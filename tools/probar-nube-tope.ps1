# C9 (21/09): que Nova ajuste SOLA lo que espera a la nube.
#
# El tope nacio en 2.500 ms y se subio a 7.000 el 19/09 porque 2,5 s se quedaba corto.
# Nadie sabia si 7 sobra o falta, porque hasta el 20/09 no se apuntaba CUANTO tarda la
# nube en contestar, solo SI llegaba. Con esos tiempos ya guardados, esto es la decision.
#
# LO QUE SE PRUEBA AQUI es la aritmetica de la decision, que es lo que puede hacer dano:
# un tope por debajo del p90 tira respuestas BUENAS que iban a llegar, y uno muy por
# encima hace esperar de mas cuando la nube no va a contestar. Y sobre todo: que con
# pocos datos NO se toque nada.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA (aprendida cinco veces): toda funcion que se llame aqui TIENE que estar en esta
# lista, o la prueba corre contra algo que no existe y pasa en verde sin probar nada.
foreach ($fn in @('Get-NubeTiempos', 'Get-NubeDias', 'Add-NubeTiempo', 'Get-NubePercentil')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

$DecisionMinIntentos = [int]([regex]::Match($fuente, '(?m)^\$DecisionMinIntentos\s*=\s*(\d+)').Groups[1].Value)
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('nubetope-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$NubeTiemposJson = Join-Path $base 'nube-tiempos.json'
$NubeTiemposMax = 200
function Log($t) { }

# La cuenta, sacada TAL CUAL del archivo real y no copiada a mano: si alli cambia el
# margen o el redondeo, esta prueba mide lo que hay y no lo que habia.
# EL TECHO BAJO DE 12 A 9 SEGUNDOS EL 21/09, porque no es cosmetico: alimenta
# $script:nubeVence y el bucle principal se QUEDA PARADO esperandolo. El patron se ata al
# suelo -que no ha cambiado- y coge hasta el techo sea el que sea, para que bajarlo otra
# vez no rompa esto; el valor se lee del archivo mas abajo y se comprueba de verdad.
$mCalc = [regex]::Match($fuente, '(?ms)\$p90N = Get-NubePercentil 90.*?if \(\$quieroN -gt (\d+)\) \{ \$quieroN = \d+ \}')
if (-not $mCalc.Success) { Write-Host '  MAL  no encuentro el calculo del tope en assistant.ps1'; exit 1 }
$calculo = [scriptblock]::Create($mCalc.Value)
$TECHO = [int]$mCalc.Groups[1].Value
function TopeQueSaldria { . $calculo; return $quieroN }

function PonTiempos([int[]]$ms) {
    $script:nubeMs = $null
    Remove-Item -LiteralPath $NubeTiemposJson -Force -ErrorAction SilentlyContinue
    foreach ($x in $ms) { [void](Add-NubeTiempo $x) }
}

Write-Host '-- con pocos datos no se decide nada --'
PonTiempos @(1000, 2000, 3000)
Comp "con 3 respuestas no llega al minimo de $DecisionMinIntentos" ((@(Get-NubeTiempos)).Count -lt $DecisionMinIntentos)

Write-Host ''
Write-Host '-- la cuenta: el tope sale del p90 mas el margen, redondeado a medio segundo --'
# 30 respuestas rapidas: p90 = 1200 ms -> 1200+800 = 2000
PonTiempos (1..30 | ForEach-Object { 400 + ($_ * 30) })
$p90 = Get-NubePercentil 90
$t = TopeQueSaldria
Comp 'nube rapida: el tope baja mucho' ($t -le 3000 -and $t -gt $p90) "p90=$p90 -> tope=$t"
Comp 'y son 4,5 s menos de espera que ahora' ((7000 - $t) -ge 4000) ("ahorra " + (7000 - $t) + " ms")

# 30 respuestas de 2 a 5 s: p90 cerca de 4,7 s -> ~5500
PonTiempos (1..30 | ForEach-Object { 2000 + ($_ * 100) })
$p90 = Get-NubePercentil 90
$t = TopeQueSaldria
Comp 'nube normal: el tope cubre el p90' ($t -ge ($p90 + 800) -and $t -le ($p90 + 1300)) "p90=$p90 -> tope=$t"
Comp 'y nunca queda por debajo del p90' ($t -gt $p90) "$t > $p90"

# nube lenta: p90 por encima del techo
PonTiempos (1..30 | ForEach-Object { 11000 + ($_ * 200) })
$p90 = Get-NubePercentil 90
$t = TopeQueSaldria
Comp 'nube muy lenta: el tope se para en el techo' ($t -eq $TECHO) "p90=$p90 -> tope=$t (techo $TECHO)"

Write-Host ''
Write-Host '-- el suelo y el techo, que son lo que impide un numero absurdo --'
PonTiempos (1..25 | ForEach-Object { 10 })
Comp 'ni con respuestas instantaneas baja de 2 s' ((TopeQueSaldria) -eq 2000) ("tope=" + (TopeQueSaldria))
PonTiempos (1..25 | ForEach-Object { 60000 })
Comp "ni con respuestas de un minuto sube de $([Math]::Round($TECHO/1000.0,1)) s" ((TopeQueSaldria) -eq $TECHO) ("tope=" + (TopeQueSaldria))
# y que ese techo siga siendo una espera que se pueda aguantar: el bucle se queda PARADO
# en un while hasta que vence, asi que un techo alto es tiempo callada sin contestar nada
Comp 'y el techo no pasa de 10 s de espera bloqueante' ($TECHO -le 10000) "$TECHO ms"

Write-Host ''
Write-Host '-- y NO se mueve por una diferencia pequena --'
# el codigo solo cambia si la diferencia con el tope de ahora llega a 1 s
PonTiempos (1..30 | ForEach-Object { 5400 })
$t = TopeQueSaldria
Comp 'el tope que saldria esta a menos de 1 s de 7000' ([Math]::Abs($t - 7000) -lt 1000) "tope=$t"
Comp 'y el codigo exige ese segundo para tocarlo' ($fuente -match '\[Math\]::Abs\(\$quieroN - \$NubeTopeMs\) -ge 1000')

Write-Host ''
Write-Host '-- y se puede deshacer hablando --'
Comp 'la decision se apunta con su valor de antes' ($fuente -match "Save-DecisionPropia 'escucha' 'nubeTopeMs'")
Comp 'y Undo sabe devolver el tope en vivo' ($fuente -match "'escucha\.nubeTopeMs' \{ \`$script:NubeTopeMs = \[int\]\`$d\.antes \}")
Comp 'no decide dos veces el mismo dia' ($fuente -match '\$script:revisionPropiaDia = \$ahora\.ToString')

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  el tope de la nube sale del p90 de sus respuestas, con suelo, techo y vuelta atras'
exit 0
