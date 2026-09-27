# -*- coding: utf-8 -*-
r"""LEER EL FICHERO DE LO IMPORTANTE (27/09, idea 79 de las 121)

EL AGUJERO: desde el 25/09 el worker copia a memoria\cerebro\importante.jsonl cada turno en que
braya corrige y cada turno en que Nova admite que no sabe algo. Se escribia en modo 'a' y NO LO LEIA
NADIE: 518 bytes y cero lectores en todo el repositorio fuera de dos bancos. Es el inventario de sus
agujeros y estaba muerto en el disco.

MATERIAL QUE HABRIA, contado con las propias regex del fichero sobre los dos registros: en 17 dias,
72 lineas (61 correcciones y 11 agujeros). Y LO QUE DE VERDAD IMPORTA: de 8 agujeros, TRES no eran
agujeros -dos '¿que hora es?' y uno del clima-, o sea que Nova dijo que no sabia algo que si sabe.

LO QUE PRUEBA ESTE BANCO (la mitad de Python): que se leen SOLO los agujeros, que se agrupan los que
son lo mismo preguntado de otra forma, que no se toca el fichero, y que una linea rota no lo tumba.
La otra mitad -la prueba en seco de si el agujero es falso- la prueba probar-agujeros-seco.ps1,
porque el resolvedor de ordenes vive en el asistente.
"""
import io
import json
import os
import shutil
import sys
import tempfile
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, RAIZ)
import charla_memoria as cm  # noqa: E402

mal = 0


def comp(que, ok, detalle=''):
    global mal
    if ok:
        print('  ok   %s%s' % (que, ('  (' + detalle + ')') if detalle else ''))
    else:
        print('  MAL  %s%s' % (que, ('  (' + detalle + ')') if detalle else ''))
        mal += 1


carpeta = tempfile.mkdtemp(prefix='nova-agu-')
try:
    c = cm.Cerebro(carpeta, None)
    ruta = os.path.join(carpeta, 'importante.jsonl')
    hoy = time.strftime('%Y-%m-%d')
    ayer = time.strftime('%Y-%m-%d', time.localtime(time.time() - 86400))
    viejo = time.strftime('%Y-%m-%d', time.localtime(time.time() - 40 * 86400))

    print('-- 1. SIN FICHERO NO PASA NADA --')
    r = c.agujeros(7)
    comp('1a. sin fichero, cero agujeros y sin reventar', r['total'] == 0 and r['grupos'] == [])

    print('')
    print('-- 2. SOLO LOS AGUJEROS, NO LAS CORRECCIONES --')
    with io.open(ruta, 'w', encoding='utf-8') as f:
        f.write(json.dumps({'d': hoy, 'h': '10:00', 'por': 'correccion',
                            'braya': 'no dije eso', 'nova': 'perdona'}, ensure_ascii=False) + '\n')
        f.write(json.dumps({'d': hoy, 'h': '11:00', 'por': 'agujero',
                            'braya': 'que hora es', 'nova': 'no tengo acceso a la hora de tu consola'}, ensure_ascii=False) + '\n')
        f.write(json.dumps({'d': ayer, 'h': '12:00', 'por': 'agujero',
                            'braya': 'y la hora que es ahora', 'nova': 'no tengo acceso a la hora'}, ensure_ascii=False) + '\n')
        f.write(json.dumps({'d': hoy, 'h': '13:00', 'por': 'agujero',
                            'braya': 'como se llama mi mascota', 'nova': 'no me has dicho nunca como se llama'}, ensure_ascii=False) + '\n')
    r2 = c.agujeros(7)
    comp('2a. las correcciones no cuentan como agujeros', r2['total'] == 3, '%d de 4 lineas' % r2['total'])
    comp('2b. y los que son lo mismo se juntan', len(r2['grupos']) == 2,
         '%d grupos: %s' % (len(r2['grupos']), ' | '.join('x%d %s' % (g['veces'], g['frase'][:28]) for g in r2['grupos'])))
    hora = [g for g in r2['grupos'] if 'hora' in g['frase']]
    comp('2c. la hora sale dos veces', hora and hora[0]['veces'] == 2, str(hora[0]['veces']) if hora else 'no esta')
    comp('2d. con sus dos dias', hora and len(hora[0]['dias']) == 2, ', '.join(hora[0]['dias']) if hora else '')
    comp('2e. el mas repetido va primero', r2['grupos'][0]['veces'] >= r2['grupos'][-1]['veces'], '')

    print('')
    print('-- 3. LO VIEJO NO CUENTA --')
    with io.open(ruta, 'a', encoding='utf-8') as f:
        f.write(json.dumps({'d': viejo, 'h': '09:00', 'por': 'agujero',
                            'braya': 'algo de hace cuarenta dias', 'nova': 'no lo se'}, ensure_ascii=False) + '\n')
    r3 = c.agujeros(7)
    comp('3a. con ventana de 7 dias, lo de hace 40 queda fuera', r3['total'] == 3, '%d' % r3['total'])
    r3b = c.agujeros(60)
    comp('3b. y con ventana de 60 entra', r3b['total'] == 4, '%d' % r3b['total'])

    print('')
    print('-- 4. UNA LINEA ROTA NO TUMBA LA CUENTA --')
    with io.open(ruta, 'a', encoding='utf-8') as f:
        f.write('esto no es json\n')
        f.write('\n')
        f.write(json.dumps({'d': hoy, 'h': '14:00', 'por': 'agujero', 'braya': '', 'nova': 'no se'}, ensure_ascii=False) + '\n')
    r4 = c.agujeros(7)
    comp('4a. se salta lo roto y sigue contando', r4['total'] == 4, '%d (la linea vacia cuenta como agujero pero no agrupa)' % r4['total'])
    comp('4b. y el agujero sin pregunta no hace grupo', len(r4['grupos']) == 2,
         '%d grupos' % len(r4['grupos']))

    print('')
    print('-- 5. SOLO LECTURA: EL FICHERO NO SE TOCA --')
    antes = io.open(ruta, encoding='utf-8').read()
    tam = os.path.getsize(ruta)
    _ = c.agujeros(7)
    comp('5a. el fichero queda igual', io.open(ruta, encoding='utf-8').read() == antes, '%d bytes' % tam)
    comp('5b. y no se poda ni se reescribe', os.path.getsize(ruta) == tam, '')

    print('')
    print('-- 6. LOS GRUPOS SE PUEDEN GUARDAR EN JSON --')
    # el worker los escribe a agujeros.json para el asistente: si llevaran un set dentro, reventaria
    try:
        json.dumps(c.agujeros(7))
        ok6 = True
    except Exception as e:
        ok6 = False
        print('       %s' % e)
    comp('6a. json.dumps del resultado no revienta', ok6, 'fichas() devuelve un set y no puede viajar')
finally:
    shutil.rmtree(carpeta, ignore_errors=True)

print('')
if mal:
    print('  %d MAL' % mal)
    sys.exit(1)
print('  el inventario de agujeros por fin se lee')
sys.exit(0)
