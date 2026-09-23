# -*- coding: utf-8 -*-
"""Un turno de la partida a ciegas, para que lo llame assistant.ps1.

Se lanza por turno y se muere: no hay proceso esperando. Cuesta el arranque de Python mas el
de Stockfish, medido en esta consola: ~1,2 s en total, de los cuales 0,15 son pensar. Un
worker vivo ahorraria medio segundo y le quitaria memoria al juego durante horas, que es
exactamente lo que no se quiere aqui (braya juega mientras habla con Nova).

Entra por argumentos y sale por JSON en la salida estandar. Todo lo que diga Nova sale en
'decir'; si hay que preguntar, viene 'opciones' con las dos jugadas y su numero.
"""
import argparse
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ajedrez              # noqa: E402
import chess                # noqa: E402


def salida(**kw):
    kw.setdefault("hay_partida", False)
    kw.setdefault("decir", "")
    kw.setdefault("opciones", [])
    kw.setdefault("fin", False)
    sys.stdout.write(json.dumps(kw, ensure_ascii=False))
    sys.stdout.flush()


def estado_o_nuevo():
    est = ajedrez.cargar()
    if not est:
        # EL NIVEL SOBREVIVE A LA PARTIDA (revision del 23/09): vive en su propio fichero,
        # porque ajedrez.json se borra al acabar y con el se iba el Elo recien ajustado.
        niv = ajedrez.cargar_nivel()
        est = {"jugadas": [], "elo": int(niv.get("elo", 1320)),
               "ganadas": int(niv.get("ganadas", 0)), "perdidas": int(niv.get("perdidas", 0))}
    est.setdefault("jugadas", [])
    est.setdefault("elo", 1320)
    return est


def cierra_si_acabo(tablero, est):
    """Devuelve el texto del final, o '' si la partida sigue."""
    if not tablero.is_game_over():
        return ""
    res = tablero.result()
    if tablero.is_checkmate():
        gana_braya = (res == "1-0")
        # EL ELO SE AJUSTA SOLO (lo pide la casa: que Nova mueva sus numeros con sus datos).
        # +60 si braya gana, -60 si pierde, entre 1320 y 2400.
        est["elo"] = max(1320, min(2400, int(est.get("elo", 1320)) + (60 if gana_braya else -60)))
        est["ganadas"] = int(est.get("ganadas", 0)) + (1 if gana_braya else 0)
        est["perdidas"] = int(est.get("perdidas", 0)) + (0 if gana_braya else 1)
        texto = "Jaque mate, ganas tu." if gana_braya else "Jaque mate. Gano yo."
    elif tablero.is_stalemate():
        texto = "Tablas por ahogado."
    else:
        texto = "Tablas."
    # EL NIVEL, A SU FICHERO, ANTES DE BORRAR LA PARTIDA. Antes se ajustaba aqui mismo y dos
    # lineas despues borrar() se llevaba el json entero: el Elo no subia ni bajaba nunca, y
    # el manual promete "si ganas, sube 60; si pierdes, baja 60".
    ajedrez.guardar_nivel({"elo": int(est.get("elo", 1320)),
                           "ganadas": int(est.get("ganadas", 0)),
                           "perdidas": int(est.get("perdidas", 0))})
    ajedrez.guardar_pgn(est)
    ajedrez.borrar()
    return texto


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--empezar", action="store_true")
    ap.add_argument("--dicho", default="")
    ap.add_argument("--elegir", type=int, default=0)   # 1 o 2, contestando a una pregunta
    ap.add_argument("--deshacer", action="store_true")
    ap.add_argument("--cerrar", action="store_true")
    ap.add_argument("--estado", action="store_true")
    a = ap.parse_args()

    if a.empezar:
        # LA DE ANTES SE GUARDA (revision del 23/09). Esta frase se reconoce ANTES de mirar
        # si hay partida abierta, a proposito, asi que era la unica manera de perder una
        # partida sin rastro: se escribia {"jugadas": []} encima y el PGN no llegaba a
        # existir. Con el oido al 70,4 % y una partida que vive dias entre los diecisiete
        # arranques diarios, la frase se puede colar sobre otra parecida.
        viejo = ajedrez.cargar()
        habia = bool(viejo and viejo.get("jugadas"))
        if habia:
            ajedrez.guardar_pgn(viejo)
        niv = ajedrez.cargar_nivel()
        est = {"jugadas": [], "elo": int(niv.get("elo", 1320)),
               "ganadas": int(niv.get("ganadas", 0)), "perdidas": int(niv.get("perdidas", 0))}
        ajedrez.guardar(est)
        salida(hay_partida=True,
               decir=("Guardo la de antes y empezamos otra. Llevas blancas: empiezas tu."
                      if habia else "Vale, partida a ciegas. Llevas blancas: empiezas tu."))
        return

    est = ajedrez.cargar()
    if not est:
        if a.estado or a.cerrar or a.deshacer:
            salida(decir="No hay ninguna partida abierta.")
        else:
            salida()
        return
    tablero = ajedrez.tablero_de(est)

    if a.cerrar:
        ajedrez.guardar_pgn(est)
        ajedrez.borrar()
        salida(decir="Dejamos la partida. La guardo por si quieres verla.")
        return

    if a.estado:
        n = len(est["jugadas"]) // 2 + 1
        ultima = ""
        if est["jugadas"]:
            prev = ajedrez.tablero_de({"jugadas": est["jugadas"][:-1]})
            ultima = " Lo ultimo, " + ajedrez.como_se_dice(prev, chess.Move.from_uci(est["jugadas"][-1])) + "."
        salida(hay_partida=True, decir="Vamos por la jugada %d.%s Te toca." % (n, ultima))
        return

    if a.deshacer:
        # las dos ultimas medias jugadas: la suya y la mia. Es la salvaguarda de esta
        # funcion: no se confirma nada con un "si" -al 70,4 % de oido, un si mal oido no es
        # una confirmacion-, se deshace.
        quitadas = 0
        while est["jugadas"] and quitadas < 2:
            est["jugadas"].pop()
            quitadas += 1
        ajedrez.guardar(est)
        salida(hay_partida=True, decir="Hecho, la retiro. Te toca otra vez.")
        return

    # --- una jugada ---------------------------------------------------------
    mov = None
    if a.elegir in (1, 2):
        # contestando a la pregunta de antes: las opciones viajaron en el estado
        # Y LA PREGUNTA CADUCA (revision del 23/09). Nada la borraba: ni --estado, ni
        # --deshacer, ni reiniciar la consola. La partida vive dias, asi que un "dos" suelto
        # tres dias despues hacia la jugada que quedo pendiente. Un minuto es de sobra: la
        # pregunta se contesta en el momento o no se contesta.
        ops = est.get("preguntadas") or []
        vieja = (time.time() - float(est.get("preguntadas_ts", 0))) > 60
        if vieja and ops:
            est.pop("preguntadas", None)
            est.pop("preguntadas_ts", None)
            ajedrez.guardar(est)
            salida(hay_partida=True, decir="Ya no tengo esa pregunta abierta. Dime la jugada.")
            return
        if len(ops) >= a.elegir:
            try:
                mov = chess.Move.from_uci(ops[a.elegir - 1])
            except Exception:       # noqa: BLE001
                mov = None
        est.pop("preguntadas", None)
        est.pop("preguntadas_ts", None)
        if mov is None or mov not in tablero.legal_moves:
            ajedrez.guardar(est)
            salida(hay_partida=True, decir="Se me fue. Dime la jugada otra vez.")
            return
    else:
        mov, motivo, cand = ajedrez.elegir(tablero, a.dicho)
        if mov is None:
            if cand:
                est["preguntadas"] = [m.uci() for m in cand]
                est["preguntadas_ts"] = time.time()
                ajedrez.guardar(est)
                salida(hay_partida=True,
                       decir="¿%s o %s?" % (ajedrez.como_se_dice(tablero, cand[0]),
                                            ajedrez.como_se_dice(tablero, cand[1])),
                       opciones=[ajedrez.como_se_dice(tablero, m) for m in cand])
                return
            # no tiene forma de jugada: NO es cosa del ajedrez, que siga su camino normal
            salida(hay_partida=True)
            return

    est.pop("preguntadas", None)
    est.pop("preguntadas_ts", None)
    # SE GUARDA COMO SE DICE ANTES DE MOVER: despues del push, board.san() ya no vale para
    # esta jugada. Hace falta para contestar cuando se eligio con --elegir, donde a.dicho
    # llega vacio y Nova decia "hecho" -justo en el unico camino donde la confirmacion hacia
    # falta de verdad, porque se llego ahi por dos jugadas que se parecen un 70 % al oido.
    dicha_suya = ajedrez.como_se_dice(tablero, mov)
    tablero.push(mov)
    est["jugadas"].append(mov.uci())
    fin = cierra_si_acabo(tablero, est)
    if fin:
        salida(decir=fin, fin=True)
        return

    resp, motivo = ajedrez.juega_maquina(tablero, elo=est.get("elo", 1320), ms=150)
    if resp is None:
        # SE DESHACE LA JUGADA DE BRAYA (revision del 23/09). Antes se guardaba igual, con
        # las NEGRAS a mover: la frase siguiente suya se emparejaba contra las jugadas
        # legales de Nova y braya acababa moviendo las piezas del rival sin saberlo. Y
        # --estado lo contaba tan tranquilo. El caso no es raro: modelos\stockfish\ no va
        # en el repositorio y son 98 MB.
        est["jugadas"].pop()
        ajedrez.guardar(est)
        salida(hay_partida=True, decir="No me funciona el motor: %s. Tu jugada no cuenta." % motivo)
        return
    dicha_mia = ajedrez.como_se_dice(tablero, resp)
    tablero.push(resp)
    est["jugadas"].append(resp.uci())
    fin = cierra_si_acabo(tablero, est)
    if fin:
        salida(decir=dicha_mia + ". " + fin, fin=True)
        return
    ajedrez.guardar(est)
    # NOMBRA TU JUGADA ANTES DE LA SUYA: asi la confirmacion va incluida sin gastar un turno,
    # y braya sabe que se entendio lo que dijo. Y nada mas: ni evaluar ni comentar.
    jaque = " Jaque." if tablero.is_check() else ""
    salida(hay_partida=True, decir="%s; yo, %s.%s" % (a.dicho.strip() or dicha_suya, dicha_mia, jaque))


if __name__ == "__main__":
    main()
