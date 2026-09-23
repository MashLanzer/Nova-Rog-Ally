# -*- coding: utf-8 -*-
"""QUE LA VENTANA SE CIERRE CUANDO DEJAS DE HABLAR, NO A LOS 30 S (22/09, idea 2).

La ventana de dictado cierra cuando pasa SILENCIO_FIN sin que el pico de energia pase el
umbral. Con un juego sonando eso no llega nunca: las explosiones pasan el umbral igual que
una voz y rearman ultima_voz, asi que solo cierra el tope duro de 30 s. Medido la noche del
22: cinco seguimientos seguidos al tope (21:44:46, 21:45:27, 21:46:21, 21:47:12, 21:47:57);
de abrir el microfono a tener texto, 34, 33, 37, 32 y 40 segundos. 176 segundos para cinco
frases, y a Whisper le llegaban ~4 s de braya y ~11 del juego.

Este banco NO mira como esta escrito: saca la condicion del fichero de verdad, la compila, y
le pasa situaciones -la de esa noche entre ellas- para ver a que segundo habria cerrado.
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fuente = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


def num(nombre, por_defecto=None):
    m = re.search(r"(?m)^%s = ([0-9.]+)" % nombre, fuente)
    if m:
        return float(m.group(1))
    return por_defecto


SILENCIO_FIN = num("SILENCIO_FIN")
SIN_PALABRA = num("SILENCIO_SIN_PALABRA")
DICTADO_MAX = num("DICTADO_MAX")
UMBRAL_ALTAVOZ = num("UMBRAL_ALTAVOZ", 0.02)

print("")
print("-- los numeros salen del fichero, no de aqui --")
comp("SILENCIO_FIN existe", SILENCIO_FIN is not None, str(SILENCIO_FIN))
comp("SILENCIO_SIN_PALABRA existe", SIN_PALABRA is not None, str(SIN_PALABRA))
comp("y es mas del doble de su pausa mas larga (1,44 s)", SIN_PALABRA and SIN_PALABRA >= 2.9,
     "%.1f s" % (SIN_PALABRA or 0))
comp("y bastante menor que el tope duro", SIN_PALABRA and DICTADO_MAX and SIN_PALABRA < DICTADO_MAX / 3.0,
     "%.1f contra %.1f" % (SIN_PALABRA or 0, DICTADO_MAX or 0))

# --- la condicion de corte, sacada del fichero y compilada ---
m = re.search(r"_corta_juego = \((.*?)\)\n", fuente, re.S)
comp("la condicion nueva existe en el fichero", m is not None)
if not m:
    sys.exit(1)
expr = " ".join(m.group(1).split())
codigo = compile("(%s)" % expr, "<corta_juego>", "eval")


def cierra(t, hay_algo, altavoz, desde_palabra, desde_voz):
    """¿Cerraria en el segundo t? Devuelve el motivo, o None."""
    entorno = {
        "hay_algo": hay_algo,
        "nivel_salida": lambda: altavoz,
        "UMBRAL_ALTAVOZ": UMBRAL_ALTAVOZ,
        "ahora": t,
        "ultima_palabra": t - desde_palabra,
        "ultima_voz": t - desde_voz,
        "SILENCIO_SIN_PALABRA": SIN_PALABRA,
        "fin_silencio": SILENCIO_FIN,
    }
    if (desde_voz >= SILENCIO_FIN and hay_algo):
        return "silencio de siempre"
    if eval(codigo, {"__builtins__": {}}, entorno):
        return "sin palabras nuevas"
    if t >= DICTADO_MAX:
        return "tope duro"
    return None


print("")
print("-- la noche del 22: braya habla 4 s y el juego sigue sonando --")
# el juego mantiene la energia alta todo el rato (desde_voz siempre 0), y braya deja de
# hablar en el segundo 4: a partir de ahi no sale ni una palabra nueva.
motivo, cuando = None, None
for decima in range(0, 400):
    t = decima / 10.0
    desde_palabra = max(0.0, t - 4.0)
    motivo = cierra(t, True, 0.30, desde_palabra, 0.0)
    if motivo:
        cuando = t
        break
comp("cierra por no oir palabras nuevas", motivo == "sin palabras nuevas", str(motivo))
comp("y a los ~7 s, no a los 30", cuando is not None and cuando <= 8.0, "%.1f s" % (cuando or 0))
comp("gana mas de 20 segundos por frase", cuando is not None and (DICTADO_MAX - cuando) >= 20,
     "%.1f s menos" % (DICTADO_MAX - (cuando or 0)))

print("")
print("-- pero sin altavoces no cambia NADA --")
motivo2, cuando2 = None, None
for decima in range(0, 400):
    t = decima / 10.0
    # en silencio, la energia tambien cae cuando braya calla
    motivo2 = cierra(t, True, 0.0, max(0.0, t - 4.0), max(0.0, t - 4.0))
    if motivo2:
        cuando2 = t
        break
comp("cierra por el silencio de siempre", motivo2 == "silencio de siempre", str(motivo2))
comp("y en su momento de siempre", cuando2 is not None and abs(cuando2 - (4.0 + SILENCIO_FIN)) < 0.2,
     "%.1f s" % (cuando2 or 0))

print("")
print("-- y mientras hablas, no te corta --")
# braya habla sin parar con el juego de fondo: salen palabras nuevas todo el rato
corto = None
for decima in range(0, 200):
    t = decima / 10.0
    if cierra(t, True, 0.30, 0.3, 0.0):     # una palabra nueva cada 0,3 s
        corto = t
        break
comp("hablando seguido no cierra", corto is None, "llego a 20 s sin cortar")
# y con pausas normales dentro de una frase (1,44 s es su pausa mas larga medida)
corto2 = None
for decima in range(0, 200):
    t = decima / 10.0
    if cierra(t, True, 0.30, 1.44, 0.0):
        corto2 = t
        break
comp("ni con su pausa mas larga medida", corto2 is None, "1,44 s entre palabras")

print("")
print("-- y no se cuela sin texto ni sin altavoces --")
comp("sin nada dicho, esta rama no cierra", cierra(5.0, False, 0.30, 5.0, 0.0) is None or
     cierra(5.0, False, 0.30, 5.0, 0.0) == "tope duro", "hay_algo falso")
comp("con los altavoces callados, tampoco", cierra(5.0, True, 0.0, 5.0, 0.0) != "sin palabras nuevas")

print("")
print("-- y el cierre deja dicho por que --")
comp("lo anota con su motivo y sus numeros",
     bool(re.search(r"cerrado a %\.1f s: los altavoces sonaban", fuente)),
     "un truncado mudo no se puede medir")
comp("y la marca se reinicia en cada dictado",
     bool(re.search(r"ultima_palabra = ahora\s*\n\s*visto_dictado = \"\"", fuente)))

print("")
print("-- y de propina: el tope se mira ANTES de cargar el modelo --")
# A las 21:45:31 Nova cargo small durante 3,7 s y acto seguido dijo "30.0 s de audio es
# demasiado para repasar". El tope estaba despues de elegir modelo.
i_tope = fuente.find("if duracion > tope_repaso:")
i_carga = min([x for x in (fuente.find("m = modelo_ultimo()"), fuente.find("m = modelo_preciso()")) if x > 0] or [0])
comp("el tope se mira antes de cargar nada", i_tope > 0 and i_tope < i_carga,
     "tope en %d, carga en %d" % (i_tope, i_carga))
# Y NO con un return: al final de esa funcion se escribe el texto del repaso, se borra la
# marca REINTENTO y se vacia la cola. Saltarse eso deja al asistente esperando un repaso que
# no llega. Con m en None, el bloque de transcribir no entra y el resto sigue igual.
comp("y sin saltarse la limpieza del final",
     "return False" not in fuente[i_tope:i_tope + 500] and "m = None" in fuente[i_tope:i_tope + 500],
     "ni return ni break: solo m = None")

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  con el juego sonando, la ventana cierra cuando dejas de hablar")
sys.exit(0)
