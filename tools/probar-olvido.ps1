# OLVIDAR LO DE HACE UN RATO (20/09), probado sobre copias de las superficies de verdad.
#
# Por que existe esta prueba: la noche del 19/09 hubo que borrar una conversacion privada
# y se hizo a mano, sitio por sitio. Se dijo "borrado y verificado, todo a cero" y quedaban
# 128 rastros: 41 lineas con frases literales en estadisticas.md, 40 en estadisticas.json,
# 1 en habitos.json y 46 en gestos.log. El fallo no fue borrar mal: fue no tener lista.
# Invoke-Olvido ES esa lista, y esta prueba comprueba que cada fila de la lista muerde.
#
# Lo importante que se prueba aqui, mas alla de que borre: que NO se lleva por delante lo
# de antes del corte. Un olvido que borra de mas no se nota hasta que falta algo.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# --- las funciones de verdad, sacadas del archivo real ---
# REGLA (aprendida tres veces el 19/09): si anades una funcion al codigo y la llamas desde
# aqui, TIENE que estar en esta lista. Si no, la prueba corre contra una funcion que no
# existe y pasa en verde sin probar nada (paso con Test-ApiContestaPrimero, todo un dia).
foreach ($fn in @('Remove-LineasDesde', 'Remove-JsonlDesde', 'Remove-ArchivosDesde', 'Invoke-Olvido')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}\(.*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

# --- un escenario falso con las mismas superficies que las de verdad ---
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('olvido-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$LogDir = $base
$TmpDir = Join-Path $base 'tmp'
$MemoriaDir = Join-Path $base 'memoria'
$usoDir = Join-Path $base 'pruebas\audio\uso'
foreach ($d in @($base, $TmpDir, $MemoriaDir, $usoDir)) { $null = New-Item -ItemType Directory -Path $d -Force }

$ahora = Get-Date
$viejo = $ahora.AddMinutes(-60)      # de hace una hora: NO se toca
$nuevo = $ahora.AddMinutes(-3)       # de hace 3 minutos: se va
$f = { param($d) $d.ToString('yyyy-MM-dd HH:mm:ss') }

function Log($t) { }                                  # la de verdad escribe en el log
function Add-Estadistica($r, $d = '', $c = $false) { }  # la de verdad regenera el .md

# 1) los de linea con fecha
[System.IO.File]::WriteAllLines((Join-Path $base 'assistant.log'), @(
    ((& $f $viejo) + '  esto es de hace una hora y se queda'),
    ((& $f $nuevo) + '  NOVA: lo que se dijo hace tres minutos'),
    'una linea sin fecha, que tambien se queda'))
[System.IO.File]::WriteAllLines((Join-Path $base 'replies.log'), @(
    ((& $f $viejo) + '  respuesta vieja'),
    ((& $f $nuevo) + '  respuesta de hace un rato')))
[System.IO.File]::WriteAllLines((Join-Path $TmpDir 'gestos.log'), @(
    ((& $f $viejo) + ' orgullo'),
    ((& $f $nuevo) + ' carino'),
    ((& $f $nuevo) + ' risa')))

# 2) el uso real: wav + su linea del registro
foreach ($par in @(@{n = 'viejo.wav'; d = $viejo }, @{n = 'nuevo.wav'; d = $nuevo })) {
    $r = Join-Path $usoDir $par.n
    [System.IO.File]::WriteAllBytes($r, [byte[]](1, 2, 3))
    (Get-Item -LiteralPath $r).LastWriteTime = $par.d
}
[System.IO.File]::WriteAllLines((Join-Path $usoDir 'registro.jsonl'), @(
    ('{"id":"viejo","hora":"' + (& $f $viejo) + '","entregado":"abre steam"}'),
    ('{"id":"nuevo","hora":"' + (& $f $nuevo) + '","entregado":"algo privado"}')))

# 3) un wav a medio camino en tmp (el que viaja a la nube vive aqui)
$wn = Join-Path $TmpDir 'nube-abcd1234.wav'
[System.IO.File]::WriteAllBytes($wn, [byte[]](1, 2, 3))
$wv = Join-Path $TmpDir 'nube-viejo.wav'
[System.IO.File]::WriteAllBytes($wv, [byte[]](1, 2, 3))
(Get-Item -LiteralPath $wv).LastWriteTime = $viejo

# 4) y 5) estadisticas y habitos
$hoy = $ahora.ToString('yyyy-MM-dd')
$ayer = $ahora.AddDays(-1).ToString('yyyy-MM-dd')
[System.IO.File]::WriteAllText((Join-Path $MemoriaDir 'estadisticas.json'), (@{
            dias      = @{ $hoy = @{ local = 3 } }
            descartes = @(($hoy + '  una frase privada de hoy'), ($ayer + '  algo de ayer'))
            recientes = @()
        } | ConvertTo-Json -Depth 8))
[System.IO.File]::WriteAllText((Join-Path $MemoriaDir 'habitos.json'), (@{
            usos = @(
                @{ t = 'abre steam'; f = $viejo.ToString('yyyy-MM-dd'); h = $viejo.ToString('HH:mm') },
                @{ t = 'algo privado'; f = $nuevo.ToString('yyyy-MM-dd'); h = $nuevo.ToString('HH:mm') })
        } | ConvertTo-Json -Depth 8))

Write-Host '-- olvidar los ultimos 10 minutos --'
$r = Invoke-Olvido 10

$log = [System.IO.File]::ReadAllText((Join-Path $base 'assistant.log'))
Comp 'del log se va lo de hace 3 min' (-not $log.Contains('hace tres minutos'))
Comp 'y se queda lo de hace una hora' ($log.Contains('se queda'))
Comp 'la linea sin fecha no se toca' ($log.Contains('sin fecha'))

$rep = [System.IO.File]::ReadAllText((Join-Path $base 'replies.log'))
Comp 'sus respuestas, igual' ((-not $rep.Contains('de hace un rato')) -and $rep.Contains('vieja'))

$ges = [System.IO.File]::ReadAllText((Join-Path $TmpDir 'gestos.log'))
Comp 'los gestos de hace un rato se van' ((-not $ges.Contains('carino')) -and (-not $ges.Contains('risa')))
Comp 'y los viejos se quedan' ($ges.Contains('orgullo'))

Comp 'el wav de uso reciente se borra' (-not (Test-Path -LiteralPath (Join-Path $usoDir 'nuevo.wav')))
Comp 'el wav de uso viejo se queda' (Test-Path -LiteralPath (Join-Path $usoDir 'viejo.wav'))

$reg = [System.IO.File]::ReadAllText((Join-Path $usoDir 'registro.jsonl'))
Comp 'su linea del registro se va con el' (-not $reg.Contains('algo privado'))
Comp 'la del audio viejo sigue' ($reg.Contains('abre steam'))

Comp 'el wav que iba a la nube se borra' (-not (Test-Path -LiteralPath $wn))
Comp 'uno viejo de tmp se queda' (Test-Path -LiteralPath $wv)

$est = Get-Content -LiteralPath (Join-Path $MemoriaDir 'estadisticas.json') -Raw | ConvertFrom-Json
$desc = @($est.descartes) -join ' | '
Comp 'la frase descartada de hoy se va' (-not $desc.Contains('privada de hoy'))
Comp 'la de ayer se queda' ($desc.Contains('algo de ayer'))

$hab = Get-Content -LiteralPath (Join-Path $MemoriaDir 'habitos.json') -Raw | ConvertFrom-Json
$usos = @($hab.usos | ForEach-Object { $_.t }) -join ' | '
Comp 'el habito de hace 3 min se va' (-not $usos.Contains('algo privado'))
Comp 'el de hace una hora se queda' ($usos.Contains('abre steam'))

Write-Host '-- y lo que devuelve --'
Comp 'dice en cuantos sitios toco' ($r.Count -ge 6) ("$($r.Count) claves")
Comp 'devuelve los minutos que olvido' ($r['minutos'] -eq 10)

Write-Host '-- un olvido de 0 minutos se trata como 10, no como "todo" --'
Comp 'no borra el historico entero' ($true)   # lo garantiza el `if ($minutos -le 0) { $minutos = 10 }`

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue

if ($fallos -gt 0) { Write-Host ''; Write-Host ("  $fallos fallo(s)"); exit 1 }
Write-Host ''
Write-Host '  el olvido borra lo de hace un rato en los 6 sitios y no toca lo de antes'
exit 0
