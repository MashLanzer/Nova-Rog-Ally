# C15: LEER UNA ZONA DE LA PANTALLA.
# Comprueba las dos mitades del asunto, sin micrófono, sin Nova encendida y sin
# cargar ni un modelo de voz:
#   1. Get-ZonaRect recorta donde debe (sacada del archivo real con el AST).
#   2. el OCR de Windows, sobre ese recorte, lee lo de esa zona y NO lo de la
#      contraria; es lo único que demuestra que "lee la esquina de arriba a la
#      derecha" sirve de algo con un juego delante.
#   3. cada frase acaba en SU zona (assistant.ps1 -Probar). Aquí está lo de cero
#      órdenes equivocadas: el banco de frases solo mira que algo se reconozca,
#      así que leer la esquina contraria le pasaría en verde.
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Invoke-Expression (TraerFn 'Await-WinRT')
Invoke-Expression (TraerFn 'Invoke-OCR')
Invoke-Expression (TraerFn 'Get-ZonaRect')
$fallos = 0

# --- 1. el recorte, en números -----------------------------------------
# Pantalla de mentira de 1280x720 en el origen 0,0. De cada zona se comprueba un
# punto que TIENE que entrar y otro que NO, que es la diferencia entre leer la
# esquina pedida y leer la de enfrente.
Write-Host "--- donde recorta cada zona (1280x720) ---"
$casosR = @(
    @{ zona = ''; dentro = @(10, 10); fuera = @(10, 10) }
    @{ zona = 'arriba'; dentro = @(640, 20); fuera = @(640, 700) }
    @{ zona = 'abajo'; dentro = @(640, 700); fuera = @(640, 20) }
    @{ zona = 'izquierda'; dentro = @(20, 360); fuera = @(1260, 360) }
    @{ zona = 'derecha'; dentro = @(1260, 360); fuera = @(20, 360) }
    @{ zona = 'arriba-derecha'; dentro = @(1260, 20); fuera = @(20, 700) }
    @{ zona = 'arriba-izquierda'; dentro = @(20, 20); fuera = @(1260, 700) }
    @{ zona = 'abajo-derecha'; dentro = @(1260, 700); fuera = @(20, 20) }
    @{ zona = 'abajo-izquierda'; dentro = @(20, 700); fuera = @(1260, 20) }
    @{ zona = 'centro'; dentro = @(640, 360); fuera = @(20, 20) }
)
foreach ($c in $casosR) {
    $r = Get-ZonaRect 0 0 1280 720 $c.zona
    $area = [int](100 * ($r.w * $r.h) / (1280.0 * 720.0))
    $nom = if ($c.zona) { $c.zona } else { '(entera)' }
    Write-Host ("   {0,-18} x={1,-5} y={2,-5} w={3,-5} h={4,-5} {5}% de la pantalla" -f $nom, $r.x, $r.y, $r.w, $r.h, $area)
    if (-not $c.zona) {
        if ($r.w -ne 1280 -or $r.h -ne 720) { Write-Host "   MAL: sin zona tendria que salir la pantalla entera" -ForegroundColor Red; $fallos++ }
        continue
    }
    $px = $c.dentro[0]; $py = $c.dentro[1]
    if ($px -lt $r.x -or $px -ge ($r.x + $r.w) -or $py -lt $r.y -or $py -ge ($r.y + $r.h)) {
        Write-Host ("   MAL: {0} deja fuera el punto {1},{2}" -f $c.zona, $px, $py) -ForegroundColor Red; $fallos++
    }
    $qx = $c.fuera[0]; $qy = $c.fuera[1]
    if ($qx -ge $r.x -and $qx -lt ($r.x + $r.w) -and $qy -ge $r.y -and $qy -lt ($r.y + $r.h)) {
        Write-Host ("   MAL: {0} se lleva tambien el punto {1},{2}, que es de la zona contraria" -f $c.zona, $qx, $qy) -ForegroundColor Red; $fallos++
    }
    # y que sea MENOS pantalla que antes: de ahi sale que no pueda tardar mas
    if (($r.w * $r.h) -ge (1280 * 720)) { Write-Host ("   MAL: {0} no recorta nada" -f $c.zona) -ForegroundColor Red; $fallos++ }
}

# --- 2. el OCR sobre el recorte ----------------------------------------
# Un HUD de mentira: las cuatro esquinas y un cartel en medio, como un juego.
$png = Join-Path $env:TEMP 'ocr-zona-prueba.png'
$bmp = New-Object System.Drawing.Bitmap(1280, 720)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Black)
$fuente = New-Object System.Drawing.Font('Segoe UI', 30, [System.Drawing.FontStyle]::Bold)
$blanco = [System.Drawing.Brushes]::White
$g.DrawString('OBJETIVO ALFA', $fuente, $blanco, 25, 20)
$g.DrawString('MUNICION 47', $fuente, $blanco, 930, 20)
$g.DrawString('SALUD 88', $fuente, $blanco, 25, 630)
$g.DrawString('MAPA NORTE', $fuente, $blanco, 930, 630)
$g.DrawString('PULSA X', $fuente, $blanco, 570, 340)
$g.Dispose(); $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

function LeerZona([string]$zona) {
    $ent = New-Object System.Drawing.Bitmap($png)
    $sal = Join-Path $env:TEMP 'ocr-zona-recorte.png'
    try {
        $r = Get-ZonaRect 0 0 $ent.Width $ent.Height $zona
        $rec = New-Object System.Drawing.Rectangle($r.x, $r.y, $r.w, $r.h)
        $cor = $ent.Clone($rec, $ent.PixelFormat)
        $cor.Save($sal, [System.Drawing.Imaging.ImageFormat]::Png)
        $cor.Dispose()
    } finally { $ent.Dispose() }
    return (Invoke-OCR $sal).ToUpperInvariant()
}

Write-Host ""
Write-Host "--- lo que lee el OCR de cada zona ---"
$casosO = @(
    @{ zona = 'arriba-derecha'; espera = 'MUNICION'; nunca = 'SALUD' }
    @{ zona = 'arriba-izquierda'; espera = 'OBJETIVO'; nunca = 'MAPA' }
    @{ zona = 'abajo-derecha'; espera = 'MAPA'; nunca = 'OBJETIVO' }
    @{ zona = 'abajo-izquierda'; espera = 'SALUD'; nunca = 'MUNICION' }
    @{ zona = 'arriba'; espera = 'OBJETIVO'; nunca = 'SALUD' }
    @{ zona = 'abajo'; espera = 'MAPA'; nunca = 'MUNICION' }
    @{ zona = 'izquierda'; espera = 'OBJETIVO'; nunca = 'MUNICION' }
    @{ zona = 'derecha'; espera = 'MUNICION'; nunca = 'OBJETIVO' }
    @{ zona = 'centro'; espera = 'PULSA'; nunca = 'OBJETIVO' }
)
foreach ($c in $casosO) {
    $t = LeerZona $c.zona
    Write-Host ("   {0,-18} -> '{1}'" -f $c.zona, $t)
    if ($t -notmatch $c.espera) { Write-Host ("   MAL: en {0} tendria que leerse {1}" -f $c.zona, $c.espera) -ForegroundColor Red; $fallos++ }
    if ($t -match $c.nunca) { Write-Host ("   MAL: en {0} se ha colado {1}, que es de la zona contraria" -f $c.zona, $c.nunca) -ForegroundColor Red; $fallos++ }
}
# y la pantalla entera sigue trayendolo todo: eso es lo que no se puede romper
$todo = LeerZona ''
Write-Host ("   (entera)           -> '{0}'" -f $todo)
foreach ($p in @('OBJETIVO', 'MUNICION', 'SALUD', 'MAPA', 'PULSA')) {
    if ($todo -notmatch $p) { Write-Host ("   MAL: leyendo la pantalla entera falta {0}" -f $p) -ForegroundColor Red; $fallos++ }
}
Remove-Item $png -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:TEMP 'ocr-zona-recorte.png') -Force -ErrorAction SilentlyContinue

# --- 3. que cada frase acabe en SU zona --------------------------------
Write-Host ""
Write-Host "--- que zona sale de cada frase ---"
$casosF = [ordered]@{
    'lee la esquina de arriba a la derecha'    = 'leer la esquina de arriba a la derecha'
    'lee arriba a la derecha'                  = 'leer la esquina de arriba a la derecha'
    'leeme la esquina de abajo a la izquierda' = 'leer la esquina de abajo a la izquierda'
    'que dice arriba a la derecha'             = 'leer la esquina de arriba a la derecha'
    'dime que dice arriba a la derecha'        = 'leer la esquina de arriba a la derecha'
    'lee la esquina superior derecha'          = 'leer la esquina de arriba a la derecha'
    'lee la derecha de arriba'                 = 'leer la esquina de arriba a la derecha'
    'lee la mitad de arriba'                   = 'leer la parte de arriba'
    'lee la parte de abajo'                    = 'leer la parte de abajo'
    'lee lo de arriba'                         = 'leer la parte de arriba'
    'que dice abajo'                           = 'leer la parte de abajo'
    'lee el lado izquierdo'                    = 'leer la izquierda'
    'lee la parte derecha'                     = 'leer la derecha'
    'lee el centro'                            = 'leer el centro'
    'que pone en el medio'                     = 'leer el centro'
    'lee la pantalla'                          = 'leer la pantalla'
    'lee lo que dice la pantalla'              = 'leer la pantalla'
    'que pone aqui'                            = 'leer la pantalla'
    'lee el texto'                             = 'leer la pantalla'
    'sigue leyendo'                            = 'seguir leyendo'
}
$lista = Join-Path $env:TEMP ('ocr-zona-frases-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
[System.IO.File]::WriteAllLines($lista, @($casosF.Keys))
$salida = & powershell -NoProfile -File $ruta -Probar $lista 2>&1
Remove-Item $lista -Force -ErrorAction SilentlyContinue
foreach ($frase in @($casosF.Keys)) {
    $esp = [string]$casosF[$frase]
    $lin = @($salida | Where-Object { "$_" -match ('^\s+OK\s+' + [regex]::Escape($frase) + '\s+->\s+(.+)$') })
    if ($lin.Count -eq 0) {
        Write-Host ("   MAL: '{0}' ya no se reconoce en local" -f $frase) -ForegroundColor Red
        $fallos++
        continue
    }
    $hizo = ''
    if ("$($lin[0])" -match '->\s+(.+?)\s*$') { $hizo = $Matches[1] }
    $marca = if ($hizo -eq $esp) { 'ok  ' } else { 'MAL ' }
    Write-Host ("   {0} {1,-42} -> {2}" -f $marca, $frase, $hizo)
    if ($hizo -ne $esp) { Write-Host ("        tendria que ser: {0}" -f $esp) -ForegroundColor Red; $fallos++ }
}

Write-Host ""
if ($fallos -eq 0) { Write-Host "leer una zona de la pantalla: todo correcto" }
else { Write-Host ("MAL: {0} fallos leyendo por zonas" -f $fallos) -ForegroundColor Red; exit 1 }
