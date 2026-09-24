# "ESTO", "ESTE", "ESO": RESOLVERLO POR LA VENTANA QUE ESTA DELANTE (23/09, idea 2).
#
# EL DATO, y sobre todo su reparto: de las 41 frases suyas con un deictico sin referente,
#  - 16 son "hay alguna actualizacion de este" -el deictico CUELGA al final, detras de una
#    preposicion-: eso se puede sustituir;
#  - 20 son "este estado es cargando en steam" -ahi "este" lleva sustantivo detras, es oido
#    roto, no un deictico colgando-: ahi inventar un referente seria inventarse la frase, asi
#    que solo se ANOTA el titulo de la ventana en el prompt;
#  - y "abre este" no se resuelve NUNCA solo. Con el oido al 70,4 %, adivinar de una ventana
#    QUE abrir o QUE borrar es la regla 1 al reves: se pregunta, y como peligrosa.
#
# LO QUE VIGILA ESTE BANCO, por orden de importancia:
#  1. Que nada que empiece por un verbo salga de aqui listo para ejecutarse (regla 1).
#  2. Que sin ventana util no se invente ningun referente.
#  3. Que el paso siga viviendo en Process-Texto y no dentro de Resolve-Fragment: $FILLER_INI
#     lleva "este" en las muletillas de cabeza, asi que Remove-Filler se lo come ANTES. Si
#     alguien mueve el bloque, las 20 frases de "este estado..." dejan de verse. La
#     comprobacion 9 esta escrita justo para explicar eso el dia que se rompa.
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
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# UN BANCO QUE LLAMA A UNA FUNCION QUE NO EXISTE PASA EN VERDE (aprendido tres veces el
# 19/09): si no esta, se sale con error en vez de seguir.
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function TraerVar([string]$n) {
    $m = [regex]::Match($fuente, '(?m)^\$' + $n + ' = (.+)$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro la variable $n"; exit 1 }
    return $m.Groups[1].Value
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

foreach ($v in @('VERBOS', 'VERBOS_DEICTICO', 'RE_DEICTICO_ACCION', 'RE_DEICTICO_ORDEN',
                 'RE_DEICTICO_COLGANDO', 'RE_DEICTICO_SUELTO', 'FILLER_INI', 'FILLER_FIN', 'FILLER_GLOBAL')) {
    Invoke-Expression ('$' + $v + ' = ' + (TraerVar $v))
}
foreach ($f in @('Resolve-Deictico', 'Get-NombreDeTitulo')) { Invoke-Expression (Traer $f) }

Write-Host ''
Write-Host '-- 1. LO QUE EMPIEZA POR UN VERBO SE PREGUNTA, NUNCA SE HACE --'
$a1 = Resolve-Deictico 'abre este' 'Steam'
Comp '"abre este" se pregunta' ($a1.modo -eq 'preguntar') "modo=$($a1.modo)"
Comp 'y la frase queda nombrada, no a medias' ($a1.texto -eq 'abre steam') "$($a1.texto)"
$a2 = Resolve-Deictico 'borra esto' 'Documentos'
Comp '"borra esto" se pregunta' ($a2.modo -eq 'preguntar') "modo=$($a2.modo)"
$a3 = Resolve-Deictico 'cierra eso' 'Discord'
Comp '"cierra eso" se pregunta' ($a3.modo -eq 'preguntar')
$a4 = Resolve-Deictico 'desinstala esto' 'It Takes Two'
Comp '"desinstala esto" se pregunta' ($a4.modo -eq 'preguntar') 'y "desinstala" no esta en $VERBOS'
$a5 = Resolve-Deictico 'busca una guia de esto' 'Hollow Knight'
Comp 'y hasta "busca una guia de esto" se pregunta' ($a5.modo -eq 'preguntar') 'buscar abre una pestana: toca algo'

Write-Host ''
Write-Host '-- 2. el deictico que cuelga al final SI se sustituye --'
# Esta es la frase que dijo 16 veces.
$b1 = Resolve-Deictico 'hay alguna actualizacion de este' 'It Takes Two'
Comp 'la que dijo 16 veces se resuelve' ($b1.modo -eq 'sustituir') "modo=$($b1.modo)"
Comp 'y queda entera y con el nombre dentro' ($b1.texto -eq 'hay alguna actualizacion de It Takes Two') "$($b1.texto)"
$b2 = Resolve-Deictico 'ahora si algo se esta explicando en este' 'Hollow Knight'
Comp '"...se esta explicando en este" tambien' ($b2.modo -eq 'sustituir') "$($b2.texto)"
$b3 = Resolve-Deictico 'cuanto pesa esto' 'Steam'
Comp 'pero sin preposicion delante, no se toca' ($b3.modo -eq '') 'el deictico no cuelga de nada'

Write-Host ''
Write-Host '-- 3. el deictico con sustantivo detras SOLO se anota --'
# Esta es la que dijo 20 veces. Aqui "este" es determinante de "estado": no hay nada que
# sustituir, y ponerle un nombre seria cambiarle la frase.
$c1 = Resolve-Deictico 'este estado es cargando en steam' 'Steam'
Comp 'la que dijo 20 veces se anota' ($c1.modo -eq 'anotar') "modo=$($c1.modo)"
Comp 'y NO se sustituye nada' ($c1.texto -eq 'este estado es cargando en steam') "$($c1.texto)"
$c2 = Resolve-Deictico 'esto es un error de red' 'Chrome'
Comp '"esto es un error de red" se anota' ($c2.modo -eq 'anotar')

Write-Host ''
Write-Host '-- 4. SIN VENTANA UTIL NO SE INVENTA NADA --'
$sinV = @('abre este', 'hay alguna actualizacion de este', 'este estado es cargando en steam',
          'ahora si algo se esta explicando en este')
$bienV = 0
foreach ($f in $sinV) {
    $r = Resolve-Deictico $f ''
    if ($r.modo -eq '' -and $r.texto -eq '') { $bienV++ }
    else { Write-Host "       se invento: '$f' -> $($r.modo) / $($r.texto)" }
}
Comp 'las cuatro devuelven vacio sin ventana' ($bienV -eq 4) "$bienV de 4"

Write-Host ''
Write-Host '-- 5. "este juego" sigue siendo de $reJuegoDelante --'
$d1 = Resolve-Deictico 'este juego va lento' 'Chrome'
Comp '"este juego va lento" no se lo queda este paso' ($d1.modo -eq '') "modo=$($d1.modo)"
Comp 'y el paso entero lo descarta antes de mirar' ($fuente -match "notmatch '\^\(\?:este\|esta\|ese\|esa\)") 'ver el if de Process-Texto'

Write-Host ''
Write-Host '-- 6. el nombre que se dice en voz alta, sacado del titulo --'
Comp 'quita el contenedor del navegador' ((Get-NombreDeTitulo 'Steam Community :: It Takes Two - Google Chrome' 'chrome') -eq 'Steam Community :: It Takes Two')
Comp 'y el contador de mensajes de cabeza' ((Get-NombreDeTitulo '(3) WhatsApp' 'chrome') -eq 'WhatsApp')
$largo = 'Documento1 - Word - 3 paginas sin guardar y algo mas todavia'
Comp 'un titulo largo no es un nombre: vale el proceso' ((Get-NombreDeTitulo $largo 'winword') -eq 'winword') "$largo"
Comp 'un titulo vacio, tambien' ((Get-NombreDeTitulo '' 'eldenring') -eq 'eldenring')
Comp 'y un nombre con guion dentro no se parte' ((Get-NombreDeTitulo 'Half-Life 2' 'hl2') -eq 'Half-Life 2') 'la lista de contenedores es cerrada'

Write-Host ''
Write-Host '-- 7. POR QUE EL PASO VIVE EN Process-Texto Y NO EN Resolve-Fragment --'
# Esta comprobacion no prueba el deictico: prueba el SITIO. $FILLER_INI lleva "este" en las
# muletillas de cabeza, asi que si alguien mueve el bloque detras de Remove-Filler, las 20
# frases de "este estado..." dejan de verse. Si esta se pone roja, ahi esta el motivo.
Comp '"este" esta en las muletillas de cabeza' ('este estado es cargando en steam' -match $FILLER_INI) 'por eso Remove-Filler se lo come'
Invoke-Expression (Traer 'Remove-Filler')
$rf = Remove-Filler 'este estado es cargando en steam'
Comp 'y Remove-Filler se lo come de verdad' ($rf -notmatch '^este\b') "'$rf'"
Comp 'el bloque se llama sobre $plano, antes de eso' ($fuente -match 'DEICTICO, POR LA VENTANA DE DELANTE')

Write-Host ''
Write-Host '-- 8. EL BLOQUE DE VERDAD, SACADO DEL ARBOL Y EJECUTADO --'
# Aqui no se copia la logica: se saca el if entero de Process-Texto y se ejecuta con el resto
# del asistente hecho de mentira. Lo que se mira es POR DONDE sale cada frase.
$fnPT = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Process-Texto' }, $true)
if (-not $fnPT) { Write-Host '  MAL  no encuentro Process-Texto'; exit 1 }
$bloqueD = ''
foreach ($x in $fnPT.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
    # EL MAS PEQUENO QUE LO CONTENGA: FindAll baja tambien a los if de dentro, pero sobre
    # todo devuelve antes los de FUERA, y coger uno de esos traeria medio Process-Texto.
    $tx = $x.Extent.Text
    if ($tx -match 'DEICTICO: sin ventana util' -and $tx -match '^if \(\$DeicticoOn') { $bloqueD = $tx; break }
}
if (-not $bloqueD) { Write-Host '  MAL  no encuentro el bloque del deictico en Process-Texto'; exit 1 }

$DeicticoOn = $true
$script:invitado = $false
$script:pendiente = $null
$script:juegoActivo = ''
$script:deicticoNota = 'sucio'
$script:paso = ''
$script:ventanaFalsa = $null
$script:vecesVentana = 0
function Log([string]$m) { }
function Add-Estadistica($a, $b) { $script:paso = $a }
function Show-Popup([string]$t, [string]$e = 'hablando') { }
function Say([string]$t, [string]$e = '') { }
function Set-UI([string]$e, [string]$t = '', [int]$ms = 0) { }
function Start-Confirmacion { }
function Open-EscuchaTrasNoEntendi { }
function Send-Charla([string]$t, [bool]$d = $false, [string]$o = 'hablar', $x = $null, [bool]$e = $false) { $script:dicho = $t; return $true }
function Submit-Command([string]$t, [string]$m = 'accion', [string]$a = '') { $script:dicho = $t }
function Get-VentanaDelante { $script:vecesVentana++; return $script:ventanaFalsa }
function Test-SoloPregunta([string]$f) { return ($f -notmatch '^(?:abre|cierra|borra|desinstala|busca)\b') }
# LO QUE HOY RESUELVE EL CAMINO LOCAL, medido con "assistant.ps1 -Probar" el 23/09 y copiado
# aqui tal cual. Son las frases del banco que YA tienen dueno: el paso del deictico no puede
# robarselas, porque hoy contestan bien y al instante.
#   copia esto                       ->  copiar
#   borra esto                       ->  olvidar lo de hace un rato
#   este estado es cargando en steam ->  estado de las descargas
#   hay alguna actualizacion de este ->  estado de las descargas
#   abre este / cierra eso / desinstala esto / ahora si algo... ->  no lo resuelve nadie
$script:conDueno = @('copia esto', 'borra esto', 'este estado es cargando en steam',
                     'hay alguna actualizacion de este', 'pon musica')
function Test-FastCommand([string]$t) { return ($script:conDueno -contains $t.ToLowerInvariant()) }
Invoke-Expression (Traer 'ConvertTo-Plain')

# devuelve: por-donde;texto-final
function Enruta([string]$frase, $ventana, [string]$juego = '') {
    $script:juegoActivo = $juego
    $script:ventanaFalsa = $ventana
    $script:vecesVentana = 0
    $script:paso = ''
    $script:dicho = ''
    $script:pendiente = $null
    $script:deicticoNota = 'sucio'
    $seguido = $true
    $texto = $frase
    & {
        $text = $frase
        $plano = ConvertTo-Plain $frase
        Invoke-Expression $bloqueD
        $script:siguio = $true
        $script:textoFinal = $text
    }
    return @{ paso = $script:paso; dicho = $script:dicho; texto = $script:textoFinal
              pendiente = $script:pendiente; veces = $script:vecesVentana }
}

$vSteam = @{ titulo = 'Steam'; proceso = 'steam'; nombre = 'Steam' }
$r1 = Enruta 'abre este' $vSteam
Comp 'con Steam delante, "abre este" pregunta' ($r1.paso -eq 'deictico-preguntado') "paso=$($r1.paso)"
Comp 'y lo deja pendiente como PELIGROSA' ($r1.pendiente -and $r1.pendiente.tipo -eq 'peligrosa') 'solo vale un si hablado'
Comp 'y NO lo ejecuta ni lo manda a nadie' ($r1.dicho -eq '') "$($r1.dicho)"

$r2 = Enruta 'ahora si algo se esta explicando en este' $vSteam
Comp 'lo que iba al modelo se sustituye y sigue' ($r2.paso -eq 'deictico') "paso=$($r2.paso)"
Comp 'y la frase de salida lleva el nombre' ($r2.texto -eq 'ahora si algo se esta explicando en Steam') "$($r2.texto)"
Comp 'sin dejar nada pendiente' ($null -eq $r2.pendiente)

$r3 = Enruta 'esto es un error de red' $vSteam
Comp 'lo que nadie sabe hacer se anota' ($r3.paso -eq 'deictico-anotado') "paso=$($r3.paso)"
Comp 'y va a la charla con el titulo pegado' ($r3.dicho -match '\[lo que tengo delante: Steam\]') "$($r3.dicho)"
Comp 'y NO acaba en el agente' ($r3.dicho -ne '') 'el agente tiene acceso total'

$r4 = Enruta 'abre este' $null
Comp 'sin ventana, "abre este" no abre nada' ($r4.paso -eq 'deictico-sin-ventana') "paso=$($r4.paso)"
Comp 'y no deja nada pendiente que confirmar' ($null -eq $r4.pendiente)

$r5 = Enruta 'este juego va lento' $vSteam
Comp '"este juego va lento" pasa de largo' ($r5.paso -eq '') "paso=$($r5.paso)"
Comp 'y llega al enrutado sin tocar' ($r5.texto -eq 'este juego va lento') "$($r5.texto)"
# LA VENTANA NI SE MIRA: es lo que hace util el filtro de cabeza del if. Sin el, la frase
# entraria, pediria la ventana a Windows y saldria por donde ha entrado: trabajo para nada en
# el camino de CADA frase que lleve "este".
Comp 'y ni se pregunta a Windows que hay delante' ($r5.veces -eq 0) "$($r5.veces) veces"


$r6 = Enruta 'pon musica' $vSteam
Comp 'y una orden normal ni entra' ($r6.paso -eq '') "paso=$($r6.paso)"
Comp 'ni ella pregunta por la ventana' ($r6.veces -eq 0) "$($r6.veces) veces"

Write-Host ''
Write-Host '-- 8b. LO QUE YA TIENE DUENO NO SE TOCA --'
# Esto es lo que salio de medirlo, y es lo que cambio el plan: de las 599 frases de los tres
# ficheros de pruebas, solo DOS entran en los patrones, y las dos ya se resuelven hoy en
# local. Un paso nuevo que se las quitara no arreglaria nada y romperia dos cosas que van.
$r7 = Enruta 'copia esto' $vSteam
Comp '"copia esto" sigue siendo un Ctrl+C' ($r7.paso -eq '') "paso=$($r7.paso)"
Comp 'y sale de aqui sin tocar' ($r7.texto -eq 'copia esto') "$($r7.texto)"
Comp 'y ni se pregunta que hay delante' ($r7.veces -eq 0) "$($r7.veces) veces"
$r8 = Enruta 'borra esto' $vSteam
Comp '"borra esto" sigue olvidando el ultimo dato' ($r8.paso -eq '') "paso=$($r8.paso)"
Comp 'y no se pregunta nada' ($null -eq $r8.pendiente)
$r9 = Enruta 'este estado es cargando en steam' $vSteam
Comp 'la de las 20 veces ya contesta hoy: no se toca' ($r9.paso -eq '') "paso=$($r9.paso)"
$r10 = Enruta 'hay alguna actualizacion de este' $vSteam
Comp 'y la de las 16, igual: contesta en 0 ms' ($r10.paso -eq '') "paso=$($r10.paso)"
Comp 'sustituirla la mandaria al modelo, que tarda mas' ($r10.texto -eq 'hay alguna actualizacion de este')
# Y CON UN JUEGO DELANTE, que es como braya habla la mitad del tiempo. Aqui el nombre no sale
# de la ventana sino de $script:juegoActivo, asi que no basta con no preguntar por la ventana:
# hace falta la segunda guarda o "copia esto" se convertiria en "copia It Takes Two".
$r11 = Enruta 'copia esto' $null 'It Takes Two'
Comp 'con un juego delante, "copia esto" tampoco se toca' ($r11.paso -eq '') "paso=$($r11.paso)"
Comp 'y no se pregunta nada' ($null -eq $r11.pendiente) "$(if ($r11.pendiente) { $r11.pendiente.texto } else { '' })"
$r12 = Enruta 'abre este' $null 'It Takes Two'
Comp 'pero "abre este" con el juego delante SI pregunta' ($r12.paso -eq 'deictico-preguntado') "paso=$($r12.paso)"
Comp 'y pregunta por el juego, no por la ventana' ($r12.pendiente -and $r12.pendiente.texto -eq 'abre It Takes Two') "$(if ($r12.pendiente) { $r12.pendiente.texto } else { '' })"

Write-Host ''
Write-Host '-- 9. nada se queda encendido (regla 2) --'
# Lo unico que este paso deja vivo es la confirmacion, y esa ya trae dos salidas y plazo. Ni
# una variable de sesion mas: lo que hubo se quito, porque una variable que se pone y se
# vacia sin que nadie la lea es estado muerto.
Comp 'ni "sustituir" ni "anotar" dejan nada pendiente' (($null -eq $r2.pendiente) -and ($null -eq $r3.pendiente))
Comp 'y no queda ninguna nota de sesion' ($fuente -notmatch 'deicticoNota') 'no la leia nadie'
$gv = SinComentarios (Traer 'Get-VentanaDelante')
Comp 'la ventana se cachea, y poco' ($gv -match '-lt 800') 'menos de lo que tarda en decir dos frases'
Comp 'y no recorre los 200 procesos' ($gv -notmatch 'Get-Process -ErrorAction') 'medido el 21/09: eso cuesta 500-740 ms'
Comp 'la capsula de Nova nunca es la ventana' ($gv -match '\$script:uiProc' -and $gv -match '\$PID')

Write-Host ''
Write-Host '-- 10. la red de atras, la de verdad --'
Invoke-Expression (Traer 'Test-SoloPregunta')
Comp 'existe y guarda la duda como Test-FastCommand' ((SinComentarios (Traer 'Test-SoloPregunta')) -match 'finally \{ \$script:dudosa = \$dudosaAntesP \}')
Comp 'y mira $AccionesQueTocan, no una lista suya' ((SinComentarios (Traer 'Test-SoloPregunta')) -match '\$AccionesQueTocan -contains')

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  esto ya sabe a que te refieres'
exit 0
