# -*- coding: utf-8 -*-
r"""Las cuentas de las 100 grabaciones (tools\grabar-100.py): que ajustar, con datos.

    python tools\analizar-100.py

Con Nova APAGADA (carga Whisper base, small y Vosk: ~1,5 GB) y ~10 minutos.
Pasa cada grabacion por el MISMO camino que el asistente -Whisper base, el repaso
con small cuando toca, la capa local de verdad (assistant.ps1 -Probar)- y saca:

  1. Aciertos por tipo (orden, charla, corte, con el nombre) y por tono.
  2. Tu tono de voz en cada forma de hablar -> el margen del corte por tono
     (MARGEN_CORTE_HZ en wake_vosk.py). La voz de Nova medida va de 165 a 327 Hz.
  3. La seguridad de Whisper cuando acierta y cuando se equivoca -> el umbral del
     repaso dudoso (config.json input.repasoDudoso).
  4. Las pausas dentro de las ordenes -> cuanto silencio cierra la frase
     (SILENCIO_FIN y SILENCIO_FIN_LOTENGO en wake_vosk.py).
  5. Las palabras que se oyen mal una y otra vez -> correcciones de commands.json.
  6. El volumen de cada tono (voz baja, desde lejos).

No cambia nada: lo deja escrito en pruebas\audio\cien\informe.md para decidir.
"""
import ast
import collections
import importlib.util
import json
import os
import re
import sys
import time
import wave

import numpy as np

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# otra carpeta como argumento: para probar este analisis sin tener las 100 hechas.
# --turbo: simula tambien el ULTIMO RECURSO (large-v3-turbo cuando base y small no
# sacan ninguna orden), como hace el asistente fuera de los juegos (15/09)
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
CON_TURBO = "--turbo" in sys.argv[1:]
CARPETA = ARGS[0] if ARGS else os.path.join(RAIZ, "pruebas", "audio", "cien")
TASA = 16000
VOZ_NOVA_MIN_HZ = 165.0     # medido el 14/09 sobre la voz en linea (es-MX-DaliaNeural)

spec = importlib.util.spec_from_file_location("pa", os.path.join(RAIZ, "tools", "probar-audio.py"))
pa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pa)

# de wake_vosk.py se sacan SOLO piezas puras (importarlo abriria el microfono)
fuente = open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
import unicodedata
ns = {"np": np, "TASA": TASA, "re": re, "unicodedata": unicodedata}
for n in ast.parse(fuente).body:
    nombre = n.targets[0].id if isinstance(n, ast.Assign) and isinstance(n.targets[0], ast.Name) else getattr(n, "name", None)
    if nombre in ("estimar_f0", "MARGEN_CORTE_HZ", "SILENCIO_FIN", "SILENCIO_FIN_LOTENGO", "PALABRAS_CORTE", "PROMPT_ORDENES", "es_eco_del_ejemplo"):
        exec(ast.get_source_segment(fuente, n), ns)
estimar_f0 = ns["estimar_f0"]


def cfg(*camino, defecto=None):
    try:
        with open(os.path.join(RAIZ, "config.json"), encoding="utf-8-sig") as f:
            c = json.load(f)
        for k in camino:
            c = c[k]
        return c
    except Exception:
        return defecto


UMBRAL_DUDOSO = float(cfg("input", "repasoDudoso", defecto=-0.9))
UMBRAL_ECO = float(cfg("input", "repasoEco", defecto=-0.5))


def lee(ruta):
    with wave.open(ruta, "rb") as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32767.0


def f0_de(a):
    return estimar_f0([np.clip(a * 32767, -32768, 32767).astype(np.int16)])


def pausas(a):
    """Silencio al principio, pausa interna mas larga y duracion de la voz."""
    tr = 480  # 30 ms
    e = np.array([np.sqrt(np.mean(a[i:i + tr] ** 2)) for i in range(0, max(0, len(a) - tr), tr)])
    if e.size == 0:
        return 0.0, 0.0, 0.0
    # EL MISMO CORTE QUE segundos_de_voz EN wake_vosk.py, y por el mismo motivo (22/09): el
    # 0,008 a secas se calibro con el array de Realtek, y con el micro USB que braya enchufo
    # el 22/09 el silencio esta en 0,018-0,025, por encima de el. Con el corte viejo esta
    # funcion daba el fichero entero como voz y las cuentas de esta herramienta -que es JUSTO
    # con la que se deciden los listones- salian mal. El suelo sale ahora del propio audio.
    # Si se toca aqui, hay que tocarlo alli: son la misma medida a proposito.
    umbral = max(0.008, float(np.percentile(e, 20)) * 1.8, float(np.percentile(e, 90)) * 0.15)
    idx = np.where(e > umbral)[0]
    if idx.size == 0:
        return 0.0, 0.0, 0.0
    ini, fin = int(idx[0]), int(idx[-1])
    mayor, racha = 0, 0
    for v in (e[ini:fin + 1] > umbral):
        racha = 0 if v else racha + 1
        mayor = max(mayor, racha)
    return ini * 0.03, mayor * 0.03, (fin - ini) * 0.03


def transcribir(modelo, audio, hw):
    segs, _ = modelo.transcribe(audio, language="es", beam_size=2, best_of=1, vad_filter=True,
                                vad_parameters=dict(min_silence_duration_ms=500), condition_on_previous_text=False,
                                no_speech_threshold=0.6, log_prob_threshold=-1.0, compression_ratio_threshold=2.4, initial_prompt=ns.get("PROMPT_ORDENES"))
    partes, peor = [], 0.0
    for s in segs:
        partes.append(s.text.strip())
        peor = min(peor, float(s.avg_logprob))
    return pa.limpiar_whisper(" ".join(partes)), peor


RE_NOMBRE = re.compile(r"^\s*(?:oye|hey|ey)?\s*nova\s*[,.]?\s*", re.IGNORECASE)


def sin_nombre(t):
    return RE_NOMBRE.sub("", t or "").strip()


def merece_repaso(t):
    return any(len(w) >= 4 for w in pa.plano(t).split())


def norm_accion(a):
    return re.sub(r"\d{1,2}:\d{2}", "H:M", a or "")


def mediana(xs):
    xs = [x for x in xs if x]
    return float(np.median(xs)) if xs else 0.0


def main():
    ruta_esp = os.path.join(CARPETA, "esperado.json")
    if not os.path.exists(ruta_esp):
        print("No hay grabaciones: primero  python tools\\grabar-100.py")
        return 0
    esperado = json.load(open(ruta_esp, encoding="utf-8"))
    clips = [n for n in sorted(esperado) if os.path.exists(os.path.join(CARPETA, n))]
    print("%d de %d grabaciones" % (len(clips), len(esperado)))
    if not clips:
        return 0
    audios = {n: lee(os.path.join(CARPETA, n)) for n in clips}
    datos = {}
    for n in clips:
        a = audios[n]
        ini, pausa, voz = pausas(a)
        datos[n] = dict(esperado[n], clip=n, dur=a.size / TASA, pico=float(np.max(np.abs(a))) if a.size else 0.0,
                        rms=float(np.sqrt(np.mean(a ** 2))) if a.size else 0.0, f0=f0_de(a), inicio=ini, pausa=pausa, voz=voz)

    from faster_whisper import WhisperModel
    hw = pa.vocabulario()
    t0 = time.time()
    base = WhisperModel(cfg("input", "whisperModelo", defecto="base") or "base", device="cpu", compute_type="int8", cpu_threads=8)
    for n in clips:
        t1 = time.time()
        txt, seg = transcribir(base, audios[n], hw)
        datos[n].update(base=txt, seguridad=seg, t_base=time.time() - t1)
    del base
    print("base: %.0f s" % (time.time() - t0))
    t0 = time.time()
    small = WhisperModel(cfg("input", "whisperModeloPreciso", defecto="small") or "small", device="cpu", compute_type="int8", cpu_threads=8)
    for n in clips:
        t1 = time.time()
        txt, seg = transcribir(small, audios[n], hw)
        datos[n].update(small=txt, seguridad_small=seg, t_small=time.time() - t1)
    del small
    print("small: %.0f s" % (time.time() - t0))

    # PARAKEET PRIMERO (15/09), como la escucha: si esta instalado, oye antes que Whisper
    import glob as _glob
    dir_pk = [x for x in _glob.glob(os.path.join(RAIZ, "modelos", "*parakeet*")) if os.path.isdir(x)]
    if dir_pk and "--sin-parakeet" not in sys.argv:
        import sherpa_onnx
        b = lambda patron: sorted(_glob.glob(os.path.join(dir_pk[0], patron)))[0]
        pk = sherpa_onnx.OfflineRecognizer.from_transducer(encoder=b("encoder*.onnx"), decoder=b("decoder*.onnx"), joiner=b("joiner*.onnx"),
                                                           tokens=b("tokens.txt"), num_threads=8, decoding_method="greedy_search", model_type="nemo_transducer")
        t0 = time.time()
        for n in clips:
            t1 = time.time()
            st = pk.create_stream()
            st.accept_waveform(TASA, audios[n].astype(np.float32))
            pk.decode_stream(st)
            datos[n].update(parakeet=pa.limpiar_whisper(st.result.text.strip()), t_parakeet=time.time() - t1)
        del pk
        print("parakeet: %.0f s" % (time.time() - t0))

    # la capa local de verdad, una sola vez para todas las frases
    frases = []
    for d in datos.values():
        frases += [d["texto"], sin_nombre(d["base"]), sin_nombre(d["small"]), sin_nombre(d.get("parakeet", ""))]
    acc = pa.acciones_de(frases)
    accion = lambda t: norm_accion(acc.get((t or "").strip(), ""))

    for d in datos.values():
        quiero = accion(d["texto"])
        d["quiero"] = quiero
        ab, asm = accion(sin_nombre(d["base"])), accion(sin_nombre(d["small"]))
        d["accion_base"], d["accion_small"] = ab, asm
        # la estrategia del asistente: base; con orden entendida pero seguridad baja,
        # repaso (y se queda el repaso si trae orden); sin orden, repaso si merece
        d["eco"] = bool(ns["es_eco_del_ejemplo"](d["base"])) if "es_eco_del_ejemplo" in ns else False
        if ab and d["eco"] and d["seguridad"] < UMBRAL_ECO:
            # eco del ejemplo con poca seguridad: solo si el repaso lo confirma, y un eco no
            # confirma a otro eco (tanda dirigida: "pon modo noche" -> small "Que hora es")
            # ... salvo que los dos modelos oigan exactamente lo mismo (15/09)
            final = asm if (not ns["es_eco_del_ejemplo"](d["small"]) or pa.plano(d["small"]) == pa.plano(d["base"])) else ""
        elif ab and d["seguridad"] >= UMBRAL_DUDOSO:
            final = ab
        elif ab:
            final = asm or ab
        elif merece_repaso(d["base"]):
            final = asm
        else:
            final = ""
        # si Parakeet saco una orden, es la que se hace (no llega a Whisper)
        ap = accion(sin_nombre(d.get("parakeet", "")))
        d["accion_parakeet"] = ap
        if ap:
            final = ap
        d["accion_final"] = final
        if d["tipo"] in ("charla", "ruido"):
            # charla y ruido de fondo: acierta si NO se hace nada
            d["ok_base"] = not ab
            d["ok"] = not final
        elif d["tipo"] == "corte":
            d["ok_base"] = d["ok"] = None
        else:
            d["ok_base"] = bool(quiero) and ab == quiero
            d["ok"] = bool(quiero) and final == quiero

    if CON_TURBO:
        # el ultimo recurso solo cuando base y small no sacan orden (o no confirman un eco),
        # nunca con lo que es charla: se aproxima con el tipo de la grabacion
        faltan = [d for d in datos.values() if d["tipo"] not in ("corte", "charla") and not d["accion_final"] and not d.get("accion_parakeet")]
        if faltan:
            t0 = time.time()
            turbo = WhisperModel("large-v3-turbo", device="cpu", compute_type="int8", cpu_threads=8)
            for d in faltan:
                t1 = time.time()
                txt, _ = transcribir(turbo, audios[d["clip"]], hw)
                d.update(turbo=txt, t_turbo=time.time() - t1)
            del turbo
            print("turbo: %d frases en %.0f s" % (len(faltan), time.time() - t0))
            acc2 = pa.acciones_de([sin_nombre(d["turbo"]) for d in faltan])
            for d in faltan:
                at = norm_accion(acc2.get(sin_nombre(d["turbo"]).strip(), ""))
                eco_t = ns["es_eco_del_ejemplo"](d["turbo"]) if "es_eco_del_ejemplo" in ns else False
                if at and (not eco_t or pa.plano(d["turbo"]) == pa.plano(d["base"])):
                    d["accion_final"] = at
                    d["por_turbo"] = True
                    d["ok"] = (not at) if d["tipo"] == "ruido" else (bool(d["quiero"]) and at == d["quiero"])

    corte = {}
    try:
        from vosk import Model, KaldiRecognizer, SetLogLevel
        SetLogLevel(-1)
        modelo = Model(os.path.join(RAIZ, "vosk", "vosk-model-small-es-0.42"))
        palabras = ns.get("PALABRAS_CORTE") or ["espera", "para", "calla", "callate", "basta", "silencio"]
        for d in datos.values():
            if d["tipo"] != "corte":
                continue
            r = KaldiRecognizer(modelo, TASA, json.dumps(palabras + ["[unk]"]))
            r.SetWords(True)
            pcm = (np.clip(audios[d["clip"]], -1, 1) * 32767).astype("<i2").tobytes()
            oidas = []
            for i in range(0, len(pcm), 8000):
                if r.AcceptWaveform(pcm[i:i + 8000]):
                    oidas += json.loads(r.Result()).get("result") or []
            oidas += json.loads(r.FinalResult()).get("result") or []
            buenas = [w for w in oidas if w.get("word") in palabras and float(w.get("conf", 0)) >= 0.9]
            corte[d["clip"]] = buenas[0] if buenas else None
    except Exception as e:  # noqa: BLE001
        print("  (sin Vosk para las palabras de corte: %s)" % e)

    L = []
    p = L.append
    p("# Las 100 grabaciones: informe (%s)" % time.strftime("%d/%m/%Y %H:%M"))
    p("")
    p("%d grabaciones. Umbral del repaso dudoso usado: %.2f." % (len(clips), UMBRAL_DUDOSO))
    p("")
    p("## 1. Aciertos")
    p("")
    p("| tipo | grabaciones | solo base | como el asistente |")
    p("|---|---|---|---|")
    for tipo in ("orden", "compuesta", "nova", "charla", "ruido"):
        ds = [d for d in datos.values() if d["tipo"] == tipo]
        if ds:
            p("| %s | %d | %d | %d |" % (tipo, len(ds), sum(bool(d["ok_base"]) for d in ds), sum(bool(d["ok"]) for d in ds)))
    evaluables = [d for d in datos.values() if d["ok"] is not None]
    equivocadas = [d for d in evaluables if d["accion_final"] and d["accion_final"] != d.get("quiero", "")]
    p("")
    p("**Total: %d de %d (%.0f %%). Órdenes equivocadas (hace otra cosa): %d.** Meta: 100 %% y 0." % (
        sum(bool(d["ok"]) for d in evaluables), len(evaluables), 100.0 * sum(bool(d["ok"]) for d in evaluables) / max(1, len(evaluables)), len(equivocadas)))
    for d in equivocadas:
        p("- EQUIVOCADA %s «%s» (%s) -> [%s]" % (d["clip"], d["decir"], d["tono"], d["accion_final"]))
    p("")
    p("| tono | ordenes | como el asistente | tono de voz (mediana) | pico (mediana) |")
    p("|---|---|---|---|---|")
    for tono in sorted({d["tono"] for d in datos.values()}):
        ds = [d for d in datos.values() if d["tono"] == tono and d["tipo"] in ("orden", "compuesta", "nova")]
        todos = [d for d in datos.values() if d["tono"] == tono]
        p("| %s | %d | %d | %.0f Hz | %.2f |" % (tono, len(ds), sum(bool(d["ok"]) for d in ds), mediana([d["f0"] for d in todos]),
                                               mediana([d["pico"] for d in todos])))
    p("")
    p("Tiempo medio por frase: base %.2f s, small %.2f s." % (np.mean([d["t_base"] for d in datos.values()]), np.mean([d["t_small"] for d in datos.values()])))
    con_pk = [d for d in datos.values() if "parakeet" in d]
    if con_pk:
        p("")
        p("**Parakeet primero:** saca orden en %d de %d frases (%.2f s de media); de ellas, equivocadas: %d." % (
            sum(1 for d in con_pk if d.get("accion_parakeet")), len(con_pk), np.mean([d["t_parakeet"] for d in con_pk]),
            sum(1 for d in con_pk if d.get("accion_parakeet") and d["accion_parakeet"] != d.get("quiero", ""))))
    if CON_TURBO:
        tt = [d["t_turbo"] for d in datos.values() if "t_turbo" in d]
        pt = [d for d in datos.values() if d.get("por_turbo")]
        p("")
        p("**Con el último recurso (turbo):** usado en %d frases (%.1f s de media); aporta %d aciertos y %d órdenes equivocadas." % (
            len(tt), np.mean(tt) if tt else 0, sum(bool(d["ok"]) for d in pt), sum(1 for d in pt if not d["ok"])))
    p("")
    malas = [d for d in datos.values() if d["ok"] is False]
    if malas:
        p("Las que fallan (como el asistente):")
        p("")
        for d in malas:
            p("- %s «%s» (%s) -> base «%s» [%s], small «%s» [%s]" % (d["clip"], d["decir"], d["tono"], d["base"], d["accion_base"] or "nada",
                                                                 d["small"], d["accion_small"] or "nada"))
        p("")

    p("## 2. Tono: el corte por voz")
    p("")
    duena = mediana([d["f0"] for d in datos.values() if d["tono"] == "normal" and d["tipo"] in ("orden", "nova")])
    margen_actual = float(ns.get("MARGEN_CORTE_HZ", 40.0))
    p("Tu tono normal (mediana de las ordenes normales): **%.0f Hz**. Margen actual: %.0f Hz. La voz de Nova empieza en %.0f Hz." % (duena, margen_actual, VOZ_NOVA_MIN_HZ))
    p("")
    difs = []
    for d in sorted(datos.values(), key=lambda d: d["clip"]):
        if d["tipo"] == "corte" or d["tono"] in ("fuerte", "grito"):
            dif = abs(d["f0"] - duena) if d["f0"] and duena else None
            if dif is not None:
                difs.append(dif)
            extra = ""
            if d["tipo"] == "corte":
                w = corte.get(d["clip"])
                extra = " | Vosk: %s" % ("'%s' %.2f" % (w["word"], float(w["conf"])) if w else "no la reconoce")
            p("- %s «%s» (%s): %s%s%s" % (d["clip"], d["decir"], d["tono"], "%.0f Hz" % d["f0"] if d["f0"] else "tono no medible",
                                         " (a %.0f Hz del tuyo)" % dif if dif is not None else "", extra))
    p("")
    if difs and duena:
        necesario = max(difs) + 5
        techo = VOZ_NOVA_MIN_HZ - duena - 5
        if necesario <= margen_actual:
            p("**Recomendación:** el margen de %.0f Hz ya cubre todas tus formas de hablar (la más lejana, a %.0f Hz). Sin cambios." % (margen_actual, max(difs)))
        elif necesario <= techo:
            p("**Recomendación:** subir MARGEN_CORTE_HZ a **%.0f** (tu voz llega a %.0f Hz del tono normal y la de Nova empieza a %.0f)." % (necesario, max(difs), techo + 5))
        else:
            p("**Ojo:** gritando llegas a %.0f Hz de tu tono normal, y la voz de Nova empieza a %.0f: el tono ya no las separa. Hace falta otra señal (el nivel del micrófono frente al del altavoz)." % (max(difs), techo + 5))
    no_medibles = [d["clip"] for d in datos.values() if d["tipo"] == "corte" and not d["f0"]]
    if no_medibles:
        p("")
        p("Palabras de corte con tono no medible (con tu tono aprendido NO cortarían): %s." % ", ".join(no_medibles))
    p("")

    p("## 3. Seguridad de Whisper: el repaso dudoso")
    p("")
    bien = [d["seguridad"] for d in datos.values() if d["tipo"] in ("orden", "compuesta", "nova") and d["accion_base"] and d["accion_base"] == d["quiero"]]
    mal = [d for d in datos.values() if d["tipo"] in ("orden", "compuesta", "nova", "charla", "ruido") and d["accion_base"] and d["accion_base"] != d["quiero"]]
    if bien:
        p("Base acierta la orden: seguridad de %.2f a %.2f (mediana %.2f), %d frases." % (min(bien), max(bien), float(np.median(bien)), len(bien)))
    if mal:
        p("Base entiende OTRA orden (lo peligroso): %d frases." % len(mal))
        for d in mal:
            p("- %s «%s» -> «%s» [%s], seguridad %.2f" % (d["clip"], d["decir"], d["base"], d["accion_base"], d["seguridad"]))
        peor_mal = max(d["seguridad"] for d in mal)
        if bien and peor_mal < min(bien):
            p("")
            p("**Recomendación:** repasoDudoso en **%.2f**: repasa todas las equivocadas sin tocar ninguna buena." % ((peor_mal + min(bien)) / 2))
        else:
            p("")
            p("**Ojo:** hay equivocadas con tanta seguridad como las buenas; el umbral solo no las separa.")
    else:
        p("Base nunca entendió otra orden distinta. **Sin cambios** en el umbral (%.2f)." % UMBRAL_DUDOSO)
    p("")

    p("## 4. Pausas: cuándo se da la frase por terminada")
    p("")
    normales = [d["pausa"] for d in datos.values() if d["tipo"] in ("orden", "nova")]
    compuestas = [d["pausa"] for d in datos.values() if d["tipo"] == "compuesta"]
    fin_lotengo = float(ns.get("SILENCIO_FIN_LOTENGO", 0.8))
    fin_normal = float(ns.get("SILENCIO_FIN", 1.4))
    if normales:
        p95 = float(np.percentile(normales, 95))
        p("Pausa más larga dentro de una orden: máx. %.2f s, el 95 %% por debajo de %.2f s. Cierre rápido actual: %.1f s." % (max(normales), p95, fin_lotengo))
        rec = max(0.6, round(max(normales) + 0.25, 1))
        p("**Recomendación:** SILENCIO_FIN_LOTENGO en **%.1f s**%s." % (rec, " (sin cambios)" if abs(rec - fin_lotengo) < 0.05 else ""))
    if compuestas:
        p("Pausas pedidas a propósito (compuestas): de %.2f a %.2f s. Cierre normal actual: %.1f s%s." % (
            min(compuestas), max(compuestas), fin_normal, "; **alguna supera el cierre: se cortaría la frase**" if max(compuestas) >= fin_normal else ""))
    p("")

    p("## 5. Lo que se oye mal una y otra vez")
    p("")
    cuenta = collections.Counter()
    ejemplos = {}
    for d in datos.values():
        if d["ok"] is not False:
            continue
        quiero = set(pa.plano(d["texto"]).split())
        for oido in (d["base"], d["small"]):
            for w in pa.plano(sin_nombre(oido)).split():
                if w not in quiero and len(w) >= 3:
                    cuenta[w] += 1
                    ejemplos.setdefault(w, "«%s» por «%s»" % (oido, d["decir"]))
    repetidas = [(w, c) for w, c in cuenta.most_common(15) if c >= 2]
    if repetidas:
        for w, c in repetidas:
            p("- **%s** (%d veces), p. ej. %s" % (w, c, ejemplos[w]))
        p("")
        p("Candidatas a corrección en commands.json SOLO si no son palabras normales del castellano.")
    else:
        p("Ninguna palabra mal oída se repite: no hacen falta correcciones nuevas.")
    p("")

    p("## 6. Volumen")
    p("")
    if not any(d["tono"] in ("bajo", "lejos") for d in datos.values()):
        p("Sin grabaciones en voz baja ni desde lejos.")
    for tono in ("bajo", "lejos"):
        ds = [d for d in datos.values() if d["tono"] == tono]
        if ds:
            flojas = [d["clip"] for d in ds if d["pico"] < 0.05]
            p("- %s: pico mediano %.2f; %d de %d aciertan%s." % (tono, mediana([d["pico"] for d in ds]), sum(bool(d["ok"]) for d in ds if d["ok"] is not None),
                                                                 len([d for d in ds if d["ok"] is not None]), "; muy flojas: " + ", ".join(flojas) if flojas else ""))
    p("")

    informe = "\n".join(L)
    with open(os.path.join(CARPETA, "informe.md"), "w", encoding="utf-8") as f:
        f.write(informe + "\n")
    with open(os.path.join(CARPETA, "datos.json"), "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=1)
    print("")
    print(informe)
    print("")
    print("Guardado en %s (y los datos crudos en datos.json)" % os.path.join(CARPETA, "informe.md"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
