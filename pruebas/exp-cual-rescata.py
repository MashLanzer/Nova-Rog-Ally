# -*- coding: utf-8 -*-
"""Cual de los candidatos rescata mas de los 74 clips que hoy se pierden."""
import io, json, os, subprocess, tempfile, collections
REPO = r"C:\Users\braya\Documents\voice-ctrl"
AQUI = os.path.dirname(os.path.abspath(__file__))

def reconoce(frases, etiq):
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    if not utiles: return {}
    tmp = os.path.join(tempfile.gettempdir(), "cual-%s-%d.txt" % (etiq, os.getpid()))
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

hoy = json.load(io.open(os.path.join(AQUI, "pipeline-hoy.json"), encoding="utf-8"))
gem = json.load(io.open(os.path.join(AQUI, "techo-gemini.json"), encoding="utf-8"))
sml = json.load(io.open(os.path.join(AQUI, "rescate-small.json"), encoding="utf-8"))
tur = {}
p = os.path.join(AQUI, "rescate-large-v3-turbo.json")
if os.path.exists(p):
    try: tur = json.load(io.open(p, encoding="utf-8"))
    except Exception: tur = {}

clips = sorted(sml)
print("clips evaluados (los que hoy se pierden): %d" % len(clips))
cands = {
    "hoy (base)": {w: hoy[w]["entregado"] for w in clips if w in hoy},
    "small":      {w: sml[w].get("texto", "") for w in clips},
    "gemini":     {w: ((gem.get("uso/" + w) or {}).get("texto") or "") for w in clips},
}
if tur: cands["turbo"] = {w: tur[w].get("texto", "") for w in clips if w in tur}

res = {}
for nombre, d in cands.items():
    res[nombre] = reconoce(list(d.values()), nombre.replace(" ", ""))
print()
print("%-14s %8s %8s" % ("motor", "rescata", "%"))
rescatan = {}
for nombre, d in cands.items():
    r = res[nombre]
    ok = [w for w, t in d.items() if t and r.get(t.strip())]
    rescatan[nombre] = set(ok)
    print("%-14s %8d %7.1f%%" % (nombre, len(ok), 100.0*len(ok)/len(clips)))
print()
base = rescatan.get("hoy (base)", set())
for nombre in cands:
    if nombre == "hoy (base)": continue
    extra = rescatan[nombre] - base
    print("=== %s rescata %d que hoy se pierden ===" % (nombre, len(extra)))
    for w in sorted(extra)[:14]:
        print("   %s  hoy:%r" % (w[:15], (hoy.get(w, {}).get("entregado") or "")[:26]))
        print("        %s:%r" % (nombre, cands[nombre][w][:52]))
    print()
json.dump({k: sorted(v) for k, v in rescatan.items()},
          io.open(os.path.join(AQUI, "cual-rescata.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
