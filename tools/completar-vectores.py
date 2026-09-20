# COMPLETAR LOS VECTORES QUE FALTAN (19/09/2026). El cerebro se rellena solo:
# charla_worker.py llama a Cerebro.completar_vectores() desde el revisor, pero solo
# con el worker VIVO y 5 min sin charla (cargar embeddinggemma junto a Qwen hace
# paginar a Windows). Si la charla termina y Nova se cierra antes de ese respiro, los
# recuerdos de ese rato se quedan sin vector hasta la siguiente conversacion larga.
# Medido hoy: 53 recuerdos, 50 vectores; faltaban el 53 y el 54 (creados a las 22:08 y
# 23:37 del 18/09, con vectores.json parado a las 21:39). Esto los completa a mano, sin
# hablarle a Nova.
#
# El id 3 NO cuenta: esta "rechazada" y completar_vectores la salta a proposito (una
# respuesta que braya desmintio no debe volver a salir en ninguna busqueda).
#
# Cuesta una sola llamada a /api/embed: carga embeddinggemma:300m-qat-q8_0 (338 MB) y
# lo suelta al acabar (keep_alive 0). Segundos, y el fichero ya esta en la cache del
# disco.
#
#   python tools\completar-vectores.py              ver que falta y completarlo
#   python tools\completar-vectores.py --ver        solo mirar, no escribe nada
#   python tools\completar-vectores.py --rehacer    si cambio el modelo de embeddings
import json
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)
import charla_memoria as cm  # noqa: E402

if cm.np is None:
    # sin numpy el cerebro trabaja solo por palabras y NO carga ni escribe vectores:
    # sin este aviso la herramienta diria "0 vectores" y "completados 0" sin explicar nada
    print("no hay numpy en este Python: sin el no hay vectores. Instalalo y repite.")
    sys.exit(4)

CARPETA = os.path.join(RAIZ, "memoria", "cerebro")
OLLAMA = "http://127.0.0.1:11434"
POR_DEFECTO = "embeddinggemma:300m-qat-q8_0"   # el mismo que pone assistant.ps1
solo_ver = "--ver" in sys.argv
rehacer = "--rehacer" in sys.argv


class Embed:
    """Igual que EmbedOllama de charla_worker.py, pero sin importar el worker
    (importarlo levanta su cliente y sus hilos)."""

    def __init__(self, modelo):
        self.nombre = modelo

    def vectores(self, textos):
        import httpx
        r = httpx.post(OLLAMA + "/api/embed",
                       json={"model": self.nombre, "input": textos, "keep_alive": 0}, timeout=120)
        r.raise_for_status()
        return r.json()["embeddings"]


def worker_vivo():
    """NO ESCRIBIR A DOS MANOS: Cerebro.guardar() reescribe cerebro.json y
    vectores.json ENTEROS, asi que si el worker esta hablando con braya el ultimo
    que guarde se lleva por delante lo del otro."""
    ps = ("Get-CimInstance Win32_Process -Filter \"Name like 'python%'\" | "
          "ForEach-Object { \"$($_.ProcessId)|$($_.CommandLine)\" }")
    try:
        s = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                           capture_output=True, text=True, timeout=60).stdout
    except Exception:  # noqa: BLE001
        return None      # no se pudo mirar
    for linea in s.splitlines():
        pid, _, cmd = linea.partition("|")
        # el propio proceso queda fuera: si no, basta con que este nombre salga en
        # nuestra linea de comandos para dar un falso positivo
        if pid.strip().isdigit() and int(pid) != os.getpid() and "charla_worker.py" in cmd:
            return True
    return False


def modelo_configurado():
    try:
        with open(os.path.join(RAIZ, "config.json"), encoding="utf-8") as f:
            return (json.load(f).get("conversacion") or {}).get("modeloEmbeddings") or POR_DEFECTO
    except Exception:  # noqa: BLE001
        return POR_DEFECTO


def modelo_de_los_vectores():
    try:
        with open(os.path.join(CARPETA, "vectores.json"), encoding="utf-8") as f:
            return json.load(f).get("modelo") or ""
    except Exception:  # noqa: BLE001
        return ""


modelo = modelo_configurado()
viejo = modelo_de_los_vectores()
print("modelo de embeddings: %s" % modelo)
if viejo and viejo != modelo:
    print("OJO: los vectores de ahora son de '%s'. Al cargarlos con otro modelo se tiran" % viejo)
    print("     TODOS y hay que rehacerlos (no es lo de hoy). Con --rehacer si es lo que quieres.")
    if not rehacer:
        sys.exit(2)

cerebro = cm.Cerebro(CARPETA, Embed(modelo))
rec = cerebro.datos["recuerdos"]
sin_vec = [r for r in rec if r["id"] not in cerebro.vec]
saltados = [r["id"] for r in sin_vec if r.get("estado") == "rechazada"]
pendientes = [r["id"] for r in sin_vec if r.get("estado") != "rechazada"]
print("recuerdos: %d | vectores: %d | sin vector: %d" % (len(rec), len(cerebro.vec), len(sin_vec)))
print("  rechazados (no llevan vector, es lo correcto): %s" % (saltados or "ninguno"))
print("  a completar: %s" % (pendientes or "ninguno"))
if not pendientes:
    print("nada que hacer.")
    sys.exit(0)
if solo_ver:
    sys.exit(0)

vivo = worker_vivo()
if vivo:
    print("ABORTADO: charla_worker.py esta en marcha. Para Nova (tools\\parar-nova.ps1) y repite.")
    sys.exit(3)
if vivo is None:
    print("aviso: no pude comprobar si charla_worker.py esta en marcha; sigo.")

# de una sola pasada: cada llamada a completar_vectores guarda los dos ficheros y
# vuelve a cargar y soltar el modelo, y eso es lo caro
hechos = cerebro.completar_vectores(cuantos=max(64, len(pendientes)))
quedan = [r["id"] for r in cerebro.datos["recuerdos"]
          if r["id"] not in cerebro.vec and r.get("estado") != "rechazada"]
print("completados: %d | vectores ahora: %d | siguen sin vector: %s"
      % (hechos, len(cerebro.vec), quedan or "ninguno"))
sys.exit(0 if hechos and not quedan else 1)
