# "INSTALA IT TAKES TWO EN STEAM" (16/09).
#
# El 15/09 a las 14:26 esta orden se fue al agente, tardo 60 s y no lo consiguio. La
# biblioteca de Nova son los appmanifest del disco: SOLO los juegos instalados, asi que
# de uno que no lo esta no hay appid para un steam://install. Lo que si se puede hacer
# -y en un segundo- es abrir su ficha en la tienda; y si ya lo tienes, decirlo.
#
# Aqui se comprueba contra la capa local de verdad, con la biblioteca real de la maquina.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

$tmp = Join-Path $env:TEMP ('inst-' + [guid]::NewGuid().ToString('N') + '.txt')
@('instala en steam un juego que no tengo',
  'descarga cyberpunk 2077',
  'instala hollow knight silksong',
  'instala outlast trials',
  'instala it takes two en steam',
  'abre steam',
  'instala eso') | Set-Content -LiteralPath $tmp -Encoding UTF8
$salida = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ruta -Probar $tmp 2>&1 | Out-String)
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

Comp 'un juego que no tienes: a la tienda' ($salida -match 'instala en steam un juego que no tengo\s+->\s+abrir un juego que no tengo en la tienda') ''
Comp '"descarga X" igual' ($salida -match 'descarga cyberpunk 2077\s+->\s+abrir cyberpunk 2077 en la tienda') ''
# EL PARECIDO NO VALE: con Hollow Knight instalado (pero no Silksong) y Outlast
# instalado (pero no Trials), la primera version contestaba "ya lo tienes". Son otros
# juegos: tienen que ir a la tienda.
Comp 'Silksong no es Hollow Knight: a la tienda' ($salida -match 'instala hollow knight silksong\s+->\s+abrir hollow knight silksong en la tienda') ''
Comp 'Outlast Trials no es Outlast: a la tienda' ($salida -match 'instala outlast trials\s+->\s+abrir outlast trials en la tienda') ''
# It Takes Two SI esta instalado en esta maquina: no debe mandarte a la tienda
Comp 'uno que ya tienes: te lo dice, no te manda a la tienda' ($salida -match 'instala it takes two en steam\s+->\s+.*ya lo tienes instalado') ''
Comp 'abrir Steam sigue siendo abrir Steam' ($salida -match 'abre steam\s+->\s+abrir steam') ''
Comp '"instala eso" no manda nada a la tienda' ($salida -notmatch 'instala eso\s+->\s+abrir') ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
