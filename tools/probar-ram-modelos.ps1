# QUE UN MODELO NO SE CARGUE SI NO CABE (17/09).
#
# El 15/09 paso de verdad: con Parakeet, base y small cargados a la vez quedaron 0,3 GB
# libres de 7,7 y Whisper tardo de 4,5 a 12,9 s por orden en vez de ~1 s. Ya habia guarda
# para la charla (Test-RamParaCharla, 3000 MB) pero NINGUNA para los modelos del oido, que
# son justo los que causaron aquello.
#
# Esto no ejecuta wake_vosk.py (abre el microfono al importarlo): comprueba sobre el FUENTE
# que las guardas siguen puestas y bien puestas, que es lo que se puede estropear sin querer.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [System.Text.Encoding]::UTF8)

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- se puede medir la RAM sin instalar nada --'
Comp 'existe ram_libre_mb' ($fuente -match 'def ram_libre_mb\(') ''
Comp 'y usa ctypes, no una dependencia nueva' ($fuente -match 'GlobalMemoryStatusEx') ''
Comp 'si no se puede medir, devuelve -1' ($fuente -match 'return -1') ''

Write-Host '  -- y los dos modelos pesados la miran antes de cargar --'
foreach ($par in @(@('modelo_parakeet', 'RAM_MIN_PARAKEET'), @('modelo_preciso', 'RAM_MIN_PRECISO'))) {
    $fn = $par[0]; $cte = $par[1]
    $i = $fuente.IndexOf("def $fn(")
    Comp "$fn existe" ($i -ge 0) ''
    if ($i -lt 0) { continue }
    # el cuerpo, hasta el siguiente def de primer nivel
    $j = $fuente.IndexOf("`ndef ", $i + 5)
    if ($j -lt 0) { $j = $fuente.Length }
    $cuerpo = $fuente.Substring($i, $j - $i)
    Comp "  $fn mira la RAM" ($cuerpo -match 'ram_libre_mb\(\)') ''
    Comp "  y la compara con $cte" ($cuerpo -match [regex]::Escape($cte)) ''
    # LO QUE MAS IMPORTA: quedarse sin RAM es pasajero. Marcarlo como roto lo apagaria
    # para siempre, y al cerrar el juego ya habria sitio.
    $iGuarda = $cuerpo.IndexOf('ram_libre_mb()')
    $iTry = $cuerpo.IndexOf('try:')
    Comp "  la guarda va ANTES del try (no lo intenta y falla)" ($iGuarda -ge 0 -and $iTry -ge 0 -and $iGuarda -lt $iTry) ''
    $trozo = if ($iGuarda -ge 0 -and $iTry -gt $iGuarda) { $cuerpo.Substring($iGuarda, $iTry - $iGuarda) } else { '' }
    Comp "  sin RAM NO lo marca como roto (es pasajero)" ($trozo -notmatch '_roto = True') ''
    Comp "  y lo dice en el log" ($trozo -match 'anota\(') ''
}

Write-Host '  -- los numeros tienen sentido --'
$mp = if ($fuente -match '(?m)^RAM_MIN_PARAKEET = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
$mf = if ($fuente -match '(?m)^RAM_MIN_PRECISO = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
Comp 'parakeet pide mas que su tamano en disco (639 MB)' ($mp -gt 639) "$mp MB"
Comp 'el oido fino pide mas que los ~500 MB que ocupa' ($mf -gt 500) "$mf MB"
Comp 'y ninguno pide tanto como la charla (3000 MB)' ($mp -lt 3000 -and $mf -lt 3000) ''
Comp 'parakeet pide mas que el oido fino (ocupa mas)' ($mp -gt $mf) ''

Write-Host '  -- y lo que NO se toca --'
# Vosk y Whisper base se cargan al arrancar y son imprescindibles: sin ellos no hay palabra
# ni dictado por boton. Una guarda de RAM ahi dejaria a Nova inutil, igual que soltar Vosk
# jugando habria roto el boton (ver idea 4).
$iVosk = $fuente.IndexOf('modelo = Model(ruta_modelo)')
Comp 'Vosk se sigue cargando sin condiciones' ($iVosk -ge 0) ''
$antes = $fuente.Substring([Math]::Max(0, $iVosk - 300), [Math]::Min(300, $iVosk))
Comp 'y no se le ha puesto guarda de RAM' ($antes -notmatch 'ram_libre_mb') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
