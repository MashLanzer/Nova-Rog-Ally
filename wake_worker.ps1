# Worker de la palabra de activacion.
#
# POR QUE UN PROCESO APARTE:
# Los runspaces de PowerShell NO son seguros entre hilos. Tener el manejador de
# SAPI ejecutando codigo mientras el bucle principal ejecutaba el suyo en el
# mismo runspace mataba el asistente EN SILENCIO. Aqui el reconocimiento vive
# aislado: si falla, el asistente sigue funcionando con el boton.
#
# POR QUE RecognizeAsync Y NO Recognize():
# El sincrono abre el microfono al llamar y lo CIERRA al volver, dejando un
# hueco sordo en cada ciclo. Con async el microfono queda abierto de forma
# continua, que es lo que se necesita para una palabra de activacion.
# En este proceso los eventos son seguros: el hilo principal solo duerme.
#
# Comunicacion: al oir el nombre se crea un archivo marca. El asistente lo ve,
# lo borra y actua.
#
# Uso: wake_worker.ps1 -nombre nova -confianza 0.3 -marca <ruta> -log <ruta>

param(
    [string]$nombre = 'nova',
    [double]$confianza = 0.3,
    [Parameter(Mandatory = $true)][string]$marca,
    [string]$log = ''
)

$ErrorActionPreference = 'Continue'
$script:rutaLog = $log
$script:rutaMarca = $marca
$script:umbral = $confianza

function Anota([string]$m) {
    if (-not $script:rutaLog) { return }
    try {
        $l = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  [escucha] ' + $m
        Out-File -FilePath $script:rutaLog -Append -Encoding utf8 -InputObject $l
    } catch {}
}

try {
    Add-Type -AssemblyName System.Speech
    $cul = New-Object System.Globalization.CultureInfo('es-ES')
    $rec = New-Object System.Speech.Recognition.SpeechRecognitionEngine($cul)

    # Gramatica CERRADA: solo el nombre y sus variantes. Cuanto mas cerrada,
    # menos falsos disparos, porque el motor no tiene con que confundirse.
    $op = New-Object System.Speech.Recognition.Choices
    foreach ($v in @($nombre, "oye $nombre", "hola $nombre", "$nombre escucha", "$nombre por favor", "ey $nombre")) { $op.Add($v) }
    $gb = New-Object System.Speech.Recognition.GrammarBuilder
    $gb.Culture = $cul
    $gb.Append($op)
    $rec.LoadGrammar((New-Object System.Speech.Recognition.Grammar($gb)))

    # OJO: con eventos asincronos PowerShell NO vincula $_. Hay que declarar
    # param(...) o el manejador lee un objeto vacio y no dispara nunca.
    $rec.Add_SpeechRecognized({
        param($remitente, $ev)
        try {
            $c = [math]::Round($ev.Result.Confidence, 2)
            if ($ev.Result.Confidence -ge $script:umbral) {
                Anota "ACTIVADO por '$($ev.Result.Text)' (confianza $c)"
                [System.IO.File]::WriteAllText($script:rutaMarca, (Get-Date -Format 'o'))
            } else {
                Anota "descartado '$($ev.Result.Text)' (confianza $c, minimo $($script:umbral))"
            }
        } catch {}
    })
    # los rechazos son la unica pista util cuando "no detecta nada"
    $rec.Add_SpeechRecognitionRejected({
        param($remitente, $ev)
        try {
            if ($ev.Result -and $ev.Result.Text) {
                Anota "rechazado '$($ev.Result.Text)' (confianza $([math]::Round($ev.Result.Confidence, 2)))"
            }
        } catch {}
    })

    $rec.SetInputToDefaultAudioDevice()
    $rec.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
    Anota "worker en marcha: nombre='$nombre' confianza minima=$confianza (microfono continuo)"
} catch {
    Anota ("ERROR al iniciar: " + $_.Exception.Message)
    exit 1
}

# El hilo principal solo duerme y deja un pulso. Con el microfono abierto de
# forma continua, AudioLevel SI refleja lo que entra: nivel 0 sostenido
# significa que no llega senal, y eso ya es un diagnostico util.
$nivelMax = 0
while ($true) {
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 500
        if ($rec.AudioLevel -gt $nivelMax) { $nivelMax = $rec.AudioLevel }
    }
    Anota "pulso: estado=$($rec.AudioState) nivel maximo en 30 s=$nivelMax"
    $nivelMax = 0
}
