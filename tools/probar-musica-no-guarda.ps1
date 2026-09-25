# UN VETO DE MUSICA PARA SIEMPRE, DE UNA FRASE MAL OIDA (25/09)
#
# LO QUE HABIA EN DISCO. memoria\musica-no.json ha tenido UNA sola entrada en toda su vida, y
# era basura: {"q": "si es resting"}, del 25/09 a la 01:25:40. Salio de un "No, no quiero,
# Cierre Sting, Paul" que Parakeet oyo mal -braya estaba pidiendo cerrar Steam- y que canary
# "mejoro" a "no quiero, si es resting por favor". Nova contesto "no te pongo mas resting" y
# lo guardo para siempre. Sin preguntar, y sin que braya tuviera manera de enterarse.
#
# LOS DOS AGUJEROS, que son los que vigila este banco:
#   1. EL PATRON. De las cuatro maneras de vetar, tres hablan de gustar ("no me gusta",
#      "odio") o de poner ("no me pongas"), y la cuarta era "no quiero", que es una negativa
#      de CUALQUIER cosa y detras de ella cabe la frase entera. Contado sobre los 633 dictados
#      distintos de assistant.log y su rotado: "no quiero" casa con UNA frase en catorce dias,
#      y tampoco es musica -"no quiero saber que se esta descagando en steam"-. Cero vetos
#      buenos y dos malos, asi que fuera.
#   2. LA GUARDA QUE NO ESTABA. El camino de las traducciones no aprende de un oido que dudaba
#      desde el 15/09 ("NO APRENDER DE LO MAL OIDO"); este escribia igual.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- 1. EL PATRON: que "no quiero" ya no vete nada --'
# El patron sale del archivo, no de una copia: un banco con su propia copia prueba su numero.
$mPat = [regex]::Match($fuente, "(?m)^\s*if \(\`$f -match '(\^\(\?:no\\\\s\+me\\\\s\+gusta.{0,200}?)'\) \{")
if (-not $mPat.Success) {
    $mPat = [regex]::Match($fuente, "(?m)^\s*if \(\`$f -match '(\^\(\?:no[^']*gusta[^']*\(\.\{3,40\}\)\`$)'\) \{")
}
if (-not $mPat.Success) { Write-Host '  MAL  no encuentro el patron de vetar nombrando'; exit 1 }
$patVeto = $mPat.Groups[1].Value
Write-Host ("       patron: " + $patVeto)
Comp 'la frase que lo destapo ya no vale para vetar' `
    ('no quiero saber que se esta descagando en steam' -notmatch $patVeto) `
    'no quiero saber que se esta descagando en steam'
Comp 'ni la que dejo basura en el fichero' ('no quiero si es resting' -notmatch $patVeto)
Comp 'pero "no me gusta X" sigue vetando' ('no me gusta el reggaeton' -match $patVeto) 'no me gusta el reggaeton'
Comp 'y "no me pongas X" tambien' ('no me pongas musica triste' -match $patVeto)
Comp 'y "odio X" tambien' ('odio el trap' -match $patVeto)

Write-Host ''
Write-Host '-- 2. LA GUARDA: de un oido que dudaba no se guarda nada --'
# LA RAMA DE VERDAD, sacada del archivo y ejecutada. Se mete dentro de un switch porque el
# codigo lleva un 'break' y un break suelto en una funcion se sale del script entero.
$iniR = $fuente.IndexOf("'musicaNo' {")
$finR = if ($iniR -ge 0) { $fuente.IndexOf("'musicaSi' {", $iniR) } else { -1 }
if ($iniR -lt 0 -or $finR -lt 0) { Write-Host '  MAL  no encuentro la rama musicaNo'; exit 1 }
$rama = $fuente.Substring($iniR, $finR - $iniR).TrimEnd() -replace '\s+$', ''

$script:guardado = @()
$script:dudosas = @{}
function Test-OidoDudoso([string]$t) { return $script:dudosas.ContainsKey($t) }
function Add-MusicaNo([string]$q, [string]$t, [string]$id) { $script:guardado += $q; return '' }
function Get-MusicaNoClaves([string]$q) { return @('reggaeton') }
function Log([string]$m) { }
$MusicaNoMax = 20
$script:ytPuesto = $null
Invoke-Expression ("function Probar-Veto([string]`$text, `$a) {`n  switch ('musicaNo') {`n" + $rama + "`n  }`n  return `$a`n}")

$script:dudosas = @{ 'no quiero si es resting' = $true }
$script:guardado = @()
$aM = @{ kind = 'musicaNo'; que = 'si es resting'; desc = '' }
$rM = Probar-Veto 'no quiero si es resting' $aM
Comp 'con el oido dudando NO se guarda nada' ($script:guardado.Count -eq 0) "guardados: $($script:guardado.Count)"
Comp 'y lo dice en vez de callarselo' ($rM.desc -match 'no te he entendido bien') "dice: $($rM.desc)"

$script:dudosas = @{}
$script:guardado = @()
$aB = @{ kind = 'musicaNo'; que = 'reggaeton'; desc = '' }
$rB = Probar-Veto 'no me gusta el reggaeton' $aB
Comp 'y con el oido limpio SI se guarda' ($script:guardado -contains 'reggaeton') "guardados: $($script:guardado -join ', ')"
Comp 'y lo repite en voz alta' ($rB.desc -match 'reggaeton') "dice: $($rB.desc)"

Write-Host ''
Write-Host '-- 3. QUE LA GUARDA VAYA ANTES DE ESCRIBIR, NO DESPUES --'
# El orden es lo unico que importa aqui: una guarda detras del Add-MusicaNo no guarda nada.
$posG = $rama.IndexOf('Test-OidoDudoso')
$posA = $rama.IndexOf('Add-MusicaNo')
Comp 'la guarda esta en la rama' ($posG -ge 0)
Comp 'y va ANTES de guardar' ($posG -ge 0 -and $posA -ge 0 -and $posG -lt $posA) "guarda en $posG, guardar en $posA"

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'un oido que duda ya no deja un veto de musica para siempre'
exit 0
