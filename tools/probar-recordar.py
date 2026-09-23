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
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)

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
con = ["que te dije del juego que era caro", "de que hablamos del fuego en la casa",
       "que me dijiste de mi pareja", "que sabes del oso polar",
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
