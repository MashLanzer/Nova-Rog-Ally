# El parte general ("como va todo"): comprueba lo que DICE, no solo que la
# frase se reconozca. Get-ParteGeneral se saca DEL ARCHIVO REAL, como en
# probar-json-ui.ps1: una copia aqui se quedaria vieja al primer cambio.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'Format-Gigas')
Invoke-Expression (TraerFn 'Get-ParteGeneral')

# --- mundo de mentira ---
# La bateria y los juegos colgados se sustituyen por versiones de mentira: leer
# la bateria de verdad haria que la prueba dijera una cosa distinta cada vez, y
# los colgados dependen de lo que haya abierto en ese momento.
$script:fraseBateria = 'bateria al 40 por ciento, te quedan unos 1 h 10 min'
$script:zombis = @()
function Get-FraseBateria([bool]$corto = $false) { return $script:fraseBateria }
function Get-JuegosZombis { return $script:zombis }

$script:reloj = 3600000
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$script:juegoActivo = $null
$script:juegoDesde = 0
$script:Juegos = @()
$script:uiCarga = 12
$script:sordinaHasta = 0

$fallos = 0
function Comprobar([string]$etiqueta, [string[]]$debeDecir, [string[]]$noDebeDecir) {
    $t = Get-ParteGeneral
    $ok = $true
    foreach ($d in $debeDecir) { if ($t -notmatch [regex]::Escape($d)) { $ok = $false } }
    foreach ($d in $noDebeDecir) { if ($t -match [regex]::Escape($d)) { $ok = $false } }
    Write-Host ("  {0}  {1,-34} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $t)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "--- el parte dice lo que hay, y calla lo que no aporta ---"

# en reposo: bateria y disco, y NADA de procesador ni colgados
Comprobar 'sin nada especial' @('bateria al 40 por ciento') @('procesador', 'colgado', 'silencio', 'desde hace')

# jugando: lo primero es a que juegas, que es el contexto de todo lo demas
$script:juegoActivo = 'ELDEN RING'
$script:juegoDesde = $script:reloj - (48 * 60000)
Comprobar 'jugando' @('estas en ELDEN RING desde hace 48 minutos') @()

# una descarga: nombre y porcentaje, del manifiesto ya leido
$script:Juegos = @(
    @{ nombre = 'REANIMAL'; bajando = $true; descargado = 62.0; total = 100.0 },
    @{ nombre = 'Outlast'; bajando = $false; descargado = 10.0; total = 10.0 }
)
Comprobar 'con una descarga' @('REANIMAL va por el 62 por ciento') @('descargas en marcha')

# varias: el nombre de cada una sobraria; lo que importa es que hay varias
$script:Juegos += @{ nombre = 'PEAK'; bajando = $true; descargado = 1.0; total = 4.0 }
Comprobar 'con dos descargas' @('2 descargas en marcha') @('REANIMAL va por')

# el procesador SOLO si esta alto: al 12 por ciento no le sirve a nadie
$script:uiCarga = 91
Comprobar 'con el procesador al 91' @('el procesador esta al 91 por ciento') @()
$script:uiCarga = 12

# un juego colgado sin ventana: lo que paso con Outlast 2
$script:zombis = @(@{ nombre = 'Outlast 2'; minutos = 240 })
Comprobar 'con un juego colgado' @('Outlast 2 sigue colgado sin ventana') @()
$script:zombis = @(@{ nombre = 'Outlast 2'; minutos = 240 }, @{ nombre = 'PEAK'; minutos = 90 })
Comprobar 'con dos colgados' @('hay 2 juegos colgados') @()
$script:zombis = @()

# en sordina: es la respuesta a "por que no me haces caso"
$script:sordinaHasta = $script:reloj + (7 * 60000)
Comprobar 'en sordina' @('sigo en silencio 7 minutos mas') @()
$script:sordinaHasta = 0

# y si no hay NADA que contar, que no se invente un parte vacio
$script:juegoActivo = $null
$script:Juegos = @()
$script:fraseBateria = ''
$sinDisco = Get-ParteGeneral
$okVacio = ($sinDisco -match 'quedan .* en [A-Z]') -or ($sinDisco -eq 'todo tranquilo')
Write-Host ("  {0}  {1,-34} {2}" -f $(if ($okVacio) { 'OK ' } else { 'MAL' }), 'sin bateria (un equipo de mesa)', $sinDisco)
if (-not $okVacio) { $fallos++ }

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
