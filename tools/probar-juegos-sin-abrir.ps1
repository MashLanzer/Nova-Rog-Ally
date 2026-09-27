# LO QUE BAJAS Y NO ABRES (27/09, idea 49 de las 121).
#
# Nova avisa de disco poco contestando con megas de cache teniendo 52 GB de juegos sin abrir
# delante. Ahora Get-JuegosSinAbrir los ve y el aviso nombra el mayor, y Test-JuegoSinEstrenar
# avisa (nivel 'bajo', solo popup) de lo que bajaste y no has abierto pasado TU plazo -aprendido
# de tus propios estrenos, no un numero a mano-. NUNCA desinstala. Datos INYECTADOS: si el banco
# mirara la biblioteca real, braya desinstala un juego y el banco se pondria rojo solo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira ---
$GB = 1073741824.0
$script:avisos = New-Object System.Collections.ArrayList
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cada = 60) {
    [void]$script:avisos.Add(@{ clave = $clave; texto = $texto; nivel = $nivel }); return $true
}
function Log([string]$m) { }
function ConvertTo-Plain([string]$t) { return ($t.ToLower() -replace '[^a-z0-9]', '') }
$script:invitado = $false
$script:juegoActivo = $null
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('jsa-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
$EstrenosPath = Join-Path $MemoriaDir 'estrenos.json'
$DescargasHechasDias = 30
function Write-Atomico([string]$ruta, [string]$contenido) { [IO.File]::WriteAllText($ruta, $contenido) }
$script:descFake = @{}
function Get-DescargasHechas { return $script:descFake }
Invoke-Expression (Traer 'Get-JuegosSinAbrir')
Invoke-Expression (Traer 'Get-Estrenos')
Invoke-Expression (Traer 'Save-Estrenos')
Invoke-Expression (Traer 'Test-JuegoSinEstrenar')

function J([string]$n, [double]$gb, [long]$ult) { return [pscustomobject]@{ nombre = $n; tamano = $gb * $GB; ultimo = $ult } }

Write-Host ''
Write-Host '  -- Get-JuegosSinAbrir: Game Pass fuera, el mayor primero --'
$script:Juegos = @((J 'RoblOx' 0 0), (J 'Aniimo' 29 0), (J '5D Chess' 0.01 0), (J 'ELDEN RING' 40 1790000000))
$sa = @(Get-JuegosSinAbrir)
Comp '1. Game Pass (tamano 0) no entra' (-not (@($sa | ForEach-Object { $_.nombre }) -contains 'RoblOx')) ''
Comp '   ELDEN RING (ya abierto, ultimo>0) tampoco' (-not (@($sa | ForEach-Object { $_.nombre }) -contains 'ELDEN RING')) ''
Comp '2. el mayor va primero (Aniimo 29, no 5D Chess 0.01)' ($sa.Count -ge 1 -and $sa[0].nombre -eq 'Aniimo') "primero: $($sa[0].nombre)"
# 3. una entrada instalada y sin abrir cuenta; una de tamano 0 no, aunque ultimo sea 0
$script:Juegos = @((J 'X' 5 0), (J 'GamePassY' 0 0))
Comp '3. instalado y sin abrir cuenta; tamano 0 no' ((@(Get-JuegosSinAbrir).Count -eq 1) -and ((@(Get-JuegosSinAbrir))[0].nombre -eq 'X')) 'el tamano>0 es la guarda, no solo ultimo=0'

Write-Host ''
Write-Host '  -- Test-JuegoSinEstrenar: el plazo sale de los datos --'
# 5. menos de 2 muestras -> calla
$script:avisos.Clear(); $script:estrenoMirado = ''; if (Test-Path $EstrenosPath) { Remove-Item $EstrenosPath -Force }
$script:Juegos = @((J 'Aniimo' 29 0), (J 'Biped' 4 0))     # ninguno abierto -> 0 muestras
$script:descFake = @{ '2026-09-20' = @('Aniimo', 'Biped') }
$r5 = Test-JuegoSinEstrenar
Comp '5. con menos de 2 muestras, calla y no avisa' ((-not $r5) -and $script:avisos.Count -eq 0) 'regla 3: sin medicion, sin frase'
# 4. el texto usa Get-DescargasHechas y compara con $plazo (variable), no un literal de dias
$tj = Traer 'Test-JuegoSinEstrenar'
Comp '4. el plazo sale de Get-DescargasHechas, no de un numero' (($tj -match 'Get-DescargasHechas') -and ($tj -match '\.Days\) -lt \$plazo')) ''

# construir 2 muestras de estreno (juegos abiertos con su dia de descarga) para tener plazo
# A Way Out bajado 09-20, abierto 09-21 (1 dia); Unravel bajado 09-20, abierto 09-20 (0 dias) -> plazo max(1,0)+1 = 2
$eps = [datetime]'1970-01-01'
$uAWayOut = [long]([datetime]'2026-09-21 00:01').ToUniversalTime().Subtract($eps).TotalSeconds
$uUnravel = [long]([datetime]'2026-09-20 11:00').ToUniversalTime().Subtract($eps).TotalSeconds
Write-Host ''
Write-Host '  -- 6, 7, 8: el candidato, la marca y el nivel --'
$hoyS = (Get-Date).ToString('yyyy-MM-dd')
$hace3 = (Get-Date).AddDays(-3).ToString('yyyy-MM-dd')
$ayer = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
$script:Juegos = @((J 'A Way Out' 20 $uAWayOut), (J 'Unravel Two' 5 $uUnravel), (J 'Aniimo' 29 0))
# 6. Aniimo bajado hace 3 dias Y tambien HOY (el mas reciente manda) -> con plazo 2, HOY < 2 dias -> calla
$script:avisos.Clear(); $script:estrenoMirado = ''; if (Test-Path $EstrenosPath) { Remove-Item $EstrenosPath -Force }
$script:descFake = @{ '2026-09-20' = @('A Way Out', 'Unravel Two'); $hace3 = @('Aniimo'); $hoyS = @('Aniimo') }
$r6 = Test-JuegoSinEstrenar
Comp '6. coge el dia MAS RECIENTE (Aniimo bajado hoy) -> no regana' ((-not $r6) -and $script:avisos.Count -eq 0) 'sin agrupar, reganaria por algo de hoy'
# 7 y 8. Aniimo bajado SOLO hace 3 dias, sin abrir, plazo 2 -> avisa una vez, nivel bajo, y no repite
$script:avisos.Clear(); $script:estrenoMirado = ''; if (Test-Path $EstrenosPath) { Remove-Item $EstrenosPath -Force }
$script:descFake = @{ '2026-09-20' = @('A Way Out', 'Unravel Two'); $hace3 = @('Aniimo') }
$r7a = Test-JuegoSinEstrenar
$nAvi = $script:avisos.Count
$nivelA = if ($nAvi) { $script:avisos[0].nivel } else { '' }
$script:estrenoMirado = ''   # simula el dia siguiente (pero la marca en disco sigue)
$r7b = Test-JuegoSinEstrenar
Comp '7. avisa una vez y la 2a pasada ya no (marca en disco)' ($r7a -and $nAvi -eq 1 -and (-not $r7b)) "1a=$r7a avisos=$nAvi 2a=$r7b"
Comp '8. el aviso es nivel "bajo" (popup, no reganina)' ($nivelA -eq 'bajo') "nivel=$nivelA"
Comp '   y la clave lleva estreno- + el nombre plano' ($script:avisos.Count -ge 1 -and $script:avisos[0].clave -like 'estreno-*') $(if ($script:avisos.Count) { $script:avisos[0].clave })

Write-Host ''
Write-Host '  -- 9, 10, 11: nunca desinstala, dos salidas, el aviso de disco --'
$dos = (Traer 'Get-JuegosSinAbrir') + (Traer 'Test-JuegoSinEstrenar')
Comp '9. las dos funciones nunca desinstalan nada' ($dos -notmatch 'Remove-Item|Start-Process|steam://uninstall|Invoke-') 'regla 1'
Comp '10. Test-JuegoSinEstrenar tiene guarda diaria y de juego' (($tj -match '\$script:estrenoMirado -eq \$hoyE') -and ($tj -match 'if \(\$script:juegoActivo\) \{ return \$false \}')) 'regla 2'
# 11. el aviso de disco nombra un juego cuando lo hay y no promete nada cuando no
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '11. el aviso de disco-poco monta $colaDisco (juego sin abrir) y ya no promete "que ocupa mas"' (($sinCom -match '\$colaDisco = " \$\(\$sinD\[0\]\.nombre\)') -and ($sinCom -match "disco-poco' ""Te quedan .* en el disco\`$otraU\.\`$colaDisco""") -and ($sinCom -notmatch "disco-poco'[^`n]*Preguntame que ocupa mas")) 'la promesa vieja contestaba con megas de cache'

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'lo que bajas y no abres se cuenta' -ForegroundColor Green
exit 0
