# UN TECHO DE GANANCIA APRENDIDO, Y QUE LO RESPETEN LOS DOS CAMINOS QUE LA SUBEN
# (26/09, idea 16 de las 121).
#
# LO MEDIDO: 985 lineas de "recorte detectado: bajando ganancia" en los dos registros, y 564
# son de hoy. Emparejando cada recorte con el anterior y reconstruyendo la ganancia de partida
# -la bajada es fija, x0,6-, 329 de los 985 (el 33,4 %) llegaron con la ganancia YA POR ENCIMA
# de la que acababa de saturar. Uno de cada tres recortes es volver a pisar el mismo charco.
#
# ESTE BANCO SE PARTE EN DOS A PROPOSITO:
#   - probar-techo-funciones.py saca las cuatro funciones del arbol y las EJECUTA. Ahi esta
#     toda la logica, y por eso la logica vive en funciones de nivel de modulo y no en trozos
#     sueltos dentro del bucle de audio: dentro del bucle no la podria ejecutar nadie.
#   - este fichero comprueba el ENGANCHE, que es lo unico que el .py no puede ver: que los tres
#     sitios del bucle llaman a quien tienen que llamar, en el orden que toca.
#
# Y EL ORDEN IMPORTA MAS QUE LA LLAMADA. Si techo_apuntar fuera DESPUES de la bajada x0,6,
# aprenderia la ganancia ya bajada -x6 en vez de x10- y el techo saldria mas bajo que la
# realidad: Nova se quedaria sorda y ningun log lo diria.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$tp = [IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [Text.Encoding]::UTF8)
# SIN COMENTARIOS: si no, explicar en una nota por que se llama a techo_frenar contaria como
# llamarlo. Ya mordio en probar-aviso-ruido.
$pSin = (($tp -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. EL SITIO QUE BAJA: de ahi sale lo que se aprende --'
$iApu = $pSin.IndexOf('techo_apuntar(ganancia, ahora)')
$iBaj = $pSin.IndexOf('ganancia = round(max(GANANCIA_MIN, ganancia * 0.6), 1)')
Comp 'el recorte apunta la ganancia que saturo' ($iApu -ge 0) ''
Comp 'y sigue existiendo la bajada de siempre' ($iBaj -ge 0) 'x0,6'
# EL ORDEN: antes de bajarla. Con el orden al reves aprenderia x6 donde saturo x10.
Comp 'se apunta ANTES de bajarla' ($iApu -ge 0 -and $iBaj -gt $iApu) 'despues aprenderia la ya bajada'
Comp '  y pegado a ella' ($iApu -ge 0 -and ($iBaj - $iApu) -lt 120) "$($iBaj - $iApu) caracteres"
# SOLO EN LA RAMA DE VERDAD: si el recorte es del altavoz, ni se baja ni se aprende nada.
$nApu = @([regex]::Matches($pSin, 'techo_apuntar\(')).Count
Comp 'se apunta en un solo sitio' ($nApu -eq 2) "$nApu (la definicion y la llamada)"
$iAlt = $pSin.IndexOf('recorte con los altavoces sonando')
Comp '  y NO en la rama del altavoz' ($iAlt -ge 0 -and $iApu -gt $iAlt) 'ahi satura el altavoz, no tu voz'

Write-Host ''
Write-Host '-- 2. PRIMER CAMINO QUE SUBE: la vuelta a la ganancia buena --'
$iCabe = $pSin.IndexOf('techo_cabe(ganancia_buena, ahora)')
Comp 'la vuelta pregunta por el techo' ($iCabe -ge 0) ''
$blV = if ($iCabe -ge 0) { $pSin.Substring($iCabe, [Math]::Min(500, $pSin.Length - $iCabe)) } else { '' }
Comp '  y solo vuelve si cabe' ($blV -match 'ganancia = ganancia_buena') ''
# Y SE DICE. Sin esto el freno seria mudo y nadie sabria por que no vuelve.
Comp '  y cuando no cabe, lo dice' ($blV -match 'no vuelvo a la x') 'un freno mudo no se puede depurar'
# LAS GUARDAS VIEJAS SIGUEN: el techo se suma a CABE_MAX, no la sustituye.
$iCM = $pSin.IndexOf('suelo_ruido * ganancia_buena < CABE_MAX')
Comp 'CABE_MAX sigue en pie' ($iCM -ge 0 -and $iCM -lt $iCabe) 'el techo se suma, no sustituye'
Comp '  y el recorte reciente tambien' ($pSin -match 'ahora - ultimo_recorte > RECORTE_RECIENTE') ''

Write-Host ''
Write-Host '-- 3. SEGUNDO CAMINO QUE SUBE: la calibracion del pulso --'
$iRound = $pSin.IndexOf('ganancia = round(max(GANANCIA_MIN, min(GANANCIA_MAX, propuesta)), 1)')
$iFren = $pSin.IndexOf('techo_frenar(ganancia, anterior, ahora)')
$iAnt = $pSin.IndexOf('anterior = ganancia')
Comp 'la calibracion pasa por el techo' ($iFren -ge 0) ''
Comp '  guardando antes la de ahora' ($iAnt -ge 0 -and $iRound -gt $iAnt) 'si no, compararia consigo misma'
# DESPUES DEL REDONDEO: si fuera antes, round() podria devolverla por encima del tope otra vez.
Comp '  y frenando DESPUES de redondear' ($iRound -ge 0 -and $iFren -gt $iRound) 'antes, round() la volveria a pasar'
# Y EL TOPE DE SALTO Y EL SUELO SIGUEN, que no son lo mismo que el techo aprendido.
Comp 'el tope de salto por ciclo sigue' ($pSin -match 'min\(ganancia \+ PASO_MAX, propuesta\)') ''

Write-Host ''
Write-Host '-- 4. LA LOGICA, SACADA DEL ARCHIVO Y EJECUTADA --'
# en su propio .py: incrustar el codigo desde aqui lo dejaba con BOM y Python no lo parseaba
python (Join-Path $PSScriptRoot 'probar-techo-funciones.py')
if ($LASTEXITCODE -ne 0) { $mal++ }

Write-Host ''
Write-Host '-- 5. contra el registro de verdad --'
$rec = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'recorte detectado: bajando ganancia') { $rec++ }
    }
}
Write-Host ("       'recorte detectado' sale $rec veces en los dos registros")
Comp 'el problema existe y es grande' ($rec -ge 200) 'medidos 985, y 329 pisando el mismo charco'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  la ganancia que saturo no se vuelve a poner'
exit 0
