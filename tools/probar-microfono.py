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
# DEVUELVE TRES COSAS DESDE EL 1/10/2026 (idea 7 de las 20 nuevas): la ganancia global, de que
# microfono es, y un diccionario con la ganancia aprendida POR FRANJA DEL DIA. Medido: entre la
# tarde y la noche hay 122 % de diferencia. Lo que este banco defiende no cambia -que la ganancia
# de un micro no se herede en otro- y ahora ademas se comprueba que LAS FRANJAS tampoco se heredan.
#
# La funcion necesita FRANJAS_GANANCIA, asi que se saca del fichero igual que ella (manera 6: nunca
# una copia propia del dato).
ns = {"GANANCIA_MIN": 0.4, "GANANCIA_MAX": 60.0, "RUTA_GANANCIA": ""}
_mf = re.search(r"^FRANJAS_GANANCIA = .*$", SRC, re.M)
if not _mf:
    print("  MAL  no encuentro FRANJAS_GANANCIA en wake_vosk.py")
    sys.exit(1)
exec(_mf.group(0), ns)
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
g, de, _fr = ganancia_guardada(REALTEK)
comp("con el mismo micro, se hereda", g == 18.3, "x%s" % g)
g, de, _fr = ganancia_guardada(USB)
comp("con otro micro, NO se hereda", g is None, "devolvio %s, era de '%s'" % (g, de[:28]))
comp("y dice de quien era, para poder contarlo", de == REALTEK)

print("")
print("-- el formato viejo (solo el numero) tampoco se hereda --")
# el tmp/ganancia.txt que hay hoy en la consola es asi: un numero pelado. No se sabe de que
# micro es, asi que lo honesto es recalibrar una vez.
pon("18.3")
g, de, _fr = ganancia_guardada(USB)
comp("un numero sin nombre no vale para nadie", g is None, "devolvio %s" % g)
comp("y no se inventa un nombre", de == "")

print("")
print("-- y lo que no puede pasar --")
pon("999|" + USB)
g, de, _fr = ganancia_guardada(USB)
comp("una ganancia fuera de rango se descarta", g is None, "devolvio %s" % g)
pon("esto no es un numero|" + USB)
g, de, _fr = ganancia_guardada(USB)
comp("un fichero roto no revienta", g is None)
try:
    os.remove(tmp)
except OSError:
    pass
ns["RUTA_GANANCIA"] = os.path.join(tempfile.gettempdir(), "no-existe-%d.txt" % os.getpid())
g, de, _fr = ganancia_guardada(USB)
comp("sin fichero, se empieza de cero", g is None)

print("")
print("-- se guarda CON el nombre, o todo lo de arriba sobra --")
# EL GUARDADO PASO A guardar_ganancia EL 1/10/2026 (idea 7): la ganancia ya no es una, son cuatro
# -una por franja del dia- y no cabia en una linea suelta. Lo que esta seccion defiende es lo mismo:
# que el NOMBRE DEL MICRO vaya al lado del numero, porque si no, al cambiar de micro se heredaria una
# calibracion que en el nuevo satura o deja a Nova sorda. Se comprueba sobre la funcion, que es donde
# vive ahora, y no sobre la linea que la llama.
comp("al guardar va el micro al lado", 'guardar_ganancia(ganancia, dispositivo' in SRC)
comp("  y la funcion escribe el nombre en el fichero",
     '"%.1f|%s|%s" % (g, micro, partes)' in SRC)
# Y LAS FRANJAS TAMPOCO SE HEREDAN de otro micro: es el mismo peligro con otra ropa. x18,3 de un
# array de Realtek satura en un USB, y eso vale para la global y para las cuatro franjas.
# LA RUTA SE DEVUELVE A SU SITIO: la prueba de "sin fichero" la habia apuntado a uno que no existe,
# asi que sin esto se escribia en tmp y la funcion leia de otro sitio. Primer intento de estas lineas.
ns["RUTA_GANANCIA"] = tmp
with open(tmp, "w", encoding="utf-8") as _f:
    _f.write("9.1|%s|noche:15.5,tarde:4.1" % REALTEK)
_g2, _de2, _fr2 = ganancia_guardada(USB)
comp("las franjas de otro micro NO se heredan", _g2 is None and _fr2 == {})
_g3, _de3, _fr3 = ganancia_guardada(REALTEK)
comp("  pero las del suyo si", _g3 == 9.1 and _fr3 == {"noche": 15.5, "tarde": 4.1})

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
