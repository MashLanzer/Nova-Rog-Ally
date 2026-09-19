# -*- coding: utf-8 -*-
"""EXPERIMENTO: cuanto se pierde SOLO por la puntuacion final.

Hallazgo del 19/09: "Cierra todo" resuelve y "Cierra todo." no. "Revisa mi correo"
resuelve y "Revisa mi correo." no. Si la capa local rechaza el punto, cada transcripcion
que venga puntuada (Gemini siempre, Parakeet a menudo) se pierde entera.
"""
import io, json, os, re, subprocess, sys, tempfile, collections
AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = r"C:\Users\braya\Documents\voice-ctrl"

def reconoce(frases):
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    if not utiles: return {}
    tmp = os.path.join(tempfile.gettempdir(), "exp-punt-%d.txt" % os.getpid())
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        for x in utiles: f.write(x.replace("\n", " ") + "\n")
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        os.path.join(REPO, "assistant.ps1"), "-Probar", tmp],
                       capture_output=True, cwd=REPO, timeout=1800)
    out = {}
    for linea in (r.stdout or b"").decode("utf-8", "replace").splitlines():
        t = linea.strip()
        if t.startswith("OK "):
            cuerpo = t[3:].strip(); out[cuerpo.split("  ->")[0].strip()] = True
        elif t.startswith("->IA"): out[t[4:].strip()] = False
    try: os.remove(tmp)
    except Exception: pass
    return out

def despunta(t):
    """Lo minimo: fuera signos de apertura y puntuacion final."""
    t = (t or "").strip()
    t = t.replace("\u00bf", "").replace("\u00a1", "")
    return re.sub(r"[.!?,;:\s]+$", "", t).strip()

# --- corpus: todo lo entregado por Nova + todo lo oido por Gemini, sobre los mismos audios ---
gem = json.load(io.open(os.path.join(AQUI, "techo-gemini.json"), encoding="utf-8"))
frases = set()
for l in io.open(os.path.join(REPO, "pruebas", "audio", "uso", "registro.jsonl"), encoding="utf-8"):
    if l.strip():
        e = (json.loads(l).get("entregado") or "").strip()
        if e: frases.add(e)
for k, v in gem.items():
    t = (v.get("texto") or "").strip()
    if t: frases.add(t)
frases = sorted(frases)
con_punt = [f for f in frases if despunta(f) != f]
print("frases distintas en total          : %d" % len(frases))
print("  ...de ellas, llevan puntuacion   : %d (%.1f%%)" % (len(con_punt), 100.0*len(con_punt)/len(frases)))

res = reconoce(frases + [despunta(f) for f in con_punt])
gana = [(f, despunta(f)) for f in con_punt if not res.get(f) and res.get(despunta(f))]
pierde = [(f, despunta(f)) for f in con_punt if res.get(f) and not res.get(despunta(f))]
ok_antes = sum(1 for f in frases if res.get(f))
ok_despues = sum(1 for f in frases if res.get(despunta(f)) or res.get(f))
print()
print("reconocidas TAL CUAL               : %d de %d (%.1f%%)" % (ok_antes, len(frases), 100.0*ok_antes/len(frases)))
print("reconocidas QUITANDO la puntuacion : %d de %d (%.1f%%)" % (ok_despues, len(frases), 100.0*ok_despues/len(frases)))
print("GANADAS solo por quitar el punto   : %d" % len(gana))
print("perdidas por quitarlo              : %d" % len(pierde))
print()
print("=== ejemplos de lo que se gana ===")
for a, b in gana[:35]: print("  %-52r ->  %r" % (a[:50], b[:50]))
if pierde:
    print()
    print("=== lo que se pierde (ojo) ===")
    for a, b in pierde[:10]: print("  %-52r ->  %r" % (a[:50], b[:50]))

# ruido: quitar puntuacion no debe hacer que se reconozca basura
ruido = [l.strip() for l in io.open(os.path.join(REPO, "pruebas", "ruido-real.txt"), encoding="utf-8")
         if l.strip() and not l.strip().startswith("#")]
rr = reconoce(ruido + [despunta(f) for f in ruido])
r_antes = sum(1 for f in ruido if rr.get(f))
r_desp = sum(1 for f in ruido if rr.get(despunta(f)) or rr.get(f))
print()
print("RUIDO (cuanto menos mejor): tal cual %d de %d  ->  sin puntuacion %d" % (r_antes, len(ruido), r_desp))
json.dump({"total": len(frases), "con_punt": len(con_punt), "ok_antes": ok_antes,
           "ok_despues": ok_despues, "gana": gana, "pierde": pierde,
           "ruido_antes": r_antes, "ruido_despues": r_desp},
          io.open(os.path.join(AQUI, "exp-puntuacion.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
