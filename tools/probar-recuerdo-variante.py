# -*- coding: utf-8 -*-
# QUE EL RECUERDO GUARDE TAMBIEN LA FRASE CON LA QUE TU LO DIJISTE (26/09, idea 58 de las 121).
#
# Los recuerdos los escribe la API en tercera persona y con SUS palabras ("Braya tiene una funda
# y esta teniendo problemas"); braya habla con las suyas y en trozos ("no cierra bien, no coincide
# con la consola"). Por eso la busqueda por palabras casi nunca los encuentra: 97 de 121 recuerdos
# no salen ni una vez en 365 turnos. La frase de braya YA esta en la mano al guardar (job.pregunta):
# se deja dentro como variante -lo que ya se hace con las respuestas, no con los episodios-, con la
# guarda de >= 3 palabras de contenido para no ensuciar la busqueda con un "no, no, no".
#
# Se EJECUTA el Cerebro de verdad (charla_memoria.Cerebro), no una copia.
import os
import shutil
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import charla_memoria as cm  # noqa: E402

mal = 0


def comp(etq, ok, det=""):
    global mal
    if not ok:
        mal += 1
    print("  %s  %-56s %s" % ("OK " if ok else "MAL", etq, ("-> %s" % (det,)) if det != "" else ""))


class Reloj:
    t = 1_800_000_000.0

    def __call__(self):
        return self.t


carpeta = tempfile.mkdtemp(prefix="nova-variante-")
try:
    c = cm.Cerebro(carpeta, reloj=Reloj())

    print("")
    print("-- guardar_texto deja la frase de braya como variante --")
    api = "Braya tiene una funda para una consola y esta teniendo problemas con ella"
    mia = "la funda no cierra bien y no coincide con la consola"
    r = c.guardar_texto("episodio", api, mia)
    comp("1. el recuerdo guarda la frase de braya como variante", bool(r) and mia in (r.get("variantes") or []), r.get("variantes"))
    # y ahora SI se encuentra por las palabras de braya (antes, con la frase de la API, no)
    hits = c.buscar("la funda no cierra bien", tipos={"episodio"}, k=3)
    comp("2. y se encuentra buscando por TUS palabras", any(h["r"]["id"] == r["id"] for h in hits), "%d hits" % len(hits))

    print("")
    print("-- la guarda: una frase corta y generica NO entra --")
    r2 = c.guardar_texto("contado", "Braya menciona que le gusta cocinar los domingos por la manana", "no no no")
    comp("3. 'no no no' (0-1 palabras de contenido) NO se guarda como variante", bool(r2) and ("no no no" not in (r2.get("variantes") or [])), r2.get("variantes"))
    # dos palabras de contenido tampoco; tres si
    r3 = c.guardar_texto("contado", "Braya prefiere el te verde por la tarde segun cuenta", "quiero descansar")
    comp("   con 2 palabras de contenido, tampoco", bool(r3) and ("quiero descansar" not in (r3.get("variantes") or [])), r3.get("variantes"))
    r4 = c.guardar_texto("contado", "Braya suele jugar de noche a juegos tranquilos por lo general", "juego mucho de madrugada tranquilo")
    comp("   con 3 o mas, si entra", bool(r4) and ("juego mucho de madrugada tranquilo" in (r4.get("variantes") or [])), r4.get("variantes"))

    print("")
    print("-- aplicar_revision pasa tu frase (job.pregunta) al guardar --")
    job = {"id": 123, "pregunta": "mi mando dejo de funcionar en los juegos de repente", "respuesta": "x", "origen": "api", "intentos": 0}
    rev = {"recuerdo": "Braya tuvo un problema con el mando en varios juegos", "hechos": []}
    c.aplicar_revision(job, rev)
    ep = [x for x in c.datos["recuerdos"] if x["tipo"] == "episodio" and "problema con el mando" in x["pregunta"]]
    comp("4. el episodio guardado lleva tu frase como variante", len(ep) == 1 and (job["pregunta"] in (ep[0].get("variantes") or [])), ep[0].get("variantes") if ep else "no se guardo")

finally:
    shutil.rmtree(carpeta, ignore_errors=True)

print("")
if mal:
    print("  %d caso(s) MAL" % mal)
    sys.exit(1)
print("  el recuerdo se encuentra por tus palabras")
sys.exit(0)
