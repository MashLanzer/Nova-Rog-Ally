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
# LA PUERTA POR LA QUE SALE LA VOZ (27/09, idea 92), doblada: aqui solo interesa QUE se dijo y con
# que nivel, no la maquinaria de avisos, que tiene sus propios bancos. Devuelve $true = salio.
$script:saleElAviso = $true
$script:dichos = @()
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60, [bool]$yaEsperado = $false) {
    if (-not $script:saleElAviso) { return $false }
    $script:dichos += @{ clave = $clave; texto = $texto; nivel = $nivel }
    return $true
}
$script:msFalsos = 1000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:redUltimoOk = 0
    $script:redFallosSeguidos = 0
    $script:redQuienFallo = @()
    $script:redCaidaDesde = 0
    $script:logs = @()
    $script:dichos = @()
    $script:redAvisada = $false
    $script:saleElAviso = $true
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

    Write-Host ''
    Write-Host '-- 7. Y SE LO DICE, UNA VEZ (27/09, idea 92 de las 121) --'
    # EL HUECO: Nova se quedaba sin clima, sin resumen del dia y sin voz en linea, contestaba a
    # medias y no explicaba por que. Un grep de 'sin-red' en las 32.900 lineas daba CERO.
    #
    # Y OJO CON EL DATO DE LA FICHA: de los fallos del registro, las 756 lineas 'no pude resumir'
    # son TODAS del 26/09, una por minuto, y son WinError 10061 -conexion denegada- contra Ollama
    # en localhost. Eso no es falta de red. Los fallos de red de verdad son 11 en 16 dias: 8 del
    # clima (DNS de api.open-meteo.com) y 3 de la voz en linea.
    Reset
    Set-RedFallo 'clima'
    Comp '7a. con un servicio caido todavia no dice nada' (@($script:dichos).Count -eq 0) 'no hay red caida que contar'
    Set-RedFallo 'ip-api'
    Comp '7b. al darla por caida lo dice' (@($script:dichos).Count -eq 1) ([string]@($script:dichos).Count)
    Comp '7c. con la clave de red' ($script:dichos[0].clave -eq 'sin-red') ([string]$script:dichos[0].clave)
    Comp '7d. y se oye, no se queda en la capsula' ($script:dichos[0].nivel -eq 'medio') ("nivel '" + [string]$script:dichos[0].nivel + "'")
    Comp '7e. diciendo lo que va a pasar, no solo que falla' ($script:dichos[0].texto -match 'esperar') ([string]$script:dichos[0].texto)
    # y no lo repite en cada fallo nuevo
    Set-RedFallo 'steam'
    Comp '7f. y no lo repite con el tercer fallo' (@($script:dichos).Count -eq 1) 'la caida ya estaba contada'

    Write-Host ''
    Write-Host '-- 8. Y CUANDO VUELVE, TAMBIEN --'
    Set-RedOk 'clima'
    Comp '8a. al volver lo dice' (@($script:dichos).Count -eq 2) ([string]@($script:dichos).Count)
    Comp '8b. con su propia clave' ($script:dichos[1].clave -eq 'red-vuelve') ([string]$script:dichos[1].clave)
    Comp '8c. y corto' ($script:dichos[1].texto.Length -lt 40) ([string]$script:dichos[1].texto)
    Set-RedOk 'ip-api'
    Comp '8d. y no lo repite en cada exito' (@($script:dichos).Count -eq 2) 'la bandera se apaga al decirlo'

    Write-Host ''
    Write-Host '-- 9. LA GUARDA: SI NO SE DIJO LA IDA, NO SE DICE LA VUELTA --'
    # Si braya no oyo que no habia internet -habia un juego delante, o el tope por hora estaba
    # gastado-, contarle que "ya volvio" es hablarle de algo que nunca le contaron.
    Reset
    $script:saleElAviso = $false
    Set-RedFallo 'clima'; Set-RedFallo 'ip-api'
    Comp '9a. el aviso de ida no sale' (@($script:dichos).Count -eq 0) 'como con un juego delante'
    $script:saleElAviso = $true
    Set-RedOk 'clima'
    Comp '9b. y entonces el de vuelta tampoco' (@($script:dichos).Count -eq 0) ([string]@($script:dichos).Count)
    Comp '9c. pero la caida SI se borro' ($script:redCaidaDesde -eq 0) 'el aviso es lo unico que se calla'

    Write-Host ''
    Write-Host '-- 10. EL CABLEADO --'
    Comp '10a. los dos avisos no se aparcan' (($txt -match "'sin-red', 'red-vuelve'") -and ($txt -match '\$AvisoSiempre = @\(')) 'un aviso de red soltado tres horas despues es ruido'
    Comp '10b. y estan dentro de AvisoSiempre, no en otra lista' ($txt -match "(?s)\`$AvisoSiempre = @\([^)]*'sin-red', 'red-vuelve'\)") ''
    Comp '10c. el de ida sale del if de dar por caida' ($sinCom -match "(?s)redCaidaDesde = \`$sw\.ElapsedMilliseconds.{0,900}Send-AvisoEntorno 'sin-red'") 'no en cada fallo'
    Comp '10d. y guarda si se dijo' ($sinCom -match "\`$script:redAvisada = \[bool\]\(Send-AvisoEntorno 'sin-red'") ''
    Comp '10e. el de vuelta pregunta por esa bandera' ($sinCom -match "(?s)if \(\`$script:redAvisada\) \{.{0,200}Send-AvisoEntorno 'red-vuelve'") ''
    Comp '10f. y el diario NO llama a Set-RedFallo' (-not ($sinCom -match "Set-RedFallo 'diario'")) 'Ollama en localhost caido no es falta de red'
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'hay un solo estado de red, y un servicio caido no apaga los demas' -ForegroundColor Green
exit 0
