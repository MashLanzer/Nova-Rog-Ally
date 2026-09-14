# -*- coding: utf-8 -*-
"""Graba TU voz diciendo unas cuantas ordenes, una sola vez.

Por que: todo el banco de pruebas mide TEXTO. Lo que de verdad falla es el
micrófono -entra bajísimo en esta máquina- y eso no lo ve ninguna prueba. Con
veinte grabaciones tuyas se puede medir lo que importa: si el reconocedor te
entiende A TI, en tu cuarto, con tu micrófono.

    python tools\\grabar-ordenes.py

Se graba una frase por vez: la lees en voz alta como se la dirias al
asistente. Los archivos van a pruebas\\audio\\ y NO se suben a GitHub.
Para repetir una que salio mal, se vuelve a ejecutar y se dice el numero.
"""
import os
import sys
import time
import json

import wave

try:
    import numpy as np
    import sounddevice as sd
except Exception as e:  # pragma: no cover
    print("Falta un paquete: %s" % e)
    print("Instala con:  pip install sounddevice numpy")
    sys.exit(1)


def escribe_wav(ruta, audio, tasa):
    # wave de la biblioteca estandar, para no anadir soundfile solo por esto:
    # cuantas menos piezas haya que instalar en la maquina, mejor
    pcm = np.clip(audio.reshape(-1), -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(tasa)
        w.writeframes(pcm.tobytes())

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "pruebas", "audio")
TASA = 16000
SEGUNDOS = 5.0

# Las cuarenta. No son al azar: hay nombres propios (lo que peor lleva el modelo
# rapido), ordenes cortas, ordenes con numero y dos frases largas encadenadas.
FRASES = [
    "abre steam",
    "abre spotify",
    "pon el volumen al setenta",
    "sube el volumen",
    "baja el brillo",
    "pon modo noche",
    "que hora es",
    "cuanta bateria queda",
    "pausa",
    "siguiente cancion",
    "abre little nightmares tres en steam",
    "cierra discord",
    "silencia el navegador",
    "que se esta descargando",
    "recuerdame en veinte minutos que saque la pizza",
    "lee la pantalla",
    "a que estoy jugando",
    "pon el juego al ochenta",
    "abre steam y pon modo juego",
    "no me escuches media hora",
    # --- las veinte del 14/09: con veinte, una pasada y la siguiente se movian
    # +-1 y no se podia demostrar ninguna mejora pequena. Mas ordenes corrientes y
    # DOS DE CHARLA, que no deben acabar en ninguna orden (acierto = no hacer nada)
    "baja el volumen",
    "sube el brillo",
    "anterior cancion",
    "cierra steam",
    "abre youtube",
    "busca recetas de pasta en youtube",
    "pon el brillo al cincuenta",
    "cuanto espacio me queda",
    "minimiza todo",
    "haz una captura",
    "pon modo foco",
    "que cancion es",
    "donde me quede",
    "apunta leche en la lista de la compra",
    "cancela el temporizador",
    "avisame en cinco minutos",
    "abre discord y pon musica",
    "que me han escrito",
    "estoy muy cansado hoy",
    "que opinas de hollow knight",
]


def graba(indice, frase):
    print("")
    print("  [%2d/%d]  \"%s\"" % (indice + 1, len(FRASES), frase))
    input("          Enter y la dices (hay %g segundos)... " % SEGUNDOS)
    for c in (3, 2, 1):
        print("            %d..." % c, end="\r", flush=True)
        time.sleep(0.4)
    print("            HABLA          ", end="\r", flush=True)
    audio = sd.rec(int(SEGUNDOS * TASA), samplerate=TASA, channels=1, dtype="float32")
    sd.wait()
    pico = float(np.max(np.abs(audio))) if audio.size else 0.0
    ruta = os.path.join(DESTINO, "%02d.wav" % (indice + 1))
    escribe_wav(ruta, audio, TASA)
    aviso = ""
    if pico < 0.01:
        aviso = "   <-- CASI NO SE OYE, repitela"
    elif pico > 0.98:
        aviso = "   <-- saturada, alejate un poco"
    print("            guardada (pico %.3f)%s" % (pico, aviso))
    return pico


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    with open(os.path.join(DESTINO, "esperado.json"), "w", encoding="utf-8") as f:
        json.dump({"%02d.wav" % (i + 1): t for i, t in enumerate(FRASES)},
                  f, ensure_ascii=False, indent=1)

    solo = None
    nuevas = len(sys.argv) > 1 and sys.argv[1] == "nuevas"
    if len(sys.argv) > 1 and not nuevas:
        try:
            solo = int(sys.argv[1]) - 1
        except ValueError:
            solo = None

    print("Micrófono: %s" % sd.query_devices(sd.default.device[0])["name"])
    print("Dilo como se lo dirias al asistente, ni mas alto ni mas despacio:")
    print("si lo dices distinto, la medida no sirve para nada.")

    if solo is not None:
        graba(solo, FRASES[solo])
    elif nuevas:
        # solo las que aun no tienen grabacion: las de antes no se repiten
        faltan = [i for i in range(len(FRASES)) if not os.path.exists(os.path.join(DESTINO, "%02d.wav" % (i + 1)))]
        print("Faltan %d de %d." % (len(faltan), len(FRASES)))
        for i in faltan:
            graba(i, FRASES[i])
    else:
        for i, frase in enumerate(FRASES):
            graba(i, frase)

    print("")
    print("Listo. Ahora, para medir:")
    print("    python tools\\probar-audio.py")
    print("Para repetir solo una:   python tools\\grabar-ordenes.py 7")
    print("Para grabar solo las que faltan:   python tools\\grabar-ordenes.py nuevas")


if __name__ == "__main__":
    main()
