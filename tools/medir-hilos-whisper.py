# -*- coding: utf-8 -*-
"""Cuantos hilos le convienen a Whisper en este chip, medido y no supuesto.

POR QUE (20/09). HILOS_PRECISO esta en 8 desde el 14/09, cuando se midio que "base pasa
de 2,0 a 1,7 s por orden con los mismos aciertos". Pero el Z2 A tiene **4 nucleos
fisicos** y 8 hilos logicos: en SMT, dos hilos por nucleo se pelean por la misma unidad
de coma flotante, y en cargas como esta 8 puede ser igual o PEOR que 4, ademas de
calentar mas. Nadie lo ha vuelto a medir desde entonces, y el oido fino (small) va hoy a
4,16 s de mediana y 8,48 s en el p90 sobre el uso real: si se le pueden quitar segundos
gratis, se le quitan.

QUE MIDE: el modelo que use de verdad el oido fino (config.json -> whisperModeloPreciso)
sobre grabaciones REALES de uso, con cada numero de hilos, y varias vueltas para que una
racha mala no decida. No mide aciertos a proposito: el texto que saca Whisper con 4 o con
8 hilos es el mismo, lo unico que cambia es lo que tarda.

OJO AL MEDIR: cierra Nova antes, o estaras midiendo con el worker comiendo CPU al lado.
Y MIRA QUE NO HAYA UN JUEGO ABIERTO, que es como se perdieron las dos primeras medidas
del 20/09: It Takes Two llevaba cuatro horas abierto comiendose 2,3 de los 4 nucleos, y
la dispersion del 26-50 %% que salia se achaco al calor. Dos segundos de
"Get-Process | Sort WorkingSet" lo habrian visto antes de empezar.

    python tools\\medir-hilos-whisper.py [--vueltas 3] [--audios 8]
"""
import argparse
import glob
import io
import json
import os
import statistics
import time
import wave

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USO = os.path.join(RAIZ, "pruebas", "audio", "uso")


def cfg(*camino):
    try:
        with io.open(os.path.join(RAIZ, "config.json"), encoding="utf-8-sig") as f:
            d = json.load(f)
        for c in camino:
            d = d.get(c)
            if d is None:
                return None
        return d
    except Exception:
        return None


def lee(ruta):
    with wave.open(ruta, "rb") as w:
        datos = w.readframes(w.getnframes())
        tasa = w.getframerate()
    a = np.frombuffer(datos, dtype=np.int16).astype(np.float32) / 32768.0
    return a, (a.size / float(tasa))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vueltas", type=int, default=5)
    ap.add_argument("--audios", type=int, default=8)
    ap.add_argument("--solo", type=str, default="", help="solo estos hilos, p.ej. 4,8")
    args = ap.parse_args()

    modelo = cfg("input", "whisperModeloPreciso") or "small"
    print("modelo del oido fino: %s" % modelo)

    # los audios mas largos del uso real, que son los que de verdad cuestan
    wavs = []
    for w in sorted(glob.glob(os.path.join(USO, "*.wav"))):
        try:
            a, seg = lee(w)
        except Exception:
            continue
        if 2.0 <= seg <= 12.0:
            wavs.append((w, a, seg))
    wavs.sort(key=lambda x: -x[2])
    wavs = wavs[:args.audios]
    if not wavs:
        raise SystemExit("no hay grabaciones de uso en %s" % USO)
    total_seg = sum(s for _, _, s in wavs)
    print("%d grabaciones, %.1f s de audio en total" % (len(wavs), total_seg))
    print("")

    from faster_whisper import WhisperModel

    hilos_probar = [int(x) for x in args.solo.split(",") if x.strip()] or [2, 4, 6, 8]

    # SE ALTERNA EL ORDEN A PROPOSITO (20/09). Dos medidas seguidas dieron una dispersion
    # del 26-50 %, y la explicacion que cuadra es el CALOR: este aparato son 15-20 W, y
    # veinte minutos de CPU al maximo lo hacen bajar de frecuencia. Medir "primero todas
    # las vueltas de 4, luego todas las de 8" reparte ese castigo de forma desigual, y de
    # paso penaliza mas a la configuracion que mas calienta, que es justo la que se esta
    # juzgando. Alternando 4,8,4,8... las dos comen el mismo calor.
    modelos = {}
    for h in hilos_probar:
        t0 = time.time()
        modelos[h] = (WhisperModel(modelo, device="cpu", compute_type="int8", cpu_threads=h), time.time() - t0)
        modelos[h][0].transcribe(wavs[0][1], language="es", beam_size=1)   # calentamiento
    por_hilos = {h: [] for h in hilos_probar}
    for v in range(args.vueltas):
        for h in hilos_probar:
            m = modelos[h][0]
            t = time.time()
            for _, a, _s in wavs:
                seg, _info = m.transcribe(a, language="es", beam_size=1)
                for _x in seg:
                    pass
            por_hilos[h].append(time.time() - t)

    res = {}
    for hilos in hilos_probar:
        tiempos = por_hilos[hilos]
        carga = modelos[hilos][1]
        med = statistics.median(tiempos)
        res[hilos] = (med, min(tiempos), max(tiempos), carga)
        disp = (max(tiempos) - min(tiempos)) / med if med else 0.0
        print("  %d hilos: mediana %.2f s  (mejor %.2f, peor %.2f)  dispersion %.0f %%  RTF %.3f%s"
              % (hilos, med, min(tiempos), max(tiempos), 100.0 * disp, med / total_seg,
                 "   <- RUIDOSA" if disp > 0.25 else ""))

    print("")
    # SE DECIDE POR LA MEDIANA, NO POR EL MEJOR TIEMPO (20/09). La primera version cogia
    # el minimo y dio "6 hilos, 47,8 s"... con una mediana de 82,0 s, peor que la de 4
    # hilos (69,2). El minimo premia al que tuvo un hueco de suerte, y en una maquina de
    # 4 nucleos donde algo mas puede arrancar en cualquier momento, eso no es el numero
    # que hay que mirar.
    mejor = min(res, key=lambda h: res[h][0])
    ahora = 8
    ruidosas = [h for h in res if (res[h][2] - res[h][1]) / res[h][0] > 0.25]
    if ruidosas:
        print("  OJO: %s tienen mas de un 25 %% entre su mejor y su peor vuelta." % (", ".join("%d hilos" % h for h in sorted(ruidosas))))
        print("  Habia algo mas usando la CPU. Cierra todo y repite antes de cambiar nada.")
        print("")
    print("  el mas rapido por mediana: %d hilos (%.2f s)" % (mejor, res[mejor][0]))
    if ahora in res:
        dif = res[ahora][0] - res[mejor][0]
        pct = 100.0 * dif / res[ahora][0] if res[ahora][0] else 0.0
        if mejor != ahora and pct >= 5.0:
            print("  HILOS_PRECISO esta en %d: bajarlo a %d ahorraria %.2f s por tanda (%.0f %%)"
                  % (ahora, mejor, dif, pct))
            print("  sobre el uso real eso es ~%.2f s por orden del oido fino"
                  % (dif / max(1, len(wavs))))
        else:
            print("  HILOS_PRECISO = %d se queda: la diferencia con el mejor es %.2f s (%.0f %%),"
                  % (ahora, dif, pct))
            print("  por debajo del 5 % que justificaria tocarlo.")


if __name__ == "__main__":
    main()
