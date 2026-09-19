# -*- coding: utf-8 -*-
"""Mide latencia y acierto de cada motor con el prompt REAL de Nova."""
import ast, json, os, sys, time, urllib.request, urllib.error

REPO = r"C:\Users\braya\Documents\voice-ctrl"
AQUI = os.path.dirname(os.path.abspath(__file__))

# --- el prompt real, sacado de charla_worker.py sin ejecutarlo ---
src = open(os.path.join(REPO, "charla_worker.py"), encoding="utf-8").read()
arbol = ast.parse(src)
const = {}
for nodo in arbol.body:
    if isinstance(nodo, ast.Assign) and len(nodo.targets) == 1:
        t = nodo.targets[0]
        if isinstance(t, ast.Name) and t.id in ("SISTEMA", "SISTEMA_ORDEN", "SISTEMA_API"):
            try: const[t.id] = ast.literal_eval(nodo.value)
            except Exception: pass
SISTEMA = const["SISTEMA"] + const["SISTEMA_ORDEN"] + const["SISTEMA_API"]
print("prompt real cargado: %d caracteres" % len(SISTEMA))

banco = json.load(open(os.path.join(AQUI, "banco-medicion.json"), encoding="utf-8"))

def pide_ollama(modelo, frase, timeout=120):
    cuerpo = json.dumps({
        "model": modelo, "stream": False,
        "options": {"temperature": 0.3, "num_predict": 120},
        "messages": [{"role": "system", "content": SISTEMA},
                     {"role": "user", "content": frase}],
    }).encode("utf-8")
    req = urllib.request.Request("http://127.0.0.1:11434/api/chat", data=cuerpo,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))["message"]["content"].strip()

def pide_claude(modelo, frase, timeout=120):
    clave = os.environ.get("ANTHROPIC_API_KEY", "").strip()   # viene con salto de linea
    cuerpo = json.dumps({
        "model": modelo, "max_tokens": 400, "system": SISTEMA,
        "messages": [{"role": "user", "content": frase}],
    }).encode("utf-8")
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=cuerpo,
        headers={"Content-Type": "application/json", "x-api-key": clave,
                 "anthropic-version": "2023-06-01"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        d = json.loads(r.read().decode("utf-8"))
        return "".join(b.get("text", "") for b in d.get("content", [])).strip()

def clasifica(resp):
    r = (resp or "").strip().upper()
    if r.startswith("[ORDEN]"): return "ORDEN"
    if r.startswith("[API]"):   return "API"
    return "CHARLA"

MOTORES = [("qwen2.5:1.5b","ollama"), ("qwen2.5:3b","ollama"),
           ("llama3.2:1b","ollama"), ("llama3.2:3b","ollama"),
           ("claude-haiku-4-5","claude")]
solo = sys.argv[2] if len(sys.argv) > 2 else ""
if solo:
    MOTORES = [m for m in MOTORES if m[0] == solo]

def descarga(modelo):
    """Saca el modelo de la RAM: sin esto Ollama los acumula y el sistema mata la medicion."""
    try:
        cuerpo = json.dumps({"model": modelo, "keep_alive": 0,
                             "messages": [{"role": "user", "content": "x"}], "stream": False}).encode()
        req = urllib.request.Request("http://127.0.0.1:11434/api/chat", data=cuerpo,
                                     headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=60).read()
    except Exception:
        pass

etiqueta = sys.argv[1] if len(sys.argv) > 1 else "sin-juego"
res = {}
for modelo, via in MOTORES:
    pide = pide_ollama if via == "ollama" else pide_claude
    print("\n=== %s ===" % modelo, flush=True)
    # arranque en frio: primera llamada, con el modelo por cargar
    t0 = time.time()
    try:
        pide(modelo, "hola")
        frio = time.time() - t0
    except Exception as e:
        msg = str(e)
        k = os.environ.get("ANTHROPIC_API_KEY", "").strip()
        if k and k in msg: msg = msg.replace(k, "<clave oculta>")
        print("  FALLA en frio: %s" % msg[:160]); res[modelo] = {"error": msg[:160]}; continue
    print("  arranque en frio: %.2f s" % frio, flush=True)
    tiempos, aciertos, detalle = [], 0, []
    for c in banco:
        t0 = time.time()
        try:
            resp = pide(modelo, c["f"])
            dt = time.time() - t0
        except Exception as e:
            detalle.append({"f": c["f"], "error": str(e)}); continue
        got = clasifica(resp)
        ok = (got == c["e"])
        aciertos += 1 if ok else 0
        tiempos.append(dt)
        detalle.append({"f": c["f"], "esperado": c["e"], "dio": got, "ok": ok,
                        "s": round(dt, 2), "resp": resp[:110]})
        print("  %-5s %5.2fs  %-6s %s" % ("OK" if ok else "MAL", dt, got, c["f"][:52]), flush=True)
    tiempos.sort()
    res[modelo] = {"frio_s": round(frio, 2), "n": len(tiempos),
        "media_s": round(sum(tiempos)/len(tiempos), 2) if tiempos else None,
        "mediana_s": round(tiempos[len(tiempos)//2], 2) if tiempos else None,
        "max_s": round(tiempos[-1], 2) if tiempos else None,
        "aciertos": aciertos, "total": len(banco), "detalle": detalle}
    print("  --> %d/%d aciertos, mediana %.2fs" % (aciertos, len(banco), res[modelo]["mediana_s"] or 0), flush=True)
    if via == "ollama":
        descarga(modelo)
        print("  (descargado de la RAM)", flush=True)
    # guardar YA: si el sistema mata esto, no se pierde lo medido
    parcial = os.path.join(AQUI, "resultado-%s.json" % etiqueta)
    previo = {}
    if os.path.exists(parcial):
        try: previo = json.load(open(parcial, encoding="utf-8"))
        except Exception: previo = {}
    previo.update({modelo: res[modelo]})
    json.dump(previo, open(parcial, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

sal = os.path.join(AQUI, "resultado-%s.json" % etiqueta)
json.dump(res, open(sal, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("\nguardado en %s" % sal)
