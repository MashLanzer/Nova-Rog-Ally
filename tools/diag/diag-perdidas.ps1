# QUE DE LO QUE BRAYA DIJO SIGUE SIN ENTENDERSE HOY (23/09).
#
# En assistant.log hay 515 lineas "LOCAL descarta: no reconozco '...'": son frases suyas que
# la capa local no supo colocar. Pero muchas son de hace dias y desde entonces se han puesto
# patrones nuevos, asi que la lista en crudo miente hacia arriba.
#
# Esto coge esas frases y las pasa por TODOS los patrones anclados de assistant.ps1 tal y como
# esta HOY. Lo que sigue sin casar con ninguno es la lista de verdad, y de ahi salen las ideas.
# No es una prueba, es una herramienta de mirar: no dice OK ni MAL, dice que queda.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$log = Join-Path $raiz 'assistant.log'

# todos los patrones anclados del fichero
$pats = @()
foreach ($m in [regex]::Matches($fuente, "-match\s+'(\^[^']+\`$)'")) {
    $p = $m.Groups[1].Value
    try { [void][regex]::new($p); $pats += $p } catch { }
}
Write-Host ("patrones anclados que compilan: {0}" -f $pats.Count)

# las frases que no reconocio, con cuantas veces
$cuenta = @{}
foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($log), "no reconozco '([^']{3,120})'")) {
    $f = $m.Groups[1].Value
    if ($cuenta.ContainsKey($f)) { $cuenta[$f]++ } else { $cuenta[$f] = 1 }
}
Write-Host ("frases distintas que no reconocio: {0}" -f $cuenta.Count)

$siguen = @()
$yaNo = 0
foreach ($f in $cuenta.Keys) {
    $casa = $false
    foreach ($p in $pats) { if ($f -match $p) { $casa = $true; break } }
    if ($casa) { $yaNo += $cuenta[$f] } else { $siguen += [pscustomobject]@{ frase = $f; veces = $cuenta[$f] } }
}
Write-Host ("ya se entienden hoy: {0} ocurrencias" -f $yaNo)
Write-Host ("siguen sin entenderse: {0} frases distintas" -f $siguen.Count)
Write-Host ''
Write-Host '-- las que mas se repiten y siguen sin entenderse --'
foreach ($x in ($siguen | Sort-Object -Property veces -Descending | Select-Object -First 60)) {
    Write-Host ("  {0,3}  {1}" -f $x.veces, $x.frase)
}
