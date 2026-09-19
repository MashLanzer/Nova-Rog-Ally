# -*- coding: utf-8 -*-
"""Nova de HOY vs Nova del registro (vieja) vs Gemini (techo), sobre los MISMOS clips.
Cada motor se mide en su PROPIA llamada al probador: mezclarlos contamina las claves."""
import io, json, os, subprocess, tempfile, collections
REPO = r"C:\Users\braya\Documents\voice-ctrl"
AQUI = os.path.dirname(os.path.abspath(__file__))

def reconoce(frases, etiq):
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    tmp = os.path.join(tempfile.gettempdir(), "hoy-%s-%d.txt" % (etiq, os.getpid()))
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
viejo = {}
for l in io.open(os.path.join(REPO, "pruebas", "audio", "uso", "registro.jsonl"), encoding="utf-8"):
    if not l.strip(): continue
    r = json.loads(l); v = (r.get("entregado") or "").strip()
    if v: viejo[r["id"] + ".wav"] = v

clips = [w for w in sorted(hoy) if "entregado" in hoy[w]]
rH = reconoce([hoy[w]["entregado"] for w in clips], "hoy")
rV = reconoce([viejo.get(w, "") for w in clips], "viejo")
rG = reconoce([(gem.get("uso/" + w) or {}).get("texto", "") for w in clips], "gem")
def okH(w): return rH.get(hoy[w]["entregado"].strip(), False)
def okV(w): return rV.get(viejo.get(w, "").strip(), False)
def okG(w): return rG.get(((gem.get("uso/" + w) or {}).get("texto") or "").strip(), False)

n = len(clips)
nH = sum(1 for w in clips if okH(w)); nV = sum(1 for w in clips if okV(w)); nG = sum(1 for w in clips if okG(w))
print("clips medidos: %d" % n)
print()
print("%-44s %5s %8s" % ("", "n", "%"))
print("%-44s %5d %7.1f%%" % ("Nova VIEJA (lo que entrego en su dia)", nV, 100.0*nV/n))
print("%-44s %5d %7.1f%%" % ("Nova DE HOY (pipeline actual)", nH, 100.0*nH/n))
print("%-44s %5d %7.1f%%" % ("Gemini (techo en la nube)", nG, 100.0*nG/n))
print()
gana = [w for w in clips if okH(w) and not okV(w)]
pierde = [w for w in clips if okV(w) and not okH(w)]
print("HOY frente a la vieja: gana %d, pierde %d" % (len(gana), len(pierde)))
for w in gana[:12]:
    print("   + %s  viejo:%r  hoy:%r [%s]" % (w[:15], viejo.get(w, "")[:30], hoy[w]["entregado"][:34], hoy[w]["via"]))
for w in pierde[:8]:
    print("   - %s  viejo:%r  hoy:%r [%s]" % (w[:15], viejo.get(w, "")[:30], hoy[w]["entregado"][:34], hoy[w]["via"]))
print()
margen = [w for w in clips if okG(w) and not okH(w)]
print("MARGEN que deja el oido de la nube sobre el de hoy: %d (%.1f%%)" % (len(margen), 100.0*len(margen)/n))
print()
print("por via del pipeline de hoy:")
c = collections.Counter(hoy[w]["via"] for w in clips)
for via in c:
    tot = c[via]; ok = sum(1 for w in clips if hoy[w]["via"] == via and okH(w))
    print("   %-20s %4d clips, resuelven %3d (%.1f%%)" % (via, tot, ok, 100.0*ok/tot))
json.dump({"n": n, "vieja": nV, "hoy": nH, "gemini": nG, "gana": gana, "pierde": pierde,
           "margen": [{"id": w, "hoy": hoy[w]["entregado"], "gemini": (gem.get("uso/"+w) or {}).get("texto","")} for w in margen]},
          io.open(os.path.join(AQUI, "exp-hoy.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
