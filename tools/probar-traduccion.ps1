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

# --- LA MAS PARECIDA, NO LA PRIMERA (17/09) ---
# Find-Traduccion devolvia la primera clave que entrara en el tope, asi que con dos
# parecidas el resultado dependia del ORDEN DEL HASHTABLE: el mismo dictado y los mismos
# datos podian dar respuestas distintas en dos ejecuciones. Por eso el hallazgo decia "no
# se reproduce". Hoy no puede pasar (hay 2 traducciones guardadas y no se parecen en nada),
# asi que esto no rescata ninguna orden: deja el resultado quieto y predecible.
#
# El caso que de verdad sujeta el arreglo es el ultimo: dos ordenes de guardado distintos
# tienen que dar LA MISMA respuesta.
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'Find-Traduccion')
$script:tradFalsas = @{}
function Get-Traducciones { return $script:tradFalsas }

Write-Host "  -- con dos parecidas, gana la mas parecida --"
# El par esta MEDIDO, no elegido a ojo: "sube el brillu" queda a distancia 1 de
# "sube el brillo" (tope 2) y a 2 de "sube el brillos" (tope 3), asi que las DOS entran
# y compiten. El primer par que probe -"sube el brillo ya"- quedaba a 4 con tope 3: no
# entraba, no competia, y la prueba habria pasado igual con el codigo viejo.
# OJO: Dictionary y no [ordered]@{}. Lo real es un hashtable y Find-Traduccion llama a
# ContainsKey, que un OrderedDictionary NO tiene: el doble se rompia antes de probar nada.
# Este mantiene el orden de insercion Y el mismo contrato.
$script:tradFalsas = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$script:tradFalsas.Add('sube el brillos', 'CON S')
$script:tradFalsas.Add('sube el brillo', 'SIN S')
Comp 'elige la de distancia 1, no la que este antes' ((Find-Traduccion 'sube el brillu') -eq 'SIN S') ("-> " + (Find-Traduccion 'sube el brillu'))
$script:tradFalsas = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$script:tradFalsas.Add('sube el brillo', 'SIN S')
$script:tradFalsas.Add('sube el brillos', 'CON S')
Comp 'y con el otro orden, LA MISMA respuesta' ((Find-Traduccion 'sube el brillu') -eq 'SIN S') ("-> " + (Find-Traduccion 'sube el brillu'))

Write-Host "  -- y lo de siempre sigue igual --"
Comp 'la exacta gana a cualquier parecida' ((Find-Traduccion 'sube el brillos') -eq 'CON S') ''
Comp 'lo que no se parece a nada no traduce' ($null -eq (Find-Traduccion 'abre steam')) ''
$script:tradFalsas = @{}
Comp 'sin traducciones guardadas, nada' ($null -eq (Find-Traduccion 'sube el brillu')) ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
