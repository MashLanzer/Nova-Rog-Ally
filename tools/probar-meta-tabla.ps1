# C19: EL NUMERO DE LA META, PARA MIRARLO (21/09).
#
# Preguntarlo ya se podia desde el 19/09 ("¿como me has entendido hoy?"). Lo que faltaba era
# un sitio donde VERLO sin preguntar, y eso es la tabla que abre memoria\estadisticas.md.
#
# LO QUE MAS SE PRUEBA AQUI no es la tabla: es que los DOS contadores den el MISMO numero.
# Hay dos formas de contar lo mismo -la frase hablada y la tabla- y eso es justo lo que hay
# que vigilar: el 19/09 la frase decia 72 % y el analisis 75 % del mismo dia, y dos numeros
# que no cuadran no se los cree nadie. Si manana alguien toca una de las dos listas
# ($UsoBien, $UsoMal, $UsoNeutro) o una de las exclusiones, esto tiene que cantar.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Sacar([string]$nombre) {
    $m = [regex]::Match($fuente, '(?m)^\$' + [regex]::Escape($nombre) + '\s*=\s*(.+)$')
    if (-not $m.Success) { throw "no encuentro la variable $nombre" }
    return $m.Groups[1].Value
}
function Log($m) { }

# las tres listas, del archivo de verdad: si se tocan, este banco tiene que enterarse
$UsoBien = Invoke-Expression (Sacar 'UsoBien')
$UsoMal = Invoke-Expression (Sacar 'UsoMal')
$UsoNeutro = Invoke-Expression (Sacar 'UsoNeutro')
Invoke-Expression (Traer 'Get-MetaDias')
Invoke-Expression (Traer 'Get-ComoTeEntendi')

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# un destinos.jsonl de mentira, con el dia de hoy y el de ayer
$dir = Join-Path $env:TEMP ("meta-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$dest = Join-Path $dir 'destinos.jsonl'
$ahora = Get-Date
$hoy = $ahora.ToString('yyyyMMdd')
$ayer = $ahora.AddDays(-1).ToString('yyyyMMdd')
$lineas = @(
    # hoy: 3 bien, 1 equivocada, 1 charla (no cuenta), 1 boton sin voz (no cuenta)
    "{`"id`":`"$hoy-090001`",`"hizo`":`"local`"}",
    "{`"id`":`"$hoy-090002`",`"hizo`":`"local`"}",
    "{`"id`":`"$hoy-090003`",`"hizo`":`"aprendida`"}",
    "{`"id`":`"$hoy-090004`",`"hizo`":`"error`",`"detalle`":`"algo salio mal`"}",
    "{`"id`":`"$hoy-090005`",`"hizo`":`"charla`"}",
    "{`"id`":`"$hoy-090006`",`"hizo`":`"error`",`"detalle`":`"dictado vacio`"}",
    # ayer: 1 bien y 1 que dijiste tu que estaba mal
    "{`"id`":`"$ayer-200001`",`"hizo`":`"local`"}",
    "{`"id`":`"$ayer-200002`",`"hizo`":`"local`"}",
    "{`"id`":`"$ayer-200002`",`"hizo`":`"fallo-dicho-por-ti`",`"detalle`":`"no era eso`"}"
)
[System.IO.File]::WriteAllLines($dest, [string[]]$lineas, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ''
Write-Host '-- los numeros, dia a dia --'
$m = Get-MetaDias 14 $dest $ahora
Comp 'salen los dos dias' ($m.Count -eq 2) ("$($m.Count) dias")
Comp 'hoy: 3 bien' ([int]$m[$hoy].bien -eq 3) ("bien=$($m[$hoy].bien)")
Comp 'hoy: 1 equivocada' ([int]$m[$hoy].mal -eq 1) ("mal=$($m[$hoy].mal)")
Comp 'la charla no cuenta como acierto ni como fallo' ([int]$m[$hoy].neutras -eq 1) ("neutras=$($m[$hoy].neutras)")
# el boton pulsado sin hablar NO es que no te entienda: medido el 19/09, y sin esta
# exclusion la frase decia 72 % donde el analisis decia 75 %
Comp 'el boton pulsado sin hablar se deja fuera' (([int]$m[$hoy].bien + [int]$m[$hoy].mal + [int]$m[$hoy].otras) -eq 4) `
    ("juzgadas=$([int]$m[$hoy].bien + [int]$m[$hoy].mal + [int]$m[$hoy].otras), tienen que ser 4")
Comp 'ayer: lo que dijiste que estaba mal cuenta como fallo' ([int]$m[$ayer].mal -eq 1) ("mal=$($m[$ayer].mal)")

Write-Host ''
Write-Host '-- Y LO QUE MAS IMPORTA: los dos contadores dicen lo mismo --'
$frase = Get-ComoTeEntendi $dest $ahora
Write-Host ("       la frase: " + $frase)
$bienF = -1; $totF = -1
if ($frase -match 'entendido (\d+) de (\d+)') { $bienF = [int]$Matches[1]; $totF = [int]$Matches[2] }
elseif ($frase -match '(\d+) de (\d+), ni una equivocada') { $bienF = [int]$Matches[1]; $totF = [int]$Matches[2] }
$bienT = [int]$m[$hoy].bien
$totT = [int]$m[$hoy].bien + [int]$m[$hoy].mal + [int]$m[$hoy].otras
Comp 'la frase da un numero' ($bienF -ge 0) "$bienF de $totF"
Comp 'los aciertos coinciden' ($bienF -eq $bienT) "frase=$bienF tabla=$bienT"
Comp 'y el total tambien' ($totF -eq $totT) "frase=$totF tabla=$totT"

Write-Host ''
Write-Host '-- sin fichero no se inventa un numero --'
$m2 = Get-MetaDias 14 (Join-Path $dir 'no-existe.jsonl') $ahora
Comp 'sin destinos.jsonl devuelve vacio' ($m2.Count -eq 0)

Write-Host ''
Write-Host '-- y la tabla se escribe en estadisticas.md --'
Comp 'el markdown llama a Get-MetaDias' ($fuente -match '\$metaD = Get-MetaDias 14')
Comp 'y lo pone ANTES de la tabla por dia' `
    ($fuente.IndexOf('$metaD = Get-MetaDias 14') -lt $fuente.IndexOf('## Por d'))

Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host ''
Write-Host '  el numero de la meta se puede mirar, y es el mismo que si lo preguntas'
exit 0
