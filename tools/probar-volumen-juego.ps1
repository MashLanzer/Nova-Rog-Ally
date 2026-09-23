# HACERSE SITIO PARA HABLAR (23/09, funcion 7 de la tanda de funciones nuevas).
#
# braya le habla mientras juega -toda la tanda del 22/09 de 21:43 a 21:48 es con una partida
# delante- y Nova hablaba ENCIMA del audio del juego, a volumen fijo. En catorce dias habla 41
# veces con un juego en primer plano, con los altavoces medidos entre 0,10 y 1,000.
#
# LO QUE SE VIGILA AQUI, y es lo unico que puede hacerle daño: que no le SUBA el volumen sin
# querer, y que se lo devuelva siempre.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}

# --- un AX de mentira, para ver que volumen se pide de verdad ---
Add-Type -TypeDefinition @'
public class AX {
    public static int VolActual = 80;
    public static int UltimoPuesto = -1;
    public static int LeerVolumenApp(int pid) { return VolActual; }
    public static bool PonerVolumenApp(int pid, int pct) { UltimoPuesto = pct; VolActual = pct; return true; }
}
'@ -ErrorAction SilentlyContinue
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$JuegoBajarAlHablar = $true
$JuegoBajarPct = 35
$script:juegoPid = 1234
$script:juegoActivo = 'It Takes Two'
$script:juegoVolAntes = -1
$script:juegoVolPid = 0
$script:juegoBajadoHasta = 0
Invoke-Expression (Traer 'Push-VolumenJuego')
Invoke-Expression (Traer 'Pop-VolumenJuego')

Write-Host ''
Write-Host '-- baja EN PROPORCION, no a un numero fijo --'
[AX]::VolActual = 80; [AX]::UltimoPuesto = -1; $script:juegoVolAntes = -1
Push-VolumenJuego
Comp 'con el juego al 80, lo baja' ([AX]::UltimoPuesto -lt 80 -and [AX]::UltimoPuesto -gt 0) "a $([AX]::UltimoPuesto)"
Comp 'y guarda el que tenia' ($script:juegoVolAntes -eq 80) "guardado: $($script:juegoVolAntes)"
Pop-VolumenJuego
Comp 'y se lo devuelve entero' ([AX]::UltimoPuesto -eq 80) "vuelto a $([AX]::UltimoPuesto)"

Write-Host ''
Write-Host '-- y con el juego BAJO, no se lo sube --'
# El fallo que habria metido un "poner 50" a secas: si braya tiene el juego al 30, ponerlo a
# 50 se lo SUBE. PonerVolumenApp es absoluto de 0 a 100, no relativo.
[AX]::VolActual = 30; [AX]::UltimoPuesto = -1; $script:juegoVolAntes = -1
Push-VolumenJuego
Comp 'al 30 no se lo sube' ([AX]::UltimoPuesto -eq -1 -or [AX]::UltimoPuesto -lt 30) "puesto: $([AX]::UltimoPuesto)"
[AX]::VolActual = 15; [AX]::UltimoPuesto = -1; $script:juegoVolAntes = -1
Push-VolumenJuego
Comp 'y por debajo de 20 ni lo toca' ([AX]::UltimoPuesto -eq -1) 'bajarlo mas no ayuda y se nota al volver'

Write-Host ''
Write-Host '-- no se baja dos veces ni se pierde el original --'
[AX]::VolActual = 90; [AX]::UltimoPuesto = -1; $script:juegoVolAntes = -1
Push-VolumenJuego
$primero = $script:juegoVolAntes
Push-VolumenJuego          # otra frase seguida
Comp 'el original sigue siendo el primero' ($script:juegoVolAntes -eq $primero) "$($script:juegoVolAntes)"
Pop-VolumenJuego
Comp 'y al devolverlo vuelve al de braya' ([AX]::UltimoPuesto -eq 90) "$([AX]::UltimoPuesto)"
Comp 'y un segundo Pop no hace nada' ($script:juegoVolAntes -lt 0)

Write-Host ''
Write-Host '-- sin juego delante no hace nada --'
$script:juegoActivo = $null; [AX]::UltimoPuesto = -1; $script:juegoVolAntes = -1
Push-VolumenJuego
Comp 'sin juego, no toca el volumen' ([AX]::UltimoPuesto -eq -1)
$script:juegoActivo = 'It Takes Two'; $script:juegoPid = 0
Push-VolumenJuego
Comp 'y sin PID tampoco' ([AX]::UltimoPuesto -eq -1)

Write-Host ''
Write-Host '-- donde se baja y quien lo devuelve --'
Comp 'se baja dentro de Play-Audio' ($fuente -match '(?s)function Play-Audio.{0,600}Push-VolumenJuego') 'Say tiene cinco salidas antes de que suene nada'
Comp 'se devuelve desde el bucle' ($fuente -match '(?s)if \(\$script:juegoVolAntes -ge 0\).{0,400}Pop-VolumenJuego') 'aunque Nova muera o la corten'
Comp 'con techo duro de 20 s' ($fuente -match 'juegoBajadoHasta = \$sw\.ElapsedMilliseconds \+ 20000') ''
Comp 'y con reloj propio, no pausaHasta' ($fuente -match 'juegoBajadoHasta') 'pausaHasta se alarga con la sordina'
Comp 'se puede apagar desde config' ($fuente -match "Get-Cfg 'juego' 'bajarAlHablar'") ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  te baja el juego para hablarte y te lo devuelve'
exit 0
