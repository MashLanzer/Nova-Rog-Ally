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

import sys
import os
import re
import json
import time
import queue
import threading

import httpx

import charla_memoria as cm

OLLAMA = "http://127.0.0.1:11434"
MODELO_LOCAL = sys.argv[1] if len(sys.argv) > 1 else "qwen2.5:3b"
MODELO_API = sys.argv[2] if len(sys.argv) > 2 else "claude-haiku-4-5"
MODELO_EMBED = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] not in ("", "-") else ""
CARPETA_CEREBRO = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "memoria", "cerebro")
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
    "las descargas de Steam, el espacio libre, qué está sonando, a qué está jugando): [ORDEN].\n"
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
ocupado = threading.Event()     # contestando: la revision en segundo plano espera
api_rota_hasta = 0.0
ultima_charla = 0.0
bloqueo_salida = threading.Lock()
cerebro = None                  # se crea en principal(); las pruebas ponen el suyo
_perfil = {"mtime": None, "lineas": []}
trivia = {"r": None, "hasta": 0.0, "hechas": []}     # la pregunta de trivia que espera respuesta
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
        with httpx.stream("POST", "https://api.anthropic.com/v1/messages", json=cuerpo, headers=_cabeceras(),
                          timeout=httpx.Timeout(30.0, connect=5.0)) as r:
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
    r = httpx.post("https://api.anthropic.com/v1/messages", headers=_cabeceras(), timeout=40,
                   json={"model": MODELO_API, "max_tokens": max_tokens, "system": sistema,
                         "messages": [{"role": "user", "content": texto}]})
    if r.status_code != 200:
        _api_rota_si(r.text)
        raise RuntimeError("api %d" % r.status_code)
    return "".join(b.get("text", "") for b in (r.json().get("content") or []) if b.get("type") == "text")


def responder(p):
    global ultima_charla
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
                mala = cerebro.marcar_incorrecta()
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
                    historial.append({"role": "user", "content": texto})
                    troc = Troceador()
                    for f in troc.meter(sabida["respuesta"] + " ") + troc.cerrar():
                        emitir(f)
                    historial.append({"role": "assistant", "content": sabida["respuesta"]})
                    recortar()
                    if not invitado:
                        apuntar_charla(texto, sabida["respuesta"])   # ver DIARIO DE CONVERSACIONES
                    salida("info", idp, texto="memoria: lo sé (recuerdo %d, %d usos)" % (sabida["id"], sabida.get("usos", 0)))
                    salida("fin", idp, origen="memoria")
                    return
        except Exception as e:  # noqa: BLE001
            salida("info", idp, texto="memoria: no pude consultarla (%s)" % e)

    tiempos["memoria"] = time.time() - ahora
    historial.append({"role": "user", "content": texto})
    extra = ""
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
            extra += "\n\nLo que sabes de braya: " + "; ".join(dp[-15:]) + "."

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
                    cerebro.aprender_turno(texto, limpiar(respuesta), quien, previo, qvec)
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
    while True:
        time.sleep(3)
        try:
            revisar_una()
        except Exception as e:  # noqa: BLE001
            salida("info", texto="memoria: %s" % e)


def descargar():
    for m in [MODELO_LOCAL] + ([MODELO_EMBED] if MODELO_EMBED else []):
        try:
            httpx.post(OLLAMA + "/api/generate", json={"model": m, "keep_alive": 0}, timeout=10)
        except Exception:  # noqa: BLE001
            pass
    salida("info", texto="modelos locales fuera de la RAM")


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


def ruta_charla(dia):
    return os.path.join(CARPETA_CEREBRO, "charla-%s.jsonl" % dia)


def apuntar_charla(texto, respuesta):
    """DIARIO DE CONVERSACIONES (M10, 14/09): cada intercambio del dia, en bruto,
    hasta que se resume (ver resumir_dias_pasados). Nunca de un invitado."""
    try:
        os.makedirs(CARPETA_CEREBRO, exist_ok=True)
        with open(ruta_charla(time.strftime("%Y-%m-%d")), "a", encoding="utf-8") as f:
            f.write(json.dumps({"h": time.strftime("%H:%M"), "braya": cm.limpio(texto, 300),
                                "nova": cm.limpio(respuesta, 300)}, ensure_ascii=False) + "\n")
    except Exception:  # noqa: BLE001
        pass


def resumir_dias_pasados(hoy=None):
    """Con Nova en reposo, lo hablado cada dia YA PASADO se resume con el modelo
    LOCAL (son tus conversaciones: nunca la API) en unas vinetas, que el
    asistente anade al diario de ese dia; el registro en bruto se borra.
    Uno por vez. Si el modelo no esta, se queda para otro rato."""
    hoy = hoy or time.strftime("%Y-%m-%d")
    try:
        nombres = sorted(n for n in os.listdir(CARPETA_CEREBRO) if n.startswith("charla-") and n.endswith(".jsonl"))
    except OSError:
        return False
    for n in nombres:
        dia = n[len("charla-"):-len(".jsonl")]
        if dia >= hoy:
            continue
        ruta = os.path.join(CARPETA_CEREBRO, n)
        turnos = []
        try:
            with open(ruta, encoding="utf-8") as f:
                for linea in f:
                    try:
                        t = json.loads(linea)
                    except ValueError:
                        continue
                    turnos.append("braya: %s\nNova: %s" % (t.get("braya", ""), t.get("nova", "")))
        except OSError:
            continue
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


def atender(p):
    op = p.get("op")
    if op == "olvidar":
        historial.clear()
    elif op == "olvidar_tema":
        n = cerebro.olvidar(p.get("texto") or "") if cerebro is not None else 0
        salida("info", texto="memoria: olvidados %d recuerdos sobre '%s'" % (n, (p.get("texto") or "")[:60]))
    elif op == "descargar":
        descargar()
    elif op == "calentar":
        threading.Thread(target=calentar, daemon=True).start()
    elif op == "aprender":
        # lo que contesto OTRO cerebro (Claude Code, M4): se aprende como de la API
        if cerebro is not None and not p.get("invitado"):
            try:
                if cerebro.aprender_turno(p.get("pregunta") or "", limpiar(p.get("respuesta") or ""), p.get("origen") or "api"):
                    salida("info", texto="memoria: aprendido de Claude Code '%s'" % (p.get("pregunta") or "")[:60])
            except Exception as e:  # noqa: BLE001
                salida("info", texto="memoria: no pude aprender (%s)" % e)
    elif op in ("hablar", "trivia", "resumir"):
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
        cerebro = cm.Cerebro(CARPETA_CEREBRO, EmbedOllama(MODELO_EMBED) if MODELO_EMBED else None)
        b = cerebro.balance()
        salida("info", texto="memoria: %d respuestas firmes, %d provisionales, %d recuerdos, %d pendientes (significado: %s)" % (
            b["respuestas"], b["provisionales"], b["contado"] + b["episodios"], b["pendientes"], MODELO_EMBED or "no"))
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
