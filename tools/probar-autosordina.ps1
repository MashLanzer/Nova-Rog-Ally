# Prueba la autosordina SACANDO LA FUNCION DEL ARCHIVO REAL. Todo lo que toca el
# mundo exterior (hablar, pausar la escucha, el popup) se simula.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'Add-RuidoRacha')

# --- el mundo de mentira ---
$AutoSordinaOn = $true
$AutoSordinaRachas = 3
$AutoSordinaVentanaMs = 5 * 60000
$AutoSordinaMs = 10 * 60000
$script:pausaHasta = 0
$script:rachaRuido = New-Object System.Collections.ArrayList
$script:temporizadores = New-Object System.Collections.ArrayList
$script:reloj = 0
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$script:dicho = @()
function Log($m) { }
function Show-Popup($t, $e) { }
function Say($t) { $script:dicho += $t }
function Pausar-Escucha($ms) { $script:pausaHasta = $script:reloj + $ms }

function Estado { "pausada=$([bool]($script:pausaHasta -gt 0)) racha=$($script:rachaRuido.Count) avisos=$($script:dicho.Count)" }

Write-Host "--- 1) dos descartes seguidos: NO debe callarse ---"
$script:reloj = 1000;  Add-RuidoRacha
$script:reloj = 60000; Add-RuidoRacha
"   $(Estado)   (esperado: pausada=False racha=2)"

Write-Host "--- 2) el tercero dentro de la ventana: se calla ---"
$script:reloj = 120000; Add-RuidoRacha
"   $(Estado)   (esperado: pausada=True racha=0 avisos=1)"
if ($script:dicho.Count) { "   dijo: $($script:dicho[0])" }
"   temporizador de vuelta encolado: $($script:temporizadores.Count)"

Write-Host "--- 3) mientras esta callada, no vuelve a avisar ---"
$script:reloj = 130000; Add-RuidoRacha
"   $(Estado)   (esperado: avisos=1, sigue en 1)"

Write-Host "--- 4) descartes MUY separados en el tiempo: nunca se calla ---"
$script:pausaHasta = 0
$script:rachaRuido.Clear()
$script:dicho = @()
foreach ($t in 0, 400000, 800000, 1200000, 1600000) { $script:reloj = $t; Add-RuidoRacha }
"   $(Estado)   (esperado: pausada=False, avisos=0)"

Write-Host ""
$fallos = 0
if ($script:dicho.Count -ne 0) { $fallos++; Write-Host "MAL: se callo con descartes espaciados" }
Write-Host $(if ($fallos) { "$fallos casos MAL" } else { "todo correcto" })
