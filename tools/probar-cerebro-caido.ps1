# QUE NOTE QUE EL CEREBRO LOCAL ESTA APAGADO (26/09, idea 14 de las 121).
#
# LO MEDIDO, y es diez veces peor de lo que decia la idea: el 26/09, entre las 00:07 y las
# 13:49, assistant.log trae SETECIENTAS CINCUENTA Y SEIS lineas de "diario: no pude resumir ...
# 10061" -Windows diciendo "no hay nadie escuchando en ese puerto"-. Los huecos entre una y
# otra: 517 de 65 segundos, 237 de 66 y uno de 67. Ni un freno, ni uno solo creciendo.
# Y pesa: de las 877 lineas que la charla escribio ese dia, 756 son esa misma. El 86,2 %.
#
# Ollama no estaba arrancado -ningun proceso y el puerto sin escuchar-, asi que Nova llamo a
# una puerta cerrada cada minuto durante catorce horas, y lo apunto cada vez.
#
# LO QUE MAS VIGILA ESTE BANCO: que el freno NO llegue al camino en caliente. Ahi hay alguien
# esperando una respuesta, y saltarselo por una espera dejaria a braya sin contestacion cuando
# el cerebro local SI habia vuelto.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$t = [IO.File]::ReadAllText((Join-Path $raiz 'charla_worker.py'), [Text.Encoding]::UTF8)
$sin = (($t -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. las cuatro piezas --'
foreach ($f in @('ollama_vivo', 'ollama_cayo', 'ollama_respondio', 'ollama_arrancar')) {
    Comp "existe $f" ($sin -match ('def ' + $f)) ''
}
# ollama_vivo NO PUEDE TOCAR LA RED: si sondeara, cada pregunta costaria una conexion y los
# bancos que doblan httpx contarian una llamada de mas.
$i = $sin.IndexOf('def ollama_vivo')
$blV = if ($i -ge 0) { $sin.Substring($i, [Math]::Min(220, $sin.Length - $i)) } else { '' }
Comp '  y ollama_vivo solo mira el reloj' ($blV -notmatch 'httpx' -and $blV -match 'time\.time\(\)') 'sondear aqui costaria una conexion por pregunta'

Write-Host ''
Write-Host '-- 2. los tres numeros, y de donde salen --'
foreach ($c in @('OLLAMA_ESPERA_SUELO', 'OLLAMA_ESPERA_TECHO', 'OLLAMA_ARRANQUE_RAM_MIN_MB')) {
    $m = [regex]::Match($t, ('(?m)^' + $c + '\s*=\s*([0-9.]+)'))
    Comp ("se saca del archivo " + $c) $m.Success ''
    if ($m.Success) { Set-Variable -Name $c -Value ([double]$m.Groups[1].Value) }
}
# EL SUELO ES EL HUECO REAL MEDIDO: 517 huecos de 65 s. Asi el primer reintento cae donde caia.
Comp 'el suelo es el hueco que ya habia' ($OLLAMA_ESPERA_SUELO -ge 60 -and $OLLAMA_ESPERA_SUELO -le 70) "$OLLAMA_ESPERA_SUELO s; medidos 517 huecos de 65"
Comp 'el techo no llega a una tarde entera' ($OLLAMA_ESPERA_TECHO -le 3600) "$([int]($OLLAMA_ESPERA_TECHO/60)) minutos"
Comp '  y es mayor que el suelo' ($OLLAMA_ESPERA_TECHO -gt $OLLAMA_ESPERA_SUELO) ''
# LA RAM NO ES UN NUMERO NUEVO: es la que el oido ya exige para su modelo grande.
$tw = [IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [Text.Encoding]::UTF8)
$mR = [regex]::Match($tw, '(?m)^RAM_MIN_PARAKEET\s*=\s*([0-9.]+)')
Comp 'la RAM minima es la que ya usa el oido' ($mR.Success -and $OLLAMA_ARRANQUE_RAM_MIN_MB -eq [double]$mR.Groups[1].Value) "$OLLAMA_ARRANQUE_RAM_MIN_MB MB, como RAM_MIN_PARAKEET"

Write-Host ''
Write-Host '-- 3. la espera crece, y se borra entera al volver --'
# LA CUENTA, ejecutada: sin esto solo se comprobaria que la linea existe.
$suelo = $OLLAMA_ESPERA_SUELO; $techo = $OLLAMA_ESPERA_TECHO
function Espera([int]$fallos) { return [Math]::Min($techo, $suelo * [Math]::Pow(2, $fallos - 1)) }
Comp 'el primer fallo espera lo de siempre' ((Espera 1) -eq $suelo) "$([int](Espera 1)) s"
Comp '  el segundo, el doble' ((Espera 2) -eq ($suelo * 2)) "$([int](Espera 2)) s"
Comp '  y acaba topando' ((Espera 20) -eq $techo) "$([int]((Espera 20)/60)) minutos"
# AL VOLVER SE BORRA DEL TODO, no se divide: si no, arrastraria la espera para siempre.
$iR = $sin.IndexOf('def ollama_respondio')
$blR = if ($iR -ge 0) { $sin.Substring($iR, [Math]::Min(600, $sin.Length - $iR)) } else { '' }
Comp 'al volver, la espera se pone a cero' ($blR -match '"no_antes_de"\] = 0') 'dividirla arrastraria el castigo'
Comp '  y los fallos tambien' ($blR -match '"fallos"\] = 0') ''

Write-Host ''
Write-Host '-- 4. se dice UNA vez, no setecientas --'
$iC = $sin.IndexOf('def ollama_cayo')
$blC = if ($iC -ge 0) { $sin.Substring($iC, [Math]::Min(700, $sin.Length - $iC)) } else { '' }
Comp 'el aviso va detras de una bandera' ($blC -match 'if not _OLLAMA\["avisado"\]') '756 lineas iguales en catorce horas'
Comp '  y la bandera se marca' ($blC -match '"avisado"\] = True') ''
Comp 'y cuando vuelve tambien se dice' ($blR -match 'ha vuelto') ''

Write-Host ''
Write-Host '-- 5. levantarlo: UNA vez, y sin estorbar --'
$iA = $sin.IndexOf('def ollama_arrancar')
$blA = if ($iA -ge 0) { $sin.Substring($iA, [Math]::Min(1200, $sin.Length - $iA)) } else { '' }
# LA MARCA VA ANTES DE TODO: si se pusiera al final, un fallo a mitad dejaria la puerta abierta
# a intentarlo otra vez en cada ciclo.
$iMarca = $blA.IndexOf('"arranque_probado"] = True')
$iJuego = $blA.IndexOf('revisor_parado')
Comp 'la marca se pone ANTES de comprobar nada' ($iMarca -ge 0 -and $iJuego -gt $iMarca) 'si no, un fallo a mitad permitiria reintentar'
Comp '  y no se levanta con un juego delante' ($blA -match 'revisor_parado\.is_set\(\)') 'regla 5 de la casa'
Comp '  ni sin RAM' ($blA -match 'OLLAMA_ARRANQUE_RAM_MIN_MB') ''
Comp '  ni si no esta instalado' ($blA -match 'os\.path\.exists\(exe\)') ''
Comp '  y sin abrir una ventana' ($blA -match '0x08000000') 'CREATE_NO_WINDOW'

Write-Host ''
Write-Host '-- 6. EL FRENO NO LLEGA AL CAMINO EN CALIENTE --'
# ESTA ES LA COMPROBACION QUE IMPIDE EL DESTROZO. En generar_local hay alguien esperando: si
# se saltara por una espera, braya se quedaria sin respuesta justo cuando el modelo SI volvio.
$iG = $sin.IndexOf('def generar_local')
$iF = $sin.IndexOf('def _cabeceras')
$blG = if ($iG -ge 0 -and $iF -gt $iG) { $sin.Substring($iG, $iF - $iG) } else { '' }
Comp 'se encuentra generar_local' ($blG -ne '') ''
Comp '  NO se frena a si mismo' ($blG -notmatch 'if not ollama_vivo') 'ahi hay alguien esperando respuesta'
Comp '  pero si cuenta el fallo' ($blG -match 'ollama_cayo\(') 'para avisar y para levantarlo'
Comp '  y avisa de que ha vuelto' ($blG -match 'ollama_respondio\(\)') ''
# Y EL BUCLE DE FONDO SI SE FRENA: ahi no espera nadie.
$iD = $sin.IndexOf('def resumir_dias_pasados')
$blD = if ($iD -ge 0) { $sin.Substring($iD, [Math]::Min(900, $sin.Length - $iD)) } else { '' }
Comp 'y el resumen del diario SI se frena' ($blD -match 'if not ollama_vivo\(\)') 'ese corria cada 65 s sin que nadie lo esperara'

Write-Host ''
Write-Host '-- 7. contra el registro de verdad --'
$n = 0
$log = Join-Path $raiz 'assistant.log'
if (Test-Path -LiteralPath $log) {
    foreach ($l in @(Get-Content -LiteralPath $log -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'no pude resumir') { $n++ }
    }
}
Write-Host ("       'no pude resumir' sale $n veces en assistant.log")
Comp 'el problema existe y es grande' ($n -ge 100) 'medidas 756 en catorce horas'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el cerebro local caido se nota una vez, no setecientas'
exit 0
