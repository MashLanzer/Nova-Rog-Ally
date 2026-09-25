# LAS DOS FRASES QUE SI SE REPITEN (25/09)
#
# LO MEDIDO, y es MUCHO menos de lo que parecia. Contando lo que Nova dijo de verdad -1.842
# frases del registro, 538 distintas- las cuatro mas repetidas resultaron ser de UN SOLO DIA:
# el bucle de "Mientras no estabas" del 21/09, 774 veces. Tanda de pruebas, no uso.
#
# Repetirse de verdad, en varios dias, solo se repiten DOS:
#   - "Hay un ruido de fondo constante..."      33 veces en 4 dias
#   - "Ya esta cargada del todo..."             20 veces en 8 dias
# Y son justo las dos que mas cansan, porque salen cuando braya no ha pedido nada.
#
# LO QUE **NO** SE HACE: construir un sistema de variedad. El motor existe desde el 18/09 en
# Get-FraseVuelta -candidatas, filtrar las ultimas, Get-Random-. Lo unico que faltaba era
# sacarlo a una funcion y darle una bolsa a esas dos frases.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. existe, y la usan LAS DOS frases medidas --'
Comp 'existe Get-FraseVariada' ($sinCom -match 'function Get-FraseVariada') ''
$usos = @([regex]::Matches($sinCom, "(?<!function )Get-FraseVariada")).Count
Comp 'y se usa dos veces' ($usos -ge 2) "$usos uso(s)"
Comp "la del ruido de fondo" ($sinCom -match "Get-FraseVariada 'oido-ruido'") '33 veces en 4 dias'
Comp "la de la bateria llena" ($sinCom -match "Get-FraseVariada 'bateria-llena'") '20 veces en 8 dias'
# LO QUE RECUERDA VIVE EN habitos.json, y tiene que hacer el viaje entero: si falta una de las
# tres patas -crear, cargar, guardar- la memoria se pierde en cada reinicio y volvemos a
# repetir. Es lo que le pasaba al humor antes de hoy.
Comp 'la memoria se crea' ($sinCom -match 'variedad = @\{\}') ''
Comp '  se carga del disco' ($sinCom -match '\$crudoH\.variedad') ''
Comp '  y se guarda' ($sinCom -match 'variedad = \$hb\.variedad') ''

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-FraseVariada' }, $true)
if (-not $d) { Comp 'se saca Get-FraseVariada del arbol' $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
Invoke-Expression $d.Extent.Text
# el liston, del archivo (manera 6)
$mR = [regex]::Match($txt, '(?m)^\$VariedadRecuerda\s*=\s*(\d+)')
Comp 'se saca del archivo VariedadRecuerda' $mR.Success ''
$VariedadRecuerda = if ($mR.Success) { [int]$mR.Groups[1].Value } else { 2 }
# los dobles, DESPUES de cargar (manera 9)
$script:hb = @{ variedad = @{} }
$script:guardados = 0
$script:quejas = 0
function Get-Habitos { return $script:hb }
function Save-Habitos { $script:guardados++ }
function Log([string]$m) { if ($m -match 'variedad: no pude') { $script:quejas++ } }

$bolsa = @('una', 'dos', 'tres', 'cuatro')

# NUNCA SE QUEDA MUDA: eso es lo primero, porque callar es peor que repetirse
$salidas = @()
foreach ($i in 1..40) { $salidas += (Get-FraseVariada 'prueba' $bolsa) }
Comp 'siempre devuelve algo' ((@($salidas | Where-Object { $_ }).Count) -eq 40) ''
Comp '  y siempre de la bolsa' ((@($salidas | Where-Object { $bolsa -notcontains $_ }).Count) -eq 0) 'no se inventa frases'
Comp '  sin quejarse' ($script:quejas -eq 0) ''

# NO REPITE LAS DOS ULTIMAS: esto es lo que arregla
$malas = 0
for ($i = 2; $i -lt $salidas.Count; $i++) {
    if ($salidas[$i] -eq $salidas[$i - 1] -or $salidas[$i] -eq $salidas[$i - 2]) { $malas++ }
}
Comp "no repite ninguna de las $VariedadRecuerda ultimas" ($malas -eq 0) "$malas repeticion(es) en 40 tiradas"

# Y USA LA BOLSA ENTERA: si se quedara en dos frases, no habriamos arreglado nada
$distintas = @($salidas | Select-Object -Unique).Count
Comp 'usa las cuatro candidatas' ($distintas -eq 4) "$distintas de 4 en 40 tiradas"

# CADA CLAVE LLEVA SU PROPIA CUENTA: si compartieran memoria, la del ruido se comeria los
# turnos de la de la bateria y saldria un patron raro en las dos.
$script:hb = @{ variedad = @{} }
[void](Get-FraseVariada 'clave-a' @('sola'))
[void](Get-FraseVariada 'clave-b' $bolsa)
Comp 'cada aviso lleva su propia memoria' ($script:hb.variedad.Keys.Count -ge 1) "$($script:hb.variedad.Keys -join ', ')"

# Y QUE LO GUARDE DE VERDAD (25/09, lo cazo una rotura). Abajo se comprueba que NO toca el
# disco cuando no hay nada que elegir, pero nadie comprobaba que SI lo toque cuando si lo hay:
# quitando el Save-Habitos, la memoria vivia solo en RAM -se perdia en cada reinicio y Nova
# volvia a repetirse- y el banco salia verde entero. Es lo mismo que le pasaba al humor.
$script:hb = @{ variedad = @{} }
$script:guardados = 0
[void](Get-FraseVariada 'guarda' $bolsa)
Comp 'y lo que elige lo guarda en disco' ($script:guardados -ge 1) 'si no, cada reinicio empieza de cero'

Write-Host ''
Write-Host '-- 3. los casos raros --'
$script:hb = @{ variedad = @{} }
Comp 'con la bolsa vacia devuelve vacio' ((Get-FraseVariada 'x' @()) -eq '') 'sin reventar'
Comp 'con $null tampoco revienta' ((Get-FraseVariada 'x' $null) -eq '') ''
$script:guardados = 0
Comp 'con UNA sola candidata la devuelve' ((Get-FraseVariada 'x' @('unica')) -eq 'unica') ''
Comp '  y no toca el disco por gusto' ($script:guardados -eq 0) 'sin nada que elegir no hay nada que recordar'

# LA MEMORIA NO CRECE SIN FIN: guarda solo las ultimas, no un historial
$script:hb = @{ variedad = @{} }
foreach ($i in 1..30) { [void](Get-FraseVariada 'tope' $bolsa) }
Comp 'la memoria no crece' ((@($script:hb.variedad['tope']).Count) -le $VariedadRecuerda) "$(@($script:hb.variedad['tope']).Count) guardadas tras 30 tiradas"

# CON MAS CANDIDATAS QUE MEMORIA TAMPOCO SE ATASCA
$script:hb = @{ variedad = @{} }
$dos = @('a', 'b')
$s2 = @()
foreach ($i in 1..10) { $s2 += (Get-FraseVariada 'dos' $dos) }
Comp 'con solo dos candidatas sigue diciendo algo' ((@($s2 | Where-Object { $_ }).Count) -eq 10) 'antes repetir que callar'

# EL CASO QUE SOLO PROTEGE ESA GUARDA (25/09, lo cazo una rotura). Con cuatro candidatas y
# memoria de dos siempre quedan dos libres, asi que borrar el "antes repetir que callar"
# dejaba el banco VERDE: ninguna prueba llegaba a quedarse sin libres. Hace falta que la
# memoria SE COMA la bolsa entera, y eso solo pasa con tantas candidatas como recuerdo.
$script:hb = @{ variedad = @{ 'lleno' = @('a', 'b') } }
$script:quejas = 0
$saleL = Get-FraseVariada 'lleno' @('a', 'b')
Comp 'con la memoria llena sigue diciendo algo' (-not [string]::IsNullOrEmpty($saleL)) "dijo '$saleL'; callar seria peor que repetir"
# Y SALE POR LA GUARDA, NO POR EL CATCH: sin el "antes repetir que callar", Get-Random se
# queda sin lista, LANZA, y el catch devuelve la primera candidata -o sea, la funcion sigue
# diciendo algo y por fuera parece que todo va bien-. La diferencia es que el catch deja
# queja en el log y la guarda no. Sin esta comprobacion, la rotura pasaba desapercibida.
Comp '  y por el camino bueno, sin quejarse' ($script:quejas -eq 0) 'quedarse sin lista no es una averia prevista'

# Y SI DE VERDAD ALGO FALLA, NI SE CALLA NI SE CALLA LA BOCA: dice algo Y lo cuenta.
$script:hb = $null          # Get-Habitos devolvera $null y reventara dentro del try
$script:quejas = 0
$saleF = Get-FraseVariada 'falla' $bolsa
Comp 'si algo revienta dentro, sigue diciendo algo' (-not [string]::IsNullOrEmpty($saleF)) "dijo '$saleF'"
Comp '  y lo deja escrito' ($script:quejas -eq 1) 'un fallo mudo aqui pareceria que Nova esta tranquila'
$script:hb = @{ variedad = @{} }

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  las frases que se repetian ya no se repiten'
exit 0
