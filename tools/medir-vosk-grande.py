# -*- coding: utf-8 -*-
r"""C25 / OID-2 (OIDO-2026-09-19.md:80-82): medir el Vosk GRANDE (vosk-model-es-0.42, 2,3 GB).

Lleva descargado desde el 19/09 y NUNCA se ha medido con el pipeline de hoy. O sirve o se
borra, y esto es lo unico que puede decidirlo con datos.

Mide lo mismo que el resto de la familia (pruebas/pipeline-hoy.py, pruebas/exp-hoy.py):
texto, accion que resuelve, segundos por clip y RAM, sobre las grabaciones de uso real de
pruebas\audio\uso (311 clips, 1.764 s de audio contados el 19/09).

UN MODELO CADA VEZ: se carga, se mide, se suelta y se comprueba que la RAM vuelve. Los dos
a la vez son 2,4 GB y la consola son 16 GB con 4 nucleos (VRAM-2026-09-19.md).

NO lo lances con Nova encendida: el worker ya tiene su Vosk small cargado y pelea por los
4 nucleos, asi que los segundos por clip saldrian inflados y la RAM libre, mentira. Para
Nova antes con tools\parar-nova.ps1.

Uso:
    python tools\medir-vosk-grande.py            small, grande y el recuento de acciones
    python tools\medir-vosk-grande.py small      solo oir con el pequeno
    python tools\medir-vosk-grande.py grande     solo oir con el grande
    python tools\medir-vosk-grande.py acciones   solo el recuento (no carga ningun modelo)
Se puede parar a media y repetir: lo ya oido se guarda y se salta.
"""
import ast, gc, io, json, os, subprocess, sys, tempfile, time, wave
import numpy as np

REPO = r"C:\Users\braya\Documents\voice-ctrl"
USO = os.path.join(REPO, "pruebas", "audio", "uso")
# El resultado va DENTRO de pruebas\audio\ a proposito: el repositorio es PUBLICO y
# .gitignore:33 ya tapa esa carpeta entera. Este JSON lleva transcrito lo que dices en las
# grabaciones, o sea que es exactamente igual de privado que los WAV.
SAL = os.path.join(REPO, "pruebas", "audio", "medir-vosk-grande.json")

MODELOS = [("small", "vosk-model-small-es-0.42"), ("grande", "vosk-model-es-0.42")]
# 0,25 s, el mismo blocksize con el que el worker alimenta a Vosk (wake_vosk.py:1654).
# Importa: Vosk decide los cortes por bloques, con otro tamano el texto no es el mismo.
BLOQUE = 4000
# Por encima de esto se considera que el modelo no ha devuelto la RAM al soltarlo.
FUGA_MB = 300


# Copiadas de tools/medir-pila-oido.py y NO importadas de alli: aquel script carga los
# modelos nada mas importarlo, y aqui la gracia es tener uno solo dentro a la vez.
def libre_mb():
    """RAM libre de la maquina entera. Cuenta lo que hagan Nova y el resto: es el numero
    honesto de 'cuanto sitio quita', pero solo si no se toca nada mas mientras se mide."""
    import ctypes
    class MS(ctypes.Structure):
        _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
    m = MS(); m.dwLength = ctypes.sizeof(MS)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
    return m.ullAvailPhys / (1024.0 * 1024.0)


def rss_mb():
    """Lo que ocupa ESTE proceso. Es el dato que no miente aunque Nova este haciendo algo.

    OJO (19/09): la copia de tools/medir-pila-oido.py devuelve 0 en x64 y nunca se noto
    porque alli nadie la llama. Sin restype, GetCurrentProcess() vuelve como int de 32 bits
    y el pseudo-handle -1 llega partido: la llamada falla y WorkingSetSize se queda a 0.
    Con argtypes/restype declarados da 12,4 MB recien arrancado, que es lo esperable.
    """
    import ctypes
    class PMC(ctypes.Structure):
        _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong),
                    ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]
    k, ps = ctypes.windll.kernel32, ctypes.windll.psapi
    k.GetCurrentProcess.restype = ctypes.c_void_p
    ps.GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.POINTER(PMC), ctypes.c_ulong]
    ps.GetProcessMemoryInfo.restype = ctypes.c_int
    p = PMC(); p.cb = ctypes.sizeof(PMC)
    if not ps.GetProcessMemoryInfo(k.GetCurrentProcess(), ctypes.byref(p), p.cb):
        return 0.0
    return p.WorkingSetSize / (1024.0 * 1024.0)


def mb_en_disco(carpeta):
    t = 0
    for raiz, _, ficheros in os.walk(carpeta):
        for f in ficheros:
            try: t += os.path.getsize(os.path.join(raiz, f))
            except OSError: pass
    return t / (1024.0 * 1024.0)


# --- lo que usa el worker, sacado de wake_vosk.py con ast y sin ejecutarlo ---
# Mismo truco que pruebas/pipeline-hoy.py: copiar los valores los desincroniza.
_ns = {"json": json}
for _nodo in ast.parse(io.open(os.path.join(REPO, "wake_vosk.py"), encoding="utf-8").read()).body:
    if isinstance(_nodo, ast.Assign) and len(_nodo.targets) == 1 \
            and isinstance(_nodo.targets[0], ast.Name) and _nodo.targets[0].id in ("TASA", "GRAMATICA_SI_NO"):
        try: exec(compile(ast.Module(body=[_nodo], type_ignores=[]), "<w>", "exec"), _ns)
        except Exception: pass
TASA = _ns.get("TASA", 16000)
GRAM = _ns.get("GRAMATICA_SI_NO", json.dumps(["si", "no", "[unk]"], ensure_ascii=False))
if "TASA" not in _ns or "GRAMATICA_SI_NO" not in _ns:
    print("OJO: no pude sacar TASA/GRAMATICA_SI_NO de wake_vosk.py; voy con los valores de reserva")


def leer(ruta):
    with wave.open(ruta, "rb") as w:
        n, sr, ch, sw = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) if sw == 2 else \
        (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128) * 256
    if ch > 1: x = x.reshape(-1, ch).mean(axis=1)
    if sr != TASA:
        idx = np.linspace(0, len(x) - 1, int(len(x) * TASA / sr)).astype(np.int64); x = x[idx]
    return x.astype(np.int16)


def cargar():
    if os.path.exists(SAL):
        try: return json.load(io.open(SAL, encoding="utf-8"))
        except Exception: print("OJO: %s ilegible, empiezo de cero" % SAL)
    return {"clips": {}, "modelos": {}}


def guardar(d):
    json.dump(d, io.open(SAL, "w", encoding="utf-8"), ensure_ascii=False, indent=0)


def grafo_dinamico(ruta):
    """Vosk solo admite gramaticas (vocabulario cerrado en caliente) con el grafo
    dinamico: graph/HCLr.fst + graph/Gr.fst. El grande trae graph/HCLG.fst, que es fijo."""
    g = os.path.join(ruta, "graph")
    return os.path.exists(os.path.join(g, "HCLr.fst")) and os.path.exists(os.path.join(g, "Gr.fst"))


def oir_con(etiq, carpeta, datos):
    ruta = os.path.join(REPO, "vosk", carpeta)
    assert os.path.isdir(ruta), "falta el modelo: %s" % ruta
    wavs = sorted(x for x in os.listdir(USO) if x.lower().endswith(".wav"))
    assert wavs, "no hay grabaciones en %s" % USO
    pendientes = [w for w in wavs if etiq not in datos["clips"].get(w, {})]
    print()
    print("== %s (%s): %d clips, %d por oir, %.0f MB en disco"
          % (etiq, carpeta, len(wavs), len(pendientes), mb_en_disco(ruta)))
    if not pendientes:
        print("   ya estaba medido; no cargo nada")
        return
    from vosk import Model, KaldiRecognizer, SetLogLevel
    SetLogLevel(-1)
    gc.collect()
    libre0, rss0 = libre_mb(), rss_mb()
    t0 = time.time()
    modelo = Model(ruta)
    carga = time.time() - t0
    libre1, rss1 = libre_mb(), rss_mb()
    print("   cargado en %.1f s; cuesta %.0f MB de RAM (proceso %.0f -> %.0f, libres %.0f -> %.0f)"
          % (carga, rss1 - rss0, rss0, rss1, libre0, libre1))
    audio_s = proc_s = 0.0
    rss_pico = rss1
    texto = ""
    for i, w in enumerate(pendientes, 1):
        try:
            a = leer(os.path.join(USO, w))
            # Un reconocedor NUEVO por clip, sin gramatica y con SetWords(False): es
            # exactamente reconocedor_libre() (wake_vosk.py:844), el que escribe los
            # parciales en pantalla mientras dictas.
            rec = KaldiRecognizer(modelo, TASA)
            rec.SetWords(False)
            crudo = a.tobytes()
            trozos = []
            t1 = time.time()
            for j in range(0, len(crudo), BLOQUE * 2):
                if rec.AcceptWaveform(crudo[j:j + BLOQUE * 2]):
                    t = json.loads(rec.Result()).get("text", "")
                    if t: trozos.append(t)
            t = json.loads(rec.FinalResult()).get("text", "")
            if t: trozos.append(t)
            dt = time.time() - t1
            del rec
            texto = " ".join(trozos).strip()
            datos["clips"].setdefault(w, {})[etiq] = {"texto": texto, "s": round(dt, 2)}
            datos["clips"][w]["dur"] = round(len(a) / float(TASA), 2)
            audio_s += len(a) / float(TASA)
            proc_s += dt
        except Exception as e:
            datos["clips"].setdefault(w, {})[etiq] = {"error": str(e)[:160]}
            print("   %s: %s" % (w, str(e)[:120]))
        rss_pico = max(rss_pico, rss_mb())
        if i % 25 == 0:
            guardar(datos)
            print("   %d/%d  ultimo: %r" % (i, len(pendientes), texto[:52]), flush=True)
    # Esta fila describe la TANDA que se acaba de oir, no el historico: si se para y se
    # repite, los totales son los del ultimo trozo. El RTF y los s/clip siguen valiendo,
    # que son cocientes de la misma tanda.
    datos["modelos"][etiq] = {
        "carpeta": carpeta, "disco_mb": round(mb_en_disco(ruta)), "carga_s": round(carga, 1),
        "ram_mb": round(rss1 - rss0), "ram_libre_mb": round(libre0 - libre1),
        "rss_pico_mb": round(rss_pico), "audio_s": round(audio_s, 1), "proceso_s": round(proc_s, 1),
        "clips": len(pendientes), "grafo_dinamico": grafo_dinamico(ruta),
    }
    guardar(datos)
    print("   %d clips: %.1f s de proceso para %.1f s de audio (RTF %.2f, %.2f s por clip)"
          % (len(pendientes), proc_s, audio_s, (proc_s / audio_s) if audio_s else 0,
             proc_s / max(1, len(pendientes))))
    # Soltarlo de verdad: Model.__del__ llama a vosk_model_free, pero solo cuando se va la
    # ultima referencia. Se comprueba, que es el motivo de medir uno cada vez.
    del modelo
    gc.collect()
    time.sleep(1.0)
    libre2 = libre_mb()
    print("   soltado: proceso %.0f MB, libres %.0f MB (antes de cargar, %.0f)"
          % (rss_mb(), libre2, libre0))
    if (libre0 - libre2) > FUGA_MB:
        print("   OJO: no ha devuelto la RAM, siguen fuera %.0f MB" % (libre0 - libre2))


def probar_gramatica_grande():
    """Los tres papeles finos de Vosk (nombre, si/no, corte) van con gramatica cerrada.
    El grande trae graph/HCLG.fst y NO trae Gr.fst/HCLr.fst, y dentro de libvosk.dll esta
    el mensaje 'Runtime graphs are not supported by this model' (visto el 19/09 leyendo las
    cadenas de la dll). Esto lo confirma en vivo en vez de fiarse de la teoria.

    Va en OTRO proceso y el ULTIMO, con los resultados ya guardados: si libvosk se cae al
    pedirle una gramatica a un grafo fijo, que se caiga solo el y no se lleve la medicion.
    """
    ruta = os.path.join(REPO, "vosk", MODELOS[1][1])
    print()
    print("== gramatica cerrada con el grande (la palabra de activacion, el si/no y el corte)")
    print("   grafo dinamico (HCLr.fst + Gr.fst): small=%s grande=%s"
          % (grafo_dinamico(os.path.join(REPO, "vosk", MODELOS[0][1])), grafo_dinamico(ruta)))
    guion = (
        "import json, sys\n"
        "from vosk import Model, KaldiRecognizer, SetLogLevel\n"
        "SetLogLevel(-1)\n"
        "m = Model(sys.argv[1])\n"
        "r = KaldiRecognizer(m, 16000, sys.argv[2])\n"
        "r.AcceptWaveform(b'\\x00' * 32000)\n"
        "print('RESULTADO ' + json.dumps(json.loads(r.FinalResult()), ensure_ascii=False))\n"
    )
    try:
        r = subprocess.run([sys.executable, "-c", guion, ruta, GRAM], capture_output=True, timeout=900)
        sal = ((r.stdout or b"") + b"\n" + (r.stderr or b"")).decode("utf-8", "replace").strip()
        print("   codigo de salida: %s" % r.returncode)
        for l in sal.splitlines()[:12]:
            print("   | %s" % l[:160])
        if r.returncode != 0 or "RESULTADO" not in sal:
            print("   -> el grande NO acepta gramatica: no puede hacer de nombre, si/no ni corte")
        else:
            print("   -> acepta la llamada; mira arriba si libvosk avisa de 'Runtime graphs'")
    except Exception as e:
        print("   no se pudo probar: %s" % str(e)[:160])


def reconoce(frases, etiq):
    """Cuantas de esas frases resuelve Nova en local, sin IA.

    Cada motor en su PROPIA llamada al probador, como en pruebas/exp-hoy.py: el probador
    devuelve un mapa texto -> OK, y si se mezclan dos motores que oyeron lo mismo las
    claves colisionan y el recuento miente.
    """
    utiles = sorted({f.strip() for f in frases if f and f.strip()})
    if not utiles:
        return {}
    tmp = os.path.join(tempfile.gettempdir(), "vosk-%s-%d.txt" % (etiq, os.getpid()))
    with io.open(tmp, "w", encoding="utf-8", newline="\n") as f:
        for x in utiles:
            f.write(x.replace("\n", " ") + "\n")
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        os.path.join(REPO, "assistant.ps1"), "-Probar", tmp],
                       capture_output=True, cwd=REPO, timeout=3600)
    out = {}
    for linea in (r.stdout or b"").decode("utf-8", "replace").splitlines():
        t = linea.strip()
        if t.startswith("OK "): out[t[3:].strip().split("  ->")[0].strip()] = True
        elif t.startswith("->IA"): out[t[4:].strip()] = False
    try: os.remove(tmp)
    except Exception: pass
    return out


def papeles(datos):
    din = {e: (datos.get("modelos", {}).get(e, {}) or {}).get("grafo_dinamico") for e, _ in MODELOS}
    if din.get("grande") is None:
        din["grande"] = grafo_dinamico(os.path.join(REPO, "vosk", MODELOS[1][1]))
    puede = "SI" if din.get("grande") else "NO"
    print()
    print("PARA QUE SE USA VOSK HOY (wake_vosk.py) Y SI EL GRANDE PODRIA HACERLO:")
    print("  1. palabra de activacion 'nova'   gramatica cerrada  :839   grande: %s" % puede)
    print("  2. si/no de las confirmaciones    gramatica cerrada  :852   grande: %s" % puede)
    print("  3. corte mientras Nova habla      gramatica cerrada  :1182  grande: %s" % puede)
    print("  4. parciales en pantalla y el 'hay algo' que cierra el dictado por silencio")
    print("     (reconocedor_libre :846, se usa :1949-1970)                grande: SI, si el RTF aguanta")
    print("  5. ultimo recurso: el texto de Vosk solo se entrega si Parakeet Y Whisper se")
    print("     quedan en blanco (:1978-2021)                              grande: SI")
    if not din.get("grande"):
        print("  Los tres primeros los descarta el propio modelo: el grande trae graph/HCLG.fst")
        print("  (grafo fijo) y no HCLr.fst+Gr.fst, y sin grafo dinamico Vosk no admite gramatica.")
    print("  Del 4 y el 5 depende todo: el texto que se ENTREGA no es de Vosk desde el 18/09,")
    print("  lo pone Parakeet y lo repasa Whisper. Un Vosk mejor solo pinta los parciales")
    print("  mas bonitos y rescata los casos en que los otros dos se callan.")


def acciones(datos):
    clips = sorted(datos.get("clips", {}))
    assert clips, "no hay nada medido todavia; lanza primero 'small' y 'grande'"
    cols = []
    for etiq, _ in MODELOS:
        cols.append(("Vosk " + etiq, {w: (datos["clips"][w].get(etiq) or {}).get("texto", "") for w in clips}))
    # Referencias, para saber si el grande cambia algo de verdad.
    reg = {}
    rj = os.path.join(USO, "registro.jsonl")
    if os.path.exists(rj):
        for l in io.open(rj, encoding="utf-8"):
            if not l.strip(): continue
            try: d = json.loads(l)
            except Exception: continue
            if d.get("id"): reg[d["id"] + ".wav"] = d
        cols.append(("Nova ese dia (entregado)", {w: (reg.get(w) or {}).get("entregado", "") for w in clips}))
    ph = os.path.join(REPO, "pruebas", "pipeline-hoy.json")
    if os.path.exists(ph):
        try:
            h = json.load(io.open(ph, encoding="utf-8"))
            cols.append(("pipeline de hoy", {w: (h.get(w) or {}).get("entregado", "") for w in clips}))
        except Exception as e:
            print("OJO: pipeline-hoy.json ilegible (%s)" % str(e)[:80])
    else:
        print("(sin pruebas/pipeline-hoy.json: lanza antes pruebas\\pipeline-hoy.py y repite")
        print(" esta fase para comparar tambien contra Parakeet+Whisper)")

    res = {}
    for nombre, txt in cols:
        mapa = reconoce(txt.values(), nombre.split()[-1].strip("()"))
        res[nombre] = {w: bool(mapa.get((txt[w] or "").strip(), False)) for w in clips}

    n = len(clips)
    print()
    print("%-26s %6s %7s %10s %8s %7s %8s" % ("", "clips", "texto", "resuelven", "%", "s/clip", "RAM MB"))
    for nombre, txt in cols:
        etiq = nombre.replace("Vosk ", "")
        m = datos.get("modelos", {}).get(etiq, {})
        con = sum(1 for w in clips if (txt[w] or "").strip())
        ok = sum(1 for w in clips if res[nombre][w])
        seg = (m.get("proceso_s", 0) / m["clips"]) if m.get("clips") else 0
        print("%-26s %6d %7d %10d %7.1f%% %7s %8s"
              % (nombre, n, con, ok, 100.0 * ok / n,
                 ("%.2f" % seg) if seg else "-", m.get("ram_mb", "-")))

    ms, mg = datos.get("modelos", {}).get("small", {}), datos.get("modelos", {}).get("grande", {})
    rtf = (mg.get("proceso_s", 0) / mg["audio_s"]) if mg.get("audio_s") else 0
    rtfs = (ms.get("proceso_s", 0) / ms["audio_s"]) if ms.get("audio_s") else 0
    print()
    print("RTF (segundos de CPU por segundo de audio): small %.2f, grande %.2f" % (rtfs, rtf))
    print("disco: small %s MB, grande %s MB" % (ms.get("disco_mb", "?"), mg.get("disco_mb", "?")))

    # Que cambia clip a clip, que es lo que de verdad se mira.
    sm = {w: (datos["clips"][w].get("small") or {}).get("texto", "") for w in clips}
    gr = {w: (datos["clips"][w].get("grande") or {}).get("texto", "") for w in clips}
    gana = [w for w in clips if res.get("Vosk grande", {}).get(w) and not res.get("Vosk small", {}).get(w)]
    pierde = [w for w in clips if res.get("Vosk small", {}).get(w) and not res.get("Vosk grande", {}).get(w)]
    print()
    print("grande frente a small: gana %d, pierde %d" % (len(gana), len(pierde)))
    for w in gana[:12]:
        print("   + %s  small:%r  grande:%r" % (w[:15], sm[w][:34], gr[w][:34]))
    for w in pierde[:8]:
        print("   - %s  small:%r  grande:%r" % (w[:15], sm[w][:34], gr[w][:34]))

    # Control de que este banco reproduce al worker: el registro guarda lo que oyo el Vosk
    # small de aquel dia (campo 'vosk'). Si esto no se parece, el harness esta mal montado.
    if reg:
        comp = [w for w in clips if w in reg and reg[w].get("vosk") is not None and sm.get(w) is not None]
        igual = sum(1 for w in comp if (reg[w].get("vosk") or "").strip() == (sm[w] or "").strip())
        if comp:
            print()
            print("control: el small de aqui coincide con el 'vosk' que apunto el worker en %d de %d (%.0f%%)"
                  % (igual, len(comp), 100.0 * igual / len(comp)))
            print("   (si baja mucho, lo que falla es la medicion, no el modelo)")

    papeles(datos)

    hoy = res.get("pipeline de hoy")
    okg = sum(1 for w in clips if res.get("Vosk grande", {}).get(w))
    oks = sum(1 for w in clips if res.get("Vosk small", {}).get(w))
    okh = sum(1 for w in clips if hoy and hoy.get(w)) if hoy else None
    print()
    print("DECISION (la regla, escrita ANTES de ver los numeros):")
    print("  1. si el grande no le saca al small al menos 10 acciones (sobre %d clips)," % n)
    print("     borrar los 2,3 GB: no paga el sitio")
    print("  2. si el RTF del grande pasa de 0,50 no sirve para los parciales: el worker")
    print("     decodifica en el mismo bucle con el que escucha, y son 4 nucleos")
    print("  3. aunque gane al small, si no llega al pipeline de hoy no entra en el dictado")
    print()
    if okg - oks < 10:
        print("  -> 1 se cumple: gana %+d acciones. NO justifica 2,3 GB: borrar vosk\\%s" % (okg - oks, MODELOS[1][1]))
    elif rtf > 0.50:
        print("  -> 2 se cumple: gana %+d pero RTF %.2f. No vale para los parciales; como" % (okg - oks, rtf))
        print("     mucho, dictado de reserva, y ahi ya estan Parakeet y Whisper")
    elif okh is not None and okg < okh:
        print("  -> 3 se cumple: gana al small (%+d) pero queda a %d del pipeline de hoy." % (okg - oks, okh - okg))
        print("     Sirve para los parciales, no para lo que se entrega")
    else:
        print("  -> ninguna regla lo descarta: gana %+d con RTF %.2f. Cambiar el small por el" % (okg - oks, rtf))
        print("     grande SOLO en el reconocedor libre (wake_vosk.py:844); el nombre, el si/no")
        print("     y el corte se quedan con el small, que es el unico con gramatica")
    print()
    print("detalle en %s" % SAL)


if __name__ == "__main__":
    que = (sys.argv[1] if len(sys.argv) > 1 else "todo").lower()
    assert que in ("todo", "small", "grande", "acciones"), \
        "que mido? small | grande | acciones | todo (sin argumento, todo)"
    d = cargar()
    if que in ("todo", "small"):
        oir_con("small", MODELOS[0][1], d)
    if que in ("todo", "grande"):
        oir_con("grande", MODELOS[1][1], d)
        probar_gramatica_grande()
    if que in ("todo", "acciones"):
        acciones(d)
