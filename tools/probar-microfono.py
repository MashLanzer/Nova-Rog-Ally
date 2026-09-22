# -*- coding: utf-8 -*-
# LA GANANCIA ES DE UN MICROFONO, NO DE LA CONSOLA (22/09).
#
# braya enchufo un micro USB a la consola y dijo lo que hacia falta: "Nova tiene que saber
# detectar cuando esta y no esta ese micro y reajustar su ganancia sola". Y tenia razon, era
# un fallo de verdad:
#
#   - la ganancia se guardaba a pelo en tmp/ganancia.txt y al arrancar se recuperaba SIN
#     MIRAR de que microfono era. Con el array de Realtek estaba en x18,3; ese numero en un
#     micro USB -que entra mucho mas fuerte- satura, y al reves deja a Nova sorda.
#   - y con Nova YA EN MARCHA, enchufar un micro nuevo no lo notaba nadie: el stream estaba
#     abierto con el de antes y nadie volvia a preguntar. Desenchufar si se notaba (deja de
#     llegar audio y salta MIC_MUERTO), pero enchufar no.
#
# Aqui se prueba la parte que se puede probar sin hardware: la logica de "esta ganancia, ¿es
# de este micro?". Lo otro -que al cambiar de micro el worker salga y el asistente lo
# relance- se comprueba sobre el codigo, porque montar dos micros de mentira no se puede.
#
#   python tools/probar-microfono.py
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- la funcion de verdad, sacada del archivo ----------------------------
ns = {"GANANCIA_MIN": 0.4, "GANANCIA_MAX": 60.0, "RUTA_GANANCIA": ""}
m = re.search(r"(?ms)^def ganancia_guardada\(.*?\n(?=\n\S|\Z)", SRC)
if not m:
    print("  MAL  no encuentro ganancia_guardada en wake_vosk.py")
    sys.exit(1)
exec(compile(m.group(0), "ganancia_guardada", "exec"), ns)
ganancia_guardada = ns["ganancia_guardada"]

import tempfile
tmp = os.path.join(tempfile.gettempdir(), "gan-prueba-%d.txt" % os.getpid())
ns["RUTA_GANANCIA"] = tmp


def pon(txt):
    io.open(tmp, "w", encoding="utf-8").write(txt)


USB = "Micrófono (USB PnP Sound Device)"
REALTEK = "Microphone Array (Realtek(R) Audio)"

print("")
print("-- la ganancia solo se hereda si es del MISMO microfono --")
pon("18.3|" + REALTEK)
g, de = ganancia_guardada(REALTEK)
comp("con el mismo micro, se hereda", g == 18.3, "x%s" % g)
g, de = ganancia_guardada(USB)
comp("con otro micro, NO se hereda", g is None, "devolvio %s, era de '%s'" % (g, de[:28]))
comp("y dice de quien era, para poder contarlo", de == REALTEK)

print("")
print("-- el formato viejo (solo el numero) tampoco se hereda --")
# el tmp/ganancia.txt que hay hoy en la consola es asi: un numero pelado. No se sabe de que
# micro es, asi que lo honesto es recalibrar una vez.
pon("18.3")
g, de = ganancia_guardada(USB)
comp("un numero sin nombre no vale para nadie", g is None, "devolvio %s" % g)
comp("y no se inventa un nombre", de == "")

print("")
print("-- y lo que no puede pasar --")
pon("999|" + USB)
g, de = ganancia_guardada(USB)
comp("una ganancia fuera de rango se descarta", g is None, "devolvio %s" % g)
pon("esto no es un numero|" + USB)
g, de = ganancia_guardada(USB)
comp("un fichero roto no revienta", g is None)
try:
    os.remove(tmp)
except OSError:
    pass
ns["RUTA_GANANCIA"] = os.path.join(tempfile.gettempdir(), "no-existe-%d.txt" % os.getpid())
g, de = ganancia_guardada(USB)
comp("sin fichero, se empieza de cero", g is None)

print("")
print("-- se guarda CON el nombre, o todo lo de arriba sobra --")
comp("al guardar va el micro al lado", 'escribir(RUTA_GANANCIA, "%.1f|%s" % (ganancia, dispositivo))' in SRC)

print("")
print("-- y se entera si cambias de micro con Nova en marcha --")
comp("mira el dispositivo cada cierto tiempo", "MIRAR_MICRO_CADA" in SRC)
comp("y solo cuando no hay nada en marcha",
     "if (not dictando and not confirmando and not pausado" in SRC)
comp("si cambia, sale para que lo relancen con el nuevo",
     bool(re.search(r"has cambiado de microfono.{0,400}sys\.exit\(3\)", SRC, re.S)))
# el asistente RELANZA al worker cuando sale: sin eso, salir dejaria a Nova sorda para
# siempre, que es mucho peor que seguir con el micro viejo
ASIS = io.open(os.path.join(RAIZ, "assistant.ps1"), encoding="utf-8-sig").read()
comp("y el asistente lo relanza cuando muere",
     "$script:wakeProc.HasExited" in ASIS and "$script:wakeProc = Start-Process" in ASIS)
comp("al arrancar avisa de que el micro cambio", "microfono distinto: antes" in SRC)

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  la ganancia va con su microfono, y cambiar de micro se nota")
sys.exit(0)
