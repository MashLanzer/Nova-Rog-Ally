# NOVA SE ENTERA DE LO QUE PASA (16/09): el freno de mano de los avisos.
#
# braya quiere 30 comportamientos que reaccionen a su entorno. Lo que se comprueba aqui
# NO es que avise, sino que SEPA CALLARSE: un asistente que habla solo se vuelve
# insoportable en dos dias, y el odia especialmente los modos que se quedan puestos.
$ErrorActionPreference = 'Stop'
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
$EntornoNocheDesde = 23
$EntornoNocheHasta = 8
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
Invoke-Expression (Traer 'Send-AvisoCola')
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

Write-Host "  -- con un invitado delante, nada --"
Reset
$script:invitado = $true
Comp 'no avisa a un invitado' (-not (Send-AvisoEntorno 'correo' 'Tienes correo.')) ''
$script:invitado = $false

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
