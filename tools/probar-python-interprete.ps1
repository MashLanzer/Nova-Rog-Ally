# LOS BANCOS DE PYTHON QUE SE RENDIAN POR EL INTERPRETE (27/09, tras la revision)
#
# LO QUE PASO: la bateria lanza sus bancos de Python con "python" a secas, y el "python" del PATH
# de esta consola es el 3.11, que NO tiene numpy ni httpx. Nova, en cambio, arranca sus workers con
# el de config.json (paths.python, el $PyExe de assistant.ps1), que si los tiene. O sea que tres
# bancos morian en el import -por el interprete, no por el codigo- y DOS DE ELLOS salian con codigo
# 0: Traceback por arriba, verde por abajo, y nadie se enteraba de que no comprobaban nada.
# probar-audio.py llevaba asi desde que se escribio; al arreglarlo por fin corrio entero (20 de 20)
# y de paso destapo que ni siquiera podia leer la frase de ejemplo.
#
# ES LA MANERA 18 DE SALIR VERDE MINTIENDO, y la mas barata de todas: no hace falta doblar ninguna
# pieza ni escribir un caso tramposo, basta con lanzar el banco con un interprete al que le falta
# algo. Por eso se vigila aqui y no a mano.
#
# LO QUE ESTE BANCO EXIGE, y solo eso: que ningun banco de la bateria importe A PELO un paquete que
# con ESE interprete no esta, a menos que antes se vuelva a lanzar con el Python de Nova. Un import
# a pelo de algo que no existe y sin esa red es muerte segura -el fichero no llega ni a su primera
# linea-, asi que aqui no hay opinion ninguna: o arranca o no arranca.
#
# LO QUE NO EXIGE, a proposito: nada a los imports que van dentro de un try. Ahi el patron normal de
# la casa es lo contrario de un fallo -charla_memoria.py degrada a busqueda por palabras cuando no
# hay numpy, que es la regla 7-. Pedirles ceremonia habria puesto SIETE rojos el primer dia por
# bancos que corren perfectamente, y un aviso que sale siempre se aprende a ignorar, que es la unica
# forma segura de matar un aviso. Se listan en gris, que es lo que merecen.
#
# COMO SE MIDE, que es lo que importa: no hay lista de paquetes escrita a mano. El ayudante
# ayuda-imports-que-faltan.py saca por AST los modulos que cada banco importa -siguiendo la cadena
# mientras se quede dentro del repo, que es como se destapo lo de probar-charla.py, que moria por el
# httpx de charla_worker.py y no por nada suyo- y pregunta por ellos con importlib.util.find_spec
# CON ESE MISMO python. Si manana alguien instala numpy en el 3.11, esto deja de quejarse solo; y si
# manana un banco nuevo importa otra cosa, lo caza sin que nadie toque una linea.
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  OK   ' + $que.PadRight(54) + ' ' + $detalle) }
    else { Write-Host ('  MAL  ' + $que.PadRight(54) + ' ' + $detalle) -ForegroundColor Red; $script:mal++ }
}

# LA RED, EN UNA SOLA FUNCION, para que la use tanto la pasada de verdad como el detector de abajo:
# un caso negativo que no toca la misma pieza no comprueba nada (manera 17 de salir verde mintiendo).
function TieneRed([string]$txt) {
    if (-not $txt) { return $false }
    # 1) sabe cual es el Python de Nova, y lo saca de config.json, no de una ruta a fuego
    $sabe = ($txt -match '_python_de_nova') -and ($txt -match 'config\.json') -and ($txt -match 'paths')
    # 2) y se vuelve a lanzar con el, en vez de rendirse
    $relanza = ($txt -match 'subprocess\.call\(\[') -and ($txt -match '__file__')
    return ($sabe -and $relanza)
}

Write-Host ''
Write-Host '-- 1. LOS BANCOS DE PYTHON QUE LANZA LA BATERIA --'
$bat = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probar-todo.ps1'))
$lanzados = New-Object System.Collections.Generic.List[string]
foreach ($ln in ($bat -split "`n")) {
    if ($ln.TrimStart().StartsWith('#')) { continue }
    $m = [regex]::Match($ln, "python[^\r\n]*?['\\/]([A-Za-z0-9._-]+\.py)")
    if (-not $m.Success) { continue }
    $r = Join-Path $PSScriptRoot $m.Groups[1].Value
    if ((Test-Path -LiteralPath $r) -and -not $lanzados.Contains($r)) { [void]$lanzados.Add($r) }
}
Comp 'la bateria lanza bancos de Python' ($lanzados.Count -gt 0) ([string]$lanzados.Count + ' ficheros')

# LOS TRES DE MENTIRA VAN EN LA MISMA LISTA Y POR EL MISMO CAMINO que los de verdad, y se
# diferencian solo en lo que decide el veredicto: el primero importa a pelo algo que no existe, el
# segundo hace lo mismo pero con la red puesta, y el tercero lo envuelve en un try.
$tmp = Join-Path $env:TEMP ('nova-interprete-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$falsoSin = Join-Path $tmp 'banco-de-mentira-sin-red.py'
$falsoCon = Join-Path $tmp 'banco-de-mentira-con-red.py'
$falsoTry = Join-Path $tmp 'banco-de-mentira-con-try.py'
$red = @(
    'import json, os, subprocess, sys',
    'def _python_de_nova():',
    '    exe = ""',
    '    try:',
    '        with open(os.path.join(os.path.dirname(__file__), "config.json")) as f:',
    '            exe = ((json.load(f).get("paths") or {}).get("python") or "")',
    '    except Exception:',
    '        exe = ""',
    '    return exe',
    'if not os.environ.get("YA_RELANZADO"):',
    '    os.environ["YA_RELANZADO"] = "1"',
    '    sys.exit(subprocess.call([_python_de_nova(), os.path.abspath(__file__)]))')
$cuerpoSin = @(
    'import os, sys',
    'import paquete_que_no_existe_en_ninguna_parte  # a pelo y sin red, a proposito',
    'print("todo correcto")') -join "`r`n"
$cuerpoCon = ($red + @(
    'import paquete_que_no_existe_en_ninguna_parte  # el mismo import a pelo, pero con red',
    'print("todo correcto")')) -join "`r`n"
$cuerpoTry = @(
    'import os, sys',
    'try:',
    '    import paquete_que_no_existe_en_ninguna_parte  # el mismo, dentro de un try',
    'except Exception:',
    '    pass',
    'print("todo correcto")') -join "`r`n"
[IO.File]::WriteAllText($falsoSin, $cuerpoSin, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($falsoCon, $cuerpoCon, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($falsoTry, $cuerpoTry, (New-Object System.Text.UTF8Encoding($false)))

$todos = @($lanzados) + @($falsoSin, $falsoCon, $falsoTry)
$lista = Join-Path $tmp 'lista.txt'
[IO.File]::WriteAllLines($lista, [string[]]$todos, (New-Object System.Text.UTF8Encoding($false)))

# EL MISMO "python" QUE USA LA BATERIA, a proposito: la pregunta es que falta AQUI
$salida = @(python (Join-Path $PSScriptRoot 'ayuda-imports-que-faltan.py') $lista 2>&1)
$codigo = $LASTEXITCODE
Comp 'el ayudante los analiza con ese mismo python' (($codigo -eq 0) -and ($salida.Count -eq $todos.Count)) ([string]$salida.Count + ' respuestas de ' + [string]$todos.Count + ', codigo ' + [string]$codigo)

$aPelo = @{}
$enTry = @{}
foreach ($l in $salida) {
    $p = ([string]$l).Split('|')
    if ($p.Count -ge 3) { $aPelo[$p[0]] = $p[1]; $enTry[$p[0]] = $p[2] }
}
Comp 'ninguno se quedo sin analizar' (-not ($aPelo.Values -contains '?')) 'un "?" seria un .py que ni se parsea'

# EL VEREDICTO, EN UNA SOLA FUNCION: le falta algo a pelo y no tiene con que levantarse
function Muere([string]$ruta, [string]$faltan) {
    if (-not $faltan -or $faltan -eq '?') { return $false }
    return (-not (TieneRed ([IO.File]::ReadAllText($ruta))))
}

Write-Host ''
Write-Host '-- 2. NINGUNO MUERE EN EL IMPORT --'
$muertos = @()
$conRed = @()
foreach ($r in $lanzados) {
    $n = Split-Path -Leaf $r
    $f = [string]$aPelo[$n]
    if (-not $f -or $f -eq '?') { continue }
    if (Muere $r $f) { $muertos += ($n + ' -> ' + $f) } else { $conRed += ('      ' + $n.PadRight(30) + ' ' + $f) }
}
Comp 'ningun banco muere en el import' ($muertos.Count -eq 0) $(if ($muertos.Count) { $muertos -join ' | ' } else { [string]$lanzados.Count + ' comprobados' })
if ($conRed.Count) {
    Write-Host ('  --   ' + $conRed.Count + ' importan a pelo algo que aqui no esta, pero se relanzan con el Python de Nova:') -ForegroundColor DarkGray
    foreach ($c in $conRed) { Write-Host $c -ForegroundColor DarkGray }
}

# INFORMATIVO, NO VEREDICTO: los que se apoyan en algo que aqui no esta pero dentro de un try. No es
# un fallo -es la regla 7- pero conviene verlos, porque ahi se esconde la otra mitad del problema:
# un except que en vez de degradar se rinde y sale con codigo 0, que es como estaba probar-audio.py.
$conTry = @()
foreach ($r in $lanzados) {
    $n = Split-Path -Leaf $r
    if ($enTry.ContainsKey($n) -and $enTry[$n]) { $conTry += ('      ' + $n.PadRight(30) + ' ' + $enTry[$n]) }
}
if ($conTry.Count) {
    Write-Host ('  --   y ' + $conTry.Count + ' se apoyan en algo que aqui no esta, con try (mira que el except no se rinda):') -ForegroundColor DarkGray
    foreach ($c in $conTry) { Write-Host $c -ForegroundColor DarkGray }
}

Write-Host ''
Write-Host '-- 3. Y QUE EL DETECTOR DETECTE --'
$nSin = Split-Path -Leaf $falsoSin
$nCon = Split-Path -Leaf $falsoCon
$nTry = Split-Path -Leaf $falsoTry
Comp 've el import a pelo de lo que no existe' ($aPelo[$nSin] -match 'paquete_que_no_existe') ([string]$aPelo[$nSin])
Comp 'y lo llama muerto, porque no tiene red' (Muere $falsoSin ([string]$aPelo[$nSin])) 'sin relanzado'
Comp 'el mismo import con red no cuenta como muerto' (-not (Muere $falsoCon ([string]$aPelo[$nCon]))) 'con relanzado'
Comp 'pero se le ve igual el paquete que falta' ($aPelo[$nCon] -match 'paquete_que_no_existe') ([string]$aPelo[$nCon])
Comp 'y el que lo mete en un try, ni muerto ni a pelo' ((-not ($aPelo[$nTry] -match 'paquete_que_no_existe')) -and ($enTry[$nTry] -match 'paquete_que_no_existe')) 'sale por la columna del try'

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($mal -eq 0) {
    Write-Host 'ningun banco de Python se rinde por el interprete'
    exit 0
}
Write-Host ('MAL: ' + [string]$mal + ' comprobaciones') -ForegroundColor Red
exit 1
