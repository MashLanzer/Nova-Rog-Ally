# AVISAR CUANDO SE CONECTE ALGUIEN EN STEAM (23/09, idea 10).
#
# LO PRIMERO, Y NO SE PUEDE TAPAR: config.json no tiene steam.apiKey, y en 14 dias
# Get-AmigosSteam no ha devuelto un solo amigo. braya lo pidio UNA vez -14/09 00:15:50- y
# Nova le contesto que necesitaba la clave; nueve dias despues sigue sin ponerla. Por eso la
# comprobacion 10 de este banco es que SIN CLAVE no se arma nada y no sale una sola peticion.
#
# LO QUE MAS SE VIGILA, y por este orden:
#
#  1) Que sin nada que vigilar NO se llame a Steam. Eso seria red dentro del bucle mientras
#     braya juega, o sea las reglas 4 y 5 de la casa rotas de golpe.
#  2) Que el aviso vaya por FLANCO y no por ESTADO. No es hipotetico: el aviso de bateria
#     llena se hizo por estado y dejo 19 avisos identicos, cuatro al dia desde el 19/09
#     (08:00, 12:00, 16:00, 20:02), con el ultimo cambio de estado real el 19/09 a las 09:24.
#     Los quince ultimos salieron sin que hubiera pasado nada.
#  3) Que el plazo sobreviva al reinicio. Hay 211 arranques en 14 dias -16 al dia-: cualquier
#     dato que no aguante una ida y vuelta por disco se pierde varias veces al dia, y una
#     vigilancia sin plazo es una vigilancia eterna.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function TraerRama([string]$dentro) {
    $r = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.IfStatementAst] -and
        $x.Clauses[0].Item1.Extent.Text -like "*$dentro*" }, $true)
    if (-not $r) { Write-Host "  MAL  no encuentro la rama con $dentro"; exit 1 }
    return $r.Extent.Text
}
# LOS PATRONES VECINOS NO SE PUEDEN LEER A TROZOS: llevan $VERBOS pegado con un +, asi que
# la comilla se cierra a la mitad. Se saca la EXPRESION entera y se evalua con la frase
# puesta, que ademas es exactamente lo que hace el codigo de verdad.
function Casa([string]$frase, [string]$pista) {
    foreach ($l in @($fuente -split "`r?`n")) {
        # la linea tiene que ser un if de una sola linea: hay condiciones repartidas en
        # varias -acaban en -and- y de esas no se puede sacar la expresion asi
        if ($l -match [regex]::Escape($pista) -and $l -match '-match\s' -and $l.TrimEnd().EndsWith(') {')) {
            $e = $l.Substring($l.IndexOf('-match ') + 7)
            $e = $e.Substring(0, $e.LastIndexOf(') {'))
            $p = $frase
            return [bool](Invoke-Expression ('$p -match ' + $e))
        }
    }
    Write-Host "  MAL  no encuentro el patron de '$pista'"; exit 1
}
# EL PATRON DE VERDAD, sacado del codigo: copiarlo aqui seria probar mi copia.
function TraerRegex([string]$pista) {
    foreach ($l in @($fuente -split "`r?`n")) {
        if ($l -match [regex]::Escape($pista)) {
            $m = [regex]::Match($l, "'(\^[^']+)'")
            if ($m.Success) { return $m.Groups[1].Value }
        }
    }
    Write-Host "  MAL  no encuentro el patron de '$pista'"; exit 1
}

# --- el mundo de mentira ----------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('amg-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$ReglasPath = Join-Path $tmp 'reglas.json'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:reglas = $null
$script:confirmado = $false
$script:invitado = $false
$script:dicho = @()
$script:hecho = @()
$script:llamadas = 0
$script:urls = @()
$script:jsonPendiente = $null
$script:claveFalsa = 'CLAVE-DE-MENTIRA'
$script:listaFalsa = $null
$script:abierto = @()
$script:cerrado = 0
function Log([string]$m) { }
function Save-Corrupto($a, $b) { }
function Write-Atomico([string]$r, [string]$t, [bool]$bom = $false) {
    [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false)))
}
function Say([string]$t, [string]$e = '') { $script:dicho += $t }
function Send-UIEvento([string]$e) { }
function Set-UI([string]$e, [string]$t = '', [int]$ms = 0) { }
function Add-Estadistica($a, $b) { }
function Invoke-FastCommand([string]$t) { $script:hecho += $t; return $t }
function Test-CadaDispara($r) { return $false }
function Test-ReglaCaducada($r) { return $false }
function Open-Eleccion([string[]]$ops, [string]$origen) { $script:abierto += , @{ opciones = @($ops); origen = $origen }; return $true }
function Close-Eleccion([bool]$u = $true) { $script:cerrado++ }
function Get-Cfg($a, $b, $c) { if ($a -eq 'steam' -and $b -eq 'apiKey') { return $script:claveFalsa }; return $c }
function Get-ClaveSteam { return $script:claveFalsa }
$script:huecoCreado = 0
function New-ClavesVacio { $script:huecoCreado++; return $true }
# LA RED, FALSEADA ENTERA: aqui no se prueba que Steam conteste -eso no se puede fijar en un
# banco-, se prueba lo que es de Nova.
# A PROPOSITO SIN GUARDA: si este falso llevara el 'ya hay una en vuelo' del de verdad, la
# comprobacion de abajo estaria probando el falso. La guarda que importa para el bucle es la
# de Watch-AmigoConecta, y la del propio Start-SteamAsync la mira probar-huerfanas.ps1.
function Start-SteamAsync([string]$url) {
    $script:llamadas++; $script:urls += $url
    $script:steamTask = 'en vuelo'
    return $true
}
function Complete-SteamAsync {
    if (-not $script:steamTask) { return $null }
    $script:steamTask = $null
    $j = $script:jsonPendiente; $script:jsonPendiente = $null
    return $j
}
# EL MENSAJE DE "NO HAY CLAVE" SE LEE DEL CODIGO. Copiandolo aqui, el banco daria verde
# aunque alguien lo dejara en "no puedo": es justo lo unico que braya va a oir el dia que
# pruebe esto, porque config.json sigue sin steam.apiKey.
$mSinClave = if ($fuente -match "error = '(para eso necesito una clave[^']+)'") { $Matches[1] } else { '' }
if (-not $mSinClave) { Write-Host '  MAL  no encuentro el mensaje de la clave que falta'; exit 1 }
# LA RED, FALSEADA POR DEBAJO. Antes aqui habia una Get-AmigosLista de mentira, y eso hacia
# que el banco probara MI COPIA: se vio rompiendo el codigo de verdad -quitandole la salida de
# "no hay clave"- y el banco seguia verde. Ahora se usa la funcion de verdad y lo que se
# falsea es Invoke-RestMethod, que es la unica linea que toca la red.
$script:rest = 0
$script:amigosFalsos = $null
function Get-YoSteam { return '76561198000000000' }
function Invoke-RestMethod {
    param([Parameter(Position = 0)][string]$Uri, [int]$TimeoutSec = 0)
    $script:rest++
    $lista = if ($null -ne $script:amigosFalsos) { @($script:amigosFalsos) } else { @(
        @{ id = '111'; nombre = 'Ana'; online = $false; visible = $true; jugando = '' },
        @{ id = '222'; nombre = 'Meramiau'; online = $false; visible = $true; jugando = '' },
        @{ id = '333'; nombre = 'Kevin'; online = $true; visible = $true; jugando = 'It Takes Two' }) }
    if ($Uri -match 'GetFriendList') {
        return (ConvertTo-Json -Depth 5 -InputObject @{ friendslist = @{ friends = @($lista | ForEach-Object { @{ steamid = $_.id } }) } } | ConvertFrom-Json)
    }
    $jug = @()
    foreach ($a in $lista) {
        $o = @{ steamid = $a.id; personaname = $a.nombre; gameextrainfo = $a.jugando }
        # un perfil en privado NO trae personastate: es asi como se detecta
        if ($a.visible) { $o.personastate = $(if ($a.online) { 1 } else { 0 }) }
        $jug += $o
    }
    return (ConvertTo-Json -Depth 5 -InputObject @{ response = @{ players = @($jug) } } | ConvertFrom-Json)
}

$CARDINALES = @{ 'uno' = 1; 'una' = 1; 'dos' = 2; 'tres' = 3; 'cuatro' = 4; 'cinco' = 5
                 'seis' = 6; 'siete' = 7; 'ocho' = 8; 'nueve' = 9; 'diez' = 10 }
$ORDINALES_YT = @{ 'primer' = 1; 'primero' = 1; 'primera' = 1; 'segundo' = 2; 'segunda' = 2; 'tercer' = 3
                   'tercero' = 3; 'tercera' = 3; 'cuarto' = 4; 'cuarta' = 4; 'quinto' = 5; 'quinta' = 5 }
$AmigoCadaMs = if ($fuente -match '(?m)^\$AmigoCadaMs = (\d+)') { [int]$Matches[1] } else { -1 }
$AmigoPlazoMs = if ($fuente -match '(?m)^\$AmigoPlazoMs = (\d+)') { [int]$Matches[1] } else { -1 }
$AmigoEligeMs = if ($fuente -match '(?m)^\$AmigoEligeMs = (\d+)') { [int]$Matches[1] } else { -1 }
# el mismo $VERBOS del codigo: los patrones vecinos lo llevan dentro
# COMILLAS SIMPLES: con dobles, PowerShell interpolaba $VERBOS -que aun no existe- y el
# patron quedaba en un munon que no casaba nunca, asi que Casa evaluaba los patrones vecinos
# con cuatro verbos en vez de los sesenta de verdad.
$VERBOS = if ($fuente -match '(?m)^\$VERBOS = ''([^'']+)''') { $Matches[1] } else { '' }
if (-not $VERBOS) { Write-Host '  MAL  no encuentro $VERBOS en el codigo'; exit 1 }
$script:steamTask = $null
$script:amigoCheck = -120000
$script:amigoOnline = @{}
$script:amigoEligiendo = $null

foreach ($f in @('ConvertTo-Plain', 'Get-Reglas', 'Save-Reglas', 'Describe-Regla', 'Invoke-Reglas',
                 'Get-AmigosLista', 'Watch-AmigoConecta', 'Start-AmigoVigila', 'Complete-AmigoElige')) { Invoke-Expression (Traer $f) }
# las tres frases, sacadas del arbol y con un marco: son ramas de Resolve-Fragment, que
# depende de medio fichero
Invoke-Expression ("function Di([string]`$f) {`n" + (TraerRama 'conecte|conecta|entre') + "`n" +
                   (TraerRama 'amigoEligiendo') + "`n" + (TraerRama 'de\s+vigilar\s+a') + "`n    return `$null`n}")

function Limpia {
    $script:reglas = $null
    $script:amigoOnline = @{}
    $script:amigoEligiendo = $null
    $script:steamTask = $null
    $script:amigoCheck = -1000000
    $script:llamadas = 0; $script:urls = @()
    $script:dicho = @(); $script:hecho = @(); $script:abierto = @(); $script:cerrado = 0
    $script:jsonPendiente = $null
    $script:amigosFalsos = $null
    $script:rest = 0
    $script:claveFalsa = 'CLAVE-DE-MENTIRA'
    try { Remove-Item -LiteralPath $ReglasPath -Force -ErrorAction SilentlyContinue } catch {}
}
# una lectura de Steam: se deja el json puesto y se da una vuelta de bucle
function Vuelta($jugadores) {
    $script:jsonPendiente = (ConvertTo-Json -InputObject @{ response = @{ players = @($jugadores) } } -Depth 5)
    $script:steamTask = 'en vuelo'
    $script:amigoCheck = -1000000
    Watch-AmigoConecta
}
# LA TRAMPA DE LA CASA, y aqui cayo este banco: Get-Reglas devuelve ',$script:reglas' para
# que una lista vacia no se convierta en $null, asi que (Reglas) da UN elemento -la
# lista entera- y .Count vale 1 siempre. Hay que asignar primero y desenrollar despues.
function Reglas {
    $g = Get-Reglas
    return @($g)
}
function Jug([string]$id, [bool]$on) { return @{ steamid = $id; personastate = $(if ($on) { 1 } else { 0 }) } }
# LA CADENA ENTERA, como la anda braya: la frase -> la lista -> el numero. No se llama a
# Complete-AmigoElige a pelo, que entonces no se probaria que el numero llega hasta ahi.
function Armar([int]$n = 2) {
    $k = @(Di 'avisame cuando se conecte mi novia')
    if ($k.Count -eq 0 -or $k[0].kind -ne 'amigoVigila') { Write-Host '  MAL  la frase de armar ya no entra'; exit 1 }
    [void](Start-AmigoVigila)
    $palabras = @{ 1 = 'uno'; 2 = 'dos'; 3 = 'tres' }
    $k2 = @(Di ('el ' + $palabras[$n]))
    if ($k2.Count -eq 0 -or $k2[0].kind -ne 'amigoElige') { Write-Host '  MAL  el numero ya no entra'; exit 1 }
    [void](Complete-AmigoElige ([int]$k2[0].n))
}

Write-Host ''
Write-Host '-- 1. la frase entra, y se elige por numero (no por nombre) --'
Limpia
$r1 = @(Di 'avisame cuando se conecte mi novia')
Comp 'la frase se entiende aqui, no se va al modelo' ($r1.Count -gt 0 -and $r1[0].kind -eq 'amigoVigila') "$($r1[0].kind)"
$f1 = Start-AmigoVigila
Comp 'lee la lista numerada' ($f1 -match '1, ' -and $f1 -match '2, ' -and $f1 -match '3, ') "$f1"
Comp 'y SIEMPRE en el mismo orden, por nombre' ($f1 -match '1, Ana; 2, Kevin; 3, Meramiau') 'se elige de oido: el orden es la mitad de la seguridad'
Comp 'y abre el selector del mando (la otra via)' (@($script:abierto).Count -eq 1 -and $script:abierto[0].origen -eq 'amigo') "$(@($script:abierto).Count)"
$r1b = @(Di 'el dos')
Comp '"el dos" se entiende como el numero dos' ($r1b.Count -gt 0 -and $r1b[0].kind -eq 'amigoElige' -and [int]$r1b[0].n -eq 2) "$($r1b[0].kind) n=$([int]$r1b[0].n)"
$f1b = Complete-AmigoElige 2
Comp 'y guarda el steamid del SEGUNDO' ((@(Reglas)[0].valor).Split('|')[0] -eq '333') "$((@(Reglas)[0].valor).Split('|')[0])"
Comp 'con su nombre al lado, para poder decirlo' ((@(Reglas)[0].valor).Split('|')[1] -eq 'Kevin') ''
Comp 'y con un plazo' ((@(Reglas)[0].valor).Split('|').Count -eq 3) "$(@(Reglas)[0].valor)"
Comp 'la regla es de un solo uso' (@(Reglas)[0].ultima -eq 'unavez') ''
Comp 'y lo dice sin cantar el steamid' (($f1b -match 'Kevin') -and ($f1b -notmatch '333')) "$f1b"
Comp 'el plazo son las seis horas del codigo' ($AmigoPlazoMs -eq 21600000) "$AmigoPlazoMs ms"
Comp 'y se dice en voz alta, que es lo que lo hace una salida' ($f1b -match 'seis horas') ''

Write-Host ''
Write-Host '-- 2. y NO le quita la frase a nadie --'
# Los dos vecinos peligrosos, con sus patrones sacados del codigo: "conecte" ya es del disco
# de los juegos, y "avisame cuando" ya es de las descargas.
$patMio = TraerRegex 'conecte|conecta|entre'
$fDisco = 'cuando conecte el disco de los juegos abre steam'
$fDesc = 'avisame cuando termine de descargarse elden ring'
Comp 'el disco de los juegos sigue siendo del disco' (Casa $fDisco 'disco(?:\s+(?:de\s+(?:los\s+)?juegos') ''
Comp 'y mi patron no lo toca' (-not ($fDisco -match $patMio)) 'lista cerrada de cinco palabras'
Comp 'la descarga sigue siendo de la descarga' (Casa $fDesc 'termin[eoa]|acab[eoa]|complet[eoa]') ''
Comp 'y mi patron tampoco lo toca' (-not ($fDesc -match $patMio)) ''
Comp 'y el del disco no me quita la mia' (-not (Casa 'avisame cuando se conecte mi novia' 'disco(?:\s+(?:de\s+(?:los\s+)?juegos')) ''
Comp 'ni el de las descargas' (-not (Casa 'avisame cuando se conecte mi novia' 'termin[eoa]|acab[eoa]|complet[eoa]')) ''
foreach ($q in @('avisame cuando se conecte mi novia', 'dime cuando entre mi chica', 'me avisas en cuanto se conecte mi amigo')) {
    Comp ("entra: `"$q`"") ($q -match $patMio) ''
}
foreach ($q in @('avisame cuando se conecte meramiau', 'avisame cuando se conecte', 'avisame cuando se conecte el wifi')) {
    Comp ("NO entra: `"$q`"") (-not ($q -match $patMio)) 'nada de transcribir nicks'
}

Write-Host ''
Write-Host '-- 3. FLANCO, NO ESTADO: la primera lectura solo toma nota --'
Limpia
Armar
$script:dicho = @()
Vuelta @((Jug '333' $true))
Comp 'primera lectura con ella YA conectada: 0 avisos' (@($script:dicho).Count -eq 0) "$(@($script:dicho) -join ' / ')"
Vuelta @((Jug '333' $true))
Comp 'sigue conectada: 0 avisos' (@($script:dicho).Count -eq 0) "$(@($script:dicho) -join ' / ')"
Vuelta @((Jug '333' $false))
Comp 'se desconecta: 0 avisos' (@($script:dicho).Count -eq 0) "$(@($script:dicho) -join ' / ')"
Vuelta @((Jug '333' $true))
Comp 'SE CONECTA: 1 aviso' (@($script:dicho).Count -eq 1) "$(@($script:dicho) -join ' / ')"
Comp 'y con su nombre dentro' (@($script:dicho)[0] -match 'Kevin') "$(@($script:dicho)[0])"

Write-Host ''
Write-Host '-- 4. y se borra sola: 10 vueltas mas y ni una palabra --'
for ($i = 0; $i -lt 10; $i++) { Vuelta @((Jug '333' $true)) }
Comp 'ni un aviso mas' (@($script:dicho).Count -eq 1) "$(@($script:dicho).Count)"
Comp 'y la regla ya no esta' (@(Reglas).Count -eq 0) "$(@(Reglas).Count) reglas"
# Y EL ESTADO SE TIRA. Si se quedara pegado, la proxima vigilancia compararia con lo que se
# vio hace horas y cantaria un "se acaba de conectar" de algo que paso anoche.
Comp 'y lo que se vio no se queda pegado' ($script:amigoOnline.Count -eq 0) "$($script:amigoOnline.Count) recordados"

Write-Host ''
Write-Host '-- 5. SIN NADA QUE VIGILAR, CERO RED --'
# Esta es la gorda: red dentro del bucle mientras braya juega.
Limpia
for ($i = 0; $i -lt 50; $i++) { $script:amigoCheck = -1000000; Watch-AmigoConecta }
Comp '50 vueltas sin regla: 0 llamadas a Steam' ($script:llamadas -eq 0) "$($script:llamadas) llamadas"
Comp 'y no deja nada vivo' ($null -eq $script:steamTask) ''
# y con regla, una cada 120 s y ni una mas
Limpia
Armar
$script:llamadas = 0
$script:amigoCheck = $sw.ElapsedMilliseconds
for ($i = 0; $i -lt 20; $i++) { Watch-AmigoConecta }
Comp 'con regla, 20 vueltas seguidas: 0 llamadas (aun no toca)' ($script:llamadas -eq 0) "$($script:llamadas)"
$script:amigoCheck = $sw.ElapsedMilliseconds - $AmigoCadaMs - 1
Watch-AmigoConecta
Comp 'pasados los dos minutos: 1 llamada' ($script:llamadas -eq 1) "$($script:llamadas)"
Watch-AmigoConecta
Comp 'y no se lanza otra con una en vuelo' ($script:llamadas -eq 1) "$($script:llamadas)"
Comp 'los dos minutos son los del chequeo de descargas' ($AmigoCadaMs -eq 120000) "$AmigoCadaMs ms"
Comp 'la url lleva el steamid vigilado' (@($script:urls)[0] -match 'steamids=333') ''

Write-Host ''
Write-Host '-- 6. el plazo: vencida se borra ANTES de gastar red --'
Limpia
Armar
$tr6 = ([string]@(Reglas)[0].valor).Split('|')
@(Reglas)[0].valor = ($tr6[0] + '|' + $tr6[1] + '|' + (Get-Date).AddHours(-1).ToString('o'))
$script:llamadas = 0
$script:amigoCheck = -1000000
Watch-AmigoConecta
Comp 'la regla vencida se va' (@(Reglas).Count -eq 0) "$(@(Reglas).Count)"
Comp 'y no gasta ni una peticion' ($script:llamadas -eq 0) "$($script:llamadas)"
# y un plazo ilegible tambien es una regla sin salida
Limpia
Armar
@(Reglas)[0].valor = '333|Kevin'
$script:llamadas = 0; $script:amigoCheck = -1000000
Watch-AmigoConecta
Comp 'sin plazo legible, fuera tambien' (@(Reglas).Count -eq 0) 'una regla sin plazo es una regla eterna'

Write-Host ''
Write-Host '-- 7. y el plazo sobrevive al reinicio (211 arranques en 14 dias) --'
Limpia
Armar
$antes7 = [string]@(Reglas)[0].valor
Save-Reglas
$script:reglas = $null            # como si Nova se hubiera reiniciado
$despues7 = [string]@(Reglas)[0].valor
Comp 'el steamid sigue ahi' ($despues7.Split('|')[0] -eq '333') "$despues7"
Comp 'el nombre sigue ahi' ($despues7.Split('|')[1] -eq 'Kevin') ''
Comp 'y el plazo sigue ahi, entero' ($despues7 -eq $antes7) "antes: $antes7"
Comp 'y sigue siendo de un solo uso' (@(Reglas)[0].ultima -eq 'unavez') ''

Write-Host ''
Write-Host '-- 8. las salidas (regla 2 de la casa) --'
Limpia
Armar
Comp 'esta armada' (@(Reglas).Count -eq 1) ''
$r8 = @(Di 'olvida lo de mi novia')
Comp '1) decirlo se entiende' ($r8.Count -gt 0 -and $r8[0].kind -eq 'amigoOlvida') "$($r8[0].kind)"
foreach ($q in @('olvida lo de mi novia', 'quita el aviso de mi chica', 'deja de vigilar a mi amiga', 'cancela lo de mi novia')) {
    $rq = @(Di $q)
    Comp ("   `"$q`"") ($rq.Count -gt 0 -and $rq[0].kind -eq 'amigoOlvida') ''
}
Comp '2) el plazo de seis horas, probado arriba' ($AmigoPlazoMs -eq 21600000) ''
Comp '3) se borra sola al avisar, probado arriba' ($fuente -match "'cascosPone', 'amigoConecta'") 'esta en la lista de un solo uso'
Comp 'y "borra la regla N" sigue valiendo para esta' ($fuente -match "borra\|elimina\|quita\|olvida\)\\s\+la\\s\+regla") 'la cuarta puerta, la de siempre'

Write-Host ''
Write-Host '-- 9. Nova la dice en cristiano, no con el nombre del tipo --'
Limpia
Armar
$d9 = Describe-Regla @(Reglas)[0]
Comp 'dice de quien es' ($d9 -match 'Kevin') "$d9"
Comp 'y NO dice "amigoConecta"' ($d9 -notmatch 'amigoConecta') ''
Comp 'ni el steamid' ($d9 -notmatch '333') ''

Write-Host ''
Write-Host '-- 10. SIN CLAVE NO SE ARMA NADA (y no sale una peticion) --'
# config.json no tiene steam.apiKey y en 14 dias esto no ha devuelto un amigo. Si algun dia
# alguien arma la vigilancia sin clave, la peticion sale con "key=" vacio a la API de Steam.
Limpia
$script:claveFalsa = ''
$f10 = Start-AmigoVigila
Comp 'lo dice, y dice donde pedirla' ($f10 -eq $mSinClave) "$f10"
Comp 'y le deja el hueco preparado para pegarla' ($script:huecoCreado -ge 1) 'asi solo tiene que abrir el archivo'
Comp 'y no arma nada' (@(Reglas).Count -eq 0) ''
Comp 'ni abre el selector para elegir a nadie' (@($script:abierto).Count -eq 0) ''
Comp 'ni sale una peticion' ($script:llamadas -eq 0) ''
Comp 'ni siquiera una sincrona con la clave vacia' ($script:rest -eq 0) 'sin esto saldria un key= vacio a la API de Steam'

Write-Host ''
Write-Host '-- 11. perfil en privado: se dice AHORA, no se calla para siempre --'
Limpia
$script:amigosFalsos = @(@{ id = '444'; nombre = 'Privada'; online = $false; visible = $false; jugando = '' },
                         @{ id = '555'; nombre = 'Abierta'; online = $false; visible = $true; jugando = '' })
[void](Start-AmigoVigila)
# alfabetica: 1 Abierta, 2 Privada
$f11 = Complete-AmigoElige 2
Comp 'avisa de que Steam no lo dice' ($f11 -match 'privado') "$f11"
Comp 'y NO arma una vigilancia que no se enteraria de nada' (@(Reglas).Count -eq 0) "$(@(Reglas).Count)"
$f11b = Complete-AmigoElige 2
Comp 'y sin lista viva, el numero no vale para nada' ($null -eq $f11b) "$f11b"

Write-Host ''
Write-Host '-- 12. lo que NO puede pasar --'
$wa = Traer 'Watch-AmigoConecta'
Comp 'el sensor no sale a la red sincrona' ($wa -notmatch 'Invoke-RestMethod') 'eso son 12 s de consola congelada'
Comp 'ni espera a un Task' ($wa -notmatch '\.Wait\(|\.Result\b') 'braya juega mientras habla'
$sa = Traer 'Start-AmigoVigila'
Comp 'armarla NO guarda nada todavia' ($sa -notmatch 'Save-Reglas') 'primero hay que saber a quien'
$ca = Traer 'Complete-AmigoElige'
Limpia
Armar 2
Armar 2
Comp 'y elegir no deja dos vigilancias de la misma persona' (@(Reglas).Count -eq 1) "$(@(Reglas).Count) reglas"
Limpia
Comp 'el nombre no va al perfil' ($ca -notmatch 'Add-DatoPerfil') '8 de sus 59 datos son nombres mal oidos'
Comp 'el sensor se llama en el bucle de verdad' ($fuente -match '(?m)^\s+try \{ Watch-AmigoConecta \} catch') ''

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  la vigilancia avisa una vez, por flanco, y sin clave no hace nada'
exit 0
