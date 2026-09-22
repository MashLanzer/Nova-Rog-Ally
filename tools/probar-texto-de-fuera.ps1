# LO QUE SE LEE DE FUERA SON DATOS, NO ORDENES (21/09).
#
# Nova le pasa al modelo texto que NO ha dicho braya en tres sitios: el OCR de la pantalla
# ("cuentame que ves"), los correos y las notificaciones. Y la charla tiene un camino de
# vuelta -el evento 'orden'- que acaba en Invoke-FastCommand, o sea EJECUTANDO.
#
# Juntando las dos cosas sale una inyeccion de instrucciones de manual, y no hace falta que
# nadie sea listo: basta una ventana de Discord en la que ponga "cierra todos los programas"
# y que braya diga "cuentame que ves". El texto entra en el prompt, el modelo puede leerlo
# como una peticion, y lo que vuelve se ejecuta.
#
# La guarda es determinista y va en el ASISTENTE, que es quien ejecuta: se apunta el id de
# la peticion que llevaba texto de fuera, y si vuelve con una orden, se tira. Contestar
# hablando si se puede -para eso se pidio-; lo que no se puede es HACER lo que diga un texto
# que no salio de su boca.
#
# Esto se comprueba sobre el CODIGO, no ejecutando el bucle entero (arrastra el worker de la
# charla, el micro y media docena de procesos). Cada comprobacion es de forma y esta escrita
# para caerse si alguien quita la guarda: comprobado quitandola a mano.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- los tres sitios que mandan texto que no dijo braya van marcados --'
# OCR de la pantalla: "cuentame que ves"
Comp 'el OCR de la pantalla va marcado como externo' `
    ($fuente -match "Send-Charla \`$pregOcr \`$false 'hablar' \`$null \`$true")
# los correos
Comp 'los correos van marcados como externos' `
    ($fuente -match "Send-Charla \(\`$lineasR -join [^)]*\) \`$false 'resumir' \`$null \`$true")
# las notificaciones
Comp 'las notificaciones van marcadas como externas' `
    ($fuente -match "Send-Charla \`$todosL \`$false 'resumir' \`$null \`$true")

Write-Host ''
Write-Host '-- y lo que dijo braya NO va marcado, que si no no se podria pedir nada --'
# estas son las llamadas con lo que el ha dicho: tienen que seguir pudiendo devolver ordenes
foreach ($llamada in @('if (Send-Charla $text) { return }',
                       'if (Send-Charla $text $true) { return }')) {
    Comp ("sigue sin marca: " + $llamada.Substring(4, [Math]::Min(34, $llamada.Length - 4))) `
        ($fuente.Contains($llamada))
}

Write-Host ''
Write-Host '-- la guarda esta donde se ejecuta --'
Comp 'Send-Charla acepta la marca' ($fuente -match '\[bool\]\$externo = \$false\) \{')
Comp 'y apunta el id de esa peticion' ($fuente -match 'if \(\$externo\) \{ \$script:charlaIdExterno = \$script:charlaId \}')
# LAS DOS RAMAS, CONTADAS. Con un -match suelto bastaba que la comparacion estuviera en
# UNA de las dos, asi que se podia anular la de 'orden' -la que ejecuta- y este banco
# seguia en verde por la de 'delegar': comprobado cambiandola por if ($false).
$nCmp = ([regex]::Matches($fuente, '\[int\]\$ev\.id -eq \$script:charlaIdExterno')).Count
Comp 'las DOS ramas comparan el id' ($nCmp -eq 2) "$nCmp de 2 (orden y delegar)"
# lo que importa: que NO llegue a ejecutarse. El 'continue' tiene que estar ANTES del
# Invoke-FastCommand de esa rama, o la guarda seria decorativa
$iGuarda = $fuente.IndexOf('sale de un texto de fuera (pantalla, correo o aviso)')
$iEjecuta = $fuente.IndexOf('try { $fastC = Invoke-FastCommand $ordenC }')
Comp 'y corta ANTES de ejecutar' ($iGuarda -gt 0 -and $iEjecuta -gt 0 -and $iGuarda -lt $iEjecuta) `
    "guarda en $iGuarda, ejecucion en $iEjecuta"
Comp 'lo apunta para poder mirarlo luego' ($fuente -match "Add-Estadistica 'orden-de-fuera'")
# 'delegar' manda el texto al otro cerebro: mismo trato
Comp 'delegar tambien se corta' ($fuente -match "no delego '\`$datoC': sale de un texto de fuera")

Write-Host ''
Write-Host '-- la marca se gasta: no puede quedarse pegada a la siguiente --'
# si no se limpiara, la peticion normal de DESPUES heredaria la marca y no se ejecutaria
$n = ([regex]::Matches($fuente, '\$script:charlaIdExterno = -1')).Count
Comp 'se limpia en las dos ramas que la miran' ($n -ge 3) "$n sitios la ponen a -1 (1 al declararla + 2 ramas)"

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host ''
Write-Host '  un texto de la pantalla o de un correo no puede convertirse en una orden'
exit 0
