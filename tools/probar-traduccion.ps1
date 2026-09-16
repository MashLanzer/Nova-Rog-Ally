# QUE LA TRADUCCION NO DE LA VUELTA A LO QUE PEDISTE (16/09).
# El 15/09 "cierra Google" volvio de la API como "Abre Google" y se abrio (tres veces
# seguidas), y de "mi ubicacion es Tampa, busca el clima" salio "abre Hollow Knight",
# un juego que nadie habia nombrado. Aqui se comprueba que esas dos se rechazan y
# -igual de importante- que una traduccion normal NO se rechaza.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txt = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
if ($txt -match '(?ms)^\$VERBOS_OPUESTOS = @\{.*?^\}') { Invoke-Expression $Matches[0] } else { throw 'no encuentro VERBOS_OPUESTOS' }
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Test-TraduccionOpuesta')
Invoke-Expression (Traer 'Test-NombreInventado')

# la biblioteca de mentira, con un nombre largo y otro corto
$script:Juegos = @(
    @{ nombre = 'Hollow Knight Silksong' }, @{ nombre = 'It Takes Two' }, @{ nombre = 'Peak' }
)

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- le da la vuelta a lo pedido: se rechaza --"
Comp 'cierra google -> Abre Google' (Test-TraduccionOpuesta 'cierra google' 'Abre Google') ''
Comp 'apaga el bluetooth -> enciende el bluetooth' (Test-TraduccionOpuesta 'apaga el bluetooth' 'enciende el bluetooth') ''
Comp 'sube el volumen -> baja el volumen' (Test-TraduccionOpuesta 'sube el volumen' 'baja el volumen') ''
Comp 'desactiva el modo juego -> activa el modo juego' (Test-TraduccionOpuesta 'desactiva el modo juego' 'activa el modo juego') ''

Write-Host "  -- traducciones normales: NO se rechazan --"
Comp 'cierra google -> cierra edge' (-not (Test-TraduccionOpuesta 'cierra google' 'cierra edge')) ''
Comp 'sube el volumen -> sube el brillo' (-not (Test-TraduccionOpuesta 'sube el volumen' 'sube el brillo')) ''
Comp 'que espacio queda -> espacio libre (sin verbo)' (-not (Test-TraduccionOpuesta 'que espacio me queda' 'espacio libre')) ''
Comp 'abre steam y cierra discord -> igual' (-not (Test-TraduccionOpuesta 'abre steam y cierra discord' 'abre steam y cierra discord')) ''
Comp 'vacios' (-not (Test-TraduccionOpuesta '' 'abre steam') -and -not (Test-TraduccionOpuesta 'abre steam' '')) ''

Write-Host "  -- se inventa un juego que no dijiste: se rechaza --"
Comp 'busca el clima -> abre Hollow Knight Silksong' (Test-NombreInventado 'mi ubicacion es tampa busca el clima' 'abre Hollow Knight Silksong') ''
Comp 'lo que SI nombraste, vale' (-not (Test-NombreInventado 'abre hollow knight silksong' 'abre Hollow Knight Silksong')) ''
# nadie dice el titulo entero: completarlo es lo que hay que hacer, no un invento (16/09)
Comp 'el titulo dicho a medias tambien vale' (-not (Test-NombreInventado 'abre hollow knight' 'abre Hollow Knight Silksong')) ''
Comp 'pero con una sola palabra suelta del titulo, no' (Test-NombreInventado 'abre el knight' 'abre Hollow Knight Silksong') ''
Comp 'un nombre corto no dispara nada' (-not (Test-NombreInventado 'sube el volumen' 'abre Peak')) ''
Comp 'sin juegos en la biblioteca, no falla' (-not (Test-NombreInventado 'hola' 'abre lo que sea')) ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
