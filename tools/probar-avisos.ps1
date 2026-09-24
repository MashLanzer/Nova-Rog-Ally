# Avisos sin voz: CUANDO se habla y cuando basta con que se vea.
# Test-AvisoSinVoz se saca del archivo real, como en las demas pruebas. Lo que
# se mide es la decision, no el pulso de la capsula (eso se ve mirandola).
# POR DONDE ESTE EL BANCO, NO POR UNA RUTA ESCRITA A MANO (22/09). Aqui habia la ruta
# completa a fuego: en una copia del repo en otra carpeta este banco seguiria midiendo el
# assistant.ps1 de SIEMPRE -verde sobre codigo que no es el que se acaba de tocar- y si la
# carpeta se renombrara se caeria entero por algo que no tiene que ver con lo que prueba.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
$fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-AvisoSinVoz' }, $true)
if (-not $fn) { throw "falta Test-AvisoSinVoz" }
Invoke-Expression $fn.Extent.Text
function Test-EnLlamada { return $false }   # sin llamada en curso (se prueba aparte)

# --- mundo de mentira ---
$script:reloj = 100000
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$AvisosSinVoz = $true
$AvisosSinVozEnJuego = $true
$script:sordinaHasta = 0
$script:juegoActivo = $null
$script:uiPerfil = ''

$fallos = 0
function Ok([string]$etiqueta, [bool]$obtenido, [bool]$esperado) {
    $ok = ($obtenido -eq $esperado)
    $que = if ($obtenido) { 'solo se ve' } else { 'habla' }
    Write-Host ("  {0}  {1,-42} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $que)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "--- cuando hablar y cuando solo verse ---"
Ok 'sin nada de por medio, habla' (Test-AvisoSinVoz) $false

$script:sordinaHasta = $script:reloj + 600000
Ok 'en sordina, callado (te callaste tu)' (Test-AvisoSinVoz) $true
$script:sordinaHasta = 0

$script:juegoActivo = 'ELDEN RING'
Ok 'con un juego delante, callado' (Test-AvisoSinVoz) $true

$AvisosSinVozEnJuego = $false
Ok 'salvo que pidas que hable en el juego' (Test-AvisoSinVoz) $false
$AvisosSinVozEnJuego = $true
$script:juegoActivo = $null

$script:uiPerfil = 'silencio'
Ok 'en modo silencio, callado' (Test-AvisoSinVoz) $true
$script:uiPerfil = 'juego'
Ok 'en modo juego (sin juego abierto), habla' (Test-AvisoSinVoz) $false
$script:uiPerfil = ''

# apagado del todo: vuelve a hablar siempre, que es como era antes
$AvisosSinVoz = $false
$script:sordinaHasta = $script:reloj + 600000
$script:juegoActivo = 'ELDEN RING'
Ok 'apagado en config, habla siempre' (Test-AvisoSinVoz) $false

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
