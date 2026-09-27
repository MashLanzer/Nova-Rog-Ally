# PERDER EL PRIMER PLANO NO ES CERRAR EL JUEGO (27/09, idea 108 de las 121)
#
# EL DATO: de las 45 salidas emparejadas de los dos registros, VEINTINUEVE (el 64 %) duran menos de
# dos minutos y VEINTE menos de treinta segundos. Las mas cortas: 4, 6, 8, 8, 9, 9, 10, 10, 10, 10,
# 10, 11, 11, 11, 14, 15, 15, 20, 20 y 21 segundos.
#
# EL 25/09 ENTRE LAS 21 Y LAS 23, siete ciclos completos con ELDEN RING y ELDEN RING NIGHTREIGN de
# 20, 10, 21, 9, 10, 11 y 8 segundos: el brillo subio y bajo SIETE veces y la escucha se apago y
# encendio SIETE veces en 75 minutos.
#
# Y LA CONTRADICCION DENTRO DE NOVA, que es la prueba de que la partida se rompe:
# memoria\juegos.json dice ELDEN RING NIGHTREIGN = 75 SEGUNDOS el 2026-09-25, mientras
# memoria\uso-ally.json dice que el proceso 'nightreign' estuvo 4.038 SEGUNDOS en primer plano ese
# mismo dia. Cincuenta y cuatro veces mas.
#
# LO QUE NO SIRVE DE GUARDA: Test-JuegoVivo. En los siete casos el proceso SI habia muerto un
# instante, asi que con esa condicion el parpadeo seguiria igual. La guarda es de TIEMPO.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la ventana salga de las reapariciones MEDIDAS de ESE juego, no de un numero escrito
#   2. que sin datos de un juego, todo se comporte EXACTAMENTE como hoy
#   3. que la ventana se pregunte ANTES que el proceso (si no, el parpadeo sigue)
#   4. que al volver, el tramo se SUME en vez de reiniciarse
#   5. y que la palabra de activacion se aplace igual que el brillo
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
Invoke-Expression (Traer 'Get-VentanaVuelta')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$mT = [regex]::Match($txt, '(?m)^\$JuegoVueltaTope = (\d+)')
$mM = [regex]::Match($txt, '(?m)^\$JuegoVueltaMax = (\d+)')
Comp 'el tope de la ventana sale del archivo' $mT.Success ($mT.Groups[1].Value + ' ms')
Comp 'y cuantas reapariciones se recuerdan' $mM.Success ($mM.Groups[1].Value)
$JuegoVueltaTope = if ($mT.Success) { [int]$mT.Groups[1].Value } else { 300000 }
$JuegoVueltaMax = if ($mM.Success) { [int]$mM.Groups[1].Value } else { 12 }

Write-Host ''
Write-Host '-- 1. LA VENTANA SALE DE LAS REAPARICIONES MEDIDAS --'
Comp '1a. sin datos, ventana CERO' ((Get-VentanaVuelta @() $JuegoVueltaTope) -eq 0) 'y entonces todo se comporta como hoy'
Comp '1b. con ceros y basura, tambien' ((Get-VentanaVuelta @(0, -5, 0) $JuegoVueltaTope) -eq 0) ''
# las siete reapariciones REALES del 25/09, en ms
$reales = @(20000, 10000, 21000, 9000, 10000, 11000, 8000)
$v = Get-VentanaVuelta $reales $JuegoVueltaTope
Comp '1c. con las siete del 25/09, 31,5 s' ($v -eq 31500) ([string]$v + ' ms: el maximo (21 s) mas la mitad')
Comp '1d. y cubre las SIETE' ((@($reales | Where-Object { $_ -ge $v }).Count) -eq 0) 'ninguna reaparicion se le escapa'
Comp '1e. el maximo y no un percentil' ((Get-VentanaVuelta @(1000, 1000, 1000, 21000) $JuegoVueltaTope) -eq 31500) 'equivocarse por abajo es lo caro: parpadea'
Comp '1f. y no se pasa del tope' ((Get-VentanaVuelta @(600000) $JuegoVueltaTope) -eq $JuegoVueltaTope) ([string]$JuegoVueltaTope + ' ms')
Comp '1g. una sola medida ya vale' ((Get-VentanaVuelta @(8000) $JuegoVueltaTope) -eq 12000) '8 s + la mitad'

Write-Host ''
Write-Host '-- 2. EL CICLO DEL 25/09, PASO A PASO --'
# se reconstruye la secuencia: sale, vuelve en 10 s, sale, vuelve en 21 s...
$ventana = Get-VentanaVuelta $reales $JuegoVueltaTope
$parpadeos = 0
foreach ($ms in $reales) {
    # con la ventana puesta, ¿se habria tocado el brillo en esa salida?
    if ($ms -ge $ventana) { $parpadeos++ }
}
Comp '2a. con la ventana medida, CERO parpadeos' ($parpadeos -eq 0) 'antes fueron siete en 75 minutos'
# y una salida de verdad SI pasa
Comp '2b. pero una salida de verdad si se confirma' ((120000) -ge $ventana) 'dos minutos fuera ya no es un alt-tab'
Comp '2c. y el tope evita esperas absurdas' ($ventana -le $JuegoVueltaTope) ([string]$ventana + ' <= ' + [string]$JuegoVueltaTope)

Write-Host ''
Write-Host '-- 3. EL ORDEN IMPORTA: LA VENTANA ANTES QUE EL PROCESO --'
$ts = Traer 'Test-SalidaJuego'
$iVen = $ts.IndexOf('$s.ventana')
$iVivo = $ts.IndexOf('Test-JuegoVivo $s')
Comp '3a. la ventana se pregunta primero' ($iVen -ge 0 -and $iVen -lt $iVivo) 'en los siete casos el proceso SI habia muerto un instante'
Comp '3b. y mientras no venza, no se decide nada' ($ts -match 'if \(\$s\.ventana -and \(\$sw\.ElapsedMilliseconds - \[double\]\$s\.desdeMs\) -lt \[double\]\$s\.ventana\) \{ return \}') ''

Write-Host ''
Write-Host '-- 4. AL VOLVER, EL TRAMO SE SUMA (la partida de 75 s) --'
Comp '4a. se apunta cuanto tardo en volver' ($ts -match 'Add-VueltaJuego \$s\.nombre \$msVuelta') 'de ahi sale la ventana de la proxima vez'
Comp '4b. y NO se ponen a cero los contadores' (-not ($ts -match '(?s)volvio en.{0,600}\$script:juegoSesionSeg = 0')) 'eso es lo que partia la partida en trozos de once segundos'
Comp '4c. se dice que no era una salida' ($ts -match 'no era una salida') ''
Comp '4d. y que el brillo no se toco' ($ts -match 'el brillo no se toco') ''

Write-Host ''
Write-Host '-- 5. EL BRILLO SE APLAZA, Y SE HACE AL CONFIRMAR --'
$ej = Traer 'Exit-Juego'
Comp '5a. Exit-Juego ya no toca el brillo si hay ventana' ($ej -match '(?s)if \(\$ventana -gt 0 -and \$script:juegoSalida\) \{.{0,400}return') ''
Comp '5b. lo guarda en la salida en duda' ($ej -match '\$script:juegoSalida\.brillo = \[int\]\$script:juegoBrilloAntes') ''
Comp '5c. con su ventana' ($ej -match '\$script:juegoSalida\.ventana = \$ventana') ''
Comp '5d. y lo dice' ($ej -match 'espero .* s antes de tocar el brillo') ''
Comp '5e. SIN ventana, se restaura como hoy' ($ej -match '(?s)\$ventana -gt 0 -and \$script:juegoSalida.{0,500}Set-Brillo \(\[int\]\$script:juegoBrilloAntes\)') 'sin datos de ese juego nada cambia'
Comp '5f. y al confirmar la salida, vuelve' ($ts -match 'Set-Brillo \(\[int\]\$s\.brillo\)') ''
Comp '5g. diciendo que fue tras la espera' ($ts -match 'tras la espera') ''

Write-Host ''
Write-Host '-- 6. Y LA PALABRA DE ACTIVACION, IGUAL --'
Comp '6a. no se borra la marca si hay espera' ($sinCom -match '\$esperaJ = \(\$dudaJ -and \$dudaJ\.ventana -and') ''
Comp '6b. mirando la misma ventana' ($sinCom -match '(?s)\$esperaJ = .{0,200}\[double\]\$dudaJ\.ventana') 'una sola idea de cuanto se espera'
Comp '6c. y la linea del registro solo sale al cambiar' ($sinCom -match 'if \(\$SoloBotonEnJuego -and \$script:soloBotonPuesto\)') 'si no, se repetiria en cada vuelta del bucle'
Comp '6d. con su bandera' ($txt -match '\$script:soloBotonPuesto = \$false') ''

Write-Host ''
Write-Host '-- 7. LAS REAPARICIONES SE GUARDAN DONDE YA HAY SITIO --'
$av = Traer 'Add-VueltaJuego'
Comp '7a. en juegos.json, sin fichero nuevo' ($av -match 'Get-JuegosMem') "ahi ya viven 'ritmoBateria' y 'muestrasBateria'"
Comp '7b. con tope por juego' ($av -match 'while \(\$l\.Count -gt \$JuegoVueltaMax\)') ([string]$JuegoVueltaMax)
Comp '7c. y no se apunta una espera absurda' ($av -match '\$ms -gt \$JuegoVueltaTope') 'volver dos horas despues no es un alt-tab'
Comp '7d. ni una de cero' ($av -match '\$ms -le 0') ''

Write-Host ''
Write-Host '-- 8. Y CONTRA LOS DATOS DE VERDAD --'
$jm = Join-Path $Raiz 'memoria\juegos.json'
$ua = Join-Path $Raiz 'memoria\uso-ally.json'
if ((Test-Path -LiteralPath $jm) -and (Test-Path -LiteralPath $ua)) {
    $j1 = Get-Content -LiteralPath $jm -Raw -Encoding UTF8 | ConvertFrom-Json
    $u1 = Get-Content -LiteralPath $ua -Raw -Encoding UTF8 | ConvertFrom-Json
    $seg = 0
    if ($j1.'ELDEN RING NIGHTREIGN' -and $j1.'ELDEN RING NIGHTREIGN'.dias.'2026-09-25') { $seg = [int]$j1.'ELDEN RING NIGHTREIGN'.dias.'2026-09-25' }
    $proc = 0
    if ($u1.'2026-09-25' -and $u1.'2026-09-25'.nightreign) { $proc = [int]$u1.'2026-09-25'.nightreign.con }
    Comp '8a. juegos.json dice 75 s de NIGHTREIGN el 25/09' ($seg -eq 75) ([string]$seg + ' s')
    Comp '8b. y uso-ally dice 4.038 del proceso' ($proc -eq 4038) ([string]$proc + ' s')
    Comp '8c. o sea 54 veces mas' ($proc -gt ($seg * 50)) ([string][Math]::Round($proc / [double][Math]::Max(1, $seg), 0) + ' veces')
} else {
    Write-Host '  --   faltan los ficheros de memoria, se salta'
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'un alt-tab ya no apaga el brillo ni parte la partida' -ForegroundColor Green
exit 0
