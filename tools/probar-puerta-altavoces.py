# -*- coding: utf-8 -*-
"""LA PUERTA DE LOS ALTAVOCES SE APRENDE DE TUS LLAMADAS (26/09, idea 18 de las 121).

EL AGUJERO: cuando los altavoces pasaban de 0,02, a la palabra de activacion se le exigia 0,85
en vez de 0,55, y ahi se le caian las llamadas. Ese 0,02 nunca salio de un dato. Medido sobre
14.422 pulsos con el nivel apuntado, 13.436 (el 93,2 %) valen CERO CLAVADO y entre 0 y 0,02
solo caen 89, el 0,6 %: ese liston no separaba nada. Y costaba 153 descartes en los dos
registros, 111 de ellos (72,5 %) con confianza de sobra para el liston normal.

ESTE BANCO VA EN PYTHON A PROPOSITO, y no es capricho: en PowerShell -match es
CASE-INSENSITIVE, asi que un patron que busque UMBRAL_ALTAVOZ casaria tambien con la funcion
nueva umbral_altavoz( y el banco no podria distinguir la constante de la puerta aprendida, que
es justo lo unico que hay que vigilar aqui. (Y de paso se evitan $ok/$OK, que en PowerShell son
la misma variable, y el $null que vale 0 en una comparacion numerica.)

NO SE IMPORTA wake_vosk: importarlo ARRANCA EL MICROFONO. Se saca la funcion del fuente y se
ejecuta en un entorno de mentira, igual que probar-no-sorda.py.

    python tools/probar-puerta-altavoces.py
"""
import io
import json
import os
import re
import sys
import tempfile
import shutil

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = [0]


def comp(que, ok, det=""):
    print("  %s  %-58s %s" % ("OK " if ok else "MAL", que, det))
    if not ok:
        fallos[0] += 1


# ---- las constantes, sacadas del fichero -------------------------------------------------
CTES = {}
for cte in ("ALTAVOZ_CUANTIL", "ALTAVOZ_MIN_MUESTRAS", "ALTAVOZ_VENTANA", "UMBRAL_ALTAVOZ_FUERTE"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s a columna 0 y como numero pelado" % cte)
        sys.exit(1)
    CTES[cte] = float(m.group(1))

# UMBRAL_ALTAVOZ viene de config.json, asi que no es un literal: se lee de su _num_de_config.
m = re.search(r"^UMBRAL_ALTAVOZ = _num_de_config\(\"umbralAltavoz\", ([0-9.]+)\)", SRC, re.M)
if not m:
    print("  MAL  no encuentro UMBRAL_ALTAVOZ")
    sys.exit(1)
SUELO = float(m.group(1))
TECHO = CTES["UMBRAL_ALTAVOZ_FUERTE"]
MINIMAS = int(CTES["ALTAVOZ_MIN_MUESTRAS"])

print("")
print("-- a. los dos numeros, y de donde salen --")
# NO SE COMPARA LA CONSTANTE CONSIGO MISMA: el p80 se recalcula aqui sobre el fichero de verdad
# mas abajo (caso g). Aqui solo se comprueba que el cuantil esta en la zona medida y que el
# suelo de muestras es el que mide la estabilidad.
comp("el cuantil deja fuera las que no sirvieron", 0.70 <= CTES["ALTAVOZ_CUANTIL"] <= 0.85,
     "p%d; con p90 se entra en el tramo de las que acabaron en nada"
     % int(CTES["ALTAVOZ_CUANTIL"] * 100))
comp("el suelo de muestras es donde el p80 deja de bailar", MINIMAS >= 25,
     "%d; por debajo el numero se mueve 0,14" % MINIMAS)
comp("el suelo es el 0,02 de config.json", SUELO == 0.02, "%.3f, y sigue siendo la palanca" % SUELO)
comp("y el techo es donde la palabra se ignora entera", TECHO == 0.35,
     "%.2f; por encima el liston duro no se aplicaria nunca" % TECHO)

# ---- la funcion, sacada del fuente y ejecutada de verdad ---------------------------------
m = re.search(r"(?ms)^def umbral_altavoz\(\):.*?\n(?=\n*\S|\Z)", SRC)
if not m:
    print("  MAL  no encuentro umbral_altavoz a nivel de modulo en wake_vosk.py")
    sys.exit(1)
CUERPO = m.group(0)

dicho = []


def monta(uso_dir):
    """Un entorno de mentira con lo justo, y la cache a cero en cada caso."""
    ns = {
        "os": os, "json": json,
        "UMBRAL_ALTAVOZ": SUELO,
        "UMBRAL_ALTAVOZ_FUERTE": TECHO,
        "ALTAVOZ_CUANTIL": CTES["ALTAVOZ_CUANTIL"],
        "ALTAVOZ_MIN_MUESTRAS": MINIMAS,
        "ALTAVOZ_VENTANA": int(CTES["ALTAVOZ_VENTANA"]),
        "USO_DIR": uso_dir,
        "anota": lambda s: dicho.append(s),
        "_puerta_altavoz": [None],
    }
    exec(compile(CUERPO, "umbral_altavoz", "exec"), ns)
    return ns["umbral_altavoz"]


def con_filas(carpeta, filas):
    os.makedirs(carpeta)
    with io.open(os.path.join(carpeta, "activaciones.jsonl"), "w", encoding="utf-8") as f:
        for d in filas:
            f.write(json.dumps(d) + "\n")
    return monta(carpeta)


tmp = tempfile.mkdtemp(prefix="puerta-")
try:
    print("")
    print("-- b. EL SUELO: la puerta nunca baja del 0,02 --")
    # Sin esto la puerta caeria al nivel del silencio y las cuatro protecciones que cuelgan de
    # UMBRAL_ALTAVOZ se activarian sin que suene nada.
    f = con_filas(os.path.join(tmp, "b"),
                  [{"desenlace": "orden", "altavoces": 0.001} for _ in range(MINIMAS + 10)])
    comp("con las llamadas en silencio, se queda en el suelo", f() == SUELO, "%.3f" % f())

    print("")
    print("-- c. EL TECHO: y nunca pasa del 0,35 --")
    # EL TECHO NO ES ADORNO: esta puerta se alimenta de un fichero que ella misma hace crecer.
    # Puerta mas alta -> pasan mas llamadas con los altavoces altos -> las que acaben en orden
    # suben el p80 -> puerta mas alta. Es un trinquete, y solo lo para el techo.
    f = con_filas(os.path.join(tmp, "c"),
                  [{"desenlace": "orden", "altavoces": 0.90} for _ in range(MINIMAS + 10)])
    comp("con las llamadas a todo volumen, se queda en el techo", f() == TECHO, "%.3f" % f())

    print("")
    print("-- d. CON POCAS LLAMADAS, EL 0,02 DE SIEMPRE --")
    f = con_filas(os.path.join(tmp, "d1"),
                  [{"desenlace": "orden", "altavoces": 0.20} for _ in range(MINIMAS - 1)])
    comp("con una menos de las que hacen falta, no aprende", f() == SUELO,
         "%d filas; hacen falta %d" % (MINIMAS - 1, MINIMAS))
    f = con_filas(os.path.join(tmp, "d2"),
                  [{"desenlace": "orden", "altavoces": 0.20} for _ in range(MINIMAS)])
    comp("  y con las justas, ya aprende", f() > SUELO, "%.3f" % f())

    print("")
    print("-- e. SOLO CUENTAN LAS QUE ACABARON EN ORDEN --")
    # ESTA ES LA COMPROBACION QUE IMPIDE EL DESTROZO: aprender de las que no sirvieron para
    # nada es aprender de los falsos positivos, que es el remedio peor que la enfermedad.
    filas = ([{"desenlace": "nada", "altavoces": 0.30} for _ in range(60)]
             + [{"desenlace": "pisada", "altavoces": 0.32} for _ in range(10)]
             + [{"desenlace": "orden", "altavoces": 0.05} for _ in range(MINIMAS)])
    f = con_filas(os.path.join(tmp, "e"), filas)
    comp("las que no sirvieron no mueven la puerta", abs(f() - 0.05) < 0.001,
         "%.3f; las de 'nada' iban a 0,30" % f())

    print("")
    print("-- f. Y NADA DE EXCEPCIONES, PASE LO QUE PASE CON EL FICHERO --")
    # El caso de verdad: el worker murio a mitad de escribir una linea. Si esto reventara, el
    # oido no arrancaria.
    comp("sin fichero, el de siempre", monta(os.path.join(tmp, "no-existe"))() == SUELO, "")
    f = con_filas(os.path.join(tmp, "f1"), [])
    comp("  con el fichero vacio, tambien", f() == SUELO, "")
    os.makedirs(os.path.join(tmp, "f2"))
    with io.open(os.path.join(tmp, "f2", "activaciones.jsonl"), "w", encoding="utf-8") as fh:
        for _ in range(MINIMAS):
            fh.write(json.dumps({"desenlace": "orden", "altavoces": 0.20}) + "\n")
        fh.write('{"desenlace": "orden", "altav')     # cortada a la mitad
    comp("  con la ultima linea cortada, aprende con las buenas",
         monta(os.path.join(tmp, "f2"))() > SUELO, "una linea rota no tumba el oido")
    f = con_filas(os.path.join(tmp, "f3"),
                  [{"desenlace": "orden", "altavoces": "alto"} for _ in range(MINIMAS + 5)])
    comp("  con el nivel escrito como texto, el de siempre", f() == SUELO, "ni revienta ni inventa")
    # EL CASO QUE DISTINGUE EL FILTRO DE LA EXCEPCION, y lo destapo una rotura que salio verde:
    # con "alto" el float() revienta y el try de fuera devuelve el suelo igual, asi que ese caso
    # NO prueba el isinstance. Un numero escrito como texto SI se convierte sin quejarse, y sin
    # el filtro se colaria en el percentil. Aqui se mezcla: si cuentan los textos, el p80 se va
    # al techo; si solo cuentan los numeros, se queda en 0,05.
    f = con_filas(os.path.join(tmp, "f4"),
                  [{"desenlace": "orden", "altavoces": "0.90"} for _ in range(60)]
                  + [{"desenlace": "orden", "altavoces": 0.05} for _ in range(MINIMAS)])
    comp("  y un numero escrito como texto no cuenta", abs(f() - 0.05) < 0.001,
         "%.3f; contandolos saldria el techo" % f())
    # NI UN NEGATIVO, que solo puede venir de un fichero corrompido.
    f = con_filas(os.path.join(tmp, "f5"),
                  [{"desenlace": "orden", "altavoces": -5.0} for _ in range(60)]
                  + [{"desenlace": "orden", "altavoces": 0.05} for _ in range(MINIMAS)])
    comp("  ni un nivel negativo", abs(f() - 0.05) < 0.001, "%.3f" % f())

    print("")
    print("-- g. Y CONTRA EL FICHERO DE VERDAD: tiene que APRENDER algo hoy --")
    # ESTE ES EL UNICO CASO QUE DISTINGUE "funciona" DE "falla y disimula". La receta que traia
    # la idea original era un no-op comprobado: pedia el nivel donde el liston duro deja fuera
    # menos del 20 % de las llamadas buenas, y activaciones.jsonl SOLO guarda las que pasaron,
    # asi que ese criterio se cumple en cualquier nivel y devolveria siempre el minimo. El
    # banco habria salido verde, el codigo habria corrido, y la puerta seguiria en 0,02 para
    # siempre sin que nadie lo notara.
    real = os.path.join(RAIZ, "pruebas", "audio", "uso")
    if not os.path.exists(os.path.join(real, "activaciones.jsonl")):
        print("       NO HAY activaciones.jsonl: este caso NO se ha comprobado")
        comp("hay llamadas apuntadas de las que aprender", False, "sin el fichero no se puede decir nada")
    else:
        # LA LISTA SE VACIA ANTES: si no, el 'any' de abajo pasaria con la linea de otro
        # caso de este mismo banco y ademas se ensenaria un numero que no es el de aqui.
        del dicho[:]
        v = monta(real)()
        comp("con tus llamadas de verdad, aprende una puerta nueva", SUELO < v <= TECHO,
             "%.3f, frente al %.3f de antes" % (v, SUELO))
        # Y SE DEJA DICHO, o no se puede auditar.
        _apr = [s for s in dicho if "aprendida" in s]
        comp("  y lo deja escrito en el log", len(_apr) == 1, _apr[0] if _apr else "no dijo nada")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("")
print("-- h. LA GUARDA DEL JUEGO, y es la que evita el destrozo --")
# Jugando, subir la puerta NO recupera ni una llamada: la rama de solo-boton esta justo detras
# y las para igual. Lo unico que cambiaria es que escribirian la marca de llamada, o sea una
# VIBRACION en el mando que braya no ha pedido. Medido: de los 153 descartes, 125 ocurrieron
# con un juego delante, y ahi viven los seis unicos textos raros del monton.
m = re.search(r"(?ms)^def umbral_confianza\(plano\):.*?\n(?=\n*\S|\Z)", SRC)
comp("se encuentra umbral_confianza", m is not None)
CUERPO_UC = m.group(0) if m else ""
if CUERPO_UC:
    _juega = [False]
    _nivel = [0.0]
    ns = {
        "CONFIANZA_MIN": 0.55, "CONFIANZA_LARGA": 0.85, "PALABRAS_SIN_SOSPECHA": 2,
        "UMBRAL_ALTAVOZ": SUELO,
        "nivel_salida": lambda: _nivel[0],
        "jugando": lambda: _juega[0],
        "umbral_altavoz": lambda: 0.177,
    }
    exec(compile(CUERPO_UC, "umbral_confianza", "exec"), ns)
    uc = ns["umbral_confianza"]
    _nivel[0] = 0.10
    _juega[0] = False
    comp("sin juego y con los altavoces a media asta, el liston normal", uc("nova") == 0.55,
         "0,10 esta por debajo de la puerta aprendida (0,177)")
    _juega[0] = True
    comp("  pero con un juego delante, el liston duro de siempre", uc("nova") == 0.85,
         "subirla ahi solo anade vibraciones que nadie pidio")
    _nivel[0] = 0.30
    _juega[0] = False
    comp("y por encima de la puerta aprendida, el duro", uc("nova") == 0.85, "0,30 > 0,177")
    _nivel[0] = 0.0
    comp("con los altavoces callados, el normal", uc("nova") == 0.55, "")
    # LA FIRMA DEL FALSO POSITIVO NO SE TOCA: mas de dos palabras siguen exigiendo 0,85 pase lo
    # que pase con los altavoces. Eso es lo que sigue tapando los engendros.
    comp("y una frase larga sigue exigiendo el duro", uc("nova por favor escucha") == 0.85,
         "la firma del falso positivo no se toca")

print("")
print("-- i. EL LOG NO MIENTE: dice la puerta que decidio --")
# Sin esto se pierde la unica medicion que existe de esta rama, que es de donde salio el numero.
m = re.search(r'_puerta = UMBRAL_ALTAVOZ if jugando\(\) else umbral_altavoz\(\)', SRC)
comp("el descarte calcula la puerta UNA vez", m is not None, "si no, el log y la decision pueden discrepar")
comp("  y la imprime en la linea", '(_alt, _puerta)' in SRC, "no la constante")
comp("  y decide con ella", "elif _alt > _puerta:" in SRC, "")

print("")
print("-- j. LAS OTRAS PROTECCIONES SIGUEN CON EL NUMERO DE SIEMPRE --")
# De UMBRAL_ALTAVOZ cuelgan mas cosas que la confianza, y esta idea toca UNA. Las demas se
# quedan con el 0,02: son las que cazan el silencio amplificado y las que frenan la ganancia.
# Ademas cuatro bancos ajenos vigilan su texto literal.
OTRAS = [
    ("el ruido de fuera", "and salida <= UMBRAL_ALTAVOZ"),
    ("el adelanto mientras Nova habla", "hay_algo and nivel_salida() <= UMBRAL_ALTAVOZ"),
    ("las llamadas flojas", "if salida <= UMBRAL_ALTAVOZ:"),
    ("la ganancia congelada", "altavoces_altos = nivel_salida() > UMBRAL_ALTAVOZ"),
    ("el techo duro de la palabra", "if salida > UMBRAL_ALTAVOZ_FUERTE:"),
]
for nombre, patron in OTRAS:
    comp("sigue con el 0,02: %s" % nombre, patron in SRC, "")

print("")
if fallos[0]:
    print("  %d caso(s) MAL" % fallos[0])
    sys.exit(1)
print("  la puerta de los altavoces se aprende de tus llamadas")
sys.exit(0)
