# EL PULSO DEL BUCLE, QUE NADIE HABIA MEDIDO (27/09, idea 72 de las 121)
#
# EL DATO: el bucle duerme 30 ms por vuelta y en 31.000 lineas no habia NI UNA medicion de lo que
# tarda de verdad una vuelta -ElapsedMilliseconds sale 350 veces y ninguna cronometra el pulso-.
# Mientras tanto el bucle SI se bloquea, y esta medido a mano en los comentarios: Say deja el
# microfono mudo 3,6 s en el saludo, recorrer los ~200 procesos cuesta de 500 a 740 ms, y la zona de
# ejecucion de ordenes que Process-Texto alcanza desde el bucle tiene 29 Start-Sleep que suman
# 8.050 ms. Hay un comentario que cuenta "47 vueltas del bucle" SUPONIENDO el periodo. Mientras una
# vuelta dura, Nova no te oye.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el medidor NO abra un fichero por vuelta (la regla 4 de la casa; la ficha pedia justo eso)
#   2. que no escriba una linea por vuelta mala: como mucho una por minuto
#   3. que con pocas vueltas NO diga nada (el liston es su propio p99, no un numero)
#   4. que la linea diga HACIENDO QUE se quedo sorda
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
foreach ($f in @('Get-PercentilLista', 'Get-VueltaP99', 'Add-VueltaMedida', 'Get-VueltaPeor')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
# los cuatro numeros, del archivo
$VueltasMemoria = 2000
$VueltasMin = 200
$VueltaPercentil = 99
$VueltaAvisoMs = 60000
Comp 'la memoria de vueltas es 2000' ($txt -match '\$VueltasMemoria = 2000') '~60 s a 30 ms'
Comp 'el minimo para opinar son 200' ($txt -match '\$VueltasMin = 200') ''
Comp 'el liston es su p99' ($txt -match '\$VueltaPercentil = 99') ''
Comp 'y el freno de la linea, un minuto' ($txt -match '\$VueltaAvisoMs = 60000') ''
# LAS DOS DEL NIVEL SE SACAN DEL FICHERO, no se copian (28/09): son las que deciden el liston, y un
# banco con su propia copia prueba su numero y no el de Nova. Si alli cambian, aqui cambia solo.
$mSueno = [regex]::Match($txt, '(?m)^\$BucleSuenoMs = (\d+)')
$mFactor = [regex]::Match($txt, '(?m)^\$VueltaNivelFactor = (\d+)')
Comp 'el sueno del bucle sale del archivo' $mSueno.Success ($(if ($mSueno.Success) { $mSueno.Groups[1].Value + ' ms' } else { 'no esta' }))
Comp 'y el factor del nivel tambien' $mFactor.Success ($(if ($mFactor.Success) { 'x' + $mFactor.Groups[1].Value } else { 'no esta' }))
$BucleSuenoMs = if ($mSueno.Success) { [int]$mSueno.Groups[1].Value } else { 30 }
$VueltaNivelFactor = if ($mFactor.Success) { [int]$mFactor.Groups[1].Value } else { 3 }
# y que el bucle duerma ESA constante y no un numero suelto
Comp 'el bucle duerme esa constante' ($txt -match 'Start-Sleep -Milliseconds \$BucleSuenoMs') 'no un 30 escrito a mano'

# los dobles, DESPUES de cargar las funciones de verdad
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
$script:aDisco = @()
function Add-TrabajoTiempo([string]$clave, [int]$ms) { $script:aDisco += @(@{ clave = $clave; ms = $ms }); return $true }
$script:msFalsos = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:vueltas = New-Object System.Collections.ArrayList
    $script:vueltaPeor = 0
    $script:vueltaPeorQue = ''
    $script:vueltaAvisoEn = -100000
    $script:vueltaVolcadoEn = 0
    $script:vueltaPeorMinuto = 0
    $script:ultimoLog = ''
    $script:logs = @()
    $script:aDisco = @()
    $script:msFalsos = 0
}

Write-Host ''
Write-Host '-- 1. CON POCAS VUELTAS NO SE OPINA --'
Reset
for ($i = 0; $i -lt 50; $i++) { Add-VueltaMedida 31 }
Comp '1a. con 50 vueltas el p99 es 0 (no lo se)' ((Get-VueltaP99) -eq 0) ([string](Get-VueltaP99))
Add-VueltaMedida 5000
Comp '1b. y una vuelta de 5 s no escribe nada todavia' (@($script:logs | Where-Object { $_ -match 'SORDA' }).Count -eq 0) 'sin liston no hay nada que superar'
Comp '1c. pero SI se guarda como la peor' ((Get-VueltaPeor).ms -eq 5000) ([string](Get-VueltaPeor).ms + ' ms')

Write-Host ''
Write-Host '-- 2. CON VUELTAS DE SOBRA, EL LISTON ES SU PROPIO p99 --'
Reset
for ($i = 0; $i -lt 300; $i++) { Add-VueltaMedida 31 }
$p99 = Get-VueltaP99
Comp '2a. con 300 vueltas normales, el p99 son ~31 ms' ($p99 -ge 30 -and $p99 -le 35) ([string]$p99 + ' ms')
$script:logs = @()
$script:ultimoLog = 'STEAM: abriendo Hollow Knight'
$script:msFalsos = 120000
Add-VueltaMedida 1400
$sordas = @($script:logs | Where-Object { $_ -match '^SORDA' })
Comp '2b. una vuelta de 1,4 s se escribe' ($sordas.Count -eq 1) (@($sordas) -join ' | ')
Comp '2c. y dice HACIENDO QUE' ($sordas.Count -eq 1 -and $sordas[0] -match 'Hollow Knight') 'para eso se guarda lo ultimo que apunto'
Comp '2d. con los dos numeros: lo que tardo y lo normal' ($sordas.Count -eq 1 -and $sordas[0] -match '1[.,]4 s' -and $sordas[0] -match [string]$p99) $sordas[0]

Write-Host ''
Write-Host '-- 3. UNA LINEA POR MINUTO COMO MUCHO --'
# sin el freno, un tramo lento escribiria cien lineas iguales y el registro no valdria para nada
$script:logs = @()
for ($i = 0; $i -lt 100; $i++) { $script:msFalsos = 120000 + $i * 30; Add-VueltaMedida 1400 }
Comp '3a. cien vueltas malas seguidas: ni una linea mas' (@($script:logs | Where-Object { $_ -match '^SORDA' }).Count -eq 0) 'la del caso 2 se acaba de gastar el minuto'
# Y OJO CON LO QUE ESTO ENSENA: tras cien vueltas de 1,4 s, el p99 de la sesion YA es 1,4 s, asi
# que otra igual no es noticia. Es lo correcto -el liston es lo normal EN ELLA, no un numero- y hay
# que pasarse de ese liston nuevo para que vuelva a hablar.
$script:msFalsos = 200000
Add-VueltaMedida 1400
Comp '3b. otra de 1,4 s ya no es noticia: ese es su p99 ahora' (@($script:logs | Where-Object { $_ -match '^SORDA' }).Count -eq 0) 'el liston sube con ella'
Add-VueltaMedida 4000
Comp '3c. pero una de 4 s si, pasado el minuto' (@($script:logs | Where-Object { $_ -match '^SORDA' }).Count -eq 1) ''

Write-Host ''
Write-Host '-- 4. NI UN FICHERO POR VUELTA (la regla 4 de la casa) --'
# La ficha de la idea proponia Add-TrabajoTiempo en cada vuelta: 33 escrituras por segundo del JSON
# entero. Aqui las vueltas viven en RAM y baja UNA muestra por minuto.
Reset
$script:msFalsos = 0
for ($i = 0; $i -lt 500; $i++) { $script:msFalsos = $i * 30; Add-VueltaMedida 31 }
Comp '4a. 500 vueltas en 15 s: ninguna escritura' (@($script:aDisco).Count -eq 0) ([string]@($script:aDisco).Count + ' escrituras')
$script:msFalsos = 61000
Add-VueltaMedida 900
# LA CUENTA ES POR CLAVE DESDE EL 28/09: al minuto se guardan DOS cosas distintas y cada una tiene
# su almacen, el peor de la vuelta ('vuelta') y la mediana ('vuelta-mediana'). Lo que este caso
# vigila -que no se escriba mas de una vez por minuto- sigue igual, pero mirando la suya.
$peores = @($script:aDisco | Where-Object { $_.clave -eq 'vuelta' })
$medianas = @($script:aDisco | Where-Object { $_.clave -eq 'vuelta-mediana' })
Comp '4b. pasado el minuto, UNA sola' ($peores.Count -eq 1) ([string]$peores.Count)
# el peor del minuto que se cierra, incluida la vuelta que lo cierra: los 900 ms de esta, no los
# 31 de las quinientas normales. Guardar la mediana seria guardar los 30 ms de dormir, que ya se saben.
Comp '4c. y lo que se guarda es el PEOR del minuto' ($peores[0].ms -eq 900) ([string]$peores[0].ms + ' ms')
Comp '4d. con la clave "vuelta"' ($peores[0].clave -eq 'vuelta') 'el almacen que ya existia'
# Y EL NIVEL, QUE ES LO QUE FALTABA (28/09, #41 de la revision). El peor del minuto dice si hubo un
# PICO; no dice nada si TODAS las vueltas son lentas, que es lo que le paso a Nova el 28/09: 92-98 %
# de un nucleo sostenido y cero lineas SORDA, porque ninguna vuelta destacaba sobre el p99 de las
# demas. Sin esta mediana, el medidor del pulso es ciego justo para lo peor que puede pasarle.
Comp '4c2. y ademas se guarda la MEDIANA del minuto' ($medianas.Count -eq 1) ([string]$medianas.Count + ' con clave vuelta-mediana')
Comp '4c3. que es el nivel, no el pico' (($medianas.Count -eq 1) -and ($medianas[0].ms -lt 900) -and ($medianas[0].ms -gt 0)) $(if ($medianas.Count) { [string]$medianas[0].ms + ' ms frente a los 900 del pico' } else { 'no hay' })
$script:msFalsos = 62000
Add-VueltaMedida 40
Comp '4e. y no se vuelve a escribir hasta el minuto siguiente' (@($script:aDisco | Where-Object { $_.clave -eq 'vuelta' }).Count -eq 1) ''

Write-Host ''
Write-Host '-- 4b. Y SI TODAS SON LENTAS, SE DICE (el caso que el pico no ve) --'
# Con quinientas vueltas de 600 ms no hay ni un pico: la 501 tambien son 600, o sea que no supera
# el p99 de las demas y por ahi no sale nada. Lo unico que lo puede cazar es el nivel.
Reset
$script:vueltaNivelDicho = $false
for ($i = 0; $i -lt 500; $i++) { $script:msFalsos = 1000 + ($i * 600); Add-VueltaMedida 600 }
$script:msFalsos = $script:msFalsos + 61000
Add-VueltaMedida 600
$lentas = @($script:logs | Where-Object { $_ -match '^LENTA' })
Comp '4f. con todas las vueltas a 600 ms, lo dice' ($lentas.Count -eq 1) ([string]$lentas.Count + ' linea(s)')
Comp '4g. y dice cuantas vueltas por segundo esta dando' (($lentas.Count -eq 1) -and ($lentas[0] -match 'vueltas por segundo')) $(if ($lentas.Count) { ([string]$lentas[0]).Substring(0, [Math]::Min(96, ([string]$lentas[0]).Length)) } else { '' })
Comp '4h. ni una linea SORDA en todo eso' (@($script:logs | Where-Object { $_ -match '^SORDA' }).Count -eq 0) 'ningun pico: por eso hacia falta el nivel'
# y UNA sola por sesion: repetirlo cada minuto seria ruido
$script:msFalsos = $script:msFalsos + 61000
Add-VueltaMedida 600
Comp '4i. y no se repite al minuto siguiente' (@($script:logs | Where-Object { $_ -match '^LENTA' }).Count -eq 1) 'una por sesion'
# EL CASO NEGATIVO, que es el que dice que esto vigila de verdad: con el bucle ocioso, callado.
Reset
$script:vueltaNivelDicho = $false
for ($i = 0; $i -lt 500; $i++) { $script:msFalsos = 1000 + ($i * 31); Add-VueltaMedida 31 }
$script:msFalsos = $script:msFalsos + 61000
Add-VueltaMedida 31
Comp '4j. pero con el bucle ocioso (31 ms) no dice nada' (@($script:logs | Where-Object { $_ -match '^LENTA' }).Count -eq 0) 'el liston es 3 veces lo que duerme'

Write-Host ''
Write-Host '-- 5. LA MEMORIA NO CRECE SIN FIN --'
Reset
for ($i = 0; $i -lt ($VueltasMemoria + 300); $i++) { Add-VueltaMedida 31 }
Comp '5a. la lista se queda en su tope' ($script:vueltas.Count -eq $VueltasMemoria) ([string]$script:vueltas.Count + ' vueltas')

Write-Host ''
Write-Host '-- 6. EL CABLEADO EN EL BUCLE --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '6a. se mide lo PRIMERO de la vuelta' ($sinCom -match '(?s)\$vAhora = \$sw\.ElapsedMilliseconds\s*\r?\n\s*if \(\$script:vueltaDesde -gt 0\)') ''
Comp '6b. midiendo la vuelta ANTERIOR (una resta, coste cero)' ($sinCom -match '\$script:vueltaMs = \[int\]\(\$vAhora - \$script:vueltaDesde\)') ''
Comp '6c. y la etiqueta se pone en Log, que es el embudo' ($sinCom -match '\$script:ultimoLog = if \(\$msg\.Length -gt 80\)') 'no en cincuenta sitios a mano'
Comp '6d. el medidor va dentro de su propio try' ($sinCom -match 'try \{ Add-VueltaMedida \$script:vueltaMs \} catch \{\}') 'medir no puede tumbar una vuelta'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova mide su propio pulso y dice cuando se queda sorda' -ForegroundColor Green
exit 0
