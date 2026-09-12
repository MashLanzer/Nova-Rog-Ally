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

if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
