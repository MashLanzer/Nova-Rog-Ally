# SU IP YA NO SALE EN CLARO (26/09, idea 57 de las 121).
#
# De los 8 destinos externos del codigo, ip-api.com era el UNICO que iba por http:// sin cifrar
# (los otros siete -anthropic, steam x2, open-meteo- por https): en esa peticion viajaba la IP
# publica de braya en claro, una vez al dia. Ahora va por https. Y se cuenta cuantos dias seguidos
# da la misma ciudad ('iguales' en ubicacion.json) -la medicion para dejar de preguntar mas
# adelante; aun no se actua (sin racha medida no se fija el numero, y falta detectar el viaje)-.
#
# La comprobacion FUERTE es de privacidad: NINGUNA llamada externa en claro en las cuatro fuentes.
# Es un guardarrail de repo, como probar-memoria-ignorada: si alguien mete otro http://, salta.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
$mal = 0
function Comp($etq, $ok, $det = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host ''
Write-Host '-- 1. ni una llamada externa en claro (http:// que no sea localhost) --'
$fuentes = @('assistant.ps1', 'wake_vosk.py', 'charla_worker.py', 'charla_memoria.py')
$enClaro = @()
foreach ($f in $fuentes) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    $n = 0
    foreach ($linea in [IO.File]::ReadAllLines($ruta)) {
        $n++
        if ($linea.TrimStart().StartsWith('#')) { continue }          # una mencion en un comentario no es una llamada
        if ($linea -match 'http://(?!127\.0\.0\.1|localhost)[a-zA-Z]') { $enClaro += "$f`:$n" }
    }
}
Comp '1. cero destinos externos por http en las 4 fuentes' ($enClaro.Count -eq 0) $(if ($enClaro.Count) { "EN CLARO: " + ($enClaro -join ', ') } else { '' })
$asis = [IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'), [Text.Encoding]::UTF8)
Comp '2. ip-api se llama por https' ($asis.Contains("'https://ip-api.com/json/") -and -not $asis.Contains("'http://ip-api.com/json/")) ''

Write-Host ''
Write-Host '-- 3. cuenta los dias seguidos con la misma ciudad (iguales) --'
$uc = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Update-Clima' }, $true)
if (-not $uc) { Write-Host '  MAL  no encuentro Update-Clima'; exit 1 }
$txt = $uc.Extent.Text
Comp '3. suma iguales cuando la ciudad coincide' ($txt -match '\$igualesU = \[int\]\$cacheU\.iguales \+ 1') 'y arranca en 1 cuando cambia'
Comp '   y lo guarda en ubicacion.json' ($txt -match 'iguales = \$igualesU') ''
# lo que NO puede pasar: que ya se corte el clima con la ubicacion fija (part 2, aun no hecha).
# Si alguien anade el Set-Cfg de lat/lon, este banco recuerda que hace falta la guarda del viaje.
Comp '   y todavia NO deja de preguntar (part 2 pendiente: falta racha medida + SSID)' (-not ($txt -match "Set-Cfg 'clima' 'lat'")) 'al implementarla, anadir aqui la guarda del SSID'

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'ni una llamada externa va en claro' -ForegroundColor Green
exit 0
