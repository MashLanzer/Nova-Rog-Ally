# QUE CORREGIRLA HABLANDO TOQUE EL RECUERDO (26/09, idea 11 de las 121).
#
# Nova ya sabia reconocer una correccion -por_que_importa la caza para guardar el turno- pero
# eso no tocaba el RECUERDO que estaba mal: se quedaba firme en el cerebro y lo volvia a decir.
# El unico camino que lo tachaba exigia que el asistente pusiera duda=true, y ese camino sale
# de un patron ANCLADO con ^ que, medido sobre las 61 correcciones habladas de catorce dias,
# caza CERO. Por eso "queda como incorrecta" aparece UNA vez en 59.872 lineas de registro.
#
# LOS NUMEROS, recontados: 365 turnos hablados, 61 correcciones (16,7 %), y de esas 61 solo UNA
# trae un par "no es X, es Y" con la palabra mala DENTRO de lo que Nova acababa de decir. O sea
# que el valor esta en TACHAR (60 casos), no en sustituir (1). La sustitucion sale casi gratis
# porque el patron ya existia en el asistente, pero no se puede vender como el motivo.
#
# LA VENTANA SALE DE LOS DATOS: de esas 61, el hueco con el turno anterior da p50 35 s, p75 55
# y p90 166. Dentro de 180 s caen 55 de 61 (90 %), y de 180 a 300 no entra NI UNA mas.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$tw = [IO.File]::ReadAllText((Join-Path $raiz 'charla_worker.py'), [Text.Encoding]::UTF8)
$tm = [IO.File]::ReadAllText((Join-Path $raiz 'charla_memoria.py'), [Text.Encoding]::UTF8)
$wSin = (($tw -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$mSin = (($tm -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. el detector es el que YA habia, no uno nuevo --'
# UN SEGUNDO DETECTOR se separaria del primero al mes siguiente y nadie se enteraria. Se usa
# por_que_importa, el mismo que decide guardar el turno entero.
Comp 'usa por_que_importa' ($wSin -match 'por_que_importa\(texto, ""\) == "correccion"') 'el mismo que decide guardar el turno'
Comp '  y no define otro patron de correccion' (@([regex]::Matches($wSin, 'RE_CORRIGE\s*=')).Count -eq 1) 'sigue habiendo uno solo'
# NEGACION_PALABRAS = 5 NO SE TOCA: hay un banco que lo saca del archivo.
Comp '  y NEGACION_PALABRAS sigue en 5' ($tw -match '(?m)^NEGACION_PALABRAS = 5') 'un banco lo saca del archivo'

Write-Host ''
Write-Host '-- 2. la ventana, de los datos --'
$m = [regex]::Match($tw, '(?m)^CORRIGE_VENTANA_S = ([0-9]+)')
Comp 'se saca del archivo CORRIGE_VENTANA_S' $m.Success ''
if ($m.Success) { $CORRIGE_VENTANA_S = [int]$m.Groups[1].Value }
Comp '  cubre el 90 % de las correcciones' ($CORRIGE_VENTANA_S -ge 180) "$CORRIGE_VENTANA_S s; 55 de 61 caen dentro"
Comp '  y no se pasa: de 180 a 300 no entra ni una mas' ($CORRIGE_VENTANA_S -le 300) "$CORRIGE_VENTANA_S s"
# EL HUECO SE LEE ANTES DE PISARLO: ultima_charla se reasigna dos lineas mas abajo.
Comp 'el hueco se guarda antes de pisar ultima_charla' ($wSin -match 'hueco = ahora - ultima_charla[\s\S]{0,200}ultima_charla = ahora') 'leerlo despues daria siempre 0'

Write-Host ''
Write-Host '-- 3. las guardas del bloque nuevo --'
# EL BLOQUE SE DELIMITA POR SU PRIMERA Y SU ULTIMA LINEA, no por una ventana de caracteres
# (26/09, lo cazo una rotura). Contando 300 caracteres hacia atras se colaba el 'return' de la
# rama de la trivia, que esta justo encima, y el banco cantaba que este bloque cortaba el turno
# cuando no lo hace. Una ventana fija cambia de significado en cuanto el codigo se mueve.
$i = $wSin.IndexOf('if (cerebro is not None and not invitado and not duda')
$iF = $wSin.IndexOf('no pude corregir', [Math]::Max(0, $i))
$bl = if ($i -ge 0 -and $iF -gt $i) { $wSin.Substring($i, $iF - $i) } else { '' }
foreach ($g in @(@('cerebro is not None', 'sin cerebro no hay nada que corregir'),
                 @('not invitado', 'en modo invitado no se toca la memoria'),
                 @('not duda', 'si el asistente ya dudo, ese camino lo hace el de siempre'),
                 @('ultimo_dicho is not None', 'sin saber QUE dijo, corregir seria adivinar'),
                 @('hueco <= CORRIGE_VENTANA_S', 'una correccion de hace media hora no habla de eso'))) {
    Comp ("  guarda: " + $g[0]) ($bl -match [regex]::Escape($g[0])) $g[1]
}
# UNA VEZ POR RECUERDO: "no, te equivocas" dos veces seguidas no puede tachar dos.
Comp '  y se olvida el recuerdo tras tocarlo' ($bl -match 'ultimo_dicho = None') 'dos "te equivocas" seguidos tacharian dos recuerdos'
# NO SE CONTESTA AQUI: marcar no es responder.
# EL BLOQUE ACABA EN SU except, no 2.200 caracteres despues (26/09, lo cazo una rotura): la
# ventana fija se comia el 'return' de la rama siguiente y el banco cantaba que este bloque
# cortaba el turno cuando no lo hace.
Comp '  sin cortar el turno' ($bl -notmatch '(?m)^\s+return\s*$') 'Nova sigue contestando a lo que le acaban de decir'

Write-Host ''
Write-Host '-- 4. corregir NO es inventar --'
Comp 'existe corregir_respuesta' ($mSin -match 'def corregir_respuesta') ''
$iC = $mSin.IndexOf('def corregir_respuesta')
$blC = if ($iC -ge 0) { $mSin.Substring($iC, [Math]::Min(2000, $mSin.Length - $iC)) } else { '' }
# LA GUARDA QUE MANDA: sin la palabra mala dentro de la respuesta, no se toca nada. Sin ella,
# "no es azul, es verde" reescribiria cualquier recuerdo que estuviera encima.
Comp '  exige que la palabra mala este en la respuesta' ($blC -match 're\.search\(r"\\b" \+ re\.escape\(plano\(malo\)\)') 'es lo unico que separa corregir de inventar'
Comp '  no resucita lo ya tachado' ($blC -match '== "rechazada"') ''
Comp '  y pasa por el filtro de lo sensible' ($blC -match 'sensible\(') 'lo que no debe guardarse sigue sin guardarse'
Comp '  y por el de longitud' ($blC -match 'limpio\(nueva') ''

Write-Host ''
Write-Host '-- 5. y el trabajo pendiente se va con el recuerdo --'
# EL BUG QUE HABIA: marcar_incorrecta tachaba el recuerdo y dejaba vivo su job. El revisor de
# fondo lo cogia mas tarde, lo daba por bueno y lo volvia a dejar firme. El job apunta al
# recuerdo por "recuerdo", no por "id".
$iM = $mSin.IndexOf('def marcar_incorrecta')
$blM = if ($iM -ge 0) { $mSin.Substring($iM, [Math]::Min(1400, $mSin.Length - $iM)) } else { '' }
Comp 'marcar_incorrecta saca su job de pendientes' ($blM -match 'j\.get\("recuerdo"\) != idm') 'si no, el revisor lo resucita'
Comp '  y corregir_respuesta tambien' ($blC -match 'j\.get\("recuerdo"\) != idm') ''
# LA FIRMA NO SE TOCA: probar-memoria.py la llama sin argumentos.
Comp '  y la firma de marcar_incorrecta sigue igual' ($mSin -match 'def marcar_incorrecta\(self, idr=None\)') 'probar-memoria.py la llama sin argumentos'

Write-Host ''
Write-Host '-- 6. contra el registro de verdad --'
$turnos = 0; $inc = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'CHARLA \(hablar\)') { $turnos++ }
        if ($l -match 'queda como incorrecta') { $inc++ }
    }
}
Write-Host ("       $turnos turnos hablados en el registro, y solo $inc recuerdo(s) tachado(s) en toda la vida de Nova")
Comp 'el problema existe' ($turnos -ge 100 -and $inc -le 5) 'con 61 correcciones medidas, uno solo tachado'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  corregirla hablando ya toca el recuerdo'
exit 0
