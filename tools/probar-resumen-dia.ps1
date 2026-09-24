# EL RESUMEN DEL DIA, CUANDO EL LO PIDA (23/09, idea 19).
#
# EXISTIA MEDIO, y la mitad que existia estaba bien: el patron y el ejecutor ya estaban, y NO
# se dispara solo -solo contesta si lo pregunta-, que es lo que pedia la idea.
# LOS CUATRO HUECOS, los cuatro medidos:
#  1. decia A QUE jugo, pero no CUANTO. It Takes Two: 3 h 12 el 22/09, 2 h 45 el 20/09 y
#     5 h 38 el 15/09, todo en juegos.json, y el resumen no lo decia.
#  2. el acierto del dia existe desde el 19/09 y solo se conseguia preguntando aparte.
#  3. las descargas terminadas solo dejaban rastro en el log y en una variable que se pierde
#     en cada uno de los 16,3 arranques diarios.
#  4. del disco Nova avisa suelta -cuatro veces en cuatro dias- y no salia aqui.
#
# Y UN HUECO DE PRUEBAS: probar-parte mira Get-ParteGeneral y probar-meta mira
# Get-ComoTeEntendi, pero a Get-QueHeHecho no la miraba NINGUN banco.
#
# LO QUE MAS VIGILA ESTE BANCO: que no se escriba un contador de aciertos nuevo. Escribir
# otro es exactamente como se llego a tener un 72 % y un 75 % del mismo dia; el numero sale
# del mismo Get-MetaDias que ya comparten analizar-uso.py y probar-meta.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el mundo de mentira ----------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('res-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$null = New-Item -ItemType Directory -Path (Join-Path $tmp 'diario') -Force
$MemoriaDir = $tmp
$DescargasHechasPath = Join-Path $tmp 'descargas.json'
$DescargasHechasDias = if ($fuente -match '(?m)^\$DescargasHechasDias = (\d+)') { [int]$Matches[1] } else { 30 }
$script:descargasMem = $null
$script:ahoraMs = 5000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:juegoActivo = ''
$script:juegoDesde = 0
$script:Juegos = @()
$script:tiempoJugado = @()
$script:meta = @{}
$script:falsas = @{}
$script:stats = @{ dias = @{} }
function Log([string]$m) { }
function Save-Corrupto($a, $b) { }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
function Update-Juegos { return 0 }
function Get-TiempoJugado([int]$dias = 7, [datetime]$hoy = (Get-Date)) { return @($script:tiempoJugado) }
function Get-MetaDias([int]$dias = 14, [string]$ruta = '', [datetime]$ahora = (Get-Date)) { return $script:meta }
function Get-Estadisticas { return $script:stats }
function Get-FalsasAlarmas { return $script:falsas }
Invoke-Expression (Traer 'Format-Minutos')
Invoke-Expression (Traer 'Format-Gigas')
Invoke-Expression (Traer 'Get-DescargasHechas')
Invoke-Expression (Traer 'Add-DescargaHecha')
Invoke-Expression (Traer 'Get-QueHeHecho')

$hoy = (Get-Date).ToString('yyyy-MM-dd')
$hoyM = (Get-Date).ToString('yyyyMMdd')
function Limpia {
    $script:tiempoJugado = @()
    $script:meta = @{}
    $script:stats = @{ dias = @{} }
    $script:falsas = @{}
    $script:juegoActivo = ''
    $script:descargasMem = $null
    try { Remove-Item -LiteralPath $DescargasHechasPath -Force -ErrorAction SilentlyContinue } catch {}
    try { Get-ChildItem -LiteralPath (Join-Path $tmp 'diario') -File | Remove-Item -Force } catch {}
}

Write-Host ''
Write-Host '-- 1. CUANTO jugo, no solo a que --'
Limpia
$script:tiempoJugado = @(@{ juego = 'It Takes Two'; minutos = 192 }, @{ juego = 'ELDEN RING'; minutos = 30 })
$r1 = Get-QueHeHecho
Comp 'dice las horas del primero' ($r1 -match 'jugaste 3 horas y 12 minutos a It Takes Two') "$r1"
Comp 'y tambien el segundo' ($r1 -match 'ELDEN RING') "$r1"

Write-Host ''
Write-Host '-- 2. cuantas te entendi, del contador que YA existe --'
Limpia
$script:meta = @{ $hoyM = @{ bien = 18; mal = 2; otras = 1; neutras = 0 } }
$r2 = Get-QueHeHecho
Comp 'dice el acierto del dia' ($r2 -match 'te entendi 18 de 21') "$r2"
$gq = SinComentarios (Traer 'Get-QueHeHecho')
Comp 'y sale de Get-MetaDias, no de un contador nuevo' ($gq -match 'Get-MetaDias 0(?![0-9])') 'un contador propio da 72 % donde otro da 75 %'

Write-Host ''
Write-Host '-- 3. que se descargo, de lo apuntado en disco --'
Limpia
Add-DescargaHecha 'It Takes Two'
$script:descargasMem = $null   # como si Nova se reiniciara
$r3 = Get-QueHeHecho
Comp 'una descarga se dice con su nombre' ($r3 -match 'termino de bajarse It Takes Two') "$r3"
Limpia
Add-DescargaHecha 'It Takes Two'
Add-DescargaHecha 'ELDEN RING'
Add-DescargaHecha 'OUTLAST 2'
$r3b = Get-QueHeHecho
Comp 'y varias, contadas' ($r3b -match 'terminaron 3 descargas') "$r3b"
Add-DescargaHecha 'It Takes Two'
Comp 'la misma dos veces no cuenta dos' (@((Get-DescargasHechas)[$hoy]).Count -eq 3) "$(@((Get-DescargasHechas)[$hoy]).Count)"

Write-Host ''
Write-Host '-- 4. y sobrevive al reinicio, que son 16 al dia --'
Limpia
Add-DescargaHecha 'PEAK'
$script:descargasMem = $null
Comp 'se relee del disco' (@((Get-DescargasHechas)[$hoy]) -contains 'PEAK') "$(@((Get-DescargasHechas)[$hoy]) -join ', ')"
Comp 'y el historico se poda a 30 dias' ($DescargasHechasDias -eq 30) "$DescargasHechasDias"
# un dia viejo se cae al escribir
$viejo = (Get-Date).AddDays(-45).ToString('yyyy-MM-dd')
$h = Get-DescargasHechas
$h[$viejo] = @('algo viejo')
Add-DescargaHecha 'MIMESIS'
$script:descargasMem = $null
Comp 'lo de hace 45 dias ya no esta' (-not (Get-DescargasHechas).ContainsKey($viejo)) "$(@((Get-DescargasHechas).Keys) -join ', ')"

Write-Host ''
Write-Host '-- 5. y cuanto disco queda --'
Limpia
$r5 = Get-QueHeHecho
Comp 'el disco sale en el resumen' ($r5 -match 'te quedan .+ en [A-Z]') "$r5"

Write-Host ''
Write-Host '-- 6. sin nada que contar, lo dice y ya --'
Limpia
$r6 = Get-QueHeHecho
# el disco siempre esta, asi que se mira que al menos no invente juegos ni ordenes
Comp 'no se inventa juegos' ($r6 -notmatch 'jugaste') "$r6"
Comp 'ni ordenes' ($r6 -notmatch 'me diste') "$r6"

Write-Host ''
Write-Host '-- 7. cada bloque en su try/catch: que falte uno no deja sin resumen --'
$nTry = ([regex]::Matches($gq, 'try \{')).Count
Comp 'hay un try por cada bloque' ($nTry -ge 6) "$nTry try"
Limpia
$script:meta = $null   # como si el fichero de uso no existiera
$r7 = Get-QueHeHecho
Comp 'y sin los aciertos, el resto sigue saliendo' ($r7 -match 'te quedan') "$r7"

Write-Host ''
Write-Host '-- 8. las tres formas nuevas de pedirlo --'
$patR = ''
foreach ($l in ($fuente -split "`r?`n")) {
    if ($l -match "'(\^\(\?:que he hecho[^']+)'") { $patR = $Matches[1]; break }
}
if (-not $patR) { Write-Host '  MAL  no encuentro el patron del resumen'; exit 1 }
$bienR = 0
foreach ($fr in @('que he hecho', 'que tal el dia', 'resumen del dia', 'como ha ido el dia',
                  'que tal ha ido el dia', 'cuentame que tal el dia', 'que paso hoy')) {
    if ($fr -match $patR) { $bienR++ } else { Write-Host "       no entra: '$fr'" }
}
Comp 'las siete formas entran' ($bienR -eq 7) "$bienR de 7"
Comp 'pero "como va todo" sigue siendo el parte general' ('como va todo' -notmatch $patR) 'eso es el estado de ahora, no el dia'

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  el resumen del dia ya cuenta el dia entero'
exit 0
