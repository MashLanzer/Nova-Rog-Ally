# LO QUE HAY DETRAS DE UN SI (21/09). Tres fallos del mismo sistema, salidos de la tanda
# de agentes que reviso todo el codigo. Detras de una confirmacion si/no estan: mandar un
# correo, borrar una carpeta, borrar una lista, apagar, reiniciar y cerrar los juegos.
#
#  1. EL CORREO NO SE ENVIABA NUNCA. Sus pendientes se crean con texto = '' y el mensaje
#     dentro del campo 'correo', y NADIE leia ese campo: al decir "si" se caia en la cola
#     generica, que hace Process-Texto '' -> "vacio, ignorado" y una tarjeta que dice "No
#     te escuche". Sin voz, asi que braya se quedaba creyendo que el correo habia salido.
#  2. MANDAR UN CORREO POR NOMBRE se contradecia solo: encontraba la direccion en los
#     ultimos correos y en la linea siguiente contestaba "No tengo la direccion guardada".
#  3. LA PREGUNTA SE QUEDABA SIN MICROFONO. El bucle exige $script:seguimientoFactor > 0
#     para abrir el oido, y ese factor se queda en 0 desde que braya dice "...y ya". Cinco
#     sitios reabrian la escucha sin reponerlo: preguntaban al aire.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- 1. el correo: el campo que nadie leia --'
# lo que lo delataba: .correo solo aparecia en las dos lineas que lo ESCRIBEN
$lee = [regex]::Matches($fuente, '\$p\.correo')
Comp 'Complete-Confirmacion ya lee el campo correo' ($lee.Count -ge 3) "$($lee.Count) usos de \$p.correo"
Comp 'y la rama va ANTES de la cola generica' `
    ($fuente.IndexOf('if ($p.correo) {') -lt $fuente.IndexOf('CONFIRMAR: $respuesta -> se ejecuta'))
Comp 'reentra por Invoke-Correo, sin copiar el envio aqui' ($fuente -match '\$dC = \[string\]\(Invoke-Correo \$aC\)')
Comp 'con $script:confirmado puesto, o volveria a preguntar' `
    ($fuente -match "(?s)if \(\`$p\.correo\) \{.{0,400}\`$script:confirmado = \`$true")
Comp 'y lo devuelve a $false pase lo que pase' `
    ($fuente -match "(?s)if \(\`$p\.correo\) \{.{0,900}finally \{ \`$script:confirmado = \`$false \}")
# el texto viaja GUARDADO: volver a pedirselo al modelo podria redactar otra cosa distinta
# de la que se leyo en voz alta antes del "si"
Comp 'el texto sale del pendiente, no se vuelve a pedir' ($fuente -match "texto = \[string\]\`$p\.correo\.texto")
Comp 'y dice en voz alta como quedo' ($fuente -match "(?s)if \(\`$p\.correo\) \{.{0,900}Say \`$dC")

Write-Host ''
Write-Host '-- y que responda al correo que se leyo, no al ultimo que haya --'
# entre la pregunta y el "si", braya puede decir "lee mi correo" y mover $script:correoUltimo
Comp 'el numero del correo viaja en el pendiente' ($fuente -match 'accion = .responder.; n = \$nResp')
Comp 'y responder usa ese numero si lo trae' ($fuente -match '\$nResp = if \(\$a\.n\) \{ \[int\]\$a\.n \}')
Comp 'con el ultimo leido solo como respaldo' ($fuente -match '\$nResp = if .*elseif \(\$script:correoUltimo\)')
Comp 'ya no se envia contra $script:correoUltimo.n a ciegas' `
    ($fuente -notmatch "Invoke-CorreoScript @\('responder', \[string\]\`$script:correoUltimo\.n")

Write-Host ''
Write-Host '-- 2. el correo por nombre, que se contradecia solo --'
Comp 'ya no dice "no tengo la direccion" tras encontrarla' `
    ($fuente -notmatch 'No tengo la direccion de \$destino guardada')
Comp 'y deja apuntado de donde la saco' ($fuente -match 'CORREO: \$quien -> \$destino \(de los ultimos correos\)')
# lo que NO puede desaparecer: si de verdad no la encuentra, tiene que decirlo
Comp 'si no la encuentra sigue pidiendola entera' ($fuente -match 'No se cual es el correo de \$destino\. Dime la direccion entera\.')

Write-Host ''
Write-Host '-- 3. la pregunta que se quedaba sin microfono --'
Comp 'el bucle sigue exigiendo el factor para abrir el oido' `
    ($fuente -match '\$script:seguimientoPendiente -and \$SeguimientoMs -gt 0 -and \$script:seguimientoFactor -gt 0')
Comp 'y "...y ya" sigue pudiendo ponerlo a 0' ($fuente -match "listo\|y ya\|eso es todo[^\r\n]*\r?\n\s*\`$script:seguimientoFactor = 0")
# LO QUE SE ARREGLA: que no quede ni una reapertura sin reponerlo. Se cuenta sobre el
# archivo, no de memoria: si manana alguien anade otra, esto lo canta.
$pend = [regex]::Matches($fuente, '\$script:seguimientoPendiente = \$true')
$conFactor = 0
$sinFactor = @()
foreach ($m in $pend) {
    # VENTANA LARGA A PROPOSITO: en este archivo los comentarios que explican el porque
    # ocupan mas que el codigo, y con 260 caracteres uno de los catorce salia MAL teniendo
    # el factor seis lineas mas abajo, detras de un parrafo. Un rojo falso cuesta lo mismo
    # que un verde falso: media hora buscando donde no hay nada.
    $cola = $fuente.Substring($m.Index, [Math]::Min(700, $fuente.Length - $m.Index))
    if ($cola -match '\$script:seguimientoFactor') { $conFactor++ }
    else { $sinFactor += (($fuente.Substring(0, $m.Index) -split "`n").Count) }
}
Comp 'toda reapertura de escucha repone el factor' ($conFactor -eq $pend.Count) `
    $(if ($sinFactor.Count) { "sin factor en la linea " + ($sinFactor -join ', ') } else { "$conFactor de $($pend.Count)" })
# sin expresiones regulares: aqui hay $ y # por todas partes y escaparlos dos veces es
# justo como se cuela un patron que no casa con nada (me paso hoy con este mismo archivo)
Comp 'el despertador pide la hora con ventana larga' `
    ($fuente.Contains('$script:seguimientoFactor = 2.4   # una hora se piensa antes de decirla'))
Comp 'y "dimelo otra vez" abre el oido de verdad' `
    ($fuente.Contains('$script:seguimientoFactor = 1.0   # le pide que lo repita'))
Comp 'el parte de la manana oye el "cinco minutos mas"' `
    ($fuente.Contains('$script:seguimientoFactor = 1.0   # acaba de invitarle'))
Comp 'y la orden que sale de la charla sigue escuchando' `
    ($fuente.Contains('$script:seguimientoFactor = 1.0   # viene de una charla'))

Write-Host ''
Write-Host '-- 4. y el "si" fantasma del oido --'
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))
Comp 'el reconocedor de si/no ya trae confianza por palabra' ($oido -match 'r\.SetWords\(True\)')
Comp 'el "si" exige que haya sonado algo' ($oido -match 'if pico_rafaga >= RAFAGA_MIN_NOMBRE:\s*\r?\n\s*respuesta = "si"')
Comp 'la rafaga se pone a cero al preguntar' `
    ($oido -match 'conf_inicio = ahora[\s\S]{0,700}pico_rafaga = 0\.0[\s\S]{0,120}confirmacion: esperando si/no')
# EL "NO" SE QUEDA SIN GUARDA A PROPOSITO: cancelar de mas no hace dano, y hacerlo dificil si
Comp 'el "no" sigue sin guarda, a proposito' `
    ($oido -match 'if any\(w in PALABRAS_NO for w in palabras\):\s*\r?\n\s*respuesta = "no"')

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  un "si" hace lo que promete, y hace falta haber hablado para darlo'
exit 0
