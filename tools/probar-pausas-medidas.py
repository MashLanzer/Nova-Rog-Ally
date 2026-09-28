# -*- coding: utf-8 -*-
r"""LOS TRES SILENCIOS QUE CIERRAN LA FRASE, MEDIDOS DE SU USO REAL (27/09, idea 74 de las 121)

LOS TRES NUMEROS de hoy salieron de una tanda de 100 grabaciones LEIDAS del 14/09, y del tercero el
propio comentario del codigo decia "provisional y razonado, no medido": SILENCIO_FIN = 1,5 s (frase
que aun no se entiende), SILENCIO_FIN_LOTENGO = 1,1 s (el asistente ya tiene la orden) y
SILENCIO_SIN_PALABRA = 3,2 s (el cierre que manda con los altavoces sonando).

MEDIDO AQUI sobre las 574 grabaciones de pruebas\audio\uso, con el MISMO detector que usa el oido
(tramas de 30 ms, suelo por percentil 20 del propio audio): 1.363 pausas DENTRO de una orden, con
p50 0,25 s, p90 1,15, p95 1,70, p98 2,45, p99 3,55 y maxima 6,75. La cola de silencio que se paga al
final de cada orden: mediana 1,70 s, p90 2,30; 16,8 minutos de reloj en 566 ordenes.

Y LO QUE ESA MEDICION DICE ES LO CONTRARIO DE LO QUE ESPERABA LA FICHA: el 1,5 de hoy cae en el
percentil 93,5 de sus pausas reales, o sea que esta BIEN elegido. Poner el p95 lo subiria a 1,70 y
Nova iria MAS LENTA. Por eso aqui el numero escrito es el TECHO: Nova solo puede ACELERAR.

LO QUE ESTE BANCO PROTEGE:
  1. que nunca se pase del numero escrito (nada de volverse mas lenta por medir)
  2. que no baje del suelo (cortar frases a media es peor que esperar un poco)
  3. que con pocas muestras manden los numeros de siempre
  4. que el detector de pausas sea el MISMO que el de segundos_de_voz, o los numeros no se pueden
     comparar con nada
"""
import ast
import glob
import io
import json
import os
import subprocess
import sys
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# EL BANCO TIENE QUE CORRER CON EL PYTHON DE NOVA (27/09). La bateria (probar-todo.ps1) lanza los
# bancos de Python con el "python" del PATH, que en esta consola es 3.11 y NO tiene numpy; Nova
# arranca sus workers con el de config.json paths.python -por defecto
# %LOCALAPPDATA%\Programs\Python\Python312\python.exe, ver $PyExe en assistant.ps1-, que SI lo
# tiene. Y aqui numpy no es un adorno del banco: las piezas de verdad que se extraen de
# wake_vosk.py lo usan por dentro (pausas_del_audio hace np.sqrt/np.percentile sobre las tramas y
# segundos_de_voz np.frombuffer), y es lo que se les pasa en el namespace. Sin numpy el banco no
# llegaba ni al primer caso: se caia con "ModuleNotFoundError: No module named 'numpy'" en el
# import y la seccion 2n227 salia en rojo por el interprete, no por el codigo. Ni se dobla numpy
# -seria meter una dependencia de mentira por debajo de la pieza que se prueba- ni se salta ningun
# caso: se vuelve a lanzar con el interprete de Nova, que es el que la corre de verdad. Y si ese
# interprete no aparece o tampoco lo tiene, se dice y se sale en rojo. Mismo remedio que ya lleva
# tools/probar-tope-reloj.py por lo mismo.


def _python_de_nova():
    exe = ''
    try:
        with io.open(os.path.join(RAIZ, 'config.json'), encoding='utf-8-sig') as f:
            exe = ((json.load(f).get('paths') or {}).get('python') or '').strip()
    except Exception:  # noqa: BLE001
        exe = ''
    if not exe:
        exe = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Python', 'Python312', 'python.exe')
    exe = os.path.expandvars(exe)
    return exe if os.path.isfile(exe) else ''


try:
    import numpy as np
except Exception:  # noqa: BLE001
    _exe = _python_de_nova()
    if _exe and os.path.normcase(_exe) != os.path.normcase(sys.executable) and not os.environ.get('NOVA_PAUSAS_RELANZADO'):
        os.environ['NOVA_PAUSAS_RELANZADO'] = '1'
        sys.exit(subprocess.call([_exe, os.path.abspath(__file__)] + sys.argv[1:]))
    if _exe:
        print('  MAL  el Python de Nova (%s) tampoco tiene numpy: no se pueden EJECUTAR las pausas' % (_exe,))
    else:
        print('  MAL  falta numpy y no encuentro el Python de Nova: no se pueden EJECUTAR las pausas')
    sys.exit(1)

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

guardadas = {}
ns = {'np': np, 'os': os,
      'guardar_lista': lambda ruta, vals: guardadas.__setitem__(ruta, list(vals)),
      'cargar_lista': lambda ruta, tope, tope_valor=200.0: list(guardadas.get(ruta, []))[-tope:],
      'RUTA_PAUSAS': 'pausas.txt'}
for n in arbol.body:
    if isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
        if isinstance(n.value, (ast.Constant, ast.List, ast.Dict)):
            try:
                exec(compile(ast.Module(body=[n], type_ignores=[]), FUENTE, 'exec'), ns)
            except Exception:
                pass
for f in ('pausas_del_audio', 'apuntar_pausas', 'silencio_medido', 'silencio_para_cerrar', 'segundos_de_voz'):
    nodo = [x for x in arbol.body if isinstance(x, ast.FunctionDef) and x.name == f]
    comp('se encuentra %s' % f, len(nodo) == 1)
    if nodo:
        exec(compile(ast.Module(body=nodo, type_ignores=[]), FUENTE, 'exec'), ns)
print('  ok   los numeros salen del archivo  (minimas %d, pct %d/%d/%d, suelos %.1f/%.1f/%.1f)'
      % (ns['PAUSAS_MINIMAS'], ns['PAUSAS_PCT_LARGO'], ns['PAUSAS_PCT_CORTO'], ns['PAUSAS_PCT_ALTAVOCES'],
         ns['SILENCIO_FIN_SUELO'], ns['SILENCIO_FIN_LOTENGO_SUELO'], ns['SILENCIO_SIN_PALABRA_SUELO']))

print('')
print('-- 1. SIN MUESTRAS, LOS NUMEROS DE SIEMPRE --')
ns['pausas'] = []
comp('1a. sin pausas, cierra a 1,5 como hoy', ns['silencio_para_cerrar']('', 'abre steam') == ns['SILENCIO_FIN'],
     '%.2f s' % ns['silencio_para_cerrar']('', 'abre steam'))
comp('1b. y a 1,1 cuando ya tiene la orden', ns['silencio_para_cerrar']('abre steam', 'abre steam') == ns['SILENCIO_FIN_LOTENGO'],
     '%.2f s' % ns['silencio_para_cerrar']('abre steam', 'abre steam'))
ns['pausas'] = [0.2] * (ns['PAUSAS_MINIMAS'] - 1)
comp('1c. con una muestra menos del minimo, todavia los de siempre',
     ns['silencio_para_cerrar']('', 'x') == ns['SILENCIO_FIN'], '%d pausas' % len(ns['pausas']))

print('')
print('-- 2. NUNCA MAS LENTA QUE HOY (el numero escrito es el TECHO) --')
# sus pausas REALES: el p98 son 2,45 s, muy por encima del 1,5 de hoy
ns['pausas'] = [0.25] * 200 + [1.7] * 20 + [2.5] * 10 + [6.7]
p98 = float(np.percentile(np.array(ns['pausas']), 98))
comp('2a. con un p98 de %.2f s...' % p98, p98 > ns['SILENCIO_FIN'], 'por encima del 1,5 escrito')
comp('2b. ...sigue cerrando a 1,5 y no a %.2f' % p98, ns['silencio_para_cerrar']('', 'x') == ns['SILENCIO_FIN'],
     '%.2f s' % ns['silencio_para_cerrar']('', 'x'))
comp('2c. y lo mismo con la orden ya entendida', ns['silencio_para_cerrar']('a', 'a') == ns['SILENCIO_FIN_LOTENGO'],
     '%.2f s' % ns['silencio_para_cerrar']('a', 'a'))
# el de los altavoces (3,2) es tan alto que con estas pausas SI acelera, y eso esta bien: lo que
# protege esta seccion es que NUNCA pase del numero escrito, no que no baje.
_alt = ns['silencio_medido'](ns['PAUSAS_PCT_ALTAVOCES'], ns['SILENCIO_SIN_PALABRA'], ns['SILENCIO_SIN_PALABRA_SUELO'])
comp('2d. y el cierre de los altavoces no pasa de 3,2', _alt <= ns['SILENCIO_SIN_PALABRA'], '%.2f s' % _alt)
comp('2e. ni baja de su suelo', _alt >= ns['SILENCIO_SIN_PALABRA_SUELO'], 'suelo %.2f s' % ns['SILENCIO_SIN_PALABRA_SUELO'])

print('')
print('-- 3. PERO SI DE VERDAD HABLA SEGUIDO, ACELERA --')
ns['pausas'] = [0.15] * 300
comp('3a. con todas sus pausas en 0,15 s, cierra antes', ns['silencio_para_cerrar']('', 'x') < ns['SILENCIO_FIN'],
     '%.2f s en vez de 1,50' % ns['silencio_para_cerrar']('', 'x'))
comp('3b. pero no por debajo del suelo', ns['silencio_para_cerrar']('', 'x') >= ns['SILENCIO_FIN_SUELO'],
     'suelo %.2f s' % ns['SILENCIO_FIN_SUELO'])
ns['pausas'] = [0.15] * 250 + [1.0] * 50
v3 = ns['silencio_para_cerrar']('', 'x')
comp('3c. con un p98 intermedio, se queda en ese valor', ns['SILENCIO_FIN_SUELO'] <= v3 <= ns['SILENCIO_FIN'],
     '%.2f s' % v3)

print('')
print('-- 4. EL DETECTOR ES EL MISMO QUE EL DEL OIDO --')
# si midiera el silencio de otra forma que segundos_de_voz, los numeros no se podrian comparar
cuerpo_p = [x for x in arbol.body if isinstance(x, ast.FunctionDef) and x.name == 'pausas_del_audio'][0]
cuerpo_v = [x for x in arbol.body if isinstance(x, ast.FunctionDef) and x.name == 'segundos_de_voz'][0]
txt_p = ast.unparse(cuerpo_p) if hasattr(ast, 'unparse') else ''
txt_v = ast.unparse(cuerpo_v) if hasattr(ast, 'unparse') else ''
comp('4a. mismo tamano de trama (480 muestras = 30 ms)', ('tr = 480' in txt_p) and ('tr = 480' in txt_v))
comp('4b. mismo suelo (percentil 20 del propio audio)',
     ("percentile(e, 20)" in txt_p) and ("percentile(e, 20)" in txt_v))
comp('4c. mismo corte', ("max(0.008, suelo * 1.8, float(np.percentile(e, 90)) * 0.15)" in txt_p) and
     ("max(0.008, suelo * 1.8, float(np.percentile(e, 90)) * 0.15)" in txt_v))

print('')
print('-- 5. SOBRE SUS GRABACIONES DE VERDAD --')
fich = sorted(glob.glob(os.path.join(RAIZ, 'pruebas', 'audio', 'uso', '*.wav')))
if not fich:
    print('  --   no hay grabaciones de uso en esta maquina; el resto del banco no depende de ellas')
else:
    guardadas.clear()
    ns['pausas'] = []
    total = 0
    leidas = 0
    for f in fich[:120]:
        try:
            with wave.open(f, 'rb') as w:
                crudo = w.readframes(w.getnframes())
        except Exception:
            continue
        leidas += 1
        ns['apuntar_pausas']([crudo])
        total = len(ns['pausas'])
    comp('5a. se miden pausas de sus ordenes', total > 0, '%d pausas en %d grabaciones' % (total, leidas))
    comp('5b. y se guardan atadas a su fichero', 'pausas.txt' in guardadas, ', '.join(guardadas.keys()))
    comp('5c. la lista no pasa de su tope', len(ns['pausas']) <= ns['PAUSAS_MEMORIA'],
         '%d de %d' % (len(ns['pausas']), ns['PAUSAS_MEMORIA']))
    # ninguna pausa puede ser mas larga que el dictado maximo
    comp('5d. ninguna pausa absurda', all(0.09 <= x <= 30.0 for x in ns['pausas']),
         'min %.2f, max %.2f' % (min(ns['pausas']), max(ns['pausas'])) if ns['pausas'] else '')
    if len(ns['pausas']) >= ns['PAUSAS_MINIMAS']:
        cierre = ns['silencio_para_cerrar']('', 'x')
        print('       con esas pausas reales, Nova cerraria a %.2f s (hoy 1,50)' % cierre)
        comp('5e. y nunca peor que hoy', cierre <= ns['SILENCIO_FIN'], '%.2f s' % cierre)
        comp('5f. ni por debajo del suelo', cierre >= ns['SILENCIO_FIN_SUELO'], 'suelo %.2f s' % ns['SILENCIO_FIN_SUELO'])

print('')
print('-- 6. NADA DE ESTO SE ROMPE CON AUDIO RARO --')
ns['pausas'] = []
comp('6a. sin audio, ni pausas ni fallo', ns['pausas_del_audio'](np.zeros(0, dtype='float32')) == [])
comp('6b. con audio en silencio, tampoco', ns['pausas_del_audio'](np.zeros(16000, dtype='float32')) == [])
comp('6c. con bloques vacios, apuntar_pausas no revienta', ns['apuntar_pausas']([]) is None)
comp('6d. y con basura dentro, tampoco', ns['apuntar_pausas']([b'\x00\x01']) is None)

print('')
if mal:
    print('  %d MAL' % mal)
    sys.exit(1)
print('  los silencios salen de sus pausas, y solo para ir mas rapida')
sys.exit(0)
