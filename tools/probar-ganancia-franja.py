# -*- coding: utf-8 -*-
# LA GANANCIA DEL MICRO, UNA POR FRANJA DEL DIA (1/10, idea 7 de las 20 nuevas)
#
# MEDIDO sobre 18.277 muestras de 'ganancia=xN.N' de los dos registros, 22 dias:
#
#     franja              muestras   mediana     p90
#     madrugada 00-07        5.262      8,00   20,80
#     maniana   08-13        3.055      8,00   19,80
#     tarde     14-19        5.731      4,10   15,60     <- el valle
#     noche     20-23        4.229      9,10   28,20     <- el pico
#
# 122 % de diferencia entre la tarde y la noche, y por horas sueltas SIETE VECES (18:00 y 19:00
# median 2,10; las 23:00 median 15,50). Y el ruido lo explica: de 08:00 a 17:00 entre el 9 % y el
# 21 % de las lineas del registro son "esto no es voz, es ruido de fondo"; a las 23:00 es el 0,1 %.
#
# LO QUE DEFIENDE:
#  1. que el formato VIEJO del fichero siga leyendose: un fichero de ayer no puede dejar sorda a
#     Nova hoy, y el primer arranque tras este cambio tiene uno de esos;
#  2. que la ganancia de OTRO MICRO no se herede, ni la global ni las franjas;
#  3. que una franja escrita mal no tire las demas;
#  4. que las cuatro franjas cubran las 24 horas sin huecos ni solapes;
#  5. y que el cambio de franja respete las DOS guardas que ya existen (CABE_MAX y el techo
#     aprendido), porque sin ellas poner la x15,5 de la noche con la tele puesta devuelve el
#     pin-pon de recortes que costo el 22/09.
import re
import io
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(RAIZ, 'wake_vosk.py')
mal = []


def comp(que, ok, detalle=''):
    print('  %s  %-56s %s' % ('ok ' if ok else 'MAL', que, detalle))
    if not ok:
        mal.append(que)


fuente = io.open(RUTA, encoding='utf-8').read()

# SE EJECUTAN LAS FUNCIONES DE VERDAD, sacadas del fichero: leer su forma no diria si el formato
# viejo se sigue entendiendo, que es lo que importa.
GANANCIA_MIN, GANANCIA_MAX = 0.3, 40.0
import time


def saca(nombre):
    m = re.search(r'^def %s\(.*?(?=^\S|\Z)' % re.escape(nombre), fuente, re.S | re.M)
    if not m:
        comp('se encuentra ' + nombre, False)
        return ''
    return m.group(0)


ctx = {'GANANCIA_MIN': GANANCIA_MIN, 'GANANCIA_MAX': GANANCIA_MAX, 'time': time, 're': re}
mFr = re.search(r'^FRANJAS_GANANCIA = .*$', fuente, re.M)
if not mFr:
    comp('se encuentra FRANJAS_GANANCIA', False)
    print('')
    print('%d MAL' % len(mal))
    sys.exit(1)
exec(mFr.group(0), ctx)
for n in ('franja_de_ahora', 'ganancia_guardada', 'guardar_ganancia'):
    c = saca(n)
    if c:
        exec(c, ctx)

print('')
print('-- 1. las cuatro franjas cubren las 24 horas, sin huecos ni solapes --')
cubierto = {}
for h in range(24):
    cubierto[h] = ctx['franja_de_ahora'](h)
comp('las 24 horas tienen franja', all(cubierto[h] for h in range(24)),
     '%d horas' % len(set(cubierto.values())) + ' franjas distintas')
nombres = [f[0] for f in ctx['FRANJAS_GANANCIA']]
comp('  y son las cuatro medidas', sorted(set(cubierto.values())) == sorted(nombres),
     ', '.join(sorted(set(cubierto.values()))))
# LAS HORAS QUE LA MEDICION SEPARA tienen que caer en franjas DISTINTAS, o la idea no sirve de nada:
# 18:00-19:00 median 2,10 y 23:00 median 15,50.
comp('  y las 19:00 (mediana 2,10) no caen con las 23:00 (15,50)',
     cubierto[19] != cubierto[23], '%s contra %s' % (cubierto[19], cubierto[23]))
# y los bordes, que es donde se equivoca uno al escribir rangos
comp('  el borde de las 8 entra en la maniana', cubierto[8] == 'maniana', cubierto[8])
comp('  el de las 14 en la tarde', cubierto[14] == 'tarde', cubierto[14])
comp('  el de las 20 en la noche', cubierto[20] == 'noche', cubierto[20])
comp('  y la medianoche en la madrugada', cubierto[0] == 'madrugada', cubierto[0])

print('')
print('-- 2. EL FORMATO VIEJO SE SIGUE LEYENDO --')
# Un fichero de ayer no puede dejar sorda a Nova hoy, y el primer arranque tras este cambio tiene
# uno de esos. Esto es lo que hace que el cambio no pueda empeorar nada el primer dia.
import tempfile
import shutil
tmp = tempfile.mkdtemp(prefix='nova-gan-')
try:
    ruta = os.path.join(tmp, 'ganancia.txt')
    ctx['RUTA_GANANCIA'] = ruta
    MICRO = 'Microphone Array (Realtek(R) Au'

    def escribe(txt):
        io.open(ruta, 'w', encoding='utf-8').write(txt)

    ctx['escribir'] = lambda r, c: io.open(r, 'w', encoding='utf-8').write(c)

    escribe('6.4|%s' % MICRO)
    g, quien, fr = ctx['ganancia_guardada'](MICRO)
    comp('el fichero de ayer (sin franjas) se lee', g == 6.4 and quien == MICRO, 'x%s' % g)
    comp('  y devuelve las franjas vacias, no un error', fr == {}, str(fr))

    escribe('6.4')
    g2, quien2, fr2 = ctx['ganancia_guardada'](MICRO)
    comp('el formato de antes del 16/09 (solo el numero) no se hereda', g2 is None, str(g2))

    print('')
    print('-- 3. el formato nuevo, ida y vuelta --')
    ctx['guardar_ganancia'](9.1, MICRO, {'noche': 15.5, 'tarde': 4.1})
    g3, quien3, fr3 = ctx['ganancia_guardada'](MICRO)
    comp('se lee lo que se escribio', g3 == 9.1 and quien3 == MICRO, 'x%s' % g3)
    comp('  con sus dos franjas', fr3 == {'noche': 15.5, 'tarde': 4.1}, str(fr3))
    comp('  y en una sola linea', len(io.open(ruta, encoding='utf-8').read().strip().split('\n')) == 1,
         repr(io.open(ruta, encoding='utf-8').read().strip())[:70])

    print('')
    print('-- 4. LO DE OTRO MICRO NO SE HEREDA, ni la global ni las franjas --')
    # Heredar la calibracion de otro micro es peor que no recordar nada: con el array de Realtek
    # estaba en x18,3 y ese numero en un micro USB satura.
    g4, quien4, fr4 = ctx['ganancia_guardada']('Micro USB de otra persona')
    comp('la ganancia de otro micro no se hereda', g4 is None, str(g4))
    comp('  Y TAMPOCO SUS FRANJAS', fr4 == {}, str(fr4))
    comp('  pero dice de quien era, para poder avisarlo', quien4 == MICRO, quien4)

    print('')
    print('-- 5. una franja escrita mal no tira las demas --')
    escribe('9.1|%s|noche:15.5,tarde:XXX,inventada:3.0,madrugada:8.0' % MICRO)
    g5, _, fr5 = ctx['ganancia_guardada'](MICRO)
    comp('se queda con las dos buenas', fr5 == {'noche': 15.5, 'madrugada': 8.0}, str(fr5))
    comp('  y la global sigue valiendo', g5 == 9.1, 'x%s' % g5)
    # Y UNA FUERA DE RANGO TAMPOCO: x200 saturaria cualquier cosa
    escribe('9.1|%s|noche:200.0,tarde:4.1' % MICRO)
    _, _, fr6 = ctx['ganancia_guardada'](MICRO)
    comp('una ganancia imposible se descarta', fr6 == {'tarde': 4.1}, str(fr6))
    # Y UN FICHERO BASURA no revienta nada
    escribe('esto no es un numero')
    g7, _, fr7 = ctx['ganancia_guardada'](MICRO)
    comp('un fichero roto no revienta', g7 is None and fr7 == {}, '%s %s' % (g7, fr7))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print('')
print('-- 6. el cableado, y las dos guardas que no se pueden perder --')
sinCom = '\n'.join(l for l in fuente.split('\n') if not l.strip().startswith('#'))
comp('al arrancar se mira la franja', 'ganancia_franjas.get(franja_actual)' in sinCom)
comp('  y se guarda en su franja al calibrar', 'ganancia_franjas[franja_actual] = ganancia' in sinCom)
comp('  y el cambio de franja se vigila en el pulso', "_franjaAhora = franja_de_ahora()" in sinCom)
# LAS DOS GUARDAS: sin ellas, poner la x15,5 de la noche con la tele puesta devuelve el pin-pon de
# recortes del 22/09. Se miran DENTRO del bloque del cambio de franja, no en todo el fichero.
i = sinCom.find('_franjaAhora = franja_de_ahora()')
bloque = sinCom[i:i + 1400] if i >= 0 else ''
comp('  el cambio respeta CABE_MAX', 'CABE_MAX' in bloque, 'si el fondo amplificado no cabe, no se cambia')
comp('  y el techo aprendido', 'techo_cabe(_gF' in bloque, 'si esa ganancia acaba de saturar, no se vuelve')
comp('  y lo dice en el registro', 'franja' in bloque and 'anota(' in bloque)
# LAS VARIABLES, DEFINIDAS SIEMPRE: una que solo existe en una rama es un NameError esperando, que
# es el mismo tropiezo que el 'callado' del 26/09.
iDef = sinCom.find('ganancia_franjas = {}')
iIf = sinCom.find('if automatica:\n    _g, _de_quien, _porFranja')
comp('las variables se definen FUERA del "if automatica"', iDef >= 0 and iIf >= 0 and iDef < iIf,
     'definidas en %d, el if en %d' % (iDef, iIf))

print('')
if mal:
    print('%d MAL' % len(mal))
    sys.exit(1)
print('la ganancia del micro se aprende por franja del dia')
sys.exit(0)
