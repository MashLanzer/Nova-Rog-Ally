# LA LISTA QUE IMPIDE BORRAR LA CONSOLA SE SALTA CON UN ALIAS (26/09, idea 34 de las 121).
#
# opencode es un agente con acceso total a esta consola. Lo que le impide hacer estragos es una
# lista de patrones "deny" en %USERPROFILE%\.config\opencode\opencode.jsonc: hoy 35 patrones
# sobre una base "*": "allow". El problema es que casan TEXTO LITERAL. "*Remove-Item*-Recurse*"
# no sabe que ri, rm, rd, del, erase y rmdir son Remove-Item; que -R y -Rec son -Recurse; que
# -For es -Force. Comprobado de verdad (no emulado): un arbol creado en TEMP, `ri -Rec -For`
# lo borra entero y no casa con ninguno de los 35.
#
# LA LISTA GEMELA, la de Claude Code ($CcProhibido en assistant.ps1:22221-22238), SI cubre los
# alias: lleva 'PowerShell(ri:*)', 'PowerShell(rm:*)', 'PowerShell(iex:*)'... La de opencode es
# la unica de las dos que se quedo atras. Ese es el hallazgo entero.
#
# URGENCIA: baja, no la idea. `grep -c 'RUNNER cmd' assistant.log` -> 0; en el rotado, 149, la
# ultima el 13/09. Desde entonces config.json tiene modelo.cerebro = "claude-code" y opencode es
# el TERCER recurso (API -> Claude Code -> opencode, assistant.ps1:23783-23801). Pero opencode.exe
# sigue instalado, sigue en config.json, y sigue siendo el camino si Claude Code no arranca. El
# agujero es real. El coste de vigilarlo es un banco de solo lectura.
#
# ESTE BANCO NO ARREGLA NADA (regla 1 de la casa: Nova puede fallar en entender, no puede ejecutar
# lo que no se le pidio). No escribe en opencode.jsonc, no propone parches, no toca $CcProhibido.
# Cuenta los rodeos y los lista. Ampliar o estrechar los permisos de un agente con acceso total
# es decision de braya.
#
# MAYUSCULAS: el matcher aqui compara SIN distinguir (WildcardPattern IgnoreCase). Es el supuesto
# conservador: reporta MENOS escapes, nunca mas, asi que la lista no se infla con agujeros que
# quiza no existen. Si el matcher real de opencode distingue mayusculas, habria MAS, no menos.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PowerShell 5.1 con -File sale con codigo 0 aunque el script
# muera a mitad, asi que morir en silencio se daba por bueno.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}

# --------------------------------------------------------------------------------------------
# 1. LEER EL FICHERO QUE MANDA. No opencode.permisos.json del repositorio (esa es copia de
#    referencia, TRASPASO.md:515-521), sino el de %USERPROFILE%, que es el que lee opencode.
#    Con Join-Path $env:USERPROFILE, no a fuego: si un dia probar-bancos-de-verdad.py amplia su
#    regex a "C:\Users\braya" a secas, este banco no sera el primero en caer.
# --------------------------------------------------------------------------------------------
$jsonc = Join-Path $env:USERPROFILE '.config\opencode\opencode.jsonc'
if (-not (Test-Path -LiteralPath $jsonc)) {
    Comp 'existe el opencode.jsonc de este usuario' $false $jsonc
    Write-Host "  $mal MAL"; exit 1
}
# La extension es .jsonc: alguien escribira un `// comentario` ahi tarde o temprano y
# ConvertFrom-Json de PS 5.1 revienta. Que reviente y lo recoja el trap (rojo ruidoso), en vez
# de un try/catch que devuelva cero patrones y verde mudo.
$textoJsonc = [IO.File]::ReadAllText($jsonc)
$j = $textoJsonc | ConvertFrom-Json
$deny = @($j.permission.bash.PSObject.Properties |
    Where-Object { $_.Value -eq 'deny' } | Select-Object -ExpandProperty Name)

# --------------------------------------------------------------------------------------------
# 2. EL PISO Y LA BASE. El piso 30 sale de los 35 de hoy con el criterio de $MINIMOS en
#    probar-regex.ps1: por debajo del numero real para que editar la lista no de rojos falsos,
#    muy por encima de cero para que "0 patrones, todo correcto" sea imposible.
# --------------------------------------------------------------------------------------------
Comp 'la lista se ha leido entera' ($deny.Count -ge 30) "hoy $($deny.Count) patrones deny"
# Si la base pasa de allow a deny, este banco entero pierde sentido y hay que enterarse.
Comp 'la base sigue siendo todo permitido' ($j.permission.bash.'*' -eq 'allow') "base '*'"
# El operador -like y WildcardPattern tratan [ ] como clase de caracteres. Hoy ningun patron
# lleva corchetes; el dia que aparezca uno, el emulador mentiria, asi que hay que avisar.
$conCorchete = @($deny | Where-Object { $_ -match '[\[\]]' })
Comp 'ningun patron usa corchetes' ($conCorchete.Count -eq 0) $(
    if ($conCorchete.Count) { "el emulador mentiria con: " + ($conCorchete -join ', ') } else { 'el comodin es fiable' })

# --------------------------------------------------------------------------------------------
# EL EMULADOR. Un patron con comodines de shell contra un comando. IgnoreCase a proposito.
# --------------------------------------------------------------------------------------------
function Test-Bloqueada([string]$cmd) {
    $casan = @()
    foreach ($p in $script:deny) {
        $w = [System.Management.Automation.WildcardPattern]::new($p, 'IgnoreCase')
        if ($w.IsMatch($cmd)) { $casan += $p }
    }
    return $casan
}

# --------------------------------------------------------------------------------------------
# 3. LOS DOS CANARIOS DEL EMULADOR, antes de generar nada. Sin ellos un emulador roto hacia
#    "todo bloqueado" daria cero escapes y VERDE mintiendo; roto hacia "nada bloqueado" daria
#    la lista entera y rojo por la razon equivocada. Los dos cierran las dos puertas.
# --------------------------------------------------------------------------------------------
Comp 'el emulador bloquea lo que opencode bloquea' (@(Test-Bloqueada 'Remove-Item -Recurse -Force C:\x').Count -gt 0) "canario 1"
Comp 'y deja pasar lo que opencode deja pasar' (@(Test-Bloqueada 'echo hola').Count -eq 0) "canario 2"

# --------------------------------------------------------------------------------------------
# 4. PREGUNTAR A LA MAQUINA, no escribir los alias a mano. Los cmdlets salen de los PROPIOS
#    patrones (regex Verbo-Nombre): hoy Remove-Item, Remove-ItemProperty, Stop-Computer,
#    Restart-Computer, Stop-Service, Invoke-Expression. Para cada uno, sus alias y las
#    abreviaturas INEQUIVOCAS de sus parametros (el prefijo mas corto que solo casa con uno).
# --------------------------------------------------------------------------------------------
$cmdlets = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $deny) {
    foreach ($m in [regex]::Matches($p, '[A-Z][a-z]+-[A-Z][a-zA-Z]+')) { [void]$cmdlets.Add($m.Value) }
}

# El prefijo mas corto de un parametro que NO sea ambiguo. -R casa solo Recurse; -For casa solo
# Force; -F casaria Filter Y Force, asi que se descarta. Devuelve el switch corto o el largo.
function Abrev-Inequivoca([string]$cmdlet, [string]$parametro) {
    $keys = @()
    try { $keys = @((Get-Command $cmdlet -ErrorAction Stop).Parameters.Keys) } catch { return "-$parametro" }
    for ($n = 1; $n -lt $parametro.Length; $n++) {
        $pre = $parametro.Substring(0, $n)
        $casan = @($keys | Where-Object { $_.ToLower().StartsWith($pre.ToLower()) })
        if ($casan.Count -eq 1) { return "-$pre" }
    }
    return "-$parametro"
}

# Genera comandos de prueba para un cmdlet: el nombre largo mas cada alias, con y sin la forma
# corta de los switches peligrosos. Para los de borrado usa -Recurse/-Force; para los demas,
# una forma minima que ejecuta (iex $x, spsv Audiosrv, rp ... -Name y).
function Variantes-De([string]$cmdlet) {
    $nombres = @($cmdlet)
    # -ErrorAction SilentlyContinue: Stop-Computer y Restart-Computer no tienen alias y Get-Alias
    # ESCRIBE un error, que acabaria en $script:errBanco y pondria la bateria amarilla cada pasada.
    $nombres += @(Get-Alias -Definition $cmdlet -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $out = @()
    switch ($cmdlet) {
        'Remove-Item' {
            $rec = Abrev-Inequivoca $cmdlet 'Recurse'
            $forc = Abrev-Inequivoca $cmdlet 'Force'
            foreach ($n in $nombres) {
                $out += ("$n -Recurse -Force C:\x")   # la forma larga: bloqueada, control
                $out += ("$n $rec $forc C:\x")         # la corta: el rodeo
                $out += ("$n $rec -Force C:\x")
            }
        }
        'Remove-ItemProperty' { foreach ($n in $nombres) { $out += ("$n HKCU:\Software\x -Name y") } }
        'Stop-Service'        { foreach ($n in $nombres) { $out += ("$n Audiosrv") } }
        'Invoke-Expression'   { foreach ($n in $nombres) { $out += ("$n `$x") } }
        'Stop-Computer'       { foreach ($n in $nombres) { $out += ("$n") } }
        'Restart-Computer'    { foreach ($n in $nombres) { $out += ("$n") } }
        default               { foreach ($n in $nombres) { $out += ("$n") } }
    }
    return $out
}

$variantes = @()
foreach ($c in @($cmdlets)) { $variantes += Variantes-De $c }
# EL MINIMO que impide el verde mudo: si Get-Alias deja de contestar (otra shell, otro perfil),
# se generarian 0 variantes, 0 escapes, y el banco saldria verde diciendo que no hay agujero.
# Hoy solo Remove-Item da 21 (7 nombres x 3 formas).
Comp 'la maquina contesta con los alias' ($variantes.Count -ge 12) "$($variantes.Count) variantes generadas"

# --------------------------------------------------------------------------------------------
# 5. EL TRINQUETE. Contar las variantes que ESCAPAN, con la guarda de la idea: como mucho las 3
#    mas cortas que escapan por cmdlet (guarda de diseno contra el ruido, no una medicion).
# --------------------------------------------------------------------------------------------
$escapesPorCmdlet = @{}
foreach ($c in @($cmdlets)) {
    $suyas = @(Variantes-De $c | Where-Object { @(Test-Bloqueada $_).Count -eq 0 })
    # las 3 mas cortas que escapan
    $suyas = @($suyas | Sort-Object { $_.Length } | Select-Object -First 3)
    if ($suyas.Count) { $escapesPorCmdlet[$c] = $suyas }
}
$escapes = @()
foreach ($c in $escapesPorCmdlet.Keys) { foreach ($e in $escapesPorCmdlet[$c]) { $escapes += $e } }

# El techo vive en un fichero al lado (como tildes-techo.txt y fragiles-techo.txt) para que
# bajarlo sea un cambio visible en el repositorio y no un numero escondido en el banco. Si el
# fichero falta o queda vacio, el techo es el de hoy: ni rojo falso ni verde mentiroso.
$techoRuta = Join-Path $PSScriptRoot 'permisos-techo.txt'
$techo = if (Test-Path -LiteralPath $techoRuta) { [int]((Get-Content -LiteralPath $techoRuta -Raw).Trim()) } else { $escapes.Count }
Comp 'los rodeos no crecen' ($escapes.Count -le $techo) "hoy $($escapes.Count), techo $techo"
if ($escapes.Count -lt $techo) {
    Write-Host ("  --   han bajado a $($escapes.Count): baja el techo en tools\permisos-techo.txt") -ForegroundColor DarkGray
}

# --------------------------------------------------------------------------------------------
# 6. LAS DOS COPIAS. El jsonc de %USERPROFILE% y opencode.permisos.json del repositorio son hoy
#    identicos byte a byte. Si la copia de referencia miente, hay que enterarse.
# --------------------------------------------------------------------------------------------
$copiaRepo = Join-Path $raiz 'opencode.permisos.json'
if (Test-Path -LiteralPath $copiaRepo) {
    $a = [IO.File]::ReadAllText($jsonc)
    $b = [IO.File]::ReadAllText($copiaRepo)
    Comp 'la copia del repositorio no miente' ($a -ceq $b) 'jsonc de %USERPROFILE% == opencode.permisos.json'
} else {
    Comp 'existe la copia de referencia en el repositorio' $false $copiaRepo
}

# --------------------------------------------------------------------------------------------
# 7. LA LISTA, que es lo que braya lee. Uno por escape, con el patron que deberia cubrirlo.
# --------------------------------------------------------------------------------------------
Write-Host ''
Write-Host '-- rodeos que se saltan la lista de opencode --'
if ($escapes.Count -eq 0) {
    Write-Host '  (ninguno)' -ForegroundColor Green
} else {
    $color = if ($escapes.Count -gt $techo) { 'Red' } else { 'Yellow' }
    foreach ($c in $escapesPorCmdlet.Keys | Sort-Object) {
        foreach ($e in $escapesPorCmdlet[$c]) {
            Write-Host ("  " + $e + "   (deberia caer bajo un patron de " + $c + ")") -ForegroundColor $color
        }
    }
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  los rodeos de la lista de opencode estan contados'
exit 0
