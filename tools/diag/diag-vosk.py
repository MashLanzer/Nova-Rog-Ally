# Diagnostico de audio + reconocimiento con Vosk.
#
# Mide el nivel REAL que entra por el microfono y, aplicando ganancia por
# software, muestra lo que Vosk entiende. Con SAPI no se podia hacer nada de
# esto: no daba acceso al audio crudo, y por eso una senal baja lo dejaba mudo.
#
# Uso:  python tools\diag\diag-vosk.py [segundos] [ganancia]

import sys
import os
import json
import queue

import numpy as np
import sounddevice as sd
from vosk import Model, KaldiRecognizer, SetLogLevel

SetLogLevel(-1)

SEGUNDOS = int(sys.argv[1]) if len(sys.argv) > 1 else 20
GANANCIA = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
TASA = 16000

base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ruta_modelo = os.path.join(base, "vosk", "vosk-model-small-es-0.42")
if not os.path.isdir(ruta_modelo):
    print("No encuentro el modelo en %s" % ruta_modelo)
    sys.exit(1)

print("dispositivo de entrada: %s" % sd.query_devices(sd.default.device[0])["name"])
print("ganancia aplicada: x%.1f    escuchando %d s. HABLA AHORA." % (GANANCIA, SEGUNDOS))
print("-" * 62)

modelo = Model(ruta_modelo)
rec = KaldiRecognizer(modelo, TASA)
rec.SetWords(False)

cola = queue.Queue()
pico_global = 0.0


def entrada(datos, marcos, tiempo, estado):
    cola.put(bytes(datos))


with sd.RawInputStream(samplerate=TASA, blocksize=4000, dtype="int16",
                       channels=1, callback=entrada):
    import time
    t0 = time.time()
    bloques = 0
    suma_pico = 0.0
    while time.time() - t0 < SEGUNDOS:
        try:
            datos = cola.get(timeout=0.5)
        except queue.Empty:
            continue

        muestras = np.frombuffer(datos, dtype=np.int16).astype(np.float32)
        pico = float(np.max(np.abs(muestras))) / 32768.0
        if pico > pico_global:
            pico_global = pico
        suma_pico += pico
        bloques += 1

        if GANANCIA != 1.0:
            muestras = np.clip(muestras * GANANCIA, -32768, 32767)
        datos = muestras.astype(np.int16).tobytes()

        if rec.AcceptWaveform(datos):
            texto = json.loads(rec.Result()).get("text", "")
            if texto:
                print("  RECONOCIDO: '%s'   (pico del bloque %.3f)" % (texto, pico))
        else:
            parcial = json.loads(rec.PartialResult()).get("partial", "")
            if parcial:
                print("  ...parcial: '%s'" % parcial)

final = json.loads(rec.FinalResult()).get("text", "")
if final:
    print("  RECONOCIDO (final): '%s'" % final)

print("-" * 62)
print("pico maximo: %.4f  (1.0 = saturado, <0.02 = muy bajo)" % pico_global)
if bloques:
    print("pico medio : %.4f" % (suma_pico / bloques))
if pico_global < 0.02:
    print("=> La senal es MUY baja. Sube la ganancia: python ... %d 8" % SEGUNDOS)
elif pico_global < 0.10:
    print("=> Senal baja pero usable con ganancia x4 o x8.")
else:
    print("=> Senal correcta.")
