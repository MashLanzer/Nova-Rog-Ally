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
$VERBOS = '(?:abre|abreme|abrele|abrir|abri|abrime|ejecuta|ejecutame|inicia|iniciame|lanza|lanzame|arranca|arrancame|prende|prendeme|pon|ponme|poneme|ponele|pone|mete|metete|entra|entrate|anda|andate|ve|vete|llevame|muestrame|ensename|busca|buscame|buscar|busque|googlea|googleame|investiga|sube|subele|subir|aumenta|baja|bajale|bajar|reduce|silencia|silenciar|mutea|pausa|pausar|reproduce|reproducir|play|siguiente|anterior|bloquea|bloquear|cierra|apaga)'

# Muletillas y cortesias que el dictado captura pero que NO son parte de la
# orden. "busca tambien en el navegador X" fallaba justo por esto.
$FILLER_GLOBAL = '\b(?:tambien|ademas|porfa|porfavor|por favor|gracias|oye|okey|dale|a ver|quiero que|necesito que|me puedes|puedes|podrias|hazme el favor de)\b'
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

function Split-Compound([string]$s) {
    # "ademas"/"tambien" son SEPARADORES si les sigue un verbo de accion, y
    # simples muletillas si no. Confundir ambos casos era lo que metia
    # "...ADEMAS sube el volumen" dentro de la busqueda anterior.
    $limpio = [regex]::Replace($s, '\b(?:ademas|tambien)\s+(?=' + $VERBOS + '\b)', ' | ')
    $limpio = Remove-Filler $limpio
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

# El dictado deforma los nombres sin parar ("Team", "steamidos", "espotifai").
# Perseguirlos uno a uno con una lista fija es una carrera perdida: aqui se
# acepta la clave conocida que aparezca dentro de lo dictado, o la que quede
# a pocas ediciones de distancia.
function Find-Aproximado([string]$t, $obj) {
    if (-not $obj -or -not $t) { return $null }
    $mejor = $null
    $mejorD = 999
    foreach ($p in $obj.PSObject.Properties) {
        $k = $p.Name
        if ($k.Length -ge 4 -and $t -match ('\b' + [regex]::Escape($k))) { return $k }
        $tope = [Math]::Max(1, [int][Math]::Floor($k.Length * 0.34))
        $d = Get-Distancia $t $k
        if ($d -le $tope -and $d -lt $mejorD) { $mejorD = $d; $mejor = $k }
    }
    # a dos o mas letras de distancia ya no es seguro: se marca para confirmar
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
        if ($n.Contains($q) -or $q.Contains($n)) {
            $puntos = [Math]::Abs($n.Length - $q.Length)
        } else {
            $d = Get-Distancia $q $n
            $tope = [Math]::Max(2, [int][Math]::Floor($n.Length * 0.35))
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

        $rutas = @('local', 'aprendida', 'memoria', 'pregunta', 'traducir', 'traducida', 'accion', 'charla', 'descarte')
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# Estadísticas del asistente")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Actualizado: " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ". La genera el asistente sola; no hace falta editarla.")
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
        [void]$sb.AppendLine("## No reconocido por la capa local (añadir a commands.json)")
        [void]$sb.AppendLine("")
        if ($s.descartes.Count -eq 0) { [void]$sb.AppendLine("_nada todavía_") }
        foreach ($x in $s.descartes) { [void]$sb.AppendLine("- " + $x) }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Últimas órdenes")
        [void]$sb.AppendLine("")
        foreach ($x in $s.recientes) { [void]$sb.AppendLine("- " + $x) }
        [System.IO.File]::WriteAllText($EstadisticasMd, $sb.ToString(), $enc)
    } catch { Log ("estadisticas: " + $_.Exception.Message) }
}

function Resolve-Fragment([string]$f) {
    # --- perfiles: una frase, varias acciones ("modo juego") ---
    if ($f -match '^(?:modo|activa el modo|pon el modo|ponte en modo)\s+(.+)$') {
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
    if ($f -match '^(?:recuerda|recuerdame|acuerdate|anota|apunta|guarda|memoriza)\s+(?!en\s+\d+\s*(?:segundo|minuto|hora))(?:que\s+|de\s+que\s+)?(.+)$') {
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
        '^(?:cuanta bateria|cuanta pila|nivel de bateria|como esta la bateria)\b' {
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
    # --- captura y grabacion (atajos de la barra de juego de Windows) ---
    switch -regex ($f) {
        '^(?:toma (?:una )?captura|captura (?:de )?pantalla|screenshot|pantallazo)$' {
            return @(@{ kind = 'winprt'; desc = 'captura de pantalla' })
        }
        '^(?:graba|grabar|clip|guarda el clip|graba los ultimos)\b' {
            return @(@{ kind = 'winaltg'; desc = 'grabar los ultimos segundos' })
        }
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
    return (Resolve-Target $f)
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
    $script:deshacer = @{ brillo = $b; procesos = New-Object System.Collections.ArrayList }
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
    $script:deshacer = $null
    if ($hecho.Count -eq 0) { return "No pude deshacerlo: el volumen y las apps de Steam no se pueden revertir" }
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
    if ($text -match '(?i)^\s*(?:recu[eé]rdame|recuerda|acu[eé]rdate|anota|apunta|guarda|memoriza)\s+(?!en\s+\d+\s*(?:segundo|minuto|hora))(?:que\s+|de\s+que\s+)?(.+)$') {
        $frase = $Matches[1].Trim()
        if ($frase.Length -gt 0) {
            $null = Add-Memoria $frase
            Log "MEMORIA: $frase"
            return "Anotado."
        }
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
    if ($ConfirmacionOn -and $script:dudosa -and -not $script:confirmado) {
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
                    # con -PassThru para poder cerrarlo si pides deshacer; las
                    # URI (steam://, shell:appsFolder) no devuelven proceso propio
                    $pr = Start-Process $a.target -PassThru -ErrorAction Stop
                    if ($pr -and $script:deshacer) { [void]$script:deshacer.procesos.Add($pr.Id) }
                    if ($a.target -match 'msedge|chrome|firefox') { $navegador = $a.target }
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
        # se avisa justo antes de reproducir para que vayan sincronizados
        $script:uiAudio = $ruta
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
# 'vosk' y 'whisper' comparten el camino: el worker de escucha graba la orden
# y la transcribe (Whisper es mucho mas preciso; Vosk pequeno se queda para
# la palabra de activacion). 'windows' es Win+H.
$DictadoWorker = ($MotorDictado -in @('vosk', 'whisper'))
$WhisperModelo = [string](Get-Cfg 'input' 'whisperModelo' 'small')
$MarcaDictar = Join-Path $TmpDir "dictar.flag"
# confirmacion por voz de coincidencias dudosas: el worker escucha si/no
$MarcaConfirmar = Join-Path $TmpDir "confirmar.flag"
$RutaConfirmacion = Join-Path $TmpDir "confirmacion.txt"
# vocabulario (apps, sitios, juegos) para que Whisper acierte los nombres
$RutaVocabulario = Join-Path $TmpDir "vocabulario.txt"
$RutaDictado = Join-Path $TmpDir "dictado.txt"
$RutaParcial = Join-Path $TmpDir "dictado-parcial.txt"
# nivel de voz 0..1 que el worker escribe mientras dictas; lo lee la interfaz
# directamente (nova_ui.exe busca ui-nivel.txt junto a ui-estado.json)
$RutaNivel = Join-Path $TmpDir "ui-nivel.txt"
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
            $script:wakeProc = Start-Process -FilePath $PyExe `
                -ArgumentList @('-u', $worker, $EscuchaNombre, $MarcaWake, $EventLog, $EscuchaGanancia,
                                $MarcaPausa, $MarcaDictar, $RutaDictado, $RutaParcial, $RutaNivel,
                                $MarcaConfirmar, $RutaConfirmacion, "$MotorDictado`:$WhisperModelo", $RutaVocabulario) `
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
            ',"perfil":"' + $script:uiPerfil + '"}'
    if ($json -ne $script:uiUltimo) {
        # UTF-8 SIN BOM: la interfaz lo lee tal cual y el BOM colaria un caracter
        try { [System.IO.File]::WriteAllText($RutaUiEstado, $json, (New-Object System.Text.UTF8Encoding $false)) } catch {}
        $script:uiUltimo = $json
    }
    $script:uiHasta = if ($ms -gt 0) { $sw.ElapsedMilliseconds + $ms } else { 0 }
}

# Dispara una animacion sin cambiar el estado (el estado se reescribe igual).
function Send-UIEvento([string]$evento) {
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

function Enter-Juego([string]$nombre) {
    $script:juegoAvisado = $false
    $script:juegoHoras = 0
    $script:juegoBrilloAntes = $null
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
    if (-not $JuegoRestaurar -or $null -eq $script:juegoBrilloAntes) { return }
    try {
        Set-Brillo ([int]$script:juegoBrilloAntes)
        Log "JUEGO: brillo restaurado a $($script:juegoBrilloAntes) al salir de $nombre"
    } catch {}
    $script:juegoBrilloAntes = $null
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
        $argLine = "run --auto" + $extraArg + " --dir " + (ConvertTo-CmdArg $WORKDIR) + " -- " + (ConvertTo-CmdArg $msg)
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
$PRE_HABLADO = 'Responde SOLO con palabras, breve (una o dos frases), en espanol, sin usar herramientas y sin ejecutar nada. '

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
ninguna palabra extra. Si la orden no encaja en ninguna forma, responde
exactamente: NO

Orden del usuario: $text
"@
}

function Submit-Command([string]$text, [string]$modo = 'accion') {
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
        if ($propuesta -and $propuesta.ToUpperInvariant() -ne 'NO' -and $propuesta.Length -lt 120) {
            Log "traduccion propuesta: '$original' -> '$propuesta'"
            $r = $null
            # una traduccion del modelo no se confirma por voz: o encaja o no
            $script:confirmado = $true
            try { $r = Invoke-FastCommand $propuesta } catch { $r = $null }
            $script:confirmado = $false
            if ($r) {
                Add-Traduccion $original $propuesta
                Add-Estadistica 'traducida' "$original -> $propuesta"
                $script:ultimaRespuesta = $r
                Send-UIEvento 'hecho'
                Show-Popup $r
                Say $r
                return
            }
            Log "la traduccion no resulto ejecutable; va al agente completo"
        } else {
            Log "el modelo no supo traducirlo; va al agente completo"
        }
        # no se pudo traducir: se manda al agente con todas sus herramientas
        Submit-Command $original 'accion'
        return
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
    Show-Popup $reply
    Say $reply
}

# --- confirmacion por voz ---
$ConfirmacionOn = [bool](Get-Cfg 'confirmacion' 'activada' $true)
$ConfirmacionMs = [int](Get-Cfg 'confirmacion' 'esperaMs' 3500)
$script:pendiente = $null
$script:confirmado = $false
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
    if ($respuesta -eq 'no') {
        Log "CONFIRMAR: cancelado por el usuario"
        Set-UI 'error' 'Vale, cancelado' 2000
        Say "Vale."
        return
    }
    Log "CONFIRMAR: $respuesta -> se ejecuta '$($p.texto)'"
    $script:confirmado = $true
    try { Process-Texto $p.texto } finally { $script:confirmado = $false }
}

# Abre el dictado. La llaman el boton y la palabra de activacion, para que
# ambos caminos se comporten EXACTAMENTE igual.
function Start-Dictado([string]$origen) {
    Log "DICTADO ($origen)"
    # con la capsula, el sonido lo pone ella (un tono corto, no la campana)
    if (-not $UiNuevaOn) { [System.Media.SystemSounds]::Exclamation.Play() }

    # --- Dictado por Vosk: ni foco, ni Win+H, ni pausa de escucha ---
    # El worker ya tiene el microfono; solo hay que decirle que transcriba.
    if ($DictadoWorker -and $script:wakeProc) {
        Remove-Item -LiteralPath $RutaDictado -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $RutaParcial -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText($MarcaDictar, 'x')
        $lbl.Text = "● VOZ..."
        $lbl.ForeColor = [System.Drawing.Color]::LimeGreen
        $capture.Show()
        Set-UI 'escuchando'
        Send-UIEvento 'despierta'
        $script:armed = $true
        $script:dictaInicio = $sw.ElapsedMilliseconds
        return
    }

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
            Submit-Command $sinPrefijo 'charla'
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
            # 4) que el modelo la traduzca a una orden conocida (~13 s) y se
            #    aprenda; si no encaja, cae al agente completo
            if ($script:ultimoDescarte) { Add-Estadistica 'descarte' $script:ultimoDescarte; $script:ultimoDescarte = '' }
            if ($TraducirOn) { Submit-Command $text 'traducir' }
            else { Submit-Command $text }
        }
    } else {
        # antes esto era mudo: no distinguias "fallo" de "no dije nada"
        Log "vacio, ignorado"
        if (-not $UiNuevaOn) { [System.Media.SystemSounds]::Hand.Play() }
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
                [System.Media.SystemSounds]::Hand.Play()
                Stop-OpencodeJob
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
                if ($lbl.Text -ne $nuevo) { $lbl.Text = $nuevo; Set-UI 'escuchando' $vista }
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
            Process-Texto ($dic.Trim())
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
        } elseif ($actual.Trim().Length -gt 0 -and ($sw.ElapsedMilliseconds - $script:lastChange) -ge $AutoSubmitMs) {
            try { Finish-Dictation "silencio" }
            catch { Log "auto-envio error: $($_.Exception.Message)"; $script:armed = $false }
        }
    }

    # --- atencion al trabajo en curso, sin bloquear el sondeo del boton ---
    if ($script:busy -and $script:proc) {
        if ($script:proc.HasExited) {
            Report-Reply (Complete-OpencodeJob)
        } elseif (($sw.ElapsedMilliseconds - $script:jobStart) -ge $CliTimeoutMs) {
            Log "RUNNER timeout tras $([Math]::Round($CliTimeoutMs/1000)) s"
            Stop-OpencodeJob
            Show-Popup "(timeout: opencode tardo mas de $([Math]::Round($CliTimeoutMs/1000)) s)" 'error'
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
                } else {
                    $script:juegoExe = ''
                }
                $script:juegoActivo = $j
                Refresh-UI   # la capsula cambia de avatar
            } elseif ($j) {
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