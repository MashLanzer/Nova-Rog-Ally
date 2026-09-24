# QUE JUEGO TE ABRE (17/09).
#
# `Find-JuegoEn` es la funcion que decide que juego se lanza cuando dices un titulo, y
# hasta hoy NO TENIA NI UNA PRUEBA. Sus propios comentarios cuentan la historia: "ring"
# lanzaba ELDEN RING, "pesa" y "speaker" lanzaban PEAK, "el" abria ELDEN RING y "es"
# Little Nightmares, y "outlast 2" acababa abriendo Outlast. Todo eso se arreglo a
# ciegas, y sin pruebas nada impide que vuelva al tocar los umbrales.
#
# La biblioteca de aqui son los titulos REALES de braya (leidos de los appmanifest de
# Steam el 17/09), porque las trampas estan en sus nombres: tres "Little Nightmares" a la
# vez, "Outlast" y "Outlast 2", y "Marvel's Spider-Man Remastered".
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
foreach ($f in 'ConvertTo-Plain', 'ConvertTo-Juego', 'Get-Distancia', 'Find-JuegoEn', 'Find-Juego') {
    Invoke-Expression (Traer $f)
}
# si no encuentra nada, el de verdad relee la biblioteca; aqui no hay nada que releer
function Update-Juegos { return $false }
$script:dudosa = $null

# los titulos tal cual los tiene el Steam de braya
$script:Juegos = @()
foreach ($n in @(
    "Baldur's Gate 3", 'Black Myth: Wukong', 'Content Warning', 'ELDEN RING',
    'Goose Goose Duck', 'Hollow Knight', 'It Takes Two',
    'Little Nightmares Enhanced Edition', 'Little Nightmares II', 'Little Nightmares III',
    'Little Nightmares', 'MIMESIS', "Marvel$([char]0x2019)s Spider-Man Remastered",
    'Mortal Kombat 1', "No Man's Sky", 'Once Human', 'Outlast 2', 'Outlast', 'PEAK',
    'REANIMAL', 'Red Dead Redemption 2', 'Resident Evil 4', 'SILENT BREATH',
    'The Past Within', 'Throne and Liberty', 'Wallpaper Engine')) {
    $script:Juegos += @{ nombre = $n; plano = (ConvertTo-Juego $n) }
}

$mal = 0
function Comp([string]$dicho, [string]$esperado) {
    $script:dudosa = $null
    $j = Find-Juego $dicho
    $sale = if ($j) { [string]$j.nombre } else { '(ninguno)' }
    $quiero = if ($esperado) { $esperado } else { '(ninguno)' }
    $ok = ($sale -eq $quiero)
    Write-Host ("  {0}  {1,-26} -> {2,-38} {3}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $dicho, $sale, $(if ($ok) { '' } else { "esperaba: $quiero" }))
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- lo que dices entero --'
Comp 'elden ring' 'ELDEN RING'
Comp 'hollow knight' 'Hollow Knight'
Comp 'it takes two' 'It Takes Two'
Comp 'silent breath' 'SILENT BREATH'
Comp 'red dead redemption 2' 'Red Dead Redemption 2'

Write-Host '  -- los que se parecen entre si (aqui es donde duele) --'
Comp 'outlast' 'Outlast'
Comp 'outlast 2' 'Outlast 2'
Comp 'little nightmares' 'Little Nightmares'
Comp 'little nightmares 2' 'Little Nightmares II'
Comp 'little nightmares 3' 'Little Nightmares III'

Write-Host '  -- palabras sueltas que NO deben abrir nada (salieron del ruido real) --'
Comp 'el' ''
Comp 'es' ''
Comp 'ring' ''
Comp 'pesa' ''
Comp 'speaker' ''
Comp 'dos' ''

Write-Host '  -- como los llama uno al hablar, no como los escribe la tienda --'
# NADIE dice "Marvel's Spider-Man Remastered": se dice "spider man". Hoy falla porque se
# exige que lo dicho cubra el 60 % del titulo, y "spider man" (10) contra
# "marvel s spider man remastered" (30) no llega ni de lejos.
Comp 'spider man' "Marvel$([char]0x2019)s Spider-Man Remastered"
Comp 'spiderman' "Marvel$([char]0x2019)s Spider-Man Remastered"
Comp 'baldurs gate 3' "Baldur's Gate 3"
Comp 'no mans sky' "No Man's Sky"

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
