# A QUE PODEMOS JUGAR LOS DOS (23/09, funcion 9 de la tanda de funciones nuevas).
#
# De donde sale: de su propia biblioteca. Contado de sus doce fichas: OCHO de sus juegos son de
# dos -siete cooperativos y uno, 5D Chess, uno contra otro-, cuatro se juegan a pantalla
# partida y TRES -A Way Out, The Past Within y Content Warning- NO SE PUEDEN JUGAR SOLO.
# Ademas juega a Roblox con su novia y tiene It Takes Two en su memoria de juegos. Nova tenia
# todo eso delante y no sabia decir cual es cual.
#
# Lo que se prueba aqui:
#   1. Que el dato NO se lo invente nadie: sale de la ficha de la tienda de Steam, que es
#      publica y no lleva clave, y se guarda para no volver a pedirla.
#   2. Que la diferencia que importa en ESTA consola se diga: braya tiene UNA pantalla.
#      "a pantalla partida aqui mismo" y "hace falta otro aparato" no son la misma respuesta.
#   3. Que juntos y uno contra otro no se mezclen: 5D Chess se juega a pantalla partida, si,
#      pero uno contra otro. Meterlo con A Way Out es contestar mal a lo que pregunto.
#   4. QUE LA FRASE QUE NOVA ENSENA FUNCIONE. Cuando no sabe de un juego dice como apuntarlo;
#      si esa frase no casa con ningun patron, le manda a un callejon sin salida. Se comprueba
#      metiendo por los patrones la frase que ella misma dice.
#   5. Que preguntar no sea apuntar. Hablando, "elden ring es de dos" es la pregunta.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$lineas = [System.IO.File]::ReadAllLines($ruta)
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
# las funciones DE VERDAD, leidas del fichero. Copiarlas aqui seria probar la copia.
$LogDir = $raiz
$MemoriaDir = Join-Path $raiz 'memoria'
function Log([string]$m) { }
foreach ($n in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-Distancia', 'Get-JuegosSteam',
                 'Get-NombreJuegoLimpio', 'Get-JuegosMem', 'Get-JuegosXbox', 'Update-Juegos',
                 'Find-JuegoEn', 'Find-Juego', 'Get-RutaJuegosDos', 'Get-JuegosDos',
                 'Save-JuegosDos', 'Get-FichaDos', 'Get-FichaDosSteam', 'Set-JuegoDos',
                 'Update-JuegosDosUno', 'Get-ParaDos', 'Join-Con')) {
    Invoke-Expression (Traer $n)
}
$script:Juegos = @(); $script:JuegosStamp = [datetime]'2000-01-01'
$script:ClavesJuegos = $null; $script:juegosDosCache = $null; $script:juegosDosFallos = 0

# los patrones, leidos de sus lineas (no copiados)
function PatronesDe([string]$marca) {
    $res = @()
    for ($i = 0; $i -lt $lineas.Count; $i++) {
        $l = $lineas[$i]
        if ($l -notmatch "\`$f -match '") { continue }
        if ($l -notmatch $marca) { continue }
        $a = $l.IndexOf("-match '") + 8
        $b = $l.LastIndexOf("'")
        if ($b -gt $a) { $res += $l.Substring($a, $b - $a) }
    }
    return $res
}
# el bloque entero de la funcion 9, de su comentario al de las descargas
$i1 = $fuente.IndexOf('# A QUE PODEMOS JUGAR LOS DOS (23/09, funcion 9)')
$i2 = $fuente.IndexOf('# DESCARGAS DE STEAM (F5)', $i1)
$bloque = if ($i1 -ge 0 -and $i2 -gt $i1) { $fuente.Substring($i1, $i2 - $i1) } else { '' }
# y las FUNCIONES, que viven mil lineas mas arriba y son otro trozo. Al principio este banco
# buscaba "store.steampowered" dentro del bloque de los PATRONES y salia rojo con el codigo
# bien: dos sitios distintos, dos rebanadas distintas.
$j1 = $fuente.IndexOf('# ===================== A QUE PODEMOS JUGAR LOS DOS')
$j2 = $fuente.IndexOf('# CUANTA RAM, Y DE QUIEN', $j1)
$blofun = if ($j1 -ge 0 -and $j2 -gt $j1) { $fuente.Substring($j1, $j2 - $j1) } else { '' }
function SacaPatrones([string]$txt) {
    $res = @()
    foreach ($l in ($txt -split "`r?`n")) {
        if ($l -notmatch "-match '") { continue }
        $a = $l.IndexOf("-match '") + 8
        $b = $l.LastIndexOf("'")
        if ($b -gt $a) { $res += $l.Substring($a, $b - $a) }
    }
    return $res
}
$patsBloque = @(SacaPatrones $bloque)
# LOS IF ENTEROS, DEL ARBOL Y EN SU ORDEN. Esto es lo que faltaba: antes se probaban los
# patrones uno a uno a ver si ALGUNO casaba, y asi no se ve que el de la pregunta se coma
# las frases de apuntar. Resolve-Fragment se para en el PRIMERO que casa, y eso es lo que
# hay que reproducir.
$ifsDos = @()
foreach ($x in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
    $t = $x.Extent.Text
    if ($t -match "kind = 'paraDos'" -or $t -match "kind = 'apuntaDos'") { $ifsDos += $t }
}
# lo que haria Resolve-Fragment con esta frase: el primer if que devuelva algo
function Resuelve([string]$frase) {
    foreach ($bloqueIf in $ifsDos) {
        # con @(): el if devuelve un array de uno y PowerShell lo aplana a hashtable,
        # y entonces [0] es 'la clave 0', que no existe
        $acc = @(& { $f = $frase; Invoke-Expression $bloqueIf })
        if ($acc -and $acc[0]) { return $acc[0] }
    }
    return $null
}

Write-Host ''
Write-Host '-- los patrones estan y se leen del fichero --'
Comp 'el bloque de la funcion 9 se encuentra' ($bloque.Length -gt 400) "$($bloque.Length) caracteres"
Comp 'y trae varios patrones' ($patsBloque.Count -ge 7) "$($patsBloque.Count) patrones"

Write-Host ''
Write-Host '-- como se pregunta esto hablando --'
$preguntas = @(
    'a que podemos jugar los dos',
    'que podemos jugar los dos',
    'que juego podemos jugar juntos',
    'a que podemos jugar con mi novia',
    'que tengo para dos',
    'que juegos tengo para jugar juntos',
    'que juegos hay para dos jugadores',
    'se puede jugar elden ring los dos',
    'elden ring es de dos',
    'a way out es cooperativo'
)
[void](Update-Juegos)      # Find-Juego mira la biblioteca de verdad
$cogidas = 0
foreach ($f in $preguntas) {
    $a = Resuelve $f
    $ok = ($null -ne $a) -and ([string]$a.kind -eq 'paraDos')
    if ($ok) { $cogidas++ }
    Write-Host ("       {0} {1,-52} {2}" -f $(if ($ok) { 'SI ' } else { 'no ' }), $f, $(if ($a) { [string]$a.kind } else { '(nada)' }))
}
Comp 'las coge todas, y como PREGUNTA' ($cogidas -eq $preguntas.Count) "$cogidas de $($preguntas.Count)"

Write-Host ''
Write-Host '-- y una orden normal no se convierte en esto --'
# Del registro de braya, tal y como las oyo Nova.
foreach ($f in @('sube el volumen', 'abre steam', 'que hora es', 'abre elden ring',
                 'cuanto le queda a elden ring', 'que juegos tengo', 'cierra el navegador',
                 'pon el modo juego', 'cuanta bateria me queda')) {
    $toca = @($patsBloque | Where-Object { $f -match $_ }).Count
    Comp "'$($f.Substring(0,[Math]::Min(34,$f.Length)))' sigue su camino" ($toca -eq 0)
}

Write-Host ''
Write-Host '-- el dato sale de Steam, no de un modelo --'
Comp 'el bloque de funciones se encuentra' ($blofun.Length -gt 1500) "$($blofun.Length) caracteres"
Comp 'pide la ficha de la tienda' ($blofun -match 'store\.steampowered\.com/api/appdetails') 'appdetails'
Comp 'sin clave de API' ($blofun -notmatch 'appdetails[^"]*key=') 'esta es publica, la de amigos no'
Comp 'y en espanol' ($blofun -match 'l=spanish')
Comp 'no hay ninguna llamada a un modelo' ($blofun -notmatch '(?i)ollama|anthropic|claude|gemini|charla_worker')
Comp 'se guarda para no repetir la peticion' ($blofun -match 'juegos-dos\.json')
Comp 'con escritura atomica' ($blofun -match 'Move-Item -LiteralPath \$tmp')
$fichero = Join-Path $MemoriaDir 'juegos-dos.json'
Comp 'y el fichero ya esta lleno' (Test-Path -LiteralPath $fichero) $fichero
# Y LOS NUMEROS DEL COMENTARIO SE CUENTAN DEL FICHERO. La cabecera decia siete de dos y
# dos que solo se pueden de dos; contando las fichas de verdad son ocho y tres. Un numero
# citado que no se puede reproducir es lo que la casa no tolera, asi que se comprueba.
if (Test-Path -LiteralPath $fichero) {
    $jj = Get-Content -LiteralPath $fichero -Raw -Encoding UTF8 | ConvertFrom-Json
    $todas = @($jj.PSObject.Properties | ForEach-Object { $_.Value })
    $nDos = @($todas | Where-Object { $_.dos }).Count
    $nSolo = @($todas | Where-Object { $_.dos -and -not $_.solo }).Count
    $nPart = @($todas | Where-Object { $_.dos -and $_.partida }).Count
    $cab = ([System.IO.File]::ReadAllText($ruta)).Substring($j1, 1200)
    Comp 'el comentario dice cuantos son de dos, y cuadra' ($cab -match 'OCHO' -and $nDos -eq 8) "$nDos de dos"
    Comp 'y cuantos SOLO de dos' ($cab -match 'TRES' -and $nSolo -eq 3) "$nSolo solo de dos"
    Comp 'y cuantos a pantalla partida' ($cab -match 'Cuatro se juegan a pantalla partida' -and $nPart -eq 4) "$nPart a pantalla partida"
}

Write-Host ''
Write-Host '-- una ficha inventada, para ver que la traduce bien --'
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("dos-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
$realMem = $MemoriaDir
try {
    $MemoriaDir = $tmpDir
    $script:juegosDosCache = $null
    [void](Update-Juegos)
    $t = @{}
    foreach ($j in $script:Juegos) {
        $nm = [string]$j.nombre
        $f = @{ nombre = $nm; solo = $true; dos = $false; coop = $false; partida = $false
                online = $false; remote = $false; contra = $false; fuente = 'prueba' }
        if ($nm -match '(?i)^a way out')   { $f.dos = $true; $f.coop = $true; $f.partida = $true; $f.online = $true; $f.solo = $false }
        if ($nm -match '(?i)^unravel two') { $f.dos = $true; $f.coop = $true; $f.partida = $true }
        if ($nm -match '(?i)^content warning') { $f.dos = $true; $f.coop = $true; $f.online = $true; $f.solo = $false }
        if ($nm -match '(?i)^5d chess')    { $f.dos = $true; $f.coop = $false; $f.contra = $true; $f.partida = $true }
        # los que NO son de Steam se quedan sin ficha a proposito: son justo el caso de
        # "de esto no lo se, dime como apuntarlo", que es lo que se comprueba abajo.
        if ($j.id -notmatch '^\d+$') { continue }
        $t[[string]$j.id] = $f
    }
    Save-JuegosDos $t
    $script:juegosDosCache = $t
    $r = Get-ParaDos
    Write-Host ("       " + $r)
    Comp 'los de la misma pantalla van primero' ($r -match 'en la misma pantalla, A Way Out')
    Comp 'y los de en linea aparte' ($r -match 'en linea, Content Warning')
    Comp 'uno contra otro NO se mezcla con juntos' (($r -match 'uno contra otro, 5D Chess') -and
        ($r -notmatch 'misma pantalla,[^;]*5D Chess')) '5D Chess es a pantalla partida, pero contra'
    Comp 'dice cuales solo se pueden de dos' ($r -match 'A Way Out y Content Warning no se pueden jugar de otra manera')
    Comp 'y los de un jugador no se ofrecen' ($r -notmatch 'Black Myth') 'ni Wallpaper Engine'
    Comp 'lo que no sabe lo dice' ($r -match 'no lo se')

    # LA FRASE QUE ENSENA TIENE QUE FUNCIONAR (esto es lo que se rompio a proposito)
    $ensenada = ''
    if ($r -match 'dime "([^"]+)"') { $ensenada = $Matches[1] }
    Comp 'ensena una frase para apuntarlo' ($ensenada.Length -gt 10) $ensenada
    # Y TIENE QUE LLEGAR A APUNTAR, no a preguntar. Se comprobo rompiendolo dos veces:
    # (a) cambiando la frase ensenada por "Minecraft es de dos", que casa con la PREGUNTA;
    # (b) dejando los patrones en el orden en que nacieron -pregunta primero-, con el que
    #     "apunta que Minecraft es de dos" tambien caia en la pregunta, con el juego
    #     llamandose "apunta que Minecraft". La rama de apuntar era codigo muerto entero.
    $aE = Resuelve $ensenada
    Comp 'y esa frase apunta de verdad, no pregunta' (($null -ne $aE) -and ([string]$aE.kind -eq 'apuntaDos')) $(if ($aE) { [string]$aE.kind } else { '(nada)' })

    # y preguntar NO es apuntar
    $rUno = Get-ParaDos 'a way out'
    Comp 'por un juego suelto contesta lo suyo' ($rUno -match 'A Way Out si es de dos') $rUno
    Comp 'y avisa de que no se puede jugar solo' ($rUno -match 'solo de dos')
    $rSolo = Get-ParaDos 'black myth wukong'
    Comp 'y de uno dice que es de uno' ($rSolo -match 'es de un jugador')

    # LA CONJUNCION NO SE DOBLA. Los trozos se unen con ' y ', asi que un trozo que
    # empiece por 'o' daba "en linea y o invitandola con Remote Play Together".
    $t2 = Get-JuegosDos
    foreach ($kk in @($t2.Keys)) { if ($t2[$kk].nombre -match '(?i)^content warning') { $t2[$kk].remote = $true; $t2[$kk].partida = $false } }
    $script:juegosDosCache = $t2
    $rRP = Get-ParaDos 'content warning'
    Comp 'la frase no dobla la conjuncion' ($rRP -notmatch ' y o ') $rRP

    # apuntar a mano un juego que no esta en Steam
    Set-JuegoDos 'Roblox' $true
    $script:juegosDosCache = $null
    $rRo = Get-ParaDos 'roblox'
    Comp 'lo que apunta braya se guarda y se lee' ($rRo -match 'Roblox si es de dos') $rRo
} finally {
    $MemoriaDir = $realMem
    $script:juegosDosCache = $null
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- apuntar y preguntar no se pisan --'
foreach ($par in @(
    @('apunta que roblox es de dos',     'apuntaDos'),
    @('apuntame que roblox es de dos',   'apuntaDos'),
    @('roblox si es de dos',             'apuntaDos'),
    @('roblox no es de dos',             'apuntaDos'),
    @('roblox es de dos',                'paraDos'),
    @('elden ring es de dos',            'paraDos'),
    @('se puede jugar elden ring los dos', 'paraDos'))) {
    $a = Resuelve $par[0]
    $kk = if ($a) { [string]$a.kind } else { '(nada)' }
    Comp ("'" + $par[0] + "'") ($kk -eq $par[1]) "$kk (se esperaba $($par[1]))"
}
Write-Host ''
Write-Host '-- el relleno es de fondo, y no molesta a la partida --'
$uno = ((Traer 'Update-JuegosDosUno') -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'una ficha por vuelta, no una rafaga' ($uno -match '\$pend\[0\]') 'doce juegos = seis minutos de fondo'
Comp 'no insiste si no hay red' ($uno -match 'juegosDosFallos -ge 3') 'tres fichas sin respuesta'
Comp 'pero el candado se cura solo' ($uno -match 'juegosDosPausaHasta = \$sw\.ElapsedMilliseconds \+ 600000') 'diez minutos, no toda la sesion'
# Y LA PUERTA DE ENTRADA TIENE QUE SER LA DEL RELOJ. Con la vieja ('-ge 3 y vuelve') el
# candado se echaba para toda la sesion, y la linea de arriba seguia existiendo mas
# abajo sin servir para nada: el banco salia verde con el fallo puesto.
$primeraU = (($uno -split "`n") | Where-Object { $_ -match 'return \$false' } | Select-Object -First 1)
Comp 'y la puerta de entrada mira el reloj' ($primeraU -match 'juegosDosPausaHasta') $primeraU.Trim()
Comp 'y un appid raro no bloquea la cola' ($uno -match "fuente = 'sin-ficha'") 'el 228980, instalado aqui, devuelve success=False'
# EL TROZO DEL BUCLE, ENTERO Y SIN COMENTARIOS. Estas dos comprobaciones nacieron
# ancladas a una linea suelta y a lo que habia DEBAJO de ella; al mover la lupa al bucle
# se cayeron solas con el codigo bien. Ahora se mira el bloque completo.
$b1 = $fuente.IndexOf('    # UNA FICHA DE JUEGO POR VUELTA')
# ACOTADO POR LINEAS, no por el primer '} catch {}': quitando el try/catch de aqui, el
# IndexOf se iba a buscar el del bloque siguiente y el trozo seguia teniendo uno. Salia
# verde justo cuando la guarda que se comprueba ya no existia.
$lineasRell = @(($fuente -split "`r?`n"))
$nb = 0; for ($q = 0; $q -lt $lineasRell.Count; $q++) { if ($lineasRell[$q] -match 'UNA FICHA DE JUEGO POR VUELTA') { $nb = $q; break } }
$trozoRelleno = if ($nb -gt 0) { (($lineasRell[$nb..([Math]::Min($nb + 16, $lineasRell.Count - 1))]) | Where-Object { $_ -notmatch '^\s*#' }) -join "`n" } else { '' }
Comp 'el bloque del relleno se encuentra' ($trozoRelleno.Length -gt 60) "$($trozoRelleno.Length) caracteres de codigo"
Comp 'no se rellena con un juego delante' ($trozoRelleno -match '-not \(Get-JuegoEnPrimerPlano\)')
Comp 'ni con una pregunta esperando' ($trozoRelleno -match '-not \$script:pendiente')
Comp 'ni mientras Nova esta ocupada' (($trozoRelleno -match '-not \$script:busy') -and ($trozoRelleno -match '-not \$script:armed'))
Comp 'ni mientras habla' ($trozoRelleno -match 'ElapsedMilliseconds -ge \$script:pausaHasta') 'es una llamada de red SINCRONA dentro del bucle'
Comp 'y si falla no tumba el bucle' (($trozoRelleno -match 'try \{') -and ($trozoRelleno -match '\} catch \{\}')) 'una excepcion de red no puede apagar a Nova'
# SIN LOS COMENTARIOS: al quitar filters=categories de la URL este banco seguia verde,
# porque la palabra estaba en el comentario de encima explicando por que se pone.
$ficha = ((Traer 'Get-FichaDosSteam') -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'la peticion tiene tope de tiempo' ($ficha -match 'TimeoutSec 3') 'corre en el bucle: 3 s de techo'
Comp 'y pide solo las categorias' ($ficha -match 'filters=categories') 'medido: 606-808 bytes en vez de 14.725-29.108'
Comp 'y si Steam no contesta, devuelve nada' ($ficha -match 'return \$null')

Write-Host ''
Write-Host '-- y con SU biblioteca de verdad --'
$script:juegosDosCache = $null
$rReal = Get-ParaDos
Write-Host ("       " + $rReal)
Comp 'contesta algo util' ($rReal -match 'Para dos tienes')
Comp 'y no se inventa un juego que no tiene' ($rReal -notmatch '(?i)it takes two') 'no esta instalado ahora'

Write-Host ''
if ($fallos) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  sabe a que podeis jugar los dos, y de donde lo ha sacado'
exit 0
