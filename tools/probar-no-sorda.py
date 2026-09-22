# -*- coding: utf-8 -*-
# QUE NOVA NO SE PUEDA QUEDAR SORDA (22/09).
#
# LO QUE PASO, tal cual, sacado de assistant.log esa madrugada:
#
#     01:17:52  suelo 0,0048  puerta 0,0060  p90 0,021  ganancia x15,5   6 de 60 bloques
#     01:18:47  suelo 0,0048  puerta 0,0060  p90 0,133  ganancia x5,0   39 de 60
#     01:20:17  suelo 0,1126  puerta 0,1295  p90 0,136  ganancia x3,2   60 de 60
#
# A las 01:18:40 empezo a sonar algo constante. A partir de ahi todos los bloques pasaban
# UMBRAL_VOZ, el p90 "de voz" dejo de ser la voz y paso a ser el ruido, la ganancia se calibro
# contra ese numero y se hundio de x15,5 a x2,6, y la puerta subio a 0,126. Las cinco rafagas
# LO QUE NO SE PUEDE AFIRMAR: que se quedara sorda. braya dejo de hablarle a las 01:18:36 y
# despues no hubo NI UN intento -ni una activacion, ni un descarte, ni una grabacion-, asi
# que no hay prueba de sordera. Lo encontro un agente refutando esta misma explicacion.
# LO QUE SI ESTA MEDIDO, y basta: (1) el margen se quedo en el 2 % -su voz asoma 0,0195 sobre
# el ruido, o sea 0,1294 contra una puerta de 0,1264-, que no es un sistema que funciona sino
# uno que aun no ha fallado; (2) la ganancia se hundio de x15,5 a x2,6 persiguiendo al ruido,
# y ese es el audio que comen Parakeet y Whisper; (3) y suelo_ruido solo se recalculaba dentro
# de la rama de calibrar, un cerrojo del que solo se salia reiniciando el worker.
#
# El arreglo tiene dos piezas y las dos se prueban aqui con esos numeros:
#   A) la puerta NUNCA sube por encima de la rafaga mas floja con la que se le ha oido.
#   B) si casi todos los bloques son "voz", no es voz: es ruido, y no se calibra con el.
#
#   python tools/probar-no-sorda.py
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
    print("  %s  %-58s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- las piezas de verdad -----------------------------------------------------------
ns = {}
for cte in ("UMBRAL_ACTIVIDAD", "SUELO_FACTOR", "RAFAGAS_RECUERDO", "RAFAGA_MARGEN",
            "RUIDO_CONSTANTE", "RUIDO_PULSOS", "RAFAGA_SUELO", "MARGEN_MINIMO"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s" % cte)
        sys.exit(1)
    ns[cte] = int(m.group(1)) if cte in ("RAFAGAS_RECUERDO", "RUIDO_PULSOS") else float(m.group(1))

ns["margenes_buenos"] = []
ns["suelo_ruido"] = 0.0
for nombre in ("techo_puerta", "apuntar_rafaga_buena", "umbral_actividad"):
    m = re.search(r"(?ms)^def %s\(.*?\n(?=\n*\S|\Z)" % nombre, SRC)
    if not m:
        print("  MAL  no encuentro %s en wake_vosk.py" % nombre)
        sys.exit(1)
    exec(compile(m.group(0), nombre, "exec"), ns)
# guardar_margenes escribe en disco; aqui no interesa
ns["guardar_margenes"] = lambda: None

techo_puerta = ns["techo_puerta"]
apuntar = ns["apuntar_rafaga_buena"]
umbral_actividad = ns["umbral_actividad"]

# LAS CINCO RAFAGAS CON LAS QUE braya LLAMO A NOVA LA NOCHE DEL 22/09, del log
SUYAS = [0.081, 0.048, 0.031, 0.029, 0.024]
SUELO_ENVENENADO = 0.1099   # el suelo que habia a las 01:49, medido
SUELO_DE_ENTONCES = 0.0045  # y el que habia a las 01:08-01:14, cuando ella le oia


def reset(rafagas=(), suelo=0.0):
    """Se le pasan las RAFAGAS tal cual se midieron, con el suelo que habia entonces;

    aqui dentro se convierten en margenes, que es lo que guarda el worker de verdad.
    SUELO_DE_ENTONCES es el que habia la noche del 22 cuando braya la llamaba: 0,0045."""
    ns["margenes_buenos"][:] = [r - SUELO_DE_ENTONCES for r in rafagas if r > SUELO_DE_ENTONCES]
    ns["suelo_ruido"] = suelo


print("")
print("-- 1) EL CASO REAL DEL 22/09, y donde el techo decide de verdad --")
# LOS NUMEROS, todos medidos: esa noche braya llamo a Nova con rafagas de 0,024 a 0,081 y el
# suelo de ruido era 0,0045; o sea que su voz ASOMA 0,0195 sobre el ruido en el peor caso.
# Luego el suelo subio a 0,1099 y la puerta a 0,1264. En esa habitacion su voz valdria
# 0,1099 + 0,0195 = 0,1294: pasaba por un 2 %.
# SE DICE CLARO: esa noche el techo apenas cambia nada (de 2,4 % de margen a 3,1 %). Donde
# decide es mas arriba: en cuanto el ruido pasa de ~0,13, la puerta sin techo (suelo x 1,15)
# se pone POR ENCIMA de lo que vale su voz y ya no hay nada que hacer; con techo, no puede.
# Por eso los dos casos de abajo: el de esa noche, y el de una habitacion mas ruidosa.
reset(suelo=SUELO_ENVENENADO)
sin_techo = umbral_actividad()
su_voz = SUELO_ENVENENADO + (min(SUYAS) - SUELO_DE_ENTONCES)
comp("la puerta se pone donde se puso esa noche", abs(sin_techo - 0.1264) < 0.003,
     "%.4f (el log decia 0.1264)" % sin_techo)
comp("y su voz pasaba por un pelo, sin techo", su_voz > sin_techo,
     "voz %.4f contra puerta %.4f: %.0f %% de margen" % (su_voz, sin_techo,
                                                        100.0 * (su_voz - sin_techo) / sin_techo))
reset(rafagas=SUYAS, suelo=SUELO_ENVENENADO)
con_techo = umbral_actividad()
comp("con techo, algo mas de margen", con_techo < sin_techo,
     "%.4f contra %.4f" % (con_techo, sin_techo))

# Y AHORA LA HABITACION RUIDOSA, que es para lo que sirve el techo. Con el suelo en 0,20:
#   sin techo  -> puerta 0,20 * 1,15 = 0,2300   y su voz vale 0,2195  -> SORDA
#   con techo  -> puerta 0,20 + 0,0195*0,8 = 0,2156                   -> le oye
RUIDOSA = 0.20
reset(suelo=RUIDOSA)
sin_t = umbral_actividad()
voz_r = RUIDOSA + (min(SUYAS) - SUELO_DE_ENTONCES)
comp("en una habitacion ruidosa, SIN techo se queda sorda", voz_r < sin_t,
     "su voz %.4f por debajo de la puerta %.4f" % (voz_r, sin_t))
reset(rafagas=SUYAS, suelo=RUIDOSA)
con_t = umbral_actividad()
comp("y CON techo, le sigue oyendo", voz_r > con_t,
     "su voz %.4f por encima de la puerta %.4f" % (voz_r, con_t))
comp("sin abrir la puerta de par en par", con_t > RUIDOSA,
     "la puerta %.4f sigue por encima del ruido %.2f: Vosk no decodifica sin parar" % (con_t, RUIDOSA))

print("-- 2) el techo no estorba cuando no hace falta --")
# con el micro limpio (Realtek, suelo ~0,001) la puerta se quedaba en 0,006 de toda la vida
reset(rafagas=SUYAS, suelo=0.001)
comp("con un micro limpio no cambia nada raro", umbral_actividad() <= ns["UMBRAL_ACTIVIDAD"],
     "%.4f" % umbral_actividad())
reset(suelo=0.001)
comp("y sin llamadas aun, manda lo de siempre", umbral_actividad() == ns["UMBRAL_ACTIVIDAD"],
     "%.4f" % umbral_actividad())
comp("sin llamadas, no hay techo que poner", techo_puerta() is None)

print("")
print("-- 3) el techo se mueve con lo que MENOS asomo, no con lo ultimo --")
# Lo que se guarda es cuanto asoma su voz, asi que una llamada suya muy floja -hablando bajito,
# o desde lejos- tiene que bajar el techo y dejarlo bajado. Una llamada fuerte no lo sube: si
# lo subiera, gritar una vez dejaria a Nova sin oir el susurro siguiente.
reset(suelo=0.010)
for r in (0.20, 0.18, 0.22):
    apuntar(r)
alto = techo_puerta()
apuntar(0.03)     # una llamada floja: el techo tiene que BAJAR
comp("una llamada floja baja el techo", techo_puerta() < alto,
     "de %.4f a %.4f" % (alto, techo_puerta()))
bajo = techo_puerta()
apuntar(0.25)     # y una fuerte NO debe volver a subirlo
comp("y una fuerte no lo vuelve a subir", abs(techo_puerta() - bajo) < 1e-9,
     "%.4f" % techo_puerta())
antes = len(ns["margenes_buenos"])
apuntar(0)
apuntar(-1)
apuntar(0.005)    # por debajo del suelo: no asoma nada, no es su voz
comp("una rafaga imposible o que no asoma, no entra", len(ns["margenes_buenos"]) == antes,
     "%d guardados" % len(ns["margenes_buenos"]))
ns["margenes_buenos"][:] = []
ns["suelo_ruido"] = 0.0
apuntar(0.05)
comp("sin suelo medido aun, no se apunta nada", len(ns["margenes_buenos"]) == 0,
     "un margen contra un suelo de cero seria el nivel entero")
reset(suelo=0.010)
for i in range(200):
    apuntar(0.05 + (i % 10) * 0.01)
comp("no se recuerdan mas de RAFAGAS_RECUERDO",
     len(ns["margenes_buenos"]) == ns["RAFAGAS_RECUERDO"], "%d" % len(ns["margenes_buenos"]))
ns["margenes_buenos"][:] = [0.0001]
comp("y nunca se pega tanto al suelo que entre el ruido",
     techo_puerta() >= ns["suelo_ruido"] + ns["MARGEN_MINIMO"] * ns["RAFAGA_MARGEN"] - 1e-9,
     "MARGEN_MINIMO %.4f" % ns["MARGEN_MINIMO"])

print("-- 4) solo cuentan las llamadas que pasaron TODOS los filtros --")
# Si aqui entrara un falso positivo, el techo bajaria a la altura de un ruido y la puerta
# con el: seria peor el remedio. Por eso apuntar_rafaga_buena se llama DESPUES del juez,
# de la confianza, de los altavoces y del antirebote, no antes.
i_marca = SRC.find("ultima_marca = ahora")
i_apunta = SRC.find("apuntar_rafaga_buena(pico_rafaga)")
i_juez = SRC.find("elif not juez_deja_pasar(texto):")
i_conf = SRC.find("elif conf < umbral_confianza(plano):")
i_flojo = SRC.find("elif pico_rafaga < umbral_rafaga():")
comp("se apunta despues del juez", 0 < i_juez < i_apunta)
comp("despues del filtro de confianza", 0 < i_conf < i_apunta)
comp("despues del filtro de 'suena demasiado flojo'", 0 < i_flojo < i_apunta)
comp("y dentro del antirebote, no fuera", 0 < i_marca < i_apunta < i_marca + 900)

print("")
print("-- 5) ruido constante no es voz --")
# la voz de una persona tiene silencios; un ventilador no. Esta es la regla que impide que
# el p90 'de voz' se convierta en el p90 del ruido.
def es_ruido(bloques_voz, bloques_ventana, pulsos_antes=0):
    p = pulsos_antes
    if bloques_ventana >= 20 and bloques_voz >= bloques_ventana * ns["RUIDO_CONSTANTE"]:
        p += 1
    else:
        p = 0
    return p >= ns["RUIDO_PULSOS"], p

# lo que se vio esa noche: 60 de 60, pulso tras pulso
ok, p = es_ruido(60, 60)
comp("60 de 60 bloques en un solo pulso: aun no se juzga", not ok, "hacen falta %d pulsos" % ns["RUIDO_PULSOS"])
ok, p = es_ruido(60, 60, p)
comp("dos pulsos seguidos a 60 de 60: eso es ruido", ok)

# y lo que NO puede confundirse con ruido: braya hablando de verdad
for bv, bt, que in [(6, 60, "una orden corta"), (39, 60, "una frase larga"),
                    (33, 60, "hablando con pausas"), (15, 60, "un si o un no")]:
    ok, _ = es_ruido(bv, bt, 1)
    comp("%-22s (%d de %d) NO es ruido" % (que, bv, bt), not ok)

ok, _ = es_ruido(19, 19, 1)
comp("con la ventana casi vacia no se juzga nada", not ok, "19 bloques es menos de 5 s")
_, p = es_ruido(60, 60, 1)
_, p2 = es_ruido(10, 60, p)
comp("y en cuanto vuelve a haber silencio, se olvida", p2 == 0, "el contador se pone a cero")

print("")
print("-- 6) y queda dicho en el log, que esa noche no se dijo nada --")
comp("Nova apunta que lo que oye es ruido", "esto no es voz, es ruido de fondo" in SRC)
comp("y con cuantos bloques de cuantos", "%d de %d bloques" in SRC)
comp("y que deja la ganancia quieta", re.search(r"dejo la ganancia en x%\.1f", SRC) is not None)
comp("al arrancar dice cuanto asoma su voz", "asoma al menos" in SRC)

print("")
print("-- 7) el suelo se mide SIEMPRE: el cerrojo que encontro un refutador --")
# Esto vivia DENTRO de la rama de calibrar, y era un lazo cerrado: la señal de la que sale la
# puerta solo se actualizaba cuando la propia puerta habia dejado pasar bloques. Si la puerta
# subia lo bastante como para bajar de MIN_BLOQUES_VOZ, el suelo no se recalculaba NUNCA MAS y
# solo se salia reiniciando el worker. Un estado del que no se sale solo, que es justo lo que
# braya rechaza. Aqui se vigila que no vuelva a meterse dentro de ninguna rama.
lineas = SRC.splitlines()
i_suelo = next((i for i, l in enumerate(lineas) if "suelo_ruido = float(" in l), -1)
comp("el calculo del suelo existe", i_suelo > 0)
if i_suelo > 0:
    # se mira hacia arriba: entre el if que lo cobija y el, no puede haber ningun "automatica"
    sangria = len(lineas[i_suelo]) - len(lineas[i_suelo].lstrip())
    dentro_de = []
    for j in range(i_suelo - 1, max(0, i_suelo - 60), -1):
        l = lineas[j]
        if not l.strip() or l.strip().startswith("#"):
            continue
        s_j = len(l) - len(l.lstrip())
        if s_j < sangria:
            dentro_de.append(l.strip()[:60])
            sangria = s_j
        if s_j <= 20:
            break
    comp("y NO esta dentro de ninguna rama de calibrar",
         not any("automatica" in d for d in dentro_de), "; ".join(dentro_de[:2]))
    i_ruido_r = SRC.find("if automatica and ruido_constante:")
    comp("se calcula ANTES de decidir si se calibra",
         0 < SRC.find("suelo_ruido = float(") < i_ruido_r)

print("")
print("-- 8) la calibracion se salta de verdad cuando hay ruido --")
# lo que se puede estropear sin querer: que la rama nueva este pero no delante de la vieja
i_ruido = SRC.find("if automatica and ruido_constante:")
i_alta = SRC.find("elif automatica and altavoces_altos")
i_cal = SRC.find("elif automatica and bloques_voz >= MIN_BLOQUES_VOZ and picos:")
comp("la rama del ruido va ANTES de la de calibrar", 0 < i_ruido < i_cal)
comp("y antes de la de los altavoces", 0 < i_ruido < i_alta)
comp("la de calibrar sigue existiendo", i_cal > 0)

print("")
print("-- 9) la ganancia que se congela tiene que ser una BUENA --")
# ESTO SALIO AL ESTRENARLO, la mañana del 22, y es el caso que faltaba. La deteccion de ruido
# funcionaba a la primera -"esto no es voz, es ruido de fondo (60 de 60 bloques)"- pero
# congelaba la ganancia EN EL VALOR YA ENVENENADO: con la voz de braya por este micro la buena
# estaba en x13-15, el ruido de las 01:18 la hundio a x3,1 persiguiendolo, y eso es lo que
# quedaba congelado. Peor: se habia guardado en tmp/ganancia.txt, asi que sobrevivia a los
# reinicios. Congelar la ultima calibracion solo sirve si la ultima era buena.
comp("se recuerda aparte la ultima ganancia buena", "ganancia_buena = 0.0" in SRC)
comp("al ver ruido se vuelve a ella, no se congela la de ahora",
     "ganancia = ganancia_buena" in SRC)
comp("y se dice en el log, que si no nadie se entera",
     "vuelvo a la x%.1f de cuando te oia" in SRC)
# el orden importa: volver ANTES de anotar, o el log diria la vieja.
# SIN EL PREFIJO DE LA LLAMADA (22/09): esto buscaba 'anota("pulso: esto no es voz' tal
# cual, y se puso rojo el dia que esa linea paso a anota_pulso() para dejar de escribir la
# misma frase 2.451 veces al dia. Lo que se comprueba es el ORDEN, no con que funcion se
# anota, asi que se busca solo el texto y vale para las dos.
_i_vuelta = SRC.find("ganancia = ganancia_buena")
_i_anota = SRC.find('("pulso: esto no es voz')
comp("se vuelve antes de anotarlo", 0 < _i_vuelta < _i_anota)
# solo la buena va al disco
_i_marca = SRC.find("ganancia_buena = ganancia")
_i_disco = SRC.find('escribir(RUTA_GANANCIA, "%.1f|%s"')
comp("solo se guarda en disco la calibrada con voz de verdad", 0 < _i_marca < _i_disco,
     "se marca como buena justo antes de escribirla")
# Y LO QUE FALLO AL ESTRENARLO POR SEGUNDA VEZ: el ruido pide RUIDO_PULSOS pulsos seguidos
# para confirmarse, asi que el PRIMERO llegaba a la rama de calibrar y marcaba como buena una
# ganancia ya contaminada. Visto en vivo: 07:45:03 recorte -> x8,7; 07:45:17 calibra x7,6 y la
# marca buena; 07:45:32 ruido confirmado, y ya no habia a que volver.
comp("solo un pulso SIN NADA de ruido cuenta como bueno",
     "if pulsos_ruidosos == 0:" in SRC)
_i_guarda = SRC.find('if pulsos_ruidosos == 0:')
_i_esc = SRC.find('escribir(RUTA_GANANCIA', _i_guarda)
comp("y el disco va dentro de esa guarda", 0 < _i_guarda < _i_esc < _i_guarda + 700,
     "si no, la proxima sesion hereda una ganancia hecha sobre ruido")
comp("y esta dentro de la rama de calibrar, no fuera",
     SRC[:_i_marca].rfind("elif automatica and bloques_voz >= MIN_BLOQUES_VOZ and picos:") >
     SRC[:_i_marca].rfind("if automatica and ruido_constante:"))
comp("lo que se recupera al arrancar cuenta como buena",
     "ganancia_buena = _g" in SRC)
# y el margen de 0,2: sin el, se reescribiria la misma ganancia en cada pulso ruidoso
# Y EL PIN-PON, que salio al estrenarlo por tercera vez: devolver la ganancia buena con un
# ruido que la hace saturar daba un ciclo de 15 segundos -vuelve a x14,5, satura, el detector
# la baja a x8,7, vuelve a x14,5- y cada vuelta destrozaba un segundo de audio. Con ese ruido
# esa ganancia no existe en esa habitacion: manda el detector de recorte.
# Y ESPERAR AL RECORTE NO BASTABA: solo espaciaba el pin-pon a 45 s. Hay que CALCULAR si esa
# ganancia cabe en esta habitacion, que es aritmetica, no espera.
comp("se calcula si la ganancia buena cabe con este ruido",
     "suelo_ruido * ganancia_buena < CABE_MAX" in SRC)
_ic = re.search(r"^CABE_MAX = ([0-9.]+)", SRC, re.M)
comp("y deja sitio para que su voz asome", _ic and 0.4 <= float(_ic.group(1)) <= 0.9,
     "CABE_MAX %s" % (_ic.group(1) if _ic else "?"))
if _ic:
    _cm = float(_ic.group(1))
    # los dos casos reales, con los numeros del 22/09
    comp("con el ruido de esa manana (0,0907) la x14,5 NO cabe", 0.0907 * 14.5 >= _cm,
         "%.2f de rango" % (0.0907 * 14.5))
    comp("y con su silencio normal (0,022) SI cabe", 0.022 * 14.5 < _cm,
         "%.2f de rango" % (0.022 * 14.5))
comp("sin suelo medido aun, no estorba", "suelo_ruido <= 0" in SRC)
comp("no se vuelve a una ganancia que esta saturando",
     "ahora - ultimo_recorte > RECORTE_RECIENTE" in SRC)
comp("y el detector de recorte apunta cuando fue", "ultimo_recorte = ahora" in SRC)
_ir = re.search(r"^RECORTE_RECIENTE = ([0-9.]+)", SRC, re.M)
comp("con un margen de al menos medio minuto", _ir and float(_ir.group(1)) >= 30,
     "%s s" % (_ir.group(1) if _ir else "?"))
comp("no se toca si ya esta en la buena",
     "abs(ganancia - ganancia_buena) > 0.2" in SRC)

print("")
print("-- 10) el oido no llama a nada que no exista --")
# ESTO PASO DE VERDAD ESTA MISMA NOCHE, y por eso esta aqui: un parche mio se llevo por
# delante cuatro funciones (segundos_de_voz, cobertura_parakeet, suena_ingles y
# repasar_si_ingles) al cortar un tramo por un ancla que no era. El fichero SEGUIA
# COMPILANDO -Python no comprueba los nombres hasta que se ejecutan-, asi que ni ast.parse ni
# la sintaxis lo cazaban: wake_vosk.py se habria caido en la primera orden, con Nova ya en
# marcha y sin oido. Lo caza esta comprobacion, que es barata y vale para siempre.
import ast as _ast
_arbol = _ast.parse(SRC)
# las clases cuentan igual: ram_libre_mb define una (_MS, la estructura de Windows) dentro
# de si misma, y llamarla es tan legitimo como llamar a una funcion
_def = {n.name for n in _ast.walk(_arbol)
        if isinstance(n, (_ast.FunctionDef, _ast.AsyncFunctionDef, _ast.ClassDef))}
_asignadas = set()
for _n in _ast.walk(_arbol):
    if isinstance(_n, _ast.Assign):
        for _t in _n.targets:
            if isinstance(_t, _ast.Name):
                _asignadas.add(_t.id)
    elif isinstance(_n, (_ast.arg,)):
        _asignadas.add(_n.arg)
    elif isinstance(_n, _ast.Import):
        for _al in _n.names:
            _asignadas.add((_al.asname or _al.name).split(".")[0])
    elif isinstance(_n, _ast.ImportFrom):
        for _al in _n.names:
            _asignadas.add(_al.asname or _al.name)
    elif isinstance(_n, _ast.Name) and isinstance(_n.ctx, (_ast.Store,)):
        _asignadas.add(_n.id)
import builtins as _b
_conocidos = _def | _asignadas | set(dir(_b))
_huerfanas = []
for _n in _ast.walk(_arbol):
    # solo llamadas a un nombre pelado: obj.metodo() no se puede comprobar asi
    if isinstance(_n, _ast.Call) and isinstance(_n.func, _ast.Name):
        if _n.func.id not in _conocidos:
            _huerfanas.append("%s (linea %d)" % (_n.func.id, _n.lineno))
comp("cada funcion que llama el oido existe de verdad", not _huerfanas,
     "; ".join(_huerfanas[:4]))
# y las que este banco da por hechas, tambien
for _f in ("segundos_de_voz", "cobertura_parakeet", "suena_ingles", "repasar_si_ingles",
           "cobertura_min", "apuntar_cobertura", "techo_puerta", "apuntar_rafaga_buena",
           "umbral_actividad", "umbral_rafaga", "plazo_soltar", "decir_estado",
           "guardar_lista", "cargar_lista", "cargar_lo_aprendido"):
    comp("existe %s" % _f, _f in _def)

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  la puerta no puede subir por encima de su voz")
sys.exit(0)
