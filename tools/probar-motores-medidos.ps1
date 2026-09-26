# LO QUE YA ESTA EN EL REGISTRO Y NADIE MIRABA (26/09, idea 19 de las 121).
#
# EL AGUJERO: Python apunta en registro.jsonl TODO repaso que hace, con su motor y el texto que
# saco -480 lineas: base 328, small 94, canary 30, turbo 23, omni 3-. El asistente no abria ese
# fichero mas que para borrarlo. Y mientras tanto el caso 5 de la revision propia -el que decide
# si un escalon de la cascada merece la pena- no podia decidir NADA, porque sus contadores
# propios llevan cinco filas de un solo dia y DecisionMinIntentos son 20.
#
# LO QUE MAS VIGILA ESTE BANCO, en orden:
#   1. Que "sirvio" se decida con Test-FastCommand, LA MISMA regla que el contador vivo. Dos
#      definiciones distintas metidas en el mismo umbral son un banco verde mintiendo.
#   2. Que no se juzgue con veredictos a medias: lo que falta por juzgar son las lineas MAS
#      NUEVAS, asi que una cuenta parcial esta sesgada hacia atras, y con ella se apagaria un
#      motor por un dato que no es.
#   3. Que el ultimo escalon de la cascada no se toque JAMAS.
#   4. Que el bucle no se bloquee: un texto por vuelta y solo con Nova parada. Medido el 26/09:
#      Test-FastCommand tarda 70 ms de media y hasta 300 ms, asi que los treinta de canary de
#      una tacada serian dos segundos con el bucle quieto.
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

# --- el mundo de mentira: NUNCA pruebas\audio\uso de verdad ---
$base = Join-Path ([IO.Path]::GetTempPath()) ('motores-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$LogDir = $base
$MemoriaDir = $base
$MotoresVeredictosJson = Join-Path $base 'motores-veredictos.json'
function Log([string]$m) { }
function Write-Atomico([string]$r, [string]$c) { [IO.File]::WriteAllText($r, $c, (New-Object Text.UTF8Encoding($false))) }
$script:motoresVeredictos = $null
$script:motoresLineas = $null
$script:motoresSello = ''
foreach ($fn in @('Get-MotoresLineas', 'Get-MotoresVeredictos', 'Step-MotorVeredicto',
        'Get-MotoresMedidos', 'Get-MotoresRepartidos', 'Test-DiaCuenta', 'Get-DecisionMinimo')) {
    Invoke-Expression (Traer $fn)
}
$mD = [regex]::Match($fuente, '(?m)^\$DecisionDatosDesde = .*$')
$DecisionDatosDesde = '2026-09-20'
$mMI = [regex]::Match($fuente, '(?m)^\$DecisionMinIntentos = (\d+)')
$DecisionMinIntentos = if ($mMI.Success) { [int]$mMI.Groups[1].Value } else { 20 }
$mAp = [regex]::Match($fuente, '(?m)^\$DecisionAprovecha = ([0-9.]+)')
$DecisionAprovecha = if ($mAp.Success) { [double]$mAp.Groups[1].Value } else { 0.15 }

# Test-FastCommand de mentira, con interruptor: es la pieza cuyo papel hay que demostrar.
$script:diceQueSi = { param($t) return ((ConvertTo-Plain2 $t) -eq 'abre steam') }
function ConvertTo-Plain2([string]$s) { return ([string]$s).ToLower().Trim() }
function Test-FastCommand([string]$text) { return [bool](& $script:diceQueSi $text) }

function NuevoUso([string]$sub) {
    $d = Join-Path $base ("uso-" + $sub)
    $null = New-Item -ItemType Directory -Path (Join-Path $d 'pruebas\audio\uso') -Force
    return $d
}
function PonLineas([string]$dirUso, $filas) {
    $r = Join-Path $dirUso 'pruebas\audio\uso\registro.jsonl'
    $ls = foreach ($f in $filas) {
        '{"id": "' + $f.id + '", "motor": "' + $f.motor + '", "texto": "' + $f.texto + '", "segundos": 1.0}'
    }
    [IO.File]::WriteAllLines($r, [string[]]@($ls), (New-Object Text.UTF8Encoding($false)))
    return (Join-Path $dirUso 'pruebas\audio\uso')
}
function Limpia { $script:motoresVeredictos = $null; $script:motoresLineas = $null; $script:motoresSello = ''
    if (Test-Path -LiteralPath $MotoresVeredictosJson) { Remove-Item -LiteralPath $MotoresVeredictosJson -Force } }
# JUZGARLO TODO ANTES DE MIRAR EL REPARTO, y hace falta decir por que: Get-MotoresMedidos NO
# cuenta las lineas sin veredicto -para eso esta el "completo"-, asi que sin esto el mapa de
# dias sale VACIO y Get-MotoresRepartidos devuelve $false por no tener nada que repartir, no
# por el freno. Los dos casos de abajo habrian pasado por la razon equivocada.
function JuzgaTodo {
    $q = 99; $v = 0
    while ($q -gt 0 -and $v -lt 400) { $q = Step-MotorVeredicto; $v++ }
    return $v
}

try {
    Write-Host '-- 1. las lineas de repaso, sacadas del registro --'
    Limpia
    $u1 = NuevoUso 'a'
    $dir1 = PonLineas $u1 @(
        @{ id = '20260921-234036'; motor = 'canary'; texto = 'abre steam' },
        @{ id = '20260922-101010'; motor = 'canary'; texto = 'que los cierres' },
        @{ id = '20260923-111111'; motor = 'canary'; texto = '' },
        @{ id = '20260923-121212'; motor = 'base'; texto = 'abre steam' },
        # EL MISMO AUDIO, REPASADO POR DOS MOTORES: la cascada es canary -> base, asi que esto
        # pasa siempre que canary no saca nada. Lo destapo una rotura a proposito que salio
        # verde: sin el motor en la clave, el veredicto del primero tapa al del segundo y uno
        # de los dos no se cuenta nunca.
        @{ id = '20260923-111111'; motor = 'base'; texto = 'abre steam' })
    $LogDir = $u1      # Step-MotorVeredicto lee por el $LogDir de siempre
    $L = Get-MotoresLineas $dir1
    Comp 'se leen todas las lineas con motor' (@($L).Count -eq 5) "$(@($L).Count)"
    $c1 = @($L | Where-Object { $_.motor -eq 'canary' })
    Comp '  con su motor' ($c1.Count -eq 3) "$($c1.Count) de canary"
    Comp '  y su dia, sacado del id' (@($L | Where-Object { $_.dia -eq '2026-09-21' }).Count -eq 1) 'yyyyMMdd-HHmmss'
    # UN TEXTO VACIO NO ES UN ERROR: canary devolvio la nada seis veces de treinta, y eso cuenta
    # como uso y no como acierto, que es justo lo que hay que medir.
    Comp '  y el texto vacio se queda, no se tira' (@($L | Where-Object { $_.texto -eq '' }).Count -eq 1) 'seis de treinta volvieron vacias'
    # LA CLAVE LLEVA EL MOTOR: dos motores pueden repasar el MISMO audio, y llevan el mismo id.
    Comp '  y la clave distingue motores del mismo audio' (@($L | ForEach-Object { $_.id } | Select-Object -Unique).Count -eq 5) 'dos motores repasan el mismo audio y llevan el mismo id'

    Write-Host ''
    Write-Host '-- 2. SIRVIO SE DECIDE CON Test-FastCommand, no con otra cosa --'
    # ESTA ES LA COMPROBACION QUE EVITA LA MENTIRA QUE MAS DUELE: si "sirvio" se calculara de
    # otra forma -texto igual al entregado, por ejemplo- el numero diria una cosa y el freno
    # que lo usa estaria medido con otra.
    $quedan = 99
    $vueltas = 0
    while ($quedan -gt 0 -and $vueltas -lt 20) { $quedan = Step-MotorVeredicto; $vueltas++ }
    Comp 'se juzgan todas en varias vueltas' ($quedan -eq 0) "$vueltas vueltas para 5 lineas"
    # UNA POR VUELTA, Y ESA ES LA REGLA 4: con cuatro lineas hacen falta cuatro vueltas.
    Comp '  de UNA en UNA, no todas de golpe' ($vueltas -eq 5) "$vueltas vueltas, 5 lineas"
    $med = Get-MotoresMedidos
    Comp 'canary sale con sus tres usos' ($med.ContainsKey('canary') -and (($med['canary'].dias.Values | ForEach-Object { $_.usos }) | Measure-Object -Sum).Sum -eq 3) ''
    $sirv = (($med['canary'].dias.Values | ForEach-Object { $_.sirvio }) | Measure-Object -Sum).Sum
    Comp '  y UN solo acierto, el que Test-FastCommand reconoce' ($sirv -eq 1) "$sirv de 3"
    # CON UN Test-FastCommand QUE DIGA SIEMPRE QUE NO, cero aciertos. Si "sirvio" se calculara
    # comparando textos, este caso seguiria dando mas de cero.
    Limpia
    $script:diceQueSi = { param($t) return $false }
    $quedan = 99; $vueltas = 0
    while ($quedan -gt 0 -and $vueltas -lt 20) { $quedan = Step-MotorVeredicto; $vueltas++ }
    $med = Get-MotoresMedidos
    $sirv = (($med['canary'].dias.Values | ForEach-Object { $_.sirvio }) | Measure-Object -Sum).Sum
    Comp 'si nada se reconoce, cero aciertos' ($sirv -eq 0) 'y no "los textos que coinciden"'
    $script:diceQueSi = { param($t) return ((ConvertTo-Plain2 $t) -eq 'abre steam') }

    Write-Host ''
    Write-Host '-- 3. CON VEREDICTOS A MEDIAS NO SE DECIDE NADA --'
    # Lo que falta por juzgar son siempre las lineas MAS NUEVAS, asi que la cuenta parcial no
    # es una muestra al azar: esta sesgada hacia atras. Apagar un motor con eso seria decidir
    # con un dato que no es.
    Limpia
    $null = Step-MotorVeredicto      # solo una de las cuatro
    $med = Get-MotoresMedidos
    Comp 'con una sola juzgada, canary NO esta completo' (-not $med['canary'].completo) 'lo que falta son las mas nuevas'
    $quedan = 99; $vueltas = 0
    while ($quedan -gt 0 -and $vueltas -lt 20) { $quedan = Step-MotorVeredicto; $vueltas++ }
    $med = Get-MotoresMedidos
    Comp '  y con todas, si' ($med['canary'].completo) ''

    Write-Host ''
    Write-Host '-- 3 bis. EL VEREDICTO SE GUARDA EN DISCO, o no sirve de nada --'
    # LO DESTAPO UNA ROTURA A PROPOSITO QUE SALIO VERDE: quitando la escritura, dentro de una
    # misma sesion no cambia NADA -la tabla en memoria es la misma-, asi que ningun caso lo
    # veia. Pero Nova arranca 235 veces en catorce dias: sin disco, cada arranque volveria a
    # juzgar las cuatrocientas ochenta lineas desde cero, una cada tres segundos, y "completo"
    # tardaria veinticuatro minutos CADA VEZ. La cinta existe justo para eso.
    Comp 'el fichero de veredictos se escribe' (Test-Path -LiteralPath $MotoresVeredictosJson) ''
    # SE OLVIDA LO QUE HAY EN MEMORIA, como en un arranque nuevo, y tiene que salir lo mismo.
    $script:motoresVeredictos = $null
    $medTrasReinicio = Get-MotoresMedidos
    Comp '  y al arrancar de nuevo, se recuerda' ($medTrasReinicio['canary'].completo) 'sin disco habria que juzgarlo todo otra vez'
    $sirvR = (($medTrasReinicio['canary'].dias.Values | ForEach-Object { $_.sirvio }) | Measure-Object -Sum).Sum
    Comp '  con los mismos veredictos' ($sirvR -eq 1) 'el unico que Test-FastCommand reconoce'

    Write-Host ''
    Write-Host '-- 4. el sello: si el fichero crece, se vuelve a leer --'
    $r1 = Join-Path $dir1 'registro.jsonl'
    Add-Content -LiteralPath $r1 -Value '{"id": "20260924-090909", "motor": "canary", "texto": "abre steam", "segundos": 1.0}' -Encoding UTF8
    $L2 = Get-MotoresLineas $dir1
    Comp 'una linea nueva se ve' (@($L2).Count -eq 6) "$(@($L2).Count)"
    Comp '  y queda por juzgar' ((Step-MotorVeredicto) -eq 0) 'se juzga esa y no quedan mas'

    Write-Host ''
    Write-Host '-- 5. el reparto en dias, con el mismo freno de siempre --'
    $ahora = [datetime]'2026-09-26'
    Limpia
    $u2 = NuevoUso 'b'
    # 19 de 20 el mismo dia: el freno tiene que pararlo (0,95 > 0,70)
    $filas = @()
    for ($i = 0; $i -lt 19; $i++) { $filas += @{ id = ('20260925-0000' + ('{0:D2}' -f $i)); motor = 'canary'; texto = 'nada' } }
    $filas += @{ id = '20260924-000001'; motor = 'canary'; texto = 'nada' }
    $dir2 = PonLineas $u2 $filas
    $LogDir = $u2
    $script:motoresLineas = $null; $script:motoresSello = ''
    $null = Get-MotoresLineas $dir2
    $null = JuzgaTodo
    $med2 = Get-MotoresMedidos
    Comp 'con 19 de 20 en un solo dia, NO se decide' (-not (Get-MotoresRepartidos $med2 'canary' $ahora)) '0,95 pasa del 0,70'
    # El reparto real de canary: 3/6/1/19/1 en cinco dias -> peor dia 19/30 = 0,633
    Limpia
    $u3 = NuevoUso 'c'
    $filas = @()
    foreach ($par in @(@('20260921', 3), @('20260922', 6), @('20260923', 1), @('20260925', 19), @('20260926', 1))) {
        for ($i = 0; $i -lt $par[1]; $i++) { $filas += @{ id = ($par[0] + '-0000' + ('{0:D2}' -f $i)); motor = 'canary'; texto = 'nada' } }
    }
    $dir3 = PonLineas $u3 $filas
    $LogDir = $u3
    $script:motoresLineas = $null; $script:motoresSello = ''
    $null = Get-MotoresLineas $dir3
    $null = JuzgaTodo
    $med3 = Get-MotoresMedidos
    Comp 'con el reparto real de canary, SI se puede' (Get-MotoresRepartidos $med3 'canary' $ahora) '19 de 30 en el peor dia = 0,63'
    # EL CORTE DE DIAS: lo de antes del arreglo no cuenta.
    Limpia
    $u4 = NuevoUso 'd'
    $filas = @()
    foreach ($par in @(@('20260918', 10), @('20260919', 10), @('20260921', 2))) {
        for ($i = 0; $i -lt $par[1]; $i++) { $filas += @{ id = ($par[0] + '-0000' + ('{0:D2}' -f $i)); motor = 'canary'; texto = 'nada' } }
    }
    $dir4 = PonLineas $u4 $filas
    $LogDir = $u4
    $script:motoresLineas = $null; $script:motoresSello = ''
    $null = Get-MotoresLineas $dir4
    $null = JuzgaTodo
    $med4 = Get-MotoresMedidos
    Comp 'lo de antes del corte no cuenta' (-not (Get-MotoresRepartidos $med4 'canary' $ahora)) "nada anterior a $DecisionDatosDesde"

    Write-Host ''
    Write-Host '-- 6. y sin fichero, no se inventa nada --'
    Limpia
    $script:motoresLineas = $null; $script:motoresSello = ''
    Comp 'sin registro.jsonl, la lista vacia' (@(Get-MotoresLineas (Join-Path $base 'no-existe')).Count -eq 0) ''
    Comp '  y el mapa vacio, no $null' ($null -ne (Get-MotoresMedidos)) 'un $null reventaria al hacer ContainsKey'
    Comp '  y no se reparte nada' (-not (Get-MotoresRepartidos @{} 'canary' $ahora)) ''
} finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '-- 7. EL CASO 5 LO USA, y solo cuando puede --'
$iC5 = $sinCom.IndexOf('$medC = @{}')
Comp 'el caso 5 pide los numeros del registro' ($iC5 -ge 0) ''
$iFinC = $sinCom.IndexOf('if ($NubeOir -and -not $script:autoDecision)')
$blC = if ($iC5 -ge 0 -and $iFinC -gt $iC5) { $sinCom.Substring($iC5, $iFinC - $iC5) } else { '' }
Comp '  y el bloque se encuentra entero, hasta el caso de al lado' ($blC -ne '') ''
# SOLO SI LAS CUENTAS PROPIAS NO LLEGAN: el registro es el suelo mientras no haya cuentas, no
# su sustituto. Los denominadores no son el mismo y sumarlos seria inventarse una poblacion.
Comp '  solo si sus propias cuentas no llegan' ($blC -match '\$intC -lt \$DecisionMinIntentos -and \$medC\.ContainsKey') ''
Comp '  y solo si ese motor esta juzgado entero' ($blC -match '\$medC\[\$mtC\]\.completo') 'con veredictos a medias, la cuenta esta sesgada'
Comp '  y solo si el registro da MAS usos' ($blC -match '\$usosR -gt \$intC') 'nunca para bajar el denominador'
# EL FRENO DEL REPARTO SIGUE, pero el que toca en cada caso.
Comp 'el freno del reparto sigue delante' ($blC -match 'Get-MotoresRepartidos \$medC \$mtC') ''
Comp '  y con las cuentas propias, el de siempre' ($blC -match 'Test-DatosRepartidos \$stR "repaso:\$mtC"') 'el viejo no se sustituye'
Comp 'los tres frenos de siempre no se tocan' (
    $blC -match 'Get-DecisionMinimo \$intC' -and $blC -match 'Test-DecisionSolida \$okC \$intC') ''
# EL ULTIMO ESCALON, JAMAS.
Comp 'el ultimo escalon de la cascada no se toca' ($sinCom -match '\$quedaC\.Count -lt 1') 'ese es el que saca las ordenes de verdad'
Comp '  y el bucle se para en Count-1' ($sinCom -match 'Select-Object -First \(\[Math\]::Max\(0, \$RepasoCascada\.Count - 1\)\)') ''
# Y SE DICE DE DONDE SALE EL NUMERO: si Nova decide con un dato, tiene que poder decir cual.
# DE DONDE SALE EL NUMERO, DICHO EN LOS TRES SITIOS: el log, la estadistica y lo que le dice a
# braya. Si Nova decide con un dato, tiene que poder decir cual.
Comp 'y dice si decidio con el registro o con sus cuentas' ($blC -match '\$fuenteC = if \(\$deRegC\)') ''
Comp '  en el registro' ($blC -match 'Log "REVISION PROPIA: quito \$mtC[^"]*\$fuenteC') ''
Comp '  en la estadistica' ($blC -match 'Add-Estadistica .auto-ajuste.[^;]{0,90}fuenteC') ''
Comp '  y en lo que te dice' ($blC -match 'mirando mis grabaciones') ''

Write-Host ''
Write-Host '-- 8. REGLA 4: el bucle no se para a juzgar --'
$iT = $sinCom.IndexOf('$script:motoresQuedan = Step-MotorVeredicto')
Comp 'el bucle juzga de uno en uno' ($iT -ge 0) ''
$blT = if ($iT -ge 0) { $sinCom.Substring([Math]::Max(0, $iT - 400), [Math]::Min(400, $iT)) } else { '' }
# LAS MISMAS GUARDAS QUE EL AVISO DE JUEGOS COLGADOS: con Nova ocupada, ni un milisegundo.
Comp '  y solo con Nova parada' (
    $blT -match '-not \$script:busy' -and $blT -match '-not \$script:armed' -and $blT -match '-not \$script:pendiente') 'las mismas de los juegos colgados'
Comp '  y no mas de una vez cada tres segundos' ($blT -match 'motoresCheck\) -ge 3000') ''
# Y NADIE MAS LO LLAMA DESDE EL CAMINO EN CALIENTE.
Comp 'nadie mas juzga por su cuenta' (@([regex]::Matches($sinCom, 'Step-MotorVeredicto')).Count -eq 2) 'la definicion y el tick'

Write-Host ''
Write-Host '-- 9. contra el registro de verdad --'
$nC = 0
$reg = Join-Path $raiz 'pruebas\audio\uso\registro.jsonl'
if (Test-Path -LiteralPath $reg) {
    foreach ($l in [IO.File]::ReadAllLines($reg)) { if ($l -match '"motor"\s*:\s*"canary"') { $nC++ } }
}
Write-Host ("       canary aparece $nC veces en registro.jsonl; en estadisticas.json son cinco, de un solo dia")
Comp 'el registro tiene mas de lo que decian las cuentas' ($nC -ge 20) 'por eso hacia falta esto'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el registro sirve para juzgar la cascada'
exit 0
