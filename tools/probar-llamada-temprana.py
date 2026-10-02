# LLAMAR A UNA FUNCION ANTES DE QUE EXISTA: EL BARRIDO DE LA FAMILIA (2/10/2026)
#
# EL FALLO, dos veces en dos dias: en PowerShell una funcion NO EXISTE hasta que su linea 'function'
# se ejecuta. Si el ARRANQUE llama a algo definido mas abajo, la llamada falla con "El termino 'X' no
# se reconoce como nombre de un cmdlet" y, como casi todas van dentro de un try, un catch se lo traga
# sin que nada avise.
#
#   1/10  Show-Popup, definida en la 30244, la llamaban los avisos del arranque. Tres avisos
#         perdidos seguidos el 30/09 y el barrido de tmp muerto el 27/09.
#   2/10  Get-QuietudMando, definida en la 37359, la llamaba Get-NadieMin (17478). SIETE petes por
#         arranque, y de paso Nova daba por hecho que no habia nadie teniendo a braya delante con el
#         mando: 4.219 lineas 'ENTORNO aparcado'.
#
# Las dos las cazo el contador de petes CUATRO DIAS DESPUES. Este banco las caza en el sitio.
#
# COMO SE MIRA, que es lo unico que tiene gracia aqui: no basta con "se llama en una linea anterior a
# su definicion", porque el caso de ayer NO sale asi -la llamada esta DENTRO de otra funcion-. Lo que
# importa es el MOMENTO: cuando el arranque ejecuta su linea L, estan definidas exactamente las
# funciones cuyo 'function' esta antes de L. Asi que:
#
#   1. se marcan las lineas del CUERPO PRINCIPAL (fuera de toda funcion) hasta el 'while ($true)';
#   2. de cada una se saca a quien llama, y eso da pares (linea L, funcion F);
#   3. se cierra transitivamente: lo que llame F tambien se ejecuta en el momento L;
#   4. y se exige def(G) < L para todo G alcanzable desde la linea L.
#
# EL TRINQUETE, Y POR QUE: el analisis es estatico y conservador -una funcion puede tener una rama
# que solo corre en el bucle, y aqui cuenta igual-, asi que hay casos que NO son fallos. En vez de
# mantener una lista de excusas a mano (que es como se acaba desactivando un banco), se guarda la
# CUENTA en tools\tempranas-techo.txt y solo puede BAJAR. Es el mismo mecanismo que
# probar-bancos-fragiles con fragiles-techo.txt, y por la misma razon: el numero de hoy es el que
# hay, y nadie puede añadir uno nuevo sin enterarse.
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PS1 = os.path.join(RAIZ, 'assistant.ps1')
TECHO = os.path.join(RAIZ, 'tools', 'tempranas-techo.txt')

mal = 0


def comp(que, ok, detalle=''):
    global mal
    print('  %s  %-58s %s' % ('ok ' if ok else 'MAL', que, detalle))
    if not ok:
        mal += 1


def sin_comentario(l):
    """Quita el comentario del final de linea sin romper las cadenas con '#' dentro.

    HACE FALTA: sin esto, '$JuegosOidosMax = 200   # ver el tope en Save-JuegoOido' contaba como
    una llamada a Save-JuegoOido, y salian tres falsos de tres."""
    fuera = []
    comilla = None
    for c in l:
        if comilla:
            fuera.append(c)
            if c == comilla:
                comilla = None
            continue
        if c in '"\'':
            comilla = c
            fuera.append(c)
            continue
        if c == '#':
            break
        fuera.append(c)
    return ''.join(fuera)


def sin_cadenas(l):
    """Vacia las cadenas, para poder contar llaves sin que mientan.

    ESTE ERA UN FALLO DEL PROPIO BANCO, y gordo: la linea
        foreach ($k in $enc.valores.Keys) { $t = $t.Replace('{' + $k + '}', ...) }
    tiene una '{' y una '}' DENTRO de comillas simples. Contandolas, el rango de la funcion que la
    contiene no se cerraba nunca, se comia veinte mil lineas, y el banco daba por "cuerpo principal"
    cosas que estaban dentro de una funcion -tres falsos de cinco- y encima se saltaba las
    definiciones de por medio (no encontraba ni Show-Popup, definida en la 30721)."""
    l = sin_comentario(l)
    fuera = []
    comilla = None
    for c in l:
        if comilla:
            if c == comilla:
                comilla = None
            continue
        if c in '"\'':
            comilla = c
            continue
        fuera.append(c)
    return ''.join(fuera)


VERBOS = (r'(?:Get|Set|Test|New|Find|Add|Send|Save|Start|Stop|Write|Read|Invoke|Clear|Receive|'
          r'Request|Process|Watch|Restore|Update|Show|Measure|Remove|Convert|Wait|Enable|Disable|'
          r'Reset|Push|Pop|Join|Split|Select|Where|Sort|Group|Export|Import|Out|Format)')
RX_LLAMADA = re.compile(r'\b(%s-[A-Z][A-Za-z0-9]+)\b' % VERBOS)
# Los cmdlets de PowerShell no cuentan: no se definen en el fichero, y si no estan definidos aqui
# simplemente no entran en el diccionario de definiciones.


def main():
    texto = io.open(PS1, encoding='utf-8-sig', errors='replace').read()
    L = texto.split('\n')
    n = len(L)
    print('')
    print('  assistant.ps1: %d lineas' % n)

    # ---- donde se define cada funcion, y que rango ocupa ----
    defs = {}
    dentro = [False] * n
    i = 0
    while i < n:
        m = re.match(r'^function\s+([A-Za-z][\w-]*)', L[i])
        if m:
            nombre = m.group(1)
            defs.setdefault(nombre, i + 1)
            prof = 0
            j = i
            while j < n:
                limpia = sin_cadenas(L[j])
                prof += limpia.count('{') - limpia.count('}')
                dentro[j] = True
                j += 1
                if prof <= 0 and j > i:
                    break
            cuerpo = (i + 1, j)        # [desde, hasta) en indices base 0
            defs[nombre] = i + 1
            defs.setdefault('__cuerpo__', {})
            defs['__cuerpo__'][nombre] = cuerpo
            i = j
        else:
            i += 1
    cuerpos = defs.pop('__cuerpo__', {})
    comp('se encuentran las definiciones', len(defs) > 400, '%d funciones' % len(defs))

    # ---- donde empieza el bucle: lo de despues no es arranque ----
    iBucle = next((k for k, l in enumerate(L) if re.match(r'^while \(\$true\) \{', l)), -1)
    comp('se encuentra el bucle principal', iBucle > 0, 'linea %d' % (iBucle + 1))
    if iBucle < 0:
        return 1

    # ---- a quien llama cada funcion ----
    llama = {}
    for nombre, (a, b) in cuerpos.items():
        s = set()
        for k in range(a, min(b, n)):
            for m in RX_LLAMADA.finditer(sin_comentario(L[k])):
                g = m.group(1)
                if g in defs and g != nombre:
                    s.add(g)
        llama[nombre] = s

    # ---- el arranque: lineas del cuerpo principal antes del bucle ----
    pares = []
    for k in range(0, iBucle):
        if dentro[k]:
            continue
        limpia = sin_comentario(L[k])
        for m in RX_LLAMADA.finditer(limpia):
            g = m.group(1)
            if g in defs:
                pares.append((k + 1, g))
    comp('el arranque llama a funciones propias', len(pares) > 20, '%d llamadas' % len(pares))

    # ---- cierre transitivo: todo lo alcanzable se ejecuta en el momento de la linea L ----
    fallos = []
    for linea, fn in pares:
        vistos = set()
        pila = [(fn, [fn])]
        while pila:
            g, camino = pila.pop()
            if g in vistos:
                continue
            vistos.add(g)
            if defs[g] > linea:
                fallos.append((linea, ' -> '.join(camino), defs[g]))
                continue        # no se sigue por dentro de algo que no existe
            for h in sorted(llama.get(g, ())):
                if h not in vistos:
                    pila.append((h, camino + [h]))

    # un mismo par (camino, definicion) puede salir por varias lineas del arranque: se deja el peor
    unicos = {}
    for linea, camino, d in fallos:
        clave = camino
        if clave not in unicos or linea < unicos[clave][0]:
            unicos[clave] = (linea, d)
    print('')
    print('  llamadas del arranque a algo definido mas abajo: %d' % len(unicos))
    for camino in sorted(unicos, key=lambda c: unicos[c][0]):
        linea, d = unicos[camino]
        print('     arranque:%-6d %s   (definida en %d)' % (linea, camino[:86], d))

    # ---- QUE LA FAMILIA DE AYER Y DE HOY NO VUELVA: las dos a la cara ----
    print('')
    iPopup = defs.get('Show-Popup', 0)
    iQuietud = defs.get('Get-QuietudMando', 0)
    iNadie = defs.get('Get-NadieMin', 0)
    comp('Get-QuietudMando se define antes de Get-NadieMin',
         0 < iQuietud < iNadie, 'quietud %d, nadie %d' % (iQuietud, iNadie))
    # Show-Popup: el arreglo del 1/10 no fue moverla, fue que los avisos no dependan de ella; lo que
    # se exige es que el aviso del arranque siga sin romperse, que es lo que mira probar-tarjeta.
    comp('Show-Popup sigue existiendo una sola vez', iPopup > 0, 'linea %d' % iPopup)

    # ---- Y QUE EL DETECTOR DETECTE: si no, todo esto seria un verde vacio ----
    # Se inventa una funcion definida al final y llamada en la primera linea del arranque.
    defsP = dict(defs); defsP['Get-Inventada'] = n
    llamaP = dict(llama)
    paresP = [(10, 'Get-Inventada')]
    pegado = []
    for linea, fn in paresP:
        if defsP[fn] > linea:
            pegado.append((linea, fn))
    comp('  y el detector sabe decir que SI cuando lo hay', len(pegado) == 1, 'caso de pega')

    # ---- EL TRINQUETE ----
    techo = None
    if os.path.exists(TECHO):
        try:
            techo = int(io.open(TECHO, encoding='ascii').read().strip().split()[0])
        except Exception:
            techo = None
    hoy = len(unicos)
    if techo is None:
        io.open(TECHO, 'w', encoding='ascii', newline='\n').write(
            '%d\n# La cuenta de llamadas del arranque a algo definido mas abajo.\n'
            '# SOLO PUEDE BAJAR: ver probar-llamada-temprana.py. Si sube, alguien ha metido una\n'
            '# dependencia nueva que el arranque no puede resolver, y el catch se la va a tragar.\n'
            % hoy)
        print('  (primera vez: techo guardado en %d)' % hoy)
    else:
        comp('la cuenta no ha subido', hoy <= techo, 'hoy %d, techo %d' % (hoy, techo))
        if hoy < techo:
            io.open(TECHO, 'w', encoding='ascii', newline='\n').write(
                '%d\n# La cuenta de llamadas del arranque a algo definido mas abajo.\n'
                '# SOLO PUEDE BAJAR: ver probar-llamada-temprana.py.\n' % hoy)
            print('  (bajo de %d a %d: techo apretado)' % (techo, hoy))

    print('')
    if mal:
        print('  %d MAL' % mal)
        return 1
    print('  el arranque no llama a nada que todavia no exista')
    return 0


if __name__ == '__main__':
    sys.exit(main())
