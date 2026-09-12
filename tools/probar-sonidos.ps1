# Los tres sonidos propios, del archivo real.
# Lo que puede salir mal: que el WAV esté mal formado (SoundPlayer.Load lo dice,
# reproducirlo no), y sobre todo que faltar la carpeta deje al asistente mudo.
# Eso último es lo importante: un pitido que no suena no se nota hasta que
# necesitas saber si te ha oído.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$LogDir = $raiz
$SonidosDir = Join-Path $raiz 'sonidos'
$script:sonidos = @{}
Invoke-Expression (Traer 'Play-Sonido')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# 1) los tres existen y Windows los acepta (Load valida la cabecera del WAV)
foreach ($n in @('te-oigo', 'hecho', 'no-pude')) {
    $f = Join-Path $SonidosDir ($n + '.wav')
    $ok = $false; $detalle = 'no existe'
    if (Test-Path -LiteralPath $f) {
        try {
            $sp = New-Object System.Media.SoundPlayer $f
            $sp.Load()
            $ok = $true
            $detalle = "{0:N0} bytes" -f (Get-Item $f).Length
        } catch { $detalle = $_.Exception.Message }
    }
    Comp "$n.wav vale como WAV" $ok $detalle
}

# 2) suenan distinto: si los tres fueran iguales, no servirían de nada
$hashes = @{}
foreach ($n in @('te-oigo', 'hecho', 'no-pude')) {
    $hashes[$n] = (Get-FileHash (Join-Path $SonidosDir ($n + '.wav')) -Algorithm SHA256).Hash
}
Comp 'los tres son distintos' (@($hashes.Values | Select-Object -Unique).Count -eq 3) ''

# 3) y lo que de verdad importa: sin carpeta, NO revienta
$antes = $SonidosDir
$SonidosDir = Join-Path $env:TEMP ('no-existe-' + [guid]::NewGuid().ToString('N'))
$script:sonidos = @{}
$exploto = $false
try { Play-Sonido 'te-oigo' $null } catch { $exploto = $true }
Comp 'sin la carpeta no revienta' (-not $exploto) 'y cae al pitido de Windows'
$respaldo = $false
try { Play-Sonido 'te-oigo' ([System.Media.SystemSounds]::Beep); $respaldo = $true } catch { }
Comp 'y el respaldo se puede usar' $respaldo ''
$SonidosDir = $antes

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
