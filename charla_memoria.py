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
# EL DISYUNTOR DEL REPASO DE RECUERDOS (26/09, idea 31). NO sale de ninguna medicion que diga
# "0,5 es el punto bueno": eso no existe y hay que decirlo. Lo que SI esta medido es el reparto
# de hoy sobre memoria\cerebro\cerebro.json: 36 de los 117 recuerdos de tipo contado+episodio
# caen con el filtro, el 30,8 %. El freno esta diecinueve puntos por encima de lo observado.
# Su unico trabajo: si un dia el filtro se ensancha y se empieza a comer mas de la MITAD de la
# memoria de braya, Nova no toca nada y lo dice. Eso significaria que esta mal el filtro, no la
# memoria.
TOPE_REPASO_RECUERDOS = 0.5
MAX_TEMAS = 30
MAX_VARIANTES = 10
# CUANDO NOVA PREGUNTA, NO ESTA RESPONDIENDO (26/09, idea 33 de las 121). Ver es_aclaracion.
# EL CORTE SALE DE UNA MESETA, no de un filo: sobre las 249 respuestas de Nova agrupadas de los
# dos registros, la rama de "esto es toda una pregunta" caza 2 con corte 60, 3 con 80, 4 con
# 100, 5 con 120 y 7 sin corte. Los largos reales son 25, 51, 64, 99, 101, 123 y 124: cualquier
# corte entre 102 y 123 da exactamente las mismas cinco, asi que 120 cae en mitad del llano.
# Y las dos que quedan fuera por largas (123 y 124) son aclaraciones de verdad, pero las caza
# igual la rama del patron: el corte no pierde ninguna.
ACLARACION_MAX_LETRAS = 120

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
# LO QUE DICE NOVA CUANDO NO ENTENDIO (26/09, idea 33). En cadena CRUDA como todas sus
# hermanas: sin la r, el \b de Python es un BACKSPACE, y hay un banco que barre este
# fichero buscando caracteres de control justo por eso.
# "completa" VA ANCLADA AL PRINCIPIO DE FRASE, y no es gusto: sobre las 249 respuestas del
# registro, suelta caza 7 y TRES son falsas ("completamente", "un reino completo"); con
# \bcompleta\b caza 4 y dos siguen siendo buenas ("la fecha completa", "la lista completa
# de nombres de tus juegos"); anclada al principio de frase caza 2 y las dos son de verdad.
RE_ACLARACION = re.compile(
    r"no te entend|no te he entendido|no entiendo bien|a que te refier|"
    r"no me quedo claro|no me ha quedado claro|me (?:lo )?repites|"
    r"(?:^|[.!?¿]\s*)complet(?:a|alo|ala)\b")


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


def clave_tema(t):
    """Las raices de un tema, en orden: "videojuegos" y "videojuego" dan la misma.

    DOS DE LAS CINCO LINEAS DE "temas de los que suele hablar" DECIAN LO MISMO (27/09, idea 94).
    En el prompt de cada charla viajan los cinco temas mas contados, y hoy eran: videojuegos (63),
    comunicacion (26), clarificacion (10), steam (10) y videojuego (10). O sea que una de las cinco
    plazas estaba gastada en repetir el primero en singular, y el tema que se quedaba fuera era
    real (roblox, 6).

    Y NO ES UN CASO INVENTADO NI HABRA MUCHOS: pasados los 30 temas guardados por esta clave salen
    29 grupos. La UNICA pareja que se junta en todo el cerebro es justo esa, y estaba en el prompt
    dos veces. Los temas estan ademas en su tope (MAX_TEMAS = 30), asi que cada tema nuevo echa a
    otro: una plaza gastada cuesta el doble.

    EN ORDEN Y NO EN CONJUNTO, aunque la ficha pedia un frozenset: con tuplas, "juegos de mesa" y
    "mesa de juegos" siguen siendo dos temas. Medido sobre los 30 de hoy, las dos formas dan
    exactamente los mismos 29 grupos, asi que la mas conservadora sale gratis.
    """
    return tuple(raiz(w) for w in t.split())


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


def es_aclaracion(texto):
    """Si esto es Nova PIDIENDO que le aclaren algo, y no una respuesta.

    EL CASO, en el cerebro de hoy: de las tres respuestas en estado "firme", UNA es el recuerdo
    117: pregunta "¿Como se llama", respuesta "¿Como se llama que? Completa que no me quedo
    claro.". Esta FIRME, o sea que respuesta_directa la suelta TAL CUAL, sin pasar por el
    modelo. Comprobado ejecutandolo: preguntando "Como se llama" Nova contesta con esa peticion
    de aclaracion, para siempre, cada vez.

    DOS CAMINOS, y el segundo lleva su guarda dentro:
      - el patron de mas arriba, que caza las formas de decirlo;
      - o que el texto sea TODA una pregunta: corto, empezando por el signo de apertura y con
        todas sus frases acabando en interrogacion.
    EL "EMPIEZA POR EL SIGNO" ES LA GUARDA, y esta medida: partiendo solo por frases se cazan 16
    de 249 y entre ellas cae una respuesta buena -"Hoy es un dia normal, pero dame mas detalles:
    ¿que dia especifico quieres saber...?"-, porque su afirmacion va separada por coma y dos
    puntos, no por punto. Exigiendo que empiece por el signo se cazan 5 y las cinco lo son.
    """
    t = (texto or "").strip()
    if not t:
        return False
    if RE_ACLARACION.search(plano(t)):
        return True
    if len(t) >= ACLARACION_MAX_LETRAS:
        return False
    if not t.startswith("¿") or not t.endswith("?"):
        return False
    # y TODAS sus frases tienen que ser preguntas: una afirmacion delante y esto ya no es
    # solo una peticion de aclaracion
    for trozo in re.split(r"(?<=[.!?])\s+", t):
        trozo = trozo.strip()
        if trozo and not trozo.endswith("?"):
            return False
    return True


def sensible(texto):
    return bool(RE_SENSIBLE.search(plano(texto)))


# LAS PALABRAS QUE EL PONE ENTRE COMILLAS (22/09). Cuando braya corrige como quiere
# que le hablen, el revisor escribe la palabra exacta entrecomillada: "No usar la
# palabra 'man'", 'sin usar "tio" para dirigirse'. Esa palabra es el TEMA de la regla,
# y es lo unico que deja ver que dos frases escritas de forma distinta hablan de lo
# mismo. Se descarta lo de una letra, lo que son varias palabras (eso es una frase, no
# una forma de llamarle) y lo que ya esta en VACIAS ("si", "no", "vale").
RE_CITADA = re.compile("['\"‘’“”]([^'\"‘’“”]{2,20}?)['\"‘’“”]")


def citadas(texto):
    fuera = set()
    for trozo in RE_CITADA.findall(str(texto or "")):
        p = plano(trozo)
        if p and " " not in p and len(p) >= 2 and p not in VACIAS:
            fuera.add(p)
    return fuera


def texto_no_entra(texto):
    """Si este texto NO puede entrar en el cerebro. La regla, en un solo sitio.

    Son las tres de siempre, sin cambiar ni el orden: vacio o demasiado corto, sensible, o
    hablando de Nova en vez de hablar de braya (19/09).
    La saco fuera la idea 31 (26/09) para que el repaso de lo ya guardado use EXACTAMENTE la
    misma que la puerta de entrada. Dos copias de la misma regla acaban separandose.
    """
    t = limpio(texto, 300)
    if not t or len(t) < 8 or sensible(t):
        return True
    return bool(RE_SOBRE_NOVA.search(plano(t)))


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

    estilo_fuera = 0      # cuantas entradas de estilo tiro el repaso al cargar
    temas_juntados = 0    # cuantos temas eran el mismo escrito de otra forma (idea 94)
    recuerdos_fuera = 0   # y cuantos recuerdos aparto el repaso (negativo: no toco nada)
    aclaraciones_fuera = 0  # y cuantas 'respuestas' eran en realidad preguntas suyas

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
            # Y LO GUARDADO PASA POR LA REGLA (ver repasar_estilo): si no, una correccion
            # suya -"deja de llamarme tio"- solo se aplica a lo que llegue despues, y lo que
            # ya estaba contradiciendola sigue viajando en el prompt de todas las charlas.
            # el numero se guarda y lo dice el worker al arrancar: esta clase no tiene
            # canal de log propio, y un repaso que no se ve no se puede comprobar.
            try:
                self.estilo_fuera = self.repasar_estilo()
            except Exception:  # noqa: BLE001
                self.estilo_fuera = 0
            # Y LO MISMO CON LOS RECUERDOS (26/09, idea 31): la regla que decide que NO entra
            # tiene que valer tambien para lo que entro antes de escribirla.
            try:
                self.recuerdos_fuera = self.repasar_recuerdos()
            except Exception:  # noqa: BLE001
                self.recuerdos_fuera = 0
            # Y LAS QUE SE GUARDARON SIENDO PREGUNTAS (26/09, idea 33).
            try:
                self.aclaraciones_fuera = self.repasar_aclaraciones()
            except Exception:  # noqa: BLE001
                self.aclaraciones_fuera = 0
            # Y LOS TEMAS QUE SON EL MISMO ESCRITO DE OTRA FORMA (27/09, idea 94): videojuegos y
            # videojuego gastaban DOS de las cinco plazas del prompt de cada charla.
            try:
                self.temas_juntados = self.repasar_temas()
            except Exception:  # noqa: BLE001
                self.temas_juntados = 0
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
        # LA RAMA SEMANTICA NO PODIA DISPARAR NUNCA (24/09, idea 11 de la tanda nueva).
        #
        # Reproducidas las 328 preguntas reales del registro contra este mismo cerebro: UNA
        # pasa el liston por palabras (lex >= 0.8), y es exactamente el unico "memoria: lo se"
        # que hay en quince dias. O sea que el liston por palabras no fallo ni una vez.
        #
        # La rama de significado, en cambio, mide contra el pozo de respuestas firmes, y ese
        # pozo tiene DOS entradas. Embebidas 25 frases suyas de verdad, el parecido maximo
        # contra esas dos es 0,350 y la mediana 0,235, frente a un liston de 0,90/0,95. No es
        # que el liston este alto: es que no hay nada que encontrar. Bajarlo a 0,35 haria que
        # contestara "Escribir es plasmar palabras..." a cualquier cosa.
        #
        # Y era el UNICO sitio donde el modelo de significado se carga en un turno de charla:
        # 2,87 s, siempre en frio, para comparar contra dos vectores.
        #
        # El liston por palabras se queda igual. La otra funcion que usa el modelo -la de
        # "te acuerdas de..."- tampoco se toca: su liston (0,28) SI esta medido, del 23/09.
        if h["lex"] < 0.8:
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
        # UN SOLO SITIO PARA LOS DOS CAMINOS (26/09, idea 33): aqui llegan tanto aprender_turno
        # -donde lo de la API entra en firme- como aplicar_revision, o sea lo que el revisor da
        # por bueno. Poner la guarda en guardar_respuesta los cubre a los dos; un segundo filtro
        # en aplicar_revision seria la misma regla en dos sitios.
        if not pregunta or not respuesta or caduca(pregunta) or sensible(pregunta + " " + respuesta):
            return None
        if es_aclaracion(respuesta):
            return None      # eso no es una respuesta: es Nova pidiendo que le aclaren
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

    def guardar_texto(self, tipo, texto, dicho=""):
        """Lo que braya conto ('contado') o un recuerdo de lo hablado ('episodio').

        'dicho' (idea 58): la frase con la que braya lo dijo. El recuerdo lo escribe la API con
        SUS palabras y en tercera persona, braya con las suyas y en trozos, asi que la busqueda
        por palabras casi nunca lo encuentra (97 de 121 recuerdos no aparecen ni una vez en 365
        turnos). Se guarda como variante -lo que ya se hace con las respuestas, no con los
        episodios- para que buscar()/_formas la puntuen sin llamar a ningun modelo. Solo si tiene
        >= 3 palabras de contenido: una frase corta y generica ('no, no, no') como variante haria
        saltar el recuerdo con cualquier cosa (_frecuencias ya castiga las palabras muy repartidas)."""
        texto = limpio(texto, 300)
        # LA REGLA VIVE EN UN SOLO SITIO (26/09, idea 31). Estas tres condiciones estaban aqui
        # escritas a mano; ahora las comparte con repasar_recuerdos, que las aplica a lo que ya
        # estaba guardado. El dia que la regla cambie, cambia para los dos caminos.
        if texto_no_entra(texto):
            return None
        con_variante = bool(dicho) and len({t for t in fichas(dicho) if not t.startswith("?")}) >= 3
        with self.lock:
            for h in self.buscar(texto, tipos={tipo}, k=1):
                if h["lex"] >= 0.85:
                    if con_variante:
                        self._variante(h["r"], dicho)   # ya lo sabia, pero ahora tambien por tus palabras
                        self.guardar()
                    return h["r"]
            r = self._nuevo(tipo, texto, texto, "firme", "charla")
            if con_variante:
                self._variante(r, dicho)
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
                    # Y SIN TOCAR ultimo_id (21/09): esto corre en el hilo del revisor,
                    # de fondo y entre turnos. Lo que guarda aqui NO es "lo ultimo que
                    # Nova le dijo a braya", que es lo que significa ese campo y de lo
                    # que depende "eso no es verdad".
                    prevUlt = self.ultimo_id
                    r = self.guardar_respuesta(pg, buena, "firme", "revisada")
                    self.ultimo_id = prevUlt
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
                self.guardar_texto("contado", h, job.get("pregunta", ""))   # idea 58: tu frase, como variante
            if rev.get("recuerdo"):
                self.guardar_texto("episodio", rev.get("recuerdo"), job.get("pregunta", ""))
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
        # PODABA POR ANTIGUEDAD Y SE CONTRADECIA A SI MISMA (22/09). Caben 12 y se
        # tiraba la primera, o sea la mas vieja, sin mirar que era; y el filtro de
        # repetidas comparaba TEXTO EXACTO, asi que cada forma NUEVA de decir lo mismo
        # gastaba una plaza. Esto es lo que habia hoy en cerebro.json, y entero viaja
        # en el prompt de TODAS las charlas (contexto() lo mete sin condicion):
        #   "Prefiere tono casual y desenfadado (tuteo, 'man')"
        #   "No usar la palabra 'man' al dirigirse a el"
        #   "tono informal y de confianza ('tio')"
        #   "sin usar la palabra 'tio'" / "sin usar 'tio' para dirigirse"
        #   "evitar usar 'tio' para dirigirse" / "prefiere que no le digan 'tio'"
        # Cinco de las doce plazas para lo mismo, y al lado las DOS que dicen justo lo
        # contrario. A Nova se le pedia en la misma frase que le hablara con confianza
        # llamandole "tio" y que no le llamara "tio": asi no hay forma de acertar.
        # Dos reglas, sin contadores ni formato nuevo (la lista sigue siendo de textos):
        #  1. SI LO REPITE, SE RENUEVA. La entrada vieja se mueve al final en vez de
        #     ignorarse. Como la poda entra por el principio, "la primera" deja de
        #     querer decir "la mas vieja" y pasa a decir "la que lleva mas tiempo sin
        #     que el la repita", que es lo unico que aqui se parece a lo que le importa.
        #  2. LA ULTIMA PALABRA SOBRE UNA PALABRA GANA. Si la entrada nueva entrecomilla
        #     una palabra ("tio"), se van las viejas que la nombren. Una correccion de
        #     como llamarle no convive con la regla anterior sobre eso mismo: la
        #     sustituye, que para eso la esta corrigiendo.
        # Probado sobre las 12 de verdad: quedan 7, ninguna contradice a otra, y siguen
        # dentro las dos reglas que importan (la de "man" y la ultima de "tio").
        pe = plano(e)
        for i, x in enumerate(est):
            if plano(x) == pe:
                est.append(est.pop(i))
                return
        nuevas = citadas(e)
        if nuevas:
            est[:] = [x for x in est if not (nuevas & set(plano(x).split()))]
        est.append(e)
        while len(est) > MAX_ESTILO:
            est.pop(0)

    def repasar_estilo(self):
        """Pasa la regla de _estilo por lo que YA estaba guardado, no solo por lo que llega.

        EL CASO DE VERDAD (22/09 por la noche, idea 5). braya le pidio TRES veces que dejara
        de llamarle "tio" y "man" (20/09 23:05:26, 20/09 23:19:17, 21/09 00:02:56), y Nova
        prometio dos veces que no lo haria. Dos dias despues, el 22/09 a las 21:48:35: "No te
        sigo, tio". En cerebro.json habia 12 entradas de estilo, y DOS de ellas decian lo
        contrario de lo que el habia pedido -"prefiere tono casual y desenfadado (tuteo,
        'man')" y "tono informal y de confianza ('tio')"-. Las 12 viajan juntas en el prompt
        de todas sus charlas, asi que la contradiccion iba dentro en cada peticion.

        La regla que lo resuelve -la ultima palabra sobre una palabra gana- se escribio ese
        mismo dia, pero vive dentro de _estilo, y _estilo solo corre cuando llega una entrada
        NUEVA. Lo que ya estaba en disco no lo repasaba nadie: cargar() hace json.load y
        update, y nada mas. Una regla que solo mira lo que entra deja armado para siempre lo
        que entro antes de escribirla.

        Se reutiliza _estilo entera a proposito, en vez de copiar su logica: asi la regla vive
        en un solo sitio y el dia que cambie, cambia para los dos caminos. De paso pasa tambien
        el filtro de datos sensibles y el de "no guardes lo que habla de mi", que las entradas
        viejas tampoco habian visto nunca.
        """
        viejas = list(self.datos.get("estilo", []))
        if not viejas:
            return 0
        self.datos["estilo"] = []
        for e in viejas:
            self._estilo(e)
        return len(viejas) - len(self.datos.get("estilo", []))

    def repasar_temas(self):
        """Junta los temas YA guardados que son el mismo escrito de otra forma.

        Igual que repasar_estilo, repasar_recuerdos y repasar_aclaraciones: una regla que solo
        mira lo que entra deja armado para siempre lo que entro antes de escribirla. Aqui el dano
        es concreto y medible: videojuegos (63) y videojuego (10) ocupaban DOS de las cinco plazas
        del prompt de cada charla, y roblox (6) se quedaba fuera por eso.

        Se reutiliza clave_tema, la misma que usa _tema, para que la regla viva en un solo sitio.
        El nombre que queda es el de la forma MAS CONTADA del grupo, y las cuentas se suman.
        Devuelve cuantos temas desaparecieron por juntarse; el worker lo dice al arrancar, que un
        repaso que no se ve no se puede comprobar.
        """
        temas = self.datos.get("temas") or {}
        if not temas:
            return 0
        grupos = {}
        for nombre, veces in temas.items():
            k = clave_tema(nombre)
            grupos.setdefault(k, []).append((nombre, veces))
        nuevos = {}
        for formas in grupos.values():
            # el mas contado da el nombre; con empate, el mas corto, para que sea estable
            formas.sort(key=lambda nv: (-nv[1], len(nv[0])))
            nuevos[formas[0][0]] = sum(v for _, v in formas)
        self.datos["temas"] = nuevos
        return len(temas) - len(nuevos)

    def repasar_aclaraciones(self):
        """Aparta las respuestas guardadas que en realidad eran peticiones de aclaracion.

        Igual que repasar_estilo y repasar_recuerdos: una regla que solo mira lo que entra deja
        armado para siempre lo que entro antes de escribirla. En el cerebro de hoy hay UNA, el
        recuerdo 117, y NO se escribe su id a mano: se cae sola con la regla, que es lo que hay
        que arreglar.
        """
        fuera = 0
        for r in (self.datos.get("recuerdos") or []):
            if r.get("tipo") != "respuesta" or r.get("estado") == "rechazada":
                continue
            if not es_aclaracion(r.get("respuesta", "")):
                continue
            r["estado"] = "rechazada"
            r["repasado"] = time.time()
            fuera += 1
        return fuera

    def repasar_recuerdos(self):
        r"""Pasa la regla de entrada por los recuerdos que YA estaban guardados.

        EL CASO, contado sobre memoria\cerebro\cerebro.json: de los 121 recuerdos, TREINTA Y
        SEIS hablan de Nova y no de braya -el 29,75 %-, y los 36 estan en estado "firme", o sea
        que entran en las busquedas y viajan en el contexto de las charlas. Son todos del 15/09
        (20) y del 18/09 (16): cero del 19/09 en adelante, que es cuando se escribio el filtro
        RE_SOBRE_NOVA. La regla se escribio y solo miro lo que llegaba despues.
        Es el mismo agujero que repasar_estilo arreglo para el estilo, y se arregla igual.

        NO SE BORRA NADA: se marcan como "rechazada", que es un estado que buscar() ya salta y
        que se puede deshacer. La lista sigue teniendo los 121.

        SOLO contado Y episodio, y SOLO el campo "respuesta". Los de tipo "respuesta" nunca
        pasaron por este filtro y no tienen que pasar ahora: una respuesta de trivia con "nova"
        en la pregunta es legitima. Y ni "pregunta" ni "variantes", que guardan la frase literal
        de braya: el "oye nova" de "oye nova, quien pinto la mona lisa" tacharia un recuerdo
        bueno.
        """
        recuerdos = self.datos.get("recuerdos") or []
        candidatos = [r for r in recuerdos
                      if r.get("tipo") in ("contado", "episodio") and r.get("estado") != "rechazada"]
        if not candidatos:
            return 0
        fuera = [r for r in candidatos if texto_no_entra(r.get("respuesta", ""))]
        if not fuera:
            return 0
        # EL DISYUNTOR: si el filtro se come mas de la mitad, no se toca nada y se dice.
        if len(fuera) > TOPE_REPASO_RECUERDOS * len(candidatos):
            return -len(fuera)
        for r in fuera:
            r["estado"] = "rechazada"
            r["repasado"] = time.time()
        # NO HACE FALTA INVALIDAR NINGUN CACHE, y conviene decirlo porque parece que si:
        # _cambio tira _df y el cache de fichas por id, y ninguno de los dos depende del
        # estado. _frecuencias recorre TODOS los recuerdos sea cual sea su estado, y _formas
        # solo mira pregunta y variantes, que aqui no se tocan. Quien respeta el "rechazada"
        # es buscar(), que lo mira en cada vuelta.
        return len(fuera)

    def _tema(self, t):
        t = plano(t)[:30]
        if not t or len(t.split()) > 3:
            return
        # y los temas tampoco: "nova" o "el asistente" como tema de conversacion acaba
        # metiendose en el prompt igual que el estilo (ver el comentario de _estilo)
        if RE_SOBRE_NOVA.search(t):
            return
        temas = self.datos.setdefault("temas", {})
        # POR RAICES, NO POR TEXTO EXACTO (27/09, idea 94): ver clave_tema. Si ya hay un tema con
        # las mismas raices, esto suma AHI en vez de abrir una plaza nueva para la misma cosa.
        # EL NOMBRE VISIBLE NO SE CAMBIA: se queda el del grupo, que al fusionar los guardados es
        # el de la forma mas contada ("videojuegos", 63, no "videojuego", 10). Cual de las dos
        # formas viaje al prompt da igual; lo que importaba era no gastar dos plazas.
        k = clave_tema(t)
        for otro in temas:
            if clave_tema(otro) == k:
                t = otro
                break
        temas[t] = temas.get(t, 0) + 1
        if len(temas) > MAX_TEMAS:
            for k, _ in sorted(temas.items(), key=lambda kv: kv[1])[:len(temas) - MAX_TEMAS]:
                del temas[k]

    def marcar_incorrecta(self, idr=None):
        """ "Eso no es verdad": la respuesta que se acaba de decir no se usa mas.

        EL id VIENE DE FUERA DESDE EL 21/09, y self.ultimo_id queda solo de respaldo.
        Antes esto se fiaba de ultimo_id, que es estado global y lo escribe TAMBIEN el
        hilo del revisor por detras, entre turnos: braya preguntaba "quien hizo Hollow
        Knight", el revisor terminaba un pendiente viejo mientras el escuchaba la
        respuesta, ultimo_id pasaba a ser OTRO recuerdo, y "no, eso no es verdad"
        rechazaba ese otro. El malo se quedaba firme y uno bueno se marcaba como falso:
        los dos errores a la vez, y ninguno se ve hasta mucho despues.
        """
        with self.lock:
            r = self._por_id(idr if idr is not None else self.ultimo_id)
            if r is None or r.get("tipo") != "respuesta":
                return None
            r["estado"] = "rechazada"
            # Y SU TRABAJO PENDIENTE, FUERA (26/09, idea 11 de las 121). Tachar el recuerdo y
            # dejar vivo su job es medio arreglo: el revisor de fondo lo coge mas tarde, lo da
            # por bueno y lo vuelve a dejar firme. El job apunta al recuerdo por "recuerdo",
            # no por "id" (ver aprender_turno), asi que hay que filtrar por ese campo.
            idm = r.get("id")
            self.datos["pendientes"] = [j for j in self.datos.get("pendientes", [])
                                        if j.get("recuerdo") != idm]
            self._cambio(r)
            self.guardar()
            return dict(r)

    def corregir_respuesta(self, idr, malo, bueno):
        """ "No es X, es Y": cambia esa palabra en la respuesta guardada, en vez de tirarla.

        MEDIDO (26/09): de las 61 correcciones habladas de catorce dias, SOLO UNA trae un par
        malo/bueno con la palabra mala DENTRO de lo que Nova acababa de decir. Las otras
        sesenta corrigen algo que Nova no habia dicho con esas palabras y se van a tachar, que
        es el camino de marcar_incorrecta. O sea que esto no es lo que salva la idea -eso es
        tachar-, pero sale casi gratis porque el patron ya existe en el asistente.

        LA GUARDA QUE MANDA, portada de Get-OrdenCorregida (assistant.ps1): si la palabra mala
        NO aparece en la respuesta guardada, no se toca nada. Es lo unico que separa corregir
        de inventar: sin ella, "no es azul, es verde" reescribiria cualquier recuerdo que
        estuviera encima, dijera lo que dijera.
        """
        if not idr or not malo or not bueno:
            return None
        with self.lock:
            r = self._por_id(idr)
            if r is None or r.get("tipo") != "respuesta":
                return None
            # lo ya tachado no se resucita
            if r.get("estado") == "rechazada":
                return None
            vieja = r.get("respuesta") or ""
            if not re.search(r"\b" + re.escape(plano(malo)) + r"\b", plano(vieja)):
                return None
            nueva = re.sub(r"(?i)\b" + re.escape(malo) + r"\b", bueno, vieja)
            nueva = limpio(nueva, 600)
            if not nueva or nueva == vieja:
                return None
            # lo que no debe guardarse sigue sin guardarse, tambien por aqui
            if sensible((r.get("pregunta") or "") + " " + nueva):
                return None
            r["respuesta"] = nueva
            r["estado"] = "firme"
            r["revisada"] = self.reloj()
            idm = r.get("id")
            self.datos["pendientes"] = [j for j in self.datos.get("pendientes", [])
                                        if j.get("recuerdo") != idm]
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


    def agujeros(self, dias=7):
        """LEER EL FICHERO DE LO IMPORTANTE (27/09, idea 79). Desde el 25/09 se copia a
        importante.jsonl cada turno en que braya corrige y cada turno en que Nova admite que no sabe
        algo. Se escribia en modo 'a' y NO LO LEIA NADIE: es el inventario de sus agujeros y estaba
        muerto en el disco (518 bytes, cero lectores en todo el repositorio fuera de dos bancos).

        Aqui se leen las lineas por='agujero' de los ultimos 'dias' y se juntan las que son lo mismo
        -por las palabras de contenido, con el mismo fichas() que usa el resto de la memoria-. No se
        llama a ningun modelo: es leer un jsonl y contar.

        SOLO LECTURA: este camino no poda ni reescribe el fichero. Devuelve
        {"total": n, "grupos": [{"veces": n, "frase": "...", "dias": [..]}, ...]}, los grupos
        ordenados por veces. La prueba de si un agujero es FALSO -algo que Nova si sabe- no se hace
        aqui: la hace el asistente, que es quien tiene el resolvedor de ordenes."""
        ruta = os.path.join(self.carpeta, "importante.jsonl")
        if not os.path.exists(ruta):
            return {"total": 0, "grupos": []}
        corte = time.strftime("%Y-%m-%d", time.localtime(self.reloj() - dias * 86400))
        lineas = []
        try:
            with open(ruta, encoding="utf-8") as f:
                for linea in f:
                    linea = linea.strip()
                    if not linea:
                        continue
                    try:
                        d = json.loads(linea)
                    except ValueError:
                        continue
                    if (d.get("por") or "") != "agujero":
                        continue
                    if (d.get("d") or "") < corte:
                        continue
                    lineas.append(d)
        except Exception:
            return {"total": 0, "grupos": []}
        grupos = []
        for d in lineas:
            pregunta = (d.get("braya") or "").strip()
            if not pregunta:
                continue
            f = frozenset(t for t in fichas(pregunta) if not t.startswith("?"))
            puesto = False
            for g in grupos:
                # la mitad de las palabras en comun ya es "lo mismo preguntado de otra forma"
                if f and g["fichas"] and len(f & g["fichas"]) >= max(1, min(len(f), len(g["fichas"])) / 2.0):
                    g["veces"] += 1
                    if d.get("d") not in g["dias"]:
                        g["dias"].append(d.get("d"))
                    puesto = True
                    break
            if not puesto:
                grupos.append({"veces": 1, "frase": pregunta[:120], "fichas": f, "dias": [d.get("d")]})
        grupos.sort(key=lambda g: g["veces"], reverse=True)
        for g in grupos:
            del g["fichas"]      # no viaja: es un set y el json no lo quiere
        return {"total": len(lineas), "grupos": grupos}
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
