# -*- coding: utf-8 -*-
"""EL TECHO DE GANANCIA APRENDIDO, SACADO DEL OIDO Y EJECUTADO.

No se reconstruye aqui: se saca del arbol de wake_vosk.py y se ejecuta de verdad. Un banco que
solo mirase el texto pasaria con un techo_frenar que devolviera siempre lo que le dan, y eso
es exactamente el fallo que se esta arreglando: 329 recortes de 985 llegaron con la ganancia ya
por encima de la que acababa de saturar.

LO QUE MAS SE VIGILA AQUI es que el techo NO frene una bajada. Si lo hiciera, impediria salir
de un recorte -justo lo contrario de para lo que esta- y dejaria el microfono saturado sin que
ningun log lo dijera.
"""
import ast
import io
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PY = os.path.join(RAIZ, 'wake_vosk.py')

src = io.open(PY, encoding='utf-8').read()
arbol = ast.parse(src)

QUIERO_FUN = ('techo_apuntar', 'techo_vigente', 'techo_cabe', 'techo_frenar')
QUIERO_VAR = ('TECHO_CADUCA_SEG', 'TECHO_MARGEN', 'techo_recorte', 'techo_visto')
trozos = []
vistas = []
for n in arbol.body:
    if isinstance(n, ast.FunctionDef) and n.name in QUIERO_FUN:
        trozos.append(ast.get_source_segment(src, n))
        vistas.append(n.name)
    elif isinstance(n, ast.Assign):
        for d in n.targets:
            if getattr(d, 'id', '') in QUIERO_VAR:
                trozos.append(ast.get_source_segment(src, n))
                vistas.append(d.id)

faltan = [x for x in QUIERO_FUN + QUIERO_VAR if x not in vistas]
if faltan:
    print('  MAL  no estan en wake_vosk.py, a nivel de modulo: %s' % ', '.join(faltan))
    print('       (si se escribieron sueltas dentro del bucle, ningun banco puede ejecutarlas)')
    sys.exit(1)

ns = {}
exec(chr(10).join(trozos), ns)
CADUCA = ns['TECHO_CADUCA_SEG']
MARGEN = ns['TECHO_MARGEN']

mal = [0]


def comp(que, cond, det=''):
    print('  %-4s %s%s' % ('ok' if cond else 'MAL', que, ('  (%s)' % det) if det else ''))
    if not cond:
        mal[0] += 1


def limpio():
    """Cada caso arranca sin techo: si no, el anterior decidiria por el siguiente."""
    ns['techo_recorte'] = 0.0
    ns['techo_visto'] = 0.0


apuntar = ns['techo_apuntar']
vigente = ns['techo_vigente']
cabe = ns['techo_cabe']
frenar = ns['techo_frenar']
T = 100000.0

print('-- a. los dos numeros, y de donde salen --')
# NO SE COMPARA LA CONSTANTE CONSIGO MISMA: se comprueba que cae dentro de lo medido. Los
# huecos entre recortes desde el 22/09, 633 de ellos: mediana 58 s, p95 904 s, p97 2.978 s.
comp('la caducidad cae dentro de los huecos medidos', 58.0 <= CADUCA <= 2978.0,
     '%.0f s; mediana 58, p95 904, p97 2.978' % CADUCA)
comp('el margen deja sitio pero no regala', 0.80 <= MARGEN < 1.0, 'x%.2f' % MARGEN)

print('')
print('-- b. sin techo, nada cambia --')
limpio()
comp('sin saber de ninguna, todo cabe', cabe(99.0, T) is True, 'hasta que sature una, no hay nada que decir')
comp('  y no se frena nada', frenar(14.0, 3.0, T) == 14.0, 'la calibracion sube como siempre')
comp('  y no hay techo vigente', vigente(T) == 0.0, '')

print('')
print('-- c. lo que saturo, no se vuelve a poner --')
limpio()
apuntar(10.0, T)
tope = round(10.0 * MARGEN, 1)
comp('la que saturo ya no cabe', cabe(10.0, T) is False, 'x10,0 saturo hace nada')
comp('  ni una mayor', cabe(14.0, T) is False, '')
comp('  pero una por debajo si', cabe(tope, T) is True, 'x%.1f' % tope)
comp('y la calibracion se queda en el tope', frenar(14.0, 5.0, T) == tope,
     'pedia x14,0 y se le da x%.1f' % tope)

print('')
print('-- d. SE QUEDA LA MENOR, NO LA ULTIMA --')
# Si se quedara la ultima, una racha con la ganancia ya baja borraria lo aprendido de la alta y
# el siguiente pulso la subiria otra vez al sitio que satura.
limpio()
apuntar(14.0, T)
apuntar(9.0, T + 10)
comp('despues de x14 y x9, el techo es 9', vigente(T + 10) == 9.0, 'el que protege es el bajo')
limpio()
apuntar(9.0, T)
apuntar(14.0, T + 10)
comp('  y en el otro orden, tambien', vigente(T + 10) == 9.0, 'x14 no borra lo aprendido de x9')

print('')
print('-- e. EL TECHO NUNCA FRENA UNA BAJADA --')
# ESTA ES LA COMPROBACION QUE IMPIDE EL DESTROZO: frenar aqui dejaria el microfono saturado y
# sin forma de salir, que es lo contrario de para lo que esta el techo.
limpio()
apuntar(10.0, T)
comp('bajar de x12 a x3 se deja pasar', frenar(3.0, 12.0, T) == 3.0, 'salir de un recorte, siempre')
comp('  aunque la nueva quede por encima del tope', frenar(9.9, 12.0, T) == 9.9, 'sigue siendo una bajada')
comp('  y quedarse igual tambien', frenar(12.0, 12.0, T) == 12.0, '')
# Y NUNCA CONVIERTE UNA SUBIDA EN BAJADA: si la de ahora ya esta por encima del tope, se queda
# donde esta; devolver el tope seria una bajada que nadie ha pedido.
comp('si ya estaba por encima, no la baja por sorpresa', frenar(14.0, 12.0, T) == 12.0,
     'se queda en x12,0, no cae a x%.1f' % tope)

print('')
print('-- f. y caduca, porque la habitacion cambia --')
limpio()
apuntar(10.0, T)
comp('justo antes de caducar, sigue mandando', cabe(14.0, T + CADUCA - 1) is False, '%.0f s' % (CADUCA - 1))
comp('  y pasado el plazo, se olvida', cabe(14.0, T + CADUCA + 1) is True, '%.0f s' % (CADUCA + 1))
comp('  y entonces la calibracion sube otra vez', frenar(14.0, 5.0, T + CADUCA + 1) == 14.0, 'se vuelve a probar')
# CADA RECORTE NUEVO RENUEVA EL PLAZO, aunque el valor no baje: si no, una racha larga con el
# mismo techo lo dejaria caducar en mitad de la racha.
apuntar(10.0, T + 500)
comp('un recorte nuevo renueva el plazo', cabe(14.0, T + 500 + CADUCA - 1) is False, 'aunque el techo no baje')

print('')
print('-- g. y la basura no se aprende --')
limpio()
apuntar(0.0, T)
comp('una ganancia de cero no se apunta', vigente(T) == 0.0, '')
apuntar(-3.0, T)
comp('  ni una negativa', vigente(T) == 0.0, '')

print('')
if mal[0]:
    print('  %d MAL' % mal[0])
    sys.exit(1)
print('  el techo aprendido se respeta y no estorba')
sys.exit(0)
