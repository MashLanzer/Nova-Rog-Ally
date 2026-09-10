# Worker de voz en linea (edge-tts) para el asistente.
#
# Se mantiene VIVO y lee frases de stdin, una por linea. Arrancar Python en
# cada frase costaba 2,5-4,4 s; asi el arranque se paga UNA vez.
#
# Ademas cachea por hash del texto: una frase repetida ("Anotado.") no vuelve
# a pedirse a la red, se reproduce al instante.
#
# Uso:  python tts_worker.py <voz> <carpeta_salida>
# Salida por stdout: la ruta del mp3, o "ERR <mensaje>" si fallo.

import sys
import os
import asyncio
import hashlib

try:
    import edge_tts
except Exception as e:  # noqa: BLE001
    print("ERR no se pudo importar edge_tts: %s" % e, flush=True)
    sys.exit(1)

VOZ = sys.argv[1] if len(sys.argv) > 1 else "es-MX-DaliaNeural"
SALIDA = sys.argv[2] if len(sys.argv) > 2 else "."
os.makedirs(SALIDA, exist_ok=True)


async def principal():
    bucle = asyncio.get_event_loop()
    while True:
        linea = await bucle.run_in_executor(None, sys.stdin.readline)
        if not linea:
            break
        # .NET antepone un BOM a la primera linea de stdin redirigido: si no se
        # quita, esa frase genera un hash distinto y nunca acierta en la cache.
        texto = linea.strip().lstrip("﻿")
        if not texto:
            continue
        clave = hashlib.md5((VOZ + "|" + texto).encode("utf-8")).hexdigest()
        ruta = os.path.join(SALIDA, clave + ".mp3")
        if not os.path.exists(ruta):
            try:
                com = edge_tts.Communicate(texto, VOZ)
                await com.save(ruta)
            except Exception as e:  # noqa: BLE001
                print("ERR %s" % e, flush=True)
                continue
        print(ruta, flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(principal())
    except KeyboardInterrupt:
        pass
