# -*- coding: utf-8 -*-
"""EL PERFIL QUE VIAJA ES EL QUE VIENE A CUENTO (25/09).

EL CASO, de braya esta misma noche: le pregunto a Nova como se llama su mascota a las 01:17:58
y ella contesto "No me has dicho nunca como se llama tu mascota, asi que no lo se". El dato
ESTABA en su perfil -la linea 27 de 60- y llevaba dias ahi. No lo vio porque al modelo de la
charla solo le llegaban los QUINCE ULTIMOS datos del perfil, y el 27 de 60 no esta entre los
quince ultimos.

O sea que Nova sabia la respuesta y dijo que no la sabia. 45 de los 60 datos eran invisibles
para la charla, que es la mitad de su "no sabe ni hacer la mitad de las cosas que le digo".

La funcion se saca del arbol de charla_worker.py y se ejecuta: un banco que mirase el texto
pasaria con una funcion que devolviera siempre los quince ultimos, que es justo lo que fallaba.
"""
import ast
import io
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = os.path.join(RAIZ, 'charla_worker.py')

src = io.open(PY, encoding='utf-8').read()
arbol = ast.parse(src)

QUIERO = ('perfil_para', '_palabras')
CONST = ('PERFIL_AL_MODELO', 'PERFIL_VACIAS')
trozos = []
for n in arbol.body:
    if isinstance(n, ast.FunctionDef) and n.name in QUIERO:
        trozos.append(ast.get_source_segment(src, n))
    elif isinstance(n, ast.Assign):
        for d in n.targets:
            if getattr(d, 'id', '') in CONST:
                trozos.append(ast.get_source_segment(src, n))

mal = [0]


def comp(que, cond, det=''):
    print('  %-4s %s%s' % ('ok' if cond else 'MAL', que, ('  (%s)' % det) if det else ''))
    if not cond:
        mal[0] += 1


comp('se saca perfil_para del arbol', any('def perfil_para' in x for x in trozos))
comp('y la lista de palabras vacias', any('PERFIL_VACIAS' in x for x in trozos),
     'sin ella, "como se llama mi mascota" se parece a todo')
if mal[0]:
    print('')
    print('  %d MAL' % mal[0])
    sys.exit(1)

ns = {}
exec(chr(10).join(trozos), ns)
perfil_para = ns['perfil_para']
TOPE = ns.get('PERFIL_AL_MODELO', 15)

# EL PERFIL DE BRAYA TAL Y COMO ESTABA: el dato de la mascota en la posicion 27 de 60
perfil = (['dato %d de relleno' % i for i in range(1, 27)] +
          ['tiene un gato o mascota llamada Meramiau'] +
          ['relleno %d distinto' % i for i in range(28, 61)])
comp('el perfil de prueba tiene 60 datos', len(perfil) == 60, '%d' % len(perfil))

r = perfil_para('Como se llama mi mascota', perfil)
comp('viajan como mucho %d datos' % TOPE, len(r) <= TOPE, '%d' % len(r))
comp('Y VA EL DE LA MASCOTA', any('Meramiau' in x for x in r), 'con dp[-15:] no iba: ese era el fallo')
comp('  (y con el metodo viejo NO iba)', not any('Meramiau' in x for x in perfil[-TOPE:]),
     'asi se sabe que la prueba prueba algo')

# SIN PREGUNTA UTIL: se comporta como antes, con los ultimos
r2 = perfil_para('eh', perfil)
comp('sin palabras utiles, los ultimos como siempre', r2 == perfil[-TOPE:], '%d datos' % len(r2))

# UN PERFIL CORTO VIAJA ENTERO
corto = ['uno', 'dos', 'tres']
comp('un perfil corto viaja entero', perfil_para('lo que sea', corto) == corto)

# LAS PALABRAS VACIAS NO CUENTAN: "que", "como", "mi" estan en casi todas las frases
solo_vacias = perfil_para('que es lo que', perfil)
comp('las palabras vacias no eligen nada', solo_vacias == perfil[-TOPE:], 'si contaran, elegirian al azar')

# VARIOS QUE TOCAN: gana el que mas palabras comparte
p2 = ['le gusta el cafe', 'juega a Hollow Knight por las noches', 'tiene un perro',
      'Hollow Knight es su juego favorito'] + ['relleno %d' % i for i in range(30)]
r3 = perfil_para('cual es mi juego favorito de Hollow Knight', p2)
comp('gana el que mas palabras comparte', 'Hollow Knight es su juego favorito' in r3)
comp('  y el otro que toca tambien entra', 'juega a Hollow Knight por las noches' in r3)

# EL ORDEN DEL PERFIL SE RESPETA: el modelo lee mejor algo coherente
r4 = perfil_para('Hollow Knight', p2)
comp('y salen en el orden del perfil', r4 == [x for x in p2 if x in r4], 'no en orden de parecido')

# NO SE REPITEN
comp('no se repite ninguno', len(r) == len(set(r)))

print('')
if mal[0]:
    print('  %d MAL' % mal[0])
    sys.exit(1)
print('  el perfil que viaja es el que viene a cuento')
sys.exit(0)
