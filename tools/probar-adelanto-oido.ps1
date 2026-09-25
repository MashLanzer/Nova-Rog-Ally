# TRANSCRIBIR MIENTRAS CALLAS, NO DESPUES (25/09, lo pidio braya)
#
# SU QUEJA: "se demora muchisimo en responderme y eso es desesperante", y la pregunta de la que
# salio esto: "como hace Alexa para contestar tan rapido".
#
# LO MEDIDO sobre 746 dictados reales del registro:
#   total, de "te escucho" a "ya tengo tu texto" ... 10,0 s de mediana
#   de eso, braya hablando ........................   5,5 s
#   LO QUE PONE NOVA ..............................   2,8 s
#   (transcribir, dentro de eso) ..................   2,2 s
#
# O sea que de los 2,8 s que pone Nova, 2,2 son transcribir. Y esos 2,2 s empiezan a contar
# CUANDO BRAYA YA HA CALLADO: antes de eso el audio esta ahi, quieto, sin que nadie lo mire.
#
# LO QUE HACE ALEXA, y es lo unico que la hace parecer instantanea: transcribe MIENTRAS hablas.
# Cuando callas, el texto ya esta.
#
# LO QUE SE HACE AQUI, que es la version segura de eso: Nova espera 1,5 s de silencio antes de
# dar la frase por cerrada (SILENCIO_FIN). Durante ese segundo y medio no hace nada. Ahora
# transcribe el audio que lleva acumulado en un hilo aparte; si al cerrar la frase resulta que
# lo unico que se anadio fue silencio, ese trabajo YA ESTA HECHO y se entrega al momento.
#
# POR QUE ES SEGURO: no cambia ninguna decision, solo ADELANTA el calculo. Si braya vuelve a
# hablar, el adelanto se tira y todo sigue como siempre. Y no se hace con un juego delante,
# porque gastar CPU de mas mientras se juega es la regla 5 de la casa.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PY = Join-Path $Raiz 'wake_vosk.py'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$py = [IO.File]::ReadAllText($PY)
$pyCod = (($py -split "`n") | Where-Object { $_.TrimStart() -notmatch '^\s*#' }) -join "`n"

Write-Host '-- 1. el adelanto existe y esta acotado --'
Comp 'existe la decision de si vale el adelanto' ($pyCod -match 'def vale_el_adelanto') ''
Comp 'y se lanza durante el silencio' ($pyCod -match 'def lanzar_adelanto|_adelanto\[') ''
# EL BLOQUE, NO LA LINEA (25/09, lo cazo el propio banco): la guarda del juego y la llamada
# estan en lineas distintas -es un if de varias condiciones-, asi que buscarlas en la misma
# linea daba rojo con el codigo perfectamente bien.
$iL = $pyCod.IndexOf('lanzar_adelanto(audio_dictado')
$blL = if ($iL -gt 0) { $pyCod.Substring([Math]::Max(0, $iL - 700), [Math]::Min(700, $iL)) } else { '' }
Comp 'NO se hace con un juego delante' ($blL -match 'not jugando') 'regla 5: no competir con el juego'
Comp 'ni mientras Nova habla' ($blL -match 'not callado') 'se oiria a si misma'
Comp 'y hay un margen medido, no un numero suelto' ($pyCod -match 'ADELANTO_MARGEN_SEG') ''

Write-Host ''
Write-Host '-- 2. LA DECISION, SACADA DEL ARCHIVO Y EJECUTADA --'
# en su propio .py: incrustar el codigo desde aqui lo dejaba con BOM y Python no lo parseaba
python (Join-Path $PSScriptRoot 'probar-adelanto-funciones.py')
if ($LASTEXITCODE -ne 0) { $mal++ }

Write-Host ''
Write-Host '-- 3. y no rompe lo de siempre --'
Comp 'el silencio de cierre sigue siendo el mismo' ($pyCod -match 'SILENCIO_FIN = 1\.5') 'el adelanto no acorta la espera'
Comp 'y el camino normal sigue existiendo' ($pyCod -match 'oir_parakeet\(audio_dictado\)') 'si el adelanto no vale, se transcribe como siempre'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova transcribe mientras callas'
exit 0
