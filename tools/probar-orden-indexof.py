# QUE NINGUN BANCO COMPARE EL ORDEN DE DOS COSAS SIN EXIGIR QUE LAS DOS ESTEN (la manera 18)
#
# IndexOf devuelve -1 cuando no encuentra, y -1 es MENOR que cualquier indice valido. Asi que
#
#     Comp 'el empuje va ANTES de decidir' ($iEmpuje -lt $iDecide) ''
#
# sale en VERDE justo cuando ha dejado de ver lo que vigila. Paso de verdad el 30/09 en
# probar-umbrales y en probar-brillo-y-disco, y los dos llevaban dias mintiendo.
#
# ESTA COMPROBACION NO ES UN BANCO MAS: VIGILA A LOS BANCOS, como las secciones 7 y 9 de la
# bateria. Recorre assistant.ps1 y los ~300 bancos de tools, encuentra las comparaciones de orden
# entre dos indices venidos de IndexOf, y exige que el lado PELIGROSO este cubierto.
#
# CUAL ES EL LADO PELIGROSO, que es la mitad del asunto: en una condicion de EXITO, el peligro esta
# donde un -1 la vuelve VERDADERA.
#     A -lt B   ->  con A = -1 sale verdadera. El peligroso es A.
#     A -gt B   ->  con B = -1 sale verdadera. El peligroso es B.
# Siempre uno de los dos, nunca los dos.
#
# Y SE RECONOCEN TRES FORMAS DE CUBRIRLO, porque si no el banco pide cambiar codigo que ya esta
# bien -y un banco que pide cambios inutiles se acaba desactivando-:
#   1. a la cara:      '$iA -ge 0', '$iA -gt 0', '$iA -ne -1'
#   2. por CADENA:     '$iA -ge 0 -and $iB -gt $iA -and $iC -gt $iB'  cubre a los tres, porque si
#                      $iC fuera -1, '-1 -gt $iB' es falso y la linea sale ROJA, que es lo correcto
#   3. con el SENTIDO INVERTIDO: 'if ($iA -lt 0 -or $iB -le $iA) { ...MAL... }' -ahi un -1 cae en la
#                      rama del error, o sea que el banco ya se queja-
#
# MEDIDO AL ESCRIBIRLO (1/10/2026): 82 comparaciones de orden en el proyecto, 73 cubiertas y SEIS
# que no -en probar-otro-oido, probar-trivia (dos), probar-exe-de-juego, probar-lupa y
# probar-volumen-juego-. Arregladas las seis, quedan 82 de 82.
import re
import io
import os
import sys
import glob

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# una variable que sale de un IndexOf: '$iA = $algo.IndexOf(' o '$iA = [algo]::...IndexOf('
RE_IDX = re.compile(r'\$(\w+)\s*=\s*(?:\$\w+|\[[^\]]+\])(?:\.\w+)*\.IndexOf\(')
RE_CMP = re.compile(r'\$(\w+)\s+-(lt|gt|le|ge)\s+\$(\w+)')
RE_NONEG = r'\$%s\s+-(?:ge|gt)\s+(?:0|1)\b'
RE_NE1 = r'\$%s\s+-ne\s+-1\b'
RE_LT0 = r'\$%s\s+-lt\s+0\b'

mal = []
total = 0
cubiertas = 0


def no_negativos(contexto, deIndexOf):
    """Que indices se sabe que NO son -1 en este contexto, incluida la cadena."""
    seguros = set()
    for v in deIndexOf:
        if (re.search(RE_NONEG % re.escape(v), contexto) or
                re.search(RE_NE1 % re.escape(v), contexto) or
                re.search(RE_LT0 % re.escape(v), contexto)):
            seguros.add(v)
    # LA CADENA, hasta que no crezca mas: si X -gt Y y Y ya es seguro, X tambien lo es, porque
    # X > Y >= 0. Esto es lo que salva '$iIf -ge 0 -and $iRet -gt $iIf -and $iApp -gt $iRet'.
    for _ in range(6):
        antes = len(seguros)
        for m in RE_CMP.finditer(contexto):
            a, op, b = m.group(1), m.group(2), m.group(3)
            if op in ('gt', 'ge') and b in seguros:
                seguros.add(a)
            elif op in ('lt', 'le') and a in seguros:
                seguros.add(b)
        if len(seguros) == antes:
            break
    return seguros


# EL SENTIDO INVERTIDO: 'if ($iA -lt 0 -or $jA -le $iA) { ...MAL...; exit 1 }'. Ahi la condicion no
# es de EXITO sino de FALLO, asi que un -1 que la vuelve verdadera hace lo correcto: cae en la rama
# del error y el banco se queja. El lado peligroso se da la vuelta.
RE_FALLO = re.compile(r"\bexit 1\b|\$(?:script:)?(?:mal|fallos)\+\+|'  MAL|\"  MAL")


def lado_peligroso(a, op, b, linea):
    invertida = bool(linea.lstrip().startswith('if (') and RE_FALLO.search(linea))
    if op in ('lt', 'le'):
        return b if invertida else a
    return a if invertida else b


ficheros = [os.path.join(RAIZ, 'assistant.ps1')] + sorted(glob.glob(os.path.join(RAIZ, 'tools', '*.ps1')))
for f in ficheros:
    try:
        texto = io.open(f, encoding='utf-8', errors='replace').read()
    except Exception as e:
        print('  MAL  no pude leer %s (%s)' % (os.path.basename(f), type(e).__name__))
        mal.append((os.path.basename(f), 0, '', 'ilegible'))
        continue
    lineas = texto.split('\n')
    deIndexOf = set()
    for l in lineas:
        for m in RE_IDX.finditer(l):
            deIndexOf.add(m.group(1))
    if not deIndexOf:
        continue
    for n, l in enumerate(lineas, 1):
        s = l.lstrip()
        # los comentarios no deciden nada, y un 'for' lleva contadores, no indices de IndexOf
        if s.startswith('#') or 'for (' in l:
            continue
        for m in RE_CMP.finditer(l):
            a, op, b = m.group(1), m.group(2), m.group(3)
            if a not in deIndexOf or b not in deIndexOf:
                continue
            total += 1
            # el contexto son esta linea y las dos de arriba: una condicion partida en varias
            # lineas es corriente, y la guarda suele ir en la primera
            ctx = '\n'.join(lineas[max(0, n - 3):n])
            seguros = no_negativos(ctx, deIndexOf)
            peligroso = lado_peligroso(a, op, b, l)
            if peligroso in seguros:
                cubiertas += 1
            else:
                mal.append((os.path.basename(f), n, peligroso, s[:104]))

print('')
print('-- comparaciones de ORDEN entre dos indices de IndexOf --')
print('  %d en total, %d cubiertas' % (total, cubiertas))
# SI NO ENCUENTRA NINGUNA, EL DETECTOR ESTA ROTO, no es que el proyecto este limpio. Es la manera
# 13: un detector que no detecta sale verde por la razon equivocada.
if total < 40:
    print('  MAL  solo he encontrado %d comparaciones, y el 1/10 habia 82: el detector esta roto' % total)
    mal.append(('(el detector)', 0, '', 'encuentra demasiado poco'))

for f, n, v, l in mal:
    if n:
        print('  MAL  %s:%d  falta exigir que $%s no sea -1' % (f, n, v))
        print('         %s' % l)

# -- Y QUE EL DETECTOR DETECTE, con un caso escrito a proposito (manera 13) --
print('')
print('-- y el detector detecta --')
TRAMPA = """$iA = $texto.IndexOf('uno')
$iB = $texto.IndexOf('dos')
Comp 'A va antes que B' ($iA -lt $iB) ''
"""
BUENO = """$iA = $texto.IndexOf('uno')
$iB = $texto.IndexOf('dos')
Comp 'A va antes que B' ($iA -ge 0 -and $iB -ge 0 -and $iA -lt $iB) ''
"""
CADENA = """$iA = $texto.IndexOf('uno')
$iB = $texto.IndexOf('dos')
$iC = $texto.IndexOf('tres')
Comp 'en orden' ($iA -ge 0 -and $iB -gt $iA -and $iC -gt $iB) ''
"""


def revisa(fuente):
    lineas = fuente.split('\n')
    deIndexOf = set()
    for l in lineas:
        for m in RE_IDX.finditer(l):
            deIndexOf.add(m.group(1))
    fallos = 0
    for n, l in enumerate(lineas, 1):
        if l.lstrip().startswith('#') or 'for (' in l:
            continue
        for m in RE_CMP.finditer(l):
            a, op, b = m.group(1), m.group(2), m.group(3)
            if a not in deIndexOf or b not in deIndexOf:
                continue
            ctx = '\n'.join(lineas[max(0, n - 3):n])
            peligroso = lado_peligroso(a, op, b, l)
            if peligroso not in no_negativos(ctx, deIndexOf):
                fallos += 1
    return fallos


INVERTIDO = """$iA = $texto.IndexOf('uno')
$jA = $texto.IndexOf('dos')
if ($iA -lt 0 -or $jA -le $iA) { Write-Host '  MAL  no lo encuentro'; exit 1 }
"""
pruebas = [
    ('caza una comparacion desnuda', revisa(TRAMPA) == 1, revisa(TRAMPA)),
    ('  y no se queja de la que lleva su guarda', revisa(BUENO) == 0, revisa(BUENO)),
    ('  ni de la cadena, que ya se cubre sola', revisa(CADENA) == 0, revisa(CADENA)),
    ('  ni del sentido invertido, donde un -1 cae en el error', revisa(INVERTIDO) == 0, revisa(INVERTIDO)),
]
for nombre, ok, visto in pruebas:
    print('  %s  %-48s %s' % ('ok ' if ok else 'MAL', nombre, '' if ok else '(dio %s)' % visto))
    if not ok:
        mal.append(('(el detector)', 0, '', nombre))

print('')
if mal:
    print('%d MAL' % len(mal))
    sys.exit(1)
print('ningun banco decide el orden con un indice que podria ser -1')
sys.exit(0)
