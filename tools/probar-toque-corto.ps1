# CUANTO TARDA BRAYA EN SOLTAR EL BOTON (18/09).
#
# holdMs (1100 ms) es lo que hay que MANTENER la tecla para que Nova dicte. Estaba puesto a ojo
# y no habia forma de saber si esta bien, porque la duracion de la pulsacion no se medía en
# ningun sitio: el log solo repetia el valor configurado ("mantener 1.1 s").
#
# El unico caso que delata un umbral alto es soltar SIN que llegue a disparar: ahi braya quiso
# dictar y se quedo sin dictado. Esto comprueba el medidor, que no decide nada todavia.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Add-ToqueCorto')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira ---
$HOLD_MS = 1100
$script:dicho = @()
$script:apuntado = @()
function Log($m) { $script:dicho += $m }
function Add-Estadistica($ruta, $detalle = '__SIN__') { $script:apuntado += "$ruta|$detalle" }

Write-Host '  -- lo que NO es un intento de dictar --'
Comp 'un toque suelto (panel rapido) no cuenta' (-not (Add-ToqueCorto 50)) ''
Comp 'ni uno de 119 ms' (-not (Add-ToqueCorto 119)) ''
Comp 'y lo que ya disparo, tampoco' (-not (Add-ToqueCorto 1100)) ''
Comp 'ni una pulsacion larga de verdad' (-not (Add-ToqueCorto 5000)) ''
Comp 'nada de eso se apunta' ($script:apuntado.Count -eq 0) "apuntados=$($script:apuntado.Count)"

Write-Host '  -- y lo que SI: se solto antes de tiempo --'
$script:dicho = @(); $script:apuntado = @()
Comp 'a los 300 ms cuenta' (Add-ToqueCorto 300) ''
Comp 'y a los 1099, justo antes de disparar' (Add-ToqueCorto 1099) ''
Comp 'a los 120 tambien (el borde de abajo)' (Add-ToqueCorto 120) ''
Comp 'se apuntaron los tres' ($script:apuntado.Count -eq 3) "apuntados=$($script:apuntado.Count)"

Write-Host '  -- y queda el dato para poder decidir despues --'
Comp 'el log dice cuanto tardo' ((($script:dicho -join ' ') -match '1099 ms')) ($script:dicho[1])
Comp 'y contra que umbral' ((($script:dicho -join ' ') -match '1100')) ''
Comp 'se cuenta como toque-corto' ((($script:apuntado -join ' ') -match 'toque-corto')) ($script:apuntado[0])

# NO DEBE LLEVAR DETALLE: "Ultimas ordenes" es la lista de lo que braya pidio, y un boton
# soltado no es una orden. Add-Estadistica solo mete en 'recientes' si hay detalle.
Comp 'y SIN detalle, para no ensuciar Ultimas ordenes' ((($script:apuntado -join ' ') -match 'toque-corto\|__SIN__')) ($script:apuntado[0])

# --- y que el bucle lo llame de verdad ---
Write-Host '  -- el bucle lo apunta donde toca --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'el bucle llama a Add-ToqueCorto' ($txt -match 'Add-ToqueCorto \(\$sw\.ElapsedMilliseconds - \$downSince\)') ''
# solo tiene sentido en la rama de "solto sin que disparase": si se llamara en otro sitio,
# contaria pulsaciones que SI dictaron
$i = $txt.IndexOf('Add-ToqueCorto ($sw.ElapsedMilliseconds')
$desde = [Math]::Max(0, $i - 320)
$trozo = $txt.Substring($desde, [Math]::Min(420, $txt.Length - $desde))
Comp 'y solo cuando se solto sin disparar' ($trozo -match '-not \$holdFired') ''
Comp 'y no se cuenta si nunca se pulso' ($trozo -match '\$downSince -gt 0') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
