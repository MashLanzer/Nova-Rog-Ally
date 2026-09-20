# -*- coding: utf-8 -*-
"""Que el disco solo se abra para lo que es tuyo Y fue una orden de verdad.

POR QUE EXISTE (20/09). La noche del 19/09 acabaron en pruebas\\audio\\uso 14 wav de una
conversacion que no era con Nova, y el motivo fue que escucha.grabarUso era un si/no:
en "si" se guardaba CUALQUIER rafaga que pasara la puerta del microfono. Ahora son tres
modos y "ordenes" tiene dos filtros. Esta prueba comprueba los dos, y sobre todo
comprueba lo que NO deben hacer:

  - la voz ajena no se graba... pero en modo "todo" si, porque ahi se pide a proposito.
  - la activacion que murio en silencio no se graba... pero "le hable y no me entendio"
    SI, y esa es la distincion que justifica todo esto: las dos llegan con el texto
    vacio, y una es ruido de la habitacion mientras la otra es justo el audio que hace
    falta para mejorar el oido. Por eso el filtro mira la VOZ, no el texto.

Las funciones se sacan de wake_vosk.py con ast, no se copian: una copia se desincroniza.

    python tools\\probar-grabar-uso.py
"""
import ast
import io
import json
import os
import shutil
import sys
import tempfile
import time
import wave

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-52s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# --- las funciones de verdad, sacadas del archivo real ---
# REGLA (aprendida cuatro veces ya): si llamas a una funcion desde aqui, TIENE que estar
# en esta lista. Si falta, la prueba revienta o -peor- pasa en verde sin probar nada.
QUIERO = ("segundos_de_voz", "modo_grabar_uso", "grabar_uso_activo", "guardar_uso", "apuntar_uso")
fuente = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)

anotado = []
ns = {"np": np, "os": os, "time": time, "json": json, "sys": sys,
      "anota": lambda t: anotado.append(t)}
for n in arbol.body:
    if isinstance(n, ast.FunctionDef) and n.name in QUIERO:
        exec(compile(ast.Module(body=[n], type_ignores=[]), "<wake_vosk>", "exec"), ns)
    # y las constantes que usan
    if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", "") in ("VOZ_MIN_GUARDAR",):
        exec(compile(ast.Module(body=[n], type_ignores=[]), "<wake_vosk>", "exec"), ns)

faltan = [q for q in QUIERO if q not in ns]
if faltan:
    print("  MAL  no encuentro en wake_vosk.py: %s" % ", ".join(faltan))
    sys.exit(1)
comp("el umbral sale del archivo, no de aqui", "VOZ_MIN_GUARDAR" in ns,
     "VOZ_MIN_GUARDAR = %s" % ns.get("VOZ_MIN_GUARDAR"))

# --- un escenario aislado: ni se toca la carpeta de uso de verdad ---
base = tempfile.mkdtemp(prefix="grabar-uso-")
ns["USO_DIR"] = os.path.join(base, "uso")
ns["NIVEL"] = os.path.join(base, "nivel.txt")
ns["escribir"] = lambda ruta, texto: io.open(ruta, "w", encoding="utf-8").write(texto)
ns["_uso"] = {"id": "", "activo": None}
ns["__file__"] = os.path.join(base, "wake_vosk.py")


def modo(m):
    """Deja config.json con ese modo y olvida el cacheado."""
    io.open(os.path.join(base, "config.json"), "w", encoding="utf-8").write(
        json.dumps({"escucha": {"grabarUso": m}}))
    ns["_uso"] = {"id": "", "activo": None}


def wavs():
    return sorted(f for f in os.listdir(ns["USO_DIR"])) if os.path.isdir(ns["USO_DIR"]) else []


def bloques(segundos, con_voz):
    """Bloques int16 como los que junta el worker. Con voz = ruido audible sostenido."""
    n = int(16000 * segundos)
    if not con_voz:
        return [np.zeros(n, dtype=np.int16)]
    t = np.arange(n) / 16000.0
    # 180 Hz con envolvente, bastante por encima del 0,008 que mira segundos_de_voz
    onda = np.sin(2 * np.pi * 180 * t) * 0.25 * (1.0 + 0.5 * np.sin(2 * np.pi * 3 * t))
    return [(onda * 32767).astype(np.int16)]


def cuantos(**campos):
    """Llama a guardar_uso y devuelve cuantos wav hay despues."""
    antes = len(wavs())
    ns["guardar_uso"](campos.pop("bloques"), **campos)
    time.sleep(0.02)   # el nombre lleva los segundos: dos seguidos no se pisan
    return len(wavs()) - antes


print("")
print("-- primero, que la medida de voz distinga las dos cosas --")
v_silencio = ns["segundos_de_voz"](np.zeros(16000, dtype=np.float32))
v_voz = ns["segundos_de_voz"]((np.concatenate(bloques(1.5, True))).astype(np.float32) / 32768.0)
comp("el silencio da 0 s de voz", v_silencio < 0.01, "%.3f s" % v_silencio)
comp("y una frase da bastante mas que el umbral", v_voz > ns["VOZ_MIN_GUARDAR"] * 4, "%.2f s" % v_voz)

print("")
print('-- modo "ordenes" (el de por defecto) --')
modo("ordenes")
comp('el modo se lee bien', ns["modo_grabar_uso"]() == "ordenes", ns["modo_grabar_uso"]())
comp("una orden normal se guarda",
     cuantos(bloques=bloques(1.5, True), entregado="abre steam", origen="nombre") == 1)
comp("la activacion que murio en silencio NO se guarda",
     cuantos(bloques=bloques(2.0, False), entregado="", origen="nombre") == 0)
comp('pero "le hable y no me entendio" SI se guarda',
     cuantos(bloques=bloques(1.5, True), entregado="", origen="nombre") == 1,
     "es el wav mas valioso que hay para el oido")
comp("la voz ajena NO se guarda",
     cuantos(bloques=bloques(1.5, True), entregado="pon musica", voz_ajena=True) == 0)
comp("y lo dice en el log, sin repetir lo que oyo",
     any("no es la tuya" in a for a in anotado) and not any("pon musica" in a for a in anotado))

print("")
print('-- modo "todo": se pide a proposito, se guarda todo --')
modo("todo")
comp("la voz ajena si se guarda",
     cuantos(bloques=bloques(1.5, True), entregado="pon musica", voz_ajena=True) == 1)
comp("y el silencio tambien",
     cuantos(bloques=bloques(2.0, False), entregado="", origen="nombre") == 1)

print("")
print('-- modo "no": el disco no se abre para nada --')
modo("no")
comp("ni para una orden buena",
     cuantos(bloques=bloques(1.5, True), entregado="abre steam", origen="nombre") == 0)

print("")
print("-- y un config viejo con true/false sigue queriendo decir lo mismo --")
modo(True)
comp("true -> todo", ns["modo_grabar_uso"]() == "todo")
modo(False)
comp("false -> no", ns["modo_grabar_uso"]() == "no")

shutil.rmtree(base, ignore_errors=True)
print("")
if fallos:
    print("  %d fallo(s)" % fallos)
    sys.exit(1)
print("  el disco solo se abre para tu voz y para lo que fue una orden de verdad")
sys.exit(0)
