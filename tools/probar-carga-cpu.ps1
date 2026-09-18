# LA SONDA DE CARGA DE CPU: BARATA, Y SI NO, APAGADA (18/09).
#
# Medido en el equipo de braya: Get-CimInstance Win32_Processor tarda entre 1057 y 1320 ms
# (cinco de cinco, en caliente) y se llamaba SINCRONA en el bucle cada 30 s solo para mover la
# insignia de carga de la capsula. Un segundo congelada de cada treinta, por un adorno.
# El contador de rendimiento de .NET da lo mismo en 0-10 ms.
#
# Aqui se comprueba lo que de verdad importa: que el camino normal no toca CIM, que hay
# respaldo si no hay contador, y que si el respaldo tambien sale caro la sonda SE APAGA en vez
# de seguir bloqueando (el criterio del acelerometro, generalizado).
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Get-CargaCPU')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira ---
$CargaTopeMs = 400
$script:apuntado = @()
$script:cimLlamadas = 0
$script:cimMs = 0
$script:cimValor = 42
function Log($m) { }
function Add-Estadistica($t, $d) { $script:apuntado += "$t|$d" }
# OJO: NO se declara $ErrorAction. Es un parametro COMUN de PowerShell, y ponerlo en el
# param() revienta la llamada entera con ParameterNameAlreadyExistsForCommand: el doble no
# llegaba a ejecutarse, se llamaba al CIM DE VERDAD (1060 ms), y como pasa del tope la sonda
# se apagaba... con lo que el caso "se apaga si es caro" salia verde por la razon equivocada.
# Con [CmdletBinding()] los parametros comunes se aceptan solos.
function Get-CimInstance {
    [CmdletBinding()]
    param([Parameter(Position = 0)]$ClassName)
    $script:cimLlamadas++
    if ($script:cimMs -gt 0) { Start-Sleep -Milliseconds $script:cimMs }
    if ($null -eq $script:cimValor) { return @() }
    return @([PSCustomObject]@{ LoadPercentage = $script:cimValor })
}
# el contador: se sustituye la de verdad, que tocaria el hardware
$script:contadorDa = 17
function New-ContadorCarga {
    if ($null -eq $script:contadorDa) { return $null }
    $c = [PSCustomObject]@{}
    $c | Add-Member -MemberType ScriptMethod -Name NextValue -Value {
        if ($script:contadorDa -eq 'romper') { throw 'el contador se fue' }
        return [double]$script:contadorDa
    }
    return $c
}
function Reiniciar {
    $script:cargaSonda = ''
    $script:cargaContador = $null
    $script:cimLlamadas = 0
    $script:cimMs = 0
    $script:cimValor = 42
    $script:contadorDa = 17
    $script:apuntado = @()
}

Write-Host '  -- con contador, ni se toca CIM (el caso normal) --'
Reiniciar
$v = Get-CargaCPU
Comp 'da la carga' ($v -eq 17) "valor=$v"
Comp 'y NO llama a CIM' ($script:cimLlamadas -eq 0) "llamadas=$($script:cimLlamadas)"
$v2 = Get-CargaCPU
Comp 'la segunda vez tampoco' ($script:cimLlamadas -eq 0 -and $v2 -eq 17) ''
Comp 'y no crea el contador otra vez' ($script:cargaSonda -eq 'contador') "sonda=$($script:cargaSonda)"

Write-Host '  -- un valor imposible no se cuela --'
Reiniciar; $script:contadorDa = 250
Comp 'por encima de 100 se recorta' ((Get-CargaCPU) -eq 100) ''
Reiniciar; $script:contadorDa = -5
Comp 'un negativo no se da por bueno' ($null -eq (Get-CargaCPU)) ''

Write-Host '  -- sin contador, el respaldo por CIM --'
Reiniciar; $script:contadorDa = $null
$v = Get-CargaCPU
Comp 'cae a CIM y da el valor' ($v -eq 42) "valor=$v"
Comp 'y lo llamo una vez' ($script:cimLlamadas -eq 1) ''

Write-Host '  -- si el contador se rompe a mitad, sigue habiendo carga --'
Reiniciar
[void](Get-CargaCPU)
$script:contadorDa = 'romper'
$v = Get-CargaCPU
Comp 'pasa a CIM sin quedarse sin dato' ($v -eq 42) "valor=$v"
Comp 'y se queda en CIM' ($script:cargaSonda -eq 'cim') "sonda=$($script:cargaSonda)"

Write-Host '  -- Y LO IMPORTANTE: si el respaldo es caro, se apaga --'
Reiniciar; $script:contadorDa = $null; $script:cimMs = 600
$v = Get-CargaCPU
Comp 'no devuelve nada' ($null -eq $v) ''
Comp 'se apaga para siempre' ($script:cargaSonda -eq 'no') "sonda=$($script:cargaSonda)"
Comp 'y lo cuenta con su numero' ((($script:apuntado -join ' ') -match 'sonda de carga off') -and (($script:apuntado -join ' ') -match '400')) ($script:apuntado -join ' ')
$antes = $script:cimLlamadas
[void](Get-CargaCPU); [void](Get-CargaCPU)
Comp 'y ya NO vuelve a llamar a la sonda cara' ($script:cimLlamadas -eq $antes) "llamadas nuevas=$($script:cimLlamadas - $antes)"

Write-Host '  -- y si no da nada util, tambien se apaga --'
Reiniciar; $script:contadorDa = $null; $script:cimValor = $null
Comp 'sin lectura, no inventa' ($null -eq (Get-CargaCPU)) ''
Comp 'y se apaga' ($script:cargaSonda -eq 'no') "sonda=$($script:cargaSonda)"

# --- que el codigo real siga usandola, y no la cara ---
Write-Host '  -- y el bucle usa la sonda, no el CIM caro --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'el bucle llama a Get-CargaCPU' ($txt -match '\$cpu = Get-CargaCPU') ''
# SIN CONTAR LOS COMENTARIOS: el nombre sale tambien en el comentario que explica por que se
# dejo de usar, asi que contarlo a secas daba 2 y un rojo falso (misma leccion que en
# probar-arranque.ps1: el texto buscado estaba tambien en mi propia nota).
$codigo = @($txt -split "`r?`n" | Where-Object { $_.TrimStart() -notlike '#*' })
$vecesReal = @($codigo | Where-Object { $_ -match 'Win32_Processor' }).Count
Comp 'Win32_Processor solo queda en el respaldo' ($vecesReal -eq 1) "en codigo=$vecesReal"

# --- y la medida de verdad, en este equipo ---
Write-Host '  -- medido aqui y ahora --'
try {
    $c = New-Object System.Diagnostics.PerformanceCounter('Processor', '% Processor Time', '_Total')
    $null = $c.NextValue(); Start-Sleep -Milliseconds 250
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    $real = [int]$c.NextValue()
    $ms = $t.ElapsedMilliseconds
    Comp 'el contador de verdad responde rapido' ($ms -lt 400) "$ms ms, carga=$real %"
} catch {
    Write-Host "  --   (no hay contador en este equipo; se usara el respaldo)"
}

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
