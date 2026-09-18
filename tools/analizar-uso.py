# -*- coding: utf-8 -*-
"""Lo que Nova OYO frente a lo que HIZO, con el uso real de braya.

    python tools\\analizar-uso.py           todo lo que haya
    python tools\\analizar-uso.py 2026-09-17  solo ese dia

Por que existe (17/09): la meta es "cero ordenes equivocadas", y hasta hoy eso no se
podia medir. El worker apuntaba en pruebas\\audio\\uso\\registro.jsonl lo que oyo cada
modelo, pero no a donde iba a parar la frase: sabiamos si te habia entendido, no si
habia acertado. Por eso los fallos de verdad -como que arrancara sorda y se activara
sola- solo salian cuando braya los notaba por casualidad.

Ahora el asistente apunta el destino en destinos.jsonl (ver Write-DestinoUso) con el
mismo id, y esto junta las dos mitades.

OJO al leer los numeros: registro.jsonl es un LOG DE EVENTOS, no una fila por orden.
Una misma orden deja una linea al dictarla y otra cuando el oido fino la repasa, asi que
contar lineas da el doble de ordenes de las que hubo. Se agrupa por id.
"""
import collections
import io
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USO = os.path.join(RAIZ, "pruebas", "audio", "uso")

# lo que cuenta como que Nova ACERTO, y lo que cuenta como que fallo
BIEN = ("local", "aprendida", "memoria", "traducida", "receta", "recitado")
MAL = ("error", "descarte", "ruido")
# NI ACIERTO NI FALLO (18/09): lo que Nova hizo con la frase, no si acerto. Mas de la mitad del
# uso real es esto y hasta hoy no dejaba rastro ninguno. No pueden entrar en el porcentaje: si
# lo hicieran, el denominador crece y los aciertos bajan solos sin que Nova falle ni una vez.
NEUTRO = ("charla", "traducir", "plan", "accion", "pregunta")


def leer(nombre):
    ruta = os.path.join(USO, nombre)
    filas = []
    if not os.path.exists(ruta):
        return filas
    for linea in io.open(ruta, encoding="utf-8"):
        linea = linea.strip()
        if not linea:
            continue
        try:
            filas.append(json.loads(linea))
        except Exception:
            pass
    return filas


def txt(d, k):
    return (d.get(k) or "").strip()


def main():
    dia = sys.argv[1] if len(sys.argv) > 1 else ""
    eventos = leer("registro.jsonl")
    destinos = leer("destinos.jsonl")
    if not eventos:
        print("No hay nada grabado todavia en %s" % USO)
        print("Se graba con config.json -> escucha.grabarUso = true, usando Nova de verdad.")
        return

    # una orden = un id. La linea que trae 'entregado' es la de la orden; las demas son
    # repasos del oido fino sobre esa misma orden.
    ordenes = collections.OrderedDict()
    # lo que cuesta cada motor de repaso, en segundos reales. Se calculo a mano dos veces
    # el 17/09 para decidir sobre el ultimo recurso; que salga solo.
    costes = collections.defaultdict(list)
    for e in eventos:
        ident = txt(e, "id")
        if not ident or (dia and not ident.startswith(dia.replace("-", ""))):
            continue
        o = ordenes.setdefault(ident, {"id": ident, "repasos": 0})
        if txt(e, "entregado") or txt(e, "origen"):
            o.update(hora=txt(e, "hora"), origen=txt(e, "origen"), dur=e.get("dur"),
                     pico=e.get("pico"), parakeet=txt(e, "parakeet"),
                     whisper=txt(e, "whisper"), entregado=txt(e, "entregado"))
        else:
            o["repasos"] += 1
            if txt(e, "texto"):
                o["repaso_texto"] = txt(e, "texto")
                o["repaso_motor"] = txt(e, "motor")
            if e.get("segundos") is not None:
                try:
                    costes[txt(e, "motor") or "?"].append(float(e["segundos"]))
                except (TypeError, ValueError):
                    pass

    for d in destinos:
        ident = txt(d, "id")
        if ident not in ordenes:
            continue
        # LO QUE DICE BRAYA MANDA. Un destino dice lo que Nova CREYO hacer: "abrir
        # Outlast" cuenta como acierto aunque el quisiera Outlast 2. Si el dijo que
        # estuvo mal, esa orden es un fallo por encima de lo que diga el destino.
        if txt(d, "hizo") == "fallo-dicho-por-ti":
            ordenes[ident]["lo_dijo_mal"] = True
            ordenes[ident]["queria"] = txt(d, "detalle")
        else:
            ordenes[ident]["hizo"] = txt(d, "hizo")
            ordenes[ident]["detalle"] = txt(d, "detalle")

    todas = list(ordenes.values())
    conVoz = [o for o in todas if o.get("entregado")]
    conDestino = [o for o in conVoz if o.get("hizo")]

    print("=" * 72)
    print("ORDENES REALES: %d   (con voz: %d)" % (len(todas), len(conVoz)))
    mudas = len(todas) - len(conVoz)
    if mudas:
        print("  %d no entregaron texto: el boton pulsado sin hablar, o audio sin voz." % mudas)
    print("=" * 72)

    if not conDestino:
        print("")
        print("Ninguna tiene apuntado QUE HIZO Nova todavia.")
        print("Eso empieza a guardarse desde el 17/09: usa Nova un rato y vuelve a mirar.")
    else:
        # lo que dijo braya manda sobre lo que Nova creyo hacer
        dichas = [o for o in conDestino if o.get("lo_dijo_mal")]
        bien = [o for o in conDestino if o["hizo"] in BIEN and not o.get("lo_dijo_mal")]
        mal = [o for o in conDestino if o["hizo"] in MAL or o.get("lo_dijo_mal")]
        # las neutras se cuentan aparte: si entraran en el denominador, el porcentaje de
        # aciertos bajaria solo por hablar con Nova, sin que se equivocara en nada
        neutras = [o for o in conDestino if o["hizo"] in NEUTRO and not o.get("lo_dijo_mal")]
        idsN = set(o["id"] for o in neutras)
        juzgadas = [o for o in conDestino if o["id"] not in idsN]
        base = max(1, len(juzgadas))
        print("")
        print("DE LAS %d QUE SE SABE QUE HIZO:" % len(conDestino))
        if neutras:
            print("  (%d son charla, traduccion o agente: ni acierto ni fallo, van aparte)" % len(neutras))
        print("  acerto:  %3d  (%.0f %%)" % (len(bien), 100.0 * len(bien) / base))
        print("  fallo:   %3d  (%.0f %%)" % (len(mal), 100.0 * len(mal) / base))
        if dichas:
            print("  ...y %d de esos fallos los dijiste TU ('no era eso'), que es el dato" % len(dichas))
            print("     que no depende de interpretar nada.")
        print("")
        print("  por destino: %s" % dict(collections.Counter(o["hizo"] for o in conDestino).most_common()))
        if mal:
            print("")
            print("  LAS QUE FALLARON (aqui esta el trabajo):")
            for o in mal[-15:]:
                marca = "TU LO DIJISTE" if o.get("lo_dijo_mal") else o["hizo"]
                print("    %s  [%s]  '%s'" % (o.get("hora", "")[-8:], marca, o.get("entregado", "")[:52]))
                if o.get("queria"):
                    print("               querias: '%s'" % o["queria"][:52])

    sinDestino = len(conVoz) - len(conDestino)
    if sinDestino and conDestino:
        print("")
        print("  (%d ordenes con voz siguen sin destino: son anteriores al 17/09)" % sinDestino)

    # lo que costo oirlas
    # OJO (17/09): esto decia "resueltas solo con Parakeet" mirando unicamente si la
    # linea principal traia whisper vacio, y daba 144 de 187. Estaba MAL, y mi propio
    # informe se contradecia sin que yo lo viera: 144 "solo Parakeet" + 125 "repasadas"
    # suman mas que las 187 ordenes que hay. El repaso llega DESPUES, en otra linea, asi
    # que ahorrarse Whisper significa no haber pagado ningun repaso.
    solo = [o for o in conVoz if o.get("parakeet") and not o.get("whisper") and not o.get("repasos")]
    repasadas = [o for o in conVoz if o.get("repasos")]
    print("")
    print("EL OIDO:")
    print("  resueltas solo con Parakeet (sin gastar Whisper): %d de %d" % (len(solo), len(conVoz)))
    print("  repasadas por el oido fino:                       %d" % len(repasadas))
    cambio = [o for o in repasadas if o.get("repaso_texto") and o.get("entregado")
              and o["repaso_texto"].lower().strip(" .,¿?¡!") != o["entregado"].lower().strip(" .,¿?¡!")]
    if repasadas:
        print("  ...y de esas, el repaso oyo algo DISTINTO en %d" % len(cambio))
    ori = collections.Counter(o.get("origen") or "?" for o in conVoz)
    print("  como empezaron: %s" % dict(ori.most_common()))

    # LO QUE CUESTA REPASAR. El 17/09 salio de aqui que el ultimo recurso (turbo) tarda
    # 16 s de mediana y no aporta el 93 % de las veces: es el motor mas lento con
    # diferencia y se lleva casi la mitad del tiempo de todos los repasos.
    if costes:
        print("")
        print("LO QUE CUESTA CADA REPASO:")
        total = 0.0
        for m in sorted(costes, key=lambda k: -sum(costes[k])):
            v = sorted(costes[m])
            total += sum(v)
            mediana = v[len(v) // 2] if len(v) % 2 else (v[len(v) // 2 - 1] + v[len(v) // 2]) / 2.0
            print("  %-6s n=%3d   media %5.1f s   mediana %5.1f s   max %5.1f s   TOTAL %6.1f s"
                  % (m, len(v), sum(v) / len(v), mediana, max(v), sum(v)))
        print("  ---")
        print("  en total se han ido %.0f s (%.1f min) repasando audio" % (total, total / 60.0))


if __name__ == "__main__":
    main()
