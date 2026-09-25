# QUE SEPA CALLARSE PORQUE BRAYA NO ESTA (23/09, idea 20).
#
# EL DATO: 77 avisos ENTORNO en catorce dias, y solo 17 (22 %) tuvieron una orden suya en los
# cinco minutos siguientes. El peor es oido-ruido: 31 avisos y 2 atendidos, el 6 %, y el 40 %
# de todo lo que Nova dice por su cuenta. Quitando los flancos fisicos -el cargador, los
# cascos, el dock, cerrar el juego, que son cosas que acaba de hacer CON LAS MANOS y por
# tanto prueban que esta- quedan 46 avisos de nivel medio con 7 atendidos: 39 frases dichas a
# una habitacion vacia.
# Y la espera hasta la siguiente orden: mediana 68 minutos, el 45 % vuelve en menos de 60 y
# el 56 % en menos de 120. De ahi salen los dos numeros, y el de 30 minutos no es nuevo: es
# el que ya usa Test-ParteManana para decidir que no hay nadie delante.
#
# LO QUE MAS VIGILA ESTE BANCO: que un aviso aplazado NO se marque como dicho. Si se marcara,
# Nova se lo callaria Y ademas lo daria por dicho -gmail-lleno tiene un plazo de una semana,
# asi que se perderia siete dias enteros- y desde fuera seria indistinguible de que no se
# entero de nada. Es el mismo fallo que tuvo el parte de la manana el 21/09, con otra ropa.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# TRAER SE LLEVA TAMBIEN DE QUIEN DEPENDE (25/09). Hasta hoy traia UNA funcion, y el dia que
# esa funcion paso a apoyarse en otra el banco reventaba con "El termino 'X' no se reconoce" y
# se ponia rojo con el codigo perfectamente bien. Paso tres veces el mismo dia -Get-NocheDesde,
# Get-FraseCaducados y Get-SueloPorAnimo- porque el codigo mejoro y el banco se quedo atras.
#
# SOLO SE ARRASTRAN LAS DE CONSULTA (Get-, Test-, ConvertTo-, Describe-). Nunca Send-, Say,
# Log, Save-, Set-, Start-, Stop-, Invoke-, Add- ni Update-: esas TIENEN EFECTOS y son justo
# las que los bancos doblan a proposito. Traerlas de verdad es la manera 9 de salir verde
# mintiendo -un banco acabo dejando un .wav real en piper\salida por eso-.
# LO QUE ESTE BANCO DOBLA, SACADO DEL PROPIO BANCO (25/09). La primera version de Traer
# recursivo arrastraba las funciones de verdad encima de Get-Habitos, Get-Estadisticas y
# Get-CuentaHoy -que este fichero dobla a proposito para darles datos de mentira- y dos
# comprobaciones se pusieron rojas al instante: la manera 9 de salir verde mintiendo,
# provocada por el propio arreglo.
#
# Y NO VALE Get-Command: los Invoke-Expression (Traer ...) corren ANTES de que se definan la
# mitad de los dobles, asi que en ese momento todavia no existen. Tampoco vale una lista a
# mano, que caducaria el dia que alguien anada un doble. Lo que no caduca es que el banco se
# lea A SI MISMO: lo que este fichero define, este fichero no lo trae.
$script:doblesBanco = @{}
try {
    foreach ($fD in @(([System.Management.Automation.Language.Parser]::ParseFile(
                $PSCommandPath, [ref]$null, [ref]$null)).FindAll({ param($x)
                $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
        $script:doblesBanco[$fD.Name] = $true
    }
} catch {}
$script:traidas = @{}
function Traer([string]$n, [bool]$dependencia = $false) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    # LA MEMORIA ES SOLO PARA LAS DEPENDENCIAS (25/09). Si frenara tambien las peticiones
    # directas, un banco que pide la misma funcion dos veces -primero para leerla y luego para
    # ejecutarla, que es un patron normal aqui- se quedaria con el doble puesto y probaria el
    # doble en vez del codigo. Paso en probar-aviso-de-mas con Get-CuentaHoy.
    if ($dependencia -and $script:traidas.ContainsKey($n)) { return '# ya traida' }
    $script:traidas[$n] = $true
    $texto = ''
    foreach ($cmd in @($fn.FindAll({ param($x) $x -is [System.Management.Automation.Language.CommandAst] }, $true))) {
        $nom = ''
        try { $nom = [string]$cmd.GetCommandName() } catch {}
        if (-not $nom -or $nom -eq $n) { continue }
        if ($nom -notmatch '^(?:Get|Test|ConvertTo|Describe)-') { continue }
        if ($script:traidas.ContainsKey($nom)) { continue }
        if ($script:doblesBanco.ContainsKey($nom)) { continue }   # lo que el banco dobla, no se trae
        $otra = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $nom }, $true)
        if ($otra) { $texto += (Traer $nom $true) + "`n" }
    }
    return ($texto + $fn.Extent.Text)
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }
function TraerVar([string]$n) {
    $m = [regex]::Match($fuente, '(?m)^\$' + $n + ' = (.+)$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro la variable $n"; exit 1 }
    return $m.Groups[1].Value
}

# --- el mundo de mentira. NUNCA se toca el tmp\ de verdad --------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('esp-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$AvisoEsperaPath = Join-Path $tmp 'avisos-esperando.json'
$script:ahoraMs = 600000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:avisoEspera = New-Object System.Collections.ArrayList
$script:entornoVistos = @{}
$script:entornoAvisos = New-Object System.Collections.ArrayList
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$script:juegoActivo = $null
$script:ultimaRespuesta = ''
$script:ausenciaMin = 0
$script:logs = @()
$script:apuntes = @()
$script:dichos = @()
$script:popups = @()
$script:vistosGuardados = 0
function Log([string]$m) { $script:logs += $m }
function Add-Estadistica($a, $b) { $script:apuntes += "$a|$b" }
function Show-Popup([string]$t, [string]$e = 'hablando') { $script:popups += $t }
function Say([string]$t, [string]$e = '') { $script:dichos += $t }
function Save-EntornoVistos { $script:vistosGuardados++ }
function Get-AusenciaMin([datetime]$ahora = (Get-Date)) { return $script:ausenciaMin }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
function Send-AvisoCola([bool]$yaMismo = $false) {
    if ($script:avisoCola.Count -eq 0) { return }
    $piezas = @($script:avisoCola | ForEach-Object { ([string]$_).Trim().TrimEnd('.') })
    $script:avisoCola.Clear()
    Say (($piezas -join '. ') + '.')
}
$script:puedoAvisar = $true
# EL FRENO, CON TOPE: asi se puede probar lo que pasa cuando el quinto aviso de la hora no
# cabe, que es donde se perdian.
$script:tope = 99
$script:soltados = 0
function Test-PuedoAvisar([string]$clave, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    if (-not $script:puedoAvisar) { return $false }
    $script:soltados++
    return ($script:soltados -le $script:tope)
}
foreach ($v in @('AvisoEsperaMin', 'AvisoEsperaCaducaMin')) { Invoke-Expression ('$' + $v + ' = ' + (TraerVar $v)) }
# $AvisoSiempre ocupa DOS lineas en el fuente, asi que TraerVar se quedaba con media lista y
# la otra media llegaba aqui como un parentesis sin cerrar.
$mS = [regex]::Match($fuente, '(?ms)^\$AvisoSiempre = (@\(.*?\))\s*$')
if (-not $mS.Success) { Write-Host '  MAL  no encuentro $AvisoSiempre'; exit 1 }
$AvisoSiempre = Invoke-Expression $mS.Groups[1].Value
foreach ($f in @('Test-AvisoAplazable', 'Get-AvisoEspera', 'Save-AvisoEspera', 'Add-AvisoEspera',
                 'Send-AvisoEsperaSuelta', 'Send-AvisoEntorno')) { Invoke-Expression (Traer $f) }

function Limpia {
    $script:avisoEspera.Clear()
    $script:entornoVistos = @{}
    $script:entornoAvisos.Clear()
    $script:avisoCola.Clear()
    $script:logs = @(); $script:apuntes = @(); $script:dichos = @(); $script:popups = @()
    $script:vistosGuardados = 0
    $script:puedoAvisar = $true
    $script:juegoActivo = $null
    try { Remove-Item -LiteralPath $AvisoEsperaPath -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host ''
Write-Host '-- 1. sin nadie delante, el aviso se guarda en vez de decirse --'
Limpia
$script:ausenciaMin = 45
$r1 = Send-AvisoEntorno 'oido-ruido' 'Hay mucho ruido, no te oigo bien' 'medio' 60
Comp 'no se dice' ($script:dichos.Count -eq 0 -and $script:avisoCola.Count -eq 0) "$($script:dichos.Count) dichos"
Comp 'y devuelve que no salio' (-not $r1) "$r1"
Comp 'pero queda aparcado' (@(Get-AvisoEspera).Count -eq 1) "$(@(Get-AvisoEspera).Count)"
Comp 'y con su texto entero' (@(Get-AvisoEspera)[0].texto -eq 'Hay mucho ruido, no te oigo bien') "$(@(Get-AvisoEspera)[0].texto)"
Comp 'y en el disco, que la sesion dura 5,8 minutos' (Test-Path -LiteralPath $AvisoEsperaPath) 'una cola en RAM se la come el reinicio'

Write-Host ''
Write-Host '-- 2. LO QUE MAS IMPORTA: no se da por dicho --'
# Si se marcara, gmail-lleno (plazo de una semana) se perderia siete dias.
Comp 'no se marca como visto' ($script:entornoVistos.Count -eq 0) "$($script:entornoVistos.Count) vistos"
Comp 'ni se guarda el fichero de vistos' ($script:vistosGuardados -eq 0) "$script:vistosGuardados escrituras"
Comp 'ni gasta una plaza del tope por hora' ($script:entornoAvisos.Count -eq 0) "$($script:entornoAvisos.Count)"
Comp 'ni se cuenta como aviso dado' (@($script:apuntes | Where-Object { $_ -match 'aviso-entorno' }).Count -eq 0) "$($script:apuntes -join ' ')"
Comp 'y el log dice que lo aparco' (@($script:logs | Where-Object { $_ -match 'aparcado' }).Count -eq 1) "$($script:logs -join ' / ')"

Write-Host ''
Write-Host '-- 3. con braya delante, todo sigue igual que antes --'
Limpia
$script:ausenciaMin = 5
$r2 = Send-AvisoEntorno 'oido-ruido' 'Hay mucho ruido' 'medio' 60
Comp 'sale al momento' ($r2 -and $script:avisoCola.Count -eq 1) "$r2"
Comp 'y no se aparca nada' (@(Get-AvisoEspera).Count -eq 0) "$(@(Get-AvisoEspera).Count)"
Comp 'y SI se marca como visto' ($script:entornoVistos.Count -eq 1) "$($script:entornoVistos.Count)"

Write-Host ''
Write-Host '-- 4. lo urgente no espera NUNCA --'
Limpia
$script:ausenciaMin = 300
$r3 = Send-AvisoEntorno 'bateria-baja' 'Te queda poca bateria' 'alto' 30
Comp 'un aviso alto sale con 5 horas de ausencia' ($r3 -and $script:dichos.Count -eq 1) "$($script:dichos -join ' ')"
Limpia
$script:ausenciaMin = 300
$r4 = Send-AvisoEntorno 'hora-dormir' 'Es tarde, deberias dormir' 'noche' 60
Comp 'y el de la noche tambien' ($r4) 'aplazarlo a la manana lo convertiria en mentira'
Limpia
$script:ausenciaMin = 300
$r5 = Send-AvisoEntorno 'cargador-quita' 'Has quitado el cargador' 'medio' 5
Comp 'y lo que acaba de hacer con las manos, igual' ($r5) 'ahi la presencia esta probada'
Comp 'las ocho exentas estan en UNA lista a la vista' ($AvisoSiempre.Count -eq 8) "$($AvisoSiempre.Count)"
Limpia
$script:ausenciaMin = 300
$r6 = Send-AvisoEntorno 'bateria-llena' 'Ya esta cargada' 'bajo' 60
Comp 'y lo que no se dice tampoco se aparca' ($r6 -and @(Get-AvisoEspera).Count -eq 0) 'aplazar algo que no suena no ahorra nada'

Write-Host ''
Write-Host '-- 5. jugando SI esta delante --'
Limpia
$script:ausenciaMin = 300
$script:juegoActivo = 'It Takes Two'
$r7 = Send-AvisoEntorno 'oido-ruido' 'Hay mucho ruido' 'medio' 60
Comp 'con un juego abierto no se aparca' (@(Get-AvisoEspera).Count -eq 0) 'de callarse ya se encarga Test-PuedoAvisar'

Write-Host ''
Write-Host '-- 6. y al volver, sale todo junto --'
Limpia
$script:ausenciaMin = 45
[void](Send-AvisoEntorno 'oido-ruido' 'Hay mucho ruido' 'medio' 60)
[void](Send-AvisoEntorno 'disco-poco' 'Queda poco disco' 'medio' 60)
Comp 'dos aparcados' (@(Get-AvisoEspera).Count -eq 2) "$(@(Get-AvisoEspera).Count)"
$script:ausenciaMin = 0
$n = Send-AvisoEsperaSuelta
Comp 'al volver salen los dos' ($n -eq 2) "$n"
Comp 'y la cola queda vacia' (@(Get-AvisoEspera).Count -eq 0) "$(@(Get-AvisoEspera).Count)"
Comp 'y AHORA si se marcan como vistos' ($script:entornoVistos.Count -eq 2) "$($script:entornoVistos.Count)"
Send-AvisoCola $true
Comp 'y se dicen en UNA sola frase' ($script:dichos.Count -eq 1) "$($script:dichos -join ' | ')"
Comp 'con las dos cosas dentro' ($script:dichos[0] -match 'ruido' -and $script:dichos[0] -match 'disco') "$($script:dichos[0])"

Write-Host ''
Write-Host '-- 7. la cola tiene plazo, o seria un modo sin salida --'
Limpia
$script:ausenciaMin = 45
[void](Send-AvisoEntorno 'oido-ruido' 'Hay mucho ruido' 'medio' 60)
# se envejece el aparcado: 130 minutos, por encima de los 120
$script:avisoEspera[0].vence = (Get-Date).AddMinutes(-10).ToString('s')
Save-AvisoEspera
$script:ausenciaMin = 0
$n2 = Send-AvisoEsperaSuelta
Comp 'un aviso de hace mas de dos horas no se dice' ($n2 -eq 0 -and $script:dichos.Count -eq 0) "$n2"
Comp 'se tira, y se apunta que se tiro' (@($script:apuntes | Where-Object { $_ -match 'aviso-caducado' }).Count -eq 1) "$($script:apuntes -join ' ')"
Comp 'y queda en el log' (@($script:logs | Where-Object { $_ -match 'caducado sin decirse' }).Count -eq 1) ''
Comp 'y la cola queda limpia' (@(Get-AvisoEspera).Count -eq 0) "$(@(Get-AvisoEspera).Count)"
Comp 'el plazo son dos horas, del 56 % de las esperas medidas' ($AvisoEsperaCaducaMin -eq 120) "$AvisoEsperaCaducaMin min"
Comp 'y el umbral de ausencia es el del parte de la manana' ($AvisoEsperaMin -eq 30) "$AvisoEsperaMin min"

Write-Host ''
Write-Host '-- 8. de la misma cosa, uno solo --'
Limpia
$script:ausenciaMin = 45
[void](Send-AvisoEntorno 'oido-ruido' 'Hay ruido' 'medio' 60)
[void](Send-AvisoEntorno 'oido-ruido' 'Hay MUCHO ruido' 'medio' 60)
Comp 'dos veces la misma clave dejan una' (@(Get-AvisoEspera).Count -eq 1) "$(@(Get-AvisoEspera).Count)"
Comp 'y se queda el texto del ultimo' (@(Get-AvisoEspera)[0].texto -eq 'Hay MUCHO ruido') "$(@(Get-AvisoEspera)[0].texto)"

Write-Host ''
Write-Host '-- 9. la cola sobrevive al reinicio --'
# Con una mediana de sesion de 5,8 minutos, esto no es un detalle.
Limpia
$script:ausenciaMin = 45
[void](Send-AvisoEntorno 'gmail-lleno' 'El correo esta lleno' 'medio' 10080)
$script:avisoEspera.Clear()      # como si Nova se reiniciara
Comp 'se relee del disco' (@(Get-AvisoEspera).Count -eq 1) "$(@(Get-AvisoEspera).Count)"
Comp 'con su clave' (@(Get-AvisoEspera)[0].clave -eq 'gmail-lleno') "$(@(Get-AvisoEspera)[0].clave)"
Comp 'y con su plazo (una semana, si es gmail)' ([int]@(Get-AvisoEspera)[0].cada -eq 10080) "$(@(Get-AvisoEspera)[0].cada)"

Write-Host ''
Write-Host '-- 10. las dos salidas estan puestas donde tienen que estar --'
$w = SinComentarios ([regex]::Match($fuente, '(?s)function Watch-Entorno.*?\n\}\r?\n').Value)
# la llamada PELADA, sin el $true: la otra solo caduca, no suelta nada
Comp 'coger el mando suelta la cola' ($w -match 'Send-AvisoEsperaSuelta\) \} catch \{ Log') 'sin decir una palabra'
Comp 'y el bloque de 30 s caduca lo viejo' ($w -match 'Send-AvisoEsperaSuelta \(Get-Date\) \$true') 'aunque no vuelva nunca'
$pat = [regex]::Match($fuente, "(?m)^\s*if \(\`$f -match '(\^\(\?:que me he perdido.+?)'\) \{").Groups[1].Value
if (-not $pat) { Write-Host '  MAL  no encuentro el patron de "que me he perdido"'; exit 1 }
$bienP = 0
foreach ($fr in @('que me he perdido', 'me he perdido algo', 'que ha pasado mientras no estaba',
                  'tenias algo que decirme', 'que tenias que decirme', 'algo nuevo',
                  'sueltalo', 'suelta lo que tengas', 'dime lo que tengas', 'cuentame lo que tengas')) {
    if ($fr -match $pat) { $bienP++ } else { Write-Host "       no entra: '$fr'" }
}
Comp 'y las diez formas de pedirlo entran' ($bienP -eq 10) "$bienP de 10"
Comp 'pero "vuelve a avisarme del juego" sigue siendo del juego' ('vuelve a avisarme del juego' -notmatch $pat) 'el interruptor general gana'

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
Write-Host '-- y el que no cabe ahora NO se pierde --'
# Estos avisos existen justamente porque Nova prometio decirlos cuando braya volviera. La cola
# se vaciaba y se guardaba ANTES de intentar soltarlos, asi que el que el freno de mano
# rechazara por el tope de cuatro por hora se perdia del todo: ni se decia ni volvia.
Limpia
for ($i = 1; $i -le 6; $i++) { [void](Add-AvisoEspera "clave$i" "aviso numero $i" 'medio' 60) }
Comp 'seis avisos esperando' (@(Get-AvisoEspera).Count -eq 6) "$(@(Get-AvisoEspera).Count)"
$script:tope = 4; $script:soltados = 0    # el freno deja pasar cuatro y para
$n = Send-AvisoEsperaSuelta
Comp 'salen cuatro' ($n -eq 4) "$n"
Comp 'y los otros dos siguen esperando' (@(Get-AvisoEspera).Count -eq 2) "$(@(Get-AvisoEspera).Count)"
$script:tope = 99; $script:soltados = 0
$n2 = Send-AvisoEsperaSuelta
Comp 'y salen en cuanto cabe' ($n2 -eq 2) "$n2"
Comp 'y ya no queda ninguno' (@(Get-AvisoEspera).Count -eq 0) ''

Write-Host ''
Write-Host '-- y no escribe una linea cada 30 s mientras dura la ausencia --'
# LO QUE PASO EL 24/09: Watch-Entorno repasa cada 30 s, y con la consola sola los mismos tres
# avisos volvian a aparcarse en cada vuelta escribiendo cada uno su linea Y guardando el
# fichero. 2.848 de las 3.448 lineas del registro de ese dia -el 82,6 %- eran eso: 300 por
# hora, unas 7.200 al dia sin que nadie tocara la consola. El banco estaba verde: la cola
# nunca crecio de tamano, que era lo unico que miraba.
Limpia
$primera = Add-AvisoEspera 'disco-poco' 'te quedan 12 gigas' 'medio' 60
Comp 'la primera vez dice que es nueva' ($primera -eq $true) "$primera"
$rep = 0
for ($i = 1; $i -le 120; $i++) { if (Add-AvisoEspera 'disco-poco' 'te quedan 12 gigas' 'medio' 60) { $rep++ } }
Comp 'y las 120 vueltas siguientes, ninguna' ($rep -eq 0) "$rep de 120 habrian escrito una linea"
Comp 'y la cola sigue con uno solo' (@(Get-AvisoEspera).Count -eq 1) "$(@(Get-AvisoEspera).Count)"

# PERO SI CAMBIA EL TEXTO, SI: son el mismo aviso y no dicen lo mismo. Que el disco pase de
# 12 a 4 gigas mientras no hay nadie es justo lo que hay que poder leer luego en el registro.
$cambio = Add-AvisoEspera 'disco-poco' 'te quedan 4 gigas' 'medio' 60
Comp 'si cambia el texto, vuelve a decir que es nueva' ($cambio -eq $true) "$cambio"
Comp 'y la cola se queda con el texto nuevo' ((@(Get-AvisoEspera))[0].texto -eq 'te quedan 4 gigas') "$((@(Get-AvisoEspera))[0].texto)"
$subeNivel = Add-AvisoEspera 'disco-poco' 'te quedan 4 gigas' 'alto' 60
Comp 'y si sube de nivel, tambien' ($subeNivel -eq $true) "$subeNivel"

# Y EL PLAZO SE REFRESCA AUNQUE NO SE APUNTE: el aviso sigue siendo verdad ahora mismo, asi
# que no puede caducar por llevar rato repitiendose. Si esto se rompiera, el aviso se tiraria
# solo a los $AvisoEsperaCaducaMin minutos justo cuando mas seguro es que sigue pasando.
Limpia
$hace = (Get-Date).AddMinutes(-($AvisoEsperaCaducaMin - 1))
[void](Add-AvisoEspera 'oido-ruido' 'hay mucho ruido' 'medio' 60 $hace)
[void](Add-AvisoEspera 'oido-ruido' 'hay mucho ruido' 'medio' 60 (Get-Date))
$v = [datetime]((@(Get-AvisoEspera))[0].vence)
Comp 'el plazo se refresca aunque la linea no se repita' ($v -gt (Get-Date).AddMinutes($AvisoEsperaCaducaMin - 2)) "vence $($v.ToString('HH:mm'))"

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya no le habla a una habitacion vacia'
exit 0
