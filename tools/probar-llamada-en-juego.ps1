# QUE NO TE IGNORE EN SILENCIO MIENTRAS JUEGAS (22/09 por la noche).
#
# Con un juego delante, la palabra de activacion no vale: solo el boton. Eso viene del
# 11/09 -Nova se activaba sola jugando y abria cosas- y NO se toca. Lo que si era un fallo
# es que lo hacia EN SILENCIO: el 22/09 de 21:00 a 21:06, braya dijo "nova" cinco veces
# jugando a It Takes Two y no recibio nada. Ni una palabra, ni un parpadeo. Desde fuera eso
# es exactamente igual que estar rota, que es la misma leccion que dejo el aviso del ruido
# doce horas antes.
#
# Lo que este banco vigila:
#   - que se ensene UNA vez por partida y no una por llamada (si no, seria el ventilador
#     otra vez, y encima en mitad de un juego);
#   - que cambiar de juego lo rearme (en la partida siguiente vuelve a merecer explicarse);
#   - que sin juego delante no diga nada (ahi la palabra SI vale: seria mentira);
#   - que se consuma la marca aunque no se ensene, o se quedaria disparando en la siguiente
#     partida por una llamada de hace horas;
#   - y que NO hable ni ejecute nada: jugando no se interrumpe, y la llamada pudo ser un
#     falso positivo del detector, que es justo por lo que existe el modo solo-boton.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA DEL BANCO: la funcion se trae del fichero de verdad, nunca se copia aqui.
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre en assistant.ps1"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Test-LlamadaEnJuego')

$base = Join-Path ([System.IO.Path]::GetTempPath()) ('llamada-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$marca = Join-Path $base 'llamada-en-juego.txt'
function Llama { [System.IO.File]::WriteAllText($marca, '123456') }

Write-Host ''
Write-Host '-- la tarde del 22: cinco llamadas en la misma partida --'
$script:llamadaJuegoDicha = ''
$mostradas = 0
for ($i = 0; $i -lt 5; $i++) {
    Llama
    if (Test-LlamadaEnJuego $marca 'It Takes Two') { $mostradas++ }
}
Comp 'cinco llamadas jugando: se explica UNA vez' ($mostradas -eq 1) "$mostradas de 5"
Comp 'y la marca queda consumida' (-not (Test-Path -LiteralPath $marca)) 'o dispararia luego sola'

Write-Host ''
Write-Host '-- y las partidas siguientes --'
Llama
Comp 'en la misma partida, ya no insiste' (-not (Test-LlamadaEnJuego $marca 'It Takes Two'))
Llama
Comp 'al cambiar de juego, vuelve a explicarse' (Test-LlamadaEnJuego $marca 'Hades') 'otra partida, otra vez'
Llama
Comp 'y en esa tampoco insiste' (-not (Test-LlamadaEnJuego $marca 'Hades'))

Write-Host ''
Write-Host '-- sin juego delante no tiene nada que explicar --'
$script:llamadaJuegoDicha = ''
Llama
Comp 'sin juego, callada' (-not (Test-LlamadaEnJuego $marca '')) 'ahi la palabra SI vale'
Comp 'pero consume la marca igual' (-not (Test-Path -LiteralPath $marca)) 'una llamada vieja no vale para luego'
Comp 'sin marca no dice nada' (-not (Test-LlamadaEnJuego $marca 'It Takes Two')) 'no se lo inventa'

Write-Host ''
Write-Host '-- y no habla, ni ejecuta, ni enciende ningun modo --'
# El bloque entero del enganche, contando llaves y no caracteres (ver la leccion de
# tools\probar-confirmaciones.ps1: una ventana de N caracteres alcanza el bloque de al lado
# y el banco pasa en verde con el codigo roto).
$ini = $fuente.IndexOf('if (Test-LlamadaEnJuego')
$cuerpo = ''
if ($ini -ge 0) {
    $j = $fuente.IndexOf('{', $ini); $prof = 0
    for ($k = $j; $k -lt $fuente.Length; $k++) {
        if ($fuente[$k] -eq '{') { $prof++ }
        elseif ($fuente[$k] -eq '}') { $prof--; if ($prof -eq 0) { $cuerpo = $fuente.Substring($j, $k - $j + 1); break } }
    }
}
Comp 'el enganche existe y se delimita' ($cuerpo.Length -gt 0) "$($cuerpo.Length) caracteres"
Comp 'se VE en la capsula' ($cuerpo -match 'Show-Popup')
Comp 'y NO se dice en voz alta' (-not ($cuerpo -match '(?m)\bSay\b')) 'jugando no se interrumpe'
Comp 'no ejecuta ninguna orden' (-not ($cuerpo -match 'Invoke-FastCommand|Process-Texto|Invoke-Reglas|Start-'))
Comp 'y queda contado para poder medirlo' ($cuerpo -match "Add-Estadistica 'llamada-en-juego'")

Write-Host ''
Write-Host '-- y el worker deja la marca donde toca --'
Comp 'la escucha escribe la marca al ignorar por juego' ($oido -match 'MARCA_LLAMADA_JUEGO\)') ''
Comp 'y solo cuando de verdad ignora por el juego' ($oido -match "(?s)ignorado: estas jugando.{0,400}escribir\(MARCA_LLAMADA_JUEGO")
Comp 'el nombre del fichero cuadra en los dos lados' (($oido -match 'llamada-en-juego\.txt') -and ($fuente -match 'llamada-en-juego\.txt')) 'si no, nadie lee lo que el otro escribe'

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  jugando te ignora, pero ya no en silencio'
exit 0
