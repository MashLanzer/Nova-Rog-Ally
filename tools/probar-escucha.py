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
QUIERO = {"SILENCIO_FIN", "SILENCIO_FIN_LOTENGO", "silencio_para_cerrar"}
trozos = []
for n in arbol.body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in QUIERO:
        trozos.append(ast.get_source_segment(fuente, n))
ns = {}
exec(chr(10).join(trozos), ns)

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
# en las 20 grabaciones la pausa mas larga DENTRO de una orden fue de 0,45 s (14/09)
comp("y no corta una pausa normal dentro de la orden", ns["SILENCIO_FIN_LOTENGO"] > 0.45)

print("")
print("todo correcto" if fallos == 0 else "%d casos MAL" % fallos)
sys.exit(1 if fallos else 0)
