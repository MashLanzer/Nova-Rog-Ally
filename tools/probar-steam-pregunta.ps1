# PREGUNTARLE OTRAS COSAS A STEAM (1/10, las 14 y 15 de las 20 funciones nuevas)
#
# LO QUE ESTA SECCION DEFIENDE, y es lo unico que de verdad importa aqui: que estas preguntas NO
# PISEN la vigilancia de amigos. El canal de red de Steam es UNO ($script:steamTask) y lo usaba
# Watch-AmigoConecta, que funciona. El acuerdo es el que ya existia: una variable dice de quien es la
# respuesta que viene, lo coge quien llega primero, y NADIE recoge lo que no ha pedido. Si eso se
# rompe, la vigilancia de amigos se queda muda sin que nadie lo note.
#
# Y LAS DOS MITADES QUE NO SE PUEDEN, medidas: GetPlayerAchievements da 403 -el perfil de Steam esta
# privado- asi que no se pueden saber los logros CONSEGUIDOS; lo que si responde es el porcentaje
# global, o sea cuales son los mas faciles del juego. Eso se dice, y se dice tambien que los suyos no
# se saben: si no, pareceria que le recomienda los que le quedan.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
$AmigoRedMs = 10000
foreach ($n in @('ConvertTo-Plain', 'Start-SteamPregunta', 'Receive-SteamPregunta',
                 'Format-DeckVerified', 'Format-LogrosFaciles', 'Get-AppIdDeJuego')) {
    Invoke-Expression (Traer $n)
}
$script:dicho = @()
function Say([string]$m) { $script:dicho += $m }
function Log([string]$m) { }
# EL RELOJ Y EL CANAL, de pega
$script:reloj = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$script:pedidas = @()
$script:respuesta = $null
function Start-SteamAsync([string]$url) { $script:pedidas += $url; $script:steamTask = 'en vuelo'; return $true }
function Complete-SteamAsync { $r = $script:respuesta; if ($r) { $script:respuesta = $null; $script:steamTask = $null }; return $r }
$script:Juegos = @(
    @{ appid = '2358720'; nombre = 'Black Myth: Wukong'; bytes = 140GB },
    @{ appid = '1225570'; nombre = 'Unravel Two'; bytes = 7GB }
)

Write-Host ''
Write-Host '-- 1. el appid sale del indice que ya tiene --'
Comp 'encuentra el juego por su nombre' ((Get-AppIdDeJuego 'Black Myth Wukong').id -eq '2358720') "$((Get-AppIdDeJuego 'Black Myth Wukong').id)"
Comp '  y devuelve el nombre bueno' ((Get-AppIdDeJuego 'unravel').nombre -eq 'Unravel Two') ''
Comp 'un juego que no esta no se inventa' (-not (Get-AppIdDeJuego 'Juego Que No Existe 9').id) ''
Comp 'y un nombre de dos letras tampoco' (-not (Get-AppIdDeJuego 'ab').id) 'casaria con cualquiera'

Write-Host ''
Write-Host '-- 2. EL CANAL SE RESPETA (lo que no puede romperse) --'
$script:amigoPide = $null; $script:steamPide = $null; $script:steamTask = $null; $script:pedidas = @()
$r = Start-SteamPregunta 'deck' '2358720' 'Black Myth: Wukong'
Comp 'con el canal libre, pregunta' ($r -eq '' -and $script:pedidas.Count -eq 1) "[$r]"
Comp '  y la url es la del informe de portatiles' ($script:pedidas[0] -match 'deckappcompatibilityreport' -and $script:pedidas[0] -match '2358720') ''
# SI LOS AMIGOS TIENEN EL CANAL, ESTO NO LO TOCA
$script:steamPide = $null; $script:steamTask = $null; $script:amigoPide = @{ paso = 'lista' }; $script:pedidas = @()
$r2 = Start-SteamPregunta 'deck' '2358720' 'X'
Comp 'si los amigos estan preguntando, NO pide' ($script:pedidas.Count -eq 0) "$($script:pedidas.Count) peticiones"
Comp '  y lo dice en vez de callarse' ($r2 -match 'otra cosa a Steam') "$r2"
# Y SI YA HAY UNA PREGUNTA SUYA EN VUELO, TAMPOCO
$script:amigoPide = $null; $script:steamPide = @{ que = 'deck'; en = 0 }; $script:pedidas = @()
Comp 'ni si ya hay una suya en vuelo' ((Start-SteamPregunta 'deck' '1' 'X') -match 'otra cosa') ''
# Y SI EL CANAL ESTA OCUPADO POR CUALQUIERA, TAMPOCO
$script:steamPide = $null; $script:steamTask = 'ocupado'; $script:pedidas = @()
Comp 'ni con el canal ocupado' ((Start-SteamPregunta 'deck' '1' 'X') -match 'otra cosa') ''

Write-Host ''
Write-Host '-- 3. NADIE RECOGE LO QUE NO HA PEDIDO --'
# Esta es LA comprobacion de la seccion: si Receive-SteamPregunta se lleva una respuesta de los
# amigos, la vigilancia se queda muda y nadie se entera.
$script:steamTask = 'en vuelo'; $script:respuesta = '{"response":{"players":[]}}'
$script:steamPide = @{ que = 'deck'; appid = '1'; juego = 'X'; en = 0 }
$script:amigoPide = @{ paso = 'lista' }      # la respuesta es de los amigos
$script:dicho = @()
Receive-SteamPregunta
Comp 'con una pregunta de amigos viva, no recoge nada' ($script:respuesta -ne $null) 'la respuesta sigue en el canal'
Comp '  y no dice nada' ($script:dicho.Count -eq 0) ''
Comp '  y no suelta su propia pregunta' ($null -ne $script:steamPide) 'si la soltara, la respuesta buena se perderia'

Write-Host ''
Write-Host '-- 4. y lo que SI ha pedido, lo recoge y lo dice --'
$script:amigoPide = $null
$script:respuesta = '{"results":{"resolved_category":1}}'
$script:steamTask = 'en vuelo'
$script:steamPide = @{ que = 'deck'; appid = '2358720'; juego = 'Black Myth: Wukong'; en = 0 }
$script:dicho = @()
Receive-SteamPregunta
Comp 'recoge la suya' ($script:dicho.Count -eq 1) "$($script:dicho.Count)"
Comp '  y dice que NO esta soportado' ($script:dicho[0] -match 'NO soportado' -and $script:dicho[0] -match 'Black Myth') "$($script:dicho[0])"
Comp '  y suelta la pregunta' ($null -eq $script:steamPide) 'si no, la siguiente no cabria'

Write-Host ''
Write-Host '-- 5. las cuatro categorias de portatil --'
foreach ($par in @(@(3, 'verificado'), @(2, 'jugable'), @(1, 'NO soportado'), @(0, 'no le han hecho la prueba'))) {
    $o = ('{"results":{"resolved_category":' + $par[0] + '}}') | ConvertFrom-Json
    Comp ('categoria ' + $par[0] + ' se dice "' + $par[1] + '"') ((Format-DeckVerified $o 'Un Juego') -match [regex]::Escape($par[1])) ''
}
$oMal = '{"results":{}}' | ConvertFrom-Json
Comp 'y si Steam no contesta la categoria, lo dice' ((Format-DeckVerified $oMal 'Un Juego') -match 'no me dice') ''

Write-Host ''
Write-Host '-- 6. los logros: los mas faciles, y lo que NO se sabe --'
$oL = @'
{"achievementpercentages":{"achievements":[
 {"name":"El primero","percent":97.7},{"name":"El del medio","percent":40.0},
 {"name":"El raro","percent":1.2},{"name":"El segundo","percent":80.5}]}}
'@ | ConvertFrom-Json
$fL = Format-LogrosFaciles $oL 'Black Myth: Wukong'
Comp 'dice cuantos logros tiene' ($fL -match '4 logros') "$fL"
Comp '  y los tres mas faciles, en orden' ($fL -match 'El primero.*El segundo.*El del medio') 'por porcentaje, de mas a menos'
Comp '  con su porcentaje' ($fL -match '98 por ciento|97 por ciento') ''
Comp '  y NO cuela el raro entre los faciles' ($fL -notmatch 'El raro') ''
# LO QUE NO SE SABE SE DICE: si no, pareceria que le recomienda los que le quedan.
Comp '  y avisa de que los tuyos no los sabe' ($fL -match 'perfil de Steam esta en privado') 'GetPlayerAchievements da 403'
$oVacio = '{"achievementpercentages":{"achievements":[]}}' | ConvertFrom-Json
Comp 'un juego sin logros se dice' ((Format-LogrosFaciles $oVacio 'X') -match 'no tiene logros') ''

Write-Host ''
Write-Host '-- 7. si Steam no contesta, se suelta el canal --'
# Una peticion colgada que no se suelta deja esto sin poder preguntar nunca mas.
$script:steamPide = @{ que = 'deck'; appid = '1'; juego = 'X'; en = 0 }
$script:steamTask = 'en vuelo'; $script:respuesta = $null
$script:reloj = 20000      # pasado el plazo
$script:dicho = @()
Receive-SteamPregunta
Comp 'pasado el plazo, suelta la pregunta' ($null -eq $script:steamPide) ''
Comp '  y lo dice' (@($script:dicho | Where-Object { $_ -match 'no me ha contestado' }).Count -ge 1) "$($script:dicho -join ' | ')"
$script:reloj = 0

Write-Host ''
Write-Host '-- 8. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca steamPregunta' ($sinCom -match "kind = 'steamPregunta'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'steamPregunta' \{") ''
Comp '  y el bucle recoge las respuestas' ($sinCom -match 'Receive-SteamPregunta') ''
# ANTES QUE EL DE LOS AMIGOS, que es el orden del acuerdo
$iMio = $sinCom.IndexOf('try { Receive-SteamPregunta }')
$iAmigo = $sinCom.IndexOf('try { Receive-AmigoPregunta }')
Comp '  y va antes que el de los amigos' ($iMio -gt 0 -and $iAmigo -gt $iMio) 'asi el suyo nunca espera por el de ellos'
# Y NO SE TOCA Start-SteamAsync NI Complete-SteamAsync: se usan como estaban.
Comp 'no se ha tocado el canal de los amigos' (($sinCom -match 'function Start-SteamAsync') -and ($sinCom -match 'function Watch-AmigoConecta')) 'siguen enteros'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova pregunta a Steam por el juego sin pisar la vigilancia de amigos' -ForegroundColor Green
exit 0
