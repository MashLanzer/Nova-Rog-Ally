# -*- coding: utf-8 -*-
"""QUE LA CACHE DE VOZ SE PODE TAMBIEN CON NOVA ENCENDIDA (17/09).

limpiar_cache() solo se llamaba AL ARRANCAR y el worker vive desde el login, asi que el
tope de 60 MB no se aplicaba nunca en caliente. Hoy la cache esta en 13,8 MB (487 mp3), o
sea que esto no rescata nada todavia: es para no tener que vaciarla a mano dentro de unos
meses, que es justo lo que se queria evitar al poner el tope.

Lo que mas se comprueba aqui no es que borre, sino DOS cosas que se pueden estropear:
que no borre lo que no toca, y que la poda no se cuele DELANTE de la voz (cuesta 17,2 ms
medidos: en el camino de cada frase eso es latencia).

    python tools/probar-cache-voz.py
"""
import ast
import os
import shutil
import sys
import tempfile
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = open(os.path.join(RAIZ, "tts_worker.py"), encoding="utf-8").read()
arbol = ast.parse(FUENTE)
QUIERO = {"limpiar_cache", "CACHE_MAX_MB", "PODA_CADA"}
trozos = []
for n in arbol.body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in QUIERO:
        trozos.append(ast.get_source_segment(FUENTE, n))
# EL ENTORNO TIENE QUE TRAER TODO LO QUE LA FUNCION USE (21/09). Aqui solo estaba "os", y
# el dia que limpiar_cache empezo a usar time.time() para barrer los .part huerfanos esta
# prueba se puso en rojo -cuatro casos- con el codigo de verdad correcto: tts_worker.py SI
# importa time, era el entorno de aqui el que no lo tenia. Un rojo asi hace perder media
# hora buscando donde no hay nada. La comprobacion de abajo evita que se repita en silencio.
ns = {"os": os, "time": time}
exec("\n".join(trozos), ns)

# QUE NO FALTE NINGUNO MAS: se miran los nombres globales que usa limpiar_cache y se exige
# que esten en el entorno O importados en tts_worker.py. Si un dia usa shutil y nadie lo
# pone aqui, sale MAL con su nombre en vez de un NameError a mitad de la prueba.
_fn = next(n for n in arbol.body if getattr(n, "name", None) == "limpiar_cache")
_locales = {a.arg for a in _fn.args.args}
for _n in ast.walk(_fn):
    if isinstance(_n, ast.Assign):
        _locales |= {t.id for t in _n.targets if isinstance(t, ast.Name)}
    elif isinstance(_n, (ast.For, ast.comprehension)):
        _tg = getattr(_n, "target", None)
        if isinstance(_tg, ast.Name):
            _locales.add(_tg.id)
        elif isinstance(_tg, ast.Tuple):
            _locales |= {e.id for e in _tg.elts if isinstance(e, ast.Name)}
_usa = {x.id for x in ast.walk(_fn) if isinstance(x, ast.Name) and isinstance(x.ctx, ast.Load)}
_import, _globales = set(), set()
for _n in arbol.body:
    if isinstance(_n, ast.Import):
        _import |= {(a.asname or a.name).split(".")[0] for a in _n.names}
    elif isinstance(_n, ast.ImportFrom):
        _import |= {(a.asname or a.name) for a in _n.names}
    elif isinstance(_n, ast.Assign):
        _globales |= {t.id for t in _n.targets if isinstance(t, ast.Name)}
    elif isinstance(_n, (ast.FunctionDef, ast.AsyncFunctionDef)):
        _globales.add(_n.name)
# SALIDA y compania son globales del modulo que esta prueba pone a mano mas abajo (a una
# carpeta de mentira): no son imports que falten, son parte del trato.
_faltan = sorted(x for x in _usa - _locales - set(ns) - set(dir(__builtins__)) - _globales
                 if x not in QUIERO and not x.startswith("_"))
_sin_importar = [x for x in _faltan if x not in _import]

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det else ""))
    if not ok:
        fallos += 1


print("  -- la prueba y el modulo hablan el mismo idioma --")
comp("el entorno de aqui trae todo lo que usa limpiar_cache", not _faltan,
     ("le faltan: " + ", ".join(_faltan)) if _faltan else "")
comp("y tts_worker.py importa de verdad lo que usa", not _sin_importar,
     ("no estan importados: " + ", ".join(_sin_importar)) if _sin_importar else "")


def montar(carpeta, cuantos, kb, edad_desde=0):
    """deja `cuantos` mp3 de `kb` KB, el primero el mas viejo"""
    for i in range(cuantos):
        ruta = os.path.join(carpeta, "voz%03d.mp3" % i)
        with open(ruta, "wb") as f:
            f.write(b"\0" * (kb * 1024))
        open(ruta + ".env", "wb").write(b"\0" * 100)
        # mtime creciente: voz000 es el mas viejo
        t = time.time() - (cuantos - i) * 60 - edad_desde
        os.utime(ruta, (t, t))


def quedan(carpeta):
    return sorted(x for x in os.listdir(carpeta) if x.endswith(".mp3"))


def megas(carpeta):
    return sum(os.path.getsize(os.path.join(carpeta, x)) for x in os.listdir(carpeta) if x.endswith(".mp3")) / 1048576.0


tope = ns["CACHE_MAX_MB"]
print("  -- por debajo del tope no se toca nada --")
d = tempfile.mkdtemp()
try:
    montar(d, 10, 1024)                      # 10 MB de 60
    ns["SALIDA"] = d
    ns["limpiar_cache"]()
    comp("con 10 MB de %d no borra nada" % tope, len(quedan(d)) == 10, "quedan %d" % len(quedan(d)))
    comp("y los .env siguen ahi", len([x for x in os.listdir(d) if x.endswith(".env")]) == 10)
finally:
    shutil.rmtree(d, ignore_errors=True)

print("  -- pasado el tope, se van los MAS VIEJOS --")
d = tempfile.mkdtemp()
try:
    montar(d, tope + 20, 1024)               # 80 MB de 60
    ns["SALIDA"] = d
    ns["limpiar_cache"]()
    q = quedan(d)
    comp("baja del tope", megas(d) <= tope, "%.1f MB" % megas(d))
    comp("y deja holgura (<= 80% del tope)", megas(d) <= tope * 0.8, "%.1f MB" % megas(d))
    comp("el mas viejo se fue", "voz000.mp3" not in q)
    comp("el mas nuevo se queda", "voz%03d.mp3" % (tope + 19) in q)
    comp("se lleva tambien su .env", not os.path.exists(os.path.join(d, "voz000.mp3.env")))
    comp("y no borra el .env del que sobrevive", os.path.exists(os.path.join(d, "voz%03d.mp3.env" % (tope + 19))))
finally:
    shutil.rmtree(d, ignore_errors=True)

print("  -- y no se lleva por delante lo que no es suyo --")
d = tempfile.mkdtemp()
try:
    montar(d, tope + 20, 1024)
    open(os.path.join(d, "velocidad.txt"), "w").write("+0%")
    open(os.path.join(d, "ui-nivel.txt"), "w").write("0")
    ns["SALIDA"] = d
    ns["limpiar_cache"]()
    comp("velocidad.txt sigue ahi", os.path.exists(os.path.join(d, "velocidad.txt")))
    comp("ui-nivel.txt tambien", os.path.exists(os.path.join(d, "ui-nivel.txt")))
finally:
    shutil.rmtree(d, ignore_errors=True)

print("  -- y no revienta con lo raro --")
d = tempfile.mkdtemp()
try:
    ns["SALIDA"] = d
    ns["limpiar_cache"]()
    comp("una carpeta vacia no la rompe", True)
finally:
    shutil.rmtree(d, ignore_errors=True)
ns["SALIDA"] = os.path.join(tempfile.gettempdir(), "no-existe-esta-carpeta-nova")
ns["limpiar_cache"]()
comp("una carpeta que no existe tampoco", True)

# --- LO QUE SUJETA QUE NO SE METE LATENCIA EN LA VOZ ---
print("  -- y la poda NO se cuela delante de la voz --")
comp("existe el contador de frases nuevas", "PODA_CADA" in ns, "PODA_CADA=%s" % ns.get("PODA_CADA"))
comp("se poda tambien dentro del bucle, no solo al arrancar", FUENTE.count("limpiar_cache()") >= 2,
     "%d llamadas" % FUENTE.count("limpiar_cache()"))
i_print = FUENTE.find("print(ruta, flush=True)")
i_poda = FUENTE.find("limpiar_cache()", i_print)
comp("y va DESPUES de entregar la ruta", i_print > 0 and i_poda > i_print,
     "print en %d, poda en %d" % (i_print, i_poda))
# solo las frases NUEVAS cuentan: un acierto de cache no deja archivo que podar
comp("solo cuentan las frases nuevas", "if creada:" in FUENTE)

print("")
print("todo correcto" if fallos == 0 else "%d casos MAL" % fallos)
sys.exit(1 if fallos else 0)
