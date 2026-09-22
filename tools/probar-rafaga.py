# -*- coding: utf-8 -*-
# EL LISTON DE LA RAFAGA, RELATIVO A SU VOZ (21/09 noche).
#
# El filtro de "suena demasiado flojo para ser una llamada" tenia un numero fijo: 0,030. Y
# braya dijo, usandola, que "se demora en recibir lo que le digo". El log lo explica: desde
# que ese filtro existe (20/09) hay 52 activaciones y 39 descartes por flojo, y cruzando
# cada descarte con el p90 de SU voz en ese mismo momento, la mayoria de esas rafagas eran
# MAS FUERTES que su propia voz (127 %, 129 %, 162 %). Su voz entera estaba por debajo del
# liston -p90 de 0,011 a 0,026 contra 0,030-, asi que no podia pasar ninguna llamada por
# mucho que repitiera. Y repetia: tres descartes seguidos en dos minutos, ni una activacion.
#
# Medido sobre esos mismos datos, el liston relativo RECUPERA 12 llamadas y NO PIERDE NI UNA
# de las 52 que hoy activan. Aqui se comprueba la formula y los casos de verdad del log.
#
#   python tools/probar-rafaga.py
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sacar(nombre, defecto):
    """el valor DEL ARCHIVO, no una copia escrita aqui: una copia se queda vieja al primer
    cambio y esta prueba pasaria midiendo otra cosa."""
    src = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
    m = re.search(r"(?m)^" + nombre + r"\s*=\s*([0-9.]+)", src)
    return float(m.group(1)) if m else defecto


SUELO = sacar("RAFAGA_SUELO", 0.010)
FACTOR = sacar("RAFAGA_FACTOR", 0.85)
src = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
m = re.search(r"(?m)^RAFAGA_MIN_NOMBRE = RAFAGA_ARG if RAFAGA_ARG is not None else ([0-9.]+)", src)
TECHO = float(m.group(1)) if m else 0.030

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-52s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


def umbral(p90):
    """la misma formula que umbral_rafaga() en wake_vosk.py"""
    if p90 <= 0:
        return TECHO
    return max(SUELO, min(TECHO, p90 * FACTOR))


print("")
print("  suelo %.3f, factor %.2f, techo %.3f (sacados del archivo)" % (SUELO, FACTOR, TECHO))
print("")
print("-- la formula --")
comp("sin p90 todavia, manda el techo de siempre", abs(umbral(0) - TECHO) < 1e-9, "%.4f" % umbral(0))
comp("si habla fuerte, se le exige lo mismo que antes", abs(umbral(0.098) - TECHO) < 1e-9, "p90 0.098 -> %.4f" % umbral(0.098))
comp("si habla flojo, el liston baja con el", umbral(0.0133) < TECHO, "p90 0.0133 -> %.4f" % umbral(0.0133))
comp("pero nunca por debajo del suelo", abs(umbral(0.001) - SUELO) < 1e-9, "p90 0.001 -> %.4f" % umbral(0.001))
comp("el liston nunca pasa del techo", all(umbral(x) <= TECHO + 1e-9 for x in (0.0, 0.01, 0.05, 0.5, 1.0)))

print("")
print("-- los casos DE VERDAD del log (21/09 por la noche) --")
# (rafaga, p90 de su voz en ese momento, lo que tiene que pasar, por que)
CASOS = [
    (0.0188, 0.0116, True,  "23:44:06  la rafaga es el 162 % de su voz: es el llamandola"),
    (0.0122, 0.0133, True,  "23:43:27  el 92 % de su voz, hablando bajito"),
    (0.0219, 0.0182, True,  "23:44:36  el 120 % de su voz"),
    (0.0287, 0.0226, True,  "23:44:56  el 127 % de su voz, y a un pelo del liston viejo"),
    (0.0237, 0.0184, True,  "17:07:06  el 129 % de su voz"),
    (0.0186, 0.0976, False, "23:42:21  el 19 % de su voz: eso NO es el llamando"),
    (0.0116, 0.0341, False, "17:11:43  el 34 % de su voz: ruido"),
]
for rafaga, p90, debe, por_que in CASOS:
    pasa = rafaga >= umbral(p90)
    comp(("pasa: " if debe else "se tira: ") + por_que, pasa == debe,
         "rafaga %.4f contra liston %.4f" % (rafaga, umbral(p90)))

print("")
print("-- y lo que hoy activa tiene que seguir activando --")
# las cinco activaciones buenas del log, con su p90
BUENAS = [(0.0620, 0.0681), (0.0420, 0.0641), (0.0530, 0.0641), (0.0350, 0.0229), (0.0760, 0.0851), (0.0410, 0.0255)]
perdidas = [(r, p) for r, p in BUENAS if r < umbral(p)]
comp("ninguna de las que activan se pierde", not perdidas, "%d perdidas de %d" % (len(perdidas), len(BUENAS)))

print("")
print("-- y el codigo usa la funcion, no el numero pelado --")
comp("la comparacion de la activacion usa umbral_rafaga()", "if pico_rafaga >= umbral_rafaga():" in src)
comp("la del dictado tambien", "elif pico_rafaga < umbral_rafaga():" in src)
comp("y el log apunta el liston que se aplico", src.count("umbral_rafaga()))") >= 2)
# SIN ESTO EL ARREGLO NO HARIA NADA Y EN SILENCIO: si nadie actualiza ultimo_p90, la
# funcion devuelve siempre el techo y todo se queda como estaba
comp("el p90 vivo se actualiza en el pulso", "ultimo_p90 = ref" in src)

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  el liston de la rafaga se adapta a su voz, y lo que ya se oia se sigue oyendo")
sys.exit(0)
