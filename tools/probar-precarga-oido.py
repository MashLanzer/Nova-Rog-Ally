# -*- coding: utf-8 -*-
# PRECARGAR PARAKEET AL ARRANCAR (22/09, idea 3 de IDEAS-2026-09-22.md).
#
# POR QUE. Medido en una sesion de 12 minutos: de 139 s de oido, 31 (el 22 %) fue SOLO cargar
# modelos, y la primera orden del arranque se come los 5,2 s de Parakeet ella sola. Nova
# arranco CATORCE veces el 22/09, asi que no es un caso raro: es el de todos los dias.
#
# LO QUE SE PRUEBA AQUI ES EL CERROJO, que es lo unico que puede salir caro. Hasta ahora
# modelo_parakeet solo la llamaba el hilo del microfono. Con un hilo que precarga, los dos
# pueden entrar a la vez: el de precarga empieza, llega una orden, el principal ve _parakeet
# todavia en None y carga OTRO. Son 703 MB cada uno en una consola donde quedan 1,7 GB libres.
# Se prueba con hilos DE VERDAD: una condicion de carrera no se ve leyendo el fuente.
#
# Y SE EJECUTA LA FUNCION REAL, ENTERA. La primera version de este banco sustituia la carga
# por una funcion de mentira, lo que obligaba a partir modelo_parakeet en dos... y eso puso en
# rojo SIETE comprobaciones de otros tres bancos, que vigilan que la guarda de RAM este dentro
# de modelo_parakeet, que vaya antes del try y que se selle _parakeet_uso al cargar. Asi que
# aqui no se parte nada: se le da un sherpa_onnx de mentira y se deja que la funcion haga todo
# su camino de verdad -la guarda de RAM, el glob de la carpeta, el sello, el cerrojo-.
#
#   python tools/probar-precarga-oido.py
import io
import os
import re
import sys
import threading
import time
import types

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# NO se importa wake_vosk: importarlo arranca el microfono. Se extrae con regex.
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- el sherpa_onnx de mentira: tarda, cuenta, y no carga 703 MB ------------------------
cargas = []


class _Rec(object):
    @staticmethod
    def from_transducer(**kw):
        cargas.append(time.time())
        time.sleep(0.25)
        return "el-modelo"


_falso = types.ModuleType("sherpa_onnx")
_falso.OfflineRecognizer = _Rec
sys.modules["sherpa_onnx"] = _falso

dicho = []
ns = {
    "threading": threading, "time": time, "os": os, "sys": sys,
    "_parakeet": None, "_parakeet_roto": False, "_parakeet_uso": 0.0,
    "_carga_parakeet": threading.Lock(),
    "anota": lambda m: dicho.append(m),
    "jugando": lambda: ns.get("_jugando", False),
    "_jugando": False,
    "ram_libre_mb": lambda: ns.get("_ram", 9000.0),
    "hacer_sitio_a_parakeet": lambda libre: ns.get("_ram_tras_sitio", libre),
    "_ram": 9000.0,
    # __file__ lo usa el glob de la carpeta de modelos: se le da el de verdad
    "__file__": os.path.join(RAIZ, "wake_vosk.py"),
}
for cte in ("PRECARGA_ESPERA", "RAM_MIN_PARAKEET", "HILOS_PRECISO"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s" % cte)
        sys.exit(1)
    ns[cte] = float(m.group(1))
PRECARGA_REAL = ns["PRECARGA_ESPERA"]

for nombre in ("modelo_parakeet", "precargar_parakeet"):
    mm = re.search(r"(?ms)^def %s\(\):.*?\n(?=\n*\S|\Z)" % nombre, SRC)
    if not mm:
        print("  MAL  no encuentro %s en wake_vosk.py" % nombre)
        sys.exit(1)
    exec(compile(mm.group(0), nombre, "exec"), ns)
modelo_parakeet = ns["modelo_parakeet"]
precargar_parakeet = ns["precargar_parakeet"]


def reset():
    cargas[:] = []
    dicho[:] = []
    ns["_parakeet"] = None
    ns["_parakeet_roto"] = False
    ns["_parakeet_uso"] = 0.0
    ns["_jugando"] = False
    ns["_ram"] = 9000.0


print("")
print("-- que carga de verdad por el camino de verdad --")
reset()
r = modelo_parakeet()
comp("carga y devuelve el modelo", r == "el-modelo", repr(r))
comp("y sella _parakeet_uso, o se soltaria al momento", ns["_parakeet_uso"] > 0)
comp("lo dice en el log con lo que tardo",
     any(re.search(r"parakeet cargado en [0-9.]+ s", d) for d in dicho), dicho[-1:])

print("")
print("-- EL CERROJO: varios hilos a la vez cargan UN solo modelo --")
reset()
hilos = [threading.Thread(target=modelo_parakeet) for _ in range(6)]
for h in hilos:
    h.start()
for h in hilos:
    h.join()
comp("seis hilos a la vez -> una sola carga", len(cargas) == 1,
     "%d cargas, serian %d MB" % (len(cargas), 703 * len(cargas)))
comp("y todos se llevan el mismo modelo", ns["_parakeet"] == "el-modelo")

# el caso exacto de la precarga: el hilo de fondo empieza y llega una orden en mitad
reset()
t = threading.Thread(target=modelo_parakeet)
t.start()
time.sleep(0.05)          # el de precarga ya esta dentro, cargando
modelo_parakeet()         # y llega una orden
t.join()
comp("si llega una orden mientras precarga, no carga otro", len(cargas) == 1,
     "%d cargas" % len(cargas))

print("")
print("-- y una vez cargado, ni se mira el cerrojo --")
reset()
ns["_parakeet"] = "el-modelo"
comp("con el modelo puesto, devuelve directo", modelo_parakeet() == "el-modelo")
comp("y no vuelve a cargar", not cargas)
reset()
ns["_parakeet_roto"] = True
comp("si esta roto, no se reintenta en cada orden", modelo_parakeet() is None and not cargas)

print("")
print("-- la guarda de RAM sigue mandando --")
reset()
ns["_ram"] = 100.0
ns["_ram_tras_sitio"] = 100.0
comp("sin memoria, NO carga", modelo_parakeet() is None, "%d cargas" % len(cargas))
comp("y lo dice con los numeros", any("no lo cargo" in d and "MB libres" in d for d in dicho),
     dicho[-1:])
reset()
ns["_ram"] = 100.0
ns["_ram_tras_sitio"] = 9000.0
comp("pero antes intenta hacer sitio", modelo_parakeet() == "el-modelo",
     "hacer_sitio_a_parakeet libero memoria y entonces si cargo")
ns["_ram_tras_sitio"] = None

print("")
print("-- la precarga se aparta cuando toca --")
reset()
ns["PRECARGA_ESPERA"] = 0.01
ns["_jugando"] = True
precargar_parakeet()
comp("con un juego delante, ni lo intenta", not cargas, "la RAM es del juego")

reset()
ns["PRECARGA_ESPERA"] = 0.01
precargar_parakeet()
comp("sin juego, precarga", len(cargas) == 1)
comp("y lo deja dicho", any("precargado" in d for d in dicho), dicho[-1:])

# el juego puede entrar DURANTE la espera: se mira otra vez
reset()
ns["PRECARGA_ESPERA"] = 0.15


def entra_juego():
    time.sleep(0.05)
    ns["_jugando"] = True


threading.Thread(target=entra_juego).start()
precargar_parakeet()
comp("si el juego entra durante la espera, se aparta", not cargas)

reset()
ns["PRECARGA_ESPERA"] = 0.01
ns["_parakeet"] = "el-modelo"
precargar_parakeet()
comp("si ya estaba cargado, no hace nada", not cargas)

print("")
print("-- y si la precarga falla, no se lleva el worker por delante --")
reset()
ns["PRECARGA_ESPERA"] = 0.01
ns["jugando"] = lambda: (_ for _ in ()).throw(RuntimeError("algo raro"))
try:
    precargar_parakeet()
    revento = False
except Exception:
    revento = True
comp("una precarga que revienta no sube la excepcion", not revento)
comp("y queda avisado en el log", any("la precarga de parakeet fallo" in d for d in dicho))
ns["jugando"] = lambda: ns.get("_jugando", False)
ns["PRECARGA_ESPERA"] = PRECARGA_REAL

print("")
print("-- y como se lanza --")
comp("en un hilo aparte, no bloqueando el arranque",
     "threading.Thread(target=precargar_parakeet" in SRC)
comp("daemon: no retiene al worker si tiene que salir",
     bool(re.search(r"Thread\(target=precargar_parakeet, daemon=True\)", SRC)))
i_hilo = SRC.find("Thread(target=precargar_parakeet")
i_stream = SRC.find("with sd.RawInputStream")
comp("se lanza ANTES de abrir el microfono", 0 < i_hilo < i_stream,
     "asi se calienta mientras ya esta escuchando")
comp("espera un poco: al arrancar ya se esta cargando Whisper",
     PRECARGA_REAL >= 3, "%.0f s" % PRECARGA_REAL)
comp("pero no tanto que no sirva", PRECARGA_REAL <= 20, "%.0f s" % PRECARGA_REAL)

print("")
print("-- y la carga sigue viviendo en UNA sola funcion --")
# Partirla en modelo_parakeet + _cargar_parakeet puso en rojo siete comprobaciones de tres
# bancos que la buscan por nombre. Que no vuelva a pasar.
comp("no se ha vuelto a partir en dos", "def _cargar_parakeet" not in SRC)
_m = re.search(r"(?ms)^def modelo_parakeet\(\):.*?\n(?=\n*\S|\Z)", SRC)
_cuerpo = _m.group(0) if _m else ""
for _que in ("RAM_MIN_PARAKEET", "hacer_sitio_a_parakeet", "_parakeet_uso = time.time()",
             "with _carga_parakeet", "sherpa_onnx"):
    comp("modelo_parakeet sigue conteniendo %s" % _que, _que in _cuerpo)

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  la primera orden ya no paga la carga")
sys.exit(0)
