# -*- coding: utf-8 -*-
# QUIEN MIRA A LOS QUE MIRAN (22/09).
#
# El banco entero son 112 secciones en verde, y de ese verde salen las decisiones. Este
# fichero comprueba que ese verde signifique algo. Tres cosas, las tres encontradas
# peinando los propios bancos y las tres reproducidas antes de arreglarlas:
#
# 1. RUTAS ABSOLUTAS. Ocho bancos .ps1 y dos .py leian assistant.ps1 (o la raiz del
#    proyecto) por su ruta completa escrita a mano. En una copia del repo en otra carpeta
#    seguirian midiendo los ficheros de SIEMPRE: verde sobre codigo que no es el que se
#    acaba de tocar. Y al renombrar la carpeta se caerian todos por algo que no tiene nada
#    que ver con lo que prueban.
#
# 2. COMPARAR SIN ORDEN NI LITERALIDAD. probar-destinos.ps1 comprobaba las cadenas de
#    varias acciones con '-notlike "*$meta*"', que tiene dos agujeros: no exige ORDEN -una
#    cadena de tres acciones devuelta al reves pasaba en verde, reproducido- y trata lo
#    esperado como PATRON, asi que un '*' o unos corchetes dentro dejaban de compararse
#    como texto.
#
# 3. ETAPAS MUDAS. probar-ocr.ps1 imprimia cuatro etapas -OCR, nota, busqueda, veredicto- y
#    solo comprobaba UNA: los digitos del OCR. Si Add-Memoria no escribia o Find-EnMemoria
#    no encontraba nada, el banco acababa en verde igual. Ademas no traia Get-Distancia,
#    que Find-EnMemoria llama por dentro: hoy pasaba de milagro porque con ese texto entra
#    por la coincidencia exacta, pero en cuanto una palabra cambiase moriria con
#    CommandNotFoundException... y nadie se enteraria, porque el resultado no se miraba.
#
# Lo que se comprueba aqui NO es que esos tres esten arreglados -eso ya lo dice que corran
# en verde-, sino que NO PUEDAN VOLVER, que es distinto y es lo que hace falta.
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(RAIZ, "tools")

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-52s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


def ficheros():
    for n in sorted(os.listdir(TOOLS)):
        if n.endswith((".ps1", ".py")) and not n.startswith("__"):
            p = os.path.join(TOOLS, n)
            try:
                yield n, io.open(p, encoding="utf-8-sig", errors="replace").read()
            except Exception:
                continue


def sin_comentarios(nombre, texto):
    # los comentarios NOMBRAN la ruta vieja para explicar que se quito; medir sobre ellos
    # seria medir la explicacion, que es un tropiezo que ya me costo dos rojos hoy
    marca = "#"
    return "\n".join(re.sub(marca + ".*$", "", l) for l in texto.split("\n"))


print("")
print("-- 1. ningun banco lee por una ruta escrita a mano --")
# Se busca la raiz del proyecto tal cual, que es como estaba escrita. Quedan fuera los DOS
# sitios donde la ruta es un DATO de la prueba y no una lectura: probar-juego-primer-plano
# usa una ruta de .exe como proceso de mentira, y probar-texto-capsula mete una ruta larga
# dentro de una frase para ver como la parte la capsula.
DATOS = {"probar-juego-primer-plano.ps1", "probar-texto-capsula.ps1"}
culpables = []
for n, s in ficheros():
    if n in DATOS:
        continue
    codigo = sin_comentarios(n, s)
    for m in re.finditer(r"[A-Za-z]:\\+Users\\+braya\\+Documents\\+voice-ctrl", codigo):
        culpables.append(n)
        break
comp("ninguno trae la raiz del proyecto a fuego", not culpables,
     ("los hay: " + ", ".join(sorted(set(culpables)))) if culpables else "")
# y que los diez arreglados usen de verdad la forma relativa
arreglados = ["medir-respiros.ps1", "probar-autosordina.ps1", "probar-avisos.ps1",
              "probar-funciones.ps1", "probar-json-ui.ps1", "probar-listas.ps1",
              "probar-parte.ps1", "probar-voz-dueno.ps1", "probar-ocr.ps1"]
malos = []
for n in arreglados:
    s = io.open(os.path.join(TOOLS, n), encoding="utf-8-sig", errors="replace").read()
    if "Split-Path -Parent $PSScriptRoot" not in s:
        malos.append(n)
comp("los .ps1 salen de $PSScriptRoot", not malos, ", ".join(malos) if malos else "%d bancos" % len(arreglados))
malos = []
for n in ("medir-vosk-grande.py", "probar-precarga.py", "probar-bancos-de-verdad.py"):
    s = io.open(os.path.join(TOOLS, n), encoding="utf-8").read()
    if "os.path.dirname(os.path.dirname(os.path.abspath(__file__)))" not in s:
        malos.append(n)
comp("y los .py de __file__", not malos, ", ".join(malos) if malos else "3 ficheros")
# LA PRUEBA DE VERDAD: que la ruta que sale exista y sea ESTE repo, no otro.
comp("y la raiz calculada es la de este repo",
     os.path.exists(os.path.join(RAIZ, "assistant.ps1")) and os.path.exists(os.path.join(RAIZ, "wake_vosk.py")),
     os.path.basename(RAIZ))

print("")
print("-- 2. las cadenas de acciones se comparan en orden y al pie de la letra --")
dest = io.open(os.path.join(TOOLS, "probar-destinos.ps1"), encoding="utf-8-sig").read()
comp("ya no compara con -notlike", '-notlike "*$_*"' not in sin_comentarios("d", dest))
comp("usa IndexOf ordinal (literal, sin comodines)", "[StringComparison]::Ordinal" in dest)
comp("y avanza la posicion, que es lo que exige el orden",
     bool(re.search(r"\$pos = \$i \+ \$m\.Length", dest)))
# Y SE EJECUTA, que es lo unico que lo demuestra: la misma cadena al derecho y al reves.
metas = ["abre steam", "sube el brillo", "pon modo noche"]


def faltan_ordinal(hace, metas):
    pos, faltan = 0, []
    for m in metas:
        i = hace.find(m, min(pos, len(hace)))
        if i < 0:
            faltan.append(m)
        else:
            pos = i + len(m)
    return faltan


derecho = "abre steam + sube el brillo + pon modo noche"
reves = "pon modo noche + sube el brillo + abre steam"
comp("al derecho sigue pasando", not faltan_ordinal(derecho, metas))
comp("y AL REVES ya no pasa", len(faltan_ordinal(reves, metas)) > 0,
     "antes daba 0 faltas: pasaba en verde")
# un comodin dentro de lo esperado ya no casa con cualquier cosa
comp("un '*' en lo esperado se compara como texto",
     faltan_ordinal("abre lo que sea", ["abre *"]) != [])

print("")
print("-- 3. ninguna etapa impresa se queda sin comprobar --")
ocr = io.open(os.path.join(TOOLS, "probar-ocr.ps1"), encoding="utf-8-sig").read()
comp("probar-ocr para en el primer error", "$ErrorActionPreference = 'Stop'" in ocr)
comp("comprueba que la nota se escribio", "Add-Memoria no dejo ninguna nota" in ocr)
comp("que la nota trae el codigo leido", "la nota no tiene el codigo leido" in ocr)
comp("que lo encuentra al preguntarlo", "no lo encuentra al preguntarlo" in ocr)
# Y LA OTRA MITAD, que es la que evita una respuesta equivocada: que NO conteste a algo
# que no tiene nada que ver.
comp("y que NO contesta a una pregunta de otra cosa", "una pregunta que no tiene nada que ver" in ocr)
comp("trae Get-Distancia, que Find-EnMemoria llama por dentro",
     "TraerFn 'Get-Distancia'" in ocr)

print("")
print("-- y la regla general: lo que se imprime, se mira --")
# Un banco que escribe una etapa y nunca sale con exit 1 no esta comprobando: esta
# narrando. Se cuenta cuantos 'exit 1' tiene cada uno de los tocados hoy.
for n in ("probar-ocr.ps1", "probar-destinos.ps1"):
    s = io.open(os.path.join(TOOLS, n), encoding="utf-8-sig").read()
    comp("%s puede fallar de verdad" % n, s.count("exit 1") >= 1, "%d salidas en rojo" % s.count("exit 1"))

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  los bancos miden este repo, en orden y sin etapas mudas")
sys.exit(0)
