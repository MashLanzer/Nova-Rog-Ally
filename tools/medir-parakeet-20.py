# -*- coding: utf-8 -*-
"""Las 20 grabaciones del bloque 5, pero por el CAMINO DE HOY (Parakeet primero).

POR QUE EXISTE (20/09). tools\\probar-audio.py mide esas mismas 20 con Whisper SOLO, y
su liston (0,75) se calibro el 12/09 asi. Desde el 15/09 el que oye primero es Parakeet,
o sea que ese aprobado avala el SEGUNDO oido, no el camino entero. El propio
probar-audio.py lo dice y deja escrita la condicion para cerrarlo:

    "Cuando haya una medida de Parakeet sobre estas 20 con su verdad al lado, entonces
     si: se cambia el circuito Y el liston a la vez, en el mismo commit."

Esto es esa medida. No cambia nada: solo la produce, para poder decidir con un numero.

QUE CUENTA COMO ACIERTO: lo mismo que en probar-audio.py, y por la misma razon. No que
el texto salga clavado, sino que el asistente HAGA LO MISMO: cada transcripcion se pasa
por la capa local de verdad (assistant.ps1 -Probar) y se compara la ACCION resuelta.
"abre little nightmares tres en steam" oido como "Abre Little Nightmares III en Steam"
abre el juego igual de bien, y contarlo como fallo seria mentir en la direccion facil.

    python tools\\medir-parakeet-20.py
"""
import glob
import io
import json
import os
import re
import subprocess
import sys
import time
import wave

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(RAIZ, "pruebas", "audio")
ESPERADO = os.path.join(AUDIO, "esperado.json")


def limpiar_como_el_worker():
    """limpiar_whisper() sacada de wake_vosk.py, no copiada.

    oir_parakeet (wake_vosk.py:690) pasa SIEMPRE la salida de Parakeet por esta funcion
    antes de entregarla. Sin ella, "Siguiente cancion." y "?Cuanta bateria queda?" -que
    son transcripciones PERFECTAS- no las resuelve la capa local y salen como fallos: el
    numero diria que Parakeet es peor de lo que es. Se saca del archivo en vez de
    copiarla para que no se desincronicen cuando alguien la toque.
    """
    import ast
    fuente = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
    arbol = ast.parse(fuente)
    for n in arbol.body:
        if isinstance(n, ast.FunctionDef) and n.name == "limpiar_whisper":
            ns = {"re": re}
            exec(compile(ast.Module(body=[n], type_ignores=[]), "<wake_vosk>", "exec"), ns)
            return ns["limpiar_whisper"]
    raise SystemExit("no encuentro limpiar_whisper en wake_vosk.py")


def lee_wav(ruta):
    with wave.open(ruta, "rb") as w:
        datos = w.readframes(w.getnframes())
        tasa = w.getframerate()
    a = np.frombuffer(datos, dtype=np.int16).astype(np.float32) / 32768.0
    if tasa != 16000:      # las 20 son de 16 kHz; si alguna no lo fuera, que se vea
        raise SystemExit("%s va a %d Hz y esto espera 16000" % (ruta, tasa))
    return a


def acciones_de_como_el_banco():
    """acciones_de() sacada de tools\probar-audio.py, no copiada.

    Esa funcion lleva dentro dos lecciones que costaron medidas falsas y que aqui se
    repetirian igual: pide la salida de PowerShell en UTF-8 (sin eso, "Siguiente
    cancion" o "?Cuanta bateria queda?" no encuentran su accion al leerlas y cuentan
    como fallo del oido cuando el oido acerto) y normaliza las horas (si el minuto
    cambiaba entre la frase buena y la oida, "que hora es" salia MAL siempre).
    """
    import ast
    fuente = io.open(os.path.join(RAIZ, "tools", "probar-audio.py"), encoding="utf-8").read()
    arbol = ast.parse(fuente)
    for n in arbol.body:
        if isinstance(n, ast.FunctionDef) and n.name == "acciones_de":
            ns = {"os": os, "re": re, "RAIZ": RAIZ}
            exec(compile(ast.Module(body=[n], type_ignores=[]), "<probar-audio>", "exec"), ns)
            return ns["acciones_de"]
    raise SystemExit("no encuentro acciones_de en tools/probar-audio.py")


def limpiar_como_el_worker():
    """limpiar_whisper() sacada de wake_vosk.py, no copiada.

    oir_parakeet (wake_vosk.py:690) pasa SIEMPRE la salida de Parakeet por esta funcion
    antes de entregarla. Sin ella, "Siguiente cancion." y "?Cuanta bateria queda?" -que
    son transcripciones PERFECTAS- no las resuelve la capa local y salen como fallos: el
    numero diria que Parakeet es peor de lo que es. Se saca del archivo en vez de
    copiarla para que no se desincronicen cuando alguien la toque.
    """
    import ast
    fuente = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
    arbol = ast.parse(fuente)
    for n in arbol.body:
        if isinstance(n, ast.FunctionDef) and n.name == "limpiar_whisper":
            ns = {"re": re}
            exec(compile(ast.Module(body=[n], type_ignores=[]), "<wake_vosk>", "exec"), ns)
            return ns["limpiar_whisper"]
    raise SystemExit("no encuentro limpiar_whisper en wake_vosk.py")


def lee_wav(ruta):
    with wave.open(ruta, "rb") as w:
        datos = w.readframes(w.getnframes())
        tasa = w.getframerate()
    a = np.frombuffer(datos, dtype=np.int16).astype(np.float32) / 32768.0
    if tasa != 16000:      # las 20 son de 16 kHz; si alguna no lo fuera, que se vea
        raise SystemExit("%s va a %d Hz y esto espera 16000" % (ruta, tasa))
    return a


def acciones_de(frases):
    """Cada frase por la capa local REAL. Devuelve {frase: accion o ''}."""
    tmp = os.path.join(RAIZ, "tmp", "medir-parakeet-20.txt")
    with io.open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(frases) + "\n")
    salida = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-Command", "& '%s' -Probar '%s'" % (os.path.join(RAIZ, "assistant.ps1"), tmp)],
        capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    hecho = {}
    for linea in (salida or "").splitlines():
        m = re.match(r"\s+(OK|->IA|SALTO)\s+(.*?)\s{2,}(?:->\s+(.*))?$", linea.rstrip())
        if m:
            hecho[m.group(2).strip()] = (m.group(3) or "").strip() if m.group(1) == "OK" else ""
    try:
        os.remove(tmp)
    except OSError:
        pass
    return hecho


def main():
    esperado = json.load(io.open(ESPERADO, encoding="utf-8"))
    wavs = sorted(glob.glob(os.path.join(AUDIO, "*.wav")))
    wavs = [w for w in wavs if os.path.basename(w) in esperado]
    if not wavs:
        raise SystemExit("no encuentro las grabaciones en %s" % AUDIO)

    import sherpa_onnx
    carps = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*parakeet*")) if os.path.isdir(c)]
    if not carps:
        raise SystemExit("no esta el modelo de Parakeet en modelos\\")
    carp = carps[0]
    t0 = time.time()
    par = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=os.path.join(carp, "encoder.int8.onnx"),
        decoder=os.path.join(carp, "decoder.int8.onnx"),
        joiner=os.path.join(carp, "joiner.int8.onnx"),
        tokens=os.path.join(carp, "tokens.txt"),
        num_threads=2, decoding_method="greedy_search", model_type="nemo_transducer")
    print("parakeet cargado en %.1f s" % (time.time() - t0))

    limpiar = limpiar_como_el_worker()
    oido, tiempos = {}, []
    for w in wavs:
        a = lee_wav(w)
        t = time.time()
        s = par.create_stream()
        s.accept_waveform(16000, a)
        par.decode_stream(s)
        txt = limpiar((s.result.text or "").strip())   # igual que oir_parakeet
        tiempos.append(time.time() - t)
        oido[os.path.basename(w)] = txt

    # las dos tandas de frases van en llamadas SEPARADAS a -Probar (19/09): en la misma
    # llamada las claves se pisan entre si y el numero sale inflado
    acciones_de = acciones_de_como_el_banco()
    acc_oido = acciones_de([t for t in oido.values() if t])
    acc_real = acciones_de([esperado[n] for n in oido])

    bien = fallo = vacio = 0
    print("")
    print("  %-9s %-38s %-38s" % ("archivo", "lo que dijiste", "lo que oyo parakeet"))
    for n in sorted(oido):
        t = oido[n]
        quiero = acc_real.get(esperado[n], "")
        tengo = acc_oido.get(t, "") if t else ""
        if not t:
            marca, vacio = "VACIO", vacio + 1
        elif quiero and tengo == quiero:
            marca, bien = "OK   ", bien + 1
        elif not quiero and not tengo:
            # ninguna de las dos resuelve en local: no lo sabe medir esta prueba
            marca, bien = "OK~  ", bien + 1
        else:
            marca, fallo = "MAL  ", fallo + 1
        print("  %s %-9s %-38s %-38s" % (marca, n, esperado[n][:38], t[:38]))

    tot = len(oido)
    print("")
    print("  parakeet solo: %d de %d (%d%%)" % (bien, tot, round(100.0 * bien / tot)))
    print("  fallos %d, sin sacar nada %d" % (fallo, vacio))
    print("  tiempo por grabacion: %.2f s de media (%.2f s el peor)"
          % (sum(tiempos) / len(tiempos), max(tiempos)))
    print("")
    print("  para comparar, el mismo banco con Whisper solo:  python tools\\probar-audio.py")
    print("  NO cambies el liston de probar-audio.py sin cambiar tambien su circuito:")
    print("  el 0,75 se calibro con Whisper solo y con otro circuito no significa nada.")


if __name__ == "__main__":
    main()
