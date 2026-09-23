# -*- coding: utf-8 -*-
"""QUE LA CORRECCION VALGA TAMBIEN PARA LO YA GUARDADO (22/09, idea 5).

braya le pidio TRES veces que dejara de llamarle "tio" y "man" (20/09 23:05:26, 20/09
23:19:17, 21/09 00:02:56) y Nova prometio dos veces que no. Dos dias despues, el 22/09 a las
21:48:35: "No te sigo, tio". En cerebro.json habia 12 entradas de estilo y DOS decian lo
contrario de lo que el pidio: "prefiere tono casual y desenfadado (tuteo, 'man')" y "tono
informal y de confianza ('tio')". Las 12 viajan juntas en el prompt de TODAS sus charlas.

La regla que lo arregla -la ultima palabra sobre una palabra gana- se escribio ese mismo dia,
pero vive en _estilo, que solo corre cuando llega una entrada NUEVA. Lo que ya estaba en
disco no lo repasaba nadie.

Este banco usa la clase de verdad, no una copia: crea un cerebro en una carpeta temporal,
le escribe el caso real y comprueba que al cargar queda solo lo ultimo que dijo braya.
"""
import io
import json
import os
import shutil
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


try:
    import charla_memoria as cm
except Exception as e:      # noqa: BLE001
    print("  MAL  no puedo importar charla_memoria: %s" % e)
    sys.exit(1)

base = tempfile.mkdtemp(prefix="estilo-")
try:
    # EL CASO REAL, en el orden en que entro: primero las dos que le gustaban, luego sus
    # correcciones. Tal cual estaban en cerebro.json la noche del 22.
    guardado = {
        "version": 1, "siguiente": 1, "recuerdos": [], "temas": {}, "pendientes": [],
        "estilo": [
            "Prefiere tono casual y desenfadado (tuteo, 'man')",
            "Le gusta el tono informal y de confianza ('tio')",
            "Prefiere respuestas cortas",
            "No quiere que le llamen 'man'",
            "Pide que no le digan 'tio', no le gusta esa palabra",
        ],
    }
    ruta = os.path.join(base, "cerebro.json")
    with io.open(ruta, "w", encoding="utf-8") as f:
        json.dump(guardado, f, ensure_ascii=False)

    c = cm.Cerebro(base)
    est = c.datos.get("estilo", [])

    print("")
    print("-- lo que le dijo ultimo es lo que manda --")
    comp("el repaso tiro algo", getattr(c, "estilo_fuera", 0) > 0, "%d fuera" % getattr(c, "estilo_fuera", 0))
    junto = " | ".join(est)
    comp("ya no queda la que le gustaba el 'man'",
         not any("casual y desenfadado" in x for x in est), junto[:60])
    comp("ni la que le gustaba el 'tio'",
         not any("informal y de confianza" in x for x in est))
    comp("y SI queda su correccion del 'man'", any("No quiere que le llamen" in x for x in est))
    comp("y la del 'tio'", any("no le gusta esa palabra" in x for x in est))
    comp("y lo que no tiene nada que ver, intacto", any("respuestas cortas" in x for x in est))

    print("")
    print("-- y no se pierde nada al volver a cargar --")
    antes = list(est)
    c2 = cm.Cerebro(base)
    comp("cargar dos veces no cambia nada mas",
         list(c2.datos.get("estilo", [])) == antes or getattr(c2, "estilo_fuera", 0) == 0,
         "idempotente")

    print("")
    print("-- y sin contradicciones no tira nada --")
    base2 = tempfile.mkdtemp(prefix="estilo2-")
    try:
        with io.open(os.path.join(base2, "cerebro.json"), "w", encoding="utf-8") as f:
            json.dump({"version": 1, "siguiente": 1, "recuerdos": [], "temas": {}, "pendientes": [],
                       "estilo": ["Prefiere respuestas cortas", "Le gusta que le hablen de usted"]}, f,
                      ensure_ascii=False)
        c3 = cm.Cerebro(base2)
        comp("las dos siguen ahi", len(c3.datos.get("estilo", [])) == 2,
             "%d entradas" % len(c3.datos.get("estilo", [])))
        comp("y no dice que tiro nada", getattr(c3, "estilo_fuera", 0) == 0)
    finally:
        shutil.rmtree(base2, ignore_errors=True)
finally:
    shutil.rmtree(base, ignore_errors=True)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  lo que te corrige vale tambien para lo que ya estaba guardado")
sys.exit(0)
