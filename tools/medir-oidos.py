# -*- coding: utf-8 -*-
# ¿HAY UN OIDO MEJOR QUE EL DE HOY, SIN QUE BRAYA GRABE NADA? (21/09)
#
# Lo pregunto el: "no se puede expandir mas el vocabulario sin que yo tenga que hablar,
# con alguna base de datos o cosas asi... que entienda de todo, que este entrenado".
#
# LO QUE SE COMPARA, y por que:
#   PARAKEET tdt 0.6b v3 (lo de hoy). Es multilingue y ELIGE EL IDIOMA POR FRASE. El
#     18/09 ya se midio que se equivoca 13 de 99 veces: "Haben The Ring", "See it now".
#     Hoy eso se tapa con un detector de palabras inglesas que TIRA la transcripcion, o
#     sea que esas ordenes se pierden y bajan a Whisper, que es mas lento.
#     No hay forma de decirle el idioma: OfflineTransducerModelConfig solo acepta los
#     tres ficheros del modelo (comprobado en sherpa_onnx 1.13.8).
#   CANARY 180m flash en-es-de-fr. Entrenado SOLO en cuatro idiomas y acepta src_lang="es".
#     Se le DICE que le hablan en espanol, asi que no tiene que adivinarlo. Y es 180M de
#     parametros frente a 600M: 198 MB en disco frente a 641 MB.
#
# SE MIDEN DOS COSAS, y la segunda es la que importa:
#   - si el TEXTO sale clavado
#   - si ACABA EN LA MISMA ACCION que la frase buena, que es lo unico que nota braya
#     (un "abre estim" que acaba abriendo Steam es un acierto, aunque el texto este mal)
# Y EL TIEMPO, que es su preferencia numero uno: un oido que acierte mas pero tarde el
# doble no sirve, y hay que decirlo con el numero delante.
#
# Uso:   python tools/medir-oidos.py [cuantos]
import io
import os
import sys
import glob
import json
import time
import wave
import unicodedata
import subprocess
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CUANTOS = int(sys.argv[1]) if len(sys.argv) > 1 else 0


def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return " ".join("".join(c if c.isalnum() or c.isspace() else " " for c in s).split())


def corpus():
    fuera = []
    for carpeta in ("cien", "dirigida", "validacion", "validacion2"):
        d = os.path.join(RAIZ, "pruebas", "audio", carpeta)
        p = os.path.join(d, "esperado.json")
        if not os.path.exists(p):
            continue
        try:
            j = json.load(io.open(p, encoding="utf-8-sig"))
        except Exception:
            continue
        for nombre, v in j.items():
            w = os.path.join(d, nombre)
            texto = (v.get("texto") if isinstance(v, dict) else v) or ""
            if os.path.exists(w) and texto:
                fuera.append({"wav": w, "verdad": texto, "de": carpeta,
                              "tipo": (v.get("tipo") if isinstance(v, dict) else "") or ""})
    return fuera


# EL HIJO CORRE APARTE a proposito: cargar dos modelos de ASR a la vez en una consola de
# 16 GB con Nova en marcha es como se mata el banco a medias (paso el 14/09). Uno, se mide,
# se cierra el proceso y se libera la RAM entera antes del siguiente.
HIJO = r'''
import sys, os, glob, json, time, wave
import numpy as np, sherpa_onnx
cual, lista = sys.argv[1], json.load(open(sys.argv[2], encoding="utf-8"))
RAIZ = sys.argv[3]
def dir_de(pat):
    d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", pat)) if os.path.isdir(c)]
    return d[0] if d else None
def f(d, pat): return sorted(glob.glob(os.path.join(d, pat)))[0]
t0 = time.time()
if cual == "parakeet":
    d = dir_de("*parakeet*")
    rec = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=f(d, "encoder*.onnx"), decoder=f(d, "decoder*.onnx"), joiner=f(d, "joiner*.onnx"),
        tokens=f(d, "tokens.txt"), num_threads=4, decoding_method="greedy_search",
        model_type="nemo_transducer")
else:
    d = dir_de("*canary*")
    rec = sherpa_onnx.OfflineRecognizer.from_nemo_canary(
        encoder=f(d, "encoder*.onnx"), decoder=f(d, "decoder*.onnx"),
        tokens=f(d, "tokens.txt"), src_lang="es", tgt_lang="es", num_threads=4)
carga = time.time() - t0
salidas, tTotal, segAudio = [], 0.0, 0.0
for w in lista:
    with wave.open(w, "rb") as x:
        a = np.frombuffer(x.readframes(x.getnframes()), dtype=np.int16).astype("float32")/32768.0
        tasa = x.getframerate()
        segAudio += x.getnframes()/float(tasa)
    t1 = time.time()
    s = rec.create_stream(); s.accept_waveform(tasa, a); rec.decode_stream(s)
    tTotal += time.time() - t1
    salidas.append(s.result.text)
print("@@" + json.dumps({"carga": carga, "seg": tTotal, "segAudio": segAudio, "salidas": salidas}, ensure_ascii=False))
'''


def corre(cual, wavs):
    base = tempfile.gettempdir()
    hijo = os.path.join(base, "_oido_%s.py" % cual)
    lista = os.path.join(base, "_wavs_%s.json" % cual)
    io.open(hijo, "w", encoding="utf-8", newline="\n").write(HIJO)
    io.open(lista, "w", encoding="utf-8").write(json.dumps(wavs))
    r = subprocess.run([sys.executable, hijo, cual, lista, RAIZ],
                       capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=5400)
    if r.returncode != 0:
        err = (r.stderr or "").strip().splitlines()
        return None, (err[-1][:200] if err else "codigo %d" % r.returncode)
    for linea in (r.stdout or "").splitlines():
        if linea.startswith("@@"):
            return json.loads(linea[2:]), None
    return None, "no devolvio resultado"


def acciones(frases):
    """Lo que la capa local HARIA con cada frase."""
    tmp = os.path.join(tempfile.gettempdir(), "medoido-%d.txt" % os.getpid())
    io.open(tmp, "w", encoding="utf-8", newline="\n").write("\n".join(frases) + "\n")
    res = {}
    try:
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                            "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%s' -Probar '%s'"
                            % (os.path.join(RAIZ, "assistant.ps1"), tmp)],
                           capture_output=True, timeout=1800)
        for linea in r.stdout.decode("utf-8", "replace").splitlines():
            t = linea.strip()
            if t.startswith("OK") and "->" in t:
                izq, _, der = t[2:].strip().rpartition("->")
                res[plano(izq)] = plano(der)
            elif t.startswith("->IA"):
                res[plano(t[4:])] = ""
            elif t.startswith("SALTO"):
                res[plano(t[5:].split("(")[0])] = "<salto>"
    except Exception as e:
        print("  (no pude preguntarle a la capa local: %s)" % e)
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass
    return res


def main():
    datos = corpus()
    if CUANTOS:
        datos = datos[:CUANTOS]
    if not datos:
        print("  no hay grabaciones con su texto de verdad")
        return 1
    wavs = [d["wav"] for d in datos]
    print("")
    print("  %d grabaciones suyas, con el texto que dijo de verdad apuntado" % len(datos))
    print("")

    res = {}
    for cual, etiqueta in (("parakeet", "Parakeet 0.6b (lo de hoy)"),
                           ("canary", "Canary 180m, src_lang=es")):
        print("  midiendo %s..." % etiqueta)
        r, err = corre(cual, wavs)
        if err:
            print("     NO SE PUDO: %s" % err)
            continue
        clav = sum(1 for d, s in zip(datos, r["salidas"]) if plano(s) == plano(d["verdad"]))
        r.update(etiqueta=etiqueta, clavadas=clav)
        res[cual] = r
        print("     %d/%d clavadas  |  %.0f ms por audio  |  x%.2f tiempo real  |  carga %.1f s"
              % (clav, len(datos), 1000.0 * r["seg"] / len(datos),
                 r["seg"] / max(0.001, r["segAudio"]), r["carga"]))

    if len(res) < 2:
        return 1

    # LO QUE DE VERDAD IMPORTA: ¿acaba en la misma accion?
    print("")
    print("  -- y lo unico que nota braya: ¿acaba en la MISMA accion? --")
    todas = set(plano(d["verdad"]) for d in datos)
    for r in res.values():
        todas.update(plano(s) for s in r["salidas"] if s)
    acc = acciones(sorted(x for x in todas if x))
    for cual, r in res.items():
        bien = 0
        for d, s in zip(datos, r["salidas"]):
            if acc.get(plano(d["verdad"]), "?") == acc.get(plano(s), "??"):
                bien += 1
        r["misma_accion"] = bien
        print("     %-32s %3d/%d  (%.1f %%)" % (r["etiqueta"], bien, len(datos),
                                                100.0 * bien / len(datos)))

    # Y EL FALLO DE IDIOMA, que es lo que se venia a arreglar
    print("")
    print("  -- las que salen en OTRO idioma (el fallo que se tapa tirando la frase) --")
    sys.path.insert(0, RAIZ)
    try:
        from wake_vosk import suena_ingles
    except Exception:
        suena_ingles = None
    for cual, r in res.items():
        n = sum(1 for s in r["salidas"] if s and suena_ingles and suena_ingles(s))
        r["suena_ingles"] = n
        print("     %-32s %3d de %d" % (r["etiqueta"], n, len(datos)))

    p, c = res.get("parakeet"), res.get("canary")
    if p and c:
        print("")
        print("  == EL VEREDICTO ==")
        print("     texto clavado:   %+d   (%d -> %d)" % (c["clavadas"] - p["clavadas"], p["clavadas"], c["clavadas"]))
        print("     misma accion:    %+d   (%d -> %d)" % (c["misma_accion"] - p["misma_accion"], p["misma_accion"], c["misma_accion"]))
        print("     suena a ingles:  %+d   (%d -> %d)" % (c["suena_ingles"] - p["suena_ingles"], p["suena_ingles"], c["suena_ingles"]))
        mp = 1000.0 * p["seg"] / len(datos)
        mc = 1000.0 * c["seg"] / len(datos)
        print("     tiempo:          %+.0f ms por audio (%.0f -> %.0f, x%.2f)" % (mc - mp, mp, mc, mc / max(1.0, mp)))
        print("     en disco:        641 MB -> 198 MB")

    salida = os.path.join(RAIZ, "tmp", "medida-oidos.json")
    try:
        io.open(salida, "w", encoding="utf-8").write(json.dumps(
            {k: {kk: vv for kk, vv in v.items() if kk != "salidas"} for k, v in res.items()},
            ensure_ascii=False, indent=1))
        # y las diferencias frase a frase, que es donde se ve si merece la pena
        det = []
        for i, d in enumerate(datos):
            sp = res["parakeet"]["salidas"][i]
            sc = res["canary"]["salidas"][i]
            if plano(sp) != plano(sc):
                det.append({"verdad": d["verdad"], "parakeet": sp, "canary": sc})
        io.open(os.path.join(RAIZ, "tmp", "medida-oidos-diferencias.json"), "w",
                encoding="utf-8").write(json.dumps(det, ensure_ascii=False, indent=1))
        print("")
        print("  detalle en tmp/medida-oidos.json y tmp/medida-oidos-diferencias.json (%d diferencias)" % len(det))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
