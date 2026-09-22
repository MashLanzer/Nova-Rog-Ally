# -*- coding: utf-8 -*-
# LOS PLAZOS DE SOLTAR MODELOS MIRAN LA RAM QUE QUEDA (22/09).
#
# braya: "todo deberia ser ajustable por ella, nova tiene que adaptarse a la situacion y
# cambiar sola". Los cuatro plazos del oido -20 min el oido fino, 5 min con juego delante,
# 2 min el ultimo recurso- estaban escritos a mano y no miraban nada. Con memoria de sobra eso
# es lo rapido y esta bien; con la memoria justa es lo contrario.
#
# LO QUE LO MOTIVA, medido el 22/09 en la consola con Nova en marcha: el worker del oido
# llevaba 1.668 MB con los cuatro modelos dentro y quedaban 1.767 MB libres de 11.979. Y esa
# madrugada el asistente se murio a mitad de un dictado sin dejar ni un error en el Visor de
# eventos de Windows -la pinta exacta de quedarse sin memoria-, y en todo el log no habia ni
# una linea que dijera cuanta RAM quedaba.
#
# Aqui se ejecuta plazo_soltar de verdad (no se mira el fuente y ya), porque lo que puede
# salir mal son los numeros: que se vuelva lento sin necesidad, o que no suelte cuando toca.
#
#   python tools/probar-plazos-soltar.py
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# NO se importa wake_vosk: importarlo arranca el microfono. Se extrae con regex.
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- la funcion de verdad, con un ram_libre_mb de mentira que se puede mover -------------
ns = {}
for cte in ("RAM_COMODA", "RAM_APRETADA", "SOLTAR_MIN_FACTOR",
            "PRECISO_SOLTAR_QUIETO", "PRECISO_SOLTAR_JUGANDO", "PARAKEET_SOLTAR_JUGANDO",
            "ULTIMO_SOLTAR", "RAM_MIN_PRECISO"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s" % cte)
        sys.exit(1)
    ns[cte] = float(m.group(1))

_ram = [-1.0]
ns["ram_libre_mb"] = lambda: _ram[0]
m = re.search(r"(?ms)^def plazo_soltar\(.*?\n(?=\n*\S|\Z)", SRC)
if not m:
    print("  MAL  no encuentro plazo_soltar en wake_vosk.py")
    sys.exit(1)
exec(compile(m.group(0), "plazo_soltar", "exec"), ns)
plazo_soltar = ns["plazo_soltar"]
QUIETO = ns["PRECISO_SOLTAR_QUIETO"]


def con(mb):
    _ram[0] = float(mb)
    return plazo_soltar(QUIETO)


print("")
print("-- con memoria de sobra, el plazo de siempre: manda la rapidez --")
comp("con 8 GB libres, el plazo entero", con(8000) == QUIETO, "%.0f s" % con(8000))
comp("justo en RAM_COMODA, tambien entero", con(ns["RAM_COMODA"]) == QUIETO, "%.0f s" % con(ns["RAM_COMODA"]))
comp("un pelin por encima, entero", con(ns["RAM_COMODA"] + 1) == QUIETO)

print("")
print("-- y si no se puede medir, tampoco se toca nada --")
# ram_libre_mb devuelve -1 cuando falla. Ahi lo prudente es NO cambiar: suponer lo peor
# dejaria a Nova lenta por si acaso, que es lo que braya no quiere.
comp("con -1 (no se sabe), el plazo de siempre", con(-1) == QUIETO, "%.0f s" % con(-1))

print("")
print("-- con la memoria justa, suelta pronto: manda no morirse --")
comp("con 500 MB, la decima parte", abs(con(500) - QUIETO * ns["SOLTAR_MIN_FACTOR"]) < 0.01,
     "%.0f s en vez de %.0f" % (con(500), QUIETO))
comp("justo en RAM_APRETADA, la decima parte",
     abs(con(ns["RAM_APRETADA"]) - QUIETO * ns["SOLTAR_MIN_FACTOR"]) < 0.01, "%.0f s" % con(ns["RAM_APRETADA"]))
comp("con 0 MB no se vuelve negativo ni cero", 0 < con(0) <= QUIETO, "%.0f s" % con(0))

print("")
print("-- en medio, proporcional y sin saltos --")
antes = None
subidas = True
for mb in range(0, 3600, 100):
    v = con(mb)
    if antes is not None and v < antes - 0.001:
        subidas = False
    antes = v
comp("mas memoria libre nunca da un plazo mas corto", subidas)
medio = (ns["RAM_COMODA"] + ns["RAM_APRETADA"]) / 2.0
comp("a media tabla, mas o menos la mitad del plazo",
     QUIETO * 0.4 < con(medio) < QUIETO * 0.75, "%.0f s con %.0f MB" % (con(medio), medio))
comp("nunca pasa del plazo escrito", max(con(mb) for mb in range(0, 12000, 250)) <= QUIETO)

print("")
print("-- EL CASO REAL DEL 22/09: 1.767 MB libres --")
# lo que habia en la consola de braya con Nova en marcha y los cuatro modelos dentro
real = con(1767)
comp("el oido fino se suelta antes de los 20 min", real < QUIETO, "%.0f s (%.1f min)" % (real, real / 60.0))
comp("pero no tan pronto como para ir recargando", real > 120,
     "%.0f s; recargarlo cuesta 2,5-5 s" % real)

print("")
print("-- los cuatro plazos pasan por aqui, o esto no sirve de nada --")
# Lo que se puede estropear sin querer: anadir un uso nuevo del plazo y olvidarse de
# envolverlo. Se comprueba sobre el fuente que no queda ninguno suelto.
for cte in ("PRECISO_SOLTAR_QUIETO", "PRECISO_SOLTAR_JUGANDO", "PARAKEET_SOLTAR_JUGANDO", "ULTIMO_SOLTAR"):
    # los usos de verdad son los que estan en una linea de codigo (no comentario ni la
    # definicion); todos tienen que estar dentro de un plazo_soltar(...)
    sueltos = []
    for linea in SRC.split("\n"):
        t = linea.strip()
        if not t or t.startswith("#") or t.startswith(cte + " ="):
            continue
        if cte in t and "plazo_soltar(" not in t:
            sueltos.append(t[:60])
    comp("%s siempre pasa por plazo_soltar" % cte, not sueltos, "; ".join(sueltos))

print("")
print("-- y la RAM queda escrita en el log, que anoche no se pudo saber --")
comp("el pulso dice cuanta RAM queda", "ram_libre=" in SRC)
comp("y el plazo que se esta aplicando", "plazo=x" in SRC)
comp("con '?' si no se puede medir, no un cero que engane",
     re.search(r'ram_libre_mb\(\).{0,400}"\?"', SRC, re.S) is not None)

print("")
print("-- los limites son razonables para esta consola (11,7 GB) --")
comp("RAM_APRETADA deja sitio a la guarda del oido fino",
     ns["RAM_APRETADA"] >= ns["RAM_MIN_PRECISO"] * 0.8,
     "apretada %.0f, el oido fino pide %.0f" % (ns["RAM_APRETADA"], ns["RAM_MIN_PRECISO"]))
comp("RAM_COMODA esta por encima de RAM_APRETADA", ns["RAM_COMODA"] > ns["RAM_APRETADA"])
comp("y por debajo de lo que pide un juego (4 GB)", ns["RAM_COMODA"] < 4000)

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  los plazos se adaptan a la memoria que queda")
sys.exit(0)
