# NADIE ME HABLA Y NADIE SE ENTERA (19/09, H2m2).
#
# Todo lo que Nova decide sale del uso real, y el uso real es una linea por orden en
# pruebas\audio\uso\destinos.jsonl. Cuando eso deja de escribirse no falla nada a la vista:
# hoy 19/09 llevaba el dia entero encendida con el decodificado al 0 % y se vio por
# casualidad. Aqui se comprueba que ahora lo dice ella y -lo que mas importa- que CALLA en
# los huecos normales de un dia o dos, que en 9 dias de registro son los unicos que ha habido.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txtFuente = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
# EL UMBRAL SE LEE DEL FUENTE, no se copia aqui (idea 62): si el 3 cambia alli, esta prueba
# lo sigue en vez de quedarse comprobando un numero que ya no existe.
$SinUsoDias = if ($txtFuente -match '''sinUsoDias'' (\d+)\)') { [int]$Matches[1] } else { 0 }
Invoke-Expression (Traer 'Get-AvisoSinUso')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
$hoy = [datetime]'2026-09-19 12:00:00'
$base = Join-Path $env:TEMP ('sin-uso-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $base -Force
$ruta = Join-Path $base 'destinos.jsonl'
function PonUso([int]$haceDias, [string]$detras = '') {
    $f = $hoy.AddDays(-$haceDias).ToString('yyyy-MM-dd HH:mm:ss')
    $t = '{"id":"x","hora":"' + $f + '","hizo":"local","detalle":"abre steam"}'
    if ($detras) { $t = $t + "`n" + $detras }
    [System.IO.File]::WriteAllText($ruta, $t + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host '  -- el umbral sale del archivo real --'
Comp 'hay umbral y es de dias' ($SinUsoDias -ge 2 -and $SinUsoDias -le 7) "sinUsoDias=$SinUsoDias"

Write-Host '  -- los huecos normales NO se cuentan (el 14/09 fue uno) --'
PonUso 0
Comp 'con una orden de hoy, callada' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''
PonUso 1
Comp 'con la de ayer, callada' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''
PonUso 2
Comp 'dos dias tampoco son noticia' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''

Write-Host '  -- a partir del umbral, lo dice --'
PonUso $SinUsoDias
$t = Get-AvisoSinUso $ruta $hoy
Comp 'con el umbral justo, avisa' ($t -ne '') ("'" + $t + "'")
Comp 'y dice cuantos dias lleva' ($t -match "Llevo $SinUsoDias dias") ''
Comp 'y por que le importa (medir)' ($t -match 'medir') ''
Comp 'y que puede ser el oido roto' ($t -match 'oido') ''
PonUso 9
Comp 'nueve dias: cuenta nueve, no el umbral' ((Get-AvisoSinUso $ruta $hoy) -match 'Llevo 9 dias') ''

Write-Host '  -- y el interruptor lo apaga del todo --'
$SinUsoDias = 0
Comp 'con sinUsoDias a 0, ni una palabra' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''
$SinUsoDias = if ($txtFuente -match '''sinUsoDias'' (\d+)\)') { [int]$Matches[1] } else { 3 }

Write-Host '  -- lo roto no la deja muda ni la hace mentir --'
Remove-Item -LiteralPath $ruta -Force
Comp 'sin fichero, callada (instalacion nueva)' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''
[System.IO.File]::WriteAllText($ruta, '')
Comp 'fichero vacio, callada' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''
[System.IO.File]::WriteAllText($ruta, "esto no es json`n")
Comp 'basura sin hora, callada (no revienta)' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''
# la ultima linea a medias es EL caso: Nova apagada justo mientras escribia. Si solo se
# mirase la ultima, este aviso se quedaria mudo para siempre y justo aqui hace falta.
PonUso 4 '{"id":"y","hora":"2026-09-1'
Comp 'ultima linea partida: usa la anterior' ((Get-AvisoSinUso $ruta $hoy) -match 'Llevo 4 dias') ''
# y una hora del futuro (reloj tocado) no puede inventarse dias
PonUso -3
Comp 'una hora del futuro no inventa nada' ((Get-AvisoSinUso $ruta $hoy) -eq '') ''

Write-Host '  -- y que el vigilante lo use de verdad --'
Comp 'Watch-Entorno lo pregunta' ($txtFuente -match '\$txtU = Get-AvisoSinUso') ''
Comp 'y avisa como mucho una vez al dia' ($txtFuente -match "'sin-uso' \`$txtU 'medio' 1440") ''
Comp 'y no relee el fichero cada 30 s' ($txtFuente -match 'sinUsoMirado.*TotalMinutes -ge 30') ''

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
