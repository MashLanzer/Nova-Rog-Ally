# -*- coding: utf-8 -*-
"""A/B honesto: el MISMO corpus, por el codigo de ANTES y el de AHORA."""
import io, json, os, subprocess, tempfile, collections
REPO = r"C:\Users\braya\Documents\voice-ctrl"

def reconoce(frases, script):
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    tmp = os.path.join(tempfile.gettempdir(), "ab-%s-%d.txt" % (os.path.basename(script), os.getpid()))
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        for x in utiles: f.write(x.replace("\n", " ") + "\n")
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        os.path.join(REPO, script), "-Probar", tmp], capture_output=True, cwd=REPO, timeout=1800)
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
frases = sorted(set(ents.values()))

viejo = reconoce(frases, "assistant-viejo.ps1")
nuevo = reconoce(frases, "assistant.ps1")
gana = [f for f in frases if nuevo.get(f) and not viejo.get(f)]
pierde = [f for f in frases if viejo.get(f) and not nuevo.get(f)]
nv = sum(1 for f in frases if viejo.get(f)); nn = sum(1 for f in frases if nuevo.get(f))
print("ENTREGAS REALES DE NOVA (%d frases distintas, el camino que corre)" % len(frases))
print("   con el codigo de ANTES : %d reconocidas (%.1f%%)" % (nv, 100.0*nv/len(frases)))
print("   con el codigo de AHORA : %d reconocidas (%.1f%%)" % (nn, 100.0*nn/len(frases)))
print("   gana %d, pierde %d" % (len(gana), len(pierde)))
for f in gana[:20]: print("      + %r" % f[:60])
for f in pierde[:10]: print("      - %r" % f[:60])

# en CLIPS, que es como se vive
cv = sum(1 for i, f in ents.items() if viejo.get(f)); cn = sum(1 for i, f in ents.items() if nuevo.get(f))
print()
print("   en CLIPS (%d con entrega): antes %d (%.1f%%) -> ahora %d (%.1f%%)" % (
    len(ents), cv, 100.0*cv/len(ents), cn, 100.0*cn/len(ents)))

ruido = [l.strip() for l in io.open(os.path.join(REPO, "pruebas", "ruido-real.txt"), encoding="utf-8")
         if l.strip() and not l.strip().startswith("#")]
rv = reconoce(ruido, "assistant-viejo.ps1"); rn = reconoce(ruido, "assistant.ps1")
print()
print("RUIDO (menos es mejor): antes %d de %d -> ahora %d de %d" % (
    sum(1 for f in ruido if rv.get(f)), len(ruido), sum(1 for f in ruido if rn.get(f)), len(ruido)))
