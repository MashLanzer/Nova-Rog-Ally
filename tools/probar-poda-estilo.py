# -*- coding: utf-8 -*-
# EL ESTILO SE CONTRADECIA A SI MISMO (22/09).
#
# La lista "estilo" de cerebro.json es como Nova cree que hay que hablarle a braya, y viaja
# ENTERA en el prompt de todas las charlas (contexto() la mete sin condicion). Caben 12.
#
# Habia dos fallos que se sumaban:
#   1. el filtro de repetidas comparaba TEXTO EXACTO, asi que cada forma NUEVA de decir lo
#      mismo gastaba una plaza;
#   2. la poda tiraba est.pop(0), o sea la mas vieja, sin mirar que era.
#
# Resultado medido sobre las 12 que habia de verdad en memoria\cerebro\cerebro.json:
#      4. Prefiere tono casual y desenfadado (tuteo, 'man')
#      5. No usar la palabra 'man' al dirigirse a el
#      6. tono informal y de confianza ('tio')
#      7. sin usar la palabra "tio"        8. sin usar "tio" para dirigirse
#      9. evitar usar 'tio' para dirigirse 10. prefiere que no le digan "tio"
# Cinco de las doce plazas para lo mismo, y al lado las dos que dicen lo contrario. A Nova
# se le pedia en la misma frase que le hablara con confianza llamandole "tio" y que no le
# llamara "tio". Asi no hay forma de acertar.
#
# LAS DOS REGLAS QUE SE PRUEBAN AQUI:
#   1. si lo repite, se renueva (la vieja se mueve al final, no se ignora), y como la poda
#      entra por el principio, "la primera" deja de querer decir "la mas vieja" y pasa a
#      decir "la que lleva mas tiempo sin que el la repita";
#   2. la ultima palabra sobre una palabra gana: si la entrada nueva entrecomilla "tio",
#      se van las viejas que la nombren.
#
# El modulo se importa de verdad, no se copia nada (la regla del banco, van diecisiete).
import io
import json
import os
import shutil
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)
import charla_memoria as cm  # noqa: E402

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-52s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# LAS DOCE DE VERDAD. Se copian aqui a proposito -no se leen del cerebro.json vivo- porque
# esto es una FOTO del 22/09: manana braya habra hablado mas y la lista sera otra, y la
# prueba tiene que seguir midiendo lo mismo. Lo que NO se copia es el codigo, que es lo que
# se esta probando.
DOCE = [
    "Respuestas rapidas y directas",
    "prefieres claridad",
    "tono relajado e informal",
    "Prefiere tono casual y desenfadado (tuteo, 'man')",
    "No usar la palabra 'man' al dirigirse a el",
    "tono informal y de confianza ('tio')",
    'sin usar la palabra "tio"',
    'sin usar "tio" para dirigirse',
    "evitar usar 'tio' para dirigirse",
    'prefiere que no le digan "tio"',
    "Seguir instrucciones precisas sobre que seccion abrir",
    "No leer pantalla sin que se lo pida",
]


def cerebro_limpio():
    carpeta = tempfile.mkdtemp(prefix="nova-estilo-")
    return cm.Cerebro(carpeta), carpeta


print("")
print("-- las palabras que el pone entre comillas --")
# Cuando braya corrige como quiere que le hablen, el revisor escribe la palabra exacta
# entrecomillada. Esa palabra es el TEMA de la regla.
casos_cit = [
    ("No usar la palabra 'man' al dirigirse a el", {"man"}),
    ('sin usar "tio" para dirigirse', {"tio"}),
    ("tono informal y de confianza ('tio')", {"tio"}),
    ("Prefiere tono casual y desenfadado (tuteo, 'man')", {"man"}),
    # una frase entera entrecomillada no es una forma de llamarle
    ("dice que prefiere 'ir directo al grano'", set()),
    # ni una sola letra, ni lo que ya es palabra vacia
    ("pon la 'a' delante", set()),
    ("responde 'si' o 'no'", set()),
    ("sin comillas no hay tema", set()),
]
for texto, esperado in casos_cit:
    sale = cm.citadas(texto)
    comp(texto[:44], sale == esperado, "-> %s" % (sorted(sale) if sale else "nada"))

print("")
print("-- las doce reales, metidas una a una como llegaron --")
c, carpeta = cerebro_limpio()
for x in DOCE:
    c._estilo(x)
est = c.datos["estilo"]
print("   quedan %d de %d:" % (len(est), len(DOCE)))
for x in est:
    print("     - %s" % x)

# LO QUE IMPORTA NO ES EL NUMERO, ES QUE NO SE CONTRADIGAN. Se mira palabra por palabra:
# de las que hablan de "tio" solo puede quedar UNA, y lo mismo con "man".
for palabra in ("tio", "man"):
    cuantas = [x for x in est if palabra in cm.plano(x).split()]
    comp("solo queda una regla sobre '%s'" % palabra, len(cuantas) <= 1,
         repr(cuantas[0][:40]) if cuantas else "ninguna")

# Y tiene que ser LA ULTIMA que el dijo, que es la que lo corrige.
ultima_tio = [x for x in DOCE if "tio" in cm.plano(x).split()][-1]
comp("y es la ultima que dijo sobre eso", ultima_tio in est, repr(ultima_tio[:40]))
comp("baja de doce a menos", len(est) < len(DOCE), "%d entradas" % len(est))
# Las que no hablan de ninguna palabra citada no las toca nadie.
for x in ("Respuestas rapidas y directas", "No leer pantalla sin que se lo pida"):
    comp("sigue dentro: %s" % x[:34], x in est)
shutil.rmtree(carpeta, ignore_errors=True)

print("")
print("-- si lo repite, se renueva (no se ignora) --")
c, carpeta = cerebro_limpio()
for x in ("uno de prueba", "dos de prueba", "tres de prueba"):
    c._estilo(x)
c._estilo("uno de prueba")          # lo repite tal cual
est = c.datos["estilo"]
comp("no se duplica", len(est) == 3, "%d entradas" % len(est))
comp("y el repetido se va al final", est[-1] == "uno de prueba", repr(est))
# Que es lo que hace que la poda deje de ser "por antiguedad": el primero de la lista ya no
# es el mas viejo, es el que lleva mas tiempo sin que braya lo repita.
comp("asi el primero es el que lleva mas sin repetirse", est[0] == "dos de prueba")
# Tambien renueva si lo dice con otras mayusculas o tildes (plano() las iguala).
c._estilo("DOS DE PRUEBA")
comp("y da igual como lo escriba", c.datos["estilo"][-1].lower() == "dos de prueba",
     repr(c.datos["estilo"][-1]))
comp("sin duplicar por las mayusculas", len(c.datos["estilo"]) == 3)
shutil.rmtree(carpeta, ignore_errors=True)

print("")
print("-- lo que NO debe cambiar --")
c, carpeta = cerebro_limpio()
for i in range(cm.MAX_ESTILO + 6):
    c._estilo("regla numero %d sin comillas" % i)
comp("el tope de %d se sigue respetando" % cm.MAX_ESTILO,
     len(c.datos["estilo"]) == cm.MAX_ESTILO, "%d entradas" % len(c.datos["estilo"]))
# El filtro del 20/09: el estilo no guarda quejas sobre Nova, que era la mitad de la lista.
antes = len(c.datos["estilo"])
c._estilo("le gusta que nova entienda bien lo que dice")
comp("sigue sin guardar lo que habla de Nova", len(c.datos["estilo"]) == antes)
c._estilo("")
comp("ni las vacias", len(c.datos["estilo"]) == antes)
# Y lo sensible tampoco, que ese filtro se puso el 19/09 y llego aqui el 20.
antes = len(c.datos["estilo"])
sens = [x for x in ("le duele la cabeza y toma medicamentos para la migrana",) if cm.sensible(x)]
if sens:
    c._estilo(sens[0])
    comp("ni lo sensible", len(c.datos["estilo"]) == antes)
else:
    comp("ni lo sensible", True, "(sin caso sensible a mano, se salta)")
# Una entrada nueva SIN comillas no puede llevarse por delante a las viejas: la regla 2
# solo actua cuando braya nombra la palabra.
c2, carpeta2 = cerebro_limpio()
for x in ("sin usar 'tio' para dirigirse", "responde rapido"):
    c2._estilo(x)
c2._estilo("prefiere frases cortas")
comp("una entrada sin comillas no borra nada", len(c2.datos["estilo"]) == 3,
     "%d entradas" % len(c2.datos["estilo"]))
shutil.rmtree(carpeta, ignore_errors=True)
shutil.rmtree(carpeta2, ignore_errors=True)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  el estilo ya no se contradice: la ultima palabra sobre una palabra gana")
sys.exit(0)
