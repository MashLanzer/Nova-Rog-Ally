# DOS DECISIONES QUE NO SE CUMPLIAN (21/09), de la tanda de agentes.
#
# 1. EL TOPE DE LA NUBE SE CAMBIABA SOLO EN MEMORIA. El caso 4 de la revision propia hacia
#    $script:NubeTopeMs = $quieroN y anunciaba el cambio por voz, pero NUNCA lo escribia en
#    config.json, que es de donde se lee al arrancar. Como la mediana de sesion son 5,8
#    minutos, a los pocos minutos volvia a 7000 sin decir nada. Y encima Save-DecisionPropia
#    SI dejaba escrito que habia decidido, asi que no lo volvia a intentar: bloqueada para
#    siempre en un tope que no llego a cambiar nunca.
#    Estaba ARMADO al encontrarlo: 74 respuestas guardadas, p90 = 7456 ms, o sea que en la
#    siguiente revision Nova habria dicho "he cambiado lo que espero de 7 a 8,5 segundos".
#
# 2. Y ERA LA UNICA DECISION SIN EL FRENO DE "DATOS REPARTIDOS". Las otras tres exigen al
#    menos 3 dias distintos y ninguno con mas del 70 % de los datos; esta no podia, porque
#    nube-tiempos.json era una lista pelada de enteros sin fecha. Una tarde jugando lejos
#    del router bastaba para arrastrar el p90 y subir el tope al techo.
#
# 3. Y LA SORDINA SE ROMPIA DICIENDO "NOVA". La pausa larga se pone sin texto (marca 'x'),
#    pero la frase de respuesta vuelve a pasar por Pausar-Escucha CON texto y la reescribe
#    como 'voz:...', donde se quedaba los 30 minutos: con esa marca el worker sigue
#    reconociendo palabras de corte -"nova", "para", "calla"- sobre cada bloque de audio.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA: todo lo que se llame aqui sale del archivo de verdad, o esto prueba humo.
# ConvertTo-Plain esta aqui porque la LINEA de la marca la llama por dentro. Van ocho
# veces que me dejo una funcion fuera de esta lista y la prueba corre contra el vacio.
foreach ($fn in @('Get-NubeTiempos', 'Get-NubeDias', 'Add-NubeTiempo', 'Get-NubePercentil', 'Test-NubeRepartida', 'ConvertTo-Plain')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\r\n].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
function Log($t) { }
function Test-DiaCuenta([string]$d) { return $true }   # la de verdad corta lo anterior al 19/09

$base = Join-Path ([System.IO.Path]::GetTempPath()) ('nubedias-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$NubeTiemposJson = Join-Path $base 'nube-tiempos.json'
$NubeTiemposMax = 200

function PonCrudo($obj) {
    [System.IO.File]::WriteAllText($NubeTiemposJson, ($obj | ConvertTo-Json -Depth 4 -Compress), (New-Object System.Text.UTF8Encoding $false))
}

Write-Host ''
Write-Host '-- 1. el tope se GUARDA antes de anunciarlo --'
Comp 'escribe el valor nuevo en config.json' ($fuente -match "Set-Cfg 'escucha' 'nubeTopeMs' \(\[string\]\`$quieroN\)")
Comp 'y si no puede guardarlo, NO decide nada' `
    ($fuente -match "(?s)if \(-not \(Set-Cfg 'escucha' 'nubeTopeMs'.{0,260}return \`$false")
Comp 'ademas suelta el dia para poder reintentarlo' `
    ($fuente -match "(?s)if \(-not \(Set-Cfg 'escucha' 'nubeTopeMs'.{0,160}revisionPropiaDia = ''")
# el orden importa: guardar ANTES de dejar escrito que se decidio, o queda bloqueada
$iSet = $fuente.IndexOf("Set-Cfg 'escucha' 'nubeTopeMs'")
$iSave = $fuente.IndexOf("Save-DecisionPropia 'escucha' 'nubeTopeMs'")
Comp 'y guarda ANTES de apuntar que ha decidido' ($iSet -gt 0 -and $iSet -lt $iSave) "config en $iSet, decision en $iSave"
# el texto de "lo que habia antes" tiene que salir de $antesN, no del valor ya cambiado
Comp 'y dice el valor de ANTES, no el nuevo' ($fuente -match '\[Math\]::Round\(\[int\]\$antesN / 1000\.0, 1\)')

Write-Host ''
Write-Host '-- 2. el techo, que no es cosmetico: el bucle se queda parado esperando --'
Comp 'el techo baja de 12 a 9 segundos' ($fuente -match 'if \(\$quieroN -gt 9000\) \{ \$quieroN = 9000 \}')
Comp 'y ya no queda el de 12' ($fuente -notmatch 'if \(\$quieroN -gt 12000\)')
Comp 'el suelo de 2 s sigue donde estaba' ($fuente -match 'if \(\$quieroN -lt 2000\) \{ \$quieroN = 2000 \}')

Write-Host ''
Write-Host '-- 3. el freno de dias repartidos, que es lo que evita decidir con una tarde mala --'
Comp 'la decision lo exige' ($fuente -match '\$msN\.Count -ge \$DecisionMinIntentos -and \(Test-NubeRepartida\)')

# todo de un solo dia: no vale, por muchas muestras que haya
PonCrudo @{ ms = @(1..40 | ForEach-Object { 3000 }); dias = @(1..40 | ForEach-Object { '2026-09-21' }) }
# OJO CON @(Get-NubeDias): como acaba en 'return ,$dl', envolverla en @() deja un array
# de UN elemento con el ArrayList dentro. Hay que ASIGNARLA. Aqui me costo cuatro rojos
# falsos... y de paso saco un fallo de verdad en Test-NubeRepartida, que hacia justo eso.
$dTmp = Get-NubeDias
Comp 'cuarenta muestras de UN dia no bastan' (-not (Test-NubeRepartida)) "$(($dTmp | Sort-Object -Unique).Count) dia(s)"

# dos dias tampoco
PonCrudo @{ ms = @(1..40 | ForEach-Object { 3000 }); dias = @((1..20 | ForEach-Object { '2026-09-20' }) + (1..20 | ForEach-Object { '2026-09-21' })) }
Comp 'dos dias tampoco' (-not (Test-NubeRepartida))

# tres dias repartidos: si
PonCrudo @{ ms = @(1..30 | ForEach-Object { 3000 }); dias = @((1..10 | ForEach-Object { '2026-09-19' }) + (1..10 | ForEach-Object { '2026-09-20' }) + (1..10 | ForEach-Object { '2026-09-21' })) }
Comp 'tres dias bien repartidos SI valen' (Test-NubeRepartida)

# tres dias pero uno se lo come casi todo: la tarde mala junto al router
PonCrudo @{ ms = @(1..100 | ForEach-Object { 3000 }); dias = @((1..90 | ForEach-Object { '2026-09-21' }) + @('2026-09-20', '2026-09-19') + (1..8 | ForEach-Object { '2026-09-21' })) }
Comp 'tres dias con uno acaparando el 98 % NO valen' (-not (Test-NubeRepartida))

Write-Host ''
Write-Host '-- y las muestras viejas, que no traen dia: cuentan para el p90 y no para el reparto --'
PonCrudo @{ ms = @(1000, 2000, 3000, 4000); hasta = '2026-09-20 10:00:00' }
$sinDia = Get-NubeDias
Comp 'un archivo de antes da tantos dias vacios como muestras' ($sinDia.Count -eq 4) "$($sinDia.Count) de 4"
Comp 'y todos vacios' ((@($sinDia | Where-Object { $_ -eq '' }).Count) -eq 4)
Comp 'con lo cual no hay reparto y no se decide' (-not (Test-NubeRepartida))
$tSinDia = Get-NubeTiempos
Comp 'pero los tiempos siguen contando' ($tSinDia.Count -eq 4) "$($tSinDia.Count) de 4"

# y al anadir una nueva, el dia va en su sitio: el ultimo
[void](Add-NubeTiempo 5000)
$d2 = Get-NubeDias
$t2 = Get-NubeTiempos
Comp 'al anadir una, las listas siguen igual de largas' ($d2.Count -eq $t2.Count) "$($d2.Count) dias, $($t2.Count) tiempos"
Comp 'y la nueva trae el dia de hoy' ($d2[$d2.Count - 1] -eq (Get-Date -Format 'yyyy-MM-dd')) "'$($d2[$d2.Count - 1])'"
Comp 'en la misma posicion que su tiempo' ($t2[$t2.Count - 1] -eq 5000)

Write-Host ''
Write-Host '-- 4. la sordina ya no deja la marca en modo voz --'
Comp 'la marca mira si hay sordina' ($fuente -match '\$voz -and \$InterrumpirOn -and \$script:sordinaHasta -le \$sw\.ElapsedMilliseconds')
# y que la cuenta salga bien en los dos casos, con la linea TAL CUAL del archivo
# LAS TRES LINEAS DEL if, no solo la primera. Cuando se puso la sordina-por-nombre (22/09)
# el if paso a tener un elseif, y este banco seguia cogiendo UNA linea: ejecutaba un if sin
# su elseif, la marca salia vacia y el caso de la sordina se ponia rojo con el codigo bien.
$mM = [regex]::Match($fuente, '(?ms)^\s*\$marcaTxt = if \(.*?^\s*else \{[^
]*\}')
if (-not $mM.Success) { Comp 'encuentro la linea de la marca' $false } else {
    $linea = [scriptblock]::Create($mM.Value.Trim())
    $EscuchaNombre = 'nova'
    $sw = [System.Diagnostics.Stopwatch]::StartNew(); Start-Sleep -Milliseconds 30
    $InterrumpirOn = $true
    $voz = 'me callo media hora'
    $script:sordinaHasta = 0
    . $linea
    Comp 'sin sordina, la marca lleva la voz (se puede interrumpir)' ($marcaTxt -like 'voz:*') "'$marcaTxt'"
    $script:sordinaHasta = $sw.ElapsedMilliseconds + 1800000
    . $linea
    # EN SORDINA, EL NOMBRE (22/09, funcion 4): el worker deja de escuchar ordenes pero
    # sigue esperando 'nova', que es como se sale de la sordina hablando. Antes era 'x' -no
    # escuchaba nada- y entonces la unica salida era el boton.
    Comp 'en sordina, la marca es el nombre (la unica puerta para volver)' ($marcaTxt -like 'nombre:*') "'$marcaTxt'"
    # el caso de la carga: la variable todavia no existe
    Remove-Variable sordinaHasta -Scope Script -ErrorAction SilentlyContinue
    . $linea
    Comp 'y antes de que exista la variable, se comporta como sin sordina' ($marcaTxt -like 'voz:*') "'$marcaTxt'"
}

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  el tope que Nova anuncia es el que se queda, y la sordina se calla de verdad'
exit 0
