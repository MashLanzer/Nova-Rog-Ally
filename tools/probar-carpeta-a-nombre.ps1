# RENOMBRAR EN LA MEMORIA LO QUE SE GUARDO CON EL NOMBRE DE LA CARPETA (26/09, idea 38 de 121).
#
# juegos.json podia tener "CatQuest_Purribean" (100 s el 20/09) en vez de "Cat Quest III", porque
# Get-JuegoEnPrimerPlano devolvia el nombre de la carpeta. Repair-ClavesPorCarpeta lo arregla al
# arrancar, una vez, sin marca (al renombrar, la clave mala deja de existir). Este banco corre la
# funcion DE VERDAD (sacada por AST) contra un juegos.json de mentira en un temporal, nunca la
# memoria real.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'), [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira: un $MemoriaDir temporal y las funciones de verdad ---
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-cn-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null
$script:logs = New-Object System.Collections.ArrayList
function Log([string]$m) { [void]$script:logs.Add($m) }
# Save-Corrupto hace Move-Item: si Repair lo llamara (no debe), juegos.json desapareceria.
function Save-Corrupto($a, $b) { throw 'Repair no debe llamar a Save-Corrupto (usa Copy-Item)' }
Invoke-Expression (Traer 'Get-JuegosMem')
Invoke-Expression (Traer 'Save-JuegosMem')
Invoke-Expression (Traer 'Get-DiasJuego')
Invoke-Expression (Traer 'Repair-ClavesPorCarpeta')

# los pares REALES del disco (leidos el 26/09; la de braya cambia, por eso van a mano). La
# entrada Xbox lleva la ruta entera en 'dir': prueba el filtro de barra.
$script:Juegos = @(
    @{ nombre = 'Cat Quest III'; dir = 'CatQuest_Purribean' }
    @{ nombre = 'Roblox'; dir = 'C:\XboxGames\Roblox' }
)
$rutaJ = Join-Path $MemoriaDir 'juegos.json'
function Limpia {
    Get-ChildItem -LiteralPath $MemoriaDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $script:juegosMem = $null
    $script:logs = New-Object System.Collections.ArrayList
}
function PonJson($obj) {
    $script:juegosMem = $null
    [IO.File]::WriteAllText($rutaJ, ($obj | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
}
function LeeJson { $script:juegosMem = $null; return (Get-JuegosMem) }
function Copias { return @(Get-ChildItem -LiteralPath $MemoriaDir -Filter '*.antes-fusion-*' -File -ErrorAction SilentlyContinue) }

# --------------------------------------------------------------------------------------------
Write-Host ''
Write-Host '  -- el caso real: la clave de la carpeta se renombra --'
Limpia
PonJson @{ 'CatQuest_Purribean' = @{ dias = @{ '2026-09-20' = 100 } } }
Repair-ClavesPorCarpeta
$r = LeeJson
$diasCat = Get-DiasJuego $r['Cat Quest III']['dias']
Comp '1. Cat Quest III existe con 100 s el 2026-09-20' ($r.ContainsKey('Cat Quest III') -and [int]$diasCat['2026-09-20'] -eq 100) "dias: $($diasCat['2026-09-20'])"
Comp '   y CatQuest_Purribean ya no existe' (-not $r.ContainsKey('CatQuest_Purribean')) ''
# la copia de seguridad: existe Y juegos.json SIGUE existiendo (esto caza Save-Corrupto/Move-Item)
Comp '2. se hizo una copia .antes-fusion-*' ((Copias).Count -eq 1) "$((Copias).Count) copias"
Comp '   y juegos.json sigue existiendo (Copy-Item, no Move-Item)' (Test-Path -LiteralPath $rutaJ) ''

Write-Host ''
Write-Host '  -- idempotente: la segunda pasada no toca nada --'
$copiasAntes = (Copias).Count
$logsAntes = $script:logs.Count
Repair-ClavesPorCarpeta
Comp '3. no crea una segunda copia' ((Copias).Count -eq $copiasAntes) "$((Copias).Count)"
Comp '   ni escribe nada nuevo en el log' ($script:logs.Count -eq $logsAntes) ''

Write-Host ''
Write-Host '  -- GUARDA 2: destino presente, dias distintos -> se fusiona --'
Limpia
PonJson @{ 'CatQuest_Purribean' = @{ dias = @{ '2026-09-20' = 100 } }
           'Cat Quest III' = @{ dias = @{ '2026-09-21' = 40 } } }
Repair-ClavesPorCarpeta
$r = LeeJson
$d = Get-DiasJuego $r['Cat Quest III']['dias']
Comp '4. quedan los dos dias' ($r.ContainsKey('Cat Quest III') -and $d.ContainsKey('2026-09-20') -and $d.ContainsKey('2026-09-21')) "$($d.Keys -join ',')"
Comp '   con sus segundos (100 + 40 = 140)' (([int]$d['2026-09-20'] + [int]$d['2026-09-21']) -eq 140) ''
Comp '   y la clave de la carpeta ya no esta' (-not $r.ContainsKey('CatQuest_Purribean')) ''

Write-Host ''
Write-Host '  -- GUARDA 3: destino presente, MISMO dia -> no se toca nada --'
Limpia
PonJson @{ 'CatQuest_Purribean' = @{ dias = @{ '2026-09-20' = 100 } }
           'Cat Quest III' = @{ dias = @{ '2026-09-20' = 55 } } }
Repair-ClavesPorCarpeta
$r = LeeJson
Comp '5. las dos claves siguen ahi (no doblar ni perder segundos)' ($r.ContainsKey('CatQuest_Purribean') -and $r.ContainsKey('Cat Quest III')) ''
Comp '   Cat Quest III sigue con sus 55 s' ([int](Get-DiasJuego $r['Cat Quest III']['dias'])['2026-09-20'] -eq 55) ''
Comp '   y lo dice en el log' (($script:logs -join ' ') -match 'comparten dia') ''

Write-Host ''
Write-Host '  -- no se inventa juegos, ni revienta sin biblioteca --'
Limpia
PonJson @{ 'It Takes Two' = @{ dias = @{ '2026-09-15' = 200 } } }
Repair-ClavesPorCarpeta
$r = LeeJson
Comp '6. una clave que no casa con ningun installdir queda intacta' ($r.ContainsKey('It Takes Two') -and [int](Get-DiasJuego $r['It Takes Two']['dias'])['2026-09-15'] -eq 200) ''
Comp '   y no se hizo copia (no habia nada que mover)' ((Copias).Count -eq 0) ''

Limpia
PonJson @{ 'CatQuest_Purribean' = @{ dias = @{ '2026-09-20' = 100 } } }
$guardaJuegos = $script:Juegos
$script:Juegos = @()
Repair-ClavesPorCarpeta
$r = LeeJson
Comp '7. sin biblioteca ($script:Juegos vacio) no toca nada ni revienta' ($r.ContainsKey('CatQuest_Purribean') -and (Copias).Count -eq 0) ''
$script:Juegos = $guardaJuegos

# el filtro de barra: la entrada Xbox (dir con ruta entera) nunca entra en la tabla, asi que una
# clave que fuera la ruta entera no se migraria (no que pase en la practica, pero fija la guarda)
Limpia
PonJson @{ 'C:\XboxGames\Roblox' = @{ dias = @{ '2026-09-10' = 10 } } }
Repair-ClavesPorCarpeta
$r = LeeJson
Comp '8. una dir con barras no genera migracion (filtro de barra)' ($r.ContainsKey('C:\XboxGames\Roblox') -and (Copias).Count -eq 0) ''

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'las claves de juego se arreglan por la carpeta' -ForegroundColor Green
exit 0
