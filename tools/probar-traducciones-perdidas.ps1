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
function Save-Corrupto($ruta, $que) { $script:corruptos += $que }
$script:corruptos = @()

$LogDir = Join-Path $env:TEMP ("trad-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$TraduccionesPath = Join-Path $LogDir 'traducciones.json'
$script:traducciones = $null
$script:traduccionesQuitadas = New-Object System.Collections.Generic.HashSet[string]
$script:invitado = $false
# D6 (21/09): el contador de usos y el tope, que ahora viven en el mismo fichero
$script:traduccionesUsos = @{}
$script:traduccionesUsoSucio = $false
$script:traduccionesUsoEn = 0
$TraduccionesMax = 300
$sw = [System.Diagnostics.Stopwatch]::StartNew()

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Write-Atomico')
Invoke-Expression (Traer 'Get-Traducciones')
Invoke-Expression (Traer 'Save-Traducciones')
Invoke-Expression (Traer 'Add-Traduccion')
Invoke-Expression (Traer 'Remove-Traduccion')
Invoke-Expression (Traer 'Add-UsoTraduccion')
# Find-Traduccion es el UNICO sitio por el que se usa una traduccion, o sea el unico que
# suma usos: sin traerla, los casos de D6 de abajo no prueban nada
Invoke-Expression (Traer 'Find-Traduccion')
Invoke-Expression (Traer 'Get-Distancia')

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Cuantas { if (-not (Test-Path -LiteralPath $TraduccionesPath)) { return 0 }
    return @((Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties).Count }
# LOS DOS FORMATOS (D6, 21/09): una entrada vieja es 'clave': 'texto' y una nueva es
# 'clave': { t: 'texto'; usos: N }. El banco tiene que leer los dos igual que el codigo,
# porque el fichero que hay hoy en la consola de braya es del formato viejo.
function Dice([string]$k) {
    if (-not (Test-Path -LiteralPath $TraduccionesPath)) { return '' }
    $j = Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pp = $j.PSObject.Properties[$k]
    if (-not $pp) { return '' }
    $v = $pp.Value
    if ($v -and $v.PSObject -and $v.PSObject.Properties['t']) { return [string]$v.t }
    return [string]$v
}
function Usos([string]$k) {
    if (-not (Test-Path -LiteralPath $TraduccionesPath)) { return -1 }
    $j = Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $pp = $j.PSObject.Properties[$k]
    if (-not $pp) { return -1 }
    $v = $pp.Value
    if ($v -and $v.PSObject -and $v.PSObject.Properties['usos']) { return [int]$v.usos }
    return 0
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

Write-Host ''
Write-Host '-- E6: el fichero de HOY, que ya es del formato nuevo --'
# EL FALLO QUE CAZA ESTE CASO (22/09). El bloque de las 14 de arriba deja el fichero en
# formato VIEJO ('clave': 'texto'), que es como era el dia que paso; con ese formato la
# fusion funcionaba. Pero desde el 22/09 lo que Nova escribe es el formato NUEVO
# ('clave': { t; usos }), y sobre ese objeto el [string] de la fusion no sacaba el texto:
# sacaba "@{t=...; usos=0}". O sea que el arreglo de las 14 destruia justo lo que salvaba.
# Reproducido con el traducciones.json de verdad: 5 de 5 entradas hechas basura con un
# solo 'aprende'. Con el codigo de antes del arreglo este bloque da MAL.
$nuevo = New-Object PSObject
for ($i = 1; $i -le 5; $i++) {
    $nuevo | Add-Member -NotePropertyName "dilo asi $i" -NotePropertyValue ([ordered]@{ t = "orden buena $i"; usos = ($i * 2) })
}
Write-Atomico $TraduccionesPath ($nuevo | ConvertTo-Json -Depth 4)
$script:traducciones = @{}                # la RAM vacia: es lo que deja un JSON corrupto
$script:traduccionesUsos = @{}
$script:traduccionesQuitadas = New-Object System.Collections.Generic.HashSet[string]
Add-Traduccion 'otra frase cualquiera' 'abre el explorador'
Comp 'siguen las 5 y entra la nueva' ((Cuantas) -eq 6) ("quedaron $(Cuantas)")
Comp 'la 4 dice su orden, no el objeto' ((Dice 'dilo asi 4') -eq 'orden buena 4') (Dice 'dilo asi 4')
Comp 'ninguna quedo con un @{ dentro' (-not ((Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8) -match '@\{')) ''
Comp 'y los usos del disco no se ponen a cero' ((Usos 'dilo asi 4') -eq 8) ("usos=$(Usos 'dilo asi 4')")
Comp 'la recien aprendida si nace en cero' ((Usos 'otra frase cualquiera') -eq 0)

# LO QUE NO DEBE CAMBIAR: el formato viejo se sigue fusionando igual. Un traducciones.json
# que no se haya vuelto a guardar desde el 22/09 sigue siendo 'clave': 'texto', y puede
# haber de los dos en el mismo fichero.
$mezcla = New-Object PSObject
$mezcla | Add-Member -NotePropertyName 'la vieja de toda la vida' -NotePropertyValue 'sube el volumen'
$mezcla | Add-Member -NotePropertyName 'la nueva del 22' -NotePropertyValue ([ordered]@{ t = 'baja el volumen'; usos = 4 })
Write-Atomico $TraduccionesPath ($mezcla | ConvertTo-Json -Depth 4)
$script:traducciones = @{}
$script:traduccionesUsos = @{}
$script:traduccionesQuitadas = New-Object System.Collections.Generic.HashSet[string]
Add-Traduccion 'y una tercera' 'pon el mando a cargar'
Comp 'la del formato viejo sobrevive entera' ((Dice 'la vieja de toda la vida') -eq 'sube el volumen') (Dice 'la vieja de toda la vida')
Comp 'la del formato nuevo tambien' ((Dice 'la nueva del 22') -eq 'baja el volumen') (Dice 'la nueva del 22')
Comp 'la vieja arranca en cero usos' ((Usos 'la vieja de toda la vida') -eq 0) ("usos=$(Usos 'la vieja de toda la vida')")
Comp 'y la nueva conserva los suyos' ((Usos 'la nueva del 22') -eq 4) ("usos=$(Usos 'la nueva del 22')")

Write-Host ''
Write-Host '-- D6: las traducciones cuentan sus usos --'
# el formato viejo tiene que seguir leyendose: el fichero que hay hoy en la consola es asi
$viejo = New-Object PSObject
$viejo | Add-Member -NotePropertyName 'hazme la pantalla mas clarita' -NotePropertyValue 'sube el brillo'
$viejo | Add-Member -NotePropertyName 'que espacio tengo disponible' -NotePropertyValue 'cuanto espacio me queda'
Write-Atomico $TraduccionesPath ($viejo | ConvertTo-Json -Depth 4)
$script:traducciones = $null
$script:traduccionesUsos = @{}
$script:traduccionesQuitadas = New-Object System.Collections.Generic.HashSet[string]
Comp 'el formato viejo se lee igual' ((Find-Traduccion 'hazme la pantalla mas clarita') -eq 'sube el brillo')
# y usarla la cuenta
[void](Find-Traduccion 'hazme la pantalla mas clarita')
[void](Find-Traduccion 'hazme la pantalla mas clarita')
Comp 'usarla suma (3 veces en total)' ([int]$script:traduccionesUsos['hazme la pantalla mas clarita'] -eq 3) `
    ("van $([int]$script:traduccionesUsos['hazme la pantalla mas clarita'])")
Comp 'y la que no se usa se queda en cero' ([int]$script:traduccionesUsos['que espacio tengo disponible'] -eq 0)
# EL DISCO NO SE TOCA EN CADA USO: eso corre en mitad de una orden
Comp 'contar no escribe en disco' ((Usos 'hazme la pantalla mas clarita') -eq 0) 'el fichero sigue en formato viejo'
# ...hasta que se guarda por otra cosa
Add-Traduccion 'una nueva' 'abre steam'
Comp 'al guardar, los usos quedan en el fichero' ((Usos 'hazme la pantalla mas clarita') -eq 3) ("usos=$(Usos 'hazme la pantalla mas clarita')")
Comp 'y el texto sigue estando' ((Dice 'hazme la pantalla mas clarita') -eq 'sube el brillo')
Comp 'la nueva nace con cero usos' ((Usos 'una nueva') -eq 0)

Write-Host ''
Write-Host '-- y hay tope: caen las que menos se usan --'
$TraduccionesMax = 4
Add-Traduccion 'otra mas todavia' 'abre spotify'
Add-Traduccion 'y otra que sobra' 'abre discord'
Comp 'no se pasa del tope' ((Cuantas) -le 4) ("hay $(Cuantas), tope 4")
Comp 'la que MAS se usa sobrevive' ((Dice 'hazme la pantalla mas clarita') -eq 'sube el brillo')
$TraduccionesMax = 300

Remove-Item -LiteralPath $LogDir -Recurse -Force -ErrorAction SilentlyContinue
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host ''
Write-Host '  guardar una traduccion ya no se lleva por delante lo que no estaba en la RAM'
exit 0
