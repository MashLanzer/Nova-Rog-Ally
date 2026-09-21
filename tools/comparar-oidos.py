# -*- coding: utf-8 -*-
# COMPARA LOS OIDOS QUE HAYA MEDIDOS, y dice cual merece la pena y en que orden.
#
# Lo que se compara no es el texto: es si la orden ACABA HACIENDO LO MISMO que si braya
# hubiera sido entendido perfectamente. Un "abre estim" que abre Steam es un acierto.
#
# Y LA CASCADA SE EVALUA COMO CASCADA: cada escalon solo entra cuando el anterior no dejo
# una orden, que es como funciona de verdad. Sumar los aciertos de cada uno por separado
# daria un numero bonito y falso.
#
# Uso:   python tools/comparar-oidos.py            (usa todos los tmp/oido-*.json)
#        python tools/comparar-oidos.py parakeet canary base
import io
import os
import sys
import json
import glob
import re
import subprocess
import tempfile
import unicodedata

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return " ".join("".join(c if c.isalnum() or c.isspace() else " " for c in s).split())


def suena_ingles_fab():
    """Las listas de wake_vosk.py SIN importarlo: importarlo arranca el microfono."""
    src = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()

    def lista(n):
        m = re.search(n + r'\s*=\s*set\("""(.*?)"""\.split\(\)\)', src, re.S)
        return set(m.group(1).split()) if m else set()
    ES, EN = lista("PALABRAS_ES"), lista("PALABRAS_EN")

    def f(t):
        w = plano(t).split()
        return bool(w) and (not any(x in ES for x in w)) and any(x in EN for x in w)
    return f


def carga(cuales):
    d = {}
    for p in sorted(glob.glob(os.path.join(RAIZ, "tmp", "oido-*.json"))):
        c = os.path.basename(p)[len("oido-"):-len(".json")]
        if cuales and c not in cuales:
            continue
        try:
            j = json.load(io.open(p, encoding="utf-8"))
        except Exception:
            continue
        d[c] = j
    return d


def acciones(frases):
    tmp = os.path.join(tempfile.gettempdir(), "cmp-oidos.txt")
    io.open(tmp, "w", encoding="utf-8", newline="\n").write("\n".join(frases) + "\n")
    res = {}
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                        "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%s' -Probar '%s'"
                        % (os.path.join(RAIZ, "assistant.ps1"), tmp)],
                       capture_output=True, timeout=3600)
    for linea in r.stdout.decode("utf-8", "replace").splitlines():
        t = linea.strip()
        if t.startswith("OK") and "->" in t:
            izq, _, der = t[2:].strip().rpartition("->")
            res[plano(izq)] = plano(der)
        elif t.startswith("->IA"):
            res[plano(t[4:])] = "<ia>"
        elif t.startswith("SALTO"):
            res[plano(t[5:].split("(")[0])] = "<salto>"
    return res


def main():
    cuales = set(x.lower() for x in sys.argv[1:])
    d = carga(cuales)
    if not d:
        print("  no hay nada medido en tmp/oido-*.json")
        return 1
    # todos tienen que haber oido LAS MISMAS grabaciones, o no se comparan
    ns = set(x["n"] for x in d.values())
    if len(ns) > 1:
        print("  OJO: no todos midieron lo mismo (%s). Se comparan solo los que coincidan."
              % ", ".join("%s=%d" % (k, v["n"]) for k, v in d.items()))
        may = max(ns)
        d = {k: v for k, v in d.items() if v["n"] == may}
    n = list(d.values())[0]["n"]
    ref = list(d.values())[0]["items"]

    todas = set(plano(x["verdad"]) for x in ref)
    for v in d.values():
        todas.update(plano(x["salio"]) for x in v["items"] if x["salio"])
    print("  resolviendo %d frases con la capa local de hoy..." % len(todas), flush=True)
    acc = acciones(sorted(t for t in todas if t))

    def a(t):
        return acc.get(plano(t), "??")
    NO = ("<ia>", "<salto>", "??")
    idx = [i for i, x in enumerate(ref) if a(x["verdad"]) not in NO]
    ing = suena_ingles_fab()
    print("")
    print("  %d de %d grabaciones son ordenes que la capa local sabe resolver" % (len(idx), n))
    print("")
    print("  %-14s %-16s %-12s %-10s %s" % ("OIDO", "ordenes bien", "ms/audio", "vacias", "otro idioma"))
    fila = []
    for c, v in sorted(d.items(), key=lambda kv: -sum(1 for i in idx if a(kv[1]["items"][i]["salio"]) == a(ref[i]["verdad"]))):
        it = v["items"]
        bien = sum(1 for i in idx if a(it[i]["salio"]) == a(ref[i]["verdad"]))
        vac = sum(1 for x in it if not (x["salio"] or "").strip())
        eng = sum(1 for x in it if x["salio"] and ing(x["salio"]))
        ms = 1000.0 * v["seg"] / v["n"]
        fila.append((c, bien, ms))
        print("  %-14s %3d/%-11d %7.0f      %4d      %4d" % (c, bien, len(idx), ms, vac, eng))

    # LA CASCADA: cada uno solo entra donde el anterior no dejo orden
    print("")
    print("  == LA CASCADA, que es como funciona de verdad ==")
    print("  (cada escalon solo entra donde el anterior no dejo una orden)")
    orden = [c for c, _, _ in fila]
    if "parakeet" in orden:
        orden.remove("parakeet")
        orden.insert(0, "parakeet")   # Parakeet es el primero por diseno, no se discute
    acum = []
    for c in orden:
        acum.append(c)
        bien = 0
        veces = {}
        for i in idx:
            for k in acum:
                r = a(d[k]["items"][i]["salio"])
                if r not in NO:
                    veces[k] = veces.get(k, 0) + 1
                    if r == a(ref[i]["verdad"]):
                        bien += 1
                    break
        extra = sum(veces.get(k, 0) for k in acum[1:])
        print("  %-42s %3d/%d  (%.1f %%)%s" % (" + ".join(acum), bien, len(idx),
              100.0 * bien / len(idx),
              ("   se le pregunta a los de atras %d veces" % extra) if len(acum) > 1 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
