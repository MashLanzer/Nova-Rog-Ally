# -*- coding: utf-8 -*-
"""Que quien CREA una accion y quien la EJECUTA hablen del mismo campo.

    python tools\\probar-acciones.py

Por que existe (17/09): "volumen al 70" PONIA EL VOLUMEN A CERO. Resolve-Fragment creaba
la accion con el campo 'nivel' y el ejecutor leia $a.pct, que no existia; en PowerShell
eso es $null, [int]$null es 0, y Nova bajaba el volumen a cero mientras respondia
"volumen al 70 por ciento". Hacer lo contrario de lo pedido y presumir de ello.

Vivio tanto porque el banco no lo podia ver: `assistant.ps1 -Probar` imprime la
DESCRIPCION de cada accion y nunca entra en el switch que la ejecuta, y pruebas\\destinos
compara textos. La descripcion decia "volumen al 70 por ciento", asi que todo salia verde.

Ejecutar las 113 ramas de verdad no es opcion: abririan programas, tocarian el volumen y
el brillo, apagarian el equipo. Pero no hace falta ejecutar para ver el fallo: basta
comparar, para cada tipo de accion, los campos que los productores ESCRIBEN con los que
su rama del switch LEE. Si una rama lee un campo que nadie de su tipo crea, es el bug del
volumen otra vez.
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, "assistant.ps1")

# 'desc' lo pone casi todo el mundo y muchas ramas lo REESCRIBEN para contestar; 'kind'
# es la propia etiqueta. Ninguno de los dos dice nada sobre este fallo.
IGNORAR = {"kind", "desc"}


def bloque(texto, ini):
    """Del '{' en ini hasta su '}', contando llaves."""
    hondo, i = 0, ini
    while i < len(texto):
        if texto[i] == "{":
            hondo += 1
        elif texto[i] == "}":
            hondo -= 1
            if hondo == 0:
                return texto[ini:i + 1]
        i += 1
    return texto[ini:]


def productores(src):
    """kind -> conjunto de campos que alguien le pone al crearlo.

    OJO con las dos formas de poner un campo, que la primera version de esta prueba no
    veia y la hacian gritar en falso (tres avisos, los tres mentira):
      1. dentro del hashtable, separados por ';' PERO TAMBIEN por salto de linea:
         @{ kind = 'volumenApp'; proceso = ...; nombre = ...
                    silenciar = $silenciar; sube = $sube }
      2. anadidos DESPUES de crearlo, que es como se ponen los opcionales:
         if ($pct) { $acc.pct = [int]$pct }        y       $x.sinVerbo = $true
    Una prueba que avisa de lo que no es acaba ignorandose, asi que mejor perderse algun
    caso que gritar en falso.
    """
    campos = {}
    for m in re.finditer(r"@\{\s*kind\s*=\s*'([a-zA-Z]+)'", src):
        tipo = m.group(1)
        ini = src.rfind("{", 0, m.end())
        cuerpo = bloque(src, ini)
        puestos = set(re.findall(r"(?:[;{]|\n)\s*([a-zA-Z]+)\s*=(?!=)", cuerpo))
        linea = src.count("\n", 0, ini) + 1
        # UNO POR UNO, NO EN BLOQUE. Aqui estaba el fallo que dejo esta prueba inutil dos
        # veces seguidas: 'volumenPct' se crea en CUATRO sitios y tres ponian 'pct'; al
        # juntarlos todos, el cuarto -el roto, el que ponia 'nivel'- quedaba tapado por
        # sus hermanos. Y era justo ESE el que hacia "volumen al 70" -> volumen a 0.
        campos.setdefault(tipo, []).append((linea, puestos - IGNORAR))
    return campos


# CAMPOS QUE SE PONEN LEJOS DEL HASHTABLE, comprobados A MANO uno por uno. Son la unica
# excepcion, y va explicita a proposito: la version anterior de esta prueba intentaba
# adivinarlos barriendo 1500 caracteres detras del productor, y eso la dejo INUTIL. Al
# validarla contra el bug del volumen reintroducido dio el mismo resultado que sin el:
# en esa ventana aparecia algun otro ".pct =" y daba el campo por puesto. Una ventana a
# ojo tapa lo que busca y no alcanza lo que necesita; una lista corta y verificada, no.
EXCEPCIONES = {
    ("app", "sinVerbo"): "se pone en Resolve-Fragment con $x.sinVerbo = $true",
    ("volumenApp", "pct"): "se pone justo despues con if ($pct) { $acc.pct = [int]$pct }",
    # el productor de la 2538 SI lo pone; el generico ("dicta un correo") no lo necesita,
    # y la rama lo consulta dentro de "if (-not $pd -and $a.abrir)". No se generaliza a
    # "cualquier $a.x dentro de un if" a proposito: eso taparia el bug del volumen, cuya
    # segunda linea es "if (-not [AX]::PonerVolumen($a.pct))".
    ("dictadoLargo", "abrir"): "opcional: solo lo pone la forma que nombra la ventana (2538)",
}


def consumidores(src):
    """kind -> conjunto de campos que su rama del switch LEE (no los que asigna)."""
    m = re.search(r"switch\s*\(\s*\$a\.kind\s*\)\s*\{", src)
    if not m:
        print("No encuentro el switch del ejecutor; ha cambiado de forma.")
        sys.exit(1)
    cuerpo = bloque(src, src.rfind("{", 0, m.end()))
    leidos = {}
    for r in re.finditer(r"'([a-zA-Z]+)'\s*\{", cuerpo):
        tipo = r.group(1)
        rama = bloque(cuerpo, cuerpo.find("{", r.end() - 1))
        usa = set()
        # CAMPOS QUE SE CONSULTAN ANTES DE USARSE = OPCIONALES POR DISENO. La rama 'url'
        # lo enseña de libro: "if ($a.youtube) { ... }", "if ($a.carpeta) { ... }" y
        # "if ($a.videoN) { ... } else { 1 }". Abrir una web normal no lleva videoN, y
        # exigirlo daba 11 avisos en falso. Lo que delata el bug del volumen es leer el
        # campo A PELO, sin preguntar: "$script:uiVolumen = [int]$a.pct".
        opcionales = set(re.findall(r"if\s*\(\s*(?:-not\s+)?\$a\.([a-zA-Z]+)\s*\)", rama))
        opcionales |= set(re.findall(r"\$a\.([a-zA-Z]+)\s*(?:-eq|-ne|-gt|-lt|-ge|-le)\s", rama))
        for c in re.finditer(r"\$a\.([a-zA-Z]+)", rama):
            campo = c.group(1)
            resto = rama[c.end():c.end() + 4]
            # "$a.desc = ..." es escribir la respuesta, no leer el dato
            if re.match(r"\s*=(?!=)", resto):
                continue
            # "$a.ContainsKey(...)" es un METODO del hashtable, no un campo. Sin esto,
            # 'cerrarTodo' salia como fallo y era mentira.
            if resto.startswith("("):
                continue
            if campo in opcionales:
                continue
            usa.add(campo)
        leidos.setdefault(tipo, set()).update(usa - IGNORAR)
    return leidos


def main():
    src = io.open(FUENTE, encoding="utf-8-sig").read()
    crean = productores(src)
    leen = consumidores(src)
    print("  acciones que se crean: %d     ramas que las ejecutan: %d" % (len(crean), len(leen)))

    malos, perdonados = [], []
    for tipo in sorted(leen):
        if tipo not in crean:
            continue          # se crea en otro sitio (reglas, recetas, el plan...)
        # cada sitio que crea esta accion se juzga POR SEPARADO: el bug del volumen era
        # una rama de cuatro, y mirandolas juntas no se veia
        for linea, puestos in crean[tipo]:
            faltan = set()
            for campo in leen[tipo] - puestos:
                if (tipo, campo) in EXCEPCIONES:
                    perdonados.append((tipo, campo))
                else:
                    faltan.add(campo)
            if faltan:
                malos.append((tipo, linea, sorted(faltan), sorted(puestos)))
    for tipo, campo in sorted(set(perdonados)):
        print("  --   '%s'.%s: %s" % (tipo, campo, EXCEPCIONES[(tipo, campo)]))

    print("")
    if not malos:
        print("  OK   nadie lee un campo que su tipo de accion no cree")
        print("")
        print("todo correcto")
        return 0

    for tipo, linea, faltan, hay in malos:
        print("  MAL  assistant.ps1:%d crea '%s' SIN %s (pone: %s), y su rama lo lee"
              % (linea, tipo, ", ".join(faltan), ", ".join(hay) or "nada"))
    print("")
    print("%d acciones MAL: el ejecutor lee un campo vacio, asi que hara algo distinto" % len(malos))
    print("(es el fallo de 'volumen al 70' -> volumen a 0; un campo vacio es 0 o cadena vacia)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
