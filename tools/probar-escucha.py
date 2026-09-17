# -*- coding: utf-8 -*-
"""Reglas de la escucha que se pueden probar SIN microfono.

wake_vosk.py abre el microfono y los modelos al importarlo, asi que no se puede
importar: se sacan del archivo real (con ast) solo las constantes y funciones
puras que se prueban, igual que TraerFn hace con assistant.ps1.

    python tools/probar-escucha.py
"""
import ast
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fuente = open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)
QUIERO = {"SILENCIO_FIN", "SILENCIO_FIN_LOTENGO", "silencio_para_cerrar", "MARGEN_CORTE_HZ", "es_voz_de_braya", "PROMPT_ORDENES", "es_eco_del_ejemplo", "PICO_OBJETIVO", "GANANCIA_MIN", "GANANCIA_MAX", "GANANCIA_INICIAL"}
trozos = []
for n in arbol.body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in QUIERO:
        trozos.append(ast.get_source_segment(fuente, n))
ns = {}
exec("import re" + chr(10) + "import unicodedata" + chr(10) + chr(10).join(trozos), ns)

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det and not ok else ""))
    if not ok:
        fallos += 1


cerrar = ns["silencio_para_cerrar"]
comp("la orden ya entendida se cierra antes", cerrar("abre steam", "abre steam ") == ns["SILENCIO_FIN_LOTENGO"])
comp("los espacios no cuentan", cerrar("pon  el volumen al 70", " pon el volumen al 70") == ns["SILENCIO_FIN_LOTENGO"])
comp("si sigues hablando, se espera lo de siempre", cerrar("abre steam", "abre steam y pon") == ns["SILENCIO_FIN"])
comp("sin nada entendido, lo de siempre", cerrar("", "abre steam") == ns["SILENCIO_FIN"])
comp("sin nada dicho, lo de siempre", cerrar("abre steam", "") == ns["SILENCIO_FIN"])
comp("lo corto es mas corto que lo de siempre", ns["SILENCIO_FIN_LOTENGO"] < ns["SILENCIO_FIN"])
# en las 100 grabaciones la pausa mas larga DENTRO de una orden fue de 0,81 s, y con
# pausas a proposito de 1,44 s (14/09)
comp("y no corta una pausa normal dentro de la orden", ns["SILENCIO_FIN_LOTENGO"] > 0.81)
comp("ni una pausa larga en una frase que aun no se entiende", ns["SILENCIO_FIN"] > 1.44)

# INTERRUMPIR: tonos medidos el 14/09 (braya 103-149 Hz en las 100, tono aprendido 119,6; Nova 165-327)
voz = ns["es_voz_de_braya"]
comp("braya interrumpe (todas sus grabaciones, gritando tambien)", all(voz(f, 119.6) for f in (103, 110, 126, 139, 140, 149)))
comp("la voz de Nova NO se interrumpe a si misma", not any(voz(f, 119.6) for f in (165, 190, 205, 267, 327)))
comp("sin tono medible (y el tuyo ya aprendido), el corte NO vale", not voz(0, 119.6))
comp("sin tono aprendido todavia, el corte vale", voz(205, 0))

# ECO DE LA FRASE DE EJEMPLO: lo que salio en las 100 grabaciones (14/09)
eco = ns["es_eco_del_ejemplo"]
comp("'Baja el brillo' (dijo 'baja el volumen') es eco del ejemplo", eco("Baja el brillo"))
comp("'¿Que hora es? ¿Que hora es' tambien", eco("¿Qué hora es? ¿Qué hora es") and eco("Pon el modo noche"))
comp("con el nombre delante tambien", eco("Nova, abre Steam") and eco("oye nova, sube el volumen"))
comp("una orden que NO esta en el ejemplo no lo es", not eco("Sube el volumen al 50") and not eco("Pausa") and not eco("Baja el volumen"))
# y la frase de ejemplo no lleva numeros: "al treinta" convertia "al ochenta" en treinta
import re as _re
comp("la frase de ejemplo no lleva numeros", not _re.search(r"[0-9]|\b(?:treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa|cien|veinte|diez)\b", ns["PROMPT_ORDENES"].lower()))
comp("nada dicho no es eco", not eco("") and not eco("Nova"))

# LA CALIBRACION GUARDADA NO SE TIRA (16/09). Habia una regla que descartaba cualquier
# ganancia guardada por debajo de x1.5 y arrancaba en x8. Como la ganancia buena de braya
# es 0.7, se cumplia SIEMPRE: se tiro 38 veces, dos el mismo 16/09. Arrancando a x8 el
# ruido de fondo bastaba para activar a Nova sola (6 de las 13 activaciones de ese dia
# con pico 0.000) y su voz de verdad saturaba, asi que no le oia. Sus dos quejas -"se
# activa sola" y "cuando le digo nova no se activa nunca"- eran el MISMO fallo.
comp("no se descarta la calibracion guardada por ser baja", "descartada (demasiado baja" not in fuente)
comp("ni queda una regla que la compare con un minimo", not _re.search(r"if\s+_g\s*<", fuente))
# el porque, con sus numeros: su voz entra a p90 0.47-0.99, asi que la ganancia que el
# pulso calcula (PICO_OBJETIVO / pico crudo) le sale BAJA. Cualquier suelo por encima
# volveria a tirarsela.
_suya = [round(ns["PICO_OBJETIVO"] / p, 2) for p in (0.47, 0.75, 0.99)]
comp("la ganancia correcta de braya es menor que x1", all(g < 1.0 for g in _suya), str(_suya))
comp("o sea que la regla vieja se la habria tirado siempre", all(g < 1.5 for g in _suya), str(_suya))
comp("y el sistema puede atenuar por debajo de x1", ns["GANANCIA_MIN"] < 1.0)

# LA GANANCIA TIENE QUE PODER BAJAR (17/09). Se quedaba clavada en x0.7 por el REDONDEO:
# con objetivo 0.58, propuesta = 0.7 + (0.58-0.7)*0.2 = 0.676 y round(...,1) devolvia 0.7
# otra vez. Ocho ciclos sin moverse. Y mientras, el 27 % de los pulsos de braya llegaban
# saturados (p90 crudo >= 0.98 en 109 de 400) pidiendo atenuar. Dos fallos que se tapaban.
comp("el suelo deja atenuar lo que pide su microfono (0.35)", ns["GANANCIA_MIN"] <= 0.35)
comp("no se arranca en x8, que fue lo que la activaba sola", ns["GANANCIA_INICIAL"] <= 2.0)
comp("queda la correccion del redondeo al bajar", "if nueva < ganancia:" in fuente)

# la formula es COPIA de la del pulso (esta dentro del bucle, no se puede sacar con ast):
# si alli cambia, hay que cambiarla aqui. Lo que se comprueba es que BAJE, que es lo que
# no hacia.
def _ciclo(g, p90):
    nueva = max(ns["GANANCIA_MIN"], min(ns["GANANCIA_MAX"], ns["PICO_OBJETIVO"] / p90))
    prop = g + (nueva - g) * (0.6 if nueva > g else 0.2)
    if nueva < g:
        prop = max(nueva, min(prop, g - 0.1))
    return round(max(ns["GANANCIA_MIN"], min(ns["GANANCIA_MAX"], prop)), 1)

comp("con su voz (p90=0.601) baja de 0.7", _ciclo(0.7, 0.601) < 0.7, "-> %.1f" % _ciclo(0.7, 0.601))
_g = 0.7
for _ in range(6):
    _g = _ciclo(_g, 0.99)
comp("y con el microfono saturado llega abajo", _g <= 0.4, "-> %.1f" % _g)
comp("subir sigue siendo rapido (no deja sordo al arrancar)", _ciclo(1.0, 0.05) >= 4.0, "-> %.1f" % _ciclo(1.0, 0.05))

print("")
print("todo correcto" if fallos == 0 else "%d casos MAL" % fallos)
sys.exit(1 if fallos else 0)
