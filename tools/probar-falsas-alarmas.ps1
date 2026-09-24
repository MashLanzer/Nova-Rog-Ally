# LAS FALSAS ALARMAS, CONTADAS SIN MENTIR (20/09).
#
# La tabla de memoria\estadisticas.md llego a decir 489 %: dividia el ruido de todo el dia
# entre las activaciones por nombre, que son dos poblaciones distintas. Un porcentaje
# imposible no engana a nadie, pero un 90 % tambien estaria mal y ese si se cree. Aqui se
# le dan a Get-FalsasAlarmas grabaciones DE MENTIRA en $env:TEMP (nunca pruebas\audio\uso\,
# que es el uso real) y se comprueba lo que CUENTA.
#
#   powershell -NoProfile -File tools\probar-falsas-alarmas.ps1
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw ('no encuentro ' + $n + ' en assistant.ps1') }
    return $fn.Extent.Text
}
# las listas salen DEL ARCHIVO REAL: una copia aqui se quedaria vieja al primer cambio y
# esta prueba pasaria midiendo otra cosa
foreach ($v in @('DestinosUso', 'DestinosSecos')) {
    $asig = @($ast.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $_.Left.VariablePath.UserPath -eq $v })
    if ($asig.Count -ne 1) { throw ('falta la lista ' + $v + ' en assistant.ps1') }
    Invoke-Expression $asig[0].Extent.Text
}
Invoke-Expression (Traer 'Get-FalsasAlarmas')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

$base = Join-Path $env:TEMP ('falsas-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $base -Force
$sinBom = New-Object System.Text.UTF8Encoding($false)
# una grabacion: el id lleva el dia dentro (20260919-100000), como en el fichero de verdad
function Grab([string]$id, [string]$origen) {
    return '{"id": "' + $id + '", "hora": "2026-09-19 10:00:00", "dur": 4.25, "pico": 0.2, "origen": "' + $origen + '", "entregado": "algo"}'
}
function Dest([string]$id, [string]$hizo) {
    return '{"id":"' + $id + '","hora":"2026-09-19 10:00:01","hizo":"' + $hizo + '","detalle":"algo"}'
}
# UN DIRECTORIO NUEVO POR CASO: Get-FalsasAlarmas se guarda el resultado mientras los dos
# ficheros no cambien de tamano, y dos casos distintos podrian pesar lo mismo
$script:dir = $base
function Anadir([string[]]$reg, [string[]]$des) {
    [System.IO.File]::WriteAllText((Join-Path $script:dir 'registro.jsonl'), (($reg -join "`n") + "`n"), $sinBom)
    [System.IO.File]::WriteAllText((Join-Path $script:dir 'destinos.jsonl'), (($des -join "`n") + "`n"), $sinBom)
}
function Pon([string[]]$reg, [string[]]$des) {
    $script:dir = Join-Path $base ([guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $script:dir -Force
    Anadir $reg $des
}
function Dice([string]$etq, [string]$dia, [int]$act, [int]$nada, [int]$pct) {
    $fa = Get-FalsasAlarmas $script:dir
    $ok = $fa.ContainsKey($dia) -and $fa[$dia].act -eq $act -and $fa[$dia].nada -eq $nada -and $fa[$dia].pct -eq $pct
    $det = if ($fa.ContainsKey($dia)) { "$($fa[$dia].act) activaciones, $($fa[$dia].nada) en nada, $($fa[$dia].pct) %" } else { 'ese dia no sale' }
    Comp $etq $ok $det
}

Write-Host '  -- sin grabaciones no se inventa un numero --'
$vacio = Get-FalsasAlarmas (Join-Path $base 'no-existe')
Comp 'sin ficheros, ni una fila' ($vacio.Count -eq 0) "$($vacio.Count) dias"

Write-Host '  -- lo que cuenta, con grabaciones de mentira --'
Pon @((Grab '20260919-100000' 'nombre'), (Grab '20260919-100100' 'nombre'),
      (Grab '20260919-100200' 'nombre'), (Grab '20260919-100300' 'nombre')) `
    @((Dest '20260919-100000' 'local'), (Dest '20260919-100100' 'ruido'),
      (Dest '20260919-100200' 'descarte'), (Dest '20260919-100300' 'error'))
Dice 'tres de cuatro acabaron en nada' '2026-09-19' 4 3 75

# ESTE ES EL FALLO QUE SE VIENE A ARREGLAR: el ruido del boton y del seguimiento NO puede
# entrar en el numerador de las activaciones por nombre. Con la cuenta vieja esto daba
# 8 de 2 = 400 %.
$reg = @((Grab '20260919-100000' 'nombre'), (Grab '20260919-100100' 'nombre'))
$des = @((Dest '20260919-100000' 'local'), (Dest '20260919-100100' 'ruido'))
foreach ($i in 1..6) {
    $reg += (Grab ('20260919-2000' + '{0:d2}' -f $i) 'boton o seguimiento')
    $des += (Dest ('20260919-2000' + '{0:d2}' -f $i) 'ruido')
}
Pon $reg $des
Dice 'el ruido del boton no cuenta como falsa alarma' '2026-09-19' 2 1 50

Write-Host '  -- los casos de borde --'
# se desperto y no dejo ni una linea: eso es lo mas parecido a una falsa alarma que hay
Pon @((Grab '20260919-100000' 'nombre'), (Grab '20260919-100100' 'nombre')) @((Dest '20260919-100000' 'local'))
Dice 'la que no dejo destino acabo en nada' '2026-09-19' 2 1 50

# la charla y el traductor son lo que Nova HIZO con la frase, no un final en falso
Pon @((Grab '20260919-100000' 'nombre'), (Grab '20260919-100100' 'nombre')) `
    @((Dest '20260919-100000' 'local'), (Dest '20260919-100100' 'charla'), (Dest '20260919-100100' 'traducir'))
Dice 'hablar no es una falsa alarma' '2026-09-19' 2 0 0

# 'descarte' se apunta DE CAMINO, antes de ir al modelo: manda el ultimo destino de verdad
Pon @((Grab '20260919-100000' 'nombre')) @((Dest '20260919-100000' 'descarte'), (Dest '20260919-100000' 'receta'))
Dice 'el descarte de camino no cuenta si luego se hizo' '2026-09-19' 1 0 0

# un dia sin destinos apuntados no puede salir: seria un 100 % por falta de datos
Pon @((Grab '20260916-100000' 'nombre'), (Grab '20260919-100000' 'nombre')) @((Dest '20260919-100000' 'local'))
$fa = Get-FalsasAlarmas $script:dir
Comp 'un dia sin destinos no sale en la tabla' (-not $fa.ContainsKey('2026-09-16')) (($fa.Keys | Sort-Object) -join ', ')

# una linea a medias -Nova apagada justo mientras escribia- no puede tumbar el contador
Pon @((Grab '20260919-100000' 'nombre'), 'esto no es json', (Grab '20260919-100100' 'nombre')) `
    @((Dest '20260919-100000' 'local'), 'roto', (Dest '20260919-100100' 'ruido'))
Dice 'una linea rota se salta' '2026-09-19' 2 1 50

# QUE LO GUARDADO NO SE QUEDE PEGADO: el numero tiene que moverse en cuanto llega una orden
# nueva, o seria otra cosa que se queda puesta sin que nadie lo note.
Pon @((Grab '20260919-100000' 'nombre')) @((Dest '20260919-100000' 'local'))
Dice 'una sola orden, y salio bien' '2026-09-19' 1 0 0
Anadir @((Grab '20260919-100000' 'nombre'), (Grab '20260919-100100' 'nombre')) `
       @((Dest '20260919-100000' 'local'), (Dest '20260919-100100' 'ruido'))
Dice 'en cuanto crece el fichero, cambia el numero' '2026-09-19' 2 1 50

# EL DATO REAL DEL 18/09, CLAVADO AQUI: 7 de 18 activaciones por nombre acabaron en nada.
# Si alguien cambia la cuenta y este numero se mueve, se entera antes que braya.
$reg = @(); $des = @()
foreach ($i in 1..18) {
    $reg += (Grab ('20260918-1000' + '{0:d2}' -f $i) 'nombre')
    $des += (Dest ('20260918-1000' + '{0:d2}' -f $i) $(if ($i -le 7) { 'ruido' } else { 'local' }))
}
Pon $reg $des
Dice 'el 18/09 de verdad: 7 de 18' '2026-09-18' 18 7 39

# LA INVARIANTE: pase lo que pase, esto es un porcentaje. Si vuelve a pasar de 100 es que
# alguien ha vuelto a mezclar poblaciones.
$reg = @(); $des = @()
foreach ($i in 1..9) {
    $reg += (Grab ('20260919-3000' + '{0:d2}' -f $i) $(if ($i -le 3) { 'nombre' } else { 'boton' }))
    $des += (Dest ('20260919-3000' + '{0:d2}' -f $i) 'ruido')
}
Pon $reg $des
$fa = Get-FalsasAlarmas $script:dir
$peor = 0
foreach ($k in $fa.Keys) { if ($fa[$k].pct -gt $peor) { $peor = $fa[$k].pct } }
Comp 'el porcentaje nunca pasa de 100' ($peor -le 100) "$peor %"

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host 'todo correcto'
