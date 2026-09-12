# "Deshaz lo de los últimos 5 minutos", del archivo real.
# Lo que importa: que coja el brillo y el volumen de la foto MÁS VIEJA de la
# ventana (la última es "hace un momento" y no sirve de nada), que cierre lo
# que se abrió en toda la ventana, y que NO toque nada de antes de esa ventana.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
# el AX de verdad está en el DLL; aquí basta uno de mentira que apunte lo que
# le piden, que es justo lo que hay que comprobar
class AX {
    static [int] $volumen = 50
    static [int] LeerVolumen() { return [AX]::volumen }
    static [bool] PonerVolumen([int]$v) { [AX]::volumen = $v; return $true }
}
$script:brillo = 50
function Set-Brillo([int]$v) { $script:brillo = $v }
function Log($m) { }

Invoke-Expression (Traer 'Invoke-DeshacerDesde')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-42} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

function Foto($haceMinutos, $brillo, $volumen) {
    return @{ cuando = (Get-Date).AddMinutes(-$haceMinutos); brillo = $brillo; volumen = $volumen
              procesos = (New-Object System.Collections.ArrayList); juego = $null }
}

# nada apuntado todavía
$script:historial = New-Object System.Collections.ArrayList
$r = Invoke-DeshacerDesde 5
Comp 'sin nada apuntado lo dice' ($r -match 'No he tocado nada') ''

# tres fotos: hace 30 min, hace 4 min y hace 1 min
$script:historial = New-Object System.Collections.ArrayList
[void]$script:historial.Add((Foto 30 10 10))
[void]$script:historial.Add((Foto 4  70 70))
[void]$script:historial.Add((Foto 1  20 20))
[AX]::volumen = 99; $script:brillo = 99

$r = Invoke-DeshacerDesde 5
Comp 'coge la MAS VIEJA de la ventana' ($script:brillo -eq 70) "brillo=$($script:brillo) (debia ser 70, no 20 ni 10)"
Comp 'y el volumen de esa misma' ([AX]::volumen -eq 70) "volumen=$([AX]::volumen)"
Comp 'no se lleva la de hace media hora' ($script:historial.Count -eq 1) "quedan $($script:historial.Count)"
Comp 'lo cuenta' ($r -match 'Vuelto a como estaba') "'$r'"

# y una ventana más ancha sí llega hasta la vieja
[AX]::volumen = 99; $script:brillo = 99
$r = Invoke-DeshacerDesde 60
Comp 'una hora si alcanza la de hace 30' ($script:brillo -eq 10) "brillo=$($script:brillo)"
Comp 'y se vacia la pila' ($script:historial.Count -eq 0) "quedan $($script:historial.Count)"

# una ventana sin nada dentro
$r = Invoke-DeshacerDesde 5
Comp 'ventana vacia lo dice, no miente' ($r -match 'No he tocado nada') ''

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
