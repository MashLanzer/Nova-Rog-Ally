# "POR QUE HAS HECHO ESO?" Y QUE PASO MIENTRAS NO ESTABAS (2/10/2026, ideas 21 y 40 de las 40)
#
# EL AGUJERO, medido antes de escribir nada: `grep -ci "por que has" assistant.ps1` daba CERO. Nova
# decide sola todo el dia -baja el volumen por el ruido, aparca un aviso porque no hay nadie, cambia
# de motor de oido, apaga una sonda que tarda cinco segundos, frena el repaso fino- y no podia
# explicar NI UNA. Para braya eso es una maquina que hace cosas raras; con la explicacion es una
# maquina de la que se puede fiar, y es la diferencia mas grande por el menor trabajo de las 40.
#
# Y ES BARATO PORQUE EL MOTIVO YA ESTABA ESCRITO: hay QUINCE sitios que hacen
# Add-Estadistica 'auto-ajuste' con el que y los numeros. Lo unico que faltaba era un cuaderno donde
# queden las ultimas y una frase que las lea. El enganche va pegado a ese Add-Estadistica a proposito:
# asi no se estrena ningun reloj, y si manana se anade una decision nueva se ve a simple vista que le
# falta la linea de al lado.
#
# LA 40 junta tres cosas que ya se guardaban y solo vivian en el registro: los avisos aparcados por no
# haber nadie, el pete vivo y el cuaderno de arriba. El dato que la justifica: el arranque del 1/10
# decia "no hay nadie desde hace 954 min" -dieciseis horas- y braya no se enteraba de nada de eso.
#
# LO QUE SE DEFIENDE:
#  1. que el cuaderno no crezca sin fin y que viva en RAM (es de esta sesion, no de anteayer);
#  2. que la frase diga CUANDO y POR QUE, no solo que paso;
#  3. que preguntando otra vez se cuente la decision ANTERIOR, no la misma;
#  4. que sin decisiones no se invente nada;
#  5. que el resumen de la vuelta se calle con una ausencia corta, y se calle del todo si no hay nada
#     que contar -decir "no ha pasado nada" es peor que callar-;
#  6. y que no suelte mas de dos cosas: un resumen de ocho puntos es una conferencia.
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

$PorQueMax = 12
$MientrasMin = 120
$script:porQue = New-Object System.Collections.ArrayList
foreach ($n in @('Add-PorQue', 'Get-FrasePorQue', 'Get-FraseMientrasNoEstabas')) { Invoke-Expression (Traer $n) }

Write-Host ''
Write-Host '-- 1. sin decisiones, no se inventa nada --'
$f = Get-FrasePorQue
Comp 'lo dice claro' ($f -match 'no he decidido nada por mi cuenta') "$f"

Write-Host ''
Write-Host '-- 2. una decision: el que, el cuando y el por que --'
Add-PorQue 'nube off: 0 de 126' 'cero aciertos en 126 intentos desde el 20/09'
$f2 = Get-FrasePorQue
Comp 'dice lo que hizo' ($f2 -match 'nube off') "$f2"
Comp '  y cuando' ($f2 -match 'ahora mismo|hace \d+ minuto') ''
Comp '  y el motivo' ($f2 -match 'cero aciertos en 126') ''

Write-Host ''
Write-Host '-- 3. preguntando otra vez, la ANTERIOR --'
$script:porQue.Clear()
Add-PorQue 'primera: confianza minima 0.30 -> 0.45' ''
Add-PorQue 'segunda: oido fino off' ''
$a = Get-FrasePorQue
Comp 'la primera vez, la ultima' ($a -match 'segunda') "$($a.Substring(0,[Math]::Min(70,$a.Length)))"
Comp '  y dice cuantas lleva' ($a -match 'Llevo 2 decisiones') ''
$b = Get-FrasePorQue
Comp 'la segunda vez, la de antes' ($b -match 'primera') "$($b.Substring(0,[Math]::Min(70,$b.Length)))"
# Y NO SE QUEDA SIN FONDO: al acabarse vuelve a la frase de "no he decidido nada"
$c = Get-FrasePorQue
Comp '  y al acabarse no revienta' ([bool]$c) "$($c.Substring(0,[Math]::Min(50,$c.Length)))"

Write-Host ''
Write-Host '-- 4. el cuaderno no crece sin fin --'
$script:porQue.Clear()
1..30 | ForEach-Object { Add-PorQue "decision $_" '' }
Comp "se queda en $PorQueMax" ($script:porQue.Count -eq $PorQueMax) "$($script:porQue.Count)"
Comp '  y guarda las ULTIMAS, no las primeras' ($script:porQue[$script:porQue.Count - 1].que -eq 'decision 30') "$($script:porQue[$script:porQue.Count-1].que)"
# UNA DECISION VACIA NO ENTRA: si no, un llamador despistado llenaria el cuaderno de nada
$antes = $script:porQue.Count
Add-PorQue '' 'motivo sin que'
Comp '  y una vacia no entra' ($script:porQue.Count -eq $antes) ''

Write-Host ''
Write-Host '-- 5. el resumen de la vuelta (idea 40) --'
$script:porQue.Clear()
$script:esperando = @()
function Get-AvisoEspera { return $script:esperando }
function Get-PeorPete { return $script:peteVivo }
$script:peteVivo = $null
# AUSENCIA CORTA: ni una palabra
$script:esperando = @(1, 2, 3)
Comp 'con 30 min fuera, no dice nada' ((Get-FraseMientrasNoEstabas 30) -eq '') "el liston son $MientrasMin min"
# AUSENCIA LARGA Y CON AVISOS: habla
$r = Get-FraseMientrasNoEstabas 954
Comp 'con 954 min y tres avisos, habla' ([bool]$r) "$r"
Comp '  dice cuantos avisos' ($r -match 'te he guardado 3 avisos') ''
Comp '  y cuantas horas' ($r -match 'en estas 16 horas') ''
Comp '  y como pedir el detalle' ($r -match 'por que has hecho eso') 'enlaza con la idea 21'
# UNO SOLO SE DICE EN SINGULAR
$script:esperando = @(1)
Comp 'un aviso, en singular' ((Get-FraseMientrasNoEstabas 300) -match 'te he guardado un aviso') ''
# SIN NADA QUE CONTAR, CALLADO DEL TODO
$script:esperando = @()
Comp 'sin nada que contar, ni una palabra' ((Get-FraseMientrasNoEstabas 954) -eq '') 'decir "no ha pasado nada" es peor'
# COMO MUCHO DOS COSAS
$script:esperando = @(1, 2)
Add-PorQue 'apague el acelerometro' ''
$script:peteVivo = @{ veces = 9; linea = 100; que = 'algo' }
$r2 = Get-FraseMientrasNoEstabas 954
Comp 'con tres cosas, solo suelta dos' (@($r2 -split ' y ').Count -le 2) "$r2"
Comp '  y las dos primeras son las utiles' ($r2 -match 'avisos' -and $r2 -match 'por mi cuenta') ''
# UN PETE DE POCA MONTA NO ENTRA
$script:esperando = @(); $script:porQue.Clear()
$script:peteVivo = @{ veces = 2; linea = 100; que = 'algo' }
Comp 'un pete de dos veces no es noticia' ((Get-FraseMientrasNoEstabas 954) -eq '') ''

Write-Host ''
Write-Host '-- 6. el cableado --'
Comp 'hay patron para preguntarlo' ($sinCom -match "kind = 'porQue'") ''
$iE = $sinCom.IndexOf("'porQue' {")
$iF = $sinCom.IndexOf('Get-FrasePorQue', [Math]::Max(0, $iE))
Comp '  y su ejecutor llama a la frase' ($iE -ge 0 -and $iF -gt $iE) ''
# LAS QUINCE DECISIONES: cada Add-Estadistica 'auto-ajuste' tiene su Add-PorQue al lado
$nAuto = ([regex]::Matches($sinCom, "Add-Estadistica 'auto-ajuste'")).Count
$nPorQ = ([regex]::Matches($sinCom, 'Add-PorQue ')).Count
Comp 'cada decision propia se apunta' ($nPorQ -ge $nAuto) "$nAuto auto-ajustes, $nPorQ apuntes"
Comp '  y protegido, que apuntar no puede romper la decision' ($sinCom -match 'try \{ Add-PorQue [^\r\n]+\} catch \{\}') 'regla 7'
# EL CUADERNO VIVE EN RAM: nada de disco (regla 4)
$cuerpoA = Traer 'Add-PorQue'
Comp 'el cuaderno no toca disco' ($cuerpoA -notmatch 'Write-Atomico|WriteAllText|Set-Content') 'es de esta sesion, no de anteayer'
# Y LA DEFINICION, ANTES DE TODOS SUS USOS (la leccion de la idea 1 de hoy)
$iDef = ($txt -split "`r?`n" | Select-String '^function Add-PorQue').LineNumber
$usos = @($txt -split "`r?`n" | Select-String 'Add-PorQue ' | Where-Object { $_.Line -notmatch '^\s*#' -and $_.Line -notmatch '^function' }).LineNumber
Comp 'se define ANTES de todos sus usos' ($iDef -gt 0 -and ($usos | Measure-Object -Minimum).Minimum -gt $iDef) "definida en $iDef, primer uso en $(($usos | Measure-Object -Minimum).Minimum)"
# LA 40 VA PEGADA AL SALUDO QUE YA EXISTE, no a un reloj nuevo
$iFr = $sinCom.IndexOf('$frase = Get-FraseVuelta')
$iMn = $sinCom.IndexOf('Get-FraseMientrasNoEstabas', [Math]::Max(0, $iFr))
Comp 'el resumen va pegado al saludo de vuelta' ($iFr -ge 0 -and $iMn -gt $iFr) 'ningun reloj nuevo'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova explica lo que decide sola, y cuenta lo que paso mientras no estabas' -ForegroundColor Green
exit 0
