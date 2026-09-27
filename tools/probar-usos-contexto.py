# -*- coding: utf-8 -*-
"""Contar como uso lo que de verdad usa el cerebro (27/09, idea 96 de las 121).

EL DATO, contado sobre memoria\\cerebro\\cerebro.json: de los 123 recuerdos, 122 tienen usos=0 y
uno tiene 1. Y no es que no se usen: el contador SOLO subia en respuesta_directa, que busca entre
los de tipo "respuesta", y de los 123 solo CUATRO lo son (113 episodios y 6 contados). Los otros
119 -los que entran a diario en el contexto de la charla- se quedaban a cero para siempre.

LO QUE SE GANA ES EL DATO, NO LA PODA, y la ficha lo tenia al reves: _podar ordena por (prioridad,
usos, usada), pero MAX_RECUERDOS son 5000 y hay 123, asi que hoy _podar NO se ejecuta nunca.

LO QUE ESTE BANCO PROTEGE:
  1. que suba el contador de los recuerdos que de VERDAD se escriben en el prompt
  2. que NO suba el de los que buscar devuelve pero no entran (seria inflar el numero)
  3. que una charla que no usa nada no mueva ningun contador
  4. que llegue al disco, que es donde no llegaba
  5. y que el contador viejo, el de respuesta_directa, siga funcionando igual

    python tools/probar-usos-contexto.py
"""
import io
import json
import os
import shutil
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)

# SE IMPORTA DE VERDAD: charla_memoria.py se puede importar (numpy y el modelo de significado son
# opcionales y la clase funciona sin ellos), asi que aqui no se copia ni se extrae nada: corre
# Cerebro.contexto entera.
import charla_memoria as cm  # noqa: E402

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det else ""))
    if not ok:
        fallos += 1


carpeta = tempfile.mkdtemp(prefix="nova-usos-")


def nuevo():
    """Un cerebro vacio en una carpeta temporal."""
    for f in os.listdir(carpeta):
        os.remove(os.path.join(carpeta, f))
    return cm.Cerebro(carpeta)


def usos_de(c, trozo):
    for r in c.datos["recuerdos"]:
        if trozo in (r.get("respuesta") or "") or trozo in (r.get("pregunta") or ""):
            return int(r.get("usos", 0))
    return None


try:
    print("")
    print("-- 1. LOS QUE ENTRAN EN EL PROMPT SUBEN --")
    c = nuevo()
    # EL CASO SALE DE PROBARLO, no de suponerlo: _vale_de_contexto exige lex >= 0.3 y _frecuencias
    # castiga las palabras que estan en TODOS los recuerdos, asi que con tres recuerdos del mismo
    # tema y nada mas el lex baja a 0,165 y NINGUNO entra. Hacen falta cuatro que compartan el tema
    # de la pregunta y dos que no. Asi buscar devuelve CUATRO y en el prompt entran TRES, que es
    # justo la diferencia que esta idea vigila.
    for t in ("el teclado mecanico azul se me quedo pequeno",
              "el teclado mecanico azul suena fuerte de noche",
              "el teclado mecanico azul lo quiero devolver",
              "el teclado mecanico azul tiene las teclas duras",
              "la bicicleta tiene la rueda pinchada",
              "quiero aprender a tocar la guitarra"):
        c.guardar_texto("episodio", t)
    comp("1a. nacen a cero", all(int(r.get("usos", 0)) == 0 for r in c.datos["recuerdos"]),
         str([r.get("usos") for r in c.datos["recuerdos"]]))
    txt = c.contexto("el teclado mecanico azul")
    comp("1b. el contexto trae algo", "teclado" in txt, "%d caracteres" % len(txt))
    subidos = [r for r in c.datos["recuerdos"] if int(r.get("usos", 0)) > 0]
    comp("1c. y los que entraron tienen uso", len(subidos) > 0, "%d de %d" % (len(subidos), len(c.datos["recuerdos"])))
    comp("1d. nunca mas de tres", len(subidos) <= 3, "%d; el prompt escribe hits[:3]" % len(subidos))
    # Y LA COMPROBACION QUE DE VERDAD SEPARA ESTA IDEA DE "subir usos a lo que buscar devuelva":
    # buscar encuentra cuatro y en el prompt caben tres, asi que uno de los cuatro NO puede subir.
    hits6 = c.buscar("el teclado mecanico azul", tipos={"respuesta", "contado", "episodio"}, k=6)
    comp("1d bis. buscar encuentra mas de los que entran", len(hits6) > len(subidos),
         "%d encontrados, %d en el prompt" % (len(hits6), len(subidos)))
    # y cuantos hay escritos en el texto: tienen que coincidir
    cuantas = len([l for l in txt.split(chr(10)) if l.startswith("- ")])
    comp("1e. tantos usos como lineas escritas", len(subidos) == cuantas,
         "%d subidos, %d lineas en el prompt" % (len(subidos), cuantas))

    print("")
    print("-- 2. Y VUELVE A SUBIR EN LA SIGUIENTE CHARLA --")
    antes = {r["id"]: int(r.get("usos", 0)) for r in c.datos["recuerdos"]}
    c.contexto("el teclado mecanico azul")
    despues = {r["id"]: int(r.get("usos", 0)) for r in c.datos["recuerdos"]}
    comp("2a. alguno sube otra vez", any(despues[k] > antes[k] for k in antes),
         str({k: (antes[k], despues[k]) for k in antes}))
    comp("2b. y ninguno baja", all(despues[k] >= antes[k] for k in antes))

    print("")
    print("-- 3. UNA CHARLA QUE NO USA NADA NO MUEVE NADA (la guarda de la ficha) --")
    c2 = nuevo()
    c2.guardar_texto("episodio", "el teclado mecanico azul se me quedo pequeno")
    c2.contexto("cuanto pesa la luna en kilos")
    comp("3a. sin nada que venga al caso, cero usos",
         all(int(r.get("usos", 0)) == 0 for r in c2.datos["recuerdos"]),
         str([r.get("usos") for r in c2.datos["recuerdos"]]))
    c3 = nuevo()
    comp("3b. y sin recuerdos no revienta", c3.contexto("hola que tal") == "" or True)

    print("")
    print("-- 4. LLEGA AL DISCO, QUE ES DONDE NO LLEGABA --")
    # El refresco de "usada" ya estaba aqui desde antes y solo se guardaba si algo DESPUES en el
    # mismo turno tocaba a guardar; aprender_turno se va sin guardar cuando el origen no es local
    # ni api. Asi que se comprueba releyendo el fichero, no la memoria.
    c4 = nuevo()
    for t in ("el teclado mecanico azul se me quedo pequeno",
              "el teclado mecanico azul suena fuerte de noche",
              "la bicicleta tiene la rueda pinchada"):
        c4.guardar_texto("episodio", t)
    c4.contexto("el teclado mecanico azul")
    crudo = json.load(io.open(os.path.join(carpeta, "cerebro.json"), encoding="utf-8"))
    enDisco = [int(r.get("usos", 0)) for r in crudo["recuerdos"]]
    comp("4a. el contador esta en el fichero", sum(enDisco) > 0, "usos en disco: %s" % enDisco)
    comp("4b. y coincide con lo que hay en memoria",
         sorted(enDisco) == sorted(int(r.get("usos", 0)) for r in c4.datos["recuerdos"]))
    # y una charla que no usa nada NO escribe (no se paga por nada)
    antesMod = os.path.getmtime(os.path.join(carpeta, "cerebro.json"))
    import time

    time.sleep(0.05)
    c4.contexto("cuanto pesa la luna en kilos")
    comp("4c. y si no se usa nada, no se escribe", os.path.getmtime(os.path.join(carpeta, "cerebro.json")) == antesMod,
         "guardar son 3,64 ms: no se pagan por nada")

    print("")
    print("-- 5. EL CONTADOR VIEJO SIGUE FUNCIONANDO --")
    c5 = nuevo()
    # NO PERSONAL Y QUE NO CADUQUE: respuesta_directa descarta de entrada lo que lleve "me
    # compre" (es_personal) o una fecha (caduca), y eso se lleva por delante la prueba entera.
    r = c5.guardar_respuesta("de que color es el cielo", "azul", "firme", "api")
    comp("5a. una respuesta guardada nace a cero", int(r.get("usos", 0)) == 0, str(r.get("usos")))
    d = c5.respuesta_directa("de que color es el cielo")
    comp("5b. contestarla directamente la cuenta", d is not None and int(d.get("usos", 0)) == 1,
         str(d.get("usos") if d else None))

    print("")
    print("-- 6. EL CABLEADO --")
    fuente = io.open(os.path.join(RAIZ, "charla_memoria.py"), encoding="utf-8").read()
    import ast

    arbol = ast.parse(fuente)
    ctx = None
    for n in ast.walk(arbol):
        if isinstance(n, ast.FunctionDef) and n.name == "contexto":
            ctx = ast.get_source_segment(fuente, n)
    comp("6a. se encuentra contexto", ctx is not None)
    comp("6b. el contador sube dentro del bucle de hits[:3]", "hits[:3]" in ctx and 'r["usos"]' in ctx,
         "no en los seis que devuelve buscar")
    comp("6c. y solo guarda si se uso algo", "if usados:" in ctx)
    comp("6d. la poda sigue mirando usos", "r.get(\"usos\", 0), r.get(\"usada\", 0)" in fuente,
         "hoy no corre -5000 de tope, 123 recuerdos-, pero el dia que corra ya no decide a ciegas")
finally:
    shutil.rmtree(carpeta, ignore_errors=True)

print("")
if fallos:
    print("  %d MAL" % fallos)
    sys.exit(1)
print("  se cuenta como uso lo que de verdad entra en el prompt")
sys.exit(0)
