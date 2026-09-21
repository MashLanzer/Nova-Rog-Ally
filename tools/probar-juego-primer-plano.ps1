# D1 (21/09): que Nova sepa que Roblox es un juego, y todo lo que no es Steam.
#
# EL CASO REAL: la noche del 20 al 21/09 braya jugo DOS HORAS a Roblox -de 22:47 a 00:58,
# con su novia- y para Nova no estaba jugando. Get-JuegoEnPrimerPlano solo miraba si la
# ruta del proceso llevaba "steamapps\common", y su Roblox es el de Game Pass, que vive en
# C:\XboxGames\Roblox\Content\RobloxPlayerBeta.exe. Con $script:juegoActivo en $null se
# quedaron fuera el tiempo de juego, el avatar de la capsula, el freno de los avisos, el
# limite de tiempo, la nota semanal y el "braya esta jugando a X" del prompt del cerebro,
# que es lo que le pide contestar en UNA frase. Sin eso, se enrollaba.
#
# LO QUE MAS IMPORTA AQUI NO ES QUE RECONOZCA JUEGOS: es que NO se invente ninguno. Si
# esto da un falso positivo, Nova cree que estas jugando cuando no lo estas y se calla
# avisos que si querias. Por eso la mitad de los casos son controles.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA APRENDIDA SEIS VECES: todo lo que se llame aqui tiene que venir del archivo de
# verdad, o esto pasa en verde sin probar nada. Las tres listas y la funcion, tal cual.
foreach ($v in @('CARPETAS_JUEGO', 'CARPETA_NO_JUEGO', 'EXES_JUEGO')) {
    $m = [regex]::Match($fuente, ('(?ms)^\$' + $v + ' = @[({].*?^[)}]'))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro $' + $v + ' en assistant.ps1'); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
$mf = [regex]::Match($fuente, '(?ms)^function Get-JuegoEnPrimerPlano \{.*?^\}')
if (-not $mf.Success) { Write-Host '  MAL  no encuentro Get-JuegoEnPrimerPlano'; exit 1 }
. ([scriptblock]::Create($mf.Value))
Comp 'las tres listas y la funcion salen del archivo de verdad' ($CARPETAS_JUEGO.Count -ge 8 -and $EXES_JUEGO.Count -ge 2)

# la funcion llama a estas dos: aqui se fingen para poder darle rutas a mano
$script:rutaFalsa = ''
$script:nombreFalso = ''
function Get-ProcesoEnPrimerPlano {
    if (-not $script:rutaFalsa -and -not $script:nombreFalso) { return $null }
    $o = New-Object PSObject
    $o | Add-Member NoteProperty Path $script:rutaFalsa
    $o | Add-Member NoteProperty Name $script:nombreFalso
    return $o
}
function Find-Juego($n) { return $null }   # nada esta en la biblioteca de Steam

function Mira([string]$ruta, [string]$nombre = 'algo') {
    $script:rutaFalsa = $ruta
    $script:nombreFalso = $nombre
    return Get-JuegoEnPrimerPlano
}

Write-Host ''
Write-Host '-- SU Roblox, la ruta de verdad de esta consola --'
Comp 'XboxGames\Roblox\Content\RobloxPlayerBeta.exe es Roblox' `
    ((Mira 'C:\XboxGames\Roblox\Content\RobloxPlayerBeta.exe' 'RobloxPlayerBeta') -eq 'Roblox')
Comp 'y su lanzador tambien' `
    ((Mira 'C:\XboxGames\Roblox\Content\gamelaunchhelper.exe' 'gamelaunchhelper') -eq 'Roblox')
Comp 'si no se puede leer la ruta, por el nombre del proceso' `
    ((Mira '' 'RobloxPlayerBeta') -eq 'Roblox')

Write-Host ''
Write-Host '-- lo que ya funcionaba: Steam, que no se puede romper --'
Comp 'ELDEN RING' ((Mira 'D:\SteamLibrary\steamapps\common\ELDEN RING\Game\eldenring.exe' 'eldenring') -eq 'ELDEN RING')
Comp 'BlackMythWukong' ((Mira 'C:\Program Files (x86)\Steam\steamapps\common\BlackMythWukong\b1.exe' 'b1') -eq 'BlackMythWukong')

Write-Host ''
Write-Host '-- las demas tiendas --'
foreach ($c in @(
        @{ r = 'C:\XboxGames\Minecraft Launcher\Content\Minecraft.exe'; n = 'Minecraft'; e = 'Minecraft Launcher' },
        @{ r = 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\x.exe'; n = 'x'; e = 'Fortnite' },
        @{ r = 'D:\GOG Galaxy\Games\Cyberpunk 2077\bin\x64\game.exe'; n = 'game'; e = 'Cyberpunk 2077' },
        @{ r = 'C:\Ubisoft\Ubisoft Game Launcher\games\Far Cry 6\bin\fc.exe'; n = 'fc'; e = 'Far Cry 6' },
        @{ r = 'C:\Program Files (x86)\Origin Games\Titanfall2\x.exe'; n = 'x'; e = 'Titanfall2' },
        @{ r = 'C:\Riot Games\VALORANT\live\v.exe'; n = 'v'; e = 'VALORANT' },
        @{ r = 'C:\Users\braya\AppData\Roaming\itch\apps\Celeste\Celeste.exe'; n = 'Celeste'; e = 'Celeste' },
        @{ r = 'C:\Users\braya\AppData\Local\Roblox\Versions\version-abc\RobloxPlayerBeta.exe'; n = 'RobloxPlayerBeta'; e = 'Roblox' },
        @{ r = 'C:\Users\braya\AppData\Roaming\.minecraft\runtime\bin\javaw.exe'; n = 'javaw'; e = 'minecraft' }   # la carpeta es .minecraft, sin mayuscula
    )) {
    $v = Mira $c.r $c.n
    Comp ($c.e) ($v -eq $c.e) $(if ($v -ne $c.e) { "sale [$v]" } else { '' })
}

Write-Host ''
Write-Host '-- CONTROLES: esto NO es jugar, y creerlo le costaria avisos --'
foreach ($c in @(
        @{ r = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'; n = 'msedge'; q = 'el navegador a pantalla completa' },
        @{ r = 'C:\Windows\explorer.exe'; n = 'explorer'; q = 'el explorador' },
        @{ r = 'C:\Program Files (x86)\Steam\steam.exe'; n = 'steam'; q = 'Steam en si, no un juego' },
        @{ r = 'C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'; n = 'EpicGamesLauncher'; q = 'el lanzador de Epic' },
        @{ r = 'D:\GOG Galaxy\GalaxyClient.exe'; n = 'GalaxyClient'; q = 'el cliente de GOG' },
        @{ r = 'C:\XboxGames\GameSave\algo.exe'; n = 'algo'; q = 'la carpeta de partidas guardadas' },
        @{ r = 'C:\Program Files\Epic Games\Fortnite\Engine\Extras\Redist\_CommonRedist\x.exe'; n = 'x'; q = 'un redistribuible' },
        @{ r = 'C:\Users\braya\Documents\voice-ctrl\nova_ui.exe'; n = 'nova_ui'; q = 'la propia Nova' },
        @{ r = 'C:\Program Files\WindowsApps\Microsoft.WindowsCalculator_x\Calculator.exe'; n = 'Calculator'; q = 'una app de la Store que no es juego' },
        @{ r = 'C:\juegos\mi steamapps commonero\x.exe'; n = 'x'; q = 'una carpeta que solo se PARECE a steamapps' }
    )) {
    $v = Mira $c.r $c.n
    Comp $c.q ($null -eq $v -or '' -eq $v) $(if ($v) { "dice que juegas a [$v]" } else { '' })
}
Comp 'sin ventana en primer plano no hay juego' ($null -eq (Mira '' ''))

Write-Host ''
Write-Host '-- y que el nombre valga para hablar: es lo que se dice en voz alta --'
$n = Mira 'C:\XboxGames\Roblox\Content\RobloxPlayerBeta.exe' 'RobloxPlayerBeta'
Comp 'no lleva barras ni punto exe' ($n -notmatch '[\\/.]') "dice [$n]"
Comp 'y no es el nombre del ejecutable' ($n -ne 'RobloxPlayerBeta') "dice [$n]"

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  Nova ya sabe que Roblox es un juego, y sigue sin inventarse ninguno'
exit 0
