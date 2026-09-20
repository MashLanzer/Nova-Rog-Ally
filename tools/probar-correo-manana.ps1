# EL CORREO DE LA MANANA (idea 22, 18/09). Las DOS funciones que lo hacen -Start-CorreoManana
# y Receive-CorreoManana- no tenian ni una prueba (H2m4 de REVISION-2026-09-18.md:183).
#
# Lo que se mide aqui es lo que duele si se rompe:
#   1. que NO congele el bucle: se lanza y se recoge en otra vuelta, nunca se espera.
#      Invoke-CorreoScript espera hasta 25 s; llamarlo desde el bucle deja a Nova sorda
#      ese rato. Por eso se comprueba tambien en el TEXTO de la funcion.
#   2. que en el log solo quede CUANTOS habia: ni remitentes ni asuntos (es correo suyo).
#   3. que si el correo tarda o contesta mal, se limpie y se pueda volver a mirar manana,
#      en vez de quedarse enganchada con $correoOut puesto para siempre.
# No se toca la cuenta de verdad: el python se sustituye por un Start-Process de mentira
# y las respuestas se escriben a mano en una carpeta temporal.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txtStart = Traer 'Start-CorreoManana'
$txtRecibe = Traer 'Receive-CorreoManana'
Invoke-Expression $txtStart
Invoke-Expression $txtRecibe
Invoke-Expression (Traer 'Format-Correos')

# --- el mundo de mentira ---
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-correo-manana-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$LogDir = $raiz
$PyWorker = 'python-que-no-existe.exe'
$CorreoScript = Join-Path $LogDir 'tools\correo.py'
$script:reloj = 100000
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }

$script:correoProc = $null
$script:correoOut = ''
$script:correoVence = 0
$script:listo = $true
$script:lanzados = @()
$script:log = @()
$script:avisos = @()

function Test-CorreoListo { return $script:listo }
function Log($m) { $script:log += [string]$m }
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    $script:avisos += , ([pscustomobject]@{ clave = $clave; texto = $texto; nivel = $nivel; cadaMin = $cadaMin })
    return $true
}
# Start-Process de mentira: una funcion tapa al cmdlet, asi que no se arranca nada.
$global:matadosG = 0
function Start-Process {
    param([string]$FilePath, [string]$WindowStyle, [switch]$PassThru, [string]$WorkingDirectory, [string[]]$ArgumentList)
    $script:lanzados += , ([pscustomobject]@{ exe = $FilePath; args = @($ArgumentList); dir = $WorkingDirectory })
    $p = [PSCustomObject]@{ Handle = 1; HasExited = $false }
    $p | Add-Member -MemberType ScriptMethod -Name Kill -Value { $global:matadosG++ }
    return $p
}
# lo que contestaria el python, escrito a mano donde Nova lo espera
function Contesta($obj) {
    $j = $obj | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($script:correoOut, $j, (New-Object System.Text.UTF8Encoding($false)))
}
function Limpia {
    $script:correoProc = $null; $script:correoOut = ''; $script:correoVence = 0
    $script:lanzados = @(); $script:log = @(); $script:avisos = @(); $global:matadosG = 0
}
$dosCorreos = [pscustomobject]@{ ok = $true; cuantos = 2; correos = @(
        [pscustomobject]@{ n = 12; de = 'Steam Support'; asunto = 'Your Steam gift has been accepted'; fecha = '19/09 08:02' },
        [pscustomobject]@{ n = 11; de = 'Chase'; asunto = 'Aviso de saldo'; fecha = '19/09 07:14' }) }

$fallos = 0
function Comp([string]$etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

try {
    Write-Host "  -- lanzarlo: solo si hay con que, y solo uno --"
    $script:listo = $false
    Comp 'sin correo configurado, ni lo intenta' ((Start-CorreoManana) -eq $false -and $script:lanzados.Count -eq 0) ''
    Comp 'y no se queda un $correoOut colgando' ($script:correoOut -eq '') "'$($script:correoOut)'"
    $script:listo = $true

    Limpia
    $arranco = Start-CorreoManana
    Comp 'con el correo listo, lo lanza' ($arranco -eq $true -and $script:lanzados.Count -eq 1) ''
    $ar = @($script:lanzados[0].args)
    Comp 'pide los no leidos, y solo 5' ($ar[0] -eq $CorreoScript -and $ar[1] -eq 'no-leidos' -and $ar[2] -eq '5') ($ar -join ' ')
    Comp 'con el fichero de respuesta que luego mira' ($ar[3] -eq $script:correoOut -and $script:correoOut) "$($script:correoOut)"
    Comp 'y se da 30 s de plazo' ($script:correoVence -eq ($script:reloj + 30000)) "$($script:correoVence)"

    $antes = $script:lanzados.Count
    Comp 'si ya hay una mirando, no lanza otra' ((Start-CorreoManana) -eq $false -and $script:lanzados.Count -eq $antes) ''

    Write-Host "  -- recoger: en otra vuelta, sin congelar el bucle --"
    # Nova no espera: mientras el python no conteste, recoger no hace nada y no avisa.
    Receive-CorreoManana
    Comp 'si aun no ha contestado, ni avisa ni suelta el sitio' ($script:avisos.Count -eq 0 -and $script:correoOut -ne '') ''

    $salida = $script:correoOut
    Contesta $dosCorreos
    Receive-CorreoManana
    Comp 'con la respuesta, avisa una vez' ($script:avisos.Count -eq 1) "$($script:avisos.Count)"
    if ($script:avisos.Count -eq 1) {
        $av = $script:avisos[0]
        Comp 'con la clave del correo de la manana' ($av.clave -eq 'correo-manana') "$($av.clave)"
        Comp 'de nivel medio: se ve, no interrumpe' ($av.nivel -eq 'medio') "$($av.nivel)"
        Comp 'y una vez cada 12 h, aunque Nova se reinicie' ($av.cadaMin -eq 720) "$($av.cadaMin)"
        Comp 'el aviso dice quien escribe' ($av.texto -match 'Steam Support' -and $av.texto -match 'Chase') "$($av.texto)"
    }
    # el log es un fichero que se queda: ahi NO puede acabar su correo
    $logC = @($script:log) -join ' | '
    Comp 'el log dice cuantos habia' ($logC -match '2 sin leer') "$logC"
    Comp 'y NI remitentes NI asuntos en el log' (-not ($logC -match 'Steam|Chase|gift|saldo')) "$logC"
    Comp 'borra el fichero con el correo dentro' (-not (Test-Path -LiteralPath $salida)) ''
    Comp 'y suelta el sitio para el dia siguiente' ($script:correoOut -eq '' -and $null -eq $script:correoProc) ''

    Write-Host "  -- cuando no hay nada que contar, callarse --"
    Limpia
    [void](Start-CorreoManana)
    Contesta ([pscustomobject]@{ ok = $true; cuantos = 0; correos = @() })
    Receive-CorreoManana
    Comp 'sin correos nuevos, no dice nada' ($script:avisos.Count -eq 0) ''
    Comp 'pero se limpia igual' ($script:correoOut -eq '') ''

    Limpia
    [void](Start-CorreoManana)
    Contesta ([pscustomobject]@{ ok = $false; error = 'no pude entrar' })
    Receive-CorreoManana
    Comp 'si el correo fallo, no inventa un aviso' ($script:avisos.Count -eq 0) ''
    Comp 'y tampoco se queda enganchada' ($script:correoOut -eq '') ''

    Limpia
    [void](Start-CorreoManana)
    [System.IO.File]::WriteAllText($script:correoOut, '{esto no es json', (New-Object System.Text.UTF8Encoding($false)))
    $rotoOk = $true
    try { Receive-CorreoManana } catch { $rotoOk = $false }
    Comp 'con la respuesta rota, no revienta ni avisa' ($rotoOk -and $script:avisos.Count -eq 0) ''
    Comp 'y deja el sitio libre' ($script:correoOut -eq '') ''

    Write-Host "  -- el que no contesta: matarlo y poder volver a mirar --"
    Limpia
    [void](Start-CorreoManana)
    $salida = $script:correoOut
    $script:reloj += 29000
    Receive-CorreoManana
    Comp 'a los 29 s todavia espera' ($script:correoOut -eq $salida -and $global:matadosG -eq 0) ''
    $script:reloj += 2000
    Receive-CorreoManana
    Comp 'pasado el plazo, mata el proceso' ($global:matadosG -eq 1) "$($global:matadosG)"
    Comp 'lo apunta en el log' ((@($script:log) -join ' | ') -match 'no contesto a tiempo') ''
    Comp 'no avisa de un correo que no ha leido' ($script:avisos.Count -eq 0) ''
    Comp 'y manana se puede volver a mirar' ($script:correoOut -eq '' -and $null -eq $script:correoProc) ''
    $script:reloj = 100000
    Limpia
    Comp 'tras el plazo, vuelve a lanzarse' ((Start-CorreoManana) -eq $true) ''

    Write-Host "  -- que nadie lo 'simplifique' a una espera --"
    # Si alguien cambia el Start-Process por Invoke-CorreoScript, todo lo de arriba sigue
    # en verde y Nova se queda sorda 25 s cada manana. Eso no se ve probando: se mira el texto.
    Comp 'Start-CorreoManana no espera a nadie' (-not ($txtStart -match 'WaitForExit|Invoke-CorreoScript')) ''
    Comp 'Receive-CorreoManana tampoco' (-not ($txtRecibe -match 'WaitForExit|Invoke-CorreoScript|Start-Sleep')) ''
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
