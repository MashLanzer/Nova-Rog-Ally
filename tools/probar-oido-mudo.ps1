# DECIR QUE ESTA SORDA, EN VEZ DE ANUNCIAR QUE ESCUCHA (24/09, idea 18 de la tanda nueva).
#
# EL DATO, medido sobre los 235 arranques del oido del registro: de la linea "escucha continua
# ACTIVA ... di 'nova'" a "worker Vosk en marcha" -que es cuando vuelve a oir de verdad- pasan
# 6 s de mediana y 12 s en el p90. Pero el p99 son 303 s y el maximo 1.716 s: VEINTIOCHO
# MINUTOS Y MEDIO diciendo "escucha activa, di nova" sin oir absolutamente nada.
#
# Y tras las seis muertes del microfono, los huecos de la muerte a volver a oir fueron 19 s,
# 45 s, 5 min 49, 12 min 42 y 35 min 14. En ninguno tenia braya forma de saberlo.
#
# Lo dice el propio codigo doce horas antes, en el comentario de Test-EstadoFresco:
# "Callarse es lo peor, porque desde fuera es identico a estar funcionando."
#
# LO QUE MAS SE VIGILA AQUI: que NO avise en un arranque normal. Hay unos 16 arranques del
# oido al dia; si el liston se bajara, Nova diria dieciseis veces al dia que esta sorda
# cuando solo estaba arrancando, y eso es exactamente el fallo de los 25 avisos identicos
# del 22/09 con otra ropa.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el mundo de mentira ----------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('mudo-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$RutaEstado = Join-Path $tmp 'escucha-estado.txt'
$script:dicho = @()
function Log([string]$m) { $script:dicho += $m }
# los dos numeros se leen del codigo: si alli cambian, el banco los sigue
$OidoMudoSegundos = if ($fuente -match '(?m)^\$OidoMudoSegundos = (\d+)') { [int]$Matches[1] } else { -1 }
$EstadoMaxSegundos = if ($fuente -match '(?m)^\$EstadoMaxSegundos = (\d+)') { [int]$Matches[1] } else { -1 }
$script:mudoAvisado = $false
$script:mudoDesdeMs = 0
foreach ($f in @('Get-OidoMudoDesde', 'Test-AvisarMudo')) { Invoke-Expression (Traer $f) }

function Limpia { $script:mudoAvisado = $false; $script:mudoDesdeMs = 0; $script:dicho = @() }

Write-Host ''
Write-Host '-- 1. un arranque normal NO puede avisar --'
Comp 'el liston sale del codigo' ($OidoMudoSegundos -gt 0) "$OidoMudoSegundos s"
Limpia
Comp 'recien refrescado, no avisa' ((Test-AvisarMudo 0 $true 1000) -eq $false) ''
Comp 'a los 6 s (la mediana del arranque), no avisa' ((Test-AvisarMudo 6 $true 2000) -eq $false) ''
Comp 'a los 12 s (el p90 del arranque), tampoco' ((Test-AvisarMudo 12 $true 3000) -eq $false) 'si no, avisaria en los 16 arranques de cada dia'
Comp 'a los 72 s (el refresco mas lento medido), tampoco' ((Test-AvisarMudo 72 $true 4000) -eq $false) 'n=2.665 pulsos'
# Y EL LISTON, POR ENCIMA DE LO MEDIDO: 72 s es el refresco mas lento que se ha visto nunca,
# asi que bajar de ahi es avisar de algo que pasa en condiciones normales.
Comp 'el liston esta por encima de los 72 s medidos' ($OidoMudoSegundos -gt 72) "$OidoMudoSegundos > 72"
Comp 'y por encima del liston de frescura, que son otra cosa' ($OidoMudoSegundos -gt $EstadoMaxSegundos) "$OidoMudoSegundos > $EstadoMaxSegundos"

Write-Host ''
Write-Host '-- 2. pero minutos callada, SI --'
Limpia
Comp 'a los 120 s avisa' ((Test-AvisarMudo 120 $true 5000) -eq $true) ''
Comp 'y el episodio queda apuntado' ($script:mudoDesdeMs -eq 5000) "$($script:mudoDesdeMs)"

Write-Host ''
Write-Host '-- 3. una vez por episodio, no cada vuelta del bucle --'
$script:mudoAvisado = $true     # esto es lo que hace el bucle cuando el aviso SALE
$repes = 0
for ($i = 0; $i -lt 200; $i++) { if (Test-AvisarMudo (300 + $i) $true (6000 + $i * 30)) { $repes++ } }
Comp '200 vueltas mas del bucle: ni un aviso mas' ($repes -eq 0) "$repes"
# y vuelve el pulso: se cierra el episodio
Comp 'al volver el pulso deja de avisar' ((Test-AvisarMudo 3 $true 99000) -eq $false) ''
Comp 'y el episodio se cierra' (($script:mudoDesdeMs -eq 0) -and (-not $script:mudoAvisado)) ''
Comp 'y queda dicho en el registro' (@($script:dicho | Where-Object { $_ -match 'volvio el pulso' }).Count -eq 1) "$(@($script:dicho) -join ' / ')"
Comp 'el episodio SIGUIENTE si vuelve a avisar' ((Test-AvisarMudo 120 $true 100000) -eq $true) 'si no, una sordera de la tarde no se diria'

Write-Host ''
Write-Host '-- 4. con el worker muerto NO habla: de eso ya habla la vigilancia --'
# Dos avisos por lo mismo es el fallo de los 25 avisos identicos del 22/09.
Limpia
Comp 'worker muerto y 600 s callada: no avisa' ((Test-AvisarMudo 600 $false 7000) -eq $false) 'lo dice la vigilancia que lo relanza'
Comp 'y no deja el episodio abierto' ($script:mudoDesdeMs -eq 0) ''
# y en cuanto vuelve a haber worker, el aviso vuelve a estar armado
Comp 'con el worker vivo otra vez, si avisa' ((Test-AvisarMudo 600 $true 8000) -eq $true) ''

Write-Host ''
Write-Host '-- 5. los segundos salen del fichero, no de un reloj propio --'
[System.IO.File]::WriteAllText($RutaEstado, 'x12.1|0.0|0.000|60|0', (New-Object System.Text.UTF8Encoding($false)))
(Get-Item -LiteralPath $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-300)
$seg = Get-OidoMudoDesde
Comp 'un estado de hace 300 s da ~300' (($seg -ge 295) -and ($seg -le 320)) "$seg s"
(Get-Item -LiteralPath $RutaEstado).LastWriteTime = (Get-Date)
Comp 'y uno recien escrito da ~0' ((Get-OidoMudoDesde) -le 3) ''
Remove-Item -LiteralPath $RutaEstado -Force
Comp 'sin fichero devuelve 0, no revienta' ((Get-OidoMudoDesde) -eq 0) 'el primer arranque de la vida no es una averia'

Write-Host ''
Write-Host '-- 6. lo que NO puede pasar --'
$tm = SinComentarios (Traer 'Test-AvisarMudo')
Comp 'la decision es pura: no habla ella sola' (($tm -notmatch 'Say\b') -and ($tm -notmatch 'Send-Aviso')) 'quien habla es el bucle, y pasa por el freno de mano'
Comp 'ni ejecuta una orden' (($tm -notmatch 'Invoke-FastCommand') -and ($tm -notmatch 'Submit-Command') -and ($tm -notmatch 'Process-Texto')) 'la regla 1'
$gm = SinComentarios (Traer 'Get-OidoMudoDesde')
Comp 'leer los segundos no bloquea el bucle' (($gm -notmatch 'Start-Sleep') -and ($gm -notmatch 'Invoke-RestMethod') -and ($gm -notmatch 'Get-Content')) 'es un LastWriteTime'

Write-Host ''
Write-Host '-- 7. y donde esta enganchado --'
$lineas = @($fuente -split "`r?`n")
$iM = ($lineas | Select-String -SimpleMatch 'Test-AvisarMudo (Get-OidoMudoDesde)' | Select-Object -First 1).LineNumber
$iR = ($lineas | Select-String -SimpleMatch 'Test-AvisarRuido (Get-OidoConRuido)' | Select-Object -First 1).LineNumber
Comp 'se llama desde el bucle' ($null -ne $iM) ''
Comp 'y ANTES que el aviso de ruido' ($null -ne $iR -and $iM -lt $iR) "mudo en $iM, ruido en $iR"
# SIN COMENTARIOS: el propio comentario del bloque explica por que es 'alto' y no 'medio',
# asi que la comprobacion de abajo casaba con el comentario aunque el codigo dijera 'medio'.
# Es el mismo tropiezo que ya costo dos roturas mudas en la tanda anterior.
$trozo = (($lineas[($iM - 8)..($iM + 8)] | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'mira si el worker esta vivo' ($trozo -match 'HasExited') ''
Comp "y va en nivel 'alto', no 'medio'" ($trozo -match "'alto'") "'medio' se calla de noche y jugando, que es cuando mas falta hace"
Comp 'el true solo se apunta si el aviso SALIO' ($trozo -match 'if \(Send-AvisoEntorno') 'si lo para el freno, se reintenta'

Write-Host ''
Write-Host '-- 8. y los tres lectores del estado siguen mirando si es fresco --'
# Get-OidoMudoDesde NO usa Test-EstadoFresco a proposito -es justo lo contrario: quiere saber
# cuanto lleva SIN refrescarse-, pero los tres que ya existian tienen que seguir usandolo.
foreach ($fn in @('Get-OidoConRuido')) {
    Comp "$fn sigue mirando la frescura" ((SinComentarios (Traer $fn)) -match 'Test-EstadoFresco') ''
}
$nFrescos = @([regex]::Matches($fuente, 'Test-EstadoFresco')).Count
Comp 'y sigue habiendo al menos tres lectores' ($nFrescos -ge 4) "$nFrescos usos (la funcion mas sus lectores)"

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya no dice que escucha mientras esta sorda'
exit 0
