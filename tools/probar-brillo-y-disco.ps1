# DOS RASTROS QUE SE PERDIAN (23/09, ideas 2 y 5 de la cuarta tanda).
#
# EL BRILLO (idea 2). $script:juegoBrilloAntes vivia solo en RAM. Si Nova muere con el juego
# delante -y muere mucho: 235 arranques en 14 dias-, la instancia nueva vuelve a aplicar el
# perfil y lee como "brillo de antes" el 100 que dejo puesto la muerta. Medido: 33 perfiles
# aplicados contra 21 restauraciones (12 sin deshacer), y de las 16 restauraciones desde que
# su brillo es 70, las 12 con la cadena limpia devolvieron 70 y las 4 con un reinicio en medio
# devolvieron 100. Cuatro de cuatro.
#
# EL DISCO (idea 5). El 22/09, entre el ultimo aviso (08:33, 11,1 GB) y las 22:50 (0,81 GB),
# el disco se miro unas 831 veces y se escribieron CERO lineas. En 14 dias hay tres cifras de
# disco en todo el log.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- el brillo de antes sobrevive a un reinicio de Nova --'
# EL BLOQUE SE CIERRA DONDE ACABA, NO A LOS 2600 CARACTERES (30/09). Esto cogia 2600 y el codigo
# crecio: 'proc = [int]$script:juegoPid' quedo a +2593 -dentro por SIETE caracteres- y
# 'exe = [string]$script:juegoExe' a +2656, o sea fuera. Dos comprobaciones rojas con el codigo
# intacto y bien puesto. Un numero de caracteres a mano caduca solo; el cierre es el comentario
# que abre lo siguiente, que se mueve con el fuente. Si no aparece, se coge TODO lo que queda:
# quedarse corto es justo el fallo que se esta arreglando.
$iBG = $fuente.IndexOf("`$brilloGuardado = Join-Path `$TmpDir 'juego-brillo.json'")
$blq = ''
if ($iBG -ge 0) {
    $iBGfin = $fuente.IndexOf('# NO se abren apps del perfil al entrar solo en un juego', $iBG)
    $largoBG = if ($iBGfin -gt $iBG) { $iBGfin - $iBG } else { $fuente.Length - $iBG }
    $blq = $fuente.Substring($iBG, $largoBG)
}
Comp 'el respaldo existe y se delimita' ($blq.Length -gt 0) "$($blq.Length) caracteres"
Comp 'se lee del disco antes de preguntarle a WMI' ($blq.IndexOf('Test-Path -LiteralPath $brilloGuardado') -lt $blq.IndexOf('WmiMonitorBrightness')) ''
Comp 'y solo si el MISMO juego sigue vivo' ($blq -match 'Test-JuegoVivo \$gB') 'PID y ruta, no solo el fichero'
Comp 'y no pasa de doce horas' ($blq -match 'TotalHours -lt 12') 'el caso del 20/09: otro juego seis horas despues'
Comp 'si no vale, se borra y se pregunta a WMI' (($blq -match 'Remove-Item -LiteralPath \$brilloGuardado') -and ($blq -match 'WmiMonitorBrightness'))
Comp 'se guarda el PID y la ruta del juego' (($blq -match 'proc = \[int\]\$script:juegoPid') -and ($blq -match 'exe = \[string\]\$script:juegoExe'))
# Y LOS DOS TIENEN QUE ESTAR, no solo ir en orden: con un IndexOf a -1 el '-gt' decide solo, y
# aqui el lado malo es que falte el 'if' -entonces -1 queda a la derecha y el verde no significa
# que el guardado este dentro de nada-.
$iEscribe = $blq.IndexOf('WriteAllText($brilloGuardado')
$iUnaVez  = $blq.IndexOf('if ($null -eq $script:juegoBrilloAntes)')
Comp 'y una sola vez por partida, no en cada alt-tab' (($iEscribe -ge 0) -and ($iUnaVez -ge 0) -and ($iEscribe -gt $iUnaVez)) "escribe=$iEscribe if=$iUnaVez"
Comp 'al restaurar, el respaldo se borra' ($fuente -match "(?s)brillo restaurado a.{0,260}Remove-Item -LiteralPath \(Join-Path \`$TmpDir 'juego-brillo\.json'\)") 'no debe sobrevivir a la partida'

Write-Host ''
Write-Host '-- una linea por giga perdido, y ni una mas --'
# el bloque MIO, que acaba donde empieza lo que ya habia (Invoke-Reglas 'disco'): con una
# ventana de N caracteres se colaba esa linea y la comprobacion de "no ejecuta nada" salia
# roja por codigo que no es de esta idea.
$iD = $fuente.IndexOf('$suelo = [int][Math]::Floor($gbLibres)')
$fD = $fuente.IndexOf("Invoke-Reglas 'disco'", $iD)
$dsc = if ($iD -ge 0 -and $fD -gt $iD) { $fuente.Substring($iD, $fD - $iD) } else { '' }
Comp 'el rastro del disco existe' ($dsc.Length -gt 0) "$($dsc.Length) caracteres"
Comp 'escribe la cifra de verdad' ($dsc -match 'Log "DISCO: \$gbLibres GB libres"') ''
Comp 'solo cuando BAJA de giga' ($dsc -match '\$suelo -lt \[int\]\$script:discoUltimoGb') 'o un juego descargando escribiria cada minuto'
Comp 'y la primera de cada arranque se apunta' ($dsc -match '\$null -eq \$script:discoUltimoGb') 'sirve de marca'
Comp 'si sube, se reengancha sin escribir' ($dsc -match '(?s)\$suelo -gt \[int\]\$script:discoUltimoGb.{0,120}discoUltimoGb = \$suelo')
Comp 'no habla, no ejecuta, no toca los avisos' (-not ($dsc -match 'Say|Send-AvisoEntorno|Show-Popup|Invoke-')) 'es un Log y nada mas'
Comp 'la variable arranca vacia' ($fuente -match '\$script:discoUltimoGb = \$null')

Write-Host ''
Write-Host '-- y el aviso de disco sigue donde estaba --'
Comp "el critico sigue en 'alto'" ($fuente -match "Send-AvisoEntorno 'disco-critico'.{0,200}'alto'") ''
Comp "y el suave en 'medio'" ($fuente -match "Send-AvisoEntorno 'disco-poco'.{0,200}'medio'")
# ANCLADO A LA LLAMADA, NO A LA CADENA SUELTA: la clave 'disco-critico' aparece tambien donde se
# recomprueba el hecho de un aviso aparcado (idea 119), que esta mucho antes en el fichero, y
# entonces este IndexOf miraba ese y el caso salia rojo sin que nada estuviera mal.
Comp 'el rastro va ANTES de los dos avisos' ($fuente.IndexOf('Log "DISCO: $gbLibres GB libres"') -lt $fuente.IndexOf("Send-AvisoEntorno 'disco-critico'")) 'para que quede escrito salga el aviso o no'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  el brillo vuelve a ser el tuyo, y el disco deja rastro'
exit 0
