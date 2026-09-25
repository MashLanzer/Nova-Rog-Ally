# Worker de CONVERSACION de Nova (13/09): hibrido, sin Claude Code, y con su
# propio CEREBRO (charla_memoria.py) que aprende de todo lo que se habla.
#
# No hay "modo conversacion": el asistente le pasa lo que dices cuando no es una
# orden que ya sabe hacer. Aqui se decide si era charla (se contesta), algo que
# hay que HACER (se devuelve al asistente) o algo que pide internet (la API).
#
# Se mantiene VIVO (como tts_worker) y lee pedidos JSON de stdin, uno por linea:
#   {"op": "hablar", "id": 3, "texto": "...", "juego": "Hades", "invitado": false, "duda": false}
#   {"op": "parar"}                         corta la respuesta en curso
#   {"op": "olvidar"}                       borra lo hablado (no lo aprendido)
#   {"op": "apunta", "texto": "...", "hecho": "..."}   deja en el hilo una orden
#   {"op": "olvidar_tema", "texto": "..."}  borra lo aprendido sobre algo
#   {"op": "descargar"}                     saca los modelos de la RAM (al jugar)
# Escribe por stdout un JSON por linea, SOLO ASCII (los acentos van escapados:
# PowerShell lee la salida con la codificacion de la consola y los romperia):
#   {"ev": "frase", "id": 3, "texto": "..."}   una frase lista para decir
#   {"ev": "fin", "id": 3, "origen": "local"}  termino (memoria | local | api | parado)
#   {"ev": "orden", "id": 3, "texto": "..."}   no era charla: hay que hacerlo
#   {"ev": "err", "id": 3, "texto": "..."}     no pudo contestar
#   {"ev": "dato", "texto": "..."}             algo sobre braya para su perfil
#   {"ev": "correccion", "texto": "..."}       lo que Nova dijo mal, ya corregido
#   {"ev": "info", "texto": "..."}             para el log
#
# ORDEN: 1) el CEREBRO: si ya lo sabe de verdad (firme y la misma pregunta), lo
# dice sin preguntar a nadie. 2) el LOCAL (Ollama con Qwen2.5 3B), con lo
# aprendido delante como contexto. 3) la API de Claude si el local no puede, si
# dice que la pregunta le queda grande ("[API]") o si pide internet (con
# busqueda web). Si la API falla, vuelve al local.
# Despues de contestar, se APRENDE: lo de la API firme; lo del local provisional,
# y la API lo revisa en segundo plano cuando no se esta hablando (ver
# charla_memoria.py: ahi estan las reglas para no quedarse con datos malos).
#
# POCA RAM (lo pidio braya): contexto de 1536, los modelos se descargan solos a
# los 2 min sin hablar, y el asistente los descarga al abrir un juego.
#
# Uso:  python charla_worker.py <modelo_local> <modelo_api> <modelo_embeddings|-> <carpeta_cerebro> <perfil.md>
# <carpeta_cerebro> es OBLIGATORIA: sin ella el worker habla igual, pero no escribe
# nada (ni diario, ni resumen, ni cerebro). Ver LA CARPETA SE DICE, NO SE ADIVINA.

import sys
import os
import re
import json
import time
import queue
import threading

import httpx
import atexit

# UN CLIENTE PARA LA API, NO UNO POR LLAMADA (18/09). El saludo TCP+TLS a api.anthropic.com
# tiene mediana 61,5 ms desde esta maquina (TCP 22-42 + TLS 21-25), y desde que la API va
# primero eso se paga EN CADA RESPUESTA HABLADA -dos veces si la charla reescribe una orden-.
# Reutilizando el cliente, ese saludo se hace UNA vez y las demas van por la conexion abierta.
# Solo para la API: las llamadas a Ollama son locales y sin TLS, ahi no hay saludo que ahorrar
# y no merece la pena tocar el camino de la charla por nada.
_api = httpx.Client(timeout=httpx.Timeout(30.0, connect=5.0))
atexit.register(_api.close)

import charla_memoria as cm

OLLAMA = "http://127.0.0.1:11434"
MODELO_LOCAL = sys.argv[1] if len(sys.argv) > 1 else "qwen2.5:3b"
MODELO_API = sys.argv[2] if len(sys.argv) > 2 else "claude-haiku-4-5"
MODELO_EMBED = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] not in ("", "-") else ""
# LA CARPETA SE DICE, NO SE ADIVINA (19/09). Hasta hoy, sin argv[4] esto apuntaba a
# memoria\cerebro: la memoria DE VERDAD de braya. Por esa puerta el banco de pruebas le
# metio recuerdos falsos -los osos polares y Hades acabaron en memoria\diario-: el
# 17/09 el diario real tenia 574 lineas, el 100 % repetidas, o sea 41 pasadas del banco
# con Nova apagada (REVISION-2026-09-18.md:81-95). Ahora, si nadie dice la carpeta, no
# hay carpeta, y quien no la diga no escribe. Nova no se entera: assistant.ps1 se la
# pasa siempre (Start-Charla, `"$CerebroDir`").
CARPETA_CEREBRO = sys.argv[4] if len(sys.argv) > 4 else ""
RUTA_PERFIL = sys.argv[5] if len(sys.argv) > 5 else ""
ESPERA_TROZO = 25.0        # s maximos entre trozos del local (en frio carga el modelo)
MAX_HISTORIAL = 12         # mensajes (6 idas y vueltas)
OLVIDO_S = 300             # tras 5 min sin hablar, la charla empieza de cero (lo aprendido no)
MIN_FRASE = 25             # letras: las frases muy cortas se juntan con la siguiente
MAX_FRASE = 200
# LA PRIMERA FRASE, ANTES (14/09): en vivo el modelo local contesto con UNA frase de
# 140 letras y la voz no empezo hasta tenerla entera. Si la primera pasa de esto sin
# punto, se corta en su ultima coma: la voz arranca con medio segundo de ventaja.
PRIMERA_MAX = 90
MARCA_API = "[API]"
MARCA_ORDEN = "[ORDEN]"

SISTEMA = (
    "Eres Nova, la asistente de voz de braya en su consola ROG Ally. Hablas en español, "
    "de tú a tú, como una amiga cercana y con chispa. Todo lo que escribes se dice en voz "
    "alta: frases cortas y naturales, sin listas, sin asteriscos, sin emojis ni formato. "
    "Responde SIEMPRE y solo en español, nunca en chino ni en otro idioma. "
    "Contesta en una a tres frases, salvo que te pida más. Si viene a cuento, termina con "
    "una pregunta para seguir la conversación. Si no sabes algo con seguridad, dilo."
)
SISTEMA_ORDEN = (
    " Si braya te pide que HAGAS algo en su consola o en Windows (abrir o cerrar programas "
    "o juegos, instalar, buscar o mover archivos, cambiar ajustes, escribir en una ventana), "
    "no lo expliques ni digas que no puedes: responde SOLO, exactamente: [ORDEN]\n"
    "También si te lo pide quejándose, repitiéndolo o en mitad de la conversación: no te "
    "disculpes ni prometas hacerlo, porque hablando no puedes hacerlo; responde [ORDEN] y "
    "Nova lo hace. [ORDEN] va solo, sin ninguna frase delante.\n"
    "Lo mismo si te pregunta por algo de su consola que Nova puede mirar (la hora, la batería, "
    "las descargas de Steam, el espacio libre, qué está sonando, a qué está jugando, el tiempo o el clima): [ORDEN].\n"
    "Ejemplos: 'abre la carpeta de descargas' -> [ORDEN]. 'instálame Discord' -> [ORDEN]. "
    "'¿en cuánto está la descarga de Steam?' -> [ORDEN]. "
    "'¿por qué no abriste Steam? ábrelo ya' -> [ORDEN]. 'pon música de Pitbull en YouTube' -> [ORDEN]. "
    "'¿qué opinas de Hades?' -> contestas tú con normalidad."
)
SISTEMA_API = (
    " Si para contestar bien necesitas datos de internet o de hoy (noticias, precios, "
    "resultados, estrenos) o la pregunta es muy difícil o técnica, responde SOLO, "
    "exactamente: [API]"
)

RE_NECESITA_API = re.compile(
    r"\b(noticias?|precio|cu[aá]nto cuesta|cotizaci[oó]n|resultados?|qui[eé]n gan[oó]|"
    r"estreno|b[uú]scame|busca en internet|en internet)\b", re.IGNORECASE)
EMOJI = re.compile("[\U0001F000-\U0001FFFF☀-➿️]")
# Qwen se pasa al CHINO a veces a mitad de frase (probado en vivo el 13/09: un
# chiste acabo en "因为他们找不到巢"). En cuanto aparece, se corta ahi.
CJK = re.compile("[぀-ヿ㐀-䶿一-鿿가-힯＀-￯]")

# NUNCA UNA CLAVE EN EL LOG: los errores de httpx llevan la cabecera dentro (visto
# el 13/09: "Illegal header value b'sk-ant-...'" acabo en la salida entera).
RE_SECRETO = re.compile(r"sk-ant-[A-Za-z0-9_\-]+", re.IGNORECASE)


def seguro(texto):
    return RE_SECRETO.sub("[clave oculta]", str(texto))


def clave_api():
    # la variable de entorno venia con un salto de linea al final y httpx la
    # rechazaba como cabecera: la API no funcionaba nunca
    return (os.environ.get("ANTHROPIC_API_KEY") or "").strip()


historial = []
pedidos = queue.Queue()
parar = threading.Event()
# JUGANDO, EL REVISOR SE CALLA (17/09). No vale reutilizar 'parar': ese se activa en CADA
# frase para cortar la respuesta en curso. Este es suyo: se pone cuando el asistente pide
# 'descargar' (lo hace al abrir un juego) y se quita en la siguiente charla.
revisor_parado = threading.Event()
revisor_hay_trabajo = threading.Event()
ocupado = threading.Event()     # contestando: la revision en segundo plano espera
api_rota_hasta = 0.0
ultima_charla = 0.0
bloqueo_salida = threading.Lock()
cerebro = None                  # se crea en principal(); las pruebas ponen el suyo
_perfil = {"mtime": None, "lineas": []}
# el liston de "me acuerdo de eso", medido contra su memoria real (ver op recordar)
LISTON_RECUERDO = 0.28
trivia = {"r": None, "hasta": 0.0, "hechas": []}     # la pregunta de trivia que espera respuesta
# LO ULTIMO QUE NOVA DIJO DE VERDAD (21/09), para que "eso no es verdad" rechace ESO.
# No vale cerebro.ultimo_id: lo escribe tambien el hilo del revisor, de fondo y entre
# turnos, asi que podia apuntar a un recuerdo que braya no ha oido en su vida.
ultimo_dicho = None
# lo que hace que una orden no se entienda suelta: pronombres pegados ("recuerdamelo",
# "bajalo") o palabras que remiten a lo hablado
RE_DEIXIS = re.compile(r"\b(\w{2,}(?:me|te|se)?(?:lo|la|los|las|le|les)|eso|esto|esa|ese|ahi|alli|luego|despues)\b")
RE_RENDIDO = re.compile(r"\b(no se|ni idea|me rindo|dimelo|dime la respuesta|cual es la respuesta)\b")


def salida(ev, idp=0, **campos):
    d = {"ev": ev, "id": idp}
    d.update({k: (seguro(v) if isinstance(v, str) else v) for k, v in campos.items()})
    with bloqueo_salida:
        sys.stdout.write(json.dumps(d, ensure_ascii=True) + "\n")
        sys.stdout.flush()


def limpiar(t):
    t = EMOJI.sub("", t)
    t = CJK.sub("", t)
    t = re.sub(r"\[[^\]]{0,60}\]", "", t)     # etiquetas sueltas: no se leen en voz alta
    t = re.sub(r"[*_#`>]+", "", t)
    t = re.sub(r"^\s*[-•]\s+", "", t, flags=re.M)
    return re.sub(r"\s+", " ", t).strip()


def necesita_api(texto):
    return bool(RE_NECESITA_API.search(texto))


# DATOS CONCRETOS, A LA API (14/09). Medido con 10 preguntas sobre juegos: el modelo
# local (3B) se inventa quien hizo que, de que va o de que genero es ("Hades es un
# juego de terror", "Peak es de estrategia", "Little Nightmares es para ninos"), y
# pedirselo en el prompt no lo arreglo. Estas preguntas van a la API (sin busqueda:
# no son de actualidad) y lo que conteste se aprende firme para la proxima vez.
RE_PIDE_DATOS = re.compile(
    r"\b(de qu[eé] (va|trata)|qui[eé]n (hizo|cre[oó]|invent[oó]|escribi[oó]|dirigi[oó]|desarroll[oó]|compuso|canta)|"
    r"cu[aá]ndo (sali[oó]|naci[oó]|se estren[oó]|se fund[oó]|muri[oó])|h[aá]blame (un poco |algo )?(de|sobre)|qu[eé] sabes (de|sobre)|"
    r"cu[eé]ntame (algo |un poco )?(de|sobre)|qu[eé] opinas (de|sobre)|qu[eé] te parece)\b", re.IGNORECASE)


def pide_datos(texto):
    return bool(RE_PIDE_DATOS.search(texto))


class Troceador:
    """Parte el texto que llega a trozos en frases, para decirlas en cuanto estan."""

    def __init__(self):
        self.buf = ""
        self.salio = False

    def meter(self, trozo):
        self.buf += trozo
        salen = []
        while True:
            corte = None
            for m in re.finditer(r"[.!?…]+(?=\s)|\n+", self.buf):
                if len(self.buf[:m.end()].strip()) >= MIN_FRASE:
                    corte = m.end()
                    break
            if corte is None and not self.salio and len(self.buf) > PRIMERA_MAX:
                i = self.buf.rfind(", ")
                if i >= 40:
                    corte = i + 2
            if corte is None and len(self.buf) > MAX_FRASE:
                i = max(self.buf.rfind(", ", 0, MAX_FRASE), self.buf.rfind(" ", 0, MAX_FRASE))
                corte = i + 1 if i > 40 else MAX_FRASE
            if corte is None:
                break
            f = limpiar(self.buf[:corte])
            self.buf = self.buf[corte:]
            if f:
                salen.append(f)
                self.salio = True
        return salen

    def cerrar(self):
        f = limpiar(self.buf)
        self.buf = ""
        return [f] if f else []


class Inicio:
    """El principio de la respuesta puede ser una MARCA ([ORDEN], [API]): hasta
    saber que no lo es, no se dice nada.

    Un modelo de 3B no siempre escribe la marca exacta: probado con Qwen2.5 3B,
    "abre la carpeta de descargas" dio "[ABRIR LA CARPETA DE DESCARGAS] ...". Por
    eso CUALQUIER etiqueta entre corchetes al empezar cuenta: la que dice API es
    la API; cualquier otra, una orden."""

    def __init__(self, marcas):
        self.marcas = marcas
        self.texto = ""
        self.decidido = not marcas

    def _etiqueta(self, etiqueta):
        if "API" in etiqueta.upper() and MARCA_API in self.marcas:
            return MARCA_API
        if MARCA_ORDEN in self.marcas:
            return MARCA_ORDEN
        return None

    def meter(self, trozo):
        self.texto += trozo
        if self.decidido:
            return "sigue", trozo
        s = self.texto.lstrip()
        if s.startswith("["):
            cierre = s.find("]")
            if cierre < 0:
                if len(s) < 60:
                    return "espera", ""       # aun puede ser una marca
                self.decidido = True
                return "sigue", s
            m = self._etiqueta(s[:cierre + 1])
            if m:
                return "marca", m
            self.decidido = True              # etiqueta que aqui no vale: se quita
            return "sigue", s[cierre + 1:]
        self.decidido = True
        return "sigue", self.texto

    def final(self):
        if self.decidido:
            return "sigue", ""
        s = self.texto.strip()
        if s.startswith("[") and len(s) > 1:   # "[ORDEN" sin cerrar tambien vale
            m = self._etiqueta(s)
            if m:
                return "marca", m
        self.decidido = True
        return "sigue", s.lstrip("[")


def recortar():
    while len(historial) > MAX_HISTORIAL:
        del historial[0]
    # la API exige que empiece por el usuario
    while historial and historial[0]["role"] != "user":
        del historial[0]


def api_disponible():
    return bool(clave_api()) and time.time() >= api_rota_hasta


def sistema_con(extra, marcas):
    # LO FIJO DELANTE Y LO QUE CAMBIA AL FINAL (14/09): Ollama reutiliza lo ya leido
    # si el principio del prompt coincide. Con el perfil y el contexto en medio, cada
    # peticion rompia la coincidencia y en frio se releian ~320 tokens (6,9 s). La
    # precarga (calentar) lee esta parte fija por adelantado: tras ella, la primera
    # frase llega en 2,2 s en vez de 13,9 s. Medido: el orden no cambia las marcas.
    s = SISTEMA
    if MARCA_ORDEN in marcas:
        s += SISTEMA_ORDEN
    if MARCA_API in marcas:
        s += SISTEMA_API
    return s + extra


PERFIL_AL_MODELO = 15
# Palabras que no distinguen nada: si contaran, "como se llama mi mascota" se parece a todo.
PERFIL_VACIAS = set("""el la los las de del en un una unos unas que y a por con no si me te se lo le al es
    esta como cual cuales cuando donde cuanto cuanta mi tu su para ya hay o u lo que quien mas menos muy
    sus mis tus ser soy eres son era fue hace tiene tengo tienes""".split())


def _palabras(t):
    import re as _re
    t = (t or "").lower()
    for a, b in (("\u00e1", "a"), ("\u00e9", "e"), ("\u00ed", "i"), ("\u00f3", "o"), ("\u00fa", "u"), ("\u00fc", "u"), ("\u00f1", "n")):
        t = t.replace(a, b)
    return set(p for p in _re.split(r"[^a-z0-9]+", t) if len(p) > 2 and p not in PERFIL_VACIAS)


def perfil_para(texto, lineas, tope=None):
    """Los datos del perfil que vienen a cuento de lo que braya acaba de decir.

    HASTA HOY SE MANDABAN LOS QUINCE ULTIMOS, y por eso Nova dijo no saber el nombre de la
    mascota de braya teniendolo escrito en la linea 27 de 60: el 27 no esta entre los quince
    ultimos. Ahora los que comparten palabras con la pregunta van primero, y el resto se
    rellena con los mas recientes, que es lo que se hacia antes.

    No hace falta un modelo de vectores para esto: comparar palabras cuesta microsegundos y
    resuelve el caso que fallaba, que es preguntar POR algo que esta escrito.
    """
    tope = tope or PERFIL_AL_MODELO
    if not lineas:
        return []
    if len(lineas) <= tope:
        return list(lineas)
    q = _palabras(texto)
    if not q:
        return list(lineas[-tope:])
    tocan = []
    for i, l in enumerate(lineas):
        comunes = len(q & _palabras(l))
        if comunes:
            # a igualdad de palabras comunes, el mas reciente primero
            tocan.append((comunes, i, l))
    tocan.sort(key=lambda x: (-x[0], -x[1]))
    fuera = [l for _, _, l in tocan[:tope]]
    # y se rellena con los ultimos, sin repetir
    for l in reversed(lineas):
        if len(fuera) >= tope:
            break
        if l not in fuera:
            fuera.append(l)
    # se devuelven en el orden del perfil, que es como estaban antes
    return [l for l in lineas if l in fuera]


def datos_perfil():
    """Lo que el perfil de siempre sabe de braya (memoria\\perfil.md), cacheado."""
    if not RUTA_PERFIL or not os.path.exists(RUTA_PERFIL):
        return []
    try:
        m = os.path.getmtime(RUTA_PERFIL)
        if _perfil["mtime"] != m:
            with open(RUTA_PERFIL, encoding="utf-8-sig") as f:
                lineas = [re.sub(r"^\s*-\s+", "", l).strip() for l in f if re.match(r"^\s*-\s+\S", l)]
            _perfil.update(mtime=m, lineas=lineas)
    except OSError:
        return []
    return _perfil["lineas"]


def generar_local(mensajes, marcas, emitir, extra=""):
    cuerpo = {
        "model": MODELO_LOCAL,
        "messages": [{"role": "system", "content": sistema_con(extra, marcas)}] + mensajes,
        "stream": True,
        "keep_alive": "2m",
        # 0.5: con 0.7 el 3B se inventaba datos con demasiada soltura. 1536: cabe
        # lo aprendido que se le pone delante sin gastar apenas mas RAM
        "options": {"num_predict": 200, "temperature": 0.5, "num_ctx": 1536},
    }
    texto = ""
    troc = Troceador()
    ini = Inicio(marcas)
    try:
        with httpx.stream("POST", OLLAMA + "/api/chat", json=cuerpo,
                          timeout=httpx.Timeout(ESPERA_TROZO, connect=2.0)) as r:
            if r.status_code != 200:
                return "fallo", "ollama respondio %d" % r.status_code
            for linea in r.iter_lines():
                if parar.is_set():
                    return "parado", texto
                if not linea:
                    continue
                try:
                    d = json.loads(linea)
                except ValueError:
                    continue
                trozo = (d.get("message") or {}).get("content") or ""
                m_cjk = CJK.search(trozo)
                if m_cjk:
                    # se queda con lo de antes del cambio de idioma y deja de generar
                    trozo = trozo[:m_cjk.start()]
                    texto += trozo
                    estado, t = ini.meter(trozo)
                    if estado == "marca":
                        return "marca", t
                    if estado == "sigue":
                        for f in troc.meter(t):
                            emitir(f)
                    texto = CJK.sub("", texto)
                    break
                if trozo:
                    texto += trozo
                    estado, t = ini.meter(trozo)
                    if estado == "marca":
                        return "marca", t
                    if estado == "sigue":
                        for f in troc.meter(t):
                            emitir(f)
                if d.get("done"):
                    break
    except (httpx.ConnectError, httpx.ConnectTimeout):
        return "fallo", "ollama no esta en marcha"
    except httpx.ReadTimeout:
        return "fallo", "ollama tardo demasiado"
    except Exception as e:  # noqa: BLE001
        return "fallo", "ollama: %s" % e
    estado, t = ini.final()
    if estado == "marca":
        return "marca", t
    for f in troc.meter(t) + troc.cerrar():
        emitir(f)
    return ("ok", texto) if texto.strip() else ("fallo", "respuesta vacia")


def _cabeceras():
    return {"x-api-key": clave_api(), "anthropic-version": "2023-06-01",
            "content-type": "application/json"}


def _api_rota_si(err):
    global api_rota_hasta
    # sin saldo o clave mala: no se reintenta en 10 min (cada intento cuesta segundos)
    if re.search(r"credit|billing|authentication|x-api-key|permission", err or "", re.IGNORECASE):
        api_rota_hasta = time.time() + 600


def generar_api(mensajes, marcas, emitir, extra="", buscar=False):
    if not clave_api():
        return "fallo", "sin clave de la API"
    cuerpo = {"model": MODELO_API, "max_tokens": 400, "system": sistema_con(extra, marcas),
              "messages": mensajes, "stream": True}
    if buscar:
        cuerpo["tools"] = [{"type": "web_search_20250305", "name": "web_search", "max_uses": 2}]
    texto = ""
    troc = Troceador()
    ini = Inicio(marcas)
    try:
        with _api.stream("POST", "https://api.anthropic.com/v1/messages", json=cuerpo, headers=_cabeceras()) as r:
            if r.status_code != 200:
                err = r.read().decode("utf-8", "replace")
                _api_rota_si(err)
                return "fallo", "api %d: %s" % (r.status_code, re.sub(r"\s+", " ", err)[:200])
            for linea in r.iter_lines():
                if parar.is_set():
                    return "parado", texto
                if not linea.startswith("data:"):
                    continue
                try:
                    d = json.loads(linea[5:].strip())
                except ValueError:
                    continue
                if d.get("type") == "content_block_delta" and (d.get("delta") or {}).get("type") == "text_delta":
                    trozo = d["delta"].get("text") or ""
                    texto += trozo
                    estado, t = ini.meter(trozo)
                    if estado == "marca":
                        return "marca", t
                    # LA MARCA AL FINAL (15/09): con la conversacion delante, la API contesto
                    # "Tienes toda la razon. Voy a hacerlo ahora. [ORDEN]". Solo se miraba el
                    # principio, asi que Nova se disculpaba, la marca se borraba al limpiar y
                    # Steam no se abria (braya lo pidio tres veces seguidas). En cuanto aparece,
                    # se deja de hablar y es una orden: lo ya dicho ("voy a hacerlo") encaja.
                    if estado == "sigue" and MARCA_ORDEN in marcas and "[ORDEN" in texto.upper():
                        return "marca", MARCA_ORDEN
                    if estado == "sigue":
                        for f in troc.meter(t):
                            emitir(f)
                elif d.get("type") == "error":
                    return "fallo", "api: %s" % d.get("error")
    except Exception as e:  # noqa: BLE001
        return "fallo", "api: %s" % e
    estado, t = ini.final()
    if estado == "marca":
        return "marca", t
    for f in troc.meter(t) + troc.cerrar():
        emitir(f)
    return ("ok", texto) if texto.strip() else ("fallo", "api sin texto")


def llamar_api_simple(sistema, texto, max_tokens=500):
    """Una llamada sin streaming (la revision de la memoria)."""
    r = _api.post("https://api.anthropic.com/v1/messages", headers=_cabeceras(), timeout=40,
                   json={"model": MODELO_API, "max_tokens": max_tokens, "system": sistema,
                         "messages": [{"role": "user", "content": texto}]})
    if r.status_code != 200:
        _api_rota_si(r.text)
        raise RuntimeError("api %d" % r.status_code)
    return "".join(b.get("text", "") for b in (r.json().get("content") or []) if b.get("type") == "text")


def responder(p):
    # ultimo_dicho: sin este 'global', las dos asignaciones de mas abajo crearian una
    # variable LOCAL y la lectura de "eso no es verdad" reventaria con UnboundLocalError
    # en mitad de la charla. Python no avisa de esto hasta que se ejecuta.
    global ultima_charla, ultimo_dicho
    idp = p.get("id", 0)
    texto = (p.get("texto") or "").strip()
    if not texto:
        salida("fin", idp, origen="nada")
        return
    invitado = bool(p.get("invitado"))
    duda = bool(p.get("duda"))
    buscar = bool(p.get("buscar"))     # ayuda con un juego: internet si o si
    ayuda = bool(p.get("ayuda"))
    ahora = time.time()
    if ahora - ultima_charla > OLVIDO_S:
        historial.clear()
    ultima_charla = ahora
    dichas = []
    tiempos = {"memoria": 0.0, "origen": "memoria"}

    def emitir(f):
        if not dichas:
            salida("info", idp, texto="primera frase en %.1f s (buscar en la memoria: %.1f s)" % (time.time() - ahora, tiempos["memoria"]))
        dichas.append(f)
        # quien la dice (memoria, local o api): la capsula tine un pelo la voz
        salida("frase", idp, texto=f, origen=tiempos["origen"])

    # 0) LA RESPUESTA A UNA PREGUNTA DE TRIVIA (F7): se juzga al momento, sin modelo
    if trivia["r"] is not None and time.time() < trivia["hasta"] and not duda:
        r = trivia["r"]
        trivia["r"] = None
        if RE_RENDIDO.search(cm.plano(texto)):
            dicho = "La respuesta es: " + r["respuesta"]
        elif cm.juzgar_trivia(r["pregunta"], r["respuesta"], texto):
            dicho = "¡Correcto! " + r["respuesta"]
        else:
            dicho = "Casi. " + r["respuesta"]
        troc = Troceador()
        for f in troc.meter(dicho + " ") + troc.cerrar():
            emitir(f)
        salida("fin", idp, origen="trivia-respuesta")
        return
    trivia["r"] = None

    # 1) EL CEREBRO: ¿ya lo sabe de verdad?
    qvec = None
    if cerebro is not None:
        try:
            if duda:
                # CON EL id DE LO QUE NOVA DIJO DE VERDAD (21/09). Antes esto se fiaba
                # de cerebro.ultimo_id, que lo escribe TAMBIEN el hilo del revisor por
                # detras, entre turnos: "no, eso no es verdad" podia rechazar un recuerdo
                # que no tenia nada que ver y dejar firme el que estaba mal.
                mala = cerebro.marcar_incorrecta(ultimo_dicho)
                if mala:
                    salida("info", idp, texto="memoria: '%s' queda como incorrecta" % mala["pregunta"][:80])
            else:
                # PRIMERO POR PALABRAS: si ya lo encuentra, ni se carga el modelo de
                # embeddings (0 ms y 0 MB). Solo si no, por significado; y con el
                # cerebro vacio, tampoco (no hay nada que buscar)
                sabida = cerebro.respuesta_directa(texto, None)
                # POR SIGNIFICADO SOLO PARA CONFIRMAR (medido el 13/09): cargar el
                # modelo de embeddings con Qwen en la RAM dejaba 428 MB libres,
                # Windows paginaba y la respuesta pasaba de 3 s a 13 s. Solo se usa
                # si por palabras ya hay una pregunta parecida que confirmar.
                if sabida is None and cerebro.datos["recuerdos"]:
                    mejor = cerebro.buscar(texto, tipos={"respuesta"}, k=1)
                    if mejor and mejor[0]["lex"] >= 0.25:
                        qvec = cerebro.vector(texto)
                        if qvec is not None:
                            sabida = cerebro.respuesta_directa(texto, qvec)
                if sabida:
                    # EL RELOJ SE PARA AQUI (21/09). tiempos["memoria"] se rellenaba
                    # al final de la busqueda... DESPUES del return de este mismo
                    # bloque, o sea que cuando la memoria SI sabia la respuesta -el
                    # unico caso en que interesa saber lo que tardo- el numero se
                    # quedaba en el 0.0 con el que nace, y la linea de info decia
                    # "buscar en la memoria: 0.0 s" siempre. Medir el camino rapido es
                    # justo lo que dice si la memoria compensa frente a llamar al modelo.
                    tiempos["memoria"] = time.time() - ahora
                    historial.append({"role": "user", "content": texto})
                    troc = Troceador()
                    for f in troc.meter(sabida["respuesta"] + " ") + troc.cerrar():
                        emitir(f)
                    historial.append({"role": "assistant", "content": sabida["respuesta"]})
                    recortar()
                    if not invitado:
                        apuntar_charla(texto, sabida["respuesta"])   # ver DIARIO DE CONVERSACIONES
                    salida("info", idp, texto="memoria: lo sé (recuerdo %d, %d usos)" % (sabida["id"], sabida.get("usos", 0)))
                    # esto SI es "lo ultimo que Nova dijo": es la respuesta que acaba de
                    # salir por la voz, no lo que el revisor guarde de fondo
                    ultimo_dicho = sabida["id"]
                    salida("fin", idp, origen="memoria")
                    return
        except Exception as e:  # noqa: BLE001
            salida("info", idp, texto="memoria: no pude consultarla (%s)" % e)

    tiempos["memoria"] = time.time() - ahora
    historial.append({"role": "user", "content": texto})
    extra = texto_datos(p)   # ver LO QUE NOVA YA SABE
    if ayuda:
        extra += " braya te pide ayuda con su partida de %s: explícale en dos o tres frases claras qué tiene que hacer." % (p.get("juego") or "su juego")
    elif p.get("juego"):
        extra += " Ahora braya está jugando a %s: contesta en una sola frase corta." % p["juego"]
    if cerebro is not None:
        try:
            extra += cerebro.contexto(texto, qvec, invitado)
        except Exception:  # noqa: BLE001
            pass
    if not invitado:
        dp = datos_perfil()
        if dp:
            # LOS QUE VIENEN A CUENTO, NO LOS ULTIMOS (25/09). Ver perfil_para: con
            # dp[-15:], preguntar por la mascota no traia la linea de la mascota si estaba
            # fuera de las quince ultimas, y Nova contestaba que no lo sabia teniendolo escrito.
            extra += "\n\nLo que sabes de braya: " + "; ".join(perfil_para(texto, dp)) + "."

    usar_api = (necesita_api(texto) or pide_datos(texto) or duda or buscar) and api_disponible()
    # SIN API, UN DATO CONCRETO NO LO CONTESTA EL LOCAL (14/09): medido, se lo inventa
    # aunque el prompt le pida que no ("Goose Goose Duck es una pelicula de Disney").
    # Se devuelve al asistente, que lo pasa a su cerebro de preguntas. Si ese tampoco
    # esta, el asistente lo reenvia con "sin_delegar" y lo contesta el local igual.
    if pide_datos(texto) and not api_disponible() and not p.get("sin_delegar"):
        historial.pop()
        salida("delegar", idp, texto=texto)
        return
    # API PRIMERO (15/09, elegido por braya: "capa local y API para las conversaciones").
    # Con el local delante, la primera frase tardaba 10-22 s en su uso real (y la API solo
    # entraba cuando el local se apartaba con [API], pagando las dos esperas). El local
    # (qwen2.5:1.5b, config.json -> conversacion.modeloLocal) queda para cuando no hay
    # internet o la API falla. Lo que contesta la API se sigue aprendiendo en la memoria.
    if api_disponible():
        intentos = ["api", "local"]
    else:
        intentos = ["local", "api", "local-sin-marca"] if not usar_api else ["api", "local"]
    motivos = []
    marca_api_vista = False
    for origen in intentos:
        tiempos["origen"] = "api" if origen == "api" else "local"
        if origen == "api":
            if not api_disponible():
                motivos.append("api no disponible")
                continue
            res, dato = generar_api(list(historial), [MARCA_ORDEN], emitir, extra, buscar=necesita_api(texto) or buscar or marca_api_vista)
        elif origen == "local":
            marcas = [MARCA_ORDEN] + ([MARCA_API] if api_disponible() else [])
            res, dato = generar_local(list(historial), marcas, emitir, extra)
        else:
            if not marca_api_vista:
                continue      # solo si el local se aparto para la API y la API fallo
            res, dato = generar_local(list(historial), [MARCA_ORDEN], emitir, extra)
        if res == "marca" and dato == MARCA_ORDEN:
            # YA VOLVIO UNA VEZ (18/09): el asistente la mando a traducir, la traduccion
            # dijo que no era una orden y se la devolvio con "sin_orden". Insistir en
            # [ORDEN] aqui es el rebote que el 18/09 dio 19 vueltas y 19 llamadas de pago
            # sin hacer nada. Se contesta con la frase de siempre para lo que no se
            # entiende, sin gastar otra generacion.
            if p.get("sin_orden"):
                historial.pop()
                salida("frase", idp, texto="Eso no he sabido hacerlo. Dímelo de otra forma.", origen="fijo")
                salida("fin", idp, origen="local")
                return
            # no era charla: el asistente lo manda a quien sabe hacerlo, y si solo se
            # entiende con lo hablado ("recuerdamelo luego"), reescrita entera (M10)
            reescrita = reescribir_orden(texto)
            historial.pop()
            salida("orden", idp, texto=reescrita, original=texto)
            return
        if res == "parado":
            historial.pop()
            salida("fin", idp, origen="parado")
            return
        if res == "ok" or (res == "fallo" and dichas):
            # si ya dijo algo y luego fallo, se queda con lo dicho: repetirlo por
            # otro camino sonaria a eco
            respuesta = (dato if res == "ok" else " ".join(dichas)).strip()
            previo = historial[-2]["content"] if len(historial) >= 2 and historial[-2]["role"] == "assistant" else ""
            historial.append({"role": "assistant", "content": respuesta})
            recortar()
            quien = "api" if origen == "api" else "local"
            salida("fin", idp, origen=quien)
            if not invitado:
                apuntar_charla(texto, respuesta)   # ver DIARIO DE CONVERSACIONES
            # 4) APRENDER (nunca de un invitado)
            if cerebro is not None and not invitado:
                try:
                    rAp = cerebro.aprender_turno(texto, limpiar(respuesta), quien, previo, qvec)
                    # si ese turno dejo un recuerdo, ESE es el que rechaza "eso no es
                    # verdad": es la respuesta que braya acaba de oir
                    if rAp and rAp.get("recuerdo"):
                        ultimo_dicho = rAp["recuerdo"]
                except Exception as e:  # noqa: BLE001
                    salida("info", idp, texto="memoria: no pude aprender (%s)" % e)
            return
        if res == "marca":
            marca_api_vista = True
            motivos.append("%s: se lo pasa a la API" % origen)
        else:
            motivos.append("%s: %s" % (origen, dato))
    historial.pop()
    salida("err", idp, texto="; ".join(motivos))


def revisar_una():
    """Un paso de la revision en segundo plano: vectores que faltan y un turno
    pendiente revisado por la API. Nunca mientras se esta contestando."""
    if cerebro is None or ocupado.is_set():
        return False
    # el repaso del dia, con 20 min sin charla (ver Cerebro.repaso)
    if time.time() - ultima_charla > 1200:
        try:
            hecho = cerebro.repaso()
            if hecho:
                salida("info", texto="memoria: repaso del dia (%d repetidos juntados, %d a revisar otra vez, %d podados)" % (
                    hecho["juntados"], hecho["reencolados"], hecho["podados"]))
        except Exception as e:  # noqa: BLE001
            salida("info", texto="memoria: repaso fallido (%s)" % e)
        # y lo hablado los dias pasados, resumido para el diario (M10)
        try:
            if resumir_dias_pasados():
                return True
        except Exception as e:  # noqa: BLE001
            salida("info", texto="diario: %s" % e)
    # los vectores que faltan, solo con Qwen ya fuera de la RAM (5 min sin charla):
    # cargar el modelo de embeddings a su lado hace paginar a Windows
    if time.time() - ultima_charla > 300:
        try:
            cerebro.completar_vectores()
        except Exception:  # noqa: BLE001
            pass
    if not api_disponible() or ocupado.is_set():
        return False
    job = cerebro.siguiente_pendiente()
    if not job:
        return False
    try:
        rev = cm.revisar_turno(job, llamar_api_simple)
    except Exception as e:  # noqa: BLE001
        cerebro.fallo_revision(job)
        salida("info", texto="memoria: revision fallida (%s)" % e)
        return False
    firmes_antes = cerebro.balance()["respuestas"]
    for ev in cerebro.aplicar_revision(job, rev):
        salida(ev["ev"], 0, texto=ev["texto"])
    b = cerebro.balance()
    if b["respuestas"] > firmes_antes:
        salida("aprendido", 0, texto=job["pregunta"][:80])   # la capsula lo celebra con un destello
    salida("info", texto="memoria: revisado '%s' (%d firmes, %d provisionales, %d pendientes)" % (
        job["pregunta"][:60], b["respuestas"], b["provisionales"], b["pendientes"]))
    return True


def revisor():
    """Revision en segundo plano, sin despertar por nada.

    Antes era "while True: time.sleep(3)" a secas: 1.200 despertares por hora mientras el
    worker viviera, y en cada uno un recorrido de hasta 5.000 recuerdos para descubrir que
    no habia nada que hacer. En una consola a bateria eso se nota, y se nota justo cuando
    braya esta jugando, que es cuando menos debe notarse.

    Ahora: espera sobre un evento (no gasta CPU), se para del todo con un juego delante y
    va espaciando las vueltas cuando no encuentra trabajo.
    """
    espera = 3.0
    while True:
        if revisor_parado.is_set():
            # con un juego delante no hay revision: se duerme hasta que vuelva la charla
            revisor_hay_trabajo.wait(30.0)
            revisor_hay_trabajo.clear()
            continue
        revisor_hay_trabajo.wait(espera)
        revisor_hay_trabajo.clear()
        try:
            hizo = revisar_una()
        except Exception as e:  # noqa: BLE001
            salida("info", texto="memoria: %s" % e)
            hizo = False
        # si hubo algo que hacer, se sigue de cerca; si no, se va soltando hasta 60 s
        espera = 3.0 if hizo else min(60.0, espera * 2)


def descargar():
    # NO DIGAS QUE LIBERASTE LO QUE NO LIBERASTE (18/09). El aviso estaba fuera del try y el
    # except se comia el fallo de Ollama: Nova afirmaba haber soltado RAM que seguia ocupada, y
    # esto corre justo al abrir un juego, o sea en plena prioridad de "poca RAM jugando".
    fallo = ""
    salieron = 0
    for m in [MODELO_LOCAL] + ([MODELO_EMBED] if MODELO_EMBED else []):
        try:
            httpx.post(OLLAMA + "/api/generate", json={"model": m, "keep_alive": 0}, timeout=10)
            salieron += 1
        except Exception as e:  # noqa: BLE001
            fallo = str(e)
    if salieron and not fallo:
        salida("info", texto="modelos locales fuera de la RAM")
    elif salieron:
        salida("info", texto="parte de los modelos sigue en la RAM (%s)" % fallo)
    else:
        salida("info", texto="NO pude sacar los modelos de la RAM (%s)" % fallo)


class EmbedOllama:
    """Vectores de significado con un modelo de embeddings de Ollama.

    keep_alive 0: se descarga en cuanto contesta. Medido el 13/09 con los dos
    modelos a la vez: quedaban 571 MB libres, Windows paginaba y las respuestas
    del 3B ya caliente pasaron de 3 s a 7-12 s. Cargarlo por consulta cuesta
    mucho menos (son 338 MB y el archivo queda en la cache del disco)."""

    def __init__(self, modelo, keep_alive=0):
        self.nombre = modelo
        self.keep_alive = keep_alive

    def vectores(self, textos):
        r = httpx.post(OLLAMA + "/api/embed", json={"model": self.nombre, "input": textos, "keep_alive": self.keep_alive}, timeout=30)
        r.raise_for_status()
        return r.json()["embeddings"]


_aviso_sin_cerebro = False


def cerebro_dicho(que):
    """EL CERROJO DE C7 (19/09): nadie escribe en la memoria sin haber dicho en que
    carpeta. Se avisa UNA vez (si no, cada frase dejaria una linea en el log)."""
    if CARPETA_CEREBRO:
        return True
    global _aviso_sin_cerebro
    if not _aviso_sin_cerebro:
        _aviso_sin_cerebro = True
        salida("info", texto="no me han dicho la carpeta del cerebro (argv[4]): no escribo %s" % que)
    return False


# DE DONDE SALE CADA LINEA DEL DIARIO (20/09, D4). C7 cerro la puerta por la que el banco
# metia recuerdos falsos -los osos polares y Hades acabaron en memoria\diario-: ya no se
# escribe sin que digan la carpeta. Esto es la otra mitad, la de dentro: cada linea dice
# de donde viene, y el resumidor solo se queda con las reales.
#
# LA SENAL NO HAY QUE INVENTARLA NI RECORDARLA: la carpeta ya lo dice. Si escribimos en
# memoria\cerebro es la memoria de verdad; cualquier otra carpeta es una prueba. Asi no
# depende de que alguien se acuerde de pasar una marca, que es justo lo que fallo.
CEREBRO_REAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memoria", "cerebro")


def origen_linea():
    try:
        if not CARPETA_CEREBRO:
            return "prueba"
        return "real" if os.path.normcase(os.path.abspath(CARPETA_CEREBRO)) == os.path.normcase(CEREBRO_REAL) else "prueba"
    except Exception:   # noqa: BLE001
        return "prueba"   # ante la duda, NO es memoria de verdad


def ruta_charla(dia):
    return os.path.join(CARPETA_CEREBRO, "charla-%s.jsonl" % dia)


# LO QUE IMPORTO NO SE RESUME (25/09, idea 35 de las 50)
#
# LO MEDIDO: cada intercambio se apunta en bruto en charla-<dia>.jsonl y, al dia siguiente,
# resumir_dias_pasados lo pasa por el modelo local, escribe 2-5 vinetas en el diario y BORRA el
# bruto. En catorce dias eso ha convertido 342 turnos de conversacion en 29 vinetas y 2.866
# bytes. Y del 13, 19, 24 y 25/09 no hay ni vineta.
#
# RESUMIR ESTA BIEN para la mayoria: nadie necesita el bruto de "que hora es". Lo que esta mal
# es que se resuma TODO POR IGUAL. Contado sobre el log de 14 dias, el 15 % de lo que braya
# dice son dos cosas que no se pueden reconstruir de un resumen:
#
#   1. CUANDO TE CORRIGE. "No dije Discord, dije Steam". "Pero yo no te dije que reprodujeras
#      eso, yo te dije el segundo video y claramente no era". "Dios, como puede ser posible que
#      no sepas hacer algo". 41 frases asi. Una vineta que diga "hablaron de Steam" no sirve de
#      nada; la frase exacta dice COMO habla braya y EN QUE se equivoco Nova.
#   2. CUANDO NOVA ADMITE UN AGUJERO. "No me has dicho nunca como se llama tu mascota". "No
#      tengo acceso a esos datos del juego". Son el inventario de lo que le falta, y hoy
#      desaparecen en el resumen del dia siguiente.
#
# LO QUE SE HACE: esos turnos se COPIAN a importante.jsonl segun pasan. El bruto se sigue
# resumiendo y borrando igual que hoy -no se cambia nada de eso-, pero lo que importo se queda.
# Sin tope, como la memoria permanente del perfil: son unas decenas de lineas al mes.
#
# Y NO SALE DE LA MAQUINA: vive en memoria\cerebro\, que el .gitignore ignora entero.
RE_CORRIGE = re.compile(
    r"(?i)\b(?:no dije|no era eso|no es eso|te equivocas|est[aá]s equivocada|"
    r"no te dije|no quer[ií]a|no ped[ií]|no quise decir|yo te dije|te dije que)\b")
RE_AGUJERO = re.compile(
    r"(?i)(?:no me has dicho|no lo s[eé]\b|no tengo acceso|no puedo ver|no dispongo|"
    r"no tengo ning[uú]n dato|nunca me has)")


# Y LA NEGACION LARGA (25/09). Los patrones de arriba cazan 41 frases del log; se conto ademas
# cuantas EMPIEZAN por "no", y son 66. Mirando las de cinco palabras o mas -56- practicamente
# todas son correcciones: "No, no te pedi la hora, dije si es Steam", "No, no es buscarlo en
# Google, es poner la mitad de una pantalla en Pinterest", "No lo estas haciendo bien, estas
# hablandolo en el mismo navegador", "No, no, tu muevete a la derecha". Las cinco palabras son
# el liston que las separa del "no" a secas y del "no, gracias", que no corrigen nada.
# Se cuela alguna ("No, asi esta bien"), y se acepta a proposito: guardar de mas cuesta una
# linea en un fichero sin tope, y perder una correccion la pierde para siempre.
RE_NEGACION = re.compile(r"(?i)^\s*no[,.]?\s")
NEGACION_PALABRAS = 5


def por_que_importa(texto, respuesta):
    """'' si es un turno normal; si no, POR QUE merece guardarse entero.

    Aparte y devolviendo el motivo -no un booleano- para que el fichero diga de que tipo es
    cada linea: dentro de un mes, saber si algo se guardo por una correccion o por un agujero
    es justo lo que deja contarlos por separado."""
    try:
        if texto and RE_CORRIGE.search(texto):
            return "correccion"
        if texto and RE_NEGACION.match(texto) and len(texto.split()) >= NEGACION_PALABRAS:
            return "correccion"
        if respuesta and RE_AGUJERO.search(respuesta):
            return "agujero"
    except Exception as e:  # noqa: BLE001
        # QUE NO SE CALLE. Devolver "" es TAMBIEN la respuesta buena -"este turno es normal"-,
        # asi que un patron roto dejaria de guardar correcciones sin que nadie se enterara:
        # el fichero simplemente no crece y parece que braya no corrige nunca. Con la linea,
        # se ve. Es la manera 10 de que un banco salga verde mintiendo, aplicada al reves.
        try:
            salida("info", texto="lo importante: no pude decidir si este turno importa (%s)" % e)
        except Exception:  # noqa: BLE001
            pass
    return ""


def apuntar_importante(texto, respuesta, motivo):
    """Copia un turno a importante.jsonl, que NO se poda nunca."""
    if not motivo:
        return
    try:
        os.makedirs(CARPETA_CEREBRO, exist_ok=True)
        with open(os.path.join(CARPETA_CEREBRO, "importante.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps({"d": time.strftime("%Y-%m-%d"), "h": time.strftime("%H:%M"),
                                "por": motivo,
                                "braya": cm.limpio(texto, 300),
                                "nova": cm.limpio(respuesta, 300)}, ensure_ascii=False) + "\n")
    except Exception:  # noqa: BLE001
        pass


def apuntar_charla(texto, respuesta):
    """DIARIO DE CONVERSACIONES (M10, 14/09): cada intercambio del dia, en bruto,
    hasta que se resume (ver resumir_dias_pasados). Nunca de un invitado."""
    if not cerebro_dicho("el diario de conversaciones"):
        return
    try:
        os.makedirs(CARPETA_CEREBRO, exist_ok=True)
        with open(ruta_charla(time.strftime("%Y-%m-%d")), "a", encoding="utf-8") as f:
            f.write(json.dumps({"h": time.strftime("%H:%M"), "o": origen_linea(),
                                "braya": cm.limpio(texto, 300),
                                "nova": cm.limpio(respuesta, 300)}, ensure_ascii=False) + "\n")
    except Exception:  # noqa: BLE001
        pass
    # Y SI ESTE TURNO IMPORTA, UNA COPIA QUE NO SE PODA (ver LO QUE IMPORTO NO SE RESUME).
    # Va aparte del try de arriba a proposito: que falle el diario en bruto no es razon para
    # perder ademas la unica copia de una correccion.
    try:
        apuntar_importante(texto, respuesta, por_que_importa(texto, respuesta))
    except Exception:  # noqa: BLE001
        pass


def resumir_dias_pasados(hoy=None):
    """Con Nova en reposo, lo hablado cada dia YA PASADO se resume con el modelo
    LOCAL (son tus conversaciones: nunca la API) en unas vinetas, que el
    asistente anade al diario de ese dia; el registro en bruto se borra.
    Uno por vez. Si el modelo no esta, se queda para otro rato."""
    hoy = hoy or time.strftime("%Y-%m-%d")
    if not cerebro_dicho("el resumen del diario"):
        return False
    try:
        nombres = sorted(n for n in os.listdir(CARPETA_CEREBRO) if n.startswith("charla-") and n.endswith(".jsonl"))
    except OSError:
        return False
    # SOLO SE FILTRA CUANDO ESTAMOS EN LA MEMORIA DE VERDAD (20/09). La primera version
    # tiraba toda linea marcada "prueba" en cualquier sitio, y con eso el resumen se
    # volvia imposible de probar: el banco escribe en su propia carpeta, o sea que TODO
    # quedaba marcado como prueba y no se resumia nada. Lo que hay que proteger es la
    # memoria real de lineas ajenas; dentro de una carpeta de pruebas, todo es coherente
    # y el resumen tiene que funcionar igual que de verdad.
    aqui_es_real = (origen_linea() == "real")
    for n in nombres:
        dia = n[len("charla-"):-len(".jsonl")]
        if dia >= hoy:
            continue
        ruta = os.path.join(CARPETA_CEREBRO, n)
        turnos = []
        saltadas = 0
        try:
            with open(ruta, encoding="utf-8") as f:
                for linea in f:
                    try:
                        t = json.loads(linea)
                    except ValueError:
                        continue
                    # SOLO LO REAL LLEGA AL RESUMEN (20/09, D4). Una linea marcada como
                    # prueba se salta aqui aunque se haya colado en el fichero: es la
                    # segunda cerradura, por si algun dia falla la primera (C7).
                    # Las lineas VIEJAS no traen el campo y cuentan como reales: son de
                    # antes de esta marca, y las contaminadas ya se borraron el 19/09.
                    # Tratarlas como sospechosas borraria historial bueno.
                    if aqui_es_real and t.get("o", "real") != "real":
                        saltadas += 1
                        continue
                    turnos.append("braya: %s\nNova: %s" % (t.get("braya", ""), t.get("nova", "")))
        except OSError:
            continue
        if saltadas:
            salida("info", texto="diario %s: me salto %d linea(s) que no son de uso real" % (dia, saltadas))
        if not turnos:
            try:
                os.remove(ruta)
            except OSError:
                pass
            continue
        try:
            r = httpx.post(OLLAMA + "/api/chat", timeout=120, json={
                "model": MODELO_LOCAL, "stream": False, "keep_alive": "2m",
                "options": {"num_predict": 220, "temperature": 0.3, "num_ctx": 1536},
                "messages": [{"role": "system", "content": (
                    "Resumes conversaciones para un diario personal. Responde SOLO con 2 a 5 viñetas cortas "
                    "en español, cada una empezando por '- ', sobre de qué hablaron braya y Nova. No inventes nada.")},
                    {"role": "user", "content": "\n".join(turnos)[-2500:]}]})
            r.raise_for_status()
            resumen = CJK.sub("", ((r.json().get("message") or {}).get("content") or "")).strip()
        except Exception as e:  # noqa: BLE001
            salida("info", texto="diario: no pude resumir lo del %s (%s)" % (dia, e))
            return False
        vinetas = ["- " + re.sub(r"^\s*[-•*]\s*", "", l).strip() for l in resumen.splitlines() if l.strip()]
        vinetas = [v for v in vinetas if len(v) > 3][:6]
        if not vinetas:
            return False
        salida("diario", 0, fecha=dia, texto="\n".join(vinetas))
        try:
            os.remove(ruta)
        except OSError:
            pass
        return True
    return False


def texto_datos(p):
    """LO QUE NOVA YA SABE (16/09). Llega en el campo "datos" de cada peticion: la hora,
    la fecha, las descargas, los temporizadores, el nivel y lo ultimo que hizo. Sin esto,
    el modelo se los inventaba o decia que no tenia acceso a ellos (10 veces el 15/09)."""
    d = (p or {}).get("datos")
    if not isinstance(d, str):
        return ""
    d = d.strip()
    if not d:
        return ""
    if len(d) > 600:
        d = d[:600]
    return (" Datos ciertos de ahora mismo, sacados del propio sistema: %s. Úsalos si vienen "
            "a cuento y NUNCA digas que no puedes saberlos; si no vienen a cuento, ni los menciones." % d)


def reescribir_orden(texto):
    """ORDENES DENTRO DE LA CHARLA (M10): "pues recuerdamelo luego" no se entiende
    suelto. Con lo hablado delante, el modelo local la reescribe como una orden
    completa. Si no hace falta o falla, la de siempre."""
    previos = historial[:-1]
    if not previos or not RE_DEIXIS.search(cm.plano(texto)):
        return texto
    # CON LA API PRIMERO (15/09): con qwen2.5:1.5b, "abre steam de una vez, no solo pidas
    # disculpas" (RE_DEIXIS caza "solo") se reescribio "Abre Steam y inicia sesion, luego
    # inicia una nueva partida o registrate": pasos que nadie pidio. La API lo hace bien y
    # en menos de un segundo; el local queda para cuando no hay API.
    sistema_r = ("Reescribe la última petición de braya como UNA orden completa y autónoma en español, "
                 "sustituyendo 'lo', 'eso', 'luego'... por lo que corresponda según la conversación. "
                 "Si ya es una orden completa, devuélvela igual. No añadas pasos ni nada que no haya pedido. "
                 "Responde SOLO con la orden, sin comillas ni explicaciones.")
    if api_disponible():
        try:
            conversacion = "\n".join(("braya: " if m["role"] == "user" else "Nova: ") + str(m["content"]) for m in previos[-6:])
            orden = limpiar(llamar_api_simple(sistema_r, "Conversación:\n%s\n\nÚltima petición de braya: %s" % (conversacion, texto),
                                              max_tokens=80)).strip(" \"'«»")
            if 3 <= len(orden) <= 200 and not CJK.search(orden):
                return orden
        except Exception:  # noqa: BLE001
            pass
    try:
        cuerpo = {"model": MODELO_LOCAL, "stream": False, "keep_alive": "2m",
                  "options": {"num_predict": 40, "temperature": 0.1, "num_ctx": 1536},
                  "messages": [{"role": "system", "content": sistema_r}]
                  + previos[-6:] + [{"role": "user", "content": texto}]}
        r = httpx.post(OLLAMA + "/api/chat", json=cuerpo, timeout=20)
        r.raise_for_status()
        orden = limpiar((r.json().get("message") or {}).get("content") or "").strip(" \"'«»")
        if 3 <= len(orden) <= 200 and not CJK.search(orden):
            return orden
    except Exception:  # noqa: BLE001
        pass
    return texto


def jugar_trivia(p):
    """TRIVIA (F7): una pregunta de lo que Nova ya sabe seguro."""
    idp = p.get("id", 0)
    r = cerebro.pregunta_trivia(trivia["hechas"]) if cerebro is not None else None
    if r is None:
        salida("frase", idp, texto="Todavía sé muy pocas cosas seguras para jugar. Pregúntame cosas y las aprendo.")
        salida("fin", idp, origen="trivia-nada")
        return
    trivia.update(r=r, hasta=time.time() + 90)
    trivia["hechas"] = (trivia["hechas"] + [r["id"]])[-20:]
    salida("frase", idp, texto="Ahí va: " + r["pregunta"])
    salida("fin", idp, origen="trivia")


def resumir_mensajes(p):
    """MENSAJES RESUMIDOS (M9): SOLO con el modelo local. Son los mensajes de
    braya: nunca salen a la API, no se aprenden y no quedan en la charla."""
    idp = p.get("id", 0)
    dichas = []

    def emitir(f):
        dichas.append(f)
        salida("frase", idp, texto=f)
    mensajes = [{"role": "user", "content": (
        "Resume en una o dos frases, para decirlo en voz alta, estos mensajes que ha recibido braya, "
        "agrupando por persona o conversación. No inventes nada:\n" + (p.get("texto") or ""))}]
    res, dato = generar_local(mensajes, [], emitir, " Ahora solo resumes mensajes: sin preguntas al final.")
    if res == "ok" or dichas:
        salida("fin", idp, origen="resumen")
    else:
        salida("err", idp, texto="no pude resumir: %s" % dato)


def calentar():
    """MENOS ESPERA EN FRIO (M2): el asistente cree que vas a charlar y lo carga ya."""
    try:
        # no basta con cargar el modelo: se le hace LEER la parte fija del prompt, que
        # en frio era lo que mas tardaba. Mismo num_ctx que generar_local, o Ollama
        # recargaria el modelo al cambiarlo.
        httpx.post(OLLAMA + "/api/chat", json={
            "model": MODELO_LOCAL, "stream": False, "keep_alive": "2m",
            "options": {"num_predict": 1, "num_ctx": 1536},
            "messages": [{"role": "system", "content": sistema_con("", [MARCA_ORDEN, MARCA_API])},
                         {"role": "user", "content": "hola"}]}, timeout=120)
        salida("info", texto="modelo local precargado")
    except Exception as e:  # noqa: BLE001
        salida("info", texto="no pude precargar el modelo local: %s" % e)


def apuntar_hilo(texto, hecho):
    """EL HILO NO SE CORTA CON LAS ORDENES (M2, 20/09). Una orden que hizo el asistente
    sin pasar por aqui: se deja el turno en el hilo para que la frase siguiente se
    entienda ("con la novena cancion", "te dije que en YouTube"). No llama a ningun
    modelo, no aprende nada y no escribe en disco: solo el hilo, que se olvida solo.

    Se apunta el PAR entero (braya / Nova) a proposito: la API exige que los papeles
    se alternen, y medio turno suelto rompería la charla siguiente."""
    global ultima_charla
    texto = (texto or "").strip()
    if not texto:
        return
    ahora = time.time()
    if ahora - ultima_charla > OLVIDO_S:
        historial.clear()      # el mismo reloj que la charla: 5 minutos y a cero
    ultima_charla = ahora
    historial.append({"role": "user", "content": texto[:300]})
    historial.append({"role": "assistant", "content": ((hecho or "").strip() or "hecho")[:300]})
    recortar()

PROMPT_BANCO = (
    "Genera preguntas de cultura general en espanol, variadas (geografia, ciencia, historia, "
    "cine, deporte, naturaleza). Devuelve SOLO un array JSON, sin texto alrededor. Cada "
    "elemento: {\"pregunta\": \"...\", \"opciones\": [\"a\",\"b\",\"c\"], \"buena\": 1}. "
    "Exactamente TRES opciones. 'buena' es 1, 2 o 3 y es la posicion de la correcta. "
    "Cada opcion, como mucho 26 caracteres. La pregunta, como mucho 120. "
    "Nada de preguntas sobre el usuario ni sobre esta conversacion."
)


def generar_banco(p):
    """LAS PREGUNTAS DE LA TRIVIA (23/09, idea 8).

    UNA sola llamada al modelo local, y nunca jugando: PowerShell ya lo frena antes de
    pedirlo. Despues cuesta cero, porque queda en disco.
    SE AVISA SIEMPRE, AUNQUE SEA CON CERO (24/09, repaso). Antes los caminos de fallo salian
    con un 'info' y PowerShell se quedaba con triviaGenerando puesto para siempre: un solo
    "el modelo no devolvio una lista" -que con un 3B es lo normal- dejaba la trivia sin poder
    pedir mas preguntas hasta el siguiente arranque. El 'aviso' va aparte del texto para que
    el lector de PowerShell no lo confunda con una frase que decir.
    LA RUTA LA MANDA POWERSHELL, no se adivina aqui: es la leccion que ya esta escrita
    arriba en este mismo fichero -adivinar la carpeta metio recuerdos falsos en el diario-.
    """
    ruta = (p.get("ruta") or "").strip()
    idp = p.get("id") or 0
    if not ruta:
        salida("banco", idp, n=0, aviso="trivia: no me han dicho donde guardar el banco; no lo escribo")
        return
    cuantas = int(p.get("cuantas") or 20)
    crudo = ""
    try:
        r = httpx.post(OLLAMA + "/api/chat", timeout=180, json={
            "model": MODELO_LOCAL,
            "messages": [{"role": "system", "content": PROMPT_BANCO},
                         {"role": "user", "content": "Dame %d preguntas." % cuantas}],
            "stream": False,
            "keep_alive": "2m",
            # 0.8: aqui SI se quiere variedad, al reves que al contestar. Y num_predict alto
            # porque son veinte preguntas de una vez.
            "options": {"num_predict": 2000, "temperature": 0.8, "num_ctx": 2048},
        })
        if r.status_code != 200:
            salida("banco", idp, n=0, aviso="trivia: ollama respondio %d" % r.status_code)
            return
        crudo = (r.json().get("message") or {}).get("content") or ""
    except Exception as e:  # noqa: BLE001
        salida("banco", idp, n=0, aviso="trivia: no pude pedir las preguntas (%s)" % e)
        return
    # el modelo suele envolver el array en texto o en ```json: se coge lo que hay entre
    # el primer [ y el ultimo ]
    i, j = crudo.find("["), crudo.rfind("]")
    if i < 0 or j <= i:
        salida("banco", idp, n=0, aviso="trivia: el modelo no devolvio una lista")
        return
    try:
        lista = json.loads(crudo[i:j + 1])
    except ValueError:
        salida("banco", idp, n=0, aviso="trivia: el modelo devolvio algo que no es JSON")
        return
    # EL MISMO FILTRO QUE POWERSHELL, a proposito: si aqui entrara algo que alli se tira,
    # el banco diria que tiene veinte y tendria doce.
    buenas = []
    for q in lista if isinstance(lista, list) else []:
        if not isinstance(q, dict):
            continue
        preg = str(q.get("pregunta") or "").strip()
        ops = q.get("opciones")
        if not preg or len(preg) > 120 or not isinstance(ops, list) or len(ops) != 3:
            continue
        ops = [str(o).strip() for o in ops]
        if any((not o) or len(o) > 26 for o in ops):
            continue
        try:
            b = int(q.get("buena"))
        except (TypeError, ValueError):
            continue
        if b < 1 or b > 3:
            continue
        buenas.append({"pregunta": preg, "opciones": ops, "buena": b})
    if not buenas:
        salida("banco", idp, n=0, aviso="trivia: ninguna de las preguntas paso el filtro")
        return
    # se funde con lo que ya hubiera, sin repetir la misma pregunta
    banco = {"preguntas": [], "hechas": []}
    try:
        if os.path.exists(ruta):
            with open(ruta, encoding="utf-8") as f:
                viejo = json.load(f)
            banco["preguntas"] = list(viejo.get("preguntas") or [])
            banco["hechas"] = list(viejo.get("hechas") or [])
    except Exception:  # noqa: BLE001
        banco = {"preguntas": [], "hechas": []}
    ya = set((q.get("pregunta") or "").strip().lower() for q in banco["preguntas"])
    nuevas = 0
    for q in buenas:
        if q["pregunta"].lower() in ya:
            continue
        ya.add(q["pregunta"].lower())
        q["id"] = "%d-%d" % (int(time.time()), len(banco["preguntas"]) + nuevas)
        banco["preguntas"].append(q)
        nuevas += 1
    try:
        tmp = ruta + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(banco, f, ensure_ascii=False)
        os.replace(tmp, ruta)
    except Exception as e:  # noqa: BLE001
        salida("banco", idp, n=0, aviso="trivia: no pude guardar el banco (%s)" % e)
        return
    salida("banco", idp, n=nuevas)


def atender(p):
    op = p.get("op")
    if op == "olvidar":
        historial.clear()
    elif op == "olvidar_tema":
        n = cerebro.olvidar(p.get("texto") or "") if cerebro is not None else 0
        salida("info", texto="memoria: olvidados %d recuerdos sobre '%s'" % (n, (p.get("texto") or "")[:60]))
    elif op == "descargar":
        # el asistente lo pide al abrir un juego: fuera los modelos de la RAM y el
        # revisor a dormir, que es lo que mas se nota jugando
        revisor_parado.set()
        descargar()
    elif op == "calentar":
        threading.Thread(target=calentar, daemon=True).start()
    elif op == "triviabanco":
        # EN SU PROPIO HILO Y SOLO SI NO ESTA OCUPADO: generar el banco NO puede ponerse
        # delante de una charla ni cortar lo que Nova este diciendo. Por eso tampoco esta en
        # la lista de ops que hacen parar.set().
        if not ocupado.is_set():
            threading.Thread(target=generar_banco, args=(p,), daemon=True).start()
        else:
            # TAMBIEN AVISA (24/09, repaso): si esto saliera con un 'info', PowerShell se
            # quedaria con triviaGenerando puesto sin que nadie lo baje nunca.
            salida("banco", p.get("id") or 0, n=0, aviso="trivia: estoy ocupada; el banco, mas tarde")
    elif op == "aprender":
        # lo que contesto OTRO cerebro (Claude Code, M4): se aprende como de la API
        if cerebro is not None and not p.get("invitado"):
            try:
                if cerebro.aprender_turno(p.get("pregunta") or "", limpiar(p.get("respuesta") or ""), p.get("origen") or "api"):
                    salida("info", texto="memoria: aprendido de Claude Code '%s'" % (p.get("pregunta") or "")[:60])
            except Exception as e:  # noqa: BLE001
                salida("info", texto="memoria: no pude aprender (%s)" % e)
    elif op == "apunta":
        apuntar_hilo(p.get("texto") or "", p.get("hecho") or "")
    elif op == "recordar":
        # BUSCAR EN LO QUE BRAYA LE HA CONTADO, POR SIGNIFICADO (23/09, funcion 4).
        # Hasta hoy una pregunta como "¿que te dije del juego que era caro?" se la comia el
        # camino de siempre y acababa en opencode -el agente con acceso total- tardando de 25
        # a 60 s, mientras la memoria tenia la respuesta al lado. Medido contra sus vectores
        # reales: 5 preguntas de 5 sacaron el recuerdo bueno EL PRIMERO sin compartir ni una
        # palabra ("del juego que era caro" -> "cada zombi cuesta ocho dolares", 0,576).
        #
        # PRIMERO LO GRATIS: buscar() sin vector es instantaneo y ya cubre lo que comparte
        # palabras. Solo si eso no llega se embebe la pregunta (3,3 s en frio, 0,03 en
        # caliente), y ni se intenta si el modelo de significado no esta.
        # Y EL LISTON ES ABSOLUTO, NO RELATIVO, Y SALE DE MEDIRLO CONTRA SU MEMORIA DE VERDAD
        # (23/09, 110 recuerdos y 106 vectores suyos):
        #   con respuesta en su memoria: 0,315  0,330  0,383  0,479  0,534   (los cinco aciertan)
        #   temas que nunca ha hablado:  0,205  0,220  0,226  0,241          (los cuatro, nada)
        # Hay hueco limpio entre 0,241 y 0,315, asi que el liston va en 0,28: pasa el peor
        # acierto con 0,035 de margen y frena el peor falso con 0,039.
        # OJO: la propuesta original decia 0,45 "medido". Con estos datos, 0,45 habria tirado
        # CUATRO de los cinco aciertos. El numero sale de medir aqui, no de copiarlo.
        texto_r = (p.get("texto") or "").strip()
        idr = p.get("id") or 0
        if cerebro is None or not texto_r:
            salida("recuerdo", idr, texto="", nada=True)
        else:
            try:
                hits = cerebro.buscar(texto_r, k=3)
                mejor = hits[0] if hits else None
                if not mejor or mejor["comb"] < LISTON_RECUERDO:
                    # el vector lo da el propio Cerebro (devuelve None si no hay modelo o si
                    # fallo hace poco, asi que no hace falta comprobar nada mas)
                    try:
                        qv = cerebro.vector(texto_r)
                        if qv is not None:
                            hits = cerebro.buscar(texto_r, k=3, qvec=qv)
                            mejor = hits[0] if hits else None
                    except Exception:   # noqa: BLE001
                        pass
                if mejor and mejor["comb"] >= LISTON_RECUERDO:
                    r = mejor["r"]
                    dicho = r.get("respuesta") or r.get("texto") or ""
                    salida("recuerdo", idr, texto=dicho, id_recuerdo=r.get("id"),
                           parecido=round(float(mejor["comb"]), 3))
                else:
                    salida("recuerdo", idr, texto="", nada=True,
                           parecido=round(float(mejor["comb"]), 3) if mejor else 0.0)
            except Exception as e:      # noqa: BLE001
                salida("recuerdo", idr, texto="", nada=True, error=str(e)[:120])
    elif op in ("hablar", "trivia", "resumir"):
        # si vuelve a hablar, el juego ya no manda: el revisor se reanuda. Sin esto se
        # quedaria dormido hasta que muriera el worker, y en vez de ahorrar CPU jugando
        # habria dejado de revisar la memoria para siempre.
        if revisor_parado.is_set():
            revisor_parado.clear()
            revisor_hay_trabajo.set()
        parar.clear()
        ocupado.set()
        try:
            {"hablar": responder, "trivia": jugar_trivia, "resumir": resumir_mensajes}[op](p)
        except Exception as e:  # noqa: BLE001
            salida("err", p.get("id", 0), texto="fallo interno: %s" % e)
        finally:
            ocupado.clear()


def lector():
    # bytes UTF-8 crudos: la entrada estandar de Windows no es UTF-8 por defecto
    for crudo in sys.stdin.buffer:
        try:
            p = json.loads(crudo.decode("utf-8", "replace"))
        except ValueError:
            continue
        op = p.get("op")
        if op in ("parar", "hablar", "trivia", "resumir"):
            parar.set()       # lo nuevo corta lo que se estuviera diciendo
        if op != "parar":
            pedidos.put(p)
    parar.set()
    pedidos.put(None)         # el asistente cerro la tuberia: se acabo


def principal():
    global cerebro
    try:
        if not CARPETA_CEREBRO:
            raise ValueError("no me han dicho la carpeta del cerebro (argv[4]); no toco la memoria de braya")
        cerebro = cm.Cerebro(CARPETA_CEREBRO, EmbedOllama(MODELO_EMBED) if MODELO_EMBED else None)
        b = cerebro.balance()
        salida("info", texto="memoria: %d respuestas firmes, %d provisionales, %d recuerdos, %d pendientes (significado: %s)" % (
            b["respuestas"], b["provisionales"], b["contado"] + b["episodios"], b["pendientes"], MODELO_EMBED or "no"))
        # EL REPASO DEL ESTILO (22/09, idea 5): cuantas preferencias guardadas se
        # contradecian entre ellas y se han ido al cargar. Si no se dice, un repaso que
        # borra cosas del cerebro no lo ve nadie.
        if getattr(cerebro, "estilo_fuera", 0):
            salida("info", texto="memoria: %d preferencia(s) de estilo que se contradecian, fuera"
                                 % cerebro.estilo_fuera)
    except Exception as e:  # noqa: BLE001
        cerebro = None
        salida("info", texto="memoria desactivada: %s" % e)
    threading.Thread(target=lector, daemon=True).start()
    threading.Thread(target=revisor, daemon=True).start()
    salida("info", texto="charla lista (local %s, api %s)" % (MODELO_LOCAL, MODELO_API))
    while True:
        p = pedidos.get()
        if p is None:
            return
        atender(p)


if __name__ == "__main__":
    principal()
