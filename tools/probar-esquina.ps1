# La esquina de la capsula: guardarla sin romper config.json.
# Aqui lo que puede salir mal de verdad es Set-Cfg: si escribe mal el archivo,
# el asistente se queda sin rutas, sin voz y sin nada al siguiente arranque.
# Se trabaja sobre una COPIA, nunca sobre el config de verdad.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Log($m) { }
$tmp = Join-Path $env:TEMP ("cfg-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Copy-Item (Join-Path $raiz 'config.json') (Join-Path $tmp 'config.json')
# Set-Cfg escribe en $cfgPath: se le apunta a la copia
$cfgPath = Join-Path $tmp 'config.json'
Invoke-Expression (Traer 'Set-Cfg')
Invoke-Expression (Traer 'Write-Atomico')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

$antes = Get-Content -Raw (Join-Path $tmp 'config.json') | ConvertFrom-Json
$nApps = @($antes.PSObject.Properties.Name).Count

Comp 'guarda el ajuste' (Set-Cfg 'ui' 'esquina' 'arriba-derecha') ''
$j = Get-Content -Raw (Join-Path $tmp 'config.json') | ConvertFrom-Json
Comp 'y se lee de vuelta' ($j.ui.esquina -eq 'arriba-derecha') "esquina='$($j.ui.esquina)'"
Comp 'sin perder las demas secciones' (@($j.PSObject.Properties.Name).Count -eq $nApps) "$nApps secciones"
Comp 'ni lo que habia en ui' ($null -ne $j.ui.popupMs) "popupMs=$($j.ui.popupMs)"
Comp 'ni las rutas' ($j.paths.opencodeCli -eq $antes.paths.opencodeCli) ''
$crudo = [System.IO.File]::ReadAllBytes((Join-Path $tmp 'config.json'))
Comp 'y SIN BOM (lo leen los workers)' (-not ($crudo[0] -eq 0xEF -and $crudo[1] -eq 0xBB)) ''

Comp 'cambiarlo otra vez no duplica' (Set-Cfg 'ui' 'esquina' 'abajo-izquierda') ''
$j = Get-Content -Raw (Join-Path $tmp 'config.json') | ConvertFrom-Json
Comp 'y queda el ultimo' ($j.ui.esquina -eq 'abajo-izquierda') "esquina='$($j.ui.esquina)'"

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
