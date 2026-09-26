# -*- coding: utf-8 -*-
"""EL DESCARTE QUE SE ARREPIENTE (26/09, idea 23 de las 121).

EL AGUJERO: cuando el oido tira una llamada -la rafaga sono floja, o los altavoces obligaban a
exigir mas confianza- no vuelve a pensar en ello nunca. Pero si a los pocos segundos se abre
una escucha BUENA -porque braya repitio, o porque se rindio y apreto el boton- ese descarte
estaba MAL, y las dos lineas ya estaban escritas en el registro sin que nadie las cruzara.

MEDIDO sobre los dos registros, 18 dias: 113 descartes por rafaga floja con 15 arrepentidos
(13 %) y 162 por confianza con altavoces con 9 (6 %).

LO QUE ESTE BANCO VIGILA MAS QUE NADA: que esto sea un CUADERNO y no un mando. La idea
original queria que la fraccion de arrepentidos bajara el liston sola, y su propio dato la
tumba: con la ventana y el escalon mas generosos que proponia, se recuperan 7 llamadas y se
cuelan 30 falsas. Si alguien cablea descartes.jsonl dentro de umbral_rafaga o umbral_confianza,
este banco tiene que ponerse rojo.

NO se importa wake_vosk: importarlo ARRANCA EL MICROFONO. Se sacan las funciones del fuente y
se ejecutan en un entorno de mentira, como hace probar-no-sorda.py.

    python tools/probar-arrepentidos.py
"""
from __future__ import print_function
import io
import json
import os
import re
import shutil
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = io.open(os.path.join(RAIZ, 'wake_vosk.py'), encoding='utf-8').read()
# SIN COMENTARIOS para lo que se mira por texto: si no, una nota que nombre la pieza contaria
# como usarla, que es una de las maneras de salir verde mintiendo.
SIN = '\n'.join(l for l in SRC.split('\n') if not l.strip().startswith('#'))

fallos = [0]


def comp(que, ok, det=''):
    print('  %s  %-58s %s' % ('OK ' if ok else 'MAL', que, det))
    if not ok:
        fallos[0] += 1


print('')
print('-- a. las dos constantes, y de donde salen --')
# EL [^0-9] NO ES ADORNO: probar-oido-flojo ya se comio ese error con FLOJO_VENTANA. Sin el,
# un 300.0 casaria contra el patron de 30.0 y el banco pasaria con la ventana diez veces mayor.
m = re.search(r'^DESCARTE_ARREPIENTE_SEG = (30\.0)[^0-9]', SRC, re.M)
comp('la ventana son treinta segundos justos', m is not None,
     'de 67 arrepentidos, 60 caen entre 4 y 30 s; acortarla a 15 perderia un tercio')
m2 = re.search(r'^DESCARTES_RECUERDO = ([0-9]+)', SRC, re.M)
comp('y la cola tiene tope', m2 is not None)
TOPE = int(m2.group(1)) if m2 else 0
comp('  que cubre de sobra la ventana', TOPE >= 20,
     '%d; el dia mas cargado fueron 54 descartes en TODO el dia' % TOPE)

# --- las funciones, sacadas del fuente y ejecutadas ---------------------------------------
QUIERO = ('fila_descarte', 'guardar_descarte', 'encolar_descarte', 'veredicto_descartes')
ns = {'os': os, 'json': json, 'anota': lambda s: None}
mv = re.search(r'^DESCARTE_ARREPIENTE_SEG = ([0-9.]+)', SRC, re.M)
ns['DESCARTE_ARREPIENTE_SEG'] = float(mv.group(1)) if mv else 30.0
ns['DESCARTES_RECUERDO'] = TOPE
ns['descartes_pendientes'] = []
tmp = tempfile.mkdtemp(prefix='arrep-')
ns['USO_DIR'] = tmp
faltan = []
for f in QUIERO:
    mf = re.search(r'(?ms)^def %s\(.*?\n(?=\n*\S|\Z)' % f, SRC)
    if not mf:
        faltan.append(f)
        continue
    exec(compile(mf.group(0), f, 'exec'), ns)
if faltan:
    print('  MAL  no estan a nivel de modulo en wake_vosk.py: %s' % ', '.join(faltan))
    shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(1)

fila_descarte = ns['fila_descarte']
encolar = ns['encolar_descarte']
veredicto = ns['veredicto_descartes']
COLA = ns['descartes_pendientes']


def limpia():
    del COLA[:]
    p = os.path.join(tmp, 'descartes.jsonl')
    if os.path.exists(p):
        os.remove(p)


def leidas():
    p = os.path.join(tmp, 'descartes.jsonl')
    if not os.path.exists(p):
        return []
    return [json.loads(l) for l in io.open(p, encoding='utf-8') if l.strip()]


try:
    print('')
    print('-- b. la fila es PURA: ni disco ni reloj --')
    f = fila_descarte({'t': 100.0, 'motivo': 'rafaga', 'texto': 'nova'}, 'arrepentido', 112.5)
    comp('se queda el motivo y el texto', f.get('motivo') == 'rafaga' and f.get('texto') == 'nova')
    comp('  y el veredicto', f.get('veredicto') == 'arrepentido')
    comp('  con lo que tardo en volver', abs(f.get('espera', 0) - 12.5) < 0.01, '%.1f s' % f.get('espera', 0))
    # EL RELOJ INTERNO NO SE GUARDA: es el tiempo del proceso, no sirve fuera de esta sesion.
    comp('  y el reloj interno NO se guarda', 't' not in f, 'es el cronometro del proceso')

    print('')
    print('-- c. UN descarte, UNA linea --')
    # ESTA ES LA ROTURA QUE MAS DUELE: si no se saca de la cola antes de escribir, dos dictados
    # dentro de la ventana apuntan el mismo descarte dos veces y la cuenta sale inflada.
    limpia()
    encolar({'t': 100.0, 'motivo': 'rafaga', 'texto': 'nova'})
    veredicto(110.0, True, 'nombre')
    veredicto(115.0, True, 'boton')
    comp('dos escuchas seguidas no lo apuntan dos veces', len(leidas()) == 1, '%d lineas' % len(leidas()))
    comp('  y la cola se queda vacia', len(COLA) == 0)

    print('')
    print('-- d. arrepentido, acertado, o todavia no se sabe --')
    limpia()
    encolar({'t': 100.0, 'motivo': 'rafaga', 'texto': 'nova'})
    veredicto(110.0, True, 'nombre')
    r = leidas()
    comp('dentro de la ventana y con escucha buena: arrepentido', r and r[0]['veredicto'] == 'arrepentido')
    comp('  y se apunta por donde volvio', r and r[0].get('volvio_por') == 'nombre', 'nombre o boton, que no es lo mismo')
    limpia()
    encolar({'t': 100.0, 'motivo': 'rafaga', 'texto': 'nova'})
    veredicto(145.0, True, 'nombre')
    r = leidas()
    # LA CONSTANTE TIENE QUE USARSE DE VERDAD, no solo estar escrita: 45 s pasan de la ventana.
    comp('pasada la ventana ya no vale, aunque se abra la escucha', r and r[0]['veredicto'] == 'acertado',
         '45 s > 30 s; si sale "arrepentido", la constante no se esta comparando')
    limpia()
    encolar({'t': 100.0, 'motivo': 'confianza', 'texto': 'nova'})
    veredicto(160.0, False)
    r = leidas()
    comp('y caduca solo como ACERTADO, sin ninguna escucha', r and r[0]['veredicto'] == 'acertado',
         'sin esto solo se apuntarian los arrepentidos y la cuenta saldria del 100 %')
    limpia()
    encolar({'t': 100.0, 'motivo': 'rafaga', 'texto': 'nova'})
    veredicto(110.0, False)
    comp('  pero uno reciente y sin escucha se espera', len(leidas()) == 0 and len(COLA) == 1,
         'todavia puede arrepentirse')

    print('')
    print('-- e. la cola no crece sin fin --')
    limpia()
    for i in range(TOPE * 3):
        encolar({'t': 100.0 + i, 'motivo': 'rafaga', 'texto': 'nova'})
    comp('se queda en el tope', len(COLA) == TOPE, '%d de %d encolados' % (len(COLA), TOPE * 3))
    # Y SE QUEDA CON LOS ULTIMOS, que son los que todavia pueden arrepentirse.
    comp('  y con los mas nuevos', COLA[-1]['t'] == 100.0 + TOPE * 3 - 1, 'los viejos ya no se pueden desmentir')

    print('')
    print('-- f. y lo que no se puede juzgar, no cuesta nada --')
    limpia()
    comp('con la cola vacia no escribe nada', veredicto(200.0, True, 'nombre') == [] and len(leidas()) == 0,
         'regla 4: esto corre en el bucle del oido')
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print('')
print('-- g. ESTO ES UN CUADERNO, NO UN MANDO --')
# LA COMPROBACION QUE IMPIDE EL DESTROZO. La mitad de la idea que ajustaba listones se cayo con
# su propio dato: con la ventana y el escalon mas generosos que proponia, se recuperan 7
# llamadas y se cuelan 30 falsas. Si alguien cablea el cuaderno dentro de un umbral, esto se
# pone rojo antes de que Nova empiece a abrir cosas que nadie pidio.
for fn in ('umbral_rafaga', 'umbral_confianza', 'umbral_actividad', 'umbral_altavoz'):
    mf = re.search(r'(?ms)^def %s\(.*?\n(?=\n*\S|\Z)' % fn, SIN)
    cuerpo = mf.group(0) if mf else ''
    comp('%s no mira los descartes' % fn,
         'descartes_pendientes' not in cuerpo and 'descartes.jsonl' not in cuerpo and
         'veredicto_descartes' not in cuerpo, 'recuperaria 7 y colaria 30')
comp('y descartes.jsonl solo se abre en un sitio',
     len(re.findall(r'open\(os\.path\.join\(USO_DIR, "descartes\.jsonl"\)', SIN)) == 1,
     'nadie mas lo escribe ni lo lee')

print('')
print('-- h. los cuatro enganches del bucle --')
# DOS QUE ENCOLAN y DOS QUE JUZGAN. Si falta uno de los que juzgan, o la cuenta sale del 100 %
# de arrepentidos o no sale ninguna.
comp('encola en dos sitios', len(re.findall(r'encolar_descarte\(dict\(', SIN)) == 2, 'rafaga y confianza')
comp('  uno por rafaga floja', re.search(r'motivo="rafaga"', SIN) is not None)
comp('  y otro por confianza', re.search(r'motivo="confianza"', SIN) is not None)
i_dic = SIN.find('veredicto_descartes(ahora, True')
i_pul = SIN.find('veredicto_descartes(ahora, False)')
comp('juzga al abrirse una escucha buena', i_dic >= 0)
comp('  y tambien en el pulso, sin escucha', i_pul >= 0, 'si no, los acertados no se apuntan nunca')
# Y EL ORIGEN VIAJA: si braya repitio el nombre o si se rindio y uso el boton no es lo mismo.
comp('  diciendo por donde volvio', re.search(r'veredicto_descartes\(ahora, True, "nombre" if origen_nombre else "boton"\)', SIN) is not None,
     'rendirse y usar el boton es peor que repetir')
# LA LINEA DEL LOG NO SE TOCA: cuatro bancos la vigilan por texto.
comp('y las dos lineas del log siguen como estaban',
     'descartado \'%s\': suena demasiado flojo para ser una llamada' in SIN and
     'descartado \'%s\': confianza %.2f < %.2f%s' in SIN, 'cuatro bancos las vigilan por texto')

print('')
print('-- i. contra el registro de verdad --')
n = 0
for f in ('assistant.log', 'assistant.log.1'):
    p = os.path.join(RAIZ, f)
    if not os.path.exists(p):
        continue
    for l in io.open(p, encoding='utf-8', errors='ignore'):
        if '[escucha] descartado' in l:
            n += 1
print('       %d descartes en los dos registros' % n)
comp('el problema existe y se puede medir', n >= 100, 'medidos 24 arrepentidos de 275')

print('')
if fallos[0]:
    print('  %d caso(s) MAL' % fallos[0])
    sys.exit(1)
print('  el oido se pone la nota a sus propios descartes')
sys.exit(0)
