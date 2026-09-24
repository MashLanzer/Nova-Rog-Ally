# "NO ESTABA HABLANDO CONTIGO" SE CALLA, Y UN "SI" SUELTO NO VA A LA API (18/09).
#
# De las grabaciones de la noche del 18/09:
#   - 21:33 y 22:07: Nova se metio en una conversacion de braya con otra persona ("nova nova",
#     confianza 1,00), gasto ~20 s y dos llamadas a la API, y el le dijo "no, no estaba hablando
#     contigo". Eso ahora la calla y suelta lo pendiente, sin decir nada.
#   - 19:04 y 20:15: un "Si" sin pregunta viva fue local -> charla -> "es una orden" -> local ->
#     API (traducir) -> "ruido". Dos llamadas para nada: al volver de la charla se descarta.
#
# Como probar-asentimiento.ps1: Process-Texto no se puede cargar, asi que se SACAN LOS PATRONES
# DEL ARCHIVO REAL y se prueban contra lo que deben y lo que NO deben pillar. Lo que mas se
# vigila es lo que no puede entrar: "no" a secas, "no abras nada", "no era eso", "no te
# entiendo" son ordenes o respuestas de verdad y tienen que seguir su camino.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$lineas = [System.IO.File]::ReadAllLines((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# --- 1) el patron de "no era para mi": la linea de encima del Log ---
$idx = -1
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($lineas[$i] -match 'Log "no era para mi:') { $idx = $i; break }
}
if ($idx -lt 1) { Write-Host '  MAL  no encuentro la rama "no era para mi" en assistant.ps1'; exit 1 }
$m = [regex]::Match($lineas[$idx - 1], "-match '([^']+)'")
if (-not $m.Success) { Write-Host "  MAL  la linea de encima no lleva un patron: $($lineas[$idx - 1])"; exit 1 }
$patron = $m.Groups[1].Value
Comp 'el patron esta anclado por los dos lados' ($patron.StartsWith('^') -and $patron.EndsWith('$'))

Write-Host '  -- lo que SI es "no era para mi" (ya sin tildes, como llega de ConvertTo-Plain) --'
foreach ($f in @('no estaba hablando contigo', 'no no estaba hablando contigo', 'no, no estaba hablando contigo',
                 'no era contigo', 'no te hablaba a ti', 'no te estaba hablando a ti', 'no es para ti', 'no hablaba contigo',
                 'no hablo contigo', 'no te hablo a ti', 'eso no era contigo', 'perdona, no era contigo', 'no iba contigo',
                 'no estaba hablando contigo nova', 'nova no era contigo', 'no te lo decia a ti', 'no era para ti')) {
    Comp "'$f' se reconoce" ($f -match $patron)
}
Write-Host '  -- lo que NO puede entrar aqui --'
foreach ($f in @('no', 'no abras nada', 'no era eso', 'no te entiendo', 'no hables', 'no me hables', 'no estaba hablando',
                 'hablando contigo he aprendido dos cosas', 'no hablo con nadie', 'no era contigo abre steam', 'estaba hablando contigo',
                 'no cierres nada', 'no, cierra el navegador')) {
    Comp "'$f' NO es 'no era para mi'" (-not ($f -match $patron))
}
# lo que hace la rama: soltar lo pendiente y callarse, sin Say
$cuerpo = ($lineas[$idx..($idx + 14)] -join "`n")
Comp 'apunta el destino como ruido (fue una activacion falsa)' ($cuerpo -match "Write-DestinoUso 'ruido'")
Comp 'suelta la pregunta viva' ($cuerpo -match '\$script:pendiente = \$null')
Comp 'apaga el seguimiento' ($cuerpo -match '\$script:seguimientoPendiente = \$false')
Comp 'corta la charla' ($cuerpo -match 'Stop-Charla')
Comp 'y NO dice nada (sin Say)' (-not ($cuerpo -match '(?m)^\s*Say '))

# --- 2) el "si" suelto que devuelve la charla ---
$idx2 = -1
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($lineas[$i] -match "\`$ev\.ev -eq 'orden' -and \(ConvertTo-Plain") { $idx2 = $i; break }
}
if ($idx2 -lt 0) { Write-Host '  MAL  no encuentro la guarda del "si" suelto en el rebote de la charla'; exit 1 }
$m2 = [regex]::Match($lineas[$idx2], "-match '([^']+)'")
if (-not $m2.Success) { Write-Host "  MAL  la guarda no lleva un patron: $($lineas[$idx2])"; exit 1 }
$patron2 = $m2.Groups[1].Value
Write-Host '  -- el "si" suelto que devuelve la charla --'
foreach ($f in @('si', 'no', 'si.', 'vale', 'claro', 'dale', 'ok')) {
    Comp "'$f' suelto se descarta sin ir a la API" ($f -match $patron2)
}
foreach ($f in @('si abre steam', 'no cierres nada', 'vale gracias', 'si, pon la novena cancion', 'claro que si abre el navegador')) {
    Comp "'$f' sigue siendo una orden" (-not ($f -match $patron2))
}
# la guarda tiene que ir ANTES del elseif de siempre, o nunca se llega a ella
$idxViejo = -1
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($lineas[$i] -match "\} elseif \(\`$ev\.ev -eq 'orden'\) \{") { $idxViejo = $i; break }
}
Comp 'la guarda va delante del rebote de siempre' ($idxViejo -gt $idx2)
$cuerpo2 = ($lineas[$idx2..($idx2 + 9)] -join "`n")
Comp 'y no llama a Submit-Command (nada a la API)' (-not ($cuerpo2 -match 'Submit-Command'))

Write-Host ''
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
