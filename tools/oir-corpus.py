# -*- coding: utf-8 -*-
# Pasa TODAS las grabaciones de braya que tienen su texto de verdad por UN oido, y guarda
# lo que saca. Un oido por ejecucion: cargar dos modelos de ASR a la vez en una consola de
# 16 GB con Nova en marcha es como se mato el banco a medias el 14/09.
#
# Uso:   python tools/oir-corpus.py parakeet|canary [cuantos]
# Deja:  tmp/oido-<cual>.json
import io
import os
import sys
import glob
import json
import time
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CUAL = (sys.argv[1] if len(sys.argv) > 1 else "parakeet").lower()
CUANTOS = int(sys.argv[2]) if len(sys.argv) > 2 else 0


def corpus():
    fuera = []
    for carpeta in ("cien", "dirigida", "validacion", "validacion2"):
        d = os.path.join(RAIZ, "pruebas", "audio", carpeta)
        p = os.path.join(d, "esperado.json")
        if not os.path.exists(p):
            continue
        try:
            j = json.load(io.open(p, encoding="utf-8-sig"))
        except Exception:
            continue
        for nombre in sorted(j):
            v = j[nombre]
            w = os.path.join(d, nombre)
            texto = (v.get("texto") if isinstance(v, dict) else v) or ""
            if os.path.exists(w) and texto:
                fuera.append({"wav": w, "verdad": texto, "de": carpeta,
                              "tipo": (v.get("tipo") if isinstance(v, dict) else "") or ""})
    return fuera


def carga():
    import sherpa_onnx
    if CUAL == "omni":
        # OMNILINGUAL 300M (Meta): 1600 idiomas, CTC. NO se le puede decir el idioma
        # (from_omnilingual_asr_ctc solo acepta model/tokens), asi que tiene el mismo
        # riesgo que Parakeet: adivinarlo. Se mide para saberlo, no para suponerlo.
        d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*omnilingual*")) if os.path.isdir(c)][0]

        def f(p):
            return sorted(glob.glob(os.path.join(d, p)))[0]
        return sherpa_onnx.OfflineRecognizer.from_omnilingual_asr_ctc(
            model=f("model*.onnx"), tokens=f("tokens.txt"), num_threads=4)
    if CUAL == "canary":
        d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*canary*")) if os.path.isdir(c)][0]

        def f(p):
            return sorted(glob.glob(os.path.join(d, p)))[0]
        # src_lang="es": AQUI ESTA TODO. A Parakeet no se le puede decir el idioma y lo
        # adivina por frase; este lo sabe porque se lo decimos.
        return sherpa_onnx.OfflineRecognizer.from_nemo_canary(
            encoder=f("encoder*.onnx"), decoder=f("decoder*.onnx"), tokens=f("tokens.txt"),
            src_lang="es", tgt_lang="es", num_threads=4)
    d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*parakeet*")) if os.path.isdir(c)][0]

    def f(p):
        return sorted(glob.glob(os.path.join(d, p)))[0]
    # EXACTAMENTE como lo carga wake_vosk.py, o no se estaria midiendo lo que corre
    return sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=f("encoder*.onnx"), decoder=f("decoder*.onnx"), joiner=f("joiner*.onnx"),
        tokens=f("tokens.txt"), num_threads=4, decoding_method="greedy_search",
        model_type="nemo_transducer")


class _Whisper:
    """faster-whisper con el idioma FIJADO. Es lo que hace Nova hoy con base y small; aqui
    sirve para medir tambien large-v3-turbo, que es mucho mejor y no se ha probado."""

    def __init__(self, nombre):
        from faster_whisper import WhisperModel
        self.m = WhisperModel(nombre, device="cpu", compute_type="int8", cpu_threads=4)

    def create_stream(self):
        return {"a": None, "t": ""}

    def decode(self, audio):
        segs, _ = self.m.transcribe(audio, language="es", beam_size=2, best_of=1)
        return " ".join(x.text.strip() for x in segs).strip()


def main():
    import numpy as np
    datos = corpus()
    if CUANTOS:
        datos = datos[:CUANTOS]
    print("  %s: %d grabaciones" % (CUAL, len(datos)), flush=True)
    t0 = time.time()
    esWhisper = CUAL.startswith("whisper-")
    rec = _Whisper(CUAL[len("whisper-"):]) if esWhisper else carga()
    tCarga = time.time() - t0
    print("  cargado en %.1f s" % tCarga, flush=True)

    salidas, tTotal, segAudio = [], 0.0, 0.0
    for i, d in enumerate(datos):
        with wave.open(d["wav"], "rb") as x:
            a = np.frombuffer(x.readframes(x.getnframes()), dtype=np.int16).astype("float32") / 32768.0
            tasa = x.getframerate()
            segAudio += x.getnframes() / float(tasa)
        t1 = time.time()
        if esWhisper:
            salidas.append(rec.decode(a))
        else:
            s = rec.create_stream()
            s.accept_waveform(tasa, a)
            rec.decode_stream(s)
            salidas.append(s.result.text)
        tTotal += time.time() - t1
        if (i + 1) % 25 == 0:
            print("    %d/%d  (%.0f ms por audio)" % (i + 1, len(datos), 1000.0 * tTotal / (i + 1)), flush=True)

    fuera = {"cual": CUAL, "carga_s": tCarga, "seg": tTotal, "seg_audio": segAudio,
             "n": len(datos),
             "items": [{"wav": os.path.basename(d["wav"]), "de": d["de"], "tipo": d["tipo"],
                        "verdad": d["verdad"], "salio": s} for d, s in zip(datos, salidas)]}
    dest = os.path.join(RAIZ, "tmp", "oido-%s.json" % CUAL)
    io.open(dest, "w", encoding="utf-8").write(json.dumps(fuera, ensure_ascii=False, indent=1))
    print("  hecho: %.0f ms por audio, x%.2f tiempo real -> %s"
          % (1000.0 * tTotal / max(1, len(datos)), tTotal / max(0.001, segAudio), dest), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
