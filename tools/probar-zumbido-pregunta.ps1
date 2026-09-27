# UNA PREGUNTA NACE MUDA EN LAS MANOS (26/09, idea 42 de las 121).
#
# Cuando nace una pregunta, un zumbido corto y flojo: la SEGUNDA via del mando (regla 7). El
# mando NUNCA ha contestado una pregunta (0 "CONFIRMAR con el mando" en 17 dias) ni con la pista
# de texto puesta desde el 23/09. La puerta es HAY MANDO, no HAY JUEGO (en 17 dias solo 1
# pregunta nacio con juego delante). Y se MIDE: dos listas, con zumbido y sin el; si con 20
# muestras la mediana no baja, se apaga solo.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
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
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira ---
$script:relojMs = 100000
$sw = New-Object psobject
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojMs }
$DecisionMinIntentos = 20
$script:vibro = 0
# fake de Start-Vibracion QUE IMITA SU EFECTO EN LA GUARDA: la de verdad deja $script:vibraCola
# lleno, y de eso depende que no zumbe dos veces. Si aqui no lo hiciera, el caso 3 pasaria por
# el motivo equivocado.
function Start-Vibracion($patron, $fuerza = 0) { $script:vibro += 1; $script:vibraCola = @($patron); $script:vibraHasta = $sw.ElapsedMilliseconds + 6000 }
function Get-PistaMando($t) { return '' }
function Set-UI($e, $t = '', $ms = 0) { }   # fake: NO cambia $script:uiEstado (capsula apagada)
Invoke-Expression (Traer 'Test-ZumbidoSirve')
Invoke-Expression (Traer 'Get-MedianaMs')
# para los casos 1-5, sin historial: Get-ZumbidoTiempos vacio -> Test-ZumbidoSirve da $true
function Get-ZumbidoTiempos { return [pscustomobject]@{ con = @(); sin = @() } }

# el bloque del zumbido, sacado del archivo (no reescrito): del $script:pendiente.nace al cierre
$iZ = $fuente.IndexOf('$script:pendiente.nace = $sw.ElapsedMilliseconds')
$iT = $fuente.IndexOf('$script:pendiente.zumbo = $true', $iZ)
$iB = $fuente.IndexOf('}', $iT)
if ($iZ -lt 0 -or $iT -lt 0 -or $iB -lt 0) { Write-Host '  MAL  no encuentro el bloque del zumbido'; exit 1 }
$bloqueZ = $fuente.Substring($iZ, $iB - $iZ + 1)
$sbZ = [scriptblock]::Create($bloqueZ)
function Corre([string]$tipo, [bool]$mando, $cola, [int]$veces = 1) {
    $script:pendiente = @{ texto = ''; vence = 0; tipo = $tipo }
    $script:mandoHay = $mando
    $script:vibraCola = @($cola)
    $script:vibraHasta = 0
    $script:vibro = 0
    for ($k = 0; $k -lt $veces; $k++) { . $sbZ }
    return $script:vibro
}

Write-Host '  -- 1..5: cuando zumba y cuando no --'
Comp '1. sin mando no zumba' ((Corre '' $false @()) -eq 0) 'la puerta es HAY MANDO'
Comp '2. con mando y pregunta normal, zumba UNA vez' ((Corre '' $true @()) -eq 1) ''
Comp '3. y NO zumba en bucle (capsula apagada = cada vuelta)' ((Corre '' $true @() 10) -eq 1) 'la guarda de vibraCola lo para'
Comp '4. en una peligrosa no zumba' ((Corre 'peligrosa' $true @()) -eq 0) 'ahi no hay atajo de mando'
Comp '5. no pisa una vibracion ya sonando' ((Corre '' $true @(50)) -eq 0) ''

Write-Host ''
Write-Host '  -- 6..8: el tiempo se apunta, separado, con sus guardas --'
$script:invitado = $false
$ZumbidoTiemposJson = Join-Path ([IO.Path]::GetTempPath()) ('zt-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
$ZumbidoTiemposMax = 200
Invoke-Expression (Traer 'Get-ZumbidoTiempos')   # sobreescribe el fake: ahora la de verdad
Invoke-Expression (Traer 'Add-ZumbidoTiempo')
function Reset { if (Test-Path -LiteralPath $ZumbidoTiemposJson) { Remove-Item -LiteralPath $ZumbidoTiemposJson -Force } }
Reset
[void](Add-ZumbidoTiempo 4000 $true)
[void](Add-ZumbidoTiempo 9000 $false)
$t = Get-ZumbidoTiempos
Comp '6. con zumbido y sin el van en listas distintas' ((@($t.con).Count -eq 1) -and ([int]@($t.con)[0] -eq 4000) -and (@($t.sin).Count -eq 1) -and ([int]@($t.sin)[0] -eq 9000)) ''
$script:invitado = $true
[void](Add-ZumbidoTiempo 5000 $true)
$script:invitado = $false
Comp '7. en modo invitado no se apunta' (@((Get-ZumbidoTiempos).con).Count -eq 1) 'sigue habiendo 1'
Reset
$ZumbidoTiemposMax = 5
1..8 | ForEach-Object { [void](Add-ZumbidoTiempo (1000 + $_) $true) }
$t8 = Get-ZumbidoTiempos
Comp '8. el tope se respeta y quedan los ultimos' ((@($t8.con).Count -eq 5) -and ([int]@($t8.con)[0] -eq 1004)) "$(@($t8.con).Count), primera $(@($t8.con)[0])"
$ZumbidoTiemposMax = 200
Reset

Write-Host ''
Write-Host '  -- 9, 10: se apaga solo si no baja la mediana --'
# con=19 PEOR que sin: con liston 20 gana el "sin historial" ($true); si alguien baja el liston a
# 10, con 19 ya decidiria y daria $false. Asi este caso distingue 20 de 10.
Comp '9. con 19 muestras NO se apaga aunque sean peores (sin historial)' (Test-ZumbidoSirve (@(1..19 | ForEach-Object { 7000 })) (@(1..20 | ForEach-Object { 6000 })) 20) 'el liston es 20, no 10'
$con20 = @(1..20 | ForEach-Object { 7000 })
$sinT = @(1..20 | ForEach-Object { 6000 }); $sinT += 40000   # el 40000 tuerce la MEDIA, no la mediana
Comp '10. con 20 y sin mejora, se apaga (mediana, no media)' (-not (Test-ZumbidoSirve $con20 $sinT 20)) 'mediana con 7000 no < 6000'
Comp '   y con mejora, sigue' (Test-ZumbidoSirve (@(1..20 | ForEach-Object { 5000 })) $sinT 20) '5000 < 6000'

Write-Host ''
Write-Host '  -- 11, 12: el apagado se anota y la pista de texto sigue --'
Comp '11. el apagado se dice y se cuenta' (($fuente -match 'ZUMBIDO DE PREGUNTA: apagado solo') -and ($fuente -match "Add-Estadistica 'auto-deshecho' 'zumbido-pregunta'")) 'un ajuste que no se cuenta no ha pasado'
Comp '12. la linea de la pista de texto sigue intacta' ($fuente -match "Set-UI 'confirmando' \(\`$script:uiTexto \+ \(Get-PistaMando") 'el zumbido es la SEGUNDA via, no sustituye la pista'
Comp '   y el patron es el corto y flojo ya elegido (70,90,70)' ($bloqueZ -match 'Start-Vibracion @\(70, 90, 70\) 16000') 'el mismo de "te he oido en juego", no uno nuevo'

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'la pregunta zumba en las manos y se mide si sirve' -ForegroundColor Green
exit 0
