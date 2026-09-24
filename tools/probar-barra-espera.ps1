# LA BARRA DE ESPERA SE LA MIDE ELLA (22/09).
#
# El numero que dibuja la barra estaba escrito a mano en dos tablas, y contra las 141 lineas
# "TRABAJO ... seg=" que Nova apunta desde el 18/09 dos de ellos mentian:
#   api-plan       n=15   mediana 1,5 s   p75 1,6    maximo 2,9    escrito 3,0
#   api-pregunta   n=11   mediana 5,7 s   p75 6,6    maximo 7,6    escrito 4,0
#   api-traducir   n=104  mediana 1,8 s   p75 2,2    maximo 6,0    escrito 2,5
#   cc-accion      n=11   mediana 20,4 s  p75 23,5   maximo 28,4   escrito 25,0
# O sea: el plan pintaba el 50 % de la barra cuando YA HABIA TERMINADO, y la pregunta se
# quedaba clavada en el 97 % los dos segundos largos que le faltaban. El comentario de al
# lado ya lo avisaba -"si miente, la barra no sirve de nada"- y el del 18/09 decia que el
# plan "aun tiene 0 ejecuciones y no hay mediana real que copiar". Ahora hay quince.
#
# braya lo pidio para el liston de letras y vale igual aqui: "todo deberia ser ajustable por
# ella". Asi que el numero deja de estar escrito y sale de lo que tarda de verdad.
#
# REGLA DEL BANCO (van diecinueve): las cuatro funciones y las dos tablas se TRAEN de
# assistant.ps1. El unico cambio es a donde apunta el fichero, que aqui va a una carpeta
# temporal para no tocar la memoria de verdad.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

foreach ($fn in @('Get-TrabajoTiempos', 'Add-TrabajoTiempo', 'Get-TrabajoPercentil', 'Get-DuracionEsperada')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\[].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
foreach ($v in @('DURACION_ESPERADA', 'DURACION_CC', 'TrabajoTiemposMax', 'TrabajoTiemposMin',
                 'TrabajoPercentil', 'TrabajoSuelo', 'TrabajoTecho')) {
    $m = [regex]::Match($fuente, ('(?m)^\${0} = .*$' -f [regex]::Escape($v)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro ${0}' -f $v); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-barra-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$TrabajoTiemposJson = Join-Path $tmpDir 'trabajo-tiempos.json'

function Limpiar { Remove-Item -LiteralPath $TrabajoTiemposJson -Force -ErrorAction SilentlyContinue }
function Meter([string]$clave, [int[]]$ms) { foreach ($x in $ms) { [void](Add-TrabajoTiempo $clave $x) } }

Write-Host ''
Write-Host '-- guardar y volver a leer --'
Limpiar
# LA TRAMPA DEL DESENROLLADO, que aqui se paga dos veces: PowerShell desenrolla lo que
# devuelve una funcion, y una lista vacia desenrollada se queda en $null, asi que quien la
# reciba peta al pedirle .Count. Por eso Get-TrabajoTiempos devuelve "return ,$l".
$l = Get-TrabajoTiempos 'api-plan'
Comp 'sin fichero devuelve una lista, no $null' ($null -ne $l) 'la coma de "return ,$l"'
Comp 'y esta vacia' ($l.Count -eq 0) "$($l.Count)"
Comp 'con la clave vacia tampoco peta' ((Get-TrabajoTiempos '').Count -eq 0)

# Y LA OTRA TRAMPA, la de ConvertTo-Json: en PowerShell 5.1 un array de UN elemento se
# escribe como un numero pelado, no como una lista. Si al releerlo no se envolviera en @(),
# el primer trabajo de cada clave se perderia en silencio.
Meter 'api-plan' @(1500)
$l = Get-TrabajoTiempos 'api-plan'
Comp 'una sola muestra se guarda y se lee' ($l.Count -eq 1) "$($l.Count) muestras"
Comp 'y con su valor' ($l.Count -eq 1 -and [int]$l[0] -eq 1500) "$($l -join ',')"
Meter 'api-plan' @(1600, 1700)
Comp 'y las siguientes se anaden' ((Get-TrabajoTiempos 'api-plan').Count -eq 3)

Write-Host ''
Write-Host '-- no se lleva por delante lo de los demas --'
# Aqui solo se sabe de un motor y un modo, y el fichero se reescribe entero: perder las
# otras claves seria empezar de cero en cada trabajo.
Meter 'claude-code-accion' @(20000, 21000)
Comp 'la clave nueva esta' ((Get-TrabajoTiempos 'claude-code-accion').Count -eq 2)
Comp 'y la de antes sigue entera' ((Get-TrabajoTiempos 'api-plan').Count -eq 3)
Meter 'api-traducir' @(1800)
Comp 'con tres claves, ninguna se pisa' `
    ((Get-TrabajoTiempos 'api-plan').Count -eq 3 -and (Get-TrabajoTiempos 'claude-code-accion').Count -eq 2 -and (Get-TrabajoTiempos 'api-traducir').Count -eq 1)
$crudo = Get-Content -LiteralPath $TrabajoTiemposJson -Raw -Encoding UTF8
Comp 'el fichero es JSON legible' ($null -ne ($crudo | ConvertFrom-Json))

Write-Host ''
Write-Host '-- el tope de la cinta --'
Limpiar
Meter 'api-traducir' (1..($TrabajoTiemposMax + 15) | ForEach-Object { 1000 + $_ })
$l = Get-TrabajoTiempos 'api-traducir'
Comp "no guarda mas de $TrabajoTiemposMax" ($l.Count -eq $TrabajoTiemposMax) "$($l.Count) muestras"
Comp 'y lo que tira es lo mas viejo' ([int]$l[$l.Count - 1] -eq (1000 + $TrabajoTiemposMax + 15)) "la ultima es $($l[$l.Count-1])"
Comp 'la mas vieja ya no esta' (-not ($l -contains 1001))

Write-Host ''
Write-Host '-- hasta que no hay bastantes, no opina --'
Limpiar
# Un p75 de tres datos es una corazonada con aspecto de dato. La misma regla que
# Get-FraseNubeTiempo.
Meter 'api-plan' @(1000, 1100, 1200)
Comp "con 3 muestras (menos de $TrabajoTiemposMin) devuelve 0" ((Get-TrabajoPercentil 'api-plan' 75) -eq 0)
Comp 'y la barra usa el numero escrito' ((Get-DuracionEsperada 'api' 'plan') -eq [int]$DURACION_ESPERADA['plan']) `
    "$([int]$DURACION_ESPERADA['plan']) ms"
Limpiar
# Diez muestras clavadas: el p75 de diez iguales es ese numero, pase lo que pase.
Meter 'api-plan' (1..$TrabajoTiemposMin | ForEach-Object { 1500 })
Comp "con $TrabajoTiemposMin muestras ya opina" ((Get-TrabajoPercentil 'api-plan' 75) -eq 1500) `
    "$(Get-TrabajoPercentil 'api-plan' 75) ms"

Write-Host ''
Write-Host '-- el percentil, por el metodo del mas cercano --'
Limpiar
# 1..20, sin interpolar: el p75 es el elemento 15 de 20 (ceil(0,75*20) = 15), o sea 1500.
Meter 'api-pregunta' (1..20 | ForEach-Object { $_ * 100 })
Comp 'p75 de 1..20 es el 15o' ((Get-TrabajoPercentil 'api-pregunta' 75) -eq 1500) "$(Get-TrabajoPercentil 'api-pregunta' 75)"
Comp 'p50 es el 10o' ((Get-TrabajoPercentil 'api-pregunta' 50) -eq 1000) "$(Get-TrabajoPercentil 'api-pregunta' 50)"
Comp 'p100 es el ultimo' ((Get-TrabajoPercentil 'api-pregunta' 100) -eq 2000) "$(Get-TrabajoPercentil 'api-pregunta' 100)"
Comp 'p1 es el primero, sin salirse por abajo' ((Get-TrabajoPercentil 'api-pregunta' 1) -eq 100) "$(Get-TrabajoPercentil 'api-pregunta' 1)"
# Da igual en que orden hayan llegado: se ordena antes.
Limpiar
Meter 'api-pregunta' (20..1 | ForEach-Object { $_ * 100 })
Comp 'y da igual el orden de llegada' ((Get-TrabajoPercentil 'api-pregunta' 75) -eq 1500)

Write-Host ''
Write-Host '-- el suelo y el techo de lo escrito --'
# Como el liston de letras de wake_vosk: el suelo protege el barrido de la capsula de irse
# adelante, y el techo evita que una tarde de red mala deje la barra parada en el 10 %.
$escritoPreg = [int]$DURACION_ESPERADA['pregunta']
Limpiar
Meter 'api-pregunta' (1..15 | ForEach-Object { 50 })          # absurdamente rapido
Comp 'un medido ridiculo se queda en el suelo' `
    ((Get-DuracionEsperada 'api' 'pregunta') -eq [int]($escritoPreg * $TrabajoSuelo)) `
    "$(Get-DuracionEsperada 'api' 'pregunta') ms (suelo $([int]($escritoPreg * $TrabajoSuelo)))"
Limpiar
Meter 'api-pregunta' (1..15 | ForEach-Object { 900000 })       # absurdamente lento
Comp 'y uno disparatado, en el techo' `
    ((Get-DuracionEsperada 'api' 'pregunta') -eq [int]($escritoPreg * $TrabajoTecho)) `
    "$(Get-DuracionEsperada 'api' 'pregunta') ms (techo $([int]($escritoPreg * $TrabajoTecho)))"
Limpiar
Meter 'api-pregunta' (1..15 | ForEach-Object { 5800 })         # razonable
Comp 'y uno razonable se usa tal cual' ((Get-DuracionEsperada 'api' 'pregunta') -eq 5800) `
    "$(Get-DuracionEsperada 'api' 'pregunta') ms"

Write-Host ''
Write-Host '-- la clave lleva motor Y modo --'
# El mismo modo por la API y por Claude Code no se parecen en nada (1,5 s contra 20), y
# mezclarlos daria un numero que no sirve para ninguno de los dos.
Limpiar
Meter 'claude-code-pregunta' (1..15 | ForEach-Object { 9000 })
Comp 'lo de claude-code no contamina a la api' `
    ((Get-DuracionEsperada 'api' 'pregunta') -eq [int]$DURACION_ESPERADA['pregunta']) `
    'la api sigue con lo escrito'
Comp 'y claude-code usa lo suyo' ((Get-DuracionEsperada 'claude-code' 'pregunta') -eq 9000)
Comp 'un motor vacio cuenta como api' `
    ((Get-DuracionEsperada '' 'plan') -eq (Get-DuracionEsperada 'api' 'plan')) 'como la linea TRABAJO del log'
Comp 'un modo desconocido cae en los 60 s' ((Get-DuracionEsperada 'api' 'loquesea') -eq 60000)
# $script:jobModo esta vacio entre trabajo y trabajo, y Hashtable.ContainsKey($null) revienta
Comp 'y un modo vacio no revienta' ((Get-DuracionEsperada 'api' '') -eq 60000)
Comp 'ni con los dos vacios' ((Get-DuracionEsperada '' '') -eq 60000)

Write-Host ''
Write-Host '-- las tablas escritas, al dia con lo medido --'
# Son el punto de partida Y el suelo y el techo, asi que si mienten, mienten dos veces.
# Estos son los p75 de las 141 lineas TRABAJO del log del 22/09.
foreach ($c in @(@('plan', 1600), @('pregunta', 6600), @('traducir', 2200))) {
    $esc = [int]$DURACION_ESPERADA[$c[0]]
    Comp ("'{0}' escrito {1} ms, medido {2}" -f $c[0], $esc, $c[1]) ($esc -eq $c[1])
}
Comp "'charla' sigue en 5000 (no hay ni una medida)" ([int]$DURACION_ESPERADA['charla'] -eq 5000)
Comp "'accion' de opencode sigue en 60000" ([int]$DURACION_ESPERADA['accion'] -eq 60000)
# EL P75 REPRODUCE LO QUE SI SE PENSO EL 18/09, que es la prueba de que es el liston bueno:
# traducir 2.200 frente a 2.500 y accion 23.500 frente a 25.000. Solo mueve los dos que
# entonces nadie pudo medir. Con la mediana pelada, 'accion' se iria a 20,4 s y adelantaria
# el barrido de la capsula casi cuatro segundos con un juego delante, que es justo lo que el
# 18/09 se decidio NO hacer.
Comp 'el p75 no adelanta el barrido de accion (cc)' `
    ([Math]::Abs([int]$DURACION_CC['accion'] - 23500) -le 2000) "$([int]$DURACION_CC['accion']) ms escrito, 23500 medido"

Write-Host ''
Write-Host '-- y lo que NO puede cambiar --'
# EL BUCLE es el peligro de todo lo que se mide solo. Aqui no lo hay: se apunta el tiempo de
# TODOS los trabajos que terminan, sin mirar lo que dijera la barra.
Comp 'se apunta sin mirar lo que dijo la barra' `
    (-not ($fuente -match 'Add-TrabajoTiempo.*jobEspMs|jobEspMs.*Add-TrabajoTiempo'))
Comp 'solo se apunta si el trabajo termino bien' ($fuente -match '\$code -eq 0 -and \$script:jobModo -and \$msT -ge 300')
# Se apunta en Complete-OpencodeJob, que es el UNICO punto por el que pasa un trabajo
# entero: el cancelado o vencido se va por Stop-OpencodeJob y no llega.
$mStop = [regex]::Match($fuente, '(?ms)^function Stop-OpencodeJob.*?^\}')
Comp 'lo cancelado no se apunta' ($mStop.Success -and -not ($mStop.Value -match 'Add-TrabajoTiempo'))
# La barra no decide NADA: no corta, no reintenta, no cambia de motor. El plazo de rendirse
# es Get-PlazoJob, y no mira esto ni lo mirara.
$mPlazo = [regex]::Match($fuente, '(?ms)^function Get-PlazoJob.*?^\}')
Comp 'Get-PlazoJob sigue sin mirar la barra' `
    ($mPlazo.Success -and -not ($mPlazo.Value -match 'DuracionEsperada|TrabajoPercentil|jobEspMs'))
# Se pide UNA vez por trabajo: Watch-OpencodeProgress corre cada 600 ms y esto abre un
# fichero.
$mWatch = [regex]::Match($fuente, '(?ms)^function Watch-OpencodeProgress.*?^\}')
Comp 'el numero se pide una sola vez por trabajo' ($mWatch.Value -match 'if \(\$script:jobEspMs -le 0\)')
Comp 'y no puede ser 0 (tres lineas abajo se divide)' ($mWatch.Value -match 'if \(\$script:jobEspMs -le 0\) \{ \$script:jobEspMs = 60000 \}')
Comp 'lo dice en el log, para poder comprobarlo' ($mWatch.Value -match 'BARRA \$\(\$script:jobMotor\)')
# Y se borra al acabar: la estimacion es de ESTE trabajo, no de los que vengan.
$mClear = [regex]::Match($fuente, '(?ms)^function Clear-OpencodeJob.*?^\}')
Comp 'y se borra al cerrar el trabajo' ($mClear.Value -match '\$script:jobEspMs = 0')
# El fichero es memoria de uso, como nube-tiempos.json: no va al repositorio.
$gi = Get-Content -LiteralPath (Join-Path $raiz '.gitignore') -Raw
Comp 'trabajo-tiempos.json no va al repositorio' ($gi -match 'trabajo-tiempos\.json')

Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  la barra ya no miente: el numero se lo mide ella'
exit 0
