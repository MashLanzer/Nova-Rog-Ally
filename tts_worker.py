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
import time

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

# numpy es OPCIONAL a proposito (18/09): acelera el calculo de la envolvente, que va delante de
# la voz, pero este worker ES la voz. Si el import fallara y no estuviera envuelto, Nova se
# quedaria muda por ahorrar 10 ms.
try:
    import numpy as _np
except Exception:  # noqa: BLE001
    _np = None

VENTANA_MS = 50


def escribir_envolvente(ruta_mp3):
    if miniaudio is None:
        return
    ruta_env = ruta_mp3 + ".env"
    # UN .env TRUNCADO NO SE REGENERABA NUNCA (18/09): la funcion salia solo con que el fichero
    # existiera, asi que una frase con la envolvente a medias movia la boca mal para siempre.
    # Medido: 19 de 487 mp3 de la cache no tienen envolvente.
    if os.path.exists(ruta_env):
        try:
            if os.path.getsize(ruta_env) > 4:
                return
        except OSError:
            return
    try:
        d = miniaudio.decode_file(ruta_mp3, output_format=miniaudio.SampleFormat.SIGNED16,
                                  nchannels=1, sample_rate=16000)
        muestras = d.samples
        paso = int(16000 * VENTANA_MS / 1000)
        if _np is not None:
            # EL RMS, DE GOLPE (18/09). El bucle de Python costaba 8-11 ms en una frase tipica
            # y 47-57 ms en una larga, y esto va DELANTE de que Nova empiece a hablar.
            a = _np.frombuffer(memoryview(muestras).cast("B"), dtype=_np.int16).astype(_np.float32)
            enteros = (len(a) // paso) * paso
            valores = []
            if enteros:
                valores = list(_np.sqrt((a[:enteros].reshape(-1, paso) ** 2).mean(axis=1)) / 32768.0)
            # el ultimo trozo incompleto cuenta igual que en el bucle de siempre: si no, la
            # boca se quedaria quieta hasta 50 ms al final de cada frase, y un audio mas corto
            # que un trozo se quedaria sin envolvente entera
            resto = a[enteros:]
            if len(resto):
                valores.append(float(_np.sqrt((resto ** 2).mean()) / 32768.0))
        else:
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
        # ATOMICO, como el mp3 de al lado: se escribe aparte y se cambia de golpe, para que la
        # capsula no lea nunca una envolvente a medias
        parcial_env = ruta_env + (".%d.part" % os.getpid())
        with open(parcial_env, "w", encoding="ascii") as f:
            f.write(" ".join("%.2f" % v for v in norm))
        os.replace(parcial_env, ruta_env)
    except Exception:
        pass

VOZ = sys.argv[1] if len(sys.argv) > 1 else "es-MX-DaliaNeural"
SALIDA = sys.argv[2] if len(sys.argv) > 2 else "."
os.makedirs(SALIDA, exist_ok=True)

# La cache no tenia tope: cada frase NUEVA deja un mp3 para siempre, y este
# proceso vive desde el login. A ~23 KB por frase son megas al mes; el usuario
# tenia que vaciarla a mano. Se borran las mas viejas al pasar del tope.
CACHE_MAX_MB = 60
# ...y cada cuantas frases NUEVAS se vuelve a mirar con Nova encendida (ver principal()).
# 50 frases nuevas son ~1,5 MB a 29 KB cada una: de sobra para no pasarse del tope entre
# una poda y la siguiente, y lo bastante espaciado para que los 17 ms no se noten.
PODA_CADA = 50


def limpiar_cache():
    try:
        archivos = []
        total = 0
        ahora = time.time()
        for nombre in os.listdir(SALIDA):
            # LOS .part HUERFANOS NO LOS BARRIA NADIE. La poda solo miraba .mp3, asi que
            # un temporal de un proceso que murio a mitad -o de una red que se corto- se
            # quedaba en la carpeta para siempre, sin contar para el tope ni borrarse.
            # Media hora es de sobra: sintetizar una frase son segundos.
            if nombre.endswith(".part"):
                rp = os.path.join(SALIDA, nombre)
                try:
                    if ahora - os.stat(rp).st_mtime > 1800:
                        os.remove(rp)
                except OSError:
                    pass
                continue
            if not nombre.endswith(".mp3"):
                continue
            ruta = os.path.join(SALIDA, nombre)
            try:
                est = os.stat(ruta)
            except OSError:
                continue
            archivos.append((est.st_mtime, est.st_size, ruta))
            total += est.st_size
        tope = CACHE_MAX_MB * 1024 * 1024
        if total <= tope:
            return
        # por mtime, que desde el 21/09 es EL ULTIMO USO (se toca al servir la frase)
        archivos.sort()            # lo que hace mas tiempo que no se usa, primero
        for _, tam, ruta in archivos:
            if total <= tope * 0.8:
                break
            for x in (ruta, ruta + ".env"):
                try:
                    os.remove(x)
                except OSError:
                    pass
            total -= tam
    except Exception:              # noqa: BLE001
        pass


limpiar_cache()


# VELOCIDAD (13/09): "habla mas rapido". El asistente deja el porcentaje en
# velocidad.txt, en esta misma carpeta; se lee en cada frase para que el cambio
# valga desde la siguiente, sin reiniciar el worker.
def velocidad():
    try:
        with open(os.path.join(SALIDA, "velocidad.txt"), encoding="ascii") as f:
            v = int(f.read().strip())
        v = max(-50, min(100, v))
        return "%+d%%" % v
    except Exception:  # noqa: BLE001
        return "+0%"


# VOZ CON EMOCION (13/09): el asistente puede anteponer "{emo:alegre}" o
# "{emo:suave}" a la frase. Un pelo mas viva o mas calmada (ritmo y tono), sin
# cambiar de voz. Se suma a la velocidad elegida.
AJUSTE_EMOCION = {"alegre": (6, "+6Hz"), "suave": (-8, "-5Hz")}


async def principal():
    bucle = asyncio.get_event_loop()
    # PODAR TAMBIEN EN CALIENTE (17/09). limpiar_cache() solo se llamaba AL ARRANCAR, y este
    # proceso vive desde el login: con Nova encendida el tope de 60 MB no se aplicaba nunca.
    # Hoy la cache esta en 13,8 MB (487 mp3, medido), asi que esto no rescata nada todavia;
    # es para que dentro de unos meses no haya que vaciarla a mano, que es justo lo que se
    # queria evitar cuando se puso el tope.
    #
    # Dos detalles que importan mas que el arreglo:
    #  - solo cuentan las frases NUEVAS: un acierto de cache no deja ningun archivo, asi que
    #    no hay nada que podar y seria trabajo para nada;
    #  - la poda va DESPUES de entregar la ruta, nunca antes: cuesta 17,2 ms medidos con los
    #    487 archivos de hoy, y delante de la voz eso es latencia en cada frase.
    nuevas = 0
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
        emo = ""
        if texto.startswith("{emo:"):
            fin_emo = texto.find("}")
            if fin_emo > 0:
                emo = texto[5:fin_emo].strip()
                texto = texto[fin_emo + 1:].strip()
        if not texto:
            continue
        ritmo = velocidad()
        tono = "+0Hz"
        if emo in AJUSTE_EMOCION:
            dv, tono = AJUSTE_EMOCION[emo]
            ritmo = "%+d%%" % max(-50, min(100, int(ritmo.rstrip("%")) + dv))
        # la velocidad y el tono van en la clave: la misma frase a otro ritmo es otro audio
        clave = hashlib.md5((VOZ + "|" + ("" if ritmo == "+0%" else ritmo + "|") + ("" if tono == "+0Hz" else tono + "|") + texto).encode("utf-8")).hexdigest()
        ruta = os.path.join(SALIDA, clave + ".mp3")
        creada = False
        if os.path.exists(ruta):
            # LA FECHA ES EL ULTIMO USO, NO EL NACIMIENTO (21/09). La poda de abajo
            # ordena por mtime, y un mp3 de la cache se escribe UNA vez y despues solo
            # se lee: sin esto, mtime es la fecha en que nacio y las primeras en caer
            # son las frases que MAS se repiten -'Vale', 'Hecho', 'Ya esta'-, que son
            # justo las que interesa tener guardadas. Tocarla aqui convierte la poda en
            # un LRU de verdad: cae lo que hace mas tiempo que no se usa.
            # No se usa st_atime porque en NTFS depende de una politica del sistema
            # (fsutil behavior DisableLastAccess) que puede estar apagada y se
            # actualiza con una hora de retraso; esto no depende de nadie.
            try:
                os.utime(ruta, None)
            except OSError:
                pass
        else:
            # Se baja a un temporal y se renombra al final. Antes se escribia
            # directamente en la ruta definitiva: si la red se cortaba a mitad
            # quedaba un mp3 truncado, y como el archivo YA EXISTIA esa frase
            # sonaba cortada para siempre, sin volver a intentarlo nunca.
                # EL .part LLEVA EL PID DESDE EL 21/09. Hay DOS de estos corriendo a la vez
            # -la voz en vivo y la voz preparada, que se adelanta a decir la frase- y la
            # frase que preparan es LA MISMA, asi que el nombre del temporal tambien lo
            # era. Cuando coincidian, uno pillaba el archivo y el otro reventaba:
            #   20/09 23:39:12  voz online: ERR [WinError 32] El proceso no tiene acceso
            #   al archivo porque esta siendo utilizado por otro proceso: ...mp3.part
            # y esa frase se quedo sin sonar, en mitad de una charla. El destino final no
            # cambia: los dos escriben el mismo mp3 y os.replace es atomico, asi que si
            # los dos acaban, el segundo deja exactamente el mismo audio.
            parcial = ruta + (".%d.part" % os.getpid())
            try:
                com = edge_tts.Communicate(texto, VOZ, rate=ritmo, pitch=tono)
                await com.save(parcial)
                os.replace(parcial, ruta)
                creada = True
            except Exception as e:  # noqa: BLE001
                try:
                    os.remove(parcial)
                except OSError:
                    pass
                print("ERR %s" % e, flush=True)
                continue
        escribir_envolvente(ruta)
        print(ruta, flush=True)
        # ya tiene la ruta: lo que se tarde aqui no retrasa esta frase
        if creada:
            nuevas += 1
            if nuevas >= PODA_CADA:
                nuevas = 0
                limpiar_cache()


if __name__ == "__main__":
    try:
        asyncio.run(principal())
    except KeyboardInterrupt:
        pass
