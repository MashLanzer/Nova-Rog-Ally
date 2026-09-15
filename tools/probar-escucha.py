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
QUIERO = {"SILENCIO_FIN", "SILENCIO_FIN_LOTENGO", "silencio_para_cerrar", "MARGEN_CORTE_HZ", "es_voz_de_braya", "PROMPT_ORDENES", "es_eco_del_ejemplo"}
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

print("")
print("todo correcto" if fallos == 0 else "%d casos MAL" % fallos)
sys.exit(1 if fallos else 0)
