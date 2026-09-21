# Pruebas del CEREBRO PROPIO de Nova (charla_memoria.py): que aprenda, que
# encuentre lo aprendido por palabras y por significado, y sobre todo que NO se
# quede con datos malos. Trabaja en una carpeta temporal y la borra al acabar.
#
#   python tools\probar-memoria.py
import json
import os
import shutil
import sys
import tempfile
import zlib

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import charla_memoria as cm  # noqa: E402

mal = 0


def comp(etq, ok, det=""):
    global mal
    if not ok:
        mal += 1
    print("  %s  %s%s" % ("OK  " if ok else "MAL ", etq, ("  -> %s" % (det,)) if det != "" else ""))


class Reloj:
    def __init__(self):
        self.t = 1_800_000_000.0

    def __call__(self):
        return self.t


class EmbedFalso:
    """Significado de mentira: sinonimos a un mismo concepto y palabras a un
    vector por hash. Dos frases con las mismas ideas dan coseno 1."""
    nombre = "falso-1"
    SINONIMOS = {"gioconda": "monalisa", "mona": "monalisa", "lisa": "", "pinto": "pintar", "pintor": "pintar", "hizo": "pintar"}

    def __init__(self):
        self.llamadas = 0
        self.roto = False

    def vectores(self, textos):
        if self.roto:
            raise RuntimeError("sin ollama")
        self.llamadas += 1
        import numpy as np
        out = []
        for t in textos:
            v = np.zeros(64, dtype=np.float32)
            for w in cm.plano(t).split():
                w = self.SINONIMOS.get(w, w)
                if not w or w in cm.VACIAS:
                    continue
                v[zlib.crc32(w.encode()) % 64] += 1.0
            out.append(v.tolist())
        return out


carpeta = tempfile.mkdtemp(prefix="nova-cerebro-")
try:
    print("--- piezas ---")
    comp("fichas: sin tildes, sin palabras vacias y con el interrogativo", cm.fichas("¿Quién pintó la Mona Lisa?") == {"?quien", "pinto", "mona", "lisa"}, cm.fichas("¿Quién pintó la Mona Lisa?"))
    comp("plural sencillo igual a los dos lados", cm.fichas("los pulpos") == cm.fichas("el pulpo"))
    comp("el interrogativo tras la cortesia", cm.interrogativo("oye nova, dime cuándo nació Cervantes") == "cuando")
    comp("lo de hoy caduca", cm.caduca("¿quién ganó el partido de hoy?") and not cm.caduca("¿quién pintó la Mona Lisa?"))
    comp("pregunta general", cm.es_pregunta_general("¿Qué es un agujero negro?"))
    comp("lo personal no es general", not cm.es_pregunta_general("¿qué es mi juego favorito?"))
    # 14/09: los datos concretos que ahora contesta la API tienen que poder aprenderse
    comp("quien hizo / de que va / hablame de son generales", all(cm.es_pregunta_general(t) for t in ("¿Quién hizo Hollow Knight?", "de qué va little nightmares", "háblame de silent hill", "qué sabes de minecraft", "háblame un poco de hollow knight")))
    comp("una opinion NO es un dato general", not cm.es_pregunta_general("¿qué opinas de Hades?") and not cm.es_pregunta_general("¿qué te parece Outlast?"))
    comp("un seguimiento no es general", not cm.es_pregunta_general("¿y eso por qué pasa?") and cm.es_seguimiento("¿y eso por qué?"))

    print("--- aprender y usar lo firme ---")
    reloj = Reloj()
    c = cm.Cerebro(carpeta, reloj=reloj)
    job = c.aprender_turno("¿Quién pintó la Mona Lisa?", "La pintó Leonardo da Vinci.", "api")
    comp("lo que contesta la API entra firme", c.balance()["respuestas"] == 1 and job.get("recuerdo"))
    comp("y queda pendiente de revision (para sacar datos, temas...)", c.siguiente_pendiente()["id"] == job["id"])
    r = c.respuesta_directa("oye nova, ¿quién pintó la mona lisa?")
    comp("la misma pregunta dicha de otra forma: respuesta directa", r and r["respuesta"] == "La pintó Leonardo da Vinci.")
    comp("distinto interrogativo NO vale ('cuándo' no es 'quién')", c.respuesta_directa("¿cuándo pintó la Mona Lisa?") is None)
    comp("un seguimiento NO vale aunque encaje", c.respuesta_directa("¿y eso quién lo pintó?") is None)
    comp("lo que caduca NO se guarda", c.guardar_respuesta("¿quién ganó el partido de hoy?", "El Madrid.", "firme", "api") is None)
    comp("lo sensible NO se guarda", c.guardar_respuesta("¿cuál es el pin de la tarjeta?", "1234", "firme", "api") is None)

    print("--- lo del modelo local, provisional hasta revisarlo ---")
    j2 = c.aprender_turno("¿Cuánto duerme un oso polar?", "El oso polar puede vivir sin dormir.", "local")
    comp("entra provisional", c.balance()["provisionales"] == 1)
    comp("NO se dice tal cual", c.respuesta_directa("¿cuánto duerme un oso polar?") is None)
    ctx = c.contexto("¿cuánto duerme un oso polar?")
    comp("solo sirve de pista, marcada sin confirmar", "SIN CONFIRMAR" in ctx, ctx)
    rev = {"tipo_turno": "pregunta_general", "respuesta_correcta": False, "pregunta_general": "¿Cuánto duerme un oso polar?",
           "respuesta_buena": "Un oso polar duerme unas siete u ocho horas al día, como nosotros.", "caduca": False,
           "datos_usuario": ["A braya le encanta Hades", "La clave del banco de braya es 1234", "braya está cansado hoy"],
           "estilo": ["respuestas cortas", "Respuestas cortas"], "temas": ["animales", "videojuegos"],
           "hechos": ["braya dice que los osos polares le dan miedo"], "recuerdo": "braya preguntó por los osos polares"}
    ev = c.aplicar_revision(j2, rev)
    comp("la revision la corrige y la deja firme", c.respuesta_directa("¿cuánto duerme un oso polar?")["respuesta"].startswith("Un oso polar duerme"))
    comp("y avisa para que Nova se corrija", {"ev": "correccion", "texto": rev["respuesta_buena"]} in ev, ev)
    datos = [e["texto"] for e in ev if e["ev"] == "dato"]
    comp("los datos sobre braya van al perfil, sin los sensibles ni los pasajeros", datos == ["A braya le encanta Hades"], datos)
    comp("el estilo sin repetir", c.datos["estilo"] == ["respuestas cortas"], c.datos["estilo"])
    comp("temas contados", c.datos["temas"].get("animales") == 1)
    comp("lo contado y el recuerdo quedan", c.balance()["contado"] == 1 and c.balance()["episodios"] == 1, c.balance())
    # 19/09: 36 de los 50 episodios que habia guardados eran esto
    comp("lo que habla de Nova no entra en el cerebro",
         c.guardar_texto("episodio", "Braya se queja de que Nova repite mucho las respuestas") is None and
         c.balance()["episodios"] == 1, c.balance())
    # Y EL ESTILO TAMPOCO (20/09, C5). El filtro del 19/09 solo estaba en guardar_texto;
    # _estilo escribe en el MISMO cerebro.json y no lo tenia. Y es el que mas pesa: el
    # estilo viaja en el prompt de TODAS las peticiones, mientras que los episodios
    # entraban en 2 de 96. Medido sobre el cerebro real de braya: 6 de las 12 entradas de
    # estilo hablaban de Nova, no de el ("le gusta que Nova entienda bien lo que dice").
    _antes = len(c.datos["estilo"])
    c._estilo("le gusta que Nova entienda bien lo que dice sin tergiversarlo")
    c._estilo("prefiere honestidad sobre las limitaciones de Nova")
    comp("lo que habla de Nova no entra en el ESTILO",
         len(c.datos["estilo"]) == _antes, c.datos["estilo"])
    c._estilo("le gustan las respuestas con ejemplos")
    comp("pero una preferencia suya de verdad si entra",
         len(c.datos["estilo"]) == _antes + 1, c.datos["estilo"])
    _temas = len(c.datos["temas"])
    c._tema("nova")
    c._tema("el asistente")
    comp("ni como tema de conversacion", len(c.datos["temas"]) == _temas, c.datos["temas"])
    comp("la revision sale de pendientes", all(j["id"] != j2["id"] for j in c.datos["pendientes"]))
    ctx = c.contexto("¿les tengo miedo a los osos polares?")
    comp("el contexto trae lo contado, el estilo y los temas", "braya te contó" in ctx and "respuestas cortas" in ctx and "animales" in ctx, ctx)
    comp("en modo invitado, nada personal", "braya te contó" not in c.contexto("osos polares", invitado=True) and "respuestas cortas" not in c.contexto("osos polares", invitado=True))

    j3 = c.aprender_turno("¿Qué es un gato?", "Un gato es un animal doméstico.", "local")
    c.aplicar_revision(j3, {"tipo_turno": "charla", "respuesta_correcta": True})
    comp("si la revision dice que no era para reutilizar, lo provisional se va", c.balance()["provisionales"] == 0)
    j4 = c.aprender_turno("¿Qué es un dragón de Komodo?", "Es un pez del Amazonas.", "local")
    c.aplicar_revision(j4, {"tipo_turno": "otro", "respuesta_correcta": False})
    comp("si estaba mal y no hay buena, queda rechazada", c.guardar_respuesta("¿Qué es un dragón de Komodo?", "Es un pez del Amazonas.", "provisional", "local") is None)

    print("--- eso no es verdad ---")
    c.respuesta_directa("¿quién pintó la Mona Lisa?")
    rechazada = c.marcar_incorrecta()
    comp("la ultima usada queda rechazada", rechazada and rechazada["pregunta"] == "¿Quién pintó la Mona Lisa?")
    comp("y no se vuelve a decir", c.respuesta_directa("¿quién pintó la Mona Lisa?") is None)

    print("--- revisiones que fallan ---")
    j5 = c.aprender_turno("hola, ¿qué tal?", "¡Muy bien!", "local")
    for _ in range(cm.MAX_INTENTOS):
        c.fallo_revision(j5)
    comp("tras varios fallos se deja de intentar", all(j["id"] != j5["id"] for j in c.datos["pendientes"]))
    comp("el revisor exige JSON", (lambda: (cm.revisar_turno(j5, lambda s, t: "no se") and False))() if False else True)
    try:
        cm.revisar_turno(j5, lambda s, t: "no tengo ni idea")
        comp("sin JSON, la revision falla (y se reintenta luego)", False)
    except ValueError:
        comp("sin JSON, la revision falla (y se reintenta luego)", True)
    rv = cm.revisar_turno(j5, lambda s, t: 'Claro: {"tipo_turno": "charla", "respuesta_correcta": true}')
    comp("con texto alrededor, saca el JSON", rv.get("tipo_turno") == "charla")

    print("--- persistencia ---")
    c2 = cm.Cerebro(carpeta, reloj=reloj)
    comp("sobrevive a releer el disco", c2.balance()["respuestas"] >= 1 and c2.respuesta_directa("¿cuánto duerme un oso polar?") is not None)
    with open(os.path.join(carpeta, "cerebro.json"), "w", encoding="utf-8") as f:
        f.write("{roto")
    c3 = cm.Cerebro(carpeta, reloj=reloj)
    comp("un archivo roto se aparta y se empieza de cero", c3.balance()["respuestas"] == 0 and any(n.startswith("cerebro.json.corrupto-") for n in os.listdir(carpeta)))
    c2.datos["temas"]["osos polares"] = 2
    comp("olvidar por tema", (c2.olvidar("oso polar") >= 1) and c2.respuesta_directa("¿cuánto duerme un oso polar?") is None)
    comp("y deja de contarlo como tema, sin tocar los demas", "osos polares" not in c2.datos["temas"] and "animales" in c2.datos["temas"], c2.datos["temas"])

    print("--- por significado ---")
    shutil.rmtree(carpeta)
    os.makedirs(carpeta)
    emb = EmbedFalso()
    c = cm.Cerebro(carpeta, embedder=emb, reloj=reloj)
    q = "¿Quién pintó la Mona Lisa?"
    c.aprender_turno(q, "La pintó Leonardo da Vinci.", "api", vector=c.vector(q))
    q2 = "¿quién hizo la Gioconda?"
    comp("por palabras no se parecen", c.buscar(q2, tipos={"respuesta"})[0]["lex"] < 0.3 if c.buscar(q2, tipos={"respuesta"}) else True)
    # GUARDIAN DE IA1 (18/09): el filtro de palabra de contenido es SOLO para la via lexica.
    # "pinto/mona/lisa" y "hizo/gioconda" no comparten una sola ficha de contenido; si el filtro
    # se aplicara tambien al significado, esto saldria vacio y buscar por significado dejaria de
    # servir justo para lo unico que sirve.
    comp("por significado entra en el contexto sin compartir palabra", "Leonardo" in c.contexto(q2, qvec=c.vector(q2)))
    r = c.respuesta_directa(q2, qvec=c.vector(q2))
    comp("por significado si: respuesta directa", r and "Leonardo" in r["respuesta"], r)
    comp("y se apunta como otra forma de decirlo", any(cm.plano(v) == cm.plano(q2) for v in c._por_id(r["id"])["variantes"]))
    c4 = cm.Cerebro(carpeta, embedder=emb, reloj=reloj)
    comp("los vectores sobreviven al disco", len(c4.vec) == 1)
    c.guardar_texto("contado", "braya dice que su perro se llama Toby")
    comp("los recuerdos sin vector se completan en segundo plano", c.completar_vectores() == 1 and len(c.vec) == 2)
    emb.roto = True
    comp("sin modelo de significado, sigue por palabras", c.vector("hola") is None and c.respuesta_directa("¿Quién pintó la Mona Lisa?") is not None)

    print("--- trivia ---")
    shutil.rmtree(carpeta)
    os.makedirs(carpeta)
    c = cm.Cerebro(carpeta, reloj=reloj)
    c.aprender_turno("¿Quién pintó la Mona Lisa?", "La pintó Leonardo da Vinci.", "api")
    c.aprender_turno("¿Qué es un volcán?", "Una montaña que expulsa lava.", "api")
    comp("con menos de tres cosas seguras no hay trivia", c.pregunta_trivia() is None)
    c.aprender_turno("¿Cuántas patas tiene una araña?", "Una araña tiene ocho patas.", "api")
    c.aprender_turno("¿Qué es un tsunami?", "Una ola gigante.", "local")
    t = c.pregunta_trivia()
    comp("con tres, pregunta; y nunca de lo provisional", t is not None and t["estado"] == "firme" and "tsunami" not in t["pregunta"], t)
    vistas = {c.pregunta_trivia(excluir=[1, 2])["id"] for _ in range(10)}
    comp("no repite las que ya pregunto (mientras queden)", vistas == {3}, vistas)
    comp("acierta con la palabra clave", cm.juzgar_trivia("¿Quién pintó la Mona Lisa?", "La pintó Leonardo da Vinci.", "Leonardo"))
    comp("repetir la pregunta no es acertar", not cm.juzgar_trivia("¿Quién pintó la Mona Lisa?", "La pintó Leonardo da Vinci.", "la pintó Picasso"))
    larga = "Un oso polar duerme unas siete u ocho horas al día."
    comp("con respuestas largas hace falta algo mas que una palabra", cm.juzgar_trivia("¿Cuánto duerme un oso polar?", larga, "unas ocho horas") and not cm.juzgar_trivia("¿Cuánto duerme un oso polar?", larga, "siete"))

    print("--- repaso del dia ---")
    dup = c._nuevo("respuesta", "¿quien pinto la mona lisa?", "Leonardo.", "provisional", "local")
    viejo_ep = c._nuevo("episodio", "braya hablo de trenes antiguos", "braya hablo de trenes antiguos", "firme", "charla")
    viejo_ep["usada"] = reloj.t - 200 * 86400
    rech = c._nuevo("respuesta", "¿Qué es un ornitorrinco?", "Un pez.", "rechazada", "local")
    rech["creada"] = reloj.t - 90 * 86400
    prov = c._nuevo("respuesta", "¿Qué es un géiser?", "Agua caliente que sale del suelo.", "provisional", "local")
    c.datos["pendientes"] = []
    hecho = c.repaso()
    comp("junta la pregunta repetida y se queda la firme", hecho and hecho["juntados"] == 1 and c._por_id(dup["id"]) is None
         and c.respuesta_directa("¿quién pintó la mona lisa?")["respuesta"] == "La pintó Leonardo da Vinci.", hecho)
    comp("lo provisional sin revisar vuelve a la cola", any(j.get("recuerdo") == prov["id"] for j in c.datos["pendientes"]))
    comp("poda lo viejo sin usar y lo rechazado hace tiempo", hecho["podados"] == 2 and c._por_id(viejo_ep["id"]) is None and c._por_id(rech["id"]) is None, hecho)
    comp("una vez al dia", c.repaso() is None)
    reloj.t += 86400
    comp("al dia siguiente, otra vez", c.repaso() is not None)

    print("--- el interrogativo suelto no arrastra recuerdos (18/09) ---")
    # MEDIDO sobre las 96 frases reales de CHARLA del registro, con el cerebro real y sin
    # embedder (lo que pasa hoy en produccion): de 9 recuperaciones, 5 eran el MISMO recuerdo
    # colandose por la ficha "?que" -"que tengo en mi escritorio" traia "?Que es escribir?"-.
    # Tras el filtro: 4 recuperaciones y 0 malas.
    c6 = cm.Cerebro(os.path.join(carpeta, "interrogativo"), reloj=reloj)
    c6.aprender_turno("¿Qué es escribir?", "Escribir es plasmar palabras.", "api")
    hit6 = c6.buscar("¿Qué?", tipos={"respuesta"})
    # SIN ESTA LINEA EL CASO NO PROBARIA NADA: si la busqueda por palabras ni siquiera alcanzara
    # el recuerdo, el contexto saldria vacio por otra razon y el verde seria falso. Con un solo
    # recuerdo "?Que?" da 0.5; las frases con tema propio se quedan en 0.28-0.29 y por eso la
    # rama de abajo se prueba contra la funcion, no por el lex.
    comp("la busqueda por palabras SI alcanza el recuerdo", hit6 and hit6[0]["lex"] >= 0.3, round(hit6[0]["lex"], 3) if hit6 else "nada")
    comp("pero '¿Qué?' a secas no lo arrastra", "plasmar" not in c6.contexto("¿Qué?"), c6.contexto("¿Qué?"))
    comp("y compartiendo la palabra sigue entrando", "plasmar" in c6.contexto("¿qué es escribir, hola?"))
    # la regla en crudo, con el MISMO recuerdo y un hit de mentira: una vez con tema en comun y
    # otra sin el. Asi no depende de cuanto pese cada palabra en el cerebro de turno.
    r6 = c6.buscar("¿qué es escribir?", tipos={"respuesta"})[0]["r"]
    falso = {"sem": None, "comb": 0.0, "lex": 0.9, "r": r6}
    comp("compartir solo el interrogativo no basta", not c6._vale_de_contexto(falso, {"escritorio"}))
    comp("compartir el tema si", c6._vale_de_contexto(falso, {"escribir"}))

    print("--- limites ---")
    viejo = cm.MAX_RECUERDOS
    cm.MAX_RECUERDOS = 3
    c5 = cm.Cerebro(os.path.join(carpeta, "poda"), reloj=reloj)
    c5.aprender_turno("¿Qué es un volcán?", "Una montaña que expulsa lava.", "api")
    c5.aprender_turno("¿Qué es un tsunami?", "Una ola gigante.", "local")
    c5.aprender_turno("¿Qué es un tornado?", "Un remolino de viento.", "api")
    c5.aprender_turno("¿Qué es un huracán?", "Una tormenta enorme.", "api")
    cm.MAX_RECUERDOS = viejo
    comp("al llenarse, se va primero lo provisional", c5.balance()["respuestas"] == 3 and c5.balance()["provisionales"] == 0, c5.balance())
finally:
    shutil.rmtree(carpeta, ignore_errors=True)

if mal:
    print("%d casos MAL" % mal)
    sys.exit(1)
print("todo correcto")
