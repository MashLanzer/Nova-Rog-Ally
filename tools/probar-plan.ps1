# TAREAS SIN EL AGENTE (16/09): el PLAN de ordenes locales.
#
# El 15/09, las 20 llamadas al agente costaron 11,6 min (el 23 % de toda la espera).
# Mirandolas una a una, la mayoria eran dos o tres ordenes que Nova ya sabe hacer dichas
# de una vez. Ahora, antes de llamar al agente, la API las descompone en ordenes del
# vocabulario local; aqui se comprueba que esa lista se lee bien y, sobre todo, que se
# RECHAZA entera en cuanto algo no encaja: es preferible esperar al agente que hacer
# tres cosas que nadie pidio.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Split-Plan')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- planes que valen --"
$p1 = @(Split-Plan "cierra todos los programas`npon el modo juego")
Comp 'dos ordenes, una por linea' ($p1.Count -eq 2 -and $p1[0] -eq 'cierra todos los programas' -and $p1[1] -eq 'pon el modo juego') ($p1 -join ' | ')
$p2 = @(Split-Plan "1. abre youtube`n2. pon pitbull en youtube")
Comp 'se le quitan los numeros' ($p2.Count -eq 2 -and $p2[0] -eq 'abre youtube') ($p2 -join ' | ')
$p3 = @(Split-Plan "- abre steam`n- abre discord")
Comp 'y los guiones' ($p3.Count -eq 2 -and $p3[0] -eq 'abre steam') ($p3 -join ' | ')
$p4 = @(Split-Plan '"abre spotify"')
Comp 'y las comillas' ($p4.Count -eq 1 -and $p4[0] -eq 'abre spotify') ($p4 -join ' | ')

Write-Host "  -- planes que NO valen (van al agente) --"
Comp 'cuando dice que no se puede' ((@(Split-Plan "NO SE PUEDE")).Count -eq 0) ''
Comp 'aunque lo diga en minusculas' ((@(Split-Plan "no se puede hacer con esas ordenes")).Count -eq 0) ''
Comp 'si queda un hueco sin rellenar' ((@(Split-Plan "abre steam`npon el volumen al <n>")).Count -eq 0) ''
$seis = ((1..6 | ForEach-Object { 'abre steam' }) -join "`n")
Comp 'si son mas de cinco pasos' ((@(Split-Plan $seis)).Count -eq 0) ''
Comp 'si no devuelve nada' ((@(Split-Plan '')).Count -eq 0 -and (@(Split-Plan "`n  `n")).Count -eq 0) ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
