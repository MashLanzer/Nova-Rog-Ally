# -*- coding: utf-8 -*-
"""POR QUE IMPORTA UN TURNO DE CHARLA (27/09, idea 117 de las 121)

EL AGUJERO: memoria\\cerebro\\importante.jsonl lo escribe el worker en modo 'a' y su propio
comentario dice que "NO se poda nunca". No lo leia nadie. Y al abrirlo, la sorpresa: cinco lineas,
las cinco con por='correccion', y ninguna es una correccion. Son frases que el oido entendio mal en
mitad de una charla, y entran porque empiezan por "no" y tienen cinco palabras o mas.

ESTE BANCO EJECUTA por_que_importa DEL FICHERO DE VERDAD. La primera version estaba en el banco de
PowerShell y replicaba el orden de los 'if' a mano: los patrones si los sacaba del .py, pero el
ORDEN lo tenia escrito, asi que mover un 'if' en el worker no lo ponia rojo. Doblar la pieza que se
prueba es la manera 15 de salir verde mintiendo. Aqui se saca la funcion entera y se ejecuta.

LO QUE PROTEGE:
  1. que las cinco lineas reales se etiqueten bien
  2. que una correccion explicita gane, aunque Nova no entendiera del todo
  3. que "no, no, no, no, no" no sea una correccion
  4. que los agujeros sigan siendo agujeros
  5. y que el ORDEN de los cuatro 'if' sea el que es, ejecutandolo
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, "charla_worker.py")
mal = 0


def comp(que, ok, detalle=""):
    global mal
    if ok:
        print("  ok   %s%s" % (que, ("  (%s)" % detalle) if detalle else ""))
    else:
        print("  MAL  %s%s" % (que, ("  (%s)" % detalle) if detalle else ""))
        mal += 1


src = io.open(FUENTE, encoding="utf-8").read()

# LA FUNCION DE VERDAD, sacada del fichero: los cuatro patrones, la constante y el cuerpo entero de
# por_que_importa. Nada de reescribir la cuenta aqui.
ns = {"re": re}
for nom in ("RE_CORRIGE", "RE_AGUJERO", "RE_NO_ENTENDI", "RE_NEGACION", "NEGACION_PALABRAS"):
    m = re.search(r"^" + nom + r"\s*=\s*(.+?)(?=\n[A-Z_]+\s*=|\n\n|\ndef )", src, re.S | re.M)
    if not m:
        comp("falta %s en charla_worker.py" % nom, False)
        sys.exit(1)
    exec(nom + " = " + m.group(1).strip(), ns)
comp("los cuatro patrones salen del fichero real", True,
     "negacion: %d palabras" % ns["NEGACION_PALABRAS"])

m = re.search(r"^def por_que_importa\(texto, respuesta\):\n(?:.*\n)*?(?=^def |\Z)", src, re.M)
if not m:
    comp("no encuentro por_que_importa en charla_worker.py", False)
    sys.exit(1)
cuerpo = m.group(0)


# el worker usa salida() dentro del except; aqui un doble que no estorba
def salida(*_a, **_k):
    pass


ns["salida"] = salida
exec(cuerpo, ns)
por_que_importa = ns["por_que_importa"]
comp("por_que_importa se ejecuta de verdad, no una copia", callable(por_que_importa),
     "%d lineas sacadas por texto" % len(cuerpo.splitlines()))

print("")
print("-- 1. LAS CINCO LINEAS DE VERDAD, COPIADAS DE importante.jsonl --")
reales = [
    ("No hay nada mas, eh? Mira yo",
     "Vale, estoy aqui. Que me miras?"),
    ("No, yo subi, pero ten cuidado cuando suba, Es tipo ese de arriba, Es que.., Es que nunca atras",
     "Vale, te sigo a medias pero me pierdo un poco. Me lo explicas con mas claridad?"),
    ("No, porque se destilada la camera con anadir con la contable",
     "Ey, creo que no te he entendido bien. Me repites eso?"),
    ("No lo es, Es mas enterada, Es de aca, Encerno? Hasta que es cheap media",
     "Vale, la verdad es que no te sigo. Puedes empezar desde el principio?"),
    ("No, no, no, no, no, no, no",
     "Que pasa? Algo te molesta o acabas de meter la pata en el juego?"),
]
sale = [por_que_importa(t, r) for t, r in reales]
comp("1a. cuatro de las cinco son 'no te entendi'", sale.count("no-entendi") == 4,
     "%d de 5: %s" % (sale.count("no-entendi"), ", ".join(sale)))
comp("1b. la del 'no, no, no' no es una correccion", sale[4] == "no-entendi",
     "sin dos palabras distintas no hay frase")
comp("1c. y antes las cinco eran 'correccion'", sale.count("correccion") < 5,
     "asi es como agujeros.json se quedaba sin nacer")
comp("1d. ninguna se pierde: todas tienen motivo", all(sale), "el fichero no pierde ni una linea")

print("")
print("-- 2. UNA CORRECCION DE VERDAD SIGUE SIENDO UNA CORRECCION --")
# las del comentario del propio worker, medidas sobre el log escrito
buenas = [
    "No, no te pedi la hora, dije si es Steam",
    "No, no es buscarlo en Google, es poner la mitad de una pantalla en Pinterest",
    "No lo estas haciendo bien, estas hablandolo en el mismo navegador",
    "No, no, tu muevete a la derecha",
]
fallan = [b for b in buenas if por_que_importa(b, "Vale, ya lo tengo.") != "correccion"]
comp("2a. las cuatro correcciones reales se guardan como tal", not fallan,
     "las cuatro" if not fallan else " | ".join(fallan))
comp("2b. 'no te dije eso' lo es aunque no la entendiera",
     por_que_importa("No, no te dije eso, te dije que abrieras Steam",
                     "Creo que no te he entendido bien.") == "correccion",
     "dice QUE estaba mal, y eso se aprende")

print("")
print("-- 3. LOS AGUJEROS SIGUEN SIENDO AGUJEROS --")
comp("3a. 'no lo se' es un agujero",
     por_que_importa("que hora es", "No lo se, no tengo acceso a la hora de tu consola.") == "agujero")
comp("3b. 'no tengo acceso' tambien",
     por_que_importa("mira el clima", "No tengo acceso a esa informacion.") == "agujero")
comp("3c. y un turno normal no es nada",
     por_que_importa("pon musica", "Ya esta sonando.") == "", "no se guarda")

print("")
print("-- 4. EL ORDEN DE LOS CUATRO 'if', EJECUTANDOLO --")
# Cada caso esta hecho para que DOS reglas casen a la vez y se vea cual gana.
comp("4a. correccion explicita gana a no-entendi",
     por_que_importa("No te dije eso", "no te he entendido bien") == "correccion",
     "la explicita dice QUE estaba mal")
comp("4b. no-entendi gana a la negacion larga",
     por_que_importa("No, porque se destilada la camera con anadir", "no te sigo") == "no-entendi",
     "era la que se comia las cinco")
comp("4c. no-entendi gana al agujero",
     por_que_importa("cualquier cosa", "no te he entendido y no lo se") == "no-entendi",
     "si no entendio la frase, el agujero no se sabe")
comp("4d. la negacion larga gana al agujero",
     por_que_importa("No, eso no es lo que queria decirte", "no lo se") == "correccion")
comp("4e. y el 'no' corto no es nada",
     por_que_importa("No", "Vale.") == "", "hacen falta cinco palabras")
comp("4f. ni el 'no, gracias'", por_que_importa("No, gracias", "Vale.") == "")

print("")
print("-- 5. LO QUE ESTO NO TOCA --")
comp("5a. el turno se sigue guardando con su motivo",
     "apuntar_importante(texto, respuesta, por_que_importa" in src,
     "el fichero no pierde ni una linea")
comp("5b. y se abre para ANADIR, no para machacar",
     re.search(r'"importante\.jsonl"\), "a"', src) is not None,
     'con "w" se perderia todo en cada turno')
comp("5c. el except sigue diciendo que no pudo decidir",
     "no pude decidir si este turno importa" in src,
     "devolver '' callado seria la manera 10 de mentir")
# LO QUE NO SE HACE: meter las correcciones en el prompt de la charla
sin_com = "\n".join(l for l in src.splitlines() if not l.lstrip().startswith("#"))
comp("5d. las correcciones NO van al prompt",
     not re.search(r"(?i)(ya te lo corrigio|esto ya te lo corrig)", sin_com),
     "cinco de cinco eran ruido: primero que haya correcciones")

print("")
if mal:
    print("%d MAL" % mal)
    sys.exit(1)
print("por_que_importa etiqueta los tres casos, y el orden es el que es")
sys.exit(0)
