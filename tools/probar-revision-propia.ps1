# NOVA SE REVISA A SI MISMA: que apague lo que no sirve, y SOLO eso.
# Y QUE SE PUEDA DESHACER HABLANDO, que es la otra mitad: un ajuste que se pone solo y
# no se quita diciendolo es justo lo que braya odia.
#
# Test-RevisionPropia es la primera funcion que cambia la configuracion de Nova sin que
# braya se lo pida. Eso da mas respeto que cualquier otra cosa de hoy, asi que lo que mas
# se comprueba aqui no es que apague, sino todo lo que NO debe hacer: no decidir sin
# historial, no tocar lo que si aporta, no actuar jugando ni con un invitado delante, y
# no repetirlo dos veces el mismo dia.
#
# Sin ayudantes que compartan estado: cada caso monta sus numeros y mira el resultado.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}

# --- el mundo de mentira, montado ANTES de traer la funcion ---
$script:invitado = $false
$script:juegoActivo = $null
$script:revisionPropiaDia = ''
$WhisperUltimo = 'large-v3-turbo'
$script:stats = @{ dias = @{} }
$script:cfgPuesta = @()
$script:avisos = @()
$script:apuntes = @()
$script:deshacer = $null
function Log($m) { }
function Get-Estadisticas { return $script:stats }
function Set-Cfg($sec, $clave, $valor) { $script:cfgPuesta += "$sec.$clave=$valor"; return $true }
function Add-Estadistica($ruta, $detalle) { $script:apuntes += "$ruta|$detalle" }
function Send-AvisoEntorno($clave, $texto, $nivel = 'medio', $cada = 60) { $script:avisos += $texto; return $true }
Invoke-Expression (Traer 'Save-DecisionPropia')
Invoke-Expression (Traer 'Undo-DecisionPropia')
Invoke-Expression (Traer 'Invoke-Deshacer')
Invoke-Expression (Traer 'Test-RevisionPropia')

$hoy = Get-Date
function Poner([int]$intentos, [int]$utiles) {
    # reparte los numeros en los ultimos 14 dias, como si fuera uso real
    $script:stats = @{ dias = @{} }
    $script:stats.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ turbo = $intentos; 'turbo-sirvio' = $utiles }
    $script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
    $script:revisionPropiaDia = ''
    $script:WhisperUltimo = 'large-v3-turbo'
    $script:invitado = $false
    $script:juegoActivo = $null
    $script:autoDecision = $null
    $script:deshacer = $null
}

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- lo que de verdad no sirve, lo apaga --'
Poner 29 1        # los numeros reales de braya: 29 intentos, 1 util
$r = Test-RevisionPropia $hoy
Comp 'con 1 util de 29, lo apaga' $r ''
Comp 'y deja la variable viva vacia' (-not $WhisperUltimo) "WhisperUltimo='$WhisperUltimo'"
Comp 'lo guarda en la configuracion' (@($script:cfgPuesta) -contains 'input.whisperModeloUltimo=') ($script:cfgPuesta -join ' ')
Comp 'y te lo dice, no lo hace a escondidas' (@($script:avisos).Count -eq 1) ''
Comp 'el aviso explica con sus numeros' ($script:avisos[0] -match '29') ''
Comp 'y dice como deshacerlo HABLANDO, no editando json' ($script:avisos[0] -match 'deshaz lo que has cambiado' -and $script:avisos[0] -notmatch 'config\.json') ''

Write-Host '  -- pero NO toca lo que si aporta (lo importante) --'
Poner 29 10       # un tercio util: eso se queda
$r = Test-RevisionPropia $hoy
Comp 'con 10 utiles de 29, no lo toca' (-not $r) ''
Comp 'la variable sigue puesta' ($WhisperUltimo -eq 'large-v3-turbo') "WhisperUltimo='$WhisperUltimo'"
Comp 'y no cambia la configuracion' (@($script:cfgPuesta).Count -eq 0) ''

Write-Host '  -- ni decide con cuatro datos --'
Poner 5 0         # nada util, pero cinco intentos no son historial
$r = Test-RevisionPropia $hoy
Comp 'con 5 intentos no juzga' (-not $r) ''
Comp 'la variable sigue puesta' ($WhisperUltimo -eq 'large-v3-turbo') ''

Write-Host '  -- y se calla cuando no toca --'
Poner 29 1
$script:juegoActivo = 'It Takes Two'
Comp 'jugando no se pone a revisarse' (-not (Test-RevisionPropia $hoy)) ''
Poner 29 1
$script:invitado = $true
Comp 'con un invitado delante tampoco' (-not (Test-RevisionPropia $hoy)) ''

Write-Host '  -- una vez al dia, no en cada vuelta del bucle --'
Poner 29 1
$primero = Test-RevisionPropia $hoy
$script:WhisperUltimo = 'large-v3-turbo'   # como si volviera a estar puesto
$segundo = Test-RevisionPropia $hoy
Comp 'la primera vez decide' $primero ''
Comp 'la segunda del mismo dia, no' (-not $segundo) ''
Comp 'y no avisa dos veces' (@($script:avisos).Count -eq 1) ("avisos: " + @($script:avisos).Count)

Write-Host '  -- si ya estaba apagado, no hace nada --'
Poner 29 1
$script:WhisperUltimo = ''
$r = Test-RevisionPropia $hoy
Comp 'no vuelve a apagar lo apagado' ((-not $r) -and @($script:cfgPuesta).Count -eq 0) ''

# ---------------------------------------------------------------------------
# DESHACERLO HABLANDO (17/09). La decision se apunta con su valor DE ANTES; si no,
# deshacerla seria adivinar a que estaba puesto.
Write-Host ''
Write-Host '  -- y se deshace hablando, sin tocar config.json --'
Poner 29 1
[void](Test-RevisionPropia $hoy)
Comp 'al decidir, apunta que deshacer' ($null -ne $script:autoDecision) ''
Comp 'y se acuerda del valor DE ANTES' ($script:autoDecision.antes -eq 'large-v3-turbo') "antes='$($script:autoDecision.antes)'"
$script:cfgPuesta = @()
$rD = Undo-DecisionPropia
Comp 'deshacerlo devuelve el valor de antes en vivo' ($WhisperUltimo -eq 'large-v3-turbo') "WhisperUltimo='$WhisperUltimo'"
Comp 'y lo guarda, no solo en memoria' (@($script:cfgPuesta) -contains 'input.whisperModeloUltimo=large-v3-turbo') ($script:cfgPuesta -join ' ')
Comp 'lo cuenta sin pedir que reinicies' ($rD -match 'ultimo recurso' -and $rD -notmatch 'reinicies') "'$rD'"
Comp 'y ya no queda nada que deshacer' ($null -eq $script:autoDecision) ''
Comp 'lo apunta en las estadisticas' ((@($script:apuntes) -join ' ') -match 'auto-deshecho') ''
$rD2 = Undo-DecisionPropia
Comp 'pedirlo dos veces no miente ni rompe' ($rD2 -match 'No he cambiado nada') "'$rD2'"

Write-Host '  -- y no se pone a discutir contigo --'
Poner 29 1
[void](Test-RevisionPropia $hoy)
[void](Undo-DecisionPropia)
$otra = Test-RevisionPropia $hoy
Comp 'si se lo devuelves, hoy no lo vuelve a apagar' (-not $otra) ''
Comp 'y el valor sigue siendo el tuyo' ($WhisperUltimo -eq 'large-v3-turbo') "WhisperUltimo='$WhisperUltimo'"

Write-Host '  -- "deshaz" a secas: primero lo tuyo, y si no, lo suyo --'
Poner 29 1
[void](Test-RevisionPropia $hoy)
$script:deshacer = $null
$rE = Invoke-Deshacer
Comp 'sin nada tuyo, deshace lo que decidio ella' ($WhisperUltimo -eq 'large-v3-turbo') "'$rE'"
Comp 'y no contesta que no hay nada que deshacer' ($rE -notmatch 'No hay nada que deshacer') "'$rE'"
# con algo tuyo pendiente, manda lo tuyo: su ajuste sigue ahi para deshacerlo luego
Poner 29 1
[void](Test-RevisionPropia $hoy)
$script:deshacer = @{ cuando = (Get-Date); brillo = $null; volumen = -1
                      procesos = @(); juego = $null }
[void](Invoke-Deshacer)
Comp 'con algo tuyo pendiente, lo tuyo va primero' ($null -ne $script:autoDecision) ''
Comp 'y su ajuste sigue pendiente de deshacer' (-not $WhisperUltimo) "WhisperUltimo='$WhisperUltimo'"

# ---------------------------------------------------------------------------
# QUE LA FRASE LLEGUE. El "deshaz" generico termina en \b, SIN ancla final, asi que se
# come "deshaz lo que has cambiado" entera si alguien mueve el patron nuevo detras. Esto
# es lo unico que sujeta ese orden.
Write-Host ''
Write-Host '  -- la frase tiene que llegar a la puerta correcta --'
$txtA = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
$lineasA = $txtA -split "`r?`n"
$iNuevo = -1; $iGen = -1; $patNuevo = ''; $patGen = ''
for ($i = 0; $i -lt $lineasA.Count; $i++) {
    $l = $lineasA[$i]
    if ($iNuevo -lt 0 -and $l -match "^\s*'(\^\(\?:deshaz\|deshacer\|revierte\|quita\|anula\).+)'\s*\{\s*$") { $iNuevo = $i; $patNuevo = $Matches[1] }
    if ($iGen -lt 0 -and $l -match "^\s*'(\^\(\?:deshaz\|deshacer\|cancela eso.+)'\s*\{\s*$") { $iGen = $i; $patGen = $Matches[1] }
}
Comp 'sigue existiendo el patron de lo que cambio ella' ($iNuevo -ge 0) ''
Comp 'y el de deshacer de toda la vida' ($iGen -ge 0) ''
Comp 'el suyo va ANTES (si no, el generico se la come)' ($iNuevo -ge 0 -and $iGen -ge 0 -and $iNuevo -lt $iGen) "nuevo=$($iNuevo + 1) generico=$($iGen + 1)"
foreach ($frase in @('deshaz lo que has cambiado', 'deshaz lo que cambiaste', 'revierte lo que decidiste',
                     'deshaz lo que has hecho tu', 'quita lo que has apagado', 'deshaz todo lo que has cambiado tu')) {
    Comp "'$frase' llega" ($frase -match $patNuevo) ''
}
Comp 'y el generico se la habria comido (por eso el orden)' ('deshaz lo que has cambiado' -match $patGen) ''
# lo que NO debe llevarse: "deshaz" a secas sigue siendo el de siempre
Comp "'deshaz' a secas NO es el de ella" (-not ('deshaz' -match $patNuevo)) ''
Comp "'deshaz lo de los ultimos 5 minutos' tampoco" (-not ('deshaz lo de los ultimos 5 minutos' -match $patNuevo)) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
