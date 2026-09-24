# "Que solo te obedezca a ti": comprueba a quien toma por el dueno de la casa y
# cuando decide que una voz no es la tuya. Las dos funciones se sacan DEL
# ARCHIVO REAL, como en las demas pruebas.
# Lo que se mide aqui es la POLITICA (a quien se pregunta y a quien no), no la
# estimacion del tono: eso lo hace el worker de Python con audio de verdad.
# POR DONDE ESTE EL BANCO, NO POR UNA RUTA ESCRITA A MANO (22/09). Aqui habia la ruta
# completa a fuego: en una copia del repo en otra carpeta este banco seguiria midiendo el
# assistant.ps1 de SIEMPRE -verde sobre codigo que no es el que se acaba de tocar- y si la
# carpeta se renombrara se caeria entero por algo que no tiene que ver con lo que prueba.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'Get-VozDuena')
Invoke-Expression (TraerFn 'Test-VozExtrana')
Invoke-Expression (TraerFn 'Update-MiVoz')
$MiVozTope = 60
# se saca del archivo real, como el resto: si alli cambia, la prueba lo sigue
$txtV = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
if ($txtV -match '(?m)^[$]MiVozDeriva = ([0-9.]+)') { $MiVozDeriva = [double]$Matches[1] }
else { throw 'falta $MiVozDeriva en assistant.ps1' }
$script:invitado = $false
$script:avisosVoz = @()
function Log($m) { }
function Add-Estadistica($ruta, $detalle) { }
function Send-AvisoEntorno($clave, $texto, $nivel = 'medio', $cada = 60) { $script:avisosVoz += $texto; return $true }

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

Write-Host ""
Write-Host "--- tu tono, aprendido de las ordenes que SI se ejecutaron ---"
# tmp\voces.json cuenta todo lo que pasa por el microfono, videos incluidos.
# Esto solo cuenta lo que se entendio y se hizo, que es la unica fuente limpia.
$rutaMia = Join-Path $TmpDir 'mi-voz.json'
Remove-Item $rutaMia -Force -ErrorAction SilentlyContinue

foreach ($hz in @(118, 120, 116, 122, 119, 117, 121, 118, 120, 119, 118, 121)) { Update-MiVoz $hz }
$mia = Get-Content -LiteralPath $rutaMia -Raw | ConvertFrom-Json
Ok 'doce ordenes tuyas dan tu tono' ([Math]::Abs([double]$mia.f0 - 119.1) -lt 1.5) $true "f0=$($mia.f0) n=$($mia.n)"

# y con eso ya manda sobre voces.json, aunque alli el ruido tenga mas cuenta
PonerVoces '[{"f0": 231.0, "n": 90}, {"f0": 119.0, "n": 12}]'
$dMia = Get-VozDuena
Ok 'manda lo aprendido, no el ruido del worker' ([Math]::Abs($dMia - 119.1) -lt 1.5) $true "dueña=$dMia"

# un salto enorme (otra persona confirmando a mano) no arrastra la referencia
Update-MiVoz 240.0
$mia2 = Get-Content -LiteralPath $rutaMia -Raw | ConvertFrom-Json
Ok 'un tono lejano no mueve tu media' ([Math]::Abs([double]$mia2.f0 - [double]$mia.f0) -lt 0.01) $true "f0=$($mia2.f0)"

# pero un cambio lento SI: la voz se mueve con los anos y con el microfono
foreach ($i in 1..40) { Update-MiVoz 150.0 }
$mia3 = Get-Content -LiteralPath $rutaMia -Raw | ConvertFrom-Json
Ok 'un cambio lento si te sigue' ([double]$mia3.f0 -gt 140) $true "f0=$($mia3.f0)"

# y f0=0 (sin medida) no ensucia nada
$antes = (Get-Content -LiteralPath $rutaMia -Raw | ConvertFrom-Json).n
Update-MiVoz 0
$despues = (Get-Content -LiteralPath $rutaMia -Raw | ConvertFrom-Json).n
Ok 'sin medida, no cuenta' ($antes -eq $despues) $true "n=$despues"

# --- QUE TU VOZ NO SE MUEVA EN SILENCIO (17/09) ---
# La media ya se rehacia sola (y se ha movido de verdad: era 119,6 Hz y hoy es 116,8). Lo que
# faltaba era enterarse, porque de este numero depende "solo yo". La guarda de 60 Hz impide
# un SALTO pero no una DERIVA: la segunda voz de la casa esta a 27,2 Hz de la de braya, o sea
# dentro de esa guarda.
Write-Host ""
Write-Host "  -- la huella se mueve sola, pero avisando --"
$rutaMia = Join-Path $TmpDir 'mi-voz.json'
function PonerVoz([double]$f0, [int]$n, [double]$base) {
    [System.IO.File]::WriteAllText($rutaMia,
        ('{"f0":' + $f0.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) +
         ',"n":' + $n + ',"base":' + $base.ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) + '}'),
        (New-Object System.Text.UTF8Encoding($false)))
    $script:avisosVoz = @()
}
function LeerVoz { return (Get-Content -LiteralPath $rutaMia -Raw -Encoding UTF8 | ConvertFrom-Json) }

# 1) un movimiento pequeno NO se avisa: la media siempre baila un poco
PonerVoz 116.8 60 116.8
Update-MiVoz 120.0
Ok 'un movimiento pequeno no molesta' (@($script:avisosVoz).Count -eq 0) $true ("avisos: " + @($script:avisosVoz).Count)
Ok 'pero la media si se mueve' ((LeerVoz).f0 -ne 116.8) $true ("f0=" + (LeerVoz).f0)

# 2) una deriva grande SI se avisa, y la base se pone al dia
PonerVoz 116.8 60 135.0
Update-MiVoz 117.0
Ok 'una deriva de mas de 15 Hz se dice' (@($script:avisosVoz).Count -eq 1) $true
Ok 'y el aviso trae los dos numeros' ($script:avisosVoz[0] -match '135' -and $script:avisosVoz[0] -match '11') $true
Ok 'la base se pone al dia (no avisa dos veces)' ([Math]::Abs([double](LeerVoz).base - [double](LeerVoz).f0) -lt 0.2) $true ("base=" + (LeerVoz).base)
$script:avisosVoz = @()
Update-MiVoz 117.0
Ok 'y en la siguiente ya no repite' (@($script:avisosVoz).Count -eq 0) $true

# 3) con cuatro medidas no se avisa: la media baila sola
PonerVoz 116.8 4 140.0
Update-MiVoz 117.0
Ok 'sin muestras suficientes no avisa' (@($script:avisosVoz).Count -eq 0) $true

# 4) la primera vez se fija la base sin avisar de nada
Remove-Item -LiteralPath $rutaMia -Force -ErrorAction SilentlyContinue
$script:avisosVoz = @()
Update-MiVoz 118.0
Ok 'la primera vez solo fija la base' (@($script:avisosVoz).Count -eq 0) $true
Ok 'y la base queda puesta' ([double](LeerVoz).base -gt 0) $true ("base=" + (LeerVoz).base)

# 5) un invitado no mueve nada de esto
PonerVoz 116.8 60 116.8
$script:invitado = $true
Update-MiVoz 200.0
Ok 'la voz de un invitado no toca tu huella' ([double](LeerVoz).f0 -eq 116.8) $true
$script:invitado = $false

# 6) y el salto enorme se sigue descartando, como antes
PonerVoz 116.8 60 116.8
Update-MiVoz 250.0
Ok 'un salto de 133 Hz se sigue descartando' ([double](LeerVoz).f0 -eq 116.8) $true

Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
