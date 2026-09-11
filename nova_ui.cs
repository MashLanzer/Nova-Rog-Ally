// Nova UI: la cara visible del asistente.
//
// POR QUE UN PROCESO APARTE Y EN WPF:
// La barra anterior era WinForms, que no tiene aceleracion por hardware: las
// animaciones van a tirones y parpadean. WPF anima a 60 fps, pero no convive
// con el bucle de un solo hilo del asistente. Separarlo resuelve las dos cosas
// y ademas aisla fallos: si la interfaz peta, el asistente sigue funcionando.
//
// COMUNICACION: el asistente escribe un JSON diminuto con el estado; aqui se
// lee cada 80 ms. Es el mismo patron de archivos que ya usan los workers de
// voz y de escucha, y evita cualquier problema de hilos.
//   {"estado","texto","nivel","evento","n","juego"}
//   estado : reposo | escuchando | pensando | hablando | error
//   evento : animacion puntual (despierta, hecho, aviso); se dispara cuando
//            cambia "n", asi que un mismo evento puede repetirse
//   juego  : ruta del ejecutable del juego en primer plano; su icono pasa a
//            ser el avatar y el punto se convierte en insignia de estado
// El nivel del microfono llega por un archivo aparte (ui-nivel.txt) que
// escribe el worker de escucha a 4 Hz, sin pasar por el asistente.
//
// CRISTAL DE VERDAD, NO PLASTICO:
// La primera version tenia el relleno opaco y parecia una lamina de plastico.
// Un cristal deja ver lo de detras, desenfocado. Windows no ofrece desenfoque
// tras una ventana con forma de capsula (el acrilico de DWM es rectangular y
// recortar la ventana por region deja bordes dentados), asi que se hace a
// mano: se captura la pantalla justo detras, se desenfoca en la GPU y se usa
// como fondo recortado con las esquinas redondas. Encima van un tinte oscuro
// ligero, un grano apenas perceptible, un reflejo de luz arriba, una linea
// especular en el canto y una sombra debajo.
//
// VIDA: nada de esto es funcional, y todo importa. El punto respira en
// reposo y parpadea de vez en cuando; al oir el nombre lanza ondas; cuando
// ejecuta algo local hace un tic; al hablar "mueve la boca"; al pensar
// laten tres puntos; en error se sacude. Son las micro-animaciones que hacen
// que parezca alguien y no una barra de progreso.
//
// COMPILAR: tools\compilar-ui.ps1
// USO: nova_ui.exe <ruta del json de estado> [PID del asistente]
//   Si se da el PID, la interfaz se cierra sola cuando ese proceso muere: asi
//   no queda una capsula huerfana en pantalla si el asistente se cae.

using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;

public class NovaUI : Window
{
    // --- medidas: el usuario pidio mantener el tamano, que no estorba
    const double ANCHO_BARRA = 340;
    const double ALTO = 44;
    const double AVATAR = 24;          // hueco del punto / icono del juego
    const double DIAM_PUNTO = 14;
    const double DIAM_INSIGNIA = 9;
    const double ICONO = 22;
    const double MARGEN = 24;          // holgura para la sombra y el resplandor
    const double RADIO_BLUR = 22;
    const int BARRAS_ONDA = 14;

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

    // el "rostro": punto, o icono del juego con el punto de insignia
    Grid esfera;
    Ellipse punto, insignia, aroAvatar;
    Image avatar;
    Ellipse[] anillos;
    System.Windows.Shapes.Path marcaHecho;
    ScaleTransform escalaPunto;

    StackPanel onda;
    Rectangle[] barras;
    StackPanel indicadorPensando;
    Ellipse[] puntitos;

    TextBlock etiqueta;
    Canvas ventanaTexto;
    TranslateTransform desplaz, entradaTexto;
    LinearGradientBrush mascaraAmbos, mascaraIzq, mascaraDer;
    int generacionTexto = 0;

    string estadoActual = "";
    string textoActual = "";
    string juegoActual = "";
    int eventoN = -1;
    double nivelActual = 0, nivelObjetivo = 0;
    double fase = 0;
    // "boca": cuanto se hincha el punto al hablar
    double boca = 0, bocaObjetivo = 0;
    DateTime proximaSilaba = DateTime.MinValue;
    Random azar = new Random();
    DispatcherTimer parpadeo;

    // click-through: la barra nunca debe robar clics al juego
    const int GWL_EXSTYLE = -20;
    const int WS_EX_TRANSPARENT = 0x20;
    const int WS_EX_TOOLWINDOW = 0x80;
    const int WS_EX_NOACTIVATE = 0x8000000;
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);
    // Para quedar POR ENCIMA de la barra de tareas. Topmost no basta: la barra
    // tambien lo es y, como esta ventana nunca se activa, la barra acababa
    // encima y tapaba media capsula. Se reafirma el orden en cada cambio de
    // estado y cada 1,5 s.
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
        Left = area.Left + 12 - MARGEN;
        Top = area.Bottom - ALTO - 12 - MARGEN;

        Color acento = ColorDe("reposo");

        // ---------- capa 1: sombra de profundidad, negra, hacia abajo ----------
        envoltorio = new Border();
        envoltorio.HorizontalAlignment = HorizontalAlignment.Left;
        envoltorio.VerticalAlignment = VerticalAlignment.Center;
        envoltorio.Margin = new Thickness(MARGEN, 0, 0, 0);
        envoltorio.CornerRadius = new CornerRadius(ALTO / 2);
        envoltorio.Background = new SolidColorBrush(Color.FromArgb(0x01, 0, 0, 0)); // necesario para que la sombra tenga forma
        var sombra = new DropShadowEffect();
        sombra.Color = Colors.Black;
        sombra.BlurRadius = 16;
        sombra.ShadowDepth = 4;
        sombra.Direction = 270;
        sombra.Opacity = 0.55;
        envoltorio.Effect = sombra;
        sacudida = new TranslateTransform();
        envoltorio.RenderTransform = sacudida;

        // ---------- capa 2: la capsula, con resplandor de color y borde ----------
        resplandor = new DropShadowEffect();
        resplandor.BlurRadius = 24;
        resplandor.ShadowDepth = 0;
        resplandor.Opacity = 0.5;
        resplandor.Color = acento;

        capsula = new Border();
        capsula.Height = ALTO;
        capsula.Width = ALTO;                 // arranca contraida: un circulo
        capsula.CornerRadius = new CornerRadius(ALTO / 2);
        capsula.BorderThickness = new Thickness(1);
        capsula.Effect = resplandor;
        capsula.Background = Brushes.Transparent;

        // borde con luz: mas claro arriba, como cae la luz sobre un cristal
        var borde = new LinearGradientBrush();
        borde.StartPoint = new Point(0, 0);
        borde.EndPoint = new Point(0, 1);
        borde.GradientStops.Add(new GradientStop(Color.FromArgb(0x5C, 0xFF, 0xFF, 0xFF), 0));
        bordeAbajo = new GradientStop(Color.FromArgb(0x55, acento.R, acento.G, acento.B), 1);
        borde.GradientStops.Add(bordeAbajo);
        capsula.BorderBrush = borde;

        // ---------- capa 3: interior recortado ----------
        interior = new Grid();
        recorte = new RectangleGeometry();
        recorte.RadiusX = ALTO / 2 - 1;
        recorte.RadiusY = ALTO / 2 - 1;
        interior.Clip = recorte;
        interior.SizeChanged += delegate
        {
            recorte.Rect = new Rect(0, 0, interior.ActualWidth, interior.ActualHeight);
        };

        // 3a: el escritorio de detras, desenfocado (lo que lo hace cristal)
        fondoDesenfocado = new Image();
        fondoDesenfocado.Stretch = Stretch.Fill;
        fondoDesenfocado.HorizontalAlignment = HorizontalAlignment.Left;
        fondoDesenfocado.VerticalAlignment = VerticalAlignment.Top;
        fondoDesenfocado.Width = ANCHO_BARRA + RADIO_BLUR * 2;
        fondoDesenfocado.Height = ALTO + RADIO_BLUR * 2;
        fondoDesenfocado.Margin = new Thickness(-RADIO_BLUR, -RADIO_BLUR, 0, 0);
        var blur = new BlurEffect();
        blur.Radius = RADIO_BLUR;
        blur.KernelType = KernelType.Gaussian;
        blur.RenderingBias = RenderingBias.Performance;
        fondoDesenfocado.Effect = blur;
        // fondo de reserva por si la captura falla: mismo tono que el tinte
        interior.Background = new SolidColorBrush(Color.FromRgb(0x14, 0x17, 0x1E));
        interior.Children.Add(fondoDesenfocado);

        // 3b: tinte oscuro LIGERO con un punto azul frio. Con 55-70 % de
        // opacidad el fondo casi no se veia y parecia carton mate.
        var tinte = new Border();
        var tintePincel = new LinearGradientBrush();
        tintePincel.StartPoint = new Point(0, 0);
        tintePincel.EndPoint = new Point(0, 1);
        tintePincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x4A, 0x1A, 0x22, 0x32), 0));
        tintePincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x78, 0x08, 0x0C, 0x16), 1));
        tinte.Background = tintePincel;
        interior.Children.Add(tinte);

        // 3c: grano apenas perceptible. Al 7 % daba textura de papel.
        var ruido = new Border();
        ruido.Background = CrearGrano();
        ruido.Opacity = 0.02;
        interior.Children.Add(ruido);

        // 3d: sombra interior en el borde de abajo: da grosor al cristal
        var sombraInterior = new Border();
        sombraInterior.VerticalAlignment = VerticalAlignment.Bottom;
        sombraInterior.Height = ALTO * 0.4;
        var sombraPincel = new LinearGradientBrush();
        sombraPincel.StartPoint = new Point(0, 0);
        sombraPincel.EndPoint = new Point(0, 1);
        sombraPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0, 0, 0), 0));
        sombraPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x48, 0, 0, 0), 1));
        sombraInterior.Background = sombraPincel;
        interior.Children.Add(sombraInterior);

        // 3e: reflejo de luz suave en la mitad superior
        var brilloSuperior = new Border();
        brilloSuperior.VerticalAlignment = VerticalAlignment.Top;
        brilloSuperior.Height = ALTO * 0.45;
        var brilloPincel = new LinearGradientBrush();
        brilloPincel.StartPoint = new Point(0, 0);
        brilloPincel.EndPoint = new Point(0, 1);
        brilloPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x24, 0xFF, 0xFF, 0xFF), 0));
        brilloPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 1));
        brilloSuperior.Background = brilloPincel;
        interior.Children.Add(brilloSuperior);

        // 3f: linea especular de 1 px en el canto superior, viva en el centro y
        // apagada en las puntas: la luz "toca" el cristal en vez de banarlo
        var especular = new Border();
        especular.VerticalAlignment = VerticalAlignment.Top;
        especular.Height = 1;
        especular.Margin = new Thickness(ALTO * 0.5, 1, ALTO * 0.5, 0);
        var especularPincel = new LinearGradientBrush();
        especularPincel.StartPoint = new Point(0, 0);
        especularPincel.EndPoint = new Point(1, 0);
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 0));
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x9A, 0xFF, 0xFF, 0xFF), 0.35));
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x9A, 0xFF, 0xFF, 0xFF), 0.65));
        especularPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 1));
        especular.Background = especularPincel;
        interior.Children.Add(especular);

        // ---------- 3g: el contenido ----------
        var fila = new StackPanel();
        fila.Orientation = Orientation.Horizontal;
        fila.VerticalAlignment = VerticalAlignment.Center;
        // Alineada a la izquierda SIEMPRE: con Stretch, si la fila media mas
        // que el circulo de reposo WPF la desplazaba y el punto salia cortado.
        fila.HorizontalAlignment = HorizontalAlignment.Left;
        fila.Margin = new Thickness((ALTO - AVATAR) / 2, 0, 0, 0);

        ConstruirRostro(acento);
        fila.Children.Add(esfera);

        // onda de audio: reacciona al nivel real del microfono
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
            r.Width = 3; r.Height = 4;
            r.RadiusX = 1.5; r.RadiusY = 1.5;
            r.Margin = new Thickness(1.5, 0, 1.5, 0);
            r.VerticalAlignment = VerticalAlignment.Center;
            r.Fill = new SolidColorBrush(acento);
            barras[i] = r;
            onda.Children.Add(r);
        }
        fila.Children.Add(onda);

        // tres puntos que laten mientras piensa
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

        etiqueta = new TextBlock();
        etiqueta.Foreground = new SolidColorBrush(Color.FromRgb(0xF2, 0xF5, 0xF8));
        etiqueta.FontFamily = new FontFamily("Segoe UI Semibold, Segoe UI");
        etiqueta.FontSize = 13.5;
        etiqueta.HorizontalAlignment = HorizontalAlignment.Left;
        etiqueta.TextTrimming = TextTrimming.None;
        var sombraTexto = new DropShadowEffect();
        sombraTexto.Color = Colors.Black; sombraTexto.BlurRadius = 4; sombraTexto.ShadowDepth = 1; sombraTexto.Opacity = 0.7;
        etiqueta.Effect = sombraTexto;
        TextOptions.SetTextRenderingMode(etiqueta, TextRenderingMode.ClearType);
        desplaz = new TranslateTransform();
        etiqueta.RenderTransform = desplaz;

        // El texto largo NO agranda la capsula: se desplaza dentro de esta
        // ventana recortada. Es un Canvas y no un Grid a proposito: el Grid
        // mide al TextBlock con el ancho del hueco y WPF le aplica un recorte
        // de diseno que viaja con la transformacion, y el texto desaparecia.
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
        Canvas.SetLeft(etiqueta, 0);
        Canvas.SetTop(etiqueta, 0);
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

        Loaded += delegate
        {
            var h = new WindowInteropHelper(this).Handle;
            int est = GetWindowLong(h, GWL_EXSTYLE);
            SetWindowLong(h, GWL_EXSTYLE, est | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);
            hwnd = h;
            PonerEncima();
            Latido();
            CapturarFondo();
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

        // parpadeo: cada 4-9 s, solo en reposo o escuchando. Es lo que mas
        // "vivo" lo hace con menos: un gesto involuntario.
        parpadeo = new DispatcherTimer();
        parpadeo.Interval = TimeSpan.FromSeconds(5);
        parpadeo.Tick += delegate
        {
            parpadeo.Interval = TimeSpan.FromSeconds(4 + azar.NextDouble() * 5);
            if (estadoActual == "reposo" || estadoActual == "escuchando" || estadoActual == "") { Parpadear(); }
        };
        parpadeo.Start();

        if (pidPadre > 0)
        {
            var vigia = new DispatcherTimer();
            vigia.Interval = TimeSpan.FromSeconds(2);
            vigia.Tick += delegate
            {
                bool vivo = true;
                try { using (var p = Process.GetProcessById(pidPadre)) { vivo = !p.HasExited; } }
                catch { vivo = false; }
                if (!vivo) { Application.Current.Shutdown(); }
            };
            vigia.Start();
        }
    }

    // El punto (o el icono del juego con el punto como insignia), los anillos
    // de las ondas y la marca del tic, todos en un hueco de 24x24.
    void ConstruirRostro(Color acento)
    {
        esfera = new Grid();
        esfera.Width = AVATAR; esfera.Height = AVATAR;
        esfera.VerticalAlignment = VerticalAlignment.Center;

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

        // icono del juego: circular, con un aro del color del estado
        avatar = new Image();
        avatar.Width = ICONO; avatar.Height = ICONO;
        avatar.Stretch = Stretch.UniformToFill;
        avatar.Clip = new EllipseGeometry(new Point(ICONO / 2, ICONO / 2), ICONO / 2, ICONO / 2);
        avatar.Visibility = Visibility.Collapsed;
        avatar.RenderTransformOrigin = new Point(0.5, 0.5);
        avatar.RenderTransform = new ScaleTransform(1, 1);
        RenderOptions.SetBitmapScalingMode(avatar, BitmapScalingMode.HighQuality);
        esfera.Children.Add(avatar);
        aroAvatar = new Ellipse();
        aroAvatar.Width = AVATAR; aroAvatar.Height = AVATAR;
        aroAvatar.Stroke = new SolidColorBrush(acento);
        aroAvatar.StrokeThickness = 1.5;
        aroAvatar.Visibility = Visibility.Collapsed;
        esfera.Children.Add(aroAvatar);

        // el punto: una esfera con su propio reflejo, no un circulo plano
        var cuerpo = new Grid();
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
        var reflejo = new Ellipse();
        reflejo.Width = DIAM_PUNTO * 0.45; reflejo.Height = DIAM_PUNTO * 0.32;
        reflejo.HorizontalAlignment = HorizontalAlignment.Left;
        reflejo.VerticalAlignment = VerticalAlignment.Top;
        reflejo.Margin = new Thickness(DIAM_PUNTO * 0.22, DIAM_PUNTO * 0.14, 0, 0);
        var reflejoPincel = new LinearGradientBrush();
        reflejoPincel.StartPoint = new Point(0, 0); reflejoPincel.EndPoint = new Point(0, 1);
        reflejoPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0xB0, 0xFF, 0xFF, 0xFF), 0));
        reflejoPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x10, 0xFF, 0xFF, 0xFF), 1));
        reflejo.Fill = reflejoPincel;
        cuerpo.Children.Add(reflejo);
        // la marca del tic, encima del punto
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

        // insignia: el punto pequeno abajo a la derecha cuando hay icono
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

    // Grano: un mosaico pequeno de pixeles grises aleatorios, repetido.
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

    // Captura lo que hay detras de la capsula y lo deja desenfocado de fondo.
    // La ventana se vuelve invisible durante un instante para no capturarse a
    // si misma; es un parpadeo de ~50 ms que solo ocurre al expandirse.
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
            Thread.Sleep(45);   // que DWM componga el cuadro sin nosotros

            using (var bmp = new System.Drawing.Bitmap(w, hgt))
            {
                using (var g = System.Drawing.Graphics.FromImage(bmp))
                {
                    g.CopyFromScreen(x, y, 0, 0, new System.Drawing.Size(w, hgt));
                }
                IntPtr hb = bmp.GetHbitmap();
                try
                {
                    var bs = Imaging.CreateBitmapSourceFromHBitmap(
                        hb, IntPtr.Zero, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                    bs.Freeze();
                    fondoDesenfocado.Source = bs;
                }
                finally { DeleteObject(hb); }
            }
            Opacity = opAntes;
        }
        catch
        {
            Opacity = 1;
        }
    }

    // ---------------------------------------------------------------
    // Vida: respiracion, parpadeo, boca, ondas, tic, sacudida
    // ---------------------------------------------------------------
    void Latido()
    {
        var a = new DoubleAnimation(0.55, 1.0, TimeSpan.FromMilliseconds(1700));
        a.AutoReverse = true;
        a.RepeatBehavior = RepeatBehavior.Forever;
        a.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
        punto.BeginAnimation(OpacityProperty, a);
        insignia.BeginAnimation(OpacityProperty, a);
    }

    void Parpadear()
    {
        var k = new DoubleAnimationUsingKeyFrames();
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.Zero)));
        k.KeyFrames.Add(new EasingDoubleKeyFrame(0.12, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(85)), new CubicEase { EasingMode = EasingMode.EaseIn }));
        k.KeyFrames.Add(new EasingDoubleKeyFrame(1.0, KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(200)), new CubicEase { EasingMode = EasingMode.EaseOut }));
        k.FillBehavior = FillBehavior.Stop;
        escalaPunto.BeginAnimation(ScaleTransform.ScaleYProperty, k);
        if (avatar.Visibility == Visibility.Visible)
        {
            (avatar.RenderTransform as ScaleTransform).BeginAnimation(ScaleTransform.ScaleYProperty, k);
        }
    }

    // el punto se hincha con un rebote elastico (al despertar)
    void Saltar(double cuanto)
    {
        var a = new DoubleAnimation(cuanto, 1.0, TimeSpan.FromMilliseconds(650));
        a.EasingFunction = new ElasticEase { Oscillations = 2, Springiness = 4, EasingMode = EasingMode.EaseOut };
        a.FillBehavior = FillBehavior.Stop;
        escalaPunto.BeginAnimation(ScaleTransform.ScaleXProperty, a);
        escalaPunto.BeginAnimation(ScaleTransform.ScaleYProperty, a);
        if (avatar.Visibility == Visibility.Visible)
        {
            var s = avatar.RenderTransform as ScaleTransform;
            s.BeginAnimation(ScaleTransform.ScaleXProperty, a);
            s.BeginAnimation(ScaleTransform.ScaleYProperty, a);
        }
    }

    // ondas concentricas que salen del punto
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

    // tic: destello blanco del punto y una marca de "hecho" que aparece y se va
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
    }

    void Sacudir()
    {
        var k = new DoubleAnimationUsingKeyFrames();
        double[] xs = { 0, -7, 6, -4, 3, -1, 0 };
        for (int i = 0; i < xs.Length; i++)
        {
            k.KeyFrames.Add(new EasingDoubleKeyFrame(xs[i], KeyTime.FromTimeSpan(TimeSpan.FromMilliseconds(i * 65)),
                new SineEase { EasingMode = EasingMode.EaseInOut }));
        }
        k.FillBehavior = FillBehavior.Stop;
        sacudida.BeginAnimation(TranslateTransform.XProperty, k);
    }

    void Evento(string nombre)
    {
        switch (nombre)
        {
            case "despierta":
                Saltar(1.6);
                Ondas(2, ColorDe("escuchando"));
                break;
            case "hecho":
                MarcarHecho();
                break;
            case "aviso":
                Saltar(1.4);
                Ondas(2, ColorDe("pensando"));
                break;
            case "error":
                Sacudir();
                break;
        }
    }

    // 30 veces por segundo: onda del microfono y boca al hablar
    void Tic33()
    {
        // --- onda ---
        if (onda.Visibility == Visibility.Visible)
        {
            fase += 0.45;
            // el nivel real llega a 4 Hz (bloques de 250 ms); se persigue con
            // un suavizado y un minimo lo mantiene respirando en el silencio
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

        // --- boca: silabas simuladas mientras habla ---
        if (estadoActual == "hablando")
        {
            var ahora = DateTime.UtcNow;
            if (ahora >= proximaSilaba)
            {
                // una de cada cuatro es una pausa entre palabras
                bocaObjetivo = azar.NextDouble() < 0.25 ? 0.0 : 0.12 + azar.NextDouble() * 0.33;
                proximaSilaba = ahora.AddMilliseconds(80 + azar.NextDouble() * 130);
            }
            boca += (bocaObjetivo - boca) * 0.4;
            resplandor.Opacity = 0.45 + boca * 0.9;
        }
        else if (boca > 0.001)
        {
            boca *= 0.8;
            if (boca < 0.001) { boca = 0; }
        }
        else { return; }
        escalaPunto.ScaleX = 1 + boca;
        escalaPunto.ScaleY = 1 + boca;
        if (avatar.Visibility == Visibility.Visible)
        {
            var s = avatar.RenderTransform as ScaleTransform;
            s.ScaleX = 1 + boca * 0.5; s.ScaleY = 1 + boca * 0.5;
        }
    }

    // ---------------------------------------------------------------
    // Estado
    // ---------------------------------------------------------------
    void LeerEstado()
    {
        string est = "reposo", txt = "", evento = "", juego = "";
        double niv = 0;
        int n = 0;
        try
        {
            if (File.Exists(rutaEstado))
            {
                string j = File.ReadAllText(rutaEstado, System.Text.Encoding.UTF8);
                est = Campo(j, "estado", "reposo");
                txt = Campo(j, "texto", "");
                evento = Campo(j, "evento", "");
                juego = Campo(j, "juego", "");
                double.TryParse(Campo(j, "nivel", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out niv);
                int.TryParse(Campo(j, "n", "0"), NumberStyles.Any, CultureInfo.InvariantCulture, out n);
            }
        }
        catch { }

        // el nivel del microfono viene por otro archivo, escrito por el worker
        // de escucha; si lleva mas de 1 s sin actualizarse, es que no dicta
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

        if (juego != juegoActual)
        {
            juegoActual = juego;
            CargarAvatar(juego);
        }

        if (est != estadoActual || txt != textoActual)
        {
            bool estabaEnReposo = (estadoActual == "" || estadoActual == "reposo");
            bool cambioTexto = (txt != textoActual);
            estadoActual = est;
            textoActual = txt;
            // al salir del reposo se refresca lo que hay detras: el escritorio
            // puede haber cambiado desde la ultima vez
            if (estabaEnReposo && est != "reposo") { CapturarFondo(); }
            Aplicar(est, txt, cambioTexto);
            if (est == "error") { Sacudir(); }
        }

        // los eventos se disparan por cambio de contador, no por nombre: asi
        // dos "hecho" seguidos se ven los dos. El primero leido al arrancar
        // no se reproduce: es de una sesion anterior.
        if (n != eventoN)
        {
            bool primero = (eventoN == -1);
            eventoN = n;
            if (!primero && !string.IsNullOrEmpty(evento)) { Evento(evento); }
        }
    }

    // Saca el icono del ejecutable del juego y lo pone de avatar; si no hay
    // juego (o el icono no se puede leer) vuelve el punto.
    void CargarAvatar(string ruta)
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
        if (bs != null)
        {
            avatar.Source = bs;
            avatar.Visibility = Visibility.Visible;
            aroAvatar.Visibility = Visibility.Visible;
            insignia.Visibility = Visibility.Visible;
            punto.Visibility = Visibility.Collapsed;
            marcaHecho.Visibility = Visibility.Collapsed;
            // entra creciendo desde el centro
            var s = avatar.RenderTransform as ScaleTransform;
            var a = new DoubleAnimation(0.2, 1.0, TimeSpan.FromMilliseconds(520));
            a.EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut, Amplitude = 0.6 };
            a.FillBehavior = FillBehavior.Stop;
            s.BeginAnimation(ScaleTransform.ScaleXProperty, a);
            s.BeginAnimation(ScaleTransform.ScaleYProperty, a);
            Ondas(1, ColorDe(estadoActual == "" ? "reposo" : estadoActual));
        }
        else
        {
            avatar.Source = null;
            avatar.Visibility = Visibility.Collapsed;
            aroAvatar.Visibility = Visibility.Collapsed;
            insignia.Visibility = Visibility.Collapsed;
            punto.Visibility = Visibility.Visible;
            marcaHecho.Visibility = Visibility.Visible;
            Saltar(0.4);
        }
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
            var sb = new System.Text.StringBuilder();
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

    Color ColorDe(string estado)
    {
        switch (estado)
        {
            case "escuchando": return Color.FromRgb(0x3D, 0xF0, 0x9A);   // verde neon
            case "pensando": return Color.FromRgb(0xFF, 0xB3, 0x3D);     // ambar
            case "hablando": return Color.FromRgb(0x4D, 0xA6, 0xFF);     // azul
            case "error": return Color.FromRgb(0xFF, 0x5A, 0x5A);        // rojo
            default: return Color.FromRgb(0x35, 0xE0, 0xC8);             // turquesa en reposo
        }
    }

    void Aplicar(string estado, string texto, bool cambioTexto)
    {
        PonerEncima();
        Color c = ColorDe(estado);
        Animar(punto.Fill as SolidColorBrush, c);
        Animar(insignia.Fill as SolidColorBrush, c);
        Animar(aroAvatar.Stroke as SolidColorBrush, c);
        foreach (var p in puntitos) { Animar(p.Fill as SolidColorBrush, c); }
        var bp = punto.Effect as DropShadowEffect;
        if (bp != null) { bp.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350))); }
        var bi = insignia.Effect as DropShadowEffect;
        if (bi != null) { bi.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350))); }
        bordeAbajo.BeginAnimation(GradientStop.ColorProperty,
            new ColorAnimation(Color.FromArgb(0x66, c.R, c.G, c.B), TimeSpan.FromMilliseconds(350)));
        foreach (var b in barras) { Animar(b.Fill as SolidColorBrush, c); }
        resplandor.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350)));

        bool expandida = (estado != "reposo") || !string.IsNullOrEmpty(texto);
        bool conOnda = (estado == "escuchando");
        bool conPuntitos = (estado == "pensando");

        // la onda invisible seguia ocupando sitio y cortaba el texto: se
        // colapsa del todo cuando no se escucha
        onda.Visibility = conOnda ? Visibility.Visible : Visibility.Collapsed;
        Desvanecer(onda, conOnda ? 1 : 0, 220);
        MostrarPuntitos(conPuntitos);

        bool hayTexto = !string.IsNullOrEmpty(texto);
        double anchoOnda = conOnda ? (BARRAS_ONDA * 6 + 12) : 0;
        double anchoPuntitos = conPuntitos ? (3 * 9 + 12) : 0;
        double fijo = (ALTO - AVATAR) / 2 + AVATAR + anchoOnda + anchoPuntitos + 16 + 2;
        double disponible = ANCHO_BARRA - fijo - 12;
        double anchoTexto = hayTexto ? MedirTexto(texto) : 0;
        double anchoVentana = Math.Min(anchoTexto, disponible);

        etiqueta.Text = texto;
        ventanaTexto.Visibility = hayTexto ? Visibility.Visible : Visibility.Collapsed;
        ventanaTexto.Width = Math.Max(0, anchoVentana);
        Desvanecer(ventanaTexto, hayTexto ? 1 : 0, 220);
        // el texto nuevo entra deslizando desde abajo (no en la transcripcion
        // en vivo, que cambia varias veces por segundo)
        if (hayTexto && cambioTexto && estado != "escuchando")
        {
            var sube = new DoubleAnimation(6, 0, TimeSpan.FromMilliseconds(260));
            sube.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
            entradaTexto.BeginAnimation(TranslateTransform.YProperty, sube);
        }

        double sobra = anchoTexto - disponible;
        int gen = ++generacionTexto;
        desplaz.BeginAnimation(TranslateTransform.XProperty, null);
        if (sobra > 0 && estado == "escuchando")
        {
            // transcripcion en vivo: lo que importa es el final
            var a = new DoubleAnimation(-sobra, TimeSpan.FromMilliseconds(160));
            a.EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut };
            desplaz.BeginAnimation(TranslateTransform.XProperty, a);
            ventanaTexto.OpacityMask = mascaraIzq;
        }
        else if (sobra > 0)
        {
            // una pasada, ~100 px/s: se lee al mismo ritmo al que se habla.
            // La mascara sigue al movimiento: al principio solo se difumina la
            // derecha (si no, se comia la primera letra), en marcha los dos
            // lados, y al final solo la izquierda.
            desplaz.X = 0;
            ventanaTexto.OpacityMask = mascaraDer;
            var a = new DoubleAnimation(0, -sobra, TimeSpan.FromMilliseconds(sobra * 10));
            a.BeginTime = TimeSpan.FromMilliseconds(900);
            a.Completed += delegate { if (gen == generacionTexto) { ventanaTexto.OpacityMask = mascaraIzq; } };
            var arranque = new DispatcherTimer();
            arranque.Interval = TimeSpan.FromMilliseconds(950);
            arranque.Tick += delegate
            {
                arranque.Stop();
                if (gen == generacionTexto) { ventanaTexto.OpacityMask = mascaraAmbos; }
            };
            arranque.Start();
            desplaz.BeginAnimation(TranslateTransform.XProperty, a);
        }
        else
        {
            desplaz.X = 0;
            ventanaTexto.OpacityMask = null;
        }

        double destino = ALTO;   // en reposo, un circulo perfecto
        if (expandida)
        {
            double exacto = fijo + (hayTexto ? anchoVentana + 12 : 0);
            destino = Math.Min(ANCHO_BARRA, Math.Max(conOnda ? 150 : 90, exacto));
        }
        Expandir(destino, expandida);

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
            resplandor.Opacity = 0.5;
        }
    }

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
