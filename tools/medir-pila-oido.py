# -*- coding: utf-8 -*-
"""C23 (VRAM-2026-09-19.md:147-149): medir la PILA ENTERA cargada a la vez.
Nadie lo ha hecho: los ~2,5 GB del informe son una suma en papel."""
import gc, os, time, glob
import numpy as np

REPO = r"C:\Users\braya\Documents\voice-ctrl"

def libre_mb():
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
    import ctypes
    class PMC(ctypes.Structure):
        _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong),
                    ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                    ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                    ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                    ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]
    p = PMC(); p.cb = ctypes.sizeof(PMC)
    ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.windll.kernel32.GetCurrentProcess(), ctypes.byref(p), p.cb)
    return p.WorkingSetSize / (1024.0 * 1024.0)

print("%-30s %12s %12s %9s" % ("paso", "cuesta MB", "quedan MB", "tarda s"))
base_l = libre_mb()
prev = base_l
print("%-30s %12s %12.0f %9s" % ("(nada, con Nova encendida)", "-", base_l, "-"))

audio = np.zeros(16000 * 3, dtype=np.float32)
pasos = []

t = time.time()
import sherpa_onnx
carp = [c for c in glob.glob(os.path.join(REPO, "modelos", "*parakeet*")) if os.path.isdir(c)][0]
f = lambda p: sorted(glob.glob(os.path.join(carp, p)))[0]
par = sherpa_onnx.OfflineRecognizer.from_transducer(
    encoder=f("encoder*.onnx"), decoder=f("decoder*.onnx"), joiner=f("joiner*.onnx"),
    tokens=f("tokens.txt"), num_threads=8, decoding_method="greedy_search", model_type="nemo_transducer")
st = par.create_stream(); st.accept_waveform(16000, audio); par.decode_stream(st)
dt = time.time() - t
l = libre_mb(); pasos.append(("+ Parakeet", prev - l, l, dt)); prev = l
print("%-30s %12.0f %12.0f %9.1f" % pasos[-1])

from faster_whisper import WhisperModel
for nombre in ("base", "small"):
    t = time.time()
    m = WhisperModel(nombre, device="cpu", compute_type="int8", cpu_threads=8)
    list(m.transcribe(audio, language="es", beam_size=1)[0])
    dt = time.time() - t
    globals()["w_" + nombre] = m
    l = libre_mb(); pasos.append(("+ Whisper " + nombre, prev - l, l, dt)); prev = l
    print("%-30s %12.0f %12.0f %9.1f" % pasos[-1])

t = time.time()
from vosk import Model, KaldiRecognizer, SetLogLevel
SetLogLevel(-1)
vk = Model(os.path.join(REPO, "vosk", "vosk-model-small-es-0.42"))
rec = KaldiRecognizer(vk, 16000)
dt = time.time() - t
l = libre_mb(); pasos.append(("+ Vosk small", prev - l, l, dt)); prev = l
print("%-30s %12.0f %12.0f %9.1f" % pasos[-1])

print()
print("PILA COMPLETA del oido: %.0f MB" % (base_l - pasos[-1][2]))
print("libre: %.0f MB -> %.0f MB" % (base_l, pasos[-1][2]))
print()
print("El informe VRAM estimaba ~2.500 MB SUMANDO EN PAPEL. Medido el 19/09: 1.233 MB,")
print("la mitad. Los modelos comparten runtime (onnxruntime, ctranslate2) y no suman.")
