# -*- coding: utf-8 -*-
"""AJEDREZ A CIEGAS (23/09/2026). Lo pidio braya: que Nova pueda jugar ajedrez mental con el
y llevar la partida entera, pero sin que nadie diseñe el juego: "debe de haber api o cosas
para eso, investigalo".

Y no se diseña: las reglas las lleva python-chess (1.11.2, Python puro, sin dependencias) y
juega Stockfish por UCI. Aqui solo esta lo que ninguna libreria puede saber: como suena una
jugada dicha en voz alta en español por el oido de Nova.

LA DECISION DE DISEÑO, Y SALE DE UN NUMERO: en las 1.127 transcripciones no vacias del log no
hay NI UN par letra+cifra tipo "e4"; los unicos tokens de una letra que aparecen son palabras
del español ("a" 174, "o" 23, "y" 224). O sea que dictar notacion no funciona y no va a
funcionar. Asi que AL OIDO NO SE LE ENSEÑA AJEDREZ: en cada turno python-chess da las ~30
jugadas legales, se generan sus formas habladas, y lo que llego del microfono se EMPAREJA
contra esa lista cerrada. Nunca se transcribe una jugada: se elige entre las que caben.

Las columnas se dicen en ICAO (alfa, bravo, charlie...) porque separan mejor: medido con la
fonetica de pruebas/fonetica.py, el peor par de letras españolas es 0,800 (e/efe, a/hache) y
con ICAO baja a 0,667 (golf/hotel). Pero el par mas flojo de todos NO son las columnas: son
las filas, seis/siete = 0,705. Por eso hay una regla fija: si las dos mejores candidatas solo
se diferencian en la fila 6 o 7, se pregunta SIEMPRE.
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "pruebas"))
from fonetica import clave_fon, jw, plano   # noqa: E402  (la fonetica ya existe, no se copia)

import chess          # noqa: E402
import chess.pgn      # noqa: E402

REPO = os.path.dirname(os.path.abspath(__file__))
RUTA_JSON = os.path.join(REPO, "memoria", "ajedrez.json")
RUTA_PGN = os.path.join(REPO, "memoria", "ajedrez.pgn")
# EL NIVEL VIVE APARTE DE LA PARTIDA (revision del 23/09). Estaba dentro de ajedrez.json, que
# se BORRA al acabar: el Elo se calculaba y se tiraba a la basura en la misma funcion, asi que
# no subia ni bajaba nunca y el manual prometia que si. Y no vale con dejar ajedrez.json vivo:
# Test-AjedrezAbierta lo lee como "hay partida" y el puente se quedaria armado para siempre.
RUTA_NIVEL = os.path.join(REPO, "memoria", "ajedrez-nivel.json")

# --- como se dice cada cosa -------------------------------------------------
PIEZAS = {"K": ["rey"], "Q": ["dama", "reina"], "R": ["torre"], "B": ["alfil"], "N": ["caballo"]}
ICAO = {"a": "alfa", "b": "bravo", "c": "charlie", "d": "delta",
        "e": "echo", "f": "foxtrot", "g": "golf", "h": "hotel"}
LETRA_ES = {"a": "a", "b": "be", "c": "ce", "d": "de",
            "e": "e", "f": "efe", "g": "ge", "h": "hache"}
NUM = {"1": "uno", "2": "dos", "3": "tres", "4": "cuatro",
       "5": "cinco", "6": "seis", "7": "siete", "8": "ocho"}
# margen minimo entre la mejor candidata y la segunda para no preguntar
MARGEN = 0.06
# y el par que SIEMPRE se pregunta (ver la cabecera): seis/siete
FILAS_DUDOSAS = {"6", "7"}
# por debajo de esto, no se parece a ninguna jugada y se deja pasar al router normal
MINIMO = 0.80


def formas_de(board, mov):
    """Todas las maneras razonables de decir esta jugada en voz alta."""
    san = board.san(mov)
    if san.startswith("O-O-O"):
        return ["enroque largo", "enroco largo"]
    if san.startswith("O-O"):
        return ["enroque corto", "enroque"]
    fuera = []
    destino = chess.square_name(mov.to_square)
    col, fila = destino[0], destino[1]
    pieza = board.piece_at(mov.from_square)
    letra = pieza.symbol().upper() if pieza else "P"
    nombres = PIEZAS.get(letra, ["peon"])
    comes = board.is_capture(mov)
    corona = ""
    if mov.promotion:
        corona = " corono " + PIEZAS.get(chess.piece_symbol(mov.promotion).upper(), ["dama"])[0]
    for nom in nombres:
        for col_dicha in (ICAO[col], LETRA_ES[col], col):
            for fila_dicha in (NUM[fila], fila):
                fuera.append("%s %s %s%s" % (nom, col_dicha, fila_dicha, corona))
                fuera.append("%s a %s %s%s" % (nom, col_dicha, fila_dicha, corona))
                if comes:
                    fuera.append("%s come en %s %s%s" % (nom, col_dicha, fila_dicha, corona))
                if letra == "P":
                    fuera.append("%s %s%s" % (col_dicha, fila_dicha, corona))
    return fuera


def elegir(board, dicho):
    """Empareja lo oido contra las jugadas LEGALES.

    Devuelve (jugada, motivo, candidatas). motivo 'ok' = se hace; cualquier otro = no se
    hace, y las candidatas son para preguntar.
    """
    d = plano(dicho)
    if not d:
        return None, "nada", []
    # PRIMERO LA FORMA, DESPUES EL PARECIDO (23/09). Sin esta guarda, "que hora es" sacaba
    # 0,80 de parecido contra alguna jugada legal y Nova preguntaba "¿foxtrot tres o charlie
    # tres?" a alguien que estaba preguntando la hora. El parecido fonetico sobre frases
    # cortas dispara solo: hace falta que la frase TENGA forma de jugada. Una jugada dicha
    # siempre trae una pieza (o una columna) y un numero de fila.
    palabras = set(d.split())
    hay_pieza = any(n in palabras for lista in PIEZAS.values() for n in lista) or "peon" in palabras
    hay_col = any(c in palabras for c in list(ICAO.values()) + list(LETRA_ES.values()))
    hay_fila = any(x in palabras for x in list(NUM.values()) + list(NUM.keys()))
    if "enroque" in d or "enroco" in d:
        pass                                  # el enroque no lleva casilla
    elif not ((hay_pieza or hay_col) and hay_fila):
        return None, "no tiene forma de jugada", []
    # SI DICE A QUE CORONA, ESO MANDA (revision del 23/09). Las cuatro promociones van a la
    # misma casilla, asi que sus formas habladas se diferencian en UNA palabra al final y el
    # parecido entre ellas es altisimo: "peon echo ocho corono dama" salia como "dos
    # parecidas" contra la torre. Aqui no hace falta adivinar: la pieza esta dicha.
    corona_pedida = None
    for _letra, _noms in PIEZAS.items():
        for _n in _noms:
            if ("corono " + _n) in d or ("corona " + _n) in d:
                corona_pedida = chess.Piece.from_symbol(_letra).piece_type
                break
        if corona_pedida:
            break
    legales = list(board.legal_moves)
    if corona_pedida:
        filtradas = [m for m in legales if m.promotion == corona_pedida]
        if filtradas:
            legales = filtradas
    clave = clave_fon(d)
    puntuadas = []
    for mov in legales:
        mejor = 0.0
        for f in formas_de(board, mov):
            p = max(jw(clave, clave_fon(f)), jw(d, plano(f)))
            if p > mejor:
                mejor = p
        puntuadas.append((mejor, mov))
    if not puntuadas:
        return None, "sin jugadas", []
    puntuadas.sort(key=lambda x: (-x[0], x[1].uci()))
    mejor_p, mejor_m = puntuadas[0]
    if mejor_p < MINIMO:
        return None, "no se parece a ninguna jugada", []
    if len(puntuadas) > 1:
        seg_p, seg_m = puntuadas[1]
        # LA REGLA DE LA FILA (ver cabecera): seis y siete se confunden mas que nada, y una
        # fila equivocada suele ser TAMBIEN una jugada legal. Ahi se pregunta siempre, aunque
        # el margen sea amplio.
        f1 = chess.square_name(mejor_m.to_square)[1]
        f2 = chess.square_name(seg_m.to_square)[1]
        misma_col = (chess.square_name(mejor_m.to_square)[0] == chess.square_name(seg_m.to_square)[0])
        misma_pieza = (board.piece_at(mejor_m.from_square) == board.piece_at(seg_m.from_square))
        if misma_col and misma_pieza and f1 in FILAS_DUDOSAS and f2 in FILAS_DUDOSAS and f1 != f2:
            return None, "seis o siete", [mejor_m, seg_m]
        if (mejor_p - seg_p) < MARGEN:
            return None, "dos parecidas", [mejor_m, seg_m]
    return mejor_m, "ok", []


def como_se_dice(board, mov):
    """La forma corta y clara, para que Nova la diga."""
    san = board.san(mov)
    if san.startswith("O-O-O"):
        return "enroque largo"
    if san.startswith("O-O"):
        return "enroque corto"
    destino = chess.square_name(mov.to_square)
    pieza = board.piece_at(mov.from_square)
    letra = pieza.symbol().upper() if pieza else "P"
    nom = PIEZAS.get(letra, ["peon"])[0]
    # Y LA CORONACION SE DICE (revision del 23/09). Sin esto, las CUATRO promociones se
    # llamaban igual -"peon echo ocho"- y la pregunta salia "¿peon echo ocho o peon echo
    # ocho?": irresoluble por voz y por mando, con dos etiquetas identicas en la capsula, y
    # contestara lo que contestara se coronaba una pieza que no habia elegido.
    corona = ""
    if mov.promotion:
        corona = " corono " + PIEZAS.get(chess.piece_symbol(mov.promotion).upper(), ["dama"])[0]
    return "%s %s %s%s" % (nom, ICAO[destino[0]], NUM[destino[1]], corona)


# --- la partida, en disco ---------------------------------------------------
# Nova arranca 16,8 veces al dia (235 en 14 dias): una partida que viva en memoria se pierde
# diecisiete veces al dia. Mismo patron que los recordatorios: json atomico, y el PGN al lado
# por si algun dia se quiere mirar la partida con un tablero de verdad.
def cargar():
    if not os.path.exists(RUTA_JSON):
        return None
    try:
        with io.open(RUTA_JSON, encoding="utf-8") as f:
            return json.load(f)
    except Exception:       # noqa: BLE001
        return None


def guardar(estado):
    os.makedirs(os.path.dirname(RUTA_JSON), exist_ok=True)
    tmp = RUTA_JSON + ".tmp"
    with io.open(tmp, "w", encoding="utf-8") as f:
        json.dump(estado, f, ensure_ascii=False)
    os.replace(tmp, RUTA_JSON)


def borrar():
    for r in (RUTA_JSON,):
        try:
            if os.path.exists(r):
                os.remove(r)
        except Exception:   # noqa: BLE001
            pass


def guardar_pgn(estado):
    try:
        b = chess.Board()
        juego = chess.pgn.Game()
        juego.headers["Event"] = "Nova a ciegas"
        juego.headers["White"] = "braya"
        juego.headers["Black"] = "Nova"
        nodo = juego
        for uci in estado.get("jugadas", []):
            mov = chess.Move.from_uci(uci)
            nodo = nodo.add_variation(mov)
            b.push(mov)
        juego.headers["Result"] = b.result()
        with io.open(RUTA_PGN, "a", encoding="utf-8") as f:
            print(juego, file=f, end="\n\n")
    except Exception:       # noqa: BLE001
        pass


def cargar_nivel():
    try:
        with io.open(RUTA_NIVEL, encoding="utf-8") as f:
            return json.load(f)
    except Exception:       # noqa: BLE001
        return {"elo": 1320, "ganadas": 0, "perdidas": 0}


def guardar_nivel(nivel):
    try:
        os.makedirs(os.path.dirname(RUTA_NIVEL), exist_ok=True)
        tmp = RUTA_NIVEL + ".tmp"
        with io.open(tmp, "w", encoding="utf-8") as f:
            json.dump(nivel, f, ensure_ascii=False)
        os.replace(tmp, RUTA_NIVEL)
    except Exception:       # noqa: BLE001
        pass


def tablero_de(estado):
    b = chess.Board()
    for uci in (estado or {}).get("jugadas", []):
        try:
            b.push(chess.Move.from_uci(uci))
        except Exception:   # noqa: BLE001
            break
    return b


# --- el rival ---------------------------------------------------------------
def stockfish_exe():
    base = os.path.join(REPO, "modelos", "stockfish")
    if not os.path.isdir(base):
        return ""
    for raiz, _, ficheros in os.walk(base):
        for f in ficheros:
            if f.lower().endswith(".exe") and "stockfish" in f.lower():
                return os.path.join(raiz, f)
    return ""


def juega_maquina(board, elo=1320, ms=150):
    """Stockfish, lanzado POR JUGADA y soltado al contestar.

    Nunca residente: braya juega con It Takes Two delante, y un proceso esperando turno le
    quita memoria y un nucleo al Z2 A durante horas para nada.
    """
    exe = stockfish_exe()
    if not exe:
        return None, "sin motor"
    try:
        import chess.engine
        motor = chess.engine.SimpleEngine.popen_uci(exe)
        try:
            try:
                motor.configure({"Threads": 1, "Hash": 16,
                                 "UCI_LimitStrength": True, "UCI_Elo": int(elo)})
            except Exception:   # noqa: BLE001
                pass            # un motor sin esas opciones juega igual, solo que fuerte
            res = motor.play(board, chess.engine.Limit(time=ms / 1000.0))
            return res.move, "ok"
        finally:
            motor.quit()
    except Exception as e:  # noqa: BLE001
        return None, "el motor fallo: %s" % e
