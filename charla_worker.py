# Worker de CONVERSACION de Nova (13/09): hibrido, sin Claude Code.
#
# No hay "modo conversacion": el asistente le pasa lo que dices cuando no es una
# orden que ya sabe hacer. Aqui se decide si era charla (se contesta), algo que
# hay que HACER (se devuelve al asistente) o algo que pide internet (la API).
#
# Se mantiene VIVO (como tts_worker) y lee pedidos JSON de stdin, uno por linea:
#   {"op": "hablar", "id": 3, "texto": "...", "juego": "Hades"}
#   {"op": "parar"}      corta la respuesta en curso
#   {"op": "olvidar"}    borra lo hablado
#   {"op": "descargar"}  saca el modelo local de la RAM (al abrir un juego)
# Escribe por stdout un JSON por linea, SOLO ASCII (los acentos van escapados:
# PowerShell lee la salida con la codificacion de la consola y los romperia):
#   {"ev": "frase", "id": 3, "texto": "..."}   una frase lista para decir
#   {"ev": "fin", "id": 3, "origen": "local"}  termino (local | api | parado)
#   {"ev": "orden", "id": 3, "texto": "..."}   no era charla: hay que hacerlo
#   {"ev": "err", "id": 3, "texto": "..."}     no pudo contestar
#   {"ev": "info", "texto": "..."}             para el log
#
# PRIMERO EL LOCAL (Ollama con Qwen2.5 3B: gratis y en esta maquina). Pasa a la
# API de Claude si Ollama no esta, si no empieza a tiempo, o si el propio modelo
# dice que la pregunta le queda grande (contesta solo "[API]"). Lo que pide
# internet (noticias, precios...) va directo a la API, con busqueda web. Si la
# API falla (sin saldo, sin clave), vuelve al local.
#
# POCA RAM (lo pidio braya): contexto de 1024, el modelo se descarga solo a los
# 2 min sin hablar, y el asistente lo descarga al abrir un juego. Ollama esta
# configurado con un solo modelo, una sola peticion y cache de 8 bits.
#
# Uso:  python charla_worker.py <modelo_local> <modelo_api>

import sys
import os
import re
import json
import time
import queue
import threading

import httpx

OLLAMA = "http://127.0.0.1:11434"
MODELO_LOCAL = sys.argv[1] if len(sys.argv) > 1 else "qwen2.5:3b"
MODELO_API = sys.argv[2] if len(sys.argv) > 2 else "claude-haiku-4-5"
ESPERA_TROZO = 25.0        # s maximos entre trozos del local (en frio carga el modelo)
MAX_HISTORIAL = 12         # mensajes (6 idas y vueltas)
OLVIDO_S = 300             # tras 5 min sin hablar, la charla empieza de cero
MIN_FRASE = 25             # letras: las frases muy cortas se juntan con la siguiente
MAX_FRASE = 200
MARCA_API = "[API]"
MARCA_ORDEN = "[ORDEN]"

SISTEMA = (
    "Eres Nova, la asistente de voz de braya en su consola ROG Ally. Hablas en español, "
    "de tú a tú, como una amiga cercana y con chispa. Todo lo que escribes se dice en voz "
    "alta: frases cortas y naturales, sin listas, sin asteriscos, sin emojis ni formato. "
    "Responde SIEMPRE y solo en español, nunca en chino ni en otro idioma. "
    "Contesta en una a tres frases, salvo que te pida más. Si viene a cuento, termina con "
    "una pregunta para seguir la conversación."
)
SISTEMA_ORDEN = (
    " Si braya te pide que HAGAS algo en su consola o en Windows (abrir o cerrar programas "
    "o juegos, instalar, buscar o mover archivos, cambiar ajustes, escribir en una ventana), "
    "no lo expliques ni digas que no puedes: responde SOLO, exactamente: [ORDEN]\n"
    "Ejemplos: 'abre la carpeta de descargas' -> [ORDEN]. 'instálame Discord' -> [ORDEN]. "
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

historial = []
pedidos = queue.Queue()
parar = threading.Event()
api_rota_hasta = 0.0
ultima_charla = 0.0
bloqueo_salida = threading.Lock()


def salida(ev, idp=0, **campos):
    d = {"ev": ev, "id": idp}
    d.update(campos)
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


class Troceador:
    """Parte el texto que llega a trozos en frases, para decirlas en cuanto estan."""

    def __init__(self):
        self.buf = ""

    def meter(self, trozo):
        self.buf += trozo
        salen = []
        while True:
            corte = None
            for m in re.finditer(r"[.!?…]+(?=\s)|\n+", self.buf):
                if len(self.buf[:m.end()].strip()) >= MIN_FRASE:
                    corte = m.end()
                    break
            if corte is None and len(self.buf) > MAX_FRASE:
                i = max(self.buf.rfind(", ", 0, MAX_FRASE), self.buf.rfind(" ", 0, MAX_FRASE))
                corte = i + 1 if i > 40 else MAX_FRASE
            if corte is None:
                break
            f = limpiar(self.buf[:corte])
            self.buf = self.buf[corte:]
            if f:
                salen.append(f)
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
    return bool(os.environ.get("ANTHROPIC_API_KEY")) and time.time() >= api_rota_hasta


def sistema_con(extra, marcas):
    s = SISTEMA + extra
    if MARCA_ORDEN in marcas:
        s += SISTEMA_ORDEN
    if MARCA_API in marcas:
        s += SISTEMA_API
    return s


def generar_local(mensajes, marcas, emitir, extra=""):
    cuerpo = {
        "model": MODELO_LOCAL,
        "messages": [{"role": "system", "content": sistema_con(extra, marcas)}] + mensajes,
        "stream": True,
        "keep_alive": "2m",
        # 0.5: con 0.7 el 3B se inventaba datos con demasiada soltura
        "options": {"num_predict": 200, "temperature": 0.5, "num_ctx": 1024},
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


def generar_api(mensajes, marcas, emitir, extra="", buscar=False):
    global api_rota_hasta
    clave = os.environ.get("ANTHROPIC_API_KEY")
    if not clave:
        return "fallo", "sin clave de la API"
    cuerpo = {"model": MODELO_API, "max_tokens": 400, "system": sistema_con(extra, marcas),
              "messages": mensajes, "stream": True}
    if buscar:
        cuerpo["tools"] = [{"type": "web_search_20250305", "name": "web_search", "max_uses": 2}]
    cab = {"x-api-key": clave, "anthropic-version": "2023-06-01", "content-type": "application/json"}
    texto = ""
    troc = Troceador()
    ini = Inicio(marcas)
    try:
        with httpx.stream("POST", "https://api.anthropic.com/v1/messages", json=cuerpo, headers=cab,
                          timeout=httpx.Timeout(30.0, connect=5.0)) as r:
            if r.status_code != 200:
                err = r.read().decode("utf-8", "replace")
                # sin saldo o clave mala: no se reintenta en 10 min (cada intento cuesta segundos)
                if re.search(r"credit|billing|authentication|x-api-key|permission", err, re.IGNORECASE):
                    api_rota_hasta = time.time() + 600
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


def responder(p):
    global ultima_charla
    idp = p.get("id", 0)
    texto = (p.get("texto") or "").strip()
    if not texto:
        salida("fin", idp, origen="nada")
        return
    ahora = time.time()
    if ahora - ultima_charla > OLVIDO_S:
        historial.clear()
    ultima_charla = ahora
    historial.append({"role": "user", "content": texto})
    extra = ""
    if p.get("juego"):
        extra = " Ahora braya está jugando a %s: contesta en una sola frase corta." % p["juego"]
    dichas = []

    def emitir(f):
        if not dichas:
            salida("info", idp, texto="primera frase en %.1f s" % (time.time() - ahora))
        dichas.append(f)
        salida("frase", idp, texto=f)

    usar_api = necesita_api(texto) and api_disponible()
    intentos = ["api", "local"] if usar_api else ["local", "api", "local-sin-marca"]
    motivos = []
    marca_api_vista = False
    for origen in intentos:
        if origen == "api":
            if not api_disponible():
                motivos.append("api no disponible")
                continue
            res, dato = generar_api(list(historial), [MARCA_ORDEN], emitir, extra, buscar=usar_api or marca_api_vista)
        elif origen == "local":
            marcas = [MARCA_ORDEN] + ([MARCA_API] if api_disponible() else [])
            res, dato = generar_local(list(historial), marcas, emitir, extra)
        else:
            if not marca_api_vista:
                continue      # solo si el local se aparto para la API y la API fallo
            res, dato = generar_local(list(historial), [MARCA_ORDEN], emitir, extra)
        if res == "marca" and dato == MARCA_ORDEN:
            # no era charla: el asistente lo manda a quien sabe hacerlo
            historial.pop()
            salida("orden", idp, texto=texto)
            return
        if res == "parado":
            historial.pop()
            salida("fin", idp, origen="parado")
            return
        if res == "ok" or (res == "fallo" and dichas):
            # si ya dijo algo y luego fallo, se queda con lo dicho: repetirlo por
            # otro camino sonaria a eco
            historial.append({"role": "assistant", "content": (dato if res == "ok" else " ".join(dichas)).strip()})
            recortar()
            salida("fin", idp, origen=origen.replace("-sin-marca", ""))
            return
        if res == "marca":
            marca_api_vista = True
            motivos.append("%s: se lo pasa a la API" % origen)
        else:
            motivos.append("%s: %s" % (origen, dato))
    historial.pop()
    salida("err", idp, texto="; ".join(motivos))


def descargar():
    try:
        httpx.post(OLLAMA + "/api/generate", json={"model": MODELO_LOCAL, "keep_alive": 0}, timeout=10)
        salida("info", texto="modelo local fuera de la RAM")
    except Exception:  # noqa: BLE001
        pass


def lector():
    # bytes UTF-8 crudos: la entrada estandar de Windows no es UTF-8 por defecto
    for crudo in sys.stdin.buffer:
        try:
            p = json.loads(crudo.decode("utf-8", "replace"))
        except ValueError:
            continue
        op = p.get("op")
        if op in ("parar", "hablar"):
            parar.set()       # lo nuevo corta lo que se estuviera diciendo
        if op != "parar":
            pedidos.put(p)
    parar.set()
    pedidos.put(None)         # el asistente cerro la tuberia: se acabo


def principal():
    threading.Thread(target=lector, daemon=True).start()
    salida("info", texto="charla lista (local %s, api %s)" % (MODELO_LOCAL, MODELO_API))
    while True:
        p = pedidos.get()
        if p is None:
            return
        op = p.get("op")
        if op == "olvidar":
            historial.clear()
        elif op == "descargar":
            descargar()
        elif op == "hablar":
            parar.clear()
            try:
                responder(p)
            except Exception as e:  # noqa: BLE001
                salida("err", p.get("id", 0), texto="fallo interno: %s" % e)


if __name__ == "__main__":
    principal()
