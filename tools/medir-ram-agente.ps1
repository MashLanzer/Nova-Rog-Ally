# CUANTA RAM SE LLEVA EL AGENTE, Y SI CABE (18/09).
#
# La prioridad numero dos de braya es velocidad y poca RAM CON UN JUEGO ABIERTO. La parte mas
# pesada de Nova -levantar Claude Code con sus node- es justo la que NO mira la memoria: en todo
# el proyecto hay una sola guarda de RAM en PowerShell (Test-RamParaCharla, 3000 MB para
# precargar el modelo de charla) y el oido tiene las suyas en wake_vosk.py (1200 MB para
# Parakeet, 900 para el preciso). Start-ClaudeCodeJob arranca sin mirar nada.
#
# Esto MIDE, no cambia nada. Lanza una tarea inofensiva igual que la lanza Nova y apunta el pico.
#
#   powershell -NoProfile -File tools\medir-ram-agente.ps1            (modo accion, el pesado)
#   powershell -NoProfile -File tools\medir-ram-agente.ps1 -Modo traducir
#
# DOS CUIDADOS QUE IMPORTAN PARA QUE EL NUMERO NO MIENTA:
#  1. Solo se cuentan los procesos claude/node NUEVOS. Si esto se ejecuta desde una sesion de
#     Claude Code, esa sesion ya pesa cientos de MB y se colaria entera en la medida.
#  2. El pico se mira muestreando, no al final: cuando el proceso termina ya ha liberado.
param(
    [string]$Modo = 'accion',
    [int]$MuestreoMs = 250,
    [int]$TopeSeg = 120
)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

function LibreMB {
    $os = Get-CimInstance Win32_OperatingSystem
    return [double]($os.FreePhysicalMemory / 1024)
}
function Cfg($seccion, $clave, $porDefecto) {
    try {
        $j = Get-Content (Join-Path $raiz 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $v = $j.$seccion.$clave
        if ($null -ne $v -and "$v" -ne '') { return $v }
    } catch {}
    return $porDefecto
}

# los mismos modelos que usa assistant.ps1
$modelo = switch ($Modo) {
    'traducir' { Cfg 'modelo' 'ccTraducir' 'haiku' }
    'accion'   { Cfg 'modelo' 'ccAccion' 'sonnet' }
    default    { Cfg 'modelo' 'ccPregunta' 'sonnet' }
}

# una tarea INOFENSIVA: que conteste y no toque nada
$prompt = 'Responde unicamente con la palabra: listo. No uses ninguna herramienta.'
$fPrompt = Join-Path $env:TEMP ('ram-agente-' + [guid]::NewGuid().ToString('N') + '.txt')
$fOut = $fPrompt + '.out'
[System.IO.File]::WriteAllText($fPrompt, $prompt, (New-Object System.Text.UTF8Encoding($false)))

$argumentos = @('-p', '--output-format', 'stream-json', '--verbose', '--model', $modelo, '--max-turns', '1')
if ($Modo -eq 'accion') {
    # el modo pesado de verdad: el que levanta el MCP de Windows
    $mcp = Join-Path $raiz 'cerebro-mcp.json'   # $LogDir = $PSScriptRoot: la raiz del repo
    if (Test-Path -LiteralPath $mcp) { $argumentos += @('--strict-mcp-config', '--mcp-config', $mcp) }
    $argumentos += @('--permission-mode', 'bypassPermissions', '--no-session-persistence')
} else {
    $argumentos += @('--tools', '""', '--strict-mcp-config', '--no-session-persistence')
}

Write-Host ''
Write-Host "  modo: $Modo   modelo: $modelo"
$libre0 = LibreMB
$total = [double]((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1024)
Write-Host ("  RAM total: {0:N0} MB   libre ANTES: {1:N0} MB" -f $total, $libre0)

# quien ya estaba: esos no cuentan (esta sesion de Claude Code pesa cientos de MB)
$antes = @{}
foreach ($p in @(Get-Process | Where-Object { $_.ProcessName -match '^(claude|node)$' })) { $antes[$p.Id] = $true }
Write-Host ("  procesos claude/node que YA estaban (no cuentan): {0}" -f $antes.Count)

# POR cmd.exe Y CON claude.cmd. Montar a mano una cadena con comillas simples anidadas y un
# redirect para "powershell -Command" no lanzaba NADA: el medidor terminaba en 1,1 s con un
# pico de 0 MB y cantaba "cabe de sobra" sin haber medido. Una llamada de verdad tarda ~14 s.
# Y claude.cmd en vez del claude.ps1 del PATH, que escribe avisos por stderr.
$claudeCmd = Join-Path $env:APPDATA 'npm\claude.cmd'
if (-not (Test-Path -LiteralPath $claudeCmd)) { Write-Host '  no encuentro claude.cmd'; exit 1 }
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'cmd.exe'
$psi.Arguments = '/c type "' + $fPrompt + '" | "' + $claudeCmd + '" ' + ($argumentos -join ' ') + ' > "' + $fOut + '" 2>&1'
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$t0 = Get-Date
$proc = [System.Diagnostics.Process]::Start($psi)

$picoAgente = 0.0
$libreMin = $libre0
$muestras = 0
while (-not $proc.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $TopeSeg) {
    Start-Sleep -Milliseconds $MuestreoMs
    $muestras++
    $suma = 0.0
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(claude|node)$' })) {
        if ($antes.ContainsKey($p.Id)) { continue }     # preexistente: no es del agente
        $suma += $p.WorkingSet64 / 1MB
    }
    if ($suma -gt $picoAgente) { $picoAgente = $suma }
    $l = LibreMB
    if ($l -lt $libreMin) { $libreMin = $l }
}
if (-not $proc.HasExited) { try { $proc.Kill() } catch {} ; Write-Host '  (se paso del tope y se corto)' }
$seg = ((Get-Date) - $t0).TotalSeconds

$salida = ''
if (Test-Path -LiteralPath $fOut) { $salida = (Get-Content -LiteralPath $fOut -Raw) }
Remove-Item -LiteralPath $fPrompt, $fOut -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host ("  duracion:           {0:N1} s   ({1} muestras)" -f $seg, $muestras)
Write-Host ("  PICO del agente:    {0:N0} MB" -f $picoAgente)
Write-Host ("  RAM libre minima:   {0:N0} MB   (empezo con {1:N0})" -f $libreMin, $libre0)
Write-Host ("  se comio:           {0:N0} MB de los {1:N0} libres = {2:N0} % de lo que habia" -f ($libre0 - $libreMin), $libre0, (100.0 * ($libre0 - $libreMin) / [Math]::Max(1, $libre0)))
Write-Host ''
# SIN MEDICION NO HAY VEREDICTO. Si el agente no arranco, el pico es 0 y la duracion ridicula:
# eso no es "cabe de sobra", es que no se ha medido nada. Ya paso una vez.
if ($picoAgente -lt 1 -or $seg -lt 3) {
    Write-Host '  MEDICION NO VALIDA: el agente no llego a arrancar.' -ForegroundColor Red
    Write-Host ("  exit={0}  salida={1} bytes  duracion={2:N1} s" -f $proc.ExitCode, $salida.Length, $seg)
    if ($salida) { Write-Host ('  ' + $salida.Substring(0, [Math]::Min(300, $salida.Length))) }
    exit 1
}
# el criterio de la ficha A2, dicho antes de medir para no moverlo despues
if ($picoAgente -gt ($libre0 / 2)) {
    Write-Host '  VEREDICTO: el pico se come MAS DE LA MITAD de lo que habia libre.' -ForegroundColor Yellow
    Write-Host '             Hay decision que tomar (una guarda como la de la charla).'
} else {
    Write-Host '  VEREDICTO: cabe de sobra. Se cierra por escrito y no se vuelve a proponer.' -ForegroundColor Green
}
if ($salida) { Write-Host ("  (el agente contesto " + $salida.Length + " bytes)") }
