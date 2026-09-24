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
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
# El arbol, para poder sacar funciones enteras en vez de buscarlas con un regex (24/09).
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)

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
# Get-JuegoEnPrimerPlano llama a Get-NombreJuegoLimpio: las DOS, o esto prueba humo
$ml = [regex]::Match($fuente, '(?ms)^function Get-NombreJuegoLimpio[ (].*?^\}')
if (-not $ml.Success) { Write-Host '  MAL  no encuentro Get-NombreJuegoLimpio'; exit 1 }
. ([scriptblock]::Create($ml.Value))
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
        @{ r = 'C:\XboxGames\Minecraft Launcher\Content\Minecraft.exe'; n = 'Minecraft'; e = 'Minecraft' }   # 'Launcher' no se dice hablando,
        @{ r = 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\x.exe'; n = 'x'; e = 'Fortnite' },
        @{ r = 'D:\GOG Galaxy\Games\Cyberpunk 2077\bin\x64\game.exe'; n = 'game'; e = 'Cyberpunk 2077' },
        @{ r = 'C:\Ubisoft\Ubisoft Game Launcher\games\Far Cry 6\bin\fc.exe'; n = 'fc'; e = 'Far Cry 6' },
        @{ r = 'C:\Program Files (x86)\Origin Games\Titanfall2\x.exe'; n = 'x'; e = 'Titanfall2' },
        @{ r = 'C:\Riot Games\VALORANT\live\v.exe'; n = 'v'; e = 'VALORANT' },
        @{ r = 'C:\Users\braya\AppData\Roaming\itch\apps\Celeste\Celeste.exe'; n = 'Celeste'; e = 'Celeste' },
        @{ r = 'C:\Users\braya\AppData\Local\Roblox\Versions\version-abc\RobloxPlayerBeta.exe'; n = 'RobloxPlayerBeta'; e = 'Roblox' },
        @{ r = 'C:\Users\braya\AppData\Roaming\.minecraft\runtime\bin\javaw.exe'; n = 'javaw'; e = 'minecraft' }   # la carpeta de datos es .minecraft, sin mayuscula
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

Write-Host ''
Write-Host '-- Y NO SE QUEDA CIEGA CON EL JUEGO EN PANTALLA COMPLETA (24/09, idea 8) --'
# LO QUE PASABA, medido contra el registro de Steam -que sobrevive a las muertes de Nova-:
# el 20/09 ELDEN RING corrio de 18:59:53 a 19:07:57 y Nova lo vio ONCE SEGUNDOS. A las
# 19:01:22 contesto 'ELDEN RING no esta abierto', y a las 19:02:27 braya le dijo al
# microfono -esta en el registro-: 'Elden Ring si esta abierto... el juego sigue abierto'.
# Se quedo ciega 7 min 49 s, unas 47 vueltas del bucle. Lo mismo el 19/09 (13 s de 272) y
# el 18/09 (11 s de 185).
# LA CAUSA: Get-ProcesoEnPrimerPlano buscaba un proceso cuyo MainWindowHandle fuera
# EXACTAMENTE la ventana de delante, y en pantalla completa exclusiva eso no casa.
$gp = ($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $x.Name -eq 'Get-ProcesoEnPrimerPlano' }, $true)).Extent.Text
$gpSin = (($gp -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'resuelve el PID de la ventana de delante' ($gpSin -match 'Get-PidDeVentana \$h') ''
Comp 'y pide UN solo proceso por ese PID' ($gpSin -match 'Get-Process -Id \$pidFg') 'de 500-740 ms a 20 ms'
# EL CAMINO NUEVO VA PRIMERO: si fuera el respaldo, seguiria recorriendo los 200 procesos
# antes y la ceguera no se arreglaria.
$iPid = $gpSin.IndexOf('Get-PidDeVentana')
$iBarrido = $gpSin.IndexOf('foreach ($p in (Get-Process')
Comp 'y ese camino va ANTES del barrido de siempre' (($iPid -ge 0) -and ($iBarrido -ge 0) -and ($iPid -lt $iBarrido)) 'si no, la ceguera sigue igual'
# PERO EL BARRIDO NO SE QUITA: si el PID no se puede resolver o el proceso muere entre una
# linea y otra, lo de siempre sigue de respaldo.
Comp 'el barrido de siempre sigue de respaldo' ($iBarrido -ge 0) 'no se quita, se pospone'
Comp 'y sin ventana delante sigue devolviendo nada' ($gpSin -match '\[IntPtr\]::Zero.{0,40}return \$null') ''
# Y LO QUE NO SE TOCA, que es lo que de verdad decide si algo es un juego: esta funcion solo
# devuelve el PROCESO. Si aqui se colara un filtro, se estaria decidiendo en dos sitios.
Comp 'no decide si es un juego' (($gpSin -notmatch 'CARPETAS_JUEGO') -and ($gpSin -notmatch 'EXES_JUEGO') -and ($gpSin -notmatch 'CARPETA_NO_JUEGO')) 'eso lo hace Get-JuegoEnPrimerPlano'
Comp 'ni apunta tiempo de juego' ($gpSin -notmatch 'Add-TiempoJuego') ''
# y el filtro de verdad sigue entero donde estaba
$gj = ($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $x.Name -eq 'Get-JuegoEnPrimerPlano' }, $true)).Extent.Text
foreach ($guarda in @('CARPETAS_JUEGO', 'EXES_JUEGO', 'CARPETA_NO_JUEGO')) {
    Comp ('el filtro sigue mirando ' + $guarda) ($gj -match [regex]::Escape($guarda)) ''
}
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  Nova ya sabe que Roblox es un juego, y sigue sin inventarse ninguno'
exit 0
