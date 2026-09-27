# -*- coding: utf-8 -*-
"""Dos de las cinco lineas de "temas de los que suele hablar" decian lo mismo (27/09, idea 94).

EL DATO, contado sobre memoria\\cerebro\\cerebro.json: en el prompt de cada charla viajan los cinco
temas mas contados, y eran videojuegos (63), comunicacion (26), clarificacion (10), steam (10) y
videojuego (10). Una de las cinco plazas gastada en repetir el primero en singular, y el tema que
se quedaba fuera era real: roblox (6). Los 30 temas estan ademas en su tope (MAX_TEMAS = 30), asi
que cada tema nuevo echa a otro y una plaza gastada cuesta el doble.

Y NO HABRA MUCHOS MAS: pasados los 30 por clave_tema salen 29 grupos. La UNICA pareja que se junta
en todo el cerebro es justo esa, y estaba en el prompt dos veces.

LO QUE ESTE BANCO PROTEGE:
  1. que las dos formas del caso REAL se junten, sumando las cuentas
  2. que el nombre que queda sea el de la forma mas contada
  3. que NO se junten temas distintos: ni por compartir una palabra, ni cambiando el orden
  4. que el repaso de lo ya guardado y la entrada nueva usen la MISMA regla
  5. que se diga cuantos junto, para que juntar de mas se vea el primer arranque

    python tools/probar-temas-juntos.py
"""
import ast
import io
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fuente = io.open(os.path.join(RAIZ, "charla_memoria.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det else ""))
    if not ok:
        fallos += 1


# LAS PIEZAS SUELTAS, SACADAS DEL ARCHIVO. charla_memoria.py se puede importar, pero arrastra
# numpy y el modelo de embeddings; aqui solo hacen falta raiz y clave_tema.
QUIERO = {"raiz", "clave_tema", "MAX_TEMAS"}
trozos, vistos = [], set()
for n in arbol.body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in QUIERO:
        trozos.append(ast.get_source_segment(fuente, n))
        vistos.add(nombre)
comp("se saca del archivo lo que se prueba", vistos == QUIERO, "" if vistos == QUIERO else "falta %s" % (QUIERO - vistos))
if vistos != QUIERO:
    sys.exit(1)
ns = {}
exec(chr(10).join(trozos), ns)
clave_tema = ns["clave_tema"]

# Y LOS DOS METODOS DE LA CLASE, sacados igual y pegados a un objeto de mentira: asi se ejecuta el
# codigo de verdad sin cargar el cerebro entero.
clase = [n for n in arbol.body if isinstance(n, ast.ClassDef) and any(
    isinstance(m, ast.FunctionDef) and m.name == "repasar_temas" for m in n.body)]
comp("y los dos metodos estan en la clase del cerebro", len(clase) == 1, "%d clase(s)" % len(clase))
metodos = {m.name: ast.get_source_segment(fuente, m) for m in clase[0].body
           if isinstance(m, ast.FunctionDef) and m.name in ("repasar_temas", "_tema")}
comp("  se encuentran repasar_temas y _tema", set(metodos) == {"repasar_temas", "_tema"}, str(sorted(metodos)))
if set(metodos) != {"repasar_temas", "_tema"}:
    sys.exit(1)

# el mundo de mentira: lo que _tema necesita de fuera
import re

ns2 = dict(ns)
ns2["re"] = re
ns2["plano"] = lambda t: t.lower().strip()
ns2["RE_SOBRE_NOVA"] = re.compile(r"\bnova\b")
cuerpo = "class Falso(object):" + chr(10)
cuerpo += "    def __init__(self):" + chr(10) + "        self.datos = {}" + chr(10)
for m in ("repasar_temas", "_tema"):
    for linea in metodos[m].split(chr(10)):
        cuerpo += "    " + linea + chr(10)
exec(cuerpo, ns2)
Falso = ns2["Falso"]

print("")
print("-- 1. LA CLAVE: MISMA RAIZ, MISMO TEMA --")
comp("1a. videojuegos y videojuego dan la misma", clave_tema("videojuegos") == clave_tema("videojuego"),
     "%s vs %s" % (clave_tema("videojuegos"), clave_tema("videojuego")))
comp("1b. steam y videojuegos NO", clave_tema("steam") != clave_tema("videojuegos"))
comp("1c. comunicacion y clarificacion tampoco", clave_tema("comunicacion") != clave_tema("clarificacion"))
# LA GUARDA QUE LA FICHA NO PEDIA: en orden, no en conjunto
comp("1d. y el ORDEN cuenta: 'juegos de mesa' no es 'mesa de juegos'",
     clave_tema("juegos de mesa") != clave_tema("mesa de juegos"), "la ficha pedia un frozenset, que si los junta")
comp("1e. ni se juntan por compartir UNA palabra", clave_tema("juegos de rol") != clave_tema("juegos de mesa"))

print("")
print("-- 2. EL CASO REAL, CON LOS NUMEROS DEL CEREBRO DE HOY --")
c = Falso()
c.datos["temas"] = {"videojuegos": 63, "comunicacion": 26, "clarificacion": 10, "steam": 10,
                    "videojuego": 10, "roblox": 6, "zombies": 5, "relacion": 5}
n = c.repasar_temas()
t = c.datos["temas"]
comp("2a. junta uno", n == 1, "%d juntado(s)" % n)
comp("2b. y queda el nombre mas contado", "videojuegos" in t and "videojuego" not in t, str(sorted(t)))
comp("2c. con las dos cuentas sumadas", t["videojuegos"] == 73, "%d, era 63 + 10" % t["videojuegos"])
comp("2d. y no toca ninguno de los demas",
     all(t[k] == v for k, v in (("comunicacion", 26), ("clarificacion", 10), ("steam", 10), ("roblox", 6))))
cinco = [k for k, _ in sorted(t.items(), key=lambda kv: -kv[1])[:5]]
comp("2e. LO QUE SE GANA: roblox entra en el prompt", "roblox" in cinco, str(cinco))
comp("2f. y ya no hay dos plazas diciendo lo mismo", len({clave_tema(k) for k in cinco}) == 5, str(cinco))

print("")
print("-- 3. Y LA MISMA REGLA PARA LO QUE LLEGA NUEVO --")
c2 = Falso()
c2.datos["temas"] = {"videojuegos": 63}
c2._tema("videojuego")
comp("3a. la forma nueva suma al grupo", c2.datos["temas"] == {"videojuegos": 64}, str(c2.datos["temas"]))
c2._tema("videojuegoS")
comp("3b. las mayusculas tampoco abren plaza", c2.datos["temas"] == {"videojuegos": 65}, str(c2.datos["temas"]))
c2._tema("roblox")
comp("3c. un tema de verdad SI abre la suya", c2.datos["temas"].get("roblox") == 1, str(c2.datos["temas"]))
c2._tema("mesa de juegos")
c2._tema("juegos de mesa")
comp("3d. y el orden distinto son dos temas", c2.datos["temas"].get("mesa de juegos") == 1 and
     c2.datos["temas"].get("juegos de mesa") == 1, str(sorted(c2.datos["temas"])))

print("")
print("-- 4. LO QUE NO PUEDE CAMBIAR --")
c3 = Falso()
c3._tema("nova")
comp("4a. un tema sobre Nova sigue sin entrar", c3.datos.get("temas", {}) == {}, str(c3.datos.get("temas")))
c3._tema("esto es una frase de mas de tres palabras")
comp("4b. ni una frase larga", c3.datos.get("temas", {}) == {}, str(c3.datos.get("temas")))
c3._tema("")
comp("4c. ni un tema vacio", c3.datos.get("temas", {}) == {})
# el tope sigue mordiendo
c4 = Falso()
for i in range(ns["MAX_TEMAS"] + 8):
    c4.datos.setdefault("temas", {})["tema%d" % i] = i + 1
c4._tema("uno mas")
comp("4d. el tope sigue en pie", len(c4.datos["temas"]) <= ns["MAX_TEMAS"],
     "%d de %d" % (len(c4.datos["temas"]), ns["MAX_TEMAS"]))

print("")
print("-- 5. SIN NADA QUE JUNTAR, NO TOCA NADA --")
c5 = Falso()
comp("5a. sin temas devuelve cero", c5.repasar_temas() == 0)
c5.datos["temas"] = {"steam": 3, "roblox": 2}
comp("5b. con temas distintos tambien", c5.repasar_temas() == 0)
comp("5c. y los deja como estaban", c5.datos["temas"] == {"steam": 3, "roblox": 2}, str(c5.datos["temas"]))

print("")
print("-- 6. EL CABLEADO --")
comp("6a. el repaso corre al cargar", "self.temas_juntados = self.repasar_temas()" in fuente)
comp("6b. y _tema usa la misma clave que el repaso", "clave_tema(t)" in metodos["_tema"] and
     "clave_tema(nombre)" in metodos["repasar_temas"], "una sola regla, en un sitio")
worker = io.open(os.path.join(RAIZ, "charla_worker.py"), encoding="utf-8").read()
comp("6c. y el worker dice cuantos junto", "temas_juntados" in worker and
     "juntados" in worker, "juntar de mas se ve el primer arranque")

print("")
print("-- 7. CONTRA EL CEREBRO DE VERDAD --")
cer = os.path.join(RAIZ, "memoria", "cerebro", "cerebro.json")
if not os.path.exists(cer):
    print("  --   no hay cerebro.json que mirar, se salta")
else:
    reales = (json.load(io.open(cer, encoding="utf-8-sig")).get("temas") or {})
    grupos = {}
    for k in reales:
        grupos.setdefault(clave_tema(k), []).append(k)
    juntan = [v for v in grupos.values() if len(v) > 1]
    comp("7a. en los temas de verdad solo se junta una pareja", len(juntan) == 1, str(juntan))
    comp("7b. y es la medida", len(juntan) == 1 and sorted(juntan[0]) == ["videojuego", "videojuegos"], str(juntan))
    comp("7c. o sea que no junta de mas", len(grupos) == len(reales) - 1,
         "%d grupos de %d temas" % (len(grupos), len(reales)))

print("")
if fallos:
    print("  %d MAL" % fallos)
    sys.exit(1)
print("  los temas que son el mismo no gastan dos plazas del prompt")
sys.exit(0)
