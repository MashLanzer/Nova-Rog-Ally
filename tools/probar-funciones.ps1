# Prueba funciones sueltas SACADAS DEL ARCHIVO REAL (no de una copia), sin
# arrancar el asistente ni tocar el microfono. El 11/09 probe una copia de
# Get-JuegosZombis escrita a mano y pase por alto que la del archivo tenia el
# regex roto: no compilaba y devolvia lista vacia en silencio.
# POR DONDE ESTE EL BANCO, NO POR UNA RUTA ESCRITA A MANO (22/09). Aqui habia la ruta
# completa a fuego: en una copia del repo en otra carpeta este banco seguiria midiendo el
# assistant.ps1 de SIEMPRE -verde sobre codigo que no es el que se acaba de tocar- y si la
# carpeta se renombrara se caeria entero por algo que no tiene que ver con lo que prueba.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
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

Write-Host ""
Write-Host "--- el oido fino: lo que NO merecio repaso en el registro ---"
# QUE DECIDE EL OIDO FINO: el modelo rapido (base) dicta, y cuando lo que sale no se
# entiende -o se entiende pero Whisper dudaba- se repasa EL MISMO audio con small.
# CUANTO ACTUO, de estadisticas.json (9 dias, del 12 al 23/09): 145 repasos pedidos (60 el
# 15/09, 23 el 20/09, 21 el 18/09), de los que 37 sirvieron (fino-sirvio), 45 dieron lo
# mismo (fino-igual) y 7 fueron invento suyo (fino-invento). Y 6 NO se llegaron a pedir
# (fino-ahorrado), que son justo las seis lineas "OIDO FINO: no lo pido" de
# assistant.log.1: los dos numeros cuadran, 5 el 15/09 y 1 el 21/09.
# Esas seis lineas son CINCO frases distintas ("No, no, no" sale dos veces), copiadas del
# registro tal cual. Son ruido del cuarto y titubeos, no ordenes. Si Test-MereceRepaso
# dejara de verlas, cada una costaria la espera del repaso -medida en el log en 4,4 /
# 3,9 / 3,6 s- para tirarla despues igual, porque Test-MismoAudio la rechazaria:
# ninguna tiene una palabra de 4 letras donde agarrarse.
# La tercera lleva una i con tilde ("dia"); aqui los ficheros son ASCII y se arma con su
# codigo, para que sea la frase de braya y no una parecida.
$noLoPido = @(
    'Y una vez que eso',
    'No, no, No, No',
    ('Ya d' + [char]0xED + 'a es hoy'),
    'No, no, no, no',
    'No, no, no'
)
$pedidas = @($noLoPido | Where-Object { Test-MereceRepaso $_ })
if ($pedidas.Count -gt 0) { $mal++ }
"  {0}  ninguna de las 5 frases del registro pide repaso" -f $(if ($pedidas.Count -eq 0) { 'OK  ' } else { 'MAL ' })
if ($pedidas.Count -gt 0) { "        piden repaso: " + ($pedidas -join ' / ') }
# ...y la otra mitad de la guarda: que tirarlas no pierda nada. Con cada invencion tipica
# del modelo preciso, el repaso de estas cinco se habria descartado igual.
$colados2 = 0
foreach ($l in $noLoPido) { foreach ($inv in $inventos) { if (Test-MismoAudio $l $inv) { $colados2++ } } }
if ($colados2 -ne 0) { $mal++ }
"  {0}  y ninguna podia aceptar un repaso ({1} combinaciones)" -f $(if ($colados2 -eq 0) { 'OK  ' } else { 'MAL ' }), ($noLoPido.Count * $inventos.Count)

Write-Host ""
Write-Host "--- el ultimo escalon del oido fino: cuando se pide turbo (del archivo real) ---"
# EL ESCALON DE ABAJO. Cuando ni base ni small sacan una orden, cuatro ramas del oido fino
# llaman a Request-UltimoRecurso para que turbo (large-v3-turbo) repase el mismo audio.
# Turbo tarda ~12 s por frase, asi que lo que decide esta funcion es cuanto te hace
# esperar. En assistant.log.1 hay 57 lineas "ULTIMO RECURSO": 29 peticiones y 27 finales.
# NADIE LA PROBABA. Se saca del archivo real con sus dependencias; lo unico de mentira son
# el cronometro, el worker y las dos rutas de marcas.
$script:relojMs = 100000
$sw = New-Object psobject
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojMs }
$script:oidosDudosos = @{}
$script:logsF = @()
function Log($m) { $script:logsF += $m }
function Add-Estadistica($a, $b) {}
function Set-UI($a, $b) {}
Invoke-Expression (Traer 'Test-PareceCharla')
Invoke-Expression (Traer 'Add-OidoDudoso')
Invoke-Expression (TraerVariable 'ReintentoUltimoMs')
Invoke-Expression (Traer 'Request-UltimoRecurso')
$dirFino = Join-Path $env:TEMP ('nova-fino-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dirFino | Out-Null
$RutaReintento = Join-Path $dirFino 'reintento.txt'
$MarcaReintento = Join-Path $dirFino 'marca-reintento.txt'
$WhisperUltimo = 'large-v3-turbo'
$script:wakeProc = New-Object psobject
$script:wakeProc | Add-Member -MemberType NoteProperty -Name HasExited -Value $false
$script:juegoActivo = $null
$script:reintentoUltimo = $false
$script:ultimoRecursoPara = ''
$script:ultimoRecursoEn = 0
$script:reintentoVence = 0
function ResetTurbo {
    $script:reintentoUltimo = $false; $script:ultimoRecursoPara = ''; $script:ultimoRecursoEn = 0
    $script:juegoActivo = $null; $script:relojMs = 100000; $script:logsF = @()
}
function CompF($etq, $ok, $det = '') {
    if (-not $ok) { $script:mal++ }
    "  {0}  {1}{2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $etq, $(if ("$det" -ne '') { "  -> $det" } else { '' })
}
# LA FRASE ES LA DEL 15/09, la que se pidio tres veces seguidas. En assistant.log.1 estan
# las tres: 11:23:23, 11:23:49 y 11:24:17, o sea 3 peticiones de turbo para el mismo audio
# en 54 segundos, ~12 s de espera cada una. De ahi salio la guarda de los 120 s. Desde que
# existe no ha vuelto a hacer falta: 0 lineas "ya se pidio para" en todo el registro, que
# es justamente la senal de que esto funciona.
$fraseTurbo = 'Quiero que veas que hay en mi pantalla y me digas que es lo que ves'
ResetTurbo
CompF 'la primera vez si se pide' (Request-UltimoRecurso $fraseTurbo $false $false 'procesar')
$script:reintentoUltimo = $false
$script:relojMs += 26000
CompF 'la segunda a los 26 s, NO (15/09 11:23:49)' (-not (Request-UltimoRecurso $fraseTurbo $false $false 'procesar')) ($script:logsF[-1])
$script:reintentoUltimo = $false
$script:relojMs += 28000
CompF 'ni la tercera a los 54 s (15/09 11:24:17)' (-not (Request-UltimoRecurso $fraseTurbo $false $false 'procesar'))
$script:reintentoUltimo = $false
$script:relojMs += 70000
CompF 'pasados los 120 s si, que ya es otra vez' (Request-UltimoRecurso $fraseTurbo $false $false 'procesar')
# JUGANDO NO. Turbo son ~12 s (y ~35 s si hay que cargarlo) y ~1 GB de RAM que ahora mismo
# es del juego; braya lo dijo asi: "si, pero no jugando".
ResetTurbo
$script:juegoActivo = 'It Takes Two'
CompF 'jugando, nunca' (-not (Request-UltimoRecurso $fraseTurbo $false $false 'procesar'))
# LO QUE PARECE CHARLA TAMPOCO, si no venia ya reconocida como orden: seria pagar 12 s por
# una frase que no era para Nova.
ResetTurbo
CompF 'lo que parece charla, no' (-not (Request-UltimoRecurso 'estoy jugando y me gusta mucho esto' $false $false 'procesar'))
ResetTurbo
CompF 'pero la misma frase ya reconocida, si' (Request-UltimoRecurso 'estoy jugando y me gusta mucho esto' $true $false 'procesar')
# Y LA MISMA GUARDA DEL OIDO FINO: sin una palabra de 4 letras, Test-MismoAudio tiraria lo
# que traiga turbo pase lo que pase, asi que esperarlo es regalar los 12 s.
ResetTurbo
CompF 'sin una palabra de 4 letras, no se pide' (-not (Request-UltimoRecurso 'No, no, no' $false $false 'procesar'))
# SIN WORKER NO HAY QUIEN REPASE: si se pidiera, nadie escribiria la respuesta y Nova se
# quedaria esperando su plazo entero para nada.
ResetTurbo
$script:wakeProc.HasExited = $true
CompF 'con la escucha muerta, no se pide' (-not (Request-UltimoRecurso $fraseTurbo $false $false 'procesar'))
$script:wakeProc.HasExited = $false
# Y CON TURBO APAGADO, nada: el 15/09 se apago en uso real.
ResetTurbo
$WhisperUltimo = ''
CompF 'con turbo apagado, no se pide' (-not (Request-UltimoRecurso $fraseTurbo $false $false 'procesar'))
$WhisperUltimo = 'large-v3-turbo'
# LO QUE DEJA PUESTO CUANDO SI SE PIDE: la marca para la escucha, el plazo, y la frase
# apuntada como dudosa para que no se aprenda de ella (ver NO APRENDER DE LO MAL OIDO).
ResetTurbo
$script:oidosDudosos = @{}
[void](Request-UltimoRecurso $fraseTurbo $false $false 'noentendi')
CompF 'al pedirlo deja la marca para la escucha' (Test-Path -LiteralPath $MarcaReintento)
CompF 'y se da un plazo, que no se espera bloqueando' ($script:reintentoVence -gt $script:relojMs) "$($script:reintentoVence - $script:relojMs) ms"
CompF 'y apunta la frase como mal oida, para no aprenderla' ($script:oidosDudosos.Count -eq 1) "$($script:oidosDudosos.Count)"
CompF 'y recuerda que hacer si turbo no contesta' ($script:reintentoAlFallar -eq 'noentendi') "$($script:reintentoAlFallar)"
Remove-Item -LiteralPath $dirFino -Recurse -Force -ErrorAction SilentlyContinue


if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
