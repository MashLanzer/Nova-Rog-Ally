# -*- coding: utf-8 -*-
"""Mide si el reconocedor TE ENTIENDE A TI, con audio de verdad.

Todo el resto del banco mide texto. Esto pasa tus grabaciones por WHISPER
-mismos modelos, mismos umbrales, misma frase de ejemplo, misma limpieza- y dice
cuantas salen bien con el modelo rapido y cuantas necesitan el oido fino. Es la
unica forma de saber si un cambio en Whisper mejora o empeora, en vez de suponerlo.

LO QUE ESTO **NO** MIDE (19/09). Desde el 15/09 el que oye PRIMERO es Parakeet, y
Whisper solo entra cuando Parakeet no saca nada o cuando lo que saco suena a ingles
(la guarda de `wake_vosk.py`, repaso del ingles). Aqui NO se carga Parakeet por
ningun lado: este numero avala el SEGUNDO oido, no el camino entero. El camino
entero, en el mismo orden que el worker, se mide con:

    python pruebas\\pipeline-hoy.py   (Parakeet -> cobertura -> ingles -> Whisper)

POR QUE SOLO EL AVISO Y NO METERLE PARAKEET (19/09). Dos razones medidas, no de gusto:
el liston de aqui (0,75) se calibro el 12/09 sobre estas 20 grabaciones CON Whisper
solo, y cambiarle el circuito sin volver a medir dejaria el liston sin significado
-que es exactamente lo que vigila-; y `pipeline-hoy.py` no puede sustituir a esta
prueba, porque corre sobre `pruebas\\audio\\uso`, que no tiene `esperado.json`, asi
que no da un aprobado/suspenso con el que cerrar el bloque 5 del banco. Cuando haya
una medida de Parakeet sobre estas 20 con su verdad al lado, entonces si: se cambia
el circuito Y el liston a la vez, en el mismo commit.

YA HAY MEDIDA, Y DICE QUE NO SE CAMBIE (20/09, tools\\medir-parakeet-20.py). Sobre estas
mismas 20 y con el mismo criterio -la ACCION resuelta, no el texto- Parakeet solo saca
11 de 20 (55 %) frente a los 19 de 20 (95 %) de Whisper solo. Tres las deja en blanco
("sube el volumen", "baja el brillo", "que hora es": las cortas) y seis las oye mal
("abre steam" -> "Habres quienes"). O sea que meterle Parakeet a esta prueba la haria
suspender su propio liston sin que nada hubiera empeorado en Nova: lo que mide esta
prueba -si Whisper te entiende- seguiria estando bien. El circuito se queda como esta.
Lo que esa medida SI confirma es por que Parakeet va primero en el worker: 1,48 s de
media por grabacion. Va delante por rapido, no por fino, y Whisper repasa detras; eso
cuadra con la medida del 18/09 (de 75 pares, Whisper saca orden en 17 y Parakeet en 12).

QUE SE CUENTA COMO ACIERTO. No que el texto salga clavado, sino que el
asistente HAGA LO MISMO. La primera version comparaba texto literal y por eso
mentia en las dos direcciones: "abre little nightmares tres en steam" oido como
"Abre Little Nightmares III en Steam" contaba como FALLO cuando en realidad
abre el juego perfectamente. Asi que cada transcripcion se pasa por la capa
local de verdad (assistant.ps1 -Probar) y se compara la ACCION resuelta.
El texto exacto se sigue enseñando, porque dice cuanta culpa es del oido y
cuanta de la capa local, pero el numero que manda es el de las acciones.

    python tools\\grabar-ordenes.py     (una vez, graba tu voz)
    python tools\\probar-audio.py       (cada vez que se toque el oido)

Devuelve 1 si baja del listón que hay en el propio archivo, para poder
encadenarlo con el resto de comprobaciones.
"""
import os
import re
import sys
import json
import time
import unicodedata

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(RAIZ, "pruebas", "audio")

import wave

# EL INTERPRETE DE NOVA, ANTES DE RENDIRSE (27/09, tras la revision)
#
# La bateria lanza los bancos de Python con "python" a secas, y en esta consola ese es el 3.11, que
# NO tiene numpy. Nova, en cambio, arranca sus workers con el de config.json (paths.python, por
# defecto %LOCALAPPDATA%\Programs\Python\Python312\python.exe, ver $PyExe en assistant.ps1), que SI
# lo tiene. O sea que este banco se rendia por el interprete y no por la maquina, y con el exit(0)
# de abajo salia VERDE sin haber comprobado ni una cosa.
#
# NO SE TOCA LA DECISION DE ABAJO, que esta razonada y sigue valiendo: faltar un paquete de verdad
# no es que el oido haya empeorado, asi que en una maquina recien montada esto avisa y sale bien.
# Lo unico que se anade es probar primero con el interprete que Nova usa de verdad.
def _python_de_nova():
    exe = ""
    try:
        import json as _json
        with open(os.path.join(RAIZ, "config.json"), encoding="utf-8-sig") as _f:
            exe = ((_json.load(_f).get("paths") or {}).get("python") or "").strip()
    except Exception:  # noqa: BLE001
        exe = ""
    if not exe:
        exe = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python312", "python.exe")
    exe = os.path.expandvars(exe)
    return exe if os.path.isfile(exe) else ""


try:
    import numpy  # noqa: F401
except Exception:  # noqa: BLE001
    _exe = _python_de_nova()
    if _exe and os.path.normcase(_exe) != os.path.normcase(sys.executable) and not os.environ.get("NOVA_AUDIO_RELANZADO"):
        import subprocess
        os.environ["NOVA_AUDIO_RELANZADO"] = "1"
        sys.exit(subprocess.call([_exe, os.path.abspath(__file__)] + sys.argv[1:]))

try:
    import numpy as np
    from faster_whisper import WhisperModel
except Exception as e:  # pragma: no cover
    # Faltar un paquete no es que el oido haya empeorado: se avisa y se sale
    # BIEN, o esto tumbaria el banco entero en una maquina recien montada.
    print("Falta un paquete: %s" % e)
    print("Instala con:  pip install numpy faster-whisper")
    sys.exit(0)


def acciones_de(frases):
    """Que hace la capa local con cada frase. Devuelve {frase: accion}.

    Se llama UNA vez con todas: arrancar assistant.ps1 cuesta segundos, y
    hacerlo por frase multiplicaria por veinte la espera."""
    import subprocess
    import tempfile
    import io
    utiles = [f for f in frases if f and f.strip()]
    if not utiles:
        return {}
    tmp = os.path.join(tempfile.gettempdir(), "probar-audio-%d.txt" % os.getpid())
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(utiles) + "\n")
    salida = ""
    try:
        # La salida de PowerShell se pide en UTF-8. Sin esto sale con la
        # codificacion de la consola, cualquier frase con tilde o con "¿"
        # ("Recuérdame en 20 minutos...") no encontraba su accion al leerla
        # y contaba como FALLO del oido cuando el oido habia acertado. Paso
        # el 12/09: medium "fallaba" dos frases que habia oido perfectas.
        orden = ("[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
                 "& '%s' -Probar '%s'" % (os.path.join(RAIZ, "assistant.ps1"), tmp))
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                            "-Command", orden],
                           capture_output=True, timeout=600)
        salida = r.stdout.decode("utf-8", "replace")
    except Exception as e:
        print("  (no pude preguntarle a la capa local: %s)" % e)
    finally:
        try:
            os.remove(tmp)
        except Exception:
            pass
    res = {}
    for linea in salida.splitlines():
        m = re.match(r"^\s*OK\s+(.*?)\s{2,}->\s+(.*)$", linea)
        if m:
            # "que hora es" resuelve a "Son las 8:49": si el minuto cambiaba entre
            # frase buena y frase oida, contaba como FALLO del oido (14/09)
            res[m.group(1).strip()] = re.sub(r"\d{1,2}:\d{2}", "H:M", m.group(2).strip())
            continue
        m = re.match(r"^\s*->IA\s+(.*)$", linea)
        if m:
            res[m.group(1).strip()] = ""
    return res


def lee_wav(ruta):
    with wave.open(ruta, "rb") as w:
        canales = w.getnchannels()
        crudo = w.readframes(w.getnframes())
    a = np.frombuffer(crudo, dtype="<i2").astype("float32") / 32767.0
    if canales > 1:
        a = a.reshape(-1, canales).mean(axis=1)
    return a


def cfg(*camino):
    with open(os.path.join(RAIZ, "config.json"), "r", encoding="utf-8-sig") as f:
        c = json.load(f)
    for k in camino:
        c = c.get(k, {}) if isinstance(c, dict) else {}
    return c


def limpiar_whisper(texto):
    # COPIA EXACTA de wake_vosk.py: si esto se desincroniza, la prueba mide
    # otra cosa distinta de lo que hace el asistente y no vale para nada.
    t = (texto or "").strip()
    t = re.sub(r"\s*\.\s+", ", ", t)
    t = re.sub(r"[.…!?]+$", "", t).strip()
    return t


def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9 ]+", " ", re.sub(r"\s+", " ", s)).strip()


def vocabulario():
    ruta = os.path.join(RAIZ, "tmp", "vocabulario.txt")
    if not os.path.exists(ruta):
        return None
    try:
        with open(ruta, "r", encoding="utf-8") as f:
            return f.read().strip() or None
    except Exception:
        return None


def _prompt_de_la_escucha():
    # la frase de ejemplo SE SACA de wake_vosk.py (no se copia): si cambia alli, la
    # prueba mide lo nuevo sin que nadie tenga que acordarse de tocar esto.
    #
    # 27/09: desde la idea 118 PROMPT_ORDENES ya no es una cadena escrita a mano sino lo que
    # devuelve _leer_prompt_ordenes(), que mira tmp\prompt-ordenes.txt (la frase que Nova
    # escribio con tus verbos) y cae en la de siempre si no hay o no vale. Un literal_eval
    # sobre eso revienta. Asi que se EXTRAE esa funcion tal cual y se ejecuta aqui, con el
    # __file__ de wake_vosk.py, que es lo que decide de que carpeta tmp se lee. Copiar aqui la
    # regla de los 20..300 caracteres habria dejado la prueba midiendo otra cosa el dia que
    # alli cambie, que es justo lo que acaba de pasar.
    import ast
    ruta = os.path.join(RAIZ, "wake_vosk.py")
    with open(ruta, encoding="utf-8") as f:
        arbol = ast.parse(f.read())
    piezas = [n for n in arbol.body
              if (isinstance(n, ast.FunctionDef) and n.name == "_leer_prompt_ordenes")
              or (isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name)
                  and n.targets[0].id == "PROMPT_ORDENES_POR_DEFECTO")]
    if len(piezas) != 2:
        print("  MAL  no encuentro en wake_vosk.py de donde sale la frase de ejemplo "
              "(PROMPT_ORDENES_POR_DEFECTO y _leer_prompt_ordenes): la prueba no mide lo que oye Nova")
        return None
    entorno = {"os": os, "__file__": ruta}
    exec(compile(ast.Module(body=piezas, type_ignores=[]), ruta, "exec"), entorno)
    return entorno["_leer_prompt_ordenes"]()


PROMPT_ORDENES = _prompt_de_la_escucha()


def transcribe(modelo, audio, hotwords=None):
    # los MISMOS parametros que wake_vosk.py, por la misma razon de arriba. Desde el
    # 14/09 la escucha ya no usa hotwords sino PROMPT_ORDENES: el argumento se ignora
    segmentos, _ = modelo.transcribe(
        audio, language="es", beam_size=2, best_of=1,
        vad_filter=True, vad_parameters=dict(min_silence_duration_ms=500),
        condition_on_previous_text=False,
        no_speech_threshold=0.6,
        log_prob_threshold=-1.0,
        compression_ratio_threshold=2.4,
        initial_prompt=PROMPT_ORDENES)
    return limpiar_whisper(" ".join(s.text.strip() for s in segmentos).strip())


def main():
    esperado_json = os.path.join(AUDIO, "esperado.json")
    if not os.path.exists(esperado_json):
        print("No hay grabaciones todavia.")
        print("Graba las tuyas una sola vez con:   python tools\\grabar-ordenes.py")
        return 0          # no es un fallo: es que aun no las has hecho

    with open(esperado_json, "r", encoding="utf-8") as f:
        esperado = json.load(f)
    hay = [n for n in sorted(esperado) if os.path.exists(os.path.join(AUDIO, n))]
    if not hay:
        print("esperado.json existe pero no hay ningun .wav al lado.")
        return 0

    rapido = cfg("input", "whisperModelo") or "base"
    preciso = cfg("input", "whisperModeloPreciso") or "small"
    hw = vocabulario()

    # El aviso, arriba del todo: esto NO es el camino de hoy. Desde el 15/09 oye
    # primero Parakeet y aqui no se carga (19/09). Sin esta linea, un 90% aqui se
    # lee como "Nova te entiende el 90%", y no es eso lo que se ha medido.
    print("SOLO WHISPER: desde el 15/09 el que oye PRIMERO es Parakeet, y aqui no se carga.")
    print("El camino entero (Parakeet -> cobertura -> ingles -> Whisper):  python pruebas\\pipeline-hoy.py")
    print("modelo rapido: %s     oido fino: %s     frase de ejemplo: %s"
          % (rapido, preciso, "si" if PROMPT_ORDENES else "no"))
    t0 = time.time()
    mr = WhisperModel(rapido, device="cpu", compute_type="int8", cpu_threads=8)
    print("cargado en %.1f s" % (time.time() - t0))

    # primero se transcribe todo, y despues se le pregunta a la capa local por
    # todas las frases de una vez: asi se arranca assistant.ps1 una sola vez
    oidas = []
    print("")
    for nombre in hay:
        audio = lee_wav(os.path.join(AUDIO, nombre))
        t1 = time.time()
        oido = transcribe(mr, audio, hw)
        oidas.append((nombre, esperado[nombre], oido, time.time() - t1))

    # LO QUE OYO SE GUARDA, PORQUE NADIE MAS LO SABE (30/09)
    #
    # EL CASO: la poda de correcciones duerme lo que no se ha oido en once dias de uso, y su corpus
    # son pruebas\audio\uso y ordenes-que-funcionaban.txt. Estas VEINTE grabaciones son la voz de
    # braya de verdad, pero lo que Whisper oye de ellas se recalculaba cada vez y no quedaba en
    # ningun fichero: 'esperado.json' guarda lo que DIJO, no lo que se oyo. Resultado: la poda
    # durmio 'si arra'->cierra, 'moldo'->modo, 'descacando'->descargando y 'medio de hora'->media
    # hora, y las cuatro salen aqui mismo, en esta prueba, en lo que el oido entiende de su voz.
    # Y sin esto no habria arreglo que durara: despertarlas a mano no sirve de nada, porque el
    # siguiente arranque de Nova volveria a dormirlas por el mismo motivo.
    # SE GUARDA EN pruebas\audio\uso PARA QUE EL CORPUS LO ENCUENTRE, con el mismo formato jsonl
    # que el resto de lo que hay ahi. Son veinte lineas: no pesa nada y se reescribe entero cada
    # vez, que es lo que toca -no es un historico, es el retrato de como oye HOY-.
    try:
        usoDir = os.path.join(AUDIO, "uso")
        if not os.path.isdir(usoDir):
            os.makedirs(usoDir)
        hoy = time.strftime("%Y%m%d")
        with open(os.path.join(usoDir, "oido-grabaciones.jsonl"), "w", encoding="utf-8") as fg:
            for nombre, dijo, oyo, _s in oidas:
                fg.write(json.dumps({"id": hoy + "-" + nombre, "texto": oyo, "frase": dijo,
                                     "de": "pruebas/audio/" + nombre}, ensure_ascii=False) + "\n")
    except Exception as e:  # noqa: BLE001
        # que no se pierda la medicion por no poder escribir un fichero de apoyo
        print("  (no pude guardar lo oido: %s)" % e)

    acc = acciones_de([q for _, q, _, _ in oidas] + [o for _, _, o, _ in oidas])

    # SI LA CAPA LOCAL NO CONTESTA, ESTO NO MIDE NADA Y DABA 100 % (21/09).
    # acciones_de() envuelve la llamada a assistant.ps1 en un try/except que solo imprime
    # un aviso y devuelve {}. Con acc vacio, ni una frase buena tiene accion, todas se caen
    # a la rama de charla -"acierta si lo oido no dispara nada"- y ahi basta con que Whisper
    # haya transcrito ALGO: las 20 salen OK, dudosos queda vacio y se imprime
    # "entendidas en total: 20 de 20 (100%) -- liston 75%" y se devuelve 0.
    # Es la UNICA prueba que mide el microfono de verdad. Un 100 % de mentira aqui es peor
    # que no tenerla: hace creer que el oido va bien justo cuando no se ha medido.
    # Las frases de charla TAMBIEN estan en acc (las lineas '->IA' se guardan con valor ""),
    # asi que esto solo salta cuando la frase no aparecio en la salida.
    faltan = [q.strip() for _, q, _, _ in oidas if q.strip() and q.strip() not in acc]
    if faltan:
        print("")
        print("  MAL  la capa local no contesto por %d de las %d frases buenas." % (len(faltan), len(oidas)))
        print("       Sin eso cada grabacion cuenta como acierto y esto no esta midiendo nada.")
        for q in faltan[:5]:
            print("         - %s" % q)
        return 1

    bien = 0
    dudosos = []
    for nombre, quiero, oido, tarda in oidas:
        aQuiero = acc.get(quiero.strip(), "")
        aOido = acc.get((oido or "").strip(), "")
        # acierto = la capa local hace LO MISMO. Si ni siquiera la frase buena
        # se reconoce, se cae al texto: es un caso que hay que arreglar en
        # commands.json, no un fallo del oido.
        if aQuiero:
            ok = (aOido != "" and aOido == aQuiero)
        else:
            # frase de CHARLA (no es ninguna orden): acierta si lo oido tampoco
            # dispara nada. Exigir el texto clavado mediria otra cosa (14/09)
            ok = bool(plano(oido)) and not aOido
        igual = plano(oido) == plano(quiero)
        marca = "OK " if ok else "MAL"
        if ok and not igual:
            marca = "OK~"       # el texto no sale clavado pero hace lo mismo
        if ok:
            bien += 1
        else:
            dudosos.append((nombre, quiero, oido))
        print("  %s  %-38s %-38s %4.1f s"
              % (marca, quiero, oido or "(nada)", tarda))

    total = len(hay)
    print("")
    print("con el modelo rapido: %d de %d" % (bien, total))

    if dudosos:
        print("")
        print("las que fallaron, con el oido fino (%s):" % preciso)
        mp = WhisperModel(preciso, device="cpu", compute_type="int8", cpu_threads=8)
        rescatadas = 0
        finas = []
        for nombre, quiero, antes in dudosos:
            audio = lee_wav(os.path.join(AUDIO, nombre))
            t1 = time.time()
            finas.append((nombre, quiero, transcribe(mp, audio, hw), time.time() - t1))
        acc2 = acciones_de([q for _, q, _, _ in finas] + [o for _, _, o, _ in finas])
        for nombre, quiero, oido, tarda in finas:
            aQuiero = acc2.get(quiero.strip(), "")
            aOido = acc2.get((oido or "").strip(), "")
            if aQuiero:
                ok = (aOido != "" and aOido == aQuiero)
            else:
                ok = bool(plano(oido)) and not aOido
            marca = "OK " if ok else "MAL"
            if ok and plano(oido) != plano(quiero):
                marca = "OK~"
            if ok:
                rescatadas += 1
            print("  %s  %-38s %-38s %4.1f s"
                  % (marca, quiero, oido or "(nada)", tarda))
        print("")
        print("el oido fino rescata %d de %d" % (rescatadas, len(dudosos)))
        print("total entendidas: %d de %d" % (bien + rescatadas, total))

    # EL LISTON. Se sube a mano cuando se mejora, igual que el 3 del ruido: lo
    # que importa no es el numero absoluto, es que no BAJE sin que nadie mire.
    #
    # Se mide sobre el TOTAL, no sobre el modelo rapido. El asistente pide el
    # oido fino solo cuando el rapido no da nada aprovechable, y lo hace SIEMPRE:
    # exigirle al rapido un 60% era pedirle cuentas a media maquina. Medido el
    # 12/09 con las 20 grabaciones de esta casa: 8 de 20 el rapido, 17 de 20 en
    # total. El liston se pone en 0.75, por debajo de lo medido, para que avise
    # cuando algo se rompa y no cada vez que una frase salga regular.
    #
    # Y es el liston DE WHISPER SOLO (19/09): calibrado el 12/09, cuando Whisper era el
    # unico oido. Si algun dia esta prueba carga Parakeet, este 0.75 hay que volver a
    # medirlo en el mismo cambio; heredarlo seria aprobar con la vara de otro circuito.
    liston = 0.75
    logrado = (bien + (rescatadas if dudosos else 0)) / float(total) if total else 1.0
    print("")
    # se conserva el prefijo "entendidas en total" porque hay scripts de ronda que
    # filtran el banco por esa cadena (tmp\cerrar-ronda.ps1 y los de las rondas)
    print("entendidas en total (SOLO WHISPER, sin Parakeet): %d de %d (%d%%)  -- liston %d%%"
          % (bien + (rescatadas if dudosos else 0), total, int(logrado * 100), int(liston * 100)))
    print("recuerda: esto no es el camino de hoy; el de hoy:  python pruebas\\pipeline-hoy.py")
    if logrado < liston:
        print("POR DEBAJO del liston")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
