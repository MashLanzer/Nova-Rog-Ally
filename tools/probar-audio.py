# -*- coding: utf-8 -*-
"""Mide si el reconocedor TE ENTIENDE A TI, con audio de verdad.

Todo el resto del banco mide texto. Esto pasa tus grabaciones por el MISMO
camino que usa el asistente -mismo modelo, mismos umbrales, mismas hotwords,
misma limpieza- y dice cuantas salen bien con el modelo rapido y cuantas
necesitan el oido fino. Es la unica forma de saber si un cambio en el
reconocimiento mejora o empeora, en vez de suponerlo.

    python tools\\grabar-ordenes.py     (una vez, graba tu voz)
    python tools\\probar-audio.py       (cada vez que se toque el oido)

Devuelve 1 si baja del listón que hay en el propio archivo, para poder
encadenarlo con el resto de comprobaciones.
"""
import os
import re
import sys
import json
import time
import unicodedata

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(RAIZ, "pruebas", "audio")

import wave

try:
    import numpy as np
    from faster_whisper import WhisperModel
except Exception as e:  # pragma: no cover
    # Faltar un paquete no es que el oido haya empeorado: se avisa y se sale
    # BIEN, o esto tumbaria el banco entero en una maquina recien montada.
    print("Falta un paquete: %s" % e)
    print("Instala con:  pip install numpy faster-whisper")
    sys.exit(0)


def lee_wav(ruta):
    with wave.open(ruta, "rb") as w:
        canales = w.getnchannels()
        crudo = w.readframes(w.getnframes())
    a = np.frombuffer(crudo, dtype="<i2").astype("float32") / 32767.0
    if canales > 1:
        a = a.reshape(-1, canales).mean(axis=1)
    return a


def cfg(*camino):
    with open(os.path.join(RAIZ, "config.json"), "r", encoding="utf-8-sig") as f:
        c = json.load(f)
    for k in camino:
        c = c.get(k, {}) if isinstance(c, dict) else {}
    return c


def limpiar_whisper(texto):
    # COPIA EXACTA de wake_vosk.py: si esto se desincroniza, la prueba mide
    # otra cosa distinta de lo que hace el asistente y no vale para nada.
    t = (texto or "").strip()
    t = re.sub(r"\s*\.\s+", ", ", t)
    t = re.sub(r"[.…!?]+$", "", t).strip()
    return t


def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9 ]+", " ", re.sub(r"\s+", " ", s)).strip()


def vocabulario():
    ruta = os.path.join(RAIZ, "tmp", "vocabulario.txt")
    if not os.path.exists(ruta):
        return None
    try:
        with open(ruta, "r", encoding="utf-8") as f:
            return f.read().strip() or None
    except Exception:
        return None


def transcribe(modelo, audio, hotwords):
    # los MISMOS parametros que wake_vosk.py, por la misma razon de arriba
    segmentos, _ = modelo.transcribe(
        audio, language="es", beam_size=2, best_of=1,
        vad_filter=True, vad_parameters=dict(min_silence_duration_ms=500),
        condition_on_previous_text=False,
        no_speech_threshold=0.6,
        log_prob_threshold=-1.0,
        compression_ratio_threshold=2.4,
        hotwords=hotwords)
    return limpiar_whisper(" ".join(s.text.strip() for s in segmentos).strip())


def main():
    esperado_json = os.path.join(AUDIO, "esperado.json")
    if not os.path.exists(esperado_json):
        print("No hay grabaciones todavia.")
        print("Graba las tuyas una sola vez con:   python tools\\grabar-ordenes.py")
        return 0          # no es un fallo: es que aun no las has hecho

    with open(esperado_json, "r", encoding="utf-8") as f:
        esperado = json.load(f)
    hay = [n for n in sorted(esperado) if os.path.exists(os.path.join(AUDIO, n))]
    if not hay:
        print("esperado.json existe pero no hay ningun .wav al lado.")
        return 0

    rapido = cfg("input", "whisperModelo") or "base"
    preciso = cfg("input", "whisperModeloPreciso") or "small"
    hw = vocabulario()

    print("modelo rapido: %s     oido fino: %s     hotwords: %s"
          % (rapido, preciso, "si" if hw else "no"))
    t0 = time.time()
    mr = WhisperModel(rapido, device="cpu", compute_type="int8", cpu_threads=4)
    print("cargado en %.1f s" % (time.time() - t0))

    bien = 0
    dudosos = []
    print("")
    for nombre in hay:
        audio = lee_wav(os.path.join(AUDIO, nombre))
        t1 = time.time()
        oido = transcribe(mr, audio, hw)
        tarda = time.time() - t1
        quiero = esperado[nombre]
        ok = plano(oido) == plano(quiero)
        if ok:
            bien += 1
        else:
            dudosos.append((nombre, quiero, oido))
        print("  %s  %-38s %-38s %4.1f s"
              % ("OK " if ok else "MAL", quiero, oido or "(nada)", tarda))

    total = len(hay)
    print("")
    print("con el modelo rapido: %d de %d" % (bien, total))

    if dudosos:
        print("")
        print("las que fallaron, con el oido fino (%s):" % preciso)
        mp = WhisperModel(preciso, device="cpu", compute_type="int8", cpu_threads=4)
        rescatadas = 0
        for nombre, quiero, antes in dudosos:
            audio = lee_wav(os.path.join(AUDIO, nombre))
            t1 = time.time()
            oido = transcribe(mp, audio, hw)
            ok = plano(oido) == plano(quiero)
            if ok:
                rescatadas += 1
            print("  %s  %-38s %-38s %4.1f s"
                  % ("OK " if ok else "MAL", quiero, oido or "(nada)", time.time() - t1))
        print("")
        print("el oido fino rescata %d de %d" % (rescatadas, len(dudosos)))
        print("total entendidas: %d de %d" % (bien + rescatadas, total))

    # EL LISTON. Se sube a mano cuando se mejora, igual que el 3 del ruido: lo
    # que importa no es el numero absoluto, es que no BAJE sin que nadie mire.
    liston = 0.60
    if total and (bien / float(total)) < liston:
        print("")
        print("POR DEBAJO del liston (%d%% con el modelo rapido)" % int(liston * 100))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
