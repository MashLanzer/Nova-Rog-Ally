# EL CONTADOR DE LA META, PROBADO SIN MICROFONO (19/09, idea 3 de MEJORAS.md).
#
# Get-ComoTeEntendi es el unico numero que mide la meta de braya -que Nova le entienda
# siempre-, asi que lo peor que puede hacer es dar un porcentaje bonito y falso. Aqui se le
# dan destinos DE MENTIRA en $env:TEMP (nunca pruebas\audio\uso\, que es el uso real) y se
# comprueba lo que DICE, no que la funcion exista.
#
#   powershell -NoProfile -File tools\probar-meta.ps1
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw ('no encuentro ' + $n + ' en assistant.ps1') }
    return $fn.Extent.Text
}
# Las tres listas salen DEL ARCHIVO REAL, no se copian aqui: una copia se quedaria vieja
# al primer cambio y esta prueba pasaria midiendo otra cosa.
foreach ($v in @('UsoBien', 'UsoMal', 'UsoNeutro')) {
    $asig = @($ast.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $_.Left.VariablePath.UserPath -eq $v })
    if ($asig.Count -ne 1) { throw ('falta la lista ' + $v + ' en assistant.ps1') }
    Invoke-Expression $asig[0].Extent.Text
}
Invoke-Expression (Traer 'Get-ComoTeEntendi')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-48} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# SI LA FRASE Y EL ANALISIS NO CUENTAN IGUAL, NO SE PUEDE CREER NINGUNO DE LOS DOS: miden
# la misma meta. El dia que alguien anada un destino nuevo en un sitio y no en el otro,
# braya oiria un porcentaje y leeria otro distinto, y no sabria cual es el bueno.
Write-Host '  -- las listas dicen lo mismo que tools\analizar-uso.py --'
$py = [System.IO.File]::ReadAllText((Join-Path $raiz 'tools\analizar-uso.py'), [System.Text.Encoding]::UTF8)
function ListaPy([string]$n) {
    if ($py -notmatch ('(?m)^' + $n + '\s*=\s*\(([^)]*)\)')) { return @() }
    return @([regex]::Matches($Matches[1], '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
}
function CompLista([string]$n, $lista) {
    $dePy = (ListaPy $n) -join ','
    $dePs = (@($lista) | Sort-Object) -join ','
    Comp ('la lista ' + $n + ' coincide con el analisis') ($dePy -ne '' -and $dePy -eq $dePs) $dePy
}
CompLista 'BIEN' $UsoBien
CompLista 'MAL' $UsoMal
CompLista 'NEUTRO' $UsoNeutro

Write-Host '  -- lo que contesta, con destinos de mentira --'
$hoy = [datetime]'2026-09-19 12:00:00'
$base = Join-Path $env:TEMP ('meta-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $base -Force
$ruta = Join-Path $base 'destinos.jsonl'
function L([string]$id, [string]$hizo, [string]$det) {
    return '{"id":"' + $id + '","hora":"2026-09-19 10:00:00","hizo":"' + $hizo + '","detalle":"' + $det + '"}'
}
function Pon([string[]]$lineas) {
    [System.IO.File]::WriteAllText($ruta, (($lineas -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}
function Dice([string]$etq, [string[]]$debe, [string[]]$noDebe) {
    $t = Get-ComoTeEntendi $ruta $hoy
    $ok = $true
    foreach ($d in $debe) { if ($t -notmatch [regex]::Escape($d)) { $ok = $false } }
    foreach ($d in $noDebe) { if ($t -match [regex]::Escape($d)) { $ok = $false } }
    Comp $etq $ok $t
}

# sin fichero: una instalacion recien puesta no tiene nada que contar, y un 0 % seria mentira
$sin = Get-ComoTeEntendi (Join-Path $base 'no-existe.jsonl') $hoy
Comp 'sin fichero no se inventa un numero' ($sin -match 'no te puedo dar el numero') $sin

# el contador es de HOY: lo de ayer no puede colarse
Pon @((L '20260918-100000' 'local' 'abre steam'), (L '20260918-100100' 'error' 'nada'))
Dice 'lo de ayer no cuenta como hoy' @('no me has pedido nada') @('por ciento')

Pon @((L '20260919-100000' 'local' 'abre steam'), (L '20260919-100100' 'aprendida' 'pon modo noche'),
      (L '20260919-100200' 'memoria' 'que apunte ayer'), (L '20260919-100300' 'error' 'baja el brillo'))
Dice 'tres de cuatro es un 75 por ciento' @('3 de 4', '75 por ciento', 'me equivoque una vez', 'baja el brillo') @()

Pon @((L '20260919-100000' 'local' 'abre steam'), (L '20260919-100100' 'local' 'sube el volumen'))
Dice 'un dia sin fallos es el 100 por ciento' @('100 por ciento', '2 de 2') @('me equivoque')

# LA CHARLA NO BAJA EL PORCENTAJE (medido el 18/09): mas de la mitad del uso real es
# neutro, y si entrara en el denominador hablar con Nova le bajaria los aciertos sin que
# se equivocara ni una vez. Aqui tienen que salir 2 de 2, no 2 de 5.
Pon @((L '20260919-100000' 'local' 'abre steam'), (L '20260919-100100' 'local' 'pausa'),
      (L '20260919-100200' 'charla' 'que tal estas'), (L '20260919-100300' 'charla' 'cuentame un chiste'),
      (L '20260919-100400' 'accion' 'busca una receta'))
Dice 'la charla y el agente van aparte' @('2 de 2', '100 por ciento', 'Aparte hablamos 3 veces') @('2 de 5', '40 por ciento')

# LO QUE DICES TU MANDA: la orden se ejecuto como 'local' y aun asi es un fallo
Pon @((L '20260919-100000' 'local' 'abrir outlast'),
      '{"id":"20260919-100000","hora":"2026-09-19 10:01:00","hizo":"fallo-dicho-por-ti","detalle":"queria outlast 2"}')
Dice 'un no era eso pesa mas que el destino' @('0 de 1', 'me lo dijiste tu', 'abrir outlast') @('100 por ciento')

# EL BOTON PULSADO SIN HABLAR NO ES UN FALLO DE OIDO: analizar-uso.py deja fuera esas
# ordenes porque nunca entregaron texto. Sin esto, del mismo dia (18/09) la frase decia
# 72 % y el analisis 75 %, y dos numeros que no cuadran no los cree nadie.
Pon @((L '20260919-100000' 'local' 'abre steam'), (L '20260919-100100' 'error' 'dictado vacio'),
      (L '20260919-100200' 'error' 'baja el brillo'))
Dice 'el dictado vacio ni suma ni resta' @('1 de 2', '50 por ciento') @('1 de 3', '33 por ciento')

# una linea a medias -Nova apagada justo mientras escribia- no puede tumbar el contador
Pon @((L '20260919-100000' 'local' 'abre steam'), 'esto no es json', (L '20260919-100100' 'local' 'pausa'))
Dice 'una linea rota se salta' @('2 de 2') @()

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host 'todo correcto'
