# EL DIARIO EN BRUTO QUE SE SUSTITUYE POR EL RESUMEN (26/09, idea 60 de las 121).
#
# Cuando el cerebro local esta caido horas, el dia pasado se quedaba sin nota en el diario (con
# idea 14 ya no se reintenta a ciegas, pero el dia esperaba). Ahora, pasado el plazo, se vuelca en
# bruto marcado 'sin resumir todavia' -para no perder el dia- y, cuando ollama vuelve, el resumen
# de verdad (vinetas) SUSTITUYE lo crudo. Este banco prueba el lado del asistente (Add-DiarioResumen).
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
$mal = 0
function Comp($etq, $ok, $det = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

function Log($m) { }
$script:invitado = $false
$DiarioDir = Join-Path ([IO.Path]::GetTempPath()) ('diario-crudo-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $DiarioDir -Force
Invoke-Expression (Traer 'Add-DiarioResumen')
$nota = Join-Path $DiarioDir '2026-09-25.md'
function Leer { return [IO.File]::ReadAllText($nota) }

Write-Host ''
Write-Host '-- 1. el volcado en bruto entra marcado "sin resumir todavia" --'
Add-DiarioResumen '2026-09-25' "no cierra bien la funda`nno coincide con la consola" $true
$t1 = Leer
Comp '1. escribe la seccion cruda' ($t1.Contains('## Lo que hablamos (sin resumir todavia)')) ''
Comp '   con las frases en bruto' ($t1.Contains('no cierra bien la funda')) ''

Write-Host ''
Write-Host '-- 2. cuando llega el resumen de verdad, SUSTITUYE lo crudo --'
Add-DiarioResumen '2026-09-25' "- hablaron de la funda de la consola`n- y de un problema de encaje" $false
$t2 = Leer
Comp '2. ya no queda la seccion cruda' (-not $t2.Contains('sin resumir todavia')) 'lo crudo se fue'
Comp '   y estan las vinetas del resumen' ($t2.Contains('hablaron de la funda') -and $t2.Contains('## Lo que hablamos')) ''
Comp '   y las frases en bruto tampoco quedan sueltas' (-not $t2.Contains('no cierra bien la funda')) ''
Comp '   el encabezado del dia sigue una sola vez' (([regex]::Matches($t2, '(?m)^# ')).Count -eq 1) ''

Write-Host ''
Write-Host '-- 3. con un invitado delante no se escribe nada --'
$notaInv = Join-Path $DiarioDir '2026-09-20.md'
$script:invitado = $true
Add-DiarioResumen '2026-09-20' 'algo' $true
$script:invitado = $false
Comp '3. en modo invitado, ni el volcado crudo' (-not (Test-Path -LiteralPath $notaInv)) ''

Remove-Item -LiteralPath $DiarioDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'el diario en bruto se sustituye por el resumen' -ForegroundColor Green
exit 0
