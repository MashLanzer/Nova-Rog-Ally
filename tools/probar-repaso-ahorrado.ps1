# NO REPASAR LO QUE YA SE VA A TIRAR (22/09).
#
# Cuando Parakeet ya ha oido una frase larga en espanol, pedirle el repaso a Whisper es pagar
# por un texto que se va a tirar entero. Medido sobre assistant.log: 328 peticiones de repaso,
# y 227 acaban en "Whisper no saca una orden: sigo con lo de Parakeet". Se espera, se mira y
# se descarta.
#
# EL CORTE -espanol largo Y mas de 8 palabras- coge 148 de esas 328 (el 45 %), que son
# 474,3 s de reloj de transcripcion y 432,1 s de audio tirado con Nova SORDA mientras
# repasaba. Entre "lo repasa" y "PARAKEET -> WHISPER" pasan 5,1 s de media.
#
# NO SE PIERDE NI UNA ORDEN: de esas 148, en 120 ya se seguia con el texto de Parakeet, y en
# las 22 restantes Whisper tampoco sacaba ninguna orden local. En dos de ellas era Parakeet
# quien la tenia BIEN y Whisper la destrozo ("abre youtube y reproduce musica de Pitbull" ->
# "abre y duro y reproducente en musica de Pipboon").
#
# POR QUE LAS DOS CONDICIONES Y NO SOLO EL NUMERO: de las 149 frases de mas de 8 palabras,
# UNA no era espanol largo ("No, but I don't know if it's a bien"), y esa si merece que la
# repase alguien que sepa de idiomas.
#
# LA MITAD DEL ARREGLO ES LA PUERTA DE ATRAS: sin $script:yaReintentado la frase cae tres
# lineas mas abajo en el oido fino, que repasa con small (8649 ms por audio frente a los 3425
# de base), o sea volver a preguntar justo lo que se acaba de decidir no preguntar.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA DEL BANCO (van quince): las funciones se TRAEN del fichero real, no se copian. Si se
# copiaran, esta prueba seguiria en verde el dia que alguien cambiara la de verdad.
# Y ConvertTo-Plain va con ella: Test-EspanolLargo la llama por dentro, y sin traerla el
# banco muere con CommandNotFoundException. Es el fallo que la seccion 7 de probar-todo.ps1
# caza, y aqui se evito de entrada.
foreach ($fn in @('ConvertTo-Plain', 'Test-EspanolLargo')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

Write-Host ''
Write-Host '-- el corte sale de config.json, no escrito a mano --'
$mMax = [regex]::Match($fuente, "(?m)^\`$RepasoMaxPalabras = \[int\]\(Get-Cfg 'escucha' 'repasoMaxPalabras' (\d+)\)")
$maxPal = if ($mMax.Success) { [int]$mMax.Groups[1].Value } else { -1 }
Comp 'el numero lo trae Get-Cfg' ($maxPal -ge 1) "por defecto $maxPal"
$cfgTxt = Get-Content -LiteralPath (Join-Path $raiz 'config.json') -Raw -Encoding UTF8
Comp 'y esta en config.json para poder tocarlo' ($cfgTxt -match 'repasoMaxPalabras')

function CuentaPal([string]$t) {
    return @((($t -replace '[^\p{L}\p{N} ]', ' ') -split '\s+') | Where-Object { $_ }).Count
}
function SeSalta([string]$t, [int]$tope) {
    # la misma condicion del bucle: espanol largo Y mas de $tope palabras
    if ($tope -le 0) { return $false }
    return ((CuentaPal $t) -gt $tope) -and (Test-EspanolLargo $t)
}

Write-Host ''
Write-Host '-- las parrafadas en espanol se saltan el repaso --'
foreach ($f in @(
    'Quiero que veas que hay en mi pantalla y me digas que es lo que ves',
    'Ahora por favor abre youtube y reproduce musica de Pitbull',
    'Cual es la distancia del Sol a la Tierra')) {
    $corto = $f.Substring(0, [Math]::Min(40, $f.Length))
    Comp "se salta: $corto" (SeSalta $f $maxPal) "$(CuentaPal $f) palabras"
}

Write-Host ''
Write-Host '-- y lo que NO se salta --'
# El corte es ESTRICTO: mas de 8, no 8 o mas.
$ocho = 'no se si eso que dijiste antes valia'
Comp 'con 8 palabras justas SI se repasa' (-not (SeSalta $ocho $maxPal)) "$(CuentaPal $ocho) palabras"
# La unica frase larga del log que no era espanol: esa si merece que la oiga otro.
$ing = "No, but I don't know if it's a bien"
Comp 'el ingles se repasa aunque sea largo' (-not (SeSalta $ing $maxPal)) 'la unica asi del log'
Comp 'y lo corto va a la cascada de siempre' (-not (SeSalta 'abre steam' $maxPal))
Comp 'con repasoMaxPalabras = 0 vuelve a repasarse todo' `
    (-not (SeSalta 'Quiero que veas que hay en mi pantalla y me digas que es lo que ves' 0)) `
    'el interruptor de apagado'

Write-Host ''
Write-Host '-- la puerta de atras, que es la mitad del arreglo --'
$blq = [regex]::Match($fuente, '(?s)NO REPASAR LO QUE YA SE VA A TIRAR.{0,3500}?Process-Texto \$dicPar')
Comp 'el bloque esta en el bucle' ($blq.Success)
Comp 'cierra el pestillo del oido fino' ($blq.Value -match 'yaReintentado = \$true') 'sin esto cae en small'
Comp 'lo apunta como repaso-ahorrado' ($blq.Value -match 'repaso-ahorrado')
Comp 'y lo dice en el log' ($blq.Value -match 'REPASO AHORRADO')
$rutasOk = $fuente -match "'fino-ahorrado', 'repaso-ahorrado'"
Comp 'repaso-ahorrado sale en la tabla del dia' $rutasOk 'si no, el numero se guarda y no se ve'

Write-Host ''
Write-Host '-- lo que NO debe cambiar --'
Comp 'solo entra lo que transcribio Parakeet' ($fuente -match '\$puedeRepaso = \(\$script:dictadoPorParakeet')
Comp 'el dictado largo sigue fuera' ($fuente -match '-not \$script:dictandoLargo')
Comp 'si Parakeet ya saco una orden, ni se mira' ($fuente -match '-not \$esOrdenPar')
# Test-FastCommand es cara: tiene que seguir llamandose UNA vez por frase, no dos.
$nFast = ([regex]::Matches($fuente, 'Test-FastCommand \$dicPar')).Count
Comp 'Test-FastCommand, una sola llamada por frase' ($nFast -le 1) "$nFast llamadas"
# Test-EspanolLargo tiene otros usuarios (la charla y el 'sigo con lo de Parakeet').
$nEL = ([regex]::Matches($fuente, 'Test-EspanolLargo')).Count
Comp 'Test-EspanolLargo conserva sus otros usos' ($nEL -ge 4) "$nEL menciones"

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  las parrafadas ya no pagan un repaso que se iba a tirar'
exit 0
