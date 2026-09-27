# -*- coding: utf-8 -*-
"""LA REGLA VALE TAMBIEN PARA LO QUE YA ESTABA (26/09, idea 31 de las 121).

EL 19/09 se escribio un filtro: lo que habla de Nova no entra en el cerebro, porque el cerebro
es la memoria de BRAYA, no el diario de Nova. Pero ese filtro solo mira lo que LLEGA.

MEDIDO sobre memoria/cerebro/cerebro.json: de los 121 recuerdos, TREINTA Y SEIS hablan de Nova
-el 29,75 %-, y los 36 estan en estado "firme", o sea que entran en las busquedas y viajan en
el contexto de todas las charlas. Son todos del 15/09 (20) y del 18/09 (16): cero del 19/09 en
adelante, que es justo cuando se escribio el filtro. Una regla que solo mira lo que entra deja
armado para siempre lo que entro antes de escribirla.

Es el mismo agujero que repasar_estilo arreglo para el estilo, y se arregla igual.

LO QUE ESTE BANCO VIGILA MAS QUE NADA:
  1. Que NO se borre nada. Se marcan como "rechazada", que es reversible.
  2. Que el filtro mire SOLO el campo "respuesta" y SOLO los tipos contado y episodio. Con
     "pregunta" o "variantes" dentro, el "oye nova" de "oye nova, quien pinto la mona lisa"
     tacharia un recuerdo bueno.
  3. Que el disyuntor pare la mano si el filtro se come mas de la mitad de la memoria.

    python tools/probar-recuerdos-repasados.py
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
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


try:
    import charla_memoria as cm
except Exception as e:      # noqa: BLE001
    print("  MAL  no puedo importar charla_memoria: %s" % e)
    sys.exit(1)


def cerebro_con(recuerdos):
    """Un cerebro de mentira en una carpeta temporal, con la clase DE VERDAD."""
    base = tempfile.mkdtemp(prefix="rec31-")
    d = {"recuerdos": [], "estilo": [], "temas": {}, "proximo": 1}
    for i, r in enumerate(recuerdos, 1):
        preg = r.get("pregunta")
        if preg is None:
            preg = r.get("respuesta", "")
        fila = {"id": i, "tipo": r.get("tipo", "episodio"), "pregunta": preg,
                "respuesta": r.get("respuesta", ""), "estado": r.get("estado", "firme"),
                "origen": "charla", "creada": 1790000000, "usada": 1790000000, "usos": 0}
        if "variantes" in r:
            fila["variantes"] = r["variantes"]
        d["recuerdos"].append(fila)
    d["proximo"] = len(recuerdos) + 1
    with io.open(os.path.join(base, "cerebro.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps(d, ensure_ascii=False))
    return base


print("")
print("-- 1. la regla vive en UN solo sitio --")
comp("existe texto_no_entra a nivel de modulo", hasattr(cm, "texto_no_entra"))
if hasattr(cm, "texto_no_entra"):
    f = cm.texto_no_entra
    comp("  lo que habla de Nova no entra", f("Braya se queja de que Nova repite mucho") is True)
    comp("  lo corto tampoco", f("ok") is True)
    comp("  ni lo vacio", f("") is True)
    comp("  pero lo de braya si", f("A braya le gusta la musica electronica de los noventa") is False)
# Y guardar_texto USA esa funcion, no una copia suya: si no, las dos se separan.
src = io.open(os.path.join(RAIZ, "charla_memoria.py"), encoding="utf-8").read()
i_g = src.find("def guardar_texto")
i_fin = src.find("def aprender_turno", i_g if i_g >= 0 else 0)
cuerpo_g = src[i_g:i_fin] if i_g >= 0 and i_fin > i_g else ""
comp("guardar_texto usa la MISMA funcion", "texto_no_entra(" in cuerpo_g)
comp("  y ya no lleva la regla escrita dentro", "RE_SOBRE_NOVA" not in cuerpo_g,
     "dos copias de la misma regla acaban separandose")

print("")
print("-- 2. los que hablan de Nova quedan apartados al cargar --")
base = cerebro_con([
    {"tipo": "episodio", "respuesta": "Braya se queja de que Nova repite mucho las respuestas"},
    {"tipo": "episodio", "respuesta": "Nova no encontro el dato del oso polar que braya pidio"},
    {"tipo": "episodio", "respuesta": "A braya le gusta la musica electronica de los noventa"},
    {"tipo": "contado", "respuesta": "Braya trabaja de noche y juega por la tarde"},
    # EL QUE BRAYA PREGUNTO DICIENDO 'oye nova': la respuesta es limpia y se queda. Pregunta y
    # variantes guardan la frase LITERAL de braya, y ahi el nombre sale a todas horas.
    {"tipo": "episodio", "pregunta": "oye nova apunta que me gusta el ajedrez",
     "respuesta": "A braya le gusta jugar al ajedrez por las noches"},
    # EL DE TIPO RESPUESTA, hablando de Nova en la RESPUESTA: tampoco se toca. Ese tipo nunca
    # paso por este filtro y no tiene que pasar ahora.
    {"tipo": "respuesta", "pregunta": "quien eres",
     "respuesta": "Soy Nova, el asistente de braya"},
])
try:
    c = cm.Cerebro(base)
    R = c.datos["recuerdos"]
    apartados = [r for r in R if r.get("estado") == "rechazada"]
    comp("los dos que hablan de Nova se apartan", len(apartados) == 2, "%d" % len(apartados))
    comp("  y el contador lo dice", c.recuerdos_fuera == 2, "%s" % c.recuerdos_fuera)
    comp("  y llevan la fecha del repaso", all(r.get("repasado") for r in apartados))
    # NO SE BORRA NADA: la lista sigue entera y se pueden recuperar.
    comp("NO se borra ni uno", len(R) == 6, "%d de 6" % len(R))
    limpios = [r for r in R if r.get("estado") != "rechazada"]
    comp("  y los cuatro limpios siguen firmes", len(limpios) == 4, "%d" % len(limpios))
    # EL DE TIPO 'respuesta' NO SE TOCA, aunque su pregunta diga 'nova'.
    resp = [r for r in R if r.get("tipo") == "respuesta"][0]
    comp("  el de tipo respuesta, intacto", resp.get("estado") != "rechazada",
         "ese tipo nunca paso por este filtro, aunque su respuesta diga Nova")
    preg = [r for r in R if "ajedrez" in (r.get("respuesta") or "")][0]
    comp("  y el que preguntaste diciendo 'oye nova', tambien", preg.get("estado") != "rechazada",
         "se mira la RESPUESTA, no la frase literal que dijo braya")
finally:
    shutil.rmtree(base, ignore_errors=True)

print("")
print("-- 3. y buscar() deja de encontrarlos, que es para lo que se hace --")
# HACEN FALTA VARIOS DE RELLENO: la puntuacion lexica pesa las palabras por lo raras que son, y
# con dos recuerdos TODAS las palabras salen en la mitad del corpus y no distinguen nada. Con
# nueve, "trombon" y "acuarela" pesan lo que tienen que pesar.
relleno = [
    {"tipo": "episodio", "respuesta": "A braya le gusta la musica electronica de los noventa"},
    {"tipo": "episodio", "respuesta": "Braya toca el trombon los domingos por la manana"},
    {"tipo": "contado", "respuesta": "Braya pinta acuarelas cuando llueve mucho"},
    {"tipo": "contado", "respuesta": "Braya prefiere el cafe sin azucar y muy cargado"},
    {"tipo": "episodio", "respuesta": "Braya vio una pelicula de submarinos el sabado"},
    {"tipo": "episodio", "respuesta": "Braya cultiva tomates en el balcon del piso"},
    {"tipo": "contado", "respuesta": "Braya corre cinco kilometros los martes por la tarde"},
]
base = cerebro_con([{"tipo": "episodio", "respuesta": "Nova confundio el trombon con una trompeta al buscarlo"}] + relleno)
try:
    c = cm.Cerebro(base)
    comp("se aparta el que habla de Nova", c.recuerdos_fuera == 1, "%s" % c.recuerdos_fuera)
    hits = c.buscar("trombon trompeta confundio", k=5)
    salio = any("confundio el trombon" in (h["r"].get("respuesta") or "") for h in hits)
    comp("el apartado ya no sale en las busquedas", not salio, "%d resultados" % len(hits))
    # PERO SE PUEDE RECUPERAR: no esta borrado, esta apartado.
    hits2 = c.buscar("trombon trompeta confundio", k=5, con_rechazadas=True)
    salio2 = any("confundio el trombon" in (h["r"].get("respuesta") or "") for h in hits2)
    comp("  pero sigue ahi si se pregunta por el", salio2, "apartado no es borrado")
    # Y EL DEL TROMBON LIMPIO SIGUE SALIENDO: no se ha llevado por delante a su vecino.
    hits3 = c.buscar("trombon domingos", k=5)
    comp("  y el recuerdo limpio del trombon sigue saliendo",
         any("toca el trombon" in (h["r"].get("respuesta") or "") for h in hits3), "%d resultados" % len(hits3))
finally:
    shutil.rmtree(base, ignore_errors=True)

print("")
print("-- 4. EL DISYUNTOR: si se come mas de la mitad, no toca nada --")
# ESTA ES LA COMPROBACION QUE IMPIDE EL DESTROZO. Si un dia alguien ensancha el filtro y se
# lleva por delante la memoria entera, Nova no la toca y lo dice.
muchos = [{"tipo": "episodio", "respuesta": "Nova hizo algo raro numero %d de la lista" % i} for i in range(8)]
muchos += [{"tipo": "episodio", "respuesta": "A braya le gusta el cafe muy cargado"}]
base = cerebro_con(muchos)
try:
    c = cm.Cerebro(base)
    apartados = [r for r in c.datos["recuerdos"] if r.get("estado") == "rechazada"]
    comp("con 8 de 9 fuera, NO aparta ninguno", len(apartados) == 0, "%d apartados" % len(apartados))
    comp("  y lo dice con un numero negativo", c.recuerdos_fuera == -8, "%s" % c.recuerdos_fuera)
    comp("  que es la regla 2: el modo que no actua tiene que decirlo", c.recuerdos_fuera < 0)
finally:
    shutil.rmtree(base, ignore_errors=True)
# Y JUSTO POR DEBAJO DE LA MITAD, SI ACTUA.
mitad = [{"tipo": "episodio", "respuesta": "Nova hizo algo raro numero %d aqui" % i} for i in range(4)]
mitad += [{"tipo": "episodio", "respuesta": "A braya le gusta el cafe cargado numero %d" % i} for i in range(5)]
base = cerebro_con(mitad)
try:
    c = cm.Cerebro(base)
    comp("con 4 de 9, si aparta", c.recuerdos_fuera == 4, "%s" % c.recuerdos_fuera)
finally:
    shutil.rmtree(base, ignore_errors=True)

print("")
print("-- 5. el numero sale del archivo, no escrito aqui --")
comp("existe TOPE_REPASO_RECUERDOS", hasattr(cm, "TOPE_REPASO_RECUERDOS"))
if hasattr(cm, "TOPE_REPASO_RECUERDOS"):
    comp("  y esta muy por encima de lo medido", cm.TOPE_REPASO_RECUERDOS >= 0.45,
         "%.2f; hoy caen el 0,31 de los candidatos" % cm.TOPE_REPASO_RECUERDOS)
    comp("  y por debajo de uno, o no frenaria nada", cm.TOPE_REPASO_RECUERDOS < 1.0)

print("")
print("-- 6. contra el cerebro de verdad --")
# SOBRE UNA COPIA: el original no se toca.
orig = os.path.join(RAIZ, "memoria", "cerebro", "cerebro.json")
if not os.path.exists(orig):
    print("       NO hay cerebro.json: este caso NO se ha comprobado")
    comp("hay un cerebro con el que medir", False, "sin el no se puede decir nada")
else:
    base = tempfile.mkdtemp(prefix="rec31real-")
    try:
        shutil.copyfile(orig, os.path.join(base, "cerebro.json"))
        antes = json.load(io.open(orig, encoding="utf-8"))
        c = cm.Cerebro(base)
        R = c.datos["recuerdos"]
        print("       %d recuerdos; el repaso aparta %d" % (len(R), c.recuerdos_fuera))
        comp("en tu cerebro de verdad, aparta unos cuantos", c.recuerdos_fuera > 0,
             "medidos 36 de 121 el 26/09")
        comp("  y no borra ni uno", len(R) == len(antes.get("recuerdos") or []),
             "%d antes, %d despues" % (len(antes.get("recuerdos") or []), len(R)))
        comp("  y se queda muy por debajo del disyuntor", c.recuerdos_fuera > 0,
             "si saltara, saldria negativo")
        # EL ORIGINAL NO SE TOCA: esto es un banco, no una migracion.
        despues = json.load(io.open(orig, encoding="utf-8"))
        comp("  y el cerebro de verdad sigue como estaba",
             json.dumps(antes, sort_keys=True) == json.dumps(despues, sort_keys=True),
             "el banco trabaja sobre una copia")
    finally:
        shutil.rmtree(base, ignore_errors=True)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  la regla vale tambien para lo que ya estaba")
sys.exit(0)
