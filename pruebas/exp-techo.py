# -*- coding: utf-8 -*-
"""El techo, con el parseo ya validado por el A/B y SIN mezclar corpus.
(exp-techo.py metia las frases de Nova y las de Gemini en la misma llamada; esto las
separa, que es lo que provoco la cifra inflada del 31 %.)"""
import io, json, os, subprocess, tempfile, collections
REPO = r"C:\Users\braya\Documents\voice-ctrl"
AQUI = os.path.dirname(os.path.abspath(__file__))

def reconoce(frases):
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    tmp = os.path.join(tempfile.gettempdir(), "techo2-%d.txt" % os.getpid())
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        for x in utiles: f.write(x.replace("\n", " ") + "\n")
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        os.path.join(REPO, "assistant.ps1"), "-Probar", tmp],
                       capture_output=True, cwd=REPO, timeout=1800)
    out = {}
    for linea in (r.stdout or b"").decode("utf-8", "replace").splitlines():
        t = linea.strip()
        if t.startswith("OK "): out[t[3:].strip().split("  ->")[0].strip()] = True
        elif t.startswith("->IA"): out[t[4:].strip()] = False
    try: os.remove(tmp)
    except Exception: pass
    return out

ents = collections.OrderedDict()
for l in io.open(os.path.join(REPO, "pruebas", "audio", "uso", "registro.jsonl"), encoding="utf-8"):
    if not l.strip(): continue
    r = json.loads(l)
    v = (r.get("entregado") or "").strip()
    if v: ents[r["id"]] = v
gem = json.load(io.open(os.path.join(AQUI, "techo-gemini.json"), encoding="utf-8"))
pares = []
for i, e in ents.items():
    t = ((gem.get("uso/" + i + ".wav") or {}).get("texto") or "").strip()
    if t: pares.append((i, e, t))
print("clips con las dos versiones: %d" % len(pares))

rn = reconoce([p[1] for p in pares])          # SOLO Nova
rg = reconoce([p[2] for p in pares])          # SOLO Gemini, en otra llamada
nova = [p for p in pares if rn.get(p[1])]
gemi = [p for p in pares if rg.get(p[2])]
solo_g = [p for p in pares if rg.get(p[2]) and not rn.get(p[1])]
solo_n = [p for p in pares if rn.get(p[1]) and not rg.get(p[2])]
n = len(pares)
print()
print("%-44s %5s %8s" % ("", "n", "%"))
print("%-44s %5d %7.1f%%" % ("Nova resuelve una accion (camino real)", len(nova), 100.0*len(nova)/n))
print("%-44s %5d %7.1f%%" % ("Gemini resolveria (techo en la nube)", len(gemi), 100.0*len(gemi)/n))
print("%-44s %5d %7.1f%%" % ("  ...solo Gemini = margen del oido", len(solo_g), 100.0*len(solo_g)/n))
print("%-44s %5d %7.1f%%" % ("  ...solo Nova", len(solo_n), 100.0*len(solo_n)/n))
json.dump({"n": n, "nova": len(nova), "gemini": len(gemi), "solo_gemini": len(solo_g),
           "solo_nova": len(solo_n),
           "margen": [{"id": i, "nova": e, "gemini": t} for i, e, t in solo_g]},
          io.open(os.path.join(AQUI, "exp-techo2.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
