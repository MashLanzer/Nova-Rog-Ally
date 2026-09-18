# QUE EL PRONOMBRE NO TAPE OTRA ORDEN (17/09).
#
# El atajo de "abrelo" reescribe la frase ANTES de que llegue a su propio patron, y los
# patrones que empiezan igual estan cientos de lineas mas abajo. Resultado: "ponla siempre
# encima" se convertia en "pon spotify siempre encima" y acababa ABRIENDO Spotify.
#
# Lo que se comprueba aqui son las dos mitades, porque una sin la otra no vale:
#   1) que las frases que SON otra orden ya no se las lleve el atajo;
#   2) que "abrelo" -lo unico que braya usa de verdad: 4 veces en el log- sigue funcionando.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Resolve-Pronombre')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- lo que SI es el atajo (lo que braya usa de verdad) --'
Comp "'abrelo' apunta al ultimo nombrado" ((Resolve-Pronombre 'abrelo' 'elden ring') -eq 'abre elden ring') ("-> " + (Resolve-Pronombre 'abrelo' 'elden ring'))
Comp "'abrele' (asi lo deja el corrector) tambien" ((Resolve-Pronombre 'abrele' 'elden ring') -eq 'abre elden ring') ("-> " + (Resolve-Pronombre 'abrele' 'elden ring'))
Comp "'abrelo en steam' conserva el donde" ((Resolve-Pronombre 'abrelo en steam' 'elden ring') -eq 'abre elden ring en steam') ("-> " + (Resolve-Pronombre 'abrelo en steam' 'elden ring'))
Comp "'buscalo en youtube' igual" ((Resolve-Pronombre 'buscalo en youtube' 'sabaton') -eq 'busca sabaton en youtube') ("-> " + (Resolve-Pronombre 'buscalo en youtube' 'sabaton'))
Comp "'abrelo ya' (relleno) sigue valiendo" ((Resolve-Pronombre 'abrelo ya' 'spotify') -eq 'abre spotify ya') ("-> " + (Resolve-Pronombre 'abrelo ya' 'spotify'))
Comp "'cierralo' cierra lo ultimo" ((Resolve-Pronombre 'cierralo' 'spotify') -eq 'cierra spotify') ("-> " + (Resolve-Pronombre 'cierralo' 'spotify'))

Write-Host '  -- y lo que NO es el atajo, sino otra orden (el fallo) --'
Comp "'ponla siempre encima' NO abre spotify" ((Resolve-Pronombre 'ponla siempre encima' 'spotify') -eq '') ("-> '" + (Resolve-Pronombre 'ponla siempre encima' 'spotify') + "'")
Comp "'ponlo siempre encima' tampoco" ((Resolve-Pronombre 'ponlo siempre encima' 'spotify') -eq '') ''
Comp "'ponle el volumen al 50' tampoco" ((Resolve-Pronombre 'ponle el volumen al 50' 'spotify') -eq '') ("-> '" + (Resolve-Pronombre 'ponle el volumen al 50' 'spotify') + "'")
Comp "'ponle el brillo al 30' tampoco" ((Resolve-Pronombre 'ponle el brillo al 30' 'spotify') -eq '') ''
Comp "'cierrala' es quitar la tarjeta" ((Resolve-Pronombre 'cierrala' 'spotify') -eq '') ("-> '" + (Resolve-Pronombre 'cierrala' 'spotify') + "'")

Write-Host '  -- y sin nada nombrado antes, el atajo no existe --'
Comp "'abrelo' sin objetivo no inventa" ((Resolve-Pronombre 'abrelo' '') -eq '') ''
Comp 'una frase vacia no revienta' ((Resolve-Pronombre '' 'spotify') -eq '') ''
Comp 'una orden normal ni se toca' ((Resolve-Pronombre 'abre steam' 'spotify') -eq '') ''

# --- LA OTRA MITAD: que la frase salvada llegue de verdad a su patron ---
# Sujeta el porque del arreglo: si manana alguien quita la guarda, esto lo caza.
Write-Host '  -- y la frase salvada encaja con su orden de verdad --'
$txtA = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
$patEncima = ''
foreach ($l in ($txtA -split "`r?`n")) {
    if ($l -match "^\s*if \(\`$f -match '(\^\(\?:ponla\|ponlo.+siempre.+)'\) \{") { $patEncima = $Matches[1]; break }
}
Comp 'sigue existiendo el patron de siempre encima' ($patEncima -ne '') ''
Comp "'ponla siempre encima' encaja con el suyo" ('ponla siempre encima' -match $patEncima) ''
Comp 'y la frase que salia antes NO encajaba con nada' (-not ('pon spotify siempre encima' -match $patEncima)) '(ese era el fallo)'

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
