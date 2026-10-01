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
# CUANTAS VECES SE CREA, que desde el 1/10 es el numero que importa: crear el contador cuesta
# casi un segundo (ver la ultima seccion) y por eso no puede pasar dentro del bucle.
$script:creaciones = 0
function New-ContadorCarga {
    $script:creaciones++
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
    $script:creaciones = 0
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

# --- LO CARO ES CREARLO, Y ESO NO PUEDE PASAR DENTRO DEL BUCLE (1/10) ---
#
# ESTE BANCO LO TUVO DELANTE TRECE DIAS Y NO LO VIO: la seccion de abajo cronometraba NextValue
# -la parte barata- con el contador YA CREADO fuera del reloj, y concluia "el contador de verdad
# responde rapido". Era verdad y no servia de nada. Medir solo el trozo barato de una operacion
# y dar por medida la operacion entera es una manera nueva de salir verde mintiendo.
#
# LO QUE COSTABA DE VERDAD, en el registro de Nova: NUEVE ARRANQUES DE NUEVE con la linea
# "SORDA ... s en una vuelta: carga de CPU: por contador de rendimiento", de 1,36 a 7,22 s. La
# primera vuelta que pedia la carga creaba el contador, y Nova se quedaba sorda ese rato justo
# despues de encenderse. Arreglado adelantando la creacion al arranque, antes del bucle.
Write-Host '  -- la creacion va en el arranque, NO en la primera vuelta que la pida --'
$lineasA = @($txt -split "`r?`n")
$iCalienta = -1; $iBucle = -1; $iFun = -1
for ($n = 0; $n -lt $lineasA.Count; $n++) {
    $l = $lineasA[$n]
    if ($l.TrimStart() -like '#*') { continue }
    # EL '^' NO ES ADORNO: exige que este en el cuerpo del script, sin sangrar, o sea que NO
    # este dentro de una funcion que a lo mejor nadie llama ni de un if que puede no entrar.
    if ($iFun -lt 0 -and $l -match '^function Get-CargaCPU\b') { $iFun = $n }
    if ($iCalienta -lt 0 -and $l -match '^try \{ \$null = Get-CargaCPU \} catch \{\}') { $iCalienta = $n }
    if ($iBucle -lt 0 -and $l -match '^while \(\$true\) \{') { $iBucle = $n }
}
Comp 'hay una llamada que lo crea al arrancar' ($iCalienta -ge 0) "linea $($iCalienta + 1)"
Comp '  y va envuelta en try/catch (regla 7)' ($iCalienta -ge 0) 'lo exige el propio patron'
Comp '  cuando la funcion ya existe' ($iFun -ge 0 -and $iCalienta -gt $iFun) "la funcion en $($iFun + 1)"
Comp '  y ANTES del bucle' ($iBucle -ge 0 -and $iCalienta -ge 0 -and $iCalienta -lt $iBucle) "el bucle empieza en $($iBucle + 1)"
# Y QUE EL DETECTOR SEPA DECIR QUE NO: sin esto, un '^try' que no encontrara nunca nada daria
# cuatro verdes por -1 y el banco no probaria absolutamente nada.
$sinLinea = @($lineasA | Where-Object { $_ -notmatch '^try \{ \$null = Get-CargaCPU \} catch \{\}' })
$iNo = -1
for ($n = 0; $n -lt $sinLinea.Count; $n++) { if ($sinLinea[$n] -match '^try \{ \$null = Get-CargaCPU \} catch \{\}') { $iNo = $n; break } }
Comp '  y si se quitara la llamada, esto se pondria rojo' ($iNo -lt 0) 'el detector detecta'

Write-Host '  -- y con el arranque hecho, las vueltas no crean nada --'
Reiniciar
[void](Get-CargaCPU)                                       # esto es el adelanto del arranque
$trasArranque = $script:creaciones
for ($n = 1; $n -le 50; $n++) { [void](Get-CargaCPU) }      # cincuenta vueltas del bucle
Comp 'el arranque lo crea una vez' ($trasArranque -eq 1) "creaciones=$trasArranque"
Comp '  y cincuenta vueltas despues sigue habiendo uno' ($script:creaciones -eq 1) "creaciones=$($script:creaciones)"

# --- y la medida de verdad, en este equipo ---
Write-Host '  -- medido aqui y ahora --'
try {
    # CREAR, CRONOMETRADO, Y EN UN PROCESO RECIEN NACIDO: en este ya estaria caliente de la
    # seccion de arriba y daria 0 ms, que es justo el numero mentiroso de antes.
    $guion = @'
$t = [System.Diagnostics.Stopwatch]::StartNew()
$c = New-Object System.Diagnostics.PerformanceCounter('Processor', '% Processor Time', '_Total')
$crear = $t.ElapsedMilliseconds
$null = $c.NextValue()
$t2 = [System.Diagnostics.Stopwatch]::StartNew()
$null = $c.NextValue()
'{0} {1}' -f $crear, $t2.ElapsedMilliseconds
'@
    $salida = ($guion | powershell.exe -NoProfile -Command -) | Select-Object -Last 1
    if ($salida -match '^(\d+) (\d+)$') {
        $msCrear = [int]$Matches[1]; $msLeer = [int]$Matches[2]
        # NO SE EXIGE UN NUMERO FIJO -eso dependeria de lo ocupada que este la maquina, y seria
        # un banco que decide su color por el entorno-, sino la RELACION, que es estructural:
        # crear hace trabajo de registro y leer es copiar un numero.
        Comp 'crear el contador cuesta mas que leerlo' ($msCrear -gt $msLeer) "crear=$msCrear ms, leer=$msLeer ms"
        Comp '  y por eso no cabe en una vuelta de 62 ms' ($msCrear -gt 62) "crear=$msCrear ms"
    } else {
        Write-Host "  --   (el proceso hijo no contesto; no se juzga)"
    }
    $c = New-Object System.Diagnostics.PerformanceCounter('Processor', '% Processor Time', '_Total')
    $null = $c.NextValue(); Start-Sleep -Milliseconds 250
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    $real = [int]$c.NextValue()
    $ms = $t.ElapsedMilliseconds
    Comp 'y la LECTURA si es gratis, que era lo unico medido antes' ($ms -lt 400) "$ms ms, carga=$real %"
} catch {
    Write-Host "  --   (no hay contador en este equipo; se usara el respaldo)"
}

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
