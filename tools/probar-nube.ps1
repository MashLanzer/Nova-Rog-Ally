# LA SEGUNDA OPINION DE LA NUBE (16/09): cuando SI vale lo que oye Gemini y cuando no.
#
# Medido con las 344 grabaciones (214 leidas + 130 de uso real): gemini-3.5-flash-lite
# entiende mas ordenes que el camino local, pero tiene dos vicios propios que aqui se
# cortan: recita los nombres que lleve el prompt y a veces mete un juego que no dijiste.
# Y siempre, siempre, con tope de espera: 5 de cada 20 peticiones pasan de 3 s.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$RutaWakeVosk = Join-Path $raiz 'wake_vosk.py'
$script:frasesEjemplo = $null
$script:Juegos = @(@{ nombre = 'Hollow Knight Silksong' }, @{ nombre = 'It Takes Two' })

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'Get-FrasesEjemplo')
Invoke-Expression (Traer 'Test-EsFraseEjemplo')
Invoke-Expression (Traer 'Test-NombreInventado')
Invoke-Expression (Traer 'Test-NubeSirve')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- se acepta --"
Comp 'una orden clara que el oido local no saco' (Test-NubeSirve 'cierra steam' 'sierra este' $true) ''
Comp 'con punto final y mayusculas' (Test-NubeSirve 'Cierra la calculadora y cierra Steam.' 'cierra la calle' $true) ''

Write-Host "  -- no se acepta --"
Comp 'vacio' (-not (Test-NubeSirve '' 'cierra steam' $false)) ''
Comp 'si no es una orden que Nova sepa hacer' (-not (Test-NubeSirve 'pues no se que decirte' 'cierra steam' $false)) ''
Comp 'la frase de ejemplo de Whisper (el eco)' (-not (Test-NubeSirve 'Que hora es' 'cierra steam' $true)) ''
Comp 'un juego que no habias nombrado' (-not (Test-NubeSirve 'abre Hollow Knight Silksong' 'busca el clima' $true)) ''
Comp 'un parrafo entero: eso no es una orden' (-not (Test-NubeSirve ('palabra ' * 40) 'cierra steam' $true)) ''
Comp 'el juego que SI nombraste, vale' (Test-NubeSirve 'abre Hollow Knight Silksong' 'abre hollow knight' $true) ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
