# UN SITIO SIN DIRECCION NO ES UN SITIO (22/09).
#
# LO QUE PASO, la cadena entera, y por eso este banco existe:
#
#   1. El liston de letras por segundo estaba roto (segundos_de_voz media el fichero entero
#      como voz con el micro USB nuevo), asi que Parakeet cedia a Whisper teniendo la orden
#      bien. braya dijo "cierra los ajustes"; Parakeet lo oyo bien; Whisper devolvio
#      "Si es a los ajutos".
#   2. Eso se aprendio: traducciones.json se quedo con 'si es a los ajutos' -> 'abre ajustes'.
#   3. Y Add-Alias-Comando ademas metio  "ajutos": ""  en la lista de SITIOS WEB de
#      commands.json, porque su else guardaba $d.url tuviera valor o no.
#   4. A partir de ahi "busca gatos en otra pestana" se resolvia como "abrir ajutos", que es
#      abrir una direccion vacia. Lo cazo el banco de destinos (pruebas\destinos.txt:123).
#
# Una sola orden mal oida envenenando el vocabulario para siempre es justo lo que braya no
# quiere: una orden equivocada es mucho peor que una que no se entiende. El arreglo es de una
# linea -si no hay ni programa ni direccion, no se aprende- y esto lo vigila.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA DEL BANCO (van catorce): toda funcion que se llame aqui TIENE que traerse, o la
# prueba corre contra el vacio. La seccion 7 de probar-todo.ps1 lo caza.
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'Add-Alias-Comando')

# --- el mundo de mentira ---
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('alias-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$cmdsPath = Join-Path $base 'commands.json'
$script:invitado = $false
$script:cmds = $null
$script:dicho = @()
function Log($m) { $script:dicho += $m }
function ConvertTo-Plain([string]$t) { return $t }
function Write-Atomico($ruta, $texto) { [System.IO.File]::WriteAllText($ruta, $texto) }
function Set-AcabaDeAprender { }
# Resolve-Target se simula: es lo que decide QUE es el destino, y aqui lo que se prueba es
# que pasa con lo que devuelve, no como lo resuelve.
$script:loQueResuelve = $null
# LA COMA NO SOBRA: PowerShell DESENROLLA las colecciones al devolverlas, asi que sin ella
# un array de un solo elemento llega como el elemento suelto y el $destino[0] del codigo
# real se queda en $null -en un hashtable, [0] busca la CLAVE 0-. Sin esta coma este banco
# daba MAL con el codigo correcto.
function Resolve-Target([string]$t) {
    if ($null -eq $script:loQueResuelve) { return $null }
    return ,$script:loQueResuelve
}

function Reset {
    $j = @{ apps = @{ 'steam' = 'steam.exe' }; sitios = @{ 'youtube' = 'https://youtube.com' } }
    [System.IO.File]::WriteAllText($cmdsPath, ($j | ConvertTo-Json -Depth 8))
}
function Leer { return (Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json) }

Write-Host ''
Write-Host '-- lo que SI se aprende --'
Reset
$script:loQueResuelve = @(@{ kind = 'sitio'; url = 'https://reddit.com'; desc = 'abrir reddit' })
$r = Add-Alias-Comando 'foro' 'reddit'
$j = Leer
Comp 'un sitio con direccion se guarda' ($null -ne $j.sitios.foro -and $j.sitios.foro -eq 'https://reddit.com') "$($j.sitios.foro)"
Comp 'y lo dice' ($r -and $r -match 'foro')

Reset
$script:loQueResuelve = @(@{ kind = 'app'; target = 'discord.exe'; desc = 'abrir Discord' })
$null = Add-Alias-Comando 'chat' 'discord'
$j = Leer
Comp 'una app con ejecutable se guarda' ($j.apps.chat -eq 'discord.exe') "$($j.apps.chat)"

Write-Host ''
Write-Host '-- EL CASO DEL 22/09: lo que NO se puede aprender --'
# Esto es lo que metio  "ajutos": ""  entre los sitios web y rompio "busca gatos en otra
# pestana". Un destino que no es una app y no trae direccion.
Reset
$script:loQueResuelve = @(@{ kind = 'ajuste'; url = ''; desc = 'abrir ajustes' })
$r = Add-Alias-Comando 'ajutos' 'ajustes'
$j = Leer
Comp 'un destino sin direccion NO se aprende' ($null -eq $r) "devolvio: $r"
Comp 'y no deja rastro en los sitios' (-not ($j.sitios.PSObject.Properties.Name -contains 'ajutos')) ($j.sitios.PSObject.Properties.Name -join ', ')
Comp 'ni en las apps' (-not ($j.apps.PSObject.Properties.Name -contains 'ajutos'))
Comp 'y lo deja dicho en el log' (($script:dicho -join ' ') -match 'NO aprendo')

Reset
$script:loQueResuelve = @(@{ kind = 'app'; target = ''; desc = 'abrir nada' })
$null = Add-Alias-Comando 'vacia' 'nada'
$j = Leer
Comp 'una app sin ejecutable tampoco' (-not ($j.apps.PSObject.Properties.Name -contains 'vacia'))

Reset
$script:loQueResuelve = @(@{ kind = 'sitio'; url = '   '; desc = 'abrir espacios' })
$null = Add-Alias-Comando 'espacios' 'nada'
$j = Leer
Comp 'ni una direccion que son solo espacios' (-not ($j.sitios.PSObject.Properties.Name -contains 'espacios'))

Reset
$script:loQueResuelve = $null
$null = Add-Alias-Comando 'nada' 'loquesea'
$j = Leer
Comp 'si no resuelve nada, no se inventa una entrada' ($j.sitios.PSObject.Properties.Name.Count -eq 1)

Write-Host ''
Write-Host '-- y lo de siempre sigue en pie --'
Reset
$script:invitado = $true
$script:loQueResuelve = @(@{ kind = 'sitio'; url = 'https://reddit.com'; desc = 'abrir reddit' })
$r = Add-Alias-Comando 'foro' 'reddit'
Comp 'en modo invitado no se aprende nada' ($null -eq $r)
$script:invitado = $false
$r = Add-Alias-Comando '' 'reddit'
Comp 'sin alias, nada' ($null -eq $r)

Write-Host ''
Write-Host '-- y el vocabulario de hoy esta limpio --'
# la entrada mala se quito a mano el 22/09; esto vigila que no vuelva ninguna igual
$real = Get-Content -LiteralPath (Join-Path $raiz 'commands.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$vacios = @()
foreach ($grupo in @('sitios', 'apps', 'busquedas')) {
    if (-not $real.$grupo) { continue }
    foreach ($pr in $real.$grupo.PSObject.Properties) {
        if (-not ([string]$pr.Value).Trim()) { $vacios += "$grupo/$($pr.Name)" }
    }
}
Comp 'ni un sitio, app o buscador sin valor en commands.json' ($vacios.Count -eq 0) ($vacios -join ', ')

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  una orden mal oida ya no envenena el vocabulario'
exit 0
