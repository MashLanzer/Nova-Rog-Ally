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
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
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
Invoke-Expression (Traer 'Get-LlamadaEnJuego')

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
    if ((Get-LlamadaEnJuego $marca 'It Takes Two') -eq 'primera') { $mostradas++ }
}
Comp 'cinco llamadas jugando: se explica UNA vez' ($mostradas -eq 1) "$mostradas de 5"
Comp 'y la marca queda consumida' (-not (Test-Path -LiteralPath $marca)) 'o dispararia luego sola'

Write-Host ''
Write-Host '-- y las partidas siguientes --'
Llama
Comp 'en la misma partida, ya no insiste' ((Get-LlamadaEnJuego $marca 'It Takes Two') -eq 'otra') 'pero SI vibra: te contesta'
Llama
Comp 'al cambiar de juego, vuelve a explicarse' ((Get-LlamadaEnJuego $marca 'Hades') -eq 'primera') 'otra partida, otra vez'
Llama
Comp 'y en esa tampoco insiste' ((Get-LlamadaEnJuego $marca 'Hades') -eq 'otra')

Write-Host ''
Write-Host '-- sin juego delante no tiene nada que explicar --'
$script:llamadaJuegoDicha = ''
Llama
Comp 'sin juego, callada' ((Get-LlamadaEnJuego $marca '') -eq '') 'ahi la palabra SI vale'
Comp 'pero consume la marca igual' (-not (Test-Path -LiteralPath $marca)) 'una llamada vieja no vale para luego'
Comp 'sin marca no dice nada' ((Get-LlamadaEnJuego $marca 'It Takes Two') -eq '') 'no se lo inventa'

Write-Host ''
Write-Host '-- y no habla, ni ejecuta, ni enciende ningun modo --'
# El bloque entero del enganche, contando llaves y no caracteres (ver la leccion de
# tools\probar-confirmaciones.ps1: una ventana de N caracteres alcanza el bloque de al lado
# y el banco pasa en verde con el codigo roto).
$ini2 = $fuente.IndexOf('$llamJ = Get-LlamadaEnJuego')
$cuerpo2 = if ($ini2 -ge 0) { $fuente.Substring($ini2, [Math]::Min(1400, $fuente.Length - $ini2)) } else { '' }
$ini = $fuente.IndexOf('if ($llamJ) {')
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
# LO QUE DE VERDAD LLEGA JUGANDO (22/09, visto en vivo media hora despues de estrenarlo):
# braya siguio llamandola SIETE veces despues de la tarjeta -22:18, 22:19, 22:25, 22:26,
# 22:32 'nova nova', 22:33-. A pantalla completa la capsula no se ve. El mando si.
Comp 'y SIEMPRE contesta con el mando' ($cuerpo -match 'Start-Vibracion') 'a pantalla completa es lo unico que llega'
# COMILLAS SIMPLES: entre dobles, PowerShell se come el $ de $llamJ antes de que llegue al
# regex, y el patron buscaba "if ( -eq 'primera')". Salia rojo con el codigo bien.
Comp 'la vibracion va fuera del "una vez por partida"' ($cuerpo -match '(?s)Start-Vibracion.*?\$llamJ -eq .primera.') 'cada llamada merece respuesta'
# Y SI LE HAS MANDADO CALLAR, NI EL MANDO (22/09). La marca la escribe el worker cada vez
# que oye algo parecido a 'nova' jugando, y ahi entra sin pasar guardas: lo que suena es el
# juego tanto como braya. Vibrarle mientras esta en sordina seria justo lo que pidio evitar.
Comp 'en sordina no vibra ni ensena nada' ($cuerpo2 -match 'sordinaHasta -gt \$sw.ElapsedMilliseconds') 'le mandaste callar'
Comp 'y es corta y floja, que no tape el juego' ($cuerpo -match 'Start-Vibracion @\(70, 90, 70\) 16000')
Comp 'y NO se dice en voz alta' (-not ($cuerpo -match '(?m)\bSay\b')) 'jugando no se interrumpe'
# 'Start-' a secas casaba con Start-Vibracion, que no ejecuta nada: se nombran las de verdad.
Comp 'no ejecuta ninguna orden' (-not ($cuerpo -match 'Invoke-FastCommand|Process-Texto|Invoke-Reglas|Start-Receta|Start-Process|Invoke-Correo|Start-Confirmacion'))
Comp 'y queda contado para poder medirlo' ($cuerpo -match "Add-Estadistica 'llamada-en-juego'")

Write-Host ''
Write-Host '-- y el worker deja la marca donde toca --'
Comp 'la escucha escribe la marca al ignorar por juego' ($oido -match 'MARCA_LLAMADA_JUEGO\)') ''
# POR LINEAS, NO POR CARACTERES. Esto media 400 caracteres entre el aviso y la escritura de
# la marca, y con 40 espacios de sangrado por linea eso son seis lineas escasas: un
# comentario nuevo en medio lo puso en rojo con el codigo bien. Lo que importa es que la
# marca se escriba DENTRO de esa rama, no a cuantos caracteres.
$lineasOido = @($oido -split "`r?`n")
$iIgn = -1
for ($q = 0; $q -lt $lineasOido.Count; $q++) { if ($lineasOido[$q] -match 'ignorado: estas jugando') { $iIgn = $q; break } }
$traIgn = if ($iIgn -ge 0) { ($lineasOido[$iIgn..([Math]::Min($iIgn + 12, $lineasOido.Count - 1))]) -join "`n" } else { '' }
Comp 'y solo cuando de verdad ignora por el juego' ($traIgn -match 'escribir\(MARCA_LLAMADA_JUEGO') 'dentro de esa misma rama'
Comp 'el nombre del fichero cuadra en los dos lados' (($oido -match 'llamada-en-juego\.txt') -and ($fuente -match 'llamada-en-juego\.txt')) 'si no, nadie lee lo que el otro escribe'

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  jugando te ignora, pero ya no en silencio'
exit 0
