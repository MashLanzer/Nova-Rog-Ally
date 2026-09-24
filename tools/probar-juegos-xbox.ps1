# D1, 2a parte (21/09): que Nova pueda ABRIR los juegos que no son de Steam.
#
# Hasta hoy la biblioteca ERA Steam: si un juego no tenia appmanifest, para Nova no
# existia. braya juega a Roblox con su novia -es de Game Pass, vive en C:\XboxGames- y no
# podia ni abrirlo, ni cerrarlo, ni preguntar por el.
#
# Y LO QUE MAS SE PRUEBA AQUI es que abrir un juego siga siendo una orden VIGILADA: abrir
# uno mientras juegas a otra cosa casi nunca es lo que pediste (el 11/09 un ruido abrio
# SILENT BREATH en mitad de una partida), asi que se pregunta antes. Esa vigilancia
# colgaba de un -match contra 'steam://rungameid', o sea que un juego que no fuera de
# Steam se habria abierto de golpe y sin poder deshacerlo.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA APRENDIDA SIETE VECES, la septima hoy mismo con este archivo: TODA funcion que se
# llame aqui tiene que estar en esta lista. Me deje ConvertTo-Plain, que ConvertTo-Juego
# llama por dentro, y Get-JuegosXbox devolvio CERO juegos sin una sola queja: el catch se
# comio la excepcion. Parecia un fallo del codigo y era un fallo de la prueba.
foreach ($fn in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-NombreJuegoLimpio', 'Get-JuegosXbox', 'New-AbrirJuego', 'Get-JuegosSteam')) {
    # la llave de cierre va DOBLE: esto es una cadena de formato, y '}' suelta la rompe
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\r\n].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
function Log($t) { }

Write-Host ''
Write-Host '-- lo que hay de verdad en esta consola --'
$jx = @(Get-JuegosXbox)
# LA PRIMERA LLAMADA NO SIRVE PARA MEDIR: son 544 ms de JIT y disco frio frente a 62 de
# las siguientes (medido hoy, seis seguidas). Lo que importa es lo que cuesta EN MARCHA,
# que es como corre: esto se relee cada minuto. Get-JuegosSteam, al lado, cuesta 67 ms.
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$null = @(Get-JuegosXbox)
$ms = $sw.ElapsedMilliseconds
foreach ($j in $jx) { Write-Host ("       {0,-22} ultimo={1}" -f $j.nombre, $j.ultimo) }
Comp 'encuentra los juegos de Game Pass' ($jx.Count -ge 1) "$($jx.Count) juegos"
Comp 'y Roblox esta entre ellos' (@($jx | Where-Object { $_.nombre -eq 'Roblox' }).Count -eq 1)
Comp 'GameSave no es un juego (no tiene lanzador)' (@($jx | Where-Object { $_.nombre -eq 'GameSave' }).Count -eq 0)
# la carpeta se llama 'Minecraft Launcher'; hablando se dice Minecraft, y tiene que
# decirse IGUAL aqui que en Get-JuegoEnPrimerPlano o el tiempo de juego no cuadra
Comp 'y Minecraft no se llama Minecraft Launcher' (@($jx | Where-Object { $_.nombre -eq 'Minecraft' }).Count -eq 1) `
    (@($jx | ForEach-Object { $_.nombre }) -join ', ')
Comp 'y en marcha cuesta como leer la biblioteca de Steam' ($ms -lt 200) "$ms ms"

Write-Host ''
Write-Host '-- la microSD que no esta puesta (encontrado midiendo esto, 21/09) --'
# braya tiene declarada E:\SteamLibrary, de una tarjeta que hoy no esta. Join-Path
# resuelve la unidad y LANZA DriveNotFoundException; con $ErrorActionPreference = Stop eso
# saltaba al catch de Get-JuegosSteam y se dejaban de leer las bibliotecas que vinieran
# detras. Hoy va la ultima y no se pierde nada, pero Steam reescribe libraryfolders.vdf
# cada vez que tocas una biblioteca: el dia que quedara la primera, cero juegos y callada.
$ErrorActionPreference = 'Stop'
$lanza = $false
try { $null = Join-Path 'E:\SteamLibrary' 'steamapps' } catch { $lanza = $true }
if (-not $lanza) {
    Write-Host '  --   aqui SI existe una unidad E:, este caso no se puede medir en esta maquina' -ForegroundColor DarkGray
} else {
    Comp 'Join-Path con una unidad ausente lanza (por eso no se usa)' $lanza
    $sinLanzar = $true
    try { $null = ('E:\SteamLibrary' -replace '/', '\').TrimEnd('\') + '\steamapps' } catch { $sinLanzar = $false }
    Comp 'pegar las cadenas no lanza' $sinLanzar
    $tp = $null
    try { $tp = Test-Path -LiteralPath 'E:\SteamLibrary\steamapps' } catch { $tp = 'LANZA' }
    Comp 'y Test-Path la descarta sin lanzar' ($tp -eq $false) "devuelve [$tp]"
}
# sin expresion regular: aqui hay barras invertidas y comillas por todas partes, y
# escaparlas dos veces es justo como se cuela un patron que no casa con nada
Comp 'Get-JuegosSteam ya no usa Join-Path para la biblioteca' `
    ($fuente.Contains(".TrimEnd('\') + '\steamapps'") -and -not $fuente.Contains("Join-Path (`$lib -replace"))
# y que siga leyendo los juegos de verdad, que es lo que no se puede romper
Comp 'y sigue viendo la biblioteca de esta consola' (@(Get-JuegosSteam).Count -ge 5) "$(@(Get-JuegosSteam).Count) juegos"

Write-Host ''
Write-Host '-- cada juego trae lo que el resto del programa le pide --'
$rb = @($jx | Where-Object { $_.nombre -eq 'Roblox' })[0]
if ($rb) {
    foreach ($k in @('id', 'nombre', 'plano', 'lanzar', 'estado', 'bajando', 'descargado', 'total', 'tamano', 'ultimo', 'dir')) {
        Comp ("trae el campo $k") ($rb.ContainsKey($k)) $(if (-not $rb.ContainsKey($k)) { 'NO ESTA' } else { '' })
    }
    Comp 'el lanzador existe en el disco' (Test-Path -LiteralPath ([string]$rb.lanzar)) ([string]$rb.lanzar)
    Comp 'no se esta descargando' (-not $rb.bajando)
    Comp 'y su nombre plano sirve para buscarlo hablando' ([string]$rb.plano -match 'roblox') "plano='$($rb.plano)'"
} else {
    Comp 'Roblox esta instalado para poder probar el resto' $false
}

Write-Host ''
Write-Host '-- la accion de abrir: la de Steam no cambia, la nueva se anade --'
$aS = @(New-AbrirJuego @{ id = '1245620'; nombre = 'ELDEN RING' })
Comp 'un juego de Steam sigue abriendose por steam://' ([string]$aS[0].target -eq 'steam://rungameid/1245620')
Comp 'y su texto sigue diciendo "en Steam"' ([string]$aS[0].desc -eq 'abrir ELDEN RING en Steam')
$aX = @(New-AbrirJuego $rb)
Comp 'Roblox se abre por su lanzador' ([string]$aX[0].target -like '*gamelaunchhelper.exe')
Comp 'y NO por steam://' ([string]$aX[0].target -notmatch 'steam://')
Comp 'su texto no miente diciendo Steam' ([string]$aX[0].desc -eq 'abrir Roblox')

Write-Host ''
Write-Host '-- LO QUE IMPORTA: los dos siguen siendo "un juego" para quien ejecuta --'
Comp 'el de Steam lleva la marca' ([bool]$aS[0].esJuego)
Comp 'y el de Game Pass tambien' ([bool]$aX[0].esJuego)
# asi se lee en la rama 'app' de Invoke-Accion, tal cual
foreach ($par in @(@{ a = $aS[0]; q = 'Steam' }, @{ a = $aX[0]; q = 'Game Pass' })) {
    $esJuego = ([bool]$par.a.esJuego -or ($par.a.target -match 'steam://rungameid'))
    Comp ("con $($par.q) delante, preguntaria antes de abrir") $esJuego
}
Comp 'y la marca se lee del campo, no solo del target' ($fuente -match '\$esJuego = \(\[bool\]\$a\.esJuego -or')
$aApp = @{ kind = 'app'; target = 'msedge.exe'; desc = 'abrir navegador' }
Comp 'una app normal NO es un juego' (-not ([bool]$aApp.esJuego -or ($aApp.target -match 'steam://rungameid')))

Write-Host ''
Write-Host '-- y las dos bibliotecas van juntas --'
Comp 'Update-Juegos lee Steam y Game Pass' ($fuente -match '\$script:Juegos = @\(Get-JuegosSteam\) \+ @\(Get-JuegosXbox\)')
Comp 'y el arranque tambien' ((([regex]::Matches($fuente, '@\(Get-JuegosSteam\) \+ @\(Get-JuegosXbox\)')).Count) -ge 2)
Comp 'ya no queda ningun steam://rungameid escrito a mano en Resolve-Target' `
    (-not ($fuente -match "(?m)^\s+if \(\`$j\) \{ return @\(@\{ kind = 'app'; target = `"steam://rungameid"))

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  los juegos de Game Pass se abren, y abrirlos sigue estando vigilado'
exit 0
