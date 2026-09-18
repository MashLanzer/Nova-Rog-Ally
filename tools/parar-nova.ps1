# PARAR A NOVA LIMPIAMENTE (18/09).
#
# Hasta hoy la unica forma de pararla era matar el proceso, y un Stop-Process es un cierre
# brusco: no dispara PowerShell.Exiting, asi que la linea "VoiceAssistant cerrado" del log no
# salia nunca y no se podia distinguir "la pare yo" de "se murio". Cada vez que se toca
# assistant.ps1 hay que reiniciar (se lee entero al arrancar): esto es lo que hay que usar.
#
#   powershell -NoProfile -File tools\parar-nova.ps1
#
# Deja tmp\salir.flag; el bucle la ve en su siguiente vuelta y sale por exit. Los workers
# vigilan al padre y la capsula recibe su PID: se cierran solos. Si en 15 s sigue viva, se
# mata, y se dice, para que quede claro que ese cierre NO fue limpio.
param([int]$EsperaSeg = 15)
$raiz = Split-Path -Parent $PSScriptRoot
$marca = Join-Path $raiz 'tmp\salir.flag'

$nova = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -match '-File\s+.*assistant\.ps1' })
if ($nova.Count -eq 0) { Write-Host 'Nova no esta encendida.'; exit 0 }
$pids = @($nova | ForEach-Object { $_.ProcessId })
Write-Host ("Nova encendida (pid " + ($pids -join ', ') + "). Dejo la marca de salida...")
[System.IO.File]::WriteAllText($marca, 'x')

$t0 = Get-Date
$viva = $true
while (((Get-Date) - $t0).TotalSeconds -lt $EsperaSeg) {
    Start-Sleep -Milliseconds 300
    $viva = @($pids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }).Count -gt 0
    if (-not $viva) { break }
}
if (-not $viva) {
    Write-Host ("Cerrada limpiamente en {0:N1} s." -f ((Get-Date) - $t0).TotalSeconds)
} else {
    Write-Host "No se cerro en $EsperaSeg s: la mato (este cierre NO es limpio y no dejara 'cerrado' en el log)."
    foreach ($p in $pids) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $marca -Force -ErrorAction SilentlyContinue
}
# lo que haya quedado de los workers, por si acaso (vigilan al padre, pero un kill los deja)
Start-Sleep -Milliseconds 800
$restos = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'wake_vosk\.py|tts_worker\.py|charla_worker\.py' })
$ui = @(Get-Process nova_ui -ErrorAction SilentlyContinue)
if ($restos.Count -or $ui.Count) {
    Write-Host ("Quedan restos: " + $restos.Count + " worker(s), capsula " + $(if ($ui.Count) { 'viva' } else { 'no' }) + ". Los cierro.")
    foreach ($r in $restos) { Stop-Process -Id $r.ProcessId -Force -ErrorAction SilentlyContinue }
    foreach ($u in $ui) { Stop-Process -Id $u.Id -Force -ErrorAction SilentlyContinue }
} else {
    Write-Host 'Sin restos: workers y capsula cerrados.'
}
