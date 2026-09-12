# "Que solo te obedezca a ti": comprueba a quien toma por el dueno de la casa y
# cuando decide que una voz no es la tuya. Las dos funciones se sacan DEL
# ARCHIVO REAL, como en las demas pruebas.
# Lo que se mide aqui es la POLITICA (a quien se pregunta y a quien no), no la
# estimacion del tono: eso lo hace el worker de Python con audio de verdad.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'Get-VozDuena')
Invoke-Expression (TraerFn 'Test-VozExtrana')

# --- mundo de mentira ---
$TmpDir = Join-Path $env:TEMP 'voz-dueno-prueba'
if (-not (Test-Path $TmpDir)) { New-Item -ItemType Directory -Path $TmpDir | Out-Null }
$rutaVoces = Join-Path $TmpDir 'voces.json'
$SoloYoOn = $true
$SoloYoMargen = 35.0
$SoloYoMinimo = 12
$script:ultimaF0 = 0

$fallos = 0
function Ok([string]$etiqueta, [bool]$obtenido, [bool]$esperado, [string]$extra = '') {
    $ok = ($obtenido -eq $esperado)
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $extra)
    if (-not $ok) { $script:fallos++ }
}
function PonerVoces([string]$json) { [System.IO.File]::WriteAllText($rutaVoces, $json, (New-Object System.Text.UTF8Encoding($false))) }

Write-Host "--- quien es el de la casa ---"

# el caso de verdad de esta maquina (tmp\voces.json el 12/09): una voz grave que
# ha dictado 39 veces, y tres apariciones sueltas que son el audio de fondo
PonerVoces '[{"f0": 119.4, "n": 39}, {"f0": 171.7, "n": 11}, {"f0": 148.4, "n": 13}, {"f0": 231.2, "n": 16}]'
$d = Get-VozDuena $rutaVoces
Ok 'la que mas ha dictado, no la primera' ([Math]::Abs($d - 119.4) -lt 0.01) $true "dueña=$d"

# la MAS FRECUENTE, aunque este la segunda en el archivo
PonerVoces '[{"f0": 231.0, "n": 4}, {"f0": 118.0, "n": 40}]'
$d2 = Get-VozDuena $rutaVoces
Ok 'el orden del archivo no manda' ([Math]::Abs($d2 - 118.0) -lt 0.01) $true "dueña=$d2"

# dos personas que usan la consola: no hay dueno, y entonces no se acusa a nadie
PonerVoces '[{"f0": 120.0, "n": 20}, {"f0": 210.0, "n": 18}]'
$d3 = Get-VozDuena $rutaVoces
Ok 'con dos que hablan parecido, no hay dueño' ($d3 -eq 0) $true "dueña=$d3"

# recien estrenado: cuatro ordenes no bastan para decidir de quien es la casa
PonerVoces '[{"f0": 120.0, "n": 4}]'
$d4 = Get-VozDuena $rutaVoces
Ok 'con pocas ordenes todavia no se sabe' ($d4 -eq 0) $true "dueña=$d4"

# sin archivo (primer arranque) y con basura dentro: ni se cae ni inventa
Remove-Item $rutaVoces -Force -ErrorAction SilentlyContinue
Ok 'sin voces.json' ((Get-VozDuena $rutaVoces) -eq 0) $true
PonerVoces 'esto no es json'
Ok 'con el archivo corrupto' ((Get-VozDuena $rutaVoces) -eq 0) $true

Write-Host ""
Write-Host "--- cuando se pregunta, y cuando no ---"
PonerVoces '[{"f0": 119.4, "n": 39}, {"f0": 231.2, "n": 16}]'
$duena = Get-VozDuena $rutaVoces

Ok 'tu voz de siempre'                (Test-VozExtrana 121.0 $duena) $false '121 Hz'
Ok 'tu, hablando algo mas agudo'      (Test-VozExtrana 148.0 $duena) $false '148 Hz, 29 de diferencia'
Ok 'justo en el borde del margen'     (Test-VozExtrana 154.0 $duena) $false '154 Hz, 35 clavados'
Ok 'la voz de un video'               (Test-VozExtrana 231.0 $duena) $true  '231 Hz'
Ok 'y una mas grave que la tuya'      (Test-VozExtrana 70.0 $duena)  $true  '70 Hz'
Ok 'sin medida de tono, no se acusa'  (Test-VozExtrana 0.0 $duena)   $false 'f0=0'
Ok 'sin dueño conocido, tampoco'      (Test-VozExtrana 231.0 0.0)    $false

# apagado: no pregunta ni con la voz mas rara
$SoloYoOn = $false
Ok 'apagado, no pregunta nunca'       (Test-VozExtrana 231.0 $duena) $false
$SoloYoOn = $true

# y el tono de la orden en curso, cuando no se le pasa ninguno
$script:ultimaF0 = 231.0
Ok 'toma el tono de la ultima orden'  (Test-VozExtrana -1 $duena)    $true  'ultimaF0=231'
$script:ultimaF0 = 0
Ok 'y si no hay ninguno, calla'       (Test-VozExtrana -1 $duena)    $false 'ultimaF0=0'

Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
