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
# Uso: wake_vosk.py <nombre> <rutaMarca> <rutaLog> [ganancia|auto]

import sys
import os
import re
import json
import queue
import time
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
INTERVALO_PULSO = 15.0    # ajuste rapido; con 60 s tardaba minutos en subir


def anota(mensaje):
    if not LOG:
        return
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S") + "  [escucha] " + mensaje + "\n")
    except Exception:
        pass


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
CONFIANZA_MIN = 0.55

base = os.path.dirname(os.path.abspath(__file__))
ruta_modelo = os.path.join(base, "vosk", "vosk-model-small-es-0.42")
if not os.path.isdir(ruta_modelo):
    anota("ERROR: falta el modelo en %s" % ruta_modelo)
    sys.exit(1)

def nuevo_reconocedor():
    r = KaldiRecognizer(modelo, TASA, GRAMATICA)
    r.SetWords(True)   # necesario para leer la confianza por palabra
    return r


try:
    modelo = Model(ruta_modelo)
    rec = nuevo_reconocedor()
    dispositivo = sd.query_devices(sd.default.device[0])["name"]
except Exception as e:
    anota("ERROR al iniciar: %s" % e)
    sys.exit(1)

cola = queue.Queue()


def entrada(datos, marcos, tiempo, estado):
    cola.put(bytes(datos))


automatica = (GANANCIA_ARG == "auto")
ganancia = GANANCIA_INICIAL if automatica else float(GANANCIA_ARG)

anota("worker Vosk en marcha: nombre='%s' dispositivo='%s' ganancia=%s"
      % (NOMBRE, dispositivo, "auto" if automatica else ganancia))

ultimo_pulso = time.time()
recortes = 0
pausado = False
picos = []
bloques_voz = 0
pico_voz = 0.0          # pico observado cuando SI habia voz reconocible
ultima_marca = 0.0

try:
    with sd.RawInputStream(samplerate=TASA, blocksize=4000, dtype="int16",
                           channels=1, callback=entrada):
        while True:
            try:
                datos = cola.get(timeout=0.5)
            except queue.Empty:
                datos = None

            ahora = time.time()

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
                rec = nuevo_reconocedor()
                anota("pausa: fin, escuchando de nuevo")

            if datos is not None:
                muestras = np.frombuffer(datos, dtype=np.int16).astype(np.float32)
                pico = float(np.max(np.abs(muestras))) / 32768.0
                # Se guardan TODOS los picos, no solo el maximo: calibrar con el
                # maximo dejaba que un solo golpe (o un resto de eco) mandara
                # sobre toda la ventana. Se usa el percentil 90.
                picos.append(pico)
                if pico > UMBRAL_VOZ:
                    bloques_voz += 1

                if ganancia != 1.0:
                    amplificado = muestras * ganancia
                    # si estamos recortando, bajar YA: esperar al siguiente
                    # pulso significaria 15 s de audio destrozado
                    if float(np.max(np.abs(amplificado))) >= 32767.0 and automatica:
                        recortes += 1
                        if recortes >= 3:
                            ganancia = round(max(GANANCIA_MIN, ganancia * 0.6), 1)
                            anota("recorte detectado: bajando ganancia a x%.1f" % ganancia)
                            recortes = 0
                            amplificado = muestras * ganancia
                    muestras = np.clip(amplificado, -32768, 32767)
                bloque = muestras.astype(np.int16).tobytes()

                # Solo se mira el resultado FINAL: los parciales cambian de
                # hipotesis constantemente y no traen confianza por palabra.
                if rec.AcceptWaveform(bloque):
                    resultado = json.loads(rec.Result())
                    texto = resultado.get("text", "")
                    if texto:
                        plano = sin_tildes(texto)
                        if pico > pico_voz:
                            pico_voz = pico
                        if PATRON_NOMBRE.search(plano):
                            conf = 0.0
                            for p in resultado.get("result", []):
                                if sin_tildes(p.get("word", "")) == NOMBRE_PLANO:
                                    conf = max(conf, float(p.get("conf", 0.0)))
                            if conf < CONFIANZA_MIN:
                                anota("descartado '%s': confianza %.2f < %.2f"
                                      % (texto, conf, CONFIANZA_MIN))
                            elif ahora - ultima_marca > 2.0:
                                # antirebote: no disparar dos veces por lo mismo
                                ultima_marca = ahora
                                anota("ACTIVADO por '%s' (confianza %.2f, pico %.3f, ganancia x%.1f)"
                                      % (texto, conf, pico, ganancia))
                                try:
                                    with open(MARCA, "w", encoding="utf-8") as f:
                                        f.write(time.strftime("%Y-%m-%dT%H:%M:%S"))
                                except Exception:
                                    pass
                                rec = nuevo_reconocedor()

            # pulso periodico: estado, nivel y ajuste de ganancia
            if ahora - ultimo_pulso >= INTERVALO_PULSO:
                # Se exige voz SOSTENIDA, no un pico suelto: un transitorio de
                # 250 ms no debe recalibrar nada.
                if automatica and bloques_voz >= MIN_BLOQUES_VOZ and picos:
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
                    anota("pulso: p90=%.4f bloques_voz=%d  ganancia=x%.1f"
                          % (ref, bloques_voz, ganancia))
                else:
                    anota("pulso: sin voz sostenida (%d bloques), sin recalibrar  ganancia=x%.1f"
                          % (bloques_voz, ganancia))
                picos = []
                bloques_voz = 0
                ultimo_pulso = ahora
except Exception as e:
    anota("ERROR en el bucle: %s" % e)
    sys.exit(1)
