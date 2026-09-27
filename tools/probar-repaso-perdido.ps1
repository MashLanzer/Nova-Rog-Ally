# SE QUEDA SIN SU REPASO FINO Y NO LO DICE (26/09, idea 9 de las 121).
#
# Cuando no hay RAM para un modelo, la guarda del oido lo deja sin cargar y escribe una linea
# en el log... que no lee nadie. Nova sigue funcionando, pero oye PEOR, y braya no tiene forma
# de saberlo: piensa que hoy le entiende mal sin mas.
#
# MEDIDO en assistant.log + assistant.log.1: TREINTA Y DOS veces en 18 dias -18 parakeet, 8 el
# oido fino y 6 canary-, repartidas en DIEZ sesiones distintas. Los megas que faltaban: minimo
# 24, mediana 376, maximo 906.
#
# Y NO ES EL AVISO DEL DISCO, aunque la idea original lo proponia: esto es RAM FISICA
# (ram_libre_mb -> GlobalMemoryStatusEx) y disco-poco habla de gigas de disco. Dos averias que
# solo se parecen en la palabra "libres". Juntarlas daria "Te quedan 10,7 gigas en el disco. Me
# he quedado sin mi repaso fino", y ademas se taparian entre ellas por compartir el reposo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$py = Join-Path $raiz 'wake_vosk.py'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$ta = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$tp = [IO.File]::ReadAllText($py, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$aSin = (($ta -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$pSin = (($tp -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. las CUATRO guardas marcan, no tres --'
# LA IDEA DECIA TRES. Son cuatro: omni tambien tiene su guarda, y aunque no ha saltado nunca
# (cero lineas "omni: no lo cargo" en 18 dias) hay que cubrirla o volvera a callarse el dia
# que el modelo se descargue.
$nGuardas = @([regex]::Matches($pSin, 'no lo cargo, solo quedan')).Count
Comp 'hay cuatro guardas de RAM' ($nGuardas -eq 4) "$nGuardas"
$nMarca = @([regex]::Matches($pSin, 'repaso_perdido = "')).Count
Comp '  y las cuatro marcan el repaso perdido' ($nMarca -ge 4) "$nMarca asignaciones"
foreach ($q in @('fino', 'parakeet', 'canary', 'omni')) {
    Comp "  marca '$q'" ($pSin -match ('repaso_perdido = "' + $q + ':')) ''
}
# CON LOS MEGAS QUE FALTAN, del liston EFECTIVO: la idea 44 cambio '- _libre' de la constante al
# valor que devuelve ram_que_pide, asi que ahora la marca dice cuantos MB faltan para el liston de
# verdad (medido), no para el 1200/900 a pelo.
Comp '  con los megas que faltan de verdad (del liston efectivo)' ($pSin -match '_pide - _libre') 'la mediana real son 376 MB'
# EL RESPALDO SIGUE EN 1200/900, pero el liston de cada modelo ya sale de lo medido (idea 44):
# canary y omni dejan de pedir prestado el liston del grande.
Comp 'el respaldo de RAM sigue en 1200/900' (($tp -match 'RAM_MIN_PARAKEET = 1200\.0') -and ($tp -match 'RAM_MIN_PRECISO = 900\.0')) 'son el respaldo cuando no hay huella medida'
Comp '  y el liston sale de ram_que_pide, no de la constante a pelo' (($pSin -match 'ram_que_pide\("canary"') -and ($pSin -match 'ram_que_pide\("parakeet"')) 'canary ya no pide el liston del grande'

Write-Host ''
Write-Host '-- 2. y se borra cuando el modelo SI carga --'
# SIN ESTO, cerrar el juego, liberar RAM y cargar parakeet bien dejaria a Nova quejandose de
# algo que ya se arreglo.
Comp 'existe _repaso_recuperado' ($pSin -match 'def _repaso_recuperado') ''
$nRec = @([regex]::Matches($pSin, '_repaso_recuperado\("')).Count
Comp '  y lo llaman los cuatro caminos de exito' ($nRec -eq 4) "$nRec llamadas"
# CADA UNO BORRA SOLO LO SUYO: si borrara a ciegas, recuperar canary taparia que parakeet
# sigue sin cargarse.
Comp '  borrando solo lo suyo' ($pSin -match 'repaso_perdido\.split\(":"\)\[0\] == cual') 'recuperar canary no puede tapar que falta parakeet'

Write-Host ''
Write-Host '-- 3. el octavo campo, AL FINAL --'
# LA LINEA CRECE POR DISENO: el asistente la lee por INDICE en cinco sitios, asi que un campo
# en medio cambiaria el significado de todos de golpe.
Comp 'el estado empieza por sus campos de siempre' ($pSin -match '"%\.1f\|%s\|%\.3f\|%d\|%d\|%d\|%d') ''
Comp '  y el nuevo va el ULTIMO' ($pSin -match 'desde_recorte,[\s\r\n]*repaso_perdido or "-"') ''
Comp '  con un guion cuando no falta nada' ($pSin -match 'repaso_perdido or "-"') 'un campo final vacio se confunde con un fichero cortado'

Write-Host ''
Write-Host '-- 4. el asistente lo lee con las guardas de siempre --'
$dG = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-RepasoPerdido' }, $true)
Comp 'existe Get-RepasoPerdido' ($null -ne $dG) ''
if ($dG) {
    $c = $dG.Extent.Text
    Comp '  mira que el fichero exista' ($c -match 'Test-Path -LiteralPath \$RutaEstado') ''
    Comp '  y que el estado no este rancio' ($c -match 'Test-EstadoFresco') 'las mismas guardas que Get-OidoFlojos'
    Comp '  y que el campo exista' ($c -match '\$st\.Count -lt 8') 'un oido viejo no trae octavo campo'
    Comp '  y trata el guion como "no falta nada"' ($c -match "-eq '-'") ''
}
$dT = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-AvisarSinRepaso' }, $true)
Comp 'existe Test-AvisarSinRepaso' ($null -ne $dT) ''
if ($dT) {
    Invoke-Expression $dT.Extent.Text
    Comp '  avisa cuando falta uno' ([bool](Test-AvisarSinRepaso 'parakeet' 376 $false)) 'el caso real: mediana 376 MB'
    Comp '  y no repite si ya aviso' ((Test-AvisarSinRepaso 'parakeet' 376 $true) -eq $false) ''
    Comp '  ni sin nombre' ((Test-AvisarSinRepaso '' 376 $false) -eq $false) ''
    Comp '  ni con cero megas' ((Test-AvisarSinRepaso 'parakeet' 0 $false) -eq $false) 'si no se pudo medir la RAM, no se inventa'
}

Write-Host ''
Write-Host '-- 5. y lo dice con clave propia, no colgado del disco --'
$iAv = $aSin.IndexOf("'oido-sin-repaso'")
Comp 'el aviso existe' ($iAv -ge 0) ''
$bl = if ($iAv -ge 0) { $aSin.Substring([Math]::Max(0, $iAv - 700), [Math]::Min(1400, $aSin.Length - [Math]::Max(0, $iAv - 700))) } else { '' }
Comp '  con clave propia, no disco-poco' ($bl -notmatch "'disco-poco'") 'son dos averias distintas'
Comp '  diciendo cuantos megas faltan' ($bl -match '\$\(\$rp\.mb\)') 'sin numero no se sabe si es cerrar una pestana o reiniciar'
Comp '  y ofreciendo el boton' ($bl -match 'boton') 'regla 7: segunda via'
# LA BANDERA SOLO SE MARCA SI EL AVISO SALIO: 'medio' se calla con un juego delante, que es
# justo cuando falta la RAM. Marcarla antes de tiempo se comeria el aviso entero.
function EnOrden([string]$t, [string]$a, [string]$b) {
    $ma = [regex]::Match($t, $a); if (-not $ma.Success) { return $false }
    return [regex]::Match($t.Substring($ma.Index + $ma.Length), $b).Success
}
Comp '  y la bandera solo si el aviso salio' (EnOrden $bl 'if \(Send-AvisoEntorno' 'sinRepasoAvisado = \$true') 'jugando es cuando falta la RAM: el aviso espera a que cierres'
# EL ORDEN: este es el menos urgente de los cuatro del oido, porque Nova SIGUE oyendo.
$iMudo = $aSin.IndexOf("'oido-mudo'"); $iFlojo = $aSin.IndexOf("'oido-flojo'")
Comp '  y va detras de los otros tres del oido' ($iMudo -ge 0 -and $iFlojo -ge 0 -and $iAv -gt $iFlojo -and $iFlojo -gt $iMudo) 'sordo manda sobre ruido, y ruido sobre esto'

Write-Host ''
Write-Host '-- 6. contra el registro de verdad --'
$n = 0; $porQuien = @{}
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match '(\S+(?: \S+)?): no lo cargo, solo quedan') {
            $n++
            $k = $Matches[1]
            if (-not $porQuien.ContainsKey($k)) { $porQuien[$k] = 0 }
            $porQuien[$k]++
        }
    }
}
Write-Host ("       $n repasos perdidos en el registro: " + (($porQuien.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key) x$($_.Value)" }) -join ', '))
Comp 'el caso existe y no es raro' ($n -ge 10) 'si fuera uno suelto, no valdria la pena avisar'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  cuando se queda sin un repaso, lo dice'
exit 0
