# -*- coding: utf-8 -*-
# DEJAR DE REINTENTAR A CIEGAS EL RESUMEN DEL DIARIO (26/09, idea 60 de las 121).
#
# El spam ("no pude resumir" cada 65 s) ya lo arreglo la idea 14 (ollama_vivo + ollama_cayo:
# backoff y avisar una vez). Lo que faltaba es la regla 2: pasadas DIARIO_CRUDO_HORAS sin poder
# resumir un dia, volcar sus frases EN BRUTO al diario para no perderlo, UNA vez (marca .crudo),
# y sustituirlo por las vinetas cuando ollama vuelva. Este banco prueba volcar_crudo_pendiente.
#
# Se EJECUTA la funcion real (extraida por AST), no una copia.
import ast
import io
import json
import os
import shutil
import sys
import tempfile
import time

sys.stdout.reconfigure(encoding="utf-8")
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fuente = io.open(os.path.join(RAIZ, "charla_worker.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    if not ok:
        fallos += 1
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etq, ("-> %s" % (det,)) if det else ""))


registros = []
ns = {"os": os, "time": time, "json": json,
      "salida": lambda ev, idp=0, **k: registros.append(dict(k)),
      "__file__": os.path.join(RAIZ, "charla_worker.py")}
QUIERO = ("origen_linea", "volcar_crudo_pendiente")
for n in arbol.body:
    if isinstance(n, ast.FunctionDef) and n.name in QUIERO:
        exec(compile(ast.Module(body=[n], type_ignores=[]), "<cw>", "exec"), ns)
    if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", "") in ("DIARIO_CRUDO_HORAS",):
        exec(compile(ast.Module(body=[n], type_ignores=[]), "<cw>", "exec"), ns)
faltan = [q for q in QUIERO if q not in ns] + (["DIARIO_CRUDO_HORAS"] if "DIARIO_CRUDO_HORAS" not in ns else [])
if faltan:
    print("  MAL  no encuentro en charla_worker.py: %s" % ", ".join(faltan))
    sys.exit(1)

tmp = tempfile.mkdtemp(prefix="diario-crudo-")
ns["CARPETA_CEREBRO"] = tmp


def escribe_dia(dia, turnos, horas_atras):
    ruta = os.path.join(tmp, "charla-%s.jsonl" % dia)
    with io.open(ruta, "w", encoding="utf-8") as f:
        for t in turnos:
            f.write(json.dumps(t, ensure_ascii=False) + "\n")
    viejo = time.time() - horas_atras * 3600
    os.utime(ruta, (viejo, viejo))
    return ruta


try:
    print("")
    print("-- 1. un dia viejo sin resumir se vuelca en bruto --")
    ruta = escribe_dia("2026-09-20", [
        {"h": "22:00", "braya": "no cierra bien la funda de la consola", "nova": "vaya"},
        {"h": "22:01", "braya": "no coincide con el borde", "nova": "entiendo"}], 7)
    registros[:] = []
    r = ns["volcar_crudo_pendiente"](hoy="2026-09-25")
    comp("1. vuelca (devuelve True)", r is True, repr(r))
    comp("   con crudo=True y la fecha del dia", len(registros) == 1 and registros[0].get("crudo") is True and registros[0].get("fecha") == "2026-09-20", registros[:1])
    comp("   y con las frases de braya en bruto", len(registros) == 1 and "no cierra bien la funda" in registros[0].get("texto", ""), "")
    comp("   y deja la marca .crudo al lado", os.path.exists(ruta + ".crudo"))
    comp("   y NO borra el jsonl (para resumirlo al volver ollama)", os.path.exists(ruta))

    print("")
    print("-- 2. no se vuelca dos veces (una por dia) --")
    registros[:] = []
    r2 = ns["volcar_crudo_pendiente"](hoy="2026-09-25")
    comp("2. ya marcado -> no re-vuelca", r2 is False and len(registros) == 0, "%s / %d" % (r2, len(registros)))

    print("")
    print("-- 3. un dia reciente (dentro del plazo) NO se vuelca todavia --")
    shutil.rmtree(tmp); os.makedirs(tmp)
    escribe_dia("2026-09-24", [{"h": "10:00", "braya": "hola", "nova": "hey"}], 1)   # solo 1 h
    registros[:] = []
    r3 = ns["volcar_crudo_pendiente"](hoy="2026-09-25")
    comp("3. dentro del plazo (1 h < 6 h) no se vuelca", r3 is False and len(registros) == 0, "%s" % r3)

finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  el dia sin resumir se vuelca en bruto a tiempo")
sys.exit(0)
