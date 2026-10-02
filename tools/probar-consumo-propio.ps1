# LO QUE NOVA OCUPA DE LA CONSOLA, MEDIDO POR ELLA MISMA (27/09, idea 111 de las 121)
#
# EL DATO: la regla 5 de la casa dice que nada residente se coma la RAM ni un nucleo que le hace
# falta al juego, y no habia NI UNA medicion de eso. TotalProcessorTime no aparecia ni una vez en
# assistant.ps1, wake_vosk.py ni charla_worker.py; WorkingSet64 solo salia dentro de Get-RamResumen,
# que corre unicamente cuando braya lo pregunta en voz alta. El pulso lo confirma: 3.805 lineas
# [escucha], 18 [bateria] y cero de consumo propio.
#
# LO QUE ESTE BANCO PROTEGE, Y POR QUE CADA COSA:
#   1. QUE UN MUERTO NO CUENTE. Es la trampa que aparecio midiendo y la ficha no la dice: un proceso
#      muerto no tira excepcion -Refresh() pasa, WorkingSet64 da 0 y TotalProcessorTime se queda
#      congelado-. Y la casa guarda .Handle de los tres workers a proposito, asi que el objeto
#      sobrevive al proceso y esto pasaria de verdad. Sin la guarda, la linea base se llena de ceros.
#   2. QUE EL LISTON SALGA DE SUS DATOS. Percentil 90 mas lo que la serie se mueve (90 menos 50).
#      Con el 90 a secas saltaria una de cada diez veces POR DEFINICION: eso es ruido, no aviso.
#   3. QUE NO OPINE SIN MUESTRAS. Menos de 20 y el liston es 0, que es 'no me preguntes'.
#   4. QUE EL MINUTO OCIOSO CUENTE. Add-TrabajoTiempo rechaza el cero por contrato; sin el maximo
#      con 1, la serie solo tendria los minutos cargados y el liston subiria solo.
#   5. QUE CON JUEGO Y SIN JUEGO NO SE MEZCLEN.
#   6. QUE ALGUIEN LO LEA. Si la serie no la cuenta nadie es otro contador muerto, que es el pecado
#      que las ideas 99 y 100 tuvieron que arreglar.
#   7. Y QUE NO REINICIE NADA. La ficha proponia reiniciar el worker hinchado; con cero muestras eso
#      es un numero inventado. Se mide y se dice.
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

# LAS FUNCIONES DE VERDAD, sacadas del fichero real. Los dobles se definen DESPUES de cargarlas,
# para que ninguna definicion de mentira tape a la buena.
$quiero = @('Get-ProcesosNova', 'Get-ConsumoProceso', 'Get-ConsumoListon', 'Test-ConsumoSalido',
            'Update-Consumo', 'Get-ConsumoResumen', 'Get-PercentilLista')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
# RECORTAR POR LOS LIMITES DE VERDAD, no por una ventana de N caracteres (27/09, idea 2). Los
# cuatro casos del cableado de abajo median "a menos de N caracteres" -uno de ellos 4000, que no
# es una vecindad, es medio archivo- y se ponen rojos solos en cuanto alguien escribe una linea
# dentro. Cuerpo() usa el arbol del parser; Bloque() cuenta llaves, para lo que no es una funcion.
function Cuerpo([string]$nombre) {
    $d = @($defs | Where-Object { $_.Name -eq $nombre })
    if ($d.Count -eq 0) { return '' }
    return (($d[0].Extent.Text -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
}
function Bloque([string]$texto, [string]$ancla) {
    $i = $texto.IndexOf($ancla)
    if ($i -lt 0) { return '' }
    $abre = $texto.IndexOf('{', $i)
    if ($abre -lt 0) { return '' }
    $prof = 0
    for ($p = $abre; $p -lt $texto.Length; $p++) {
        if ($texto[$p] -eq '{') { $prof++ }
        elseif ($texto[$p] -eq '}') { $prof--; if ($prof -eq 0) { return $texto.Substring($abre, $p - $abre + 1) } }
    }
    return ''
}
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 7 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)

# EL MUNDO DE MENTIRA (despues de cargar, nunca antes)
$ConsumoTopeMs = 60
$ConsumoMinMuestras = 20
$ConsumoPercentil = 90
$ConsumoAvisoMin = 60
$ConsumoNombres = @{ cerebro = 'el cerebro'; oido = 'el oido'; capsula = 'la capsula'; charla = 'la charla' }
$script:consumoSonda = ''
$script:consumoTurno = -1
$script:consumoLeidas = 0
$script:consumoAntes = @{}
$script:consumoUltimo = @{}
$script:consumoAvisoEn = @{}
# Y EL ULTIMO VALOR AVISADO DE CADA COSA (2/10): Test-ConsumoSalido ya no repite el MISMO
# numero, asi que sin esta tabla la llamaba sobre $null y el banco moria con "No se puede
# llamar a un metodo en una expresion con valor NULL" -que desde fuera parece un fallo del
# codigo y era del banco-.
$script:consumoAvisoVal = @{}
$script:yoProc = $null
$script:wakeProc = $null; $script:uiProc = $null; $script:charlaProc = $null
$script:juegoActivo = $null
$sw = [Diagnostics.Stopwatch]::StartNew()
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { }
# la tabla de series, en RAM: los dobles de Get/Add-TrabajoTiempo
$script:series = @{}
function Get-TrabajoTiempos([string]$clave) {
    $l = New-Object System.Collections.ArrayList
    if ($script:series.ContainsKey($clave)) { foreach ($v in $script:series[$clave]) { [void]$l.Add([int]$v) } }
    return ,$l
}
function Add-TrabajoTiempo([string]$clave, [int]$ms) {
    # EL CONTRATO DE VERDAD, copiado del original: rechaza el cero y lo de abajo
    if (-not $clave -or $ms -le 0) { return $false }
    if (-not $script:series.ContainsKey($clave)) { $script:series[$clave] = New-Object System.Collections.ArrayList }
    [void]$script:series[$clave].Add($ms)
    return $true
}
# un proceso de pega, con el mismo trato que da el de verdad
function Falso([int]$mb, [double]$cpuS, [bool]$muerto = $false) {
    $o = New-Object PSObject
    $o | Add-Member -MemberType NoteProperty -Name WorkingSet64 -Value ([double]$mb * 1MB)
    $o | Add-Member -MemberType NoteProperty -Name TotalProcessorTime -Value ([TimeSpan]::FromSeconds($cpuS))
    $o | Add-Member -MemberType NoteProperty -Name HasExited -Value $muerto
    $o | Add-Member -MemberType ScriptMethod -Name Refresh -Value { }
    return $o
}

Write-Host ''
Write-Host '-- 1. UN PROCESO MUERTO NO CUENTA (la trampa que aparecio midiendo) --'
# tal cual se vio: 168 MB, 224 MB, y desde ahi 0 con la CPU clavada en 2,08
$vivo = Falso 224 2.08
Comp '1a. uno vivo si se lee' ($null -ne (Get-ConsumoProceso $vivo $null 1000.0)) ''
$muerto = Falso 0 2.08 $true
Comp '1b. uno muerto devuelve nada' ($null -eq (Get-ConsumoProceso $muerto $null 1000.0)) 'Refresh() pasa y da 0 megas sin quejarse'
# y con RAM 0 pero sin marcar muerto (por si acaso), tampoco se cuela un cero
$cero = Falso 0 2.08
Comp '1c. ni uno que diga 0 megas' ($null -eq (Get-ConsumoProceso $cero $null 1000.0)) 'un 0 en la serie hunde el liston para siempre'
# y la lista de procesos tambien lo filtra
$script:wakeProc = Falso 281 100.0
$script:uiProc = Falso 98 50.0 $true
$script:yoProc = Falso 214 1874.0
$v = Get-ProcesosNova
Comp '1d. la capsula muerta no sale de la lista' (@($v | Where-Object { $_.nombre -eq 'capsula' }).Count -eq 0) ([string]$v.Count + ' vivos de 3')
Comp '1e. y el oido y el cerebro si' ((@($v | Where-Object { $_.nombre -eq 'oido' }).Count -eq 1) -and (@($v | Where-Object { $_.nombre -eq 'cerebro' }).Count -eq 1)) ''
Comp '1f. la lista vuelve con su cuenta de verdad' ($v.Count -eq 2) 'medido: con @() en el llamador esto valdria 1 siempre'
$guardaY = $script:yoProc; $guardaW = $script:wakeProc; $guardaU = $script:uiProc
$script:yoProc = Falso 0 0.0 $true; $script:wakeProc = $null; $script:uiProc = $null
$nadie = Get-ProcesosNova
Comp '1g. y sin nadie vivo, cuenta cero' ([int]$nadie.Count -eq 0) 'un array de uno con la lista vacia dentro haria medir la nada'
$script:yoProc = $guardaY; $script:wakeProc = $guardaW; $script:uiProc = $guardaU

Write-Host ''
Write-Host '-- 2. LA CUOTA DE NUCLEO ES UNA RESTA PARTIDA POR OTRA --'
# 26,2 % de un nucleo: la ficha midio el cerebro en 1.874 s de CPU sobre 1h59m
$a = Get-ConsumoProceso (Falso 214 1000.0) $null 60000.0
Comp '2a. sin lectura anterior, la cuota es -1' ([int]$a.cuota -eq -1) 'todavia no se, y no se guarda nada'
$b = Get-ConsumoProceso (Falso 214 1060.0) @{ cpu = 1000.0; reloj = 60000.0 } 120000.0
Comp '2b. 60 s de CPU en 60 s de reloj es un nucleo entero' ([int]$b.cuota -eq 1000) ([string]$b.cuota + ' milesimas')
$c = Get-ConsumoProceso (Falso 214 1015.72) @{ cpu = 1000.0; reloj = 60000.0 } 120000.0
Comp '2c. y el 26,2 % de la ficha sale 262' ([Math]::Abs([int]$c.cuota - 262) -le 1) ([string]$c.cuota + ' milesimas')
# el relanzamiento: el handle es otro y la CPU baja
$d = Get-ConsumoProceso (Falso 214 3.0) @{ cpu = 1000.0; reloj = 60000.0 } 120000.0
Comp '2d. una resta negativa no es un dato' ([int]$d.cuota -eq -1) 'pasa cuando el worker se relanza entre dos turnos'
Comp '2e. pero el punto nuevo si se guarda' ([Math]::Abs([double]$d.cpu - 3.0) -lt 0.01) 'de ahi sale la cuota siguiente'

Write-Host ''
Write-Host '-- 3. EL LISTON SALE DE SU PROPIA SERIE --'
$script:series = @{}
1..19 | ForEach-Object { [void](Add-TrabajoTiempo 'ram:oido' 280) }
Comp '3a. con 19 muestras no opina' ((Get-ConsumoListon 'ram:oido') -eq 0) 'menos de 20 es "no me preguntes"'
[void](Add-TrabajoTiempo 'ram:oido' 280)
Comp '3b. con 20 ya hay liston' ((Get-ConsumoListon 'ram:oido') -gt 0) ([string](Get-ConsumoListon 'ram:oido') + ' megas')
Comp '3c. una serie quieta deja el liston pegado' ((Get-ConsumoListon 'ram:oido') -eq 280) 'p90 = p50 = 280, no se mueve nada'
# una serie que se mueve abre el liston sola
$script:series = @{}
1..20 | ForEach-Object { [void](Add-TrabajoTiempo 'ram:cerebro' (200 + $_ * 5)) }
$lC = Get-ConsumoListon 'ram:cerebro'
$p90 = [int](Get-PercentilLista (Get-TrabajoTiempos 'ram:cerebro') 90)
$p50 = [int](Get-PercentilLista (Get-TrabajoTiempos 'ram:cerebro') 50)
Comp '3d. una serie ancha abre el liston sola' ($lC -gt $p90) ('p90 ' + $p90 + ' + lo que se mueve ' + ($p90 - $p50) + ' = ' + $lC)
Comp '3e. y no es un numero escrito a mano' ($lC -eq ($p90 + ($p90 - $p50))) ''
# y esto es lo que evita el ruido: estar en el decil alto NO es salirse
$script:consumoAvisoEn = @{}; $script:consumoAvisoVal = @{}; $script:logs = @()
Comp '3f. estar en el decil alto no es salirse' (-not (Test-ConsumoSalido 'ram:cerebro' $p90 'cerebro' 'megas')) ('el p90 son ' + $p90 + ' y el liston ' + $lC)
Comp '3g. pero hincharse si' (Test-ConsumoSalido 'ram:cerebro' ($lC + 1) 'cerebro' 'megas') ''
Comp '3h. y lo dice con nombre de casa' ($script:logs[-1] -match 'el cerebro') ([string]$script:logs[-1])

Write-Host ''
Write-Host '-- 4. UNA LINEA POR HORA, NO UNA POR MINUTO --'
$antesL = $script:logs.Count
Comp '4a. el segundo aviso seguido se calla' (-not (Test-ConsumoSalido 'ram:cerebro' ($lC + 99) 'cerebro' 'megas')) ''
Comp '4b. y no escribe nada' ($script:logs.Count -eq $antesL) 'un tramo hinchado escribiria una por minuto'
# pasada la hora, vuelve a hablar
$script:consumoAvisoEn['ram:cerebro'] = [double]$sw.ElapsedMilliseconds - ($ConsumoAvisoMin * 60000) - 1
# PASADA LA HORA VUELVE A HABLAR, PERO SOLO SI EMPEORA (2/10). Antes bastaba con que pasara la
# hora, y en el registro del 2/10 eso daba ocho lineas identicas: 'la capsula va por 236
# milesimas de nucleo y lo suyo son 230', un 2,6 % por encima, repetido cada hora. El criterio
# nuevo es el de los petes: la noticia es que EMPEORE, no que el reloj siga andando.
Comp '4c. pasada la hora y PEOR, vuelve a decirlo' (Test-ConsumoSalido 'ram:cerebro' ($lC + 200) 'cerebro' 'megas') ''
$script:consumoAvisoEn['ram:cerebro'] = [double]$sw.ElapsedMilliseconds - ($ConsumoAvisoMin * 60000) - 1
Comp '4c2. pero con el MISMO numero, no' (-not (Test-ConsumoSalido 'ram:cerebro' ($lC + 200) 'cerebro' 'megas')) 'ocho lineas iguales el 2/10'
# y el freno es POR CLAVE: que se hinche la RAM no calla el aviso de la CPU
$script:series['cpu:cerebro'] = $script:series['ram:cerebro']
Comp '4d. el freno es por cosa, no global' (Test-ConsumoSalido 'cpu:cerebro' ($lC + 1) 'cerebro' 'milesimas de nucleo') ''

Write-Host ''
Write-Host '-- 5. EL TURNO: UNO POR VUELTA, Y EL MINUTO OCIOSO CUENTA --'
$script:series = @{}; $script:consumoAntes = @{}; $script:consumoUltimo = @{}
$script:consumoTurno = -1; $script:consumoLeidas = 0; $script:consumoSonda = ''; $script:logs = @()
$script:yoProc = Falso 214 1874.0
$script:wakeProc = Falso 281 500.0
$script:uiProc = Falso 98 300.0
$script:charlaProc = $null
[void](Update-Consumo); [void](Update-Consumo); [void](Update-Consumo)
Comp '5a. tres vueltas miden los tres, no uno tres veces' ($script:consumoUltimo.Count -eq 3) ([string]$script:consumoUltimo.Count + ' medidos')
Comp '5b. y cada uno con sus megas' (([int]$script:consumoUltimo['oido'].mb -eq 281) -and ([int]$script:consumoUltimo['cerebro'].mb -eq 214)) ''
Comp '5c. la primera vuelta de cada uno no tiene cuota' (-not $script:series.ContainsKey('cpu:cerebro')) 'no hay lectura anterior con la que restar'
# la segunda vuelta de cada uno si
[void](Update-Consumo); [void](Update-Consumo); [void](Update-Consumo)
Comp '5d. la segunda si la tiene' ($script:series.ContainsKey('cpu:cerebro')) ''
# EL MINUTO OCIOSO: la CPU no se ha movido nada, la cuota es 0, y Add-TrabajoTiempo rechaza el 0
$script:series = @{}; $script:consumoAntes = @{}; $script:consumoTurno = -1
$quieto = Falso 214 1874.0
$script:yoProc = $quieto; $script:wakeProc = $null; $script:uiProc = $null
[void](Update-Consumo); [void](Update-Consumo)
Comp '5e. un minuto ocioso tambien cuenta' ($script:series.ContainsKey('cpu:cerebro')) 'sin el maximo con 1, el liston subiria solo'
$ocioso = -1
if ($script:series.ContainsKey('cpu:cerebro') -and $script:series['cpu:cerebro'].Count -gt 0) { $ocioso = [int]$script:series['cpu:cerebro'][0] }
Comp '5f. y vale una milesima de nucleo' ($ocioso -eq 1) 'por debajo de cualquier decision'
Comp '5g. pero el ultimo dice la cuota de verdad' ([int]$script:consumoUltimo['cerebro'].cuota -eq 0) 'lo guardado es 1, lo que se cuenta es 0'
# SI EL PROCESO DEL TURNO NO SE DEJA LEER, no se rompe la vuelta. Este es el caso de verdad: vivo
# cuando se lista y Access denied al leerlo (un proceso elevado), o muerto entre las dos cosas. Un
# muerto YA no llega aqui: lo filtra Get-ProcesosNova y la vuelta se va sin medir a nadie.
$script:consumoAntes['cerebro'] = @{ cpu = 1874.0; reloj = 1000.0 }
$arisco = Falso 214 1874.0
$arisco | Add-Member -MemberType ScriptMethod -Name Refresh -Value { throw 'acceso denegado' } -Force
$script:yoProc = $arisco
$antesS = $script:series.Count
[void](Update-Consumo)
Comp '5h. si no se deja leer, no se apunta nada' ($script:series.Count -eq $antesS) ''
Comp '5i. y se olvida su lectura anterior' (-not $script:consumoAntes.ContainsKey('cerebro')) 'si no, la cuota siguiente saldria de un hueco y seria enorme'

Write-Host ''
Write-Host '-- 6. CON JUEGO Y SIN JUEGO NO SE MEZCLAN --'
$script:series = @{}; $script:consumoAntes = @{}; $script:consumoTurno = -1; $script:consumoUltimo = @{}
$script:yoProc = Falso 214 1874.0; $script:wakeProc = $null; $script:uiProc = $null; $script:charlaProc = $null
$script:juegoActivo = $null
[void](Update-Consumo)
$script:juegoActivo = 'elden ring'
[void](Update-Consumo)
Comp '6a. con juego va a su propia clave' ($script:series.ContainsKey('ram:cerebro:juego')) ''
Comp '6b. y sin juego a la suya' ($script:series.ContainsKey('ram:cerebro')) ''
Comp '6c. y no se pisan' (([int]$script:series['ram:cerebro'].Count -eq 1) -and ([int]$script:series['ram:cerebro:juego'].Count -eq 1)) ''
# y el aviso dice contra que juego
$script:series['ram:cerebro:juego'] = New-Object System.Collections.ArrayList
1..20 | ForEach-Object { [void]$script:series['ram:cerebro:juego'].Add(200) }
$script:consumoAvisoEn = @{}; $script:consumoAvisoVal = @{}; $script:logs = @()
[void](Test-ConsumoSalido 'ram:cerebro:juego' 900 'cerebro' 'megas')
Comp '6d. y el aviso dice con que juego delante' ($script:logs[-1] -match 'elden ring') ([string]$script:logs[-1])
$script:juegoActivo = $null

Write-Host ''
Write-Host '-- 7. QUE ALGUIEN LO LEA (si no, es otro contador muerto) --'
$script:consumoUltimo = @{ cerebro = @{ mb = 214; cuota = 262 }; oido = @{ mb = 281; cuota = 154 }; capsula = @{ mb = 98; cuota = 174 } }
$script:series = @{}
$r = Get-ConsumoResumen
Comp '7a. sin muestras dice lo que ve y ya' ($r -match '281 megas') ([string]$r)
Comp '7b. y elige al que mas ocupa' ($r -match 'el oido') 'el oido con 281, no el cerebro con 214'
Comp '7c. y no promete linea base que no tiene' (-not ($r -match 'normal|suyo')) ''
# una serie de verdad se mueve, y 281 vive dentro de ella. (Con la serie clavada en 280 un solo
# mega mas SI es salirse, y el codigo lo decia bien: el caso estaba mal elegido, no la pieza.)
1..20 | ForEach-Object { [void](Add-TrabajoTiempo 'ram:oido' (270 + ($_ % 11))) }
$r2 = Get-ConsumoResumen
Comp '7d. con serie, dice si es lo normal' ($r2 -match 'lo normal en el') ([string]$r2)
$script:series = @{}
1..20 | ForEach-Object { [void](Add-TrabajoTiempo 'ram:oido' 150) }
$r3 = Get-ConsumoResumen
Comp '7e. y si se paso, lo dice con su numero' (($r3 -match 'mas de lo suyo') -and ($r3 -match '150')) ([string]$r3)
$script:consumoUltimo = @{}
Comp '7f. sin nada medido, no dice nada' ((Get-ConsumoResumen) -eq '') 'se acaba de arrancar'

Write-Host ''
Write-Host '-- 8. EL CABLEADO Y LO QUE NO SE HACE --'
Comp '8a. el turno cuelga del bloque del minuto' ($sinCom -match '(?s)\[temperatura\].{0,900}Update-Consumo') 'al lado de la temperatura, sin estrenar reloj'
Comp '8b. Get-RamResumen lo cuenta' ($sinCom -match '(?s)yo llevo.{0,200}Get-ConsumoResumen') ''
Comp '8c. la sonda se cronometra a si misma' ($sinCom -match 'ConsumoTopeMs') 'como Get-CargaCPU y la de temperatura'
Comp '8d. y se apaga sola si cuesta' ($sinCom -match "sonda de consumo off") ''
Comp '8e. la primera lectura no se juzga' ($sinCom -match '\$script:consumoLeidas -ge 2') 'esa paga el Get-Process del cerebro'
# ANCLADO A LAS LINEAS QUE LA NOMBRAN, no a los 40 caracteres siguientes: asi tambien se ve el
# llamador que este en otro sitio del fichero, y no lo tapa una linea nueva por medio.
$lineasUC = @(($sinCom -split "`n") | Where-Object { $_ -match 'Update-Consumo' })
Comp '8f. NO reinicia ningun worker' (($lineasUC.Count -gt 0) -and -not ($lineasUC -match '(Restart|Stop-Process|\.Kill)')) 'con cero muestras eso seria un numero inventado'
$cuerpoUC = Cuerpo 'Update-Consumo'
Comp '8g. ni mata procesos en la sonda' (($cuerpoUC -ne '') -and -not ($cuerpoUC -match '(\.Kill\(\)|Stop-Process)')) ''
$cuerpoCS = Cuerpo 'Test-ConsumoSalido'
Comp '8h. no habla por el altavoz' (($cuerpoCS -ne '') -and -not ($cuerpoCS -match '(Say |Send-Aviso)')) 'esto va al registro, no a la voz'
Comp '8i. ni estrena fichero' (-not ($sinCom -match 'consumo\.json|consumo\.txt')) 'reusa trabajo-tiempos.json, que ya existe'
Comp '8j. el tope se puede tocar desde config' ($sinCom -match "Get-Cfg 'ui' 'consumoTopeMs'") ''
# la tercera aparicion es un comentario de final de linea; lo que importa es que solo haya UN llamador
Comp '8k. Get-RamResumen sigue sin correr en el bucle' (@([regex]::Matches($sinCom, '= Get-RamResumen ')).Count -eq 1) 'recorrer los 200 procesos cuesta de 500 a 740 ms'
# EL BLOQUE DE LA ACCION 'ram' ENTERO, contado por llaves: la ventana de 400 caracteres tapaba
# esta comprobacion en cuanto se escribiera un comentario dentro del case.
Comp '8l. y su unico llamador es la orden hablada' ((Bloque $sinCom "'ram' {") -match '= Get-RamResumen ') ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova ya sabe lo que ocupa, y sabe cuanto es lo suyo' -ForegroundColor Green
exit 0
