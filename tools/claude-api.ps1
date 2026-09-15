# Llama a la API de Claude y escribe la respuesta por stdout.
#
# POR QUE UN SCRIPT APARTE: el asistente lanza a opencode como PROCESO y recoge
# su salida de un archivo. Haciendo esto igual, la API entra por la misma puerta
# -misma cancelacion con el boton, mismo progreso en la capsula, misma recogida-
# sin tocar nada de esa maquinaria. Y el bucle principal no se bloquea.
#
#   powershell -File tools\claude-api.ps1 -PromptFile <archivo> [-Modelo ...] [-MaxTokens N]
#
# La clave NO se pasa por argumentos: se lee de ANTHROPIC_API_KEY (del proceso o
# del entorno del usuario). En la linea de comandos la veria cualquiera que mire
# la lista de procesos.
param(
    [Parameter(Mandatory = $true)][string]$PromptFile,
    [string]$Modelo = 'claude-haiku-4-5',
    [int]$MaxTokens = 300,
    [string]$Sistema = '',
    # LO QUE VES EN PANTALLA (15/09): una captura que va con el texto
    [string]$Imagen = '',
    # donde dejar la respuesta, en UTF-8 (ver LAS TILDES, DE PUNTA A PUNTA EN UTF-8)
    [string]$SalidaArchivo = ''
)

$ErrorActionPreference = 'Stop'

# LAS TILDES, DE PUNTA A PUNTA EN UTF-8 (15/09). Llegaban rotas al asistente ("busca Clem??n"
# se aprendio asi): Invoke-RestMethod de PowerShell 5.1 decodificaba la respuesta como Latin-1
# y Write-Output la escribia con la codificacion de la consola. Ahora la respuesta se decodifica
# a mano desde sus bytes y se escribe en bytes UTF-8. Comprobado byte a byte por el mismo camino
# que el asistente (Start-Process con la salida redirigida): "Clem C3 AD n", bien.
# Y por si acaso, con -SalidaArchivo la respuesta se deja tambien en ese archivo, en UTF-8.
# OJO al probarlo: un .ps1 sin BOM con tildes dentro se lee como ANSI y las rompe el mismo.
function Write-Salida([string]$texto) {
    if ($SalidaArchivo) {
        try { [System.IO.File]::WriteAllText($SalidaArchivo, $texto + "`n", (New-Object System.Text.UTF8Encoding($false))) } catch {}
    }
    $flujo = [Console]::OpenStandardOutput()
    $b = [System.Text.Encoding]::UTF8.GetBytes($texto + "`n")
    $flujo.Write($b, 0, $b.Length)
    $flujo.Flush()
}

function Salir([string]$msg) {
    # a stdout, no a stderr: el asistente lee stdout y asi el fallo se ve en la
    # respuesta en vez de perderse
    Write-Salida $msg
    exit 1
}

$clave = $env:ANTHROPIC_API_KEY
if (-not $clave) { $clave = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User') }
if (-not $clave) { $clave = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'Machine') }
if (-not $clave) {
    Salir "(falta la clave: pon ANTHROPIC_API_KEY en las variables de entorno)"
}
$clave = $clave.Trim()

if (-not (Test-Path -LiteralPath $PromptFile)) { Salir "(no encuentro el prompt)" }
$prompt = [System.IO.File]::ReadAllText($PromptFile, [System.Text.Encoding]::UTF8)
if (-not $prompt.Trim()) { Salir "(prompt vacio)" }

$contenido = $prompt
if ($Imagen -and (Test-Path -LiteralPath $Imagen)) {
    # reducida a 1280 px de ancho y en JPEG: la pantalla entera en PNG pesa varios MB
    # y la API no necesita mas para leer una ventana
    try {
        Add-Type -AssemblyName System.Drawing
        $org = [System.Drawing.Image]::FromFile($Imagen)
        try {
            $esc = [Math]::Min(1.0, 1280.0 / $org.Width)
            $w = [int]($org.Width * $esc); $h = [int]($org.Height * $esc)
            $bmp = New-Object System.Drawing.Bitmap($w, $h)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImage($org, 0, 0, $w, $h)
            $g.Dispose()
            $ms = New-Object System.IO.MemoryStream
            $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $pars = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $pars.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]80)
            $bmp.Save($ms, $codec, $pars)
            $bmp.Dispose()
            $b64 = [Convert]::ToBase64String($ms.ToArray())
        } finally { $org.Dispose() }
        $contenido = @(
            @{ type = 'image'; source = @{ type = 'base64'; media_type = 'image/jpeg'; data = $b64 } },
            @{ type = 'text'; text = $prompt }
        )
    } catch {
        [Console]::Error.WriteLine("no pude adjuntar la imagen: " + $_.Exception.Message)
    }
}
$cuerpo = @{
    model      = $Modelo
    max_tokens = $MaxTokens
    messages   = @(@{ role = 'user'; content = $contenido })
}
if ($Sistema) { $cuerpo['system'] = $Sistema }

# UTF-8 a mano tambien al mandar: PowerShell 5.1 manda el cuerpo en la
# codificacion por defecto y los acentos llegaban rotos al modelo.
$json = $cuerpo | ConvertTo-Json -Depth 6 -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri 'https://api.anthropic.com/v1/messages' -Method Post `
        -Headers @{
            'x-api-key'         = $clave
            'anthropic-version' = '2023-06-01'
        } `
        -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 60
    $crudo = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    $r = $crudo | ConvertFrom-Json
} catch {
    $detalle = $_.Exception.Message
    # el cuerpo del error dice MUCHO mas que el mensaje (clave mala, saldo,
    # modelo inexistente...), asi que se intenta leer
    try {
        $respE = $_.Exception.Response
        if ($respE) {
            $sr = New-Object System.IO.StreamReader($respE.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd()
            if ($txt) { $detalle = $txt }
        }
    } catch {}
    Salir ("(error de la API: " + (($detalle -replace '\s+', ' ').Trim()) + ")")
}

$partes = @()
foreach ($b in @($r.content)) {
    if ($b.type -eq 'text' -and $b.text) { $partes += [string]$b.text }
}
if ($partes.Count -eq 0) { Salir "(la API no devolvio texto)" }

# una linea de coste al final, en stderr, para poder mirarlo sin ensuciar la
# respuesta que el asistente va a leer en voz alta
try {
    $u = $r.usage
    [Console]::Error.WriteLine("tokens: entrada=$($u.input_tokens) salida=$($u.output_tokens) modelo=$($r.model)")
} catch {}

Write-Salida ($partes -join "`n")
