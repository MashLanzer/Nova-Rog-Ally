# EN LA MESA O EN LAS MANOS (27/09, idea 69 de las 121)
#
# DOS SENALES QUE NO COSTABAN NADA Y NO SE USABAN:
#   1. dwPacketNumber del mando. XInput solo lo sube cuando el mando cambia de estado, y el estado
#      ya se leia cada 30 ms: de la struct solo se usaba wButtons. Aparecia CERO veces en las
#      31.000 lineas del script. Medido hoy: puerto 0, paquete 11481, y 700 ms despues sin tocarlo
#      sigue en 11481; las setas tienen valor en reposo (LX=0 LY=-1), asi que cualquier roce lo mueve.
#   2. SimpleOrientationSensor. PRESENTE en esta Ally, devuelve Faceup, 0,157 ms por lectura (200
#      llamadas). El acelerometro daria lo mismo y cuesta 15,52 ms: por eso sigue apagado.
#
# LO QUE SE GANA, y lo mas importante NO estaba en la ficha: GetLastInputInfo -la unica senal de
# presencia que habia- NO cuenta el mando. Jugando una hora con el mando, para Windows braya lleva
# una hora sin tocar nada, asi que Nova podia dar por hecho que no hay nadie y aparcar avisos con
# el delante.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que sin datos NO se afirme nada (umbral sin aprender, sensor apagado, mando sin ver -> false)
#   2. que el umbral de 'quieto' salga de los huecos de braya y no de un numero escrito
#   3. que el mando recorte Get-NadieMin y no compita con las otras dos senales
#   4. que la pista del mando desaparezca solo cuando esta en la mesa
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
foreach ($f in @('Get-PercentilLista', 'Get-HuecosMando', 'Add-HuecoMando', 'Get-QuietudMando',
                 'Get-UmbralQuietud', 'Get-EnLaMesa', 'Get-PistaMando', 'Watch-Orientacion')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
function Log([string]$m) { $script:logs += @($m) }
$script:logs = @()
function Write-Atomico([string]$ruta, [string]$contenido) {
    [IO.File]::WriteAllText($ruta, $contenido, (New-Object Text.UTF8Encoding($false)))
}
# el reloj del bucle, de mentira pero con la misma cara
$script:msFalsos = 600000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }

$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-mesa-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $MemoriaDir -Force | Out-Null
$MandoHuecosJson = Join-Path $MemoriaDir 'mando-huecos.json'
$MandoHuecosMax = 300
$MandoHuecosMin = 20
$MandoQuietoPct = 90
# los cuatro numeros, sacados del archivo: si alli cambian y aqui no, se ve
Comp 'el tope de huecos guardados es 300' ($txt -match '\$MandoHuecosMax = 300') ''
Comp 'el minimo de muestras es 20' ($txt -match '\$MandoHuecosMin = 20') ''
Comp 'y el percentil es el 90' ($txt -match '\$MandoQuietoPct = 90') 'un hueco mas largo que el 90 % de los suyos'

try {
    Write-Host ''
    Write-Host '-- 1. SIN DATOS NO SE AFIRMA NADA --'
    $script:mandoHay = $false
    $script:mandoMovidoEn = -100000
    $script:orientacionPlana = $false
    Comp '1a. sin mando visto, la quietud es -1 (no lo se)' ((Get-QuietudMando) -lt 0) 'no es "esta quieto"'
    Comp '1b. sin huecos aprendidos, el umbral es 0' ((Get-UmbralQuietud) -eq 0) 'que es "no me preguntes todavia"'
    Comp '1c. y Get-EnLaMesa dice NO' (-not (Get-EnLaMesa)) 'no se inventa una certeza'
    $script:mandoHay = $true
    $script:mandoMovidoEn = 1000            # se movio hace 599 s
    Comp '1d. con mando pero sin umbral, sigue diciendo NO' (-not (Get-EnLaMesa)) ''
    Comp '1e. y con umbral pero sin estar tumbada, tambien NO' $true 'se prueba abajo, con datos'

    Write-Host ''
    Write-Host '-- 2. EL UMBRAL SALE DE SUS PROPIOS HUECOS --'
    # 19 huecos: todavia no hay bastante
    for ($i = 1; $i -le 19; $i++) { [void](Add-HuecoMando 10) }
    Comp '2a. con 19 muestras, el umbral aun es 0' ((Get-UmbralQuietud) -eq 0) ([string](@(Get-HuecosMando)).Count + ' muestras')
    [void](Add-HuecoMando 10)
    Comp '2b. con 20 ya contesta' ((Get-UmbralQuietud) -gt 0) ([string](Get-UmbralQuietud) + ' s')
    # ahora unos huecos de partida (cortos) y unos pocos largos: el p90 tiene que quedar arriba
    Remove-Item -LiteralPath $MandoHuecosJson -Force
    foreach ($h in @(2, 3, 2, 4, 3, 2, 5, 3, 2, 4, 6, 3, 2, 4, 3, 2, 8, 3, 2, 40)) { [void](Add-HuecoMando $h) }
    $u2 = Get-UmbralQuietud
    $med2 = Get-PercentilLista (Get-HuecosMando) 50
    Comp '2c. el p90 queda por encima de la mediana de sus huecos' ($u2 -gt $med2) ('p90=' + [string]$u2 + ' s, mediana=' + [string]$med2 + ' s')
    Comp '2d. y no es el mayor (no basta con un hueco raro)' ($u2 -lt 40) ([string]$u2 + ' < 40')
    Comp '2e. el percentil es la pieza comun, no una copia' ($txt -match 'return \(Get-PercentilLista \$lista \$pct\)') 'Get-TrabajoPercentil usa la misma'

    Write-Host ''
    Write-Host '-- 3. LAS DOS SENALES, LAS DOS --'
    $script:mandoHay = $true
    $script:msFalsos = 600000
    $script:mandoMovidoEn = 600000 - (($u2 + 5) * 1000)    # quieto mas que el umbral
    $script:orientacionPlana = $true
    Comp '3a. tumbada Y el mando quieto de mas: esta en la mesa' (Get-EnLaMesa) ([string](Get-QuietudMando) + ' s quieto, umbral ' + [string]$u2)
    $script:orientacionPlana = $false
    Comp '3b. el mando quieto pero en la mano: NO es la mesa' (-not (Get-EnLaMesa)) 'leyendo un dialogo tambien esta quieto'
    $script:orientacionPlana = $true
    $script:mandoMovidoEn = 600000 - 1000                  # se movio hace 1 s
    Comp '3c. tumbada pero el mando moviendose: NO es la mesa' (-not (Get-EnLaMesa)) 'jugando en la cama'

    Write-Host ''
    Write-Host '-- 4. LA PISTA DEL MANDO SOLO CUANDO ES UNA VIA REAL --'
    # 41 lineas CONFIRMAR en los dos logs = 20 preguntas; 5 murieron por plazo y NINGUNA se
    # contesto con el mando. Ofrecerla con el mando en la mesa ensena un camino que no existe.
    $script:juegoActivo = $null
    $script:mandoMovidoEn = 600000 - 1000
    Comp '4a. con el mando en la mano, se ofrece' ((Get-PistaMando 'normal') -match 'A si') (Get-PistaMando 'normal')
    $script:mandoMovidoEn = 600000 - (($u2 + 5) * 1000)
    Comp '4b. con el mando en la mesa, no se ofrece' ((Get-PistaMando 'normal') -eq '') 'la pregunta se contesta hablando'
    $script:mandoHay = $false
    Comp '4c. y sin mando, como antes: nada' ((Get-PistaMando 'normal') -eq '') ''

    Write-Host ''
    Write-Host '-- 5. EL MANDO CUENTA COMO PRESENCIA (lo que GetLastInputInfo no ve) --'
    Comp '5a. Get-NadieMin mira la quietud del mando' ($txt -match '\$qm = \[int\]\(Get-QuietudMando\)') ''
    Comp '5b. y RECORTA el resultado, no compite' ($txt -match 'if \(\$mMando -lt \$res\) \{ \$res = \$mMando \}') 'si se movio hace 1 min, no llevo 50 sin nadie'
    Comp '5c. el bucle lee el paquete solo del puerto 0' ($txt -match 'if \(\$u -eq 0\) \{') 'los otros tres estan aplazados (idea 66)'
    Comp '5d. y guarda el hueco que se cierra' ($txt -match '\[void\]\(Add-HuecoMando \$huecoS\)') 'asi aprende su propio umbral'

    Write-Host ''
    Write-Host '-- 6. EL SENSOR DE VERDAD, LEIDO AQUI --'
    $script:orientacion = $null
    $script:orientaProbado = $false
    $script:orientacionPlana = $false
    $script:orientaPlanaEn = 0
    $hay = $false
    try {
        $null = [Windows.Devices.Sensors.SimpleOrientationSensor, Windows.Devices.Sensors, ContentType = WindowsRuntime]
        $script:orientacion = [Windows.Devices.Sensors.SimpleOrientationSensor]::GetDefault()
        $hay = [bool]$script:orientacion
    } catch { $hay = $false }
    if (-not $hay) {
        Write-Host '  --   esta maquina no tiene sensor de orientacion; el resto del banco no depende de el'
    } else {
        $script:logs = @()
        # EL ESTRENO CUESTA (cazado aqui el 27/09): la PRIMERA GetCurrentOrientation de la sesion
        # tarda 11,96 ms y en caliente 1,86. La guarda de Watch-Orientacion media la primera, asi
        # que desactivaba el sensor para siempre en la unica consola donde funciona. Ahora calienta
        # con una lectura que no cuenta y juzga la segunda; este caso es el que lo vigila.
        $cron = [Diagnostics.Stopwatch]::StartNew()
        Watch-Orientacion
        $cron.Stop()
        Comp '6a. el estreno NO desactiva el sensor' ([bool]$script:orientacion) (@($script:logs) -join ' | ')
        Comp '6b. y dice en el registro lo que midio' (@($script:logs | Where-Object { $_ -match 'orientacion: lecturas OK' }).Count -eq 1) ''
        Comp '6c. y la guarda calienta antes de medir' ((Traer 'Watch-Orientacion') -match 'LA PRIMERA LECTURA NO VALE PARA MEDIR') ([string][Math]::Round($cron.Elapsed.TotalMilliseconds, 1) + ' ms tardo el estreno entero aqui')
        # y una segunda pasada, ya sin la prueba de estreno
        $cron2 = [Diagnostics.Stopwatch]::StartNew()
        Watch-Orientacion
        $cron2.Stop()
        Comp '6d. y en caliente, menos todavia' ($cron2.Elapsed.TotalMilliseconds -lt 5) ([string][Math]::Round($cron2.Elapsed.TotalMilliseconds, 3) + ' ms')
        Write-Host ('       la consola esta ' + $(if ($script:orientacionPlana) { 'TUMBADA' } else { 'en la mano / de pie' }) + ' ahora mismo')
    }
    Comp '6e. lleva la guarda de apagarse si tarda' ((Traer 'Watch-Orientacion') -match 'orientacion: lectura lenta o vacia') 'la misma que el acelerometro'
    Comp '6f. y no se lee mas de una vez por segundo' ($txt -match '\$script:orientaCheck\) -ge 1000') ''
} finally {
    Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova sabe si la consola esta en la mesa, y el mando cuenta como presencia' -ForegroundColor Green
exit 0
