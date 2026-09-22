# HAS VUELTO A LA CONSOLA (18/09): que te salude al volver, y sobre todo QUE SEPA CALLARSE.
#
# Lo que pidio braya: "cuando nova este encendida, y pasa un tiempo sola, al tomar la consola
# en mis manos lo detecte y me salude de alguna forma, no siempre igual porque se vuelve
# repetitivo". Lo dificil no es saludar: es no saludar a destiempo. De los 55 huecos de 20
# minutos o mas del registro, 30 tienen un arranque de Nova dentro, y en esos ya saludo al
# arrancar (142 veces en 9 dias).
#
# LA HORA VA POR PARAMETRO, no del reloj del sistema. probar-entorno.ps1 tuvo que mover la
# franja de noche lejos de la hora actual porque pasar el banco de madrugada bloqueaba 12
# casos sin que nada estuviera roto; aqui Test-VueltaSaludo recibe la hora, asi que la franja
# puede ser la de verdad (23-8) y el banco da lo mismo a las 3 de la tarde que a las 3 de la
# madrugada.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}

# el cronometro del proceso, de mentira: ni Test-VueltaSaludo ni Set-PresenciaAhora lo
# aceptan por parametro, y hace falta poder decir "Nova lleva 5 horas encendida"
$script:relojMs = 18000000
$sw = New-Object psobject
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojMs }

# la configuracion, con los valores por defecto del archivo real
$EntornoOn = $true
$VueltaOn = $true
$VueltaMin = 45
$VueltaVozMin = 180
$EntornoNocheDesde = 23
$EntornoNocheHasta = 8
$AvisosSinVoz = $true
$AvisosSinVozEnJuego = $true

$script:invitado = $false
$script:entornoCallado = $false
$script:armed = $false
$script:busy = $false
$script:pendiente = $null
$script:juegoActivo = $null
$script:sordinaHasta = 0
$script:uiPerfil = ''
$script:juegoRef = $null
$script:presenciaVistoEn = 0
$script:presenciaGuardada = 0
$script:avisosAplazados = New-Object System.Collections.ArrayList
$script:logLineas = @()
$script:notifPendientes = New-Object System.Collections.ArrayList
$script:ultimoHabloEn = 0
$script:resumenPendiente = ''
$script:resumenFirma = ''
$script:dicho = @()
$script:popup = @()
$script:eventos = @()
$script:guardados = 0

function Log($m) { $script:logLineas += $m }
function Say($t) { $script:dicho += $t }
function Show-Popup($t, $estadoUI = 'hablando') { $script:popup += $t }
function Send-UIEvento($e) { $script:eventos += $e }
function Test-EnLlamada { return $false }
function Get-JuegoDeReferencia { return $script:juegoRef }
$script:hb = @{ presencia = @{} }
function Get-Habitos { return $script:hb }
function Save-Habitos { $script:guardados++ }

# las de verdad, sacadas del archivo real
Invoke-Expression (Traer 'Test-AvisoSinVoz')
Invoke-Expression (Traer 'Send-Aviso')
Invoke-Expression (Traer 'Set-PresenciaAhora')
Invoke-Expression (Traer 'Get-AusenciaMin')
Invoke-Expression (Traer 'Get-FraseVuelta')
Invoke-Expression (Traer 'Test-VueltaSaludo')
Invoke-Expression (Traer 'Set-HabloAhora')
Invoke-Expression (Traer 'Test-ResumenAlVolver')

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Reset {
    $script:hb = @{ presencia = @{} }
    $script:dicho = @(); $script:popup = @(); $script:eventos = @()
    $script:invitado = $false; $script:entornoCallado = $false
    $script:armed = $false; $script:busy = $false; $script:pendiente = $null
    $script:juegoActivo = $null; $script:juegoRef = $null
    $script:sordinaHasta = 0; $script:uiPerfil = ''
    $script:presenciaVistoEn = 0; $script:presenciaGuardada = 0
    $script:guardados = 0
    $script:avisosAplazados = New-Object System.Collections.ArrayList
    $script:relojMs = 18000000        # 5 h encendida: Nova lleva viva todo el hueco
    $script:logLineas = @()
    $script:notifPendientes = New-Object System.Collections.ArrayList
    $script:ultimoHabloEn = 0
    $script:resumenPendiente = ''
    $script:resumenFirma = ''
}
function Visto([datetime]$t) { $script:hb.presencia['visto'] = $t.ToString('yyyy-MM-dd HH:mm:ss') }

$T = [datetime]'2026-09-18 19:00:00'      # una tarde cualquiera, fuera de la franja de noche

Write-Host '  -- vuelves tras un rato --'
Reset
Visto $T.AddMinutes(-45)
$r1 = Test-VueltaSaludo $T
Comp 'a los 45 minutos fuera, saluda' $r1
Comp 'pero solo se ve: nada de voz' ($script:dicho.Count -eq 0 -and $script:popup.Count -eq 1) ($script:popup -join '')
Comp 'con su pulso en la capsula' ($script:eventos -contains 'pulso:saludo')

Write-Host '  -- pero un rato corto no es volver --'
Reset
Visto $T.AddMinutes(-20)
Comp 'a los 20 minutos, ni se inmuta' (-not (Test-VueltaSaludo $T))
Comp 'y no ensucia la capsula' ($script:popup.Count -eq 0)

Write-Host '  -- tras horas fuera si merece la voz --'
Reset
Visto $T.AddHours(-4)
$r3 = Test-VueltaSaludo $T
Comp 'tras 4 horas, saluda en voz alta' ($r3 -and $script:dicho.Count -eq 1) ($script:dicho -join '')
Comp 'y con el gesto de saludar' ($script:eventos -contains 'gesto:saludo')

Write-Host '  -- lo que NO puede pasar: saludar dos veces --'
# de los 55 huecos de 20 min o mas del registro, 30 tienen un arranque dentro: sin esta
# guarda, Nova diria hola al arrancar y otra vez dos segundos despues
Reset
Visto $T.AddHours(-4)
$script:relojMs = 600000
Comp 'si Nova arranco dentro del hueco, no saluda otra vez' (-not (Test-VueltaSaludo $T))
Reset
Visto $T.AddHours(-4)
$script:relojMs = 30000
Comp 'ni a los 30 s de arrancar' (-not (Test-VueltaSaludo $T))

Write-Host '  -- con un juego delante, ni voz ni ruido --'
# el gesto 'saludo' de la capsula llama a Sonar(sonSuave): mandarlo y confiar en que la voz
# se calle dejaria un ruido sin que nadie hable, que es peor que el saludo entero
Reset
Visto $T.AddHours(-4)
$script:juegoActivo = 'It Takes Two'
$r6 = Test-VueltaSaludo $T
Comp 'jugando, saluda pero se calla' ($r6 -and $script:dicho.Count -eq 0) ($script:dicho -join '')
Comp 'y sin gesto ni pulso, que suenan' ($script:eventos.Count -eq 0) ($script:eventos -join ',')
Comp 'aunque en la capsula se lee' ($script:popup.Count -eq 1)

Write-Host '  -- a las dos de la madrugada, en silencio --'
Reset
$N = [datetime]'2026-09-18 02:00:00'
Visto $N.AddHours(-4)
$r7 = Test-VueltaSaludo $N
Comp 'de madrugada saluda sin voz' ($r7 -and $script:dicho.Count -eq 0)
Comp 'y sin gesto ni pulso' ($script:eventos.Count -eq 0) ($script:eventos -join ',')
Comp 'con la frase que toca a esas horas' ($script:popup.Count -eq 1 -and $script:popup[0] -match 'tarde') ($script:popup -join '')

Write-Host '  -- mientras dictas, espera --'
Reset
Visto $T.AddHours(-4)
$script:armed = $true
Comp 'con el dictado abierto no saluda' (-not (Test-VueltaSaludo $T))
Comp 'y no se apunta como saludado' (-not $script:hb.presencia['saludo'])
$script:armed = $false
Comp 'al bajar el dictado, si' (Test-VueltaSaludo $T)

Write-Host '  -- y NO dos veces en la misma hora --'
Reset
Visto $T.AddHours(-4)
Comp 'el primero sale' (Test-VueltaSaludo $T)
Comp 'media hora despues, no' (-not (Test-VueltaSaludo $T.AddMinutes(30)))
Comp 'pero a las dos horas, si' (Test-VueltaSaludo $T.AddHours(2))

Write-Host '  -- nunca la misma frase (que es lo que se vuelve repetitivo) --'
# el relleno de la charla filtra solo la ULTIMA dicha y la guarda en memoria de proceso; con
# 187 arranques en 9 dias eso se olvida constantemente. Aqui son las tres ultimas y en disco.
Reset
$dichas = @()
foreach ($i in 1..12) {
    $script:hb.presencia['saludo'] = ''       # el freno de la hora se prueba arriba
    Visto $T.AddHours(-4)
    $script:presenciaVistoEn = 0              # como si Nova se hubiera reiniciado entre medias
    $script:popup = @(); $script:dicho = @()
    [void](Test-VueltaSaludo $T)
    if ($script:popup.Count -gt 0) { $dichas += $script:popup[0] } else { $dichas += '(no saludo)' }
}
$repes = 0
for ($i = 3; $i -lt $dichas.Count; $i++) {
    if ($dichas[($i - 3)..($i - 1)] -contains $dichas[$i]) { $repes++ }
}
Comp 'doce saludos sin repetir ninguno de los tres anteriores' ($repes -eq 0) "repetidas=$repes"
Comp 'y la memoria de frases sobrevive fuera del proceso' (@($script:hb.presencia['frases']).Count -eq 3)

Write-Host '  -- la presencia no machaca el disco --'
# esto lo llama cada pulsacion del mando y el bucle va a 30 ms; Save-Habitos reescribe el
# fichero entero (1,33 ms medidos). Sin freno serian cientos de escrituras por partida.
Reset
Set-PresenciaAhora $T
Comp 'la primera señal se guarda' ($script:guardados -eq 1)
foreach ($i in 1..50) { $script:relojMs += 30; [void](Set-PresenciaAhora $T) }
Comp 'pero 50 pulsaciones seguidas no escriben 50 veces' ($script:guardados -eq 1) "escrituras=$($script:guardados)"
$script:relojMs += 61000
Set-PresenciaAhora $T
Comp 'pasado un minuto, vuelve a guardarse' ($script:guardados -eq 2)

Write-Host '  -- y con un invitado delante, nada --'
Reset
Visto $T.AddHours(-4)
$script:invitado = $true
Comp 'no saluda a quien no eres tu' (-not (Test-VueltaSaludo $T))

Write-Host '  -- el resumen al volver no se queda repitiendose (22/09) --'
# 1.126 lineas "RESUMEN AL VOLVER" el 21/09, 97 KB, el 25 % de lo que Nova escribio ese
# dia; 774 de ellas la MISMA notificacion repetida cada 30 s durante 6 h 27 min, porque
# Watch-Entorno llama cada 30 s y esto rearmaba siempre. Lo que se prueba: que una ausencia
# larga deje UNA sola linea, que una notificacion nueva si vuelva a armarlo, y que si la
# capsula ya lo mostro estando braya fuera se vuelva a dejar puesto para cuando vuelva.
function Ausencia([int]$vueltas) {
    foreach ($i in 1..$vueltas) { Test-ResumenAlVolver; $script:relojMs += 30000 }
}
Reset
Set-HabloAhora
[void]$script:notifPendientes.Add(@{ id = '1'; app = 'XBOX Game Bar Widgets' })
$script:relojMs += 7200000
Ausencia 774
Comp 'las 774 vueltas de aquel dia dejan UNA sola linea' ($script:logLineas.Count -eq 1) "lineas=$($script:logLineas.Count)"
Comp 'y el aviso queda puesto para cuando vuelva' ($script:resumenPendiente -eq 'Mientras no estabas: 1 mensaje de XBOX Game Bar Widgets') $script:resumenPendiente

Write-Host '  -- pero si se mostro estando el fuera, se vuelve a dejar --'
$script:resumenPendiente = ''
Test-ResumenAlVolver
Comp 'no se pierde: vuelve a armarse una vez' ($script:resumenPendiente -and $script:logLineas.Count -eq 2) "lineas=$($script:logLineas.Count)"
Ausencia 100
Comp 'y esa tampoco se repite en 100 vueltas mas' ($script:logLineas.Count -eq 2) "lineas=$($script:logLineas.Count)"

Write-Host '  -- una notificacion NUEVA si vuelve a contar --'
[void]$script:notifPendientes.Add(@{ id = '2'; app = 'Discord' })
Test-ResumenAlVolver
Comp 'con dos mensajes, se rearma y lo dice' ($script:logLineas.Count -eq 3 -and $script:resumenPendiente -eq 'Mientras no estabas: 2 mensajes') $script:resumenPendiente
Ausencia 100
Comp 'y se vuelve a callar' ($script:logLineas.Count -eq 3) "lineas=$($script:logLineas.Count)"

Write-Host '  -- lo que NO debe cambiar --'
Reset
Set-HabloAhora
[void]$script:notifPendientes.Add(@{ id = '3'; app = 'Discord' })
$script:relojMs += 7000000      # 1 h 57 min
Test-ResumenAlVolver
Comp 'a 1 h 57 min todavia no es ausencia' ($script:resumenPendiente -eq '' -and $script:logLineas.Count -eq 0) $script:resumenPendiente
$script:relojMs += 200000       # ya pasan de 2 h
Test-ResumenAlVolver
Comp 'pasadas las 2 h si sale, como siempre' ($script:resumenPendiente -eq 'Mientras no estabas: 1 mensaje de Discord') $script:resumenPendiente

Reset
Set-HabloAhora
$script:relojMs += 7200000
Ausencia 50
Comp 'sin mensajes no dice nada, por muchas horas que pasen' ($script:resumenPendiente -eq '' -and $script:logLineas.Count -eq 0) "lineas=$($script:logLineas.Count)"

Reset
[void]$script:notifPendientes.Add(@{ id = '4'; app = 'Discord' })
$script:relojMs += 99999999
Test-ResumenAlVolver
Comp 'recien arrancada, sin haberle hablado, no inventa una ausencia' ($script:resumenPendiente -eq '') $script:resumenPendiente

Write-Host '  -- y una ausencia NUEVA vuelve a merecer su linea --'
Reset
Set-HabloAhora
[void]$script:notifPendientes.Add(@{ id = '5'; app = 'Discord' })
$script:relojMs += 7200000
Ausencia 20
$primeras = $script:logLineas.Count
Set-HabloAhora                      # braya vuelve y le habla
$script:resumenPendiente = ''
$script:relojMs += 7200000          # y se va otras 2 h, con los mismos mensajes
Test-ResumenAlVolver
Comp 'otra ausencia con los mismos mensajes si cuenta' ($script:logLineas.Count -eq ($primeras + 1)) "antes=$primeras ahora=$($script:logLineas.Count)"

Write-Host ''
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
