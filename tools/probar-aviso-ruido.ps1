# QUE NOVA DIGA QUE NO TE OYE, EN VEZ DE CALLARSE (22/09, idea 5).
#
# La madrugada del 22, a las 01:18:40, empezo a sonar algo constante y la puerta de energia
# subio a 0,1264, a un 2 % de lo que valdria la voz de braya en esa habitacion (0,1294). No se
# puede afirmar que se quedara sorda, porque dejo de hablarle justo antes y no hubo ni un
# intento despues. Lo que si es seguro es que en 34 minutos Nova no DIJO que estaba oyendo
# ruido de fondo, y desde fuera eso es identico a funcionar bien. El arreglo de fondo esta en
# wake_vosk.py -la puerta ya no puede pasar de la rafaga mas floja con la que se le ha oido- y
# se prueba en tools\probar-no-sorda.py. Esto prueba la otra mitad: que lo DIGA.
#
# Lo que se puede estropear sin querer y por eso esta aqui:
#   - que el quinto campo se lea por indice y un worker viejo (cuatro campos) reviente la
#     lectura o, peor, se lea como si hubiera ruido siempre;
#   - que el aviso deje de ir por Send-AvisoEntorno y se salte el silencio de la noche;
#   - que se convierta en un aviso cada minuto, que es justo lo que braya no aguanta.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA DEL BANCO (van trece): toda funcion que se llame aqui TIENE que estar en esta lista,
# o la prueba corre contra el vacio y sale verde con el codigo roto. La seccion 7 de
# probar-todo.ps1 lo caza, pero mejor no darle trabajo.
# Test-EstadoFresco entra el 22/09: desde ese dia Get-OidoConRuido la llama por dentro para
# no contestar con la medicion del worker ANTERIOR (escucha-estado.txt no lo borra nadie, y
# tras un arranque tarda 16 s de mediana en refrescarse). Sin traerla, este banco muere a la
# primera con CommandNotFoundException, que es exactamente como lo cazo la bateria.
foreach ($fn in @('Test-EstadoFresco', 'Get-OidoConRuido', 'Test-AvisarRuido')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ ({{].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

# Test-AvisarRuido llama a Log cuando se rearma (solo escribe una linea en assistant.log, no
# decide nada). Se pone un sustituto que la guarda, para poder comprobar que ese rearme queda
# dicho: sin log, un aviso que se rearma solo es invisible desde fuera.
$script:dicho = New-Object System.Collections.ArrayList
function Log([string]$m) { [void]$script:dicho.Add($m) }

$base = Join-Path ([System.IO.Path]::GetTempPath()) ('ruido-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$RutaEstado = Join-Path $base 'escucha-estado.txt'

# El liston de frescura sale del fichero real, no escrito aqui: si algun dia cambia, este
# banco lo sigue solo.
$mMax = [regex]::Match($fuente, "(?m)^\`$EstadoMaxSegundos = (\d+)")
$EstadoMaxSegundos = if ($mMax.Success) { [int]$mMax.Groups[1].Value } else { 45 }

function Pon([string]$linea) { [System.IO.File]::WriteAllText($RutaEstado, $linea) }

Write-Host ''
Write-Host '-- el quinto campo dice si lo que entra es ruido --'
Pon '2.6|0.1323|0.000|60|1'
Comp 'con ruido constante, lo sabe' (Get-OidoConRuido) 'la linea que habria escrito a las 01:50'
# Y NO CON LA MEDICION DEL WORKER MUERTO (22/09). escucha-estado.txt no lo borra nadie, asi
# que tras reiniciar la escucha lo que hay ahi es del worker anterior hasta que el nuevo
# escribe su primer pulso: 16 s de mediana, 46 s en el p90, y el 14 % tarda mas de 30 s.
# Este aviso no ejecuta ninguna orden, pero le haria decir a Nova que le esta entrando un
# ruido que se fue con el proceso de antes.
(Get-Item $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-($EstadoMaxSegundos + 15))
Comp 'pero con el estado rancio se calla' (-not (Get-OidoConRuido)) "mas de $EstadoMaxSegundos s"
(Get-Item $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-($EstadoMaxSegundos - 10))
Comp 'y uno de hace un momento sigue valiendo' (Get-OidoConRuido) 'no se tiran los buenos'
Pon '15.5|0.0210|0.000|6|0'
Comp 'hablando de verdad, no se queja' (-not (Get-OidoConRuido)) 'la de las 01:17, cuando le oia bien'

Write-Host ''
Write-Host '-- y no revienta con lo que no espera --'
# EL CASO DE VERDAD: justo despues de actualizar, el asistente es nuevo y el worker que esta
# en marcha todavia es el viejo, con cuatro campos. Tiene que decir "no hay ruido", nunca
# fallar y nunca inventarse un si.
Pon '15.5|0.0210|0.000|6'
Comp 'un worker viejo (cuatro campos) no da falso positivo' (-not (Get-OidoConRuido)) 'ni excepcion'
Pon ''
Comp 'un fichero vacio tampoco' (-not (Get-OidoConRuido))
Pon 'esto no es un estado'
Comp 'una linea con basura tampoco' (-not (Get-OidoConRuido))
Pon '2.6|0.13|0.000|60|'
Comp 'el quinto campo vacio es no' (-not (Get-OidoConRuido))
Pon '2.6|0.13|0.000|60|1|algo|mas'
Comp 'campos de mas (una version futura) se leen igual' (Get-OidoConRuido)
Remove-Item -LiteralPath $RutaEstado -Force -ErrorAction SilentlyContinue
Comp 'sin fichero, no hay ruido que avisar' (-not (Get-OidoConRuido))

Write-Host ''
Write-Host '-- el worker escribe ese campo, o lo de arriba no sirve de nada --'
Comp 'el worker arma el estado en un solo sitio' ($oido -match 'def decir_estado\(') ''
Comp 'y el quinto campo es el del ruido' ($oido -match 'ruido_de_fuera = pulsos_ruidosos >= RUIDO_PULSOS')
# LO QUE SONABA POR LOS ALTAVOCES NO ES RUIDO QUE BRAYA TENGA QUE QUITAR (22/09 noche). El
# detector solo mira si casi todos los bloques pasan la puerta, y la musica, un video, un
# juego o la propia voz de Nova los pasan igual que un ventilador. Medido el 22/09 a las
# 20:57-20:59: con musica a 0,23-0,58 de nivel de salida entraban 41-56 bloques de 60, y el
# liston del ruido son 55. Si esto se cae, Nova vuelve a decirle que quite un ruido que ha
# puesto el.
Comp 'y los altavoces no cuentan como ruido' ($oido -match 'ruido_de_fuera = pulsos_ruidosos >= RUIDO_PULSOS and salida <= UMBRAL_ALTAVOZ') 'la musica no es un ventilador'
# decir_estado escribe el campo de los altavoces Y decide el del ruido con el mismo numero:
# si se midiera dos veces, podrian contradecirse dentro de la misma linea.
$dEstado = [regex]::Match($oido, '(?ms)^def decir_estado\(.*?
(?=\S)').Value
Comp 'el nivel de salida se mide una vez por linea' (([regex]::Matches($dEstado, 'nivel_salida\(\)')).Count -eq 1)
# Y EL PULSO LO DEJA ESCRITO, o manana no se puede contar cuantos eran altavoces.
Comp 'el pulso de ruido apunta los altavoces' ($oido -match 'seguidos, altavoces %\.3f')
Comp 'nadie lo escribe ya a mano' (-not ($oido -match 'escribir\(RUTA_ESTADO, "%'))
# el orden importa: los campos 0 a 3 tienen que seguir donde estaban.
# EL REGEX ERA CERRADO Y LA LINEA PUEDE CRECER (24/09): decir_estado dice en su propio
# comentario que los campos nuevos se anaden AL FINAL para que el asistente viejo siga
# leyendo lo mismo, y el 24/09 llego el sexto (la racha de descartes por flojo). Con la
# comilla final pegada al quinto, cumplir ese diseno ponia este banco rojo. Ahora se mira
# el PREFIJO -que es lo que de verdad protege a los lectores por indice- y ademas que el
# quinto siga siendo el del ruido, que es lo unico que el tipo %d no distingue por si solo.
Comp 'la ganancia sigue siendo el campo 0' ($oido -match 'return "%\.1f\|%s\|%\.3f\|%d\|%d')
Comp 'y el ruido sigue siendo el quinto' ($oido -match 'bloques_voz, 1 if ruido_de_fuera else 0') 'los dos son %d: el tipo no los separa'

Write-Host ''
Write-Host '-- el aviso respeta las reglas de braya --'
# Send-AvisoEntorno es quien aplica el limite por hora, el silencio de la noche (de 23:00 a
# 8:00 solo pasa lo 'alto') y el modo juego. Si el aviso dejara de ir por ahi, sonaria de
# madrugada, que es exactamente cuando paso esto.
# El bloque entero del aviso, desde que lee el rearme hasta el catch. Antes se anclaba en
# "if (Get-OidoConRuido) {", que dejo de existir al meter la guarda de episodio.
$m = [regex]::Match($fuente, '(?ms)\$rearmeR = .*?\} catch \{\}')
Comp 'el aviso existe y va por Send-AvisoEntorno' ($m.Success -and $m.Value -match 'Send-AvisoEntorno') ''
Comp "con nivel 'medio', que de noche NO pasa" ($m.Value -match "'medio'") 'asi no te despierta'
$cada = [regex]::Match($m.Value, "'medio'\s+(\d+)")
Comp 'el reloj, de red de seguridad y ancho' ($cada.Success -and [int]$cada.Groups[1].Value -ge 60) ("cada $($cada.Groups[1].Value) min")
# LO QUE FALLO EL PRIMER DIA (22/09): con 30 minutos de reposo salieron 25 avisos identicos
# entre las 08:00 y las 20:20. El limite de verdad tiene que ser el episodio, no el reloj.
Comp 'y el que manda es el episodio, no el reloj' ($m.Value -match 'Test-AvisarRuido') 'la guarda de idempotencia'
Comp "el 'ya lo dije' solo se apunta si el aviso salio" ($m.Value -match '(?s)if \(Send-AvisoEntorno.*?\$script:ruidoAvisado = \$true') 'si lo para la noche, se reintenta'
Comp 'dice que hacer, no solo que pasa' ($m.Value -match 'quitalo o acercame')
# NO es un modo que se queda activo: braya los rechaza. Solo avisa.
Comp 'no enciende ningun modo ni cambia nada' (-not ($m.Value -match 'Set-|\$script:modo|config'))

Write-Host ''
Write-Host '-- una vez por episodio: el dia del 22/09, en un milisegundo --'
# El bucle de entorno mira esto cada 30 s. Aqui se corren 12 horas de ruido constante -las
# mismas que produjeron los 25 avisos- y se cuenta cuantas veces habria hablado.
$MIN = 60000
$REARME = 15 * $MIN
$script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
$veces = 0
for ($t = 0; $t -le (12 * 60 * $MIN); $t += 30000) {
    if (Test-AvisarRuido $true $t $REARME) { $veces++; $script:ruidoAvisado = $true }
}
Comp '12 h de ruido seguido: lo dice una vez' ($veces -eq 1) "$veces aviso(s), antes 25"

# Y EL REARME. Si el ruido se va y vuelve, es otro episodio y hay que decirlo otra vez: el
# aviso no puede quedarse mudo para siempre, que seria el fallo contrario.
$script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
$t = 0
$primera = Test-AvisarRuido $true $t $REARME
if ($primera) { $script:ruidoAvisado = $true }
$t += 30000
# el ruido para, pero solo diez minutos: todavia es el mismo episodio
$corto = $false
for ($i = 0; $i -lt 20; $i++) { $t += 30000; [void](Test-AvisarRuido $false $t $REARME) }
$corto = Test-AvisarRuido $true $t $REARME
Comp 'diez minutos de calma no son un episodio nuevo' (-not $corto) 'sigue callada'
# ahora si: veinte minutos limpios
$script:ruidoLimpioDesde = 0
for ($i = 0; $i -lt 40; $i++) { $t += 30000; [void](Test-AvisarRuido $false $t $REARME) }
Comp 'y el rearme queda dicho en el log' (@($script:dicho | Where-Object { $_ -match 'se rearma' }).Count -eq 1)
$vuelve = Test-AvisarRuido $true $t $REARME
Comp 'pero veinte si: el ruido que vuelve se dice' $vuelve 'otro episodio'

# LA MITAD QUE SE ME OLVIDABA: si el aviso NO sale (de noche, o jugando), Send-AvisoEntorno
# devuelve falso y nadie apunta el 'ya lo dije'. Tiene que seguir pidiendolo.
$script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
$pide = 0
for ($i = 0; $i -lt 10; $i++) { if (Test-AvisarRuido $true ($i * 30000) $REARME) { $pide++ } }
Comp 'si la noche lo bloquea, lo sigue pidiendo' ($pide -eq 10) 'el que calla es Send-AvisoEntorno'

Write-Host ''
Write-Host '-- y si le preguntas como te oye, tambien lo dice --'
# ANCLADO A estadoEscucha: '$partes = @()' sale en varios sitios de assistant.ps1 y Match
# cogia el primero, que es otro. Y comillas SIMPLES, que entre dobles PowerShell se come
# el $ antes de que llegue al regex.
$e = [regex]::Match($fuente, '(?ms)''estadoEscucha'' \{.{0,1800}')
Comp 'estadoEscucha lo menciona' ($e.Value -match 'ruido de fondo constante')
Comp 'y lo primero, que es lo que mas explica' ($e.Value.IndexOf('ruido de fondo') -lt $e.Value.IndexOf('pausaHasta'))

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  Nova dice cuando el ruido le tapa la voz'
exit 0
