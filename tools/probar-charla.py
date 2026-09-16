# Pruebas del worker de conversacion (charla_worker.py) SIN red: el troceo en
# frases, la limpieza para la voz, las marcas [ORDEN] y [API], el camino (API
# primero y el local de respaldo, 15/09) y el olvido, con respuestas de mentira.
#
#   python tools\probar-charla.py
import os
import sys
import json
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import charla_worker as cw  # noqa: E402

mal = 0


def comp(etq, ok, det=""):
    global mal
    if not ok:
        mal += 1
    print("  %s  %s%s" % ("OK  " if ok else "MAL ", etq, ("  -> %s" % (det,)) if det != "" else ""))


print("--- los datos que Nova ya sabe llegan a la charla (16/09) ---")
_d = cw.texto_datos({"datos": "son las 21:30 del martes 15 de septiembre. no hay nada descargandose en Steam"})
comp("la hora y las descargas entran en el contexto", "21:30" in _d and "descargandose" in _d, _d[:70])
comp("y se le dice que no diga que no puede saberlos", "NUNCA digas que no puedes" in _d)
comp("sin datos, no se le cuela nada", cw.texto_datos({}) == "" and cw.texto_datos({"datos": "   "}) == "")
comp("un dato larguisimo se recorta", len(cw.texto_datos({"datos": "x" * 2000})) < 800)
comp("si viene algo que no es texto, se ignora", cw.texto_datos({"datos": 5}) == "")

print("--- troceo en frases ---")
t = cw.Troceador()
salen = []
for trozo in ["Hola, ", "¿qué tal estás hoy? Yo ", "muy bien, gracias por preguntar."]:
    salen += t.meter(trozo)
comp("la primera frase sale en cuanto termina", salen == ["Hola, ¿qué tal estás hoy?"], salen)
salen += t.cerrar()
comp("y el resto al cerrar", salen[-1] == "Yo muy bien, gracias por preguntar.", salen)
t = cw.Troceador()
comp("una frase muy corta espera a la siguiente", t.meter("Vale. ") == [])
comp("y se junta con ella", t.meter("Te cuento lo que he pensado. ") == ["Vale. Te cuento lo que he pensado."])
t = cw.Troceador()
comp("sin puntos, se corta antes de 200 letras", len(t.meter("palabra " * 40)[0]) <= 200)
t = cw.Troceador()
larga = t.meter("Hollow Knight es un juego precioso de explorar, con un mundo enorme lleno de secretos, jefes muy dificiles y ")
comp("una primera frase larga sin punto sale por su ultima coma", larga == ["Hollow Knight es un juego precioso de explorar, con un mundo enorme lleno de secretos,"], larga)
comp("y las siguientes esperan a su punto como siempre", t.meter("una musica que te acompaña, sin prisa ninguna, durante horas y horas de partida ") == [])
comp("limpia asteriscos, listas y emojis", cw.limpiar("- **Claro** 😀 que si") == "Claro que si", cw.limpiar("- **Claro** 😀 que si"))
comp("lo que pide internet va a la API", cw.necesita_api("dime las noticias de hoy") and not cw.necesita_api("hoy estoy cansada"))
# datos concretos sobre algo (quien lo hizo, de que va): el 3B se los inventa (14/09)
comp("los datos concretos van a la API", all(cw.pide_datos(t) for t in ("¿Qué opinas de Hades?", "quién hizo hollow knight", "de qué va little nightmares", "háblame de silent hill", "cuéntame algo de goose goose duck", "háblame un poco de hollow knight en tres o cuatro frases")))
comp("la charla normal NO va a la API por eso", not any(cw.pide_datos(t) for t in ("estoy muy cansado hoy", "cuéntame un chiste", "me gusta hollow knight", "abre steam")))
err = "memoria: revision fallida (Illegal header value b'sk-ant-api03-AbC_dEf-123\\n')"
comp("una clave NUNCA sale hacia el log", "sk-ant" not in cw.seguro(err) and "[clave oculta]" in cw.seguro(err), cw.seguro(err))
os.environ["ANTHROPIC_API_KEY"] = "falsa\n"
comp("la clave con salto de linea al final se limpia", cw._cabeceras()["x-api-key"] == "falsa")

print("--- el principio puede ser una marca ---")
i = cw.Inicio([cw.MARCA_ORDEN, cw.MARCA_API])
comp("'[OR' todavia puede ser marca: espera", i.meter("[OR")[0] == "espera")
comp("'[ORDEN]' es la marca", i.meter("DEN]") == ("marca", "[ORDEN]"))
i = cw.Inicio([cw.MARCA_ORDEN])
comp("texto normal sale entero", i.meter("Claro") == ("sigue", "Claro") and i.meter(" que si") == ("sigue", " que si"))
i = cw.Inicio([cw.MARCA_ORDEN])
i.meter("[ORDEN")
comp("una marca sin cerrar al final tambien cuenta", i.final() == ("marca", "[ORDEN]"))
i = cw.Inicio([cw.MARCA_ORDEN, cw.MARCA_API])
i.meter("[ABRIR LA CARPETA")
comp("la etiqueta que se invento el 3B de verdad cuenta como orden", i.meter(" DE DESCARGAS] ¿Algo mas?") == ("marca", "[ORDEN]"))
i = cw.Inicio([cw.MARCA_ORDEN, cw.MARCA_API])
comp("una etiqueta que menciona la API es la API", i.meter("[NECESITO API]") == ("marca", "[API]"))
i = cw.Inicio([cw.MARCA_ORDEN])
comp("si la API no vale aqui, [API] se toma como orden y no se lee", i.meter("[API]")[0] == "marca")
comp("etiquetas sueltas en mitad no se leen", cw.limpiar("Hecho [NOTA] y listo") == "Hecho y listo", cw.limpiar("Hecho [NOTA] y listo"))


class Resp:
    def __init__(self, lineas, estado=200, error=b""):
        self.lineas = lineas
        self.status_code = estado
        self.error = error

    def iter_lines(self):
        for l in self.lineas:
            yield l

    def read(self):
        return self.error

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def local(*trozos):
    return [json.dumps({"message": {"content": x}, "done": False}) for x in trozos] + [json.dumps({"done": True})]


def api(*trozos):
    return ["data: " + json.dumps({"type": "content_block_delta", "delta": {"type": "text_delta", "text": x}}) for x in trozos]


guion = []
llamadas = []


def falso_stream(metodo, url, **kw):
    llamadas.append((url, kw.get("json")))
    r = guion.pop(0)
    if isinstance(r, Exception):
        raise r
    return r


cw.httpx.stream = falso_stream
eventos = []
cw.salida = lambda ev, idp=0, **c: eventos.append(dict(ev=ev, id=idp, **c))


def frases():
    return [e["texto"] for e in eventos if e["ev"] == "frase"]


def fin():
    return [e for e in eventos if e["ev"] in ("fin", "err", "orden", "delegar")][-1]


def hablar(idp, texto, *respuestas):
    del eventos[:]
    guion[:] = list(respuestas)
    cw.responder({"op": "hablar", "id": idp, "texto": texto})
    return fin()


print("--- camino: la API primero, el local de respaldo (15/09) ---")
os.environ["ANTHROPIC_API_KEY"] = "falsa"
cw.api_rota_hasta = 0
cw.historial.clear()
del llamadas[:]
f = hablar(1, "hola nova", Resp(api("Me alegro mucho de oírte. ", "¿Qué tal ha ido el día?")))
comp("con API, la charla normal la contesta la API", f.get("origen") == "api", f)
comp("frase a frase", frases() == ["Me alegro mucho de oírte.", "¿Qué tal ha ido el día?"], frases())
comp("se recuerda lo hablado", [m["role"] for m in cw.historial] == ["user", "assistant"])
comp("y el local ni se toca (ni RAM ni espera)", [u for u, _ in llamadas] == ["https://api.anthropic.com/v1/messages"], [u for u, _ in llamadas])

f = hablar(2, "abreme la carpeta de capturas", Resp(api("[ORD", "EN]")))
comp("algo que hacer: la API lo devuelve como orden", f["ev"] == "orden" and f["texto"] == "abreme la carpeta de capturas" and frases() == [], f)
comp("y la orden no queda en la charla", len(cw.historial) == 2)

f = hablar(3, "abre steam de una vez, no me pidas disculpas", Resp(api("Tienes toda la razón. ", "Voy a hacerlo ahora.\n\n[ORD", "EN]")))
comp("la marca [ORDEN] al final tambien es una orden (15/09)", f["ev"] == "orden" and f["texto"] == "abre steam de una vez, no me pidas disculpas", (f, frases()))
comp("y la marca no se dice en voz alta", not any("ORDEN" in x for x in frases()), frases())
comp("ni la orden queda en la charla", len(cw.historial) == 2, len(cw.historial))

f = hablar(4, "otra dificil", Resp([], 400, b'{"error":{"message":"Your credit balance is too low"}}'),
           Resp(local("No lo sé con seguridad, ", "pero te cuento lo que recuerdo.")))
comp("la API sin saldo: contesta el local", f.get("origen") == "local" and frases() == ["No lo sé con seguridad, pero te cuento lo que recuerdo."], (f, frases()))
comp("y no reintenta la API en un rato", not cw.api_disponible())
comp("el local de respaldo no puede pedir la API", cw.MARCA_API not in llamadas[-1][1]["messages"][0]["content"])
comp("el local lleva contexto corto (poca RAM)", llamadas[-1][1]["options"]["num_ctx"] == 1536 and llamadas[-1][1]["keep_alive"] == "2m")

f = hablar(9, "cuentame un chiste", Resp(local("¿Por qué los pájaros no usan Facebook? ", "因为他们找不到巢。", " Otra cosa más.")))
comp("si se pasa al chino, se corta ahi y no se lee", f.get("origen") == "local" and frases() == ["¿Por qué los pájaros no usan Facebook?"], (f, frases()))
comp("y lo guardado en la charla va sin chino", "因" not in cw.historial[-1]["content"], cw.historial[-1]["content"])

f = hablar(5, "cuentame un chiste", cw.httpx.ConnectError("sin ollama"))
comp("sin Ollama ni API: error con el motivo", f["ev"] == "err" and "ollama" in f["texto"], f)
comp("el turno fallido no queda en la memoria", cw.historial[-1]["role"] == "assistant")

cw.api_rota_hasta = 0
f = hablar(6, "busca en internet a que hora abre el museo", Resp(api("Hoy abre el museo a las diez. ")))
comp("lo que pide internet va directo a la API", f.get("origen") == "api" and llamadas[-1][0].startswith("https://api.anthropic.com"), f)
comp("y con busqueda web", (llamadas[-1][1].get("tools") or [{}])[0].get("name") == "web_search")

# SIN API, un dato concreto no lo contesta el local: se lo inventaria (14/09)
os.environ["ANTHROPIC_API_KEY"] = ""
antes = len(cw.historial)
f = hablar(10, "¿Quién hizo Hollow Knight?")
comp("sin API, un dato concreto se devuelve al asistente", f["ev"] == "delegar" and f["texto"] == "¿Quién hizo Hollow Knight?", f)
comp("y no queda en la charla", len(cw.historial) == antes, len(cw.historial))
del eventos[:]
guion[:] = [Resp(local("Creo que lo hizo un estudio pequeño. "))]
cw.responder({"op": "hablar", "id": 11, "texto": "¿Quién hizo Hollow Knight?", "sin_delegar": True})
comp("si el asistente no tiene a quien pasarlo, lo contesta el local", fin().get("origen") == "local", fin())
comp("la charla normal sin API sigue en el local", hablar(12, "hoy estoy contento", Resp(local("Me alegro mucho, cuéntame. "))).get("origen") == "local")
os.environ["ANTHROPIC_API_KEY"] = "falsa"

cw.parar.set()
f = hablar(7, "habla", Resp(local("Esto no ", "debería oírse.")))
comp("parar corta la respuesta y no la recuerda", f.get("origen") == "parado" and frases() == [], f)
cw.parar.clear()

cw.ultima_charla = time.time() - 400
hablar(8, "hola otra vez", Resp(api("Hola de nuevo, ¿qué me cuentas?")))
comp("tras 5 min sin hablar, la charla empieza de cero", len(cw.historial) == 2, len(cw.historial))

cw.historial[:] = [{"role": "assistant", "content": "x"}] + [{"role": "user" if n % 2 == 0 else "assistant", "content": str(n)} for n in range(14)]
cw.recortar()
comp("la memoria se recorta y empieza por el usuario", len(cw.historial) <= cw.MAX_HISTORIAL and cw.historial[0]["role"] == "user", len(cw.historial))

print("--- con su propio cerebro ---")
import shutil  # noqa: E402
import tempfile  # noqa: E402
import charla_memoria as cm  # noqa: E402

carpeta = tempfile.mkdtemp(prefix="nova-charla-cerebro-")
try:
    cw.cerebro = cm.Cerebro(carpeta)
    cw.api_rota_hasta = 0
    cw.historial.clear()
    perfil = os.path.join(carpeta, "perfil.md")
    with open(perfil, "w", encoding="utf-8") as fp:
        fp.write("# Perfil\n- Su juego favorito es Hades\n")
    cw.RUTA_PERFIL = perfil

    f = hablar(20, "¿Qué es un agujero negro?", Resp(api("Es una región del espacio de la que ni la luz escapa. ")))
    comp("la API contesta y se aprende firme", f.get("origen") == "api" and cw.cerebro.balance()["respuestas"] == 1, cw.cerebro.balance())
    antes = len(llamadas)

    class EmbedContador:
        nombre = "contador"
        n = 0

        def vectores(self, textos):
            EmbedContador.n += 1
            return [[1.0, 0.0] for _ in textos]
    cw.cerebro.embedder = EmbedContador()
    f = hablar(21, "oye nova, ¿qué es un agujero negro?")
    comp("la segunda vez lo dice de memoria, sin llamar a nadie", f.get("origen") == "memoria" and len(llamadas) == antes and frases() == ["Es una región del espacio de la que ni la luz escapa."], (f, frases()))
    comp("y si lo encuentra por palabras, ni carga el modelo de significado", EmbedContador.n == 0, EmbedContador.n)
    guion[:] = [Resp(api("Es un felino grande. "))]
    hablar(211, "¿Qué es un tigre?")
    comp("sin nada parecido por palabras tampoco lo carga (RAM)", EmbedContador.n == 0, EmbedContador.n)
    cw.cerebro.datos["recuerdos"] = [r for r in cw.cerebro.datos["recuerdos"] if "tigre" not in r["pregunta"].lower()]
    cw.cerebro._cambio()
    cw.cerebro.datos["pendientes"] = [j for j in cw.cerebro.datos["pendientes"] if "tigre" not in j["pregunta"].lower()]
    cw.cerebro.embedder = None

    cw.api_rota_hasta = time.time() + 999   # lo que sigue es del local: con la API caida
    f = hablar(22, "¿Cuánto duerme un oso polar?", Resp(local("El oso polar puede vivir sin dormir. ")))
    comp("lo del local entra provisional", f.get("origen") == "local" and cw.cerebro.balance()["provisionales"] == 1, cw.cerebro.balance())
    f = hablar(23, "¿cuánto duerme un oso polar?", Resp(local("Unas ocho horas. ")))
    sistema = llamadas[-1][1]["messages"][0]["content"]
    comp("lo provisional NO se repite: vuelve al modelo con la pista marcada", f.get("origen") == "local" and "SIN CONFIRMAR" in sistema, sistema[-300:])
    comp("y el modelo lleva el perfil de braya", "Su juego favorito es Hades" in sistema)

    cw.api_rota_hasta = 0
    del eventos[:]
    guion[:] = [Resp(api("Tienes razón, duermen unas siete u ocho horas. "))]
    cw.responder({"op": "hablar", "id": 24, "texto": "eso no es verdad", "duda": True})   # la marca la pone Send-Charla
    f = fin()
    comp("'eso no es verdad': a la API primero", f.get("origen") == "api" and llamadas[-1][0].startswith("https://api.anthropic.com"), f)

    f = hablar(25, "¿Qué es un volcán?", Resp(api("Una montaña que expulsa lava. ")))
    antes_b = cw.cerebro.balance()
    del eventos[:]
    cw.api_rota_hasta = time.time() + 999   # con el local, para ver su prompt
    guion[:] = [Resp(local("Un tsunami es una ola enorme. "))]
    cw.responder({"op": "hablar", "id": 26, "texto": "¿Qué es un tsunami?", "invitado": True})
    cw.api_rota_hasta = 0
    sistema = llamadas[-1][1]["messages"][0]["content"]
    comp("de un invitado no se aprende", cw.cerebro.balance() == antes_b, (antes_b, cw.cerebro.balance()))
    comp("y no lleva el perfil de braya", "Su juego favorito es Hades" not in sistema)
    comp("de un invitado no queda nada pendiente", all(j["pregunta"] != "¿Qué es un tsunami?" for j in cw.cerebro.datos["pendientes"]))

    print("--- la revision en segundo plano ---")
    del eventos[:]
    cw.llamar_api_simple = lambda s, t, max_tokens=500: json.dumps({
        "tipo_turno": "charla", "respuesta_correcta": True, "datos_usuario": ["A braya le encanta Hades"],
        "estilo": ["respuestas cortas"], "temas": ["espacio"], "hechos": [], "recuerdo": ""})
    cw.ocupado.set()
    comp("mientras contesta, no revisa", cw.revisar_una() is False)
    cw.ocupado.clear()
    pendientes_antes = len(cw.cerebro.datos["pendientes"])
    comp("en reposo revisa un turno", cw.revisar_una() is True and len(cw.cerebro.datos["pendientes"]) == pendientes_antes - 1)
    comp("y manda al asistente lo que es para el perfil", any(e["ev"] == "dato" and e["texto"] == "A braya le encanta Hades" for e in eventos), eventos)

    def api_rota(s, t, max_tokens=500):
        raise RuntimeError("api 400")
    cw.llamar_api_simple = api_rota
    job = cw.cerebro.siguiente_pendiente()
    cw.revisar_una()
    j2 = [j for j in cw.cerebro.datos["pendientes"] if j["id"] == job["id"]]
    comp("si la API falla, el turno sigue pendiente para luego", j2 and j2[0]["intentos"] == 1)
    os.environ.pop("ANTHROPIC_API_KEY", None)
    comp("sin API no revisa (y nada se da por bueno)", cw.revisar_una() is False)
finally:
    cw.cerebro = None
    shutil.rmtree(carpeta, ignore_errors=True)

print("--- trivia, resumen de mensajes, ayuda de juego y ordenes en la charla ---")
carpeta2 = tempfile.mkdtemp(prefix="nova-charla-trivia-")
try:
    cw.cerebro = cm.Cerebro(carpeta2)
    for q, r in [("¿Quién pintó la Mona Lisa?", "La pintó Leonardo da Vinci."), ("¿Qué es un volcán?", "Una montaña que expulsa lava."),
                 ("¿Cuántas patas tiene una araña?", "Una araña tiene ocho patas.")]:
        cw.atender({"op": "aprender", "pregunta": q, "respuesta": r, "origen": "api"})
    comp("aprende lo que contesta otro cerebro (Claude Code)", cw.cerebro.balance()["respuestas"] == 3, cw.cerebro.balance())
    del eventos[:]
    antes = len(llamadas)
    cw.atender({"op": "trivia", "id": 40})
    preg = frases()
    comp("trivia: pregunta de lo que sabe, sin llamar a ningun modelo", fin().get("origen") == "trivia" and preg and preg[0].startswith("Ahí va:") and len(llamadas) == antes, preg)
    clave = sorted(t for t in cm.fichas(cw.trivia["r"]["respuesta"]) - cm.fichas(cw.trivia["r"]["pregunta"]) if not t.startswith("?"))[0]
    del eventos[:]
    cw.atender({"op": "hablar", "id": 41, "texto": clave})
    comp("y juzga la respuesta al momento", fin().get("origen") == "trivia-respuesta" and frases() and frases()[0].startswith("¡Correcto!"), (clave, frases()))
    cw.atender({"op": "trivia", "id": 42})
    del eventos[:]
    cw.atender({"op": "hablar", "id": 43, "texto": "ni idea, me rindo"})
    comp("rendirse da la respuesta", frases() and frases()[0].startswith("La respuesta es:"), frases())

    os.environ["ANTHROPIC_API_KEY"] = "falsa"
    cw.api_rota_hasta = 0
    pend0 = cw.cerebro.balance()["pendientes"]
    del eventos[:]
    guion[:] = [Resp(local("Ana y Leo quieren jugar a las diez. ", "Tu madre pregunta por la cena."))]
    cw.atender({"op": "resumir", "id": 44, "texto": "Discord, Ana: jugamos a las 10?. Discord, Leo: yo me apunto. WhatsApp, Mama: vienes a cenar?"})
    comp("mensajes resumidos con el modelo LOCAL", fin().get("origen") == "resumen" and llamadas[-1][0].startswith(cw.OLLAMA), fin())
    comp("y nada de eso se aprende ni queda en la charla", cw.cerebro.balance()["pendientes"] == pend0 and not any("Ana" in m["content"] for m in cw.historial))
    del eventos[:]
    guion[:] = [cw.httpx.ConnectError("sin ollama")]
    cw.atender({"op": "resumir", "id": 45, "texto": "WhatsApp, Mama: vienes?"})
    comp("sin modelo local, el resumen NO va a la API (son tus mensajes)", fin()["ev"] == "err" and llamadas[-1][0].startswith(cw.OLLAMA), fin())

    cw.historial[:] = [{"role": "user", "content": "¿a qué hora cierra la tienda?"}, {"role": "assistant", "content": "Cierra a las ocho."}]
    cw.ultima_charla = time.time()
    posts = []

    class RespPost:
        status_code = 200

        def raise_for_status(self):
            pass

        def json(self):
            # formato de Ollama y de la API a la vez: la reescritura prueba primero la API (15/09)
            return {"message": {"content": "recuérdame ir a la tienda a las siete y media"},
                    "content": [{"type": "text", "text": "recuérdame ir a la tienda a las siete y media"}]}
    cw.httpx.post = lambda url, **kw: (posts.append(kw.get("json")), RespPost())[1]
    del eventos[:]
    guion[:] = [Resp(api("[ORDEN]"))]
    cw.atender({"op": "hablar", "id": 46, "texto": "pues recuérdamelo luego"})
    f = fin()
    comp("una orden con 'lo' o 'luego' se reescribe con lo hablado", f["ev"] == "orden" and f["texto"] == "recuérdame ir a la tienda a las siete y media" and f.get("original") == "pues recuérdamelo luego", f)
    comp("viendo la conversacion", posts and "Cierra a las ocho." in json.dumps(posts[-1], ensure_ascii=False))
    del eventos[:]
    guion[:] = [Resp(api("[ORDEN]"))]
    cw.atender({"op": "hablar", "id": 47, "texto": "abre la carpeta de descargas"})
    comp("una orden completa no se toca", fin()["texto"] == "abre la carpeta de descargas" and len(posts) == 1, fin())

    del eventos[:]
    guion[:] = [Resp(api("Esquiva sus embestidas y ataca por detrás. "))]
    cw.atender({"op": "hablar", "id": 48, "texto": "En el juego Hades: como mato a este jefe", "buscar": True, "ayuda": True, "juego": "Hades"})
    comp("ayuda con el juego: a la API con busqueda web", fin().get("origen") == "api" and (llamadas[-1][1].get("tools") or [{}])[0].get("name") == "web_search", fin())
    comp("y explicada, no en una frase de juego", "ayuda con su partida" in llamadas[-1][1]["system"] and "una sola frase corta" not in llamadas[-1][1]["system"])
finally:
    cw.cerebro = None
    shutil.rmtree(carpeta2, ignore_errors=True)

print("--- diario de conversaciones ---")
carpeta3 = tempfile.mkdtemp(prefix="nova-charla-diario-")
dir_antes = cw.CARPETA_CEREBRO
try:
    cw.CARPETA_CEREBRO = carpeta3
    cw.cerebro = None
    cw.historial.clear()
    guion[:] = [Resp(api("Me alegro de que te guste Hades. "))]
    cw.responder({"op": "hablar", "id": 60, "texto": "me encanta Hades"})
    hoy = time.strftime("%Y-%m-%d")
    ruta_hoy = os.path.join(carpeta3, "charla-%s.jsonl" % hoy)
    comp("cada charla del dia se apunta", os.path.exists(ruta_hoy) and "Hades" in open(ruta_hoy, encoding="utf-8").read())
    guion[:] = [Resp(api("Vale. "))]
    cw.responder({"op": "hablar", "id": 61, "texto": "secreto de invitado", "invitado": True})
    comp("lo de un invitado no", "invitado" not in open(ruta_hoy, encoding="utf-8").read())
    comp("el dia de hoy no se resume todavia", cw.resumir_dias_pasados(hoy) is False and os.path.exists(ruta_hoy))
    ayer = "2026-01-01"
    os.replace(ruta_hoy, os.path.join(carpeta3, "charla-%s.jsonl" % ayer))
    posts_d = []

    class RespDiario:
        status_code = 200

        def raise_for_status(self):
            pass

        def json(self):
            return {"message": {"content": "- braya contó que le encanta Hades\n* hablaron de juegos"}}
    cw.httpx.post = lambda url, **kw: (posts_d.append(kw.get("json")), RespDiario())[1]
    del eventos[:]
    comp("al dia siguiente se resume con el modelo local", cw.resumir_dias_pasados(hoy) is True and posts_d and posts_d[-1]["model"] == cw.MODELO_LOCAL)
    ev_d = [e for e in eventos if e["ev"] == "diario"]
    comp("y va al diario de ese dia, en viñetas", ev_d and ev_d[0]["fecha"] == ayer and ev_d[0]["texto"] == "- braya contó que le encanta Hades\n- hablaron de juegos", ev_d)
    comp("el registro en bruto se borra", not os.path.exists(os.path.join(carpeta3, "charla-%s.jsonl" % ayer)))
    with open(os.path.join(carpeta3, "charla-2026-01-02.jsonl"), "w", encoding="utf-8") as fd:
        fd.write(json.dumps({"h": "10:00", "braya": "hola", "nova": "hola"}) + "\n")

    def post_roto(url, **kw):
        raise RuntimeError("sin ollama")
    cw.httpx.post = post_roto
    comp("sin modelo local, se queda para otro rato", cw.resumir_dias_pasados(hoy) is False and os.path.exists(os.path.join(carpeta3, "charla-2026-01-02.jsonl")))
finally:
    cw.CARPETA_CEREBRO = dir_antes
    shutil.rmtree(carpeta3, ignore_errors=True)

if mal:
    print("%d casos MAL" % mal)
    sys.exit(1)
print("todo correcto")
