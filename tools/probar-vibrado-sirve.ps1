# LA VIBRACION ESTABA DETRAS DE UNA PUERTA QUE NO SE ABRIA (27/09, idea 77 de las 121)
#
# EL DATO: Send-AvisoVibrado solo vibraba si $script:capsulaCiega, y eso se decidia comparando la
# resolucion nativa con la actual. 'CAPSULA CIEGA' sale CERO veces en los dos registros (16 dias) con
# 4.038 segundos de nightreign en un solo dia (memoria\uso-ally.json, 25/09): el juego corre a la
# resolucion nativa, asi que la puerta nunca se abrio. Resultado medido: 5 lineas 'aviso SIN VOZ' y
# CERO vibradas, con el canal disponible las 130 veces que arranco ('mando: vibracion disponible').
#
# La idea 67 (hoy) arreglo la deteccion: ahora lo dice la propia capsula. Y aqui se abre la puerta
# que faltaba: tambien se vibra con un JUEGO delante aunque la capsula se vea, porque con un juego el
# punto queda al 42 % y braya dijo el 24/09 que no lo veia.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que sin juego y sin capsula ciega NO se vibre (ahi el aviso se ve y vibrar solo molesta)
#   2. que no haya dos zumbidos pegados
#   3. que se MIDA si el zumbido movio algo, y que la clase que nunca mueve nada deje de vibrar
#   4. que una clase que alguna vez sirvio no se corte nunca
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
foreach ($f in @('Get-VibradoSeguidosSinNada', 'Send-AvisoVibrado', 'Set-VibradoReaccion')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$VibrarVentanaMs = 30000
$VibrarSeguidosMax = 5
$VibrarSeparacionMs = 60000
Comp 'los tres numeros salen del archivo' (($txt -match '\$VibrarVentanaMs = 30000') -and ($txt -match '\$VibrarSeguidosMax = 5') -and ($txt -match '\$VibrarSeparacionMs = 60000')) ''

# los dobles, DESPUES de cargar
$script:zumbidos = 0
function Start-Vibracion($patron, $fuerza) { $script:zumbidos++ }
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
$script:stats = @{ dias = @{}; descartes = @(); recientes = @(); decisiones = @() }
function Get-Estadisticas { return $script:stats }
$script:apuntados = @()
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) {
    $script:apuntados += @(@{ ruta = $ruta; detalle = $detalle })
    $dia = '2026-09-27'
    if (-not $script:stats.dias.ContainsKey($dia)) { $script:stats.dias[$dia] = @{} }
    if (-not $script:stats.dias[$dia].ContainsKey($ruta)) { $script:stats.dias[$dia][$ruta] = 0 }
    $script:stats.dias[$dia][$ruta]++
}
$script:msFalsos = 1000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:zumbidos = 0
    $script:logs = @()
    $script:apuntados = @()
    $script:stats = @{ dias = @{}; descartes = @(); recientes = @(); decisiones = @() }
    $script:vibroEn = -100000
    $script:vibroClave = ''
    $script:vibroVence = 0
    $script:capsulaCiega = $false
    $script:juegoActivo = $null
    $script:msFalsos = 1000000
}

Write-Host ''
Write-Host '-- 1. CUANDO NO HACE FALTA, NO SE VIBRA --'
Reset
Comp '1a. sin juego y con la capsula visible: no vibra' (-not (Send-AvisoVibrado 'bateria')) 'el aviso se ve; vibrar solo molesta'
Comp '1b. y no suena nada' ($script:zumbidos -eq 0) ([string]$script:zumbidos)

Write-Host ''
Write-Host '-- 2. LAS DOS RAZONES PARA VIBRAR --'
Reset
$script:capsulaCiega = $true
Comp '2a. con la capsula ciega, vibra' (Send-AvisoVibrado 'bateria') ''
Reset
$script:juegoActivo = 'nightreign'
Comp '2b. y con un juego delante tambien (esta es la puerta nueva)' (Send-AvisoVibrado 'bateria') '4.038 s de nightreign en un dia y cero vibrados'
Comp '2c. y el zumbido suena de verdad' ($script:zumbidos -eq 1) ([string]$script:zumbidos)

Write-Host ''
Write-Host '-- 3. NI DOS ZUMBIDOS PEGADOS --'
Comp '3a. otro seguido, no' (-not (Send-AvisoVibrado 'bateria')) 'menos de un minuto'
$script:msFalsos += $VibrarSeparacionMs - 1
Comp '3b. un segundo antes del minuto, tampoco' (-not (Send-AvisoVibrado 'bateria')) ''
$script:msFalsos += 2
Comp '3c. pasado el minuto, si' (Send-AvisoVibrado 'bateria') ''

Write-Host ''
Write-Host '-- 4. ¿MOVIO ALGO? SE APUNTA --'
Reset
$script:juegoActivo = 'nightreign'
$null = Send-AvisoVibrado 'bateria'
Comp '4a. tras vibrar, hay una ventana abierta' ($script:vibroVence -gt 0) ([string]$script:vibroVence)
$null = Set-VibradoReaccion $true
Comp '4b. si braya reacciona, se apunta que sirvio' (@($script:apuntados | Where-Object { $_.ruta -eq 'vibro-sirvio:bateria' }).Count -eq 1) (@($script:apuntados)[0].ruta)
Comp '4c. y la ventana se cierra' ($script:vibroVence -eq 0) 'no se apunta dos veces el mismo zumbido'
Comp '4d. una segunda llamada no apunta nada' ((Set-VibradoReaccion $true) -eq $false -and @($script:apuntados).Count -eq 1) ''
$script:msFalsos += $VibrarSeparacionMs + 1
$null = Send-AvisoVibrado 'bateria'
$null = Set-VibradoReaccion $false
Comp '4e. y si no mueve nada, se apunta que no sirvio' (@($script:apuntados | Where-Object { $_.ruta -eq 'vibro-nada:bateria' }).Count -eq 1) ''
Comp '4f. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'no movio nada' }).Count -eq 1) (@($script:logs) -join ' | ')

Write-Host ''
Write-Host '-- 5. LA CLASE QUE NUNCA MUEVE NADA DEJA DE VIBRAR --'
Reset
$script:juegoActivo = 'nightreign'
for ($i = 1; $i -le $VibrarSeguidosMax; $i++) {
    $script:msFalsos += $VibrarSeparacionMs + 1
    $null = Send-AvisoVibrado 'tiempo'
    $null = Set-VibradoReaccion $false
}
Comp '5a. cinco zumbidos sin reaccion' ($script:zumbidos -eq $VibrarSeguidosMax) ([string]$script:zumbidos)
$script:msFalsos += $VibrarSeparacionMs + 1
Comp '5b. el sexto ya no suena' (-not (Send-AvisoVibrado 'tiempo')) ''
Comp '5c. y lo dice, no se calla' (@($script:logs | Where-Object { $_ -match 'dejo de vibrar por eso' }).Count -eq 1) ''
Comp '5d. pero OTRA clase sigue vibrando' (Send-AvisoVibrado 'descarga') 'se corta por clase, no del todo'

Write-Host ''
Write-Host '-- 6. Y LO QUE ALGUNA VEZ SIRVIO NO SE CORTA --'
Reset
$script:juegoActivo = 'nightreign'
# una vez sirvio y luego seis veces no
$script:stats.dias['2026-09-26'] = @{ 'vibro-sirvio:recordatorio' = 1; 'vibro-nada:recordatorio' = 6 }
Comp '6a. con un acierto dentro, la cuenta de seguidos es 0' ((Get-VibradoSeguidosSinNada 'recordatorio') -eq 0) 'no se castiga a lo que funciona'
Comp '6b. asi que sigue vibrando' (Send-AvisoVibrado 'recordatorio') ''

Write-Host ''
Write-Host '-- 7. EL CABLEADO: LAS TRES SENALES DE REACCION --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7a. el flanco del gatillo' ($sinCom -match '(?s)\$holdFired = \$false.{0,80}Set-VibradoReaccion \$true') ''
Comp '7b. la llamada por su nombre' ($sinCom -match '(?s)Set-VibradoReaccion \$true\) \}\s*\r?\n\s*Start-Dictado') ''
Comp '7c. y abrir el panel rapido' ($sinCom -match '(?s)PANEL RAPIDO: abierto.{0,160}Set-VibradoReaccion \$true') ''
Comp '7d. la ventana que se pasa sin nada, en el bucle' ($sinCom -match '\$sw\.ElapsedMilliseconds -gt \$script:vibroVence\) \{ \[void\]\(Set-VibradoReaccion \$false\)') ''
Comp '7e. Send-Aviso le pasa la clase del aviso' ($sinCom -match 'Send-AvisoVibrado \$\(if \(\$tipo\)') 'para poder medir por clase'
# LO QUE NO DEBE SER UNA SENAL: pulsar cualquier boton jugando. Con eso, todo zumbido "serviria".
Comp '7f. y NO cuenta cualquier pulsacion' (-not ($sinCom -match 'Set-PresenciaAhora[^\r\n]{0,120}Set-VibradoReaccion')) 'jugando el mando se pulsa todo el rato'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el zumbido se usa cuando hace falta y se mide si sirve' -ForegroundColor Green
exit 0
