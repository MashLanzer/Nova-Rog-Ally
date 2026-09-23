# MIRAR LA PANTALLA DE VERDAD (23/09, funcion 1 de la tanda de funciones nuevas).
#
# Es la queja mas dura de todo el registro de braya. El 20/09, entre las 23:04 y las 00:00:
#   "mirALO tu mismo en la pantalla y dime que ves"
#   "me dijiste cualquier cosa menos lo que viste en la pantalla"
#   "deja de decir que no ves nada en mi pantalla, literalmente tienes un OCR con el que
#    puedes ver mi pantalla"
#   "estas alucinando"
# De sus 40 turnos que hablan de la pantalla, diez cogieron la ruta buena -la de la captura
# adjunta a la API- y ocho cayeron en la charla, que es CIEGA: la palabra "pantalla" no
# aparece ni una vez en charla_worker.py.
#
# Y habia un segundo agujero, este de fondo: el OCR lee LETRAS, y en un juego no hay letras.
# Cuando volvia vacio, Nova decia "no veo texto en la pantalla" con la captura ya hecha en el
# disco y una API al lado que sabe mirar imagenes.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# el patron de ver la pantalla, leido de su linea (nada de copiarlo aqui)
$lineaV = @($fuente -split "`r?`n" | Where-Object { $_ -match 'que es lo que ves' })[0]
$patV = ''
if ($lineaV) {
    $a1 = $lineaV.IndexOf("-match '")
    if ($a1 -ge 0) { $a1 += 8; $a2 = $lineaV.LastIndexOf("')"); if ($a2 -gt $a1) { $patV = $lineaV.Substring($a1, $a2 - $a1) } }
}
# y la guarda de verbos, que es lo que impide que una ORDEN acabe descrita
$lineaG = @($fuente -split "`r?`n" | Where-Object { $_ -match 'abre\|abras\|abrir' -and $_ -match 'notmatch' })[0]
$patG = ''
if ($lineaG) {
    $b1 = $lineaG.IndexOf("-notmatch '")
    if ($b1 -ge 0) { $b1 += 11; $b2 = $lineaG.LastIndexOf("' -and"); if ($b2 -gt $b1) { $patG = $lineaG.Substring($b1, $b2 - $b1) } }
}

Write-Host ''
Write-Host '-- SUS frases del 20/09, las ocho que se perdieron --'
Comp 'el patron se puede leer del fichero' ($patV.Length -gt 0) "$($patV.Length) caracteres"
# tal y como las oyo Nova, en plano (ConvertTo-Plain ya quito tildes y mayusculas)
$suyas = @(
    'miralo tu mismo en la pantalla y dime que ves',
    'deja de decir que no ves nada en mi pantalla literalmente tienes un ocr con el que puedes ver mi pantalla',
    'puedes mirar mi pantalla',
    'dime que ves',
    'mira a ver que hay en mi pantalla',
    'mira mi pantalla',
    'que ves en mi pantalla',
    'describeme la pantalla'
)
$cogidas = 0
foreach ($f in $suyas) {
    $ok = ($f -match $patV)
    if ($ok) { $cogidas++ }
    $corto = if ($f.Length -gt 46) { $f.Substring(0, 43) + '...' } else { $f }
    Write-Host ("       {0} {1}" -f $(if ($ok) { 'SI ' } else { 'no ' }), $corto)
}
Comp 'las coge todas' ($cogidas -eq $suyas.Count) "$cogidas de $($suyas.Count)"

Write-Host ''
Write-Host '-- pero una ORDEN sigue siendo una orden --'
# Esta es la guarda que NO se toca: sin ella, "abre el juego que tengo en pantalla" acababa
# descrito en vez de ejecutado (15/09).
Comp 'la guarda de verbos existe' ($patG.Length -gt 0) "$($patG.Length) caracteres"
foreach ($f in @('abre el juego que tengo en pantalla', 'cierra lo que hay en la pantalla',
                 'pon lo que sale en la pantalla', 'inicia el juego de la pantalla')) {
    Comp ("'" + $f.Substring(0, [Math]::Min(34, $f.Length)) + "' no se describe") ($f -match $patG) 'la frena la guarda de verbos'
}

Write-Host ''
Write-Host '-- y el OCR vacio ya no es "no veo nada" --'
Comp 'con el OCR vacio se manda la imagen' ($fuente -match 'el OCR no encontro texto; mando la imagen a la API') ''
Comp 'y solo se rinde si tampoco hay captura' ($fuente -match "No he podido mirar la pantalla") ''
Comp 'el otro camino (ocrMemoria) tambien' ($fuente -match '(?s)ocrMemoria.{0,900}Mira esta captura de lo que tengo delante') ''
$quedan = ([regex]::Matches($fuente, 'No veo texto en la pantalla')).Count
Comp 'ya no queda ese texto en ningun sitio' ($quedan -eq 0) "$quedan sitio(s)"

Write-Host ''
Write-Host '-- y no es un modo: va turno a turno --'
Comp 'no enciende nada que haya que apagar' (-not ($fuente -match '(?s)VER PANTALLA: captura adjunta.{0,400}\$script:modo')) ''
Comp 'la captura se hace en el momento' ($fuente -match 'Save-Captura \(Join-Path \$TmpDir .pantalla\.png.\)') ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  cuando le pides que mire la pantalla, la mira'
exit 0
