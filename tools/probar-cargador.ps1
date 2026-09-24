# A QUE PORCENTAJE ENCHUFA BRAYA EL CARGADOR (18/09).
#
# bateriaPct (15) es el nivel al que Nova avisa de que queda poca bateria. Para saber si ese
# numero es el bueno haria falta saber a que % enchufa el de verdad, y eso NO SE APUNTABA: el
# log solo decia "cargador: enchufado".
#
# Medido antes de tocar nada: UN solo "AVISO: bateria al" en todo el registro, 2 enchufados (en
# 2 dias, o sea que ni siquiera pasa el freno de datos repartidos) y niveles casi siempre al
# 100 %. Por eso esto NO cambia el 15: instala el medidor que faltaba.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Add-CargaConectada')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

$script:dicho = @()
$script:apuntado = @()
function Log($m) { $script:dicho += $m }
function Add-Estadistica($ruta, $detalle = '__SIN__') { $script:apuntado += "$ruta|$detalle" }

Write-Host '  -- una lectura que no sirve no se apunta --'
Comp 'el 0 % no cuenta (no hay bateria leida)' (-not (Add-CargaConectada 0)) ''
Comp 'ni un negativo' (-not (Add-CargaConectada -5)) ''
Comp 'ni mas del 100 %' (-not (Add-CargaConectada 101)) ''
Comp 'y nada de eso se guarda' ($script:apuntado.Count -eq 0) "apuntados=$($script:apuntado.Count)"

Write-Host '  -- y lo que si: el nivel al enchufar --'
$script:dicho = @(); $script:apuntado = @()
Comp 'al 45 % cuenta' (Add-CargaConectada 45) ''
Comp 'al 100 tambien (enchufa por costumbre)' (Add-CargaConectada 100) ''
Comp 'y al 1 %, el borde de abajo' (Add-CargaConectada 1) ''
Comp 'se apuntaron los tres' ($script:apuntado.Count -eq 3) "apuntados=$($script:apuntado.Count)"

Write-Host '  -- y queda el dato con el que decidir despues --'
Comp 'el log dice a que nivel fue' ((($script:dicho -join ' ') -match 'al 45 %')) ($script:dicho[0])
Comp 'se cuenta como cargador-puesto' ((($script:apuntado -join ' ') -match 'cargador-puesto')) ($script:apuntado[0])
# igual que el toque corto: sin detalle, que "Ultimas ordenes" es lo que PIDIO braya
Comp 'y SIN detalle, para no ensuciar Ultimas ordenes' ((($script:apuntado -join ' ') -match 'cargador-puesto\|__SIN__')) ''

Write-Host '  -- y el bucle lo apunta solo al PONER el cargador --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'el bucle llama a Add-CargaConectada' ($txt -match 'Add-CargaConectada \$pc') ''
$i = $txt.IndexOf('Add-CargaConectada $pc')
$desde = [Math]::Max(0, $i - 260)
$trozo = $txt.Substring($desde, [Math]::Min(360, $txt.Length - $desde))
# al QUITARLO no interesa: el dato que falta es a que % decide enchufar
Comp 'y solo cuando se enchufa (cg -eq 1)' ($trozo -match '\$cg -eq 1') ''
Comp 'y va en el flanco, no cada minuto' ($trozo -match 'cargador:') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
