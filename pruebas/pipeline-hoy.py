# -*- coding: utf-8 -*-
"""Pasa los WAV por el pipeline de HOY: Parakeet -> cobertura -> guarda del ingles -> Whisper.

Las funciones puras (segundos_de_voz, cobertura_parakeet, suena_ingles, limpiar_whisper y
las listas PALABRAS_ES/EN) se EXTRAEN de wake_vosk.py con ast, no se copian: asi no se
desincronizan cuando alguien toque el original. Los parametros de los modelos son los
mismos que usa el worker (leidos de wake_vosk.py y config.json).
"""
import ast, io, json, os, re, sys, time, unicodedata, wave
import numpy as np

REPO = r"C:\Users\braya\Documents\voice-ctrl"
AQUI = os.path.dirname(os.path.abspath(__file__))
SAL = os.path.join(AQUI, "pipeline-hoy.json")

# --- extraer del worker, sin ejecutarlo ---
src = io.open(os.path.join(REPO, "wake_vosk.py"), encoding="utf-8").read()
arbol = ast.parse(src)
ns = {"np": np, "re": re, "unicodedata": unicodedata, "time": time, "os": os}
# EL LISTON YA NO ES UN NUMERO, ES UNA FUNCION (22/09). Antes se traia
# PARAKEET_COBERTURA_MIN, un 4,0 escrito a mano; desde el 22/09 el liston se lo pone Nova
# con el ritmo de habla de braya (cobertura_min + apuntar_cobertura). Aqui se traen las
# dos y se alimenta el aprendizaje wav a wav, en el mismo orden, para que esta herramienta
# mida el camino DE VERDAD y no uno congelado.
QUIERO_FUN = {"segundos_de_voz", "cobertura_parakeet", "suena_ingles", "limpiar_whisper",
              "cobertura_min", "apuntar_cobertura"}
QUIERO_VAR = {"PALABRAS_ES", "PALABRAS_EN", "COBERTURA_ARRANQUE", "COBERTURA_SUELO",
              "COBERTURA_TECHO", "COBERTURA_FRACCION", "COBERTURA_MEMORIA",
              "COBERTURA_MINIMAS", "TASA", "HILOS_PRECISO",
              "PROMPT_ORDENES", "TRANSCRIBIR_MAX"}
for nodo in arbol.body:
    if isinstance(nodo, ast.FunctionDef) and nodo.name in QUIERO_FUN:
        exec(compile(ast.Module(body=[nodo], type_ignores=[]), "<w>", "exec"), ns)
    elif isinstance(nodo, ast.Assign) and len(nodo.targets) == 1 and isinstance(nodo.targets[0], ast.Name) \
            and nodo.targets[0].id in QUIERO_VAR:
        try: exec(compile(ast.Module(body=[nodo], type_ignores=[]), "<w>", "exec"), ns)
        except Exception: pass
faltan = (QUIERO_FUN | QUIERO_VAR) - set(ns)
if faltan: print("OJO, no se pudo extraer: %s" % sorted(faltan))
TASA = ns.get("TASA", 16000)
ns["coberturas"] = []   # la memoria del liston, igual que en el worker
HILOS = ns.get("HILOS_PRECISO", 8); PROMPT = ns.get("PROMPT_ORDENES", "")
TMAX = ns.get("TRANSCRIBIR_MAX", 30)
print("extraido de wake_vosk.py: liston de arranque=%.1f (aprende solo) hilos=%d prompt=%r"
      % (ns.get("COBERTURA_ARRANQUE", 4.0), HILOS, PROMPT[:40]))

cfg = json.load(io.open(os.path.join(REPO, "config.json"), encoding="utf-8-sig"))
MOD_W = cfg.get("input", {}).get("whisperModelo", "base")
print("whisper del worker: %r" % MOD_W)

def leer(ruta):
    with wave.open(ruta, "rb") as w:
        n, sr, ch, sw = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) if sw == 2 else \
        (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128) * 256
    if ch > 1: x = x.reshape(-1, ch).mean(axis=1)
    if sr != TASA:
        idx = np.linspace(0, len(x) - 1, int(len(x) * TASA / sr)).astype(np.int64); x = x[idx]
    return x.astype(np.int16)

import glob, sherpa_onnx
from faster_whisper import WhisperModel
carp = [c for c in glob.glob(os.path.join(REPO, "modelos", "*parakeet*")) if os.path.isdir(c)][0]
f = lambda p: sorted(glob.glob(os.path.join(carp, p)))[0]
t0 = time.time()
par = sherpa_onnx.OfflineRecognizer.from_transducer(
    encoder=f("encoder*.onnx"), decoder=f("decoder*.onnx"), joiner=f("joiner*.onnx"),
    tokens=f("tokens.txt"), num_threads=HILOS, decoding_method="greedy_search", model_type="nemo_transducer")
print("parakeet cargado en %.1f s" % (time.time() - t0))
t0 = time.time()
whi = WhisperModel(MOD_W, device="cpu", compute_type="int8", cpu_threads=HILOS)
list(whi.transcribe(np.zeros(TASA, dtype=np.float32), language="es", beam_size=1)[0])
print("whisper '%s' cargado en %.1f s" % (MOD_W, time.time() - t0))

def oir_whisper(a16):
    audio = a16.astype(np.float32) / 32768.0
    if audio.size < TASA // 4: return ""
    tope = int(TASA * TMAX)
    if audio.size > tope: audio = audio[:tope]
    segs, _ = whi.transcribe(audio, language="es", beam_size=2, best_of=1,
        vad_filter=True, vad_parameters=dict(min_silence_duration_ms=500),
        condition_on_previous_text=False, no_speech_threshold=0.6,
        log_prob_threshold=-1.0, compression_ratio_threshold=2.4, initial_prompt=PROMPT)
    return ns["limpiar_whisper"](" ".join(s.text.strip() for s in segs).strip())

def pipeline(a16):
    """Lo mismo que hace el worker, en el mismo orden."""
    audio = a16.astype(np.float32) / 32768.0
    par_txt, motivo = "", ""
    if audio.size >= TASA // 4:
        st = par.create_stream(); st.accept_waveform(TASA, audio); par.decode_stream(st)
        par_txt = ns["limpiar_whisper"](st.result.text.strip())
        if par_txt:
            _c = ns["cobertura_parakeet"](par_txt, audio)
            _lis = ns["cobertura_min"]()
            ns["apuntar_cobertura"](_c)   # ANTES de decidir, como en el worker
            if _c < _lis:
                motivo = "cobertura"; par_txt = ""
    if par_txt and ns["suena_ingles"](par_txt):
        w = oir_whisper(a16)
        if w: return w, par_txt, "repaso-ingles"
        return par_txt, par_txt, "ingles-sin-rescate"
    if par_txt: return par_txt, par_txt, "parakeet"
    w = oir_whisper(a16)
    return w, "", (motivo or "parakeet-vacio")

USO = os.path.join(REPO, "pruebas", "audio", "uso")
wavs = sorted(x for x in os.listdir(USO) if x.lower().endswith(".wav"))
hecho = {}
if os.path.exists(SAL):
    try: hecho = json.load(io.open(SAL, encoding="utf-8"))
    except Exception: hecho = {}
print("clips: %d (ya hechos: %d)" % (len(wavs), len(hecho)))
n = 0
for w in wavs:
    if w in hecho: continue
    try:
        a = leer(os.path.join(USO, w))
        t1 = time.time()
        ent, pk, via = pipeline(a)
        hecho[w] = {"entregado": ent, "parakeet": pk, "via": via,
                    "dur": round(len(a) / TASA, 2), "s": round(time.time() - t1, 2)}
    except Exception as e:
        hecho[w] = {"error": str(e)[:160]}
    n += 1
    if n % 20 == 0:
        json.dump(hecho, io.open(SAL, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        print("  %d/%d  ultimo: [%s] %r" % (n, len(wavs), hecho[w].get("via"), hecho[w].get("entregado", "")[:46]), flush=True)
json.dump(hecho, io.open(SAL, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
import collections
print("TERMINADO. vias:", collections.Counter(v.get("via") for v in hecho.values()))
