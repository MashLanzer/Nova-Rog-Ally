# LA CRIBA DE IDEAS: lo que se me salto nueve veces de veinte, hecho a maquina (1/10/2026)
#
# EL PROBLEMA, con su numero: de las 20 ideas del 1/10, NUEVE ya estaban hechas o se apoyaban en un
# dato falso. Y el metodo (METODO-BUSCAR-IDEAS.md) YA DECIA "primero mira, luego propon" y "ante la
# duda razonable sobre si ya existe, matarla". O sea que el fallo no es que falte la instruccion:
# es que la instruccion la tiene que cumplir el que propone, y el que propone siempre cree que ya
# miro. Un metodo que pide algo y no lo comprueba no es un metodo, es un deseo.
#
# ASI QUE AQUI SE COMPRUEBA SOLO. Se le da un documento de ideas y por cada una corre siete filtros
# que salen, uno por uno, de los nueve fallos de verdad. No opina sobre si la idea es buena: solo
# dice "esto huele a que ya esta hecho, aqui tienes la linea". La prueba va pegada SIEMPRE, porque
# un veredicto sin la linea que lo sostiene es justo lo que fallo.
#
# LOS SIETE FILTROS Y DE QUE CAIDA SALE CADA UNO:
#
#   F1 numero-ya-escrito   El numero que citas como prueba ya esta escrito en un comentario del
#                          repo Y EN UNA LINEA QUE HABLA DE LO MISMO -> alguien ya lo midio.
#                          CASO 17: mis "756 lineas" estaban en assistant.ps1:24520.
#   F2 dato-de-antes       El dato esta concentrado en pocos dias y TODOS anteriores al commit que
#                          toco esa zona. CASO 17 otra vez: las 756 son todas del 26/09 y el
#                          arreglo es del 27/09. Tambien los CASOS 13 y 15.
#   F3 si-tiene-lectores   Dices "no se usa / no decide nada" de algo que tiene llamadores.
#                          CASOS 12, 16 y 19: Get-FranjaMuerta tiene tres, Find-Propuesta tres.
#   F4 quien-lo-escribe    El sitio donde se ESCRIBE el contador que citas, con su comentario.
#                          CASO 5: 'parakeet-a-whisper' no son fallos, es el repaso. Lo decia el
#                          comentario de al lado.
#   F5 apagado-a-proposito El ajuste esta a vacio/false/0 en config.json: se apago a mano y el
#                          motivo suele estar escrito. CASO 6: nubeOir = ''.
#   F6 frase-ya-dicha      La frase que propones que Nova diga, ya la dice -y la linea donde sale
#                          es una SALIDA suya, no un ejemplo de un banco-. CASO 14.
#   F7 banco-que-lo-cubre  Hay un banco cuyo encabezado comparte palabras RARAS con la idea. Si
#                          existe el banco, existe la funcion: la senal mas barata que hay.
#
# POR QUE TODOS LOS FILTROS EXIGEN "PALABRAS RARAS": la primera version de esto marco 19 ideas de
# 20, o sea que no servia para nada -un detector que dice si a todo-. El 609, el 100 y el 158
# aparecen en comentarios que no tienen nada que ver, y 'probar-acuerdo-oidos' comparte tres
# palabras comunes con casi cualquier idea. Una palabra que sale en mas de CIEN lineas del codigo
# no distingue nada, asi que no cuenta para emparejar.
#
# COMO SE LEE LA SALIDA: "FUERTE" es casi seguro que la idea esta muerta (F1, F2, F5, F6). "MIRA"
# es que hay algo que leer antes de proponerla (F3, F4, F7). Una idea sin ninguna marca no es
# buena: es solo una idea que estos siete filtros no pueden tumbar.
#
# --hasta=AAAA-MM-DD mira el repo COMO ESTABA ese dia. Para medir la criba con un documento viejo
# hay que hacerlo asi, o se compara contra los arreglos que salieron DE ese documento y todo sale
# marcado (es lo primero que paso).
#
# TODO EN ASCII, y a proposito: la consola de Windows en cp1252 se come los acentos y la salida de
# una herramienta que se lee a ojo no puede depender de la pagina de codigos.
import io
import json
import os
import re
import subprocess
import sys
import unicodedata

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HASTA = None       # None = el repo de ahora; 'AAAA-MM-DD' = como estaba ese dia
REV = None


def git(args):
    try:
        p = subprocess.Popen(['git'] + args, cwd=RAIZ, stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        out, _ = p.communicate()
        return out.decode('utf-8', 'replace')
    except Exception:
        return ''


def leer(ruta):
    """El fichero, del disco o de la revision que se pidio con --hasta."""
    if REV:
        t = git(['show', '%s:%s' % (REV, ruta.replace('\\', '/'))])
        if t:
            return t.lstrip(u'﻿')
    try:
        with io.open(os.path.join(RAIZ, ruta), encoding='utf-8-sig', errors='replace') as f:
            return f.read()
    except Exception:
        return ''


def ficheros_de(carpeta, exts):
    if REV:
        salida = git(['ls-tree', '--name-only', '%s:%s' % (REV, carpeta)]).split('\n')
    else:
        d = os.path.join(RAIZ, carpeta)
        salida = sorted(os.listdir(d)) if os.path.isdir(d) else []
    return [n.strip() for n in salida if n.strip().endswith(exts)]


def ascii_seguro(s):
    """Para IMPRIMIR: la consola de Windows va en cp1252 y un caracter raro del documento mata el
    proceso entero con UnicodeEncodeError. Paso al cribar IDEAS-AUTONOMIA-121 por un '∿'."""
    try:
        return s.encode('ascii', 'replace').decode('ascii')
    except Exception:
        return '?'


def soso(s):
    """Sin acentos, sin comillas raras y en minuscula: para comparar frases de verdad."""
    s = s.replace(u'’', "'").replace(u'“', '"').replace(u'”', '"')
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'\s+', ' ', s).strip().lower()


# ----------------------------------------------------------------- palabras raras
# Una palabra que sale en mas de CIEN lineas de assistant.ps1 no distingue nada. Sin esto, la
# criba empareja cualquier idea con cualquier comentario y marca las veinte.
COMUNES_TOPE = 100
_frecuencia = {}


def rara(p):
    if len(p) < 5:
        return False
    return _frecuencia.get(p, 0) <= COMUNES_TOPE


def palabras(texto):
    return set(re.findall(r'[a-z]{5,}', soso(texto)))


def raras(texto):
    return set(p for p in palabras(texto) if rara(p))


# ------------------------------------------------------------------ el material
FUENTES = {}
PS1 = ''
PS1_LIN = []
LOG_LIN = []
CONTADORES = {}
AJUSTES = {}
BANCOS = {}


def cargar():
    global PS1, PS1_LIN, LOG_LIN, CONTADORES, AJUSTES, BANCOS, _frecuencia
    FUENTES['assistant.ps1'] = leer('assistant.ps1')
    for n in ficheros_de('tools', ('.ps1', '.py')):
        if n != 'criba-ideas.py':
            FUENTES['tools/' + n] = leer('tools/' + n)
    PS1 = FUENTES.get('assistant.ps1', '')
    PS1_LIN = PS1.split('\n')

    _frecuencia = {}
    for linea in PS1_LIN:
        for p in set(re.findall(r'[a-z]{5,}', soso(linea))):
            _frecuencia[p] = _frecuencia.get(p, 0) + 1

    # EL REGISTRO SIEMPRE DEL DISCO: es un fichero de datos, no de codigo, y la version de hace
    # dos dias no existe en git (esta ignorado). Lo que --hasta cambia es el CODIGO.
    try:
        with io.open(os.path.join(RAIZ, 'assistant.log'), encoding='utf-8-sig',
                     errors='replace') as f:
            LOG_LIN = f.read().split('\n')
    except Exception:
        LOG_LIN = []

    try:
        st = json.loads(leer('memoria/estadisticas.json') or '{}')
    except Exception:
        st = {}
    CONTADORES = {}
    for fecha, h in (st.get('dias') or {}).items():
        if isinstance(h, dict):
            for k, v in h.items():
                try:
                    CONTADORES.setdefault(k, {})[fecha] = int(v)
                except Exception:
                    pass

    try:
        cfg = json.loads(leer('config.json') or '{}')
    except Exception:
        cfg = {}
    AJUSTES.clear()

    def _plano(o, ruta):
        if isinstance(o, dict):
            for k, v in o.items():
                _plano(v, ruta + [k])
        else:
            AJUSTES['.'.join(ruta)] = o
            AJUSTES.setdefault(ruta[-1], o)
    _plano(cfg, [])

    global FRASES_NOVA
    BANCOS.clear()
    for nombre, txt in FUENTES.items():
        if nombre.startswith('tools/probar-'):
            cab = nombre[len('tools/probar-'):] + ' ' + '\n'.join(txt.split('\n')[:16])
            BANCOS[nombre] = raras(cab)
    FRASES_NOVA = _catalogo_frases()
    ORDENES[:] = _catalogo_ordenes()


# Lo que se dice para negar que algo se use. Si una idea dice esto Y nombra una funcion con
# llamadores, el filtro 3 salta. Sale de como estaban escritas las caidas 12, 16 y 19.
NEGACIONES = [u'no decide nada', u'no se usa', u'no lo usa nadie', u'no lo lee nadie',
              u'nadie lo lee', u'nadie la lee', u'no se lee', u'no sirve para nada',
              u'no se aprovecha', u'no aprovecha', u'nunca ha ', u'no se mira',
              u'no lo mira', u'sin lector', u'no hace nada con', u'no decide',
              u'no se reconoce', u'no lo reconoce', u'no sabe que', u'no se da cuenta',
              u'no avisa', u'no lo dice', u'no dice nada', u'nunca propone',
              u'no se entera', u'no lo sabe']

# Senales de que la linea del codigo es algo que Nova DICE, no un ejemplo de un banco ni una
# orden de braya. Sin esto, F6 marcaba "cuando abra elden ring pon modo noche" -que la dice
# braya- como si Nova ya la dijera.
SALIDA = ('return', 'decir', 'set-ui', 'frase', 'texto =', 'msg', 'responde', 'aviso',
          'send-', 'habla', '+ "', '= "')


# ------------------------------------------------------------- partir el documento
def ideas_de(texto):
    """Devuelve [(numero, titulo, cuerpo)] de un IDEAS-*.md."""
    salida = []
    actual = None
    for linea in texto.split('\n'):
        m = re.match(r'^###\s+(\d+)\.\s*(.+?)\s*$', linea)
        if m:
            if actual:
                salida.append(actual)
            actual = [int(m.group(1)), m.group(2), []]
            continue
        if re.match(r'^##\s+\S', linea) and actual:
            salida.append(actual)
            actual = None
            continue
        if actual:
            actual[2].append(linea)
    if actual:
        salida.append(actual)
    return [(n, t, '\n'.join(c)) for n, t, c in salida]


def numeros_de(cuerpo):
    """Los numeros que la idea usa COMO PRUEBA. Solo de 100 arriba: por debajo salen por
    casualidad en cualquier sitio (el 28 aparece 181 veces en el codigo) y el filtro se
    volveria ruido. Se quitan los anios, las horas y los ids largos de fecha."""
    t = re.sub(r'\b20\d{6}-\d{6}\b', ' ', cuerpo)      # ids del corpus de uso
    t = re.sub(r'\b20\d\d-\d\d-\d\d\b', ' ', t)        # fechas
    t = re.sub(r'\b\d{1,2}:\d\d\b', ' ', t)            # horas
    t = re.sub(r'\b\d\d?/\d\d?\b', ' ', t)             # 26/09
    vistos = []
    for m in re.finditer(r'\b(\d{1,3}(?:\.\d{3})+|\d{3,})\b', t):
        n = int(m.group(1).replace('.', ''))
        if n in (2026, 2025) or n < 100:
            continue
        # LOS NUMEROS REDONDOS NO SON HUELLAS. El 100, el 200, el 1.000 salen en cualquier
        # comentario del repo por casualidad: con el 100 esto marcaba la idea 1 contra una nota
        # sobre el contador de rendimiento que no tenia nada que ver.
        if n % 100 == 0 and n <= 2000:
            continue
        if n not in vistos:
            vistos.append(n)
    return vistos


def funciones_de(cuerpo):
    return sorted(set(re.findall(r'\b((?:Get|Set|Test|New|Find|Add|Send|Save|Start|Stop|Write|'
                                 r'Read|Invoke|Clear|Receive|Request|Process|Watch|Restore|'
                                 r'Update|Show|Measure)-[A-Z][A-Za-z0-9]+)\b', cuerpo)))


def contadores_de(cuerpo):
    cand = set(re.findall(r'`([^`\n]{2,48})`', cuerpo))
    cand |= set(re.findall(r"'([a-z][a-z0-9:_-]{2,40})'", cuerpo))
    return sorted(c for c in cand if c in CONTADORES)


def ajustes_de(cuerpo):
    cand = set(re.findall(r'`([A-Za-z][A-Za-z0-9.]{2,48})`', cuerpo))
    return sorted(c for c in cand if c in AJUSTES)


DECIR = ('decir', 'diga', 'dir', 'avis', 'cont', 'suelt', 'hable', 'respond', 'suger',
         'propon', 'anunci', 'coment')


def frases_de(cuerpo):
    """Lo que la idea propone que Nova DIGA, y solo eso.

    AQUI ESTABA EL SEGUNDO FALSO FUERTE: la idea 11 citaba *"no pude pintar la tarjeta"* como
    SINTOMA -lo que Nova dice cuando falla- y el filtro la leyo como la frase propuesta, asi
    que la condeno por "eso ya lo dice". Pues claro que lo dice: la idea era arreglarlo. Se
    exige que la frase venga detras de un verbo de decir, o del bloque de la propuesta."""
    fuera = []
    for m in re.finditer(u'“([^”\n]{12,160})”|\\*"([^"\n]{12,160})"\\*'
                         u'|"([^"\n]{12,160})"', cuerpo):
        f = (m.group(1) or m.group(2) or m.group(3) or '').strip()
        if len(f.split()) < 4 or f.startswith('`') or f in fuera:
            continue
        antes = soso(cuerpo[max(0, m.start() - 90):m.start()])
        propuesta = 'que hacer' in soso(cuerpo[:m.start()])[-700:]
        if any(v in antes for v in DECIR) or propuesta:
            fuera.append(f)
    return fuera[:6]


def patrones_log_de(cuerpo):
    """Trozos de texto que la idea cita del registro, para datarlos."""
    cand = []
    for m in re.findall(r'`([^`\n]{10,90})`', cuerpo):
        if m in CONTADORES or m in AJUSTES:
            continue
        trozos = [x.strip() for x in re.split(r'<[^>]*>|\[[^\]]*\]|\.\.\.|\{[^}]*\}', m)]
        trozos = [x for x in trozos if len(x) >= 10]
        if trozos:
            cand.append(max(trozos, key=len))
    return cand[:4]


# ------------------------------------------------------------------- los filtros
def f1_numero_ya_escrito(titulo, cuerpo):
    """El numero solo no vale: tiene que aparecer en una linea que hable DE LO MISMO. Sin esa
    exigencia esto marcaba el 609 de una idea de Parakeet contra un comentario sobre la palabra
    'este', y marcaba las veinte ideas."""
    tema = raras(titulo + ' ' + cuerpo[:700])
    avisos = []
    for n in numeros_de(cuerpo)[:8]:
        pat = re.compile(r'(?<![\d.])(%d|%s)(?![\d.])'
                         % (n, '{:,}'.format(n).replace(',', r'\.')))
        hecho = False
        for nombre, txt in FUENTES.items():
            if hecho or not txt:
                continue
            for i, linea in enumerate(txt.split('\n')):
                if not pat.search(linea):
                    continue
                if not (linea.lstrip().startswith('#') or nombre.startswith('tools/probar-')):
                    continue
                # DOS PALABRAS RARAS, NO UNA: con una sola, el 375 de una idea sobre el corpus
                # se emparejaba con un comentario sobre Elden Ring porque los dos decian
                # "elden". Una coincidencia es coincidencia; dos ya es el mismo tema.
                comun = tema & raras(linea)
                if len(comun) < 2:
                    continue
                avisos.append((u'FUERTE', u'F1 numero-ya-escrito',
                               u'el %d que citas ya esta medido aqui (%s)'
                               % (n, ', '.join(sorted(comun)[:3])),
                               u'%s:%d: %s' % (nombre, i + 1, linea.strip()[:112])))
                hecho = True
                break
    return avisos


def f2_dato_de_antes(cuerpo):
    """La comprobacion que mas duele, y la que caza el caso 17 sola: si el dato esta CONCENTRADO
    en pocos dias y todos son anteriores al commit que toco esa zona, la idea esta describiendo
    un problema ya arreglado. La concentracion importa: un contador que lleva veinte dias
    subiendo esta vivo, aunque el codigo se tocara ayer."""
    avisos = []
    # SOLO EL DATO PRINCIPAL, el de la primera parte de la idea. El otro falso FUERTE salio de
    # aqui: la idea 9 citaba 'disco-poco' como UNO de varios ejemplos, ese ejemplo era de un
    # episodio de dos dias del 24/09, y la criba tumbo la idea entera por el ejemplo. El dato
    # que sostiene una idea esta donde se enuncia, no en la lista de casos.
    cabeza = cuerpo[:420]
    terminos = [(c, 'contador') for c in contadores_de(cabeza)]
    terminos += [(p, 'log') for p in patrones_log_de(cabeza)]
    for termino, clase in terminos[:6]:
        if clase == 'contador':
            cuenta = CONTADORES.get(termino, {})
            dias = sorted(d for d, v in cuenta.items() if v > 0)
            total = sum(cuenta.values())
        else:
            hits = [l for l in LOG_LIN if termino in l and re.match(r'^20\d\d-\d\d-\d\d', l)]
            dias = sorted(set(l[:10] for l in hits))
            total = len(hits)
        if not dias or len(dias) > 3:          # repartido en muchos dias = sigue vivo
            continue
        # Y GRANDE: la firma de "episodio puntual ya arreglado" son las 756 lineas de un solo
        # dia. Un contador con 12 apariciones en dos dias no prueba nada, y marcarlo convertia
        # en FUERTE una idea que era buena (la 9, por 'disco-poco').
        if total < 100:
            continue
        # Y SE PRUEBAN TROZOS MAS CORTOS, que es lo que hacia fallar el caso 17 entero: en el
        # registro el texto sale seguido ("charla: diario: no pude resumir lo del 26/09") pero en
        # el codigo esta partido por el salto de un comentario, asi que git -S no lo encontraba.
        # "no pude resumir" si, y da el commit del 27/09 que es el que tumba la idea.
        pal = termino.split()
        intentos = [termino]
        for largo in (4, 3):
            for i in range(0, max(1, len(pal) - largo + 1)):
                trozo = ' '.join(pal[i:i + largo])
                if len(trozo) >= 14 and trozo not in intentos:
                    intentos.append(trozo)
        commit = ''
        for cand in intentos[:7]:
            args = ['log', '-1', '--format=%ad', '--date=short', '-S', cand]
            if HASTA:
                args.append('--until=%sT23:59:59' % HASTA)
            commit = git(args + ['--', 'assistant.ps1']).strip()
            if re.match(r'^20\d\d-\d\d-\d\d$', commit or ''):
                break
            commit = ''
        if not commit:
            continue
        if dias[-1] < commit:
            # UN SOLO DATO MATA; UNO DE VARIOS, NO. Si la idea enuncia tres o cuatro contadores
            # es una LISTA DE EJEMPLOS -la idea 9 nombraba tres avisos que no sirven-, y que uno
            # de ellos sea un episodio viejo no tumba la idea: solo obliga a mirarla.
            nivel = u'FUERTE' if len(terminos) <= 2 else u'MIRA'
            avisos.append((nivel, u'F2 dato-de-antes',
                           u'el dato de "%s" es de ANTES del arreglo' % termino[:40],
                           u'dato: %s (%d dia%s)  |  commit que lo toca: %s'
                           % ('..'.join(sorted(set([dias[0], dias[-1]]))), len(dias),
                              '' if len(dias) == 1 else 's', commit)))
    return avisos


def f3_si_tiene_lectores(cuerpo):
    bajo = soso(cuerpo)
    niega = [n for n in NEGACIONES if soso(n) in bajo]
    if not niega:
        return []
    avisos = []
    for fn in funciones_de(cuerpo)[:6]:
        lineas = [i + 1 for i, l in enumerate(PS1_LIN)
                  if re.search(r'\b%s\b' % re.escape(fn), l) and not l.lstrip().startswith('#')]
        if len(lineas) >= 2:
            avisos.append((u'MIRA', u'F3 si-tiene-lectores',
                           u'dices "%s" pero %s se usa en %d sitios'
                           % (niega[0].strip(), fn, len(lineas)),
                           u'assistant.ps1 lineas %s'
                           % (', '.join(str(x) for x in lineas[:8]))))
    return avisos


def f4_quien_lo_escribe(cuerpo):
    """El contador que citas: quien lo escribe y QUE DICE el comentario de al lado. Aqui no hay
    veredicto, hay deberes: la caida 5 fue leer el nombre del contador y no su significado."""
    avisos = []
    for c in contadores_de(cuerpo)[:4]:
        pat = re.compile(r"Add-Estadistica\s+.{0,40}%s" % re.escape(c))
        for i, linea in enumerate(PS1_LIN):
            if not pat.search(linea):
                continue
            ctx = [PS1_LIN[j].strip().lstrip('#').strip()
                   for j in range(max(0, i - 14), i) if PS1_LIN[j].lstrip().startswith('#')]
            avisos.append((u'INFO', u'F4 quien-lo-escribe',
                           u"que significa de verdad '%s'" % c,
                           u'assistant.ps1:%d  %s'
                           % (i + 1, (' / '.join(ctx[-2:]))[:140] or linea.strip()[:112])))
            break
    return avisos


def f5_apagado_a_proposito(cuerpo):
    avisos = []
    for a in ajustes_de(cuerpo)[:6]:
        v = AJUSTES.get(a)
        if v == '' or v is False or v == 0:
            donde = [i + 1 for i, l in enumerate(PS1_LIN) if a.split('.')[-1] in l][:3]
            avisos.append((u'FUERTE', u'F5 apagado-a-proposito',
                           u'%s esta a %r en config.json: se apago a mano' % (a, v),
                           u'el motivo suele estar en assistant.ps1 lineas %s'
                           % (', '.join(str(x) for x in donde) or '(ninguna)')))
    return avisos


def f6_frase_ya_dicha(cuerpo):
    """Y la linea tiene que ser una SALIDA de Nova. Sin eso, esto marcaba una orden que dice
    BRAYA ('cuando abra elden ring pon modo noche') como si Nova ya la dijera."""
    avisos = []
    for f in frases_de(cuerpo):
        pal = soso(f).split()
        for largo in (len(pal), 7, 6, 5):
            if largo > len(pal):
                continue
            nucleo = ' '.join(pal[:largo])
            if len(nucleo) < 20:
                continue
            golpe = None
            for k, l in enumerate(PS1_LIN):
                if nucleo in soso(l):
                    bajo = soso(l)
                    if any(s in bajo for s in SALIDA):
                        golpe = k + 1
                    break
            if golpe:
                avisos.append((u'FUERTE', u'F6 frase-ya-dicha',
                               u'Nova ya dice eso: "%s"' % nucleo[:70],
                               u'assistant.ps1:%d' % golpe))
                break
    return avisos


def _catalogo_frases():
    """Todo lo que Nova PUEDE DECIR: las cadenas literales de cinco palabras o mas que salen de
    un return, un Decir, un Set-UI o un aviso. Es el filtro que faltaba: la idea 14 proponia
    "hoy te he entendido peor que de costumbre" y Nova ya decia "Hoy te estoy entendiendo peor
    de lo normal" -misma cosa, otras palabras-, asi que buscarla literal no la encontraba."""
    fuera = []
    for i, linea in enumerate(PS1_LIN):
        if linea.lstrip().startswith('#'):
            continue
        bajo = soso(linea)
        if not any(s in bajo for s in SALIDA):
            continue
        for cad in re.findall(r'"([^"\n]{20,220})"', linea) + re.findall(r"'([^'\n]{20,220})'",
                                                                        linea):
            if len(cad.split()) >= 5 and not re.match(r'^[A-Za-z0-9_.:\\/-]+$', cad):
                fuera.append((i + 1, cad))
    return fuera


FRASES_NOVA = []


def _prefijos(frase):
    return set(p[:5] for p in re.findall(r'[a-z]{4,}', soso(frase)))


def f8_frase_parecida(cuerpo):
    """Parecido por RAIZ, no por letra: 'entendido' y 'entendiendo' comparten 'enten'. Se exige
    que coincidan tres de cada cinco raices y al menos dos raras, para no emparejar dos frases
    solo porque las dos digan 'hoy' y 'veces'."""
    avisos = []
    for f in frases_de(cuerpo):
        pf = _prefijos(f)
        if len(pf) < 3:
            continue
        mejor = None
        for lin, cad in FRASES_NOVA:
            pc = _prefijos(cad)
            comun = pf & pc
            if not comun:
                continue
            parte = float(len(comun)) / len(pf)
            rarasComunes = set(p for p in comun
                               if not any(_frecuencia.get(q, 0) > COMUNES_TOPE
                                          for q in (p,)))
            if parte >= 0.6 and len(rarasComunes) >= 2:
                if not mejor or parte > mejor[0]:
                    mejor = (parte, lin, cad)
        if mejor:
            avisos.append((u'FUERTE', u'F8 frase-parecida',
                           u'Nova ya dice casi eso (%d%% de las raices)' % int(mejor[0] * 100),
                           u'assistant.ps1:%d: "%s"' % (mejor[1], mejor[2][:96])))
    return avisos


ORDENES = []


def _catalogo_ordenes():
    """Los 483 regex con los que Nova reconoce una orden. Son el catalogo EJECUTABLE de lo que
    entiende, y por eso este filtro no puede mentir: o la frase casa o no casa.

    DE DONDE SALE: el 1/10, proponiendo las 40 ideas, di por nuevas dos cosas que ya existian
    -"que cancion suena" (linea 6008) y "donde lo deje" (linea 6093)- porque grep me devolvia UNA
    sola mencion y lo lei como "casi no existe". Una funcion implementada una vez tiene exactamente
    una mencion: la de su implementacion. Contar menciones no sirve; probar la frase si."""
    fuera = []
    for i, linea in enumerate(PS1_LIN):
        if linea.lstrip().startswith('#'):
            continue
        for m in re.finditer(r"-match\s+'(\^[^']{6,400})'", linea):
            pat = m.group(1)
            try:
                # PowerShell y Python comparten la sintaxis que se usa aqui: (?:...), |, \b, $.
                rx = re.compile(pat, re.IGNORECASE)
            except re.error:
                continue
            # LOS PATRONES GENERICOS NO VALEN COMO PRUEBA. En el fichero hay troceadores como
            # '^(\\S+)\\s+(?:(el|la|lo)\\s+)?(\\S+)(.*)$' que casan con CUALQUIER par de palabras:
            # con ellos dentro, este filtro diria que Nova ya entiende todo. Si casa con tres
            # palabras inventadas, no distingue nada y se tira.
            if any(rx.match(x) for x in ('zzqq wwxx vvuu', 'qqq zzz', 'xkcd plugh xyzzy')):
                continue
            fuera.append((i + 1, pat, rx))
    return fuera


def _frases_sueltas(cuerpo):
    """Las frases que la idea pone como ejemplo de lo que braya diria: entre comillas, cortas y
    sin signos de codigo. No se filtran por verbo de decir como en F6/F8, al contrario: aqui
    interesan justo las que braya PEDIRIA."""
    cand = []
    for pat in (u'«([^»\n]{6,70})»', u'“([^”\n]{6,70})”',
                r'\*"([^"\n]{6,70})"\*', r'"([^"\n]{6,70})"'):
        for f in re.findall(pat, cuerpo):
            f = f.strip().strip('?!.,;:').strip()
            f = re.sub(u'^[¿¡]+', '', f)
            # TIENE QUE PARECER UNA ORDEN DE BRAYA, no cualquier cosa entre comillas: sin numeros,
            # sin markdown, sin mayusculas en medio y corta. Sin esto, el filtro le pasaba al
            # catalogo trozos como "y lleva 20,2 dias sin tocarse" o "SORDA N s: SORDA N s".
            if not (2 <= len(f.split()) <= 7):
                continue
            if re.search(r'[0-9${}()\[\]\\|=<>*:;%]', f):
                continue
            if re.search(r'[a-z]\s+[A-Z]', f) or f.upper() == f:
                continue
            if f not in cand:
                cand.append(f)
    return cand[:10]


def f9_orden_ya_entendida(cuerpo):
    """Se le pasa la frase a los 483 regex de verdad. Si alguno casa, Nova YA entiende eso."""
    avisos = []
    for f in _frases_sueltas(cuerpo):
        seca = soso(f)
        # EL COMODIN NO PRUEBA NADA, y es lo que hacia que este filtro marcara "modo susurro" o
        # "por que has", que yo mismo acababa de comprobar con grep que NO existen. Hay patrones
        # del tipo '^modo\s+(.+)$' que casan con cualquier "modo X": reconocen la FORMA, no esa
        # orden. Se cambia la ultima palabra por una inventada; si sigue casando, es un comodin.
        pal = seca.split()
        falsa = ' '.join(pal[:-1] + ['zqwxvu'])
        otra = ' '.join(['zqwxvu'] + pal[1:])
        for lin, pat, rx in ORDENES:
            if rx.match(seca) and not rx.match(falsa) and not rx.match(otra):
                avisos.append((u'FUERTE', u'F9 orden-ya-entendida',
                               u'Nova ya entiende "%s"' % f[:50],
                               u'assistant.ps1:%d: %s' % (lin, pat[:96])))
                break
    return avisos[:3]


def f7_banco_que_lo_cubre(titulo, cuerpo):
    """Si existe un banco del tema, existe la funcion. Con palabras RARAS: con palabras comunes,
    'probar-acuerdo-oidos' se emparejaba con casi cualquier idea."""
    tema = raras(titulo + ' ' + cuerpo[:500])
    marcas = []
    for nombre, cab in BANCOS.items():
        comun = tema & cab
        if len(comun) >= 3:
            marcas.append((len(comun), nombre, sorted(comun)))
    marcas.sort(reverse=True)
    return [(u'MIRA', u'F7 banco-que-lo-cubre',
             u'ya hay un banco que habla de esto (%s)' % ', '.join(c[:4]), n)
            for _, n, c in marcas[:2]]


def criba(titulo, cuerpo):
    return (f1_numero_ya_escrito(titulo, cuerpo) + f2_dato_de_antes(cuerpo)
            + f3_si_tiene_lectores(cuerpo) + f4_quien_lo_escribe(cuerpo)
            + f5_apagado_a_proposito(cuerpo) + f6_frase_ya_dicha(cuerpo)
            + f8_frase_parecida(cuerpo)
            + f9_orden_ya_entendida(titulo + chr(10) + cuerpo)
            + f7_banco_que_lo_cubre(titulo, cuerpo))


def main():
    global HASTA, REV
    args = []
    solo = None
    callado = False
    for a in sys.argv[1:]:
        if a.startswith('--hasta='):
            HASTA = a.split('=', 1)[1]
        elif a.startswith('--idea='):
            solo = int(a.split('=', 1)[1])
        elif a == '--corto':
            callado = True
        elif not a.startswith('--'):
            args.append(a)
    if not args:
        print('uso: python tools/criba-ideas.py IDEAS-xxxx.md [--hasta=AAAA-MM-DD] [--idea=N]')
        return 2
    if HASTA:
        REV = git(['rev-list', '-1', '--until=%sT23:59:59' % HASTA, 'main']).strip()
        if not REV:
            print('no encuentro ninguna version hasta ' + HASTA)
            return 2
    cargar()
    texto = leer(args[0])
    if not texto:
        try:
            with io.open(os.path.join(RAIZ, args[0]), encoding='utf-8-sig',
                         errors='replace') as f:
                texto = f.read()
        except Exception:
            print('no puedo leer ' + args[0])
            return 2
    ideas = ideas_de(texto)
    print('')
    print('CRIBA DE %s: %d ideas' % (args[0], len(ideas)))
    if REV:
        print('mirando el repo como estaba el %s (%s)' % (HASTA, REV[:9]))
    print('')
    fuertes, marcadas = [], []
    for n, t, c in ideas:
        if solo is not None and n != solo:
            continue
        av = criba(t, c)
        hayF = any(x[0] == u'FUERTE' for x in av)
        print(ascii_seguro('%s %2d. %s' % ('FUERTE ' if hayF else ('mira   ' if av else 'pasa   '),
                                           n, t[:86])))
        if not callado:
            for nivel, filtro, que, prueba in av:
                print(ascii_seguro('        %-7s %-22s %s' % (nivel, filtro, que)))
                print(ascii_seguro('                %s' % prueba))
            if av:
                print('')
        if av:
            marcadas.append(n)
        if hayF:
            fuertes.append(n)
    print('')
    print('-' * 78)
    print('FUERTE (casi seguro ya hecho): %d  %s' % (len(fuertes), fuertes))
    print('alguna marca                 : %d de %d' % (len(marcadas), len(ideas)))
    print('')
    print('Una idea sin marca no es buena: es una que estos siete filtros no pueden tumbar.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
