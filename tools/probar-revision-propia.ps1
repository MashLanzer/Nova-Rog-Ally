# NOVA SE REVISA A SI MISMA: que apague lo que no sirve, y SOLO eso.
#
# Test-RevisionPropia es la primera funcion que cambia la configuracion de Nova sin que
# braya se lo pida. Eso da mas respeto que cualquier otra cosa de hoy, asi que lo que mas
# se comprueba aqui no es que apague, sino todo lo que NO debe hacer: no decidir sin
# historial, no tocar lo que si aporta, no actuar jugando ni con un invitado delante, y
# no repetirlo dos veces el mismo dia.
#
# Sin ayudantes que compartan estado: cada caso monta sus numeros y mira el resultado.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}

# --- el mundo de mentira, montado ANTES de traer la funcion ---
$script:invitado = $false
$script:juegoActivo = $null
$script:revisionPropiaDia = ''
$WhisperUltimo = 'large-v3-turbo'
$script:stats = @{ dias = @{} }
$script:cfgPuesta = @()
$script:avisos = @()
$script:apuntes = @()
function Log($m) { }
function Get-Estadisticas { return $script:stats }
function Set-Cfg($sec, $clave, $valor) { $script:cfgPuesta += "$sec.$clave=$valor"; return $true }
function Add-Estadistica($ruta, $detalle) { $script:apuntes += "$ruta|$detalle" }
function Send-AvisoEntorno($clave, $texto, $nivel = 'medio', $cada = 60) { $script:avisos += $texto; return $true }
Invoke-Expression (Traer 'Test-RevisionPropia')

$hoy = Get-Date
function Poner([int]$intentos, [int]$utiles) {
    # reparte los numeros en los ultimos 14 dias, como si fuera uso real
    $script:stats = @{ dias = @{} }
    $script:stats.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ turbo = $intentos; 'turbo-sirvio' = $utiles }
    $script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
    $script:revisionPropiaDia = ''
    $script:WhisperUltimo = 'large-v3-turbo'
    $script:invitado = $false
    $script:juegoActivo = $null
}

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- lo que de verdad no sirve, lo apaga --'
Poner 29 1        # los numeros reales de braya: 29 intentos, 1 util
$r = Test-RevisionPropia $hoy
Comp 'con 1 util de 29, lo apaga' $r ''
Comp 'y deja la variable viva vacia' (-not $WhisperUltimo) "WhisperUltimo='$WhisperUltimo'"
Comp 'lo guarda en la configuracion' (@($script:cfgPuesta) -contains 'input.whisperModeloUltimo=') ($script:cfgPuesta -join ' ')
Comp 'y te lo dice, no lo hace a escondidas' (@($script:avisos).Count -eq 1) ''
Comp 'el aviso explica con sus numeros' ($script:avisos[0] -match '29' -and $script:avisos[0] -match 'config.json') ''

Write-Host '  -- pero NO toca lo que si aporta (lo importante) --'
Poner 29 10       # un tercio util: eso se queda
$r = Test-RevisionPropia $hoy
Comp 'con 10 utiles de 29, no lo toca' (-not $r) ''
Comp 'la variable sigue puesta' ($WhisperUltimo -eq 'large-v3-turbo') "WhisperUltimo='$WhisperUltimo'"
Comp 'y no cambia la configuracion' (@($script:cfgPuesta).Count -eq 0) ''

Write-Host '  -- ni decide con cuatro datos --'
Poner 5 0         # nada util, pero cinco intentos no son historial
$r = Test-RevisionPropia $hoy
Comp 'con 5 intentos no juzga' (-not $r) ''
Comp 'la variable sigue puesta' ($WhisperUltimo -eq 'large-v3-turbo') ''

Write-Host '  -- y se calla cuando no toca --'
Poner 29 1
$script:juegoActivo = 'It Takes Two'
Comp 'jugando no se pone a revisarse' (-not (Test-RevisionPropia $hoy)) ''
Poner 29 1
$script:invitado = $true
Comp 'con un invitado delante tampoco' (-not (Test-RevisionPropia $hoy)) ''

Write-Host '  -- una vez al dia, no en cada vuelta del bucle --'
Poner 29 1
$primero = Test-RevisionPropia $hoy
$script:WhisperUltimo = 'large-v3-turbo'   # como si volviera a estar puesto
$segundo = Test-RevisionPropia $hoy
Comp 'la primera vez decide' $primero ''
Comp 'la segunda del mismo dia, no' (-not $segundo) ''
Comp 'y no avisa dos veces' (@($script:avisos).Count -eq 1) ("avisos: " + @($script:avisos).Count)

Write-Host '  -- si ya estaba apagado, no hace nada --'
Poner 29 1
$script:WhisperUltimo = ''
$r = Test-RevisionPropia $hoy
Comp 'no vuelve a apagar lo apagado' ((-not $r) -and @($script:cfgPuesta).Count -eq 0) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
