# -*- coding: utf-8 -*-
# ¿SE PUEDE AMPLIAR LO QUE NOVA ENTIENDE SIN QUE BRAYA HABLE MAS? (21/09)
#
# Lo pregunto el: "no se puede expandir mas el vocabulario sin que yo tenga que hablar,
# con alguna base de datos o cosas asi". Esto lo mide con SUS grabaciones, no de oidas.
#
# LO QUE SE MIDE, y por que estas tres cosas:
#   1. PARAKEET TAL COMO ESTA HOY (greedy_search, sin hotwords)  <- la referencia
#   2. PARAKEET CON modified_beam_search, sin hotwords           <- lo que cuesta el cambio
#   3. PARAKEET CON modified_beam_search Y hotwords              <- lo que se gana
# Las hotwords de sherpa-onnx SOLO funcionan con modified_beam_search (lo dice su propia
# documentacion), y hoy Nova usa greedy. Asi que activar las hotwords obliga a cambiar el
# decodificador, y eso tiene un precio en tiempo. La 2 existe para separar las dos cosas:
# si el beam search solo ya mejora, no hay que atribuirselo a las hotwords.
#
# Y SE MIDEN DOS COSAS DISTINTAS EN CADA UNA:
#   - si el TEXTO sale clavado (lo que se suele medir, y no es lo que importa)
#   - si ACABA EN LA MISMA ACCION (lo unico que nota braya)
# Un "abre estim" que acaba abriendo Steam es un acierto aunque el texto este mal.
#
# LA VELOCIDAD MANDA (es su preferencia numero uno): si el beam search tarda mas de lo que
# gana, la respuesta es que NO, y hay que decirlo con el numero delante.
#
# Uso:   python tools/medir-vocabulario.py [cuantos]
import io
import os
import sys
import glob
import json
import time
import wave
import unicodedata

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CUANTOS = int(sys.argv[1]) if len(sys.argv) > 1 else 0   # 0 = todos


def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return " ".join("".join(c if c.isalnum() or c.isspace() else " " for c in s).split())


def corpus():
    """Las grabaciones que tienen su texto DE VERDAD apuntado."""
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
            if not os.path.exists(w):
                continue
            texto = v.get("texto") if isinstance(v, dict) else v
            tipo = (v.get("tipo") if isinstance(v, dict) else "") or ""
            if not texto:
                continue
            fuera.append({"wav": w, "verdad": texto, "tipo": tipo, "de": carpeta})
    return fuera


def lee(ruta):
    with wave.open(ruta, "rb") as f:
        import numpy as np
        datos = f.readframes(f.getnframes())
        a = np.frombuffer(datos, dtype=np.int16).astype("float32") / 32768.0
        return a, f.getframerate()


def nombres_propios():
    """LO QUE NOVA PUEDE SABER SIN PREGUNTAR: de sus propios archivos, no de la nube."""
    fuera = []
    # el nombre y las apps que ya conoce
    try:
        c = json.load(io.open(os.path.join(RAIZ, "commands.json"), encoding="utf-8-sig"))
        fuera += [k for k in (c.get("apps") or {})]
        fuera += [k for k in (c.get("sitios") or {})]
    except Exception:
        pass
    # los juegos de todas las tiendas
    try:
        import subprocess
        r = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "Get-ChildItem 'C:\\Program Files (x86)\\Steam\\steamapps\\common',"
                            "'C:\\XboxGames' -Directory -ErrorAction SilentlyContinue | "
                            "ForEach-Object { $_.Name }"],
                           capture_output=True, text=True, timeout=30)
        fuera += [x.strip() for x in r.stdout.splitlines() if x.strip()]
    except Exception:
        pass
    # limpieza: nada de una letra, ni repetidos, ni cosas que nadie dice en voz alta
    vistos, limpio = set(), []
    for n in fuera:
        n = (n or "").strip()
        if len(n) < 3 or plano(n) in vistos:
            continue
        vistos.add(plano(n))
        limpio.append(n)
    return limpio


def carga_parakeet(metodo, hotwords_file=None, score=1.5):
    import sherpa_onnx
    d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*parakeet*")) if os.path.isdir(c)][0]

    def f(pat):
        return sorted(glob.glob(os.path.join(d, pat)))[0]
    kw = dict(encoder=f("encoder*.onnx"), decoder=f("decoder*.onnx"), joiner=f("joiner*.onnx"),
              tokens=f("tokens.txt"), num_threads=4, decoding_method=metodo,
              model_type="nemo_transducer")
    if hotwords_file:
        kw["hotwords_file"] = hotwords_file
        kw["hotwords_score"] = score
        kw["modeling_unit"] = "bpe"
        bpe = os.path.join(d, "bpe.model")
        if os.path.exists(bpe):
            kw["bpe_vocab"] = bpe
    t0 = time.time()
    r = sherpa_onnx.OfflineRecognizer.from_transducer(**kw)
    return r, time.time() - t0


def transcribe(rec, audio, tasa):
    s = rec.create_stream()
    s.accept_waveform(tasa, audio)
    rec.decode_stream(s)
    return s.result.text


def accion_de(frases):
    """Lo que la capa local HARIA con cada frase. Es lo unico que nota braya."""
    import subprocess
    import tempfile
    tmp = os.path.join(tempfile.gettempdir(), "medvoc-%d.txt" % os.getpid())
    io.open(tmp, "w", encoding="utf-8", newline="\n").write("\n".join(frases) + "\n")
    res = {}
    try:
        r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                            "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%s' -Probar '%s'"
                            % (os.path.join(RAIZ, "assistant.ps1"), tmp)],
                           capture_output=True, timeout=900)
        for linea in r.stdout.decode("utf-8", "replace").splitlines():
            t = linea.strip()
            if t.startswith("OK") and "->" in t:
                cuerpo = t[2:].strip()
                izq, _, der = cuerpo.rpartition("->")
                res[plano(izq)] = der.strip()
            elif t.startswith("->IA"):
                res[plano(t[4:])] = ""
    except Exception as e:
        print("  (no pude preguntarle a la capa local: %s)" % e)
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass
    return res


def mide(nombre, rec, datos, carga):
    t0 = time.time()
    salidas = []
    for d in datos:
        a, tasa = lee(d["wav"])
        salidas.append(transcribe(rec, a, tasa))
    seg = time.time() - t0
    clavadas = sum(1 for d, s in zip(datos, salidas) if plano(s) == plano(d["verdad"]))
    return {"nombre": nombre, "carga_s": carga, "seg": seg,
            "ms_por_audio": (seg * 1000.0) / max(1, len(datos)),
            "clavadas": clavadas, "total": len(datos), "salidas": salidas}


def main():
    datos = corpus()
    if CUANTOS:
        datos = datos[:CUANTOS]
    if not datos:
        print("  no hay grabaciones con su texto de verdad")
        return 1
    print("")
    print("  %d grabaciones con su texto de verdad (%s)"
          % (len(datos), ", ".join(sorted(set(d["de"] for d in datos)))))

    props = nombres_propios()
    import tempfile
    fh = os.path.join(tempfile.gettempdir(), "hotwords-nova.txt")
    io.open(fh, "w", encoding="utf-8", newline="\n").write("\n".join(props) + "\n")
    print("  %d nombres propios sacados de su propia maquina (sin nube, sin preguntarle)" % len(props))
    print("")

    pruebas = [
        ("1. como esta hoy (greedy, sin hotwords)", "greedy_search", None),
        ("2. beam search, sin hotwords", "modified_beam_search", None),
        ("3. beam search CON hotwords", "modified_beam_search", fh),
    ]
    res = []
    for etiqueta, metodo, hot in pruebas:
        try:
            rec, carga = carga_parakeet(metodo, hot)
        except Exception as e:
            print("  %-42s NO SE PUDO: %s" % (etiqueta, str(e)[:120]))
            continue
        r = mide(etiqueta, rec, datos, carga)
        res.append(r)
        print("  %-42s %3d/%d clavadas  %6.0f ms/audio  (carga %.1f s)"
              % (etiqueta, r["clavadas"], r["total"], r["ms_por_audio"], r["carga_s"]))
        del rec

    if not res:
        return 1

    # Y LO QUE DE VERDAD IMPORTA: ¿acaba en la misma accion?
    print("")
    print("  -- y lo unico que nota braya: ¿acaba en la MISMA accion? --")
    todas = set()
    for r in res:
        todas.update(plano(s) for s in r["salidas"] if s)
    todas.update(plano(d["verdad"]) for d in datos)
    acc = accion_de(sorted(x for x in todas if x))
    for r in res:
        bien = 0
        for d, s in zip(datos, r["salidas"]):
            aV = acc.get(plano(d["verdad"]), "")
            aS = acc.get(plano(s), "")
            # si la frase buena no es una orden, acierta si lo oido tampoco lo es
            bien += 1 if (aS == aV) else 0
        r["misma_accion"] = bien
        print("  %-42s %3d/%d  (%.1f %%)" % (r["nombre"], bien, len(datos), 100.0 * bien / len(datos)))

    base = res[0]
    print("")
    print("  -- el veredicto --")
    for r in res[1:]:
        dTexto = r["clavadas"] - base["clavadas"]
        dAcc = r.get("misma_accion", 0) - base.get("misma_accion", 0)
        dMs = r["ms_por_audio"] - base["ms_por_audio"]
        print("  %s" % r["nombre"])
        print("     texto: %+d   accion: %+d   tiempo: %+.0f ms por audio (%.1fx)"
              % (dTexto, dAcc, dMs, r["ms_por_audio"] / max(1.0, base["ms_por_audio"])))
    salida = os.path.join(RAIZ, "tmp", "medida-vocabulario.json")
    try:
        io.open(salida, "w", encoding="utf-8").write(json.dumps(
            [{k: v for k, v in r.items() if k != "salidas"} for r in res], ensure_ascii=False, indent=1))
        print("")
        print("  detalle en tmp/medida-vocabulario.json")
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
