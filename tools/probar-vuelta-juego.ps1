# VOLVER AL JUEGO NO ES ENTRAR EN EL JUEGO (26/09, idea 4 de las 121).
#
# Enter-Juego la llama el bucle en cuanto la ventana del juego vuelve al primer plano, asi que
# un alt-tab de veinte segundos contaba como entrar y Nova soltaba "Modo juego" otra vez.
#
# MEDIDO sobre assistant.log y assistant.log.1: 56 entradas en 14 dias, 45 de ellas vueltas a un
# juego ya visto, y TREINTA de esas 45 en menos de una hora. Los huecos: 24 s, 24 s, 30 s, 41 s,
# 47 s, 52 s, 110 s, 113 s, 121 s, 130 s, 141 s, 221 s, 230 s, 246 s, 262 s, 297 s, 404 s...
# La mitad de los "Modo juego" llegaban a menos de cinco minutos del anterior. Y solo hubo 9
# cierres de verdad en esos catorce dias.
#
# LA SENAL BUENA NO ES EL RELOJ, ES EL PROCESO. Si el PID del juego no ha cambiado, no has
# salido de el por muchas horas que pasen; y si ha cambiado, es una partida nueva aunque hayan
# pasado veinte segundos. El reloj queda de respaldo para cuando no hay PID.
#
# LO QUE NO SE TOCA: el perfil se aplica igual. El brillo hay que ponerlo vuelvas de donde
# vuelvas; lo que sobra es anunciarlo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. la guarda esta donde se habla --'
$dE = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Enter-Juego' }, $true)
Comp 'se encuentra Enter-Juego' ($null -ne $dE) ''
if (-not $dE) { Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
# SIN LOS COMENTARIOS, Y ESTO COSTO DOS ROTURAS QUE NO SE CAZABAN (26/09). Extent.Text trae el
# comentario largo que explica la guarda, y ese comentario nombra 'juegoPid' y 'JuegoVueltaMs':
# buscando sobre el texto crudo, borrar la comprobacion del PID del CODIGO dejaba el banco
# verde, porque el nombre seguia estando... en la explicacion de por que deberia estar.
$cuerpo = (($dE.Extent.Text -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'mira si vuelves al mismo juego' ($cuerpo -match 'vuelveAlMismo') ''
# Y NO BASTA CON CALCULARLO: hay que USARLO para decidir. Quitando el if y dejando el calculo,
# la primera version seguia verde: es "una definicion no es una llamada" con otra ropa.
Comp '  y lo USA para decidir si habla' ($cuerpo -match 'if \(\$vuelveAlMismo\)') 'calcularlo y no mirarlo es peor que nada'
Comp '  llamando a Test-VuelveAlMismoJuego' ($cuerpo -match 'Test-VuelveAlMismoJuego') 'la decision vive en su funcion, y el banco la corre de verdad'
# LO QUE SE CALLA ES LA FRASE, NO EL PERFIL: esta es la comprobacion que impide que alguien
# "arregle" esto saltandose el perfil entero y dejando a braya con el brillo de escritorio.
$iSay = $cuerpo.IndexOf('Say "Modo')
$iPerfil = $cuerpo.IndexOf('Invoke-FastCommand')
Comp '  el perfil se aplica antes de decidir callarse' ($iPerfil -ge 0 -and $iPerfil -lt $iSay) 'el brillo hay que ponerlo igual'
Comp '  y el silencio deja linea en el log' ($cuerpo -match "no digo 'Modo") 'un silencio sin explicacion parece una averia'
# Y QUE EL Say SIGA EXISTIENDO: callarse siempre seria "arreglarlo" rompiendolo.
Comp '  y cuando SI es partida nueva, habla' ($cuerpo -match 'Say "Modo') ''

Write-Host ''
Write-Host '-- 2. la constante, del archivo, y es la de la tarjeta hermana --'
$m = [regex]::Match($txt, '(?m)^\$JuegoVueltaMs\s*=\s*(.+)$')
Comp 'se saca del archivo JuegoVueltaMs' $m.Success ''
if ($m.Success) { Invoke-Expression ('$JuegoVueltaMs = ' + $m.Groups[1].Value.Trim()) }
# LA HERMANA: Show-RecuerdoJuego lleva desde siempre con una hora. Dos guardas que hacen lo
# mismo con dos numeros distintos son dos numeros que mantener, y el dia que alguien toque uno
# el otro se queda atras sin que nadie lo note.
$dR = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Show-RecuerdoJuego' }, $true)
$hermana = 0
if ($dR -and $dR.Extent.Text -match '(\d{6,})') { $hermana = [int]$Matches[1] }
Comp 'es la misma hora que la tarjeta hermana' ($hermana -gt 0 -and $JuegoVueltaMs -eq $hermana) "$JuegoVueltaMs contra $hermana"
Comp '  y es una hora de verdad' ($JuegoVueltaMs -eq 3600000) "$([int]($JuegoVueltaMs/60000)) minutos"

Write-Host ''
Write-Host '-- 3. y decide bien, ejecutando la logica de verdad --'
# LA FUNCION DE VERDAD, SACADA DEL ARCHIVO, no una copia escrita aqui al lado (26/09, lo cazo
# una rotura). La primera version reimplementaba la decision en este banco, asi que borrar la
# comprobacion del PID EN EL CODIGO dejaba el banco verde: estaba probando su propia copia, que
# es la manera 14 de salir verde mintiendo. Ahora se ejecuta la misma funcion que corre Nova.
$dV = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-VuelveAlMismoJuego' }, $true)
Comp 'se saca Test-VuelveAlMismoJuego del arbol' ($null -ne $dV) ''
if (-not $dV) { Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
$script:juegoEntradas = @{}
Invoke-Expression $dV.Extent.Text
function Decide([string]$nombre, [int]$proc, [double]$ahora) { return (Test-VuelveAlMismoJuego $nombre $proc $ahora) }
# La primera vez SIEMPRE habla: no hay nada con lo que comparar.
Comp 'la primera entrada habla' ((Decide 'ELDEN RING' 111 0) -eq $false) ''
# EL CASO REAL: alt-tab de 24 s, mismo proceso -> se calla
Comp 'un alt-tab de 24 s al mismo proceso, se calla' ((Decide 'ELDEN RING' 111 24000) -eq $true) 'el caso medido del log'
# Y OTRO DE TRES HORAS, mismo proceso: sigue siendo el mismo juego abierto
Comp '  y uno de tres horas tambien, si el proceso es el mismo' ((Decide 'ELDEN RING' 111 10824000) -eq $true) 'no has salido del juego'
# PARTIDA NUEVA: el proceso cambio -> habla aunque hayan pasado 20 s
Comp 'si el proceso cambio, habla aunque sean 20 s' ((Decide 'ELDEN RING' 222 10844000) -eq $false) 'es una partida nueva de verdad'
# OTRO JUEGO: nunca se calla
Comp 'otro juego distinto siempre habla' ((Decide 'It Takes Two' 333 10845000) -eq $false) ''
# SIN PID (Nova reinicio y no pudo leerlo): manda el reloj
$script:juegoEntradas = @{}
[void](Decide 'A Way Out' 0 0)
Comp 'sin PID, un alt-tab de 30 s se calla' ((Decide 'A Way Out' 0 30000) -eq $true) 'manda el reloj de respaldo'
$script:juegoEntradas = @{}
[void](Decide 'A Way Out' 0 0)
Comp '  y pasada la hora, habla' ((Decide 'A Way Out' 0 ($JuegoVueltaMs + 1)) -eq $false) 'una hora y un milisegundo'

Write-Host ''
Write-Host '-- 4. contra el registro de verdad --'
# CUANTAS VECES SE HABRIA CALLADO con lo que de verdad paso. Si saliera cero, esto no serviria;
# si se callara en TODAS, es que se ha comido tambien las partidas nuevas.
$logs = @('assistant.log', 'assistant.log.1') | ForEach-Object { Join-Path $raiz $_ } | Where-Object { Test-Path -LiteralPath $_ }
if ($logs.Count -gt 0) {
    $ent = @()
    foreach ($lg in $logs) {
        foreach ($l in @(Get-Content -LiteralPath $lg -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if ($l -match "^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+JUEGO: perfil '\S+' aplicado al entrar en (.+)$") {
                $ent += [pscustomobject]@{ t = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null); j = $Matches[2].Trim() }
            }
        }
    }
    $ent = @($ent | Sort-Object t)
    $ult = @{}
    $callaria = 0
    foreach ($e in $ent) {
        if ($ult.ContainsKey($e.j) -and (($e.t - $ult[$e.j]).TotalMilliseconds -lt $JuegoVueltaMs)) { $callaria++ }
        $ult[$e.j] = $e.t
    }
    Write-Host ("       $($ent.Count) entradas en el registro; se callaria en $callaria")
    Comp 'se calla en unas cuantas' ($callaria -ge 10) 'si fuera cero, esto no serviria'
    Comp '  y no en todas' ($callaria -lt $ent.Count) 'las partidas nuevas siguen hablando'
} else {
    Write-Host '       (no hay registro con el que medir)'
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  volver al juego ya no es entrar en el juego'
exit 0
