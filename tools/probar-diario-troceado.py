# -*- coding: utf-8 -*-
"""El resumen del dia se escribia con el final del dia (27/09, idea 105 de las 121).

EL DATO, contado sobre los turnos reales del registro: el 20/09 hubo 82 turnos y 16.098 caracteres
de conversacion, y al resumidor entraban los ONCE ultimos turnos -el 13 %- por el recorte [-2500:].
El 18/09, 33 de 89. El 15/09, 25 de 72. Y despues os.remove borraba el bruto entero: el resto del
dia no se perdia a medias, se perdia del todo.

Y EL DIARIO HABLABA DE NOVA: de las 38 vinetas escritas en memoria\\diario, DIECINUEVE -la mitad- la
nombran. El prompt pedia "de que hablaron braya y Nova", y eso es lo que salia.

LO QUE ESTE BANCO PROTEGE:
  1. que se corte por CONVERSACION (cinco minutos sin hablar), que es lo que hace que un dia
     partido en tres ratos no se resuma con el ultimo
  2. que si hay que dejar trozos fuera, se queden los MAS LARGOS y no los ultimos
  3. que se devuelvan en orden cronologico, para que el diario se lea de la manana a la noche
  4. que el prompt no pida hablar de Nova
  5. y que si una llamada falla, el bruto NO se borre

    python tools/probar-diario-troceado.py
"""
import ast
import io
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fuente = io.open(os.path.join(RAIZ, "charla_worker.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det else ""))
    if not ok:
        fallos += 1


# LAS PIEZAS PURAS, SACADAS DEL ARCHIVO. charla_worker.py se puede importar, pero arrastra httpx y
# medio mundo; aqui solo hacen falta las tres funciones puras y sus constantes.
QUIERO = {"minutos_de", "trocear_turnos", "trozos_que_valen", "RESUMEN_TROZO_CHARS",
          "RESUMEN_TROZOS_MAX", "RESUMEN_HUECO_MIN", "RESUMEN_VINETAS"}
trozos, vistos = [], set()
for n in arbol.body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in QUIERO:
        trozos.append(ast.get_source_segment(fuente, n))
        vistos.add(nombre)
comp("se saca del archivo lo que se prueba", vistos == QUIERO, "" if vistos == QUIERO else "falta %s" % (QUIERO - vistos))
if vistos != QUIERO:
    sys.exit(1)
ns = {}
exec(chr(10).join(trozos), ns)
minutos_de = ns["minutos_de"]
trocear = ns["trocear_turnos"]
valen = ns["trozos_que_valen"]

print("")
print("-- 1. LA HORA, QUE ES LO QUE PERMITE CORTAR --")
comp("1a. '14:07' son 847 minutos", minutos_de("14:07") == 847, str(minutos_de("14:07")))
comp("1b. '00:12' son 12", minutos_de("00:12") == 12)
comp("1c. y lo que no se entiende es None", minutos_de("nada") is None and minutos_de(None) is None,
     "no se cuando fue, no se inventa una hora")
comp("1d. ni con un formato raro revienta", minutos_de("14") is None and minutos_de("") is None)

print("")
print("-- 2. SE CORTA POR CONVERSACION (el nucleo de la idea) --")
# dos ratos separados por veinte minutos: dos conversaciones
t = [(10, "a" * 100), (12, "b" * 100), (32, "c" * 100), (33, "d" * 100)]
r = trocear(t)
comp("2a. dos ratos separados son dos trozos", len(r) == 2, "%s" % [len(x) for x in r])
comp("2b. con sus turnos cada uno", [len(x) for x in r] == [2, 2])
# el borde exacto del corte
comp("2c. a cuatro minutos sigue siendo la misma", len(trocear([(10, "a"), (14, "b")])) == 1, "el corte son 5")
comp("2d. a cinco ya son dos", len(trocear([(10, "a"), (15, "b")])) == 2)
# y sin hora no se parte por hueco
comp("2e. sin hora, no se parte por hueco", len(trocear([(None, "a"), (None, "b"), (None, "c")])) == 1,
     "no se sabe cuando fue: mejor un trozo que tres inventados")
comp("2f. una hora suelta entre dos sin hora no corta de mas", len(trocear([(None, "a"), (10, "b"), (None, "c")])) == 1)

print("")
print("-- 3. Y POR TAMANO, PARA QUE EL MODELO NO LO RECORTE OTRA VEZ --")
t2 = [(10, "x" * 2000), (11, "y" * 2000), (12, "z" * 2000)]
r2 = trocear(t2)
comp("3a. tres turnos de 2.000 no caben en uno", len(r2) == 3, "%s" % [sum(len(y) for y in x) for x in r2])
comp("3b. y ninguno pasa del tope", all(sum(len(y) for y in x) <= ns["RESUMEN_TROZO_CHARS"] for x in r2),
     "tope %d" % ns["RESUMEN_TROZO_CHARS"])
# un turno gigante solo no se puede partir, y va solo
r3 = trocear([(10, "z" * 9000), (11, "a")])
comp("3c. un turno mas grande que el tope va solo", len(r3) == 2 and len(r3[0]) == 1, "%s" % [len(x) for x in r3])
comp("3d. y no se pierde", sum(len(x) for x in r3) == 2)
comp("3e. el hueco manda sobre el tamano", len(trocear([(10, "a" * 100), (30, "b" * 100)])) == 2,
     "primero se pregunta si es otra conversacion")

print("")
print("-- 4. SI SOBRAN TROZOS, SE QUEDAN LOS MAS LARGOS (no los ultimos) --")
tr = [["a" * 10], ["b" * 5000], ["c" * 100], ["d" * 3000], ["e" * 1], ["f" * 20], ["g" * 40]]
q = valen(tr, 3)
comp("4a. se queda con tres", len(q) == 3, "%d" % len(q))
comp("4b. y son los tres mas largos", sorted(x[0][0] for x in q) == ["b", "c", "d"],
     "%s" % [x[0][0] for x in q])
comp("4c. EN ORDEN CRONOLOGICO", [x[0][0] for x in q] == ["b", "c", "d"],
     "el diario se lee de la manana a la noche")
comp("4d. y la ultima conversacion corta se queda fuera", "e" not in [x[0][0] for x in q],
     "eso es lo que antes era el resumen ENTERO del dia")
comp("4e. si caben todos, no se toca nada", valen(tr, 10) == tr)
comp("4f. y el tope de fabrica son seis", ns["RESUMEN_TROZOS_MAX"] == 6, str(ns["RESUMEN_TROZOS_MAX"]))

print("")
print("-- 5. EL CASO REAL DEL 20/09: 82 TURNOS Y 16.098 CARACTERES --")
# se reconstruye un dia como el 20/09: 82 turnos repartidos en varias horas
turnos = []
m = 8 * 60
for i in range(82):
    if i in (20, 45, 70):
        m += 90        # tres cortes de hora y media: cuatro conversaciones
    else:
        m += 2
    turnos.append((m, "braya: " + ("x" * 180) + chr(10) + "Nova: " + ("y" * 10)))
total = sum(len(t) for _, t in turnos)
piezas = valen(trocear(turnos))
entra = sum(sum(len(y) for y in x) for x in piezas)
comp("5a. el dia son ~16.000 caracteres", total > 15000, "%d" % total)
comp("5b. antes entraba solo el final", True, "2.500 de %d = %d %%" % (total, round(100.0 * 2500 / total)))
comp("5c. ahora entra mucho mas", entra > 2500 * 3, "%d caracteres, el %d %% del dia" % (entra, round(100.0 * entra / total)))
comp("5d. en como mucho seis llamadas", len(piezas) <= 6, "%d trozos" % len(piezas))
comp("5e. y ningun trozo pasa del contexto", all(sum(len(y) for y in x) <= ns["RESUMEN_TROZO_CHARS"] for x in piezas))

print("")
print("-- 6. EL PROMPT YA NO PIDE HABLAR DE NOVA --")
res = None
for n in ast.walk(arbol):
    if isinstance(n, ast.FunctionDef) and n.name == "resumir_dias_pasados":
        res = ast.get_source_segment(fuente, n)
comp("6a. se encuentra el resumidor", res is not None)
comp("6b. pide lo que le paso a BRAYA", "lo que le pasó o le interesó a BRAYA" in res)
comp("6c. y dice explicitamente que no hable de Nova", "No hables de Nova" in res,
     "19 de las 38 vinetas escritas la nombran")
comp("6d. ya no pide 'de que hablaron braya y Nova'", "de qué hablaron braya y Nova" not in res)
comp("6e. una o dos vinetas por trozo, no cinco", "1 o 2 viñetas" in res, "las cinco se juntan al final")
comp("6f. y el diario se queda con cinco", "vinetas[:RESUMEN_VINETAS]" in res and ns["RESUMEN_VINETAS"] == 5)

print("")
print("-- 7. SI UNA LLAMADA FALLA, EL BRUTO NO SE BORRA --")
iFor = res.index("for pieza in piezas:")
iRet = res.index("return False", iFor)
iRm = res.index("os.remove(ruta)", iFor)
comp("7a. el return del fallo va antes del borrado", iRet < iRm,
     "un dia a medio resumir no se puede tirar")
comp("7b. y el borrado sigue ahi para cuando sale bien", "os.remove(ruta)" in res)
comp("7c. cada trozo se recorta a su tope", "[-RESUMEN_TROZO_CHARS:]" in res, "no a un 2500 escrito a mano")
comp("7d. y se dice cuantas conversaciones eran", "las resumo por separado" in res)

print("")
if fallos:
    print("  %d MAL" % fallos)
    sys.exit(1)
print("  el resumen del dia mira el dia entero, y habla de braya")
sys.exit(0)
