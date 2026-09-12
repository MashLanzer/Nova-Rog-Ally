param([string]$Probar = "")
# -Probar <archivo>: banco de pruebas. Pasa cada linea del archivo por la
# capa local SIN ejecutar nada y dice cual reconoce y cual no. Sirve para
# medir la cobertura del entendimiento con frases reales del log, en vez
# de tener que decirlas en voz alta una por una.
$ErrorActionPreference = "Stop"

$LogDir = $PSScriptRoot
if (-not $LogDir) { $LogDir = "C:\Users\braya\Documents\voice-ctrl" }

# config.json es OPCIONAL: si falta o esta corrupto se usan los valores por
# defecto de abajo, que son exactamente los que tenia el script hardcodeado.
# Debe ser JSON puro (sin comentarios): ConvertFrom-Json de PS 5.1 no los admite.
$cfg = $null
$cfgPath = Join-Path $LogDir "config.json"
if (Test-Path -LiteralPath $cfgPath) {
    try { $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { $cfg = $null; $cfgError = $_.Exception.Message }
}
function Get-Cfg([string]$section, [string]$key, $default) {
    try {
        if ($cfg -and $cfg.$section -and $null -ne $cfg.$section.$key) { return $cfg.$section.$key }
    } catch {}
    return $default
}

# Vocabulario de comandos locales (ver commands.json). Si falta, todo va a opencode.
$cmds = $null
$cmdsError = $null
$cmdsPath = Join-Path $LogDir "commands.json"
if (Test-Path -LiteralPath $cmdsPath) {
    try { $cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { $cmds = $null; $cmdsError = $_.Exception.Message }
}

$EventLog = Join-Path $LogDir "assistant.log"
$ReplyLog = Join-Path $LogDir "replies.log"

$VK_H = 0x48
$VK_ESCAPE = 0x1B
$VK_LWIN = 0x5B
$VK_MENU = 0x12
$KEYUP = 0x0002

$XINPUT_START = 0x0010
$TRIGGER = $XINPUT_START
$HOLD_MS = [int](Get-Cfg 'input' 'holdMs' 1100)
# Envio automatico: si el dictado deja de producir texto durante este tiempo,
# la orden se manda sola y no hace falta el segundo hold. 0 = desactivado
# (vuelve al comportamiento de pulsar el boton para enviar).
$AutoSubmitMs = [int](Get-Cfg 'input' 'autoSubmitMs' 2500)
# aviso proactivo cuando la bateria baja de este porcentaje (0 = desactivado)
$BateriaAviso = [int](Get-Cfg 'avisos' 'bateriaPct' 15)
# traducir con el modelo lo que la capa local no entienda, y aprenderlo
$TraducirOn = [bool](Get-Cfg 'opencode' 'traducir' $true)
# saludo hablado al arrancar: confirma que la voz funciona
$SaludoOn = [bool](Get-Cfg 'voz' 'saludo' $true)

$OCODECLI = [string](Get-Cfg 'paths' 'opencodeCli' "C:\Users\braya\AppData\Roaming\npm\node_modules\opencode-ai\bin\opencode.exe")
$NODEDIR = [string](Get-Cfg 'paths' 'nodeDir' "C:\Program Files\nodejs")
$WORKDIR = [string](Get-Cfg 'paths' 'workDir' "C:\Users\braya\Documents")
$PopupMs = [int](Get-Cfg 'ui' 'popupMs' 8000)
# el arranque en frio del CLI ronda 1-2 min; 180s se quedaba justo
$CliTimeoutMs = [int](Get-Cfg 'opencode' 'timeoutMs' 240000)
$TmpDir = Join-Path $LogDir "tmp"
# los logs crecian sin cota en un proceso que vive desde el login
$MaxLogBytes = [int](Get-Cfg 'logging' 'maxLogBytes' 5242880)
$KeepLogs = [int](Get-Cfg 'logging' 'keepLogs' 3)

# Rota <log> -> <log>.1 -> <log>.2 ... y descarta lo que pase de $KeepLogs.
function Rotate-Log([string]$path) {
    try {
        if (-not (Test-Path -LiteralPath $path)) { return }
        if ((Get-Item -LiteralPath $path).Length -lt $MaxLogBytes) { return }
        $oldest = "$path.$KeepLogs"
        if (Test-Path -LiteralPath $oldest) { Remove-Item -LiteralPath $oldest -Force -ErrorAction SilentlyContinue }
        for ($i = $KeepLogs - 1; $i -ge 1; $i--) {
            $src = "$path.$i"
            if (Test-Path -LiteralPath $src) { Move-Item -LiteralPath $src -Destination "$path.$($i + 1)" -Force }
        }
        Move-Item -LiteralPath $path -Destination "$path.1" -Force
    } catch {}
}

function Log([string]$msg) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $msg
    Rotate-Log $EventLog
    try { Out-File -FilePath $EventLog -Append -Encoding utf8 -InputObject $line } catch {}
}

# Comillado segun las reglas de CommandLineToArgvW: duplica las barras que
# preceden a una comilla, escapa la comilla y duplica las barras finales.
# Sin esto, un texto dictado con comillas o barras rompe el paso de argumentos.
function ConvertTo-CmdArg([string]$s) {
    if ($null -eq $s) { $s = "" }
    $s = [regex]::Replace($s, '(\\*)"', '$1$1\"')
    $s = [regex]::Replace($s, '(\\+)$', '$1$1')
    return '"' + $s + '"'
}

function Send-Key([int]$vk) {
    [AX]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [AX]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
}

function Send-WinH {
    [AX]::keybd_event([byte]$VK_LWIN, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$VK_H, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]$VK_H, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$VK_LWIN, 0, $KEYUP, [UIntPtr]::Zero)
}

# =====================================================================
# CAPA DE COMANDOS LOCALES (sin LLM)
# "abre steam" tardaba 35 s pasando por el agente; aqui se resuelve en <1 s.
# REGLA: si CUALQUIER parte de la orden no se reconoce, no se ejecuta NADA y
# la frase entera se manda a opencode. Cumplir una orden a medias es peor.
# =====================================================================

# Formas de habla latinoamericana incluidas a proposito: subele/bajale/ponme/
# metete/anda/prende, ademas del imperativo peninsular. Todo va sin tildes
# porque el texto se normaliza antes de comparar.
$VERBOS = '(?:abre|abreme|abrele|abrir|abri|abrime|ejecuta|ejecutame|inicia|iniciame|lanza|lanzame|arranca|arrancame|prende|prendeme|pon|ponme|poneme|ponele|pone|mete|metete|entra|entrate|anda|andate|ve|vete|llevame|muestrame|muestra|ensename|busca|buscame|buscar|busque|googlea|googleame|investiga|sube|subele|subir|aumenta|baja|bajale|bajar|reduce|silencia|silenciar|mutea|pausa|pausar|reproduce|reproducir|play|siguiente|anterior|bloquea|bloquear|cierra|cierrame|cierrate|apaga|escribe|escribeme|teclea|pulsa|presiona|aprieta|dale a|cambia|cambiate|pasate|copia|pega|selecciona|guarda|minimiza|maximiza|enfoca)'

# Muletillas y cortesias que el dictado captura pero que NO son parte de la
# orden. "busca tambien en el navegador X" fallaba justo por esto.
$FILLER_GLOBAL = '\b(?:tambien|ademas|porfa|porfavor|por favor|gracias|oye|okey|dale(?!\s+al?\b)|a ver|quiero que|necesito que|me puedes|puedes|podrias|hazme el favor de)\b'
# "a mi"/"ya me"/"me" salen mucho al dictar ("ya me abre steam", "ábreme")
$FILLER_INI = '^(?:(?:y|luego|despues|ahora|entonces|a mi|ami|ya me|me|pues|este)\s+)+'

# El lugar puede ir ANTES del verbo: "en el navegador busca X". Sin esto, el
# fragmento no empezaba por verbo, se pegaba al anterior y rompia la frase.
$LOCATIVO = '(?:en\s+(?:el\s+|la\s+)?(?:navegador|internet|web|red|explorador|google|youtube|pinterest|bing|amazon|wikipedia|twitch|reddit|github)\s+)'

# Ordenes de ventana: no llevan verbo ("a mitad de pantalla"), asi que hay que
# reconocerlas explicitamente como inicio de fragmento o se pegan a la anterior.
$VENTANA = '(?:(?:a\s+)?(?:la\s+)?(?:mitad de pantalla|media pantalla|mitad|izquierda|derecha)|maximiza|maximizar|pantalla completa|agranda|minimiza|minimizar|achica)'

function Remove-Filler([string]$s) {
    if (-not $s) { return "" }
    $t = [regex]::Replace($s, $FILLER_GLOBAL, ' ')
    $t = [regex]::Replace($t, $FILLER_INI, '')
    return (($t -replace '\s+', ' ').Trim())
}

# minusculas y sin tildes: el dictado no es consistente con los acentos
function ConvertTo-Plain([string]$s) {
    if (-not $s) { return "" }
    $d = $s.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $d.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    $t = $sb.ToString()
    # El dictado antepone signos de apertura, y los patrones anclan en ^: un
    # simple "¿" delante hacia que "¿que hora es" no coincidiera con nada,
    # mientras que "que hora es" si. Aparecio en el log del usuario varias veces.
    $t = $t -replace '[¿?¡!,;:"]', ' '
    return ($t -replace '\s+', ' ').Trim().ToLowerInvariant()
}

# corrige errores tipicos del dictado ("painterest" -> "pinterest")
function Repair-Words([string]$s) {
    if (-not $cmds -or -not $cmds.correcciones) { return $s }
    $out = $s
    foreach ($p in $cmds.correcciones.PSObject.Properties) {
        $out = [regex]::Replace($out, '\b' + [regex]::Escape($p.Name) + '\b', $p.Value)
    }
    return $out
}

# Parte ordenes compuestas. Solo corta en "y"/","/"luego" si lo que sigue
# empieza por un verbo, para no destrozar "busca gatos y perros en google".
# Lista plana de verbos, derivada del propio $VERBOS para no duplicarla.
$VERBOS_LISTA = (($VERBOS -replace '^\(\?:', '') -replace '\)$', '') -split '\|'

# El dictado deforma tambien los verbos ("buscal" por "busca"). Se corrige solo
# la PRIMERA palabra y solo a distancia 1, para no inventar ordenes.
function Repair-Verb([string]$f) {
    if (-not $f) { return $f }
    $partes = $f -split '\s+', 2
    # UNA PALABRA SUELTA NO SE REPARA. Al hacerlo, una palabra cualquiera del
    # castellano se convertia en verbo y, ya reconocida, se ejecutaba saltandose
    # el filtro de ruido (que solo actua cuando la capa local NO entiende):
    # 'pesa' -> 'pega' -> Ctrl+V en lo que tuvieras delante, 'copla' -> Ctrl+C,
    # 'guardia' -> Ctrl+S, 'pasa' -> pausa. Son palabras que salen del altavoz
    # todo el rato. Un verbo solo, sin objeto, casi nunca es una orden util.
    if ($partes.Count -lt 2) { return $f }
    $primera = $partes[0]
    if ($primera.Length -lt 4 -or ($VERBOS_LISTA -contains $primera)) { return $f }
    $mejor = $null
    $mejorD = 999
    foreach ($v in $VERBOS_LISTA) {
        if ([Math]::Abs($v.Length - $primera.Length) -gt 1) { continue }
        $d = Get-Distancia $primera $v
        if ($d -le 1 -and $d -lt $mejorD) { $mejorD = $d; $mejor = $v }
    }
    if (-not $mejor) { return $f }
    if ($partes.Count -gt 1) { return "$mejor $($partes[1])" }
    return $mejor
}

# Verbos que pueden ABRIR una orden nueva sin conector delante. Hablando
# seguido no se dicen: "abre steam inicia little nightmare 3" son dos ordenes.
# Se dejan fuera a proposito los ambiguos en habla normal -"ve", "anda",
# "entra", "pega", "dale a"-, que aparecen dentro de frases sin ser ordenes.
$VERBOS_CORTE = '(?:abre|abreme|abrir|ejecuta|inicia|lanza|arranca|prende|sube|subir|aumenta|baja|bajar|reduce|silencia|pausa|reproduce|bloquea|cierra|apaga|minimiza|maximiza|busca|buscame|buscar|googlea)'

# Detras de estos, lo que viene es CONTENIDO y no otra orden: "busca como abrir
# una lata" es una sola cosa, aunque lleve "abrir" en medio. El corte se apaga
# al verlos y solo lo reabre un conector explicito.
$VERBOS_TEXTO = '(?:busca|buscame|buscar|busque|googlea|googleame|investiga|escribe|escribeme|teclea|muestrame|muestra|ensename)'

function Add-CortesSinConector([string]$s) {
    if (-not $s) { return $s }
    $palabras = $s -split '\s+'
    $out = New-Object System.Collections.ArrayList
    $libre = $false
    for ($i = 0; $i -lt $palabras.Count; $i++) {
        $w = $palabras[$i]
        if ($i -gt 0 -and -not $libre -and $w -match ('^' + $VERBOS_CORTE + '$')) { [void]$out.Add('|') }
        if ($w -match ('^' + $VERBOS_TEXTO + '$')) { $libre = $true }
        elseif ($w -in @('y', 'luego', 'despues', 'ademas', 'tambien')) { $libre = $false }
        [void]$out.Add($w)
    }
    return ($out -join ' ')
}

function Split-Compound([string]$s) {
    # "ademas"/"tambien" son SEPARADORES si les sigue un verbo de accion, y
    # simples muletillas si no. Confundir ambos casos era lo que metia
    # "...ADEMAS sube el volumen" dentro de la busqueda anterior.
    $limpio = [regex]::Replace($s, '\b(?:ademas|tambien)\s+(?=' + $VERBOS + '\b)', ' | ')
    $limpio = Remove-Filler $limpio
    $limpio = Add-CortesSinConector $limpio
    $parts = [regex]::Split($limpio, '\s*(?:\||,|;|\by\s+luego\b|\by\s+despues\b|\bluego\b|\bdespues\b|\by\b)\s*')
    $res = New-Object System.Collections.ArrayList
    foreach ($p in $parts) {
        $t = Repair-Verb (Remove-Filler $p)
        if (-not $t) { continue }
        if ($res.Count -gt 0 -and $t -notmatch ('^' + $LOCATIVO + '?(?:' + $VERBOS + '|' + $VENTANA + ')\b')) {
            # no empieza por verbo: pertenece al fragmento anterior
            # ("busca gatos y perros en google")
            $res[$res.Count - 1] = $res[$res.Count - 1] + ' y ' + $t
        } else {
            [void]$res.Add($t)
        }
    }
    return $res.ToArray()
}

function Test-Prop($obj, [string]$name) {
    if (-not $obj) { return $false }
    return ($obj.PSObject.Properties.Name -contains $name)
}

# Distancia de Levenshtein: cuantas ediciones separan dos palabras.
function Get-Distancia([string]$a, [string]$b) {
    $n = $a.Length; $m = $b.Length
    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }
    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $c = if ($a[$i - 1] -eq $b[$j - 1]) { 0 } else { 1 }
            # con variables intermedias a proposito: el parser de PS 5.1 no
            # traga un indice bidimensional dentro de una llamada a metodo
            $borrar = $d[($i - 1), $j] + 1
            $insertar = $d[$i, ($j - 1)] + 1
            $sustituir = $d[($i - 1), ($j - 1)] + $c
            $min = $borrar
            if ($insertar -lt $min) { $min = $insertar }
            if ($sustituir -lt $min) { $min = $sustituir }
            $d[$i, $j] = $min
        }
    }
    return $d[$n, $m]
}

# Distancia FONETICA. Lo que confunde el dictado casi nunca son letras al azar:
# son sonidos parecidos, y sobre todo vocales. "stein" por "steam" son dos
# ediciones -la vocal y la nasal final- y con el tope del 34% una palabra de
# cinco letras solo perdona una: por eso "abre stein" acababa en el agente.
# Aqui una confusion de ese tipo cuesta la mitad que un cambio cualquiera.
# El coste va DOBLADO para no arrastrar decimales: 2 = una edicion entera,
# 1 = media. El que llama compara contra su tope tambien doblado.
$script:GruposFon = @(
    'aeiou',    # vocales entre si: el error mas comun con diferencia
    'bvp',
    'ckq',
    'szc',      # seseo
    'gj',
    'mn',       # nasales: "stein"/"steam"
    'dt',
    'rl',
    'yi'
)

function Test-MismoSonido([char]$x, [char]$y) {
    foreach ($g in $script:GruposFon) {
        if ($g.IndexOf($x) -ge 0 -and $g.IndexOf($y) -ge 0) { return $true }
    }
    return $false
}

function Get-DistanciaFon([string]$a, [string]$b) {
    $n = $a.Length; $m = $b.Length
    if ($n -eq 0) { return ($m * 2) }
    if ($m -eq 0) { return ($n * 2) }
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i * 2 }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j * 2 }
    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $ca = $a[$i - 1]; $cb = $b[$j - 1]
            if ($ca -eq $cb) { $c = 0 }
            elseif (Test-MismoSonido $ca $cb) { $c = 1 }
            else { $c = 2 }
            $borrar = $d[($i - 1), $j] + 2
            $insertar = $d[$i, ($j - 1)] + 2
            $sustituir = $d[($i - 1), ($j - 1)] + $c
            $min = $borrar
            if ($insertar -lt $min) { $min = $insertar }
            if ($sustituir -lt $min) { $min = $sustituir }
            $d[$i, $j] = $min
        }
    }
    return $d[$n, $m]
}

# El dictado deforma los nombres sin parar ("Team", "steamidos", "espotifai").
# Perseguirlos uno a uno con una lista fija es una carrera perdida: aqui se
# acepta la clave conocida que aparezca dentro de lo dictado, o la que quede
# a pocas ediciones de distancia.
function Find-Aproximado([string]$t, $obj) {
    if (-not $obj -or -not $t) { return $null }
    # Con dos o tres letras se llega a casi cualquier nombre corto en dos
    # ediciones: 'el' -> 'edge'. Y el ruido del microfono son justo palabras
    # asi ('el', 'es', 'eh', 'los'). Sin un minimo de longitud, cualquier
    # carraspeo abria una aplicacion. Los nombres que se dicen enteros siguen
    # funcionando: la coincidencia exacta se comprueba antes que esta.
    if ($t.Length -lt 4) { return $null }
    $mejor = $null
    $mejorD = 999
    foreach ($p in $obj.PSObject.Properties) {
        $k = $p.Name
        if ($k.Length -ge 4 -and $t -match ('\b' + [regex]::Escape($k))) { return $k }
        # tope en la misma escala doblada que Get-DistanciaFon
        $tope = [Math]::Max(2, [int][Math]::Floor($k.Length * 0.34) * 2)
        $d = Get-DistanciaFon $t $k
        if ($d -le $tope -and $d -lt $mejorD) { $mejorD = $d; $mejor = $k }
    }
    # a una edicion entera o mas ya no es seguro: se marca para confirmar
    if ($mejor -and $mejorD -ge 2) { $script:dudosa = $mejor }
    return $mejor
}

# Normaliza un titulo de juego: sin tildes ni puntuacion y con los numeros
# romanos pasados a arabigos, para que "Little Nightmares III" y lo que dicta
# Windows ("little nighters 3") puedan compararse.
function ConvertTo-Juego([string]$s) {
    $t = ConvertTo-Plain $s
    $t = $t -replace '[^\w\s]', ' '
    $t = [regex]::Replace($t, '\biii\b', '3')
    $t = [regex]::Replace($t, '\bii\b', '2')
    $t = [regex]::Replace($t, '\biv\b', '4')
    $t = [regex]::Replace($t, '\bvi\b', '6')
    $t = [regex]::Replace($t, '\bv\b', '5')
    $t = [regex]::Replace($t, '\bi\b', '1')
    return (($t -replace '\s+', ' ').Trim())
}

# Lee la biblioteca de Steam del disco (appmanifest_*.acf). Es la unica forma
# de lanzar un juego por su nombre sin preguntarle a un LLM.
function Get-JuegosSteam {
    $res = @()
    try {
        $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
        if (-not $sp) { return $res }
        $libs = New-Object System.Collections.ArrayList
        [void]$libs.Add(($sp -replace '/', '\'))
        $vdf = Join-Path ($sp -replace '/', '\') 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($l in ((Get-Content -LiteralPath $vdf -Raw) -split "`n")) {
                if ($l -match '"path"\s*"([^"]+)"') { [void]$libs.Add(($Matches[1] -replace '\\\\', '\')) }
            }
        }
        $vistos = @{}
        foreach ($lib in ($libs | Select-Object -Unique)) {
            $d = Join-Path ($lib -replace '/', '\') 'steamapps'
            if (-not (Test-Path -LiteralPath $d)) { continue }
            foreach ($f in (Get-ChildItem -LiteralPath $d -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue)) {
                $c = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($c -match '"appid"\s*"(\d+)"') { $id = $Matches[1] } else { continue }
                if ($c -match '"name"\s*"([^"]+)"') { $nm = $Matches[1] } else { continue }
                if ($vistos.ContainsKey($id)) { continue }
                $vistos[$id] = $true
                # los redistribuibles no son juegos
                if ($nm -match '(?i)redistributable|proton|steam linux runtime|steamworks') { continue }
                $res += @{ id = $id; nombre = $nm; plano = (ConvertTo-Juego $nm) }
            }
        }
    } catch {}
    return $res
}

# Relee la biblioteca, como mucho una vez por minuto. Devuelve $true si releyo.
# Sin esto, un juego instalado despues de arrancar no existiria para el
# asistente hasta el siguiente reinicio.
$script:JuegosStamp = [DateTime]::MinValue
function Update-Juegos {
    if (((Get-Date) - $script:JuegosStamp).TotalSeconds -lt 60) { return $false }
    $antes = @($script:Juegos).Count
    $script:Juegos = Get-JuegosSteam
    $script:JuegosStamp = Get-Date
    $ahora = @($script:Juegos).Count
    if ($ahora -ne $antes) { Log "biblioteca de Steam actualizada: $antes -> $ahora juegos" }
    return $true
}

function Find-JuegoEn([string]$q, $lista) {
    if (-not $lista -or @($lista).Count -eq 0) { return $null }
    # Se puntua a TODOS y se elige el mejor. Devolver el primero que "contiene"
    # hacia que "outlast 2" acabara abriendo "Outlast", porque ese aparecia antes.
    $mejor = $null
    $mejorPuntos = 9999
    foreach ($j in $lista) {
        $n = $j.plano
        if ($n -eq $q) { return $j }
        $puntos = $null
        # UNA CONSULTA CORTA 'CONTIENE' A MEDIA BIBLIOTECA. 'el' esta dentro de
        # 'elden ring', y como la contencion puntuaba mejor que cualquier
        # parecido, un simple articulo abria el juego SIN preguntar siquiera.
        # Salio en el corpus de ruido real: 'el' -> ELDEN RING, 'es' -> Little
        # Nightmares. Para que la contencion valga, el trozo tiene que ser
        # sustancial: al menos cuatro letras y un 40 % del titulo.
        if ($q.Length -lt 4) { continue }
        # Contains() es subcadena cruda: 'speaker' contiene 'peak' y lanzaba
        # PEAK; 'ring' cabe en 'elden ring' y lanzaba ELDEN RING. Y como la
        # contencion puntua por debajo de 100, ni siquiera pedia confirmacion.
        # Ahora tiene que ser una PALABRA entera y cubrir la mayor parte del
        # titulo. Al reves (lo dicho contiene al titulo) sigue valiendo tal cual:
        # 'outlast dos' para 'Outlast 2'.
        $contiene = $false
        if ($n -match ('\b' + [regex]::Escape($q) + '\b') -and $q.Length -ge $n.Length * 0.6) { $contiene = $true }
        elseif ($q -match ('\b' + [regex]::Escape($n) + '\b')) { $contiene = $true }
        if ($contiene) {
            $puntos = [Math]::Abs($n.Length - $q.Length)
        } else {
            $d = Get-Distancia $q $n
            # En titulos cortos, un tope de 2 llega a casi cualquier palabra de
            # cuatro letras: 'pesa' acababa en PEAK. Con menos de seis letras se
            # exige practicamente clavarlo.
            $tope = if ($n.Length -lt 6) { 1 } else { [Math]::Max(2, [int][Math]::Floor($n.Length * 0.35)) }
            # +100: cualquier contencion es mejor pista que un parecido lejano
            if ($d -le $tope) { $puntos = $d + 100 }
        }
        if ($null -ne $puntos -and $puntos -lt $mejorPuntos) { $mejorPuntos = $puntos; $mejor = $j }
    }
    # acertado solo por parecido lejano (no por contencion): mejor preguntar
    # "¿Little Nightmares III?" que lanzar el juego equivocado
    if ($mejor -and $mejorPuntos -ge 100) { $script:dudosa = $mejor.nombre }
    return $mejor
}

function Find-Juego([string]$t) {
    $q = ConvertTo-Juego ($t -replace '^juego\s+', '')
    if (-not $q) { return $null }
    $j = Find-JuegoEn $q $script:Juegos
    if ($j) { return $j }
    # Ningun titulo encaja: puede ser un juego instalado DESPUES de arrancar.
    # Se relee la biblioteca (con tope de una vez por minuto) y se reintenta.
    if (Update-Juegos) { return (Find-JuegoEn $q $script:Juegos) }
    return $null
}

# Nombre hablado de una app -> nombre de PROCESO, para cerrarla o traerla al
# frente. Se saca del ejecutable de commands.json; los URI (steam://, spotify:)
# tienen su proceso conocido a mano.
$PROCESOS_URI = @{ 'steam' = 'steam'; 'spotify' = 'Spotify'; 'discord' = 'Discord'; 'xbox' = 'XboxPcApp'; 'camara' = 'WindowsCamera';
                   'configuracion' = 'SystemSettings'; 'ajustes' = 'SystemSettings'; 'armoury crate' = 'ArmouryCrate'; 'armoury' = 'ArmouryCrate' }
# Programas de usuario abiertos: los que tienen ventana con titulo. Se dejan
# fuera el propio asistente, su capsula, el escritorio y la barra de tareas,
# que no son "programas" para quien habla y cerrarlos romperia la sesion.
$PROCESOS_INTOCABLES = @('explorer', 'nova_ui', 'powershell', 'pwsh', 'ApplicationFrameHost',
                         'TextInputHost', 'SystemSettings', 'ShellExperienceHost', 'SearchHost')

function Get-AppsAbiertas {
    $res = @()
    foreach ($pr in (Get-Process -ErrorAction SilentlyContinue)) {
        try {
            if (-not $pr.MainWindowTitle) { continue }
            if ($pr.Id -eq $PID) { continue }
            if ($PROCESOS_INTOCABLES -contains $pr.ProcessName) { continue }
            $res += $pr
        } catch {}
    }
    return $res
}

# --- JUEGOS COLGADOS (zombis) ---
# El 11/09 habia un Outlast 2 vivo desde hacia mas de tres horas, sin ventana
# en ninguna parte (ni barra de tareas ni Alt+Tab) pero sonando y quemando
# CPU. No se podia cerrar porque no se podia ver. La firma es esa: proceso de
# un juego, SIN ventana, y comiendo procesador sin parar.
# El ultimo detalle es el que evita los falsos positivos: Wallpaper Engine
# tampoco tiene ventana y tambien esta en steamapps, pero gasta un 3 % de un
# nucleo; el juego colgado gastaba un 87 %.
$ZombiMinutos = 20
$ZombiUsoCPU = 0.30       # fraccion de un nucleo, sostenida desde que arranco
$script:zombisAvisados = @{}
$script:zombiCheck = 0

# ¿El repaso del oido fino tiene algo que ver con lo que se oyo primero?
# Al modelo preciso se le pasa la lista de tus apps y juegos como pista, y con
# audio que no es voz eso le hace INVENTARSE uno de esos nombres: 'los' salio
# como 'SILENT BREATH' y se abrio el juego. Si las dos transcripciones no
# comparten ni un trozo de palabra, no es que oyera mejor: es que se lo invento.
# 'abrestean' -> 'abre steam' si comparte ('abre' esta dentro), y ese es el caso
# para el que existe el repaso.
# LA FIRMA DE LA ALUCINACION DE WHISPER.
# A Whisper se le pasan tus apps y juegos como pistas (hotwords) para que
# acierte los nombres propios. El efecto secundario es que, cuando lo que oye
# NO es voz, devuelve justo esos nombres, en fila y separados por comas:
#   'SILENT BREATH, PEAK, Hollow Knight, Outlast 2, Little Nightmares III,'
#   'Engine, Little Nightmares II, Goose Duck, REANIMAL,'
# La capa local se lo tragaba como una orden multiple y abria los cinco juegos.
# Salieron 6 casos asi en los 103 dictados reales del log. Nadie pide abrir
# cinco juegos de golpe y sin un verbo: eso no es una orden, es el modelo
# recitando el catalogo que le dimos.
function Test-CatalogoRecitado([string]$text) {
    if (-not $cmds -or -not $text) { return $false }
    # OJO: las comas se miran en el texto ORIGINAL. ConvertTo-Plain las
    # convierte en espacios (para que '¿que hora es' case con los patrones),
    # asi que sobre el plano esta senal no existe y la funcion no detectaba
    # nada en absoluto.
    if ($text -notmatch ',') { return $false }
    $plano = ConvertTo-Plain $text
    if ($plano -match ('\b(?:' + $VERBOS + ')\b')) { return $false }   # con verbo es una orden de verdad
    $trozos = @($text -split ',' | ForEach-Object { (ConvertTo-Plain $_).Trim() } | Where-Object { $_ })
    if ($trozos.Count -lt 2) { return $false }
    $delCatalogo = 0
    foreach ($t in $trozos) {
        $esNombre = $false
        if (Test-Prop $cmds.apps $t) { $esNombre = $true }
        elseif (Test-Prop $cmds.sitios $t) { $esNombre = $true }
        elseif (Find-Juego $t) { $esNombre = $true }
        if ($esNombre) { $delCatalogo++ }
    }
    # Basta UNO. Al exigir dos se colaba 'Enhanced Edition, Outlast, Throne,':
    # solo 'Outlast' emparejaba con la biblioteca y los otros dos eran restos
    # del mismo destrozo, asi que el filtro lo dejaba pasar y abria el juego.
    # Una enumeracion por comas, sin un solo verbo, con un nombre de tu
    # biblioteca dentro, no es una orden que hayas dado: es el modelo
    # recitando. Si de verdad quieres abrir dos cosas, di el verbo:
    # 'abre steam y discord'.
    return ($delCatalogo -ge 1)
}

function Test-MismoAudio([string]$a, [string]$b) {
    $pa = ConvertTo-Plain $a
    $pb = ConvertTo-Plain $b
    if (-not $pa -or -not $pb) { return $false }
    foreach ($w in @($pa -split '\s+')) {
        if ($w.Length -lt 4) { continue }
        if ($pb -like "*$w*") { return $true }
    }
    foreach ($w in @($pb -split '\s+')) {
        if ($w.Length -lt 4) { continue }
        if ($pa -like "*$w*") { return $true }
    }
    return $false
}

# El parametro existe para poder PROBARLA: el banco le pasa procesos de
# mentira (uno colgado, Wallpaper Engine, uno con ventana...) y comprueba a
# cuales senala. Sin eso solo se puede mirar lo que haya abierto en ese
# momento, que casi nunca es lo interesante. En uso normal no se le pasa nada.
function Get-JuegosZombis([object[]]$procesos) {
    $res = @()
    $ahora = Get-Date
    if (-not $procesos) { $procesos = @(Get-Process -ErrorAction SilentlyContinue) }
    foreach ($pr in $procesos) {
        try {
            $ruta = $pr.Path
            if (-not $ruta -or $ruta -notmatch '(?i)steamapps\\common\\([^\\]+)') { continue }
            $carpeta = $Matches[1]
            # utilidades de escritorio que viven sin ventana a proposito
            if ($carpeta -match '(?i)wallpaper_engine|steamvr|proton|steam linux runtime') { continue }
            if ($pr.MainWindowTitle) { continue }        # tiene ventana: esta vivo y lo ves
            $mins = ($ahora - $pr.StartTime).TotalMinutes
            if ($mins -lt $ZombiMinutos) { continue }
            $uso = 0.0
            if ($mins -gt 0) { $uso = $pr.CPU / ($mins * 60.0) }
            if ($uso -lt $ZombiUsoCPU) { continue }
            $j = Find-Juego $carpeta
            $nombre = if ($j) { $j.nombre } else { $carpeta }
            if ($script:juegoActivo -and $nombre -eq $script:juegoActivo) { continue }
            $res += @{ proc = $pr; nombre = $nombre; minutos = [int]$mins; uso = $uso }
        } catch {}
    }
    return $res
}

function Resolve-Proceso([string]$t) {
    if (-not $t -or -not $cmds) { return $null }
    $t = ($t -replace '^(?:a|al|el|la|los|las|mi|un|una)\s+', '').Trim()
    $t = Repair-Words $t
    $k = $null
    if (Test-Prop $cmds.apps $t) {
        $k = $t
    } elseif (@($t -split '\s+').Count -le 3) {
        # El MISMO limite que Resolve-Target, y por el mismo motivo: buscar por
        # parecido dentro de una frase larga encuentra cualquier nombre suelto.
        # Aqui era peor, porque lo que se resuelve es a quien CERRAR: 'cierra la
        # ventana del navegador que tengo abierta ahora mismo' acababa en
        # cerrarApp msedge. Si la frase es larga y no se entiende, que la mire
        # el modelo.
        $k = Find-Aproximado $t $cmds.apps
    }
    if (-not $k) {
        # tambien un juego instalado: "cierra elden ring"
        $j = Find-Juego $t
        if ($j -and $script:juegoActivo -and $j.nombre -eq $script:juegoActivo) { return @{ proceso = '*juego*'; nombre = $j.nombre } }
        return $null
    }
    $target = [string]$cmds.apps.$k
    $proc = $null
    if ($PROCESOS_URI.ContainsKey($k)) { $proc = $PROCESOS_URI[$k] }
    elseif ($target -match '^([\w\-. ]+)\.exe$') { $proc = $Matches[1] }
    elseif ($target -match '\\([\w\-. ]+)\.exe$') { $proc = $Matches[1] }
    if (-not $proc) { return $null }
    return @{ proceso = $proc; nombre = $k }
}

# Resuelve un nombre suelto contra apps, sitios conocidos o un dominio.
function Resolve-Target([string]$t) {
    if (-not $t) { return $null }
    $t = ($t -replace '^(?:a|al|el|la|los|las|mi|un|una)\s+', '').Trim()
    # "…en steam" es una pista fuerte de que se pide un JUEGO, no una app
    $pistaJuego = $false
    if ($t -match '\s+en\s+steam$') {
        $t = ($t -replace '\s+en\s+steam$', '').Trim()
        $pistaJuego = $true
    }
    if ($pistaJuego) {
        $j = Find-Juego $t
        if ($j) { return @(@{ kind = 'app'; target = "steam://rungameid/$($j.id)"; desc = "abrir $($j.nombre) en Steam" }) }
        return $null
    }
    if (Test-Prop $cmds.apps $t) { return @(@{ kind = 'app'; target = [string]$cmds.apps.$t; desc = "abrir $t" }) }
    if (Test-Prop $cmds.sitios $t) { return @(@{ kind = 'url'; url = [string]$cmds.sitios.$t; desc = "abrir $t" }) }
    # un titulo de la biblioteca, aunque no se haya dicho "en steam"
    $j = Find-Juego $t
    if ($j) { return @(@{ kind = 'app'; target = "steam://rungameid/$($j.id)"; desc = "abrir $($j.nombre) en Steam" }) }
    if ($t -match '^[\w\-]+\.(?:com|es|org|net|io|tv|gg|dev|app|mx|co|ar|cl)$') {
        return @(@{ kind = 'url'; url = "https://$t"; desc = "abrir $t" })
    }
    # La aproximacion SOLO para objetivos cortos. Aplicarla a una frase larga y
    # deforme hacia que "Freelesign en el navegador buscal Pinterest" encontrase
    # "navegador" dentro, abriera el navegador y se comiera el resto de la orden.
    # Si la frase es larga y no se entiende, es mejor mandarla entera a opencode.
    if (($t -split '\s+').Count -le 3) {
        $ap = Find-Aproximado $t $cmds.apps
        if ($ap) { return @(@{ kind = 'app'; target = [string]$cmds.apps.$ap; desc = "abrir $ap" }) }
        $ap = Find-Aproximado $t $cmds.sitios
        if ($ap) { return @(@{ kind = 'url'; url = [string]$cmds.sitios.$ap; desc = "abrir $ap" }) }
    }
    return $null
}

# Devuelve un ARRAY de acciones, o $null si no reconoce el fragmento.
# Array porque "sube el volumen y el brillo" son DOS acciones en una frase:
# antes se tragaba todo dentro de la busqueda.
# --- Memoria permanente (vault de Obsidian dentro del proyecto) ---
# Guardar es LOCAL e instantaneo; recordar necesita a opencode (ver README del
# vault). Separarlo asi evita esperar un minuto por escribir una linea.
$MemoriaDir = Join-Path $LogDir "memoria"
$DiarioDir = Join-Path $MemoriaDir "diario"

function Add-Memoria([string]$texto) {
    if (-not (Test-Path -LiteralPath $DiarioDir)) { New-Item -ItemType Directory -Force -Path $DiarioDir | Out-Null }
    $nota = Join-Path $DiarioDir ((Get-Date -Format 'yyyy-MM-dd') + '.md')
    if (-not (Test-Path -LiteralPath $nota)) {
        # cultura explicita: si no, la cabecera sale medio en ingles
        $cul = New-Object System.Globalization.CultureInfo('es-MX')
        $cab = "# " + (Get-Date).ToString('dddd d "de" MMMM "de" yyyy', $cul) + "`r`n"
        [System.IO.File]::WriteAllText($nota, $cab, (New-Object System.Text.UTF8Encoding($false)))
    }
    $linea = "`r`n- **" + (Get-Date -Format 'HH:mm') + "** " + $texto
    [System.IO.File]::AppendAllText($nota, $linea, (New-Object System.Text.UTF8Encoding($false)))
    return $nota
}

# --- BUSQUEDA LOCAL EN LA MEMORIA (sin modelo) ---
# "que sabes de X" iba siempre al agente (25-60 s). Casi siempre basta con
# buscar las palabras clave en las notas y leer las lineas que las contienen:
# <1 s. Solo si no se encuentra nada se pregunta al modelo, como antes.
$PALABRAS_VACIAS = @('que','sabes','sobre','de','del','la','el','los','las','un','una','unos','unas','te','dije','dijo',
    'anote','apunte','recuerdas','acuerdas','en','tus','mis','notas','mi','memoria','me','lo','le','se','y','o','a',
    'con','por','para','al','es','era','hay','tengo','tienes','tiene','como','cuando','donde','cual','quien','algo',
    'esto','eso','ese','esa','este','esta','hoy','ayer','ahora','dime','cuentame','acerca','respecto','guardaste')

function Find-EnMemoria([string]$text) {
    $plano = ConvertTo-Plain $text
    $claves = @($plano -split '\s+' | Where-Object { $_.Length -ge 3 -and $PALABRAS_VACIAS -notcontains $_ })
    if ($claves.Count -eq 0) { return $null }
    $archivos = @()
    foreach ($d in @($DiarioDir, (Join-Path $MemoriaDir 'temas'))) {
        if (Test-Path -LiteralPath $d) {
            $archivos += Get-ChildItem -LiteralPath $d -Filter '*.md' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        }
    }
    $hallazgos = New-Object System.Collections.ArrayList
    foreach ($f in $archivos) {
        $lineas = @()
        try { $lineas = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8) } catch { continue }
        foreach ($l in $lineas) {
            if ($l -match '^\s*#' -or $l.Trim().Length -lt 4) { continue }
            $lp = ConvertTo-Plain $l
            $puntos = 0
            foreach ($c in $claves) {
                # prefijo o distancia 1 en palabras largas: "recetas" ~ "receta"
                if ($lp -match ('\b' + [regex]::Escape($c))) { $puntos++; continue }
                if ($c.Length -ge 5) {
                    foreach ($w in ($lp -split '\s+')) {
                        if ([Math]::Abs($w.Length - $c.Length) -le 1 -and (Get-Distancia $w $c) -le 1) { $puntos++; break }
                    }
                }
            }
            if ($puntos -gt 0) {
                $limpio = ($l -replace '^\s*-\s*', '' -replace '\*\*(\d\d:\d\d)\*\*\s*', '' -replace '\s+', ' ').Trim()
                $fecha = ''
                if ($f.BaseName -match '^(\d{4})-(\d{2})-(\d{2})$') {
                    $cul = New-Object System.Globalization.CultureInfo('es-MX')
                    try { $fecha = (Get-Date -Year $Matches[1] -Month $Matches[2] -Day $Matches[3]).ToString('d "de" MMMM', $cul) } catch {}
                } else { $fecha = $f.BaseName }
                [void]$hallazgos.Add(@{ puntos = $puntos; texto = $limpio; fecha = $fecha; orden = $hallazgos.Count })
            }
        }
    }
    if ($hallazgos.Count -eq 0) { return $null }
    $mejores = @($hallazgos | Sort-Object @{e={$_.puntos};d=$true}, @{e={$_.orden}} | Select-Object -First 3)
    $frases = @()
    foreach ($h in $mejores) {
        $frases += if ($h.fecha) { "$($h.texto) (el $($h.fecha))" } else { $h.texto }
    }
    $intro = if ($mejores.Count -eq 1) { "Anotaste: " } else { "Encontre esto: " }
    return ($intro + ($frases -join '. '))
}

# --- ESTADISTICAS DE USO (memoria\estadisticas.md) ---
# Que ruta toma cada orden y que no se reconocio, en una nota de Obsidian que
# se puede leer sin abrir logs. Dice exactamente que anadir a commands.json.
$EstadisticasJson = Join-Path $MemoriaDir 'estadisticas.json'
$EstadisticasMd = Join-Path $MemoriaDir 'estadisticas.md'
$script:stats = $null

function Get-Estadisticas {
    if ($null -ne $script:stats) { return $script:stats }
    $script:stats = @{ dias = @{}; descartes = @(); recientes = @() }
    if (Test-Path -LiteralPath $EstadisticasJson) {
        try {
            $j = Get-Content -LiteralPath $EstadisticasJson -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($d in $j.dias.PSObject.Properties) {
                $h = @{}
                foreach ($k in $d.Value.PSObject.Properties) { $h[$k.Name] = [int]$k.Value }
                $script:stats.dias[$d.Name] = $h
            }
            $script:stats.descartes = @($j.descartes | ForEach-Object { [string]$_ })
            $script:stats.recientes = @($j.recientes | ForEach-Object { [string]$_ })
        } catch {}
    }
    return $script:stats
}

function Add-Estadistica([string]$ruta, [string]$detalle = '') {
    try {
        $s = Get-Estadisticas
        $dia = Get-Date -Format 'yyyy-MM-dd'
        if (-not $s.dias.ContainsKey($dia)) { $s.dias[$dia] = @{} }
        if (-not $s.dias[$dia].ContainsKey($ruta)) { $s.dias[$dia][$ruta] = 0 }
        $s.dias[$dia][$ruta]++
        # humor de la capsula: aciertos frente a errores de hoy y ayer
        try {
            $ok = 0; $mal = 0
            foreach ($k in @($dia, (Get-Date).AddDays(-1).ToString('yyyy-MM-dd'))) {
                if (-not $s.dias.ContainsKey($k)) { continue }
                foreach ($r in @('local', 'aprendida', 'memoria', 'traducida')) { if ($s.dias[$k].ContainsKey($r)) { $ok += $s.dias[$k][$r] } }
                if ($s.dias[$k].ContainsKey('error')) { $mal += $s.dias[$k]['error'] }
            }
            $script:uiAnimo = [Math]::Max(-1.0, [Math]::Min(1.0, ($ok - 2.0 * $mal) / [Math]::Max(10.0, $ok + $mal)))
        } catch {}
        $d = ($detalle -replace '\s+', ' ').Trim()
        if ($d.Length -gt 90) { $d = $d.Substring(0, 87) + '...' }
        if ($ruta -eq 'descarte' -and $d) {
            $s.descartes = @(@("$dia  $d") + @($s.descartes | Where-Object { $_ -notmatch ('  ' + [regex]::Escape($d) + '$') }) | Select-Object -First 30)
        } elseif ($d) {
            $s.recientes = @(@((Get-Date -Format 'yyyy-MM-dd HH:mm') + "  [$ruta]  $d") + $s.recientes | Select-Object -First 40)
        }
        # json (estado) + markdown (lectura)
        $o = New-Object PSObject
        $dias = New-Object PSObject
        foreach ($k in ($s.dias.Keys | Sort-Object)) {
            $fila = New-Object PSObject
            foreach ($r in $s.dias[$k].Keys) { $fila | Add-Member -NotePropertyName $r -NotePropertyValue $s.dias[$k][$r] }
            $dias | Add-Member -NotePropertyName $k -NotePropertyValue $fila
        }
        $o | Add-Member -NotePropertyName dias -NotePropertyValue $dias
        $o | Add-Member -NotePropertyName descartes -NotePropertyValue @($s.descartes)
        $o | Add-Member -NotePropertyName recientes -NotePropertyValue @($s.recientes)
        $enc = New-Object System.Text.UTF8Encoding($false)
        if (-not (Test-Path -LiteralPath $MemoriaDir)) { New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null }
        [System.IO.File]::WriteAllText($EstadisticasJson, ($o | ConvertTo-Json -Depth 6), $enc)

        $rutas = @('activacion', 'local', 'aprendida', 'memoria', 'pregunta', 'traducir', 'traducida', 'accion', 'charla', 'ruido', 'descarte', 'error')
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# Estadísticas del asistente")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Actualizado: " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ". La genera el asistente sola; no hace falta editarla.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("**activacion**: veces que se desperto al oir su nombre. **ruido**: lo que se descarto por no ser una orden.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Rutas: **local** (<1 s, sin modelo), **aprendida** (traducción guardada), **memoria** (búsqueda en notas), **pregunta** (modelo sin herramientas), **traducir** → **traducida** (el modelo la convirtió a una orden local y se aprendió), **accion** (agente completo), **charla**, **descarte** (trozo que la capa local no entendió).")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Por día")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| día | " + ($rutas -join ' | ') + " |")
        [void]$sb.AppendLine("|---|" + (($rutas | ForEach-Object { '---:' }) -join '|') + "|")
        foreach ($k in ($s.dias.Keys | Sort-Object -Descending | Select-Object -First 30)) {
            $celdas = $rutas | ForEach-Object { if ($s.dias[$k].ContainsKey($_)) { $s.dias[$k][$_] } else { '' } }
            [void]$sb.AppendLine("| $k | " + ($celdas -join ' | ') + " |")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Falsas alarmas")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("De cada vez que se desperto al oir su nombre, cuantas acabaron sin ejecutar nada.")
        [void]$sb.AppendLine("Si sube, el microfono esta cazando ruido; si las activaciones caen a cero, se ha vuelto sordo.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| día | activaciones | en nada | % |")
        [void]$sb.AppendLine("|---|---:|---:|---:|")
        foreach ($k in ($s.dias.Keys | Sort-Object -Descending | Select-Object -First 14)) {
            $act = 0; $nada = 0
            if ($s.dias[$k].ContainsKey('activacion')) { $act = $s.dias[$k]['activacion'] }
            foreach ($r in @('ruido', 'descarte', 'error')) { if ($s.dias[$k].ContainsKey($r)) { $nada += $s.dias[$k][$r] } }
            $pct = if ($act -gt 0) { [int](100.0 * $nada / $act) } else { 0 }
            [void]$sb.AppendLine("| $k | $act | $nada | $pct % |")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## No reconocido por la capa local (añadir a commands.json)")
        [void]$sb.AppendLine("")
        if ($s.descartes.Count -eq 0) { [void]$sb.AppendLine("_nada todavía_") }
        foreach ($x in $s.descartes) { [void]$sb.AppendLine("- " + $x) }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Últimas órdenes")
        [void]$sb.AppendLine("")
        foreach ($x in $s.recientes) { [void]$sb.AppendLine("- " + $x) }
        # gestos de la capsula (tmp\gestos.log, lo escribe nova_ui.exe): cuantos
        # carinos, negaciones, dudas... por dia. Un termometro de la relacion.
        try {
            $gl = Join-Path $TmpDir 'gestos.log'
            if (Test-Path -LiteralPath $gl) {
                $lineasG = [System.IO.File]::ReadAllLines($gl, [System.Text.Encoding]::UTF8)
                if ($lineasG.Count -gt 6000) {
                    $lineasG = $lineasG[($lineasG.Count - 5000)..($lineasG.Count - 1)]
                    [System.IO.File]::WriteAllLines($gl, [string[]]$lineasG, $enc)
                }
                $porDia = @{}
                foreach ($l in $lineasG) {
                    if ($l -match '^(\d{4}-\d{2}-\d{2}) \S+ (\S+)$') {
                        $g = $Matches[2]
                        if ($g -in @('escucho', 'lotengo', 'atencion')) { continue }   # ruido: pasan a cada rato
                        if (-not $porDia.ContainsKey($Matches[1])) { $porDia[$Matches[1]] = @{} }
                        if (-not $porDia[$Matches[1]].ContainsKey($g)) { $porDia[$Matches[1]][$g] = 0 }
                        $porDia[$Matches[1]][$g]++
                    }
                }
                if ($porDia.Count -gt 0) {
                    [void]$sb.AppendLine("")
                    [void]$sb.AppendLine("## Gestos de la cápsula")
                    [void]$sb.AppendLine("")
                    [void]$sb.AppendLine("Lo que le dijiste y cómo reaccionó: cariño, gracias, risa, negar, duda, pena, orgullo…")
                    [void]$sb.AppendLine("")
                    foreach ($k in ($porDia.Keys | Sort-Object -Descending | Select-Object -First 14)) {
                        $partes = $porDia[$k].GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { "$($_.Key) ×$($_.Value)" }
                        [void]$sb.AppendLine("- **$k**: " + ($partes -join ', '))
                    }
                }
            }
        } catch {}
        [System.IO.File]::WriteAllText($EstadisticasMd, $sb.ToString(), $enc)
    } catch { Log ("estadisticas: " + $_.Exception.Message) }
}

function Resolve-Fragment([string]$f) {
    # --- perfiles: una frase, varias acciones ("modo juego") ---
    if ($f -match '^(?:modo|activa el modo|activa modo|pon el modo|pon modo|ponte en modo|cambia a modo|entra en modo)\s+(.+)$') {
        $nombre = $Matches[1].Trim()
        if (Test-Prop $cmds.perfiles $nombre) {
            $acc = @()
            foreach ($orden in @($cmds.perfiles.$nombre)) {
                # cada linea del perfil se resuelve como una orden normal
                foreach ($fr in @(Split-Compound (Repair-Words (ConvertTo-Plain $orden)))) {
                    $a = Resolve-Fragment $fr
                    if ($a) { $acc += $a }
                }
            }
            if ($acc.Count -gt 0) {
                return (@(@{ kind = 'decir'; desc = "modo $nombre" }) + $acc)
            }
        }
        return $null
    }
    # "recuerda que X" -> se anota YA, sin pasar por el modelo
    # El lookahead negativo distingue "recuerdame que X" (nota) de
    # "recuerdame EN 20 MINUTOS que X" (temporizador), que se resuelve mas abajo.
    if ($f -match '^(?:recuerda|recuerdame|acuerdate|anota|apunta|guarda(?=\s+(?:que|de\s+que)\b)|memoriza)\s+(?!en\s+\d+\s*(?:segundo|minuto|hora))(?:que\s+|de\s+que\s+)?(.+)$') {
        return @(@{ kind = 'memoria'; texto = $Matches[1].Trim(); desc = "anotar en la memoria" })
    }
    # El lugar puede preceder al verbo ("en el navegador busca X"). Se separa
    # aqui para que el resto de la funcion vea una orden con forma normal.
    $sitioForzado = $null
    if ($f -match ('^' + $LOCATIVO)) {
        $loc = $Matches[0]
        $nombre = ($loc -replace '^en\s+(?:el\s+|la\s+)?', '').Trim()
        if ($nombre -notmatch '^(?:navegador|internet|web|red|explorador)$') { $sitioForzado = $nombre }
        # al quitar el lugar aparece un verbo nuevo al frente, que puede venir
        # deformado ("en el navegador buscal X"): hay que repararlo tambien aqui
        $f = Repair-Verb ($f.Substring($loc.Length).Trim())
    }
    # --- frases sociales: se contestan aqui, no valen 40 s de modelo ---
    switch -regex ($f) {
        '^(?:gracias|muchas gracias|mil gracias|te lo agradezco|gracias nova)$' { return @(@{ kind = 'decir'; desc = (@('De nada.', 'A ti.', 'Para eso estoy.', 'Cuando quieras.') | Get-Random) }) }
        '^(?:hola|hola nova|buenas|buenos dias|buenas tardes|buenas noches|que tal|que mas|que hay)$' { return @(@{ kind = 'decir'; desc = (@('Hola. Dime.', 'Aqui estoy. ¿Que hacemos?', 'Hola, te escucho.') | Get-Random) }) }
        '^(?:adios|chao|chau|hasta luego|nos vemos|me voy|hasta manana)$' { return @(@{ kind = 'decir'; desc = (@('Hasta luego.', 'Nos vemos.', 'Aqui estare.') | Get-Random) }) }
        '^(?:como estas|que tal estas|como vas|como te va|todo bien)$' { return @(@{ kind = 'decir'; desc = (@('Muy bien, lista para lo que digas.', 'De maravilla. ¿Y tu?', 'Bien, con ganas de trabajar.') | Get-Random) }) }
        '^(?:te quiero|te adoro|eres genial|eres la mejor|eres lo maximo|buen trabajo|bien hecho|me encantas)$' { return @(@{ kind = 'decir'; desc = (@('Y yo a ti.', 'Gracias, me sonrojo.', 'Eso me anima.') | Get-Random) }) }
        '^(?:quien eres|como te llamas|que eres)$' { return @(@{ kind = 'decir'; desc = "Soy $EscuchaNombre, tu asistente de la consola. Vivo en la esquina de abajo." }) }
        '^(?:que puedes hacer|que sabes hacer|ayuda|que haces)$' { return @(@{ kind = 'decir'; desc = 'Abro apps y juegos, busco, controlo volumen y brillo, escribo y pulso teclas, cierro ventanas, pongo temporizadores y reglas, anoto en tu memoria y le pregunto a la inteligencia artificial lo que no sepa.' }) }
    }
    # --- preguntas que se responden AQUI mismo, sin modelo ---
    # Preguntarle la hora a un LLM cuesta 13 s y encima puede negarse.
    switch -regex ($f) {
        '^(?:que hora es|que horas son|dime la hora|la hora)\b' {
            $cul = New-Object System.Globalization.CultureInfo('es-MX')
            return @(@{ kind = 'decir'; desc = ("Son las " + (Get-Date).ToString('H:mm', $cul)) })
        }
        '^(?:que dia es|que fecha es|dime la fecha|que fecha|el dia de hoy)\b' {
            $cul = New-Object System.Globalization.CultureInfo('es-MX')
            return @(@{ kind = 'decir'; desc = ("Hoy es " + (Get-Date).ToString('dddd d "de" MMMM', $cul)) })
        }
        '^(?:cuanta bateria|cuanta pila|nivel de bateria|como esta la bateria|como esta la pila|cual es el estado de la bateria|estado de la bateria|cuanto le queda a la bateria|cuanta carga|como va la bateria|que tal la bateria)\b' {
            $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
            $t = if ($b -and $b.EstimatedChargeRemaining) { "Bateria al $($b.EstimatedChargeRemaining) por ciento" } else { "No pude leer la bateria" }
            return @(@{ kind = 'decir'; desc = $t })
        }
        '^(?:cuantos juegos|que juegos tengo|mis juegos)\b' {
            return @(@{ kind = 'decir'; desc = ("Tienes " + @($script:Juegos).Count + " juegos instalados en Steam") })
        }
        '^(?:deshaz|deshacer|cancela eso|cancelalo|no cancela|revierte|vuelve atras|atras eso)\b' {
            return @(@{ kind = 'deshacer'; desc = 'deshacer lo ultimo' })
        }
        '^(?:repite|repitelo|repitemelo|que me dijiste|que dijiste|ultima respuesta|la ultima respuesta)\b' {
            $r = $script:ultimaRespuesta
            if (-not $r) { $r = "Todavia no te he respondido nada" }
            return @(@{ kind = 'decir'; desc = $r })
        }
        '^(?:que anote hoy|que apunte hoy|mis notas de hoy|que recorde hoy)\b' {
            $n = Join-Path $DiarioDir ((Get-Date -Format 'yyyy-MM-dd') + '.md')
            $t = "Hoy no has anotado nada"
            if (Test-Path -LiteralPath $n) {
                $ls = @(Get-Content -LiteralPath $n -Encoding UTF8 | Where-Object { $_ -match '^\s*-\s' })
                if ($ls.Count -gt 0) {
                    $t = "Hoy anotaste: " + (($ls | ForEach-Object { $_ -replace '^\s*-\s*\*\*\d\d:\d\d\*\*\s*', '' }) -join '; ')
                }
            }
            return @(@{ kind = 'decir'; desc = $t })
        }
    }
    # --- PRONOMBRES ---
    # "abrelo" tras haber nombrado algo. Se recuerda SOLO el ultimo objetivo,
    # no una conversacion entera: asi se habla natural sin el riesgo del modo
    # persistente que hubo que quitar por tragarse las ordenes.
    # Incluye "le" a proposito: el corrector de verbos convierte "abrelo" en
    # "abrele" (distancia 1) antes de llegar aqui.
    if ($script:ultimoObjetivo -and $f -match '^(abre|abrir|cierra|busca|buscar|pon|inicia|lanza|ejecuta)(?:lo|la|le|los|las|melo|mela|me lo|me la)\b\s*(.*)$') {
        $verbo = $Matches[1]
        $resto = $Matches[2].Trim()
        $f = "$verbo $($script:ultimoObjetivo)"
        if ($resto) { $f = "$f $resto" }
    }
    # --- temporizadores: lo mas util con las manos ocupadas ---
    if ($f -match '^(?:recuerdame|avisame|despiertame|ponme un temporizador|temporizador|alarma)\s+(?:en|de|dentro de)\s+(\d+)\s*(segundo|segundos|minuto|minutos|hora|horas)\b\s*(?:que|para|de|a)?\s*(.*)$') {
        $n = [int]$Matches[1]
        $unidad = $Matches[2]
        $que = $Matches[3].Trim()
        $ms = switch -regex ($unidad) {
            '^segundo' { $n * 1000 }
            '^minuto' { $n * 60000 }
            default { $n * 3600000 }
        }
        if ($ms -le 0) { return $null }
        $desc = if ($que) { "aviso en $n $unidad" } else { "temporizador de $n $unidad" }
        return @(@{ kind = 'temporizador'; ms = $ms; texto = $que; n = $n; unidad = $unidad; desc = $desc })
    }
    if ($f -match '^(?:cuanto llevo jugando|cuanto tiempo llevo jugando|hace cuanto juego)\b') {
        return @(@{ kind = 'tiempoJuego'; desc = 'tiempo de juego' })
    }
    if ($f -match '^(?:a que estoy jugando|que estoy jugando|que juego es este)\b') {
        return @(@{ kind = 'queJuego'; desc = 'juego actual' })
    }
    # el tiempo, con lo que ya se consulto para el avatar de la capsula
    if ($f -match '^(?:que tiempo hace|que clima hace|que clima hay|como esta el clima|como esta el tiempo|va a llover|que temperatura hace|cuantos grados hay|cuantos grados hace)\b') {
        $t = if ($script:clima) { "Ahora mismo $($script:clima.desc), $($script:clima.temp) grados" } else { "No tengo el tiempo a mano; no pude consultarlo" }
        # el emoji del tiempo sustituye a la carita unos segundos, solo ahora
        if ($script:clima) { $script:uiClima = $script:clima.emoji; $script:uiClimaHasta = $sw.ElapsedMilliseconds + 9000 }
        return @(@{ kind = 'decir'; desc = $t })
    }
    # --- leer la pantalla (OCR de Windows) ---
    if ($f -match '^(?:lee|leeme|leer|que dice|que pone|que hay escrito|dime que dice)\s+(?:lo que (?:hay|dice|pone) (?:en\s+)?|en\s+)?(?:la\s+|esta\s+|el\s+)?(?:pantalla|ventana|esto|aqui|texto|mensaje)\b') {
        return @(@{ kind = 'ocr'; desc = 'leer la pantalla' })
    }
    # --- captura y grabacion (atajos de la barra de juego de Windows) ---
    switch -regex ($f) {
        '^(?:toma (?:una )?captura|captura (?:de )?pantalla|screenshot|pantallazo)$' {
            return @(@{ kind = 'winprt'; desc = 'captura de pantalla' })
        }
        '^(?:graba|grabar|clip|guarda el clip|graba los ultimos)\b' {
            return @(@{ kind = 'winaltg'; desc = 'grabar los ultimos segundos' })
        }
    }
    # --- CONTROL DE APPS Y VENTANAS (lo que faltaba para "hacer cualquier cosa") ---
    # cerrar: "cierra steam", "cierra esta ventana", "cierra el juego"
    if ($f -match '^(?:cierra|cierrame|cerrar|apaga|quita|quitame|mata)\s+(?:el\s+|la\s+|a\s+)?(.+)$') {
        $obj = $Matches[1].Trim()
        if ($obj -match '^(?:esta ventana|la ventana|esto|esta|la app|la aplicacion|ventana)$') { return @(@{ kind = 'altf4'; desc = 'cerrar la ventana' }) }
        if ($obj -match '^(?:el juego|juego|este juego|el videojuego)$') { return @(@{ kind = 'cerrarJuego'; desc = 'cerrar el juego' }) }
        if ($obj -match '^(?:todo|todas las ventanas|todas)$') { return @(@{ kind = 'winkey'; vk = 0x44; desc = 'mostrar el escritorio' }) }
        # cerrar de verdad, pero preguntando: ver el bloque 'cerrarTodo'
        if ($obj -match '^(?:todos los programas|los programas|todas las apps|todas las aplicaciones|todo lo abierto|todos los programas abiertos)$') {
            return @(@{ kind = 'cerrarTodo'; desc = 'cerrar los programas abiertos' })
        }
        $proc = Resolve-Proceso $obj
        if ($proc) { return @(@{ kind = 'cerrarApp'; proceso = $proc.proceso; desc = "cerrar $($proc.nombre)" }) }
        # no se reconoce que cerrar: que siga su camino (puede ser otra cosa)
    }
    # cambiar de app: "cambia a discord", "ve a steam", "enfoca el navegador", "muestra spotify"
    if ($f -match '^(?:cambia a|cambiate a|pasate a|pasa a|enfoca|muestra|muestrame|ve a|vete a|llevame a|ponme en|trae|traeme)\s+(?:el\s+|la\s+|a\s+)?(.+)$') {
        $obj = $Matches[1].Trim()
        if ($obj -match '^(?:el escritorio|escritorio)$') { return @(@{ kind = 'winkey'; vk = 0x44; desc = 'mostrar el escritorio' }) }
        if ($obj -match '^(?:el juego|juego)$' -and $script:juegoActivo) { return @(@{ kind = 'enfocarJuego'; desc = "volver a $($script:juegoActivo)" }) }
        $proc = Resolve-Proceso $obj
        if ($proc) { return @(@{ kind = 'enfocar'; proceso = $proc.proceso; desc = "cambiar a $($proc.nombre)" }) }
    }
    # "cierrate" es la capsula, no el asistente: la carita se va de la pantalla
    # pero el microfono sigue, asi que basta volver a decir su nombre.
    if ($f -match '^(?:cierrate|cierra la capsula|escondete|ocultate|quitate|vete de la pantalla|desaparece|piérdete|pierdete)$') {
        return @(@{ kind = 'esconder'; desc = 'me quito, dime mi nombre cuando me necesites' })
    }
    # SORDINA: apagar el oido un rato. Cuando estas viendo un video o jugando
    # con el sonido alto, el microfono caza ese audio y lo toma por ordenes; en
    # vez de pelearse con el ruido, se calla. NO es un modo que se quede puesto:
    # siempre lleva plazo, el boton (mantener ≡) sigue funcionando mientras
    # tanto, y al volver te avisa en voz alta.
    if ($f -match '^(?:no me escuches|no escuches|deja de escuchar|dejate de escuchar|duermete|vete a dormir|a dormir|descansa|apaga el oido|no me oigas|ignorame)(?:\s+(?:durante|por|un|una)?\s*(?:(\d+)\s*(minuto|minutos|hora|horas)|(un rato|media hora|un momento|rato)))?$') {
        # OJO: hay que copiar los grupos ANTES de usar -match otra vez, porque
        # cada -match reescribe $Matches entero. Con el numero y la unidad
        # leidos de $Matches despues de comprobar la unidad, decia 'me callo 2'
        # y se comia el 'horas'.
        $num = $Matches[1]; $unidad = $Matches[2]; $expr = $Matches[3]
        $ms = 15 * 60000
        $comoLoDigo = 'un cuarto de hora'
        if ($num) {
            $n = [int]$num
            if ($unidad -match '^hora') { $ms = $n * 3600000 } else { $ms = $n * 60000 }
            $comoLoDigo = "$n $unidad"
        } elseif ($expr -eq 'media hora') {
            $ms = 30 * 60000
            $comoLoDigo = 'media hora'
        }
        if ($ms -le 0) { return $null }
        return @(@{ kind = 'sordina'; ms = $ms; desc = "me callo $comoLoDigo; si me necesitas antes, manten el boton" })
    }
    # Diagnostico hablado: hasta ahora, para saber por que no te oia habia que
    # abrir assistant.log y leer las lineas del pulso. Esto cuenta lo mismo en
    # una frase, que es lo util cuando tienes las manos ocupadas.
    if ($f -match '^(?:como me oyes|que tal me oyes|oyes bien|escuchas bien|como me escuchas|como esta el microfono|que tal el microfono|como va la escucha|estado del microfono)$') {
        return @(@{ kind = 'estadoEscucha'; desc = 'estado de la escucha' })
    }
    # Volver de la sordina antes de tiempo. Mientras esta sorda solo se llega
    # aqui por el boton (manten ≡), que es justo lo que la salva de quedarse
    # muda: un modo con plazo del que no se puede salir sigue siendo una trampa.
    # OJO con las formas: cuando la frase llega aqui ya paso por Remove-Filler,
    # que se come 'puedes' y el 'me' inicial. O sea que 'ya puedes escucharme'
    # llega como 'ya escucharme' y 'me escuchas bien' como 'escuchas bien'. Los
    # patrones tienen que escribirse contra ESA forma, no contra lo que dices.
    if ($f -match '^(?:ya\s+)?(?:escuchame|escucharme|vuelve a escucharme|vuelve a escuchar|despierta|despiertate|te escucho|estoy aqui|sigue escuchando)$') {
        return @(@{ kind = 'despertarEscucha'; desc = 'te escucho otra vez' })
    }
    # juegos colgados: los que no salen por ningun lado pero siguen sonando
    if ($f -match '^(?:hay algo colgado|que hay colgado|hay algun juego colgado|algun juego colgado|hay juegos colgados|revisa los juegos|mira si hay algo colgado|cierra los juegos colgados|cierra lo colgado)$') {
        return @(@{ kind = 'zombis'; desc = 'buscar juegos colgados' })
    }
    if ($f -match '^(?:minimiza todo|minimizar todo|muestra el escritorio|escritorio|esconde todo|oculta todo)$') { return @(@{ kind = 'winkey'; vk = 0x44; desc = 'mostrar el escritorio' }) }
    if ($f -match '^(?:cambia de ventana|siguiente ventana|otra ventana|alterna)$') { return @(@{ kind = 'alttab'; desc = 'cambiar de ventana' }) }
    # escribir en la app activa: "escribe hola que tal"
    if ($f -match '^(?:escribe|escribeme|teclea|dicta|pon el texto)\s+(.+)$') {
        return @(@{ kind = 'escribir'; texto = $Matches[1].Trim(); desc = "escribir '$($Matches[1].Trim())'" })
    }
    # teclas: "pulsa enter", "dale a escape", "presiona espacio"
    if ($f -match '^(?:pulsa|presiona|aprieta|dale a|dale al|toca|oprime)\s+(?:la\s+|el\s+|tecla\s+)?(.+)$') {
        $k = $Matches[1].Trim()
        $mapa = @{ 'enter' = 0x0D; 'intro' = 0x0D; 'escape' = 0x1B; 'esc' = 0x1B; 'espacio' = 0x20; 'tab' = 0x09; 'tabulador' = 0x09;
                   'arriba' = 0x26; 'abajo' = 0x28; 'izquierda' = 0x25; 'derecha' = 0x27; 'borrar' = 0x08; 'retroceso' = 0x08;
                   'suprimir' = 0x2E; 'inicio' = 0x24; 'fin' = 0x23; 'f5' = 0x74; 'f11' = 0x7A; 'windows' = 0x5B; 'play' = 0xB3; 'pausa' = 0xB3 }
        $rep = 1
        if ($k -match '^(.+?)\s+(\d+)\s+veces$') { $k = $Matches[1]; $rep = [Math]::Min(20, [int]$Matches[2]) }
        if ($mapa.ContainsKey($k)) { return @(@{ kind = 'key'; vk = $mapa[$k]; repeat = $rep; desc = "pulsar $k" }) }
        return $null
    }
    switch -regex ($f) {
        '^(?:copia|copiar|copia eso|copialo)$' { return @(@{ kind = 'atajo'; teclas = '^c'; desc = 'copiar' }) }
        '^(?:pega|pegar|pegalo)$' { return @(@{ kind = 'atajo'; teclas = '^v'; desc = 'pegar' }) }
        '^(?:corta|cortar)$' { return @(@{ kind = 'atajo'; teclas = '^x'; desc = 'cortar' }) }
        '^(?:selecciona todo|seleccionar todo|selecciona todo el texto)$' { return @(@{ kind = 'atajo'; teclas = '^a'; desc = 'seleccionar todo' }) }
        '^(?:guarda|guardar|guarda el archivo|guardalo)$' { return @(@{ kind = 'atajo'; teclas = '^s'; desc = 'guardar' }) }
        '^(?:deshaz eso|deshacer eso|control zeta|control z)$' { return @(@{ kind = 'atajo'; teclas = '^z'; desc = 'deshacer' }) }
        '^(?:rehaz|rehacer|control y)$' { return @(@{ kind = 'atajo'; teclas = '^y'; desc = 'rehacer' }) }
        '^(?:nueva pestana|abre una pestana|pestana nueva)$' { return @(@{ kind = 'atajo'; teclas = '^t'; desc = 'nueva pestana' }) }
        '^(?:cierra la pestana|cierra esta pestana|cerrar pestana)$' { return @(@{ kind = 'atajo'; teclas = '^w'; desc = 'cerrar pestana' }) }
        '^(?:recarga|recargar|actualiza la pagina|refresca)$' { return @(@{ kind = 'key'; vk = 0x74; repeat = 1; desc = 'recargar' }) }
        '^(?:pantalla completa del navegador|f once)$' { return @(@{ kind = 'key'; vk = 0x7A; repeat = 1; desc = 'pantalla completa' }) }
        '^(?:baja|bajar|desplaza hacia abajo|scroll abajo)$' { return @(@{ kind = 'key'; vk = 0x22; repeat = 1; desc = 'bajar la pagina' }) }
        '^(?:sube|subir|desplaza hacia arriba|scroll arriba)$' { return @(@{ kind = 'key'; vk = 0x21; repeat = 1; desc = 'subir la pagina' }) }
    }
    # musica y video: "pon bad bunny en spotify", "reproduce lofi en youtube"
    if ($f -match '^(?:pon|ponme|reproduce|reproduceme|escuchar|quiero escuchar|toca|tocame)\s+(.+?)\s+en\s+spotify$') {
        $q = $Matches[1].Trim()
        return @(@{ kind = 'url'; url = ('spotify:search:' + [Uri]::EscapeDataString($q)); desc = "buscar '$q' en Spotify" })
    }
    if ($f -match '^(?:pon|ponme|reproduce|reproduceme|quiero ver|ver|toca)\s+(.+?)\s+en\s+youtube$') {
        $q = $Matches[1].Trim()
        return @(@{ kind = 'url'; url = ('https://www.youtube.com/results?search_query=' + [Uri]::EscapeDataString($q)); desc = "buscar '$q' en YouTube" })
    }
    # buscar en el equipo (Windows Search): "busca en el equipo fotos de julio"
    if ($f -match '^(?:busca|buscame|buscar)\s+en\s+(?:el\s+)?(?:equipo|pc|computador|computadora|ordenador|windows|mis archivos)\s+(.+)$') {
        return @(@{ kind = 'buscarEquipo'; texto = $Matches[1].Trim(); desc = "buscar '$($Matches[1].Trim())' en el equipo" })
    }
    # --- colocacion de ventanas ---
    switch -regex ($f) {
        '^(?:a\s+)?(?:mitad de pantalla|media pantalla|la mitad|a la izquierda|izquierda)$' { return @(@{ kind = 'winkey'; vk = 0x25; desc = 'media pantalla izquierda' }) }
        '^(?:a\s+)?(?:la\s+)?derecha$' { return @(@{ kind = 'winkey'; vk = 0x27; desc = 'media pantalla derecha' }) }
        '^(?:maximiza|maximizar|pantalla completa|agranda)$' { return @(@{ kind = 'winkey'; vk = 0x26; desc = 'maximizar ventana' }) }
        '^(?:minimiza|minimizar|achica)$' { return @(@{ kind = 'winkey'; vk = 0x28; desc = 'minimizar ventana' }) }
    }
    # --- niveles: volumen y brillo, con formas latinas (subele / bajale) ---
    # "pon"/"deja" entran aqui tambien ("pon el brillo al 20%"), pero si la
    # frase no habla de volumen ni brillo se DEJA PASAR al resto de la funcion:
    # devolver $null aqui rompería "ponme spotify".
    if ($f -match '^(sube|subir|subele|aumenta|baja|bajar|bajale|reduce|pon|ponle|poner|deja|dejar)\b') {
        $sube = ($Matches[1] -match '^(?:sube|subir|subele|aumenta)$')
        $max = ($f -match '\b(?:maximo|tope|todo|full)\b')
        $min = ($f -match '\b(?:minimo|nada)\b')
        # Porcentaje POR OBJETIVO: se busca el numero mas cercano a cada palabra.
        # Con un solo $pct global, "el volumen al 50% y el brillo al 80%" ponia
        # los dos al 50 %.
        $pctVol = $null
        $pctBri = $null
        if ($f -match '(?:volumen|sonido|audio)[^0-9]{0,20}(\d{1,3})') {
            $n = [int]$Matches[1]; if ($n -ge 0 -and $n -le 100) { $pctVol = $n }
        }
        if ($f -match 'brillo[^0-9]{0,20}(\d{1,3})') {
            $n = [int]$Matches[1]; if ($n -ge 0 -and $n -le 100) { $pctBri = $n }
        }
        $acc = @()
        if ($f -match '\b(?:volumen|sonido|audio)\b') {
            if ($null -ne $pctVol) {
                $acc += @{ kind = 'volumenPct'; pct = $pctVol; desc = "volumen al $pctVol por ciento" }
            } else {
                $rep = if ($max -or $min) { 50 } else { 5 }
                $acc += @{ kind = 'key'; vk = $(if ($sube) { 0xAF } else { 0xAE }); repeat = $rep
                           desc = ("$(if ($sube) { 'subir' } else { 'bajar' }) volumen" + $(if ($max) { ' al maximo' } elseif ($min) { ' al minimo' } else { '' })) }
            }
        }
        if ($f -match '\bbrillo\b') {
            if ($null -ne $pctBri) {
                $acc += @{ kind = 'brillo'; nivel = $pctBri; desc = "brillo al $pctBri por ciento" }
            } else {
                $nivel = if ($max) { 100 } elseif ($min) { 0 } elseif ($sube) { -1 } else { -2 }
                $acc += @{ kind = 'brillo'; nivel = $nivel
                           desc = ("$(if ($sube) { 'subir' } else { 'bajar' }) brillo" + $(if ($max) { ' al maximo' } elseif ($min) { ' al minimo' } else { '' })) }
            }
        }
        if ($acc.Count -gt 0) { return $acc }
        # sin volumen ni brillo: NO cortar aqui, puede ser "ponme spotify"
    }
    # --- multimedia y sistema ---
    switch -regex ($f) {
        '^(?:silencia|silenciar|mutea)\b' { return @(@{ kind = 'key'; vk = 0xAD; repeat = 1; desc = 'silenciar' }) }
        '^(?:pausa|pausar|reproduce|reproducir|play)$' { return @(@{ kind = 'key'; vk = 0xB3; repeat = 1; desc = 'play/pausa' }) }
        '^(?:siguiente|pasa|pasala|adelanta)\b' { return @(@{ kind = 'key'; vk = 0xB0; repeat = 1; desc = 'siguiente' }) }
        '^(?:anterior|regresa|atras)\b' { return @(@{ kind = 'key'; vk = 0xB1; repeat = 1; desc = 'anterior' }) }
        '^(?:bloquea|bloquear)\b' { return @(@{ kind = 'lock'; desc = 'bloquear sesion' }) }
    }
    # --- busquedas ---
    if ($f -match '^(?:busca|buscame|buscar|busque|googlea|googleame|investiga)\s+(.+)$') {
        $q = $Matches[1].Trim()
        # "busca en el navegador X" / "en en el navegador X" / "busca el navegador X":
        # eso indica DONDE buscar, no QUE buscar. El dictado repite "en" a menudo.
        $q = [regex]::Replace($q, '^(?:en\s+)*(?:el\s+|la\s+)?(?:navegador|internet|web|red|explorador)\s+', '')
        $sitio = [string]$cmds.buscadorPorDefecto
        $sitioExplicito = $false
        # el lugar dicho ANTES del verbo manda ("en youtube busca X")
        if ($sitioForzado -and (Test-Prop $cmds.busquedas $sitioForzado)) { $sitio = $sitioForzado; $sitioExplicito = $true }
        if ($q -match '^(.*?)\s+en\s+([\w\s]+)$') {
            $cand = $Matches[2].Trim()
            if (Test-Prop $cmds.busquedas $cand) { $q = $Matches[1].Trim(); $sitio = $cand; $sitioExplicito = $true }
        }
        # la coletilla generica tambien aparece AL FINAL ("busca pinterest en internet")
        $q = [regex]::Replace($q, '\s+en\s+(?:el\s+|la\s+)?(?:internet|navegador|web|red|explorador)$', '')
        $q = $q.Trim()
        if (-not $q) { return $null }
        # "busca pinterest" con un sitio/app conocido = ABRIRLO, que es lo que se
        # espera; buscar esa palabra en Google no aporta nada. Solo cuando no se
        # nombro un buscador concreto ("busca gatos en youtube" si busca).
        if (-not $sitioExplicito -and ($q -split '\s+').Count -le 2) {
            $directo = Resolve-Target $q
            if ($directo) { return $directo }
        }
        if (-not (Test-Prop $cmds.busquedas $sitio)) { return $null }
        $url = ([string]$cmds.busquedas.$sitio) -replace '\{q\}', [System.Uri]::EscapeDataString($q)
        return @(@{ kind = 'url'; url = $url; desc = "buscar '$q' en $sitio" })
    }
    # --- abrir algo, con las variantes latinas de "abrir/ir a" ---
    if ($f -match '^(?:abre|abreme|abrele|abrir|abri|abrime|ejecuta|ejecutame|inicia|iniciame|lanza|lanzame|arranca|arrancame|prende|prendeme|ponme|poneme|ponele|pone|pon|metete|mete|entrate|entra|andate|anda|vete|ve|llevame|muestrame|ensename)\s+(?:a\s+|al\s+|en\s+|de\s+)?(.+)$') {
        return (Resolve-Target $Matches[1])
    }
    # --- sin verbo: solo el nombre ("steam", "youtube") ---
    # Se marca de donde viene: decir un nombre a secas es comodo para abrir
    # steam, pero es tambien la forma en que el ruido abre juegos solo
    # ('SILENT BREATH' salio 4 veces en el log sin que nadie lo dijera). Al
    # ejecutar, un JUEGO sin verbo se pregunta antes.
    $sv = Resolve-Target $f
    if ($sv) { foreach ($x in $sv) { $x.sinVerbo = $true } }
    return $sv
}

# Brillo por WMI. nivel: 0-100 absoluto, -1 = subir un paso, -2 = bajar un paso.
function Set-Brillo([int]$nivel) {
    $act = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop).CurrentBrightness
    $destino = switch ($nivel) {
        -1 { [Math]::Min(100, [int]$act + 20) }
        -2 { [Math]::Max(0, [int]$act - 20) }
        default { [Math]::Max(0, [Math]::Min(100, $nivel)) }
    }
    $met = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop
    $null = Invoke-CimMethod -InputObject $met -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]1; Brightness = [byte]$destino }
    # la capsula ensena un sol con la barra del nivel un instante
    try { Send-UIEvento "brillo:$destino" } catch {}
}

# Ejecuta la orden si TODA ella se reconoce. Devuelve el resumen, o $null
# para que la frase siga su camino hacia opencode.
# Estado para deshacer. Solo se puede revertir lo que se sabe leer y reponer:
# el brillo (WMI) y los procesos que HEMOS lanzado nosotros. El volumen de
# Windows no se puede leer sin librerias externas, y las apps abiertas por URI
# (steam://) no devuelven un proceso propio: eso NO se puede deshacer.
$script:deshacer = $null

function Save-EstadoParaDeshacer {
    $b = $null
    try { $b = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop).CurrentBrightness } catch {}
    $script:deshacer = @{ brillo = $b; procesos = New-Object System.Collections.ArrayList; juego = $null }
}

function Invoke-Deshacer {
    if (-not $script:deshacer) { return "No hay nada que deshacer" }
    $hecho = @()
    if ($null -ne $script:deshacer.brillo) {
        try { Set-Brillo ([int]$script:deshacer.brillo); $hecho += "brillo restaurado" } catch {}
    }
    foreach ($pid2 in @($script:deshacer.procesos)) {
        try {
            $pr = Get-Process -Id $pid2 -ErrorAction Stop
            $pr.CloseMainWindow() | Out-Null
            $hecho += "cerrado $($pr.ProcessName)"
        } catch {}
    }
    if ($script:deshacer.juego) {
        $jg = $script:deshacer.juego
        foreach ($pr in (Get-Process -ErrorAction SilentlyContinue)) {
            try {
                if ($pr.Path -notmatch '(?i)steamapps\\common\\') { continue }
                if ($pr.StartTime -lt $jg.desde) { continue }
                if (-not $pr.CloseMainWindow()) { Start-Sleep -Milliseconds 1200 }
                if (-not $pr.HasExited) { $pr.Kill() }
                $hecho += "cerrado $($jg.nombre)"
                break
            } catch {}
        }
    }
    $script:deshacer = $null
    if ($hecho.Count -eq 0) { return "No pude deshacerlo: el volumen no se puede revertir" }
    return ($hecho -join '; ')
}

# "aprende que a X le llamo Y": amplia commands.json hablando, sin editar JSON.
function Add-Alias-Comando([string]$alias, [string]$objetivo) {
    $alias = (ConvertTo-Plain $alias).Trim()
    if (-not $alias -or -not $objetivo) { return $null }
    $destino = Resolve-Target (ConvertTo-Plain $objetivo)
    if (-not $destino) { return $null }
    $d = $destino[0]
    try {
        $j = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($d.kind -eq 'app') {
            $j.apps | Add-Member -NotePropertyName $alias -NotePropertyValue ([string]$d.target) -Force
        } else {
            $j.sitios | Add-Member -NotePropertyName $alias -NotePropertyValue ([string]$d.url) -Force
        }
        $txt = $j | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($cmdsPath, $txt, (New-Object System.Text.UTF8Encoding($false)))
        $script:cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Log "APRENDIDO: '$alias' -> $($d.desc)"
        return "Listo, ahora se que $alias es $($d.desc -replace '^abrir ', '')"
    } catch {
        Log ("no pude aprender: " + $_.Exception.Message)
        return $null
    }
}

# =====================================================================
# TRADUCCIONES APRENDIDAS
# Cuando la capa local no entiende una frase, en vez de mandarla al agente
# completo (25-160 s) se le pide al modelo que la TRADUZCA a una orden que si
# conocemos (~13 s, sin herramientas). Si la traduccion es valida se ejecuta en
# local y se GUARDA: la proxima vez que digas algo parecido tarda <1 s.
# El modelo nunca ejecuta nada; solo propone texto que se valida contra el
# vocabulario cerrado antes de hacerle caso.
# =====================================================================
$TraduccionesPath = Join-Path $LogDir "traducciones.json"
$script:traducciones = $null

function Get-Traducciones {
    if ($null -ne $script:traducciones) { return $script:traducciones }
    $script:traducciones = @{}
    if (Test-Path -LiteralPath $TraduccionesPath) {
        try {
            $j = Get-Content -LiteralPath $TraduccionesPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $script:traducciones[$p.Name] = [string]$p.Value }
        } catch {}
    }
    return $script:traducciones
}

function Add-Traduccion([string]$original, [string]$traducida) {
    $clave = ConvertTo-Plain $original
    if (-not $clave -or -not $traducida) { return }
    $t = Get-Traducciones
    $t[$clave] = $traducida
    try {
        $o = New-Object PSObject
        foreach ($k in $t.Keys) { $o | Add-Member -NotePropertyName $k -NotePropertyValue $t[$k] -Force }
        [System.IO.File]::WriteAllText($TraduccionesPath, ($o | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
        Log "APRENDIDO: '$original' = '$traducida'"
    } catch { Log ("no pude guardar la traduccion: " + $_.Exception.Message) }
}

# ¿La traduccion del modelo se explica por UNA palabra desconocida que
# corresponde a UNA app o sitio conocidos? Entonces vale la pena aprender esa
# palabra como alias (sirve para cualquier frase futura).
$PALABRAS_COMUNES = @('abre','abrir','pon','ponme','busca','en','el','la','los','las','un','una','de','del','al','a','y','con','por','para','que','me','lo','le','mi','tu','su','ya','ahora','porfa','por','favor','steam','juego')
function Find-Generalizacion([string]$original, [string]$traducida) {
    if (-not $cmds) { return $null }
    $po = ConvertTo-Plain $original
    $pt = ConvertTo-Plain $traducida
    $wo = @($po -split '\s+' | Where-Object { $_ })
    $wt = @($pt -split '\s+' | Where-Object { $_ })
    $alias = @($wo | Where-Object { $_.Length -ge 3 -and $wt -notcontains $_ -and $PALABRAS_COMUNES -notcontains $_ })
    if ($alias.Count -ne 1) { return $null }
    $objetivos = @()
    foreach ($k in @($cmds.apps.PSObject.Properties.Name) + @($cmds.sitios.PSObject.Properties.Name)) {
        if ($pt -match ('\b' + [regex]::Escape($k) + '\b') -and $po -notmatch ('\b' + [regex]::Escape($k) + '\b')) { $objetivos += $k }
    }
    $objetivos = @($objetivos | Select-Object -Unique)
    if ($objetivos.Count -ne 1) { return $null }
    # que no sea ya una correccion o alias conocido
    if (Test-Prop $cmds.apps $alias[0] -or Test-Prop $cmds.sitios $alias[0]) { return $null }
    return @{ alias = $alias[0]; objetivo = $objetivos[0] }
}

function Find-Traduccion([string]$text) {
    $t = Get-Traducciones
    if ($t.Count -eq 0) { return $null }
    $clave = ConvertTo-Plain $text
    if ($t.ContainsKey($clave)) { return $t[$clave] }
    # tolerancia a variaciones del dictado sobre algo ya aprendido
    foreach ($k in $t.Keys) {
        if ([Math]::Abs($k.Length - $clave.Length) -gt 6) { continue }
        $tope = [Math]::Max(2, [int][Math]::Floor($k.Length * 0.2))
        if ((Get-Distancia $clave $k) -le $tope) { return $t[$k] }
    }
    return $null
}

# ¿Reconoceria la capa local esta frase? SOLO resuelve, no ejecuta nada. Se
# usa sobre la transcripcion EN VIVO para que la capsula asienta ("lo tengo")
# antes de que termines de hablar.
function Test-FastCommand([string]$text) {
    if (-not $cmds -or -not $text) { return $false }
    if ($text -match '(?i)^\s*aprende\s+que\s+') { return $true }
    $pl = ConvertTo-Plain $text
    if ($pl -match '^(?:recuerdame|avisame|recordatorio)\s+(?!que\b)(?:hoy|manana|pasado manana|el (?:lunes|martes|miercoles|jueves|viernes|sabado|domingo)|el \d{1,2} de |a las? )') { return $true }   # recordatorio con fecha
    if ($text -match '(?i)^\s*(?:recu[eé]rdame|recuerda|acu[eé]rdate|anota|apunta|guarda(?=\s+(?:que|de\s+que)\b)|memoriza)\s+(?!en\s+\d+)') { return $true }
    if ($pl -match '^(?:cuando\s|cada\s+\d+|todos los dias|a las?\s)') { return $false }   # reglas: las decide Invoke-ReglaVoz
    # el mismo corte que en Invoke-FastCommand: este es el camino que usan la
    # capsula y el banco de pruebas, y tiene que decir lo mismo que el ejecutor
    if (Test-CatalogoRecitado $text) { return $false }
    $frags = $null
    try { $frags = Split-Compound (Repair-Words (ConvertTo-Plain $text)) } catch { return $false }
    if (-not $frags -or $frags.Count -eq 0) { return $false }
    $dudosaAntes = $script:dudosa
    try {
        foreach ($f in $frags) {
            $a = $null
            try { $a = Resolve-Fragment $f } catch { $a = $null }
            if (-not $a) { return $false }
        }
        return $true
    } finally { $script:dudosa = $dudosaAntes }
}

function Invoke-FastCommand([string]$text) {
    if (-not $cmds) { return $null }
    # aprender vocabulario hablando (se lee del texto ORIGINAL, sin normalizar)
    if ($text -match '(?i)^\s*aprende\s+que\s+(?:a\s+)?(.+?)\s+(?:le\s+(?:digo|llamo|dicen)|es|se\s+llama)\s+(.+)$') {
        $a = $Matches[1].Trim(); $b = $Matches[2].Trim()
        # "aprende que a spotify le digo musica" -> alias=musica, objetivo=spotify
        $r = Add-Alias-Comando $b $a
        if (-not $r) { $r = Add-Alias-Comando $a $b }   # o al reves
        if ($r) { return $r }
        return "No supe a que te refieres con eso"
    }
    # La memoria guarda el texto TAL CUAL se dijo, con mayusculas y acentos.
    # Si se dejara pasar por la normalizacion se archivaria en minusculas y sin
    # tildes, que es justo lo que no quieres leer meses despues en Obsidian.
    # mismo lookahead que en Resolve-Fragment: "en 20 minutos" es temporizador,
    # no una nota para el diario
    if ($text -match '(?i)^\s*(?:recu[eé]rdame|recuerda|acu[eé]rdate|anota|apunta|guarda(?=\s+(?:que|de\s+que)\b)|memoriza)\s+(?!en\s+\d+\s*(?:segundo|minuto|hora))(?!(?:hoy|ma[nñ]ana|pasado\s+ma[nñ]ana|el\s+(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)|el\s+\d{1,2}\s+de\s|a\s+las?\s)\b)(?:que\s+|de\s+que\s+)?(.+)$') {
        $frase = $Matches[1].Trim()
        if ($frase.Length -gt 0) {
            $null = Add-Memoria $frase
            Log "MEMORIA: $frase"
            # si lleva una fecha ("el 3 de octubre"), ese dia lo celebro
            $md = $null
            try { $md = Add-Fecha $frase } catch { $md = $null }
            if ($md) { return "Anotado. Y ese dia te lo recuerdo." }
            return "Anotado."
        }
    }
    # recordatorios con fecha y hora reales ("recuerdame manana a las 10 que...")
    $rec = $null
    try { $rec = Invoke-RecordatorioVoz $text } catch { Log ("recordatorio: " + $_.Exception.Message); $rec = $null }
    if ($rec) { return $rec }
    # fechas guardadas: "que fechas tengo"
    if ($text -match '(?i)^\s*(?:que fechas (?:tengo|hay|guardaste)|mis fechas|que cumples hay|que cumpleanos hay)\b') {
        $fs = @(Get-Fechas | Sort-Object md)
        if ($fs.Count -eq 0) { return "No tienes fechas guardadas. Di, por ejemplo: recuerda que el 3 de octubre es el cumple de Ana." }
        return ("Tienes " + $fs.Count + ": " + (($fs | ForEach-Object { $_.texto }) -join '; '))
    }
    # reglas por voz: se interpretan sobre la frase ENTERA (no se parte por "y")
    $regla = $null
    try { $regla = Invoke-ReglaVoz $text } catch { Log ("regla: " + $_.Exception.Message); $regla = $null }
    if ($regla) { return $regla }
    if (Test-CatalogoRecitado $text) {
        Log "LOCAL descarta: '$text' es el catalogo recitado, no una orden"
        return $null
    }
    $frags = Split-Compound (Repair-Words (ConvertTo-Plain $text))
    if (-not $frags -or $frags.Count -eq 0) { return $null }

    $script:dudosa = $null
    $acciones = @()
    foreach ($f in $frags) {
        $a = Resolve-Fragment $f
        if (-not $a) {
            # dejar constancia del trozo exacto: es lo que dice que anadir a
            # commands.json en vez de tener que adivinarlo despues
            Log "LOCAL descarta: no reconozco '$f' -> la orden entera va a opencode"
            # se anota en las estadisticas SOLO si la frase acaba yendo al
            # modelo como orden (las preguntas siempre se descartan aqui y no
            # son vocabulario que falte): lo decide Process-Texto
            $script:ultimoDescarte = $f
            return $null   # todo o nada
        }
        $acciones += $a
    }

    # --- CONFIRMACION DE COINCIDENCIAS DUDOSAS ---
    # Si algo se resolvio por parecido lejano, no se ejecuta: se devuelve la
    # pregunta y se deja la orden pendiente. El bucle principal la ejecuta si
    # dices "si" o si pasan unos segundos sin respuesta; "no" la cancela. Sin
    # estado pegajoso: el plazo la limpia sola.
    if ($ConfirmacionOn -and $script:dudosa -and -not $script:confirmado -and -not $script:sinDudosa) {
        $script:pendiente = @{ texto = $text; vence = 0 }
        $q = [string]$script:dudosa
        $script:dudosa = $null
        return ("¿" + $q + "?")
    }

    # se recuerda el ultimo objetivo nombrado, para que "abrelo" funcione luego
    foreach ($a in $acciones) {
        if ($a.desc -match '^abrir (.+?)( en Steam)?$') { $script:ultimoObjetivo = $Matches[1]; break }
        if ($a.desc -match "^buscar '(.+?)' en ") { $script:ultimoObjetivo = $Matches[1]; break }
    }

    # se guarda el estado ANTES de tocar nada, para poder deshacer
    $tocaEstado = @($acciones | Where-Object { $_.kind -in @('brillo', 'volumenPct', 'key', 'app') }).Count -gt 0
    if ($tocaEstado -and -not ($acciones | Where-Object { $_.kind -eq 'deshacer' })) { Save-EstadoParaDeshacer }

    $hechas = @()
    $navegador = $null
    foreach ($a in $acciones) {
        try {
            switch ($a.kind) {
                # se sustituye la descripcion por el resultado real
                'deshacer' { $a.desc = (Invoke-Deshacer) }
                'app' {
                    # ABRIR UN JUEGO MIENTRAS JUEGAS A OTRA COSA casi nunca es lo
                    # que pediste: es la firma de una orden mal oida. El 11/09 un
                    # ruido acabo abriendo SILENT BREATH en mitad de una partida.
                    # Se pregunta antes, igual que con 'cierra todos los programas'.
                    $esJuego = ($a.target -match 'steam://rungameid')
                    $comoSeLlama = ($a.desc -replace '^abrir\s+', '' -replace '\s+en Steam$', '')
                    if ($esJuego -and -not $script:confirmado -and ($script:juegoActivo -or $a.sinVerbo)) {
                        $script:pendiente = @{ texto = "abre $comoSeLlama en steam"; vence = 0; tipo = 'peligrosa' }
                        $a.desc = if ($script:juegoActivo) { "estas jugando a $($script:juegoActivo). ¿Abro $comoSeLlama?" }
                                  else { "¿Abro $comoSeLlama?" }
                    } else {
                        # con -PassThru para poder cerrarlo si pides deshacer; las
                        # URI (steam://, shell:appsFolder) no devuelven proceso propio
                        $pr = Start-Process $a.target -PassThru -ErrorAction Stop
                        if ($pr -and $script:deshacer) { [void]$script:deshacer.procesos.Add($pr.Id) }
                        # Un juego de Steam no deja proceso al que agarrarse, asi
                        # que se apunta QUE y CUANDO: al deshacer se busca el que
                        # haya aparecido despues. Antes, 'deshaz' no podia con
                        # ellos, que es justo lo que hace falta tras un falso
                        # positivo.
                        if ($esJuego -and $script:deshacer) {
                            $script:deshacer.juego = @{ nombre = $comoSeLlama; desde = (Get-Date) }
                        }
                        if ($a.target -match 'msedge|chrome|firefox') { $navegador = $a.target }
                    }
                }
                'url' {
                    if ($navegador) { Start-Process $navegador $a.url -ErrorAction Stop }
                    else { Start-Process $a.url -ErrorAction Stop }
                }
                'key' { for ($i = 0; $i -lt $a.repeat; $i++) { Send-Key $a.vk } }
                'brillo' { Set-Brillo $a.nivel }
                'memoria' { $null = Add-Memoria $a.texto }
                'decir' {
                    # la respuesta ES la descripcion; se dice y ya. Si es un
                    # perfil, la capsula lo sabe ("noche" = paleta calida)
                    if ($a.desc -match '^modo (\w+)$') { $script:uiPerfil = $Matches[1] }
                }
                'temporizador' {
                    $vence = $sw.ElapsedMilliseconds + $a.ms
                    $txt = if ($a.texto) { $a.texto } else { "se acabo el tiempo" }
                    [void]$script:temporizadores.Add(@{ vence = $vence; texto = $txt; total = $a.ms })
                    $a.desc = "listo, te aviso en $($a.n) $($a.unidad)"
                }
                'tiempoJuego' {
                    if ($script:juegoActivo) {
                        $mins = [int](($sw.ElapsedMilliseconds - $script:juegoDesde) / 60000)
                        $a.desc = "llevas $mins minutos con $($script:juegoActivo)"
                    } else {
                        $a.desc = "ahora mismo no detecto ningun juego abierto"
                    }
                }
                'queJuego' {
                    $a.desc = if ($script:juegoActivo) { "estas jugando a $($script:juegoActivo)" } else { "no detecto ningun juego en primer plano" }
                }
                'winprt' { Send-WinKey 0x2C }        # Win+ImprPant: guarda en Imagenes\Capturas
                'winaltg' { Send-WinAlt 0x47 }       # Win+Alt+G: graba lo ultimo
                'volumenPct' {
                    # Windows mueve el volumen en pasos del 2 %: se baja a cero
                    # y se sube lo justo. Sin librerias externas no hay via mejor.
                    for ($i = 0; $i -lt 50; $i++) { Send-Key 0xAE }
                    $pasos = [int][Math]::Round($a.pct / 2)
                    for ($i = 0; $i -lt $pasos; $i++) { Send-Key 0xAF }
                }
                'winkey' { Send-WinKey $a.vk }
                'lock' { Start-Process 'rundll32.exe' 'user32.dll,LockWorkStation' -ErrorAction Stop }
                'altf4' { [AX]::keybd_event([byte]$VK_MENU, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 40; Send-Key 0x73; [AX]::keybd_event([byte]$VK_MENU, 0, $KEYUP, [UIntPtr]::Zero) }
                'alttab' { [AX]::keybd_event([byte]$VK_MENU, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 40; Send-Key 0x09; Start-Sleep -Milliseconds 40; [AX]::keybd_event([byte]$VK_MENU, 0, $KEYUP, [UIntPtr]::Zero) }
                'atajo' { [System.Windows.Forms.SendKeys]::SendWait($a.teclas) }
                'escribir' {
                    # SendKeys interpreta + ^ % ~ ( ) { }: se escapan entre llaves
                    $txt = [regex]::Replace($a.texto, '[+^%~(){}\[\]]', { param($m) '{' + $m.Value + '}' })
                    [System.Windows.Forms.SendKeys]::SendWait($txt)
                }
                'esconder' { Set-UI 'retirada' }
                'sordina' {
                    Pausar-Escucha $a.ms
                    # el aviso de vuelta va por la via de los temporizadores, que
                    # ya sabe hablar sola cuando vence
                    [void]$script:temporizadores.Add(@{ vence = ($sw.ElapsedMilliseconds + $a.ms + 1500)
                                                        texto = 'Ya vuelvo a escucharte.'; total = $a.ms
                                                        tipo = 'sordina' })
                    Log "SORDINA: escucha apagada $([int]($a.ms / 60000)) min"
                }
                'cerrarTodo' {
                    $abiertas = @(Get-AppsAbiertas)
                    if ($abiertas.Count -eq 0) {
                        $a.desc = 'no hay ningun programa abierto'
                    } elseif (-not $script:confirmado) {
                        # Cerrar programas no se deshace, asi que NUNCA se hace a la
                        # primera: se dice en voz alta que se va a cerrar y se espera
                        # un si. El tipo 'peligrosa' hace ademas que callarse cancele,
                        # al reves que en el resto de confirmaciones.
                        $nombres = @($abiertas | ForEach-Object { if ($_.MainWindowTitle.Length -gt 40) { $_.ProcessName } else { $_.MainWindowTitle } } | Select-Object -Unique)
                        $script:pendiente = @{ texto = 'cierra todos los programas'; vence = 0; tipo = 'peligrosa' }
                        $a.desc = 'voy a cerrar ' + $nombres.Count + ': ' + ($nombres -join ', ') + '. ¿Cierro?'
                    } else {
                        $cerradas = 0
                        foreach ($pr in $abiertas) {
                            # CloseMainWindow es la X de la ventana: si el programa
                            # tiene algo sin guardar, lo preguntara el. Nunca se mata
                            # a la fuerza aqui: perder trabajo por una orden mal oida
                            # seria el peor fallo posible de todo esto.
                            try { if ($pr.CloseMainWindow()) { $cerradas++ } } catch {}
                        }
                        $a.desc = "cerrados $cerradas de $($abiertas.Count)"
                    }
                }
                'estadoEscucha' {
                    if (-not $script:wakeProc -or $script:wakeProc.HasExited) {
                        $a.desc = 'la escucha por voz no esta funcionando ahora mismo; el boton si'
                    } else {
                        $g = 0.0; $alt = 0.0
                        try {
                            $cul = [System.Globalization.CultureInfo]::InvariantCulture
                            $st = ([System.IO.File]::ReadAllText($RutaEstado).Trim()) -split '\|'
                            $g = [double]::Parse($st[0], $cul)
                            $alt = [double]::Parse($st[2], $cul)
                        } catch {}
                        $partes = @()
                        if ($script:pausaHasta -gt 0) {
                            $partes += 'ahora mismo no estoy escuchando, me pediste silencio; di escuchame para volver'
                        } elseif ($g -ge 6) {
                            $partes += "entras muy bajito: estoy amplificando el microfono $([int]$g) veces"
                        } elseif ($g -ge 2.5) {
                            $partes += "te oigo algo bajo, amplifico $([int]$g) veces"
                        } else {
                            $partes += 'el microfono entra bien'
                        }
                        if ($alt -gt 0.02) { $partes += 'y ahora suenan los altavoces, asi que desconfio de lo que oigo' }
                        try {
                            $s = Get-Estadisticas
                            $dia = Get-Date -Format 'yyyy-MM-dd'
                            if ($s.dias.ContainsKey($dia)) {
                                $act = 0; $nada = 0
                                if ($s.dias[$dia].ContainsKey('activacion')) { $act = $s.dias[$dia]['activacion'] }
                                foreach ($r in @('ruido', 'descarte', 'error')) { if ($s.dias[$dia].ContainsKey($r)) { $nada += $s.dias[$dia][$r] } }
                                if ($act -gt 0) { $partes += "hoy me has despertado $act veces y $nada no eran para mi" }
                            }
                        } catch {}
                        $a.desc = ($partes -join ', ')
                    }
                }
                'despertarEscucha' {
                    Reanudar-Escucha
                    # y se retira el aviso de vuelta: ya no hace falta
                    for ($i = $script:temporizadores.Count - 1; $i -ge 0; $i--) {
                        if ($script:temporizadores[$i].tipo -eq 'sordina') { $script:temporizadores.RemoveAt($i) }
                    }
                    Log 'SORDINA: cancelada a mano'
                }
                'zombis' {
                    $z = @(Get-JuegosZombis)
                    if ($z.Count -eq 0) {
                        $a.desc = 'no hay ningun juego colgado'
                    } elseif (-not $script:confirmado) {
                        # cerrar un juego pierde lo no guardado: nunca a la primera
                        $lista = @($z | ForEach-Object {
                            $h = [int]($_.minutos / 60); $m = $_.minutos % 60
                            $cuanto = if ($h -gt 0) { "$h horas" } else { "$m minutos" }
                            "$($_.nombre), abierto desde hace $cuanto"
                        })
                        $script:pendiente = @{ texto = 'cierra los juegos colgados'; vence = 0; tipo = 'peligrosa' }
                        $a.desc = 'sin ventana pero gastando procesador: ' + ($lista -join '; ') + '. ¿Lo cierro?'
                    } else {
                        $n = 0
                        foreach ($x in $z) {
                            # colgado quiere decir que no responde: CloseMainWindow no
                            # sirve (no hay ventana) y el cierre suave se ignora, asi
                            # que aqui si hay que forzarlo. Por eso se pregunta antes.
                            try { $x.proc.Kill(); $n++ } catch {}
                            $script:zombisAvisados.Remove($x.proc.Id)
                        }
                        $a.desc = if ($n -eq 1) { "cerrado $($z[0].nombre)" } else { "cerrados $n juegos colgados" }
                    }
                }
                'cerrarApp' {
                    $ps = @(Get-Process -Name $a.proceso -ErrorAction SilentlyContinue)
                    if ($ps.Count -eq 0) { $a.desc = "$($a.desc): no estaba abierta" }
                    else {
                        # Se le da el momento de cerrarse bien, igual que a los
                        # juegos. Matar de golpe una app que tiene algo sin
                        # guardar es el peor final posible para una orden mal
                        # oida, y aqui se hacia sin esperar nada.
                        foreach ($pr in $ps) {
                            try {
                                if (-not $pr.CloseMainWindow()) {
                                    Start-Sleep -Milliseconds 1500
                                    if (-not $pr.HasExited) { $pr.Kill() }
                                }
                            } catch {}
                        }
                    }
                }
                'cerrarJuego' {
                    if ($script:juegoActivo -and $script:juegoExe) {
                        $ps = @(Get-Process | Where-Object { try { $_.Path -eq $script:juegoExe } catch { $false } })
                        foreach ($pr in $ps) { try { if (-not $pr.CloseMainWindow()) { Start-Sleep -Milliseconds 1500; if (-not $pr.HasExited) { $pr.Kill() } } } catch {} }
                        $a.desc = "cerrando $($script:juegoActivo)"
                    } else { $a.desc = 'no hay ningun juego abierto' }
                }
                'enfocar' {
                    $pr = Get-Process -Name $a.proceso -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
                    if ($pr) {
                        [AX]::ShowWindow($pr.MainWindowHandle, 9) | Out-Null   # SW_RESTORE por si esta minimizada
                        [void][AX]::ForceForeground($pr.MainWindowHandle)
                    } else { $a.desc = "$($a.desc): no esta abierta" }
                }
                'enfocarJuego' {
                    $pr = Get-Process | Where-Object { try { $_.Path -eq $script:juegoExe -and $_.MainWindowHandle -ne 0 } catch { $false } } | Select-Object -First 1
                    if ($pr) { [AX]::ShowWindow($pr.MainWindowHandle, 9) | Out-Null; [void][AX]::ForceForeground($pr.MainWindowHandle) }
                }
                'ocr' {
                    Set-UI 'pensando' 'leyendo la pantalla'
                    $png = Join-Path $TmpDir 'pantalla.png'
                    Save-Captura $png | Out-Null
                    $texto = Invoke-OCR $png
                    if (-not $texto) { $a.desc = 'No veo texto en la pantalla' }
                    else {
                        try { [System.IO.File]::WriteAllText((Join-Path $TmpDir 'ocr.txt'), $texto, (New-Object System.Text.UTF8Encoding($false))) } catch {}
                        $script:ultimaLectura = $texto
                        $a.desc = if ($texto.Length -gt 320) { $texto.Substring(0, 320) + '... y sigue' } else { $texto }
                    }
                }
                'buscarEquipo' {
                    Send-WinKey 0x53   # Win+S
                    Start-Sleep -Milliseconds 700
                    [System.Windows.Forms.SendKeys]::SendWait(([regex]::Replace($a.texto, '[+^%~(){}\[\]]', { param($m) '{' + $m.Value + '}' })))
                }
            }
            $hechas += $a.desc
        } catch {
            $hechas += ($a.desc + " [FALLO: " + $_.Exception.Message + "]")
        }
        Start-Sleep -Milliseconds 250
    }
    return ($hechas -join '; ')
}

# =====================================================================
# VOZ (TTS). Se usa el motor MODERNO de Windows (WinRT), no System.Speech:
# System.Speech solo ve las voces SAPI5 viejas ("Helena Desktop"), mientras
# que WinRT ve las OneCore y, si se instalan, las "Natural" (neuronales),
# que son las unicas que suenan humanas. La preferencia esta ordenada para
# coger automaticamente la mejor disponible sin tocar codigo.
# =====================================================================
$VozOn = [bool](Get-Cfg 'voz' 'activada' $true)
$VozPref = @(Get-Cfg 'voz' 'preferencia' @('Natural', 'es-MX', 'es-'))
$script:vozSyn = $null
$script:vozAwait = $null
$script:vozPlayer = $null

# --- Voz EN LINEA (edge-tts): la de mejor calidad ---
# El worker de Python se mantiene VIVO: arrancarlo por frase costaba 2,5-4,4 s.
# Ademas cachea por hash, asi que una frase repetida ("Anotado.") sale en 2 ms.
$VozMotor = [string](Get-Cfg 'voz' 'motor' 'online')
$VozOnlineNombre = [string](Get-Cfg 'voz' 'vozOnline' 'es-MX-DaliaNeural')
$PyExe = [string](Get-Cfg 'paths' 'python' "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe")
$TtsWorker = Join-Path $LogDir "tts_worker.py"
$VozCache = Join-Path $TmpDir "voz"
$script:ttsProc = $null

# --- REPRODUCCION DE AUDIO ---
# Se usa MediaPlayer de WPF, NO MCI. MCI informaba 'playing' y la posicion
# avanzaba, pero en esta maquina no llegaba a los altavoces: el asistente
# "hablaba" en silencio. MediaPlayer es el metodo con el que el usuario SI
# escucho las pruebas de voz, asi que esta comprobado que suena aqui.
$script:reproductor = $null

function Play-Audio([string]$ruta) {
    if (-not (Test-Path -LiteralPath $ruta)) { return $false }
    try {
        if (-not $script:reproductor) {
            Add-Type -AssemblyName PresentationCore -ErrorAction Stop
            $script:reproductor = New-Object System.Windows.Media.MediaPlayer
        }
        $script:reproductor.Open([Uri]$ruta)
        # Open es asincrono: sin esta pausa Play() no encuentra nada cargado
        Start-Sleep -Milliseconds 250
        $script:reproductor.Play()
        return $true
    } catch {
        Log ("reproduccion fallida, probando MCI: " + $_.Exception.Message)
        try { [AX]::PlayMp3($ruta); return $true } catch { return $false }
    }
}

function Initialize-Online {
    if (-not (Test-Path -LiteralPath $PyExe) -or -not (Test-Path -LiteralPath $TtsWorker)) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $VozCache)) { New-Item -ItemType Directory -Force -Path $VozCache | Out-Null }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $PyExe
        $psi.Arguments = "-u `"$TtsWorker`" $VozOnlineNombre `"$VozCache`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = $LogDir
        $script:ttsProc = [System.Diagnostics.Process]::Start($psi)
        Log "voz: $VozOnlineNombre (neuronal en linea) PID=$($script:ttsProc.Id)"
        return $true
    } catch {
        Log ("WARN: voz en linea no arranco: " + $_.Exception.Message)
        $script:ttsProc = $null
        return $false
    }
}

function Say-Online([string]$texto) {
    if (-not $script:ttsProc -or $script:ttsProc.HasExited) {
        # si murio, que el log diga POR QUE: su stderr se guardaba y nadie lo leia
        if ($script:ttsProc) {
            try {
                $err = $script:ttsProc.StandardError.ReadToEnd()
                if ($err) { Log ("voz online: el worker murio con: " + (($err -replace '\s+', ' ').Trim())) }
                $script:ttsProc.Dispose()
            } catch {}
            $script:ttsProc = $null
        }
        if (-not (Initialize-Online)) { return $false }
        Start-Sleep -Milliseconds 2000
    }
    try {
        # Bytes UTF-8 directos al flujo. .NET Framework no deja fijar la
        # codificacion de StandardInput y en la consola oculta usaba IBM850:
        # cada tilde o "¿" mataba al worker (surrogate en el md5). Verificado.
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($texto + "`n")
        $flujo = $script:ttsProc.StandardInput.BaseStream
        $flujo.Write($bytes, 0, $bytes.Length)
        $flujo.Flush()
        # con tope: si la red se cae, no se puede colgar el bucle para siempre
        $tarea = $script:ttsProc.StandardOutput.ReadLineAsync()
        if (-not $tarea.Wait(8000)) { Log "voz online: sin respuesta en 8 s"; return $false }
        $ruta = $tarea.Result
        if (-not $ruta -or $ruta.StartsWith('ERR')) { Log "voz online: $ruta"; return $false }
        # la capsula mueve la boca con la envolvente de ESTE audio (<mp3>.env);
        # se avisa justo antes de reproducir para que vayan sincronizados.
        # La envolvente da ademas la DURACION real: con ella la pausa de la
        # escucha (y el seguimiento) acaban cuando acaba la voz, no cuando lo
        # estimaba la cuenta de letras
        $script:uiAudio = $ruta
        try {
            $env = $ruta + '.env'
            if (Test-Path -LiteralPath $env) {
                $n = ([System.IO.File]::ReadAllText($env).Trim() -split '\s+').Count
                $dur = $n * 50 + 450
                $fin = $sw.ElapsedMilliseconds + $dur
                $script:pausaHasta = $fin
                $script:uiHasta = [Math]::Max($script:uiHasta, $fin)
            }
        } catch {}
        Refresh-UI
        return (Play-Audio $ruta)
    } catch {
        Log ("voz online error: " + $_.Exception.Message)
        return $false
    }
}

# --- Piper: TTS neuronal OFFLINE, la voz que suena humana de verdad ---
# Windows instala las voces "Natural" (Dalia) como paquete de aplicacion pero
# NO las registra donde las apps pueden verlas: son exclusivas del Narrador.
# Verificado en esta maquina. Por eso se usa Piper.
# CLAVE: el proceso se mantiene VIVO. Arrancarlo por frase costaba 1.311 ms
# (recarga del modelo); persistente baja a ~250 ms.
$PiperDir = Join-Path $LogDir "piper"
$PiperExe = Join-Path $PiperDir "piper.exe"
$PiperModelo = Join-Path $PiperDir "es_MX-claude-high.onnx"
$PiperSalida = Join-Path $PiperDir "salida"
$script:piperProc = $null

function Initialize-Piper {
    if (-not (Test-Path -LiteralPath $PiperExe) -or -not (Test-Path -LiteralPath $PiperModelo)) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $PiperSalida)) { New-Item -ItemType Directory -Force -Path $PiperSalida | Out-Null }
        Get-ChildItem -LiteralPath $PiperSalida -Filter *.wav -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $PiperExe
        $psi.Arguments = "--model `"$PiperModelo`" --output_dir `"$PiperSalida`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = $PiperDir
        $script:piperProc = [System.Diagnostics.Process]::Start($psi)
        Log "voz: Piper es-MX (neuronal, offline) PID=$($script:piperProc.Id)"
        return $true
    } catch {
        Log ("WARN: Piper no arranco: " + $_.Exception.Message)
        $script:piperProc = $null
        return $false
    }
}

function Say-Piper([string]$texto) {
    if (-not $script:piperProc -or $script:piperProc.HasExited) {
        if (-not (Initialize-Piper)) { return $false }
        Start-Sleep -Milliseconds 2500   # carga del modelo
    }
    try {
        $antes = @(Get-ChildItem -LiteralPath $PiperSalida -Filter *.wav -ErrorAction SilentlyContinue).Count
        $script:piperProc.StandardInput.WriteLine($texto)
        $script:piperProc.StandardInput.Flush()
        $w = $null
        $t0 = [DateTime]::UtcNow
        while (([DateTime]::UtcNow - $t0).TotalSeconds -lt 8) {
            Start-Sleep -Milliseconds 25
            $fs = @(Get-ChildItem -LiteralPath $PiperSalida -Filter *.wav -ErrorAction SilentlyContinue)
            if ($fs.Count -gt $antes) { $w = ($fs | Sort-Object LastWriteTime | Select-Object -Last 1); break }
        }
        if (-not $w) { return $false }
        # esperar a que termine de escribirse: reproducirlo a medias da error
        $tam = -1
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Milliseconds 25
            $n = (Get-Item -LiteralPath $w.FullName).Length
            if ($n -eq $tam -and $n -gt 0) { break }
            $tam = $n
        }
        $script:vozPlayer.SoundLocation = $w.FullName
        $script:vozPlayer.Load()
        $script:vozPlayer.Play()
        # dejar solo los ultimos wav para no llenar el disco
        Get-ChildItem -LiteralPath $PiperSalida -Filter *.wav | Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 3 | Remove-Item -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Log ("Piper error: " + $_.Exception.Message)
        return $false
    }
}

function Initialize-Voz {
    if (-not $VozOn) { Log "voz desactivada por configuracion"; return }
    $script:vozPlayer = New-Object System.Media.SoundPlayer
    # orden de preferencia: en linea (mejor voz) -> Piper (offline) -> Windows
    if ($VozMotor -eq 'online' -and (Initialize-Online)) { return }
    if ($VozMotor -ne 'windows' -and (Initialize-Piper)) { return }
    Log "sin motor neuronal; se usara la voz de Windows"
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        # PS 5.1 no sabe "await": hay que llegar a AsTask por reflexion
        $script:vozAwait = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                           $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
        $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media, ContentType = WindowsRuntime]
        $null = [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
        # OJO: la propiedad de instancia AllVoices se proyecta mal en PS 5.1
        # (devuelve 0); hay que usar la ESTATICA.
        $todas = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices
        $elegida = $null
        foreach ($p in $VozPref) {
            $elegida = $todas | Where-Object { $_.DisplayName -like "*$p*" -or $_.Language -like "$p*" } | Select-Object -First 1
            if ($elegida) { break }
        }
        if (-not $elegida) { $elegida = $todas | Select-Object -First 1 }
        $script:vozSyn = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
        if ($elegida) {
            $script:vozSyn.Voice = $elegida
            Log "voz: $($elegida.DisplayName) [$($elegida.Language)]"
        }
        $script:vozPlayer = New-Object System.Media.SoundPlayer
    } catch {
        Log ("WARN: voz no disponible, se sigue sin ella: " + $_.Exception.Message)
        $script:vozSyn = $null
    }
}

function Await-Voz($op, $tipo) {
    $m = $script:vozAwait.MakeGenericMethod($tipo)
    $t = $m.Invoke($null, @($op))
    # NUNCA Wait(-1): esto se ejecuta dentro del bucle principal, y una espera
    # infinita congelaria el asistente entero si el sintetizador se cuelga.
    if (-not $t.Wait(5000)) {
        Log "voz: la sintesis no respondio en 5 s"
        return $null
    }
    return $t.Result
}

# Habla sin bloquear el bucle: la sintesis tarda ~60 ms y Play() es asincrono.
function Say([string]$texto) {
    if (-not $texto) { return }
    $t = ($texto -replace '\s+', ' ').Trim()
    if ($t.Length -eq 0) { return }
    if ($t.Length -gt 300) { $t = $t.Substring(0, 300) }
    # Silenciar la escucha mientras hablamos. La reproduccion es asincrona, asi
    # que se estima la duracion por longitud del texto (~70 ms por caracter) y
    # el bucle principal reanuda al vencer el plazo.
    try {
        $script:finVoz = $sw.ElapsedMilliseconds
        $estimado = [Math]::Min(20000, ($t.Length * 70) + 1200)
        Pausar-Escucha $estimado
        # la capsula muestra lo que se dice y vuelve al reposo al callar. El
        # audio se anade despues, cuando se sabe cual es (Say-Online).
        $script:uiAudio = ''
        Set-UI 'hablando' $t ([Math]::Max($estimado, 2500))
    } catch {}
    # cadena de respaldo: si la red falla, sigue habiendo voz
    if ($script:ttsProc) { if (Say-Online $t) { return } }
    if ($script:piperProc) { if (Say-Piper $t) { return } }
    if (-not $script:vozSyn) { return }
    try {
        $st = Await-Voz ($script:vozSyn.SynthesizeTextToStreamAsync($t)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        if (-not $st) { return }
        $dr = New-Object Windows.Storage.Streams.DataReader($st.GetInputStreamAt(0))
        [void](Await-Voz ($dr.LoadAsync([uint32]$st.Size)) ([uint32]))
        $bytes = New-Object byte[] $st.Size
        $dr.ReadBytes($bytes)
        $wav = Join-Path $TmpDir "voz.wav"
        [System.IO.File]::WriteAllBytes($wav, $bytes)
        $script:vozPlayer.SoundLocation = $wav
        $script:vozPlayer.Load()
        $script:vozPlayer.Play()
    } catch {
        Log ("voz error: " + $_.Exception.Message)
    }
}

# =====================================================================
# ESCUCHA CONTINUA (palabra de activacion)
# Motor SAPI en es-ES, offline. La gramatica es CERRADA: solo el nombre y sus
# variantes. Cuanto mas cerrada, menos falsos disparos, porque el motor no
# tiene otra cosa con la que confundirse. Verificado que rechaza "abre steam",
# "que hora es" y hasta "no va a llover", que foneticamente se le parece.
# =====================================================================
$EscuchaOn = [bool](Get-Cfg 'escucha' 'activada' $true)
$EscuchaNombre = [string](Get-Cfg 'escucha' 'nombre' 'nova')
$EscuchaConf = [double](Get-Cfg 'escucha' 'confianzaMinima' 0.65)
$EscuchaMotor = [string](Get-Cfg 'escucha' 'motor' 'vosk')
# ganancia por software: 'auto' mide el pico real y se ajusta sola
$EscuchaGanancia = [string](Get-Cfg 'escucha' 'ganancia' 'auto')
$script:wakeProc = $null
$script:finVoz = 0
$MarcaWake = Join-Path $TmpDir "despierta.flag"
# Mientras exista esta marca, el worker ignora el microfono. Se crea al hablar
# y al dictar: la voz del propio asistente volvia al microfono con pico 0.99 y
# hundia su ganancia automatica, dejandolo sordo.
$MarcaPausa = Join-Path $TmpDir "escucha-pausa.flag"
# --- DICTADO POR VOSK (sustituye a Win+H) ---
# Win+H era el origen de casi todos los fallos: robaba el foco -y si fallaba,
# el texto se escribia en OTRA ventana-, deformaba palabras ("steamidos",
# "little nighters 3") y obligaba a esperar el silencio desde fuera. El worker
# ya tiene el microfono abierto: dicta el tambien.
$MotorDictado = [string](Get-Cfg 'input' 'dictado' 'vosk')
# MODO DE SEGUIMIENTO: tras responder, se vuelve a escuchar durante este
# tiempo SIN palabra de activacion. Si hablas, es otra orden; si no, se cierra
# en silencio. Permite encadenar: "nova, abre steam" ... "y sube el volumen"
# ... "y avisame en veinte minutos". 0 = desactivado. Solo con el dictado del
# worker (whisper/vosk): Win+H no puede esperar sin robar el foco.
$SeguimientoMs = [int](Get-Cfg 'input' 'seguimientoMs' 2500)
# 'vosk' y 'whisper' comparten el camino: el worker de escucha graba la orden
# y la transcribe (Whisper es mucho mas preciso; Vosk pequeno se queda para
# la palabra de activacion). 'windows' es Win+H.
$DictadoWorker = ($MotorDictado -in @('vosk', 'whisper'))
$WhisperModelo = [string](Get-Cfg 'input' 'whisperModelo' 'small')
# Modelo de repaso: el rapido dicta, y solo cuando la orden no se reconoce se
# repasa el MISMO audio con este (mas lento, bastante mas preciso con los
# nombres propios). Vacio = desactivado, se dicta solo con el rapido.
$WhisperPreciso = [string](Get-Cfg 'input' 'whisperModeloPreciso' '')
$MarcaDictar = Join-Path $TmpDir "dictar.flag"
# confirmacion por voz de coincidencias dudosas: el worker escucha si/no
$MarcaConfirmar = Join-Path $TmpDir "confirmar.flag"
$RutaConfirmacion = Join-Path $TmpDir "confirmacion.txt"
# vocabulario (apps, sitios, juegos) para que Whisper acierte los nombres
$RutaVocabulario = Join-Path $TmpDir "vocabulario.txt"
$RutaDictado = Join-Path $TmpDir "dictado.txt"
$RutaParcial = Join-Path $TmpDir "dictado-parcial.txt"
$RutaEstado = Join-Path $TmpDir "escucha-estado.txt"
# Mientras hay un juego delante, la palabra de activacion se apaga y solo vale
# el boton. Es cuando mas molesta equivocarse -el 11/09 abrio un juego solo en
# mitad de una partida- y cuando el boton del mando esta mas a mano.
$MarcaSoloBoton = Join-Path $TmpDir "solo-boton.flag"
$SoloBotonEnJuego = [bool](Get-Cfg 'escucha' 'soloBotonEnJuego' $true)
$MarcaReintento = Join-Path $TmpDir "reintentar.flag"
$RutaReintento = Join-Path $TmpDir "reintento.txt"
# nivel de voz 0..1 que el worker escribe mientras dictas; lo lee la interfaz
# directamente (nova_ui.exe busca ui-nivel.txt junto a ui-estado.json)
$RutaNivel = Join-Path $TmpDir "ui-nivel.txt"

# MARCAS HUERFANAS. Si el asistente murio de golpe -taskkill, cierre de sesion,
# un cuelgue- sus marcas se quedan puestas y el worker nuevo las obedece como si
# fueran de ahora. La peor con diferencia es escucha-pausa.flag: el worker nace
# SORDO, tirando todo el audio, y no hay forma de sacarlo de ahi hablando,
# porque justamente no oye. Reanudar-Escucha solo la borra si pausaHasta > 0, y
# en un proceso recien arrancado vale 0, asi que se quedaba puesta para siempre.
# Una dictar.flag huerfana es mas leve pero tambien molesta: el worker se pone a
# grabar una orden que nadie esta dictando. Se limpian todas al arrancar.
foreach ($m in @($MarcaPausa, $MarcaSoloBoton, $MarcaDictar, $MarcaConfirmar, $MarcaReintento, $MarcaWake)) {
    if (Test-Path -LiteralPath $m) {
        Log "marca huerfana de la sesion anterior: $(Split-Path -Leaf $m)"
        try { Remove-Item -LiteralPath $m -Force -ErrorAction SilentlyContinue } catch {}
    }
}
$script:pausaHasta = 0

function Pausar-Escucha([int]$ms) {
    try {
        [System.IO.File]::WriteAllText($MarcaPausa, 'x')
        $fin = $sw.ElapsedMilliseconds + $ms
        if ($fin -gt $script:pausaHasta) { $script:pausaHasta = $fin }
    } catch {}
}

function Reanudar-Escucha {
    try { Remove-Item -LiteralPath $MarcaPausa -Force -ErrorAction SilentlyContinue } catch {}
    $script:pausaHasta = 0
}

function Initialize-Escucha {
    if (-not $EscuchaOn) { Log "escucha continua desactivada por configuracion"; return }
    # DOS MOTORES POSIBLES:
    #  vosk (por defecto): lee el microfono en Python y AMPLIFICA por software.
    #    En esta maquina el microfono entra muy bajo (prueba de Windows: 7 %) y
    #    SAPI lo tomaba por silencio. Vosk da acceso al audio crudo, asi que la
    #    ganancia se puede corregir; SAPI no lo permitia.
    #  sapi: worker en C# (wake_worker.exe). Se conserva como alternativa.
    #    OJO: NO puede ser un script de PowerShell. PowerShell no soporta los
    #    eventos asincronos de SAPI: el manejador corre en el hilo del
    #    reconocedor y mata el proceso en silencio. Comprobado dos veces.
    try {
        Remove-Item -LiteralPath $MarcaWake -Force -ErrorAction SilentlyContinue
        if ($EscuchaMotor -eq 'vosk') {
            $worker = Join-Path $LogDir "wake_vosk.py"
            if (-not (Test-Path -LiteralPath $worker)) { Log "WARN: falta wake_vosk.py"; return }
            # La confianza minima va TAMBIEN aqui: hasta ahora solo la recibia el
            # wake_worker.exe viejo, asi que el ajuste del config no hacia nada.
            $conf = $EscuchaConf.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $script:wakeProc = Start-Process -FilePath $PyExe `
                -ArgumentList @('-u', $worker, $EscuchaNombre, $MarcaWake, $EventLog, $EscuchaGanancia,
                                $MarcaPausa, $MarcaDictar, $RutaDictado, $RutaParcial, $RutaNivel,
                                $MarcaConfirmar, $RutaConfirmacion, "$MotorDictado`:$WhisperModelo", $RutaVocabulario,
                                $conf, $MarcaReintento, $RutaReintento, $WhisperPreciso) `
                -WorkingDirectory $LogDir -WindowStyle Hidden -PassThru
        } else {
            $worker = Join-Path $LogDir "wake_worker.exe"
            if (-not (Test-Path -LiteralPath $worker)) { Log "WARN: falta wake_worker.exe"; return }
            $conf = $EscuchaConf.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $script:wakeProc = Start-Process -FilePath $worker `
                -ArgumentList @($EscuchaNombre, $conf, $MarcaWake, $EventLog) `
                -WindowStyle Hidden -PassThru
        }
        $null = $script:wakeProc.Handle
        # Es un portatil de JUEGOS: la escucha nunca debe competir por CPU con
        # el juego en primer plano.
        try { $script:wakeProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
        Log "escucha continua ACTIVA [$EscuchaMotor] (worker PID=$($script:wakeProc.Id)): di '$EscuchaNombre'"
    } catch {
        Log ("WARN: escucha continua no arranco: " + $_.Exception.Message)
        $script:wakeProc = $null
    }
}

# =====================================================================
# INTERFAZ (nova_ui.exe): la cara visible del asistente
# Una capsula de cristal en la esquina inferior izquierda que vive en su
# propio proceso WPF. Aqui NO se dibuja nada: solo se escribe un JSON con el
# estado y la interfaz lo lee cada 80 ms. Mismo patron de archivos que los
# workers de voz y escucha; cero hilos compartidos con este bucle.
#
# La barra antigua de WinForms sigue existiendo porque el dictado de Windows
# necesita una ventana con foco donde escribir, pero se vuelve invisible
# (opacidad minima) cuando la interfaz nueva esta activa.
# =====================================================================
$UiNuevaOn = [bool](Get-Cfg 'ui' 'nueva' $true)
$RutaUiEstado = Join-Path $TmpDir "ui-estado.json"
$script:uiProc = $null
$script:uiUltimo = ''
$script:uiHasta = 0     # cuando vence, la capsula vuelve al reposo
$script:uiCheck = 0
$script:uiIntentos = 0

# Estados: reposo | escuchando | pensando | hablando | error.
# $ms > 0: volver al reposo pasado ese tiempo (si no hay nada mas en marcha).
# Ademas del estado, el JSON lleva:
#   evento/n : animacion puntual (despierta, hecho, aviso). La interfaz la
#              dispara cuando cambia n, asi que el mismo evento puede repetirse.
#   juego    : ejecutable del juego en primer plano; su icono pasa a ser el
#              avatar de la capsula y el punto se vuelve insignia de estado.
$script:uiEstado = 'reposo'
$script:uiTexto = ''
$script:uiEvento = ''
$script:uiEventoN = 0
$script:juegoExe = ''
$script:uiAudio = ''        # mp3 que suena; la capsula busca <mp3>.env para mover la boca
$script:uiBateria = 100
$script:uiCargando = 0
$script:uiPerfil = ''       # ultimo perfil aplicado ("noche" cambia la paleta)
$script:uiCarga = 0         # % de CPU: la capsula se agita por encima del 85
$script:uiProgreso = 0      # 0..1 mientras opencode trabaja (linea del borde)
$script:uiVoz = 0           # indice de la voz que dicto (por tono), 0 = la habitual
$script:uiClima = ''        # emoji del tiempo: solo unos segundos cuando se pregunta
$script:uiClimaHasta = 0
$script:uiAnimo = 0         # -1..1 segun aciertos y errores de las ultimas 24 h

function ConvertTo-JsonTexto([string]$s) {
    $t = (($s -replace '[\r\n\t]+', ' ') -replace '\s+', ' ').Trim()
    return $t.Replace('\', '\\').Replace('"', '\"')
}

function Set-UI([string]$estado, [string]$texto = '', [int]$ms = 0) {
    if (-not $UiNuevaOn) { return }
    $t = (($texto -replace '[\r\n\t]+', ' ') -replace '\s+', ' ').Trim()
    if ($t.Length -gt 140) { $t = $t.Substring(0, 137) + "..." }
    $script:uiEstado = $estado
    $script:uiTexto = $t
    # temporizador mas proximo, en tiempo de reloj (ms Unix) para que la
    # capsula dibuje el anillo con su propio reloj sin que haya que reescribir
    $tFin = 0; $tTotal = 0
    if ($script:temporizadores -and $script:temporizadores.Count -gt 0) {
        $prox = $null
        foreach ($tp in $script:temporizadores) { if ($null -eq $prox -or $tp.vence -lt $prox.vence) { $prox = $tp } }
        if ($prox) {
            $tFin = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() + ($prox.vence - $sw.ElapsedMilliseconds)
            $tTotal = $prox.total
        }
    }
    $json = '{"estado":"' + $estado + '","texto":"' + (ConvertTo-JsonTexto $t) + '","nivel":0' +
            ',"evento":"' + $script:uiEvento + '","n":' + $script:uiEventoN +
            ',"juego":"' + (ConvertTo-JsonTexto $script:juegoExe) + '"' +
            ',"audio":"' + (ConvertTo-JsonTexto $script:uiAudio) + '"' +
            ',"bateria":' + $script:uiBateria + ',"cargando":' + $script:uiCargando +
            ',"tempoFin":' + $tFin + ',"tempoTotal":' + $tTotal +
            ',"perfil":"' + $script:uiPerfil + '"' +
            ',"carga":' + $script:uiCarga + ',"clima":"' + (ConvertTo-JsonTexto $script:uiClima) + '"' +
            ',"animo":' + ([double]$script:uiAnimo).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture) +
            ',"progreso":' + ([double]$script:uiProgreso).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture) +
            ',"voz":' + $script:uiVoz + '}'
    if ($json -ne $script:uiUltimo) {
        # UTF-8 SIN BOM: la interfaz lo lee tal cual y el BOM colaria un caracter
        try { [System.IO.File]::WriteAllText($RutaUiEstado, $json, (New-Object System.Text.UTF8Encoding $false)) } catch {}
        $script:uiUltimo = $json
    }
    $script:uiHasta = if ($ms -gt 0) { $sw.ElapsedMilliseconds + $ms } else { 0 }
    # si se pregunto el tiempo, que el emoji dure al menos lo que la respuesta
    if ($script:uiClimaHasta -gt 0 -and $script:uiHasta -gt $script:uiClimaHasta) { $script:uiClimaHasta = $script:uiHasta + 1500 }
}

# Dispara una animacion sin cambiar el estado (el estado se reescribe igual).
function Send-UIEvento([string]$evento) {
    # eco en el mando: lo que la capsula celebra, el mando lo hace sentir
    switch ($evento) {
        'hecho' { Start-Vibracion @(50, 60, 50) 18000 }
        'logro' { Start-Vibracion @(80, 60, 80, 60, 160) 26000 }
        'aviso' { Start-Vibracion @(120, 80, 120) 22000 }
    }
    if (-not $UiNuevaOn) { return }
    $script:uiEvento = $evento
    $script:uiEventoN++
    Refresh-UI
}

# Reescribe el estado actual (tras cambiar el juego o lanzar un evento) sin
# tocar el plazo de vuelta al reposo.
function Refresh-UI {
    $resta = 0
    if ($script:uiHasta -gt 0) { $resta = [Math]::Max(1, $script:uiHasta - $sw.ElapsedMilliseconds) }
    Set-UI $script:uiEstado $script:uiTexto $resta
}

function Initialize-UI {
    if (-not $UiNuevaOn) { Log "interfaz nueva desactivada por configuracion"; return }
    $exe = Join-Path $LogDir "nova_ui.exe"
    if (-not (Test-Path -LiteralPath $exe)) { Log "WARN: falta nova_ui.exe (compilar con tools\compilar-ui.ps1); sigue la barra antigua"; $script:UiNuevaOn = $false; return }
    try {
        # arrancar siempre en reposo: un JSON viejo de otra sesion dejaria la
        # capsula abierta con un texto rancio
        $script:uiUltimo = ''
        Set-UI 'reposo'
        # se le pasa nuestro PID: si este proceso muere, la capsula se cierra sola
        $script:uiProc = Start-Process -FilePath $exe -ArgumentList @((ConvertTo-CmdArg $RutaUiEstado), "$PID") `
            -WorkingDirectory $LogDir -PassThru
        $null = $script:uiProc.Handle
        try { $script:uiProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
        Log "interfaz ACTIVA (PID=$($script:uiProc.Id))"
    } catch {
        Log ("WARN: la interfaz no arranco: " + $_.Exception.Message)
        $script:uiProc = $null
    }
}

# Win + Alt + <tecla>: atajos de la barra de juego (grabar, captura)
function Send-WinAlt([int]$vk) {
    [AX]::keybd_event([byte]$VK_LWIN, 0, 0, [UIntPtr]::Zero)
    [AX]::keybd_event([byte]$VK_MENU, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$VK_MENU, 0, $KEYUP, [UIntPtr]::Zero)
    [AX]::keybd_event([byte]$VK_LWIN, 0, $KEYUP, [UIntPtr]::Zero)
}

# --- QUE ESTA EN PRIMER PLANO ---
# Saber a que juegas desbloquea frases naturales ("cuanto llevo jugando",
# "busca una guia de esto") sin tener que nombrarlo cada vez.
$script:juegoActivo = $null
$script:juegoDesde = 0

function Get-ProcesoEnPrimerPlano {
    try {
        $h = [AX]::GetForegroundWindow()
        if ($h -eq [IntPtr]::Zero) { return $null }
        $hilo = [AX]::GetWindowThreadProcessId($h, [IntPtr]::Zero)
        if ($hilo -eq 0) { return $null }
        # el hilo no da el PID directamente: se busca por ventana principal
        foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
            if ($p.MainWindowHandle -eq $h) { return $p }
        }
    } catch {}
    return $null
}

# Devuelve el juego de Steam que esta en primer plano, o $null.
function Get-JuegoEnPrimerPlano {
    $p = Get-ProcesoEnPrimerPlano
    if (-not $p) { return $null }
    $ruta = ''
    try { $ruta = $p.Path } catch { return $null }
    if (-not $ruta -or $ruta -notmatch '(?i)steamapps\\common\\([^\\]+)') { return $null }
    $carpeta = $Matches[1]
    # el ejecutable se guarda aparte: la capsula saca de el el icono del juego
    $script:juegoExeCandidato = $ruta
    # la carpeta de instalacion suele parecerse al titulo
    $j = Find-Juego $carpeta
    if ($j) { return $j.nombre }
    return $carpeta
}

# --- RUTINAS DE JUEGO (config.json -> juego) ---
# Al entrar en un juego se aplica un perfil (por defecto "juego"); al salir se
# restaura el brillo que habia. El volumen no se puede leer sin librerias
# externas, asi que no se restaura: se avisa en vez de fingir.
$JuegoPerfilEntrar = [string](Get-Cfg 'juego' 'perfilAlEntrar' 'juego')
$JuegoRestaurar = [bool](Get-Cfg 'juego' 'restaurarAlSalir' $true)
$JuegoAvisoMin = [int](Get-Cfg 'juego' 'avisoMinutos' 120)
$script:juegoBrilloAntes = $null
$script:juegoAvisado = $false

$script:juegoHoras = 0

# --- EL TIEMPO (config.json -> clima) ---
# Una consulta por hora a Open-Meteo (sin clave). Si no hay coordenadas en la
# configuracion se piden UNA vez a ip-api.com por la IP publica: eso manda la
# IP a un tercero; con clima.lat/lon en config.json no hace falta.
$ClimaOn = [bool](Get-Cfg 'clima' 'activada' $true)
$ClimaLat = Get-Cfg 'clima' 'lat' $null
$ClimaLon = Get-Cfg 'clima' 'lon' $null
$script:clima = $null
$script:climaCheck = -3600000

function Update-Clima {
    if (-not $ClimaOn) { return }
    try {
        if ($null -eq $ClimaLat -or $null -eq $ClimaLon) {
            $g = Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=lat,lon,city' -TimeoutSec 4
            if ($g -and $g.lat) { $script:ClimaLat = [double]$g.lat; $script:ClimaLon = [double]$g.lon; Log "clima: ubicacion por IP ($($g.city))" }
            else { return }
        }
        $cul = [System.Globalization.CultureInfo]::InvariantCulture
        $u = 'https://api.open-meteo.com/v1/forecast?latitude=' + ([double]$ClimaLat).ToString($cul) + '&longitude=' + ([double]$ClimaLon).ToString($cul) + '&current_weather=true'
        $r = Invoke-RestMethod -Uri $u -TimeoutSec 4
        $cw = $r.current_weather
        if (-not $cw) { return }
        $codigo = [int]$cw.weathercode
        $noche = ($cw.is_day -eq 0)
        # codigos WMO -> emoji + descripcion hablada
        $emoji = '☀️'; $desc = 'esta despejado'
        if ($codigo -ge 1 -and $codigo -le 2) { $emoji = '⛅'; $desc = 'hay algunas nubes' }
        elseif ($codigo -eq 3) { $emoji = '☁️'; $desc = 'esta nublado' }
        elseif ($codigo -ge 45 -and $codigo -le 48) { $emoji = '🌫️'; $desc = 'hay niebla' }
        elseif ($codigo -ge 51 -and $codigo -le 67) { $emoji = '🌧️'; $desc = 'esta lloviendo' }
        elseif ($codigo -ge 71 -and $codigo -le 77) { $emoji = '🌨️'; $desc = 'esta nevando' }
        elseif ($codigo -ge 80 -and $codigo -le 82) { $emoji = '🌦️'; $desc = 'hay chubascos' }
        elseif ($codigo -ge 95) { $emoji = '⛈️'; $desc = 'hay tormenta' }
        elseif ($noche) { $emoji = '🌙'; $desc = 'esta despejado' }
        $temp = [int][Math]::Round([double]$cw.temperature)
        $script:clima = @{ emoji = $emoji; desc = $desc; temp = $temp }
        # el avatar NO cambia solo: la carita manda. El tiempo se ensena solo
        # cuando se pregunta (Resolve-Fragment) y unos segundos.
        Log "clima: $desc, $temp grados (codigo $codigo)"
    } catch { Log ("clima: no disponible (" + $_.Exception.Message + ")") }
}

# =====================================================================
# REGLAS POR VOZ: "cuando abra elden ring pon modo noche", "cuando la bateria
# baje del 20 bloquea", "todos los dias a las 9 pon el brillo al 60", "cada
# 45 minutos avisame en 0 minutos que descanse". Se guardan en reglas.json y
# se evaluan desde el bucle principal. La accion es una orden LOCAL (se
# valida con Test-FastCommand al crearla): nada de texto libre al modelo.
# =====================================================================
$ReglasPath = Join-Path $LogDir 'reglas.json'
$script:reglas = $null
$HORAS_PALABRA = @{ 'una' = 1; 'dos' = 2; 'tres' = 3; 'cuatro' = 4; 'cinco' = 5; 'seis' = 6; 'siete' = 7; 'ocho' = 8; 'nueve' = 9; 'diez' = 10; 'once' = 11; 'doce' = 12 }

function Get-Reglas {
    if ($null -ne $script:reglas) { return ,$script:reglas }
    $script:reglas = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $ReglasPath) {
        try {
            # sin @(): ver el comentario de Get-Recordatorios
            $crudoReglas = Get-Content -LiteralPath $ReglasPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($r in $crudoReglas) {
                if ($null -eq $r -or -not [string]$r.tipo) { continue }
                [void]$script:reglas.Add(@{ id = [int]$r.id; tipo = [string]$r.tipo; valor = [string]$r.valor; accion = [string]$r.accion; ultima = [string]$r.ultima })
            }
        } catch {}
    }
    # la coma evita que PowerShell "desenrolle" la lista vacia en $null
    return ,$script:reglas
}

function Save-Reglas {
    try {
        # foreach sobre la variable, no por tuberia: la lista llega como UN
        # objeto (por la coma de Get-Reglas) y la tuberia no la desenrollaria
        $g = Get-Reglas
        $lista = @()
        foreach ($x in $g) {
            $o = New-Object PSObject
            foreach ($k in 'id', 'tipo', 'valor', 'accion', 'ultima') { $o | Add-Member -NotePropertyName $k -NotePropertyValue $x[$k] }
            $lista += $o
        }
        $json = if ($lista.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($lista) -Depth 4 }
        [System.IO.File]::WriteAllText($ReglasPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch { Log ("reglas: no pude guardar: " + $_.Exception.Message) }
}

function Describe-Regla($r) {
    $cuando = switch ($r.tipo) {
        'juegoAbre' { if ($r.valor) { "cuando abras $($r.valor)" } else { 'cuando abras un juego' } }
        'juegoCierra' { if ($r.valor) { "cuando cierres $($r.valor)" } else { 'cuando cierres el juego' } }
        'bateria' { "cuando la bateria baje del $($r.valor) por ciento" }
        'hora' { "todos los dias a las $($r.valor)" }
        'cada' { "cada $($r.valor) minutos" }
        default { $r.tipo }
    }
    return "$cuando, $($r.accion)"
}

# Intenta interpretar la frase como regla. Devuelve la respuesta hablada, o
# $null si no es una regla.
function Invoke-ReglaVoz([string]$text) {
    $p = ConvertTo-Plain $text
    $g = Get-Reglas
    if ($p -match '^(?:borra|elimina|quita|olvida)\s+(?:todas\s+)?(?:las\s+)?reglas$') {
        $g.Clear(); Save-Reglas; return "Listo, sin reglas."
    }
    if ($p -match '^(?:borra|elimina|quita|olvida)\s+la\s+regla\s+(\d+)$') {
        $id = [int]$Matches[1]
        $q = @($g | Where-Object { $_.id -eq $id })
        if ($q.Count -eq 0) { return "No hay ninguna regla $id" }
        foreach ($x in $q) { $g.Remove($x) }
        Save-Reglas; return "Regla $id borrada."
    }
    if ($p -match '^(?:que reglas hay|que reglas tengo|mis reglas|cuales son las reglas|lista las reglas|dime las reglas)$') {
        if ($g.Count -eq 0) { return "No tienes reglas. Puedes decir: cuando abra un juego, pon modo juego." }
        return ("Tienes " + $g.Count + ": " + (($g | ForEach-Object { "regla $($_.id), " + (Describe-Regla $_) }) -join '. '))
    }
    $tipo = $null; $valor = ''; $accion = ''
    if ($p -match '^cuando\s+(?:se\s+)?(?:abra|inicie|arranque|empiece|entre a|entre en)\s+(?:el\s+|un\s+|cualquier\s+)?(.+?)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea)\b.*)$') {
        $tipo = 'juegoAbre'; $obj = $Matches[1].Trim(); $accion = $Matches[2].Trim()
        if ($obj -notmatch '^(?:juego|videojuego|algo|cualquier cosa)$') { $j = Find-Juego $obj; if ($j) { $valor = $j.nombre } else { return "No conozco el juego '$obj'" } }
    }
    elseif ($p -match '^cuando\s+(?:se\s+)?(?:cierre|termine|acabe|salga de|salga del)\s+(?:el\s+|un\s+|cualquier\s+)?(.+?)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea)\b.*)$') {
        $tipo = 'juegoCierra'; $obj = $Matches[1].Trim(); $accion = $Matches[2].Trim()
        if ($obj -notmatch '^(?:juego|videojuego|algo|cualquier cosa)$') { $j = Find-Juego $obj; if ($j) { $valor = $j.nombre } else { return "No conozco el juego '$obj'" } }
    }
    elseif ($p -match '^cuando\s+la\s+(?:bateria|pila)\s+(?:baje|este|llegue|caiga)\s+(?:del|al|a|por debajo del|por debajo de|de|menos del)\s+(\d{1,3})\s*(?:por ciento|%)?\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea)\b.*)$') {
        $tipo = 'bateria'; $valor = [string][int]$Matches[1]; $accion = $Matches[2].Trim()
    }
    elseif ($p -match '^(?:todos los dias|cada dia|diariamente|siempre)?\s*a\s+las?\s+(\d{1,2}|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce)(?::(\d{2})|\s+y\s+media|\s+y\s+cuarto)?\s*(de la manana|de la tarde|de la noche|am|pm)?\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea)\b.*)$') {
        # Los grupos, COPIADOS antes de nada: el primer -match de las lineas de
        # abajo (la franja) reescribe $Matches entero y $Matches[4] desaparecia.
        # 'a las 10 de la noche pon modo noche' reventaba con una excepcion que
        # se tragaba el catch de Invoke-FastCommand, asi que la regla no se
        # creaba y nadie se enteraba. Lo mismo con 'y media' y 'y cuarto': el
        # ejemplo de la documentacion llevaba roto desde que se escribio.
        $g0 = $Matches[0]; $g1 = $Matches[1]; $g2 = $Matches[2]; $g3 = $Matches[3]; $g4 = $Matches[4]
        $h = $g1; if ($HORAS_PALABRA.ContainsKey($h)) { $h = $HORAS_PALABRA[$h] }; $h = [int]$h
        $m = 0
        if ($g2) { $m = [int]$g2 } elseif ($g0 -match 'y media') { $m = 30 } elseif ($g0 -match 'y cuarto') { $m = 15 }
        $franja = $g3
        if ($franja -match 'tarde|noche|pm' -and $h -lt 12) { $h += 12 }
        if ($franja -match 'manana|am' -and $h -eq 12) { $h = 0 }
        $tipo = 'hora'; $valor = ('{0:00}:{1:00}' -f $h, $m); $accion = $g4.Trim()
    }
    elseif ($p -match '^cada\s+(\d+)\s*(minutos?|horas?)\s*,?\s*((?:' + $VERBOS + '|modo|activa|desactiva|bloquea)\b.*)$') {
        $n = [int]$Matches[1]; if ($Matches[2] -match '^hora') { $n *= 60 }
        if ($n -lt 1) { return "Cada cuanto tiempo? Necesito al menos un minuto." }
        $tipo = 'cada'; $valor = [string]$n; $accion = $Matches[3].Trim()
    }
    if (-not $tipo) { return $null }
    if (-not (Test-FastCommand $accion)) { return "Entendi la condicion, pero no reconozco la accion '$accion'. Tiene que ser una orden que yo sepa hacer." }
    $id = 1; foreach ($x in $g) { if ($x.id -ge $id) { $id = $x.id + 1 } }
    $r = @{ id = $id; tipo = $tipo; valor = $valor; accion = $accion; ultima = '' }
    [void]$g.Add($r); Save-Reglas
    Log ("REGLA $id guardada: " + (Describe-Regla $r))
    Add-Estadistica 'local' "regla: $text"
    return ("Regla $id guardada: " + (Describe-Regla $r) + ".")
}

# Ejecuta las reglas de un tipo cuyo valor encaje.
function Invoke-Reglas([string]$tipo, [string]$dato = '') {
    $g = Get-Reglas
    if ($g.Count -eq 0) { return }
    $hoy = Get-Date -Format 'yyyy-MM-dd'
    foreach ($r in @($g)) {
        if ($r.tipo -ne $tipo) { continue }
        $dispara = $false
        switch ($tipo) {
            'juegoAbre' { $dispara = (-not $r.valor -or $r.valor -eq $dato) }
            'juegoCierra' { $dispara = (-not $r.valor -or $r.valor -eq $dato) }
            'bateria' {
                $pct = [int]$dato
                if ($pct -le [int]$r.valor) { if ($r.ultima -ne 'baja') { $dispara = $true; $r.ultima = 'baja' } }
                elseif ($pct -gt ([int]$r.valor + 10)) { $r.ultima = '' }
            }
            'hora' { if ($dato -eq $r.valor -and $r.ultima -ne $hoy) { $dispara = $true; $r.ultima = $hoy } }
            'cada' {
                $ult = 0; if ($r.ultima) { [double]::TryParse($r.ultima, [ref]$ult) | Out-Null }
                if (($sw.ElapsedMilliseconds - $ult) -ge ([int]$r.valor * 60000)) { $dispara = $true; $r.ultima = [string]$sw.ElapsedMilliseconds }
            }
        }
        if (-not $dispara) { continue }
        Log ("REGLA $($r.id) dispara: " + (Describe-Regla $r))
        $script:confirmado = $true
        $res = $null
        try { $res = Invoke-FastCommand $r.accion } catch { $res = $null } finally { $script:confirmado = $false }
        if ($res) { Send-UIEvento 'hecho'; Say ("Regla $($r.id): $res") } else { Log "REGLA $($r.id): la accion no se pudo ejecutar" }
    }
    if ($tipo -in @('bateria', 'hora', 'cada')) { Save-Reglas }
}

# =====================================================================
# FECHAS: "recuerda que el 3 de octubre es el cumple de Ana" -> ademas del
# diario, se guarda en memoria\fechas.json y ese dia lo celebra al arrancar.
# =====================================================================
$FechasPath = Join-Path $MemoriaDir 'fechas.json'
$MESES = @{ 'enero' = 1; 'febrero' = 2; 'marzo' = 3; 'abril' = 4; 'mayo' = 5; 'junio' = 6; 'julio' = 7; 'agosto' = 8; 'septiembre' = 9; 'setiembre' = 9; 'octubre' = 10; 'noviembre' = 11; 'diciembre' = 12 }

function Get-Fechas {
    $lista = @()
    if (Test-Path -LiteralPath $FechasPath) {
        # mismo fantasma que en los recordatorios: ver Get-Recordatorios
        try {
            $crudo = Get-Content -LiteralPath $FechasPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($x in $crudo) { if ($null -ne $x -and [string]$x.texto) { $lista += $x } }
        } catch { $lista = @() }
    }
    return $lista
}

function Add-Fecha([string]$frase) {
    $p = ConvertTo-Plain $frase
    if ($p -notmatch '\b(?:el\s+)?(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\b') { return $null }
    $d = [int]$Matches[1]; $m = $MESES[$Matches[2]]
    if ($d -lt 1 -or $d -gt 31) { return $null }
    $md = '{0:00}-{1:00}' -f $m, $d
    $lista = @(Get-Fechas | Where-Object { -not ($_.md -eq $md -and $_.texto -eq $frase) })
    $lista += New-Object PSObject -Property @{ md = $md; texto = $frase }
    try {
        [System.IO.File]::WriteAllText($FechasPath, (ConvertTo-Json -InputObject @($lista) -Depth 3), (New-Object System.Text.UTF8Encoding($false)))
        Log "FECHA guardada ($md): $frase"
    } catch {}
    return $md
}

function Test-FechasHoy {
    $hoy = Get-Date -Format 'MM-dd'
    $de = @(Get-Fechas | Where-Object { $_.md -eq $hoy })
    if ($de.Count -eq 0) { return }
    foreach ($f in $de) {
        Log "FECHA de hoy: $($f.texto)"
        Say ("Hoy es un dia especial: " + $f.texto)
        Send-UIEvento 'logro'
    }
}

# =====================================================================
# RECORDATORIOS CON FECHA Y HORA: "recuerdame manana a las 10 que llame al
# medico", "avisame el viernes a las cinco de la tarde que...", "recuerdame
# a las 3 revisar el horno" (hoy si aun no ha pasado; si no, manana). Se
# guardan en memoria\recordatorios.json y sobreviven a los reinicios.
# =====================================================================
$RecordatoriosPath = Join-Path $MemoriaDir 'recordatorios.json'
$DIAS_SEMANA = @{ 'lunes' = 1; 'martes' = 2; 'miercoles' = 3; 'jueves' = 4; 'viernes' = 5; 'sabado' = 6; 'domingo' = 0 }

function Get-Recordatorios {
    $lista = @()
    if (Test-Path -LiteralPath $RecordatoriosPath) {
        # OJO con @(...) alrededor de ConvertFrom-Json: con un "[]" en el
        # archivo, PowerShell 5.1 no devuelve una lista vacia sino una lista de
        # UN elemento que contiene la lista vacia. Ese fantasma se guardaba
        # luego como {"value":[],"Count":0} dentro del json y contaba como un
        # recordatorio de verdad. El foreach sobre el resultado crudo si da 0.
        try {
            $crudo = Get-Content -LiteralPath $RecordatoriosPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($x in $crudo) { if ($null -ne $x -and [string]$x.texto) { $lista += $x } }
        } catch { $lista = @() }
    }
    return $lista
}

function Save-Recordatorios($lista) {
    $json = if (@($lista).Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($lista) -Depth 3 }
    [System.IO.File]::WriteAllText($RecordatoriosPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-RecordatorioVoz([string]$text) {
    $p = ConvertTo-Plain $text
    if ($p -match '^(?:que recordatorios (?:tengo|hay)|mis recordatorios|que tengo pendiente|que me tienes que recordar)$') {
        $rs = @(Get-Recordatorios | Sort-Object cuando)
        if ($rs.Count -eq 0) { return "No tienes recordatorios. Di, por ejemplo: recuerdame manana a las diez que llame al medico." }
        $cul = New-Object System.Globalization.CultureInfo('es-MX')
        return ("Tienes " + $rs.Count + ": " + (($rs | ForEach-Object { ([DateTime]$_.cuando).ToString('dddd d "a las" H:mm', $cul) + ", " + $_.texto }) -join '. '))
    }
    if ($p -match '^(?:borra|elimina|quita|olvida)\s+(?:todos\s+)?(?:los\s+)?recordatorios$') { Save-Recordatorios @(); return "Listo, sin recordatorios." }
    if ($p -notmatch '^(?:recuerdame|avisame|recordatorio|ponme un recordatorio|pon un recordatorio)\s+(?!que\b)(.+)$') { return $null }
    $resto = $Matches[1]
    $hoy = (Get-Date).Date
    $fecha = $null; $hora = -1; $min = 0
    # dia
    if ($resto -match '^(?:para\s+)?hoy\b\s*(.*)$') { $fecha = $hoy; $resto = $Matches[1] }
    elseif ($resto -match '^(?:para\s+)?pasado manana\b\s*(.*)$') { $fecha = $hoy.AddDays(2); $resto = $Matches[1] }
    elseif ($resto -match '^(?:para\s+)?manana\b\s*(.*)$') { $fecha = $hoy.AddDays(1); $resto = $Matches[1] }
    elseif ($resto -match '^(?:para\s+)?el\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b\s*(.*)$') {
        $d = $DIAS_SEMANA[$Matches[1]]; $resto = $Matches[2]
        $delta = ($d - [int]$hoy.DayOfWeek + 7) % 7
        if ($delta -eq 0) { $delta = 7 }   # "el viernes" dicho un viernes = el que viene
        $fecha = $hoy.AddDays($delta)
    }
    elseif ($resto -match '^(?:para\s+)?el\s+(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)\b\s*(.*)$') {
        $dd = [int]$Matches[1]; $mm = $MESES[$Matches[2]]; $resto = $Matches[3]
        try { $fecha = Get-Date -Year $hoy.Year -Month $mm -Day $dd -Hour 0 -Minute 0 -Second 0 } catch { return "Esa fecha no existe." }
        if ($fecha.Date -lt $hoy) { $fecha = $fecha.AddYears(1) }
    }
    # hora
    if ($resto -match '^(?:a\s+las?\s+)(\d{1,2}|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce)(?::(\d{2})|\s+y\s+media|\s+y\s+cuarto|\s+menos\s+cuarto)?\s*(de la manana|de la tarde|de la noche|am|pm)?\s*(.*)$') {
        # mismos cuidados que en las reglas: copiar ANTES de volver a usar
        # -match. Aqui el fallo era mudo: $resto quedaba vacio y contestaba
        # '¿Que te recuerdo?', asi que creias haber puesto el recordatorio y no
        # existia. Pasaba con 'y media', 'y cuarto' y 'menos cuarto'.
        $g0 = $Matches[0]; $g1 = $Matches[1]; $g2 = $Matches[2]; $g3 = $Matches[3]; $g4 = $Matches[4]
        $h = $g1; if ($HORAS_PALABRA.ContainsKey($h)) { $h = $HORAS_PALABRA[$h] }; $hora = [int]$h
        if ($g2) { $min = [int]$g2 } elseif ($g0 -match 'y media') { $min = 30 } elseif ($g0 -match 'y cuarto') { $min = 15 } elseif ($g0 -match 'menos cuarto') { $min = 45; $hora-- }
        $franja = $g3; $resto = $g4
        if ($franja -match 'tarde|noche|pm' -and $hora -lt 12) { $hora += 12 }
        if ($franja -match 'manana|am' -and $hora -eq 12) { $hora = 0 }
        # sin franja y hora "pequena": si ya paso de manana, sera de tarde
        if (-not $franja -and $hora -le 7 -and $hora -ge 1 -and $null -eq $fecha) { $hora += 12 }
    }
    if ($null -eq $fecha -and $hora -lt 0) { return $null }   # no es un recordatorio con fecha
    $texto = ($resto -replace '^(?:que|de que|de|para|a)\s+', '').Trim()
    if (-not $texto) { return "¿Que te recuerdo?" }
    if ($hora -lt 0) { $hora = 9 }   # solo dia: a las 9 de la manana
    if ($null -eq $fecha) {
        $fecha = $hoy
        if ($hoy.AddHours($hora).AddMinutes($min) -le (Get-Date)) { $fecha = $hoy.AddDays(1) }
    }
    $cuando = $fecha.Date.AddHours($hora).AddMinutes($min)
    if ($cuando -le (Get-Date)) { return "Esa hora ya paso." }
    $lista = @(Get-Recordatorios) + @(New-Object PSObject -Property @{ cuando = $cuando.ToString('s'); texto = $texto })
    Save-Recordatorios $lista
    $cul = New-Object System.Globalization.CultureInfo('es-MX')
    $dicho = if ($cuando.Date -eq $hoy) { "hoy a las " + $cuando.ToString('H:mm', $cul) } elseif ($cuando.Date -eq $hoy.AddDays(1)) { "manana a las " + $cuando.ToString('H:mm', $cul) } else { $cuando.ToString('dddd d "de" MMMM "a las" H:mm', $cul) }
    Log "RECORDATORIO ($cuando): $texto"
    Add-Estadistica 'local' "recordatorio: $text"
    return "Listo, te lo recuerdo $dicho."
}

function Test-Recordatorios {
    $lista = @(Get-Recordatorios)
    if ($lista.Count -eq 0) { return }
    $ahora = Get-Date
    $quedan = @()
    foreach ($r in $lista) {
        $c = $null
        try { $c = [DateTime]$r.cuando } catch { continue }
        if ($c -le $ahora) {
            Log "RECORDATORIO vence: $($r.texto)"
            Show-Popup ("Recordatorio: " + $r.texto)
            Say ("Te recuerdo: " + $r.texto)
            Send-UIEvento 'aviso'
            Start-Vibracion @(120, 80, 120)
        } else { $quedan += $r }
    }
    if ($quedan.Count -ne $lista.Count) { Save-Recordatorios $quedan }
}

# =====================================================================
# MICRO-CHARLA: un comentario espontaneo al dia, y solo si viene a cuento.
# =====================================================================
$CharlaOn = [bool](Get-Cfg 'charla' 'activada' $true)
$script:charlaAgua = ''
$script:charlaTarde = ''

# =====================================================================
# LOGROS DE STEAM: Steam reescribe appcache\stats\UserGameStats_<usuario>_<app>.bin
# cuando cambian los logros del juego que esta corriendo. Se vigila la fecha
# del archivo del juego activo: si cambia, medalla. (Tambien cambia con otras
# estadisticas: puede haber algun falso positivo; una medalla de mas no duele.)
# =====================================================================
$script:logroArchivo = ''
$script:logroStamp = [DateTime]::MinValue
$script:logroUltimo = 0

function Watch-LogrosSteam {
    if (-not $script:juegoActivo) { $script:logroArchivo = ''; return }
    try {
        if (-not $script:logroArchivo) {
            $j = @($script:Juegos | Where-Object { $_.nombre -eq $script:juegoActivo }) | Select-Object -First 1
            if (-not $j) { return }
            $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath -replace '/', '\'
            $f = Get-ChildItem -LiteralPath (Join-Path $sp 'appcache\stats') -Filter "UserGameStats_*_$($j.id).bin" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $f) { $script:logroArchivo = '-'; return }
            $script:logroArchivo = $f.FullName
            $script:logroStamp = $f.LastWriteTimeUtc
            return
        }
        if ($script:logroArchivo -eq '-') { return }
        $st = [System.IO.File]::GetLastWriteTimeUtc($script:logroArchivo)
        if ($st -ne $script:logroStamp) {
            $script:logroStamp = $st
            if (($sw.ElapsedMilliseconds - $script:logroUltimo) -ge 120000) {
                $script:logroUltimo = $sw.ElapsedMilliseconds
                Log "LOGRO (stats de Steam cambiaron) en $($script:juegoActivo)"
                Send-UIEvento 'logro'
            }
        }
    } catch {}
}

# =====================================================================
# ACELEROMETRO (WinRT): un golpe o sacudida de la consola sobresalta a la
# capsula. Si el sensor no existe, no se hace nada.
# =====================================================================
$script:acelerometro = $null
$script:acelCheck = 0
$script:acelUltimo = 0
# Apagado por defecto: en la ROG Ally GetDefault() devuelve un sensor pero
# GetCurrentReading() tarda 5 s y devuelve null SIEMPRE (probado con
# ReportInterval fijado). Con sensores.acelerometro = true se intenta, con la
# guarda de Watch-Acelerometro por si cambia el hardware.
if ([bool](Get-Cfg 'sensores' 'acelerometro' $false)) {
    try {
        $null = [Windows.Devices.Sensors.Accelerometer, Windows.Devices.Sensors, ContentType = WindowsRuntime]
        $script:acelerometro = [Windows.Devices.Sensors.Accelerometer]::GetDefault()
        if ($script:acelerometro) { Log "acelerometro: disponible (se probara la primera lectura)" } else { Log "acelerometro: no hay sensor" }
    } catch { $script:acelerometro = $null; Log "acelerometro: no disponible" }
}

$script:acelProbado = $false
function Watch-Acelerometro {
    if (-not $script:acelerometro) { return }
    try {
        # GUARDA: en la Ally el sensor "existe" pero GetCurrentReading tarda
        # 5 s y devuelve null. Llamado cada 250 ms bloqueaba el asistente
        # entero (se descubrio porque las ordenes tardaban 30 s en leerse).
        # Si la primera lectura es lenta o vacia, se apaga para siempre.
        if (-not $script:acelProbado) {
            $script:acelProbado = $true
            try { $script:acelerometro.ReportInterval = [Math]::Max(100, $script:acelerometro.MinimumReportInterval) } catch {}
            $t = [System.Diagnostics.Stopwatch]::StartNew()
            $r0 = $script:acelerometro.GetCurrentReading()
            if ($t.ElapsedMilliseconds -gt 150 -or -not $r0) {
                Log ("acelerometro: sin lecturas utiles (" + $t.ElapsedMilliseconds + " ms, nulo=" + ($null -eq $r0) + "); desactivado")
                $script:acelerometro = $null
                return
            }
            Log "acelerometro: lecturas OK"
        }
        $r = $script:acelerometro.GetCurrentReading()
        if (-not $r) { return }
        $mag = [Math]::Sqrt($r.AccelerationX * $r.AccelerationX + $r.AccelerationY * $r.AccelerationY + $r.AccelerationZ * $r.AccelerationZ)
        if ([Math]::Abs($mag - 1.0) -gt 0.7 -and ($sw.ElapsedMilliseconds - $script:acelUltimo) -ge 5000) {
            $script:acelUltimo = $sw.ElapsedMilliseconds
            Log ("SACUDIDA: {0:0.00} g" -f $mag)
            Send-UIEvento 'gesto:sobresalto'
        }
    } catch { $script:acelerometro = $null }
}

# =====================================================================
# NOTA SEMANAL: memoria\semanas\AAAA-Www.md, escrita en lenguaje hablado a
# partir de las estadisticas y del diario de gestos. Una por semana vencida.
# =====================================================================
function Write-NotaSemanal {
    try {
        $hoy = (Get-Date).Date
        # lunes de ESTA semana; la semana a resumir es la anterior
        $lunes = $hoy.AddDays(-(([int]$hoy.DayOfWeek + 6) % 7))
        $ini = $lunes.AddDays(-7); $fin = $lunes.AddDays(-1)
        $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
        $semana = $cal.GetWeekOfYear($ini, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
        $dir = Join-Path $MemoriaDir 'semanas'
        $ruta = Join-Path $dir ('{0}-W{1:00}.md' -f $ini.Year, $semana)
        if (Test-Path -LiteralPath $ruta) { return }
        $s = Get-Estadisticas
        $tot = @{}; $dias = 0
        for ($d = $ini; $d -le $fin; $d = $d.AddDays(1)) {
            $k = $d.ToString('yyyy-MM-dd')
            if (-not $s.dias.ContainsKey($k)) { continue }
            $dias++
            foreach ($r in $s.dias[$k].Keys) { if (-not $tot.ContainsKey($r)) { $tot[$r] = 0 }; $tot[$r] += $s.dias[$k][$r] }
        }
        if ($dias -eq 0) { return }   # semana sin uso: no hay nada que contar
        $gestos = @{}
        $gl = Join-Path $TmpDir 'gestos.log'
        if (Test-Path -LiteralPath $gl) {
            foreach ($l in [System.IO.File]::ReadAllLines($gl, [System.Text.Encoding]::UTF8)) {
                if ($l -match '^(\d{4}-\d{2}-\d{2}) \S+ (\S+)$') {
                    $dd = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
                    if ($dd -lt $ini -or $dd -gt $fin) { continue }
                    if ($Matches[2] -in @('escucho', 'lotengo', 'atencion')) { continue }
                    if (-not $gestos.ContainsKey($Matches[2])) { $gestos[$Matches[2]] = 0 }
                    $gestos[$Matches[2]]++
                }
            }
        }
        $cul = New-Object System.Globalization.CultureInfo('es-MX')
        $n = 0; foreach ($k in 'local', 'aprendida', 'memoria', 'pregunta', 'traducida', 'accion', 'charla') { if ($tot.ContainsKey($k)) { $n += $tot[$k] } }
        $rapidas = 0; foreach ($k in 'local', 'aprendida', 'memoria') { if ($rapidas -ne $null -and $tot.ContainsKey($k)) { $rapidas += $tot[$k] } }
        $errores = if ($tot.ContainsKey('error')) { $tot['error'] } else { 0 }
        $desc = @($s.descartes | Where-Object { $_ -match '^(\d{4}-\d{2}-\d{2})' -and ([DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null) -ge $ini) -and ([DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null) -le $fin) } | ForEach-Object { $_ -replace '^\S+\s+', '' } | Select-Object -First 5)
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# Semana del " + $ini.ToString('d "de" MMMM', $cul) + " al " + $fin.ToString('d "de" MMMM "de" yyyy', $cul))
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Esta semana hablamos $dias " + $(if ($dias -eq 1) { 'día' } else { 'días' }) + ". Me pediste $n " + $(if ($n -eq 1) { 'cosa' } else { 'cosas' }) + $(if ($n -gt 0) { ", y $rapidas de ellas las resolví al instante sin pasar por el modelo" } else { '' }) + ".")
        if ($errores -gt 0) { [void]$sb.AppendLine("Hubo $errores " + $(if ($errores -eq 1) { 'tropiezo' } else { 'tropiezos' }) + " (cancelaciones, dictados vacíos o esperas que se pasaron de tiempo).") }
        if ($desc.Count -gt 0) { [void]$sb.AppendLine(""); [void]$sb.AppendLine("Cosas que no entendí a la primera y que podrías enseñarme en commands.json: " + (($desc | ForEach-Object { "«$_»" }) -join ', ') + ".") }
        if ($gestos.Count -gt 0) {
            $top = @($gestos.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 4 | ForEach-Object { "$($_.Key) ×$($_.Value)" })
            [void]$sb.AppendLine(""); [void]$sb.AppendLine("Lo que más me dijiste, según mis gestos: " + ($top -join ', ') + ".")
            if ($gestos.ContainsKey('carino') -and $gestos['carino'] -ge 3) { [void]$sb.AppendLine("Gracias por los cariños, se notaron.") }
            if ($gestos.ContainsKey('negar') -and $gestos['negar'] -gt ($n / 3)) { [void]$sb.AppendLine("Hubo bastantes «no»: si algo hago mal a menudo, apúntamelo en la lista de descartes y lo aprendo.") }
        }
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        [System.IO.File]::WriteAllText($ruta, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
        Log "nota semanal escrita: $ruta"
    } catch { Log ("nota semanal: " + $_.Exception.Message) }
}

function Enter-Juego([string]$nombre) {
    $script:juegoAvisado = $false
    $script:juegoHoras = 0
    $script:juegoBrilloAntes = $null
    $script:logroArchivo = ''
    Invoke-Reglas 'juegoAbre' $nombre
    if (-not $JuegoPerfilEntrar) { return }
    if (-not (Test-Prop $cmds.perfiles $JuegoPerfilEntrar)) { return }
    try { $script:juegoBrilloAntes = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop).CurrentBrightness } catch {}
    # NO se abren apps del perfil al entrar solo en un juego (abrir Discord
    # encima de un juego recien lanzado seria un estorbo): solo niveles
    $ordenes = @($cmds.perfiles.$JuegoPerfilEntrar) | Where-Object { (ConvertTo-Plain $_) -notmatch '^(?:abre|abrir|lanza|ejecuta)\b' }
    $hechas = @()
    foreach ($o in $ordenes) {
        $r = $null
        try { $r = Invoke-FastCommand $o } catch { $r = $null }
        if ($r) { $hechas += $r }
    }
    if ($hechas.Count -gt 0) {
        Log "JUEGO: perfil '$JuegoPerfilEntrar' aplicado al entrar en $nombre"
        Say "Modo $JuegoPerfilEntrar."
        Send-UIEvento 'hecho'
    }
}

function Exit-Juego([string]$nombre) {
    Invoke-Reglas 'juegoCierra' $nombre
    if (-not $JuegoRestaurar -or $null -eq $script:juegoBrilloAntes) { return }
    try {
        Set-Brillo ([int]$script:juegoBrilloAntes)
        Log "JUEGO: brillo restaurado a $($script:juegoBrilloAntes) al salir de $nombre"
    } catch {}
    $script:juegoBrilloAntes = $null
}

# =====================================================================
# VER LA PANTALLA: captura de la ventana activa (o de toda la pantalla) y
# OCR con el motor integrado de Windows (WinRT, sin instalar nada).
# =====================================================================
$script:winrtAsTask = $null
function Await-WinRT($op, $tipo) {
    if (-not $script:winrtAsTask) {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $script:winrtAsTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                           $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    }
    $t = $script:winrtAsTask.MakeGenericMethod($tipo).Invoke($null, @($op))
    if (-not $t.Wait(8000)) { throw "WinRT: sin respuesta en 8 s" }
    return $t.Result
}

# Guarda un PNG de la ventana en primer plano (o de toda la pantalla si no
# hay ventana util). Esconde la capsula un instante para que no salga.
function Save-Captura([string]$ruta) {
    if ($UiNuevaOn) { Send-UIEvento 'oculta'; Start-Sleep -Milliseconds 180 }
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $x = $b.Left; $y = $b.Top; $w = $b.Width; $h = $b.Height
    try {
        $hw = [AX]::GetForegroundWindow()
        if ($hw -ne [IntPtr]::Zero -and $hw -ne $capture.Handle) {
            $r = New-Object AX+RECT
            if ([AX]::GetWindowRect($hw, [ref]$r) -and ($r.Right - $r.Left) -gt 80 -and ($r.Bottom - $r.Top) -gt 60) {
                $x = [Math]::Max($b.Left, $r.Left); $y = [Math]::Max($b.Top, $r.Top)
                $w = [Math]::Min($b.Right, $r.Right) - $x; $h = [Math]::Min($b.Bottom, $r.Bottom) - $y
            }
        }
    } catch {}
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
        $bmp.Save($ruta, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose(); $bmp.Dispose() }
    return $ruta
}

function Invoke-OCR([string]$png) {
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
    $null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    $null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType = WindowsRuntime]
    $motor = $null
    try { $motor = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage((New-Object Windows.Globalization.Language 'es')) } catch { $motor = $null }
    if (-not $motor) { $motor = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
    if (-not $motor) { throw "no hay motor de OCR (instala el idioma en Windows)" }
    $archivo = Await-WinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync($png)) ([Windows.Storage.StorageFile])
    $flujo = Await-WinRT ($archivo.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $dec = Await-WinRT ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($flujo)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bmp = Await-WinRT ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $res = Await-WinRT ($motor.RecognizeAsync($bmp)) ([Windows.Media.Ocr.OcrResult])
    try { $flujo.Dispose() } catch {}
    # una linea por renglon, para que se lea con pausas naturales
    $lineas = @($res.Lines | ForEach-Object { $_.Text })
    return (($lineas -join '. ') -replace '\s+', ' ').Trim()
}

# =====================================================================
# VIBRACION DEL MANDO: patron de [on, off, on, ...] en ms, sin bloquear; el
# bucle principal lo va ejecutando. Un eco tactil de lo que hace la capsula.
# =====================================================================
$MandoVibracion = [bool](Get-Cfg 'mando' 'vibracion' $true)
$script:vibraCola = @()
$script:vibraHasta = 0
$script:vibraEncendida = $false
$script:vibraFuerza = 0

$script:vibraSiguienteOn = $true
$script:vibraAvisado = $false

function Start-Vibracion([int[]]$patron, [int]$fuerza = 22000) {
    if (-not $MandoVibracion -or -not $patron -or $patron.Count -eq 0) { return }
    # el patron alterna encendido/apagado empezando por encendido
    $script:vibraCola = @($patron)
    $script:vibraFuerza = $fuerza
    $script:vibraHasta = 0
    $script:vibraSiguienteOn = $true
}

function Tick-Vibracion {
    if ($script:vibraHasta -gt 0) {
        if ($sw.ElapsedMilliseconds -lt $script:vibraHasta) { return }
        $script:vibraHasta = 0
        if ($script:vibraEncendida) { try { [void][AX]::Vibrar(0, 0, 0) } catch {}; $script:vibraEncendida = $false }
    }
    if ($script:vibraCola.Count -eq 0) { return }
    $ms = [int]$script:vibraCola[0]
    $script:vibraCola = @($script:vibraCola | Select-Object -Skip 1)
    if ($script:vibraSiguienteOn) {
        $ok = $false
        try { $ok = [AX]::Vibrar(0, [uint16]$script:vibraFuerza, [uint16]($script:vibraFuerza / 2)) } catch { $ok = $false }
        if (-not $script:vibraAvisado) { $script:vibraAvisado = $true; Log ("mando: vibracion " + $(if ($ok) { 'disponible' } else { 'no disponible (sin mando XInput)' })) }
        if (-not $ok) { $script:vibraCola = @(); return }   # sin mando: fuera
        $script:vibraEncendida = $true
    }
    $script:vibraSiguienteOn = -not $script:vibraSiguienteOn
    $script:vibraHasta = $sw.ElapsedMilliseconds + $ms
}

# Win + <tecla>: usado para colocar ventanas (Win+flechas)
function Send-WinKey([int]$vk) {
    [AX]::keybd_event([byte]$VK_LWIN, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$VK_LWIN, 0, $KEYUP, [UIntPtr]::Zero)
}

if ($Probar) {
    if (-not (Test-Path -LiteralPath $Probar)) { Write-Output "no existe: $Probar"; exit 1 }
    # Reconocer una orden NO es gratis: "recuerdame manana a las diez que llame
    # al medico" crea el recordatorio de verdad nada mas detectarlo, y "cuando
    # abras elden ring..." guarda la regla. La primera version de este banco
    # llego a escribir ambas cosas en la memoria real. Aqui se desvia a una
    # carpeta de usar y tirar todo lo que persiste: probar no toca nada tuyo.
    $pruebaDir = Join-Path ([System.IO.Path]::GetTempPath()) ("nova-prueba-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $pruebaDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pruebaDir 'diario') -Force | Out-Null
    $MemoriaDir = $pruebaDir
    $DiarioDir = Join-Path $pruebaDir 'diario'
    $ReglasPath = Join-Path $pruebaDir 'reglas.json'
    $RecordatoriosPath = Join-Path $pruebaDir 'recordatorios.json'
    $FechasPath = Join-Path $pruebaDir 'fechas.json'
    $TraduccionesPath = Join-Path $pruebaDir 'traducciones.json'
    $EstadisticasJson = Join-Path $pruebaDir 'estadisticas.json'
    $EstadisticasMd = Join-Path $pruebaDir 'estadisticas.md'
    $ok = 0; $no = 0
    foreach ($linea in (Get-Content -LiteralPath $Probar -Encoding UTF8)) {
        $t = $linea.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        # mismo orden que Process-Texto: reglas y recordatorios se resuelven
        # antes que las ordenes sueltas, o el banco mentiria
        $r = $false; $via = ''
        try { if (Invoke-ReglaVoz $t) { $r = $true; $via = 'regla' } } catch { $via = 'REGLA ROTA' ; $r = $false }
        if (-not $r) { try { if (Invoke-RecordatorioVoz $t) { $r = $true; $via = 'recordatorio' } } catch { $via = 'RECORDATORIO ROTO' } }
        if (-not $r) { try { $r = Test-FastCommand $t } catch { $r = $false } }
        if ($r) {
            $ok++
            # QUE haria, no solo si lo reconoce. Sin esto, el banco decia 'OK'
            # a 'pesa' sin contar que eso era un Ctrl+V en lo que tuvieras
            # delante, ni a 'abre el speaker' que lanzaba PEAK.
            $comoQue = ''
            # si lo cogio una regla o un recordatorio, decirlo: la descripcion
            # de Resolve-Fragment seria otra cosa y despistaria
            if ($via) { $comoQue = "  ->  [$via]" }
            elseif ($true) { try {
                $descs = @()
                foreach ($fr in @(Split-Compound (Repair-Words (ConvertTo-Plain $t)))) {
                    $acc = Resolve-Fragment $fr
                    if ($acc) { $descs += @($acc | ForEach-Object { $_.desc }) }
                }
                $descs = @($descs | Where-Object { $_ })
                if ($descs.Count -gt 0) { $comoQue = '  ->  ' + ($descs -join ' + ') }
            } catch {} }
            Write-Output ("  OK    " + $t.PadRight(38) + $comoQue)
        }
        else    { $no++; Write-Output ("  ->IA  " + $t) }
    }
    Write-Output ""
    Write-Output ("reconocidas en local: $ok de " + ($ok + $no))
    try { Remove-Item -LiteralPath $pruebaDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    exit 0
}

$mutex = New-Object System.Threading.Mutex($false, "Local\VoiceAssistant")
if (-not $mutex.WaitOne(0)) {
    Write-Output "VoiceAssistant ya esta ejecutandose."
    exit 0
}

try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
} catch {
    # sin WinForms no hay captura ni popup: abortar aqui con un mensaje claro,
    # en vez de reventar 20 lineas mas abajo con un error incomprensible
    Log ("ERROR cargando WinForms: " + $_.Exception.Message)
    exit 1
}

$dll = Join-Path $LogDir "assistant-dx.dll"
if (-not (Test-Path $dll)) {
    Log "ERROR: falta $dll"
    exit 1
}
# Integridad del DLL: se carga con Add-Type desde una carpeta que cualquier
# proceso de tu cuenta puede escribir. La primera vez se anota el hash en
# config.json (confianza inicial); despues se compara. AVISA pero NO aborta:
# lo mas probable ante un cambio es que lo hayas recompilado tu, y dejarte sin
# asistente por eso seria peor. Si recompilas, borra seguridad.hashDll.
try {
    $hashAhora = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    $hashEsperado = [string](Get-Cfg 'seguridad' 'hashDll' '')
    if (-not $hashEsperado) {
        Log "hash del DLL registrado por primera vez: $hashAhora"
        Log "  (para fijarlo, copia ese valor en config.json -> seguridad.hashDll)"
    } elseif ($hashEsperado -ne $hashAhora) {
        Log "ALERTA: assistant-dx.dll NO coincide con el hash esperado."
        Log "  esperado: $hashEsperado"
        Log "  actual  : $hashAhora"
        Log "  Si lo recompilaste, actualiza config.json. Si no, revisa el archivo."
    }
} catch {}

try {
    Add-Type -Path $dll
} catch {
    Log ("ERROR cargando DLL: " + $_.Exception.Message)
    exit 1
}

try {
    $env:PATH = $NODEDIR + ";" + $env:PATH
} catch {}

if (-not (Test-Path -LiteralPath $TmpDir)) {
    try { New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null } catch {}
}

Log "VoiceAssistant iniciado PID=$PID (trigger: mantener ≡ $([Math]::Round($HOLD_MS/1000,1)) s; destino: opencode CLI headless)."
if ($cfgError) { Log "WARN: config.json ilegible, se usan los valores por defecto: $cfgError" }
elseif ($cfg) { Log "config.json cargado" }
if ($cmdsError) { Log "WARN: commands.json ilegible, todo ira a opencode: $cmdsError" }
elseif ($cmds) {
    Log ("commands.json cargado: " + @($cmds.apps.PSObject.Properties).Count + " apps, " +
         @($cmds.sitios.PSObject.Properties).Count + " sitios, " +
         @($cmds.busquedas.PSObject.Properties).Count + " buscadores")
} else { Log "WARN: no hay commands.json; todo ira a opencode" }

Initialize-Voz
Initialize-Escucha
# gestos propios (config.json -> ui.gestos): la capsula los lee de tmp\gestos.txt
try {
    $lineas = @()
    foreach ($g in @(Get-Cfg 'ui' 'gestos' @())) {
        if ($g.gesto -and $g.patron) { $lineas += ([string]$g.gesto + '|' + [string]$g.patron) }
    }
    [System.IO.File]::WriteAllLines((Join-Path $TmpDir 'gestos.txt'), [string[]]$lineas, (New-Object System.Text.UTF8Encoding($false)))
} catch {}
Initialize-UI

$script:Juegos = Get-JuegosSteam
$script:JuegosStamp = Get-Date
# Vocabulario para Whisper: nombres propios que el dictado suele destrozar.
# Se le pasan como "prompt" y los transcribe bien ("Steam", no "stim").
try {
    $voc = @($EscuchaNombre)
    if ($cmds) {
        $voc += @($cmds.apps.PSObject.Properties.Name | Where-Object { $_ -notmatch '\s' -or $_.Length -le 16 } | Select-Object -First 20)
        $voc += @($cmds.sitios.PSObject.Properties.Name | Select-Object -First 14)
    }
    $voc += @($script:Juegos | ForEach-Object { $_.nombre } | Select-Object -First 20)
    $voc = @($voc | Where-Object { $_ } | Select-Object -Unique)
    [System.IO.File]::WriteAllText($RutaVocabulario, (($voc -join ', ') + '.'), (New-Object System.Text.UTF8Encoding($false)))
} catch {}
if (@($script:Juegos).Count -gt 0) {
    Log ("biblioteca de Steam: " + @($script:Juegos).Count + " juegos indexados")
} else {
    Log "WARN: no se pudo leer la biblioteca de Steam; los juegos iran a opencode"
}
if (-not (Test-Path $OCODECLI)) {
    Log "ERROR: opencode CLI no encontrado en $OCODECLI"
    exit 1
}

$scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$capture = New-Object System.Windows.Forms.Form
$capture.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$capture.ShowInTaskbar = $false
$capture.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$capture.Size = New-Object System.Drawing.Size(320, 44)
$capture.Location = New-Object System.Drawing.Point(($scr.Left + 12), ($scr.Bottom - 56))
$capture.TopMost = $true
$capture.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 38)
$capture.Text = "voice-capture"
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "● VOZ..."
$lbl.ForeColor = [System.Drawing.Color]::LimeGreen
$lbl.BackColor = $capture.BackColor
$lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lbl.AutoSize = $true
$lbl.Location = New-Object System.Drawing.Point(8, 6)
$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.AcceptsReturn = $true
$tb.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$tb.Width = 1
$tb.Height = 1
$tb.Location = New-Object System.Drawing.Point(0, 0)
$capture.Controls.Add($lbl)
$capture.Controls.Add($tb)
# Con la interfaz nueva, esta barra se vuelve invisible pero SIGUE EXISTIENDO:
# el dictado de Windows necesita una ventana con foco donde escribir. Con
# opacidad 0 Windows deja de pintarla; 0,01 la mantiene viva y con foco.
if ($UiNuevaOn) { $capture.Opacity = 0.01 }

function Show-Capture {
    $tb.Text = ""
    $capture.Show()
    $capture.Activate()
    $capture.BringToFront()
    # El "tap" de Alt sortea el foreground lock de Windows. Si aun asi falla
    # (overlay de Armoury Crate, notificacion, Focus Assist), el dictado escribe
    # en OTRA ventana y el texto llega vacio: ese era el bug "vacio, ignorado".
    # Antes el retorno se descartaba con | Out-Null y el fallo era invisible.
    $ok = $false
    for ($try = 1; $try -le 3 -and -not $ok; $try++) {
        [AX]::keybd_event([byte]$VK_MENU, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 20
        [AX]::keybd_event([byte]$VK_MENU, 0, $KEYUP, [UIntPtr]::Zero)
        # ForceForeground usa AttachThreadInput: SetForegroundWindow a secas
        # fallaba 3/3 contra el foreground lock (log 11:10:06)
        $ok = [bool]([AX]::ForceForeground($capture.Handle))
        if (-not $ok) {
            Log "WARN: no se pudo tomar el primer plano (intento $try/3)"
            Start-Sleep -Milliseconds 150
        }
    }
    Start-Sleep -Milliseconds 250
    [void]$tb.Focus()
    Start-Sleep -Milliseconds 250
    return $ok
}

# El reconocimiento puede seguir insertando texto despues del Esc. Esperar a que
# el contenido se estabilice en vez de confiar en un Start-Sleep fijo de 600 ms,
# que bajo carga cortaba la ultima palabra dictada.
function Wait-DictationText {
    $prev = $null
    $stable = 0
    $w = [System.Diagnostics.Stopwatch]::StartNew()
    while ($w.ElapsedMilliseconds -lt 2000) {
        [System.Windows.Forms.Application]::DoEvents()
        $cur = $tb.Text
        if ($cur -eq $prev) {
            $stable++
            # 3 lecturas iguales (~240 ms) con texto => dejo de escribir
            if ($stable -ge 3 -and $cur.Trim().Length -gt 0) { break }
        } else {
            $stable = 0
            $prev = $cur
        }
        Start-Sleep -Milliseconds 80
    }
    return $tb.Text.Trim()
}

# --- estado del popup (no bloqueante) ---
$script:popupForm = $null
$script:popupFont = $null
$script:popupUntil = 0

# Cierra y LIBERA el popup. Sin este Dispose, cada respuesta filtraba un Font
# y un Form; en un proceso que vive meses desde el login agota los handles GDI.
function Close-Popup {
    if ($script:popupForm) {
        try { $script:popupForm.Close(); $script:popupForm.Dispose() } catch {}
        $script:popupForm = $null
    }
    if ($script:popupFont) {
        try { $script:popupFont.Dispose() } catch {}
        $script:popupFont = $null
    }
    $script:popupUntil = 0
}

function Show-Popup([string]$text, [string]$estadoUI = 'hablando') {
    Close-Popup
    # Con la interfaz nueva el mensaje va a la capsula. El popup antiguo solo
    # se abre ademas para textos largos, que en 340 px no se podrian leer.
    if ($UiNuevaOn) {
        Set-UI $estadoUI $text $PopupMs
        if ($text.Length -le 80) { return }
    }
    try {
        $f = New-Object System.Windows.Forms.Form
        $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $f.ShowInTaskbar = $false
        $f.TopMost = $true
        $f.BackColor = [System.Drawing.Color]::FromArgb(28, 32, 42)
        $f.ForeColor = [System.Drawing.Color]::White
        $f.Padding = New-Object System.Windows.Forms.Padding(14)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.AutoSize = $false
        $l.MaximumSize = New-Object System.Drawing.Size(600, 0)
        $l.ForeColor = $f.ForeColor
        $l.BackColor = $f.BackColor
        $script:popupFont = New-Object System.Drawing.Font("Segoe UI", 10.5)
        $l.Font = $script:popupFont
        $l.Dock = [System.Windows.Forms.DockStyle]::Fill
        $f.Controls.Add($l)
        $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $f.AutoSize = $true
        $f.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $s2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $f.Location = New-Object System.Drawing.Point(($s2.Right - $f.Width - 24), ($s2.Bottom - $f.Height - 48))
        $f.Show()
        [System.Media.SystemSounds]::Asterisk.Play()
        # NO se espera aqui: antes este bucle bloqueaba 8 s el sondeo del boton.
        # El bucle principal lo cierra al vencer $popupUntil.
        $script:popupForm = $f
        $script:popupUntil = $sw.ElapsedMilliseconds + $PopupMs
    } catch {
        Log "popup error: $($_.Exception.Message)"
        Close-Popup
    }
}

# --- trabajo de opencode en segundo plano (no bloqueante) ---
$script:busy = $false
$script:proc = $null
$script:jobOut = $null
$script:jobErr = $null
$script:jobIn = $null
$script:jobStart = 0

# Libera el trabajo actual y devuelve la UI a reposo.
function Clear-OpencodeJob {
    foreach ($f in @($script:jobOut, $script:jobErr, $script:jobIn)) {
        if ($f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
    $script:jobOut = $null; $script:jobErr = $null; $script:jobIn = $null
    try { if ($script:proc) { $script:proc.Dispose() } } catch {}
    $script:proc = $null
    $script:busy = $false
    $lbl.Text = "● VOZ..."
    $lbl.ForeColor = [System.Drawing.Color]::LimeGreen
    $capture.Hide()
}

# Mata el trabajo en curso sin reportar respuesta (cancelacion del usuario).
function Stop-OpencodeJob {
    if (-not $script:busy) { return }
    # /T mata tambien los hijos: Kill() solo se lleva el padre y deja
    # opencode.exe huerfano consumiendo CPU (ver TRASPASO.md seccion 9)
    try { & taskkill.exe /PID $script:proc.Id /T /F 2>$null | Out-Null } catch {}
    try { if (-not $script:proc.HasExited) { $script:proc.Kill() } } catch {}
    # Espera CORTA: esto corre dentro del bucle principal y se invoca justo
    # cuando el usuario esta cancelando. Esperar 5 s dejaba el boton sin
    # responder en el peor momento posible. El hijo terminara de morir solo.
    try { $script:proc.WaitForExit(300) | Out-Null } catch {}
    Clear-OpencodeJob
}

# Lanza opencode.exe DIRECTAMENTE (sin powershell.exe oculto intermedio: ese salto
# es el spawn "flaky" de TRASPASO.md seccion 9) y RETORNA DE INMEDIATO.
# Antes se esperaba aqui hasta 240 s, y durante todo ese rato el bucle principal
# no sondeaba XInput: cualquier pulsacion de ≡ se perdia en silencio.
function Start-OpencodeJob([string]$text, [string]$extra = '') {
    $id = [System.Guid]::NewGuid().ToString("N")
    $script:jobOut = Join-Path $TmpDir "out-$id.txt"
    $script:jobErr = Join-Path $TmpDir "err-$id.txt"
    $script:jobIn = Join-Path $TmpDir "in-$id.txt"

    # el dictado puede traer saltos de linea; en argv se colapsan a espacios
    $msg = ($text -replace '\s+', ' ').Trim()
    if ($msg.Length -eq 0) { Clear-OpencodeJob; return $false }

    try {
        # stdin vacio => EOF inmediato; sin consola interactiva el CLI no se queda esperando
        [System.IO.File]::WriteAllText($script:jobIn, "")

        # El `--` es OBLIGATORIO por seguridad: sin el, un texto dictado que
        # empiece por guion ("menos i" -> -i) lo parsea yargs como flag.
        # Verificado: con `--` responde bien; sin `--` sale exit=1 en 2s.
        $extraArg = if ($extra) { " $extra" } else { "" }
        # --format json: una linea por evento (tool_use con la herramienta,
        # text con la respuesta). Asi la capsula puede contar QUE esta haciendo
        # mientras trabaja, y la respuesta se saca limpia de los eventos text.
        $argLine = "run --auto --format json" + $extraArg + " --dir " + (ConvertTo-CmdArg $WORKDIR) + " -- " + (ConvertTo-CmdArg $msg)
        $script:jobLeido = 0
        $script:jobPasos = 0
        $script:jobUltimaHerr = ''
        $script:jobProgresoCheck = 0
        Log "RUNNER cmd: $argLine"

        $script:proc = Start-Process -FilePath $OCODECLI -ArgumentList $argLine `
            -WorkingDirectory $WORKDIR -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $script:jobOut -RedirectStandardError $script:jobErr `
            -RedirectStandardInput $script:jobIn
        # tocar .Handle cachea el handle del proceso; sin esto .ExitCode
        # devuelve $null tras salir (quirk de Start-Process -PassThru)
        $null = $script:proc.Handle
    } catch {
        Log ("lanzamiento fallido: " + $_.Exception.Message)
        Clear-OpencodeJob
        return $false
    }

    $script:jobStart = $sw.ElapsedMilliseconds
    $script:busy = $true
    return $true
}

# VOZ INTERNA: mientras opencode trabaja, se lee lo que lleva escrito en su
# salida (eventos JSON) y la capsula cuenta que esta haciendo. Tambien se
# manda un progreso estimado para la linea del borde inferior.
$HERRAMIENTAS_ES = @{
    'bash' = 'ejecutando un comando'; 'read' = 'leyendo un archivo'; 'write' = 'escribiendo un archivo'; 'edit' = 'editando un archivo';
    'glob' = 'buscando archivos'; 'grep' = 'buscando en archivos'; 'list' = 'mirando carpetas'; 'webfetch' = 'consultando la web';
    'websearch' = 'buscando en internet'; 'todowrite' = 'planificando'; 'todoread' = 'planificando'; 'task' = 'delegando una tarea'
}
$DURACION_ESPERADA = @{ 'pregunta' = 18000; 'traducir' = 15000; 'charla' = 20000; 'accion' = 60000 }

function Watch-OpencodeProgress {
    if (-not $script:busy -or -not $script:jobOut) { return }
    if (($sw.ElapsedMilliseconds - $script:jobProgresoCheck) -lt 600) { return }
    $script:jobProgresoCheck = $sw.ElapsedMilliseconds
    $herr = ''
    try {
        $fs = [System.IO.File]::Open($script:jobOut, 'Open', 'Read', 'ReadWrite')
        try {
            if ($fs.Length -gt $script:jobLeido) {
                $fs.Seek($script:jobLeido, 'Begin') | Out-Null
                $buf = New-Object byte[] ($fs.Length - $script:jobLeido)
                $n = $fs.Read($buf, 0, $buf.Length)
                $script:jobLeido += $n
                $trozo = [System.Text.Encoding]::UTF8.GetString($buf, 0, $n)
                foreach ($m in [regex]::Matches($trozo, '"type":"tool_use".{0,200}?"tool":"([^"]+)"')) {
                    $script:jobPasos++
                    $herr = $m.Groups[1].Value
                }
            }
        } finally { $fs.Dispose() }
    } catch {}
    if ($herr) {
        $clave = $herr.ToLowerInvariant()
        $frase = $null
        if ($HERRAMIENTAS_ES.ContainsKey($clave)) { $frase = $HERRAMIENTAS_ES[$clave] }
        elseif ($clave -match '^(?:mcp_)?windows') { $frase = 'controlando el escritorio' }
        elseif ($clave -match 'mcp|__') { $frase = 'usando una herramienta' }
        else { $frase = "usando $herr" }
        if ($frase -ne $script:jobUltimaHerr) {
            $script:jobUltimaHerr = $frase
            Log "PASO $($script:jobPasos): $herr"
            Set-UI 'pensando' $frase
        }
    }
    # progreso estimado: tiempo transcurrido sobre lo esperado por modo
    $esp = if ($DURACION_ESPERADA.ContainsKey($script:jobModo)) { $DURACION_ESPERADA[$script:jobModo] } else { 60000 }
    $p = [Math]::Min(0.97, ($sw.ElapsedMilliseconds - $script:jobStart) / [double]$esp)
    if ([Math]::Abs($p - $script:uiProgreso) -ge 0.02) { $script:uiProgreso = [Math]::Round($p, 2); Refresh-UI }
}

# Recoge la salida del proceso YA terminado y devuelve el texto de respuesta.
function Complete-OpencodeJob {
    $code = -1
    $stdout = ""
    $stderr = ""
    try {
        # solo se llega aqui con el proceso YA terminado, asi que retorna al
        # instante; el tope es una red de seguridad, no una espera real
        try { $script:proc.WaitForExit(1000) | Out-Null } catch {}
        try { $code = $script:proc.ExitCode } catch {}
        if (Test-Path -LiteralPath $script:jobOut) {
            $stdout = [System.IO.File]::ReadAllText($script:jobOut, [System.Text.Encoding]::UTF8)
        }
        if (Test-Path -LiteralPath $script:jobErr) {
            $stderr = [System.IO.File]::ReadAllText($script:jobErr, [System.Text.Encoding]::UTF8)
        }
    } catch {
        $stderr = $stderr + "`r`nerror al recoger salida: " + $_.Exception.Message
    } finally {
        Clear-OpencodeJob
    }

    Log ("RUNNER exit=$code stdout=" + $stdout.Length + "B stderr=" + $stderr.Length + "B")

    # salida en JSON por lineas: la respuesta son los eventos "text"
    if ($stdout -match '"type":"text"') {
        $textos = @()
        foreach ($linea in ($stdout -split "`r?`n")) {
            if ($linea -notmatch '^\s*\{.*"type":"text"') { continue }
            try {
                $ev = $linea | ConvertFrom-Json
                if ($ev.part -and $ev.part.text) { $textos += [string]$ev.part.text }
            } catch {}
        }
        if ($textos.Count -gt 0) { return @(($textos -join "`n")) }
    }
    if ($stdout.Trim().Length -gt 0) { return @($stdout) }
    # el CLI manda parte de su salida a stderr; si stdout vino vacio, es el mejor dato que hay
    if ($stderr.Trim().Length -gt 0) { return @("(exit=$code) " + $stderr.Trim()) }
    return @("(sin salida de opencode; exit=$code)")
}

# Si la frase pregunta por algo recordado, se le dice a opencode donde mirar y
# que responda para ser ESCUCHADA (breve, sin listas ni codigo).
$RE_MEMORIA = '\b(?:que sabes (?:de|del|sobre|acerca)|que te dije|que dije|que te conte|recuerdas|te acuerdas|en tus notas|en mis notas|que anote|que apunte|mi memoria|mis notas|que guardaste|que tengo anotado)\b'

function Expand-Prompt([string]$texto) {
    if ((ConvertTo-Plain $texto) -match $RE_MEMORIA) {
        Log "consulta a la memoria"
        return ("Consulta mis notas en la carpeta " + $MemoriaDir + " (Markdown, en diario\ y temas\). " +
                "Responde BREVE y en lenguaje hablado, sin listas ni codigo: tu respuesta se lee en voz alta. " +
                "Si no encuentras nada, dilo en una frase y no inventes. Pregunta: " + $texto)
    }
    return $texto
}

# Prefijo para que el modelo CONTESTE en vez de actuar. Sin esto, el agente
# intenta usar herramientas para todo y tarda 25-160 s en vez de ~13 s.
# La ruta PREGUNTA no tenia filtro de ruido: cualquier frase de un video que
# empezara por 'que' o 'como' entraba aqui y el modelo contestaba lo que fuera
# (pasó el 11/09 a las 20:11 con 'como decia algo para dar vamos tumbado').
# Misma solucion que en TRADUCIR: el modelo dice si esto iba con el o no, en la
# misma llamada y sin latencia extra.
$PRE_HABLADO = 'Responde SOLO con palabras, breve (una o dos frases), en espanol, sin usar herramientas y sin ejecutar nada. Si el texto no es una pregunta ni algo dicho a un asistente -es ruido, una frase suelta, el audio de un video o una conversacion ajena- responde exactamente: NO. '

# Preguntas: se contestan hablando, no se ejecutan.
$RE_PREGUNTA = '^(?:que|cual|cuanto|cuantos|cuando|donde|quien|como|por que|para que|sabes|dime|cuentame|explicame|explica|crees|opinas|hablame|es cierto|de verdad)\b'

# Construye la peticion de traduccion. Se le da el vocabulario REAL para que no
# invente, y se le exige responder solo con la orden, sin explicaciones.
function Build-PromptTraduccion([string]$text) {
    $apps = (@($cmds.apps.PSObject.Properties.Name) | Select-Object -First 24) -join ', '
    $sitios = (@($cmds.sitios.PSObject.Properties.Name) | Select-Object -First 14) -join ', '
    $juegos = (@($script:Juegos | ForEach-Object { $_.nombre }) | Select-Object -First 20) -join ', '
    return @"
Traduce la orden del usuario a UNA sola linea con una de estas formas exactas:
abre <app>
abre <sitio>
abre <juego> en steam
busca <texto> en <sitio>
sube el volumen | baja el volumen | pon el volumen al <n>%
sube el brillo | baja el brillo | pon el brillo al <n>%
pausa | reproduce | siguiente | anterior | silencia
maximiza | minimiza | a mitad de pantalla | a la derecha
bloquea
modo juego | modo noche | modo trabajo | modo cine | modo silencio

Apps disponibles: $apps
Sitios disponibles: $sitios
Juegos instalados: $juegos

Responde SOLO con la linea traducida, sin comillas, sin explicacion y sin
ninguna palabra extra.
Si es una peticion de verdad dirigida a un asistente, pero no encaja en
ninguna de las formas de arriba, responde exactamente: TAREA
Si NO es una orden dirigida a nadie (conversacion ajena, el audio de un
video o de una cancion que sonaba de fondo, una frase suelta, inconexa o
sin sentido), responde exactamente: NO

Orden del usuario: $text
"@
}

function Submit-Command([string]$text, [string]$modo = 'accion', [string]$adjunto = '') {
    Log "SUBMIT ($modo): $text"
    $script:jobModo = $modo
    $script:jobTextoOriginal = $text
    $etiqueta = if ($modo -eq 'accion') { "* Procesando..." } else { "* Pensando..." }
    $lbl.Text = "$etiqueta (manten ≡ para cancelar)"
    $lbl.ForeColor = [System.Drawing.Color]::Gold
    $capture.Show()
    # sin puntos suspensivos: la capsula ya pone tres puntos que laten
    Set-UI 'pensando' $(if ($modo -eq 'accion') { 'Procesando' } elseif ($modo -eq 'traducir') { 'Entendiendo' } else { 'Pensando' })
    Add-Estadistica $modo $text

    $prompt = Expand-Prompt $text     # si pregunta por la memoria, ya viene guiado
    if ($modo -eq 'traducir') {
        $prompt = Build-PromptTraduccion $text
    } elseif ($modo -ne 'accion' -and $prompt -eq $text) {
        $prompt = $PRE_HABLADO + $text
    } elseif ($modo -eq 'accion') {
        # La respuesta se LEE EN VOZ ALTA: el agente contesta como si
        # escribiera, y tres lineas ya son demasiado para escuchar.
        $prompt = "Al terminar, resume lo que hiciste en UNA frase corta, sin listas ni markdown, porque se leera en voz alta. " + $prompt
    }
    # 'charla' encadena la sesion anterior: recuerda lo hablado antes
    $extra = if ($modo -eq 'charla') { '--continue' } else { '' }
    # captura de pantalla como contexto (el CLI admite --file)
    if ($adjunto -and (Test-Path -LiteralPath $adjunto)) {
        $extra = ($extra + ' --file ' + (ConvertTo-CmdArg $adjunto)).Trim()
        $prompt = "Te adjunto una captura de la ventana que tengo delante. " + $prompt
    }

    if (-not (Start-OpencodeJob $prompt $extra)) {
        Show-Popup "(no se pudo lanzar opencode; ver assistant.log)" 'error'
    }
}

# Formatea, registra y muestra la respuesta ya recogida.
function Report-Reply($out) {
    # --- respuesta a una peticion de TRADUCCION ---
    # El modelo solo propone texto; aqui se VALIDA contra el vocabulario cerrado
    # y solo se ejecuta si la capa local lo reconoce. Nunca se ejecuta texto
    # libre devuelto por el modelo.
    if ($script:jobModo -eq 'traducir') {
        $script:jobModo = ''
        $propuesta = (($out | Out-String) -replace '\s+', ' ').Trim()
        # el modelo a veces adorna: quedarse con la primera linea util
        $propuesta = ($propuesta -split '[\r\n]' | Where-Object { $_.Trim() } | Select-Object -First 1)
        $propuesta = $propuesta.Trim().Trim('"').Trim("'")
        $original = $script:jobTextoOriginal
        $veredicto = if ($propuesta) { $propuesta.ToUpperInvariant().Trim('.', ' ') } else { '' }
        # El modelo tiene la ultima palabra sobre si esto era una orden. Casi
        # nada de lo que llega hasta aqui lo dijo el usuario: es audio que el
        # microfono le robo a un video, al juego o a alguien hablando al lado.
        # Escalarlo al agente por si acaso -con --auto y todo Documents- era
        # regalarle el disco a una frase que nadie pronuncio, y encima costaba
        # entre 25 y 160 s de espera por cada ruido.
        if (-not $propuesta -or $veredicto -eq 'NO') {
            Log "NO era una orden: '$original' (descartado, no llega al agente)"
        $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
            Add-Estadistica 'ruido' $original
            Send-UIEvento 'gesto:confuso'
            Show-Popup "No te entendi. Repitelo." 'error'
            Say "No te entendi"
            return
        }
        # Peticion de verdad, pero fuera del vocabulario local: para eso esta
        # el agente. Esta es la UNICA puerta que le queda abierta a la voz.
        if ($veredicto -eq 'TAREA') {
            Log "peticion fuera del vocabulario local: va al agente completo"
            Submit-Command $original 'accion'
            return
        }
        if ($propuesta.Length -lt 120) {
            Log "traduccion propuesta: '$original' -> '$propuesta'"
            $r = $null
            # Una traduccion del modelo no se pregunta por parecido: o encaja o
            # no. Pero OJO con como se hace: antes se usaba $script:confirmado,
            # que significa 'el usuario ya dijo que si' y apaga TAMBIEN las
            # confirmaciones de las acciones que no se deshacen. O sea que una
            # propuesta nacida de un ruido ('cierra todos los programas', 'abre
            # SILENT BREATH en steam') se ejecutaba a la primera. $sinDudosa
            # silencia solo la pregunta por parecido, que es lo que se queria.
            $script:sinDudosa = $true
            try { $r = Invoke-FastCommand $propuesta } catch { $r = $null }
            $script:sinDudosa = $false
            if ($r) {
                Add-Traduccion $original $propuesta
                Add-Estadistica 'traducida' "$original -> $propuesta"
                $script:ultimaRespuesta = $r
                Send-UIEvento 'hecho'
                Show-Popup $r
                Say $r
                # AUTOAPRENDIZAJE: si la diferencia es UNA palabra ("calcu" ->
                # "calculadora"), se propone aprenderla como alias para que
                # valga en cualquier frase, no solo en esta
                try {
                    $gen = Find-Generalizacion $original $propuesta
                    if ($gen) {
                        $script:aprenderPendiente = @{ alias = $gen.alias; objetivo = $gen.objetivo
                            pregunta = ("¿Quieres que " + $gen.alias + " sea siempre " + $gen.objetivo + "?") }
                    }
                } catch {}
                return
            }
            Log "la traduccion '$propuesta' no resulto ejecutable"
        } else {
            Log "respuesta de traduccion ilegible (demasiado larga): '$propuesta'"
        }
        # Antes esto caia al agente. Ya no: si la capa local rechaza la orden
        # que propuso el propio modelo, el agente tampoco va a acertar, y mas
        # vale un "no" en un segundo que dos minutos de espera para nada.
        Add-Estadistica 'descarte' $original
        $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
        Send-UIEvento 'gesto:confuso'
        Show-Popup "No pude hacerlo. Dimelo de otra forma." 'error'
        Say "No pude hacerlo"
        return
    }

    # --- respuesta a una PREGUNTA: puede venir con el veredicto de arriba ---
    if ($script:jobModo -eq 'pregunta') {
        $limpia = (($out | Out-String) -replace '\s+', ' ').Trim().Trim('"').Trim("'").TrimEnd('.')
        if ($limpia.ToUpperInvariant() -eq 'NO') {
            $script:jobModo = ''
            Log "NO era una pregunta: '$($script:jobTextoOriginal)' (descartada)"
            Add-Estadistica 'ruido' $script:jobTextoOriginal
            $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
            Send-UIEvento 'gesto:confuso'
            Show-Popup "No te entendi. Repitelo." 'error'
            Say "No te entendi"
            return
        }
    }

    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $full = ($out | Out-String)
    Rotate-Log $ReplyLog
    Out-File -FilePath $ReplyLog -Append -Encoding utf8 -InputObject ("=== " + $now + " ===")
    Out-File -FilePath $ReplyLog -Append -Encoding utf8 -InputObject $full

    $lines = @($out) | Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 }
    $clean = $lines | Where-Object { $_.ToString() -notmatch '^\s*(>|-)' }
    $reply = (($clean | ForEach-Object { $_.ToString() }) -join " ").Trim()
    if ($reply.Length -eq 0) { $reply = "(sin respuesta)" }
    if ($reply.Length -gt 1000) { $reply = $reply.Substring(0, 1000) + " [...]" }
    Log "REPLY: $reply"
    $script:ultimaRespuesta = $reply
    # tarea larga terminada: un pulso largo en el mando, por si estabas jugando
    if (($sw.ElapsedMilliseconds - $script:jobStart) -ge 8000) { Start-Vibracion @(220) 24000 }
    Show-Popup $reply
    Say $reply
}

# --- confirmacion por voz ---
$ConfirmacionOn = [bool](Get-Cfg 'confirmacion' 'activada' $true)
$ConfirmacionMs = [int](Get-Cfg 'confirmacion' 'esperaMs' 3500)
$script:pendiente = $null
$script:confirmado = $false
# 'confirmado' = el usuario dijo que si. 'sinDudosa' = no preguntes por
# parecido, pero lo demas sigue en pie. Confundirlos abria la puerta de atras.
$script:sinDudosa = $false
$script:dudosa = $null

# Pide al worker que escuche un si/no. La pregunta ya se dijo (Say), y el
# worker esta en pausa mientras suena: el plazo empieza cuando termine.
function Start-Confirmacion {
    if (-not $script:pendiente) { return }
    Remove-Item -LiteralPath $RutaConfirmacion -Force -ErrorAction SilentlyContinue
    $espera = $ConfirmacionMs
    if ($script:pausaHasta -gt $sw.ElapsedMilliseconds) { $espera += ($script:pausaHasta - $sw.ElapsedMilliseconds) }
    $script:pendiente.vence = $sw.ElapsedMilliseconds + $espera
    if ($script:wakeProc -and -not $script:wakeProc.HasExited) {
        try { [System.IO.File]::WriteAllText($MarcaConfirmar, 'x') } catch {}
    }
}

# Resuelve la orden pendiente: 'si' la ejecuta, 'no' la cancela.
function Complete-Confirmacion([string]$respuesta) {
    $p = $script:pendiente
    $script:pendiente = $null
    Remove-Item -LiteralPath $MarcaConfirmar -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $RutaConfirmacion -Force -ErrorAction SilentlyContinue
    if (-not $p) { return }
    # pregunta de aprendizaje: solo un "si" claro ensena; el silencio, no
    if ($p.tipo -eq 'aprender') {
        if ($respuesta -eq 'si') {
            $r = $null
            try { $r = Add-Alias-Comando $p.alias $p.objetivo } catch { $r = $null }
            if ($r) { Send-UIEvento 'hecho'; Say "Aprendido: $($p.alias) es $($p.objetivo)." } else { Say "No pude guardarlo." }
        } else {
            Log "APRENDER: sin aprender ($respuesta)"
            if ($respuesta -eq 'no') { Say "Vale, lo dejo." } else { Set-UI 'reposo' }
        }
        return
    }
    # CALLARSE NO EJECUTA NADA, tampoco en las dudosas. Antes el silencio valia
    # por un si a los 3,5 s, y eso convertia cada coincidencia floja del ruido
    # en una accion: el microfono capta 'el', se pregunta '¿Edge?', nadie
    # contesta porque nadie sabia que se estaba preguntando, y se abre Edge.
    # Para decir que si hay que decirlo.
    if ($respuesta -ne 'si') {
        Log "CONFIRMAR: no se ejecuta '$($p.texto)' ($respuesta)"
        if ($respuesta -eq 'no') {
            Set-UI 'error' 'Vale, cancelado' 2000
            Say "Vale, lo dejo."
        } else {
            # silencio: ni se ejecuta ni se habla, que a lo mejor no habia nadie
            Set-UI 'reposo'
        }
        return
    }
    Log "CONFIRMAR: $respuesta -> se ejecuta '$($p.texto)'"
    $script:confirmado = $true
    try { Process-Texto $p.texto } finally { $script:confirmado = $false }
}

# "Lo tengo": mientras dictas, si lo transcrito hasta ahora ya es una orden
# que la capa local reconoce, la capsula asiente una vez. Con tope de una
# comprobacion cada 400 ms: los parciales cambian varias veces por segundo.
$script:loTengo = $false
$script:loTengoCheck = 0
$script:perdida = $false
$script:seguimientoPendiente = $false
$script:enSeguimiento = $false
$script:seguimientoFactor = 1.0
# --- oido fino: repaso de la ultima orden con el modelo preciso ---
$script:yaReintentado = $false     # una sola vez por orden, o seria un bucle
$script:reintentoVence = 0
$script:reintentoTexto = ''
$ReintentoMaxMs = 15000            # si no contesta a tiempo, se sigue sin el
$script:aprenderPendiente = $null
$script:ultimaLectura = ''
function Test-LoTengo([string]$vista) {
    if ($script:loTengo -or -not $UiNuevaOn -or -not $vista) { return }
    if (($sw.ElapsedMilliseconds - $script:loTengoCheck) -lt 400) { return }
    $script:loTengoCheck = $sw.ElapsedMilliseconds
    $ok = $false
    try { $ok = Test-FastCommand $vista } catch { $ok = $false }
    if ($ok) { $script:loTengo = $true; Send-UIEvento 'gesto:lotengo' }
}

# Abre el dictado. La llaman el boton y la palabra de activacion, para que
# ambos caminos se comporten EXACTAMENTE igual.
function Start-Dictado([string]$origen) {
    Log "DICTADO ($origen)"
    $script:yaReintentado = $false
    # Cuantas veces se despierta por voz. Sin este numero no hay forma de
    # saber si los filtros de falsas alarmas funcionan o si, al reves, se han
    # pasado de listos y ya no te oyen.
    if ($origen -like 'nombre*') { Add-Estadistica 'activacion' }
    $script:loTengo = $false
    $script:perdida = $false
    $script:seguimientoPendiente = $false
    $seguimiento = ($origen -eq 'seguimiento')
    $script:enSeguimiento = $seguimiento
    # con la capsula, el sonido lo pone ella (un tono corto, no la campana)
    if (-not $UiNuevaOn -and -not $seguimiento) { [System.Media.SystemSounds]::Exclamation.Play() }

    # --- Dictado por el worker (Whisper/Vosk): ni foco, ni Win+H, ni pausa ---
    # El worker ya tiene el microfono; solo hay que decirle que transcriba.
    if ($DictadoWorker -and $script:wakeProc) {
        Remove-Item -LiteralPath $RutaDictado -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $RutaParcial -Force -ErrorAction SilentlyContinue
        # en seguimiento, la marca lleva el plazo: si no hay voz en ese tiempo
        # el worker cierra solo y entrega vacio
        $ventana = [int]($SeguimientoMs * $script:seguimientoFactor)
        [System.IO.File]::WriteAllText($MarcaDictar, $(if ($seguimiento) { "seguimiento:$ventana" } else { 'x' }))
        Start-Vibracion $(if ($seguimiento) { @(40) } else { @(90) })
        $lbl.Text = "● VOZ..."
        $lbl.ForeColor = [System.Drawing.Color]::LimeGreen
        $capture.Show()
        if ($seguimiento) { Set-UI 'atenta' }
        else { Set-UI 'escuchando'; Send-UIEvento 'despierta' }
        $script:armed = $true
        $script:dictaInicio = $sw.ElapsedMilliseconds
        return
    }
    if ($seguimiento) { $script:enSeguimiento = $false; return }   # Win+H no puede esperar en silencio

    # --- Camino antiguo (Win+H), solo si se pide por configuracion ---
    # mientras dictas, el worker no debe escuchar: competiria por el microfono
    Pausar-Escucha 60000
    if (Show-Capture) {
        Send-WinH
        Set-UI 'escuchando'
        Send-UIEvento 'despierta'
        $script:armed = $true
        # punto de partida para detectar el silencio
        $script:lastText = ""
        $script:lastChange = $sw.ElapsedMilliseconds
    } else {
        # ABORTAR, no continuar: sin el foco, el dictado escribe en OTRA
        # ventana y esas pulsaciones disparan cosas sueltas.
        Log "ABORTADO: sin primer plano; no se abre el dictado"
        [System.Media.SystemSounds]::Hand.Play()
        $capture.Hide()
        # IMPRESCINDIBLE: sin esto la pausa de 60 s se queda puesta y la palabra
        # de activacion queda muda un minuto cada vez que falla el foco, que en
        # esta maquina no es raro (overlays de ASUS robando el primer plano).
        Reanudar-Escucha
        Show-Popup "No pude tomar el foco. Dictado cancelado. Intenta de nuevo." 'error'
        $script:armed = $false
    }
}

# Cierra el dictado, recoge el texto y lo ejecuta. La llaman tanto el segundo
# hold del boton como el envio automatico por silencio.
function Finish-Dictation([string]$motivo) {
    Log "ENVIAR ($motivo)"
    $script:armed = $false
    $text = ''
    try {
        Send-Key $VK_ESCAPE
        $text = Wait-DictationText
    } finally {
        # en finally: si Send-Key o la captura fallan, la pausa NO puede
        # quedarse puesta o la escucha se queda muda hasta un minuto
        $capture.Hide()
        Reanudar-Escucha
    }
    Process-Texto $text
}

# Todo lo que ocurre DESPUES de tener el texto. Lo comparten el dictado por
# Vosk y el antiguo de Windows, para que se comporten igual.
function Process-Texto([string]$text) {
    if ($text.Length -gt 0) {
        $plano = ConvertTo-Plain $text
        # en seguimiento, "gracias" / "nada mas" cierran la cadena con elegancia
        if ($script:enSeguimiento -and $plano -match '^(?:gracias|muchas gracias|ok gracias|vale gracias|nada mas|eso es todo|eso es todo gracias|listo|ya esta|ya|nada|no nada|ok|vale)$') {
            Log "seguimiento: cerrado con '$text'"
            $script:enSeguimiento = $false
            $script:seguimientoPendiente = $false
            if ($plano -match 'gracias') { Say "De nada." } else { Set-UI 'reposo' }
            return
        }
        # cualquier orden real deja preparado el seguimiento (se arma al
        # terminar de hablar); lo que no lleva respuesta hablada lo apaga
        $script:seguimientoPendiente = $true
        # SEGUIMIENTO INTELIGENTE: si la frase queda "colgando" ("abre steam
        # y...", "pon el volumen y luego..."), la ventana se alarga; si acaba
        # en "listo" / "y ya", no hay ventana. La coletilla se quita antes de
        # ejecutar.
        $script:seguimientoFactor = 1.0
        if ($plano -match '\s(?:y|e|o|luego|despues|tambien|ademas|y luego|y despues|y tambien)$' -or $text.Trim().EndsWith(',')) {
            $script:seguimientoFactor = 2.4
            $text = ($text -replace '(?i)[\s,]+(?:y|e|o|luego|despu[eé]s|tambi[eé]n|adem[aá]s|y luego|y despu[eé]s|y tambi[eé]n)\s*$', '').Trim()
            $plano = ConvertTo-Plain $text
            if (-not $text) { Set-UI 'reposo'; return }
        } elseif ($plano -match '\s(?:listo|y ya|eso es todo|nada mas|y nada mas)$') {
            $script:seguimientoFactor = 0
            $text = ($text -replace '(?i)[\s,]+(?:listo|y ya|eso es todo|nada m[aá]s|y nada m[aá]s)\s*$', '').Trim()
            $plano = ConvertTo-Plain $text
        }

        # NO hay modo conversacion persistente. Se probó y fue un error: al
        # quedarse activo se tragaba las ordenes ("Abre steam" acababa en el
        # modelo, que ademas se negaba a ejecutar). Cada frase se enruta sola.
        #
        # En su lugar, la charla se pide EXPLICITAMENTE por frase. Encadena la
        # sesion con --continue, asi que recuerda lo hablado, pero no puede
        # secuestrar nada: en cuanto dices otra cosa, vuelve al enrutado normal.
        if ($plano -match '^(?:preguntale a la ia|pregunta a la ia|dile a la ia|consulta a la ia|oye ia|hey ia)\s+(.+)$') {
            # se recorta del texto ORIGINAL para no perder acentos ni mayusculas
            $sinPrefijo = $text -replace '(?i)^\s*(?:preg[uú]ntale a la ia|pregunta a la ia|dile a la ia|consulta a la ia|oye ia|hey ia)\s+', ''
            # si habla de lo que hay delante ("que es esto", "esta ventana",
            # "lo que ves"), se adjunta una captura de la ventana activa
            $adjunto = ''
            if ($plano -match '\b(?:esto|esta ventana|esta pantalla|la pantalla|en pantalla|lo que ves|lo que hay aqui|aqui|esta imagen|este error|este mensaje|esta foto)\b') {
                try {
                    $adjunto = Save-Captura (Join-Path $TmpDir 'pantalla.png')
                    Log "contexto de pantalla adjuntado"
                    # el modelo puede no ver imagenes: se le da tambien el TEXTO
                    # de la ventana (OCR), que vale para casi todo (errores,
                    # mensajes, menus)
                    try {
                        Set-UI 'pensando' 'leyendo la pantalla'
                        $vis = Invoke-OCR $adjunto
                        if ($vis) {
                            if ($vis.Length -gt 1500) { $vis = $vis.Substring(0, 1500) }
                            $sinPrefijo = $sinPrefijo + " [Texto visible en la ventana activa: " + $vis + "]"
                        }
                    } catch { Log ("ocr para contexto fallo: " + $_.Exception.Message) }
                } catch { Log ("captura fallida: " + $_.Exception.Message); $adjunto = '' }
            }
            Submit-Command $sinPrefijo 'charla' $adjunto
            return
        }

        # 1) local instantaneo
        $fast = $null
        $script:ultimoDescarte = ''
        try { $fast = Invoke-FastCommand $text }
        catch { Log "fast-command error: $($_.Exception.Message)"; $fast = $null }
        if ($fast) {
            if ($script:pendiente) {
                # coincidencia dudosa: se pregunta y se espera un si/no (o el
                # plazo). $fast es la pregunta ("¿Little Nightmares III?")
                Log "CONFIRMAR: '$text' -> $fast"
                Show-Popup $fast
                Say $fast
                Set-UI 'escuchando' $fast
                Start-Confirmacion
            } else {
                Log "LOCAL: $text -> $fast"
                Add-Estadistica 'local' $text
                $script:ultimaRespuesta = $fast
                Send-UIEvento 'hecho'
                Show-Popup $fast
                Say $fast
            }
        }
        # 1b) memoria: buscar en las notas ANTES de molestar al modelo
        elseif ($plano -match $RE_MEMORIA) {
            $enc = $null
            try { $enc = Find-EnMemoria $text } catch { $enc = $null }
            if ($enc) {
                Log "MEMORIA LOCAL: $text -> $enc"
                Add-Estadistica 'memoria' $text
                $script:ultimaRespuesta = $enc
                Send-UIEvento 'hecho'
                Show-Popup $enc
                Say $enc
            } else {
                Submit-Command $text 'pregunta'   # Expand-Prompt le dira donde mirar
            }
        }
        # 2) pregunta: que CONTESTE, no que actue (~13 s en vez de 25-160 s)
        elseif ($plano -match $RE_PREGUNTA) {
            Submit-Command $text 'pregunta'
        }
        else {
            # 3) ¿ya aprendimos a traducir esta orden? entonces es instantanea
            $apr = Find-Traduccion $text
            if ($apr) {
                $r = $null
                try { $r = Invoke-FastCommand $apr } catch { $r = $null }
                if ($r) {
                    Log "APRENDIDA: '$text' -> '$apr' -> $r"
                    Add-Estadistica 'aprendida' $text
                    $script:ultimaRespuesta = $r
                    Send-UIEvento 'hecho'
                    Show-Popup $r
                    Say $r
                    return
                }
            }
            # 3.5) FILTRO DE RUIDO. Lo que llega aqui no lo entendio la capa
            #      local, y el siguiente paso lo manda al agente con --auto,
            #      que puede hacer CUALQUIER COSA en el disco. Una frase de una
            #      o dos palabras sueltas casi nunca es una orden: es el
            #      microfono mal transcrito ("Oh", "Ok", "El", "Meme"). Antes
            #      esos restos se ejecutaban y por eso se abrian cosas que
            #      nadie habia pedido. Se pide repetir en vez de adivinar.
            $palabras = @(($text -split '\s+') | Where-Object { $_ -ne '' })
            if ($palabras.Count -le 2 -and $text.Length -lt 18) {
                Log "RUIDO descartado (no llega al agente): '$text'"
                $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
                Add-Estadistica 'ruido' $text
                Send-UIEvento 'gesto:confuso'
                Show-Popup "No te entendi. Repitelo." 'error'
                Say "No te entendi"
                return
            }
            # 3.6) SEGUNDA OPORTUNIDAD (oido fino). El modelo rapido deforma
            #      los nombres propios: 'abre steam' llega como 'abrestean'.
            #      Se repasa el MISMO audio con el modelo preciso antes de
            #      gastar 13 s de modelo remoto.
            #      VA DESPUES DEL FILTRO DE RUIDO, y no es un detalle: al reves
            #      (11/09, 20:15) un ruido transcrito como 'los' se mando a
            #      repasar, el modelo preciso -sesgado con la lista de juegos-
            #      alucino 'SILENT BREATH', y el asistente ABRIO el juego solo
            #      mientras el usuario estaba jugando a otra cosa. El filtro de
            #      ruido existia precisamente para eso y yo lo habia saltado.
            if ($WhisperPreciso -and $DictadoWorker -and -not $script:yaReintentado -and
                $script:wakeProc -and -not $script:wakeProc.HasExited) {
                $script:yaReintentado = $true
                try {
                    Remove-Item -LiteralPath $RutaReintento -Force -ErrorAction SilentlyContinue
                    [System.IO.File]::WriteAllText($MarcaReintento, 'x')
                    $script:reintentoTexto = $text
                    $script:reintentoVence = $sw.ElapsedMilliseconds + $ReintentoMaxMs
                    Log "OIDO FINO: no reconoci '$text', pido repaso"
                    Set-UI 'pensando' 'Afinando el oido'
                    return
                } catch {
                    $script:reintentoVence = 0
                    Log ('no se pudo pedir el repaso: ' + $_.Exception.Message)
                }
            }

            # 4) que el modelo la traduzca a una orden conocida (~13 s) y se
            #    aprenda; si no encaja, cae al agente completo
            if ($script:ultimoDescarte) { Add-Estadistica 'descarte' $script:ultimoDescarte; $script:ultimoDescarte = '' }
            Send-UIEvento 'gesto:confuso'   # "no te entendi del todo": ladea la cabeza
            if ($TraducirOn) { Submit-Command $text 'traducir' }
            else { Submit-Command $text }
        }
    } else {
        # antes esto era mudo: no distinguias "fallo" de "no dije nada"
        Log "vacio, ignorado"
        if (-not $UiNuevaOn) { [System.Media.SystemSounds]::Hand.Play() }
        Add-Estadistica 'error' 'dictado vacio'
        Show-Popup "No te escuche. Intenta de nuevo." 'error'
    }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Saludo al arrancar: confirma en voz alta que esta lista, y sirve de prueba
# inmediata de que la cadena de audio funciona de extremo a extremo.
if ($SaludoOn) {
    try {
        $saludo = if ($EscuchaOn) { "Listo. Di $EscuchaNombre cuando me necesites." } else { "Listo." }
        Log "saludo de arranque"
        Say $saludo
    } catch { Log ("saludo fallido: " + $_.Exception.Message) }
}

$startPrev = $false
$downSince = 0
$holdFired = $false
$script:armed = $false
$script:lastText = ""
$script:lastChange = 0
$script:ultimaRespuesta = ""
$script:bateriaCheck = 0
$script:bateriaAvisada = $false
$script:cargaCheck = 0
$script:minutoVisto = ''
$script:diaVisto = Get-Date -Format 'yyyy-MM-dd'
# al arrancar: fechas de hoy y nota de la semana pasada (si toca)
try { Test-FechasHoy } catch {}
try { Write-NotaSemanal } catch {}
$script:wakeCheck = 0
$script:wakeIntentos = 0
$script:pollReintento = 0
$script:temporizadores = New-Object System.Collections.ArrayList
$script:juegoCheck = 0
$script:ultimoObjetivo = ''
$script:dictaInicio = 0
$script:jobModo = ''
$script:jobTextoOriginal = ''
$pollErrs = 0

while ($true) {
    [System.Windows.Forms.Application]::DoEvents()
    $startNow = $false
    $pollOk = $true
    # tras un fallo de XInput se espera 5 s SIN bloquear el bucle: el resto
    # (escucha, popups, trabajos) tiene que seguir atendiendose
    $saltarPoll = ($script:pollReintento -gt 0 -and $sw.ElapsedMilliseconds -lt $script:pollReintento)
    for ($u = 0; (-not $saltarPoll) -and $u -lt 4; $u++) {
        try {
            $state = New-Object AX+XINPUT_STATE
            $r = [AX]::XInputGetState([uint32]$u, [ref]$state)
            if ($r -eq 0 -and (($state.Gamepad.wButtons -band $TRIGGER) -eq $TRIGGER)) {
                $startNow = $true
                break
            }
        } catch {
            # NADA de Start-Sleep aqui dentro: estaba en un bucle sobre los 4
            # mandos, asi que un fallo persistente de XInput dormia hasta 20 s
            # POR VUELTA con el boton sin responder. El contador solo silenciaba
            # el log, no evitaba la espera. Ahora se corta el tick y se aplaza
            # el siguiente intento sin bloquear.
            $pollOk = $false
            $pollErrs++
            if ($pollErrs -le 5) {
                Log "poll error: $($_.Exception.Message)"
                if ($pollErrs -eq 5) { Log "poll error: se silencian los siguientes avisos hasta que vuelva a funcionar" }
            }
            $script:pollReintento = $sw.ElapsedMilliseconds + 5000
            break
        }
    }
    if ($pollOk) { $pollErrs = 0 }

    if ($startNow -and -not $startPrev) {
        $downSince = $sw.ElapsedMilliseconds
        $holdFired = $false
    }
    if ($startNow -and -not $holdFired -and ($sw.ElapsedMilliseconds - $downSince) -ge $HOLD_MS) {
        $holdFired = $true
        try {
            if ($script:busy) {
                # Un hold mientras opencode trabaja = cancelar. Antes esta
                # pulsacion se perdia: el bucle estaba bloqueado esperando.
                Log "CANCELAR (hold durante procesamiento)"
                if (-not $UiNuevaOn) { [System.Media.SystemSounds]::Hand.Play() }
                Stop-OpencodeJob
                Add-Estadistica 'error' 'cancelado'
                Send-UIEvento 'gesto:sobresalto'
                Show-Popup "Orden cancelada." 'error'
            } elseif (-not $script:armed) {
                Start-Dictado "mantener ≡"
            } elseif ($DictadoWorker -and $script:wakeProc) {
                # con Vosk el boton solo dice "ya termine": el worker entrega
                # lo que lleve transcrito y el bucle lo recoge
                Log "ENVIAR (boton)"
                Remove-Item -LiteralPath $MarcaDictar -Force -ErrorAction SilentlyContinue
            } else {
                Finish-Dictation "boton"
            }
        } catch {
            Log "accion error: $($_.Exception.Message)"
            $script:armed = $false
        }
    }

    # --- VIGILANCIA DEL WORKER DE ESCUCHA ---
    # Si muere, la palabra de activacion deja de funcionar EN SILENCIO durante
    # el resto de la sesion: el bucle solo miraba el archivo marca, que nunca
    # volveria a aparecer. Se comprueba cada 30 s y se relanza.
    if ($EscuchaOn -and ($sw.ElapsedMilliseconds - $script:wakeCheck) -ge 30000) {
        $script:wakeCheck = $sw.ElapsedMilliseconds
        if ($script:wakeProc -and $script:wakeProc.HasExited) {
            if ($script:wakeIntentos -lt 3) {
                $script:wakeIntentos++
                Log "WARN: el worker de escucha murio; relanzando (intento $($script:wakeIntentos)/3)"
                # liberar el handle antes de soltar la referencia: este proceso
                # vive meses y cada relanzo filtraria uno
                try { $script:wakeProc.Dispose() } catch {}
                $script:wakeProc = $null
                Initialize-Escucha
            } elseif ($script:wakeIntentos -eq 3) {
                $script:wakeIntentos++   # avisar una sola vez
                Log "ERROR: el worker de escucha no se sostiene; se sigue solo con el boton"
                Show-Popup "La palabra de activacion fallo. Sigue funcionando el boton." 'error'
                Say "La escucha por voz fallo. Puedes seguir usando el boton."
            }
        } elseif ($script:wakeProc) {
            $script:wakeIntentos = 0   # lleva vivo un rato: se rearman los reintentos
        }
    }

    # reanuda la escucha cuando vence la pausa (fin estimado de la voz)
    if ($script:pausaHasta -gt 0 -and $sw.ElapsedMilliseconds -ge $script:pausaHasta -and -not $script:armed) {
        Reanudar-Escucha
        # SEGUIMIENTO: acabo de responder a una orden; vuelvo a escuchar un
        # rato sin palabra de activacion por si encadenas otra
        if ($script:aprenderPendiente -and -not $script:busy -and -not $script:pendiente) {
            # antes del seguimiento, la pregunta de aprendizaje ("¿quieres que
            # 'calcu' sea siempre 'calculadora'?"); el seguimiento se pierde,
            # es una pregunta y espera si/no
            $ap = $script:aprenderPendiente
            $script:aprenderPendiente = $null
            $script:pendiente = @{ texto = ''; vence = 0; tipo = 'aprender'; alias = $ap.alias; objetivo = $ap.objetivo }
            Log "APRENDER: pregunto por '$($ap.alias)' -> '$($ap.objetivo)'"
            Say $ap.pregunta
            Set-UI 'escuchando' $ap.pregunta
            Start-Confirmacion
        } elseif ($script:seguimientoPendiente -and $SeguimientoMs -gt 0 -and $script:seguimientoFactor -gt 0 -and $DictadoWorker -and $script:wakeProc -and
            -not $script:wakeProc.HasExited -and -not $script:busy -and -not $script:pendiente) {
            Start-Dictado 'seguimiento'
        }
        $script:seguimientoPendiente = $false
    }

    # --- CONFIRMACION PENDIENTE (si / no / plazo) ---
    if ($script:pendiente) {
        $resp = ''
        if (Test-Path -LiteralPath $RutaConfirmacion) {
            try { $resp = ([System.IO.File]::ReadAllText($RutaConfirmacion)).Trim().ToLowerInvariant() } catch {}
            if ($resp -ne 'si' -and $resp -ne 'no') { $resp = '' }
        }
        if ($resp) { Complete-Confirmacion $resp }
        elseif ($sw.ElapsedMilliseconds -ge $script:pendiente.vence) { Complete-Confirmacion 'plazo' }
    }

    # --- PALABRA DE ACTIVACION ---
    # El worker deja un archivo marca; aqui solo se mira si existe. Nada de
    # eventos ni hilos compartidos: eso es lo que mataba el proceso.
    if ($script:wakeProc -and (Test-Path -LiteralPath $MarcaWake)) {
        Remove-Item -LiteralPath $MarcaWake -Force -ErrorAction SilentlyContinue
        if ($script:armed -or $script:busy -or $script:pendiente) {
            # ya estabamos escuchando o procesando: se ignora sin ruido
        } elseif (($sw.ElapsedMilliseconds - $script:finVoz) -lt 1500) {
            # acabamos de hablar: evita despertarse con su propia voz
            Log "despertar ignorado (acabamos de hablar)"
        } else {
            Start-Dictado "nombre '$EscuchaNombre'"
        }
    }

    # --- DICTADO POR VOSK: recoger lo transcrito y mostrarlo en vivo ---
    if ($script:armed -and $DictadoWorker) {
        # transcripcion en vivo: ver lo que oye mientras hablas
        if (Test-Path -LiteralPath $RutaParcial) {
            try {
                $par = [System.IO.File]::ReadAllText($RutaParcial, [System.Text.Encoding]::UTF8)
                $vista = ($par -replace '\s+', ' ').Trim()
                if ($vista.Length -gt 44) { $vista = "..." + $vista.Substring($vista.Length - 41) }
                $nuevo = if ($vista) { "● $vista" } else { "● VOZ..." }
                if ($lbl.Text -ne $nuevo) { $lbl.Text = $nuevo; Set-UI 'escuchando' $vista; Test-LoTengo $vista }
            } catch {}
        }
        # el worker ya termino: entrega el texto
        if (Test-Path -LiteralPath $RutaDictado) {
            $dic = ''
            try { $dic = [System.IO.File]::ReadAllText($RutaDictado, [System.Text.Encoding]::UTF8) } catch {}
            Remove-Item -LiteralPath $RutaDictado -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $MarcaDictar -Force -ErrorAction SilentlyContinue
            $script:armed = $false
            $capture.Hide()
            # la voz que dicto (por tono): la capsula tine la escucha por persona
            try {
                $rv = Join-Path $TmpDir 'dictado-voz.txt'
                if (Test-Path -LiteralPath $rv) {
                    $v = ([System.IO.File]::ReadAllText($rv).Trim() -split '\s+')[0]
                    $script:uiVoz = [int]$v
                    Remove-Item -LiteralPath $rv -Force -ErrorAction SilentlyContinue
                }
            } catch {}
            if ($script:enSeguimiento -and -not $dic.Trim()) {
                # ventana de seguimiento sin voz: se cierra sin decir nada
                Log "seguimiento: silencio, se cierra"
                $script:enSeguimiento = $false
                Set-UI 'reposo'
            } else {
                Process-Texto ($dic.Trim())
            }
        }
        # "me perdi": 25 s dictando sin que nada encaje todavia
        elseif (-not $script:perdida -and -not $script:loTengo -and ($sw.ElapsedMilliseconds - $script:dictaInicio) -ge 25000) {
            $script:perdida = $true
            Send-UIEvento 'gesto:perdida'
        } elseif (($sw.ElapsedMilliseconds - $script:dictaInicio) -ge 35000) {
            # red de seguridad: si el worker no responde, no dejar el estado colgado
            Log "dictado sin respuesta del worker; se cancela"
            Remove-Item -LiteralPath $MarcaDictar -Force -ErrorAction SilentlyContinue
            $script:armed = $false
            $capture.Hide()
            Set-UI 'error' 'Sin respuesta del microfono' 2500
        }
    }

    # --- ENVIO AUTOMATICO (solo para el dictado antiguo de Windows).
    # Con Vosk el propio worker detecta el silencio y entrega el texto.
    if ($script:armed -and -not $DictadoWorker -and $AutoSubmitMs -gt 0) {
        $actual = $tb.Text
        if ($actual -ne $script:lastText) {
            $script:lastText = $actual
            $script:lastChange = $sw.ElapsedMilliseconds
            # TRANSCRIPCION EN VIVO: ver lo que oye mientras hablas. Asi notas
            # al momento si transcribio mal, en vez de descubrirlo al ejecutar.
            $vista = ($actual -replace '\s+', ' ').Trim()
            if ($vista.Length -gt 44) { $vista = "..." + $vista.Substring($vista.Length - 41) }
            $lbl.Text = if ($vista) { "● $vista" } else { "● VOZ..." }
            Set-UI 'escuchando' $vista
            Test-LoTengo $vista
        } elseif ($actual.Trim().Length -gt 0 -and ($sw.ElapsedMilliseconds - $script:lastChange) -ge $AutoSubmitMs) {
            try { Finish-Dictation "silencio" }
            catch { Log "auto-envio error: $($_.Exception.Message)"; $script:armed = $false }
        }
    }

    # --- atencion al trabajo en curso, sin bloquear el sondeo del boton ---
    if ($script:busy -and $script:proc) {
        Watch-OpencodeProgress
        if ($script:proc.HasExited) {
            $script:uiProgreso = 0
            Report-Reply (Complete-OpencodeJob)
        } elseif (($sw.ElapsedMilliseconds - $script:jobStart) -ge $CliTimeoutMs) {
            Log "RUNNER timeout tras $([Math]::Round($CliTimeoutMs/1000)) s"
            $script:uiProgreso = 0
            Stop-OpencodeJob
            Add-Estadistica 'error' 'timeout de opencode'
            Show-Popup "(timeout: opencode tardo mas de $([Math]::Round($CliTimeoutMs/1000)) s)" 'error'
        }
    }

    # --- OIDO FINO: recoger el repaso (o rendirse cuando vence el plazo) ---
    # No se espera bloqueando: el bucle sigue vivo, la capsula sigue animandose
    # y el boton sigue respondiendo mientras el worker repasa el audio.
    if ($script:reintentoVence -gt 0) {
        $fino = $null
        if (Test-Path -LiteralPath $RutaReintento) {
            try { $fino = [System.IO.File]::ReadAllText($RutaReintento, [System.Text.Encoding]::UTF8) } catch { $fino = '' }
            Remove-Item -LiteralPath $RutaReintento -Force -ErrorAction SilentlyContinue
        } elseif ($sw.ElapsedMilliseconds -ge $script:reintentoVence) {
            Log "OIDO FINO: sin respuesta a tiempo; sigo con lo que tenia"
            Remove-Item -LiteralPath $MarcaReintento -Force -ErrorAction SilentlyContinue
            $fino = ''
        }
        if ($null -ne $fino) {
            $script:reintentoVence = 0
            $orig = $script:reintentoTexto
            $script:reintentoTexto = ''
            $limpio = $fino.Trim()
            if ($limpio -and (ConvertTo-Plain $limpio) -ne (ConvertTo-Plain $orig) -and (Test-MismoAudio $orig $limpio)) {
                Log "OIDO FINO: '$orig' -> '$limpio'"
                Process-Texto $limpio
            } elseif ($limpio -and -not (Test-MismoAudio $orig $limpio)) {
                Log "OIDO FINO descartado: '$limpio' no se parece en nada a '$orig'; es invento suyo"
                Add-Estadistica 'ruido' $orig
                $script:seguimientoPendiente = $false
                Send-UIEvento 'gesto:confuso'
                Show-Popup "No te entendi. Repitelo." 'error'
                Say "No te entendi"
            } else {
                # el oido fino oyo lo mismo (o nada): no hay nada que ganar
                Process-Texto $orig
            }
        }
    }

    # --- temporizadores vencidos ---
    if ($script:temporizadores.Count -gt 0) {
        for ($i = $script:temporizadores.Count - 1; $i -ge 0; $i--) {
            $t = $script:temporizadores[$i]
            if ($sw.ElapsedMilliseconds -ge $t.vence) {
                $script:temporizadores.RemoveAt($i)
                Log "TEMPORIZADOR: $($t.texto)"
                [System.Media.SystemSounds]::Exclamation.Play()
                Show-Popup $t.texto
                Say $t.texto
                Send-UIEvento 'aviso'
            }
        }
    }

    # --- juegos colgados: avisar, NUNCA cerrar por su cuenta ---
    # Solo avisa (y una vez por proceso): cerrar un juego a la fuerza pierde lo
    # que no este guardado, y eso lo decide el usuario, no el asistente.
    if (($sw.ElapsedMilliseconds - $script:zombiCheck) -ge 600000) {
        $script:zombiCheck = $sw.ElapsedMilliseconds
        if (-not $script:busy -and -not $script:armed -and -not $script:pendiente) {
            if ($script:zombisAvisados.Count -gt 20) { $script:zombisAvisados = @{} }
            foreach ($z in @(Get-JuegosZombis)) {
                if ($script:zombisAvisados.ContainsKey($z.proc.Id)) { continue }
                $script:zombisAvisados[$z.proc.Id] = $true
                $h = [int]($z.minutos / 60)
                $cuanto = if ($h -gt 0) { "$h horas" } else { "$($z.minutos) minutos" }
                $msg = "$($z.nombre) lleva $cuanto abierto sin ventana y gastando procesador. Parece colgado. Si quieres, di: cierra lo colgado."
                Log "ZOMBI: $($z.nombre) PID=$($z.proc.Id) $($z.minutos) min uso=$([Math]::Round($z.uso, 2))"
                Show-Popup $msg
                Say $msg
                break   # de uno en uno: dos avisos seguidos serian una encerrona
            }
        }
    }

    # --- que juego esta en primer plano (cada 10 s, es una consulta cara) ---
    if (($sw.ElapsedMilliseconds - $script:juegoCheck) -ge 10000) {
        $script:juegoCheck = $sw.ElapsedMilliseconds
        try {
            $script:juegoExeCandidato = ''
            $j = Get-JuegoEnPrimerPlano
            if ($j -ne $script:juegoActivo) {
                if ($script:juegoActivo) { Exit-Juego $script:juegoActivo }
                if ($j) {
                    Log "juego en primer plano: $j"
                    $script:juegoDesde = $sw.ElapsedMilliseconds
                    $script:juegoExe = $script:juegoExeCandidato
                    Enter-Juego $j
                    if ($SoloBotonEnJuego) {
                        try {
                            [System.IO.File]::WriteAllText($MarcaSoloBoton, $j)
                            Log 'escucha: solo boton mientras juegas (config: escucha.soloBotonEnJuego)'
                        } catch {}
                    }
                } else {
                    $script:juegoExe = ''
                    try { Remove-Item -LiteralPath $MarcaSoloBoton -Force -ErrorAction SilentlyContinue } catch {}
                    if ($SoloBotonEnJuego) { Log 'escucha: vuelve la palabra de activacion (fuera del juego)' }
                }
                $script:juegoActivo = $j
                Refresh-UI   # la capsula cambia de avatar
            } elseif ($j) {
                Watch-LogrosSteam
                # cada hora completa de juego, una "medalla" en la capsula (sin voz)
                $horasJugadas = [int][Math]::Floor(($sw.ElapsedMilliseconds - $script:juegoDesde) / 3600000)
                if ($horasJugadas -gt $script:juegoHoras) {
                    $script:juegoHoras = $horasJugadas
                    Log "JUEGO: $horasJugadas h con $j"
                    Send-UIEvento 'logro'
                }
            }
            if ($j -and $JuegoAvisoMin -gt 0 -and -not $script:juegoAvisado -and
                      (($sw.ElapsedMilliseconds - $script:juegoDesde) -ge ($JuegoAvisoMin * 60000))) {
                $script:juegoAvisado = $true
                $horas = [Math]::Round($JuegoAvisoMin / 60.0, 1)
                $cuanto = if ($JuegoAvisoMin -ge 60 -and ($JuegoAvisoMin % 60) -eq 0) { "$([int]$horas) horas" } else { "$JuegoAvisoMin minutos" }
                if ($cuanto -eq '1 horas') { $cuanto = 'una hora' }
                Log "JUEGO: aviso de tiempo ($cuanto con $j)"
                Say "Oye, ya llevas $cuanto con $j."
                Send-UIEvento 'aviso'
            }
        } catch {}
    }

    # --- reglas por hora y periodicas; fechas; nota semanal (cada minuto) ---
    $minutoAhora = Get-Date -Format 'HH:mm'
    if ($minutoAhora -ne $script:minutoVisto) {
        $script:minutoVisto = $minutoAhora
        try { Invoke-Reglas 'hora' $minutoAhora; Invoke-Reglas 'cada' } catch {}
        try { Test-Recordatorios } catch {}
        $diaAhora = Get-Date -Format 'yyyy-MM-dd'
        if ($diaAhora -ne $script:diaVisto) {
            $script:diaVisto = $diaAhora
            try { Test-FechasHoy } catch {}
            try { Write-NotaSemanal } catch {}
        }
        # micro-charla: un comentario si viene a cuento, una vez al dia
        if ($CharlaOn -and $script:juegoActivo) {
            $minsJuego = ($sw.ElapsedMilliseconds - $script:juegoDesde) / 60000
            if ($minsJuego -ge 180 -and $script:charlaAgua -ne $diaAhora) {
                $script:charlaAgua = $diaAhora
                Say "Oye, ya van tres horas seguidas. Un vaso de agua no vendria mal."
            }
            if ($minutoAhora -ge '01:00' -and $minutoAhora -le '01:05' -and $script:charlaTarde -ne $diaAhora) {
                $script:charlaTarde = $diaAhora
                Say "Es la una de la manana. ¿Seguimos, o lo dejamos por hoy?"
            }
        }
    }

    # --- vibracion del mando (patron en curso) ---
    if ($script:vibraCola.Count -gt 0 -or $script:vibraHasta -gt 0) { Tick-Vibracion }

    # --- acelerometro (cada 250 ms) y logros de Steam (con el juego) ---
    if ($script:acelerometro -and ($sw.ElapsedMilliseconds - $script:acelCheck) -ge 250) { $script:acelCheck = $sw.ElapsedMilliseconds; Watch-Acelerometro }

    # --- carga de CPU (cada 30 s): la capsula se agita si va al limite ---
    if (($sw.ElapsedMilliseconds - $script:cargaCheck) -ge 30000) {
        $script:cargaCheck = $sw.ElapsedMilliseconds
        try {
            $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average).Average
            if ($null -ne $cpu) {
                $cpu = [int]$cpu
                if ([Math]::Abs($cpu - $script:uiCarga) -ge 10 -or (($cpu -ge 85) -ne ($script:uiCarga -ge 85))) { $script:uiCarga = $cpu; Refresh-UI }
            }
        } catch {}
    }

    # --- el tiempo (una vez por hora; la primera, a los 20 s de arrancar) ---
    if ($ClimaOn -and ($sw.ElapsedMilliseconds - $script:climaCheck) -ge 3600000 -and $sw.ElapsedMilliseconds -ge 20000) {
        $script:climaCheck = $sw.ElapsedMilliseconds
        Update-Clima
    }

    # --- aviso proactivo de bateria (se comprueba una vez por minuto) ---
    if (($sw.ElapsedMilliseconds - $script:bateriaCheck) -ge 60000) {
        $script:bateriaCheck = $sw.ElapsedMilliseconds
        try {
            $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($bat -and $bat.EstimatedChargeRemaining) {
                $pc = [int]$bat.EstimatedChargeRemaining
                $cargando = ($bat.BatteryStatus -eq 2)   # 2 = conectado a la red
                # la insignia de la capsula avisa por debajo del 20 % y
                # celebra la carga
                $cg = if ($cargando) { 1 } else { 0 }
                if ($pc -ne $script:uiBateria -or $cg -ne $script:uiCargando) {
                    $script:uiBateria = $pc; $script:uiCargando = $cg
                    Refresh-UI
                }
                if (-not $cargando) { Invoke-Reglas 'bateria' ([string]$pc) }
                if (-not $cargando -and $pc -le $BateriaAviso -and -not $script:bateriaAvisada) {
                    $script:bateriaAvisada = $true
                    Log "AVISO: bateria al $pc %"
                    Show-Popup "Bateria al $pc por ciento."
                    Say "Oye, te queda $pc por ciento de bateria."
                    Send-UIEvento 'aviso'
                }
                # rearmar cuando se recupera, para que pueda volver a avisar
                if ($cargando -or $pc -gt ($BateriaAviso + 10)) { $script:bateriaAvisada = $false }
            }
        } catch {}
    }

    # cierra el popup al vencer su plazo (antes se esperaba 8 s bloqueando)
    if ($script:popupUntil -gt 0 -and $sw.ElapsedMilliseconds -ge $script:popupUntil) {
        Close-Popup
    }

    # el tiempo vuelve a ser la carita al vencer su plazo
    if ($script:uiClimaHasta -gt 0 -and $sw.ElapsedMilliseconds -ge $script:uiClimaHasta) {
        $script:uiClimaHasta = 0
        $script:uiClima = ''
        Refresh-UI
    }

    # --- INTERFAZ: vuelta al reposo y vigilancia del proceso ---
    if ($script:uiHasta -gt 0 -and $sw.ElapsedMilliseconds -ge $script:uiHasta) {
        # solo si no hay nada en marcha: escuchando o pensando mandan
        if (-not $script:armed -and -not $script:busy) { Set-UI 'reposo' } else { $script:uiHasta = 0 }
    }
    if ($UiNuevaOn -and ($sw.ElapsedMilliseconds - $script:uiCheck) -ge 30000) {
        $script:uiCheck = $sw.ElapsedMilliseconds
        if ($script:uiProc -and $script:uiProc.HasExited) {
            if ($script:uiIntentos -lt 3) {
                $script:uiIntentos++
                Log "WARN: la interfaz murio; relanzando (intento $($script:uiIntentos)/3)"
                try { $script:uiProc.Dispose() } catch {}
                $script:uiProc = $null
                Initialize-UI
            } elseif ($script:uiIntentos -eq 3) {
                $script:uiIntentos++
                Log "ERROR: la interfaz no se sostiene; vuelve la barra antigua"
                $script:UiNuevaOn = $false
                $capture.Opacity = 1
            }
        } elseif ($script:uiProc) {
            $script:uiIntentos = 0
        }
    }

    $startPrev = $startNow
    Start-Sleep -Milliseconds 30
}