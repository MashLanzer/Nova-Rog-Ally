# Crear y borrar modos por voz, contra un commands.json de mentira.
# Lo que de verdad puede romperse aquí es escribir el JSON (si se escribe mal,
# el asistente se queda sin apps ni sitios al siguiente arranque) y el patrón
# de "crea el modo X: ...", que tiene que quedarse con el nombre Y con todas
# las órdenes, sin que la "y" de la frase le corte la cabeza.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Log($m) { }
function Test-Prop($obj, $n) {
    if (-not $obj) { return $false }
    return [bool]($obj.PSObject.Properties.Name -contains $n)
}
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Add-Perfil')
Invoke-Expression (Traer 'Write-Atomico')
Invoke-Expression (Traer 'Remove-Perfil')

# un commands.json de mentira, copia del real para que tenga la misma forma
$tmp = Join-Path $env:TEMP ("modos-" + [guid]::NewGuid().ToString('N') + '.json')
Copy-Item (Join-Path $raiz 'commands.json') $tmp
$cmdsPath = $tmp
$script:cmds = $null

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-36} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

$appsAntes = @((Get-Content -Raw $tmp | ConvertFrom-Json).apps.PSObject.Properties.Name).Count

$puso = Add-Perfil 'streaming' @('cierra discord', 'pon el volumen al 30')
$j = Get-Content -Raw $tmp | ConvertFrom-Json
Comp 'se crea el modo' ($puso -and (Test-Prop $j.perfiles 'streaming')) ''
Comp 'con sus dos ordenes' (@($j.perfiles.streaming).Count -eq 2) ("[" + (@($j.perfiles.streaming) -join ' | ') + "]")
Comp 'y no se lleva por delante el resto' (@($j.apps.PSObject.Properties.Name).Count -eq $appsAntes) "$appsAntes apps siguen"
Comp 'los modos de siempre siguen' (Test-Prop $j.perfiles 'juego') ''

# crear con el mismo nombre lo SUSTITUYE, no lo duplica
$null = Add-Perfil 'streaming' @('pon el brillo al 50')
$j = Get-Content -Raw $tmp | ConvertFrom-Json
Comp 'crearlo otra vez lo sustituye' (@($j.perfiles.streaming).Count -eq 1) ''

Comp 'borrar uno que no existe dice que no' (-not (Remove-Perfil 'nomeinventes')) ''
$quito = Remove-Perfil 'streaming'
$j = Get-Content -Raw $tmp | ConvertFrom-Json
Comp 'se borra' ($quito -and -not (Test-Prop $j.perfiles 'streaming')) ''
Comp 'sin tocar los demas' (Test-Prop $j.perfiles 'juego') ''
Comp 'un modo sin ordenes no se guarda' (-not (Add-Perfil 'vacio' @())) ''

# --- el patron de crear, el MISMO del archivo real ---
# se saca del árbol, no a golpe de recortar texto: así es EL patrón, el mismo
# que corre de verdad, y no una copia que puede quedarse vieja
# LA CONDICION ENTERA, NO LA PRIMERA CADENA QUE APAREZCA (24/09). El patron de crear son
# ahora DOS alternativas unidas con -or: la de los nombres de dos palabras -que exige dos
# puntos o coma- y la de siempre. Este banco cogia la primera cadena del arbol, o sea solo la
# primera mitad, y daba MAL en "crea el modo noche pon el brillo al 10", que la segunda mitad
# resuelve perfectamente. Peor aun: al no casar, $Matches se quedaba con lo del caso anterior
# y el banco decia nombre='streaming' en un caso que iba de 'noche'.
$condCrear = $null
$ifCrear = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.IfStatementAst] -and
    $x.Clauses[0].Item1.Extent.Text -like '*guardame*modo*' -and
    $x.Extent.Text -like '*Add-Perfil*' }, $true)
if ($ifCrear) { $condCrear = $ifCrear.Clauses[0].Item1.Extent.Text }
if (-not $condCrear) {
    Comp 'encuentro el patron de crear en el archivo' $false 'no esta'
} else {
    $casos = @(
        @('crea el modo streaming: cierra discord y pon el volumen al 30', 'streaming', 'cierra discord y pon el volumen al 30'),
        @('crea el modo noche pon el brillo al 10', 'noche', 'pon el brillo al 10'),
        @('hazme un modo lectura con pon el brillo al 40', 'lectura', 'pon el brillo al 40'),
        @('crea el modo estamos dos: abre it takes two y abre discord', 'estamos dos', 'abre it takes two y abre discord')
    )
    foreach ($c in $casos) {
        $text = $c[0]
        $Matches = $null
        $casa = [bool](Invoke-Expression $condCrear)
        $ok = $casa -and ($Matches[1] -eq $c[1]) -and ($Matches[2].Trim() -eq $c[2])
        Comp ("lo parte bien: " + $c[1]) $ok $(if ($ok) { '' } elseif ($casa) { "nombre='$($Matches[1])' cuerpo='$($Matches[2])'" } else { 'no casa con ninguna de las dos mitades' })
    }
    # y que NO se coma una orden normal
    $text = 'modo juego'; $Matches = $null
    Comp 'no se come "modo juego"' (-not [bool](Invoke-Expression $condCrear)) ''
}

Remove-Item $tmp -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
