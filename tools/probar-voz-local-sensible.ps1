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
# EL BLOQUE DE UN if, CONTADO POR LLAVES (27/09, idea 2): el 6b de abajo media "a menos de 200
# caracteres" y eso se pone rojo solo el dia que alguien escribe una linea dentro del if.
function Bloque([string]$texto, [string]$ancla) {
    $i = $texto.IndexOf($ancla)
    if ($i -lt 0) { return '' }
    $abre = $texto.IndexOf('{', $i)
    if ($abre -lt 0) { return '' }
    $prof = 0
    for ($p = $abre; $p -lt $texto.Length; $p++) {
        if ($texto[$p] -eq '{') { $prof++ }
        elseif ($texto[$p] -eq '}') { $prof--; if ($prof -eq 0) { return $texto.Substring($abre, $p - $abre + 1) } }
    }
    return ''
}
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
Write-Host '-- 5b. EL CAMINO DE VERDAD, EJECUTADO (no mirado) --'
# ESTO ES LO QUE FALTABA, y lo destapo un revisor: con el apartado 6 de abajo -que solo mira orden y
# cercania de texto- se podia INVERTIR el if real de Say (poner 'if (-not (Test-VozLocal ...))') y el
# banco salia VERDE ENTERO, firmando "su saldo ya no sale de casa" mientras mandaba el saldo de Chase
# a Microsoft y las frases normales a Piper. Un banco que no ejecuta el camino no vigila su signo.
# Asi que aqui se saca el bloque de Say por SANGRADO -el cierre es la primera linea posterior que
# empieza por '}' con la misma indentacion- y se EJECUTA con dobles que apuntan por donde salio.
$lin = [IO.File]::ReadAllLines($PS1)
$iV = -1
# EL ANCLA ES LAXA A PROPOSITO: acepta tambien un '-not' delante. Si exigiera el texto exacto, la
# inversion de polaridad se cazaria por "no encuentro el bloque" -que es fragil: un renombrado lo
# rompe igual- en vez de por lo que de verdad importa, que la frase del saldo acabe en internet.
for ($i = 0; $i -lt $lin.Count; $i++) { if ($lin[$i] -match '^\s+if \(.{0,8}Test-VozLocal \$t ') { $iV = $i; break } }
# Y LO QUE PREPARA LA DECISION, SI LO HAY (28/09). Desde hoy la bandera de lo privado se lee y se
# baja en las lineas de justo encima del if -es de un solo uso, ver Say-, asi que el bloque empieza
# ahi: sacar solo el if dejaria la variable vacia y el banco reventaria por su propio recorte, que
# es lo que paso al aplicar el cambio. Se miran tres lineas hacia atras y ni una mas.
if ($iV -ge 1) {
    for ($k = 1; $k -le 3; $k++) {
        $j = $iV - $k
        if ($j -lt 0) { break }
        if ($lin[$j] -match '\$privadaV\s*=') { $iV = $j; break }
    }
}
Comp '5b0. se encuentra el bloque en Say' ($iV -ge 0) ('linea ' + ($iV + 1))
$fV = -1
if ($iV -ge 0) {
    $sangria = ([regex]::Match($lin[$iV], '^(\s*)')).Groups[1].Value
    for ($i = $iV + 1; $i -lt $lin.Count; $i++) { if ($lin[$i] -eq ($sangria + '}')) { $fV = $i; break } }
}
Comp '5b1. y su cierre por sangrado' ($fV -gt $iV) ([string]($fV - $iV + 1) + ' lineas')
if ($fV -gt $iV) {
    $cuerpoV = ($lin[$iV..$fV] -join "`n")
    # los dobles: apuntan por donde salio la frase, y Say-Piper puede fallar a voluntad
    $script:fue = ''
    $script:piperPuede = $true
    function Say-Piper([string]$x) { if ($script:piperPuede) { $script:fue = 'casa'; return $true } ; $script:fue = 'piper-no-pudo'; return $false }
    function Log([string]$m) { $script:logs += @($m) }
    $script:logs = @()
    # se envuelve en una funcion para que el 'return' de dentro corte sin matar el banco
    $fn = [scriptblock]::Create("function Decidir([string]`$t, [bool]`$priv) {`n`$script:respuestaPrivada = `$priv`n$cuerpoV`nreturn 'fuera'`n}")
    . $fn
    # LA FRASE DEL SALDO SE QUEDA EN CASA, ejecutandolo
    $script:fue = ''; $script:piperPuede = $true
    $r1 = Decidir $reales[0].t $false
    Comp '5b2. la del saldo sale por la voz de casa' (($script:fue -eq 'casa') -and ($r1 -ne 'fuera')) ('fue por: ' + $script:fue)
    # UNA NORMAL NO
    $script:fue = ''
    $r2 = Decidir 'Ya esta abierto Steam.' $false
    Comp '5b3. una normal NO pasa por Piper' (($script:fue -eq '') -and ($r2 -eq 'fuera')) ('fue por: ' + $(if ($script:fue) { $script:fue } else { 'la de fuera, como debe' }))
    # Y SI PIPER NO PUEDE, SE SIGUE HABLANDO
    $script:fue = ''; $script:piperPuede = $false; $script:logs = @()
    $r3 = Decidir $reales[0].t $false
    Comp '5b4. si Piper no puede, sigue a la de fuera' ($r3 -eq 'fuera') ''
    # LA BANDERA, EJECUTADA Y NO MIRADA (28/09). Hasta hoy los casos 6a-6e comprobaban el cableado
    # buscando texto en el fichero, y ninguno comprobaba lo unico que importa: que la bandera siga
    # PUESTA cuando Say la lee. No lo estaba -el camino local la bajaba veinticinco lineas antes del
    # Say-, asi que la mitad "bandera" del filtro no habia funcionado nunca y el banco salia verde.
    # Aqui se usa una frase que NO casa con el patron, para que lo unico que pueda mandarla a casa
    # sea la bandera: si alguien vuelve a bajarla antes de tiempo, esto se pone rojo.
    $script:fue = ''; $script:piperPuede = $true
    $r4 = Decidir 'Solo Gover esta conectado, jugando Rocket League.' $true
    Comp '5b8. con la bandera puesta, una frase sin palabras de dinero se queda en casa' (($script:fue -eq 'casa') -and ($r4 -ne 'fuera')) ('fue por: ' + $(if ($script:fue) { $script:fue } else { 'la de fuera' }))
    # y es de UN SOLO USO: la siguiente frase ya no la arrastra (la regla 2, ningun modo se queda
    # puesto). Decidir vuelve a poner la bandera en cada llamada, asi que se mira la variable.
    Comp '5b9. y la bandera queda bajada para la frase siguiente' (-not $script:respuestaPrivada) ('vale ' + [string]$script:respuestaPrivada)
    $script:fue = ''
    $r5 = Decidir 'Ya esta abierto Steam.' $false
    Comp '5b10. y sin bandera, esa misma frase sale por la de fuera' (($script:fue -eq '') -and ($r5 -eq 'fuera')) ''
    Comp '5b5. y lo deja dicho en el log' (@($script:logs | Where-Object { $_ -match 'Piper no pudo' }).Count -eq 1) ''
    $script:piperPuede = $true
    # LA MARCA DE PRIVADO TAMBIEN MANDA, ejecutandola
    $script:fue = ''
    [void](Decidir 'Ahi la tienes.' $true)
    Comp '5b6. y una respuesta privada se queda en casa' ($script:fue -eq 'casa') ''
}

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
Comp '6a. la decision va ANTES de la voz de fuera' ($sinCom.IndexOf('Test-VozLocal $t') -lt $sinCom.IndexOf('if (Say-Online $t $emo)')) ''
Comp '6b. se prueba Piper, que ya estaba escrita' ((Bloque $sinCom 'Test-VozLocal $t') -match 'Say-Piper \$t') ''
Comp '6c. y si Piper no puede, se sigue hablando' ($sinCom -match 'Piper no pudo; va por la de fuera') 'callarse seria peor que decirlo'
# POR ORDEN, COMO EL 6a, Y NO POR DISTANCIA: lo que se protege es que DESPUES de intentar la voz de
# fuera siga habiendo un Say-Piper. La cuenta de 300 caracteres se rompia sola en cuanto se
# escribiera codigo entre las dos, que es justo lo que esta idea vino a quitar.
$iOnline = $sinCom.IndexOf('if (Say-Online $t $emo)')
Comp '6d. la cadena de respaldo sigue entera' (($iOnline -gt 0) -and ($sinCom.IndexOf('Say-Piper $t', $iOnline) -gt $iOnline)) 'Piper sigue siendo el respaldo de siempre'
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
