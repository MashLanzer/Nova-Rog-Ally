# EL SALDO DE SU BANCO LO DIJO LA VOZ DE MICROSOFT (27/09, idea 116 de las 121)
#
# EL DATO: con voz.motor = online, el texto de CADA frase que Nova dice se POSTea a los servidores de
# Microsoft (edge-tts, es-MX-DaliaNeural). De las 220 frases que ha dicho en voz alta, CINCO llevan
# datos privados de verdad, y las cinco salen del correo. La peor, del 15/09 a las 14:25: 'tienes
# 10940 no leidos, y hoy destacan una alerta de Chase de saldo bajo (7.23 dolares), una transferencia
# devuelta de 25 dolares'. Su saldo bancario, dicho por un servicio de terceros.
#
# LO QUE ESTE BANCO PROTEGE, y los casos son las frases REALES del registro:
#   1. que las cinco se digan con la voz de casa
#   2. que lo normal -'abro Steam', 'son las once'- siga con la voz de fuera, porque a braya no le
#      gustan las voces roboticas y esto se limita a lo medido
#   3. que si Piper no puede, se siga hablando por fuera: callarse seria peor
#   4. que se pueda apagar desde config.json
#   5. que la bandera $script:respuestaPrivada que ya existia cuente, y que el correo la levante
#   6. y que NO se toque $RE_DATO_SENSIBLE, que decide otra cosa: lo que se guarda en el perfil
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LA PIEZA Y LOS DOS PATRONES, DEL FICHERO REAL
$d = @($arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-VozLocal' }, $true))
Comp 'Test-VozLocal esta una sola vez' ($d.Count -eq 1) ([string]$d.Count)
if ($d.Count -eq 1) { Invoke-Expression $d[0].Extent.Text }
function TraerVar([string]$n) {
    $a = $arbol.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq ('$' + $n) }, $true)
    if (-not $a) { throw "falta la variable $n en assistant.ps1" }
    return $a.Right.Extent.Text
}
Invoke-Expression ('$RE_VOZ_LOCAL = ' + (TraerVar 'RE_VOZ_LOCAL'))
Invoke-Expression ('$RE_DATO_SENSIBLE = ' + (TraerVar 'RE_DATO_SENSIBLE'))
$VozLocalSensible = $true
Comp 'los dos patrones salen del fichero real' (($RE_VOZ_LOCAL.Length -gt 40) -and ($RE_DATO_SENSIBLE.Length -gt 40)) ''

Write-Host ''
Write-Host '-- 1. LAS CINCO FRASES DE VERDAD, COPIADAS DEL REGISTRO --'
$reales = @(
    @{ f = '2026-09-15 14:25'; t = 'Ya revise tu bandeja: tienes 10940 no leidos, y hoy destacan una alerta de Chase de saldo bajo (7.23 dolares), una transferencia devuelta de 25 dolares' }
    @{ f = '2026-09-15 15:44'; t = 'Ya esta abierto tu Gmail. Tienes casi once mil correos sin leer; lo mas importante es que te regalaron el juego It Takes Two en Steam' }
    @{ f = '2026-09-19 09:20'; t = 'Tienes 5 correos nuevos. PetSmart, It is here! Come in for National Pet Bird Day. Chase, Recibiste dinero con Zelle' }
    @{ f = '2026-09-22 08:35'; t = 'Tienes 5 correos nuevos. Chase, El saldo disponible de tu cuenta esta por debajo de tu limite de $50.00 para la...' }
    @{ f = '2026-09-23 10:32'; t = 'Tienes 5 correos nuevos: uno de Canva, uno de Chase, uno de Experian, y 2 mas.' }
)
$fuera = @()
foreach ($r in $reales) {
    if (Test-VozLocal $r.t $false) { Write-Host ('  ok   ' + $r.f + ' se queda en casa') }
    else { Write-Host ('  MAL  ' + $r.f + ' SALE A INTERNET'); $mal++; $fuera += @($r.f) }
}
Comp '1z. las cinco se quedan en casa' ($fuera.Count -eq 0) $(if ($fuera.Count) { 'se escapan: ' + ($fuera -join ', ') } else { 'ni una sale' })

Write-Host ''
Write-Host '-- 1b. CADA TROZO DEL PATRON TIENE QUE VALER PARA ALGO --'
# Las cinco frases de arriba traen varias senales a la vez -'saldo' viene con 'dolares', y con
# '$50.00'-, asi que quitandole un trozo al patron siguen cazandose por otro y el banco no se
# enteraba. Aqui va una frase minima por trozo, todas con la forma que tiene un aviso de correo.
$porTrozo = @(
    @{ q = 'saldo';        t = 'Tu saldo esta por debajo del limite.' }
    @{ q = 'dolares';      t = 'Te devolvieron veinticinco dolares.' }
    @{ q = 'cifra con $';  t = 'El cargo fue de $50.00 esta manana.' }
    @{ q = 'transferencia'; t = 'Hay una transferencia devuelta.' }
    @{ q = 'zelle';        t = 'Recibiste algo con Zelle.' }
    @{ q = 'no leidos';    t = 'Tienes diez mil no leidos.' }
    @{ q = 'sin leer';     t = 'Tienes casi once mil correos sin leer.' }
    @{ q = 'tienes N correos'; t = 'Tienes 5 correos de PetSmart y Canva.' }
    @{ q = 'correos nuevos'; t = 'Hay correos nuevos de esta manana.' }
)
foreach ($pt in $porTrozo) {
    if (Test-VozLocal $pt.t $false) { Write-Host ('  ok   ' + $pt.q + ' se queda en casa') }
    else { Write-Host ('  MAL  ' + $pt.q + ' SALE A INTERNET  (' + $pt.t + ')'); $mal++ }
}

Write-Host ''
Write-Host '-- 2. LO NORMAL SIGUE CON LA VOZ DE FUERA --'
# tambien del registro: lo que Nova dice todo el dia
$normales = @(
    'Son las once y cinco.'
    'Ya esta abierto Steam.'
    'Listo, cree la carpeta receta uno en el escritorio.'
    'Sin cargador, al 47 por ciento.'
    'Ya esta cargada del todo, puedes desenchufarla.'
    'Llevas dos horas jugando.'
    'Se me paso decirte esto a tiempo: ya esta cargada del todo.'
    'Ahi la tienes.'
)
$colados = @()
foreach ($n in $normales) { if (Test-VozLocal $n $false) { $colados += @($n) } }
Comp '2a. ninguna frase normal se va a la voz de casa' ($colados.Count -eq 0) $(if ($colados.Count) { 'se cuelan: ' + ($colados -join ' | ') } else { 'las ocho salen como siempre' })
Comp '2b. el texto vacio tampoco' (-not (Test-VozLocal '' $false)) ''

Write-Host ''
Write-Host '-- 3. EL FALSO POSITIVO QUE HAY, Y DE DONDE VIENE --'
# 'y 15 de dinero' es de un juego de Roblox y casa por el \bdinero\b que YA estaba en
# $RE_DATO_SENSIBLE, no por el patron nuevo. Se deja dicho para que nadie lo busque en el sitio malo.
$roblox = 'Veo un juego de Roblox tipo obby: estas sobre una rampa junto a lava, con resortes y jetpacks en la barra de objetos y 15 de dinero.'
Comp '3a. el de Roblox se va a la voz de casa' (Test-VozLocal $roblox $false) 'seis de 220, y esta es la que sobra'
Comp '3b. y es el patron VIEJO el que lo caza' (($roblox -match $RE_DATO_SENSIBLE) -and -not ($roblox -match $RE_VOZ_LOCAL)) 'el \bdinero\b heredado, no el nuevo'

Write-Host ''
Write-Host '-- 4. LA BANDERA QUE YA EXISTIA CUENTA --'
Comp '4a. una respuesta marcada privada va a casa' (Test-VozLocal 'Te escribio tu amigo desde el movil.' $true) 'los nicks, los mensajes, los nombres de sus ficheros'
Comp '4b. aunque el texto no diga nada raro' (Test-VozLocal 'Ahi la tienes.' $true) ''
Comp '4c. y sin la marca, esa misma sale fuera' (-not (Test-VozLocal 'Ahi la tienes.' $false)) ''

Write-Host ''
Write-Host '-- 5. SE PUEDE APAGAR --'
$VozLocalSensible = $false
Comp '5a. apagado, ni la del saldo se queda' (-not (Test-VozLocal $reales[0].t $false)) 'voz.localSensible en config.json'
Comp '5b. ni la marcada privada' (-not (Test-VozLocal 'lo que sea' $true)) ''
$VozLocalSensible = $true
Comp '5c. y encendido vuelve a quedarse' (Test-VozLocal $reales[0].t $false) ''

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
Comp '6a. la decision va ANTES de la voz de fuera' ($sinCom.IndexOf('Test-VozLocal $t') -lt $sinCom.IndexOf('if (Say-Online $t $emo)')) ''
Comp '6b. se prueba Piper, que ya estaba escrita' ($sinCom -match '(?s)Test-VozLocal \$t[\s\S]{0,200}?Say-Piper \$t') ''
Comp '6c. y si Piper no puede, se sigue hablando' ($sinCom -match 'Piper no pudo; va por la de fuera') 'callarse seria peor que decirlo'
Comp '6d. la cadena de respaldo sigue entera' ($sinCom -match '(?s)Say-Online \$t \$emo[\s\S]{0,300}?Say-Piper \$t') 'Piper sigue siendo el respaldo de siempre'
Comp '6e. el correo levanta la bandera de privado' ($sinCom -match '(?s)function Invoke-Correo\(\$a\) \{\s*\$script:respuestaPrivada = \$true') 'era el hueco: seis caminos la levantaban y el correo no'
Comp '6f. y el patron del perfil NO se ha tocado' ($RE_DATO_SENSIBLE -match 'contrase\|password') 'ese decide que se guarda, que es otra decision'
Comp '6g. son dos patrones y no uno' (@([regex]::Matches($sinCom, '\$RE_VOZ_LOCAL')).Count -ge 2) ''
$cuerpoT = ((@($arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-VozLocal' }, $true))[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '6h. Test-VozLocal es pura' (-not ($cuerpoT -match '(Get-Date|Log |Say|Test-Path|\$sw\.)')) 'por eso se le pueden correr las 220 frases'
Comp '6i. y mira los dos patrones' (($cuerpoT -match 'RE_VOZ_LOCAL') -and ($cuerpoT -match 'RE_DATO_SENSIBLE')) ''
Comp '6j. el modelo de Piper esta en su sitio' (Test-Path (Join-Path $Raiz 'piper\es_MX-claude-high.onnx')) 'si no, esto no podria funcionar'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'su saldo ya no sale de casa por el altavoz' -ForegroundColor Green
exit 0
