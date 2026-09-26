# -*- coding: utf-8 -*-
"""PASO 0 DE LA IDEA 22: medir ANTES de escribir una linea de produccion.

LA IDEA: un tercer reconocedor de Vosk con la lista CERRADA de lo que braya tiene instalado,
que corra sobre el mismo audio del dictado. Con lista cerrada, el decodificador esta OBLIGADO a
elegir entre esos nombres, asi que "sting" no puede salir: o sale "steam" o no sale nada.

EL PROBLEMA QUE RESUELVE, medido sobre registro.jsonl (1.037 lineas): "sting" aparece 36 veces
y VEINTIUNA de ellas estan en el campo "vosk", o sea que las dijo el mismo reconocedor libre
que ya corre hoy sobre ese audio. Y el texto entregado de esas filas dice Steam:
    vosk: "ahora sting y sube el brillo"          -> entregado: "Abre Steam y sube el brillo"
    vosk: "cierra la calculadora y cierre sting"  -> entregado: "Cierra la calculadora y cierra Steam"
Ademas, Find-Aproximado NO puede rescatarlo: la distancia fonetica sting->steam es 5 y el tope
para una clave de cinco letras es 2. "stein" (2) y "team" (2) si entran; "sting" no.

LO QUE ESTE PROGRAMA DECIDE, y por eso existe antes que el codigo: si el reconocedor cerrado
separa limpio (a) las veces que hay un nombre de verdad, de (b) las veces que NO lo hay y se lo
inventa. Si no separa, la idea SE CAE y no se implementa. El liston de confianza sale de aqui o
no sale de ningun sitio (regla 3 de la casa: nada de numeros inventados).

    python tools/medir-nombres-instalados.py

Solo lee. No escribe nada en el proyecto.
"""
from __future__ import print_function
import io
import json
import os
import re
import sys
import time
import unicodedata
import wave

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USO = os.path.join(RAIZ, 'pruebas', 'audio', 'uso')
REG = os.path.join(USO, 'registro.jsonl')
MODELO = os.path.join(RAIZ, 'vosk', 'vosk-model-small-es-0.42')
VOCAB = os.path.join(RAIZ, 'tmp', 'vocabulario.txt')
TASA = 16000


def plano(s):
    s = unicodedata.normalize('NFD', s or '')
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = s.lower()
    return re.sub(r'[^a-z0-9 ]+', ' ', s).strip()


def norm(s):
    return re.sub(r'\s+', ' ', plano(s))


print('--- la lista de lo que hay instalado ---')
if not os.path.exists(VOCAB):
    print('  NO hay tmp/vocabulario.txt: sin lista no hay nada que medir')
    sys.exit(1)
crudo = io.open(VOCAB, encoding='utf-8', errors='ignore').read()
nombres = []
for x in crudo.replace('\n', ',').split(','):
    n = norm(x)
    if n and n not in nombres:
        nombres.append(n)
print('  %d nombres, del vocabulario que el asistente ya escribe' % len(nombres))

# EL LEXICO DEL MODELO NO SE PUEDE LEER: este modelo no trae words.txt, el lexico vive dentro
# de graph/Gr.fst. Pero Vosk DICE en voz alta lo que ignora ("Ignoring word missing in
# vocabulary"), asi que se le pregunta a el: se monta la gramatica con la lista entera,
# capturando su salida de error, y lo que se queja es lo que no conoce.
try:
    from vosk import Model, KaldiRecognizer, SetLogLevel
except Exception as e:
    print('  no puedo importar vosk: %s' % e)
    sys.exit(1)
t0 = time.time()
modelo = Model(MODELO)
print('  modelo cargado en %.1f s' % (time.time() - t0))

_tmp = os.path.join(os.environ.get('TEMP', '.'), 'vosk-lexico-%d.txt' % os.getpid())
_fd2 = os.dup(2)
_f = os.open(_tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC)
os.dup2(_f, 2)
try:
    KaldiRecognizer(modelo, TASA, json.dumps(nombres + ['[unk]'], ensure_ascii=False))
finally:
    os.dup2(_fd2, 2)
    os.close(_f)
    os.close(_fd2)
falta = set()
try:
    for l in io.open(_tmp, encoding='utf-8', errors='ignore'):
        m = re.search(r"Ignoring word missing in vocabulary: '([^']+)'", l)
        if m:
            falta.add(m.group(1))
    os.remove(_tmp)
except Exception:
    pass
print('  PALABRAS QUE EL MODELO NO CONOCE: %d' % len(falta))
print('     ' + ', '.join(sorted(falta)))
alcanzables = set(n for n in nombres if not (set(n.split(' ')) & falta))
perdidos = [n for n in nombres if n not in alcanzables]
print('  nombres alcanzables de verdad: %d de %d' % (len(alcanzables), len(nombres)))
print('  se pierden enteros: ' + ', '.join(sorted(perdidos)[:12]))

# --- el reconocedor cerrado -------------------------------------------------------------
SetLogLevel(-1)

GRAM = json.dumps(sorted(alcanzables) + ['[unk]'], ensure_ascii=False)


def cerrado():
    r = KaldiRecognizer(modelo, TASA, GRAM)
    r.SetWords(True)
    return r


t0 = time.time()
for _ in range(5):
    cerrado()
print('  crear el cerrado cuesta %.1f ms' % ((time.time() - t0) * 200))

# --- las filas del registro, con su wav -------------------------------------------------
filas = []
for l in io.open(REG, encoding='utf-8', errors='ignore'):
    try:
        d = json.loads(l)
    except Exception:
        continue
    if not d.get('id') or 'entregado' not in d:
        continue
    filas.append(d)
print('')
print('--- las ordenes con audio en disco ---')
con_wav = []
for d in filas:
    p = os.path.join(USO, d['id'] + '.wav')
    if os.path.exists(p):
        con_wav.append((d, p))
print('  %d de %d ordenes tienen su wav' % (len(con_wav), len(filas)))


def oye(ruta):
    """Devuelve (texto, confianza minima por palabra) del reconocedor cerrado."""
    r = cerrado()
    try:
        w = wave.open(ruta, 'rb')
    except Exception:
        return ('', 0.0)
    try:
        if w.getframerate() != TASA or w.getnchannels() != 1:
            return ('', 0.0)
        while True:
            b = w.readframes(4000)
            if len(b) == 0:
                break
            r.AcceptWaveform(b)
        d = json.loads(r.FinalResult())
    except Exception:
        return ('', 0.0)
    finally:
        w.close()
    txt = norm(d.get('text', ''))
    confs = [x.get('conf', 0.0) for x in d.get('result', []) if x.get('word') != '[unk]']
    return (txt, min(confs) if confs else 0.0)


# --- (a) las que SI llevan un nombre, y (b) las que no ----------------------------------
# COMO SE DECIDE SI LA ORDEN LLEVABA UN NOMBRE: por lo que Nova ENTREGO, que es lo que braya
# dio por bueno. No por lo que oyo el reconocedor libre, que es justo lo que falla.
def lleva_nombre(d):
    e = norm(d.get('entregado', ''))
    for n in alcanzables:
        if re.search(r'\b' + re.escape(n) + r'\b', e):
            return n
    return ''


grupoA, grupoB = [], []
for d, p in con_wav:
    n = lleva_nombre(d)
    (grupoA if n else grupoB).append((d, p, n))
print('  (a) llevan un nombre de la lista en lo entregado: %d' % len(grupoA))
print('  (b) no llevan ninguno:                            %d' % len(grupoB))

TOPE = int(os.environ.get('TOPE', '120'))
print('')
print('--- decodificando (tope %d por grupo, por tiempo) ---' % TOPE)
t0 = time.time()
resA, resB = [], []
for d, p, n in grupoA[:TOPE]:
    txt, conf = oye(p)
    resA.append((d['id'], n, txt, conf, txt == n))
for d, p, n in grupoB[:TOPE]:
    txt, conf = oye(p)
    resB.append((d['id'], '', txt, conf, txt == ''))
print('  %d audios en %.0f s' % (len(resA) + len(resB), time.time() - t0))

# DOS VARAS DE MEDIR, Y LAS DOS HACEN FALTA:
#  - ESTRICTA: lo que devuelve es EXACTAMENTE un nombre de la lista. Es lo que pedia el plan,
#    porque es la unica forma de tapar el agujero del lexico ("elden ring" mutilado a "ring").
#  - FLOJA: el nombre bueno esta ENTRE las palabras que devolvio. Es mas generosa con la idea, y
#    hay que mirarla antes de tumbarla: con una frase entera el cerrado suelta varios nombres
#    seguidos, asi que la estricta la castiga por diseno.
def suelta(txt):
    return [w for w in (txt or '').split(' ') if w]


aciertos = [r for r in resA if r[4]]
aciertosF = [r for r in resA if r[1] and r[1] in (r[2] or '')]
fallos = [r for r in resA if not r[4]]
inventos = [r for r in resB if r[2]]
callados = [r for r in resB if not r[2]]
print('')
print('--- (a) cuando SI habia un nombre ---')
print('  acierta exacto: %d de %d (%.1f %%)' % (len(aciertos), len(resA), 100.0 * len(aciertos) / max(1, len(resA))))
print('  y con la vara floja (el nombre bueno esta entre lo que dijo): %d de %d (%.1f %%)'
      % (len(aciertosF), len(resA), 100.0 * len(aciertosF) / max(1, len(resA))))
for r in aciertos[:8]:
    print('     %-18s -> "%s"  conf %.2f' % (r[0], r[2], r[3]))
print('  falla:          %d' % len(fallos))
for r in fallos[:8]:
    print('     %-18s esperaba "%s" y dijo "%s"  conf %.2f' % (r[0], r[1], r[2], r[3]))
print('')
print('--- (b) cuando NO habia ninguno ---')
print('  se calla:       %d de %d (%.1f %%)' % (len(callados), len(resB), 100.0 * len(callados) / max(1, len(resB))))
print('  se lo inventa:  %d' % len(inventos))
for r in inventos[:10]:
    print('     %-18s se invento "%s"  conf %.2f' % (r[0], r[2], r[3]))

print('')
print('--- EL LISTON: separa o no separa ---')
ca = sorted(r[3] for r in aciertosF)
cb = sorted(r[3] for r in inventos)


def pc(v, q):
    if not v:
        return 0.0
    return v[min(len(v) - 1, int(q * (len(v) - 1)))]


if ca:
    print('  confianza de los aciertos: min %.2f  p10 %.2f  mediana %.2f' % (ca[0], pc(ca, 0.10), pc(ca, 0.50)))
if cb:
    print('  confianza de los inventos: mediana %.2f  p90 %.2f  max %.2f' % (pc(cb, 0.50), pc(cb, 0.90), cb[-1]))
if not ca:
    print('  NO HAY NI UN ACIERTO: la idea se cae, no hay liston que poner.')
elif not cb:
    print('  NO SE INVENTA NADA: el liston puede ser el minimo de los aciertos, %.2f' % ca[0])
else:
    mejor, mejorN = None, -1
    for paso in range(0, 101):
        u = paso / 100.0
        buenos = sum(1 for c in ca if c >= u)
        malos = sum(1 for c in cb if c >= u)
        if malos == 0 and buenos > mejorN:
            mejorN, mejor = buenos, u
    if mejor is None:
        print('  NO SEPARAN: hay inventos con mas confianza que cualquier acierto.')
        print('  LA IDEA SE CAE tal y como esta planteada.')
    else:
        print('  con el liston en %.2f: %d aciertos de %d y CERO inventos' % (mejor, mejorN, len(resA)))
        print('  (y sin liston serian %d aciertos y %d inventos)' % (len(aciertos), len(inventos)))
