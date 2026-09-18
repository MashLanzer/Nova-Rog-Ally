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

Write-Host '  -- y el oido fino se suelta tambien sin juego (idea 12) --'
# Medido en el log: entre dos usos del oido fino pasan 111 s de mediana, pero el 30 % de los
# huecos pasa de 5 min y el 13 % de media hora. Recargarlo cuesta 2,5 s. Retenerlo horas por
# ahorrar 2,5 s es mal negocio. Parakeet NO: se usa cada 28 s de mediana y cuesta 5,6 s.
$iSol = $fuente.IndexOf('def soltar_preciso_si_toca(')
$jSol = $fuente.IndexOf("`ndef ", $iSol + 5)
if ($jSol -lt 0) { $jSol = $fuente.Length }
$cuerpoSol = $fuente.Substring($iSol, $jSol - $iSol)
Comp 'soltar_preciso mira si hay juego' ($cuerpoSol -match 'hay_juego') ''
Comp 'y tiene un plazo para cada caso' ($cuerpoSol -match 'PRECISO_SOLTAR_JUGANDO' -and $cuerpoSol -match 'PRECISO_SOLTAR_QUIETO') ''
Comp 'ya NO se rinde cuando no hay juego' ($cuerpoSol -notmatch 'if not \(MARCA_SOLO_BOTON') ''
Comp 'y dice en el log cual de los dos fue' ($cuerpoSol -match 'sin juego delante') ''

$pj = if ($fuente -match '(?m)^PRECISO_SOLTAR_JUGANDO = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
$pq = if ($fuente -match '(?m)^PRECISO_SOLTAR_QUIETO = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
Comp 'sin juego se espera MAS que jugando' ($pq -gt $pj) ("$pq s frente a $pj s")
Comp 'y lo bastante como para no cortar una racha' ($pq -ge 600) ("$pq s")

Write-Host '  -- pero a Parakeet no se le pone plazo (se usa cada 28 s) --'
$iPar = $fuente.IndexOf('def soltar_parakeet_si_toca(')
$jPar = $fuente.IndexOf("`ndef ", $iPar + 5)
if ($jPar -lt 0) { $jPar = $fuente.Length }
$cuerpoPar = $fuente.Substring($iPar, $jPar - $iPar)
Comp 'parakeet solo se suelta jugando, sin plazo' ($cuerpoPar -match 'jugando\(\)' -and $cuerpoPar -notmatch 'SOLTAR_QUIETO') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
