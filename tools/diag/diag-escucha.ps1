# Diagnostico de la escucha continua.
#
# Registra TODO lo que oye el motor: nivel de audio, hipotesis aceptadas y
# tambien las RECHAZADAS con su confianza. Sin esto no hay forma de saber si
# el problema es el microfono, el umbral o el reconocimiento.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\diag\diag-escucha.ps1
# Habla durante los 30 segundos: di "nova" varias veces, claro y normal.

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Speech

$salida = Join-Path $PSScriptRoot 'diag-escucha.txt'
$lineas = New-Object System.Collections.ArrayList
function Anota([string]$m) {
    $t = (Get-Date -Format 'HH:mm:ss.fff') + '  ' + $m
    [void]$lineas.Add($t)
    Write-Host $t
}

Anota "=== dispositivos de entrada del sistema ==="
Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue |
    ForEach-Object { Anota ("   " + $_.Name + "  estado=" + $_.Status) }

$cul = New-Object System.Globalization.CultureInfo('es-ES')
$rec = New-Object System.Speech.Recognition.SpeechRecognitionEngine($cul)
Anota "motor: $($rec.RecognizerInfo.Name) [$($rec.RecognizerInfo.Culture)]"

# Dos gramaticas a la vez:
#  1) la cerrada del nombre, como en el asistente
#  2) DICTADO LIBRE, para ver que entiende realmente cuando hablas
$op = New-Object System.Speech.Recognition.Choices
foreach ($v in @('nova', 'oye nova', 'hola nova', 'nova escucha')) { $op.Add($v) }
$gb = New-Object System.Speech.Recognition.GrammarBuilder
$gb.Culture = $cul
$gb.Append($op)
$gNombre = New-Object System.Speech.Recognition.Grammar($gb)
$gNombre.Name = 'nombre'
$rec.LoadGrammar($gNombre)
Anota "gramatica 'nombre' cargada"

try {
    $gLibre = New-Object System.Speech.Recognition.DictationGrammar
    $gLibre.Name = 'libre'
    $rec.LoadGrammar($gLibre)
    Anota "gramatica 'dictado libre' cargada"
} catch {
    Anota "dictado libre NO disponible: $($_.Exception.Message)"
}

# IMPORTANTE: con RecognizeAsync el evento llega desde otro hilo y PowerShell
# NO vincula $_. Hay que declarar param(...) o el manejador lee un objeto vacio.
$rec.Add_SpeechRecognized({
    param($s, $ev)
    Anota ("ACEPTADO   '" + $ev.Result.Text + "'  confianza=" + [math]::Round($ev.Result.Confidence, 3) +
           "  gramatica=" + $(if ($ev.Result.Grammar) { $ev.Result.Grammar.Name } else { '?' }))
})
$rec.Add_SpeechRecognitionRejected({
    param($s, $ev)
    $alt = ($ev.Result.Alternates | ForEach-Object { $_.Text + '(' + [math]::Round($_.Confidence, 2) + ')' }) -join ' | '
    Anota ("RECHAZADO  '" + $ev.Result.Text + "'  confianza=" + [math]::Round($ev.Result.Confidence, 3) + "  alternativas: " + $alt)
})
$rec.Add_SpeechDetected({ param($s, $ev) Anota "   (voz detectada)" })
$rec.Add_AudioStateChanged({ param($s, $ev) Anota ("   audio: " + $ev.AudioState) })

try {
    $rec.SetInputToDefaultAudioDevice()
    Anota "microfono predeterminado: ABIERTO"
} catch {
    Anota "microfono: FALLO -> $($_.Exception.Message)"
    [System.IO.File]::WriteAllLines($salida, $lineas, (New-Object System.Text.UTF8Encoding($true)))
    exit 1
}

$rec.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
Anota ">>> HABLA AHORA. Di 'nova' varias veces durante 30 segundos <<<"

$t0 = Get-Date
$maxNivel = 0
while (((Get-Date) - $t0).TotalSeconds -lt 30) {
    Start-Sleep -Milliseconds 250
    if ($rec.AudioLevel -gt $maxNivel) { $maxNivel = $rec.AudioLevel }
}
$rec.RecognizeAsyncStop()
Anota "nivel de audio maximo alcanzado: $maxNivel  (0 = el microfono no capta NADA)"
$rec.Dispose()

[System.IO.File]::WriteAllLines($salida, $lineas, (New-Object System.Text.UTF8Encoding($true)))
Write-Host ""
Write-Host "Resultado guardado en: $salida"
