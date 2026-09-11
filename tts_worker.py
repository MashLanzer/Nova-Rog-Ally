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

# ENVOLVENTE PARA LA CAPSULA: junto a cada mp3 se deja <mp3>.env con la
# amplitud (0..1) cada 50 ms. La interfaz mueve la "boca" del punto con ella,
# sincronizada con la voz real, en vez de simular silabas. Es opcional: si
# miniaudio no esta, no hay .env y la capsula simula.
try:
    import miniaudio
    import array
    import math
except Exception:  # noqa: BLE001
    miniaudio = None

VENTANA_MS = 50


def escribir_envolvente(ruta_mp3):
    if miniaudio is None:
        return
    ruta_env = ruta_mp3 + ".env"
    if os.path.exists(ruta_env):
        return
    try:
        d = miniaudio.decode_file(ruta_mp3, output_format=miniaudio.SampleFormat.SIGNED16,
                                  nchannels=1, sample_rate=16000)
        muestras = d.samples
        paso = int(16000 * VENTANA_MS / 1000)
        valores = []
        for i in range(0, len(muestras), paso):
            trozo = muestras[i:i + paso]
            if not trozo:
                break
            rms = math.sqrt(sum(m * m for m in trozo) / len(trozo)) / 32768.0
            valores.append(rms)
        if not valores:
            return
        # normalizado al pico de la frase y con una curva que abre la boca
        # con las vocales sin que las consonantes la dejen cerrada
        pico = max(valores) or 1.0
        norm = [min(1.0, (v / pico) ** 0.7) for v in valores]
        with open(ruta_env, "w", encoding="ascii") as f:
            f.write(" ".join("%.2f" % v for v in norm))
    except Exception:
        pass

VOZ = sys.argv[1] if len(sys.argv) > 1 else "es-MX-DaliaNeural"
SALIDA = sys.argv[2] if len(sys.argv) > 2 else "."
os.makedirs(SALIDA, exist_ok=True)


async def principal():
    bucle = asyncio.get_event_loop()
    while True:
        # stdin en BINARIO y decodificado como UTF-8 a mano. Con sys.stdin de
        # texto, Python usaba la pagina de codigos de la consola oculta (850)
        # y cualquier tilde o "¿" acababa en un surrogate que reventaba el
        # md5: el worker moria en silencio con cada frase no ASCII y el
        # asistente lo relanzaba (2 s mudo). El asistente ahora escribe bytes
        # UTF-8 directamente, sin pasar por el codificador de .NET.
        cruda = await bucle.run_in_executor(None, sys.stdin.buffer.readline)
        if not cruda:
            break
        linea = cruda.decode("utf-8", errors="replace")
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
        escribir_envolvente(ruta)
        print(ruta, flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(principal())
    except KeyboardInterrupt:
        pass
