// Nova UI: la cara visible del asistente.
//
// POR QUE UN PROCESO APARTE Y EN WPF:
// La barra anterior era WinForms, que no tiene aceleracion por hardware: las
// animaciones van a tirones y parpadean. WPF anima a 60 fps, pero no convive
// con el bucle de un solo hilo del asistente. Separarlo resuelve las dos cosas
// y ademas aisla fallos: si la interfaz peta, el asistente sigue funcionando.
//
// COMUNICACION: el asistente escribe un JSON diminuto con el estado; aqui se
// lee cada 80 ms. Mismo patron de archivos que los workers de voz y escucha.
//   estado     : reposo | escuchando | pensando | hablando | error
//   texto      : lo que se muestra
//   evento + n : animacion puntual (despierta, hecho, aviso, logro,
//                brillo:NN, gesto:<nombre>); se dispara cuando cambia "n"
//   juego      : ruta del ejecutable del juego en primer plano (su icono es
//                el avatar; el punto pasa a insignia)
//   audio      : mp3 que esta sonando; <mp3>.env es la envolvente a 20 Hz
//   bateria / cargando, tempoFin / tempoTotal, perfil ("noche")
//   carga      : % de CPU: por encima del 85 el pulso se acelera y enrojece
//   clima      : emoji del tiempo (avatar cuando no hay juego) y climaTemp
//   animo      : -1..1, humor de las ultimas 24 h (errores vs aciertos)
// El nivel del microfono llega por ui-nivel.txt (worker de escucha, 4 Hz).
// El volumen del sistema se lee AQUI por COM cada 250 ms.
//
// CRISTAL DE VERDAD, NO PLASTICO: se captura la pantalla justo detras, se
// desenfoca en la GPU y se usa de fondo recortado; encima tinte ligero,
// grano apenas perceptible, reflejo arriba, linea especular y sombra.
//
// VIDA: nada de esto es funcional, y todo importa. Respira, parpadea, mira,
// se duerme si la ignoran, se encoge cuando el juego va a pantalla completa,
// se aparta de las ventanas que la tapan, y GESTICULA con lo que le dices:
// asiente, niega, saluda, se sonroja, se rie, duda, se sobresalta, suda si
// tarda... Es lo que separa a alguien de una barra de progreso.
//
// COMPILAR: tools\compilar-ui.ps1
// USO: nova_ui.exe <ruta del json de estado> [PID del asistente]

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Media;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;

// ---------------------------------------------------------------
// Volumen maestro de Windows por COM (Core Audio). Solo lo que se usa; el
// orden de los metodos es el de la vtable y NO se puede cambiar.
// ---------------------------------------------------------------
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorCom { }

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator
{
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice
{
    int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
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

public class NovaUI : Window
{
    // --- medidas: el usuario pidio mantener el tamano, que no estorba
    const double ANCHO_BARRA = 340;
    const double ALTO = 44;
    // la carita manda: punto grande (20 px en un hueco de 28) y ojos visibles
    const double AVATAR = 28;
    const double DIAM_PUNTO = 20;
    const double DIAM_INSIGNIA = 10;
    const double ICONO = 26;
    const double MARGEN = 24;
    const double RADIO_BLUR = 22;
    const int BARRAS_ONDA = 14;
    const int PARTICULAS = 6;
    const double SEPARACION = 12;      // distancia al borde de la pantalla

    static string rutaEstado;
    static string rutaNivel;
    static int pidPadre = 0;

    Border envoltorio;
    Border capsula;
    Grid interior;
    RectangleGeometry recorte;
    Image fondoDesenfocado;
    DropShadowEffect resplandor;
    GradientStop bordeAbajo;
    TranslateTransform sacudida;
    ScaleTransform escalaEnvoltorio;

    // el "rostro"
    Grid esfera, cuerpo;
    Ellipse punto, insignia, aroAvatar, reflejoPunto, orbita;
    Image avatar;
    TextBlock avatarClima, corazon, pregunta, zeta, sudor;
    Ellipse[] anillos;
    Ellipse[] chispas;
    System.Windows.Shapes.Path marcaHecho, anilloTempo;
    ScaleTransform escalaPunto;
    TranslateTransform mirada;
    RotateTransform giroOrbita;
    // ojos: dos pupilas que miran, parpadean y expresan
    Ellipse ojoIzq, ojoDer;
    ScaleTransform escOjoIzq, escOjoDer;
    RotateTransform rotOjoIzq, rotOjoDer;
    TranslateTransform trasOjoIzq, trasOjoDer;
    string expresion = "normal";
    DateTime expresionHasta = DateTime.MaxValue;
    Rectangle lineaProgreso;
    double progreso = 0;
    int voz = 0;
    // gestos: giro, desplazamiento y escala de TODO el rostro
    RotateTransform rotGesto;
    TranslateTransform trasGesto;
    ScaleTransform escalaGesto;
    StackPanel ecualizador;
    Rectangle[] bandas;

    StackPanel onda;
    Rectangle[] barras;
    StackPanel indicadorPensando;
    Ellipse[] puntitos;

    StackPanel panelNivel;
    TextBlock glifoNivel;
    Rectangle barraNivel;
    DispatcherTimer ocultarNivel;
    IAudioEndpointVolume volumen;
    float volAnterior = -1;
    bool muteAnterior = false;
    int fallosVolumen = 0;

    TextBlock etiqueta, etiquetaSombra;
    Canvas ventanaTexto;
    TranslateTransform desplaz, desplazSombra, entradaTexto;
    LinearGradientBrush mascaraAmbos, mascaraIzq, mascaraDer;
    int generacionTexto = 0;

    string estadoActual = "";
    string textoActual = "";
    string juegoActual = "";
    string audioActual = "";
    string perfilActual = "";
    string climaActual = "";
    int eventoN = -1;
    int bateria = 100;
    bool cargando = false;
    int carga = 0;
    double animo = 0;
    double tempoFin = 0, tempoTotal = 0;
    bool tempoActivo = false;
    int ultimoSegundo = -1;
    double nivelActual = 0, nivelObjetivo = 0;
    double fase = 0;
    double velocidadOnda = 0.45;
    DateTime prisaHasta = DateTime.MinValue;
    double boca = 0, bocaObjetivo = 0;
    DateTime proximaSilaba = DateTime.MinValue;
    double[] envolvente = null;
    DateTime envInicio = DateTime.MinValue;
    DateTime pensandoDesde = DateTime.MinValue;
    DateTime ultimoSudor = DateTime.MinValue;
    bool orbitando = false;
    bool nocheActual = false;
    bool calmaHasta = false;
    DateTime calmaFin = DateTime.MinValue;
    Random azar = new Random();
    DispatcherTimer parpadeo;
    Point raton = new Point(-1, -1);
    DateTime ratonMovido = DateTime.MinValue;
    double miradaX = 0, miradaY = 0;
    bool cerca = false;                 // el raton esta junto a la capsula
    SoundPlayer sonDespierta, sonHecho, sonError, sonLogro, sonAviso, sonTic, sonSuave;
    bool cerrando = false;
    // sueno y foco
    DateTime ultimaActividad = DateTime.UtcNow;
    bool dormido = false;
    DateTime ultimaZeta = DateTime.MinValue;
    bool foco = false;                  // ventana a pantalla completa delante
    int focoCuenta = 0;
    // apartarse de una ventana que la tapa
    double leftBase = 0;
    bool apartada = false;
    int tapadaCuenta = 0;
    Dictionary<string, DateTime> ultimoGesto = new Dictionary<string, DateTime>();
    // memoria corta de gestos: encadenados, humor de minutos, ritmo, tono
    string ultimoGestoNombre = "";
    DateTime ultimoGestoHora = DateTime.MinValue;
    string ultimaOrden = "";                 // ultimo texto final de la transcripcion
    DateTime ultimaPena = DateTime.MinValue;
    DateTime escuchandoDesde = DateTime.MinValue;
    DateTime ultimoAsentimiento = DateTime.MinValue;
    string humor = "";                       // "contenta" | "cauta" | ""
    DateTime humorHasta = DateTime.MinValue;
    List<DateTime> negaciones = new List<DateTime>();
    List<KeyValuePair<DateTime, int>> ritmo = new List<KeyValuePair<DateTime, int>>();
    int gritoCuenta = 0, susurroCuenta = 0;
    DateTime tonoHasta = DateTime.MinValue;
    List<string[]> gestosExtra = new List<string[]>();
    DateTime gestosExtraLeido = DateTime.MinValue;
    string rutaGestosCfg, rutaGestosLog;

    // click-through: la barra nunca debe robar clics al juego
    const int GWL_EXSTYLE = -20;
    const int WS_EX_TRANSPARENT = 0x20;
    const int WS_EX_TOOLWINDOW = 0x80;
    const int WS_EX_NOACTIVATE = 0x8000000;
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] struct PUNTO { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)] struct RECTA { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out PUNTO p);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECTA r);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    const uint SWP_NOSIZE = 0x0001, SWP_NOMOVE = 0x0002, SWP_NOACTIVATE = 0x0010;
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    IntPtr hwnd = IntPtr.Zero;

    void PonerEncima()
    {
        if (hwnd != IntPtr.Zero) { SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE); }
    }

    [STAThread]
    public static void Main(string[] args)
    {
        rutaEstado = args.Length > 0 ? args[0] : "ui-estado.json";
        if (args.Length > 1) { int.TryParse(args[1], out pidPadre); }
        try { rutaNivel = System.IO.Path.Combine(System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(rutaEstado)), "ui-nivel.txt"); }
        catch { rutaNivel = null; }
        var app = new Application();
        // un fallo en cualquier animacion no debe tumbar la interfaz
        app.DispatcherUnhandledException += delegate(object s, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e) { e.Handled = true; };
        app.Run(new NovaUI());
    }

    public NovaUI()
    {
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false;
        Topmost = true;
        ResizeMode = ResizeMode.NoResize;
        Width = ANCHO_BARRA + MARGEN * 2;
        Height = ALTO + MARGEN * 2;

        var area = SystemParameters.WorkArea;
        leftBase = area.Left + SEPARACION - MARGEN;
        Left = leftBase;
        Top = area.Bottom - ALTO - SEPARACION - MARGEN;

        nocheActual = EsNoche();
        Color acento = ColorDe("reposo");

        // ---------- capa 1: sombra de profundidad ----------
        envoltorio = new Border();
        envoltorio.HorizontalAlignment = HorizontalAlignment.Left;
        envoltorio.VerticalAlignment = VerticalAlignment.Center;
        envoltorio.Margin = new Thickness(MARGEN, 0, 0, 0);
        envoltorio.CornerRadius = new CornerRadius(ALTO / 2);
        envoltorio.Background = new SolidColorBrush(Color.FromArgb(0x01, 0, 0, 0));
        var sombra = new DropShadowEffect();
        sombra.Color = Colors.Black; sombra.BlurRadius = 16; sombra.ShadowDepth = 4; sombra.Direction = 270; sombra.Opacity = 0.55;
        envoltorio.Effect = sombra;
        sacudida = new TranslateTransform();
        escalaEnvoltorio = new ScaleTransform(1, 1);
        var grupoEnv = new TransformGroup();
        grupoEnv.Children.Add(escalaEnvoltorio);
        grupoEnv.Children.Add(sacudida);
        envoltorio.RenderTransform = grupoEnv;
        // origen en el centro del circulo de reposo: al encogerse se queda en su sitio
        envoltorio.RenderTransformOrigin = new Point(ALTO / 2 / ANCHO_BARRA, 0.5);

        // ---------- capa 2: la capsula ----------
        resplandor = new DropShadowEffect();
        resplandor.BlurRadius = 24; resplandor.ShadowDepth = 0; resplandor.Opacity = 0.5; resplandor.Color = acento;

        capsula = new Border();
        capsula.Height = ALTO;
        capsula.Width = ALTO;
        capsula.CornerRadius = new CornerRadius(ALTO / 2);
        capsula.BorderThickness = new Thickness(1);
        capsula.Effect = resplandor;
        capsula.Background = Brushes.Transparent;
        var borde = new LinearGradientBrush();
        borde.StartPoint = new Point(0, 0); borde.EndPoint = new Point(0, 1);
        borde.GradientStops.Add(new GradientStop(Color.FromArgb(0x5C, 0xFF, 0xFF, 0xFF), 0));
        bordeAbajo = new GradientStop(Color.FromArgb(0x55, acento.R, acento.G, acento.B), 1);
        borde.GradientStops.Add(bordeAbajo);
        capsula.BorderBrush = borde;

        // ---------- capa 3: interior ----------
        interior = new Grid();
        recorte = new RectangleGeometry();
        recorte.RadiusX = ALTO / 2 - 1; recorte.RadiusY = ALTO / 2 - 1;
        interior.Clip = recorte;
        interior.SizeChanged += delegate { recorte.Rect = new Rect(0, 0, interior.ActualWidth, interior.ActualHeight); };

        fondoDesenfocado = new Image();
        fondoDesenfocado.Stretch = Stretch.Fill;
        fondoDesenfocado.HorizontalAlignment = HorizontalAlignment.Left;
        fondoDesenfocado.VerticalAlignment = VerticalAlignment.Top;
        fondoDesenfocado.Width = ANCHO_BARRA + RADIO_BLUR * 2;
        fondoDesenfocado.Height = ALTO + RADIO_BLUR * 2;
        fondoDesenfocado.Margin = new Thickness(-RADIO_BLUR, -RADIO_BLUR, 0, 0);
        var blur = new BlurEffect();
        blur.Radius = RADIO_BLUR; blur.KernelType = KernelType.Gaussian; blur.RenderingBias = RenderingBias.Performance;
        fondoDesenfocado.Effect = blur;
        interior.Background = new SolidColorBrush(Color.FromRgb(0x14, 0x17, 0x1E));
        interior.Children.Add(fondoDesenfocado);

        var tinte = new Border();
        var tintePincel = new LinearGradientBrush();
        tintePincel.StartPoint = new Point(0, 0); tintePincel.EndPoint = new Point(0, 1);
        tintePincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x4A, 0x1A, 0x22, 0x32), 0));
        tintePincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x78, 0x08, 0x0C, 0x16), 1));
        tinte.Background = tintePincel;
        interior.Children.Add(tinte);

        var ruido = new Border();
        ruido.Background = CrearGrano();
        ruido.Opacity = 0.02;
        interior.Children.Add(ruido);

        var sombraInterior = new Border();
        sombraInterior.VerticalAlignment = VerticalAlignment.Bottom;
        sombraInterior.Height = ALTO * 0.4;
        var sombraPincel = new LinearGradientBrush();
        sombraPincel.StartPoint = new Point(0, 0); sombraPincel.EndPoint = new Point(0, 1);
        sombraPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0, 0, 0), 0));
        sombraPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x48, 0, 0, 0), 1));
        sombraInterior.Background = sombraPincel;
        interior.Children.Add(sombraInterior);

        var brilloSuperior = new Border();
        brilloSuperior.VerticalAlignment = VerticalAlignment.Top;
        brilloSuperior.Height = ALTO * 0.45;
        var brilloPincel = new LinearGradientBrush();
        brilloPincel.StartPoint = new Point(0, 0); brilloPincel.EndPoint = new Point(0, 1);
        brilloPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x24, 0xFF, 0xFF, 0xFF), 0));
        brilloPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 1));
        brilloSuperior.Background = brilloPincel;
        interior.Children.Add(brilloSuperior);

        // linea de progreso en el borde inferior: se llena mientras opencode
        // trabaja (voz interna); mas alla del 95 % late, porque ya es espera
        lineaProgreso = new Rectangle();
        lineaProgreso.Height = 2;
        lineaProgreso.HorizontalAlignment = HorizontalAlignment.Left;
        lineaProgreso.VerticalAlignment = VerticalAlignment.Bottom;
        lineaProgreso.Margin = new Thickness(ALTO * 0.4, 0, 0, 1);
        lineaProgreso.RadiusX = 1; lineaProgreso.RadiusY = 1;
        lineaProgreso.Width = 0;
        lineaProgreso.Opacity = 0;
        lineaProgreso.Fill = new SolidColorBrush(acento);
        lineaProgreso.IsHitTestVisible = false;
        interior.Children.Add(lineaProgreso);

        var especular = new Border();
        especular.VerticalAlignment = VerticalAlignment.Top;
        especular.Height = 1;
        especular.Margin = new Thickness(ALTO * 0.5, 1, ALTO * 0.5, 0);
        var especularPincel = new LinearGradientBrush();
        especularPincel.StartPoint = new Point(0, 0); especularPincel.EndPoint = new Point(1, 0);
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 0));
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x9A, 0xFF, 0xFF, 0xFF), 0.35));
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x9A, 0xFF, 0xFF, 0xFF), 0.65));
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 1));
        especular.Background = especularPincel;
        interior.Children.Add(especular);

        // ---------- contenido ----------
        var fila = new StackPanel();
        fila.Orientation = Orientation.Horizontal;
        fila.VerticalAlignment = VerticalAlignment.Center;
        fila.HorizontalAlignment = HorizontalAlignment.Left;
        fila.Margin = new Thickness((ALTO - AVATAR) / 2, 0, 0, 0);

        ConstruirRostro(acento);
        fila.Children.Add(esfera);

        // volumen / brillo
        panelNivel = new StackPanel();
        panelNivel.Orientation = Orientation.Horizontal;
        panelNivel.VerticalAlignment = VerticalAlignment.Center;
        panelNivel.Margin = new Thickness(12, 0, 0, 0);
        panelNivel.Visibility = Visibility.Collapsed;
        panelNivel.Opacity = 0;
        glifoNivel = new TextBlock();
        glifoNivel.FontFamily = new FontFamily("Segoe MDL2 Assets, Segoe Fluent Icons");
        glifoNivel.FontSize = 15;
        glifoNivel.Foreground = new SolidColorBrush(Color.FromRgb(0xF2, 0xF5, 0xF8));
        glifoNivel.VerticalAlignment = VerticalAlignment.Center;
        panelNivel.Children.Add(glifoNivel);
        var pista = new Border();
        pista.Width = 72; pista.Height = 4;
        pista.CornerRadius = new CornerRadius(2);
        pista.Background = new SolidColorBrush(Color.FromArgb(0x50, 0xFF, 0xFF, 0xFF));
        pista.Margin = new Thickness(10, 0, 0, 0);
        pista.VerticalAlignment = VerticalAlignment.Center;
        barraNivel = new Rectangle();
        barraNivel.Height = 4; barraNivel.Width = 36;
        barraNivel.RadiusX = 2; barraNivel.RadiusY = 2;
        barraNivel.HorizontalAlignment = HorizontalAlignment.Left;
        barraNivel.Fill = new SolidColorBrush(acento);
        pista.Child = barraNivel;
        panelNivel.Children.Add(pista);
        fila.Children.Add(panelNivel);
        ocultarNivel = new DispatcherTimer();
        ocultarNivel.Interval = TimeSpan.FromMilliseconds(1500);
        ocultarNivel.Tick += delegate
        {
            ocultarNivel.Stop();
            Desvanecer(panelNivel, 0, 200);
            var t = new DispatcherTimer();
            t.Interval = TimeSpan.FromMilliseconds(220);
            t.Tick += delegate { t.Stop(); panelNivel.Visibility = Visibility.Collapsed; Aplicar(estadoActual, textoActual, false); };
            t.Start();
        };

        onda = new StackPanel();
        onda.Orientation = Orientation.Horizontal;
        onda.VerticalAlignment = VerticalAlignment.Center;
        onda.Margin = new Thickness(12, 0, 0, 0);
        onda.Opacity = 0;
        onda.Visibility = Visibility.Collapsed;
        barras = new Rectangle[BARRAS_ONDA];
        for (int i = 0; i < BARRAS_ONDA; i++)
        {
            var r = new Rectangle();
            r.Width = 3; r.Height = 4; r.RadiusX = 1.5; r.RadiusY = 1.5;
            r.Margin = new Thickness(1.5, 0, 1.5, 0);
            r.VerticalAlignment = VerticalAlignment.Center;
            r.Fill = new SolidColorBrush(acento);
            barras[i] = r;
            onda.Children.Add(r);
        }
        fila.Children.Add(onda);

        indicadorPensando = new StackPanel();
        indicadorPensando.Orientation = Orientation.Horizontal;
        indicadorPensando.VerticalAlignment = VerticalAlignment.Center;
        indicadorPensando.Margin = new Thickness(12, 0, 0, 0);
        indicadorPensando.Visibility = Visibility.Collapsed;
        puntitos = new Ellipse[3];
        for (int i = 0; i < 3; i++)
        {
            var e = new Ellipse();
            e.Width = 5; e.Height = 5;
            e.Margin = new Thickness(2, 0, 2, 0);
            e.Fill = new SolidColorBrush(acento);
            e.Opacity = 0.3;
            puntitos[i] = e;
            indicadorPensando.Children.Add(e);
        }
        fila.Children.Add(indicadorPensando);

        // texto, con su "sombra" para el rastro al desplazarse
        etiqueta = CrearEtiqueta();
        desplaz = new TranslateTransform();
        etiqueta.RenderTransform = desplaz;
        etiquetaSombra = CrearEtiqueta();
        etiquetaSombra.Effect = new BlurEffect { Radius = 5, KernelType = KernelType.Gaussian };
        etiquetaSombra.Opacity = 0;
        desplazSombra = new TranslateTransform();
        etiquetaSombra.RenderTransform = desplazSombra;

        ventanaTexto = new Canvas();
        ventanaTexto.ClipToBounds = true;
        ventanaTexto.Height = 20;
        ventanaTexto.HorizontalAlignment = HorizontalAlignment.Left;
        ventanaTexto.VerticalAlignment = VerticalAlignment.Center;
        ventanaTexto.Margin = new Thickness(12, 0, 0, 0);
        ventanaTexto.Opacity = 0;
        ventanaTexto.Visibility = Visibility.Collapsed;
        entradaTexto = new TranslateTransform();
        ventanaTexto.RenderTransform = entradaTexto;
        Canvas.SetLeft(etiquetaSombra, 0); Canvas.SetTop(etiquetaSombra, 0);
        Canvas.SetLeft(etiqueta, 0); Canvas.SetTop(etiqueta, 0);
        ventanaTexto.Children.Add(etiquetaSombra);
        ventanaTexto.Children.Add(etiqueta);
        fila.Children.Add(ventanaTexto);

        mascaraAmbos = Mascara(0.07, 0.93);
        mascaraIzq = Mascara(0.09, 1.01);
        mascaraDer = Mascara(-0.01, 0.91);

        interior.Children.Add(fila);
        capsula.Child = interior;
        envoltorio.Child = capsula;

        var lienzo = new Grid();
        lienzo.Children.Add(envoltorio);
        Content = lienzo;

        CrearSonidos();
        IniciarVolumen();
        try
        {
            string carpeta = System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(rutaEstado));
            rutaGestosCfg = System.IO.Path.Combine(carpeta, "gestos.txt");
            rutaGestosLog = System.IO.Path.Combine(carpeta, "gestos.log");
            CargarGestosExtra();
        }
        catch { }

        Loaded += delegate
        {
            var h = new WindowInteropHelper(this).Handle;
            int est = GetWindowLong(h, GWL_EXSTYLE);
            SetWindowLong(h, GWL_EXSTYLE, est | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
            hwnd = h;
            PonerEncima();
            Latido();
            CapturarFondo();
            EntradaEnEscena();
        };

        var relojZ = new DispatcherTimer();
        relojZ.Interval = TimeSpan.FromMilliseconds(1500);
        relojZ.Tick += delegate { PonerEncima(); };
        relojZ.Start();

        var reloj = new DispatcherTimer();
        reloj.Interval = TimeSpan.FromMilliseconds(80);
        reloj.Tick += delegate { LeerEstado(); };
        reloj.Start();

        var reloj2 = new DispatcherTimer();
        reloj2.Interval = TimeSpan.FromMilliseconds(33);
        reloj2.Tick += delegate { Tic33(); };
        reloj2.Start();

        var reloj4 = new DispatcherTimer();
        reloj4.Interval = TimeSpan.FromMilliseconds(250);
        reloj4.Tick += delegate { Tic250(); };
        reloj4.Start();

        var relojMirada = new DispatcherTimer();
        relojMirada.Interval = TimeSpan.FromMilliseconds(66);
        relojMirada.Tick += delegate { Mirar(); };
        relojMirada.Start();

        parpadeo = new DispatcherTimer();
        parpadeo.Interval = TimeSpan.FromSeconds(5);
        parpadeo.Tick += delegate
        {
            // cauta o hablando rapido: parpadea mas a menudo
            double baseSeg = (humor == "cauta" && DateTime.UtcNow < humorHasta) ? 2 : 4;
            if (velocidadOnda > 0.6) { baseSeg = 2.5; }
            parpadeo.Interval = TimeSpan.FromSeconds(baseSeg + azar.NextDouble() * 5);
            if (!dormido && (estadoActual == "reposo" || estadoActual == "escuchando" || estadoActual == "")) { Parpadear(); }
        };
        parpadeo.Start();

        var relojCarga = new DispatcherTimer();
        relojCarga.Interval = TimeSpan.FromSeconds(4);
        relojCarga.Tick += delegate { if (cargando) { DestelloCarga(); } };
        relojCarga.Start();

        var relojAnimo = new DispatcherTimer();
        relojAnimo.Interval = TimeSpan.FromSeconds(60);
        relojAnimo.Tick += delegate
        {
            bool n = EsNoche();
            if (n != nocheActual) { nocheActual = n; Latido(); Aplicar(estadoActual, textoActual, false); }
        };
        relojAnimo.Start();

        // sueno: 30 min sin nada que hacer y sin juego
        var relojSueno = new DispatcherTimer();
        relojSueno.Interval = TimeSpan.FromSeconds(10);
        relojSueno.Tick += delegate
        {
            bool debe = !foco && string.IsNullOrEmpty(juegoActual) && (estadoActual == "reposo" || estadoActual == "")
                        && (DateTime.UtcNow - ultimaActividad).TotalMinutes >= 30;
            if (debe && !dormido) { Dormir(); }
            if (dormido && (DateTime.UtcNow - ultimaZeta).TotalSeconds >= 9) { ultimaZeta = DateTime.UtcNow; Zeta(); }
        };
        relojSueno.Start();

        if (pidPadre > 0)
        {
            var vigia = new DispatcherTimer();
            vigia.Interval = TimeSpan.FromSeconds(2);
            vigia.Tick += delegate
            {
                bool vivo = true;
                try { using (var p = Process.GetProcessById(pidPadre)) { vivo = !p.HasExited; } }
                catch { vivo = false; }
                if (!vivo) { vigia.Stop(); SalidaDeEscena(); }
            };
            vigia.Start();
        }
    }

    TextBlock CrearEtiqueta()
    {
        var t = new TextBlock();
        t.Foreground = new SolidColorBrush(Color.FromRgb(0xF2, 0xF5, 0xF8));
        t.FontFamily = new FontFamily("Segoe UI Semibold, Segoe UI");
        t.FontSize = 13.5;
        t.HorizontalAlignment = HorizontalAlignment.Left;
        t.TextTrimming = TextTrimming.None;
        var sombraTexto = new DropShadowEffect();
        sombraTexto.Color = Colors.Black; sombraTexto.BlurRadius = 4; sombraTexto.ShadowDepth = 1; sombraTexto.Opacity = 0.7;
        t.Effect = sombraTexto;
        TextOptions.SetTextRenderingMode(t, TextRenderingMode.ClearType);
        return t;
    }

    TextBlock Glifo(string texto, double tamano, Color color, string fuente)
    {
        var t = new TextBlock();
        t.Text = texto;
        t.FontSize = tamano;
        t.FontFamily = new FontFamily(fuente);
        t.FontWeight = FontWeights.Bold;
        t.Foreground = new SolidColorBrush(color);
        t.Opacity = 0;
        t.IsHitTestVisible = false;
        t.HorizontalAlignment = HorizontalAlignment.Center;
        t.VerticalAlignment = VerticalAlignment.Center;
        t.RenderTransform = new TranslateTransform(0, 0);
        return t;
    }

    // El punto (o el icono del juego / el tiempo con el punto de insignia),
    // los anillos, las chispas, el tic, el anillo del temporizador, la
    // orbita, y los adornos de los gestos (corazon, ?, z, gota de sudor).
    void ConstruirRostro(Color acento)
    {
        esfera = new Grid();
        esfera.Width = AVATAR; esfera.Height = AVATAR;
        esfera.VerticalAlignment = VerticalAlignment.Center;
        esfera.RenderTransformOrigin = new Point(0.5, 0.5);
        rotGesto = new RotateTransform(0);
        trasGesto = new TranslateTransform(0, 0);
        escalaGesto = new ScaleTransform(1, 1);
        var grupo = new TransformGroup();
        grupo.Children.Add(escalaGesto);
        grupo.Children.Add(rotGesto);
        grupo.Children.Add(trasGesto);
        esfera.RenderTransform = grupo;

        anillos = new Ellipse[2];
        for (int i = 0; i < 2; i++)
        {
            var a = new Ellipse();
            a.Width = DIAM_PUNTO; a.Height = DIAM_PUNTO;
            a.Stroke = new SolidColorBrush(acento);
            a.StrokeThickness = 1.5;
            a.Opacity = 0;
            a.IsHitTestVisible = false;
            a.RenderTransformOrigin = new Point(0.5, 0.5);
            a.RenderTransform = new ScaleTransform(1, 1);
            anillos[i] = a;
            esfera.Children.Add(a);
        }

        chispas = new Ellipse[PARTICULAS];
        for (int i = 0; i < PARTICULAS; i++)
        {
            var c = new Ellipse();
            c.Width = 2.5; c.Height = 2.5;
            c.Fill = new SolidColorBrush(Colors.White);
            c.Opacity = 0;
            c.IsHitTestVisible = false;
            c.RenderTransform = new TranslateTransform(0, 0);
            chispas[i] = c;
            esfera.Children.Add(c);
        }

        anilloTempo = new System.Windows.Shapes.Path();
        anilloTempo.Width = AVATAR + 8; anilloTempo.Height = AVATAR + 8;
        anilloTempo.Margin = new Thickness(-4);
        anilloTempo.Stroke = new SolidColorBrush(acento);
        anilloTempo.StrokeThickness = 2;
        anilloTempo.StrokeStartLineCap = PenLineCap.Round;
        anilloTempo.StrokeEndLineCap = PenLineCap.Round;
        anilloTempo.Opacity = 0;
        anilloTempo.IsHitTestVisible = false;
        esfera.Children.Add(anilloTempo);

        var pistaOrbita = new Grid();
        pistaOrbita.Width = AVATAR + 10; pistaOrbita.Height = AVATAR + 10;
        pistaOrbita.Margin = new Thickness(-5);
        pistaOrbita.RenderTransformOrigin = new Point(0.5, 0.5);
        giroOrbita = new RotateTransform(0);
        pistaOrbita.RenderTransform = giroOrbita;
        orbita = new Ellipse();
        orbita.Width = 4; orbita.Height = 4;
        orbita.HorizontalAlignment = HorizontalAlignment.Center;
        orbita.VerticalAlignment = VerticalAlignment.Top;
        orbita.Fill = new SolidColorBrush(acento);
        var brilloOrb = new DropShadowEffect();
        brilloOrb.Color = acento; brilloOrb.BlurRadius = 6; brilloOrb.ShadowDepth = 0; brilloOrb.Opacity = 0.9;
        orbita.Effect = brilloOrb;
        orbita.Opacity = 0;
        pistaOrbita.Children.Add(orbita);
        esfera.Children.Add(pistaOrbita);

        avatar = new Image();
        avatar.Width = ICONO; avatar.Height = ICONO;
        avatar.Stretch = Stretch.UniformToFill;
        avatar.Clip = new EllipseGeometry(new Point(ICONO / 2, ICONO / 2), ICONO / 2, ICONO / 2);
        avatar.Visibility = Visibility.Collapsed;
        avatar.RenderTransformOrigin = new Point(0.5, 0.5);
        avatar.RenderTransform = new ScaleTransform(1, 1);
        RenderOptions.SetBitmapScalingMode(avatar, BitmapScalingMode.HighQuality);
        esfera.Children.Add(avatar);
        // el tiempo como avatar (emoji) cuando no hay juego
        avatarClima = Glifo("", 15, Colors.White, "Segoe UI Emoji");
        avatarClima.FontWeight = FontWeights.Normal;
        avatarClima.Visibility = Visibility.Collapsed;
        avatarClima.RenderTransformOrigin = new Point(0.5, 0.5);
        avatarClima.RenderTransform = new ScaleTransform(1, 1);
        esfera.Children.Add(avatarClima);
        aroAvatar = new Ellipse();
        aroAvatar.Width = AVATAR; aroAvatar.Height = AVATAR;
        aroAvatar.Stroke = new SolidColorBrush(acento);
        aroAvatar.StrokeThickness = 1.5;
        aroAvatar.Visibility = Visibility.Collapsed;
        esfera.Children.Add(aroAvatar);

        cuerpo = new Grid();
        cuerpo.Width = DIAM_PUNTO; cuerpo.Height = DIAM_PUNTO;
        cuerpo.RenderTransformOrigin = new Point(0.5, 0.5);
        escalaPunto = new ScaleTransform(1, 1);
        cuerpo.RenderTransform = escalaPunto;
        punto = new Ellipse();
        punto.Fill = new SolidColorBrush(acento);
        var brilloPunto = new DropShadowEffect();
        brilloPunto.Color = acento; brilloPunto.BlurRadius = 10; brilloPunto.ShadowDepth = 0; brilloPunto.Opacity = 0.9;
        punto.Effect = brilloPunto;
        cuerpo.Children.Add(punto);
        // ecualizador: cuatro bandas dentro del punto mientras habla
        ecualizador = new StackPanel();
        ecualizador.Orientation = Orientation.Horizontal;
        ecualizador.HorizontalAlignment = HorizontalAlignment.Center;
        ecualizador.VerticalAlignment = VerticalAlignment.Center;
        ecualizador.Opacity = 0;
        ecualizador.IsHitTestVisible = false;
        bandas = new Rectangle[4];
        for (int i = 0; i < 4; i++)
        {
            var b = new Rectangle();
            b.Width = 1.4; b.Height = 2;
            b.RadiusX = 0.7; b.RadiusY = 0.7;
            b.Margin = new Thickness(0.55, 0, 0.55, 0);
            b.VerticalAlignment = VerticalAlignment.Center;
            b.Fill = new SolidColorBrush(Color.FromArgb(0xC8, 0xFF, 0xFF, 0xFF));
            bandas[i] = b;
            ecualizador.Children.Add(b);
        }
        cuerpo.Children.Add(ecualizador);
        // OJOS: dos pupilas oscuras sobre el punto. Es lo que lo convierte en
        // una cara: miran a donde mira la capsula, parpadean solas y ponen
        // la expresion del gesto (abiertos, entrecerrados, felices, tristes,
        // cerrados al dormir).
        ojoIzq = CrearOjo(); ojoDer = CrearOjo();
        ojoIzq.HorizontalAlignment = HorizontalAlignment.Left;
        ojoIzq.Margin = new Thickness(DIAM_PUNTO * 0.21, DIAM_PUNTO * 0.33, 0, 0);
        ojoDer.HorizontalAlignment = HorizontalAlignment.Right;
        ojoDer.Margin = new Thickness(0, DIAM_PUNTO * 0.33, DIAM_PUNTO * 0.21, 0);
        escOjoIzq = new ScaleTransform(1, 1); escOjoDer = new ScaleTransform(1, 1);
        rotOjoIzq = new RotateTransform(0); rotOjoDer = new RotateTransform(0);
        trasOjoIzq = new TranslateTransform(0, 0); trasOjoDer = new TranslateTransform(0, 0);
        var gI = new TransformGroup(); gI.Children.Add(escOjoIzq); gI.Children.Add(rotOjoIzq); gI.Children.Add(trasOjoIzq);
        var gD = new TransformGroup(); gD.Children.Add(escOjoDer); gD.Children.Add(rotOjoDer); gD.Children.Add(trasOjoDer);
        ojoIzq.RenderTransform = gI; ojoDer.RenderTransform = gD;
        cuerpo.Children.Add(ojoIzq);
        cuerpo.Children.Add(ojoDer);
        // el reflejo, mas pequeno y arriba a la izquierda, para dejar sitio a los ojos
        reflejoPunto = new Ellipse();
        reflejoPunto.Width = DIAM_PUNTO * 0.26; reflejoPunto.Height = DIAM_PUNTO * 0.16;
        reflejoPunto.HorizontalAlignment = HorizontalAlignment.Left;
        reflejoPunto.VerticalAlignment = VerticalAlignment.Top;
        reflejoPunto.Margin = new Thickness(DIAM_PUNTO * 0.16, DIAM_PUNTO * 0.09, 0, 0);
        var reflejoPincel = new LinearGradientBrush();
        reflejoPincel.StartPoint = new Point(0, 0); reflejoPincel.EndPoint = new Point(0, 1);
        reflejoPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0xB0, 0xFF, 0xFF, 0xFF), 0));
        reflejoPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x10, 0xFF, 0xFF, 0xFF), 1));
        reflejoPunto.Fill = reflejoPincel;
        mirada = new TranslateTransform(0, 0);
        reflejoPunto.RenderTransform = mirada;
        cuerpo.Children.Add(reflejoPunto);
        marcaHecho = new System.Windows.Shapes.Path();
        marcaHecho.Data = Geometry.Parse("M 3.2,7.4 L 5.9,10.1 L 10.8,4.4");
        marcaHecho.Stroke = Brushes.White;
        marcaHecho.StrokeThickness = 1.8;
        marcaHecho.StrokeStartLineCap = PenLineCap.Round;
        marcaHecho.StrokeEndLineCap = PenLineCap.Round;
        marcaHecho.StrokeLineJoin = PenLineJoin.Round;
        marcaHecho.Opacity = 0;
        cuerpo.Children.Add(marcaHecho);
        esfera.Children.Add(cuerpo);

        insignia = new Ellipse();
        insignia.Width = DIAM_INSIGNIA; insignia.Height = DIAM_INSIGNIA;
        insignia.HorizontalAlignment = HorizontalAlignment.Right;
        insignia.VerticalAlignment = VerticalAlignment.Bottom;
        insignia.Margin = new Thickness(0, 0, -1, -1);
        insignia.Fill = new SolidColorBrush(acento);
        insignia.Stroke = new SolidColorBrush(Color.FromRgb(0x10, 0x14, 0x1C));
        insignia.StrokeThickness = 1.5;
        var brilloIns = new DropShadowEffect();
        brilloIns.Color = acento; brilloIns.BlurRadius = 8; brilloIns.ShadowDepth = 0; brilloIns.Opacity = 0.9;
        insignia.Effect = brilloIns;
        insignia.Visibility = Visibility.Collapsed;
        esfera.Children.Add(insignia);

        // adornos de gestos (arrancan invisibles)
        corazon = Glifo("♥", 10, Color.FromRgb(0xFF, 0x7A, 0xA8), "Segoe UI Symbol");
        esfera.Children.Add(corazon);
        // centrados y desplazados con el margen (alinear a la esquina con
        // margenes negativos los dejaba fuera del hueco y no se veian)
        pregunta = Glifo("?", 11, Color.FromRgb(0xFF, 0xD3, 0x6A), "Segoe UI");
        pregunta.Margin = new Thickness(18, 0, 0, 20);
        esfera.Children.Add(pregunta);
        zeta = Glifo("z", 10, Color.FromRgb(0xC8, 0xD8, 0xFF), "Segoe UI");
        zeta.Margin = new Thickness(14, 0, 0, 16);
        esfera.Children.Add(zeta);
        sudor = Glifo("●", 6, Color.FromRgb(0x8C, 0xC8, 0xFF), "Segoe UI");
        sudor.Margin = new Thickness(14, 0, 0, 8);
        esfera.Children.Add(sudor);
    }

    Ellipse CrearOjo()
    {
        var o = new Ellipse();
        o.Width = DIAM_PUNTO * 0.21; o.Height = DIAM_PUNTO * 0.32;
        o.VerticalAlignment = VerticalAlignment.Top;
        o.Fill = new SolidColorBrush(Color.FromArgb(0xE6, 0x0B, 0x12, 0x24));
        o.RenderTransformOrigin = new Point(0.5, 0.5);
        o.IsHitTestVisible = false;
        return o;
    }

    // Expresion de los ojos durante un tiempo (ms <= 0: hasta que se cambie).
    //   normal | abiertos | entrecerrados | felices | tristes | cerrados | atentos
    void Expresion(string nombre, int ms)
    {
        if (dormido && nombre != "cerrados" && nombre != "normal") { return; }
        expresion = nombre;
        expresionHasta = (ms > 0) ? DateTime.UtcNow.AddMilliseconds(ms) : DateTime.MaxValue;
        double sx = 1, sy = 1, rot = 0, dy = 0;
        switch (nombre)
        {
            case "abiertos": sx = 1.45; sy = 1.45; break;
            case "entrecerrados": sy = 0.45; break;
            case "felices": sy = 0.42; dy = -0.7; break;
            case "tristes": rot = 14; dy = 0.7; break;
            case "cerrados": sy = 0.12; break;
            case "atentos": sx = 1.15; sy = 1.15; break;
            case "cautos": sy = 0.75; break;
        }
        int dur = 180;
        AnimarA(escOjoIzq, ScaleTransform.ScaleXProperty, sx, dur); AnimarA(escOjoDer, ScaleTransform.ScaleXProperty, sx, dur);
        AnimarA(escOjoIzq, ScaleTransform.ScaleYProperty, sy, dur); AnimarA(escOjoDer, ScaleTransform.ScaleYProperty, sy, dur);
        AnimarA(rotOjoIzq, RotateTransform.AngleProperty, rot, dur); AnimarA(rotOjoDer, RotateTransform.AngleProperty, -rot, dur);
        AnimarA(trasOjoIzq, TranslateTransform.YProperty, dy, dur); AnimarA(trasOjoDer, TranslateTransform.YProperty, dy, dur);
    }

    static void AnimarA(DependencyObject obj, DependencyProperty prop, double hasta, int ms)
    {
        var a = new DoubleAnimation(hasta, TimeSpan.FromMilliseconds(ms));
        a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
        ((IAnimatable)obj).BeginAnimation(prop, a);
    }

    static LinearGradientBrush Mascara(double ini, double fin)
    {
        var m = new LinearGradientBrush();
        m.StartPoint = new Point(0, 0); m.EndPoint = new Point(1, 0);
        m.GradientStops.Add(new GradientStop(Color.FromArgb(ini > 0 ? (byte)0x00 : (byte)0xFF, 0, 0, 0), 0));
        m.GradientStops.Add(new GradientStop(Color.FromArgb(0xFF, 0, 0, 0), Math.Max(0, ini)));
        m.GradientStops.Add(new GradientStop(Color.FromArgb(0xFF, 0, 0, 0), Math.Min(1, fin)));
        m.GradientStops.Add(new GradientStop(Color.FromArgb(fin < 1 ? (byte)0x00 : (byte)0xFF, 0, 0, 0), 1));
        m.Freeze();
        return m;
    }

    static ImageBrush CrearGrano()
    {
        const int n = 96;
        var wb = new WriteableBitmap(n, n, 96, 96, PixelFormats.Bgra32, null);
        var px = new byte[n * n * 4];
        var r = new Random(7);
        for (int i = 0; i < n * n; i++)
        {
            byte v = (byte)r.Next(0, 256);
            px[i * 4] = v; px[i * 4 + 1] = v; px[i * 4 + 2] = v; px[i * 4 + 3] = 255;
        }
        wb.WritePixels(new Int32Rect(0, 0, n, n), px, n * 4, 0);
        var b = new ImageBrush(wb);
        b.TileMode = TileMode.Tile;
        b.ViewportUnits = BrushMappingMode.Absolute;
        b.Viewport = new Rect(0, 0, n, n);
        RenderOptions.SetBitmapScalingMode(b, BitmapScalingMode.NearestNeighbor);
        return b;
    }

    // ---------------------------------------------------------------
    // Sonidos sintetizados en memoria, cortos y suaves
    // ---------------------------------------------------------------
    static SoundPlayer Tono(double amplitud, params double[] notasYms)
    {
        const int tasa = 22050;
        var muestras = new List<short>();
        for (int k = 0; k + 1 < notasYms.Length; k += 2)
        {
            double f = notasYms[k];
            int n = (int)(tasa * notasYms[k + 1] / 1000.0);
            for (int i = 0; i < n; i++)
            {
                double t = (double)i / tasa;
                double env = Math.Min(1.0, i / (tasa * 0.005)) * (1.0 - (double)i / n);
                double v = Math.Sin(2 * Math.PI * f * t) * 0.8 + Math.Sin(2 * Math.PI * f * 2 * t) * 0.2;
                muestras.Add((short)(v * env * amplitud * 32767));
            }
        }
        int bytes = muestras.Count * 2;
        var ms = new MemoryStream();
        var w = new BinaryWriter(ms);
        w.Write(new[] { 'R', 'I', 'F', 'F' }); w.Write(36 + bytes); w.Write(new[] { 'W', 'A', 'V', 'E' });
        w.Write(new[] { 'f', 'm', 't', ' ' }); w.Write(16); w.Write((short)1); w.Write((short)1);
        w.Write(tasa); w.Write(tasa * 2); w.Write((short)2); w.Write((short)16);
        w.Write(new[] { 'd', 'a', 't', 'a' }); w.Write(bytes);
        foreach (var s in muestras) { w.Write(s); }
        w.Flush();
        ms.Position = 0;
        var sp = new SoundPlayer(ms);
        sp.Load();
        return sp;
    }

    void CrearSonidos()
    {
        try
        {
            sonDespierta = Tono(0.16, 523, 70, 784, 90);
            sonHecho = Tono(0.14, 988, 55);
            sonError = Tono(0.16, 220, 130);
            sonLogro = Tono(0.15, 659, 60, 880, 60, 1175, 110);
            sonAviso = Tono(0.15, 740, 80, 740, 80);
            sonTic = Tono(0.07, 1320, 25);
            sonSuave = Tono(0.09, 660, 45);
        }
        catch { }
    }

    static void Sonar(SoundPlayer s)
    {
        try { if (s != null) { s.Play(); } } catch { }
    }

    // ---------------------------------------------------------------
    // Volumen del sistema (COM)
    // ---------------------------------------------------------------
    void IniciarVolumen()
    {
        try
        {
            var enumerador = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
            IMMDevice dispositivo;
            if (enumerador.GetDefaultAudioEndpoint(0, 0, out dispositivo) != 0) { volumen = null; return; }
            Guid iid = typeof(IAudioEndpointVolume).GUID;
            object o;
            if (dispositivo.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) { volumen = null; return; }
            volumen = (IAudioEndpointVolume)o;
            float v; bool m;
            volumen.GetMasterVolumeLevelScalar(out v);
            volumen.GetMute(out m);
            volAnterior = v; muteAnterior = m;
        }
        catch { volumen = null; }
    }

    void VigilarVolumen()
    {
        if (volumen == null)
        {
            if (++fallosVolumen % 40 == 0) { IniciarVolumen(); }
            return;
        }
        try
        {
            float v; bool m;
            if (volumen.GetMasterVolumeLevelScalar(out v) != 0 || volumen.GetMute(out m) != 0) { volumen = null; return; }
            bool cambio = (Math.Abs(v - volAnterior) > 0.005f) || (m != muteAnterior);
            volAnterior = v; muteAnterior = m;
            // glifos de Segoe MDL2 Assets: silencio, volumen 0 / medio / alto
            if (cambio) { MostrarNivel(m ? "" : (v < 0.01f ? "" : (v < 0.5f ? "" : "")), m ? 0 : v); }
        }
        catch { volumen = null; }
    }

    void MostrarNivel(string glifo, double valor)
    {
        if (estadoActual != "reposo" && estadoActual != "") { return; }
        if (Cine()) { return; }   // en el cine no se molesta
        Despertar();
        glifoNivel.Text = glifo;
        var anchoBarra = new DoubleAnimation(Math.Max(0, Math.Min(1, valor)) * 72, TimeSpan.FromMilliseconds(220));
        anchoBarra.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
        barraNivel.BeginAnimation(WidthProperty, anchoBarra);
        if (panelNivel.Visibility != Visibility.Visible)
        {
            panelNivel.Visibility = Visibility.Visible;
            Desvanecer(panelNivel, 1, 180);
            double fijo = (ALTO - AVATAR) / 2 + AVATAR + 16 + 2;
            Expandir(fijo + 12 + 15 + 10 + 72, true);
            EscalaFoco(false);
        }
        ocultarNivel.Stop();
        ocultarNivel.Start();
    }

    void CapturarFondo()
    {
        try
        {
            var src = PresentationSource.FromVisual(this);
            if (src == null) { return; }
            var m = src.CompositionTarget.TransformToDevice;
            Point origen = capsula.PointToScreen(new Point(0, 0));
            int x = (int)Math.Round(origen.X - RADIO_BLUR * m.M11);
            int y = (int)Math.Round(origen.Y - RADIO_BLUR * m.M22);
            int w = (int)Math.Round((ANCHO_BARRA + RADIO_BLUR * 2) * m.M11);
            int hgt = (int)Math.Round((ALTO + RADIO_BLUR * 2) * m.M22);
            if (w <= 0 || hgt <= 0) { return; }

            double opAntes = Opacity;
            Opacity = 0;
            Dispatcher.Invoke(DispatcherPriority.Render, new Action(delegate { }));
            Thread.Sleep(45);

            using (var bmp = new System.Drawing.Bitmap(w, hgt))
            {
                using (var g = System.Drawing.Graphics.FromImage(bmp))
                {
                    g.CopyFromScreen(x, y, 0, 0, new System.Drawing.Size(w, hgt));
                }
                IntPtr hb = bmp.GetHbitmap();
                try
                {
                    var bs = Imaging.CreateBitmapSourceFromHBitmap(hb, IntPtr.Zero, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                    bs.Freeze();
                    fondoDesenfocado.Source = bs;
                }
                finally { DeleteObject(hb); }
            }
            Opacity = opAntes;
        }
        catch { Opacity = 1; }
    }

    // ---------------------------------------------------------------
    // Vida basica: respiracion, parpadeo, saltos, ondas, chispas
    // ---------------------------------------------------------------
    static bool EsNoche() { int h = DateTime.Now.Hour; return h >= 22 || h < 7; }
    bool Noche() { return nocheActual || perfilActual == "noche"; }
    bool BateriaBaja() { return bateria <= 20 && !cargando; }
    bool Agitado() { return carga >= 85; }
    bool Desanimado() { return animo <= -0.3; }

    void Latido()
    {
        double periodo = Noche() ? 2600 : 1700;
        if (Desanimado()) { periodo = 2300; }
        if (humor == "contenta" && DateTime.UtcNow < humorHasta) { periodo *= 0.8; }
        if (humor == "cauta" && DateTime.UtcNow < humorHasta) { periodo *= 1.15; }
        if (Agitado()) { periodo = 1100; }
        if (BateriaBaja()) { periodo = 900; }
        if (dormido) { periodo = 4200; }
        if (calmaHasta && DateTime.UtcNow < calmaFin) { periodo = 3200; }
        double bajo = dormido ? 0.22 : 0.55, alto = dormido ? 0.45 : 1.0;
        var a = new DoubleAnimation(bajo, alto, TimeSpan.FromMilliseconds(periodo));
        a.AutoReverse = true;
        a.RepeatBehavior = RepeatBehavior.Forever;
        a.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
        punto.BeginAnimation(OpacityProperty, a);
        insignia.BeginAnimation(OpacityProperty, a);
    }

    void Parpadear()
    {
        if (punto.Visibility == Visibility.Visible)
        {
            // con ojos, parpadean los OJOS (y el punto apenas se aplasta)
            if (expresion == "cerrados") { return; }
            double baseY = (expresion == "entrecerrados") ? 0.45 : (expresion == "felices" ? 0.42 : (expresion == "cautos" ? 0.75 : (expresion == "abiertos" || expresion == "atentos" ? (expresion == "abiertos" ? 1.45 : 1.15) : 1.0)));
            var ko = new DoubleAnimationUsingKeyFrames();
            ko.KeyFrames.Add(new EasingDoubleKeyFrame(baseY, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            ko.KeyFrames.Add(new EasingDoubleKeyFrame(0.08, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(70)), new CubicEase { EasingMode = EasingMode.EaseIn }));
            ko.KeyFrames.Add(new EasingDoubleKeyFrame(baseY, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(170)), new CubicEase { EasingMode = EasingMode.EaseOut }));
            ko.FillBehavior = FillBehavior.Stop;
            escOjoIzq.BeginAnimation(ScaleTransform.ScaleYProperty, ko);
            escOjoDer.BeginAnimation(ScaleTransform.ScaleYProperty, ko);
            var kp = new DoubleAnimationUsingKeyFrames();
            kp.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            kp.KeyFrames.Add(new EasingDoubleKeyFrame(0.93, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(80))));
            kp.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(190))));
            kp.FillBehavior = FillBehavior.Stop;
            escalaPunto.BeginAnimation(ScaleTransform.ScaleYProperty, kp);
            return;
        }
        var k = new DoubleAnimationUsingKeyFrames();
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        k.KeyFrames.Add(new EasingDoubleKeyFrame(0.12, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(85)), new CubicEase { EasingMode = EasingMode.EaseIn }));
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(200)), new CubicEase { EasingMode = EasingMode.EaseOut }));
        k.FillBehavior = FillBehavior.Stop;
        if (avatar.Visibility == Visibility.Visible) { (avatar.RenderTransform as ScaleTransform).BeginAnimation(ScaleTransform.ScaleYProperty, k); }
        if (avatarClima.Visibility == Visibility.Visible) { (avatarClima.RenderTransform as ScaleTransform).BeginAnimation(ScaleTransform.ScaleYProperty, k); }
    }

    void Saltar(double cuanto)
    {
        var a = new DoubleAnimation(cuanto, 1.0, TimeSpan.FromMilliseconds(650));
        a.EasingFunction = new ElasticEase { Oscillations = 2, Springiness = 4, EasingMode = EasingMode.EaseOut };
        a.FillBehavior = FillBehavior.Stop;
        escalaPunto.BeginAnimation(ScaleTransform.ScaleXProperty, a);
        escalaPunto.BeginAnimation(ScaleTransform.ScaleYProperty, a);
        foreach (var fe in new FrameworkElement[] { avatar, avatarClima })
        {
            if (fe.Visibility != Visibility.Visible) { continue; }
            var s = fe.RenderTransform as ScaleTransform;
            s.BeginAnimation(ScaleTransform.ScaleXProperty, a);
            s.BeginAnimation(ScaleTransform.ScaleYProperty, a);
        }
    }

    void Ondas(int cuantas, Color c)
    {
        for (int i = 0; i < Math.Min(cuantas, anillos.Length); i++)
        {
            var a = anillos[i];
            a.Stroke = new SolidColorBrush(c);
            var s = a.RenderTransform as ScaleTransform;
            var esc = new DoubleAnimation(0.9, 3.1, TimeSpan.FromMilliseconds(750));
            esc.BeginTime = TimeSpan.FromMilliseconds(i * 190);
            esc.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
            esc.FillBehavior = FillBehavior.Stop;
            var op = new DoubleAnimationUsingKeyFrames();
            op.BeginTime = esc.BeginTime;
            op.KeyFrames.Add(new LinearDoubleKeyFrame(0.95, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(750))));
            op.FillBehavior = FillBehavior.Stop;
            s.BeginAnimation(ScaleTransform.ScaleXProperty, esc);
            s.BeginAnimation(ScaleTransform.ScaleYProperty, esc);
            a.BeginAnimation(OpacityProperty, op);
        }
    }

    void Chispas(Color c)
    {
        foreach (var ch in chispas)
        {
            double ang = azar.NextDouble() * Math.PI * 2;
            double d = 15 + azar.NextDouble() * 12;
            ch.Fill = new SolidColorBrush(azar.NextDouble() < 0.5 ? Colors.White : c);
            var tr = ch.RenderTransform as TranslateTransform;
            var ax = new DoubleAnimation(0, Math.Cos(ang) * d, TimeSpan.FromMilliseconds(520));
            var ay = new DoubleAnimation(0, Math.Sin(ang) * d, TimeSpan.FromMilliseconds(520));
            ax.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
            ay.EasingFunction = ax.EasingFunction;
            ax.FillBehavior = FillBehavior.Stop; ay.FillBehavior = FillBehavior.Stop;
            var op = new DoubleAnimationUsingKeyFrames();
            op.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            op.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(180))));
            op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(520))));
            op.FillBehavior = FillBehavior.Stop;
            tr.BeginAnimation(TranslateTransform.XProperty, ax);
            tr.BeginAnimation(TranslateTransform.YProperty, ay);
            ch.BeginAnimation(OpacityProperty, op);
        }
    }

    // firma de arranque: las chispas dibujan una "N" y se apagan
    void FirmaN()
    {
        double[][] trazos = {
            new double[] { -8, 9, -8, -9 },   // palo izquierdo, de abajo arriba
            new double[] { -8, -9, 8, 9 },    // diagonal
            new double[] { 8, 9, 8, -9 }      // palo derecho
        };
        for (int i = 0; i < chispas.Length; i++)
        {
            var ch = chispas[i];
            int trazo = i / 2;
            if (trazo >= trazos.Length) { break; }
            double[] t = trazos[trazo];
            double f0 = (i % 2) * 0.5, f1 = f0 + 0.5;   // cada chispa recorre media linea
            var tr = ch.RenderTransform as TranslateTransform;
            ch.Fill = new SolidColorBrush(ColorDe("reposo"));
            var inicio = TimeSpan.FromMilliseconds(trazo * 260 + (i % 2) * 130);
            var ax = new DoubleAnimation(t[0] + (t[2] - t[0]) * f0, t[0] + (t[2] - t[0]) * f1, TimeSpan.FromMilliseconds(260));
            var ay = new DoubleAnimation(t[1] + (t[3] - t[1]) * f0, t[1] + (t[3] - t[1]) * f1, TimeSpan.FromMilliseconds(260));
            ax.BeginTime = inicio; ay.BeginTime = inicio;
            ax.FillBehavior = FillBehavior.Stop; ay.FillBehavior = FillBehavior.Stop;
            var op = new DoubleAnimationUsingKeyFrames();
            op.BeginTime = inicio;
            op.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
            op.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(420))));
            op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(800))));
            op.FillBehavior = FillBehavior.Stop;
            tr.BeginAnimation(TranslateTransform.XProperty, ax);
            tr.BeginAnimation(TranslateTransform.YProperty, ay);
            ch.BeginAnimation(OpacityProperty, op);
        }
    }

    void MarcarHecho()
    {
        Color c = ColorDe(estadoActual == "" ? "reposo" : estadoActual);
        var flash = new ColorAnimation(Colors.White, c, TimeSpan.FromMilliseconds(420));
        flash.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
        (punto.Fill as SolidColorBrush).BeginAnimation(SolidColorBrush.ColorProperty, flash);
        (insignia.Fill as SolidColorBrush).BeginAnimation(SolidColorBrush.ColorProperty, flash);
        var k = new DoubleAnimationUsingKeyFrames();
        k.KeyFrames.Add(new LinearDoubleKeyFrame(0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        k.KeyFrames.Add(new LinearDoubleKeyFrame(1, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(110))));
        k.KeyFrames.Add(new LinearDoubleKeyFrame(1, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(650))));
        k.KeyFrames.Add(new LinearDoubleKeyFrame(0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(900))));
        k.FillBehavior = FillBehavior.Stop;
        marcaHecho.BeginAnimation(OpacityProperty, k);
        Saltar(1.35);
        Ondas(1, c);
        Sonar(sonHecho);
    }

    void Sacudir()
    {
        var k = new DoubleAnimationUsingKeyFrames();
        double[] xs = { 0, -7, 6, -4, 3, -1, 0 };
        for (int i = 0; i < xs.Length; i++)
        {
            k.KeyFrames.Add(new EasingDoubleKeyFrame(xs[i], KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(i * 65)), new SineEase { EasingMode = EasingMode.EaseInOut }));
        }
        k.FillBehavior = FillBehavior.Stop;
        sacudida.BeginAnimation(TranslateTransform.XProperty, k);
        Sonar(sonError);
    }

    void Logro()
    {
        Color oro = Color.FromRgb(0xFF, 0xD3, 0x6A);
        Color c = ColorDe(estadoActual == "" ? "reposo" : estadoActual);
        foreach (var b in new[] { punto.Fill, insignia.Fill, aroAvatar.Stroke })
        {
            var sb = b as SolidColorBrush;
            if (sb == null) { continue; }
            var k = new ColorAnimationUsingKeyFrames();
            k.KeyFrames.Add(new LinearColorKeyFrame(oro, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(150))));
            k.KeyFrames.Add(new LinearColorKeyFrame(oro, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(1400))));
            k.KeyFrames.Add(new LinearColorKeyFrame(c, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(1900))));
            sb.BeginAnimation(SolidColorBrush.ColorProperty, k);
        }
        Saltar(1.5);
        Ondas(2, oro);
        Chispas(oro);
        Sonar(sonLogro);
    }

    void DestelloCarga()
    {
        Color verde = Color.FromRgb(0x3D, 0xF0, 0x9A);
        Color c = ColorDe(estadoActual == "" ? "reposo" : estadoActual);
        foreach (var b in new[] { punto.Fill, insignia.Fill })
        {
            var sb = b as SolidColorBrush;
            if (sb == null) { continue; }
            var k = new ColorAnimationUsingKeyFrames();
            k.KeyFrames.Add(new LinearColorKeyFrame(verde, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(200))));
            k.KeyFrames.Add(new LinearColorKeyFrame(c, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(800))));
            sb.BeginAnimation(SolidColorBrush.ColorProperty, k);
        }
    }

    void EntradaEnEscena()
    {
        escalaEnvoltorio.ScaleX = 0.2; escalaEnvoltorio.ScaleY = 0.2;
        envoltorio.Opacity = 0;
        var s = new DoubleAnimation(0.2, 1.0, TimeSpan.FromMilliseconds(700));
        s.EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = 0.7 };
        s.FillBehavior = FillBehavior.Stop;
        s.Completed += delegate { escalaEnvoltorio.ScaleX = 1; escalaEnvoltorio.ScaleY = 1; };
        escalaEnvoltorio.BeginAnimation(ScaleTransform.ScaleXProperty, s);
        escalaEnvoltorio.BeginAnimation(ScaleTransform.ScaleYProperty, s);
        envoltorio.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(400)));
        var t = new DispatcherTimer();
        t.Interval = TimeSpan.FromMilliseconds(350);
        t.Tick += delegate { t.Stop(); Ondas(2, ColorDe("reposo")); FirmaN(); };
        t.Start();
    }

    void SalidaDeEscena()
    {
        if (cerrando) { return; }
        cerrando = true;
        var sy = new DoubleAnimation(1.0, 0.04, TimeSpan.FromMilliseconds(220));
        sy.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseIn };
        var sx = new DoubleAnimation(1.0, 0.0, TimeSpan.FromMilliseconds(260));
        sx.BeginTime = TimeSpan.FromMilliseconds(200);
        sx.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseIn };
        sx.Completed += delegate { Application.Current.Shutdown(); };
        escalaEnvoltorio.BeginAnimation(ScaleTransform.ScaleYProperty, sy);
        escalaEnvoltorio.BeginAnimation(ScaleTransform.ScaleXProperty, sx);
        var t = new DispatcherTimer();
        t.Interval = TimeSpan.FromMilliseconds(900);
        t.Tick += delegate { Application.Current.Shutdown(); };
        t.Start();
    }

    // ---------------------------------------------------------------
    // Sueno
    // ---------------------------------------------------------------
    void Dormir()
    {
        dormido = true;
        Expresion("cerrados", 0);
        Latido();
        Desvanecer(esfera, 0.55, 1500);
        Desvanecer(capsula, 0.75, 1500);
        // se acomoda: se deja caer un poco y se ladea
        Anim(trasGesto, TranslateTransform.YProperty, 0, 1.5, 900, false);
        Anim(rotGesto, RotateTransform.AngleProperty, 0, -10, 900, false);
    }

    void Despertar()
    {
        ultimaActividad = DateTime.UtcNow;
        if (!dormido) { return; }
        dormido = false;
        Expresion("abiertos", 900);
        Latido();
        Desvanecer(esfera, 1, 300);
        Desvanecer(capsula, 1, 300);
        zeta.BeginAnimation(OpacityProperty, null);
        zeta.Opacity = 0;
        // estiramiento al despertar
        Anim(trasGesto, TranslateTransform.YProperty, 1.5, 0, 350, true);
        Anim(rotGesto, RotateTransform.AngleProperty, -10, 0, 350, true);
        var k = new DoubleAnimationUsingKeyFrames();
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.35, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(220)), new CubicEase { EasingMode = EasingMode.EaseOut }));
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(480)), new BackEase { EasingMode = EasingMode.EaseOut }));
        k.FillBehavior = FillBehavior.Stop;
        escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, k);
    }

    void Zeta()
    {
        var tr = zeta.RenderTransform as TranslateTransform;
        var ay = new DoubleAnimation(0, -12, TimeSpan.FromMilliseconds(2200));
        ay.EasingFunction = new SineEase { EasingMode = EasingMode.EaseOut };
        ay.FillBehavior = FillBehavior.Stop;
        var ax = new DoubleAnimation(0, 5, TimeSpan.FromMilliseconds(2200));
        ax.FillBehavior = FillBehavior.Stop;
        var op = new DoubleAnimationUsingKeyFrames();
        op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        op.KeyFrames.Add(new LinearDoubleKeyFrame(0.9, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(400))));
        op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(2200))));
        op.FillBehavior = FillBehavior.Stop;
        tr.BeginAnimation(TranslateTransform.YProperty, ay);
        tr.BeginAnimation(TranslateTransform.XProperty, ax);
        zeta.BeginAnimation(OpacityProperty, op);
    }

    // ---------------------------------------------------------------
    // GESTOS: la capsula reacciona a lo que dices (y a lo que ella dice)
    // ---------------------------------------------------------------
    static string Plano(string s)
    {
        if (string.IsNullOrEmpty(s)) { return ""; }
        string d = s.Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder();
        foreach (char ch in d)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark) { sb.Append(ch); }
        }
        return sb.ToString().ToLowerInvariant();
    }

    // Cada entrada: nombre del gesto y la expresion sobre el texto plano. El
    // orden importa: gana el primero que casa. Se evalua sobre lo NUEVO de la
    // transcripcion en vivo, y sobre la respuesta entera al empezar a hablar.
    // Incluye ingles y regionalismos (parce, wey, tio, che, chevere, bacano):
    // el mismo gesto para la misma intencion, digas como lo digas.
    static readonly string[][] GESTOS_USUARIO = {
        new[] { "carino",   @"\b(te quiero|te adoro|te amo|me encantas|eres (genial|la mejor|el mejor|increible|lo maximo|lo mejor|una crack|un crack)|buen trabajo|bien hecho|que linda|que lindo|love you|you rock|you're the best)\b" },
        new[] { "gracias",  @"\b(gracias|muchas gracias|mil gracias|perfecto|genial|excelente|estupendo|de lujo|brutal|chevere|bacano|thanks|thank you|ty|nice|great|awesome)\b" },
        new[] { "risa",     @"\b(ja+ja+|je+je+|jsjs|lol|lmao|xd|jiji)\b|jajaj|jeje" },
        new[] { "saludo",   @"^\s*(hola|holi|buenas|buenos dias|buenas tardes|buenas noches|que tal|que mas|que hubo|quiubo|que onda|que hay|hey|ey|hi|hello|what's up|whats up)\b" },
        new[] { "despedida",@"\b(adios|chao|chau|hasta luego|nos vemos|me voy|hasta manana|bye|see you|good night)\b" },
        new[] { "paciencia",@"^\s*(eh+|em+|mm+|hmm+|este|a ver|pues|bueno pues|osea|o sea|espera|espérate|esperate|un momento)\b" },
        new[] { "negar",    @"^\s*(no|nop|nel|nah|nope|no way|cancela|cancelalo|para|parate|olvidalo|dejalo|nada|asi no|eso no)\b" },
        new[] { "asentir",  @"^\s*(si|sip|dale|vale|claro|ok|okey|okay|yes|yeah|yep|sale|va|de una|listo|eso|exacto|correcto|hazlo)\b" },
        new[] { "reverencia", @"\b(por favor|porfa|porfis|plis|please|te pido|si puedes|serias tan amable)\b" },
        new[] { "prisa",    @"\b(rapido|ya|apurate|apura|corre|urgente|ahora mismo|de una|volando|hurry|quick|fast)\b" },
        new[] { "calma",    @"\b(despacio|tranquilo|tranqui|calma|sin prisa|con calma|relax|slow|easy)\b" },
        new[] { "disculpa", @"\b(perdon|lo siento|disculpa|disculpame|mi error|me equivoque|sorry|my bad)\b" },
        // al principio del trozo nuevo, o tras "y" / coma: "abre steam y que hora es"
        new[] { "duda",     @"(^|\by\s+|,\s*)\s*(que|cual|cuales|como|por que|porque|donde|quien|cuanto|cuantos|cuando|sabes|crees|what|how|where|when|why)\b" },
        new[] { "atencion", @"\bnova\b" },
        new[] { "sueno",    @"\b(duerme|duermete|descansa|a dormir|silencio|callate|shh+|sleep)\b" },
        new[] { "sorpresa", @"\b(wow|guau|uy|oh|no puede ser|en serio|increible|que fuerte|omg|no manches|no jodas)\b" },
        new[] { "carino",   @"\b(parce|parcero|mano|manito|wey|guey|tio|che|bro|crack)\b.*\b(gracias|genial|bien|buena|buenisimo)\b|\b(gracias|genial|bien|buena|buenisimo)\b.*\b(parce|parcero|mano|manito|wey|guey|tio|che|bro|crack)\b" },
    };
    // complicidad con el juego: solo cuando hay un juego delante
    static readonly string[][] GESTOS_JUEGO = {
        new[] { "logro",  @"\b(lo logre|lo logramos|ganamos|gane|lo mate|lo matamos|lo pase|lo pasamos|por fin|victoria|gg|ez)\b" },
        new[] { "apoyo",  @"\b(voy a morir|me van a matar|me mataron|me mato|este jefe|otra vez|que dificil|no puedo|imposible|casi|ay no|ayuda|ayudame|vamos|dale que se puede)\b" },
    };
    static readonly string[][] GESTOS_PROPIOS = {
        new[] { "pena",     @"^\s*(no pude|no encontre|no se pudo|no supe|fallo|error|no te escuche|no tengo|no hay nada|no detecto|todavia no)\b" },
        new[] { "orgullo",  @"^\s*(listo|hecho|anotado|abriendo|encontre esto|anotaste|ahora se que)\b" },
        new[] { "duda",     @"^\s*\?|\?\s*$" },
        new[] { "carino",   @"\b(de nada|con gusto|un placer|para eso estoy)\b" },
    };

    void AnalizarTexto(string texto, bool propio)
    {
        string p = Plano(texto);
        if (p.Trim().Length == 0) { return; }
        if (propio)
        {
            foreach (var g in GESTOS_PROPIOS)
            {
                try { if (Regex.IsMatch(p, g[1])) { Gesto(g[0]); break; } } catch { }
            }
            Entonar(texto);
            return;
        }
        // 1) los gestos del usuario (config.json -> ui.gestos), que mandan
        foreach (var g in gestosExtra)
        {
            try { if (Regex.IsMatch(p, g[1])) { Gesto(g[0]); return; } } catch { }
        }
        // 2) complicidad con el juego
        if (!string.IsNullOrEmpty(juegoActual))
        {
            foreach (var g in GESTOS_JUEGO)
            {
                try { if (Regex.IsMatch(p, g[1])) { Gesto(g[0]); return; } } catch { }
            }
        }
        // 3) el vocabulario general
        foreach (var g in GESTOS_USUARIO)
        {
            try { if (Regex.IsMatch(p, g[1])) { Gesto(g[0]); return; } } catch { }
        }
    }

    // gestos propios del usuario: tmp\gestos.txt, una linea "gesto|patron",
    // lo escribe el asistente desde config.json -> ui.gestos
    void CargarGestosExtra()
    {
        try
        {
            if (string.IsNullOrEmpty(rutaGestosCfg) || !File.Exists(rutaGestosCfg)) { gestosExtra.Clear(); return; }
            var fecha = File.GetLastWriteTimeUtc(rutaGestosCfg);
            if (fecha == gestosExtraLeido) { return; }
            gestosExtraLeido = fecha;
            gestosExtra.Clear();
            foreach (var linea in File.ReadAllLines(rutaGestosCfg, Encoding.UTF8))
            {
                int sep = linea.IndexOf('|');
                if (sep <= 0) { continue; }
                string gesto = linea.Substring(0, sep).Trim().ToLowerInvariant();
                string patron = linea.Substring(sep + 1).Trim();
                if (gesto.Length == 0 || patron.Length == 0) { continue; }
                try { new Regex(patron); } catch { continue; }
                gestosExtra.Add(new[] { gesto, patron });
            }
        }
        catch { }
    }

    // entonacion visual de lo que ella dice: una pregunta arquea y sube la
    // mirada; cada cifra que dice es un tic
    void Entonar(string texto)
    {
        if (string.IsNullOrEmpty(texto)) { return; }
        string t = texto.Trim();
        if (t.EndsWith("?") || t.StartsWith("¿"))
        {
            rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, 7, 7, 7, 0 }, 450));
            miradaY -= 2.5;
        }
        int k = 0;
        foreach (char ch in t)
        {
            if (!char.IsDigit(ch)) { continue; }
            var t1 = new DispatcherTimer();
            t1.Interval = TimeSpan.FromMilliseconds(700 + k * 230);
            t1.Tick += delegate
            {
                t1.Stop();
                if (estadoActual != "hablando") { return; }
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.1, 1 }, 70));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.1, 1 }, 70));
            };
            t1.Start();
            if (++k >= 6) { break; }
        }
    }

    // ritmo: palabras por segundo de la transcripcion en vivo. Rapido, todo
    // se acelera (onda, parpadeo); pausado, todo se relaja.
    void MedirRitmo(string texto)
    {
        int palabras = texto.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries).Length;
        var ahora = DateTime.UtcNow;
        ritmo.Add(new KeyValuePair<DateTime, int>(ahora, palabras));
        ritmo.RemoveAll(delegate(KeyValuePair<DateTime, int> kv) { return (ahora - kv.Key).TotalSeconds > 5; });
        if (ritmo.Count < 3) { return; }
        var primero = ritmo[0];
        double segundos = (ahora - primero.Key).TotalSeconds;
        if (segundos < 1.5) { return; }
        double pps = (palabras - primero.Value) / segundos;
        if (prisaHasta != DateTime.MinValue) { return; }   // la prisa manda
        if (pps >= 3.0) { velocidadOnda = 0.75; }
        else if (pps > 0 && pps <= 1.2) { velocidadOnda = 0.28; }
        else { velocidadOnda = 0.45; }
    }

    // tono: gritar encoge y abre los ojos; susurrar acerca y baja el halo
    void MedirTono()
    {
        if (estadoActual != "escuchando") { gritoCuenta = 0; susurroCuenta = 0; return; }
        double n = nivelObjetivo;
        gritoCuenta = (n >= 0.97) ? gritoCuenta + 1 : 0;
        susurroCuenta = (n > 0.02 && n < 0.22) ? susurroCuenta + 1 : 0;
        if (DateTime.UtcNow < tonoHasta) { return; }
        if (gritoCuenta >= 3) { gritoCuenta = 0; Gesto("grito"); }
        else if (susurroCuenta >= 8 && textoActual.Length > 0) { susurroCuenta = 0; Gesto("susurro"); }
    }

    void Humor(string nuevo, int minutos)
    {
        humor = nuevo;
        humorHasta = DateTime.UtcNow.AddMinutes(minutos);
        Latido();
        double esc = (nuevo == "cauta") ? 0.92 : 1.0;
        var a = new DoubleAnimation(esc, TimeSpan.FromMilliseconds(600));
        a.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
        escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, a);
        escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, a);
        if (estadoActual == "reposo" || estadoActual == "") { Aplicar(estadoActual, textoActual, false); }
    }

    void AnotarGesto(string nombre)
    {
        try
        {
            if (string.IsNullOrEmpty(rutaGestosLog)) { return; }
            File.AppendAllText(rutaGestosLog, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + nombre + "\r\n", Encoding.UTF8);
        }
        catch { }
    }

    // anima una propiedad de una transformacion: de "desde" a "hasta"; si
    // "volver", regresa al valor de reposo al terminar (AutoReverse)
    static void Anim(DependencyObject obj, DependencyProperty prop, double desde, double hasta, int ms, bool volver)
    {
        var a = new DoubleAnimation(desde, hasta, TimeSpan.FromMilliseconds(ms));
        a.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
        if (volver) { a.AutoReverse = true; a.FillBehavior = FillBehavior.Stop; }
        else { a.FillBehavior = FillBehavior.HoldEnd; }
        ((IAnimatable)obj).BeginAnimation(prop, a);
    }

    static DoubleAnimationUsingKeyFrames Secuencia(double[] valores, int msPorPaso)
    {
        var k = new DoubleAnimationUsingKeyFrames();
        for (int i = 0; i < valores.Length; i++)
        {
            k.KeyFrames.Add(new EasingDoubleKeyFrame(valores[i], KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(i * msPorPaso)),
                new SineEase { EasingMode = EasingMode.EaseInOut }));
        }
        k.FillBehavior = FillBehavior.Stop;
        return k;
    }

    void Flotar(TextBlock glifo, double dx, double dy, int ms)
    {
        var tr = glifo.RenderTransform as TranslateTransform;
        var ax = new DoubleAnimation(0, dx, TimeSpan.FromMilliseconds(ms));
        var ay = new DoubleAnimation(0, dy, TimeSpan.FromMilliseconds(ms));
        ax.EasingFunction = new SineEase { EasingMode = EasingMode.EaseOut };
        ay.EasingFunction = ax.EasingFunction;
        ax.FillBehavior = FillBehavior.Stop; ay.FillBehavior = FillBehavior.Stop;
        var op = new DoubleAnimationUsingKeyFrames();
        op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        op.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(ms * 0.15))));
        op.KeyFrames.Add(new LinearDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(ms * 0.6))));
        op.KeyFrames.Add(new LinearDoubleKeyFrame(0.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(ms))));
        op.FillBehavior = FillBehavior.Stop;
        tr.BeginAnimation(TranslateTransform.XProperty, ax);
        tr.BeginAnimation(TranslateTransform.YProperty, ay);
        glifo.BeginAnimation(OpacityProperty, op);
    }

    void Sonrojo(Color hacia, int ms)
    {
        Color c = ColorDe(estadoActual == "" ? "reposo" : estadoActual);
        foreach (var b in new[] { punto.Fill, insignia.Fill, aroAvatar.Stroke })
        {
            var sb = b as SolidColorBrush;
            if (sb == null) { continue; }
            var k = new ColorAnimationUsingKeyFrames();
            k.KeyFrames.Add(new LinearColorKeyFrame(hacia, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(200))));
            k.KeyFrames.Add(new LinearColorKeyFrame(hacia, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(ms - 400))));
            k.KeyFrames.Add(new LinearColorKeyFrame(c, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(ms))));
            sb.BeginAnimation(SolidColorBrush.ColorProperty, k);
        }
    }

    void Gesto(string nombre)
    {
        DateTime ultimo;
        if (ultimoGesto.TryGetValue(nombre, out ultimo) && (DateTime.UtcNow - ultimo).TotalMilliseconds < 1500) { return; }
        ultimoGesto[nombre] = DateTime.UtcNow;
        Despertar();
        var ahora = DateTime.UtcNow;

        // --- encadenados: el gesto depende del anterior ---
        if (nombre == "gracias" && ultimoGestoNombre == "pena" && (ahora - ultimoGestoHora).TotalSeconds < 25) { nombre = "alivio"; }
        if (nombre == "pena") { ultimaPena = ahora; }

        // --- humor de minutos ---
        if (nombre == "carino" || nombre == "gracias" || nombre == "logro") { Humor("contenta", 2); }
        if (nombre == "negar")
        {
            negaciones.Add(ahora);
            negaciones.RemoveAll(delegate(DateTime d) { return (ahora - d).TotalSeconds > 60; });
            if (negaciones.Count >= 2) { Humor("cauta", 2); }
        }
        ultimoGestoNombre = nombre;
        ultimoGestoHora = ahora;
        AnotarGesto(nombre);

        // la expresion de los ojos acompana al gesto
        switch (nombre)
        {
            case "carino": case "gracias": case "risa": case "logro": case "alivio": case "apoyo": case "orgullo": Expresion("felices", 1700); break;
            case "duda": case "confuso": case "paciencia": case "perdida": Expresion("entrecerrados", 1300); break;
            case "sorpresa": case "grito": case "sobresalto": case "atencion": Expresion("abiertos", 900); break;
            case "pena": case "despedida": Expresion("tristes", 1900); break;
            case "calma": case "susurro": Expresion("entrecerrados", 2500); break;
        }

        switch (nombre)
        {
            case "perdida":
                // mira a un lado y a otro: "¿por donde iba?"
                trasGesto.BeginAnimation(TranslateTransform.XProperty, Secuencia(new double[] { 0, -3, 3, -3, 3, 0 }, 260));
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, -8, 8, -8, 8, 0 }, 260));
                Flotar(pregunta, 2, -6, 1600);
                break;
            case "alivio":
                // suspiro: se hincha, aguanta y suelta
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.18, 1.18, 0.96, 1 }, 260));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.18, 1.18, 0.96, 1 }, 260));
                Sonrojo(Color.FromRgb(0xC8, 0xF0, 0xDC), 1400);
                Sonar(sonSuave);
                break;
            case "determinacion":
                // se aprieta y brilla: "esta vez si"
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 0.88, 0.88, 1.08, 1 }, 150));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 0.88, 0.88, 1.08, 1 }, 150));
                Sonrojo(Colors.White, 900);
                Ondas(1, Colors.White);
                break;
            case "paciencia":
                // parpadeo lento y mirada hacia arriba: "te espero"
                miradaY -= 3;
                escalaPunto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 0.2, 0.2, 1 }, 220));
                break;
            case "apoyo":
                // se acerca y brilla: "vamos, tu puedes"
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.15, 1.15, 1 }, 300));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.15, 1.15, 1 }, 300));
                Sonrojo(Color.FromRgb(0xFF, 0xD3, 0x6A), 1500);
                Ondas(1, Color.FromRgb(0xFF, 0xD3, 0x6A));
                Sonar(sonSuave);
                break;
            case "logro":
                Logro();
                break;
            case "lotengo":
                // "ya se lo que quieres": asentimiento anticipado y destello
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 2, 0 }, 120));
                Sonrojo(Colors.White, 500);
                Sonar(sonTic);
                break;
            case "grito":
                tonoHasta = ahora.AddSeconds(2);
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 0.85, 0.85, 0.85, 1 }, 350));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 0.85, 0.85, 0.85, 1 }, 350));
                // ojos como platos: el reflejo se agranda
                reflejoPunto.BeginAnimation(WidthProperty, Secuencia(new double[] { DIAM_PUNTO * 0.45, DIAM_PUNTO * 0.7, DIAM_PUNTO * 0.7, DIAM_PUNTO * 0.45 }, 350));
                reflejoPunto.BeginAnimation(HeightProperty, Secuencia(new double[] { DIAM_PUNTO * 0.32, DIAM_PUNTO * 0.5, DIAM_PUNTO * 0.5, DIAM_PUNTO * 0.32 }, 350));
                break;
            case "susurro":
                tonoHasta = ahora.AddSeconds(3);
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.1, 1.1, 1.1, 1 }, 500));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.1, 1.1, 1.1, 1 }, 500));
                resplandor.BeginAnimation(DropShadowEffect.OpacityProperty, Secuencia(new double[] { 0.5, 0.2, 0.2, 0.2, 0.5 }, 500));
                break;
            case "escucho":
                // asentimiento suave mientras sigue una frase larga
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 1.6, 0 }, 180));
                break;
            case "asentir":
                // dos cabeceos cortos
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 2.5, 0, 2.5, 0 }, 110));
                break;
            case "negar":
                // un circulo girado no se nota: el giro va acompanado de un
                // vaiven horizontal para que se vea tambien sin avatar
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, -14, 12, -8, 5, 0 }, 90));
                trasGesto.BeginAnimation(TranslateTransform.XProperty, Secuencia(new double[] { 0, -3, 3, -2, 1, 0 }, 90));
                break;
            case "saludo":
                // se inclina a un lado y a otro, como quien saluda con la mano
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, 16, -12, 16, -8, 0 }, 130));
                trasGesto.BeginAnimation(TranslateTransform.XProperty, Secuencia(new double[] { 0, 2.5, -2, 2.5, -1.5, 0 }, 130));
                Saltar(1.2);
                Sonar(sonSuave);
                break;
            case "despedida":
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, 14, -10, 12, 0 }, 150));
                Sonrojo(Color.FromRgb(0xC8, 0xD8, 0xFF), 1800);
                break;
            case "gracias":
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 2, 0, 2, 0 }, 120));
                Sonrojo(Color.FromRgb(0xFF, 0x9A, 0xC0), 1600);
                Sonar(sonSuave);
                break;
            case "carino":
                Sonrojo(Color.FromRgb(0xFF, 0x7A, 0xA8), 2400);
                Flotar(corazon, 6, -18, 1600);
                Saltar(1.25);
                Sonar(sonSuave);
                break;
            case "risa":
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 0.85, 1.1, 0.85, 1.1, 0.9, 1 }, 70));
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 1.5, -1.5, 1.5, -1.5, 0 }, 70));
                break;
            case "reverencia":
                // se inclina hacia delante (se aplasta un poco y baja) y vuelve
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 0.82, 0.82, 1 }, 220));
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 2.5, 2.5, 0 }, 220));
                break;
            case "prisa":
                prisaHasta = DateTime.UtcNow.AddSeconds(3);
                velocidadOnda = 0.9;
                sacudida.BeginAnimation(TranslateTransform.XProperty, Secuencia(new double[] { 0, -2, 2, -2, 2, -1, 1, 0 }, 35));
                break;
            case "calma":
                calmaHasta = true; calmaFin = DateTime.UtcNow.AddSeconds(12);
                Latido();
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.12, 1 }, 900));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.12, 1 }, 900));
                break;
            case "disculpa":
                // un "oh": se estira hacia arriba y se relaja
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 0.9, 1 }, 260));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.15, 1 }, 260));
                break;
            case "duda":
                // ladea la cabeza y le sale un "?"
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, 13, 13, 13, 0 }, 350));
                Flotar(pregunta, 2, -6, 1500);
                break;
            case "confuso":
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, -12, 12, -12, 0 }, 200));
                Flotar(pregunta, 2, -6, 1400);
                break;
            case "atencion":
                Saltar(1.3);
                break;
            case "sueno":
                ultimaActividad = DateTime.UtcNow.AddMinutes(-31);
                break;
            case "sorpresa":
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.3, 1 }, 160));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.3, 1 }, 160));
                Ondas(1, Colors.White);
                break;
            case "sobresalto":
                // salta hacia atras (arriba) y se queda un instante encogida
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, -5, -5, 0 }, 120));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 0.85, 0.85, 1 }, 120));
                break;
            case "pena":
                // se deja caer un poco y el halo se apaga
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, 2.5, 2.5, 2.5, 0 }, 500));
                rotGesto.BeginAnimation(RotateTransform.AngleProperty, Secuencia(new double[] { 0, -8, -8, -8, 0 }, 500));
                break;
            case "orgullo":
                escalaGesto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.15, 1 }, 300));
                escalaGesto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.15, 1 }, 300));
                trasGesto.BeginAnimation(TranslateTransform.YProperty, Secuencia(new double[] { 0, -2, 0 }, 300));
                break;
        }
    }

    void Evento(string nombre)
    {
        string arg = "";
        int dp = nombre.IndexOf(':');
        if (dp > 0) { arg = nombre.Substring(dp + 1); nombre = nombre.Substring(0, dp); }
        Despertar();
        switch (nombre)
        {
            case "despierta":
                Saltar(1.6);
                Ondas(2, ColorDe("escuchando"));
                Chispas(ColorDe("escuchando"));
                Sonar(sonDespierta);
                break;
            case "hecho": MarcarHecho(); break;
            case "aviso":
                Saltar(1.4);
                Ondas(2, ColorDe("pensando"));
                Sonar(sonAviso);
                break;
            case "logro": Logro(); break;
            case "error": Sacudir(); break;
            case "gesto": Gesto(arg); break;
            case "brillo":
                {
                    double v;
                    if (double.TryParse(arg, NumberStyles.Any, CultureInfo.InvariantCulture, out v)) { MostrarNivel("", v / 100.0); }
                    break;
                }
        }
    }

    // ---------------------------------------------------------------
    // Mirada y presencia
    // ---------------------------------------------------------------
    void Mirar()
    {
        double ox = 0, oy = 0;
        bool cercaAhora = false;
        try
        {
            PUNTO p;
            if (GetCursorPos(out p))
            {
                if (p.X != raton.X || p.Y != raton.Y) { raton = new Point(p.X, p.Y); ratonMovido = DateTime.UtcNow; }
            }
            Point objetivo = new Point(double.NaN, double.NaN);
            if ((DateTime.UtcNow - ratonMovido).TotalSeconds < 8) { objetivo = raton; }
            else
            {
                IntPtr h = GetForegroundWindow();
                RECTA r;
                if (h != IntPtr.Zero && h != hwnd && GetWindowRect(h, out r) && r.R > r.L && r.B > r.T)
                {
                    objetivo = new Point((r.L + r.R) / 2.0, (r.T + r.B) / 2.0);
                }
            }
            Point centro = esfera.PointToScreen(new Point(AVATAR / 2, AVATAR / 2));
            if (!double.IsNaN(objetivo.X))
            {
                double dx = objetivo.X - centro.X, dy = objetivo.Y - centro.Y;
                double dist = Math.Sqrt(dx * dx + dy * dy);
                double alcance = cerca ? 3.4 : 2.4;
                if (dist > 30)
                {
                    ox = dx / dist * alcance;
                    oy = dy / dist * alcance * 0.66;
                }
            }
            // presencia: el raton junto a la capsula (60 px) enciende el halo
            double dxr = raton.X - centro.X, dyr = raton.Y - centro.Y;
            double ancho = capsula.ActualWidth;
            double cx = Math.Max(0, Math.Min(ancho, dxr));   // distancia al segmento de la capsula
            double dd = Math.Sqrt((dxr - cx) * (dxr - cx) + dyr * dyr);
            cercaAhora = dd < 60 && (DateTime.UtcNow - ratonMovido).TotalSeconds < 20;
        }
        catch { }
        miradaX += (ox - miradaX) * 0.18;
        miradaY += (oy - miradaY) * 0.18;
        mirada.X = miradaX * 0.5;
        mirada.Y = miradaY * 0.5;
        // los ojos miran mas que el reflejo
        trasOjoIzq.X = miradaX * 1.1; trasOjoDer.X = miradaX * 1.1;
        if (expresion == "normal" || expresion == "atentos" || expresion == "abiertos" || expresion == "cautos" || expresion == "entrecerrados")
        {
            // (la Y de la expresion la lleva la animacion; aqui solo si no hay desplazamiento propio)
        }
        if (Cine()) { cercaAhora = false; }
        if (cercaAhora != cerca)
        {
            cerca = cercaAhora;
            if (estadoActual == "reposo" || estadoActual == "" || estadoActual == "escuchando")
            {
                var op = new DoubleAnimation(cerca ? 0.95 : 0.5, TimeSpan.FromMilliseconds(350));
                var rad = new DoubleAnimation(cerca ? 34 : 24, TimeSpan.FromMilliseconds(350));
                resplandor.BeginAnimation(DropShadowEffect.OpacityProperty, op);
                resplandor.BeginAnimation(DropShadowEffect.BlurRadiusProperty, rad);
                if (cerca) { Despertar(); Saltar(1.15); }
            }
        }
    }

    // ---------------------------------------------------------------
    // Foco (pantalla completa) y apartarse de ventanas que la tapan
    // ---------------------------------------------------------------
    void VigilarVentanas()
    {
        try
        {
            IntPtr h = GetForegroundWindow();
            if (h == IntPtr.Zero || h == hwnd) { AjustarFoco(false); AjustarApartada(false); return; }
            var sb = new StringBuilder(64);
            GetClassName(h, sb, 64);
            string clase = sb.ToString();
            if (clase == "Progman" || clase == "WorkerW" || clase == "Shell_TrayWnd" || clase == "Windows.UI.Core.CoreWindow")
            {
                AjustarFoco(false); AjustarApartada(false); return;
            }
            RECTA r;
            if (!GetWindowRect(h, out r)) { return; }
            var src = PresentationSource.FromVisual(this);
            double esc = (src != null) ? src.CompositionTarget.TransformToDevice.M11 : 1.0;
            double anchoPantalla = SystemParameters.PrimaryScreenWidth * esc;
            double altoPantalla = SystemParameters.PrimaryScreenHeight * esc;
            bool completa = r.L <= 0 && r.T <= 0 && r.R >= anchoPantalla - 1 && r.B >= altoPantalla - 1;
            AjustarFoco(completa);
            if (completa) { AjustarApartada(false); return; }
            // una ventana maximizada tapa toda la pantalla: no hay sitio libre
            // al que apartarse, asi que se queda en su esquina
            double area = Math.Max(0, Math.Min(r.R, anchoPantalla) - Math.Max(r.L, 0)) * Math.Max(0, Math.Min(r.B, altoPantalla) - Math.Max(r.T, 0));
            if (area >= 0.9 * anchoPantalla * altoPantalla) { AjustarApartada(false); return; }
            // ¿tapa la ventana la capsula (en su sitio base)?
            double capX = (leftBase + MARGEN) * esc, capY = (Top + MARGEN) * esc;
            double capW = ALTO * esc, capH = ALTO * esc;
            bool tapa = r.L < capX + capW && r.R > capX && r.T < capY + capH && r.B > capY;
            AjustarApartada(tapa);
        }
        catch { }
    }

    void AjustarFoco(bool completa)
    {
        // histeresis: 1 s seguido (4 muestras) antes de cambiar
        focoCuenta = completa ? Math.Min(4, focoCuenta + 1) : Math.Max(0, focoCuenta - 1);
        bool nuevo = completa ? focoCuenta >= 4 : focoCuenta > 0;
        if (nuevo != foco)
        {
            foco = nuevo;
            EscalaFoco(foco && (estadoActual == "reposo" || estadoActual == ""));
        }
    }

    // en foco y reposo, la capsula se encoge a la mitad (un punto de 22 px)
    void EscalaFoco(bool pequena)
    {
        double destino = pequena ? 0.5 : 1.0;
        var a = new DoubleAnimation(destino, TimeSpan.FromMilliseconds(420));
        a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut };
        escalaEnvoltorio.BeginAnimation(ScaleTransform.ScaleXProperty, a);
        escalaEnvoltorio.BeginAnimation(ScaleTransform.ScaleYProperty, a);
    }

    void AjustarApartada(bool tapa)
    {
        tapadaCuenta = tapa ? Math.Min(4, tapadaCuenta + 1) : Math.Max(0, tapadaCuenta - 1);
        bool nuevo = tapa ? tapadaCuenta >= 4 : tapadaCuenta > 0;
        if (nuevo == apartada) { return; }
        apartada = nuevo;
        double destino = leftBase;
        if (apartada)
        {
            // se desliza a la derecha hasta el borde de la ventana que la tapa,
            // sin salirse de la pantalla
            try
            {
                RECTA r; GetWindowRect(GetForegroundWindow(), out r);
                var src = PresentationSource.FromVisual(this);
                double esc = (src != null) ? src.CompositionTarget.TransformToDevice.M11 : 1.0;
                destino = r.R / esc + SEPARACION - MARGEN;
                double maximo = SystemParameters.PrimaryScreenWidth - ANCHO_BARRA - SEPARACION - MARGEN;
                if (destino > maximo) { destino = maximo; }
            }
            catch { destino = leftBase; }
        }
        var a = new DoubleAnimation(destino, TimeSpan.FromMilliseconds(520));
        a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut };
        BeginAnimation(LeftProperty, a);
    }

    // ---------------------------------------------------------------
    // Relojes
    // ---------------------------------------------------------------
    void Tic33()
    {
        if (onda.Visibility == Visibility.Visible)
        {
            if (prisaHasta != DateTime.MinValue && DateTime.UtcNow > prisaHasta) { prisaHasta = DateTime.MinValue; velocidadOnda = 0.45; }
            fase += velocidadOnda;
            nivelActual += (nivelObjetivo - nivelActual) * 0.22;
            double nivel = Math.Max(nivelActual, 0.18);
            for (int i = 0; i < barras.Length; i++)
            {
                double centro = 1.0 - Math.Abs(i - (barras.Length - 1) / 2.0) / ((barras.Length - 1) / 2.0);
                double oscila = 0.55 + 0.45 * Math.Sin(fase + i * 0.7);
                double h = 4 + (nivel * 26 * centro * oscila) + azar.NextDouble() * 2;
                if (h < 4) { h = 4; }
                if (h > 30) { h = 30; }
                barras[i].Height = h;
            }
        }

        if (estadoActual == "hablando")
        {
            var ahora = DateTime.UtcNow;
            if (envolvente != null)
            {
                double t = (ahora - envInicio).TotalMilliseconds - 300;
                int idx = (int)(t / 50);
                if (t < 0) { bocaObjetivo = 0; }
                else if (idx < envolvente.Length) { bocaObjetivo = envolvente[idx] * 0.5; }
                else { bocaObjetivo = 0; }
                // ecualizador: bandas pseudo-espectrales sobre la envolvente
                double e = bocaObjetivo * 2;
                double tt = (ahora - envInicio).TotalMilliseconds / 1000.0;
                for (int i = 0; i < bandas.Length; i++)
                {
                    double mod = 0.55 + 0.45 * Math.Sin(tt * (7 + i * 3.1) + i * 1.3);
                    double h = 1.5 + e * mod * 7.5;
                    bandas[i].Height = Math.Max(1.5, Math.Min(9, h));
                }
                if (ecualizador.Opacity < 0.05) { Desvanecer(ecualizador, 1, 200); }
            }
            else if (ahora >= proximaSilaba)
            {
                bocaObjetivo = azar.NextDouble() < 0.25 ? 0.0 : 0.12 + azar.NextDouble() * 0.33;
                proximaSilaba = ahora.AddMilliseconds(80 + azar.NextDouble() * 130);
            }
            boca += (bocaObjetivo - boca) * 0.45;
            resplandor.Opacity = 0.45 + boca * 0.9;
        }
        else
        {
            if (ecualizador.Opacity > 0.05) { Desvanecer(ecualizador, 0, 200); }
            if (boca > 0.001)
            {
                boca *= 0.8;
                if (boca < 0.001) { boca = 0; }
            }
            else { return; }
        }
        escalaPunto.ScaleX = 1 + boca;
        escalaPunto.ScaleY = 1 + boca;
        foreach (var fe in new FrameworkElement[] { avatar, avatarClima })
        {
            if (fe.Visibility != Visibility.Visible) { continue; }
            var s = fe.RenderTransform as ScaleTransform;
            s.ScaleX = 1 + boca * 0.5; s.ScaleY = 1 + boca * 0.5;
        }
    }

    void Tic250()
    {
        VigilarVolumen();
        VigilarVentanas();
        MedirTono();
        if (calmaHasta && DateTime.UtcNow >= calmaFin) { calmaHasta = false; Latido(); }
        if (humor != "" && DateTime.UtcNow >= humorHasta) { Humor("", 0); }
        if ((DateTime.UtcNow - gestosExtraLeido).TotalSeconds > 30) { CargarGestosExtra(); }
        // "te escucho": en frases largas, un asentimiento suave cada ~3,5 s
        if (estadoActual == "escuchando" && textoActual.Length > 0
            && (DateTime.UtcNow - escuchandoDesde).TotalSeconds >= 6
            && (DateTime.UtcNow - ultimoAsentimiento).TotalSeconds >= 3.5)
        {
            ultimoAsentimiento = DateTime.UtcNow;
            Gesto("escucho");
        }

        // --- temporizador ---
        if (tempoFin > 0 && tempoTotal > 0)
        {
            double ahora = (DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalMilliseconds;
            double resta = tempoFin - ahora;
            if (resta <= 0)
            {
                if (tempoActivo) { tempoActivo = false; anilloTempo.Opacity = 0; Ondas(2, ColorDe("pensando")); }
            }
            else
            {
                double progreso = Math.Max(0, Math.Min(1, resta / tempoTotal));
                DibujarArco(progreso);
                if (!tempoActivo) { tempoActivo = true; Desvanecer(anilloTempo, 0.9, 300); ultimoSegundo = -1; }
                // cuenta atras: en los ultimos 10 s, un latido del anillo y un
                // tic minimo del punto por cada segundo
                if (resta <= 10000)
                {
                    int seg = (int)Math.Ceiling(resta / 1000.0);
                    if (seg != ultimoSegundo)
                    {
                        ultimoSegundo = seg;
                        anilloTempo.BeginAnimation(Shape.StrokeThicknessProperty, Secuencia(new double[] { 2, 3.6, 2 }, 140));
                        escalaPunto.BeginAnimation(ScaleTransform.ScaleXProperty, Secuencia(new double[] { 1, 1.14, 1 }, 90));
                        escalaPunto.BeginAnimation(ScaleTransform.ScaleYProperty, Secuencia(new double[] { 1, 1.14, 1 }, 90));
                        Sonar(sonTic);
                    }
                }
            }
        }
        else if (tempoActivo) { tempoActivo = false; Desvanecer(anilloTempo, 0, 300); }

        // --- espera larga ---
        if (estadoActual == "pensando")
        {
            double s = (DateTime.UtcNow - pensandoDesde).TotalSeconds;
            if (!orbitando && s >= 20)
            {
                orbitando = true;
                MostrarPuntitos(false);
                Desvanecer(orbita, 1, 300);
                var g = new DoubleAnimation(0, 360, TimeSpan.FromMilliseconds(2400));
                g.RepeatBehavior = RepeatBehavior.Forever;
                giroOrbita.BeginAnimation(RotateTransform.AngleProperty, g);
                Aplicar(estadoActual, textoActual, false);
            }
            // a partir de 40 s, suda: una gota le resbala cada 8 s
            if (s >= 40 && (DateTime.UtcNow - ultimoSudor).TotalSeconds >= 8)
            {
                ultimoSudor = DateTime.UtcNow;
                Flotar(sudor, 1, 9, 1300);
            }
        }
    }

    void DibujarArco(double fraccion)
    {
        double r = (AVATAR + 8) / 2 - 1;
        double cx = (AVATAR + 8) / 2, cy = cx;
        if (fraccion >= 0.999) { fraccion = 0.999; }
        if (fraccion <= 0.002) { anilloTempo.Data = null; return; }
        double ang = fraccion * Math.PI * 2;
        Point ini = new Point(cx, cy - r);
        Point fin = new Point(cx + r * Math.Sin(ang), cy - r * Math.Cos(ang));
        var fig = new PathFigure();
        fig.StartPoint = ini;
        fig.Segments.Add(new ArcSegment(fin, new Size(r, r), 0, fraccion > 0.5, SweepDirection.Clockwise, true));
        var geo = new PathGeometry();
        geo.Figures.Add(fig);
        anilloTempo.Data = geo;
    }

    // ---------------------------------------------------------------
    // Estado
    // ---------------------------------------------------------------
    void LeerEstado()
    {
        string est = "reposo", txt = "", evento = "", juego = "", audio = "", perfil = "", clima = "";
        double niv = 0, tFin = 0, tTotal = 0, an = 0;
        int n = 0, bat = 100, carg = 0, cpu = 0;
        try
        {
            if (File.Exists(rutaEstado))
            {
                string j = File.ReadAllText(rutaEstado, System.Text.Encoding.UTF8);
                est = Campo(j, "estado", "reposo");
                txt = Campo(j, "texto", "");
                evento = Campo(j, "evento", "");
                juego = Campo(j, "juego", "");
                audio = Campo(j, "audio", "");
                perfil = Campo(j, "perfil", "");
                clima = Campo(j, "clima", "");
                double.TryParse(Campo(j, "nivel", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out niv);
                int.TryParse(Campo(j, "n", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out n);
                int.TryParse(Campo(j, "bateria", "100"), NumberStyles.Any, CultureInfo.InvariantCulture, out bat);
                int.TryParse(Campo(j, "cargando", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out carg);
                int.TryParse(Campo(j, "carga", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out cpu);
                double.TryParse(Campo(j, "tempoFin", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out tFin);
                double.TryParse(Campo(j, "tempoTotal", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out tTotal);
                double.TryParse(Campo(j, "animo", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out an);
                double pr; int vz;
                double.TryParse(Campo(j, "progreso", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out pr);
                int.TryParse(Campo(j, "voz", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out vz);
                if (vz != voz) { voz = vz; }
                if (Math.Abs(pr - progreso) > 0.005)
                {
                    progreso = pr;
                    double ancho = Math.Max(0, capsula.Width - ALTO * 0.8) * progreso;
                    AnimarA(lineaProgreso, WidthProperty, ancho, 500);
                    if (progreso <= 0) { AnimarA(lineaProgreso, OpacityProperty, 0, 300); }
                    else if (progreso >= 0.95)
                    {
                        var lat = new DoubleAnimation(0.35, 0.9, TimeSpan.FromMilliseconds(600));
                        lat.AutoReverse = true; lat.RepeatBehavior = RepeatBehavior.Forever;
                        lineaProgreso.BeginAnimation(OpacityProperty, lat);
                    }
                    else { AnimarA(lineaProgreso, OpacityProperty, 0.85, 300); }
                }
            }
        }
        catch { }
        if (expresion != "normal" && DateTime.UtcNow >= expresionHasta && !dormido) { Expresion("normal", 0); }

        if (est == "escuchando" && rutaNivel != null)
        {
            try
            {
                if (File.Exists(rutaNivel) && (DateTime.UtcNow - File.GetLastWriteTimeUtc(rutaNivel)).TotalSeconds < 1.0)
                {
                    double v;
                    if (double.TryParse(File.ReadAllText(rutaNivel).Trim(), NumberStyles.Any, CultureInfo.InvariantCulture, out v)) { niv = Math.Max(niv, v); }
                }
            }
            catch { }
        }
        nivelObjetivo = niv;
        tempoFin = tFin; tempoTotal = tTotal;

        bool repintar = false;
        bool bajaAntes = BateriaBaja(), agitadoAntes = Agitado(), desanimadoAntes = Desanimado();
        bateria = bat; cargando = (carg != 0); carga = cpu; animo = an;
        if (BateriaBaja() != bajaAntes || Agitado() != agitadoAntes || Desanimado() != desanimadoAntes) { Latido(); repintar = true; }
        if (perfil != perfilActual)
        {
            bool nocheAntes = Noche();
            perfilActual = perfil;
            if (Noche() != nocheAntes) { Latido(); repintar = true; }
        }
        if (juego != juegoActual || clima != climaActual)
        {
            juegoActual = juego;
            climaActual = clima;
            CargarAvatar(juego, clima);
        }
        if (audio != audioActual)
        {
            audioActual = audio;
            envolvente = CargarEnvolvente(audio);
            envInicio = DateTime.UtcNow;
        }

        if (est != estadoActual || txt != textoActual)
        {
            bool estabaEnReposo = (estadoActual == "" || estadoActual == "reposo");
            bool cambioTexto = (txt != textoActual);
            string textoAnterior = textoActual;
            string estadoAnterior = estadoActual;
            estadoActual = est;
            textoActual = txt;
            if (est != "reposo") { Despertar(); }
            if (estabaEnReposo && est != "reposo") { CapturarFondo(); }
            if (est == "escuchando" && estadoAnterior != "escuchando") { escuchandoDesde = DateTime.UtcNow; ultimoAsentimiento = DateTime.UtcNow; ritmo.Clear(); }
            if (est == "atenta") { escuchandoDesde = DateTime.UtcNow; }
            if (est != "escuchando" && estadoAnterior == "escuchando")
            {
                // fin de una orden: si repite la que acabo en pena, determinacion
                string orden = Plano(textoAnterior).Trim();
                if (orden.Length > 0 && orden == ultimaOrden && (DateTime.UtcNow - ultimaPena).TotalSeconds < 90) { Gesto("determinacion"); }
                if (orden.Length > 0) { ultimaOrden = orden; }
                if (prisaHasta == DateTime.MinValue) { velocidadOnda = 0.45; }
            }
            if (est == "pensando" && estadoAnterior != "pensando") { pensandoDesde = DateTime.UtcNow; ultimoSudor = DateTime.UtcNow; }
            if (est != "pensando" && orbitando) { orbitando = false; Desvanecer(orbita, 0, 200); giroOrbita.BeginAnimation(RotateTransform.AngleProperty, null); }
            if (est != "hablando") { envolvente = null; }
            if (estabaEnReposo != (est == "reposo")) { EscalaFoco(foco && est == "reposo"); }
            Aplicar(est, txt, cambioTexto, textoAnterior);
            if (est == "error") { Sacudir(); }
            // gestos: lo nuevo de la transcripcion, o la respuesta entera
            if (est == "escuchando" && cambioTexto)
            {
                string nuevo = (!string.IsNullOrEmpty(textoAnterior) && txt.StartsWith(textoAnterior, StringComparison.Ordinal)) ? txt.Substring(textoAnterior.Length) : txt;
                AnalizarTexto(nuevo, false);
                MedirRitmo(txt);
            }
            else if (est == "hablando" && cambioTexto) { AnalizarTexto(txt, true); }
        }
        else if (repintar) { Aplicar(est, txt, false); }

        if (n != eventoN)
        {
            bool primero = (eventoN == -1);
            eventoN = n;
            if (!primero && !string.IsNullOrEmpty(evento)) { Evento(evento); }
        }
    }

    static double[] CargarEnvolvente(string audio)
    {
        if (string.IsNullOrEmpty(audio)) { return null; }
        try
        {
            string env = audio + ".env";
            if (!File.Exists(env)) { return null; }
            var partes = File.ReadAllText(env).Split(new[] { ' ', '\n', '\r', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            var lista = new List<double>();
            foreach (var p in partes)
            {
                double v;
                if (double.TryParse(p, NumberStyles.Any, CultureInfo.InvariantCulture, out v)) { lista.Add(Math.Max(0, Math.Min(1, v))); }
            }
            return lista.Count > 0 ? lista.ToArray() : null;
        }
        catch { return null; }
    }

    // avatar: icono del juego si lo hay; si no, el tiempo (emoji); si no, el punto
    void CargarAvatar(string ruta, string clima)
    {
        BitmapSource bs = null;
        if (!string.IsNullOrEmpty(ruta) && File.Exists(ruta))
        {
            try
            {
                using (var ico = System.Drawing.Icon.ExtractAssociatedIcon(ruta))
                {
                    if (ico != null)
                    {
                        bs = Imaging.CreateBitmapSourceFromHIcon(ico.Handle, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                        bs.Freeze();
                    }
                }
            }
            catch { bs = null; }
        }
        bool conAvatar = (bs != null) || !string.IsNullOrEmpty(clima);
        avatar.Source = bs;
        avatar.Visibility = (bs != null) ? Visibility.Visible : Visibility.Collapsed;
        avatarClima.Text = clima ?? "";
        avatarClima.Visibility = (bs == null && !string.IsNullOrEmpty(clima)) ? Visibility.Visible : Visibility.Collapsed;
        avatarClima.Opacity = 1;
        aroAvatar.Visibility = conAvatar ? Visibility.Visible : Visibility.Collapsed;
        insignia.Visibility = conAvatar ? Visibility.Visible : Visibility.Collapsed;
        punto.Visibility = conAvatar ? Visibility.Collapsed : Visibility.Visible;
        reflejoPunto.Visibility = punto.Visibility;
        marcaHecho.Visibility = punto.Visibility;
        ecualizador.Visibility = punto.Visibility;
        // los ojos son del punto: sobre un icono de juego quedarian raros
        ojoIzq.Visibility = punto.Visibility;
        ojoDer.Visibility = punto.Visibility;
        if (conAvatar)
        {
            var fe = (bs != null) ? (FrameworkElement)avatar : avatarClima;
            var s = fe.RenderTransform as ScaleTransform;
            var a = new DoubleAnimation(0.2, 1.0, TimeSpan.FromMilliseconds(520));
            a.EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = 0.6 };
            a.FillBehavior = FillBehavior.Stop;
            s.BeginAnimation(ScaleTransform.ScaleXProperty, a);
            s.BeginAnimation(ScaleTransform.ScaleYProperty, a);
            Ondas(1, ColorDe(estadoActual == "" ? "reposo" : estadoActual));
        }
        else { Saltar(0.4); }
    }

    static string Campo(string json, string clave, string porDefecto)
    {
        string busca = "\"" + clave + "\"";
        int i = json.IndexOf(busca, StringComparison.Ordinal);
        if (i < 0) { return porDefecto; }
        i = json.IndexOf(':', i);
        if (i < 0) { return porDefecto; }
        i++;
        while (i < json.Length && char.IsWhiteSpace(json[i])) { i++; }
        if (i >= json.Length) { return porDefecto; }
        if (json[i] == '"')
        {
            i++;
            var sb = new StringBuilder();
            while (i < json.Length && json[i] != '"')
            {
                if (json[i] == '\\' && i + 1 < json.Length) { i++; }
                sb.Append(json[i]); i++;
            }
            return sb.ToString();
        }
        int fin = i;
        while (fin < json.Length && (char.IsDigit(json[fin]) || json[fin] == '.' || json[fin] == '-')) { fin++; }
        return json.Substring(i, fin - i);
    }

    static Color Mezcla(Color a, Color b, double t)
    {
        return Color.FromRgb((byte)(a.R + (b.R - a.R) * t), (byte)(a.G + (b.G - a.G) * t), (byte)(a.B + (b.B - a.B) * t));
    }

    Color ColorDe(string estado)
    {
        switch (estado)
        {
            case "escuchando":
                // un tono por voz (por altura del tono de quien habla)
                switch (voz)
                {
                    case 1: return Color.FromRgb(0x3D, 0xD9, 0xF0);   // cian
                    case 2: return Color.FromRgb(0xB4, 0x8C, 0xFF);   // violeta
                    case 3: return Color.FromRgb(0xFF, 0xB3, 0x5A);   // naranja
                    default: return Color.FromRgb(0x3D, 0xF0, 0x9A);  // verde
                }
            case "atenta": return Color.FromRgb(0x33, 0xB8, 0x80);    // verde apagado: "sigo aqui"
            case "pensando": return Color.FromRgb(0xFF, 0xB3, 0x3D);
            case "hablando": return Color.FromRgb(0x4D, 0xA6, 0xFF);
            case "error": return Color.FromRgb(0xFF, 0x5A, 0x5A);
            default:
                {
                    Color c = Color.FromRgb(0x35, 0xE0, 0xC8);
                    if (Noche()) { c = Color.FromRgb(0xFF, 0xB0, 0x7A); }
                    if (Desanimado()) { c = Mezcla(c, Color.FromRgb(0x8A, 0x96, 0x9C), 0.45); }   // apagado
                    else if (animo >= 0.5) { c = Mezcla(c, Colors.White, 0.12); }              // mas vivo
                    if (Agitado()) { c = Mezcla(c, Color.FromRgb(0xFF, 0x6A, 0x4A), 0.35); }   // caliente
                    if (BateriaBaja()) { c = Color.FromRgb(0xFF, 0xA8, 0x3D); }
                    return c;
                }
        }
    }

    void Aplicar(string estado, string texto, bool cambioTexto) { Aplicar(estado, texto, cambioTexto, null); }

    void Aplicar(string estado, string texto, bool cambioTexto, string textoAnterior)
    {
        PonerEncima();
        Color c = ColorDe(estado);
        Animar(punto.Fill as SolidColorBrush, c);
        Animar(insignia.Fill as SolidColorBrush, c);
        Animar(aroAvatar.Stroke as SolidColorBrush, c);
        Animar(orbita.Fill as SolidColorBrush, c);
        Animar(anilloTempo.Stroke as SolidColorBrush, c);
        Animar(barraNivel.Fill as SolidColorBrush, c);
        foreach (var p in puntitos) { Animar(p.Fill as SolidColorBrush, c); }
        foreach (var fe in new FrameworkElement[] { punto, insignia, orbita })
        {
            var ef = fe.Effect as DropShadowEffect;
            if (ef != null) { ef.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350))); }
        }
        bordeAbajo.BeginAnimation(GradientStop.ColorProperty, new ColorAnimation(Color.FromArgb(0x66, c.R, c.G, c.B), TimeSpan.FromMilliseconds(350)));
        foreach (var b in barras) { Animar(b.Fill as SolidColorBrush, c); }
        resplandor.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350)));

        bool expandida = (estado != "reposo") || !string.IsNullOrEmpty(texto);
        bool conOnda = (estado == "escuchando" || estado == "atenta");
        bool conPuntitos = (estado == "pensando") && !orbitando;
        bool conNivel = (panelNivel.Visibility == Visibility.Visible);
        Animar(lineaProgreso.Fill as SolidColorBrush, c);
        // ojos: atentos al escuchar, normales el resto (si no hay expresion en curso)
        if (estado == "escuchando" || estado == "atenta") { if (expresion == "normal") { Expresion("atentos", 0); } }
        else if (expresion == "atentos") { Expresion("normal", 0); }

        onda.Visibility = conOnda ? Visibility.Visible : Visibility.Collapsed;
        Desvanecer(onda, conOnda ? 1 : 0, 220);
        MostrarPuntitos(conPuntitos);
        if (estado != "reposo" && conNivel)
        {
            ocultarNivel.Stop();
            panelNivel.Visibility = Visibility.Collapsed;
            panelNivel.Opacity = 0;
            conNivel = false;
        }

        bool hayTexto = !string.IsNullOrEmpty(texto);
        double anchoOnda = conOnda ? (BARRAS_ONDA * 6 + 12) : 0;
        double anchoPuntitos = conPuntitos ? (3 * 9 + 12) : 0;
        double anchoNivel = conNivel ? (12 + 15 + 10 + 72) : 0;
        double fijo = (ALTO - AVATAR) / 2 + AVATAR + anchoOnda + anchoPuntitos + anchoNivel + 16 + 2;
        double disponible = ANCHO_BARRA - fijo - 12;
        double anchoTexto = hayTexto ? MedirTexto(texto) : 0;
        double anchoVentana = Math.Min(anchoTexto, disponible);

        etiqueta.Inlines.Clear();
        if (hayTexto && estado == "escuchando" && cambioTexto && !string.IsNullOrEmpty(textoAnterior)
            && texto.Length > textoAnterior.Length && texto.StartsWith(textoAnterior, StringComparison.Ordinal))
        {
            var viejo = new Run(textoAnterior);
            var nuevo = new Run(texto.Substring(textoAnterior.Length));
            var pincel = new SolidColorBrush(c);
            nuevo.Foreground = pincel;
            var ca = new ColorAnimation(Color.FromRgb(0xF2, 0xF5, 0xF8), TimeSpan.FromMilliseconds(520));
            ca.BeginTime = TimeSpan.FromMilliseconds(120);
            pincel.BeginAnimation(SolidColorBrush.ColorProperty, ca);
            etiqueta.Inlines.Add(viejo);
            etiqueta.Inlines.Add(nuevo);
        }
        else { etiqueta.Text = texto; }
        etiquetaSombra.Text = texto;
        ventanaTexto.Visibility = hayTexto ? Visibility.Visible : Visibility.Collapsed;
        ventanaTexto.Width = Math.Max(0, anchoVentana);
        Desvanecer(ventanaTexto, hayTexto ? 1 : 0, 220);
        if (hayTexto && cambioTexto && estado != "escuchando")
        {
            var sube = new DoubleAnimation(6, 0, TimeSpan.FromMilliseconds(260));
            sube.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
            entradaTexto.BeginAnimation(TranslateTransform.YProperty, sube);
        }

        double sobra = anchoTexto - disponible;
        int gen = ++generacionTexto;
        desplaz.BeginAnimation(TranslateTransform.XProperty, null);
        desplazSombra.BeginAnimation(TranslateTransform.XProperty, null);
        etiquetaSombra.BeginAnimation(OpacityProperty, null);
        etiquetaSombra.Opacity = 0;
        if (sobra > 0 && estado == "escuchando")
        {
            var a = new DoubleAnimation(-sobra, TimeSpan.FromMilliseconds(160));
            a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
            desplaz.BeginAnimation(TranslateTransform.XProperty, a);
            desplazSombra.X = -sobra;
            ventanaTexto.OpacityMask = mascaraIzq;
        }
        else if (sobra > 0)
        {
            desplaz.X = 0;
            ventanaTexto.OpacityMask = mascaraDer;
            var a = new DoubleAnimation(0, -sobra, TimeSpan.FromMilliseconds(sobra * 10));
            a.BeginTime = TimeSpan.FromMilliseconds(900);
            a.Completed += delegate { if (gen == generacionTexto) { ventanaTexto.OpacityMask = mascaraIzq; etiquetaSombra.BeginAnimation(OpacityProperty, new DoubleAnimation(0, TimeSpan.FromMilliseconds(250))); } };
            // el rastro: la misma animacion con 70 ms de retraso, desenfocada
            var s = new DoubleAnimation(0, -sobra, TimeSpan.FromMilliseconds(sobra * 10));
            s.BeginTime = TimeSpan.FromMilliseconds(970);
            var arranque = new DispatcherTimer();
            arranque.Interval = TimeSpan.FromMilliseconds(950);
            arranque.Tick += delegate
            {
                arranque.Stop();
                if (gen == generacionTexto)
                {
                    ventanaTexto.OpacityMask = mascaraAmbos;
                    etiquetaSombra.BeginAnimation(OpacityProperty, new DoubleAnimation(0.35, TimeSpan.FromMilliseconds(200)));
                }
            };
            arranque.Start();
            desplaz.BeginAnimation(TranslateTransform.XProperty, a);
            desplazSombra.BeginAnimation(TranslateTransform.XProperty, s);
        }
        else
        {
            desplaz.X = 0; desplazSombra.X = 0;
            ventanaTexto.OpacityMask = null;
        }

        double destino = ALTO;
        if (expandida || conNivel)
        {
            double exacto = fijo + (hayTexto ? anchoVentana + 12 : 0);
            destino = Math.Min(ANCHO_BARRA, Math.Max(conOnda ? 150 : 90, exacto));
        }
        Expandir(destino, expandida || conNivel);
        if (progreso > 0) { AnimarA(lineaProgreso, WidthProperty, Math.Max(0, destino - ALTO * 0.8) * progreso, 440); }

        if (estado == "pensando")
        {
            var p = new DoubleAnimation(0.3, 0.9, TimeSpan.FromMilliseconds(700));
            p.AutoReverse = true;
            p.RepeatBehavior = RepeatBehavior.Forever;
            p.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
            resplandor.BeginAnimation(DropShadowEffect.OpacityProperty, p);
        }
        else
        {
            resplandor.BeginAnimation(DropShadowEffect.OpacityProperty, null);
            // modo cine (pantalla completa sin juego): halo al minimo
            bool cine = foco && string.IsNullOrEmpty(juegoActual) && (estado == "reposo" || estado == "");
            resplandor.Opacity = cine ? 0.15 : (estado == "atenta" ? 0.3 : (cerca ? 0.95 : 0.5));
        }
    }

    bool Cine() { return foco && string.IsNullOrEmpty(juegoActual); }

    void MostrarPuntitos(bool si)
    {
        if (si && indicadorPensando.Visibility != Visibility.Visible)
        {
            indicadorPensando.Visibility = Visibility.Visible;
            for (int i = 0; i < puntitos.Length; i++)
            {
                var a = new DoubleAnimation(0.25, 1.0, TimeSpan.FromMilliseconds(380));
                a.AutoReverse = true;
                a.RepeatBehavior = RepeatBehavior.Forever;
                a.BeginTime = TimeSpan.FromMilliseconds(i * 160);
                a.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
                puntitos[i].BeginAnimation(OpacityProperty, a);
                var s = new ScaleTransform(1, 1);
                puntitos[i].RenderTransformOrigin = new Point(0.5, 0.5);
                puntitos[i].RenderTransform = s;
                var e = new DoubleAnimation(0.75, 1.25, TimeSpan.FromMilliseconds(380));
                e.AutoReverse = true; e.RepeatBehavior = RepeatBehavior.Forever;
                e.BeginTime = a.BeginTime;
                e.EasingFunction = a.EasingFunction;
                s.BeginAnimation(ScaleTransform.ScaleXProperty, e);
                s.BeginAnimation(ScaleTransform.ScaleYProperty, e);
            }
        }
        else if (!si && indicadorPensando.Visibility == Visibility.Visible)
        {
            indicadorPensando.Visibility = Visibility.Collapsed;
            foreach (var p in puntitos) { p.BeginAnimation(OpacityProperty, null); p.RenderTransform = null; }
        }
    }

    double MedirTexto(string texto)
    {
        var ft = new FormattedText(texto, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight,
            new Typeface(etiqueta.FontFamily, etiqueta.FontStyle, etiqueta.FontWeight, etiqueta.FontStretch),
            etiqueta.FontSize, Brushes.White);
        return Math.Ceiling(ft.WidthIncludingTrailingWhitespace);
    }

    void Expandir(double destino, bool creciendo)
    {
        var a = new DoubleAnimation(destino, TimeSpan.FromMilliseconds(creciendo ? 440 : 320));
        if (creciendo) { a.EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = 0.35 }; }
        else { a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut }; }
        capsula.BeginAnimation(WidthProperty, a);
    }

    static void Desvanecer(UIElement e, double destino, int ms)
    {
        var a = new DoubleAnimation(destino, TimeSpan.FromMilliseconds(ms));
        a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
        e.BeginAnimation(OpacityProperty, a);
    }

    static void Animar(SolidColorBrush b, Color destino)
    {
        if (b == null) { return; }
        var a = new ColorAnimation(destino, TimeSpan.FromMilliseconds(350));
        a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
        b.BeginAnimation(SolidColorBrush.ColorProperty, a);
    }
}
