# -*- coding: utf-8 -*-
"""Los clips donde el pipeline de HOY no resuelve: los rescata un Whisper mayor?

Se miden los tres candidatos sobre los MISMOS clips, uno cargado cada vez (4 nucleos,
RAM justa): base (el actual), small (el 'oido fino' ya configurado) y large-v3-turbo.
"""
import ast, io, json, os, sys, time, wave, glob
import numpy as np
from faster_whisper import WhisperModel

REPO = r"C:\Users\braya\Documents\voice-ctrl"
AQUI = os.path.dirname(os.path.abspath(__file__))
MODELO = sys.argv[1] if len(sys.argv) > 1 else "small"
SAL = os.path.join(AQUI, "rescate-%s.json" % MODELO.replace("/", "-"))

src = io.open(os.path.join(REPO, "wake_vosk.py"), encoding="utf-8").read()
ns = {"re": __import__("re")}
for nodo in ast.parse(src).body:
    if isinstance(nodo, ast.FunctionDef) and nodo.name == "limpiar_whisper":
        exec(compile(ast.Module(body=[nodo], type_ignores=[]), "<w>", "exec"), ns)
    elif isinstance(nodo, ast.Assign) and len(nodo.targets) == 1 and \
         getattr(nodo.targets[0], "id", "") in ("PROMPT_ORDENES", "TASA", "HILOS_PRECISO"):
        exec(compile(ast.Module(body=[nodo], type_ignores=[]), "<w>", "exec"), ns)
TASA = ns.get("TASA", 16000); PROMPT = ns.get("PROMPT_ORDENES", ""); HILOS = ns.get("HILOS_PRECISO", 8)

hoy = json.load(io.open(os.path.join(AQUI, "pipeline-hoy.json"), encoding="utf-8"))
exp = json.load(io.open(os.path.join(AQUI, "exp-hoy.json"), encoding="utf-8"))
resueltos = set(exp["gana"]) | {m["id"] for m in exp["margen"]}
# los que NO resuelven hoy: todo clip cuya via no acabo en accion
fallan = [w for w in sorted(hoy) if "entregado" in hoy[w] and hoy[w]["via"] in
          ("repaso-ingles", "parakeet-vacio", "cobertura")]
# y ademas los de parakeet que no resolvieron
print("clips a rescatar (vias flojas): %d" % len(fallan))

def leer(ruta):
    with wave.open(ruta, "rb") as w:
        n, sr, ch, sw = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    if ch > 1: x = x.reshape(-1, ch).mean(axis=1)
    if sr != TASA:
        idx = np.linspace(0, len(x) - 1, int(len(x) * TASA / sr)).astype(np.int64); x = x[idx]
    return x

t0 = time.time()
m = WhisperModel(MODELO, device="cpu", compute_type="int8", cpu_threads=HILOS)
print("%s cargado en %.1f s" % (MODELO, time.time() - t0))
USO = os.path.join(REPO, "pruebas", "audio", "uso")
out = {}
if os.path.exists(SAL):
    try: out = json.load(io.open(SAL, encoding="utf-8"))
    except Exception: out = {}
n = 0
for w in fallan:
    if w in out: continue
    try:
        a = leer(os.path.join(USO, w))
        t1 = time.time()
        segs, _ = m.transcribe(a, language="es", beam_size=2, best_of=1,
            vad_filter=True, vad_parameters=dict(min_silence_duration_ms=500),
            condition_on_previous_text=False, no_speech_threshold=0.6,
            log_prob_threshold=-1.0, compression_ratio_threshold=2.4, initial_prompt=PROMPT)
        out[w] = {"texto": ns["limpiar_whisper"](" ".join(s.text.strip() for s in segs).strip()),
                  "s": round(time.time() - t1, 2)}
    except Exception as e:
        out[w] = {"error": str(e)[:150]}
    n += 1
    if n % 15 == 0:
        json.dump(out, io.open(SAL, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        print("  %d/%d  %r" % (n, len(fallan), out[w].get("texto", "")[:44]), flush=True)
json.dump(out, io.open(SAL, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
ts = [v["s"] for v in out.values() if "s" in v]
print("TERMINADO %s: %d clips, mediana %.2f s" % (MODELO, len(out), sorted(ts)[len(ts)//2] if ts else 0))
