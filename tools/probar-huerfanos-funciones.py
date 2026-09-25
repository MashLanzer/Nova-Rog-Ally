# -*- coding: utf-8 -*-
"""LAS FUNCIONES DE VIGILANCIA DEL PADRE, SACADAS DEL .PY REAL Y EJECUTADAS.

No se reconstruyen aqui ni se leen con una expresion regular: se sacan del arbol de Python de
voz_windows.py y se ejecutan de verdad contra procesos que este banco crea y mata. Un banco que
solo mirase el texto saldria verde con una funcion que devolviera siempre True.

Y SE COMPARA CON LA DEL OIDO: wake_vosk.py tiene la misma pareja desde el 13/09 y esta probada
en uso real (en el registro se lee "el asistente ya no existe; salgo y suelto el microfono", 5
veces). Si las dos copias divergen, una de las dos esta mal y hay que enterarse.
"""
import ast
import io
import os
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
mal = [0]


def comp(que, ok, detalle=""):
    print("  %-4s %s%s" % ("ok" if ok else "MAL", que, ("  (%s)" % detalle) if detalle else ""))
    if not ok:
        mal[0] += 1


def sacar(ruta, nombres):
    """Devuelve {nombre: codigo fuente} usando el arbol, no una regex."""
    src = io.open(ruta, encoding="utf-8").read()
    arbol = ast.parse(src)
    fuera = {}
    for n in ast.walk(arbol):
        if isinstance(n, ast.FunctionDef) and n.name in nombres:
            fuera[n.name] = ast.get_source_segment(src, n)
    return fuera


P_VOZ = os.path.join(RAIZ, "voz_windows.py")
P_OIDO = os.path.join(RAIZ, "wake_vosk.py")

print("-- 2. proceso_vivo y padre_vivo, ejecutadas de verdad --")
trozos = sacar(P_VOZ, ("proceso_vivo", "padre_vivo"))
comp("proceso_vivo esta en voz_windows.py", "proceso_vivo" in trozos)
comp("padre_vivo esta en voz_windows.py", "padre_vivo" in trozos)
if len(trozos) < 2:
    print("")
    print("  MAL: sin las dos funciones no se puede probar nada mas")
    sys.exit(1)

# un PID que existe de verdad: el mio. Y uno que YA NO existe: un proceso que arranco y muere.
muerto = subprocess.Popen([sys.executable, "-c", "pass"])
muerto.wait()
PID_MUERTO = muerto.pid
vivo = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
PID_VIVO = vivo.pid

try:
    esp = {"PID_PADRE": 0}
    exec(trozos["proceso_vivo"], esp)
    exec(trozos["padre_vivo"], esp)
    pv = esp["proceso_vivo"]

    comp("un proceso vivo sale vivo", pv(PID_VIVO) is True, "el mio, PID %d" % PID_VIVO)
    comp("uno que ya murio sale muerto", pv(PID_MUERTO) is False, "PID %d" % PID_MUERTO)
    comp("el cero sale muerto", pv(0) is False, "no hay proceso 0")

    # ANTE LA DUDA, VIVO: es la regla que tiene escrita wake_vosk.py, y aqui importa mas aun.
    # Dar por muerto a quien no lo esta deja a braya sin dictado en mitad de una partida.
    comp("sin NOVA_PID_PADRE se sigue vivo", esp["padre_vivo"]() is True, "un worker suelto no se suicida")

    esp2 = {"PID_PADRE": PID_MUERTO}
    exec(trozos["proceso_vivo"], esp2)
    exec(trozos["padre_vivo"], esp2)
    comp("con el padre muerto, padre_vivo dice que no", esp2["padre_vivo"]() is False, "es lo que dispara el cierre")

    esp3 = {"PID_PADRE": PID_VIVO}
    exec(trozos["proceso_vivo"], esp3)
    exec(trozos["padre_vivo"], esp3)
    comp("con el padre vivo, dice que si", esp3["padre_vivo"]() is True, "")

    # LAS DOS COPIAS, LA DEL OIDO Y LA DEL DICTADO
    print("")
    print("-- 2b. la copia del oido y la del dictado no divergen --")
    delOido = sacar(P_OIDO, ("proceso_vivo",))
    comp("wake_vosk.py sigue teniendo la suya", "proceso_vivo" in delOido)
    if "proceso_vivo" in delOido:
        def pelar(t):
            fuera = []
            for l in t.split(chr(10)):
                l = l.strip()
                if l and not l.startswith("#"):
                    fuera.append(l)
            return chr(10).join(fuera)
        comp("y las dos hacen exactamente lo mismo",
             pelar(delOido["proceso_vivo"]) == pelar(trozos["proceso_vivo"]),
             "misma tecnica: OpenProcess + GetExitCodeProcess, 259 = sigue viva")
        # y que sea la tecnica buena, no os.getppid(): en Windows el hijo NO se reasigna
        # cuando el padre muere, asi que getppid sigue devolviendo el mismo numero para
        # siempre y no sirve para saber si aquel proceso vive.
        comp("y no se conforma con os.getppid()",
             "OpenProcess" in trozos["proceso_vivo"] and "getppid" not in trozos["proceso_vivo"],
             "en Windows getppid no cambia cuando el padre muere")
finally:
    try:
        vivo.kill()
    except Exception:
        pass

print("")
if mal[0]:
    print("  %d MAL" % mal[0])
    sys.exit(1)
print("  las funciones del worker hacen lo que dicen")
sys.exit(0)
