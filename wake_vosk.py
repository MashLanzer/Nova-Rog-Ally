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
VOCABULARIO = sys.argv[13] if len(sys.argv) > 13 else ""
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
MODELO_PRECISO = sys.argv[17] if len(sys.argv) > 17 else ""
CONFIRMACION_MAX = 5.0

# se da por terminada la frase tras este silencio
SILENCIO_FIN = 1.4
# tope duro, por si el silencio nunca llega (ruido de fondo constante)
DICTADO_MAX = 30.0
# Lo que se le da a Whisper como mucho. Llegar a DICTADO_MAX significa que
# nunca hubo un silencio: eso no es una orden, es ruido constante. El 11/09
# hubo 14 transcripciones de 30 s que costaron 181 s de CPU para nada. Una
# orden de verdad, incluso larga ("recuerdame manana a las diez que..."), cabe
# de sobra en esto, y se coge el PRINCIPIO porque es donde esta la orden.
TRANSCRIBIR_MAX = 15.0

TASA = 16000
PICO_OBJETIVO = 0.35      # nivel al que queremos llevar la voz
# Medido en esta maquina: la voz normal entra a 0.02-0.05 y hizo falta x26
# para activarse. Empezar en x1 obligaba a gritar durante los primeros
# minutos, mientras la ganancia trepaba sola.
GANANCIA_INICIAL = 8.0
# El minimo permite ATENUAR: si el microfono entra fuerte, amplificar recorta
# la senal y el reconocimiento se vuelve imposible por el motivo contrario.
GANANCIA_MIN = 0.5
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
    return ctypes.cast(ptr, POINTER(IAudioMeterInformation))


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


def modelo_preciso():
    global _preciso, _preciso_roto
    if _preciso is not None or _preciso_roto or not MODELO_PRECISO:
        return _preciso
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


def atender_reintento(ultimo_audio):
    """El asistente no reconocio la orden: se repasa el mismo audio con el
    modelo preciso. Siempre se contesta algo, aunque sea vacio, porque el
    asistente esta esperando al otro lado con un plazo."""
    if not REINTENTO or not os.path.exists(REINTENTO):
        return False
    texto = ""
    try:
        m = modelo_preciso()
        if m is not None and ultimo_audio:
            t0 = time.time()
            texto = quitar_nombre(transcribir_whisper(ultimo_audio, m))
            anota("oido fino: '%s' (%.1f s)" % (texto, time.time() - t0))
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
    # porcentaje de bloques que llegaron al decodificador: mide el ahorro real
    if bloques_totales <= 0:
        return 0
    return int(100.0 * bloques_decodificados / bloques_totales)


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


def leer_vocabulario():
    if not VOCABULARIO:
        return None
    try:
        with open(VOCABULARIO, "r", encoding="utf-8") as f:
            v = f.read().strip()
        return v or None
    except Exception:
        return None


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
    if not NIVEL:
        return
    try:
        f0 = estimar_f0(bloques)
        idx = indice_voz(f0)
        escribir(os.path.join(os.path.dirname(NIVEL), "dictado-voz.txt"), "%d %.0f" % (idx, f0))
        if f0 > 0:
            anota("voz: tono %.0f Hz -> voz %d" % (f0, idx))
    except Exception:
        pass


def transcribir_whisper(bloques, modelo=None):
    # bloques: lista de arrays int16 ya amplificados
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
    # OJO con initial_prompt: Whisper lo trata como TEXTO ANTERIOR y lo
    # CONTINUA cuando el audio es flojo. Con la lista de apps y juegos ahi
    # dentro, el silencio se transcribia como "SILENT BREATH, PEAK, Hollow
    # Knight..." y esa frase inventada se ejecutaba como si fuera una orden.
    # hotwords sesga el decodificador hacia esas palabras SIN meterlas en el
    # contexto, que es lo que queriamos desde el principio.
    # Los tres umbrales descartan el segmento cuando no hay voz de verdad:
    # sin ellos Whisper siempre devuelve algo, aunque el audio sea ruido.
    segmentos, info = modelo.transcribe(
        audio, language="es", beam_size=2, best_of=1,
        vad_filter=True, vad_parameters=dict(min_silence_duration_ms=500),
        condition_on_previous_text=False,
        no_speech_threshold=0.6,
        log_prob_threshold=-1.0,
        compression_ratio_threshold=2.4,
        hotwords=leer_vocabulario())
    texto = " ".join(s.text.strip() for s in segmentos).strip()
    anota("whisper: %.1f s de audio en %.2f s -> '%s'" % (audio.size / TASA, time.time() - t0, texto))
    return limpiar_whisper(texto)


# Segunda red por si el nombre se cuela igual: se quita del principio de la
# orden. "nova abre steam" debe ejecutarse como "abre steam".
PATRON_INICIO = re.compile(
    r"^\s*(?:oye\s+|hola\s+|ey\s+)?" + re.escape(NOMBRE_PLANO) + r"\b[\s,.]*", re.IGNORECASE)


def quitar_nombre(texto):
    return PATRON_INICIO.sub("", texto or "").strip()


def escribir(ruta, contenido):
    if not ruta:
        return
    try:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(contenido)
    except Exception:
        pass


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
        # int8 en CPU: ~500 MB con "small". cpu_threads bajo a proposito: es un
        # portatil de juegos y este proceso corre con prioridad baja.
        whisper = WhisperModel(nombre_modelo or "small", device="cpu", compute_type="int8", cpu_threads=4)
        # calentamiento: la primera transcripcion tarda 3 s; mejor ahora que
        # en la primera orden
        list(whisper.transcribe(np.zeros(TASA, dtype=np.float32), language="es", beam_size=1)[0])
        anota("whisper '%s' cargado en %.1f s" % (nombre_modelo, time.time() - t0))
    except Exception as e:
        whisper = None
        anota("WARN: no se pudo cargar Whisper (%s); el dictado usara Vosk" % e)

cola = queue.Queue()


def entrada(datos, marcos, tiempo, estado):
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
        # Una ganancia asi de baja no se calibro con tu voz: en esta maquina la
        # voz entra a 0.02-0.05 y hace falta amplificar entre x8 y x26. Un valor
        # por debajo de x1.5 sale de haber calibrado con los altavoces sonando,
        # y arrastrarlo entre sesiones es empezar el dia sordo.
        if _g < 1.5:
            anota("ganancia recordada x%.1f descartada (demasiado baja: se calibro con ruido); se empieza en x%.1f"
                  % (_g, GANANCIA_INICIAL))
        else:
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
ultimo_audio = []       # el de la ULTIMA orden, por si hay que repasarlo (oido fino)
confirmando = False
conf_inicio = 0.0
dicta_inicio = 0.0
ultima_voz = 0.0
prebuffer = collections.deque(maxlen=PREBUFFER)
bloques_totales = 0
bloques_decodificados = 0
picos = []
bloques_voz = 0
pico_voz = 0.0          # pico observado cuando SI habia voz reconocible
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

                # PAUSA: el asistente esta hablando o dictando. Se tira el audio
                # sin mirarlo y sin recalibrar; al reanudar se reinicia el
                # reconocedor para no arrastrar restos de su propia voz.
                if PAUSA and os.path.exists(PAUSA):
                    if not pausado:
                        pausado = True
                        anota("pausa: el asistente habla o dicta, se ignora el microfono")
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
                    try:
                        with open(DICTAR, "r", encoding="utf-8") as f:
                            contenido = f.read().strip()
                        if contenido.startswith("seguimiento:"):
                            espera_voz = float(contenido.split(":", 1)[1]) / 1000.0
                    except Exception:
                        espera_voz = 0.0
                    hubo_voz = 0
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
                    if whisper is not None:
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
                    dictando = False
                    ultimo_audio = audio_dictado
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
                    bloques_totales += 1
                    if pico > UMBRAL_ACTIVIDAD:
                        if arrastre <= 0:
                            pico_rafaga = 0.0   # empieza una rafaga nueva
                        arrastre = ARRASTRE
                    elif arrastre > 0:
                        arrastre -= 1
                    if arrastre > 0 and pico > pico_rafaga:
                        pico_rafaga = pico

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
                        if ((ahora - ultima_voz) >= SILENCIO_FIN and hay_algo) or \
                           ((ahora - dicta_inicio) >= DICTADO_MAX):
                            resto = json.loads(rec.FinalResult()).get("text", "")
                            if resto:
                                dictado.append(resto)
                            texto_vosk = " ".join([t for t in dictado if t])
                            texto_final = texto_vosk
                            anotar_voz(audio_dictado)
                            # Cerrar por el tope de 30 s SIN haber oido nada quiere
                            # decir que eso no era una orden, sino ruido continuo.
                            # Antes se le daban igual 15 s de ruido a Whisper: unos
                            # 29 s de CPU con el bucle bloqueado -sordo y sin mirar
                            # la marca de activacion- para entregar un texto que
                            # ademas llega cuando el asistente ya se ha rendido.
                            callado = (not hay_algo) and (ahora - dicta_inicio) >= DICTADO_MAX
                            if callado:
                                anota("dictado: %.0f s sin oir nada; no hay nada que transcribir"
                                      % DICTADO_MAX)
                                texto_final = ""
                            if whisper is not None and not callado:
                                escribir(PARCIAL, texto_vosk)
                                mejor = transcribir_whisper(audio_dictado)
                                if mejor:
                                    texto_final = mejor
                                vaciar_cola("transcripcion")
                            texto_final = quitar_nombre(texto_final)
                            anota("dictado: '%s'" % texto_final)
                            escribir(TEXTO, texto_final)
                            try:
                                os.remove(DICTAR)
                            except Exception:
                                pass
                            dictando = False
                            ultimo_audio = audio_dictado
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
                    if decodificar:
                        bloques_decodificados += 1
                    # Solo se mira el resultado FINAL: los parciales cambian de
                    # hipotesis constantemente y no traen confianza por palabra.
                    if decodificar and rec.AcceptWaveform(bloque):
                        resultado = json.loads(rec.Result())
                        texto = resultado.get("text", "")
                        if texto:
                            plano = sin_tildes(texto)
                            if pico > pico_voz:
                                pico_voz = pico
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
                                    anota("ACTIVADO por '%s' (confianza %.2f, pico %.3f, ganancia x%.1f, altavoces %.3f)"
                                          % (texto, conf, pico, ganancia, nivel_salida()))
                                    try:
                                        with open(MARCA, "w", encoding="utf-8") as f:
                                            f.write(time.strftime("%Y-%m-%dT%H:%M:%S"))
                                    except Exception:
                                        pass
                                    rec = nuevo_reconocedor()

                # pulso periodico: estado, nivel y ajuste de ganancia
                if ahora - ultimo_pulso >= INTERVALO_PULSO:
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
                        anota("pulso: ganancia congelada en x%.1f (suenan los altavoces: %.3f)"
                              % (ganancia, nivel_salida()))
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
                        ganancia = round(max(GANANCIA_MIN, min(GANANCIA_MAX, propuesta)), 1)
                        anota("pulso: p90=%.4f bloques_voz=%d ganancia=x%.1f decodificado=%d%% altavoces=%.3f"
                              % (ref, bloques_voz, ganancia, pct_dec(), nivel_salida()))
                        escribir(RUTA_GANANCIA, "%.1f" % ganancia)
                        escribir(RUTA_ESTADO, "%.1f|%.4f|%.3f|%d" % (ganancia, ref, nivel_salida(), bloques_voz))
                    else:
                        anota("pulso: sin voz sostenida (%d bloques) ganancia=x%.1f decodificado=%d%% altavoces=%.3f"
                              % (bloques_voz, ganancia, pct_dec(), nivel_salida()))
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
                except Exception:
                    pass
                continue
except Exception as e:
    anota("ERROR en el bucle: %s" % e)
    sys.exit(1)
