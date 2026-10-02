# CUANTO VALE LA CRIBA, MEDIDO CONTRA UN CASO REAL CON RESPUESTA CONOCIDA (1/10/2026)
#
# Una criba de ideas no se puede "revisar a ojo": o separa las muertas de las vivas o no sirve, y
# eso es un numero. Aqui esta el unico caso del proyecto con la respuesta ya sabida: las 20 ideas
# del 1/10, de las que NUEVE resultaron estar hechas o apoyadas en un dato falso y ONCE se
# implementaron de verdad.
#
# Y SE MIRA EL REPO COMO ESTABA EL 30/09, que es lo unico honesto: once de esas ideas se
# convirtieron en codigo el 1/10, asi que cribarlas contra el repo de hoy encuentra MIS PROPIOS
# arreglos y lo marca todo. La primera version marcaba 19 de 20 justo por eso, y por emparejar
# cualquier numero con cualquier comentario.
#
# LO QUE SE MIDE, y en este orden de importancia:
#   1. de las NUEVE muertas, cuantas marca            -> lo que la criba existe para hacer
#   2. de las ONCE buenas, cuantas marca por error    -> el precio; si marca todas, no sirve
#   3. lo mismo contando solo las marcas FUERTE       -> que es lo que mata una idea sin leerla
#
# Un detector que dice "si" a todo tiene el punto 1 perfecto y es inutil. Por eso los dos numeros
# van siempre juntos, y por eso este fichero no se puede "arreglar" subiendo la sensibilidad.
import os
import sys

# El fichero se llama con guion (la costumbre de tools\), asi que no se puede importar por su
# nombre: se carga por ruta. Es eso o renombrarlo y romper la costumbre de las otras 378.
_AQUI = os.path.dirname(os.path.abspath(__file__))
_RUTA = os.path.join(_AQUI, 'criba-ideas.py')
try:
    import importlib.util as _iu
    _spec = _iu.spec_from_file_location('criba_ideas', _RUTA)
    C = _iu.module_from_spec(_spec)
    _spec.loader.exec_module(C)
except ImportError:
    import imp
    C = imp.load_source('criba_ideas', _RUTA)

DOC = 'IDEAS-20-2026-10-01.md'
HASTA = '2026-09-30'

# La verdad, de la seccion "QUE PASO AL IMPLEMENTARLAS" de ese mismo documento.
MUERTAS = [5, 6, 12, 13, 14, 15, 16, 17, 19]
BUENAS = [1, 2, 3, 4, 7, 8, 9, 10, 11, 18, 20]


def main():
    C.HASTA = HASTA
    C.REV = C.git(['rev-list', '-1', '--until=%sT23:59:59' % HASTA, 'main']).strip()
    if not C.REV:
        print('no encuentro la version del ' + HASTA)
        return 2
    C.cargar()
    texto = C.leer(DOC)
    if not texto:
        print('no puedo leer ' + DOC)
        return 2
    ideas = C.ideas_de(texto)
    if len(ideas) != 20:
        print('esperaba 20 ideas en %s y hay %d' % (DOC, len(ideas)))
        return 1

    marca, fuerte, detalle = set(), set(), {}
    for n, t, c in ideas:
        av = C.criba(t, c)
        # INFO no cuenta como marca: son deberes de lectura, no una sospecha.
        if any(x[0] != u'INFO' for x in av):
            marca.add(n)
        if any(x[0] == u'FUERTE' for x in av):
            fuerte.add(n)
        detalle[n] = av

    print('')
    print('MEDIDA DE LA CRIBA sobre %s (repo del %s, %s)' % (DOC, HASTA, C.REV[:9]))
    print('frases que Nova puede decir, catalogadas: %d' % len(C.FRASES_NOVA))
    print('')
    cazadas = [n for n in MUERTAS if n in marca]
    falsas = [n for n in BUENAS if n in marca]
    cazadasF = [n for n in MUERTAS if n in fuerte]
    falsasF = [n for n in BUENAS if n in fuerte]
    print('  MUERTAS marcadas : %d de %d   %s' % (len(cazadas), len(MUERTAS), cazadas))
    print('  BUENAS marcadas  : %d de %d   %s  <- el precio' % (len(falsas), len(BUENAS), falsas))
    print('')
    print('  solo FUERTE, muertas: %d de %d   %s' % (len(cazadasF), len(MUERTAS), cazadasF))
    print('  solo FUERTE, buenas : %d de %d   %s  <- estas moririan sin leerlas'
          % (len(falsasF), len(BUENAS), falsasF))
    # QUE VALE CADA FILTRO, uno por uno. Es la misma regla que el metodo aplica a los angulos de
    # busqueda: el que produce ocho y salva una esta agotado. Un filtro que marca tantas buenas
    # como muertas no distingue nada y hay que quitarlo o afinarlo, no dejarlo "por si acaso".
    print('  filtro                   muertas  buenas   (de %d y %d)' % (len(MUERTAS), len(BUENAS)))
    porFiltro = {}
    for n, av in detalle.items():
        for niv, f, _, _ in av:
            porFiltro.setdefault(f, [set(), set()])
            porFiltro[f][0 if n in MUERTAS else 1].add(n)
    for f in sorted(porFiltro):
        m, b = porFiltro[f]
        juicio = 'sirve' if len(m) > len(b) else ('empata' if len(m) == len(b) else 'RUIDO')
        print('  %-24s %4d     %4d    %s' % (f, len(m), len(b), juicio))
    print('')
    for n in MUERTAS:
        if n not in marca:
            tit = [t for x, t, _ in ideas if x == n]
            print('  SE ESCAPA la %d (%s)' % (n, (tit[0] if tit else '')[:60]))
    for n in BUENAS:
        if n in fuerte:
            print('  FUERTE FALSO en la %d:' % n)
            for niv, f, q, p in detalle[n]:
                if niv == u'FUERTE':
                    print('      %s  %s' % (f, q))
                    print('      %s' % p)
    print('')

    # EL VEREDICTO, con los dos numeros a la vez. Los listones salen de para que sirve la criba:
    # avisar de casi todas las muertas, y no condenar a FUERTE a ninguna buena.
    mal = 0
    if len(cazadas) < 8:
        print('MAL: deja escapar %d muertas de %d' % (len(MUERTAS) - len(cazadas), len(MUERTAS)))
        mal += 1
    # EL RUIDO ACEPTABLE, Y POR QUE ESTE NUMERO: siete de once buenas llevan alguna marca "MIRA",
    # y eso NO se arregla apretando el filtro que trabaja. Medido con el umbral de F7 en 3, 4 y 5
    # palabras raras compartidas: con 3 caza 9 muertas de 9 y marca 7 buenas; con 4 baja a 4
    # muertas de 9 y 3 buenas. O sea que apretar cuesta cinco muertas para ahorrar cuatro
    # lecturas, y las lecturas son baratas -la marca trae el fichero y la linea-. El liston se
    # pone donde deja de distinguir: si marcara DIEZ de once, estaria diciendo si a todo.
    if len(falsas) > 9:
        print('MAL: marca %d buenas de %d; eso ya es decir si a todo'
              % (len(falsas), len(BUENAS)))
        mal += 1
    if len(falsasF) > 0:
        print('MAL: %s son buenas y salen como FUERTE' % falsasF)
        mal += 1
    if len(cazadasF) < 2:
        print('MAL: solo %d muertas llegan a FUERTE' % len(cazadasF))
        mal += 1
    if mal:
        print('')
        print('%d listones sin pasar' % mal)
        return 1
    print('La criba separa: avisa de %d/%d muertas y no condena ninguna buena.'
          % (len(cazadas), len(MUERTAS)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
