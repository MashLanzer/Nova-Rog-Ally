# -*- coding: utf-8 -*-
"""Dictado con el motor de voz de WINDOWS (el mismo de Win+H) sin abrir Win+H.
=============================================================================

POR QUE EXISTE
  El dictado propio va con faster-whisper. Medido en esta maquina con ocho
  ordenes locutadas: el modelo rapido ("base") falla el 40 % de las palabras y
  el preciso ("small") el 27 %, y small tarda unas tres veces mas. El usuario
  dice que el dictado de Windows le entendia mucho mejor, y tiene sentido: es un
  motor en la nube entrenado para dictado, con el procesado de audio del
  sistema por delante. Se dejo de usar porque Win+H ROBA EL FOCO, y eso jugando
  es inservible. Esta API es el mismo motor SIN la ventana de Win+H.

COMO SE COMUNICA
  Igual que los otros workers: por archivos, sin hilos compartidos con nadie.
    - vigila la marca de dictado (la MISMA que wake_vosk.py: dictar.flag), asi
      que no hay un protocolo nuevo que mantener;
    - cuando aparece, escucha y escribe lo que oiga en su propio archivo de
      salida;
    - NO borra la marca: de eso se encarga wake_vosk.py, que es el dueno del
      dictado. Este worker es un oido de mas, no un sustituto.

DEGRADACION
  El asistente prefiere este texto si llega y no esta vacio; si no llega, usa
  el de Whisper como siempre. O sea que si este motor no oye el microfono de
  esta maquina -que entra flojisimo, 0.02-0.05 de pico, y esta API no acepta
  audio ya amplificado- no se pierde nada: el asistente sigue funcionando igual.

REQUISITOS
  - pip install winsdk
  - Configuracion > Privacidad y seguridad > Voz > Reconocimiento de voz en
    linea ACTIVADO (sin eso, el dictado libre no compila).
  - El paquete de voz del idioma instalado (aqui es-ES).

Uso:  voz_windows.py <marcaDictar> <rutaSalida> <log> [idioma]
"""
import asyncio
import datetime
import os
import sys
import time

MARCA = sys.argv[1] if len(sys.argv) > 1 else ""
SALIDA = sys.argv[2] if len(sys.argv) > 2 else ""
LOG = sys.argv[3] if len(sys.argv) > 3 else ""
IDIOMA = sys.argv[4] if len(sys.argv) > 4 else "es-ES"

# Cuanto se espera a que empieces a hablar, y cuanto silencio cierra la frase.
# El segundo se deja parecido al del worker propio (1,4 s) para que la sensacion
# sea la misma por los dos caminos.
ESPERA_INICIAL = 6.0
SILENCIO_FIN = 1.3
CONFIANZAS = {0: "alta", 1: "media", 2: "baja", 3: "rechazada"}


def anota(mensaje):
    if not LOG:
        return
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S") + "  [voz-win] " + mensaje + "\n")
    except Exception:
        pass


def escribir(ruta, texto):
    if not ruta:
        return
    try:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(texto)
    except Exception as e:                                  # noqa: BLE001
        anota("no pude escribir %s (%s)" % (ruta, e))


async def preparar():
    from winsdk.windows.media.speechrecognition import (
        SpeechRecognizer, SpeechRecognitionTopicConstraint, SpeechRecognitionScenario)
    from winsdk.windows.globalization import Language

    rec = SpeechRecognizer(Language(IDIOMA))
    rec.constraints.append(
        SpeechRecognitionTopicConstraint(SpeechRecognitionScenario.DICTATION, "orden"))
    rec.timeouts.initial_silence_timeout = datetime.timedelta(seconds=ESPERA_INICIAL)
    rec.timeouts.end_silence_timeout = datetime.timedelta(seconds=SILENCIO_FIN)
    res = await rec.compile_constraints_async()
    if int(res.status) != 0:
        anota("el motor no acepta el dictado (estado %s). ¿Esta activado el "
              "reconocimiento de voz en linea?" % res.status)
        return None
    anota("motor de Windows listo (%s)" % IDIOMA)
    return rec


async def principal():
    rec = await preparar()
    if rec is None:
        return 1
    while True:
        try:
            if not MARCA or not os.path.exists(MARCA):
                await asyncio.sleep(0.08)
                continue
            t0 = time.time()
            r = await rec.recognize_async()
            texto = (r.text or "").strip()
            conf = CONFIANZAS.get(int(r.confidence), str(r.confidence))
            anota("oido: '%s' (confianza %s, %.1f s)" % (texto, conf, time.time() - t0))
            # Lo rechazado no se entrega: mas vale que el asistente se quede con
            # lo de Whisper que darle una frase en la que el propio motor no cree.
            if texto and conf != "rechazada":
                escribir(SALIDA, texto)
            # UNA ronda por dictado. La marca sigue puesta hasta que el worker de
            # Vosk cierra la frase; si volvieramos a escuchar ahora, la segunda
            # ronda dejaria un texto que el asistente se encontraria en la orden
            # SIGUIENTE y contestaria a lo de hace un minuto.
            while MARCA and os.path.exists(MARCA):
                await asyncio.sleep(0.08)
        except Exception as e:                              # noqa: BLE001
            # una ronda que falle no se lleva el worker: se anota y se sigue
            anota("fallo al escuchar: %s" % e)
            await asyncio.sleep(0.5)


if __name__ == "__main__":
    try:
        sys.exit(asyncio.run(principal()))
    except KeyboardInterrupt:
        pass
