# NOVA HABLABA POR SU CUENTA CASI TANTO COMO CUANDO LA LLAMAN (24/09, idea 4 de la tanda nueva).
#
# LA MEDICION, de memoria\estadisticas.json:
#
#     del 19 al 24/09:  69 avisos por su cuenta  contra  80 veces que braya la llamo
#     antes del 16/09:   0 avisos                contra 119
#
# Los avisos por su cuenta nacieron el 16/09 y en una semana pasaron de no existir a casi
# igualar lo que el pide. Cada uno por separado esta justificado -el propio codigo tiene
# escrito "hablar por todo es lo que cansa"-; el problema es la SUMA, y nadie la miraba: el
# tope que habia son 4 POR HORA, que en un dia despierto dan hasta 64.
#
# EL LISTON NO ES UN NUMERO NUEVO, es una proporcion: Nova no habla por su cuenta mas veces de
# las que le hablan. Y el suelo tampoco es nuevo: es el mismo $EntornoPorHora que ya estaba.
#
# LO QUE MAS SE VIGILA AQUI: que NO toque los dias buenos. Una regla que recorte avisos utiles
# seria peor que el problema, porque los avisos existen para decirle cosas que el no ha pedido
# pero necesita saber -que se queda sin disco, que el oido esta sordo-.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }
Invoke-Expression (Traer 'Test-CabeOtroAviso')
# EL SUELO SALE DEL ARCHIVO, NO DE AQUI. Escrito a mano, cambiar $EntornoPorHora en
# assistant.ps1 dejaba este banco verde probando otro numero: un banco que trae su copia de la
# constante no prueba la constante. Lo cazo el repaso del 24/09.
$mSuelo = [regex]::Match($fuente, '(?m)^\$EntornoPorHora = \[int\]\(Get-Cfg ''entorno'' ''porHora'' (\d+)\)')
if (-not $mSuelo.Success) { Write-Host '  MAL  no encuentro $EntornoPorHora'; exit 1 }
$suelo = [int]$mSuelo.Groups[1].Value
Comp 'el suelo sale del archivo' ($suelo -eq 4) "$suelo por hora"

Write-Host ''
Write-Host '-- 1. LOS TRECE DIAS REALES, uno a uno --'
# avisos y llamadas de cada dia, tal cual estan en memoria\estadisticas.json el 24/09.
$dias = @(
    @{ d = '11/09'; av = 0;  ac = 19 }, @{ d = '12/09'; av = 0;  ac = 69 },
    @{ d = '13/09'; av = 0;  ac = 3  }, @{ d = '15/09'; av = 0;  ac = 28 },
    @{ d = '16/09'; av = 6;  ac = 13 }, @{ d = '17/09'; av = 1;  ac = 0  },
    @{ d = '18/09'; av = 3;  ac = 27 }, @{ d = '19/09'; av = 7;  ac = 7  },
    @{ d = '20/09'; av = 9;  ac = 26 }, @{ d = '21/09'; av = 6;  ac = 27 },
    @{ d = '22/09'; av = 31; ac = 7  }, @{ d = '23/09'; av = 14; ac = 12 },
    @{ d = '24/09'; av = 2;  ac = 1  }
)
$totDichos = 0; $totReales = 0
# OJO CON LO QUE SE LE PASA (24/09, repaso): el codigo real pasa Get-CuentaHoy 'activacion',
# que son las llamadas de HASTA ESE MOMENTO, no las del dia entero. Simular con el total es
# mas optimista que la realidad, y eso hacia que la afirmacion de la seccion 2 no estuviera
# probada. Aqui se sigue usando el total en la tabla de arriba -que es la vista de conjunto- y
# el caso con el orden real va en la seccion 2b, con los datos del 23/09.
foreach ($x in $dias) {
    # se simula el dia entero: cada aviso pasa por la funcion con la cuenta que llevaba
    $salen = 0
    for ($i = 0; $i -lt $x.av; $i++) {
        if (Test-CabeOtroAviso $salen $x.ac $suelo 'medio') { $salen++ }
    }
    $totDichos += $salen; $totReales += $x.av
    $esperado = [Math]::Min($x.av, [Math]::Max($suelo, $x.ac))
    $nota = $(if ($salen -lt $x.av) { "corta $($x.av - $salen)" } else { 'no toca nada' })
    Comp ("$($x.d): $($x.av) avisos y $($x.ac) llamadas -> $salen") ($salen -eq $esperado) $nota
}
Comp 'en total se dicen 53 de los 79' ($totDichos -eq 53) "$totDichos de $totReales"
Comp 'y se cortan 26' (($totReales - $totDichos) -eq 26) "$($totReales - $totDichos)"

Write-Host ''
Write-Host '-- 2. y los recortes caen SOLO donde sobraban --'
# Esto es lo que decide si la regla vale: los dias buenos no se tocan. Si esta comprobacion se
# cayera, la regla estaria comiendose avisos utiles, que es peor que el problema que arregla.
$buenos = @('16/09', '18/09', '19/09', '20/09', '21/09', '24/09')
$tocados = @()
foreach ($x in $dias) {
    if ($x.d -notin $buenos) { continue }
    $salen = 0
    for ($i = 0; $i -lt $x.av; $i++) { if (Test-CabeOtroAviso $salen $x.ac $suelo 'medio') { $salen++ } }
    if ($salen -ne $x.av) { $tocados += $x.d }
}
Comp 'ningun dia bueno pierde un solo aviso' ($tocados.Count -eq 0) $(if ($tocados) { "toca: $($tocados -join ', ')" } else { 'los seis intactos' })
# y el 22/09, que es el dia de los 25 avisos identicos, se queda en 7
$s22 = 0; for ($i = 0; $i -lt 31; $i++) { if (Test-CabeOtroAviso $s22 7 $suelo 'medio') { $s22++ } }
Comp 'el 22/09 pasa de 31 avisos a 7' ($s22 -eq 7) "$s22"

Write-Host ''
Write-Host '-- 2b. EL 23/09 ENTERO, con las horas de verdad --'
# Aqui se prueba lo que la tabla de arriba no puede: que el ORDEN importa. El codigo real pasa
# las llamadas de HASTA ESE MOMENTO, no las del dia entero, y simular con el total es mas
# optimista que la realidad.
#
# Los trece avisos que SONARON el 23/09 con su hora, y las catorce activaciones reales de ese
# dia sacadas del registro. El dato que lo cambia todo: braya estuvo delante a las 00:28-00:30
# y NO volvio hasta las 21:08. Todo lo de en medio -de las 08:00 a las 20:41- sono a una
# habitacion vacia.
$avisos23 = @('00:26:58', '08:00:19', '08:00:33', '10:32:36', '10:32:51', '12:32:52',
              '14:33:14', '16:33:21', '20:00:57', '20:37:32', '20:41:58', '21:14:16', '21:36:32')
$llamadas23 = @('00:28:12', '00:28:13', '00:30:01', '00:30:16', '21:08:48', '21:09:28',
                '21:15:33', '21:17:22', '21:19:43', '21:21:20', '21:22:01', '22:12:24',
                '22:12:26', '22:38:23')
$dichos = 0; $cortados = @()
foreach ($h in $avisos23) {
    $llamadasHasta = @($llamadas23 | Where-Object { $_ -le $h }).Count
    if (Test-CabeOtroAviso $dichos $llamadasHasta $suelo 'medio') { $dichos++ } else { $cortados += $h }
}
Comp 'el 23/09 con el orden real: corta los de la casa vacia' ($cortados.Count -ge 1) "$dichos dichos, $($cortados.Count) cortados"
# Y LOS QUE CORTA SON LOS DE EN MEDIO, no los de cuando el estaba: eso es lo que hace que la
# regla valga. Si cortara los de las 21:xx -con braya delante- seria un fallo.
$conEl = @($cortados | Where-Object { $_ -ge '21:08:48' })
Comp 'y ninguno de los que sonaron con el delante' ($conEl.Count -eq 0) $(if ($conEl) { "corta: $($conEl -join ', ')" } else { 'los cortados son todos de la casa vacia' })
Comp 'y los primeros cuatro pasan igual, por el suelo' ($dichos -ge $suelo) "$dichos dichos"

Write-Host '-- 2c. y el caso duro: todos los avisos ANTES de la primera llamada --'
# Es el escenario que el repaso imaginaba. Aqui el freno SI corta, y debe hacerlo: si braya no
# ha aparecido, lo que Nova tenga que decir no lo esta oyendo nadie. Ademas esos avisos ni
# llegan aqui -Test-AvisoAplazable los aparca antes-, pero si llegaran, el suelo es la red.
$dichos2 = 0
for ($i = 0; $i -lt 10; $i++) { if (Test-CabeOtroAviso $dichos2 0 $suelo 'medio') { $dichos2++ } }
Comp 'con cero llamadas, pasan los del suelo y ni uno mas' ($dichos2 -eq $suelo) "$dichos2 de 10"
# y en cuanto braya aparece, se abre otra vez
$dichos3 = $dichos2
for ($i = 0; $i -lt 6; $i++) { if (Test-CabeOtroAviso $dichos3 8 $suelo 'medio') { $dichos3++ } }
Comp 'y en cuanto aparece, vuelven a caber' ($dichos3 -gt $dichos2) "de $dichos2 a $dichos3"

Write-Host ''
Write-Host '-- 3. lo importante pasa SIEMPRE --'
# Es la misma decision que ya tenia el tope por hora. Si esto se cayera, el aviso de que el
# microfono esta muerto se perderia justo el dia en que Nova esta hablando de mas.
Comp 'un aviso alto pasa con 500 avisos y 0 llamadas' (Test-CabeOtroAviso 500 0 $suelo 'alto') ''
Comp 'y uno medio, no' (-not (Test-CabeOtroAviso 500 0 $suelo 'medio')) ''
Comp 'ni uno bajo' (-not (Test-CabeOtroAviso 500 0 $suelo 'bajo')) ''
Comp 'ni uno de noche' (-not (Test-CabeOtroAviso 500 0 $suelo 'noche')) 'la hora de dormir tambien cuenta'

Write-Host ''
Write-Host '-- 4. el suelo, para que un dia callado no la deje muda --'
# Si la proporcion se mirara desde el primer aviso, un dia en que braya no ha dicho nada Nova
# no podria avisar ni de que se esta quedando sin disco.
Comp 'con 0 llamadas, los primeros 4 pasan' (Test-CabeOtroAviso 3 0 $suelo 'medio') ''
Comp 'y el quinto ya no' (-not (Test-CabeOtroAviso 4 0 $suelo 'medio')) ''
Comp 'con 10 llamadas, el quinto si' (Test-CabeOtroAviso 4 10 $suelo 'medio') ''
Comp 'y el undecimo no' (-not (Test-CabeOtroAviso 10 10 $suelo 'medio')) 'ni uno mas que las llamadas'
Comp 'el suelo sale de EntornoPorHora, no de un numero nuevo' ($fuente -match '\$EntornoPorHora = \[int\]\(Get-Cfg') ''

Write-Host ''
Write-Host '-- 5. LO QUE NO HACE --'
$tc = SinComentarios (Traer 'Test-CabeOtroAviso')
Comp 'no habla: decide y ya' (($tc -notmatch '\bSay\b') -and ($tc -notmatch 'Send-Aviso')) ''
Comp 'ni toca el estado' ($tc -notmatch '\$script:') 'pura, para que el banco le corra trece dias'
Comp 'ni mira el reloj por su cuenta' ($tc -notmatch 'Get-Date') 'todo por parametro'

Write-Host ''
Write-Host '-- 6. y el freno esta enganchado de verdad --'
$bloque = (($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
# Y QUE CUENTE LO QUE SUENA, NO TODO (24/09, repaso). 'aviso-entorno' se apunta tambien para
# los de nivel 'bajo', que solo se ven en la capsula: 22 de los 77 del registro. Contando esos,
# un 28 % del presupuesto se iba en cosas que no hablan, justo al reves de la regla.
Comp 'Test-PuedoAvisar lo usa' ($bloque -match 'Test-CabeOtroAviso \(Get-CuentaHoy ''aviso-dicho''\) \(Get-CuentaHoy ''activacion''\)') 'y cuenta lo DICHO, no lo mostrado'
Comp 'y el contador de lo dicho solo se apunta al hablar' (([regex]::Matches($bloque, "Add-Estadistica 'aviso-dicho'")).Count -eq 2) 'las dos ramas que llegan a la voz'
Comp 'y sigue existiendo el de todos, que mide otra cosa' ($bloque -match "Add-Estadistica 'aviso-entorno'") ''
Comp 'y con el suelo de siempre' ($bloque -match "Test-CabeOtroAviso[^\n]*\`$EntornoPorHora \`$nivel") ''
Comp 'y deja una linea cuando se calla' ($bloque -match "ENTORNO: hoy ya he hablado por mi cuenta") 'callarse sin decirlo es lo de siempre'
Comp 'y un contador para vigilarlo' ($bloque -match "Add-Estadistica 'aviso-de-mas'") ''
# EL TOPE POR HORA NO SE TOCA: son dos frenos distintos y el viejo sigue haciendo su trabajo.
Comp 'el tope por hora sigue en pie' ($bloque -match '\$script:entornoAvisos\.Count -ge \$EntornoPorHora') ''
$gc = SinComentarios (Traer 'Get-CuentaHoy')
Comp 'la cuenta sale de las estadisticas que ya se guardan' ($gc -match 'Get-Estadisticas') 'no hay fichero nuevo'
# Y SE EJECUTA, no se lee. Mirando solo el texto, cambiar el 'return 0' del dia sin datos por
# un 'return 999' dejaba este banco verde... y a Nova callada entera el primer dia del mes,
# porque con 999 avisos contados no cabe ni uno mas. Probado: pasaba.
Invoke-Expression (Traer 'Get-CuentaHoy')
$script:estFalsas = @{ dias = @{} }
function Get-Estadisticas { return $script:estFalsas }
$hoyD = Get-Date -Format 'yyyy-MM-dd'
Comp 'sin nada guardado de hoy, cuenta CERO' ((Get-CuentaHoy 'aviso-entorno') -eq 0) "$(Get-CuentaHoy 'aviso-entorno')"
$script:estFalsas.dias[$hoyD] = @{ 'activacion' = 12 }
Comp 'y una ruta que no esta hoy, tambien cero' ((Get-CuentaHoy 'aviso-entorno') -eq 0) "$(Get-CuentaHoy 'aviso-entorno')"
Comp 'pero la que si esta se lee bien' ((Get-CuentaHoy 'activacion') -eq 12) "$(Get-CuentaHoy 'activacion')"
$script:estFalsas.dias['2020-01-01'] = @{ 'aviso-entorno' = 400 }
Comp 'y lo de otros dias no cuenta' ((Get-CuentaHoy 'aviso-entorno') -eq 0) 'el presupuesto es de HOY'
function Get-Estadisticas { throw 'el fichero esta roto' }
Comp 'y con las estadisticas rotas, cero y no revienta' ((Get-CuentaHoy 'activacion') -eq 0) 'no deja a Nova muda por un json malo'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya no habla por su cuenta mas que cuando la llamas'
exit 0
