# Convierte los descartes del log en vocabulario nuevo.
#
# El asistente ya registra cada frase que la capa local NO entendio:
#   LOCAL descarta: no reconozco '<trozo>'
# Ese registro estaba ahi sin aprovechar: habia que leerlo a mano y editar
# commands.json uno mismo. Este script lo agrupa por frecuencia, busca a que
# se parece cada descarte dentro del vocabulario que YA existe, y propone las
# entradas. No escribe nada sin que lo apruebes.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\aprende-descartes.ps1

$ErrorActionPreference = 'Continue'
$base = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$log = Join-Path $base 'assistant.log'
$cmdsPath = Join-Path $base 'commands.json'

if (-not (Test-Path -LiteralPath $log)) { Write-Host "No encuentro $log" -ForegroundColor Red; exit 1 }
$cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-Distancia([string]$a, [string]$b) {
    $n = $a.Length; $m = $b.Length
    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $c = if ($a[$i - 1] -eq $b[$j - 1]) { 0 } else { 1 }
            $x = $d[($i - 1), $j] + 1
            $y = $d[$i, ($j - 1)] + 1
            $z = $d[($i - 1), ($j - 1)] + $c
            $min = $x
            if ($y -lt $min) { $min = $y }
            if ($z -lt $min) { $min = $z }
            $d[$i, $j] = $min
        }
    }
    return $d[$n, $m]
}

$texto = [System.IO.File]::ReadAllText($log, [System.Text.Encoding]::UTF8)
$descartes = @{}
foreach ($l in ($texto -split "`r?`n")) {
    if ($l -match "LOCAL descarta: no reconozco '([^']+)'") {
        $d = $Matches[1].Trim()
        if ($d) { $descartes[$d] = 1 + [int]$descartes[$d] }
    }
}

if ($descartes.Count -eq 0) {
    Write-Host 'No hay descartes en el log. Nada que aprender por ahora.' -ForegroundColor Green
    exit 0
}

# vocabulario conocido, para buscar parecidos
$conocidas = @()
foreach ($p in $cmds.apps.PSObject.Properties) { $conocidas += @{ nombre = $p.Name; tipo = 'app' } }
foreach ($p in $cmds.sitios.PSObject.Properties) { $conocidas += @{ nombre = $p.Name; tipo = 'sitio' } }

Write-Host ''
Write-Host "Frases que el asistente NO entendio ($($descartes.Count) distintas):" -ForegroundColor Cyan
Write-Host ''

$sug = @()
foreach ($e in ($descartes.GetEnumerator() | Sort-Object Value -Descending)) {
    $frase = $e.Key
    $veces = $e.Value
    Write-Host ("  [{0}x] '{1}'" -f $veces, $frase) -ForegroundColor White

    # ultima palabra: suele ser el objetivo ("abre el estin" -> "estin")
    $palabras = ($frase -split '\s+') | Where-Object { $_.Length -ge 3 }
    $mejor = $null; $mejorD = 999; $mejorPal = ''
    foreach ($pal in $palabras) {
        foreach ($c in $conocidas) {
            $d = Get-Distancia $pal $c.nombre
            $tope = [Math]::Max(2, [int][Math]::Floor($c.nombre.Length * 0.45))
            if ($d -le $tope -and $d -lt $mejorD) { $mejorD = $d; $mejor = $c; $mejorPal = $pal }
        }
    }
    # una correccion de una palabra a si misma no aporta nada
    if ($mejor -and $mejorPal -ne $mejor.nombre) {
        Write-Host ("        se parece a '{0}' ({1}) -> sugerencia: correccion '{2}' = '{0}'" -f $mejor.nombre, $mejor.tipo, $mejorPal) -ForegroundColor Yellow
        $sug += @{ de = $mejorPal; a = $mejor.nombre }
    } elseif ($mejor) {
        Write-Host '        esa palabra YA se conoce: el fallo esta en el resto de la frase' -ForegroundColor DarkGray
    } else {
        Write-Host '        no se parece a nada conocido: quiza sea algo nuevo que anadir a mano' -ForegroundColor DarkGray
    }
}

if ($sug.Count -eq 0) {
    Write-Host ''
    Write-Host 'Sin sugerencias automaticas.' -ForegroundColor Gray
    exit 0
}

Write-Host ''
Write-Host "Se pueden anadir $($sug.Count) correcciones a commands.json." -ForegroundColor Cyan
$r = Read-Host 'Aplicar? (s/N)'
if ($r -ne 's' -and $r -ne 'S') { Write-Host 'No se cambio nada.' -ForegroundColor Gray; exit 0 }

foreach ($s in $sug) {
    $cmds.correcciones | Add-Member -NotePropertyName $s.de -NotePropertyValue $s.a -Force
}
[System.IO.File]::WriteAllText($cmdsPath, ($cmds | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ''
Write-Host "Listo: $($sug.Count) correcciones anadidas. Reinicia el asistente para que las cargue." -ForegroundColor Green
