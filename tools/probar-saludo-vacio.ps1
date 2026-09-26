# SALUDAR A UNA HABITACION VACIA NO ES ESTAR VIVA, ES RUIDO (25/09)
#
# LO MEDIDO sobre assistant.log y su rotado: 213 "saludo de arranque" en 16 dias. Es, con
# diferencia, lo que mas dice Nova por su cuenta. Y de esos 213:
#     59 (28 %) sin UNA SOLA senal de braya en media hora a cada lado,
#     87 (41 %) sin ninguna en diez minutos,
# y estan repartidos en DOCE dias distintos, asi que no es una tanda de pruebas.
# La causa esta contada en NOVA-TODO: el 84 % de los arranques cae a menos de 30 min de un
# commit. La mayoria son reinicios de desarrollo, no braya sentandose delante.
#
# POR QUE NO BASTABA LO QUE YA HABIA: Get-AusenciaMin mide desde la ultima senal que le llego A
# NOVA y tiene un suelo a proposito, "arranque + 60 s". Al arrancar, la ausencia vale CERO por
# construccion: Nova da por hecho que braya esta delante siempre que acaba de nacer, y nace
# 10-15 veces al dia. Por eso hacia falta preguntarselo a Windows: cuanto hace que alguien toco
# el teclado, el raton o el mando EN LA MAQUINA, viva Nova o no.
#
# LO QUE VIGILA ESTE BANCO, por orden:
#  1. Que si no se puede medir, Nova SALUDE. Callarla por una medicion fallida seria peor que
#     el ruido que se quita.
#  2. Que el liston sea $AvisoEsperaMin -los mismos 30 minutos con los que ya decide "no hay
#     nadie" para aparcar un aviso- y no una copia suya. Dos listones para la misma pregunta
#     serian dos opiniones sobre si braya esta delante.
#  3. Que el saludo NO SE PIERDA: callado quiere decir en la capsula, no en ningun sitio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}

Write-Host ''
Write-Host '-- 1. EL SENTIDO NUEVO: preguntarle a Windows si hay alguien --'
Invoke-Expression (Traer 'Get-InactividadMin')
$ocio = Get-InactividadMin
Comp 'Get-InactividadMin contesta un numero' ($ocio -is [int]) "devolvio $ocio"
Comp 'y no es un disparate' ($ocio -ge -1 -and $ocio -le 10080) "$ocio min (o -1 si no lo sabe)"
# Se ejecuta de verdad contra Windows: si el P/Invoke se rompiera, esto lo canta.
Comp 'y sabe medirlo en esta maquina' ($ocio -ge 0) 'si sale -1 aqui, la llamada al sistema fallo'

Write-Host ''
Write-Host '-- 1b. Y CUANDO LA LLAMADA AL SISTEMA FALLA, dice -1 y no 0 --'
# Aqui la llamada funciona, asi que el catch no se ejercita nunca y una rotura que lo cambiara
# por "return 0" salia VERDE. Se le pone delante un tipo SENUELO llamado NovaOcio.P sin ningun
# metodo: la funcion lo ve ya definido, se salta el Add-Type, y al invocar GetLastInputInfo
# revienta. Eso recorre el catch de verdad. Va en un PowerShell aparte para no ensuciar el de
# arriba, donde se mide la maquina de verdad.
$aparte = @"
Add-Type -TypeDefinition 'namespace NovaOcio { public class P { } }' -ErrorAction Stop
$(Traer 'Get-InactividadMin')
Write-Output (Get-InactividadMin)
"@
$tmpS = Join-Path ([IO.Path]::GetTempPath()) ("ocio-" + [Guid]::NewGuid().ToString('N') + '.ps1')
[System.IO.File]::WriteAllText($tmpS, $aparte, (New-Object System.Text.UTF8Encoding($true)))
try {
    $salida = & powershell -NoProfile -ExecutionPolicy Bypass -File $tmpS 2>$null
    $valor = [int](@($salida | Where-Object { $_ -match '^-?\d+$' })[-1])
    Comp 'con la llamada rota, devuelve -1 (no lo se)' ($valor -eq -1) "devolvio $valor"
} finally { Remove-Item -LiteralPath $tmpS -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '-- 2. EL LISTON SALE DE DONDE YA ESTABA, no de una copia --'
$mL = [regex]::Match($fuente, '(?m)^\$AvisoEsperaMin\s*=\s*(\d+)')
Comp 'existe $AvisoEsperaMin en el archivo' $mL.Success
$liston = if ($mL.Success) { [int]$mL.Groups[1].Value } else { -1 }
Write-Host ("       el liston de 'no hay nadie': " + $liston + ' min')
$iniS = $fuente.IndexOf('# SALUDAR A UNA HABITACION VACIA')
$finS = if ($iniS -ge 0) { $fuente.IndexOf('} catch { Log ("saludo fallido', $iniS) } else { -1 }
if ($iniS -lt 0 -or $finS -lt 0) { Write-Host '  MAL  no encuentro la decision del saludo'; exit 1 }
$bloque = $fuente.Substring($iniS, $finS - $iniS)
Comp 'la decision usa $AvisoEsperaMin y no un numero suyo' `
    ($bloque -match '\$AvisoEsperaMin' -and $bloque -notmatch '-ge\s+\d') 'un 30 escrito aqui seria una segunda opinion'

Write-Host ''
Write-Host '-- 3. LA DECISION, EJECUTADA CON DOBLES --'
$script:dicho = @(); $script:visto = @(); $script:apuntes = @(); $script:log = @()
function Say([string]$t) { $script:dicho += $t }
function Show-Popup([string]$t, [string]$e = '') { $script:visto += $t }
function Add-Estadistica([string]$k, [string]$v = '') { $script:apuntes += $k }
function Log([string]$m) { $script:log += $m }
$AvisoEsperaMin = $liston
$script:ocioDoble = 0
function Get-InactividadMin { return $script:ocioDoble }
Invoke-Expression ("function Saludar([string]`$saludo) {`n" + $bloque + "`n}")

function Probar([int]$ocio, [string]$que) {
    $script:ocioDoble = $ocio
    $script:dicho = @(); $script:visto = @(); $script:apuntes = @()
    Saludar 'Lista. Tu di nova.'
}

Probar 200 ''
Comp 'con 200 min sin tocar nada, NO habla' ($script:dicho.Count -eq 0) "dijo $($script:dicho.Count) cosa(s)"
Comp 'pero el saludo se ve en la capsula' ($script:visto.Count -eq 1) 'callada no es desaparecida'
Comp 'y queda contado, para poder juzgarlo luego' (@($script:apuntes) -contains 'saludo-callado') ($script:apuntes -join ',')

Probar 0 ''
Comp 'con alguien delante, saluda en voz alta' ($script:dicho.Count -eq 1) "dijo $($script:dicho.Count)"

Probar ($liston - 1) ''
Comp 'justo por debajo del liston, tambien habla' ($script:dicho.Count -eq 1) "$($liston - 1) min"
Probar $liston ''
Comp 'y justo en el liston ya se calla' ($script:dicho.Count -eq 0) "$liston min"

Write-Host ''
Write-Host '-- 4. SI NO SE PUEDE MEDIR, SE SALUDA --'
# Esta es la que mas importa: un -1 es "no lo se", no "no hay nadie". Si esto se rompiera, una
# llamada al sistema que fallara dejaria a Nova muda en cada arranque y nadie sabria por que.
Probar -1 ''
Comp 'con la medicion fallida (-1), Nova SALUDA' ($script:dicho.Count -eq 1) 'nunca callar por no saber'

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'el saludo decide si suena, y no se dice a una habitacion vacia'
exit 0
