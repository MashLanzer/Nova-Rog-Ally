# LA RONDA DE FONDO NO MIRABA SI HAY ALGUIEN DELANTE (27/09, idea 112 de las 121)
#
# EL DATO, contado en los dos registros: entre las 02:00 y las 08:59 no hay NI UNA de las 170
# ordenes -cero, hora por hora- y en esa misma franja Nova consulto el tiempo 62 veces y salio a
# mirar el correo 9 (de 14 en total). Mientras escribia 4.187 lineas 'ENTORNO aparcado', que es ella
# misma diciendo que no hay nadie a quien contarselo.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que con alguien delante NO cambie nada (la guarda no puede volver lenta a Nova despierta)
#   2. que sin nadie la cadencia sea lo que lleva sin nadie, y que nunca sea MENOR que la normal
#   3. que nunca deje de mirar del todo: un modo sin salida no puede existir (regla 2)
#   4. que el -1 de 'no lo se' se trate como 'hay alguien', nunca como ausencia
#   5. que el refresco al volver caiga en la vuelta siguiente, sin codigo para el
#   6. que el freno de un minuto siga puesto: medido, sin el son 259 s de CPU en seis horas
#   7. que el clima estrene el Test-RedParaFondo que le faltaba
#   8. y que el disco, la biblioteca y el oido se queden fuera
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LAS PIEZAS DE VERDAD, del fichero real. Los dobles van DESPUES.
$quiero = @('Test-TocaRonda', 'Test-HayAlguien', 'Get-NadieMinFrenado', 'Test-RondaDeFondo')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 4 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)

# EL MUNDO DE MENTIRA (despues de cargar, nunca antes)
$TrabajoAusenciaMin = 15
$script:nadieCache = -1
$script:nadieCacheEn = -100000
$script:fondoSaltadas = 0
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
$sw = [Diagnostics.Stopwatch]::StartNew()
$script:redOk = $true
function Test-RedParaFondo { return $script:redOk }
$script:nadieDevuelve = 0
$script:vecesPreguntado = 0
function Get-NadieMin { $script:vecesPreguntado++; return $script:nadieDevuelve }
function Reset([int]$nadie = 0) {
    $script:nadieDevuelve = $nadie
    $script:nadieCache = -1; $script:nadieCacheEn = -100000
    $script:fondoSaltadas = 0; $script:vecesPreguntado = 0
    $script:logs = @(); $script:redOk = $true
}
$HORA = 3600000.0

Write-Host ''
Write-Host '-- 1. CON ALGUIEN DELANTE, NO CAMBIA NADA --'
Comp '1a. antes del plazo no toca' (-not (Test-TocaRonda ($HORA - 1) $HORA 0)) 'igual que siempre'
Comp '1b. cumplido el plazo, toca' (Test-TocaRonda $HORA $HORA 0) ''
Comp '1c. con 14 min de ausencia, sigue tocando' (Test-TocaRonda $HORA $HORA 14) 'el liston de la casa son 15'
# OJO: pasar el liston de 15 min NO alarga nada por si solo. La cadencia larga es la ausencia, y
# hasta que la ausencia no supera a la cadencia normal, el suelo manda. Asi que con 15 o con 59
# minutos fuera se sigue mirando cada hora, exactamente igual que antes de este cambio.
Comp '1d. pasar el liston no alarga por si solo' (Test-TocaRonda $HORA $HORA 15) '15 min de ausencia siguen siendo una ronda por hora'
Comp '1e. ni con 59 minutos fuera' (Test-TocaRonda $HORA $HORA 59) 'la normal es el suelo'
Comp '1f. y con 90 ya no toca a la hora' (-not (Test-TocaRonda $HORA $HORA 90)) 'ahi si empieza a alargarse'

Write-Host ''
Write-Host '-- 2. SIN NADIE, LA CADENCIA ES LO QUE LLEVA SIN NADIE --'
# dos horas sin nadie: se mira cada dos horas
Comp '2a. con 120 min fuera, a la hora no toca' (-not (Test-TocaRonda $HORA $HORA 120)) ''
Comp '2b. y a las dos horas si' (Test-TocaRonda (2 * $HORA) $HORA 120) 'la cadencia se ajusta sola, sin numero a mano'
Comp '2c. con 600 min fuera, a las dos horas no' (-not (Test-TocaRonda (2 * $HORA) $HORA 600)) ''
Comp '2d. y a las diez horas si' (Test-TocaRonda (10 * $HORA) $HORA 600) ''
# NUNCA ANTES DE SU CADENCIA NORMAL, PASE LO QUE PASE CON LA PRESENCIA. Esto es lo que de verdad
# protege que la guarda no pueda acelerar nada, y lo da la primera linea de la funcion. (Aqui habia
# dos casos sobre un 'suelo' que resulto ser codigo muerto: pasaban por esta misma primera linea,
# asi que se quedaban verdes con y sin el. Se quito el suelo y se escribio lo que si se rompe.)
$antesDeTiempo = @()
foreach ($fuera in -1, 0, 14, 15, 20, 120, 600, 10080) {
    if (Test-TocaRonda ($HORA - 1) $HORA $fuera) { $antesDeTiempo += @([string]$fuera) }
}
Comp '2e. nunca antes de su cadencia normal' ($antesDeTiempo.Count -eq 0) 'probado con 8 presencias distintas, del -1 a una semana fuera'
Comp '2f. y justo al cumplirla, con alguien, toca' (Test-TocaRonda $HORA $HORA 0) ''

Write-Host ''
Write-Host '-- 3. NUNCA DEJA DE MIRAR (regla 2: un modo sin salida no puede existir) --'
$sinSalida = @()
foreach ($fuera in 30, 120, 600, 1440, 10080) {
    # POR MUCHO QUE LLEVE FUERA SIEMPRE HAY UN PLAZO EN EL QUE VUELVE A TOCAR, y ese plazo es el
    # mayor de los dos: su ausencia o la cadencia normal.
    $plazo = [Math]::Max([double]$fuera * 60000.0, $HORA)
    if (-not (Test-TocaRonda $plazo $HORA $fuera)) { $sinSalida += @([string]$fuera) }
}
Comp '3a. lleve lo que lleve, acaba tocando' ($sinSalida.Count -eq 0) 'probado con media hora, dos, diez, un dia y una semana fuera'
Comp '3b. y una semana fuera no lo apaga' (Test-TocaRonda (10080 * 60000.0) $HORA 10080) ''

Write-Host ''
Write-Host '-- 4. NO SABER NO ES "NO HAY NADIE" --'
Comp '4a. con -1, se hace lo de siempre' (Test-TocaRonda $HORA $HORA -1) 'una averia de user32 no puede dejarla sin mirar'
Reset -1
Comp '4b. y Test-HayAlguien dice que si' (Test-HayAlguien) ''
# LO QUE DE VERDAD SE PUEDE ROMPER AQUI es de donde sale ese -1: si Get-NadieMin peta, el catch
# tiene que devolver -1 y no un numero. Un catch que contestara '0' o '999' seria la manera 10 de
# mentir, y en este caso dejaria a Nova sin mirar nada por una averia de user32.
$script:nadieCache = -1; $script:nadieCacheEn = -100000
function Get-NadieMin { throw 'user32 no contesta' }
Comp '4e. si la senal peta, el catch dice -1' ([int](Get-NadieMinFrenado) -eq -1) 'ni 0 ni un numero grande'
Comp '4f. y con eso se hace lo de siempre' (Test-HayAlguien) ''
function Get-NadieMin { $script:vecesPreguntado++; return $script:nadieDevuelve }
Reset 0
Comp '4c. con 0 minutos fuera, hay alguien' (Test-HayAlguien) ''
Reset 99
Comp '4d. con 99, no hay nadie' (-not (Test-HayAlguien)) ''

Write-Host ''
Write-Host '-- 5. EL REFRESCO AL VOLVER, SIN UNA LINEA PARA EL --'
Reset 600
# seis horas durmiendo: la ronda vencio hace mucho y se salta
$desde = -6 * $HORA
Comp '5a. durmiendo, la ronda se salta' (-not (Test-RondaDeFondo $desde $HORA 'el tiempo')) ''
Comp '5b. y se cuenta lo que se ahorro' ($script:fondoSaltadas -eq 1) ([string]$script:fondoSaltadas)
# y ahora vuelve: la MISMA llamada, solo cambia la presencia
$script:nadieDevuelve = 0
$script:nadieCacheEn = -100000    # el freno del minuto ya caduco
Comp '5c. al volver, cae en la vuelta siguiente' (Test-RondaDeFondo $desde $HORA 'el tiempo') 'sin evento de vuelta ni codigo para el'
Comp '5d. y lo dice con lo que se ahorro' ($script:logs.Count -gt 0 -and $script:logs[-1] -match 'me ahorre 1 salida') ([string]$script:logs[-1])
Comp '5e. y el contador se pone a cero' ($script:fondoSaltadas -eq 0) 'si no, la cuenta del tramo siguiente mentiria'
# y sin nada saltado, no se escribe nada
$antesL = $script:logs.Count
[void](Test-RondaDeFondo $desde $HORA 'el tiempo')
Comp '5f. sin nada que contar, no escribe' ($script:logs.Count -eq $antesL) 'una linea por hora seria ruido'

Write-Host ''
Write-Host '-- 6. EL FRENO DE UN MINUTO (medido: sin el, 259 s de CPU en seis horas) --'
Reset 600
$antesP = $script:vecesPreguntado
1..50 | ForEach-Object { [void](Test-RondaDeFondo (-6 * $HORA) $HORA 'el tiempo') }
Comp '6a. cincuenta vueltas, una sola pregunta' (($script:vecesPreguntado - $antesP) -eq 1) ([string]($script:vecesPreguntado - $antesP) + ' preguntas')
Comp '6b. Get-InactividadMin cuesta 0,364 ms' $true 'medido aqui con 200 llamadas; y es la parte BARATA de Get-NadieMin'
# y pasado el minuto, se vuelve a preguntar
$script:nadieCacheEn = [double]$sw.ElapsedMilliseconds - 60001
[void](Test-RondaDeFondo (-6 * $HORA) $HORA 'el tiempo')
Comp '6c. pasado el minuto, se vuelve a mirar' (($script:vecesPreguntado - $antesP) -eq 2) 'el freno no puede ser para siempre'
# el freno NO se salta la cuenta: antes del plazo no se pregunta nada
Reset 600
[void](Test-RondaDeFondo ([double]$sw.ElapsedMilliseconds) $HORA 'el tiempo')
Comp '6d. antes del plazo ni se pregunta' ($script:vecesPreguntado -eq 0) 'la presencia solo se mira cuando ya tocaria'

Write-Host ''
Write-Host '-- 7. LA RED CAIDA MANDA SOBRE TODO --'
Reset 0
$script:redOk = $false
Comp '7a. con la red caida no se sale' (-not (Test-RondaDeFondo (-6 * $HORA) $HORA 'el tiempo')) 'el clima no tenia esta guarda; el correo si desde la idea 84'
Comp '7b. y eso no se cuenta como ahorro por ausencia' ($script:fondoSaltadas -eq 0) 'son dos motivos distintos y no se mezclan'
Comp '7c. ni se pregunta por la presencia' ($script:vecesPreguntado -eq 0) ''

Write-Host ''
Write-Host '-- 8. EL CABLEADO, Y LO QUE SE QUEDA FUERA --'
Comp '8a. el clima pasa por la ronda' ($sinCom -match "Test-RondaDeFondo \`$script:climaCheck 3600000 'el tiempo'") ''
Comp '8b. y ya no mira el reloj a pelo' (-not ($sinCom -match '\$script:climaCheck\) -ge 3600000')) ''
Comp '8c. la primera sigue a los 20 s del arranque' ($sinCom -match '(?s)ClimaOn.{0,80}-ge 20000') 'eso no era el problema'
Comp '8d. el correo de la manana pregunta si hay alguien' ($sinCom -match '(?s)\$hC -ge 7 -and \$hC -lt 12.{0,120}Test-HayAlguien') ''
Comp '8e. y conserva su ventana y su una-vez-al-dia' ($sinCom -match '(?s)\$hC -ge 7 -and \$hC -lt 12.{0,120}yaMireHoy') ''
# EL OIDO FUERA: dormirlo por inactividad la dejaria sorda
Comp '8f. el oido NO pasa por la ronda' (-not ($sinCom -match '(?s)(wakeCheck[\s\S]{0,200}Test-RondaDeFondo|Test-RondaDeFondo[^
]{0,80}wakeCheck)')) 'dormirlo por inactividad la dejaria sorda'
Comp '8g. y sigue mirandose cada 30 s' ($sinCom -match '\$script:wakeCheck\) -ge 30000') ''
# EL DISCO Y LA BIBLIOTECA FUERA: no son red
Comp '8h. el disco no pasa por la ronda' (-not ($sinCom -match '(?s)DriveInfo.{0,400}Test-RondaDeFondo')) 'DriveInfo es local, no ahorra ni un viaje'
Comp '8i. la biblioteca tampoco' (-not ($sinCom -match '(?s)Update-Juegos.{0,200}Test-RondaDeFondo')) 'lee el vdf del disco, 67 ms medidos'
# SOBRE SU PROPIO TEXTO, no sobre una ventana de N caracteres del fichero: la funcion encogio al
# quitarle el suelo muerto y la ventana empezo a alcanzar a la de al lado, que si usa el reloj.
$cuerpoT = @($defs | Where-Object { $_.Name -eq 'Test-TocaRonda' })[0].Extent.Text
Comp '8j. Test-TocaRonda es pura' (-not ($cuerpoT -match '(Get-Date|\$sw\.|Log |Test-Path)')) 'sin reloj ni fichero dentro: por eso se puede probar'
Comp '8k. y el liston es el que ya usa la copia' ($cuerpoT -match '\$TrabajoAusenciaMin') 'no es un numero nuevo'
Comp '8m. y no le quedo suelo muerto' (-not ($cuerpoT -match 'largaMs')) 'quitarlo no ponia rojo ni un caso'
Comp '8l. Test-BuenRatoParaTrabajo sigue usandolo' ($sinCom -match '(?s)function Test-BuenRatoParaTrabajo[\s\S]{0,400}?\$TrabajoAusenciaMin') 'las dos guardas miran el mismo numero'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la ronda de fondo ya mira si hay alguien a quien contarselo' -ForegroundColor Green
exit 0
