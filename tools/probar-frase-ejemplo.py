# -*- coding: utf-8 -*-
"""EL OIDO LEE LA FRASE DE EJEMPLO EN VEZ DE TENERLA A FUEGO (27/09, idea 118 de las 121)

EL DATO: PROMPT_ORDENES era una constante escrita a mano el 14/09 -"Nova, abre Steam. Sube el
volumen. Pon el modo noche. Que hora es? Baja el brillo."- y llevaba 'sube', que es UNA orden real
en todo el historial, y no llevaba 'cierra', que son dieciocho y es el verbo que peor se oye: 21
veces salio como 'Tierra Steam', 'Sierra Gul', 'Si es Steam'.

LO QUE ESTE BANCO PROTEGE, y lo primero es lo que mas importa:
  1. que NUNCA se quede sin frase. Un oido sin ejemplo se va al ingles -medido el 14/09 con 100
     grabaciones: "Everything", "King is a Hollow Knight"-, asi que ningun camino puede devolver
     vacio. El respaldo es la constante medida, no una cadena en blanco.
  2. que una frase absurda -corta, larguisima- no se acepte
  3. que es_eco_del_ejemplo siga valiendo con la frase nueva, ejecutandola
  4. y que la constante de siempre siga ahi, intacta
"""
import io
import os
import re
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, "wake_vosk.py")
mal = 0


def comp(que, ok, detalle=""):
    global mal
    if ok:
        print("  ok   %s%s" % (que, ("  (%s)" % detalle) if detalle else ""))
    else:
        print("  MAL  %s%s" % (que, ("  (%s)" % detalle) if detalle else ""))
        mal += 1


src = io.open(FUENTE, encoding="utf-8").read()

# LA PIEZA DE VERDAD, sacada del fichero y ejecutada. El __file__ del namespace apunta a un sitio de
# mentira, que es lo que deja probar los cuatro caminos sin tocar el tmp de casa.
TMP = tempfile.mkdtemp(prefix="nova-frase-")
os.makedirs(os.path.join(TMP, "tmp"), exist_ok=True)
FALSO = os.path.join(TMP, "wake_vosk.py")
RUTA = os.path.join(TMP, "tmp", "prompt-ordenes.txt")

m = re.search(r"^PROMPT_ORDENES_POR_DEFECTO = .+?\n\n\ndef _leer_prompt_ordenes\(\):\n(?:.*\n)*?(?=\n\nPROMPT_ORDENES = )",
              src, re.M)
if not m:
    comp("encuentro el lector en wake_vosk.py", False, "cambio el nombre o la forma?")
    sys.exit(1)
ns = {"os": os, "__file__": FALSO}
exec(m.group(0), ns)
leer = ns["_leer_prompt_ordenes"]
PORDEF = ns["PROMPT_ORDENES_POR_DEFECTO"]
comp("el lector se ejecuta de verdad, no una copia", callable(leer),
     "%d lineas sacadas del fichero" % len(m.group(0).splitlines()))
comp("y la frase de siempre sigue ahi", "abre Steam" in PORDEF and len(PORDEF) > 60,
     "%d caracteres" % len(PORDEF))


def pon(txt):
    io.open(RUTA, "w", encoding="utf-8").write(txt)


def quita():
    if os.path.exists(RUTA):
        os.remove(RUTA)


print("")
print("-- 1. NUNCA SE QUEDA SIN FRASE --")
quita()
comp("1a. sin fichero, la de siempre", leer() == PORDEF, "un oido sin ejemplo se va al ingles")
pon("")
comp("1b. con el fichero vacio, la de siempre", leer() == PORDEF)
pon("   \n  \n")
comp("1c. con solo espacios, la de siempre", leer() == PORDEF)
pon("corta")
comp("1d. con una frase de 5 letras, la de siempre", leer() == PORDEF, "no empuja a nada")
pon("x" * 400)
comp("1e. con una de 400, la de siempre", leer() == PORDEF, "una frase larga arrastra")
# y la carpeta que no existe
os.rename(os.path.join(TMP, "tmp"), os.path.join(TMP, "tmp2"))
comp("1f. sin la carpeta tmp, la de siempre", leer() == PORDEF)
os.rename(os.path.join(TMP, "tmp2"), os.path.join(TMP, "tmp"))

print("")
print("-- 2. LA FRASE QUE NOVA ESCRIBE SI SE USA --")
nueva = "Nova, abre el navegador. Cierra la ventana. ¿Qué hora es? Mira el correo. Dime la hora."
pon(nueva)
comp("2a. se lee la de Nova", leer() == nueva, nueva)
comp("2b. y lleva 'Cierra'", "Cierra" in leer(), "18 usos reales, y 21 veces mal oido")
pon("  " + nueva + "  \n")
comp("2c. se le quitan los espacios de los lados", leer() == nueva, "un \\n al final no es la frase")
pon("Nova, abre el navegador. Cierra la ventana.")
comp("2d. una de 43 letras vale", leer().startswith("Nova, abre"), "el minimo son 20")

print("")
print("-- 3. es_eco_del_ejemplo SIGUE VALIENDO CON LA FRASE NUEVA --")
# Se ejecuta la funcion de verdad, con la frase nueva puesta. Es la guarda que detecta cuando
# Whisper devuelve el propio ejemplo en vez de lo que braya dijo, y hace que se pida confirmacion.
me = re.search(r"^def llano\(.*?\n(?:.*\n)*?(?=^def |\Z)", src, re.M)
mf = re.search(r"^def es_eco_del_ejemplo\(texto\):\n(?:.*\n)*?(?=^def |\Z)", src, re.M)
if not mf:
    comp("encuentro es_eco_del_ejemplo", False)
else:
    # llano() usa unicodedata para quitar los acentos; sin el, la funcion sacada del fichero peta
    import unicodedata
    ns2 = {"re": re, "unicodedata": unicodedata, "PROMPT_ORDENES": nueva}
    if me:
        exec(me.group(0), ns2)
    else:
        # llano no esta como def suelta; se busca donde este
        m2 = re.search(r"^def llano\b.*?\n(?:.*\n)*?(?=^\S)", src, re.M)
        if m2:
            exec(m2.group(0), ns2)
    exec(mf.group(0), ns2)
    eco = ns2["es_eco_del_ejemplo"]
    comp("3a. reconoce el ejemplo entero devuelto", bool(eco(nueva)), "Whisper a veces recita el prompt")
    comp("3b. y una frase suelta del ejemplo", bool(eco("Cierra la ventana")), "por eso parte por puntuacion")
    comp("3c. pero NO una orden de verdad", not eco("abre el steam ese"), "si no, no se ejecutaria nada")
    comp("3d. ni una que se parezca a medias", not eco("cierra la ventana del navegador"),
         "lleva mas de lo que hay en el ejemplo")

print("")
print("-- 4. LA CONSTANTE DE SIEMPRE SIGUE INTACTA --")
sin_com = "\n".join(l for l in src.splitlines() if not l.lstrip().startswith("#"))
comp("4a. PROMPT_ORDENES sigue existiendo", re.search(r"^PROMPT_ORDENES = _leer_prompt_ordenes\(\)", sin_com, re.M) is not None,
     "es lo que usa el resto del worker")
# SOBRE EL CUERPO DE LA FUNCION, no sobre el fichero: wake_vosk.py tiene muchos 'return ""'
# legitimos en otras funciones y el caso pasaba por uno de ellos.
cuerpo = os.linesep.join(l for l in m.group(0).splitlines() if not l.lstrip().startswith("#"))
comp("4b. y el respaldo es la frase medida, no ''",
     ("return PROMPT_ORDENES_POR_DEFECTO" in cuerpo)
     and ('return ""' not in cuerpo) and ("return " + chr(39) * 2 not in cuerpo),
     "devolver vacio dejaria al oido en ingles")
comp("4f. y son TRES caminos al respaldo", cuerpo.count("return PROMPT_ORDENES_POR_DEFECTO") >= 3,
     "sin fichero, frase absurda y averia")
comp("4c. se leen los dos limites", ("len(fr) < 20" in sin_com) and ("len(fr) > 300" in sin_com),
     "ni corta ni larguisima")
comp("4d. y el except tambien devuelve la de siempre",
     re.search(r"except Exception:.*\n\s*return PROMPT_ORDENES_POR_DEFECTO", sin_com) is not None,
     "un disco lleno no puede dejarla muda")
comp("4e. es_eco_del_ejemplo NO se ha tocado",
     "frases = {llano(f) for f in re.split(" in sin_com,
     "parte por puntuacion, asi que vale para cualquier frase")

import shutil

shutil.rmtree(TMP, ignore_errors=True)

print("")
if mal:
    print("%d MAL" % mal)
    sys.exit(1)
print("el oido lee su frase de ejemplo y nunca se queda sin ella")
sys.exit(0)
