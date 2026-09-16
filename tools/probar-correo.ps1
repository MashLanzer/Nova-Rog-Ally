# EL CORREO POR VOZ (16/09). Sin tocar la cuenta de verdad: el script de correo se
# sustituye por uno de mentira.
#
# El 15/09 "revisa mi correo" se pidio tres veces y las tres acabaron en el agente
# (37-93 s). Lo que se comprueba aqui, sobre todo, es la parte peligrosa: ENVIAR sale
# de la maquina y no se deshace, y Nova oye mal a veces. Nunca puede enviarse nada sin
# que braya diga que si.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Format-Correos')
Invoke-Expression (Traer 'Invoke-Correo')

# --- el mundo de mentira ---
$script:enviados = @()
$script:confirmado = $false
$script:pendiente = $null
$script:correoUltimo = $null
function Log($m) { }
function Test-CorreoListo { return $true }
function Invoke-CorreoScript([string[]]$args1, [int]$plazoMs = 25000) {
    if ($args1[0] -eq 'no-leidos') {
        return [pscustomobject]@{ ok = $true; cuantos = 2; correos = @(
            [pscustomobject]@{ n = 10; de = 'Steam Support'; asunto = 'Your Steam gift has been accepted'; fecha = '16/09 15:31' },
            [pscustomobject]@{ n = 9;  de = 'Chase'; asunto = 'El saldo está por debajo de tu límite'; fecha = '16/09 22:01' }) }
    }
    if ($args1[0] -eq 'leer') {
        return [pscustomobject]@{ ok = $true; cuantos = 1; correos = @(
            [pscustomobject]@{ n = 10; de = 'Steam Support'; asunto = 'Your Steam gift has been accepted'; cuerpo = 'Tu regalo ha sido aceptado.' }) }
    }
    if ($args1[0] -eq 'ultimos') { return [pscustomobject]@{ ok = $true; correos = @() } }
    # enviar / responder
    $script:enviados += ,@($args1)
    return [pscustomobject]@{ ok = $true }
}

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- leer: no pregunta y no envia nada --"
$r = Invoke-Correo @{ accion = 'no-leidos' }
Comp 'cuenta los correos y dice de quien son' ($r -match 'Tienes 2 correos nuevos' -and $r -match 'Steam Support' -and $r -match 'Chase') "$r"
Comp 'y no ha enviado nada' ($script:enviados.Count -eq 0) ''
$r = Invoke-Correo @{ accion = 'leer' }
Comp 'leer el ultimo trae el texto' ($r -match 'De Steam Support' -and $r -match 'Tu regalo ha sido aceptado') "$r"

Write-Host "  -- enviar: SIEMPRE pregunta antes --"
$script:confirmado = $false; $script:pendiente = $null; $script:enviados = @()
$r = Invoke-Correo @{ accion = 'responder'; texto = 'gracias, ya lo vi' }
Comp 'responder pregunta antes de enviar' ($r -match '¿Lo envio\?' -and $r -match 'gracias, ya lo vi') "$r"
Comp 'y NO ha enviado nada todavia' ($script:enviados.Count -eq 0) ''
Comp 'queda pendiente de un si, como una orden peligrosa' ($script:pendiente -and $script:pendiente.tipo -eq 'peligrosa') ''

# ahora, con el si dicho
$script:confirmado = $true
$r = Invoke-Correo @{ accion = 'responder'; texto = 'gracias, ya lo vi' }
Comp 'con el si, se envia' ($r -eq 'Enviado.' -and $script:enviados.Count -eq 1) "$r"
Comp 'y va con la marca de confirmado' ($script:enviados[0] -contains '--confirmado') ($script:enviados[0] -join ' ')

Write-Host "  -- mandar a alguien --"
$script:confirmado = $false; $script:pendiente = $null; $script:enviados = @()
$r = Invoke-Correo @{ accion = 'enviar'; destino = 'lucia@ejemplo.com'; texto = 'llego tarde' }
Comp 'lee a quien va y que dice' ($r -match 'lucia@ejemplo.com' -and $r -match 'llego tarde' -and $r -match '¿Lo envio\?') "$r"
Comp 'sin enviar nada' ($script:enviados.Count -eq 0) ''
$script:confirmado = $false
$r = Invoke-Correo @{ accion = 'enviar'; destino = 'mi hermano'; texto = 'hola' }
Comp 'sin direccion, la pide en vez de adivinar' ($r -match 'Dimela entera|No se cual es el correo') "$r"
Comp 'y tampoco envia' ($script:enviados.Count -eq 0) ''

Write-Host "  -- responder sin haber mirado el correo --"
$script:correoUltimo = $null; $script:confirmado = $true; $script:enviados = @()
$r = Invoke-Correo @{ accion = 'responder'; texto = 'vale' }
Comp 'no responde a ciegas' ($r -match 'revisa mi correo' -and $script:enviados.Count -eq 0) "$r"

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
