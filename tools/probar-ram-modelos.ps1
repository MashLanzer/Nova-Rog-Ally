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

Write-Host '  -- y a Parakeet tambien, pero con mucha mas paciencia --'
$iPar = $fuente.IndexOf('def soltar_parakeet_si_toca(')
$jPar = $fuente.IndexOf("`ndef ", $iPar + 5)
if ($jPar -lt 0) { $jPar = $fuente.Length }
$cuerpoPar = $fuente.Substring($iPar, $jPar - $iPar)
# ESTO CAMBIO EL 22/09, y conviene saber por que, porque lo de antes tambien estaba bien
# razonado: 'a Parakeet no se le pone plazo, que se usa cada 28 s'. Sigue siendo verdad -medido
# sobre los 477 huecos del log: 31 s de mediana, 51 el p75, 170 el p90-, pero desde que se
# PRECARGA al arrancar (ver PRECARGA en wake_vosk.py) ya no se carga solo cuando hace falta:
# esta siempre dentro, aunque braya no diga nada en toda la manana, y son 703 MB. El 22/09 la
# consola se quedo en 2.946 MB libres de 11.979 con el worker del oido en 1.103.
# Asi que se le da plazo, pero LARGO: con 20 min se suelta 19 veces de 477 -el 4 % de los
# huecos, los de verdad largos- y recargarlo cuesta 4,8 s. La intencion de la regla vieja se
# respeta entera: no cortar una racha. Lo que se vigila aqui es justo eso.
Comp 'parakeet tiene plazo tambien sin juego' ($cuerpoPar -match 'PARAKEET_SOLTAR_QUIETO') ''
Comp 'y distingue si hay juego o no' ($cuerpoPar -match 'hay_juego') ''
Comp 'y lo dice en el log' ($cuerpoPar -match 'parakeet soltado') ''
$qj = if ($fuente -match '(?m)^PARAKEET_SOLTAR_JUGANDO = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
$qq = if ($fuente -match '(?m)^PARAKEET_SOLTAR_QUIETO = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
Comp 'sin juego se espera MAS que jugando' ($qq -gt $qj) ("$qq s frente a $qj s")
# el p90 de los huecos entre usos es 170 s: el plazo tiene que dejarlo pasar con mucho margen
Comp 'y lo bastante como para no cortar una racha' ($qq -ge 900) ("$qq s, y el p90 de los huecos es 170 s")
Comp 'pasa por plazo_soltar, o no mirara la RAM' ($cuerpoPar -match 'plazo_soltar\(') ''

Write-Host '  -- y si a Parakeet le falta poco, se hace sitio el mismo (19/09) --'
Comp 'existe hacer_sitio_a_parakeet' ($fuente -match 'def hacer_sitio_a_parakeet\(') ''
$iHs = $fuente.IndexOf('def hacer_sitio_a_parakeet(')
$jHs = $fuente.IndexOf("`ndef ", $iHs + 5)
if ($jHs -lt 0) { $jHs = $fuente.Length }
$cuerpoHs = if ($iHs -ge 0) { $fuente.Substring($iHs, $jHs - $iHs) } else { '' }
Comp 'suelta el oido fino, no otra cosa' ($cuerpoHs -match '_preciso = None') ''
Comp 'no lo toca si se acaba de usar' ($cuerpoHs -match '_preciso_uso < PARAKEET_QUIETO_FINO') ''
Comp 'y vuelve a medir despues de soltarlo' ($cuerpoHs -match 'ahora = ram_libre_mb\(\)') ''
Comp 'lo deja dicho en el log' ($cuerpoHs -match 'hacerle sitio a Parakeet') ''
$qf = if ($fuente -match '(?m)^PARAKEET_QUIETO_FINO = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
Comp 'el plazo es corto pero no cero' ($qf -ge 30 -and $qf -le 300) ("$qf s")
$iPk = $fuente.IndexOf('def modelo_parakeet(')
$jPk = $fuente.IndexOf("`ndef ", $iPk + 5)
$cuerpoPk = $fuente.Substring($iPk, $jPk - $iPk)
Comp 'modelo_parakeet lo intenta ANTES de rendirse' (
    $cuerpoPk.IndexOf('hacer_sitio_a_parakeet') -gt 0 -and
    $cuerpoPk.IndexOf('hacer_sitio_a_parakeet') -lt $cuerpoPk.IndexOf('no lo cargo')) ''
Comp 'y si aun asi no cabe, sigue sin cargarlo' ($cuerpoPk -match 'no lo cargo, solo quedan' -and $cuerpoPk -match 'return None') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
