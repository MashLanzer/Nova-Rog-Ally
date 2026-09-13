# Pruebas del worker de conversacion (charla_worker.py) SIN red: el troceo en
# frases, la limpieza para la voz, las marcas [ORDEN] y [API], el camino hibrido
# (local -> API -> local) y el olvido, con respuestas de mentira.
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
comp("limpia asteriscos, listas y emojis", cw.limpiar("- **Claro** 😀 que si") == "Claro que si", cw.limpiar("- **Claro** 😀 que si"))
comp("lo que pide internet va a la API", cw.necesita_api("dime las noticias de hoy") and not cw.necesita_api("hoy estoy cansada"))

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
    return [e for e in eventos if e["ev"] in ("fin", "err", "orden")][-1]


def hablar(idp, texto, *respuestas):
    del eventos[:]
    guion[:] = list(respuestas)
    cw.responder({"op": "hablar", "id": idp, "texto": texto})
    return fin()


print("--- camino hibrido ---")
os.environ["ANTHROPIC_API_KEY"] = "falsa"
cw.historial.clear()
f = hablar(1, "hola nova", Resp(local("Me alegro mucho de oírte. ", "¿Qué tal ha ido el día?")))
comp("charla normal: la contesta el local", f.get("origen") == "local", f)
comp("frase a frase", frases() == ["Me alegro mucho de oírte.", "¿Qué tal ha ido el día?"], frases())
comp("se recuerda lo hablado", [m["role"] for m in cw.historial] == ["user", "assistant"])
comp("el local lleva contexto corto (poca RAM)", llamadas[-1][1]["options"]["num_ctx"] == 1024 and llamadas[-1][1]["keep_alive"] == "2m")

f = hablar(2, "abreme la carpeta de capturas", Resp(local("[ORD", "EN]")))
comp("algo que hacer: el local lo devuelve como orden", f["ev"] == "orden" and f["texto"] == "abreme la carpeta de capturas" and frases() == [], f)
comp("y la orden no queda en la charla", len(cw.historial) == 2)

f = hablar(3, "explicame la teoria de cuerdas", Resp(local("[AP", "I]")), Resp(api("Imagina que todo está hecho de cuerdas diminutas. ")))
comp("el local dice [API]: pasa a la API sin decir la marca", f.get("origen") == "api" and frases() == ["Imagina que todo está hecho de cuerdas diminutas."], (f, frases()))

f = hablar(4, "otra dificil", Resp(local("[API]")), Resp([], 400, b'{"error":{"message":"Your credit balance is too low"}}'),
           Resp(local("No lo sé con seguridad, ", "pero te cuento lo que recuerdo.")))
comp("la API sin saldo: vuelve al local", f.get("origen") == "local" and frases() == ["No lo sé con seguridad, pero te cuento lo que recuerdo."], (f, frases()))
comp("y no reintenta la API en un rato", not cw.api_disponible())
comp("el ultimo local ya no puede pedir la API", cw.MARCA_API not in llamadas[-1][1]["messages"][0]["content"])

f = hablar(5, "cuentame un chiste", cw.httpx.ConnectError("sin ollama"))
comp("sin Ollama ni API: error con el motivo", f["ev"] == "err" and "ollama" in f["texto"], f)
comp("el turno fallido no queda en la memoria", cw.historial[-1]["role"] == "assistant")

cw.api_rota_hasta = 0
f = hablar(6, "busca en internet a que hora abre el museo", Resp(api("Hoy abre el museo a las diez. ")))
comp("lo que pide internet va directo a la API", f.get("origen") == "api" and llamadas[-1][0].startswith("https://api.anthropic.com"), f)
comp("y con busqueda web", (llamadas[-1][1].get("tools") or [{}])[0].get("name") == "web_search")

f = hablar(9, "cuentame un chiste", Resp(local("¿Por qué los pájaros no usan Facebook? ", "因为他们找不到巢。", " Otra cosa más.")))
comp("si se pasa al chino, se corta ahi y no se lee", f.get("origen") == "local" and frases() == ["¿Por qué los pájaros no usan Facebook?"], (f, frases()))
comp("y lo guardado en la charla va sin chino", "因" not in cw.historial[-1]["content"], cw.historial[-1]["content"])

cw.parar.set()
f = hablar(7, "habla", Resp(local("Esto no ", "debería oírse.")))
comp("parar corta la respuesta y no la recuerda", f.get("origen") == "parado" and frases() == [], f)
cw.parar.clear()

cw.ultima_charla = time.time() - 400
hablar(8, "hola otra vez", Resp(local("Hola de nuevo, ¿qué me cuentas?")))
comp("tras 5 min sin hablar, la charla empieza de cero", len(cw.historial) == 2, len(cw.historial))

cw.historial[:] = [{"role": "assistant", "content": "x"}] + [{"role": "user" if n % 2 == 0 else "assistant", "content": str(n)} for n in range(14)]
cw.recortar()
comp("la memoria se recorta y empieza por el usuario", len(cw.historial) <= cw.MAX_HISTORIAL and cw.historial[0]["role"] == "user", len(cw.historial))

if mal:
    print("%d casos MAL" % mal)
    sys.exit(1)
print("todo correcto")
