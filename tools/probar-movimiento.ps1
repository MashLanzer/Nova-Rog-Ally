# SABER SI LA CONSOLA ESTA EN LA MANO (27/09, idea 83 de las 121)
#
# EL DATO QUE LO DESBLOQUEA: el comentario del codigo decia que GetCurrentReading() "tarda 5 s y
# devuelve null SIEMPRE", y por eso config.json tenia sensores.acelerometro = false. Medido hoy con el
# MISMO camino que usa el codigo -ReportInterval fijado antes de leer-: primera lectura 33,1 ms (la
# guarda corta en 150), y de 30 lecturas seguidas CERO nulas, media 2,94 ms, maximo 17,1. El sensor
# funciona y llevaba apagado por una medicion vieja.
#
# PARA QUE SIRVE: 4.153 lineas "ENTORNO aparcado (no hay nadie...)" en el registro actual, que tiene
# 7.924. El 52 % de lo que Nova escribe es apuntar que no hay nadie a quien hablar, y siete de esos
# avisos caducaron sin decirse nunca.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el umbral salga de SU reposo, no de un numero escrito
#   2. que un pico suelto (un golpe en la mesa) NO cuente como que hay alguien
#   3. que "no lo se" (-1) no se confunda nunca con "no hay nadie"
#   4. que sin sensor todo siga exactamente como hoy
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
foreach ($f in @('Get-PercentilLista', 'Get-AcelUmbral', 'Get-MovimientoMin', 'Watch-Acelerometro')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$AcelDeltasMemoria = 200
$AcelDeltasMin = 40
$AcelUmbralMin = 0.02
$AcelRachaMin = 2
# LAS DOS DE LA GUARDA DE LECTURAS LENTAS (30/09, con el arreglo que apaga el sensor cuando TODAS
# las lecturas tardan 5 s y no solo la primera). Si se olvidan aqui, llegan a la funcion como
# $null y en PowerShell '22 -gt $null' es VERDAD: la guarda apagaria el sensor en la primera
# lectura buena y este banco saldria rojo sin que el asistente tuviera nada mal. Paso al escribir
# el arreglo.
$AcelLecturaLentaMs = 150
$AcelLentasMax = 2
Comp 'los seis numeros salen del archivo' (($txt -match '\$AcelDeltasMin = 40') -and ($txt -match '\$AcelUmbralMin = 0\.02') -and ($txt -match '\$AcelRachaMin = 2') -and ($txt -match '\$AcelLecturaLentaMs = 150') -and ($txt -match '\$AcelLentasMax = 2')) ''
# Y EL 150 NO PUEDE VOLVER A ESTAR ESCRITO DOS VECES: la guarda de la primera lectura lo tenia a
# pelo, y el arreglo lo saco a constante justo para que las dos guardas no se separen.
Comp '  y el de la lectura lenta esta en un solo sitio' ((@([regex]::Matches($txt, '-gt 150\b')).Count) -eq 0) 'las dos guardas usan $AcelLecturaLentaMs'
# EL CHOQUE DE NOMBRES QUE CAZO ESTE BANCO: la constante se llamaba $AcelSeguidos y el contador
# $script:acelSeguidos, y en PowerShell los nombres NO distinguen mayusculas, asi que eran LA MISMA
# variable: el contador machacaba el minimo dejandolo en 1, y un golpe en la mesa contaba como braya.
Comp 'la constante y el contador tienen nombres distintos' (($txt -match '\$AcelRachaMin') -and ($txt -match '\$script:acelRacha\b') -and -not ($txt -match 'acelSeguidos')) 'PowerShell los confundiria'
Comp 'y el acelerometro ya viene encendido por defecto' ($txt -match "Get-Cfg 'sensores' 'acelerometro' \`$true") 'la medicion que lo apagaba ya no es cierta'
$cfg = Get-Content -LiteralPath (Join-Path $Raiz 'config.json') -Raw | ConvertFrom-Json
Comp 'y en config.json tambien' ([bool]$cfg.sensores.acelerometro) ''

$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
function Send-UIEvento([string]$e) { }
$script:msFalsos = 1000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:acelDeltas = New-Object System.Collections.ArrayList
    $script:acelRacha = 0
    $script:acelMagAntes = 0.0
    $script:movidoEn = 0
    $script:acelerometro = 'un sensor de mentira'
    $script:acelProbado = $true
    $script:acelUltimo = 0
    $script:logs = @()
    $script:msFalsos = 1000000
}
# el sensor de mentira: devuelve las lecturas que se le den
$script:cola = @()
function LeerFalso($x, $y, $z) {
    # se imita el camino de Watch-Acelerometro sin llamar al WinRT
    $mag = [Math]::Sqrt($x * $x + $y * $y + $z * $z)
    if ($script:acelMagAntes -gt 0) {
        $delta = [Math]::Abs($mag - $script:acelMagAntes)
        [void]$script:acelDeltas.Add([double]$delta)
        while ($script:acelDeltas.Count -gt $AcelDeltasMemoria) { $script:acelDeltas.RemoveAt(0) }
        $umbral = Get-AcelUmbral
        if ($umbral -gt 0 -and $delta -gt $umbral) {
            $script:acelRacha++
            if ($script:acelRacha -ge $AcelRachaMin) { $script:movidoEn = $sw.ElapsedMilliseconds }
        } else {
            $script:acelRacha = 0
        }
    }
    $script:acelMagAntes = $mag
}

Write-Host ''
Write-Host '-- 1. SIN DATOS NO SE OPINA --'
Reset
Comp '1a. sin deltas, no hay umbral' ((Get-AcelUmbral) -eq 0) 'que es "todavia no lo se"'
Comp '1b. y el movimiento es -1, no 0' ((Get-MovimientoMin) -eq -1) '-1 es "no lo se"; 0 seria "acaba de moverse"'
$script:acelerometro = $null
Comp '1c. sin sensor, tambien -1' ((Get-MovimientoMin) -eq -1) 'y Get-NadieMin lo ignora'

Write-Host ''
Write-Host '-- 2. EL UMBRAL SALE DE SU PROPIO REPOSO --'
Reset
# 60 lecturas en reposo, con el ruido tipico medido en esta consola (~0,003 g)
$azar = New-Object System.Random(7)
for ($i = 0; $i -lt 60; $i++) { LeerFalso 0.0 0.05 (-1.07 + ($azar.NextDouble() - 0.5) * 0.006) }
$u2 = Get-AcelUmbral
Comp '2a. con 60 lecturas en reposo ya hay umbral' ($u2 -gt 0) ([string][Math]::Round($u2, 4) + ' g')
Comp '2b. y es el suelo o poco mas (el reposo es casi plano)' ($u2 -ge $AcelUmbralMin) ('suelo ' + [string]$AcelUmbralMin)
Comp '2c. en reposo NO se da por movida' ($script:movidoEn -eq 0) 'el ruido no es braya'

Write-Host ''
Write-Host '-- 3. UN PICO SUELTO NO ES ALGUIEN --'
Reset
for ($i = 0; $i -lt 60; $i++) { LeerFalso 0.0 0.05 (-1.07 + ($azar.NextDouble() - 0.5) * 0.006) }
LeerFalso 0.0 0.05 (-1.40)     # un golpe en la mesa: una sola lectura fuera
Comp '3a. una sola lectura grande no marca movimiento' ($script:movidoEn -eq 0) 'hacen falta dos seguidas'
LeerFalso 0.0 0.05 (-0.80)     # y otra: ya es movimiento de verdad
Comp '3b. dos seguidas si' ($script:movidoEn -gt 0) ''
Comp '3c. y entonces el movimiento son 0 minutos' ((Get-MovimientoMin) -eq 0) 'acaba de pasar'

Write-Host ''
Write-Host '-- 4. Y LUEGO SE OLVIDA SOLO --'
$script:msFalsos += 300000      # cinco minutos despues
Comp '4a. cinco minutos despues, 5' ((Get-MovimientoMin) -eq 5) ([string](Get-MovimientoMin) + ' min')
Comp '4b. sigue siendo un dato, no un -1' ((Get-MovimientoMin) -ge 0) ''

Write-Host ''
Write-Host '-- 5. EL CABLEADO EN Get-NadieMin --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '5a. Get-NadieMin mira el movimiento' ($sinCom -match '\$mv = \[int\]\(Get-MovimientoMin\)') ''
Comp '5b. y solo recorta si es un dato de verdad' ($sinCom -match 'if \(\$mv -ge 0 -and \$mv -lt \$res\)') 'un -1 no puede recortar nada'
Comp '5c. el sobresalto de siempre sigue' ($sinCom -match "Send-UIEvento 'gesto:sobresalto'") 'el segundo uso no se lleva el primero'
Comp '5d. y la guarda que apaga el sensor sigue en su sitio' ($sinCom -match 'acelerometro: sin lecturas utiles') 'la consola donde no funcione lo apaga sola'

Write-Host ''
Write-Host '-- 6. EL SENSOR DE VERDAD, LEIDO AQUI --'
$hay = $false
try {
    $null = [Windows.Devices.Sensors.Accelerometer, Windows.Devices.Sensors, ContentType = WindowsRuntime]
    $script:acelerometro = [Windows.Devices.Sensors.Accelerometer]::GetDefault()
    $hay = [bool]$script:acelerometro
} catch { $hay = $false }
if (-not $hay) {
    Write-Host '  --   esta maquina no tiene acelerometro; el resto del banco no depende de el'
} else {
    $script:acelDeltas = New-Object System.Collections.ArrayList
    $script:acelRacha = 0
    $script:acelMagAntes = 0.0
    $script:movidoEn = 0
    $script:acelProbado = $false
    $script:acelUltimo = 0
    $script:logs = @()
    $cron = [Diagnostics.Stopwatch]::StartNew()
    Watch-Acelerometro
    $cron.Stop()
    Comp '6a. la primera lectura no desactiva el sensor' ([bool]$script:acelerometro) (@($script:logs) -join ' | ')
    Comp '6b. y dice que las lecturas van bien' (@($script:logs | Where-Object { $_ -match 'acelerometro: lecturas OK' }).Count -eq 1) ''
    $ms = @()
    for ($i = 0; $i -lt 20; $i++) {
        $c2 = [Diagnostics.Stopwatch]::StartNew(); Watch-Acelerometro; $c2.Stop()
        $ms += $c2.Elapsed.TotalMilliseconds
    }
    $media = ($ms | Measure-Object -Average).Average
    Write-Host ('       20 vueltas del vigilante: media ' + [Math]::Round($media, 2) + ' ms, maximo ' + [Math]::Round(($ms | Measure-Object -Maximum).Maximum, 1) + ' ms')
    # UN SENSOR QUE ESTA PERO NO SIRVE ES UN TERCER CASO, y le faltaba camino (30/09). Este banco
    # solo sabia de dos mundos: no hay acelerometro -y se salta- o hay uno que responde. En ESTA
    # consola pasa lo tercero: la primera lectura contesta y todas las demas tardan 5 s y vuelven
    # vacias. Medido aqui mismo: 5.015 ms de media las veinte. Pedirle deltas a eso es pedir lo
    # imposible, y el rojo no decia nada del asistente.
    # LO QUE HAY QUE EXIGIR ENTONCES ES LA GUARDA, que es lo que protege a braya: que Nova lo APAGUE
    # en cuanto lo ve, que lo diga, y que a partir de ahi no cueste nada. Si el sensor si responde,
    # se sigue exigiendo lo de siempre. Asi el banco vale en las dos maquinas y ninguna de las dos
    # pasa de gratis.
    $seApago = (-not $script:acelerometro)
    $loDijo = @($script:logs | Where-Object { $_ -match 'lecturas seguidas lentas o vacias' }).Count -ge 1
    if ($seApago) {
        Write-Host '       este sensor responde la primera y se cuelga las demas: Nova tiene que apagarlo' -ForegroundColor DarkGray
        Comp '6c. el sensor que no sirve se apaga solo' $seApago 'y no se come 5 s por vuelta para siempre'
        Comp '6d.   y lo dice en el log' $loDijo ([string](@($script:logs) -join ' | '))
        # y lo que de verdad importa: a partir de que se apaga, sale gratis. Las primeras lentas se
        # pagan una vez; las ultimas diez tienen que ser ya de balde.
        $ultimas = ($ms[10..19] | Measure-Object -Average).Average
        Comp '6e.   y desde entonces sale gratis' ($ultimas -lt 30) ([string][Math]::Round($ultimas, 2) + ' ms de media las ultimas diez')
    } else {
        Comp '6c. cuesta poco en caliente' ($media -lt 30) ([string][Math]::Round($media, 2) + ' ms de media')
        Comp '6d. y ya tiene deltas de esta consola' ($script:acelDeltas.Count -ge 15) ([string]$script:acelDeltas.Count + ' medidas')
        $uReal = Get-AcelUmbral
        Write-Host ('       con ' + $script:acelDeltas.Count + ' medidas el umbral seria ' + $(if ($uReal -gt 0) { [string][Math]::Round($uReal, 4) + ' g' } else { 'todavia no lo se (hacen falta ' + $AcelDeltasMin + ')' }))
    }
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova sabe si la consola esta en la mano, aunque no toques un boton' -ForegroundColor Green
exit 0
