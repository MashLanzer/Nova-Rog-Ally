# Worker de palabra de activacion con Vosk (offline).
#
# POR QUE VOSK Y NO SAPI:
# SAPI no da acceso al audio crudo. En esta maquina el microfono entra muy
# bajo (prueba de Windows: 7 %), y SAPI lo clasificaba como silencio: nunca
# llegaba a intentar reconocer. Aqui leemos el microfono nosotros, asi que
# podemos AMPLIFICAR por software antes de reconocer.
#
# GANANCIA AUTOMATICA: se mide el pico real y se ajusta el multiplicador para
# acercarlo a un objetivo. Sin esto habria que adivinar el numero a mano.
#
# Comunicacion: al oir el nombre se crea un archivo marca, igual que el worker
# anterior. El asistente lo ve, lo borra y actua.
#
# Uso: wake_vosk.py <nombre> <rutaMarca> <rutaLog> [ganancia|auto] [pausa]
#      [dictar] [texto] [parcial] [nivel]

import sys
# Si el worker muere dentro de numpy/Whisper/sounddevice, Python no deja ni
# una linea: el 12/09 murio tres veces sin rastro (20:13, 21:15, 22:21).
# faulthandler vuelca la pila al stderr, que el asistente guarda en
# tmp/wake-err.log.
import faulthandler
faulthandler.enable()
import os
import re
import json
import queue
import time
import collections
import unicodedata

import numpy as np
import sounddevice as sd
from vosk import Model, KaldiRecognizer, SetLogLevel

SetLogLevel(-1)

NOMBRE = (sys.argv[1] if len(sys.argv) > 1 else "nova").lower()
MARCA = sys.argv[2] if len(sys.argv) > 2 else "despierta.flag"
LOG = sys.argv[3] if len(sys.argv) > 3 else ""
GANANCIA_ARG = sys.argv[4] if len(sys.argv) > 4 else "auto"
# Mientras exista este archivo se ignora el audio por completo. Lo crea el
# asistente cuando HABLA o cuando esta dictando: su propia voz volvia al
# microfono con pico 0.99 y hundia la ganancia automatica hasta x0.7,
# dejandolo sordo a la voz real (0.02). Ese era el fallo de "ya no se activa".
PAUSA = sys.argv[5] if len(sys.argv) > 5 else ""
# --- DICTADO ---
# Mientras exista DICTAR, este worker transcribe la frase ENTERA en vez de
# buscar solo el nombre. Sustituye a Win+H, que era el origen de casi todos
# los fallos: robaba el foco (y si fallaba, el texto acababa en otra ventana),
# deformaba palabras, y obligaba a esperar al silencio desde fuera.
# Al terminar escribe el texto en TEXTO y borra DICTAR.
DICTAR = sys.argv[6] if len(sys.argv) > 6 else ""
TEXTO = sys.argv[7] if len(sys.argv) > 7 else ""
PARCIAL = sys.argv[8] if len(sys.argv) > 8 else ""
# --- NIVEL PARA LA INTERFAZ ---
# Mientras el asistente dicta (con Win+H este worker esta en pausa, pero el
# microfono sigue llegando) se escribe aqui el nivel de voz, 0..1, para que la
# onda de la capsula se mueva con la voz real. La interfaz lo lee directamente:
# el asistente no esta en medio, asi que no anade latencia a nada.
NIVEL = sys.argv[9] if len(sys.argv) > 9 else ""
# --- CONFIRMACION SI/NO ---
# Mientras exista CONFIRMAR se escucha SOLO si/no con una gramatica cerrada
# (instantanea y fiable para cuatro palabras) y se escribe la respuesta en
# CONFIRMACION. Lo usa el asistente cuando acerto una orden por parecido
# lejano: "¿Little Nightmares III?".
CONFIRMAR = sys.argv[10] if len(sys.argv) > 10 else ""
CONFIRMACION = sys.argv[11] if len(sys.argv) > 11 else ""
# --- MOTOR DE DICTADO: "vosk" o "whisper[:modelo]" ---
# Vosk pequeno sirve para la palabra de activacion pero transcribe mal las
# ordenes ("abre stein"). Whisper (faster-whisper, int8 en CPU) es mucho mas
# preciso: se graba la orden entera y se transcribe al callar. Vosk sigue
# dando la transcripcion parcial en vivo mientras hablas.
MOTOR_DICTADO = sys.argv[12] if len(sys.argv) > 12 else "vosk"
# argv[13] es tmp\vocabulario.txt: assistant.ps1 (:9632) lo sigue pasando en este
# hueco, pero AQUI NO SE LEE y no hay que volver a leerlo. El initial_prompt de
# Whisper es PROMPT_ORDENES a proposito: el 11/09 se quito la lista de nombres
# porque con audio flojo Whisper la continuaba, y el 14/09 las 100 grabaciones
# confirmaron que las hotwords hacian lo mismo. Por eso el 19/09 se quito
# leer_vocabulario(), que era la unica que abria ese fichero y no la llamaba nadie.
# --- CONFIANZA MINIMA (config.json -> escucha.confianzaMinima) ---
# Hasta ahora este worker ignoraba ese ajuste: solo llegaba al wake_worker.exe
# viejo, asi que el numero del config no hacia absolutamente nada.
try:
    CONFIANZA_ARG = float(sys.argv[14]) if len(sys.argv) > 14 else None
except ValueError:
    CONFIANZA_ARG = None
# --- SEGUNDA OPORTUNIDAD (oido fino) ---
# El modelo rapido ("base") entiende mal los nombres propios: "abrestean" por
# "abre steam". El preciso ("small") acierta bastante mas, pero tarda unas tres
# veces mas, y pagar eso en CADA orden no compensa. Asi que se dicta con el
# rapido y, solo cuando el asistente no reconoce lo que le llego, pide por esta
# marca que se repase el MISMO audio con el preciso. Lo caro se paga unicamente
# cuando hace falta.
REINTENTO = sys.argv[15] if len(sys.argv) > 15 else ""
REINTENTO_TEXTO = sys.argv[16] if len(sys.argv) > 16 else ""
MODELO_PRECISO = sys.argv[17] if len(sys.argv) > 17 and sys.argv[17] not in ("", "-") else ""
# ULTIMO RECURSO (15/09): cuando ni base ni small entienden la orden, el asistente pide
# este (large-v3-turbo). Con las grabaciones de braya rescato 19 de 36 que fallaban, sin
# romper ninguna ni convertir el ruido en ordenes; tarda ~12 s por frase en la Ally.
# "-" = apagado (15/09: turbo se apago en uso real; el asistente no puede pasar un argumento vacio)
MODELO_ULTIMO = sys.argv[18] if len(sys.argv) > 18 and sys.argv[18] not in ("", "-") else ""
# se suelta tras este rato sin usarse (~1 GB de RAM); con un juego delante, en seguida
ULTIMO_SOLTAR = 120.0
# 8 s y no 5 (18/09): el worker tiene que escuchar el si/no AL MENOS lo que el asistente
# espera (6 s), con margen. Antes era al reves y el asistente cortaba mientras este escuchaba.
CONFIRMACION_MAX = 8.0
# el oido fino no repasa audios mas largos que esto (ver atender_reintento)
REPASO_MAX = 8.0

# se da por terminada la frase tras este silencio
SILENCIO_FIN = 1.5
# LA FRASE DE EJEMPLO PARA WHISPER (14/09). Antes se le daba la lista de apps y juegos
# como hotwords. Con las 100 grabaciones de braya, eso lo arrastraba al ingles y a
# recitar nombres ("Everything", "King is a Hollow Knight", "Outlast 3, Goose Duck").
# Con esta frase en espanol, como el asistente (base + repaso con small), acierta 74
# de 90 en vez de 63, y base solo 43 ordenes de 78 en vez de 28. Y el miedo de antes
# -que continuara la frase con ruido y se inventara una orden- se midio: 108 trozos de
# ruido (71 del cuarto, 30 de la voz de Nova, 7 sinteticos) y NINGUNA orden; con las
# hotwords, la voz de Nova diciendo "Abro Hollow Knight" si acababa en abrirlo.
# SIN NUMEROS NI NOMBRES DE JUEGOS (14/09, 110 grabaciones): con "al treinta" en la
# frase, "pon el juego al ochenta" se oia "al treinta" (el numero arrastra, y se haria
# en silencio con otro numero). Sin numeros acierta lo mismo (92 de 110) y ningun
# numero cambia. Con "Abre Little Nightmares III" se inventaba ese juego en frases
# que no lo decian, y la voz de Nova volvia a acabar en abrir otro.
PROMPT_ORDENES = "Nova, abre Steam. Sube el volumen. Pon el modo noche. ¿Qué hora es? Baja el brillo."


def es_eco_del_ejemplo(texto):
    """¿Lo oido es SOLO frases de PROMPT_ORDENES? Con voz poco clara Whisper a veces
    devuelve su propio ejemplo: en las 100 grabaciones, "cuanta bateria queda" desde
    lejos salio "Que hora es" y "baja el volumen", "Baja el brillo". El asistente,
    con eco y seguridad baja, pide que el oido fino lo confirme antes de hacerlo."""
    def llano(t):
        t = unicodedata.normalize("NFD", (t or "").lower())
        t = "".join(c for c in t if unicodedata.category(c) != "Mn")
        t = " ".join(re.sub(r"[^a-z0-9 ]+", " ", t).split())
        return re.sub(r"^(?:oye |hey |ey )?nova ?", "", t).strip()
    frases = {llano(f) for f in re.split(r"[.?¿!]+", PROMPT_ORDENES)} - {""}
    partes = [llano(x) for x in re.split(r"[.?¿!,]+", texto or "")]
    partes = [x for x in partes if x]
    return bool(partes) and all(x in frases for x in partes)
# ... salvo que el asistente ya tenga la orden entera (tmp\lotengo.txt, el mismo
# texto que va en el parcial): entonces basta con esto (14/09). En las 20
# grabaciones, la pausa mas larga DENTRO de una orden es de 0,45 s; los 1,4 s
# eran para no cortar frases largas que aun no se entienden, y se mantienen.
# 14/09, con las 100 grabaciones: la pausa mas larga DENTRO de una orden normal fue
# de 0,81 s (con 20 parecia 0,45), y con pausas a proposito se llego a 1,44 s. De ahi
# 1,1 s para lo ya entendido y 1,5 s (antes 1,4) para lo que aun no.
SILENCIO_FIN_LOTENGO = 1.1


def silencio_para_cerrar(tengo, dicho):
    """Cuanto silencio cierra la frase. Lo corto SOLO si lo que el asistente ya
    entendio (tengo) es exactamente lo dicho hasta ahora: si has seguido hablando
    despues ("abre steam... y pon modo juego"), ya no coincide y se espera lo
    de siempre. Aparte para poder probarlo sin microfono (tools/probar-escucha.py)."""
    if tengo and dicho and " ".join(tengo.split()) == " ".join(dicho.split()):
        return SILENCIO_FIN_LOTENGO
    return SILENCIO_FIN
# tope duro, por si el silencio nunca llega (ruido de fondo constante)
DICTADO_MAX = 30.0
# sin reconocer ni una palabra en este rato, el dictado se cierra vacio
DICTADO_SIN_VOZ = 8.0
# Lo que se le da a Whisper como mucho. Llegar a DICTADO_MAX significa que
# nunca hubo un silencio: eso no es una orden, es ruido constante. El 11/09
# hubo 14 transcripciones de 30 s que costaron 181 s de CPU para nada. Una
# orden de verdad, incluso larga ("recuerdame manana a las diez que..."), cabe
# de sobra en esto, y se coge el PRINCIPIO porque es donde esta la orden.
TRANSCRIBIR_MAX = 15.0

TASA = 16000
PICO_OBJETIVO = 0.35      # nivel al que queremos llevar la voz
# ARRANCAR BAJO ES MAS SEGURO QUE ARRANCAR ALTO (17/09). El comentario de antes
# decia "la voz entra a 0.02-0.05 y hizo falta x26", y eso describia OTRO microfono:
# medido sobre 400 pulsos reales de braya, el p90 crudo tiene mediana 0.601 y el 27 %
# llega SATURADO, asi que la ganancia que pide es 0.58 de mediana. Arrancar en x8 era
# lo que hacia que se activara sola con ruido y que no le oyera (17/09), y volveria a
# pasar en cuanto faltara tmp\ganancia.txt, que es un directorio de usar y tirar.
# Se arranca neutro: el pulso SUBE rapido (factor 0.6) y BAJA lento (0.2), asi que
# quedarse corto se corrige en segundos y pasarse son minutos de activaciones solas.
GANANCIA_INICIAL = 1.0
# El minimo permite ATENUAR: si el microfono entra fuerte, amplificar recorta
# la senal y el reconocimiento se vuelve imposible por el motivo contrario.
GANANCIA_MIN = 0.3
GANANCIA_MAX = 40.0
# Por debajo de esto la ventana es silencio: calibrar con silencio dispararia
# la ganancia al maximo y luego saturaria la voz.
UMBRAL_VOZ = 0.008
# bloques de 250 ms por encima del umbral que hacen falta para recalibrar:
# con menos, un golpe suelto bastaba para mover la ganancia
MIN_BLOQUES_VOZ = 4
PASO_MAX = 4.0
# --- PUERTA DE ENERGIA ---
# Sin esto Vosk decodifica 4 bloques por segundo las 24 horas, aunque no haya
# nadie hablando, y este worker arranca con Windows en un portatil de juegos.
# Decodificar es lo caro; medir la energia del bloque es practicamente gratis.
# Se deja un margen de arrastre para no cortar el final de la palabra, y un
# pre-buffer para no perder su principio.
UMBRAL_ACTIVIDAD = 0.006
ARRASTRE = 4              # bloques que se siguen decodificando tras el silencio
PREBUFFER = 2             # bloques previos que se recuperan al detectar voz
INTERVALO_PULSO = 15.0    # ajuste rapido; con 60 s tardaba minutos en subir
# LA VENTANA DEL "decodificado=N%" (19/09/2026). Ese porcentaje del pulso salia de
# DOS CONTADORES QUE NO SE RESETEABAN NUNCA: era la media de toda la vida del
# proceso. Con Nova encendida desde las 09:19 seguia marcando decodificado=0% a
# las 19:18 (PENDIENTES-2026-09-19.md:10) y, aunque le hablaras diez veces
# seguidas, con diez horas de silencio detras el numero no se habria movido ni un
# punto: un aviso que tarda horas en reaccionar no avisa de nada.
# Ahora se cuenta por cubos. Cada cubo dura un INTERVALO_PULSO -lo mismo que tarda
# el pulso en salir, asi que cada latido resume cubos enteros- y se promedian los
# ultimos VENTANA_DEC_CUBOS. 20 x 15 s = 5 minutos: bastante para que un silencio
# corto no lo tire a cero, y poco para que hablarle se note en el latido siguiente.
VENTANA_DEC_CUBOS = 20
# EL LATIDO SOLO CUANDO DICE ALGO NUEVO (18/09). Los 6 formatos de pulso eran el 43,9 % del log
# (11.811 lineas; el 16/09 dejo 5.086), y el que mas se repite -"sin voz sostenida"- no aporta
# nada que no diga el siguiente. Se calla mientras repita lo mismo, pero como mucho un minuto:
# si Nova se quedara colgada, en el log tiene que notarse el hueco.
# Ojo: esto NO toca el fichero de estado, que se sigue escribiendo siempre porque de ahi leen
# la ganancia y la capsula.
PULSO_REPETIDO_MAX = 60.0
_pulso_ultimo = ""
_pulso_ultimo_en = 0.0


def anota_pulso(texto, ahora):
    """El pulso, sin repetirse: igual que el anterior y hace menos de un minuto, se calla."""
    global _pulso_ultimo, _pulso_ultimo_en
    # lo que cambia en cada latido (el nivel exacto de los altavoces) no cuenta como novedad:
    # se compara sin los numeros de coma flotante
    clave = "".join(c for c in texto if not (c.isdigit() or c == "."))
    if clave == _pulso_ultimo and (ahora - _pulso_ultimo_en) < PULSO_REPETIDO_MAX:
        return
    _pulso_ultimo = clave
    _pulso_ultimo_en = ahora
    anota(texto)
# --- ALTAVOCES ---
# Por encima de este pico en la SALIDA se considera que esta sonando algo
# (medido en esta maquina: silencio 0.0002, fondo suave 0.007, video 0.30).
UMBRAL_ALTAVOZ = 0.02
# Por encima de esto no suena "algo de fondo": suena FUERTE (un juego, un
# video a volumen normal). Ahi la palabra de activacion no es fiable -el
# 11/09 a las 20:16 se activo con los altavoces a 0.39 y confianza 0.91,
# por encima del umbral exigente- y encima el usuario esta jugando, que es
# cuando mas molesta. Queda el boton, que no se equivoca nunca.
UMBRAL_ALTAVOZ_FUERTE = 0.35
# El modelo preciso solo corre a rachas y con prioridad baja: puede permitirse
# mas hilos que el rapido, que va en el camino de cada orden.
HILOS_PRECISO = 8
INTERVALO_MEDIDOR = 0.15   # no tiene sentido preguntar mas a menudo


def anota(mensaje):
    if not LOG:
        return
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S") + "  [escucha] " + mensaje + "\n")
    except Exception:
        pass


# --- MEDIDOR DE LOS ALTAVOCES (mejora 3) ---
# El worker ya se callaba mientras NOVA habla (archivo PAUSA), pero no cuando
# suena cualquier otra cosa: un video, un juego o -literalmente lo que paso el
# 11/09- un Outlast 2 colgado sonando durante horas. Ese audio entraba por el
# microfono y se convertia en "ordenes". Aqui se le pregunta a Windows cuanto
# esta sonando por los altavoces; si suena, se desconfia mas de lo que se oye.
# Se usa IAudioMeterInformation: es una llamada suelta, no abre ningun stream
# ni consume CPU, y si algo falla el worker sigue igual que antes.
_medidor = None
_medidor_valor = 0.0
_medidor_visto = 0.0
_medidor_fallos = 0
_medidor_creado = 0.0
_medidor_reintento = 0.0
REFRESCO_MEDIDOR = 300.0   # s: rehacerlo por si cambiaste de altavoces a cascos


def _crear_medidor():
    import ctypes
    from ctypes import POINTER, c_float
    import comtypes
    from comtypes import GUID, COMMETHOD, IUnknown, CLSCTX_ALL

    class IAudioMeterInformation(IUnknown):
        _iid_ = GUID("{C02216F6-8C67-4B5B-9D00-D008E73E0064}")
        _methods_ = (COMMETHOD([], ctypes.HRESULT, "GetPeakValue",
                               (["out"], POINTER(c_float), "pfPeak")),)

    class IMMDevice(IUnknown):
        _iid_ = GUID("{D666063F-1587-4E43-81F1-B948E807363F}")
        _methods_ = (COMMETHOD([], ctypes.HRESULT, "Activate",
                               (["in"], POINTER(GUID), "iid"),
                               (["in"], ctypes.c_uint, "dwClsCtx"),
                               (["in"], POINTER(ctypes.c_void_p), "pParams"),
                               (["out"], POINTER(POINTER(IUnknown)), "ppInterface")),)

    class IMMDeviceEnumerator(IUnknown):
        _iid_ = GUID("{A95664D2-9614-4F35-A746-DE8DB63617E6}")
        _methods_ = (
            COMMETHOD([], ctypes.HRESULT, "NoUsado_EnumAudioEndpoints",
                      (["in"], ctypes.c_uint, "dataFlow"),
                      (["in"], ctypes.c_uint, "dwStateMask"),
                      (["out"], POINTER(POINTER(IUnknown)), "ppDevices")),
            COMMETHOD([], ctypes.HRESULT, "GetDefaultAudioEndpoint",
                      (["in"], ctypes.c_uint, "dataFlow"),
                      (["in"], ctypes.c_uint, "role"),
                      (["out"], POINTER(POINTER(IMMDevice)), "ppEndpoint")),
        )

    enum = comtypes.CoCreateInstance(GUID("{BCDE0395-E52F-467C-8E3D-C4579291692E}"),
                                     IMMDeviceEnumerator, CLSCTX_ALL)
    dev = enum.GetDefaultAudioEndpoint(0, 0)      # 0 = eRender: los altavoces
    ptr = dev.Activate(IAudioMeterInformation._iid_, CLSCTX_ALL, None)
    # QueryInterface y NO ctypes.cast (15/09): cast no reserva el objeto, asi que al
    # soltarse 'ptr' el medidor quedaba apuntando a memoria ya liberada, y al tirarlo o
    # rehacerlo (cada REFRESCO_MEDIDOR) se liberaba dos veces: la escucha murio con
    # "access violation" en comtypes (unknwn.py, Release) dos veces el 15/09.
    return ptr.QueryInterface(IAudioMeterInformation)


def nivel_salida():
    """Pico actual de los altavoces (0..1). 0.0 si no se puede medir.

    De esta medida cuelgan CUATRO protecciones (mas confianza exigida con
    altavoces, veto con altavoces fuertes, ganancia congelada y freno del
    detector de recorte). Si se apaga, todas desaparecen en silencio y vuelven
    los fallos del 11/09. Por eso no se da por perdida a la primera y se rehace
    cada tanto: el objeto guarda el dispositivo de salida DE CUANDO SE CREO, y
    al cambiar de altavoces a cascos el viejo devuelve 0.0 sin dar ningun
    error."""
    global _medidor, _medidor_valor, _medidor_visto
    global _medidor_fallos, _medidor_creado, _medidor_reintento
    ahora = time.time()
    if ahora - _medidor_visto < INTERVALO_MEDIDOR:
        return _medidor_valor
    _medidor_visto = ahora
    # si lleva un rato fallando, se reintenta de vez en cuando, no a cada vuelta
    if _medidor is None and _medidor_fallos > 3 and ahora - _medidor_reintento < 30.0:
        return 0.0
    if _medidor is not None and ahora - _medidor_creado > REFRESCO_MEDIDOR:
        _medidor = None          # a ver si ha cambiado el dispositivo de salida
    try:
        if _medidor is None:
            _medidor_reintento = ahora
            _medidor = _crear_medidor()
            _medidor_creado = ahora
            if _medidor_fallos:
                anota("medidor de altavoces recuperado tras %d fallos" % _medidor_fallos)
            elif _medidor_creado == ahora and not _medidor_valor:
                anota("medidor de altavoces activo: se desconfia del microfono mientras suena algo")
            _medidor_fallos = 0
        _medidor_valor = float(_medidor.GetPeakValue())
    except Exception as e:              # noqa: BLE001
        _medidor = None
        _medidor_fallos += 1
        _medidor_valor = 0.0
        if _medidor_fallos in (1, 5, 25):
            anota("WARN: no puedo medir los altavoces (%s); reintentando" % e)
    return _medidor_valor


# --- OIDO FINO: el modelo preciso, cargado solo si llega a hacer falta ---
# Ocupa ~500 MB en RAM, asi que no se carga al arrancar: en esta maquina hay
# 7,7 GB y el juego manda. La primera vez tarda unos segundos; a partir de ahi
# se queda listo.
_preciso = None
_preciso_roto = False
_preciso_uso = 0.0
# JUGANDO, LA RAM ES DEL JUEGO (14/09): con un juego delante (la marca solo-boton)
# y este rato sin repasar nada, se suelta. Volver a cargarlo cuesta ~3 s, y solo
# si llega a hacer falta; tenerlo cargado toda la partida eran ~500 MB para nada.
PRECISO_SOLTAR_JUGANDO = 300.0
# Y SIN JUEGO TAMBIEN, PERO CON MAS PACIENCIA (17/09). Hasta hoy el oido fino solo se soltaba
# si habia un juego delante: sin juego se quedaba en RAM para siempre, ~500 MB, aunque
# pasaran dias. En todo el log se solto UNA vez.
#
# Medido en el log antes de elegir el numero: entre dos usos del oido fino pasan 111 s de
# mediana, pero el 30 % de los huecos pasa de 5 minutos, el 18 % de 10 y el 13 % de media
# hora (el mayor, 59 horas). Recargarlo cuesta 2,5 s de mediana. Retenerlo horas para
# ahorrar 2,5 s es mal negocio.
#
# 20 minutos deja fuera al 82 % de los huecos: no se suelta en medio de una racha de
# ordenes, solo cuando de verdad has dejado de usarlo.
PRECISO_SOLTAR_QUIETO = 1200.0


# CUANTA RAM QUEDA, SIN INSTALAR NADA (17/09). psutil existe en esta maquina, pero el worker
# no lo importa y no se le van a anadir dependencias por esto: GlobalMemoryStatusEx da el
# mismo numero (comprobado: 2.414 MB por las dos vias) y viene con Python.
def ram_libre_mb():
    """MB de RAM fisica libre, o -1 si no se puede saber (entonces no se estorba)."""
    try:
        import ctypes

        class _MS(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                        ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                        ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                        ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                        ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
        m = _MS()
        m.dwLength = ctypes.sizeof(_MS)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m)):
            return -1
        return m.ullAvailPhys / 1048576.0
    except Exception:  # noqa: BLE001
        return -1


# LO QUE HACE FALTA PARA CARGAR CADA UNO, con margen. Parakeet ocupa 639 MB en disco y el
# oido fino unos 500 en int8; se pide casi el doble porque cargar deja picos y porque dejar
# el equipo sin aire es justo lo que se quiere evitar.
#
# El 15/09 paso de verdad: con Parakeet, base y small cargados a la vez quedaron 0,3 GB
# libres de 7,7 y Whisper tardo de 4,5 a 12,9 s por orden en vez de ~1 s. Ya habia guarda
# para la charla (Test-RamParaCharla, 3000 MB) pero NINGUNA para estos, que son los que
# causaron aquello.
#
# OJO: quedarse sin RAM no marca el modelo como roto. _parakeet_roto y _preciso_roto son
# para siempre, y esto es pasajero: cuando cierres el juego habra sitio y se cargara.
RAM_MIN_PARAKEET = 1200.0
RAM_MIN_PRECISO = 900.0


def modelo_preciso():
    global _preciso, _preciso_roto
    if _preciso is not None or _preciso_roto or not MODELO_PRECISO:
        return _preciso
    _libre = ram_libre_mb()
    if 0 <= _libre < RAM_MIN_PRECISO:
        anota("oido fino: no lo cargo, solo quedan %.0f MB libres (hacen falta %.0f)"
              % (_libre, RAM_MIN_PRECISO))
        return None
    try:
        t0 = time.time()
        from faster_whisper import WhisperModel
        _preciso = WhisperModel(MODELO_PRECISO, device="cpu", compute_type="int8",
                                cpu_threads=HILOS_PRECISO)
        anota("oido fino '%s' cargado en %.1f s" % (MODELO_PRECISO, time.time() - t0))
    except Exception as e:
        _preciso_roto = True
        anota("WARN: no se pudo cargar el oido fino (%s)" % e)
    return _preciso


# --- PARAKEET PRIMERO (15/09): NVIDIA Parakeet TDT 0.6B v3 oye antes que Whisper ---
# Con las 214 grabaciones de braya: 0,6 s por frase y NINGUNA orden equivocada (no lleva
# frase de ejemplo que se cuele). Si lo que oye no se entiende como orden, el asistente
# pide "base" y Whisper repasa el mismo audio (ver atender_reintento). Si no esta
# instalado (modelos/*parakeet*) o hay un juego delante, todo sigue con Whisper como antes.
_parakeet = None
_parakeet_roto = False


def jugando():
    return bool(MARCA_SOLO_BOTON) and os.path.exists(MARCA_SOLO_BOTON)


# EL PRIMERO SE HACE SITIO (19/09). La noche del 18 Parakeet no cargo NI UNA vez en toda
# la sesion: le faltaban entre 26 y 271 MB (quedaban 929, 976 y 1174 de los 1200 que pide).
# Mientras tanto el oido fino ocupaba sus ~500 MB desde las 23:34 sin repasar nada, porque
# su plazo sin juego delante son 20 minutos y la sesion duro 11. Resultado: la noche entera
# oyendo con Whisper base, que es el repaso, no el titular (ver la medida del 18/09: de 75
# pares, Parakeet acerto 23 que base fallo).
#
# Asi que, si falta poco, el titular se hace sitio: suelta el oido fino y lo vuelve a
# mirar. Recargarlo cuesta 2,5 s de mediana y solo si vuelve a hacer falta. No se toca si
# se uso hace menos de un minuto (estara en mitad de una racha), y si aun asi no cabe, no
# se ha perdido nada: se sigue con base, igual que antes.
PARAKEET_QUIETO_FINO = 60.0


def hacer_sitio_a_parakeet(libre):
    global _preciso
    if _preciso is None:
        return libre
    if time.time() - _preciso_uso < PARAKEET_QUIETO_FINO:
        return libre
    _preciso = None
    import gc
    gc.collect()
    ahora = ram_libre_mb()
    anota("oido fino soltado para hacerle sitio a Parakeet: %.0f -> %.0f MB libres"
          % (libre, ahora))
    return ahora


def modelo_parakeet():
    global _parakeet, _parakeet_roto
    if _parakeet is not None or _parakeet_roto:
        return _parakeet
    _libre = ram_libre_mb()
    if 0 <= _libre < RAM_MIN_PARAKEET:
        _libre = hacer_sitio_a_parakeet(_libre)
    if 0 <= _libre < RAM_MIN_PARAKEET:
        anota("parakeet: no lo cargo, solo quedan %.0f MB libres (hacen falta %.0f)"
              % (_libre, RAM_MIN_PARAKEET))
        return None
    try:
        import glob
        carpetas = [c for c in glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "modelos", "*parakeet*")) if os.path.isdir(c)]
        if not carpetas:
            _parakeet_roto = True
            return None
        import sherpa_onnx

        def fichero(patron):
            return sorted(glob.glob(os.path.join(carpetas[0], patron)))[0]
        t0 = time.time()
        _parakeet = sherpa_onnx.OfflineRecognizer.from_transducer(
            encoder=fichero("encoder*.onnx"), decoder=fichero("decoder*.onnx"), joiner=fichero("joiner*.onnx"),
            tokens=fichero("tokens.txt"), num_threads=HILOS_PRECISO, decoding_method="greedy_search", model_type="nemo_transducer")
        anota("parakeet cargado en %.1f s" % (time.time() - t0))
    except Exception as e:
        _parakeet_roto = True
        anota("WARN: no se pudo cargar Parakeet (%s); se sigue con Whisper" % e)
    return _parakeet


# COBERTURA DE PARAKEET (15/09). En vivo, tras una respuesta larga, oyo solo "el Xbox" de
# 8 s de audio con 4 s de voz ("y ahora podrias decirme quien invento el Xbox") y se abrio
# Xbox. Lo que saca tiene que cubrir la voz que hubo: letras por segundo de voz. Medido con
# las 214 grabaciones de orden, charla y ruido: la orden buena con menos cobertura tuvo 6,2
# ("Abre in the ring") y el caso del Xbox 1,5; con 3, 5 o 7 no se pierde ningun acierto.
# Por debajo, Parakeet no manda y el audio lo oye Whisper como siempre.
PARAKEET_COBERTURA_MIN = 4.0


def segundos_de_voz(audio):
    """Lo mismo que mide analizar-100: de la primera a la ultima trama de 30 ms con voz."""
    tr = 480
    n = audio.size // tr
    if n == 0:
        return 0.0
    e = np.sqrt(np.mean(audio[:n * tr].reshape(n, tr) ** 2, axis=1))
    idx = np.where(e > max(0.008, float(np.percentile(e, 90)) * 0.15))[0]
    return 0.0 if idx.size == 0 else (idx[-1] - idx[0]) * 0.03


def cobertura_parakeet(texto, audio):
    letras = len(re.sub(r"[^\w]|_|\d", "", texto or ""))
    return letras / max(segundos_de_voz(audio), 0.3)


# PARAKEET OYE INGLES EN TU ESPAÑOL (18/09). v3 elige el idioma por frase y 13 de 99 veces
# eligio mal: "Haben The Ring", "See it now", "Well probably", "And I think I'm tentative".
# Suena a ingles si NO lleva ni una palabra española corriente y SI alguna palabra vacia
# inglesa. Solo palabras vacias, nunca digrafos ni terminaciones: "Bluetooth", "Elden Ring",
# "Little Nightmares" o "Rocket League" son ingles y son ordenes tuyas de todos los dias, y
# llevan casi siempre un verbo español delante ("abre", "pon") que las salva igualmente.
PALABRAS_ES = set("""el la los las de del en un una unos unas que y a por con no si me te se lo le al es esta
    pon ponme abre abreme cierra cierralo sube baja quita quitame cual cuales hora modo mi tu su para ya hay
    dime revisa quiero como donde cuando cuanto cuanta todo esto eso nova ey oye vale bueno gracias ok okey
    puedes puede crea crear abrir cerrar poner busca buscame enciende apaga activa desactiva llama mira
    brillo volumen pantalla navegador correo cancion canciones musica juego juegos ajustes archivo carpeta
    tambien otra otro ahora luego mas menos muy bien mal hoy manana ayer noche dia minuto minutos segundos
    temporizador alarma recordatorio recuerdame agenda calendario haber ver dame cuentame explicame dile
    ponlo quitalo cierre agrega anade elimina borra guarda escribe lee leeme traduce resume pausa reanuda
    siguiente anterior captura foto bloquea apagar reinicia silencio calla para espera nada olvidalo
    nuevo nueva ultimo ultima primero primera segundo segunda tercero tercera""".split())
PALABRAS_EN = set("""the and i'm i im you your it it's is are was were this that these those here there now then
    see well probably gonna wanna know think everything something nothing anything what where when how why
    who which we they he she my me our their his her at on in to of for with from by as be been being have
    has had do does did can could would should will won't don't doesn't didn't not or but if so just like
    get got go going come came make made let yeah okay please thanks thank hello hi hey right left up down
    over out about into back off all any some more most much very too also still again ever never always
    sometimes tentative""".split())


def suena_ingles(texto):
    """True si lo de Parakeet es ingles de arriba abajo: sin una palabra española, con alguna inglesa."""
    palabras = [unicodedata.normalize("NFD", w).encode("ascii", "ignore").decode().lower()
                for w in re.findall(r"[a-záéíóúñüA-ZÁÉÍÓÚÑÜ']+", texto or "")]
    palabras = [w for w in palabras if w]
    if not palabras or any(w in PALABRAS_ES for w in palabras):
        return False
    if re.search(r"[áéíóúñ¿¡]", texto or ""):
        return False
    return any(w in PALABRAS_EN for w in palabras)


def repasar_si_ingles(rapido, bloques):
    """Si lo de Parakeet suena a ingles, lo oye Whisper (forzado a español) antes de entregar.
    Devuelve (parakeet, whisper): con Whisper acertando, lo de Parakeet se queda en "" para
    que se entregue lo suyo; si Whisper no saca nada, se entrega lo de Parakeet como siempre."""
    if not rapido or whisper is None or not suena_ingles(rapido):
        return rapido, ""
    # EL REPASO, CON EL OIDO FINO (19/09). Medido pasando las 311 grabaciones de uso por
    # este mismo camino: la guarda salta 22 veces (bien: detecta el ingles), pero el
    # repaso lo hacia Whisper "base" y de esas 22 solo UNA acababa en una orden buena.
    # Con "small" salen mas ("Si es el navegador" -> "Cierra el navegador"). Se pide el
    # oido fino, que ya tiene su propia guarda de RAM (900 MB) y devuelve None si no cabe
    # o si hay un juego comiendose la memoria; entonces se sigue con base, como siempre.
    fino = modelo_preciso()
    mejor = transcribir_whisper(bloques, modelo=fino) if fino is not None else ""
    if not mejor:
        mejor = transcribir_whisper(bloques)
    anota("parakeet: '%s' suena a ingles y tu hablas español; Whisper oye '%s'" % (rapido, mejor or "nada"))
    if not mejor:
        return rapido, ""
    return "", mejor


def oir_parakeet(bloques):
    """Lo que oye Parakeet, o "" (sin modelo, jugando, casi sin audio o sin cubrir la voz)."""
    if not bloques or jugando():
        return ""
    m = modelo_parakeet()
    if m is None:
        return ""
    # LA CARRERA CON EL JUEGO (18/09, 22:12): cargar tarda 11,5 s, el juego paso delante
    # mientras tanto y Parakeet tardo 32,9 s en 14 s de audio con 400 MB libres. Se mira
    # otra vez: con juego, lo oye Whisper base, que ya esta en la RAM y no la pelea.
    if jugando():
        anota("parakeet: el juego paso delante mientras cargaba; lo oye Whisper")
        return ""
    try:
        audio = np.concatenate(bloques).astype(np.float32) / 32768.0
        if audio.size < TASA // 4:
            return ""
        t0 = time.time()
        st = m.create_stream()
        st.accept_waveform(TASA, audio)
        m.decode_stream(st)
        texto = limpiar_whisper(st.result.text.strip())
        anota("parakeet: %.1f s de audio en %.2f s -> '%s'" % (audio.size / TASA, time.time() - t0, texto))
        if texto:
            c = cobertura_parakeet(texto, audio)
            if c < PARAKEET_COBERTURA_MIN:
                anota("parakeet: '%s' no cubre la voz (%.1f letras por segundo de voz, minimo %.0f); lo oye Whisper"
                      % (texto, c, PARAKEET_COBERTURA_MIN))
                return ""
        return texto
    except Exception as e:
        anota("WARN: fallo Parakeet (%s)" % e)
        return ""


def marcar_parakeet():
    if NIVEL:
        escribir(os.path.join(os.path.dirname(NIVEL), "dictado-motor.txt"), "parakeet")


def soltar_parakeet_si_toca():
    global _parakeet
    if _parakeet is not None and jugando():
        _parakeet = None
        import gc
        gc.collect()
        anota("parakeet soltado: hay un juego delante")


_ultimo = None
_ultimo_roto = False
_ultimo_uso = 0.0


def modelo_ultimo():
    """Turbo, cargado solo si llega a hacer falta. Antes se suelta small: los dos a la
    vez son ~1,5 GB y la Ally no va sobrada (small se recarga en ~3 s si vuelve a hacer
    falta)."""
    global _ultimo, _ultimo_roto, _preciso
    if _ultimo is not None or _ultimo_roto or not MODELO_ULTIMO:
        return _ultimo
    try:
        _preciso = None
        import gc
        gc.collect()
        t0 = time.time()
        from faster_whisper import WhisperModel
        _ultimo = WhisperModel(MODELO_ULTIMO, device="cpu", compute_type="int8", cpu_threads=HILOS_PRECISO)
        anota("ultimo recurso '%s' cargado en %.1f s" % (MODELO_ULTIMO, time.time() - t0))
    except Exception as e:
        _ultimo_roto = True
        anota("WARN: no se pudo cargar el ultimo recurso (%s)" % e)
    return _ultimo


def soltar_ultimo_si_toca():
    global _ultimo
    if _ultimo is None:
        return
    jugando = bool(MARCA_SOLO_BOTON) and os.path.exists(MARCA_SOLO_BOTON)
    if not jugando and time.time() - _ultimo_uso < ULTIMO_SOLTAR:
        return
    _ultimo = None
    import gc
    gc.collect()
    anota("ultimo recurso soltado (%s)" % ("hay un juego delante" if jugando else "sin usarse"))


def atender_reintento(ultimo_audio):
    """El asistente no reconocio la orden: se repasa el mismo audio con el
    modelo preciso (o, si pide "ultimo", con el ultimo recurso). Siempre se
    contesta algo, aunque sea vacio, porque el asistente espera con un plazo."""
    if not REINTENTO or not os.path.exists(REINTENTO):
        return False
    texto = ""
    try:
        pedido = ""
        try:
            with open(REINTENTO, encoding="utf-8", errors="replace") as f:
                pedido = f.read().strip()
        except Exception:
            pass
        ultimo = pedido == "ultimo" and bool(MODELO_ULTIMO)
        base = pedido == "base" and whisper is not None
        global _preciso_uso, _ultimo_uso
        if ultimo:
            m = modelo_ultimo()
            _ultimo_uso = time.time()
        elif base:
            # PARAKEET PRIMERO: Parakeet oyo algo que no es una orden; Whisper de siempre
            m = whisper
        else:
            m = modelo_preciso()
            _preciso_uso = time.time()
        duracion = sum(len(b) for b in ultimo_audio) / float(TASA) if ultimo_audio else 0.0
        if m is not None and duracion > REPASO_MAX and not base:
            # El 12/09 small tardo 24 y 35 s con audios largos, con el plazo del
            # asistente en 15 s y este hilo sordo todo ese rato. Una orden que
            # dura mas de esto es conversacion o ruido: no merece el repaso.
            anota("oido fino: %.1f s de audio es demasiado para repasar (tope %.0f s)"
                  % (duracion, REPASO_MAX))
        elif m is not None and ultimo_audio:
            t0 = time.time()
            # si el asistente se rinde (quita la marca), se deja de transcribir
            # en el siguiente segmento en vez de seguir sordo para nada
            texto = quitar_nombre(transcribir_whisper(
                ultimo_audio, m, seguir=lambda: os.path.exists(REINTENTO)))
            anota("%s: '%s' (%.1f s)" % ("ultimo recurso" if ultimo else ("whisper tras parakeet" if base else "oido fino"), texto, time.time() - t0))
            if _uso["id"] and grabar_uso_activo():
                apuntar_uso(dict(id=_uso["id"], hora=time.strftime("%Y-%m-%d %H:%M:%S"),
                                 motor="turbo" if ultimo else ("base" if base else "small"), texto=texto,
                                 seguridad=_ultima_seguridad, segundos=round(time.time() - t0, 2)))
        elif not ultimo_audio:
            anota("oido fino: no queda audio de la orden anterior")
    except Exception as e:
        anota("WARN: fallo el oido fino (%s)" % e)
    escribir(REINTENTO_TEXTO, texto)
    try:
        os.remove(REINTENTO)
    except Exception:
        pass
    vaciar_cola("oido fino")
    return True


def soltar_preciso_si_toca():
    global _preciso
    if _preciso is None:
        return
    quieto = time.time() - _preciso_uso
    hay_juego = bool(MARCA_SOLO_BOTON and os.path.exists(MARCA_SOLO_BOTON))
    # jugando, la RAM es del juego y se suelta antes; sin juego se espera mucho mas, pero
    # se suelta igual (ver PRECISO_SOLTAR_QUIETO)
    plazo = PRECISO_SOLTAR_JUGANDO if hay_juego else PRECISO_SOLTAR_QUIETO
    if quieto < plazo:
        return
    _preciso = None
    import gc
    gc.collect()
    anota("oido fino soltado: %s y lleva %.0f min sin usarse"
          % ("hay un juego delante" if hay_juego else "sin juego delante", quieto / 60))


def umbral_confianza(plano):
    """Cuanta confianza se le exige al nombre para dar por buena la activacion."""
    u = CONFIANZA_MIN
    if len(plano.split()) > PALABRAS_SIN_SOSPECHA:
        u = max(u, CONFIANZA_LARGA)
    # Si por los altavoces esta sonando algo, lo que entra por el microfono es
    # sospechoso por definicion: casi todo el ruido de anoche era eso.
    if nivel_salida() > UMBRAL_ALTAVOZ:
        u = max(u, CONFIANZA_LARGA)
    return u


def pct_dec():
    # Porcentaje de bloques que llegaron al decodificador EN LOS ULTIMOS ~5 MINUTOS
    # (ver VENTANA_DEC_CUBOS): mide el ahorro real de la puerta de energia AHORA, no
    # el promedio desde que arranco el proceso. Se suman los cubos ya cerrados MAS el
    # que se esta llenando, para que el numero no dependa de si el cubo actual acaba
    # de empezar (si no, cada 15 s el pulso daria un salto sin motivo).
    tot = bloques_totales + sum(t for t, _ in ventana_dec)
    dec = bloques_decodificados + sum(d for _, d in ventana_dec)
    if tot <= 0:
        return 0
    return int(100.0 * dec / tot)


def sin_tildes(s):
    d = unicodedata.normalize("NFD", s)
    return "".join(c for c in d if unicodedata.category(c) != "Mn").lower()


NOMBRE_PLANO = sin_tildes(NOMBRE)
# \b = limite de PALABRA. Antes se usaba endswith(), que es coincidencia de
# subcadena: "genova" o "innova" activaban el asistente.
PATRON_NOMBRE = re.compile(r"\b" + re.escape(NOMBRE_PLANO) + r"\b")
# Gramatica CERRADA: se le dice al decodificador que solo existen estas frases
# (mas [unk] para todo lo demas). Reduce falsos positivos de raiz -el modelo ya
# no puede "alucinar" el nombre dentro de una conversacion cualquiera- y ademas
# abarata cada decodificacion, porque el grafo de busqueda es diminuto.
GRAMATICA = json.dumps([
    NOMBRE_PLANO,
    "oye " + NOMBRE_PLANO,
    "hola " + NOMBRE_PLANO,
    "ey " + NOMBRE_PLANO,
    NOMBRE_PLANO + " escucha",
    NOMBRE_PLANO + " por favor",
    "[unk]",
], ensure_ascii=False)
CONFIANZA_MIN = CONFIANZA_ARG if CONFIANZA_ARG is not None else 0.55
# --- LA FIRMA DEL FALSO POSITIVO ---
# La gramatica de arriba es CERRADA: ante cualquier ruido el decodificador esta
# OBLIGADO a devolver algo de esa lista, y lo que devuelve entonces son
# engendros como "ey favor ey nova" o "por hola nova" (log del 11/09). Cuando
# de verdad llamas, dices una frase limpia y corta. Asi que a partir de tres
# palabras se exige mucha mas confianza: no cuesta nada y no toca el caso
# normal, que es decir "nova" a secas.
CONFIANZA_LARGA = 0.85
PALABRAS_SIN_SOSPECHA = 2
GRAMATICA_SI_NO = json.dumps(["si", "si dale", "dale", "vale", "claro", "ok", "no", "no cancela", "cancela", "[unk]"], ensure_ascii=False)
PALABRAS_SI = ("si", "dale", "vale", "claro", "ok")
PALABRAS_NO = ("no", "cancela")

base = os.path.dirname(os.path.abspath(__file__))
ruta_modelo = os.path.join(base, "vosk", "vosk-model-small-es-0.42")
if not os.path.isdir(ruta_modelo):
    anota("ERROR: falta el modelo en %s" % ruta_modelo)
    sys.exit(1)

def nuevo_reconocedor():
    r = KaldiRecognizer(modelo, TASA, GRAMATICA)
    r.SetWords(True)   # necesario para leer la confianza por palabra
    return r


def reconocedor_libre():
    # sin gramatica: transcripcion abierta, para dictar la orden completa
    r = KaldiRecognizer(modelo, TASA)
    r.SetWords(False)
    return r


def reconocedor_si_no():
    r = KaldiRecognizer(modelo, TASA, GRAMATICA_SI_NO)
    r.SetWords(False)
    return r


# QUITADA leer_vocabulario() el 19/09: no la llamaba nadie (ver argv[13] arriba).
def limpiar_whisper(texto):
    # Whisper puntua y pone mayusculas; la capa local espera texto plano.
    # Los puntos internos se vuelven comas (separan ordenes) y el final se quita.
    t = (texto or "").strip()
    t = re.sub(r"\s*\.\s+", ", ", t)
    t = re.sub(r"[.…!?]+$", "", t).strip()
    return t


# --- VOZ POR TONO ---
# Estimacion sencilla del tono fundamental (autocorrelacion) de la orden
# dictada, para distinguir voces por su altura: no es identificacion de
# hablante de verdad, pero separa razonablemente dos o tres personas. Las
# voces vistas se guardan junto al estado (voces.json) y se entrega el indice.
def estimar_f0(bloques):
    if not bloques:
        return 0.0
    audio = np.concatenate(bloques).astype(np.float32) / 32768.0
    tam = 800   # 50 ms a 16 kHz
    lo, hi = int(TASA / 400), int(TASA / 70)   # 70-400 Hz
    f0s = []
    tramos = 0
    for i in range(0, len(audio) - tam, tam):
        if tramos >= 60:
            break
        tr = audio[i:i + tam]
        if float(np.sqrt(np.mean(tr * tr))) < 0.03:
            continue
        tramos += 1
        tr = tr - float(np.mean(tr))
        ac = np.correlate(tr, tr, mode="full")[tam - 1:]
        if ac[0] <= 0:
            continue
        seg = ac[lo:hi]
        if seg.size == 0:
            continue
        k = int(np.argmax(seg)) + lo
        if ac[k] / ac[0] < 0.3:
            continue
        f0s.append(TASA / float(k))
    if len(f0s) < 5:
        return 0.0
    return float(np.median(f0s))


def indice_voz(f0):
    if f0 <= 0 or not NIVEL:
        return 0
    ruta = os.path.join(os.path.dirname(NIVEL), "voces.json")
    voces = []
    try:
        with open(ruta, "r", encoding="utf-8") as f:
            voces = json.load(f)
    except Exception:
        voces = []
    mejor = -1
    for i, v in enumerate(voces):
        if abs(v.get("f0", 0) - f0) <= 22 and (mejor < 0 or abs(voces[mejor]["f0"] - f0) > abs(v["f0"] - f0)):
            mejor = i
    if mejor < 0:
        if len(voces) >= 4:
            return 0
        voces.append({"f0": round(f0, 1), "n": 1})
        mejor = len(voces) - 1
    else:
        v = voces[mejor]
        n = int(v.get("n", 1))
        v["f0"] = round((v["f0"] * n + f0) / (n + 1), 1)
        v["n"] = n + 1
    try:
        with open(ruta, "w", encoding="utf-8") as f:
            json.dump(voces, f)
    except Exception:
        pass
    return mejor


def anotar_voz(bloques):
    """Apunta el tono del dictado para el asistente y lo devuelve (0 si no se sabe)."""
    if not NIVEL:
        return 0.0
    try:
        f0 = estimar_f0(bloques)
        idx = indice_voz(f0)
        escribir(os.path.join(os.path.dirname(NIVEL), "dictado-voz.txt"), "%d %.0f" % (idx, f0))
        if f0 > 0:
            anota("voz: tono %.0f Hz -> voz %d" % (f0, idx))
        return float(f0)
    except Exception:
        return 0.0


def voz_duena():
    """El tono de la voz de braya que el asistente ha aprendido de sus ordenes
    (mi-voz.json, junto a los demas archivos de estado), o 0 si aun no lo sabe."""
    try:
        with open(os.path.join(os.path.dirname(NIVEL), "mi-voz.json"), encoding="utf-8") as f:
            d = json.load(f)
        return float(d.get("f0", 0)) if int(d.get("n", 0)) >= 12 else 0.0
    except Exception:
        return 0.0


def transcribir_whisper(bloques, modelo=None, seguir=None):
    # bloques: lista de arrays int16 ya amplificados
    global _ultima_seguridad
    _ultima_seguridad = None
    modelo = modelo or whisper
    if modelo is None or not bloques:
        return ""
    audio = np.concatenate(bloques).astype(np.float32) / 32768.0
    if audio.size < TASA // 4:
        return ""
    tope = int(TASA * TRANSCRIBIR_MAX)
    if audio.size > tope:
        anota("audio de %.1f s recortado a %.0f s: una orden no dura tanto"
              % (audio.size / TASA, TRANSCRIBIR_MAX))
        audio = audio[:tope]
    t0 = time.time()
    # FRASE DE EJEMPLO, NO LISTA DE NOMBRES (ver PROMPT_ORDENES). Historia: el 11/09
    # se quito un initial_prompt que llevaba la lista de apps y juegos, porque con
    # audio flojo Whisper la continuaba ("SILENT BREATH, PEAK...") y eso se ejecutaba;
    # se cambio por hotwords. Con las 100 grabaciones (14/09) se vio que las hotwords
    # tambien lo arrastraban a esos nombres, y que una frase corta de ordenes en
    # espanol, sin nombres, acierta mucho mas y no convierte el ruido en ordenes.
    # Los tres umbrales descartan el segmento cuando no hay voz de verdad:
    # sin ellos Whisper siempre devuelve algo, aunque el audio sea ruido.
    segmentos, info = modelo.transcribe(
        audio, language=idioma_dictado(), beam_size=2, best_of=1,
        vad_filter=True, vad_parameters=dict(min_silence_duration_ms=500),
        condition_on_previous_text=False,
        no_speech_threshold=0.6,
        log_prob_threshold=-1.0,
        compression_ratio_threshold=2.4,
        initial_prompt=PROMPT_ORDENES)
    # los segmentos salen de uno en uno (el trabajo se hace al pedirlos): entre
    # uno y otro se puede mirar si todavia hace falta seguir
    partes = []
    peor = 0.0      # el trozo con menos seguridad (avg_logprob: 0 es seguro, -1 muy dudoso)
    for s in segmentos:
        partes.append(s.text.strip())
        peor = min(peor, float(getattr(s, "avg_logprob", 0.0) or 0.0))
        if seguir is not None and not seguir():
            anota("whisper: cortado a medias, ya no hace falta")
            break
    texto = " ".join(partes).strip()
    _ultima_seguridad = round(peor, 2) if texto else None
    if NIVEL and texto:
        # LA SEGURIDAD DEL DICTADO (14/09): el asistente la mira para confirmar el
        # dato de una receta antes de usar un nombre que quiza oyo mal
        # y si lo oido es un ECO de la frase de ejemplo (ver es_eco_del_ejemplo)
        escribir(os.path.join(os.path.dirname(NIVEL), "dictado-confianza.txt"),
                 "%.2f%s" % (peor, " eco" if es_eco_del_ejemplo(texto) else ""))
    anota("whisper: %.1f s de audio en %.2f s -> '%s'" % (audio.size / TASA, time.time() - t0, texto))
    return limpiar_whisper(texto)


# Segunda red por si el nombre se cuela igual: se quita del principio de la
# orden. "nova abre steam" debe ejecutarse como "abre steam".
PATRON_INICIO = re.compile(
    r"^\s*(?:oye\s+|hola\s+|ey\s+)?" + re.escape(NOMBRE_PLANO) + r"\b[\s,.]*", re.IGNORECASE)


# EL IDIOMA DEL DICTADO (13/09): "traduce lo que diga". El asistente deja el
# codigo (en, fr...) en idioma-dictado.txt, junto a los demas archivos de estado,
# y lo quita al terminar. Sin archivo, espanol.
def idioma_dictado():
    try:
        ruta = os.path.join(os.path.dirname(NIVEL), "idioma-dictado.txt") if NIVEL else ""
        if not ruta or not os.path.exists(ruta):
            return "es"
        with open(ruta, encoding="utf-8") as f:
            v = f.read().strip().lower()
        return v if re.match(r"^[a-z]{2}$", v) else "es"
    except Exception:
        return "es"


# GRABAR EL USO (15/09): con config.json -> escucha.grabarUso, cada orden dictada se
# guarda en pruebas/audio/uso (un WAV) y lo que oyo cada modelo en registro.jsonl.
# Las tandas de grabar-100 median tu voz LEYENDO; en uso real se habla mas rapido y
# cortado ("abre spotify": 0,7 s en vivo frente a 1,2 s grabado), y la prueba en vivo
# del 15/09 fue mucho peor de lo que decian. Esto mide con la voz de verdad. No sale
# de la maquina: pruebas/audio/ esta en .gitignore.
USO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pruebas", "audio", "uso")
_uso = {"id": "", "activo": None}
_ultima_seguridad = None


def grabar_uso_activo():
    if _uso["activo"] is None:
        try:
            with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json"), encoding="utf-8-sig") as f:
                _uso["activo"] = bool((json.load(f).get("escucha") or {}).get("grabarUso", False))
        except Exception:
            _uso["activo"] = False
        if _uso["activo"]:
            anota("grabar el uso: cada orden se guarda en %s" % USO_DIR)
    return _uso["activo"]


def apuntar_uso(campos):
    try:
        os.makedirs(USO_DIR, exist_ok=True)
        with open(os.path.join(USO_DIR, "registro.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(campos, ensure_ascii=False) + "\n")
    except Exception as e:
        anota("WARN: no pude apuntar el uso (%s)" % e)


def guardar_uso(bloques, **campos):
    if not bloques or not grabar_uso_activo():
        return
    try:
        import wave
        os.makedirs(USO_DIR, exist_ok=True)
        ident = time.strftime("%Y%m%d-%H%M%S")
        if os.path.exists(os.path.join(USO_DIR, ident + ".wav")):
            ident += "-%03d" % int(time.time() * 1000 % 1000)
        datos = np.concatenate(bloques).astype(np.int16)
        with wave.open(os.path.join(USO_DIR, ident + ".wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TASA)
            w.writeframes(datos.tobytes())
        _uso["id"] = ident
        # QUE HIZO NOVA CON ESTO (17/09): aqui solo sabemos lo que se OYO. El asistente
        # apunta aparte a donde fue a parar la frase, y necesita saber de cual hablamos:
        # se le deja el id, como ya se le deja el motor o la confianza. Va dentro de
        # guardar_uso a proposito, que es el unico sitio por el que pasan los dos
        # caminos (el boton y la activacion por nombre).
        if NIVEL:
            escribir(os.path.join(os.path.dirname(NIVEL), "dictado-id.txt"), ident)
        apuntar_uso(dict(id=ident, hora=time.strftime("%Y-%m-%d %H:%M:%S"), dur=round(datos.size / float(TASA), 2),
                         pico=round(float(np.max(np.abs(datos.astype(np.int32)))) / 32768.0, 3), **campos))
    except Exception as e:
        anota("WARN: no pude guardar el uso (%s)" % e)


# EL AUDIO DE LA ULTIMA ORDEN (16/09), siempre en el mismo sitio: tmp\ultima-orden.wav.
# Es lo que permite al asistente pedir una segunda opinion a la nube cuando la capa
# local no entiende, sin tener que volver a hablar. Se pisa en cada orden y no sale de
# la maquina salvo que el propio asistente lo mande (y eso solo con nubeOir puesto).
def guardar_ultima_orden(bloques):
    if not bloques or not NIVEL:
        return
    try:
        import wave
        destino = os.path.join(os.path.dirname(NIVEL), "ultima-orden.wav")
        datos = np.concatenate(bloques).astype(np.int16)
        with wave.open(destino + ".tmp", "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TASA)
            w.writeframes(datos.tobytes())
        # se escribe aparte y se renombra: si el asistente lo lee a medias, lee basura
        os.replace(destino + ".tmp", destino)
    except Exception as e:
        anota("WARN: no pude guardar el audio de la ultima orden (%s)" % e)


# NOTAS DE VOZ (13/09): si el asistente dejo una ruta en guardar-audio.txt, el
# audio del dictado que acaba de terminar se guarda ahi en WAV (16 kHz, mono).
def guardar_audio_si_toca(bloques):
    try:
        ruta_pedido = os.path.join(os.path.dirname(NIVEL), "guardar-audio.txt") if NIVEL else ""
        if not ruta_pedido or not os.path.exists(ruta_pedido):
            return
        with open(ruta_pedido, encoding="utf-8") as f:
            destino = f.read().strip()
        os.remove(ruta_pedido)
        if not destino or not bloques:
            return
        import wave
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        datos = np.concatenate(bloques).astype(np.int16).tobytes()
        with wave.open(destino, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(TASA)
            w.writeframes(datos)
        anota("nota de voz guardada (%.1f s)" % (len(datos) / 2.0 / TASA))
    except Exception as e:
        anota("WARN: no pude guardar la nota de voz (%s)" % e)


# INTERRUMPIR A NOVA (13/09): mientras habla, el microfono ya no se tira del
# todo. Si la marca de pausa dice "voz:<lo que esta diciendo>", un reconocedor
# con gramatica cerrada escucha solo "espera", "para", "calla"... La palabra que
# esta en su propia frase se descarta (seria su eco), y hace falta confianza alta.
PALABRAS_CORTE = ["espera", "para", "calla", "callate", "basta", "silencio"]
_corte = {"rec": None, "marca": None, "texto": set(), "leido": 0.0, "audio": [], "base": 0}
# LA PROPIA VOZ DE NOVA LA INTERRUMPIA (14/09): las 3 interrupciones del log fueron
# falsas ("callate" 1,00 y 0,98, "silencio" 0,95) en charlas sin nadie hablando: con
# gramatica cerrada, su voz por el altavoz acaba sonando a una de estas palabras, y
# la confianza no lo separa. El TONO si: medido con estimar_f0, las 20 grabaciones
# de braya van de 111 a 126 Hz y la voz de Nova, en trozos de 0,6 s, de 165 a 327.
# Con 40 Hz de margen sobre el tono aprendido no se pierde ninguna de braya ni se
# cuela ningun trozo de Nova. Un grito muy agudo podria no valer: queda el boton.
# 14/09, 100 grabaciones: gritando "basta" llegaste a 37 Hz de tu tono normal.
MARGEN_CORTE_HZ = 42.0
AUDIO_CORTE_MAX = 30 * TASA     # lo que se guarda para medir la palabra, como mucho


def es_voz_de_braya(f0, duena):
    """Una palabra de corte vale si su tono es el de braya. Sin tono aprendido
    todavia, vale (como antes). Con tono aprendido pero SIN tono medible en la
    palabra, NO vale: en vivo el 14/09 se colo un "espera" con tono 0 mientras Nova
    hablaba sola. Mientras habla, cortar de mas es peor; el boton corta siempre."""
    if duena <= 0:
        return True
    if f0 <= 0:
        return False
    return abs(f0 - duena) <= MARGEN_CORTE_HZ


# EL NOMBRE TAMBIEN CORTA (18/09): decir "nova" mientras habla la interrumpe y la deja
# escuchando la orden nueva, igual que "para". Seguro por las dos guardas que ya habia: si
# "nova" esta en la frase que ella misma dice se ignora (anti-eco), y solo vale con tu tono.
def _palabras_corte():
    return PALABRAS_CORTE + ([NOMBRE] if NOMBRE and NOMBRE not in PALABRAS_CORTE else [])


def _reconocedor_corte():
    r = KaldiRecognizer(modelo, TASA, json.dumps(_palabras_corte() + ["[unk]"]))
    r.SetWords(True)
    return r


def vigilar_corte(datos):
    if not PAUSA or not NIVEL or datos is None:
        return
    ahora = time.time()
    if ahora - _corte["leido"] > 0.3:
        _corte["leido"] = ahora
        try:
            with open(PAUSA, encoding="utf-8", errors="replace") as f:
                marca = f.read()
        except Exception:
            marca = ""
        if not marca.startswith("voz:"):
            _corte.update(rec=None, marca=None)
            return
        if marca != _corte["marca"]:
            _corte.update(marca=marca, texto=set(marca[4:].split()), rec=_reconocedor_corte(), audio=[], base=0)
    if _corte["rec"] is None:
        return
    try:
        m = np.clip(np.frombuffer(datos, dtype=np.int16).astype(np.float32) * ganancia, -32768, 32767)
        m16 = m.astype(np.int16)
        _corte["audio"].append(m16)
        total = sum(len(b) for b in _corte["audio"])
        while total > AUDIO_CORTE_MAX and len(_corte["audio"]) > 1:
            fuera = _corte["audio"].pop(0)
            total -= len(fuera)
            _corte["base"] += len(fuera)
        if not _corte["rec"].AcceptWaveform(m16.tobytes()):
            return
        res = json.loads(_corte["rec"].Result())
        for w in res.get("result") or []:
            palabra = w.get("word", "")
            conf = float(w.get("conf", 0))
            if palabra in _palabras_corte() and palabra not in _corte["texto"] and conf >= 0.9:
                # el tono del trozo EXACTO de la palabra (con un margen), no del audio
                # entero: si braya lo dice encima de Nova, ese trozo es sobre todo suyo
                f0 = 0.0
                try:
                    todo = np.concatenate(_corte["audio"])
                    # +-0,4 s: con +-0,15 una palabra de Nova quedo sin tono medible (14/09)
                    s0 = max(0, int((float(w.get("start", 0)) - 0.4) * TASA) - _corte["base"])
                    s1 = max(s0, int((float(w.get("end", 0)) + 0.4) * TASA) - _corte["base"])
                    f0 = estimar_f0([todo[s0:s1]])
                except Exception as _e_tono:  # noqa: BLE001
                    # sin esto, un fallo aqui deja f0 = 0.0 y, con el tono ya aprendido,
                    # es_voz_de_braya(0, duena) da falso: Nova NO SE CALLA cuando se lo dices
                    # y no queda ni una linea. Que obedezca ante tono desconocido es otra
                    # mejora (la 2 de este hallazgo) y se decide aparte.
                    anota("no pude medir el tono de la palabra de corte (%s)" % _e_tono)
                    f0 = 0.0
                duena = voz_duena()
                if not es_voz_de_braya(f0, duena):
                    anota("corte descartado: '%s' (confianza %.2f) con tono %.0f Hz, y el tuyo es %.0f: es mi propia voz"
                          % (palabra, conf, f0, duena))
                    continue
                escribir(os.path.join(os.path.dirname(NIVEL), "corte.flag"), palabra)
                anota("interrumpida: '%s' (confianza %.2f, tono %.0f Hz) mientras hablaba" % (palabra, conf, f0))
                _corte["rec"] = _reconocedor_corte()
                _corte["audio"] = []
                _corte["base"] = 0
                return
    except Exception as e:  # noqa: BLE001
        anota("WARN: vigilar el corte fallo (%s)" % e)
        _corte["rec"] = None


def quitar_nombre(texto):
    return PATRON_INICIO.sub("", texto or "").strip()


# TOPE DE AVISOS DE ESCRITURA (18/09). Por aqui sale tambien el NIVEL del audio, que se
# escribe constantemente mientras dictas: si el disco falla, anotar sin freno llenaria el log
# con miles de lineas. Mismo criterio que la capsula con sus errores de animacion.
_avisos_escribir = 0
MAX_AVISOS_ESCRIBIR = 5


def escribir(ruta, contenido):
    if not ruta:
        return
    # ATOMICO: se escribe aparte y se cambia de golpe, para que el asistente no
    # lea nunca un archivo a medio escribir (un texto de orden cortado). Si el
    # cambio falla porque justo lo tiene abierto el lector, se escribe directo
    # como antes: mejor eso que perder la escritura.
    global _avisos_escribir
    tmp = ruta + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(contenido)
        os.replace(tmp, ruta)
        return
    except Exception as e:  # noqa: BLE001
        # no es grave por si solo: abajo se reintenta escribiendo directo
        if _avisos_escribir < MAX_AVISOS_ESCRIBIR:
            _avisos_escribir += 1
            anota("escritura atomica fallida en %s (%s); lo intento directo" % (os.path.basename(ruta), e))
    try:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(contenido)
    except Exception as e:  # noqa: BLE001
        # ESTO SI ES GRAVE: por aqui salen la orden, la confirmacion y el parcial. Si se
        # pierde, el asistente no se entera de nada y solo ve vencer su plazo.
        if _avisos_escribir < MAX_AVISOS_ESCRIBIR:
            _avisos_escribir += 1
            anota("NO PUDE ESCRIBIR %s (%s): lo que iba ahi se ha perdido" % (os.path.basename(ruta), e))


try:
    modelo = Model(ruta_modelo)
    rec = nuevo_reconocedor()
    dispositivo = sd.query_devices(sd.default.device[0])["name"]
except Exception as e:
    anota("ERROR al iniciar: %s" % e)
    sys.exit(1)

whisper = None
if MOTOR_DICTADO.startswith("whisper"):
    nombre_modelo = MOTOR_DICTADO.split(":", 1)[1] if ":" in MOTOR_DICTADO else "small"
    try:
        t0 = time.time()
        from faster_whisper import WhisperModel
        # int8 en CPU: ~500 MB con "small". 8 hilos, como el oido fino: medido el
        # 14/09 con las 20 grabaciones, base pasa de 2,0 a 1,7 s por orden con los
        # mismos aciertos. No le quita CPU al juego: este proceso corre con
        # prioridad baja y solo trabaja a rachas, al dictar.
        whisper = WhisperModel(nombre_modelo or "small", device="cpu", compute_type="int8", cpu_threads=HILOS_PRECISO)
        # calentamiento: la primera transcripcion tarda 3 s; mejor ahora que
        # en la primera orden
        list(whisper.transcribe(np.zeros(TASA, dtype=np.float32), language="es", beam_size=1)[0])
        anota("whisper '%s' cargado en %.1f s" % (nombre_modelo, time.time() - t0))
    except Exception as e:
        whisper = None
        anota("WARN: no se pudo cargar Whisper (%s); el dictado usara Vosk" % e)

cola = queue.Queue()


# MICROFONO MUERTO: tras suspender el equipo o cambiar de dispositivo, el
# stream puede seguir "abierto" sin entregar un solo bloque. El worker parecia
# vivo y la palabra de activacion dejaba de funcionar en silencio. Se apunta
# cuando llego el ultimo bloque (desde el hilo del audio) y el bucle sale si
# pasa demasiado; el asistente lo relanza y el stream se abre de nuevo.
MIC_MUERTO = 5.0
ultima_llegada = time.time()

# EL ASISTENTE SIGUE VIVO? (auditoria del 13/09): si el asistente moria, este
# worker seguia con el microfono, y al volver a arrancar quedaban dos
# escuchando. El asistente pasa su PID en NOVA_PID_PADRE; se mira en cada pulso.
try:
    PID_PADRE = int(os.environ.get("NOVA_PID_PADRE", "0") or 0)
except ValueError:
    PID_PADRE = 0


def padre_vivo():
    if not PID_PADRE:
        return True
    try:
        import ctypes
        k32 = ctypes.windll.kernel32
        h = k32.OpenProcess(0x1000, False, PID_PADRE)   # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        codigo = ctypes.c_ulong()
        ok = k32.GetExitCodeProcess(h, ctypes.byref(codigo))
        k32.CloseHandle(h)
        return (not ok) or codigo.value == 259   # 259 = STILL_ACTIVE
    except Exception:
        return True


def entrada(datos, marcos, tiempo, estado):
    global ultima_llegada
    ultima_llegada = time.time()
    cola.put(bytes(datos))


def vaciar_cola(motivo):
    # Transcribir con Whisper bloquea este hilo 10-40 s, y el microfono no se
    # para: la cola se llena de audio viejo. Al volver al bucle se decodificaba
    # todo ese rato de golpe y a maxima velocidad, con lo que el asistente se
    # "activaba" con su propia voz y con conversacion de hace medio minuto.
    # Ese audio ya no vale para nada: se tira.
    n = 0
    while True:
        try:
            cola.get_nowait()
            n += 1
        except queue.Empty:
            break
    if n > 2:
        anota("descartados %.1f s de audio atrasado (%s)" % (n * 0.25, motivo))
    return n


automatica = (GANANCIA_ARG == "auto")
# La ganancia buena depende del microfono, y no cambia de un dia para otro.
# Arrancar siempre en x8 significaba varios minutos de audio saturado hasta que
# la calibracion bajaba sola -justo los minutos en los que no se entendia nada.
# Se recuerda la ultima y se empieza ahi.
RUTA_GANANCIA = os.path.join(os.path.dirname(NIVEL), "ganancia.txt") if NIVEL else ""
# Estado legible para el asistente, escrito en cada pulso. Sirve para que
# puedas preguntarle "¿como me oyes?" en vez de tener que abrir el log.
RUTA_ESTADO = os.path.join(os.path.dirname(NIVEL), "escucha-estado.txt") if NIVEL else ""
# Mientras exista esta marca no se evalua la palabra de activacion: solo el
# boton. La crea el asistente cuando hay un juego en primer plano. El dictado
# y la confirmacion siguen funcionando con normalidad.
MARCA_SOLO_BOTON = os.path.join(os.path.dirname(NIVEL), "solo-boton.flag") if NIVEL else ""
LOTENGO = os.path.join(os.path.dirname(NIVEL), "lotengo.txt") if NIVEL else ""


def ganancia_guardada():
    if not RUTA_GANANCIA:
        return None
    try:
        with open(RUTA_GANANCIA, "r", encoding="utf-8") as f:
            g = float(f.read().strip())
        if GANANCIA_MIN <= g <= GANANCIA_MAX:
            return g
    except Exception:
        pass
    return None


ganancia = GANANCIA_INICIAL if automatica else float(GANANCIA_ARG)
if automatica:
    _g = ganancia_guardada()
    if _g is not None:
        # SE CONFIA EN LA CALIBRACION GUARDADA (16/09). Aqui habia una regla que
        # descartaba cualquier ganancia por debajo de x1.5 y empezaba en x8, porque
        # "la voz entra a 0.02-0.05 y hace falta amplificar entre x8 y x26". Eso era
        # verdad con el microfono de entonces; con el de ahora la voz entra a p90
        # 0.47-0.99 con x0.7, muy por encima de PICO_OBJETIVO (0.35).
        #
        # El efecto era el peor posible, y esta medido: la calibracion buena se tiro 38
        # veces (dos el 16/09: x1.1 y x0.8 sustituidas por x8.0). Arrancando a x8, el
        # ruido de fondo se amplificaba hasta activar a Nova SOLA -6 de las 13
        # activaciones de ese dia con pico 0.000- y, como bajar es lento a proposito
        # (factor 0.2), el descenso duraba minutos: por eso las falsas caian a x3.6,
        # x2.9, x2.7 y x2.1. Mientras tanto la voz de verdad saturaba y no se reconocia.
        # Un unico fallo causaba las dos quejas: "se activa sola" y "cuando le digo nova
        # no me hace caso nunca".
        #
        # Arrancar desde lo guardado es seguro: el pulso recalcula la ganancia DESDE
        # CERO (PICO_OBJETIVO / pico crudo) en cuanto hay voz sostenida, y para SUBIR es
        # rapido (factor 0.6). Si el valor guardado fuera malo se corrige solo en
        # segundos; el descarte, en cambio, estropeaba TODOS los arranques. El rango ya
        # lo valida ganancia_guardada(), que solo acepta entre GANANCIA_MIN y _MAX.
        ganancia = _g
        anota("ganancia recordada de la sesion anterior: x%.1f" % ganancia)
# NOTA: aqui hubo una 'ganancia_limpia' como red de seguridad, para recuperar
# la ultima calibracion hecha en silencio. Era codigo muerto: los dos unicos
# caminos que bajan la ganancia (el pulso y el detector de recorte) ya
# comprueban nivel_salida() antes de tocarla, asi que la copia acababa siempre
# valiendo lo mismo que el original y la recuperacion no podia dispararse
# jamas. La proteccion de verdad es que el medidor siga vivo, y de eso se
# encarga nivel_salida(), que se rehace sola si falla o si cambias de salida.

anota("worker Vosk en marcha: nombre='%s' dispositivo='%s' ganancia=%s"
      % (NOMBRE, dispositivo, "auto" if automatica else ganancia))

ultimo_pulso = time.time()
recortes = 0
ultimo_aviso_recorte = 0.0
ultimo_aviso_solo_boton = 0.0
pausado = False
arrastre = 0
dictando = False
dictado = []
audio_dictado = []      # bloques amplificados de la orden, para Whisper
origen_nombre = False   # el dictado lo abrio el nombre (no el boton ni un seguimiento)
ultimo_audio = []       # el de la ULTIMA orden, por si hay que repasarlo (oido fino)
confirmando = False
conf_inicio = 0.0
dicta_inicio = 0.0
ultima_voz = 0.0
prebuffer = collections.deque(maxlen=PREBUFFER)
bloques_totales = 0         # OJO: es el cubo ABIERTO, no el total del proceso
bloques_decodificados = 0
ventana_dec = collections.deque(maxlen=VENTANA_DEC_CUBOS)   # cubos ya cerrados
cubo_dec_desde = time.time()
picos = []
bloques_voz = 0
# QUITADA pico_voz el 19/09: se actualizaba en cada texto reconocido y no la leia
# nadie; el pico que SI se usa al activar y en el log es pico_rafaga.
pico_rafaga = 0.0       # pico de la rafaga que se esta decodificando ahora
ultima_marca = 0.0

try:
    with sd.RawInputStream(samplerate=TASA, blocksize=4000, dtype="int16",
                           channels=1, callback=entrada):
        while True:
            try:
                try:
                    datos = cola.get(timeout=0.5)
                except queue.Empty:
                    datos = None

                ahora = time.time()
                crudo = datos   # se conserva para medir el nivel aunque se tire
                if datos is None and ahora - ultima_llegada > MIC_MUERTO:
                    anota("ERROR: el microfono lleva %.0f s sin entregar audio; salgo para que me relancen"
                          % (ahora - ultima_llegada))
                    sys.exit(3)

                # PAUSA: el asistente esta hablando o dictando. Se tira el audio
                # sin mirarlo y sin recalibrar; al reanudar se reinicia el
                # reconocedor para no arrastrar restos de su propia voz.
                if PAUSA and os.path.exists(PAUSA):
                    if not pausado:
                        pausado = True
                        anota("pausa: el asistente habla o dicta, se ignora el microfono")
                    vigilar_corte(datos)   # salvo "espera", "para"... (ver INTERRUMPIR A NOVA)
                    datos = None
                    picos = []
                    bloques_voz = 0
                    ultimo_pulso = ahora
                elif pausado:
                    pausado = False
                    vaciar_cola("fin de pausa")
                    datos = None
                    # mismo cuidado que al salir de confirmacion: si hay un dictado
                    # abierto (el asistente hablo en mitad de uno, por ejemplo un
                    # recordatorio), cambiar de reconocedor lo deja mudo
                    if not dictando:
                        rec = nuevo_reconocedor()
                    anota("pausa: fin, escuchando de nuevo")

                # --- el asistente pide repasar la ultima orden con el oido fino ---
                # Sin 'continue': saltaria tambien el pulso del final del bucle.
                # Y NO mientras se dicta o se confirma: el repaso bloquea el hilo
                # varios segundos y al terminar vacia la cola, o sea que se llevaria
                # por delante el audio de la orden que se este dictando ahora mismo.
                if not dictando and not confirmando:
                    atender_reintento(ultimo_audio)
                    soltar_preciso_si_toca()
                    soltar_ultimo_si_toca()
                    soltar_parakeet_si_toca()

                # --- entrar y salir del modo dictado ---
                quiere_dictar = bool(DICTAR) and os.path.exists(DICTAR)
                # 'not confirmando' es tan necesario como el 'not dictando' que
                # lleva la entrada a confirmacion: con las dos marcas puestas, el
                # 'continue' del bloque de confirmacion impedia que el dictado
                # avanzara nunca, dictar.flag no se borraba y el asistente se
                # quedaba esperando hasta agotar su plazo.
                if quiere_dictar and not dictando and not confirmando:
                    dictando = True
                    # SEGUIMIENTO: la marca lleva "seguimiento:<ms>"; si no hay voz
                    # en ese plazo, se cierra en silencio con texto vacio
                    espera_voz = 0.0
                    origen_nombre = False
                    try:
                        with open(DICTAR, "r", encoding="utf-8") as f:
                            contenido = f.read().strip()
                        origen_nombre = (contenido == "nombre")
                        if contenido.startswith("seguimiento:"):
                            espera_voz = float(contenido.split(":", 1)[1]) / 1000.0
                    except Exception:
                        espera_voz = 0.0
                    hubo_voz = 0
                    voz_seguimiento_en = None
                    # Se tira el audio ya encolado: contiene el final de "Nova" y
                    # se transcribia como si fuera la orden.
                    try:
                        while True:
                            cola.get_nowait()
                    except queue.Empty:
                        pass
                    datos = None
                    rec = reconocedor_libre()
                    dictado = []
                    audio_dictado = []
                    dicta_inicio = ahora
                    ultima_voz = ahora
                    escribir(PARCIAL, "")
                    anota("dictado: escuchando la orden")
                elif dictando and not quiere_dictar:
                    # el asistente lo corto a mano (boton): se entrega lo que haya
                    texto_final = " ".join([t for t in dictado if t]).strip()
                    parcial = json.loads(rec.FinalResult()).get("text", "")
                    if parcial:
                        texto_final = (texto_final + " " + parcial).strip()
                    rapido = oir_parakeet(audio_dictado)
                    mejor = ""
                    _ultima_seguridad = None
                    oido_parakeet = rapido
                    rapido, mejor = repasar_si_ingles(rapido, audio_dictado)   # ver PARAKEET OYE INGLES
                    if rapido:
                        texto_final = rapido
                        marcar_parakeet()
                        vaciar_cola("corte a mano")
                    elif mejor:
                        texto_final = mejor
                        vaciar_cola("corte a mano")
                    elif whisper is not None:
                        mejor = transcribir_whisper(audio_dictado)
                        if mejor:
                            texto_final = mejor
                        # Whisper bloquea el hilo varios segundos y mientras tanto
                        # la cola se llena. Sin vaciarla, al volver al bucle se
                        # decodifica de golpe el audio de hace medio minuto con el
                        # reconocedor de activacion: activaciones fantasma. El
                        # camino normal ya lo hacia; este, el del boton, no.
                        vaciar_cola("corte a mano")
                    texto_final = quitar_nombre(texto_final)
                    anota("dictado: cortado a mano -> '%s'" % texto_final)
                    escribir(TEXTO, texto_final)
                    guardar_uso(audio_dictado, origen="boton", parakeet=oido_parakeet, whisper=mejor,
                                seguridad=_ultima_seguridad, entregado=texto_final)
                    dictando = False
                    ultimo_audio = audio_dictado
                    guardar_ultima_orden(ultimo_audio)   # ver EL AUDIO DE LA ULTIMA ORDEN
                    guardar_audio_si_toca(ultimo_audio)
                    audio_dictado = []
                    rec = nuevo_reconocedor()

                # --- entrar y salir del modo confirmacion (si/no) ---
                quiere_confirmar = bool(CONFIRMAR) and os.path.exists(CONFIRMAR)
                if quiere_confirmar and not confirmando and not pausado and not dictando:
                    confirmando = True
                    try:
                        while True:
                            cola.get_nowait()
                    except queue.Empty:
                        pass
                    datos = None
                    rec = reconocedor_si_no()
                    conf_inicio = ahora
                    anota("confirmacion: esperando si/no")
                elif confirmando and (not quiere_confirmar or (ahora - conf_inicio) >= CONFIRMACION_MAX):
                    if quiere_confirmar:
                        anota("confirmacion: sin respuesta")
                        try:
                            os.remove(CONFIRMAR)
                        except Exception:
                            pass
                    confirmando = False
                    # OJO: si en esta misma vuelta ya se entro en dictado, el
                    # reconocedor libre acaba de instalarse y no hay que pisarlo con
                    # el de gramatica cerrada. Si se pisa, el dictado deja de dar
                    # parciales, nunca se cumple 'hay_algo' y no termina por
                    # silencio: aguanta hasta el tope de 30 s.
                    if not dictando:
                        rec = nuevo_reconocedor()

                # nivel para la onda de la interfaz, solo mientras se dicta o se
                # esta en pausa (que es cuando la capsula esta abierta). Se
                # normaliza con la ganancia actual: la ganancia automatica lleva
                # la voz normal a ~0.35, asi que hablar normal da ~0.8.
                if NIVEL and crudo is not None and (pausado or dictando):
                    try:
                        m = np.frombuffer(crudo, dtype=np.int16).astype(np.float32)
                        pico_crudo = float(np.max(np.abs(m))) / 32768.0
                        escribir(NIVEL, "%.3f" % min(1.0, pico_crudo * ganancia / 0.45))
                    except Exception:
                        pass

                if datos is not None:
                    muestras = np.frombuffer(datos, dtype=np.int16).astype(np.float32)
                    pico = float(np.max(np.abs(muestras))) / 32768.0
                    # Se guardan los picos de los bloques CON VOZ, no el maximo
                    # suelto: calibrar con el maximo dejaba que un solo golpe (o un
                    # resto de eco) mandara sobre toda la ventana. Se usa el p90.
                    # Meter tambien los bloques de silencio hundia ese p90 a 0.0000
                    # y la ganancia se iba a x9: entonces el ruido de fondo entraba
                    # amplificado y Vosk "oia" el nombre en el silencio.
                    if pico > UMBRAL_VOZ:
                        picos.append(pico)
                        bloques_voz += 1

                    if ganancia != 1.0:
                        amplificado = muestras * ganancia
                        # si estamos recortando, bajar YA: esperar al siguiente
                        # pulso significaria 15 s de audio destrozado
                        if float(np.max(np.abs(amplificado))) >= 32767.0 and automatica:
                            recortes += 1
                            if recortes >= 3:
                                # El recorte puede ser del ALTAVOZ, no de tu voz.
                                # Bajar la ganancia entonces es lo contrario de lo
                                # que hace falta: deja el microfono sordo justo
                                # mientras suena algo. Y se peleaba con el pulso,
                                # que la recuperaba: x8 -> x2.9 -> x8, sin parar.
                                if nivel_salida() > UMBRAL_ALTAVOZ:
                                    recortes = 0
                                    if ahora - ultimo_aviso_recorte > 30:
                                        ultimo_aviso_recorte = ahora
                                        anota("recorte con los altavoces sonando (%.3f): la ganancia se queda en x%.1f"
                                              % (nivel_salida(), ganancia))
                                else:
                                    ganancia = round(max(GANANCIA_MIN, ganancia * 0.6), 1)
                                    anota("recorte detectado: bajando ganancia a x%.1f" % ganancia)
                                    recortes = 0
                                    amplificado = muestras * ganancia
                        muestras = np.clip(amplificado, -32768, 32767)
                    bloque = muestras.astype(np.int16).tobytes()

                    # PUERTA: si el bloque es silencio y no venimos de voz reciente,
                    # ni se toca el decodificador. Es donde esta el ahorro real.
                    # El cubo de la ventana se cierra AQUI, con el audio en la mano, y
                    # no donde se imprime el pulso: hay dos caminos (dictado y pausa)
                    # que adelantan 'ultimo_pulso' sin llegar a imprimir nada, y la
                    # ventana se quedaria congelada justo cuando le estas hablando.
                    if ahora - cubo_dec_desde >= INTERVALO_PULSO:
                        ventana_dec.append((bloques_totales, bloques_decodificados))
                        bloques_totales = 0
                        bloques_decodificados = 0
                        cubo_dec_desde = ahora
                    bloques_totales += 1
                    if pico > UMBRAL_ACTIVIDAD:
                        if arrastre <= 0:
                            pico_rafaga = 0.0   # empieza una rafaga nueva
                        arrastre = ARRASTRE
                    elif arrastre > 0:
                        arrastre -= 1
                    if arrastre > 0 and pico > pico_rafaga:
                        pico_rafaga = pico
                    # LOS DECODIFICADOS SE CUENTAN AQUI, NO MAS ABAJO (19/09/2026). El
                    # contador estaba detras del 'continue' del dictado y del de la
                    # confirmacion, y en esas dos ramas el bloque SI pasa por el
                    # decodificador (rec.AcceptWaveform en ambas). Con la media de toda
                    # la vida el sesgo se diluia; con una ventana de 5 minutos salia al
                    # reves de lo que interesa: un dictado de 30 s metia ~120 bloques
                    # como "no decodificados" y hundia el porcentaje justo despues de
                    # usarla, que es cuando tiene que estar alto.
                    if confirmando or dictando or arrastre > 0:
                        bloques_decodificados += 1

                    # --- MODO CONFIRMACION: solo si/no, y rapido (parciales) ---
                    if confirmando:
                        texto_c = ""
                        if rec.AcceptWaveform(bloque):
                            texto_c = json.loads(rec.Result()).get("text", "")
                        else:
                            texto_c = json.loads(rec.PartialResult()).get("partial", "")
                        palabras = [sin_tildes(w) for w in texto_c.split()]
                        respuesta = ""
                        if any(w in PALABRAS_NO for w in palabras):
                            respuesta = "no"
                        elif any(w in PALABRAS_SI for w in palabras):
                            respuesta = "si"
                        if respuesta:
                            anota("confirmacion: '%s' -> %s" % (texto_c, respuesta))
                            escribir(CONFIRMACION, respuesta)
                            try:
                                os.remove(CONFIRMAR)
                            except Exception:
                                pass
                            confirmando = False
                            rec = nuevo_reconocedor()
                        continue

                    # --- MODO DICTADO: transcribir todo, no buscar el nombre ---
                    if dictando:
                        if pico > UMBRAL_ACTIVIDAD:
                            ultima_voz = ahora
                            hubo_voz += 1
                        # EL RITMO DE BRAYA (13/09): cuanto tarda en empezar a hablar en
                        # una ventana de seguimiento. El asistente ajusta la ventana con esto
                        if espera_voz > 0 and voz_seguimiento_en is None and NIVEL and (
                                len(dictado) > 0 or json.loads(rec.PartialResult()).get("partial", "")):
                            voz_seguimiento_en = ahora - dicta_inicio
                            escribir(os.path.join(os.path.dirname(NIVEL), "seguimiento-voz.txt"), "%.2f" % voz_seguimiento_en)
                        # seguimiento sin voz: fuera, sin molestar. Cuenta como voz
                        # que el reconocedor haya sacado ALGO (parcial o final), no
                        # el nivel: el ruido de fondo pasaba el umbral y la ventana
                        # se quedaba abierta 30 s
                        if espera_voz > 0 and (ahora - dicta_inicio) >= espera_voz:
                            algo = len(dictado) > 0 or bool(json.loads(rec.PartialResult()).get("partial", ""))
                            if algo:
                                espera_voz = 0.0   # hay voz: dictado normal
                        if espera_voz > 0 and (ahora - dicta_inicio) >= espera_voz:
                            anota("seguimiento: sin voz en %.1f s" % espera_voz)
                            escribir(TEXTO, "")
                            try:
                                os.remove(DICTAR)
                            except Exception:
                                pass
                            dictando = False
                            audio_dictado = []
                            rec = nuevo_reconocedor()
                            continue
                        # el audio se guarda siempre: lo usan Whisper y el tono de voz
                        audio_dictado.append(muestras.astype(np.int16))
                        if rec.AcceptWaveform(bloque):
                            t = json.loads(rec.Result()).get("text", "")
                            if t:
                                dictado.append(t)
                                escribir(PARCIAL, " ".join(dictado))
                        else:
                            p = json.loads(rec.PartialResult()).get("partial", "")
                            if p:
                                escribir(PARCIAL, (" ".join(dictado) + " " + p).strip())
                        # fin por silencio (habiendo oido algo) o por tope duro
                        hay_algo = len(dictado) > 0 or bool(json.loads(rec.PartialResult()).get("partial", ""))
                        # SIN UNA PALABRA: el 12/09 tres activaciones falsas dejaron
                        # la escucha abierta los 30 s enteros, porque sin nada
                        # reconocido nunca se cumple el fin por silencio. Si en
                        # DICTADO_SIN_VOZ no ha salido ni un parcial, no hay orden.
                        mudo = (not hay_algo) and (ahora - dicta_inicio) >= DICTADO_SIN_VOZ
                        fin_silencio = SILENCIO_FIN
                        if LOTENGO and hay_algo and (ahora - ultima_voz) >= SILENCIO_FIN_LOTENGO and os.path.exists(LOTENGO):
                            try:
                                with open(LOTENGO, "r", encoding="utf-8") as f:
                                    tengo = " ".join(f.read().split())
                                fin_silencio = silencio_para_cerrar(tengo, " ".join(dictado) + " " + json.loads(rec.PartialResult()).get("partial", ""))
                            except Exception:
                                pass
                        if ((ahora - ultima_voz) >= fin_silencio and hay_algo) or mudo or \
                           ((ahora - dicta_inicio) >= DICTADO_MAX):
                            resto = json.loads(rec.FinalResult()).get("text", "")
                            if resto:
                                dictado.append(resto)
                            texto_vosk = " ".join([t for t in dictado if t])
                            texto_final = texto_vosk
                            f0_dictado = anotar_voz(audio_dictado)
                            # Cerrar por el tope de 30 s SIN haber oido nada quiere
                            # decir que eso no era una orden, sino ruido continuo.
                            # Antes se le daban igual 15 s de ruido a Whisper: unos
                            # 29 s de CPU con el bucle bloqueado -sordo y sin mirar
                            # la marca de activacion- para entregar un texto que
                            # ademas llega cuando el asistente ya se ha rendido.
                            callado = (not hay_algo) and (mudo or (ahora - dicta_inicio) >= DICTADO_MAX)
                            if callado:
                                anota("dictado: %.0f s sin oir nada; no hay nada que transcribir"
                                      % (ahora - dicta_inicio))
                                texto_final = ""
                            # VOZ DE OTRA PERSONA TRAS EL NOMBRE (14/09): con gente hablando
                            # cerca, "nova" salta ~2 veces cada 4 min y cada una se llevaba
                            # segundos de Whisper. Si el tono queda MUY lejos del tuyo
                            # (el doble del margen del asistente) y lo oido es cortisimo,
                            # se entrega lo de Vosk sin Whisper: el asistente lo descarta
                            # igual por voz ajena. Con el boton o en un seguimiento, nunca.
                            ajena = False
                            if origen_nombre and f0_dictado > 0 and not callado:
                                duena = voz_duena()
                                if duena > 0 and abs(f0_dictado - duena) > 70 and len(texto_vosk.split()) <= 4:
                                    ajena = True
                                    anota("dictado: voz de otra persona (%.0f Hz frente a %.0f Hz) tras el nombre; sin Whisper"
                                          % (f0_dictado, duena))
                            rapido = oir_parakeet(audio_dictado) if (not callado and not ajena) else ""
                            mejor = ""
                            _ultima_seguridad = None
                            # lo que dijo Parakeet se guarda aunque suene a ingles: es el dato
                            oido_parakeet = rapido
                            rapido, mejor = repasar_si_ingles(rapido, audio_dictado)
                            if rapido:
                                texto_final = rapido
                                marcar_parakeet()
                                vaciar_cola("transcripcion")
                            elif mejor:
                                # Parakeet sonaba a ingles y Whisper si saco algo: va lo de Whisper,
                                # y sin marcar_parakeet, que el asistente lo trate como Whisper
                                texto_final = mejor
                                vaciar_cola("transcripcion")
                            elif whisper is not None and not callado and not ajena:
                                escribir(PARCIAL, texto_vosk)
                                mejor = transcribir_whisper(audio_dictado)
                                if mejor:
                                    texto_final = mejor
                                vaciar_cola("transcripcion")
                            texto_final = quitar_nombre(texto_final)
                            anota("dictado: '%s'" % texto_final)
                            escribir(TEXTO, texto_final)
                            if not callado:
                                guardar_uso(audio_dictado, origen="nombre" if origen_nombre else "boton o seguimiento",
                                            vosk=texto_vosk, parakeet=oido_parakeet, whisper=mejor, seguridad=_ultima_seguridad,
                                            entregado=texto_final, voz_ajena=ajena)
                            try:
                                os.remove(DICTAR)
                            except Exception:
                                pass
                            dictando = False
                            ultimo_audio = audio_dictado
                            guardar_ultima_orden(ultimo_audio)   # ver EL AUDIO DE LA ULTIMA ORDEN
                            guardar_audio_si_toca(ultimo_audio)
                            audio_dictado = []
                            rec = nuevo_reconocedor()
                        # en dictado no se evalua la palabra de activacion
                        if ahora - ultimo_pulso >= INTERVALO_PULSO:
                            ultimo_pulso = ahora
                        continue

                    # OJO: aqui NO vale un 'continue'. Saltaria tambien el pulso del
                    # final del bucle, que es justo lo que registra el diagnostico y
                    # recalibra la ganancia, y durante el silencio -o sea, casi
                    # siempre- dejariamos de hacer ambas cosas.
                    decodificar = (arrastre > 0)
                    if not decodificar:
                        prebuffer.append(bloque)

                    # al arrancar la voz se recupera el pre-buffer, para no perder
                    # el principio de la palabra
                    if decodificar and prebuffer:
                        for b in prebuffer:
                            if rec.AcceptWaveform(b):
                                pass   # descartado: es solo contexto previo
                        prebuffer.clear()
                    # (bloques_decodificados ya se conto arriba, con bloques_totales)
                    # Solo se mira el resultado FINAL: los parciales cambian de
                    # hipotesis constantemente y no traen confianza por palabra.
                    if decodificar and rec.AcceptWaveform(bloque):
                        resultado = json.loads(rec.Result())
                        texto = resultado.get("text", "")
                        if texto:
                            plano = sin_tildes(texto)
                            if PATRON_NOMBRE.search(plano):
                                conf = 0.0
                                solo_boton = bool(MARCA_SOLO_BOTON) and os.path.exists(MARCA_SOLO_BOTON)
                                salida = nivel_salida()
                                for p in resultado.get("result", []):
                                    if sin_tildes(p.get("word", "")) == NOMBRE_PLANO:
                                        conf = max(conf, float(p.get("conf", 0.0)))
                                if solo_boton:
                                    if ahora - ultimo_aviso_solo_boton > 60:
                                        ultimo_aviso_solo_boton = ahora
                                        anota("'%s' ignorado: estas jugando, aqui solo vale el boton" % texto)
                                elif salida > UMBRAL_ALTAVOZ_FUERTE:
                                    if ahora - ultimo_aviso_solo_boton > 60:
                                        ultimo_aviso_solo_boton = ahora
                                        anota("'%s' ignorado: los altavoces suenan fuerte (%.3f), la palabra no es de fiar"
                                              % (texto, salida))
                                elif pico_rafaga < UMBRAL_VOZ:
                                    # Vosk daba confianza 1.00 al nombre sobre
                                    # bloques de pico 0.000, o sea silencio puro
                                    # amplificado. Sin haber sonado nada no hay
                                    # nada que reconocer.
                                    anota("descartado '%s': sin voz real (pico rafaga %.4f)"
                                          % (texto, pico_rafaga))
                                elif conf < umbral_confianza(plano):
                                    anota("descartado '%s': confianza %.2f < %.2f%s"
                                          % (texto, conf, umbral_confianza(plano),
                                             "" if len(plano.split()) <= PALABRAS_SIN_SOSPECHA
                                             else " (frase larga: se exige mas)"))
                                elif ahora - ultima_marca > 2.0:
                                    # antirebote: no disparar dos veces por lo mismo
                                    ultima_marca = ahora
                                    # 'pico' es el del ultimo bloque, que al cerrar la
                                    # frase suele ser silencio (0.000); lo que decide
                                    # es el de la rafaga, y sin el el log parecia
                                    # activarse con silencio puro
                                    anota("ACTIVADO por '%s' (confianza %.2f, pico %.3f, rafaga %.3f, ganancia x%.1f, altavoces %.3f)"
                                          % (texto, conf, pico, pico_rafaga, ganancia, nivel_salida()))
                                    try:
                                        with open(MARCA, "w", encoding="utf-8") as f:
                                            f.write(time.strftime("%Y-%m-%dT%H:%M:%S"))
                                    except Exception as _e_marca:  # noqa: BLE001
                                        # el anota("ACTIVADO...") ya salio arriba: si esto
                                        # falla y no se dice, EL LOG MIENTE (dice que te oyo
                                        # y no pasa nada)
                                        anota("ACTIVADO pero no pude dejar la marca (%s): el asistente no se va a enterar" % _e_marca)
                                    rec = nuevo_reconocedor()

                # pulso periodico: estado, nivel y ajuste de ganancia
                if ahora - ultimo_pulso >= INTERVALO_PULSO:
                    if not padre_vivo():
                        anota("el asistente ya no existe (PID %d); salgo y suelto el microfono" % PID_PADRE)
                        sys.exit(0)
                    # Se exige voz SOSTENIDA, no un pico suelto: un transitorio de
                    # 250 ms no debe recalibrar nada. Y NO se recalibra mientras suenan los altavoces. Lo que entra
                    # entonces es sobre todo el altavoz, no tu voz, y el calculo sale
                    # al reves: pico alto -> ganancia baja (se vio x0.7 con los
                    # altavoces a 0.55). Con la voz entrando a 0.02-0.05, amplificar
                    # x0.7 es quedarse sordo justo cuando mas falta hace decir
                    # "nova, pausa". Se conserva la ultima calibracion buena y se
                    # vuelve a ajustar cuando haya silencio.
                    altavoces_altos = nivel_salida() > UMBRAL_ALTAVOZ
                    if automatica and altavoces_altos and bloques_voz >= MIN_BLOQUES_VOZ:
                        anota_pulso("pulso: ganancia congelada en x%.1f (suenan los altavoces: %.3f)"
                                    % (ganancia, nivel_salida()), ahora)
                        escribir(RUTA_ESTADO, "%.1f|0|%.3f|%d" % (ganancia, nivel_salida(), bloques_voz))
                    elif automatica and bloques_voz >= MIN_BLOQUES_VOZ and picos:
                        ref = float(np.percentile(np.array(picos), 90))
                        ref = max(ref, 1e-6)
                        # El pico es CRUDO, antes de amplificar: la ganancia se
                        # calcula desde cero. Multiplicarla por la actual la
                        # componia en cada ciclo hasta el tope, y ahi la voz salia
                        # recortada y no se reconocia nada.
                        nueva = max(GANANCIA_MIN, min(GANANCIA_MAX, PICO_OBJETIVO / ref))
                        # asimetrico: subir rapido, bajar despacio, para que un
                        # ruido puntual no deje sordo el minuto siguiente
                        factor = 0.6 if nueva > ganancia else 0.2
                        propuesta = ganancia + (nueva - ganancia) * factor
                        # segunda red: tope de salto por ciclo
                        propuesta = max(ganancia - PASO_MAX, min(ganancia + PASO_MAX, propuesta))
                        # EL REDONDEO SE COMIA LA BAJADA (17/09). Con ganancia 0.7 y
                        # objetivo 0.58: propuesta = 0.7 + (0.58-0.7)*0.2 = 0.676, y
                        # round(...,1) la devolvia a 0.7. Se quedaba clavada para
                        # siempre aunque el microfono pidiera menos, que es justo lo
                        # que pasaba: 27 % de los pulsos saturados sin poder atenuar.
                        # Si toca bajar, se fuerza un decimal, sin pasarse del objetivo.
                        if nueva < ganancia:
                            propuesta = max(nueva, min(propuesta, ganancia - 0.1))
                        ganancia = round(max(GANANCIA_MIN, min(GANANCIA_MAX, propuesta)), 1)
                        # esta SI se escribe siempre: es el ajuste de ganancia de verdad, el
                        # dato con el que se decide si la escucha esta bien calibrada
                        anota("pulso: p90=%.4f bloques_voz=%d ganancia=x%.1f decodificado=%d%% altavoces=%.3f"
                              % (ref, bloques_voz, ganancia, pct_dec(), nivel_salida()))
                        escribir(RUTA_GANANCIA, "%.1f" % ganancia)
                        escribir(RUTA_ESTADO, "%.1f|%.4f|%.3f|%d" % (ganancia, ref, nivel_salida(), bloques_voz))
                    else:
                        anota_pulso("pulso: sin voz sostenida (%d bloques) ganancia=x%.1f decodificado=%d%% altavoces=%.3f"
                                    % (bloques_voz, ganancia, pct_dec(), nivel_salida()), ahora)
                        escribir(RUTA_ESTADO, "%.1f|0|%.3f|%d" % (ganancia, nivel_salida(), bloques_voz))
                    picos = []
                    bloques_voz = 0
                    # tres recortes sueltos repartidos en horas (un portazo, una
                    # tos) no deben sumarse hasta provocar una bajada espuria
                    recortes = 0
                    ultimo_pulso = ahora
            except Exception as e:
                # Una vuelta que falle no se lleva el worker por delante: se
                # anota y se sigue con la siguiente. Antes cualquier json.loads
                # raro de Vosk mataba el proceso, y con el el dictado en curso.
                anota("fallo en una vuelta del bucle: %s" % e)
                try:
                    rec = nuevo_reconocedor()
                except Exception as _e_rec:  # noqa: BLE001
                    # si esto falla, el reconocedor queda roto y cada vuelta vuelve a fallar:
                    # un bucle de errores mudo. Al menos que se vea en el log.
                    anota("no pude rehacer el reconocedor (%s): la escucha puede quedarse sorda" % _e_rec)
                continue
except Exception as e:
    anota("ERROR en el bucle: %s" % e)
    sys.exit(1)
