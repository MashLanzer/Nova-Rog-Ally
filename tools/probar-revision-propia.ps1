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
$NubeOir = 'gemini'
$WhisperPreciso = 'small'
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
Invoke-Expression (Traer 'Test-DatosRepartidos')
Invoke-Expression (Traer 'Test-RevisionPropia')

$hoy = Get-Date
function Poner([int]$intentos, [int]$utiles) {
    # REPARTIDO EN TRES DIAS (17/09): desde que existe Test-DatosRepartidos, un monton de
    # intentos de una sola tarde ya no vale para decidir. Se reparte como seria en uso real.
    $script:stats = @{ dias = @{} }
    $tercio = [int][Math]::Floor($intentos / 3)
    $resto = $intentos - ($tercio * 2)
    $script:stats.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ turbo = $tercio; 'turbo-sirvio' = $utiles }
    $script:stats.dias[$hoy.AddDays(-2).ToString('yyyy-MM-dd')] = @{ turbo = $tercio; 'turbo-sirvio' = 0 }
    $script:stats.dias[$hoy.AddDays(-3).ToString('yyyy-MM-dd')] = @{ turbo = $resto; 'turbo-sirvio' = 0 }
    $script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
    $script:revisionPropiaDia = ''
    $script:WhisperUltimo = 'large-v3-turbo'
    $script:NubeOir = 'gemini'
    $script:WhisperPreciso = ''
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
# IDEA 1: APAGAR LA NUBE QUE NO SIRVE (17/09).
# Antes de decidir hizo falta poder medir: habia tres contadores de desenlace y ninguno de
# INTENTO, asi que el log ensenaba 29 llamadas a Gemini y las estadisticas decian
# "nube-nada: 1". Con ese dato, cualquier decision habria sido mentira.
function PonerNube([int]$intentos, [int]$utiles) {
    $script:stats = @{ dias = @{} }
    $tercioN = [int][Math]::Floor($intentos / 3)
    $restoN = $intentos - ($tercioN * 2)
    $script:stats.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ 'nube-intento' = $tercioN; 'nube-sirvio' = $utiles }
    $script:stats.dias[$hoy.AddDays(-2).ToString('yyyy-MM-dd')] = @{ 'nube-intento' = $tercioN; 'nube-sirvio' = 0 }
    $script:stats.dias[$hoy.AddDays(-3).ToString('yyyy-MM-dd')] = @{ 'nube-intento' = $restoN; 'nube-sirvio' = 0 }
    $script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
    $script:revisionPropiaDia = ''
    $script:NubeOir = 'gemini'
    $script:WhisperPreciso = ''
    $script:WhisperUltimo = ''      # ya apagado: aqui se juzga la nube
    $script:invitado = $false
    $script:juegoActivo = $null
    $script:autoDecision = $null
    $script:deshacer = $null
}

Write-Host ''
Write-Host '  -- la nube que no sirve, la apaga --'
PonerNube 24 1
$rN = Test-RevisionPropia $hoy
Comp 'con 1 util de 24, apaga la nube' $rN ''
Comp 'y la deja vacia en vivo' (-not $NubeOir) "NubeOir='$NubeOir'"
Comp 'lo guarda en la configuracion' (@($script:cfgPuesta) -contains 'escucha.nubeOir=') ($script:cfgPuesta -join ' ')
Comp 'y lo dice con sus numeros' (@($script:avisos).Count -eq 1 -and $script:avisos[0] -match '24') ''

Write-Host '  -- pero NO la apaga si aporta --'
PonerNube 24 6        # el 25 %: se queda
Comp 'con 6 utiles de 24, no la toca' (-not (Test-RevisionPropia $hoy)) ''
Comp 'la nube sigue puesta' ($NubeOir -eq 'gemini') "NubeOir='$NubeOir'"

Write-Host '  -- ni juzga sin intentos suficientes --'
PonerNube 8 0         # ocho intentos no son historial
Comp 'con 8 intentos no juzga' (-not (Test-RevisionPropia $hoy)) ''
Comp 'la nube sigue puesta' ($NubeOir -eq 'gemini') ''

Write-Host '  -- y se deshace hablando, como lo demas --'
PonerNube 24 1
[void](Test-RevisionPropia $hoy)
$script:cfgPuesta = @()
$rD3 = Undo-DecisionPropia
Comp 'devuelve la nube en vivo' ($NubeOir -eq 'gemini') "NubeOir='$NubeOir'"
Comp 'y lo guarda' (@($script:cfgPuesta) -contains 'escucha.nubeOir=gemini') ($script:cfgPuesta -join ' ')
Comp 'sin pedir que reinicies' ($rD3 -notmatch 'reinicies') "'$rD3'"

Write-Host '  -- UNA decision al dia: la segunda pisaria a la primera --'
# las dos cosas mal a la vez: turbo inutil Y nube inutil
$script:stats = @{ dias = @{} }
foreach ($dd in 1..3) {
    $script:stats.dias[$hoy.AddDays(-$dd).ToString('yyyy-MM-dd')] = @{
        turbo = 10; 'turbo-sirvio' = $(if ($dd -eq 1) { 1 } else { 0 })
        'nube-intento' = 8; 'nube-sirvio' = $(if ($dd -eq 1) { 1 } else { 0 }) }
}
$script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
$script:revisionPropiaDia = ''
$script:NubeOir = 'gemini'; $script:WhisperUltimo = 'large-v3-turbo'
$script:invitado = $false; $script:juegoActivo = $null; $script:autoDecision = $null
$uno = Test-RevisionPropia $hoy
$dos = Test-RevisionPropia $hoy
Comp 'decide una cosa' $uno ''
Comp 'y no una segunda el mismo dia' (-not $dos) ''
Comp 'solo un aviso' (@($script:avisos).Count -eq 1) ("avisos: " + @($script:avisos).Count)
Comp 'y la decision guardada se puede deshacer' ($null -ne $script:autoDecision) ''

Write-Host '  -- si la nube ya esta apagada, no se mete con ella --'
PonerNube 24 1
$script:NubeOir = ''
Comp 'no vuelve a apagar lo apagado' (-not (Test-RevisionPropia $hoy)) ''

# --- y que el INSTRUMENTO siga puesto: sin el, la decision es sobre un dato falso ---
Write-Host '  -- y el contador que lo hace posible sigue ahi --'
$txtN = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'Start-NubeOir cuenta cada intento' ($txtN -match "Add-Estadistica 'nube-intento'") ''
Comp 'y se apunta cuando la nube sobra' ($txtN -match "Add-Estadistica 'nube-sobra'") ''

# IDEA 2: UN SOLO DIA NO ES UNA COSTUMBRE (17/09).
# Al ir a decidir el umbral de la palabra salio que 41 de los 49 descartes por confianza
# eran del mismo dia (11/09), justo cuando la ganancia arrancaba en x8 y el microfono
# saturaba: un fallo YA arreglado. Y lo mismo pasaba con lo que Nova ya decide: los 29
# intentos del ultimo recurso son de un unico dia.
Write-Host ''
Write-Host '  -- una decision no sale de una sola tarde --'
$st1 = @{ dias = @{} }
$st1.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ turbo = 29 }
Comp 'con 29 intentos de UN dia, no hay reparto' (-not (Test-DatosRepartidos $st1 'turbo' $hoy)) ''

$st2 = @{ dias = @{} }
foreach ($dd in 1..3) { $st2.dias[$hoy.AddDays(-$dd).ToString('yyyy-MM-dd')] = @{ turbo = 10 } }
Comp 'repartido en tres dias, si vale' (Test-DatosRepartidos $st2 'turbo' $hoy) ''

$st3 = @{ dias = @{} }
$st3.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ turbo = 28 }
$st3.dias[$hoy.AddDays(-2).ToString('yyyy-MM-dd')] = @{ turbo = 1 }
$st3.dias[$hoy.AddDays(-3).ToString('yyyy-MM-dd')] = @{ turbo = 1 }
Comp 'tres dias pero uno concentra el 93 %, no vale' (-not (Test-DatosRepartidos $st3 'turbo' $hoy)) ''

$st4 = @{ dias = @{} }
$st4.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ turbo = 10 }
$st4.dias[$hoy.AddDays(-2).ToString('yyyy-MM-dd')] = @{ turbo = 10 }
Comp 'dos dias no bastan, hacen falta tres' (-not (Test-DatosRepartidos $st4 'turbo' $hoy)) ''
Comp 'y sin ningun dato, tampoco' (-not (Test-DatosRepartidos (@{ dias = @{} }) 'turbo' $hoy)) ''
Comp 'una clave que no existe no revienta' (-not (Test-DatosRepartidos $st2 'no-existe' $hoy)) ''

Write-Host '  -- y la revision propia lo exige de verdad --'
# los numeros REALES de braya el 15/09: 29 intentos, 1 util... todos del mismo dia
$script:stats = @{ dias = @{} }
$script:stats.dias['2026-09-15'] = @{ turbo = 29; 'turbo-sirvio' = 1 }
$script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
$script:revisionPropiaDia = ''
$script:WhisperUltimo = 'large-v3-turbo'; $script:NubeOir = ''
$script:invitado = $false; $script:juegoActivo = $null; $script:autoDecision = $null
Comp 'con los 29 de una tarde NO decide' (-not (Test-RevisionPropia ([datetime]'2026-09-16'))) ''
Comp 'y no toca nada' (@($script:cfgPuesta).Count -eq 0) ($script:cfgPuesta -join ' ')

# IDEA 3: EL OIDO FINO, CON LOS INVENTOS EN CONTRA (17/09).
# Acierta 27 de 81, pero se INVENTA la orden 5 veces. Un invento no es "no aporto": es una
# orden equivocada. Asi que lo que se mide es el acierto NETO, sirvio menos inventado.
function PonerFino([int]$repasos, [int]$sirvio, [int]$invento) {
    $script:stats = @{ dias = @{} }
    $t = [int][Math]::Floor($repasos / 3); $r = $repasos - ($t * 2)
    $script:stats.dias[$hoy.AddDays(-1).ToString('yyyy-MM-dd')] = @{ fino = $t; 'fino-sirvio' = $sirvio; 'fino-invento' = $invento }
    $script:stats.dias[$hoy.AddDays(-2).ToString('yyyy-MM-dd')] = @{ fino = $t; 'fino-sirvio' = 0; 'fino-invento' = 0 }
    $script:stats.dias[$hoy.AddDays(-3).ToString('yyyy-MM-dd')] = @{ fino = $r; 'fino-sirvio' = 0; 'fino-invento' = 0 }
    $script:cfgPuesta = @(); $script:avisos = @(); $script:apuntes = @()
    $script:revisionPropiaDia = ''
    $script:WhisperPreciso = 'small'
    $script:WhisperUltimo = ''; $script:NubeOir = ''    # aqui se juzga el fino
    $script:invitado = $false; $script:juegoActivo = $null
    $script:autoDecision = $null; $script:deshacer = $null
}

Write-Host ''
Write-Host '  -- el oido fino que ya no compensa, lo apaga --'
PonerFino 24 2 0
Comp 'con 2 aciertos de 24, lo apaga' (Test-RevisionPropia $hoy) ''
Comp 'y lo deja vacio en vivo' (-not $WhisperPreciso) "WhisperPreciso='$WhisperPreciso'"
Comp 'lo guarda' (@($script:cfgPuesta) -contains 'input.whisperModeloPreciso=') ($script:cfgPuesta -join ' ')

Write-Host '  -- LOS INVENTOS CUENTAN EN CONTRA (lo que mejora la idea) --'
PonerFino 24 10 0
Comp 'con 10 aciertos limpios de 24, NO lo toca' (-not (Test-RevisionPropia $hoy)) ''
Comp 'el fino sigue puesto' ($WhisperPreciso -eq 'small') "WhisperPreciso='$WhisperPreciso'"
PonerFino 24 10 9
Comp 'mismos aciertos pero 9 inventos: lo apaga' (Test-RevisionPropia $hoy) '(neto 1 de 24)'
Comp 'y el aviso nombra los inventos' ($script:avisos[0] -match 'invento') ''

Write-Host '  -- con los numeros REALES de braya no se apaga --'
# 81 repasos, 27 aciertos, 5 inventos -> neto 22 de 81 = 27 %, muy por encima del 15 %
PonerFino 81 27 5
Comp 'con 27 aciertos y 5 inventos de 81, se queda' (-not (Test-RevisionPropia $hoy)) ''
Comp 'el fino sigue puesto' ($WhisperPreciso -eq 'small') ''

Write-Host '  -- y el reparto tambien lo frena --'
# los dias REALES: 17, 60 y 4 -> el peor concentra el 74 %
$script:stats = @{ dias = @{} }
$script:stats.dias['2026-09-12'] = @{ fino = 17; 'fino-sirvio' = 0; 'fino-invento' = 0 }
$script:stats.dias['2026-09-15'] = @{ fino = 60; 'fino-sirvio' = 1; 'fino-invento' = 0 }
$script:stats.dias['2026-09-16'] = @{ fino = 4;  'fino-sirvio' = 0; 'fino-invento' = 0 }
$script:cfgPuesta = @(); $script:avisos = @(); $script:revisionPropiaDia = ''
$script:WhisperPreciso = 'small'; $script:WhisperUltimo = ''; $script:NubeOir = ''
$script:invitado = $false; $script:juegoActivo = $null; $script:autoDecision = $null
Comp 'aunque el ratio sea malo, un dia con el 74 % no decide' (-not (Test-RevisionPropia ([datetime]'2026-09-17'))) ''
Comp 'y no toca nada' (@($script:cfgPuesta).Count -eq 0) ($script:cfgPuesta -join ' ')

Write-Host '  -- y se deshace hablando --'
PonerFino 24 2 0
[void](Test-RevisionPropia $hoy)
$script:cfgPuesta = @()
$rF = Undo-DecisionPropia
Comp 'devuelve el oido fino en vivo' ($WhisperPreciso -eq 'small') "WhisperPreciso='$WhisperPreciso'"
Comp 'y lo guarda' (@($script:cfgPuesta) -contains 'input.whisperModeloPreciso=small') ($script:cfgPuesta -join ' ')
Comp 'sin pedir que reinicies' ($rF -notmatch 'reinicies') "'$rF'"

Write-Host '  -- si ya estaba apagado, no se mete --'
PonerFino 24 2 0
$script:WhisperPreciso = ''
Comp 'no vuelve a apagar lo apagado' (-not (Test-RevisionPropia $hoy)) ''

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
