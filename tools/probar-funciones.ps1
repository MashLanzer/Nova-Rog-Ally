# Prueba funciones sueltas SACADAS DEL ARCHIVO REAL (no de una copia), sin
# arrancar el asistente ni tocar el microfono. El 11/09 probe una copia de
# Get-JuegosZombis escrita a mano y pase por alto que la del archivo tenia el
# regex roto: no compilaba y devolvia lista vacia en silencio.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

# devuelve el TEXTO: el Invoke-Expression tiene que hacerse en el ambito del
# script, o las funciones quedan definidas solo dentro de esta funcion
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { throw "no encuentro $nombre" }
    return $fn.Extent.Text
}

# dependencias minimas
$script:juegoActivo = $null
$ZombiMinutos = 20
$ZombiUsoCPU = 0.30
function Find-Juego($t) { return $null }   # sin biblioteca: usa el nombre de la carpeta
# las estadisticas se sustituyen por datos de mentira: lo que se prueba es
# Get-Atragantos, no de donde vienen los numeros
function Get-Estadisticas { return $script:stats }

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Test-MismoAudio')
Invoke-Expression (Traer 'Get-JuegosZombis')
Invoke-Expression (Traer 'Get-Atragantos')
Invoke-Expression (Traer 'Get-Trozo')
Invoke-Expression (Traer 'Test-MereceRepaso')

$mal = 0
Write-Host "--- Test-MismoAudio (del archivo real) ---"
$casos = @(
  @('los',        'SILENT BREATH',        $false, 'el ruido que abrio el juego'),
  @('abrestean',  'abre steam',           $true,  'el caso para el que existe el repaso'),
  @('eh',         'OUTLAST 2',            $false, 'ruido corto'),
  @('Abre, Lytlen y Mar estresenstea', 'abre little nightmares tres en steam', $true, 'destrozo real de base'),
  @('pon modo noche', 'pon modo noche',   $true,  'identicos')
)
foreach ($c in $casos) {
    $r = Test-MismoAudio $c[0] $c[1]
    $ok = ($r -eq $c[2])
    if (-not $ok) { $mal++ }
    "  {0}  '{1}' vs '{2}' -> {3}  ({4})" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $c[0], $c[1], $r, $c[3]
}

Write-Host ""
Write-Host "--- Get-JuegosZombis con procesos de mentira ---"
$BARRA = [char]92
function Falso($nombre, $carpeta, $ventana, $minutos, $fraccionCPU) {
    $base = 'C:' + $BARRA + 'Program Files (x86)' + $BARRA + 'Steam' + $BARRA + 'steamapps' + $BARRA + 'common'
    [PSCustomObject]@{
        Id = (Get-Random -Minimum 1000 -Maximum 9999)
        ProcessName = $nombre
        Path = $base + $BARRA + $carpeta + $BARRA + $nombre + '.exe'
        MainWindowTitle = $ventana
        StartTime = (Get-Date).AddMinutes(-$minutos)
        CPU = $minutos * 60 * $fraccionCPU
    }
}
# el caso real del 11/09 y sus vecinos, que NO deben caer
$falsos = @(
    (Falso 'Outlast2'    'Outlast 2'          ''                   210 0.87),  # colgado de verdad
    (Falso 'wallpaper64' 'wallpaper_engine'   ''                   598 0.03),  # utilidad sin ventana
    (Falso 'TL'          'Throne and Liberty' 'Throne and Liberty'  90 0.95),  # jugando ahora
    (Falso 'Reanimal'    'REANIMAL'           ''                     5 0.90),  # recien abierto
    (Falso 'Silent'      'SILENT BREATH'      ''                    45 0.05)   # abierto sin gastar
)
$esperado = @('Outlast 2')
$z = @(Get-JuegosZombis $falsos)
$vistos = @($z | ForEach-Object { $_.nombre })
foreach ($f in $falsos) {
    $trozos = $f.Path.Split($BARRA)
    $carpeta = $trozos[$trozos.Count - 2]
    $marcado = ($vistos -contains $carpeta)
    $debe = ($esperado -contains $carpeta)
    $ok = ($marcado -eq $debe)
    if (-not $ok) { $mal++ }
    "  {0}  {1,-20} {2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $carpeta, $(if ($marcado) { '-> COLGADO' } else { '   (se deja en paz)' })
}

Write-Host ""
Write-Host "--- y contra los procesos de verdad de ahora mismo ---"
$real = @(Get-JuegosZombis)
if ($real.Count -eq 0) { "  ninguno colgado" } else { foreach ($x in $real) { "  COLGADO: $($x.nombre) ($($x.minutos) min)" } }

Write-Host ""
# --- Get-Atragantos: que ordenes fallan mas de una vez ---
# Lo delicado es que NO cuente ruido de una palabra y que agrupe bien lo que
# vino por caminos distintos (descarte hoy, modelo ayer): si no agrupa, la
# frase que mas falla se lee igual que una que fallo una vez y ya.
Write-Host ""
Write-Host "--- Get-Atragantos (del archivo real) ---"
$script:stats = @{
    dias = @{}
    descartes = @('2026-09-12  pon musica', '2026-09-11  pon musica', '2026-09-10  abre el disco duro', '2026-09-09  eh')
    recientes = @(
        '2026-09-12 21:03  [traducir]  pon musica',
        '2026-09-12 20:10  [local]  abre steam',
        '2026-09-11 19:00  [error]  cierra el juego',
        '2026-09-11 18:00  [error]  cierra el juego'
    )
}
$at = @(Get-Atragantos)
$casosA = @(
    @('la que mas falla va primera', ($at.Count -gt 0 -and (ConvertTo-Plain $at[0].frase) -eq 'pon musica')),
    @('y cuenta las tres veces',     ($at.Count -gt 0 -and $at[0].veces -eq 3)),
    @('junta descarte y modelo',     ($at.Count -gt 0 -and $at[0].rutas.Count -eq 2)),
    @('el error tambien cuenta',     (@($at | Where-Object { (ConvertTo-Plain $_.frase) -eq 'cierra el juego' -and $_.veces -eq 2 }).Count -eq 1)),
    @('una orden que fue bien no sale', (@($at | Where-Object { (ConvertTo-Plain $_.frase) -eq 'abre steam' }).Count -eq 0)),
    @('el ruido de una palabra no sale', (@($at | Where-Object { (ConvertTo-Plain $_.frase) -eq 'eh' }).Count -eq 0))
)
foreach ($c in $casosA) {
    if (-not $c[1]) { $mal++ }
    "  {0}  {1}" -f $(if ($c[1]) { 'OK  ' } else { 'MAL ' }), $c[0]
}

# --- Get-Trozo: leer una pantalla larga a cachos ---
# Lo unico que puede quedar feo aqui es cortar una palabra por la mitad (suena
# a fallo, no a pausa) y perder o repetir texto al seguir.
Write-Host ""
Write-Host "--- Get-Trozo (del archivo real) ---"
$largo = (1..40 | ForEach-Object { "Frase numero $_ con unas cuantas palabras." }) -join ' '
$t1 = Get-Trozo $largo 0 120
$t2 = Get-Trozo $largo $t1.fin 120
$casosT = @(
    @('el primer trozo cabe',        ($t1.texto.Length -le 120)),
    # NO PARTIR UNA PALABRA SE MIRA POR DONDE SE CORTO, NO POR COMO ACABA EL TROZO
    # (21/09). El patron de antes, '[.\w]$', pedia que el trozo acabara en letra, digito
    # o punto... y cortar a mitad de palabra deja JUSTAMENTE una letra al final. O sea que
    # era cierto en el caso bueno Y en el malo: no podia detectar lo que decia detectar.
    # El unico caso en que Get-Trozo parte una palabra es el corte de respaldo
    # ($corte = $largo - 1), y lo que lo distingue es el caracter por el que corto: con un
    # corte limpio el que queda justo antes del 'fin' es un espacio o un punto.
    @('no parte una palabra',        ($t1.fin -ge $largo.Length -or $largo[$t1.fin - 1] -eq ' ' -or $largo[$t1.fin - 1] -eq '.')),
    @('y dice donde se quedo',       ($t1.fin -gt 0 -and $t1.fin -lt $largo.Length)),
    @('el segundo sigue, no repite', ($t2.texto -ne $t1.texto -and $largo.Substring($t1.fin).TrimStart().StartsWith($t2.texto.Substring(0, 12)))),
    @('un texto corto va entero',    ((Get-Trozo 'hola que tal' 0 120).texto -eq 'hola que tal')),
    @('pasado el final, nada',       ((Get-Trozo 'hola' 99 120).texto -eq ''))
)
foreach ($c in $casosT) {
    if (-not $c[1]) { $mal++ }
    "  {0}  {1}" -f $(if ($c[1]) { 'OK  ' } else { 'MAL ' }), $c[0]
}

# --- Test-MereceRepaso: no pedir un repaso que se va a tirar igual ---
# La guarda solo es legitima si se cumple esto: siempre que dice que NO merece
# la pena, Test-MismoAudio habria rechazado el repaso pase lo que pase. No se
# da por supuesto: se comprueba contra el corpus de ruido REAL y contra los
# nombres que el modelo preciso suele alucinar.
Write-Host ""
Write-Host "--- Test-MereceRepaso (del archivo real) ---"
$inventos = @(
    'SILENT BREATH', 'Little Nightmares III', 'Outlast 2', 'Hollow Knight',
    'abre steam', 'pon modo noche', 'Wallpaper Engine', 'REANIMAL', 'sube el volumen'
)
$ruido = Join-Path (Split-Path -Parent $PSScriptRoot) (Join-Path 'pruebas' 'ruido-real.txt')
$cortas = 0; $colados = 0
if (Test-Path -LiteralPath $ruido) {
    foreach ($l in (Get-Content -LiteralPath $ruido -Encoding UTF8)) {
        $l = $l.Trim(); if (-not $l -or $l.StartsWith('#')) { continue }
        if (Test-MereceRepaso $l) { continue }
        $cortas++
        foreach ($inv in $inventos) { if (Test-MismoAudio $l $inv) { $colados++ } }
    }
}
$casosR = @(
    @('el ruido de tres letras no merece repaso', (-not (Test-MereceRepaso 'los'))),
    @('ni dos palabras cortas',                   (-not (Test-MereceRepaso 'si va'))),
    @('una orden de verdad si',                   (Test-MereceRepaso 'abrestean')),
    @('y el destrozo largo tambien',              (Test-MereceRepaso 'Abre, Lytlen y Mar estresenstea')),
    @('hay frases cortas en el corpus real',      ($cortas -ge 5)),
    @('y NINGUNA podia aceptar un repaso',        ($colados -eq 0))
)
foreach ($c in $casosR) {
    if (-not $c[1]) { $mal++ }
    "  {0}  {1}" -f $(if ($c[1]) { 'OK  ' } else { 'MAL ' }), $c[0]
}
"      ({0} frases cortas del corpus real x {1} invenciones = {2} combinaciones, {3} coladas)" -f $cortas, $inventos.Count, ($cortas * $inventos.Count), $colados

Write-Host ""
Write-Host "--- Test-Charla: conversacion de fondo vs ordenes largas de verdad ---"
# las listas tambien salen del archivo real: si alguien quita un verbo de
# $VERBOS, esta prueba tiene que notarlo
function TraerVariable([string]$nombre) {
    $asig = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $n.Left.VariablePath.UserPath -eq $nombre }, $true)
    if (-not $asig) { throw "no encuentro `$$nombre" }
    return $asig.Extent.Text
}
foreach ($v in @('VERBOS', 'VERBOS_LISTA', 'VERBOS_OIDOS', 'INICIO_ORDEN', 'INGLES_COMUN', 'ESPANOL_COMUN')) { Invoke-Expression (TraerVariable $v) }
$script:Juegos = @(@{ nombre = 'The Last of Us Part I' }, @{ nombre = 'Hollow Knight' })
Invoke-Expression (Traer 'Test-Charla')
$casosC = @(
  # charla real del 12/09, 19:00-19:07, tal como llego (despues del oido fino)
  @('Bueno, voy a tratar de salir más rápido que solo, Te amo, te amo, te amo, te amo', $true),
  @('Porque eso supone que nosotros a las ocho,', $true),
  @('Vamos a centrarlo, Igual, igual.., Sí, yo sé que es esta temporada dos domingos, Igual podemos vernos el lunes, ¿no', $true),
  @('Laiya, es que Laiya está haciendo prueba y se activa y entonces me escucha a mí lo que yo estoy hablando, Dios, escucha', $true),
  @('INCREIBLE, todo lo que ha hecho, Wey, wey me esta escuchando, wey me esta escuchando y se esta escuchando super bien', $true),
  @('En el código lo que yo dije hace formar una frase, ya no, y ahora lo que hace es utilizar el reconocimiento de voz de windows', $true),
  @("A ver, steam, yes, concept, boy, love it, I'm working with another person, and I don't know when we're going to do it", $true),
  # ordenes largas de verdad (log y banco): NINGUNA puede caer
  @('Abre steam y busca también el navegador perros y gato Además sube el volumen y el brillo máximo', $false),
  @('Puedes bajarle el volumen al 10% y subir el brillo al 90%', $false),
  @('Búscame en steam los juegos que están en oferta', $false),
  @('recuerdame manana a las 10 que llame al medico', $false),
  @('Busca información sobre el juego que estoy jugando y dime que no me voy a hacer en esta parte', $false),
  @("Abre en navegador y busca pa' interest, además ponte en porisador de 5 minutos", $false),
  @('Sierra todas las ventanas que tengo abiertas en el escritorio', $false),
  @('oye nova pon el volumen al treinta por ciento por favor', $false),
  @('Hazme un resumen de lo que dice esta página web ahora', $false),
  @('bueno abre steam y pon el modo juego ahora mismo', $false),
  @('Bájale el volumen al juego y súbele a discord un poco', $false),
  # charla CORTA en ingles (revision del 12/09): tampoco es para mi
  @('Oh my god, what is that?', $true),
  @("I don't know, man", $true),
  @("Yeah, that's right bro", $true),
  @('What are you doing?', $true),
  @("let's go guys, come on", $true),
  # ...pero con nombres ingleses de por medio, sigue siendo orden
  @('the last of us', $false),
  @('abre the last of us', $false),
  @('pon music for you', $false),
  @('hollow knight silksong', $false),
  @('que is that', $false),
  @('Steam big picture mode', $false),
  # lo corto no es cosa de este filtro
  @('bueno vale', $false)
)
foreach ($c in $casosC) {
    $r = Test-Charla $c[0]
    $ok = ($r -eq $c[1])
    if (-not $ok) { $mal++ }
    "  {0}  {1} -> {2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $c[0].Substring(0, [Math]::Min(60, $c[0].Length)), $(if ($r) { 'charla' } else { 'orden' })
}

if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
