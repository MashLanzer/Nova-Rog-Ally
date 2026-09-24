# "INSTALA IT TAKES TWO EN STEAM" (16/09).
#
# El 15/09 a las 14:26 esta orden se fue al agente, tardo 60 s y no lo consiguio. La
# biblioteca de Nova son los appmanifest del disco: SOLO los juegos instalados, asi que
# de uno que no lo esta no hay appid para un steam://install. Lo que si se puede hacer
# -y en un segundo- es abrir su ficha en la tienda; y si ya lo tienes, decirlo.
#
# Aqui se comprueba contra la capa local de verdad, con la biblioteca real de la maquina.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# EL JUEGO INSTALADO SE SACA DE LA BIBLIOTECA, no se escribe a mano (revision del 23/09).
# Aqui ponia "it takes two" con el comentario "SI esta instalado en esta maquina"; braya lo
# desinstalo y el banco se puso rojo con el codigo bien. Lo que se prueba es la REGLA -si lo
# tienes, te lo dice-, y para eso da igual cual sea.
$ast0 = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer0([string]$n) {
    $fn = $ast0.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
$LogDir = $raiz
function Log([string]$m) { }
foreach ($fn0 in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-JuegosSteam')) { Invoke-Expression (Traer0 $fn0) }
$miosInst = @(Get-JuegosSteam | Where-Object { $_.nombre -and $_.nombre -notmatch '(?i)redistrib|wallpaper' } |
              Sort-Object -Property { $_.nombre.Length })
if ($miosInst.Count -eq 0) { Write-Host '  (sin biblioteca de Steam: me salto el caso del juego instalado)' }
$tengo = if ($miosInst.Count) { ($miosInst[0].nombre).ToLowerInvariant() } else { '' }

$tmp = Join-Path $env:TEMP ('inst-' + [guid]::NewGuid().ToString('N') + '.txt')
@('instala en steam un juego que no tengo',
  'descarga cyberpunk 2077',
  'instala hollow knight silksong',
  'instala outlast trials',
  $(if ($tengo) { "instala $tengo en steam" } else { 'abre steam' }),
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
# uno que SI esta instalado ahora mismo: no debe mandarte a la tienda
if ($tengo) {
    $pat = 'instala ' + [regex]::Escape($tengo) + ' en steam\s+->\s+.*ya lo tienes instalado'
    Comp 'uno que ya tienes: te lo dice, no te manda a la tienda' ($salida -match $pat) $tengo
}
Comp 'abrir Steam sigue siendo abrir Steam' ($salida -match 'abre steam\s+->\s+abrir steam') ''
Comp '"instala eso" no manda nada a la tienda' ($salida -notmatch 'instala eso\s+->\s+abrir') ''

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
