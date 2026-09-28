# LOS INSTRUMENTOS MUDOS: CONTADORES QUE NO HAN CONTADO NADA (26/09, idea 48 de las 121).
#
# Nova tiene ~90 claves de Add-Estadistica y ~40 no han contado nunca en memoria\estadisticas.json,
# y 13 rutas memoria\* que el codigo nombra pero que no existen en disco. Un contador que nadie
# alimenta o un fichero que nadie escribe es un instrumento mudo: parece que mide y no mide. Este
# banco los caza, pero SOLO los viejos: fecha cada clave por su primer commit y solo acusa si
# lleva mas de $MudoDias sin un solo dato -asi un contador nacido ayer no sale acusado-.
#
# NO se acusa por numero: no se afirma "hay 40 mudas". Ese numero cambia solo con el calendario.
# Lo que se afirma es (A) que toda clave con datos esta en el fuente -si aparece una por una via
# nueva, hay que declararla-, y (C..F) el liston, la excepcion y los almacenes, sobre fixtures.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# LAS 17 CLAVES QUE ENTRAN POR OTRA VIA (no por un literal): lista de MOTIVOS, no un numero. Si
# aparece una decimoctava, la comprobacion A sale roja y pide anadirla aqui con su via.
$otraVia = @(
    'accion', 'plan', 'pregunta', 'traducir',                              # Add-Estadistica $modo $text
    'repaso:base', 'repaso:canary', 'repaso-ahorrado',                     # repaso:$motorC
    'aviso-nada:bateria-llena', 'aviso-nada:cargador-pone', 'aviso-nada:disco-poco',
    'aviso-nada:hora-dormir', 'aviso-nada:lo-que-no-dije', 'aviso-nada:oido-mudo', 'aviso-nada:oido-ruido',
    'aviso-sirvio:lo-que-no-dije', 'aviso-sirvio:me-cai', 'aviso-sirvio:oido-ruido', 'aviso-sirvio:oido-mudo')

# 1. LAS CLAVES DEL FUENTE (literales; las que llevan $ van aparte y no se juzgan)
$literales = @{}
foreach ($m in [regex]::Matches($fuente, "Add-Estadistica\s+['""]([^'""]+)['""]")) {
    $k = $m.Groups[1].Value
    if ($k -notmatch '\$') { $literales[$k] = $true }
}
Comp '1. se encuentran las claves literales en el fuente' ($literales.Count -ge 40) "$($literales.Count) claves literales"

# 3. LAS CLAVES CON DATOS en estadisticas.json (todas las jornadas; PSObject, no hashtable en 5.1)
$conDatos = @{}
# EL FICHERO DE PRODUCCION NO PUEDE DECIDIR EL COLOR (28/09, tras la revision). Esto lee el
# memoria\estadisticas.json DE VERDAD y exige que toda clave con datos este declarada en el fuente o
# en la lista blanca de aqui abajo. Dos problemas, y los dos los tiene documentados el propio
# proyecto en probar-logro-anotado.ps1 ("un rojo que depende de lo que haya en disco hoy no dice
# nada del codigo; eso ya costo dos rojos falsos el 25/09"):
#   - cualquier cosa que escriba una clave mientras el banco corre -otro banco, o Nova viva, que es
#     lo normal ahora- lo pone rojo sin que el codigo haya cambiado;
#   - y al reves, si ese dia el fichero no trae una clave, la comprobacion pasa por no tener nada
#     que mirar, que es la manera 17.
# SE PUEDE APUNTAR A OTRO FICHERO con la variable de entorno NOVA_ESTADISTICAS, que es lo que hace
# el banco cuando quiere un caso fijo; sin ella sigue mirando el de verdad, que tambien informa.
$rutaEst = if ($env:NOVA_ESTADISTICAS) { $env:NOVA_ESTADISTICAS } else { Join-Path $raiz 'memoria\estadisticas.json' }
if (Test-Path -LiteralPath $rutaEst) {
    $j = Get-Content -LiteralPath $rutaEst -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($dia in $j.dias.PSObject.Properties) {
        foreach ($c in $dia.Value.PSObject.Properties) { $conDatos[$c.Name] = $true }
    }
}
Comp '3. estadisticas.json se lee por .dias (PSObject), no crudo' ($conDatos.Count -ge 1) "$($conDatos.Count) claves con datos"
# una clave muy usada TIENE que salir con datos: si se lee $j en vez de $j.dias, conDatos trae
# 'dias'/'decisiones' y no las claves de verdad, y esto lo caza (local es de las mas contadas).
Comp '   una clave muy usada (local) aparece con datos' ($conDatos.ContainsKey('local')) 'si no, se leyo $j y no $j.dias'

# A. AUTOCALIBRADA: toda clave con datos tiene que estar en el fuente o declarada de otra via
$declaradas = @{}; foreach ($k in $otraVia) { $declaradas[$k] = $true }
# LA CLAVE CON DETALLE CUENTA POR SU RAIZ (28/09, tras la revision). Add-Estadistica escribe
# 'raiz:detalle' cuando se le pasa un detalle -aviso-nada:juego-cierra, aviso-sirvio:hora-dormir,
# pete:979-, y el detalle sale de lo que pasa ese dia: no se puede enumerar. La lista blanca de
# arriba intentaba enumerarlo y por eso crecia sola y se quedaba corta; con Nova encendida, cada
# aviso nuevo ponia el banco rojo SIN QUE EL CODIGO HUBIERA CAMBIADO. Lo que hay que exigir es que
# la RAIZ este declarada, que es lo que el fuente puede declarar.
function RaizClave([string]$k) { if ($k -match '^([^:]+):') { return $Matches[1] } ; return $k }
$huerfanas = @($conDatos.Keys | Where-Object {
    -not $literales.ContainsKey($_) -and -not $declaradas.ContainsKey($_) -and
    -not $literales.ContainsKey((RaizClave $_)) -and -not $declaradas.ContainsKey((RaizClave $_))
})
# EL VEREDICTO NO SALE DEL FICHERO DE PRODUCCION (28/09, tras la revision). Lo que hay hoy en
# memoria\estadisticas.json lo escribe Nova mientras vive, asi que juzgar por ahi es juzgar por el
# disco: con la consola encendida, cada aviso nuevo ponia esto rojo sin que el codigo hubiera
# cambiado, y al reves -si ese dia el fichero no traia una clave, la comprobacion pasaba por no
# tener nada que mirar, que es la manera 17-. El propio proyecto ya lo tiene documentado en
# probar-logro-anotado.ps1: 'un rojo que depende de lo que haya en disco hoy no dice nada del
# codigo; eso ya costo dos rojos falsos el 25/09'.
# LO QUE SI SE JUZGA es el codigo, y esta justo debajo: que el regex saque los literales bien.
# Lo del disco se ENSENA -que para eso sirve- pero en gris, y solo cuenta como fallo si se le
# apunta a un fichero fijo con NOVA_ESTADISTICAS, que es cuando el contenido si lo elige el banco.
if ($env:NOVA_ESTADISTICAS) {
    Comp 'A. toda clave con datos esta en el fuente (o declarada de otra via)' ($huerfanas.Count -eq 0) $(
        if ($huerfanas.Count) { "SIN DECLARAR: " + ($huerfanas -join ', ') } else { 'ninguna suelta' })
} elseif ($huerfanas.Count) {
    Write-Host ('  --   A. en el estadisticas.json de hoy hay ' + $huerfanas.Count + " clave(s) que el fuente no declara: " + (($huerfanas | Select-Object -First 6) -join ', ')) -ForegroundColor DarkGray
    Write-Host '       (no es un fallo: lo escribe Nova mientras vive. Para juzgarlo, NOVA_ESTADISTICAS a un fichero fijo)' -ForegroundColor DarkGray
} else {
    Write-Host '  ok   A. ninguna clave del estadisticas.json de hoy se queda sin declarar'
}
# y sobre texto de mentira, que el regex hace lo que debe
$fx = "Add-Estadistica 'pepe' ; Add-Estadistica ""juan"" ; Add-Estadistica `$modo `$text"
$km = @([regex]::Matches($fx, "Add-Estadistica\s+['""]([^'""]+)['""]")) | ForEach-Object { $_.Groups[1].Value }
Comp '   el regex coge comilla simple y doble, no la variable' (($km -contains 'pepe') -and ($km -contains 'juan') -and (-not ($km -contains '$modo'))) ''

# B. LA FECHA, con una sola pasada de git; y comprobada contra git log -S para arranque-oido
function Fecha-Claves([string[]]$claves) {
    $res = @{}
    $commit = ''; $fecha = ''
    $salida = & git -C $raiz log --reverse --format="#C#%h %ad" --date=format:"%Y-%m-%d %H:%M" -p --unified=0 -- assistant.ps1 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'no puedo fechar los contadores: git fallo' }
    foreach ($ln in $salida) {
        if ($ln.StartsWith('#C#')) { $p = $ln.Substring(3).Split(' ', 2); $commit = $p[0]; $fecha = $p[1]; continue }
        if ($ln.StartsWith('+') -and -not $ln.StartsWith('+++')) {
            foreach ($k in $claves) {
                if (-not $res.ContainsKey($k) -and $ln.Contains("'" + $k + "'")) { $res[$k] = @{ commit = $commit; fecha = $fecha } }
            }
        }
    }
    return $res
}
$hayGit = $false
try { $null = & git -C $raiz rev-parse --is-inside-work-tree 2>$null; $hayGit = ($LASTEXITCODE -eq 0) } catch { $hayGit = $false }
if (-not $hayGit) {
    # sin repo git no hay fecha y sin fecha no se puede acusar: NO se sale verde en silencio
    Comp 'hay repositorio git para fechar los contadores' $false 'sin git no se comprueba nada'
    Write-Host "  $mal MAL"; exit 1
}
$fechas = Fecha-Claves @($literales.Keys)
$fArr = $fechas['arranque-oido']
Comp 'B. arranque-oido nace en 3be3ac6 2026-09-24 02:20 (una pasada)' ($fArr -and $fArr.commit -eq '3be3ac6' -and $fArr.fecha -eq '2026-09-24 02:20') $(if ($fArr) { $fArr.commit + ' ' + $fArr.fecha })
$viaS = (& git -C $raiz log -S"Add-Estadistica 'arranque-oido'" --format='%h' -- assistant.ps1 2>$null | Select-Object -Last 1)
Comp '   y coincide con git log -S (las dos formas de fecharlo)' ($fArr -and ([string]$viaS).Trim() -eq $fArr.commit) "log -S: $viaS"

# C. EL LISTON, sobre fechas FIJAS (no Get-Date)
$MudoDias = 4
function Acusar([datetime]$nace, [datetime]$hoy) { return (($hoy - $nace).TotalDays -gt $script:MudoDias) }
$hoyFx = [datetime]'2026-09-26 18:00'
Comp 'C. una muda de 10 dias se acusa' (Acusar ([datetime]'2026-09-16 18:00') $hoyFx) ''
Comp '   una de 2 dias NO (nacio anteayer)' (-not (Acusar ([datetime]'2026-09-24 18:00') $hoyFx)) ''
Comp '   la de exactamente 4 dias NO' (-not (Acusar ([datetime]'2026-09-22 18:00') $hoyFx)) 'el liston es MAS de 4'
Comp '   la de 5 dias SI' (Acusar ([datetime]'2026-09-21 18:00') $hoyFx) ''

# D, E. LA EXCEPCION sale de config.json (motorOrdenes), no de una lista a mano
$motorO = 'worker'
try { $motorO = [string]([IO.File]::ReadAllText((Join-Path $raiz 'config.json')) | ConvertFrom-Json).input.motorOrdenes } catch {}
function Exenta([string]$clave, [string]$motor) { return (($clave -eq 'vozwin' -or $clave -eq 'vozwin-mudo') -and $motor -ne 'vozwin') }
Comp "D. con motorOrdenes '$motorO', vozwin no se acusa" ((Exenta 'vozwin' $motorO) -and (Exenta 'vozwin-mudo' $motorO)) ''
Comp '   con motorOrdenes vozwin, SI se acusaria (mismo detector, otro valor)' (-not (Exenta 'vozwin' 'vozwin')) ''
# E. la excepcion que miente: vozwin tiene que EXISTIR en el fuente y estar muda
Comp 'E. vozwin existe en el fuente (si no, quita la excepcion)' ($literales.ContainsKey('vozwin')) ''
Comp '   y sigue muda (si ya cuenta, quita la excepcion)' (-not $conDatos.ContainsKey('vozwin')) ''

# F. LOS ALMACENES: rutas memoria\ del fuente que no existen
$rutasMem = @{}
foreach ($m in [regex]::Matches($fuente, "Join-Path\s+\`$MemoriaDir\s+['""]([^'""]+)['""]")) { $rutasMem[$m.Groups[1].Value] = $true }
$noExisten = @($rutasMem.Keys | Where-Object { -not (Test-Path -LiteralPath (Join-Path $raiz (Join-Path 'memoria' $_))) })
Comp 'F. arranque-oido.json y guia-tiempos.json salen como almacenes vacios' (($noExisten -contains 'arranque-oido.json') -and ($noExisten -contains 'guia-tiempos.json')) "$($noExisten.Count) rutas sin crear"
Comp '   y estadisticas.json, que SI existe, no sale' (-not ($noExisten -contains 'estadisticas.json')) ''

# 7. LA LISTA REAL, con fecha, para que braya la lea (no falla si es larga: es informativa)
Write-Host ''
Write-Host '-- contadores mudos de mas de 4 dias (con su commit) --'
$hoy = Get-Date
$acusados = 0
foreach ($k in ($literales.Keys | Sort-Object)) {
    if ($conDatos.ContainsKey($k)) { continue }
    if (Exenta $k $motorO) { continue }
    $f = $fechas[$k]
    if (-not $f) { continue }
    $d = $null; try { $d = [datetime]::ParseExact($f.fecha, 'yyyy-MM-dd HH:mm', $null) } catch { continue }
    if (Acusar $d $hoy) { Write-Host ("  " + $k.PadRight(24) + " nace " + $f.fecha + "  " + $f.commit); $acusados++ }
}
Write-Host ("  ($acusados contadores mudos de mas de $MudoDias dias; los nuevos entran solos con el calendario)")

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host 'los instrumentos que no han medido nada estan contados'
exit 0
