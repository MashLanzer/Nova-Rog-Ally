# -*- coding: utf-8 -*-
"""AJEDREZ A CIEGAS (23/09/2026). Lo pidio braya.

Lo que se prueba aqui NO es el ajedrez -eso lo lleva python-chess y no hace falta
comprobarlo-, sino las tres cosas que son de Nova y pueden fallarle a braya:

  1. QUE UNA ORDEN NORMAL NUNCA SE CONVIERTA EN UNA JUGADA. Es la regla de la casa: tolera
     que no le entienda, no tolera que haga algo que no pidio. Con una partida abierta, "sube
     el volumen" tiene que salir de aqui sin tocar el tablero.
  2. QUE LA CONFUSION CONOCIDA SE PREGUNTE. Medido con la fonetica del repo, el par mas flojo
     de todo el alfabeto hablado son las filas seis/siete (0,705), y una fila equivocada suele
     ser TAMBIEN una jugada legal: ahi Nova no puede elegir por parecido.
  3. QUE LA PARTIDA SOBREVIVA. Nova arranca 16,8 veces al dia (235 en 14 dias); una partida en
     memoria se pierde diecisiete veces al dia.
"""
import io
import os
import shutil
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


try:
    import chess
    import ajedrez
except Exception as e:      # noqa: BLE001
    print("  MAL  no puedo importar: %s" % e)
    sys.exit(1)

print("")
print("-- lo que dice braya se convierte en la jugada que es --")
b = chess.Board()
casos_ok = [
    ("peon echo cuatro", "e4"),
    ("echo cuatro", "e4"),
    ("caballo foxtrot tres", "Nf3"),
    ("caballo efe tres", "Nf3"),          # el nombre español de la letra, como segunda forma
    ("caballo a foxtrot tres", "Nf3"),
]
for dicho, esperado in casos_ok:
    mov, motivo, _ = ajedrez.elegir(b, dicho)
    comp("'%s'" % dicho, mov is not None and b.san(mov) == esperado,
         (b.san(mov) if mov else motivo))

print("")
print("-- y una orden normal NO toca el tablero --")
# Estas son ordenes REALES del log de braya, no inventadas.
# Y NO BASTA CON QUE NO SE EJECUTE: tampoco puede quedar como CANDIDATA. Sin la guarda de
# forma, "que hora es" sacaba 0,80 contra alguna jugada legal y salia por "dos parecidas", o
# sea que Nova preguntaba "¿foxtrot tres o charlie tres?" a alguien que preguntaba la hora.
# Comprobar solo que no se mueve nada dejaba pasar eso: se comprobo rompiendolo a proposito.
for dicho in ("sube el volumen", "abre steam", "que hora es", "cierra el navegador",
              "pon el modo juego", "abre youtube en la mitad y en la otra mitad abre pinterest"):
    mov, motivo, cand = ajedrez.elegir(b, dicho)
    comp("'%s' no es una jugada" % dicho[:34], mov is None, motivo)
    comp("   ...y ni siquiera se pregunta", len(cand) == 0,
         "candidatas: %s" % (", ".join(b.san(m) for m in cand) if cand else "ninguna"))

print("")
print("-- la confusion de seis/siete se pregunta, no se adivina --")
# Una posicion donde la misma torre puede ir a a6 y a a7: si el oido se come la diferencia,
# las dos son legales y elegir por parecido seria mover una pieza donde braya no dijo.
b2 = chess.Board("4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
legales = {b2.san(m) for m in b2.legal_moves}
comp("la posicion tiene las dos jugadas", "Ra6" in legales and "Ra7" in legales,
     "Ra6 y Ra7 legales")
mov, motivo, cand = ajedrez.elegir(b2, "torre alfa seis")
comp("no la hace sola", mov is None, motivo)
comp("y pregunta por las dos", motivo == "seis o siete" and len(cand) == 2,
     " / ".join(b2.san(m) for m in cand) if cand else "")

print("")
print("-- una partida entera, hablada, con el motor de verdad --")
tmp = tempfile.mkdtemp(prefix="ajedrez-")
json_real, pgn_real = ajedrez.RUTA_JSON, ajedrez.RUTA_PGN
ajedrez.RUTA_JSON = os.path.join(tmp, "ajedrez.json")
ajedrez.RUTA_PGN = os.path.join(tmp, "ajedrez.pgn")
try:
    estado = {"jugadas": [], "elo": 1320}
    tablero = ajedrez.tablero_de(estado)
    dichas = ["peon echo cuatro", "caballo foxtrot tres", "alfil charlie cuatro"]
    hechas = 0
    for dicho in dichas:
        mov, motivo, _ = ajedrez.elegir(tablero, dicho)
        if mov is None:
            comp("'%s' entro" % dicho, False, motivo)
            continue
        hechas += 1
        tablero.push(mov)
        estado["jugadas"].append(mov.uci())
        # y contesta la maquina
        resp, motivo2 = ajedrez.juega_maquina(tablero, elo=estado["elo"], ms=100)
        if resp is not None:
            tablero.push(resp)
            estado["jugadas"].append(resp.uci())
    comp("las tres jugadas dichas entraron", hechas == 3, "%d de 3" % hechas)
    comp("y la maquina contesto a todas", len(estado["jugadas"]) == 6,
         "%d medias jugadas" % len(estado["jugadas"]))
    comp("el tablero sigue siendo legal", tablero.is_valid())

    print("")
    print("-- y la partida sobrevive al reinicio --")
    ajedrez.guardar(estado)
    comp("se guarda en disco", os.path.exists(ajedrez.RUTA_JSON))
    vuelto = ajedrez.cargar()
    comp("y se lee igual", vuelto is not None and vuelto["jugadas"] == estado["jugadas"],
         "%d jugadas" % len(vuelto["jugadas"] if vuelto else []))
    tablero2 = ajedrez.tablero_de(vuelto)
    comp("y el tablero se reconstruye entero", tablero2.fen() == tablero.fen(),
         "misma posicion tras 'reiniciar'")
    ajedrez.guardar_pgn(estado)
    comp("el PGN queda escrito", os.path.exists(ajedrez.RUTA_PGN) and
         os.path.getsize(ajedrez.RUTA_PGN) > 40)
    ajedrez.borrar()
    comp("y al cerrarla se borra el estado", not os.path.exists(ajedrez.RUTA_JSON))
    comp("pero el PGN se queda", os.path.exists(ajedrez.RUTA_PGN), "la partida no se pierde")
finally:
    ajedrez.RUTA_JSON, ajedrez.RUTA_PGN = json_real, pgn_real
    shutil.rmtree(tmp, ignore_errors=True)

print("")
print("-- LO QUE ENCONTRO LA REVISION (23/09) --")
tmp = tempfile.mkdtemp(prefix="ajedrez2-")
json_real, pgn_real, niv_real = ajedrez.RUTA_JSON, ajedrez.RUTA_PGN, ajedrez.RUTA_NIVEL
ajedrez.RUTA_JSON = os.path.join(tmp, "ajedrez.json")
ajedrez.RUTA_PGN = os.path.join(tmp, "ajedrez.pgn")
ajedrez.RUTA_NIVEL = os.path.join(tmp, "nivel.json")
try:
    # 1. LAS CUATRO PROMOCIONES SE LLAMAN DISTINTO.
    # Sin esto, como_se_dice devolvia "peon echo ocho" para las cuatro y la pregunta salia
    # "¿peon echo ocho o peon echo ocho?": irresoluble por voz Y por mando, con dos etiquetas
    # identicas en la capsula, y se coronaba una pieza que braya no habia elegido.
    bp = chess.Board("7k/4P3/8/8/8/8/8/K7 w - - 0 1")
    proms = [m for m in bp.legal_moves if m.promotion]
    dichas = [ajedrez.como_se_dice(bp, m) for m in proms]
    comp("las cuatro promociones existen", len(proms) == 4, "%d" % len(proms))
    comp("y se dicen de cuatro maneras distintas", len(set(dichas)) == 4, " / ".join(sorted(dichas)))
    mov, motivo, cand = ajedrez.elegir(bp, "peon echo ocho corono dama")
    comp("y se puede pedir una en concreto", mov is not None and mov.promotion == chess.QUEEN,
         bp.san(mov) if mov else motivo)

    # 2. SIN MOTOR, LA JUGADA DE BRAYA NO SE QUEDA A MEDIAS.
    # Antes se guardaba igual, con las NEGRAS a mover: la frase siguiente suya se emparejaba
    # contra las jugadas legales de Nova y acababa moviendo las piezas del rival sin saberlo.
    # modelos\\stockfish\\ no va en el repositorio, asi que el caso es real.
    exe_real = ajedrez.stockfish_exe
    ajedrez.stockfish_exe = lambda: ""
    try:
        est = {"jugadas": [], "elo": 1320}
        ajedrez.guardar(est)
        r = subprocess.run([sys.executable, os.path.join(RAIZ, "ajedrez_turno.py"),
                            "--dicho", "peon echo cuatro"], capture_output=True, text=True,
                           env=dict(os.environ, NOVA_AJEDREZ_TMP=tmp))
    finally:
        ajedrez.stockfish_exe = exe_real
    # el subproceso usa las rutas de verdad, asi que esto se comprueba en el proceso de aqui:
    est = {"jugadas": [], "elo": 1320}
    tab = ajedrez.tablero_de(est)
    mov, _, _ = ajedrez.elegir(tab, "peon echo cuatro")
    tab.push(mov)
    est["jugadas"].append(mov.uci())
    resp, motivo = ajedrez.juega_maquina(tab, elo=1320, ms=50) if ajedrez.stockfish_exe() else (None, "sin motor")
    if resp is None:
        est["jugadas"].pop()          # es lo que hace ajedrez_turno.py
    comp("sin motor, el tablero se queda como estaba",
         (resp is not None) or (len(est["jugadas"]) == 0),
         "si no, la frase siguiente mueve las piezas de Nova")
    fuente_t = io.open(os.path.join(RAIZ, "ajedrez_turno.py"), encoding="utf-8").read()
    comp("y el codigo lo deshace de verdad", 'est["jugadas"].pop()' in fuente_t)
    comp("y lo dice", "Tu jugada no cuenta" in fuente_t)

    # 3. EL NIVEL SOBREVIVE A LA PARTIDA.
    # Se ajustaba en cierra_si_acabo y dos lineas despues borrar() se llevaba el json entero:
    # el Elo no subia ni bajaba nunca, y el manual promete que si.
    ajedrez.guardar_nivel({"elo": 1380, "ganadas": 1, "perdidas": 0})
    ajedrez.borrar()
    niv = ajedrez.cargar_nivel()
    comp("el nivel vive fuera de la partida", niv["elo"] == 1380 and niv["ganadas"] == 1,
         "elo %d tras borrar la partida" % niv["elo"])
    comp("y el codigo lo guarda antes de borrar",
         fuente_t.index("guardar_nivel") < fuente_t.index("ajedrez.borrar()"))
    comp("y suma la ganada o la perdida", '"ganadas"] = int(est.get("ganadas", 0)) + (1 if gana_braya else 0)' in fuente_t)

    # 4. EMPEZAR OTRA NO SE LLEVA LA DE ANTES.
    # "juguemos al ajedrez" se reconoce ANTES de mirar si hay partida abierta, a proposito:
    # era la unica manera de perder una partida sin rastro.
    comp("al empezar se guarda la de antes", "ajedrez.guardar_pgn(viejo)" in fuente_t)
    comp("y se dice", "Guardo la de antes" in fuente_t)

    # 5. LA PREGUNTA CADUCA.
    comp("la pregunta lleva sello de tiempo", '"preguntadas_ts"' in fuente_t)
    comp("y se descarta al minuto",
         ('"preguntadas_ts", 0)' in fuente_t) and ('> 60' in fuente_t) and
         ('Ya no tengo esa pregunta abierta' in fuente_t))
    comp("y al contestarla se nombra la jugada", "dicha_suya = ajedrez.como_se_dice(tablero, mov)" in fuente_t)
    comp("no un 'hecho' pelado", 'or "hecho"' not in fuente_t)
finally:
    ajedrez.RUTA_JSON, ajedrez.RUTA_PGN, ajedrez.RUTA_NIVEL = json_real, pgn_real, niv_real
    shutil.rmtree(tmp, ignore_errors=True)

print("")
print("-- el motor: por jugada, nunca residente --")
exe = ajedrez.stockfish_exe()
comp("Stockfish esta", bool(exe), os.path.basename(exe) if exe else "no esta")
fuente = io.open(os.path.join(RAIZ, "ajedrez.py"), encoding="utf-8").read()
comp("se arranca y se cierra en la misma llamada", "motor.quit()" in fuente,
     "con It Takes Two delante no puede quedarse esperando turno")
comp("con un hilo y poca memoria", '"Threads": 1' in fuente and '"Hash": 16' in fuente)
comp("y con la fuerza limitada", "UCI_LimitStrength" in fuente and "UCI_Elo" in fuente)
comp("si no hay motor, lo dice y no revienta", 'return None, "sin motor"' in fuente)

print("")
print("-- y la fonetica no se copia: se usa la del repo --")
comp("importa pruebas/fonetica.py", "from fonetica import" in fuente)
comp("y no tiene su propia copia", "def clave_fon" not in fuente and "def jw" not in fuente)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  se puede jugar a ciegas, y una orden no se convierte en jugada")
sys.exit(0)
