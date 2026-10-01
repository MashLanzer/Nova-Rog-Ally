# SUBTITULOS DEL AUDIO DEL JUEGO (1/10, la 17 de las 20 funciones nuevas)
#
# Es la unica de las veinte que gasta UN NUCLEO ENTERO mientras trabaja, y por eso este banco
# no va de que los subtitulos salgan: va de que se CALLEN. Lo que defiende:
#
#  1. que no se arranque si la consola ya va ahogada -subtitular con el juego al 90 % es
#     estropear la partida que se queria entender-;
#  2. que se corte SOLA: por plazo, al cerrarse el juego y cuando se lo pidan (regla 2);
#  3. que el pedido al worker salga en BYTES UTF-8 y sin preambulo. Esto no es teoria: el
#     1/10, con StandardInput.WriteLine, PowerShell colaba su BOM delante del primer "{", el
#     worker no podia leer el JSON y "que ha dicho" NO CONTESTABA NUNCA, en silencio;
#  4. que el subtitulo vaya a la capsula como 'atenta' y NO por voz: repetir en alto lo que el
#     juego acaba de decir, encima del juego, es absurdo;
#  5. que "que ha dicho" no resuelva sin subtitulos puestos, y que una notificacion reciente le
#     gane -leer un mensaje privado en voz alta por un falso positivo es el peor fallo posible-;
#  6. y que el worker en Python siga teniendo UN hilo y su puerta de silencio, que son las dos
#     decisiones que salieron de medir y las dos que un descuido deshace sin que se note.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$RutaPy = Join-Path $Raiz 'subtitulos.py'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}

# --- las constantes medidas, con los mismos valores que el fichero ---
$SubtitulosModelo = 'tiny'
$SubtitulosTrozoSeg = 6
$SubtitulosMaxMin = 20
$SubtitulosCpuMax = 88
$LogDir = $Raiz
$PyExe = (Get-Command powershell).Source   # algo que EXISTE, para que Get-Estorbo no se queje de Python
$PyWorker = $PyExe

foreach ($n in @('Get-EstorboSubtitulos', 'Start-Subtitulos', 'Stop-Subtitulos', 'Send-SubPedido',
                 'Receive-Subtitulos', 'Request-UltimoSubtitulo', 'Get-FraseSubtitulos', 'Get-NombreIdioma')) {
    Invoke-Expression (Traer $n)
}
# el mapa de idiomas vive al lado de Get-NombreIdioma y hay que traerlo a mano
$IDIOMAS_SUB = @{ 'en' = 'ingles'; 'es' = 'espanol'; 'ja' = 'japones' }

# --- los dobles, DESPUES de cargar las funciones de verdad ---
$script:dicho = @()
function Say([string]$m) { $script:dicho += $m }
function Log([string]$m) { }
$script:ui = @()
function Set-UI([string]$estado, [string]$texto = '', [int]$ms = 0) { $script:ui += @{ estado = $estado; texto = $texto; ms = $ms } }
$script:mandado = @()
function Submit-Command([string]$t, [string]$o) { $script:mandado += $t }
# LA SONDA DE CPU, DOBLADA: asi el banco decide el numero y no lo decide la maquina donde corre.
# Sin esto, esta seccion saldria verde o roja segun lo que estuviera haciendo la consola, que es
# justo la manera 7 de los bancos que mienten (el color lo pone el entorno, no el codigo).
$script:cpuPega = 30
function Get-CargaCPU { return $script:cpuPega }
$script:reloj = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }

# UN PROCESO DE PEGA QUE NO ES UN PROCESO: asi el banco no arranca Python de verdad ni abre la
# grabadora del altavoz de braya, y a la vez se ejecutan las funciones DE VERDAD.
function Nuevo-ProcPega([string[]]$lineas) {
    $ms = New-Object System.IO.MemoryStream
    $sw2 = New-Object System.IO.StreamWriter($ms)
    $cola = New-Object System.Collections.Queue
    foreach ($l in $lineas) { [void]$cola.Enqueue($l) }
    $p = [pscustomobject]@{
        HasExited = $false
        Id = 4242
        StandardInput = [pscustomobject]@{ BaseStream = $ms }
        StandardOutput = [pscustomobject]@{ Cola = $cola }
        Escrito = $ms
        Matado = $false
    }
    $p.StandardOutput | Add-Member -MemberType ScriptMethod -Name ReadLineAsync -Value {
        $q = $this.Cola
        $tarea = [pscustomobject]@{ IsCompleted = ($q.Count -gt 0); Result = $null }
        if ($q.Count -gt 0) { $tarea.Result = [string]$q.Dequeue() }
        return $tarea
    }
    $p | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms2) $this.HasExited = $true; return $true }
    $p | Add-Member -MemberType ScriptMethod -Name Kill -Value { $this.Matado = $true }
    $p | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
    return $p
}

function Reset {
    $script:dicho = @(); $script:ui = @(); $script:mandado = @()
    $script:subProc = $null; $script:subLectura = $null
    $script:subDesde = 0; $script:subIdioma = ''; $script:subUltimo = ''
    $script:subPideUltimo = $false; $script:subPideEn = 0; $script:subMsPeor = 0
    $script:juegoActivo = 'Elden Ring De Pega'
    $script:uiCarga = 30
    $script:cpuPega = 30
    $script:respuestaSinTarjeta = $false
    $script:reloj = 0
}

Write-Host ''
Write-Host '-- 1. NO se arranca si la consola ya va ahogada --'
# Es la decision que sale de medir: subtitular cuesta 99 % de un nucleo mientras transcribe.
Reset
$script:cpuPega = 95
$r = Start-Subtitulos
Comp 'con la CPU al 95 no se pone' ($null -eq $script:subProc) 'un nucleo mas ahi es estropear la partida'
Comp '  y lo dice con el numero delante' ($r -match '95' -and $r -match 'nucleo') "$r"
Reset
$script:cpuPega = $SubtitulosCpuMax
Comp "y justo en el liston ($SubtitulosCpuMax) tampoco" ($null -eq $script:subProc) ''
Write-Host ''
Write-Host '-- 2. ni si falta la pieza que oye el juego --'
Reset
$guardaLog = $LogDir
$LogDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-nada-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
$r2 = Start-Subtitulos
Comp 'sin subtitulos.py no se promete nada' ($null -eq $script:subProc -and $r2 -match 'No puedo subtitular') "$r2"
$LogDir = $guardaLog
Comp '  y con el fichero puesto, el estorbo desaparece' ((Get-EstorboSubtitulos) -eq '') "$(Get-EstorboSubtitulos)"

Write-Host ''
Write-Host '-- 3. EL PEDIDO SALE EN BYTES UTF-8, SIN PREAMBULO --'
# ESTO NO ES TEORIA. El 1/10, con StandardInput.WriteLine, PowerShell metia su BOM delante del
# primer "{", json.loads fallaba en el worker y el pedido se perdia EN SILENCIO: "que ha dicho"
# no contestaba nunca y no habia ni una linea de error en ningun sitio.
Reset
$script:subProc = Nuevo-ProcPega @()
Comp 'el pedido se manda' (Send-SubPedido '{"op":"ultimo"}') ''
$bytes = $script:subProc.Escrito.ToArray()
Comp '  y el primer byte es "{", no un BOM' ($bytes.Count -gt 0 -and $bytes[0] -eq 0x7B) ("primero: 0x{0:X2}" -f $(if ($bytes.Count) { $bytes[0] } else { 0 }))
Comp '  y acaba en salto de linea, que es lo que el worker espera' ($bytes[$bytes.Count - 1] -eq 0x0A) ''
Comp '  y no lleva BOM en ningun sitio' (-not ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) ''
# Y NO SE ESCRIBE AL WORKER QUE YA MURIO: eso es una excepcion por una tuberia cerrada.
$script:subProc.HasExited = $true
Comp 'al worker muerto no se le escribe' (-not (Send-SubPedido '{"op":"ultimo"}')) ''

Write-Host ''
Write-Host '-- 4. el subtitulo se LEE, no se oye --'
Reset
$script:subProc = Nuevo-ProcPega @('{"ev":"listo"}', '{"ev":"idioma","idioma":"en","conf":0.93}', '{"ev":"sub","texto":"Take the east road","idioma":"en","ms":1800}')
Receive-Subtitulos
Comp 'el subtitulo llega a la capsula' (@($script:ui | Where-Object { $_.texto -eq 'Take the east road' }).Count -eq 1) "$($script:ui.Count) pintadas"
# 'atenta' Y NO 'hablando': con 'hablando' la capsula se pinta del azul de "estoy contestando"
# y el subtitulo pareceria suyo.
$pintada = @($script:ui | Where-Object { $_.texto -eq 'Take the east road' })[0]
Comp "  como 'atenta', no como 'hablando'" ($pintada.estado -eq 'atenta') "$($pintada.estado)"
Comp '  y dura mas de un trozo, para no parpadear' ($pintada.ms -gt (($SubtitulosTrozoSeg - 1) * 1000)) "$($pintada.ms) ms"
Comp '  y NO se dice en voz alta' ($script:dicho.Count -eq 0) "dijo: $($script:dicho -join ' | ')"
Comp '  y se queda con el idioma del juego' ($script:subIdioma -eq 'en') "$($script:subIdioma)"
Comp '  y apunta lo que tardo, para poder decirlo' ($script:subMsPeor -eq 1800) "$($script:subMsPeor)"

Write-Host ''
Write-Host '-- 5. SE CORTA SOLA: las tres salidas (regla 2) --'
# a) el plazo
Reset
$script:subProc = Nuevo-ProcPega @()
$script:subDesde = 0
$script:reloj = ($SubtitulosMaxMin * 60000) + 1
Receive-Subtitulos
Comp "a los $SubtitulosMaxMin minutos se quita sola" ($null -eq $script:subProc) ''
Comp '  y avisa de que se ha quitado' (@($script:dicho | Where-Object { $_ -match 'Quito los subtitulos' }).Count -eq 1) "$($script:dicho -join ' | ')"
# Y UN MINUTO ANTES NO: si no, el plazo no seria un plazo
Reset
$script:subProc = Nuevo-ProcPega @()
$script:reloj = ($SubtitulosMaxMin - 1) * 60000
Receive-Subtitulos
Comp '  y un minuto antes sigue puesta' ($null -ne $script:subProc) ''
# b) se cierra el juego
Reset
$script:subProc = Nuevo-ProcPega @()
$script:juegoActivo = ''
$script:reloj = 40000
Receive-Subtitulos
Comp 'sin juego delante se quita' ($null -eq $script:subProc) 'subtitular el escritorio es gastar un nucleo en el silencio'
Comp '  y de eso NO habla: nadie lo ha preguntado' ($script:dicho.Count -eq 0) "$($script:dicho -join ' | ')"
# ...pero no en los primeros segundos, que es cuando el juego aun no se ha puesto delante
Reset
$script:subProc = Nuevo-ProcPega @()
$script:juegoActivo = ''
$script:reloj = 5000
Receive-Subtitulos
Comp '  pero no en los primeros segundos' ($null -ne $script:subProc) 'el juego tarda en ponerse delante'
# c) se lo pide braya
Reset
$script:subProc = Nuevo-ProcPega @()
$p = $script:subProc
Comp 'se quita cuando se lo pides' ((Stop-Subtitulos 'me lo has pedido') -and $null -eq $script:subProc) ''
$esc = [System.Text.Encoding]::UTF8.GetString($p.Escrito.ToArray())
Comp '  y se le pide al worker que se vaya, no se le mata' ($esc -match '"op":"fin"' -and -not $p.Matado) "$($esc.Trim())"
Comp 'y quitar lo que no estaba puesto no se inventa nada' (-not (Stop-Subtitulos)) ''

Write-Host ''
Write-Host '-- 6. "que ha dicho": la mitad que SI va en espanol --'
Reset
Comp 'sin subtitulos puestos, lo dice y no promete' ((Request-UltimoSubtitulo) -match 'No estoy oyendo el juego') ''
Reset
$script:subProc = Nuevo-ProcPega @('{"ev":"ultimo","texto":"The bridge is out"}')
Comp 'con subtitulos puestos, pide y calla' ((Request-UltimoSubtitulo) -eq '') 'la respuesta llega luego'
Comp '  y queda apuntado que esta esperando' ($script:subPideUltimo) ''
Comp '  y pedirlo dos veces no manda dos' ((Request-UltimoSubtitulo) -match 'Ya voy') ''
Receive-Subtitulos
Comp '  y al llegar, se manda a traducir' (@($script:mandado | Where-Object { $_ -match 'Traduce al espanol' -and $_ -match 'The bridge is out' }).Count -eq 1) "$($script:mandado -join ' | ')"
Comp '  y deja de estar esperando' (-not $script:subPideUltimo) ''
# SI NO HABIA NADA, SE DICE: contestar con una traduccion del vacio seria inventar.
Reset
$script:subProc = Nuevo-ProcPega @('{"ev":"ultimo","texto":""}')
[void](Request-UltimoSubtitulo)
Receive-Subtitulos
Comp 'si no oyo nada, lo dice y no traduce el vacio' ($script:mandado.Count -eq 0 -and @($script:dicho | Where-Object { $_ -match 'No he oido nada' }).Count -eq 1) "$($script:dicho -join ' | ')"
# Y NO SE QUEDA ESPERANDO PARA SIEMPRE (regla 2): el worker contesta en menos de un trozo.
Reset
$script:subProc = Nuevo-ProcPega @()
[void](Request-UltimoSubtitulo)
$script:reloj = 16000
Receive-Subtitulos
Comp 'y la espera caduca a los 15 s' (-not $script:subPideUltimo) ''
Comp '  diciendolo, no callandose' (@($script:dicho | Where-Object { $_ -match 'No he conseguido recuperar' }).Count -eq 1) "$($script:dicho -join ' | ')"

Write-Host ''
Write-Host '-- 7. el parte, y el idioma en cristiano --'
Reset
Comp 'apagada, lo dice y dice como ponerla' ((Get-FraseSubtitulos) -match 'No estoy subtitulando' -and (Get-FraseSubtitulos) -match 'subtitula') "$(Get-FraseSubtitulos)"
Reset
$script:subProc = Nuevo-ProcPega @()
$script:subIdioma = 'ja'
$script:subMsPeor = 2400
$script:reloj = 3 * 60000
$fr = Get-FraseSubtitulos
Comp 'puesta, dice cuanto lleva' ($fr -match '3 minutos') "$fr"
Comp '  y el idioma con su nombre, no el codigo' ($fr -match 'japones' -and $fr -notmatch '\bja\b') ''
Comp '  y lo que mas tardo un subtitulo' ($fr -match '2[.,]4 segundos') ''
Comp "  y cuanto le queda del plazo" ($fr -match "$($SubtitulosMaxMin - 3) minutos") ''
# UN MINUTO NO ES "1 minutos", y medio minuto no es "0 minutos"
Reset
$script:subProc = Nuevo-ProcPega @()
$script:reloj = 30000
Comp 'medio minuto se dice "menos de un minuto"' ((Get-FraseSubtitulos) -match 'menos de un minuto') "$(Get-FraseSubtitulos)"
$script:reloj = 70000
Comp 'y uno se dice "un minuto"' ((Get-FraseSubtitulos) -match 'Llevo un minuto') "$(Get-FraseSubtitulos)"
Comp 'un idioma que no conozco no se inventa' ((Get-NombreIdioma 'xx') -eq 'otro idioma') "$(Get-NombreIdioma 'xx')"

Write-Host ''
Write-Host '-- 8. el cableado y los patrones --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'el bucle lee lo que va diciendo el worker' ($sinCom -match 'Receive-Subtitulos') ''
Comp "hay un patron que los pone" ($sinCom -match "kind = 'subtitulos'; que = 'pon'") ''
Comp '  y otro que los quita' ($sinCom -match "kind = 'subtitulos'; que = 'quita'") ''
# LA GUARDA VA EN LA MISMA CONDICION, igual que el "que dice" de las notificaciones: se mira
# que en las lineas de ANTES del return este el $script:subProc, o sea que la condicion que
# resuelve ya lo exige. Se mide con la ventana justo delante, no con un regex de medio fichero:
# ese es el que se vuelve verde con cualquier cosa (la manera 1 de los bancos que mienten).
$iUlt = $sinCom.IndexOf("que = 'ultimo'; desc = 'traducir")
Comp '  y el "que ha dicho" existe como patron' ($iUlt -gt 0) "$iUlt"
if ($iUlt -gt 0) {
    $antes = $sinCom.Substring([Math]::Max(0, $iUlt - 400), [Math]::Min(400, $iUlt))
    Comp '  y lleva su guarda EN LA MISMA CONDICION' ($antes -match 'subProc') 'sin subtitulos puestos no debe resolver'
}
# Y LA NOTIFICACION GANA: leer un mensaje privado en voz alta por un falso positivo es el peor
# fallo posible, asi que el "que dice" de las notificaciones va ANTES.
$iNotif = $sinCom.IndexOf("kind = 'notifQueDice'")
Comp '  y la notificacion reciente le gana' ($iNotif -gt 0 -and $iUlt -gt $iNotif) "notif en $iNotif, subtitulo en $iUlt"
# NO SE ESCRIBE CON WriteLine: es el fallo del 1/10 y volveria a perder los pedidos en silencio.
$cuerpos = (Traer 'Send-SubPedido') + (Traer 'Stop-Subtitulos') + (Traer 'Request-UltimoSubtitulo')
Comp '  y nadie escribe al worker con WriteLine' ($cuerpos -notmatch 'StandardInput\.WriteLine') 'PowerShell le cuela un BOM al primero'

Write-Host ''
Write-Host '-- 9. el worker en Python: las dos decisiones que salieron de medir --'
$fuentePy = [IO.File]::ReadAllText($RutaPy)
# UN HILO, Y ESTA MEDIDO: con 4 va igual que con 2 y gasta el doble. Si alguien lo sube "para
# que vaya mas rapido", no va mas rapido: solo le quita nucleos al juego.
Comp 'el worker usa UN hilo' ($fuentePy -match 'cpu_threads=1') 'con 4 va igual que con 2 y gasta el doble'
Comp '  y el modelo pequenio' ($fuentePy -match 'MODELO = sys\.argv\[1\].*"tiny"') ''
Comp '  y tiene puerta de silencio antes de Whisper' ($fuentePy -match 'np\.abs\(trozo\)\.max\(\)\) < PICO_MIN') 'si no, transcribe el silencio y se lo inventa'
# LA PUERTA VA ANTES DEL transcribe, no despues: despues no ahorra nada.
$iPuerta = $fuentePy.IndexOf('np.abs(trozo).max()) < PICO_MIN')
$iTrans = $fuentePy.IndexOf('modelo.transcribe(')
Comp '  y la puerta va ANTES de transcribir' ($iPuerta -gt 0 -and $iTrans -gt $iPuerta) ''
Comp '  y el idioma se fija solo si se oyo algo' ($fuentePy -match 'if texto:[\s\S]{0,120}idioma = str\(inf\.language\)') 'sobre silencio da "es al 44 %"'
Comp '  y muere solo si se cierra la tuberia' ($fuentePy -match '_fin\.set\(\)' -and $fuentePy -match 'for linea in sys\.stdin') 'regla 5: ni un Whisper huerfano'
# Y EL CINTURON DE ENCIMA: que mire si Nova sigue viva, como el oido y la voz. Aqui pesa mas que
# en ninguno, porque lo que quedaria suelto es un Whisper comiendose un nucleo entero.
Comp '  y tambien mira si Nova sigue viva' ($fuentePy -match 'NOVA_PID_PADRE' -and $fuentePy -match 'if not padre_vivo\(\)') ''
Comp '    y ante la duda lo da por vivo' ($fuentePy -match 'except Exception:[\s\S]{0,60}return True') 'apagarse a media escena es peor'
$blqArr = Traer 'Start-Subtitulos'
# EL PATRON VA EN COMILLAS SIMPLES: entre dobles, PowerShell expande $PID al PID de este banco y
# el regex pasa a buscar un numero que no esta escrito en ninguna parte.
Comp '    y el arranque le dice de quien es hijo' ($blqArr -match "NOVA_PID_PADRE', \[string\]\`$PID") 'sin esto el hijo no sabe a quien mirar'
Comp '  y escribe solo ASCII' ($fuentePy -match 'ensure_ascii=True') 'PowerShell romperia los acentos'
# Y SE EJECUTA DE VERDAD: que el solape no salga dos veces.
# OJO AL NOMBRE: esto NO puede llamarse $pyExe. En PowerShell los nombres de variable no
# distinguen mayusculas, asi que $pyExe y el $PyExe que Get-EstorboSubtitulos necesita de mas
# arriba son LA MISMA VARIABLE, y el banco acababa intentando correr el .py con powershell.exe.
# El error que salia era "Traceback (most recent call last):" y nada mas. Mismo tropiezo que
# $PY contra $py, que ya esta apuntado.
$interpretePy = $env:NOVA_PY
if (-not $interpretePy) { $interpretePy = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe' }
if (Test-Path -LiteralPath $interpretePy) {
    $prueba = @'
import sys, importlib.util
spec = importlib.util.spec_from_file_location("sub", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m._comun("you have to reach the top", "the top of the tower"))
print(m._comun("nada que ver", "otra cosa"))
print(int(m.PICO_MIN > 0), int(m.SOLAPE > 0 and m.SOLAPE < m.TROZO))
'@
    $tmpP = Join-Path ([IO.Path]::GetTempPath()) ('nova-sub-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.py')
    [IO.File]::WriteAllText($tmpP, $prueba)
    # EL stderr VA A UN FICHERO, NO AL 2>&1. Con $ErrorActionPreference='Stop', un '2>&1' sobre un
    # programa de fuera convierte CADA linea de su stderr en un ErrorRecord y la PRIMERA lanza: el
    # banco moria con "Traceback (most recent call last):" y nada mas, o sea con el aviso y sin el
    # motivo. Asi se ve el error entero, que es de lo que sirve un banco.
    $errP = $tmpP + '.err'
    try {
        $sal = @(& $interpretePy $tmpP $RutaPy 2>$errP)
        $errTxt = ''
        if (Test-Path -LiteralPath $errP) { $errTxt = ([IO.File]::ReadAllText($errP)).Trim() }
        if ($errTxt) { Comp 'el trozo de Python corre sin quejarse' $false $errTxt.Replace("`r", ' ').Replace("`n", ' | ') }
        Comp 'el solape compartido se recorta' ([string]$sal[0] -eq '7') "devolvio '$($sal[0])' (de 'the top')"
        Comp '  y lo que no se solapa no se toca' ([string]$sal[1] -eq '0') "$($sal[1])"
        Comp '  y el solape cabe dentro del trozo' ([string]$sal[2] -eq '1 1') "$($sal[2])"
    } finally {
        Remove-Item -LiteralPath $tmpP -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $errP -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host '  --   sin Python aqui: el trozo ejecutable del worker se salta' -ForegroundColor DarkGray
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova subtitula el juego cuando se lo pides, y se calla sola' -ForegroundColor Green
exit 0
