# QUE EL ANIMO TENGA CONSECUENCIAS, NO SOLO COLOR (25/09, idea 50)
#
# LO QUE HAY: Nova calcula un animo de -1 a 1 con los aciertos y errores de hoy y ayer
# ($script:uiAnimo, assistant.ps1). Es un dato REAL, no un adorno... y solo se usa para dos
# cosas, las dos de aspecto: el latido de la capsula se hace mas lento si esta desanimada
# (nova_ui.cs, Desanimado()) y el color se apaga o se aclara. Nada mas.
#
# LO QUE FALTABA: que le cambie el COMPORTAMIENTO. Si Nova lleva un dia malo -o sea, si esta
# entendiendo mal a braya- lo ultimo que debe hacer es hablar mas por su cuenta: interrumpir
# mas cuando estas fallando es la peor combinacion posible. Y al reves, un dia bueno se puede
# permitir alguna iniciativa mas.
#
# ESTO SE APOYA EN UN DATO DURO: el 24/09 Nova hablo 21 veces por su cuenta por UNA que braya
# la llamo. El presupuesto de avisos existe justo para eso, y el animo es la senal que dice si
# hoy conviene gastarlo o no.
#
# LO QUE NO CAMBIA: lo critico (nivel 'alto') pasa siempre, tenga el animo que tenga. Un aviso
# urgente no se calla porque Nova este de mal dia.
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

Write-Host '-- 1. el animo llega a una decision, no solo a un color --'
Comp 'existe Get-SueloPorAnimo' ($sinCom -match 'function Get-SueloPorAnimo') ''
$usos = @([regex]::Matches($sinCom, '(?<!function )Get-SueloPorAnimo')).Count
Comp 'y se usa de verdad' ($usos -ge 1) "$usos uso(s)"
Comp 'el animo sigue viajando a la capsula' ($sinCom -match '"animo":') 'el color y el latido no se tocan'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-SueloPorAnimo' }, $true)
if (-not $d) {
    Comp 'se saca Get-SueloPorAnimo del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
function Log([string]$m) { }
# la constante, del archivo (manera 6)
$m = [regex]::Match($txt, '(?m)^\$AnimoMalo\s*=\s*(.+)$')
Comp 'se saca del archivo el liston del mal dia' $m.Success ''
if ($m.Success) { Invoke-Expression ('$AnimoMalo = ' + $m.Groups[1].Value.Trim()) }
$m2 = [regex]::Match($txt, '(?m)^\$AnimoBueno\s*=\s*(.+)$')
if ($m2.Success) { Invoke-Expression ('$AnimoBueno = ' + $m2.Groups[1].Value.Trim()) }

$base = 4
$script:uiAnimo = 0.0
Comp 'un dia normal no cambia nada' ((Get-SueloPorAnimo $base) -eq $base) "suelo $base"

$script:uiAnimo = -0.6
$malo = Get-SueloPorAnimo $base
Comp 'un dia malo habla menos' ($malo -lt $base) "$malo en vez de $base"
Comp '  pero no se calla del todo' ($malo -ge 1) "$malo"
# Y CON UN SUELO PEQUENO TAMPOCO (25/09, lo cazo una rotura): con suelo 4, dividir por dos o
# por cuatro da 2 o 1, y las dos pasan un "mayor o igual que 1". Con suelo 2 se ve la
# diferencia: la mitad es 1 y la cuarta parte es CERO, o sea callarse del todo.
foreach ($sBajo in @(1, 2, 3)) {
    Comp ("  ni con un suelo de " + $sBajo) ((Get-SueloPorAnimo $sBajo) -ge 1) "$(Get-SueloPorAnimo $sBajo)"
}

$script:uiAnimo = 0.8
$bueno = Get-SueloPorAnimo $base
Comp 'un dia bueno se permite algo mas' ($bueno -ge $base) "$bueno"
Comp '  pero sin desmadrarse' ($bueno -le ($base * 2)) "$bueno, como mucho el doble"

# EL ORDEN: peor animo, menos avisos. Siempre.
$script:uiAnimo = -1.0; $peor = Get-SueloPorAnimo $base
$script:uiAnimo = 1.0;  $mejor = Get-SueloPorAnimo $base
Comp 'y siempre en el mismo sentido' ($peor -le $malo -and $malo -le $base -and $base -le $bueno -and $bueno -le $mejor) "$peor <= $malo <= $base <= $bueno <= $mejor"

Write-Host ''
Write-Host '-- 3. y lo critico pasa igual --'
$dC = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-CabeOtroAviso' }, $true)
if ($dC) {
    Invoke-Expression $dC.Extent.Text
    $script:uiAnimo = -1.0
    Comp 'con el peor animo, lo critico sigue pasando' ((Test-CabeOtroAviso 99 0 1 'alto') -eq $true) 'un aviso urgente no se calla por estar de mal dia'
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el animo cambia lo que hace, no solo como se ve'
exit 0
