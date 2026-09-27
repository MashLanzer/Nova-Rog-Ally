# EL JUEGO QUE SE ABRE Y SE MUERE A LOS DIEZ SEGUNDOS (26/09, idea 47 de las 121).
#
# El 25/09 ELDEN RING NIGHTREIGN murio 6 veces en una hora (11, 21, 11, 11, 11, 20 s cada intento)
# y Nova no dijo nada. Ahora cuenta las muertes consecutivas del mismo juego y, a la 3a, ofrece
# 'cierra steam'. La racha se rompe si el juego hace una partida de verdad (Clear) o si pasa mas
# de $JuegoVueltaMs desde la ultima muerte. Este banco corre Test-MuereAlArrancar de verdad.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

$JuegoVueltaMs = if ($fuente -match '(?m)^\$JuegoVueltaMs\s*=\s*(\d+)') { [int]$Matches[1] } else { -1 }
$script:juegoMuertesSeguidas = @{}
Invoke-Expression (Traer 'Test-MuereAlArrancar')
Invoke-Expression (Traer 'Clear-MuereAlArrancar')

Comp '0. $JuegoVueltaMs se lee del archivo (una hora)' ($JuegoVueltaMs -eq 3600000) "$JuegoVueltaMs"

Write-Host ''
Write-Host '  -- 1, 2: la racha real del 25/09 (por juego, primera >=3 en la 3a) --'
$script:juegoMuertesSeguidas = @{}
# los seis huecos reales entre muertes de NIGHTREIGN (en segundos): 0, 1520, 569, 1034, 142, 982
$ms = 0.0
$sec = @()
foreach ($gap in @(0, 1520, 569, 1034, 142, 982)) { $ms += $gap * 1000; $sec += (Test-MuereAlArrancar 'NIGHTREIGN' $ms) }
Comp '1. NIGHTREIGN cuenta 1..6 y la primera vez >=3 es la 3a' (($sec -join ',') -eq '1,2,3,4,5,6') ($sec -join ',')
$idx3 = 0; for ($k = 0; $k -lt $sec.Count; $k++) { if ($sec[$k] -ge 3) { $idx3 = $k; break } }
Comp '   >=3 no antes de la 3a muerte (indice 2)' ($idx3 -eq 2) "en el intento $($idx3 + 1)"
Comp '2. ELDEN RING (otro juego) nunca pasa de 1' ((Test-MuereAlArrancar 'ELDEN RING' 5000.0) -eq 1) 'se cuenta por juego, no todos juntos'

Write-Host ''
Write-Host '  -- 3, 4: la racha se rompe por partida buena y por tiempo --'
$script:juegoMuertesSeguidas = @{}
[void](Test-MuereAlArrancar 'Z' 0.0); [void](Test-MuereAlArrancar 'Z' 100.0); [void](Test-MuereAlArrancar 'Z' 200.0)
Clear-MuereAlArrancar 'Z'
Comp '3. tras una partida buena (Clear), la siguiente muerte vuelve a 1' ((Test-MuereAlArrancar 'Z' 300.0) -eq 1) 'no 4'
$script:juegoMuertesSeguidas = @{}
$w1 = Test-MuereAlArrancar 'W' 0.0
$w2 = Test-MuereAlArrancar 'W' ($JuegoVueltaMs - 1)
$script:juegoMuertesSeguidas = @{}
[void](Test-MuereAlArrancar 'W' 0.0)
$w3 = Test-MuereAlArrancar 'W' ($JuegoVueltaMs + 1)
Comp '4. a una hora menos 1 ms sigue la racha (2), a una hora + 1 ms vuelve a 1' ($w2 -eq 2 -and $w3 -eq 1) "dentro=$w2 fuera=$w3"

Write-Host ''
Write-Host '  -- 5..8: el aviso, en su sitio, en la 3a, por juego, con la frase de datos --'
$tsj = Traer 'Test-SalidaJuego'
# el bloque de la rama corta: del if de $JuegoMinimoPartida a su return
$iIf = $tsj.IndexOf('if ($minsS -lt $JuegoMinimoPartida)')
$iRet = $tsj.IndexOf('return', $iIf)
$corta = if ($iIf -ge 0 -and $iRet -gt $iIf) { $tsj.Substring($iIf, $iRet - $iIf) } else { '' }
Comp '5. el aviso esta DENTRO de la rama corta (no en Exit-Juego ni en la larga)' ($corta -match "Send-AvisoEntorno \(.juego-muere-") 'donde Test-PuedoAvisar no lo tira por "esta jugando"'
Comp '6. dispara en >=3, no en ==3 (si no, el episodio real quedaria mudo)' (($corta -match 'nSeg -ge 3') -and ($corta -notmatch 'nSeg -eq 3')) ''
# y que Test-PuedoAvisar tiene la guarda del pendiente (por eso el >=3 y no ==3)
$tpa = Traer 'Test-PuedoAvisar'
Comp '   Test-PuedoAvisar se calla con una confirmacion viva' ($tpa -match '\$script:pendiente') 'la 3a muerte coincidio con una; la 4a habla'
Comp '7. la frase lleva $nSeg y $segS, no numeros pegados' (($corta -match '\$nSeg') -and ($corta -match '\$segS')) 'anti instrumento mudo'
Comp '8. la clave del aviso lleva el nombre del juego' ($corta -match "'juego-muere-' \+ \`$s\.nombre|.juego-muere-. \+ \`$s\.nombre") 'para que el cadaMin no tape otro juego'
# el $segS se captura ANTES de $minsS (fuera de la ventana de 240 caracteres de probar-juegos)
$iSeg = $tsj.IndexOf('$segS = [int]$script:juegoSesionSeg')
$iMin = $tsj.IndexOf('$minsS = [int]$script:juegoSesionMin')
Comp '   y $segS se captura antes de $minsS (fuera del regex de 240)' ($iSeg -ge 0 -and $iMin -gt $iSeg) ''
# y Clear se llama en la rama larga (partida de verdad)
Comp '   Clear-MuereAlArrancar se llama al cerrar de verdad' ($tsj -match 'Clear-MuereAlArrancar') 'la partida buena limpia la racha'
# y los segundos se acumulan en Exit-Juego
$ej = Traer 'Exit-Juego'
Comp '   Exit-Juego acumula los segundos de la sentada' ($ej -match '\$script:juegoSesionSeg \+=') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'el juego que se muere al arrancar se caza' -ForegroundColor Green
exit 0
