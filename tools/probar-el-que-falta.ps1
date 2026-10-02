# "EL QUE, DESPUES DE PON": PEDIR SOLO LA PARTE QUE FALTA (2/10/2026, idea 22 de las 40)
#
# EL AGUJERO: cuando Nova no entendia decia "No te entendi" y braya repetia LA FRASE ENTERA. Pero
# muchas veces el verbo esta clarisimo -va al principio y sale de una lista cerrada de noventa, que es
# la parte que mejor se oye- y lo que falla es el objeto: "pon" mas un ruido. Pedir la frase entera es
# pedir trabajo de mas y, peor, tirar la parte que SI se oyo.
#
# POR QUE ESTO ACERCA EL 100 % Y CAMBIAR DE MODELO NO: cambiar de modelo se midio el 21/09 y NO mejora
# la comprension (esta en voice-ctrl-oido-medido). Esto no intenta oir mejor: aprovecha lo oido.
#
# LOS TRES SITIOS: la frase "No te entendi" estaba escrita tres veces en assistant.ps1, y los tres
# tiraban igual lo que se habia oido. Los tres pasan ahora por la misma funcion.
#
# LO QUE SE DEFIENDE, y la mitad son los casos en que NO debe hablar asi:
#  1. con verbo claro y objeto corto, pregunta por el objeto;
#  2. SIN verbo, la frase de siempre -inventarse un "pon que?" seria poner palabras en su boca-;
#  3. con el verbo pero SIN nada detras, la de siempre: no es que no se entendiera, es que no lo dijo;
#  4. con cinco palabras detras, la de siempre: ahi lo que falla no es una palabra suelta;
#  5. y un verbo en medio de la frase no cuenta, solo al principio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`r?`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LA LISTA DE VERBOS SE SACA DEL FICHERO, no se copia: si manana se le anade un verbo, este banco lo
# prueba solo en vez de mirar una copia vieja.
$iV = $txt.IndexOf('$VERBOS = ')
$finV = $txt.IndexOf("`n", $iV)
Invoke-Expression $txt.Substring($iV, $finV - $iV)
Invoke-Expression (Traer 'ConvertTo-Suave')
Invoke-Expression (Traer 'Get-FraseNoEntendi')

Write-Host ''
Write-Host '-- 1. con verbo claro y objeto corto: pregunta por el objeto --'
$r = Get-FraseNoEntendi 'pon chchch'
Comp 'lo dice corto en voz' ($r.decir -eq 'pon, que?') "$($r.decir)"
Comp '  y en la capsula, con lo que oyo' ($r.ver -match 'pon' -and $r.ver -match 'chchch') "$($r.ver)"
$r2 = Get-FraseNoEntendi 'abre rrrr'
Comp 'con otro verbo, el mismo trato' ($r2.decir -eq 'abre, que?') "$($r2.decir)"
$r3 = Get-FraseNoEntendi 'baja el brrrr'
Comp 'con dos palabras detras tambien' ($r3.decir -eq 'baja, que?') "$($r3.decir)"

Write-Host ''
Write-Host '-- 2. SIN verbo: la frase de siempre --'
foreach ($t in @('chchch', 'mmmm aaaa', 'no se que es esto', 'hola')) {
    $x = Get-FraseNoEntendi $t
    Comp ("  '" + $t + "' -> la de siempre") ($x.decir -eq 'No te entendi') "$($x.decir)"
}

Write-Host ''
Write-Host '-- 3. verbo SIN nada detras: la de siempre --'
# Eso no es "no te entendi el objeto": es que no lo dijo, y ya tiene su propio camino.
foreach ($t in @('pon', 'abre', 'baja  ')) {
    $x = Get-FraseNoEntendi $t
    Comp ("  '" + $t.Trim() + "' -> la de siempre") ($x.decir -eq 'No te entendi') "$($x.decir)"
}

Write-Host ''
Write-Host '-- 4. con una cola larga: la de siempre --'
$x4 = Get-FraseNoEntendi 'pon una cosa que no se entiende nada de nada'
Comp 'con cinco palabras detras no pregunta por el objeto' ($x4.decir -eq 'No te entendi') "$($x4.decir)"
# el borde: cuatro si, cinco no
$x4b = Get-FraseNoEntendi 'pon una dos tres cuatro'
Comp '  con cuatro, todavia pregunta' ($x4b.decir -eq 'pon, que?') "$($x4b.decir)"

Write-Host ''
Write-Host '-- 5. un verbo en MEDIO no cuenta --'
$x5 = Get-FraseNoEntendi 'rrrr pon rrrr'
Comp 'solo vale el verbo al principio' ($x5.decir -eq 'No te entendi') "$($x5.decir)"

Write-Host ''
Write-Host '-- 6. nada de entradas raras rompe esto --'
foreach ($t in @('', '   ', 'PON ALGO RARO')) {
    $x = Get-FraseNoEntendi $t
    Comp ("  con '" + $t + "' devuelve algo" ) ([bool]$x.decir -and [bool]$x.ver) "$($x.decir)"
}

Write-Host ''
Write-Host '-- 7. el cableado: los OCHO sitios pasan por aqui --'
$nViejas = ([regex]::Matches($sinCom, 'Say "No te entendi"')).Count
Comp 'ya no queda ningun "No te entendi" suelto' ($nViejas -eq 0) "$nViejas sitios"
# OCHO SITIOS, NO TRES: al correr esto por primera vez salieron CINCO MAS que no habia visto, con el
# texto en $text en vez de en $orig. Los ocho tiraban igual la parte que si se oyo. Si manana aparece
# un noveno, este banco lo canta.
$nNuevas = ([regex]::Matches($sinCom, 'Get-FraseNoEntendi \$(?:orig|text)')).Count
Comp '  y los OCHO llaman a la funcion' ($nNuevas -eq 8) "$nNuevas sitios"
# Y LAS DOS FRASES VAN A SU CANAL: la larga a la capsula, la corta a la voz
$iVer = $sinCom.IndexOf('Show-Popup $fraseNE.ver')
$iDec = $sinCom.IndexOf('Say $fraseNE.decir', [Math]::Max(0, $iVer))
Comp '  la larga se VE y la corta se DICE' ($iVer -ge 0 -and $iDec -gt $iVer) 'la voz suena encima del juego'
# LA LISTA DE VERBOS NO SE DUPLICA
$cuerpo = Traer 'Get-FraseNoEntendi'
Comp 'usa la lista de verbos del fichero' ($cuerpo -match '\$VERBOS') 'sin copiarla'
Comp '  y no se inventa una lista propia' ($cuerpo -notmatch "'abre\|") ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'cuando el verbo se oye, Nova pregunta solo por lo que falta' -ForegroundColor Green
exit 0
