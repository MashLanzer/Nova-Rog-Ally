# -*- coding: utf-8 -*-
"""JUGANDO, LAS MISMAS GUARDAS QUE SIN JUEGO (22/09 por la noche, idea 1 de la tercera tanda).

La rama que ignora la palabra de activacion con un juego delante era la PRIMERA de la cadena,
por delante de las guardas de altavoces, rafaga, confianza y juez. Medido sobre assistant.log:
con juego, 359 de 360 hipotesis del nombre entraban sin que nadie mirara NADA; sin juego, esas
mismas guardas tiran 156 de 540 (el 29 %). Y el ritmo lo confirma: 21,5 hipotesis por hora con
juego contra 4,1 sin juego, cinco veces mas.

Eso daba igual mientras la rama solo escribia una linea en el log. Desde el 22/09 por la noche
no: el asistente contesta a esa marca con una tarjeta y con un toque en el mando, asi que cada
cosa que dijera It Takes Two parecida a "nova" era una vibracion que braya no habia pedido.

Este banco lee el ARBOL del fichero (no su texto) y comprueba el orden de verdad de la cadena.
Lo comprueba asi porque aqui el orden ES el comportamiento: cambiarlo no rompe ninguna linea,
solo hace que la primera rama se coma los casos de las siguientes, en silencio.
"""
import ast
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(RAIZ, "wake_vosk.py")
fuente = io.open(RUTA, encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


def texto_cond(nodo):
    """La condicion tal cual, para poder nombrarla en el veredicto."""
    try:
        return ast.get_source_segment(fuente, nodo) or ""
    except Exception:       # noqa: BLE001
        return ""


# --- se busca LA cadena: la que tiene una rama con 'solo_boton' ---
arbol = ast.parse(fuente)
cadena = None
for nodo in ast.walk(arbol):
    if not isinstance(nodo, ast.If):
        continue
    condiciones, actual = [], nodo
    while True:
        condiciones.append(texto_cond(actual.test))
        if len(actual.orelse) == 1 and isinstance(actual.orelse[0], ast.If):
            actual = actual.orelse[0]
        else:
            break
    if any(c.strip() == "solo_boton" for c in condiciones) and len(condiciones) > 3:
        cadena = condiciones
        break

print("")
print("-- la cadena que decide si te ha oido --")
comp("la cadena existe y tiene varias ramas", cadena is not None and len(cadena) >= 5,
     ("%d ramas" % len(cadena)) if cadena else "no la encuentro")
if not cadena:
    print("  no se puede seguir sin la cadena")
    sys.exit(1)

pos = {}
for i, c in enumerate(cadena):
    c = c.strip()
    if c == "solo_boton":
        pos["juego"] = i
    elif "UMBRAL_ALTAVOZ_FUERTE" in c:
        pos["altavoces"] = i
    elif "umbral_rafaga()" in c:
        pos["rafaga"] = i
    elif "umbral_confianza" in c:
        pos["confianza"] = i
    elif "juez_deja_pasar" in c:
        pos["juez"] = i
    elif "ultima_marca" in c:
        pos["activar"] = i

for clave in ("juego", "altavoces", "rafaga", "confianza", "activar"):
    comp("esta la guarda de %s" % clave, clave in pos, "rama %s" % pos.get(clave, "?"))

print("")
print("-- y el juego va DESPUES de todas ellas --")
for clave in ("altavoces", "rafaga", "confianza"):
    if clave in pos and "juego" in pos:
        comp("los %s se miran antes que el juego" % clave, pos[clave] < pos["juego"],
             "%s en %d, juego en %d" % (clave, pos[clave], pos["juego"]))
if "juez" in pos and "juego" in pos:
    comp("y el juez tambien", pos["juez"] < pos["juego"])
if "activar" in pos and "juego" in pos:
    comp("pero el juego sigue ANTES de despertar", pos["juego"] < pos["activar"],
         "o jugando se activaria igual, que es lo que braya no quiere")

print("")
print("-- con su propio reloj, o volveria a ignorarte en silencio --")
# Los dos avisos compartian ultimo_aviso_solo_boton. Con la rama del juego la primera eso no
# molestaba (la de altavoces no se alcanzaba nunca jugando); detras de las guardas si se
# alcanza, y los altavoces del juego resetearian la ventana de 60 s todo el rato.
comp("el reloj del juego es una variable aparte", "ultimo_aviso_juego = 0.0" in fuente)
comp("y la rama del juego usa el suyo",
     bool(re.search(r"elif solo_boton:.{0,1800}?ultimo_aviso_juego = ahora", fuente, re.S)))
comp("la de los altavoces sigue con el de antes",
     bool(re.search(r"UMBRAL_ALTAVOZ_FUERTE.{0,400}?ultimo_aviso_solo_boton = ahora", fuente, re.S)))

print("")
print("-- y la linea deja los numeros, para poder repartir las 358 --")
comp("el aviso del juego apunta confianza, rafaga y altavoces",
     bool(re.search(r"solo vale el boton\"\s*\n\s*\" \(confianza %\.2f, rafaga %\.4f, altavoces %\.3f\)", fuente)),
     "sin esto no se sabe cuales eran de braya")
comp("y sigue dejando la marca para el asistente",
     bool(re.search(r"elif solo_boton:.{0,2200}?escribir\(MARCA_LLAMADA_JUEGO", fuente, re.S)))

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  jugando, tu nombre pasa por las mismas guardas que siempre")
sys.exit(0)
