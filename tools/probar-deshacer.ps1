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

# ---------------------------------------------------------------------------
# "DESHAZ" A SECAS, ENCADENADO (19/09). Hasta hoy Invoke-Deshacer no tocaba la pila:
# el segundo "deshaz" contestaba "No hay nada que deshacer" con la foto del paso
# anterior delante. Las fotos van SIN brillo a proposito y el WMI se tapa: así la
# prueba no lee el hardware de la máquina y solo mide lo que se quiere medir.
Write-Host "--- deshaz encadenado ---"
function Get-CimInstance { throw 'en la prueba no hay WMI' }
Invoke-Expression (Traer 'Invoke-Deshacer')
Invoke-Expression (Traer 'Save-EstadoParaDeshacer')
# el tope se lee del archivo, para que la prueba no mienta si algún día cambia
$DeshacerMaxPasos = [int]([regex]::Match((Get-Content $ruta -Raw), '(?m)^\$DeshacerMaxPasos\s*=\s*(\d+)\s*$').Groups[1].Value)
Comp 'el tope esta entre 3 y 5 pasos' ($DeshacerMaxPasos -ge 3 -and $DeshacerMaxPasos -le 5) "tope=$DeshacerMaxPasos"

$script:historial = New-Object System.Collections.ArrayList
foreach ($v in @(10, 70, 20)) { [void]$script:historial.Add((Foto 1 $null $v)) }
$script:deshacer = $script:historial[$script:historial.Count - 1]
$script:deshacerSeguidos = 0
[AX]::volumen = 99

[void](Invoke-Deshacer)
Comp 'el primer deshaz devuelve lo ultimo' ([AX]::volumen -eq 20) "volumen=$([AX]::volumen)"
$r2 = Invoke-Deshacer
Comp 'el SEGUNDO ya no miente' ($r2 -notmatch 'No hay nada') "'$r2'"
Comp 'y va un paso mas atras' ([AX]::volumen -eq 70) "volumen=$([AX]::volumen)"
[void](Invoke-Deshacer)
Comp 'y el tercero otro mas' ([AX]::volumen -eq 10) "volumen=$([AX]::volumen)"
Comp 'la foto gastada sale de la pila' ($script:historial.Count -eq 0) "quedan $($script:historial.Count)"
$r4 = Invoke-Deshacer
Comp 'sin pila si dice que no hay nada' ($r4 -match 'No hay nada que deshacer') "'$r4'"

# el tope: con mas fotos que pasos permitidos se para, y lo DICE
$script:historial = New-Object System.Collections.ArrayList
foreach ($i in 1..($DeshacerMaxPasos + 2)) { [void]$script:historial.Add((Foto 1 $null $i)) }
$script:deshacer = $script:historial[$script:historial.Count - 1]
$script:deshacerSeguidos = 0
for ($i = 0; $i -lt $DeshacerMaxPasos; $i++) { [void](Invoke-Deshacer) }
$rT = Invoke-Deshacer
Comp 'al llegar al tope se para' ($script:historial.Count -eq 2) "quedan $($script:historial.Count)"
Comp 'y no miente: dice como seguir' ($rT -match 'ultimos cinco minutos') "'$rT'"

# una orden nueva rompe la cadena y vuelve a haber cinco pasos
$script:deshacerSeguidos = 3
Save-EstadoParaDeshacer
Comp 'una orden nueva reinicia la cuenta' ($script:deshacerSeguidos -eq 0) "seguidos=$($script:deshacerSeguidos)"

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
