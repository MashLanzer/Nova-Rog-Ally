# -*- coding: utf-8 -*-
"""Que el diario diga de donde sale cada linea, y que el resumen solo use lo real.

POR QUE (20/09, D4). El banco de pruebas llego a meter recuerdos FALSOS en la memoria de
verdad: los osos polares y Hades acabaron en memoria\\diario, y el 17/09 ese diario tenia
574 lineas con el 100 % repetidas, o sea 41 pasadas del banco. C7 cerro la puerta -nadie
escribe sin decir en que carpeta-, y esto es la segunda cerradura: cada linea dice si es
real o de prueba, y el resumidor descarta lo que no sea real.

LA SENAL NO SE INVENTA NI SE RECUERDA: sale de la carpeta. Si se escribe en
memoria\\cerebro es la memoria de verdad; cualquier otra es prueba. Asi no depende de que
alguien se acuerde de pasar una marca, que es justo lo que fallo la primera vez.

    python tools\\probar-diario-origen.py
"""
import ast
import io
import json
import os
import shutil
import sys
import tempfile
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# las funciones de verdad, sacadas del archivo real
QUIERO = ("origen_linea",)
fuente = io.open(os.path.join(RAIZ, "charla_worker.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)

dicho = []
ns = {"os": os, "time": time, "json": json,
      "salida": lambda *a, **k: dicho.append(k.get("texto", "")),
      "__file__": os.path.join(RAIZ, "charla_worker.py")}
for n in arbol.body:
    if isinstance(n, ast.FunctionDef) and n.name in QUIERO:
        exec(compile(ast.Module(body=[n], type_ignores=[]), "<cw>", "exec"), ns)
    if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", "") == "CEREBRO_REAL":
        exec(compile(ast.Module(body=[n], type_ignores=[]), "<cw>", "exec"), ns)
faltan = [q for q in QUIERO if q not in ns]
if faltan or "CEREBRO_REAL" not in ns:
    print("  MAL  no encuentro en charla_worker.py: %s" % ", ".join(faltan + (["CEREBRO_REAL"] if "CEREBRO_REAL" not in ns else [])))
    sys.exit(1)

print("")
print("-- de donde dice que viene cada linea --")
ns["CARPETA_CEREBRO"] = ns["CEREBRO_REAL"]
comp("la memoria de verdad es 'real'", ns["origen_linea"]() == "real", ns["origen_linea"]())

tmp = tempfile.mkdtemp(prefix="diario-")
ns["CARPETA_CEREBRO"] = tmp
comp("una carpeta cualquiera es 'prueba'", ns["origen_linea"]() == "prueba", ns["origen_linea"]())

ns["CARPETA_CEREBRO"] = ""
comp("sin carpeta, 'prueba' (ante la duda, no es real)", ns["origen_linea"]() == "prueba")

# la misma carpeta escrita de otra forma sigue siendo la real: si no, el banco de verdad
# se marcaria como prueba y dejaria de resumirse nada
ns["CARPETA_CEREBRO"] = os.path.join(RAIZ, "memoria", "..", "memoria", "CEREBRO")
comp("la real escrita raro sigue siendo real", ns["origen_linea"]() == "real", ns["origen_linea"]())

print("")
print("-- y el resumidor solo se queda con lo real --")
# se reproduce el filtro tal y como esta en resumir_dias_pasados, leido del archivo
filtro = 'if aqui_es_real and t.get("o", "real") != "real":'
comp("el filtro existe en resumir_dias_pasados", filtro in fuente)
comp("y el contador de saltadas tambien", 'saltadas += 1' in fuente)
# EL "aqui_es_real" NO SOBRA, y esta prueba existe para que nadie lo quite: sin el, el
# filtro tira TODA linea de prueba en cualquier carpeta, y como el banco escribe en la
# suya, el resumen del diario se volvia imposible de probar (paso el 20/09: dos casos en
# rojo en cuanto se aplico). Lo que hay que proteger es la memoria de verdad.
comp("y solo muerde en la memoria de verdad", 'aqui_es_real = (origen_linea() == "real")' in fuente)

lineas = [
    {"h": "10:00", "o": "real", "braya": "abre steam", "nova": "abriendo"},
    {"h": "10:01", "o": "prueba", "braya": "dime algo de osos polares", "nova": "los osos polares..."},
    {"h": "10:02", "braya": "linea vieja sin campo", "nova": "ok"},
]
quedan = [t for t in lineas if t.get("o", "real") == "real"]
comp("la de prueba se cae", len(quedan) == 2, "%d de %d" % (len(quedan), len(lineas)))
comp("y no queda ni rastro del oso", not any("oso" in json.dumps(t, ensure_ascii=False) for t in quedan))
comp("la vieja sin campo se conserva", any("linea vieja" in t["braya"] for t in quedan))

shutil.rmtree(tmp, ignore_errors=True)
print("")
if fallos:
    print("  %d fallo(s)" % fallos)
    sys.exit(1)
print("  el diario dice de donde viene cada linea y el resumen solo usa lo real")
sys.exit(0)
