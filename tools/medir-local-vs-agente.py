# -*- coding: utf-8 -*-
"""Cuanto resuelve Nova sola y cuanto acaba esperando al agente.

    python tools\\medir-local-vs-agente.py              todo el log
    python tools\\medir-local-vs-agente.py 2026-09-18   solo ese dia

POR QUE EXISTE (19/09). PENDIENTE.md:1507 y NOVA-LLM.md:208 piden lo mismo desde el
16/09: "medir en uso real cuantas tareas resuelve el plan y cuantas siguen yendo al
agente". El unico numero que se citaba era del 15/09 y estaba contado A MANO: 20
llamadas al agente, 11,6 min, el 23 % de toda la espera. Contar a mano no se repite cada
dia, y desde entonces el plan (16/09) y la linea TRABAJO (18/09) han cambiado el reparto
sin que nadie lo vuelva a medir. tools\\analizar-uso.py no vale para esto: mete 'accion'
y 'plan' en el saco NEUTRO a proposito (para no hundir el % de aciertos) y no mira
tiempos.

DE DONDE SALEN LOS DATOS. Solo se LEE assistant.log y memoria\\estadisticas.json. No
arranca nada ni carga ningun modelo: se puede ejecutar con Nova encendida.

  camino LOCAL      'LOCAL: <frase> -> <lo que hizo>'   (Process-Texto, assistant.ps1)
                    'LOCAL (desde la charla): ...'      (una orden dicha dentro de charla)
  camino PLAN       "PLAN: '<frase>' -> a | b"          = resuelto con ordenes propias
                    'PLAN: no sale con ordenes...'      = se rindio, va al agente
                    "PLAN: '<x>' pide confirmacion"     = a medias, el resto al agente
  camino AGENTE     'SUBMIT (accion): <frase>'          = la unica puerta al agente

  LO QUE TARDA      'TRABAJO modo=X motor=Y ... seg=N'  (existe desde el 18/09 18:45)
                    antes de esa fecha la linea no existia, asi que se empareja
                    'SUBMIT (<modo>)' con el 'RUNNER exit=' siguiente: solo hay UN
                    trabajo vivo a la vez ($script:busy en assistant.ps1), asi que el
                    emparejado es exacto, con resolucion de 1 s. El motor se deduce de
                    'CEREBRO (...): claude-code' o de 'RUNNER cmd: run --auto'
                    (opencode); si no aparece ninguno de los dos, es la API.

COMPROBACION DEL METODO: sobre el 15/09 este script saca 20 llamadas al agente y 11,6
min, que es exactamente el numero que se conto a mano ese dia. Si algun dia deja de
cuadrar, es que ha cambiado el log, no la realidad.

OJO AL LEER: 'traducir' y 'plan' TAMBIEN son llamadas al modelo y tambien se esperan,
aunque no sean el agente. Van en su propia fila porque cuestan 2-5 s por la API y el
agente 20-90: meter las 70 traducciones del 18/09 en el mismo saco que las 5 tareas
taparia justo lo que se quiere ver.
"""
import collections
import io
import json
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOG = os.path.join(RAIZ, "assistant.log")
ESTADISTICAS = os.path.join(RAIZ, "memoria", "estadisticas.json")

# 'YYYY-MM-DD HH:MM:SS  mensaje'. El log empieza con BOM: se lee con utf-8-sig.
LINEA = re.compile(r"^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})\s\s(.*)$")
RE_TRABAJO = re.compile(
    r"^TRABAJO modo=(\S+) motor=(\S+) prompt=(\d+)c seg=([\d.]+) pasos=(\d+)")
RE_SUBMIT = re.compile(r"^SUBMIT \(([a-z]+)\): (.*)$")
RE_CEREBRO = re.compile(r"^CEREBRO \(([a-z]+)\): claude-code")


def seg(hhmmss):
    """de HH:MM:SS a segundos, para emparejar SUBMIT con RUNNER sin linea TRABAJO"""
    h, m, s = hhmmss.split(":")
    return int(h) * 3600 + int(m) * 60 + int(s)


def mediana(v):
    v = sorted(v)
    n = len(v)
    if not n:
        return 0.0
    return v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2.0


def pct(a, b):
    return "%5.1f %%" % (100.0 * a / b) if b else "    -  "


def leer_log(dia):
    """Devuelve (contadores por dia, trabajos, perdidos). Un trabajo = una llamada."""
    dias = collections.OrderedDict()
    trabajos = []
    perdidos = collections.Counter()
    abierto = None      # el SUBMIT vivo: {'dia','seg','modo','texto','motor','fin'}

    def cerrar(pendiente):
        """se apunta el emparejado SUBMIT+RUNNER solo si no llego una linea TRABAJO"""
        if pendiente and pendiente.get("fin") is not None:
            # a medianoche el reloj vuelve a 0 y la resta saldria negativa
            dur = pendiente["fin"] - pendiente["seg"]
            if dur < 0:
                dur += 86400
            trabajos.append({"dia": pendiente["dia"], "modo": pendiente["modo"],
                             "motor": pendiente["motor"] or "api",
                             "seg": float(dur), "pasos": 0,
                             "texto": pendiente["texto"], "fuente": "SUBMIT+RUNNER"})
        elif pendiente:
            # se fue a mitad: reinicio de Nova, cancelacion o plazo agotado. No es un
            # tiempo medible, pero SI es una espera que braya pago: se cuenta aparte.
            perdidos[pendiente["modo"]] += 1

    if not os.path.exists(LOG):
        return dias, trabajos, perdidos
    for linea in io.open(LOG, encoding="utf-8-sig", errors="replace"):
        m = LINEA.match(linea.rstrip("\r\n"))
        if not m:
            continue
        d, hora, msg = m.group(1), m.group(2), m.group(3)
        if dia and d != dia:
            continue
        c = dias.setdefault(d, collections.Counter())

        # --- lo que resolvio ella sola, sin modelo ninguno ---
        # OJO: "LOCAL: hago las ordenes y '<x>' va a la conversacion" NO se cuenta.
        # Es el preambulo del atajo charla+orden y va seguido de su propia linea
        # "LOCAL: <frase> -> <hizo>": contarlo doblaba esas ordenes.
        if msg.startswith("LOCAL: ") and " -> " in msg:
            c["local"] += 1
        elif msg.startswith("LOCAL (desde la charla): "):
            c["local"] += 1
        elif msg.startswith("LOCAL descarta: no reconozco "):
            c["local-no"] += 1

        # --- el plan: la API propone ordenes del vocabulario, no ejecuta nada ---
        elif msg.startswith("PLAN: no sale con ordenes"):
            c["plan-no"] += 1
        elif msg.startswith("PLAN: '") and " -> " in msg:
            c["plan-sirvio"] += 1
        elif msg.startswith("PLAN: '") and ("pide confirmacion" in msg or "no se pudo hacer" in msg):
            c["plan-a-medias"] += 1

        # --- la unica puerta al agente ---
        mm = RE_SUBMIT.match(msg)
        if mm:
            cerrar(abierto)
            c["submit-" + mm.group(1)] += 1
            abierto = {"dia": d, "seg": seg(hora), "modo": mm.group(1),
                       "texto": mm.group(2), "motor": "", "fin": None}
            continue
        if msg.startswith("VoiceAssistant iniciado"):
            cerrar(abierto)     # lo que estuviera en marcha murio con el proceso
            abierto = None
            continue

        if abierto is not None:
            if RE_CEREBRO.match(msg):
                abierto["motor"] = "claude-code"
                continue
            if msg.startswith("RUNNER cmd: run --auto"):
                abierto["motor"] = "opencode"
                continue
            if msg.startswith("RUNNER exit=") and abierto.get("fin") is None:
                # se anota la hora pero NO se cierra: la linea TRABAJO viene justo
                # detras (18/09+) y trae el tiempo bueno, con decimas.
                # SOLO EL PRIMERO. Sin el "is None", un 'RUNNER exit' posterior -otro
                # trabajo que arranco sin pasar por SUBMIT- pisaba la hora y el trabajo
                # salia larguisimo: el 11/09 19:36 una traduccion de 18 s aparecia como
                # 636 s y se llevaba ella sola el 13 % de toda la espera medida.
                abierto["fin"] = seg(hora)
                continue

        mt = RE_TRABAJO.match(msg)
        if mt:
            trabajos.append({"dia": d, "modo": mt.group(1), "motor": mt.group(2),
                             "seg": float(mt.group(4)), "pasos": int(mt.group(5)),
                             "texto": (abierto or {}).get("texto", ""),
                             "fuente": "TRABAJO"})
            abierto = None
            continue
    cerrar(abierto)
    return dias, trabajos, perdidos


def leer_estadisticas(dia):
    if not os.path.exists(ESTADISTICAS):
        return {}
    try:
        d = json.load(io.open(ESTADISTICAS, encoding="utf-8-sig"))
    except Exception:
        return {}
    dias = d.get("dias") or {}
    return {dia: dias.get(dia, {})} if dia else dias


def main():
    dia = sys.argv[1] if len(sys.argv) > 1 else ""
    dias, trabajos, perdidos = leer_log(dia)
    if not dias:
        print("No hay nada que medir en %s%s" % (LOG, (" para " + dia) if dia else ""))
        return

    tot = collections.Counter()
    for c in dias.values():
        tot.update(c)
    local = tot["local"]
    planOk = max(0, tot["plan-sirvio"] - tot["plan-a-medias"])   # el que se hizo ENTERO
    agente = tot["submit-accion"]
    todas = local + planOk + agente

    print("=" * 76)
    print("QUIEN RESOLVIO LAS ORDENES%s" % ((" el " + dia) if dia else ""))
    print("=" * 76)
    print("  la capa LOCAL, sin modelo ninguno:  %4d  %s" % (local, pct(local, todas)))
    print("  el PLAN (la API propone, ejecuta    %4d  %s" % (planOk, pct(planOk, todas)))
    print("     Nova con ordenes suyas)")
    if tot["plan-a-medias"]:
        print("     ...y %d se quedaron a medias: el resto fue al agente" % tot["plan-a-medias"])
    print("  al AGENTE (claude-code / opencode): %4d  %s" % (agente, pct(agente, todas)))
    print("  ---")
    print("  ordenes con destino: %d" % todas)
    if tot["plan-no"] or tot["plan-sirvio"]:
        intentos = tot["plan-no"] + tot["plan-sirvio"]
        print("")
        print("  EL PLAN, cuando se le pregunto: %d de %d salieron con ordenes propias (%s)"
              % (tot["plan-sirvio"], intentos, pct(tot["plan-sirvio"], intentos)))
    if tot["local-no"]:
        print("  (%d frases se salieron del vocabulario local y pasaron al modelo; una"
              % tot["local-no"])
        print("   misma frase repetida cuenta cada vez)")

    print("")
    print("=" * 76)
    print("LO QUE SE ESPERO, POR CAMINO")
    print("=" * 76)
    if not trabajos:
        print("  no hay ninguna llamada al modelo apuntada")
    else:
        porModo = collections.defaultdict(list)
        for t in trabajos:
            porModo[(t["modo"], t["motor"])].append(t["seg"])
        total = sum(sum(v) for v in porModo.values())
        for k in sorted(porModo, key=lambda k: -sum(porModo[k])):
            v = porModo[k]
            print("  %-9s %-11s n=%3d  media %5.1f s  mediana %5.1f s  max %5.1f s  TOTAL %6.1f s (%s)"
                  % (k[0], k[1], len(v), sum(v) / len(v), mediana(v), max(v), sum(v),
                     pct(sum(v), total)))
        print("  ---")
        print("  esperando al modelo, en total: %.0f s (%.1f min)" % (total, total / 60.0))
        tAg = [t["seg"] for t in trabajos if t["modo"] == "accion"]
        tPl = [t["seg"] for t in trabajos if t["modo"] == "plan"]
        print("  de eso, el AGENTE: %.0f s (%.1f min) en %d llamadas = %s de la espera"
              % (sum(tAg), sum(tAg) / 60.0, len(tAg), pct(sum(tAg), total)))
        if tPl:
            print("  y el PLAN:         %.0f s (%.1f min) en %d llamadas = %s de la espera"
                  % (sum(tPl), sum(tPl) / 60.0, len(tPl), pct(sum(tPl), total)))
            # lo que cuesta el plan frente a lo que ahorra: cada tarea que no va al
            # agente se ahorra la mediana entera del agente
            med = mediana(tAg)
            ahorro = tot["plan-sirvio"] * med
            print("")
            print("  BALANCE DEL PLAN: cuesta %.0f s en total y ahorra ~%.0f s"
                  % (sum(tPl), ahorro))
            print("     (%d tareas x %.1f s, la mediana del agente). Sale %s."
                  % (tot["plan-sirvio"], med,
                     "A CUENTA" if ahorro > sum(tPl) else "CARO: cuesta mas de lo que quita"))
    if perdidos:
        print("")
        print("  %d llamadas se quedaron sin final (reinicio, cancelacion o plazo): %s"
              % (sum(perdidos.values()), dict(perdidos)))
        print("  esa espera se pago igual, pero no se puede cronometrar.")

    print("")
    print("=" * 76)
    print("DIA A DIA (lo que tiene que subir: local. Lo que tiene que bajar: agente)")
    print("=" * 76)
    print("  dia          local  plan-ok  plan-no  agente   espera del agente")
    porDiaT = collections.defaultdict(float)
    porDiaN = collections.Counter()
    for t in trabajos:
        if t["modo"] == "accion":
            porDiaT[t["dia"]] += t["seg"]
            porDiaN[t["dia"]] += 1
    for d in sorted(dias):
        c = dias[d]
        if not (c["local"] or c["submit-accion"] or c["plan-sirvio"] or c["plan-no"]):
            continue
        nLoc = c["local"] + max(0, c["plan-sirvio"] - c["plan-a-medias"])
        base = nLoc + c["submit-accion"]
        print("  %s  %5d  %7d  %7d  %6d   %5.1f min en %-3d  (local %s)"
              % (d, c["local"], c["plan-sirvio"], c["plan-no"], c["submit-accion"],
                 porDiaT.get(d, 0.0) / 60.0, porDiaN.get(d, 0), pct(nLoc, base)))

    tareas = [t for t in trabajos if t["modo"] == "accion"]
    if tareas:
        print("")
        print("LAS QUE FUERON AL AGENTE (aqui esta el trabajo: cuales podrian ser locales)")
        for t in tareas[-20:]:
            print("  %s  %5.1f s  %-11s  '%s'"
                  % (t["dia"], t["seg"], t["motor"], (t["texto"] or "(sin texto)")[:48]))

    est = leer_estadisticas(dia)
    if est:
        print("")
        print("CONTRASTE con memoria\\estadisticas.json (el log y las estadisticas se")
        print("cuentan por separado: si no cuadran, uno de los dos miente):")
        for d in sorted(est):
            f = est[d] or {}
            interes = dict((k, f[k]) for k in
                           ("local", "aprendida", "memoria", "receta", "traducida",
                            "plan", "plan-sirvio", "plan-no", "accion") if k in f)
            if interes:
                print("  %s  %s" % (d, interes))


if __name__ == "__main__":
    main()
