# -*- coding: utf-8 -*-
r"""Cuanto tarda la primera frase de la charla, en frio y tras la precarga.

A mano, cuando se toque charla_worker.py (el prompt, la precarga, las opciones de
Ollama). No va en probar-todo: carga el modelo local dos veces (~1,9 GB y ~40 s).

    python tools\probar-precarga.py

Arranca el worker de charla DE VERDAD con un cerebro temporal (no toca memoria\)
y sin clave de la API, descarga el modelo y mide:
  A) sin precarga: charla directa en frio
  B) con precarga: "calentar" y luego la charla
Medido el 14/09: A 13,1 s, B 2,6 s. Si B se acerca a A, la precarga ha dejado de
leer la parte fija del prompt (ver sistema_con en charla_worker.py).
"""
import json, os, queue, subprocess, sys, tempfile, threading, time, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
# POR DONDE ESTE EL BANCO, NO POR UNA RUTA ESCRITA A MANO (22/09): con la ruta completa
# a fuego, una copia del repo en otra carpeta seguiria midiendo los ficheros de SIEMPRE.
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H = {"Content-Type": "application/json"}


def descargar():
    urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:11434/api/generate", data=json.dumps(
        {"model": "qwen2.5:3b", "keep_alive": 0, "prompt": ""}).encode(), headers=H), timeout=60).read()
    time.sleep(3)


def arrancar():
    cerebro = tempfile.mkdtemp(prefix="cerebro-prueba-")
    env = dict(os.environ)
    env.pop("ANTHROPIC_API_KEY", None)      # solo el modelo local: la prueba mide eso
    p = subprocess.Popen([sys.executable, "-u", os.path.join(RAIZ, "charla_worker.py"), "qwen2.5:3b", "claude-haiku-4-5", "-",
                          cerebro, os.path.join(cerebro, "perfil.md")], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         cwd=RAIZ, env=env)
    q = queue.Queue()
    threading.Thread(target=lambda: [q.put(json.loads(l)) for l in p.stdout], daemon=True).start()
    return p, q


def esperar(q, cond, tope):
    t0 = time.time()
    while time.time() - t0 < tope:
        try:
            ev = q.get(timeout=0.5)
        except queue.Empty:
            continue
        if cond(ev):
            return ev
    return None


def mandar(p, d):
    p.stdin.write((json.dumps(d) + "\n").encode("utf-8"))
    p.stdin.flush()


for nombre, precargar in (("A sin precarga", False), ("B con precarga", True)):
    descargar()
    p, q = arrancar()
    esperar(q, lambda e: "charla lista" in str(e.get("texto", "")), 30)
    if precargar:
        t0 = time.time()
        mandar(p, {"op": "calentar"})
        ev = esperar(q, lambda e: "precarg" in str(e.get("texto", "")), 120)
        print("%s: precarga en %.1f s (%s)" % (nombre, time.time() - t0, ev and ev.get("texto")))
    t0 = time.time()
    mandar(p, {"op": "hablar", "texto": "estoy muy cansado hoy", "id": 7})
    ev = esperar(q, lambda e: e.get("ev") in ("frase", "err"), 90)
    print("%s: primera frase en %.1f s -> %s" % (nombre, time.time() - t0, ev))
    esperar(q, lambda e: e.get("ev") == "fin", 60)
    p.stdin.close()
    p.wait(timeout=30)
descargar()
