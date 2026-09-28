# -*- coding: utf-8 -*-
"""BUSCAR EN LO QUE BRAYA LE HA CONTADO (23/09, funcion 4).

Hasta hoy "¿que te dije del juego que era caro?" se iba a opencode -el agente con acceso
total al sistema- tardando de 25 a 60 segundos, con la respuesta esperando en la memoria de
Nova. Y el otro lado: el 18/09 a las 19:07, en 24 segundos, dos peticiones de borrado se
fueron enteras a opencode mientras la charla contestaba "no tengo ningun dato sobre un oso
polar"... un dato que ella misma se habia inventado y guardado.

LO QUE SE PRUEBA AQUI ES EL LISTON, porque es lo unico que puede hacerle daño: si esta bajo,
Nova contesta cualquier cosa parecida y eso es inventar; si esta alto, dice que no se acuerda
de cosas que si sabe. Se mide contra SU memoria de verdad, no contra ejemplos.
"""
import io
import json
import os
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)

# La consola de Nova no siempre es UTF-8, y aqui se imprimen recuerdos SUYOS tal cual (llevan
# acentos: "8 dolares", "musica electronica"). Con la cp1252 de PowerShell un solo caracter
# raro tiraba el banco por UnicodeEncodeError a mitad de la tabla, y eso se cuenta rojo sin
# que falle nada de lo que se vigila.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:      # noqa: BLE001
    pass


# ESTE BANCO SE CORRE CON EL PYTHON DE NOVA, NO CON EL PRIMERO DEL PATH (27/09)
#
# Aqui el liston se mide contra la memoria DE VERDAD, y para eso hace falta el embebedor:
# "from charla_worker import EmbedOllama" (mas abajo). charla_worker.py importa httpx arriba
# del fichero -su cliente unico de la API, 18/09-, y el python con el que Nova lanza sus
# workers (paths.python de config.json y, si no esta puesto,
# %LOCALAPPDATA%\Programs\Python\Python312\python.exe) SI lo tiene. Pero
# tools\probar-todo.ps1 lanza este banco con "python" a secas, y en esta maquina eso resuelve
# a C:\Program Files\Python311\python.exe, que NO lo tiene.
# Medido antes de arreglarlo: el try de mas abajo cazaba ese ModuleNotFoundError y el banco
# imprimia "MAL  no puedo abrir su memoria: No module named 'httpx'" y salia con 1 sin haber
# medido NADA -ni un acierto, ni un falso, ni el hueco-, asi que la seccion 2n100 se contaba
# roja con el codigo bien. El interprete era el equivocado, no el liston.
#
# Se hace igual que en tools\probar-charla.py: si al interprete que nos toco le falta una
# dependencia del worker, nos volvemos a lanzar UNA vez con el de Nova (la marca
# NOVA_BANCO_RELANZADO corta la recursion) y se devuelve su codigo tal cual. Si el de Nova
# tampoco esta, o tampoco la tiene, se DICE y se sale con 1: aqui no se salta ni una
# comprobacion en silencio. Y va ANTES del primer print, para no imprimir la tabla dos veces.
def _python_de_nova():
    ruta = ""
    try:
        with io.open(os.path.join(RAIZ, "config.json"), encoding="utf-8-sig") as f:
            ruta = str(((json.load(f) or {}).get("paths") or {}).get("python") or "")
    except Exception:      # noqa: BLE001
        ruta = ""
    if not ruta:
        ruta = os.path.join(os.environ.get("LOCALAPPDATA") or "",
                            "Programs", "Python", "Python312", "python.exe")
    return os.path.expandvars(ruta)


try:
    import charla_worker      # noqa: F401  (solo para ver si ESTE python puede cargarlo)
except ModuleNotFoundError as _e:
    _falta = getattr(_e, "name", None) or "una dependencia"
    if os.environ.get("NOVA_BANCO_RELANZADO"):
        print("  MAL  al python de Nova tambien le falta %s: pip install %s" % (_falta, _falta))
        sys.exit(1)
    _py = _python_de_nova()
    if not os.path.isfile(_py):
        print("  MAL  falta %s y no encuentro el python de Nova en %s" % (_falta, _py))
        sys.exit(1)
    _ent = dict(os.environ)
    _ent["NOVA_BANCO_RELANZADO"] = "1"
    sys.exit(subprocess.call([_py, os.path.abspath(__file__)] + sys.argv[1:], env=_ent))

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-52s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


fuente = io.open(os.path.join(RAIZ, "charla_worker.py"), encoding="utf-8").read()

print("")
print("-- el liston sale del fichero, no de aqui --")
import re
m = re.search(r"(?m)^LISTON_RECUERDO = ([0-9.]+)", fuente)
liston = float(m.group(1)) if m else None
comp("existe LISTON_RECUERDO", liston is not None, str(liston))
comp("y las dos comparaciones lo usan",
     len(re.findall(r"LISTON_RECUERDO", fuente)) >= 3, "%d usos" % len(re.findall(r"LISTON_RECUERDO", fuente)))

# --- contra su memoria de verdad -------------------------------------------
try:
    import charla_memoria as cm
    from charla_worker import EmbedOllama
    cerebro = cm.Cerebro(os.path.join(RAIZ, "memoria", "cerebro"),
                         EmbedOllama("embeddinggemma:300m-qat-q8_0"))
except Exception as e:      # noqa: BLE001
    print("  MAL  no puedo abrir su memoria: %s" % e)
    sys.exit(1)

print("")
print("-- su memoria de verdad: %d recuerdos, %d vectores --" % (
    len(cerebro.datos.get("recuerdos", [])), len(cerebro.vec)))


def mejor(q):
    qv = cerebro.vector(q)
    h = cerebro.buscar(q, k=1, qvec=qv) if qv is not None else cerebro.buscar(q, k=1)
    if not h:
        return 0.0, ""
    r = h[0]["r"]
    return h[0]["comb"], (r.get("respuesta") or r.get("texto") or "")[:44]


# temas que SI estan en su memoria (sacados de sus recuerdos reales)
# EL OSO POLAR SE CAYO DE ESTA LISTA, Y CON RAZON (26/09, idea 31). El UNICO recuerdo que
# hablaba de un oso polar era el id 39: "Braya quiere eliminar un dato sobre un oso polar de su
# perfil, pero Nova no encontro ese dato". Eso no es algo que braya contara: es Nova contando lo
# que le paso a ELLA, y desde el 19/09 eso no entra en el cerebro. El repaso de lo ya guardado
# lo aparto, y sin el este banco se quedaba VERDE devolviendo una barbaridad a 0,279 -"?Como se
# llama que? Completa que no me quedo"-, que es peor que ponerse rojo.
# Se cambia por la funda de la consola (recuerdos 32 y 33), que SI es algo que conto braya.
con = ["que te dije del juego que era caro", "de que hablamos del fuego en la casa",
       "que me dijiste de mi pareja", "que te dije de la funda de la consola",
       "que dije de la musica electronica"]
# y temas que NO ha hablado nunca
sin = ["que te dije de la pesca en noruega", "que sabes de mi coche electrico",
       "de que hablamos de la bolsa de nueva york", "que dije del telescopio espacial"]

print("")
print("   los que SI estan:")
peor_si = 1.0
for q in con:
    p, t = mejor(q)
    peor_si = min(peor_si, p)
    print("     %.3f  %-38s %s" % (p, q[:38], t))
print("   los que NO:")
mejor_no = 0.0
for q in sin:
    p, t = mejor(q)
    mejor_no = max(mejor_no, p)
    print("     %.3f  %-38s %s" % (p, q[:38], t))

print("")
comp("los que SI estan pasan el liston", liston is not None and peor_si >= liston,
     "el peor acierto: %.3f" % peor_si)
comp("y los que NO, no lo pasan", liston is not None and mejor_no < liston,
     "el mejor falso: %.3f" % mejor_no)
comp("y queda hueco entre los dos", peor_si - mejor_no > 0.03,
     "%.3f de separacion" % (peor_si - mejor_no))
comp("el liston esta dentro del hueco", liston is not None and mejor_no < liston < peor_si,
     "%.3f < %.2f < %.3f" % (mejor_no, liston or 0, peor_si))

print("")
print("-- y lo barato primero --")
comp("primero busca sin vector", bool(re.search(r"hits = cerebro\.buscar\(texto_r, k=3\)\n", fuente)),
     "instantaneo; el vector cuesta ~3,7 s en frio")
comp("y solo embebe si no llega", bool(re.search(r"if not mejor or mejor\[.comb.\] < LISTON_RECUERDO:", fuente)))
comp("no revienta si no hay modelo", "if qv is not None:" in fuente)
comp("ni si falla la memoria", 'salida("recuerdo", idr, texto="", nada=True, error=' in fuente)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  se acuerda de lo que le contaste, y dice que no cuando no lo sabe")
sys.exit(0)
