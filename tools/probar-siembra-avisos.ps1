# SEMBRAR LA ESPERA APRENDIDA DEL REGISTRO (27/09, idea 73 de las 121)
#
# EL MECANISMO del 25/09 esta bien: Nova mira si braya le habla en los cinco minutos siguientes a un
# aviso y, con ocho muestras, espacia los que no mueven nada. EL PROBLEMA es que los contadores
# nacieron ese dia: 12 muestras repartidas en 10 claves, ninguna llega a ocho, asi que
# Get-EsperaAviso devuelve siempre el numero escrito y la regla no hace NADA. Y los avisos utiles
# salen una o dos veces por semana, asi que un mes despues seguiria igual.
#
# EL REGISTRO YA LO SABE desde el 9 de septiembre: 101 lineas 'ENTORNO (clave, nivel)' con su hora
# (62 de nivel medio, 9 noche, 27 bajo y 3 alto) y la actividad de braya al lado.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que los de nivel 'bajo' NO cuenten: no suenan, solo se ven, y de un aviso que nunca sono no
#      se puede deducir si movio algo. Son 27 de las 101, 21 de ellas bateria-llena.
#   2. que los de nivel 'alto' tampoco: Test-PuedoAvisar ni llama a Get-EsperaAviso para ellos.
#   3. que un aviso con otro pegado a menos de cinco minutos se descarte: no se sabe a cual contesto.
#   4. que NO se siembre dos veces, que doblaria todas las cuentas.
#   5. que la fecha de cada muestra sea la del AVISO y no la de hoy.
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('Seed-ReaccionesAviso', 'Get-ReaccionesAviso', 'Get-EsperaAviso')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$SeedVentanaMs = 300000
$RE_SEED_ACTIVIDAD = '(?:\[escucha\] ACTIVADO|DICTADO \(|ORDEN ESCRITA|TOQUE CORTO)'
$AvisoReaccionMin = 8
$AvisoEsperaTope = 6
Comp 'la ventana es la misma de la regla en vivo (5 min)' ($txt -match '\$SeedVentanaMs = 300000') ''

# los dobles, DESPUES de cargar
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
$script:stats = $null
function Get-Estadisticas { return $script:stats }
$script:apuntados = @()
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) {
    $script:apuntados += @(@{ ruta = $ruta; detalle = $detalle })
    $dia = Get-Date -Format 'yyyy-MM-dd'
    if (-not $script:stats.dias.ContainsKey($dia)) { $script:stats.dias[$dia] = @{} }
    if (-not $script:stats.dias[$dia].ContainsKey($ruta)) { $script:stats.dias[$dia][$ruta] = 0 }
    $script:stats.dias[$dia][$ruta]++
}

$LogDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-siembra-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$UTF8 = New-Object Text.UTF8Encoding($false)
function EscribirLog([string[]]$lineas) {
    [IO.File]::WriteAllLines((Join-Path $LogDir 'assistant.log'), [string[]]$lineas, $UTF8)
}
function Reset {
    $script:stats = @{ dias = @{}; descartes = @(); recientes = @(); decisiones = @() }
    $script:logs = @()
    $script:apuntados = @()
}
function Cuenta([string]$clave, [string]$tipo) {
    $n = 0
    foreach ($d in @($script:stats.dias.Keys)) {
        if ($script:stats.dias[$d].ContainsKey("aviso-$tipo`:$clave")) { $n += [int]$script:stats.dias[$d]["aviso-$tipo`:$clave"] }
    }
    return $n
}

try {
    Write-Host ''
    Write-Host '-- 1. LO BASICO: reacciono o no reacciono --'
    Reset
    EscribirLog @(
        '2026-09-10 10:00:00  ENTORNO (disco-poco, medio): Te quedan 10 gigas.',
        '2026-09-10 10:01:00  DICTADO (nombre ''nova'')',
        '2026-09-10 12:00:00  ENTORNO (disco-poco, medio): Te quedan 9 gigas.',
        '2026-09-10 12:30:00  DICTADO (nombre ''nova'')')
    $r1 = Seed-ReaccionesAviso
    Comp '1a. siembra' $r1 (@($script:logs) -join ' | ')
    Comp '1b. el aviso con dictado al minuto cuenta como que sirvio' ((Cuenta 'disco-poco' 'sirvio') -eq 1) ([string](Cuenta 'disco-poco' 'sirvio'))
    Comp '1c. y el que tuvo la respuesta a los 30 min, como que no' ((Cuenta 'disco-poco' 'nada') -eq 1) ([string](Cuenta 'disco-poco' 'nada'))
    Comp '1d. la fecha es la del AVISO, no la de hoy' ($script:stats.dias.ContainsKey('2026-09-10')) (@($script:stats.dias.Keys) -join ', ')

    Write-Host ''
    Write-Host '-- 2. LOS QUE NO SUENAN NO CUENTAN (el filtro que faltaba) --'
    Reset
    EscribirLog @(
        '2026-09-11 10:00:00  ENTORNO (bateria-llena, bajo): Ya esta cargada del todo.',
        '2026-09-11 12:00:00  ENTORNO (bateria-llena, bajo): Ya esta cargada del todo.',
        '2026-09-11 14:00:00  ENTORNO (oido-mudo, alto): No te oigo.',
        '2026-09-11 16:00:00  ENTORNO (hora-dormir, noche): Es tarde.')
    $null = Seed-ReaccionesAviso
    Comp '2a. los de nivel bajo quedan fuera' (((Cuenta 'bateria-llena' 'sirvio') + (Cuenta 'bateria-llena' 'nada')) -eq 0) 'nunca sonaron: su "no reacciono" no mide nada'
    Comp '2b. los de nivel alto tambien' (((Cuenta 'oido-mudo' 'sirvio') + (Cuenta 'oido-mudo' 'nada')) -eq 0) 'Test-PuedoAvisar ni les pregunta la espera'
    Comp '2c. pero los de noche SI cuentan' (((Cuenta 'hora-dormir' 'sirvio') + (Cuenta 'hora-dormir' 'nada')) -eq 1) 'esos suenan'
    Comp '2d. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'fuera por nivel' }).Count -eq 1) (@($script:logs) -join ' | ')

    Write-Host ''
    Write-Host '-- 3. DOS AVISOS PEGADOS: NO SE SABE A CUAL CONTESTO --'
    Reset
    EscribirLog @(
        '2026-09-12 10:00:00  ENTORNO (gmail-lleno, medio): Tienes el correo lleno.',
        '2026-09-12 10:02:00  ENTORNO (disco-poco, medio): Te quedan 9 gigas.',
        '2026-09-12 10:03:00  DICTADO (nombre ''nova'')',
        '2026-09-12 20:00:00  ENTORNO (gmail-lleno, medio): Tienes el correo lleno.')
    $null = Seed-ReaccionesAviso
    Comp '3a. los dos pegados no se cuentan' (((Cuenta 'disco-poco' 'sirvio') + (Cuenta 'disco-poco' 'nada')) -eq 0) 'el mismo criterio que avisoMirar, que solo vigila uno'
    Comp '3b. y el suelto de la noche si' (((Cuenta 'gmail-lleno' 'sirvio') + (Cuenta 'gmail-lleno' 'nada')) -eq 1) ([string](Cuenta 'gmail-lleno' 'nada') + ' sin reaccion')

    Write-Host ''
    Write-Host '-- 4. NO SE SIEMBRA DOS VECES --'
    Reset
    EscribirLog @(
        '2026-09-13 10:00:00  ENTORNO (disco-poco, medio): Te quedan 10 gigas.',
        '2026-09-13 10:01:00  DICTADO (nombre ''nova'')')
    $null = Seed-ReaccionesAviso
    $antes4 = (Cuenta 'disco-poco' 'sirvio') + (Cuenta 'disco-poco' 'nada')
    $r4 = Seed-ReaccionesAviso
    $desp4 = (Cuenta 'disco-poco' 'sirvio') + (Cuenta 'disco-poco' 'nada')
    Comp '4a. la segunda vez no hace nada' (-not $r4) ''
    Comp '4b. y las cuentas no se doblan' ($antes4 -eq $desp4) ([string]$antes4 + ' -> ' + [string]$desp4)
    Comp '4c. la marca queda en las estadisticas, no en tmp' (@($script:apuntados | Where-Object { $_.ruta -eq 'siembra-reacciones' }).Count -eq 1) 'tmp se limpia; esto no'

    Write-Host ''
    Write-Host '-- 5. Y LA REGLA, QUE ERA EL PUNTO DE TODO ESTO --'
    # con 8 muestras y menos del 10 % de reaccion, la espera se multiplica por 4
    Reset
    $lineas5 = @()
    foreach ($h in 1..9) {
        $lineas5 += ('2026-09-1{0} 10:00:00  ENTORNO (oido-ruido, medio): Hay ruido.' -f ($h % 10))
    }
    EscribirLog $lineas5
    $null = Seed-ReaccionesAviso
    $n5 = (Cuenta 'oido-ruido' 'sirvio') + (Cuenta 'oido-ruido' 'nada')
    Comp '5a. nueve avisos sueltos se siembran' ($n5 -eq 9) ([string]$n5 + ' muestras')
    Comp '5b. ninguno movio nada' ((Cuenta 'oido-ruido' 'sirvio') -eq 0) ''
    $espera = Get-EsperaAviso 'oido-ruido' 30
    Comp '5c. y AHORA la espera de 30 min se multiplica por 4' ($espera -eq 120) ([string]$espera + ' min')
    $esperaOtra = Get-EsperaAviso 'una-que-no-se-sembro' 30
    Comp '5d. una clave sin datos sigue con su numero escrito' ($esperaOtra -eq 30) ([string]$esperaOtra + ' min')

    Write-Host ''
    Write-Host '-- 6. SIN REGISTRO NO PASA NADA --'
    Reset
    Remove-Item -LiteralPath (Join-Path $LogDir 'assistant.log') -Force -ErrorAction SilentlyContinue
    $r6 = Seed-ReaccionesAviso
    Comp '6a. sin ficheros de log, no siembra ni se rompe' (-not $r6) ''
    Comp '6b. y no deja marca (asi lo intenta cuando haya registro)' (@($script:apuntados).Count -eq 0) ''
} finally {
    Remove-Item -LiteralPath $LogDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7a. se llama al arrancar, tras Initialize-Escucha' ($sinCom -match '(?s)Initialize-Escucha\s*\r?\n\s*try \{ \[void\]\(Seed-ReaccionesAviso\)') ''
Comp '7b. y NO desde el bucle' (@([regex]::Matches($sinCom, 'Seed-ReaccionesAviso')).Count -eq 2) 'definicion + una sola llamada'
Comp '7c. lee el registro con ReadLines, no entero en RAM' ((Traer 'Seed-ReaccionesAviso') -match '\[System\.IO\.File\]::ReadLines') '6 MB entre los dos ficheros'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la espera aprendida arranca con lo que ya sabia el registro' -ForegroundColor Green
exit 0
