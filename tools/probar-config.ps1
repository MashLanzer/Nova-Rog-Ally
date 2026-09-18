# QUE UN config.json MAL ESCRITO NO MATE A NOVA (17/09).
#
# Casi todas las lecturas de configuracion van envueltas en [int] o [double], y
# [int]'mucho' LANZA. Con $ErrorActionPreference='Stop' y siete de esas lecturas ANTES de
# que exista Log, una letra de mas en config.json dejaba a Nova sin arrancar y sin decir
# por que. Desde hoy Nova ademas se escribe sola en ese archivo, asi que esto importa mas
# que ayer.
#
# Lo que se comprueba no es solo que no reviente: es que NO CAMBIE ningun valor bueno. El
# arreglo facil -forzar el tipo del default- convertiria una escala de 1.25 en 1.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Get-Cfg')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
# devuelve $true si la lectura NO revienta al convertirla, como hace el arranque de verdad
function Sobrevive([scriptblock]$b) {
    try { [void](& $b); return $true } catch { return $false }
}

# --- un config.json con TODO lo que una persona escribe mal ---
$cfg = @'
{
  "input":   { "holdMs": "mucho", "autoSubmitMs": "2500", "dictado": "whisper" },
  "ui":      { "escala": 1.25, "popupMs": 8000 },
  "voz":     { "activada": "no", "saludo": "si", "motor": "online" },
  "escucha": { "confianzaMinima": "cero coma cinco", "soloYo": true, "ganancia": "auto" },
  "logging": { "keepLogs": true }
}
'@ | ConvertFrom-Json

Write-Host '  -- lo mal escrito no mata el arranque --'
Comp 'un numero escrito con letras no revienta' (Sobrevive { [int](Get-Cfg 'input' 'holdMs' 1100) }) ''
Comp 'y devuelve el valor de siempre' ([int](Get-Cfg 'input' 'holdMs' 1100) -eq 1100) ("-> " + [int](Get-Cfg 'input' 'holdMs' 1100))
Comp 'un decimal escrito con letras tampoco' (Sobrevive { [double](Get-Cfg 'escucha' 'confianzaMinima' 0.65) }) ''
Comp 'y se queda en el de siempre' ([double](Get-Cfg 'escucha' 'confianzaMinima' 0.65) -eq 0.65) ''
Comp 'un si/no donde va un numero tampoco' (Sobrevive { [int](Get-Cfg 'logging' 'keepLogs' 3) }) ''
Comp 'y usa el de siempre' ([int](Get-Cfg 'logging' 'keepLogs' 3) -eq 3) ("-> " + [int](Get-Cfg 'logging' 'keepLogs' 3))

Write-Host '  -- pero NO estropea nada de lo que esta bien (lo importante) --'
Comp 'una escala de 1.25 sigue siendo 1.25, no 1' ([double](Get-Cfg 'ui' 'escala' 1.0) -eq 1.25) ("-> " + (Get-Cfg 'ui' 'escala' 1.0))
Comp 'un numero normal pasa igual' ([int](Get-Cfg 'ui' 'popupMs' 8000) -eq 8000) ''
Comp 'un numero escrito entre comillas sigue valiendo' ([int](Get-Cfg 'input' 'autoSubmitMs' 9999) -eq 2500) ("-> " + [int](Get-Cfg 'input' 'autoSubmitMs' 9999))
Comp 'un texto pasa tal cual' ((Get-Cfg 'input' 'dictado' 'windows') -eq 'whisper') ''
Comp 'un texto donde el default es texto, aunque parezca otra cosa' ((Get-Cfg 'escucha' 'ganancia' 'auto') -eq 'auto') ''
Comp 'un si/no de verdad se respeta' ((Get-Cfg 'escucha' 'soloYo' $false) -eq $true) ''

Write-Host '  -- y el fallo que no avisaba: "no" que se leia como SI --'
# [bool]'no' devuelve True. Esto no reventaba: se tragaba lo contrario de lo que pedias.
Comp '"no" se entiende como no' ((Get-Cfg 'voz' 'activada' $true) -eq $false) ("-> " + (Get-Cfg 'voz' 'activada' $true))
Comp '"si" se entiende como si' ((Get-Cfg 'voz' 'saludo' $false) -eq $true) ("-> " + (Get-Cfg 'voz' 'saludo' $false))
Comp 'y un texto que no es ni si ni no usa el de siempre' ((Get-Cfg 'voz' 'motor' $true) -eq $true) ''

Write-Host '  -- lo que falta, como siempre --'
Comp 'una seccion que no existe da el de siempre' ((Get-Cfg 'nada' 'nada' 'pordefecto') -eq 'pordefecto') ''
Comp 'una clave que no existe tambien' ((Get-Cfg 'input' 'noexiste' 42) -eq 42) ''

# --- y sin config.json, que es el caso de una instalacion nueva ---
$cfg = $null
Comp 'sin config.json entero, todo por defecto' ((Get-Cfg 'input' 'holdMs' 1100) -eq 1100) ''
Comp 'y no revienta' (Sobrevive { [int](Get-Cfg 'input' 'holdMs' 1100) }) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
