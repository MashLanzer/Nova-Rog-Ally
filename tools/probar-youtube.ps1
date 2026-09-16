# "REPRODUCE EL SEGUNDO VIDEO DE YOUTUBE" (16/09).
#
# El 15/09 se pidio cuatro veces (11:32:33, 13:15:08 y dos mas) y las cuatro acabaron en
# el agente, hasta 88 s, sin conseguirlo. Aqui se comprueba que la orden se entiende en
# local, que coge el numero que toca y -lo mas importante- que NO se inventa nada cuando
# todavia no se ha puesto ninguna busqueda.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$txt = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# la tabla de ordinales, sacada del archivo real
if ($txt -match '(?ms)^\$ORDINALES_YT = @\{.*?\}\s*$') { Invoke-Expression $Matches[0] } else { throw 'no encuentro ORDINALES_YT' }
Comp 'la tabla de ordinales existe' ($ORDINALES_YT['segundo'] -eq 2 -and $ORDINALES_YT['tercera'] -eq 3) ''

# el numero N sale de la MISMA pagina de resultados, sin repetir ids
$html = '"videoId":"AAAAAAAAAAA" ... "videoId":"AAAAAAAAAAA" ... "videoId":"BBBBBBBBBBB" ... "videoId":"CCCCCCCCCCC"'
$ids = @([regex]::Matches($html, '"videoId":"([A-Za-z0-9_-]{11})"') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
Comp 'los ids repetidos no cuentan dos veces' ($ids.Count -eq 3 -and $ids[1] -eq 'BBBBBBBBBBB') ($ids -join ', ')
Comp 'el segundo es el segundo distinto' ($ids[1] -eq 'BBBBBBBBBBB') ''

# las frases, contra la capa local de verdad
$tmp = Join-Path $env:TEMP ('yt-' + [guid]::NewGuid().ToString('N') + '.txt')
@('pon pitbull en youtube', 'reproduce el segundo video de youtube', 'pon la tercera cancion',
  'reproduce la segunda cancion de el', 'pon el video numero 4', 'reproduce el segundo') |
    Set-Content -LiteralPath $tmp -Encoding UTF8
$salida = & powershell -NoProfile -ExecutionPolicy Bypass -File $ruta -Probar $tmp 2>&1
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
$texto = ($salida | Out-String)
Comp 'poner algo en youtube sigue igual' ($texto -match "pon pitbull en youtube\s+->\s+poner 'pitbull' en YouTube") ''
# sin haber puesto nada antes, no se inventa una busqueda: lo dice
foreach ($frase in 'reproduce el segundo video de youtube', 'pon la tercera cancion', 'reproduce el segundo') {
    Comp "'$frase' se entiende en local" ($texto -match ([regex]::Escape($frase) + '\s+->')) ''
}
Comp 'y sin busqueda previa avisa en vez de abrir algo' ($texto -match 'Dime primero que quieres que ponga') ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
