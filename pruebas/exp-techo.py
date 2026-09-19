# -*- coding: utf-8 -*-
"""EL TECHO: si el oido fuera perfecto, cuantas ordenes mas entenderia Nova?

Compara, sobre los MISMOS audios de uso real, lo que entrego Nova con lo que oyo
Gemini, midiendo lo unico que importa: si la capa local resuelve una ACCION.
"""
import io, json, os, subprocess, sys, tempfile, collections
AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = r"C:\Users\braya\Documents\voice-ctrl"

def reconoce(frases):
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    if not utiles: return {}
    tmp = os.path.join(tempfile.gettempdir(), "exp-techo-%d.txt" % os.getpid())
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        for x in utiles: f.write(x.replace("\n", " ") + "\n")
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        os.path.join(REPO, "assistant.ps1"), "-Probar", tmp],
                       capture_output=True, cwd=REPO, timeout=1800)
    out = {}
    for linea in (r.stdout or b"").decode("utf-8", "replace").splitlines():
        t = linea.strip()
        if t.startswith("OK "):
            cuerpo = t[3:].strip()
            frase = cuerpo.split("  ->")[0].strip()
            accion = cuerpo.split("  ->")[1].strip() if "  ->" in cuerpo else ""
            out[frase] = accion or "(sin desc)"
        elif t.startswith("->IA"):
            out[t[4:].strip()] = None
    try: os.remove(tmp)
    except Exception: pass
    return out

gem = json.load(io.open(os.path.join(AQUI, "techo-gemini.json"), encoding="utf-8"))
ords = collections.OrderedDict()
for l in io.open(os.path.join(REPO, "pruebas", "audio", "uso", "registro.jsonl"), encoding="utf-8"):
    if not l.strip(): continue
    r = json.loads(l)
    i = r["id"]
    o = ords.setdefault(i, {"ent": "", "dur": 0})
    if (r.get("entregado") or "").strip(): o["ent"] = r["entregado"].strip()
    if r.get("dur"): o["dur"] = r["dur"]

pares = []
for i, o in ords.items():
    g = gem.get("uso/" + i + ".wav") or {}
    t = (g.get("texto") or "").strip()
    if not t: continue
    pares.append((i, o["ent"], t, o["dur"]))
print("clips de uso real con las dos versiones (Nova y Gemini): %d" % len(pares))

res = reconoce([p[1] for p in pares] + [p[2] for p in pares])
def acc(x): return res.get((x or "").strip())

nova_ok = [p for p in pares if acc(p[1])]
gem_ok   = [p for p in pares if acc(p[2])]
solo_gem = [p for p in pares if acc(p[2]) and not acc(p[1])]
solo_nova= [p for p in pares if acc(p[1]) and not acc(p[2])]
ambos    = [p for p in pares if acc(p[1]) and acc(p[2])]
distinta = [p for p in ambos if acc(p[1]) != acc(p[2])]

n = len(pares)
print()
print("%-46s %5s %7s" % ("", "n", "% "))
print("%-46s %5d %6.1f%%" % ("Nova resuelve una accion hoy", len(nova_ok), 100.0*len(nova_ok)/n))
print("%-46s %5d %6.1f%%" % ("Gemini (oido casi perfecto) resolveria", len(gem_ok), 100.0*len(gem_ok)/n))
print("%-46s %5d %6.1f%%" % ("  ...solo Gemini (lo que gana un oido mejor)", len(solo_gem), 100.0*len(solo_gem)/n))
print("%-46s %5d %6.1f%%" % ("  ...solo Nova (donde Gemini es peor)", len(solo_nova), 100.0*len(solo_nova)/n))
print("%-46s %5d" % ("  ...los dos, pero accion DISTINTA", len(distinta)))
print()
print("=== LO QUE GANARIA UN OIDO PERFECTO (solo Gemini) ===")
for i, e, t, dur in solo_gem[:30]:
    print("  %s d=%.1f" % (i, dur))
    print("     Nova  : %r   -> nada" % e[:56])
    print("     Gemini: %r   -> %s" % (t[:56], acc(t)))
print()
print("=== DONDE GEMINI ES PEOR ===")
for i, e, t, dur in solo_nova[:10]:
    print("  %s  Nova: %r -> %s   |  Gemini: %r" % (i, e[:40], acc(e), t[:40]))
json.dump({"n": n, "nova": len(nova_ok), "gemini": len(gem_ok), "solo_gemini": len(solo_gem),
           "solo_nova": len(solo_nova),
           "ids_solo_gemini": [{"id": i, "nova": e, "gemini": t, "accion": acc(t)} for i, e, t, d in solo_gem]},
          io.open(os.path.join(AQUI, "exp-techo.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
