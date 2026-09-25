# LOS 109 MINUTOS DE MICROFONO QUE SE TIRAN A LA BASURA (24/09).
#
# LA MEDICION, contada sobre assistant.log.1 (el log de hoy, assistant.log, no tiene ni uno;
# los 1.116 estan todos en el anterior, del 09/09 al 23/09):
#   1.116 lineas "descartados N s de audio atrasado". Sumadas, 6.563,6 segundos: 109 minutos
#   de microfono a la basura en once dias. Por motivo, y cuadra con las 1.116:
#     transcripcion 604, oido fino 478, corte a mano 14, canary 10, fin de pausa 7, omni 3.
#   El descarte mas pequeno es 0,8 s, la mediana 2,5 s y el mas grande 238,8 s -casi cuatro
#   minutos seguidos-. 292 pasan de 5 s, 124 de 10 s, 37 de 30 s y 10 de un minuto. Y los
#   1.116 valores son multiplos exactos de 0,25: ni uno se sale.
#
# POR QUE SE TIRA. Transcribir bloquea el hilo del oido 10-40 s y el microfono no se para:
# la cola se llena de audio viejo. Al volver al bucle se decodificaba todo ese rato de golpe
# y a maxima velocidad con el reconocedor de la palabra de activacion, o sea que Nova se
# "activaba" con su propia voz y con conversacion de hace medio minuto. Eso es la regla 1 al
# reves: ejecutar algo que nadie acaba de pedir.
#
# LA PREGUNTA QUE DECIDE ESTE BANCO: si el descarte fallara, que se pierde en cada direccion.
#   - SI DESCARTA DE MENOS (se cae una llamada), vuelven las activaciones fantasma, y con
#     ellas ordenes que braya no ha dicho. Lo peor que puede pasar.
#   - SI DESCARTA DE MAS, se come una orden de braya. Y aqui esta el dato que tranquiliza:
#     de los 478 descartes por "oido fino" hay 478 parejas en el registro con el segundo que
#     tardo el modelo justo antes. El descarte mide LO MISMO que el bloqueo: mediana de la
#     razon 0,96, y 423 de las 478 (88 %) caen a menos de un segundo del bloqueo. O sea que
#     lo que se tira es exactamente la ventana en la que el oido estaba sordo, nunca audio
#     vivo. Ese es el limite que este banco vigila: que vaciar_cola tire lo que hay AHORA y
#     ni un bloque de lo que llegue despues, y que no se llame cuando no toca.
#
# Y TODO SE EJECUTA. vaciar_cola y atender_reintento se sacan en caliente de wake_vosk.py y
# se corren de verdad, con una cola de mentira que se llena mientras el modelo "trabaja".
# Solo las tres ultimas comprobaciones miran texto, porque son sitios del bucle grande de
# wake_vosk.py que no se pueden arrancar sueltos.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PowerShell 5.1 con -File sale con codigo 0 aunque el
# script muera a mitad, y un banco muerto se daba por bueno.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaOido = Join-Path $raiz 'wake_vosk.py'
# Los finales de linea a LF antes de nada: wake_vosk.py se guarda con CRLF y los patrones de
# aqui abajo anclan al final de linea. Sin esto no encontraria ni una sola funcion.
$oido = ([System.IO.File]::ReadAllText($rutaOido)) -replace "`r`n", "`n"

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# Los comentarios fuera ANTES de mirar texto. Ya ha pasado tres veces que un comentario con
# la palabra buscada dentro dejara invisible una rotura de verdad.
$sinCom = (($oido -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")

function Sacar([string]$nombre, [string]$patron) {
    $m = [regex]::Match($oido, $patron)
    if (-not $m.Success) { Write-Host "  MAL  no encuentro $nombre en wake_vosk.py"; exit 1 }
    return $m.Value
}

Write-Host ''
Write-Host '-- 1. LOS 0,25 SEGUNDOS POR BLOQUE no son un numero puesto a mano --'
# El registro cuenta segundos multiplicando bloques por 0,25, y ese 0,25 sale de dividir el
# tamano del bloque del microfono entre la frecuencia. Si alguien toca el blocksize y se
# olvida del 0,25, el registro sigue verde MINTIENDO: diria la mitad o el doble de segundos
# de los que se tiran, y la medicion de arriba -las 478 parejas- dejaria de cuadrar sin que
# nadie se enterara. Por eso se comparan los tres numeros entre si y no se copia ninguno.
$mTasa = [regex]::Match($oido, '(?m)^TASA = (\d+)')
$mBloq = [regex]::Match($oido, 'sd\.RawInputStream\(samplerate=TASA, blocksize=(\d+)')
Comp 'TASA sigue declarada' $mTasa.Success
Comp 'y el microfono sigue abriendose con un blocksize' $mBloq.Success
if (-not ($mTasa.Success -and $mBloq.Success)) { Write-Host '  el oido cambio de forma'; exit 1 }
$TASA = [int]$mTasa.Groups[1].Value
$bloque = [int]$mBloq.Groups[1].Value
$porBloque = [double]$bloque / $TASA
Comp "un bloque dura $porBloque s ($bloque muestras a $TASA Hz)" ($porBloque -eq 0.25) "$porBloque"
Comp 'y vaciar_cola cuenta con ese mismo 0,25' ($sinCom -match 'n \* 0\.25') 'si no, el registro miente en segundos'
# Los 1.116 valores del registro son multiplos de 0,25 y el mas pequeno es 0,8 (tres
# bloques): eso demuestra que el liston de abajo es "mas de 2", no otro.
Comp 'y solo se apunta a partir de tres bloques' ($sinCom -match 'if n > 2:\s*\n\s*anota\("descartados') 'el minimo del registro es 0,8 s = 3 bloques'

# --- se preparan el sitio de pruebas y el banco de python ---
$sitio = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-atrasado-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $sitio | Out-Null
try {
    $fnVaciar = Sacar 'vaciar_cola' '(?ms)^def vaciar_cola\(motivo\):.*?^    return n$'
    $fnAtender = Sacar 'atender_reintento' '(?ms)^def atender_reintento\(ultimo_audio\):.*?^    return True$'
    $mRepaso = [regex]::Match($oido, '(?m)^REPASO_MAX = ([\d.]+)')
    $mRepasoB = [regex]::Match($oido, '(?m)^REPASO_MAX_BASE = ([\d.]+)')
    Comp 'REPASO_MAX y REPASO_MAX_BASE siguen ahi' ($mRepaso.Success -and $mRepasoB.Success) `
        "$($mRepaso.Groups[1].Value) s y $($mRepasoB.Groups[1].Value) s"
    if (-not ($mRepaso.Success -and $mRepasoB.Success)) { exit 1 }

    $plantilla = @'
# -*- coding: utf-8 -*-
# Generado por probar-audio-atrasado.ps1. Las dos funciones de abajo son las de
# wake_vosk.py, sacadas EN CALIENTE de ese fichero, no escritas aqui.
import io
import json
import os
import queue
import sys
import threading
import time

SITIO = sys.argv[1]
registro = []


def anota(mensaje):
    registro.append(mensaje)


cola = queue.Queue()

__VACIAR__

# --- lo que atender_reintento necesita, todo de mentira menos ella misma ---
REINTENTO = os.path.join(SITIO, "reintento.flag")
REINTENTO_TEXTO = os.path.join(SITIO, "reintento.txt")
TASA = __TASA__
REPASO_MAX = __REPASO_MAX__
REPASO_MAX_BASE = __REPASO_MAX_BASE__
MODELO_ULTIMO = "modelo-turbo"
whisper = "modelo-base"


# DESDE EL 24/09 (ideas 14 y 15) Whisper carga en un hilo y el dictado espera con
# esperar_whisper() en vez de mirar "whisper is not None". Aqui ya esta cargado, asi que la
# version de mentira devuelve que si al instante: lo que se prueba en este banco es el vaciado
# de la cola, no la carga -eso tiene el suyo, probar-arranque-oido.py-.
def esperar_whisper():
    return whisper is not None
_uso = {"id": "", "activo": None}
_ultima_seguridad = None
_preciso_uso = 0.0
_ultimo_uso = 0.0
cargados = []
LLEGAN = [0]
REVIENTA = [False]


def mientras_esta_sordo():
    # el microfono no se para mientras el modelo trabaja: la cola se llena de audio viejo
    for _ in range(LLEGAN[0]):
        cola.put(b"bloque")
    if REVIENTA[0]:
        raise RuntimeError("el modelo se cayo")


def modelo_canary():
    cargados.append("canary")
    return "M"


def modelo_omni():
    cargados.append("omni")
    return "M"


def modelo_preciso():
    cargados.append("small")
    return "M"


def modelo_ultimo():
    cargados.append("turbo")
    return "M"


def quitar_nombre(texto):
    return texto


def grabar_uso_activo():
    return False


def apuntar_uso(campos):
    pass


def escribir(ruta, contenido):
    with io.open(ruta, "w", encoding="utf-8") as f:
        f.write(contenido)


def transcribir_sherpa(audio, m):
    mientras_esta_sordo()
    return "lo que oyo sherpa"


def transcribir_whisper(audio, m=None, seguir=None):
    mientras_esta_sordo()
    return "lo que oyo whisper"


__ATENDER__


def limpiar():
    # cola NUEVA en cada caso: si una rotura deja a vaciar_cola esperando para siempre, ese
    # hilo se queda con la cola vieja y no se lleva por delante los casos siguientes.
    global cola
    cola = queue.Queue()
    del registro[:]
    del cargados[:]
    LLEGAN[0] = 0
    REVIENTA[0] = False
    for r in (REINTENTO, REINTENTO_TEXTO):
        if os.path.exists(r):
            os.remove(r)


def vigilar(hacer, limite=8.0):
    # TODO se corre en un hilo con reloj. Un vaciado que se quede esperando audio es la
    # rotura mas cara que hay aqui -el oido sordo para siempre- y sin esto el banco se
    # colgaria con ella en vez de ponerse rojo.
    caja = {}

    def correr():
        try:
            caja["r"] = hacer()
        except Exception as e:
            caja["e"] = str(e)

    h = threading.Thread(target=correr)
    h.daemon = True
    h.start()
    h.join(limite)
    return (not h.is_alive()), caja


salida = []


def caso_cola(nombre, bloques, motivo):
    limpiar()
    for _ in range(bloques):
        cola.put(b"bloque")
    termino, caja = vigilar(lambda: vaciar_cola(motivo))
    salida.append(dict(nombre=nombre, termino=termino, n=caja.get("r", -1),
                       cola=cola.qsize(), registro=list(registro)))


def caso(nombre, pedido, segundos, llegan, revienta=False, ya=0, sin_marca=False):
    limpiar()
    if not sin_marca:
        escribir(REINTENTO, pedido)
    LLEGAN[0] = llegan
    REVIENTA[0] = revienta
    for _ in range(ya):
        cola.put(b"bloque")
    audio = [[0] * int(round(segundos * TASA))] if segundos > 0 else []
    termino, caja = vigilar(lambda: atender_reintento(audio))
    texto = None
    if os.path.exists(REINTENTO_TEXTO):
        texto = io.open(REINTENTO_TEXTO, encoding="utf-8").read()
    salida.append(dict(nombre=nombre, termino=termino, devuelto=bool(caja.get("r")),
                       cola=cola.qsize(), marca=os.path.exists(REINTENTO), texto=texto,
                       cargados=list(cargados), registro=list(registro)))


caso_cola("cola vacia", 0, "prueba")
caso_cola("un bloque", 1, "prueba")
caso_cola("dos bloques", 2, "prueba")
caso_cola("tres bloques", 3, "prueba")
caso_cola("diez bloques", 10, "prueba")
caso_cola("el mayor del registro", 955, "prueba")

# lo que llega DESPUES de vaciar sigue ahi: no se lleva por delante audio vivo
limpiar()
for _ in range(6):
    cola.put(b"bloque")
termino, caja = vigilar(lambda: vaciar_cola("prueba"))
for _ in range(4):
    cola.put(b"bloque")
salida.append(dict(nombre="lo de despues se queda", termino=termino,
                   n=caja.get("r", -1), cola=cola.qsize()))

caso("canary", "canary", 1.0, 40)
caso("omni", "omni", 1.0, 12)
caso("base", "base", 1.0, 24)
caso("ultimo recurso", "ultimo", 1.0, 8)
caso("oido fino", "", 1.0, 10)
caso("demasiado largo", "", 19.8, 0, ya=8)
caso("sin audio", "", 0, 0, ya=6)
caso("el modelo revienta", "", 1.0, 16, revienta=True)
caso("sin marca", "", 1.0, 0, ya=8, sin_marca=True)

sys.stdout.write(json.dumps(salida))
'@

    $py = $plantilla.Replace('__VACIAR__', $fnVaciar).Replace('__ATENDER__', $fnAtender)
    $py = $py.Replace('__TASA__', [string]$TASA)
    $py = $py.Replace('__REPASO_MAX__', $mRepaso.Groups[1].Value).Replace('__REPASO_MAX_BASE__', $mRepasoB.Groups[1].Value)

    # SIN PYTHON NO HAY BANCO, Y HAY QUE DECIRLO. Callarse y saltarse las secciones que
    # ejecutan seria pintar de verde justo lo unico que importa aqui.
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host '  MAL  no hay python en el PATH: no puedo ejecutar el descarte de verdad'
        exit 1
    }
    $rutaPy = Join-Path $sitio '_descarte.py'
    [System.IO.File]::WriteAllText($rutaPy, $py, (New-Object System.Text.UTF8Encoding $false))
    $crudo = (& python $rutaPy $sitio) -join ''
    if ($LASTEXITCODE -ne 0 -or -not $crudo) {
        Write-Host "  MAL  el oido no se pudo ejecutar (codigo $LASTEXITCODE): $crudo"
        exit 1
    }
    # SIN @() A PROPOSITO: en PowerShell 5.1, ConvertFrom-Json suelta la lista entera como UN
    # objeto, y @(...) la mete dentro de otra lista de uno. Con foreach directo si se recorre.
    $r = ConvertFrom-Json $crudo
    $porNombre = @{}
    foreach ($c in $r) { $porNombre[[string]$c.nombre] = $c }
    function Caso([string]$n) {
        if (-not $porNombre.ContainsKey($n)) { Write-Host "  MAL  falta el caso $n"; exit 1 }
        return $porNombre[$n]
    }
    # LA COMA DE DELANTE NO SOBRA: 'return' de PowerShell deshace una lista de uno y devuelve
    # la cadena suelta, y entonces $d[0] es la LETRA 'd' en vez de la linea entera. Con eso,
    # las comparaciones de abajo salian rojas por el banco, no por el codigo.
    function Descartes($c) {
        $l = @(@($c.registro) | Where-Object { $_ -like 'descartados*' })
        return ,$l
    }

    Write-Host ''
    Write-Host '-- 2. VACIAR_COLA EJECUTADA: tira todo lo que hay, y lo cuenta bien --'
    # Si dejara un solo bloque sin tirar, ese bloque se decodifica en la siguiente vuelta con
    # el reconocedor de la palabra de activacion. Un "nova" de hace medio minuto vale igual
    # que uno de ahora: Nova se abre sola.
    foreach ($p in @(@('cola vacia', 0), @('un bloque', 1), @('dos bloques', 2),
                     @('tres bloques', 3), @('diez bloques', 10), @('el mayor del registro', 955))) {
        $c = Caso $p[0]
        Comp "$($p[0]): devuelve $($p[1]) y la cola queda vacia" `
            (($c.termino -eq $true) -and ($c.n -eq $p[1]) -and ($c.cola -eq 0)) "n=$($c.n) quedan=$($c.cola) volvio=$($c.termino)"
    }
    # EL LISTON DE TRES, que es lo que dice el registro: el descarte mas pequeno de los 1.116
    # es 0,8 s. Con uno o dos bloques se tira igual pero NO se apunta, porque un cuarto de
    # segundo de cola es lo normal en cada vuelta del bucle y llenaria el registro de ruido.
    Comp 'con 0, 1 y 2 bloques no apunta nada' `
        (((Descartes (Caso 'cola vacia')).Count -eq 0) -and ((Descartes (Caso 'un bloque')).Count -eq 0) -and ((Descartes (Caso 'dos bloques')).Count -eq 0)) ''
    # Los tres numeros de aqui abajo son los del registro tal cual: el minimo (0,8), la
    # mediana (2,5) y el maximo (238,8). Si la cuenta de segundos se rompiera, el registro
    # seguiria saliendo pero diciendo otra cosa, y las 478 parejas dejarian de cuadrar.
    Comp 'tres bloques se apuntan como 0,8 s, el minimo del registro' `
        ((Descartes (Caso 'tres bloques'))[0] -eq 'descartados 0.8 s de audio atrasado (prueba)') "$((Descartes (Caso 'tres bloques'))[0])"
    Comp 'diez bloques como 2,5 s, la mediana de los 1.116' `
        ((Descartes (Caso 'diez bloques'))[0] -eq 'descartados 2.5 s de audio atrasado (prueba)') "$((Descartes (Caso 'diez bloques'))[0])"
    Comp '955 bloques como 238,8 s, el mayor que hay en el registro' `
        ((Descartes (Caso 'el mayor del registro'))[0] -eq 'descartados 238.8 s de audio atrasado (prueba)') "$((Descartes (Caso 'el mayor del registro'))[0])"
    Comp 'y apunta UNA vez, no una por bloque' ((Descartes (Caso 'el mayor del registro')).Count -eq 1) '955 lineas serian el registro entero'

    Write-Host ''
    Write-Host '-- 3. Y NO SE LLEVA POR DELANTE AUDIO VIVO --'
    # Este es el lado que se come una orden de braya. vaciar_cola tiene que tirar lo que hay
    # EN ESE INSTANTE y volver. Si esperara a que llegue mas -un get() sin nowait, un
    # timeout- el hilo del oido se quedaria ahi colgado y Nova se queda sorda del todo, sin
    # una linea en el registro que lo cuente. Por eso se corre en un hilo aparte y se mira
    # si vuelve.
    $col = Caso 'cola vacia'
    Comp 'con la cola vacia vuelve enseguida en vez de esperar' ($col.termino -eq $true) 'si no, el oido se cuelga y Nova se queda sorda del todo'
    Comp 'y devuelve cero sin apuntar nada' (($col.n -eq 0) -and ((Descartes $col).Count -eq 0)) "$($col.n)"
    $desp = Caso 'lo de despues se queda'
    Comp 'lo que entra por el microfono DESPUES sigue en la cola' (($desp.termino -eq $true) -and ($desp.cola -eq 4)) "quedan $($desp.cola) de 4"

    Write-Host ''
    Write-Host '-- 4. LOS OCHO CAMINOS DEL OIDO FINO, y los ocho vacian la cola --'
    # atender_reintento se llama en cada vuelta del bucle. Cuando el asistente pide repaso,
    # bloquea el hilo mientras carga y corre un modelo, y al terminar TIENE que vaciar.
    # El comentario del codigo lo dice con todas las letras: ni return ni break, porque si
    # un camino se salta el final, el asistente se queda esperando un repaso que no llega,
    # la marca sin borrar, y la cola llena de audio viejo listo para activarla sola.
    $caminos = @(
        @{ n = 'canary';            s = 10.0;  m = 'canary';    mod = 'canary' },
        @{ n = 'omni';              s = 3.0;   m = 'omni';      mod = 'omni' },
        @{ n = 'base';              s = 6.0;   m = 'oido fino'; mod = '' },
        @{ n = 'ultimo recurso';    s = 2.0;   m = 'oido fino'; mod = 'turbo' },
        @{ n = 'oido fino';         s = 2.5;   m = 'oido fino'; mod = 'small' },
        @{ n = 'demasiado largo';   s = 2.0;   m = 'oido fino'; mod = '' },
        @{ n = 'sin audio';         s = 1.5;   m = 'oido fino'; mod = 'small' },
        @{ n = 'el modelo revienta'; s = 4.0;  m = 'oido fino'; mod = 'small' }
    )
    foreach ($k in $caminos) {
        $c = Caso $k.n
        $d = Descartes $c
        $esperada = ('descartados {0} s de audio atrasado ({1})' -f $k.s.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture), $k.m)
        Comp ("$($k.n): vuelve y la cola queda vacia") (($c.termino -eq $true) -and ($c.cola -eq 0)) "quedan $($c.cola) volvio=$($c.termino)"
        Comp ("   y lo apunta como '$esperada'") (($d.Count -eq 1) -and ($d[0] -eq $esperada)) "$($d -join ' | ')"
        Comp ("   contesta al asistente y borra la marca") (($null -ne $c.texto) -and (-not $c.marca) -and $c.devuelto) `
            "texto=$($null -ne $c.texto) marca=$($c.marca)"
    }
    # DOS DETALLES QUE SE ESCAPAN SOLOS. El del canary: su rama sale con return, asi que
    # tiene que vaciar UNA vez; si a alguien se le va ese return, cargaria ademas un segundo
    # modelo y vaciaria dos veces. Y el del audio largo: los 23 "demasiado para repasar" del
    # registro -19,8 s y 30,2 s el 13/09, tope 8 s- NO cargan modelo, y aun asi 10 de ellos
    # apuntaron su descarte justo detras (2,0 s a las 16:15:25). Vaciar no depende de haber
    # transcrito.
    Comp 'el canary carga un modelo y solo uno' ((@((Caso 'canary').cargados) -join ',') -eq 'canary') "$(@((Caso 'canary').cargados) -join ',')"
    $cL = Caso 'demasiado largo'
    Comp 'con audio de 19,8 s no carga ningun modelo' ((@($cL.cargados)).Count -eq 0) "$(@($cL.cargados) -join ',')"
    Comp 'y aun asi vacia (el caso real del 13/09 a las 16:15)' ((Descartes $cL).Count -eq 1) ''
    Comp '   y lo dice con el tope de verdad' ((@($cL.registro) -join ' ') -like '*19.8 s de audio es demasiado para repasar (tope 8 s)*') ''
    $cR = Caso 'el modelo revienta'
    Comp 'si el modelo se cae, avisa' ((@($cR.registro) -join ' ') -like '*WARN: fallo el oido fino*') ''
    Comp '   y vacia igual: el hilo estuvo sordo lo mismo' ((Descartes $cR).Count -eq 1) 'vaciar dentro del try seria el fallo'
    Comp '   y contesta vacio en vez de dejar al asistente esperando' ($cR.texto -eq '') "'$($cR.texto)'"

    Write-Host ''
    Write-Host '-- 5. SIN QUE SE LO PIDAN NO TOCA LA COLA --'
    # atender_reintento entra en CADA vuelta del bucle, treinta veces por segundo. Si vaciara
    # sin mirar la marca, se comeria la orden de braya mientras la esta diciendo y Nova se
    # quedaria sorda para siempre sin una sola linea en el registro. Es la rotura mas cara
    # de las que este banco puede ver.
    $sm = Caso 'sin marca'
    Comp 'sin reintento.flag contesta que no hay nada que hacer' (($sm.termino -eq $true) -and ($sm.devuelto -eq $false)) "$($sm.devuelto)"
    Comp 'y deja los 8 bloques de audio donde estaban' ($sm.cola -eq 8) "quedan $($sm.cola) de 8"
    Comp 'y no apunta nada' ((Descartes $sm).Count -eq 0) ''

    Write-Host ''
    Write-Host '-- 6. LOS SITIOS DEL BUCLE, que no se pueden arrancar sueltos --'
    # Aqui si se mira texto, sin comentarios delante, porque esto vive dentro del bucle
    # grande de wake_vosk.py y no hay forma de correrlo a trozos. Son los sitios donde el
    # hilo se queda sordo: cada uno tiene que vaciar al volver.
    # LA TERCERA RAMA CAMBIO DE NOMBRE EL 24/09 (ideas 14 y 15): era "elif whisper is not
    # None" y ahora es "elif esperar_whisper()", porque Whisper carga en un hilo y ese None
    # puede significar "todavia no". Lo que hace la rama es lo mismo.
    # 604 de los 1.116 descartes son del dictado normal y 14 del boton, y los dos bloques
    # tienen TRES ramas que bloquean el hilo (parakeet, el repaso de ingles, y whisper).
    # La tercera se anadio tarde -el comentario del codigo lo cuenta: "el camino normal ya
    # lo hacia; este, el del boton, no"- y es justo la que se vuelve a olvidar.
    Comp 'el dictado vacia en sus tres ramas' `
        ($sinCom -match 'if rapido:[\s\S]{0,260}vaciar_cola\("transcripcion"\)[\s\S]{0,260}elif mejor:[\s\S]{0,260}vaciar_cola\("transcripcion"\)[\s\S]{0,400}esperar_whisper\(\):[\s\S]{0,300}vaciar_cola\("transcripcion"\)') `
        '604 descartes salen de aqui'
    Comp 'y el corte a mano tambien en las suyas' `
        ($sinCom -match 'if rapido:[\s\S]{0,260}vaciar_cola\("corte a mano"\)[\s\S]{0,260}elif mejor:[\s\S]{0,260}vaciar_cola\("corte a mano"\)[\s\S]{0,400}elif esperar_whisper\(\)[\s\S]{0,300}vaciar_cola\("corte a mano"\)') `
        '14 descartes, y esta rama es la que se anadio tarde'
    # 0 de los 1.116 descartes comparten segundo con otro: las ramas son excluyentes de
    # verdad, no se disparan dos a la vez.
    Comp 'y ni una rama de mas' `
        ((([regex]::Matches($sinCom, 'vaciar_cola\("transcripcion"\)')).Count -eq 3) -and (([regex]::Matches($sinCom, 'vaciar_cola\("corte a mano"\)')).Count -eq 3)) `
        'en el registro no hay dos descartes en el mismo segundo'
    # 7 descartes por "fin de pausa": mientras Nova habla se tira el audio sin mirarlo, y al
    # volver hay que vaciar lo encolado o se decodifica su propia voz.
    Comp 'al salir de la pausa vacia antes de nada' ($sinCom -match 'elif pausado:\s*\n\s*pausado = False\s*\n\s*vaciar_cola\("fin de pausa"\)') `
        '7 descartes, y el audio es la voz de Nova'
    # LA GUARDA QUE EVITA COMERSE UNA ORDEN: el repaso solo se pide cuando no hay un dictado
    # ni una confirmacion abiertos. Sin ella, el repaso bloquea varios segundos y al terminar
    # vacia, llevandose por delante la orden que braya esta diciendo AHORA MISMO.
    Comp 'el repaso no se pide con un dictado o una confirmacion abiertos' `
        ($sinCom -match 'if not dictando and not confirmando:\s*\n\s*atender_reintento\(ultimo_audio\)') `
        'si no, el repaso se come la orden que se esta dictando'
    # Entrar en dictado y entrar en confirmacion vacian a mano (sin pasar por vaciar_cola,
    # porque ahi no se quiere linea en el registro): en el dictado, para que el final de
    # "nova" no se transcriba como si fuera la orden; en la confirmacion, para que la propia
    # voz de Nova leyendo la pregunta no le regale el "si".
    Comp 'entrar en dictado y en confirmacion vacian tambien' (([regex]::Matches($sinCom, 'cola\.get_nowait\(\)')).Count -eq 3) `
        "$(([regex]::Matches($sinCom, 'cola\.get_nowait\(\)')).Count) de 3"
    Comp 'y el microfono sigue llenando esa misma cola' ($sinCom -match 'def entrada\(datos, marcos, tiempo, estado\):[\s\S]{0,200}cola\.put\(bytes\(datos\)\)') ''
}
finally {
    Remove-Item -LiteralPath $sitio -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  el audio de hace medio minuto ya no puede activarla sola'
exit 0
