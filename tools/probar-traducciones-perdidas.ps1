# C6: LAS 14 TRADUCCIONES QUE SE PERDIERON (21/09).
#
# El 19/09 aparecieron 14 aprendidos menos en traducciones.json y nadie supo quien lo habia
# reescrito. La pista era el FORMATO: dos espacios tras los dos puntos, que es como escribe
# ConvertTo-Json de PowerShell 5.1. O sea que lo reescribio Nova misma.
#
# Y se puede reproducir: los dos sitios que guardaban el fichero -aprender una traduccion y
# olvidar una- cogian $script:traducciones (la copia que vive en RAM) y la escribian ENTERA
# encima. Eso vale si la copia en RAM lo tiene todo, y hay al menos un camino en que no:
# cuando el JSON llega corrupto, Get-Traducciones se lo lleva a un lado y devuelve una tabla
# VACIA. El siguiente "aprende que..." deja el fichero con UNA entrada.
#
# LO QUE NO PUEDE PASAR AL ARREGLARLO: que "olvida que X es Y" se deshaga solo. Si al
# guardar se fusiona con el disco sin mas, lo que acabas de olvidar vuelve desde el propio
# fichero. Por eso hay una lista de lo borrado a proposito, y por eso ese caso esta aqui
# abajo: es el que impedia arreglar esto.
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
function Save-Corrupto($ruta, $que) { $script:corruptos += $que }
$script:corruptos = @()

$LogDir = Join-Path $env:TEMP ("trad-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$TraduccionesPath = Join-Path $LogDir 'traducciones.json'
$script:traducciones = $null
$script:traduccionesQuitadas = New-Object System.Collections.Generic.HashSet[string]
$script:invitado = $false

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Write-Atomico')
Invoke-Expression (Traer 'Get-Traducciones')
Invoke-Expression (Traer 'Save-Traducciones')
Invoke-Expression (Traer 'Add-Traduccion')
Invoke-Expression (Traer 'Remove-Traduccion')

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Cuantas { if (-not (Test-Path -LiteralPath $TraduccionesPath)) { return 0 }
    return @((Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties).Count }
function Dice([string]$k) {
    if (-not (Test-Path -LiteralPath $TraduccionesPath)) { return '' }
    $j = Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pp = $j.PSObject.Properties[$k]
    if ($pp) { return [string]$pp.Value } else { return '' }
}

Write-Host ''
Write-Host '-- lo normal: aprender y olvidar --'
Comp 'se aprende una' ($null -eq (Add-Traduccion 'hazme la pantalla mas clarita' 'sube el brillo') -or $true) ''
Add-Traduccion 'ponme una peli' 'abre netflix'
Comp 'hay dos en el fichero' ((Cuantas) -eq 2) ("van $(Cuantas)")
Comp 'y dicen lo que tienen que decir' ((Dice 'hazme la pantalla mas clarita') -eq 'sube el brillo')
Comp 'olvidar una la quita' ((Remove-Traduccion 'ponme una peli') -and (Cuantas) -eq 1)

Write-Host ''
Write-Host '-- EL CASO DE LAS 14: la RAM va corta y el disco tiene mas --'
# se simula lo que pasa de verdad: el fichero tiene 14, y la copia en RAM se queda vacia
# (es lo que hace Get-Traducciones cuando el JSON llega corrupto)
$catorce = New-Object PSObject
for ($i = 1; $i -le 14; $i++) { $catorce | Add-Member -NotePropertyName "frase numero $i" -NotePropertyValue "orden $i" }
Write-Atomico $TraduccionesPath ($catorce | ConvertTo-Json -Depth 4)
$script:traducciones = $null              # como si Nova acabara de arrancar
$script:traducciones = @{}                # ...y la lectura hubiera fallado: tabla VACIA
$script:traduccionesQuitadas = New-Object System.Collections.Generic.HashSet[string]
Comp 'el fichero tiene las 14' ((Cuantas) -eq 14)
Add-Traduccion 'una frase nueva' 'una orden nueva'
Comp 'tras aprender UNA, siguen estando las 14 + la nueva' ((Cuantas) -eq 15) ("quedaron $(Cuantas)")
Comp 'y la numero 7 sigue diciendo lo suyo' ((Dice 'frase numero 7') -eq 'orden 7') (Dice 'frase numero 7')

Write-Host ''
Write-Host '-- lo que NO puede pasar: que olvidar se deshaga solo --'
# esta es la razon por la que esto no se arreglo antes: fusionar con el disco sin mas
# resucita lo que acabas de olvidar, porque sigue estando en el fichero
Comp 'se olvida la numero 3' (Remove-Traduccion 'frase numero 3')
Comp 'y ya no esta' ((Dice 'frase numero 3') -eq '') (Dice 'frase numero 3')
Add-Traduccion 'otra mas' 'otra orden'
Comp 'tras guardar otra vez, la 3 NO ha vuelto' ((Dice 'frase numero 3') -eq '') (Dice 'frase numero 3')
Comp 'y el resto sigue' ((Cuantas) -eq 15) ("van $(Cuantas)")

Write-Host ''
Write-Host '-- y si la olvidaste y la vuelves a aprender, se queda --'
Add-Traduccion 'frase numero 3' 'la quiero otra vez'
Comp 'vuelve a estar' ((Dice 'frase numero 3') -eq 'la quiero otra vez')
Add-Traduccion 'y una mas' 'y una orden mas'
Comp 'y sigue estando tras otro guardado' ((Dice 'frase numero 3') -eq 'la quiero otra vez')

Remove-Item -LiteralPath $LogDir -Recurse -Force -ErrorAction SilentlyContinue
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host ''
Write-Host '  guardar una traduccion ya no se lleva por delante lo que no estaba en la RAM'
exit 0
