# LA VOZ DE LO QUE YA ESTA ESCRITO Y ESPERANDO SU TURNO (26/09, idea 59 de las 121).
#
# Los avisos del entorno se aparcan con el texto YA escrito esperando un buen momento, y al
# soltarse pagaban ~974 ms de red delante de braya (p50 902, p90 1.245, max 3.636 sobre 348
# medidas) frente a 5 ms si ya estaba hecha. Ahora, al aparcarse, Nova manda ese texto al worker
# de voz preparada (prioridad baja, cache por md5). Solo cuando Add-AvisoEspera devuelve true (no
# en cada vuelta), solo los 'medio' que SI se dicen, y nunca con un juego delante.
#
# Se EJECUTA Send-AvisoEntorno de verdad (AST) con Send-PrepVoz doblado para contar sus llamadas.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
$mal = 0
function Comp($etq, $ok, $det = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira: se controlan las guardas para llevar el aviso por cada camino ---
$script:preparadas = New-Object System.Collections.ArrayList
function Send-PrepVoz([string]$texto, [string]$emo = '') { [void]$script:preparadas.Add($texto) }
$script:aplazable = $true
function Test-AvisoAplazable($c, $n = 'medio', $a = (Get-Date)) { return $script:aplazable }
$script:addEspera = $true
function Add-AvisoEspera($c, $t, $n, $cada, $a = (Get-Date)) { return $script:addEspera }
function Get-NadieMin($a = (Get-Date)) { return 45 }
function Test-PuedoAvisar($c, $n = 'medio', $cada = 60) { return $true }
function Save-EntornoVistos { }
function Log($m) { }
function Add-Estadistica($a, $b = '') { }
function Show-Popup($t, $e = 'hablando') { }
function Send-AvisoCola($y = $false) { }
$script:entornoVistos = @{}
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$script:entornoAvisos = New-Object System.Collections.ArrayList
# LA LISTA DE AVISOS EN OBSERVACION (27/09, idea 91): antes era UNA variable a $null y ahora es
# una lista a la que Send-AvisoEntorno le hace .Add(). Sin este doble el banco revienta con "no
# se puede llamar a un metodo en una expresion con valor NULL".
$script:avisosMirar = New-Object System.Collections.ArrayList
$AvisosMirarMax = 4
$script:ultimaRespuesta = ''
$script:avisoMirar = $null
$script:uiMia = $false
$AvisoReaccionVentanaMs = 180000
$sw = [pscustomobject]@{ ElapsedMilliseconds = 100000 }
# Get-NivelAviso y Get-ReaccionesAviso entran desde el 1/10/2026 (idea 9 de las 20 nuevas):
# Send-AvisoEntorno decide el nivel en su PRIMERA linea, asi que sin ellas este banco revienta con un
# CommandNotFoundException y todo sale a cero. Se traen de verdad y no dobladas: doblar justo la pieza
# que decide el nivel seria la manera 15 de los bancos que mienten.
$AvisoReaccionMin = 8; $AvisoReaccionCeroMin = 5; $AvisoMudoCeros = 8; $AvisoEsperaTope = 6
Invoke-Expression (Traer 'Get-ReaccionesAviso')
Invoke-Expression (Traer 'Get-NivelAviso')
Invoke-Expression (Traer 'Send-AvisoEntorno')

Write-Host ''
Write-Host '-- 1. al aparcarse, se prepara la voz con el texto ya escrito --'
$script:aplazable = $true; $script:addEspera = $true; $script:preparadas.Clear()
$r = Send-AvisoEntorno 'gmail-lleno' 'Tienes el correo casi lleno.' 'medio' 10080
Comp '1. aparcado -> Send-PrepVoz con ese texto' ((-not $r) -and $script:preparadas.Count -eq 1 -and $script:preparadas[0] -eq 'Tienes el correo casi lleno.') "prep=$($script:preparadas.Count)"

Write-Host ''
Write-Host '-- 2. no en cada vuelta: si Add-AvisoEspera ya lo tenia, NO se re-prepara --'
$script:aplazable = $true; $script:addEspera = $false; $script:preparadas.Clear()
$r = Send-AvisoEntorno 'gmail-lleno' 'Tienes el correo casi lleno.' 'medio' 10080
Comp '2. ya aparcado (Add-AvisoEspera false) -> ni una preparacion' ((-not $r) -and $script:preparadas.Count -eq 0) "prep=$($script:preparadas.Count)"

Write-Host ''
Write-Host '-- 3. si el aviso se dice AHORA (no se aparca), no hace falta prepararlo --'
$script:aplazable = $false; $script:addEspera = $true; $script:preparadas.Clear()
$r = Send-AvisoEntorno 'dock' 'Pantalla conectada.' 'medio' 60
Comp '3. camino de decir ahora -> no pasa por la preparacion aparcada' ($script:preparadas.Count -eq 0) "prep=$($script:preparadas.Count) (lo dice al momento)"

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'la voz del aviso aparcado se prepara sola' -ForegroundColor Green
exit 0
