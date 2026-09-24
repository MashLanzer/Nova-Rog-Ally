# UN "OK" SUELTO NO ES RUIDO (18/09), pero tampoco puede tragarse nada mas.
#
# Con "gracias" detras ya se contestaba desde el 15/09; sin el, "ok" o "muy bien" a secas
# acababan en "No te entendi" -7 veces en 8 dias, la ultima documentada como
# "RUIDO descartado: 'Muy bien'" el 15/09 a las 18:30-.
#
# Process-Texto no se puede cargar en un probador: pasa de las 700 lineas y toca todo. Asi que
# se hace lo mismo que probar-umbrales.ps1 con los umbrales: SACAR EL PATRON DEL ARCHIVO REAL y
# probarlo contra lo que debe y lo que no debe pillar. Si alguien lo cambia, esto se entera.
#
# Lo que mas se vigila aqui no es lo que entra, sino lo que NO puede entrar:
#   - "si", "no", "claro", "dale" y "cancela" son PALABRAS_SI / PALABRAS_NO del worker
#     (wake_vosk.py): son respuestas a una pregunta viva. Si alguien las metiera en esta rama,
#     una confirmacion podria perderse por el camino.
#   - "ok abre steam" tiene que seguir siendo una ORDEN. De eso se encarga $FILLER_INI, pero si
#     este patron se aflojara (quitandole el $ del final, por ejemplo) se comeria la orden
#     entera y Nova se quedaria callada en vez de abrir Steam.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$lineas = [System.IO.File]::ReadAllLines((Join-Path $raiz 'assistant.ps1'))

$idx = -1
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($lineas[$i] -match 'Log "asentimiento:') { $idx = $i; break }
}
if ($idx -lt 1) { Write-Host '  MAL  no encuentro la rama del asentimiento en assistant.ps1'; exit 1 }
$m = [regex]::Match($lineas[$idx - 1], "'([^']+)'")
if (-not $m.Success) { Write-Host "  MAL  la linea de encima no lleva un patron: $($lineas[$idx - 1])"; exit 1 }
$patron = $m.Groups[1].Value
Write-Host "  patron sacado del archivo real: $patron"

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-46} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host '  -- lo que SI es un asentimiento --'
foreach ($f in @('ok', 'okay', 'okey', 'vale', 'muy bien', 'perfecto', 'genial', 'listo', 'entendido', 'de acuerdo')) {
    Comp "'$f' se reconoce" ($f -match $patron)
}

Write-Host '  -- y lo que NO puede caer aqui --'
# las respuestas a una pregunta viva: si esta rama se las tragara, la confirmacion se perderia
foreach ($f in @('si', 'no', 'claro', 'dale', 'cancela')) {
    Comp "'$f' es una respuesta, no un asentimiento" (-not ($f -match $patron))
}
# y las ordenes de verdad que EMPIEZAN por una muletilla
foreach ($f in @('ok abre steam', 'vale sube el volumen', 'bueno pon el modo noche', 'listo para empezar', 'busca cuanto vale una ps5 en google')) {
    Comp "'$f' sigue siendo una orden" (-not ($f -match $patron))
}
# "gracias" lo contesta la cortesia de arriba, con su "De nada"; aqui se cerraria en silencio
foreach ($f in @('gracias', 'ok gracias', 'muchas gracias')) {
    Comp "'$f' es de la cortesia, no de aqui" (-not ($f -match $patron))
}

Write-Host ''
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
