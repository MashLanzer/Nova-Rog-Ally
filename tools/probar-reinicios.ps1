# SE MUERE LA MITAD DE LAS VECES Y SOLO RECUERDA LA ULTIMA (26/09, idea 50 de las 121).
#
# Medido sobre assistant.log.1 + assistant.log: 72 arranques / 36 cierres limpios = 50,0 % de
# los arranques no acaban en cierre normal, y 46 relanzamientos del oido o la capsula en 12 dias
# (pico de 9 el 22/09) que Nova nunca conto ni dijo. Ahora cuenta 'arranque', 'cierre-limpio',
# 'relanza:oido' y 'relanza:capsula', y Test-ReiniciosDeMas avisa (nivel 'medio', se aparca si
# no hay nadie) cuando HOY supera SU PROPIA mediana de 14 dias -nunca un numero a mano-.
#
# Los datos se INYECTAN: unas estadisticas de mentira. El banco EJECUTA Get-MedianaDias,
# Test-ReiniciosDeMas y Test-DatosRepartidos de verdad (AST), no las reescribe.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
# el fuente sin comentarios: una clave metida en un '#' no cuenta como enganche (manera 2)
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
function Trozo([string]$t, [string]$ini, [string]$fin) {
    $i = $t.IndexOf($ini); if ($i -lt 0) { return '' }
    $j = $t.IndexOf($fin, $i + $ini.Length); if ($j -lt 0) { return $t.Substring($i) }
    return $t.Substring($i, $j - $i)
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host ''
Write-Host '  -- 1. los cuatro enganches siguen puestos, en su bloque (comentarios fuera) --'
$tEx = Trozo $sinCom 'Register-EngineEvent PowerShell.Exiting' 'if ($cfgError)'
Comp '1a. cierre-limpio, con su guarda, en el bloque del Exiting' (($tEx -match "Add-Estadistica 'cierre-limpio'") -and ($tEx -match '\$script:arranqueContado')) ''
$tAr = Trozo $sinCom '$sw = [System.Diagnostics.Stopwatch]::StartNew()' 'if ($SaludoOn)'
Comp '1b. arranque, entre $sw y el saludo' ($tAr -match "Add-Estadistica 'arranque'") ''
$tOi = Trozo $sinCom 'el worker de escucha murio' 'Initialize-Escucha'
Comp '1c. relanza:oido, entre el Log y el Initialize-Escucha' ($tOi -match "Add-Estadistica 'relanza:oido'") 'si se moviera fuera del bloque, este trozo se queda sin el'
$tUi = Trozo $sinCom 'la interfaz murio' 'Initialize-UI'
Comp '1d. relanza:capsula, entre el Log y el Initialize-UI' ($tUi -match "Add-Estadistica 'relanza:capsula'") ''

Write-Host ''
Write-Host '  -- 2. la guarda de simetria se EJECUTA (scriptblock del Exiting via AST) --'
$sbAst = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and $x.Extent.Text -match 'VoiceAssistant cerrado PID=' }, $true)
if (-not $sbAst) { throw 'no encuentro el scriptblock del Exiting' }
$txt = $sbAst.Extent.Text
$sbEx = [scriptblock]::Create($txt.Substring(1, $txt.Length - 2))
$script:cierres = New-Object System.Collections.ArrayList
function Log([string]$m) { }
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) { [void]$script:cierres.Add($ruta) }
$script:arranqueContado = $false
$script:cierres.Clear(); & $sbEx
Comp '2a. sin arranque contado, NO apunta cierre-limpio' (-not ($script:cierres -contains 'cierre-limpio')) 'cubre el exit 1 de "opencode no encontrado"'
$script:arranqueContado = $true
$script:cierres.Clear(); & $sbEx
Comp '2b. con arranque contado, SI apunta cierre-limpio' ($script:cierres -contains 'cierre-limpio') ''

# --- el mundo de mentira para las funciones de la mediana y el aviso ---
$ahora = [datetime]'2026-09-26 18:00'
function Dia([int]$off) { return $ahora.AddDays(-$off).ToString('yyyy-MM-dd') }
$script:statsFalsas = @{ dias = @{} }
function Get-Estadisticas { return $script:statsFalsas }
$script:hoyCuenta = @{}
function Get-CuentaHoy([string]$r) { if ($script:hoyCuenta.ContainsKey($r)) { return [int]$script:hoyCuenta[$r] } return 0 }
function Test-DiaCuenta([string]$d) { return $true }
$script:avisos = New-Object System.Collections.ArrayList
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60, [bool]$yaEsperado = $false) {
    [void]$script:avisos.Add(@{ clave = $clave; texto = $texto; nivel = $nivel; cada = $cadaMin }); return $true
}
$script:invitado = $false
$script:juegoActivo = $null
$script:reiniciosAvisoDia = ''
Invoke-Expression (Traer 'Get-MedianaDias')
Invoke-Expression (Traer 'Test-DatosRepartidos')
Invoke-Expression (Traer 'Get-SumaDias')
Invoke-Expression (Traer 'Get-DiasConClave')
Invoke-Expression (Traer 'Get-TasaSucia')
Invoke-Expression (Traer 'Test-ReiniciosDeMas')

Write-Host ''
Write-Host '  -- 3, 4. la mediana cuenta los ceros y no se come el dia de hoy --'
# 3. 14 dias que existen; la clave en 5 (valor 10) y ausente en 9 -> los 9 ceros mandan, mediana 0
$s3 = @{ dias = @{} }
for ($i = 1; $i -le 14; $i++) { $s3.dias[(Dia $i)] = @{} }
$cinco = @(1, 3, 5, 7, 9)
foreach ($i in $cinco) { $s3.dias[(Dia $i)]['arranque'] = 10 }
$med3 = Get-MedianaDias $s3 'arranque' $ahora 14
Comp '3. con la clave en 5 de 14 dias, la mediana es 0 (los ceros cuentan)' ($med3 -eq 0) "mediana=$med3 (sin los ceros saldria 10)"
# 4. dos dias ayer/anteayer (1 y 3) y HOY enorme (100). Excluyendo hoy: mediana 2. Contando hoy: 3.
$s4 = @{ dias = @{} }
$s4.dias[(Dia 0)] = @{ 'arranque' = 100 }
$s4.dias[(Dia 1)] = @{ 'arranque' = 1 }
$s4.dias[(Dia 2)] = @{ 'arranque' = 3 }
$med4 = Get-MedianaDias $s4 'arranque' $ahora 14
Comp '4. la mediana excluye hoy: da 2, no 3' ($med4 -eq 2) "mediana=$med4 (si contara hoy=100 saldria 3)"

Write-Host ''
Write-Host '  -- 5. el liston es la mediana, no un numero --'
function DatosArranque([int[]]$prev, [int]$hoy) {
    $s = @{ dias = @{} }
    for ($i = 0; $i -lt $prev.Count; $i++) { $s.dias[(Dia ($i + 1))] = @{ 'arranque' = $prev[$i] } }
    $script:statsFalsas = $s
    $script:hoyCuenta = @{ 'arranque' = $hoy }
}
function Corre() { $script:avisos.Clear(); $script:reiniciosAvisoDia = ''; $script:invitado = $false; $script:juegoActivo = $null; return (Test-ReiniciosDeMas $ahora) }
DatosArranque @(5, 5, 5, 5, 5, 5) 8;  $rA = Corre; $nA = $script:avisos.Count
DatosArranque @(10, 10, 10, 10, 10, 10) 8; $rB = Corre; $nB = $script:avisos.Count
Comp '5. mismo hoy=8: habla con mediana 5 y calla con mediana 10' ($rA -and $nA -eq 1 -and (-not $rB) -and $nB -eq 0) "A=$rA/$nA  B=$rB/$nB"

Write-Host ''
Write-Host '  -- 6. la guarda de reparto manda (todo en un dia no dispara) --'
$s6 = @{ dias = @{} }
$s6.dias[(Dia 1)] = @{ 'arranque' = 5 }   # UN solo dia con datos
$script:statsFalsas = $s6
$script:hoyCuenta = @{ 'arranque' = 50 }
$script:avisos.Clear(); $script:reiniciosAvisoDia = ''; $script:invitado = $false; $script:juegoActivo = $null
$r6 = Test-ReiniciosDeMas $ahora
Comp '6. con todo el historial en un dia, calla (reparto < 3 dias)' ((-not $r6) -and $script:avisos.Count -eq 0) 'sin Test-DatosRepartidos hablaria (50>5)'

Write-Host ''
Write-Host '  -- 7. una vez al dia --'
DatosArranque @(5, 5, 5, 5, 5, 5) 8
$script:avisos.Clear(); $script:reiniciosAvisoDia = ''; $script:invitado = $false; $script:juegoActivo = $null
$p1 = Test-ReiniciosDeMas $ahora
$p2 = Test-ReiniciosDeMas $ahora
Comp '7. dos pasadas seguidas = un solo aviso' ($p1 -and (-not $p2) -and $script:avisos.Count -eq 1) "1a=$p1 2a=$p2 avisos=$($script:avisos.Count)"

Write-Host ''
Write-Host '  -- 8. con invitado o jugando, ni una palabra (casos que sin la guarda SI hablarian) --'
DatosArranque @(5, 5, 5, 5, 5, 5) 8
$script:avisos.Clear(); $script:reiniciosAvisoDia = ''; $script:invitado = $true; $script:juegoActivo = $null
$r8a = Test-ReiniciosDeMas $ahora
DatosArranque @(5, 5, 5, 5, 5, 5) 8
$script:avisos.Clear(); $script:reiniciosAvisoDia = ''; $script:invitado = $false; $script:juegoActivo = 'A Way Out'
$r8b = Test-ReiniciosDeMas $ahora
Comp '8. invitado -> calla, y jugando -> calla' ((-not $r8a) -and (-not $r8b) -and $script:avisos.Count -eq 0) "invitado=$r8a jugando=$r8b"

Write-Host ''
Write-Host '  -- 9. el texto lleva los DOS numeros (rama de relanzamientos: hoy 9, mediana 2) --'
$s9 = @{ dias = @{} }
$prev9 = @(1, 1, 2, 2, 3, 3)                 # mediana de oido = 2; capsula ausente = 0 -> mediana suma 2
for ($i = 0; $i -lt $prev9.Count; $i++) { $s9.dias[(Dia ($i + 1))] = @{ 'relanza:oido' = $prev9[$i] } }
$script:statsFalsas = $s9
$script:hoyCuenta = @{ 'relanza:oido' = 9; 'relanza:capsula' = 0 }   # arranque sin datos -> no habla por ahi
$script:avisos.Clear(); $script:reiniciosAvisoDia = ''; $script:invitado = $false; $script:juegoActivo = $null
$r9 = Test-ReiniciosDeMas $ahora
$txt9 = if ($script:avisos.Count) { [string]$script:avisos[0].texto } else { '' }
Comp '9. habla por relanzamientos y la frase lleva el 9 y el 2' ($r9 -and ($txt9 -match '\b9\b') -and ($txt9 -match '\b2\b') -and ($txt9 -notmatch 'arranques')) $txt9
# EL NIVEL CAMBIO EL 27/09 (idea 64): relanzar el oido o la capsula lo arregla Nova sola
# relanzando, asi que se VE en la capsula y no se dice ('bajo'). Lo que se dice en voz alta es
# lo que ella no se arregla: morirse entera o arrancar de mas.
Comp '   y el aviso es nivel "bajo" (se arregla sola), clave me-reinicio' ($script:avisos.Count -ge 1 -and $script:avisos[0].nivel -eq 'bajo' -and $script:avisos[0].clave -eq 'me-reinicio') $(if ($script:avisos.Count) { $script:avisos[0].nivel })


Write-Host ''
Write-Host '  -- 10 a 14. MORIR MAL: la semana contra la anterior (27/09, idea 64) --'
# La idea 50 dejo 'arranque' y 'cierre-limpio' contandose y NADIE los comparaba, que era el dato
# por el que nacio la idea: 72 arranques y 36 cierres limpios en los registros reales.
function DatosTasa([int]$arrR, [int]$cieR, [int]$arrA, [int]$cieA, [hashtable]$hoy = $null) {
    # se reparte en los 7 dias de cada ventana para que la guarda de reparto no lo frene
    $s = @{ dias = @{} }
    for ($i = 1; $i -le 7; $i++) { $s.dias[(Dia $i)] = @{ 'arranque' = 0; 'cierre-limpio' = 0 } }
    for ($i = 8; $i -le 14; $i++) { $s.dias[(Dia $i)] = @{ 'arranque' = 0; 'cierre-limpio' = 0 } }
    for ($n = 0; $n -lt $arrR; $n++) { $d = Dia (($n % 7) + 1); $s.dias[$d]['arranque'] = [int]$s.dias[$d]['arranque'] + 1 }
    for ($n = 0; $n -lt $cieR; $n++) { $d = Dia (($n % 7) + 1); $s.dias[$d]['cierre-limpio'] = [int]$s.dias[$d]['cierre-limpio'] + 1 }
    for ($n = 0; $n -lt $arrA; $n++) { $d = Dia (($n % 7) + 8); $s.dias[$d]['arranque'] = [int]$s.dias[$d]['arranque'] + 1 }
    for ($n = 0; $n -lt $cieA; $n++) { $d = Dia (($n % 7) + 8); $s.dias[$d]['cierre-limpio'] = [int]$s.dias[$d]['cierre-limpio'] + 1 }
    if ($hoy) { $s.dias[(Dia 0)] = $hoy }
    $script:statsFalsas = $s
    $script:hoyCuenta = @{ 'arranque' = 0 }   # hoy a cero: asi el que hable solo puede ser la tasa
}
# 10. esta semana 14 de 14 sin cierre normal; la anterior 1 de 14 -> habla, y con los dos numeros
DatosTasa 14 0 14 13; $r10 = Corre
$txt10 = if ($script:avisos.Count) { [string]$script:avisos[0].texto } else { '' }
Comp '10. con la tasa disparada, habla' ($r10 -and $script:avisos.Count -eq 1) $txt10
Comp '   y la frase lleva los dos porcentajes (100 y 7)' (($txt10 -match '100 %') -and ($txt10 -match '7 %')) $txt10
Comp '   con clave propia y nivel medio (esto NO se arregla sola)' ($script:avisos.Count -ge 1 -and $script:avisos[0].clave -eq 'me-muero-mal' -and $script:avisos[0].nivel -eq 'medio') $(if ($script:avisos.Count) { $script:avisos[0].clave })
# 11. EL MARGEN SALE DE LA MUESTRA: con 4 arranques, una subida de 25 puntos es UNA sesion -> calla
DatosTasa 4 2 4 3; $r11 = Corre
Comp '11. subida del tamano de una sola sesion (4 arranques, +25 pts): calla' ((-not $r11) -and $script:avisos.Count -eq 0) 'el margen es 1/4 = 25 pts'
# 11b. y con la MISMA subida pero 20 arranques (margen 5 pts), si habla
DatosTasa 20 10 20 15; $r11b = Corre
Comp '11b. la misma subida con 20 arranques (margen 5 pts): habla' ($r11b -and $script:avisos.Count -eq 1) 'la muestra manda, no un numero'
# 12. HOY NO ENTRA: la sesion de hoy esta viva y no tiene cierre; si contara, siempre saldria sucia
DatosTasa 14 14 14 14 @{ 'arranque' = 99; 'cierre-limpio' = 0 }; $r12 = Corre
Comp '12. hoy no cuenta para la tasa (99 arranques sin cierre hoy y calla)' ((-not $r12) -and $script:avisos.Count -eq 0) 'si contara hoy, hablaria siempre'
# 13. UNA TARDE DE DESARROLLO no es una averia: todo en un dia -> la guarda de reparto calla
$s13 = @{ dias = @{} }
$s13.dias[(Dia 1)] = @{ 'arranque' = 20; 'cierre-limpio' = 0 }
for ($i = 8; $i -le 14; $i++) { $s13.dias[(Dia $i)] = @{ 'arranque' = 2; 'cierre-limpio' = 2 } }
$script:statsFalsas = $s13; $script:hoyCuenta = @{ 'arranque' = 0 }
$r13 = Corre
Comp '13. 20 arranques sucios en UN solo dia: calla (reparto)' ((-not $r13) -and $script:avisos.Count -eq 0) 'sin la guarda, cada tarde de desarrollo seria una averia'
# 14. si coinciden la tasa mala Y los relanzamientos, habla la tasa: es la que no se arregla sola
$s14 = @{ dias = @{} }
for ($i = 1; $i -le 7; $i++) { $s14.dias[(Dia $i)] = @{ 'arranque' = 2; 'cierre-limpio' = 0; 'relanza:oido' = 1 } }
for ($i = 8; $i -le 14; $i++) { $s14.dias[(Dia $i)] = @{ 'arranque' = 2; 'cierre-limpio' = 2; 'relanza:oido' = 1 } }
$script:statsFalsas = $s14; $script:hoyCuenta = @{ 'arranque' = 0; 'relanza:oido' = 9 }
$r14 = Corre
Comp '14. con las dos cosas a la vez, habla la que no se arregla sola' ($r14 -and $script:avisos.Count -eq 1 -and $script:avisos[0].clave -eq 'me-muero-mal') $(if ($script:avisos.Count) { $script:avisos[0].clave })
Comp '   y con plazo de una semana, no de un dia' ($script:avisos.Count -ge 1 -and $script:avisos[0].cada -eq 10080) $(if ($script:avisos.Count) { $script:avisos[0].cada })
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'los reinicios se cuentan y se comparan con lo normal' -ForegroundColor Green
exit 0
