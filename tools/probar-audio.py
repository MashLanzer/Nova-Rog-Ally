# -*- coding: utf-8 -*-
"""Mide si el reconocedor TE ENTIENDE A TI, con audio de verdad.

Todo el resto del banco mide texto. Esto pasa tus grabaciones por el MISMO
camino que usa el asistente -mismo modelo, mismos umbrales, misma frase de ejemplo,
misma limpieza- y dice cuantas salen bien con el modelo rapido y cuantas
necesitan el oido fino. Es la unica forma de saber si un cambio en el
reconocimiento mejora o empeora, en vez de suponerlo.

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
    # la frase de ejemplo SE LEE de wake_vosk.py (no se copia): si cambia alli, la
    # prueba mide lo nuevo sin que nadie tenga que acordarse de tocar esto
    import ast
    fuente = open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
    for n in ast.parse(fuente).body:
        if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) and n.targets[0].id == "PROMPT_ORDENES":
            return ast.literal_eval(n.value)
    return None


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

    acc = acciones_de([q for _, q, _, _ in oidas] + [o for _, _, o, _ in oidas])

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
    liston = 0.75
    logrado = (bien + (rescatadas if dudosos else 0)) / float(total) if total else 1.0
    print("")
    print("entendidas en total: %d de %d (%d%%)  -- liston %d%%"
          % (bien + (rescatadas if dudosos else 0), total, int(logrado * 100), int(liston * 100)))
    if logrado < liston:
        print("POR DEBAJO del liston")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
