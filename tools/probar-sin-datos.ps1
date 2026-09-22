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
# 20/09: el aviso solo promete un apagado cuando la binomial ya da; hay que traerla.
$DecisionAlfa = if ($txtFuente -match '\$DecisionAlfa = ([0-9.]+)') { [double]$Matches[1] } else { 0.01 }
$DecisionPorAcierto = if ($txtFuente -match '\$DecisionPorAcierto = ([0-9]+)') { [int]$Matches[1] } else { 10 }
Invoke-Expression (Traer 'Get-DecisionPValor')
Invoke-Expression (Traer 'Test-DecisionSolida')
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
function Num([int]$turbo, [int]$sirvio, [int]$nubeI = 0, [int]$nubeS = 0, [int]$fino = 0, [int]$finoS = 0, [int]$finoInv = 0) {
    return @{ 'turbo' = $turbo; 'turbo-sirvio' = $sirvio; 'nube-intento' = $nubeI; 'nube-sirvio' = $nubeS
              'fino' = $fino; 'fino-sirvio' = $finoS; 'fino-invento' = $finoInv }
}

# los interruptores vivos: el aviso solo habla de lo que sigue encendido (D1)
$WhisperUltimo = 'large-v3-turbo'
$NubeOir = 'gemini'
$WhisperPreciso = ''            # el oido fino tiene su propio bloque mas abajo

Write-Host '  -- el caso de verdad: 1 de 45, pero todo de un dia --'
# 20/09: era 1 de 29, pero con alfa 0,01 esos numeros ya no son una decision esperando
# datos, sino una decision que aun no existe. Se sube a 45, que si da (p = 0,006).
$real = Stats @{ '2026-09-15' = @{ 'turbo' = 45; 'turbo-sirvio' = 1 } }
$t = Get-AvisoSinDatos $real (Num 45 1) $hoy
Comp 'avisa de que tiene una decision esperando' ($t -ne '') ("'" + $t + "'")
Comp 'y dice cuantas veces le sirvio' ($t -match '1 de 45') ''
Comp 'y de cuantos dias sale' ($t -match 'de 1 dia\b') ''
Comp 'y que no se fia de cambiar con tan poco' ($t -match 'no me fio') ''
Comp 'y que lo apagara si sigue asi' ($t -match 'lo apago y te aviso') ''

Write-Host '  -- y CALLA cuando no hay nada que contar --'
Comp 'sin intentos, nada' ((Get-AvisoSinDatos (Stats @{}) (Num 0 0) $hoy) -eq '') ''
$pocos = Stats @{ '2026-09-15' = @{ 'turbo' = 12; 'turbo-sirvio' = 0 } }
Comp 'con menos de 20 intentos, nada (no se juzga)' ((Get-AvisoSinDatos $pocos (Num 12 0) $hoy) -eq '') ''
$util = Stats @{ '2026-09-15' = @{ 'turbo' = 29; 'turbo-sirvio' = 9 } }
Comp 'si SI le sirve, no hay decision pendiente' ((Get-AvisoSinDatos $util (Num 29 9) $hoy) -eq '') ''
# 20/09: y si el ratio canta pero la cuenta no llega, tampoco. 1 de 29 da p = 0,055, y
# prometer 'si sigue asi lo apago' seria prometer un apagado que no toca.
$flojo = Stats @{ '2026-09-15' = @{ 'turbo' = 29; 'turbo-sirvio' = 1 } }
Comp 'con 1 de 29 la binomial no llega: no promete nada' ((Get-AvisoSinDatos $flojo (Num 29 1) $hoy) -eq '') ''

Write-Host '  -- y si los datos YA valen, calla: entonces decide sola --'
$rep = Stats @{ '2026-09-15' = @{ 'turbo' = 15; 'turbo-sirvio' = 0 }
                '2026-09-16' = @{ 'turbo' = 15; 'turbo-sirvio' = 1 }
                '2026-09-17' = @{ 'turbo' = 15; 'turbo-sirvio' = 0 } }
Comp 'repartido en 3 dias: no avisa, decide' ((Get-AvisoSinDatos $rep (Num 45 1) $hoy) -eq '') ''

Write-Host '  -- la nube tambien, por el mismo camino --'
$nube = Stats @{ '2026-09-16' = @{ 'nube-intento' = 45; 'nube-sirvio' = 1 } }
$tn = Get-AvisoSinDatos $nube (Num 0 0 45 1) $hoy
Comp 'avisa de la nube' ($tn -match 'nube') ("'" + $tn + "'")
Comp 'con su cifra' ($tn -match '1 de 45') ''

Write-Host '  -- y NO anuncia lo que ya esta apagado (18/09, D1) --'
# El ultimo recurso lleva apagado desde el 15/09 (config.json: whisperModeloUltimo = '').
# Sin esta guarda, la primera frase de la revision seria que va a apagar algo ya apagado.
$WhisperUltimo = ''
Comp 'con el ultimo recurso apagado, no lo menciona' ((Get-AvisoSinDatos $real (Num 45 1) $hoy) -eq '') ''
$WhisperUltimo = 'large-v3-turbo'
Comp 'y si vuelve a encenderse, vuelve a contarlo' ((Get-AvisoSinDatos $real (Num 45 1) $hoy) -match '1 de 45') ''
$NubeOir = ''
Comp 'lo mismo con la nube apagada' ((Get-AvisoSinDatos $nube (Num 0 0 45 1) $hoy) -eq '') ''
$NubeOir = 'gemini'

Write-Host '  -- y lo raro no lo rompe --'
Comp 'sin dias, no revienta' ((Get-AvisoSinDatos @{ dias = @{} } (Num 45 1) $hoy) -eq '') ''
Comp 'con stats vacio tampoco' ((Get-AvisoSinDatos @{} (Num 45 1) $hoy) -eq '') ''

Write-Host '  -- y con el corte puesto, esos dias ya no son una decision esperando --'
# 19/09, idea 61: si los 29 son de antes de arreglar el microfono, no es que falten dias, es
# que no hay decision. Callarse es lo correcto: lo que no se puede es decidir con ellos.
$DecisionDatosDesde = '2026-09-18'
Comp 'los 45 del 15/09 ya no cuentan' ((Get-AvisoSinDatos $real (Num 45 1) ([datetime]'2026-09-19')) -eq '') ''
$DecisionDatosDesde = ''
Comp 'y sin corte vuelve a avisar, como antes' ((Get-AvisoSinDatos $real (Num 45 1) $hoy) -match '1 de 45') ''

# EL OIDO FINO ERA EL CASO VIVO Y FALTABA (20/09, P5). El ultimo recurso esta apagado desde
# el 15/09 y la nube se juzga aparte: el fino es el unico de los tres que sigue encendido,
# o sea el unico que podia tener una decision esperando... y del que Nova no decia nada.
Write-Host '  -- y el oido fino, que era el que faltaba --'
# LOS NUMEROS DE AQUI SALEN DE MEDIR, no de elegirlos bonitos (20/09). P4 y P5 se
# escribieron a la vez y se pisan: P5 traia 2 aciertos de 30, pero con el umbral que trajo
# P4 eso da p = 0,1514 y NO es solido, asi que Nova se calla, y hace bien. Este aviso
# promete "si sigue asi unos dias mas, lo apago": prometerlo con p = 0,15 seria prometer
# algo que los numeros no sostienen. Medido sobre las funciones reales:
#     30 intentos, 0 utiles -> p = 0,0076  SOLIDO
#     30 intentos, 1 util   -> p = 0,0480  no
#     30 intentos, 2 utiles -> p = 0,1514  no
#     45 intentos, 1 util   -> p = 0,0060  SOLIDO
$WhisperPreciso = 'small'
$finoM = Stats @{ '2026-09-15' = @{ 'fino' = 30; 'fino-sirvio' = 0; 'fino-invento' = 1 } }
$tf = Get-AvisoSinDatos $finoM (Num 0 0 0 0 30 0 1) $hoy
Comp 'avisa del oido fino' ($tf -match 'oido fino') ("'" + $tf + "'")
Comp 'con su cifra' ($tf -match '0 de 30') ''
Comp 'y nombra los inventos' ($tf -match 'invente la orden 1') ''
# y con los mismos numeros pero SIN ser solidos, se calla (es el caso que traia P5)
$finoP = Stats @{ '2026-09-15' = @{ 'fino' = 30; 'fino-sirvio' = 2; 'fino-invento' = 1 } }
Comp 'con 2 de 30 (p=0,15) se calla, no lo promete' ((Get-AvisoSinDatos $finoP (Num 0 0 0 0 30 2 1) $hoy) -eq '') ''
# LOS INVENTOS CUENTAN EN CONTRA, igual que en Test-RevisionPropia: 6 aciertos limpios de
# 30 aportan (hacen falta 5), asi que no hay decision esperando.
$finoU = Stats @{ '2026-09-15' = @{ 'fino' = 30; 'fino-sirvio' = 6; 'fino-invento' = 0 } }
Comp 'si aporta limpio, no hay decision esperando' ((Get-AvisoSinDatos $finoU (Num 0 0 0 0 30 6 0) $hoy) -eq '') ''
# EL AVISO Y LA DECISION TIENEN QUE JUZGAR IGUAL (21/09). Aqui iba el acierto BRUTO a
# Test-DecisionSolida mientras Test-RevisionPropia -la que apaga el oido fino de verdad-
# le pasa el NETO (sirvio menos invento). Con 6 de 30 pero 6 inventos, el neto es 0: la
# decision de verdad lo ve como un cero redondo y este aviso lo veia como 6 y se callaba.
# O sea que Nova no avisaba de una decision que SI iba a tomar. Los numeros son los
# mismos que el caso de arriba, cambiando solo los inventos: si alguien vuelve a poner el
# bruto, este caso se cae y el de arriba no.
$finoN = Stats @{ '2026-09-15' = @{ 'fino' = 30; 'fino-sirvio' = 6; 'fino-invento' = 6 } }
$tn = Get-AvisoSinDatos $finoN (Num 0 0 0 0 30 6 6) $hoy
Comp 'con 6 aciertos y 6 inventos (neto 0) SI avisa' ($tn -match 'oido fino') ("'" + $tn + "'")
Comp 'y dice los dos numeros, no el neto a secas' (($tn -match '6 de 30') -and ($tn -match 'invente la orden 6')) ''

$finoR = Stats @{ '2026-09-15' = @{ 'fino' = 10; 'fino-sirvio' = 0; 'fino-invento' = 0 }
                  '2026-09-16' = @{ 'fino' = 10; 'fino-sirvio' = 0; 'fino-invento' = 0 }
                  '2026-09-17' = @{ 'fino' = 10; 'fino-sirvio' = 0; 'fino-invento' = 0 } }
Comp 'repartido en 3 dias: no avisa, decide' ((Get-AvisoSinDatos $finoR (Num 0 0 0 0 30 0 0) $hoy) -eq '') ''

Write-Host '  -- la nube tambien, por el mismo camino --'
$nube = Stats @{ '2026-09-16' = @{ 'nube-intento' = 45; 'nube-sirvio' = 1 } }
$tn = Get-AvisoSinDatos $nube (Num 0 0 45 1) $hoy
Comp 'avisa de la nube' ($tn -match 'nube') ("'" + $tn + "'")
Comp 'con su cifra' ($tn -match '1 de 45') ''

Write-Host '  -- y NO anuncia lo que ya esta apagado (18/09, D1) --'
# El ultimo recurso lleva apagado desde el 15/09 (config.json: whisperModeloUltimo = '').
# Sin esta guarda, la primera frase de la revision seria que va a apagar algo ya apagado.
$WhisperUltimo = ''
Comp 'con el ultimo recurso apagado, no lo menciona' ((Get-AvisoSinDatos $real (Num 45 1) $hoy) -eq '') ''
$WhisperUltimo = 'large-v3-turbo'
Comp 'y si vuelve a encenderse, vuelve a contarlo' ((Get-AvisoSinDatos $real (Num 45 1) $hoy) -match '1 de 45') ''
$NubeOir = ''
Comp 'lo mismo con la nube apagada' ((Get-AvisoSinDatos $nube (Num 0 0 45 1) $hoy) -eq '') ''
$NubeOir = 'gemini'

Write-Host '  -- y lo raro no lo rompe --'
Comp 'sin dias, no revienta' ((Get-AvisoSinDatos @{ dias = @{} } (Num 45 1) $hoy) -eq '') ''
Comp 'con stats vacio tampoco' ((Get-AvisoSinDatos @{} (Num 45 1) $hoy) -eq '') ''

Write-Host '  -- y con el corte puesto, esos dias ya no son una decision esperando --'
# 19/09, idea 61: si los 29 son de antes de arreglar el microfono, no es que falten dias, es
# que no hay decision. Callarse es lo correcto: lo que no se puede es decidir con ellos.
$DecisionDatosDesde = '2026-09-18'
Comp 'los 45 del 15/09 ya no cuentan' ((Get-AvisoSinDatos $real (Num 45 1) ([datetime]'2026-09-19')) -eq '') ''
$DecisionDatosDesde = ''
Comp 'y sin corte vuelve a avisar, como antes' ((Get-AvisoSinDatos $real (Num 45 1) $hoy) -match '1 de 45') ''

$WhisperPreciso = ''
Comp 'y con el oido fino apagado, no lo menciona' ((Get-AvisoSinDatos $finoM (Num 0 0 0 0 30 2 1) $hoy) -eq '') ''

# --- y que el codigo real lo use ---
Write-Host '  -- y la revision propia lo cuenta en sus tres salidas --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'existe el envoltorio que lo apunta' ($txt -match 'function Set-AvisoSinDatos') ''
# EL AVISO SUELTO SE FUE (20/09, P5): era nivel 'medio' y se lo comia la noche. Ahora se
# apunta y lo saca el parte de la manana, que es donde braya lo lee.
Comp 'ya no sale por un aviso suelto que se calla de noche' ($txt -notmatch "'auto-sin-datos'") ''
Comp 'lo deja apuntado para el parte' ($txt -match '\$script:parteSinDatos = \$t') ''
Comp 'y el parte de la manana lo recoge' ($txt -match '(?s)function Test-ParteManana.{0,6000}\$script:parteSinDatos') ''
Comp 'una vez cada 7 dias como mucho' ($txt -match '\.TotalDays -lt 7') ''
Comp 'y el reloj se marca cuando SALE, no cuando se intenta' ($txt -match '\$hbM\.sinDatosVisto = \$ahora\.ToString') ''
$n = ([regex]::Matches($txt, 'Set-AvisoSinDatos \$stR \$numR \$ahora')).Count
Comp 'se llama en las salidas sin decision' ($n -ge 4) "llamadas=$n"
# avisar NO es decidir: Test-RevisionPropia tiene que seguir diciendo $false
Comp 'y avisar no cuenta como decidir' ($txt -match 'return \$false\s*\r?\n\}\s*\r?\n\s*# IDEA 22') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
