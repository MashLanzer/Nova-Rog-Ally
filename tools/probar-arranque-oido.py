# -*- coding: utf-8 -*-
# WHISPER CERRABA EL MICROFONO MIENTRAS CARGABA (24/09, ideas 14 y 15 de la tanda nueva).
#
# LO MEDIDO. De "VoiceAssistant iniciado" a "worker Vosk en marcha": mediana 7 s, p90 11 s,
# p99 142 s y maximo 242 s. Cargar Whisper base: n=217, mediana 4,2 s, maximo 117,9 s, suma
# 1.427 s. Entre eso y Parakeet, casi media hora de los quince dias solo cargando modelos.
#
# LOS OCHO ARRANQUES LENTOS, uno a uno: SEIS son un reinicio de desarrollo cayendo encima de un
# worker que todavia cargaba, con dos copias de Whisper compitiendo en un chip clase Steam
# Deck. Cinco de los ocho son del 16/09 entre las 20:13 y las 21:48, los minutos exactos de
# cinco commits de esa sesion. Las dos defensas de aquello ya estan puestas -el barrido de
# huerfanos del 17/09 y el cerrojo del 19/09- y desde el 19/09 ninguna carga pasa de 24,4 s.
#
# Y LO QUE LE COSTO A BRAYA, contado: UN dictado, el 16/09 a las 21:43:56. En los ocho huecos
# hay CERO pulsaciones de boton, y eso si es prueba: el boton lo registra assistant.ps1, que
# esta vivo mientras el worker carga.
#
# LO QUE SE ARREGLA: Whisper se cargaba EN SERIE Y BLOQUEANDO, antes de abrir el microfono, y
# Vosk -que es quien oye "nova"- ya estaba cargado veinte lineas antes. O sea que el microfono
# esperaba a un modelo que solo hace falta al DICTAR.
#
# LO QUE MAS SE VIGILA AQUI: que el dictado ESPERE y no degrade. Con la carga en un hilo,
# "whisper vale None" ya no significa "no se pudo" sino, a veces, "todavia no", y caer a Vosk
# en silencio seria perder comprension justo en la meta del 100 %.
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAKE = io.open(os.path.join(RAIZ, 'wake_vosk.py'), encoding='utf-8').read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


print("")
print("-- 1. la carga va en un hilo, no bloqueando --")
comp("hay una funcion que la carga", "def cargar_whisper():" in WAKE)
comp("y arranca en un hilo demonio",
     "threading.Thread(target=cargar_whisper, daemon=True).start()" in WAKE)
comp("con su evento para saber cuando esta", "whisper_listo = threading.Event()" in WAKE)
# EL EVENTO SE MARCA PASE LO QUE PASE: si solo se marcara al cargar bien, un fallo dejaria al
# dictado esperando para siempre, que es peor que el problema que se arregla.
i_fin = WAKE.find("        finally:")
i_set = WAKE.find("            whisper_listo.set()")
comp("el evento se marca en un finally", i_fin >= 0 and i_set > i_fin,
     "un fallo no puede dejar al dictado esperando para siempre")
# Y CON OTRO MOTOR, el evento ya esta puesto desde el arranque: si no, "esperar_whisper"
# esperaria dos minutos a algo que nadie va a cargar.
m_else = re.search(r"\nelse:\n    whisper_listo\.set\(\)", WAKE)
comp("y si el motor no es whisper, ya esta marcado", bool(m_else),
     "o esperaria dos minutos a algo que nadie carga")

print("")
print("-- 2. VOSK SIGUE CARGANDO ANTES, que es quien oye 'nova' --")
# Si esto se cayera, el nombre dejaria de funcionar hasta que Whisper terminara, que es
# exactamente el problema que se viene a quitar.
i_vosk = WAKE.find("KaldiRecognizer")
i_whisper = WAKE.find("whisper_listo = threading.Event()")
comp("Vosk se prepara antes que Whisper", 0 <= i_vosk < i_whisper,
     "el nombre no puede esperar al dictado")

print("")
print("-- 3. y el DICTADO ESPERA, no degrada --")
comp("hay una funcion que espera", "def esperar_whisper():" in WAKE)
m_tope = re.search(r"WHISPER_ESPERA_MAX = ([0-9.]+)", WAKE)
comp("con un tope", bool(m_tope), (m_tope.group(1) + " s") if m_tope else "sin tope")
# EL TOPE LO MANDA EL PRESUPUESTO DEL ASISTENTE, no la carga mas lenta. Esta comprobacion
# nacio exigiendo 117,9 s -la carga mas lenta medida- y era un error: el asistente CANCELA el
# dictado a los 50 s, asi que una espera larga no da "peor comprension", da NADA. El numero
# sale de restar dos mediciones que ya estaban: 50 - 30 (lo que dura el dictado) - 13,6 (lo que
# tarda Whisper en transcribir) = 6,4 s de margen para CARGAR.
comp("el tope cabe en los 50 s que espera el asistente",
     bool(m_tope) and float(m_tope.group(1)) <= 6.5,
     "50 - 30 de dictado - 13,6 de transcribir = 6,4 s")
comp("y no es cero: la mediana de carga son 4,2 s",
     bool(m_tope) and float(m_tope.group(1)) >= 4.2,
     "por debajo cortaria la mitad de las cargas normales")
# Y QUE EL ASISTENTE SIGA CANCELANDO A LOS 50: si alguien sube ese numero sin tocar este, el
# calculo de arriba deja de valer y nadie se entera.
ASIS2 = io.open(os.path.join(RAIZ, "assistant.ps1"), encoding="utf-8-sig").read()
comp("y el asistente sigue cancelando a los 50 s", "-ge 50000) {" in ASIS2,
     "si eso cambia, el tope de arriba hay que recalcularlo")
comp("vuelve al instante si ya esta listo", "if whisper_listo.is_set():" in WAKE)
comp("y deja dicho cuanto espero", "esperados %.1f s a que Whisper" in WAKE,
     "si no, la espera seria invisible")
comp("y avisa si se pasa del tope", "lleva %.0f s cargando" in WAKE)

print("")
print("-- 4. LOS TRES SITIOS que miraban whisper, todos esperan --")
# Si alguno se quedara con el "is not None" pelado, ese camino seguiria degradando a Vosk en
# silencio los primeros segundos de cada arranque.
sin_com = chr(10).join(l for l in WAKE.split(chr(10)) if not l.strip().startswith("#"))
# Las dos que quedan son el valor de retorno de esperar_whisper, que es justo donde tienen que
# estar: FUERA de esa funcion no puede quedar ninguna, o ese camino seguiria degradando.
i_esp = sin_com.find("def esperar_whisper():")
i_fin_esp = sin_com.find("def precargar_parakeet():")
dentro = sin_com[i_esp:i_fin_esp].count("whisper is not None")
fuera = sin_com.count("whisper is not None") - dentro
comp("no queda ninguno FUERA de esperar_whisper", fuera == 0,
     "%d fuera, %d dentro (esas son su valor de retorno)" % (fuera, dentro))
comp("el reintento por modelo espera", "base = pedido == \"base\" and esperar_whisper()" in WAKE)
comp("el dictado del boton espera", "elif esperar_whisper():" in WAKE)
comp("y el dictado normal tambien", "and esperar_whisper():" in WAKE)

print("")
print("-- 4b. y esperar_whisper se EJECUTA, no se lee --")
# El hallazgo del repaso: todas las comprobaciones de este banco miraban el TEXTO, asi que
# cambiar .wait(WHISPER_ESPERA_MAX) por .wait(WHISPER_ESPERA_MAX/60) lo dejaba verde -la
# constante seguia escrita-. Aqui se saca la funcion del fichero y se corre de verdad.
import threading
import time as _t
_fn = re.search(r"(?ms)^def esperar_whisper\(\):.*?(?=^def )", WAKE)
if not _fn:
    comp("se puede sacar esperar_whisper del fichero", False)
else:
    _apuntes = []
    _ns = {"threading": threading, "time": _t,
           "whisper_listo": threading.Event(), "whisper": None,
           "WHISPER_ESPERA_MAX": 0.4,          # 0,4 s para no tardar en el banco
           "anota": lambda m: _apuntes.append(m)}
    exec(_fn.group(0), _ns)                                        # noqa: S102
    # a) sin cargar: espera el tope y avisa
    _t0 = _t.time()
    _r = _ns["esperar_whisper"]()
    _tardo = _t.time() - _t0
    comp("sin cargar, espera el tope entero", 0.35 <= _tardo <= 1.2, "%.2f s" % _tardo)
    comp("y devuelve que no hay whisper", _r is False)
    comp("y lo deja dicho", any("cargando" in a for a in _apuntes),
         "si se callara, la orden saldria peor entendida sin pista de por que")
    # b) ya cargado: vuelve al instante
    _ns["whisper_listo"].set(); _ns["whisper"] = object(); _apuntes.clear()
    _t0 = _t.time()
    _r2 = _ns["esperar_whisper"]()
    _tardo2 = _t.time() - _t0
    comp("ya cargado, vuelve al instante", _tardo2 < 0.05 and _r2 is True, "%.3f s" % _tardo2)
    comp("y sin escribir nada", not _apuntes)
    # c) carga a mitad de la espera: no espera de mas
    _ns2 = dict(_ns); _ns2["whisper_listo"] = threading.Event(); _ns2["whisper"] = None
    _ns2["WHISPER_ESPERA_MAX"] = 5.0; _apuntes.clear(); _ns2["anota"] = lambda m: _apuntes.append(m)
    exec(_fn.group(0), _ns2)                                       # noqa: S102
    def _carga():
        _t.sleep(0.3)
        _ns2["whisper"] = object()
        _ns2["whisper_listo"].set()
    threading.Thread(target=_carga, daemon=True).start()
    _t0 = _t.time()
    _r3 = _ns2["esperar_whisper"]()
    _tardo3 = _t.time() - _t0
    comp("si carga a mitad, no espera el tope entero", _tardo3 < 1.5 and _r3 is True, "%.2f s de 5" % _tardo3)

print("")
print("-- 5. LO QUE NO SE TOCA --")
# Nada residente de mas: es el mismo modelo, la misma RAM y el mismo int8 de siempre.
comp("el modelo sigue siendo el mismo", 'compute_type="int8"' in WAKE)
comp("y con los mismos hilos", "cpu_threads=HILOS_PRECISO" in WAKE)
# Hay TRES WhisperModel en el fichero y solo una es la del dictado: las otras dos son el
# modelo preciso del oido fino y el del ultimo recurso, y esas no se tocan.
comp("el del dictado se construye una sola vez",
     WAKE.count("whisper = WhisperModel(") == 1, "una sola construccion")
comp("y los otros dos modelos siguen donde estaban",
     ("_preciso = WhisperModel(" in WAKE) and ("_ultimo = WhisperModel(" in WAKE),
     "el oido fino y el ultimo recurso")
# Y LA PRECARGA DE PARAKEET, que ya usaba este patron, sigue igual: de ahi se copio.
comp("la precarga de parakeet sigue en su hilo", "def precargar_parakeet():" in WAKE)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  el microfono ya no espera a que cargue el dictado")
sys.exit(0)
