# -*- coding: utf-8 -*-
"""Que paquetes le faltan a cada banco CON EL INTERPRETE QUE LO LANZA.

Lo usa tools\probar-python-interprete.ps1. Recibe un fichero de texto con una ruta .py
por linea y escribe una linea por banco:

    nombre.py|numpy,httpx|            (le faltan esos y los importa A PELO: no arranca)
    nombre.py||numpy                  (le falta numpy, pero el import va dentro de un try)
    nombre.py||                       (no le falta ninguno)
    nombre.py|?|                      (no se pudo parsear)

LA DIFERENCIA ENTRE LAS DOS COLUMNAS ES TODO EL BANCO. Un import a pelo de algo que no
esta es muerte segura: el fichero no llega ni a su primera linea de codigo. Un import
dentro de un try suele ser lo contrario -charla_memoria.py lo hace a proposito para
degradar a busqueda por palabras cuando no hay numpy, que es la regla 7 de la casa-, asi
que exigirle red seria pedir ceremonia por gusto y acabar con un aviso que sale siempre,
que es la unica forma segura de matar un aviso.

Se lanza a proposito con el MISMO "python" que usa la bateria: lo que se quiere saber no
es si los paquetes existen en algun sitio, sino si existen AQUI. Y mira, no importa:
find_spec no ejecuta el modulo, asi que esto no carga 1,9 GB de numpy para responder.
"""
import ast
import importlib.util
import io
import os
import sys


def modulos_de(ruta):
    """Devuelve (a_pelo, protegidos): los modulos raiz que el fichero importa, separados
    por si el import cuelga de un try o no. Un import dentro de una funcion cuenta como a
    pelo salvo que esa funcion lo envuelva en un try: si se llama, mata igual."""
    try:
        with io.open(ruta, encoding="utf-8-sig") as f:
            arbol = ast.parse(f.read())
    except Exception:  # noqa: BLE001
        return None
    a_pelo, protegidos = set(), set()

    def anda(nodos, dentro_de_try):
        for n in nodos:
            if isinstance(n, ast.Import):
                for a in n.names:
                    (protegidos if dentro_de_try else a_pelo).add(a.name.split(".")[0])
            elif isinstance(n, ast.ImportFrom):
                if n.level == 0 and n.module:
                    (protegidos if dentro_de_try else a_pelo).add(n.module.split(".")[0])
            elif isinstance(n, ast.Try):
                # solo el cuerpo esta protegido; lo que va en el except, el else o el
                # finally corre igual que fuera
                anda(n.body, True)
                anda(n.handlers, dentro_de_try)
                anda(n.orelse, dentro_de_try)
                anda(n.finalbody, dentro_de_try)
            else:
                anda(list(ast.iter_child_nodes(n)), dentro_de_try)

    anda(arbol.body, False)
    return a_pelo - protegidos, protegidos


def buscar(m):
    """El spec del modulo, o None si aqui no esta."""
    try:
        return importlib.util.find_spec(m)
    except Exception:  # noqa: BLE001
        return None


def main():
    lista = sys.argv[1]
    with io.open(lista, encoding="utf-8-sig") as f:
        rutas = [l.strip() for l in f if l.strip()]
    for ruta in rutas:
        nombre = os.path.basename(ruta)
        piezas = modulos_de(ruta)
        if piezas is None:
            print("%s|?|" % nombre)
            continue
        # LOS HERMANOS DEL REPO NO SON PAQUETES, PERO SI SE SIGUEN: un banco que hace
        # "import charla_worker" lo encuentra porque corre desde su carpeta, no porque este
        # instalado; y lo que de verdad lo mata es que charla_worker importe httpx A PELO.
        # Sin seguir la cadena, probar-charla.py -que murio justo por ahi- saldria limpio.
        # La cadena se sigue SOLO por los imports a pelo: si el padre ya envolvio al hijo en
        # un try, lo que le pase al hijo esta contenido.
        raiz = os.path.dirname(os.path.dirname(os.path.abspath(ruta)))
        viejo = list(sys.path)
        sys.path.insert(0, os.path.dirname(os.path.abspath(ruta)))
        sys.path.insert(0, raiz)
        sin_red, con_red, vistos = [], [], set()
        cola = [piezas]
        while cola:
            a_pelo, protegidos = cola.pop()
            for m in sorted(a_pelo) + sorted(protegidos):
                if m in vistos or m in sys.builtin_module_names or m == "__future__":
                    continue
                vistos.add(m)
                desnudo = m in a_pelo
                spec = buscar(m)
                if spec is None:
                    (sin_red if desnudo else con_red).append(m)
                    continue
                origen = getattr(spec, "origin", "") or ""
                de_casa = (origen.lower().endswith(".py")
                           and os.path.abspath(origen).lower().startswith(raiz.lower() + os.sep))
                if de_casa and desnudo:
                    hijos = modulos_de(origen)
                    if hijos:
                        cola.append(hijos)
        sys.path[:] = viejo
        print("%s|%s|%s" % (nombre, ",".join(sorted(set(sin_red))), ",".join(sorted(set(con_red)))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
