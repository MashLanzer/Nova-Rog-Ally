# Prueba EN VIVO de lo que el banco de texto no ve: arranca Nova de verdad, le
# pasa frases escritas (tools\decir.ps1), mira el log y la para.
#
#   powershell -NoProfile -File tools\probar-vivo.ps1
#   powershell -NoProfile -File tools\probar-vivo.ps1 -Restaurar   (si se corto a medias)
#
# Comprueba: que arranca; una orden local; que una opinion sobre un juego NO lo
# abre; una charla larga (varias frases seguidas, que Nova no se interrumpe sola y
# que la voz preparada llega a tiempo); y un dato concreto (a la API o al cerebro).
# Hace dos fotos de la RAM por pieza (en reposo y tras la charla).
#
# ANTES copia memoria\ y config.json a %TEMP%\nova-probar-vivo, y al terminar los
# devuelve tal cual: lo que Nova aprenda o apunte durante la prueba no se queda.
# Si el sistema la matara por falta de memoria, el final no llega a ejecutarse:
# por eso existe -Restaurar. Nova tiene que estar APAGADA antes de empezar.
param([switch]$Restaurar)

$R = Split-Path -Parent $PSScriptRoot
$B = Join-Path $env:TEMP 'nova-probar-vivo'

function Devolver {
    if (-not (Test-Path (Join-Path $B 'memoria'))) { Write-Host "  no hay copia en $B"; return }
    Remove-Item (Join-Path $R 'memoria') -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $B 'memoria') (Join-Path $R 'memoria') -Recurse
    Copy-Item (Join-Path $B 'config.json') (Join-Path $R 'config.json') -Force
    Write-Host "  memoria y config.json devueltas (copia del $((Get-Item $B).LastWriteTime))"
}

if ($Restaurar) { Devolver; exit 0 }

$ya = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'assistant\.ps1' -and $_.CommandLine -notmatch 'Probar|probar-vivo' })
if ($ya.Count -gt 0) { Write-Host "Nova esta encendida (PID $($ya[0].ProcessId)). Apagala antes: esta prueba la arranca ella."; exit 1 }
$libre = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
if ($libre -lt 2000) { Write-Host "Solo $libre MB libres (hacen falta 2000). Cierra algo y vuelve a probar."; exit 1 }

if (Test-Path $B) { Remove-Item $B -Recurse -Force }
New-Item -ItemType Directory $B | Out-Null
Copy-Item (Join-Path $R 'memoria') (Join-Path $B 'memoria') -Recurse
Copy-Item (Join-Path $R 'config.json') (Join-Path $B 'config.json')
Write-Host "copia de seguridad en $B  (si esto se corta: tools\probar-vivo.ps1 -Restaurar)"

$log = Join-Path $R 'assistant.log'
$fallos = 0
function Comp($etq, $ok, $det = '') {
    if ($ok) { Write-Host "  OK   $etq" } else { Write-Host "  MAL  $etq  $det" -ForegroundColor Red; $script:fallos++ }
}
function Lineas($desde) { @(Get-Content $log | Select-Object -Skip $desde) }
function Esperar($desde, $patron, $seg) {
    $t0 = Get-Date
    do { Start-Sleep -Milliseconds 500; $n = Lineas $desde } until (($n -match $patron) -or ((Get-Date) - $t0).TotalSeconds -gt $seg)
    return [bool]((Lineas $desde) -match $patron)
}
function Decir($frase) {
    $ini = (Get-Content $log).Count
    powershell -NoProfile -File (Join-Path $R 'tools\decir.ps1') $frase | Out-Null
    return $ini
}
function Arbol($id) { Get-CimInstance Win32_Process -Filter "ParentProcessId=$id" | ForEach-Object { Arbol $_.ProcessId; $_.ProcessId } }
function Foto($etq, $raiz) {
    $ids = @(Arbol $raiz) + $raiz
    $filas = foreach ($pr in (Get-CimInstance Win32_Process)) {
        $c = [string]$pr.CommandLine
        $pieza = $null
        if ($ids -contains $pr.ProcessId) {
            if ($c -match 'wake_vosk') { $pieza = 'escucha (Vosk + Whisper)' }
            elseif ($c -match 'charla_worker') { $pieza = 'charla (worker)' }
            elseif ($c -match 'tts_worker') { $pieza = 'voz en linea (worker)' }
            elseif ($pr.Name -match 'nova_ui') { $pieza = 'capsula' }
            elseif ($c -match 'assistant\.ps1') { $pieza = 'asistente (PowerShell)' }
            elseif ($pr.Name -match 'piper') { $pieza = 'voz sin conexion (Piper)' }
            else { $pieza = "otro: $($pr.Name)" }
        } elseif ($pr.Name -match '^ollama') { $pieza = "Ollama ($($pr.Name))" }
        if ($pieza) { [pscustomobject]@{ pieza = $pieza; MB = [int]($pr.WorkingSetSize / 1MB) } }
    }
    $tot = ($filas | Measure-Object MB -Sum).Sum
    Write-Host ""
    Write-Host "  RAM, $etq (total $tot MB; libres $([int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)) MB):"
    $filas | Group-Object pieza | ForEach-Object { [pscustomobject]@{ pieza = $_.Name; MB = ($_.Group | Measure-Object MB -Sum).Sum; n = $_.Count } } |
        Sort-Object MB -Descending | ForEach-Object { Write-Host ("    {0,-32} {1,6} MB{2}" -f $_.pieza, $_.MB, $(if ($_.n -gt 1) { "  ($($_.n) procesos)" } else { '' })) }
}

$inicio = (Get-Content $log).Count
$p = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', (Join-Path $R 'assistant.ps1')) -WorkingDirectory $R -PassThru
Write-Host "Nova arrancada (PID $($p.Id))"
try {
    Write-Host ""
    Write-Host "--- arranque"
    Comp "arranca y carga Whisper" (Esperar $inicio "whisper .base. cargado" 60)
    Start-Sleep -Seconds 5
    Foto 'en reposo' $p.Id

    Write-Host ""
    Write-Host "--- orden local"
    $i = Decir "que hora es"
    Comp "'que hora es' la hace la capa local" (Esperar $i 'LOCAL: que hora es' 20)
    Start-Sleep -Seconds 6

    Write-Host ""
    Write-Host "--- nombrar un juego no es pedirlo"
    $i = Decir "que opinas de outlast"
    [void](Esperar $i 'charla: contesto|CONFIRMAR|LOCAL:' 90)
    $n = Lineas $i
    Comp "'que opinas de outlast' no pregunta si abrirlo" (-not ($n -match 'CONFIRMAR|LOCAL: que opinas')) (($n -match 'CONFIRMAR|LOCAL:') -join ' | ')
    [void](Esperar $i 'charla: contesto' 60)
    Start-Sleep -Seconds 10

    Write-Host ""
    Write-Host "--- charla larga"
    $i = Decir "cuentame un poco de hollow knight en cuatro o cinco frases"
    Comp "contesta" (Esperar $i 'charla: contesto' 120)
    # hasta que deje de decir frases (8 s sin ninguna nueva)
    $t0 = Get-Date; $antes = -1
    do { Start-Sleep -Seconds 4; $ahora = @(Lineas $i | Where-Object { $_ -match 'charla dice' }).Count; $quieto = ($ahora -eq $antes); $antes = $ahora } until ($quieto -or ((Get-Date) - $t0).TotalSeconds -gt 90)
    $n = Lineas $i
    $dichas = @($n | Where-Object { $_ -match 'charla dice' }).Count
    $prep = @($n | Where-Object { $_ -match 'voz: frase ya preparada' }).Count
    $almomento = @($n | Where-Object { $_ -match 'voz: frase sintetizada al momento' }).Count
    Write-Host "  frases dichas: $dichas | voz ya preparada: $prep | sintetizada al momento: $almomento | origen: $((@($n | Where-Object { $_ -match 'charla: contesto' }) -replace '.*contesto ', '') -join ',')"
    Comp "dice varias frases seguidas" ($dichas -ge 2) "solo $dichas"
    Comp "Nova no se interrumpe a si misma" (-not ($n -match 'INTERRUMPIDA')) (($n -match 'interrumpida') -join ' | ')
    if ($dichas -ge 2) { Comp "alguna frase llega ya preparada" ($prep -ge 1) "preparadas $prep, al momento $almomento" }
    $desc = @($n | Where-Object { $_ -match 'corte descartado' }).Count
    if ($desc -gt 0) { Write-Host "  (su propia voz descartada como corte: $desc veces)" }
    Foto 'tras la charla' $p.Id

    Write-Host ""
    Write-Host "--- dato concreto"
    $i = Decir "quien hizo hollow knight"
    [void](Esperar $i 'charla: contesto|dato concreto|CONFIRMAR' 90)
    $n = Lineas $i
    Comp "'quien hizo hollow knight' no pregunta si abrirlo" (-not ($n -match 'CONFIRMAR')) (($n -match 'CONFIRMAR') -join ' | ')
    Comp "va a la API (o al cerebro sin API), no al modelo local" ([bool]($n -match 'charla: contesto \(api\)|dato concreto')) (($n -match 'charla: contesto') -join ' | ')
} finally {
    $ids = @(Arbol $p.Id) + $p.Id
    foreach ($id in $ids) { try { Stop-Process -Id $id -Force -ErrorAction Stop } catch {} }
    Start-Sleep -Seconds 2
    $quedan = @(Get-Process -Id $ids -ErrorAction SilentlyContinue).Count
    Write-Host ""
    Write-Host "Nova parada ($($ids.Count) procesos, quedan $quedan)"
    Devolver
}
Write-Host ""
if ($fallos -eq 0) { Write-Host "todo correcto" } else { Write-Host "$fallos casos MAL" }
exit $(if ($fallos -eq 0) { 0 } else { 1 })
