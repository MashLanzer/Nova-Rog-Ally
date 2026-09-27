# UN SOLO ESTADO DE RED, EN VEZ DE DIECISEIS PLAZOS SUELTOS (27/09, idea 84 de las 121)
#
# EL PROBLEMA: cada pieza descubria por su cuenta que no hay red y pagaba su propio plazo. En
# assistant.ps1 hay siete plazos escritos a mano (tienda de Steam 3 s, YouTube 6 s, ip-api 4 s,
# open-meteo 4 s, amigos 10 s, correo 25 s, correo de la manana 30 s) y en charla_worker.py nueve
# mas; adaptativos, solo dos. Y un grep de Test-Connection, NetworkAvailability, Test-Red, hayRed y
# sinRed sobre los cuatro fuentes daba CERO: no existia ninguna funcion que supiera si hay red.
#
# LO QUE ESTE BANCO PROTEGE, y el primero es el que de verdad importa:
#   1. que UN servicio caido (Steam en mantenimiento) NO apague el clima, el correo y los amigos:
#      hacen falta DOS servicios DISTINTOS
#   2. que cualquier exito borre la caida al instante
#   3. que la caida CADUQUE: un modo sin salida no puede existir (regla 2 de la casa)
#   4. que lo que pide braya en voz alta no se bloquee nunca, solo se le acorte el plazo
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('Set-RedOk', 'Set-RedFallo', 'Test-RedParaFondo', 'Get-PlazoRed')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$RedFallosParaCaida = 2
$RedCaidaViejaMs = 300000
Comp 'hacen falta dos servicios distintos' ($txt -match '\$RedFallosParaCaida = 2') ''
Comp 'y la caida caduca a los cinco minutos' ($txt -match '\$RedCaidaViejaMs = 300000') 'ningun modo sin salida'

$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-red-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$RedJson = Join-Path $TmpDir 'red.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$ruta, [string]$contenido) { [IO.File]::WriteAllText($ruta, $contenido, $UTF8) }
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
$script:msFalsos = 1000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:redUltimoOk = 0
    $script:redFallosSeguidos = 0
    $script:redQuienFallo = @()
    $script:redCaidaDesde = 0
    $script:logs = @()
    $script:msFalsos = 1000000
}

try {
    Write-Host ''
    Write-Host '-- 1. UN SOLO SERVICIO CAIDO NO ES LA RED CAIDA --'
    Reset
    Comp '1a. de entrada, la red se da por buena' (Test-RedParaFondo) 'sin datos, se intenta'
    Set-RedFallo 'steam'
    Comp '1b. con Steam en mantenimiento, se sigue intentando lo demas' (Test-RedParaFondo) 'esto es lo que protege la guarda'
    Set-RedFallo 'steam'
    Set-RedFallo 'steam'
    Comp '1c. ni con Steam fallando tres veces' (Test-RedParaFondo) 'el mismo servicio no cuenta dos veces'
    Comp '1d. y no se ha dado por caida' ($script:redCaidaDesde -eq 0) ''

    Write-Host ''
    Write-Host '-- 2. DOS DISTINTOS SI --'
    Set-RedFallo 'clima'
    Comp '2a. steam + clima: la red esta caida' (-not (Test-RedParaFondo)) ''
    Comp '2b. y lo dice, con quienes' (@($script:logs | Where-Object { $_ -match 'doy la red por caida' -and $_ -match 'steam' -and $_ -match 'clima' }).Count -eq 1) (@($script:logs | Where-Object { $_ -match 'caida' }) -join ' | ')
    Comp '2c. y queda escrito en el json' ((Get-Content -LiteralPath $RedJson -Raw) -match '"caida":1') (Get-Content -LiteralPath $RedJson -Raw)

    Write-Host ''
    Write-Host '-- 3. CUALQUIER EXITO LA BORRA AL INSTANTE --'
    Set-RedOk 'ip-api'
    Comp '3a. un exito y vuelve a haber red' (Test-RedParaFondo) ''
    Comp '3b. la cuenta de fallos a cero' ($script:redFallosSeguidos -eq 0 -and @($script:redQuienFallo).Count -eq 0) ''
    Comp '3c. y lo dice' (@($script:logs | Where-Object { $_ -match 'vuelvo a contar con la red' }).Count -eq 1) ''
    Comp '3d. el json tambien' ((Get-Content -LiteralPath $RedJson -Raw) -match '"caida":0') ''

    Write-Host ''
    Write-Host '-- 4. LA CAIDA CADUCA (ningun modo sin salida) --'
    Reset
    Set-RedFallo 'steam'; Set-RedFallo 'clima'
    Comp '4a. caida' (-not (Test-RedParaFondo)) ''
    $script:msFalsos += $RedCaidaViejaMs - 1000
    Comp '4b. a los cuatro minutos, sigue caida' (-not (Test-RedParaFondo)) ''
    $script:msFalsos += 2000
    Comp '4c. pasados los cinco, se vuelve a probar' (Test-RedParaFondo) 'sin esperar a un exito que nadie va a pedir'
    Comp '4d. y lo dice' (@($script:logs | Where-Object { $_ -match 'vuelvo a probar' }).Count -eq 1) ''

    Write-Host ''
    Write-Host '-- 5. EL PLAZO SE ACORTA, NO SE BLOQUEA --'
    Reset
    Comp '5a. con red buena, el plazo escrito' ((Get-PlazoRed 4) -eq 4) '4 s'
    Set-RedFallo 'steam'
    Comp '5b. con un fallo, la mitad' ((Get-PlazoRed 4) -eq 2) 'no se regalan segundos cuando ya se sabe'
    Set-RedFallo 'clima'
    Comp '5c. y con la red caida, tambien la mitad (no cero)' ((Get-PlazoRed 4) -eq 2) 'lo que pide braya se intenta igual'
    Comp '5d. un plazo de 1 s no baja a cero' ((Get-PlazoRed 1) -ge 1) 'cero seria no intentarlo'
    Comp '5e. y un plazo absurdo no revienta' ((Get-PlazoRed 0) -ge 1) ''

    Write-Host ''
    Write-Host '-- 6. QUIEN PREGUNTA Y QUIEN NO --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    # las tres de fondo preguntan
    Comp '6a. el clima pregunta antes de salir a la red' ($sinCom -match '(?s)function Update-Clima.{0,3000}Test-RedParaFondo') ''
    Comp '6b. la ubicacion por IP tambien' ($sinCom -match "(?s)Test-RedParaFondo\) \{[^\r\n]*\r?\n[^\r\n]*ip-api") ''
    Comp '6c. la ficha de Steam tambien' ($sinCom -match '(?s)function Get-FichaDosSteam.{0,1200}Test-RedParaFondo') ''
    Comp '6d. y el correo de la manana' ($sinCom -match '(?s)function Start-CorreoManana.{0,400}Test-RedParaFondo') ''
    # y los exitos/fallos se apuntan
    Comp '6e. el clima apunta su exito y su fallo' (($sinCom -match "Set-RedOk 'clima'") -and ($sinCom -match "Set-RedFallo 'clima'")) ''
    Comp '6f. ip-api tambien' (($sinCom -match "Set-RedOk 'ip-api'") -and ($sinCom -match "Set-RedFallo 'ip-api'")) ''
    # LO QUE NO DEBE PASAR: que la charla o el correo que pide braya se bloqueen
    Comp '6g. la charla NO pregunta por la red' (-not ($sinCom -match '(?s)function Send-Charla\b.{0,800}Test-RedParaFondo')) 'lo que pide braya no se bloquea nunca'
    Comp '6h. ni el correo que pide braya' (-not ($sinCom -match '(?s)function Invoke-CorreoScript.{0,600}Test-RedParaFondo')) ''
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'hay un solo estado de red, y un servicio caido no apaga los demas' -ForegroundColor Green
exit 0
