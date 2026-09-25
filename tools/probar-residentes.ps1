# QUE NO SE VUELVA A COLAR UN WORKER SIN PROTECCION (25/09, ideas 19 y 20)
#
# LO QUE PASO: voz_windows.py estuvo TRECE DIAS sin ninguna de las dos protecciones que tienen
# los demas workers, y nadie se entero hasta que habia 44 procesos vivos comiendo 1,3 GB con
# braya jugando. No fue mala suerte: fue que nada lo comprobaba.
#
# LAS DOS PROTECCIONES, y basta con una:
#   a) leer ordenes por la entrada estandar: cuando el padre muere, esa tuberia se cierra, el
#      bucle termina y el proceso se apaga solo. Asi se salvan charla_worker y tts_worker.
#   b) recibir NOVA_PID_PADRE y mirar si ese PID sigue vivo. Asi se salva wake_vosk desde el
#      13/09, y voz_windows desde el 24/09.
# voz_windows.py no tenia NINGUNA. De ahi el reparto exacto que se encontro: 44 de ese y cero
# de los otros tres.
#
# IDEA 20, LA OTRA MITAD: la lista de procesos que se matan al salir se ampliaba A MANO, y
# habia crecido tres veces en cuatro dias -piperProc el 21/09, guiaProc y vozWinProc el 24/09-,
# cada vez porque alguien descubrio que faltaba uno. Ahora se construye sola recorriendo las
# variables de proceso que existan, asi que un worker nuevo entra sin que nadie se acuerde.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. TODO worker de Python residente tiene una de las dos protecciones --'
# Se buscan los .py que el asistente arranca y se quedan vivos, y para cada uno se comprueba en
# SU PROPIO codigo que tiene stdin o NOVA_PID_PADRE. No se da nada por sabido: se mira el .py.
$residentes = @()
foreach ($m in [regex]::Matches($sinCom, '([a-z_]+)\.py')) {
    $n = $m.Groups[1].Value
    if ($residentes -notcontains $n) { $residentes += $n }
}
# RESIDENTE ES EL QUE TIENE UN BUCLE QUE NO TERMINA SOLO (25/09, y el criterio costo dos
# intentos). El primero metia en la lista todo .py que se nombrara, y acuso a ajedrez_turno.py
# de no tener proteccion cuando ese se llama con "&": el asistente ESPERA a que termine, asi
# que no puede quedarse huerfano ni queriendo. El segundo miraba si el nombre aparecia cerca de
# un Start-Process, y se dejo fuera a casi todos, porque el asistente los lanza por una
# variable ($worker, $wv) escrita lejos del arranque.
#
# El criterio bueno no esta en quien lo arranca sino en el propio worker: lo que hace que un
# proceso pueda quedarse huerfano es tener un bucle que NO TERMINA SOLO. Uno que hace su cuenta
# y sale no sobrevive a nadie por definicion.
$residentes = @($residentes | Where-Object {
    $ruta = Join-Path $Raiz ($_ + '.py')
    if (-not (Test-Path -LiteralPath $ruta)) { return $false }
    $c = [IO.File]::ReadAllText($ruta)
    ($c -match '(?m)^\s*while\s+(True|1)\s*:') -or ($c -match '(?m)^\s*for\s+\w+\s+in\s+sys\.stdin')
})
Comp 'se encuentran los workers de Python' ($residentes.Count -ge 3) "$($residentes -join ', ')"

foreach ($w in $residentes) {
    $ruta = Join-Path $Raiz ($w + '.py')
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    $c = [IO.File]::ReadAllText($ruta)
    $porTuberia = $c -match 'sys\.stdin'
    $porPid = $c -match 'NOVA_PID_PADRE'
    $como = if ($porTuberia -and $porPid) { 'tuberia y PID' }
            elseif ($porTuberia) { 'tuberia' }
            elseif ($porPid) { 'PID del padre' }
            else { 'NINGUNA' }
    Comp ("  " + $w + ".py no puede quedarse huerfano") ($porTuberia -or $porPid) $como
}

Write-Host ''
Write-Host '-- 2. y la lista de los que se matan al salir se construye SOLA (idea 20) --'
Comp 'existe Get-ProcesosResidentes' ($sinCom -match 'function Get-ProcesosResidentes') ''
$iG = $sinCom.IndexOf('function Get-ProcesosResidentes')
$blG = if ($iG -gt 0) { $sinCom.Substring($iG, [Math]::Min(900, $sinCom.Length - $iG)) } else { '' }
Comp 'y los busca, no los escribe a mano' ($blG -match 'Get-Variable') 'asi un worker nuevo entra solo'
Comp 'mirando que sean procesos de verdad' ($blG -match 'Diagnostics\.Process') 'no cualquier variable que acabe en Proc'
# LA LISTA A MANO YA NO ESTA: si siguiera, seria la que manda y esto no serviria de nada
Comp 'el parar limpio ya no lleva la lista a mano' (-not ($sinCom -match 'foreach \(\$pW in @\(\$script:wakeProc')) 'esa lista crecio 3 veces en 4 dias'
Comp 'y usa la que se construye sola' ($sinCom -match 'foreach \(\$pW in @\(Get-ProcesosResidentes\)') ''

Write-Host ''
Write-Host '-- 3. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-ProcesosResidentes' }, $true)
if (-not $d) {
    Comp 'se saca Get-ProcesosResidentes del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text

# se montan variables de proceso de mentira, como las del asistente
$p1 = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 20') -WindowStyle Hidden -PassThru
$null = $p1.Handle
$p2 = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 20') -WindowStyle Hidden -PassThru
$null = $p2.Handle
try {
    $script:wakeProc = $p1
    $script:inventadoProc = $p2      # un worker NUEVO que nadie ha anadido a ninguna lista
    $script:ttsProc = $null          # uno que no ha arrancado
    $script:noEsProc = 'texto'       # una variable que acaba en Proc y no es un proceso
    $r = @(Get-ProcesosResidentes)
    Comp 'encuentra los procesos vivos' ($r.Count -eq 2) "$($r.Count)"
    Comp 'incluye uno que nadie apunto en ninguna lista' (@($r | Where-Object { $_.Id -eq $p2.Id }).Count -eq 1) 'esto es lo que evita el proximo voz_windows'
    Comp 'y no se traga una variable que no es un proceso' (@($r | Where-Object { $_ -is [string] }).Count -eq 0) ''
    Comp 'ni los que no han arrancado' (@($r | Where-Object { -not $_ }).Count -eq 0) ''
} finally {
    foreach ($p in @($p1, $p2)) { try { if (-not $p.HasExited) { $p.Kill() } } catch {} }
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  ningun residente se queda sin red'
exit 0
