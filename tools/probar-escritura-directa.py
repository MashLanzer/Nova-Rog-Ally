# -*- coding: utf-8 -*-
"""Que aprenda que fichero no la deja cambiarlo de golpe (27/09, idea 93 de las 121).

EL DATO: 37 fallos "escritura atomica fallida ... [WinError 5] Acceso denegado" en ocho dias
distintos; 21 de ui-nivel.txt, 14 de dictado-parcial.txt y 2 de escucha-estado.txt. Y lo que de
verdad importa: el 22/09 esto se dio por arreglado -se anadio FileShare.Delete en los dos
lectores- y DESPUES hay TRECE mas: 2 el 23/09, 2 el 24/09, OCHO el 25/09 y uno HOY, el 27/09.
El arreglo no lo arreglo. Con el tope de 50 avisos por proceso, 37 es un suelo.

LO QUE ESTE BANCO PROTEGE:
  1. que el contenido llegue SIEMPRE al fichero, con fallo o sin el (es lo unico que no se
     puede perder: por ahi salen la orden, la confirmacion y el parcial)
  2. que hagan falta TRES fallos del MISMO fichero, no uno
  3. que despues NO se vuelva a intentar el .tmp, que es de lo que va la idea
  4. que un fichero no contagie a otro
  5. y que no se anote una linea por palabra oida, que es el ruido que se quita

    python tools/probar-escritura-directa.py
"""
import ast
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fuente = open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
arbol = ast.parse(fuente)
# SE SACA DEL ARCHIVO DE VERDAD, no se copia aqui: wake_vosk.py abre el microfono y los modelos
# al importarlo, asi que no se puede importar.
QUIERO = {"escribir", "FALLOS_PARA_DIRECTO", "_fallos_fichero", "_directo",
          "MAX_AVISOS_ESCRIBIR", "_avisos_escribir"}
trozos = []
vistos = set()
for n in arbol.body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in QUIERO:
        trozos.append(ast.get_source_segment(fuente, n))
        vistos.add(nombre)

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det else ""))
    if not ok:
        fallos += 1


comp("se saca todo del archivo", vistos == QUIERO, "" if vistos == QUIERO else "falta %s" % (QUIERO - vistos))
if vistos != QUIERO:
    sys.exit(1)

# EL MUNDO DE MENTIRA. Se dobla lo de fuera -el aviso y el os.replace de Windows-, nunca la
# funcion que se prueba. Y el disco es de verdad: un directorio temporal.
import tempfile

carpeta = tempfile.mkdtemp(prefix="nova-escritura-")
apuntes = []


class OsFalso(object):
    """El os de verdad, salvo que replace() falla para los ficheros que se le digan.

    Es exactamente lo que hace Windows cuando el lector tiene el fichero abierto sin
    FileShare.Delete: el open() del .tmp funciona y el os.replace se cae con Acceso denegado.
    """

    def __init__(self, real):
        self.path = real.path
        self._real = real
        self.fallar = set()
        self.replaces = 0

    def replace(self, a, b):
        self.replaces += 1
        if os.path.basename(b) in self.fallar:
            raise PermissionError("[WinError 5] Acceso denegado: '%s'" % b)
        return self._real.replace(a, b)


osf = OsFalso(os)
ns = {"os": osf, "anota": lambda m: apuntes.append(m)}
exec(chr(10).join(trozos), ns)
escribir = ns["escribir"]


def leer(nombre):
    with open(os.path.join(carpeta, nombre), encoding="utf-8") as f:
        return f.read()


def reset():
    del apuntes[:]
    ns["_fallos_fichero"].clear()
    ns["_directo"].clear()
    ns["_avisos_escribir"] = 0
    osf.fallar = set()
    osf.replaces = 0


ruta_ui = os.path.join(carpeta, "ui-nivel.txt")
ruta_par = os.path.join(carpeta, "dictado-parcial.txt")

try:
    print("")
    print("-- 1. CUANDO TODO VA BIEN, NADA CAMBIA --")
    reset()
    escribir(ruta_ui, "0.42")
    comp("escribe", leer("ui-nivel.txt") == "0.42")
    comp("  de golpe, con el .tmp", osf.replaces == 1, "%d replace(s)" % osf.replaces)
    comp("  y sin decir nada", apuntes == [], str(apuntes))
    comp("  y no se rinde con ningun fichero", len(ns["_directo"]) == 0)

    print("")
    print("-- 2. EL CASO REAL: ui-nivel.txt NO SE DEJA --")
    reset()
    osf.fallar = {"ui-nivel.txt"}
    escribir(ruta_ui, "uno")
    comp("2a. lo que iba ahi llega igual", leer("ui-nivel.txt") == "uno", "es lo unico que no se puede perder")
    comp("2b. y se dice que fallo", len([a for a in apuntes if "atomica fallida" in a]) == 1, str(len(apuntes)))
    comp("2c. con un fallo NO se rinde", "ui-nivel.txt" not in ns["_directo"], "un choque suelto no condena un fichero")
    escribir(ruta_ui, "dos")
    comp("2d. con dos tampoco", "ui-nivel.txt" not in ns["_directo"])
    escribir(ruta_ui, "tres")
    comp("2e. al TERCERO si", "ui-nivel.txt" in ns["_directo"], "FALLOS_PARA_DIRECTO = %d" % ns["FALLOS_PARA_DIRECTO"])
    comp("2f. y lo dice una vez, con la cuenta", len([a for a in apuntes if "no deja cambiarlo de golpe" in a]) == 1,
         [a for a in apuntes if "no deja cambiarlo de golpe" in a])
    comp("2g. el contenido sigue llegando", leer("ui-nivel.txt") == "tres")

    print("")
    print("-- 3. Y A PARTIR DE AHI YA NO LO INTENTA (de esto va la idea) --")
    antes = osf.replaces
    cuantos = len(apuntes)
    for i in range(30):
        escribir(ruta_ui, "nivel %d" % i)
    comp("3a. ni un intento atomico mas", osf.replaces == antes, "%d replace(s) en 30 escrituras" % (osf.replaces - antes))
    comp("3b. ni una linea mas en el registro", len(apuntes) == cuantos, "%d linea(s) nuevas" % (len(apuntes) - cuantos))
    comp("3c. y el contenido sigue llegando entero", leer("ui-nivel.txt") == "nivel 29", "por aqui salen las ordenes")

    print("")
    print("-- 4. UN FICHERO NO CONTAGIA A OTRO --")
    comp("4a. el otro no esta en la lista", "dictado-parcial.txt" not in ns["_directo"])
    escribir(ruta_par, "abre st")
    comp("4b. y sigue escribiendose de golpe", osf.replaces == antes + 1, "%d" % (osf.replaces - antes))
    comp("4c. con su contenido", leer("dictado-parcial.txt") == "abre st")
    comp("4d. y sin contar fallos suyos", ns["_fallos_fichero"].get("dictado-parcial.txt", 0) == 0)

    print("")
    print("-- 5. LOS FALLOS SE CUENTAN POR NOMBRE, NO EN UN MONTON --")
    reset()
    osf.fallar = {"ui-nivel.txt", "dictado-parcial.txt"}
    escribir(ruta_ui, "a")
    escribir(ruta_par, "b")
    escribir(ruta_ui, "c")
    escribir(ruta_par, "d")
    comp("5a. dos fallos de cada, ninguno se rinde", len(ns["_directo"]) == 0,
         "%s" % sorted(ns["_directo"]))
    comp("5b. y cada uno lleva su cuenta", ns["_fallos_fichero"] == {"ui-nivel.txt": 2, "dictado-parcial.txt": 2},
         str(ns["_fallos_fichero"]))
    escribir(ruta_ui, "e")
    comp("5c. el tercero de uno solo rinde a ese", sorted(ns["_directo"]) == ["ui-nivel.txt"], str(sorted(ns["_directo"])))

    print("")
    print("-- 6. SI NI DIRECTO SE PUEDE, ESO SI ES GRAVE Y SE DICE --")
    reset()
    osf.fallar = {"ui-nivel.txt"}
    for i in range(3):
        escribir(ruta_ui, "x")
    del apuntes[:]
    # ahora la carpeta desaparece: ni directo se puede escribir
    import shutil

    shutil.rmtree(carpeta)
    escribir(ruta_ui, "y")
    comp("6a. se dice que se perdio", len([a for a in apuntes if "NO PUDE ESCRIBIR" in a]) == 1, str(apuntes))
    comp("6b. y no revienta la escucha", True, "un except por encima, como antes")
    os.makedirs(carpeta, exist_ok=True)

    print("")
    print("-- 7. EL TOPE DE AVISOS SIGUE PROTEGIENDO --")
    reset()
    osf.fallar = {"ui-nivel.txt"}
    ns["_avisos_escribir"] = ns["MAX_AVISOS_ESCRIBIR"]
    escribir(ruta_ui, "z")
    comp("7a. con el tope gastado no se anota el fallo suelto", len([a for a in apuntes if "atomica fallida" in a]) == 0)
    escribir(ruta_ui, "z")
    escribir(ruta_ui, "z")
    comp("7b. pero el 'me rindo' SI se dice", len([a for a in apuntes if "no deja cambiarlo" in a]) == 1,
         "es una sola linea por sesion y fichero, no depende del tope")

    print("")
    print("-- 8. Y LA LISTA DURA SOLO LA SESION --")
    # esto es la guarda que hace que el arreglo sea reversible: si el problema era pasajero, el
    # siguiente arranque vuelve a intentarlo atomico. Se comprueba de la unica forma honesta:
    # que no se escriba en ningun sitio.
    comp("8a. no se guarda en disco en ninguna parte", "_directo" not in fuente.split("def escribir")[0].replace("_directo = set()", ""),
         "solo la declaracion, nada de open/json")
    cuerpo = ast.get_source_segment(fuente, [n for n in arbol.body if getattr(n, "name", "") == "escribir"][0])
    comp("8b. escribir() no lee ni escribe ninguna lista de fuera", ("json" not in cuerpo) and ("_directo = " not in cuerpo))
    comp("8c. y el umbral sale del archivo", "FALLOS_PARA_DIRECTO = 3" in fuente, "tres del mismo fichero")
finally:
    import shutil

    shutil.rmtree(carpeta, ignore_errors=True)

print("")
if fallos:
    print("  %d MAL" % fallos)
    sys.exit(1)
print("  cada fichero aprende si la deja cambiarlo de golpe")
sys.exit(0)
