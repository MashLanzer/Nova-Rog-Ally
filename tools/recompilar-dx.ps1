# RECOMPILAR assistant-dx.dll DESDE assistant-dx.cs, y dejar el hash al dia.
#
# Por que hace falta un script: el DLL se carga con Add-Type -Path, asi que mientras Nova
# este en marcha el archivo esta BLOQUEADO y no se puede sobrescribir. Y si se recompila y
# se olvida el hash, assistant.ps1 avisa en cada arranque de que el DLL "NO coincide con el
# hash esperado", que es justo el aviso que hay que poder creerse.
#
# No se recompila al arrancar a proposito: invocar csc en cada arranque COLGABA y mataba el
# proceso en silencio (por eso se precompila desde el 10/09).
#
# Uso:   powershell -NoProfile -File tools\recompilar-dx.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$cs = Join-Path $raiz 'assistant-dx.cs'
$dll = Join-Path $raiz 'assistant-dx.dll'
$cfg = Join-Path $raiz 'config.json'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'

if (-not (Test-Path -LiteralPath $cs)) { Write-Host "  no encuentro $cs"; exit 1 }
if (-not (Test-Path -LiteralPath $csc)) { Write-Host "  no encuentro el compilador: $csc"; exit 1 }

# 1) ¿ESTA COGIDO? Se comprueba ABRIENDOLO EN EXCLUSIVA, no mirando los modulos de cada
# proceso: eso fue lo primero que escribi y no lo vio: .Modules salta por permisos en
# media lista de procesos y el que importa se colaba. Abrir el archivo no falla nunca por
# permisos ajenos, y es exactamente la operacion que va a hacer Copy-Item despues.
$cogido = $false
if (Test-Path -LiteralPath $dll) {
    try {
        $fs = [System.IO.File]::Open($dll, 'Open', 'ReadWrite', 'None')
        $fs.Close(); $fs.Dispose()
    } catch { $cogido = $true }
}
if ($cogido) {
    # de paso, quien es: si se puede saber, se dice; si no, tampoco pasa nada
    $quien = @()
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
        try { foreach ($m in $p.Modules) { if ($m.FileName -eq $dll) { $quien += ("{0} (pid {1})" -f $p.ProcessName, $p.Id); break } } } catch {}
    }
    Write-Host ''
    Write-Host '  assistant-dx.dll esta cogido por otro proceso: Nova esta en marcha.' -ForegroundColor Yellow
    if ($quien.Count -gt 0) { $quien | ForEach-Object { Write-Host "     $_" } }
    Write-Host '  Parala antes de recompilar y vuelve a ejecutar esto.'
    Write-Host ''
    exit 2
}

# 2) compilar aparte y solo mover si sale limpio: un DLL a medias deja a Nova sin arrancar
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('dx-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.dll')
$salida = & $csc /nologo /target:library "/out:$tmp" $cs 2>&1
$errores = @($salida | Where-Object { $_ -match 'error CS' })
if ($errores.Count -gt 0) {
    Write-Host '  no compila:' -ForegroundColor Red
    $errores | Select-Object -First 8 | ForEach-Object { Write-Host "     $_" }
    exit 1
}

# 3) y que el DLL nuevo cargue y traiga lo que se espera, antes de ponerlo en su sitio
try {
    Add-Type -Path $tmp
    $faltan = @()
    foreach ($m in @('LeerVolumen', 'PonerVolumen', 'OlvidarVolumen', 'XInputGetState', 'SetForegroundWindow')) {
        if (-not ([AX].GetMethods() | Where-Object { $_.Name -eq $m })) { $faltan += $m }
    }
    if ($faltan.Count -gt 0) {
        Write-Host ("  el DLL nuevo no trae: " + ($faltan -join ', ')) -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ("  el DLL nuevo no carga: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

$antes = if (Test-Path -LiteralPath $dll) { (Get-Item -LiteralPath $dll).Length } else { 0 }
Copy-Item -LiteralPath $tmp -Destination $dll -Force
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$hash = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
Write-Host ("  assistant-dx.dll: {0} -> {1} bytes" -f $antes, (Get-Item -LiteralPath $dll).Length)

# 4) el hash, en config.json. Sin esto, cada arranque avisaria de un cambio que fuiste tu.
$texto = [System.IO.File]::ReadAllText($cfg)
$viejo = [regex]::Match($texto, '"hashDll"\s*:\s*"([0-9A-Fa-f]*)"')
if (-not $viejo.Success) {
    Write-Host '  no encuentro seguridad.hashDll en config.json; ponlo a mano:'
    Write-Host "     $hash"
    exit 1
}
$texto = $texto.Remove($viejo.Groups[1].Index, $viejo.Groups[1].Length).Insert($viejo.Groups[1].Index, $hash)
# SIN BOM: config.json lo leen tambien pipeline-hoy.py y completar-vectores.py, y un BOM
# los rompio el 20/09. Se escribe igual que estaba.
[System.IO.File]::WriteAllText($cfg, $texto, (New-Object System.Text.UTF8Encoding $false))
Write-Host "  config.json -> seguridad.hashDll = $hash"
Write-Host ''
Write-Host '  listo. Arranca Nova y el DLL nuevo entra con ella.'
exit 0
