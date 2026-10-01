# Worker de SUBTITULOS del audio del juego (01/10/2026, la 17 de las 20 funciones nuevas).
#
# Oye lo que SALE por los altavoces -no el microfono- y lo escribe. Es la mas cara de las 20
# y por eso es la unica que lleva un numero medido delante de cada decision.
#
# LO QUE SE MIDIO ANTES DE ESCRIBIR UNA LINEA (01/10, en esta consola, con la bateria encima):
#   - capturar el audio del sistema (WASAPI loopback) cuesta 8,7 % de un nucleo. Se puede.
#   - con NADA sonando, el pico de amplitud es EXACTAMENTE 0,00000. Asi que la puerta de
#     "no hay nada que subtitular" es gratis y exacta: no hace falta un VAD para eso.
#   - Whisper tiny int8 sobre trozos de 6 s:
#         1 hilo  -> x0,30 de tiempo real, 1,8 s de retraso,  99 % de UN nucleo
#         2 hilos -> x0,20 de tiempo real, 1,2 s de retraso, 197 %
#         4 hilos -> x0,20 de tiempo real, 1,2 s de retraso, 385 %
#     Cuatro hilos es dinero tirado: igual de rapido que dos y el doble de nucleos. Va con UN
#     HILO (regla 5: el juego necesita los nucleos). Un subtitulo tarda 1,8 s en salir.
#   - detectar el idioma cuesta 2,7 s POR TROZO, asi que se detecta UNA VEZ y se fija.
#
# POR QUE NO TRADUCE, que era la mitad bonita de la idea: Whisper solo traduce HACIA ingles.
# Para el espanol hay que pasar por el modelo local, y eso tambien se midio: 4,13 s con
# llama3.2:1b y 5,04 s con qwen2.5:3b. Encima de los 1,8 s de transcribir son SIETE SEGUNDOS
# de retraso, y ademas traducia mal: "the top of the tower" -> "el topo del castillo", "the
# bridge is out" -> "El puente esta fuera", "he sold us out" -> "Se entrego a nosotros". Un
# subtitulo que llega siete segundos tarde y mal no es un subtitulo.
# ASI QUE LOS SUBTITULOS SALEN EN EL IDIOMA QUE HABLA EL JUEGO. Para el espanol esta la otra
# mitad, que SI puede pagar los 5 s porque braya la pide y espera: "que ha dicho", que coge
# los ultimos segundos de aqui (op "ultimo") y los traduce arriba.
#
# Pedidos por stdin, un JSON por linea:
#   {"op": "ultimo"}      lo oido en los ultimos segundos, para traducirlo arriba
#   {"op": "fin"}         se acabo (tambien vale cerrar stdin)
# Por stdout, un JSON por linea y SOLO ASCII (PowerShell lee con la codificacion de la
# consola y romperia los acentos; mismo trato que charla_worker.py):
#   {"ev": "listo"}                                  el modelo esta cargado y ya oye
#   {"ev": "sub", "texto": "...", "idioma": "en", "ms": 1800}   un subtitulo
#   {"ev": "idioma", "idioma": "en", "conf": 0.93}   lo que habla el juego, ya fijado
#   {"ev": "ultimo", "texto": "..."}                 respuesta a op "ultimo"
#   {"ev": "err", "texto": "..."}                    no pudo
#   {"ev": "info", "texto": "..."}                   para el log
#
# Uso:  python subtitulos.py [modelo] [segundos_por_trozo]

import sys
import os
import json
import time
import threading
import queue


# SALIDA SIEMPRE ASCII Y SIEMPRE AL MOMENTO: si se queda en el bufer, el subtitulo llega
# cuando ya no sirve.
def di(d):
    try:
        sys.stdout.write(json.dumps(d, ensure_ascii=True) + "\n")
        sys.stdout.flush()
    except Exception:
        pass


MODELO = sys.argv[1] if len(sys.argv) > 1 else "tiny"
TROZO = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
SR = 16000
# EL SOLAPE ES LO QUE SALVA LA FRASE PARTIDA: sin el, una frase a caballo de dos trozos sale
# cortada por la mitad en los dos. Un segundo basta y cuesta un sexto de trozo.
SOLAPE = 1.0
# EL SILENCIO NO SE TRANSCRIBE. Medido: con nada sonando el pico es 0,00000 exacto, pero un
# juego con musica de fondo y sin voz tampoco merece una llamada a Whisper, asi que el liston
# no es cero: es un pico audible de verdad.
PICO_MIN = 0.012
# CUANTO SE GUARDA PARA "que ha dicho": medio minuto es lo que cabe en una pregunta.
RECUERDO_SEG = 30

_pedidos = queue.Queue()
_fin = threading.Event()
_ultimo = []            # lo ultimo oido, para "que ha dicho": (reloj, texto)
_candado = threading.Lock()

# EL ASISTENTE SIGUE VIVO? Mismo cinturon que wake_vosk.py y voz_windows.py llevan desde el
# 13/09, y aqui pesa mas que en ninguno: lo que quedaria huerfano es un Whisper comiendose un
# nucleo entero (regla 5). El cierre de la tuberia ya deberia bastar -se midio: el worker muere
# en cuanto stdin se cierra- pero eso depende de que nadie mas tenga el otro extremo abierto, y
# esto no depende de nada. Se mira una vez por trozo, o sea cada cinco segundos.
try:
    PID_PADRE = int(os.environ.get("NOVA_PID_PADRE", "0") or 0)
except ValueError:
    PID_PADRE = 0


def padre_vivo():
    # ANTE LA DUDA, VIVO: dar por muerto a quien no lo esta apagaria los subtitulos a media
    # escena; esperar de mas solo cuesta un trozo.
    if not PID_PADRE:
        return True
    try:
        import ctypes
        k32 = ctypes.windll.kernel32
        h = k32.OpenProcess(0x1000, False, PID_PADRE)   # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        codigo = ctypes.c_ulong()
        ok = k32.GetExitCodeProcess(h, ctypes.byref(codigo))
        k32.CloseHandle(h)
        return (not ok) or codigo.value == 259          # 259 = STILL_ACTIVE
    except Exception:
        return True


def _stdin():
    # SE LEE 'sys.stdin.buffer', EL FLUJO BINARIO, Y NO 'sys.stdin'. Esto costo media tarde el
    # 1/10: con 'for linea in sys.stdin' el pedido que manda PowerShell NO LLEGABA NUNCA -ni una
    # linea, ni un error-, porque el envoltorio de texto mete su propia lectura adelantada encima
    # del bufer binario y no suelta la linea hasta tener de sobra o hasta el final del flujo. Y
    # engañaba doble: el 'fin' parecia funcionar, porque al cerrarse la tuberia el bucle terminaba
    # igual. charla_worker.py ya lee 'sys.stdin.buffer' desde el 13/09, por esto mismo.
    #
    # REGLA 7: si el que lee stdin se cae, el worker no se puede quedar sordo a las ordenes. Y
    # si stdin se cierra -el asistente murio-, esto se acaba solo y no queda un Whisper
    # huerfano comiendose un nucleo (regla 5).
    try:
        for crudo in sys.stdin.buffer:
            try:
                linea = crudo.decode("utf-8", "replace").strip()
            except Exception:
                continue
            # Y SE LE QUITA EL PREAMBULO SI VIENE: PowerShell le cuela su BOM al primer mensaje si
            # alguien escribe con StandardInput.WriteLine en vez de bytes al BaseStream. Nova
            # escribe bytes (Send-SubPedido), pero esto cuesta nada y ahorra un fallo mudo.
            linea = linea.lstrip("﻿")
            if not linea:
                continue
            try:
                d = json.loads(linea)
            except Exception:
                continue
            op = str(d.get("op", ""))
            # SE APUNTA LO QUE LLEGA. No es adorno: el 1/10 hubo que averiguar si un pedido que no
            # se contestaba no habia llegado o no se habia atendido, y sin esta linea las dos cosas
            # se ven exactamente igual desde fuera.
            di({"ev": "info", "texto": "pedido recibido: " + (op or "(sin op)")})
            if op == "fin":
                _fin.set()
                return
            _pedidos.put(d)
    except Exception:
        pass
    _fin.set()


def _contesta_pedidos():
    while not _pedidos.empty():
        try:
            d = _pedidos.get_nowait()
        except Exception:
            return
        if str(d.get("op", "")) == "ultimo":
            ahora = time.time()
            with _candado:
                trozos = [t for (c, t) in _ultimo if ahora - c <= RECUERDO_SEG and t]
            di({"ev": "ultimo", "texto": " ".join(trozos)[-900:]})


def _comun(antes, ahora):
    # cuantas letras del PRINCIPIO de 'ahora' son el FINAL de 'antes' (el segundo solapado)
    tope = min(len(antes), len(ahora), 90)
    for n in range(tope, 5, -1):
        if antes[-n:] == ahora[:n]:
            return n
    return 0


def main():
    try:
        import numpy as np
        import soundcard as sc
        from faster_whisper import WhisperModel
    except Exception as e:
        di({"ev": "err", "texto": "me faltan piezas para subtitular: %s" % type(e).__name__})
        return

    # EL ALTAVOZ POR DEFECTO, NO UNO ELEGIDO A MANO: si braya enchufa los cascos, el loopback
    # tiene que seguir al sitio donde suena el juego, y el altavoz por defecto es ese sitio.
    try:
        sp = sc.default_speaker()
        mic = sc.get_microphone(id=str(sp.name), include_loopback=True)
    except Exception as e:
        di({"ev": "err", "texto": "no encuentro por donde sale el sonido (%s)" % type(e).__name__})
        return

    try:
        # UN HILO, Y ESTA MEDIDO: con dos va 0,6 s mas rapido y se come otro nucleo entero; con
        # cuatro no va nada mas rapido que con dos. El juego va delante.
        modelo = WhisperModel(MODELO, device="cpu", compute_type="int8", cpu_threads=1)
    except Exception as e:
        di({"ev": "err", "texto": "no pude cargar el oido de subtitulos (%s)" % type(e).__name__})
        return

    threading.Thread(target=_stdin, daemon=True).start()

    import numpy as np
    idioma = None          # se detecta UNA vez (2,7 s cada deteccion) y se fija
    nSolape = int(SR * SOLAPE)
    nTrozo = int(SR * TROZO)
    dicho = ""             # el ultimo subtitulo, para no repetir el segundo solapado

    # LA CAPTURA VA EN SU PROPIO HILO, Y ESTO TAMBIEN LO SACO UNA PRUEBA CON SONIDO DE VERDAD
    # (1/10): con la captura y Whisper en el mismo bucle, mientras se transcribe un trozo -1,8 s-
    # nadie vacia la grabadora, el anillo de WASAPI se desborda y soundcard avisa con "data
    # discontinuity in recording". Se vio tal cual: de 16 s de audio solo salieron DOS subtitulos
    # en vez de tres, y los que salian tenian agujeros. Un subtitulo con agujeros no sirve.
    # Capturar cuesta 8,7 % de un nucleo medido, asi que este hilo es barato; el caro -Whisper, un
    # nucleo- sigue siendo uno solo (regla 5 intacta).
    # Y LA COLA TIENE TOPE: si Whisper se retrasara, el audio no puede crecer sin fin comiendose la
    # RAM. Se tiran los trozos viejos, que es lo correcto: un subtitulo de hace medio minuto no
    # sirve para nada, y es mejor saltarse un trozo que ir cada vez mas tarde.
    _audio = []
    _audioN = [0]
    _candadoA = threading.Lock()
    COLA_MAX = int(SR * TROZO * 4)      # cuatro trozos de margen

    def _captura():
        try:
            with mic.recorder(samplerate=SR, channels=1, blocksize=2048) as rec:
                di({"ev": "listo"})
                while not _fin.is_set():
                    d = rec.record(numframes=SR // 4)      # cuartos de segundo
                    d = d[:, 0] if getattr(d, "ndim", 1) > 1 else d
                    d = d.astype(np.float32)
                    with _candadoA:
                        _audio.append(d)
                        _audioN[0] += len(d)
                        while _audioN[0] > COLA_MAX and len(_audio) > 1:
                            _audioN[0] -= len(_audio.pop(0))
        except Exception as e:
            di({"ev": "err", "texto": "se corto el sonido (%s)" % type(e).__name__})
        _fin.set()

    hiloCap = threading.Thread(target=_captura, daemon=True)
    hiloCap.start()
    cola = np.zeros(0, dtype=np.float32)

    try:
        while not _fin.is_set():
            _contesta_pedidos()
            if not padre_vivo():
                di({"ev": "info", "texto": "el asistente ya no esta; me voy"})
                return
            # SE ESPERA A QUE HAYA UN TROZO ENTERO, en siestas cortas: asi el "fin" y el "que
            # ha dicho" se atienden en menos de un decimo (medido: 0,04 s) y no se queda nadie
            # bloqueado dentro de una lectura de seis segundos, que es lo que pasaba antes.
            with _candadoA:
                if _audio:
                    cola = np.concatenate([cola] + _audio)
                    del _audio[:]
                    _audioN[0] = 0
            if len(cola) < nTrozo:
                time.sleep(0.08)
                continue
            trozo = cola[:nTrozo]
            # el solape se queda para el siguiente: la frase partida se oye entera alli
            cola = cola[nTrozo - nSolape:]

            # LA PUERTA GRATIS: sin esto, Whisper se come un nucleo entero para transcribir
            # silencio y devolver lo que tiny inventa cuando no hay nada ("Gracias por ver
            # el video"). Un maximo de numpy sobre 96.000 muestras cuesta microsegundos.
            if float(np.abs(trozo).max()) < PICO_MIN:
                continue

            t0 = time.time()
            try:
                if idioma is None:
                    segs, inf = modelo.transcribe(trozo, beam_size=1, vad_filter=True)
                    texto = " ".join(s.text.strip() for s in segs).strip()
                    # EL IDIOMA SE FIJA SOLO SI SE OYO ALGO: detectarlo sobre un trozo sin
                    # voz da "es al 44 %" (medido) y dejaria el worker fijado en el idioma
                    # equivocado para toda la sesion.
                    if texto:
                        idioma = str(inf.language)
                        di({"ev": "idioma", "idioma": idioma,
                            "conf": round(float(inf.language_probability), 2)})
                else:
                    segs, inf = modelo.transcribe(trozo, language=idioma, beam_size=1,
                                                  vad_filter=True)
                    texto = " ".join(s.text.strip() for s in segs).strip()
            except Exception as e:
                di({"ev": "err", "texto": "no pude transcribir (%s)" % type(e).__name__})
                continue

            if not texto:
                continue
            # EL SEGUNDO SOLAPADO SALDRIA DOS VECES: si el subtitulo nuevo empieza por
            # donde acabo el anterior, se recorta esa parte.
            if dicho:
                corte = _comun(dicho, texto)
                if corte > 6:
                    texto = texto[corte:].strip()
            if not texto:
                continue
            dicho = texto
            with _candado:
                _ultimo.append((time.time(), texto))
                del _ultimo[:-20]
            di({"ev": "sub", "texto": texto, "idioma": idioma or "-",
                "ms": int((time.time() - t0) * 1000)})
    finally:
        _fin.set()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as e:
        di({"ev": "err", "texto": "me rompi: %s" % type(e).__name__})
