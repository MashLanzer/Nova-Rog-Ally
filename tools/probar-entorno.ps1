# NOVA SE ENTERA DE LO QUE PASA (16/09): el freno de mano de los avisos.
#
# braya quiere 30 comportamientos que reaccionen a su entorno. Lo que se comprueba aqui
# NO es que avise, sino que SEPA CALLARSE: un asistente que habla solo se vuelve
# insoportable en dos dias, y el odia especialmente los modos que se quedan puestos.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$sw = [System.Diagnostics.Stopwatch]::StartNew()
# la configuracion, con los valores por defecto del archivo real
$EntornoOn = $true
$EntornoPorHora = 4
# UN BANCO NO PUEDE CAMBIAR DE COLOR SEGUN EL RELOJ (17/09). Con la franja real (23-8),
# pasar las pruebas de madrugada bloqueaba TODOS los avisos normales -que es lo correcto
# de noche- y salian 12 casos MAL sin que nada estuviera roto. Peor aun: "nivel bajo: sin
# voz" seguia en verde, porque con todo bloqueado se cumple solo. Asi que la franja se
# pone lejos de la hora actual, y los casos que necesitan noche la fijan ellos.
$hAhoraP = (Get-Date).Hour
$EntornoNocheDesde = ($hAhoraP + 2) % 24
$EntornoNocheHasta = ($hAhoraP + 3) % 24
$script:entornoAvisos = New-Object System.Collections.ArrayList
$script:entornoVistos = @{}
$script:entornoCallado = $false
$script:invitado = $false
$script:juegoActivo = $null
$script:busy = $false
$script:pendiente = $null
$script:dictandoLargo = $false
$script:dicho = @()
function Log($m) { }
function Add-Estadistica($a, $b) { }
function Show-Popup($t, $tipo = '') { }
function Say($t) { $script:dicho += $t }
# las marcas de "ya lo dije" viven en disco (si no, cada reinicio rearma los avisos),
# asi que esto tiene que estar ANTES de la primera llamada a Send-AvisoEntorno
$EntornoVistosPath = Join-Path $env:TEMP ('avisos-vistos-' + [guid]::NewGuid().ToString('N') + '.json')
function Write-Atomico($ruta, $texto) { [System.IO.File]::WriteAllText($ruta, $texto, (New-Object System.Text.UTF8Encoding($false))) }
Invoke-Expression (Traer 'Get-EntornoVistos')
Invoke-Expression (Traer 'Save-EntornoVistos')
Invoke-Expression (Traer 'Test-PuedoAvisar')
# la voz de los avisos normales no sale al momento: espera unos segundos y sale junta
$AvisoJuntarMs = 4000
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$script:habitosFalsos = @{ charlaHoras = @{} }
function Get-Habitos { return $script:habitosFalsos }
$script:statsFalsas = @{ dias = @{} }
function Get-Estadisticas { return $script:statsFalsas }
# Get-HoraFinHabitual entra el 22/09: desde ese dia Get-AvisoHoraDormir decide con la hora a
# la que braya PARA de verdad, no con las horas en que ha tenido conversacion. Sin traerla,
# esto muere con CommandNotFoundException a la primera.
Invoke-Expression (Traer 'Get-HoraFinHabitual')
Invoke-Expression (Traer 'Get-AvisoHoraDormir')
Invoke-Expression (Traer 'Get-AvisoFallos')
Invoke-Expression (Traer 'Send-AvisoCola')
# LA COLA DE LOS QUE NO SE DICEN PORQUE NO HAY NADIE (23/09, idea 20). Send-AvisoEntorno ya
# las llama, asi que sin esto este banco moria a mitad... y salia con exit 0, que es peor.
# Aqui la ausencia se deja en CERO: lo que se prueba en este fichero es el filtro de siempre,
# con braya delante. El aplazado tiene su propio banco (probar-avisos-espera.ps1).
$fuenteE = [System.IO.File]::ReadAllText($ruta)
$script:avisoEspera = New-Object System.Collections.ArrayList
$AvisoEsperaPath = Join-Path $env:TEMP ('entorno-espera-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.json')
$mS = [regex]::Match($fuenteE, '(?ms)^\$AvisoSiempre = (@\(.*?\))\s*$')
if (-not $mS.Success) { throw 'no encuentro $AvisoSiempre' }
$AvisoSiempre = Invoke-Expression $mS.Groups[1].Value
$AvisoEsperaMin = if ($fuenteE -match '(?m)^\$AvisoEsperaMin = (\d+)') { [int]$Matches[1] } else { 30 }
$AvisoEsperaCaducaMin = if ($fuenteE -match '(?m)^\$AvisoEsperaCaducaMin = (\d+)') { [int]$Matches[1] } else { 120 }
$script:ausenciaFalsa = 0
function Get-AusenciaMin([datetime]$ahora = (Get-Date)) { return $script:ausenciaFalsa }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
# Set-AvisosEntorno llama a Get-DiaJuego desde la idea 11: otra que faltaba y que mataba
# este banco a mitad, tambien en silencio.
Invoke-Expression (Traer 'Get-DiaJuego')
Invoke-Expression (Traer 'Test-AvisoAplazable')
Invoke-Expression (Traer 'Get-AvisoEspera')
Invoke-Expression (Traer 'Save-AvisoEspera')
Invoke-Expression (Traer 'Add-AvisoEspera')
Invoke-Expression (Traer 'Send-AvisoEntorno')
Invoke-Expression (Traer 'Set-AvisosEntorno')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Reset {
    $script:entornoAvisos = New-Object System.Collections.ArrayList
    $script:entornoVistos = @{}
    # las marcas ya viven en disco: si no se borran, un caso ensucia al siguiente
    Remove-Item -LiteralPath $EntornoVistosPath -Force -ErrorAction SilentlyContinue
    $script:entornoCallado = $false
    $script:juegoActivo = $null
    $script:busy = $false; $script:pendiente = $null; $script:dictandoLargo = $false
    $script:dicho = @()
    $script:avisoCola = New-Object System.Collections.ArrayList
    $script:avisoColaDesde = 0
}

Write-Host "  -- avisa cuando toca --"
Reset
Comp 'un aviso normal sale' (Send-AvisoEntorno 'dock' 'Pantalla conectada.') ''
Send-AvisoCola $true
Comp 'y se dice en voz alta' ($script:dicho.Count -eq 1) ''''

Write-Host "  -- pero no se repite --"
Comp 'el mismo aviso, otra vez, NO' (-not (Send-AvisoEntorno 'dock' 'Pantalla conectada.')) ''
Comp 'otro distinto SI' (Send-AvisoEntorno 'cascos' 'Cascos puestos.') ''

Write-Host "  -- presupuesto por hora --"
Reset
$salieron = 0
foreach ($i in 1..8) { if (Send-AvisoEntorno "cosa$i" "aviso $i") { $salieron++ } }
Comp "como mucho $EntornoPorHora por hora" ($salieron -eq $EntornoPorHora) "salieron $salieron"
Comp 'lo critico pasa igual' (Send-AvisoEntorno 'bateria' 'Te queda el 5 por ciento.' 'alto') ''

Write-Host "  -- jugando, silencio --"
Reset
$script:juegoActivo = 'It Takes Two'
Comp 'un aviso normal NO molesta jugando' (-not (Send-AvisoEntorno 'correo' 'Tienes correo.')) ''
Comp 'pero lo critico si' (Send-AvisoEntorno 'bateria' 'Te queda el 5 por ciento.' 'alto') ''

Write-Host "  -- mientras habla o espera un si --"
Reset
$script:busy = $true
Comp 'no interrumpe si esta ocupada' (-not (Send-AvisoEntorno 'dock' 'Pantalla conectada.')) ''
Reset
$script:pendiente = @{ tipo = 'peligrosa' }
Comp 'ni mientras espera un si' (-not (Send-AvisoEntorno 'dock' 'Pantalla conectada.')) ''

Write-Host "  -- el interruptor --"
Reset
$r = Set-AvisosEntorno $false
Comp '"no me avises" lo apaga' ($r -match 'no te aviso' -and -not (Send-AvisoEntorno 'dock' 'x')) "$r"
Comp 'y ni siquiera lo critico pasa' (-not (Send-AvisoEntorno 'bateria' 'x' 'alto')) ''
$r = Set-AvisosEntorno $true
Comp 'y se vuelve a encender' ($r -match 'vuelvo a avisarte' -and (Send-AvisoEntorno 'dock' 'x')) "$r"

Write-Host "  -- los de poca monta no se dicen, solo se ven --"
Reset
$null = Send-AvisoEntorno 'menor' 'Descarga terminada.' 'bajo'
Comp 'nivel bajo: sin voz' ($script:dicho.Count -eq 0) ''

Write-Host "  -- los niveles de la fase 1 son los que tienen que ser --"
# la bateria al limite tiene que sonar JUGANDO (es lo unico que de verdad urge);
# una descarga terminada, no: eso puede esperar a que salgas del juego
Reset
$script:juegoActivo = 'It Takes Two'
Comp 'bateria baja avisa jugando (es critico)' (Send-AvisoEntorno 'bateria-baja' 'Te queda el 15 por ciento.' 'alto' 20) ''
Comp 'una descarga terminada NO interrumpe la partida' (-not (Send-AvisoEntorno 'descarga-x' 'Ya termino de descargarse.' 'medio' 180)) ''
Reset
Comp 'y fuera del juego la descarga si se dice' (Send-AvisoEntorno 'descarga-x' 'Ya termino de descargarse.' 'medio' 180) ''

Write-Host "  -- el 'una vez cada X' sobrevive al reinicio --"
# EL FALLO DE VERDAD (16/09, visto en vivo): el aviso del Gmail lleno, con plazo de UNA
# SEMANA, salio dos veces en once minutos porque entre medias se reinicio Nova. Las
# marcas vivian en memoria, asi que cada arranque rearmaba todos los avisos.
Reset
Comp 'el aviso sale la primera vez' (Send-AvisoEntorno 'gmail-lleno' 'Gmail lleno.' 'medio' 10080) ''
Comp 'y queda apuntado en disco' (Test-Path $EntornoVistosPath) ''
# esto es reiniciar Nova: la memoria se vacia, el archivo se queda
$script:entornoVistos = @{}
$script:entornoAvisos = New-Object System.Collections.ArrayList
Comp 'tras reiniciar, NO se repite' (-not (Send-AvisoEntorno 'gmail-lleno' 'Gmail lleno.' 'medio' 10080)) ''
Comp 'pero otro aviso distinto si sale' (Send-AvisoEntorno 'otra-cosa' 'Otra cosa.' 'medio' 10080) ''
Remove-Item $EntornoVistosPath -ErrorAction SilentlyContinue

Write-Host "  -- dos avisos seguidos, una sola frase --"
# EL FALLO QUE ESTUVE A PUNTO DE METER (16/09): mi primera version le pegaba al aviso
# nuevo el texto del anterior... que YA HABIA SONADO. O sea, lo repetia en voz alta.
Reset
[void](Send-AvisoEntorno 'uno' 'Cargando, vas por el 40 por ciento.')
[void](Send-AvisoEntorno 'dos' 'Sin la pantalla grande.')
Comp 'todavia no ha dicho nada' ($script:dicho.Count -eq 0) ''
Send-AvisoCola $true
Comp 'sale una frase, no dos' ($script:dicho.Count -eq 1) "$($script:dicho.Count)"
Comp 'y estan las dos cosas' ($script:dicho[0] -like '*40 por ciento*' -and $script:dicho[0] -like '*pantalla grande*') "$($script:dicho[0])"
Reset
[void](Send-AvisoEntorno 'uno' 'Cargando, vas por el 40 por ciento.')
Send-AvisoCola $true
[void](Send-AvisoEntorno 'dos' 'Sin la pantalla grande.')
Send-AvisoCola $true
Comp 'lo ya dicho NO se repite' ($script:dicho.Count -eq 2 -and $script:dicho[1] -notlike '*40 por ciento*') "$($script:dicho -join ' / ')"

Write-Host "  -- pero lo critico no hace cola --"
Reset
[void](Send-AvisoEntorno 'descarga-z' 'Ya termino de descargarse.' 'medio' 180)
[void](Send-AvisoEntorno 'bateria' 'Te queda el 5 por ciento.' 'alto')
Comp 'se dice al momento y va primero' ($script:dicho.Count -eq 1 -and $script:dicho[0] -like 'Te queda el 5*') "$($script:dicho -join ' / ')"

Write-Host "  -- de noche, y el aviso que se callaba a si mismo --"
# EL FALLO QUE HABRIA PASADO DESAPERCIBIDO: el freno calla de noche todo lo que no sea
# 'alto'... asi que un "vete a dormir" a las 2 de la madrugada no habria salido NUNCA.
Reset
$hAhora = (Get-Date).Hour
$EntornoNocheDesde = $hAhora
$EntornoNocheHasta = ($hAhora + 1) % 24
Comp 'de noche, un aviso normal se calla' (-not (Send-AvisoEntorno 'dock' 'Pantalla conectada.')) ''
Comp 'pero el de la hora de dormir SI sale' (Send-AvisoEntorno 'hora-dormir' 'Son las 2:30.' 'noche') ''
Reset
$script:juegoActivo = 'It Takes Two'
Comp 'y aun asi no interrumpe la partida' (-not (Send-AvisoEntorno 'hora-dormir' 'Son las 2:30.' 'noche')) ''
$EntornoNocheDesde = ($hAhoraP + 2) % 24
$EntornoNocheHasta = ($hAhoraP + 3) % 24

Write-Host "  -- la hora de dormir es LA TUYA, no las 23:00 de nadie --"
Reset
# esta si necesita la franja de verdad: lo que prueba es a que horas son "raras"
$EntornoNocheDesde = 23
$EntornoNocheHasta = 8
$noche = (Get-Date).Date.AddHours(2)
$script:habitosFalsos.charlaHoras = @{}
Comp 'a las 2 y nunca sueles estarlo: avisa' ((Get-AvisoHoraDormir $noche) -ne '') "$(Get-AvisoHoraDormir $noche)"
foreach ($d in 1..4) { $script:habitosFalsos.charlaHoras[$noche.AddDays(-$d).ToString('yyyy-MM-dd|HH')] = 1 }
Comp 'si SUELES estar despierto a esa hora, callado' ((Get-AvisoHoraDormir $noche) -eq '') ''
Comp 'y a las 4 de la tarde jamas' ((Get-AvisoHoraDormir ((Get-Date).Date.AddHours(16))) -eq '') ''
$EntornoNocheDesde = ($hAhoraP + 2) % 24
$EntornoNocheHasta = ($hAhoraP + 3) % 24

Write-Host "  -- cuando me equivoco mas de lo normal --"
$hoyF = (Get-Date).ToString('yyyy-MM-dd')
$script:statsFalsas.dias = @{}
# MIDE LOS DESCARTES, NO LOS 'error' (22/09). 'error' sube cuando braya CANCELA una orden y
# cuando opencode da timeout: con ese contador, el aviso podia decirle "no te entiendo" un
# dia en que le hubiera entendido todo. Los descartes son las veces que de verdad se tiro lo
# que dijo.
$script:statsFalsas.dias[$hoyF] = @{ descarte = 12 }
foreach ($d in 1..4) { $script:statsFalsas.dias[(Get-Date).AddDays(-$d).ToString('yyyy-MM-dd')] = @{ descarte = 2 } }
Comp '12 descartes con una media de 2: lo dice' ((Get-AvisoFallos) -ne '') "$(Get-AvisoFallos)"
$script:statsFalsas.dias[$hoyF] = @{ descarte = 3 }
Comp 'tres descartes sueltos: ni una palabra' ((Get-AvisoFallos) -eq '') ''
$script:statsFalsas.dias = @{ $hoyF = @{ descarte = 12 } }
Comp 'sin semana con que comparar, callado' ((Get-AvisoFallos) -eq '') ''
# EL CASO QUE LO CAZA: un dia de cancelaciones y timeouts NO es un dia de no entender.
$script:statsFalsas.dias = @{ $hoyF = @{ error = 12; descarte = 1 } }
foreach ($d in 1..4) { $script:statsFalsas.dias[(Get-Date).AddDays(-$d).ToString('yyyy-MM-dd')] = @{ error = 2; descarte = 1 } }
Comp 'doce cancelaciones no son doce malentendidos' ((Get-AvisoFallos) -eq '') 'mide descarte, no error'

Write-Host "  -- con un invitado delante, nada --"
Reset
$script:invitado = $true
Comp 'no avisa a un invitado' (-not (Send-AvisoEntorno 'correo' 'Tienes correo.')) ''
$script:invitado = $false

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
