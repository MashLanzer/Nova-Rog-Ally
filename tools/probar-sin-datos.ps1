# LO QUE NO PUEDE DECIDIR, TAMBIEN SE CUENTA (18/09).
#
# Hasta hoy Nova solo hablaba cuando decidia algo. Pero puede pasar -y pasa ahora mismo- que los
# numeros canten y el freno de datos repartidos la pare: el ultimo recurso lleva 1 acierto de 29
# intentos (muy por debajo del 15 %) y no se apaga porque los 29 son TODOS del 15/09, y
# Test-DatosRepartidos pide >=3 dias y <=70 % en uno.
#
# El freno esta bien. Lo que estaba mal era callarselo: desde fuera no se distingue de "no hay
# nada que revisar". Aqui se comprueba que lo cuenta SOLO cuando toca.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
# LOS UMBRALES VIVEN EN assistant.ps1 (18/09, idea 62). Test-RevisionPropia y Get-AvisoSinDatos
# ya no llevan el 15 % ni los 20 intentos escritos a mano: usan $DecisionAprovecha,
# $DecisionMinIntentos y Get-DecisionMinimo. Aqui se LEEN del fuente en vez de copiarlos, que es
# justo lo que la idea 62 queria evitar: si cambian alli, esta prueba los sigue.
$txtFuente = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
$DecisionAprovecha = if ($txtFuente -match '\$DecisionAprovecha = ([0-9.]+)') { [double]$Matches[1] } else { 0.15 }
$DecisionMinIntentos = if ($txtFuente -match '\$DecisionMinIntentos = ([0-9]+)') { [int]$Matches[1] } else { 20 }
Invoke-Expression (Traer 'Get-DecisionMinimo')
Invoke-Expression (Traer 'Test-DiaCuenta')
Invoke-Expression (Traer 'Test-DatosRepartidos')
Invoke-Expression (Traer 'Get-AvisoSinDatos')
# EL CORTE, APAGADO AQUI A PROPOSITO (19/09, idea 61). Estos casos usan los dias REALES
# del 15 al 17/09, que son justo los que el corte por defecto (18/09) descarta: con el
# puesto, todos saldrian vacios y la prueba pasaria sin probar nada. Lo que se mira aqui
# es el aviso; el corte tiene sus casos en tools\probar-revision-propia.ps1.
$DecisionDatosDesde = ''

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
$hoy = [datetime]'2026-09-18'
function Stats([hashtable]$porDia) {
    $d = @{}
    foreach ($k in $porDia.Keys) { $d[$k] = $porDia[$k] }
    return @{ dias = $d }
}
function Num([int]$turbo, [int]$sirvio, [int]$nubeI = 0, [int]$nubeS = 0) {
    return @{ 'turbo' = $turbo; 'turbo-sirvio' = $sirvio; 'nube-intento' = $nubeI; 'nube-sirvio' = $nubeS }
}

# los interruptores vivos: el aviso solo habla de lo que sigue encendido (D1)
$WhisperUltimo = 'large-v3-turbo'
$NubeOir = 'gemini'

Write-Host '  -- el caso de verdad: 1 de 29, pero todo de un dia --'
$real = Stats @{ '2026-09-15' = @{ 'turbo' = 29; 'turbo-sirvio' = 1 } }
$t = Get-AvisoSinDatos $real (Num 29 1) $hoy
Comp 'avisa de que tiene una decision esperando' ($t -ne '') ("'" + $t + "'")
Comp 'y dice cuantas veces le sirvio' ($t -match '1 de 29') ''
Comp 'y de cuantos dias sale' ($t -match 'de 1 dia\b') ''
Comp 'y que no se fia de cambiar con tan poco' ($t -match 'no me fio') ''
Comp 'y que lo apagara si sigue asi' ($t -match 'lo apago y te aviso') ''

Write-Host '  -- y CALLA cuando no hay nada que contar --'
Comp 'sin intentos, nada' ((Get-AvisoSinDatos (Stats @{}) (Num 0 0) $hoy) -eq '') ''
$pocos = Stats @{ '2026-09-15' = @{ 'turbo' = 12; 'turbo-sirvio' = 0 } }
Comp 'con menos de 20 intentos, nada (no se juzga)' ((Get-AvisoSinDatos $pocos (Num 12 0) $hoy) -eq '') ''
$util = Stats @{ '2026-09-15' = @{ 'turbo' = 29; 'turbo-sirvio' = 9 } }
Comp 'si SI le sirve, no hay decision pendiente' ((Get-AvisoSinDatos $util (Num 29 9) $hoy) -eq '') ''

Write-Host '  -- y si los datos YA valen, calla: entonces decide sola --'
$rep = Stats @{ '2026-09-15' = @{ 'turbo' = 10; 'turbo-sirvio' = 0 }
                '2026-09-16' = @{ 'turbo' = 10; 'turbo-sirvio' = 1 }
                '2026-09-17' = @{ 'turbo' = 9;  'turbo-sirvio' = 0 } }
Comp 'repartido en 3 dias: no avisa, decide' ((Get-AvisoSinDatos $rep (Num 29 1) $hoy) -eq '') ''

Write-Host '  -- la nube tambien, por el mismo camino --'
$nube = Stats @{ '2026-09-16' = @{ 'nube-intento' = 24; 'nube-sirvio' = 1 } }
$tn = Get-AvisoSinDatos $nube (Num 0 0 24 1) $hoy
Comp 'avisa de la nube' ($tn -match 'nube') ("'" + $tn + "'")
Comp 'con su cifra' ($tn -match '1 de 24') ''

Write-Host '  -- y NO anuncia lo que ya esta apagado (18/09, D1) --'
# El ultimo recurso lleva apagado desde el 15/09 (config.json: whisperModeloUltimo = '').
# Sin esta guarda, la primera frase de la revision seria que va a apagar algo ya apagado.
$WhisperUltimo = ''
Comp 'con el ultimo recurso apagado, no lo menciona' ((Get-AvisoSinDatos $real (Num 29 1) $hoy) -eq '') ''
$WhisperUltimo = 'large-v3-turbo'
Comp 'y si vuelve a encenderse, vuelve a contarlo' ((Get-AvisoSinDatos $real (Num 29 1) $hoy) -match '1 de 29') ''
$NubeOir = ''
Comp 'lo mismo con la nube apagada' ((Get-AvisoSinDatos $nube (Num 0 0 24 1) $hoy) -eq '') ''
$NubeOir = 'gemini'

Write-Host '  -- y lo raro no lo rompe --'
Comp 'sin dias, no revienta' ((Get-AvisoSinDatos @{ dias = @{} } (Num 29 1) $hoy) -eq '') ''
Comp 'con stats vacio tampoco' ((Get-AvisoSinDatos @{} (Num 29 1) $hoy) -eq '') ''

Write-Host '  -- y con el corte puesto, esos dias ya no son una decision esperando --'
# 19/09, idea 61: si los 29 son de antes de arreglar el microfono, no es que falten dias, es
# que no hay decision. Callarse es lo correcto: lo que no se puede es decidir con ellos.
$DecisionDatosDesde = '2026-09-18'
Comp 'los 29 del 15/09 ya no cuentan' ((Get-AvisoSinDatos $real (Num 29 1) ([datetime]'2026-09-19')) -eq '') ''
$DecisionDatosDesde = ''
Comp 'y sin corte vuelve a avisar, como antes' ((Get-AvisoSinDatos $real (Num 29 1) $hoy) -match '1 de 29') ''

# --- y que el codigo real lo use ---
Write-Host '  -- y la revision propia lo cuenta en sus tres salidas --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'existe el envoltorio que habla' ($txt -match 'function Send-AvisoSinDatos') ''
Comp 'avisa como mucho una vez por semana' ($txt -match "'auto-sin-datos' \`$t 'medio' 10080") ''
$n = ([regex]::Matches($txt, 'Send-AvisoSinDatos \$stR \$numR \$ahora')).Count
Comp 'se llama en las salidas sin decision' ($n -ge 4) "llamadas=$n"
# avisar NO es decidir: Test-RevisionPropia tiene que seguir diciendo $false
Comp 'y avisar no cuenta como decidir' ($txt -match 'return \$false\s*\r?\n\}\s*\r?\n\s*# IDEA 22') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
