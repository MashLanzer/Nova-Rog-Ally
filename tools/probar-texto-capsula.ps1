# QUE EL TEXTO DE LA CAPSULA NO SE PARTA A MITAD DE PALABRA (17/09).
#
# Set-UI cortaba a 137 letras a pelo: "no he podido abrir la carpeta de desc..." se quedaba
# en "desc". La VOZ ya lo hacia bien desde el 14/09 (Get-TextoVoz busca el final de una
# frase, y si no el ultimo espacio); esto es lo mismo para lo que se LEE.
#
# Lo que se comprueba no es solo que corte: es que la ultima palabra que se ve este ENTERA
# en el texto original. Y hay un caso que demuestra que el corte viejo la partia, porque si
# no, esta prueba no estaria sujetando nada.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Get-TextoCapsula')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
# la comprobacion de verdad: lo que se ve tiene que ser un principio EXACTO del original,
# y terminar justo donde el original tiene un espacio (o donde se acaba)
function TerminaEnPalabra([string]$original, [string]$visto) {
    $base = $visto -replace '\.\.\.$', ''
    $base = $base.TrimEnd()
    if (-not $original.StartsWith($base)) { return $false }
    if ($base.Length -ge $original.Length) { return $true }
    return ($original[$base.Length] -eq ' ' -or $original[$base.Length] -in @(',', '.', ';', ':'))
}

# una respuesta larga de verdad, de las que da Nova
$largo = 'No he podido abrir la carpeta de descargas porque la ruta que tienes guardada en la configuracion ya no existe, asi que he abierto el escritorio en su lugar'

Write-Host '  -- lo largo se corta por donde se puede leer --'
$r = Get-TextoCapsula $largo
Comp 'no se pasa del tope' ($r.Length -le 140) "largo=$($r.Length)"
Comp 'la ultima palabra esta entera' (TerminaEnPalabra $largo $r) "'$r'"
Comp 'y avisa de que sigue' ($r.EndsWith('...')) ''
Comp 'sin coma ni punto colgando antes de los puntos' (-not ($r -match '[,;:.]\.\.\.$')) "'$r'"

Write-Host '  -- y el corte viejo SI la partia (si no, esto no prueba nada) --'
$viejo = $largo.Substring(0, 137) + '...'
Comp 'el de antes dejaba la palabra a medias' (-not (TerminaEnPalabra $largo $viejo)) "'...$($viejo.Substring(120))'"

Write-Host '  -- lo que cabe no se toca --'
Comp 'una respuesta corta sale igual' ((Get-TextoCapsula 'Abriendo Steam') -eq 'Abriendo Steam') ''
$justo = 'a' * 140
Comp 'lo que mide justo el tope no se corta' ((Get-TextoCapsula $justo) -eq $justo) ("largo=" + (Get-TextoCapsula $justo).Length)
Comp 'vacio sigue vacio' ((Get-TextoCapsula '') -eq '') ''

Write-Host '  -- y los casos raros no lo rompen --'
$saltos = "Primera linea`r`nsegunda    linea`tcon tabulador"
Comp 'saltos y espacios de mas se juntan' ((Get-TextoCapsula $saltos) -eq 'Primera linea segunda linea con tabulador') ("'" + (Get-TextoCapsula $saltos) + "'")
# una ruta larguisima sin espacios utiles: se corta a pelo A PROPOSITO, es mejor que
# ensenar dos palabras y nada mas
$ruta = 'He guardado esto en C:\Users\braya\Documents\voice-ctrl\pruebas\audio\uso\registro-de-todo-lo-que-se-ha-oido-hoy-y-tambien-de-ayer-por-la-noche.jsonl'
$rr = Get-TextoCapsula $ruta
Comp 'una palabra larguisima no lo cuelga' ($rr.Length -le 140 -and $rr.EndsWith('...')) "largo=$($rr.Length)"
Comp 'y aun asi ensena bastante, no dos palabras' ($rr.Length -ge 100) "largo=$($rr.Length)"

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
