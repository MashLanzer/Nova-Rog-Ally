# "X EN LA MITAD Y EN LA OTRA MITAD Y" (22/09 por la noche, idea 9).
#
# En catorce dias la pantalla dividida NO se ejecuto bien ni una sola vez por voz: cero de
# once intentos. Y la forma que braya usa de verdad -"abre X en la mitad y en la otra mitad
# Y"- no la cogia ninguno de los cuatro patrones que habia: la dijo tres veces en tres dias
# distintos (18/09 20:03, 20/09 18:55, 22/09 01:10) y las tres acabaron en el modelo, en una
# busqueda de Google equivocada o en una traduccion basura. La del 22 costo 68 segundos y
# acabo con braya cerrando el navegador a mano.
#
# Las dos guardas que lleva son la mitad del arreglo, y este banco esta sobre todo para
# ellas: sin la cola no glotona el caso con mas peligro no gana nada, y sin la guarda del
# volumen "pon el volumen a la mitad" se convertiria en una pantalla dividida.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre"; exit 1 }
    return $fn.Extent.Text
}
# REGLA DEL BANCO: se trae Split-Ordenes de verdad con TODO lo que necesita -sus funciones y
# sus variables-, leido del fichero. Copiar aqui cualquiera de estas listas seria probar la
# copia en vez del codigo, que en este repo ya ha pasado tres veces.
# LAS VARIABLES SE SACAN DEL ARBOL, NO CON UN REGEX: varias son tablas de varias lineas
# (VERBOS_IMPERATIVO son 20) y un regex de una linea se lleva media tabla, que es como
# salia "el literal de hash estaba incompleto".
function TraerVar([string]$nombre) {
    $asig = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $n.Left.VariablePath.UserPath -eq $nombre }, $true)
    if (-not $asig) { Write-Host "  MAL  no encuentro `$$nombre"; exit 1 }
    return $asig.Extent.Text
}
# LA LISTA ENTERA, INCLUIDAS LAS DE SEGUNDO NIVEL. Faltaban FILLER_INI, FILLER_FIN,
# FILLER_GLOBAL (las usa Remove-Filler) y VERBOS_CORTE/VERBOS_TEXTO (Add-CortesSinConector),
# y el sintoma no era un error: con $FILLER_GLOBAL vacio, el -replace casa en CADA posicion
# de la cadena y mete el reemplazo entre letra y letra. La frase salia como
# "a b r e y o u t u b e ..." y TODAS las comprobaciones rojas, con el codigo bien.
foreach ($nv in @('VERBOS', 'VERBOS_IMPERATIVO', 'VERBOS_OIDOS', 'VERBOS_LISTA', 'LOCATIVO', 'VENTANA',
                  'FILLER_INI', 'FILLER_FIN', 'FILLER_GLOBAL', 'VERBOS_CORTE', 'VERBOS_TEXTO')) {
    Invoke-Expression (TraerVar $nv)
}
foreach ($fn in @('ConvertTo-Plain', 'Get-Distancia', 'Repair-Verb', 'Repair-Words',
                  'Remove-Filler', 'Test-NombreConocido', 'Add-CortesSinConector',
                  'Split-Compound', 'Split-Ordenes')) {
    Invoke-Expression (Traer $fn)
}

# OJO CON EL RESULTADO: Split-Ordenes devuelve la lista de fragmentos, y envolverla con
# @() y unirla con ' | ' partia la cadena en caracteres sueltos ("d i v i d i r ..."), asi
# que TODAS las comprobaciones salian rojas con el codigo bien. Se une sin separador cuando
# ya viene una sola pieza.
function Uno([string]$frase) {
    $r = Split-Ordenes $frase
    if ($null -eq $r) { return '' }
    if ($r -is [string]) { return $r }
    return (($r | ForEach-Object { [string]$_ }) -join ' | ')
}

Write-Host ''
Write-Host '-- TUS FRASES, las once del log, no frases inventadas --'
# LA LECCION, Y ME LA COMI YO ANOCHE: la primera version de este banco probaba frases que yo
# habia escrito ("abre YouTube en la mitad y en la otra mitad abre Pinterest"), salio verde
# entera, y el patron cogia CERO de las once peticiones reales de braya. Sus frases dicen "la
# mitad DE LA PANTALLA y en la otra mitad", con el hueco en medio, y el patron pedia "mitad y"
# pegado. Un banco que prueba lo que escribio quien hizo el arreglo no prueba nada.
# Estas salen de assistant.log (09/09-23/09) tal y como las oyo Nova, con sus erratas.
$mias = @(
    'sobre youtube en la mitad de la pantalla y en la otra mitad abre painterest',
    'abre youtube a la mitad de la pantalla y en la otra mitad abre painterest',
    'no no es buscarlo en google es poner la mitad de una pantalla en pinterest y la otra mitad en youtube',
    'si pero abre youtube en la pantalla izquierda y pinterest en la pantalla derecha',
    'mira ponme un temporizador de 5 minutos abre el navegador y a pantalla dividida abre steam'
)
$cogidas = 0
foreach ($f in $mias) {
    $r = Uno $f
    $ok = $r -match 'dividir pantalla'
    if ($ok) { $cogidas++ }
    $corto = if ($f.Length -gt 44) { $f.Substring(0, 41) + '...' } else { $f }
    Write-Host ("       {0} {1,-44} -> {2}" -f $(if ($ok) { 'SI ' } else { 'no ' }), $corto, $r)
}
Comp 'de las cinco alcanzables, se cogen las cinco' ($cogidas -eq 5) "$cogidas de 5"
$r1 = Uno 'sobre youtube en la mitad de la pantalla y en la otra mitad abre painterest'
Comp 'la del 18/09 20:03, con el hueco en medio' ($r1 -match 'dividir pantalla youtube con painterest') $r1
$r2 = Uno 'abre youtube a la mitad de la pantalla y en la otra mitad abre painterest'
Comp 'la del 20/09 18:55, con "a la"' ($r2 -match 'dividir pantalla youtube con painterest') $r2
$r3 = Uno 'no no es buscarlo en google es poner la mitad de una pantalla en pinterest y la otra mitad en youtube'
Comp 'la del 18/09 19:03, al reves y con ruido delante' ($r3 -match 'dividir pantalla pinterest con youtube') $r3
# Y LA QUE SIGUE SIN COGERSE, dicha por su nombre para que nadie la de por hecha: el 22/09 a
# la 01:10 dijo "abre navegador en la mitad de la pantalla izquierda con painteress y en la
# otra mitad derecha abren navegador tambien con youtube". Lleva dos destinos pegados con
# "con" y un verbo en plural: sacarla de ahi pide otra regla, no este patron.
$r4 = Uno 'abre navegador en la mitad de la pantalla izquierda con painteress y en la otra mitad derecha abren navegador tambien con youtube'
Comp 'la del 22/09 01:10 NO se coge, y se dice' (-not ($r4 -match 'dividir pantalla navegador con')) 'pide otra regla; no se tapa'

Write-Host ''
Write-Host '-- el volumen y el brillo siguen siendo el volumen y el brillo --'
# HONESTIDAD SOBRE ESTA PARTE: con el patron tal y como esta, "pon el volumen a la mitad" no
# puede colarse aunque se quite la guarda, porque el patron EXIGE "y en la otra mitad" detras
# y nadie dice eso del volumen. Se comprobo quitando la guarda a proposito: el banco siguio
# verde. La guarda se queda -es una linea y protege si alguien relaja el patron-, pero lo que
# de verdad impide la colision es la exigencia de "la otra mitad", y eso es lo que se vigila
# abajo. Las tres frases de aqui valen igual: son el caso real de cada dia.
$v1 = Uno 'pon el volumen a la mitad'
Comp 'el volumen NO se vuelve pantalla dividida' ($v1 -notmatch 'dividir pantalla') $v1
$v2 = Uno 'pon el brillo a la mitad'
Comp 'el brillo tampoco' ($v2 -notmatch 'dividir pantalla') $v2
$v3 = Uno 'baja la musica a la mitad'
Comp 'ni la musica' ($v3 -notmatch 'dividir pantalla') $v3

Write-Host ''
Write-Host '-- y la cola no es glotona --'
# La frase real del 10/09. Con (.+)$ hasta el final, el segundo destino se llevaba la
# busqueda entera y Resolve-Target fallaba: cero ganancia en el caso con mas peligro.
$g = Uno 'abre YouTube en la mitad y en la otra mitad abre el navegador'
Comp 'el segundo destino es solo la app' ($g -match 'con el navegador$') $g
Comp 'el patron corta en la barra' ($fuente -match '\(\[\^\|\]\+\?\)') 'que es el separador que respeta Split-Compound'
# LO QUE DE VERDAD SEPARA ESTO DEL VOLUMEN: que haga falta "la otra mitad". Si alguien deja
# el patron en "X a la mitad" a secas, "pon el volumen a la mitad" se volveria una pantalla
# dividida, y eso si seria una orden que braya no dio.
# el patron nuevo: su linea, buscada por texto literal (nada de regex sobre un regex, que
# es como salieron cuatro rojos seguidos con el codigo bien)
$lineaM = @($fuente -split "`r?`n" | Where-Object { $_.Contains('otra') -and $_.Contains('-match') -and $_.Contains('mitad') })[0]
$patM = ''
if ($lineaM) {
    $a1 = $lineaM.IndexOf("-match '")
    if ($a1 -ge 0) {
        $a1 += 8
        $a2 = $lineaM.LastIndexOf("')")
        if ($a2 -gt $a1) { $patM = $lineaM.Substring($a1, $a2 - $a1) }
    }
}
Comp 'el patron nuevo se puede leer del fichero' ($patM.Length -gt 0) "$($patM.Length) caracteres"
Comp 'y exige "la otra mitad"' ($patM.Contains('otra')) 'es lo que lo separa del volumen'
Comp 'el volumen a secas NO casa' (-not ('pon el volumen a la mitad' -match $patM)) 'aunque se quitara la guarda'
Comp 'ni el brillo' (-not ('pon el brillo a la mitad' -match $patM))

Write-Host ''
Write-Host '-- y lo que ya funcionaba sigue igual --'
$y1 = Uno 'abre YouTube en la pantalla izquierda y Pinterest en la derecha'
Comp 'la forma izquierda/derecha' ($y1 -match 'dividir pantalla youtube con pinterest') $y1
$y2 = Uno 'abre Steam y el navegador en pantalla dividida'
Comp 'la forma "en pantalla dividida"' ($y2 -match 'dividir pantalla steam con el navegador') $y2
$y3 = Uno 'abre Steam a pantalla dividida'
Comp 'y la de una sola app' ($y3 -match 'dividir pantalla con steam') $y3

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  "en la mitad y en la otra mitad" ya es una pantalla dividida'
exit 0
