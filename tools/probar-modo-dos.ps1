# EL MODO "ESTAMOS DOS" YA EXISTE: ESTE BANCO LO DEMUESTRA (23/09, idea 17).
#
# La idea era un modo nuevo para las sesiones de dos jugadores. NO se hace: seria un cuarto
# sitio donde se guardan listas de ordenes con nombre, teniendo ya perfiles, montajes y
# recetas. Lo que le falta a braya no es codigo, es la frase:
#
#     "crea el modo estamos dos: abre it takes two y abre discord"
#     "modo estamos dos"        para ponerlo
#     "modo normal"             para salir
#
# Ocho de sus doce juegos son de dos y tres solo se pueden jugar de dos; It Takes Two, 5 h 38
# el 15/09, 3 h 12 el 22/09, 2 h 45 el 20/09. Un modo para sesiones de SEIS HORAS es justo el
# candidato a quedarse puesto, asi que lo que este banco vigila de verdad es la salida: que
# 'modo normal' devuelva el brillo y el volumen EXACTOS, y que Nova diga lo que hizo y nada
# mas -prometer que ha "salido del modo" cuando solo ha tocado dos cosas seria mentir-.
$ErrorActionPreference = 'Stop'
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
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
# EL TROZO DE VERDAD, NO UNA COPIA: los dos ejecutores del modo viven dentro de un switch de
# mil lineas, asi que se saca el caso contando llaves sobre el codigo real. Reescribirlos aqui
# seria probar lo que yo creo que hace Nova, no lo que hace.
function TraerCaso([string]$nombre) {
    $i = $fuente.IndexOf("'$nombre' {")
    if ($i -lt 0) { Write-Host "  MAL  no encuentro el caso $nombre"; exit 1 }
    $j = $fuente.IndexOf('{', $i)
    $n = 0
    for ($k = $j; $k -lt $fuente.Length; $k++) {
        if ($fuente[$k] -eq '{') { $n++ }
        elseif ($fuente[$k] -eq '}') { $n--; if ($n -eq 0) { return $fuente.Substring($j + 1, $k - $j - 1) } }
    }
    Write-Host "  MAL  el caso $nombre no cierra"; exit 1
}
# Y lo mismo con el if que resuelve "modo X": es una rama dentro de Resolve-Fragment, que
# depende de medio fichero. Se saca la rama entera del arbol y se le pone un marco.
function TraerRama([string]$dentro) {
    $r = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.IfStatementAst] -and
        $x.Clauses[0].Item1.Extent.Text -like "*$dentro*" }, $true)
    if (-not $r) { Write-Host "  MAL  no encuentro la rama con $dentro"; exit 1 }
    return $r.Extent.Text
}

# --- el mundo de mentira ----------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('modo-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$cmdsPath = Join-Path $tmp 'commands.json'
[System.IO.File]::WriteAllText($cmdsPath, '{"apps":{},"perfiles":{}}', (New-Object System.Text.UTF8Encoding($false)))
$script:cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cmds = $script:cmds
$script:invitado = $false
$script:hondoPerfil = 0
$script:dudosa = ''
$script:antesDeModo = $null
$script:brillo = 42
$script:volumen = 17
$script:tocado = @()
$script:dicho = @()
function Log([string]$m) { }
function Write-Atomico([string]$r, [string]$t, [bool]$bom = $false) {
    [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false)))
}
function Get-BrilloActual { return $script:brillo }
function Set-Brillo([int]$v) { $script:brillo = $v; $script:tocado += "brillo=$v"; return $true }
class AX {
    static [int] LeerVolumen() { return [int](Get-Variable -Name volumen -Scope Script -ValueOnly) }
    static [void] PonerVolumen([int]$v) {
        Set-Variable -Name volumen -Scope Script -Value $v
        Set-Variable -Name tocado -Scope Script -Value ((Get-Variable -Name tocado -Scope Script -ValueOnly) + "volumen=$v")
    }
}
foreach ($f in @('ConvertTo-Plain', 'Test-Prop', 'Get-Distancia', 'Add-Perfil')) { Invoke-Expression (Traer $f) }
# las dos de partir frases no hacen falta enteras: aqui cada linea del perfil es una orden
function Repair-Words([string]$t) { return $t }
function Split-Compound([string]$t) { return @($t) }
# Resolve-Fragment, solo lo justo: una orden cualquiera vale, y "modo X" vuelve a entrar
# -que es como se hace un modo que se llama a si mismo-
$script:resueltas = 0
function Resolve-Fragment([string]$fr) {
    $script:resueltas++
    # EL FRENO DE ESTE BANCO, no el de Nova: si el tope de anidamiento de assistant.ps1
    # desaparece, aqui la recursion seria infinita y el banco no diria "MAL", se quedaria
    # colgado para siempre -y con el, la bateria entera-. A las 50 vueltas se corta y la
    # comprobacion de abajo canta, que es lo que tiene que pasar.
    if ($script:resueltas -gt 50) { return $null }
    if ($fr -match '^modo\s+(.+)$') { return (Resolve-Modo $fr) }
    return @{ kind = 'prueba'; desc = $fr }
}
Invoke-Expression ("function Resolve-Modo([string]`$f) {`n" + (TraerRama 'ponte en modo') + "`n    return `$null`n}")
# la rama de CREAR vive en Invoke-FastCommand y hay una gemela en Test-FastCommand: se coge
# la que ejecuta, que es la que tiene Add-Perfil dentro
$ramaCrear = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.IfStatementAst] -and
    $x.Clauses[0].Item1.Extent.Text -like '*guardame*modo*' -and
    $x.Extent.Text -like '*Add-Perfil*' }, $true)
if (-not $ramaCrear) { Write-Host '  MAL  no encuentro la rama de crear un modo'; exit 1 }
function Split-Ordenes([string]$t) { return @($t -split '\s+y\s+') }
Invoke-Expression ("function Do-CrearModo([string]`$text) {`n" + $ramaCrear.Extent.Text + "`n    return `$null`n}")
Invoke-Expression ("function Do-ModoEntra(`$a) {`n" + (TraerCaso 'modoEntra') + "`n}")
Invoke-Expression ("function Do-ModoFuera(`$a) {`n" + (TraerCaso 'modoFuera') + "`n}")

Write-Host ''
Write-Host '-- 0. LA FRASE QUE SE LE DA A BRAYA, dicha tal cual --'
# Esto es lo unico que le falta: la frase. Asi que la frase se prueba, no se supone.
$r0 = Do-CrearModo 'crea el modo estamos dos: abre it takes two y abre discord'
Comp 'la frase se entiende aqui, no se va al modelo' ($null -ne $r0) "$r0"
Comp 'y el modo se llama "estamos dos", no "estamos"' ((Test-Prop $script:cmds.perfiles 'estamos dos') -eq $true) "$(@($script:cmds.perfiles.PSObject.Properties.Name) -join ', ')"
Comp 'con sus DOS ordenes, no con una que empieza por "dos:"' (@($script:cmds.perfiles.'estamos dos').Count -eq 2) "$(@($script:cmds.perfiles.'estamos dos') -join ' | ')"
Comp 'y ninguna orden arrastra el nombre' ((@($script:cmds.perfiles.'estamos dos') -join ' ') -notmatch 'dos:') ''
# y lo de siempre sigue igual: sin dos puntos manda el patron viejo
[void](Do-CrearModo 'crea el modo juego que pon el brillo al 100')
Comp 'sin dos puntos, el nombre de una palabra sigue igual' ((Test-Prop $script:cmds.perfiles 'juego') -eq $true) "$(@($script:cmds.perfiles.PSObject.Properties.Name) -join ', ')"
[void](Do-CrearModo 'crea el modo noche, pon el brillo al 20')
Comp 'con coma, tambien' ((Test-Prop $script:cmds.perfiles 'noche') -eq $true) ''
Comp 'y no se ha colado el cuerpo en el nombre' ((Test-Prop $script:cmds.perfiles 'noche pon el brillo al 20') -eq $false) ''

# LOS DOS GEMELOS, QUE TIENEN QUE SER EL MISMO. El patron de crear esta escrito dos veces: en
# Test-FastCommand -que es lo que le dice al banco de siempre que esto se hace en casa- y en
# Invoke-FastCommand, que es quien lo hace. Si se separan, Nova sigue creando el modo pero el
# banco cree que la frase se va al modelo, y al reves: el banco da verde y la frase no hace
# nada. El propio codigo lo avisa en un comentario; aqui se comprueba, y con el arbol, que
# contar lineas ya se equivoco una vez.
$gemelos = @($ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.IfStatementAst] -and
    $x.Clauses[0].Item1.Extent.Text -like '*guardame*modo*' }, $true))
Comp 'el patron de crear esta escrito dos veces' ($gemelos.Count -eq 2) "$($gemelos.Count) sitios"
if ($gemelos.Count -eq 2) {
    $c0 = ($gemelos[0].Clauses[0].Item1.Extent.Text -replace '\s+', ' ').Trim()
    $c1 = ($gemelos[1].Clauses[0].Item1.Extent.Text -replace '\s+', ' ').Trim()
    Comp 'y las dos copias dicen lo mismo' ($c0 -eq $c1) 'si se separan, el banco da verde y la frase no hace nada'
}

Write-Host ''
Write-Host '-- 1. el modo se crea hablando, con un nombre de DOS palabras --'
Comp 'Add-Perfil guarda el modo' ((Add-Perfil 'estamos dos' @('abre it takes two', 'abre discord')) -eq $true) ''
$disco = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
Comp 'y queda escrito en el disco' ((Test-Prop $disco.perfiles 'estamos dos') -eq $true) ''
Comp 'y Nova lo ve SIN reiniciar' ((Test-Prop $script:cmds.perfiles 'estamos dos') -eq $true) 'Add-Perfil relee $script:cmds'
Comp 'con sus dos ordenes' (@($script:cmds.perfiles.'estamos dos').Count -eq 2) "$(@($script:cmds.perfiles.'estamos dos').Count)"

Write-Host ''
Write-Host '-- 2. "modo estamos dos" lo pone (y el filtro de modos de sistema no se lo come) --'
$cmds = $script:cmds
$acc = @(Resolve-Modo 'modo estamos dos')
Comp 'la frase se resuelve aqui, no se va al modelo' ($acc.Count -gt 0) "$($acc.Count) acciones"
Comp 'lo primero es apuntar como estaba' ([string]$acc[0].kind -eq 'modoEntra') "$([string]$acc[0].kind)"
Comp 'y detras van sus dos ordenes' ($acc.Count -eq 3) "$($acc.Count)"
# el filtro de 'modo X' excluye foco/ahorro/rendimiento/normal... y eso NO puede tragarse
# un nombre suyo
foreach ($n in @('estamos dos', 'dos', 'pareja', 'cooperativo')) {
    $r = @(Resolve-Modo "modo $n")
    Comp ("el filtro no se come `"$n`"") ($null -ne $r -and ($r.Count -gt 0 -or -not (Test-Prop $cmds.perfiles $n))) ''
}
foreach ($n in @('normal', 'ahorro', 'foco')) {
    Comp ("y si sigue sin tocar el modo de sistema `"$n`"") ($null -eq (Resolve-Modo "modo $n")) 'ese lo lleva otro sitio'
}

Write-Host ''
Write-Host '-- 3. un modo que se llama a si mismo NO cuelga a Nova --'
# Desde que los modos se crean por voz nada impide un "modo a" que llame al "modo b" que
# llame al "modo a". Sin tope eso es el asistente colgado, con una sesion de seis horas
# delante.
[void](Add-Perfil 'circulo' @('modo circulo'))
$script:hondoPerfil = 0
$script:resueltas = 0
$cmds = $script:cmds
$antes = Get-Date
$r3 = @(Resolve-Modo 'modo circulo')
$tardo = ((Get-Date) - $antes).TotalSeconds
Comp 'termina, y rapido' ($tardo -lt 5) ("{0:N2} s" -f $tardo)
Comp 'se corta a las 3 vueltas, no a las mil' ($script:resueltas -le 4) "$($script:resueltas) vueltas"
Comp 'y el contador vuelve a cero (hay finally)' ($script:hondoPerfil -eq 0) "$($script:hondoPerfil)"

Write-Host ''
Write-Host '-- 4. LA SALIDA: "modo normal" devuelve brillo y volumen EXACTOS --'
$script:brillo = 42; $script:volumen = 17; $script:tocado = @(); $script:antesDeModo = $null
Do-ModoEntra @{ kind = 'modoEntra'; modo = 'estamos dos' }
Comp 'al entrar se apunta como estaba' ($script:antesDeModo.brillo -eq 42 -and $script:antesDeModo.volumen -eq 17) "brillo=$($script:antesDeModo.brillo) volumen=$($script:antesDeModo.volumen)"
# el modo baja las dos cosas, como haria la lista de ordenes
$script:brillo = 15; $script:volumen = 80; $script:tocado = @()
$a4 = @{ kind = 'modoFuera'; modo = ''; desc = '' }
Do-ModoFuera $a4
Comp 'el brillo vuelve al de antes' ($script:brillo -eq 42) "$($script:brillo)"
Comp 'el volumen vuelve al de antes' ($script:volumen -eq 17) "$($script:volumen)"
Comp 'y lo dice nombrando LAS DOS cosas' ($a4.desc -match 'brillo al 42' -and $a4.desc -match 'volumen al 17') "$($a4.desc)"
Comp 'no promete haber salido del modo' ($a4.desc -notmatch 'salido|apagado|desactivado') 'solo toco dos cosas: eso es lo que dice'
Comp 'y no se queda nada apuntado' ($null -eq $script:antesDeModo) ''

Write-Host ''
Write-Host '-- 5. salir de OTRO modo distinto del puesto: dice cual era y no toca nada --'
$script:brillo = 42; $script:volumen = 17; $script:antesDeModo = $null
Do-ModoEntra @{ kind = 'modoEntra'; modo = 'estamos dos' }
$script:brillo = 15; $script:volumen = 80; $script:tocado = @()
$a5 = @{ kind = 'modoFuera'; modo = 'foco'; desc = '' }
Do-ModoFuera $a5
Comp 'dice cual era el modo puesto' ($a5.desc -match 'estamos dos') "$($a5.desc)"
Comp 'y NO toca ni el brillo ni el volumen' (@($script:tocado).Count -eq 0) "$(@($script:tocado) -join ', ')"
Comp 'la salida buena sigue ahi para cuando quiera' ($null -ne $script:antesDeModo) ''
# y sin nada apuntado, no se inventa un brillo
$script:antesDeModo = $null; $script:tocado = @()
$a5b = @{ kind = 'modoFuera'; modo = ''; desc = '' }
Do-ModoFuera $a5b
Comp 'sin nada apuntado, pregunta en vez de inventarse un numero' ($a5b.desc -match 'Dime a que brillo') "$($a5b.desc)"
Comp 'y tampoco toca nada' (@($script:tocado).Count -eq 0) ''

Write-Host ''
Write-Host '-- 6. la pareja NO crea modos en la consola de braya --'
# El modo invitado se propone solo cuando Nova no reconoce la voz. Montajes y palabras-no ya
# respetan el invitado; los modos tienen que respetarlo igual, que es el mismo fichero de
# ordenes de braya.
$script:invitado = $true
$antes6 = [System.IO.File]::ReadAllText($cmdsPath)
$ok6 = Add-Perfil 'de la novia' @('abre discord')
$despues6 = [System.IO.File]::ReadAllText($cmdsPath)
$script:invitado = $false
Comp 'con un invitado, Add-Perfil dice que no' ($ok6 -eq $false) "$ok6"
Comp 'y commands.json no cambia ni un byte' ($antes6 -eq $despues6) ''

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  el modo de dos ya existe: crea el modo estamos dos, ponlo, y modo normal para salir'
exit 0
