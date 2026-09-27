# -*- coding: utf-8 -*-
r"""LO QUE IMPORTO NO SE RESUME (25/09, idea 35 de las 50 / 18 de las 21)

LO MEDIDO: cada intercambio se apunta en bruto en charla-<dia>.jsonl y, al dia siguiente,
resumir_dias_pasados lo pasa por el modelo local, escribe 2-5 vinetas en el diario y BORRA el
bruto. En catorce dias eso ha convertido 342 turnos de conversacion en 29 vinetas y 2.866
bytes; y del 13, 19, 24 y 25/09 no hay ni vineta.

RESUMIR ESTA BIEN para la mayoria: nadie necesita el bruto de "que hora es". Lo que esta mal es
que se resuma TODO POR IGUAL. Contado sobre el log de 14 dias, el 15 % de lo que braya dice son
dos cosas que no se pueden reconstruir de un resumen:

  1. CUANDO TE CORRIGE (41 frases): "No dije Discord, dije Steam", "Pero yo no te dije que
     reprodujeras eso, yo te dije el segundo video y claramente no era". Una vineta que diga
     "hablaron de Steam" no sirve: la frase exacta dice COMO habla braya y EN QUE fallo Nova.
  2. CUANDO NOVA ADMITE UN AGUJERO (10): "No me has dicho nunca como se llama tu mascota", "No
     tengo acceso a esos datos del juego". Es el inventario de lo que le falta.

LO QUE PRUEBA ESTE BANCO: que esos turnos se copian aparte y que el resto NO, que es lo que
separa esto de no podar nada. Y que la copia no depende de que el diario en bruto funcione.
"""
import ast
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(RAIZ, 'charla_worker.py')
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
comp('charla_worker.py se parsea entero', True)

print('-- 1. existe, y se llama desde donde pasan TODOS los turnos --')
nombres = set()
for n in ast.walk(arbol):
    if isinstance(n, ast.FunctionDef):
        nombres.add(n.name)
for f in ('por_que_importa', 'apuntar_importante'):
    comp('existe %s' % f, f in nombres)

# QUE SE LLAME DESDE apuntar_charla, que es el embudo por el que pasa cada intercambio. Se
# mira el ARBOL de esa funcion, no el texto del fichero: una llamada escrita en un comentario
# o en otra funcion no vale (maneras 1 y 4).
ap = [n for n in ast.walk(arbol) if isinstance(n, ast.FunctionDef) and n.name == 'apuntar_charla']
comp('existe apuntar_charla', len(ap) == 1)
if len(ap) == 1:
    llamadas = set()
    for n in ast.walk(ap[0]):
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name):
            llamadas.add(n.func.id)
    comp('  y llama a apuntar_importante', 'apuntar_importante' in llamadas,
         'ahi pasa cada turno de charla')
    comp('  y a por_que_importa', 'por_que_importa' in llamadas)
    # LA COPIA NO PUEDE COLGAR DEL TRY DEL DIARIO: si falla escribir el bruto, la unica copia
    # de una correccion se perderia con el. Tienen que ser dos try distintos.
    tries = [n for n in ap[0].body if isinstance(n, ast.Try)]
    comp('  y va en su propio try, no en el del diario', len(tries) >= 2,
         '%d bloques try: que falle el bruto no puede llevarse lo importante' % len(tries))

print('')
print('-- 2. LAS FUNCIONES, SACADAS DEL ARCHIVO Y EJECUTADAS --')
# se ejecuta el codigo REAL del fichero, no una copia escrita aqui (maneras 2 y 6)
# SE CARGAN TODAS LAS CONSTANTES DE MODULO, no una lista escrita a mano (25/09). La primera
# version nombraba RE_CORRIGE y RE_AGUJERO una por una: al anadir RE_NEGACION, la funcion
# reventaba con NameError dentro de su propio try, devolvia "" -que es TAMBIEN la respuesta
# buena- y nueve comprobaciones se pusieron rojas sin que el codigo tuviera nada malo. Una
# lista a mano en un banco caduca el dia que alguien anade algo.
def quejas_del_worker(*_a, **k):
    quejas.append(k.get('texto', ''))


quejas = []
ns = {'re': re, 'salida': quejas_del_worker}
def es_literal_segura(nodo):
    """True si la asignacion no depende de nada de fuera: un numero, una cadena, o un
    re.compile de cadenas. Asi se cargan TODAS las que usa la funcion sin cargar ademas
    MODELO_LOCAL y companhia, que salen de sys.argv y revientan aqui."""
    v = nodo.value
    if isinstance(v, ast.Constant):
        return True
    if isinstance(v, ast.Call) and isinstance(v.func, ast.Attribute) and v.func.attr == 'compile':
        return all(isinstance(a, ast.Constant) or isinstance(a, ast.BinOp) or
                   isinstance(a, ast.JoinedStr) is False for a in v.args)
    return False


for n in arbol.body:
    if isinstance(n, ast.Assign) and all(isinstance(t, ast.Name) for t in n.targets) and             all(t.id.isupper() for t in n.targets) and es_literal_segura(n):
        try:
            exec(compile(ast.Module(body=[n], type_ignores=[]), FUENTE, 'exec'), ns)
        except Exception:      # una constante que no se puede cargar sola: no es de las nuestras
            pass
    if isinstance(n, ast.FunctionDef) and n.name == 'por_que_importa':
        exec(compile(ast.Module(body=[n], type_ignores=[]), FUENTE, 'exec'), ns)
comp('se sacan los patrones del archivo', 'RE_CORRIGE' in ns and 'RE_AGUJERO' in ns)
comp('  y el de la negacion larga', 'RE_NEGACION' in ns and 'NEGACION_PALABRAS' in ns)
comp('  y el liston sale del archivo, no de aqui', ns.get('NEGACION_PALABRAS') == 5,
     'vale %s' % ns.get('NEGACION_PALABRAS'))
por_que_importa = ns.get('por_que_importa')
comp('y la funcion', por_que_importa is not None)
if por_que_importa is None:
    print('')
    print('  %d MAL' % mal)
    sys.exit(1)

print('')
print('-- 3. LAS FRASES DE VERDAD, sacadas del log de braya --')
# CORRECCIONES REALES (las cuatro primeras son literales del registro)
for frase in ('No dije Discord, dije Steam',
              # LA NEGACION LARGA, que los dos patrones de arriba no cazaban (25/09). Estas
              # cuatro son literales del registro y las cuatro son correcciones de verdad.
              'No, el brillo no sabes por que me contestas eso',
              'No, no te pedi la hora, Dije si es Steam',
              'No, no es buscarlo en Google, es poner la mitad de una pantalla en Pinterest',
              'No lo estas haciendo bien, estas hablandolo en el mismo navegador',
              'Pero yo no te dije que reproduciras eso, Yo te dije el segundo video y claramente no era',
              'no era eso',
              'No, el brillo no sabes por que me contestas eso'):
    comp('se guarda: "%s"' % frase[:52], por_que_importa(frase, 'lo que sea') == 'correccion')

# AGUJEROS REALES (literales de las respuestas de Nova)
for resp in ('No me has dicho nunca como se llama tu mascota, asi que no lo se.',
             'No tengo acceso a esos datos del juego, la verdad.',
             'No tengo ningun dato sobre un oso polar en lo que se de ti, braya.'):
    comp('se guarda el agujero: "%s"' % resp[:44], por_que_importa('cualquier cosa', resp) == 'agujero')

print('')
print('-- 4. Y LO NORMAL NO SE GUARDA (si no, esto no poda nada) --')
# ESTO ES LA MITAD DEL VALOR: si todo pareciera importante, el fichero seria una copia del
# diario y no habriamos separado nada.
# Y EL LISTON DE LA NEGACION: un "no" corto NO es una correccion, y si lo fuera este fichero
# se llenaria de "no" sueltos. Esto es lo que ejercita las cinco palabras.
for frase in ('no', 'No.', 'no, gracias', 'No, nada'):
    comp('NO se guarda el no corto: "%s"' % frase, por_que_importa(frase, 'vale') == '',
         '%d palabra(s): por debajo del liston' % len(frase.split()))

for frase, resp in (('que hora es', 'Son las once y veinte.'),
                    ('abre Steam', 'Abriendo Steam.'),
                    ('pon musica', 'Va.'),
                    ('gracias', 'De nada.'),
                    ('sube el volumen al 60', 'Volumen al 60.')):
    comp('NO se guarda: "%s"' % frase, por_que_importa(frase, resp) == '',
         'un turno normal no ocupa sitio')
comp('ni con los dos vacios', por_que_importa('', '') == '')
comp('ni con None, sin reventar', por_que_importa(None, None) == '')

print('')
print('-- 5. EL MOTIVO SE DICE, no es un si/no --')
comp('una correccion se marca como tal', por_que_importa('no dije eso', 'ya') == 'correccion')
comp('un agujero tambien', por_que_importa('hola', 'no tengo acceso a eso') == 'agujero')
comp('y la correccion manda sobre el agujero',
     por_que_importa('no dije eso', 'no tengo acceso a eso') == 'correccion',
     'lo que dice braya pesa mas que lo que contesta Nova')

print('')
print('-- 6. Y SI UN PATRON SE ROMPE, SE OYE --')
# "" es TAMBIEN la respuesta buena ("este turno es normal"), asi que un patron roto dejaria de
# guardar correcciones en silencio y el fichero solo se quedaria vacio. Con la queja, se ve.
quejas[:] = []
comp('un turno normal no se queja de nada', (por_que_importa('hola', 'hola') == '') and not quejas)
falsa = dict(ns)
falsa['RE_CORRIGE'] = None          # lo que pasaria si alguien rompe un patron
exec(compile(ast.Module(body=[n for n in arbol.body
                              if isinstance(n, ast.FunctionDef) and n.name == 'por_que_importa'],
                        type_ignores=[]), FUENTE, 'exec'), falsa)
quejas[:] = []
r = falsa['por_que_importa']('no dije eso', 'ya')
comp('con un patron roto devuelve "" ...', r == '')
comp('  ...pero lo dice en voz alta', len(quejas) == 1, 'si no, el fichero se quedaria vacio en silencio')

print('')
print('-- 7. Y NO SALE DE LA MAQUINA --')
# El fichero lleva conversaciones personales y el repositorio es PUBLICO.
gi = io.open(os.path.join(RAIZ, '.gitignore'), encoding='utf-8').read()
comp('memoria/cerebro esta en el .gitignore', 'memoria/cerebro/' in gi or 'cerebro/' in gi,
     'ahi es donde se escribe importante.jsonl')
comp('y el fichero se escribe ahi dentro', 'CARPETA_CEREBRO' in src and 'importante.jsonl' in src)


print('')
print('-- 8. Y TAMBIEN FUERA DE LA CHARLA (27/09, idea 68) --')
# EL DATO: de las 68 frases-correccion del registro, 16 (el 24 %) no aparecen en ninguna linea
# CHARLA: eran ordenes o dictados. Se perdia justo la correccion mas util, la que dice QUE orden
# se ejecuto mal. Ahora el juicio corre tambien en apuntar_hilo, que es por donde el asistente
# manda cada orden (Set-UltimaOrden -> op "apunta").
#
# SIN DUPLICAR LA REGLA: la ficha de la idea proponia llevar por_que_importa a PowerShell y que un
# banco comparase las dos copias. No hay dos copias que comparar, y eso es mejor que compararlas.
ah = [n for n in ast.walk(arbol) if isinstance(n, ast.FunctionDef) and n.name == 'apuntar_hilo']
comp('existe apuntar_hilo', len(ah) == 1)
if len(ah) == 1:
    llam2 = set()
    for n in ast.walk(ah[0]):
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name):
            llam2.add(n.func.id)
    comp('  y juzga el turno igual que la charla', 'por_que_importa' in llam2)
    comp('  y lo copia a lo importante', 'apuntar_importante' in llam2)
    comp('  respetando el modo invitado', 'invitado' in [a.arg for a in ah[0].args.args],
         'con otro delante no se guarda nada suyo')
comp('y NO hay una segunda copia de la regla en PowerShell',
     'no dije|no era eso' not in io.open(os.path.join(RAIZ, 'assistant.ps1'), encoding='utf-8').read(),
     'la manera 15: dos copias que se separan con el tiempo')

print('')
print('-- 9. LA COLA DE CUANDO LA CHARLA ESTA DORMIDA, EJECUTADA DE VERDAD --')
# Set-UltimaOrden manda la orden SIN arrancar el worker (levantarlo en mitad de una orden costaria
# segundos), asi que con la charla dormida el turno se perdia entero. PowerShell deja la linea
# CRUDA en hilo-pendiente.jsonl y el juicio se hace al arrancar, aqui.
import json as _json
import tempfile
import shutil
import time as _time
ns9 = dict(ns)          # ns ya trae re + las constantes del modulo, cargadas del fichero
carpeta9 = tempfile.mkdtemp(prefix='nova-pend-')
try:
    class _CmFalso(object):
        @staticmethod
        def limpio(t, n):
            return (t or '')[:n]
    ns9.update({'os': os, 'json': _json, 'time': _time, 'cm': _CmFalso, 'CARPETA_CEREBRO': carpeta9})
    for f in ('por_que_importa', 'apuntar_importante', 'vaciar_hilo_pendiente'):
        nodo = [n for n in arbol.body if isinstance(n, ast.FunctionDef) and n.name == f]
        comp('se encuentra %s' % f, len(nodo) == 1)
        if nodo:
            exec(compile(ast.Module(body=nodo, type_ignores=[]), FUENTE, 'exec'), ns9)
    ruta9 = os.path.join(carpeta9, 'hilo-pendiente.jsonl')
    with io.open(ruta9, 'w', encoding='utf-8') as f:
        f.write(_json.dumps({'texto': 'no, yo te dije el segundo video', 'hecho': 'reproducir el primero'}) + '\n')
        f.write(_json.dumps({'texto': 'pon musica', 'hecho': 'abrir Spotify'}) + '\n')
        f.write('esto no es json\n')
        f.write(_json.dumps({'texto': 'no dije Discord, dije Steam', 'hecho': 'abrir Discord', 'invitado': True}) + '\n')
    quejas[:] = []
    ns9['vaciar_hilo_pendiente']()
    imp = os.path.join(carpeta9, 'importante.jsonl')
    lineas9 = []
    if os.path.exists(imp):
        lineas9 = [_json.loads(x) for x in io.open(imp, encoding='utf-8').read().splitlines() if x.strip()]
    comp('la correccion se guarda', len(lineas9) == 1, '%d linea(s)' % len(lineas9))
    if lineas9:
        comp('  con el motivo marcado como de orden', lineas9[0].get('por') == 'correccion-orden',
             str(lineas9[0].get('por')))
        comp('  y dice QUE orden se ejecuto mal', lineas9[0].get('nova') == 'reproducir el primero',
             str(lineas9[0].get('nova')))
    comp('una orden normal NO se guarda', not any('pon musica' in (x.get('braya') or '') for x in lineas9),
         'si se guardara todo, el fichero no distinguiria nada')
    comp('lo de un invitado tampoco', not any('Discord' in (x.get('braya') or '') for x in lineas9))
    comp('una linea rota no rompe la cola', len(lineas9) == 1, 'se salta y sigue')
    comp('y la cola se borra al vaciarla', not os.path.exists(ruta9),
         'si no, se reintentaria en cada arranque para siempre')
    comp('y lo dice en voz alta', any('esperaban con la charla apagada' in q for q in quejas),
         'un trabajo callado no se puede comprobar')
    # sin fichero no hace nada y no revienta
    quejas[:] = []
    ns9['vaciar_hilo_pendiente']()
    comp('sin cola, ni una palabra ni un fallo', not quejas)
finally:
    shutil.rmtree(carpeta9, ignore_errors=True)

print('')
print('-- 10. Y EL CABLEADO EN POWERSHELL --')
ps = io.open(os.path.join(RAIZ, 'assistant.ps1'), encoding='utf-8').read()
comp('Set-UltimaOrden manda tambien el modo invitado', "invitado = [bool]$script:invitado } $false" in ps)
comp('y encola si la charla no estaba viva', 'if (-not $mandado -and -not $script:invitado) { Add-HiloPendiente' in ps)
comp('la cola tiene tope', '$HiloPendienteMax = 200' in ps, 'un dia entero sin charla no deja un fichero sin fin')
comp('y se queda con las ULTIMAS', 'Select-Object -Last $HiloPendienteMax' in ps)
comp('la cola vive en memoria/cerebro (que no sale de la maquina)', "Join-Path $MemoriaDir 'cerebro'" in ps)

print('')
if mal:
    print('  %d MAL' % mal)
    sys.exit(1)
print('  lo que importo sobrevive a la poda')
sys.exit(0)
