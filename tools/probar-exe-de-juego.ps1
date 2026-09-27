# APRENDER SOLA CON QUE PROGRAMA SE ABRE CADA JUEGO (26/09, idea 26 de las 121).
#
# EL CASO, con numeros exactos: el 25/09 braya jugo 4.038 segundos seguidos a ELDEN RING
# NIGHTREIGN -una hora y siete minutos- y Nova apunto SETENTA Y CINCO. El 1,86 %: se perdio el
# 98,14 % de la partida. Y no es solo la cuenta de horas: en esa hora, con el microfono abierto
# porque "no habia juego", hay 45 lineas de llamadas descartadas en el registro.
#
# POR QUE: la lista de ejecutables de juego esta escrita a mano y tiene CUATRO entradas. Todo lo
# que no arranque desde una carpeta reconocible y no este en esas cuatro es invisible.
#
# COMO SE APRENDE: Steam sella LastPlayed en el appmanifest de lo que se acaba de jugar. Si un
# proceso lleva mucho rato delante sin que Nova lo reconozca y en esa ventana se movio
# EXACTAMENTE UN appmanifest, ese es el juego. Comprobado con el caso real: el LastPlayed de
# nightreign cayo a las 23:53:48, dentro de la ventana, y ningun otro se movio.
#
# LO QUE ESTE BANCO VIGILA MAS QUE NADA: que con DOS candidatos no se aprenda nada. Equivocarse
# aqui hace que Nova cierre el microfono creyendo que braya esta jugando, y eso lo deja sin voz.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$fuente = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
            $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}

Write-Host '-- 1. los dos numeros, y de donde salen --'
foreach ($c in @('ExesJuegoMax', 'ExesJuegoMinSeg')) {
    $m = [regex]::Match($fuente, ('(?m)^\$' + $c + '\s*=\s*([0-9]+)'))
    Comp ("se saca del archivo " + $c) $m.Success ''
    if ($m.Success) { Set-Variable -Name $c -Value ([int]$m.Groups[1].Value) }
}
# EL LISTON CAE EN EL HUECO VACIO: el no-juego con mas tiempo delante en un DIA ENTERO es
# explorer con 350 s; el caso bueno mas corto son 2.351 s. Entre 350 y 2.351 no hay nada.
Comp 'los minutos delante dejan fuera a explorer' ($ExesJuegoMinSeg -gt 350) (
    "$ExesJuegoMinSeg s; explorer junta 350 en TODO un dia, no seguidos")
Comp '  y dejan pasar una partida de verdad' ($ExesJuegoMinSeg -lt 2351) (
    'la mas corta medida son 2.351 s; nightreign fueron 4.038')
# LOS 300 QUE PEDIA LA IDEA NO VALEN: explorer ya pasa de 300 en un dia y quedaria a tiro.
Comp '  y no son los 300 de la idea' ($ExesJuegoMinSeg -ge 600) 'con 300, explorer queda a tiro'
# EL TOPE SE COPIA DEL CUADERNO DE LA ALLY, no se inventa.
$mU = [regex]::Match($fuente, '(?m)^\$UsoAllyMax\s*=\s*([0-9]+)')
Comp 'el tope es el mismo que el del cuaderno de la Ally' ($mU.Success -and $ExesJuegoMax -eq [int]$mU.Groups[1].Value) (
    "$ExesJuegoMax; en dos dias de cuaderno han salido nueve procesos distintos")

Write-Host ''
Write-Host '-- 2. EL CASAMIENTO, ejecutado: uno solo o ninguno --'
Invoke-Expression (Traer 'Find-JuegoPorUltimoJugado')
function Seg([string]$f) { return [long]([DateTimeOffset]::new([datetime]$f).ToUnixTimeSeconds()) }
$desde = [datetime]'2026-09-25 22:45:22'
$hasta = [datetime]'2026-09-25 23:53:00'
# EL CASO REAL, con la hora exacta del appmanifest: 2622380 sello a las 23:53:48.
$script:Juegos = @(
    @{ nombre = 'ELDEN RING NIGHTREIGN'; ultimo = (Seg '2026-09-25 23:53:48') },
    @{ nombre = 'A Way Out'; ultimo = (Seg '2026-09-25 00:01:15') },
    @{ nombre = 'Unravel Two'; ultimo = (Seg '2026-09-25 11:03:26') },
    @{ nombre = 'The Past Within'; ultimo = (Seg '2026-09-25 12:40:22') })
$antes = @{ 'ELDEN RING NIGHTREIGN' = (Seg '2026-09-24 10:00:00'); 'A Way Out' = (Seg '2026-09-25 00:01:15')
    'Unravel Two' = (Seg '2026-09-25 11:03:26'); 'The Past Within' = (Seg '2026-09-25 12:40:22') }
Comp 'el caso real de nightreign sale bien' ((Find-JuegoPorUltimoJugado $desde $hasta $antes) -eq 'ELDEN RING NIGHTREIGN') (
    'LastPlayed 23:53:48, dentro de la ventana; ningun otro se movio')
# CON DOS, NADA. Esta es la comprobacion que impide el destrozo.
$antes2 = @{ 'ELDEN RING NIGHTREIGN' = (Seg '2026-09-24 10:00:00'); 'A Way Out' = (Seg '2026-09-24 09:00:00')
    'Unravel Two' = (Seg '2026-09-25 11:03:26'); 'The Past Within' = (Seg '2026-09-25 12:40:22') }
$script:Juegos[1].ultimo = (Seg '2026-09-25 23:40:00')
Comp 'con DOS que se movieron, NO se aprende nada' ((Find-JuegoPorUltimoJugado $desde $hasta $antes2) -eq '') (
    'adivinar entre dos dejaria a braya sin microfono')
$script:Juegos[1].ultimo = (Seg '2026-09-25 00:01:15')
# CON NINGUNO, TAMPOCO
$todosIguales = @{ 'ELDEN RING NIGHTREIGN' = (Seg '2026-09-25 23:53:48'); 'A Way Out' = (Seg '2026-09-25 00:01:15')
    'Unravel Two' = (Seg '2026-09-25 11:03:26'); 'The Past Within' = (Seg '2026-09-25 12:40:22') }
Comp 'si ninguno se movio, tampoco' ((Find-JuegoPorUltimoJugado $desde $hasta $todosIguales) -eq '') (
    'un sello de ayer no dice nada de ahora')
# Y FUERA DE LA VENTANA, NO CUENTA
$fuera = @{ 'ELDEN RING NIGHTREIGN' = (Seg '2026-09-24 10:00:00'); 'A Way Out' = (Seg '2026-09-25 00:01:15')
    'Unravel Two' = (Seg '2026-09-25 11:03:26'); 'The Past Within' = (Seg '2026-09-25 12:40:22') }
Comp 'un sello de fuera de la ventana no cuenta' (
    (Find-JuegoPorUltimoJugado ([datetime]'2026-09-25 08:00:00') ([datetime]'2026-09-25 09:00:00') $fuera) -eq '') (
    'solo nightreign se movio, pero a las 23:53: fuera de la ventana')
# LA HOLGURA: el +120 s es el mismo tope que ya usan Add-TiempoJuego y Add-UsoAlly.
Comp 'y la holgura es de dos minutos por detras' (
    (Find-JuegoPorUltimoJugado ([datetime]'2026-09-25 22:45:22') ([datetime]'2026-09-25 23:52:00') $antes) -eq 'ELDEN RING NIGHTREIGN') (
    'Steam sella un poco despues de salir')

Write-Host ''
Write-Host '-- 3. la tabla: se lee, se guarda y se olvida --'
$tmpD = Join-Path ([IO.Path]::GetTempPath()) ('exes-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmpD -Force
$ExesJuegoPath = Join-Path $tmpD 'juegos-exes.json'
$script:exesJuego = $null
$script:invitado = $false
function Log([string]$m) { $script:dichoE += $m }
$script:dichoE = @()
function Save-Corrupto($a, $b) { }
function Write-Atomico([string]$r, [string]$c) { [IO.File]::WriteAllText($r, $c, (New-Object Text.UTF8Encoding($false))) }
foreach ($fn in @('Get-ExesJuego', 'Save-ExeJuego', 'Remove-ExeJuego')) { Invoke-Expression (Traer $fn) }
try {
    Comp 'sin fichero, la tabla esta vacia' ((Get-ExesJuego).Count -eq 0) ''
    Comp 'se aprende uno' ([bool](Save-ExeJuego 'nightreign' 'ELDEN RING NIGHTREIGN')) ''
    $script:exesJuego = $null
    Comp '  y se recuerda tras reiniciar' ((Get-ExesJuego)['nightreign'].juego -eq 'ELDEN RING NIGHTREIGN') (
        'se olvida lo de la RAM y se relee del disco')
    Comp '  y queda dicho en el log' ((($script:dichoE -join ' ') -match 'EXE DE JUEGO')) ''
    [void](Save-ExeJuego 'nightreign' 'ELDEN RING NIGHTREIGN')
    Comp '  y la segunda vez suma, no duplica' ((Get-ExesJuego).Count -eq 1 -and (Get-ExesJuego)['nightreign'].veces -eq 2) ''
    # EN MINUSCULAS SIEMPRE: el nombre del proceso llega como Windows quiera.
    [void](Save-ExeJuego 'SpiderMan' 'Marvel Spider-Man')
    $crudoE = [IO.File]::ReadAllText($ExesJuegoPath)
    Comp 'la clave se ESCRIBE en minusculas' ($crudoE -cmatch '"spiderman"' -and $crudoE -cnotmatch '"SpiderMan"') (
        'una hashtable de PowerShell no distingue mayusculas: hay que mirar el fichero')
    # SE PUEDE DESHACER, que es la regla 2 de la casa.
    Comp 'y se puede olvidar' ([bool](Remove-ExeJuego 'SpiderMan')) ''
    Comp '  y se va de verdad' (-not (Get-ExesJuego).ContainsKey('spiderman')) ''
    Comp '  y olvidar lo que no esta no revienta' ((Remove-ExeJuego 'no-existe') -eq $false) ''
    # LO QUE HAGA OTRO NO SE APRENDE
    $script:invitado = $true
    Comp 'con un invitado delante, no se aprende nada' ((Save-ExeJuego 'loquesea' 'Un Juego') -eq $false) ''
    $script:invitado = $false
    # EL TOPE
    for ($i = 0; $i -lt ($ExesJuegoMax + 5); $i++) { [void](Save-ExeJuego ("proc$i") "Juego $i") }
    Comp 'la tabla no crece sin fin' ((Get-ExesJuego).Count -le $ExesJuegoMax) (
        "$((Get-ExesJuego).Count) de tope $ExesJuegoMax")
} finally { Remove-Item -LiteralPath $tmpD -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '-- 4. el enganche: lo escrito a mano manda, y los filtros siguen --'
$cuerpoJ = Traer 'Get-JuegoEnPrimerPlano'
$iMano = $cuerpoJ.IndexOf('$EXES_JUEGO.ContainsKey($nomP)')
$iApr = $cuerpoJ.IndexOf('$aprE.ContainsKey($nomP)')
Comp 'la funcion consulta la tabla aprendida' ($iApr -ge 0) ''
Comp '  pero DESPUES de la lista escrita a mano' ($iMano -ge 0 -and $iApr -gt $iMano) 'lo escrito a mano manda'
# Y LO APRENDIDO PASA POR LOS MISMOS FILTROS: no se salta ninguno.
$iRet = $cuerpoJ.IndexOf('if (-not $carpeta) { return $null }')
Comp '  y delante de los filtros de siempre' ($iRet -gt $iApr) ''
foreach ($f in @('CARPETA_NO_JUEGO', '_CommonRedist', 'Get-NombreJuegoLimpio', 'Find-Juego')) {
    Comp ("  el filtro de $f sigue detras") ($cuerpoJ.IndexOf($f) -gt $iApr) ''
}
# LA LISTA A MANO NO SE VACIA "porque ya se aprende sola": es lo que funciona sin Steam.
$mEJ = [regex]::Match($fuente, '(?ms)^\$EXES_JUEGO = @\{.*?\}\r?\n')
Comp 'la lista escrita a mano sigue entera' ($mEJ.Success -and @([regex]::Matches($mEJ.Value, "'[a-z0-9-]+' =")).Count -ge 4) ''

Write-Host ''
Write-Host '-- 5. el candidato no cuesta ni una consulta nueva --'
$iC = $sinCom.IndexOf('$script:exeSinJuego = [string]$appU')
Comp 'el tic de 10 s lleva la cuenta' ($iC -ge 0) ''
$blC = if ($iC -ge 0) { $sinCom.Substring([Math]::Max(0, $iC - 700), [Math]::Min(900, $sinCom.Length - [Math]::Max(0, $iC - 700))) } else { '' }
# REGLA 5: se reusa el $appU que la linea de arriba ya tiene en la mano.
Comp '  reusando el proceso que ya se leyo' ($blC -match 'Add-UsoAlly \$appU') 'cero consultas nuevas al sistema'
Comp '  y si es un juego conocido, no hay nada que aprender' ($blC -match 'if \(\$j -or -not \$appU\)') ''
Comp '  y si cambia el proceso, la cuenta empieza de nuevo' ($blC -match '-ne \[string\]\$script:exeSinJuego') ''

Write-Host ''
Write-Host '-- 6. y el aprendizaje: sin avisos y con sus guardas --'
$iA = $sinCom.IndexOf('$cualE = Find-JuegoPorUltimoJugado')
Comp 'el aprendizaje existe' ($iA -ge 0) ''
# EL FIN ES SU PROPIO catch, no un vecino lejano: entre este bloque y Get-AvisoHoraDormir la
# idea 27 (cambio de horario) metio un Send-AvisoEntorno legitimo, y usar el vecino como fin
# metia ese aviso en la ventana y ponia roja la comprobacion de "no interrumpe" con el codigo bien.
$iFinA = $sinCom.IndexOf("exes de juego:", [Math]::Max(0, $iA))
$iIniA = $sinCom.LastIndexOf('if ($script:exeSinJuego -and', [Math]::Max(0, $iA))
$blA = if ($iIniA -ge 0 -and $iFinA -gt $iIniA) { $sinCom.Substring($iIniA, $iFinA - $iIniA) } else { '' }
Comp '  y se lee entero' ($blA -ne '') ''
Comp '  exige los minutos delante' ($blA -match '\$ExesJuegoMinSeg \* 1000') ''
Comp '  y no aprende lo que ya sabe' ($blA -match '-not \$tbE\.ContainsKey\(\$procE\) -and -not \$EXES_JUEGO\.ContainsKey\(\$procE\)') ''
Comp '  ni con un invitado delante' ($blA -match '-not \$script:invitado') ''
# ESTO NO INTERRUMPE: ni una palabra hablada, ni un popup.
Comp '  y NO interrumpe' ($blA -notmatch 'Send-AvisoEntorno' -and $blA -notmatch 'Say ' -and $blA -notmatch 'Show-Popup') (
    'solo una linea en el log y una entrada en la tabla')
# EL CANDIDATO SE GASTA PASE LO QUE PASE: si no, se reintentaria en cada vuelta.
$iBorra = $blA.IndexOf('$script:exeSinJuego = ' + [char]39 + [char]39)
$iSi = $blA.IndexOf('if ($cualE)')
Comp '  y el candidato se gasta aunque no se aprenda' ($iBorra -gt $iSi -and $iSi -ge 0) (
    'fuera del if: si no, un proceso que Steam no aclara se reintentaria cada vuelta')
Comp '  y cuando Steam no lo aclara, lo dice' ($blA -match 'Steam no lo aclara') ''

Write-Host ''
Write-Host '-- 7. el fichero esta ignorado a mano --'
# Si no, Test-MemoriaIgnorada se lo anade sola al arrancar y ademas gasta un aviso hablado.
$gi = [IO.File]::ReadAllText((Join-Path $raiz '.gitignore'))
Comp 'memoria/juegos-exes.json esta en .gitignore' ($gi -match 'memoria/juegos-exes\.json') (
    'si no, Nova se lo anade sola y gasta un aviso en decirlo')

Write-Host ''
Write-Host '-- 8. contra el cuaderno de verdad --'
$seg = 0
$ua = Join-Path $raiz 'memoria\uso-ally.json'
if (Test-Path -LiteralPath $ua) {
    try {
        $j = Get-Content -LiteralPath $ua -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($d in $j.PSObject.Properties) {
            foreach ($a in $d.Value.PSObject.Properties) {
                if ([int]$a.Value.con -gt $seg) { $seg = [int]$a.Value.con }
            }
        }
    } catch {}
}
Write-Host ("       lo mas visto en un dia en el cuaderno de la Ally: $seg s")
Comp 'hay partidas largas de las que aprender' ($seg -ge $ExesJuegoMinSeg) "$seg s, y el liston son $ExesJuegoMinSeg"

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova aprende sola con que programa se abre cada juego'
exit 0
