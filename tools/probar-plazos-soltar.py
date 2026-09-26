# -*- coding: utf-8 -*-
# LOS PLAZOS DE SOLTAR MODELOS MIRAN LA RAM QUE QUEDA (22/09).
#
# braya: "todo deberia ser ajustable por ella, nova tiene que adaptarse a la situacion y
# cambiar sola". Los cuatro plazos del oido -20 min el oido fino, 5 min con juego delante,
# 2 min el ultimo recurso- estaban escritos a mano y no miraban nada. Con memoria de sobra eso
# es lo rapido y esta bien; con la memoria justa es lo contrario.
#
# LO QUE LO MOTIVA, medido el 22/09 en la consola con Nova en marcha: el worker del oido
# llevaba 1.668 MB con los cuatro modelos dentro y quedaban 1.767 MB libres de 11.979. Y esa
# madrugada el asistente se murio a mitad de un dictado sin dejar ni un error en el Visor de
# eventos de Windows -la pinta exacta de quedarse sin memoria-, y en todo el log no habia ni
# una linea que dijera cuanta RAM quedaba.
#
# Aqui se ejecuta plazo_soltar de verdad (no se mira el fuente y ya), porque lo que puede
# salir mal son los numeros: que se vuelva lento sin necesidad, o que no suelte cuando toca.
#
#   python tools/probar-plazos-soltar.py
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# NO se importa wake_vosk: importarlo arranca el microfono. Se extrae con regex.
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- la funcion de verdad, con un ram_libre_mb de mentira que se puede mover -------------
ns = {}
for cte in ("RAM_COMODA", "RAM_APRETADA", "SOLTAR_MIN_FACTOR",
            "PRECISO_SOLTAR_QUIETO", "PRECISO_SOLTAR_JUGANDO", "PARAKEET_SOLTAR_JUGANDO",
            "ULTIMO_SOLTAR", "RAM_MIN_PRECISO"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s" % cte)
        sys.exit(1)
    ns[cte] = float(m.group(1))

_ram = [-1.0]
ns["ram_libre_mb"] = lambda: _ram[0]
m = re.search(r"(?ms)^def plazo_soltar\(.*?\n(?=\n*\S|\Z)", SRC)
if not m:
    print("  MAL  no encuentro plazo_soltar en wake_vosk.py")
    sys.exit(1)
exec(compile(m.group(0), "plazo_soltar", "exec"), ns)
plazo_soltar = ns["plazo_soltar"]
QUIETO = ns["PRECISO_SOLTAR_QUIETO"]


def con(mb):
    _ram[0] = float(mb)
    return plazo_soltar(QUIETO)


print("")
print("-- con memoria de sobra, el plazo de siempre: manda la rapidez --")
comp("con 8 GB libres, el plazo entero", con(8000) == QUIETO, "%.0f s" % con(8000))
comp("justo en RAM_COMODA, tambien entero", con(ns["RAM_COMODA"]) == QUIETO, "%.0f s" % con(ns["RAM_COMODA"]))
comp("un pelin por encima, entero", con(ns["RAM_COMODA"] + 1) == QUIETO)

print("")
print("-- y si no se puede medir, tampoco se toca nada --")
# ram_libre_mb devuelve -1 cuando falla. Ahi lo prudente es NO cambiar: suponer lo peor
# dejaria a Nova lenta por si acaso, que es lo que braya no quiere.
comp("con -1 (no se sabe), el plazo de siempre", con(-1) == QUIETO, "%.0f s" % con(-1))

print("")
print("-- con la memoria justa, suelta pronto: manda no morirse --")
comp("con 500 MB, la decima parte", abs(con(500) - QUIETO * ns["SOLTAR_MIN_FACTOR"]) < 0.01,
     "%.0f s en vez de %.0f" % (con(500), QUIETO))
comp("justo en RAM_APRETADA, la decima parte",
     abs(con(ns["RAM_APRETADA"]) - QUIETO * ns["SOLTAR_MIN_FACTOR"]) < 0.01, "%.0f s" % con(ns["RAM_APRETADA"]))
comp("con 0 MB no se vuelve negativo ni cero", 0 < con(0) <= QUIETO, "%.0f s" % con(0))

print("")
print("-- en medio, proporcional y sin saltos --")
antes = None
subidas = True
for mb in range(0, 3600, 100):
    v = con(mb)
    if antes is not None and v < antes - 0.001:
        subidas = False
    antes = v
comp("mas memoria libre nunca da un plazo mas corto", subidas)
medio = (ns["RAM_COMODA"] + ns["RAM_APRETADA"]) / 2.0
comp("a media tabla, mas o menos la mitad del plazo",
     QUIETO * 0.4 < con(medio) < QUIETO * 0.75, "%.0f s con %.0f MB" % (con(medio), medio))
comp("nunca pasa del plazo escrito", max(con(mb) for mb in range(0, 12000, 250)) <= QUIETO)

print("")
print("-- EL CASO REAL DEL 22/09: 1.767 MB libres --")
# lo que habia en la consola de braya con Nova en marcha y los cuatro modelos dentro
real = con(1767)
comp("el oido fino se suelta antes de los 20 min", real < QUIETO, "%.0f s (%.1f min)" % (real, real / 60.0))
comp("pero no tan pronto como para ir recargando", real > 120,
     "%.0f s; recargarlo cuesta 2,5-5 s" % real)

print("")
print("-- los cuatro plazos pasan por aqui, o esto no sirve de nada --")
# Lo que se puede estropear sin querer: anadir un uso nuevo del plazo y olvidarse de
# envolverlo. Se comprueba sobre el fuente que no queda ninguno suelto.
for cte in ("PRECISO_SOLTAR_QUIETO", "PRECISO_SOLTAR_JUGANDO", "PARAKEET_SOLTAR_JUGANDO", "ULTIMO_SOLTAR"):
    # los usos de verdad son los que estan en una linea de codigo (no comentario ni la
    # definicion); todos tienen que estar dentro de un plazo_soltar(...)
    sueltos = []
    for linea in SRC.split("\n"):
        t = linea.strip()
        if not t or t.startswith("#") or t.startswith(cte + " ="):
            continue
        if cte in t and "plazo_soltar(" not in t:
            sueltos.append(t[:60])
    comp("%s siempre pasa por plazo_soltar" % cte, not sueltos, "; ".join(sueltos))

print("")
print("-- y la RAM queda escrita en el log, que anoche no se pudo saber --")
comp("el pulso dice cuanta RAM queda", "ram_libre=" in SRC)
comp("y el plazo que se esta aplicando", "plazo=x" in SRC)
# ANCLADO EN LA LINEA DEL PULSO, NO EN UNA VENTANA DE CARACTERES (26/09). Esto pedia el "?"
# dentro de los 400 caracteres siguientes a ram_libre_mb() y se puso rojo solo en cuanto
# entro el contador de memoria justa entre las dos: una ventana fija castiga cualquier linea
# nueva en medio aunque lo vigilado siga intacto. Lo que de verdad importa es que la LINEA
# del pulso -la que escribe ram_libre- decida entre el valor y el "?" mirando el signo.
_pulso = re.search(r'anota_pulso\("pulso: suelo=.*?\), ahora\)', SRC, re.S)
comp("el pulso existe y se puede leer entero", _pulso is not None)
_txt = _pulso.group(0) if _pulso else ""
comp("con '?' si no se puede medir, no un cero que engane",
     '"?"' in _txt and "_ram >= 0" in _txt)

print("")
print("-- los limites son razonables para esta consola (11,7 GB) --")
comp("RAM_APRETADA deja sitio a la guarda del oido fino",
     ns["RAM_APRETADA"] >= ns["RAM_MIN_PRECISO"] * 0.8,
     "apretada %.0f, el oido fino pide %.0f" % (ns["RAM_APRETADA"], ns["RAM_MIN_PRECISO"]))
comp("RAM_COMODA esta por encima de RAM_APRETADA", ns["RAM_COMODA"] > ns["RAM_APRETADA"])
comp("y por debajo de lo que pide un juego (4 GB)", ns["RAM_COMODA"] < 4000)



# ==========================================================================================
# LOS LISTONES SALEN DE LO QUE CUESTAN LOS MODELOS (26/09, idea 17 de las 121)
# ==========================================================================================
print("")
print("-- de donde salen los dos listones --")
# ESTO ES LO QUE SUSTITUYE A "ADAPTATIVO": los listones no pueden separarse en silencio de lo
# que cuesta volver a cargar lo que sueltan. Si manana entra un Parakeet mas gordo y alguien
# sube RAM_MIN_PARAKEET sin tocar esto, se pone rojo.
_mp = re.search(r"^RAM_MIN_PARAKEET = ([0-9.]+)", SRC, re.M)
comp("se encuentra RAM_MIN_PARAKEET", _mp is not None)
_RMP = float(_mp.group(1)) if _mp else 0.0
comp("RAM_APRETADA es lo que pide el oido fino",
     ns["RAM_APRETADA"] == ns["RAM_MIN_PRECISO"],
     "%.0f == %.0f; por debajo ya no cabe, retenerlo no compra nada"
     % (ns["RAM_APRETADA"], ns["RAM_MIN_PRECISO"]))
comp("RAM_COMODA es lo que cuesta traer los dos",
     ns["RAM_COMODA"] == _RMP + ns["RAM_MIN_PRECISO"],
     "%.0f == %.0f + %.0f" % (ns["RAM_COMODA"], _RMP, ns["RAM_MIN_PRECISO"]))

print("")
print("-- y el efecto, sobre los pulsos de verdad --")
# NO SE CUENTAN NUMEROS EXACTOS, SE COMPARAN TRES JUEGOS DE LISTONES SOBRE LOS MISMOS DATOS.
# El log crece cada quince segundos: un banco que exigiera "30 recortados" se pondria rojo
# manana sin que nadie tocara nada. Lo que se afirma es una RELACION, y esa no caduca.
_log = os.path.join(RAIZ, "assistant-pulso.log")
_libres = []
if os.path.exists(_log):
    for _l in io.open(_log, encoding="utf-8", errors="ignore"):
        _m = re.search(r"ram_libre=([0-9]+)", _l)
        if _m:
            _libres.append(float(_m.group(1)))


def _recorta_con(comoda, apretada):
    """Cuantos de esos pulsos correrian con el plazo recortado, con esos dos listones.

    Se ejecuta el plazo_soltar DE VERDAD, cambiandole solo las dos constantes: reescribir la
    formula aqui seria doblar la pieza que se prueba, y entonces el banco pasaria en verde con
    la de wake_vosk.py rota.
    """
    n2 = dict(ns)
    n2["RAM_COMODA"] = comoda
    n2["RAM_APRETADA"] = apretada
    exec(compile(m.group(0), "plazo_soltar", "exec"), n2)
    f = n2["plazo_soltar"]
    n = 0
    for v in _libres:
        _ram[0] = v
        if f(QUIETO) < QUIETO - 0.001:
            n += 1
    return n


if not _libres:
    print("       NO HAY assistant-pulso.log: este caso NO se ha comprobado")
    comp("hay pulsos que replicar", False, "sin el log no se puede decir nada")
else:
    _hoy = _recorta_con(ns["RAM_COMODA"], ns["RAM_APRETADA"])
    _antes = _recorta_con(2500.0, 1000.0)
    # El p60 y el p15 de los propios datos, que es lo que pedia la idea antes de recontarla.
    _ord = sorted(_libres)
    _p60 = _ord[min(len(_ord) - 1, int(0.60 * len(_ord)))]
    _p15 = _ord[min(len(_ord) - 1, int(0.15 * len(_ord)))]
    _pct = _recorta_con(_p60, _p15)
    print("       %d pulsos reales; recortados: hoy %d, antes %d, por percentil %d"
          % (len(_libres), _hoy, _antes, _pct))
    comp("los listones nuevos recortan MENOS que los viejos", _hoy < _antes,
         "%.1f %% frente a %.1f %%" % (100.0 * _hoy / len(_libres), 100.0 * _antes / len(_libres)))
    # Y ESTE ES EL CASO QUE EXPLICA POR QUE NO SE HIZO LO QUE PEDIA LA IDEA: un liston puesto
    # en el percentil p fija el recorte en 1-p POR CONSTRUCCION, aqui y en cualquier consola.
    comp("  y muchisimo menos que su propio percentil", _hoy < _pct,
         "el p60/p15 recortaria el %.1f %%: congelar el sintoma, no adaptarse"
         % (100.0 * _pct / len(_libres)))
    # LA RED DE ABAJO: no recortar nunca seria soltar tarde, y soltar tarde es lo que mato a
    # Nova la madrugada del 19/09.
    comp("  sin dejar de recortar cuando de verdad falta", _hoy > 0,
         "con la memoria justa sigue soltando pronto")

print("")
print("-- la cuenta de con cuanta memoria esta oyendo --")
_ns3 = {"RAM_COMODA": ns["RAM_COMODA"], "pulsos_ram": 0, "pulsos_ram_justa": 0}
_mpm = re.search(r"^RAM_PULSOS_MINIMOS = (.+)$", SRC, re.M)
comp("se encuentra RAM_PULSOS_MINIMOS", _mpm is not None)
_mip = re.search(r"^INTERVALO_PULSO = ([0-9.]+)", SRC, re.M)
if _mpm and _mip:
    _ns3["INTERVALO_PULSO"] = float(_mip.group(1))
    exec(compile("RAM_PULSOS_MINIMOS = " + _mpm.group(1), "cte", "exec"), _ns3)
    # DIEZ MINUTOS, Y NO UN NUMERO SUELTO: son los diez minutos de la frase partidos por el
    # periodo del pulso. Si manana cambia INTERVALO_PULSO, esto se ajusta solo.
    comp("son los diez minutos de la frase, no un numero a ojo",
         _ns3["RAM_PULSOS_MINIMOS"] == int(600.0 / _ns3["INTERVALO_PULSO"]),
         "%d pulsos de %.0f s" % (_ns3["RAM_PULSOS_MINIMOS"], _ns3["INTERVALO_PULSO"]))
for _f in ("apunta_ram", "ram_justa_pct"):
    _mf = re.search(r"(?ms)^def %s\(.*?\n(?=\n*\S|\Z)" % _f, SRC)
    comp("se encuentra %s a nivel de modulo" % _f, _mf is not None)
    if _mf:
        exec(compile(_mf.group(0), _f, "exec"), _ns3)
if "apunta_ram" in _ns3 and "ram_justa_pct" in _ns3:
    _ap = _ns3["apunta_ram"]
    _pct_f = _ns3["ram_justa_pct"]
    _min = _ns3.get("RAM_PULSOS_MINIMOS", 40)
    comp("sin diez minutos contados, no se sabe nada", _pct_f() == -1,
         "-1, nunca 0: con dos pulsos el porcentaje salta entre 0 y 100")
    # LA GUARDA DEL RIESGO: con un juego delante la foto de memoria es la del juego, que pide
    # de 4 a 6 GB. Contarla haria decir a Nova que anda apretada cuando lo que pasa es que
    # braya esta jugando. Es exactamente la madrugada del 19/09 que nombra el riesgo.
    for _i in range(_min * 2):
        _ap(200.0, True)
    comp("con un juego delante no se cuenta ni un pulso", _pct_f() == -1,
         "ahi la memoria es del juego, no de Nova")
    # NI LO QUE NO SE HA PODIDO MEDIR: ram_libre_mb devuelve -1 cuando falla.
    for _i in range(_min * 2):
        _ap(-1.0, False)
    comp("  ni lo que no se ha podido medir", _pct_f() == -1, "contarlo como apretado seria inventarselo")
    # Y AHORA LA CUENTA DE VERDAD: mitad justos, mitad comodos.
    for _i in range(_min):
        _ap(ns["RAM_COMODA"] - 100.0, False)
    for _i in range(_min):
        _ap(ns["RAM_COMODA"] + 100.0, False)
    comp("con la mitad justos, dice la mitad", _pct_f() == 50, "%d %%" % _pct_f())
    _ns3["pulsos_ram"] = 0
    _ns3["pulsos_ram_justa"] = 0
    for _i in range(_min):
        _ap(ns["RAM_COMODA"], False)
    comp("  y justo en el liston ya NO cuenta como apretado", _pct_f() == 0,
         "RAM_COMODA clavada es comoda, igual que en plazo_soltar")

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  los plazos se adaptan a la memoria que queda")
sys.exit(0)
