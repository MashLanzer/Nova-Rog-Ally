# -*- coding: utf-8 -*-
"""LA DECISION DEL ADELANTO, SACADA DEL OIDO Y EJECUTADA.

No se reconstruye aqui: se saca del arbol de wake_vosk.py y se ejecuta de verdad. Un banco que
solo mirase el texto pasaria con una funcion que devolviera siempre True, y eso entregaria una
transcripcion a medias cada vez que braya hiciera una pausa larga en mitad de una frase.
"""
import ast
import io
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = os.path.join(RAIZ, 'wake_vosk.py')

src = io.open(PY, encoding='utf-8').read()
arbol = ast.parse(src)

trozos = []
for n in arbol.body:
    if isinstance(n, ast.FunctionDef) and n.name == 'vale_el_adelanto':
        trozos.append(ast.get_source_segment(src, n))
    elif isinstance(n, ast.Assign):
        for d in n.targets:
            if getattr(d, 'id', '') in ('ADELANTO_MARGEN_SEG', 'TASA'):
                trozos.append(ast.get_source_segment(src, n))

if not any('def vale_el_adelanto' in x for x in trozos):
    print('  MAL  no existe vale_el_adelanto en wake_vosk.py')
    sys.exit(1)

ns = {}
exec(chr(10).join(trozos), ns)
vale = ns['vale_el_adelanto']
TASA = ns.get('TASA', 16000)
MARGEN = ns.get('ADELANTO_MARGEN_SEG', 2.0)

mal = [0]


def comp(que, cond, det=''):
    print('  %-4s %s%s' % ('ok' if cond else 'MAL', que, ('  (%s)' % det) if det else ''))
    if not cond:
        mal[0] += 1


comp('se saca la constante del margen del archivo', 'ADELANTO_MARGEN_SEG' in ns, '%.1f s' % MARGEN)
comp('sin adelanto hecho, no vale', vale(0, TASA * 5, TASA) is False)
# Y SIN AUDIO FINAL TAMPOCO (25/09, lo cazo una rotura). Con n_final = 0 la resta sale
# POSITIVA -el adelanto tiene muestras y el final ninguna- y sin esta guarda un audio vacio
# se llevaria por delante el texto del adelanto. La guarda de "no puede encoger" no cubre este
# caso: aqui no encoge, es que no hay nada.
comp('sin audio final tampoco vale', vale(TASA * 1, 0, TASA) is False, 'no encoge: es que no hay nada')
# Y NADA CONTRA NADA, QUE ES DONDE LA GUARDA IMPORTA DE VERDAD (25/09, lo cazo una rotura):
# con los dos a cero la resta da CERO, que cabe de sobra en el margen, asi que sin la guarda
# "vale" diria que si a un adelanto que no existe sobre un audio que no existe.
comp('nada contra nada no vale', vale(0, 0, TASA) is False, 'la resta da 0 y 0 cabe en el margen')
comp('si solo se anadio silencio, SI vale', vale(TASA * 5, int(TASA * 5.8), TASA) is True,
     '0,8 s mas: eso es el silencio de cierre')
comp('si braya siguio hablando, NO vale', vale(TASA * 5, TASA * 9, TASA) is False,
     '4 s mas de audio no son silencio')
comp('justo en el margen, vale', vale(TASA * 5, int(TASA * (5 + MARGEN)), TASA) is True)
comp('pasado el margen, no', vale(TASA * 5, int(TASA * (5 + MARGEN + 0.5)), TASA) is False)
# QUE NO PUEDA ENCOGER: si el audio final es menor que el adelantado, algo va mal y lo barato
# es rehacerlo, no entregar un texto de un audio que ya no existe.
comp('si el audio final es MENOR, no vale', vale(TASA * 5, TASA * 4, TASA) is False)
comp('el margen es un numero razonable', 0.5 <= MARGEN <= 4.0, '%.1f s' % MARGEN)
# EL CASO DE BRAYA, con sus numeros: habla 5,5 s de mediana y el silencio de cierre son 1,5 s
comp('el caso real: 5,5 s hablando + 1,5 s de silencio', vale(int(TASA * 5.5), int(TASA * 7.0), TASA) is True,
     'aqui es donde se ganan los 2,2 s')

print('')
if mal[0]:
    print('  %d MAL' % mal[0])
    sys.exit(1)
print('  la decision del adelanto hace lo que dice')
sys.exit(0)
