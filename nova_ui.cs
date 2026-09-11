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
//
// CRISTAL DE VERDAD, NO PLASTICO:
// La primera version tenia el relleno opaco y parecia una lamina de plastico.
// Un cristal deja ver lo de detras, desenfocado. Windows no ofrece desenfoque
// tras una ventana con forma de capsula (el acrilico de DWM es rectangular y
// recortar la ventana por region deja bordes dentados), asi que se hace a
// mano: se captura la pantalla justo detras, se desenfoca en la GPU y se usa
// como fondo recortado con las esquinas redondas. Encima van un tinte oscuro,
// un grano fino como el del acrilico, un reflejo de luz en el borde superior
// y una sombra debajo. Eso es lo que separa un cristal de un plastico.
//
// COMPILAR: ver tools\compilar-ui.ps1
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
    const double DIAM_PUNTO = 14;
    const double MARGEN = 24;          // holgura para la sombra y el resplandor
    const double RADIO_BLUR = 22;
    const int BARRAS_ONDA = 14;

    static string rutaEstado;
    static int pidPadre = 0;

    Border envoltorio;          // lleva la sombra de profundidad (negra)
    Border capsula;             // lleva el resplandor de color y el borde
    Grid interior;              // recortado con las esquinas redondas
    RectangleGeometry recorte;
    Image fondoDesenfocado;
    Border tinte;
    Border brilloSuperior;
    Ellipse punto;
    TextBlock etiqueta;
    StackPanel onda;
    Rectangle[] barras;
    DropShadowEffect resplandor;
    GradientStop bordeAbajo;

    string estadoActual = "";
    string textoActual = "";
    double nivelActual = 0;
    double fase = 0;
    Random azar = new Random();

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

        // 3b: tinte oscuro translucido, mas claro arriba
        tinte = new Border();
        var tintePincel = new LinearGradientBrush();
        tintePincel.StartPoint = new Point(0, 0);
        tintePincel.EndPoint = new Point(0, 1);
        // El tinte tiene que ser LIGERO: con 55-70 % de opacidad el fondo
        // desenfocado casi no se veia y el conjunto parecia carton mate.
        // Un cristal oscuro real deja pasar la mitad de la luz, y con un
        // toque azul frio, no gris neutro.
        tintePincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x4A, 0x1A, 0x22, 0x32), 0));
        tintePincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x78, 0x08, 0x0C, 0x16), 1));
        tinte.Background = tintePincel;
        interior.Children.Add(tinte);

        // 3c: grano apenas perceptible. Al 7 % daba textura de papel; al 2 %
        // solo rompe el degradado plano sin que se note como textura.
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
        brilloSuperior = new Border();
        brilloSuperior.VerticalAlignment = VerticalAlignment.Top;
        brilloSuperior.Height = ALTO * 0.45;
        var brilloPincel = new LinearGradientBrush();
        brilloPincel.StartPoint = new Point(0, 0);
        brilloPincel.EndPoint = new Point(0, 1);
        brilloPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x24, 0xFF, 0xFF, 0xFF), 0));
        brilloPincel.GradientStops.Add(new GradientStop(Color.FromArgb(0x00, 0xFF, 0xFF, 0xFF), 1));
        brilloSuperior.Background = brilloPincel;
        interior.Children.Add(brilloSuperior);

        // 3f: linea especular de 1 px en el canto superior, mas viva en el
        // centro y apagada en las puntas: es lo que hace que la luz "toque"
        // el cristal en vez de banarlo por igual
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

        // 3e: el contenido
        var fila = new StackPanel();
        fila.Orientation = Orientation.Horizontal;
        fila.VerticalAlignment = VerticalAlignment.Center;
        fila.Margin = new Thickness((ALTO - DIAM_PUNTO) / 2, 0, 16, 0);

        // el punto: una esfera con su propio reflejo, no un circulo plano
        var esfera = new Grid();
        esfera.Width = DIAM_PUNTO; esfera.Height = DIAM_PUNTO;
        esfera.VerticalAlignment = VerticalAlignment.Center;
        punto = new Ellipse();
        punto.Fill = new SolidColorBrush(acento);
        var brilloPunto = new DropShadowEffect();
        brilloPunto.Color = acento; brilloPunto.BlurRadius = 10; brilloPunto.ShadowDepth = 0; brilloPunto.Opacity = 0.9;
        punto.Effect = brilloPunto;
        esfera.Children.Add(punto);
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
        esfera.Children.Add(reflejo);
        fila.Children.Add(esfera);

        // onda de audio: reacciona al nivel real del microfono
        onda = new StackPanel();
        onda.Orientation = Orientation.Horizontal;
        onda.VerticalAlignment = VerticalAlignment.Center;
        onda.Margin = new Thickness(12, 0, 0, 0);
        onda.Opacity = 0;
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

        etiqueta = new TextBlock();
        etiqueta.Foreground = new SolidColorBrush(Color.FromRgb(0xF2, 0xF5, 0xF8));
        etiqueta.FontFamily = new FontFamily("Segoe UI Semibold, Segoe UI");
        etiqueta.FontSize = 13.5;
        etiqueta.VerticalAlignment = VerticalAlignment.Center;
        etiqueta.Margin = new Thickness(12, 0, 0, 0);
        etiqueta.TextTrimming = TextTrimming.CharacterEllipsis;
        etiqueta.Opacity = 0;
        var sombraTexto = new DropShadowEffect();
        sombraTexto.Color = Colors.Black; sombraTexto.BlurRadius = 4; sombraTexto.ShadowDepth = 1; sombraTexto.Opacity = 0.7;
        etiqueta.Effect = sombraTexto;
        TextOptions.SetTextRenderingMode(etiqueta, TextRenderingMode.ClearType);
        fila.Children.Add(etiqueta);

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
        reloj2.Tick += delegate { AnimarOnda(); };
        reloj2.Start();

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

    void Latido()
    {
        var a = new DoubleAnimation(0.5, 1.0, TimeSpan.FromMilliseconds(1700));
        a.AutoReverse = true;
        a.RepeatBehavior = RepeatBehavior.Forever;
        a.EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut };
        punto.BeginAnimation(OpacityProperty, a);
    }

    void AnimarOnda()
    {
        if (onda.Opacity < 0.05) { return; }
        fase += 0.45;
        // el asistente no siempre manda nivel; con un minimo la onda respira
        // sola mientras escucha en vez de quedarse plana como si estuviera muerta
        double nivel = Math.Max(nivelActual, 0.35);
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

    void LeerEstado()
    {
        string est = "reposo", txt = "";
        double niv = 0;
        try
        {
            if (File.Exists(rutaEstado))
            {
                string j = File.ReadAllText(rutaEstado, System.Text.Encoding.UTF8);
                est = Campo(j, "estado", "reposo");
                txt = Campo(j, "texto", "");
                double.TryParse(Campo(j, "nivel", "0"), NumberStyles.Any,
                                CultureInfo.InvariantCulture, out niv);
            }
        }
        catch { }

        nivelActual = niv;
        if (est != estadoActual || txt != textoActual)
        {
            bool estabaEnReposo = (estadoActual == "" || estadoActual == "reposo");
            estadoActual = est;
            textoActual = txt;
            // al salir del reposo se refresca lo que hay detras: el escritorio
            // puede haber cambiado desde la ultima vez
            if (estabaEnReposo && est != "reposo") { CapturarFondo(); }
            Aplicar(est, txt);
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

    void Aplicar(string estado, string texto)
    {
        PonerEncima();
        Color c = ColorDe(estado);
        Animar(punto.Fill as SolidColorBrush, c);
        var bp = punto.Effect as DropShadowEffect;
        if (bp != null) { bp.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350))); }
        bordeAbajo.BeginAnimation(GradientStop.ColorProperty,
            new ColorAnimation(Color.FromArgb(0x66, c.R, c.G, c.B), TimeSpan.FromMilliseconds(350)));
        foreach (var b in barras) { Animar(b.Fill as SolidColorBrush, c); }
        resplandor.BeginAnimation(DropShadowEffect.ColorProperty, new ColorAnimation(c, TimeSpan.FromMilliseconds(350)));

        bool expandida = (estado != "reposo") || !string.IsNullOrEmpty(texto);
        bool conOnda = (estado == "escuchando");

        etiqueta.Text = texto;
        Desvanecer(etiqueta, string.IsNullOrEmpty(texto) ? 0 : 1, 220);
        // la onda invisible seguia ocupando sitio y cortaba el texto: se
        // colapsa del todo cuando no se escucha
        onda.Visibility = conOnda ? Visibility.Visible : Visibility.Collapsed;
        Desvanecer(onda, conOnda ? 1 : 0, 220);

        double destino = ALTO;   // en reposo, un circulo perfecto
        if (expandida)
        {
            double anchoOnda = conOnda ? (BARRAS_ONDA * 6 + 12) : 0;
            double anchoTexto = string.IsNullOrEmpty(texto) ? 0 : MedirTexto(texto) + 12;
            double exacto = (ALTO - DIAM_PUNTO) / 2 + DIAM_PUNTO + anchoOnda + anchoTexto + 16 + 2;
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
