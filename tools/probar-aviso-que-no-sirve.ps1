# EL AVISO QUE NO SIRVE: ANTES SE ESPERABA MAS, AHORA SE BAJA A LA PANTALLA (1/10, idea 9 de 20)
#
# El freno de la espera YA EXISTIA (Get-EsperaAviso, 25/09) y funciona. Lo que medi el 1/10 es que
# casi nunca llega a activarse: pide OCHO reacciones por clave y solo DOS de dieciseis llegan
# -'oido-ruido' (36) y 'hora-dormir' (12)-. Las otras catorce no frenan nunca, y entre ellas estan
# las que NO HAN SERVIDO NI UNA VEZ: 'disco-poco' 0 de 4 (aparcado 842 veces en el registro),
# 'gmail-lleno' 0 de 3 (aparcado 1.652).
#
# DOS CAMBIOS, NINGUNO TOCA EL FRENO QUE FUNCIONA:
#  1. CERO DE CINCO YA ES SENAL. Si la tasa real fuera el 30 % -el liston de "aporta"-, la
#     probabilidad de cero aciertos seguidos es 0,7^N: con cuatro es el 24 % (puede ser mala
#     suerte), con CINCO el 17 %, con seis el 12 %. Solo para el cero EXACTO: con 1 de 5 la senal es
#     floja y manda el liston de ocho, como siempre.
#  2. Y EL QUE NO HA SERVIDO JAMAS SE BAJA A NIVEL 'bajo', que ya significa "solo se ve en la
#     capsula, no suena". Alargar la espera tiene tope de SEIS HORAS a proposito, asi que un aviso
#     inutil seguiria sonando cuatro veces al dia para siempre. Bajarlo es mejor que callarlo: el
#     dato sigue llegando y deja de interrumpir, y si algun dia sirve vuelve a subir solo.
#
# HONESTO: con los datos del 1/10 esto NO CAMBIA NADA todavia. 'disco-poco' tiene 0 de 4 y el
# liston es 5: le falta una muestra. No se baja a 4 para que haga algo, porque un 0 de 4 es mala
# suerte una de cada cuatro veces y eso es poco para callar un aviso.
#
# LO QUE DEFIENDE:
#  1. que lo CRITICO ('alto') no se baje nunca, ni con cien ceros;
#  2. que 'noche' tampoco: ese nivel no habla de urgencia sino de CUANDO se puede decir;
#  3. que un aviso que sirvio UNA vez siga sonando;
#  4. que el cero exacto frene antes, y que 1 de 5 NO;
#  5. y que el nivel se decida en UN solo sitio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
# los mismos valores que el fichero
$AvisoReaccionMin = 8
$AvisoReaccionCeroMin = 5
$AvisoEsperaTope = 6
$AvisoMudoCeros = 8
foreach ($n in @('Get-EsperaAviso', 'Get-NivelAviso')) { Invoke-Expression (Traer $n) }
# LAS REACCIONES, DOBLADAS: asi los numeros los decide el banco y no el fichero de braya, que
# cambia cada dia (seria la manera 7: el color lo pone el entorno, no el codigo).
$script:si = 0; $script:no = 0
function Get-ReaccionesAviso([string]$clave) {
    $r = @()
    for ($i = 0; $i -lt $script:si; $i++) { $r += $true }
    for ($i = 0; $i -lt $script:no; $i++) { $r += $false }
    return $r
}
$script:log = @()
function Log([string]$m) { $script:log += $m }
$script:apuntado = @()
function Add-Estadistica([string]$k, [string]$v = '') { $script:apuntado += "$k=$v" }
function Poner([int]$si, [int]$no) { $script:si = $si; $script:no = $no; $script:log = @(); $script:apuntado = @() }

Write-Host ''
Write-Host '-- 1. el cero exacto frena antes (cinco en vez de ocho) --'
$base = 60
Poner 0 4
Comp 'con 0 de 4 todavia NO frena' ((Get-EsperaAviso 'x' $base) -eq $base) "$(Get-EsperaAviso 'x' $base) min"
Poner 0 5
Comp 'con 0 de 5 SI frena' ((Get-EsperaAviso 'x' $base) -gt $base) "$(Get-EsperaAviso 'x' $base) min"
Comp '  y por cuatro, que es lo que toca con tasa 0' ((Get-EsperaAviso 'x' $base) -eq ($base * 4)) "$(Get-EsperaAviso 'x' $base)"
Poner 0 7
Comp 'y con 0 de 7 tambien, sin esperar a los ocho' ((Get-EsperaAviso 'x' $base) -gt $base) "$(Get-EsperaAviso 'x' $base) min"

Write-Host ''
Write-Host '-- 2. pero UNA que sirva ya no es cero --'
# Con 1 de 5 la senal es floja: manda el liston de ocho, como siempre. Si esto fallara, un aviso
# que ha servido una vez de cinco se frenaria con los mismos datos que no bastan para nada.
Poner 1 4
Comp 'con 1 de 5 NO frena (le faltan muestras)' ((Get-EsperaAviso 'x' $base) -eq $base) "$(Get-EsperaAviso 'x' $base) min"
Poner 1 7
Comp 'con 1 de 8 si, porque ya hay ocho' ((Get-EsperaAviso 'x' $base) -gt $base) "$(Get-EsperaAviso 'x' $base) min"
# Y LO QUE APORTA NO SE TOCA: un tercio ya es servir
Poner 4 8
Comp 'y lo que sirve un tercio sigue igual' ((Get-EsperaAviso 'x' $base) -eq $base) "$(Get-EsperaAviso 'x' $base) min"

Write-Host ''
Write-Host '-- 3. el que no ha servido JAMAS se baja a la capsula --'
Poner 0 8
# SE LLAMA UNA VEZ Y SE GUARDA. Primer intento de estas cuatro lineas: el TEXTO DEL DETALLE del
# primer Comp era "$(Get-NivelAviso ...)", o sea una SEGUNDA llamada, y esa segunda escribia otra
# linea de registro y otro contador. Las tres comprobaciones de debajo contaban dos y salian rojas
# acusando al codigo de repetirse. El detalle de un Comp no puede ejecutar lo que se esta midiendo.
$nivelBajado = Get-NivelAviso 'disco-poco' 'medio'
Comp 'con 0 de 8, un aviso normal pasa a "bajo"' ($nivelBajado -eq 'bajo') "$nivelBajado"
Comp '  y lo dice en el registro' (@($script:log | Where-Object { $_ -match 'A LA CAPSULA' }).Count -eq 1) "$($script:log.Count) lineas"
Comp '  con la clave dentro' (@($script:log | Where-Object { $_ -match 'disco-poco' }).Count -eq 1) ''
Comp '  y lo apunta para poder contarlo' (@($script:apuntado | Where-Object { $_ -match '^aviso-a-capsula=disco-poco' }).Count -eq 1) "$($script:apuntado -join ' | ')"
Poner 0 7
Comp 'con 0 de 7 todavia no se baja' ((Get-NivelAviso 'x' 'medio') -eq 'medio') "$(Get-NivelAviso 'x' 'medio')"
Poner 1 20
Comp 'y uno que sirvio UNA vez de 21 sigue sonando' ((Get-NivelAviso 'x' 'medio') -eq 'medio') "$(Get-NivelAviso 'x' 'medio')"

Write-Host ''
Write-Host '-- 4. LO CRITICO NO SE TOCA, NI CON CIEN CEROS --'
# 'alto' se salta todos los filtros de la casa a proposito: es lo que hace que un aviso critico sea
# critico. Bajarlo por una estadistica seria romper eso.
Poner 0 100
Comp 'un aviso "alto" con 0 de 100 sigue siendo alto' ((Get-NivelAviso 'disco-critico' 'alto') -eq 'alto') "$(Get-NivelAviso 'disco-critico' 'alto')"
Comp '  y no suelta ni una linea de registro' ($script:log.Count -eq 0) "$($script:log -join ' | ')"
# 'noche' TAMPOCO: ese nivel no habla de urgencia, habla de CUANDO se puede decir -es el unico que
# se salta el silencio nocturno-, asi que bajarlo lo dejaria sin su unica ventana.
Comp "y 'noche' tampoco se baja" ((Get-NivelAviso 'hora-dormir' 'noche') -eq 'noche') "$(Get-NivelAviso 'hora-dormir' 'noche')"
Comp '  ni se queja de el' ($script:log.Count -eq 0) ''
# y uno que YA es 'bajo' no se vuelve a bajar ni ensucia el registro
Comp "uno que ya era 'bajo' se queda igual y calla" (((Get-NivelAviso 'x' 'bajo') -eq 'bajo') -and $script:log.Count -eq 0) ''

Write-Host ''
Write-Host '-- 5. y la espera sigue teniendo tope --'
# Ni con cien ceros se calla del todo: para eso esta lo de la capsula, no un plazo infinito.
Poner 0 100
Comp 'la espera no pasa del tope de 6 horas' ((Get-EsperaAviso 'x' $base) -le ($AvisoEsperaTope * 60)) "$(Get-EsperaAviso 'x' $base) min de $($AvisoEsperaTope * 60)"

Write-Host ''
Write-Host '-- 6. el cableado: el nivel se decide en UN solo sitio --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$cuerpoS = Traer 'Send-AvisoEntorno'
$sSin = (($cuerpoS -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'Send-AvisoEntorno decide el nivel' ($sSin -match '\$nivel = Get-NivelAviso \$clave \$nivel') ''
# EN LA PRIMERA LINEA: el nivel manda en el aplazado, la tarjeta y el tope por hora, asi que si se
# decide a mitad de camino la primera mitad cree que es 'medio' y la segunda que es 'bajo'.
$iNivel = $sSin.IndexOf('Get-NivelAviso')
$iAplaza = $sSin.IndexOf('Test-AvisoAplazable')
Comp '  ANTES de decidir si se aplaza' ($iNivel -ge 0 -and $iAplaza -ge 0 -and $iNivel -lt $iAplaza) "nivel en $iNivel, aplaza en $iAplaza"
Comp '  y solo hay un sitio que lo decida' ((@([regex]::Matches($sinCom, 'Get-NivelAviso'))).Count -eq 2) 'la definicion y la llamada'
Comp 'los dos numeros tienen su motivo escrito al lado' (($txt -match '0,7\^N') -and ($txt -match '0,7\^8')) 'de donde salen el 5 y el 8'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el aviso que nunca sirve se ve y no se oye' -ForegroundColor Green
exit 0
