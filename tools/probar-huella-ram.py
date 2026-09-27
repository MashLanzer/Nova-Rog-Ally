# -*- coding: utf-8 -*-
# LOS 1200 MB QUE PARAKEET DICE NECESITAR NO LOS MIDIO NADIE (26/09, idea 44 de las 121).
#
# El liston de RAM (1200) se escribio con 7,7 GB libres y lo COMPARTEN tres modelos: canary (198
# MB en disco) y omni (350) piden el liston del grande. Ahora cada modelo mide en vivo lo que
# ocupa al cargar (huellas-ram.txt) y su liston sale de max(huella)+reserva; mientras no haya
# huella, el respaldo es el 1200/900 de siempre. Este banco EJECUTA ram_que_pide y apuntar_huella
# de verdad (sacadas del archivo con regex, sin importar wake_vosk, que abriria el microfono).
import ast
import os
import re
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
ARBOL = ast.parse(SRC)

fallos = 0


def comp(etq, ok, det=""):
    global fallos
    print("  %s  %s%s" % ("OK " if ok else "MAL", etq, ("  -> %s" % det) if det else ""))
    if not ok:
        fallos += 1


# --- las funciones de verdad, en un ns con un fichero de huellas en un temporal ---
_tmp = tempfile.mkdtemp()
RUTA = os.path.join(_tmp, "huellas-ram.txt")


def _escribir(ruta, contenido):
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(contenido)


def _cte(nombre):
    m = re.search(r"^%s = ([0-9.]+)" % nombre, SRC, re.M)
    return float(m.group(1)) if m else None


ns = {"os": os, "open": open, "escribir": _escribir, "RUTA_HUELLAS": RUTA,
      "RAM_RESERVA_TRAS_CARGAR": _cte("RAM_RESERVA_TRAS_CARGAR"),
      "HUELLA_MEMORIA": int(_cte("HUELLA_MEMORIA"))}
for node in ARBOL.body:
    if isinstance(node, ast.FunctionDef) and node.name in ("apuntar_huella", "ram_que_pide"):
        exec(ast.get_source_segment(SRC, node), ns)
aq = ns["ram_que_pide"]
ap = ns["apuntar_huella"]


def reset():
    if os.path.exists(RUTA):
        os.remove(RUTA)


comp("RAM_RESERVA_TRAS_CARGAR sale de 1200-746", ns["RAM_RESERVA_TRAS_CARGAR"] == 454.0, "%.0f" % ns["RAM_RESERVA_TRAS_CARGAR"])

print("")
print("-- 1..5: el liston sale de lo medido, no de la constante --")
reset()
comp("1. sin ninguna medida, el liston es el respaldo exacto", aq("parakeet", "carp", 1200.0) == 1200.0, "%.1f" % aq("parakeet", "carp", 1200.0))
# canary tres cargas: 210, 228, 219 (antes=3000, despues=3000-h)
reset()
for h in (210, 228, 219):
    ap("canary", "sherpa-canary", 3000, 3000 - h)
comp("2. con medidas, el liston SE MUEVE de verdad", aq("canary", "sherpa-canary", 1200.0) == 682.0 and aq("canary", "sherpa-canary", 1200.0) < 1200, "%.1f (682 = 228+454, < 1200)" % aq("canary", "sherpa-canary", 1200.0))
comp("3. es el MAXIMO, no la media (228, no 219)", aq("canary", "sherpa-canary", 1200.0) == 682.0, "media daria 673")
reset()
ap("fino", "small", 3000, 3000 - 50)
comp("4. la reserva sigue puesta (nunca por debajo de 454)", aq("fino", "small", 900.0) == 504.0, "huella 50 -> 504")
reset()
ap("parakeet", "sherpa-parakeet", 3000, 3000 - 746)
comp("5. con la huella del 19/09 (746) el liston de parakeet NO se mueve", aq("parakeet", "sherpa-parakeet", 1200.0) == 1200.0, "746+454=1200")

print("")
print("-- 6, 7: no se apunta basura, y la carpeta invalida --")
reset()
ap("parakeet", "p", -1, 500)      # no se pudo medir el antes
ap("parakeet", "p", 900, -1)      # ni el despues
ap("parakeet", "p", 900, 950)     # delta negativo (el juego solto memoria)
ap("parakeet", "p", 4000, 500)    # delta 3500, absurdo
comp("6. no se apunta lo que no se puede medir ni lo absurdo", aq("parakeet", "p", 1200.0) == 1200.0, "el fichero sigue sin huella util")
reset()
ap("parakeet", "sherpa-viejo", 3000, 3000 - 700)
comp("7. si cambia la carpeta del modelo, la huella NO se hereda", aq("parakeet", "sherpa-nuevo", 1200.0) == 1200.0, "otra carpeta -> respaldo")
comp("   pero con la misma carpeta si vale", aq("parakeet", "sherpa-viejo", 1200.0) == 1154.0, "700+454")

print("")
print("-- 8: la medida esta EN el codigo y DESPUES de la carga --")
_fuentes = {"modelo_parakeet": "from_transducer(", "modelo_canary": "from_nemo_canary(",
            "modelo_omni": "from_omnilingual_asr_ctc(", "modelo_preciso": "WhisperModel("}
for fn, carga in _fuentes.items():
    m = re.search(r"(?ms)^def %s\(\):.*?\n(?=\n*\S|\Z)" % fn, SRC)
    cuerpo = m.group(0) if m else ""
    iCarga = cuerpo.find(carga)
    iAp = cuerpo.find("apuntar_huella(")
    iFin = cuerpo.find(" cargado en")
    comp("8. %s mide la huella tras cargar" % fn, iCarga >= 0 and iAp > iCarga and iFin > iAp, "carga=%d apunta=%d fin=%d" % (iCarga, iAp, iFin))

print("")
print("-- 9: las cuatro guardas usan el liston calculado, no la constante --")
sin_com = "\n".join(ln for ln in SRC.split("\n") if not ln.strip().startswith("#"))
comp("9. 'no lo cargo, solo quedan' sigue apareciendo 4 veces", sin_com.count("no lo cargo, solo quedan") == 4, "%d" % sin_com.count("no lo cargo, solo quedan"))
comp("   las cuatro guardas llaman a ram_que_pide", sin_com.count("ram_que_pide(") >= 4, "%d" % sin_com.count("ram_que_pide("))
comp("   y ninguna marca resta la constante a pelo (usan _pide)", "RAM_MIN_PARAKEET - _libre" not in sin_com and "RAM_MIN_PRECISO - _libre" not in sin_com, "las marcas restan _pide")
# y sobre todo: NINGUNA guarda compara _libre contra la constante a pelo (llamar a ram_que_pide y
# luego no usar _pide es la forma facil de que esto quede en verde sin cambiar nada)
comp("   y ninguna guarda compara _libre contra la constante (usan _pide)", "_libre < RAM_MIN_PARAKEET" not in sin_com and "_libre < RAM_MIN_PRECISO" not in sin_com, "el liston efectivo, no el respaldo")

print("")
print("-- 10: contra el registro de verdad --")
neg = 0
for lf in ("assistant.log", "assistant.log.1"):
    p = os.path.join(RAIZ, lf)
    if os.path.exists(p):
        try:
            neg += sum(1 for ln in open(p, encoding="utf-8", errors="replace") if "no lo cargo, solo quedan" in ln)
        except Exception:
            pass
print("       negativas de RAM en el registro: %d" % neg)
comp("10. hay historial de negativas que esto viene a reducir", neg >= 10, "%d (canary y omni dejan de pedir el liston del grande)" % neg)

print("")
if fallos:
    print("%d casos MAL" % fallos)
    sys.exit(1)
print("el liston sale de lo medido")
sys.exit(0)
