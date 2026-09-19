# -*- coding: utf-8 -*-
"""Donde falla el oido de Nova, con el uso real. Agrupa registro.jsonl por id y clasifica."""
import io, json, os, re, collections, unicodedata

REPO = r"C:\Users\braya\Documents\voice-ctrl"
USO = os.path.join(REPO, "pruebas", "audio", "uso")
AQUI = os.path.dirname(os.path.abspath(__file__))

def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")

filas = [json.loads(l) for l in io.open(os.path.join(USO, "registro.jsonl"), encoding="utf-8") if l.strip()]
dest = {}
for l in io.open(os.path.join(USO, "destinos.jsonl"), encoding="utf-8"):
    if l.strip():
        r = json.loads(l); dest[r["id"]] = r

# agrupar por id conservando lo que oyo cada motor (hay varias lineas por orden)
ords = collections.OrderedDict()
for r in filas:
    i = r["id"]
    o = ords.setdefault(i, {"id": i, "dur": 0, "pico": 0, "origen": "", "parakeet": "", "whisper": "",
                            "vosk": "", "entregado": "", "seguridad": None, "motor": "", "texto": ""})
    for k in ("dur", "pico", "origen", "parakeet", "whisper", "vosk", "entregado", "seguridad", "motor", "texto"):
        v = r.get(k)
        if v not in (None, "", 0): o[k] = v

ING = set("the and i'm im you it is are was were well yeah okay ok what let's so my me his her they we this that have has don't can't now here there good thanks thank please yes no hey oh come going look see know just like get got one two three".split())
ESP = set("el la los las un una de del que en por para con sin es esta este esa ese abre cierra pon pone sube baja busca dime mira quiero pantalla volumen brillo juego musica hora bateria steam nova si no gracias hola vale ahora luego tambien".split())
VERBOS = set("abre abreme abrir cierra cerrar pon ponme poner busca buscame buscar sube subir baja bajar quita quitar dime dame lee leeme silencia apaga enciende activa desactiva reproduce pausa manda envia escribe crea cuenta mira traduce recuerdame avisame".split())
ALU = ("suscribete", "suscribase", "gracias por ver", "no olvides suscribirte", "subtitulos", "amara.org",
       "www.", "youtube.com", "comenta", "dale like", "hasta la proxima", "musica de fondo")

try:
    cmds = json.load(io.open(os.path.join(REPO, "commands.json"), encoding="utf-8"))
except Exception:
    cmds = {}
conocidos = set()
for k in ("apps", "sitios"):
    v = cmds.get(k)
    if isinstance(v, dict): conocidos |= {plano(x) for x in v.keys()}
juegos = set()
try:
    for m in re.finditer(r"abrir ([^\n']{2,40}?) en Steam", io.open(os.path.join(REPO, "assistant.log"), encoding="utf-8", errors="replace").read()):
        juegos.add(plano(m.group(1)))
except Exception: pass
conocidos |= juegos

def dist(a, b):
    a, b = plano(a).split(), plano(b).split()
    if not a and not b: return 0.0
    comunes = len(set(a) & set(b))
    return 1.0 - comunes / max(1, max(len(set(a)), len(set(b))))

cats = collections.OrderedDict()
detalle = collections.defaultdict(list)
BIEN = ("local", "aprendida", "memoria", "receta", "recitado", "traducida")
NEUTRO = ("charla", "traducir", "plan", "accion", "pregunta")

for i, o in ords.items():
    d = dest.get(i, {})
    hizo = d.get("hizo", "")
    par, whi, ent = o["parakeet"] or "", o["whisper"] or "", o["entregado"] or ""
    dur, pico = float(o["dur"] or 0), float(o["pico"] or 0)
    tp = plano(par).split()
    cat = None
    if dur < 0.6 or pico < 0.01: cat = "a_sin_audio"
    elif hizo in BIEN: cat = "h_bien"
    elif par and not (set(tp) & ESP) and (set(tp) & ING): cat = "b_parakeet_ingles"
    elif not par and not whi: cat = "c_vacio"
    elif any(x in plano(ent) or x in plano(whi) for x in ALU): cat = "e_alucinacion"
    elif ent and len(ent.split()) <= 2 and dur >= 1.5: cat = "d_fragmento"
    elif hizo in NEUTRO: cat = "i_neutro"
    else:
        pe = plano(ent).split()
        if pe and pe[0] in VERBOS:
            resto = " ".join(pe[1:])
            if resto and not any(c in resto for c in conocidos): cat = "f_nombre_mal"
        if not cat and par and whi and dist(par, whi) > 0.5: cat = "g_discrepancia"
        if not cat: cat = "j_otro"
    cats[cat] = cats.get(cat, 0) + 1
    detalle[cat].append({"id": i, "dur": dur, "pico": pico, "par": par[:60], "whi": whi[:60],
                         "ent": ent[:60], "hizo": hizo, "det": (d.get("detalle") or "")[:50]})

total = len(ords)
utiles = total - cats.get("a_sin_audio", 0)
print("ORDENES CON AUDIO GRABADO: %d   (con audio util: %d)" % (total, utiles))
print()
print("%-22s %5s %7s" % ("categoria", "n", "% util"))
for c in sorted(cats, key=lambda k: -cats[k]):
    print("%-22s %5d %6.1f%%" % (c, cats[c], 100.0 * cats[c] / max(1, utiles)))
print()
for c in ("b_parakeet_ingles", "d_fragmento", "e_alucinacion", "f_nombre_mal", "g_discrepancia", "c_vacio", "j_otro"):
    if c not in detalle: continue
    print("--- %s (%d) ---" % (c, len(detalle[c])))
    for x in detalle[c][:6]:
        print("   %s d=%.1f p=%.3f" % (x["id"], x["dur"], x["pico"]))
        print("      par='%s'  whi='%s'" % (x["par"], x["whi"]))
        print("      ent='%s'  hizo=%s %s" % (x["ent"], x["hizo"], x["det"]))
    print()

json.dump({c: detalle[c] for c in detalle}, io.open(os.path.join(AQUI, "taxonomia.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
mejorar = {x["id"]: c for c in ("b_parakeet_ingles", "d_fragmento", "e_alucinacion", "f_nombre_mal", "g_discrepancia") for x in detalle.get(c, [])}
json.dump(mejorar, io.open(os.path.join(AQUI, "ids-a-mejorar.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("candidatos a mejorar: %d ids -> ids-a-mejorar.json" % len(mejorar))
etiq = sum(1 for i, o in ords.items() if dest.get(i, {}).get("hizo") in BIEN and dest.get(i, {}).get("detalle"))
print("con etiqueta funcional (hizo=BIEN y detalle): %d" % etiq)
