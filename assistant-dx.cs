// Fuente de assistant-dx.dll (clase AX), reconstruido por reflexion sobre el
// binario existente el 2026-09-10. El .cs original se habia perdido: sin el no
// se podia recompilar el P/Invoke sin decompilar.
//
// Se precompila a DLL a proposito: hacer Add-Type -TypeDefinition en cada
// arranque invocaba csc, lo que COLGABA y mataba el proceso en silencio.
// assistant.ps1 lo carga con Add-Type -Path.
//
// RECOMPILAR (ajusta la version del framework si hiciera falta):
//   & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" `
//       /target:library /out:assistant-dx.dll assistant-dx.cs
//
// Verificado contra el binario en uso: AX expone XInputGetState (xinput1_4.dll),
// keybd_event y SetForegroundWindow (user32.dll), mas las structs XINPUT_STATE
// y XINPUT_GAMEPAD con layout secuencial.

using System;
using System.Runtime.InteropServices;

public class AX
{
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_GAMEPAD
    {
        public ushort wButtons;
        public byte bLeftTrigger;
        public byte bRightTrigger;
        public short sThumbLX;
        public short sThumbLY;
        public short sThumbRX;
        public short sThumbRY;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_STATE
    {
        public uint dwPacketNumber;
        public XINPUT_GAMEPAD Gamepad;
    }

    // En modo escritorio la ROG Ally solo expone a XInput los dos botones del
    // marco: START (0x0010, el boton "≡") y BACK/VIEW (0x0020). RB/LB/Y/B/
    // cruceta/L3/R3/LT/RT NO llegan: ASUS/ACSE los remapea a teclado/raton.
    [DllImport("xinput1_4.dll")]
    public static extern int XInputGetState(uint dwUserIndex, ref XINPUT_STATE pState);

    // Vibracion del mando (eco tactil: al despertar, al confirmar, al acabar
    // una tarea larga). Devuelve 0 si el mando existe y acepto la orden.
    [StructLayout(LayoutKind.Sequential)]
    public struct XINPUT_VIBRATION
    {
        public ushort wLeftMotorSpeed;
        public ushort wRightMotorSpeed;
    }

    [DllImport("xinput1_4.dll")]
    public static extern int XInputSetState(uint dwUserIndex, ref XINPUT_VIBRATION pVibration);

    public static bool Vibrar(uint idx, ushort izquierdo, ushort derecho)
    {
        var v = new XINPUT_VIBRATION();
        v.wLeftMotorSpeed = izquierdo;
        v.wRightMotorSpeed = derecho;
        return XInputSetState(idx, ref v) == 0;
    }

    // Rectangulo de la ventana en primer plano: para capturarla (OCR, contexto
    // de pantalla para la IA) sin llevarse toda la pantalla.
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    // Devuelve false si Windows deniega el cambio de primer plano (foreground
    // lock). assistant.ps1 comprueba el retorno y reintenta: descartarlo hacia
    // invisible el fallo que provocaba el bug "vacio, ignorado".
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern IntPtr SetFocus(IntPtr hWnd);

    // Reproduccion de MP3 sin depender de WPF/MediaPlayer, que necesita un
    // Dispatcher y no encaja bien en el bucle WinForms del asistente.
    // MCI reproduce en segundo plano y no bloquea.
    [DllImport("winmm.dll", CharSet = CharSet.Auto)]
    public static extern int mciSendString(string comando, System.Text.StringBuilder retorno, int tam, IntPtr callback);

    public static void PlayMp3(string ruta)
    {
        // cerrar lo anterior para no acumular alias abiertos
        mciSendString("close ttsvoz", null, 0, IntPtr.Zero);
        mciSendString("open \"" + ruta + "\" type mpegvideo alias ttsvoz", null, 0, IntPtr.Zero);
        mciSendString("play ttsvoz", null, 0, IntPtr.Zero);
    }

    // Windows bloquea el cambio de primer plano desde un proceso que no tiene
    // el foco (foreground lock): SetForegroundWindow a secas devuelve false y
    // el dictado acaba escribiendo en OTRA ventana ("vacio, ignorado").
    // Enganchando la cola de entrada del hilo que SI tiene el foco
    // (AttachThreadInput), el sistema nos considera parte de esa cola y
    // permite el cambio. Es la tecnica estandar para este caso.
    public static bool ForceForeground(IntPtr hWnd)
    {
        IntPtr fg = GetForegroundWindow();
        if (fg == hWnd) { return true; }

        uint hiloAjeno = GetWindowThreadProcessId(fg, IntPtr.Zero);
        uint hiloPropio = GetCurrentThreadId();
        bool enganchado = false;

        if (hiloAjeno != 0 && hiloAjeno != hiloPropio)
        {
            enganchado = AttachThreadInput(hiloPropio, hiloAjeno, true);
        }
        try
        {
            ShowWindow(hWnd, 5);          // SW_SHOW
            BringWindowToTop(hWnd);
            SetForegroundWindow(hWnd);
            SetFocus(hWnd);
        }
        finally
        {
            if (enganchado) { AttachThreadInput(hiloPropio, hiloAjeno, false); }
        }
        // el valor de retorno de SetForegroundWindow miente a veces;
        // lo que cuenta es quien tiene realmente el primer plano
        return GetForegroundWindow() == hWnd;
    }
}
