# -*- coding: utf-8 -*-
# LA NOCHE QUE NOVA SE QUEDO MUDA (21/09). Del log, tal cual:
#   2026-09-20 23:39:11  charla dice: Te esta enganchando o aun estas viendo como va la cosa?
#   2026-09-20 23:39:12  voz online: ERR [WinError 32] El proceso no tiene acceso al
#                        archivo porque esta siendo utilizado por otro proceso: ...mp3.part
#   2026-09-20 23:39:12  voz: no hay ninguna voz disponible
# braya oyo media respuesta y silencio, en mitad de una charla. Son DOS fallos encadenados
# y aqui se prueban los dos:
#   1. LA CAUSA: hay dos workers de voz -el que habla y el que se adelanta preparando la
#      frase- y los dos escribian en el MISMO archivo temporal, porque el nombre salia del
#      texto y el texto era el mismo.
#   2. LA RED QUE NO ESTABA: el respaldo de Piper exigia $script:piperProc, que nunca se
#      llena porque Initialize-Voz devuelve antes cuando la voz en linea arranca bien.
#      Piper llevaba sin sonar desde el 10/09 y nadie lo sabia.
import io
import os
import re
import sys
import time
import tempfile
import shutil

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fallos = []


def comp(etiqueta, ok, detalle=""):
    print("  %s  %-58s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos.append(etiqueta)


w = io.open(os.path.join(RAIZ, "tts_worker.py"), encoding="utf-8").read()
ps = io.open(os.path.join(RAIZ, "assistant.ps1"), encoding="utf-8-sig").read()

print("")
print("-- 1. cada worker escribe en SU archivo temporal --")
comp("el .part del audio lleva el PID", 'ruta + (".%d.part" % os.getpid())' in w)
comp("y el de la envolvente tambien", 'ruta_env + (".%d.part" % os.getpid())' in w)
comp("ya no queda ningun .part sin PID", '+ ".part"' not in w)

# y que dos procesos distintos NO se pisen: el nombre tiene que salir distinto
nombres = set()
for pid in (1234, 5678):
    nombres.add("/tmp/abc.mp3" + (".%d.part" % pid))
comp("dos procesos dan dos nombres distintos", len(nombres) == 2)
# pero el destino FINAL es el mismo, que es lo que hace que la cache siga sirviendo
comp("y el mp3 final sigue siendo uno solo", w.count("os.replace(parcial, ruta)") == 1)

print("")
print("-- 2. los .part huerfanos se barren (antes no los miraba nadie) --")
m = re.search(r"(?ms)^def limpiar_cache\(\):.*?(?=^\S|\Z)", w)
if not m:
    comp("encuentro limpiar_cache en tts_worker.py", False)
else:
    base = tempfile.mkdtemp(prefix="vozpart-")
    try:
        ent = {"os": os, "time": time, "SALIDA": base, "CACHE_MAX_MB": 50}
        exec(compile(m.group(0), "limpiar_cache", "exec"), ent)

        def pon(nombre, edad_seg, tam=1000):
            r = os.path.join(base, nombre)
            io.open(r, "wb").write(b"x" * tam)
            t = time.time() - edad_seg
            os.utime(r, (t, t))
            return r

        viejo = pon("aaa.mp3.4321.part", 3600)
        nuevo = pon("bbb.mp3.9999.part", 60)
        audio = pon("ccc.mp3", 3600)
        ent["limpiar_cache"]()
        comp("un .part de hace una hora se borra", not os.path.exists(viejo))
        comp("uno de hace un minuto NO (puede estar escribiendose)", os.path.exists(nuevo))
        comp("y un mp3 bueno no se toca", os.path.exists(audio))

        # y que no reviente con la carpeta vacia ni con basura dentro
        for f in os.listdir(base):
            os.remove(os.path.join(base, f))
        ent["limpiar_cache"]()
        os.mkdir(os.path.join(base, "una-carpeta.part"))
        ent["limpiar_cache"]()
        comp("no revienta con la carpeta vacia ni con una carpeta .part dentro", True)
    finally:
        shutil.rmtree(base, ignore_errors=True)

print("")
print("-- 3. el respaldo de Piper, que llevaba sin poder usarse desde el 10/09 --")
comp("ya no exige $script:piperProc para intentarlo",
     "if ($script:piperProc) { if (Say-Piper $t) { return } }" not in ps)
comp("lo intenta si hay voz y el motor no es el de Windows",
     "if ($VozOn -and $VozMotor -ne 'windows') { if (Say-Piper $t) { return } }" in ps)
# la razon por la que nunca se llenaba: esa linea sigue ahi y hay que probarlo CON ella
comp("Initialize-Voz sigue devolviendo antes si la voz en linea arranca",
     "if ($VozMotor -eq 'online' -and (Initialize-Online)) { return }" in ps)
# Say-Piper tiene que saber arrancar Piper sola, o esto no vale de nada
comp("y Say-Piper arranca Piper sola cuando no esta",
     re.search(r"function Say-Piper.{0,400}?if \(-not \(Initialize-Piper\)\) \{ return \$false \}",
               ps, re.S) is not None)
comp("Initialize-Piper se planta en seco si falta el .exe o el modelo",
     "if (-not (Test-Path -LiteralPath $PiperExe) -or -not (Test-Path -LiteralPath $PiperModelo)) { return $false }" in ps)
# LA LISTA DE RESIDENTES YA NO ESTA ESCRITA A MANO (25/09, idea 20). Esto buscaba
# "foreach ($pW in @($script:wakeProc" y luego cada residente por su nombre dentro de esa
# linea. Ese mismo dia la lista se cambio por Get-ProcesosResidentes -que barre las variables
# *Proc del ambito, para que no haya lista que acordarse de ampliar- y SEIS comprobaciones se
# pusieron rojas con el fallo arreglado. El banco estaba anclado a como estaba escrito.
#
# Lo de ahora es mas fuerte: que el parar limpio pregunte por los residentes, y que la funcion
# que responde este escrita para encontrarlos por su FORMA (una variable *Proc que contiene un
# proceso), no por una lista. Asi un residente nuevo entra solo, que es lo que la lista no hacia.
_kill = ps[ps.index("foreach ($pW in @(Get-ProcesosResidentes"):] if "foreach ($pW in @(Get-ProcesosResidentes" in ps else ""
comp("y al parar limpio se pregunta por los residentes", bool(_kill))
_res = ps[ps.index("function Get-ProcesosResidentes"):] if "function Get-ProcesosResidentes" in ps else ""
_res = _res[:2000]
comp("  y esa funcion barre las variables *Proc", "-notlike '*Proc'" in _res and "Get-Variable -Scope Script" in _res)
comp("  quedandose solo con los procesos", "[System.Diagnostics.Process]" in _res)

# que lo que hace falta este de verdad en el disco, o el respaldo sigue sin existir
for rel in ("piper/piper.exe", "piper/es_MX-claude-high.onnx"):
    comp("esta instalado %s" % rel, os.path.exists(os.path.join(RAIZ, rel.replace("/", os.sep))))

print("")
if fallos:
    print("  %d fallo(s)" % len(fallos))
    sys.exit(1)
print("  si la voz en linea falla, Nova ya no se queda muda")
sys.exit(0)
