# Genera los tres sonidos del asistente, en sonidos\.
#
# Por qué generarlos en vez de bajarlos: son tres tonos de menos de medio
# segundo, se hacen con cuatro líneas de matemáticas, y así están en el repo
# como CÓDIGO que se puede leer y afinar en vez de como tres binarios que nadie
# sabe de dónde salieron.
#
#   powershell -NoProfile -File tools\hacer-sonidos.ps1
#
# Los tres dicen cosas distintas a propósito, y se distinguen sin mirar:
#   te-oigo   dos notas SUBIENDO    -> "dime"        (abre una pregunta)
#   hecho     dos notas BAJANDO     -> "ya está"     (cierra)
#   no-pude   una nota grave, plana -> "no ha salido"
# El pitido de Windows es el mismo para las tres cosas, y encima es el sonido
# que suena cuando algo va mal en cualquier otro programa.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$destino = Join-Path $raiz 'sonidos'
if (-not (Test-Path -LiteralPath $destino)) { New-Item -ItemType Directory -Force -Path $destino | Out-Null }

$TASA = 44100

# Una nota con entrada y salida suaves. Sin el sobre, el corte seco del final
# suena a "clic" y es justo lo que hace que un pitido resulte barato.
function Nota([double]$hz, [double]$segundos, [double]$volumen) {
    $n = [int]($TASA * $segundos)
    $m = New-Object 'double[]' $n
    $subida = [int]($TASA * 0.006)
    $bajada = [int]($TASA * 0.10)
    for ($i = 0; $i -lt $n; $i++) {
        $sobre = 1.0
        if ($i -lt $subida) { $sobre = $i / [double]$subida }
        elseif ($i -gt ($n - $bajada)) { $sobre = ($n - $i) / [double]$bajada }
        # un poco del armónico de arriba: un seno puro suena a pitido de horno
        $t = $i / [double]$TASA
        $v = [Math]::Sin(2 * [Math]::PI * $hz * $t) + 0.18 * [Math]::Sin(4 * [Math]::PI * $hz * $t)
        $m[$i] = $v * $sobre * $volumen * 0.55
    }
    return $m
}

function Silencio([double]$segundos) {
    return (New-Object 'double[]' ([int]($TASA * $segundos)))
}

function Guardar([string]$nombre, [double[]]$muestras) {
    $total = $muestras.Length
    $bytes = New-Object 'byte[]' ($total * 2)
    $k = 0
    foreach ($v in $muestras) {
        $s = [int]([Math]::Max(-1.0, [Math]::Min(1.0, $v)) * 32000)
        $bytes[$k++] = [byte]($s -band 0xFF)
        $bytes[$k++] = [byte](($s -shr 8) -band 0xFF)
    }
    $ruta = Join-Path $destino ($nombre + '.wav')
    $fs = [System.IO.File]::Create($ruta)
    $w = New-Object System.IO.BinaryWriter($fs)
    try {
        $w.Write([char[]]'RIFF'); $w.Write([int](36 + $bytes.Length))
        $w.Write([char[]]'WAVE'); $w.Write([char[]]'fmt ')
        $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1)
        $w.Write([int]$TASA); $w.Write([int]($TASA * 2))
        $w.Write([int16]2); $w.Write([int16]16)
        $w.Write([char[]]'data'); $w.Write([int]$bytes.Length)
        $w.Write($bytes)
    } finally { $w.Dispose(); $fs.Dispose() }
    Write-Host ("  {0,-10} {1,7:N0} bytes   {2:N2} s" -f ($nombre + '.wav'), (Get-Item $ruta).Length, ($total / [double]$TASA))
}

Write-Host "sonidos en $destino"
# sol4 -> do5: sube, abre, pide
Guardar 'te-oigo'  ((Nota 784 0.085 0.55) + (Nota 1047 0.13 0.5))
# mi5 -> sol4: baja, cierra, "listo"
Guardar 'hecho'    ((Nota 1047 0.075 0.45) + (Nota 784 0.15 0.42))
# una sola, grave y sin adornos: nada que celebrar
Guardar 'no-pude'  ((Nota 320 0.055 0.5) + (Silencio 0.035) + (Nota 262 0.19 0.45))
Write-Host ""
Write-Host "Listo. El asistente los usa solo; si borras la carpeta, vuelve a los pitidos de Windows."
