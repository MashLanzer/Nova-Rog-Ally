# -*- coding: utf-8 -*-
# C23: LA PILA DEL OIDO ENTERA, CARGADA A LA VEZ.
#
# Desde el 21/09 la cascada del repaso es parakeet -> canary -> omni -> whisper base, y esos
# escalones se piden uno detras de otro para la MISMA frase. Cada modelo se carga la primera
# vez que hace falta y se queda en memoria hasta que el oido lo suelta (PARAKEET_SOLTAR_JUGANDO).
# O sea que en el peor caso -una frase que baja los cuatro escalones mientras Nova esta en
# marcha- pueden estar los cuatro dentro a la vez.
#
# Eso NUNCA se habia medido, y es la diferencia entre una cascada que mejora el oido y una
# que deja la consola sin memoria en mitad de una partida. La consola son 11,70 GB visibles
# (medido el 19/09) y el juego se lleva lo suyo.
#
# Se mide de verdad: se cargan uno a uno, se transcribe un audio con cada uno para que el
# modelo se despliegue del todo (cargar no es usar), y se apunta la RAM del proceso despues
# de cada uno.
#
#   python tools/medir-pila-oido.py
import io
import os
import sys
import glob
import time
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def mb_proceso():
    """La RAM de ESTE proceso. Si no se puede leer devuelve -1, NUNCA 0: un cero aqui se lee
    como 'no ocupa nada' y es mentira. La primera version devolvia 0 al fallar y la tabla
    salio entera a ceros, que es peor que no tener la columna."""
    try:
        import ctypes
        from ctypes import wintypes

        class PMC(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                        ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                        ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]
        c = PMC()
        c.cb = ctypes.sizeof(c)
        # K32GetProcessMemoryInfo vive en kernel32 y no obliga a cargar psapi.dll aparte,
        # que es lo que fallaba en silencio.
        fn = getattr(ctypes.windll.kernel32, "K32GetProcessMemoryInfo", None)
        if fn is None:
            fn = ctypes.windll.psapi.GetProcessMemoryInfo
        if not fn(ctypes.windll.kernel32.GetCurrentProcess(), ctypes.byref(c), c.cb):
            return -1.0
        return c.WorkingSetSize / (1024.0 * 1024.0)
    except Exception:
        return -1.0


def mb_libres():
    try:
        import ctypes

        class MS(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                        ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                        ("ullTotalPageFile", ctypes.c_ulonglong), ("ullAvailPageFile", ctypes.c_ulonglong),
                        ("ullTotalVirtual", ctypes.c_ulonglong), ("ullAvailVirtual", ctypes.c_ulonglong),
                        ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
        m = MS()
        m.dwLength = ctypes.sizeof(m)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
        return m.ullAvailPhys / (1024.0 * 1024.0), m.ullTotalPhys / (1024.0 * 1024.0)
    except Exception:
        return -1.0, -1.0


def un_audio():
    for carpeta in ("cien", "dirigida", "validacion", "validacion2"):
        d = os.path.join(RAIZ, "pruebas", "audio", carpeta)
        w = sorted(glob.glob(os.path.join(d, "*.wav")))
        if w:
            return w[0]
    return None


def carga(cual):
    import sherpa_onnx

    def f(d, p):
        return sorted(glob.glob(os.path.join(d, p)))[0]

    if cual == "parakeet":
        d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*parakeet*")) if os.path.isdir(c)][0]
        return sherpa_onnx.OfflineRecognizer.from_transducer(
            encoder=f(d, "encoder*.onnx"), decoder=f(d, "decoder*.onnx"), joiner=f(d, "joiner*.onnx"),
            tokens=f(d, "tokens.txt"), num_threads=4, decoding_method="greedy_search",
            model_type="nemo_transducer")
    if cual == "canary":
        d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*canary*")) if os.path.isdir(c)][0]
        return sherpa_onnx.OfflineRecognizer.from_nemo_canary(
            encoder=f(d, "encoder*.onnx"), decoder=f(d, "decoder*.onnx"), tokens=f(d, "tokens.txt"),
            src_lang="es", tgt_lang="es", num_threads=4)
    if cual == "omni":
        d = [c for c in glob.glob(os.path.join(RAIZ, "modelos", "*omnilingual*")) if os.path.isdir(c)][0]
        return sherpa_onnx.OfflineRecognizer.from_omnilingual_asr_ctc(
            model=f(d, "model*.onnx"), tokens=f(d, "tokens.txt"), num_threads=4)
    raise ValueError(cual)


def main():
    import numpy as np
    wav = un_audio()
    if not wav:
        print("  no hay ni una grabacion en pruebas/audio")
        return 1
    with wave.open(wav, "rb") as x:
        audio = np.frombuffer(x.readframes(x.getnframes()), dtype=np.int16).astype("float32") / 32768.0
        tasa = x.getframerate()

    libres0, total = mb_libres()
    print("  la consola: %.0f MB en total, %.0f MB libres ahora mismo" % (total, libres0))
    print("  (con Nova en marcha, que es como pasa de verdad)")
    print("")
    print("  %-22s %10s %12s %12s" % ("tras cargar", "del proceso", "suma", "libres"))
    base = mb_proceso()
    hay = base >= 0
    def col(v):
        return ("%8.0f MB" % v) if hay else "       ?  "
    print("  %-22s %s %10s %10.0f MB" % ("nada (python solo)", col(base), "-", mb_libres()[0]))
    if not hay:
        print("  (la RAM del proceso no se puede leer aqui; lo que manda es la columna de libres)")

    vivos = []
    antes = base
    libresAnt = mb_libres()[0]
    for cual in ("parakeet", "canary", "omni"):
        t0 = time.time()
        try:
            rec = carga(cual)
        except Exception as e:   # noqa: BLE001
            print("  %-22s NO se pudo cargar: %s" % (cual, str(e)[:60]))
            continue
        # cargar no es usar: se transcribe para que el modelo se despliegue del todo
        s = rec.create_stream()
        s.accept_waveform(tasa, audio)
        rec.decode_stream(s)
        vivos.append(rec)
        ahora = mb_proceso()
        libresA = mb_libres()[0]
        print("  %-22s %s %+9.0f MB %10.0f MB   (%.1f s)"
              % ("+ " + cual, col(ahora), (ahora - antes) if hay else (libresAnt - libresA),
                 libresA, time.time() - t0))
        antes = ahora
        libresAnt = libresA

    # y whisper base, que es el ultimo escalon
    t0 = time.time()
    try:
        from faster_whisper import WhisperModel
        wm = WhisperModel("base", device="cpu", compute_type="int8", cpu_threads=4)
        list(wm.transcribe(audio, language="es", beam_size=1)[0])
        ahora = mb_proceso()
        libresA = mb_libres()[0]
        print("  %-22s %s %+9.0f MB %10.0f MB   (%.1f s)"
              % ("+ whisper base", col(ahora), (ahora - antes) if hay else (libresAnt - libresA),
                 libresA, time.time() - t0))
        antes = ahora
        libresAnt = libresA
    except Exception as e:   # noqa: BLE001
        print("  %-22s NO se pudo cargar: %s" % ("whisper base", str(e)[:60]))

    libres1 = mb_libres()[0]
    print("")
    if hay:
        print("  LA PILA ENTERA: %.0f MB del proceso, y quedan %.0f MB libres" % (antes, libres1))
    else:
        print("  LA PILA ENTERA: quedan %.0f MB libres" % libres1)
    print("  se ha comido %.0f MB de los %.0f que habia" % (libres0 - libres1, libres0))
    if libres1 < 1000:
        print("  OJO: menos de 1 GB libre con la pila cargada. Jugando, eso es poco.")
        return 1
    print("  cabe: queda mas de 1 GB libre con los cuatro dentro y Nova en marcha")
    return 0


if __name__ == "__main__":
    sys.exit(main())
