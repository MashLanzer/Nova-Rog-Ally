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

base = os.path.dirname(os.path.abspath(__file__))
ruta_modelo = os.path.join(base, "vosk", "vosk-model-small-es-0.42")
if not os.path.isdir(ruta_modelo):
    anota("ERROR: falta el modelo en %s" % ruta_modelo)
    sys.exit(1)

try:
    modelo = Model(ruta_modelo)
    rec = KaldiRecognizer(modelo, TASA)
    rec.SetWords(False)
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
pico_ventana = 0.0
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
                pico_ventana = 0.0
                ultimo_pulso = ahora
            elif pausado:
                pausado = False
                rec = KaldiRecognizer(modelo, TASA)
                rec.SetWords(False)
                anota("pausa: fin, escuchando de nuevo")

            if datos is not None:
                muestras = np.frombuffer(datos, dtype=np.int16).astype(np.float32)
                pico = float(np.max(np.abs(muestras))) / 32768.0
                if pico > pico_ventana:
                    pico_ventana = pico

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

                texto = ""
                if rec.AcceptWaveform(bloque):
                    texto = json.loads(rec.Result()).get("text", "")
                else:
                    texto = json.loads(rec.PartialResult()).get("partial", "")

                if texto:
                    plano = sin_tildes(texto)
                    if pico > pico_voz:
                        pico_voz = pico
                    if NOMBRE_PLANO in plano.split() or plano.endswith(NOMBRE_PLANO):
                        # antirebote: no disparar dos veces por la misma frase
                        if ahora - ultima_marca > 2.0:
                            ultima_marca = ahora
                            anota("ACTIVADO por '%s' (pico %.3f, ganancia x%.1f)"
                                  % (texto, pico, ganancia))
                            try:
                                with open(MARCA, "w", encoding="utf-8") as f:
                                    f.write(time.strftime("%Y-%m-%dT%H:%M:%S"))
                            except Exception:
                                pass
                            rec = KaldiRecognizer(modelo, TASA)
                            rec.SetWords(False)

            # pulso periodico: estado, nivel y ajuste de ganancia
            if ahora - ultimo_pulso >= INTERVALO_PULSO:
                # SOLO se calibra si en la ventana hubo voz. Ajustar con
                # silencio llevaba la ganancia al maximo y luego saturaba.
                if automatica and pico_ventana > UMBRAL_VOZ:
                    # pico_ventana es el pico CRUDO, antes de amplificar. La
                    # ganancia se calcula desde cero: multiplicarla por la
                    # actual la componia en cada ciclo hasta el tope, y a x60
                    # la voz salia recortada y Vosk no reconocia nada.
                    nueva = PICO_OBJETIVO / pico_ventana
                    nueva = max(GANANCIA_MIN, min(GANANCIA_MAX, nueva))
                    # asimetrico a proposito: subir rapido (para oirte cuanto
                    # antes) y bajar despacio (un ruido puntual no debe
                    # dejarnos sordos durante el minuto siguiente)
                    factor = 0.6 if nueva > ganancia else 0.2
                    ganancia = round(ganancia + (nueva - ganancia) * factor, 1)
                    anota("pulso: pico=%.4f (voz)  ganancia=x%.1f" % (pico_ventana, ganancia))
                else:
                    anota("pulso: pico=%.4f (silencio, sin recalibrar)  ganancia=x%.1f"
                          % (pico_ventana, ganancia))
                pico_ventana = 0.0
                ultimo_pulso = ahora
except Exception as e:
    anota("ERROR en el bucle: %s" % e)
    sys.exit(1)
