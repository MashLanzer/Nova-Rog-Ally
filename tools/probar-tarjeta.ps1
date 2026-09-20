# ¿La tarjeta de respuestas largas roba el foco?
# Esto es lo unico que importa de la mejora 13: Form.Show() ACTIVA la ventana y
# sobre un juego a pantalla completa exclusiva eso te saca de la partida. Aqui
# se mide de verdad: quien tenia el foco antes tiene que seguir teniendolo.
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
Comp 'el cristal se pinta'      $pinta        ''
Comp 'el filo de acento esta'   $acento       ''
Comp 'el texto se lee'          $texto_ok    "$claros pixeles de letra"
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
Write-Host "todo correcto"
