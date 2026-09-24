# Prueba la autosordina SACANDO LA FUNCION DEL ARCHIVO REAL. Todo lo que toca el
# mundo exterior (hablar, pausar la escucha, el popup) se simula.
#
# OJO, ESTA PRUEBA MENTIA (17/09, auditoria de robustez). Los casos 1, 2 y 3 IMPRIMIAN
# el estado con el valor esperado al lado ("esperado: pausada=True racha=0 avisos=1")
# pero no comparaban nada: eran cadenas sueltas. La unica comprobacion de verdad era la
# del caso 4, y el script NO tenia `exit 1`, asi que ni esa podia hacer fallar el banco
# (probar-todo.ps1 mira $LASTEXITCODE). Era decorativa entera.
# POR DONDE ESTE EL BANCO, NO POR UNA RUTA ESCRITA A MANO (22/09). Aqui habia la ruta
# completa a fuego: en una copia del repo en otra carpeta este banco seguiria midiendo el
# assistant.ps1 de SIEMPRE -verde sobre codigo que no es el que se acaba de tocar- y si la
# carpeta se renombrara se caeria entero por algo que no tiene que ver con lo que prueba.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
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

$fallos = 0
function Comp([string]$etiqueta, [bool]$ok, [string]$detalle) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Estado { "pausada=$([bool]($script:pausaHasta -gt 0)) racha=$($script:rachaRuido.Count) avisos=$($script:dicho.Count)" }

Write-Host '  -- dos descartes seguidos: NO debe callarse --'
$script:reloj = 1000;  Add-RuidoRacha
$script:reloj = 60000; Add-RuidoRacha
Comp 'con dos ruidos sigue escuchando' ($script:pausaHasta -eq 0) (Estado)
Comp 'y lleva la cuenta de los dos' ($script:rachaRuido.Count -eq 2) (Estado)
Comp 'sin decir nada todavia' ($script:dicho.Count -eq 0) (Estado)

Write-Host '  -- el tercero dentro de la ventana: se calla --'
$script:reloj = 120000; Add-RuidoRacha
Comp 'al tercero se calla' ($script:pausaHasta -gt 0) (Estado)
Comp 'y lo avisa una vez' ($script:dicho.Count -eq 1) $(if ($script:dicho.Count) { $script:dicho[0] } else { '(no dijo nada)' })
Comp 'la racha se reinicia' ($script:rachaRuido.Count -eq 0) (Estado)
Comp 'y deja encolada la vuelta' ($script:temporizadores.Count -eq 1) "temporizadores=$($script:temporizadores.Count)"

Write-Host '  -- mientras esta callada, no vuelve a avisar --'
$script:reloj = 130000; Add-RuidoRacha
Comp 'no repite el aviso' ($script:dicho.Count -eq 1) (Estado)

Write-Host '  -- descartes MUY separados: nunca se calla --'
$script:pausaHasta = 0
$script:rachaRuido.Clear()
$script:dicho = @()
foreach ($t in 0, 400000, 800000, 1200000, 1600000) { $script:reloj = $t; Add-RuidoRacha }
Comp 'con ruidos espaciados sigue escuchando' ($script:pausaHasta -eq 0) (Estado)
Comp 'y no dice nada' ($script:dicho.Count -eq 0) (Estado)

Write-Host ''
if ($fallos -gt 0) { Write-Host "$fallos casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
