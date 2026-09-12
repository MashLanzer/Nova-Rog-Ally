# -*- coding: utf-8 -*-
"""Prueba el motor de dictado de WINDOWS (el mismo de Win+H) sin abrir Win+H,
sin robar el foco y sin arrancar el asistente.

    python tools\\probar-voz-windows.py

Lo que hay que averiguar con esto es UNA cosa: si ese motor oye bien el
microfono de esta maquina. Entra flojisimo (la voz llega a 0.02-0.05) y por eso
el worker propio la amplifica por software antes de reconocer; esta API, en
cambio, escucha el microfono ella misma y no se le puede dar audio ya tratado.
Si oye bien, merece la pena montar el worker; si no, no.

Di una frase corta cuando lo pida. Cinco rondas y un resumen.
"""
import asyncio
import sys
import time

FRASES = [
    'abre steam',
    'abre little nightmares tres en steam',
    'sube el volumen al sesenta por ciento',
    'recuerdame en veinte minutos que saque la ropa',
    'cierra discord y abre spotify',
]


async def principal():
    try:
        from winsdk.windows.media.speechrecognition import (
            SpeechRecognizer, SpeechRecognitionTopicConstraint,
            SpeechRecognitionScenario, SpeechRecognitionConfidence)
        from winsdk.windows.globalization import Language
    except ImportError:
        print('falta el puente: pip install winsdk')
        return 1

    rec = SpeechRecognizer(Language('es-ES'))
    rec.constraints.append(
        SpeechRecognitionTopicConstraint(SpeechRecognitionScenario.DICTATION, 'orden'))
    # sin esto corta en cuanto dudas un instante
    rec.timeouts.initial_silence_timeout = __import__('datetime').timedelta(seconds=6)
    rec.timeouts.end_silence_timeout = __import__('datetime').timedelta(milliseconds=1200)
    res = await rec.compile_constraints_async()
    if int(res.status) != 0:
        print('el motor no acepto el dictado (estado %s).' % res.status)
        print('Comprueba Configuracion > Privacidad y seguridad > Voz.')
        return 1

    nombres = {0: 'alta', 1: 'media', 2: 'baja', 3: 'rechazada'}
    resultados = []
    print('Listo. Habla cuando veas "AHORA".\n')
    for i, frase in enumerate(FRASES, 1):
        print('--- %d de %d ---' % (i, len(FRASES)))
        print('   di:  "%s"' % frase)
        print('   AHORA...', end=' ', flush=True)
        t0 = time.time()
        try:
            r = await rec.recognize_async()
        except Exception as e:                      # noqa: BLE001
            print('fallo: %s' % e)
            resultados.append((frase, '', 'error', 0.0))
            continue
        tardo = time.time() - t0
        texto = r.text or ''
        conf = nombres.get(int(r.confidence), str(r.confidence))
        print('oyo: "%s"   (confianza %s, %.1f s)' % (texto, conf, tardo))
        resultados.append((frase, texto, conf, tardo))
        print()

    print('=== resumen ===')
    vacias = sum(1 for _, t, _, _ in resultados if not t.strip())
    tiempos = [t for _, _, _, t in resultados if t > 0]
    print('  no oyo nada en %d de %d intentos' % (vacias, len(resultados)))
    if tiempos:
        print('  tiempo medio: %.1f s   (Whisper base tarda 2-8 s con la orden entera)' % (sum(tiempos) / len(tiempos)))
    print()
    for frase, texto, conf, _ in resultados:
        marca = 'vacio' if not texto.strip() else ('igual' if texto.strip().lower().rstrip('.') == frase else 'distinto')
        print('  %-8s %-42s -> %s' % (marca, frase, texto))
    print()
    print('Lo importante: si casi todo sale "vacio", este motor no oye tu')
    print('microfono y no merece la pena seguir por aqui. Si oye, aunque cambie')
    print('palabras, si merece la pena.')
    return 0


if __name__ == '__main__':
    sys.exit(asyncio.run(principal()))
