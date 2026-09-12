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

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Test-MismoAudio')
Invoke-Expression (Traer 'Get-JuegosZombis')

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
if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
