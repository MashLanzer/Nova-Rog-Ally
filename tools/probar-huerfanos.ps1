# LOS WORKERS QUE SOBREVIVIAN A NOVA (24/09)
#
# LO MEDIDO: el 24/09 a las 21:53 Nova murio de golpe mientras braya jugaba, y a las 22:30
# habia 44 procesos voz_windows.py vivos comiendo 1,3 GB en una maquina donde Windows ve
# 11,70 GB y A Way Out estaba usando 1,9. Eso es la regla 5 de la casa rota: nada residente
# comiendo RAM que le hace falta al juego.
#
# POR QUE SE ACUMULABAN, y son tres agujeros distintos:
#   1. voz_windows.py no mira si su padre sigue vivo. wake_vosk.py SI lo hace desde el 13/09
#      (NOVA_PID_PADRE + padre_vivo), y por eso en el registro se lee "el asistente ya no
#      existe; salgo y suelto el microfono". El de Windows no tenia nada: su bucle ocioso
#      duerme 80 ms y vuelve a mirar la marca, para siempre.
#   2. El "parar limpio" (assistant.ps1) mata wakeProc, ttsProc, prepVozProc y piperProc.
#      vozWinProc NO esta en esa lista. Esa lista se ha ido ampliando cada vez que se
#      descubria uno que faltaba: piperProc entro el 21/09, guiaProc el 24/09.
#   3. El barrido de huerfanos del arranque (17/09) busca wake_vosk, tts_worker y
#      charla_worker. voz_windows NO esta. Es la manera 7 de salir verde mintiendo, pero
#      del reves: una lista cerrada que el diseno amplio y nadie volvio a tocar.
#      OJO CON LA VENTANA TEMPORAL: voz_windows.py nacio el 11/09 a las 23:00 y el barrido
#      se arreglo el 17/09 a las 16:34. No es desfase, es un olvido.
#
# CUANTAS VECES PASO, en la ventana justa: el "VoiceAssistant cerrado" se anadio el 18/09 a
# las 17:06, asi que solo se puede contar desde ahi. Del 18/09 al 24/09: 61 "iniciado" y 35
# "cerrado". 26 cierres sucios en seis dias, y en un cierre sucio PowerShell.Exiting no
# dispara por definicion.
#
# ESTE BANCO NO MIRA LA FORMA DEL CODIGO (leccion del commit e1ab4dc). La seccion 3 arranca
# un worker de verdad con un padre de mentira, mata al padre y mira si el worker se muere
# solo. Las funciones de la seccion 2 se sacan del .py real con el arbol de Python y se
# EJECUTAN, no se leen.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
# OJO: PowerShell NO distingue mayusculas, asi que $PY y $py serian la misma
# variable. La primera version de este banco leia el fichero en $py y con eso
# pisaba la ruta: al worker le llegaban las 129 lineas del .py como argumento, y
# moria al instante. El banco lo contaba como 'no arranco' sin decir por que.
$RutaVoz = Join-Path $Raiz 'voz_windows.py'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  ($detalle)" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  ($detalle)" })); $script:mal++ }
}

Write-Host '-- 1. los tres agujeros, cerrados --'
$txt = [IO.File]::ReadAllText($PS1)
# LOS COMENTARIOS FUERA (24/09, lo cazo una rotura). La primera version buscaba 'voz_windows'
# en el texto tal cual, y el comentario que explica el arreglo CONTIENE esa palabra: se podia
# borrar la comprobacion del codigo y el banco seguia verde. Es la manera 2 de salir verde
# mintiendo, y estaba escrita desde el 23/09. Aqui se cae una linea entera si empieza por '#'.
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# el arbol, para sacar funciones enteras y ejecutarlas (y no adivinarlas con un regex)
$errAst = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$errAst)
$fuentePy = [IO.File]::ReadAllText($RutaVoz)

# el barrido del arranque: se saca el bloque de verdad, no todo el fichero
$iB = $txt.IndexOf('workers de una sesion anterior que se quedaron huerfanos')
Comp 'el barrido de huerfanos sigue existiendo' ($iB -gt 0) ''
# el ancla es un comentario, asi que se busca en el texto entero; el TROZO que se mira, no
$iB2 = $sinCom.IndexOf('Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |')
$barrido = if ($iB2 -gt 0) { $sinCom.Substring($iB2, [Math]::Min(900, $sinCom.Length - $iB2)) } else { '' }
Comp 'el barrido busca voz_windows' ($barrido -match 'voz_windows') 'el que dejaba 44 vivos'
foreach ($w in @('wake_vosk', 'tts_worker', 'charla_worker')) {
    Comp ("y sigue buscando " + $w) ($barrido -match $w) 'no se pierde ninguno de los de antes'
}

# EL PARAR LIMPIO YA NO MATA POR LISTA (25/09, idea 20). Esto pedia literalmente
# "foreach ($pW in @($script:wakeProc" y luego que en esa linea estuvieran vozWinProc,
# ttsProc, prepVozProc y piperProc. Ese mismo dia la lista a mano se cambio por
# Get-ProcesosResidentes -que barre las variables *Proc del ambito, para que no haya lista que
# olvidar ampliar- y CINCO comprobaciones se pusieron rojas con el fallo arreglado. El banco
# estaba anclado a como estaba escrito, no a lo que hace.
#
# Lo de ahora prueba mas: que el parar limpio pregunte por los residentes, y que la funcion
# que responde los encuentre de verdad, EJECUTANDOLA con procesos reales delante. Asi un
# residente nuevo entra solo, que es justo lo que la lista a mano no hacia.
$iK = $sinCom.IndexOf('foreach ($pW in @(Get-ProcesosResidentes')
Comp 'el parar limpio pregunta por los residentes' ($iK -gt 0) 'y no por una lista escrita a mano'
$dRes = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-ProcesosResidentes' }, $true)
Comp '  existe Get-ProcesosResidentes' ($null -ne $dRes) ''
if ($dRes) {
    Invoke-Expression $dRes.Extent.Text
    $yo = Get-Process -Id $PID
    # los cinco de siempre MAS el que se descubrio el 24/09: si el barrido dejara de verlos,
    # volveriamos a los 44 huerfanos de 1,3 GB
    $script:wakeProc = $yo; $script:ttsProc = $yo; $script:prepVozProc = $yo
    $script:piperProc = $yo; $script:vozWinProc = $yo; $script:guiaProc = $yo
    $script:noEsUnProceso = 'una cadena'
    $hallados = @(Get-ProcesosResidentes)
    Comp '  y los encuentra a los seis' ($hallados.Count -ge 6) "$($hallados.Count) de 6"
    Comp '  sin colar lo que no es un proceso' ((@($hallados | Where-Object { $_ -isnot [System.Diagnostics.Process] }).Count) -eq 0) ''
    $script:wakeProc = $null; $script:ttsProc = $null; $script:prepVozProc = $null
    $script:piperProc = $null; $script:vozWinProc = $null; $script:guiaProc = $null
}

# el PID del padre, para los DOS arranques del worker
$n = ([regex]::Matches($txt, 'voz_windows\.py')).Count
Comp 'voz_windows.py se nombra en el asistente' ($n -ge 2) "$n veces: arranque y relanzamiento"
$iA = $sinCom.IndexOf('if ($VozWindowsOn) {')
$blA = if ($iA -gt 0) { $sinCom.Substring($iA, [Math]::Min(600, $sinCom.Length - $iA)) } else { '' }
Comp 'el arranque pone NOVA_PID_PADRE' ($blA -match 'NOVA_PID_PADRE') 'sin esto el hijo no sabe de quien es'
$iR = $sinCom.IndexOf('if ($VozWindowsOn -and ($sw.ElapsedMilliseconds - $script:vozWinCheck)')
$blR = if ($iR -gt 0) { $sinCom.Substring($iR, [Math]::Min(1100, $sinCom.Length - $iR)) } else { '' }
Comp 'y el relanzamiento tambien' ($blR -match 'NOVA_PID_PADRE') 'el relanzado tambien puede quedar huerfano'

# y que NO dependa de la rama del motor: la del oido esta dentro de if motor -eq vosk
$iV = $sinCom.IndexOf("if (`$EscuchaMotor -eq 'vosk')")
Comp 'la del oido sigue en su sitio' ($iV -gt 0) ''
Comp 'pero la del dictado NO depende de esa rama' ($iA -gt $iV -and $blA -match 'NOVA_PID_PADRE') 'con otro motor tambien queda protegido'

Write-Host ''
Write-Host '-- 2. las funciones del worker, SACADAS DEL .PY Y EJECUTADAS --'
Comp 'voz_windows.py lee NOVA_PID_PADRE' ($fuentePy -match 'NOVA_PID_PADRE') ''
Comp 'y tiene padre_vivo' ($fuentePy -match 'def padre_vivo') ''
# Y EN LOS DOS BUCLES, NO EN UNO (24/09, lo cazo una rotura). Con una sola llamada el banco
# salia verde: la seccion 3 no crea la marca de dictado, asi que el worker no llega nunca al
# segundo bucle y nadie se enteraba de que le faltaba el vistazo. Se cuentan las LLAMADAS
# -morir_si_huerfano() con parentesis- sin contar la definicion ni los comentarios.
$pyCodigo = (($fuentePy -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$llamadas = ([regex]::Matches($pyCodigo, '(?<!def )morir_si_huerfano\(\)')).Count
Comp 'lo comprueba en los DOS bucles de espera' ($llamadas -eq 2) "$llamadas llamada(s): el ocioso y el del dictado"
Write-Host ''
python (Join-Path $PSScriptRoot 'probar-huerfanos-funciones.py')
if ($LASTEXITCODE -ne 0) { $mal++ }

Write-Host ''
Write-Host '-- 3. LA PRUEBA DE VERDAD: un worker real con un padre de mentira --'
# Aqui no se mira el codigo: se arranca voz_windows.py de verdad, se le dice que su padre es
# un powershell que este banco acaba de crear, se comprueba que vive, se mata al padre y se
# mira si el hijo se muere solo. Es exactamente lo que paso a las 21:53.
#
# NO TOCA EL MICROFONO: el worker solo llama al reconocedor cuando existe la marca de dictado,
# y este banco no la crea nunca. Se queda en su bucle ocioso, que es justo el que hay que probar.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-huerf-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$marca  = Join-Path $tmp 'dictar.flag'
$salida = Join-Path $tmp 'oido.txt'
$logW   = Join-Path $tmp 'worker.log'
$pyExe = 'pythonw.exe'
try { $null = Get-Command pythonw.exe -ErrorAction Stop } catch { $pyExe = 'python.exe' }

function Arrancar-Worker([int]$pidPadre) {
    $antes = $env:NOVA_PID_PADRE
    if ($pidPadre -gt 0) { $env:NOVA_PID_PADRE = "$pidPadre" } else { Remove-Item Env:NOVA_PID_PADRE -ErrorAction SilentlyContinue }
    try {
        $p = Start-Process -FilePath $pyExe -ArgumentList @('-u', $RutaVoz, $marca, $salida, $logW, 'es-ES') `
             -WorkingDirectory $Raiz -WindowStyle Hidden -PassThru
        # EL HANDLE, IGUAL QUE EL ASISTENTE. Sin cogerlo aqui, .HasExited lanza en vez de
        # contestar, y el catch de Sigue-Vivo lo convertia en "muerto": la primera version de
        # este banco daba por muerto un worker que estaba perfectamente vivo. assistant.ps1
        # coge el Handle en las cuatro veces que arranca algo, y es por esto.
        $null = $p.Handle
        return $p
    } finally { if ($antes) { $env:NOVA_PID_PADRE = $antes } else { Remove-Item Env:NOVA_PID_PADRE -ErrorAction SilentlyContinue } }
}
function Sigue-Vivo($p) {
    if (-not $p) { return $false }
    # NO SE TRAGA EL ERROR: si .HasExited fallara, se pregunta al sistema. Un catch que
    # devuelva $false a secas hace que el banco diga "se murio solo" cuando en realidad no
    # ha podido mirarlo, que es salir verde mintiendo.
    try { return (-not $p.HasExited) }
    catch { return [bool](Get-Process -Id $p.Id -ErrorAction SilentlyContinue) }
}
function Esperar-Muerte($p, [int]$segundos) {
    $t = [Diagnostics.Stopwatch]::StartNew()
    while ($t.Elapsed.TotalSeconds -lt $segundos) {
        if (-not (Sigue-Vivo $p)) { return [Math]::Round($t.Elapsed.TotalSeconds, 1) }
        Start-Sleep -Milliseconds 200
    }
    return -1
}

try {
    # el padre de mentira: un powershell que duerme y no hace nada mas
    $padre = Start-Process -FilePath 'powershell.exe' `
             -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 120') `
             -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 300
    Comp 'el padre de mentira arranco' (Sigue-Vivo $padre) "PID $($padre.Id)"

    $hijo = Arrancar-Worker $padre.Id
    # EL MOTOR DE WINDOWS TARDA EN ABRIR: en esta maquina el registro dice "motor de Windows
    # listo" en menos de 3 s, pero se le dan 12 por si el sistema esta cargado con un juego.
    $t = [Diagnostics.Stopwatch]::StartNew()
    while ($t.Elapsed.TotalSeconds -lt 12 -and -not (Test-Path -LiteralPath $logW)) { Start-Sleep -Milliseconds 200 }
    Start-Sleep -Milliseconds 800
    $arranco = Sigue-Vivo $hijo
    Comp 'el worker arranco y se queda esperando' $arranco "PID $(if($hijo){$hijo.Id}else{'-'})"
    if (-not $arranco) {
        Comp 'NO SE PUEDE PROBAR NADA MAS' $false 'el worker no llego a vivir; mira worker.log'
        if (Test-Path -LiteralPath $logW) { Get-Content -LiteralPath $logW -Tail 4 | ForEach-Object { Write-Host "       $_" } }
    } else {
        # con el padre vivo, el hijo NO se muere: esto es lo que evita que se suicide en marcha
        Start-Sleep -Seconds 4
        Comp 'con el padre vivo sigue vivo a los 4 s' (Sigue-Vivo $hijo) 'no se suicida en mitad de una partida'

        # y ahora lo que importa
        $padre.Kill()
        $seg = Esperar-Muerte $hijo 20
        Comp 'al morir el padre, el worker se cierra SOLO' ($seg -ge 0) $(if ($seg -ge 0) { "tardo $seg s" } else { 'sigue vivo a los 20 s: ESTE es el fallo de los 44' })
        if ($seg -ge 0) { Comp 'y tarda menos de 10 s en enterarse' ($seg -lt 10) "$seg s" }
        if (Sigue-Vivo $hijo) { try { $hijo.Kill() } catch {} }
    }

    Write-Host ''
    Write-Host '-- 4. y sin NOVA_PID_PADRE se comporta como siempre --'
    # COMPATIBILIDAD: si alguien arranca el worker a mano, sin decirle de quien es hijo, tiene
    # que seguir funcionando igual que antes. Un worker que se suicidara por no saberlo seria
    # peor que el fallo que arreglamos.
    $suelto = Arrancar-Worker 0
    Start-Sleep -Seconds 6
    Comp 'un worker sin padre declarado sigue vivo' (Sigue-Vivo $suelto) 'ante la duda, vivo'
    if (Sigue-Vivo $suelto) { try { $suelto.Kill() } catch {} }
} finally {
    Get-Process -Name 'python', 'pythonw' -ErrorAction SilentlyContinue | Where-Object {
        try { $_.StartTime -gt (Get-Date).AddMinutes(-3) } catch { $false }
    } | ForEach-Object {
        $cl = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cl -and $cl -match [regex]::Escape($tmp)) { try { $_.Kill() } catch {} }
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  los workers ya no sobreviven a Nova'
exit 0
