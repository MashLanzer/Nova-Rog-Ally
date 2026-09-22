# -*- coding: utf-8 -*-
r"""C24 / VRAM-9 (VRAM-2026-09-19.md:151): ¿va Ollama mas rapido en la Radeon que en CPU?

Lo que dice el informe de VRAM, palabra por palabra: "Si Ollama con OLLAMA_IGPU_ENABLE=1
(Vulkan sobre la Radeon) iria mas rapido que en CPU: nadie lo ha probado; con 4 GB de VRAM
probablemente no compensa". Lleva de pendiente desde el 19/09 y es lo unico que puede
cerrarlo con datos.

QUE HACE. Manda las MISMAS peticiones a qwen2.5:3b -el modelo de la charla, config.json
conversacion.modeloLocal- dos veces: con Ollama como esta ahora y con Ollama relanzado con
OLLAMA_IGPU_ENABLE=1. Mide segundos hasta la primera palabra y tokens por segundo, que son
los dos numeros que se notan hablando.

LAS PETICIONES SON LAS SUYAS, no inventadas: salen de las frases de charla del propio
assistant.log. Si no hay, se usan unas de repuesto parecidas.

NO lo lances con Nova encendida: el worker de charla usa el mismo Ollama y los numeros
saldrian mezclados. Para Nova antes con tools\parar-nova.ps1.

DEJA OLLAMA COMO ESTABA. Al terminar -o si algo falla, o si lo paras a medias- se relanza
con las variables de entorno originales. Eso es lo unico que toca del sistema.

Uso:
    python tools\medir-ollama-igpu.py
"""
import io
import json
import os
import re
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLLAMA_URL = "http://127.0.0.1:11434"
EXE = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Ollama", "ollama.exe")
SALIDA = os.path.join(REPO, "pruebas", "ollama-igpu.json")

try:
    import urllib.request
except ImportError:
    print("falta urllib"); sys.exit(1)


def modelo_local():
    try:
        cfg = json.load(io.open(os.path.join(REPO, "config.json"), encoding="utf-8-sig"))
        return cfg.get("conversacion", {}).get("modeloLocal", "qwen2.5:3b")
    except Exception:
        return "qwen2.5:3b"


def frases_suyas(n=6):
    """Las peticiones salen de lo que braya le dice de verdad, no de un corpus inventado."""
    fuera = []
    try:
        log = io.open(os.path.join(REPO, "assistant.log"), encoding="utf-8", errors="replace")
        for l in log:
            m = re.search(r"SUBMIT \(charla\): (.+)$", l) or re.search(r"charla: contesto.*", l)
            if m and m.lastindex:
                t = m.group(1).strip()
                if 12 < len(t) < 120 and t not in fuera:
                    fuera.append(t)
    except Exception:
        pass
    if len(fuera) < n:
        fuera += [
            "que juegos tengo instalados en steam",
            "cuanto le queda a la bateria",
            "explicame en dos frases que es el ray tracing",
            "que tiempo va a hacer manana",
            "dime una idea para cenar rapido",
            "cuanto ocupa elden ring",
        ]
    return fuera[:n]


# 60 s y no 25 (22/09): el primer intento dijo 'no arranca Ollama' y el de despues -el del
# finally, con el puerto ya libre del todo- si arranco. No era que no arrancara: era que se
# le preguntaba demasiado pronto.
def ollama_vivo(espera=60.0):
    t0 = time.time()
    while time.time() - t0 < espera:
        try:
            urllib.request.urlopen(OLLAMA_URL + "/api/tags", timeout=2).read()
            return True
        except Exception:
            time.sleep(0.5)
    return False


def parar_ollama():
    # LLAMA-SERVER TAMBIEN, o se quedan sueltos (22/09). Ollama lanza un llama-server por
    # modelo cargado, y matar solo ollama.exe deja al hijo vivo con el modelo entero dentro.
    # Paso aqui: dos huerfanos de 1.675 y 551 MB en una consola de 11,9 GB, que dejaron el
    # sistema en 376 MB libres y empezaron a matar procesos.
    for nombre in ("ollama app.exe", "ollama.exe", "llama-server.exe"):
        subprocess.run(["taskkill", "/F", "/IM", nombre], capture_output=True)
    # 5 s: Windows tarda en soltar el puerto 11434 despues de matar al que lo tenia,
    # y si se relanza antes, el nuevo no puede escuchar y parece que no arranca.
    time.sleep(5.0)


def arrancar_ollama(extra=None):
    ent = dict(os.environ)
    if extra:
        ent.update(extra)
    if not os.path.exists(EXE):
        print("  no encuentro ollama.exe en %s" % EXE)
        return False
    subprocess.Popen([EXE, "serve"], env=ent,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    return ollama_vivo()


def una(modelo, prompt):
    """Una peticion en streaming: segundos hasta la primera palabra y tokens/s."""
    cuerpo = json.dumps({
        "model": modelo, "prompt": prompt, "stream": True,
        "options": {"num_predict": 80, "temperature": 0.2},
    }).encode("utf-8")
    req = urllib.request.Request(OLLAMA_URL + "/api/generate", data=cuerpo,
                                 headers={"Content-Type": "application/json"})
    t0 = time.time()
    primera = None
    trozos = 0
    fin = {}
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            for linea in r:
                if not linea.strip():
                    continue
                try:
                    d = json.loads(linea.decode("utf-8"))
                except Exception:
                    continue
                if d.get("response"):
                    trozos += 1
                    if primera is None:
                        primera = time.time() - t0
                if d.get("done"):
                    fin = d
    except Exception as e:
        return None, None, str(e)[:60]
    total = time.time() - t0
    n_eval = fin.get("eval_count") or trozos
    dur = (fin.get("eval_duration") or 0) / 1e9
    tps = (n_eval / dur) if dur > 0 else (n_eval / total if total else 0)
    return (primera if primera is not None else total), tps, ""


def donde_corre(modelo):
    """Lo que dice el propio Ollama de donde metio el modelo."""
    try:
        cuerpo = json.dumps({"model": modelo}).encode("utf-8")
        req = urllib.request.Request(OLLAMA_URL + "/api/show", data=cuerpo,
                                     headers={"Content-Type": "application/json"})
        json.loads(urllib.request.urlopen(req, timeout=20).read().decode("utf-8"))
    except Exception:
        pass
    try:
        d = json.loads(urllib.request.urlopen(OLLAMA_URL + "/api/ps", timeout=10).read().decode("utf-8"))
        for m in d.get("models", []):
            tot = m.get("size") or 0
            vram = m.get("size_vram") or 0
            if tot:
                return "%.0f %% en la GPU (%.0f MB de %.0f)" % (100.0*vram/tot, vram/1e6, tot/1e6)
    except Exception:
        pass
    return "no lo dice"


def tanda(etiqueta, modelo, prompts):
    print("")
    print("  -- %s --" % etiqueta)
    # una de calentamiento, que no cuenta: carga el modelo
    una(modelo, "hola")
    print("     donde esta el modelo: %s" % donde_corre(modelo))
    prim, tps = [], []
    for i, p in enumerate(prompts, 1):
        a, b, err = una(modelo, p)
        if err:
            print("     %d/%d  FALLO: %s" % (i, len(prompts), err))
            continue
        prim.append(a); tps.append(b)
        print("     %d/%d  primera palabra %5.2f s   %5.1f tokens/s   %s" % (i, len(prompts), a, b, p[:40]))
    if not prim:
        return None
    prim.sort(); tps.sort()
    med = lambda v: v[len(v)//2]
    print("     MEDIANA: primera palabra %.2f s, %.1f tokens/s" % (med(prim), med(tps)))
    return {"primera": med(prim), "tps": med(tps), "n": len(prim)}


def main():
    modelo = modelo_local()
    prompts = frases_suyas()
    print("")
    print("  C24 / VRAM-9: ¿va Ollama mas rapido en la Radeon que en CPU?")
    print("  modelo: %s      peticiones: %d (de su propio log)" % (modelo, len(prompts)))

    # de que variables se parte, para poder dejarlo igual
    originales = {k: v for k, v in os.environ.items() if k.startswith("OLLAMA")}
    print("  variables de ahora: %s" % (", ".join("%s=%s" % kv for kv in sorted(originales.items())) or "ninguna"))

    res = {}
    try:
        parar_ollama()
        if not arrancar_ollama():
            print("  no arranca Ollama; lo dejo estar"); return 1
        res["cpu"] = tanda("COMO ESTA HOY (CPU)", modelo, prompts)

        parar_ollama()
        if not arrancar_ollama({"OLLAMA_IGPU_ENABLE": "1"}):
            print("  no arranca con OLLAMA_IGPU_ENABLE=1; lo dejo estar"); return 1
        res["igpu"] = tanda("CON OLLAMA_IGPU_ENABLE=1 (Vulkan sobre la Radeon)", modelo, prompts)
    finally:
        # SIEMPRE se deja como estaba, pase lo que pase
        print("")
        print("  dejando Ollama como estaba...")
        parar_ollama()
        arrancar_ollama()

    print("")
    print("  === EL VEREDICTO ===")
    c, g = res.get("cpu"), res.get("igpu")
    if not c or not g:
        print("  faltan datos de una de las dos tandas"); return 1
    # en los dos, POSITIVO = la GPU gana. La primera palabra es "cuanto menos tarda" y
    # los tokens "cuantos mas saca", asi que las restas van al reves a proposito.
    dp = 100.0 * (c["primera"] - g["primera"]) / c["primera"]
    dt = 100.0 * (g["tps"] - c["tps"]) / c["tps"]
    print("     primera palabra: %.2f s -> %.2f s   (%+.0f %% mas rapida)"
          % (c["primera"], g["primera"], dp))
    print("     tokens/s:        %.1f   -> %.1f     (%+.0f %%)"
          % (c["tps"], g["tps"], dt))
    print("")
    if dt > 15 and dp > 10:
        print("     LA GPU GANA CLARO: merece la pena ponerlo fijo.")
    elif dt < -10 or dp < -10:
        print("     LA GPU PIERDE: se queda como esta. Con 4 GB de VRAM era lo esperable.")
    else:
        print("     EMPATE (menos del 15 %%): no compensa tocar nada. Un cambio que no se nota")
        print("     no se hace, y este ademas mete una variable mas que mantener.")
    try:
        io.open(SALIDA, "w", encoding="utf-8").write(json.dumps(res, indent=2))
        print("")
        print("     numeros guardados en %s" % os.path.relpath(SALIDA, REPO))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
