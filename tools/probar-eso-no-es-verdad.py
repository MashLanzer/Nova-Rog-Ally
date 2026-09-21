# -*- coding: utf-8 -*-
# "ESO NO ES VERDAD" RECHAZABA EL RECUERDO EQUIVOCADO (21/09), de la tanda de agentes.
#
# marcar_incorrecta() no recibia ningun id: usaba self.ultimo_id, que es estado global.
# Y ese campo lo escribe TAMBIEN guardar_respuesta desde aplicar_revision, o sea desde el
# HILO DEL REVISOR, de fondo y entre turnos.
#
# El caso: braya pregunta "quien hizo Hollow Knight", Nova contesta y se guarda. Mientras
# el escucha la respuesta, el revisor termina un pendiente viejo por detras y ultimo_id
# pasa a ser otro recuerdo cualquiera. braya dice "no, eso no es verdad" y lo que se marca
# como falso es ESE OTRO. Dos errores de un golpe: el malo se queda firme y uno bueno se
# rechaza. Y ninguno de los dos se ve hasta mucho despues.
#
# Lo que se prueba aqui es justo esa carrera, porque es la unica forma de que no vuelva.
import io
import os
import sys
import json
import tempfile
import shutil

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)

fallos = []


def comp(etiqueta, ok, detalle=""):
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos.append(etiqueta)


import charla_memoria as cm  # noqa: E402

base = tempfile.mkdtemp(prefix="esonoesverdad-")
try:
    c = cm.Cerebro(base)

    print("")
    print("-- el caso de verdad: el revisor pisa por detras entre turnos --")
    # EL ORDEN IMPORTA Y ME COSTO UN ROJO: primero lo de ANTES, y lo ultimo que Nova
    # dice tiene que ser lo ultimo que se guarda. Al reves, ultimo_id ya estaba mal antes
    # de que el revisor entrara y la prueba acusaba a quien no era.
    otro = c.guardar_respuesta("cual es la distancia de la tierra al sol", "150 millones de km", "firme", "api")
    comp("hay un recuerdo de antes", otro is not None and otro.get("id"))

    # y AHORA braya pregunta, y esto SI es lo ultimo que Nova dijo
    bueno = c.guardar_respuesta("quien hizo hollow knight", "Team Cherry", "firme", "api")
    idDicho = bueno["id"]
    comp("lo ultimo dicho es lo ultimo guardado", c.ultimo_id == idDicho)

    # AQUI ENTRA EL REVISOR, de fondo, mientras braya escucha la respuesta. Con el
    # 'recuerdo' apuntando a uno que ya no esta, que es cuando pasa por guardar_respuesta
    job = {"id": 1, "pregunta": "cual es la distancia de la tierra al sol",
           "respuesta": "150 millones de km", "origen": "api", "recuerdo": 999999, "intentos": 0}
    with c.lock:
        c.datos["pendientes"].append(job)
    c.aplicar_revision(job, {"tipo_turno": "pregunta_general", "caduca": False,
                             "pregunta_general": "A que distancia esta el Sol de la Tierra",
                             "respuesta_buena": "Unos 150 millones de kilometros"})
    comp("el revisor NO se lleva por delante 'lo ultimo dicho'", c.ultimo_id == idDicho,
         "ultimo_id=%s, deberia ser %s" % (c.ultimo_id, idDicho))

    # y ahora braya dice "no, eso no es verdad"
    mala = c.marcar_incorrecta(idDicho)
    comp("se rechaza el recuerdo que Nova dijo de verdad", mala is not None and mala["id"] == idDicho,
         "rechaza %s" % (mala and mala.get("id")))
    comp("y queda marcado como rechazado", mala and mala.get("estado") == "rechazada")
    otroAhora = c._por_id(otro["id"])
    comp("el otro recuerdo NO se toca", otroAhora and otroAhora.get("estado") != "rechazada",
         "esta como '%s'" % (otroAhora and otroAhora.get("estado")))

    print("")
    print("-- y el id explicito manda sobre el global, que es lo que se arreglo --")
    a = c.guardar_respuesta("cuantas lunas tiene marte", "dos", "firme", "api")
    b = c.guardar_respuesta("de que color es el cielo", "azul", "firme", "api")
    # ultimo_id apunta a 'b', pero lo que Nova dijo fue 'a'
    comp("el global apunta al ultimo guardado", c.ultimo_id == b["id"])
    m = c.marcar_incorrecta(a["id"])
    comp("con id explicito se rechaza ESE, no el del global", m and m["id"] == a["id"])
    comp("y el del global sigue entero", c._por_id(b["id"]).get("estado") != "rechazada")
    # sin id, se sigue usando el global (respaldo, para no romper a quien no lo pase)
    m2 = c.marcar_incorrecta()
    comp("sin id sigue valiendo el global, como respaldo", m2 and m2["id"] == b["id"])

    print("")
    print("-- lo que NO puede rechazarse --")
    c.ultimo_id = None
    comp("sin nada dicho, no rechaza nada", c.marcar_incorrecta() is None)
    comp("con un id que no existe, tampoco", c.marcar_incorrecta(999999) is None)
    # un apunte de texto no es una respuesta: no se puede marcar como falsa
    t = c.guardar_texto("estilo", "braya escribe en frases cortas")
    if t is not None:
        comp("un apunte de estilo no es una respuesta", c.marcar_incorrecta(t.get("id")) is None)

    print("")
    print("-- y el worker apunta lo que DIJO, no lo que guarde el revisor --")
    w = io.open(os.path.join(RAIZ, "charla_worker.py"), encoding="utf-8").read()
    comp("tiene su propia variable de lo ultimo dicho", "ultimo_dicho = None" in w)
    comp("y la declara global donde la escribe", "global ultima_charla, ultimo_dicho" in w)
    comp("se la pasa a marcar_incorrecta", "cerebro.marcar_incorrecta(ultimo_dicho)" in w)
    comp("la apunta al contestar de memoria", 'ultimo_dicho = sabida["id"]' in w)
    comp("y al aprender una respuesta nueva", 'ultimo_dicho = rAp["recuerdo"]' in w)
    mm = io.open(os.path.join(RAIZ, "charla_memoria.py"), encoding="utf-8").read()
    comp("el revisor guarda y devuelve el ultimo_id como estaba", "self.ultimo_id = prevUlt" in mm)
finally:
    shutil.rmtree(base, ignore_errors=True)

print("")
if fallos:
    print("  %d fallo(s)" % len(fallos))
    sys.exit(1)
print("  'eso no es verdad' rechaza lo que Nova dijo, no lo que el revisor guardo de fondo")
sys.exit(0)
