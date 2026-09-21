# ¿SURTIO EFECTO LA ORDEN? (18/09) — NOVA-LLM, pieza 1: el bucle de verificacion.
#
# POR QUE EXISTE. El fallo mas caro de todo el proyecto fue "volumen al 70" dejando el volumen
# A CERO mientras Nova contestaba "volumen al 70 por ciento". Vivio semanas porque el banco
# comparaba la DESCRIPCION de la accion y nunca su efecto (ver tools\probar-acciones.py). Esto
# comprueba lo contrario: que despues de actuar, Nova MIRA como quedo la cosa.
#
# Lo que mas se comprueba aqui no es que detecte el fallo, sino que NO SE INVENTE NINGUNO:
# cuando no puede leer el volumen, cuando la orden es relativa, o cuando no es de su tipo,
# tiene que callarse. Un aviso falso de "no se puso" es peor que no comprobar nada.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}

# --- el mundo de mentira: el AX de verdad esta en assistant-dx.cs ---
class AX {
    static [int] $volumen = 50
    static [bool] $puedeLeer = $true
    static [bool] $ponerFunciona = $true
    static [int] LeerVolumen() { if (-not [AX]::puedeLeer) { return -1 }; return [AX]::volumen }
    static [bool] PonerVolumen([int]$v) {
        if (-not [AX]::ponerFunciona) { return $false }
        [AX]::volumen = [Math]::Max(0, [Math]::Min(100, $v)); return $true
    }
}
$script:brilloReal = 50
$script:brilloSeLee = $true
$script:puestos = @()
function Get-BrilloActual { if (-not $script:brilloSeLee) { return -1 }; return $script:brilloReal }
function Set-Brillo([int]$n) { $script:puestos += "brillo=$n"; $script:brilloReal = $n }
function Log($m) { }

$EfectoMargenVolumen = 2
$EfectoMargenBrillo = 5
Invoke-Expression (Traer 'Get-BrilloDestino')
Invoke-Expression (Traer 'Test-EfectoAccion')
Invoke-Expression (Traer 'Invoke-AccionOtraVez')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- el volumen: cuando SI se puso --'
[AX]::volumen = 70
$r = Test-EfectoAccion @{ kind = 'volumenPct'; pct = 70 }
Comp 'al 70 y esta al 70: correcto' ($r.ok) "esperado=$($r.esperado) real=$($r.real)"
[AX]::volumen = 71
Comp 'un punto de baile no es un fallo' ((Test-EfectoAccion @{ kind = 'volumenPct'; pct = 70 }).ok) ''

Write-Host '  -- y EL FALLO QUE MOTIVO ESTO: pedir 70 y quedarse en 0 --'
[AX]::volumen = 0
$r = Test-EfectoAccion @{ kind = 'volumenPct'; pct = 70 }
Comp 'lo detecta' (-not $r.ok) "esperado=$($r.esperado) real=$($r.real)"
Comp 'y dice en cuanto se quedo' ($r.real -eq 0 -and $r.esperado -eq 70) ''

Write-Host '  -- pedir mas de 100 no es un fallo (PonerVolumen recorta igual) --'
[AX]::volumen = 100
Comp 'pedir 150 y quedarse en 100 esta bien' ((Test-EfectoAccion @{ kind = 'volumenPct'; pct = 150 }).ok) ''

Write-Host '  -- y CALLA cuando no sabe (lo mas importante) --'
[AX]::puedeLeer = $false
Comp 'si no puede leer el volumen, no opina' ($null -eq (Test-EfectoAccion @{ kind = 'volumenPct'; pct = 70 })) ''
[AX]::puedeLeer = $true
Comp 'una accion que no es suya, no la juzga' ($null -eq (Test-EfectoAccion @{ kind = 'app'; target = 'steam' })) ''
Comp 'sin accion, no revienta' ($null -eq (Test-EfectoAccion $null)) ''
Comp 'sin kind tampoco' ($null -eq (Test-EfectoAccion @{ pct = 70 })) ''

Write-Host '  -- el brillo absoluto --'
$script:brilloReal = 40
$r = Test-EfectoAccion @{ kind = 'brillo'; nivel = 40 }
Comp 'al 40 y esta al 40: correcto' ($r.ok) "esperado=$($r.esperado) real=$($r.real)"
$script:brilloReal = 10
$r = Test-EfectoAccion @{ kind = 'brillo'; nivel = 80 }
Comp 'pedir 80 y quedarse en 10 se detecta' (-not $r.ok) "esperado=$($r.esperado) real=$($r.real)"
$script:brilloReal = 43
Comp 'un panel con saltos de 5 no es un fallo' ((Test-EfectoAccion @{ kind = 'brillo'; nivel = 40 }).ok) ''

Write-Host '  -- los relativos quedan fuera aposta (no se sabe el antes) --'
Comp 'subir un paso no se juzga' ($null -eq (Test-EfectoAccion @{ kind = 'brillo'; nivel = -1 })) ''
Comp 'bajar un paso tampoco' ($null -eq (Test-EfectoAccion @{ kind = 'brillo'; nivel = -2 })) ''
$script:brilloSeLee = $false
Comp 'y si no se lee el brillo, calla' ($null -eq (Test-EfectoAccion @{ kind = 'brillo'; nivel = 50 })) ''
$script:brilloSeLee = $true

Write-Host '  -- el calculo del destino, compartido con Set-Brillo --'
Comp 'absoluto: 60 es 60' ((Get-BrilloDestino 60 30) -eq 60) ''
Comp 'subir un paso: +20' ((Get-BrilloDestino -1 30) -eq 50) ''
Comp 'bajar un paso: -20' ((Get-BrilloDestino -2 30) -eq 10) ''
Comp 'no se pasa de 100' ((Get-BrilloDestino -1 95) -eq 100) ''
Comp 'ni baja de 0' ((Get-BrilloDestino -2 10) -eq 0) ''
Comp 'y un absoluto imposible se recorta' ((Get-BrilloDestino 250 30) -eq 100) ''

Write-Host '  -- reintentar: solo lo idempotente --'
[AX]::volumen = 0
Comp 'el volumen se reintenta' (Invoke-AccionOtraVez @{ kind = 'volumenPct'; pct = 70 }) ''
Comp 'y ahora si esta puesto' ([AX]::volumen -eq 70) "volumen=$([AX]::volumen)"
$script:puestos = @()
Comp 'el brillo absoluto se reintenta' (Invoke-AccionOtraVez @{ kind = 'brillo'; nivel = 80 }) ''
Comp 'y se llamo a Set-Brillo' ((($script:puestos -join ' ') -match 'brillo=80')) ($script:puestos -join ' ')
$script:puestos = @()
Comp 'un brillo RELATIVO no se reintenta (se moveria dos veces)' (-not (Invoke-AccionOtraVez @{ kind = 'brillo'; nivel = -1 })) ''
Comp 'y no se toco nada' ($script:puestos.Count -eq 0) ''
Comp 'abrir una app no se reintenta aqui' (-not (Invoke-AccionOtraVez @{ kind = 'app'; target = 'steam' })) ''

# --- y que el ejecutor lo use de verdad ---
Write-Host '  -- y el ejecutor lo comprueba antes de dar la orden por hecha --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'el ejecutor llama a Test-EfectoAccion' ($txt -match '\$efecto = Test-EfectoAccion \$a') ''
Comp 'y reintenta una vez' ($txt -match 'if \(Invoke-AccionOtraVez \$a\)') ''
Comp 'lo apunta para poder medirlo' ($txt -match "Add-Estadistica 'no-surtio-efecto'") ''
# lo que mas importa: que NO presuma. La descripcion que iba a decir se cambia por la verdad
Comp 'y corrige lo que iba a decir, en vez de presumir' ($txt -match 'lo intente dos veces y no se puso') ''
$i = $txt.IndexOf('$efecto = Test-EfectoAccion $a')
$j = $txt.IndexOf('$hechas += $a.desc', $i)
Comp 'la comprobacion va ANTES de dar la accion por hecha' ($i -gt 0 -and $j -gt $i) "comprueba=$i hechas=$j"

# Set-Brillo tiene 7 llamadores y en PowerShell un valor devuelto que nadie recoge se cuela
# en la salida de la funcion que envuelve: por eso el calculo se saco aparte y Set-Brillo
# sigue sin devolver nada.
$cuerpoSB = $txt.Substring($txt.IndexOf('function Set-Brillo'), 700)
Comp 'Set-Brillo sigue sin devolver nada' ($cuerpoSB -notmatch 'return \$destino') ''
Comp 'y usa el calculo compartido' ($cuerpoSB -match 'Get-BrilloDestino') ''

Write-Host ''
Write-Host '-- cerrar una app: que de verdad se haya cerrado (B9, 20/09) --'
# Hasta hoy la rama 'cerrarApp' mandaba cerrar y decia 'cerrado' sin mirar. Si la app
# pedia guardar y se quedaba abierta, Nova cantaba victoria igual: el mismo fallo de
# fondo que la mentira de las carpetas del 20/09.
$rC = Test-EfectoAccion @{ kind = 'cerrarApp'; proceso = 'proceso-que-no-existe-jamas' }
Comp 'un proceso que no esta, cuenta como cerrado' ($rC -and $rC.ok) ("real=" + $(if ($rC) { $rC.real } else { 'null' }))
$rV = Test-EfectoAccion @{ kind = 'cerrarApp'; proceso = 'powershell' }
Comp 'y uno que SIGUE vivo, como no cerrado' ($rV -and -not $rV.ok) ("real=" + $(if ($rV) { $rV.real } else { 'null' }))
Comp 'el juego no entra por aqui (tiene su propio camino)' ($null -eq (Test-EfectoAccion @{ kind = 'cerrarApp'; proceso = '*juego*' })) ''
Comp 'y una accion sin proceso tampoco' ($null -eq (Test-EfectoAccion @{ kind = 'cerrarApp' })) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
