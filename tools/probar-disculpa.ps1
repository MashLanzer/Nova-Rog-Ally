# CUANDO NOVA SE DISCULPA, QUE LO APUNTE ELLA MISMA (26/09, idea 55 de las 121).
#
# De 542 respuestas de la charla en 14 dias, 31 son una admision clara de error ("Tienes razon,
# me equivoque", "confundi Bluetooth con wifi", "no deberia haber dicho que lo cerre"). Esa
# admision la escribe NOVA, no braya, asi que no se confunde una charla que empieza por "no" con
# una correccion. Cada turno asi queda como sospecha de fallo (senal 'me-disculpe', peso 'medio')
# con la frase de braya que lo provoco. Dobla el corpus de sospechas (hoy 33 lineas, 3 clases).
#
# Se EJECUTA Write-FalloDeducido de verdad y se saca el PATRON del propio assistant.ps1 (no una
# copia): comprobar con un patron escrito aqui probaria mi regex, no la de Nova (manera 4).
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
$mal = 0
function Comp($etq, $ok, $det = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira ---
function Log($m) { }
$script:ultimoUsoId = ''
$script:ultimoDeducidoId = ''
$base = Join-Path $env:TEMP ('disculpa-' + [guid]::NewGuid().ToString('N'))
$TmpDir = Join-Path $base 'tmp'
$LogDir = $base
$dirUso = Join-Path $base 'pruebas\audio\uso'
$null = New-Item -ItemType Directory -Path $TmpDir -Force
$null = New-Item -ItemType Directory -Path $dirUso -Force
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Write-FalloDeducido')
$fSenales = Join-Path $dirUso 'senales-fallo.jsonl'

Write-Host ''
Write-Host '-- 1. la senal se escribe con su clase y su peso --'
[void](Write-FalloDeducido 'me-disculpe' 'confundi bluetooth con wifi' 'id-disc')
[void](Write-FalloDeducido 'descarte' 'pon la novena cancion' 'id-desc')
[void](Write-FalloDeducido 'no-orden-a-charla' 'que tal estas' 'id-noc')
$lineas = @(Get-Content -LiteralPath $fSenales -Encoding UTF8 | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
$disc = @($lineas | Where-Object { $_.senal -eq 'me-disculpe' })
Comp '1. la disculpa deja una senal me-disculpe' ($disc.Count -eq 1) "$($disc.Count)"
Comp '   con peso medio (sospecha, no verdad)' ($disc.Count -eq 1 -and $disc[0].peso -eq 'medio') "peso=$(if ($disc.Count) { $disc[0].peso })"
Comp '   y con la frase de braya como detalle' ($disc.Count -eq 1 -and $disc[0].detalle -eq 'confundi bluetooth con wifi') "detalle=$(if ($disc.Count) { $disc[0].detalle })"
$desc = @($lineas | Where-Object { $_.senal -eq 'descarte' })
$noc = @($lineas | Where-Object { $_.senal -eq 'no-orden-a-charla' })
Comp '2. el descarte sigue en alto y no-orden-a-charla en bajo' (($desc.Count -eq 1 -and $desc[0].peso -eq 'alto') -and ($noc.Count -eq 1 -and $noc[0].peso -eq 'bajo')) ''

Write-Host ''
Write-Host '-- 3. el patron (sacado del propio assistant.ps1) caza las admisiones y no las disculpas por limitacion --'
$mP = [regex]::Match($fuente, "\(ConvertTo-Plain \`$fraseC\) -match '([^']+)'")
if (-not $mP.Success) { Write-Host '  MAL  no encuentro el patron de me-disculpe en el fuente'; exit 1 }
$patron = $mP.Groups[1].Value
Write-Host "       patron: $patron"
$admiten = @(
    'Tienes razon, me equivoque al interpretar lo que dijiste',
    'Claro, tienes razon. Disculpa el error, confundi Bluetooth con wifi',
    'Tienes razon, me pase. No deberia haber dicho que lo cerre',
    'Uy, me confundi de aplicacion',
    'Perdona, meti la pata con eso')
$noAdmiten = @(
    'Lo siento, no tengo informacion sobre ese tema',
    'Perdon, man, fui muy largo en la respuesta',
    'Vale, te abro el navegador ahora mismo',
    'Que tal, en que te ayudo hoy')
$okA = $true; foreach ($f in $admiten) { if (-not ((ConvertTo-Plain $f) -match $patron)) { $okA = $false; Write-Host "     no cazo (deberia): $f" } }
$okN = $true; foreach ($f in $noAdmiten) { if ((ConvertTo-Plain $f) -match $patron) { $okN = $false; Write-Host "     cazo (no deberia): $f" } }
Comp '3. caza las 5 admisiones de ejemplo' $okA ''
Comp '   y NO caza las disculpas por limitacion ni las ordenes' $okN 'lo siento/no tengo informacion, perdon fui largo, abre navegador'

Write-Host ''
Write-Host '-- 4. y no consume el id: braya todavia puede quejarse despues --'
# Write-FalloDeducido no borra tmp\dictado-id.txt ni $script:ultimoUsoId (lo dice su comentario).
Set-Content -LiteralPath (Join-Path $TmpDir 'dictado-id.txt') -Value 'id-vivo' -NoNewline
$script:ultimoDeducidoId = ''
[void](Write-FalloDeducido 'me-disculpe' 'algo' '')
$idSigue = (Test-Path -LiteralPath (Join-Path $TmpDir 'dictado-id.txt')) -and (([IO.File]::ReadAllText((Join-Path $TmpDir 'dictado-id.txt'))).Trim() -eq 'id-vivo')
Comp '4. la marca del dictado sigue viva tras apuntar la disculpa' $idSigue 'un "no era eso" posterior no se queda sin id'

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'cuando Nova se disculpa, lo apunta ella misma' -ForegroundColor Green
exit 0
