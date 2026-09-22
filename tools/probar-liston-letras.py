# -*- coding: utf-8 -*-
# EL LISTON DE LETRAS POR SEGUNDO SE LO PONE NOVA (22/09).
#
# braya lo pidio asi: "no se puede hacer que el liston de letras sea ajustable por nova, de
# hecho todo deberia ser ajustable por ella, nova tiene que adaptarse a la situacion y cambiar
# sola". Y tenia razon por un motivo que se midio ese mismo dia: con el micro USB recien
# enchufado, el liston fijo de 4,0 mandaba a Whisper ordenes que Parakeet YA TENIA BIEN
# ('Cierra el navegador', 'Cierra los ajustes', 'Cierra el administrador'), y Whisper tardaba
# 2,1 s mas en devolverlas PEOR ('Si es a los ajutos', 'Si es la Administrador'). Un numero
# fijo causando ordenes equivocadas, que es lo peor que puede pasar.
#
# Aqui se prueban las dos piezas:
#   1) segundos_de_voz, que estaba ROTO con el micro nuevo: su corte fijo de 0,008 quedaba por
#      debajo del silencio del USB (0,018-0,025) y devolvia el fichero entero como voz.
#   2) cobertura_min(), el liston que ahora sale del ritmo de braya, con especial cuidado en
#      LO QUE MAS FACIL ES ROMPER: que el aprendizaje no se vaya solo.
#
#   python tools/probar-liston-letras.py
import io
import os
import re
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# NO se importa wake_vosk: importarlo arranca el microfono. Se extrae el codigo con regex.
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- las piezas de verdad, sacadas del archivo ---------------------------
ns = {"np": np, "re": re}
piezas = ["segundos_de_voz", "cobertura_parakeet", "cobertura_min", "apuntar_cobertura",
          "guardar_lista", "cargar_lista", "guardar_coberturas"]
for nombre in piezas:
    m = re.search(r"(?ms)^def %s\(.*?\n(?=\n*\S|\Z)" % nombre, SRC)
    if not m:
        print("  MAL  no encuentro %s en wake_vosk.py" % nombre)
        sys.exit(1)
    exec(compile(m.group(0), nombre, "exec"), ns)

# y las constantes, tal cual estan escritas
for cte in ("COBERTURA_ARRANQUE", "COBERTURA_SUELO", "COBERTURA_TECHO",
            "COBERTURA_FRACCION", "COBERTURA_MEMORIA", "COBERTURA_MINIMAS"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s" % cte)
        sys.exit(1)
    # los tamaños son enteros (se usan para cortar listas); los listones, decimales
    ns[cte] = int(m.group(1)) if cte in ("COBERTURA_MEMORIA", "COBERTURA_MINIMAS") else float(m.group(1))
ns["coberturas"] = []
# lo que guardar/cargar necesitan del worker, de mentira pero con el mismo comportamiento
import tempfile
ns["RUTA_COBERTURAS"] = os.path.join(tempfile.gettempdir(), "cob-prueba-%d.txt" % os.getpid())
ns["dispositivo"] = "Microfono (USB PnP Sound Device)"
ns["anota"] = lambda *a, **k: None
def _escribir(ruta, contenido):
    io.open(ruta, "w", encoding="utf-8").write(contenido)
ns["escribir"] = _escribir

segundos_de_voz = ns["segundos_de_voz"]
cobertura_min = ns["cobertura_min"]
apuntar_cobertura = ns["apuntar_cobertura"]


def reset(valores=()):
    ns["coberturas"][:] = list(valores)


# EL GENERADOR ES PROPIO, no numpy.random: en la consola de braya una directiva de Control de
# aplicaciones de Windows bloquea el DLL de numpy.random y lo tumba al importarlo. Y de paso
# el banco sale igual en cada vuelta, que es lo que se quiere de una prueba.
def _ruido(n, semilla):
    """Ruido repetible entre -1 y 1, con un congruencial de toda la vida."""
    x = semilla
    v = []
    for _ in range(n):
        x = (1103515245 * x + 12345) % 2147483648
        v.append(x / 1073741824.0 - 1.0)
    return np.array(v, dtype=np.float32)


# EL ALTO ES EL DE SU VOZ DE VERDAD (0,065 de pico por el micro USB, del log del 22/09), no un
# grito. Con una voz mucho mas alta que el ruido el corte viejo tambien acertaba, y entonces la
# prueba no probaria nada: lo que rompia el 0,008 fijo era justo que su voz y el ruido del USB
# se parecen (0,065 contra 0,022, tres veces, no cien).
def audio_de(seg_voz, seg_silencio, suelo, alto=0.065):
    """Un audio de mentira: silencio al suelo que se le diga, y voz en medio."""
    n_s = int(seg_silencio * 16000 / 2)
    n_v = int(seg_voz * 16000)
    sil = _ruido(n_s, 7) * suelo
    voz = _ruido(n_v, 99) * alto
    return np.concatenate([sil, voz, sil]).astype(np.float32)


# =========================================================================
print("")
print("-- 1) medir la voz: el corte sale del propio audio --")
# EL CASO QUE LO MOTIVA. Mismo audio, mismo habla, dos microfonos: el array de Realtek
# (silencio 0,001) y el USB de braya (silencio 0,022). Antes el USB devolvia el fichero
# entero; ahora los dos tienen que dar aproximadamente los mismos segundos de voz.
limpio = audio_de(2.0, 3.0, suelo=0.001)
sucio = audio_de(2.0, 3.0, suelo=0.022)
v_lim, v_suc = segundos_de_voz(limpio), segundos_de_voz(sucio)
comp("con un micro limpio mide la voz, no el fichero", 1.5 <= v_lim <= 2.6, "%.1f s de 5,0" % v_lim)
comp("con el micro USB de braya, tambien", 1.5 <= v_suc <= 2.6, "%.1f s de 5,0 (antes: 5,0)" % v_suc)
comp("y los dos microfonos dan casi lo mismo", abs(v_lim - v_suc) < 0.5,
     "limpio %.1f, USB %.1f" % (v_lim, v_suc))

# EL FALLO DE VERDAD, tal cual estaba: con el corte fijo de 0,008 el audio sucio daba 5,0
viejo = np.where(np.sqrt(np.mean(sucio[:sucio.size // 480 * 480].reshape(-1, 480) ** 2, axis=1))
                 > max(0.008, 0.15 * float(np.percentile(np.sqrt(np.mean(
                     sucio[:sucio.size // 480 * 480].reshape(-1, 480) ** 2, axis=1)), 90))))[0]
v_viejo = (viejo[-1] - viejo[0]) * 0.03 if viejo.size else 0.0
comp("(comprobado: con el corte viejo daba el fichero entero)", v_viejo > 4.5, "%.1f s" % v_viejo)

# y un audio mudo del todo no se inventa voz
comp("un audio en silencio no tiene voz", segundos_de_voz(audio_de(0.0, 4.0, 0.001)) < 0.5)
comp("un audio vacio no revienta", segundos_de_voz(np.zeros(0, dtype=np.float32)) == 0.0)

print("")
print("-- 2) el liston: de donde sale --")
reset()
comp("sin muestras suyas, el de siempre", cobertura_min() == ns["COBERTURA_ARRANQUE"],
     "%.1f" % cobertura_min())
reset([13.7] * int(ns["COBERTURA_MINIMAS"] - 1))
comp("con menos de las minimas, sigue el de siempre", cobertura_min() == ns["COBERTURA_ARRANQUE"],
     "%.1f con %d muestras" % (cobertura_min(), len(ns["coberturas"])))

# EL RITMO DE VERDAD DE braya, medido el 22/09 sobre sus 395 grabaciones emparejadas:
# mediana 13,7 letras/s. 13,7 * 0,30 = 4,1, casi el 4,0 que se calibro a mano el 15/09.
reset([7.9, 10.5, 13.7, 16.4, 20.0] * 8)
lis = cobertura_min()
comp("con su ritmo real (mediana 13,7), da el 4,0 de siempre", 3.6 <= lis <= 4.6, "%.2f" % lis)

print("")
print("-- 3) y se adapta cuando cambia la situacion --")
reset([6.0] * 30)     # habla mas despacio, o el micro entra distinto
comp("si braya habla mas despacio, el liston baja", cobertura_min() < 4.0, "%.2f" % cobertura_min())
reset([22.0] * 30)    # habla rapido y seguido
comp("si habla mas rapido, el liston sube", cobertura_min() > 4.5, "%.2f" % cobertura_min())

print("")
print("-- 4) LO QUE MAS FACIL ES ROMPER: que no se vaya solo --")
# EL BUCLE DE REALIMENTACION. Si solo se apuntaran las coberturas que YA pasan el liston, la
# mediana subiria en cada vuelta y el liston con ella, hasta mandarlo todo a Whisper otra vez
# -que es justo lo que veniamos a arreglar-. Por eso apuntar_cobertura se llama ANTES de
# decidir y con todas. Aqui se simulan 400 frases suyas y se comprueba que el liston se queda
# quieto en vez de treparse.
_rr = _ruido(900, 11)
_ri = [0]


def ritmo_suyo():
    """Una cobertura como las suyas: mediana 13,7 con la dispersion real."""
    _ri[0] = (_ri[0] + 1) % 900
    return max(0.5, 13.7 + float(_rr[_ri[0]]) * 7.0)
reset()
historia = []
for _ in range(400):
    c = ritmo_suyo()                            # su ritmo, con la dispersion real
    apuntar_cobertura(c)                        # se apunta SIEMPRE, pase o no
    historia.append(cobertura_min())
comp("tras 400 frases suyas el liston no se ha trepado", historia[-1] < 5.5,
     "empezo en %.2f y acabo en %.2f" % (historia[20], historia[-1]))
comp("y se mueve poco: es un liston, no un pendulo", max(historia[30:]) - min(historia[30:]) < 1.2,
     "de %.2f a %.2f" % (min(historia[30:]), max(historia[30:])))

# y la version rota, para dejar escrito por que se hace asi
reset()
malo = []
for _ in range(400):
    c = ritmo_suyo()
    if c >= cobertura_min():        # <-- el fallo: apuntar solo lo que aprueba
        apuntar_cobertura(c)
    malo.append(cobertura_min())
comp("(y si solo se apuntara lo aprobado, SI subiria)", malo[-1] >= historia[-1],
     "roto %.2f vs bueno %.2f" % (malo[-1], historia[-1]))

# el codigo, no la teoria: apuntar tiene que ir antes del if
orden = re.search(r"apuntar_cobertura\(c\)(.{0,200}?)if c < liston", SRC, re.S)
comp("en el codigo, se apunta ANTES de decidir", orden is not None)

print("")
print("-- 5) el suelo y el techo, que un aprendizaje sin frenos se va --")
reset([0.5] * 40)
comp("con puros recortes no baja del suelo", cobertura_min() == ns["COBERTURA_SUELO"],
     "%.2f" % cobertura_min())
reset([60.0] * 40)
comp("con frases larguisimas no sube del techo", cobertura_min() == ns["COBERTURA_TECHO"],
     "%.2f" % cobertura_min())
comp("el suelo deja fuera el caso del Xbox (1,5 letras/s)", 1.5 < ns["COBERTURA_SUELO"])
comp("y el techo no pasa del 4,0 de siempre por mucho", ns["COBERTURA_TECHO"] <= 8.0)

print("")
print("-- 6) la memoria no crece sin parar --")
reset()
for i in range(500):
    apuntar_cobertura(10.0 + i % 7)
comp("se recuerdan como mucho COBERTURA_MEMORIA", len(ns["coberturas"]) == int(ns["COBERTURA_MEMORIA"]),
     "%d guardadas" % len(ns["coberturas"]))
comp("y son las ultimas, no las primeras", ns["coberturas"][-1] == 10.0 + 499 % 7)
reset()
apuntar_cobertura(0.0)
apuntar_cobertura(-3.0)
comp("una cobertura imposible no entra", len(ns["coberturas"]) == 0)

print("")
print("-- 7) el numero fijo ya no manda en ningun sitio --")
comp("PARAKEET_COBERTURA_MIN ha desaparecido", "PARAKEET_COBERTURA_MIN" not in SRC)
comp("quien decide llama a cobertura_min()", "liston = cobertura_min()" in SRC)
comp("y el log dice el liston de hoy, no un numero de piedra",
     "mi liston de hoy" in SRC)

print("")
print("-- 8) punta a punta, con los casos reales del 22/09 --")
# 'Cierra los ajustes' con el micro USB: 18 letras, ~2,1 s de voz de verdad (el log decia 5,3)
casos = [
    ("Cierra los ajustes", 2.1, True),
    ("Cierra el navegador", 2.9, True),
    ("Cierra el administrador", 2.9, True),
    ("Dime que ves en mi pantalla", 2.1, True),
    ("Se nave", 9.7, False),          # el recorte de verdad: 7 letras en 9,7 s de voz
    ("Ahora esta", 3.1, False),
]
reset([7.9, 10.5, 13.7, 16.4, 20.0] * 8)
lis = cobertura_min()
for texto, seg, deberia in casos:
    letras = len(re.sub(r"[^\w]|_|\d", "", texto))
    c = letras / max(seg, 0.3)
    comp("%-26s %s" % (texto[:26], "se entrega" if deberia else "se manda a Whisper"),
         (c >= lis) == deberia, "%.1f letras/s, liston %.1f" % (c, lis))

print("")
print("-- 9) lo aprendido sobrevive al reinicio, y va con su microfono --")
# El 22/09 Nova arranco CATORCE veces en un dia. Sin esto, el liston volvia al de partida en
# cada arranque y no llegaba a usarse nunca lo aprendido. Se guarda con las mismas reglas que
# la ganancia -y por el mismo motivo: heredar la calibracion de otro microfono fue un fallo de
# verdad esa misma noche-, asi que aqui se prueba la pareja generica guardar_lista/cargar_lista,
# que es la que usan tanto el liston de letras como las rafagas de la puerta.
guardar_lista = ns["guardar_lista"]
cargar_lista = ns["cargar_lista"]
RUTA = ns["RUTA_COBERTURAS"]
MEM = ns["COBERTURA_MEMORIA"]
USB = "Microfono (USB PnP Sound Device)"
REALTEK = "Microphone Array (Realtek(R) Audio)"

reset([7.9, 10.5, 13.7, 16.4, 20.0] * 8)
antes = cobertura_min()
guardar_lista(RUTA, ns["coberturas"])
reset()                      # como si el worker acabara de arrancar
ns["coberturas"][:] = cargar_lista(RUTA, MEM)
comp("tras reiniciar, el liston es el mismo", abs(cobertura_min() - antes) < 0.01,
     "antes %.2f, ahora %.2f" % (antes, cobertura_min()))
comp("y con las mismas frases", len(ns["coberturas"]) == 40, "%d" % len(ns["coberturas"]))

# EL FALLO QUE YA PASO CON LA GANANCIA: heredar la calibracion de otro microfono.
ns["dispositivo"] = REALTEK
ns["coberturas"][:] = cargar_lista(RUTA, MEM)
comp("lo aprendido con OTRO micro no se hereda", len(ns["coberturas"]) == 0,
     "%d frases heredadas" % len(ns["coberturas"]))
comp("y entonces arranca con el de siempre", cobertura_min() == ns["COBERTURA_ARRANQUE"])
ns["dispositivo"] = USB

# y lo que no puede pasar
io.open(RUTA, "w", encoding="utf-8").write("esto no es un numero|" + USB)
comp("un fichero roto no revienta ni envenena el liston", cargar_lista(RUTA, MEM) == [])
io.open(RUTA, "w", encoding="utf-8").write("5.0,999999,7.0|" + USB)
comp("un valor imposible tira el fichero entero", cargar_lista(RUTA, MEM) == [],
     "medio bueno y medio corrupto es peor que nada: el percentil saldria torcido")
io.open(RUTA, "w", encoding="utf-8").write("5.0,7.0")   # sin micro: formato viejo
comp("sin nombre de micro, no vale para nadie", cargar_lista(RUTA, MEM) == [])
io.open(RUTA, "w", encoding="utf-8").write("0.5,0.9|" + USB)
comp("y el tope de valor se respeta", cargar_lista(RUTA, MEM, 0.4) == [],
     "con tope 0,4 un 0,9 tira el fichero: es lo que protege a las rafagas")
try:
    os.remove(RUTA)
except OSError:
    pass
comp("sin fichero, se empieza de cero sin quejarse", cargar_lista(RUTA, MEM) == [])

# no se guarda mas de lo que cabe
reset()
for i in range(200):
    apuntar_cobertura(10.0 + i % 5)
comp("en disco no se acumulan mas de COBERTURA_MEMORIA",
     len(cargar_lista(RUTA, MEM)) <= MEM, "%d" % len(cargar_lista(RUTA, MEM)))
comp("y apuntar_cobertura guarda sola, sin que nadie se lo pida",
     "guardar_coberturas()" in SRC)
try:
    os.remove(RUTA)
except OSError:
    pass

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  el liston se lo pone Nova, y no se le va solo")
sys.exit(0)
