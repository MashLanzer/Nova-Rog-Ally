# -*- coding: utf-8 -*-
# UN TOPE DE RELOJ EN LA TRANSCRIPCION (22/09, idea 4 de IDEAS-2026-09-22.md).
#
# MEDIDO sobre las 812 transcripciones del log: 2,3 s de mediana, 15,1 el p90, 27,5 el p95...
# y 238,9 la peor. Con TRANSCRIBIR_MAX limitando el audio a 15 segundos, tardar 238 no es
# audio largo: es la maquina ahogada. Y pasado cierto punto el trabajo ya no le sirve a nadie,
# porque el asistente deja de esperar el repaso a los 15 s ($ReintentoMaxMs); lo que llegue
# despues se tira igual, pero mientras tanto este hilo esta sordo.
#
# Con 30 s se corta el 4,1 % (33 de 812) y se ahorran 838 s, y es el doble del p90, asi que no
# se lleva por delante ninguna transcripcion normal.
#
# Aqui se ejecuta transcribir_whisper DE VERDAD, con un modelo de mentira que entrega los
# segmentos despacio. Comprobar el fuente no bastaria: lo que importa es que al cortar
# DEVUELVA lo que ya tiene en vez de perderlo, y eso solo se ve ejecutandolo.
#
#   python tools/probar-tope-reloj.py
import io
import os
import re
import sys
import time

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# NO se importa wake_vosk: importarlo arranca el microfono. Se extrae con regex.
SRC = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


# ---- la funcion de verdad, con el mundo de fuera simulado ------------------------------
dicho = []
ns = {
    "np": np, "re": re, "time": time, "os": os,
    "TASA": 16000,
    "anota": lambda m: dicho.append(m),
    "NIVEL": "",                     # no se escribe el fichero de confianza
    "idioma_dictado": lambda: "es",
    "PROMPT_ORDENES": "",
    "limpiar_whisper": lambda t: t,
    "es_eco_del_ejemplo": lambda t: False,
    "escribir": lambda r, c: None,
    "whisper": None,
    "_ultima_seguridad": None,
}
for cte in ("TRANSCRIBIR_MAX", "TRANSCRIBIR_TOPE_S"):
    m = re.search(r"^%s = ([0-9.]+)" % cte, SRC, re.M)
    if not m:
        print("  MAL  falta la constante %s" % cte)
        sys.exit(1)
    ns[cte] = float(m.group(1))

m = re.search(r"(?ms)^def transcribir_whisper\(.*?\n(?=\n*\S|\Z)", SRC)
if not m:
    print("  MAL  no encuentro transcribir_whisper en wake_vosk.py")
    sys.exit(1)
exec(compile(m.group(0), "transcribir_whisper", "exec"), ns)
transcribir_whisper = ns["transcribir_whisper"]
TOPE = ns["TRANSCRIBIR_TOPE_S"]


class Trozo(object):
    def __init__(self, texto):
        self.text = texto
        self.avg_logprob = -0.3


class ModeloLento(object):
    """Entrega cada segmento tras `por_trozo` segundos, como hace faster-whisper:
    el trabajo se hace al PEDIR el segmento, no al llamar a transcribe()."""

    def __init__(self, textos, por_trozo):
        self.textos = textos
        self.por_trozo = por_trozo
        self.pedidos = 0

    def transcribe(self, audio, **kw):
        def gen():
            for t in self.textos:
                time.sleep(self.por_trozo)
                self.pedidos += 1
                yield Trozo(t)
        return gen(), None


def audio(seg):
    # ruido flojo: da igual el contenido, el modelo es de mentira
    return (np.arange(int(seg * 16000)) % 97).astype(np.int16)


print("")
print("-- lo normal no se toca --")
dicho[:] = []
mod = ModeloLento(["abre", "steam"], 0.05)
t0 = time.time()
r = transcribir_whisper([audio(3.0)], modelo=mod)
comp("una transcripcion rapida sale entera", r.strip() == "abre steam", repr(r))
comp("y no se queja de ningun tope", not any("lo dejo aqui" in d for d in dicho))
comp("se pidieron todos los segmentos", mod.pedidos == 2, "%d" % mod.pedidos)

print("")
print("-- y la que se eterniza, se corta --")
# EL CASO DEL LOG: 238,9 s. Aqui se acelera el reloj usando un tope pequeno, porque la
# prueba no puede tardar de verdad medio minuto: lo que se comprueba es la LOGICA.
ns["TRANSCRIBIR_TOPE_S"] = 0.25
dicho[:] = []
mod = ModeloLento(["uno", "dos", "tres", "cuatro", "cinco", "seis"], 0.12)
r = transcribir_whisper([audio(3.0)], modelo=mod)
comp("corta antes de pedirlos todos", mod.pedidos < 6, "pidio %d de 6" % mod.pedidos)
comp("y DEVUELVE lo que ya tenia, no lo pierde", r.strip().startswith("uno"), repr(r))
comp("lo deja dicho en el log", any("lo dejo aqui" in d for d in dicho),
     [d for d in dicho if "lo dejo" in d][:1])
comp("y dice cuanto llevaba y cual era el tope",
     any(re.search(r"llevo [0-9.]+ s y lo dejo aqui \(tope [0-9.]+ s\)", d) for d in dicho))
ns["TRANSCRIBIR_TOPE_S"] = TOPE

print("")
print("-- el corte de 'ya no hace falta' sigue mandando --")
# seguir() es el corte de siempre: el asistente ya no quiere la respuesta. Va ANTES que el
# tope de reloj, porque es una razon mejor para parar.
dicho[:] = []
mod = ModeloLento(["uno", "dos", "tres"], 0.02)
r = transcribir_whisper([audio(3.0)], modelo=mod, seguir=lambda: False)
comp("si ya no hace falta, corta en el primero", mod.pedidos == 1, "%d" % mod.pedidos)
comp("y lo dice con su motivo", any("ya no hace falta" in d for d in dicho))
i_seguir = SRC.find("if seguir is not None and not seguir():")
i_tope = SRC.find("if time.time() - t0 > TRANSCRIBIR_TOPE_S:")
comp("en el codigo, seguir() se mira antes que el reloj", 0 < i_seguir < i_tope)

print("")
print("-- y lo que no puede pasar --")
dicho[:] = []
mod = ModeloLento([], 0.01)
r = transcribir_whisper([audio(3.0)], modelo=mod)
comp("sin segmentos no revienta", r == "", repr(r))
comp("un audio diminuto se descarta antes de nada", transcribir_whisper([audio(0.1)], modelo=mod) == "")
comp("sin modelo tampoco revienta", transcribir_whisper([audio(3.0)], modelo=None) == "")

print("")
print("-- el tope es razonable para lo que tarda de verdad --")
# p90 = 15,1 s sobre 812 transcripciones del log: el tope tiene que dejarlo pasar holgado
comp("el tope dobla el p90 medido (15,1 s)", TOPE >= 30, "%.0f s" % TOPE)
comp("y no es tan grande que no corte nada", TOPE <= 60, "%.0f s" % TOPE)
comp("va por debajo de la peor medida (238,9 s)", TOPE < 238)

print("")
print("-- y queda escrito que esto NO lo cubre todo --")
# El trabajo se hace al PEDIR cada segmento: si el primero tarda los 30 s enteros, aqui no
# se llega a entrar. Que quede dicho en el codigo, para que nadie lo de por resuelto.
comp("el codigo avisa de lo que no cubre", "LO QUE ESTO NO CUBRE" in SRC)
comp("y adonde mirar para la causa de fondo",
     "plazo_soltar" in SRC and "RAM_MIN_PRECISO" in SRC)

if fallos:
    print("")
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("")
print("  una transcripcion no puede eternizarse")
sys.exit(0)
