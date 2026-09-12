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

    // ---------------------------------------------------------------
    // VOLUMEN DEL SISTEMA (COM), para no moverlo a base de teclazos.
    // Antes se ponia un porcentaje con 50 pulsaciones de VK_VOLUME_DOWN y
    // luego N de VK_VOLUME_UP: ~2,5 s de tics sonando encima del juego, y sin
    // forma de LEER el valor, asi que "deshaz" no podia devolverlo.
    // La declaracion es la misma que ya usa nova_ui.cs para dibujarlo.
    // ---------------------------------------------------------------
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorCom { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume
    {
        int RegisterControlChangeNotify(IntPtr p);
        int UnregisterControlChangeNotify(IntPtr p);
        int GetChannelCount(out uint n);
        int SetMasterVolumeLevel(float db, ref Guid ctx);
        int SetMasterVolumeLevelScalar(float v, ref Guid ctx);
        int GetMasterVolumeLevel(out float db);
        int GetMasterVolumeLevelScalar(out float v);
        int SetChannelVolumeLevel(uint c, float db, ref Guid ctx);
        int SetChannelVolumeLevelScalar(uint c, float v, ref Guid ctx);
        int GetChannelVolumeLevel(uint c, out float db);
        int GetChannelVolumeLevelScalar(uint c, out float v);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool m, ref Guid ctx);
        int GetMute([MarshalAs(UnmanagedType.Bool)] out bool m);
    }

    // Se cachea el endpoint: crearlo cuesta unos ms y esto se llama a menudo.
    // Si el dispositivo por defecto cambia (auriculares), el objeto viejo
    // empieza a fallar; entonces se rehace en la siguiente llamada.
    static IAudioEndpointVolume _vol;

    static IAudioEndpointVolume Volumen(bool rehacer)
    {
        if (_vol != null && !rehacer) { return _vol; }
        if (_vol != null)
        {
            try { Marshal.FinalReleaseComObject(_vol); } catch { }
            _vol = null;
        }
        object enumerador = null, dispositivo = null;
        try
        {
            var en = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCom() as object);
            enumerador = en;
            IMMDevice dev;
            if (en.GetDefaultAudioEndpoint(0, 0, out dev) != 0) { return null; }   // 0 = altavoces
            dispositivo = dev;
            Guid iid = typeof(IAudioEndpointVolume).GUID;
            object o;
            if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) { return null; }
            _vol = (IAudioEndpointVolume)o;
            return _vol;
        }
        catch { return null; }
        finally
        {
            try { if (dispositivo != null && Marshal.IsComObject(dispositivo)) { Marshal.FinalReleaseComObject(dispositivo); } } catch { }
            try { if (enumerador != null && Marshal.IsComObject(enumerador)) { Marshal.FinalReleaseComObject(enumerador); } } catch { }
        }
    }

    /// Volumen actual, 0..100. Devuelve -1 si no se puede leer.
    public static int LeerVolumen()
    {
        for (int intento = 0; intento < 2; intento++)
        {
            var v = Volumen(intento > 0);
            if (v == null) { continue; }
            try
            {
                float f;
                if (v.GetMasterVolumeLevelScalar(out f) == 0) { return (int)Math.Round(f * 100.0); }
            }
            catch { }
        }
        return -1;
    }

    /// Pone el volumen (0..100). Devuelve false si no se pudo.
    public static bool PonerVolumen(int pct)
    {
        if (pct < 0) { pct = 0; }
        if (pct > 100) { pct = 100; }
        Guid ctx = Guid.Empty;
        for (int intento = 0; intento < 2; intento++)
        {
            var v = Volumen(intento > 0);
            if (v == null) { continue; }
            try { if (v.SetMasterVolumeLevelScalar(pct / 100f, ref ctx) == 0) { return true; } }
            catch { }
        }
        return false;
    }

    /// 1 silenciado, 0 no, -1 no se pudo leer.
    public static int LeerSilencio()
    {
        for (int intento = 0; intento < 2; intento++)
        {
            var v = Volumen(intento > 0);
            if (v == null) { continue; }
            try
            {
                bool m;
                if (v.GetMute(out m) == 0) { return m ? 1 : 0; }
            }
            catch { }
        }
        return -1;
    }

    public static bool PonerSilencio(bool silencio)
    {
        Guid ctx = Guid.Empty;
        for (int intento = 0; intento < 2; intento++)
        {
            var v = Volumen(intento > 0);
            if (v == null) { continue; }
            try { if (v.SetMute(silencio, ref ctx) == 0) { return true; } }
            catch { }
        }
        return false;
    }

    // ---------------------------------------------------------------
    // VOLUMEN POR APLICACION (mezclador de Windows, por sesiones)
    // Misma familia COM que el volumen maestro de arriba. Permite bajar el
    // juego sin bajarle la voz al amigo de Discord, que con el volumen
    // maestro es imposible.
    // ---------------------------------------------------------------
    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionManager2
    {
        int NoUsado_GetAudioSessionControl(IntPtr a, int b, out IntPtr c);
        int NoUsado_GetSimpleAudioVolume(IntPtr a, int b, out IntPtr c);
        int GetSessionEnumerator(out IAudioSessionEnumerator ppSessionEnum);
    }

    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionEnumerator
    {
        int GetCount(out int SessionCount);
        int GetSession(int SessionIndex, out IAudioSessionControl Session);
    }

    [ComImport, Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl
    {
        int GetState(out int pRetVal);
    }

    [ComImport, Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl2
    {
        int GetState(out int pRetVal);
        int NoUsado_GetDisplayName(out IntPtr p);
        int NoUsado_SetDisplayName(string v, ref Guid g);
        int NoUsado_GetIconPath(out IntPtr p);
        int NoUsado_SetIconPath(string v, ref Guid g);
        int NoUsado_GetGroupingParam(out Guid g);
        int NoUsado_SetGroupingParam(ref Guid g, ref Guid ctx);
        int NoUsado_RegisterAudioSessionNotification(IntPtr p);
        int NoUsado_UnregisterAudioSessionNotification(IntPtr p);
        int NoUsado_GetSessionIdentifier(out IntPtr p);
        int NoUsado_GetSessionInstanceIdentifier(out IntPtr p);
        int GetProcessId(out uint pRetVal);
        int IsSystemSoundsSession();
        int SetDuckingPreference(bool optOut);
    }

    [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ISimpleAudioVolume
    {
        int SetMasterVolume(float fLevel, ref Guid EventContext);
        int GetMasterVolume(out float pfLevel);
        int SetMute(bool bMute, ref Guid EventContext);
        int GetMute(out bool pbMute);
    }

    static IAudioSessionEnumerator Sesiones()
    {
        object enumerador = null, dispositivo = null;
        try
        {
            var en = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCom() as object);
            enumerador = en;
            IMMDevice dev;
            if (en.GetDefaultAudioEndpoint(0, 0, out dev) != 0) { return null; }
            dispositivo = dev;
            Guid iid = typeof(IAudioSessionManager2).GUID;
            object o;
            if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) { return null; }
            var mgr = (IAudioSessionManager2)o;
            IAudioSessionEnumerator ses;
            if (mgr.GetSessionEnumerator(out ses) != 0) { return null; }
            return ses;
        }
        catch { return null; }
        finally
        {
            try { if (dispositivo != null && Marshal.IsComObject(dispositivo)) { Marshal.FinalReleaseComObject(dispositivo); } } catch { }
            try { if (enumerador != null && Marshal.IsComObject(enumerador)) { Marshal.FinalReleaseComObject(enumerador); } } catch { }
        }
    }

    /// PIDs que tienen sonido ACTIVO ahora mismo (estado 1 = activo).
    /// Con esto se puede responder "¿que esta sonando?".
    public static int[] PidsConSonido()
    {
        var lista = new System.Collections.Generic.List<int>();
        var ses = Sesiones();
        if (ses == null) { return lista.ToArray(); }
        try
        {
            int n;
            if (ses.GetCount(out n) != 0) { return lista.ToArray(); }
            for (int i = 0; i < n; i++)
            {
                IAudioSessionControl c;
                if (ses.GetSession(i, out c) != 0) { continue; }
                try
                {
                    int estado;
                    if (c.GetState(out estado) != 0 || estado != 1) { continue; }   // 1 = AudioSessionStateActive
                    var c2 = c as IAudioSessionControl2;
                    if (c2 == null) { continue; }
                    uint pid;
                    if (c2.GetProcessId(out pid) != 0 || pid == 0) { continue; }
                    if (!lista.Contains((int)pid)) { lista.Add((int)pid); }
                }
                finally { try { Marshal.FinalReleaseComObject(c); } catch { } }
            }
        }
        catch { }
        finally { try { Marshal.FinalReleaseComObject(ses); } catch { } }
        return lista.ToArray();
    }

    // Busca la sesion de un PID y le aplica lo que toque. Se recorre cada vez
    // en vez de cachear: las sesiones nacen y mueren con las apps.
    static bool ConSesion(int pid, Func<ISimpleAudioVolume, bool> hacer)
    {
        var ses = Sesiones();
        if (ses == null) { return false; }
        try
        {
            int n;
            if (ses.GetCount(out n) != 0) { return false; }
            for (int i = 0; i < n; i++)
            {
                IAudioSessionControl c;
                if (ses.GetSession(i, out c) != 0) { continue; }
                try
                {
                    var c2 = c as IAudioSessionControl2;
                    if (c2 == null) { continue; }
                    uint p2;
                    if (c2.GetProcessId(out p2) != 0 || (int)p2 != pid) { continue; }
                    var vol = c as ISimpleAudioVolume;
                    if (vol == null) { continue; }
                    return hacer(vol);
                }
                finally { try { Marshal.FinalReleaseComObject(c); } catch { } }
            }
        }
        catch { }
        finally { try { Marshal.FinalReleaseComObject(ses); } catch { } }
        return false;
    }

    /// Volumen de una app concreta, 0..100. -1 si no tiene sesion de audio.
    public static int LeerVolumenApp(int pid)
    {
        int r = -1;
        ConSesion(pid, delegate(ISimpleAudioVolume v)
        {
            float f;
            if (v.GetMasterVolume(out f) == 0) { r = (int)Math.Round(f * 100.0); return true; }
            return false;
        });
        return r;
    }

    public static bool PonerVolumenApp(int pid, int pct)
    {
        if (pct < 0) { pct = 0; }
        if (pct > 100) { pct = 100; }
        Guid ctx = Guid.Empty;
        return ConSesion(pid, delegate(ISimpleAudioVolume v)
        {
            return v.SetMasterVolume(pct / 100f, ref ctx) == 0;
        });
    }

    public static bool SilenciarApp(int pid, bool silencio)
    {
        Guid ctx = Guid.Empty;
        return ConSesion(pid, delegate(ISimpleAudioVolume v)
        {
            return v.SetMute(silencio, ref ctx) == 0;
        });
    }
}
