# -*- coding: utf-8 -*-
"""Correccion fonetica de nombres propios contra la lista REAL de apps, sitios y juegos.

La idea: "Abre St", "Abre este", "Abre Sting" son todos "Abre Steam". El oido no va a
mejorar eso (Gemini tampoco lo arregla), pero la lista de nombres que braya puede abrir
es corta y cerrada: se puede corregir DESPUES de oir.
"""
import io, json, os, re, sys, unicodedata

REPO = r"C:\Users\braya\Documents\voice-ctrl"

def plano(s):
    s = unicodedata.normalize("NFD", (s or "").lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9 ]+", " ", s).strip()

def clave_fon(s):
    """Clave fonetica para espanol: junta lo que suena igual al oido de un modelo ASR."""
    t = plano(s).replace(" ", "")
    if not t: return ""
    r = []
    i = 0
    while i < len(t):
        c = t[i]
        nxt = t[i+1] if i + 1 < len(t) else ""
        if c == "h": i += 1; continue                       # muda
        if c == "v": c = "b"                                # b/v suenan igual
        elif c == "z": c = "s"                              # seseo
        elif c == "c" and nxt in "ei": c = "s"
        elif c == "c": c = "k"
        elif c == "q": c = "k"; 
        elif c == "k": c = "k"
        elif c == "w": c = "u"
        elif c == "y": c = "i"
        elif c == "j": c = "x"
        elif c == "g" and nxt in "ei": c = "x"
        elif c == "ll": c = "i"
        if r and r[-1] == c: i += 1; continue               # dobles
        r.append(c); i += 1
    return "".join(r)

def jw(a, b):
    """Jaro-Winkler, sin dependencias."""
    if a == b: return 1.0
    la, lb = len(a), len(b)
    if not la or not lb: return 0.0
    v = max(la, lb) // 2 - 1
    ma, mb = [False]*la, [False]*lb
    m = 0
    for i in range(la):
        for j in range(max(0, i-v), min(lb, i+v+1)):
            if not mb[j] and a[i] == b[j]:
                ma[i] = mb[j] = True; m += 1; break
    if not m: return 0.0
    k = t = 0
    for i in range(la):
        if ma[i]:
            while not mb[k]: k += 1
            if a[i] != b[k]: t += 1
            k += 1
    t //= 2
    j = (m/la + m/lb + (m-t)/m) / 3
    p = 0
    for x, y in zip(a, b):
        if x == y and p < 4: p += 1
        else: break
    return j + p * 0.1 * (1 - j)

def cargar_nombres():
    nombres = []
    c = json.load(io.open(os.path.join(REPO, "commands.json"), encoding="utf-8"))
    for k in ("apps", "sitios"):
        v = c.get(k)
        if isinstance(v, dict): nombres += list(v.keys())
    txt = io.open(os.path.join(REPO, "assistant.log"), encoding="utf-8", errors="replace").read()
    for m in re.finditer(r"abrir ([^\n';]{2,40}?) en Steam", txt):
        n = m.group(1).strip()
        if 2 <= len(n) <= 40: nombres.append(n)
    vistos, out = set(), []
    for n in nombres:
        p = plano(n)
        if p and p not in vistos: vistos.add(p); out.append(n)
    return out

NOMBRES = cargar_nombres()
FON = [(n, plano(n), clave_fon(n)) for n in NOMBRES]
# VERBOS INCLUIDOS LOS MAL OIDOS (19/09): en el uso real salen "Abra Steam", "Habre",
# "Sierra steam". Si el verbo no casa, no se corrige nada y se pierde el caso entero.
VERBOS = ("abre|abreme|abrir|abrime|abra|abr|habre|habré|habrir|ábre|"
          "cierra|cerrar|cierrame|sierra|cierre|cierra|"
          "pon|ponme|poner|ponga|lanza|ejecuta|inicia|arranca|busca|buscame|abrelo")
# palabras que detras del verbo NO son un nombre propio mal oido, son espanol de verdad:
# corregirlas romperia ordenes que hoy funcionan ("abre el archivo", "cierra la ventana")
NO_TOCAR = set("archivo archivos carpeta ventana ventanas pestana pestanas programa programas "
               "aplicacion aplicaciones app apps juego juegos todo todos todas esto eso ese esa "
               "ultimo ultima musica cancion video videos correo correos pagina paginas menu "
               "ajustes configuracion volumen brillo pantalla teclado raton nada algo".split())

def corrige(texto, umbral=0.86):
    """Si la frase es '<verbo> <algo>' y <algo> suena como un nombre conocido, lo sustituye."""
    m = re.match(r"(?i)^\s*(%s)\s+(?:el\s+|la\s+|a\s+|en\s+)?(.+?)\s*[.!?]*$" % VERBOS, texto or "")
    if not m: return texto, None, 0.0
    verbo, obj = m.group(1), m.group(2)
    po, fo = plano(obj), clave_fon(obj)
    if not po: return texto, None, 0.0
    for n, pn, fn in FON:
        if po == pn: return texto, None, 1.0          # ya es exacto: no tocar
    if po in NO_TOCAR or po.split()[0] in NO_TOCAR:
        return texto, None, 0.0
    mejor, punt = None, 0.0
    for n, pn, fn in FON:
        s = max(jw(po, pn), jw(fo, fn) * 0.98)
        # PREFIJO (19/09): "Abre St" es Steam cortado por el recorte, no otra palabra.
        # Si lo oido es prefijo del nombre y tiene >=2 letras, eso vale mas que la
        # distancia, que penaliza injustamente lo corto.
        if len(po) >= 2 and (pn.startswith(po) or fn.startswith(fo)):
            s = max(s, 0.80 + 0.04 * min(len(po), 5))
        # mismo arranque fonetico y longitud parecida: "sting"/"steam" empiezan igual
        elif len(fo) >= 3 and len(fn) >= 3 and fo[:2] == fn[:2] and abs(len(fo) - len(fn)) <= 2:
            s = max(s, jw(fo, fn) + 0.10)
        if s > punt: mejor, punt = n, s
    if mejor and punt >= umbral:
        return "%s %s" % (verbo, mejor), mejor, punt
    return texto, None, punt

if __name__ == "__main__":
    print("nombres conocidos: %d" % len(NOMBRES))
    print(", ".join(NOMBRES[:30]))
    print()
    pruebas = ["Abre St", "Abre este", "Abre Sting", "Abre Steam", "Abre Team", "Abra Steam",
               "Cierra tambien la aplicacion de Xbook", "abre spotify", "abre el disco",
               "Cierra el de ring", "abre discor", "pon youtube", "abre pinteres",
               "abre little nightmares tres", "abre jolo nait", "abre elden ring", "abre outlast"]
    for p in pruebas:
        t, n, s = corrige(p)
        marca = "  ->  %r" % t if t != p else ""
        print("  %-42s %.2f%s" % (repr(p), s, marca))
