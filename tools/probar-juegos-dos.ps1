# A QUE PODEMOS JUGAR LOS DOS (23/09, funcion 9 de la tanda de funciones nuevas).
#
# De donde sale: de su propia biblioteca. De los doce juegos que tiene instalados SIETE son de
# dos, y tres -A Way Out, The Past Within y Content Warning- NO SE PUEDEN JUGAR SOLO. Ademas
# juega a Roblox con su novia y tiene It Takes Two en su memoria de juegos. Nova tenia todo eso
# delante y no sabia decir cual es cual.
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
# y los de APUNTAR por separado: de "LO QUE BRAYA APUNTA A MANO" hasta el final del bloque
$k1 = $bloque.IndexOf('# LO QUE BRAYA APUNTA A MANO')
$patsApunta = @(if ($k1 -ge 0) { SacaPatrones ($bloque.Substring($k1)) })

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
$cogidas = 0
foreach ($f in $preguntas) {
    $ok = @($patsBloque | Where-Object { $f -match $_ }).Count -gt 0
    if ($ok) { $cogidas++ }
    Write-Host ("       {0} {1}" -f $(if ($ok) { 'SI ' } else { 'no ' }), $f)
}
Comp 'las coge todas' ($cogidas -eq $preguntas.Count) "$cogidas de $($preguntas.Count)"

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
    # Y TIENE QUE CASAR CON EL PATRON DE APUNTAR, no con cualquiera. Se comprobo rompiendolo:
    # cambiando la frase ensenada por "Minecraft es de dos" el banco seguia verde, porque esa
    # frase casa... con la PREGUNTA. Nova le habria ensenado a preguntar otra vez lo mismo.
    $casa = @($patsApunta | Where-Object { $ensenada -match $_ }).Count
    Comp 'y esa frase apunta de verdad, no pregunta' ($casa -gt 0) 'si no, es un callejon sin salida'

    # y preguntar NO es apuntar
    $rUno = Get-ParaDos 'a way out'
    Comp 'por un juego suelto contesta lo suyo' ($rUno -match 'A Way Out si es de dos') $rUno
    Comp 'y avisa de que no se puede jugar solo' ($rUno -match 'solo de dos')
    $rSolo = Get-ParaDos 'black myth wukong'
    Comp 'y de uno dice que es de uno' ($rSolo -match 'es de un jugador')

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
Write-Host '-- el relleno es de fondo, y no molesta a la partida --'
$uno = Traer 'Update-JuegosDosUno'
Comp 'una ficha por vuelta, no una rafaga' ($uno -match '\$pend\[0\]') 'doce juegos = seis minutos de fondo'
Comp 'no insiste si no hay red' ($uno -match 'juegosDosFallos -ge 3') 'tres fallos y para'
$codigoBucle = ($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'no se rellena con un juego delante' ($codigoBucle -match 'if \(-not \(Get-JuegoEnPrimerPlano\)\) \{ \[void\]\(Update-JuegosDosUno\)')
Comp 'y si falla no tumba el bucle' ($fuente -match '\} catch \{\}\r?\n\r?\n    # la lupa se quita sola')
$ficha = Traer 'Get-FichaDosSteam'
Comp 'la peticion tiene tope de tiempo' ($ficha -match 'TimeoutSec 5') 'no se cuelga esperando a Steam'
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
