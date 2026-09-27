# -*- coding: utf-8 -*-
r"""EL OIDO SABE CUANTO VA A TARDAR CADA MOTOR (27/09, idea 71 de las 121)

LO MEDIDO sobre los 477 repasos de registro.jsonl, dividiendo los segundos de cada fila 'motor'
entre la duracion del audio de la fila de orden con el mismo id: base 0,32 s por segundo de audio
(n=328), canary 0,43 (n=29), small 0,93 (n=94), omni 1,05 (n=3), turbo 2,97 (n=23).

QUE SIGNIFICA: dentro del plazo del asistente -15 s- a base le caben 46 segundos de audio y a
turbo cinco. El tope de hoy son 8 para los dos (12 para base). Resultado: turbo se paso del plazo
en 17 de sus 23 usos (el 73 %), small en 12 de 94 y base en 6 de 328. Son 36 repasos que llegaron
tarde: 23,2 minutos de CPU quemados para nada, 9 minutos de plazo esperandolos, y 30 lineas
'OIDO FINO: sin respuesta a tiempo; sigo con lo que tenia' en los registros.

Y LO QUE CORRIGIO EL VERIFICADOR, que cambia donde hay que meter mano: canary y omni salen de
atender_reintento por su propia rama ANTES de que se calcule la duracion, asi que hasta hoy NO
TENIAN NINGUN TOPE.

LO QUE ESTE BANCO PROTEGE:
  1. que con el ritmo medido se rechace lo que NO cabe... y se acepte lo que si cabe
  2. que el ULTIMO escalon no se salte nunca (detras de turbo no hay nada)
  3. que sin plazo o sin ritmo se vuelva al tope de segundos de audio de siempre
  4. que un arranque en frio no deje a un motor fuera para siempre (mediana, no la peor)
"""
import ast
import io
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, 'wake_vosk.py')
mal = 0


def comp(que, ok, detalle=''):
    global mal
    if ok:
        print('  ok   %s%s' % (que, ('  (' + detalle + ')') if detalle else ''))
    else:
        print('  MAL  %s%s' % (que, ('  (' + detalle + ')') if detalle else ''))
        mal += 1


src = io.open(FUENTE, encoding='utf-8').read()
arbol = ast.parse(src)
comp('wake_vosk.py se parsea entero', True)

# --- las funciones, sacadas del archivo y ejecutadas (nunca una copia escrita aqui) ---
ns = {'os': os, 'time': __import__('time')}
guardadas = {}


def guardar_lista_falso(ruta, valores):
    guardadas[ruta] = list(valores)


def cargar_lista_falso(ruta, tope, tope_valor=200.0):
    return list(guardadas.get(ruta, []))[-tope:]


ns['guardar_lista'] = guardar_lista_falso
ns['cargar_lista'] = cargar_lista_falso
ns['ruta_ritmo'] = lambda motor: ('ritmo-%s.txt' % motor) if motor else ''
# las constantes del modulo que son literales sueltas (no las que salen de sys.argv)
for n in arbol.body:
    if isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
        if isinstance(n.value, (ast.Constant, ast.Dict, ast.List)):
            try:
                exec(compile(ast.Module(body=[n], type_ignores=[]), FUENTE, 'exec'), ns)
            except Exception:
                pass
for f in ('mediana', 'ritmo_motor', 'apuntar_ritmo', 'cabe_el_repaso'):
    nodo = [x for x in arbol.body if isinstance(x, ast.FunctionDef) and x.name == f]
    comp('se encuentra %s' % f, len(nodo) == 1)
    if nodo:
        exec(compile(ast.Module(body=nodo, type_ignores=[]), FUENTE, 'exec'), ns)
mediana = ns['mediana']
ritmo_motor = ns['ritmo_motor']
apuntar_ritmo = ns['apuntar_ritmo']
cabe = ns['cabe_el_repaso']
print('  ok   los tres numeros salen del archivo  (memoria %d, minimo %d, margen %s)'
      % (ns['RITMO_MEMORIA'], ns['RITMO_MIN'], ns['RITMO_MARGEN']))

print('')
print('-- 1. SIN DATOS, EL TOPE DE SIEMPRE (nada cambia hasta que hay medidas) --')
ns['_ritmo'].clear()
guardadas.clear()
ok, por = cabe('small', 5.0, 15.0)
comp('1a. 5 s de audio sin ritmo aprendido: se repasa', ok, por)
ok, por = cabe('small', 9.0, 15.0)
comp('1b. 9 s pasa el tope de 8 del oido fino: no se repasa', not ok, por)
ok, por = cabe('base', 9.0, 15.0)
comp('1c. pero base tiene su propio tope de 12: si se repasa', ok, por)
ok, por = cabe('base', 13.0, 15.0)
comp('1d. y con 13 s ya no', not ok, por)

print('')
print('-- 2. CON EL RITMO MEDIDO, MANDA EL PLAZO --')
# los ritmos reales medidos en el registro
for _ in range(6):
    apuntar_ritmo('turbo', 2.97, 1.0)
    apuntar_ritmo('base', 0.32, 1.0)
    apuntar_ritmo('small', 0.93, 1.0)
    apuntar_ritmo('canary', 0.43, 1.0)
comp('2a. el ritmo de turbo se aprende', abs(ritmo_motor('turbo') - 2.97) < 0.01, '%.2f s/s' % ritmo_motor('turbo'))
# turbo con 15 s de plazo: le caben ~4 s de audio (5 / 1,25 de margen)
ok, por = cabe('turbo', 4.0, 15.0)
comp('2b. turbo con 4 s de audio y 15 s de plazo: cabe', ok, por)
ok, por = cabe('turbo', 6.0, 15.0)
comp('2c. turbo con 6 s de audio: NO cabe, y no se carga el modelo', not ok, por)
# y eso es lo que pasaba de verdad: 6 s de audio son 17,8 s de turbo
comp('2d. y lo dice con los numeros', ('17.8' in por) or ('17,8' in por), por)
# base, en cambio, se traga audios largos de sobra
ok, por = cabe('base', 20.0, 15.0)
comp('2e. base con 20 s de audio en 15 s de plazo: cabe (0,32 s/s)', ok, por)
ok, por = cabe('base', 40.0, 15.0)
comp('2f. con 40 s ya no cabe', not ok, por)
# small: 15 s de plazo / 0,93 = 16 s, con margen ~12,9
ok, por = cabe('small', 10.0, 15.0)
comp('2g. small con 10 s de audio: cabe', ok, por)
ok, por = cabe('small', 14.0, 15.0)
comp('2h. small con 14 s: no cabe', not ok, por)
# EL TOPE VIEJO YA NO MANDA cuando hay ritmo: un audio de 9 s con base y plazo largo entra
ok, por = cabe('base', 9.0, 60.0)
comp('2i. con un plazo grande, el tope viejo de 12 s ya no corta', ok, por)

print('')
print('-- 3. EL ULTIMO ESCALON NO SE SALTA NUNCA --')
ok, por = cabe('turbo', 120.0, 1.0, True)
comp('3a. turbo como ultimo recurso, con 120 s de audio y 1 s de plazo: se repasa igual', ok,
     'detras de el no hay nada; saltarselo es quedarse sin respuesta')
ok, por = cabe('turbo', 120.0, 1.0, False)
comp('3b. y el mismo audio NO como ultimo: no se repasa', not ok, por)

print('')
print('-- 4. LA MEDIANA, NO LA PEOR (un arranque en frio no deja fuera a un motor) --')
ns['_ritmo'].clear()
guardadas.clear()
for _ in range(5):
    apuntar_ritmo('small', 0.9, 1.0)
apuntar_ritmo('small', 30.0, 1.0)     # el arranque en frio: 30 s por segundo de audio
r = ritmo_motor('small')
comp('4a. un solo repaso lentisimo no se lleva la mediana', r < 1.5, '%.2f s/s con un 30,0 dentro' % r)
ok, por = cabe('small', 10.0, 15.0)
comp('4b. asi que small sigue repasando lo que puede', ok, por)
# y la lista no crece sin fin
for _ in range(100):
    apuntar_ritmo('small', 0.9, 1.0)
comp('4c. la lista se queda en su tope', len(ns['_ritmo']['small']) == ns['RITMO_MEMORIA'],
     '%d valores' % len(ns['_ritmo']['small']))
comp('4d. y se guarda en disco para la proxima sesion', 'ritmo-small.txt' in guardadas,
     ', '.join(sorted(guardadas.keys())))

print('')
print('-- 5. LO QUE NO SE PUEDE MEDIR NO SE APUNTA --')
ns['_ritmo'].clear()
guardadas.clear()
apuntar_ritmo('small', 5.0, 0.0)      # sin audio: division por cero
apuntar_ritmo('small', 0.0, 5.0)      # sin tiempo: imposible
apuntar_ritmo('small', 5.0, 0.01)     # 500 s/s: absurdo, fuera del tope
apuntar_ritmo('', 5.0, 5.0)           # sin motor
comp('5a. nada de eso entra en la lista', len(ns['_ritmo'].get('small', [])) == 0,
     '%d valores' % len(ns['_ritmo'].get('small', [])))
comp('5b. y sin lista, se vuelve al tope de siempre', not cabe('small', 9.0, 15.0)[0],
     'el de 8 s de audio')

print('')
print('-- 6. Y EL MARGEN SE RESPETA --')
ns['_ritmo'].clear()
guardadas.clear()
for _ in range(6):
    apuntar_ritmo('small', 1.0, 1.0)  # 1 s por segundo de audio, facil de contar
# con margen 1,25 y plazo 10 s, el tope real son 8 s de audio
ok, _p = cabe('small', 7.9, 10.0)
comp('6a. 7,9 s de audio con 10 s de plazo: cabe', ok, 'margen %s' % ns['RITMO_MARGEN'])
ok, _p = cabe('small', 8.1, 10.0)
comp('6b. 8,1 s: no cabe (el margen se lo come)', not ok, 'se deja un cuarto de sitio de sobra')

print('')
if mal:
    print('  %d MAL' % mal)
    sys.exit(1)
print('  el oido no empieza lo que no va a llegar')
sys.exit(0)
