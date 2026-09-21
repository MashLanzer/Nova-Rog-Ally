# EL CEREBRO PROPIO DE NOVA (13/09). Lo pidio braya "con especial atencion":
# todo lo que se habla con Nova deja huella aqui, para que con el tiempo sepa
# contestar sola sin preguntar a Ollama ni a la API.
#
# Es delicado: una memoria que guarda errores los repite para siempre (probado
# ese mismo dia: el modelo local dijo que el oso polar vive sin dormir). Reglas:
#   - lo que contesta la API se guarda FIRME;
#   - lo que contesta el modelo local entra PROVISIONAL: solo sirve de pista
#     ("sin confirmar") hasta que la API lo revisa en segundo plano. Si estaba
#     mal, se guarda lo correcto y Nova puede corregirse;
#   - lo que depende de la fecha (noticias, precios, "hoy") NUNCA se guarda como
#     respuesta, ni nada sensible (claves, dinero, salud);
#   - una respuesta de memoria se da TAL CUAL solo si esta firme, es la misma
#     pregunta con el mismo interrogativo ("quien invento" no es "cuando se
#     invento"), no es personal y no depende de lo hablado justo antes ("¿y eso
#     por que?");
#   - "eso no es verdad" la marca como rechazada y no se vuelve a usar.
# De cada charla, la revision saca ademas: datos sobre braya (van al perfil de
# siempre, con sus filtros), como le gusta que le hablen, sus temas, lo que
# cuenta y un recuerdo de lo hablado.
#
# Se busca de DOS formas a la vez: por palabras (siempre, sin RAM extra) y por
# significado (vectores de un modelo de embeddings, si esta). Ninguna de las dos
# necesita a la otra para funcionar.
#
# Todo vive en memoria\cerebro\ (fuera del repositorio): cerebro.json y
# vectores.json, escritos de forma atomica.

import base64
import json
import math
import os
import re
import threading
import time
import unicodedata

try:
    import numpy as np
except Exception:  # noqa: BLE001
    np = None

MAX_RECUERDOS = 5000
MAX_PENDIENTES = 300
MAX_INTENTOS = 3
MAX_ESTILO = 12
MAX_TEMAS = 30
MAX_VARIANTES = 10

VACIAS = set("""
a al algo algun alguna algunas alguno algunos ante antes asi aun bien cada con contra de del desde el ella
ellas ellos en entre era eran eres es esa esas ese esos esta estaba estan estar estas este esto estos estoy fue
fueron ha habia han has hasta hay la las le les lo los mas me mi mis mucho muy nada ni no nos o otra otras
otro otros para pero poco por porque se sea ser si sin sobre son su sus tambien te tener tengo ti tiene
tienen todo todos tu tus un una uno unos unas y ya yo oye nova dime cuentame explicame sabes sabias puedes
podrias quiero quisiera favor porfa hola vale bueno pues entonces decir decirme
que quien quienes cuando donde cuanto cuanta cuantos cuantas como cual cuales
""".split())

INTERROGATIVOS = ["por que", "para que", "quienes", "quien", "cuando", "donde", "cuantos", "cuantas", "cuanto",
                  "cuanta", "cuales", "cual", "como", "que"]
RE_CORTESIA = re.compile(r"^(?:oye|nova|hola|dime|sabes|sabias|me puedes decir|puedes decirme|podrias decirme|y|a ver|bueno|pues)\s+")
RE_CADUCA = re.compile(
    r"\b(hoy|ahora|ahorita|actual|actuales|actualmente|este ano|esta semana|este mes|ultimo|ultima|ultimos|ultimas|"
    r"noticia|noticias|precio|precios|cuesta|cotizacion|resultado|resultados|gano|ganaron|clima|temperatura|"
    r"que hora|que dia|fecha|estreno|manana|ayer)\b")
RE_SEGUIMIENTO = re.compile(r"^(y|pero|entonces|osea|o sea|tambien|ademas)\b|\b(eso|esa|ese|esos|esas|aquello|lo anterior|lo que dijiste|antes)\b")
RE_PERSONAL = re.compile(r"\b(mi|mis|me|yo|tu|tus|te|contigo|conmigo)\b")
RE_PREGUNTA_GENERAL = re.compile(
    r"^(que (es|son|significa|quiere decir)|quien(es)? (es|son|fue|fueron|era|invento|descubrio|escribio|pinto|creo|dirigio|hizo|hicieron|desarrollo|compuso|canta)|"
    # 14/09: lo que ahora va a la API por ser un dato concreto (ver RE_PIDE_DATOS en
    # charla_worker.py) tiene que poder aprenderse, o se preguntaba a la API cada vez
    r"de que (va|trata)|hablame (un poco |algo )?(de|sobre) |que sabes (de|sobre) |"
    r"cuant[oa]s? |como (se|funciona|funcionan|nacen|hacen)|por que |donde (esta|estan|queda|vive|viven)|"
    r"cuando (fue|nacio|murio|se|empezo|termino)|explicame|dame un dato|dato curioso|cual (es|fue|era) |en que (ano|pais|siglo))")
# lo que no es un DATO de braya sino como esta ahora (probado en vivo el 14/09: "estoy
# muy cansado hoy" acabo en el perfil como "esta cansado hoy")
RE_PASAJERO = re.compile(
    r"\b(hoy|ahora|ahorita|ayer|manana|esta semana|este rato|en este momento|todavia|de momento|"
    r"cansad[oa]|agotad[oa]|aburrid[oa]|triste|contento|contenta|enfadad[oa]|nervios[oa]|con sueno|"
    r"de buen humor|de mal humor|estresad[oa]|agobiad[oa])\b")
RE_SENSIBLE = re.compile(r"contrase|password|\bclave\b|\bpin\b|tarjeta|\bbanco\b|bancari|dinero|sueldo|salud|enfermedad|medicament|diagnostic|\bdni\b|pasaporte")
# NI SOBRE NOVA (19/09). Lo que entra en el cerebro por "hechos" y "recuerdo" no
# pasaba por el filtro del perfil, que si lo rechaza (Add-DatoPerfil, assistant.ps1
# :5140). Y se nota: de los 50 episodios guardados hasta hoy, 36 hablan de Nova
# ("Nova se contradijo...", "Braya se queja de que Nova repite mucho"). Eso es un
# diario de mis fallos, no algo que sirva para contestarle. Lo que de ahi valia
# ("prefiere que la musica se abra en YouTube en lugar de Spotify", "respuestas
# cortas") ya esta en memoria\perfil.md y en el estilo, que si pasan por el filtro.
# Las otras dos reglas del perfil -la queja y la deduccion- no se copian: sobre esos
# 50 episodios cazan 0 y 0, y no se paga complejidad sin dato.
RE_SOBRE_NOVA = re.compile(r"\b(?:nova|asistente|la ia|el modelo)\b")


def plano(texto):
    t = unicodedata.normalize("NFD", str(texto or "").lower())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    t = re.sub(r"[^a-z0-9 ]+", " ", t)
    return re.sub(r"\s+", " ", t).strip()


def sin_cortesia(p):
    antes = None
    while antes != p:
        antes = p
        p = RE_CORTESIA.sub("", p)
    return p


def raiz(w):
    # plural sencillo, igual a los dos lados: "pulpos" ~ "pulpo", "animales" ~ "animal"
    if len(w) > 4 and w.endswith("es") and w[-3] not in "aeiou":
        return w[:-2]
    if len(w) > 4 and w.endswith("s"):
        return w[:-1]
    return w


def interrogativo(texto):
    q = sin_cortesia(plano(texto))
    for w in INTERROGATIVOS:
        if q == w or q.startswith(w + " "):
            return w.replace(" ", "_")
    return ""


def fichas(texto):
    p = plano(texto)
    toks = {raiz(w) for w in p.split() if (len(w) >= 3 or w.isdigit()) and w not in VACIAS}
    i = interrogativo(texto)
    if i:
        toks.add("?" + i)
    return toks


def caduca(texto):
    return bool(RE_CADUCA.search(plano(texto)))


def es_seguimiento(texto):
    q = sin_cortesia(plano(texto))
    return bool(RE_SEGUIMIENTO.search(q)) or len([t for t in fichas(texto) if not t.startswith("?")]) == 0


def es_personal(texto):
    return bool(RE_PERSONAL.search(sin_cortesia(plano(texto))))


def es_pregunta_general(texto):
    q = sin_cortesia(plano(texto))
    return bool(RE_PREGUNTA_GENERAL.match(q)) and not caduca(texto) and not es_seguimiento(texto) and not es_personal(texto)


def sensible(texto):
    return bool(RE_SENSIBLE.search(plano(texto)))


def limpio(x, maximo=300):
    t = re.sub(r"\s+", " ", str(x or "")).strip()
    return t[:maximo]


class Cerebro:
    """La memoria que Nova construye hablando. Segura entre hilos."""

    def __init__(self, carpeta, embedder=None, reloj=time.time):
        self.carpeta = carpeta
        self.ruta = os.path.join(carpeta, "cerebro.json")
        self.ruta_vec = os.path.join(carpeta, "vectores.json")
        self.embedder = embedder
        self.reloj = reloj
        self.lock = threading.RLock()
        self.vec = {}
        self.vec_sucio = False
        self.embed_roto_hasta = 0.0
        self.ultimo_id = None
        self._df = None
        self._cache = {}
        self.datos = self._vacio()
        self.cargar()

    # ---------------------------------------------------------------- disco
    @staticmethod
    def _vacio():
        return {"version": 1, "siguiente": 1, "recuerdos": [], "estilo": [], "temas": {}, "pendientes": []}

    def cargar(self):
        with self.lock:
            self.datos = self._vacio()
            if os.path.exists(self.ruta):
                try:
                    with open(self.ruta, encoding="utf-8") as f:
                        d = json.load(f)
                    self.datos.update(d)
                except Exception:  # noqa: BLE001
                    # roto: se aparta (no se pierde) y se empieza de cero
                    try:
                        os.replace(self.ruta, self.ruta + ".corrupto-" + time.strftime("%Y%m%d-%H%M%S"))
                    except OSError:
                        pass
                    self.datos = self._vacio()
            self.vec = {}
            if np is not None and self.embedder is not None and os.path.exists(self.ruta_vec):
                try:
                    with open(self.ruta_vec, encoding="utf-8") as f:
                        dv = json.load(f)
                    if dv.get("modelo") == self.embedder.nombre:     # otro modelo: se rehacen
                        for k, b in (dv.get("v") or {}).items():
                            a = np.frombuffer(base64.b64decode(b), dtype=np.float16).astype(np.float32)
                            self.vec[int(k)] = self._normal(a)
                except Exception:  # noqa: BLE001
                    # roto: se aparta igual que cerebro.json ahi arriba (18/09). Sin esto, el
                    # primer guardado lo sobrescribia y no quedaba forma de ver que se rompio.
                    # Lo que se pierde al regenerarlo es tiempo y RAM, no conocimiento
                    # (completar_vectores los rehace), pero el fichero roto vale para saber
                    # POR QUE se rompio, que es lo que hoy no se puede.
                    try:
                        os.replace(self.ruta_vec, self.ruta_vec + ".corrupto-" + time.strftime("%Y%m%d-%H%M%S"))
                    except OSError:
                        pass
                    self.vec = {}
            self._cambio()

    @staticmethod
    def _escribir(ruta, obj):
        tmp = ruta + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=1)
        os.replace(tmp, ruta)

    def guardar(self):
        with self.lock:
            os.makedirs(self.carpeta, exist_ok=True)
            self._escribir(self.ruta, self.datos)
            if self.vec_sucio and np is not None and self.embedder is not None:
                v = {str(k): base64.b64encode(a.astype(np.float16).tobytes()).decode("ascii") for k, a in self.vec.items()}
                self._escribir(self.ruta_vec, {"modelo": self.embedder.nombre, "v": v})
                self.vec_sucio = False

    # ------------------------------------------------------------- busqueda
    @staticmethod
    def _normal(a):
        n = float(np.linalg.norm(a))
        return a / n if n > 0 else a

    def vector(self, texto):
        """Vector de significado, o None si no hay modelo (o fallo hace poco)."""
        if self.embedder is None or np is None or self.reloj() < self.embed_roto_hasta or not texto:
            return None
        try:
            v = self.embedder.vectores([texto])[0]
            return self._normal(np.asarray(v, dtype=np.float32))
        except Exception:  # noqa: BLE001
            self.embed_roto_hasta = self.reloj() + 60
            return None

    def _cambio(self, r=None):
        self._df = None
        if r is None:
            self._cache = {}
        else:
            self._cache.pop(r.get("id"), None)

    def _formas(self, r):
        c = self._cache.get(r["id"])
        if c is None:
            c = [fichas(f) for f in [r.get("pregunta", "")] + list(r.get("variantes") or []) if f]
            self._cache[r["id"]] = c
        return c

    def _vale_de_contexto(self, h, contenido):
        """?Este recuerdo habla de algo de lo preguntado, o solo coincide el 'que'?

        MEDIDO el 18/09 sobre las 96 frases reales de charla: de 9 recuperaciones, 5 eran el
        mismo recuerdo colandose por la ficha '?que' ("que tengo en mi escritorio" traia
        "?Que es escribir?"). Compartir el interrogativo no es compartir el tema.

        Solo se exige en la via lexica. Si el significado ya dice que se parecen, se respeta:
        "?me gustan los felinos?" debe poder traer "braya adora los gatos" sin una palabra en
        comun, que es justo lo que aporta buscar por significado.
        """
        if h["sem"] is not None and h["comb"] >= 0.45:
            return True
        if h["lex"] < 0.3:
            return False
        if not contenido:
            return False                     # "?Que?" a secas no tiene tema: no arrastra nada
        for formas in self._formas(h["r"]):
            if contenido & {t for t in formas if not t.startswith("?")}:
                return True
        return False

    def _frecuencias(self):
        if self._df is None:
            df = {}
            for r in self.datos["recuerdos"]:
                vistas = set()
                for fs in self._formas(r):
                    vistas |= fs
                for t in vistas:
                    df[t] = df.get(t, 0) + 1
            self._df = df
        return self._df

    @staticmethod
    def _lex(q, d, df, n):
        if not q or not d:
            return 0.0
        if q == d:
            return 1.0

        def peso(t):
            return math.log(1.0 + (n + 1.0) / (1.0 + df.get(t, 0)))
        inter = sum(peso(t) for t in q & d)
        union = sum(peso(t) for t in q | d)
        return inter / union if union else 0.0

    def buscar(self, texto, tipos=None, k=3, qvec=None, con_rechazadas=False):
        q = fichas(texto)
        with self.lock:
            df = self._frecuencias()
            n = len(self.datos["recuerdos"])
            res = []
            for r in self.datos["recuerdos"]:
                if r.get("estado") == "rechazada" and not con_rechazadas:
                    continue
                if tipos and r.get("tipo") not in tipos:
                    continue
                lex = max([self._lex(q, fs, df, n) for fs in self._formas(r)] or [0.0])
                sem = None
                if qvec is not None and r["id"] in self.vec:
                    sem = float(np.dot(qvec, self.vec[r["id"]]))
                comb = (0.6 * sem + 0.4 * lex) if sem is not None else lex
                if comb > 0.05:
                    res.append({"r": r, "lex": lex, "sem": sem, "comb": comb})
            res.sort(key=lambda h: h["comb"], reverse=True)
            return res[:k]

    def respuesta_directa(self, texto, qvec=None):
        """La respuesta aprendida para decirla TAL CUAL, o None. Muy exigente."""
        if caduca(texto) or es_seguimiento(texto) or es_personal(texto):
            return None
        hits = self.buscar(texto, tipos={"respuesta"}, k=1, qvec=qvec)
        if not hits:
            return None
        h = hits[0]
        r = h["r"]
        if r.get("estado") != "firme" or interrogativo(texto) != r.get("interrogativo", ""):
            return None
        sem = h["sem"]
        if sem is None:
            igual = h["lex"] >= 0.8
        else:
            igual = h["lex"] >= 0.999 or sem >= 0.95 or (sem >= 0.90 and h["lex"] >= 0.3)
        if not igual:
            return None
        with self.lock:
            r["usos"] = int(r.get("usos", 0)) + 1
            r["usada"] = self.reloj()
            if h["lex"] < 0.999:
                self._variante(r, texto)     # otra forma de preguntarlo: la proxima, por palabras
            self.ultimo_id = r["id"]
            self.guardar()
            return dict(r)

    def contexto(self, texto, qvec=None, invitado=False):
        """Lo que el modelo deberia tener delante al contestar esto."""
        tipos = {"respuesta"} if invitado else {"respuesta", "contado", "episodio"}
        contenido = {t for t in fichas(texto) if not t.startswith("?")}
        hits = [h for h in self.buscar(texto, tipos=tipos, k=6, qvec=qvec)
                if self._vale_de_contexto(h, contenido)]
        lineas = []
        for h in hits[:3]:
            r = h["r"]
            r["usada"] = self.reloj()        # lo que sirve de contexto no se poda por viejo
            if r["tipo"] == "respuesta":
                marca = "" if r.get("estado") == "firme" else " (SIN CONFIRMAR: no lo afirmes)"
                lineas.append("- %s -> %s%s" % (r["pregunta"], r["respuesta"], marca))
            elif r["tipo"] == "contado":
                lineas.append("- braya te contó: %s" % r["respuesta"])
            else:
                dia = time.strftime("%d/%m", time.localtime(r.get("creada", 0)))
                lineas.append("- recuerdo del %s: %s" % (dia, r["respuesta"]))
        partes = []
        if lineas:
            partes.append("Lo que ya sabes (úsalo solo si viene al caso):\n" + "\n".join(lineas))
        if not invitado:
            with self.lock:
                estilo = list(self.datos.get("estilo") or [])
                temas = sorted((self.datos.get("temas") or {}).items(), key=lambda kv: -kv[1])[:5]
            if estilo:
                partes.append("Cómo le gusta a braya que le hables: " + "; ".join(estilo) + ".")
            if temas:
                partes.append("Temas de los que suele hablar: " + ", ".join(t for t, _ in temas) + ".")
        return ("\n\n" + "\n\n".join(partes)) if partes else ""

    # ------------------------------------------------------------ aprender
    def _por_id(self, idr):
        if idr is None:
            return None
        for r in self.datos["recuerdos"]:
            if r["id"] == idr:
                return r
        return None

    def _variante(self, r, texto):
        texto = limpio(texto, 200)
        if not texto:
            return
        p = plano(texto)
        if p == plano(r.get("pregunta", "")) or any(p == plano(v) for v in r.get("variantes") or []):
            return
        r.setdefault("variantes", []).append(texto)
        while len(r["variantes"]) > MAX_VARIANTES:
            r["variantes"].pop(0)
        self._cambio(r)

    def _nuevo(self, tipo, pregunta, respuesta, estado, origen):
        ahora = self.reloj()
        r = {"id": self.datos["siguiente"], "tipo": tipo, "pregunta": pregunta, "interrogativo": interrogativo(pregunta),
             "variantes": [], "respuesta": respuesta, "estado": estado, "origen": origen,
             "creada": ahora, "usada": ahora, "usos": 0}
        self.datos["siguiente"] += 1
        self.datos["recuerdos"].append(r)
        self._cambio()
        self._podar()
        return r

    def guardar_respuesta(self, pregunta, respuesta, estado, origen, vector=None):
        pregunta = limpio(pregunta, 200)
        respuesta = limpio(respuesta, 600)
        if not pregunta or not respuesta or caduca(pregunta) or sensible(pregunta + " " + respuesta):
            return None
        inter = interrogativo(pregunta)
        with self.lock:
            # la misma respuesta que ya se rechazo no vuelve a entrar
            for h in self.buscar(pregunta, tipos={"respuesta"}, k=3, con_rechazadas=True):
                r = h["r"]
                if r.get("estado") == "rechazada" and h["lex"] >= 0.999 and plano(r["respuesta"]) == plano(respuesta):
                    return None
            existente = None
            for h in self.buscar(pregunta, tipos={"respuesta"}, k=3, qvec=vector):
                r = h["r"]
                if r.get("interrogativo", "") == inter and (h["lex"] >= 0.85 or (h["sem"] is not None and h["sem"] >= 0.93)):
                    existente = r
                    break
            if existente is not None:
                # lo firme no lo pisa lo provisional
                if estado == "firme" or existente.get("estado") != "firme":
                    existente.update(respuesta=respuesta, estado=estado, origen=origen)
                    if estado == "firme":
                        existente["revisada"] = self.reloj()
                self._variante(existente, pregunta)
                r = existente
            else:
                r = self._nuevo("respuesta", pregunta, respuesta, estado, origen)
            if vector is not None:
                self.vec[r["id"]] = vector
                self.vec_sucio = True
            self._cambio(r)
            self.ultimo_id = r["id"]
            self.guardar()
            return r

    def guardar_texto(self, tipo, texto):
        """Lo que braya conto ('contado') o un recuerdo de lo hablado ('episodio')."""
        texto = limpio(texto, 300)
        if not texto or len(texto) < 8 or sensible(texto):
            return None
        if RE_SOBRE_NOVA.search(plano(texto)):
            return None      # hablaba de mi, no de braya: al cerebro no entra (19/09)
        with self.lock:
            for h in self.buscar(texto, tipos={tipo}, k=1):
                if h["lex"] >= 0.85:
                    return h["r"]             # ya lo sabia
            r = self._nuevo(tipo, texto, texto, "firme", "charla")
            self.guardar()
            return r

    def aprender_turno(self, pregunta, respuesta, origen, previo="", vector=None):
        """Tras cada respuesta de Ollama o de la API. Lo que no se sabe si esta
        bien entra como provisional y queda pendiente de revision."""
        if origen not in ("local", "api") or not limpio(pregunta) or not limpio(respuesta):
            return None
        job = {"id": int(self.reloj() * 1000), "pregunta": limpio(pregunta, 300), "respuesta": limpio(respuesta, 800),
               "origen": origen, "previo": limpio(previo, 300), "intentos": 0}
        if es_pregunta_general(pregunta):
            r = self.guardar_respuesta(pregunta, respuesta, "firme" if origen == "api" else "provisional", origen, vector)
            if r is not None:
                job["recuerdo"] = r["id"]
        with self.lock:
            pend = self.datos["pendientes"]
            pend.append(job)
            while len(pend) > MAX_PENDIENTES:
                pend.pop(0)
            self.guardar()
        return job

    def siguiente_pendiente(self):
        with self.lock:
            for j in self.datos["pendientes"]:
                if j.get("intentos", 0) < MAX_INTENTOS:
                    return dict(j)
        return None

    def fallo_revision(self, job):
        with self.lock:
            for j in list(self.datos["pendientes"]):
                if j.get("id") == job.get("id"):
                    j["intentos"] = j.get("intentos", 0) + 1
                    if j["intentos"] >= MAX_INTENTOS:
                        self.datos["pendientes"].remove(j)
            self.guardar()

    def aplicar_revision(self, job, rev):
        """Aplica lo que dijo el revisor (la API). Devuelve eventos para el
        asistente: {"ev": "dato"} para el perfil, {"ev": "correccion"}."""
        eventos = []
        with self.lock:
            self.datos["pendientes"] = [j for j in self.datos["pendientes"] if j.get("id") != job.get("id")]
            prov = self._por_id(job.get("recuerdo"))
            pg = limpio(rev.get("pregunta_general"), 200)
            buena = limpio(rev.get("respuesta_buena"), 600)
            general = rev.get("tipo_turno") == "pregunta_general" and not rev.get("caduca") and pg and buena and not caduca(pg)
            if general:
                if prov is not None and prov.get("estado") != "rechazada":
                    # la pregunta queda como la escribe el revisor (bien escrita, se
                    # entiende sola: es la que se lee en la trivia); la tuya, variante
                    original = prov["pregunta"]
                    if prov.get("estado") != "firme":
                        prov.update(respuesta=buena, estado="firme", origen="revisada", revisada=self.reloj())
                    prov["pregunta"] = pg
                    self._variante(prov, original)
                    self._cambio(prov)
                elif prov is None or prov.get("estado") == "rechazada":
                    r = self.guardar_respuesta(pg, buena, "firme", "revisada")
                    if r is not None and es_pregunta_general(job.get("pregunta", "")):
                        self._variante(r, job["pregunta"])
                if job.get("origen") == "local" and rev.get("respuesta_correcta") is False:
                    eventos.append({"ev": "correccion", "texto": buena})
            elif prov is not None and prov.get("estado") != "firme":
                if rev.get("respuesta_correcta") is False:
                    prov["estado"] = "rechazada"
                    self._cambio(prov)
                else:
                    # no era conocimiento para reutilizar (o caduca): fuera
                    self.datos["recuerdos"].remove(prov)
                    self.vec.pop(prov["id"], None)
                    self._cambio()
            for d in rev.get("datos_usuario") or []:
                d = limpio(d, 180)
                # al perfil solo lo estable: nada sensible ni pasajero ("esta cansado hoy")
                if 8 <= len(d) and not sensible(d) and not RE_PASAJERO.search(plano(d)):
                    eventos.append({"ev": "dato", "texto": d})
            for e in rev.get("estilo") or []:
                self._estilo(limpio(e, 120))
            for t in rev.get("temas") or []:
                self._tema(t)
            for h in rev.get("hechos") or []:
                self.guardar_texto("contado", h)
            if rev.get("recuerdo"):
                self.guardar_texto("episodio", rev.get("recuerdo"))
            self.guardar()
        return eventos

    def _estilo(self, e):
        # EL MISMO FILTRO QUE guardar_texto, Y AQUI PESA MAS (20/09, C5). El filtro de
        # "no guardes lo que habla de mi" se puso el 19/09 en guardar_texto, pero _estilo
        # escribe en el MISMO cerebro.json desde la misma aplicar_revision y no lo tenia.
        # Y es el que mas dano hace: el estilo viaja en el prompt de TODAS las peticiones
        # (contexto() lo mete sin condicion), mientras que los episodios entraban en 2 de
        # 96 turnos -ese fue justo el argumento con el que se descarto limpiar lo viejo-.
        # Medido el 20/09: 6 de las 12 entradas de "estilo" caian con este criterio, entre
        # ellas "le gusta que Nova entienda bien lo que dice sin tergiversarlo", que no es
        # una preferencia de braya: es una queja sobre Nova.
        if not e or sensible(e):
            return
        if RE_SOBRE_NOVA.search(plano(e)):
            return
        est = self.datos.setdefault("estilo", [])
        if any(plano(x) == plano(e) for x in est):
            return
        est.append(e)
        while len(est) > MAX_ESTILO:
            est.pop(0)

    def _tema(self, t):
        t = plano(t)[:30]
        if not t or len(t.split()) > 3:
            return
        # y los temas tampoco: "nova" o "el asistente" como tema de conversacion acaba
        # metiendose en el prompt igual que el estilo (ver el comentario de _estilo)
        if RE_SOBRE_NOVA.search(t):
            return
        temas = self.datos.setdefault("temas", {})
        temas[t] = temas.get(t, 0) + 1
        if len(temas) > MAX_TEMAS:
            for k, _ in sorted(temas.items(), key=lambda kv: kv[1])[:len(temas) - MAX_TEMAS]:
                del temas[k]

    def marcar_incorrecta(self):
        """ "Eso no es verdad": la ultima respuesta usada o aprendida no se usa mas."""
        with self.lock:
            r = self._por_id(self.ultimo_id)
            if r is None or r.get("tipo") != "respuesta":
                return None
            r["estado"] = "rechazada"
            self._cambio(r)
            self.guardar()
            return dict(r)

    def olvidar(self, sobre):
        """ "Olvida lo de los osos polares": fuera todo recuerdo que CONTENGA esas
        palabras (en la pregunta, sus variantes o la respuesta). No vale el
        parecido global: "oso polar" frente a "¿cuanto duerme un oso polar?" se
        parece poco y es justo lo que hay que borrar."""
        with self.lock:
            q = {t for t in fichas(sobre) if not t.startswith("?")}
            if not q:
                return 0
            fuera = []
            for r in self.datos["recuerdos"]:
                todo = set()
                for fs in self._formas(r):
                    todo |= fs
                todo |= fichas(r.get("respuesta", ""))
                if q <= todo:
                    fuera.append(r)
            for r in fuera:
                self.datos["recuerdos"].remove(r)
                self.vec.pop(r["id"], None)
            # y deja de contarlo como tema suyo (probado en vivo: tras "olvida lo de
            # los agujeros negros" seguia el tema "agujeros negros")
            temas = self.datos.get("temas") or {}
            temas_fuera = [t for t in temas if {raiz(w) for w in plano(t).split() if w not in VACIAS} & q]
            for t in temas_fuera:
                del temas[t]
            if fuera or temas_fuera:
                self.vec_sucio = True
                self._cambio()
                self.guardar()
            return len(fuera)

    def _podar(self):
        rec = self.datos["recuerdos"]
        if len(rec) <= MAX_RECUERDOS:
            return
        prioridad = {"provisional": 0, "rechazada": 1}
        tipo_p = {"episodio": 2, "contado": 3, "respuesta": 4}

        def clave(r):
            return (prioridad.get(r.get("estado"), tipo_p.get(r.get("tipo"), 5)), r.get("usos", 0), r.get("usada", 0))
        for r in sorted(rec, key=clave)[:len(rec) - MAX_RECUERDOS]:
            rec.remove(r)
            self.vec.pop(r["id"], None)
        self.vec_sucio = True
        self._cambio()

    def completar_vectores(self, cuantos=16):
        """Pone vector a los recuerdos que no lo tienen (en segundo plano)."""
        if self.embedder is None or np is None or self.reloj() < self.embed_roto_hasta:
            return 0
        with self.lock:
            faltan = [r for r in self.datos["recuerdos"] if r["id"] not in self.vec and r.get("estado") != "rechazada"][:cuantos]
        if not faltan:
            return 0
        try:
            vs = self.embedder.vectores([r["pregunta"] for r in faltan])
        except Exception:  # noqa: BLE001
            self.embed_roto_hasta = self.reloj() + 60
            return 0
        with self.lock:
            for r, v in zip(faltan, vs):
                self.vec[r["id"]] = self._normal(np.asarray(v, dtype=np.float32))
            self.vec_sucio = True
            self.guardar()
        return len(faltan)

    def repaso(self, forzar=False):
        """REPASO DEL DIA (M3; una vez al dia, con Nova en reposo): poda lo viejo
        que no sirve, junta preguntas repetidas y vuelve a mandar a revision lo
        provisional que se quedo sin revisar. Devuelve lo que hizo, o None si hoy
        ya se repaso."""
        ahora = self.reloj()
        hoy = time.strftime("%Y-%m-%d", time.localtime(ahora))
        with self.lock:
            if self.datos.get("ultimo_repaso") == hoy and not forzar:
                return None
            self.datos["ultimo_repaso"] = hoy
            dia = 86400

            def viejo(r, dias, campo="usada"):
                return ahora - r.get(campo, ahora) > dias * dia
            # 1) poda
            podar = [r for r in self.datos["recuerdos"] if
                     (r.get("estado") == "rechazada" and viejo(r, 60, "creada")) or
                     (r.get("estado") == "provisional" and viejo(r, 30, "creada")) or
                     (r["tipo"] == "episodio" and viejo(r, 180)) or
                     (r["tipo"] == "contado" and viejo(r, 365))]
            ids_podar = {r["id"] for r in podar}
            # 2) repetidos: mismas palabras y mismo interrogativo o, con vectores,
            #    casi el mismo significado. Se queda el mejor (firme, mas usado)
            resp = [r for r in self.datos["recuerdos"]
                    if r["tipo"] == "respuesta" and r.get("estado") != "rechazada" and r["id"] not in ids_podar]
            resp.sort(key=lambda r: (r.get("estado") == "firme", r.get("usos", 0)), reverse=True)
            vistos = {}
            fuera = set()
            for r in resp:
                clave = (r.get("interrogativo", ""), frozenset(fichas(r["pregunta"])))
                if clave in vistos:
                    self._juntar(vistos[clave], r)
                    fuera.add(r["id"])
                else:
                    vistos[clave] = r
            if np is not None and self.vec:
                quedan = [r for r in resp if r["id"] not in fuera and r["id"] in self.vec][:1500]
                if len(quedan) > 1:
                    m = np.stack([self.vec[r["id"]] for r in quedan])
                    s = m @ m.T
                    for i, a in enumerate(quedan):
                        if a["id"] in fuera:
                            continue
                        for j in np.nonzero(s[i, i + 1:] >= 0.95)[0]:
                            b = quedan[i + 1 + int(j)]
                            if b["id"] in fuera or b.get("interrogativo", "") != a.get("interrogativo", ""):
                                continue
                            self._juntar(a, b)
                            fuera.add(b["id"])
            quitar = ids_podar | fuera
            if quitar:
                self.datos["recuerdos"] = [r for r in self.datos["recuerdos"] if r["id"] not in quitar]
                for i in quitar:
                    self.vec.pop(i, None)
                self.vec_sucio = True
            # 3) lo provisional que se quedo sin revisar vuelve a la cola
            en_cola = {j.get("recuerdo") for j in self.datos["pendientes"]}
            reencolados = 0
            for r in self.datos["recuerdos"]:
                if (r["tipo"] == "respuesta" and r.get("estado") == "provisional" and r["id"] not in en_cola
                        and len(self.datos["pendientes"]) < MAX_PENDIENTES):
                    self.datos["pendientes"].append({"id": int(ahora * 1000) + r["id"], "pregunta": r["pregunta"],
                                                     "respuesta": r["respuesta"], "origen": "local", "previo": "",
                                                     "intentos": 0, "recuerdo": r["id"]})
                    reencolados += 1
            self._cambio()
            self.guardar()
            return {"juntados": len(fuera), "reencolados": reencolados, "podados": len(ids_podar)}

    def _juntar(self, queda, sobra):
        for v in [sobra.get("pregunta", "")] + list(sobra.get("variantes") or []):
            self._variante(queda, v)
        queda["usos"] = int(queda.get("usos", 0)) + int(sobra.get("usos", 0))

    def pregunta_trivia(self, excluir=()):
        """TRIVIA (F7): una pregunta para jugar, SOLO de lo confirmado y general.
        Hace falta saber al menos tres cosas seguras."""
        import random
        with self.lock:
            buenas = [r for r in self.datos["recuerdos"] if r["tipo"] == "respuesta" and r.get("estado") == "firme"
                      and es_pregunta_general(r["pregunta"])]
            if len(buenas) < 3:
                return None
            candidatas = [r for r in buenas if r["id"] not in set(excluir)] or buenas
            return dict(random.choice(candidatas))

    def balance(self):
        with self.lock:
            b = {"respuestas": 0, "provisionales": 0, "contado": 0, "episodios": 0, "estilo": len(self.datos.get("estilo") or []),
                 "temas": len(self.datos.get("temas") or {}), "pendientes": len(self.datos["pendientes"])}
            for r in self.datos["recuerdos"]:
                if r.get("estado") == "rechazada":
                    continue
                if r["tipo"] == "respuesta":
                    b["respuestas" if r.get("estado") == "firme" else "provisionales"] += 1
                elif r["tipo"] == "contado":
                    b["contado"] += 1
                else:
                    b["episodios"] += 1
            return b


def juzgar_trivia(pregunta, respuesta_buena, dicho):
    """¿Acierta? Las palabras de la respuesta que NO estan en la pregunta
    ("Leonardo", "Vinci") tienen que aparecer en lo dicho: al menos una, o un
    tercio si la respuesta es larga. Sin modelo: instantaneo."""
    clave = {t for t in fichas(respuesta_buena) - fichas(pregunta) if not t.startswith("?")}
    if not clave:
        return False
    return len(clave & fichas(dicho)) >= max(1, math.ceil(len(clave) * 0.3))


# ------------------------------------------------------------------ revisor
REVISOR_SISTEMA = """Eres el revisor de la memoria de Nova, la asistente de voz de braya. Recibes un turno de conversación (lo que dijo braya y lo que contestó Nova). Devuelve SOLO un objeto JSON válido, sin texto alrededor, con estas claves:
- "tipo_turno": "pregunta_general" (pregunta de conocimiento general que sirve igual otro día), "charla", "personal", "actualidad" u "otro".
- "respuesta_correcta": true o false: si lo que contestó Nova es correcto y no se inventa nada.
- "pregunta_general": si tipo_turno es "pregunta_general", la pregunta reformulada para entenderse sola; si no, "".
- "respuesta_buena": si tipo_turno es "pregunta_general", la respuesta correcta en una a tres frases naturales para decir en voz alta en español; si no, "".
- "caduca": true si la respuesta depende de la fecha o de la actualidad.
- "datos_usuario": lista de datos ESTABLES sobre braya que dijo él (en tercera persona, cortos): gustos, nombres, costumbres. Nunca estados pasajeros (cansado, aburrido, de buen humor) ni lo que hace hoy; nunca contraseñas, dinero, salud ni documentos.
- "estilo": lista de preferencias que expresó sobre cómo quiere que Nova le hable (vacía si no dijo nada de eso).
- "temas": lista de 1 a 3 temas de la conversación, de una o dos palabras.
- "hechos": lista de cosas NO personales que contó braya (en tercera persona, empezando por "braya dice que"). Vacía si no contó nada.
- "recuerdo": una frase corta con lo que vale la pena recordar de esta conversación, o "" si no hay nada.
Sé estricto: ante la duda, respuesta_correcta false y listas vacías."""


def revisar_turno(job, llamar_api):
    """Pide la revision de un turno. llamar_api(sistema, texto_usuario) -> texto."""
    turno = {"braya_dijo": job.get("pregunta", ""), "nova_contesto": job.get("respuesta", ""),
             "lo_que_se_hablaba_justo_antes": job.get("previo", "")}
    crudo = llamar_api(REVISOR_SISTEMA, json.dumps(turno, ensure_ascii=False))
    m = re.search(r"\{.*\}", crudo or "", re.S)
    if not m:
        raise ValueError("el revisor no devolvio JSON")
    rev = json.loads(m.group(0))
    if not isinstance(rev, dict):
        raise ValueError("el revisor no devolvio un objeto")
    return rev
