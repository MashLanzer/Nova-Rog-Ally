# ¿La tarjeta de respuestas largas roba el foco?
# Esto es lo unico que importa de la mejora 13: Form.Show() ACTIVA la ventana y
# sobre un juego a pantalla completa exclusiva eso te saca de la partida. Aqui
# se mide de verdad: quien tenia el foco antes tiene que seguir teniendolo.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$raiz = Split-Path -Parent $PSScriptRoot
Add-Type -Path (Join-Path $raiz 'assistant-dx.dll')

$texto = ("Respuesta larga de prueba. " * 12)
$antes = [AX]::GetForegroundWindow()

$f = New-Object AXTarjeta
$f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$f.ShowInTaskbar = $false
$f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$f.BackColor = [System.Drawing.Color]::FromArgb(13, 17, 25)
$f.ForeColor = [System.Drawing.Color]::FromArgb(238, 243, 248)
$f.Opacity = 0.95
$fuente = New-Object System.Drawing.Font("Segoe UI", 10.5)
$margen = 16; $barra = 3; $anchoMax = 560
$medida = [System.Windows.Forms.TextRenderer]::MeasureText($texto, $fuente,
    (New-Object System.Drawing.Size($anchoMax, 0)),
    ([System.Windows.Forms.TextFormatFlags]::WordBreak))
$f.ClientSize = New-Object System.Drawing.Size(([Math]::Min($anchoMax, $medida.Width) + $margen * 2 + $barra + 6), ($medida.Height + $margen * 2))
$bar = New-Object System.Windows.Forms.Panel
$bar.Dock = [System.Windows.Forms.DockStyle]::Left; $bar.Width = $barra
$bar.BackColor = [System.Drawing.Color]::FromArgb(53, 224, 200)
$l = New-Object System.Windows.Forms.Label
$l.Text = $texto; $l.AutoSize = $false
$l.Dock = [System.Windows.Forms.DockStyle]::Fill
$l.Padding = New-Object System.Windows.Forms.Padding($margen, $margen, $margen, $margen)
$l.Font = $fuente; $l.ForeColor = $f.ForeColor
$l.BackColor = [System.Drawing.Color]::Transparent
$f.Controls.Add($l); $f.Controls.Add($bar)
$s = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$f.Location = New-Object System.Drawing.Point(($s.Right - $f.Width - 24), ($s.Bottom - $f.Height - 78))

$h = $f.Handle
$rgn = [AX]::RegionRedonda($f.Width, $f.Height, 16)
$redondeada = ($rgn -ne [IntPtr]::Zero)
if ($redondeada) { $f.Region = [System.Drawing.Region]::FromHrgn($rgn) }

$f.Show()
$mostro = [AX]::IsWindowVisible($h)
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 400
[System.Windows.Forms.Application]::DoEvents()
$despues = [AX]::GetForegroundWindow()
# OJO: $f.Visible es la idea que tiene WinForms, y como la ventana se saca por
# Win32 sigue creyendola oculta. Lo que vale es lo que ve el sistema.
$visible = [AX]::IsWindowVisible($h)
$tam = "$($f.Width)x$($f.Height)"

# ESTA LA TARJETA ENCIMA DONDE SE LA FOTOGRAFIA? (25/09, corrige la guarda del 21/09)
# Lo de abajo fotografia el trozo de pantalla donde deberia estar la tarjeta. Si algo la
# tapa, lo que se mide es lo de encima. El 25/09 salieron DOS ROJOS FALSOS porque el TECLADO
# TACTIL de Windows estaba abierto -en una consola de mano es la manera normal de escribir- y
# cubre la mitad de abajo de la pantalla, justo donde se pinta la tarjeta. Se guardo la
# captura para verlo: sale el teclado. Y enganaba en las tres comprobaciones a la vez, porque
# el teclado es oscuro (el "cristal se pinta" pasaba por la razon equivocada), no tiene filo
# verde, y sus letras dejan 186 pixeles claros contra los 1.297 de la tarjeta.
# LA GUARDA QUE HABIA preguntaba "hay un JUEGO a pantalla completa?": el 90 % del ancho Y del
# alto, y un proceso que no fuera la consola ni el editor. El teclado no es ninguna de las dos
# cosas -ocupa todo el ancho pero media pantalla de alto, y es de explorer-, asi que pasaba de
# largo. La pregunta buena no es quien hay delante, es SI SE VE LA TARJETA: se le pregunta al
# sistema que ventana hay en seis puntos de su rectangulo, y tienen que ser todos ella.
# Los puntos van metidos hacia dentro a proposito: las esquinas estan redondeadas con radio 16
# y ahi el sistema contesta lo que hay DEBAJO, que seria un tapado de mentira.
# Y se puede preguntar asi porque la tarjeta NO es transparente al raton: en assistant-dx.cs
# lleva NOACTIVATE, TOOLWINDOW y TOPMOST, pero no WS_EX_TRANSPARENT.
$tapadaPor = ''
try {
    Add-Type -Namespace TJ -Name Enc -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr WindowFromPoint(System.Drawing.Point p);
[DllImport("user32.dll")] public static extern System.IntPtr GetAncestor(System.IntPtr h, uint flags);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr h, out uint pid);
'@ -ReferencedAssemblies System.Drawing -ErrorAction Stop
    $medio = $f.Top + [int]($f.Height / 2)
    $puntos = @(
        (New-Object System.Drawing.Point(($f.Left + 2),               $medio)),
        (New-Object System.Drawing.Point(($f.Left + [int]($f.Width / 2)), $medio)),
        (New-Object System.Drawing.Point(($f.Left + 24),              ($f.Top + 12))),
        (New-Object System.Drawing.Point(($f.Left + $f.Width - 24),   ($f.Top + 12))),
        (New-Object System.Drawing.Point(($f.Left + 24),              ($f.Top + $f.Height - 12))),
        (New-Object System.Drawing.Point(($f.Left + $f.Width - 24),   ($f.Top + $f.Height - 12)))
    )
    foreach ($pt in $puntos) {
        $hEncima = [TJ.Enc]::WindowFromPoint($pt)
        if ($hEncima -eq [IntPtr]::Zero) { continue }
        $raizEncima = [TJ.Enc]::GetAncestor($hEncima, 2)   # GA_ROOT: el punto puede caer en un hijo
        if ($raizEncima -eq $h) { continue }
        # DE QUIEN ES ESA VENTANA. Se pregunta por el HANDLE, no buscando el proceso cuyo
        # MainWindowHandle coincida: el teclado tactil no tiene ventana principal, asi que por
        # ahi salia 'otra ventana' y el aviso no decia que cerrar.
        $pid2 = [uint32]0
        [void][TJ.Enc]::GetWindowThreadProcessId($raizEncima, [ref]$pid2)
        $pEncima = if ($pid2) { Get-Process -Id $pid2 -ErrorAction SilentlyContinue } else { $null }
        $tapadaPor = if ($pEncima) { $pEncima.ProcessName } else { 'otra ventana' }
        break
    }
} catch { $tapadaPor = '' }
$sinMedir = ($tapadaPor -ne '')
$sinMedirN = 0
if ($sinMedir) {
    Write-Host ("  --   algo tapa la tarjeta ($tapadaPor): la captura saldria de ahi y no de ella") -ForegroundColor DarkGray
    Write-Host ('       Lo que se VE no se puede medir aqui. Cierra lo que tape esa esquina y repite.') -ForegroundColor DarkGray
}

# Y QUE SE VEA DE VERDAD: se fotografia el trozo de pantalla donde esta. Sin
# esto, una tarjeta que no pinta nada pasaria las otras tres comprobaciones.
$pinta = $false; $acento = $false; $script:texto_ok = $false; $claros = 0
try {
    $bmp = New-Object System.Drawing.Bitmap($f.Width, $f.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($f.Left, $f.Top, 0, 0, (New-Object System.Drawing.Size($f.Width, $f.Height)))
    $g.Dispose()
    $suma = 0; $n = 0
    for ($y = 8; $y -lt $bmp.Height - 8; $y += 6) {
        for ($x = 20; $x -lt $bmp.Width - 8; $x += 6) {
            $c = $bmp.GetPixel($x, $y); $suma += ($c.R + $c.G + $c.B) / 3.0; $n++
        }
    }
    $medio = if ($n) { $suma / $n } else { 255 }
    $pinta = ($medio -lt 90)          # cristal oscuro, no el escritorio
    for ($y = 10; $y -lt $bmp.Height - 10; $y += 4) {
        $c = $bmp.GetPixel(2, $y)
        if ($c.G -gt 150 -and $c.B -gt 130 -and $c.R -lt 120) { $acento = $true; break }
    }
    # y que el texto SE LEA: una tarjeta que solo pinta el fondo pasaria todo
    # lo anterior (paso, de hecho, cuando se mostraba por Win32 a pelo)
    $claros = 0
    for ($y = 8; $y -lt $bmp.Height - 8; $y += 2) {
        for ($x = 24; $x -lt $bmp.Width - 8; $x += 2) {
            $c = $bmp.GetPixel($x, $y)
            if ((($c.R + $c.G + $c.B) / 3.0) -gt 140) { $claros++ }
        }
    }
    $script:texto_ok = ($claros -gt 200)
    $bmp.Dispose()
} catch { }

$f.Close(); $f.Dispose(); $fuente.Dispose()

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-34} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
Comp 'se muestra sin activar'   $mostro       "visible=$mostro"
Comp 'la ventana esta visible'  $visible      "tamano $tam"
# LAS TRES QUE SALEN DE LA FOTO. Antes solo se saltaban dos: "el cristal se pinta" se mediía
# igual y pasaba en verde midiendo lo que hubiera encima, que casi siempre tambien es oscuro.
foreach ($c in @(@('el cristal se pinta', $pinta, ''),
                 @('el filo de acento esta', $acento, ''),
                 @('el texto se lee', $texto_ok, "$claros pixeles de letra"))) {
    if ($sinMedir) { Write-Host ("  --   {0,-34} sin medir, la tarjeta esta tapada" -f $c[0]) -ForegroundColor DarkGray; $sinMedirN++ }
    else { Comp $c[0] ([bool]$c[1]) ([string]$c[2]) }
}
Comp 'esquinas redondeadas'     $redondeada   ''
# LO QUE SE MIDE ES QUE LA TARJETA NO ROBE EL FOCO, no que el foco no se mueva (20/09).
# Si mientras corre la prueba hay otra ventana viva -un juego, el navegador- el foco puede
# cambiar por su cuenta, y eso salia ROJO como si lo hubiera robado la tarjeta. Paso con
# It Takes Two y el navegador delante. Lo que de verdad importa es que el foco NO acabe en
# la tarjeta: si se fue a otra parte, esta prueba no se puede medir aqui y lo dice, en vez
# de acusar a la tarjeta de algo que no ha hecho.
if ($despues -eq $antes) {
    Comp 'el foco NO se ha movido' $true "antes=$antes despues=$despues tarjeta=$h"
} elseif ($despues -eq $h) {
    Comp 'el foco NO se ha movido' $false "LO ROBO LA TARJETA: despues=$despues tarjeta=$h"
} else {
    Write-Host '  --   el foco se fue a otra ventana, no a la tarjeta: aqui no se puede medir' -ForegroundColor DarkGray
    Write-Host ("       antes=$antes despues=$despues tarjeta=$h. Cierra lo demas y repite.") -ForegroundColor DarkGray
}

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
# UN VERDE A SECAS CON TRES COSAS SIN MEDIR ES UN VERDE QUE MIENTE. Se conserva el texto
# "todo correcto" porque la bateria lo busca tal cual con Select-String, y el PERO va detras.
if ($sinMedirN) { Write-Host "todo correcto, PERO $sinMedirN sin medir (la tapaba $tapadaPor)"; exit 0 }
Write-Host "todo correcto"
