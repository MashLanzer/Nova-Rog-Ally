# "No era eso" contra el ruido: la lista de frases que ya te molestaron una vez.
# Lo que importa de esto es que se cure sola. Una frase vetada para siempre por
# una vez que cambiaste de idea sería peor que el problema que arregla, así que
# se comprueba que decir "sí" la retire.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Log($m) { }
$MemoriaDir = Join-Path $env:TEMP ("rech-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null
$RechazosPath = Join-Path $MemoriaDir 'rechazos.json'
$script:rechazos = $null

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Rechazos')
Invoke-Expression (Traer 'Save-Rechazos')
Invoke-Expression (Traer 'Write-Atomico')
Invoke-Expression (Traer 'Add-Rechazo')
Invoke-Expression (Traer 'Remove-Rechazo')
Invoke-Expression (Traer 'Test-Rechazada')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Comp 'al principio no hay nada' (-not (Test-Rechazada 'abre steam')) ''
Comp 'se apunta una frase' (Add-Rechazo 'Abre Steam') ''
Comp 'y se reconoce igual sin tildes ni mayusculas' (Test-Rechazada 'abre steam') ''
Comp 'otra frase no queda vetada' (-not (Test-Rechazada 'abre spotify')) ''
Comp 'una palabra suelta no se apunta' (-not (Add-Rechazo 'steam')) 'vetaria media lista'

# se cuenta cuantas veces
$null = Add-Rechazo 'abre steam'
Comp 'lleva la cuenta' ((Get-Rechazos)['abre steam'] -eq 2) ("van " + (Get-Rechazos)['abre steam'])

# sobrevive a releer el archivo (es lo que pasa al reiniciar)
$script:rechazos = $null
Comp 'sobrevive al reinicio' (Test-Rechazada 'abre steam') ''

# y se cura: decir que si la retira
Comp 'decir que si la retira' (Remove-Rechazo 'abre steam') ''
Comp 'y ya no pregunta mas' (-not (Test-Rechazada 'abre steam')) ''
$script:rechazos = $null
Comp 'tambien despues de reiniciar' (-not (Test-Rechazada 'abre steam')) ''
Comp 'retirar una que no esta dice que no' (-not (Remove-Rechazo 'abre lo que sea')) ''

Remove-Item $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
