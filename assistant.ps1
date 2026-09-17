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
# EL LOG NO CRECE SIN FIN (14/09): nunca se rotaba e iba por 1,3 MB en cuatro dias.
# Al arrancar, pasados 5 MB se guarda como assistant.log.1 (el anterior se pierde) y
# se empieza otro. Con -Probar no se toca: el banco no debe mover el log real.
if (-not $Probar) {
    try {
        if ((Test-Path -LiteralPath $EventLog) -and (Get-Item -LiteralPath $EventLog).Length -gt 5MB) {
            Move-Item -LiteralPath $EventLog -Destination "$EventLog.1" -Force
        }
    } catch {}
}
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
$VERBOS = '(?:abre|abreme|abrele|abrir|abri|abrime|ejecuta|ejecutame|inicia|iniciame|lanza|lanzame|arranca|arrancame|prende|prendeme|pon|ponme|poneme|ponele|pone|mete|metete|entra|entrate|anda|andate|ve|vete|llevame|muestrame|muestra|ensename|busca|buscame|buscar|busque|googlea|googleame|investiga|sube|subele|subir|aumenta|baja|bajale|bajar|reduce|silencia|silenciar|mutea|pausa|pausar|reproduce|reproducir|play|siguiente|anterior|bloquea|bloquear|cierra|cierrame|cierrate|apaga|escribe|escribeme|teclea|pulsa|presiona|aprieta|dale a|cambia|cambiate|pasate|copia|pega|selecciona|guarda|minimiza|maximiza|enfoca|manda|envia|mueve|restaura|restaurar)'

# Muletillas y cortesias que el dictado captura pero que NO son parte de la
# orden. "busca tambien en el navegador X" fallaba justo por esto.
$FILLER_GLOBAL = '\b(?:tambien|ademas|porfa|porfavor|por favor|gracias|oye|okey|dale(?!\s+al?\b)|a ver|quiero que|necesito que|me puedes|puedes|podrias|hazme el favor de)\b'
# "a mi"/"ya me"/"me" salen mucho al dictar ("ya me abre steam", "ábreme")
# "hey nova pon modo juego" se iba a la IA: el nombre y el saludo de delante no
# son parte de la orden (auditoria del 13/09)
$FILLER_INI = '^(?:(?:y|luego|despues|ahora|entonces|a mi|ami|ya me|me|pues|este|hey|ey|hola|nova)\s+)+'

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

# VERBOS DE CABEZA QUE ESTE MICROFONO SE COME. Lista cerrada, y cada entrada
# sale de las 20 grabaciones del 12/09, no de suponer: "pon modo noche" se oye
# "CON el modo noche" y "pon el juego al ochenta" se oye "CON el juego al 80".
# Va aparte de la correccion por distancia porque "con" tiene tres letras y esa
# no toca palabras cortas -y hace bien: a distancia 1, cualquier palabra corta
# del castellano se convierte en un verbo y acaba ejecutandose.
# Solo se aplica a la PRIMERA palabra y solo si hay algo detras.
$VERBOS_OIDOS = @{
    'con'   = 'pon'      # pon modo noche -> con el modo noche
    'pongo' = 'pon'      # abre steam y pon modo juego -> ... y pongo modo juego
    'lea'   = 'lee'      # lee la pantalla -> lea la pantalla
    'aure'  = 'abre'     # abre elden ring -> aure el ring (tanda dirigida, 14/09)
    'aura'  = 'abre'     # abre peak -> aura pic
    'sierra' = 'cierra'  # cierra discord -> sierra discord (ya lo pillaba por
                         # distancia, pero asi no depende de ella)
}

# EL VERBO DE CABEZA, EN IMPERATIVO (15/09). Cada regla enumera sus propias formas
# ("pon|ponme|reproduce|..."), y por eso "poner un temporizador de cinco minutos",
# "pone el modo noche" o "reproducir lofi en youtube" no encajaban en ninguna y se
# iban al modelo (34 s), mientras que "pon un temporizador de cinco minutos" tardaba
# 2 s. Normalizando aqui una sola vez, TODAS las reglas los entienden.
# Solo la primera palabra y solo si hay algo detras, como el resto de esta funcion:
# un verbo suelto casi nunca es una orden, y sonando el altavoz es ruido.
$VERBOS_IMPERATIVO = @{
    'poner' = 'pon'; 'pone' = 'pon'; 'ponerme' = 'ponme'
    'abrir' = 'abre'; 'cerrar' = 'cierra'; 'iniciar' = 'inicia'; 'lanzar' = 'lanza'
    'ejecutar' = 'ejecuta'; 'arrancar' = 'arranca'; 'buscar' = 'busca'; 'googlear' = 'googlea'
    'subir' = 'sube'; 'bajar' = 'baja'; 'aumentar' = 'aumenta'; 'reducir' = 'reduce'
    'silenciar' = 'silencia'; 'pausar' = 'pausa'; 'reproducir' = 'reproduce'
    'apagar' = 'apaga'; 'encender' = 'enciende'; 'activar' = 'activa'; 'desactivar' = 'desactiva'
    'quitar' = 'quita'; 'escribir' = 'escribe'; 'teclear' = 'teclea'; 'grabar' = 'graba'
    'cortar' = 'corta'; 'mover' = 'mueve'; 'instalar' = 'instala'; 'cambiar' = 'cambia'
    'minimizar' = 'minimiza'; 'maximizar' = 'maximiza'; 'bloquear' = 'bloquea'
    'guardar' = 'guarda'; 'copiar' = 'copia'; 'leer' = 'lee'; 'enviar' = 'envia'
    'mandar' = 'manda'; 'crear' = 'crea'; 'avisar' = 'avisa'; 'mostrar' = 'muestra'
    # subjuntivo: asi se dicen las correcciones ("lo que dije fue que ABRIERAS el juego")
    'abras' = 'abre'; 'abrieras' = 'abre'; 'cierres' = 'cierra'; 'cerraras' = 'cierra'
    'pongas' = 'pon'; 'pusieras' = 'pon'; 'busques' = 'busca'; 'buscaras' = 'busca'
    'reproduzcas' = 'reproduce'; 'subas' = 'sube'; 'bajes' = 'baja'; 'quites' = 'quita'
    'escribas' = 'escribe'; 'hicieras' = 'haz'; 'inicies' = 'inicia'; 'iniciaras' = 'inicia'
}

# El dictado deforma tambien los verbos ("buscal" por "busca"). Se corrige solo
# la PRIMERA palabra y solo a distancia 1, para no inventar ordenes.
function Repair-Verb([string]$f) {
    if (-not $f) { return $f }
    $partes = $f -split '\s+', 2
    if ($partes.Count -gt 1 -and $VERBOS_OIDOS.ContainsKey($partes[0])) {
        return ($VERBOS_OIDOS[$partes[0]] + ' ' + $partes[1])
    }
    if ($partes.Count -gt 1 -and $VERBOS_IMPERATIVO.ContainsKey($partes[0])) {
        return ($VERBOS_IMPERATIVO[$partes[0]] + ' ' + $partes[1])
    }
    # UNA PALABRA SUELTA NO SE REPARA. Al hacerlo, una palabra cualquiera del
    # castellano se convertia en verbo y, ya reconocida, se ejecutaba saltandose
    # el filtro de ruido (que solo actua cuando la capa local NO entiende):
    # 'pesa' -> 'pega' -> Ctrl+V en lo que tuvieras delante, 'copla' -> Ctrl+C,
    # 'guardia' -> Ctrl+S, 'pasa' -> pausa. Son palabras que salen del altavoz
    # todo el rato. Un verbo solo, sin objeto, casi nunca es una orden util.
    if ($partes.Count -lt 2) { return $f }
    $primera = $partes[0]
    if ($primera.Length -lt 4 -or ($VERBOS_LISTA -contains $primera)) { return $f }
    # "pasa la musica" es "siguiente", ya tiene su orden: corregirlo a "pausa"
    # la paraba (auditoria del 13/09)
    # "pasame la lista" tampoco: se "corregia" a otro verbo y no llegaba a su orden
    if ($primera -in 'pasa', 'pasala', 'pasame', 'salta') { return $f }
    # "describe mi fondo de pantalla" se corregia a "escribe ..." y TECLEABA el texto en la
    # ventana que hubiera delante (15/09)
    if ($primera -match '^(?:describe|describeme|describir|describelo|describela)$') { return $f }
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

# ¿Es esto, tal cual, algo que sabemos abrir? Sin parecidos ni
# aproximaciones: aqui solo vale el nombre exacto, porque se usa para
# decidir si un trozo suelto es una orden por si mismo.
function Test-NombreConocido([string]$t) {
    if (-not $cmds -or -not $t) { return $false }
    if (Test-Prop $cmds.apps $t) { return $true }
    if (Test-Prop $cmds.sitios $t) { return $true }
    $p = ConvertTo-Juego $t
    foreach ($j in @($script:Juegos)) { if ($j.plano -eq $p) { return $true } }
    return $false
}

# Punto unico de entrada para partir una frase en ordenes.
# SE PROBO separar tambien por comas y hubo que revertirlo: el dictado las
# pone donde le parece ("Sierra, el navegador", "Abre, steam, y busca los
# huevos"), asi que la coma no dice nada sobre donde acaba una orden y
# partir por ella tiraba cinco ordenes reales del log. Lo que si funciona
# esta abajo, en Resolve-Target: varios nombres conocidos seguidos.
function Split-Ordenes([string]$texto) {
    $planoS = ConvertTo-Plain $texto
    # "en youtube busca gatos" es "busca gatos en youtube" (14/09): si no, se partia
    # en "abrir youtube" + "buscar gatos en Google"
    if ($planoS -match '^en\s+(youtube|google|pinterest|bing|amazon|wikipedia|twitch|reddit|github)\s*,?\s+(busca|buscame|buscar|googlea|pon|ponme|reproduce)\s+(.+)$') {
        # los grupos, a variables YA: el -match de abajo pisaria $Matches
        $sitioS = $Matches[1]; $verboS = $Matches[2]; $queS = $Matches[3]
        $planoS = if ($verboS -match '^(?:pon|ponme|reproduce)$') { "$verboS $queS en $sitioS" } else { "busca $queS en $sitioS" }
    }
    # "abrir el steam y en una segunda ventana buscar pinterest" (14/09): que sea en
    # otra ventana o pestana no cambia nada (se abre aparte igual), y en medio partia
    # mal la frase. Se quita.
    if ($planoS -match '\ben\s+(?:una|otra)\s+(?:segunda\s+|nueva\s+)?(?:ventana|pestana)\b') {
        $planoS = [regex]::Replace($planoS, '\s*(?:\by\s+)?\ben\s+(?:una|otra)\s+(?:segunda\s+|nueva\s+)?(?:ventana|pestana)\b\s*', ' y ')
        $planoS = (($planoS -replace '^\s*y\s+', '') -replace '\s+y\s*$', '' -replace '\s+', ' ').Trim()
    }
    return (Split-Compound (Repair-Words $planoS))
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
        # DOS NOMBRES SEGUIDOS (auditoria del 13/09): el dictado quita las comas,
        # asi que "cierra spotify, discord y steam" llega como "cierra spotify
        # discord" + "steam", y Discord se perdia. Si lo de detras del verbo no es
        # un nombre pero se parte en dos que si lo son, son dos ordenes.
        if ($t -match ('^(' + $VERBOS + ')\s+(.+)$')) {
            $vbD = $Matches[1]; $objD = $Matches[2]
            $pwD = @($objD -split '\s+')
            if ($pwD.Count -ge 2 -and -not (Test-NombreConocido $objD)) {
                for ($c = 1; $c -lt $pwD.Count; $c++) {
                    $izqD = ($pwD[0..($c - 1)] -join ' '); $derD = ($pwD[$c..($pwD.Count - 1)] -join ' ')
                    if ((Test-NombreConocido $izqD) -and (Test-NombreConocido $derD)) { [void]$res.Add("$vbD $izqD"); $t = "$vbD $derD"; break }
                }
            }
        }
        # ¿El fragmento anterior se quedo en un verbo suelto? Entonces esto es
        # su objeto, venga como venga. El dictado puntua a su antojo: "Sierra,
        # el navegador" o "Abre, steam, y busca los huevos" son UNA orden con
        # comas de adorno, y partirlas ahi dejaba "cierra" y "abre" sin nada
        # que hacer, con lo que se perdia la frase entera por la regla de
        # todo-o-nada.
        $colgando = $false
        if ($res.Count -gt 0) {
            $ult = [string]$res[$res.Count - 1]
            if (@($ult -split '\s+').Count -eq 1 -and ($VERBOS_LISTA -contains $ult)) { $colgando = $true }
        }
        # "cierra todos los programas menos steam Y discord": lo que sigue a una
        # EXCEPCION es parte de ella, aunque sea un nombre conocido. Se partia en
        # "cerrar todo menos steam" + "abrir discord" (12/09): justo lo contrario
        # de lo pedido.
        $enExcepcion = ($res.Count -gt 0 -and ([string]$res[$res.Count - 1]) -match '\b(?:menos|excepto|salvo|quitando)\b' -and
                        $t -notmatch ('^(?:' + $VERBOS + ')\b'))
        if ($res.Count -gt 0 -and ($colgando -or $enExcepcion -or ($t -notmatch ('^' + $LOCATIVO + '?(?:' + $VERBOS + '|' + $VENTANA + ')\b') -and
            -not (Test-NombreConocido $t)))) {
            # ... SALVO que el trozo sea algo que sabemos abrir. "abre steam y
            # discord" se pegaba entero y acababa abriendo SOLO Steam: dentro
            # de "steam y discord" se encontraba "steam" y el resto se tiraba
            # sin avisar. Eso rompe la regla de todo-o-nada, y de la peor
            # manera: pediste dos cosas y pasaba una, en silencio.
            # no empieza por verbo: pertenece al fragmento anterior
            # ("busca gatos y perros en google")
            $res[$res.Count - 1] = $res[$res.Count - 1] + ' y ' + $t
        } else {
            # UN NOMBRE SUELTO HEREDA EL VERBO (auditoria del 13/09): en "cierra
            # steam y discord" el trozo "discord" iba solo, y un nombre solo es
            # "abrelo": cerraba Steam y ABRIA Discord. Ahora es "cierra discord".
            if ($res.Count -gt 0 -and $t -notmatch ('^' + $LOCATIVO + '?(?:' + $VERBOS + '|' + $VENTANA + ')\b')) {
                $verboPrev = ([string]$res[$res.Count - 1] -split '\s+')[0]
                if ($VERBOS_LISTA -contains $verboPrev) { $t = "$verboPrev $t" }
            }
            # WHISPER REPITE (14/09): con audio flojo devuelve la frase dos veces,
            # "cierra el discord, cierra el discord", y se hacia dos veces. Una
            # orden identica justo detras de si misma es eco, salvo las que se
            # repiten a proposito para dar pasos ("sube el volumen, sube el volumen").
            if ($res.Count -gt 0 -and ([string]$res[$res.Count - 1]) -eq $t -and
                $t -notmatch '^(?:sube|subir|subele|baja|bajar|bajale|aumenta|reduce|siguiente|anterior|pasa|salta|adelanta|atrasa|retrocede)\b') { continue }
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
# ESCRITURA ATOMICA (14/09): los JSON de memoria se escribian directamente, y un
# apagon o la bateria a cero a mitad dejaba el archivo a medias (el .corrupto
# evitaba perderlo todo, no el destrozo). Ahora se escribe un .tmp y se cambia
# por el bueno de una vez: o esta el viejo entero o el nuevo entero.
function Write-Atomico([string]$ruta, [string]$texto, [bool]$bom = $false) {
    $tmp = "$ruta.tmp"
    [System.IO.File]::WriteAllText($tmp, $texto, (New-Object System.Text.UTF8Encoding($bom)))
    if (Test-Path -LiteralPath $ruta) {
        try { [System.IO.File]::Replace($tmp, $ruta, $null); return } catch {}
    }
    Move-Item -LiteralPath $tmp -Destination $ruta -Force
}

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

# RECITADO DE LA FRASE DE EJEMPLO (15/09). Con casi silencio en una ventana de seguimiento
# Whisper devolvio su frase de ejemplo entera ("Sube el volumen. Pon el modo noche. ¿Que hora
# es? Baja el brillo.") y se puso el volumen al 35 y se bajo el brillo sin que nadie lo
# pidiera. Nadie da asi varias ordenes del ejemplo: dos o mas frases DISTINTAS de la frase
# de ejemplo son un recitado, no una orden. En las 214 grabaciones solo paso dos veces y
# ninguna era una orden de verdad (ruido y "busca gatos en youtube" mal oido). La frase se
# lee de wake_vosk.py (PROMPT_ORDENES) para no tener dos copias que se desincronicen.
$script:frasesEjemplo = $null
function Get-FrasesEjemplo {
    if ($null -ne $script:frasesEjemplo) { return $script:frasesEjemplo }
    $script:frasesEjemplo = @()
    try {
        $rutaW = if ($RutaWakeVosk) { $RutaWakeVosk } else { Join-Path $PSScriptRoot 'wake_vosk.py' }
        $src = [System.IO.File]::ReadAllText($rutaW, [System.Text.Encoding]::UTF8)
        if ($src -match '(?m)^PROMPT_ORDENES\s*=\s*"([^"]+)"') {
            $script:frasesEjemplo = @(($Matches[1] -split '[.?¿!]+') |
                ForEach-Object { (ConvertTo-Plain $_) -replace '^(?:oye |hey |ey )?nova ?', '' } |
                Where-Object { $_ } | Select-Object -Unique)
        }
    } catch {}
    return $script:frasesEjemplo
}
# UNA SOLA FRASE DEL EJEMPLO (16/09). Test-RecitaEjemplo pide DOS partes, porque se
# hizo para el recitado entero. Pero el repaso cuela de una en una: medido con las 214
# grabaciones leidas, las 4 ordenes equivocadas graves del camino actual son esto
# ("sube el volumen" se repaso como "¿Que hora es" y Nova dijo la hora). Cuando el
# repaso trae UNA frase del ejemplo y lo primero no se le parecia, no vale.
function Test-EsFraseEjemplo([string]$texto) {
    $frases = @(Get-FrasesEjemplo)
    if ($frases.Count -eq 0 -or -not $texto) { return $false }
    $pl = (ConvertTo-Plain $texto) -replace '^(?:oye |hey |ey )?nova ?', ''
    if (-not $pl) { return $false }
    foreach ($f in $frases) {
        $largo = [Math]::Max($pl.Length, $f.Length)
        if ($largo -gt 0 -and (1.0 - (Get-Distancia $pl $f) / $largo) -ge 0.85) { return $true }
    }
    return $false
}

function Test-RecitaEjemplo([string]$texto) {
    $frases = @(Get-FrasesEjemplo)
    if ($frases.Count -eq 0 -or -not $texto) { return $false }
    $vistas = @{}
    $partesEco = 0
    foreach ($parte in ($texto -split '[.?¿!,;]+')) {
        $pl = (ConvertTo-Plain $parte) -replace '^(?:oye |hey |ey )?nova ?', ''
        if (-not $pl) { continue }
        foreach ($f in $frases) {
            $largo = [Math]::Max($pl.Length, $f.Length)
            # "abra steam" tambien es "abre steam": parecido de 0,8 o mas
            if ((1.0 - (Get-Distancia $pl $f) / $largo) -ge 0.8) { $vistas[$f] = 1; $partesEco++; break }
        }
    }
    # tambien la MISMA repetida (15/09): "cierra steam" se oyo "¿Que hora es? ¿Que hora es"
    # y acabo en la charla contestando que no sabe la hora
    return ($partesEco -ge 2)
}

# PARAKEET PARA LO QUE NO ES UNA ORDEN (15/09). En la segunda sesion de uso real,
# Parakeet oyo bien frases largas que Whisper base destrozo, y se seguia con lo de base:
# "ahora por favor abre youtube y reproduce musica de Pitbull" -> "abre y duro y
# reproducente en musica de Pipboon"; "que pongan musica en YouTube" -> "que ponga
# muzigen" (y se aprendio); "borra eso" -> "baja eso". En 27 frases de uso donde no
# coincidian, Parakeet acerto claramente en ~16 y base solo en 3 ordenes cortas que
# base SI entiende como orden. Por eso: si Whisper saca una orden, vale Whisper; si
# no, se sigue con Parakeet cuando lo suyo es una frase en espanol (4+ palabras).
function Test-EspanolLargo([string]$t) {
    if (-not $t) { return $false }
    $pal = @(((ConvertTo-Plain $t) -split '\s+') | Where-Object { $_ })
    if ($pal.Count -lt 4) { return $false }
    foreach ($ch in $t.ToCharArray()) { if ([char]::IsLetter($ch) -and [int]$ch -ge 0x250) { return $false } }
    $ingles = @('the','and','you','is','it','to','of','what','how','so','we','go','can','i','a','yeah','well','that','this','like','say','now','okay','they','have','if','not','but','since','will','are','in','their','do','only','good','things','too','uh','my','your','with','for','be')
    $n = @($pal | Where-Object { $ingles -contains $_ }).Count
    return ($n / $pal.Count) -lt 0.34
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

# JUEGOS POR COMO SUENAN (14/09, tanda dirigida). Sin la lista de nombres, Whisper en
# espanol escribe los titulos en ingles como le suenan: "Jolon Nights", "gus gus dup",
# "Aura pic", "contenguarme". Por letras no se parecen al titulo; por SONIDO si. Esto
# pasa cada titulo a como lo diria alguien que habla espanol (la h inglesa suena j, "oo"
# suena u, "igh" suena ai...) y lo oido a su clave de sonido, y los compara. Medido con
# lo que oyo Whisper en las dos tandas: 12 de 34 titulos mal oidos encontrados y NINGUNA
# de 391 frases que no son de juegos (ni el ruido real) se confunde con uno. Se usa solo
# detras de un verbo de abrir y SIEMPRE pregunta antes ("¿Hollow Knight?").
function Get-ClaveSonido([string]$t, [bool]$ingles = $false) {
    $t = ConvertTo-Juego $t
    $t = [regex]::Replace($t, '\btres\b', '3')
    $t = [regex]::Replace($t, '\bdos\b', '2')
    $t = [regex]::Replace($t, '\buno\b', '1')
    if ($ingles) {
        foreach ($par in @(@('ght', 't'), @('igh', 'ai'), @('kn', 'n'), @('ph', 'f'), @('th', 't'), @('ck', 'k'), @('ee', 'i'), @('ea', 'i'),
                           @('oo', 'u'), @('ow', 'o'), @('out', 'aut'), @('ou', 'au'), @('wa', 'gua'), @('w', 'u'), @('y', 'i'), @('qu', 'k'))) {
            $t = $t.Replace($par[0], $par[1])
        }
        $t = [regex]::Replace($t, '\bh', 'j')
        $t = [regex]::Replace($t, 'e\b', '')
    }
    $t = [regex]::Replace($t, 'c(?=[ei])', 's')
    $t = $t.Replace('c', 'k').Replace('z', 's').Replace('v', 'b')
    $t = [regex]::Replace($t, 'g(?=[ei])', 'j')
    $t = $t.Replace('ll', 'i').Replace('h', '').Replace('x', 'ks')
    $t = [regex]::Replace($t, '(.)\1+', '$1')
    return ($t -replace '\s', '')
}

$script:ClavesJuegos = $null
function Find-JuegoPorSonido([string]$resto, [string]$frase, [double]$umbral = 0.5) {
    if (-not $script:Juegos -or @($script:Juegos).Count -eq 0) { return $null }
    if (-not $script:ClavesJuegos -or $script:ClavesJuegos.Count -ne @($script:Juegos).Count) {
        $script:ClavesJuegos = @{}
        foreach ($jS in @($script:Juegos)) { $script:ClavesJuegos[$jS.nombre] = Get-ClaveSonido $jS.nombre $true }
    }
    # con y sin la palabra de delante: "Aure el ring" se prueba como "el ring" y como "ring"
    $variantes = New-Object System.Collections.ArrayList
    [void]$variantes.Add((Get-ClaveSonido $resto))
    $sinPrimera = (($frase -split '\s+', 2) + @(''))[1]
    if ($sinPrimera) { [void]$variantes.Add((Get-ClaveSonido $sinPrimera)) }
    $variantes = @($variantes | Where-Object { $_.Length -ge 3 } | Select-Object -Unique)
    if ($variantes.Count -eq 0) { return $null }
    $mejor = $null; $mejorP = 0.0; $segundaP = 0.0
    foreach ($jS in @($script:Juegos)) {
        $k = [string]$script:ClavesJuegos[$jS.nombre]
        if (-not $k) { continue }
        $p = 0.0
        foreach ($q in $variantes) {
            $pq = 1.0 - ((Get-Distancia $q $k) / [double][Math]::Max($q.Length, $k.Length))
            if ($pq -gt $p) { $p = $pq }
        }
        if ($p -gt $mejorP) { $segundaP = $mejorP; $mejorP = $p; $mejor = $jS }
        elseif ($p -gt $segundaP) { $segundaP = $p }
    }
    # sin un claro ganador (Outlast / Outlast 2) no se adivina
    if ($mejor -and $mejorP -ge $umbral -and ($mejorP - $segundaP) -ge 0.08) { return $mejor }
    return $null
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
            foreach ($l in ((Get-Content -LiteralPath $vdf -Raw -Encoding UTF8) -split "`n")) {
                if ($l -match '"path"\s*"([^"]+)"') { [void]$libs.Add(($Matches[1] -replace '\\\\', '\')) }
            }
        }
        $vistos = @{}
        foreach ($lib in ($libs | Select-Object -Unique)) {
            $d = Join-Path ($lib -replace '/', '\') 'steamapps'
            if (-not (Test-Path -LiteralPath $d)) { continue }
            foreach ($f in (Get-ChildItem -LiteralPath $d -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue)) {
                $c = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($c -match '"appid"\s*"(\d+)"') { $id = $Matches[1] } else { continue }
                if ($c -match '"name"\s*"([^"]+)"') { $nm = $Matches[1] } else { continue }
                if ($vistos.ContainsKey($id)) { continue }
                $vistos[$id] = $true
                # los redistribuibles no son juegos
                if ($nm -match '(?i)redistributable|proton|steam linux runtime|steamworks') { continue }
                # todo esto ya estaba en el archivo y se tiraba a la basura
                $est = 0; $bd = 0; $bt = 0; $tam = 0; $lp = 0; $dir = ''
                if ($c -match '"StateFlags"\s*"(\d+)"') { $est = [int]$Matches[1] }
                if ($c -match '"BytesDownloaded"\s*"(\d+)"') { $bd = [double]$Matches[1] }
                if ($c -match '"BytesToDownload"\s*"(\d+)"') { $bt = [double]$Matches[1] }
                if ($c -match '"SizeOnDisk"\s*"(\d+)"') { $tam = [double]$Matches[1] }
                if ($c -match '"LastPlayed"\s*"(\d+)"') { $lp = [long]$Matches[1] }
                if ($c -match '"installdir"\s*"([^"]+)"') { $dir = $Matches[1] }
                # descargando de verdad: no basta con que falten bytes (hay
                # entradas instaladas con contadores viejos, como los
                # redistribuibles), tiene que estar EN OTRO estado que instalado
                $bajando = ($est -ne 4) -and ($bt -gt 0) -and ($bd -lt $bt)
                $res += @{ id = $id; nombre = $nm; plano = (ConvertTo-Juego $nm)
                           estado = $est; bajando = $bajando; descargado = $bd; total = $bt
                           tamano = $tam; ultimo = $lp; dir = $dir }
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

# "94,2 gigas" se lee mejor que "94200000000 bytes".
function Format-Gigas([double]$bytes) {
    if ($bytes -le 0) { return "0 gigas" }
    $g = $bytes / 1073741824.0
    if ($g -lt 1) { return ([int]($bytes / 1048576.0)).ToString() + " megas" }
    if ($g -lt 10) { return $g.ToString("0.0", [System.Globalization.CultureInfo]::GetCultureInfo("es-ES")) + " gigas" }
    return ([int][Math]::Round($g)).ToString() + " gigas"
}

# "hace dos dias" en vez de una fecha: es como se pregunta y como se responde.
function Format-Desde([long]$unix) {
    if ($unix -le 0) { return $null }
    $cuando = [DateTimeOffset]::FromUnixTimeSeconds($unix).ToLocalTime().DateTime
    $dias = [int][Math]::Floor(((Get-Date).Date - $cuando.Date).TotalDays)
    if ($dias -le 0) { return "hoy" }
    if ($dias -eq 1) { return "ayer" }
    if ($dias -lt 7) { return "hace $dias dias" }
    if ($dias -lt 14) { return "hace una semana" }
    if ($dias -lt 60) { return "hace " + [int][Math]::Round($dias / 7.0) + " semanas" }
    $cul = New-Object System.Globalization.CultureInfo("es-MX")
    return "el " + $cuando.ToString("d \d\e MMMM", $cul)
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
                   'configuracion' = 'SystemSettings'; 'ajustes' = 'SystemSettings'; 'armoury crate' = 'ArmouryCrate'; 'armoury' = 'ArmouryCrate'
                   # apps del sistema de Windows 11 cuyo proceso no se llama como su
                   # .exe: "cierra la calculadora" buscaba "calc" y no la encontraba
                   'calculadora' = 'CalculatorApp'; 'calc' = 'CalculatorApp'; 'fotos' = 'Photos'; 'tienda' = 'WinStore.App'; 'microsoft store' = 'WinStore.App' }
# Programas de usuario abiertos: los que tienen ventana con titulo. Se dejan
# fuera el propio asistente, su capsula, el escritorio y la barra de tareas,
# que no son "programas" para quien habla y cerrarlos romperia la sesion.
# Tambien la terminal y Claude: el 12/09 "cierra todos los procesos" cerro la
# ventana donde el usuario estaba hablando con Claude, a mitad de mensaje.
$PROCESOS_INTOCABLES = @('explorer', 'nova_ui', 'powershell', 'pwsh', 'ApplicationFrameHost',
                         'TextInputHost', 'SystemSettings', 'ShellExperienceHost', 'SearchHost',
                         'WindowsTerminal', 'OpenConsole', 'conhost', 'claude', 'opencode', 'python', 'pythonw')

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
# Descargas: que estaba bajando la ultima vez que se miro, para notar cuando
# una termina. Sin esto habria que preguntar a Steam, que es justo lo que no
# se puede hacer sin salir del juego. Se declara mas abajo, con las demas
# variables de flanco: aqui estaba DUPLICADA y la de abajo la pisaba.
# -120000: la primera lectura se hace al arrancar, no a los dos minutos. Solo
# toma nota (no anuncia finales), y asi el anillo de la descarga sale enseguida.
$script:descargaCheck = -120000
# Si estaba cargando la ultima vez que se miro. $null = todavia no se sabe,
# para no disparar una regla en el primer chequeo tras arrancar.
$script:cargandoAntes = $null
$script:bateriaMin = 0

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
    # ... tambien con un verbo MAL OIDO. "Sierra, steam" (cierra steam, 12/09,
    # jugando) se tiraba como catalogo recitado porque "sierra" no es un verbo.
    # Solo la lista cerrada de $VERBOS_OIDOS, no la correccion por parecido: a
    # distancia 1 media biblioteca de Steam pasaria por verbo.
    if ($VERBOS_OIDOS.ContainsKey((@($plano -split '\s+'))[0])) { return $false }
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

# ¿Vale la pena pedir el repaso del oido fino?
# Test-MismoAudio (justo debajo) solo acepta el repaso si comparte con lo que
# se oyo primero un trozo de palabra de 4 letras o mas. Si lo primero no tiene
# ninguna palabra de 4 letras, ninguna palabra larga del repaso puede caber
# dentro: el repaso se descartara SIEMPRE. Esperarlo es regalar segundos, y
# encima en el caso mas frecuente, que es el ruido corto.
function Test-MereceRepaso([string]$text) {
    $p = ConvertTo-Plain $text
    if (-not $p) { return $false }
    foreach ($w in @($p -split '\s+')) { if ($w.Length -ge 4) { return $true } }
    return $false
}

# ¿Es CHARLA y no una orden para mi?
# El 12/09, de 19:02 a 19:07, el usuario hablaba con otra persona y todo acabo
# en el agente: "bueno, voy a tratar de salir mas rapido", "porque eso supone
# que nosotros a las ocho", "igual podemos vernos el lunes, ¿no?". "nova" salto
# con confianzas de 0,65 a 0,96, asi que subir el umbral no lo separa de las
# ordenes buenas. Lo que si lo separa, mirando TODAS las frases largas que han
# llegado al agente en el log y en el banco: una orden empieza por lo que se
# quiere ("abre", "busca", "sube", "recuerda", "puedes..."); la charla, por
# cualquier otra cosa. Solo se aplica a lo que la capa local NO entendio y no
# es pregunta, y solo a frases largas: lo corto ya lo lleva el filtro de ruido.
$INICIO_ORDEN = @('puedes', 'podrias', 'puede', 'podria', 'quiero', 'quisiera', 'necesito', 'me', 'hazme', 'haz', 'dame', 'deja', 'dejame',
    'activa', 'activame', 'desactiva', 'recuerda', 'recuerdame', 'avisame', 'avisa', 'apunta', 'anota', 'lee', 'leeme', 'dicta',
    'traduce', 'traduceme', 'descarga', 'descargame', 'instala', 'desinstala', 'crea', 'creame', 'borra', 'elimina', 'quita', 'llama',
    'juega', 'configura', 'ajusta', 'revisa', 'mira', 'comprueba', 'calcula', 'convierte', 'ayudame', 'ayuda', 'resume', 'resumeme',
    'cuenta', 'cuentame', 'dime', 'busca', 'buscame', 'ensename', 'muestrame', 'explica', 'explicame', 'escribe', 'escribeme',
    'intenta', 'prueba', 'organiza', 'ordena', 'limpia', 'graba', 'captura', 'toma', 'saca', 'contesta', 'responde', 'manda', 'ponle',
    'ponte', 'hazte', 'quitale', 'cambiale', 'dile', 'agrega', 'anade', 'agregame', 'enciende', 'desconecta', 'conecta', 'vuelve', 'repite')
# Palabras inglesas corrientes para la charla corta (ver Test-Charla). Fuera las
# que tambien son espanol: "no", "me", "he", "come", "a", "ok".
$INGLES_COMUN = @('the', 'you', 'i', 'is', 'it', 'that', 'what', 'oh', 'my', 'god', 'this', 'and', 'to', 'of', 'yes', 'yeah',
    'so', 'we', 'are', 'do', 'know', 'like', 'just', 'go', 'lets', "let's", 'on', 'man', 'bro', 'wow', 'look', 'right', 'im',
    "i'm", 'dont', "don't", 'its', "it's", 'thats', "that's", 'was', 'with', 'for', 'have', 'not', 'she', 'they', 'your', 'him',
    'her', 'there', 'here', 'how', 'why', 'who', 'where', 'when', 'can', 'cant', "can't", 'will', 'would', 'please', 'thank',
    'thanks', 'sorry', 'hello', 'dude', 'guys', 'well', 'now', 'really', 'very', 'good', 'nice', 'cool', 'love', 'want', 'get',
    'got', 'gonna', 'wanna', 'be', 'am', 'in', 'at', 'all', 'one', 'too', 'did', 'see', 'say', 'said', 'out', 'up', 'about',
    'then', 'if', 'but', 'or', 'doing', 'going', 'think', 'our', 'us', 'fuck', 'shit', 'damn')
$ESPANOL_COMUN = @('de', 'la', 'el', 'que', 'y', 'en', 'un', 'una', 'por', 'con', 'para', 'mi', 'me', 'lo', 'se', 'los', 'las',
    'al', 'del', 'es', 'si', 'no', 'esta', 'este', 'eso', 'ya', 'yo', 'tu', 'te', 'le', 'su', 'pon', 'abre', 'sube', 'baja',
    'volumen', 'brillo', 'modo', 'juego', 'ventana', 'cierra', 'busca', 'nova', 'como', 'donde', 'cuando', 'porque', 'pero')
function Test-Charla([string]$text) {
    $p = ConvertTo-Plain $text
    if (-not $p) { return $false }
    # lo de delante no cuenta: "oye nova, abre steam", "bueno, pon modo noche"
    $p = ($p -replace '^(?:(?:hola|oye|ey|hey|nova|por favor|porfa|a ver|bueno|vale|ok|okey|entonces|y|pues|eh)\s+)+', '').Trim()
    $w = @($p -split '\s+' | Where-Object { $_ })
    if ($w.Count -lt 3) { return $false }
    $primera = $w[0]
    if ($VERBOS_OIDOS.ContainsKey($primera)) { return $false }          # "sierra todas las ventanas..."
    if (($VERBOS_LISTA -contains $primera) -or ($INICIO_ORDEN -contains $primera)) { return $false }
    # imperativo con el pronombre pegado: "buscame", "bajale", "abrelo"
    if ($primera -match '^[a-z]{2,}[ae](?:me|le|te|lo|la|les|los|las|nos)$') { return $false }
    # CHARLA CORTA EN INGLES (revision del 12/09): "oh my god what is that",
    # "I don't know man". Las ordenes son en espanol, asi que una frase corta
    # hecha de palabras inglesas corrientes y sin una sola espanola es
    # conversacion (o un video). Pero un juego se llama como se llama: si la
    # frase lleva el nombre de uno ("the last of us"), no se toca.
    if ($w.Count -lt 7) {
        $en = @($w | Where-Object { $INGLES_COMUN -contains $_ }).Count
        $es = @($w | Where-Object { $ESPANOL_COMUN -contains $_ }).Count
        if ($es -gt 0 -or $en -lt 2 -or ($en / $w.Count) -lt 0.5) { return $false }
        foreach ($j in @($script:Juegos)) {
            if (-not $j -or -not $j.nombre) { continue }
            $nj = ConvertTo-Plain ([string]$j.nombre)
            # en los dos sentidos: "the last of us" no contiene "the last of us part i"
            if ($nj.Length -ge 4 -and ($p.Contains($nj) -or $nj.Contains($p))) { return $false }
        }
    }
    return $true
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
    # VARIOS NOMBRES SEGUIDOS son varias ordenes. "abre steam, discord y
    # spotify" llega aqui como "steam discord" (la coma se borro al
    # normalizar y "y spotify" ya se separo): antes se buscaba un parecido
    # dentro y se abria SOLO Steam, tirando el resto sin avisar. Se exige que
    # TODAS las palabras sean nombres conocidos, asi que "little nightmares"
    # o "bad bunny" no se parten.
    $trozos = @($t -split '\s+' | Where-Object { $_ })
    if ($trozos.Count -ge 2 -and $trozos.Count -le 3) {
        $todos = $true
        foreach ($x in $trozos) { if (-not (Test-NombreConocido $x)) { $todos = $false; break } }
        if ($todos) {
            $acc = @()
            foreach ($x in $trozos) { $acc += (Resolve-Target $x) }
            if ($acc.Count -eq $trozos.Count) { return $acc }
        }
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

# LISTAS DE VERDAD, no notas sueltas.
# El diario guarda texto y ya: "recuerda que compre pan" es una linea mas entre
# cientos. Una lista es otra cosa -se le anade, se le quita y se vacia- y eso no
# se puede hacer con lineas de diario. Va en su propio archivo, junto a la
# memoria, porque son datos tuyos y no tienen que subir a GitHub.
# Se guarda como objeto {nombre: [items]}, no como array: asi el archivo se lee
# igual de bien a mano si algun dia hay que arreglarlo.
$RutaListas = Join-Path $MemoriaDir "listas.json"
# JSON ROTO (auditoria del 13/09): si un archivo de memoria no se puede leer, se
# APARTA como .corrupto-<fecha> antes de que el siguiente guardado escriba encima
# una version vacia y se pierda todo lo que tenia (fuera de git: *.corrupto-*).
function Save-Corrupto([string]$ruta, [string]$que) {
    try {
        if (-not (Test-Path -LiteralPath $ruta)) { return }
        $destC = $ruta + '.corrupto-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $ruta -Destination $destC -Force
        Log "$($que): el archivo no se podia leer; lo aparto como $(Split-Path -Leaf $destC)"
    } catch {}
}
function Get-Listas {
    try {
        if (-not (Test-Path -LiteralPath $RutaListas)) { return @{} }
        $datos = Get-Content -LiteralPath $RutaListas -Raw -Encoding UTF8 | ConvertFrom-Json
        $h = @{}
        foreach ($prop in $datos.PSObject.Properties) { $h[$prop.Name] = @($prop.Value) }
        return $h
    } catch { Log ("listas: no pude leerlas (" + $_.Exception.Message + ")"); Save-Corrupto $RutaListas 'listas'; return @{} }
}
function Save-Listas($listas) {
    try {
        if (-not (Test-Path -LiteralPath $MemoriaDir)) { New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null }
        $o = New-Object PSObject
        foreach ($k in $listas.Keys) { $o | Add-Member -NotePropertyName $k -NotePropertyValue @($listas[$k]) -Force }
        Write-Atomico $RutaListas ($o | ConvertTo-Json -Depth 5)
        return $true
    } catch { Log ("listas: no pude guardarlas (" + $_.Exception.Message + ")"); return $false }
}
# "la lista", a secas: si solo tienes una, es esa. Si tienes varias, la de la
# compra si existe, y si no hay ninguna se crea la de la compra. Preguntar
# "¿cual de tus tres listas?" cada vez seria justo lo que no quieres con el
# mando en la mano.
function Resolve-Lista([string]$nombre, $listas) {
    $n = (ConvertTo-Plain $nombre).Trim()
    $n = ($n -replace '^(?:la|el|los|las|mi|mis)\s+', '').Trim()
    if ($n) {
        foreach ($k in $listas.Keys) { if ((ConvertTo-Plain $k) -eq $n) { return $k } }
        return $n
    }
    if ($listas.Keys.Count -eq 1) { return @($listas.Keys)[0] }
    foreach ($k in $listas.Keys) { if ((ConvertTo-Plain $k) -eq 'compra') { return $k } }
    return 'compra'
}
function Format-Lista([string]$nombre, $items) {
    if (-not $items -or @($items).Count -eq 0) { return "la lista de $nombre esta vacia" }
    $n = @($items).Count
    $cuantos = if ($n -eq 1) { "1 cosa" } else { "$n cosas" }
    return "en la lista de $nombre tienes ${cuantos}: " + (@($items) -join ', ')
}

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

# DIARIO DE CONVERSACIONES (M10, 14/09): el worker de charla resume con el modelo
# local lo hablado cada dia y aqui se anade al diario de ESE dia, bajo su titulo.
# Asi "¿de que hablamos ayer?" lo encuentra la busqueda en tus notas.
function Add-DiarioResumen([string]$fecha, [string]$texto) {
    if ($fecha -notmatch '^\d{4}-\d{2}-\d{2}$' -or -not $texto.Trim()) { return }
    if (-not (Test-Path -LiteralPath $DiarioDir)) { New-Item -ItemType Directory -Force -Path $DiarioDir | Out-Null }
    $notaD = Join-Path $DiarioDir ($fecha + '.md')
    $encD = New-Object System.Text.UTF8Encoding($false)
    if (-not (Test-Path -LiteralPath $notaD)) {
        $culD = New-Object System.Globalization.CultureInfo('es-MX')
        $diaD = [datetime]::ParseExact($fecha, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
        [System.IO.File]::WriteAllText($notaD, "# " + $diaD.ToString('dddd d "de" MMMM "de" yyyy', $culD) + "`r`n", $encD)
    }
    $lineasD = @($texto -split "`r?`n" | Where-Object { $_.Trim() })
    [System.IO.File]::AppendAllText($notaD, "`r`n`r`n## Lo que hablamos`r`n" + ($lineasD -join "`r`n") + "`r`n", $encD)
    Log "DIARIO: lo hablado el $fecha, resumido en $($lineasD.Count) lineas"
}

# RECETAS QUE CONFIRMAN EL DATO DUDOSO (M7, 14/09): Whisper apunta su seguridad al
# transcribir (el peor avg_logprob de sus trozos). Si una receta con datos llega
# de un dictado dudoso, se pregunta antes de hacer nada con un nombre mal oido.
$script:dictadoConfianza = 0.0
$script:dictadoConfianzaEn = -999999
# El umbral se calibro con las 20 grabaciones de pruebas\audio (14/09): con este
# microfono Whisper base casi nunca esta muy seguro; con -0,6 preguntaba en 13 de
# 20 dictados, con -0,8 en 9, todos mal oidos, y en ninguno bien oido.
function Test-DictadoDudoso {
    return [bool](($sw.ElapsedMilliseconds - $script:dictadoConfianzaEn) -lt 60000 -and $script:dictadoConfianza -lt -0.8)
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
    if ($script:invitado) { return }   # ver MODO INVITADO
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
        Write-Atomico $EstadisticasJson ($o | ConvertTo-Json -Depth 6)

        $rutas = @('activacion', 'vozwin', 'vozwin-mudo', 'local', 'aprendida', 'memoria', 'pregunta', 'traducir', 'traducida', 'accion', 'charla', 'ruido', 'recitado', 'descarte', 'error', 'fino', 'fino-sirvio', 'fino-igual', 'fino-invento', 'fino-ahorrado')
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("# Estadísticas del asistente")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Actualizado: " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ". La genera el asistente sola; no hace falta editarla.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("**activacion**: veces que se desperto al oir su nombre. **ruido**: lo que se descarto por no ser una orden. **recitado**: enumeraciones de nombres de tu biblioteca que Whisper se invento con el ruido (si esto sube, el microfono esta cazando audio; si baja a cero durante semanas, quiza ya no hace falta el filtro).")
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
        # LO QUE SE LE ATRAGANTA. Arriba ya estaban los descartes sueltos, pero
        # sin contar: una frase que falla cinco veces se leia igual que una que
        # fallo una vez y nunca mas. Agrupado y contado, se ve que arreglar.
        try {
            $at = @(Get-Atragantos | Where-Object { $_.veces -ge 2 } | Select-Object -First 12)
            if ($at.Count -gt 0) {
                # EL OIDO FINO, EN NUMEROS. Cuesta hasta unos segundos por orden y hasta
        # ahora no habia forma de saber si compensa. Si "sirvio" se queda en cero
        # semana tras semana, sobra; si es alto, es lo mejor que tiene.
        try {
            $fTot = 0; $fSir = 0; $fIgu = 0; $fInv = 0; $fAho = 0
            foreach ($k in $s.dias.Keys) {
            if ($s.dias[$k].ContainsKey('fino')) { $fTot += $s.dias[$k]['fino'] }
            if ($s.dias[$k].ContainsKey('fino-sirvio')) { $fSir += $s.dias[$k]['fino-sirvio'] }
            if ($s.dias[$k].ContainsKey('fino-igual')) { $fIgu += $s.dias[$k]['fino-igual'] }
            if ($s.dias[$k].ContainsKey('fino-invento')) { $fInv += $s.dias[$k]['fino-invento'] }
            if ($s.dias[$k].ContainsKey('fino-ahorrado')) { $fAho += $s.dias[$k]['fino-ahorrado'] }
            }
            if (($fTot + $fAho) -gt 0) {
                [void]$sb.AppendLine("## El oído fino, ¿compensa?")
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine('Cuando la capa local no entiende algo, se repasa el MISMO audio con el modelo preciso antes de ir al modelo remoto. Cuesta segundos. Esto dice si sirve.')
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("- repasos pedidos: **$fTot**")
                $pct = if ($fTot -gt 0) { [int](100.0 * $fSir / $fTot) } else { 0 }
                [void]$sb.AppendLine("- **sirvieron: $fSir** ($pct %) — oyó algo distinto Y bueno")
                [void]$sb.AppendLine("- oyó lo mismo: $fIgu — tiempo tirado")
                [void]$sb.AppendLine("- se lo inventó: $fInv — se descartó a tiempo")
                [void]$sb.AppendLine("- ni se pidieron: $fAho — no tenían ninguna palabra de 4 letras, así que el repaso se habría descartado seguro")
                [void]$sb.AppendLine("")
            }
        } catch {}
        [void]$sb.AppendLine("## Lo que más se me atraganta")
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine('Frases que acabaron sin entenderse, en el modelo o en error, MÁS DE UNA VEZ. Para arreglar una: di "aprende que <la frase> es <la orden buena>".')
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("| veces | frase | qué pasó |")
                [void]$sb.AppendLine("|---:|---|---|")
                foreach ($x in $at) {
                    [void]$sb.AppendLine("| $($x.veces) | $($x.frase) | " + ($x.rutas -join ", ") + " |")
                }
                [void]$sb.AppendLine("")
            }
        } catch {}
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

# QUE SE ME ATRAGANTA. Las ordenes que acabaron en el modelo, en nada o en un
# error, agrupadas y contadas. Estos datos ya se guardaban desde hace dias y
# nadie los miraba nunca: el unico sitio donde se veia que algo fallaba era el
# log, y para eso hay que ir a buscarlo. Devuelve una lista ordenada de
# @{ frase; veces; rutas }.
# El portapapeles, con red. Get-Clipboard puede fallar (otro proceso lo tiene
# abierto) y ahi lo correcto es contestar "no tienes nada", no reventar.
function Get-Portapapeles {
    try {
        $t = Get-Clipboard -Format Text -ErrorAction SilentlyContinue
        if ($t -is [array]) { $t = $t -join " " }
        return ([string]$t).Trim()
    } catch { return '' }
}

# Un vistazo corto y decible. Se lee EN VOZ ALTA, asi que no tiene sentido
# soltar mil caracteres ni las lineas en crudo.
function Get-Ojeada([string]$t) {
    $x = (($t -replace '[\r\n]+', ' ') -replace '\s{2,}', ' ').Trim()
    if ($x.Length -gt 90) { $x = $x.Substring(0, 90) + '...' }
    return $x
}

function Get-Atragantos {
    $s = Get-Estadisticas
    $cuenta = @{}; $rutasDe = @{}; $comoSeDijo = @{}
    $apuntar = {
        param($frase, $ruta)
        $k = ConvertTo-Plain $frase
        if (-not $k -or $k.Length -lt 3) { return }
        # una palabra suelta casi siempre es ruido, no una orden que falle
        if ($k -notmatch '\s') { return }
        if (-not $cuenta.ContainsKey($k)) { $cuenta[$k] = 0; $rutasDe[$k] = @(); $comoSeDijo[$k] = $frase }
        $cuenta[$k]++
        if ($rutasDe[$k] -notcontains $ruta) { $rutasDe[$k] += $ruta }
    }
    foreach ($x in @($s.descartes)) {
        # "2026-09-12  abre el disco duro"
        $f = $x; if ($x -match '^\d{4}-\d{2}-\d{2}\s+(.+)$') { $f = $Matches[1] }
        & $apuntar $f 'no lo entendi'
    }
    foreach ($x in @($s.recientes)) {
        # "2026-09-12 21:03  [traducir]  pon musica"
        if ($x -notmatch '^\S+\s+\S+\s+\[([^\]]+)\]\s+(.+)$') { continue }
        # copiar YA: cualquier -match posterior se lleva $Matches por delante
        $ruta = $Matches[1]; $f = $Matches[2]
        $etiqueta = switch ($ruta) {
            'traducir' { 'tuve que preguntarle al modelo' }
            'accion'   { 'tuve que preguntarle al modelo' }
            'pregunta' { 'tuve que preguntarle al modelo' }
            'error'    { 'acabo en error' }
            default    { '' }
        }
        if (-not $etiqueta) { continue }
        & $apuntar $f $etiqueta
    }
    $lista = @()
    foreach ($k in $cuenta.Keys) {
        $lista += @{ frase = $comoSeDijo[$k]; veces = $cuenta[$k]; rutas = $rutasDe[$k] }
    }
    return @($lista | Sort-Object -Property @{ Expression = { $_.veces }; Descending = $true }, @{ Expression = { $_.frase } })
}

# La bateria, dicha como se dice. Estaba dentro del patron de "cuanta bateria";
# ahora la usan ese patron y el parte general ("como va todo"), que es justo el
# tipo de dato que no conviene tener contado de dos maneras distintas.
# $corto: para el parte, donde va junto a otras cinco cosas.
# TU TONO, aprendido de las ordenes que DE VERDAD se ejecutaron.
# tmp\voces.json no sirve para esto y conviene entender por que: lo escribe el
# worker con TODO lo que pasa por el microfono, asi que cuenta tambien el audio
# de los videos. En esta maquina, 3 de sus 4 ranuras son ruido (171, 148 y 231
# Hz), y si un dia el ruido dictara mas que tu, el "dueno" pasaria a ser el
# ruido y el asistente empezaria a desconfiar de ti. Aqui solo entra el tono de
# lo que se ejecuto: una orden que se reconocio y se hizo.
# Media movil con tope de muestras, no media de toda la vida: asi el centro se
# mueve contigo (un microfono nuevo, la voz con los anos) en vez de quedarse
# clavado en la primera semana.
$MiVozTope = 60
function Update-MiVoz([double]$f0) {
    if ($f0 -le 0 -or $script:invitado) { return }   # la voz de un invitado no es la tuya
    try {
        $ruta = Join-Path $TmpDir 'mi-voz.json'
        $m = 0.0; $n = 0
        if (Test-Path -LiteralPath $ruta) {
            $d = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
            $m = [double]$d.f0; $n = [int]$d.n
        }
        # Un salto enorme no puede arrastrar la referencia: si un dia confirmas
        # a mano una orden dicha por otra persona, esa medida no tiene por que
        # mover tu tono. Al principio (sin datos) se acepta lo que venga.
        if ($n -gt 0 -and [Math]::Abs($f0 - $m) -gt 60) { return }
        if ($n -ge $MiVozTope) { $n = $MiVozTope - 1 }
        $m = if ($n -eq 0) { $f0 } else { (($m * $n) + $f0) / ($n + 1) }
        $j = '{"f0":' + ([double]$m).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture) + ',"n":' + ($n + 1) + '}'
        [System.IO.File]::WriteAllText($ruta, $j, (New-Object System.Text.UTF8Encoding($false)))
    } catch {}
}

# TU VOZ, la de la casa. Primero la aprendida de tus ordenes (mi-voz.json); si
# todavia no hay bastantes, se cae a tmp\voces.json, que escribe el worker, y
# de ahi se coge la que MAS ha dictado. No la primera: la primera puede ser
# perfectamente un video que sonaba el dia que se estreno el archivo.
# Devuelve 0 si todavia no se sabe, y entonces no se pregunta nada: con dos
# docenas de ordenes repartidas no se puede acusar a nadie de no ser el dueno.
function Get-VozDuena([string]$ruta = '') {
    if (-not $ruta) {
        $mia = Join-Path $TmpDir 'mi-voz.json'
        try {
            if (Test-Path -LiteralPath $mia) {
                $d = Get-Content -LiteralPath $mia -Raw -Encoding UTF8 | ConvertFrom-Json
                if ([int]$d.n -ge $SoloYoMinimo -and [double]$d.f0 -gt 0) { return [double]$d.f0 }
            }
        } catch {}
        $ruta = Join-Path $TmpDir 'voces.json'
    }
    try {
        if (-not (Test-Path -LiteralPath $ruta)) { return 0.0 }
        # OJO: @(algo | ConvertFrom-Json) sobre un array JSON da UN elemento que
        # es el array entero, no los elementos. Hay que asignar primero y
        # envolver despues; si no, $orden[0].n es un Object[] y el [int] revienta
        # dentro del try, que se lo traga y deja sin dueño a cualquiera.
        $datos = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
        $voces = @($datos)
        if ($voces.Count -eq 0) { return 0.0 }
        $orden = @($voces | Sort-Object -Property n -Descending)
        $top = $orden[0]
        if ([int]$top.n -lt $SoloYoMinimo) { return 0.0 }
        # y que destaque: si la segunda casi empata, no hay dueno, hay dos
        # personas hablandole a la consola, y ahi lo justo es no molestar
        if ($orden.Count -gt 1 -and [int]$top.n -lt (1.5 * [int]$orden[1].n)) { return 0.0 }
        return [double]$top.f0
    } catch { return 0.0 }
}

# ¿Esto lo has dicho tu? Solo dice $true cuando se PUEDE afirmar que no: hace
# falta una medida de tono de esta orden, un dueno claro, y una diferencia
# grande. En cualquier duda contesta $false y la orden sigue su camino: esta es
# una defensa contra el ruido, no un portero.
function Test-VozExtrana([double]$f0 = -1, [double]$duena = -1) {
    if (-not $SoloYoOn) { return $false }
    if ($f0 -lt 0) {
        # TU VOZ AL ENFADARTE (15/09): con el boton o respondiendole justo despues de
        # hablar ella, quien habla eres tu. En su uso real subio a 155, 153 y 179 Hz
        # (su tono es 116) justo al quejarse, y Nova le pregunto "no me suena tu voz" y
        # descarto dos veces lo que dijo. Solo se desconfia de la voz tras el nombre.
        if ($script:origenDictado -eq 'seguimiento' -or $script:origenDictado -like 'mantener*') { return $false }
        $f0 = [double]$script:ultimaF0
    }
    if ($f0 -le 0) { return $false }
    if ($duena -lt 0) { $duena = Get-VozDuena }
    if ($duena -le 0) { return $false }
    return ([Math]::Abs($f0 - $duena) -gt $SoloYoMargen)
}

function Get-FraseBateria([bool]$corto = $false) {
    $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $b -or -not $b.EstimatedChargeRemaining) { return '' }
    $pc = [int]$b.EstimatedChargeRemaining
    $t = if ($corto) { "bateria al $pc por ciento" } else { "Bateria al $pc por ciento" }
    if ($b.BatteryStatus -eq 2) {
        $t += if ($pc -ge 99) { ", cargada y enchufada" } else { " y cargando" }
    } else {
        # EstimatedRunTime: Windows devuelve un centinela enorme (71582788)
        # mientras esta enchufado, asi que solo vale si es un numero de minutos
        # con sentido.
        $min = 0
        try { $rt = [int]$b.EstimatedRunTime; if ($rt -gt 0 -and $rt -lt 1000) { $min = $rt } } catch {}
        if ($min -gt 0) {
            $h = [int][Math]::Floor($min / 60); $m = $min % 60
            $cuanto = if ($h -ge 1) { "$h h $m min" } else { "$m minutos" }
            $t += ", te quedan unos $cuanto"
        }
    }
    return $t
}

# UN SOLO PARTE, en vez de seis preguntas. Todos estos datos ya se recogian por
# separado; lo unico que faltaba era juntarlos. Se dice SOLO lo que aporta: el
# procesador solo si esta alto, los colgados solo si los hay. Un parte que
# siempre dice seis cosas no se escucha entero.
# Esta aparte -y no dentro del switch- para que tools\probar-parte.ps1 pueda
# sacarla del archivo real y comprobar lo que DICE, no solo que la frase se
# reconozca.
# ¿QUE HE HECHO HOY?
# Todo esto ya se guardaba y no lo juntaba nadie: a que jugaste y cuanto (la
# biblioteca de Steam apunta la ultima partida), que anotaste (el diario tiene
# un archivo por dia), que descargas acabaron, y cuantas ordenes diste -con
# cuantas se despertO para nada, que es el numero que dice si el microfono esta
# cazando ruido-.
# Se cuenta en frases, no en tablas: esto se ESCUCHA.
function Get-QueHeHecho {
    $partes = @()
    $hoy = Get-Date -Format 'yyyy-MM-dd'

    # 1. a que jugaste hoy, segun los manifiestos de Steam
    try {
        $null = Update-Juegos
        $hoyIni = [DateTimeOffset]::new((Get-Date).Date, [TimeSpan]::Zero).ToUnixTimeSeconds()
        $jugados = @($script:Juegos | Where-Object { [long]$_.ultimo -ge $hoyIni } |
                     Sort-Object -Property ultimo -Descending)
        if ($jugados.Count -eq 1) { $partes += "jugaste a $($jugados[0].nombre)" }
        elseif ($jugados.Count -gt 1) {
            $nombres = @($jugados | Select-Object -First 3 | ForEach-Object { $_.nombre })
            $partes += "jugaste a " + ($nombres -join ', ')
        }
    } catch {}

    # 2. cuanto llevas con el de ahora (el tiempo total del dia no se guarda;
    #    decir lo que SI se sabe es mejor que inventar un total)
    if ($script:juegoActivo) {
        $mins = [int](($sw.ElapsedMilliseconds - $script:juegoDesde) / 60000)
        if ($mins -ge 1) { $partes += "llevas $mins minutos con $($script:juegoActivo) ahora mismo" }
    }

    # 3. que apuntaste: las notas del diario de hoy
    try {
        $diario = Join-Path $MemoriaDir ("diario\" + $hoy + ".md")
        if (Test-Path -LiteralPath $diario) {
            $lineas = @(Get-Content -LiteralPath $diario -Encoding UTF8 |
                        Where-Object { $_.Trim() -and $_ -notmatch '^#' })
            if ($lineas.Count -eq 1) { $partes += "apuntaste una cosa" }
            elseif ($lineas.Count -gt 1) { $partes += "apuntaste $($lineas.Count) cosas" }
        }
    } catch {}

    # 4. las ordenes del dia, y cuantas fueron ruido
    try {
        $st = Get-Estadisticas
        if ($st.dias.ContainsKey($hoy)) {
            $d = $st.dias[$hoy]
            $hechas = 0
            foreach ($r in @('local', 'aprendida', 'traducida', 'memoria')) {
                if ($d.ContainsKey($r)) { $hechas += [int]$d[$r] }
            }
            $nada = 0
            foreach ($r in @('ruido', 'descarte', 'error')) {
                if ($d.ContainsKey($r)) { $nada += [int]$d[$r] }
            }
            if ($hechas -gt 0) {
                $t = "me diste $hechas ordenes"
                if ($nada -gt 0) { $t += " y $nada veces me desperte para nada" }
                $partes += $t
            } elseif ($nada -gt 0) {
                $partes += "hoy me desperte $nada veces para nada y no me pediste nada"
            }
        }
    } catch {}

    if ($partes.Count -eq 0) { return 'hoy no ha pasado gran cosa todavia' }
    return 'hoy ' + ($partes -join ', ')
}

function Get-ParteGeneral {
    $partes = @()
    # 1. a que juegas: es el contexto de todo lo demas
    if ($script:juegoActivo) {
        $mins = [int](($sw.ElapsedMilliseconds - $script:juegoDesde) / 60000)
        $partes += "estas en $($script:juegoActivo) desde hace $mins minutos"
    }
    # 2. bateria, con lo que queda
    $fb = Get-FraseBateria $true
    if ($fb) { $partes += $fb }
    # 3. descargas (los manifiestos ya leidos, sin tocar Steam ni la red)
    $bajando = @($script:Juegos | Where-Object { $_.bajando })
    if ($bajando.Count -eq 1) {
        $jb = $bajando[0]
        $pct = [int](100.0 * $jb.descargado / [Math]::Max(1, $jb.total))
        $partes += "$($jb.nombre) va por el $pct por ciento"
    } elseif ($bajando.Count -gt 1) {
        $partes += "$($bajando.Count) descargas en marcha"
    }
    # 4. disco: la unidad de los juegos, que es la que se llena
    try {
        $uni = 'C'
        $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
        if ($sp) { $uni = ($sp -replace '/', '\').Substring(0, 1).ToUpper() }
        $di = New-Object System.IO.DriveInfo($uni)
        if ($di.IsReady) { $partes += ("quedan " + (Format-Gigas $di.AvailableFreeSpace) + " en $uni") }
    } catch {}
    # 5. procesador, SOLO si esta alto: decir "al 10 por ciento" no le sirve a
    #    nadie, y lo que se busca preguntando esto es el tiron
    if ($script:uiCarga -ge 85) { $partes += "el procesador esta al $($script:uiCarga) por ciento" }
    # 6. algo colgado sin ventana (lo que paso con Outlast 2)
    try {
        $zz = @(Get-JuegosZombis)
        if ($zz.Count -eq 1) { $partes += "$($zz[0].nombre) sigue colgado sin ventana" }
        elseif ($zz.Count -gt 1) { $partes += "hay $($zz.Count) juegos colgados sin ventana" }
    } catch {}
    # 7. y si estoy sorda, decirlo: es la respuesta a "por que no me haces caso",
    #    y aqui no cuesta nada
    if ($script:sordinaHasta -gt $sw.ElapsedMilliseconds) {
        $quedan = [int][Math]::Ceiling(($script:sordinaHasta - $sw.ElapsedMilliseconds) / 60000.0)
        $partes += "sigo en silencio $quedan minutos mas"
    }
    if ($partes.Count -eq 0) { return 'todo tranquilo' }
    return ($partes -join ', ')
}

# CUANTAS VECES. El dictado escribe "tres veces", no "3 veces", asi que sin
# esta tabla la mitad de las ordenes de menu no se entienden. El tope de 20 es
# el mismo que ya tenia "pulsa X N veces": con la voz, pasarse de teclas es
# mucho peor que quedarse corto, porque deshacer 40 pulsaciones en un menu de
# juego no se puede.
$VECES_TOPE = 20
$NumerosPalabra = @{
    'un' = 1; 'una' = 1; 'uno' = 1; 'dos' = 2; 'tres' = 3; 'cuatro' = 4; 'cinco' = 5
    'seis' = 6; 'siete' = 7; 'ocho' = 8; 'nueve' = 9; 'diez' = 10; 'once' = 11
    'doce' = 12; 'trece' = 13; 'catorce' = 14; 'quince' = 15; 'dieciseis' = 16
    'diecisiete' = 17; 'dieciocho' = 18; 'diecinueve' = 19; 'veinte' = 20
    'veintiuno' = 21; 'veintidos' = 22; 'veintitres' = 23; 'veinticuatro' = 24
    'veinticinco' = 25; 'veintiseis' = 26; 'veintisiete' = 27; 'veintiocho' = 28
    'veintinueve' = 29; 'treinta' = 30; 'cuarenta' = 40; 'cincuenta' = 50
    'sesenta' = 60; 'setenta' = 70; 'ochenta' = 80; 'noventa' = 90
    'cien' = 100; 'ciento' = 100
}

# NUMEROS DICHOS CON PALABRAS.
# El dictado escribe unas veces "70" y otras "setenta", segun le da, y TODOS los
# patrones de esta base esperan digitos. Medido con las 20 grabaciones del
# 12/09, eso se llevaba por delante cuatro ordenes de golpe, y en silencio:
#   "pon el volumen al setenta"        -> acababa en "baja el volumen" (!)
#   "pon el juego al ochenta"          -> no se entendia
#   "abre little nightmares tres"      -> abria Little Nightmares, el primero
#   "recuerdame en veinte minutos ..." -> se archivaba como nota del diario
# Ninguno se veia en el banco de texto, porque alli las frases llevan cifras.
function ConvertTo-Digitos([string]$t) {
    if (-not $t) { return $t }
    if ($t -notmatch '(?i)\b(?:un|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|dieci|veint|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa|cien)') { return $t }
    # primero los compuestos ("treinta y cinco"), que si no se comerian el
    # "treinta" por su cuenta y dejarian un "30 y 5" sin sentido
    $t = [regex]::Replace($t, '(?i)\b(treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa)\s+y\s+(uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)\b', {
        param($m)
        [string]([int]$NumerosPalabra[$m.Groups[1].Value.ToLower()] + [int]$NumerosPalabra[$m.Groups[2].Value.ToLower()])
    })
    $t = [regex]::Replace($t, '(?i)\bciento\s+(\d{1,2})\b', { param($m) [string](100 + [int]$m.Groups[1].Value) })
    # y luego los sueltos. Fuera "un"/"una"/"uno": son articulos mucho mas veces
    # que numeros ("dicta UN correo", "pon UNA cancion"), y el temporizador ya
    # entiende "en un minuto" por su cuenta.
    $sueltos = @($NumerosPalabra.Keys | Where-Object { $_ -notin @('un', 'una', 'uno') })
    $t = [regex]::Replace($t, '(?i)\b(' + ((@($sueltos) | Sort-Object -Property Length -Descending) -join '|') + ')\b', {
        param($m) [string]$NumerosPalabra[$m.Groups[1].Value.ToLower()]
    })
    return $t
}
function Get-Veces([string]$txt) {
    if (-not $txt) { return 1 }
    $t = $txt.Trim().ToLower()
    if ($t -match '^\d{1,2}$') { return [Math]::Max(1, [Math]::Min($VECES_TOPE, [int]$t)) }
    if ($NumerosPalabra.ContainsKey($t)) { return [int]$NumerosPalabra[$t] }
    return 1
}

function Resolve-Fragment([string]$f) {
    # Los numeros, a cifras, ANTES de mirar ningun patron. Aqui no llega el
    # texto libre: las notas del diario las coge un atajo anterior con el texto
    # tal cual, y el dictado largo va por otro camino. Asi que convertir aqui no
    # le cambia las palabras a nada que se vaya a guardar o a escribir.
    $f = ConvertTo-Digitos $f
    # --- perfiles: una frase, varias acciones ("modo juego") ---
    # "modo foco" NO es un perfil: tiene su propia orden mas abajo (ver MODO FOCO),
    # y este bloque devuelve $null con un modo que no existe (revision del 13/09)
    # "pon UN modo juego": asi lo oye Whisper con la frase de ejemplo (14/09)
    if ($f -match '^(?:modo|activa el modo|activa modo|activa un modo|pon el modo|pon modo|pon un modo|ponte en modo|cambia a modo|entra en modo)\s+(?!(?:foco|concentracion|ahorro|bajo consumo|eficiencia|rendimiento|maximo rendimiento|alto rendimiento|equilibrado)\b)(.+)$') {
        $nombre = $Matches[1].Trim()
        # UN MODO QUE SE PARECE (validacion, 15/09): "pon modo juego" se oyo "Pon el modo
        # huevo" (Whisper confunde la j con la h). Si no existe y UNO SOLO se le parece
        # mucho (hasta 2 letras), ese, pero preguntando antes.
        if (-not (Test-Prop $cmds.perfiles $nombre) -and $nombre.Length -ge 4 -and $cmds.perfiles) {
            $candModo = @($cmds.perfiles.PSObject.Properties.Name | Where-Object { $_.Length -ge 4 -and (Get-Distancia $nombre $_) -le 2 })
            if ($candModo.Count -eq 1) { $script:dudosa = "modo " + $candModo[0]; $nombre = [string]$candModo[0] }
        }
        if (Test-Prop $cmds.perfiles $nombre) {
            # TOPE DE ANIDAMIENTO. Desde que los modos se pueden crear por voz,
            # nada impide un "modo a" que llame al "modo b" que llame al "modo a":
            # sin tope eso es una recursion infinita, o sea, el asistente colgado.
            if ($script:hondoPerfil -ge 3) {
                Log "PERFIL: demasiados modos encadenados en '$nombre'; se corta"
                return $null
            }
            $script:hondoPerfil++
            try {
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
            } finally { $script:hondoPerfil-- }
        }
        return $null
    }
    # "recuerda que X" -> se anota YA, sin pasar por el modelo
    # El lookahead negativo distingue "recuerdame que X" (nota) de
    # "recuerdame EN 20 MINUTOS que X" (temporizador), que se resuelve mas abajo.
    # --- modos: verlos y borrarlos hablando ---
    # CREARLOS no puede estar aqui: "crea el modo x: cierra discord Y pon el
    # volumen al 30" llega ya partido por la "y", asi que el patron nunca veria
    # la frase entera. Se resuelve en Invoke-FastCommand, antes de partir, igual
    # que "aprende que...".
    if ($f -match '^(?:que|cuantos)\s+modos\s+(?:tengo|hay|conoces|sabes)$' -or
        $f -match '^(?:mis|lista de)\s+modos$' -or $f -match '^que modos$') {
        return @(@{ kind = 'verModos'; desc = 'tus modos' })
    }
    if ($f -match '^que\s+(?:hace|tiene)\s+(?:el\s+)?modo\s+(.+)$') {
        return @(@{ kind = 'verModo'; nombre = $Matches[1].Trim(); desc = 'ver un modo' })
    }
    # solo "borra / elimina": "quita el modo juego" u "olvida el modo noche" se dicen
    # queriendo DESACTIVARLO, y lo borraban de commands.json sin preguntar (auditoria 13/09)
    if ($f -match '^(?:borra|borrame|elimina)\s+(?:el\s+)?modo\s+(.+)$') {
        return @(@{ kind = 'borrarModo'; nombre = $Matches[1].Trim(); desc = 'borrar un modo' })
    }

    # --- a que esquina se va la capsula ---
    # 'ponme' y companía estan en la lista a proposito: Repair-Verb arregla el
    # verbo de cabeza por parecido ANTES de llegar aqui, y 'ponte' acaba siendo
    # 'ponme' (el primero de la lista a distancia 1). Sin eso, 'ponte arriba a la
    # derecha' no se reconocia y 'vete arriba a la derecha' si, que es de las
    # cosas mas desconcertantes que puede hacer.
    if ($f -match '^(?:ponte|ponme|poneme|pone|pon|ponete|vete|ve|colocate|coloca|muevete|mueve|pasate|pasa)\s+(?:a\s+la\s+|a\s+|al\s+|en\s+la\s+|en\s+)?(?:esquina\s+(?:de\s+)?)?(arriba|abajo)\s*(?:a\s+la\s+|a\s+|de\s+la\s+|\s+)?(izquierda|derecha)$' -or
        $f -match '^(?:ponte|ponme|poneme|pone|pon|ponete|vete|ve|colocate|coloca|muevete|mueve|pasate|pasa)\s+(?:a\s+la\s+|a\s+|al\s+|en\s+la\s+|en\s+)?(?:esquina\s+(?:de\s+)?)?(?:la\s+)?(izquierda|derecha)\s+(?:de\s+)?(arriba|abajo)$') {
        # los grupos, copiados YA: un -match mas abajo se lleva $Matches
        $g1 = $Matches[1]; $g2 = $Matches[2]
        $vert = if ($g1 -match '^(?:arriba|abajo)$') { $g1 } else { $g2 }
        $hori = if ($g1 -match '^(?:izquierda|derecha)$') { $g1 } else { $g2 }
        return @(@{ kind = 'esquina'; valor = "$vert-$hori"; desc = "ponerse $vert a la $hori" })
    }
    if ($f -match '^(?:donde estas|en que esquina estas|donde te has puesto)$') {
        return @(@{ kind = 'dondeEstas'; desc = 'donde esta la capsula' })
    }

    # --- copiar lo que acaba de decir ---
    # Va antes de "copia esto" (que es un Ctrl+C sobre la ventana de delante):
    # son dos cosas distintas y el patron corto se quedaria con esta.
    if ($f -match '^(?:copia|copiame|guarda|guardame)\s+(?:la|el|lo|eso|esa)\s+(?:que\s+(?:me\s+)?(?:has\s+)?(?:dicho|dijiste)|respuesta|ultimo|ultima\s+respuesta|que\s+dice|de\s+la\s+tarjeta)$' -or
        $f -match '^copia(?:me)?\s+lo\s+(?:que\s+)?(?:has\s+)?(?:dicho|dijiste)$') {
        return @(@{ kind = 'copiarRespuesta'; desc = 'copiar la respuesta' })
    }

    # --- portapapeles ---
    # Va ANTES de anotar: si no, "apunta lo copiado" guardaria una nota que
    # dice, literalmente, "lo copiado".
    if ($f -match '^(?:apunta|anota|guarda)\s+(?:lo|el|eso|esto)\s+(?:que\s+tengo\s+)?(?:copiado|del portapapeles)$' -or
        $f -match '^guarda (?:esto|eso) en (?:mis )?(?:notas|la memoria|el diario)$') {
        return @(@{ kind = 'apuntarCopiado'; desc = 'guardar lo copiado' })
    }
    if ($f -match '^(?:copia|copiame|copiar)(?:\s+(?:esto|eso|lo|aqui))?$' -or
        $f -match '^copialo$') {
        return @(@{ kind = 'copiar'; desc = 'copiar' })
    }
    if ($f -match '^(?:pega|pegame|pegar)(?:\s+(?:esto|eso|lo|aqui|aca))?$' -or
        $f -match '^pegalo$') {
        return @(@{ kind = 'pegar'; desc = 'pegar' })
    }
    if ($f -match '^(?:que (?:tengo )?copiado|que copie|que hay en el portapapeles|que tengo en el portapapeles|que hay copiado)$') {
        return @(@{ kind = 'queCopiado'; desc = 'que tengo copiado' })
    }
    # EL DICTADO SE COME EL VERBO. "pon el volumen al setenta" llega como
    # "volumen al 70" mas veces de las que parece (medido en las grabaciones del
    # 12/09). Con un numero detras no hay ambiguedad: nadie dice "volumen al 70"
    # sin querer subirlo o bajarlo.
    if ($f -match '^(?:el\s+)?(?:volumen|sonido)\s+(?:al?\s+)?(\d{1,3})(?:\s*(?:%|por ciento))?$') {
        $n = [int]$Matches[1]
        if ($n -ge 0 -and $n -le 100) {
            return @(@{ kind = 'volumenPct'; nivel = $n; desc = "volumen al $n por ciento" })
        }
    }
    if ($f -match '^(?:el\s+)?brillo\s+(?:al?\s+)?(\d{1,3})(?:\s*(?:%|por ciento))?$') {
        $n = [int]$Matches[1]
        if ($n -ge 0 -and $n -le 100) {
            return @(@{ kind = 'brillo'; nivel = $n; desc = "brillo al $n por ciento" })
        }
    }
    # --- LISTAS ---
    # Van ANTES que "apunta ..." (que escribe en el diario), porque "apunta pan
    # en la lista de la compra" encaja tambien alli y acabaria como una linea
    # suelta de diario, que es justo lo que no sirve.
    if ($f -match '^(?:apunta|anota|anade|agrega|mete|pon|sumale|echa)\s+(.+?)\s+(?:en|a)\s+(?:la\s+|mi\s+)?lista(?:\s+de\s+(.+))?$') {
        $cosa = $Matches[1].Trim(); $cual = $Matches[2]
        if ($cosa) { return @(@{ kind = 'listaAdd'; cosa = $cosa; lista = $cual; desc = "apuntar $cosa" }) }
    }
    # copiar una lista al portapapeles para mandarla (13/09)
    if ($f -match '^(?:copia(?:me)?|pasame|comparte)\s+(?:la\s+|mi\s+)?lista(?:\s+de\s+(.+))?$') {
        return @(@{ kind = 'listaCopiar'; lista = $Matches[1]; desc = 'copiar la lista' })
    }
    if ($f -match '^(?:que|cuanto)\s+(?:tengo|hay|queda|me queda|falta)\s+(?:en\s+)?(?:la\s+|mi\s+)?lista(?:\s+de\s+(.+))?$' -or
        $f -match '^(?:lee|leeme|dime|dame|ensename|muestrame)\s+(?:la\s+|mi\s+)?lista(?:\s+de\s+(.+))?$' -or
        $f -match '^(?:la\s+)?lista(?:\s+de\s+(.+))?$') {
        return @(@{ kind = 'listaVer'; lista = $Matches[1]; desc = 'ver la lista' })
    }
    if ($f -match '^(?:que listas|cuantas listas|mis listas|que listas tengo|que listas hay)$') {
        return @(@{ kind = 'listaCuales'; desc = 'que listas tengo' })
    }
    # vaciar va ANTES de quitar una cosa: "borra la lista" encaja en los dos
    if ($f -match '^(?:borra|vacia|limpia|tira|quita)\s+(?:toda\s+)?(?:la\s+|mi\s+)?lista(?:\s+de\s+(.+))?$') {
        return @(@{ kind = 'listaVaciar'; lista = $Matches[1]; desc = 'vaciar la lista' })
    }
    if ($f -match '^(?:borra|quita|tacha|elimina|saca)\s+(?:el\s+|la\s+|lo\s+)?(.+?)\s+(?:de\s+)?(?:la\s+|mi\s+)?lista(?:\s+de\s+(.+))?$') {
        $cosa = $Matches[1].Trim(); $cual2 = $Matches[2]
        if ($cosa) { return @(@{ kind = 'listaQuitar'; cosa = $cosa; lista = $cual2; desc = "quitar $cosa de la lista" }) }
    }
    # CAMBIAR UN MODO HABLANDO va ANTES de anotar: "recuerda que en modo juego no abras
    # discord" es configurar el modo, no una nota para el diario (15/09, 11:40)
    $dModo = $null
    try { $dModo = Resolve-ModoPorVoz $f } catch { $dModo = $null }
    if ($dModo) {
        $qModo = if ($dModo.quitar) { "quitar '$($dModo.orden)' del modo $($dModo.modo)" } else { "anadir '$($dModo.orden)' al modo $($dModo.modo)" }
        return @(@{ kind = 'modoEditar'; datos = $dModo; desc = $qModo })
    }
    if ($f -match '^(?:recuerda|recuerdame|acuerdate|anota|apunta|guarda(?=\s+(?:que|de\s+que)\b)|memoriza)\s+(?!.*\s(?:en|a)\s+(?:la\s+|mi\s+)?lista(?:\s+de\s+.+)?$)(?!(?:en|dentro de)\s+(?:\d+|un|una|uno|medi[ao]|(?:un\s+)?cuarto\s+de|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis\S+|veinte|veinti\S+|treinta|cuarenta|cincuenta|sesenta|noventa)(?:\s+y\s+\S+)?\s+(?:segundos?|minutos?|horas?)\b)(?!(?:\d+|un|una|medi[ao]|(?:un\s+)?cuarto\s+de|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis\S+|veinte|veinti\S+|treinta|cuarenta|cincuenta|sesenta|noventa)(?:\s+y\s+\S+)?\s+(?:minutos?|horas?)(?:\s+y\s+media)?\s+antes\b)(?!(?:esto|eso|esta pantalla|lo de la pantalla|lo que dice la pantalla|lo que pone|este codigo|el codigo|la clave|la combinacion|esta clave|este numero)$)(?!(?:cual|cuales|que es|que fue|si|donde|cuando|quien|como|cuanto)\b)(?:que\s+|de\s+que\s+)?(.+)$') {
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
        # "en youtube pon lofi": el sitio vuelve al final, que es como lo entiende
        # "pon X en youtube" (14/09: sin esto, "pon lofi" suelto iba a la IA)
        if ($sitioForzado -eq 'youtube' -and $f -match '^(?:pon|ponme|reproduce|reproduceme|quiero ver|ver|toca)\s') { $f = "$f en youtube" }
    }
    # --- frases sociales: se contestan aqui, no valen 40 s de modelo ---
    switch -regex ($f) {
        '^(?:gracias|muchas gracias|mil gracias|te lo agradezco|gracias nova)$' { return @(@{ kind = 'decir'; desc = (@('De nada.', 'A ti.', 'Para eso estoy.', 'Cuando quieras.') | Get-Random) }) }
        '^(?:hola|hola nova|buenas|buenos dias|buenas tardes|buenas noches|que tal|que mas|que hay)$' { return @(@{ kind = 'decir'; desc = (@('Hola. Dime.', 'Aqui estoy. ¿Que hacemos?', 'Hola, te escucho.') | Get-Random) }) }
        '^(?:adios|chao|chau|hasta luego|nos vemos|me voy|hasta manana)$' { return @(@{ kind = 'decir'; desc = (@('Hasta luego.', 'Nos vemos.', 'Aqui estare.') | Get-Random) }) }
        # en plena conversacion estas ya no tienen respuesta fija: las contesta la charla (ver CONVERSACION DE VERDAD)
        '^(?:como estas|que tal estas|como vas|como te va|todo bien)$' { if (Test-CharlaCaliente) { return $null }; return @(@{ kind = 'decir'; desc = (@('Muy bien, lista para lo que digas.', 'De maravilla. ¿Y tu?', 'Bien, con ganas de trabajar.') | Get-Random) }) }
        '^(?:te quiero|te adoro|eres genial|eres la mejor|eres lo maximo|buen trabajo|bien hecho|me encantas)$' { if (Test-CharlaCaliente) { return $null }; return @(@{ kind = 'decir'; desc = (@('Y yo a ti.', 'Gracias, me sonrojo.', 'Eso me anima.') | Get-Random) }) }
        '^(?:quien eres|como te llamas|que eres)$' { return @(@{ kind = 'decir'; desc = "Soy $EscuchaNombre, tu asistente de la consola. Vivo en la esquina de abajo." }) }
        # "puedes" llega YA QUITADO por Remove-Filler (es lo que hace que
        # "puedes bajarle el volumen" funcione), asi que "que puedes hacer" se
        # ve aqui como "que hacer": hay que aceptar las dos formas
        '^(?:que (?:(?:puedes|podes|sabes|sabe)\s+)?hacer(?: tu| nova)?|que sabes? how to do|(?:en que|como) (?:me )?(?:(?:puedes|podes)\s+)?ayudar(?:me)?(?: tu| nova)?|para que sirves|ayuda|que haces)$' { return @(@{ kind = 'decir'; desc = 'Abro apps y juegos, busco, controlo volumen y brillo, escribo y pulso teclas, cierro ventanas, pongo temporizadores y reglas, anoto en tu memoria y le pregunto a la inteligencia artificial lo que no sepa.' }) }
    }
    # --- preguntas que se responden AQUI mismo, sin modelo ---
    # Preguntarle la hora a un LLM cuesta 13 s y encima puede negarse.
    switch -regex ($f) {
        # LA FRASE ENTERA (validacion, 15/09): con "\b" valia cualquier cosa detras, y la
        # frase de ejemplo de Whisper colaba "¿Que hora es Steam", "Que hora es la cancion"
        # o la tele ("¿Que hora es? Yo soy un...") como la hora: 5 de las 6 ordenes
        # equivocadas. Tambien "que hora es en tokio" daba la hora de aqui.
        '^(?:(?:dime\s+)?que hora es|(?:dime\s+)?que horas son|dime la hora|la hora)(?:\s+(?:ya|ahora|ahorita|por favor|porfa))?$' {
            $cul = New-Object System.Globalization.CultureInfo('es-MX')
            return @(@{ kind = 'decir'; desc = ("Son las " + (Get-Date).ToString('H:mm', $cul)) })
        }
        # 15/09: "¿cual es la fecha de hoy?" y "exacto, quiero saber que dia es hoy"
        # se iban a la charla, que contestaba que no tiene la fecha
        '^(?:(?:exacto|vale|ok|okey|si|correcto)\s+)?(?:(?:quiero saber|dime|sabes|me dices)\s+)?(?:que dia es|que fecha es|cual es la fecha|dime la fecha|que fecha|el dia de hoy)\b' {
            $cul = New-Object System.Globalization.CultureInfo('es-MX')
            return @(@{ kind = 'decir'; desc = ("Hoy es " + (Get-Date).ToString('dddd d "de" MMMM', $cul)) })
        }
        '^(?:cuanta bateria|cuanta pila|nivel de bateria|como esta la bateria|como esta la pila|cual es el estado de la bateria|estado de la bateria|cuanto le queda a la bateria|cuanta carga|como va la bateria|que tal la bateria)\b' {
            $t = Get-FraseBateria
            if (-not $t) { return @(@{ kind = 'decir'; desc = "No pude leer la bateria" }) }
            return @(@{ kind = 'decir'; desc = $t })
        }
        '^(?:cuantos juegos|que juegos tengo|mis juegos)\b' {
            return @(@{ kind = 'decir'; desc = ("Tienes " + @($script:Juegos).Count + " juegos instalados en Steam") })
        }
        # con ventana de tiempo PRIMERO: "deshaz todo lo de este minuto" tambien
        # encaja con el patron de abajo, y ese se quedaria solo con lo ultimo.
        '^(?:deshaz|deshacer|revierte|vuelve atras)\s+(?:todo\s+)?(?:lo\s+)?(?:que\s+has\s+hecho\s+)?(?:del?\s+|en\s+)?(?:(?:este|esta|el|la|los|las)\s+)?(?:(?:ultimo|ultima|ultimos|ultimas)\s+)?(?:(\d{1,3})\s*)?(minutos?|horas?|media hora|cuarto de hora)$' {
            # $Matches se pierde en cuanto haya otro -match: se copia ya
            $cuantos = $Matches[1]; $unidad = $Matches[2]
            $mins = switch -regex ($unidad) {
                '^media hora$'     { 30 }
                '^cuarto de hora$' { 15 }
                '^horas?$'         { 60 * $(if ($cuantos) { [int]$cuantos } else { 1 }) }
                default            { $(if ($cuantos) { [int]$cuantos } else { 1 }) }
            }
            return @(@{ kind = 'deshacerDesde'; minutos = $mins
                        desc = $(if ($mins -eq 1) { 'deshacer lo del ultimo minuto' }
                                 elseif ($mins -ge 60) { "deshacer lo de la ultima " + $(if ($mins -eq 60) { 'hora' } else { [int]($mins / 60).ToString() + ' horas' }) }
                                 else { "deshacer lo de los ultimos $mins minutos" }) })
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
    # "recuerdeme" / "recuerden" (validacion, 15/09): la forma de usted, asi lo oye Whisper
    # 15/09: "pon un temporizador PARA dos horas" y "¿puedes poner un temporizador de
    # cinco minutos?" se iban al agente (34 s). Faltaban "para/por", el infinitivo y
    # los numeros dichos con letras.
    if ($f -match '^(?:recuerdame|recuerdeme|recuerdenme|recuerden|avisame|despiertame|ponme un temporizador|pon un temporizador|poner un temporizador|pon temporizador|ponme una alarma|pon una alarma|poner una alarma|temporizador|alarma)\s+(?:en|de|para|por|dentro de)\s+(\d+|(?:un\s+)?cuarto\s+de|un|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|quince|veinte|treinta|cuarenta|cincuenta|sesenta|noventa|medi[ao])\s*(segundo|segundos|minuto|minutos|hora|horas)\b\s*(?:que|para|de|a)?\s*(.*)$') {
        $cuanto = $Matches[1]
        $unidad = $Matches[2]
        $que0 = $Matches[3]
        # "media hora" son 30 minutos, no media unidad de nada: se convierte
        # aqui y se dice en minutos, que es como se entiende al oirlo
        $mitad = ($cuanto -match '^medi[ao]$')
        # "un cuarto de hora": 15 minutos, dichos en minutos (nunca lo entendio)
        $cuarto = ($cuanto -match 'cuarto')
        if ($cuarto) { $unidad = 'minutos' }
        $palT = @{ 'un' = 1; 'una' = 1; 'dos' = 2; 'tres' = 3; 'cuatro' = 4; 'cinco' = 5; 'seis' = 6; 'siete' = 7
                   'ocho' = 8; 'nueve' = 9; 'diez' = 10; 'once' = 11; 'doce' = 12; 'quince' = 15; 'veinte' = 20
                   'treinta' = 30; 'cuarenta' = 40; 'cincuenta' = 50; 'sesenta' = 60; 'noventa' = 90 }
        $n = if ($mitad) { 30 } elseif ($cuarto) { 15 } elseif ($cuanto -match '^\d+$') { [int]$cuanto }
             elseif ($palT.ContainsKey($cuanto)) { $palT[$cuanto] } else { 1 }
        if ($mitad) {
            $unidad = if ($unidad -like 'hora*') { 'minutos' } else { 'segundos' }
            if ($unidad -eq 'segundos') { $n = 30 }
        }
        $que = $que0.Trim()
        $ms = switch -regex ($unidad) {
            '^segundo' { $n * 1000 }
            '^minuto' { $n * 60000 }
            default { $n * 3600000 }
        }
        if ($ms -le 0) { return $null }
        $desc = if ($que) { "aviso en $n $unidad" } else { "temporizador de $n $unidad" }
        return @(@{ kind = 'temporizador'; ms = $ms; texto = $que; n = $n; unidad = $unidad; desc = $desc })
    }
    # --- modo de energia (ver MODO DE ENERGIA POR VOZ) ---
    if ($f -match '^(?:modo|pon(?:me)?\s+(?:el\s+)?modo|activa\s+(?:el\s+)?modo|cambia\s+a\s+modo)\s+(ahorro(?: de (?:energia|bateria))?|bajo consumo|eficiencia|rendimiento|maximo rendimiento|alto rendimiento|equilibrado)$' -or
        $f -match '^(ahorra bateria|ahorra energia|ahorremos bateria)$') {
        $pedido = [string]$Matches[1]
        $modoE = if ($pedido -match 'rendimiento') { 'rendimiento' } elseif ($pedido -match 'equilibrado') { 'equilibrado' } else { 'ahorro' }
        return @(@{ kind = 'energia'; modo = $modoE; desc = "modo $modoE" })
    }
    if ($f -match '^(?:que modo de energia (?:tengo|hay|esta puesto|uso)|en que modo de energia estoy|como esta la energia)$') {
        return @(@{ kind = 'energia'; modo = 'consulta'; desc = 'modo de energia' })
    }
    # --- bluetooth y wifi (ver BLUETOOTH Y WI-FI POR VOZ) ---
    if ($f -match '^(apaga|desactiva|quita|desconecta|enciende|activa|prende|pon|conecta)\s+(?:el\s+|la\s+)?(bluetooth|wifi|wi fi|wi-fi|internet inalambrico)$') {
        # OJO (15/09): el -match de $encR machaca $Matches, y "activa el bluetooth" encendia el wifi
        $verboR = $Matches[1]; $radioR = $Matches[2]
        $encR = ($verboR -match '^(?:enciende|activa|prende|pon|conecta)$')
        $tipoR = if ($radioR -eq 'bluetooth') { 'bluetooth' } else { 'wifi' }
        return @(@{ kind = 'radio'; tipo = $tipoR; encender = $encR; desc = "$(if ($encR) { 'encender' } else { 'apagar' }) el $tipoR" })
    }
    # --- tiempo de juego (ver TIEMPO DE JUEGO DE LA SEMANA) ---
    if ($f -match '^(?:cuanto|cuanto tiempo|a que)\s+he\s+jugado(?:\s+(esta semana|hoy|este mes|estos dias))?$') {
        $perJ = [string]$Matches[1]
        $diasJ = if ($perJ -eq 'hoy') { 1 } elseif ($perJ -eq 'este mes') { 30 } else { 7 }
        return @(@{ kind = 'tiempoSemana'; dias = $diasJ; periodo = $(if ($perJ) { $perJ } else { 'esta semana' }); desc = 'tiempo de juego' })
    }
    # --- salida de sonido (ver SALIDA DE SONIDO POR VOZ) ---
    if ($f -match '^(?:pon|cambia|pasa|manda|saca)\s+(?:el\s+)?(?:sonido|audio)\s+(?:a|en|por)\s+(?:los\s+|las\s+|el\s+|la\s+|mis\s+)?(.+)$' -or
        $f -match '^(?:cambia|pon)\s+la\s+salida\s+(?:de\s+(?:audio|sonido)\s+)?(?:a|en|por)\s+(?:los\s+|las\s+|el\s+|la\s+|mis\s+)?(.+)$' -or
        $f -match '^(?:vuelve|regresa|cambia)\s+a\s+(?:los\s+|las\s+|mis\s+)?(altavoces|bocinas|parlantes|cascos|auriculares|audifonos)$') {
        return @(@{ kind = 'salidaAudio'; quiere = [string]$Matches[1]; desc = 'cambiar la salida de sonido' })
    }
    if ($f -match '^(?:por donde suena(?: el sonido)?|que salida de (?:audio|sonido) tengo|donde suena el sonido|que altavoces uso)$') {
        return @(@{ kind = 'salidaAudio'; quiere = ''; desc = 'salida de sonido' })
    }
    # --- la ultima captura (ver LA ULTIMA CAPTURA) ---
    if ($f -match '^(?:copia(?:me)?|pasame|pon en el portapapeles)\s+la\s+ultima\s+captura(?:\s+de\s+pantalla)?$') {
        return @(@{ kind = 'ultimaCaptura'; accion = 'copiar'; desc = 'copiar la ultima captura' })
    }
    if ($f -match '^(?:ensename|muestrame|abre(?:me)?|ver)\s+la\s+ultima\s+captura(?:\s+de\s+pantalla)?$') {
        return @(@{ kind = 'ultimaCaptura'; accion = 'abrir'; desc = 'abrir la ultima captura' })
    }
    # --- esconderse un rato (ver ESCONDERSE UN RATO) ---
    if ($f -match '^(?:escondete|ocultate|quitate|desaparece|retirate)\s+(?:durante\s+|por\s+|unos?\s+|un\s+)?(\d{1,3}|cinco|diez|quince|veinte|treinta|media|una)\s*(minutos?|horas?|hora)$') {
        $cantE = [string]$Matches[1]; $unidE = [string]$Matches[2]
        $palE = @{ 'cinco' = 5; 'diez' = 10; 'quince' = 15; 'veinte' = 20; 'treinta' = 30; 'media' = 30; 'una' = 60 }
        $minE = if ($cantE -match '^\d+$') { [int]$cantE } elseif ($palE.ContainsKey($cantE)) { $palE[$cantE] } else { 10 }
        if ($unidE -match '^hora' -and $cantE -notmatch '^(?:media|una)$') { $minE *= 60 }
        $minE = [Math]::Max(1, [Math]::Min(240, $minE))
        return @(@{ kind = 'esconderTiempo'; minutos = $minE; desc = "me escondo $minE minutos" })
    }
    # --- velocidad de la voz (ver VELOCIDAD DE LA VOZ) ---
    if ($f -match '^(?:habla(?:me)?\s+)?(?:mas|un poco mas)\s+(rapido|deprisa|lento|despacio)$' -or $f -match '^habla(?:me)?\s+(normal|a velocidad normal)$' -or $f -match '^(?:velocidad|voz)\s+(normal)$') {
        $pideV = [string]$Matches[1]
        $pasoV = if ($pideV -match '^(?:rapido|deprisa)$') { 15 } elseif ($pideV -match '^(?:lento|despacio)$') { -15 } else { 0 }
        return @(@{ kind = 'vozVelocidad'; paso = $pasoV; desc = 'velocidad de la voz' })
    }
    # --- modo foco (ver el vencimiento de los temporizadores) ---
    if ($f -match '^(?:modo foco|modo concentracion|concentrate|pomodoro|ponme en modo foco|ponte en modo foco|pon (?:el )?modo foco|activa el modo foco)(?:\s+(?:de|durante|por|en)?\s*(\d{1,3}|cinco|diez|quince|veinte|veinticinco|treinta|cuarenta|cuarenta y cinco|cincuenta|sesenta|media|una)\s*(minutos?|horas?|hora)?)?$') {
        $cantF = [string]$Matches[1]; $unidF = [string]$Matches[2]
        $palabrasF = @{ 'cinco' = 5; 'diez' = 10; 'quince' = 15; 'veinte' = 20; 'veinticinco' = 25; 'treinta' = 30; 'cuarenta' = 40; 'cuarenta y cinco' = 45; 'cincuenta' = 50; 'sesenta' = 60; 'media' = 30; 'una' = 60 }
        $minF = 25
        if ($cantF -match '^\d+$') { $minF = [int]$cantF } elseif ($palabrasF.ContainsKey($cantF)) { $minF = $palabrasF[$cantF] }
        if ($unidF -match '^hora' -and $cantF -notmatch '^(?:media|una)$') { $minF *= 60 }
        if ($minF -lt 1 -or $minF -gt 240) { $minF = 25 }
        return @(@{ kind = 'foco'; minutos = $minF; desc = "modo foco $minF minutos" })
    }
    if ($f -match '^(?:termina|acaba|cancela|quita|para|sal del)\s+(?:el\s+)?(?:modo foco|foco|pomodoro)$') {
        return @(@{ kind = 'focoFin'; desc = 'terminar el foco' })
    }
    # --- Discord (ver DISCORD POR VOZ) ---
    if ($f -match '^(?:silencia|silenciame|mutea|apaga|quita|desmutea|activa|enciende|cambia)\s+(?:mi|el)\s+(?:micro|microfono|mic)(?:\s+(?:de|en)\s+discord)?$' -or
        $f -match '^(?:silencia|mutea)(?:me)?\s+en\s+discord$') {
        return @(@{ kind = 'discordMicro'; desc = 'el micro de Discord' })
    }
    if ($f -match '^(?:ensordeceme|ensordece(?:me)?(?:\s+en)?\s+discord|no quiero oir discord|ensordecer discord|quita el ensordecer|des ?ensordeceme)$') {
        return @(@{ kind = 'discordSordo'; desc = 'ensordecer en Discord' })
    }
    # --- historial del portapapeles (ver HISTORIAL DEL PORTAPAPELES) ---
    if ($f -match '^(?:que copie antes|que habia copiado antes|que copie antes de esto|que tenia copiado antes|lo que copie antes)$') {
        return @(@{ kind = 'portaAnterior'; desc = 'lo que copiaste antes' })
    }
    if ($f -match '^(?:pega lo (?:penultimo|anterior|de antes)|pega lo que copie antes|pega lo que tenia copiado antes)$') {
        return @(@{ kind = 'pegarAnterior'; desc = 'pegar lo de antes' })
    }
    if ($f -match '^(?:que he copiado(?: hoy)?|historial del portapapeles|que copie hoy)$') {
        return @(@{ kind = 'portaHistorial'; desc = 'lo que has copiado' })
    }
    # --- en que nivel esta Nova (ver NOVA EVOLUCIONA) ---
    if ($f -match '^(?:que nivel tienes|en que nivel estas|cual es tu nivel|que nivel eres|cuanto has crecido|has subido de nivel)$') {
        return @(@{ kind = 'nivelNova'; desc = 'mi nivel' })
    }
    # --- que cancion suena (ver LA MUSICA EN LA CAPSULA) ---
    if ($f -match '^(?:que cancion es(?: esta)?|que cancion suena|que (?:esta sonando|suena)|como se llama (?:esta|la) cancion|de quien es (?:esta|la) cancion|que musica es esta)$') {
        return @(@{ kind = 'musicaQue'; desc = 'que suena' })
    }
    # --- contactos importantes (ver CONTACTOS IMPORTANTES) ---
    if ($f -match '^(?:avisame|dime)\s+(?:solo\s+)?(?:si|cuando)\s+me\s+escrib[ae]\s+(.+)$' -or
        $f -match '^(?:pon|anade|agrega|mete)\s+a\s+(.+?)\s+(?:en|a|como)\s+(?:mis\s+)?(?:contactos\s+)?importantes$') {
        return @(@{ kind = 'contactoImp'; accion = 'poner'; nombre = $Matches[1].Trim(); desc = 'contacto importante' })
    }
    if ($f -match '^(?:quita|borra|saca)\s+a\s+(.+?)\s+de\s+(?:mis\s+)?(?:contactos\s+)?importantes$') {
        return @(@{ kind = 'contactoImp'; accion = 'quitar'; nombre = $Matches[1].Trim(); desc = 'quitar contacto importante' })
    }
    if ($f -match '^(?:que|cuales son mis|quienes son mis)\s+contactos\s+importantes(?:\s+tengo)?$' -or $f -match '^mis contactos importantes$') {
        return @(@{ kind = 'contactoImp'; accion = 'ver'; nombre = ''; desc = 'contactos importantes' })
    }
    # --- brillo automatico por hora (ver BRILLO AUTOMATICO) ---
    if ($f -match '^(activa|pon|enciende|desactiva|quita|apaga)\s+(?:el\s+)?brillo\s+automatico$') {
        return @(@{ kind = 'brilloAuto'; activar = ($Matches[1] -match '^(?:activa|pon|enciende)$'); desc = 'brillo automatico' })
    }
    # --- los avisos por su cuenta (ver NOVA SE ENTERA DE LO QUE PASA) ---
    if ($f -match '^(?:no me avises|no avises|deja de avisarme|no me digas nada|no me molestes)(?:\s+de\s+nada)?$') {
        return @(@{ kind = 'avisosEntorno'; encendido = $false; desc = 'dejar de avisarte' })
    }
    if ($f -match '^(?:vuelve a avisarme|avisame otra vez|puedes avisarme|ya puedes avisarme)(?:\s+de\s+(?:todo|las cosas))?$') {
        return @(@{ kind = 'avisosEntorno'; encendido = $true; desc = 'volver a avisarte' })
    }
    # --- EL CORREO (16/09; ver Invoke-Correo) ---
    # "revisa mi correo" / "tengo correos nuevos" / "que correos tengo"
    if ($f -match '^(?:revisa|mira|lee|checa|chequea|ver|dime)?\s*(?:mi|el|los)?\s*(?:correo|correos|email|emails|gmail|mail|bandeja)(?:\s+(?:nuevos?|no leidos?|de hoy|pendientes?))?$' -or
        $f -match '^(?:tengo|hay|me llego|llego|me ha llegado)\s+(?:algun\s+|algunos\s+|correos?\s+|emails?\s+)*(?:correo|correos|email|emails|mail)(?:\s+(?:nuevos?|no leidos?|importantes?))?$' -or
        $f -match '^(?:que|cuantos)\s+correos?\s+(?:tengo|hay|me\s+(?:han\s+)?(?:llegado|escrito))(?:\s+(?:nuevos?|hoy))?$') {
        return @(@{ kind = 'correo'; accion = 'no-leidos'; desc = 'tu correo' })
    }
    # "leeme el ultimo correo": ese SI trae el cuerpo, porque lo has pedido
    if ($f -match '^(?:lee(?:me)?|abre(?:me)?|dime|que dice)\s+(?:el\s+)?(?:ultimo|primer|primero)?\s*(?:correo|email|mail)(?:\s+(?:entero|completo|de que va))?$' -or
        $f -match '^(?:de que va|que dice)\s+(?:el\s+)?(?:ultimo\s+)?(?:correo|email|mail)$') {
        return @(@{ kind = 'correo'; accion = 'leer'; desc = 'leer el ultimo correo' })
    }
    # "contestale que voy en camino" / "responde al correo que llego tarde"
    if ($f -match '^(?:contesta(?:le)?|responde(?:le)?|respondele)\s+(?:al?\s+)?(?:correo|email|mail)?\s*(?:que|diciendo|con)\s+(.{3,400})$') {
        return @(@{ kind = 'correo'; accion = 'responder'; texto = $Matches[1].Trim(); desc = 'responder al correo' })
    }
    # "manda un correo a lucia diciendo que llego tarde"
    if ($f -match '^(?:manda(?:le)?|envia(?:le)?|escribe(?:le)?)\s+(?:un\s+|el\s+)?(?:correo|email|mail)\s+a\s+(\S+@\S+|[a-z0-9 ._-]{2,40}?)\s+(?:que|diciendo(?:\s+que)?|con(?:\s+el\s+texto)?)\s+(.{3,400})$') {
        return @(@{ kind = 'correo'; accion = 'enviar'; destino = $Matches[1].Trim(); texto = $Matches[2].Trim(); desc = 'mandar un correo' })
    }

    # --- notificaciones (ver NOTIFICACIONES MIENTRAS JUEGAS) ---
    if ($f -match '^(?:que me han escrito|quien me ha escrito|(?:me )?ha escrito alguien|(?:me )?escribio alguien|tengo (?:mensajes|notificaciones)(?: nuevos| nuevas)?|que (?:mensajes|notificaciones) tengo|hay mensajes(?: nuevos)?|alguna notificacion|algun mensaje)$') {
        return @(@{ kind = 'notifResumen'; desc = 'tus mensajes' })
    }
    # sin "que me dicen": es demasiado corriente y leeria tus mensajes en voz alta
    # si alguien lo dice cerca (revision del 13/09)
    if ($f -match '^(?:leemelos|leemelas|lee(?:me)? (?:los mensajes|las notificaciones)|leeme lo que me han escrito)$') {
        return @(@{ kind = 'notifLeer'; desc = 'leer tus mensajes' })
    }
    # --- ¿me da para jugar hasta las 12? (13/09) ---
    if ($f -match '^(?:me\s+)?(?:da|alcanza|llego)\s+(?:con\s+)?(?:la\s+(?:bateria|pila)\s+)?(?:para\s+(?:jugar|seguir|estar|aguantar)\s+)?hasta\s+las?\s+(\d{1,2})(?:[:\s](\d{2}))?(?:\s+(?:de la (?:noche|tarde|manana)))?$') {
        return @(@{ kind = 'bateriaHasta'; hora = [int]$Matches[1]; minuto = $(if ($Matches[2]) { [int]$Matches[2] } else { 0 }); desc = 'si te da la bateria' })
    }
    # --- cuanto me dura la bateria con esto (ver BATERIA POR JUEGO) ---
    if ($f -match '^(?:cuanto me (?:dura|va a durar|aguanta) la (?:bateria|pila)|cuanto (?:aguanta|dura) la (?:bateria|pila)|cuanto (?:me )?(?:dura|aguanta) la (?:bateria|pila) (?:con esto|jugando|con este juego)|(?:me )?(?:da|alcanza) la (?:bateria|pila)(?: para (?:terminar|acabar|jugar|otra partida|un rato))?|cuanto puedo jugar(?: con la (?:bateria|pila))?)$') {
        return @(@{ kind = 'duracionBateria'; desc = 'cuanto dura la bateria' })
    }
    # --- donde me quede (ver JUEGOS) ---
    if ($f -match '^(?:donde me quede|en que me quede|por donde iba|donde lo deje|donde me habia quedado|en que parte me quede|por donde me quede)(?:\s+(?:en|con)\s+(.+))?$') {
        return @(@{ kind = 'dondeMeQuede'; juego = [string]$Matches[1]; desc = 'donde te quedaste' })
    }
    # --- como esta configurada ---
    if ($f -match '^(?:como (?:estas|te tengo) (?:configurada|puesta|ajustada)|(?:cual es|dime|ensename|muestrame|que es)?\s*(?:tu|la) configuracion|que configuracion tienes|como tienes todo puesto|que ajustes tienes)$') {
        return @(@{ kind = 'configuracion'; desc = 'mi configuracion' })
    }
    # --- la tarjeta larga: fijarla y quitarla ---
    if ($f -match '^(?:dejala(?: ahi)?|deja la tarjeta(?: ahi)?|fija la tarjeta|fijala|no la quites|no quites la tarjeta|deja(?:la)? (?:la tarjeta )?(?:abierta|puesta)|dejala abierta|dejala puesta|espera no la quites)$') {
        return @(@{ kind = 'fijarTarjeta'; desc = 'dejar la tarjeta' })
    }
    if ($f -match '^(?:quitala|quita la tarjeta|cierra la tarjeta|cierrala|ya la lei|ya esta leida|ya puedes quitarla|quita eso de la pantalla)$') {
        return @(@{ kind = 'quitarTarjeta'; desc = 'quitar la tarjeta' })
    }
    # --- el balance de lo aprendido ---
    if ($f -match '^(?:cuanto has aprendido|cuanto me has ahorrado|cuanto tiempo me has ahorrado|que tal vas aprendiendo|como vas aprendiendo|como va tu aprendizaje|cuanto sabes ya|que tanto has aprendido)$') {
        return @(@{ kind = 'balanceAprendizaje'; desc = 'lo aprendido' })
    }
    # --- lo que Nova sabe de ti ---
    if ($f -match '^(?:que sabes de mi|que sabes sobre mi|que has aprendido de mi|que sabes de braya|que conoces de mi|que sabes de mi vida|que tienes anotado (?:sobre|de) mi|que tienes apuntado (?:sobre|de) mi|que has anotado (?:sobre|de) mi)$') {
        return @(@{ kind = 'verPerfil'; desc = 'lo que se de ti' })
    }
    # --- recetas aprendidas: verlas y olvidarlas ---
    if ($f -match '^(?:que (?:has aprendido|aprendiste|recetas tienes|sabes hacer sola)(?:\s+(?:hoy|ayer|de la ultima sesion|en la ultima sesion|de la sesion|esta sesion|ultimamente))?|que tareas (?:has aprendido|sabes hacer)|mis recetas|lista (?:las )?recetas|dime (?:las )?recetas)$') {
        return @(@{ kind = 'verRecetas'; desc = 'recetas aprendidas' })
    }
    if ($f -match '^(?:olvida|borra|elimina)\s+(?:esa receta|la ultima receta|la receta|lo ultimo que aprendiste|lo que acabas de aprender)$') {
        return @(@{ kind = 'olvidarReceta'; desc = 'olvidar la receta' })
    }
    # --- "no era eso": deshacer Y no repetir el error ---
    if ($f -match '^(?:no era eso|eso no era|no era esto|no te pedi eso|eso no|no queria eso|no era lo que dije)$') {
        return @(@{ kind = 'noEraEso'; desc = 'deshacer y olvidar esa interpretacion' })
    }
    # --- en que fallo ---
    if ($f -match '^(?:que (?:me )?(?:estas |estoy )?entend\w* mal|en que fall\w*|que (?:no )?(?:entiendes|te cuesta|se te atraganta)|que se te atraganta|donde fall\w*)\b') {
        return @(@{ kind = 'queFallo'; desc = 'en que fallo' })
    }
    # --- UN temporizador concreto: cuanto le queda, pausa, reanudar, cancelar (13/09) ---
    if ($f -match '^(?:cuanto (?:le )?(?:queda|falta)|que le queda)\s+(?:al temporizador de(?:l| la)?|a la alarma de(?:l| la)?|a la|al|a)\s+(.+)$') {
        return @(@{ kind = 'tempoUno'; accion = 'ver'; que = $Matches[1].Trim(); desc = 'cuanto queda' })
    }
    if ($f -match '^(?:pausa|para|deten)\s+(?:el\s+)?(?:temporizador|la alarma|la cuenta atras)(?:\s+de(?:l| la)?\s+(.+))?$') {
        return @(@{ kind = 'tempoUno'; accion = 'pausar'; que = [string]$Matches[1]; desc = 'pausar el temporizador' })
    }
    if ($f -match '^(?:reanuda|sigue con|continua|quita la pausa a|quita la pausa al)\s+(?:el\s+)?(?:temporizador|la alarma|la cuenta atras)(?:\s+de(?:l| la)?\s+(.+))?$') {
        return @(@{ kind = 'tempoUno'; accion = 'reanudar'; que = [string]$Matches[1]; desc = 'reanudar el temporizador' })
    }
    if ($f -match '^(?:cancela|quita|borra|anula)\s+(?:el\s+)?(?:temporizador|la alarma|el aviso)\s+de(?:l| la)?\s+(.+)$') {
        return @(@{ kind = 'tempoUno'; accion = 'cancelar'; que = $Matches[1].Trim(); desc = 'cancelar ese temporizador' })
    }
    # --- temporizadores: consultar y cancelar ---
    if ($f -match '^(?:cuanto (?:queda|falta)|que queda)\s*(?:del?\s+)?(?:temporizador|aviso|alarma|cuenta atras)?$' -or
        $f -match '^(?:tengo|hay)\s+(?:algun\s+)?(?:temporizador|aviso|alarma)\b' -or
        $f -match '^(?:que|cuantos)\s+(?:temporizadores|avisos|alarmas)\s+(?:tengo|hay)\b') {
        return @(@{ kind = 'verTempo'; desc = 'temporizadores' })
    }
    if ($f -match '^(?:cancela|quita|borra|anula|para)\s+(?:el\s+|los\s+|la\s+|las\s+)?(?:temporizador|temporizadores|aviso|avisos|alarma|alarmas|cuenta atras)$') {
        return @(@{ kind = 'quitarTempo'; desc = 'cancelar temporizadores' })
    }
    # CLIP DEL JUEGO (F1): la Game Bar guarda lo ultimo que ha pasado
    # ("guarda lo ultimo" ya era copiar la respuesta: no se pisa)
    if ($f -match '^(?:guarda|graba|guardame|grabame|salva)\s+(?:el\s+clip|un\s+clip|lo\s+que\s+(?:acaba\s+de\s+pasar|ha\s+pasado)|los\s+ultimos\s+\d+\s+segundos|la\s+jugada)$' -or
        $f -match '^(?:clip|clipealo|clipea\s+eso|haz(?:me)?\s+un\s+clip)$') {
        return @(@{ kind = 'clipJuego'; desc = 'guardar el clip' })
    }
    # AMIGOS CONECTADOS (F9)
    if ($f -match '^(?:quien|quienes)\s+(?:de\s+mis\s+amigos\s+)?(?:esta|estan)\s+(?:conectados?|en\s+linea|jugando)(?:\s+en\s+(steam|discord))?$' -or
        $f -match '^(?:hay\s+)?(?:algun\s+amigo|alguien)\s+(?:conectado|en\s+linea)(?:\s+en\s+(steam|discord))?$' -or
        $f -match '^que\s+amigos\s+(?:estan|hay)\s+(?:conectados|en\s+linea)(?:\s+en\s+(steam|discord))?$') {
        if ($Matches[1] -eq 'discord') { return @(@{ kind = 'amigosDiscord'; desc = 'amigos en Discord' }) }
        return @(@{ kind = 'amigosSteam'; desc = 'amigos conectados' })
    }
    # HISTORIAL DE MUSICA (F10)
    if ($f -match '^(?:como se llamaba|cual era|que cancion era)\s+(?:esa|la)\s+cancion(?:\s+de\s+antes)?$') {
        return @(@{ kind = 'musicaAnterior'; desc = 'la cancion de antes' })
    }
    if ($f -match '^(?:pon(?:me)?|vuelve\s+a\s+poner|busca(?:me)?)\s+la\s+(?:cancion\s+)?que\s+(?:sonaba|estaba\s+sonando|escuchaba|estaba\s+escuchando)\s+(antes|hace un rato|esta manana|anoche|ayer por la noche|ayer por la manana|ayer por la tarde|ayer)$') {
        return @(@{ kind = 'musicaDe'; cuando = $Matches[1]; desc = 'la cancion de ' + $Matches[1] })
    }
    # DESCARGAS DE STEAM (F5): cuanto le queda a un juego, que se esta bajando, y
    # abrir la pagina de descargas (pausar desde fuera no se puede)
    if ($f -match '^(?:cuanto\s+(?:le\s+)?(?:queda|falta)\s+(?:a|al)\s+|como\s+va\s+(?:la\s+descarga\s+de\s+)?)(.+?)(?:\s+(?:para|de|en)\s+(?:descargar(?:se)?|bajar(?:se)?|instalar(?:se)?))?$' -and
        @($script:Juegos | Where-Object { $_.bajando }).Count -gt 0) {
        $txtD = $null
        try { $txtD = Get-DescargaJuego $Matches[1] } catch { $txtD = $null }
        if ($txtD) { return @(@{ kind = 'descargaJuego'; texto = $txtD; desc = $txtD }) }
    }
    if ($f -match '^(pausa|para|deten|reanuda|abre|ensename|muestrame)\s+(?:las\s+)?descargas(?:\s+de\s+steam)?$') {
        return @(@{ kind = 'descargasAbrir'; pausar = ($Matches[1] -match '^(?:pausa|para|deten|reanuda)$'); desc = 'las descargas de Steam' })
    }
    if ($f -match '^que\s+(?:se\s+)?(?:esta|estan)\s+(?:descargando|bajando|actualizando)(?:\s+en\s+steam)?$') {
        return @(@{ kind = 'descargas'; desc = 'estado de las descargas' })
    }
    # 15/09: "¿hay algo descargandose en Steam?" y "revisa ahora si algo se esta
    # descargando" se fueron al agente (37 s y 25 s) teniendo el dato ya leido
    if ($f -match '^(?:revisa\s+(?:ahora\s+)?)?(?:hay\s+)?algo\s+(?:que\s+se\s+(?:este|esta)\s+)?(?:descargando(?:se)?|bajando(?:se)?|instalando(?:se)?|actualizando(?:se)?)(?:\s+en\s+steam)?$' -or
        $f -match '^revisa\s+(?:ahora\s+)?si\s+(?:hay\s+)?algo\s+se\s+esta\s+(?:descargando|bajando|instalando)(?:\s+en\s+steam)?$' -or
        $f -match '^(?:en\s+)?cuanto\s+(?:va|esta|le\s+queda\s+a)\s+la\s+descarga(?:\s+de\s+steam)?$') {
        return @(@{ kind = 'descargas'; desc = 'estado de las descargas' })
    }
    # --- descargas de Steam (datos que ya se leen al arrancar) ---
    if ($f -match '^(?:como va|que tal va|en que va|cuanto queda de)\s+(?:la\s+)?(?:descarga|bajada|instalacion)\b') {
        return @(@{ kind = 'descargas'; desc = 'estado de las descargas' })
    }
    if ($f -match '^(?:hay|queda|falta)\s+(?:alguna\s+)?descarga\b') {
        return @(@{ kind = 'descargas'; desc = 'estado de las descargas' })
    }
    # --- que tengo en el escritorio (15/09: 44 s de agente para leer una carpeta) ---
    if ($f -match '^(?:que\s+(?:tengo|hay)|dime\s+que\s+(?:tengo|hay)|ensename\s+(?:lo\s+que\s+(?:tengo|hay)|el\s+contenido\s+de))\s+en\s+(?:mi\s+|el\s+)?escritorio$') {
        $escD = [Environment]::GetFolderPath('Desktop')
        $itemsD = @()
        try {
            $itemsD = @(Get-ChildItem -LiteralPath $escD -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -ne 'desktop.ini' } | Sort-Object Name)
        } catch { $itemsD = @() }
        if ($itemsD.Count -eq 0) { return @(@{ kind = 'decir'; desc = 'No hay nada en tu escritorio' }) }
        $nomsD = @($itemsD | ForEach-Object { $_.Name -replace '\.(?:lnk|url)$', '' } | Select-Object -First 12)
        # dicho en voz alta, "tienes 3:" suena a medias (probado en vivo el 16/09)
        $textoD = "En el escritorio tienes $($itemsD.Count) $(if ($itemsD.Count -eq 1) { 'cosa' } else { 'cosas' }): " + ($nomsD -join ', ')
        if ($itemsD.Count -gt $nomsD.Count) { $textoD += " y $($itemsD.Count - $nomsD.Count) mas" }
        return @(@{ kind = 'decir'; desc = $textoD })
    }
    # --- espacio en disco: "¿cabe la siguiente?" ---
    # "que espacio tengo disponible" y "cuanto espacio libre me queda en la consola" (15/09)
    if ($f -match '^(?:cuanto\s+)?(?:espacio|disco|sitio)\s*(?:me\s+)?(?:queda|libre|hay|tengo)?$' -or
        $f -match '^cuanto (?:espacio|sitio) (?:me )?(?:queda|hay|tengo)\b' -or
        $f -match '^(?:que|cuanto)\s+(?:espacio|sitio)\s+(?:libre\s+|disponible\s+)?(?:me\s+)?(?:queda|hay|tengo)(?:\s+(?:libre|disponible))?\b') {
        return @(@{ kind = 'disco'; desc = 'espacio libre' })
    }
    # --- DICTADO LARGO ---
    # El dictado de siempre es para ordenes cortas; para escribir un mensaje no
    # sirve. Esto entra en modo continuo escribiendo en la ventana de delante.
    # con destino: "dicta un correo en el bloc de notas", "dicta en discord"
    if ($f -match '^(?:dicta|dictame|escribe|toma)\s+(?:un\s+|una\s+|el\s+|la\s+)?(?:correo|mensaje|texto|nota larga|dictado|carta|email|whatsapp)?\s*(?:en|a)\s+(?:el\s+|la\s+|los\s+)?(.+)$' -or
        $f -match '^(?:empieza|empezar|entra)\s+(?:a\s+|en\s+(?:modo\s+)?)?dicta(?:r|do)\s+(?:en|a)\s+(?:el\s+|la\s+)?(.+)$') {
        $donde = $Matches[1].Trim()
        $pr = Resolve-Proceso $donde
        if ($pr) {
            # con que se abre, por si no lo esta: sale del mismo commands.json
            # que usa "abre el bloc de notas"
            $conQue = $null
            $objN = @(Resolve-Target $donde)
            if ($objN.Count -gt 0 -and $objN[0].kind -eq 'app' -and $objN[0].target) { $conQue = [string]$objN[0].target }
            return @(@{ kind = 'dictadoLargo'; proceso = $pr.proceso; abrir = $conQue
                        desc = "dictado largo en $($pr.nombre)" })
        }
        # si no se sabe a que app se refiere, NO se entra a ciegas: escribir en
        # la ventana equivocada es peor que no escribir
        return @(@{ kind = 'decir'; desc = "no se cual es $donde. Ponla delante y dime dicta un correo" })
    }
    if ($f -match '^(?:dicta|dictame|escribe|toma)\s+(?:un\s+|una\s+|el\s+|la\s+)?(?:correo|mensaje|texto|nota larga|dictado|carta|email|whatsapp)$' -or
        $f -match '^(?:empieza|empezar|entra)\s+(?:a\s+|en\s+(?:modo\s+)?)?dicta(?:r|do)$' -or
        $f -match '^(?:modo\s+)?dictado(?:\s+largo)?$' -or
        $f -match '^(?:voy a|quiero)\s+dictar$') {
        return @(@{ kind = 'dictadoLargo'; desc = 'dictado largo' })
    }
    # --- ORDENES DE VENTANA SOBRE UNA APP POR SU NOMBRE ---
    # Todo lo de ventanas actuaba solo sobre la que tiene el foco, que es justo
    # la que NO quieres tocar mientras juegas: para minimizar Spotify habia que
    # ponerlo delante primero, o sea salir del juego. Esto va directo a la
    # ventana de la app que digas y NO le roba el foco a nadie.
    # Va antes que "minimiza todo" no, DESPUES: esa es mas concreta y ya existe.
    # sin "baja": "baja spotify" es bajarle el volumen, no minimizarlo (auditoria 13/09)
    if ($f -match '^(?:minimiza|minimizar|esconde|oculta|guarda)\s+(?:el\s+|la\s+|a\s+)?(.+)$') {
        $obj = $Matches[1].Trim()
        # "guarda el archivo" es Ctrl+S, no "minimiza el Explorador de archivos"
        # (Resolve-Proceso encontraba "archivos" por parecido)
        if ($obj -notmatch '^(?:todo|todas|el escritorio|escritorio|la pagina|el tamano|tamano|(?:los |el )?(?:archivos?|documentos?|cambios|trabajo))$') {
            $proc = Resolve-Proceso $obj
            if ($proc) { return @(@{ kind = 'ventanaApp'; proceso = $proc.proceso; accion = 'minimizar'; desc = "minimizar $($proc.nombre)" }) }
            # "minimiza zorglub": se dice que no esta, en vez de mandarlo a la IA (14/09).
            # Solo con "minimiza": "guarda el clip" o "esconde..." siguen su camino
            if ($f -match '^(?:minimiza|minimizar)\s') { return @(@{ kind = 'decir'; desc = "no veo ninguna ventana de $obj" }) }
        }
    }
    if ($f -match '^(?:maximiza|maximizar|agranda|abre del todo)\s+(?:el\s+|la\s+|a\s+)?(.+)$') {
        $obj = $Matches[1].Trim()
        if ($obj -notmatch '^(?:el tamano|tamano)$') {
            $proc = Resolve-Proceso $obj
            if ($proc) { return @(@{ kind = 'ventanaApp'; proceso = $proc.proceso; accion = 'maximizar'; desc = "maximizar $($proc.nombre)" }) }
        }
    }
    if ($f -match '^(?:restaura|restaurar|recupera|saca)\s+(?:el\s+|la\s+|a\s+)?(.+)$') {
        $proc = Resolve-Proceso ($Matches[1].Trim())
        if ($proc) { return @(@{ kind = 'ventanaApp'; proceso = $proc.proceso; accion = 'restaurar'; desc = "restaurar $($proc.nombre)" }) }
    }
    if ($f -match '^(?:manda|mandale|envia|pasa|mueve|llevate|lleva)\s+(?:el\s+|la\s+|a\s+)?(.+?)\s+(?:a|al)\s+(?:el\s+|la\s+)?(?:otr[oa]|segund[oa])\s+(?:monitor|pantalla)$') {
        $proc = Resolve-Proceso ($Matches[1].Trim())
        if ($proc) { return @(@{ kind = 'ventanaApp'; proceso = $proc.proceso; accion = 'otroMonitor'; desc = "mandar $($proc.nombre) al otro monitor" }) }
    }
    # --- MOVERSE POR UN MENU SIN SOLTAR EL MANDO ---
    # Con un juego a pantalla completa, esto es lo unico que no se podia hacer
    # hablando: habia "pulsa abajo", pero una sola vez, y un menu son cinco.
    # "abajo tres veces", "izquierda dos", "atras", "acepta".
    # Son FLECHAS, no pagina arriba/abajo: en un menu, avanzar de pagina no
    # mueve la seleccion. Por eso "baja" a secas se deja como estaba (sigue
    # siendo pagina abajo, que es lo que hace falta en el navegador) y solo se
    # convierte en flecha cuando dices cuantas veces.
    $DIRECCIONES = @{
        'abajo' = 0x28; 'arriba' = 0x26; 'izquierda' = 0x25; 'derecha' = 0x27
        'atras' = 0x1B; 'acepta' = 0x0D; 'aceptar' = 0x0D; 'entra' = 0x0D
        'entrar' = 0x0D; 'confirma' = 0x0D; 'adelante' = 0x0D
    }
    # "adelante" A SECAS ya no pulsa (validacion, 15/09): "abre steam" dicho desde lejos se
    # oyo "Adelante" y pulso la tecla. Con verbo ("pulsa adelante") sigue valiendo.
    if ($f -match '^(?!adelante$)(?:(?:pulsa|presiona|dale a|dale al|ve|vete|muevete|mueve|desplazate)\s+)?(?:la\s+|el\s+|tecla\s+|flecha\s+|hacia\s+|a la\s+|al\s+)?(abajo|arriba|izquierda|derecha|atras|acepta|aceptar|entra|entrar|confirma|adelante)(?:\s+(\d{1,2}|\w+)\s*(?:veces|vez))?$') {
        # $Matches se pisa con el siguiente -match: se copia ya
        $dir = $Matches[1]; $cuantas = $Matches[2]
        $veces = Get-Veces $cuantas
        $comoSeDice = if ($veces -gt 1) { "$dir $veces veces" } else { $dir }
        return @(@{ kind = 'key'; vk = $DIRECCIONES[$dir]; repeat = $veces; desc = "pulsar $comoSeDice" })
    }
    # y los verbos de desplazar, SOLO cuando dices cuantas: ahi ya no hablas de
    # la pagina, hablas de moverte por una lista
    if ($f -match '^(baja|bajar|sube|subir)\s+(\d{1,2}|\w+)\s*(?:veces|vez)$') {
        $verbo = $Matches[1]; $cuantas2 = $Matches[2]
        $veces = Get-Veces $cuantas2
        $vk = if ($verbo -like 'baj*') { 0x28 } else { 0x26 }
        $comoSeDice = if ($verbo -like 'baj*') { 'abajo' } else { 'arriba' }
        return @(@{ kind = 'key'; vk = $vk; repeat = $veces; desc = "pulsar $comoSeDice $veces veces" })
    }
    # --- el tamano de la capsula, a peticion ---
    # OJO: "hazte mas grande" llega aqui como "hazte mas grande", pero "ponte
    # mas grande" pasa antes por Repair-Verb, que arregla el verbo de cabeza por
    # parecido y convierte "ponte" en "ponme". Por eso estan las dos formas.
    if ($f -match '^(?:(?:hazte|ponte|ponme|vuelvete|hazte ver)\s+)?(?:un poco\s+)?(?:mas\s+)(?:grande|grandota|mayor)$' -or
        $f -match '^(?:aumenta|agranda)(?:\s+(?:el\s+)?tamano)?$' -or
        $f -match '^(?:sube|aumenta|agranda)\s+(?:el\s+)?tamano$' -or
        $f -match '^(?:que\s+)?no te veo\s*(?:bien|nada)?$') {
        return @(@{ kind = 'escalaUI'; paso = 1; desc = 'hacerse mas grande' })
    }
    if ($f -match '^(?:(?:hazte|ponte|ponme|vuelvete)\s+)?(?:un poco\s+)?(?:mas\s+)(?:pequena|pequeno|chica|chico|chiquita)$' -or
        $f -match '^(?:reduce|achica|encoge)(?:\s+(?:el\s+)?tamano)?$' -or
        $f -match '^(?:baja|reduce|achica|encoge)\s+(?:el\s+)?tamano$') {
        return @(@{ kind = 'escalaUI'; paso = -1; desc = 'hacerse mas pequena' })
    }
    if ($f -match '^(?:(?:hazte|ponte|ponme|vuelvete)\s+)?(?:del?\s+)?tamano (?:normal|de siempre|original)$' -or
        $f -match '^(?:vuelve|recupera)\s+(?:a\s+)?(?:tu\s+)?tamano(?:\s+normal)?$') {
        return @(@{ kind = 'escalaUI'; paso = 0; desc = 'volver al tamano de siempre' })
    }
    # --- el color de la capsula (ver $ColoresUI) ---
    # Hace falta la palabra "color" o un verbo reflexivo ("ponte", "vuelvete"):
    # "pon rojo" a secas podria ser cualquier cosa.
    # "ponte" llega como "ponme" (Repair-Verb), y el color en femenino: "morada"
    $nomsCol = @($ColoresUI.Keys) + @($ColoresUI.Keys | Where-Object { $_ -match 'o$' } | ForEach-Object { $_ -replace 'o$', 'a' })
    $reCol = (@($nomsCol | Sort-Object { - $_.Length }) | ForEach-Object { [regex]::Escape($_) }) -join '|'
    if ($f -match ('^(?:ponte|ponme|poneme|vuelvete|hazte|cambiate|pintate)\s+(?:de\s+|en\s+|a\s+)?(?:(?:color|colour)\s+)?(' + $reCol + ')$') -or
        $f -match ('^(?:pon|cambia|cambiame|ponme)\s+(?:el\s+|tu\s+)?color\s+(?:a\s+|en\s+|de\s+)?(' + $reCol + ')$')) {
        $nomCol = $Matches[1]
        if (-not $ColoresUI.Contains($nomCol)) { $nomCol = $nomCol -replace 'a$', 'o' }
        return @(@{ kind = 'colorUI'; nombre = $nomCol; valor = $ColoresUI[$nomCol]; desc = "ponerme de color $nomCol" })
    }
    if ($f -match '^(?:(?:ponte|ponme|poneme|vuelvete|hazte)\s+)?(?:de\s+|del\s+|a\s+)?(?:tu\s+)?color (?:normal|de siempre|original)$' -or
        $f -match '^(?:vuelve|recupera)\s+(?:a\s+)?tu\s+color(?:\s+de siempre|\s+normal)?$') {
        return @(@{ kind = 'colorUI'; nombre = ''; valor = ''; desc = 'volver a mi color de siempre' })
    }
    # --- que solo te obedezca a ti, dicho y quitado hablando ---
    if ($f -match '^(?:hazme caso solo a mi|solo hazme caso a mi|obedeceme solo a mi|solo obedeceme a mi|hazme caso solo a mi voz|no hagas caso a otros|no obedezcas a nadie mas)$') {
        return @(@{ kind = 'soloYo'; valor = $true; desc = 'obedecer solo a tu voz' })
    }
    if ($f -match '^(?:haz caso a todos|obedece a todos|hazle caso a cualquiera|da igual quien hable|escucha a todos)$') {
        return @(@{ kind = 'soloYo'; valor = $false; desc = 'obedecer a cualquiera' })
    }
    if ($f -match '^(?:reconoces (?:la|mi) voz|me reconoces la voz|de quien te fias|sabes quien soy|conoces (?:mi|la) voz|distingues mi voz)$') {
        return @(@{ kind = 'quienSoy'; desc = 'que voces conozco' })
    }
    # --- QUE HE HECHO HOY ---
    if ($f -match '^(?:que he hecho|que hice|que hemos hecho|resumen del dia|como fue el dia|que tal el dia|que paso hoy|cuentame el dia)(?:\s+hoy)?$') {
        return @(@{ kind = 'queHeHecho'; desc = 'resumen del dia' })
    }
    # --- UN SOLO PARTE, en vez de seis preguntas ---
    # Bateria, disco, descargas, a que juegas, si algo esta colgado y si estas
    # en sordina se podian preguntar una a una desde hace tiempo. Nadie se
    # acuerda de las seis seguidas, y justo antes de empezar una partida es
    # cuando importan todas. OJO al orden: esto va DESPUES de "como va la
    # descarga" y "como va la bateria", que son mas concretas.
    if ($f -match '^(?:como va todo|como vamos|que tal todo|que tal va todo|como esta todo|como anda todo|como va la consola|como esta la consola|como esta el equipo|estado general|dame el parte|el parte|resumen|resumen general|como estamos)$') {
        return @(@{ kind = 'parte'; desc = 'parte general' })
    }
    # --- copia de seguridad de lo aprendido ---
    # Acotada (revision del 12/09): "saca una copia" o "respalda el archivo en
    # el pendrive" son cosas TUYAS, no la copia de lo aprendido por Nova.
    $deNova = '(?:todo|lo aprendido|lo que sabes|lo que has aprendido|tus cosas|mis cosas|la memoria|tu memoria)'
    if ($f -match ('^(?:haz|hazme|haga|crea|creame|saca|guarda)\s+(?:una\s+|la\s+)?copia\s+(?:de\s+seguridad(?:\s+de\s+' + $deNova + ')?|de\s+' + $deNova + ')(?:\s+ahora)?$') -or
        $f -match ('^(?:haz|hazme|guarda|crea)\s+(?:un\s+)?respaldo(?:\s+de\s+' + $deNova + ')?$') -or $f -match ('^(?:respalda|respaldame)(?:\s+' + $deNova + ')?$')) {
        return @(@{ kind = 'copiaSeguridad'; desc = 'copia de seguridad' })
    }
    # --- ultima vez que jugaste a algo ---
    if ($f -match '^(?:cuando\s+)(?:jugue|juge|jugaba|lo jugue)\s*(?:a|al)?\s*(.*)$') {
        return @(@{ kind = 'ultimaPartida'; que = $Matches[1].Trim(); desc = 'ultima partida' })
    }
    if ($f -match '^(?:a que (?:he |)jugado|que he jugado|a que jugue)\s*(?:esta semana|ultimamente|estos dias|hoy)?$') {
        return @(@{ kind = 'jugadoReciente'; desc = 'lo jugado ultimamente' })
    }
    # --- cuanto ocupa un juego ---
    if ($f -match '^(?:cuanto (?:ocupa|pesa|mide))\s+(.+)$') {
        return @(@{ kind = 'ocupa'; que = $Matches[1].Trim(); desc = 'tamano en disco' })
    }
    if ($f -match '^(?:cuanto llevo jugando|cuanto tiempo llevo jugando|hace cuanto juego)\b') {
        return @(@{ kind = 'tiempoJuego'; desc = 'tiempo de juego' })
    }
    if ($f -match '^(?:a que estoy jugando|que estoy jugando|que juego es este)\b') {
        return @(@{ kind = 'queJuego'; desc = 'juego actual' })
    }
    # el tiempo, con lo que ya se consulto para el avatar de la capsula
    # "cual es el clima para hoy" iba a la charla, que decia que no tenia el clima (15/09)
    if ($f -match '^(?:que tiempo hace|que clima hace|que clima hay|como esta el clima|como esta el tiempo|va a llover|que temperatura hace|cuantos grados hay|cuantos grados hace|cual es el clima|cual es el tiempo|que tal el clima|que tal el tiempo|el clima de hoy|el clima para hoy|el tiempo para hoy|que clima va a hacer|que tiempo va a hacer)\b') {
        $t = if ($script:clima) { "Ahora mismo $($script:clima.desc), $($script:clima.temp) grados" } else { "No tengo el tiempo a mano; no pude consultarlo" }
        # el emoji del tiempo sustituye a la carita unos segundos, solo ahora
        if ($script:clima) { $script:uiClima = $script:clima.emoji; $script:uiClimaHasta = $sw.ElapsedMilliseconds + 9000 }
        return @(@{ kind = 'decir'; desc = $t })
    }
    # --- decir algo en voz alta ---
    # Existe sobre todo para las REGLAS: antes una regla no podia hablar y la
    # documentacion recurria al truco de "recuerdame en 0 minutos que...".
    # "dime quien hizo outlast" es una PREGUNTA, no "di en voz alta 'quien hizo
    # outlast'" (probado el 14/09). "avisame si..." sigue siendo de reglas.
    # 15/09: la anticipacion solo miraba la palabra siguiente, y "dime de los juegos
    # cual tiene mas horas" se decia en voz alta tal cual. Ahora basta con que la
    # pregunta aparezca en cualquier sitio de la frase.
    if ($f -match '^(?:(?:di|dime)\s+(?!.*\b(?:quien|quienes|cual|cuales|cuando|donde|como|cuanto|cuanta|cuantos|cuantas|por que|de que|a que)\b)|(?:avisa|avisame)\s+)(?:que\s+)?(.+)$') {
        return @(@{ kind = 'decir'; desc = $Matches[1].Trim() })
    }
    # --- leer la pantalla (OCR de Windows) ---
    if ($f -match '^(?:lee|leeme|leer|que dice|que pone|que hay escrito|dime que dice)\s+(?:lo que (?:hay|dice|pone) (?:en\s+)?|en\s+)?(?:la\s+|esta\s+|el\s+)?(?:pantalla|ventana|esto|aqui|texto|mensaje)\b') {
        return @(@{ kind = 'ocr'; desc = 'leer la pantalla' })
    }
    # --- seguir leyendo donde se quedo ---
    # el complemento es OBLIGATORIO: un "sigue" o un "dale" sueltos son dos de
    # las cosas mas faciles de oir en un video de fondo
    if ($f -match '^(?:sigue|continua|seguime|dale)\s+(?:leyendo|con la lectura|leyendome)$' -or
        $f -match '^(?:y\s+)?(?:que|el resto|lo que)\s+(?:mas )?(?:dice|pone|falta|queda)$' -or
        $f -match '^lee(?:me)?\s+el resto$') {
        return @(@{ kind = 'seguirLeyendo'; desc = 'seguir leyendo' })
    }
    # --- apuntar lo que hay en la pantalla, sin dictarlo ---
    if ($f -match '^(?:apunta|anota|guarda|apuntame|anotame)\s+(?:esto|eso|esta pantalla|lo de la pantalla|lo que dice la pantalla|lo que pone|este codigo|el codigo|la clave|la combinacion|esta clave|este numero)$') {
        return @(@{ kind = 'ocrMemoria'; desc = 'apuntar lo que hay en la pantalla' })
    }
    # --- captura y grabacion (atajos de la barra de juego de Windows) ---
    switch -regex ($f) {
        '^(?:(?:toma|tomame|haz|hazme|saca|sacame) (?:una )?captura(?: de pantalla)?|captura (?:de )?pantalla|screenshot|pantallazo)$' {
            return @(@{ kind = 'winprt'; desc = 'captura de pantalla' })
        }
        # "graba un audio para mi madre" es una nota de voz, no un clip (14/09)
        # "corta los ultimos 30 segundos de juego" (15/09) se fue al agente 41 s
        '^(?:graba|grabar)\b(?!\s+(?:un|una|me)\s+(?:audio|nota|mensaje))|^(?:clip|guarda el clip|graba los ultimos)\b|^(?:corta|cortame|clipea|clipeame|guarda|guardame)\s+(?:los\s+)?ultimos\s+\d{1,3}\s+segundos(?:\s+de\s+(?:juego|la\s+partida|partida|video))?$' {
            return @(@{ kind = 'winaltg'; desc = 'grabar los ultimos segundos' })
        }
    }
    # --- CONTROL DE APPS Y VENTANAS (lo que faltaba para "hacer cualquier cosa") ---
    # cerrar: "cierra steam", "cierra esta ventana", "cierra el juego"
    # "quita el sonido a spotify" es silenciarlo, no cerrarlo (auditoria del 13/09)
    if ($f -match '^(?:cierra|cierrame|cerrar|apaga|quita|quitame|mata|termina|finaliza|acaba con)\s+(?!(?:el\s+|la\s+)?(?:sonido|volumen|audio|silencio|voz)\b)(?:el\s+|la\s+|a\s+)?(.+)$') {
        $obj = $Matches[1].Trim()
        if ($obj -match '^(?:esta ventana|la ventana|esto|esta|la app|la aplicacion|ventana)$') { return @(@{ kind = 'altf4'; desc = 'cerrar la ventana' }) }
        if ($obj -match '^(?:el juego|juego|este juego|el videojuego)$') { return @(@{ kind = 'cerrarJuego'; desc = 'cerrar el juego' }) }
        # "CIERRA TODO" ES CERRAR (15/09, 5 veces en el uso real): mostraba el
        # escritorio y braya seguia con "cierra Discord y Xbox" o "cierra todos".
        # Cerrar pide confirmacion (ver el bloque 'cerrarTodo'), asi que equivocarse
        # aqui no cierra nada a la primera. El escritorio sigue en "minimiza todo".
        if ($obj -match '^(?:todo|todos|todas|todas las ventanas|todo lo que tengo abierto)$') {
            return @(@{ kind = 'cerrarTodo'; excepto = ''; desc = 'cerrar los programas abiertos' })
        }
        # cerrar de verdad, pero preguntando: ver el bloque 'cerrarTodo'
        # "procesos" y el "que estan abiertos" del final entraron el 12/09:
        # "cierra todos los procesos que estan abiertos" no encajaba, se fue al
        # agente, y el agente cerro TODO sin preguntar -Claude y la capsula
        # incluidas-. Esta orden no puede salir nunca de aqui.
        # "...menos steam y discord": las excepciones viajan con la orden. Antes
        # esta forma no encajaba y se iba al agente con --auto (revision 12/09).
        if ($obj -match '^(?:tod[oa]s? (?:los |las )?(?:programas|procesos|apps|aplicaciones)|los (?:programas|procesos)|las (?:apps|aplicaciones)|todo lo abierto|todo lo que (?:esta|este|tengo|hay) abierto|todo(?=\s+(?:menos|excepto|salvo|quitando|pero no)\s))(?:\s+(?:que\s+)?(?:estan|esten|tengo|hay)?\s*abiert[oa]s)?(?:\s+(?:menos|excepto|salvo|quitando|pero no)\s+(.+))?$') {
            $exceptoCT = if ($Matches[1]) { $Matches[1].Trim() } else { '' }
            return @(@{ kind = 'cerrarTodo'; excepto = $exceptoCT; desc = $(if ($exceptoCT) { "cerrar los programas abiertos menos $exceptoCT" } else { 'cerrar los programas abiertos' }) })
        }
        # "cierra google" / "cierra youtube": son paginas, y lo que se puede cerrar es
        # el navegador. El 15/09 se dijo tres veces seguidas y acabo en la API, que
        # lo tradujo al reves ("Abre Google").
        if ($obj -match '^(?:google|youtube|gmail|el buscador|buscador|la pagina|pagina|la web|internet)$') {
            $procNav = Resolve-Proceso 'navegador'
            if ($procNav) { return @(@{ kind = 'cerrarApp'; proceso = $procNav.proceso; desc = "cerrar $($procNav.nombre)" }) }
        }
        $proc = Resolve-Proceso $obj
        if ($proc) { return @(@{ kind = 'cerrarApp'; proceso = $proc.proceso; desc = "cerrar $($proc.nombre)" }) }
        # no se reconoce que cerrar: que siga su camino (puede ser otra cosa)
    }
    # cambiar de app: "cambia a discord", "ve a steam", "enfoca el navegador", "muestra spotify"
    # "al" tambien: "cambia al bloc de notas" no encajaba, se fue al modelo y
    # quedo aprendido como "abre bloc de notas", que abre OTRO en vez de ir al
    # que ya tenias (revision del 12/09)
    if ($f -match '^(?:regresa al|regresa a|cambia al|cambiate al|pasate al|pasa al|ve al|vete al|llevame al|cambia a|cambiate a|pasate a|pasa a|enfoca|muestra|muestrame|ve a|vete a|llevame a|ponme en|trae|traeme)\s+(?:el\s+|la\s+|a\s+)?(.+)$') {
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
    if ($f -match '^(?:no me escuches|no escuches|deja de escuchar|dejate de escuchar|duermete|vete a dormir|a dormir|descansa|apaga el oido|no me oigas|ignorame)(?:\s+(?:durante|por|en|un|una)?\s*(?:(\d+)\s*(minuto|minutos|hora|horas)|(una hora|un rato|media hora|un momento|rato)))?$') {
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
        } elseif ($expr -eq 'una hora') {
            # "no me escuches una hora" se iba a la IA (auditoria del 13/09)
            $ms = 3600000
            $comoLoDigo = 'una hora'
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
    # abrir una carpeta por su nombre (ver ABRIR UNA CARPETA POR SU NOMBRE)
    if ($f -match '^(?:abre|abreme|abrir|ensename|muestrame)\s+(?:la\s+|mi\s+)?carpeta\s+(?:de\s+mis\s+|de\s+|del\s+)?(.+)$') {
        $nomC = $Matches[1].Trim()
        $rutaC = Find-CarpetaPorNombre $nomC
        if ($rutaC) { return @(@{ kind = 'url'; url = $rutaC; carpeta = $true; desc = "abrir la carpeta $nomC" }) }
        return @(@{ kind = 'decir'; desc = "No encuentro ninguna carpeta que se llame $nomC" })
    }
    # el teclado en pantalla de Windows ("abre el teclado", 15/09)
    if ($f -match '^(?:abre|abreme|abrir|muestra|muestrame|saca|sacame|pon|ponme)\s+(?:el\s+)?teclado(?:\s+(?:en\s+pantalla|virtual|de\s+pantalla))?$') {
        return @(@{ kind = 'app'; target = 'osk.exe'; desc = 'abrir el teclado en pantalla' })
    }
    # escribir en la app activa: "escribe hola que tal" ("escribir hola", 15/09)
    if ($f -match '^(?:escribe|escribeme|escribir|teclea|teclear|dicta|pon el texto)\s+(.+)$') {
        return @(@{ kind = 'escribir'; texto = $Matches[1].Trim(); desc = "escribir '$($Matches[1].Trim())'" })
    }
    # teclas: "pulsa enter", "dale a escape", "presiona espacio"
    if ($f -match '^(?:pulsa|presiona|aprieta|dale a|dale al|toca|oprime)\s+(?:la\s+|el\s+|tecla\s+)?(.+)$') {
        $k = $Matches[1].Trim()
        $mapa = @{ 'enter' = 0x0D; 'intro' = 0x0D; 'escape' = 0x1B; 'esc' = 0x1B; 'espacio' = 0x20; 'tab' = 0x09; 'tabulador' = 0x09;
                   'arriba' = 0x26; 'abajo' = 0x28; 'izquierda' = 0x25; 'derecha' = 0x27; 'borrar' = 0x08; 'retroceso' = 0x08;
                   'suprimir' = 0x2E; 'inicio' = 0x24; 'fin' = 0x23; 'f5' = 0x74; 'f11' = 0x7A; 'windows' = 0x5B; 'play' = 0xB3; 'pausa' = 0xB3 }
        $rep = 1
        # "tres veces" ademas de "3 veces": el dictado escribe la palabra
        if ($k -match '^(.+?)\s+(\d{1,2}|\w+)\s+(?:veces|vez)$') {
            $kk = $Matches[1]; $cuantas = $Matches[2]
            $v = Get-Veces $cuantas
            # solo si de verdad era un numero: "dale a la tecla veces" no
            if ($v -gt 1 -or $cuantas -match '^(?:1|un|una|uno)$') { $k = $kk; $rep = $v }
        }
        if ($mapa.ContainsKey($k)) { return @(@{ kind = 'key'; vk = $mapa[$k]; repeat = $rep; desc = "pulsar $k" }) }
        # UNA LETRA O UN NUMERO SUELTO: "dale a la a", "pulsa el 1". En un menu
        # de juego es lo que hay que poder decir, y el mapa de arriba solo tiene
        # teclas con nombre. Se admite tambien la letra dicha sola ("a", "be").
        $letras = @{ 'be' = 'b'; 'ce' = 'c'; 'de' = 'd'; 'efe' = 'f'; 'ge' = 'g'; 'hache' = 'h'
                     'jota' = 'j'; 'ka' = 'k'; 'ele' = 'l'; 'eme' = 'm'; 'ene' = 'n'; 'pe' = 'p'
                     'cu' = 'q'; 'ere' = 'r'; 'erre' = 'r'; 'ese' = 's'; 'te' = 't'; 'uve' = 'v'
                     'equis' = 'x'; 'ye' = 'y'; 'zeta' = 'z' }
        if ($letras.ContainsKey($k)) { $k = $letras[$k] }
        if ($k -match '^[a-z]$') {
            return @(@{ kind = 'key'; vk = [int][char]([string]$k).ToUpper(); repeat = $rep; desc = "pulsar $($k.ToUpper())" })
        }
        if ($k -match '^\d$') {
            return @(@{ kind = 'key'; vk = (0x30 + [int]$k); repeat = $rep; desc = "pulsar $k" })
        }
        return $null
    }
    switch -regex ($f) {
        '^(?:copia|copiar|copia eso|copialo)$' { return @(@{ kind = 'atajo'; teclas = '^c'; desc = 'copiar' }) }
        '^(?:pega|pegar|pegalo)$' { return @(@{ kind = 'atajo'; teclas = '^v'; desc = 'pegar' }) }
        '^(?:corta|cortar)$' { return @(@{ kind = 'atajo'; teclas = '^x'; desc = 'cortar' }) }
        '^(?:selecciona todo|seleccionar todo|selecciona todo el texto)$' { return @(@{ kind = 'atajo'; teclas = '^a'; desc = 'seleccionar todo' }) }
        '^(?:guarda|guardar|guardalo|guarda (?:el |los )?(?:archivo|documento|cambios|trabajo))$' { return @(@{ kind = 'atajo'; teclas = '^s'; desc = 'guardar' }) }
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
    # "reproduce el segundo video de youtube" / "pon la tercera cancion": el numero N
    # de la ULTIMA busqueda (ver EL VIDEO NUMERO N)
    if ($f -match '^(?:pon|ponme|reproduce|reproduceme|quiero ver|ver|toca|dale a)\s+(?:el|la)\s+(\w+)\s*(?:video|vídeo|cancion|resultado|tema)?\s*(?:de\s+(?:youtube|la\s+lista|la\s+busqueda))?$' -and
        ($ORDINALES_YT.ContainsKey([string]$Matches[1]) -or [string]$Matches[1] -match '^\d{1,2}$')) {
        $ordTxt = [string]$Matches[1]
        $nYT = if ($ORDINALES_YT.ContainsKey($ordTxt)) { [int]$ORDINALES_YT[$ordTxt] } else { [int]$ordTxt }
        if (-not $script:ytUltimaBusqueda) { return @(@{ kind = 'decir'; desc = 'Dime primero que quieres que ponga' }) }
        return @(@{ kind = 'url'; url = ('https://www.youtube.com/results?search_query=' + [Uri]::EscapeDataString($script:ytUltimaBusqueda))
                    youtube = $script:ytUltimaBusqueda; videoN = $nYT; desc = "poner el numero $nYT de '$($script:ytUltimaBusqueda)'" })
    }
    if ($f -match '^(?:pon|ponme|reproduce|reproduceme|quiero ver|ver|toca)\s+(?:el|la)\s+(\w+)\s+(?:video|vídeo|cancion|resultado|tema)\s+de\s+(.+)$' -and
        ($ORDINALES_YT.ContainsKey([string]$Matches[1]) -or [string]$Matches[1] -match '^\d{1,2}$')) {
        $ordTxt2 = [string]$Matches[1]; $quienYT = $Matches[2].Trim()
        $nYT2 = if ($ORDINALES_YT.ContainsKey($ordTxt2)) { [int]$ORDINALES_YT[$ordTxt2] } else { [int]$ordTxt2 }
        # "de el" = de lo ultimo que se puso (15/09: "reproduce la segunda cancion de el")
        if ($quienYT -match '^(?:el|ella|eso|ese|esa|esta|este|youtube)$') { $quienYT = [string]$script:ytUltimaBusqueda }
        if (-not $quienYT) { return @(@{ kind = 'decir'; desc = 'Dime primero que quieres que ponga' }) }
        return @(@{ kind = 'url'; url = ('https://www.youtube.com/results?search_query=' + [Uri]::EscapeDataString($quienYT))
                    youtube = $quienYT; videoN = $nYT2; desc = "poner el numero $nYT2 de '$quienYT'" })
    }
    if ($f -match '^(?:pon|ponme|reproduce|reproduceme|quiero ver|ver|toca)\s+(.+?)\s+en\s+youtube$') {
        $q = $Matches[1].Trim()
        # 'youtube': al hacerla se pone el primer video (ver PONER EL VIDEO, NO SOLO BUSCARLO)
        return @(@{ kind = 'url'; url = ('https://www.youtube.com/results?search_query=' + [Uri]::EscapeDataString($q)); youtube = $q; desc = "poner '$q' en YouTube" })
    }
    # buscar en el equipo (Windows Search): "busca en el equipo fotos de julio"
    if ($f -match '^(?:busca|buscame|buscar)\s+en\s+(?:el\s+)?(?:equipo|pc|computador|computadora|ordenador|windows|mis archivos)\s+(.+)$') {
        return @(@{ kind = 'buscarEquipo'; texto = $Matches[1].Trim(); desc = "buscar '$($Matches[1].Trim())' en el equipo" })
    }
    # --- la ventana de delante: otro monitor y "siempre encima" ---
    if ($f -match '^(?:mandala|pasala|muevela|llevala|manda|pasa|mueve)\s+(?:la ventana\s+)?(?:al|a la|a)\s+(?:otro|otra|segunda|segundo)\s+(?:monitor|pantalla)$' -or
        $f -match '^(?:al|a la)\s+(?:otro|otra)\s+(?:monitor|pantalla)$') {
        return @(@{ kind = 'otroMonitor'; desc = 'al otro monitor' })
    }
    if ($f -match '^(?:ponla|ponlo|dejala|dejalo|pon|deja)\s+(?:la ventana\s+|esto\s+|esta\s+ventana\s+)?siempre\s+(?:encima|arriba|delante)$') {
        return @(@{ kind = 'siempreEncima'; encima = $true; desc = 'siempre encima' })
    }
    if ($f -match '^(?:quitale|quita|saca|sacale)\s+(?:el|lo(?:s)?)?\s*(?:de)?\s*siempre\s+(?:encima|arriba|delante)$' -or
        $f -match '^ya no (?:la |lo )?(?:dejes |pongas )?siempre\s+(?:encima|arriba|delante)$') {
        return @(@{ kind = 'siempreEncima'; encima = $false; desc = 'quitar el siempre encima' })
    }
    # --- colocacion de ventanas ---
    switch -regex ($f) {
        '^(?:a\s+)?(?:mitad de pantalla|media pantalla|la mitad|a la izquierda|izquierda)$' { return @(@{ kind = 'winkey'; vk = 0x25; desc = 'media pantalla izquierda' }) }
        '^(?:a\s+)?(?:la\s+)?derecha$' { return @(@{ kind = 'winkey'; vk = 0x27; desc = 'media pantalla derecha' }) }
        '^(?:maximiza|maximizar|pantalla completa|agranda)$' { return @(@{ kind = 'winkey'; vk = 0x26; desc = 'maximizar ventana' }) }
        '^(?:minimiza|minimizar|achica)$' { return @(@{ kind = 'winkey'; vk = 0x28; desc = 'minimizar ventana' }) }
    }
    # --- el volumen DE UNA APP dicho con "volumen de" (auditoria del 13/09) ---
    # "sube el volumen de spotify", "pon el volumen de discord al 30" caian en el
    # volumen GENERAL. Se reescriben como "sube spotify (al 30)", que ya es el de
    # la app. "pon spotify" a secas no: eso es abrirlo, asi que con "pon" hace
    # falta el numero.
    if ($f -match '^(sube|subele|baja|bajale|pon|ponle)\s+(?:el\s+)?(?:volumen|sonido)\s+(?:de|del|a|al)\s+(.+?)(\s+al?\s+\d{1,3}\s*(?:%|por\s*ciento)?)?$') {
        $verboV = [string]$Matches[1]; $appV = ([string]$Matches[2]).Trim(); $restoV = [string]$Matches[3]
        if ($appV -notmatch '^(?:todo|tope|maximo|minimo|la mitad|mitad|medio|sistema|equipo|pc|ordenador|juego|la musica)$' -and
            ($verboV -notmatch '^pon' -or $restoV) -and (Resolve-Proceso $appV)) {
            return (Resolve-Fragment ("$verboV $appV$restoV"))
        }
    }
    # --- niveles: volumen y brillo, con formas latinas (subele / bajale) ---
    # "pon"/"deja" entran aqui tambien ("pon el brillo al 20%"), pero si la
    # frase no habla de volumen ni brillo se DEJA PASAR al resto de la funcion:
    # devolver $null aqui rompería "ponme spotify".
    if ($f -match '^(sube|subir|subele|aumenta|baja|bajar|bajale|reduce|pon|ponle|poner|deja|dejar)\b') {
        # el verbo se copia ANTES: el -match de $sube pisa $Matches
        $verboN = [string]$Matches[1]
        $sube = ($verboN -match '^(?:sube|subir|subele|aumenta)$')
        $esPon = ($verboN -match '^(?:pon|ponle|poner|deja|dejar)$')
        # "del todo" es a tope si sube y a cero si baja: "baja el volumen del todo"
        # lo ponia al MAXIMO (auditoria del 13/09)
        $delTodo = ($f -match '\bdel\s+todo\b')
        $max = ($f -match '\b(?:maximo|tope|full)\b') -or ($f -match '\btodo\b' -and ($sube -or -not $delTodo))
        $min = ($f -match '\b(?:minimo|nada)\b') -or ($delTodo -and -not $sube -and -not $esPon)
        $mitad = ($f -match '\b(?:la\s+mitad|mitad|medio)\b')
        # Porcentaje POR OBJETIVO: se busca el numero mas cercano a cada palabra.
        # Con un solo $pct global, "el volumen al 50% y el brillo al 80%" ponia
        # los dos al 50 %.
        $pctVol = $null
        $pctBri = $null
        # El numero solo es un PORCENTAJE si lo anuncia un "al"/"a" o si
        # lleva % / "por ciento" detras. Antes valia cualquier numero cerca
        # de la palabra, y "baja el volumen 2 veces" acababa poniendolo al
        # 2 %: lo contrario de lo que pediste, y sin vuelta atras facil.
        # "de"/"del" tambien: "pon el brillo al treinta" se oyo "Con el brillo del 30" (14/09)
        if ($f -match '(?:volumen|sonido|audio)[^0-9]{0,20}?\b(?:al|a|de|del|el)\s+(\d{1,3})\b' -or
            $f -match '(?:volumen|sonido|audio)[^0-9]{0,20}(\d{1,3})\s*(?:%|por\s*ciento)' -or
            # "pon el volumen setenta", sin "al": asi lo oye Whisper deprisa (14/09). Solo
            # con "pon": "baja el volumen 2 veces" no es un porcentaje
            $f -match '^(?:pon|ponme|ponle)\s+(?:el\s+)?(?:volumen|sonido|audio)\s+(\d{1,3})$') {
            $n = [int]$Matches[1]; if ($n -ge 0 -and $n -le 100) { $pctVol = $n }
        }
        # El numero solo es un PORCENTAJE si lo anuncia un "al"/"a" o si
        # lleva % / "por ciento" detras. Antes valia cualquier numero cerca
        # de la palabra, y "baja el volumen 2 veces" acababa poniendolo al
        # 2 %: lo contrario de lo que pediste, y sin vuelta atras facil.
        if ($f -match 'brillo[^0-9]{0,20}?\b(?:al|a|de|del|el)\s+(\d{1,3})\b' -or
            $f -match 'brillo[^0-9]{0,20}(\d{1,3})\s*(?:%|por\s*ciento)' -or
            $f -match '^(?:pon|ponme|ponle)\s+(?:el\s+)?brillo\s+(\d{1,3})$') {
            $n = [int]$Matches[1]; if ($n -ge 0 -and $n -le 100) { $pctBri = $n }
        }
        $acc = @()
        if ($f -match '\b(?:volumen|sonido|audio)\b') {
            if ($null -ne $pctVol) {
                $acc += @{ kind = 'volumenPct'; pct = $pctVol; desc = "volumen al $pctVol por ciento" }
            } elseif ($mitad -and -not $max -and -not $min) {
                $acc += @{ kind = 'volumenPct'; pct = 50; desc = 'volumen a la mitad' }
            } elseif ($max -or $min) {
                # al maximo o al minimo: un numero, no 50 teclazos (~1,5 s)
                $acc += @{ kind = 'volumenPct'; pct = $(if ($max) { 100 } else { 0 })
                           desc = ("volumen al " + $(if ($max) { 'maximo' } else { 'minimo' })) }
            } elseif (-not $esPon) {
                # ("pon el sonido" a secas no dice cuanto: no se toca, y la frase sigue
                # su camino; antes bajaba el volumen, auditoria del 13/09)
                # un paso de 10, con numero exacto y sin los tics del teclado
                $acc += @{ kind = 'volumenRel'; sube = $sube; paso = $(if ($sube) { 10 } else { -10 })
                           desc = ("$(if ($sube) { 'subir' } else { 'bajar' }) volumen") }
            }
        }
        if ($f -match '\bbrillo\b') {
            if ($null -ne $pctBri) {
                $acc += @{ kind = 'brillo'; nivel = $pctBri; desc = "brillo al $pctBri por ciento" }
            } elseif ($max -or $min -or $mitad -or -not $esPon) {
                # "pon el brillo ..." sin cuanto NO baja el brillo: la misma regla que el
                # volumen. Con las 100 grabaciones, "pon el brillo de trinta" lo bajaba (14/09)
                $nivel = if ($max) { 100 } elseif ($min) { 0 } elseif ($mitad) { 50 } elseif ($sube) { -1 } else { -2 }
                $acc += @{ kind = 'brillo'; nivel = $nivel
                           # "pon el brillo al maximo" decia "bajar brillo al maximo" (14/09)
                           desc = $(if ($max) { 'brillo al maximo' } elseif ($min) { 'brillo al minimo' } elseif ($mitad) { 'brillo a la mitad' } else { "$(if ($sube) { 'subir' } else { 'bajar' }) brillo" }) }
            }
        }
        if ($acc.Count -gt 0) { return $acc }
        # sin volumen ni brillo: NO cortar aqui, puede ser "ponme spotify"
    }
    # --- multimedia y sistema ---
    switch -regex ($f) {
        # el mute de verdad: la tecla CONMUTA, asi que decir "silencia" dos
        # veces devolvia el sonido sin querer. Y ahora hay como quitarlo.
        '^(?:silencia|silenciar|mutea|silencio)$' { return @(@{ kind = 'silencio'; silencio = $true; desc = 'silenciar' }) }
        '^(?:quita el silencio|desilencia|dessilencia|quita el mute|desmutea|vuelve el sonido|pon el sonido)$' { return @(@{ kind = 'silencio'; silencio = $false; desc = 'sonido otra vez' }) }
        '^(?:pausa|pausar|reproduce|reproducir|play)$' { return @(@{ kind = 'key'; vk = 0xB3; repeat = 1; desc = 'play/pausa' }) }
        # la tecla es un interruptor: se mira antes si ya suena (revision del 13/09)
        '^(?:pausa|para|apaga|quita)\s+(?:la\s+)?(?:musica|cancion)$' { return @(@{ kind = 'musicaPlay'; sonar = $false; desc = 'pausar la musica' }) }
        # "pausa spotify" abria Spotify: el verbo "pausa" caia en el de abrir (auditoria 13/09)
        '^(?:pausa|pausar|para)\s+(?:a\s+|el\s+|la\s+)?(?:spotify|youtube|netflix|el video|la serie|la pelicula|el reproductor)$' { return @(@{ kind = 'musicaPlay'; sonar = $false; desc = 'pausar lo que suena' }) }
        '^(?:reanuda|quita la pausa a|pon|dale play a)\s+(?:la\s+)?(?:musica|cancion)$' { return @(@{ kind = 'musicaPlay'; sonar = $true; desc = 'poner la musica' }) }
        '^(?:siguiente|pasa|pasala|adelanta)\b' { return @(@{ kind = 'key'; vk = 0xB0; repeat = 1; desc = 'siguiente' }) }
        # "regresa a steam" es volver a esa ventana, no la cancion anterior (14/09)
        '^(?:anterior|atras)\b|^regresa(?!\s+(?:a|al)\b)|^(?:la\s+|pon\s+la\s+)?cancion\s+anterior$|^pon\s+la\s+anterior$' { return @(@{ kind = 'key'; vk = 0xB1; repeat = 1; desc = 'anterior' }) }
        # a secas o con lo que se bloquea: "bloquea a ese tio en discord" bloqueaba la sesion
        '^(?:bloquea|bloquear)(?:\s+(?:la\s+)?(?:pantalla|sesion|el\s+(?:pc|ordenador|equipo|computador|computadora)))?$' { return @(@{ kind = 'lock'; desc = 'bloquear sesion' }) }
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
    # INSTALAR UN JUEGO (15/09, 14:26: "instala en Steam It Takes Two", 60 s de agente
    # y sin conseguirlo). La biblioteca de Nova son los appmanifest del disco: solo los
    # juegos INSTALADOS, asi que de uno que no lo esta no hay appid con el que montar un
    # steam://install. Se abre su ficha en la tienda y le das a instalar tu; y si ya lo
    # tienes, se dice en vez de mandarte a la tienda.
    if ($f -match '^(?:instala|instalame|instalar|descarga|descargame|descargar|bajame|baja)\s+(?:el\s+juego\s+|el\s+|la\s+|en\s+steam\s+)?(.+?)(?:\s+en\s+(?:el\s+)?steam)?$') {
        $jInst = $Matches[1].Trim()
        # "instala en Steam It Takes Two": el nombre va detras del locativo
        $jInst = ($jInst -replace '^(?:en\s+(?:el\s+)?steam\s+)', '').Trim()
        if ($jInst.Length -ge 3 -and $jInst -notmatch '^(?:esto|eso|lo|algo|nada)$') {
            # AQUI EL PARECIDO NO VALE (16/09): Find-Juego empareja por aproximacion y
            # con "instala hollow knight SILKSONG" contestaba "Hollow Knight ya lo
            # tienes" (es otro juego), y con "outlast trials" contestaba "Outlast".
            # Para instalar se exige que el nombre sea el mismo, no que uno contenga
            # al otro: si sobran palabras, es otro juego y hay que ir a la tienda.
            $yaInst = Find-Juego $jInst
            if ($yaInst -and (ConvertTo-Suave ([string]$yaInst.nombre)) -eq (ConvertTo-Suave $jInst)) {
                return @(@{ kind = 'decir'; desc = "$($yaInst.nombre) ya lo tienes instalado. Dime: abre $($yaInst.nombre)" })
            }
            return @(@{ kind = 'url'
                        url = ('https://store.steampowered.com/search/?term=' + [Uri]::EscapeDataString($jInst))
                        desc = "abrir $jInst en la tienda de Steam para instalarlo" })
        }
    }
    # --- VERBO PEGADO (validacion, 15/09): "abre peak" se oyo "Abrepec". Solo si lo de
    # detras del verbo es algo conocido o suena a un juego: "abreviar" se queda como esta.
    if ($f -match '^(abre|cierra)([a-z]{3,})(\s.*)?$') {
        $verboPeg = $Matches[1]
        $restoPeg = ($Matches[2] + $Matches[3]).Trim()
        if ((Resolve-Target $restoPeg) -or (Find-JuegoPorSonido $restoPeg $restoPeg 0.5)) {
            return (Resolve-Fragment "$verboPeg $restoPeg")
        }
    }
    # --- abrir algo, con las variantes latinas de "abrir/ir a" ---
    # el lookahead suelta "pon spotify al 40": eso es volumen de esa app, no
    # abrirla. Sin el, "pon" (verbo de abrir) se quedaba con la frase entera.
    if ($f -match '^(?:abre|abreme|abrele|abrir|abri|abrime|ejecuta|ejecutame|inicia|iniciame|lanza|lanzame|arranca|arrancame|prende|prendeme|ponme|poneme|ponele|pone|pon|metete|mete|entrate|entra|andate|anda|vete|ve|llevame|muestrame|ensename)\s+(?!.*\bal\s+\d{1,3}\s*(?:%|por ciento)?$)(?!(?:el\s+)?(?:juego|videojuego)\s+(?:(?:al|el)\s+)?\d{1,3}\s*(?:%|por ciento)?$)(?:a\s+|al\s+|en\s+|de\s+)?(.+)$') {
        $objAbrir = $Matches[1]
        # "ABRE EL NAVEGADOR CON PINTEREST" (15/09, 11:30:56): se abria el navegador y
        # Pinterest se perdia por el camino, sin avisar; y "abre pinterest en el
        # navegador" ni se entendia. Las dos frases piden lo mismo: abrir ese sitio.
        # Si lo de detras no es un sitio conocido ("abre el navegador en modo incognito"),
        # no se toca nada y se abre el navegador como siempre.
        if ($objAbrir -match '^(?:el\s+|la\s+)?(?:navegador|internet|web|explorador|chrome|edge|firefox)\s+(?:con|en|y)\s+(?:la\s+(?:pagina|web)\s+de\s+)?(.+)$') {
            $rtNav = Resolve-Target ($Matches[1].Trim())
            if ($rtNav) { return $rtNav }
        }
        if ($objAbrir -match '^(.+?)\s+en\s+(?:el\s+|la\s+)?(?:navegador|internet|web|chrome|edge|firefox)$') {
            $rtNav = Resolve-Target ($Matches[1].Trim())
            if ($rtNav) { return $rtNav }
        }
        $rtAbrir = Resolve-Target $objAbrir
        if ($rtAbrir) { return $rtAbrir }
        # no es nada conocido por como se escribe: ¿un juego por como suena? (ver
        # JUEGOS POR COMO SUENAN). Se abre el de verdad, pero PREGUNTANDO antes
        $jSonido = Find-JuegoPorSonido $objAbrir $f
        if ($jSonido) {
            $rtAbrir = Resolve-Target ([string]$jSonido.nombre)
            if ($rtAbrir) { $script:dudosa = [string]$jSonido.nombre; return $rtAbrir }
        }
        return $null
    }
    # --- volumen de UNA aplicacion (mezclador de Windows) ---
    # Va aqui abajo a proposito: si estuviera antes, "sube el volumen" caeria
    # aqui y acabaria buscando una app llamada "volumen".
    # el "al" puede faltar: "pon el juego al ochenta" se oye "Con el juego, 80" (14/09)
    if ($f -match '^(?:sube|subele|baja|bajale|silencia|mutea|quita el sonido a|pon)\s+(?:el\s+|la\s+|a\s+|al\s+)?(.+?)\s*(?:(?:(?:al|el)\s+)?(\d{1,3})\s*(?:%|por ciento)?)?$') {
        $quien = $Matches[1].Trim(); $pct = $Matches[2]
        # "sube el volumen" y compania NO son esto
        if ($quien -notmatch '^(?:volumen|sonido|audio|brillo|pantalla)$') {
            $pr = Resolve-Proceso $quien
            # "el juego" se acepta SIEMPRE: si no hay ninguno abierto, la
            # respuesta util es decirlo, no mandar la frase al modelo.
            if (-not $pr -and $quien -match '^(?:el\s+)?(?:juego|videojuego)$') {
                $pr = @{ proceso = '*juego*'; nombre = 'el juego' }
            }
            if ($pr) {
                $verbo = ($f -split '\s+')[0]
                $silenciar = ($verbo -match '^(?:silencia|mutea|quita)')
                $sube = ($verbo -match '^(?:sube|subele)')
                $acc = @{ kind = 'volumenApp'; proceso = $pr.proceso; nombre = $pr.nombre
                          silenciar = $silenciar; sube = $sube }
                if ($pct) { $acc.pct = [int]$pct }
                $acc.desc = if ($silenciar) { "silenciar $($pr.nombre)" }
                            elseif ($pct) { "$($pr.nombre) al $pct por ciento" }
                            else { "$(if ($sube) { 'subir' } else { 'bajar' }) $($pr.nombre)" }
                return @($acc)
            }
        }
    }
    # --- que esta sonando ---
    if ($f -match '^(?:que (?:esta |se esta )?(?:sonando|suena)|quien (?:esta )?(?:sonando|suena)|de donde (?:viene|sale) (?:el|ese) (?:sonido|ruido|audio))\b') {
        return @(@{ kind = 'queSuena'; desc = 'que esta sonando' })
    }
    # --- sin verbo: solo el nombre ("steam", "youtube") ---
    # Se marca de donde viene: decir un nombre a secas es comodo para abrir
    # steam, pero es tambien la forma en que el ruido abre juegos solo
    # ('SILENT BREATH' salio 4 veces en el log sin que nadie lo dijera). Al
    # ejecutar, un JUEGO sin verbo se pregunta antes.
    $sv = Resolve-Target $f
    # NOMBRAR ALGO NO ES PEDIRLO (14/09): Resolve-Target encuentra el titulo DENTRO
    # de la frase, asi que "que opinas de hollow knight", "hollow knight es dificil"
    # o "te gusta steam" acababan en abrirlo. Si fuera del propio nombre hay
    # palabras de charla, no es una orden: que la lleve la conversacion.
    if ($sv) {
        $descSv = ConvertTo-Plain ((@($sv | ForEach-Object { [string]$_.desc }) -join ' '))
        # probado en vivo el 14/09: "quien hizo hollow knight" preguntaba "¿Abro Hollow Knight?"
        foreach ($mSv in [regex]::Matches($f, '^(?:que|cual|como|por que|te|me|has|he|sabes|crees|conoces|tu|quien|quienes|cuando|donde|cuanto|cuanta|cuantos|de que|dime|hablame|cuentame|explicame)\b|\b(?:es|son|era|fue|esta|estaba|opinas|piensas|parece|gusta|gustan|encanta|jugado|jugaste|jugue|odio|dificil|facil|mejor|peor|bonito|feo|aburrido|hizo|hicieron|creo|desarrollo|salio|trata|cuesta|dura|sabes)\b')) {
            if ($descSv -notmatch ('\b' + [regex]::Escape($mSv.Value) + '\b')) { return $null }
        }
        # ... ni en INGLES: con las 100 grabaciones, "quien hizo hollow knight" se oyo
        # "King is a Hollow Knight" y preguntaba si abrirlo (14/09)
        foreach ($wSv in @($f -split '\s+')) {
            if ($INGLES_COMUN -contains $wSv -and $descSv -notmatch ('\b' + [regex]::Escape($wSv) + '\b')) { return $null }
        }
        # SOLO EL NOMBRE (tanda dirigida, 14/09): "cierra steam" desde lejos se oyo
        # "¡Siempre Steam!" y abria Steam. Sin verbo, cada palabra tiene que ser parte
        # del nombre, parecerse mucho a una (un titulo mal oido) o ser de relleno.
        $palDesc = @((ConvertTo-Juego $descSv) -split '\s+' | Where-Object { $_ })
        foreach ($wSv in @((ConvertTo-Juego $f) -split '\s+' | Where-Object { $_ })) {
            if ($wSv -in @('el', 'la', 'los', 'las', 'un', 'una', 'en', 'de', 'del', 'y', 'a', 'al', 'por', 'favor', 'porfa', 'nova', 'ahora', 'ya', 'pues', 'bueno', 'vale', 'ok', 'oye', 'steam', 'juego', 'hola', 'buenas')) { continue }
            if ($palDesc -contains $wSv) { continue }
            $cercaSv = $false
            if ($wSv.Length -ge 4) {
                foreach ($pdSv in $palDesc) { if ($pdSv.Length -ge 4 -and (Get-Distancia $wSv $pdSv) -le 2) { $cercaSv = $true; break } }
            }
            if (-not $cercaSv) { return $null }
        }
    }
    # SIN VERBO Y SIN NOMBRE CONOCIDO, ¿un juego por como suena? (tanda dirigida, 14/09):
    # "Ahora gus gus dup" llega como "gus gus dup" porque "ahora" se quita como muletilla.
    # Sin verbo el riesgo es mayor, asi que el umbral es 0,85: medido con 786 frases
    # normales y de ruido, ninguna llega (con 0,75, "epic" acababa en PEAK). Solo si
    # Resolve-Target no encontro nada (los filtros de arriba ya habrian devuelto), con dos
    # palabras o mas, y preguntando antes.
    if (-not $sv -and @($f -split '\s+').Count -ge 2) {
        $jSv = Find-JuegoPorSonido $f $f 0.85
        if ($jSv) {
            $sv = Resolve-Target ([string]$jSv.nombre)
            if ($sv) { $script:dudosa = [string]$jSv.nombre }
        }
    }
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
# Las fotos del estado, con su hora, para poder volver a "hace cinco minutos"
# y no solo a "la orden anterior".
$script:historial = New-Object System.Collections.ArrayList

function Save-EstadoParaDeshacer {
    $b = $null
    try { $b = (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop).CurrentBrightness } catch {}
    # el volumen ya se puede leer, asi que ya se puede devolver: antes
    # "deshaz" contestaba literalmente que no podia con el
    $vol = -1
    try { $vol = [AX]::LeerVolumen() } catch {}
    $script:deshacer = @{ cuando = (Get-Date); brillo = $b; volumen = $vol
                          procesos = New-Object System.Collections.ArrayList; juego = $null }
    # LA PILA. Antes solo existia la ultima foto, asi que "deshaz" dos veces
    # seguidas ya no tenia nada que devolver. Se guardan las de la ultima hora
    # y como mucho 40: mas es memoria que nadie va a pedir.
    [void]$script:historial.Add($script:deshacer)
    $limite = (Get-Date).AddHours(-1)
    while ($script:historial.Count -gt 0 -and
           ($script:historial[0].cuando -lt $limite -or $script:historial.Count -gt 40)) {
        $script:historial.RemoveAt(0)
    }
}

# Vuelve a como estaba hace N minutos: el brillo y el volumen de la foto MAS
# VIEJA de esa ventana (la ultima no vale: esa es "hace un momento"), y se
# cierra todo lo que se abrio desde entonces.
function Invoke-DeshacerDesde([int]$minutos) {
    if ($minutos -lt 1) { $minutos = 1 }
    $desde = (Get-Date).AddMinutes(-$minutos)
    $fotos = @($script:historial | Where-Object { $_.cuando -ge $desde })
    if ($fotos.Count -eq 0) { return "No he tocado nada en los ultimos $minutos minutos" }
    $vieja = $fotos[0]
    $hecho = @()
    if ($null -ne $vieja.brillo) {
        try { Set-Brillo ([int]$vieja.brillo); $hecho += "brillo como estaba" } catch {}
    }
    if ($null -ne $vieja.volumen -and [int]$vieja.volumen -ge 0) {
        $vAntes = [int]$vieja.volumen
        if ([AX]::LeerVolumen() -ne $vAntes) {
            try { if ([AX]::PonerVolumen($vAntes)) { $hecho += "volumen al $vAntes" } } catch {}
        }
    }
    # los procesos SI son de todas las fotos: se abrieron todos en la ventana
    $cerrados = 0
    foreach ($f in $fotos) {
        foreach ($pid3 in @($f.procesos)) {
            try {
                $pr = Get-Process -Id $pid3 -ErrorAction Stop
                $pr.CloseMainWindow() | Out-Null
                $cerrados++
            } catch {}
        }
    }
    if ($cerrados -gt 0) { $hecho += "$cerrados " + $(if ($cerrados -eq 1) { 'programa cerrado' } else { 'programas cerrados' }) }
    foreach ($f in $fotos) { $script:historial.Remove($f) }
    $script:deshacer = $null
    if ($hecho.Count -eq 0) { return "No habia nada que devolver de esos $minutos minutos" }
    return ("Vuelto a como estaba: " + ($hecho -join '; '))
}

function Invoke-Deshacer {
    if (-not $script:deshacer) { return "No hay nada que deshacer" }
    $hecho = @()
    if ($null -ne $script:deshacer.brillo) {
        # solo si de verdad cambio: decia "brillo restaurado" y lo reescribia aunque
        # la orden no lo hubiera tocado (auditoria del 13/09)
        $briAhora = -1
        try { $briAhora = [int]((Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness) } catch {}
        if ($briAhora -ne [int]$script:deshacer.brillo) {
            try { Set-Brillo ([int]$script:deshacer.brillo); $hecho += "brillo restaurado" } catch {}
        }
    }
    if ($null -ne $script:deshacer.volumen -and [int]$script:deshacer.volumen -ge 0) {
        $vAntes = [int]$script:deshacer.volumen
        if ([AX]::LeerVolumen() -ne $vAntes) {
            try { if ([AX]::PonerVolumen($vAntes)) { $hecho += "volumen al $vAntes" } } catch {}
        }
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
    if ($hecho.Count -eq 0) { return "No pude deshacerlo: no habia nada que devolver" }
    return ($hecho -join '; ')
}

# "aprende que a X le llamo Y": amplia commands.json hablando, sin editar JSON.
# Guardar un modo en commands.json. Se escribe como el resto (UTF-8 sin BOM) y
# se RELEE al vuelo, o el modo recien creado no existiria hasta reiniciar.
# Guarda un ajuste en config.json sin tocar lo demas. Hace falta para que la
# esquina sobreviva al reinicio: si no, habria que decirselo cada vez.
function Set-Cfg([string]$seccion, [string]$clave, $valor) {
    try {
        # $cfgPath, no $PSScriptRoot: es la MISMA ruta que se lee al arrancar, y
        # ademas se puede apuntar a otro sitio para probarlo sin tocar el de verdad
        $ruta = $cfgPath
        $j = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $j.$seccion) { $j | Add-Member -NotePropertyName $seccion -NotePropertyValue (New-Object PSObject) -Force }
        $j.$seccion | Add-Member -NotePropertyName $clave -NotePropertyValue $valor -Force
        # SIN BOM: lo leen tambien los workers de Python, en crudo
        Write-Atomico $ruta ($j | ConvertTo-Json -Depth 8)
        Log "config: $seccion.$clave = $valor"
        return $true
    } catch { Log ("no pude guardar la configuracion: " + $_.Exception.Message); return $false }
}

function Add-Perfil([string]$nombre, [string[]]$ordenes) {
    $nombre = (ConvertTo-Plain $nombre).Trim()
    if (-not $nombre -or $ordenes.Count -eq 0) { return $false }
    try {
        $j = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $j.perfiles) { $j | Add-Member -NotePropertyName perfiles -NotePropertyValue (New-Object PSObject) -Force }
        $j.perfiles | Add-Member -NotePropertyName $nombre -NotePropertyValue ([string[]]$ordenes) -Force
        Write-Atomico $cmdsPath ($j | ConvertTo-Json -Depth 8)
        $script:cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Log ("MODO CREADO: $nombre -> " + ($ordenes -join '; '))
        return $true
    } catch { Log ("no pude crear el modo: " + $_.Exception.Message); return $false }
}

# EL CORREO (16/09). El 15/09 "revisa mi correo" se pidio tres veces y las tres
# acabaron en el agente (37-93 s) sin dar nada util.
#
# LEER no cambia nada: no pregunta, y ademas no marca los correos como leidos (que Nova
# te los cuente no puede hacer que desaparezcan de tu movil).
# ENVIAR sale de la maquina y no se deshace, y Nova oye mal a veces: NUNCA se envia sin
# un si hablado, y antes se lee en voz alta a quien va y que dice.
$CorreoScript = Join-Path $LogDir 'tools\correo.py'
$script:correoUltimo = $null      # el ultimo correo leido, para poder responderle

function Test-CorreoListo {
    if (-not (Test-Path -LiteralPath $CorreoScript)) { return $false }
    foreach ($v in 'NOVA_CORREO_USUARIO', 'NOVA_CORREO_CLAVE') {
        $x = [Environment]::GetEnvironmentVariable($v, 'Process')
        if (-not $x) { $x = [Environment]::GetEnvironmentVariable($v, 'User') }
        if (-not $x) { return $false }
    }
    return $true
}

# Llama al script y devuelve lo que conteste, ya en objeto. $args1: lista de argumentos.
function Invoke-CorreoScript([string[]]$args1, [int]$plazoMs = 25000) {
    $sal = Join-Path $TmpDir ("correo-" + [System.Guid]::NewGuid().ToString('N').Substring(0, 8) + ".json")
    try {
        $pr = Start-Process -FilePath $PyWorker -WindowStyle Hidden -PassThru -WorkingDirectory $LogDir `
            -ArgumentList (@($CorreoScript) + $args1 + @($sal))
        $null = $pr.Handle
        if (-not $pr.WaitForExit($plazoMs)) {
            try { $pr.Kill() } catch {}
            return @{ ok = $false; error = 'tardo demasiado' }
        }
        if (-not (Test-Path -LiteralPath $sal)) { return @{ ok = $false; error = 'sin respuesta' } }
        $txt = [System.IO.File]::ReadAllText($sal, [System.Text.Encoding]::UTF8)
        return ($txt | ConvertFrom-Json)
    } catch {
        return @{ ok = $false; error = $_.Exception.Message }
    } finally {
        Remove-Item -LiteralPath $sal -Force -ErrorAction SilentlyContinue
    }
}

# De la lista de correos a una frase que se pueda ESCUCHAR: quien escribe y de que va.
function Format-Correos($correos) {
    $n = @($correos).Count
    if ($n -eq 0) { return 'No tienes correos nuevos.' }
    $trozos = @()
    foreach ($c in @($correos | Select-Object -First 4)) {
        $de = [string]$c.de
        $asunto = [string]$c.asunto
        if ($asunto.Length -gt 80) { $asunto = $asunto.Substring(0, 80).Trim() + '...' }
        $trozos += $(if ($asunto) { "$de, $asunto" } else { $de })
    }
    $cab = if ($n -eq 1) { 'Tienes un correo nuevo: ' } else { "Tienes $n correos nuevos. " }
    $txt = $cab + ($trozos -join '. ')
    if ($n -gt 4) { $txt += ". Y $($n - 4) mas." }
    return $txt
}

function Invoke-Correo($a) {
    if (-not (Test-CorreoListo)) {
        return 'Todavia no tengo tu correo configurado. Hace falta una contrasena de aplicacion de Google.'
    }
    $accion = [string]$a.accion
    if ($accion -eq 'no-leidos') {
        $r = Invoke-CorreoScript @('no-leidos', '8')
        if (-not $r.ok) { return "No pude mirar tu correo: $($r.error)" }
        $script:correoUltimo = @($r.correos) | Select-Object -First 1
        # en el log, SOLO cuantos habia: ni remitentes ni asuntos
        Log "CORREO: $($r.cuantos) sin leer"
        return (Format-Correos $r.correos)
    }
    if ($accion -eq 'leer') {
        $r = Invoke-CorreoScript @('leer', '1')
        if (-not $r.ok) { return "No pude leer tu correo: $($r.error)" }
        $c = @($r.correos) | Select-Object -First 1
        if (-not $c) { return 'No tienes ningun correo.' }
        $script:correoUltimo = $c
        Log 'CORREO: leido el ultimo'
        $cuerpo = [string]$c.cuerpo
        if ($cuerpo.Length -gt 700) { $cuerpo = $cuerpo.Substring(0, 700).Trim() + '...' }
        if (-not $cuerpo) { $cuerpo = '(no trae texto)' }
        return "De $($c.de), $($c.asunto). Dice: $cuerpo"
    }
    if ($accion -eq 'responder') {
        if (-not $script:correoUltimo) { return 'Primero dime: revisa mi correo. Asi se a cual respondo.' }
        # NUNCA se envia a la primera: se lee a quien va y que dice, y se espera un si
        if (-not $script:confirmado) {
            $script:pendiente = @{ texto = ''; vence = 0; tipo = 'peligrosa'; correo = @{ accion = 'responder'; n = [int]$script:correoUltimo.n; texto = [string]$a.texto } }
            return "Le respondo a $($script:correoUltimo.de) esto: $($a.texto). ¿Lo envio?"
        }
        $r = Invoke-CorreoScript @('responder', [string]$script:correoUltimo.n, [string]$a.texto, '--confirmado') 40000
        if (-not $r.ok) { return "No pude enviarlo: $($r.error)" }
        Log 'CORREO: respuesta enviada'
        return 'Enviado.'
    }
    if ($accion -eq 'enviar') {
        $destino = [string]$a.destino
        # sin arroba no es una direccion: se busca en los ultimos correos por el nombre
        if ($destino -notmatch '@') {
            $r0 = Invoke-CorreoScript @('ultimos', '20')
            $cand = @()
            if ($r0.ok) { $cand = @($r0.correos | Where-Object { (ConvertTo-Plain ([string]$_.de)).Contains((ConvertTo-Plain $destino)) }) }
            if ($cand.Count -eq 0) { return "No se cual es el correo de $destino. Dime la direccion entera." }
            $destino = [string]$cand[0].de
            return "No tengo la direccion de $destino guardada. Dimela entera y te lo mando."
        }
        if (-not $script:confirmado) {
            $script:pendiente = @{ texto = ''; vence = 0; tipo = 'peligrosa'; correo = @{ accion = 'enviar'; destino = $destino; texto = [string]$a.texto } }
            return "Le mando a $destino esto: $($a.texto). ¿Lo envio?"
        }
        $r = Invoke-CorreoScript @('enviar', $destino, 'Mensaje de braya', [string]$a.texto, '--confirmado') 40000
        if (-not $r.ok) { return "No pude enviarlo: $($r.error)" }
        Log 'CORREO: enviado'
        return 'Enviado.'
    }
    return 'No se que quieres que haga con el correo.'
}

# CAMBIAR UN MODO HABLANDO (16/09). El 15/09 braya dijo "recuerda que al poner modo
# juego abras Steam y Discord no lo abras" y Nova lo guardo como una NOTA en el diario:
# el modo juego siguio abriendo Discord, justo lo que pedia que dejara de hacer.
#
# Va en DOS partes a proposito. Resolve-ModoPorVoz solo mira la frase y no toca nada
# (Resolve-Fragment se usa tambien para VALIDAR ordenes -al crear una receta, por
# ejemplo-, y ahi cambiar un modo de verdad seria un desastre silencioso); el cambio lo
# hace Invoke-ModoEditar desde el ejecutor, como cualquier otra accion.
#   "en modo juego no abras discord"   -> quita 'abre discord' del modo juego
#   "al poner modo juego abre steam"   -> anade 'abre steam' al modo juego
function Resolve-ModoPorVoz([string]$texto) {
    if (-not $texto -or -not $cmds -or -not $cmds.perfiles) { return $null }
    $p = ConvertTo-Plain $texto
    # se quita el "recuerda que" de delante: asi lo dijo el 15/09 y acabo en el diario
    $p = ($p -replace '^(?:recuerda(?:me)?\s+que\s+|acuerdate\s+de\s+que\s+|apunta\s+que\s+)', '').Trim()
    # el "en" A SECAS es la forma natural ("en modo juego no abras Discord"); exigir un
    # verbo delante dejaba fuera justo la frase que provoco todo esto
    if ($p -notmatch '^(?:(?:cuando|al|si)\s+(?:pong[ao]|poner|active|activar|entre|entrar)\s+(?:en\s+)?|en\s+|para\s+(?:el\s+)?)?(?:el\s+)?modo\s+(\w+)[,\s]+(.+)$') { return $null }
    $modoN = $Matches[1].Trim(); $resto = $Matches[2].Trim()
    if (-not (Test-Prop $cmds.perfiles $modoN)) { return $null }

    $quitar = $false
    if ($resto -match '^(?:ya\s+)?no\s+(.+)$') { $quitar = $true; $resto = $Matches[1].Trim() }
    elseif ($resto -match '^(?:quita|saca|elimina|borra)\s+(?:el\s+|la\s+|lo\s+de\s+)?(.+)$') { $quitar = $true; $resto = $Matches[1].Trim() }
    # el subjuntivo, como se dice al pedirlo ("abras steam", "no abras discord")
    $resto = (Repair-Verb $resto).Trim()
    if (-not $resto) { return $null }
    # anadir algo que Nova no sabe hacer no tiene sentido: se dice y no se cambia nada
    if (-not $quitar -and -not (Test-FastCommand $resto)) {
        return @{ modo = $modoN; orden = $resto; quitar = $false; imposible = $true }
    }
    return @{ modo = $modoN; orden = $resto; quitar = $quitar; imposible = $false }
}

# Aplica lo que decidio Resolve-ModoPorVoz y devuelve la frase que dira Nova.
function Invoke-ModoEditar($d) {
    if (-not $d) { return 'No entendi que modo cambiar.' }
    $modoN = [string]$d.modo; $resto = [string]$d.orden
    if ($d.imposible) { return "No se hacer '$resto', asi que no lo meto en el modo $modoN." }
    if (-not (Test-Prop $cmds.perfiles $modoN)) { return "No tengo ningun modo $modoN." }
    $lista = @(@($cmds.perfiles.$modoN) | ForEach-Object { [string]$_ } | Where-Object { $_ })

    if ($d.quitar) {
        # POR CONTENCION, no con regex: una orden puede acabar en "0%", y un \b detras
        # de % no casa nunca (no es caracter de palabra)
        $clave = ConvertTo-Plain (($resto -replace '^(?:abre|abras|abrir|pon|pongas|poner)\s+', '').Trim())
        if (-not $clave) { return "No entendi que quitar del modo $modoN." }
        $fuera = @($lista | Where-Object { (ConvertTo-Plain $_).Contains($clave) })
        if ($fuera.Count -eq 0) { return "El modo $modoN no hace nada con $clave." }
        $lista = @($lista | Where-Object { $fuera -notcontains $_ })
        if ($lista.Count -eq 0) { return "Si quito eso, el modo $modoN se queda vacio. Mejor dime: olvida el modo $modoN." }
        if (-not (Add-Perfil $modoN $lista)) { return "No pude cambiar el modo $modoN." }
        Log "MODO ${modoN}: quitado '$($fuera -join ', ')' (lo pediste hablando)"
        Add-Estadistica 'modo-editado' "$modoN -sin- $($fuera -join ', ')"
        Set-AcabaDeAprender
        return "Hecho. El modo $modoN ya no $($fuera -join ' ni ')."
    }
    if (@($lista | Where-Object { (ConvertTo-Plain $_) -eq (ConvertTo-Plain $resto) }).Count -gt 0) {
        return "El modo $modoN ya hace eso."
    }
    if ($lista.Count -ge 8) { return "El modo $modoN ya tiene muchas cosas; quita alguna antes." }
    $lista += $resto
    if (-not (Add-Perfil $modoN $lista)) { return "No pude cambiar el modo $modoN." }
    Log "MODO ${modoN}: anadido '$resto' (lo pediste hablando)"
    Add-Estadistica 'modo-editado' "$modoN +mas+ $resto"
    Set-AcabaDeAprender
    return "Hecho. El modo $modoN ahora tambien $resto."
}

function Remove-Perfil([string]$nombre) {
    $nombre = (ConvertTo-Plain $nombre).Trim()
    if (-not $nombre) { return $false }
    try {
        $j = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not (Test-Prop $j.perfiles $nombre)) { return $false }
        $j.perfiles.PSObject.Properties.Remove($nombre)
        Write-Atomico $cmdsPath ($j | ConvertTo-Json -Depth 8)
        $script:cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Log "MODO BORRADO: $nombre"
        return $true
    } catch { Log ("no pude borrar el modo: " + $_.Exception.Message); return $false }
}

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
        Write-Atomico $cmdsPath $txt
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
        } catch { Save-Corrupto $TraduccionesPath 'traducciones' }
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
        Write-Atomico $TraduccionesPath ($o | ConvertTo-Json -Depth 4)
        Log "APRENDIDO: '$original' = '$traducida'"
    } catch { Log ("no pude guardar la traduccion: " + $_.Exception.Message) }
}

# ¿La traduccion del modelo se explica por UNA palabra desconocida que
# corresponde a UNA app o sitio conocidos? Entonces vale la pena aprender esa
# palabra como alias (sirve para cualquier frase futura).
$PALABRAS_COMUNES = @('abre','abrir','pon','ponme','busca','en','el','la','los','las','un','una','de','del','al','a','y','con','por','para','que','me','lo','le','mi','tu','su','ya','ahora','porfa','por','favor','steam','juego')
# =====================================================================
# FRASES QUE YA TE MOLESTARON UNA VEZ
# "no era eso" apunta aqui la frase. La proxima vez que llegue exactamente
# igual no se ejecuta: se pregunta. Y si dices que si, se borra de la lista,
# porque entonces la querias de verdad: asi se cura sola en vez de quedarse
# vetada para siempre por una vez que cambiaste de idea.
# =====================================================================
$RechazosPath = Join-Path $MemoriaDir 'rechazos.json'
$script:rechazos = $null

function Get-Rechazos {
    if ($null -ne $script:rechazos) { return $script:rechazos }
    $script:rechazos = @{}
    if (Test-Path -LiteralPath $RechazosPath) {
        try {
            $j = Get-Content -LiteralPath $RechazosPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($x in $j.PSObject.Properties) { $script:rechazos[$x.Name] = [int]$x.Value }
        } catch {}
    }
    return $script:rechazos
}

function Save-Rechazos {
    try {
        $h = Get-Rechazos
        $o = New-Object PSObject
        foreach ($k in $h.Keys) { $o | Add-Member -NotePropertyName $k -NotePropertyValue $h[$k] -Force }
        if (-not (Test-Path -LiteralPath $MemoriaDir)) { New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null }
        Write-Atomico $RechazosPath ($o | ConvertTo-Json -Depth 3)
    } catch { Log ("no pude guardar los rechazos: " + $_.Exception.Message) }
}

function Add-Rechazo([string]$texto) {
    $k = ConvertTo-Plain $texto
    # una palabra suelta no identifica nada y vetaria media lista de ordenes
    if (-not $k -or $k -notmatch '\s') { return $false }
    $h = Get-Rechazos
    if ($h.ContainsKey($k)) { $h[$k] = [int]$h[$k] + 1 } else { $h[$k] = 1 }
    Save-Rechazos
    Log "RECHAZO apuntado: '$k' (van $($h[$k]))"
    return $true
}

function Remove-Rechazo([string]$texto) {
    $k = ConvertTo-Plain $texto
    $h = Get-Rechazos
    if (-not $k -or -not $h.ContainsKey($k)) { return $false }
    $h.Remove($k)
    Save-Rechazos
    Log "RECHAZO retirado: '$k' (esta vez si la querias)"
    return $true
}

function Test-Rechazada([string]$texto) {
    $k = ConvertTo-Plain $texto
    if (-not $k) { return $false }
    return (Get-Rechazos).ContainsKey($k)
}

# Olvidar una traduccion aprendida. Hace falta para "no era eso": sin esto,
# una interpretacion equivocada se queda para siempre y repite el error.
function Remove-Traduccion([string]$original) {
    $clave = ConvertTo-Plain $original
    if (-not $clave) { return $false }
    $t = Get-Traducciones
    if (-not $t.ContainsKey($clave)) { return $false }
    $t.Remove($clave)
    try {
        $o = New-Object PSObject
        foreach ($k in $t.Keys) { $o | Add-Member -NotePropertyName $k -NotePropertyValue $t[$k] -Force }
        Write-Atomico $TraduccionesPath ($o | ConvertTo-Json -Depth 4)
        Log "OLVIDADO: la traduccion de '$original'"
        return $true
    } catch { Log ("no pude olvidar la traduccion: " + $_.Exception.Message); return $false }
}

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

# =====================================================================
# RECETAS: AUTOAPRENDIZAJE DE TAREAS (13/09)
# Cuando el cerebro (Claude Code) hace una tarea nueva con herramientas, deja
# ademas una RECETA: la frase como plantilla con huecos ("crea una carpeta
# llamada {nombre} en {sitio}") y los pasos para repetirla. La proxima vez que
# se pida algo que encaje, Nova la hace sola y sin IA: preguntando las primeras
# veces (recetas.confirmarVeces) y directamente despues.
# Lo que NUNCA entra en una receta, y por tanto sigue pasando siempre por el
# cerebro, que piensa cada vez: borrar, matar procesos, servicios, registro,
# apagar, descargar, instalar o ejecutar texto como codigo.
# Lo dicho entra en el script como VARIABLE escapada, nunca pegado al codigo:
# una frase dictada no puede colarle ordenes al PowerShell.
# =====================================================================
$RecetasOn = [bool](Get-Cfg 'recetas' 'activadas' $true)
$RecetasConfirmar = [int](Get-Cfg 'recetas' 'confirmarVeces' 2)
$RecetasPath = Join-Path $MemoriaDir 'recetas.json'
$RecetasMax = 200
$RE_RECETA_PROHIBIDO = '(?i)\b(?:Remove-Item|Remove-ItemProperty|Clear-Item|Clear-Content|Clear-RecycleBin|Stop-Process|taskkill|Stop-Service|Restart-Service|Set-Service|Restart-Computer|Stop-Computer|shutdown|logoff|Format-Volume|Clear-Disk|Initialize-Disk|diskpart|bcdedit|Set-ItemProperty|New-ItemProperty|Set-ExecutionPolicy|Invoke-Expression|Invoke-WebRequest|Invoke-RestMethod|Start-BitsTransfer|schtasks|Register-ScheduledTask|Uninstall-Package|Install-Package|Install-Module|msiexec|winget|choco|Add-MpPreference|Set-MpPreference|Disable-NetAdapter|RunAs)\b|\b(?:curl|wget)\b|\bnet\s+user\b|\breg(?:\.exe)?\s+(?:add|delete|import)\b'
$script:recetas = $null
$script:ultimaReceta = $null
$script:ultimaRecetaEn = 0
$script:ccConHerramientas = $false
$script:reparandoReceta = $null   # receta que fallo y cuya tarea lleva ahora el cerebro para arreglarla
$script:acabaDeAprender = $false  # la capsula celebrara en el proximo "hecho" (ver Send-UIEvento)
$script:acabaDeAprenderEn = 0
function Set-AcabaDeAprender {
    $script:acabaDeAprender = $true
    $script:acabaDeAprenderEn = $sw.ElapsedMilliseconds
    try { Update-Madurez } catch {}   # ¿sube de nivel? (ver NOVA EVOLUCIONA)
}

# Lo que se le pide al cerebro al final de cada tarea (modo accion).
$CcInstruccionReceta = @'


AL FINAL, en una linea aparte y despues de la frase de resumen, deja una RECETA en UNA sola linea de JSON para que Nova repita esto sola la proxima vez, en 1-3 segundos y sin ti. Hay DOS tipos:

1) ACCION (cambia algo: crear, abrir, mover, escribir, pulsar teclas, abrir un enlace steam:// o una web):
RECETA: {"tipo": "accion", "frase": "...", "resumen": "...", "pasos": [...], "respuesta": "..."}

2) INFORMACION (solo mira y dice: que hay en una carpeta, cuanto ocupa algo, cuantos archivos hay, que juegos tienes...):
RECETA: {"tipo": "info", "frase": "...", "resumen": "...", "pasos": [{"tipo": "lectura", "script": "..."}], "voz": {"modo": "plantilla", "plantilla": "...", "vacio": "..."}}
- El script de "lectura" SOLO LEE. Puede usar Get-ChildItem, Get-Item, Get-Content, Test-Path, Join-Path, Get-Process, Get-CimInstance, Measure-Object, Select-Object, Sort-Object, Where-Object, ForEach-Object, Group-Object y ConvertTo-Json, y nada mas. Prohibido todo lo que empiece por Set-, New-, Remove-, Start-, Invoke-, Out-File, llamar a un .exe o redirigir con >. Usa $env:USERPROFILE, no [Environment].
- Termina SIEMPRE escribiendo UN objeto con ConvertTo-Json -Compress, por ejemplo: [pscustomobject]@{ cuantos = $i.Count; nombres = @($i | Select-Object -First 5 | ForEach-Object { $_.Name }) } | ConvertTo-Json -Compress
- "voz.plantilla": la frase que dira Nova con esos datos. {campo} pone el valor; {campo|singular|plural} pone el numero y su palabra ("3 archivos", "1 archivo"). Ejemplo: "En descargas tienes {cuantos|archivo|archivos}. Los ultimos: {nombres}."
- "voz.vacio": lo que dice cuando no hay nada ("No tienes nada en descargas."). Es obligatorio.

Para los dos tipos:
- "frase": la orden del usuario como plantilla, en minusculas y sin tildes, con {hueco} en lo que cambiaria otra vez (maximo 3 huecos, nombres en minusculas, por ejemplo {nombre}, {carpeta}, {juego}).
- IMPORTANTE: las partes fijas de "frase" copialas EXACTAMENTE como las dijo el usuario, mismas palabras y en el mismo orden, y las rutas completas tal cual. Nova compara la plantilla palabra por palabra: si resumes o acortas algo, no encajara nunca. No incluyas saludos, "ok", "mira" ni comentarios.
- TODO hueco tiene que usarse: como variable ($nombre) en un script o como {nombre} en una orden. El nombre de un archivo o carpeta que el usuario dijo sale del hueco, nunca de un texto fijo.
- Pon hueco a los nombres, textos, rutas, numeros o apps que cambiarian la proxima vez. Sin huecos solo si la orden no lleva ningun dato ("que tengo en mi escritorio").
- "resumen": lo que hace, en infinitivo y corto, puede usar huecos.
- "pasos": de 1 a 6. {"tipo": "powershell", "script": "..."} (PowerShell 5.1, sin preguntar nada), {"tipo": "orden", "texto": "abre spotify"} (una orden que Nova ya entiende) o {"tipo": "lectura", "script": "..."} (solo para informacion).
- "respuesta" (solo accion): la frase corta que Nova dira al terminar, puede usar huecos.

Si NO se puede repetir sin ti, escribe RECETA: NO y detras UNO de estos motivos:
- NO pantalla: tuviste que MIRAR la pantalla para decidir donde pulsar o que elegir.
- NO contenido: habia que elegir o redactar algo segun su contenido (que video, que contestar).
- NO externo: enviaste, compraste, aceptaste algo o iniciaste sesion.
- NO destructivo: hubo que borrar, cerrar programas o tocar el registro.
- NO inseguro: no estas seguro de que el script funcione solo con otros valores.
- NO charla: no era una tarea.
Lo que SI se puede repetir, aunque antes se dijera que no: dar informacion con un script de lectura, mover archivos o accesos directos, y pulsar un atajo de teclado.
'@

function Get-Recetas {
    if ($null -ne $script:recetas) { return ,$script:recetas }
    $script:recetas = New-Object System.Collections.ArrayList
    if (Test-Path -LiteralPath $RecetasPath) {
        try {
            $crudo = Get-Content -LiteralPath $RecetasPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($x in $crudo) {
                if ($null -eq $x -or -not [string]$x.frase) { continue }
                $pasos = New-Object System.Collections.ArrayList
                foreach ($pp in @($x.pasos)) { if ($pp) { [void]$pasos.Add(@{ tipo = [string]$pp.tipo; texto = [string]$pp.texto }) } }
                $vars = New-Object System.Collections.ArrayList
                foreach ($vv in @($x.variantes)) { if ([string]$vv) { [void]$vars.Add([string]$vv) } }
                # tipo y voz son de las recetas de INFORMACION (16/09). Una receta vieja
                # sin ellos es de accion, como siempre.
                $tipoR = if ([string]$x.tipo -eq 'info') { 'info' } else { 'accion' }
                $vozR = $null
                if ($x.voz) {
                    $vozR = @{ modo = [string]$x.voz.modo; plantilla = [string]$x.voz.plantilla
                               vacio = [string]$x.voz.vacio; instruccion = [string]$x.voz.instruccion }
                }
                [void]$script:recetas.Add(@{ id = [int]$x.id; frase = [string]$x.frase; resumen = [string]$x.resumen; respuesta = [string]$x.respuesta
                    pasos = $pasos; variantes = $vars; ejemplo = [string]$x.ejemplo; creada = [string]$x.creada
                    usos = [int]$x.usos; confirmadas = [int]$x.confirmadas; fallos = [int]$x.fallos; rechazos = [int]$x.rechazos
                    tipo = $tipoR; voz = $vozR })
            }
        } catch { Log ("recetas: no pude leer el archivo: " + $_.Exception.Message); Save-Corrupto $RecetasPath 'recetas' }
    }
    return ,$script:recetas
}

function Save-Recetas {
    try {
        $g = Get-Recetas
        $lista = @()
        foreach ($r in $g) {
            $pasosJ = @()
            foreach ($pp in $r.pasos) { $pasosJ += New-Object PSObject -Property ([ordered]@{ tipo = $pp.tipo; texto = $pp.texto }) }
            $vozJ = $null
            if ($r.voz) {
                $vozJ = New-Object PSObject -Property ([ordered]@{ modo = [string]$r.voz.modo; plantilla = [string]$r.voz.plantilla
                                                                   vacio = [string]$r.voz.vacio; instruccion = [string]$r.voz.instruccion })
            }
            $lista += New-Object PSObject -Property ([ordered]@{ id = $r.id; frase = $r.frase; resumen = $r.resumen; respuesta = $r.respuesta
                pasos = $pasosJ; variantes = @(@($r.variantes) | Where-Object { $_ }); ejemplo = $r.ejemplo; creada = $r.creada; usos = $r.usos; confirmadas = $r.confirmadas; fallos = $r.fallos; rechazos = $r.rechazos
                tipo = $(if ([string]$r.tipo -eq 'info') { 'info' } else { 'accion' }); voz = $vozJ })
        }
        $json = if ($lista.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($lista) -Depth 6 }
        Write-Atomico $RecetasPath $json
    } catch { Log ("recetas: no pude guardar: " + $_.Exception.Message) }
}

# Minusculas y sin tildes, SIN cambiar la longitud: asi un hueco encontrado en
# esta version se recorta del texto ORIGINAL en las mismas posiciones, y una
# ruta o un nombre llegan como se dijeron ("C:\Juegos\Capturas"), no destrozados
# por ConvertTo-Plain.
function ConvertTo-Suave([string]$s) {
    if (-not $s) { return '' }
    $sb = New-Object System.Text.StringBuilder $s.Length
    foreach ($ch in $s.ToLowerInvariant().ToCharArray()) {
        $d = ([string]$ch).Normalize([System.Text.NormalizationForm]::FormD)
        [void]$sb.Append($d[0])
    }
    return $sb.ToString()
}

function Get-PatronReceta([string]$frase) {
    $trozos = [regex]::Split((ConvertTo-Suave $frase).Trim(), '(\{[a-z_]{1,20}\})')
    $partes = @()
    foreach ($t in $trozos) {
        if ($t -match '^\{([a-z_]{1,20})\}$') { $nombreH = $Matches[1]; $partes += "(?<$nombreH>.+?)"; continue }
        $palabras = @((($t -replace '[,.;:!?"]', ' ').Trim() -split '\s+') | Where-Object { $_ })
        if ($palabras.Count -eq 0) { continue }
        $partes += (($palabras | ForEach-Object { [regex]::Escape($_) }) -join '[\s,.;:]+')
    }
    if ($partes.Count -eq 0) { return $null }
    return ('^[\s,.;:]*' + ($partes -join '[\s,.;:]+') + '[\s,.;:!?]*$')
}

# La receta mas ESPECIFICA (mas texto fijo) que encaje, con los valores de sus
# huecos recortados del texto original. $lista permite probar una sola receta.
function Find-Receta([string]$text, $lista = $null) {
    if (-not $RecetasOn -or -not $text -or $script:invitado) { return $null }
    $g = if ($null -ne $lista) { $lista } else { Get-Recetas }
    if (@($g).Count -eq 0) { return $null }
    # la cortesia de delante no cuenta: "oye nova, puedes crear..."
    $base = [regex]::Replace($text, '^\s*(?:(?:nova|oye|hola|por favor|porfa|puedes|podrias|me puedes|quiero que|necesito que)[\s,]+)+', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $suave = ConvertTo-Suave $base
    $mejor = $null; $mejorLargo = -1
    foreach ($r in $g) {
      # la frase con la que se aprendio y las OTRAS formas de decirlo que ha ido
      # aprendiendo (ver Get-VarianteReceta)
      foreach ($plantilla in (@([string]$r.frase) + @(@($r.variantes) | Where-Object { $_ }))) {
        $pat = Get-PatronReceta $plantilla
        if (-not $pat) { continue }
        $m = $null
        try { $m = [regex]::Match($suave, $pat) } catch { continue }
        if (-not $m.Success) { continue }
        $largo = ((ConvertTo-Suave $plantilla) -replace '\{[a-z_]+\}', '').Length
        if ($largo -le $mejorLargo) { continue }
        $vals = @{}
        $bien = $true
        foreach ($nombreH in @([regex]::Matches((ConvertTo-Suave $plantilla), '\{([a-z_]{1,20})\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)) {
            $grp = $m.Groups[$nombreH]
            if (-not $grp.Success) { $bien = $false; break }
            $v = $base.Substring($grp.Index, $grp.Length).Trim().TrimEnd('.', ',', ';', '!', '?').Trim()
            if (-not $v -or $v.Length -gt 200) { $bien = $false; break }
            $vals[$nombreH] = $v
        }
        if (-not $bien) { continue }
        $mejor = @{ receta = $r; valores = $vals; plantilla = $plantilla }
        $mejorLargo = $largo
      }
    }
    return $mejor
}

# OTRA FORMA DE DECIR UNA RECETA. De "hazme una carpeta Fotos en el escritorio"
# con nombre=Fotos sale "hazme una carpeta {nombre} en el escritorio". Solo si
# TODOS los valores estan tal cual en la frase: si Haiku corrigio o completo
# algo, no se inventa una plantilla que luego no encajaria.
function Get-VarianteReceta([string]$original, $valores) {
    $base = [regex]::Replace($original, '^\s*(?:(?:nova|oye|hola|por favor|porfa|puedes|podrias|me puedes|quiero que|necesito que)[\s,]+)+', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $plantilla = ConvertTo-Suave ($base.Trim().TrimEnd('.', ',', ';', '!', '?').Trim())
    # los valores mas largos primero: que "fotos" no se coma parte de "fotos viejas"
    foreach ($k in @($valores.Keys | Sort-Object { -([string]$valores[$_]).Length })) {
        $v = ConvertTo-Suave ([string]$valores[$k])
        if (-not $v) { return $null }
        $i = $plantilla.IndexOf($v)
        if ($i -lt 0) { return $null }
        $plantilla = $plantilla.Substring(0, $i) + '{' + $k + '}' + $plantilla.Substring($i + $v.Length)
    }
    $plantilla = ($plantilla -replace '\s+', ' ').Trim()
    $literales = @((($plantilla -replace '\{[^}]*\}', ' ') -replace '[^a-z0-9 ]', ' ').Trim() -split '\s+' | Where-Object { $_.Length -ge 2 })
    if ($literales.Count -lt 2) { return $null }
    return $plantilla
}

# RECETAS QUE PREGUNTAN LO QUE FALTA (13/09): "crea una carpeta" cuando se
# aprendio "crea una carpeta llamada {nombre}". Solo si la frase aprendida tiene
# UN hueco y va al FINAL: se quita con su enlace ("llamada", "que se llame",
# "en la"...) y, si lo que queda encaja con lo dicho, se pregunta el valor.
function Find-RecetaIncompleta([string]$text, $lista = $null) {
    if (-not $RecetasOn -or -not $text -or $script:invitado) { return $null }
    $g = if ($null -ne $lista) { $lista } else { Get-Recetas }
    if (@($g).Count -eq 0) { return $null }
    $base = [regex]::Replace($text, '^\s*(?:(?:nova|oye|hola|por favor|porfa|puedes|podrias|me puedes|quiero que|necesito que)[\s,]+)+', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $suave = ConvertTo-Suave $base
    foreach ($r in $g) {
        foreach ($plantilla in (@([string]$r.frase) + @(@($r.variantes) | Where-Object { $_ }))) {
            $ps = (ConvertTo-Suave $plantilla).Trim().TrimEnd('.', '!', '?').Trim()
            if (@([regex]::Matches($ps, '\{[a-z_]{1,20}\}')).Count -ne 1) { continue }
            $mH = [regex]::Match($ps, '^(.*?)[\s,]*\{([a-z_]{1,20})\}$')
            if (-not $mH.Success) { continue }
            $sin = $mH.Groups[1].Value.Trim()
            for ($k = 0; $k -lt 3; $k++) {
                $sin = [regex]::Replace($sin, '\s+(?:llamad[oa]s?|que se llame|con el nombre|con nombre|de nombre|nombre|de|del|en|a|al|con|para|sobre|por|el|la|los|las|un|una)$', '').Trim()
            }
            if (@($sin -split '\s+' | Where-Object { $_ }).Count -lt 2) { continue }
            $pat = Get-PatronReceta $sin
            if ($pat -and [regex]::IsMatch($suave, $pat)) { return @{ receta = $r; hueco = $mH.Groups[2].Value } }
        }
    }
    return $null
}

function Add-VarianteReceta($r, [string]$variante) {
    if (-not $variante) { return }
    if (-not $r.variantes) { $r.variantes = New-Object System.Collections.ArrayList }
    foreach ($pl in (@([string]$r.frase) + @($r.variantes))) { if ((ConvertTo-Suave ([string]$pl)) -eq (ConvertTo-Suave $variante)) { return } }
    [void]$r.variantes.Add($variante)
    while ($r.variantes.Count -gt 20) { $r.variantes.RemoveAt(0) }
    Save-Recetas
    Log "RECETA $($r.id): aprendida otra forma de decirlo: '$variante'"
    Add-Estadistica 'receta-variante' $variante
    Set-AcabaDeAprender
}

# SOLO LECTURA DE VERDAD (16/09). Una receta de informacion se ejecuta SIN preguntar,
# asi que su script no puede tocar nada. Aqui no vale la lista de lo prohibido (siempre
# se queda corta): se exige que TODO lo que parezca un comando este en esta lista.
$CMDLETS_LECTURA = @(
    'get-childitem', 'gci', 'ls', 'dir', 'get-item', 'gi', 'get-content', 'gc', 'cat',
    'test-path', 'join-path', 'split-path', 'resolve-path', 'get-process', 'get-date',
    'get-ciminstance', 'get-itemproperty', 'measure-object', 'measure', 'select-object',
    'select', 'sort-object', 'sort', 'where-object', 'where', 'foreach-object', 'foreach',
    'group-object', 'group', 'convertto-json', 'convertfrom-json', 'out-string',
    'select-string', 'compare-object', 'get-volume', 'get-psdrive', 'write-output', 'echo'
)
function Test-ScriptSoloLectura([string]$s) {
    if (-not $s) { return $false }
    if (Test-ScriptProhibido $s) { return $false }
    # nada que escriba, redirija o llame fuera: >, >>, .exe, &, ., start, cmd
    if ($s -match '(?m)(?<![-\w])>{1,2}(?!\s*\$null)') { return $false }
    if ($s -match '(?i)\b(?:start-process|new-object\s+system\.diagnostics|saps|cmd|powershell|pwsh|\w+\.exe)\b') { return $false }
    if ($s -match '(?m)^\s*[&.]\s') { return $false }
    # los verbos que cambian algo, aunque no esten en la lista de prohibidos
    if ($s -match '(?i)\b(?:set|new|remove|clear|add|move|copy|rename|start|stop|invoke|out|export|import|write|register|unregister|enable|disable|install|uninstall|restart|suspend|resume|send|receive)-\w+\b') {
        # Write-Output y Out-String si valen: no cambian nada
        $malos = @([regex]::Matches($s, '(?i)\b(?:set|new|remove|clear|add|move|copy|rename|start|stop|invoke|out|export|import|write|register|unregister|enable|disable|install|uninstall|restart|suspend|resume|send|receive)-\w+\b') |
                   ForEach-Object { $_.Value.ToLowerInvariant() } | Where-Object { $CMDLETS_LECTURA -notcontains $_ })
        if ($malos.Count -gt 0) { return $false }
    }
    return $true
}

function Test-ScriptProhibido([string]$s) {
    if ($s -match $RE_RECETA_PROHIBIDO) { return $true }
    # los alias cortos solo cuentan en posicion de comando: "del" o "rd" dentro
    # de un texto ("carpeta del juego") no son nada
    if ($s -match '(?im)(?:^|[;|&{(])\s*(?:rm|rd|rmdir|del|erase|kill|ri|spps|iex|iwr|irm)\s') { return $true }
    return $false
}

function Get-TextoReceta($r, [string]$campo, $valores) {
    $t = [string]$r[$campo]
    if (-not $t) { $t = [string]$r.frase }
    foreach ($k in $valores.Keys) { $t = $t.Replace('{' + $k + '}', [string]$valores[$k]) }
    return ($t -replace '\{[a-z_]+\}', 'algo')
}

# Valida lo que devolvio el cerebro y, si vale, lo guarda. Devuelve la receta o
# $null, y siempre deja en el log por que no se aprendio.
function Add-Receta([string]$original, [string]$bloque) {
    $ini = $bloque.IndexOf('{'); $fin = $bloque.LastIndexOf('}')
    if ($ini -lt 0 -or $fin -le $ini) { Log "RECETA descartada: no trae JSON"; return $null }
    $o = $null
    try { $o = $bloque.Substring($ini, $fin - $ini + 1) | ConvertFrom-Json } catch { Log "RECETA descartada: el JSON no es valido"; return $null }
    $frase = ([string]$o.frase).Trim()
    if ($frase.Length -lt 6 -or $frase.Length -gt 160) { Log "RECETA descartada: frase vacia o demasiado larga"; return $null }
    $huecos = @([regex]::Matches($frase, '\{([^}]*)\}') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    if ($huecos.Count -gt 3) { Log "RECETA descartada: mas de 3 huecos"; return $null }
    $reservados = @('args', 'input', 'host', 'error', 'home', 'pid', 'pwd', 'true', 'false', 'null', 'this', 'matches', 'profile',
                    'psitem', 'lastexitcode', 'executioncontext', 'myinvocation', 'shellid', 'env', 'foreach', 'switch', 'sender', 'event')
    foreach ($h in $huecos) {
        if ($h -notmatch '^[a-z_]{1,20}$' -or $reservados -contains $h) { Log "RECETA descartada: hueco '$h' no valido"; return $null }
    }
    $literales = @(((ConvertTo-Suave $frase) -replace '\{[^}]*\}', ' ' -replace '[^a-z0-9 ]', ' ').Trim() -split '\s+' | Where-Object { $_.Length -ge 2 })
    if ($literales.Count -lt 2) { Log "RECETA descartada: la frase es demasiado general"; return $null }
    $pasos = New-Object System.Collections.ArrayList
    foreach ($pp in @($o.pasos)) {
        if ($null -eq $pp) { continue }
        $tipo = ([string]$pp.tipo).ToLowerInvariant()
        $cuerpo = if ($tipo -eq 'powershell' -or $tipo -eq 'lectura') { [string]$pp.script } else { [string]$pp.texto }
        if (-not $cuerpo.Trim() -and $tipo -eq 'lectura') { $cuerpo = [string]$pp.texto }
        if (@('powershell', 'orden', 'lectura') -notcontains $tipo -or -not $cuerpo.Trim()) { Log "RECETA descartada: paso '$tipo' no valido"; return $null }
        if ($tipo -eq 'powershell' -and ($cuerpo.Length -gt 2000 -or (Test-ScriptProhibido $cuerpo))) { Log "RECETA descartada: el script hace algo que no puede ir en una receta"; return $null }
        # un paso de LECTURA se ejecutara sin preguntar, asi que se le exige mas: lista
        # blanca, no lista negra (ver SOLO LECTURA DE VERDAD)
        if ($tipo -eq 'lectura' -and ($cuerpo.Length -gt 2000 -or -not (Test-ScriptSoloLectura $cuerpo))) { Log "RECETA descartada: el paso de lectura no es solo de lectura"; return $null }
        if ($tipo -eq 'orden' -and $cuerpo.Length -gt 120) { Log "RECETA descartada: orden demasiado larga"; return $null }
        [void]$pasos.Add(@{ tipo = $tipo; texto = $cuerpo })
    }
    if ($pasos.Count -lt 1 -or $pasos.Count -gt 6) { Log "RECETA descartada: sin pasos o con demasiados"; return $null }
    # la frase que dijo el usuario TIENE que encajar en su propia plantilla
    $prov = @{ id = 0; frase = $frase; pasos = $pasos }
    $enc = Find-Receta $original @($prov)
    # ...o con su PRIMERA PARTE: "crea una carpeta X en el escritorio, ahi es
    # donde guardo mis partidas" lleva una coletilla que no es la orden, y la
    # plantilla del cerebro, bien hecha, no la incluye (13/09: se perdia la
    # receta). Lo de detras de la coma es comentario.
    if (-not $enc -and $original -match '^\s*([^,;]{6,}?)\s*[,;]') {
        $primeraParte = $Matches[1]
        $enc = Find-Receta $primeraParte @($prov)
        if ($enc) { Log "RECETA: '$frase' encaja con la primera parte de la frase ('$primeraParte')" }
    }
    # ...o SIN LA CORTESIA (auditoria del 13/09): "puedes contar los archivos de mi
    # carpeta de descargas" no encajaba en "cuenta los archivos de mi carpeta de
    # {carpeta}" y la receta se perdia siempre. Se quita "puedes/podrias/quiero
    # que..." y, si aun asi el primer verbo no coincide, la plantilla se guarda
    # con TU verbo: es como lo vas a volver a decir.
    if (-not $enc) {
        $limpio = ($original -replace '(?i)^\s*(?:(?:oye|hey|ey|nova|por favor|porfa)[\s,]+)*(?:me\s+)?(?:puedes|podrias|podrías|podras|podrás|quiero que|me gustaria que|me gustaría que|necesito que)\s+(?:me\s+)?', '').Trim()
        if ($limpio -and $limpio -ne $original.Trim()) {
            $enc = Find-Receta $limpio @($prov)
            if (-not $enc) {
                $pl = @($limpio -split '\s+'); $pf = @($frase -split '\s+')
                if ($pl.Count -gt 1 -and $pf.Count -gt 1 -and $pf[0] -notmatch '\{') {
                    $frase2 = (@($pl[0]) + @($pf[1..($pf.Count - 1)])) -join ' '
                    $prov2 = @{ id = 0; frase = $frase2; pasos = $pasos }
                    $enc = Find-Receta $limpio @($prov2)
                    if ($enc) { Log "RECETA: plantilla ajustada a como lo dijiste: '$frase2'"; $frase = $frase2; $prov = $prov2 }
                }
            }
        }
    }
    if (-not $enc) { Log "RECETA descartada: '$original' no encaja en '$frase'"; return $null }
    # y las ordenes de Nova tienen que existir, con los valores de esta vez
    foreach ($pp in $pasos) {
        if ($pp.tipo -ne 'orden') { continue }
        $t = $pp.texto
        foreach ($k in $enc.valores.Keys) { $t = $t.Replace('{' + $k + '}', [string]$enc.valores[$k]) }
        if (-not (Test-FastCommand $t)) { Log "RECETA descartada: Nova no entiende la orden '$t'"; return $null }
    }
    $g = Get-Recetas
    # la misma plantilla aprendida otra vez sustituye a la anterior
    $clave = ConvertTo-Suave $frase
    # ...conservando las otras formas de decirla que ya se hubieran aprendido
    $varsViejas = New-Object System.Collections.ArrayList
    foreach ($x in @($g)) {
        if ((ConvertTo-Suave ([string]$x.frase)) -eq $clave) {
            foreach ($vv in @($x.variantes)) { if ($vv) { [void]$varsViejas.Add([string]$vv) } }
            [void]$g.Remove($x)
        }
    }
    $id = 1; foreach ($x in $g) { if ($x.id -ge $id) { $id = $x.id + 1 } }
    # RECETA DE INFORMACION (16/09): la que solo mira y dice. Necesita su plantilla de
    # voz; sin ella no sabria que decir con los datos, asi que no se aprende.
    $tipoN = if (([string]$o.tipo).ToLowerInvariant() -eq 'info') { 'info' } else { 'accion' }
    $vozN = $null
    if ($tipoN -eq 'info') {
        if (@($pasos | Where-Object { $_.tipo -eq 'lectura' }).Count -eq 0) { Log "RECETA descartada: es de informacion y no trae ningun paso de lectura"; return $null }
        if (@($pasos | Where-Object { $_.tipo -eq 'powershell' }).Count -gt 0) { Log "RECETA descartada: una receta de informacion no puede llevar pasos que cambien algo"; return $null }
        $plantillaN = ([string]$o.voz.plantilla).Trim()
        if (-not $plantillaN) { Log "RECETA descartada: es de informacion y no dice como contarlo (falta voz.plantilla)"; return $null }
        $vozN = @{ modo = 'plantilla'; plantilla = $plantillaN; vacio = ([string]$o.voz.vacio).Trim(); instruccion = ([string]$o.voz.instruccion).Trim() }
    }
    $r = @{ id = $id; frase = $frase; resumen = ([string]$o.resumen).Trim(); respuesta = ([string]$o.respuesta).Trim(); pasos = $pasos; variantes = $varsViejas
            ejemplo = $original; creada = (Get-Date -Format 's'); usos = 0; confirmadas = 0; fallos = 0; rechazos = 0
            tipo = $tipoN; voz = $vozN }
    [void]$g.Add($r)
    while ($g.Count -gt $RecetasMax) { $g.RemoveAt(0) }
    Save-Recetas
    Log "RECETA $id aprendida: '$frase' ($($pasos.Count) pasos)"
    Add-Estadistica 'receta-aprendida' $frase
    Set-AcabaDeAprender
    return $r
}

# Ejecuta los pasos. Cada script va en un PowerShell oculto con tope de 20 s,
# con los valores declarados ANTES como variables de texto escapadas.
# UN PASO DE SCRIPT, EN DOS MITADES (14/09): arrancarlo y recogerlo. Invoke-Receta
# espera entre las dos; Start-Receta no (ver RECETA SIN BLOQUEAR).
function Start-PasoScript([string]$cuerpo, $valores) {
    # se vuelve a mirar al ejecutar: el archivo de recetas se puede editar a mano
    if (Test-ScriptProhibido $cuerpo) { return @{ ok = $false; error = 'el script tiene algo prohibido' } }
    $rutaS = Join-Path $TmpDir ("receta-" + [System.Guid]::NewGuid().ToString('N') + ".ps1")
    $cab = "`$ErrorActionPreference = 'Stop'`r`n"
    # LOS VALORES NUNCA VAN PEGADOS EN EL SCRIPT (auditoria del 13/09):
    # duplicar la ' no bastaba, PowerShell tambien cierra una cadena con
    # comillas tipograficas y un valor dictado colaba codigo. Viajan en variables
    # de entorno del proceso hijo y el script solo las lee.
    foreach ($k in $valores.Keys) {
        if ($k -notmatch '^[a-z_]{1,20}$') { return @{ ok = $false; error = "hueco '$k' no valido" } }
        $cab += ('$' + $k + " = [Environment]::GetEnvironmentVariable('NOVA_HUECO_" + $k + "')`r`n")
    }
    [System.IO.File]::WriteAllText($rutaS, $cab + $cuerpo, (New-Object System.Text.UTF8Encoding($true)))
    # el error del script se guarda: es lo que el cerebro necesita para arreglar
    # la receta (ver Complete-RecetaResultado, autorreparacion)
    $rutaE = [System.IO.Path]::ChangeExtension($rutaS, '.err.txt')
    # LO QUE DEVUELVE EL SCRIPT (16/09): hasta ahora solo se guardaba el error, y por eso
    # una receta no podia DECIR datos. Con la salida en un archivo, un paso de lectura
    # puede contestar "en el escritorio tienes 3 cosas: ...".
    $rutaO = [System.IO.Path]::ChangeExtension($rutaS, '.out.txt')
    try {
        foreach ($k in $valores.Keys) { [Environment]::SetEnvironmentVariable("NOVA_HUECO_$k", [string]$valores[$k], 'Process') }
        $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File ' + (ConvertTo-CmdArg $rutaS)) `
            -WorkingDirectory $WORKDIR -WindowStyle Hidden -PassThru -RedirectStandardError $rutaE -RedirectStandardOutput $rutaO
        $null = $pr.Handle
        return @{ ok = $true; proc = $pr; rutaS = $rutaS; rutaE = $rutaE; rutaO = $rutaO }
    } catch {
        Remove-Item -LiteralPath $rutaS -Force -ErrorAction SilentlyContinue
        return @{ ok = $false; error = "no pude ejecutar el script: $($_.Exception.Message)" }
    } finally {
        # el hijo ya se llevo su copia del entorno al arrancar
        foreach ($k in $valores.Keys) { [Environment]::SetEnvironmentVariable("NOVA_HUECO_$k", $null, 'Process') }
    }
}
# '' si fue bien; si no, el error. Borra los archivos del paso.
# La SALIDA del script queda en $script:ultimaSalidaPaso (ver LO QUE DEVUELVE EL
# SCRIPT). No se devuelve aqui para no cambiarle el contrato a los tres sitios que
# llaman a esta funcion esperando un texto de error.
$script:ultimaSalidaPaso = ''
function Complete-PasoScript($ini, [bool]$tiempoAgotado = $false) {
    $script:ultimaSalidaPaso = ''
    try {
        if ($ini.rutaO -and (Test-Path -LiteralPath $ini.rutaO)) {
            try {
                $sal = [System.IO.File]::ReadAllText($ini.rutaO, [System.Text.Encoding]::UTF8)
                if ($sal.Length -gt 4000) { $sal = $sal.Substring(0, 4000) }
                $script:ultimaSalidaPaso = $sal.Trim()
            } catch {}
        }
        if ($tiempoAgotado) { try { $ini.proc.Kill() } catch {}; return 'tardo mas de 20 s' }
        if ($ini.proc.ExitCode -ne 0) {
            $errTxt = ''
            # PowerShell 5.1 escribe sus errores con la codificacion de la
            # consola (OEM), no en UTF-8: leido como UTF-8 salia "t?rmino"
            try { $errTxt = (([System.IO.File]::ReadAllText($ini.rutaE, [System.Text.Encoding]::GetEncoding([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage))) -replace '\s+', ' ').Trim() } catch {}
            if ($errTxt.Length -gt 400) { $errTxt = $errTxt.Substring(0, 400) }
            return "el script termino con codigo $($ini.proc.ExitCode): $errTxt"
        }
        return ''
    } finally {
        Remove-Item -LiteralPath $ini.rutaS -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $ini.rutaE -Force -ErrorAction SilentlyContinue
        if ($ini.rutaO) { Remove-Item -LiteralPath $ini.rutaO -Force -ErrorAction SilentlyContinue }
    }
}

# DE LOS DATOS A LA FRASE (16/09). El script de lectura devuelve UN objeto JSON y la
# receta trae una plantilla: "En el escritorio tienes {cuantos|cosa|cosas}: {nombres}".
#   {campo}                  -> el valor tal cual
#   {campo|singular|plural}  -> el numero y su palabra ("3 cosas", "1 cosa")
# Si no hay nada que decir (0, vacio o el campo no esta), se dice el texto de "vacio".
function Format-VozInfo($voz, [string]$salida) {
    if (-not $voz) { return '' }
    $plantilla = [string]$voz.plantilla
    if (-not $plantilla) { return '' }
    $datos = $null
    if ($salida) { try { $datos = $salida | ConvertFrom-Json } catch { $datos = $null } }
    if ($null -eq $datos) { return [string]$voz.vacio }
    # ¿hay algo que contar? un 0 o una lista vacia es "no hay nada"
    $hayAlgo = $false
    $texto = [regex]::Replace($plantilla, '\{([a-z_]+)(?:\|([^|}]+)\|([^}]+))?\}', {
        param($m)
        $campo = $m.Groups[1].Value
        $val = $null
        try { $val = $datos.$campo } catch { $val = $null }
        if ($null -eq $val) { return '' }
        if ($val -is [System.Array]) {
            if ($val.Count -gt 0) { $script:vozHayAlgo = $true }
            if ($m.Groups[2].Success) { return ('' + $val.Count + ' ' + $(if ($val.Count -eq 1) { $m.Groups[2].Value } else { $m.Groups[3].Value })) }
            return (@($val | ForEach-Object { [string]$_ }) -join ', ')
        }
        if ($val -is [int] -or $val -is [long] -or $val -is [double]) {
            if ([double]$val -gt 0) { $script:vozHayAlgo = $true }
            if ($m.Groups[2].Success) { return ('' + $val + ' ' + $(if ([double]$val -eq 1) { $m.Groups[2].Value } else { $m.Groups[3].Value })) }
            return [string]$val
        }
        if ([string]$val) { $script:vozHayAlgo = $true }
        return [string]$val
    })
    $hayAlgo = [bool]$script:vozHayAlgo
    $script:vozHayAlgo = $false
    if (-not $hayAlgo -and [string]$voz.vacio) { return [string]$voz.vacio }
    return (($texto -replace '\s+', ' ').Trim())
}
$script:vozHayAlgo = $false

function Invoke-Receta($r, $valores) {
    $salidaInv = ''
    foreach ($paso in $r.pasos) {
        $tipo = [string]$paso.tipo; $cuerpo = [string]$paso.texto
        if ($tipo -eq 'orden') {
            $orden = $cuerpo
            foreach ($k in $valores.Keys) { $orden = $orden.Replace('{' + $k + '}', [string]$valores[$k]) }
            $res = $null
            try { $res = Invoke-FastCommand $orden } catch { $res = $null }
            if (-not $res) { return @{ ok = $false; error = "la orden '$orden' no se pudo hacer" } }
        } elseif ($tipo -eq 'powershell' -or $tipo -eq 'lectura') {
            # aqui se ESPERA al script; la receta con el bucle libre va por
            # Start-Receta (ver RECETA SIN BLOQUEAR)
            if ($tipo -eq 'lectura' -and -not (Test-ScriptSoloLectura $cuerpo)) { return @{ ok = $false; error = 'el paso de lectura ya no es solo de lectura' } }
            $ini = Start-PasoScript $cuerpo $valores
            if (-not $ini.ok) { return @{ ok = $false; error = $ini.error } }
            $termino = $ini.proc.WaitForExit(20000)
            $errP = Complete-PasoScript $ini (-not $termino)
            if ($script:ultimaSalidaPaso) { $salidaInv = $script:ultimaSalidaPaso }
            if ($errP) { return @{ ok = $false; error = $errP } }
        } else {
            return @{ ok = $false; error = "paso desconocido '$tipo'" }
        }
    }
    $txt = Get-TextoReceta $r 'respuesta' $valores
    if ([string]$r.tipo -eq 'info') {
        $txtI = Format-VozInfo $r.voz $salidaInv
        if ($txtI) { $txt = $txtI } elseif (-not ([string]$r.respuesta)) { $txt = 'No pude averiguarlo.' }
    } elseif (-not ([string]$r.respuesta)) { $txt = 'Hecho, como la otra vez.' }
    return @{ ok = $true; texto = $txt }
}

# ENSEÑADA POR TI: "aprende que cuando diga prepara la partida, abre discord,
# pon modo juego y baja el volumen al 40". Una receta de ordenes que Nova ya
# sabe hacer, sin IA. Como la pediste tu, nace de confianza: no pregunta.
# Cada orden se comprueba ANTES de guardar, igual que al crear un modo.
function New-RecetaEnsenada([string]$disparador, [string]$cuerpo) {
    $disp = (($disparador -replace '["«»“”{}]', '') -replace '\s+', ' ').Trim().TrimEnd('.', ',', ':', ';').Trim()
    $palabras = @(((ConvertTo-Suave $disp) -replace '[^a-z0-9 ]', ' ').Trim() -split '\s+' | Where-Object { $_ })
    if ($palabras.Count -lt 2) { return @{ ok = $false; texto = "Necesito una frase de al menos dos palabras para acordarme." } }
    # que no pise lo que ya significa algo: "cuando diga abre steam, ..." no
    if (Test-FastCommand $disp) { return @{ ok = $false; texto = "'$disp' ya significa otra cosa para mi; elige otra frase." } }
    $lineas = @(); $malas = @()
    foreach ($fr in @(Split-Ordenes $cuerpo)) {
        if (-not $fr) { continue }
        if (Resolve-Fragment $fr) { $lineas += $fr } else { $malas += $fr }
    }
    if ($lineas.Count -eq 0) { return @{ ok = $false; texto = "No entendi ninguna de esas ordenes, asi que no he aprendido nada." } }
    if ($lineas.Count -gt 6) { $lineas = @($lineas | Select-Object -First 6) }
    $g = Get-Recetas
    $clave = ((ConvertTo-Suave $disp) -replace '\s+', ' ').Trim()
    foreach ($x in @($g)) { if ((ConvertTo-Suave ([string]$x.frase)) -eq $clave) { [void]$g.Remove($x) } }
    $pasos = New-Object System.Collections.ArrayList
    foreach ($l in $lineas) { [void]$pasos.Add(@{ tipo = 'orden'; texto = $l }) }
    $id = 1; foreach ($x in $g) { if ($x.id -ge $id) { $id = $x.id + 1 } }
    $r = @{ id = $id; frase = $clave; resumen = ($lineas -join ', '); respuesta = 'Hecho.'; pasos = $pasos
            variantes = (New-Object System.Collections.ArrayList); ejemplo = $disp; creada = (Get-Date -Format 's')
            usos = 0; confirmadas = [Math]::Max(0, $RecetasConfirmar); fallos = 0; rechazos = 0 }
    [void]$g.Add($r)
    Save-Recetas
    $script:ultimaReceta = $id
    $script:ultimaRecetaEn = $sw.ElapsedMilliseconds
    Log "RECETA $id ensenada: '$clave' -> $($lineas -join ' | ')"
    Add-Estadistica 'receta-ensenada' $clave
    Set-AcabaDeAprender
    $txt = "Aprendido: cuando digas '$disp', hare " + $(if ($lineas.Count -eq 1) { 'esto: ' } else { "$($lineas.Count) cosas: " }) + ($lineas -join '; ') + '.'
    if ($malas.Count -gt 0) { $txt += " Esto no lo entendi y lo he dejado fuera: " + ($malas -join '; ') + '.' }
    return @{ ok = $true; texto = $txt }
}

# RECETA SIN BLOQUEAR (M11, 14/09): un paso de script esperaba hasta 20 s con el
# bucle parado: el boton no respondia y la capsula se quedaba congelada. Ahora,
# si la receta lleva scripts, Step-Receta arranca los pasos, Watch-Receta mira en
# cada vuelta del bucle si el script acabo, y al terminar Complete-RecetaResultado
# hace lo de siempre (contar, aprender, reparar, contestar). $variante: la forma
# de decirlo que se aprende si sale bien (el "si" a "¿lo hago?").
$script:recetaEnCurso = $null
function Start-Receta($enc, [string]$text, [string]$variante = '') {
    $r = $enc.receta
    if ($script:recetaEnCurso) {
        Log "RECETA $($r.id): hay otra en curso; esta no se empieza"
        Say 'Espera, todavia estoy con la tarea de antes.'
        return $false
    }
    Log "RECETA $($r.id): '$text' -> la hago sin IA"
    Set-UI 'pensando' 'Como la otra vez'
    if (@(@($r.pasos) | Where-Object { @('powershell', 'lectura') -contains [string]$_.tipo }).Count -gt 0) {
        $script:recetaEnCurso = @{ enc = $enc; texto = $text; variante = $variante; paso = 0; ini = $null; desde = 0; salida = '' }
        Step-Receta
        return 'enCurso'
    }
    return (Complete-RecetaResultado $enc $text (Invoke-Receta $r $enc.valores) $variante)
}

function Step-Receta {
    $e = $script:recetaEnCurso
    if (-not $e) { return }
    $r = $e.enc.receta
    $valores = $e.enc.valores
    $pasos = @($r.pasos)
    while ($e.paso -lt $pasos.Count) {
        $paso = $pasos[$e.paso]
        $tipo = [string]$paso.tipo; $cuerpo = [string]$paso.texto
        if ($tipo -eq 'orden') {
            $orden = $cuerpo
            foreach ($k in $valores.Keys) { $orden = $orden.Replace('{' + $k + '}', [string]$valores[$k]) }
            $resO = $null
            try { $resO = Invoke-FastCommand $orden } catch { $resO = $null }
            if (-not $resO) { Close-Receta @{ ok = $false; error = "la orden '$orden' no se pudo hacer" }; return }
            $e.paso++
        } elseif ($tipo -eq 'powershell' -or $tipo -eq 'lectura') {
            # se vuelve a comprobar al ejecutar, no solo al aprender: el archivo de
            # recetas se puede editar a mano (ver SOLO LECTURA DE VERDAD)
            if ($tipo -eq 'lectura' -and -not (Test-ScriptSoloLectura $cuerpo)) {
                Close-Receta @{ ok = $false; error = 'el paso de lectura ya no es solo de lectura' }; return
            }
            $ini = Start-PasoScript $cuerpo $valores
            if (-not $ini.ok) { Close-Receta @{ ok = $false; error = $ini.error }; return }
            $e.ini = $ini
            $e.desde = $sw.ElapsedMilliseconds
            return    # lo recoge Watch-Receta
        } else {
            Close-Receta @{ ok = $false; error = "paso desconocido '$tipo'" }
            return
        }
    }
    $txt = Get-TextoReceta $r 'respuesta' $valores
    if ([string]$r.tipo -eq 'info') {
        # los datos que leyo el ultimo paso, dichos con su plantilla
        $txtI = Format-VozInfo $r.voz ([string]$e.salida)
        if ($txtI) { $txt = $txtI } elseif (-not ([string]$r.respuesta)) { $txt = 'No pude averiguarlo.' }
    } elseif (-not ([string]$r.respuesta)) { $txt = 'Hecho, como la otra vez.' }
    Close-Receta @{ ok = $true; texto = $txt }
}

function Watch-Receta {
    $e = $script:recetaEnCurso
    if (-not $e -or -not $e.ini) { return }
    $ini = $e.ini
    if ($ini.proc.HasExited) { $errP = Complete-PasoScript $ini $false }
    elseif (($sw.ElapsedMilliseconds - $e.desde) -ge 20000) { $errP = Complete-PasoScript $ini $true }
    else { return }
    $e.ini = $null
    # la salida viaja con la receta: Complete-PasoScript la borra en el paso siguiente
    if ($script:ultimaSalidaPaso) { $e.salida = $script:ultimaSalidaPaso }
    if ($errP) { Close-Receta @{ ok = $false; error = $errP }; return }
    $e.paso++
    Step-Receta
}

function Close-Receta($res) {
    $e = $script:recetaEnCurso
    $script:recetaEnCurso = $null
    if ($e) { [void](Complete-RecetaResultado $e.enc $e.texto $res $e.variante) }
}

function Complete-RecetaResultado($enc, [string]$text, $res, [string]$variante = '') {
    $r = $enc.receta
    if ($res.ok) {
        $r.usos = [int]$r.usos + 1
        $r.confirmadas = [int]$r.confirmadas + 1
        $r.fallos = 0
        Save-Recetas
        $script:ultimaReceta = $r.id
        $script:ultimaRecetaEn = $sw.ElapsedMilliseconds
        Add-Estadistica 'receta' $text
        $script:ultimaRespuesta = $res.texto
        # no el "hecho" de siempre: el gesto de "lo hice sola, sin IA"
        Send-UIEvento 'gesto:sinia'
        Show-Popup $res.texto
        Say $res.texto
        # dijiste que si Y salio bien: esa forma de decirlo queda aprendida, y la
        # proxima vez encaja en local, sin preguntarle a nadie
        if ($variante) {
            Add-VarianteReceta $r $variante
            # aprender la forma nueva es mas que haberla hecho: esa celebracion gana
            if ($script:acabaDeAprender) { Send-UIEvento 'gesto:aprendido' }
        }
        return $true
    }
    $r.fallos = [int]$r.fallos + 1
    if ($r.fallos -ge 3) {
        $g = Get-Recetas
        [void]$g.Remove($r)
        Log "RECETA $($r.id) olvidada: fallo tres veces seguidas, ni reparada funciona ($($res.error))"
        Save-Recetas
        Submit-Command $text 'accion'
        return $false
    }
    Save-Recetas
    # AUTORREPARACION. Antes una receta que fallaba dos veces se borraba y se
    # perdia lo aprendido. Ahora la tarea va al cerebro CON la receta rota y su
    # error: la hace y devuelve la receta corregida, que ocupa el sitio de la
    # vieja con sus usos, confirmaciones y formas de decirlo (Report-Reply).
    Log "RECETA $($r.id) fallo ($($res.error)); se la doy al cerebro para que la haga y la arregle"
    $script:reparandoReceta = @{ id = $r.id; texto = $text; frase = [string]$r.frase; error = [string]$res.error
                                 pasos = ((@($r.pasos) | ForEach-Object { $_.tipo + ': ' + $_.texto }) -join ' || ') }
    Submit-Command $text 'accion'
    return $false
}

# =====================================================================
# PERFIL: LO QUE NOVA SABE DE TI (13/09)
# Las recetas aprenden a HACER; esto aprende COMO ERES: tus carpetas, tu juego
# favorito, como llamas a las cosas. Lo llena el cerebro (una linea DATO: al
# final de lo que contesta, cuando descubre algo estable) y tu ("aprende que
# mi carpeta de capturas es D:\Capturas"). Va con CADA peticion al cerebro, asi
# que contesta y hace las tareas sabiendolo.
# Un archivo Markdown, una linea por dato: se lee y se corrige a mano.
# =====================================================================
$PerfilPath = Join-Path $MemoriaDir 'perfil.md'
$PerfilMax = 60
$RE_DATO_SENSIBLE = '(?i)contrase|password|\bclave\b|\bpin\b|tarjeta|cuenta bancaria|\bdni\b|pasaporte|seguro social|\bsalud\b|enfermedad|medicamento|diagnostic'

$CcInstruccionDato = @'


Si braya AFIRMA en esta peticion un dato ESTABLE y util sobre si mismo que todavia no esta en su perfil (una carpeta o ruta suya, su juego favorito, como llama a algo, algo que dice que le gusta o que no), escribelo al final en una linea aparte: DATO: <frase corta en tercera persona, por ejemplo: Su carpeta de capturas es D:\Capturas>. Como mucho UNA linea DATO.

Solo lo que el dice de si mismo, con sus palabras. NO escribas DATO si:
- lo has DEDUCIDO tu (que dijera "mi amor" no es un dato sobre su pareja);
- habla de Nova, de lo que hace bien o mal, o se esta quejando ("no me entiendes", "te equivocas");
- es lo que quiere AHORA (una orden, una peticion, algo de un rato), no como es el;
- ya hay algo parecido en su perfil, aunque lo dijera con otras palabras: no repitas ni matices lo que ya esta;
- no estas seguro. En la duda, no escribas nada: una frase inventada se queda ahi para siempre y va con cada peticion.
Nunca contrasenas, claves, dinero ni salud.
'@

function Get-DatosPerfil {
    if (-not (Test-Path -LiteralPath $PerfilPath)) { return @() }
    return @(Get-Content -LiteralPath $PerfilPath -Encoding UTF8 | Where-Object { $_ -match '^\s*-\s+\S' } | ForEach-Object { ($_ -replace '^\s*-\s+', '').Trim() })
}

function Save-DatosPerfil([string[]]$datos) {
    $lineas = @('# Lo que Nova sabe de braya', '',
                'Lo va llenando sola: lo que descubre el cerebro y lo que le dices con "aprende que mi...".',
                'Se puede editar a mano: una linea por dato, empezando por "- ".', '') + @($datos | ForEach-Object { "- $_" })
    [System.IO.File]::WriteAllLines($PerfilPath, [string[]]$lineas, (New-Object System.Text.UTF8Encoding($false)))
}

function Add-DatoPerfil([string]$dato, [string]$fuente = '') {
    if ($script:invitado) { Log "PERFIL: modo invitado, no guardo nada"; return $null }
    $d = ($dato -replace '\s+', ' ').Trim().TrimEnd('.').Trim()
    if ($d.Length -lt 8 -or $d.Length -gt 180) { return $null }
    if ($d -match $RE_DATO_SENSIBLE) { Log "PERFIL: no guardo un dato sensible"; return $null }
    # NI SOBRE NOVA NI DE UNA QUEJA (16/09). El 15/09 acabaron en el perfil, para
    # siempre y viajando con cada peticion: "Braya considera que Nova se equivoca
    # frecuentemente" y "Braya siente que Nova no entiende bien lo que dice".
    $plD = ConvertTo-Suave $d
    if ($plD -match '\b(?:nova|asistente|la ia|el modelo)\b') { Log "PERFIL: no guardo lo que habla de mi: $d"; return $null }
    if ($plD -match '\b(?:se equivoca|no entiende|falla|no funciona|molesta|tarda|lento|frecuentemente)\b' -and
        $plD -match '\b(?:considera|siente|cree|piensa|opina|prefiere que)\b') { Log "PERFIL: eso era una queja, no un dato: $d"; return $null }
    # NI DEDUCCIONES: "Braya tiene una pareja (la llama 'mi amor')" salio de oirle decir
    # "mi amor" una vez. Lo que empieza por "parece", "podria" o va entre parentesis
    # explicando de donde se saco, no es algo que el haya afirmado.
    if ($plD -match '^(?:parece|puede que|posiblemente|probablemente|quiza)\b' -or $plD -match '\(.*(?:la llama|lo llama|porque dijo|segun).*\)') {
        Log "PERFIL: eso es una deduccion, no algo que dijera: $d"; return $null
    }
    $datos = @(Get-DatosPerfil)
    $clave = (((ConvertTo-Suave $d) -replace '[^a-z0-9 ]', ' ') -replace '\s+', ' ').Trim()
    # DEL MISMO TEMA, SOLO UNA (16/09). El filtro viejo solo miraba si la frase nueva
    # estaba CONTENIDA en una vieja, y por eso cabian a la vez "le gusta la musica
    # electronica", "no le gusta la musica electronica" y cinco matices mas. Ahora, si
    # comparte la mayoria de sus palabras con algo que ya se sabe, es el mismo tema: se
    # queda lo que ya habia (y para cambiarlo esta "olvida que...").
    $palD = @($clave -split '\s+' | Where-Object { $_.Length -ge 4 } | Select-Object -Unique)
    foreach ($x in $datos) {
        $cx = (((ConvertTo-Suave $x) -replace '[^a-z0-9 ]', ' ') -replace '\s+', ' ').Trim()
        if ($cx -eq $clave -or $cx.Contains($clave)) { return $null }   # ya lo sabia
        # EN LOS DOS SENTIDOS (16/09): mirar solo que porcentaje de la frase NUEVA esta
        # en la vieja castiga a las frases largas, que son justo las que mas ruido
        # meten ("braya no le gusta cierto estilo de musica electronica que escuchaba
        # recientemente" colaba al lado de "no le gusta la musica electronica").
        $palX = @($cx -split '\s+' | Where-Object { $_.Length -ge 4 } | Select-Object -Unique)
        if ($palD.Count -ge 2 -and $palX.Count -ge 2) {
            $comunes = @($palD | Where-Object { $palX -contains $_ }).Count
            $propD = $comunes / [double]$palD.Count
            $propX = $comunes / [double]$palX.Count
            # el mismo tema si coincide la mayoria de una de las dos, o si comparten
            # tres palabras con contenido (dos frases sobre "musica electronica" lo son)
            if ($propD -ge 0.6 -or $propX -ge 0.6 -or $comunes -ge 3) {
                Log "PERFIL: ya se algo de eso ('$x'); no apunto '$d'"
                return $null
            }
        }
    }
    $datos += $d
    while ($datos.Count -gt $PerfilMax) { $datos = @($datos | Select-Object -Skip 1) }
    Save-DatosPerfil $datos
    Log "PERFIL: aprendido ($fuente): $d"
    Add-Estadistica 'perfil' $d
    Set-AcabaDeAprender
    return $d
}

# Olvida el dato que mas palabras comparta con lo dicho ("olvida que mi juego
# favorito..."). Hace falta que coincidan al menos la mitad de las palabras con
# contenido, para no borrar otra cosa por una palabra suelta.
function Remove-DatoPerfil([string]$sobre) {
    $palabras = @(((ConvertTo-Suave $sobre) -replace '[^a-z0-9 ]', ' ') -split '\s+' | Where-Object { $_.Length -ge 4 } | Select-Object -Unique)
    if ($palabras.Count -eq 0) { return $null }
    $datos = @(Get-DatosPerfil)
    $mejor = $null; $mejorN = 0
    foreach ($x in $datos) {
        $cx = ConvertTo-Suave $x
        $n = @($palabras | Where-Object { $cx.Contains($_) }).Count
        if ($n -gt $mejorN) { $mejor = $x; $mejorN = $n }
    }
    if (-not $mejor -or $mejorN -lt [Math]::Max(1, [Math]::Ceiling($palabras.Count / 2))) { return $null }
    Save-DatosPerfil @($datos | Where-Object { $_ -ne $mejor })
    Log "PERFIL: olvidado: $mejor"
    return $mejor
}

# El prompt de sistema de cada peticion: quien es Nova + lo que sabe de ti.
function Get-SistemaCerebro {
    $base = ''
    try { if (Test-Path -LiteralPath $CcSistema) { $base = [System.IO.File]::ReadAllText($CcSistema, [System.Text.Encoding]::UTF8) } } catch {}
    $datos = if ($script:invitado) { @() } else { @(Get-DatosPerfil) }
    if ($datos.Count -gt 0) {
        $base += "`n`n## Lo que sabes de braya (su perfil: tenlo en cuenta)`n" + (($datos | ForEach-Object { "- $_" }) -join "`n") + "`n"
    }
    # RESPUESTAS CORTAS JUGANDO (13/09): con un juego delante no hay tiempo para
    # escuchar un parrafo. Solo cambia COMO contesta, no lo que puede hacer.
    if ($base -and $script:juegoActivo) {
        $base += "`n`n## Ahora mismo`nbraya esta jugando a $($script:juegoActivo). Contesta en UNA sola frase corta, sin listas ni explicaciones, salvo que pida expresamente mas detalle.`n"
    }
    if (-not $base) { return $null }
    $ruta = Join-Path $TmpDir 'cerebro-sistema-actual.md'
    [System.IO.File]::WriteAllText($ruta, $base, (New-Object System.Text.UTF8Encoding($false)))
    return $ruta
}

# "¿Cuanto has aprendido?": lo que sabe, y lo que ha rendido esta semana. Cada
# cosa hecha sola con una receta cuenta como una peticion al cerebro ahorrada,
# unos 20 s de espera (medido el 13/09: 17-27 s).
function Get-BalanceAprendizaje {
    $cerebroT = ''
    try { $cerebroT = Get-BalanceCerebro } catch {}   # lo aprendido hablando (M1)
    $g = Get-Recetas
    $nRec = $g.Count
    $nVar = 0
    foreach ($r in $g) { $nVar += @(@($r.variantes) | Where-Object { $_ }).Count }
    $nDatos = @(Get-DatosPerfil).Count
    $sinIA = 0; $aprendidas = 0
    $st = Get-Estadisticas
    for ($i = 0; $i -lt 7; $i++) {
        $k = (Get-Date).AddDays(-$i).ToString('yyyy-MM-dd')
        if (-not $st.dias.ContainsKey($k)) { continue }
        if ($st.dias[$k].ContainsKey('receta')) { $sinIA += [int]$st.dias[$k]['receta'] }
        foreach ($c in 'receta-aprendida', 'receta-ensenada', 'receta-variante', 'receta-reparada', 'perfil') {
            if ($st.dias[$k].ContainsKey($c)) { $aprendidas += [int]$st.dias[$k][$c] }
        }
    }
    if ($nRec -eq 0 -and $nDatos -eq 0) {
        if ($cerebroT) { return $cerebroT }
        return 'todavia no he aprendido nada. Cuando la IA haga algo por ti lo ire aprendiendo, y tambien puedes ensenarme: aprende que cuando diga...'
    }
    $frases = @()
    if ($nRec -gt 0) {
        $t = 'se hacer ' + $(if ($nRec -eq 1) { 'una tarea' } else { "$nRec tareas" })
        if ($nVar -gt 0) { $t += ' y entiendo ' + ($nRec + $nVar) + ' formas de pedirlas' }
        $frases += $t
    }
    if ($nDatos -gt 0) { $frases += 'se ' + $(if ($nDatos -eq 1) { 'una cosa' } else { "$nDatos cosas" }) + ' de ti' }
    $txt = ($frases -join ', y ')
    if ($sinIA -gt 0) {
        $min = [int][Math]::Ceiling($sinIA * 20 / 60.0)
        $txt += '. Esta semana hice sola ' + $(if ($sinIA -eq 1) { 'una cosa' } else { "$sinIA cosas" }) + ' sin preguntarle a la IA: unos ' + $(if ($min -eq 1) { 'un minuto' } else { "$min minutos" }) + ' de espera que te ahorre'
    } elseif ($aprendidas -gt 0) {
        $txt += '. Esta semana aprendi ' + $(if ($aprendidas -eq 1) { 'una cosa nueva' } else { "$aprendidas cosas nuevas" })
    }
    if ($cerebroT) { $txt += '. Y ' + $cerebroT }
    return $txt
}

# JUEGOS: lo que Nova recuerda de cada uno. Donde te quedaste ("me quede en el
# jefe del castillo") y cuanto gasta de bateria, aprendido jugando.
# memoria\juegos.json, fuera de git.
$script:juegosMem = $null
$script:ultimoJuego = $null
$script:ultimoJuegoEn = 0
function Get-JuegosMem {
    if ($null -ne $script:juegosMem) { return $script:juegosMem }
    $script:juegosMem = @{}
    $rutaJ = Join-Path $MemoriaDir 'juegos.json'
    if (Test-Path -LiteralPath $rutaJ) {
        try {
            $crudoJ = Get-Content -LiteralPath $rutaJ -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $crudoJ.PSObject.Properties) {
                $h = @{}
                foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }
                $script:juegosMem[$p.Name] = $h
            }
        } catch { Log ("juegos: no pude leer la memoria: " + $_.Exception.Message) }
    }
    return $script:juegosMem
}
function Save-JuegosMem {
    try {
        $rutaJ = Join-Path $MemoriaDir 'juegos.json'
        $tmpJ = $rutaJ + '.tmp'
        [System.IO.File]::WriteAllText($tmpJ, ((Get-JuegosMem) | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmpJ -Destination $rutaJ -Force
    } catch { Log ("juegos: no pude guardar la memoria: " + $_.Exception.Message) }
}
# El juego del que se habla: el de delante, o el ultimo que cerraste (2 h)
function Get-JuegoDeReferencia {
    if ($script:juegoActivo) { return $script:juegoActivo }
    if ($script:ultimoJuego -and ($sw.ElapsedMilliseconds - $script:ultimoJuegoEn) -lt 7200000) { return $script:ultimoJuego }
    return $null
}
function Set-NotaJuego([string]$juego, [string]$nota) {
    $m = Get-JuegosMem
    if (-not $m.ContainsKey($juego)) { $m[$juego] = @{} }
    $m[$juego]['nota'] = $nota
    $m[$juego]['notaFecha'] = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    Save-JuegosMem
}
function Get-HaceCuanto([string]$fecha) {
    $d = [datetime]::MinValue
    if (-not [datetime]::TryParse($fecha, [ref]$d)) { return '' }
    $horas = ((Get-Date) - $d).TotalHours
    if ($horas -lt 3) { return 'hace un rato' }
    $dias = ((Get-Date).Date - $d.Date).Days
    if ($dias -eq 0) { return 'hoy' }
    if ($dias -eq 1) { return 'ayer' }
    return "hace $dias dias"
}

# BATERIA POR JUEGO: con un juego delante y sin cargador se abre un "tramo" con
# el % de ese momento. Se cierra al enchufar, al cambiar de juego o cada 20
# min, y si duro al menos 10 min y bajo algo, el ritmo (% por hora) se mezcla
# con lo ya aprendido de ese juego. Ninguna estimacion sale de un solo vistazo.
$script:tramoBat = $null
function Update-BateriaJuego([int]$pct, [int]$cargando) {
    $j = $script:juegoActivo
    $t = $script:tramoBat
    # sin juego delante (Alt+Tab un momento) el tramo sigue: solo lo cierran
    # enchufar, OTRO juego o los 20 min. Si no, no aprendia nunca (revision 13/09)
    if ($t -and ($cargando -eq 1 -or ($j -and $j -ne $t.juego) -or ($sw.ElapsedMilliseconds - $t.desde) -ge 1200000)) {
        $minT = ($sw.ElapsedMilliseconds - $t.desde) / 60000.0
        $baja = $t.pct - $pct
        if ($minT -ge 10 -and $baja -ge 2) {
            $ritmo = $baja / ($minT / 60.0)
            $m = Get-JuegosMem
            if (-not $m.ContainsKey($t.juego)) { $m[$t.juego] = @{} }
            $antes = [double]$m[$t.juego]['ritmoBateria']
            $nMu = [int]$m[$t.juego]['muestrasBateria']
            $nuevo = if ($nMu -gt 0 -and $antes -gt 0) { $antes * 0.6 + $ritmo * 0.4 } else { $ritmo }
            $m[$t.juego]['ritmoBateria'] = [Math]::Round($nuevo, 1)
            $m[$t.juego]['muestrasBateria'] = $nMu + 1
            Save-JuegosMem
            Log ("BATERIA: {0} gasta {1:N1} %/h en este tramo ({2:N0} min); media {3:N1} %/h" -f $t.juego, $ritmo, $minT, $nuevo)
            # IDEA 16: comparado con SU media, no con un numero inventado. $antes y $nMu
            # son todavia los de ANTES de este tramo. Hace falta historial (3 muestras) o
            # cualquier tramo pareceria raro.
            if ($nMu -ge 3 -and $antes -gt 0 -and $ritmo -gt ($antes * 1.6)) {
                [void](Send-AvisoEntorno 'bateria-rara' ("La bateria se esta yendo mas rapido de lo normal con " + $t.juego + ".") 'medio' 240)
            }
        }
        $script:tramoBat = $null
        $t = $null
    }
    if (-not $t -and $j -and $cargando -eq 0) { $script:tramoBat = @{ juego = $j; pct = $pct; desde = $sw.ElapsedMilliseconds } }
}
# Minutos que quedan con ese juego al % actual, o $null si aun no se sabe
function Get-DuracionBateriaJuego([string]$juego, [int]$pct = -1) {
    $m = Get-JuegosMem
    if (-not $juego -or -not $m.ContainsKey($juego)) { return $null }
    $ritmoJ = [double]$m[$juego]['ritmoBateria']
    if ($ritmoJ -le 0) { return $null }
    if ($pct -lt 0) { $pct = [int]$script:uiBateria }
    return [int]($pct / $ritmoJ * 60)
}
function Format-Minutos([int]$min) {
    if ($min -eq 1) { return 'un minuto' }
    if ($min -lt 60) { return "$min minutos" }
    $h = [int][Math]::Floor($min / 60); $r = $min % 60
    $th = if ($h -eq 1) { 'una hora' } else { "$h horas" }
    if ($r -lt 5) { return $th }
    return "$th y $r minutos"
}
# AL ENTRAR EN UN JUEGO: donde te quedaste y cuanto te dura, en la capsula,
# sin voz y sin tarjeta (el juego acaba de arrancar). Una vez por hora como
# mucho: salir y volver con Alt+Tab tambien cuenta como "entrar".
$script:juegoRecordado = @{}
function Show-RecuerdoJuego([string]$nombre) {
    if ($script:juegoRecordado.ContainsKey($nombre) -and ($sw.ElapsedMilliseconds - $script:juegoRecordado[$nombre]) -lt 3600000) { return }
    $m = Get-JuegosMem
    $partes = @()
    if ($m.ContainsKey($nombre) -and $m[$nombre]['nota']) { $partes += 'te quedaste en ' + $m[$nombre]['nota'] }
    if ($script:uiCargando -eq 0) {
        $minB = Get-DuracionBateriaJuego $nombre
        if ($minB) { $partes += 'bateria para ' + (Format-Minutos $minB) }
    }
    if ($partes.Count -eq 0) { return }
    $script:juegoRecordado[$nombre] = $sw.ElapsedMilliseconds
    $txtR = $partes -join ' · '
    if ($txtR.Length -gt 70) { $txtR = $txtR.Substring(0, 67) + '...' }
    $txtR = $txtR.Substring(0, 1).ToUpper() + $txtR.Substring(1)
    Log "JUEGOS: al entrar en $nombre -> $txtR"
    Set-UI 'hablando' $txtR 7000
}

# NOTIFICACIONES MIENTRAS JUEGAS: se miran las de Windows cada 30 s (las del
# centro de actividades, con el permiso que ya da el sistema). Jugando, una
# nueva solo hace latir el borde de la capsula: sin voz, sin texto, sin tarjeta.
# "¿Que me han escrito?" dice de quien; "leemelos" lo lee.
$script:notifVistas = @{}
$script:notifPendientes = New-Object System.Collections.ArrayList
$script:notifPrimera = $true
$script:notifFallos = 0
$NOTIF_IGNORAR = '(?i)^(?:Seguridad de Windows|Windows Security|Configuraci[oó]n|Settings|Windows|Explorador de archivos)$'
function Get-Notificaciones {
    if ($script:notifFallos -ge 3) { return @() }
    try {
        $null = [Windows.UI.Notifications.Management.UserNotificationListener, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.UI.Notifications.UserNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $lis = [Windows.UI.Notifications.Management.UserNotificationListener]::Current
        $acceso = [string]$lis.GetAccessStatus()
        if ($acceso -ne 'Allowed') {
            $script:notifFallos = 3
            Log "notificaciones: Windows no da permiso ($acceso); no se miran"
            return @()
        }
        $lista = Await-WinRT ($lis.GetNotificationsAsync([Windows.UI.Notifications.NotificationKinds]::Toast)) ([System.Collections.Generic.IReadOnlyList[Windows.UI.Notifications.UserNotification]])
        $res = @()
        foreach ($n in $lista) {
            $app = ''
            try { $app = [string]$n.AppInfo.DisplayInfo.DisplayName } catch {}
            if ($app -match $NOTIF_IGNORAR) { continue }
            $textos = @()
            try {
                $bind = $n.Notification.Visual.GetBinding([Windows.UI.Notifications.KnownNotificationBindings]::ToastGeneric)
                foreach ($te in $bind.GetTextElements()) { if ($te.Text) { $textos += [string]$te.Text } }
            } catch {}
            $res += @{ id = [string]$n.Id; app = $app; titulo = $(if ($textos.Count) { $textos[0] } else { '' }); texto = (@($textos | Select-Object -Skip 1) -join ' ') }
        }
        $script:notifFallos = 0
        return $res
    } catch {
        $script:notifFallos++
        Log ("notificaciones: " + $_.Exception.Message)
        return @()
    }
}
# CONTACTOS IMPORTANTES (13/09): "avisame solo si me escribe Ana". Con la lista
# vacia todo sigue como antes; con alguien dentro, solo sus mensajes avisan (un
# pulso y "Ana te ha escrito" jugando; un aviso fuera) y los demas esperan en
# silencio. memoria\contactos.json, fuera de git.
$script:contactos = $null
$script:ultimaNotif = $null
function Get-Contactos {
    if ($null -ne $script:contactos) { return ,$script:contactos }
    $script:contactos = New-Object System.Collections.ArrayList
    $rutaC = Join-Path $MemoriaDir 'contactos.json'
    if (Test-Path -LiteralPath $rutaC) {
        try { foreach ($nC in @(Get-Content -LiteralPath $rutaC -Raw -Encoding UTF8 | ConvertFrom-Json)) { if ($nC) { [void]$script:contactos.Add([string]$nC) } } }
        catch { Save-Corrupto $rutaC 'contactos' }
    }
    return ,$script:contactos
}
function Save-Contactos {
    try { Write-Atomico (Join-Path $MemoriaDir 'contactos.json') (ConvertTo-Json -InputObject @($script:contactos)) } catch {}
}
function Watch-Notificaciones([object[]]$todas) {
    # una lectura fallida no cuenta: ni gasta la primera vuelta ni vacia lo visto
    # (si no, al volver a funcionar todo lo viejo parecia nuevo; revision 13/09)
    if ($script:notifFallos -gt 0) { return 0 }
    $nuevas = @($todas | Where-Object { -not $script:notifVistas.ContainsKey($_.id) })
    # lo visto se poda a lo que sigue en el centro de actividades
    $script:notifVistas = @{}
    foreach ($n in $todas) { $script:notifVistas[$n.id] = $true }
    # al arrancar, lo que ya estaba en el centro de actividades no es nuevo
    if ($script:notifPrimera) { $script:notifPrimera = $false; return 0 }
    if ($nuevas.Count -eq 0) { return 0 }
    foreach ($n in $nuevas) { [void]$script:notifPendientes.Add($n) }
    $script:ultimaNotif = $nuevas[$nuevas.Count - 1]   # a quien contestar (ver CONTESTAR UN MENSAJE)
    while ($script:notifPendientes.Count -gt 30) { $script:notifPendientes.RemoveAt(0) }
    Log ("NOTIFICACIONES: {0} nueva(s) de {1}" -f $nuevas.Count, ((@($nuevas | ForEach-Object { $_.app }) | Select-Object -Unique) -join ', '))
    $importantes = @(Get-Contactos)
    if ($importantes.Count -gt 0) {
        $deImp = @($nuevas | Where-Object {
            $tituloI = ConvertTo-Plain ([string]$_.titulo)
            @($importantes | Where-Object { $tituloI -match ('\b' + [regex]::Escape((ConvertTo-Plain $_)) + '\b') }).Count -gt 0
        })
        if ($deImp.Count -gt 0) {
            $quienI = [string]$deImp[0].titulo
            if ($script:juegoActivo -or (Test-AvisoSinVoz)) {
                Send-UIEvento 'pulso:mensaje'
                if (-not $script:busy -and -not $script:pendiente) { Set-UI 'hablando' "$quienI te ha escrito" 4000 }
            } else {
                Send-Aviso "$quienI te ha escrito" 'mensaje'
            }
        }
    } elseif ($script:juegoActivo) { Send-UIEvento 'pulso:mensaje' }
    return $nuevas.Count
}
function Get-ResumenNotificaciones {
    $pend = @($script:notifPendientes)
    if ($pend.Count -eq 0) { return 'nada nuevo; nadie te ha escrito' }
    $grupos = @($pend | Group-Object { $_.app } | Sort-Object Count -Descending | ForEach-Object { "$($_.Count) de $($_.Name)" })
    $lista = if ($grupos.Count -gt 1) { ($grupos[0..($grupos.Count - 2)] -join ', ') + ' y ' + $grupos[-1] } else { $grupos[0] }
    $total = if ($pend.Count -eq 1) { 'tienes una' } else { "tienes $($pend.Count)" }
    return "$total`: $lista. Di leemelos si quieres oirlos"
}
function Get-LecturaNotificaciones([int]$max = 5) {
    $pend = @($script:notifPendientes | Select-Object -Last $max)
    if ($pend.Count -eq 0) { return 'no tengo mensajes nuevos que leerte' }
    $partes = foreach ($n in $pend) {
        $quien = if ($n.titulo) { "$($n.app), $($n.titulo)" } else { $n.app }
        if ($n.texto) { "$quien`: $($n.texto)" } else { $quien }
    }
    $script:notifPendientes.Clear()
    return ($partes -join '. ')
}

# LA MUSICA EN LA CAPSULA: lo que suena en Windows (Spotify, el navegador...),
# mirado cada 5 s. Mientras suena, la carita se mece (lo dibuja la capsula con
# el campo "musica"); al empezar una cancion, el titulo un momento, y solo si
# no estas jugando ni haciendo nada. "¿Que cancion es?" lo dice.
$script:mediaMgr = $null
$script:mediaFallos = 0
$script:uiMusica = 0
$script:musicaTitulo = ''
$script:musicaArtista = ''
$script:musicaCheck = 0
function Get-MusicaActual {
    if ($script:mediaFallos -ge 3) { return $null }
    try {
        if (-not $script:mediaMgr) {
            $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
            $script:mediaMgr = Await-WinRT ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
        }
        $ses = $script:mediaMgr.GetCurrentSession()
        if (-not $ses) { $script:mediaFallos = 0; return $null }
        $estadoM = [string]$ses.GetPlaybackInfo().PlaybackStatus
        $script:mediaFallos = 0
        # en pausa no cambia la cancion: no se pregunta (y la pregunta puede tardar
        # si la app no contesta: tope de 1,5 s, no 8; revision del 13/09)
        if ($estadoM -ne 'Playing' -and $script:musicaTitulo) {
            return @{ sonando = $false; titulo = $script:musicaTitulo; artista = $script:musicaArtista; app = [string]$ses.SourceAppUserModelId }
        }
        $props = Await-WinRT ($ses.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]) 1500
        $script:musicaArtista = [string]$props.Artist
        return @{ sonando = ($estadoM -eq 'Playing'); titulo = [string]$props.Title; artista = [string]$props.Artist; app = [string]$ses.SourceAppUserModelId }
    } catch {
        $script:mediaFallos++
        Log ("musica: " + $_.Exception.Message)
        return $null
    }
}
function Watch-Musica($mu) {
    $sonando = [bool]($mu -and $mu.sonando)
    $flag = if ($sonando) { 1 } else { 0 }
    $repintar = $false
    if ($flag -ne $script:uiMusica) { $script:uiMusica = $flag; $repintar = $true }
    if ($sonando -and $mu.titulo -and $mu.titulo -ne $script:musicaTitulo) {
        $script:musicaTitulo = $mu.titulo
        Log "MUSICA: $($mu.titulo) - $($mu.artista)"
        try { Add-HistorialMusica $mu.titulo $mu.artista } catch {}   # ver HISTORIAL DE MUSICA
        if (-not $script:juegoActivo -and $script:uiEstado -eq 'reposo' -and -not $script:busy -and -not $script:pendiente) {
            $tM = [string][char]0x266A + ' ' + $mu.titulo + $(if ($mu.artista) { ' · ' + $mu.artista } else { '' })
            if ($tM.Length -gt 48) { $tM = $tM.Substring(0, 45) + '...' }
            Set-UI 'hablando' $tM 3500
            $repintar = $false
        }
    }
    if ($repintar) { Refresh-UI }
}

# HABITOS: que ordenes das y a que hora, para PROPONERTE automatizarlas (nunca
# se crea nada sin un si). Dos costumbres: la misma orden a la misma hora
# (+-30 min) tres dias distintos de la ultima semana, o la misma orden justo
# despues de abrir una app (3 min) tres dias distintos. Una propuesta al dia
# como mucho, y un "no" es para siempre. memoria\habitos.json, fuera de git.
$script:habitos = $null
function Get-Habitos {
    if ($null -ne $script:habitos) { return $script:habitos }
    $script:habitos = @{ usos = (New-Object System.Collections.ArrayList); rechazadas = (New-Object System.Collections.ArrayList); ultimaPropuesta = ''; fin = @{}; cargaAvisada = ''; nivelVisto = 0; brilloAuto = $false; parteVisto = ''; ritmo = (New-Object System.Collections.ArrayList); charlaHoras = @{}; minutosJuego = @{} }
    $rutaH = Join-Path $MemoriaDir 'habitos.json'
    if (Test-Path -LiteralPath $rutaH) {
        try {
            $crudoH = Get-Content -LiteralPath $rutaH -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($u in @($crudoH.usos)) { if ($u -and $u.t) { [void]$script:habitos.usos.Add(@{ t = [string]$u.t; f = [string]$u.f; h = [string]$u.h }) } }
            foreach ($r in @($crudoH.rechazadas)) { if ($r) { [void]$script:habitos.rechazadas.Add([string]$r) } }
            $script:habitos.ultimaPropuesta = [string]$crudoH.ultimaPropuesta
            if ($crudoH.fin) { foreach ($pf in $crudoH.fin.PSObject.Properties) { $script:habitos.fin[$pf.Name] = [string]$pf.Value } }
            $script:habitos.cargaAvisada = [string]$crudoH.cargaAvisada
            $script:habitos.nivelVisto = [int]$crudoH.nivelVisto
            $script:habitos.brilloAuto = [bool]$crudoH.brilloAuto
            $script:habitos.parteVisto = [string]$crudoH.parteVisto
            if ($crudoH.minutosJuego) { foreach ($pM in $crudoH.minutosJuego.PSObject.Properties) { $script:habitos.minutosJuego[$pM.Name] = [int]$pM.Value } }
            foreach ($x in @($crudoH.ritmo)) { if ($null -ne $x) { [void]$script:habitos.ritmo.Add([double]$x) } }
            if ($crudoH.charlaHoras) { foreach ($pf in $crudoH.charlaHoras.PSObject.Properties) { $script:habitos.charlaHoras[$pf.Name] = [int]$pf.Value } }
        } catch { Log ("habitos: no pude leerlos: " + $_.Exception.Message) }
    }
    return $script:habitos
}
function Save-Habitos {
    try {
        $hb = Get-Habitos
        $o = [ordered]@{ usos = @($hb.usos); rechazadas = @($hb.rechazadas); ultimaPropuesta = $hb.ultimaPropuesta; fin = $hb.fin; cargaAvisada = $hb.cargaAvisada; nivelVisto = $hb.nivelVisto; brilloAuto = [bool]$hb.brilloAuto; parteVisto = [string]$hb.parteVisto; ritmo = @($hb.ritmo); charlaHoras = $hb.charlaHoras; minutosJuego = $hb.minutosJuego }
        $rutaH = Join-Path $MemoriaDir 'habitos.json'
        [System.IO.File]::WriteAllText($rutaH + '.tmp', (ConvertTo-Json -InputObject $o -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath ($rutaH + '.tmp') -Destination $rutaH -Force
    } catch { Log ("habitos: no pude guardarlos: " + $_.Exception.Message) }
}
function Add-Habito([string]$texto, [datetime]$cuando = (Get-Date)) {
    if ($script:invitado) { return }   # lo que pide un invitado no es tu costumbre
    $p = ConvertTo-Plain $texto
    # solo ordenes que HACEN algo; preguntar la hora no es una costumbre que automatizar
    # SIN "cierra" (revision del 13/09): "cierra todos los programas" confirmado
    # tres noches acababa en una regla diaria que se ejecuta sin preguntar
    if (-not $p -or $p.Length -gt 60 -or $p -notmatch '^(?:abre|pon|ponme|modo|activa|desactiva|sube|baja|silencia|lanza|inicia|arranca)\b') { return }
    if ($p -match '\b(?:todo|todos|todas|apaga|reinicia|bloquea|borra|elimina)\b') { return }
    $hb = Get-Habitos
    [void]$hb.usos.Add(@{ t = $p; f = $cuando.ToString('yyyy-MM-dd'); h = $cuando.ToString('HH:mm') })
    while ($hb.usos.Count -gt 400) { $hb.usos.RemoveAt(0) }
    Save-Habitos
}
# PARTE DE LA MANANA (13/09): con la primera orden del dia (de 5 a 12), despues
# de contestarla, UNA linea en la capsula y sin voz: el tiempo, la bateria y lo
# que tienes hoy. Va por el mismo camino que el resumen al volver. Si solo hay
# la bateria, no es un parte: calla.
function Test-ParteManana([datetime]$ahora = (Get-Date)) {
    if ($script:invitado -or $ahora.Hour -lt 5 -or $ahora.Hour -ge 12) { return }
    $hbM = Get-Habitos
    $hoyM = $ahora.ToString('yyyy-MM-dd')
    if ($hbM.parteVisto -eq $hoyM) { return }
    $hbM.parteVisto = $hoyM
    Save-Habitos
    $partes = @()
    if ($script:clima) { $partes += "$($script:clima.emoji) $($script:clima.temp)°" }
    try {
        $bM = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bM -and $bM.EstimatedChargeRemaining) { $partes += "bateria $([int]$bM.EstimatedChargeRemaining) %" }
    } catch {}
    $recHoy = @(Get-Recordatorios | Where-Object { $c = $null; try { $c = [DateTime]$_.cuando } catch {}; $c -and $c.Date -eq $ahora.Date })
    if ($recHoy.Count -eq 1) { $partes += "hoy: $($recHoy[0].texto)" }
    elseif ($recHoy.Count -gt 1) { $partes += "$($recHoy.Count) recordatorios hoy" }
    if ($partes.Count -lt 2) { return }
    $lineaM = 'Buenos dias · ' + ($partes -join ' · ')
    Log "PARTE DE LA MANANA: $lineaM"
    $script:resumenPendiente = if ($script:resumenPendiente) { "$($script:resumenPendiente) · $lineaM" } else { $lineaM }
}
# MODO INVITADO (13/09): "pon el modo invitado" antes de dejarle la consola a
# alguien. Mientras dura, Nova no aprende (costumbres, recetas, perfil, tu voz,
# estadisticas), no mira tus notas ni lee tus mensajes y la charla no hereda lo
# que hablaste tu. Se quita diciendolo o solo, tras 30 min sin ordenes.
$script:invitado = $false
$script:invitadoUltimo = 0
function Test-FinInvitado {
    if (-not $script:invitado) { return }
    if (($sw.ElapsedMilliseconds - $script:invitadoUltimo) -lt 1800000) { return }
    $script:invitado = $false
    Log "MODO INVITADO: fuera (30 min sin ordenes)"
}
# =====================================================================
# QUINTA TANDA, FUNCIONES (13/09)
# =====================================================================
$script:despertadorHora = 0          # hasta cuando lo proximo que digas es la hora del despertador
$script:despertadorSonoEn = -9999999
$script:rutinaDormirTrasNota = $false
$script:limiteJuego = $null
$script:vozAjenaVeces = @()
$script:vozAjenaF0Vista = 0.0
$script:invitadoPropuesta = $false
$script:invitadoPropuestoEn = -9999999

# "dos horas", "media hora", "una hora y media", "45 minutos" -> minutos
function Get-MinutosDichos([string]$cant, [string]$unidad) {
    $n = switch -regex ($cant) {
        '^\d+$' { [double]$cant; break }
        '^(?:una|un)$' { 1; break }
        '^media$' { 0.5; break }
        '^dos$' { 2; break }
        '^tres$' { 3; break }
        '^cuatro$' { 4; break }
        '^cinco$' { 5; break }
        default { 0 }
    }
    if ($unidad -match 'hora y media') { return [int](($n + 0.5) * 60) }
    if ($unidad -match '^hora') { return [int]($n * 60) }
    return [int]$n
}
function Format-MinutosDichos([int]$min) {
    if ($min -eq 30) { return 'media hora' }
    if ($min -eq 90) { return 'una hora y media' }
    if ($min -ge 60 -and $min % 60 -eq 0) { $h = $min / 60; if ($h -eq 1) { return 'una hora' } else { return "$h horas" } }
    return "$min minutos"
}

# CLIP DEL JUEGO (F1): Win+Alt+G guarda los ultimos segundos... solo si la
# grabacion en segundo plano de la Game Bar esta activada. Si no, no hace nada, y
# hay que decirlo en vez de fingir que se guardo.
function Invoke-ClipJuego {
    $gdvr = $null
    try { $gdvr = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -ErrorAction Stop } catch {}
    if (-not $gdvr -or [int]$gdvr.HistoricalCaptureEnabled -ne 1) {
        return 'para guardar clips activa en la Game Bar la grabacion de lo que ha pasado: Win mas G, Captura'
    }
    try { Send-Combinacion 'win+alt+g' } catch { return 'no pude pedirle el clip a la Game Bar' }
    Log "CLIP: pedido a la Game Bar"
    return 'clip guardado'
}

# DESCARGAS DE STEAM (F5): cuanto le queda a un juego concreto
function Get-DescargaJuego([string]$nombre) {
    $j = Find-Juego $nombre
    if (-not $j) { return $null }
    $jj = @($script:Juegos | Where-Object { $_.nombre -eq $j.nombre }) | Select-Object -First 1
    if (-not $jj) { return $null }
    if (-not $jj.bajando) { return "$($jj.nombre) no se esta descargando" }
    # 1.0 y no 1: con un 1 entero PowerShell elige Max(int, int) y un juego de mas
    # de 2 GB revienta la cuenta
    $pct = [int](100.0 * [double]$jj.descargado / [Math]::Max(1.0, [double]$jj.total))
    return "$($jj.nombre) va por el $pct por ciento; faltan $(Format-Gigas ([double]$jj.total - [double]$jj.descargado))"
}

# LIMITE DE JUEGO PROPIO (F6): "avisame cuando lleve 2 horas". Un aviso al
# llegar y otro mas firme 15 min despues. Vale para la partida de ahora (o la
# siguiente, si no hay juego) y se quita al cerrar ese juego.
function Test-LimiteJuego {
    $l = $script:limiteJuego
    if (-not $l) { return }
    if (-not $script:juegoActivo) {
        if ($l.visto) { $script:limiteJuego = $null; Log "LIMITE DE JUEGO: fuera (juego cerrado)" }
        return
    }
    $l.visto = $true
    $min = ($sw.ElapsedMilliseconds - $script:juegoDesde) / 60000
    if ($l.avisos -eq 0 -and $min -ge $l.min) {
        $l.avisos = 1
        Log "LIMITE DE JUEGO: $($l.min) min con $($script:juegoActivo)"
        Send-Aviso ("Ya llevas " + (Format-MinutosDichos $l.min) + " con $($script:juegoActivo), como me pediste.") 'tiempo'
    } elseif ($l.avisos -eq 1 -and $min -ge ($l.min + 15)) {
        $l.avisos = 2
        Send-UIEvento 'pulso:tiempo'
        Send-Aviso 'Van quince minutos mas. ¿Lo dejamos por hoy?' 'tiempo'
    }
}

# DESPERTADOR (F4): "despiertame a las 7", "pon el despertador para manana a las
# 7 y media". Es un recordatorio con el texto 'despertador'; al sonar, musica, la
# hora, el tiempo y lo de hoy. "Cinco minutos mas" lo pospone.
function Invoke-DespertadorVoz([string]$text) {
    $p = ConvertTo-Plain $text
    if ($p -match '^(?:quita|cancela|borra|apaga)\s+(?:el\s+)?despertador$') {
        $antesD = @(Get-Recordatorios)
        $quedanD = @($antesD | Where-Object { $_.texto -ne 'despertador' })
        if ($quedanD.Count -eq $antesD.Count) { return 'No tenias despertador.' }
        Save-Recordatorios $quedanD
        return 'Despertador quitado.'
    }
    if ($p -match '^(?:cinco|5|diez|10)\s+minutos\s+mas$' -and ($sw.ElapsedMilliseconds - $script:despertadorSonoEn) -lt 900000) {
        $masD = if ($p -match 'diez|10') { 10 } else { 5 }
        Save-Recordatorios (@(Get-Recordatorios) + @(New-Object PSObject -Property @{ cuando = (Get-Date).AddMinutes($masD).ToString('s'); texto = 'despertador' }))
        return "Vale, $masD minutos mas."
    }
    if ($p -notmatch '^(?:despiertame|ponme\s+el\s+despertador|pon\s+el\s+despertador|ponme\s+una\s+alarma|pon\s+una\s+alarma)\s+(?:para\s+)?(.+)$') { return $null }
    $cuandoD = $Matches[1]
    if ($cuandoD -match '^(?:en|dentro\s+de)\s') { return $null }   # "despiertame en 20 minutos": eso es un temporizador
    $rD = Invoke-RecordatorioVoz "recuerdame $cuandoD despertador"
    if (-not $rD) { return $null }
    if ($rD -match '^Listo, te lo recuerdo (.+)$') { return "Listo, te despierto $($Matches[1])" }
    return $rD
}
function Invoke-Despertador {
    $script:despertadorSonoEn = $sw.ElapsedMilliseconds
    Log "DESPERTADOR: suena"
    Send-UIEvento 'despierta'
    $muD = $null
    try { $muD = Get-MusicaActual } catch {}
    if (-not ($muD -and $muD.sonando)) {
        try { [AX]::keybd_event([byte]0xB3, 0, 0, [UIntPtr]::Zero); [AX]::keybd_event([byte]0xB3, 0, 2, [UIntPtr]::Zero) } catch {}
    }
    $culD = New-Object System.Globalization.CultureInfo('es-MX')
    $partesD = @('Buenos dias. Son las ' + (Get-Date).ToString('H:mm', $culD))
    if ($script:clima) { $partesD += "$($script:clima.desc), $($script:clima.temp) grados" }
    $hoyD = @(Get-Recordatorios | Where-Object { $c = $null; try { $c = [DateTime]$_.cuando } catch {}; $c -and $c.Date -eq (Get-Date).Date -and $_.texto -ne 'despertador' })
    if ($hoyD.Count -eq 1) { $partesD += "hoy tienes: $($hoyD[0].texto)" } elseif ($hoyD.Count -gt 1) { $partesD += "hoy tienes $($hoyD.Count) recordatorios" }
    Say (($partesD -join '. ') + '. Si quieres, di cinco minutos mas.')
    $script:seguimientoPendiente = $true
}

# RUTINA DE DORMIR (F3): "me voy a dormir". Brillo y volumen bajos y, si no hay
# despertador, lo pregunta. Con un juego delante, "me voy a dormir" apunta antes
# donde te quedaste y la rutina sigue al contestar (ver Report-Reply).
function Invoke-RutinaDormir {
    $hechasR = @()
    try { if (Invoke-FastCommand 'pon el brillo al 20') { $hechasR += 'brillo bajo' } } catch {}
    try { if (Invoke-FastCommand 'pon el volumen al 20') { $hechasR += 'volumen bajo' } } catch {}
    $txtR = 'A descansar' + $(if ($hechasR.Count) { ': ' + ($hechasR -join ' y ') } else { '' }) + '.'
    if (@(Get-Recordatorios | Where-Object { $_.texto -eq 'despertador' }).Count -gt 0) { return "$txtR Tu despertador ya esta puesto. Buenas noches." }
    $script:pendiente = @{ texto = ''; vence = 0; tipo = 'despertador' }
    return "$txtR ¿Te pongo el despertador?"
}

# AMIGOS CONECTADOS (F9): Steam, con su API web (hace falta una clave gratuita de
# steamcommunity.com/dev/apikey en config: steam, apiKey). Discord no deja verlo
# sin un bot: no se puede.
function Get-AmigosSteam {
    $claveS = [string](Get-Cfg 'steam' 'apiKey' '')
    if (-not $claveS) { return 'para ver quien esta conectado en Steam necesito una clave de su API: pidela en steamcommunity.com barra dev barra apikey y ponla en la configuracion, en steam, apiKey' }
    $cuentaS = [int64]0
    try { $cuentaS = [int64](Get-ItemProperty 'HKCU:\Software\Valve\Steam\ActiveProcess' -ErrorAction Stop).ActiveUser } catch {}
    if ($cuentaS -le 0) { return 'Steam no tiene la sesion iniciada' }
    $yoS = [string]([int64]76561197960265728 + $cuentaS)
    try {
        $fl = Invoke-RestMethod "https://api.steampowered.com/ISteamUser/GetFriendList/v1/?key=$claveS&steamid=$yoS&relationship=friend" -TimeoutSec 6
        $idsS = @($fl.friendslist.friends | ForEach-Object { $_.steamid } | Select-Object -First 100)
        if ($idsS.Count -eq 0) { return 'no veo a ningun amigo en tu lista de Steam' }
        $psS = Invoke-RestMethod ("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=$claveS&steamids=" + ($idsS -join ',')) -TimeoutSec 6
        $onS = @($psS.response.players | Where-Object { [int]$_.personastate -gt 0 })
        if ($onS.Count -eq 0) { return 'ahora mismo no hay nadie conectado en Steam' }
        $jugandoS = @($onS | Where-Object { $_.gameextrainfo } | ForEach-Object { "$($_.personaname) jugando a $($_.gameextrainfo)" })
        $soloS = @($onS | Where-Object { -not $_.gameextrainfo } | ForEach-Object { $_.personaname })
        $partesS = @()
        if ($jugandoS.Count) { $partesS += ($jugandoS -join ', ') }
        if ($soloS.Count) { $partesS += ('conectados: ' + ($soloS -join ', ')) }
        return "en Steam hay $($onS.Count): " + ($partesS -join '; ')
    } catch {
        Log ("steam amigos: " + ($_.Exception.Message -replace 'key=[^&\s]+', 'key=***'))
        return 'no pude preguntarle a Steam'
    }
}

# HISTORIAL DE MUSICA (F10): lo que ha sonado, con fecha (memoria\musica.json,
# fuera del repositorio; las 300 ultimas). "¿Como se llamaba esa cancion?" y
# "pon la que sonaba ayer por la noche" (la busca en Spotify).
$script:musicaHist = $null
function Get-HistorialMusica {
    if ($null -ne $script:musicaHist) { return ,$script:musicaHist }
    $script:musicaHist = New-Object System.Collections.ArrayList
    $rutaM = Join-Path $MemoriaDir 'musica.json'
    if (Test-Path -LiteralPath $rutaM) {
        try {
            foreach ($x in (Get-Content -LiteralPath $rutaM -Raw -Encoding UTF8 | ConvertFrom-Json)) {
                if ($x -and $x.t) { [void]$script:musicaHist.Add(@{ t = [string]$x.t; a = [string]$x.a; f = [string]$x.f }) }
            }
        } catch { try { Save-Corrupto $rutaM } catch {} }
    }
    return ,$script:musicaHist
}
function Add-HistorialMusica([string]$titulo, [string]$artista, [datetime]$cuando = (Get-Date)) {
    if (-not $titulo -or $script:invitado) { return }
    $h = Get-HistorialMusica
    if ($h.Count -gt 0 -and $h[$h.Count - 1].t -eq $titulo) { return }
    [void]$h.Add(@{ t = $titulo; a = $artista; f = $cuando.ToString('s') })
    while ($h.Count -gt 300) { $h.RemoveAt(0) }
    try {
        $rutaM = Join-Path $MemoriaDir 'musica.json'
        [System.IO.File]::WriteAllText("$rutaM.tmp", (ConvertTo-Json @($h) -Depth 3), (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath "$rutaM.tmp" -Destination $rutaM -Force
    } catch {}
}
function Find-CancionDe([string]$cuando, [datetime]$ahora = (Get-Date)) {
    # OJO: sin @(...). Get-HistorialMusica devuelve la lista envuelta (",lista");
    # con @() quedaba UNA lista dentro de otra y cada "cancion" era la lista entera
    $h = Get-HistorialMusica
    if ($h.Count -eq 0) { return $null }
    $hoy = $ahora.Date
    $desde = $null; $hasta = $null
    switch ($cuando) {
        { $_ -in 'antes', 'hace un rato' } { $desde = $ahora.AddHours(-3); $hasta = $ahora }
        'esta manana' { $desde = $hoy.AddHours(5); $hasta = $hoy.AddHours(13) }
        { $_ -in 'anoche', 'ayer por la noche' } { $desde = $hoy.AddDays(-1).AddHours(19); $hasta = $hoy.AddHours(5) }
        'ayer por la manana' { $desde = $hoy.AddDays(-1).AddHours(5); $hasta = $hoy.AddDays(-1).AddHours(13) }
        'ayer por la tarde' { $desde = $hoy.AddDays(-1).AddHours(13); $hasta = $hoy.AddDays(-1).AddHours(20) }
        'ayer' { $desde = $hoy.AddDays(-1); $hasta = $hoy }
    }
    if (-not $desde) { return $null }
    $en = @($h | Where-Object { $d = [datetime]$_.f; $d -ge $desde -and $d -lt $hasta })
    if ($en.Count -eq 0) { return $null }
    # la que mas sono en ese rato; a igualdad, la ultima que sono
    $mejorC = @($en | Group-Object { $_.t } | Sort-Object @{ e = { $_.Count }; d = $true }, @{ e = { [datetime](@($_.Group)[-1].f) }; d = $true })[0]
    return @($mejorC.Group)[-1]
}
function Get-CancionAnterior {
    $h = Get-HistorialMusica   # sin @(): ver Find-CancionDe
    if ($h.Count -eq 0) { return $null }
    $ultima = $h[$h.Count - 1]
    # si la ultima es la que suena ahora, "esa cancion" es la de antes
    if ($h.Count -ge 2 -and $script:uiMusica -eq 1 -and $ultima.t -eq $script:musicaTitulo) { return $h[$h.Count - 2] }
    return $ultima
}

# =====================================================================
# NOVA SE ENTERA DE LO QUE PASA (16/09). El motor de los avisos por su cuenta.
#
# Hasta ahora Nova solo hablaba cuando le hablabas. Esto le deja avisar de cosas que
# pasan (dock, cascos, bateria, descargas, correo...), pero con freno de mano, porque
# un asistente que habla solo se vuelve insoportable rapido:
#   - como mucho $EntornoPorHora avisos por hora;
#   - jugando, solo lo critico (nivel 'alto');
#   - de $EntornoNocheDesde a $EntornoNocheHasta, solo lo critico;
#   - el mismo aviso no se repite hasta que pasa su plazo;
#   - los de nivel 'bajo' NO se dicen en voz alta: solo se ven en la capsula;
#   - "no me avises de nada" lo apaga entero hasta que digas lo contrario.
# =====================================================================
$EntornoOn = [bool](Get-Cfg 'entorno' 'avisos' $false)
$EntornoPorHora = [int](Get-Cfg 'entorno' 'porHora' 4)
$EntornoGmailLleno = [bool](Get-Cfg 'entorno' 'gmailLleno' $false)
$EntornoNocheDesde = [int](Get-Cfg 'entorno' 'nocheDesde' 23)
$EntornoNocheHasta = [int](Get-Cfg 'entorno' 'nocheHasta' 8)
$script:entornoAvisos = New-Object System.Collections.ArrayList   # cuando salio cada uno
# clave -> cuando salio, en HORA DE RELOJ (no en ms del cronometro, que se reinicia con
# Nova). Se guarda en disco: si no, cada reinicio vuelve a avisar de todo.
$script:entornoVistos = @{}
$EntornoVistosPath = Join-Path $TmpDir 'avisos-vistos.json'
function Get-EntornoVistos {
    if ($script:entornoVistos.Count -gt 0) { return $script:entornoVistos }
    try {
        if (Test-Path -LiteralPath $EntornoVistosPath) {
            $j = Get-Content -LiteralPath $EntornoVistosPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $script:entornoVistos[$p.Name] = [string]$p.Value }
        }
    } catch {}
    return $script:entornoVistos
}
function Save-EntornoVistos {
    try {
        $o = [ordered]@{}
        foreach ($k in ($script:entornoVistos.Keys | Sort-Object)) { $o[$k] = [string]$script:entornoVistos[$k] }
        Write-Atomico $EntornoVistosPath (ConvertTo-Json -InputObject $o -Depth 3)
    } catch {}
}
$script:entornoCallado = $false                                    # "no me avises de nada"

# ¿se puede avisar de esto AHORA? nivel: 'bajo' (solo capsula), 'medio', 'alto' (critico)
function Test-PuedoAvisar([string]$clave, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    if (-not $EntornoOn -or $script:entornoCallado -or $script:invitado) { return $false }
    $ahoraE = $sw.ElapsedMilliseconds
    # el mismo aviso, una vez cada cuanto. Por HORA DE RELOJ y leido de disco: si no,
    # cada reinicio de Nova rearmaba todos los avisos (16/09: el del Gmail lleno, con
    # plazo de una semana, salio dos veces en once minutos).
    $vistos = Get-EntornoVistos
    if ($vistos.ContainsKey($clave)) {
        $cuando = [datetime]::MinValue
        if ([datetime]::TryParse([string]$vistos[$clave], [ref]$cuando)) {
            if (((Get-Date) - $cuando).TotalMinutes -lt $cadaMin) { return $false }
        }
    }
    if ($nivel -ne 'alto') {
        # JUGANDO, SILENCIO: es cuando mas molesta y cuando menos caso se hace
        if ($script:juegoActivo) { return $false }
        $hE = (Get-Date).Hour
        $esNocheE = if ($EntornoNocheDesde -gt $EntornoNocheHasta) { ($hE -ge $EntornoNocheDesde -or $hE -lt $EntornoNocheHasta) }
                    else { ($hE -ge $EntornoNocheDesde -and $hE -lt $EntornoNocheHasta) }
        # 'noche' es el aviso que SOLO tiene sentido de noche (la hora de dormir):
        # se salta el silencio nocturno y nada mas. Jugando sigue callado, y cuenta
        # para el tope por hora como cualquier otro.
        if ($esNocheE -and $nivel -ne 'noche') { return $false }
        # y nunca mientras esta hablando, dictando o esperando un si
        if ($script:busy -or $script:pendiente -or $script:dictandoLargo) { return $false }
    }
    # PRESUPUESTO POR HORA: se cuentan los de la ultima hora y se para ahi
    $hace1h = $ahoraE - 3600000
    while ($script:entornoAvisos.Count -gt 0 -and [double]$script:entornoAvisos[0] -lt $hace1h) { $script:entornoAvisos.RemoveAt(0) }
    if ($script:entornoAvisos.Count -ge $EntornoPorHora -and $nivel -ne 'alto') { return $false }
    return $true
}

# IDEA 23: DOS AVISOS SEGUIDOS SE DICEN EN UNA SOLA FRASE. Pasa de verdad: sacas el
# portatil del dock y en el mismo momento cambia la pantalla, se va el cargador y salta
# la bateria. Tres frases seguidas cansan mas que los tres datos juntos.
#
# Se junta SOLO LA VOZ: el aviso se apunta, se ve y se registra al momento, pero se dice
# unos segundos despues, pegado a los que hayan caido mientras. Lo critico ('alto') no
# espera a nadie y ademas se cuela el primero.
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$AvisoJuntarMs = 4000

# Suelta lo que haya esperando, todo junto. $yaMismo se salta la espera (lo critico).
function Send-AvisoCola([bool]$yaMismo = $false) {
    if ($script:avisoCola.Count -eq 0) { return }
    if (-not $yaMismo) {
        if (($sw.ElapsedMilliseconds - $script:avisoColaDesde) -lt $AvisoJuntarMs) { return }
        # si esta hablando o esperando un si, que siga esperando: no se pisa una charla
        if ($script:busy -or $script:pendiente) { return }
    }
    $piezas = @($script:avisoCola | ForEach-Object { ([string]$_).Trim().TrimEnd('.') })
    $script:avisoCola.Clear()
    $junto = ($piezas -join '. ')
    if ($junto -notmatch '[?!]$') { $junto += '.' }
    Say $junto
}

# Avisa de algo. Devuelve $true si el aviso pasa el filtro (los normales se dicen unos
# segundos despues, ver la idea 23 aqui arriba).
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    if (-not (Test-PuedoAvisar $clave $nivel $cadaMin)) { return $false }
    $script:entornoVistos[$clave] = (Get-Date).ToString('s')
    Save-EntornoVistos
    [void]$script:entornoAvisos.Add($sw.ElapsedMilliseconds)
    Log "ENTORNO ($clave, $nivel): $texto"
    Add-Estadistica 'aviso-entorno' $clave
    $script:ultimaRespuesta = $texto
    Show-Popup $texto
    # los de poca monta NO se dicen: se ven y ya. Hablar por todo es lo que cansa.
    if ($nivel -eq 'alto') {
        # lo critico va delante de lo que estuviera esperando, y sale ya
        $script:avisoCola.Insert(0, $texto)
        Send-AvisoCola $true
    } elseif ($nivel -ne 'bajo') {
        if ($script:avisoCola.Count -eq 0) { $script:avisoColaDesde = $sw.ElapsedMilliseconds }
        [void]$script:avisoCola.Add($texto)
    }
    return $true
}

# LO QUE PASA SIN QUE DIGAS NADA (fase 2, 16/09). Se mira cada 30 s desde el bucle.
# Todo pasa por Send-AvisoEntorno, o sea que respeta el tope por hora, el silencio
# jugando, las horas tranquilas y el "no me avises".
$script:entornoCheck = 0
$script:entornoUltimaActividad = 0
$script:entornoBotonesAntes = 0
$script:entornoUnidades = $null      # las unidades que habia la ultima vez (idea 31)
function Watch-Entorno([int]$botones = 0) {
    if (-not $EntornoOn) { return }
    # IDEA 6: COGES LA CONSOLA. El bucle ya lee los cuatro mandos; si aparecen botones
    # tras un buen rato quieto, es que la acabas de coger.
    $ahoraW = $sw.ElapsedMilliseconds
    if ($botones -ne 0) {
        $quietoMin = if ($script:entornoUltimaActividad -gt 0) { ($ahoraW - $script:entornoUltimaActividad) / 60000 } else { 0 }
        $script:entornoUltimaActividad = $ahoraW
        if ($quietoMin -ge 90 -and $script:entornoBotonesAntes -eq 0) {
            $txtM = 'Hola. ¿Seguimos?'
            if ($script:ultimoJuego) { $txtM = "Hola. ¿Seguimos con $($script:ultimoJuego)?" }
            [void](Send-AvisoEntorno 'mando-vuelta' $txtM 'medio' 180)
        }
        if ($quietoMin -ge 5 -and $script:entornoBotonesAntes -eq 0) {
            # para una regla basta con que lo cojas tras un rato quieto: el saludo
            # pide 90 minutos porque hablar cansa, pero "pon el modo juego" no.
            Invoke-Reglas 'mandoCoge' 'coge'
        }
    }
    $script:entornoBotonesAntes = $botones
    try { Send-AvisoCola } catch {}
    if (($ahoraW - $script:entornoCheck) -lt 30000) { return }
    $script:entornoCheck = $ahoraW

    # IDEAS 1 y 17: el parte de la manana y el resumen al volver EXISTIAN, pero solo
    # se preparaban dentro de Process-Texto: si no le hablabas, no salian nunca.
    if (-not $script:invitado) {
        try { Test-ParteManana } catch {}
        try { Test-ResumenAlVolver } catch {}
    }

    # IDEA 19 (cuanto llevas hoy): NO va en esta tanda. Me invente Get-TiempoJuegoHoy,
    # que no existe: hay tiempo de la PARTIDA de ahora ($script:juegoDesde) y el de la
    # semana, pero no los minutos acumulados del dia. Hacerlo bien es llevar la cuenta
    # por dia al cerrar cada juego, y eso es otra tanda; improvisar aqui un contador a
    # medias daria numeros falsos, que es peor que no decir nada.

    # IDEA 31: EL DISCO DE LOS JUEGOS VA Y VIENE. braya conecta un disco externo con
    # mas juegos y lo quita. Hasta ahora la biblioteca solo se refrescaba cuando alguien
    # preguntaba por un juego: con el disco fuera, "abre Elden Ring" intentaria abrir
    # algo que ya no esta; con el disco puesto, Nova no se enteraba de que tiene diez
    # juegos mas. Se comprueban las unidades y, si cambian, se reindexa.
    try {
        $letras = @([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady } | ForEach-Object { $_.Name }) -join ','
        if ($null -ne $script:entornoUnidades -and $letras -ne $script:entornoUnidades) {
            $antesJ = @($script:Juegos).Count
            $script:JuegosStamp = (Get-Date).AddMinutes(-5)   # forzar el refresco
            [void](Update-Juegos)
            $ahoraJ = @($script:Juegos).Count
            Log "UNIDADES: '$($script:entornoUnidades)' -> '$letras' (juegos: $antesJ -> $ahoraJ)"
            Invoke-Reglas 'discoJuegos' $(if ($ahoraJ -lt $antesJ) { 'quita' } else { 'pone' })
            if ($ahoraJ -gt $antesJ) {
                [void](Send-AvisoEntorno 'disco-juegos' "Veo el disco de los juegos. Ahora tienes $ahoraJ juegos." 'medio' 5)
            } elseif ($ahoraJ -lt $antesJ) {
                [void](Send-AvisoEntorno 'disco-juegos' "Quitaste el disco: te quedan $ahoraJ juegos a mano." 'medio' 5)
            }
        }
        $script:entornoUnidades = $letras
    } catch {}

    # IDEA 18: te has pasado de tu hora
    try {
        $txtD = Get-AvisoHoraDormir
        if ($txtD) { [void](Send-AvisoEntorno 'hora-dormir' $txtD 'noche' 480) }
    } catch {}

    # IDEA 29: hoy me estoy equivocando mas de lo normal
    try {
        $txtF = Get-AvisoFallos
        if ($txtF) { [void](Send-AvisoEntorno 'fallo-racha' $txtF 'medio' 720) }
    } catch {}

    # IDEA 22: el correo, una vez por la manana y sin congelar el bucle. Si Nova se
    # reinicia se vuelve a mirar, pero el aviso no se repite: eso lo frena el 'una vez
    # cada 12 horas' de Send-AvisoEntorno, que vive en disco.
    try {
        Receive-CorreoManana
        $hC = (Get-Date).Hour
        $diaC = (Get-Date).ToString('yyyy-MM-dd')
        if (-not $script:invitado -and $hC -ge 7 -and $hC -lt 12 -and -not $script:correoOut -and $script:correoMananaDia -ne $diaC) {
            $script:correoMananaDia = $diaC
            [void](Start-CorreoManana)
        }
    } catch {}

    # IDEA 26: el correo lleno. Una vez por semana, que es lo que aguanta cualquiera.
    try {
        if ($EntornoGmailLleno) {
            [void](Send-AvisoEntorno 'gmail-lleno' 'Recuerda que tienes el almacenamiento de Gmail lleno y puedes dejar de recibir correos.' 'medio' 10080)
        }
    } catch {}

    # IDEA 30: el resumen de la semana, los domingos por la tarde
    try {
        $hoyS = Get-Date
        if ($hoyS.DayOfWeek -eq [System.DayOfWeek]::Sunday -and $hoyS.Hour -ge 18) {
            $balS = ''
            try { $balS = [string](Get-BalanceAprendizaje) } catch { $balS = '' }
            if ($balS) { [void](Send-AvisoEntorno 'resumen-semana' $balS 'bajo' 10080) }
        }
    } catch {}
}

# IDEA 18: TE HAS PASADO DE TU HORA. Nada de sermon a las 23:00 clavadas: solo si a
# ESTA hora no sueles estar levantado. "Sueles" = tres dias de las dos ultimas semanas,
# el mismo criterio que ya usa la precarga de la charla. Devuelve la frase o '', sin
# hacer nada: el que decide si se dice es el vigilante.
function Get-AvisoHoraDormir([datetime]$ahora = (Get-Date)) {
    $hD = $ahora.Hour
    if ($hD -lt $EntornoNocheDesde -and $hD -ge 5) { return '' }
    $claveD = $ahora.ToString('HH')
    $limD = $ahora.AddDays(-14).ToString('yyyy-MM-dd')
    $diasD = @((Get-Habitos).charlaHoras.Keys | Where-Object { $_.EndsWith("|$claveD") -and $_.Substring(0, 10) -ge $limD }).Count
    if ($diasD -ge 3) { return '' }   # a estas horas sueles estar despierto: no es noticia
    return ('Son las ' + $ahora.ToString('H\:mm') + ' y a esta hora no sueles estar levantado.')
}

# IDEA 29: HOY ME ESTOY EQUIVOCANDO MAS DE LO NORMAL. Comparado con SU media de la
# semana, no con un numero inventado (la misma regla que la bateria de los juegos).
function Get-AvisoFallos([datetime]$ahora = (Get-Date)) {
    $stE = Get-Estadisticas
    $hoyE = $ahora.ToString('yyyy-MM-dd')
    if (-not $stE.dias.ContainsKey($hoyE)) { return '' }
    $malHoy = [int]$stE.dias[$hoyE]['error']
    if ($malHoy -lt 5) { return '' }        # con menos, cualquier dia pareceria malo
    $sumaE = 0; $nDiasE = 0
    for ($i = 1; $i -le 7; $i++) {
        $kE = $ahora.AddDays(-$i).ToString('yyyy-MM-dd')
        if (-not $stE.dias.ContainsKey($kE)) { continue }
        $sumaE += [int]$stE.dias[$kE]['error']
        $nDiasE++
    }
    if ($nDiasE -lt 3) { return '' }        # sin con que comparar, mejor callarse
    $mediaE = $sumaE / [double]$nDiasE
    if ($mediaE -le 0 -or $malHoy -le ($mediaE * 2)) { return '' }
    return "Hoy te estoy entendiendo peor de lo normal: $malHoy ordenes que no supe hacer. Si alguna se repite, dime: aprende que cuando diga..."
}

# IDEA 22: EL CORREO DE LA MANANA. Invoke-CorreoScript ESPERA a que el script termine
# (hasta 25 s); llamarlo desde el bucle dejaria a Nova congelada ese rato, sorda a todo.
# Asi que se lanza y se recoge en otra vuelta, igual que la segunda opinion de la nube.
$script:correoProc = $null
$script:correoOut = ''
$script:correoVence = 0
$script:correoMananaDia = ''

function Start-CorreoManana {
    if ($script:correoOut) { return $false }          # ya hay una mirando
    if (-not (Test-CorreoListo)) { return $false }
    try {
        $idC = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
        $script:correoOut = Join-Path $TmpDir "correo-manana-$idC.json"
        $script:correoProc = Start-Process -FilePath $PyWorker -WindowStyle Hidden -PassThru `
            -WorkingDirectory $LogDir -ArgumentList @($CorreoScript, 'no-leidos', '5', $script:correoOut)
        $null = $script:correoProc.Handle
        $script:correoVence = $sw.ElapsedMilliseconds + 30000
        Log 'CORREO: mirando el de la manana'
        return $true
    } catch {
        Log ('CORREO: no pude mirarlo: ' + $_.Exception.Message)
        $script:correoOut = ''
        return $false
    }
}

function Receive-CorreoManana {
    if (-not $script:correoOut) { return }
    if (Test-Path -LiteralPath $script:correoOut) {
        $rC = $null
        try { $rC = [System.IO.File]::ReadAllText($script:correoOut, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch {}
        Remove-Item -LiteralPath $script:correoOut -Force -ErrorAction SilentlyContinue
        $script:correoOut = ''
        $script:correoProc = $null
        if ($rC -and $rC.ok -and [int]$rC.cuantos -gt 0) {
            # en el log SOLO cuantos habia: ni remitentes ni asuntos
            Log "CORREO: $($rC.cuantos) sin leer (el de la manana)"
            [void](Send-AvisoEntorno 'correo-manana' (Format-Correos $rC.correos) 'medio' 720)
        }
        return
    }
    if ($sw.ElapsedMilliseconds -ge $script:correoVence) {
        try { if ($script:correoProc -and -not $script:correoProc.HasExited) { $script:correoProc.Kill() } } catch {}
        Remove-Item -LiteralPath $script:correoOut -Force -ErrorAction SilentlyContinue
        $script:correoOut = ''
        $script:correoProc = $null
        Log 'CORREO: el de la manana no contesto a tiempo'
    }
}

# "no me avises de nada" / "vuelve a avisarme"
function Set-AvisosEntorno([bool]$encendido) {
    $script:entornoCallado = -not $encendido
    if ($encendido) { return 'Vale, vuelvo a avisarte de las cosas.' }
    return 'Hecho, no te aviso de nada hasta que me digas lo contrario.'
}

# DOCK Y CASCOS (F8): cada 15 s, cuantas pantallas hay y si suena por unos cascos.
# Solo el FLANCO (al conectar), como el cargador.
$script:pantallasAntes = $null
$script:cascosAntes = $null
$script:dispCheck = 0
$script:uiDock = 0
function Watch-Dispositivos {
    $nP = 1
    try { $nP = @([System.Windows.Forms.Screen]::AllScreens).Count } catch {}
    if ($null -ne $script:pantallasAntes -and $nP -gt $script:pantallasAntes) {
        Log "DOCK: pantalla conectada ($nP)"
        Invoke-Reglas 'dockPone' 'pone'
        # idea 2: en el dock se juega en grande y con sonido; no hace falta la bateria
        [void](Send-AvisoEntorno 'dock-pone' 'Veo la pantalla grande. Si quieres, di: pon el modo trabajo.' 'bajo' 30)
    }
    # idea 3: al sacarla del dock, lo que importa es cuanto queda
    if ($null -ne $script:pantallasAntes -and $nP -lt $script:pantallasAntes) {
        Log "DOCK: pantalla desconectada ($nP)"
        $txtD = 'Ya estas sin la pantalla grande.'
        try {
            $bD = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($bD -and $bD.EstimatedChargeRemaining -and $bD.BatteryStatus -ne 2) {
                $txtD = "Sin la pantalla grande. Te queda el $([int]$bD.EstimatedChargeRemaining) por ciento de bateria."
            }
        } catch {}
        Invoke-Reglas 'dockQuita' 'quita'
        [void](Send-AvisoEntorno 'dock-quita' $txtD 'medio' 30)
    }
    $dockAhora = if ($nP -gt 1) { 1 } else { 0 }
    if ($dockAhora -ne $script:uiDock) { $script:uiDock = $dockAhora; Refresh-UI }
    $script:pantallasAntes = $nP
    $casP = $false
    try {
        $actP = @(Get-SalidasAudio | Where-Object { $_.actual }) | Select-Object -First 1
        if ($actP -and $actP.nombre -match '(?i)headphone|headset|auricular|casco|buds|airpods|wh-|wf-|hands-free|manos libres') { $casP = $true }
    } catch {}
    if ($null -ne $script:cascosAntes -and $casP -and -not $script:cascosAntes) {
        Log "CASCOS: puestos"
        Invoke-Reglas 'cascosPone' 'pone'
        # idea 4: con cascos, el volumen de los altavoces es un susto
        # $script:uiVolumen es lo ultimo que Nova puso o leyo; -1 = no lo sabe todavia
        $volC = [int]$script:uiVolumen
        if ($volC -gt 50) {
            [void](Send-AvisoEntorno 'cascos-pone' "Cascos puestos y el volumen esta al $volC. Di: pon el volumen al 30." 'medio' 10)
        } else {
            [void](Send-AvisoEntorno 'cascos-pone' 'Cascos puestos.' 'bajo' 10)
        }
    }
    # idea 5: al quitarlos, lo que sonaba sale por los altavoces de golpe
    if ($null -ne $script:cascosAntes -and -not $casP -and $script:cascosAntes) {
        Log "CASCOS: quitados"
        Invoke-Reglas 'cascosQuita' 'quita'
        # ¿suena algo? El worker deja el nivel de los altavoces en escucha-estado.txt
        # ("ganancia|ref|altavoces|bloques"); el mismo dato que usa "¿como me oyes?"
        $altC = 0.0
        try {
            $stC = ([System.IO.File]::ReadAllText($RutaEstado).Trim()) -split '\|'
            $altC = [double]::Parse($stC[2], [System.Globalization.CultureInfo]::InvariantCulture)
        } catch { $altC = 0.0 }
        if ($altC -gt 0.02) {
            [void](Send-AvisoEntorno 'cascos-quita' 'Te quitaste los cascos y sigue sonando. Di: pausa.' 'medio' 5)
        }
    }
    $script:cascosAntes = $casP
}

# RESUMEN AL VOLVER (13/09): si la orden llega tras mas de 2 h sin decirle
# nada, despues de contestarla la capsula enseña una linea con lo que ha pasado
# mientras tanto (hoy: los mensajes que te esperan). Si no paso nada, calla.
$script:ultimoUsoEn = 0
$script:resumenPendiente = ''
function Test-ResumenAlVolver {
    $ahoraU = $sw.ElapsedMilliseconds
    $ausente = ($script:ultimoUsoEn -gt 0 -and ($ahoraU - $script:ultimoUsoEn) -ge 7200000)
    $script:ultimoUsoEn = $ahoraU
    if (-not $ausente) { return }
    $partes = @()
    $nN = @($script:notifPendientes).Count
    if ($nN -gt 0) {
        $apps = @($script:notifPendientes | ForEach-Object { $_.app } | Select-Object -Unique)
        $partes += $(if ($nN -eq 1) { '1 mensaje' } else { "$nN mensajes" }) + $(if ($apps.Count -eq 1) { " de $($apps[0])" } else { '' })
    }
    if ($partes.Count -eq 0) { return }
    $script:resumenPendiente = 'Mientras no estabas: ' + ($partes -join ' · ')
    Log "RESUMEN AL VOLVER: $($script:resumenPendiente)"
}

# RECORDATORIO PARA CARGAR (13/09): se apunta la ultima orden de cada dia (la
# madrugada cuenta como el dia anterior, hasta las 5:00). Con 4 dias o mas de
# las dos ultimas semanas sale tu hora habitual de dejarla; en la media hora
# antes, sin cargador y por debajo del 40 %, un pulso y "enchufame". Una vez al dia.
function Set-UsoAhora([datetime]$cuando = (Get-Date)) {
    $hb = Get-Habitos
    $hb.fin[$cuando.AddHours(-5).ToString('yyyy-MM-dd')] = $cuando.ToString('HH:mm')
    $limite = $cuando.AddDays(-30).ToString('yyyy-MM-dd')
    foreach ($k in @($hb.fin.Keys)) { if ($k -lt $limite) { $hb.fin.Remove($k) } }
    Save-Habitos
}
# minutos desde las 00:00 del dia (la madrugada suma 24 h: la 01:00 son 1500), o -1
function Get-HoraFinHabitual([datetime]$hoy = (Get-Date)) {
    $hb = Get-Habitos
    $desde = $hoy.AddDays(-14).ToString('yyyy-MM-dd')
    $hoyK = $hoy.AddHours(-5).ToString('yyyy-MM-dd')
    $mins = @($hb.fin.Keys | Where-Object { $_ -ge $desde -and $_ -lt $hoyK } | ForEach-Object {
        $hf = [string]$hb.fin[$_]
        $mm = [int]$hf.Substring(0, 2) * 60 + [int]$hf.Substring(3, 2)
        if ($mm -lt 300) { $mm += 1440 }
        $mm
    } | Sort-Object)
    if ($mins.Count -lt 4) { return -1 }
    return $mins[[int][Math]::Floor($mins.Count / 2)]
}
function Test-RecordarCarga([int]$pct, [int]$cargando, [datetime]$ahora = (Get-Date)) {
    if ($cargando -eq 1 -or $pct -gt 40) { return $false }
    $finH = Get-HoraFinHabitual $ahora
    if ($finH -lt 0) { return $false }
    $mAhora = $ahora.Hour * 60 + $ahora.Minute
    if ($mAhora -lt 300) { $mAhora += 1440 }
    if ($mAhora -lt ($finH - 30) -or $mAhora -gt $finH) { return $false }
    $hb = Get-Habitos
    $diaC = $ahora.AddHours(-5).ToString('yyyy-MM-dd')
    if ($hb.cargaAvisada -eq $diaC) { return $false }
    $hb.cargaAvisada = $diaC
    Save-Habitos
    return $true
}

# BRILLO AUTOMATICO POR HORA (13/09): "activa el brillo automatico". Cada minuto
# se mira la franja (manana 60, dia 80, tarde 60, noche 40, madrugada 25) y solo
# se cambia al ENTRAR en una franja nueva: si lo tocas a mano, se respeta hasta
# la siguiente. Nunca con un juego delante (ahi manda el modo juego).
$script:brilloAutoPuesto = -1
function Get-BrilloPorHora([int]$hora) {
    if ($hora -ge 8 -and $hora -lt 18) { return 80 }
    if ($hora -ge 18 -and $hora -lt 21) { return 60 }
    if ($hora -ge 21) { return 40 }
    if ($hora -ge 6) { return 60 }
    return 25
}
function Update-BrilloAuto {
    $hbA2 = Get-Habitos
    if (-not $hbA2.brilloAuto -or $script:juegoActivo) { return }
    $objB = Get-BrilloPorHora (Get-Date).Hour
    if ($objB -eq $script:brilloAutoPuesto) { return }
    $script:brilloAutoPuesto = $objB
    try { Set-Brillo $objB; Log "BRILLO AUTOMATICO: $objB %" } catch {}
}

function Find-Propuesta([datetime]$hoy = (Get-Date)) {
    $hb = Get-Habitos
    if ($hb.ultimaPropuesta -eq $hoy.ToString('yyyy-MM-dd')) { return $null }
    $desde = $hoy.AddDays(-7).ToString('yyyy-MM-dd')
    $rec = @($hb.usos | Where-Object { $_.f -ge $desde })
    $reglasP = Get-Reglas
    # 1. la misma orden a la misma hora
    foreach ($g in @($rec | Group-Object { $_.t })) {
        $porDia = @{}
        foreach ($u in $g.Group) { if (-not $porDia.ContainsKey($u.f)) { $porDia[$u.f] = $u.h } }
        if ($porDia.Count -lt 3) { continue }
        $mins = @($porDia.Values | ForEach-Object { [int]$_.Substring(0, 2) * 60 + [int]$_.Substring(3, 2) } | Sort-Object)
        $med = $mins[[int][Math]::Floor($mins.Count / 2)]
        if (@($mins | Where-Object { [Math]::Abs($_ - $med) -le 30 }).Count -lt 3) { continue }
        $med5 = ([int]([Math]::Round($med / 5.0) * 5)) % 1440
        $hora = '{0:00}:{1:00}' -f [int][Math]::Floor($med5 / 60), ($med5 % 60)
        $clave = "hora|$($g.Name)"
        if ($hb.rechazadas -contains $clave) { continue }
        if (@($reglasP | Where-Object { $_.tipo -eq 'hora' -and (ConvertTo-Plain $_.accion) -eq $g.Name }).Count -gt 0) { continue }
        return @{ clave = $clave; tipo = 'hora'; valor = $hora; accion = $g.Name
            pregunta = "Estos dias, a eso de las $hora, sueles pedirme $($g.Name). ¿Quieres que lo haga yo sola cada dia a esa hora?" }
    }
    # 2. la misma orden justo despues de abrir una app
    $pares = @{}
    for ($i = 1; $i -lt $rec.Count; $i++) {
        $b = $rec[$i]; $a = $rec[$i - 1]
        if ($a.f -ne $b.f -or $a.t -eq $b.t -or $a.t -notmatch '^abre (.+)$') { continue }
        $appP = $Matches[1]
        $dm = ([int]$b.h.Substring(0, 2) * 60 + [int]$b.h.Substring(3, 2)) - ([int]$a.h.Substring(0, 2) * 60 + [int]$a.h.Substring(3, 2))
        if ($dm -lt 0 -or $dm -gt 3) { continue }
        $k = "$appP|$($b.t)"
        if (-not $pares.ContainsKey($k)) { $pares[$k] = @{} }
        $pares[$k][$a.f] = $true
    }
    foreach ($k in $pares.Keys) {
        if ($pares[$k].Count -lt 3) { continue }
        $appP, $accP = $k -split '\|', 2
        $clave = "app|$k"
        if ($hb.rechazadas -contains $clave) { continue }
        if (@($reglasP | Where-Object { $_.tipo -eq 'appAbre' -and (ConvertTo-Plain $_.valor) -eq $appP -and (ConvertTo-Plain $_.accion) -eq $accP }).Count -gt 0) { continue }
        return @{ clave = $clave; tipo = 'appAbre'; valor = $appP; accion = $accP
            pregunta = "Cuando abres $appP, casi siempre me pides despues $accP. ¿Quieres que lo haga yo sola?" }
    }
    # 3. tres ordenes seguidas, siempre en el mismo orden y en menos de 5 min, tres
    #    dias distintos (13/09): no son una regla (las pides tu), asi que se
    #    proponen como UNA orden ensenada: "haz lo de siempre".
    $seqs = @{}
    for ($i = 2; $i -lt $rec.Count; $i++) {
        $u1 = $rec[$i - 2]; $u2 = $rec[$i - 1]; $u3 = $rec[$i]
        if ($u1.f -ne $u3.f -or $u1.t -eq $u2.t -or $u2.t -eq $u3.t -or $u1.t -eq $u3.t) { continue }
        $m1 = [int]$u1.h.Substring(0, 2) * 60 + [int]$u1.h.Substring(3, 2)
        $m3 = [int]$u3.h.Substring(0, 2) * 60 + [int]$u3.h.Substring(3, 2)
        if (($m3 - $m1) -lt 0 -or ($m3 - $m1) -gt 5) { continue }
        $kS = "$($u1.t)|$($u2.t)|$($u3.t)"
        if (-not $seqs.ContainsKey($kS)) { $seqs[$kS] = @{} }
        $seqs[$kS][$u1.f] = $true
    }
    foreach ($kS in $seqs.Keys) {
        if ($seqs[$kS].Count -lt 3) { continue }
        $clave = "seq|$kS"
        if ($hb.rechazadas -contains $clave) { continue }
        $ords = @($kS -split '\|')
        return @{ clave = $clave; tipo = 'secuencia'; ordenes = $ords; valor = ''; accion = ''
            pregunta = "Sueles pedirme seguidas estas tres cosas: $($ords[0]), $($ords[1]) y $($ords[2]). ¿Te hago un modo que lo haga todo junto?" }
    }
    return $null
}

# DISCORD POR VOZ (13/09): "silencia mi micro", "ensordeceme". Discord solo
# atiende atajos GLOBALES si los configuras tu (Ajustes > Atajos de teclado >
# "Activar o desactivar silencio" / "ensordecer"). Nova pulsa esa combinacion
# (config.json: discord.teclaMicro / discord.teclaSordo). Son interruptores:
# Discord no deja poner "silenciado" a secas, asi que Nova no presume de saber
# en que estado queda.
$DiscordTeclaMicro = [string](Get-Cfg 'discord' 'teclaMicro' 'ctrl+shift+m')
$DiscordTeclaSordo = [string](Get-Cfg 'discord' 'teclaSordo' 'ctrl+shift+d')
function Send-Combinacion([string]$combo) {
    $vks = @()
    foreach ($parte in ($combo.ToLowerInvariant() -split '\+')) {
        $pt = $parte.Trim()
        $vk = $null
        if ($pt -match '^(?:ctrl|control)$') { $vk = 0x11 }
        elseif ($pt -eq 'shift') { $vk = 0x10 }
        elseif ($pt -eq 'alt') { $vk = 0x12 }
        elseif ($pt -match '^(?:win|windows)$') { $vk = 0x5B }
        elseif ($pt -match '^f([1-9]|1[0-2])$') { $vk = 0x6F + [int]$Matches[1] }
        elseif ($pt -match '^[a-z0-9]$') { $vk = [int][char]$pt.ToUpperInvariant() }
        if ($null -eq $vk) { throw "la tecla '$pt' no la entiendo" }
        $vks += $vk
    }
    foreach ($vk in $vks) { [AX]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 25 }
    for ($i = $vks.Count - 1; $i -ge 0; $i--) { [AX]::keybd_event([byte]$vks[$i], 0, $KEYUP, [UIntPtr]::Zero) }
}

# HISTORIAL DEL PORTAPAPELES (13/09): los ultimos 10 textos que copiaste, mirado
# cada 4 s. SOLO EN MEMORIA: se pierde al cerrar el asistente y nunca va a
# disco ni al log (lo que se copia son contrasenas, direcciones, codigos...).
$script:portaHist = New-Object System.Collections.ArrayList
$script:portaCheck = 0
function Watch-Portapapeles([string]$texto) {
    if (-not $texto -or $texto.Length -gt 5000) { return }
    if ($script:portaHist.Count -gt 0 -and $script:portaHist[0] -ceq $texto) { return }
    # si ya estaba mas atras (lo acabas de volver a pegar), sube al principio
    for ($i = $script:portaHist.Count - 1; $i -ge 0; $i--) { if ($script:portaHist[$i] -ceq $texto) { $script:portaHist.RemoveAt($i) } }
    $script:portaHist.Insert(0, $texto)
    while ($script:portaHist.Count -gt 10) { $script:portaHist.RemoveAt($script:portaHist.Count - 1) }
}

# NOVA EVOLUCIONA: un nivel del 0 al 5 segun lo que ha aprendido (tareas, formas
# de pedirlas, datos tuyos y reglas). Se ve poco a proposito: el halo de la
# capsula un pelin mas amplio en cada nivel, y al subir, un destello despues de
# hablar. "¿Que nivel tienes?" lo cuenta. El nivel ya celebrado se guarda en
# config.json (ui.nivelVisto) para no celebrarlo dos veces.
$NIVELES_NOVA = @(0, 1, 5, 12, 25, 50)
$script:uiMadurez = 0
$script:nivelPendiente = 0
function Get-CuentaAprendida {
    $n = 0
    try { $rsC = Get-Recetas; $n += $rsC.Count; foreach ($r in $rsC) { $n += @(@($r.variantes) | Where-Object { $_ }).Count } } catch {}
    try { $n += @(Get-DatosPerfil).Count } catch {}
    try { $n += (Get-Reglas).Count } catch {}
    return $n
}
function Get-Madurez([int]$cuenta) {
    $nv = 0
    for ($i = 0; $i -lt $NIVELES_NOVA.Count; $i++) { if ($cuenta -ge $NIVELES_NOVA[$i]) { $nv = $i } }
    return $nv
}
function Update-Madurez {
    $cuentaM = Get-CuentaAprendida
    $nv = Get-Madurez $cuentaM
    if ($nv -ne $script:uiMadurez) { $script:uiMadurez = $nv; Refresh-UI }
    # el nivel ya celebrado va en habitos.json (fuera de git), no en config.json,
    # que esta en el repositorio publico (revision del 13/09)
    $hbN = Get-Habitos
    if ($nv -gt [int]$hbN.nivelVisto) {
        $hbN.nivelVisto = $nv
        Save-Habitos
        # no ahora: la respuesta que viene detras taparia el destello. Despues
        # de hablar (ver el bloque de la pausa)
        $script:nivelPendiente = $nv
        Log "NIVEL: sube al $nv ($cuentaM cosas aprendidas)"
    }
}
function Get-FraseNivel {
    $cuentaM = Get-CuentaAprendida
    $nv = Get-Madurez $cuentaM
    $cosas = if ($cuentaM -eq 1) { 'una cosa' } else { "$cuentaM cosas" }
    if ($nv -ge $NIVELES_NOVA.Count - 1) { return "estoy en el nivel $nv, el maximo: se $cosas" }
    $faltan = $NIVELES_NOVA[$nv + 1] - $cuentaM
    return "estoy en el nivel $nv y se $cosas; " + $(if ($faltan -eq 1) { 'con una mas' } else { "con $faltan mas" }) + " subo al $($nv + 1)"
}

# MODO DE ENERGIA POR VOZ (13/09): el deslizador "Modo de energia" de Windows
# (maxima eficiencia / equilibrado / maximo rendimiento), con la misma API que
# usa el propio Windows. No toca los modos de Armoury Crate.
function Initialize-Energia {
    if ('NovaEnergia.P' -as [type]) { return }
    Add-Type -Namespace NovaEnergia -Name P -MemberDefinition @'
[DllImport("powrprof.dll")] public static extern uint PowerSetActiveOverlayScheme(System.Guid g);
[DllImport("powrprof.dll")] public static extern uint PowerGetEffectiveOverlayScheme(out System.Guid g);
'@
}
$GUID_ENERGIA = @{ 'ahorro' = '961cc777-2547-4f9d-8174-7d86181b8a7a'; 'equilibrado' = '00000000-0000-0000-0000-000000000000'; 'rendimiento' = 'ded574b5-45a0-4f42-8737-46345c09c238' }
function Get-ModoEnergia {
    Initialize-Energia
    $g = [Guid]::Empty
    if ([NovaEnergia.P]::PowerGetEffectiveOverlayScheme([ref]$g) -ne 0) { return '' }
    foreach ($k in $GUID_ENERGIA.Keys) { if ($GUID_ENERGIA[$k] -eq $g.ToString()) { return $k } }
    return 'personalizado'
}
function Set-ModoEnergia([string]$modo) {
    Initialize-Energia
    return ([NovaEnergia.P]::PowerSetActiveOverlayScheme([Guid]$GUID_ENERGIA[$modo]) -eq 0)
}

# BLUETOOTH Y WI-FI POR VOZ (13/09): las radios de Windows por WinRT, sin abrir
# ajustes. OJO: apagar el Wi-Fi deja sin internet al cerebro y a la voz en linea
# (habla Piper, sin red), asi que se avisa al hacerlo.
function Set-Radio([string]$tipo, [bool]$encender) {
    $null = [Windows.Devices.Radios.Radio, Windows.System.Devices, ContentType = WindowsRuntime]
    $radios = Await-WinRT ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]]) 4000
    $kindR = if ($tipo -eq 'bluetooth') { 'Bluetooth' } else { 'WiFi' }
    $radio = @($radios | Where-Object { [string]$_.Kind -eq $kindR }) | Select-Object -First 1
    $nombreR = if ($tipo -eq 'bluetooth') { 'el bluetooth' } else { 'el wifi' }
    if (-not $radio) { return "no encuentro $nombreR en este equipo" }
    $objetivo = if ($encender) { [Windows.Devices.Radios.RadioState]::On } else { [Windows.Devices.Radios.RadioState]::Off }
    $palabra = if ($encender) { 'encendido' } else { 'apagado' }
    if ([string]$radio.State -eq [string]$objetivo) { return "$nombreR ya estaba $palabra" }
    $resR = Await-WinRT ($radio.SetStateAsync($objetivo)) ([Windows.Devices.Radios.RadioAccessStatus]) 5000
    if ([string]$resR -ne 'Allowed') { return "Windows no me deja cambiar $nombreR ($resR)" }
    if ($tipo -eq 'wifi' -and -not $encender) { return 'wifi apagado; sin internet no puedo preguntarle a la IA' }
    return "$nombreR $palabra"
}

# TIEMPO DE JUEGO DE LA SEMANA (13/09): los segundos con cada juego delante se
# suman por dia en memoria\juegos.json ("dias": {"2026-09-13": 2700}), guardados
# cada 5 min de juego y al salir, no en cada vuelta. 60 dias como mucho.
$script:tiempoJuegoPend = @{}
$script:tiempoJuegoVisto = 0
function Add-TiempoJuego([string]$juego, [int]$seg) {
    if (-not $juego -or $seg -le 0 -or $seg -gt 120) { return }
    if (-not $script:tiempoJuegoPend.ContainsKey($juego)) { $script:tiempoJuegoPend[$juego] = 0 }
    $script:tiempoJuegoPend[$juego] += $seg
    $sumaP = 0; foreach ($v in $script:tiempoJuegoPend.Values) { $sumaP += $v }
    if ($sumaP -ge 300) { Save-TiempoJuego }
}
function Get-DiasJuego($dias) {
    $h = @{}
    if ($dias -is [hashtable]) { foreach ($k in $dias.Keys) { $h[$k] = [int]$dias[$k] } }
    elseif ($dias) { foreach ($p in $dias.PSObject.Properties) { $h[$p.Name] = [int]$p.Value } }
    return $h
}
function Save-TiempoJuego([datetime]$hoy = (Get-Date)) {
    if ($script:tiempoJuegoPend.Count -eq 0) { return }
    $m = Get-JuegosMem
    $diaT = $hoy.ToString('yyyy-MM-dd')
    $limiteT = $hoy.AddDays(-60).ToString('yyyy-MM-dd')
    foreach ($k in @($script:tiempoJuegoPend.Keys)) {
        if (-not $m.ContainsKey($k)) { $m[$k] = @{} }
        $h = Get-DiasJuego $m[$k]['dias']
        $h[$diaT] = [int]$h[$diaT] + [int]$script:tiempoJuegoPend[$k]
        foreach ($d in @($h.Keys)) { if ($d -lt $limiteT) { $h.Remove($d) } }
        $m[$k]['dias'] = $h
    }
    $script:tiempoJuegoPend = @{}
    Save-JuegosMem
}
# minutos por juego de los ultimos $dias dias (incluido hoy), de mas a menos
function Get-TiempoJugado([int]$dias = 7, [datetime]$hoy = (Get-Date)) {
    Save-TiempoJuego $hoy
    $m = Get-JuegosMem
    $desde = $hoy.AddDays(-($dias - 1)).ToString('yyyy-MM-dd')
    $tot = @{}
    foreach ($k in $m.Keys) {
        $h = Get-DiasJuego $m[$k]['dias']
        foreach ($d in $h.Keys) { if ($d -ge $desde) { $tot[$k] = [int]$tot[$k] + [int]$h[$d] } }
    }
    return @($tot.GetEnumerator() | Where-Object { $_.Value -ge 60 } | Sort-Object Value -Descending | ForEach-Object { @{ juego = $_.Key; minutos = [int][Math]::Round($_.Value / 60) } })
}

# VELOCIDAD DE LA VOZ (13/09): "habla mas rapido / mas despacio / normal", en
# escalones de 15 % entre -30 % y +45 %. El worker de voz en linea la lee de
# velocidad.txt en su carpeta de cache en cada frase (y la mete en la cache).
$script:vozVelocidad = 0
function Set-VozVelocidad([int]$pct) {
    $script:vozVelocidad = [Math]::Max(-30, [Math]::Min(45, $pct))
    try {
        if ($VozCache) {
            if (-not (Test-Path -LiteralPath $VozCache)) { New-Item -ItemType Directory -Force -Path $VozCache | Out-Null }
            [System.IO.File]::WriteAllText((Join-Path $VozCache 'velocidad.txt'), [string]$script:vozVelocidad)
        }
    } catch {}
}

# SALIDA DE SONIDO POR VOZ (13/09): "pon el sonido en los cascos", "vuelve a los
# altavoces". El cambio del dispositivo predeterminado lo hace nova_audio.cs con
# la misma interfaz que usa el panel de sonido de Windows. Se busca por palabras
# (cascos -> headphones/headset/buds..., altavoces -> speakers, tele -> HDMI) o
# por el nombre que digas.
function Initialize-SalidaAudio {
    if ('NovaAudio.Salida' -as [type]) { return $true }
    $csA = Join-Path $LogDir 'nova_audio.cs'
    if (-not (Test-Path -LiteralPath $csA)) { Log "salida de audio: falta nova_audio.cs"; return $false }
    try { Add-Type -TypeDefinition ([System.IO.File]::ReadAllText($csA)) -ErrorAction Stop; return $true }
    catch { Log ("salida de audio: " + $_.Exception.Message); return $false }
}
function Get-SalidasAudio {
    if (-not (Initialize-SalidaAudio)) { return @() }
    return @([NovaAudio.Salida]::Lista() | ForEach-Object { $pA = $_ -split '\|', 3; @{ id = $pA[0]; nombre = $pA[1]; actual = ($pA[2] -eq '1') } })
}
function Set-SalidaAudio([string]$quiere) {
    $listaA = @(Get-SalidasAudio)
    if ($listaA.Count -eq 0) { return 'no encuentro salidas de sonido' }
    $qA = ConvertTo-Plain $quiere
    $patronA = if ($qA -match 'casco|auricular|headset|audifono') { '(?i)headphone|headset|auricular|casco|buds|airpods|wh-|wf-|hands-free|manos libres' }
               elseif ($qA -match 'altavoc|bocina|parlante|speaker') { '(?i)speaker|altavoz|altavoces|realtek' }
               elseif ($qA -match 'tele|tv|monitor|pantalla|hdmi') { '(?i)hdmi|tv|monitor|display' }
               else { [regex]::Escape($qA) }
    $candA = @($listaA | Where-Object { (ConvertTo-Plain $_.nombre) -match $patronA -or $_.nombre -match $patronA })
    if ($candA.Count -eq 0) {
        if ($listaA.Count -eq 1) { return "solo hay una salida de sonido: $($listaA[0].nombre)" }
        return "no encuentro $quiere; tengo " + ((@($listaA | ForEach-Object { $_.nombre })) -join ', ')
    }
    $objA = $candA[0]
    if ($objA.actual) { return "ya suena por $($objA.nombre)" }
    [NovaAudio.Salida]::Poner($objA.id)
    return "ahora suena por $($objA.nombre)"
}

# LA ULTIMA CAPTURA (13/09): la imagen mas reciente de las carpetas donde caen
# las capturas (barra de juego de Windows, Recortes / Impr Pant, Videos). "Copia
# la ultima captura" la deja en el portapapeles para pegarla en Discord.
function Get-UltimaCaptura {
    $carpetas = @(
        (Join-Path ([Environment]::GetFolderPath('MyVideos')) 'Captures'),
        (Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Screenshots'),
        (Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Capturas de pantalla'),
        [Environment]::GetFolderPath('MyVideos')
    )
    $mejor = $null
    foreach ($c in $carpetas) {
        if (-not $c -or -not (Test-Path -LiteralPath $c)) { continue }
        $f = Get-ChildItem -LiteralPath $c -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Extension -match '^\.(?:png|jpe?g|webp|bmp)$' } |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f -and (-not $mejor -or $f.LastWriteTime -gt $mejor.LastWriteTime)) { $mejor = $f }
    }
    return $mejor
}

# ESCONDERSE UN RATO (13/09): "escondete 10 minutos" para grabar o emitir. La
# capsula se retira como con "escondete" y vuelve sola al vencer el plazo.
$script:retiradaHasta = 0
# '' = visible; 'nombre' = escondida hasta que la llames; 'tiempo' = hasta que venza
$script:uiRetirada = $false

# COLOR DE LA CAPSULA A ELECCION: "ponte de color naranja". Solo cambia el de
# reposo; los de cada estado (escuchando, pensando, error...) se quedan, que
# son los que dicen algo. Va aqui arriba y no junto a la esquina porque el
# banco (-Probar) sale antes de llegar alli.
$ColoresUI = [ordered]@{
    'turquesa' = '35E0C8'; 'verde agua' = '35E0C8'; 'verde' = '3DF09A'; 'azul' = '4D8BFF'; 'celeste' = '5CC8FF'
    'cian' = '3DD9F0'; 'morado' = 'A77BFF'; 'violeta' = 'B48CFF'; 'lila' = 'C9A2FF'; 'rosa' = 'FF7EC4'
    'rojo' = 'FF5A5A'; 'naranja' = 'FF8A3D'; 'amarillo' = 'FFD84A'; 'dorado' = 'FFC24A'; 'blanco' = 'E8EEF4'
}

# "¿COMO ESTAS CONFIGURADA?": lo esencial en una tarjeta, para no tener que
# abrir config.json a mano. Solo lo que cambia algo para ti.
function Get-Configuracion {
    $p = @()
    $motorO = [string](Get-Cfg 'input' 'motorOrdenes' 'auto')
    $conFino = if ($WhisperPreciso) { " y repaso lo dudoso con $WhisperPreciso" } else { '' }
    $oidoT = switch ($motorO) {
        'worker' { "te oigo con Whisper $WhisperModelo$conFino" }
        'auto' { "te oigo con el dictado de Windows fuera del juego y con Whisper $WhisperModelo jugando" }
        default { 'te oigo con el dictado de Windows' }
    }
    if ($script:sordinaHasta -gt $sw.ElapsedMilliseconds) {
        $oidoT += ', aunque ahora estoy en sordina ' + [int][Math]::Ceiling(($script:sordinaHasta - $sw.ElapsedMilliseconds) / 60000) + ' minutos'
    }
    $p += "Me llamo $EscuchaNombre y $oidoT"
    $p += if (-not $VozOn) { 'tengo la voz apagada' }
          elseif ($VozMotor -eq 'online') { "hablo con la voz en linea $VozOnlineNombre" }
          else { "hablo con $VozMotor" }
    if ($CerebroMotor -eq 'claude-code') {
        $p += "lo que no se hacer lo piensa Claude: $CcModeloTraducir para entenderte, $CcModeloPregunta para preguntas y $CcModeloAccion para tareas"
    } elseif ($CerebroMotor) {
        $p += "mi cerebro es $CerebroMotor"
    }
    $esq = $script:esquina -split '-'
    $colN = ''
    foreach ($k in $ColoresUI.Keys) { if ($ColoresUI[$k] -eq $script:uiColor) { $colN = $k; break } }
    $p += "vivo $($esq[0]) a la $($esq[1]), al $([int]($script:uiEscala * 100)) por ciento" + $(if ($colN) { " y de color $colN" } else { '' })
    $nMod = 0
    try { $nMod = @($cmds.perfiles.PSObject.Properties.Name).Count } catch {}
    $nReg = (Get-Reglas).Count
    $nRec = (Get-Recetas).Count
    $nDat = @(Get-DatosPerfil).Count
    $p += "tengo $nMod modos, $nReg reglas, $nRec tareas aprendidas y $nDat cosas sabidas de ti"
    # cada frase empieza en mayuscula: en la tarjeta se lee, no solo se oye
    return (@($p | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join '. ') + '.'
}

# PLAZO POR MODO (auditoria del 13/09): con un solo plazo de 240 s, si Haiku se
# colgaba traduciendo (tarda ~5 s) Nova se quedaba 4 min "Entendiendo".
function Get-PlazoJob {
    switch ([string]$script:jobModo) {
        'traducir' { return 25000 }
        'plan' { return 25000 }
        'pregunta' { return 90000 }
        'charla' { return 90000 }
        default { return $CliTimeoutMs }
    }
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
    # el MISMO patron completo que usa el ejecutor: con solo "aprende que"
    # decia si, y luego no habia nada que aprender (y de paso Repair-Verb
    # convertia "aprende" en "prende" y la frase se perdia)
    if ($text -match '(?i)^\s*aprende\s+que\s+(?:a\s+)?(.+?)\s+(?:le\s+(?:digo|llamo|dicen)|es|se\s+llama)\s+(.+)$') { return $true }
    # el MISMO patron que el ejecutor, o el banco no ve que crear un modo es local
    if ($text -match '(?i)^\s*(?:crea|crear|haz|hazme|define|guardame)\s+(?:el\s+|un\s+)?modo\s+([^\s:,]{2,20})\s*(?::|,|\s+que\s+|\s+con\s+|\s+)\s*(.+)$') { return $true }
    $pl = ConvertTo-Plain $text
    if ($pl -match '^(?:recuerdame|avisame|recordatorio)\s+(?!que\b)(?:hoy|manana|pasado manana|el (?:lunes|martes|miercoles|jueves|viernes|sabado|domingo)|el \d{1,2} de |a las? )') { return $true }   # recordatorio con fecha
    # ojo: los mismos lookaheads que el ejecutor. Con el patron corto, este
    # atajo devolvia $true y se saltaba Resolve-Fragment, de modo que el
    # banco no podia ver que "guarda el archivo" acababa en el diario.
    if ($text -match '(?i)^\s*(?:recu[eé]rdame|recuerda|acu[eé]rdate|anota|apunta|guarda(?=\s+(?:que|de\s+que)\b)|memoriza)\s+(?!.*\s(?:en|a)\s+(?:la\s+|mi\s+)?lista(?:\s+de\s+.+)?$)(?!(?:en|dentro de)\s+(?:\d+|un|una|uno|medi[ao]|(?:un\s+)?cuarto\s+de|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis\S+|veinte|veinti\S+|treinta|cuarenta|cincuenta|sesenta|noventa)(?:\s+y\s+\S+)?\s+(?:segundos?|minutos?|horas?)\b)(?!(?:\d+|un|una|medi[ao]|(?:un\s+)?cuarto\s+de|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis\S+|veinte|veinti\S+|treinta|cuarenta|cincuenta|sesenta|noventa)(?:\s+y\s+\S+)?\s+(?:minutos?|horas?)(?:\s+y\s+media)?\s+antes\b)(?!(?:esto|eso|esta pantalla|lo de la pantalla|lo que dice la pantalla|lo que pone|este codigo|el codigo|la clave|la combinacion|esta clave|este numero)$)(?!(?:hoy|ma[nñ]ana|pasado\s+ma[nñ]ana|el\s+(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)|el\s+\d{1,2}\s+de\s|a\s+las?\s)\b)(?!(?:cual|cuales|que es|que fue|si|donde|cuando|quien|como|cuanto)\b)(?:que\s+|de\s+que\s+)?(.+)$' -and $text -notmatch '\?\s*$') { return $true }
    # Reglas y recordatorios con hora: los decide Invoke-ReglaVoz, que SI crea
    # cosas, asi que aqui no se puede llamar. Se responde $true solo si la
    # frase tiene la forma de una regla; el banco las prueba aparte llamando
    # al de verdad. Antes era un $false seco y la capsula nunca asentia a una
    # regla, aunque fuera perfecta.
    # OJO: solo las formas que DE VERDAD son una regla. Con un '^cuando\s' a
    # secas se colaban preguntas sobre el pasado -"cuando jugue a outlast"- que
    # no son reglas y acababan en el modelo por nada.
    if ($pl -match '^(?:cuando\s+(?:se\s+)?(?:abra|abras|inicie|inicies|arranque|empiece|entre|cierre|cierres|termine|acabe|complete|salga|la bateria|la pila|quite|quites|enchufe|enchufes|ponga|pongas|conecte|desconecte)|cada\s+\d+\s*(?:minuto|hora)|todos los dias|a las?\s)') {
        return [bool]($pl -match ('(?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame|abrelo|abrela|ejecutalo|lanzalo|inicialo|arrancalo|juegalo)\b'))
    }
    # el mismo corte que en Invoke-FastCommand: este es el camino que usan la
    # capsula y el banco de pruebas, y tiene que decir lo mismo que el ejecutor
    if (Test-CatalogoRecitado $text) { return $false }
    $frags = $null
    try { $frags = Split-Ordenes $text } catch { return $false }
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

# Las acciones que TOCAN el sistema, por oposicion a las que solo miran o
# cuentan. Sirven para dos cosas distintas y las dos quieren la misma lista: dar
# un respiro entre ellas, y decidir si una orden merece que se pregunte antes
# (una voz que no es la tuya puede preguntar la hora; no puede cerrar el juego).
$AccionesQueTocan = @('app', 'url', 'key', 'atajo', 'escribir', 'winkey', 'altf4', 'alttab', 'otroMonitor',
                      'enfocar', 'enfocarJuego', 'buscarEquipo', 'winprt', 'winaltg',
                      'volumenPct', 'brillo', 'lock', 'cerrarApp', 'cerrarJuego', 'cerrarTodo')

# PONER EL VIDEO, NO SOLO BUSCARLO (15/09). "Reproduce la cancion de Pitbull Give Me
# Everything en YouTube" abria la busqueda; braya se quejo y el agente tardo 83 s en
# ponerla. La pagina de resultados de YouTube ya trae los videoId: se abre el primero,
# sin clave ni agente. Probado: "pitbull give me everything" -> "Pitbull - Give Me
# Everything ft. Ne-Yo, Afrojack, Nayer". Si falla o tarda, la busqueda como antes.
# ABRIR UNA CARPETA POR SU NOMBRE (15/09): "abre la carpeta Games" (la del escritorio) no se
# entendia; la API lo tradujo a "abre explorador" y ademas se aprendio. Primero los nombres
# de siempre (descargas, documentos...); si no, una carpeta con ese nombre en el escritorio,
# documentos, descargas, la carpeta personal, imagenes, videos o musica.
function Find-CarpetaPorNombre([string]$nombre) {
    $pl = ConvertTo-Plain $nombre
    if (-not $pl) { return '' }
    $especiales = @{
        'descargas' = (Join-Path $env:USERPROFILE 'Downloads'); 'documentos' = [Environment]::GetFolderPath('MyDocuments')
        'escritorio' = [Environment]::GetFolderPath('Desktop'); 'imagenes' = [Environment]::GetFolderPath('MyPictures')
        'fotos' = [Environment]::GetFolderPath('MyPictures'); 'musica' = [Environment]::GetFolderPath('MyMusic')
        'videos' = [Environment]::GetFolderPath('MyVideos')
    }
    if ($especiales.ContainsKey($pl) -and $especiales[$pl] -and (Test-Path -LiteralPath $especiales[$pl])) { return $especiales[$pl] }
    $raices = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'), (Join-Path $env:USERPROFILE 'Downloads'),
                $env:USERPROFILE, [Environment]::GetFolderPath('MyPictures'), [Environment]::GetFolderPath('MyVideos'), [Environment]::GetFolderPath('MyMusic'))
    $parecida = ''
    foreach ($r in $raices) {
        if (-not $r -or -not (Test-Path -LiteralPath $r)) { continue }
        foreach ($d in @(Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue)) {
            $pd = ConvertTo-Plain $d.Name
            if ($pd -eq $pl) { return $d.FullName }
            if (-not $parecida -and $pd -and [Math]::Min($pd.Length, $pl.Length) -ge 4 -and ($pd.StartsWith($pl) -or $pl.StartsWith($pd))) { $parecida = $d.FullName }
        }
    }
    return $parecida
}

# EL VIDEO NUMERO N (16/09). El 15/09, "reproduce el segundo video de YouTube" y
# "reproduce la segunda cancion de el" se fueron al agente cuatro veces (hasta 88 s) y
# ni asi. Es la misma pagina de resultados: basta con coger la coincidencia numero N,
# quitando repetidos (YouTube repite el mismo videoId varias veces en el HTML).
function Get-PrimerVideoYouTube([string]$q, [int]$n = 1) {
    if (-not $q) { return '' }
    if ($n -lt 1) { $n = 1 }
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 -Headers @{ 'Accept-Language' = 'es-ES,es;q=0.9' } `
            -Uri ('https://www.youtube.com/results?search_query=' + [Uri]::EscapeDataString($q))
        $ids = @([regex]::Matches([string]$r.Content, '"videoId":"([A-Za-z0-9_-]{11})"') |
                 ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        if ($ids.Count -ge $n) {
            Log "YOUTUBE: '$q' -> $($ids[$n - 1])$(if ($n -gt 1) { " (el numero $n de $($ids.Count))" })"
            return 'https://www.youtube.com/watch?v=' + $ids[$n - 1]
        }
        if ($ids.Count -gt 0) {
            Log "YOUTUBE: '$q' solo tiene $($ids.Count) videos; pongo el ultimo"
            return 'https://www.youtube.com/watch?v=' + $ids[$ids.Count - 1]
        }
        Log "YOUTUBE: '$q' sin videos en la pagina; abro la busqueda"
    } catch { Log ("YOUTUBE: no pude sacar el video (" + $_.Exception.Message + "); abro la busqueda") }
    return ''
}

# LO ULTIMO QUE SE PUSO EN YOUTUBE, para poder decir "pon el segundo" despues
$script:ytUltimaBusqueda = ''
# "el segundo", "la tercera cancion", "el video numero 4"
$ORDINALES_YT = @{ 'primer' = 1; 'primero' = 1; 'primera' = 1; 'segundo' = 2; 'segunda' = 2; 'tercer' = 3
                   'tercero' = 3; 'tercera' = 3; 'cuarto' = 4; 'cuarta' = 4; 'quinto' = 5; 'quinta' = 5 }

function Invoke-FastCommand([string]$text) {
    if (-not $cmds) { return $null }
    # EL JUEGO QUE TIENES DELANTE (15/09): jugando a It Takes Two, "busca informacion sobre el
    # juego que esta en pantalla" buscaba esa frase tal cual en Google.
    $reJuegoDelante = '(?i)\b(?:el juego (?:al )?que estoy jugando|el juego que (?:est[aá]|tengo) en (?:la )?pantalla|este juego)\b'
    if ($script:juegoActivo -and $text -match $reJuegoDelante) {
        $text = $text -replace $reJuegoDelante, [string]$script:juegoActivo
    }
    # EL JUEGO QUE SALE EN PANTALLA, SIN ESTAR JUGANDO (15/09): con la ficha de It Takes Two
    # abierta en Steam, "abre el juego que tengo en pantalla" acabo preguntando por Hollow
    # Knight. Se lee la pantalla (OCR) y se busca un juego de la biblioteca que salga ahi.
    if (-not $script:juegoActivo -and $text -match '(?i)\b(?:abre|abras|abrir|inicia|inicies|arranca|lanza|juega|pon)\b' -and
        $text -match '(?i)\b(?:(?:el )?juego que (?:tengo|est[aá]|sale|aparece|hay) en (?:la |mi )?pantalla|ese juego|el juego de la pantalla)\b') {
        $ocrJ = ''
        try { $ocrJ = Invoke-OCR (Save-Captura (Join-Path $TmpDir 'pantalla.png')) } catch { Log ("juego en pantalla: " + $_.Exception.Message) }
        $plOcr = ' ' + (ConvertTo-Plain $ocrJ) + ' '
        $jEnc = @(@($script:Juegos) | Where-Object { $_.nombre -and $plOcr.Contains(' ' + (ConvertTo-Plain ([string]$_.nombre)) + ' ') } |
                  Sort-Object { - ([string]$_.nombre).Length } | Select-Object -First 1)
        if ($jEnc.Count -gt 0) {
            Log "JUEGO EN PANTALLA: '$($jEnc[0].nombre)'"
            $text = "abre $($jEnc[0].nombre) en steam"
        } else {
            Log "JUEGO EN PANTALLA: no veo el nombre de ningun juego de la biblioteca"
        }
    }
    # ENSEÑARLE UNA SECUENCIA (ver New-RecetaEnsenada): "aprende que cuando diga
    # prepara la partida, abre discord y pon modo juego". Va antes que el dato
    # sobre ti y que el alias, que tambien empiezan por "aprende que".
    if ($text -match '(?i)^\s*(?:aprende|apr[eé]ndete|aprendete|recuerda)\s+que\s+(?:cuando|si)\s+(?:te\s+)?(?:diga|digo)\s+(.+)$') {
        $restoE = $Matches[1].Trim()
        $dispE = $null; $cuerpoE = $null
        # lo mas fiable: una coma o dos puntos entre la frase y lo que hay que hacer
        if ($restoE -match '^(.+?)\s*[,:]\s*(?:(?:tienes que|debes|hay que|quiero que|entonces)\s+)?(.+)$') {
            $dispE = $Matches[1]; $cuerpoE = $Matches[2]
        } elseif ($restoE -match ('(?i)^(.+?)\s+(?:(?:tienes que|debes|hay que|quiero que|entonces)\s+)?((?:' + $VERBOS + '|modo|activa|desactiva)\b.+)$')) {
            # sin coma: la frase acaba donde empieza la primera orden
            $dispE = $Matches[1]; $cuerpoE = $Matches[2]
        }
        if ($dispE -and $cuerpoE) { return (New-RecetaEnsenada $dispE $cuerpoE).texto }
        return "Dime la frase y lo que tengo que hacer, por ejemplo: aprende que cuando diga prepara la partida, abre discord y pon modo juego."
    }
    # CONTESTAR UN MENSAJE POR VOZ (13/09): "contestale que ya voy". Se escribe en
    # la app del ultimo mensaje que llego (Discord, WhatsApp...), SIN ENVIAR: Nova
    # no sabe si la conversacion abierta es la de quien te escribio, asi que lo
    # deja escrito y te pide que lo revises. Se lee del texto ORIGINAL (tildes).
    if ($text -match '(?i)^\s*(?:cont[eé]stale|resp[oó]ndele|escr[ií]bele)\s+(?:que\s+)?(.{2,300}?)[\s.]*$') {
        $respM = $Matches[1].Trim()
        $nM = $script:ultimaNotif
        if (-not $nM) { return "No tengo ningun mensaje reciente al que contestar." }
        $procM = Resolve-Proceso ([string]$nM.app)
        $ventM = if ($procM) { Get-Process -Name $procM.proceso -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 } else { $null }
        if (-not $ventM) { return "No encuentro $($nM.app) abierto para escribirle." }
        [AX]::ShowWindow($ventM.MainWindowHandle, 9) | Out-Null
        [void][AX]::ForceForeground($ventM.MainWindowHandle)
        Start-Sleep -Milliseconds 400
        if ([AX]::GetForegroundWindow() -ne $ventM.MainWindowHandle) { return "No pude poner $($nM.app) delante para escribir." }
        [System.Windows.Forms.SendKeys]::SendWait(([regex]::Replace($respM, '[+^%~(){}\[\]]', { param($mm) '{' + $mm.Value + '}' })))
        Log "CONTESTAR: escrito en $($nM.app), sin enviar"
        return "Lo he escrito en $($nM.app) sin enviar. Mira que sea la conversacion de $($nM.titulo) y dale a enviar."
    }
    # DONDE TE QUEDASTE (ver JUEGOS): "me quede en el jefe del castillo", "lo
    # dejo en el capitulo 3". Se lee del texto ORIGINAL, con sus mayusculas.
    # Sin un juego delante ni uno cerrado hace poco no hay de que juego
    # hablar: la frase sigue su camino.
    if ($text -match '(?i)^\s*(?:me\s+(?:he\s+)?qued[eé]|me\s+quedo|lo\s+dej[oeé])\s+(?:en|por)\s+(.{3,120}?)[\s.]*$') {
        $notaJ = $Matches[1].Trim()
        # mas estricto que "donde me quede": con el juego delante o cerrado hace
        # menos de 30 min, y sin lo que claramente no es una partida ("me quede
        # en casa"; revision del 13/09)
        $jr = if ($script:juegoActivo) { $script:juegoActivo }
              elseif ($script:ultimoJuego -and ($sw.ElapsedMilliseconds - $script:ultimoJuegoEn) -lt 1800000) { $script:ultimoJuego }
              else { $null }
        if ((ConvertTo-Plain $notaJ) -match '^(?:hoy|aqui|ahora|ya)$|^(?:(?:la |mi |el )?(?:casa|trabajo|escuela|colegio|clase|oficina|cama|calle|coche|carro)|dormid[oa]|sin (?:bateria|luz|internet))\b') { $jr = $null }
        if ($jr) {
            Set-NotaJuego $jr $notaJ
            Log "JUEGOS: nota para $jr -> $notaJ"
            return "Apuntado. En $jr te quedaste en $notaJ."
        }
    }
    # APRENDER UN DATO SOBRE TI (ver PERFIL): "aprende que mi carpeta de capturas
    # es D:\Capturas". Va ANTES que el alias de abajo, que tambien empieza por
    # "aprende que" y contestaria "no supe a que te refieres".
    if ($text -match '(?i)^\s*(?:aprende|apr[eé]ndete|aprendete|ten en cuenta|recuerda siempre|quiero que sepas)\s+que\s+((?:mi|mis|yo|me|a mi)\b.+)$') {
        $datoDicho = $Matches[1].Trim().TrimEnd('.')
        $guardado = Add-DatoPerfil ("Dicho por braya: " + $datoDicho) 'lo dijiste'
        if ($guardado) { return "Aprendido sobre ti: $datoDicho." }
        return "Eso ya lo sabia, o no es algo que guarde."
    }
    # OLVIDAR UN DATO: "olvida que mi juego favorito es..." (si no se parece a
    # ninguno, la frase sigue su camino: puede ser otra cosa)
    if ($text -match '(?i)^\s*(?:olvida|olv[ií]date de|borra)\s+(?:que|lo de)\s+(.+)$') {
        $quitado = Remove-DatoPerfil $Matches[1]
        if ($quitado) { return "Olvidado: " + ($quitado -replace '^Dicho por braya:\s*', '') + "." }
    }
    # aprender vocabulario hablando (se lee del texto ORIGINAL, sin normalizar)
    if ($text -match '(?i)^\s*aprende\s+que\s+(?:a\s+)?(.+?)\s+(?:le\s+(?:digo|llamo|dicen)|es|se\s+llama)\s+(.+)$') {
        $a = $Matches[1].Trim(); $b = $Matches[2].Trim()
        # "aprende que a spotify le digo musica" -> alias=musica, objetivo=spotify
        $r = Add-Alias-Comando $b $a
        if (-not $r) { $r = Add-Alias-Comando $a $b }   # o al reves
        if ($r) { return $r }
        return "No supe a que te refieres con eso"
    }
    # CREAR UN MODO HABLANDO. Tiene que ser aqui arriba, sobre la frase ENTERA:
    # "crea el modo streaming: cierra discord Y pon el volumen al 30" se parte
    # por esa "y" unas lineas mas abajo, y entonces ningun patron volveria a ver
    # el nombre del modo junto a sus ordenes.
    if ($text -match '(?i)^\s*(?:crea|crear|haz|hazme|define|guardame)\s+(?:el\s+|un\s+)?modo\s+([^\s:,]{2,20})\s*(?::|,|\s+que\s+|\s+con\s+|\s+)\s*(.+)$') {
        $nom = $Matches[1].Trim(); $cuerpo = $Matches[2].Trim()
        # Se COMPRUEBA que cada trozo se entienda ANTES de guardar nada: un modo
        # con una linea que no se reconoce es un modo que un dia hace la mitad de
        # lo que le pides y no dice por que.
        $lineas = @(); $malas = @()
        foreach ($fr in @(Split-Ordenes $cuerpo)) {
            if (-not $fr) { continue }
            if (Resolve-Fragment $fr) { $lineas += $fr } else { $malas += $fr }
        }
        if ($lineas.Count -eq 0) { return "No entendi ninguna de esas ordenes, asi que no he creado nada." }
        if (-not (Add-Perfil $nom $lineas)) { return "No pude guardar el modo." }
        $r = "Modo $nom creado, con $($lineas.Count) " + $(if ($lineas.Count -eq 1) { 'orden' } else { 'ordenes' }) + '.'
        if ($malas.Count -gt 0) { $r += " Esto no lo entendi y lo he dejado fuera: " + ($malas -join '; ') + '.' }
        return $r
    }
    # La memoria guarda el texto TAL CUAL se dijo, con mayusculas y acentos.
    # Si se dejara pasar por la normalizacion se archivaria en minusculas y sin
    # tildes, que es justo lo que no quieres leer meses despues en Obsidian.
    # mismo lookahead que en Resolve-Fragment: "en 20 minutos" es temporizador,
    # no una nota para el diario
    if ($text -match '(?i)^\s*(?:recu[eé]rdame|recuerda|acu[eé]rdate|anota|apunta|guarda(?=\s+(?:que|de\s+que)\b)|memoriza)\s+(?!.*\s(?:en|a)\s+(?:la\s+|mi\s+)?lista(?:\s+de\s+.+)?$)(?!(?:en|dentro de)\s+(?:\d+|un|una|uno|medi[ao]|(?:un\s+)?cuarto\s+de|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis\S+|veinte|veinti\S+|treinta|cuarenta|cincuenta|sesenta|noventa)(?:\s+y\s+\S+)?\s+(?:segundos?|minutos?|horas?)\b)(?!(?:\d+|un|una|medi[ao]|(?:un\s+)?cuarto\s+de|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis\S+|veinte|veinti\S+|treinta|cuarenta|cincuenta|sesenta|noventa)(?:\s+y\s+\S+)?\s+(?:minutos?|horas?)(?:\s+y\s+media)?\s+antes\b)(?!(?:esto|eso|esta pantalla|lo de la pantalla|lo que dice la pantalla|lo que pone|este codigo|el codigo|la clave|la combinacion|esta clave|este numero)$)(?!(?:hoy|ma[nñ]ana|pasado\s+ma[nñ]ana|el\s+(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)|el\s+\d{1,2}\s+de\s|a\s+las?\s)\b)(?!(?:cual|cuales|que es|que fue|si|donde|cuando|quien|como|cuanto)\b)(?:que\s+|de\s+que\s+)?(.+)$' -and $text -notmatch '\?\s*$') {
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
        # se cuenta para poder vigilarlo: es la defensa principal contra abrir
        # cosas solo, y conviene ver tanto si deja de saltar como si se pasa
        Add-Estadistica 'recitado' $text
        return $null
    }
    # CHARLA AL FINAL UNIDA CON "Y" (ver LAS DOS COSAS A LA VEZ): "que hora es y
    # cuentame algo curioso" no se partia y la cola se perdia (probado en vivo el
    # 13/09). Si la cola no es a su vez una orden conocida ("y dime la bateria"),
    # se aparta para la conversacion y se resuelve solo lo de delante.
    $colaCharla = ''
    if ($ConversacionOn -and $text -match '(?i)^(.+?)[\s,]+y\s+((?:cu[eé]ntame|dime|expl[ií]came|h[aá]blame|qu[eé] opinas|crees|sabes|recomi[eé]ndame|dame una idea)\b.+)$') {
        $delanteC = $Matches[1].Trim(); $colaC = $Matches[2].Trim()
        if (-not (Resolve-Fragment (ConvertTo-Plain $colaC))) { $colaCharla = $colaC; $text = $delanteC }
    }
    $frags = Split-Ordenes $text
    if (-not $frags -or $frags.Count -eq 0) { return $null }

    $script:dudosa = $null
    $script:charlaResto = ''
    $acciones = @()
    $restoCharla = @()
    foreach ($f in $frags) {
        $a = Resolve-Fragment $f
        if (-not $a) {
            # LAS DOS COSAS A LA VEZ (13/09): "abre spotify y cuentame algo de
            # musica". El trozo que no es orden pero parece charla o pregunta no
            # tumba lo demas: las ordenes se hacen y ese trozo va a la
            # conversacion (ver CONVERSACION DE VERDAD)
            if ($ConversacionOn -and ((Test-Charla $f) -or ((ConvertTo-Plain $f) -match $RE_PREGUNTA))) {
                $restoCharla += $f
                continue
            }
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
    # solo charla, sin ninguna orden: no es cosa de este atajo (Process-Texto la lleva)
    if ($acciones.Count -eq 0) { return $null }
    if ($colaCharla) { $restoCharla += $colaCharla }
    if ($restoCharla.Count -gt 0) {
        $script:charlaResto = ($restoCharla -join ', ')
        Log "LOCAL: hago las ordenes y '$($script:charlaResto)' va a la conversacion"
    }

    # --- CONFIRMACION DE COINCIDENCIAS DUDOSAS ---
    # Si algo se resolvio por parecido lejano, no se ejecuta: se devuelve la
    # pregunta y se deja la orden pendiente. El bucle principal la ejecuta si
    # dices "si" o si pasan unos segundos sin respuesta; "no" la cancela. Sin
    # estado pegajoso: el plazo la limpia sola.
    # YA ME DIJISTE QUE ESTO NO. La misma frase, otra vez: se pregunta en vez
    # de hacerla. Es la unica defensa contra lo que de verdad pasa -una frase
    # del video de fondo que la capa local entiende perfectamente-, porque ahi
    # no hay ninguna traduccion aprendida que borrar.
    if (-not $script:confirmado -and (Test-Rechazada $text)) {
        $script:pendiente = @{ texto = $text; vence = 0; tipo = 'rechazada' }
        $qr = @($acciones | ForEach-Object { $_.desc }) -join ' y '
        if (-not $qr) { $qr = $text }
        # $($var)? y no $var?: en PowerShell 5.1 la ? se come como parte del nombre
        # de la variable y la pregunta salia vacia (auditoria del 13/09)
        return "La ultima vez me dijiste que no era eso. ¿$($qr)?"
    }
    # ESTA VOZ NO ES LA TUYA. Solo para las ordenes que TOCAN algo: si el audio
    # de un video pregunta la hora, que la pregunte. Y solo se pregunta -nunca
    # se descarta-, porque el que habla raro puedes ser tu con la voz tomada, y
    # porque decir "si" o mantener el boton cuesta menos que quedarse sin
    # asistente. Si la frase ya venia confirmada, no se vuelve a preguntar.
    if (-not $script:confirmado -and (Test-VozExtrana) -and
        @($acciones | Where-Object { $AccionesQueTocan -contains $_.kind }).Count -gt 0) {
        $script:pendiente = @{ texto = $text; vence = 0; tipo = 'peligrosa' }
        $qv = @($acciones | ForEach-Object { $_.desc }) -join ' y '
        if (-not $qv) { $qv = $text }
        Log ("VOZ EXTRANA: $([int]$script:ultimaF0) Hz frente a $([int](Get-VozDuena)) Hz; se pregunta antes de: " + $qv)
        Add-Estadistica 'voz-extrana' $text
        return "No me suena tu voz. ¿$($qv)?"
    }
    # TRADUCCION DE ALGO MAL OIDO (15/09): "Ensectiva el modo noche" (dijo "desactiva") se
    # tradujo a "modo noche" y se hizo lo contrario de lo pedido. Si lo que se tradujo ya
    # necesito un repaso (ver NO APRENDER DE LO MAL OIDO), no se hace a la primera: se
    # pregunta, y como una peligrosa, solo vale un si hablado (ni el plazo ni el boton).
    if (-not $script:confirmado -and $script:preguntarTraduccion -and @($acciones).Count -gt 0) {
        $script:pendiente = @{ texto = $text; vence = 0; tipo = 'peligrosa' }
        $qd = @($acciones | ForEach-Object { $_.desc }) -join ' y '
        if (-not $qd) { $qd = $text }
        Log "OIDO DUDOSO: la traduccion sale de algo mal oido; se pregunta antes de: $qd"
        Add-Estadistica 'traduccion-preguntada' $text
        return "No estoy segura de haberte oido bien. ¿$($qd)?"
    }
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

    # QUE FRASE FUE. Para que "no era eso" sepa a que se refiere. No se apunta
    # la propia "no era eso", claro, ni "deshaz": eso dejaria sin referencia a
    # la siguiente queja.
    if (-not ($acciones | Where-Object { $_.kind -in @('noEraEso', 'deshacer', 'deshacerDesde') })) {
        $script:ultimoEjecutado = $text
    }

    # se guarda el estado ANTES de tocar nada, para poder deshacer
    $tocaEstado = @($acciones | Where-Object { $_.kind -in @('brillo', 'volumenPct', 'key', 'app') }).Count -gt 0
    if ($tocaEstado -and -not ($acciones | Where-Object { $_.kind -in @('deshacer', 'deshacerDesde') })) { Save-EstadoParaDeshacer }

    $hechas = @()
    $navegador = $null
    # Tras estas acciones hay que dar un respiro: son las que mandan teclas o
    # abren cosas, y si se encadenan sin pausa se pisan entre si (dos SendKeys
    # seguidos, o lanzar la URL antes de que el navegador exista). Las demas
    # -decir, anotar, consultar- no tocan nada de fuera y no necesitan nada.
    $RESPIRO = $AccionesQueTocan
    $acciones = @($acciones)
    for ($iAcc = 0; $iAcc -lt $acciones.Count; $iAcc++) {
        $a = $acciones[$iAcc]
        # ANTES de tocar nada: que se vea lo que viene, y por cual va
        Set-UIHaciendo $a.kind
        Set-UICola $acciones.Count ($iAcc + 1)
        try {
            switch ($a.kind) {
                # se sustituye la descripcion por el resultado real
                'deshacer' { $a.desc = (Invoke-Deshacer) }
                'deshacerDesde' { $a.desc = (Invoke-DeshacerDesde ([int]$a.minutos)) }
                'app' {
                    # ABRIR UN JUEGO MIENTRAS JUEGAS A OTRA COSA casi nunca es lo
                    # que pediste: es la firma de una orden mal oida. El 11/09 un
                    # ruido acabo abriendo SILENT BREATH en mitad de una partida.
                    # Se pregunta antes, igual que con 'cierra todos los programas'.
                    $esJuego = ($a.target -match 'steam://rungameid')
                    $comoSeLlama = ($a.desc -replace '^abrir\s+', '' -replace '\s+en Steam$', '')
                    if ($esJuego -and -not $script:confirmado -and ($script:juegoActivo -or $a.sinVerbo)) {
                        $script:pendiente = @{ texto = "abre $comoSeLlama en steam"; vence = 0; tipo = 'peligrosa' }
                        $a.desc = if ($script:juegoActivo) { "estas jugando a $($script:juegoActivo). ¿Abro $($comoSeLlama)?" }
                                  else { "¿Abro $($comoSeLlama)?" }
                    } else {
                        # con -PassThru para poder cerrarlo si pides deshacer; las
                        # URI (steam://, shell:appsFolder) no devuelven proceso propio
                        $pr = Start-Process $a.target -PassThru -ErrorAction Stop
                        # AVISO DE ACTUALIZACION (13/09): si Steam marca el juego con
                        # una actualizacion pendiente (StateFlags bit 2), se dice ya,
                        # antes de encontrarse la descarga al arrancar
                        if ($esJuego -and $a.target -match 'rungameid/(\d+)') {
                            $idAct = $Matches[1]
                            $jAct = @($script:Juegos | Where-Object { [string]$_.id -eq $idAct }) | Select-Object -First 1
                            if ($jAct -and ([int]$jAct.estado -band 2) -and -not $jAct.bajando) { $a.desc = "$($a.desc); ojo, tiene una actualizacion pendiente" }
                        }
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
                    $urlA = $a.url
                    if ($a.youtube) {
                        $nV = if ($a.videoN) { [int]$a.videoN } else { 1 }
                        $primerV = Get-PrimerVideoYouTube ([string]$a.youtube) $nV
                        if ($primerV) { $urlA = $primerV }
                        $script:ytUltimaBusqueda = [string]$a.youtube   # para "pon el segundo"
                    }
                    if ($a.carpeta) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $urlA + '"') -ErrorAction Stop }
                    elseif ($navegador) { Start-Process $navegador $urlA -ErrorAction Stop }
                    else { Start-Process $urlA -ErrorAction Stop }
                }
                'key' { for ($i = 0; $i -lt $a.repeat; $i++) { Send-Key $a.vk } }
                'brillo' { Set-Brillo $a.nivel }
                'memoria' { $null = Add-Memoria $a.texto }
                'modoEditar' { $a.desc = Invoke-ModoEditar $a.datos }
                'correo' { $a.desc = Invoke-Correo $a }
                'avisosEntorno' { $a.desc = Set-AvisosEntorno ([bool]$a.encendido) }
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
                'balanceAprendizaje' { $a.desc = (Get-BalanceAprendizaje) }
                'configuracion' { $a.desc = (Get-Configuracion) }
                'nivelNova' { $a.desc = Get-FraseNivel }
                'energia' {
                    if ($a.modo -eq 'consulta') {
                        $actualE = Get-ModoEnergia
                        $a.desc = if ($actualE) { "estoy en modo $actualE" } else { 'no pude leer el modo de energia' }
                    } else {
                        $okE = $false
                        try { $okE = Set-ModoEnergia $a.modo } catch { Log ("energia: " + $_.Exception.Message) }
                        $a.desc = if ($okE) { "modo $($a.modo) puesto" } else { 'Windows no me dejo cambiar el modo de energia' }
                    }
                }
                'radio' {
                    try { $a.desc = Set-Radio $a.tipo $a.encender } catch { $a.desc = "no pude cambiar el $($a.tipo)"; Log ("radio: " + $_.Exception.Message) }
                }
                'tiempoSemana' {
                    $listaJ = @(Get-TiempoJugado $a.dias)
                    $a.desc = if ($listaJ.Count -eq 0) { "$($a.periodo) no has jugado nada, o no te he visto" }
                              else {
                                  $trozosJ = @($listaJ | Select-Object -First 4 | ForEach-Object { "$($_.juego), $(Format-Minutos $_.minutos)" })
                                  $totalJ = 0; foreach ($x in $listaJ) { $totalJ += $x.minutos }
                                  "$($a.periodo) has jugado $(Format-Minutos $totalJ): " + ($trozosJ -join '; ')
                              }
                    $script:sinTarjeta = $true
                    $script:sinTarjetaEn = $sw.ElapsedMilliseconds
                }
                'salidaAudio' {
                    try {
                        if ($a.quiere) { $a.desc = Set-SalidaAudio $a.quiere }
                        else {
                            $actA = @(Get-SalidasAudio | Where-Object { $_.actual }) | Select-Object -First 1
                            $a.desc = if ($actA) { "suena por $($actA.nombre)" } else { 'no se por donde suena' }
                        }
                    } catch { $a.desc = 'no pude cambiar la salida de sonido'; Log ("salida de audio: " + $_.Exception.Message) }
                }
                'ultimaCaptura' {
                    $capU = Get-UltimaCaptura
                    if (-not $capU) {
                        $a.desc = 'no encuentro ninguna captura'
                    } elseif ($a.accion -eq 'abrir') {
                        try { Start-Process -FilePath $capU.FullName; $a.desc = 'ahi la tienes' } catch { $a.desc = 'no pude abrirla' }
                    } else {
                        try {
                            # desde memoria: con FromFile el archivo se queda bloqueado
                            $bytesU = [System.IO.File]::ReadAllBytes($capU.FullName)
                            $imgU = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, $bytesU)))
                            [System.Windows.Forms.Clipboard]::SetImage($imgU)
                            $hace = [int]((Get-Date) - $capU.LastWriteTime).TotalMinutes
                            $a.desc = 'copiada, lista para pegar' + $(if ($hace -ge 60) { " (es de hace $(Format-Minutos $hace))" } else { '' })
                        } catch { $a.desc = 'no pude copiarla'; Log ("ultima captura: " + $_.Exception.Message) }
                    }
                }
                'esconderTiempo' {
                    $script:uiRetirada = 'tiempo'
                    $script:retiradaHasta = $sw.ElapsedMilliseconds + [int]$a.minutos * 60000
                    Set-UI 'retirada'
                    # nunca vacia: una respuesta vacia se toma por "no lo entendi" y va a la IA
                    $a.desc = "vale, vuelvo en $(Format-Minutos ([int]$a.minutos))"
                }
                'vozVelocidad' {
                    $nuevaV = if ($a.paso -eq 0) { 0 } else { $script:vozVelocidad + [int]$a.paso }
                    Set-VozVelocidad $nuevaV
                    # solo si cambia: Set-Cfg reescribe config.json entero
                    if ([int](Get-Cfg 'voz' 'velocidad' 0) -ne $script:vozVelocidad) { [void](Set-Cfg 'voz' 'velocidad' $script:vozVelocidad) }
                    $a.desc = if ($script:vozVelocidad -eq 0) { 'vuelvo a mi velocidad normal' }
                              elseif ($a.paso -gt 0 -and $script:vozVelocidad -ge 45) { 'ya hablo lo mas rapido que se' }
                              elseif ($a.paso -lt 0 -and $script:vozVelocidad -le -30) { 'ya hablo lo mas despacio que se' }
                              elseif ($a.paso -gt 0) { 'hablo mas rapido' } else { 'hablo mas despacio' }
                }
                'foco' {
                    # MODO FOCO (13/09): un temporizador de tipo "foco" (el anillo de
                    # la capsula lo cuenta). Al vencer pregunta por el descanso.
                    for ($i = $script:temporizadores.Count - 1; $i -ge 0; $i--) { if ($script:temporizadores[$i].tipo -in 'foco', 'descanso') { $script:temporizadores.RemoveAt($i) } }
                    $msF = [int]$a.minutos * 60000
                    [void]$script:temporizadores.Add(@{ vence = $sw.ElapsedMilliseconds + $msF; texto = 'fin del foco'; total = $msF; tipo = 'foco' })
                    $a.desc = "foco de " + $(if ($a.minutos -eq 1) { 'un minuto' } else { "$($a.minutos) minutos" }) + "; te aviso al terminar"
                }
                'focoFin' {
                    $habia = 0
                    for ($i = $script:temporizadores.Count - 1; $i -ge 0; $i--) { if ($script:temporizadores[$i].tipo -in 'foco', 'descanso') { $script:temporizadores.RemoveAt($i); $habia++ } }
                    $a.desc = if ($habia -gt 0) { 'foco terminado' } else { 'no habia ningun foco en marcha' }
                }
                { $_ -in 'discordMicro', 'discordSordo' } {
                    if (-not (Get-Process Discord -ErrorAction SilentlyContinue)) {
                        $a.desc = 'Discord no esta abierto'
                    } else {
                        $comboD = if ($a.kind -eq 'discordMicro') { $DiscordTeclaMicro } else { $DiscordTeclaSordo }
                        try {
                            Send-Combinacion $comboD
                            $a.desc = if ($a.kind -eq 'discordMicro') { 'cambiado tu micro de Discord' } else { 'cambiado el ensordecer de Discord' }
                        } catch { $a.desc = "no pude pulsar el atajo de Discord: $($_.Exception.Message)" }
                    }
                }
                'portaAnterior' {
                    $a.desc = if ($script:portaHist.Count -ge 2) { 'antes copiaste: ' + (Get-Ojeada $script:portaHist[1]) }
                              else { 'no recuerdo nada copiado antes de lo ultimo' }
                }
                'pegarAnterior' {
                    if ($script:portaHist.Count -ge 2) {
                        $anterior = [string]$script:portaHist[1]
                        $puesto = $false
                        try { Set-Clipboard -Value $anterior; $puesto = $true } catch {}
                        if ($puesto) {
                            Watch-Portapapeles $anterior
                            Start-Sleep -Milliseconds 120
                            [System.Windows.Forms.SendKeys]::SendWait('^v')
                            $a.desc = 'pegado lo de antes'
                        } else { $a.desc = 'no pude tocar el portapapeles' }
                    } else { $a.desc = 'no recuerdo nada copiado antes de lo ultimo' }
                }
                'portaHistorial' {
                    $nH = $script:portaHist.Count
                    $a.desc = if ($nH -eq 0) { 'desde que estoy encendida no has copiado nada' }
                              else { "recuerdo ${nH}: " + ((@($script:portaHist | Select-Object -First 3) | ForEach-Object { Get-Ojeada $_ }) -join '; ') }
                    $script:sinTarjeta = $true
                    $script:sinTarjetaEn = $sw.ElapsedMilliseconds
                }
                'musicaPlay' {
                    $muP = Get-MusicaActual
                    if ($muP -and $muP.sonando -eq $a.sonar) {
                        $a.desc = if ($a.sonar) { 'ya esta sonando' } else { 'ya esta en pausa' }
                    } else {
                        Send-Key 0xB3
                        $a.desc = if ($a.sonar) { 'la pongo' } else { 'pausada' }
                    }
                }
                'musicaQue' {
                    $mu = Get-MusicaActual
                    $a.desc = if (-not $mu -or -not $mu.titulo) { 'ahora mismo no suena nada' }
                              elseif (-not $mu.sonando) { "esta en pausa: $($mu.titulo)" + $(if ($mu.artista) { ", de $($mu.artista)" } else { '' }) }
                              else { "suena $($mu.titulo)" + $(if ($mu.artista) { ", de $($mu.artista)" } else { '' }) }
                }
                'contactoImp' {
                    $lcI = Get-Contactos
                    switch ($a.accion) {
                        'poner' {
                            if ($lcI -notcontains $a.nombre) { [void]$lcI.Add($a.nombre); Save-Contactos }
                            $a.desc = "vale: si te escribe $($a.nombre) te aviso aunque estes jugando; los demas mensajes esperan"
                        }
                        'quitar' {
                            $fuera = @($lcI | Where-Object { $_ -eq $a.nombre })
                            foreach ($y in $fuera) { [void]$lcI.Remove($y) }
                            Save-Contactos
                            $a.desc = if ($fuera.Count -gt 0) { "quitado $($a.nombre)" } else { "$($a.nombre) no estaba entre los importantes" }
                        }
                        'ver' { $a.desc = if ($lcI.Count -gt 0) { 'tus contactos importantes: ' + ($lcI -join ', ') } else { 'no tienes contactos importantes; todos los mensajes avisan igual' } }
                    }
                }
                'brilloAuto' {
                    $hbB = Get-Habitos
                    $hbB.brilloAuto = [bool]$a.activar
                    Save-Habitos
                    $script:brilloAutoPuesto = -1
                    if ($a.activar) { Update-BrilloAuto; $a.desc = "brillo automatico activado: ahora al $(Get-BrilloPorHora (Get-Date).Hour) por ciento" }
                    else { $a.desc = 'brillo automatico desactivado' }
                }
                'notifResumen' {
                    if ($script:invitado) { $a.desc = 'en modo invitado no miro los mensajes'; break }
                    try { [void](Watch-Notificaciones @(Get-Notificaciones)) } catch {}
                    $a.desc = Get-ResumenNotificaciones
                }
                'notifLeer' {
                    if ($script:invitado) { $a.desc = 'en modo invitado no leo los mensajes'; break }
                    # MUCHOS MENSAJES (M9): el modelo LOCAL (nunca la API: son tus
                    # mensajes) los resume agrupados por persona o conversacion
                    $nPendL = @($script:notifPendientes).Count
                    if ($nPendL -ge 4 -and $ConversacionOn) {
                        $todosL = Get-LecturaNotificaciones 15
                        if (Send-Charla $todosL $false 'resumir') { $a.desc = "tienes $nPendL; te los resumo"; break }
                        $a.desc = $todosL
                    } else {
                        $a.desc = Get-LecturaNotificaciones
                    }
                    $script:sinTarjeta = $true   # para oirlo, no para una tarjeta
                    $script:sinTarjetaEn = $sw.ElapsedMilliseconds
                }
                'bateriaHasta' {
                    # BATERIA CON CONSEJO (13/09): cuanto falta hasta esa hora frente a
                    # lo que te dura (lo aprendido de ESTE juego, o lo que calcula
                    # Windows). Si no llega, pregunta si pone el modo ahorro.
                    $ahoraH = Get-Date
                    $objH = Get-Date -Hour ([Math]::Min(23, [int]$a.hora)) -Minute ([Math]::Min(59, [int]$a.minuto)) -Second 0
                    if ($objH -le $ahoraH -and [int]$a.hora -lt 12) { $objH = $objH.AddHours(12) }
                    if ($objH -le $ahoraH) { $objH = $objH.AddDays(1) }
                    $faltanH = [int][Math]::Ceiling(($objH - $ahoraH).TotalMinutes)
                    $dispH = if ($script:juegoActivo) { Get-DuracionBateriaJuego $script:juegoActivo } else { $null }
                    if (-not $dispH -and $script:bateriaMin -gt 0) { $dispH = [int]$script:bateriaMin }
                    $a.desc = if ($script:uiCargando -eq 1) { 'con el cargador puesto, sin problema' }
                              elseif (-not $dispH) { "todavia no se cuanto te dura; vas por el $($script:uiBateria) por ciento" }
                              elseif ($dispH -ge $faltanH) { "si: te quedan unas $(Format-Minutos $dispH) y necesitas $(Format-Minutos $faltanH)" }
                              else {
                                  $script:pendiente = @{ texto = ''; vence = 0; tipo = 'ahorroEnergia' }
                                  "no llegas: te quedan unas $(Format-Minutos $dispH) y necesitas $(Format-Minutos $faltanH). ¿Pongo el modo ahorro?"
                              }
                }
                'duracionBateria' {
                    $jB = $script:juegoActivo
                    $minJ = if ($jB) { Get-DuracionBateriaJuego $jB } else { $null }
                    $a.desc = if ($script:uiCargando -eq 1) { "el cargador esta puesto, asi que sin prisa ($($script:uiBateria) por ciento)" }
                              elseif ($minJ) { "con $jB, unas $(Format-Minutos $minJ) mas; vas por el $($script:uiBateria) por ciento" }
                              elseif ($jB -and $script:bateriaMin -gt 0) { "Windows calcula $(Format-Minutos $script:bateriaMin); lo que gasta $jB lo aprendo en cuanto juegues un rato sin cargador" }
                              elseif ($script:bateriaMin -gt 0) { "a este ritmo, unas $(Format-Minutos $script:bateriaMin); vas por el $($script:uiBateria) por ciento" }
                              else { Get-FraseBateria }
                }
                'dondeMeQuede' {
                    $mJ = Get-JuegosMem
                    $jr = $null
                    if ($a.juego) {
                        foreach ($k in $mJ.Keys) {
                            $pk = ConvertTo-Plain $k
                            if ($pk.Contains($a.juego) -or $a.juego.Contains($pk)) { $jr = $k; break }
                        }
                    }
                    if (-not $jr) { $jr = Get-JuegoDeReferencia }
                    if (-not $jr) {
                        # sin juego delante: la nota mas reciente, sea del juego que sea
                        $masReciente = ''
                        foreach ($k in $mJ.Keys) {
                            if ($mJ[$k]['nota'] -and [string]$mJ[$k]['notaFecha'] -gt $masReciente) { $masReciente = [string]$mJ[$k]['notaFecha']; $jr = $k }
                        }
                    }
                    $a.desc = if ($jr -and $mJ.ContainsKey($jr) -and $mJ[$jr]['nota']) {
                        "En $jr te quedaste en $($mJ[$jr]['nota']), $(Get-HaceCuanto ([string]$mJ[$jr]['notaFecha']))"
                    } elseif ($jr) { "no tengo apuntado donde te quedaste en $jr; dime: me quede en..." }
                    else { 'no tengo nada apuntado; mientras juegas, dime: me quede en...' }
                }
                'fijarTarjeta' {
                    if ($script:popupForm) {
                        $script:popupFijada = $true
                        $script:popupUntil = $sw.ElapsedMilliseconds + $PopupFijadaMs
                        $a.desc = 'la dejo ahi; di quitala cuando acabes'
                    } else {
                        $a.desc = 'no hay ninguna tarjeta abierta'
                    }
                }
                'quitarTarjeta' {
                    $a.desc = if ($script:popupForm) { 'quitada' } else { 'no habia ninguna tarjeta' }
                    Close-Popup
                }
                'verPerfil' {
                    $dp = @(Get-DatosPerfil)
                    $a.desc = if ($dp.Count -eq 0) { 'todavia no se nada de ti; se ira llenando solo, o dime: aprende que mi...' }
                              else { "se $($dp.Count) cosas de ti: " + ((@($dp | Select-Object -Last 6) | ForEach-Object { $_ -replace '^Dicho por braya:\s*', '' }) -join '; ') }
                }
                'verRecetas' {
                    $rsV = Get-Recetas
                    $a.desc = if ($rsV.Count -eq 0) { 'todavia no he aprendido ninguna tarea; cuando la IA haga algo por ti, la aprendere' }
                              else { "he aprendido $($rsV.Count): " + ((@($rsV) | Select-Object -Last 8 | ForEach-Object { ([string]$_.frase) -replace '\{[a-z_]+\}', 'algo' }) -join '; ') }
                    # y lo aprendido HABLANDO (el cerebro propio, M1)
                    $cerebroV = ''
                    try { $cerebroV = Get-BalanceCerebro } catch {}
                    if ($cerebroV) { $a.desc = if ($rsV.Count -eq 0) { $cerebroV } else { "$($a.desc). Y $cerebroV" } }
                }
                'olvidarReceta' {
                    $rsO = Get-Recetas
                    $objO = $null
                    if ($script:ultimaReceta) { $objO = @($rsO | Where-Object { $_.id -eq $script:ultimaReceta }) | Select-Object -First 1 }
                    if (-not $objO -and $rsO.Count -gt 0) { $objO = $rsO[$rsO.Count - 1] }
                    if ($objO) {
                        [void]$rsO.Remove($objO)
                        Save-Recetas
                        $script:ultimaReceta = $null
                        $a.desc = 'olvidada: ' + (([string]$objO.frase) -replace '\{[a-z_]+\}', 'algo')
                    } else {
                        $a.desc = 'no tengo ninguna receta que olvidar'
                    }
                }
                'noEraEso' {
                    # 1) deshacer lo que se hiciera
                    $r = Invoke-Deshacer
                    # 1b) y apuntar la frase, que es lo que evita que vuelva a
                    #     pasar cuando NO hay ninguna traduccion de por medio
                    $apuntada = $false
                    # si vino de una TRADUCCION, lo rechazado es tu frase original, no la
                    # orden normal a la que se tradujo: si no, "baja el volumen" pasaba a
                    # preguntar siempre (auditoria del 13/09)
                    $fraseRechazo = if ($script:ultimaAprendida) { [string]$script:ultimaAprendida } else { [string]$script:ultimoEjecutado }
                    if ($fraseRechazo) { $apuntada = Add-Rechazo $fraseRechazo }
                    # 2) y si la orden salio de una traduccion APRENDIDA, borrarla:
                    #    si no, volveria a equivocarse igual la proxima vez. Esto es
                    #    lo que convierte un "no era eso" en algo que sirve.
                    $olvidada = $null
                    if ($script:ultimaAprendida) {
                        $olvidada = $script:ultimaAprendida
                        [void](Remove-Traduccion $olvidada)   # sin [void] Nova decia "True"
                        $script:ultimaAprendida = ''
                    }
                    # 2b) y si lo ultimo fue una RECETA (usada o recien aprendida), fuera
                    $recetaOlvidada = $null
                    if ($script:ultimaReceta -and ($sw.ElapsedMilliseconds - $script:ultimaRecetaEn) -lt 180000) {
                        $gR = Get-Recetas
                        $objR = @($gR | Where-Object { $_.id -eq $script:ultimaReceta })
                        if ($objR.Count -gt 0) { [void]$gR.Remove($objR[0]); Save-Recetas; $recetaOlvidada = [string]$objR[0].frase }
                        $script:ultimaReceta = $null
                    }
                    $a.desc = if ($recetaOlvidada) { "$r. Y olvido esa receta." }
                              elseif ($olvidada) { "$r. Y olvido que '$olvidada' significaba eso." }
                              elseif ($apuntada) { "$r. Si lo vuelvo a oir, te pregunto antes." }
                              else { $r }
                }
                'verModos' {
                    $nn = @()
                    try { $nn = @($cmds.perfiles.PSObject.Properties.Name) } catch {}
                    $a.desc = if ($nn.Count -eq 0) { 'no tienes ningun modo' }
                              else { 'tienes ' + ($nn -join ', ') }
                }
                'verModo' {
                    $nom = ConvertTo-Plain $a.nombre
                    if (-not (Test-Prop $cmds.perfiles $nom)) {
                        $a.desc = "no tengo ningun modo que se llame $nom"
                    } else {
                        $a.desc = "el modo $nom hace: " + (@($cmds.perfiles.$nom) -join '; ')
                    }
                }
                'borrarModo' {
                    $nom = ConvertTo-Plain $a.nombre
                    if (-not (Test-Prop $cmds.perfiles $nom)) {
                        $a.desc = "no tengo ningun modo que se llame $nom"
                    } elseif (Remove-Perfil $nom) {
                        $a.desc = "modo $nom borrado"
                    } else {
                        $a.desc = 'no pude borrarlo'
                    }
                }
                'otroMonitor' {
                    # si solo hay una pantalla, mandar Win+Shift+Derecha es tirar
                    # la combinacion al vacio y quedarse callado como si valiera
                    $pantallas = 1
                    try { $pantallas = @([System.Windows.Forms.Screen]::AllScreens).Count } catch {}
                    if ($pantallas -lt 2) {
                        $a.desc = 'solo tienes una pantalla'
                    } else {
                        Send-WinShiftKey 0x27
                        $a.desc = 'al otro monitor'
                    }
                }
                'siempreEncima' {
                    $ya = $false
                    try { $ya = [AX]::EstaEncima() } catch {}
                    if ($ya -eq $a.encima) {
                        $a.desc = if ($a.encima) { 'ya estaba siempre encima' } else { 'no estaba siempre encima' }
                    } else {
                        $ok = $false
                        try { $ok = [AX]::SiempreEncima([bool]$a.encima) } catch {}
                        $a.desc = if (-not $ok) { 'no pude con esa ventana' }
                                  elseif ($a.encima) { 'siempre encima' }
                                  else { 'ya no esta siempre encima' }
                    }
                }
                'esquina' {
                    if ($script:esquina -eq $a.valor) {
                        $a.desc = 'ya estaba ahi'
                    } else {
                        $script:esquina = $a.valor
                        if (Set-Cfg 'ui' 'esquina' $a.valor) {
                            $a.desc = 'listo, y me acuerdo'
                        } else {
                            # se mueve igual: no poder guardarlo no es razon para
                            # no obedecer, pero se dice, que si no parece que si
                            $a.desc = 'me muevo, pero no he podido guardarlo para la proxima'
                        }
                        Refresh-UI
                    }
                }
                'colorUI' {
                    if ($script:uiColor -eq $a.valor) {
                        $a.desc = if ($a.valor) { "ya soy $($a.nombre)" } else { 'ya tengo mi color de siempre' }
                    } else {
                        $script:uiColor = $a.valor
                        $guardadoC = Set-Cfg 'ui' 'color' $a.valor
                        $a.desc = if ($a.valor) { "listo, ahora soy $($a.nombre)" } else { 'vuelvo a mi color de siempre' }
                        if (-not $guardadoC) { $a.desc += ', pero no he podido guardarlo para la proxima' }
                        Refresh-UI
                    }
                }
                'dondeEstas' {
                    $p = $script:esquina -split '-'
                    $a.desc = "estoy $($p[0]) a la $($p[1])"
                }
                'copiarRespuesta' {
                    $t = [string]$script:ultimaRespuesta
                    if (-not $t.Trim()) {
                        $a.desc = 'todavia no te he dicho nada'
                    } else {
                        $puesto = $false
                        try { Set-Clipboard -Value $t; $puesto = $true } catch {}
                        $a.desc = if ($puesto) { "copiado, $($t.Length) caracteres" }
                                  else { 'no pude tocar el portapapeles' }
                    }
                }
                'copiar' {
                    [System.Windows.Forms.SendKeys]::SendWait('^c')
                    # se espera a que la ventana de verdad copie: sin esta pausa
                    # se lee el portapapeles ANTERIOR y te dice una cosa por otra
                    Start-Sleep -Milliseconds 250
                    $t = Get-Portapapeles
                    $a.desc = if ($t) { 'copiado: ' + (Get-Ojeada $t) } else { 'copiado' }
                }
                'pegar' {
                    [System.Windows.Forms.SendKeys]::SendWait('^v')
                    $a.desc = 'pegado'
                }
                'queCopiado' {
                    $t = Get-Portapapeles
                    $a.desc = if ($t) { 'tienes copiado: ' + (Get-Ojeada $t) }
                              else { 'no tienes nada copiado' }
                }
                'apuntarCopiado' {
                    $t = Get-Portapapeles
                    if (-not $t) {
                        $a.desc = 'no tienes nada copiado'
                    } else {
                        $limpio = (($t -replace '[\r\n]+', ' / ') -replace '\s{2,}', ' ').Trim()
                        if ($limpio.Length -gt 600) { $limpio = $limpio.Substring(0, 600) + ' [...]' }
                        $null = Add-Memoria ("(copiado) " + $limpio)
                        # se lee el principio: asi sabes QUE guardo al momento
                        $a.desc = 'apuntado: ' + (Get-Ojeada $t)
                    }
                }
                'queFallo' {
                    $at = @(Get-Atragantos | Where-Object { $_.veces -ge 2 } | Select-Object -First 4)
                    if ($at.Count -eq 0) {
                        $a.desc = 'de lo que llevo apuntado, nada se me ha atragantado mas de una vez'
                    } else {
                        $partes = foreach ($x in $at) { "$($x.frase), $($x.veces) veces ($($x.rutas -join ' y '))" }
                        $a.desc = 'lo que mas se me atraganta: ' + ($partes -join '; ') +
                                  '. Si me dices "aprende que" y luego la frase y la orden buena, no vuelve a pasar.'
                    }
                }
                'tempoUno' {
                    $tpsU = @($script:temporizadores | Where-Object { $_.tipo -ne 'sordina' })
                    $queU = ((ConvertTo-Plain ([string]$a.que)) -replace '^(?:la|el|los|las)\s+', '').Trim()
                    $elegidos = if ($queU) { @($tpsU | Where-Object { (ConvertTo-Plain ([string]$_.texto)) -match [regex]::Escape($queU) }) } else { $tpsU }
                    if ($elegidos.Count -eq 0) {
                        $a.desc = if ($queU) { "no tengo ningun temporizador de $queU" } else { 'no tienes ningun temporizador' }
                    } elseif ($elegidos.Count -gt 1 -and -not $queU -and $a.accion -ne 'ver') {
                        $a.desc = "tienes $($elegidos.Count); dime cual, por ejemplo: pausa el temporizador de la pizza"
                    } else {
                        $tU = $elegidos[0]
                        switch ($a.accion) {
                            'ver' {
                                $restU = if ($tU.pausado) { [long]$tU.pausado } else { $tU.vence - $sw.ElapsedMilliseconds }
                                $minU = [int][Math]::Ceiling($restU / 60000.0)
                                $a.desc = $(if ($minU -le 1) { 'queda menos de un minuto' } else { "quedan $minU minutos" }) + $(if ($tU.pausado) { ', y esta en pausa' } else { '' })
                            }
                            'pausar' {
                                if ($tU.pausado) { $a.desc = 'ya estaba en pausa' }
                                else { $tU.pausado = [long]($tU.vence - $sw.ElapsedMilliseconds); $tU.vence = [long]::MaxValue; $a.desc = 'temporizador en pausa' }
                            }
                            'reanudar' {
                                if (-not $tU.pausado) { $a.desc = 'no estaba en pausa' }
                                else { $tU.vence = $sw.ElapsedMilliseconds + [long]$tU.pausado; $tU.Remove('pausado'); $a.desc = 'sigue contando' }
                            }
                            'cancelar' { [void]$script:temporizadores.Remove($tU); $a.desc = 'temporizador cancelado' }
                        }
                    }
                }
                'verTempo' {
                    # la sordina vive en esta misma lista y no es un aviso tuyo
                    $tps = @($script:temporizadores | Where-Object { $_.tipo -ne 'sordina' })
                    if ($tps.Count -eq 0) {
                        $a.desc = 'no tienes ningun temporizador'
                    } else {
                        $partes = @()
                        foreach ($tp in ($tps | Sort-Object { $_.vence })) {
                            $restoT = if ($tp.pausado) { [long]$tp.pausado } else { $tp.vence - $sw.ElapsedMilliseconds }
                            $queda = [int][Math]::Ceiling($restoT / 60000.0)
                            $cuanto = if ($queda -le 1) { 'menos de un minuto' } else { "$queda minutos" }
                            # sin el texto por defecto: "quedan 2 minutos para se acabo el tiempo"
                            $partes += if ($tp.texto -and $tp.texto -notin 'se acabo el tiempo', 'fin del foco', 'se acabo el descanso') { "$cuanto para $($tp.texto)" } else { "$cuanto" }
                        }
                        $a.desc = 'quedan ' + ($partes -join '; ')
                    }
                }
                'quitarTempo' {
                    $antes = 0
                    for ($i = $script:temporizadores.Count - 1; $i -ge 0; $i--) {
                        if ($script:temporizadores[$i].tipo -ne 'sordina') { $script:temporizadores.RemoveAt($i); $antes++ }
                    }
                    $a.desc = if ($antes -eq 0) { 'no tenias ninguno' }
                              elseif ($antes -eq 1) { 'temporizador cancelado' }
                              else { "$antes temporizadores cancelados" }
                }
                'descargas' {
                    $bajando = @($script:Juegos | Where-Object { $_.bajando })
                    if ($bajando.Count -eq 0) {
                        $a.desc = 'no hay ninguna descarga en marcha'
                    } else {
                        $partes = @()
                        foreach ($j in $bajando) {
                            $pct = [int](100.0 * $j.descargado / [Math]::Max(1, $j.total))
                            $falta = Format-Gigas ($j.total - $j.descargado)
                            $partes += "$($j.nombre), $pct por ciento, faltan $falta"
                        }
                        $a.desc = ($partes -join '; ')
                    }
                }
                'parte' { $a.desc = (Get-ParteGeneral) }
                'copiaSeguridad' {
                    $c = New-CopiaSeguridad 'lo pediste'
                    $a.desc = if ($c) { "hecha la copia: $($c.archivos) archivos guardados" } else { 'no pude hacer la copia, esta en el log' }
                }
                'queHeHecho' { $a.desc = (Get-QueHeHecho) }
                'listaAdd' {
                    $listas = Get-Listas
                    $cual = Resolve-Lista ([string]$a.lista) $listas
                    $items = @()
                    if ($listas.ContainsKey($cual)) { $items = @($listas[$cual]) }
                    $yaEsta = $false
                    foreach ($it in $items) { if ((ConvertTo-Plain $it) -eq (ConvertTo-Plain $a.cosa)) { $yaEsta = $true } }
                    if ($yaEsta) {
                        $a.desc = "$($a.cosa) ya estaba en la lista de $cual"
                    } else {
                        $items += [string]$a.cosa
                        $listas[$cual] = $items
                        if (Save-Listas $listas) {
                            $a.desc = "apuntado, en la lista de $cual llevas $(@($items).Count)"
                        } else {
                            $a.desc = "no pude guardar la lista"
                        }
                    }
                }
                'clipJuego' { $a.desc = Invoke-ClipJuego }
                'descargaJuego' { $a.desc = [string]$a.texto }
                'descargasAbrir' {
                    try {
                        Start-Process 'steam://open/downloads'
                        $a.desc = if ($a.pausar) { 'te abro las descargas de Steam; desde ahi se pausan' } else { 'abriendo las descargas de Steam' }
                    } catch { $a.desc = 'no pude abrir Steam' }
                }
                'amigosSteam' { $a.desc = Get-AmigosSteam }
                'amigosDiscord' { $a.desc = 'en Discord no puedo verlo: no deja mirarlo sin un bot' }
                'musicaAnterior' {
                    $cA = Get-CancionAnterior
                    $a.desc = if ($cA) { "era $($cA.t)" + $(if ($cA.a) { " de $($cA.a)" } else { '' }) } else { 'no tengo apuntada ninguna cancion todavia' }
                }
                'musicaDe' {
                    $cD = Find-CancionDe ([string]$a.cuando)
                    if (-not $cD) { $a.desc = "no tengo apuntado nada de $($a.cuando)" }
                    else {
                        try { Start-Process ('spotify:search:' + [Uri]::EscapeDataString(("$($cD.t) $($cD.a)").Trim())) } catch {}
                        $a.desc = "te busco en Spotify $($cD.t)" + $(if ($cD.a) { " de $($cD.a)" } else { '' })
                    }
                }
                'listaCopiar' {
                    $listasC = Get-Listas
                    $cualC = Resolve-Lista ([string]$a.lista) $listasC
                    if (-not $listasC.ContainsKey($cualC) -or @($listasC[$cualC]).Count -eq 0) { $a.desc = "no tienes nada en la lista de $cualC" }
                    else {
                        $textoC = "Lista de $($cualC):`r`n" + ((@($listasC[$cualC]) | ForEach-Object { "- $_" }) -join "`r`n")
                        $okC = $false
                        try { Set-Clipboard -Value $textoC; $okC = $true } catch {}
                        $a.desc = if ($okC) { "copiada la lista de $cualC, " + $(if (@($listasC[$cualC]).Count -eq 1) { 'una cosa' } else { "$(@($listasC[$cualC]).Count) cosas" }) + '; ya puedes pegarla' } else { 'no pude tocar el portapapeles' }
                    }
                }
                'listaVer' {
                    $listas = Get-Listas
                    $cual = Resolve-Lista ([string]$a.lista) $listas
                    if (-not $listas.ContainsKey($cual)) { $a.desc = "no tienes lista de $cual" }
                    else { $a.desc = Format-Lista $cual $listas[$cual] }
                }
                'listaCuales' {
                    $listas = Get-Listas
                    if ($listas.Keys.Count -eq 0) {
                        $a.desc = 'no tienes ninguna lista todavia'
                    } else {
                        $partes = @()
                        foreach ($k in $listas.Keys) { $partes += "$k (" + @($listas[$k]).Count + ")" }
                        $a.desc = 'tienes ' + ($partes -join ', ')
                    }
                }
                'listaQuitar' {
                    $listas = Get-Listas
                    $cual = Resolve-Lista ([string]$a.lista) $listas
                    if (-not $listas.ContainsKey($cual)) {
                        $a.desc = "no tienes lista de $cual"
                    } else {
                        $items = @($listas[$cual])
                        # sin articulo: se dice "quita los huevos" y en la lista
                        # pone "huevos". Comparar en crudo fallaba justo en lo
                        # mas normal que se puede decir.
                        $plano = (ConvertTo-Plain $a.cosa) -replace '^(?:el|la|los|las|un|una|unos|unas|mi|mis)\s+', ''
                        # "el primero" y "el ultimo" son lo que de verdad se dice
                        # cuando ya has leido la lista en voz alta
                        $quitar = -1
                        if ($plano -match '^(?:primero|primera|primer|uno|el uno)$') { $quitar = 0 }
                        elseif ($plano -match '^(?:ultimo|ultima|el ultimo)$') { $quitar = $items.Count - 1 }
                        else {
                            for ($k = 0; $k -lt $items.Count; $k++) {
                                $it = (ConvertTo-Plain $items[$k]) -replace '^(?:el|la|los|las|un|una|unos|unas|mi|mis)\s+', ''
                                if ($it -eq $plano) { $quitar = $k; break }
                            }
                            # y si no es exacto, que contenga: "quita el pan de molde"
                            if ($quitar -lt 0) {
                                for ($k = 0; $k -lt $items.Count; $k++) {
                                    if ((ConvertTo-Plain $items[$k]) -like "*$plano*") { $quitar = $k; break }
                                }
                            }
                        }
                        if ($quitar -lt 0 -or $quitar -ge $items.Count) {
                            $a.desc = "no encuentro $($a.cosa) en la lista de $cual"
                        } else {
                            $quitado = $items[$quitar]
                            $nuevos = @()
                            for ($k = 0; $k -lt $items.Count; $k++) { if ($k -ne $quitar) { $nuevos += $items[$k] } }
                            $listas[$cual] = $nuevos
                            $null = Save-Listas $listas
                            $a.desc = if (@($nuevos).Count -eq 0) { "tachado $quitado, y con eso se acaba la lista" }
                                      else { "tachado $quitado, quedan " + @($nuevos).Count }
                        }
                    }
                }
                'listaVaciar' {
                    $listas = Get-Listas
                    $cual = Resolve-Lista ([string]$a.lista) $listas
                    if (-not $listas.ContainsKey($cual) -or @($listas[$cual]).Count -eq 0) {
                        $a.desc = "la lista de $cual ya estaba vacia"
                    } elseif (-not $script:confirmado) {
                        # vaciar una lista de la compra a medio hacer es tan
                        # irreversible como cerrar un juego: se pregunta
                        $cuantos = @($listas[$cual]).Count
                        $script:pendiente = @{ texto = "borra la lista de $cual"; vence = 0; tipo = 'peligrosa' }
                        $a.desc = "en la lista de $cual hay $cuantos cosas. ¿La vacio?"
                    } else {
                        $listas.Remove($cual)
                        $null = Save-Listas $listas
                        $a.desc = "lista de $cual vaciada"
                    }
                }
                'dictadoLargo' {
                    # la que tenias TU delante al empezar a hablar, no la que
                    # tiene el foco ahora (que ya es la del asistente)
                    $script:dictadoVentana = $script:ventanaUsuario
                    # ...salvo que hayas dicho a cual: entonces se pone delante
                    if ($a.proceso) {
                        $pd = Get-Process -Name $a.proceso -ErrorAction SilentlyContinue |
                              Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
                        if (-not $pd -and $a.abrir) {
                            # no esta abierta: se abre. Decir "dicta en el bloc
                            # de notas" y que conteste "no esta abierta" es
                            # mandar al usuario a hacer a mano justo lo que
                            # acaba de pedir.
                            Log "DICTADO LARGO: $($a.proceso) no estaba abierta; la abro"
                            try { Start-Process $a.abrir -ErrorAction Stop } catch {
                                $a.desc = "$($a.desc): no pude abrirla"
                                break
                            }
                            # esperar a que aparezca la ventana, hasta 6 s: una
                            # app fria tarda, y sin ventana no hay donde dictar
                            for ($esp = 0; $esp -lt 30; $esp++) {
                                Start-Sleep -Milliseconds 200
                                $pd = Get-Process -Name $a.proceso -ErrorAction SilentlyContinue |
                                      Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
                                if ($pd) { break }
                            }
                        }
                        if (-not $pd) {
                            $a.desc = "$($a.desc): no esta abierta"
                            break
                        }
                        [void][AX]::ShowWindow($pd.MainWindowHandle, 9)   # por si estaba minimizada
                        [void][AX]::ForceForeground($pd.MainWindowHandle)
                        Start-Sleep -Milliseconds 200
                        $script:dictadoVentana = $pd.MainWindowHandle
                    }
                    # QUE VENTANA es, en el log: si algun dia el texto aparece
                    # donde no debe, este numero es lo unico que lo explica
                    Log ("DICTADO LARGO: escribire en la ventana " + $script:dictadoVentana)
                    $script:dictandoLargo = $true
                    $script:dictadoLargoHasta = $sw.ElapsedMilliseconds + $DictadoLargoMs
                    $script:dictadoUltimo = ''
                    $script:dictadoLineas = 0
                    $script:dictadoWinH = ($DictadoLargoMotor -eq 'windows')
                    Log "DICTADO LARGO: empieza (motor $DictadoLargoMotor, plazo $([int]($DictadoLargoMs / 60000)) min)"
                    if ($script:dictadoWinH) {
                        # NO se abre aqui: el asistente esta a punto de contestar
                        # en voz alta, y Win+H transcribiria su propia voz. Se
                        # deja pedido y lo abre el bucle en cuanto se calle.
                        $script:dictadoWinHPendiente = $true
                        $a.desc = 'voy, abro el dictado de Windows. Cuando acabes, manten el boton'
                    } else {
                        $a.desc = 'te escribo lo que digas en la ventana de delante. Para salir, di ya esta o manten el boton'
                    }
                }
                'escalaUI' {
                    $antes = [double]$script:uiEscala
                    if ([int]$a.paso -eq 0) {
                        $script:uiEscala = 1.0
                    } else {
                        # al escalon de al lado, no a un numero cualquiera: se
                        # busca el actual en la lista y se avanza uno
                        $i = 0
                        for ($k = 0; $k -lt $EscalasUI.Count; $k++) {
                            if ([Math]::Abs($EscalasUI[$k] - $antes) -lt 0.01) { $i = $k }
                        }
                        $i = [Math]::Max(0, [Math]::Min($EscalasUI.Count - 1, $i + [int]$a.paso))
                        $script:uiEscala = [double]$EscalasUI[$i]
                    }
                    if ([Math]::Abs($script:uiEscala - $antes) -lt 0.01) {
                        $a.desc = if ([int]$a.paso -gt 0) { 'ya estoy todo lo grande que puedo' }
                                  elseif ([int]$a.paso -lt 0) { 'ya estoy todo lo pequena que puedo' }
                                  else { 'ya estaba en el tamano de siempre' }
                    } else {
                        $pct = [int]($script:uiEscala * 100)
                        $guardado = Set-Cfg 'ui' 'escala' $script:uiEscala
                        $a.desc = if ($guardado) { "listo, al $pct por ciento, y me acuerdo" }
                                  else { "listo, al $pct por ciento, pero no he podido guardarlo para la proxima" }
                        Refresh-UI
                    }
                }
                'soloYo' {
                    $script:SoloYoOn = [bool]$a.valor
                    $guardado = Set-Cfg 'escucha' 'soloYo' ([bool]$a.valor)
                    $que = if ($a.valor) { 'a partir de ahora, si la voz no se parece a la tuya, pregunto antes de hacer nada' }
                           else { 'vale, hago caso a cualquiera' }
                    $a.desc = if ($guardado) { $que } else { "$que, pero no he podido guardarlo para la proxima" }
                }
                'quienSoy' {
                    $duena = Get-VozDuena
                    if (-not $SoloYoOn) {
                        $a.desc = 'ahora mismo hago caso a cualquiera; dime hazme caso solo a mi para cambiarlo'
                    } elseif ($duena -le 0) {
                        $a.desc = 'todavia no. Necesito oirte unas cuantas veces mas para saber cual es tu voz'
                    } else {
                        $t = "tu voz esta sobre los $([int]$duena) hercios"
                        if ($script:ultimaF0 -gt 0) {
                            $dif = [int][Math]::Abs($script:ultimaF0 - $duena)
                            $t += if ($dif -gt $SoloYoMargen) { ", y esto ultimo lo he oido a $([int]$script:ultimaF0): no me suena a ti" }
                                  else { ", y lo que acabas de decir encaja" }
                        }
                        $a.desc = $t
                    }
                }
                'disco' {
                    # la unidad donde estan los juegos, no siempre C:
                    $unidades = @('C')
                    try {
                        $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
                        if ($sp) { $u = ($sp -replace '/', '\').Substring(0, 1).ToUpper(); if ($unidades -notcontains $u) { $unidades += $u } }
                    } catch {}
                    $partes = @()
                    foreach ($u in $unidades) {
                        try {
                            $di = New-Object System.IO.DriveInfo($u)
                            if (-not $di.IsReady) { continue }
                            $libre = Format-Gigas $di.AvailableFreeSpace
                            $partes += "en $($u): $libre"
                        } catch {}
                    }
                    if ($partes.Count -eq 0) { $a.desc = 'no pude leer el disco' }
                    else { $a.desc = 'te quedan ' + ($partes -join ', ') }
                }
                'ultimaPartida' {
                    $j = $null
                    if ($a.que) { $j = Find-Juego $a.que }
                    if (-not $j) {
                        $a.desc = "no tengo ese juego en la biblioteca"
                    } else {
                        # el indice se lee al arrancar; para una fecha conviene
                        # refrescar, que es justo el dato que cambia al jugar
                        $null = Update-Juegos
                        $act = @($script:Juegos | Where-Object { $_.id -eq $j.id })
                        $lp = if ($act.Count -gt 0) { [long]$act[0].ultimo } else { [long]$j.ultimo }
                        $cuando = Format-Desde $lp
                        $a.desc = if ($cuando) { "jugaste a $($j.nombre) $cuando" } else { "no has jugado a $($j.nombre) todavia" }
                    }
                }
                'jugadoReciente' {
                    $null = Update-Juegos
                    $limite = [DateTimeOffset]::Now.AddDays(-8).ToUnixTimeSeconds()
                    $recientes = @($script:Juegos | Where-Object { [long]$_.ultimo -gt $limite } | Sort-Object { -[long]$_.ultimo })
                    if ($recientes.Count -eq 0) {
                        $a.desc = 'no has jugado a nada esta semana'
                    } else {
                        $partes = @()
                        foreach ($j in ($recientes | Select-Object -First 5)) {
                            $partes += "$($j.nombre) ($(Format-Desde ([long]$j.ultimo)))"
                        }
                        $a.desc = 'esta semana: ' + ($partes -join ', ')
                    }
                }
                'ocupa' {
                    $j = if ($a.que) { Find-Juego $a.que } else { $null }
                    if (-not $j) { $a.desc = "no tengo ese juego en la biblioteca" }
                    else {
                        $act = @($script:Juegos | Where-Object { $_.id -eq $j.id })
                        $tam = if ($act.Count -gt 0) { [double]$act[0].tamano } else { 0 }
                        $a.desc = if ($tam -gt 0) { "$($j.nombre) ocupa $(Format-Gigas $tam)" } else { "no se cuanto ocupa $($j.nombre)" }
                    }
                }
                'volumenApp' {
                    # el juego activo no tiene nombre de proceso fijo: se resuelve
                    # al vuelo desde el ejecutable que la capsula ya conoce
                    $pids = @()
                    if ($a.proceso -eq '*juego*') {
                        if (-not $script:juegoExe) {
                            $a.desc = 'no hay ningun juego abierto'
                            break
                        }
                        $pids = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { try { $_.Path -eq $script:juegoExe } catch { $false } } | ForEach-Object { $_.Id })
                    } else {
                        $pids = @(Get-Process -Name $a.proceso -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
                    }
                    if ($pids.Count -eq 0) {
                        $a.desc = "$($a.nombre) no esta abierto"
                    } else {
                        $hizo = $false
                        foreach ($pd in $pids) {
                            if ($a.silenciar) {
                                if ([AX]::SilenciarApp($pd, $true)) { $hizo = $true }
                            } elseif ($null -ne $a.pct) {
                                if ([AX]::PonerVolumenApp($pd, [int]$a.pct)) { $hizo = $true }
                            } else {
                                $v = [AX]::LeerVolumenApp($pd)
                                if ($v -ge 0) {
                                    $destino = [Math]::Max(0, [Math]::Min(100, $v + $(if ($a.sube) { 20 } else { -20 })))
                                    if ([AX]::PonerVolumenApp($pd, $destino)) { $hizo = $true; $a.desc = "$($a.nombre) al $destino por ciento" }
                                }
                            }
                        }
                        if (-not $hizo) { $a.desc = "$($a.nombre) no esta reproduciendo nada ahora mismo" }
                    }
                }
                'queSuena' {
                    $pids = @()
                    try { $pids = @([AX]::PidsConSonido()) } catch {}
                    $nombres = @()
                    foreach ($pd in $pids) {
                        try {
                            $pr = Get-Process -Id $pd -ErrorAction Stop
                            $n = $pr.ProcessName
                            # si es un juego de Steam, mejor su nombre de verdad
                            try {
                                if ($pr.Path -match '(?i)steamapps\\common\\([^\\]+)') {
                                    $j = Find-Juego $Matches[1]
                                    if ($j) { $n = $j.nombre }
                                }
                            } catch {}
                            if ($nombres -notcontains $n) { $nombres += $n }
                        } catch {}
                    }
                    $a.desc = if ($nombres.Count -eq 0) { 'ahora mismo no suena nada' }
                              else { 'suena ' + ($nombres -join ', ') }
                }
                'queJuego' {
                    $a.desc = if ($script:juegoActivo) { "estas jugando a $($script:juegoActivo)" } else { "no detecto ningun juego en primer plano" }
                }
                'winprt' { Send-WinKey 0x2C }        # Win+ImprPant: guarda en Imagenes\Capturas
                'winaltg' { Send-WinAlt 0x47 }       # Win+Alt+G: graba lo ultimo
                'volumenPct' {
                    # UNA llamada. Antes esto eran 50 pulsaciones de bajar y N de
                    # subir, con 30 ms entre cada una: ~2,5 s de tics de volumen
                    # sonando encima del juego para poner un simple 70 %.
                    # Si la API falla (dispositivo raro), se vuelve al metodo
                    # viejo: mas vale lento que no hacer nada.
                    $script:uiVolumen = [int]$a.pct
                    if (-not [AX]::PonerVolumen($a.pct)) {
                        Log "volumen: la API fallo, voy con las teclas"
                        for ($i = 0; $i -lt 50; $i++) { Send-Key 0xAE }
                        $pasos = [int][Math]::Round($a.pct / 2)
                        for ($i = 0; $i -lt $pasos; $i++) { Send-Key 0xAF }
                    }
                }
                'volumenRel' {
                    # subir o bajar un paso, pero con numero exacto y sin tics
                    $ahora = [AX]::LeerVolumen()
                    if ($ahora -lt 0) {
                        Send-Key $(if ($a.sube) { 0xAF } else { 0xAE })
                    } else {
                        $destino = [Math]::Max(0, [Math]::Min(100, $ahora + $a.paso))
                        [void][AX]::PonerVolumen($destino)
                        $script:uiVolumen = [int]$destino
                        $a.desc = "volumen al $destino por ciento"
                    }
                }
                'silencio' {
                    $m = [AX]::LeerSilencio()
                    $quiere = if ($null -ne $a.silencio) { [bool]$a.silencio } else { ($m -ne 1) }
                    if (-not [AX]::PonerSilencio($quiere)) { Send-Key 0xAD }
                    $a.desc = if ($quiere) { 'silencio' } else { 'sonido otra vez' }
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
                'esconder' { $script:uiRetirada = 'nombre'; Set-UI 'retirada' }
                'sordina' {
                    Pausar-Escucha $a.ms
                    $script:sordinaHasta = $sw.ElapsedMilliseconds + $a.ms
                    # el aviso de vuelta va por la via de los temporizadores, que
                    # ya sabe hablar sola cuando vence
                    [void]$script:temporizadores.Add(@{ vence = ($sw.ElapsedMilliseconds + $a.ms + 1500)
                                                        texto = 'Ya vuelvo a escucharte.'; total = $a.ms
                                                        tipo = 'sordina' })
                    Log "SORDINA: escucha apagada $([int]($a.ms / 60000)) min"
                }
                'cerrarTodo' {
                    $abiertas = @(Get-AppsAbiertas)
                    # EXCEPCIONES: "menos steam y discord". Cada una se resuelve a su
                    # proceso; si alguna no se sabe que es, NO se sigue: cerrar
                    # justo lo que querias conservar es el peor fallo de todos.
                    $excepto = if ((Test-Prop $a 'excepto') -or $a.ContainsKey('excepto')) { [string]$a.excepto } else { '' }
                    $noTocar = @()
                    $desconocida = ''
                    if ($excepto) {
                        foreach ($x in @($excepto -split '\s*(?:,|\by\b|\be\b)\s*' | Where-Object { $_ })) {
                            $px = Resolve-Proceso $x
                            if ($px -and $px.proceso -eq '*juego*' -and $script:juegoExe) { $noTocar += [System.IO.Path]::GetFileNameWithoutExtension($script:juegoExe) }
                            elseif ($px) { $noTocar += $px.proceso }
                            else { $desconocida = $x; break }
                        }
                    }
                    if ($desconocida) {
                        $a.desc = "no se que es '$desconocida', asi que no cierro nada"
                    } else {
                    if ($noTocar.Count -gt 0) { $abiertas = @($abiertas | Where-Object { $noTocar -notcontains $_.ProcessName }) }
                    # al confirmar se cierra LO QUE SE ANUNCIO, no lo que haya abierto
                    # en ese momento: lo que abras mientras contestas no entra
                    if ($script:confirmado -and $script:cerrarTodoPids) {
                        $abiertas = @($abiertas | Where-Object { $script:cerrarTodoPids -contains $_.Id })
                    }
                    if ($abiertas.Count -eq 0) {
                        $a.desc = 'no hay ningun programa abierto que cerrar'
                    } elseif (-not $script:confirmado) {
                        # Cerrar programas no se deshace, asi que NUNCA se hace a la
                        # primera: se dice en voz alta que se va a cerrar y se espera
                        # un si. El tipo 'peligrosa' hace ademas que callarse cancele,
                        # al reves que en el resto de confirmaciones.
                        $nombres = @($abiertas | ForEach-Object { if ($_.MainWindowTitle.Length -gt 40) { $_.ProcessName } else { $_.MainWindowTitle } } | Select-Object -Unique)
                        $script:cerrarTodoPids = @($abiertas | ForEach-Object { $_.Id })
                        $textoCT = if ($excepto) { "cierra todos los programas menos $excepto" } else { 'cierra todos los programas' }
                        $script:pendiente = @{ texto = $textoCT; vence = 0; tipo = 'peligrosa' }
                        $a.desc = 'voy a cerrar ' + $nombres.Count + ': ' + ($nombres -join ', ') + '. ¿Cierro?'
                    } else {
                        $script:cerrarTodoPids = $null
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
                    $script:sordinaHasta = 0
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
                        # UNA SOLA ESPERA PARA TODOS (15/09): "cierra el navegador" tardo 20 s. El
                        # navegador tiene muchos procesos sin ventana, CloseMainWindow da $false en
                        # cada uno y se esperaban 1,5 s por CADA uno. Ahora se pide cerrar a los que
                        # tienen ventana, se espera una vez (hasta 1,5 s) y se mata lo que siga. Si
                        # ninguno tiene ventana (en la bandeja), se mata como antes, sin esperar.
                        $conVentana = @($ps | Where-Object { try { $_.MainWindowHandle -ne [IntPtr]::Zero } catch { $false } })
                        if ($conVentana.Count -eq 0) {
                            foreach ($pr in $ps) { try { if (-not $pr.HasExited) { $pr.Kill() } } catch {} }
                        } else {
                            foreach ($pr in $conVentana) { try { [void]$pr.CloseMainWindow() } catch {} }
                            $hastaC = [DateTime]::Now.AddMilliseconds(1500)
                            while ([DateTime]::Now -lt $hastaC -and @($conVentana | Where-Object { try { -not $_.HasExited } catch { $false } }).Count -gt 0) {
                                Start-Sleep -Milliseconds 100
                            }
                            foreach ($pr in $conVentana) { try { if (-not $pr.HasExited) { $pr.Kill() } } catch {} }
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
                'ventanaApp' {
                    # NO se toca el foco en ningun caso: ShowWindow con
                    # SW_MINIMIZE / SW_MAXIMIZE / SW_RESTORE no activa la
                    # ventana, y para mover se usa SetWindowPos con NOACTIVATE.
                    # Todo el sentido de esto es no salir del juego.
                    $pv = Get-Process -Name $a.proceso -ErrorAction SilentlyContinue |
                          Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
                    if (-not $pv) {
                        $a.desc = "$($a.desc): no esta abierta"
                    } else {
                        $hw = $pv.MainWindowHandle
                        switch ($a.accion) {
                            'minimizar' { [void][AX]::ShowWindow($hw, 6) }    # SW_MINIMIZE
                            'maximizar' { [void][AX]::ShowWindow($hw, 3) }    # SW_MAXIMIZE
                            'restaurar' { [void][AX]::ShowWindow($hw, 9) }    # SW_RESTORE
                            'otroMonitor' {
                                $pantallas = @([System.Windows.Forms.Screen]::AllScreens)
                                if ($pantallas.Count -lt 2) {
                                    # decirlo, en vez de mover la ventana al vacio:
                                    # es el mismo criterio que "mandala al otro
                                    # monitor" sobre la ventana con foco
                                    $a.desc = 'solo tienes una pantalla'
                                } else {
                                    $r = New-Object AX+RECT
                                    if (-not [AX]::GetWindowRect($hw, [ref]$r)) {
                                        $a.desc = "$($a.desc): no pude leer donde esta"
                                    } else {
                                        # una ventana maximizada no se puede mover:
                                        # hay que restaurarla antes y volver a
                                        # maximizarla en la pantalla nueva
                                        $estabaMax = ($pv.MainWindowHandle -ne 0) -and ([AX]::GetWindowLong($hw, -16) -band 0x01000000)
                                        if ($estabaMax) { [void][AX]::ShowWindow($hw, 9); Start-Sleep -Milliseconds 120; [void][AX]::GetWindowRect($hw, [ref]$r) }
                                        $cx = ($r.Left + $r.Right) / 2; $cy = ($r.Top + $r.Bottom) / 2
                                        $actual = $pantallas | Where-Object { $_.Bounds.Contains([int]$cx, [int]$cy) } | Select-Object -First 1
                                        if (-not $actual) { $actual = $pantallas[0] }
                                        $i = [Array]::IndexOf($pantallas, $actual)
                                        $destino = $pantallas[($i + 1) % $pantallas.Count]
                                        # se conserva el tamano y la posicion RELATIVA
                                        # dentro de la pantalla: una ventana que
                                        # estaba arriba a la izquierda sigue estando
                                        # arriba a la izquierda en la otra
                                        $nx = $destino.WorkingArea.X + ($r.Left - $actual.WorkingArea.X)
                                        $ny = $destino.WorkingArea.Y + ($r.Top - $actual.WorkingArea.Y)
                                        $anchoV = $r.Right - $r.Left; $altoV = $r.Bottom - $r.Top
                                        # y que no se salga de la pantalla de destino
                                        $nx = [Math]::Max($destino.WorkingArea.X, [Math]::Min($nx, $destino.WorkingArea.Right - $anchoV))
                                        $ny = [Math]::Max($destino.WorkingArea.Y, [Math]::Min($ny, $destino.WorkingArea.Bottom - $altoV))
                                        $SWP_NOACTIVATE = 0x0010; $SWP_NOZORDER = 0x0004
                                        [void][AX]::SetWindowPos($hw, [IntPtr]::Zero, [int]$nx, [int]$ny, $anchoV, $altoV, ($SWP_NOACTIVATE -bor $SWP_NOZORDER))
                                        if ($estabaMax) { Start-Sleep -Milliseconds 120; [void][AX]::ShowWindow($hw, 3) }
                                    }
                                }
                            }
                        }
                    }
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
                        $trozo = Get-Trozo $texto 0
                        $script:lecturaPos = $trozo.fin
                        $a.desc = $trozo.texto + $(if ($trozo.fin -lt $texto.Length) { ' ... Di "sigue leyendo" para el resto.' } else { '' })
                    }
                }
                'seguirLeyendo' {
                    if (-not $script:ultimaLectura) {
                        $a.desc = 'no he leido nada todavia'
                    } elseif ($script:lecturaPos -ge $script:ultimaLectura.Length) {
                        $a.desc = 'ya no queda mas'
                    } else {
                        $trozo = Get-Trozo $script:ultimaLectura $script:lecturaPos
                        $script:lecturaPos = $trozo.fin
                        $a.desc = $trozo.texto + $(if ($trozo.fin -lt $script:ultimaLectura.Length) { ' ... y sigue.' } else { '' })
                    }
                }
                'ocrMemoria' {
                    Set-UI 'pensando' 'leyendo la pantalla'
                    $png = Join-Path $TmpDir 'pantalla.png'
                    Save-Captura $png | Out-Null
                    $texto = Invoke-OCR $png
                    if (-not $texto) {
                        $a.desc = 'No veo texto en la pantalla'
                    } else {
                        $script:ultimaLectura = $texto
                        # una pantalla viene en muchas lineas y en una nota de diario
                        # eso queda ilegible: se junta todo en una sola
                        $limpio = (($texto -replace '[\r\n]+', ' / ') -replace '\s{2,}', ' ').Trim()
                        if ($limpio.Length -gt 600) { $limpio = $limpio.Substring(0, 600) + ' [...]' }
                        # de donde salio: sin esto, meses despues es un texto
                        # huerfano en el diario y no hay forma de situarlo
                        $donde = if ($script:juegoActivo) { $script:juegoActivo } else { 'la pantalla' }
                        $null = Add-Memoria ("(de $donde) " + $limpio)
                        Log "OCR A MEMORIA ($donde): $limpio"
                        # se lee el principio: asi sabes QUE guardo, y si el OCR ha
                        # leido mal te enteras al momento y no meses despues
                        $ojo = if ($limpio.Length -gt 90) { $limpio.Substring(0, 90) + "..." } else { $limpio }
                        $a.desc = "Apuntado: $ojo"
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
            # que se vea CUAL fallo, no solo que algo fallo
            Set-UICola $acciones.Count ($iAcc + 1) $true
            Start-Sleep -Milliseconds 400
        }
        # solo si esta accion toco el sistema Y queda alguna por hacer
        if ($iAcc -lt ($acciones.Count - 1) -and $RESPIRO -contains $a.kind) {
            Start-Sleep -Milliseconds 250
        }
    }
    Set-UIHaciendo ''
    Set-UICola 0 0
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
# LOS WORKERS, CON pythonw (14/09): con python.exe cada uno abria su conhost.exe (una
# consola oculta, 3-5 procesos y ~40 MB medidos en vivo). pythonw no abre consola y
# las tuberias funcionan igual. Si no esta, se sigue con python.exe.
$PyWorker = $PyExe
try {
    $pyw = Join-Path (Split-Path -Parent $PyExe) 'pythonw.exe'
    if (Test-Path -LiteralPath $pyw) { $PyWorker = $pyw }
} catch {}
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
        # DE NOCHE, MAS BAJITO (13/09): de 22:00 a 7:00 la voz suena al 55 %. Solo
        # la voz en linea: Piper (el respaldo sin internet) va por SoundPlayer,
        # que no tiene volumen.
        $horaV = (Get-Date).Hour
        $script:reproductor.Volume = if ($horaV -ge 22 -or $horaV -lt 7) { 0.55 } else { 1.0 }
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
        $psi.FileName = $PyWorker
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

function Say-Online([string]$texto, [string]$emo = '') {
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
        # sin Start-Sleep (14/09): congelaba el bucle 2 s. El worker lee la frase de
        # la tuberia en cuanto arranca, y la espera de abajo ya tiene su plazo de 8 s
        if (-not (Initialize-Online)) { return $false }
    }
    try {
        # Bytes UTF-8 directos al flujo. .NET Framework no deja fijar la
        # codificacion de StandardInput y en la consola oculta usaba IBM850:
        # cada tilde o "¿" mataba al worker (surrogate en el md5). Verificado.
        # VOZ CON EMOCION (M6): "{emo:alegre} ..." o "{emo:suave} ...", lo entiende el worker
        $envioT = if ($emo) { "{emo:$emo} $texto" } else { $texto }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($envioT + "`n")
        $flujo = $script:ttsProc.StandardInput.BaseStream
        $t0Voz = $sw.ElapsedMilliseconds
        $flujo.Write($bytes, 0, $bytes.Length)
        $flujo.Flush()
        # con tope: si la red se cae, no se puede colgar el bucle para siempre
        $tarea = $script:ttsProc.StandardOutput.ReadLineAsync()
        # una respuesta larga tarda mas en sintetizarse: plazo segun lo largo (ver RESPUESTAS LARGAS ENTERAS)
        $plazoVoz = [int][Math]::Min(30000, 8000 + $texto.Length * 15)
        if (-not $tarea.Wait($plazoVoz)) { Log "voz online: sin respuesta en $([int]($plazoVoz / 1000)) s"; return $false }
        # lo que ESPERO el bucle a la voz (ver VOZ PREPARADA): una frase ya hecha tarda
        # ms; una nueva, ~1 s. Solo se apunta en charla, o el log se llenaria de esto
        if ($script:charlaEsperando -or $script:charlaFrases.Count -gt 0 -or $script:prepVozProc) {
            Log ("voz: frase " + $(if (($sw.ElapsedMilliseconds - $t0Voz) -lt 250) { 'ya preparada' } else { 'sintetizada al momento' }) + " ($($sw.ElapsedMilliseconds - $t0Voz) ms)")
        }
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
                $script:vozFinReal = $fin    # la charla encadena frases con esto
                # Max: una pausa mas larga ya puesta (la sordina) no se acorta (auditoria 13/09)
                # LA PAUSA REAL (14/09): pero la que puso Say con la cuenta de letras
                # (70 ms por letra + 1,2 s) si, o la escucha seguia sorda ~0,7 s de mas
                # en cada frase. Solo si nadie la ha tocado desde entonces.
                if ($script:pausaEstimadaVoz -gt 0 -and $script:pausaHasta -eq $script:pausaEstimadaVoz -and $script:sordinaHasta -le $sw.ElapsedMilliseconds) {
                    $script:pausaHasta = $fin
                } else {
                    $script:pausaHasta = [Math]::Max($script:pausaHasta, $fin)
                }
                $script:pausaEstimadaVoz = -1
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
        # sin Start-Sleep (14/09): la carga del modelo la cubre la espera del .wav (8 s)
        if (-not (Initialize-Piper)) { return $false }
    }
    try {
        $antes = @(Get-ChildItem -LiteralPath $PiperSalida -Filter *.wav -ErrorAction SilentlyContinue).Count
        # BYTES UTF-8 (14/09), como con la voz en linea: WriteLine usa la codificacion
        # de la consola y Piper recibia "bater?a est?". Medido con --debug: con UTF-8
        # sale "bateria" con el acento en la i y "esta" en la a; asi, "batera est".
        $bytesP = [System.Text.Encoding]::UTF8.GetBytes($texto + "`n")
        $script:piperProc.StandardInput.BaseStream.Write($bytesP, 0, $bytesP.Length)
        $script:piperProc.StandardInput.BaseStream.Flush()
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

# TILDES PARA LA VOZ (14/09). El codigo escribe sin tildes ("No te entendi",
# "bateria", "cancion") y la voz neuronal lee lo que ve: sin tilde, el acento
# puede caer donde no es. Solo palabras SIN otra lectura posible sin tilde ("esta",
# "mas", "si", "que" se quedan como estan: ahi la tilde cambia el significado).
# Las tildes se ponen con codigos de caracter: este archivo no lleva BOM y PS 5.1
# leeria mal una tilde escrita tal cual.
$script:TildesVoz = $null
function Add-TildesVoz([string]$s) {
    if (-not $s) { return $s }
    if (-not $script:TildesVoz) {
        $a = [char]0xE1; $e = [char]0xE9; $i = [char]0xED; $o = [char]0xF3; $u = [char]0xFA; $n = [char]0xF1
        $script:TildesVoz = [ordered]@{
            'entendi' = "entend$i"; 'aqui' = "aqu$i"; 'ahi' = "ah$i"; 'alli' = "all$i"; 'asi' = "as$i"
            'todavia' = "todav$i" + 'a'; 'despues' = "despu$e" + 's'; 'tambien' = "tambi$e" + 'n'; 'ademas' = "adem$a" + 's'
            'musica' = "m$u" + 'sica'; 'bateria' = "bater$i" + 'a'; 'cancion' = "canci$o" + 'n'; 'ultimo' = "$u" + 'ltimo'
            'ultima' = "$u" + 'ltima'; 'ultimos' = "$u" + 'ltimos'; 'rapido' = "r$a" + 'pido'; 'numero' = "n$u" + 'mero'
            'pagina' = "p$a" + 'gina'; 'dia' = "d$i" + 'a'; 'dias' = "d$i" + 'as'; 'podria' = "podr$i" + 'a'; 'habia' = "hab$i" + 'a'
            'tenia' = "ten$i" + 'a'; 'queria' = "quer$i" + 'a'; 'minimo' = "m$i" + 'nimo'; 'maximo' = "m$a" + 'ximo'
            'manana' = "ma$n" + 'ana'; 'segun' = "seg$u" + 'n'; 'algun' = "alg$u" + 'n'; 'ningun' = "ning$u" + 'n'
            'volvera' = "volver$a"; 'sera' = "ser$a"; 'estare' = "estar$e"; 'avisare' = "avisar$e"; 'recordare' = "recordar$e"
            'boton' = "bot$o" + 'n'; 'microfono' = "micr$o" + 'fono'; 'conexion' = "conexi$o" + 'n'; 'configuracion' = "configuraci$o" + 'n'
            'telefono' = "tel$e" + 'fono'; 'dificil' = "dif$i" + 'cil'; 'facil' = "f$a" + 'cil'
            'sabado' = "s$a" + 'bado'; 'miercoles' = "mi$e" + 'rcoles'; 'dificiles' = "dif$i" + 'ciles'; 'rapida' = "r$a" + 'pida'
        }
    }
    if (-not $script:TildesVozRe) {
        # UNA sola expresion para todas: se llama en cada frase y en cada tarjeta
        $script:TildesVozRe = New-Object System.Text.RegularExpressions.Regex(
            ('\b(?:' + (@($script:TildesVoz.Keys) -join '|') + ')\b'),
            ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Compiled))
    }
    # conserva la mayuscula inicial ("Ultimo" -> "Último")
    return $script:TildesVozRe.Replace($s, {
        param($m)
        $r = $script:TildesVoz[$m.Value.ToLowerInvariant()]
        if ($m.Value -ceq $m.Value.ToUpperInvariant()) { $r = $r.ToUpperInvariant() }
        elseif ([char]::IsUpper($m.Value[0])) { $r = $r.Substring(0, 1).ToUpperInvariant() + $r.Substring(1) }
        $r
    })
}

# El texto TAL CUAL llega a la voz: espacios, tildes y el corte a 300 letras. Aparte
# porque la voz preparada (Send-PrepVoz) tiene que pedir exactamente el mismo, o no
# acierta en la cache.
function Get-TextoVoz([string]$texto) {
    $t = Add-TildesVoz (($texto -replace '\s+', ' ').Trim())
    # RESPUESTAS LARGAS ENTERAS (15/09): con el tope en 300 letras la voz se callaba a
    # mitad de una respuesta del agente ("se corta y deja de hablar") mientras la tarjeta
    # ensenaba el resto. Ahora el tope es 1.200 letras, y la voz tiene mas plazo.
    if ($t.Length -gt 1200) {
        # POR EL FINAL DE UNA FRASE (14/09): cortar a secas dejaba la voz a mitad de
        # palabra. Se busca el ultimo punto; si no, el ultimo espacio.
        $corteV = $t.Substring(0, 1200).LastIndexOfAny([char[]]'.!?;')
        if ($corteV -lt 400) { $corteV = $t.Substring(0, 1200).LastIndexOf(' ') }
        $t = if ($corteV -gt 0) { $t.Substring(0, $corteV + 1).Trim() } else { $t.Substring(0, 1200) }
    }
    return $t
}

# VOZ PREPARADA (14/09). Una frase nueva tarda ~1 s en sintetizarse (medido: 0,99 s
# de media) y una ya hecha 2 ms. La charla llega frase a frase, pero cada una se
# sintetizaba al tocarle, con ~1 s de hueco entre frase y frase. Un segundo worker
# de voz, igual que el de siempre y con la misma cache, las va preparando en cuanto
# llegan; al decirlas ya estan hechas. Escribe con .part y renombra, asi que los
# dos pueden pedir la misma sin pisarse. Su salida no se lee: no hace falta.
$script:prepVozProc = $null
function Send-PrepVoz([string]$texto, [string]$emo = '') {
    if (-not $texto -or -not $script:ttsProc -or $script:ttsProc.HasExited) { return }
    try {
        if (-not $script:prepVozProc -or $script:prepVozProc.HasExited) {
            $psiP = New-Object System.Diagnostics.ProcessStartInfo
            $psiP.FileName = $PyWorker
            $psiP.Arguments = "-u `"$TtsWorker`" $VozOnlineNombre `"$VozCache`""
            $psiP.UseShellExecute = $false
            $psiP.RedirectStandardInput = $true
            $psiP.CreateNoWindow = $true
            $psiP.WorkingDirectory = $LogDir
            $script:prepVozProc = [System.Diagnostics.Process]::Start($psiP)
            try { $script:prepVozProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
            Log "voz preparada: worker PID=$($script:prepVozProc.Id)"
        }
        $script:prepVozUltima = $sw.ElapsedMilliseconds
        $envioP = if ($emo) { "{emo:$emo} $texto" } else { $texto }
        $bytesP = [System.Text.Encoding]::UTF8.GetBytes($envioP + "`n")
        $script:prepVozProc.StandardInput.BaseStream.Write($bytesP, 0, $bytesP.Length)
        $script:prepVozProc.StandardInput.BaseStream.Flush()
    } catch { Log ("voz preparada: " + $_.Exception.Message) }
}

# Habla sin bloquear el bucle: la sintesis tarda ~60 ms y Play() es asincrono.
function Say([string]$texto, [string]$emo = '') {
    if (-not $texto) { return }
    $script:vozFinReal = 0
    $t = Get-TextoVoz $texto
    if ($t.Length -eq 0) { return }
    # en una llamada no se habla: la capsula lo ensena y late (ver SILENCIO EN LLAMADAS)
    if (Test-EnLlamada) {
        try { Set-UI 'hablando' $t 5000; Send-UIEvento 'pulso:llamada' } catch {}
        return
    }
    # Silenciar la escucha mientras hablamos. La reproduccion es asincrona, asi
    # que se estima la duracion por longitud del texto (~70 ms por caracter) y
    # el bucle principal reanuda al vencer el plazo.
    try {
        $script:finVoz = $sw.ElapsedMilliseconds
        $estimado = [Math]::Min(90000, ($t.Length * 70) + 1200)
        $previaV = $script:pausaHasta
        Pausar-Escucha $estimado $t
        # si fue ESTA estimacion la que alargo la pausa, Say-Online la puede acortar
        # a la duracion real del audio (ver LA PAUSA REAL)
        $script:pausaEstimadaVoz = if ($script:pausaHasta -gt $previaV) { $script:pausaHasta } else { -1 }
        # la capsula muestra lo que se dice y vuelve al reposo al callar. El
        # audio se anade despues, cuando se sabe cual es (Say-Online).
        $script:uiAudio = ''
        Set-UI 'hablando' $t ([Math]::Max($estimado, 2500))
    } catch {}
    # cadena de respaldo: si la red falla, sigue habiendo voz
    if ($script:ttsProc) { if (Say-Online $t $emo) { return } }
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
$script:vozWinProc = $null
$script:vozWinCheck = 0
$script:vozWinIntentos = 0
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
# ULTIMO RECURSO (15/09): si ni el rapido ni el preciso entienden la orden, se repasa con
# este (~12 s). Vacio = desactivado. Ver Request-UltimoRecurso.
$WhisperUltimo = [string](Get-Cfg 'input' 'whisperModeloUltimo' 'large-v3-turbo')
# OJO (15/09): vacio se le pasa a la escucha como '-'. Con un argumento vacio Start-Process
# falla y la escucha NO arranca (paso al apagar turbo en uso real).
$MarcaDictar = Join-Path $TmpDir "dictar.flag"
# confirmacion por voz de coincidencias dudosas: el worker escucha si/no
$MarcaConfirmar = Join-Path $TmpDir "confirmar.flag"
$RutaConfirmacion = Join-Path $TmpDir "confirmacion.txt"
# vocabulario (apps, sitios, juegos) para que Whisper acierte los nombres
$RutaVocabulario = Join-Path $TmpDir "vocabulario.txt"
$RutaDictado = Join-Path $TmpDir "dictado.txt"
$RutaParcial = Join-Path $TmpDir "dictado-parcial.txt"
# la orden ya se entiende entera: la escucha cierra la frase antes (ver SILENCIO_FIN_LOTENGO)
$RutaLoTengo = Join-Path $TmpDir "lotengo.txt"
$RutaEstado = Join-Path $TmpDir "escucha-estado.txt"
# --- DICTADO CON EL MOTOR DE WINDOWS (el de Win+H, sin su ventana) ---
# Convive con Whisper en vez de sustituirlo: los dos oyen la misma orden y
# se prefiere lo que diga Windows SI dice algo. Esa API escucha el microfono
# ella misma y no acepta audio amplificado, asi que puede no oir este micro,
# que entra a 0.02-0.05; por eso viene apagado y por eso hay respaldo.
$VozWindowsOn = [bool](Get-Cfg 'input' 'vozWindows' $false)
$RutaDictadoWin = Join-Path $TmpDir "dictado-winrt.txt"
# Mientras hay un juego delante, la palabra de activacion se apaga y solo vale
# el boton. Es cuando mas molesta equivocarse -el 11/09 abrio un juego solo en
# mitad de una partida- y cuando el boton del mando esta mas a mano.
$MarcaSoloBoton = Join-Path $TmpDir "solo-boton.flag"
$SoloBotonEnJuego = [bool](Get-Cfg 'escucha' 'soloBotonEnJuego' $true)
# QUE SOLO TE OBEDEZCA A TI. El tono de cada orden dictada ya se estimaba y se
# guardaba (tmp\voces.json); nadie lo usaba para nada. Si la orden viene de una
# voz que no se parece a la tuya, no se ejecuta: se pregunta. Es la defensa que
# faltaba contra el audio de un video CON VOZ HUMANA, que es el unico ruido que
# los filtros de hoy no distinguen (no es voz sintetica ni ruido: es una voz de
# verdad diciendo palabras de verdad).
# El margen es ancho a proposito: tu propia voz se mueve al susurrar, al gritar
# o resfriado, y preguntar de mas es peor que no preguntar. Con 35 Hz, una voz
# de video a 230 Hz salta y tu mismo hablando algo mas agudo no.
$SoloYoOn = [bool](Get-Cfg 'escucha' 'soloYo' $true)
$InterrumpirOn = [bool](Get-Cfg 'escucha' 'interrumpir' $true)   # ver INTERRUMPIR A NOVA
$SoloYoMargen = [double](Get-Cfg 'escucha' 'soloYoMargenHz' 35)
$SoloYoMinimo = [int](Get-Cfg 'escucha' 'soloYoMinimo' 12)
$MarcaReintento = Join-Path $TmpDir "reintentar.flag"
# una orden ESCRITA en vez de dicha (tools\decir.ps1): para probar sin hablar
$RutaOrdenEscrita = Join-Path $TmpDir "orden-escrita.txt"
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
# Restos de peticiones al agente que se cancelaron a mitad (manteniendo el
# boton): el runner muere antes de borrar sus in-/out-/err-/raw- y se quedan
# ahi para siempre. Se barren los de hace mas de un dia, nunca los recientes,
# que pueden estar en uso ahora mismo.
# UNA SOLA NOVA, Y ANTES DE TOCAR tmp\ (auditoria del 13/09): el candado estaba
# mas abajo, asi que una segunda copia (la clave Run mas un arranque a mano)
# borraba las marcas de la que ya funcionaba -le quitaba la pausa mientras
# hablaba- y solo despues se daba cuenta de que sobraba.
$mutex = $null
if (-not $Probar) {
    $mutex = New-Object System.Threading.Mutex($false, "Local\VoiceAssistant")
    if (-not $mutex.WaitOne(0)) {
        Write-Output "VoiceAssistant ya esta ejecutandose."
        exit 0
    }
    # workers de una sesion anterior que se quedaron huerfanos (su asistente ya
    # no existe): siguen con el microfono y al arrancar habria dos escuchando
    try {
        foreach ($wo in @(Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
                          Where-Object { $_.CommandLine -and ($_.CommandLine -match 'wake_vosk\.py' -or $_.CommandLine -match 'tts_worker\.py') })) {
            if (-not (Get-Process -Id $wo.ProcessId -ErrorAction SilentlyContinue)) { continue }
            if (-not (Get-Process -Id $wo.ParentProcessId -ErrorAction SilentlyContinue)) {
                Stop-Process -Id $wo.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}
try {
    $limite = (Get-Date).AddDays(-1)
    $restos = @(Get-ChildItem -LiteralPath $TmpDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(?:in|out|err|raw)-[0-9a-f]{16,}' -and $_.LastWriteTime -lt $limite })
    # tampoco en el banco: podrian ser los de una orden VIVA del asistente
    if ($restos.Count -gt 0 -and -not $Probar) {
        $restos | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        Log "limpieza: $($restos.Count) restos de ordenes canceladas"
    }
} catch {}

# NO en el banco (-Probar): tmp\ es el MISMO que usa el asistente encendido, y
# borrarle las marcas le quitaba la pausa mientras hablaba (se oia a si mismo,
# 12/09 22:20) o le cancelaba un dictado o una confirmacion en curso.
foreach ($m in $(if ($Probar) { @() } else { @($MarcaPausa, $MarcaSoloBoton, $MarcaDictar, $MarcaConfirmar, $MarcaReintento, $MarcaWake) })) {
    if (Test-Path -LiteralPath $m) {
        Log "marca huerfana de la sesion anterior: $(Split-Path -Leaf $m)"
        try { Remove-Item -LiteralPath $m -Force -ErrorAction SilentlyContinue } catch {}
    }
}
$script:pausaHasta = 0

function Pausar-Escucha([int]$ms, [string]$voz = '') {
    try {
        # INTERRUMPIR A NOVA (M5): si la pausa es porque habla, la marca lleva lo que
        # dice. El worker escucha solo "espera", "para", "calla"... y descarta la
        # palabra si esta en la propia frase (sin eso se cortaria con su eco)
        $marcaTxt = if ($voz -and $InterrumpirOn) { 'voz:' + (ConvertTo-Plain $voz) } else { 'x' }
        [System.IO.File]::WriteAllText($MarcaPausa, $marcaTxt)
        $fin = $sw.ElapsedMilliseconds + $ms
        if ($fin -gt $script:pausaHasta) { $script:pausaHasta = $fin }
    } catch {}
}

function Reanudar-Escucha([switch]$Forzar) {
    # CON LA SORDINA PUESTA NO SE REANUDA (auditoria del 13/09): "no me escuches
    # media hora" se levantaba en cuanto Nova terminaba de decir "vale". Solo la
    # levanta quien lo pide a proposito (-Forzar: el dictado con el boton).
    if (-not $Forzar -and $script:sordinaHasta -gt $sw.ElapsedMilliseconds) { $script:pausaHasta = 0; return }
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
            # el worker vigila que este proceso siga vivo: si muere, sale y suelta
            # el microfono en vez de quedarse escuchando huerfano (auditoria 13/09)
            $env:NOVA_PID_PADRE = "$PID"
            $worker = Join-Path $LogDir "wake_vosk.py"
            if (-not (Test-Path -LiteralPath $worker)) { Log "WARN: falta wake_vosk.py"; return }
            # La confianza minima va TAMBIEN aqui: hasta ahora solo la recibia el
            # wake_worker.exe viejo, asi que el ajuste del config no hacia nada.
            $conf = $EscuchaConf.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            # EL STDERR DEL WORKER, A UN ARCHIVO. El 12/09 murio tres veces sin
            # dejar ni una linea (se lanzaba sin redirigir nada). Y lo que dejo
            # la vez anterior se pasa al log ANTES de relanzar, porque la
            # redireccion vacia el archivo justo cuando mas falta hace.
            $rutaErrWorker = Join-Path $TmpDir 'wake-err.log'
            try {
                if ((Test-Path -LiteralPath $rutaErrWorker) -and (Get-Item -LiteralPath $rutaErrWorker).Length -gt 0) {
                    $errViejo = ([System.IO.File]::ReadAllText($rutaErrWorker)).Trim()
                    if ($errViejo) { Log ("worker de escucha, su salida de error la vez anterior: " + $errViejo.Substring([Math]::Max(0, $errViejo.Length - 2000))) }
                }
            } catch {}
            $script:wakeProc = Start-Process -FilePath $PyWorker `
                -ArgumentList @('-u', $worker, $EscuchaNombre, $MarcaWake, $EventLog, $EscuchaGanancia,
                                $MarcaPausa, $MarcaDictar, $RutaDictado, $RutaParcial, $RutaNivel,
                                $MarcaConfirmar, $RutaConfirmacion, "$MotorDictado`:$WhisperModelo", $RutaVocabulario,
                                $conf, $MarcaReintento, $RutaReintento, $(if ($WhisperPreciso) { $WhisperPreciso } else { '-' }), $(if ($WhisperUltimo) { $WhisperUltimo } else { '-' })) `
                -WorkingDirectory $LogDir -WindowStyle Hidden -PassThru `
                -RedirectStandardError $rutaErrWorker
        } else {
            $worker = Join-Path $LogDir "wake_worker.exe"
            if (-not (Test-Path -LiteralPath $worker)) { Log "WARN: falta wake_worker.exe"; return }
            $conf = $EscuchaConf.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $script:wakeProc = Start-Process -FilePath $worker `
                -ArgumentList @($EscuchaNombre, $conf, $MarcaWake, $EventLog) `
                -WindowStyle Hidden -PassThru
        }
        $null = $script:wakeProc.Handle
        # el oido de Windows, si esta activado: otro proceso aparte, que mira
        # la MISMA marca de dictado y escribe en su propio archivo
        if ($VozWindowsOn) {
            $wv = Join-Path $LogDir "voz_windows.py"
            if (Test-Path -LiteralPath $wv) {
                try {
                    $script:vozWinProc = Start-Process -FilePath $PyWorker `
                        -ArgumentList @('-u', $wv, $MarcaDictar, $RutaDictadoWin, $EventLog, 'es-ES') `
                        -WorkingDirectory $LogDir -WindowStyle Hidden -PassThru
                    $null = $script:vozWinProc.Handle
                    try { $script:vozWinProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
                    Log "dictado de Windows ACTIVO (worker PID=$($script:vozWinProc.Id))"
                } catch { Log ("WARN: no arranco el dictado de Windows: " + $_.Exception.Message) }
            } else { Log "WARN: falta voz_windows.py" }
        }
        # Es un portatil de JUEGOS: la escucha nunca debe competir por CPU con
        # el juego en primer plano.
        try { $script:wakeProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
        $script:wakeDesde = $sw.ElapsedMilliseconds
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
# Cuando vence el si/no, en reloj de pared: la capsula dibuja la barra que se
# vacia con su propio reloj, sin reescribir el estado en cada tic. Se declara
# AQUI y no junto a $pendiente porque Set-UI se usa mucho antes: alli valdrian
# $null y el JSON saldria roto.
$script:confirmaFin = 0
$script:confirmaTotal = 0
$script:uiVoz = 0           # indice de la voz que dicto (por tono), 0 = la habitual
$script:ultimaF0 = 0        # tono de la ultima orden dictada, en Hz (0 = no se pudo medir)
$script:uiClima = ''        # emoji del tiempo: solo unos segundos cuando se pregunta
$script:uiClimaHasta = 0
$script:uiAnimo = 0         # -1..1 segun aciertos y errores de las ultimas 24 h
$script:uiHaciendo = ''     # QUE se esta ejecutando ahora mismo (glifo en la capsula)
$script:uiRemoto = $false   # "pensando" lo lleva la IA (violeta) y no Nova sola (ambar)
$script:sinTarjeta = $false # la proxima respuesta es para oirla: sin tarjeta grande (ver Show-Popup)
$script:sinTarjetaEn = 0
$script:respuestaSinTarjeta = $false   # la respuesta del cerebro que viene es para oirla
$script:notaJuegoPendiente = $null     # la respuesta que viene es donde te quedaste en este juego
$script:notaPorGrabar = $null          # el proximo seguimiento se guarda como nota de voz
$script:grabandoNota = $null           # ...y esta en marcha (ruta del WAV)
$script:traducirPorOir = $null         # el proximo seguimiento se oye en este idioma
$script:traduciendoVoz = $null         # ...y esta en marcha
$script:huecoPendiente = $null         # a una receta le falta un valor y se ha preguntado
$script:avisosAplazados = New-Object System.Collections.ArrayList   # avisos que llegaron mientras dictabas
$script:notifCheck = 0      # ultima vez que se miraron las notificaciones
$script:uiCola = ''         # "3/2" = tres cosas en esta orden, va por la segunda; "3/2!" = esa fallo
$script:uiDescarga = 0      # 0..1 de la descarga de Steam mas avanzada (anillo)

function ConvertTo-JsonTexto([string]$s) {
    $t = (($s -replace '[\r\n\t]+', ' ') -replace '\s+', ' ').Trim()
    return $t.Replace('\', '\\').Replace('"', '\"')
}

function Set-UI([string]$estado, [string]$texto = '', [int]$ms = 0) {
    if (-not $UiNuevaOn) { return }
    # ESCONDIDA: volver al reposo es volver a esconderse. Sin esto, la propia
    # respuesta ("me quito...") la sacaba y al callar se quedaba a la vista
    # (13/09). Hablar o escuchar si la ensenan un momento.
    if ($estado -eq 'reposo' -and $script:uiRetirada) { $estado = 'retirada' }
    $t = (($texto -replace '[\r\n\t]+', ' ') -replace '\s+', ' ').Trim()
    if ($t.Length -gt 140) { $t = $t.Substring(0, 137) + "..." }
    $script:uiEstado = $estado
    $script:uiTexto = $t
    # la marca de "lo lleva la IA" dura lo que dura el pensar: cualquier otro
    # estado (respuesta, error, reposo) la quita
    if ($estado -ne 'pensando') { $script:uiRemoto = $false }
    # temporizador mas proximo, en tiempo de reloj (ms Unix) para que la
    # capsula dibuje el anillo con su propio reloj sin que haya que reescribir
    $tFin = 0; $tTotal = 0; $tTipo = ''
    if ($script:temporizadores -and $script:temporizadores.Count -gt 0) {
        $prox = $null
        # los que estan en pausa no dibujan el anillo (su vence es infinito)
        foreach ($tp in $script:temporizadores) { if ($tp.pausado) { continue }; if ($null -eq $prox -or $tp.vence -lt $prox.vence) { $prox = $tp } }
        if ($prox) {
            $tFin = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() + ($prox.vence - $sw.ElapsedMilliseconds)
            $tTotal = $prox.total
            if ($prox.tipo) { $tTipo = [string]$prox.tipo }
        }
    }
    # EN QUE ESTADO ESTA EL OIDO. La capsula lo dibuja: sin esto, estar sorda y
    # estar escuchando se ven exactamente igual.
    $oido = 'palabra'
    if ($script:sordinaHasta -gt $sw.ElapsedMilliseconds) { $oido = 'sorda' }
    # "solo boton": la palabra esta apagada pero el boton sigue valiendo.
    # Pasa con un juego delante (marca solo-boton) o si el worker murio.
    elseif (Test-Path -LiteralPath $MarcaSoloBoton) { $oido = 'boton' }
    elseif ($EscuchaOn -and (-not $script:wakeProc -or $script:wakeProc.HasExited)) { $oido = 'boton' }
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
            ',"oido":"' + $oido + '","tempoTipo":"' + $tTipo + '"' +
            ',"haciendo":"' + $script:uiHaciendo + '"' +
            ',"remoto":"' + $(if ($script:uiRemoto -or $script:busy) { '1' } else { '0' }) + '"' +
            ',"musica":"' + $script:uiMusica + '"' +
            ',"peligrosa":"' + $(if ($script:pendiente -and $script:pendiente.tipo -eq 'peligrosa') { '1' } else { '0' }) + '"' +
            ',"madurez":"' + $script:uiMadurez + '"' +
            ',"tiempo":"' + $script:uiTiempo + '"' +
            ',"vol":"' + $script:uiVolumen + '"' +
            ',"cola":"' + $script:uiCola + '"' +
            ',"descarga":' + ([double]$script:uiDescarga).ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture) +
            ',"escala":' + ([double]$script:uiEscala * $(if ($script:uiDock -eq 1) { 1.25 } else { 1.0 })).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture) +
            ',"origen":"' + $script:uiOrigen + '"' +
            ',"color":"' + $script:uiColor + '"' +
            ',"confirmaFin":' + ([long]$script:confirmaFin) + ',"confirmaTotal":' + ([long]$script:confirmaTotal) +
            ',"esquina":"' + $script:esquina + '"' +
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
    # ACABA DE APRENDER ALGO: el "hecho" de siempre se convierte en la
    # celebracion. Hace falta porque la capsula lee UN evento por vuelta, y el
    # "hecho" que llega justo despues de aprender pisaria el gesto. La marca
    # caduca a los 10 s, para no celebrar a destiempo algo que no toca.
    if ($script:acabaDeAprender -and ($sw.ElapsedMilliseconds - $script:acabaDeAprenderEn) -gt 10000) { $script:acabaDeAprender = $false }
    if ($evento -eq 'hecho' -and $script:acabaDeAprender) { $evento = 'gesto:aprendido' }
    if ($evento -eq 'gesto:aprendido') { $script:acabaDeAprender = $false }
    # eco en el mando: lo que la capsula celebra, el mando lo hace sentir
    switch ($evento) {
        'hecho' { Start-Vibracion @(50, 60, 50) 18000 }
        'logro' { Start-Vibracion @(80, 60, 80, 60, 160) 26000 }
        'aviso' { Start-Vibracion @(120, 80, 120) 22000 }
        'gesto:aprendido' { Start-Vibracion @(40, 50, 40, 50, 110) 22000 }
        'gesto:sinia' { Start-Vibracion @(50, 60, 50) 18000 }
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

# QUE VA A HACER, ANTES DE HACERLO
# Cada accion que toca el sistema enciende un glifo en la capsula JUSTO ANTES de
# ejecutarse: la app, el altavoz, la ventana. Una forma se reconoce de un
# vistazo; leer el texto tarda mas que la accion en pasar, y para entonces ya no
# hay nada que cancelar. NO anade ninguna espera: el glifo se ve durante lo que
# tarde la accion y el respiro de 250 ms que la sigue. Las ordenes que solo
# CONSULTAN (la hora, a que juegas, que modos hay) no llevan glifo: no hay nada
# que cancelar y el parpadeo solo seria ruido.
$GlifosAccion = @{
    'app' = 'app'; 'url' = 'web'; 'buscarEquipo' = 'web'
    'volumenPct' = 'sonido'; 'volumenRel' = 'sonido'; 'volumenApp' = 'sonido'
    'silencio' = 'mudo'
    'brillo' = 'brillo'
    'key' = 'tecla'; 'atajo' = 'tecla'; 'winkey' = 'tecla'; 'winaltg' = 'tecla'; 'alttab' = 'tecla'
    'escribir' = 'escribir'
    'winprt' = 'captura'
    'otroMonitor' = 'ventana'; 'siempreEncima' = 'ventana'; 'esconder' = 'ventana'
    'enfocar' = 'ventana'; 'enfocarJuego' = 'ventana'
    'cerrarApp' = 'cerrar'; 'cerrarJuego' = 'cerrar'; 'cerrarTodo' = 'cerrar'; 'zombis' = 'cerrar'
    'lock' = 'bloqueo'
    'memoria' = 'nota'; 'ocrMemoria' = 'nota'; 'apuntarCopiado' = 'nota'
    'temporizador' = 'tiempo'; 'quitarTempo' = 'tiempo'
    'copiar' = 'copia'; 'pegar' = 'copia'; 'copiarRespuesta' = 'copia'
    'ocr' = 'pantalla'; 'seguirLeyendo' = 'pantalla'
    'deshacer' = 'deshacer'; 'deshacerDesde' = 'deshacer'; 'noEraEso' = 'deshacer'
}
# CUANTAS COSAS SON Y POR CUAL VA. "abre steam y pon modo juego" son dos; si
# falla la segunda, hasta ahora no habia forma de saber cual fue. Solo se manda
# cuando hay MAS DE UNA: para una sola, un punto suelto no dice nada.
function Set-UICola([int]$total, [int]$indice, [bool]$fallo = $false) {
    if (-not $UiNuevaOn) { return }
    $v = ''
    if ($total -gt 1) { $v = "$total/$indice" + $(if ($fallo) { '!' } else { '' }) }
    if ($v -eq $script:uiCola) { return }
    $script:uiCola = $v
    Refresh-UI
}

function Set-UIHaciendo([string]$kind) {
    if (-not $UiNuevaOn) { return }
    $g = ''
    if ($kind) { $g = [string]$GlifosAccion[$kind] }
    # solo se reescribe el estado si CAMBIA: dos teclas seguidas no valen dos
    # escrituras del JSON ni dos animaciones de entrada
    if ($g -eq $script:uiHaciendo) { return }
    $script:uiHaciendo = $g
    Refresh-UI
}

# AVISOS SIN VOZ
# Hasta ahora un aviso o te hablaba encima o no existia. Con un juego delante,
# que te hable es justo lo que no quieres; en sordina, le acabas de pedir
# silencio. Pero callar del todo es no enterarte. Asi que en esos casos el
# aviso se ve -tres pulsos de color en el borde de la capsula, con el texto
# puesto- y no suena.
# El aviso SIEMPRE aparece; lo unico que cambia es si ademas habla.
$AvisosSinVoz = [bool](Get-Cfg 'avisos' 'sinVoz' $true)
$AvisosSinVozEnJuego = [bool](Get-Cfg 'avisos' 'sinVozEnJuego' $true)
# SILENCIO EN LLAMADAS (13/09): si OTRA app esta usando el microfono (Discord,
# una llamada, una grabacion), Nova no habla: su voz se colaria en la llamada.
# Lo dice el registro de privacidad de Windows (LastUsedTimeStop = 0 mientras se
# usa). No cuentan el worker de escucha de Nova (python) ni el dictado de
# Windows. Se mira como mucho cada 3 s.
$script:llamadaVista = 0
$script:llamadaActiva = $false
function Test-EnLlamada {
    if (($sw.ElapsedMilliseconds - $script:llamadaVista) -lt 3000 -and $script:llamadaVista -gt 0) { return $script:llamadaActiva }
    $script:llamadaVista = $sw.ElapsedMilliseconds
    $activa = $false
    try {
        $raizM = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone'
        $claves = @(Get-ChildItem -LiteralPath $raizM -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath (Join-Path $raizM 'NonPackaged') -ErrorAction SilentlyContinue)
        foreach ($cl in $claves) {
            if ($cl.PSChildName -match '(?i)python|TextInputHost|MicrosoftWindows\.Client|voice-ctrl|^NonPackaged$') { continue }
            $pr = Get-ItemProperty -LiteralPath $cl.PSPath -ErrorAction SilentlyContinue
            if ($pr -and $null -ne $pr.LastUsedTimeStart -and [long]$pr.LastUsedTimeStop -eq 0) { $activa = $true; break }
        }
    } catch {}
    if ($activa -ne $script:llamadaActiva) { Log ("LLAMADA: " + $(if ($activa) { 'otra app usa el microfono; Nova se calla' } else { 'microfono libre; Nova vuelve a hablar' })) }
    $script:llamadaActiva = $activa
    return $activa
}
function Test-AvisoSinVoz {
    if (Test-EnLlamada) { return $true }
    if (-not $AvisosSinVoz) { return $false }
    # te callaste tu: no te hablo yo
    if ($script:sordinaHasta -gt $sw.ElapsedMilliseconds) { return $true }
    # con un juego delante, hablarte encima te saca de la partida
    if ($AvisosSinVozEnJuego -and $script:juegoActivo) { return $true }
    # y el modo silencio es exactamente esto
    if ($script:uiPerfil -eq 'silencio') { return $true }
    return $false
}

# Un aviso, por la puerta que toque. $tipo da el color del pulso: bateria,
# tiempo, descarga, recordatorio.
function Send-Aviso([string]$texto, [string]$tipo = '') {
    # MIENTRAS DICTAS, ESPERA (auditoria del 13/09): hablar encima de un dictado
    # pone la pausa y el worker tira tu audio. Se guarda y suena al terminar.
    if ($script:armed) {
        [void]$script:avisosAplazados.Add(@{ texto = $texto; tipo = $tipo })
        Log "aviso aplazado hasta que termines de dictar: $texto"
        return
    }
    Show-Popup $texto
    if (Test-AvisoSinVoz) {
        Send-UIEvento ("pulso:" + $tipo)
        Log "aviso SIN VOZ ($tipo): $texto"
    } else {
        Say $texto
        # una descarga terminada tiene su propio gesto: el salto con chispas (13/09)
        Send-UIEvento $(if ($tipo -eq 'descarga') { 'gesto:descargado' } else { 'aviso' })
    }
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

# lluvia / nieve / tormenta / '' : lo dibuja la capsula, muy de vez en cuando
$script:uiTiempo = ''
# el volumen que Nova acaba de poner: la capsula ensancha el halo al cambiar (13/09)
$script:uiVolumen = -1
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
        # EL CLIMA VIVO: la capsula deja caer una gota (o un copo) de vez en cuando
        $tiempoAntes = $script:uiTiempo
        $script:uiTiempo = if (($codigo -ge 51 -and $codigo -le 67) -or ($codigo -ge 80 -and $codigo -le 82)) { 'lluvia' }
                           elseif (($codigo -ge 71 -and $codigo -le 77) -or ($codigo -ge 85 -and $codigo -le 86)) { 'nieve' }
                           elseif ($codigo -ge 95) { 'tormenta' }
                           elseif ($codigo -le 1 -and -not $noche) { 'sol' } else { '' }
        if ($script:uiTiempo -ne $tiempoAntes) { Refresh-UI }
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
# --- COPIA DE SEGURIDAD DE LO APRENDIDO (idea 8) ---
# Traducciones, reglas, modos, alias, rechazos, listas, fechas, recordatorios,
# el diario y la voz del dueno: meses de ajustes repartidos en una docena de
# JSON que se reescriben enteros cada vez. Uno que se corte a medias (un
# apagon, la bateria a cero en mitad de un Set-Content) se lleva todo lo suyo
# sin avisar. Una copia al dia, sola, y otra cuando se pida; se guardan las 14
# ultimas, que con ~40 KB cada una no ocupan nada.
$CopiasDir = Join-Path $LogDir 'copias'
$CopiasMax = 14
function New-CopiaSeguridad([string]$motivo = 'a mano') {
    try {
        $origen = @($TraduccionesPath, (Join-Path $LogDir 'reglas.json'), $cmdsPath, $cfgPath, $MemoriaDir,
                    (Join-Path $TmpDir 'mi-voz.json')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        if ($origen.Count -eq 0) { Log "COPIA: no hay nada que copiar"; return $null }
        if (-not (Test-Path -LiteralPath $CopiasDir)) { New-Item -ItemType Directory -Path $CopiasDir -Force | Out-Null }
        $zip = Join-Path $CopiasDir ('lo-aprendido_' + (Get-Date -Format 'yyyy-MM-dd_HHmm') + '.zip')
        Compress-Archive -LiteralPath $origen -DestinationPath $zip -Force -ErrorAction Stop
        # las viejas fuera: el nombre lleva la fecha, asi que ordenar por nombre es ordenar por fecha
        Get-ChildItem -LiteralPath $CopiasDir -Filter 'lo-aprendido_*.zip' | Sort-Object Name -Descending |
            Select-Object -Skip $CopiasMax | Remove-Item -Force -ErrorAction SilentlyContinue
        $n = @($origen | ForEach-Object { if (Test-Path -LiteralPath $_ -PathType Container) { Get-ChildItem -LiteralPath $_ -Recurse -File } else { Get-Item -LiteralPath $_ } }).Count
        $kb = [int][Math]::Ceiling((Get-Item -LiteralPath $zip).Length / 1KB)
        Log "COPIA ($motivo): $n archivos, $kb KB -> $zip"
        # TAMBIEN EN ONEDRIVE (13/09): si el equipo tiene OneDrive, la misma copia
        # se deja en OneDrive\Nova\copias (las 14 ultimas), para no perderla si se
        # pierde la Ally. Si no hay OneDrive, no pasa nada.
        try {
            $odN = $env:OneDrive
            if ($odN -and (Test-Path -LiteralPath $odN)) {
                $destOD = Join-Path $odN 'Nova\copias'
                if (-not (Test-Path -LiteralPath $destOD)) { New-Item -ItemType Directory -Force -Path $destOD | Out-Null }
                Copy-Item -LiteralPath $zip -Destination $destOD -Force
                @(Get-ChildItem -LiteralPath $destOD -Filter 'lo-aprendido_*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip 14) |
                    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
                Log "COPIA: tambien en OneDrive ($destOD)"
            }
        } catch { Log ("COPIA: no pude dejarla en OneDrive: " + $_.Exception.Message) }
        return @{ ruta = $zip; archivos = $n; kb = $kb }
    } catch {
        Log ("COPIA fallida ($motivo): " + $_.Exception.Message)
        return $null
    }
}
# ¿Hace falta la copia del dia? Solo si la ultima tiene mas de 20 horas: asi
# reiniciar el asistente cinco veces no deja cinco copias iguales.
function Test-CopiaPendiente {
    if (-not (Test-Path -LiteralPath $CopiasDir)) { return $true }
    $ultima = Get-ChildItem -LiteralPath $CopiasDir -Filter 'lo-aprendido_*.zip' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $ultima) { return $true }
    return (((Get-Date) - $ultima.LastWriteTime).TotalHours -ge 20)
}

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
                [void]$script:reglas.Add(@{ id = [int]$r.id; tipo = [string]$r.tipo; valor = [string]$r.valor; accion = [string]$r.accion; ultima = [string]$r.ultima; cond = [string]$r.cond })
            }
        } catch { Save-Corrupto $ReglasPath 'reglas' }
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
            foreach ($k in 'id', 'tipo', 'valor', 'accion', 'ultima', 'cond') { $o | Add-Member -NotePropertyName $k -NotePropertyValue $x[$k] }
            $lista += $o
        }
        $json = if ($lista.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($lista) -Depth 4 }
        Write-Atomico $ReglasPath $json
    } catch { Log ("reglas: no pude guardar: " + $_.Exception.Message) }
}

# --- REGLAS SOBRE CUALQUIER APP (idea 5) ---
# Antes "cuando abra X" solo entendia juegos de Steam: "cuando abra Spotify,
# baja el juego al 40" contestaba "no conozco el juego". Ahora X puede ser
# cualquier app de commands.json. Si el nombre es EXACTAMENTE una app, gana la
# app (Spotify no debe acabar emparejado por parecido con un juego); si no, se
# prueba como juego y, por ultimo, como app por parecido.
function Resolve-SujetoRegla([string]$obj) {
    if ($cmds -and (Test-Prop $cmds.apps $obj)) { return @{ app = $true; nombre = $obj } }
    $j = Find-Juego $obj
    if ($j) { return @{ app = $false; nombre = $j.nombre } }
    $pr = Resolve-Proceso $obj
    if ($pr -and $pr.proceso -ne '*juego*') { return @{ app = $true; nombre = $pr.nombre } }
    return $null
}

# Vigila las apps que salen en alguna regla y dispara al CAMBIAR: de cerrada a
# abierta (appAbre) y al reves (appCierra). La primera mirada solo toma nota:
# si al arrancar el asistente Spotify ya estaba abierto, eso no es "abrirlo".
# Lo mismo con una regla recien creada: su app se apunta y dispara a la
# siguiente vez que cambie.
$script:appsCheck = 0
$script:appsVivas = @{}
function Watch-AppsReglas {
    $g = Get-Reglas
    $nombres = @($g | Where-Object { $_.tipo -eq 'appAbre' -or $_.tipo -eq 'appCierra' } | ForEach-Object { $_.valor } | Select-Object -Unique)
    if ($nombres.Count -eq 0) { $script:appsVivas = @{}; return }
    foreach ($n in $nombres) {
        $pr = Resolve-Proceso $n
        if (-not $pr -or $pr.proceso -eq '*juego*') { continue }
        $viva = [bool](Get-Process -Name $pr.proceso -ErrorAction SilentlyContinue)
        $antes = $script:appsVivas[$n]
        $script:appsVivas[$n] = $viva
        if ($null -eq $antes) { continue }
        if ($viva -and -not $antes) { Log "APP abierta: $n"; Invoke-Reglas 'appAbre' $n }
        elseif ($antes -and -not $viva) { Log "APP cerrada: $n"; Invoke-Reglas 'appCierra' $n }
    }
}

function Describe-Regla($r) {
    $cuando = switch ($r.tipo) {
        'juegoAbre' { if ($r.valor) { "cuando abras $($r.valor)" } else { 'cuando abras un juego' } }
        'juegoCierra' { if ($r.valor) { "cuando cierres $($r.valor)" } else { 'cuando cierres el juego' } }
        'appAbre' { "cuando abras $($r.valor)" }
        'appCierra' { "cuando cierres $($r.valor)" }
        'bateria' { "cuando la bateria baje del $($r.valor) por ciento" }
        'cargadorQuita' { 'cuando quites el cargador' }
        'cargadorPone' { 'cuando enchufes el cargador' }
        'dockPone' { 'cuando conectes el dock o una pantalla' }
        'cascosPone' { 'cuando te pongas los cascos' }
        'dockQuita' { 'cuando quites la pantalla' }
        'cascosQuita' { 'cuando te quites los cascos' }
        'bateriaLlena' { 'cuando termine de cargar' }
        'discoJuegos' { if ($r.valor -eq 'quita') { 'cuando quites el disco de los juegos' } else { 'cuando conectes el disco de los juegos' } }
        'mandoCoge' { 'cuando cojas el mando' }
        'disco' { "cuando queden menos de $($r.valor) gigas" }
        'descarga' { if ($r.valor) { "cuando termine de descargarse $($r.valor)" } else { 'cuando termine una descarga' } }
        'hora' { "todos los dias a las $($r.valor)" }
        'cada' { "cada $($r.valor) minutos" }
        default { $r.tipo }
    }
    return "$cuando" + $(if ($r.cond -eq 'noche') { ' y sea de noche' } elseif ($r.cond -eq 'dia') { ' y sea de dia' } else { '' }) + ", $($r.accion)" + $(if ($r.ultima -eq 'unavez') { ' (una sola vez)' } else { '' })
}

# Intenta interpretar la frase como regla. Devuelve la respuesta hablada, o
# $null si no es una regla.
function Invoke-ReglaVoz([string]$text) {
    $p = ConvertTo-Plain $text
    $g = Get-Reglas
    # REGLAS COMBINADAS (13/09): "cuando abra hades y sea de noche, pon modo noche".
    # La condicion se quita de la frase (el resto se entiende como siempre) y se
    # guarda aparte; al dispararse, se mira la hora (noche = de 20:00 a 7:00).
    $condR = ''
    if ($p -match '^cuando\s' -and $p -match '\s+(?:y\s+)?(?:solo\s+)?(?:(?:sea|es|este|estemos)\s+)?(?:de|por la|en la)\s+(noche|dia)\b') {
        $condR = $Matches[1]
        $p = ($p -replace '\s+(?:y\s+)?(?:solo\s+)?(?:(?:sea|es|este|estemos)\s+)?(?:de|por la|en la)\s+(?:noche|dia)\b', '').Trim()
    }
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
    # RECORDATORIO DE UN SOLO USO LIGADO A UNA APP (13/09): "recuerdame comprar la
    # expansion cuando abra hades" o "cuando abra hades recuerdame...". Es una regla
    # que lo dice la primera vez que abres eso, y se borra sola.
    # y el recordatorio de un solo uso al conectar el dock o ponerse los cascos (F8)
    $recDisp = $null; $recTxtD = $null
    $RE_DISP = '((?:conecte|conectes|enchufe|ponga)\s+(?:el\s+|la\s+)?(?:dock|base|tele|television|monitor|pantalla)|(?:me\s+)?(?:conecte|ponga)\s+(?:los\s+|mis\s+)?(?:cascos|auriculares|audifonos))'
    if ($p -match ('^(?:recuerdame|avisame)\s+(?:que\s+|de\s+)?(.+?)\s+cuando\s+' + $RE_DISP + '$')) { $recTxtD = $Matches[1]; $recDisp = $Matches[2] }
    elseif ($p -match ('^cuando\s+' + $RE_DISP + '\s*,?\s*(?:recuerdame|avisame)\s+(?:que\s+|de\s+)?(.+)$')) { $recDisp = $Matches[1]; $recTxtD = $Matches[2] }
    if ($recDisp -and $recTxtD) {
        $esCascos = ($recDisp -match 'cascos|auriculares|audifonos')
        $idD = 1; foreach ($x in $g) { if ($x.id -ge $idD) { $idD = $x.id + 1 } }
        $rDisp = @{ id = $idD; tipo = $(if ($esCascos) { 'cascosPone' } else { 'dockPone' }); valor = ''; accion = "di " + $recTxtD.Trim(); ultima = 'unavez' }
        [void]$g.Add($rDisp); Save-Reglas
        Log ("REGLA $idD guardada: " + (Describe-Regla $rDisp))
        return "Vale, te lo recuerdo cuando " + $(if ($esCascos) { 'te pongas los cascos.' } else { 'conectes el dock.' })
    }
    $recApp = $null; $recTexto = $null
    if ($p -match '^(?:recuerdame|avisame)\s+(?:que\s+|de\s+)?(.+?)\s+cuando\s+(?:abra|abras|abro|inicie|arranque|entre en|entre a|juegue a|juegue al|juegue)\s+(?:el\s+|la\s+|al\s+|a\s+)?(.+)$') {
        $recTexto = $Matches[1]; $recApp = $Matches[2]
    } elseif ($p -match '^cuando\s+(?:abra|abras|abro|inicie|arranque|entre en|entre a|juegue a|juegue al|juegue)\s+(?:el\s+|la\s+|al\s+|a\s+)?(.+?)\s*,?\s*(?:recuerdame|avisame)\s+(?:que\s+|de\s+)?(.+)$') {
        $recApp = $Matches[1]; $recTexto = $Matches[2]
    }
    if ($recApp -and $recTexto) {
        $sujR = Resolve-SujetoRegla $recApp.Trim()
        if (-not $sujR) { return "No conozco '$($recApp.Trim())': no es un juego instalado ni una app de las que se abrir." }
        $idR = 1; foreach ($x in $g) { if ($x.id -ge $idR) { $idR = $x.id + 1 } }
        $rR = @{ id = $idR; tipo = $(if ($sujR.app) { 'appAbre' } else { 'juegoAbre' }); valor = $sujR.nombre; accion = "di " + $recTexto.Trim(); ultima = 'unavez' }
        [void]$g.Add($rR); Save-Reglas
        Log ("REGLA $idR guardada: " + (Describe-Regla $rR))
        return "Vale, te lo recuerdo cuando abras $($sujR.nombre)."
    }
    $tipo = $null; $valor = ''; $accion = ''
    if ($p -match '^cuando\s+(?:se\s+)?(?:abra|abras|abro|inicie|arranque|empiece|entre a|entre en)\s+(?:el\s+|un\s+|cualquier\s+)?(.+?)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'juegoAbre'; $obj = $Matches[1].Trim(); $accion = $Matches[2].Trim()
        if ($obj -notmatch '^(?:juego|videojuego|algo|cualquier cosa)$') {
            $sujeto = Resolve-SujetoRegla $obj
            if (-not $sujeto) { return "No conozco '$obj': no es un juego instalado ni una app de las que se abrir." }
            if ($sujeto.app) { $tipo = 'appAbre' }
            $valor = $sujeto.nombre
        }
    }
    # DESCARGAS: "cuando termine de descargarse elden ring, abrelo"
    # Ojo con el orden: esta va ANTES que la de "cuando termine X" (cerrar un
    # juego), porque "cuando termine de descargarse X" tambien encaja alli y
    # se quedaria con ella.
    elseif ($p -match '^cuando\s+(?:se\s+)?(?:termine|acabe|complete)\s+(?:de\s+)?(?:descargar|bajar|instalar)(?:se)?\s*(?:el\s+|la\s+|un\s+)?(.*?)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame|abrelo|abrela|ejecutalo|lanzalo|inicialo|arrancalo|juegalo)\b.*)$') {
        $tipo = 'descarga'; $obj = $Matches[1].Trim(); $accion = $Matches[2].Trim()
        $valor = ''
        if ($obj -and $obj -notmatch '^(?:algo|cualquier cosa|lo que sea|juego|videojuego|el juego|descarga|la descarga)$') {
            $j = Find-Juego $obj
            if ($j) { $valor = $j.nombre } else { return "No conozco el juego '$obj'" }
        }
        # "abrelo" es la forma NATURAL aqui y no vale en ninguna otra regla, porque
        # en las demas no hay un "lo" evidente. Aqui si lo hay: el juego que acaba
        # de bajarse. Se traduce ya, que la accion se guarda como texto y luego la
        # ejecuta Invoke-FastCommand sin saber de que regla vino.
        if ($accion -match '^(?:abrelo|abrela|ejecutalo|lanzalo|inicialo|arrancalo|juegalo)$') {
            if (-not $valor) { return "Dime que juego: 'abrelo' no se a que se refiere si no nombras uno." }
            $accion = "abre $valor"
        }
    }
    # LA BATERIA LLENA: "cuando termine de cargar, avisame" (16/09).
    # OJO CON EL ORDEN, y esto lo cazo el banco: tiene que ir ANTES que la de cerrar un
    # juego ("cuando termine X"), porque esa se comia "cuando termine DE CARGAR" tomando
    # "de cargar" como nombre de juego, y contestaba "no conozco 'de cargar'". Es la
    # misma trampa que ya obligo a subir la de las descargas, unas lineas mas arriba.
    elseif ($p -match '^cuando\s+(?:(?:se\s+)?(?:termine|acabe)\s+de\s+cargar(?:se)?|(?:la\s+)?(?:bateria|pila)\s+(?:este|se\s+ponga)\s+(?:llena|cargada|al\s+(?:cien|100)(?:\s*(?:por ciento|%))?))\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'bateriaLlena'; $valor = ''; $accion = $Matches[1].Trim()
    }
    elseif ($p -match '^cuando\s+(?:se\s+)?(?:cierre|cierres|cierro|termine|acabe|salga de|salga del)\s+(?:el\s+|un\s+|cualquier\s+)?(.+?)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'juegoCierra'; $obj = $Matches[1].Trim(); $accion = $Matches[2].Trim()
        if ($obj -notmatch '^(?:juego|videojuego|algo|cualquier cosa)$') {
            $sujeto = Resolve-SujetoRegla $obj
            if (-not $sujeto) { return "No conozco '$obj': no es un juego instalado ni una app de las que se abrir." }
            if ($sujeto.app) { $tipo = 'appCierra' }
            $valor = $sujeto.nombre
        }
    }
    elseif ($p -match '^cuando\s+la\s+(?:bateria|pila)\s+(?:baje|este|llegue|caiga)\s+(?:del|al|a|por debajo del|por debajo de|de|menos del)\s+(\d{1,3})\s*(?:por ciento|%)?\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'bateria'; $valor = [string][int]$Matches[1]; $accion = $Matches[2].Trim()
    }
    # CARGADOR: "cuando quite el cargador pon el brillo al 30"
    elseif ($p -match '^cuando\s+(?:lo\s+|la\s+)?(?:quite|quites|desenchufe|desenchufes|saque|saques|desconecte|desconectes)\s+(?:el\s+)?(?:cargador|cable|corriente|enchufe)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'cargadorQuita'; $valor = ''; $accion = $Matches[1].Trim()
    }
    elseif ($p -match '^cuando\s+(?:lo\s+|la\s+)?(?:enchufe|enchufes|conecte|conectes|ponga|pongas)\s+(?:el\s+)?(?:cargador|cable|corriente|enchufe|a cargar)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'cargadorPone'; $valor = ''; $accion = $Matches[1].Trim()
    }
    # DOCK Y CASCOS (F8): "cuando conecte el dock pon modo tele", "cuando me ponga los cascos sube el volumen"
    elseif ($p -match '^cuando\s+(?:conecte|conectes|enchufe|enchufes|ponga|pongas)\s+(?:el\s+|la\s+)?(?:dock|base|tele|television|monitor|pantalla)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'dockPone'; $valor = ''; $accion = $Matches[1].Trim()
    }
    elseif ($p -match '^cuando\s+(?:me\s+)?(?:conecte|conectes|ponga|pongas)\s+(?:los\s+|mis\s+)?(?:cascos|auriculares|audifonos)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'cascosPone'; $valor = ''; $accion = $Matches[1].Trim()
    }
    # LOS SENSORES DE LAS 31 IDEAS, YA ENGANCHABLES (16/09). Hasta ahora Nova se
    # enteraba de todo esto y solo lo decia; no se podia colgar nada de ello.
    # "cuando quite el dock, pon el modo bateria"
    elseif ($p -match '^cuando\s+(?:lo\s+|la\s+)?(?:quite|quites|desconecte|desconectes|saque|saques|desenchufe|desenchufes)\s+(?:el\s+|la\s+)?(?:dock|base|tele|television|monitor|pantalla)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'dockQuita'; $valor = ''; $accion = $Matches[1].Trim()
    }
    # "cuando me quite los cascos, pausa"
    elseif ($p -match '^cuando\s+(?:me\s+)?(?:quite|quites|saque|saques)\s+(?:los\s+|mis\s+)?(?:cascos|auriculares|audifonos)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'cascosQuita'; $valor = ''; $accion = $Matches[1].Trim()
    }
    # "cuando conecte el disco de los juegos, di ya estan" (y al quitarlo).
    # El verbo decide: el mismo patron sirve para las dos, y el valor guarda cual.
    elseif ($p -match '^cuando\s+(conecte|conectes|enchufe|enchufes|ponga|pongas|quite|quites|desconecte|desconectes|saque|saques)\s+(?:el\s+)?disco(?:\s+(?:de\s+(?:los\s+)?juegos|externo|duro|de\s+fuera))?\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'discoJuegos'; $accion = $Matches[2].Trim()
        $valor = if ($Matches[1] -match '^(?:quite|quites|desconecte|desconectes|saque|saques)$') { 'quita' } else { 'pone' }
    }
    # "cuando coja el mando, pon el modo juego"
    elseif ($p -match '^cuando\s+(?:coja|cojas|agarre|agarres|use|uses|toque|toques|encienda|enciendas)\s+(?:el\s+)?(?:mando|control|joystick|gamepad|mandito)\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'mandoCoge'; $valor = ''; $accion = $Matches[1].Trim()
    }
    # DISCO: "cuando queden menos de 20 gigas avisame"
    elseif ($p -match '^cuando\s+(?:queden|quede|haya|tenga)\s+menos\s+de\s+(\d{1,4})\s*(?:gigas?|gb|g)\b\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        $tipo = 'disco'; $valor = [string][int]$Matches[1]; $accion = $Matches[2].Trim()
    }
    elseif ($p -match '^(?:todos los dias|cada dia|diariamente|siempre)?\s*a\s+las?\s+(\d{1,2}|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce)(?::(\d{2})|\s+y\s+media|\s+y\s+cuarto)?\s*(de la manana|de la tarde|de la noche|am|pm)?\s*,?\s*(?:entonces\s+)?((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
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
    elseif ($p -match '^cada\s+(\d+)\s*(minutos?|horas?)\s*,?\s*((?:' + $VERBOS + '|modo|activa|desactiva|bloquea|di|avisa|avisame)\b.*)$') {
        # los grupos se copian ANTES del -match de la unidad, que pisa $Matches:
        # con "horas" la accion salia $null y la regla no se creaba (auditoria 13/09)
        $n = [int]$Matches[1]; $unidadC = [string]$Matches[2]; $accionC = [string]$Matches[3]
        if ($unidadC -match '^hora') { $n *= 60 }
        if ($n -lt 1) { return "Cada cuanto tiempo? Necesito al menos un minuto." }
        $tipo = 'cada'; $valor = [string]$n; $accion = $accionC.Trim()
    }
    if (-not $tipo) { return $null }
    # "avisame" a secas no es una accion ejecutable, pero es lo que se dice.
    # Se convierte en un aviso hablado con el texto del propio disparador.
    if ($accion -match '^(?:avisa|avisame)$') {
        $queDecir = switch ($tipo) {
            'disco' { "queda poco espacio en el disco, menos de $valor gigas" }
            'descarga' { if ($valor) { "$valor ha terminado de descargarse" } else { 'ha terminado una descarga' } }
            'bateria' { "te queda poca bateria, menos del $valor por ciento" }
            'cargadorQuita' { 'has quitado el cargador' }
            'cargadorPone' { 'ya esta cargando' }
            'dockPone' { 'has conectado una pantalla' }
            'cascosPone' { 'te has puesto los cascos' }
            'dockQuita' { 'has quitado la pantalla' }
            'cascosQuita' { 'te has quitado los cascos' }
            'bateriaLlena' { 'ya esta cargada del todo' }
            'discoJuegos' { if ($valor -eq 'quita') { 'has quitado el disco de los juegos' } else { 'ya esta el disco de los juegos' } }
            'mandoCoge' { 'has cogido el mando' }
            'juegoAbre' { 'ya abriste el juego' }
            'juegoCierra' { 'ya cerraste el juego' }
            'appAbre' { "se abrio $valor" }
            'appCierra' { "se cerro $valor" }
            default { 'aviso' }
        }
        $accion = "di $queDecir"
    }
    if (-not (Test-FastCommand $accion)) { return "Entendi la condicion, pero no reconozco la accion '$accion'. Tiene que ser una orden que yo sepa hacer." }
    $id = 1; foreach ($x in $g) { if ($x.id -ge $id) { $id = $x.id + 1 } }
    $r = @{ id = $id; tipo = $tipo; valor = $valor; accion = $accion; ultima = ''; cond = $condR }
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
            'appAbre' { $dispara = ($r.valor -eq $dato) }
            'appCierra' { $dispara = ($r.valor -eq $dato) }
            'bateria' {
                $pct = [int]$dato
                if ($pct -le [int]$r.valor) { if ($r.ultima -ne 'baja') { $dispara = $true; $r.ultima = 'baja' } }
                elseif ($pct -gt ([int]$r.valor + 10)) { $r.ultima = '' }
            }
            'cargadorQuita' { $dispara = ($dato -eq 'quita') }
            'cargadorPone' { $dispara = ($dato -eq 'pone') }
            'dockPone' { $dispara = ($dato -eq 'pone') }
            'cascosPone' { $dispara = ($dato -eq 'pone') }
            'dockQuita' { $dispara = ($dato -eq 'quita') }
            'cascosQuita' { $dispara = ($dato -eq 'quita') }
            'bateriaLlena' { $dispara = ($dato -eq 'llena') }
            # sin valor vale cualquiera de las dos, por si alguien dice solo "el disco"
            'discoJuegos' { $dispara = (-not $r.valor -or $r.valor -eq $dato) }
            'mandoCoge' { $dispara = ($dato -eq 'coge') }
            'disco' {
                # igual que la bateria: solo al cruzar el umbral, y se rearma
                # cuando vuelve a haber holgura (5 gigas de margen)
                $gb = [double]$dato
                if ($gb -le [double]$r.valor) { if ($r.ultima -ne 'poco') { $dispara = $true; $r.ultima = 'poco' } }
                elseif ($gb -gt ([double]$r.valor + 5)) { $r.ultima = '' }
            }
            'descarga' { $dispara = (-not $r.valor -or $r.valor -eq $dato) }
            'hora' { if ($dato -eq $r.valor -and $r.ultima -ne $hoy) { $dispara = $true; $r.ultima = $hoy } }
            'cada' {
                $ult = 0; if ($r.ultima) { [double]::TryParse($r.ultima, [ref]$ult) | Out-Null }
                if (($sw.ElapsedMilliseconds - $ult) -ge ([int]$r.valor * 60000)) { $dispara = $true; $r.ultima = [string]$sw.ElapsedMilliseconds }
            }
        }
        if (-not $dispara) { continue }
        # la condicion de una regla combinada (ver REGLAS COMBINADAS)
        if ($r.cond) {
            $horaC = (Get-Date).Hour
            $esNocheC = ($horaC -ge 20 -or $horaC -lt 7)
            if (($r.cond -eq 'noche' -and -not $esNocheC) -or ($r.cond -eq 'dia' -and $esNocheC)) { continue }
        }
        Log ("REGLA $($r.id) dispara: " + (Describe-Regla $r))
        $script:confirmado = $true
        $res = $null
        try { $res = Invoke-FastCommand $r.accion } catch { $res = $null } finally { $script:confirmado = $false }
        $unaVez = ($r.ultima -eq 'unavez' -and $tipo -in @('appAbre', 'juegoAbre', 'dockPone', 'cascosPone'))
        if ($res) { Send-UIEvento 'hecho'; Say ($(if ($unaVez) { 'Recuerda' } else { "Regla $($r.id)" }) + ": $res") } else { Log "REGLA $($r.id): la accion no se pudo ejecutar" }
        # un recordatorio de un solo uso se borra al cumplirse (ver Invoke-ReglaVoz)
        if ($unaVez) { [void]$g.Remove($r); Save-Reglas; Log "REGLA $($r.id): era de un solo uso, borrada" }
    }
    if ($tipo -in @('bateria', 'hora', 'cada', 'disco')) { Save-Reglas }
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
        Write-Atomico $FechasPath (ConvertTo-Json -InputObject @($lista) -Depth 3)
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
    Write-Atomico $RecordatoriosPath $json
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
    # AVISO ANTES DE UNA HORA (idea 6): "avisame diez minutos antes de las
    # diez", "recuerdame media hora antes de las ocho que empieza la partida".
    # Habia "a las diez" y habia "en veinte minutos", pero no lo que de verdad
    # se pide antes de una partida. Va DESPUES del dia ("manana diez minutos
    # antes de las diez") y ANTES de la hora, que se lee igual que siempre.
    $antesMin = 0
    if ($resto -match '^(.+?)\s+(minutos?|horas?)(\s+y\s+media)?\s+antes(?:\s+(?:de\s+)?(.+))?$') {
        $cantA = $Matches[1].Trim(); $unidadA = $Matches[2]; $yMediaA = [bool]$Matches[3]; $trasA = $Matches[4]
        if ($cantA -match '^(?:un\s+)?cuarto\s+de$') { $antesMin = 15 }
        elseif ($cantA -match '^medi[ao]$') { if ($unidadA -like 'hora*') { $antesMin = 30 } }
        elseif ($cantA -match '^(?:un|una)$') { $antesMin = if ($unidadA -like 'hora*') { 60 } else { 1 } }
        else {
            $cantA = (ConvertTo-Digitos $cantA).Trim()
            if ($cantA -match '^\d{1,3}$') { $antesMin = if ($unidadA -like 'hora*') { [int]$cantA * 60 } else { [int]$cantA } }
        }
        # "una hora y media antes", "dos horas y media antes"
        if ($antesMin -gt 0 -and $yMediaA -and $unidadA -like 'hora*') { $antesMin += 30 }
        if ($antesMin -gt 0) {
            $resto = $trasA
            # "antes de las diez": el patron de la hora espera "a las"
            if ($resto -match '^las?\s') { $resto = 'a ' + $resto }
        }
    }
    # hora
    # "11:30" llega como "11 30": ConvertTo-Plain cambia los dos puntos por un
    # espacio, y con solo ':' el patron se quedaba con las 11 y guardaba "30 de
    # la noche que apague el horno" como texto del recordatorio (12/09).
    if ($resto -match '^(?:a\s+las?\s+)(\d{1,2}|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce)(?:(?::|\s+)(\d{2})\b|\s+y\s+media|\s+y\s+cuarto|\s+menos\s+cuarto)?\s*(de la manana|de la tarde|de la noche|am|pm)?\s*(.*)$') {
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
    # no es un recordatorio con fecha... salvo que haya antelacion sin hora, que
    # se pregunta justo debajo
    if ($null -eq $fecha -and $hora -lt 0 -and $antesMin -le 0) { return $null }
    # "avisame veinte minutos antes" sin decir de que: mejor preguntar que
    # dejar que la frase se vaya al agente
    if ($antesMin -gt 0 -and $hora -lt 0) { return "¿Antes de que hora? Di, por ejemplo: avisame diez minutos antes de las nueve." }
    $texto = ($resto -replace '^(?:que|de que|de|para|a)\s+', '').Trim()
    # con antelacion no hace falta decir que: el aviso ya dice cuanto falta
    if (-not $texto -and $antesMin -le 0) { return "¿Que te recuerdo?" }
    if ($hora -lt 0) { $hora = 9 }   # solo dia: a las 9 de la manana
    if ($null -eq $fecha) {
        $fecha = $hoy
        if ($hoy.AddHours($hora).AddMinutes($min) -le (Get-Date)) { $fecha = $hoy.AddDays(1) }
    }
    $cuando = $fecha.Date.AddHours($hora).AddMinutes($min)
    if ($cuando -le (Get-Date)) { return "Esa hora ya paso." }
    $antesDicho = ''
    if ($antesMin -gt 0) {
        $evento = $cuando
        $cuando = $evento.AddMinutes(-$antesMin)
        $cul0 = New-Object System.Globalization.CultureInfo('es-MX')
        $margen = if ($antesMin % 60 -eq 0) { $hh = $antesMin / 60; if ($hh -eq 1) { 'una hora' } else { "$hh horas" } } elseif ($antesMin -eq 30) { 'media hora' } elseif ($antesMin -eq 90) { 'una hora y media' } elseif ($antesMin % 60 -eq 30) { "$([int][Math]::Floor($antesMin / 60)) horas y media" } elseif ($antesMin -eq 1) { 'un minuto' } else { "$antesMin minutos" }
        # "falta una hora", "faltan diez minutos": se lee en voz alta
        $falta = if ($margen -match '^(?:una hora|media hora|una hora y media|un minuto)$') { 'falta' } else { 'faltan' }
        if ($cuando -le (Get-Date)) { return "Ya $falta menos de $margen para las " + $evento.ToString('H:mm', $cul0) + "." }
        $texto = if ($texto) { "$texto. Es a las " + $evento.ToString('H:mm', $cul0) } else { "$falta $margen para las " + $evento.ToString('H:mm', $cul0) }
        $antesDicho = ", $margen antes"
    }
    $lista = @(Get-Recordatorios) + @(New-Object PSObject -Property @{ cuando = $cuando.ToString('s'); texto = $texto })
    Save-Recordatorios $lista
    $cul = New-Object System.Globalization.CultureInfo('es-MX')
    $dicho = if ($cuando.Date -eq $hoy) { "hoy a las " + $cuando.ToString('H:mm', $cul) } elseif ($cuando.Date -eq $hoy.AddDays(1)) { "manana a las " + $cuando.ToString('H:mm', $cul) } else { $cuando.ToString('dddd d "de" MMMM "a las" H:mm', $cul) }
    Log "RECORDATORIO ($cuando): $texto"
    Add-Estadistica 'local' "recordatorio: $text"
    return "Listo, te lo recuerdo $dicho$antesDicho."
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
            # el despertador no es un aviso: suena (ver DESPERTADOR)
            if ($r.texto -eq 'despertador') { try { Invoke-Despertador } catch { Log ("despertador: " + $_.Exception.Message) }; continue }
            Log "RECORDATORIO vence: $($r.texto)"
            Send-Aviso ("Te recuerdo: " + $r.texto) 'recordatorio'
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
    # IDEA 11: el juego tiene algo pendiente. En los manifiestos de Steam, StateFlags 4
    # es "instalado y listo"; cualquier otra cosa (6, 550, 1026...) es actualizacion o
    # descarga a medias. Mejor saberlo AHORA que cuando el juego no arranca.
    try {
        $jE = @($script:Juegos | Where-Object { $_.nombre -eq $nombre }) | Select-Object -First 1
        if ($jE -and [int]$jE.estado -ne 4) {
            [void](Send-AvisoEntorno "juego-pendiente-$nombre" "Ojo, $nombre tiene una actualizacion o descarga pendiente en Steam." 'medio' 120)
        }
    } catch {}
    $script:juegoAvisado = $false
    $script:juegoHoras = 0
    $script:juegoBrilloAntes = $null
    $script:logroArchivo = ''
    try { Show-RecuerdoJuego $nombre } catch { Log ("juegos: " + $_.Exception.Message) }
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
    try { Save-TiempoJuego } catch {}
    # "me quede en..." dicho justo despues de salir sigue siendo de este juego
    $script:ultimoJuego = $nombre
    $script:ultimoJuegoEn = $sw.ElapsedMilliseconds
    # IDEAS 19 y 20: cuanto se juega cada dia. Se apunta AL CERRAR, que es cuando se
    # sabe lo que duro la partida; asi "cuanto llevo hoy" no se lo inventa nadie.
    try {
        $minJ = [int](($sw.ElapsedMilliseconds - $script:juegoDesde) / 60000)
        if ($minJ -ge 2 -and $minJ -le 720) {
            $hbJ = Get-Habitos
            $diaJ = (Get-Date).AddHours(-5).ToString('yyyy-MM-dd')   # la madrugada cuenta como ayer
            if (-not $hbJ.minutosJuego) { $hbJ.minutosJuego = @{} }
            $hbJ.minutosJuego[$diaJ] = [int]$hbJ.minutosJuego[$diaJ] + $minJ
            $limJ = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')
            foreach ($k in @($hbJ.minutosJuego.Keys)) { if ($k -lt $limJ) { $hbJ.minutosJuego.Remove($k) } }
            Save-Habitos
            $totJ = [int]$hbJ.minutosJuego[$diaJ]
            Log "JUEGO: $minJ min con $nombre (hoy van $totJ)"
            if ($totJ -ge 240) {
                [void](Send-AvisoEntorno 'horas-hoy' "Hoy llevas $([Math]::Round($totJ / 60.0, 1)) horas de juego." 'bajo' 480)
            }
        }
    } catch {}
    Invoke-Reglas 'juegoCierra' $nombre
    # idea 9: es el momento en que te acuerdas; media hora despues, ya no
    if ($nombre) {
        [void](Send-AvisoEntorno "juego-cierra" "Cerraste $nombre. Si quieres, dime donde te quedaste." 'medio' 120)
    }
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
function Await-WinRT($op, $tipo, [int]$esperaMs = 8000) {
    if (-not $script:winrtAsTask) {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $script:winrtAsTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                           $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    }
    $t = $script:winrtAsTask.MakeGenericMethod($tipo).Invoke($null, @($op))
    if (-not $t.Wait($esperaMs)) { throw "WinRT: sin respuesta en $esperaMs ms" }
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

# Un trozo de texto para decir en voz alta, desde $desde. Se corta en un PUNTO
# y, si no hay, en un espacio: partir una palabra por la mitad suena a fallo,
# no a pausa. Devuelve el texto y DONDE se quedo, para poder seguir.
function Get-Trozo([string]$todo, [int]$desde, [int]$largo = 320) {
    if ($desde -lt 0) { $desde = 0 }
    if ($desde -ge $todo.Length) { return @{ texto = ''; fin = $todo.Length } }
    $resto = $todo.Substring($desde)
    if ($resto.Length -le $largo) { return @{ texto = $resto.Trim(); fin = $todo.Length } }
    $cacho = $resto.Substring(0, $largo)
    # el ultimo punto que deje al menos media frase; si no, el ultimo espacio
    $corte = $cacho.LastIndexOf('. ')
    if ($corte -lt [int]($largo / 2)) { $corte = $cacho.LastIndexOf(' ') }
    if ($corte -lt [int]($largo / 2)) { $corte = $largo - 1 }
    $fin = $desde + $corte + 1
    return @{ texto = $resto.Substring(0, $corte + 1).Trim(); fin = $fin }
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
# Win+Shift+<tecla>: mover la ventana entre monitores. Es Send-WinKey con el
# Shift por fuera; separadas para no meterle un parametro opcional a la que ya
# usan quince sitios.
function Send-WinShiftKey([int]$vk) {
    [AX]::keybd_event([byte]$VK_LWIN, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]0x10, 0, 0, [UIntPtr]::Zero)      # Shift
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]$vk, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [AX]::keybd_event([byte]0x10, 0, $KEYUP, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [AX]::keybd_event([byte]$VK_LWIN, 0, $KEYUP, [UIntPtr]::Zero)
}

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
    # el banco escribia RECORDATORIO/REGLA de mentira en el assistant.log real
    $EventLog = Join-Path $pruebaDir 'probar.log'
    # el perfil y las recetas se calculan al cargar, ANTES de este bloque: sin
    # esto, "aprende que mi..." pasado por el banco escribiria en el perfil real
    $PerfilPath = Join-Path $pruebaDir 'perfil.md'
    $RecetasPath = Join-Path $pruebaDir 'recetas.json'
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
                foreach ($fr in @(Split-Ordenes $t)) {
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

# el candado ya se cogio arriba, antes de limpiar tmp\ (ver UNA SOLA NOVA)
if (-not $mutex) {
    $mutex = New-Object System.Threading.Mutex($false, "Local\VoiceAssistant")
    if (-not $mutex.WaitOne(0)) {
        Write-Output "VoiceAssistant ya esta ejecutandose."
        exit 0
    }
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

Log "VoiceAssistant iniciado PID=$PID (trigger: mantener ≡ $([Math]::Round($HOLD_MS/1000,1)) s; cerebro: $([string](Get-Cfg 'modelo' 'cerebro' 'claude-code')))."
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
# TRES RECETAS DE INFORMACION YA PUESTAS (16/09). Para no empezar de cero: son las
# preguntas que el 15/09 se fueron al agente costando 44 s cada una. Se ponen solo si no
# existen ya (por su frase), y nacen confirmadas: leer una carpeta no pide permiso.
function Add-RecetasInfoBase {
    if (-not $RecetasOn) { return }
    $base = @(
        @{ frase = 'que hay en mis descargas'
           resumen = 'mirar la carpeta de descargas'
           script = '$d = Join-Path $env:USERPROFILE ''Downloads''; $i = @(Get-ChildItem -LiteralPath $d -File | Sort-Object LastWriteTime -Descending); [pscustomobject]@{ cuantos = $i.Count; nombres = @($i | Select-Object -First 5 | ForEach-Object { $_.Name }) } | ConvertTo-Json -Compress'
           plantilla = 'En descargas tienes {cuantos|archivo|archivos}. Los ultimos: {nombres}.'
           vacio = 'No tienes nada en la carpeta de descargas.' },
        @{ frase = 'que hay en mis documentos'
           resumen = 'mirar la carpeta de documentos'
           script = '$d = Join-Path $env:USERPROFILE ''Documents''; $i = @(Get-ChildItem -LiteralPath $d | Sort-Object LastWriteTime -Descending); [pscustomobject]@{ cuantos = $i.Count; nombres = @($i | Select-Object -First 5 | ForEach-Object { $_.Name }) } | ConvertTo-Json -Compress'
           plantilla = 'En documentos tienes {cuantos|cosa|cosas}. Lo ultimo: {nombres}.'
           vacio = 'No tienes nada en documentos.' },
        @{ frase = 'cuantos clips tengo'
           resumen = 'contar los clips de juego'
           script = '$d = Join-Path $env:USERPROFILE ''Videos\Captures''; $i = @(Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending); [pscustomobject]@{ cuantos = $i.Count; ultimo = $(if ($i.Count -gt 0) { $i[0].Name } else { '''' }) } | ConvertTo-Json -Compress'
           plantilla = 'Tienes {cuantos|clip|clips} guardados. El ultimo es {ultimo}.'
           vacio = 'No tienes ningun clip guardado.' }
    )
    $g = Get-Recetas
    $puestas = 0
    foreach ($b in $base) {
        $clave = ConvertTo-Suave $b.frase
        if (@($g | Where-Object { (ConvertTo-Suave ([string]$_.frase)) -eq $clave }).Count -gt 0) { continue }
        if (-not (Test-ScriptSoloLectura $b.script)) { Log "receta base '$($b.frase)': su script no pasa la revision de solo lectura"; continue }
        $pasos = New-Object System.Collections.ArrayList
        [void]$pasos.Add(@{ tipo = 'lectura'; texto = $b.script })
        $id = 1; foreach ($x in $g) { if ($x.id -ge $id) { $id = $x.id + 1 } }
        [void]$g.Add(@{ id = $id; frase = $b.frase; resumen = $b.resumen; respuesta = ''; pasos = $pasos
                        variantes = (New-Object System.Collections.ArrayList); ejemplo = $b.frase; creada = (Get-Date -Format 's')
                        usos = 0; confirmadas = [Math]::Max(2, $RecetasConfirmar); fallos = 0; rechazos = 0
                        tipo = 'info'; voz = @{ modo = 'plantilla'; plantilla = $b.plantilla; vacio = $b.vacio; instruccion = '' } })
        $puestas++
    }
    if ($puestas -gt 0) { Save-Recetas; Log "recetas de informacion puestas de serie: $puestas" }
}
try { Add-RecetasInfoBase } catch { Log ("recetas base: " + $_.Exception.Message) }
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
# DE QUE PROCESO ES UNA VENTANA. Hace falta para no dictarse a uno mismo:
# comparar handles no basta, porque la capsula es WPF sin titulo y el
# MainWindowHandle que da .NET no es el de la ventana que Windows pone en
# primer plano. Con el PID no hay duda.
Add-Type -Namespace Nova -Name Win -MemberDefinition @'
[DllImport("user32.dll")]
public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int pid);
public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
[DllImport("user32.dll")]
public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder s, int max);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(IntPtr hWnd);
[DllImport("user32.dll")]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
public struct RECT { public int Left, Top, Right, Bottom; }
[DllImport("user32.dll")]
public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
'@ -ErrorAction SilentlyContinue

# EL PANEL DE WIN+H, CERRADO DE VERDAD.
# Antes se intentaba APARTAR su ventana (SetWindowPos a -3000) y cerrarlo con
# otro Win+H. Las dos cosas fallaban, comprobado el 12/09 con capturas:
#   - la ventana se mueve, pero el panel NO: Windows lo dibuja por su cuenta
#     encima de todo, asi que moverla no cambiaba nada en pantalla;
#   - Win+H no es un interruptor fiable. Si el panel se ha quedado en su
#     error ("selecciona un cuadro de texto") o ya se habia cerrado solo, el
#     segundo Win+H lo ABRE en vez de cerrarlo. Ese era el panel que se quedaba
#     a la vista al terminar el dictado.
# Lo que si funciona siempre: terminar TextInputHost. El panel desaparece en el
# acto, en cualquier estado, y Windows relanza el proceso solo en cuanto hace
# falta (el siguiente Win+H abrio el panel a la primera). No hay nada que
# guardar en ese proceso: es el que pinta el teclado tactil y el dictado.
function Close-PanelDictado {
    $n = 0
    foreach ($pr in @(Get-Process TextInputHost -ErrorAction SilentlyContinue)) {
        try { $pr.Kill(); $n++ } catch {}
    }
    return $n
}
function Get-PidDeVentana([IntPtr]$h) {
    if ($h -eq [IntPtr]::Zero) { return 0 }
    $p = 0
    try { [void][Nova.Win]::GetWindowThreadProcessId($h, [ref]$p) } catch { return 0 }
    return $p
}

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
    $script:popupFijada = $false
}
$script:popupFijada = $false
# Fijada no es para siempre: odias los modos que se quedan puestos. Diez
# minutos dan para seguir una lista de pasos entera.
$PopupFijadaMs = 600000

# Los tres sonidos del asistente. Se cargan una vez y se quedan en memoria:
# abrir el WAV en cada pitido mete un retraso que se NOTA, porque justo estos
# suenan cuando quieres saber al instante si te oyo.
# Si falta la carpeta (o el archivo), se vuelve al pitido de Windows: no tener
# tres ficheros de 20 KB no puede dejar al asistente mudo.
$SonidosDir = Join-Path $LogDir 'sonidos'
$script:sonidos = @{}
function Play-Sonido([string]$nombre, [System.Media.SystemSound]$respaldo) {
    try {
        if (-not $script:sonidos.ContainsKey($nombre)) {
            $ruta = Join-Path $SonidosDir ($nombre + '.wav')
            if (Test-Path -LiteralPath $ruta) {
                $sp = New-Object System.Media.SoundPlayer $ruta
                $sp.Load()
                $script:sonidos[$nombre] = $sp
            } else {
                $script:sonidos[$nombre] = $null
            }
        }
        $sp = $script:sonidos[$nombre]
        # Play(), no PlaySync(): el bucle no puede pararse a esperar un pitido
        if ($sp) { $sp.Play(); return }
    } catch {}
    if ($respaldo) { $respaldo.Play() }
}

function Show-Popup([string]$text, [string]$estadoUI = 'hablando') {
    # lo que se VE con las mismas tildes que lo que se OYE (ver TILDES PARA LA VOZ)
    $text = Add-TildesVoz $text
    # SIN TARJETA: respuestas que son para OIRLAS (leer los mensajes). Minimalismo:
    # la capsula enseña el principio y la voz dice el resto; nada de tarjeta grande.
    # caduca a los 3 s: si la puso algo que no paso por aqui (una regla), no puede
    # recortar la siguiente respuesta de la IA (revision del 13/09)
    if ($script:sinTarjeta -and ($sw.ElapsedMilliseconds - $script:sinTarjetaEn) -gt 3000) { $script:sinTarjeta = $false }
    if ($script:sinTarjeta -and $UiNuevaOn) {
        $script:sinTarjeta = $false
        $corto = if ($text.Length -gt 60) { $text.Substring(0, 57) + '...' } else { $text }
        Set-UI $estadoUI $corto $PopupMs
        return
    }
    # TARJETA FIJADA ("dejala ahi"): un mensaje corto va solo a la capsula y no
    # se la lleva por delante; uno largo si la sustituye, porque necesita sitio.
    # Sin esto, el propio "listo, la dejo" cerraba la tarjeta que fijaba.
    if ($script:popupFijada -and $script:popupForm -and $UiNuevaOn -and $text.Length -le 80) {
        Set-UI $estadoUI $text $PopupMs
        return
    }
    Close-Popup
    # Con la interfaz nueva el mensaje va a la capsula. El popup antiguo solo
    # se abre ademas para textos largos, que en 340 px no se podrian leer.
    if ($UiNuevaOn) {
        # SIN TARJETA NUNCA (15/09, pedido por braya): "quita eso, solo manten el texto que
        # trae Nova". Una respuesta larga abria ademas la tarjeta de cristal; ahora todo va
        # solo a la capsula, y la voz lo dice entero (ver RESPUESTAS LARGAS ENTERAS).
        Set-UI $estadoUI $text $PopupMs
        return
    }
    try {
        # TARJETA DE CRISTAL, Y SOBRE TODO: SIN ROBAR EL FOCO.
        # Form.Show() ACTIVA la ventana. Sobre un juego a pantalla completa
        # exclusiva eso lo saca de pantalla completa o lo minimiza: una
        # respuesta larga te tiraba de la partida, que es exactamente el tipo
        # de cosa por la que hubo que apagar el asistente. Aqui se crea el
        # handle sin mostrarla y se saca con SW_SHOWNA.
        # AXTarjeta (en el DLL) es una Form que se niega a activarse al
        # mostrarse; con una Form corriente, Show() te saca del juego
        $f = New-Object AXTarjeta
        $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $f.ShowInTaskbar = $false
        # NADA de $f.TopMost: medido, es justo esa propiedad la que activa la
        # ventana al mostrarla y te saca del juego. AXTarjeta ya se pone encima
        # ella sola, con WS_EX_TOPMOST en su estilo.
        $f.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $f.BackColor = [System.Drawing.Color]::FromArgb(13, 17, 25)
        $f.ForeColor = [System.Drawing.Color]::FromArgb(238, 243, 248)
        $f.Opacity = 0.95

        # se mide el texto a mano: con AutoSize el tamano no es fiable hasta
        # despues de mostrarla, y hace falta ANTES para redondear las esquinas
        $script:popupFont = New-Object System.Drawing.Font("Segoe UI", 10.5)
        $margen = 16; $barra = 3; $anchoMax = 560
        $medida = [System.Windows.Forms.TextRenderer]::MeasureText(
            $text, $script:popupFont,
            (New-Object System.Drawing.Size($anchoMax, 0)),
            ([System.Windows.Forms.TextFormatFlags]::WordBreak))
        $anchoF = [Math]::Min($anchoMax, $medida.Width) + $margen * 2 + $barra + 6
        $altoF = $medida.Height + $margen * 2
        $f.ClientSize = New-Object System.Drawing.Size($anchoF, $altoF)

        # el filo de acento a la izquierda, el mismo verde de la capsula
        $bar = New-Object System.Windows.Forms.Panel
        $bar.Dock = [System.Windows.Forms.DockStyle]::Left
        $bar.Width = $barra
        $bar.BackColor = [System.Drawing.Color]::FromArgb(53, 224, 200)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $l.AutoSize = $false
        $l.Dock = [System.Windows.Forms.DockStyle]::Fill
        $l.Padding = New-Object System.Windows.Forms.Padding($margen, $margen, $margen, $margen)
        $l.Font = $script:popupFont
        $l.ForeColor = $f.ForeColor
        $l.BackColor = [System.Drawing.Color]::Transparent
        $f.Controls.Add($l)
        $f.Controls.Add($bar)

        $s2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        # encima de la capsula, no debajo: la capsula vive en la esquina
        $f.Location = New-Object System.Drawing.Point(($s2.Right - $f.Width - 24), ($s2.Bottom - $f.Height - 78))

        # esquinas redondeadas (el handle se crea aqui, sin mostrar nada)
        $null = $f.Handle
        try {
            $rgn = [AX]::RegionRedonda($f.Width, $f.Height, 16)
            if ($rgn -ne [IntPtr]::Zero) { $f.Region = [System.Drawing.Region]::FromHrgn($rgn) }
        } catch {}

        $f.Show()
        Play-Sonido 'hecho' ([System.Media.SystemSounds]::Asterisk)
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
$script:jobPorApi = $false      # la peticion en curso salio por la API de Claude
$script:jobPrompt = ''          # el prompt tal cual, por si hay que rehacerlo
$script:jobExtra = ''
$script:apiFallo = $false       # la API dio un error que no se arregla reintentando
$script:jobErr = $null
$script:jobIn = $null
$script:jobStart = 0

# Libera el trabajo actual y devuelve la UI a reposo.
function Clear-OpencodeJob {
    foreach ($f in @($script:jobOut, $script:jobErr, $script:jobIn, $(if ($script:jobOut) { $script:jobOut + '.consola' }))) {
        if ($f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
    $script:jobOut = $null; $script:jobErr = $null; $script:jobIn = $null
    # sin esto, cancelar pasada la estimacion dejaba el barrido de progreso en reposo
    $script:uiProgreso = 0
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
    # cancelada: la reparacion de receta que llevara no puede colarse en otra tarea
    $script:reparandoReceta = $null
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

# EL CEREBRO DE FUERA: la API de Claude para entender, opencode para hacer.
# Lo que se le pide al modelo casi siempre es traducir una frase a una orden
# conocida o contestar algo corto. Para eso, opencode es un camion para llevar
# una carta: tarda 13-160 s porque monta un agente con herramientas. Una llamada
# directa a la API tarda ~1 s y cuesta centimos al mes.
# Las TAREAS de verdad ("busca en mis archivos y hazme un resumen") siguen yendo
# a opencode, que para eso si hace falta un agente con manos.
$ClaudeOn = [bool](Get-Cfg 'modelo' 'usarClaude' $true)
# Haiku para traducir: es clasificar una frase contra una lista cerrada, el caso
# de libro para el modelo rapido. Opus para lo que se contesta hablando, donde
# la diferencia se nota.
$ClaudeModeloRapido = [string](Get-Cfg 'modelo' 'rapido' 'claude-haiku-4-5')
$ClaudeModeloBueno = [string](Get-Cfg 'modelo' 'bueno' 'claude-opus-5')
$ClaudeScript = Join-Path $LogDir "tools\claude-api.ps1"

# =====================================================================
# EL CEREBRO: CLAUDE CODE (13/09)
# El mismo Claude que programa este asistente, en modo sin ventana (claude -p),
# con la suscripcion del usuario. Sustituye como primera opcion a la API (sin
# saldo) y a opencode (modelo gratuito y flojo), que quedan de respaldo.
# Medido antes de montarlo, lanzado igual que aqui: Haiku sin herramientas
# contesta en 3,8 s; Sonnet con el MCP de Windows hace una tarea con una
# herramienta en 13,8 s. apiKeySource=none en los dos: tira de la suscripcion.
# Entra por la MISMA puerta que opencode ($script:proc y los archivos out/err/
# in), asi que la cancelacion con el boton, la capsula y la recogida no cambian.
# =====================================================================
$CerebroMotor = [string](Get-Cfg 'modelo' 'cerebro' 'claude-code')
$CcCli = [string](Get-Cfg 'paths' 'claudeCodeCli' (Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe'))
$CcModeloTraducir = [string](Get-Cfg 'modelo' 'ccTraducir' 'haiku')
$CcModeloPregunta = [string](Get-Cfg 'modelo' 'ccPregunta' 'sonnet')
$CcModeloAccion = [string](Get-Cfg 'modelo' 'ccAccion' 'sonnet')
$CcMcp = Join-Path $LogDir 'cerebro-mcp.json'          # solo el MCP de Windows: cargar todos hace lento cada arranque
$CcSistema = Join-Path $LogDir 'cerebro-sistema.md'    # quien es Nova, como hablar y las reglas fijas
$CcSesionDir = Join-Path $LogDir 'cerebro'             # donde viven las charlas (--continue)
# Lo mismo que se le prohibe a opencode (opencode.jsonc), en la sintaxis de
# Claude Code. Van ADEMAS de las reglas fijas del prompt de sistema.
$CcProhibido = @('Bash(rm -rf:*)', 'Bash(rm -fr:*)', 'Bash(rm -r:*)', 'Bash(format:*)', 'Bash(diskpart:*)', 'Bash(reg delete:*)',
                 'Bash(shutdown:*)', 'Bash(git push --force:*)', 'Bash(git reset --hard:*)', 'Bash(git clean -f:*)',
                 'PowerShell(Stop-Computer:*)', 'PowerShell(Restart-Computer:*)', 'PowerShell(Format-Volume:*)', 'PowerShell(Clear-Disk:*)',
                 'PowerShell(shutdown:*)', 'PowerShell(diskpart:*)', 'PowerShell(reg delete:*)',
                 # BLOQUEO DE LO DESTRUCTIVO (decidido por braya el 13/09, tras la
                 # auditoria): las herramientas del MCP de Windows que tocan el
                 # registro, los procesos, los archivos o ejecutan PowerShell a
                 # pelo se saltaban toda la lista de arriba. Y borrar o matar
                 # procesos por cualquier terminal. Sigue pudiendo abrir apps,
                 # crear carpetas y archivos, escribir, pulsar y mover ventanas.
                 'mcp__windows__Registry', 'mcp__windows__Process', 'mcp__windows__PowerShell', 'mcp__windows__FileSystem',
                 'Bash(rm:*)', 'Bash(rmdir:*)', 'Bash(del:*)', 'Bash(rd:*)', 'Bash(erase:*)', 'Bash(taskkill:*)', 'Bash(reg:*)',
                 'Bash(powershell:*)', 'Bash(pwsh:*)', 'Bash(cmd:*)',
                 'PowerShell(Remove-Item:*)', 'PowerShell(rm:*)', 'PowerShell(del:*)', 'PowerShell(rmdir:*)', 'PowerShell(rd:*)', 'PowerShell(erase:*)',
                 'PowerShell(ri:*)', 'PowerShell(Clear-Content:*)', 'PowerShell(Clear-RecycleBin:*)',
                 'PowerShell(Stop-Process:*)', 'PowerShell(kill:*)', 'PowerShell(spps:*)', 'PowerShell(taskkill:*)',
                 'PowerShell(Set-ItemProperty:*)', 'PowerShell(New-ItemProperty:*)', 'PowerShell(Remove-ItemProperty:*)', 'PowerShell(reg:*)',
                 'PowerShell(Invoke-Expression:*)', 'PowerShell(iex:*)', 'PowerShell(cmd:*)', 'PowerShell(Start-Process cmd:*)')
$script:jobMotor = ''
$script:jobPorCC = $false
$script:jobAdjunto = ''
$script:ccFallo = $false

function Test-CerebroClaudeCode {
    return ($CerebroMotor -eq 'claude-code' -and -not $script:ccFallo -and (Test-Path -LiteralPath $CcCli))
}

function Start-ClaudeCodeJob([string]$prompt, [string]$modo, [string]$adjunto = '') {
    $id = [System.Guid]::NewGuid().ToString("N")
    $script:jobOut = Join-Path $TmpDir "out-$id.txt"
    $script:jobErr = Join-Path $TmpDir "err-$id.txt"
    $script:jobIn = Join-Path $TmpDir "in-$id.txt"
    if (-not $prompt.Trim()) { Clear-OpencodeJob; return $false }
    try {
        if ($adjunto -and (Test-Path -LiteralPath $adjunto)) { $prompt = $prompt + " (La captura esta en: $adjunto. Mirala con la herramienta Read.)" }
        # en las tareas, que deje la receta para repetirla sin IA (ver RECETAS)
        if ($modo -eq 'accion' -and $RecetasOn) { $prompt = $prompt + $CcInstruccionReceta }
        # y que apunte lo que descubra de ti; en traducir NO: ahi Haiku tiene
        # que contestar una sola linea y un DATO: rompería la traduccion
        if ($modo -ne 'traducir') { $prompt = $prompt + $CcInstruccionDato }
        # y si viene de una receta que fallo, con lo necesario para arreglarla
        if ($modo -eq 'accion' -and $script:reparandoReceta -and $script:reparandoReceta.texto -eq $script:jobTextoOriginal) {
            $rep = $script:reparandoReceta
            $prompt = $prompt + "`n`nCONTEXTO IMPORTANTE: Nova ya tenia una receta aprendida para esto, con la plantilla `"$($rep.frase)`", y al repetirla FALLO. Sus pasos eran: $($rep.pasos). El error fue: $($rep.error). Haz la tarea y, en la RECETA del final, usa esa MISMA plantilla con los pasos corregidos para que no vuelva a fallar."
        }
        # el prompt entra por STDIN desde un archivo: tildes, comillas y saltos
        # de linea llegan intactos (en argv se destrozan)
        [System.IO.File]::WriteAllText($script:jobIn, $prompt, (New-Object System.Text.UTF8Encoding($false)))
        $a = New-Object System.Collections.ArrayList
        foreach ($x in @('-p', '--output-format', 'stream-json', '--verbose')) { [void]$a.Add($x) }
        # quien es Nova + LO QUE SABE DE TI (ver PERFIL), en cada peticion
        $sistemaActual = $null
        try { $sistemaActual = Get-SistemaCerebro } catch { $sistemaActual = $null }
        if ($sistemaActual) { [void]$a.Add('--append-system-prompt-file'); [void]$a.Add((ConvertTo-CmdArg $sistemaActual)) }
        $dir = $WORKDIR
        $modelo = $CcModeloPregunta
        switch ($modo) {
            'traducir' {
                # clasificar una frase contra una lista cerrada: el modelo rapido y nada mas
                $modelo = $CcModeloTraducir
                foreach ($x in @('--tools', '""', '--strict-mcp-config', '--no-session-persistence', '--max-turns', '1')) { [void]$a.Add($x) }
            }
            'accion' {
                # manos de verdad: el MCP de Windows y permisos sin preguntar (no hay
                # nadie delante de un teclado para contestar), con lo destructivo fuera
                $modelo = $CcModeloAccion
                foreach ($x in @('--permission-mode', 'bypassPermissions', '--strict-mcp-config', '--mcp-config', (ConvertTo-CmdArg $CcMcp),
                                 '--no-session-persistence', '--max-turns', '40')) { [void]$a.Add($x) }
                [void]$a.Add('--disallowedTools')
                foreach ($r in $CcProhibido) { [void]$a.Add((ConvertTo-CmdArg $r)) }
            }
            default {
                # preguntas y charla: contestar, y buscar en internet si hace falta
                foreach ($x in @('--tools', 'WebSearch,WebFetch,Read', '--allowedTools', 'WebSearch,WebFetch,Read', '--strict-mcp-config', '--max-turns', '6')) { [void]$a.Add($x) }
                if ($modo -eq 'charla' -and -not $script:invitado) {
                    # la charla recuerda lo hablado: su propia carpeta, con sesiones
                    # (un invitado no hereda tu conversacion: ver MODO INVITADO)
                    if (-not (Test-Path -LiteralPath $CcSesionDir)) { New-Item -ItemType Directory -Path $CcSesionDir -Force | Out-Null }
                    $dir = $CcSesionDir
                    [void]$a.Add('--continue')
                } else {
                    [void]$a.Add('--no-session-persistence')
                }
            }
        }
        [void]$a.Add('--model'); [void]$a.Add($modelo)
        $script:jobLeido = 0; $script:jobPasos = 0; $script:jobUltimaHerr = ''; $script:jobProgresoCheck = 0
        Log "CEREBRO ($modo): claude-code $modelo, $($prompt.Length) caracteres"
        # SIN la clave de la API (sin saldo: Claude Code la preferiria a la
        # suscripcion y fallaria) y sin las variables de una sesion de Claude
        # Code que haya lanzado este asistente. Se devuelven al terminar.
        $quitadas = @{}
        foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name -match '^(?:ANTHROPIC_API_KEY|CLAUDECODE|CLAUDE_CODE_.+|CLAUDE_PID)$' })) {
            $quitadas[$v.Name] = $v.Value
            Remove-Item -LiteralPath ("Env:" + $v.Name) -ErrorAction SilentlyContinue
        }
        try {
            $script:proc = Start-Process -FilePath $CcCli -ArgumentList ($a -join ' ') `
                -WorkingDirectory $dir -WindowStyle Hidden -PassThru `
                -RedirectStandardOutput $script:jobOut -RedirectStandardError $script:jobErr `
                -RedirectStandardInput $script:jobIn
        } finally {
            foreach ($k in $quitadas.Keys) { Set-Item -LiteralPath ("Env:" + $k) -Value $quitadas[$k] }
        }
        $null = $script:proc.Handle
    } catch {
        Log ("no pude lanzar el cerebro (Claude Code): " + $_.Exception.Message)
        Clear-OpencodeJob
        return $false
    }
    $script:jobMotor = 'claude-code'
    $script:jobStart = $sw.ElapsedMilliseconds
    $script:busy = $true
    return $true
}

function Test-ClaveClaude {
    foreach ($ambito in @('Process', 'User', 'Machine')) {
        $v = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', $ambito)
        if ($v) { return $true }
    }
    return $false
}

# Misma forma que Start-OpencodeJob a proposito: escribe en los mismos archivos
# y deja $script:proc, asi que la cancelacion con el boton, el progreso y la
# recogida funcionan sin cambiar nada de eso.
function Start-ClaudeJob([string]$texto, [string]$modelo, [int]$maxTokens, [string]$imagen = '') {
    $id = [System.Guid]::NewGuid().ToString("N")
    $script:jobOut = Join-Path $TmpDir "out-$id.txt"
    $script:jobErr = Join-Path $TmpDir "err-$id.txt"
    $script:jobIn = Join-Path $TmpDir "in-$id.txt"
    if (-not $texto.Trim()) { Clear-OpencodeJob; return $false }
    try {
        # el prompt va por ARCHIVO, no por linea de comandos: lleva saltos de
        # linea, comillas y acentos, y en argv todo eso se destroza
        [System.IO.File]::WriteAllText($script:jobIn, $texto, (New-Object System.Text.UTF8Encoding($false)))
        $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ClaudeScript,
                  '-PromptFile', $script:jobIn, '-Modelo', $modelo, '-MaxTokens', [string]$maxTokens,
                  '-SalidaArchivo', $script:jobOut)
        # LO QUE VES EN PANTALLA (15/09): la captura va con la pregunta
        if ($imagen -and (Test-Path -LiteralPath $imagen)) { $args += @('-Imagen', $imagen) }
        $script:jobLeido = 0; $script:jobPasos = 0; $script:jobUltimaHerr = ''; $script:jobProgresoCheck = 0
        Log "CLAUDE: $modelo, $($texto.Length) caracteres de prompt"
        # la respuesta la escribe el propio script en $script:jobOut, en UTF-8, y la consola
        # redirigida va aparte, de respaldo (ver LAS TILDES en claude-api.ps1)
        $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $args `
            -WorkingDirectory $LogDir -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput ($script:jobOut + '.consola') -RedirectStandardError $script:jobErr
        $null = $script:proc.Handle
    } catch {
        Log ("no pude llamar a la API: " + $_.Exception.Message)
        Clear-OpencodeJob
        return $false
    }
    $script:jobStart = $sw.ElapsedMilliseconds
    $script:busy = $true
    return $true
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

        # SIN LA CLAVE DE ANTHROPIC. opencode no tiene credenciales propias: si
        # hereda ANTHROPIC_API_KEY la usa y cambia de modelo solo
        # (opencode/big-pickle -> anthropic/claude-sonnet-4-6). El 12/09 la
        # clave se puso para la API directa, la cuenta no tenia saldo, y desde
        # el primer arranque que heredo la variable TODAS las tareas de opencode
        # fallaron con "credit balance too low" (visto en su opencode.db). Se
        # retira solo mientras se lanza: la API la sigue leyendo por su cuenta.
        $claveApi = $env:ANTHROPIC_API_KEY
        Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
        try {
            $script:proc = Start-Process -FilePath $OCODECLI -ArgumentList $argLine `
                -WorkingDirectory $WORKDIR -WindowStyle Hidden -PassThru `
                -RedirectStandardOutput $script:jobOut -RedirectStandardError $script:jobErr `
                -RedirectStandardInput $script:jobIn
        } finally {
            if ($claveApi) { $env:ANTHROPIC_API_KEY = $claveApi }
        }
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
    'powershell' = 'ejecutando un comando'; 'toolsearch' = 'buscando herramientas'; 'agent' = 'delegando una tarea'
}
# Con la API son ~1-3 s; con opencode, 15-60. La capsula usa esto para dibujar
# la barra de espera, y si miente la barra no sirve de nada.
$DURACION_ESPERADA = @{ 'pregunta' = 4000; 'traducir' = 2500; 'charla' = 5000; 'accion' = 60000 }
# con Claude Code, medido el 13/09: arrancar cuesta ~2-3 s y una tarea corta con
# herramientas unos 14
$DURACION_CC = @{ 'pregunta' = 8000; 'traducir' = 4000; 'charla' = 9000; 'accion' = 25000 }

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
                # el mismo evento en el formato de Claude Code (stream-json)
                foreach ($m in [regex]::Matches($trozo, '"type":"tool_use","id":"[^"]*","name":"([^"]+)"')) {
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
        elseif ($clave -match '^(?:mcp_+)?windows') { $frase = 'controlando el escritorio' }
        elseif ($clave -match 'mcp|__') { $frase = 'usando una herramienta' }
        else { $frase = "usando $herr" }
        if ($frase -ne $script:jobUltimaHerr) {
            $script:jobUltimaHerr = $frase
            Log "PASO $($script:jobPasos): $herr"
            Set-UI 'pensando' $frase
        }
    }
    # progreso estimado: tiempo transcurrido sobre lo esperado por modo
    $tablaEsp = if ($script:jobMotor -eq 'claude-code') { $DURACION_CC } else { $DURACION_ESPERADA }
    $esp = if ($tablaEsp.ContainsKey($script:jobModo)) { $tablaEsp[$script:jobModo] } else { 60000 }
    $p = [Math]::Min(0.97, ($sw.ElapsedMilliseconds - $script:jobStart) / [double]$esp)
    if ([Math]::Abs($p - $script:uiProgreso) -ge 0.02) { $script:uiProgreso = [Math]::Round($p, 2); Refresh-UI }
}

# Recoge la salida del proceso YA terminado y devuelve el texto de respuesta.
function Complete-OpencodeJob {
    $script:ccConHerramientas = $false
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
        } elseif (Test-Path -LiteralPath ($script:jobOut + '.consola')) {
            # la API por script no llego a escribir su archivo: lo de la consola, aunque sea sin tildes
            $stdout = [System.IO.File]::ReadAllText(($script:jobOut + '.consola'), [System.Text.Encoding]::UTF8)
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

    # --- CLAUDE CODE: la respuesta es el evento "result" del final ---
    if ($script:jobMotor -eq 'claude-code') {
        $script:jobMotor = ''
        # solo se aprende una receta de lo que se hizo DE VERDAD con herramientas
        $script:ccConHerramientas = ($stdout -match '"type":"tool_use"')
        $res = $null
        foreach ($linea in ($stdout -split "`r?`n")) {
            # OJO: el evento NO empieza por {"type":"result"; sus campos vienen en
            # otro orden ({"duration_api_ms":...,"type":"result",...}). Con el
            # patron anclado al principio no se encontraba nunca (13/09).
            if ($linea -match '"type":"result"') {
                try { $ev = $linea | ConvertFrom-Json; if ($ev.type -eq 'result') { $res = $ev } } catch {}
            }
        }
        if (-not $res) {
            # ¿LLEGO A HACER ALGO? Si uso alguna herramienta, NO se rehace con el
            # respaldo: el 13/09 creo un archivo, no se leyo su respuesta y la
            # orden se mando otra vez a opencode. Repetir una accion es peor
            # que no confirmarla.
            if ($stdout -match '"type":"tool_use"') {
                Log "CEREBRO: sin respuesta final, pero llego a usar herramientas; no se repite"
                return @("No se si lo termine: empece a hacerlo pero no me llego la confirmacion. Miralo antes de repetirlo.")
            }
            # ni siquiera llego a contestar (no arranco, sin sesion iniciada...):
            # esto SI se puede rehacer con el respaldo, porque no hizo nada
            $msg = if ($stderr.Trim()) { $stderr.Trim() } else { "sin resultado; exit=$code" }
            return @("(error del cerebro: " + $msg.Substring(0, [Math]::Min(300, $msg.Length)) + ")")
        }
        if ($res.subtype -eq 'success' -and -not $res.is_error) { return @([string]$res.result) }
        if ($res.subtype -eq 'success' -and $res.is_error) {
            # ...salvo que ANTES del error ya usara herramientas (auditoria 13/09):
            # repetirlo con el respaldo podria hacer dos veces lo mismo
            if ($stdout -match '"type":"tool_use"') {
                Log "CEREBRO: error de la cuenta despues de usar herramientas; no se repite"
                return @("No se si lo termine: empece a hacerlo y la cuenta dio un error. Miralo antes de repetirlo.")
            }
            # error de la cuenta o del servicio (limite de uso, sesion caducada):
            # tampoco hizo nada, se puede rehacer con el respaldo
            return @("(error del cerebro: " + [string]$res.result + ")")
        }
        # Se quedo a medias EN MITAD de una tarea (demasiados pasos, fallo al
        # ejecutar). NO se rehace con el respaldo: podria repetir lo que ya hizo.
        Log ("CEREBRO a medias: " + [string]$res.subtype)
        if ([string]$res.result) { return @([string]$res.result) }
        return @("No pude terminarlo del todo. Mira si hizo algo antes de repetirlo.")
    }

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
# "lo que dije fue que abrieras el juego" es una CORRECCION, no una consulta a la
# memoria (15/09): con "que dije" a secas se iba a leer las notas.
$RE_MEMORIA = '\b(?:que sabes (?:de|del|sobre|acerca)|que te dije(?!\s+fue)|que dije(?!\s+fue)|que te conte|recuerdas|te acuerdas|en tus notas|en mis notas|que anote|que apunte|mi memoria|mis notas|que guardaste|que tengo anotado|que tienes anotado)\b'

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
$PRE_HABLADO = 'Responde SOLO con palabras, breve (una o dos frases), en espanol, sin ejecutar nada en el equipo (si la pregunta necesita datos de hoy, puedes buscar en internet). Si el texto no es una pregunta ni algo dicho a un asistente -es ruido, una frase suelta, el audio de un video o una conversacion ajena- responde exactamente: NO. '

# Preguntas: se contestan hablando, no se ejecutan.
$RE_PREGUNTA = '^(?:que|cual|cuanto|cuantos|cuando|donde|quien|como|por que|para que|sabes|dime|cuentame|explicame|explica|crees|opinas|hablame|es cierto|de verdad)\b'

# Construye la peticion de traduccion. Se le da el vocabulario REAL para que no
# invente, y se le exige responder solo con la orden, sin explicaciones.
# EL PLAN (16/09, ver TAREAS SIN EL AGENTE). Mismo vocabulario que la traduccion, pero
# pidiendo VARIAS ordenes en vez de una. Se le deja decir que no se puede: mas vale
# esperar al agente que hacer tres cosas que nadie pidio.
function Build-PromptPlan([string]$text) {
    return ((Build-PromptTraduccion $text) + @"

ESTO ES UNA TAREA DE VARIOS PASOS. Descomponla en las ordenes de arriba, UNA POR LINEA,
como maximo 5, en el orden en que hay que hacerlas. No escribas numeros, guiones ni
explicaciones: solo las ordenes, tal cual aparecen en la lista, con los datos rellenados.
Si la tarea necesita algo que NO esta en la lista (mirar la pantalla, elegir un resultado,
descargar, instalar, mover archivos, escribir un correo...), responde una sola linea:
NO SE PUEDE
"@)
}

# De lo que devuelve la API a una lista de ordenes, comprobando TODAS antes de hacer
# ninguna. Devuelve @() si el plan no sirve: entonces la tarea va al agente.
# El booleano de cada orden lo pone quien llama (Test-FastCommand), para poder probar
# esta funcion sin arrastrar medio archivo.
function Split-Plan([string]$texto) {
    if (-not $texto) { return @() }
    $lineas = @(($texto -split '[\r\n]+') | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    # se le cuelan numeros, guiones y comillas de vez en cuando
    $lineas = @($lineas | ForEach-Object { (($_ -replace '^\s*(?:\d+[\.\)]|[-*•])\s*', '').Trim().Trim('"').Trim("'")).Trim() } | Where-Object { $_ })
    if ($lineas.Count -eq 0) { return @() }
    if (@($lineas | Where-Object { $_.ToUpperInvariant() -match '^NO SE PUEDE' }).Count -gt 0) { return @() }
    # lo que lleve un hueco sin rellenar no se puede hacer
    if (@($lineas | Where-Object { $_ -match '<[^>]*>' }).Count -gt 0) { return @() }
    if ($lineas.Count -gt 5) { return @() }
    return $lineas
}

function Build-PromptTraduccion([string]$text) {
    $apps = (@($cmds.apps.PSObject.Properties.Name) | Select-Object -First 24) -join ', '
    $sitios = (@($cmds.sitios.PSObject.Properties.Name) | Select-Object -First 14) -join ', '
    $juegos = (@($script:Juegos | ForEach-Object { $_.nombre }) | Select-Object -First 20) -join ', '
    # las TAREAS APRENDIDAS (recetas), para que las reconozca dichas de otra forma
    $tareas = ''
    if ($RecetasOn) {
        $gT = Get-Recetas
        if ($gT.Count -gt 0) {
            $listaT = @(@($gT) | Sort-Object { - [int]$_.usos } | Select-Object -First 25 | ForEach-Object { '- ' + [string]$_.frase })
            $tareas = "`nTareas que Nova ya sabe hacer. Si la orden es una de estas, aunque se diga con otras palabras, responde con esa plantilla rellenando cada {hueco} con lo que dijo el usuario, copiado tal cual:`n" + ($listaT -join "`n") + "`n"
        }
    }
    # TODO LO QUE NOVA SABE HACER (15/09). Con la lista vieja, en su uso real la API
    # marcaba "cierra la calculadora y cierra steam" como NO y "puedes poner un
    # temporizador de cinco minutos" como TAREA: no sabia que Nova hace eso sola, y
    # ahora una TAREA va a Claude Code (35-90 s). Cada forma de aqui se comprobo con
    # la capa local de verdad (tools\probar-audio.py, acciones_de) antes de ponerla.
    return @"
Traduce lo que dijo el usuario a ordenes que Nova sabe hacer, usando SOLO estas formas:
abre <app> | abre <sitio> | abre <juego> en steam | abre la carpeta <nombre>
cierra <app> | cierra todos los programas | minimiza todo
minimiza <app> | maximiza <app> | a mitad de pantalla
busca <texto> en <sitio> | pon <cancion o artista> en spotify
sube el volumen | baja el volumen | pon el volumen al <n> | silencia | quita el silencio | pon <app> al <n>
sube el brillo | baja el brillo | pon el brillo al <n>
pausa | reproduce | siguiente cancion | anterior cancion | que esta sonando
pon un temporizador de <n> minutos | cuanto queda del temporizador | cancela el temporizador
recuerdame en <n> minutos que <algo> | recuerdame manana a las <hora> que <algo> | que recordatorios tengo
recuerda que <dato> | que sabes de mi
que hora es | que dia es hoy | cuanta bateria queda | cuanto espacio me queda | que se esta descargando
a que estoy jugando | donde me quede | cuanto he jugado esta semana | que he hecho hoy
haz una captura | lee la pantalla | bloquea | deshaz
no me escuches <n> minutos
modo juego | modo noche | modo trabajo | modo cine | modo silencio | modo ahorro | modo foco <n> minutos
apunta <cosa> en la lista de la compra | que tengo en la lista
cuando <pase algo> <orden>

Apps disponibles: $apps
Sitios disponibles: $sitios
Juegos instalados: $juegos
$tareas

Responde SOLO con la orden traducida, sin comillas, sin explicacion y sin
ninguna palabra extra. Si pide varias cosas, pon una orden por linea.
Nunca dejes huecos como <n> sin rellenar: si falta un dato (por ejemplo
cuantos minutos), no pongas esa orden.
El texto sale de un reconocedor de voz y puede traer palabras mal oidas:
interpreta lo que quiso decir.
Si es una peticion de verdad dirigida a un asistente pero no se puede hacer
con esas formas (hace falta manejar programas, webs o archivos paso a paso:
reproducir un video concreto, revisar algo dentro de una app, buscar en
archivos...), responde exactamente: TAREA
Si NO es una orden dirigida a nadie (conversacion ajena, el audio de un
video o de una cancion que sonaba de fondo, una frase suelta, inconexa o
sin sentido), responde exactamente: NO

Orden del usuario: $text
"@
}

# =====================================================================
# CONVERSACION DE VERDAD (13/09): sin modo y sin frase para empezar (lo pidio
# braya: el "modo conversacion" del 11/09 se tragaba las ordenes). Cada frase
# se enruta sola: lo que Nova ya sabe hacer se hace; lo que es charla o
# pregunta va al worker de charla (charla_worker.py): primero Qwen2.5 3B en
# local con Ollama y, si no puede, la API de Claude. Contesta FRASE A FRASE (la
# primera suena en cuanto esta) y al acabar Nova vuelve a escuchar sola. Si el
# modelo ve que lo dicho era algo que HACER, lo devuelve y va por el camino de
# siempre de las ordenes. Jugando, el modelo sale de la RAM.
# =====================================================================
$CharlaWorker = Join-Path $LogDir 'charla_worker.py'
$ConversacionOn = [bool](Get-Cfg 'conversacion' 'activada' $true)
$ConversacionModelo = [string](Get-Cfg 'conversacion' 'modeloLocal' 'qwen2.5:3b')
$ConversacionApi = [string](Get-Cfg 'modelo' 'rapido' 'claude-haiku-4-5')
$ConversacionEsperaMs = [int](Get-Cfg 'conversacion' 'esperaMs' 7000)
# EL CEREBRO PROPIO (charla_memoria.py): lo aprendido hablando, en memoria\cerebro
# (fuera del repositorio). El modelo de embeddings busca por significado; sin el,
# se busca solo por palabras.
$ConversacionEmbed = [string](Get-Cfg 'conversacion' 'modeloEmbeddings' 'embeddinggemma:300m-qat-q8_0')
$CerebroDir = Join-Path $MemoriaDir 'cerebro'
$script:charlaProc = $null
$script:charlaLectura = $null
$script:charlaId = 0
$script:charlaTexto = ''
$script:charlaEsperando = $false
$script:charlaFrases = New-Object System.Collections.Queue
$script:charlaUltima = -600000      # ms del ultimo intercambio de charla
$script:charlaSilencios = 0
$script:charlaDescargada = $true
$script:vozFinReal = 0              # cuando acaba DE VERDAD la frase que suena (ver Say-Online)
$script:charlaOp = 'hablar'         # que se le pidio al worker (hablar, trivia, resumir)
$script:triviaHasta = 0             # hasta cuando la proxima frase es la respuesta a la trivia
$script:ventanaCharla = $false      # el proximo seguimiento es de una conversacion
$script:precargaEn = -600000        # ultima precarga del modelo de charla
$script:uiOrigen = ''               # quien dice la frase que suena (memoria, local, api): la capsula la tine
$script:progresoCharla = $false     # la linea de la capsula marca la espera de la charla

# EL RITMO DE BRAYA (M8): cuanto tardas en empezar a hablar cuando Nova te deja
# la ventana abierta. Lo mide el worker de escucha; con los ultimos 30, la
# ventana se ajusta: ni tan corta que te corte ni tan larga que escuche de mas.
function Add-RitmoSeguimiento {
    $rutaR = Join-Path $TmpDir 'seguimiento-voz.txt'
    if (-not (Test-Path -LiteralPath $rutaR)) { return }
    $s = -1.0
    try { $s = [double]::Parse(([System.IO.File]::ReadAllText($rutaR)).Trim(), [System.Globalization.CultureInfo]::InvariantCulture) } catch { $s = -1.0 }
    Remove-Item -LiteralPath $rutaR -Force -ErrorAction SilentlyContinue
    if ($s -lt 0 -or $s -gt 30 -or $script:invitado) { return }
    $hbR = Get-Habitos
    [void]$hbR.ritmo.Add([Math]::Round($s, 2))
    while ($hbR.ritmo.Count -gt 30) { $hbR.ritmo.RemoveAt(0) }
    Save-Habitos
}
function Get-VentanaSeguimiento([bool]$charla = $false) {
    $hbV = Get-Habitos
    if ($hbV.ritmo.Count -lt 5) { if ($charla) { return $ConversacionEsperaMs } else { return $SeguimientoMs } }
    $orden = @($hbV.ritmo | Sort-Object)
    $p80 = [double]$orden[[int][Math]::Floor(($orden.Count - 1) * 0.8)]
    if ($charla) { return [int][Math]::Min(12000, [Math]::Max(4000, $p80 * 1600 + 1500)) }
    return [int][Math]::Min(6000, [Math]::Max($SeguimientoMs, $p80 * 1300 + 800))
}

# MENOS ESPERA EN FRIO (M2): el modelo de charla tarda ~15 s en cargar. Si es
# probable que vayas a conversar (hablasteis hace poco, o sueles hacerlo a esta
# hora tres dias de las dos ultimas semanas), al llamarla se precarga mientras
# dictas. Jugando no, que la RAM es del juego, salvo que acabeis de hablar.
function Add-CharlaHora([datetime]$cuando = (Get-Date)) {
    if ($script:invitado) { return }
    $hbC = Get-Habitos
    $clave = $cuando.ToString('yyyy-MM-dd|HH')
    if ($hbC.charlaHoras.ContainsKey($clave)) { return }
    $hbC.charlaHoras[$clave] = 1
    $limite = $cuando.AddDays(-14).ToString('yyyy-MM-dd')
    foreach ($k in @($hbC.charlaHoras.Keys)) { if ($k.Substring(0, 10) -lt $limite) { $hbC.charlaHoras.Remove($k) } }
    Save-Habitos
}
# RAM PARA PRECARGAR LA CHARLA (15/09). En la prueba en vivo la precarga de qwen2.5:3b (2 GB)
# saltaba al pulsar el boton, justo cuando la escucha tenia Parakeet, base y small cargados:
# quedaron 0,3 GB libres de 7,7 y Whisper tardo de 4,5 a 12,9 s por orden en vez de ~1 s (la
# primera orden, 29 s en total). Una charla en frio tarda mas en contestar; una orden lenta es
# peor. Sin este margen libre no se precarga (config.json -> conversacion.precargaRamMinMB).
$PrecargaRamMinMB = [int](Get-Cfg 'conversacion' 'precargaRamMinMB' 3000)
function Test-RamParaCharla {
    try {
        if (-not ('Microsoft.VisualBasic.Devices.ComputerInfo' -as [type])) { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop }
        $libreMB = [double](New-Object Microsoft.VisualBasic.Devices.ComputerInfo).AvailablePhysicalMemory / 1MB
        if ($libreMB -lt $PrecargaRamMinMB) {
            Log ("charla: no precargo el modelo, solo quedan {0:N0} MB libres (minimo {1})" -f $libreMB, $PrecargaRamMinMB)
            return $false
        }
        return $true
    } catch { return $true }
}
function Test-PrecargaCharla([datetime]$ahora = (Get-Date)) {
    if (-not $ConversacionOn) { return $false }
    # con la API contesta ella primero (ver API PRIMERO en charla_worker.py): cargar el
    # modelo local solo gastaria 1-2 GB de RAM que la escucha necesita
    if ($ClaudeOn -and -not $script:apiFallo -and (Test-ClaveClaude)) { return $false }
    $reciente = ($sw.ElapsedMilliseconds - $script:charlaUltima) -lt 1200000
    if ($reciente) { return $true }
    if ($script:juegoActivo) { return $false }
    $hora = $ahora.ToString('HH')
    $limite = $ahora.AddDays(-14).ToString('yyyy-MM-dd')
    $dias = @((Get-Habitos).charlaHoras.Keys | Where-Object { $_.EndsWith("|$hora") -and $_.Substring(0, 10) -ge $limite }).Count
    return ($dias -ge 3)
}

# lo que ha aprendido HABLANDO, para "¿que has aprendido?" (M1)
function Get-BalanceCerebro {
    $rutaC = Join-Path $CerebroDir 'cerebro.json'
    if (-not (Test-Path -LiteralPath $rutaC)) { return '' }
    $c = $null
    try { $c = Get-Content -LiteralPath $rutaC -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return '' }
    $firmes = 0; $prov = 0; $otros = 0
    foreach ($r in @($c.recuerdos)) {
        if (-not $r -or $r.estado -eq 'rechazada') { continue }
        if ($r.tipo -eq 'respuesta') { if ($r.estado -eq 'firme') { $firmes++ } else { $prov++ } } else { $otros++ }
    }
    $temas = @()
    if ($c.temas) { $temas = @($c.temas.PSObject.Properties | Sort-Object { [int]$_.Value } -Descending | Select-Object -First 2 | ForEach-Object { $_.Name }) }
    if (($firmes + $prov + $otros) -eq 0) { return '' }
    $t = 'hablando contigo he aprendido ' + $(if ($firmes -eq 1) { 'una respuesta segura' } else { "$firmes respuestas seguras" })
    if ($prov -gt 0) { $t += " y tengo $prov por confirmar" }
    if ($otros -gt 0) { $t += ', ademas de ' + $(if ($otros -eq 1) { 'un recuerdo' } else { "$otros recuerdos" }) + ' de lo que hablamos' }
    if ($temas.Count -gt 0) { $t += '. Sueles hablarme de ' + ($temas -join ' y ') }
    return $t
}

function Initialize-Charla {
    if ($script:charlaProc -and -not $script:charlaProc.HasExited) { return $true }
    if (-not $ConversacionOn -or -not (Test-Path -LiteralPath $PyExe) -or -not (Test-Path -LiteralPath $CharlaWorker)) { return $false }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $PyWorker
        $embedArg = if ($ConversacionEmbed) { $ConversacionEmbed } else { '-' }
        $psi.Arguments = "-u `"$CharlaWorker`" $ConversacionModelo $ConversacionApi $embedArg `"$CerebroDir`" `"$PerfilPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.CreateNoWindow = $true
        $psi.WorkingDirectory = $LogDir
        $script:charlaProc = [System.Diagnostics.Process]::Start($psi)
        $script:charlaLectura = $null
        Log "charla: worker PID=$($script:charlaProc.Id) (local $ConversacionModelo, api $ConversacionApi)"
        return $true
    } catch {
        Log ("charla: el worker no arranco: " + $_.Exception.Message)
        $script:charlaProc = $null
        return $false
    }
}

# UNA TRADUCCION NO PUEDE DAR LA VUELTA A LO QUE PEDISTE (16/09). El 15/09 "cierra
# Google" volvio de la API como "Abre Google" y se abrio (y asi tres veces seguidas);
# y de "mi ubicacion es Tampa, busca el clima" salio "abre Hollow Knight", un juego
# que no habia nombrado nadie. Son los dos fallos que mas duelen, porque hacen lo
# CONTRARIO de lo pedido o abren algo que no pediste. Si pasa, no se hace nada y se
# pide repetir: mas vale un "no te entendi" que abrir lo que querias cerrar.
$VERBOS_OPUESTOS = @{
    'abre' = 'cierra'; 'cierra' = 'abre'; 'activa' = 'desactiva'; 'desactiva' = 'activa'
    'enciende' = 'apaga'; 'apaga' = 'enciende'; 'sube' = 'baja'; 'baja' = 'sube'
    'conecta' = 'desconecta'; 'desconecta' = 'conecta'; 'maximiza' = 'minimiza'
    'minimiza' = 'maximiza'; 'silencia' = 'desilencia'; 'pausa' = 'reproduce'; 'reproduce' = 'pausa'
}
function Test-TraduccionOpuesta([string]$original, [string]$propuesta) {
    if (-not $original -or -not $propuesta) { return $false }
    $po = @((ConvertTo-Plain $original) -split '\s+' | Where-Object { $VERBOS_OPUESTOS.ContainsKey($_) })
    $pp = @((ConvertTo-Plain $propuesta) -split '\s+' | Where-Object { $VERBOS_OPUESTOS.ContainsKey($_) })
    if ($po.Count -eq 0 -or $pp.Count -eq 0) { return $false }
    # solo el PRIMER verbo de cada uno: "abre steam y cierra discord" tiene los dos
    return ([string]$VERBOS_OPUESTOS[[string]$po[0]] -eq [string]$pp[0])
}
function Test-NombreInventado([string]$original, [string]$propuesta) {
    if (-not $propuesta -or -not $script:Juegos) { return $false }
    $plO = ' ' + (ConvertTo-Plain $original) + ' '
    $plP = ' ' + (ConvertTo-Plain $propuesta) + ' '
    foreach ($j in @($script:Juegos)) {
        $nJ = ConvertTo-Plain ([string]$j.nombre)
        # nombres cortos no: "peak" o "raft" aparecen dentro de cualquier frase
        if (-not $nJ -or $nJ.Length -lt 6) { continue }
        if (-not $plP.Contains(' ' + $nJ + ' ')) { continue }
        # EL JUEGO DICHO A MEDIAS NO ES UN INVENTO (16/09): "abre hollow knight" ->
        # "Hollow Knight Silksong" es lo que hay que hacer, porque nadie dice el
        # titulo entero. El invento es cuando NINGUNA palabra del titulo estaba en
        # lo que dijiste ("busca el clima" -> "abre Hollow Knight").
        $palJ = @($nJ -split '\s+' | Where-Object { $_.Length -ge 4 })
        if ($palJ.Count -gt 0) {
            $dichas = @($palJ | Where-Object { $plO.Contains(' ' + $_ + ' ') }).Count
            if ($dichas -ge [Math]::Ceiling($palJ.Count / 2.0)) { continue }
        } elseif ($plO.Contains($nJ)) { continue }
        return $true
    }
    return $false
}

# LA CHARLA SABE LO QUE NOVA SABE (16/09). El 15/09, 10 respuestas se inventaron el
# dato o dijeron "no tengo acceso" a cosas que el asistente tenia delante: la hora, el
# temporizador puesto hacia un minuto, el nivel, las descargas de Steam y el clima. Van
# con cada frase de charla, en texto corto. No es un modo ni una consulta mas: son datos
# que ya estan en memoria, leidos en el momento.
function Get-DatosNova {
    $d = @()
    try {
        $cul = New-Object System.Globalization.CultureInfo('es-MX')
        $ahora = Get-Date
        $d += 'son las ' + $ahora.ToString('H:mm', $cul) + ' del ' + $ahora.ToString('dddd d "de" MMMM "de" yyyy', $cul)
    } catch {}
    if ($script:clima) { $d += "el tiempo ahora: $($script:clima.desc), $($script:clima.temp) grados" }
    try {
        $bajando = @($script:Juegos | Where-Object { $_.bajando })
        if ($bajando.Count -gt 0) { $d += 'descargandose en Steam: ' + (($bajando | ForEach-Object { $_.nombre }) -join ', ') }
        else { $d += 'no hay nada descargandose en Steam' }
    } catch {}
    try {
        # los internos (sordina, descanso) no son "tus" temporizadores
        $tempos = @($script:temporizadores | Where-Object { -not $_.tipo -or $_.tipo -eq 'foco' })
        if ($tempos.Count -gt 0) {
            $d += 'temporizadores puestos: ' + (($tempos | ForEach-Object {
                $min = [Math]::Max(0, [int][Math]::Ceiling(($_.vence - $sw.ElapsedMilliseconds) / 60000))
                $q = if ($_.texto) { [string]$_.texto } else { 'aviso' }
                "$q (le quedan $min minutos)" }) -join '; ')
        } else { $d += 'no hay ningun temporizador puesto' }
    } catch {}
    # lo ultimo que se hizo, mientras este reciente: "¿creaste la nota?" (15/09)
    if ($script:ultimaOrden -and ($sw.ElapsedMilliseconds - [double]$script:ultimaOrden.cuando) -lt 600000) {
        $d += 'lo ultimo que hiciste por el fue: ' + [string]$script:ultimaOrden.desc
    }
    try { $n = Get-FraseNivel; if ($n) { $d += $n } } catch {}
    if ($script:juegoActivo) { $d += "tiene abierto el juego $($script:juegoActivo)" }
    return ($d -join '. ')
}

function Send-CharlaPedido($pedido, [bool]$arrancar = $true) {
    if ($arrancar) { if (-not (Initialize-Charla)) { return $false } }
    elseif (-not $script:charlaProc -or $script:charlaProc.HasExited) { return $false }
    try {
        # bytes UTF-8 directos, como con la voz: la tuberia no es UTF-8 por defecto
        $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $pedido -Compress) + "`n")
        $flujo = $script:charlaProc.StandardInput.BaseStream
        $flujo.Write($bytes, 0, $bytes.Length)
        $flujo.Flush()
        return $true
    } catch { Log ("charla: no pude escribir al worker: " + $_.Exception.Message); return $false }
}

function Send-Charla([string]$text, [bool]$duda = $false, [string]$op = 'hablar', $extra = $null) {
    if (-not $ConversacionOn -or -not $text) { return $false }
    $script:charlaId++
    # invitado: ni se aprende de lo que diga ni se le pone delante lo tuyo.
    # duda: "eso no es verdad", la ultima respuesta queda como incorrecta
    $pedido = @{ op = $op; id = $script:charlaId; texto = $text; invitado = [bool]$script:invitado; duda = $duda }
    if ($extra) { foreach ($k in @($extra.Keys)) { $pedido[$k] = $extra[$k] } }
    if ($script:juegoActivo) { $pedido.juego = [string]$script:juegoActivo }
    # ver LA CHARLA SABE LO QUE NOVA SABE. Solo al hablar: resumir mensajes o traducir
    # no necesitan nada de esto, y el invitado no ve nada suyo.
    if ($op -eq 'hablar' -and -not $script:invitado) {
        try { $dn = Get-DatosNova; if ($dn) { $pedido.datos = $dn } } catch {}
    }
    if (-not (Send-CharlaPedido $pedido)) { return $false }
    $script:charlaTexto = $text
    $script:charlaOp = $op
    $script:charlaFrases.Clear()
    $script:charlaEsperando = $true
    $script:charlaDesde = $sw.ElapsedMilliseconds
    $script:charlaRelleno = $false
    $script:charlaDescargada = $false
    $script:charlaSilencios = 0
    $script:seguimientoPendiente = $false     # se arma cuando termine de contestar
    if ($op -eq 'resumir') {
        Log "CHARLA (resumir mensajes): $($text.Length) caracteres"   # tus mensajes no van al log
    } else {
        Log "CHARLA ($op): $text"
        Add-Estadistica 'charla' $text
        try { Add-CharlaHora } catch {}
    }
    # si ya esta hablando (la orden de una frase mixta), que no se le corte la cara
    if ($sw.ElapsedMilliseconds -ge $script:pausaHasta) { Set-UI 'pensando' }
    return $true
}

# ¿PARECE CHARLA? (14/09): "estoy muy cansado hoy" iba a Claude Code como si
# fuera una orden (probado en vivo): Test-Charla solo da por charla las frases
# largas o en ingles, porque se hizo para DESCARTAR ruido. Esta es para
# CONVERSAR: lo que no empieza como una orden y suena a hablar de uno mismo o a
# comentario va a la charla. Si era algo que hacer, el modelo contesta [ORDEN] y
# vuelve al camino de las ordenes.
function Test-PareceCharla([string]$text) {
    $p = ConvertTo-Plain $text
    $p = ($p -replace '^(?:(?:hola|oye|ey|hey|nova|bueno|pues|y|vale|ok|mira|sabes|oyes)\s+)+', '').Trim()
    $w = @($p -split '\s+' | Where-Object { $_ })
    if ($w.Count -lt 2) { return $false }
    # "me encanta", "me siento", "te cuento": "me" abre ordenes ("me pones...") pero
    # con un verbo de sentir delante es hablar de uno mismo
    if ($p -match '^(?:me|te|nos)\s+(?:encanta|encantan|gusta|gustan|siento|paso|pasa|apetece|aburro|duele|preocupa|molesta|flipa|cae|parece|cuesta|agobia|alegra|cuento)\b') { return $true }
    $primera = $w[0]
    if ($VERBOS_OIDOS.ContainsKey($primera) -or ($VERBOS_LISTA -contains $primera) -or ($INICIO_ORDEN -contains $primera)) { return $false }
    if ($primera -match '^[a-z]{2,}[ae](?:me|le|te|lo|la|les|los|las|nos)$') { return $false }   # "ponme", "bajalo"
    return ($p -match '\b(estoy|estaba|estuve|me|mi|mis|yo|tengo|tenia|creo|pienso|siento|gusta|gustan|encanta|encantan|odio|hoy|ayer|vengo|acabo|fijate|imaginate|te cuento|que tal|como estas|que opinas|tu que|y tu)\b')
}

# VOZ CON EMOCION (M6): una frase de la charla que consuela se dice un pelo mas
# calmada; una que se alegra, un pelo mas viva. Lo demas, la voz de siempre.
function Get-EmocionFrase([string]$t) {
    $p = ConvertTo-Plain $t
    if ($p -match '\b(lo siento|vaya|que pena|animo|tranquil[oa]|no te preocupes|te entiendo|lamento|descansa|respira)\b') { return 'suave' }
    if ($t -match '!' -or $p -match '\b(genial|me alegro|que bien|felicidades|enhorabuena|jaja|increible|estupendo|fantastico|que guay)\b') { return 'alegre' }
    return ''
}

# ¿Se esta conversando AHORA (modelo cargado, ultima respuesta hace menos de 2
# min)? Entonces lo social ("que tal estas") lo contesta la charla y no una
# frase fija; en frio, la fija, que es instantanea.
function Test-CharlaCaliente {
    return [bool]($ConversacionOn -and $script:charlaProc -and -not $script:charlaProc.HasExited -and
                  ($sw.ElapsedMilliseconds - $script:charlaUltima) -lt 110000)
}

function Stop-Charla {
    if ($script:charlaEsperando -or $script:charlaFrases.Count -gt 0) {
        [void](Send-CharlaPedido @{ op = 'parar' } $false)
        Log "charla: cortada"
    }
    $script:charlaEsperando = $false
    $script:charlaFrases.Clear()
}

# Lo que va diciendo el worker, sin bloquear el bucle
function Receive-Charla {
    # la voz preparada se cierra sola a los 3 min sin charla (~40 MB que no hacen
    # falta fuera de una conversacion); se vuelve a abrir con la siguiente
    if ($script:prepVozProc -and ($sw.ElapsedMilliseconds - $script:prepVozUltima) -gt 180000) {
        try { $script:prepVozProc.StandardInput.Close() } catch {}
        try { $script:prepVozProc.Dispose() } catch {}
        $script:prepVozProc = $null
        Log "voz preparada: 3 min sin charla, se cierra"
    }
    if (-not $script:charlaProc) { return }
    if ($script:charlaProc.HasExited) {
        Log "charla: el worker se cerro"
        $script:charlaProc = $null
        $script:charlaLectura = $null
        if ($script:charlaEsperando) { $script:charlaEsperando = $false; Submit-Command $script:charlaTexto 'pregunta' }
        return
    }
    for ($n = 0; $n -lt 20; $n++) {
        if (-not $script:charlaLectura) { $script:charlaLectura = $script:charlaProc.StandardOutput.ReadLineAsync() }
        if (-not $script:charlaLectura.IsCompleted) { return }
        $linea = $script:charlaLectura.Result
        $script:charlaLectura = $null
        if ($null -eq $linea) { return }
        $ev = $null
        try { $ev = $linea | ConvertFrom-Json } catch { $ev = $null }
        if (-not $ev) { continue }
        if ($ev.ev -eq 'info') { Log "charla: $($ev.texto)"; continue }
        # el cerebro confirmo algo nuevo: un destello en la capsula (D1)
        if ($ev.ev -eq 'aprendido') { Log "charla: aprendido '$($ev.texto)'"; Send-UIEvento 'destello'; continue }
        # lo hablado un dia, resumido: al diario de ese dia (M10)
        if ($ev.ev -eq 'diario') { try { Add-DiarioResumen ([string]$ev.fecha) ([string]$ev.texto) } catch { Log ("diario: " + $_.Exception.Message) }; continue }
        # EL CEREBRO PROPIO: lo que la revision saco de la charla (llega cuando sea, sin id)
        if ($ev.ev -eq 'dato') {
            if (-not $script:invitado) { try { [void](Add-DatoPerfil ([string]$ev.texto) 'charla') } catch {} }
            continue
        }
        if ($ev.ev -eq 'correccion') {
            Log "charla: me equivoque, lo correcto es: $($ev.texto)"
            # solo si seguis hablando; si no, ya lo sabra para la proxima
            if (($sw.ElapsedMilliseconds - $script:charlaUltima) -lt 90000 -and -not $script:armed -and -not $script:charlaEsperando) {
                $script:charlaFrases.Enqueue(@{ t = ("Por cierto, antes me equivoque: " + [string]$ev.texto); o = 'api' })
            }
            continue
        }
        if ([int]$ev.id -ne $script:charlaId) { continue }   # de una respuesta ya cortada
        if ($ev.ev -eq 'frase') {
            $script:charlaFrases.Enqueue(@{ t = [string]$ev.texto; o = [string]$ev.origen })
            # la primera suena ya; las que vienen detras se preparan (ver VOZ PREPARADA)
            if ($script:charlaFrases.Count -gt 1 -or $script:vozFinReal -gt $sw.ElapsedMilliseconds) {
                Send-PrepVoz (Get-TextoVoz ([string]$ev.texto)) (Get-EmocionFrase ([string]$ev.texto))
            }
        } elseif ($ev.ev -eq 'fin') {
            $script:charlaEsperando = $false
            $script:charlaUltima = $sw.ElapsedMilliseconds
            Log "charla: contesto ($($ev.origen))"
            if ($ev.origen -ne 'parado') {
                # al acabar de hablar, vuelve a escuchar sola y con mas margen
                $script:seguimientoPendiente = $true
                $script:seguimientoFactor = 1.0
                $script:ventanaCharla = $true        # la ventana de charla, a tu ritmo (ver Get-VentanaSeguimiento)
                # tras la pregunta de trivia, lo proximo que digas es tu respuesta
                $script:triviaHasta = if ($ev.origen -eq 'trivia') { $sw.ElapsedMilliseconds + 90000 } else { 0 }
                if ($script:pausaHasta -le 0) { $script:pausaHasta = $sw.ElapsedMilliseconds + 100 }
            }
        } elseif ($ev.ev -eq 'orden') {
            $script:charlaEsperando = $false
            $ordenC = [string]$ev.texto
            Log ("charla: no era charla sino una orden -> '$ordenC'" + $(if ($ev.original -and [string]$ev.original -ne $ordenC) { " (dicho: '$($ev.original)')" } else { '' }))
            $script:seguimientoPendiente = $true
            # ORDENES DENTRO DE LA CHARLA (M10): ya reescrita con lo hablado. Primero
            # lo que Nova sabe hacer sola; si no, el camino de siempre
            $fastC = $null
            try { $fastC = Invoke-FastCommand $ordenC } catch { $fastC = $null }
            if ($fastC -and $script:pendiente) {
                Show-Popup $fastC
                Say $fastC
                Set-UI 'escuchando' $fastC
                Start-Confirmacion
            } elseif ($fastC) {
                Log "LOCAL (desde la charla): $ordenC -> $fastC"
                Send-UIEvento 'hecho'
                Say $fastC
            } elseif ($TraducirOn) { Submit-Command $ordenC 'traducir' } else { Submit-Command $ordenC }
        } elseif ($ev.ev -eq 'delegar') {
            # SIN API, UN DATO CONCRETO (14/09): el modelo local se lo inventaria
            # ("quien hizo Hollow Knight"), asi que la charla lo devuelve y va al
            # cerebro de preguntas, que busca de verdad
            $script:charlaEsperando = $false
            $datoC = [string]$ev.texto
            Log "charla: sin API, '$datoC' es un dato concreto; va al cerebro de preguntas"
            Submit-Command $datoC 'pregunta'
        } elseif ($ev.ev -eq 'err') {
            $script:charlaEsperando = $false
            if ($script:charlaOp -eq 'resumir') {
                # tus mensajes NUNCA van a otro cerebro: sin resumen, se leen tal cual
                Log "charla: no pude resumir los mensajes; los leo"
                Say $script:charlaTexto
            } elseif ($script:charlaOp -eq 'trivia') {
                Log "charla: la trivia fallo ($($ev.texto))"
                Say 'Ahora no puedo jugar.'
            } else {
                # ni el local ni la API: queda el cerebro de siempre, mejor que callarse
                Log "charla: sin respuesta ($($ev.texto)); se lo paso al cerebro"
                Submit-Command $script:charlaTexto 'pregunta'
            }
        }
    }
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
    # y en violeta, no en ambar: esto lo lleva la IA (ver Set-UI, "remoto")
    $script:uiRemoto = $true
    Set-UI 'pensando' $(if ($modo -eq 'accion') { 'Procesando' } elseif ($modo -eq 'traducir') { 'Entendiendo' } elseif ($modo -eq 'plan') { 'Viendo como hacerlo' } else { 'Pensando' })
    Add-Estadistica $modo $text

    $prompt = Expand-Prompt $text     # si pregunta por la memoria, ya viene guiado
    if ($modo -eq 'traducir') {
        $prompt = Build-PromptTraduccion $text
    } elseif ($modo -eq 'plan') {
        $prompt = Build-PromptPlan $text
    } elseif ($modo -ne 'accion' -and $prompt -eq $text) {
        $prompt = $PRE_HABLADO + $text
    } elseif ($modo -eq 'accion') {
        # La respuesta se LEE EN VOZ ALTA: el agente contesta como si
        # escribiera, y tres lineas ya son demasiado para escuchar.
        $prompt = "Al terminar, resume lo que hiciste en UNA frase corta, sin listas ni markdown, porque se leera en voz alta. " + $prompt
        # REGLA FIJA, delante de todo. El 12/09 "cierra todos los procesos"
        # llego aqui y el agente cerro Claude (con el usuario escribiendo en
        # el), la capsula, Steam y Discord, sin preguntar. El agente tiene
        # manos de verdad: lo que nunca debe tocar se le dice cada vez.
        $prompt = "REGLA FIJA: nunca cierres, mates ni reinicies estos procesos: nova_ui, powershell, pwsh, python, WindowsTerminal, OpenConsole, conhost, claude, opencode, node, explorer, ni ningun proceso del sistema; son el propio asistente y la sesion del usuario. Si la tarea es cerrar todos los programas o muchos a la vez, NO la hagas: contesta solo 'Para eso di: cierra todos los programas. Te pregunto antes de cerrar nada.' " + $prompt
    }
    # 'charla' encadena la sesion anterior: recuerda lo hablado antes
    $extra = if ($modo -eq 'charla') { '--continue' } else { '' }
    # captura de pantalla como contexto (el CLI admite --file)
    if ($adjunto -and (Test-Path -LiteralPath $adjunto)) {
        $extra = ($extra + ' --file ' + (ConvertTo-CmdArg $adjunto)).Trim()
        $prompt = "Te adjunto una captura de la ventana que tengo delante. " + $prompt
    }

    # A DONDE VA (15/09, elegido por braya: "capa local y API para conversaciones y
    # comandos basicos, Claude Code para las tareas pesadas, opencode de respaldo").
    # Medido con su uso real del 15/09: entender una frase por Claude Code tardaba
    # 8-11 s y por la API 1,3-1,7 s; una pregunta, 3-5 s por la API. Las tareas
    # ('accion') necesitan un agente con manos: esas van a Claude Code (35-90 s).
    # Si algo no arranca o falla, se baja un escalon: API -> Claude Code -> opencode.
    $script:jobAdjunto = $adjunto
    $porApi = ($ClaudeOn -and $modo -ne 'accion' -and (Test-Path -LiteralPath $ClaudeScript) -and (Test-ClaveClaude))
    if ($porApi -and -not $script:apiFallo) {
        # traducir devuelve una linea; hablar, una o dos frases
        $modelo = if ($modo -eq 'traducir' -or $modo -eq 'plan') { $ClaudeModeloRapido } else { $ClaudeModeloBueno }
        $tope = if ($modo -eq 'traducir') { 60 } elseif ($modo -eq 'plan') { 150 } else { 400 }
        # se guarda por si hay que rehacerla con Claude Code u opencode
        $script:jobPrompt = $prompt
        $script:jobExtra = $extra
        $script:jobPorApi = $true
        $script:jobPorCC = $false
        if (Start-ClaudeJob $prompt $modelo $tope $adjunto) { return }
        $script:jobPorApi = $false
        Log "la API no arranco; sigo con Claude Code"
    }
    if (Test-CerebroClaudeCode) {
        $script:jobPrompt = $prompt
        $script:jobExtra = $extra
        $script:jobPorApi = $false
        $script:jobPorCC = $true
        if (Start-ClaudeCodeJob $prompt $modo $adjunto) { return }
        $script:jobPorCC = $false
        Log "el cerebro (Claude Code) no arranco; sigo con opencode"
    }
    $script:jobPorApi = $false
    if (-not (Start-OpencodeJob $prompt $extra)) {
        Show-Popup "(no se pudo lanzar opencode; ver assistant.log)" 'error'
    }
}

# Formatea, registra y muestra la respuesta ya recogida.
function Report-Reply($out) {
    # ¿NO LLEGO A CONTESTAR EL CEREBRO? (no arranco, limite de uso, sesion
    # caducada). Entonces no hizo nada y la orden se rehace con opencode. Lo que
    # se quedo a medias en mitad de una tarea NO llega aqui como error: ver
    # Complete-OpencodeJob.
    if ($script:jobPorCC) {
        $script:jobPorCC = $false
        $crudoCC = ($out | Out-String)
        if ($crudoCC -match '^\s*\(error del cerebro:') {
            $motivoCC = (($crudoCC -replace '\s+', ' ').Trim())
            if ($motivoCC.Length -gt 240) { $motivoCC = $motivoCC.Substring(0, 240) + '...' }
            Log "CEREBRO FALLO, rehago con opencode: $motivoCC"
            # lo que no se arregla reintentando se deja de intentar hasta el
            # proximo arranque, para no sumar segundos a cada orden
            if ($crudoCC -match '(?i)limit|login|logged|auth|credit|subscription|not found|no se reconoce') {
                $script:ccFallo = $true
                Log "cerebro Claude Code desactivado hasta el proximo arranque"
            }
            $script:busy = $false
            # el respaldo (opencode --auto) solo para TAREAS: una traduccion o una
            # pregunta fallida no tienen por que ir a un agente con acceso al
            # disco (auditoria del 13/09)
            if ($script:jobPrompt -and $script:jobModo -eq 'accion') {
                if (Start-OpencodeJob $script:jobPrompt $script:jobExtra) { return }
            }
            Show-Popup "El modelo no contesto. Ver assistant.log." 'error'
            Say "No pude preguntarle al modelo"
            return
        }
    }
    # ¿FALLO LA API? Entonces la orden NO se pierde: se rehace con opencode,
    # que es lo que habia antes. Esto paso de verdad el 12/09 -la cuenta sin
    # saldo- y la orden se descartaba como si fuera ruido, que es el peor final
    # posible: el usuario habla, no pasa nada y nadie dice por que.
    if ($script:jobPorApi) {
        $script:jobPorApi = $false
        $crudo = ($out | Out-String)
        if ($crudo -match '\(error de la API:|\(falta la clave|\(la API no devolvio|\(prompt vacio\)') {
            $motivo = (($crudo -replace '\s+', ' ').Trim())
            if ($motivo.Length -gt 200) { $motivo = $motivo.Substring(0, 200) + '...' }
            Log "API FALLO, rehago con opencode: $motivo"
            # sin saldo o con la clave mala, TODAS las siguientes van a fallar
            # igual: se deja de intentar hasta el proximo arranque, para no
            # anadir un segundo de espera a cada orden para nada
            if ($crudo -match 'credit balance|authentication_error|invalid x-api-key|permission') {
                $script:apiFallo = $true
                Log "API desactivada hasta el proximo arranque (el error no se arregla reintentando)"
            }
            $script:busy = $false
            # primero Claude Code, que entiende igual de bien; opencode, si tampoco
            if ($script:jobPrompt -and (Test-CerebroClaudeCode)) {
                $script:jobPorCC = $true
                if (Start-ClaudeCodeJob $script:jobPrompt $script:jobModo $script:jobAdjunto) { Log "API FALLO: lo rehace Claude Code"; return }
                $script:jobPorCC = $false
            }
            if ($script:jobPrompt) {
                if (Start-OpencodeJob $script:jobPrompt $script:jobExtra) { return }
            }
            Show-Popup "El modelo no contesto. Ver assistant.log." 'error'
            Say "No pude preguntarle al modelo"
            return
        }
    }
    # --- respuesta a una peticion de TRADUCCION ---
    # El modelo solo propone texto; aqui se VALIDA contra el vocabulario cerrado
    # y solo se ejecuta si la capa local lo reconoce. Nunca se ejecuta texto
    # libre devuelto por el modelo.
    # EL PLAN (ver TAREAS SIN EL AGENTE): varias ordenes locales en vez de una tarea del
    # agente. Se comprueban TODAS antes de hacer ninguna; si una sola no vale, no se hace
    # nada y la peticion sigue su camino de siempre.
    if ($script:jobModo -eq 'plan') {
        $script:jobModo = ''
        $originalP = $script:jobTextoOriginal
        $ordenesP = @(Split-Plan (($out | Out-String)))
        $malaP = ''
        foreach ($oP in $ordenesP) {
            $okP = $false
            try { $okP = [bool](Test-FastCommand $oP) } catch { $okP = $false }
            if (-not $okP) { $malaP = $oP; break }
        }
        if ($ordenesP.Count -gt 0 -and -not $malaP) {
            Log ("PLAN: '$originalP' -> " + ($ordenesP -join ' | '))
            Add-Estadistica 'plan-sirvio' ("$originalP -> " + ($ordenesP -join ' | '))
            $hechasP = @()
            foreach ($oP in $ordenesP) {
                $rP = $null
                try { $rP = Invoke-FastCommand $oP } catch { $rP = $null }
                if (-not $rP) {
                    # a mitad: se dice lo que si se hizo y el resto va al agente
                    Log "PLAN: '$oP' no se pudo hacer; el resto va al agente"
                    Add-Estadistica 'plan-a-medias' $oP
                    if ($hechasP.Count -gt 0) { Say (($hechasP -join ', ') + '. Lo demas lo miro.') }
                    Submit-Command $originalP 'accion'
                    return
                }
                $hechasP += $rP
            }
            $script:ultimaOrden = @{ texto = $originalP; desc = ($hechasP -join ', '); cuando = $sw.ElapsedMilliseconds }
            $script:ultimaRespuesta = ($hechasP -join ', ')
            Send-UIEvento 'hecho'
            Show-Popup $script:ultimaRespuesta
            Say $script:ultimaRespuesta
            return
        }
        Log "PLAN: no sale con ordenes que yo sepa hacer$(if ($malaP) { " ('$malaP')" }); va al agente"
        Add-Estadistica 'plan-no' $originalP
        Submit-Command $originalP 'accion'
        return
    }
    if ($script:jobModo -eq 'traducir') {
        $script:jobModo = ''
        # VARIAS ORDENES (15/09): una por linea, y se juntan con " y ", que la capa local
        # ya encadena ("abre steam y sube el brillo"). Antes las lineas se pegaban con un
        # espacio y la segunda orden podia perderse o mezclarse con la primera.
        $propuesta = ((@(($out | Out-String) -split '[\r\n]+') | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }) -join ' y ')
        $propuesta = ($propuesta -replace '\s+', ' ').Trim()
        # SIN HUECOS (15/09): "cierra steam y pon un temporizador de <n> minutos" no se pudo
        # hacer entera y no se hizo nada. Lo que lleva un hueco se quita y el resto se hace.
        if ($propuesta -match '<[^>]*>') {
            $sinHueco = @(($propuesta -split ' y ') | Where-Object { $_ -notmatch '<[^>]*>' })
            Log "traduccion con huecos sin rellenar ('$propuesta'): me quedo con '$($sinHueco -join ' y ')'"
            $propuesta = ($sinHueco -join ' y ').Trim()
        }
        # [string]: si Haiku no devolvio nada, $propuesta es $null y .Trim() tumbaba
        # el asistente entero (auditoria del 13/09)
        $propuesta = ([string]$propuesta).Trim().Trim('"').Trim("'")
        $original = $script:jobTextoOriginal
        $veredicto = if ($propuesta) { $propuesta.ToUpperInvariant().Trim('.', ' ') } else { '' }
        # El modelo tiene la ultima palabra sobre si esto era una orden. Casi
        # nada de lo que llega hasta aqui lo dijo el usuario: es audio que el
        # microfono le robo a un video, al juego o a alguien hablando al lado.
        # Escalarlo al agente por si acaso -con --auto y todo Documents- era
        # regalarle el disco a una frase que nadie pronuncio, y encima costaba
        # entre 25 y 160 s de espera por cada ruido.
        if (-not $propuesta -or $veredicto -eq 'NO') {
            # NO ES UNA ORDEN, PERO ES TUYO (16/09). Callarse esta bien para el ruido de
            # un video, pero el 15/09 se comio cinco peticiones de verdad ("mira por que
            # no me dices cuanto espacio libre me queda") y braya se quedo hablando solo.
            # Si es espanol claro, largo y con TU voz, no es ruido: es charla.
            if ($ConversacionOn -and -not $script:invitado -and (Test-EspanolLargo $original) -and -not (Test-VozExtrana)) {
                Log "NO era una orden, pero es espanol tuyo: '$original' -> a la charla"
                Add-Estadistica 'no-orden-a-charla' $original
                if (Send-Charla $original) { return }
            }
            Log "NO era una orden: '$original' (descartado, no llega al agente)"
        $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
            Add-Estadistica 'ruido' $original
            Add-RuidoRacha
            Send-UIEvento 'gesto:confuso'
            Show-Popup "No te entendi. Repitelo." 'error'
            Say "No te entendi"
            Open-EscuchaTrasNoEntendi
            return
        }
        # Peticion de verdad, pero fuera del vocabulario local: para eso esta
        # el agente. Esta es la UNICA puerta que le queda abierta a la voz.
        if ($veredicto -eq 'TAREA') {
            # ANTES DEL AGENTE, EL PLAN (16/09): muchas "tareas" son dos o tres ordenes
            # que Nova ya sabe hacer dichas de una vez, y el agente cuesta 35-90 s.
            if ($ClaudeOn -and (Test-Path -LiteralPath $ClaudeScript) -and (Test-ClaveClaude) -and -not $script:apiFallo) {
                Log "peticion fuera del vocabulario local: pruebo a hacerla con ordenes mias"
                Submit-Command $original 'plan'
                return
            }
            Log "peticion fuera del vocabulario local: va al agente completo"
            Submit-Command $original 'accion'
            return
        }
        if ($propuesta.Length -lt 200) {
            Log "traduccion propuesta: '$original' -> '$propuesta'"
            # ¿es una TAREA APRENDIDA dicha con otras palabras? Haiku conoce las
            # recetas (Build-PromptTraduccion) y contesta con la plantilla
            # rellena. Entonces se pregunta, se hace en local y, si sale bien,
            # esa forma de decirlo se aprende para que la proxima no pase por aqui.
            $recP = $null
            if ($RecetasOn) { try { $recP = Find-Receta $propuesta } catch { $recP = $null } }
            if ($recP) {
                $variante = $null
                try { $variante = Get-VarianteReceta $original $recP.valores } catch { $variante = $null }
                $script:pendiente = @{ texto = ''; vence = 0; tipo = 'receta'; id = $recP.receta.id; valores = $recP.valores; original = $original; variante = $variante }
                $preguntaV = "¿Hago esto: " + (Get-TextoReceta $recP.receta 'resumen' $recP.valores) + "?"
                Log "RECETA $($recP.receta.id) dicha con otras palabras: '$original' -> '$propuesta' (forma nueva: '$variante')"
                Say $preguntaV
                Set-UI 'escuchando' $preguntaV
                Start-Confirmacion
                return
            }
            $r = $null
            # Una traduccion del modelo no se pregunta por parecido: o encaja o
            # no. Pero OJO con como se hace: antes se usaba $script:confirmado,
            # que significa 'el usuario ya dijo que si' y apaga TAMBIEN las
            # confirmaciones de las acciones que no se deshacen. O sea que una
            # propuesta nacida de un ruido ('cierra todos los programas', 'abre
            # SILENT BREATH en steam') se ejecutaba a la primera. $sinDudosa
            # silencia solo la pregunta por parecido, que es lo que se queria.
            $script:sinDudosa = $true
            # ver UNA TRADUCCION NO PUEDE DAR LA VUELTA A LO QUE PEDISTE
            $vuelta = $false
            try { $vuelta = (Test-TraduccionOpuesta $original $propuesta) -or (Test-NombreInventado $original $propuesta) } catch { $vuelta = $false }
            if ($vuelta) {
                Log "TRADUCCION RECHAZADA: '$original' -> '$propuesta' (le da la vuelta a lo pedido o mete un nombre que no dijiste)"
                Add-Estadistica 'traduccion-rechazada' "$original -> $propuesta"
                $script:seguimientoPendiente = $false
                Send-UIEvento 'gesto:confuso'
                Show-Popup "No te entendi. Repitelo." 'error'
                Say "No te entendi"
                Open-EscuchaTrasNoEntendi
                return
            }
            $script:preguntarTraduccion = (Test-OidoDudoso $original)
            try { $r = Invoke-FastCommand $propuesta } catch { $r = $null }
            $script:sinDudosa = $false
            $script:preguntarTraduccion = $false
            if ($r -and $script:pendiente) {
                # la capa local pregunta antes de hacerlo (mal oido, voz extrana, ya rechazada):
                # antes aqui se decia la pregunta pero nadie esperaba la respuesta
                Log "CONFIRMAR (traduccion): '$original' -> '$propuesta' -> $r"
                Show-Popup $r
                Say $r
                Set-UI 'escuchando' $r
                Start-Confirmacion
                return
            }
            if ($r) {
                # SOLO SE APRENDE LO QUE SE PUEDE REPETIR (15/09). Se aprendieron "abre la carpeta
                # Games" = "abre explorador", "cierra Google" = "cierra edge" y frases de 15 palabras
                # que no se van a volver a decir igual. No se aprende una frase de mas de 6 palabras,
                # ni una traduccion que pierde un nombre propio de lo dicho, ni una con letras rotas.
                $palO = @((ConvertTo-Plain $original) -split '\s+' | Where-Object { $_ })
                $plProp = ' ' + (ConvertTo-Plain $propuesta) + ' '
                $nombreFuera = @([regex]::Matches($original, '(?<=\S\s)\p{Lu}\p{L}{3,}') | Where-Object { -not $plProp.Contains(' ' + (ConvertTo-Plain $_.Value) + ' ') }).Count -gt 0
                if (Test-OidoDudoso $original) {
                    Log "no aprendo '$original' = '$propuesta': venia de un oido que dudaba (ver NO APRENDER DE LO MAL OIDO)"
                } elseif ($palO.Count -gt 6 -or $nombreFuera -or $propuesta.Contains([string][char]0xFFFD)) {
                    Log "no aprendo '$original' = '$propuesta': frase larga o con un nombre que la traduccion no conserva (ver SOLO SE APRENDE LO QUE SE PUEDE REPETIR)"
                } else {
                    Add-Traduccion $original $propuesta
                }
                $script:ultimaAprendida = $original
                Add-Estadistica 'traducida' "$original -> $propuesta"
                $script:ultimaRespuesta = $r
                Send-UIEvento 'hecho'
                Show-Popup $r
                Say $r
                # AUTOAPRENDIZAJE: si la diferencia es UNA palabra ("calcu" ->
                # "calculadora"), se propone aprenderla como alias para que
                # valga en cualquier frase, no solo en esta
                try {
                    $gen = if (Test-OidoDudoso $original) { $null } else { Find-Generalizacion $original $propuesta }
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
            Add-RuidoRacha
            $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
            Send-UIEvento 'gesto:confuso'
            Show-Popup "No te entendi. Repitelo." 'error'
            Say "No te entendi"
            Open-EscuchaTrasNoEntendi
            return
        }
    }

    # --- ¿trae una RECETA? Se aprende y se quita de lo que se dice (ver RECETAS) ---
    # --- DATOS sobre ti que haya descubierto el cerebro: se guardan y no se dicen (ver PERFIL) ---
    $textoDatos = ($out | Out-String)
    $mDatos = [regex]::Matches($textoDatos, '(?m)^[ \t]*DATO:[ \t]*(.+?)[ \t]*$')
    if ($mDatos.Count -gt 0) {
        foreach ($md in @($mDatos | Select-Object -First 2)) { try { [void](Add-DatoPerfil $md.Groups[1].Value 'el cerebro') } catch {} }
        $out = @(([regex]::Replace($textoDatos, '(?m)^[ \t]*DATO:.*$\r?\n?', '')).Trim())
    }

    $textoOut = ($out | Out-String)
    # ¿esta respuesta es la de una receta que fallo y se esta reparando?
    $rep = $null
    if ($script:reparandoReceta -and $script:reparandoReceta.texto -eq $script:jobTextoOriginal) { $rep = $script:reparandoReceta }
    $script:reparandoReceta = $null
    $mRec = [regex]::Match($textoOut, '(?m)^[ \t]*RECETA:[ \t]*')
    if ($mRec.Success) {
        $bloqueRec = $textoOut.Substring($mRec.Index + $mRec.Length).Trim()
        $out = @($textoOut.Substring(0, $mRec.Index).Trim())
        if ($bloqueRec -match '^(?i)no\b') {
            # el motivo viene detras del NO (pantalla, contenido, externo, destructivo,
            # inseguro, charla): sin el no habia forma de saber que se puede mejorar
            $motivoRec = ''
            if ($bloqueRec -match '^(?i)no[ \t:,-]+([a-z]+)') { $motivoRec = $Matches[1].ToLowerInvariant() }
            Log ("RECETA: el cerebro dice que esto no se puede repetir igual" + $(if ($motivoRec) { " (motivo: $motivoRec)" } else { '' }))
            Add-Estadistica 'receta-no' $(if ($motivoRec) { $motivoRec } else { 'sin motivo' })
        } elseif ($RecetasOn -and $script:jobModo -eq 'accion' -and $script:ccConHerramientas -and -not $script:invitado) {
            # lo que habia que conservar de la receta rota, ANTES de aprender la
            # nueva: si trae la misma plantilla, Add-Receta sustituye a la vieja
            $datosRota = $null
            if ($rep) {
                # OJO: primero a una variable. Get-Recetas devuelve la lista
                # envuelta (",lista"): por tuberia directa, Where-Object veria la
                # lista entera como UN objeto, no receta a receta
                $gAntes = Get-Recetas
                $rotaAntes = $gAntes | Where-Object { $_.id -eq $rep.id } | Select-Object -First 1
                if ($rotaAntes) { $datosRota = @{ usos = [int]$rotaAntes.usos; confirmadas = [int]$rotaAntes.confirmadas; frase = [string]$rotaAntes.frase; variantes = @($rotaAntes.variantes) } }
            }
            $nuevaRec = $null
            try { $nuevaRec = Add-Receta $script:jobTextoOriginal $bloqueRec } catch { Log ("RECETA: " + $_.Exception.Message) }
            if ($nuevaRec -and $datosRota) {
                # la reparada ocupa el sitio de la rota: si el cerebro uso otra
                # plantilla, la vieja se quita y sus formas de decirlo pasan a esta
                $gRep = Get-Recetas
                foreach ($x in @($gRep | Where-Object { $_.id -eq $rep.id -and -not [object]::ReferenceEquals($_, $nuevaRec) })) { [void]$gRep.Remove($x) }
                foreach ($pl in (@($datosRota.frase) + @($datosRota.variantes))) { if ($pl) { Add-VarianteReceta $nuevaRec ([string]$pl) } }
                $nuevaRec.usos = $datosRota.usos
                $nuevaRec.confirmadas = $datosRota.confirmadas
                $nuevaRec.fallos = 0
                Save-Recetas
                Log "RECETA $($nuevaRec.id) reparada por el cerebro (era la $($rep.id))"
                Add-Estadistica 'receta-reparada' ([string]$nuevaRec.frase)
                $script:ultimaReceta = $nuevaRec.id
                $script:ultimaRecetaEn = $sw.ElapsedMilliseconds
                $out = @(([string]$out[0]).TrimEnd() + ' Y ya arregle lo que habia aprendido.')
            } elseif ($nuevaRec) {
                $script:ultimaReceta = $nuevaRec.id
                $script:ultimaRecetaEn = $sw.ElapsedMilliseconds
                $out = @(([string]$out[0]).TrimEnd() + ' Aprendido para la proxima.')
            }
        }
    }
    if ($rep -and -not ($mRec.Success)) { Log "RECETA $($rep.id): el cerebro hizo la tarea pero no devolvio receta; se queda como estaba, con su fallo apuntado" }
    # si de esta respuesta salio algo aprendido (receta, reparacion o dato), se celebra
    if ($script:acabaDeAprender) { Send-UIEvento 'gesto:aprendido' }

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
    # "ABRELO" DESPUES DE QUE NOVA NOMBRE UN JUEGO (16/09). El 15/09 "¿puedes abrirlo?"
    # abrio Steam: el pronombre solo miraba el ultimo objetivo LOCAL, y el juego lo
    # acababa de nombrar el agente en esta misma respuesta.
    try {
        $plR = ' ' + (ConvertTo-Plain $reply) + ' '
        foreach ($jR in @($script:Juegos)) {
            $nR = ConvertTo-Plain ([string]$jR.nombre)
            if ($nR -and $nR.Length -ge 6 -and $plR.Contains(' ' + $nR + ' ')) {
                $script:ultimoObjetivo = [string]$jR.nombre
                Log "el pronombre apunta ahora a '$($jR.nombre)' (lo nombro la respuesta)"
                break
            }
        }
    } catch {}
    # tarea larga terminada: un pulso largo en el mando, por si estabas jugando
    if (($sw.ElapsedMilliseconds - $script:jobStart) -ge 8000) { Start-Vibracion @(220) 24000 }
    $eraSinTarjeta = [bool]$script:respuestaSinTarjeta
    # la traduccion de la pantalla se oye, no se lee en una tarjeta (ver TRADUCIR LA PANTALLA)
    if ($script:respuestaSinTarjeta) {
        $script:respuestaSinTarjeta = $false
        $script:sinTarjeta = $true
        $script:sinTarjetaEn = $sw.ElapsedMilliseconds
    }
    # la respuesta era DONDE TE QUEDASTE en un juego: se guarda como su nota
    if ($script:notaJuegoPendiente) {
        $jN = [string]$script:notaJuegoPendiente
        $script:notaJuegoPendiente = $null
        $notaN = (($reply -replace '["\.]', '') -replace '\s+', ' ').Trim()
        if ($notaN -and $notaN -notmatch '(?i)no lo se|error del cerebro|^\(' -and $notaN.Length -le 80) {
            Set-NotaJuego $jN $notaN
            Log "JUEGOS: nota para $jN (leida de la pantalla) -> $notaN"
            $reply = "Apuntado: en $jN te quedaste en $notaN."
        } else {
            $reply = "No pude saber donde te quedaste. Dime: me quede en..."
        }
    }
    # "me voy a dormir" con un juego delante: apuntado donde te quedaste, la rutina (F3)
    if ($script:rutinaDormirTrasNota) {
        $script:rutinaDormirTrasNota = $false
        try { $reply = "$reply " + (Invoke-RutinaDormir) } catch {}
    }
    # EL CEREBRO APRENDE TAMBIEN DE CLAUDE CODE (M4): lo que contesto a una
    # pregunta pasa al cerebro propio como respuesta de la API (firme si es
    # conocimiento general; el revisor saca ademas datos y temas). No lo que era
    # leer o traducir la pantalla, ni lo de un invitado.
    if ($ConversacionOn -and $script:jobModo -in @('pregunta', 'charla') -and -not $eraSinTarjeta -and -not $script:invitado -and
        $reply -notmatch '^\(' -and $script:jobTextoOriginal) {
        try { [void](Send-CharlaPedido @{ op = 'aprender'; pregunta = [string]$script:jobTextoOriginal; respuesta = $reply; origen = 'api' }) } catch {}
    }
    Show-Popup $reply
    Say $reply
    # la rutina de dormir pregunto por el despertador: se espera el si o el no
    if ($script:pendiente -and $script:pendiente.tipo -eq 'despertador') { Set-UI 'escuchando' $reply; Start-Confirmacion }
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
    $script:confirmaFin = 0; $script:confirmaTotal = 0
    Remove-Item -LiteralPath $MarcaConfirmar -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $RutaConfirmacion -Force -ErrorAction SilentlyContinue
    if (-not $p) { return }
    # DESCANSO TRAS EL FOCO (ver MODO FOCO)
    if ($p.tipo -eq 'descanso') {
        if ($respuesta -eq 'si') {
            [void]$script:temporizadores.Add(@{ vence = $sw.ElapsedMilliseconds + 300000; texto = 'se acabo el descanso'; total = 300000; tipo = 'descanso' })
            Send-UIEvento 'hecho'
            Set-UI 'hablando' 'Descanso: 5 minutos' 3000
        } else {
            Set-UI 'reposo'
        }
        return
    }
    # MODO INVITADO PROPUESTO (M7)
    if ($p.tipo -eq 'invitadoAuto') {
        if ($respuesta -eq 'si') {
            $script:invitado = $true
            $script:invitadoUltimo = $sw.ElapsedMilliseconds
            Log "MODO INVITADO: dentro (propuesto por voz ajena)"
            Send-UIEvento 'hecho'
            Say 'Modo invitado puesto. Se quita solo en media hora sin ordenes.'
        } else { Set-UI 'reposo' }
        return
    }
    # ¿TE PONGO EL DESPERTADOR? (rutina de dormir)
    if ($p.tipo -eq 'despertador') {
        if ($respuesta -eq 'si') {
            $script:despertadorHora = $sw.ElapsedMilliseconds + 60000
            $script:seguimientoPendiente = $true
            Say '¿A que hora?'
        } else { Say 'Buenas noches.' }
        return
    }
    # APAGADO PROGRAMADO (F3)
    if ($p.tipo -in @('apagado', 'reinicio')) {
        if ($respuesta -eq 'si') {
            $esReinicio = ($p.tipo -eq 'reinicio')
            # "ya" son 30 s: da tiempo a decir "cancela el apagado"
            $segA = [Math]::Max(30, [int]$p.min * 60)
            try {
                Start-Process -FilePath 'shutdown.exe' -ArgumentList @($(if ($esReinicio) { '/r' } else { '/s' }), '/t', [string]$segA) -WindowStyle Hidden
                Log "$(if ($esReinicio) { 'REINICIO' } else { 'APAGADO' }): en $segA s"
                $cuandoA = if ([int]$p.min -gt 0) { Format-MinutosDichos ([int]$p.min) } else { '30 segundos' }
                Say ($(if ($esReinicio) { 'Me reinicio en ' } else { 'Me apago en ' }) + $cuandoA + '. Di cancela el apagado si cambias de idea.')
            } catch { Say 'No pude programarlo.' }
        } else { Set-UI 'reposo' }
        return
    }
    # MODO AHORRO PARA LLEGAR A UNA HORA (ver 'bateriaHasta')
    if ($p.tipo -eq 'ahorroEnergia') {
        if ($respuesta -eq 'si') {
            $okAE = $false
            try { $okAE = Set-ModoEnergia 'ahorro' } catch {}
            Send-UIEvento 'hecho'
            Set-UI 'hablando' $(if ($okAE) { 'Modo ahorro puesto' } else { 'No pude cambiar el modo' }) 2500
        } else {
            Set-UI 'reposo'
        }
        return
    }
    # AHORRO CON LA BATERIA BAJA JUGANDO (ver el aviso de bateria)
    if ($p.tipo -eq 'ahorro') {
        if ($respuesta -eq 'si') {
            try { Set-Brillo 30 } catch {}
            Send-UIEvento 'hecho'
            Set-UI 'hablando' 'Brillo al 30%' 2500
        } else {
            Set-UI 'reposo'
        }
        return
    }
    # PROPUESTA DE AUTOMATIZAR UNA COSTUMBRE (ver HABITOS)
    if ($p.tipo -eq 'propuesta') {
        $pr = $p.propuesta
        if ($respuesta -eq 'si' -and $pr.tipo -eq 'secuencia') {
            # tres ordenes seguidas -> un MODO con las tres (ver Find-Propuesta, 3).
            # Se llama "rutina" (o "rutina 2", "rutina 3"... si ya hay).
            $hbS = Get-Habitos
            [void]$hbS.rechazadas.Add($pr.clave)
            Save-Habitos
            $nomS = 'rutina'; $nS = 1
            while (Test-Prop $script:cmds.perfiles $nomS) { $nS++; $nomS = "rutina $nS" }
            $okS = Add-Perfil $nomS ([string[]]@($pr.ordenes))
            Log "PROPUESTA secuencia aceptada: modo $nomS ($okS)"
            Send-UIEvento $(if ($okS) { 'hecho' } else { 'error' })
            Say $(if ($okS) { "Hecho. Cuando digas modo $nomS, lo hago todo." } else { 'No pude crear el modo.' })
            return
        }
        if ($respuesta -eq 'si') {
            # que no se cuele nada destructivo en una regla que corre sola, y que
            # la accion sea una orden que Nova sepa hacer (como al crear reglas)
            if ((ConvertTo-Plain $pr.accion) -match '^(?:cierra|apaga|reinicia|bloquea|borra|elimina)\b|\b(?:todo|todos|todas)\b' -or -not (Test-FastCommand $pr.accion)) {
                Log "PROPUESTA descartada al aceptar: '$($pr.accion)' no puede ir en una regla"
                Say "Eso mejor me lo sigues pidiendo tu."
                Set-UI 'reposo'
                return
            }
            $tipoP = $pr.tipo; $valorP = $pr.valor
            if ($tipoP -eq 'appAbre') {
                # lo que se abria puede ser una app o un juego: la regla es distinta
                # y el nombre tiene que ser el que usa el vigilante de reglas
                $suj = Resolve-SujetoRegla $pr.valor
                if (-not $suj) { Say "Uy, ya no se que es $($pr.valor). Lo dejo."; Set-UI 'reposo'; return }
                $tipoP = if ($suj.app) { 'appAbre' } else { 'juegoAbre' }
                $valorP = $suj.nombre
            }
            $gP = Get-Reglas
            $idP = 1; foreach ($x in $gP) { if ($x.id -ge $idP) { $idP = $x.id + 1 } }
            $rP = @{ id = $idP; tipo = $tipoP; valor = $valorP; accion = $pr.accion; ultima = '' }
            [void]$gP.Add($rP); Save-Reglas
            Log ("REGLA $idP guardada (propuesta aceptada): " + (Describe-Regla $rP))
            # aceptada: no se vuelve a proponer (el nombre guardado en la regla puede
            # no coincidir con lo dicho, "navegador" frente a "Microsoft Edge")
            $hbA = Get-Habitos
            [void]$hbA.rechazadas.Add($pr.clave)
            Save-Habitos
            Set-AcabaDeAprender
            Send-UIEvento 'hecho'
            Say "Hecho. Me encargo yo."
        } elseif ($respuesta -eq 'no') {
            $hbN = Get-Habitos
            [void]$hbN.rechazadas.Add($pr.clave)
            Save-Habitos
            Log "PROPUESTA rechazada: $($pr.clave)"
            Say "Vale, no te lo vuelvo a proponer."
        }
        Set-UI 'reposo'
        return
    }
    # EL DATO DUDOSO DE UNA RECETA (M7): si, se hace; no, se pide otra vez SIN
    # castigar a la receta (lo que fallo fue el oido, no ella)
    if ($p.tipo -eq 'recetaDato') {
        $gD = Get-Recetas
        $objD = @($gD | Where-Object { $_.id -eq $p.id })
        if ($respuesta -eq 'si' -and $objD.Count -gt 0) {
            [void](Start-Receta @{ receta = $objD[0]; valores = $p.valores } $p.original)
        } elseif ($respuesta -eq 'no') {
            $script:seguimientoPendiente = $true
            Say 'Vale, dimelo otra vez.'
        } else { Set-UI 'reposo' }
        return
    }
    # pregunta de una RECETA ("esto ya lo aprendi: ... ¿lo hago?")
    if ($p.tipo -eq 'receta') {
        $gR = Get-Recetas
        $objR = @($gR | Where-Object { $_.id -eq $p.id })
        if ($objR.Count -eq 0) { Set-UI 'reposo'; return }
        if ($respuesta -eq 'si') {
            # si sale bien, esa forma de decirlo queda aprendida (lo hace
            # Complete-RecetaResultado, tambien si la receta acaba en segundo plano)
            [void](Start-Receta @{ receta = $objR[0]; valores = $p.valores } $p.original ([string]$p.variante))
        } elseif ($respuesta -eq 'no') {
            $objR[0].rechazos = [int]$objR[0].rechazos + 1
            if ($objR[0].rechazos -ge 2) {
                [void]$gR.Remove($objR[0])
                Log "RECETA $($p.id) olvidada: dos veces que no"
                Say "Vale. Y la olvido."
            } else {
                Say "Vale, lo dejo."
            }
            Save-Recetas
        } else {
            Set-UI 'reposo'
        }
        return
    }
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
    # DIJISTE QUE SI: entonces la querias. Se quita de la lista de rechazadas,
    # o se quedaria preguntando por ella el resto de su vida.
    if ($respuesta -eq 'si' -and $p.tipo -eq 'rechazada') { $null = Remove-Rechazo $p.texto }
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
# DICTADO LARGO. Un modo, que es justo lo que se evita en esta base de codigo,
# asi que lleva TRES salidas: la frase ("ya esta", "para de dictar"), el boton
# mantenido, y un plazo. Ademas la capsula lo dice todo el rato. Un modo que
# escribe en la ventana de delante y del que no se sabe salir seria lo peor que
# hay aqui dentro.
$DictadoLargoMs = [int](Get-Cfg 'input' 'dictadoLargoMinutos' 10) * 60000
# CON QUE SE DICTA LO LARGO.
# "windows" = Win+H, el dictado de voz de Windows 11. Es OTRO motor que el de
# la API (SpeechRecognitionTopicConstraint), que en esta maquina rechaza todo:
# Win+H reconoce EN LA NUBE y entiende bien; el de la API es el local de
# OneCore y no da una. Medido el 12/09, seis rondas seguidas con el microfono
# para el solo: seis rechazos con texto vacio.
# El pero de Win+H siempre fue que ROBA EL FOCO. Para una orden suelta eso es
# inservible mientras juegas, pero para el dictado largo da igual: el foco TIENE
# que estar en la ventana donde se escribe, que es justo lo que hace falta. Y
# escribe Windows directamente, asi que no hay que teclear nada ni acertar con
# la transcripcion.
# "propio" = el camino de Whisper, escribiendo con SendKeys. Se queda por si
# algun dia Win+H no esta o molesta.
$DictadoLargoMotor = [string](Get-Cfg 'input' 'dictadoLargoMotor' 'windows')

# CADA MOTOR DONDE SIRVE.
# Win+H (el dictado de Windows, que reconoce en la nube) entiende muchisimo
# mejor: medido con las 20 grabaciones, Whisper acierta 8 de 20 con el modelo
# rapido; Win+H escribio 900 caracteres casi sin un error. Pero para leer lo que
# dices hay que traer al frente la ventana del asistente, y con un juego a
# pantalla completa eso te saca de la partida.
# Asi que se elige por situacion: jugando, Whisper (no molesta); el resto del
# tiempo, Win+H (acierta). "auto" es eso; "worker" fuerza Whisper siempre y
# "windows" fuerza Win+H siempre.
$DictadoMotor = [string](Get-Cfg 'input' 'motorOrdenes' 'auto')
$script:dictandoLargo = $false
$script:dictadoLargoHasta = 0
$script:dictadoUltimo = ''     # lo ultimo escrito, para "borra lo ultimo" y "cambia X por Y"
# A QUE VENTANA SE DICTA. Se fija al entrar y no cambia: SendKeys escribe en la
# que tenga el foco EN ESE INSTANTE, y entre que hablas y se transcribe pasan
# segundos. Sin esto, cualquier ventana que se ponga delante mientras hablas
# -un aviso, el navegador terminando de cargar, tu mismo haciendo clic- se lleva
# el resto del correo. Medido: en una prueba con el Bloc de notas delante, el
# texto acabo en otro sitio.
$script:dictadoVentana = [IntPtr]::Zero
$script:ventanaUsuario = [IntPtr]::Zero   # la que tenias delante al empezar a hablar
$script:dictadoWinH = $false              # el dictado en curso lo lleva Win+H
$script:ordenPorWorker = $true            # la orden en curso la transcribe el worker (si no, Win+H)
$script:dictadoWinHPendiente = $false     # hay que abrirlo en cuanto deje de hablar
$script:dictadoLineas = 0      # cuantos trozos van escritos, para contarlo al salir
$script:seguimientoFactor = 1.0
# --- oido fino: repaso de la ultima orden con el modelo preciso ---
$script:yaReintentado = $false     # una sola vez por orden, o seria un bucle
$script:reintentoReconocida = $false   # el repaso es de una orden que YA se entendia
# por debajo de esta seguridad de Whisper se repasa incluso lo que se entiende
# (ver REPASO DE LO DUDOSO): las ordenes bien oidas de las grabaciones, >= -0,73
$RepasoDudosoUmbral = [double](Get-Cfg 'input' 'repasoDudoso' -0.9)
# ECO DE LA FRASE DE EJEMPLO (14/09): si lo oido es solo frases del ejemplo que se le da
# a Whisper y la seguridad baja de esto, el oido fino tiene que confirmarlo. Con las 100
# grabaciones: de 3 ordenes equivocadas quedan 1, sin perder aciertos, y solo 5 de 90
# ordenes buenas esperan el repaso (con -0,7 quedaban 2; confirmando todas, 17 esperas).
$RepasoEcoUmbral = [double](Get-Cfg 'input' 'repasoEco' -0.5)
$script:dictadoEco = $false
$script:reintentoEco = $false
$script:reintentoVence = 0
$script:reintentoTexto = ''
$ReintentoMaxMs = 15000            # si no contesta a tiempo, se sigue sin el
# ULTIMO RECURSO: WHISPER TURBO (15/09, elegido por braya: "si, pero no jugando"). Cuando
# ni base ni small sacan una orden, se repasa el mismo audio con large-v3-turbo. Con sus
# grabaciones rescato 19 de 36 que fallaban sin romper ninguna y 0 ordenes con ruido,
# pero tarda ~12 s (y ~35 s si hay que cargarlo): de ahi su propio plazo. Nunca jugando,
# nunca con lo que parece charla y una sola vez por orden.
# PARAKEET PRIMERO (15/09). La escucha pasa el audio primero por NVIDIA Parakeet TDT 0.6B v3
# (0,6 s por frase, y NUNCA una orden equivocada con las grabaciones de braya: no lleva
# frase de ejemplo que se cuele). Si lo que oye se entiende como orden, se hace ya; si
# no, se pide aqui que Whisper repase el mismo audio y eso sigue el camino de siempre
# (repaso con small, guarda del eco, turbo, charla). Medido con 214 grabaciones: 195
# entendidas y 0 ordenes equivocadas, frente a 188 y 1 con Whisper solo, y mas rapido.
$script:reintentoBase = $false
$script:dictadoPorParakeet = $false
# NO APRENDER DE LO MAL OIDO (15/09). "Ensectiva el modo noche" (dijo "desactiva") paso por
# el oido fino y por turbo sin sacar una orden; el modelo lo tradujo a "modo noche" -justo lo
# contrario-, se hizo y se guardo para siempre en traducciones.json. Lo que ya necesito un
# repaso queda marcado: no se aprende ni como traduccion ni como alias.
$script:oidosDudosos = @{}
# OTRA OPORTUNIDAD TRAS "NO TE ENTENDI" (15/09, pedido por braya): despues de cada "no te
# entendi" vuelve a escuchar sola, sin decir "nova" ni pulsar el boton, para repetirlo al
# momento. Una ventana en silencio se cierra sola sin decir nada (como cualquier
# seguimiento), asi que el silencio no hace bucle; y como mucho se encadenan dos seguidas,
# para que un ruido que no para no la tenga abriendose una y otra vez.
$script:noEntendiSeguidos = 0
$script:origenDictado = ''
$script:siguioParakeet = $false
function Open-EscuchaTrasNoEntendi {
    $script:noEntendiSeguidos++
    if ($script:noEntendiSeguidos -gt 2) {
        Log "no te entendi: van $($script:noEntendiSeguidos) seguidos; esta vez no vuelvo a escuchar"
        return
    }
    $script:seguimientoPendiente = $true
    $script:seguimientoFactor = 1.0
}
$script:preguntarTraduccion = $false
function Add-OidoDudoso([string]$t) {
    $k = ConvertTo-Plain $t
    if (-not $k) { return }
    if ($script:oidosDudosos.Count -gt 300) { $script:oidosDudosos.Clear() }
    $script:oidosDudosos[$k] = $sw.ElapsedMilliseconds
}
function Test-OidoDudoso([string]$t) {
    $k = ConvertTo-Plain $t
    return [bool]($k -and $script:oidosDudosos.ContainsKey($k))
}
# SEGUNDA OPINION EN LA NUBE (16/09). Ver el comentario de arriba del archivo de
# parche: se lanza junto al repaso de Whisper y solo vale si contesta a tiempo.
# La clave vive en GEMINI_API_KEY (entorno del usuario), nunca en el repositorio.
$NubeOir = [string](Get-Cfg 'escucha' 'nubeOir' '')
$NubeTopeMs = [int](Get-Cfg 'escucha' 'nubeTopeMs' 2500)
$NubeScript = Join-Path $LogDir 'tools\gemini-oir.py'
# el aviso va AQUI y no en el bloque de arranque: alli esta variable todavia no existe
# (el script se lee de arriba abajo) y el log decia que la nube estaba apagada
if ($NubeOir -eq 'gemini') { Log "segunda opinion en la nube: Gemini, con tope de $([Math]::Round($NubeTopeMs / 1000.0, 1)) s" }
# lo mismo para los avisos por su cuenta: sin esta linea no habia forma de saber si
# estaban puestos, que es justo la duda que costo un rato con la nube esta manana
if ($EntornoOn) { Log "avisos por mi cuenta: puestos (hasta $EntornoPorHora por hora; de noche y jugando, solo lo importante)" }
$script:nubeProc = $null
$script:nubeOut = ''
$script:nubeWav = ''
$script:nubeVence = 0

# ¿Vale lo que oyo la nube en vez de lo que oyo el oido local? El booleano viene de
# fuera (Test-FastCommand) para poder probar esta decision sin arrastrar medio archivo.
function Test-NubeSirve([string]$nube, [string]$local, [bool]$esOrden) {
    if (-not $nube) { return $false }
    $t = $nube.Trim()
    # una orden no es un parrafo: si devuelve una parrafada, no es lo que dijiste
    if ($t.Length -lt 2 -or $t.Length -gt 120) { return $false }
    # los mismos dos vicios que ya se cortan en el oido local y en la traduccion
    if (Test-EsFraseEjemplo $t) { return $false }
    if (Test-NombreInventado $local $t) { return $false }
    return $esOrden
}

function Clear-NubeOir {
    foreach ($fN in @($script:nubeOut, $script:nubeWav)) {
        if ($fN) { Remove-Item -LiteralPath $fN -Force -ErrorAction SilentlyContinue }
    }
    $script:nubeOut = ''
    $script:nubeWav = ''
    $script:nubeVence = 0
    $script:nubeProc = $null
}

function Start-NubeOir([string]$para) {
    if ($NubeOir -ne 'gemini' -or $script:invitado) { return $false }
    $wavN = Join-Path $TmpDir 'ultima-orden.wav'
    if (-not (Test-Path -LiteralPath $wavN)) { return $false }
    Clear-NubeOir
    try {
        $idN = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
        # se COPIA: el siguiente dictado pisa ultima-orden.wav mientras esta viajando
        $script:nubeWav = Join-Path $TmpDir "nube-$idN.wav"
        Copy-Item -LiteralPath $wavN -Destination $script:nubeWav -Force
        $script:nubeOut = Join-Path $TmpDir "nube-$idN.txt"
        $script:nubeProc = Start-Process -FilePath $PyWorker -WindowStyle Hidden -PassThru `
            -WorkingDirectory $LogDir `
            -ArgumentList @($NubeScript, $script:nubeWav, $script:nubeOut, [string]$NubeTopeMs)
        $null = $script:nubeProc.Handle
        $script:nubeVence = $sw.ElapsedMilliseconds + $NubeTopeMs + 800
        Log "NUBE: segunda opinion de '$para' (tope $([Math]::Round($NubeTopeMs / 1000.0, 1)) s)"
        return $true
    } catch {
        Log ('NUBE: no pude lanzarla: ' + $_.Exception.Message)
        Clear-NubeOir
        return $false
    }
}

# '' si no hay nada (o ya no da tiempo); el texto si contesto
function Receive-NubeOir {
    if (-not $script:nubeOut) { return '' }
    if (Test-Path -LiteralPath $script:nubeOut) {
        $tN = ''
        try { $tN = [System.IO.File]::ReadAllText($script:nubeOut, [System.Text.Encoding]::UTF8) } catch { $tN = '' }
        Clear-NubeOir
        return $tN.Trim()
    }
    if ($sw.ElapsedMilliseconds -ge $script:nubeVence) {
        Log 'NUBE: no contesto a tiempo; sigo con el oido de siempre'
        Add-Estadistica 'nube-tarde' ''
        try { if ($script:nubeProc -and -not $script:nubeProc.HasExited) { $script:nubeProc.Kill() } } catch {}
        Clear-NubeOir
    }
    return ''
}

function Request-WhisperTras([string]$texto) {
    if (-not $script:wakeProc -or $script:wakeProc.HasExited) { return $false }
    try {
        Remove-Item -LiteralPath $RutaReintento -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $TmpDir 'dictado-confianza.txt') -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText($MarcaReintento, 'base')
        $script:reintentoTexto = $texto
        $script:reintentoBase = $true
        $script:reintentoVence = $sw.ElapsedMilliseconds + $ReintentoMaxMs
        Log "PARAKEET: '$texto' no es una orden que entienda; lo repasa Whisper"
        Add-Estadistica 'parakeet-a-whisper' $texto
        [void](Start-NubeOir $texto)   # ver SEGUNDA OPINION EN LA NUBE
        Set-UI 'pensando'
        return $true
    } catch {
        $script:reintentoBase = $false
        return $false
    }
}
$ReintentoUltimoMs = 60000
$script:reintentoUltimo = $false
$script:ultimoRecursoPara = ''
$script:ultimoRecursoEn = 0
$script:reintentoAlFallar = 'procesar'
function Request-UltimoRecurso([string]$orig, [bool]$reconocida, [bool]$eco, [string]$alFallar = 'procesar') {
    if (-not $WhisperUltimo -or $script:reintentoUltimo -or $script:juegoActivo) { return $false }
    # UNA SOLA VEZ POR FRASE (15/09): el 15/09 se pidio turbo cuatro veces seguidas para
    # la misma frase (ver UN REPASO QUE SE QUEDA SIN DUENO)
    $claveU = ConvertTo-Plain $orig
    if ($claveU -and $script:ultimoRecursoPara -eq $claveU -and ($sw.ElapsedMilliseconds - $script:ultimoRecursoEn) -lt 120000) {
        Log "ULTIMO RECURSO: ya se pidio para '$orig'; no lo repito"
        return $false
    }
    if (-not $script:wakeProc -or $script:wakeProc.HasExited) { return $false }
    if (-not $reconocida -and (Test-PareceCharla $orig)) { return $false }
    if (-not (Test-MereceRepaso $orig)) { return $false }
    try {
        Remove-Item -LiteralPath $RutaReintento -Force -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText($MarcaReintento, 'ultimo')
        $script:ultimoRecursoPara = $claveU
        $script:ultimoRecursoEn = $sw.ElapsedMilliseconds
        $script:reintentoTexto = $orig
        Add-OidoDudoso $orig
        $script:reintentoReconocida = $reconocida
        $script:reintentoEco = $eco
        $script:reintentoUltimo = $true
        $script:reintentoAlFallar = $alFallar
        $script:reintentoVence = $sw.ElapsedMilliseconds + $ReintentoUltimoMs
        Log "ULTIMO RECURSO: ni base ni small sacan una orden de '$orig'; lo repasa turbo"
        Add-Estadistica 'turbo' $orig
        Set-UI 'pensando' 'Pensandolo mejor'
        return $true
    } catch {
        $script:reintentoUltimo = $false
        return $false
    }
}
# --- AUTOSORDINA: se calla sola si el microfono entra en racha de ruido ---
# Tres descartes en cinco minutos no son mala suerte: es que esta oyendo algo
# que no eres tu. Antes de los filtros de hoy eso acababa abriendo cosas;
# ahora ya no, pero sigue molestando que conteste "no te entendi" cada dos
# minutos mientras juegas.
$AutoSordinaOn = [bool](Get-Cfg 'escucha' 'autoSordina' $true)
$AutoSordinaRachas = [int](Get-Cfg 'escucha' 'autoSordinaRachas' 3)
$AutoSordinaVentanaMs = [int](Get-Cfg 'escucha' 'autoSordinaVentanaMin' 5) * 60000
$AutoSordinaMs = [int](Get-Cfg 'escucha' 'autoSordinaMinutos' 10) * 60000
$script:rachaRuido = New-Object System.Collections.ArrayList
# Hasta cuando esta SORDA. No vale $script:pausaHasta: esa misma pausa se usa
# durante un segundo cada vez que habla, y eso no es estar sorda.
$script:sordinaHasta = 0
$script:aprenderPendiente = $null
$script:ultimaLectura = ''
# Por donde va la lectura en voz alta de esa pantalla, para "sigue leyendo".
$script:lecturaPos = 0
# En que esquina vive la capsula. Se lee de config.json al arrancar y se
# guarda ahi mismo al cambiarla, para que sobreviva al reinicio.
$script:esquina = [string](Get-Cfg 'ui' 'esquina' 'abajo-izquierda')
if ($script:esquina -notmatch '^(?:abajo|arriba)-(?:izquierda|derecha)$') { $script:esquina = 'abajo-izquierda' }
# TAMANO DE LA CAPSULA, recordado igual que la esquina. En la pantalla de 7
# pulgadas de la Ally el tamano de siempre es pequeno de verdad. Los pasos son
# discretos a proposito: "un poco mas grande" no significa nada, y con la voz
# no se ajusta un numero, se sube un escalon.
$EscalasUI = @(0.75, 1.0, 1.25, 1.5, 1.75, 2.0)
$script:uiEscala = [double](Get-Cfg 'ui' 'escala' 1.0)
if ($script:uiEscala -lt 0.75 -or $script:uiEscala -gt 2.0) { $script:uiEscala = 1.0 }
# VELOCIDAD DE LA VOZ guardada (ver Set-VozVelocidad): se le pasa al worker al arrancar
try { Set-VozVelocidad ([int](Get-Cfg 'voz' 'velocidad' 0)) } catch {}
# COLOR DE REPOSO elegido por voz (hex sin #; vacio = el de siempre)
$script:uiColor = [string](Get-Cfg 'ui' 'color' '')
if ($script:uiColor -notmatch '^[0-9A-Fa-f]{6}$') { $script:uiColor = '' }
# NIVEL de Nova al arrancar (ver NOVA EVOLUCIONA). Lo aprendido con el asistente
# apagado (una receta editada a mano) no se celebra: se da por visto.
try {
    $script:uiMadurez = Get-Madurez (Get-CuentaAprendida)
    $hbI = Get-Habitos
    if ($script:uiMadurez -gt [int]$hbI.nivelVisto) { $hbI.nivelVisto = $script:uiMadurez; Save-Habitos }
} catch {}
# La ultima frase que se ejecuto de verdad, para saber a que se refiere un
# "no era eso".
$script:ultimoEjecutado = ''
# Modos dentro de modos: cuantos van encadenados ahora mismo (ver el tope).
$script:hondoPerfil = 0
# Que juegos estaban bajando en la vuelta anterior. $null (no vacio) hasta la
# primera lectura: al arrancar no se sabe que estaba bajando antes, y anunciar
# ahi un final seria inventarselo.
# SON DOS, y no una: el aviso hablado compara por ID de Steam y las reglas
# ("cuando termine de descargarse X, abrelo") comparan por NOMBRE. Compartian
# variable, asi que cada uno veia las claves del otro como descargas que
# acababan de terminar y disparaba reglas con un numero por nombre.
$script:bajandoAntes = $null
$script:bajandoReglas = $null
# De que frase aprendida salio la ultima orden, para poder olvidarla si dices
# "no era eso".
$script:ultimaAprendida = ''
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
# Un descarte mas en la cuenta. Si se juntan varios en poco tiempo, se calla
# sola: no es un castigo, es que en esa situacion la escucha por voz esta
# haciendo mas ruido que servicio. El boton sigue funcionando.
function Add-RuidoRacha {
    if (-not $AutoSordinaOn) { return }
    if ($script:pausaHasta -gt 0) { return }          # ya esta callada
    # NO ES RUIDO SI ERES TU (15/09): jugando, tres "no te entendi" seguidos en ventanas de
    # seguimiento (braya contestandole) y se callo 10 minutos diciendo que oia ruido. La
    # autosordina es para la tele que despierta el nombre, no para el boton ni para lo que
    # se le contesta justo despues de hablar ella.
    if ($script:origenDictado -eq 'seguimiento' -or $script:origenDictado -like 'mantener*') { return }
    $ahora = $sw.ElapsedMilliseconds
    [void]$script:rachaRuido.Add($ahora)
    # fuera los de fuera de la ventana
    for ($i = $script:rachaRuido.Count - 1; $i -ge 0; $i--) {
        if (($ahora - $script:rachaRuido[$i]) -gt $AutoSordinaVentanaMs) { $script:rachaRuido.RemoveAt($i) }
    }
    if ($script:rachaRuido.Count -lt $AutoSordinaRachas) { return }
    $script:rachaRuido.Clear()
    $mins = [int]($AutoSordinaMs / 60000)
    Log "AUTOSORDINA: $AutoSordinaRachas descartes seguidos; me callo $mins min"
    Pausar-Escucha $AutoSordinaMs
    $script:sordinaHasta = $sw.ElapsedMilliseconds + $AutoSordinaMs
    [void]$script:temporizadores.Add(@{ vence = ($sw.ElapsedMilliseconds + $AutoSordinaMs + 1500)
                                        texto = 'Ya vuelvo a escucharte.'; total = $AutoSordinaMs
                                        tipo = 'sordina' })
    $aviso = "Creo que estoy oyendo ruido y no a ti. Me callo $mins minutos; si me necesitas, usa el boton."
    Show-Popup $aviso
    Say $aviso
}

function Start-Dictado([string]$origen) {
    Log "DICTADO ($origen)"
    if ($origen -ne 'seguimiento') { $script:noEntendiSeguidos = 0 }
    $script:origenDictado = $origen
    $script:siguioParakeet = $false
    # llamarla de nuevo corta lo que estuviera contestando (ver CONVERSACION DE VERDAD)
    if ($origen -ne 'seguimiento') { try { Stop-Charla } catch {} }
    # si es probable que vayas a charlar, el modelo empieza a cargar ya (ver MENOS ESPERA EN FRIO)
    if ($origen -ne 'seguimiento' -and ($sw.ElapsedMilliseconds - $script:precargaEn) -gt 90000) {
        try {
            if (Test-PrecargaCharla) {
                $script:precargaEn = $sw.ElapsedMilliseconds
                if ((Test-RamParaCharla) -and (Send-CharlaPedido @{ op = 'calentar' })) { Log "charla: precargo el modelo (es probable charlar)" }
            }
        } catch {}
    }
    # NOTA DE VOZ y TRADUCTOR (13/09): solo el dictado de seguimiento que viene
    # detras de "graba una nota" / "traduce lo que diga" lleva la marca para el
    # worker (guarda el audio / escucha en otro idioma). Cualquier otro la quita:
    # un ingles olvidado estropearia todas tus ordenes.
    $rutaGuardarAudio = Join-Path $TmpDir 'guardar-audio.txt'
    $rutaIdiomaDictado = Join-Path $TmpDir 'idioma-dictado.txt'
    $utf8SinBom = New-Object System.Text.UTF8Encoding($false)
    if ($origen -eq 'seguimiento' -and $script:notaPorGrabar) {
        try { [System.IO.File]::WriteAllText($rutaGuardarAudio, [string]$script:notaPorGrabar, $utf8SinBom) } catch {}
        $script:grabandoNota = $script:notaPorGrabar
    } else {
        Remove-Item -LiteralPath $rutaGuardarAudio -Force -ErrorAction SilentlyContinue
        $script:grabandoNota = $null
    }
    $script:notaPorGrabar = $null
    if ($origen -eq 'seguimiento' -and $script:traducirPorOir) {
        try { [System.IO.File]::WriteAllText($rutaIdiomaDictado, [string]$script:traducirPorOir, $utf8SinBom) } catch {}
        $script:traduciendoVoz = $script:traducirPorOir
    } else {
        Remove-Item -LiteralPath $rutaIdiomaDictado -Force -ErrorAction SilentlyContinue
        $script:traduciendoVoz = $null
    }
    $script:traducirPorOir = $null
    # QUE VENTANA TENIAS TU. Se apunta ANTES de mostrar nada del asistente: en
    # cuanto aparece su ventana de captura, el foco es suyo, y quien pregunte
    # despues obtiene esa. La necesita el dictado largo, que escribe en la tuya.
    # NINGUNA ventana del asistente cuenta como tuya: ni la de captura ni la
    # CAPSULA, que aunque no roba clics si aparece como ventana en primer plano.
    # Si se cuela, el correo se lo lleva ella y el log dice 'escrito' tan
    # tranquilo. Medido: el destino salia 1705814, que era nova_ui.
    try {
        $hwTuyo = [AX]::GetForegroundWindow()
        $duenoVentana = Get-PidDeVentana $hwTuyo
        $pidUi = 0
        if ($script:uiProc -and -not $script:uiProc.HasExited) { $pidUi = $script:uiProc.Id }
        if ($hwTuyo -ne [IntPtr]::Zero -and $duenoVentana -ne $PID -and ($pidUi -eq 0 -or $duenoVentana -ne $pidUi)) {
            $script:ventanaUsuario = $hwTuyo
        }
    } catch {}
    # que no quede texto del oido de Windows de una orden anterior: si no, la
    # nueva empezaria con basura del pasado
    if ($VozWindowsOn) { Remove-Item -LiteralPath $RutaDictadoWin -Force -ErrorAction SilentlyContinue }
    $script:yaReintentado = $false
    $script:reintentoUltimo = $false
    # UN REPASO QUE SE QUEDA SIN DUENO (15/09). Turbo repasaba "quiero que veas que hay
    # en mi pantalla" cuando empezo otro dictado: aqui se borraba la marca de turbo pero
    # no el plazo, y su respuesta llego como si fuera del oido fino, que volvio a pedir
    # turbo; la escucha se cayo (access violation) y, sin audio, dio dos vueltas mas.
    # Si empieza otro dictado, lo pendiente ya no es de nadie: se abandona entero y la
    # escucha deja de transcribir en cuanto ve que la marca ya no esta.
    if ($script:reintentoVence -gt 0) {
        Log "repaso pendiente de '$($script:reintentoTexto)' abandonado: empieza otro dictado"
        $script:reintentoVence = 0
        $script:reintentoBase = $false
        $script:reintentoReconocida = $false
        $script:reintentoEco = $false
        $script:reintentoTexto = ''
        Remove-Item -LiteralPath $MarcaReintento -Force -ErrorAction SilentlyContinue
    }
    # BOTON CON LA SORDINA PUESTA ("no me escuches media hora" o la autosordina).
    # La sordina es para el NOMBRE, no para ti: el propio aviso dice "usa el
    # boton". Pero se hace con la marca de pausa, que para el worker es "tira
    # todo el audio", asi que el dictado no recibia nada y la orden se perdia
    # (revision del 12/09). Se levanta para este dictado y el bucle la vuelve a
    # poner al terminar, con el tiempo que le quedara.
    if ($origen -like 'mantener*' -and $script:sordinaHasta -gt $sw.ElapsedMilliseconds -and (Test-Path -LiteralPath $MarcaPausa)) {
        Reanudar-Escucha -Forzar
        $script:sordinaRepausar = $true
        Log "SORDINA: la levanto para este dictado con el boton"
    }
    # NOVA ESTABA HABLANDO (un aviso, un temporizador, o pulsaste ≡ mientras
    # contestaba): la pausa hace que el worker tire el audio, asi que el dictado
    # se congelaba 50 s. Se corta la voz y se escucha (auditoria del 13/09).
    elseif ((Test-Path -LiteralPath $MarcaPausa) -and -not ($script:sordinaHasta -gt $sw.ElapsedMilliseconds)) {
        try { if ($script:reproductor) { $script:reproductor.Stop() } } catch {}
        try { if ($script:vozPlayer) { $script:vozPlayer.Stop() } } catch {}
        Reanudar-Escucha
        Log "DICTADO: corto la voz y vuelvo a escuchar para oirte"
    }
    # Cuantas veces se despierta por voz. Sin este numero no hay forma de
    # saber si los filtros de falsas alarmas funcionan o si, al reves, se han
    # pasado de listos y ya no te oyen.
    if ($origen -like 'nombre*') { Add-Estadistica 'activacion' }
    # "escondete" a secas dura hasta que la LLAMAS (nombre o boton): la escucha
    # de seguimiento que se abre sola tras responder no cuenta como llamarla
    if ($script:uiRetirada -eq 'nombre' -and ($origen -like 'nombre*' -or $origen -like 'mantener*')) { $script:uiRetirada = $false }
    $script:loTengo = $false
    $script:loTengoEscrito = $false
    Remove-Item -LiteralPath $RutaLoTengo -Force -ErrorAction SilentlyContinue
    $script:perdida = $false
    $script:seguimientoPendiente = $false
    # sin esto, una orden sin medida de tono se juzgaria con la de la anterior
    $script:ultimaF0 = 0
    # 'largo' es un seguimiento con la ventana MUY larga: en mitad de un correo
    # se piensa lo que se va a decir, y cerrar la escucha a los 2,5 s obligaria
    # a volver a decir "nova" cada dos frases.
    $largo = ($origen -eq 'largo')
    $seguimiento = ($origen -eq 'seguimiento') -or $largo
    $script:enSeguimiento = ($origen -eq 'seguimiento')
    # con la capsula, el sonido lo pone ella (un tono corto, no la campana)
    if (-not $UiNuevaOn -and -not $seguimiento) { Play-Sonido 'te-oigo' ([System.Media.SystemSounds]::Exclamation) }

    # QUE MOTOR PARA ESTA ORDEN. Jugando manda no molestar; fuera del juego manda
    # acertar. El dictado largo va siempre por su camino, que ya lo decidio antes.
    $usaWorker = $DictadoWorker
    if ($DictadoMotor -eq 'worker') { $usaWorker = $true }
    elseif ($DictadoMotor -eq 'windows') { $usaWorker = $false }
    elseif ($DictadoMotor -eq 'auto' -and -not $largo) {
        # sin juego delante, Win+H; con juego, el worker
        $usaWorker = [bool]$script:juegoActivo
    }
    if ($largo) { $usaWorker = $true }   # el largo se gestiona aparte
    # EL MOTOR DE ESTA ORDEN, apuntado para el bucle. Antes el bucle miraba el
    # global $DictadoWorker ("hay worker"), que es SIEMPRE cierto aunque la orden
    # vaya por Win+H: la recogida del worker se creia a cargo, su red de
    # seguridad comparaba con el reloj de una orden vieja y cancelaba al
    # segundo ("dictado sin respuesta del worker", 12/09 19:08), y el envio por
    # silencio de Win+H no se alcanzaba nunca. motorOrdenes = windows no
    # funcionaba en absoluto.
    # y VIVO: tras 3 fallos el worker podia seguir referenciado ya muerto, y cada
    # pulsacion de ≡ esperaba 50 s a un worker que no existia (auditoria 13/09)
    $script:ordenPorWorker = [bool]($usaWorker -and $script:wakeProc -and -not $script:wakeProc.HasExited)
    $script:dictaInicio = $sw.ElapsedMilliseconds

    # --- Dictado por el worker (Whisper/Vosk): ni foco, ni Win+H, ni pausa ---
    # El worker ya tiene el microfono; solo hay que decirle que transcriba.
    if ($usaWorker -and $script:wakeProc) {
        Remove-Item -LiteralPath $RutaDictado -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $RutaParcial -Force -ErrorAction SilentlyContinue
        # en seguimiento, la marca lleva el plazo: si no hay voz en ese tiempo
        # el worker cierra solo y entrega vacio
        $ventana = if ($largo) { 20000 }
                   elseif ($script:ventanaCharla) { Get-VentanaSeguimiento $true }
                   else { [int]((Get-VentanaSeguimiento $false) * $script:seguimientoFactor) }
        $script:ventanaCharla = $false
        Remove-Item -LiteralPath (Join-Path $TmpDir 'seguimiento-voz.txt') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $TmpDir 'dictado-confianza.txt') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $TmpDir 'dictado-motor.txt') -Force -ErrorAction SilentlyContinue
        $script:dictadoEco = $false
        $script:dictadoPorParakeet = $false
        # "nombre": el worker se ahorra Whisper con una voz muy lejos de la tuya (ver wake_vosk)
        [System.IO.File]::WriteAllText($MarcaDictar, $(if ($seguimiento) { "seguimiento:$ventana" } elseif ($origen -like 'nombre*' -and $SoloYoOn) { 'nombre' } else { 'x' }))
        Start-Vibracion $(if ($seguimiento) { @(40) } else { @(90) })
        $lbl.Text = "● VOZ..."
        $lbl.ForeColor = [System.Drawing.Color]::LimeGreen
        # en dictado largo NO: se quedaria con el foco, y el foco tiene que
        # estar en la ventana a la que se escribe
        if (-not $largo) { $capture.Show() }
        if ($largo) { Set-UI 'escuchando' 'dictando... di ya esta para parar' }
        elseif ($seguimiento) { Set-UI 'atenta' }
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
        Play-Sonido 'no-pude' ([System.Media.SystemSounds]::Hand)
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
        # el Escape de arriba no siempre se lo lleva: ver Close-PanelDictado
        [void](Close-PanelDictado)
        Reanudar-Escucha
        # y el foco vuelve a lo TUYO. Sin esto, cada orden por Win+H te deja
        # escribiendo en la ventana invisible del asistente.
        if ($script:ventanaUsuario -ne [IntPtr]::Zero) {
            try { [void][AX]::ForceForeground($script:ventanaUsuario) } catch {}
        }
    }
    Process-Texto $text
}

# Todo lo que ocurre DESPUES de tener el texto. Lo comparten el dictado por
# Vosk y el antiguo de Windows, para que se comporten igual.
# Escribe en la ventana que tengas delante. Es el mismo camino que la orden
# "escribe ...", con el escape de SendKeys: un '+' o un '%' sin escapar serian
# Shift y Alt, y en mitad de un correo eso es un desastre silencioso.
function Write-EnVentana([string]$texto) {
    if (-not $texto) { return }
    # Si la ventana de destino ya no tiene el foco, se le devuelve. Y si ya no
    # existe, no se escribe a ciegas en lo que haya: se cierra el modo.
    if ($script:dictandoLargo -and $script:dictadoVentana -ne [IntPtr]::Zero) {
        if ($script:dictadoVentana -eq $capture.Handle) {
            Log "DICTADO LARGO: el destino era mi propia ventana; no escribo"
            Stop-DictadoLargo 'destino invalido'
            return
        }
        if (-not [AX]::IsWindowVisible($script:dictadoVentana)) {
            Log "DICTADO LARGO: la ventana a la que dictaba ya no esta"
            Stop-DictadoLargo 'se cerro la ventana'
            return
        }
        if ([AX]::GetForegroundWindow() -ne $script:dictadoVentana) {
            $ok = [AX]::ForceForeground($script:dictadoVentana)
            Start-Sleep -Milliseconds 120
            if ([AX]::GetForegroundWindow() -ne $script:dictadoVentana) {
                # Windows puede denegar el cambio de primer plano. Escribir
                # igual mandaria el correo a saber donde: mejor no escribir y
                # decirlo, que es lo unico honesto.
                Log ("DICTADO LARGO: no pude devolver el foco a la ventana (ForceForeground=" + $ok + "); no escribo")
                return
            }
        }
    }
    [System.Windows.Forms.SendKeys]::SendWait(([regex]::Replace($texto, '[+^%~(){}\[\]]', { param($m) '{' + $m.Value + '}' })))
}

function Stop-DictadoLargo([string]$porque = '') {
    if (-not $script:dictandoLargo) { return }
    $script:dictadoWinHPendiente = $false
    if ($script:dictadoWinH) {
        # NO con otro Win+H: si el panel ya se habia cerrado o estaba en su
        # error, lo volvia a abrir y se quedaba a la vista. Ver Close-PanelDictado.
        $n = Close-PanelDictado
        Log "DICTADO LARGO: panel de Windows cerrado ($n)"
        Start-Sleep -Milliseconds 200
        $script:dictadoWinH = $false
        Reanudar-Escucha
    }
    $script:dictandoLargo = $false
    $script:dictadoLargoHasta = 0
    $script:dictadoVentana = [IntPtr]::Zero
    $n = $script:dictadoLineas
    $script:dictadoLineas = 0
    $script:dictadoUltimo = ''
    Log "DICTADO LARGO: fin ($porque), $n trozos escritos"
    $script:uiPerfil = ''
    Set-UI 'reposo'
    Send-Aviso $(if ($n -gt 0) { "Listo, he escrito $n trozos." } else { "Listo, no he escrito nada." }) 'tiempo'
}

# Lo que se oye mientras esta el modo puesto: o es una orden DEL MODO, o se
# escribe tal cual. Devuelve $true si ya se ha ocupado de la frase.
function Invoke-DictadoLargo([string]$text) {
    if (-not $script:dictandoLargo) { return $false }
    $plano = (ConvertTo-Plain $text).Trim()
    if (-not $plano) { return $true }

    # --- salir ---
    if ($plano -match '^(?:ya esta|ya|listo|para|para de dictar|deja de dictar|fin|fin del dictado|termina|terminamos|basta|se acabo|ya termine|corta)$') {
        Stop-DictadoLargo 'lo pediste'
        return $true
    }
    # --- signos y saltos ---
    if ($plano -match '^(?:punto y aparte|nueva linea|salto de linea|otra linea|aparte)$') {
        Write-EnVentana "{ENTER}"
        $script:dictadoUltimo = ''
        $script:dictadoLineas++
        Log "DICTADO LARGO: salto de linea"
        return $true
    }
    if ($plano -match '^(?:punto y seguido|punto)$') { Write-EnVentana '. '; $script:dictadoUltimo = ''; return $true }
    if ($plano -match '^(?:coma)$') { Write-EnVentana ', '; return $true }
    if ($plano -match '^(?:dos puntos)$') { Write-EnVentana ': '; return $true }
    if ($plano -match '^(?:punto y coma)$') { Write-EnVentana '; '; return $true }
    if ($plano -match '^(?:signo de interrogacion|interrogacion)$') { Write-EnVentana '? '; $script:dictadoUltimo = ''; return $true }
    if ($plano -match '^(?:signo de exclamacion|exclamacion)$') { Write-EnVentana '! '; $script:dictadoUltimo = ''; return $true }

    # --- borrar lo ultimo ---
    # Se borra con retrocesos lo que se escribio, no con Ctrl+Z: deshacer en una
    # ventana ajena puede tirar de cosas que no ha escrito nadie de aqui.
    if ($plano -match '^(?:borra lo ultimo|borra eso|quita lo ultimo|borralo|eso no|no eso no)$') {
        if (-not $script:dictadoUltimo) {
            Log "DICTADO LARGO: no hay nada reciente que borrar"
        } else {
            Write-EnVentana ("{BACKSPACE " + $script:dictadoUltimo.Length + "}")
            Log "DICTADO LARGO: borrado '$script:dictadoUltimo'"
            $script:dictadoUltimo = ''
            if ($script:dictadoLineas -gt 0) { $script:dictadoLineas-- }
        }
        return $true
    }

    # --- cambiar una palabra de lo ultimo ---
    if ($plano -match '^cambia\s+(.+?)\s+por\s+(.+)$') {
        $de = $Matches[1].Trim(); $a = $Matches[2].Trim()
        if (-not $script:dictadoUltimo) {
            Log "DICTADO LARGO: no hay nada reciente que cambiar"
        } elseif ((ConvertTo-Plain $script:dictadoUltimo) -notmatch [regex]::Escape((ConvertTo-Plain $de))) {
            Log "DICTADO LARGO: '$de' no esta en lo ultimo que escribi"
        } else {
            # se reescribe el trozo entero: buscar y sustituir a ciegas dentro de
            # una ventana ajena es mucho peor que rehacer lo que ya se sabe
            $nuevo = [regex]::Replace($script:dictadoUltimo, [regex]::Escape($de), $a, 'IgnoreCase')
            Write-EnVentana ("{BACKSPACE " + $script:dictadoUltimo.Length + "}")
            Start-Sleep -Milliseconds 60
            Write-EnVentana $nuevo
            Log "DICTADO LARGO: '$de' -> '$a'"
            $script:dictadoUltimo = $nuevo
        }
        return $true
    }

    # --- y si no, se escribe ---
    # ESTA VOZ NO ES LA TUYA: lo mismo que con las ordenes, pero aqui ni se
    # pregunta, se ignora. Preguntar "¿escribo esto?" en mitad de un correo
    # seria peor que perder una frase.
    if (Test-VozExtrana) {
        Log "DICTADO LARGO: descartado por voz extrana ($([int]$script:ultimaF0) Hz)"
        return $true
    }
    $trozo = $text.Trim()
    if ($script:dictadoUltimo) { $trozo = ' ' + $trozo }
    Write-EnVentana $trozo
    $script:dictadoUltimo = $trozo
    $script:dictadoLineas++
    $script:dictadoLargoHasta = $sw.ElapsedMilliseconds + $DictadoLargoMs
    Log "DICTADO LARGO: escrito '$($text.Trim())'"
    Set-UI 'escuchando' ("dictando: " + $text.Trim())
    return $true
}

# LAS QUEJAS REHACEN LA ORDEN (16/09). El 15/09, 19 ordenes acabaron en nada porque
# Nova trataba la queja como charla ("perdona, me confundi") o como consulta a la
# memoria, y braya tenia que repetirlo hasta 7 veces. Aqui la queja se convierte en la
# orden que se pidio, usando la ULTIMA que se hizo. No es un modo que se quede puesto:
# es un solo paso, y si lo que sale no es una orden que Nova sepa hacer, no se hace
# nada raro, la frase sigue su camino de siempre (charla o modelo).
$RE_QUEJA = '(?:^(?:no|pero|oye no|que no)\b|no te (?:pedi|dije)|yo no (?:dije|pedi)|lo que (?:dije|pedi|queria) fue|no es (?:el|la|eso)|no solo|por que no (?:abriste|cerraste|pusiste|hiciste|iniciaste)|te (?:dije|pedi) que)'

function Get-OrdenCorregida([string]$text) {
    if (-not $script:ultimaOrden -or -not $text) { return $null }
    # solo lo reciente: una queja de hace media hora no habla de esa orden
    if (($sw.ElapsedMilliseconds - [double]$script:ultimaOrden.cuando) -gt 180000) { return $null }
    $p = ConvertTo-Plain $text
    if ($p -notmatch $RE_QUEJA) { return $null }
    # OJO: aqui NO hay comas ni signos (ConvertTo-Plain los quita). La primera version
    # dependia de ellas y devolvia frases pegadas que no eran ordenes.
    $ant = ConvertTo-Plain ([string]$script:ultimaOrden.texto)
    $sale = $null

    # 1) "...dije cierra steam" / "lo que dije fue que abrieras el juego".
    #    El .* es CODICIOSO a proposito: vale la ULTIMA marca, no la primera. Con la
    #    primera, "no te pedi la hora dije cierra steam" daba "la hora dije cierra steam".
    if ($p -match '^.*\b(?:dije|pedi|queria)(?:\s+fue)?(?:\s+que)?\s+(.+)$') {
        $sale = $Matches[1].Trim()
    }
    # 2) "no es el wifi es el bluetooth": se cambia esa palabra en la orden anterior
    if (-not $sale -and $p -match '^(?:no|pero)\s+(?:es|era)\s+(?:el|la|lo)?\s*(.+?)\s+(?:es|sino|era)\s+(?:el|la|lo)?\s*(.+)$') {
        $malo = $Matches[1].Trim(); $bueno = $Matches[2].Trim()
        if ($malo -and $bueno -and $ant -match ('\b' + [regex]::Escape($malo) + '\b')) {
            $sale = ($ant -replace ('\b' + [regex]::Escape($malo) + '\b'), $bueno)
        }
    }
    # 3) "no es el volumen" (sin decir cual estaba mal): vale si la orden anterior era
    #    "verbo + objeto"; se le cambia el objeto conservando el articulo y el resto
    #    ("pon el brillo al 50" -> "pon el volumen al 50"). Si no, no se inventa nada.
    if (-not $sale -and $p -match '^(?:no|pero)\s+(?:es|era)\s+(?:el|la|lo)?\s*(.+)$') {
        $bueno = $Matches[1].Trim()
        if ($bueno -and $ant -match '^(\S+)\s+(?:(el|la|lo)\s+)?(\S+)(.*)$') {
            $artA = if ($Matches[2]) { $Matches[2] + ' ' } else { '' }
            $sale = ($Matches[1] + ' ' + $artA + $bueno + $Matches[4])
        }
    }
    # 4) "por que no abriste steam"
    if (-not $sale -and $p -match 'por que no (abriste|cerraste|pusiste|iniciaste)\s+(?:el\s+|la\s+)?(.+)$') {
        $verboQ = switch ($Matches[1]) { 'abriste' { 'abre' } 'cerraste' { 'cierra' } 'iniciaste' { 'inicia' } default { 'pon' } }
        $sale = ($verboQ + ' ' + $Matches[2].Trim())
    }
    # 5) "no solo lo busques reproducelo": el verbo del final con el objeto de antes
    if (-not $sale -and $p -match 'no solo\s+.*?\b(\w{4,})(?:lo|la|los|las)$' -and $script:ultimoObjetivo) {
        $sale = ($Matches[1] + ' ' + $script:ultimoObjetivo)
    }
    if (-not $sale) { return $null }

    $sale = (Repair-Verb ($sale -replace '\s+', ' ').Trim())
    # LO QUE SALGA TIENE QUE PARECER UNA ORDEN. Si no, se devuelve nada y la frase sigue
    # su camino normal: es preferible contestar a la queja que hacer algo que nadie pidio.
    # La comprobacion de verdad la hace Test-FastCommand fuera; esto solo corta lo absurdo.
    if ($sale.Length -lt 3 -or @($sale -split '\s+').Count -gt 8) { return $null }
    $verbo0 = @($sale -split '\s+')[0]
    # $VERBOS no los tiene todos (no estan activa, enciende, quita, crea...), y por eso la
    # correccion del bluetooth se tiraba estando bien
    $masVerbos = @('activa', 'activame', 'desactiva', 'enciende', 'prende', 'quita', 'quitame',
                   'conecta', 'desconecta', 'crea', 'creame', 'haz', 'hazme', 'lee', 'leeme',
                   'graba', 'corta', 'instala', 'desinstala', 'recuerdame', 'avisame', 'dime',
                   'di', 'repite', 'traduce', 'apunta', 'anota', 'borra', 'cancela')
    if ($VERBOS_LISTA -notcontains $verbo0 -and $masVerbos -notcontains $verbo0 -and
        $verbo0 -notmatch '^(?:que|cuanto|cual|donde|cuando)$') { return $null }
    if ($sale -eq $ant) { return $null }
    return $sale
}
function Process-Texto([string]$text) {
    # EL MODO MANDA: con el dictado largo puesto, NADA de lo que se oiga abre,
    # cierra ni toca el sistema. O es una orden del modo, o se escribe. Esto va
    # lo primero a proposito: es lo que hace que el modo sea seguro.
    if ($script:dictandoLargo) {
        if (Invoke-DictadoLargo $text) { $script:seguimientoPendiente = $false; return }
    }
    if ($text.Length -gt 0) {
        # has vuelto: el resumen de lo que paso (ver RESUMEN AL VOLVER) y tu hora
        # de uso de hoy (ver RECORDATORIO PARA CARGAR)
        if (-not $script:invitado) {
            try { Test-ResumenAlVolver } catch {}
            try { Test-ParteManana } catch {}   # ver PARTE DE LA MANANA
            try { Set-UsoAhora } catch {}
        }
        $plano = ConvertTo-Plain $text
        if ($script:invitado) { $script:invitadoUltimo = $sw.ElapsedMilliseconds }
        $script:uiOrigen = ''   # lo que se conteste ahora no hereda el tinte de la charla anterior

        # RECITADO DE LA FRASE DE EJEMPLO: solo con lo oido por Whisper hace un momento
        # (una orden escrita con dos de esas frases es tuya y vale)
        if ($script:ordenPorWorker -and ($sw.ElapsedMilliseconds - $script:dictadoConfianzaEn) -lt 15000 -and
            (Test-RecitaEjemplo $text)) {
            Log "RECITADO: '$text' son varias frases del ejemplo de Whisper, no una orden; no hago nada"
            Add-Estadistica 'recitado' $text
            $script:seguimientoPendiente = $false
            Send-UIEvento 'gesto:confuso'
            Show-Popup "No te entendi. Repitelo." 'error'
            Say "No te entendi"
            Open-EscuchaTrasNoEntendi
            return
        }

        # "SILENCIO" JUSTO CUANDO NOVA HABLA O ACABA DE HABLAR (14/09): era silenciar el PC.
        # Dicho para cortarla -en la charla o en los 6 s siguientes a su ultima frase-
        # la calla y ya: te quedabas sin sonido por querer que se callara ella. Ni con
        # una nota de voz ni con el traductor esperando: ahi "para" es su respuesta.
        if (-not $script:grabandoNota -and -not $script:traduciendoVoz -and
            $plano -match '^(?:silencio|callate|calla|basta|para)$' -and
            ($script:charlaEsperando -or $script:charlaFrases.Count -gt 0 -or
             ($sw.ElapsedMilliseconds - [Math]::Max([double]$script:vozFinReal, [double]$script:finVoz)) -lt 6000)) {
            try { Stop-Charla } catch {}
            $script:seguimientoPendiente = $false
            Log "CORTE: '$text' mientras hablaba o nada mas acabar; la callo en vez de silenciar el PC"
            Set-UI 'reposo'
            return
        }

        # LO QUE LLEGA TRAS UNA PREGUNTA SUYA, antes que nada (ni "gracias" ni atajos):
        # NOTA DE VOZ: el worker ya guardo el audio en WAV; aqui llega lo que dijiste
        if ($script:grabandoNota) {
            $wavN = [string]$script:grabandoNota
            $script:grabandoNota = $null
            $script:seguimientoPendiente = $false
            if (Test-Path -LiteralPath $wavN) {
                try { [System.IO.File]::WriteAllText([System.IO.Path]::ChangeExtension($wavN, '.txt'), $text, (New-Object System.Text.UTF8Encoding($false))) } catch {}
                Log "NOTA DE VOZ guardada: $wavN"
                Send-UIEvento 'hecho'
                Set-UI 'hablando' 'Nota guardada' 2500
            } else {
                Log "NOTA DE VOZ: el worker no dejo el audio"
                Say 'No pude guardar el audio.'
            }
            return
        }
        # TRADUCTOR DE CONVERSACION: lo dicho en el otro idioma se traduce y se
        # oye; despues vuelve a escuchar en ese idioma hasta que no hable nadie
        # o se diga "stop"
        if ($script:traduciendoVoz) {
            $idiomaT = [string]$script:traduciendoVoz
            $script:traduciendoVoz = $null
            if ($plano -match '^(?:stop|para|parar|basta|ya|ya esta|fin|enough|done|that s all|thats all|end)$') {
                $script:seguimientoPendiente = $false
                Log "TRADUCTOR: fin"
                Say 'Fin de la traduccion.'
                return
            }
            $script:traducirPorOir = $idiomaT
            $script:seguimientoPendiente = $true
            $script:seguimientoFactor = 2.4
            $script:respuestaSinTarjeta = $true
            Submit-Command ("Traduce al espanol esto que ha dicho alguien en voz alta. Contesta SOLO con la traduccion, sin comillas ni comentarios: " + $text) 'pregunta'
            return
        }
        # EL VALOR QUE FALTABA a una receta (ver RECETAS QUE PREGUNTAN LO QUE FALTA)
        if ($script:huecoPendiente) {
            $hp = $script:huecoPendiente
            $script:huecoPendiente = $null
            if ($plano -match '^(?:nada|no|dejalo|olvidalo|cancela|da igual|ninguno|ninguna)$') {
                $script:seguimientoPendiente = $false
                Set-UI 'reposo'
                return
            }
            $valorH = $text.Trim().TrimEnd('.', ',', ';', '!', '?').Trim()
            if (($sw.ElapsedMilliseconds - $hp.en) -le 60000 -and $valorH -and $valorH.Length -le 200) {
                $encH = @{ receta = $hp.receta; valores = @{ ([string]$hp.hueco) = $valorH } }
                if (-not $script:confirmado -and (Test-DictadoDudoso)) {
                    # el valor que faltaba llego en un dictado dudoso: se confirma (M7)
                    $script:pendiente = @{ texto = ''; vence = 0; tipo = 'recetaDato'; id = $hp.receta.id; valores = $encH.valores; original = "$($hp.original) $valorH" }
                    $preguntaDatoH = "Entendi: " + (Get-TextoReceta $hp.receta 'resumen' $encH.valores) + ". ¿Es asi?"
                    Say $preguntaDatoH
                    Set-UI 'escuchando' $preguntaDatoH
                    Start-Confirmacion
                } elseif ($script:confirmado -or [int]$hp.receta.confirmadas -ge $RecetasConfirmar) {
                    [void](Start-Receta $encH $hp.original)
                } else {
                    $script:pendiente = @{ texto = ''; vence = 0; tipo = 'receta'; id = $hp.receta.id; valores = $encH.valores; original = "$($hp.original) $valorH" }
                    $preguntaRecH = "Esto ya lo aprendi: " + (Get-TextoReceta $hp.receta 'resumen' $encH.valores) + ". ¿Lo hago?"
                    Say $preguntaRecH
                    Set-UI 'escuchando' $preguntaRecH
                    Start-Confirmacion
                }
                return
            }
        }

        # TRIVIA (F7): lo que digas tras la pregunta de Nova es tu respuesta, sea lo
        # que sea ("Leonardo" a secas, que el filtro de ruido tiraria)
        if ($script:triviaHasta -gt $sw.ElapsedMilliseconds) {
            $script:triviaHasta = 0
            if (Send-Charla $text) { return }
        }
        if ($plano -match '^(?:hazme una pregunta|preguntame algo|ponme a prueba|juguemos a (?:la )?trivia|jugamos a (?:la )?trivia|trivia)$') {
            $script:seguimientoPendiente = $false
            if (Send-Charla 'trivia' $false 'trivia') { return }
            Say 'Para jugar necesito el modelo de charla.'
            return
        }
        # AYUDA CON EL JUEGO QUE TIENES DELANTE (F2): el juego y lo que pone la
        # pantalla van a la API con busqueda web; lo que conteste se aprende
        $juegoAyuda = $null
        if ($ConversacionOn -and $plano -match '^(?:como\s+(?:paso|supero|mato|derroto|venzo|resuelvo|consigo|hago|abro|llego)\b|ayudame\s+con\s+(?:esto|este|esta)\b|que\s+hago\s+(?:aqui|ahora)$|no\s+se\s+como\s+(?:pasar|seguir|hacer|matar|derrotar)\b)') {
            $juegoAyuda = Get-JuegoDeReferencia
        }
        if ($juegoAyuda) {
            $pantallaA = ''
            try { $pantallaA = [string](Invoke-OCR (Save-Captura (Join-Path $TmpDir 'pantalla.png'))) } catch {}
            if ($pantallaA.Length -gt 500) { $pantallaA = $pantallaA.Substring(0, 500) }
            $pideA = "En el juego $($juegoAyuda): $text" + $(if ($pantallaA) { " (en la pantalla pone: $pantallaA)" } else { '' })
            Log "AYUDA DE JUEGO ($juegoAyuda): $text"
            if (Send-Charla $pideA $false 'hablar' @{ buscar = $true; ayuda = $true }) { return }
        }

        # EL CEREBRO PROPIO: "eso no es verdad" en plena charla rechaza lo ultimo que
        # dijo (y se contesta de nuevo por la API); "olvida lo de X" borra lo aprendido
        if ((Test-CharlaCaliente) -and $plano -match '^(?:no\s+)?(?:eso\s+no\s+es\s+(?:verdad|asi|cierto|correcto)|no\s+es\s+(?:verdad|asi|cierto)|te\s+equivocas|estas\s+equivocada|eso\s+esta\s+mal|mentira)\b') {
            if (Send-Charla $text $true) { return }
        }
        if ($ConversacionOn -and $plano -match '^(?:olvida|olvidate\s+de)\s+(?:todo\s+)?lo\s+(?:de|que sabes de|sobre)\s+(?:la\s+|el\s+|los\s+|las\s+)?(.+)$') {
            $temaO = $Matches[1]
            if (Send-CharlaPedido @{ op = 'olvidar_tema'; texto = $temaO }) {
                $script:seguimientoPendiente = $false
                Log "CEREBRO: olvidar lo de '$temaO'"
                Say "Vale, olvido lo de $temaO."
                return
            }
        }

        # MODO INVITADO AUTOMATICO (M7): tres frases en 10 min con una voz que no es
        # la tuya -> despues de contestar, Nova pregunta si pone el modo invitado.
        # Cada dictado cuenta una vez (el tono de una orden escrita es el de antes).
        if (-not $script:invitado -and $SoloYoOn -and $script:ultimaF0 -gt 0 -and $script:ultimaF0 -ne $script:vozAjenaF0Vista) {
            $script:vozAjenaF0Vista = $script:ultimaF0
            if (Test-VozExtrana) {
                $script:vozAjenaVeces = @(@($script:vozAjenaVeces) | Where-Object { ($sw.ElapsedMilliseconds - $_) -lt 600000 }) + @($sw.ElapsedMilliseconds)
                if ($script:vozAjenaVeces.Count -ge 3 -and ($sw.ElapsedMilliseconds - $script:invitadoPropuestoEn) -gt 1800000) { $script:invitadoPropuesta = $true }
            } else {
                $script:vozAjenaVeces = @()
            }
        }
        # LA HORA DEL DESPERTADOR, tras "¿te pongo el despertador?" -> "si" -> "¿a que hora?"
        if ($script:despertadorHora -gt $sw.ElapsedMilliseconds) {
            $script:despertadorHora = 0
            $script:seguimientoPendiente = $false
            if ($plano -match '^(?:no|nada|dejalo|da igual|ninguno|ninguna)$') { Say 'Vale, sin despertador. Buenas noches.'; return }
            $horaD = $plano
            if ($horaD -notmatch '^(?:a\s+las?|para\s+las?|manana|hoy|el\s)') { $horaD = "a las $horaD" }
            $rHora = $null
            try { $rHora = Invoke-DespertadorVoz "despiertame $horaD" } catch {}
            if ($rHora) { Log "DESPERTADOR: $horaD -> $rHora"; Say $rHora; return }
        }
        # DESPERTADOR (F4)
        $rDesp = $null
        try { $rDesp = Invoke-DespertadorVoz $text } catch { $rDesp = $null }
        if ($rDesp) { $script:seguimientoPendiente = $false; Log "DESPERTADOR: $text -> $rDesp"; Send-UIEvento 'hecho'; Say $rDesp; return }
        # RUTINA DE DORMIR (F3). Con un juego delante, "me voy a dormir" la lleva
        # "apunta donde me quede" y la rutina sigue al contestar
        if ($plano -match '^(?:me voy a dormir|me voy a la cama|me voy a acostar|a dormir|hora de dormir|buenas noches nova)$' -and
            -not ($plano -eq 'me voy a dormir' -and (Get-JuegoDeReferencia))) {
            $rRut = Invoke-RutinaDormir
            Log "RUTINA DE DORMIR: $rRut"
            Say $rRut
            if ($script:pendiente) { Set-UI 'escuchando' $rRut; Start-Confirmacion }
            return
        }
        # APAGADO PROGRAMADO (F3): siempre con un si delante
        if ($plano -match '^(?:apagate|apaga\s+(?:la\s+consola|el\s+pc|el\s+ordenador|la\s+computadora))\s+(?:en|dentro\s+de)\s+(\d{1,3}|una|un|media|dos|tres)\s*(hora y media|horas?|minutos?)$') {
            $minA = Get-MinutosDichos $Matches[1] $Matches[2]
            if ($minA -ge 1 -and $minA -le 600) {
                $script:pendiente = @{ texto = ''; vence = 0; tipo = 'apagado'; min = $minA }
                $pregA = "¿Apago la consola en $(Format-MinutosDichos $minA)?"
                Say $pregA
                Set-UI 'escuchando' $pregA
                Start-Confirmacion
                return
            }
        }
        # APAGAR O REINICIAR YA (14/09): antes iba a la IA sin preguntar nada aqui.
        # Siempre con un si, y con 30 s para arrepentirse ("cancela el apagado")
        $apagarYa = ($plano -match '^(?:apaga|apagar)\s+(?:la\s+consola|el\s+pc|el\s+ordenador|la\s+computadora|el\s+equipo)(?:\s+ya|\s+ahora)?$')
        $reiniciarYa = ($plano -match '^(?:reinicia|reiniciar)\s+(?:la\s+consola|el\s+pc|el\s+ordenador|la\s+computadora|el\s+equipo)(?:\s+ya|\s+ahora)?$')
        if ($apagarYa -or $reiniciarYa) {
            $script:pendiente = @{ texto = ''; vence = 0; tipo = $(if ($reiniciarYa) { 'reinicio' } else { 'apagado' }); min = 0 }
            $pregY = if ($reiniciarYa) { '¿Reinicio la consola?' } else { '¿Apago la consola?' }
            Say $pregY
            Set-UI 'escuchando' $pregY
            Start-Confirmacion
            return
        }
        if ($plano -match '^(?:cancela|anula|quita|para)\s+(?:el\s+)?(?:apagado|reinicio)$') {
            try { Start-Process -FilePath 'shutdown.exe' -ArgumentList '/a' -WindowStyle Hidden -Wait } catch {}
            $script:seguimientoPendiente = $false
            Log "APAGADO: cancelado"
            Say 'Apagado cancelado.'
            return
        }
        # LIMITE DE JUEGO PROPIO (F6)
        if ($plano -match '^(?:avisame|dime|recuerdame)\s+cuando\s+lleve\s+(\d{1,3}|una|un|media|dos|tres|cuatro|cinco)\s*(hora y media|horas?|minutos?)(?:\s+(?:jugando|de juego|con el juego|con este juego))?$') {
            $minL = Get-MinutosDichos $Matches[1] $Matches[2]
            $script:limiteJuego = @{ min = $minL; avisos = 0; visto = $false }
            $script:seguimientoPendiente = $false
            Log "LIMITE DE JUEGO: $minL min"
            Say ('Vale, te aviso cuando lleves ' + (Format-MinutosDichos $minL) + $(if ($script:juegoActivo) { " con $($script:juegoActivo)." } else { ' en la proxima partida.' }))
            return
        }
        if ($plano -match '^(?:quita|cancela|olvida)\s+(?:el\s+)?(?:limite|aviso)\s+de\s+(?:juego|tiempo)$') {
            $script:limiteJuego = $null
            $script:seguimientoPendiente = $false
            Say 'Limite quitado.'
            return
        }

        # ORDENES DE ESTOS MODOS
        if ($plano -match '^(?:activa|pon|ponme|entra en)\s+(?:el\s+)?modo\s+invitado$' -or $plano -match '^modo\s+invitado$') {
            $script:invitado = $true
            $script:invitadoUltimo = $sw.ElapsedMilliseconds
            $script:seguimientoPendiente = $false
            Log "MODO INVITADO: dentro"
            Send-UIEvento 'hecho'
            Say 'Modo invitado. No aprendo nada ni miro tus cosas. Se quita solo en media hora sin ordenes.'
            return
        }
        if ($plano -match '^(?:quita|desactiva|apaga|sal del|salir del|termina|fuera)\s+(?:el\s+)?modo\s+invitado$') {
            $script:seguimientoPendiente = $false
            if (-not $script:invitado) { Say 'No estaba puesto.'; return }
            $script:invitado = $false
            Log "MODO INVITADO: fuera (pedido)"
            Send-UIEvento 'hecho'
            Say 'Modo invitado quitado.'
            return
        }
        if ($plano -match '^(?:graba(?:me)?|grabar|guarda(?:me)?)\s+(?:una\s+nota(?:\s+de\s+voz)?|un\s+audio|un\s+mensaje\s+de\s+voz|una\s+nota\s+de\s+audio)(?:\s+para\s+.+)?$') {
            if (-not $DictadoWorker -or -not $script:wakeProc) { Say 'Para grabar notas necesito la escucha por voz.'; return }
            $script:notaPorGrabar = Join-Path (Join-Path $MemoriaDir 'notas-voz') ((Get-Date).ToString('yyyy-MM-dd_HHmmss') + '.wav')
            $script:seguimientoPendiente = $true
            $script:seguimientoFactor = 2.4
            Log "NOTA DE VOZ: preparada"
            Say 'Te escucho.'
            return
        }
        $pideNotaVoz = ''
        if ($plano -match '^(?:reproduce(?:me)?|pon(?:me)?|escucha|escuchar)\s+(?:la\s+|mi\s+)?(?:ultima\s+nota(?:\s+de\s+voz)?|nota\s+de\s+voz)$') { $pideNotaVoz = 'oir' }
        elseif ($plano -match '^(?:lee(?:me)?|que\s+dice|que\s+decia)\s+(?:la\s+|mi\s+)?(?:ultima\s+nota(?:\s+de\s+voz)?|nota\s+de\s+voz)$') { $pideNotaVoz = 'leer' }
        if ($pideNotaVoz) {
            $script:seguimientoPendiente = $false
            $wavU = Get-ChildItem -LiteralPath (Join-Path $MemoriaDir 'notas-voz') -Filter '*.wav' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $wavU) { Say 'No tienes notas de voz.'; return }
            $cuandoN = $wavU.LastWriteTime.ToString('d/M H:mm')
            if ($pideNotaVoz -eq 'leer') {
                $txtU = [System.IO.Path]::ChangeExtension($wavU.FullName, '.txt')
                if (Test-Path -LiteralPath $txtU) { Say ("Tu nota dice: " + [System.IO.File]::ReadAllText($txtU, [System.Text.Encoding]::UTF8)) }
                else { Say 'Esa nota no tiene texto.' }
                return
            }
            try {
                $script:reproductorNota = New-Object System.Media.SoundPlayer $wavU.FullName
                $script:reproductorNota.Play()
                $durN = [int][Math]::Max(500, ($wavU.Length - 44) / 32)   # ms: 16 kHz, 16 bits, mono
                Pausar-Escucha ($durN + 800)   # que no se oiga a si misma diciendo "nova"
                Log "NOTA DE VOZ: reproduzco $($wavU.Name)"
                Set-UI 'hablando' "Nota del $cuandoN" ([Math]::Min(8000, $durN + 1000))
            } catch { Log ("nota de voz: " + $_.Exception.Message); Say 'No pude reproducirla.' }
            return
        }
        $idiomasT = @{ ingles = 'en'; frances = 'fr'; portugues = 'pt'; italiano = 'it'; aleman = 'de'; japones = 'ja'; chino = 'zh'; coreano = 'ko' }
        $RE_IDIOMA_T = '(ingles|frances|portugues|italiano|aleman|japones|chino|coreano)'
        if ($plano -match ('^(?:traduce(?:me)?|traducir)\s+lo\s+que\s+(?:me\s+|te\s+|nos\s+)?(?:diga|digan|dice|dicen|hable|hablen)(?:\s+en\s+' + $RE_IDIOMA_T + ')?$') -or
            $plano -match ('^(?:(?:activa|pon)\s+(?:el\s+)?)?(?:modo\s+)?traductor(?:\s+(?:de|del|en)\s+' + $RE_IDIOMA_T + ')?$')) {
            if (-not $DictadoWorker -or -not $script:wakeProc) { Say 'Para traducir necesito la escucha por voz.'; return }
            $nomT = if ($Matches[1]) { [string]$Matches[1] } else { 'ingles' }
            $script:traducirPorOir = $idiomasT[$nomT]
            $script:seguimientoPendiente = $true
            $script:seguimientoFactor = 2.4
            Log "TRADUCTOR: escucho en $nomT ($($script:traducirPorOir))"
            Say "Te escucho en $nomT."
            return
        }
        # en seguimiento, "gracias" / "nada mas" cierran la cadena con elegancia
        if ($script:enSeguimiento -and $plano -match '^(?:gracias|muchas gracias|ok gracias|vale gracias|nada mas|eso es todo|eso es todo gracias|listo|ya esta|ya|nada|no nada|ok|vale)$') {
            Log "seguimiento: cerrado con '$text'"
            $script:enSeguimiento = $false
            $script:seguimientoPendiente = $false
            if ($plano -match 'gracias') { Say "De nada." } else { Set-UI 'reposo' }
            return
        }
        # "GRACIAS" FUERA DEL SEGUIMIENTO (15/09): tras una tarea larga, braya dijo "gracias"
        # con el boton y Nova contesto "No te entendi" (se tomaba por ruido).
        # tambien "entiendo, gracias", "perfecto, gracias"... (15/09: acababa en "No te entendi")
        if ($plano -match '^(?:(?:ok|okay|vale|perfecto|genial|listo|muy bien|entiendo|entendido|de acuerdo|bueno)\s+)?(?:muchas\s+)?gracias(?:\s+nova)?$') {
            Log "cortesia: '$text'"
            $script:seguimientoPendiente = $false
            Say "De nada."
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

        # RESUMIR LA PANTALLA y APUNTAR DONDE ME QUEDE LEYENDOLA (13/09): el mismo
        # camino que traducir. "Resumeme esto" lo resume en voz. "Apunta donde me
        # quede" (o "lo dejo por hoy" con un juego delante o recien cerrado) le
        # pide al cerebro, con el texto del menu de pausa, la zona o mision, y lo
        # guarda como nota del juego al llegar la respuesta (ver Report-Reply).
        $pideResumen = ($plano -match '^(?:resumeme|resume|resumelo|resumemelo)\s+(?:esto|la pantalla|lo que hay en (?:la )?pantalla|esta pagina|este texto)$' -or $plano -match '^de que va esto$')
        $pideDonde = ($plano -match '^(?:apunta|guarda|anota)\s+(?:donde|por donde|en que parte)\s+(?:me quede|voy|estoy|iba)$' -or $plano -match '^(?:lo dejo por hoy|lo dejo aqui|me voy a dormir)$')
        if ($pideDonde -and -not (Get-JuegoDeReferencia)) { $pideDonde = $false }
        # "me voy a dormir" con un juego: primero donde te quedaste, luego la rutina (F3)
        $script:rutinaDormirTrasNota = ($pideDonde -and $plano -eq 'me voy a dormir')
        if ($pideResumen -or $pideDonde) {
            Set-UI 'pensando' 'leyendo la pantalla'
            $visR = ''
            try { $visR = Invoke-OCR (Save-Captura (Join-Path $TmpDir 'pantalla.png')) } catch { Log ("leer pantalla: " + $_.Exception.Message) }
            if (-not $visR) {
                Log "LEER PANTALLA: el OCR no encontro texto"
                Show-Popup 'No veo texto en la pantalla'
                Say 'No veo texto en la pantalla'
                return
            }
            if ($visR.Length -gt 2500) { $visR = $visR.Substring(0, 2500) }
            $script:respuestaSinTarjeta = $true
            if ($pideDonde) {
                $script:notaJuegoPendiente = Get-JuegoDeReferencia
                Log "DONDE ME QUEDE: leo la pantalla de $($script:notaJuegoPendiente)"
                Submit-Command ("Este es el texto que se ve en la pantalla de un videojuego. Di en 3 a 8 palabras donde esta el jugador (zona, mision, capitulo o jefe), sin nada mas. Si no se puede saber, responde solo: no lo se. Texto: " + $visR) 'pregunta'
            } else {
                Log "RESUMIR PANTALLA: $($visR.Length) caracteres"
                Submit-Command ("Resume en una o dos frases, en espanol y para decirlo en voz alta, lo que dice este texto de mi pantalla. Texto: " + $visR) 'pregunta'
            }
            return
        }

        # TRADUCIR LA PANTALLA (13/09): "¿que dice esto?" en un juego en ingles.
        # Se lee la pantalla (OCR, local) y SOLO ese texto va al cerebro, que
        # contesta en una o dos frases. La respuesta se oye, sin tarjeta.
        if ($plano -match '^(?:que dice esto|que dice aqui|que pone aqui|que pone en la pantalla|que dice la pantalla|que significa esto|traduce(?:me)?\s+(?:esto|la pantalla|lo que (?:hay|pone|dice)(?: en (?:la )?pantalla)?))$') {
            Set-UI 'pensando' 'leyendo la pantalla'
            $visT = ''
            try { $visT = Invoke-OCR (Save-Captura (Join-Path $TmpDir 'pantalla.png')) } catch { Log ("traducir pantalla: " + $_.Exception.Message) }
            if (-not $visT) {
                Log "TRADUCIR PANTALLA: el OCR no encontro texto"
                Show-Popup 'No veo texto en la pantalla'
                Say 'No veo texto en la pantalla'
                return
            }
            if ($visT.Length -gt 1500) { $visT = $visT.Substring(0, 1500) }
            Log "TRADUCIR PANTALLA: $($visT.Length) caracteres"
            $script:respuestaSinTarjeta = $true
            Submit-Command ("Traduce al espanol lo que dice este texto de mi pantalla, en una o dos frases naturales y sin explicar nada mas. Si ya esta en espanol, resumelo en una frase. Texto: " + $visT) 'pregunta'
            return
        }

        # LO QUE VES EN MI PANTALLA (15/09, elegido por braya: "si, con captura"). Antes lo
        # hacia el agente: "quiero que veas que hay en mi pantalla" tardo 87 s (Claude
        # Code con captura por MCP). Ahora la captura de la ventana va con la pregunta
        # a la API, que la mira y contesta en una o dos frases.
        # ...pero no si es una orden: "abre el juego que tengo en pantalla" acababa aqui y la API
        # contestaba NO, sin hacer nada (15/09). Eso lo resuelve EL JUEGO QUE SALE EN PANTALLA.
        if ($plano -notmatch '\b(?:abre|abras|abrir|abrelo|inicia|inicies|iniciar|arranca|lanza|juega|cierra|cierres|pon|ponme)\b' -and
            $plano -match '\b(?:que (?:ves?|hay|sale|aparece|tengo) en (?:mi |la |esta )?pantalla|que es lo que ves|lo que (?:ves|hay) en (?:mi |la |esta )?pantalla|describe(?:me)? (?:mi |la |esta |el )?(?:fondo de )?pantalla|(?:mi|el) fondo de pantalla|mira (?:mi |la |esta )?pantalla)\b') {
            Set-UI 'pensando' 'mirando la pantalla'
            $capV = ''
            try { $capV = Save-Captura (Join-Path $TmpDir 'pantalla.png') } catch { Log ("ver pantalla: " + $_.Exception.Message) }
            if ($capV) {
                Log "VER PANTALLA: captura adjunta para '$text'"
                $script:respuestaSinTarjeta = $true
                Submit-Command ("Mira esta captura de la ventana que tengo delante y contesta a lo que te pido en una o dos frases cortas y naturales, porque se leera en voz alta. Lo que te pido: " + $text) 'pregunta' $capV
                return
            }
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

        # 0) REPASO DE LO DUDOSO AUNQUE SE ENTIENDA (14/09). El oido fino solo se
        #    pedia cuando la capa local no entendia nada; si el modelo rapido oia
        #    MAL pero con forma de orden, se hacia otra cosa sin mas. Medido con las
        #    20 grabaciones: toda orden que base entiende bien trae una seguridad de
        #    -0,73 o mejor, y lo que oye destrozado baja de -0,8. Por debajo de
        #    $RepasoDudosoUmbral se repasa ANTES de hacer nada; si el repaso no
        #    aporta, se hace lo que se oyo primero (ver OIDO FINO: recoger).
        if ($WhisperPreciso -and $script:ordenPorWorker -and -not $script:yaReintentado -and
            $script:wakeProc -and -not $script:wakeProc.HasExited -and
            ($sw.ElapsedMilliseconds - $script:dictadoConfianzaEn) -lt 15000 -and
            ($script:dictadoConfianza -lt $RepasoDudosoUmbral -or ($script:dictadoEco -and $script:dictadoConfianza -lt $RepasoEcoUmbral)) -and
            (Test-FastCommand $text)) {
            $script:yaReintentado = $true
            try {
                Remove-Item -LiteralPath $RutaReintento -Force -ErrorAction SilentlyContinue
                [System.IO.File]::WriteAllText($MarcaReintento, 'x')
                $script:reintentoTexto = $text
                Add-OidoDudoso $text
                $script:reintentoReconocida = $true
                # el eco del ejemplo NO se hace si el repaso no lo confirma (ver ECO DE LA FRASE DE EJEMPLO)
                $script:reintentoEco = ($script:dictadoEco -and $script:dictadoConfianza -lt $RepasoEcoUmbral)
                if ($script:reintentoEco) { Log "OIDO FINO: '$text' es la frase de ejemplo de Whisper con poca seguridad ($($script:dictadoConfianza)); lo confirmo antes" }
                $script:reintentoVence = $sw.ElapsedMilliseconds + $ReintentoMaxMs
                Log "OIDO FINO: '$text' se entiende pero Whisper dudaba ($($script:dictadoConfianza)); lo repaso antes de hacerlo"
                Add-Estadistica 'fino' $text
                Set-UI 'pensando' 'Afinando el oido'
                return
            } catch {
                $script:reintentoVence = 0
                $script:reintentoReconocida = $false
                Log ('no se pudo pedir el repaso: ' + $_.Exception.Message)
            }
        }

        # LAS QUEJAS REHACEN LA ORDEN (ver Get-OrdenCorregida). Va antes que nada
        # porque una queja puede encajar por accidente en una regla local ("no es el
        # wifi, es el bluetooth" tiene dentro una orden de radio) y porque despues
        # solo quedan la memoria, la charla y el modelo, que es donde se perdian.
        if (-not $script:corrigiendo -and -not $script:pendiente -and -not $script:invitado) {
            $corr = $null
            try { $corr = Get-OrdenCorregida $text } catch { $corr = $null }
            if ($corr) {
                $corrOk = $false
                try { $corrOk = [bool](Test-FastCommand $corr) } catch { $corrOk = $false }
                if ($corrOk) {
                    Log "CORRECCION: '$text' -> '$corr' (la ultima fue '$($script:ultimaOrden.texto)')"
                    Add-Estadistica 'correccion' "$text -> $corr"
                    $script:corrigiendo = $true
                    try { Process-Texto $corr } finally { $script:corrigiendo = $false }
                    return
                }
                Log "CORRECCION: de '$text' sale '$corr', que no se hacer; sigue su camino"
            }
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
                $script:ultimaOrden = @{ texto = $text; desc = [string]$fast; cuando = $sw.ElapsedMilliseconds }
                $script:noEntendiSeguidos = 0
                Add-Estadistica 'local' $text
                # tus costumbres, para proponerte automatizarlas (ver HABITOS)
                # lo que tuvo que confirmarse (peligroso, dudoso, voz ajena) no es
                # una costumbre que automatizar (revision del 13/09)
                if (-not $script:confirmado) { try { Add-Habito $text } catch {} }
                # esta orden se entendio y se hizo: su tono eres tu. Es la unica
                # fuente limpia que hay, y la que evita que el ruido acabe
                # pasando por dueno de la casa.
                Update-MiVoz $script:ultimaF0
                $script:ultimaRespuesta = $fast
                Send-UIEvento 'hecho'
                Show-Popup $fast
                Say $fast
                # la parte de charla de una frase mixta: se contesta detras (ver LAS DOS COSAS A LA VEZ)
                if ($script:charlaResto) {
                    $restoC = $script:charlaResto
                    $script:charlaResto = ''
                    [void](Send-Charla $restoC)
                }
            }
        }
        # 1b) memoria: buscar en las notas ANTES de molestar al modelo
        elseif ($plano -match $RE_MEMORIA) {
            $enc = $null
            if ($script:invitado) { Say 'En modo invitado no miro tus notas.'; return }
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
        # 2) pregunta: que CONTESTE, no que actue. Va a la CONVERSACION (local o
        #    API, ver CONVERSACION DE VERDAD); sin ella, al cerebro de siempre
        elseif ($plano -match $RE_PREGUNTA) {
            if (-not (Send-Charla $text)) { Submit-Command $text 'pregunta' }
        }
        else {
            # 3) ¿ya aprendimos a traducir esta orden? entonces es instantanea
            $apr = Find-Traduccion $text
            if ($apr) {
                $r = $null
                try { $r = Invoke-FastCommand $apr } catch { $r = $null }
                if ($r) {
                    Log "APRENDIDA: '$text' -> '$apr' -> $r"
                    $script:ultimaOrden = @{ texto = $apr; desc = [string]$r; cuando = $sw.ElapsedMilliseconds }
                    $script:ultimaAprendida = $text
                    if ($script:ultimaAprendida) { Log "(si dices 'no era eso', la olvido)" }
                    Add-Estadistica 'aprendida' $text
                    Update-MiVoz $script:ultimaF0
                    $script:ultimaRespuesta = $r
                    Send-UIEvento 'hecho'
                    Show-Popup $r
                    Say $r
                    return
                }
            }
            # 3b) ¿una RECETA aprendida encaja? Entonces se hace sin IA: las
            #     primeras veces preguntando, y despues directamente (ver RECETAS)
            $recEnc = $null
            try { $recEnc = Find-Receta $text } catch { $recEnc = $null }
            if ($recEnc) {
                # UNA RECETA DE INFORMACION NO SE PREGUNTA (16/09): solo mira y dice, no
                # cambia nada, asi que preguntar "¿lo hago?" molesta sin proteger de nada.
                if ([string]$recEnc.receta.tipo -eq 'info') {
                    [void](Start-Receta $recEnc $text)
                    return
                }
                if (-not $script:confirmado -and @($recEnc.valores.Keys).Count -gt 0 -and (Test-DictadoDudoso)) {
                    # el dictado salio dudoso y la receta usa lo oido: se confirma el dato (M7)
                    $script:pendiente = @{ texto = ''; vence = 0; tipo = 'recetaDato'; id = $recEnc.receta.id; valores = $recEnc.valores; original = $text }
                    $preguntaDato = "Entendi: " + (Get-TextoReceta $recEnc.receta 'resumen' $recEnc.valores) + ". ¿Es asi?"
                    Log "RECETA $($recEnc.receta.id): dictado dudoso ($($script:dictadoConfianza)); confirmo el dato antes"
                    Say $preguntaDato
                    Set-UI 'escuchando' $preguntaDato
                    Start-Confirmacion
                } elseif ($script:confirmado -or [int]$recEnc.receta.confirmadas -ge $RecetasConfirmar) {
                    [void](Start-Receta $recEnc $text)
                } else {
                    $script:pendiente = @{ texto = ''; vence = 0; tipo = 'receta'; id = $recEnc.receta.id; valores = $recEnc.valores; original = $text }
                    $preguntaRec = "Esto ya lo aprendi: " + (Get-TextoReceta $recEnc.receta 'resumen' $recEnc.valores) + ". ¿Lo hago?"
                    Log "RECETA $($recEnc.receta.id): pregunto antes de repetir '$text'"
                    Say $preguntaRec
                    Set-UI 'escuchando' $preguntaRec
                    Start-Confirmacion
                }
                return
            }
            # 3c) una receta a la que le falta el valor del final: se pregunta y
            #     la respuesta llega por el seguimiento (ver $script:huecoPendiente)
            $recInc = $null
            try { $recInc = Find-RecetaIncompleta $text } catch { $recInc = $null }
            if ($recInc) {
                $script:huecoPendiente = @{ receta = $recInc.receta; hueco = $recInc.hueco; original = $text; en = $sw.ElapsedMilliseconds }
                $script:seguimientoPendiente = $true
                $script:seguimientoFactor = 2.4
                $preguntaH = "¿Que $($recInc.hueco -replace '_', ' ')?"
                Log "RECETA $($recInc.receta.id): falta '$($recInc.hueco)' en '$text', lo pregunto"
                Say $preguntaH
                return
            }
            # 3.5) FILTRO DE RUIDO. Lo que llega aqui no lo entendio la capa
            #      local, y el siguiente paso lo manda al agente con --auto,
            #      que puede hacer CUALQUIER COSA en el disco. Una frase de una
            #      o dos palabras sueltas casi nunca es una orden: es el
            #      microfono mal transcrito ("Oh", "Ok", "El", "Meme"). Antes
            #      esos restos se ejecutaban y por eso se abrian cosas que
            #      nadie habia pedido. Se pide repetir en vez de adivinar.
            # EN PLENA CONVERSACION, una respuesta corta ("si, claro", "no mucho")
            # es charla, no ruido: sigue la conversacion (ver CONVERSACION DE VERDAD)
            if ($script:enSeguimiento -and ($sw.ElapsedMilliseconds - $script:charlaUltima) -lt 60000 -and -not (Test-VozExtrana) -and (Send-Charla $text)) { return }
            $palabras = @(($text -split '\s+') | Where-Object { $_ -ne '' })
            if ($palabras.Count -le 2 -and $text.Length -lt 18) {
                Log "RUIDO descartado (no llega al agente): '$text'"
                $script:seguimientoPendiente = $false   # un descarte no encadena: era ruido
                Add-Estadistica 'ruido' $text
                Add-RuidoRacha
                Send-UIEvento 'gesto:confuso'
                Show-Popup "No te entendi. Repitelo." 'error'
                Say "No te entendi"
                Open-EscuchaTrasNoEntendi
                return
            }
            # 3.6) CHARLA o VOZ AJENA: no era para mi. Se descarta EN SILENCIO:
            #      si estas hablando con alguien, un "no te entendi" en mitad
            #      de la conversacion es justo lo que sobra. Y no se manda al
            #      agente, que tardaba 15-20 s en decidir que no era nada
            #      mientras la capsula decia "Entendiendo".
            # PERO NO ANTES DEL OIDO FINO (revision del 12/09): una orden larga
            # con el verbo destrozado ("Abresteen y pongo Molyworld ahora
            # mismo") parece charla, y es justo lo que el repaso rescata. Si
            # esta frase va a repasarse, se espera: tras el repaso vuelve aqui
            # con $script:yaReintentado puesto y entonces si se juzga.
            $vaARepasar = ($WhisperPreciso -and $script:ordenPorWorker -and -not $script:yaReintentado -and
                           $script:wakeProc -and -not $script:wakeProc.HasExited -and (Test-MereceRepaso $text))
            $esCharla = (-not $vaARepasar) -and (Test-Charla $text)
            $esAjena = (-not $vaARepasar) -and (Test-VozExtrana)
            # charla TUYA: ya no se descarta, se conversa (ver CONVERSACION DE
            # VERDAD). La voz que no es la tuya se sigue descartando en silencio.
            if ($esCharla -and -not $esAjena -and (Send-Charla $text)) { return }
            if ($esCharla -or $esAjena) {
                $porque = if ($esAjena) { 'voz que no es la tuya' } else { 'charla' }
                Log "CHARLA descartada ($porque, no llega al agente): '$text'"
                $script:seguimientoPendiente = $false
                # 'descarte' y no 'charla': 'charla' ya es el modo de hablar con
                # la IA, y esto es un despertar para nada
                Add-Estadistica 'descarte' $text
                Set-UI 'reposo'
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
            if ($WhisperPreciso -and $script:ordenPorWorker -and -not $script:yaReintentado -and
                $script:wakeProc -and -not $script:wakeProc.HasExited -and
                (Test-MereceRepaso $text)) {
                $script:yaReintentado = $true
                try {
                    Remove-Item -LiteralPath $RutaReintento -Force -ErrorAction SilentlyContinue
                    [System.IO.File]::WriteAllText($MarcaReintento, 'x')
                    $script:reintentoTexto = $text
                    Add-OidoDudoso $text
                    $script:reintentoVence = $sw.ElapsedMilliseconds + $ReintentoMaxMs
                    Log "OIDO FINO: no reconoci '$text', pido repaso"
                    Add-Estadistica 'fino' $text
                    Set-UI 'pensando' 'Afinando el oido'
                    return
                } catch {
                    $script:reintentoVence = 0
                    Log ('no se pudo pedir el repaso: ' + $_.Exception.Message)
                }
            }

            if ($WhisperPreciso -and $script:ordenPorWorker -and -not $script:yaReintentado -and
                -not (Test-MereceRepaso $text)) {
                # se cuenta para poder ver cuanto se ahorra de verdad
                Add-Estadistica 'fino-ahorrado' $text
                Log "OIDO FINO: no lo pido, '$text' no tiene ninguna palabra de 4 letras y el repaso se descartaria igual"
            }

            # EN PLENA CONVERSACION (M10) lo que no entiende la capa local va a la
            # charla: con lo hablado delante sabe si "ponlo mas bajo" es una orden
            # (y la reescribe entera) o parte de la conversacion
            # (y fuera de ella, lo que parece conversacion: ver Test-PareceCharla)
            if (((Test-CharlaCaliente) -or (Test-PareceCharla $text)) -and (Send-Charla $text)) { return }
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
        if (-not $UiNuevaOn) { Play-Sonido 'no-pude' ([System.Media.SystemSounds]::Hand) }
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
$script:ultimaOrden = $null     # la ultima orden HECHA, para que una queja la rehaga
$script:corrigiendo = $false
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
# PANEL RAPIDO (13/09): doble toque en ≡ y la capsula enseña UNA linea,
# "‹ Volumen ›". La cruceta izquierda/derecha cambia de cosa; arriba/abajo la
# ajusta; A hace lo suyo (silenciar, pausar); B cierra, y solo se cierra a los
# 6 s sin tocar nada. Nada de ventanas nuevas: la misma capsula de siempre.
# El volumen va con las teclas multimedia (Windows no deja leerlo aqui, pero
# su propio indicador ya lo enseña); el brillo si se lee y se dice.
# OJO: XInput no es exclusivo. Con un juego delante, la cruceta le llega
# tambien al juego mientras el panel esta abierto.
$XINPUT_ARR = 0x0001
$XINPUT_ABA = 0x0002
$XINPUT_IZQ = 0x0004
$XINPUT_DER = 0x0008
$PanelItems = @('volumen', 'brillo', 'musica', 'energia', 'salida')
$script:panelEnergia = ''
$script:panelSalida = $null
$script:panel = $null
$script:toqueEn = 0
$script:panelBrillo = -1
function Open-PanelRapido {
    $script:panelBrillo = -1
    try { $script:panelBrillo = [int]((Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness) } catch {}
    $script:panel = @{ i = 0; hasta = $sw.ElapsedMilliseconds + 6000; nota = '' }
    $script:panelEnergia = ''; $script:panelSalida = $null   # se releen al llegar a ellos
    Log "PANEL RAPIDO: abierto"
    Start-Vibracion @(30, 40, 30) 14000
    Show-PanelRapido
}
function Close-PanelRapido([bool]$tocarUI = $true) {
    if (-not $script:panel) { return }
    $script:panel = $null
    Log "PANEL RAPIDO: cerrado"
    if ($tocarUI) { Set-UI 'reposo' }
}
function Show-PanelRapido {
    if (-not $script:panel) { return }
    $item = $PanelItems[$script:panel.i]
    $etq = switch ($item) {
        'volumen' { 'Volumen' }
        'brillo' { if ($script:panelBrillo -ge 0) { "Brillo $($script:panelBrillo)%" } else { 'Brillo' } }
        'musica' { if ($script:uiMusica -and $script:musicaTitulo) { $tt = $script:musicaTitulo; if ($tt.Length -gt 18) { $tt = $tt.Substring(0, 17) + '…' }; [string][char]0x266A + " $tt" } else { 'Musica' } }
        # ENERGIA Y SONIDO EN EL PANEL (13/09): se leen al llegar a ellos, no al abrir
        'energia' {
            if (-not $script:panelEnergia) { try { $script:panelEnergia = Get-ModoEnergia } catch {} }
            if ($script:panelEnergia) { "Energia: $($script:panelEnergia)" } else { 'Energia' }
        }
        'salida' {
            if ($null -eq $script:panelSalida) { try { $script:panelSalida = [string](@(Get-SalidasAudio | Where-Object { $_.actual }) | Select-Object -First 1).nombre } catch { $script:panelSalida = '' } }
            $ns = [string]$script:panelSalida; if ($ns.Length -gt 18) { $ns = $ns.Substring(0, 17) + '…' }
            if ($ns) { "Sonido: $ns" } else { 'Sonido' }
        }
    }
    if ($script:panel.nota) { $etq += " $($script:panel.nota)" }
    Set-UI 'atenta' ([string][char]0x2039 + " $etq " + [char]0x203A) 6500
}
function Invoke-PanelRapido([int]$pul) {
    $item = $PanelItems[$script:panel.i]
    $arriba = ($pul -band $XINPUT_ARR) -ne 0
    $abajo = ($pul -band $XINPUT_ABA) -ne 0
    $boton = ($pul -band $XINPUT_A) -ne 0
    switch ($item) {
        'volumen' {
            if ($boton) { Send-Key 0xAD; $script:panel.nota = 'silencio' }
            else { $vk = if ($arriba) { 0xAF } else { 0xAE }; Send-Key $vk; Send-Key $vk; $script:panel.nota = $(if ($arriba) { [string][char]0x25B2 } else { [string][char]0x25BC }) }
        }
        'brillo' {
            if ($arriba -or $abajo) {
                if ($script:panelBrillo -lt 0) { $script:panelBrillo = 50 }
                $script:panelBrillo = [Math]::Max(0, [Math]::Min(100, $script:panelBrillo + $(if ($arriba) { 10 } else { -10 })))
                Set-Brillo $script:panelBrillo
                $script:panel.nota = ''
            }
        }
        'energia' {
            # arriba/A: mas rendimiento; abajo: mas ahorro
            $ordenE = @('ahorro', 'equilibrado', 'rendimiento')
            $actE = [array]::IndexOf($ordenE, [string]$script:panelEnergia)
            if ($actE -lt 0) { $actE = 1 }
            $nuevoE = if ($abajo) { [Math]::Max(0, $actE - 1) } else { [Math]::Min(2, $actE + 1) }
            try { if (Set-ModoEnergia $ordenE[$nuevoE]) { $script:panelEnergia = $ordenE[$nuevoE] } } catch {}
            $script:panel.nota = ''
        }
        'salida' {
            # arriba/abajo/A: la siguiente o la anterior salida de sonido
            try {
                $listaP = @(Get-SalidasAudio)
                if ($listaP.Count -gt 1) {
                    $iP = 0; for ($k = 0; $k -lt $listaP.Count; $k++) { if ($listaP[$k].actual) { $iP = $k } }
                    $iP = if ($abajo) { ($iP + $listaP.Count - 1) % $listaP.Count } else { ($iP + 1) % $listaP.Count }
                    [NovaAudio.Salida]::Poner($listaP[$iP].id)
                    $script:panelSalida = $listaP[$iP].nombre
                    $script:panel.nota = ''
                } else { $script:panel.nota = '(solo hay una)' }
            } catch { $script:panel.nota = '(no pude)' }
        }
        'musica' {
            if ($boton) { Send-Key 0xB3; $script:panel.nota = 'play/pausa' }
            elseif ($arriba) { Send-Key 0xB0; $script:panel.nota = 'siguiente' }
            elseif ($abajo) { Send-Key 0xB1; $script:panel.nota = 'anterior' }
        }
    }
    Start-Vibracion @(20) 12000
    Log "PANEL RAPIDO: $item $(if ($boton) { 'A' } elseif ($arriba) { 'arriba' } else { 'abajo' })"
}

$pollErrs = 0
# botones del mando en la vuelta anterior: A y B contestan preguntas (ver abajo)
$XINPUT_A = 0x1000
$XINPUT_B = 0x2000
$script:botonesPrev = 0
$script:mandoRespondioEn = -100000

$script:erroresBucle = 0
while ($true) {
    # RED DEL BUCLE (auditoria del 13/09): con $ErrorActionPreference = Stop, una
    # sola excepcion sin capturar en cualquier punto de la vuelta apagaba el
    # asistente hasta el siguiente inicio de sesion. Ahora se anota y se sigue.
    try {
    [System.Windows.Forms.Application]::DoEvents()
    $startNow = $false
    $botones = 0
    $pollOk = $true
    # tras un fallo de XInput se espera 5 s SIN bloquear el bucle: el resto
    # (escucha, popups, trabajos) tiene que seguir atendiendose
    $saltarPoll = ($script:pollReintento -gt 0 -and $sw.ElapsedMilliseconds -lt $script:pollReintento)
    for ($u = 0; (-not $saltarPoll) -and $u -lt 4; $u++) {
        try {
            $state = New-Object AX+XINPUT_STATE
            $r = [AX]::XInputGetState([uint32]$u, [ref]$state)
            if ($r -eq 0) { $botones = $botones -bor [int]$state.Gamepad.wButtons }
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

    # RESPONDER CON EL MANDO (13/09): con una pregunta de si/no esperando, A es
    # si y B es no. Solo mientras hay pregunta: el resto del tiempo A y B son
    # del juego y aqui no se tocan. Cuenta la PULSACION (el flanco), no tenerlo
    # apretado: si ya lo tenias pulsado jugando cuando llego la pregunta, no
    # vale como respuesta. Una pregunta peligrosa ("cierra todos los
    # programas") sigue pidiendo un si hablado; B si la cancela.
    $pulsadoA = (($botones -band $XINPUT_A) -ne 0) -and (($script:botonesPrev -band $XINPUT_A) -eq 0)
    $pulsadoB = (($botones -band $XINPUT_B) -ne 0) -and (($script:botonesPrev -band $XINPUT_B) -eq 0)
    # todos los botones que se ACABAN de pulsar en esta vuelta (los usa el panel)
    $pulsados = [int]$botones -band (-bnot [int]$script:botonesPrev)
    $script:botonesPrev = $botones
    # Revision del 13/09: jugando, A es el boton que mas se pulsa; ahi solo vale
    # con ≡ apretado a la vez (≡+A / ≡+B). Y nunca mientras suena la pregunta.
    $conMenu = (($botones -band $TRIGGER) -eq $TRIGGER)
    $mandoVale = ((-not $script:juegoActivo) -or $conMenu) -and ($sw.ElapsedMilliseconds -ge $script:pausaHasta)
    if (($pulsadoA -or $pulsadoB) -and $mandoVale -and $conMenu) { $holdFired = $true; $script:mandoRespondioEn = $sw.ElapsedMilliseconds }   # que ≡ no dispare el hold
    if (($pulsadoA -or $pulsadoB) -and $mandoVale -and $script:pendiente -and -not $script:busy -and -not $script:panel) {
        try {
            if ($pulsadoB) {
                Log "CONFIRMAR con el mando: B (no)"
                Start-Vibracion @(40, 50, 40) 14000
                Complete-Confirmacion 'no'
                Send-UIEvento 'gesto:negar'   # la carita niega (13/09)
            } elseif ($script:pendiente.tipo -eq 'peligrosa') {
                Log "mando: A no vale para una pregunta peligrosa; hace falta un si hablado"
                Start-Vibracion @(120) 20000
                Set-UI 'confirmando' 'Dimelo en voz alta'
            } else {
                Log "CONFIRMAR con el mando: A (si)"
                Start-Vibracion @(70) 14000
                # la carita asiente ANTES de hacerlo: lo que venga despues (el "hecho")
                # pisaria el gesto en la misma vuelta de la capsula (13/09)
                Send-UIEvento 'gesto:asentir'
                Start-Sleep -Milliseconds 120
                Complete-Confirmacion 'si'
            }
        } catch { Log "mando A/B error: $($_.Exception.Message)" }
    }

    # PANEL RAPIDO abierto: la cruceta y A/B son suyos (ver PANEL RAPIDO)
    if ($script:panel) {
        try {
            if ($script:pendiente -or $script:busy -or $script:armed) {
                Close-PanelRapido $false   # otra cosa manda en la capsula: no la pises
            } elseif ($sw.ElapsedMilliseconds -ge $script:panel.hasta) {
                Close-PanelRapido
            } elseif ($pulsados -ne 0) {
                $script:panel.hasta = $sw.ElapsedMilliseconds + 6000
                if ($pulsados -band $XINPUT_B) { Close-PanelRapido }
                elseif ($pulsados -band $XINPUT_IZQ) { $script:panel.i = ($script:panel.i + $PanelItems.Count - 1) % $PanelItems.Count; $script:panel.nota = ''; Show-PanelRapido }
                elseif ($pulsados -band $XINPUT_DER) { $script:panel.i = ($script:panel.i + 1) % $PanelItems.Count; $script:panel.nota = ''; Show-PanelRapido }
                elseif ($pulsados -band ($XINPUT_ARR -bor $XINPUT_ABA -bor $XINPUT_A)) { Invoke-PanelRapido $pulsados; Show-PanelRapido }
            }
        } catch { Log ("panel rapido: " + $_.Exception.Message); $script:panel = $null }
    }

    # DOBLE TOQUE en ≡ (dos pulsaciones cortas en menos de 450 ms): abre o cierra
    # el panel rapido. Un toque corto no hacia nada hasta ahora, y mantenerlo
    # (dictar) sigue igual: soltar despues del hold no cuenta como toque.
    if (-not $startNow -and $startPrev -and -not $holdFired) {
        if ($script:toqueEn -gt 0 -and ($sw.ElapsedMilliseconds - $script:toqueEn) -le 450) {
            $script:toqueEn = 0
            try {
                if ($script:panel) { Close-PanelRapido }
                elseif (-not $script:armed -and -not $script:pendiente -and -not $script:busy) { Open-PanelRapido }
            } catch { Log ("panel rapido: " + $_.Exception.Message) }
        } else {
            $script:toqueEn = $sw.ElapsedMilliseconds
        }
    }
    if ($startNow -and -not $startPrev) {
        $downSince = $sw.ElapsedMilliseconds
        $holdFired = $false
    }
    # si ≡ se uso como ≡+A / ≡+B para contestar, mantenerlo no dicta (revision 13/09)
    if ($startNow -and -not $holdFired -and ($sw.ElapsedMilliseconds - $downSince) -ge $HOLD_MS -and
        ($sw.ElapsedMilliseconds - $script:mandoRespondioEn) -gt 1500) {
        $holdFired = $true
        try {
            if ($script:pendiente -and -not $script:busy) {
                # HAY UNA PREGUNTA ESPERANDO. Contestar "si" en voz alta con un
                # juego sonando es lo que menos funciona, y el mando ya lo tienes
                # en la mano: mantener el boton vale por un si.
                # ...SALVO que sea peligrosa ("cierra todos los programas"):
                # ahi el mismo gesto que cancela cuando estoy ocupada no puede
                # valer por un si. Un boton mantenido "para cortar" cerraba todo.
                if ($script:pendiente.tipo -eq 'peligrosa') {
                    Log "CANCELAR con el boton (la pregunta era peligrosa: solo vale un si hablado)"
                    Start-Vibracion @(70, 60, 70) 16000
                    Complete-Confirmacion 'no'
                } else {
                    Log "CONFIRMAR con el boton"
                    Start-Vibracion @(70) 14000      # un toque corto: "recibido"
                    Complete-Confirmacion 'si'
                }
            } elseif ($script:busy) {
                # Un hold mientras opencode trabaja = cancelar. Antes esta
                # pulsacion se perdia: el bucle estaba bloqueado esperando.
                Log "CANCELAR (hold durante procesamiento)"
                if (-not $UiNuevaOn) { Play-Sonido 'no-pude' ([System.Media.SystemSounds]::Hand) }
                Stop-OpencodeJob
                Add-Estadistica 'error' 'cancelado'
                Send-UIEvento 'gesto:sobresalto'
                Show-Popup "Orden cancelada." 'error'
            } elseif ($script:dictandoLargo) {
                # SALIDA POR EL BOTON. Un modo que escribe en la ventana de
                # delante tiene que poder cerrarse sin hablar: si el microfono
                # no te oye, decir "ya esta" no vale de nada.
                Log "DICTADO LARGO: cerrado con el boton"
                Start-Vibracion @(70, 60, 70) 16000
                Remove-Item -LiteralPath $MarcaDictar -Force -ErrorAction SilentlyContinue
                $script:armed = $false
                $capture.Hide()
                Stop-DictadoLargo 'el boton'
            } elseif (-not $script:armed) {
                Start-Dictado "mantener ≡"
            } elseif ($script:ordenPorWorker -and $script:wakeProc) {
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

    # --- VIGILANCIA DEL OIDO DE WINDOWS ---
    # Si muere, el asistente sigue tan campante con Whisper, asi que el fallo
    # es invisible: el usuario solo notaria que "ya no acierta como antes".
    if ($VozWindowsOn -and ($sw.ElapsedMilliseconds - $script:vozWinCheck) -ge 30000) {
        $script:vozWinCheck = $sw.ElapsedMilliseconds
        if ($script:vozWinProc -and $script:vozWinProc.HasExited) {
            if ($script:vozWinIntentos -lt 2) {
                $script:vozWinIntentos++
                Log "WARN: el oido de Windows murio; relanzando (intento $($script:vozWinIntentos)/2)"
                try { $script:vozWinProc.Dispose() } catch {}
                $script:vozWinProc = $null
                try {
                    $wv = Join-Path $LogDir "voz_windows.py"
                    $script:vozWinProc = Start-Process -FilePath $PyWorker `
                        -ArgumentList @('-u', $wv, $MarcaDictar, $RutaDictadoWin, $EventLog, 'es-ES') `
                        -WorkingDirectory $LogDir -WindowStyle Hidden -PassThru
                    $null = $script:vozWinProc.Handle
                    try { $script:vozWinProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal } catch {}
                } catch { Log ("no se pudo relanzar: " + $_.Exception.Message) }
            } elseif ($script:vozWinIntentos -eq 2) {
                $script:vozWinIntentos++   # avisar una sola vez, y sin voz: no es grave
                Log "ERROR: el oido de Windows no se sostiene; se sigue con Whisper"
            }
        }
    }

    # --- LO QUE PASA SIN QUE DIGAS NADA (fase 2) ---
    try { Watch-Entorno $botones } catch { Log ("entorno: " + $_.Exception.Message) }

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
                try { $script:wakeProc.Dispose() } catch {}
                $script:wakeProc = $null   # el boton dicta con Windows, no espera a un worker muerto
                Show-Popup "La palabra de activacion fallo. Sigue funcionando el boton." 'error'
                Say "La escucha por voz fallo. Puedes seguir usando el boton."
            }
        } elseif ($script:wakeProc -and ($sw.ElapsedMilliseconds - $script:wakeDesde) -gt 300000) {
            # 5 min vivo, no 30 s: un worker que muere cada 40 s reiniciaba el
            # contador sin parar y nunca se daba por perdido (auditoria del 13/09)
            $script:wakeIntentos = 0   # lleva vivo un rato: se rearman los reintentos
        }
    }

    # --- INTERRUMPIR A NOVA (M5): "espera", "para", "calla"... dicho mientras habla ---
    $rutaCorte = Join-Path $TmpDir 'corte.flag'
    if (Test-Path -LiteralPath $rutaCorte) {
        $palabraCorte = ''
        try { $palabraCorte = ([System.IO.File]::ReadAllText($rutaCorte)).Trim() } catch {}
        Remove-Item -LiteralPath $rutaCorte -Force -ErrorAction SilentlyContinue
        if ($sw.ElapsedMilliseconds -lt $script:pausaHasta -and -not $script:armed) {
            Log "INTERRUMPIDA: '$palabraCorte' mientras hablaba"
            try { if ($script:reproductor) { $script:reproductor.Stop() } } catch {}
            try { if ($script:vozPlayer) { $script:vozPlayer.Stop() } } catch {}
            try { Stop-Charla } catch {}
            $script:vozFinReal = 0
            Send-UIEvento 'gesto:paciencia'
            # y te escucha, sin decir "nova"
            $script:seguimientoPendiente = $true
            $script:seguimientoFactor = 1.0
            $script:ventanaCharla = (($sw.ElapsedMilliseconds - $script:charlaUltima) -lt 60000)
            $script:pausaHasta = $sw.ElapsedMilliseconds + 150
        }
    }

    # --- CONVERSACION: lo que contesta el worker, frase a frase (ver CONVERSACION DE VERDAD) ---
    # tambien solo con la voz preparada viva: Receive-Charla es quien la cierra
    if ($script:charlaProc -or $script:prepVozProc) { try { Receive-Charla } catch { Log ("charla: " + $_.Exception.Message) } }
    # EN FRIO el modelo tarda en cargar (~12-16 s medido): pasados 5 s sin nada,
    # una palabra corta para que no parezca colgada. Una vez por respuesta.
    if ($script:charlaEsperando -and -not $script:charlaRelleno -and $script:charlaFrases.Count -eq 0 -and -not $script:armed -and
        ($sw.ElapsedMilliseconds - $script:charlaDesde) -gt 5000 -and $sw.ElapsedMilliseconds -ge $script:pausaHasta) {
        $script:charlaRelleno = $true
        Log "charla: tarda mas de 5 s, digo algo mientras"
        # variadas y NUNCA la misma dos veces seguidas (14/09): con tres, se repetian
        $rellenosC = @('Deja que lo piense.', 'A ver...', 'Un segundito.', 'Mmm, buena pregunta.', 'Dame un momento.',
                       'Espera, que lo pienso.', 'Vale, a ver.', 'Uy, eso tiene miga.')
        $rellenoC = Get-Random -InputObject @($rellenosC | Where-Object { $_ -ne $script:ultimoRelleno })
        $script:ultimoRelleno = $rellenoC
        Say $rellenoC
    }
    # LA ESPERA SE VE (D3): si la charla tarda mas de 2 s, la linea de la capsula se
    # va llenando (en frio son 12-16 s); al llegar la primera frase, se vacia
    $esperaC = ($script:charlaEsperando -and $script:charlaFrases.Count -eq 0 -and ($sw.ElapsedMilliseconds - $script:charlaDesde) -gt 2000)
    if ($esperaC) {
        # la escala, la de lo que va a tardar DE VERDAD (14/09): con el modelo caliente
        # o recien precargado contesta en 2-3 s, y la linea de 16 s apenas se movia
        $escalaE = if ((Test-CharlaCaliente) -or ($sw.ElapsedMilliseconds - $script:precargaEn) -lt 110000) { 5000.0 } else { 16000.0 }
        $frE = [Math]::Min(0.9, ($sw.ElapsedMilliseconds - $script:charlaDesde) / $escalaE)
        if (-not $script:progresoCharla -or ($frE - $script:uiProgreso) -ge 0.04) { $script:progresoCharla = $true; $script:uiProgreso = $frE; Refresh-UI }
    } elseif ($script:progresoCharla) {
        $script:progresoCharla = $false
        $script:uiProgreso = 0
        Refresh-UI
    }
    if ($script:charlaFrases.Count -gt 0 -and -not $script:armed) {
        # la siguiente frase entra cuando acaba la que suena (su duracion real)
        $finFrase = if ($script:vozFinReal -gt 0) { $script:vozFinReal } else { $script:pausaHasta }
        if ($sw.ElapsedMilliseconds -ge ($finFrase - 150)) {
            $frC = $script:charlaFrases.Dequeue()
            $fraseC = [string]$frC.t
            $script:uiOrigen = [string]$frC.o
            Log "charla dice: $fraseC"
            $script:ultimaRespuesta = $fraseC
            Say $fraseC (Get-EmocionFrase $fraseC)
        }
    }

    # reanuda la escucha cuando vence la pausa (fin estimado de la voz)
    if ($script:pausaHasta -gt 0 -and $sw.ElapsedMilliseconds -ge $script:pausaHasta -and -not $script:armed -and $script:charlaFrases.Count -eq 0) {
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
        } elseif ($script:resumenPendiente -and -not $script:busy -and -not $script:pendiente) {
            # HAS VUELTO (ver RESUMEN AL VOLVER): una linea, sin voz.
            # Desde el 16/09 tambien lo prepara Watch-Entorno, asi que sale aunque no
            # le hayas dicho nada; antes habia que hablarle para enterarte.
            $txtRes = $script:resumenPendiente
            $script:resumenPendiente = ''
            Send-UIEvento 'gesto:saludo'
            Set-UI 'hablando' $txtRes 4500
        } elseif ($script:invitadoPropuesta -and -not $script:busy -and -not $script:pendiente -and -not $script:invitado) {
            # VOZ AJENA VARIAS VECES (M7): se pregunta, nunca se pone solo
            $script:invitadoPropuesta = $false
            $script:invitadoPropuestoEn = $sw.ElapsedMilliseconds
            $script:vozAjenaVeces = @()
            $script:pendiente = @{ texto = ''; vence = 0; tipo = 'invitadoAuto' }
            $pregI = 'No reconozco esta voz. ¿Pongo el modo invitado?'
            Log "MODO INVITADO: lo propongo (voz ajena varias veces)"
            Say $pregI
            Set-UI 'escuchando' $pregI
            Start-Confirmacion
        } elseif ($script:nivelPendiente -gt 0 -and -not $script:busy -and -not $script:pendiente) {
            # SUBIO DE NIVEL (ver NOVA EVOLUCIONA): un destello y la palabra, sin voz
            $nvP = $script:nivelPendiente
            $script:nivelPendiente = 0
            Send-UIEvento 'gesto:nivel'
            Set-UI 'hablando' "Nivel $nvP" 2500
        } elseif (-not $script:juegoActivo -and -not $script:busy -and -not $script:pendiente -and
                  ($propH =$(try { Find-Propuesta } catch { $null }))) {
            # UNA COSTUMBRE QUE AUTOMATIZAR (ver HABITOS): justo despues de hacer
            # una orden, que es cuando estas pendiente; nunca jugando. Se apunta
            # el dia al preguntar, conteste lo que conteste: una al dia.
            $hbP = Get-Habitos
            $hbP.ultimaPropuesta = (Get-Date).ToString('yyyy-MM-dd')
            Save-Habitos
            $script:pendiente = @{ texto = ''; vence = 0; tipo = 'propuesta'; propuesta = $propH }
            Log "PROPUESTA: $($propH.clave)"
            Say $propH.pregunta
            Set-UI 'escuchando' $propH.pregunta
            Start-Confirmacion
        } elseif ($script:seguimientoPendiente -and $SeguimientoMs -gt 0 -and $script:seguimientoFactor -gt 0 -and $DictadoWorker -and $script:wakeProc -and
            -not $script:wakeProc.HasExited -and -not $script:busy -and -not $script:pendiente -and $script:reintentoVence -le 0) {
            Start-Dictado 'seguimiento'
        }
        $script:seguimientoPendiente = $false
    }

    # --- CONFIRMACION PENDIENTE (si / no / plazo) ---
    if ($script:pendiente) {
        # QUE SE VEA QUE ESPERA UN SI O UN NO. Mientras la pregunta suena manda
        # 'hablando'; en cuanto termina, la capsula pasa a 'confirmando' y dibuja
        # el plazo vaciandose. Sin esto se queda igual que en reposo y nadie sabe
        # que le estan preguntando algo, que es justo como el silencio acababa
        # cancelando ordenes buenas.
        if ($script:uiEstado -ne 'confirmando' -and -not $script:busy -and $script:uiHasta -le $sw.ElapsedMilliseconds) {
            $queda = [Math]::Max(0, $script:pendiente.vence - $sw.ElapsedMilliseconds)
            $script:confirmaFin = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() + $queda
            $script:confirmaTotal = [Math]::Max(1, $queda)
            Set-UI 'confirmando' $script:uiTexto
        }
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
        # reintentoVence: el oido fino esta repasando la orden anterior. Un
        # "nova" ahora abria otro dictado y el repaso ejecutaba despues la
        # orden VIEJA encima de la nueva.
        if ($script:armed -or $script:busy -or $script:pendiente -or $script:reintentoVence -gt 0) {
            # ya estabamos escuchando o procesando: se ignora sin ruido
        } elseif (($sw.ElapsedMilliseconds - $script:finVoz) -lt 1500) {
            # acabamos de hablar: evita despertarse con su propia voz
            Log "despertar ignorado (acabamos de hablar)"
        } else {
            Start-Dictado "nombre '$EscuchaNombre'"
        }
    }

    # --- una RESPUESTA escrita ("si"/"no") a una pregunta pendiente ---
    # Para probar sin voz lo que pasa despues de un "¿lo hago?".
    if ($script:pendiente -and -not $script:busy -and (Test-Path -LiteralPath $RutaOrdenEscrita)) {
        $escritaC = ''
        try { $escritaC = [System.IO.File]::ReadAllText($RutaOrdenEscrita, [System.Text.Encoding]::UTF8).Trim() } catch {}
        if ($escritaC -match '^(?i)(?:s[ií]|no)$') {
            Remove-Item -LiteralPath $RutaOrdenEscrita -Force -ErrorAction SilentlyContinue
            Log "RESPUESTA ESCRITA: $escritaC"
            Complete-Confirmacion $(if ($escritaC -match '^(?i)no$') { 'no' } else { 'si' })
        }
    }

    # --- una orden ESCRITA (tools\decir.ps1) ---
    # Pasa por Process-Texto igual que una dicha, pero sin audio: ni oido fino
    # (no hay nada que repasar) ni juicio de la voz (no hay tono que medir).
    if (-not $script:armed -and -not $script:busy -and -not $script:pendiente -and $script:reintentoVence -le 0 -and
        (Test-Path -LiteralPath $RutaOrdenEscrita)) {
        $escrita = ''
        try { $escrita = [System.IO.File]::ReadAllText($RutaOrdenEscrita, [System.Text.Encoding]::UTF8).Trim() } catch {}
        Remove-Item -LiteralPath $RutaOrdenEscrita -Force -ErrorAction SilentlyContinue
        if ($escrita) {
            Log "ORDEN ESCRITA: $escrita"
            $script:ordenPorWorker = $false
            $script:yaReintentado = $true
            $script:ultimaF0 = 0
            try { Process-Texto $escrita } catch { Log ("orden escrita: " + $_.Exception.Message) }
        }
    }

    # --- DICTADO POR VOSK: recoger lo transcrito y mostrarlo en vivo ---
    if ($script:armed -and $script:ordenPorWorker) {
        # transcripcion en vivo: ver lo que oye mientras hablas
        if (Test-Path -LiteralPath $RutaParcial) {
            try {
                $par = [System.IO.File]::ReadAllText($RutaParcial, [System.Text.Encoding]::UTF8)
                $vista = ($par -replace '\s+', ' ').Trim()
                if ($vista.Length -gt 44) {
                    # por PALABRAS (14/09): cortar a 41 letras dejaba "...lume al setenta"
                    $colaV = $vista.Substring($vista.Length - 41)
                    $espV = $colaV.IndexOf(' ')
                    if ($espV -ge 0 -and $espV -lt 20) { $colaV = $colaV.Substring($espV + 1) }
                    $vista = "..." + $colaV
                }
                $nuevo = if ($vista) { "● $vista" } else { "● VOZ..." }
                if ($lbl.Text -ne $nuevo) {
                    $lbl.Text = $nuevo; Set-UI 'escuchando' $vista; Test-LoTengo $vista
                    # CERRAR ANTES LO QUE YA SE ENTIENDE (14/09): se le dice a la escucha
                    # QUE texto se entendio; si sigues hablando, ya no coincide y espera
                    # los 1,4 s de siempre. Solo con la frase entera delante, no con "...".
                    if ($script:loTengo -and -not $script:loTengoEscrito -and -not $vista.StartsWith('...')) {
                        $script:loTengoEscrito = $true
                        try { [System.IO.File]::WriteAllText($RutaLoTengo, (($par -replace '\s+', ' ').Trim()), (New-Object System.Text.UTF8Encoding($false))) } catch {}
                    }
                    # PRECARGA POR LO QUE VAS DICIENDO (14/09): en frio el modelo tarda
                    # 7,8 s en cargar y la primera frase llego a 19 s. Si lo que llevas
                    # dicho ya suena a charla, empieza a cargar mientras terminas. No
                    # jugando (la RAM es del juego) ni si ya es una orden conocida.
                    if ($ConversacionOn -and -not $script:juegoActivo -and ($sw.ElapsedMilliseconds - $script:precargaEn) -gt 90000 -and
                        @($vista -split '\s+').Count -ge 3 -and -not $vista.StartsWith('...') -and
                        (Test-PareceCharla $vista) -and -not (Test-FastCommand $vista)) {
                        $script:precargaEn = $sw.ElapsedMilliseconds
                        try { if ((Test-RamParaCharla) -and (Send-CharlaPedido @{ op = 'calentar' })) { Log "charla: precargo el modelo, '$vista' suena a charla" } } catch {}
                    }
                }
            } catch {}
        }
        # el worker ya termino: entrega el texto
        if (Test-Path -LiteralPath $RutaDictado) {
            $dic = ''
            try { $dic = [System.IO.File]::ReadAllText($RutaDictado, [System.Text.Encoding]::UTF8) } catch {}
            # UNA SEGUNDA MIRADA (15/09): "abre youtube y reproduce Pitbull" llego en el mismo
            # segundo en que se leyo el archivo vacio, y la ventana se cerro como silencio
            if (-not $dic.Trim()) {
                Start-Sleep -Milliseconds 150
                try { $dic = [System.IO.File]::ReadAllText($RutaDictado, [System.Text.Encoding]::UTF8) } catch {}
                if ($dic.Trim()) { Log "DICTADO: el texto llego justo al leerlo; en la segunda mirada si esta" }
            }
            Remove-Item -LiteralPath $RutaDictado -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $RutaLoTengo -Force -ErrorAction SilentlyContinue
            # ¿dijo algo el motor de Windows? Entonces se prefiere lo suyo. Si no
            # llego nada -o no oye este microfono- se sigue con lo de Whisper,
            # que es justo lo que hace que activarlo no pueda empeorar nada.
            if ($VozWindowsOn -and (Test-Path -LiteralPath $RutaDictadoWin)) {
                $porWin = ''
                try { $porWin = [System.IO.File]::ReadAllText($RutaDictadoWin, [System.Text.Encoding]::UTF8) } catch {}
                Remove-Item -LiteralPath $RutaDictadoWin -Force -ErrorAction SilentlyContinue
                if ($porWin.Trim()) {
                    if ($porWin.Trim() -ne $dic.Trim()) { Log "DICTADO de Windows: '$($dic.Trim())' -> '$($porWin.Trim())'" }
                    $dic = $porWin
                    Add-Estadistica 'vozwin' $porWin.Trim()
                } elseif ($dic.Trim()) {
                    # oyo Whisper pero Windows no: si esto pasa siempre, ese motor
                    # no oye este microfono y el ajuste se puede apagar
                    Add-Estadistica 'vozwin-mudo'
                }
            }
            Remove-Item -LiteralPath $MarcaDictar -Force -ErrorAction SilentlyContinue
            $script:armed = $false
            $capture.Hide()
            # la voz que dicto (por tono): la capsula tine la escucha por persona,
            # y el TONO en Hz decide si esto lo has dicho tu o sale de un video
            try {
                $rv = Join-Path $TmpDir 'dictado-voz.txt'
                if (Test-Path -LiteralPath $rv) {
                    $campos = @(([System.IO.File]::ReadAllText($rv).Trim() -split '\s+'))
                    $script:uiVoz = [int]$campos[0]
                    if ($campos.Count -gt 1) { $script:ultimaF0 = [double]$campos[1] }
                    Remove-Item -LiteralPath $rv -Force -ErrorAction SilentlyContinue
                }
                # y lo seguro que estaba Whisper (ver RECETAS QUE CONFIRMAN EL DATO DUDOSO)
                $rc = Join-Path $TmpDir 'dictado-confianza.txt'
                if (Test-Path -LiteralPath $rc) {
                    # "-0.52" o "-0.52 eco" (lo oido es la frase de ejemplo de Whisper)
                    $partesC = @(([System.IO.File]::ReadAllText($rc)).Trim() -split '\s+')
                    $script:dictadoConfianza = [double]::Parse($partesC[0], [System.Globalization.CultureInfo]::InvariantCulture)
                    $script:dictadoEco = ($partesC.Count -gt 1 -and $partesC[1] -eq 'eco')
                    $script:dictadoConfianzaEn = $sw.ElapsedMilliseconds
                    Remove-Item -LiteralPath $rc -Force -ErrorAction SilentlyContinue
                }
                # ¿lo oyo Parakeet? (ver PARAKEET PRIMERO)
                $script:dictadoPorParakeet = $false
                $rm = Join-Path $TmpDir 'dictado-motor.txt'
                if (Test-Path -LiteralPath $rm) {
                    $script:dictadoPorParakeet = ([System.IO.File]::ReadAllText($rm)) -match 'parakeet'
                    Remove-Item -LiteralPath $rm -Force -ErrorAction SilentlyContinue
                }
            } catch {}
            if ($script:enSeguimiento -and -not $dic.Trim()) {
                $script:enSeguimiento = $false
                if (($sw.ElapsedMilliseconds - $script:charlaUltima) -lt 60000 -and $script:charlaSilencios -lt 1) {
                    # en una CONVERSACION se espera una ventana mas antes de dejarlo
                    $script:charlaSilencios++
                    Log "seguimiento: silencio en una conversacion, espero otro poco"
                    $script:seguimientoPendiente = $true
                    $script:ventanaCharla = $true
                    $script:pausaHasta = $sw.ElapsedMilliseconds + 100
                } else {
                    # ventana de seguimiento sin voz: se cierra sin decir nada
                    Log "seguimiento: silencio, se cierra"
                    Set-UI 'reposo'
                }
            } else {
                if ($script:enSeguimiento) { try { Add-RitmoSeguimiento } catch {} }   # ver EL RITMO DE BRAYA
                # PARAKEET PRIMERO: si lo que oyo no es una orden que se entienda, Whisper
                # repasa el mismo audio y eso sigue el camino de siempre
                if ($script:dictadoPorParakeet -and $dic.Trim() -and -not $script:dictandoLargo -and
                    -not (Test-FastCommand ($dic.Trim())) -and (Request-WhisperTras ($dic.Trim()))) {
                    # lo recoge OIDO FINO: recoger el repaso
                } else {
                    if ($script:dictadoPorParakeet) { Add-Estadistica 'parakeet' ($dic.Trim()) }
                    Process-Texto ($dic.Trim())
                }
            }
        }
        # "me perdi": 25 s dictando sin que nada encaje todavia
        elseif (-not $script:perdida -and -not $script:loTengo -and ($sw.ElapsedMilliseconds - $script:dictaInicio) -ge 25000) {
            $script:perdida = $true
            Send-UIEvento 'gesto:perdida'
        # 50 s: el worker corta el dictado a los 30 y Whisper ha llegado a tardar
        # 13,6 s mas; con 35 se cancelaba y el texto llegaba despues sin dueno
        } elseif (($sw.ElapsedMilliseconds - $script:dictaInicio) -ge 50000) {
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
    if ($script:armed -and -not $script:ordenPorWorker -and $AutoSubmitMs -gt 0) {
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
        } elseif ($actual.Trim().Length -eq 0 -and ($sw.ElapsedMilliseconds - $script:dictaInicio) -ge 10000) {
            # 10 s sin una sola palabra: Win+H se ha rendido solo (o no oye).
            # Sin esto se quedaba armado para siempre, con la escucha propia
            # en pausa y el panel de Windows a la vista.
            Log "Win+H: 10 s sin texto, se cierra"
            try { Finish-Dictation "sin voz" }
            catch { Log "cierre sin voz: $($_.Exception.Message)"; $script:armed = $false }
        }
    }

    # --- una receta con script corriendo aparte (ver RECETA SIN BLOQUEAR) ---
    if ($script:recetaEnCurso) {
        try { Watch-Receta } catch { Log ("receta: " + $_.Exception.Message); $script:recetaEnCurso = $null }
    }

    # --- atencion al trabajo en curso, sin bloquear el sondeo del boton ---
    if ($script:busy -and $script:proc) {
        Watch-OpencodeProgress
        if ($script:proc.HasExited) {
            $script:uiProgreso = 0
            Report-Reply (Complete-OpencodeJob)
        } elseif (($sw.ElapsedMilliseconds - $script:jobStart) -ge (Get-PlazoJob)) {
            Log "RUNNER timeout tras $([Math]::Round((Get-PlazoJob)/1000)) s ($($script:jobModo))"
            $script:uiProgreso = 0
            Stop-OpencodeJob
            Add-Estadistica 'error' 'timeout de opencode'
            Show-Popup "El modelo tardo demasiado y lo he dejado." 'error'
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
        # lo que pidio PARAKEET PRIMERO: Whisper sobre el mismo audio, que entra como si
        # fuera el dictado (con su seguridad y su marca de eco, y con el repaso disponible)
        if ($null -ne $fino -and $script:reintentoBase) {
            $script:reintentoVence = 0
            $script:reintentoBase = $false
            $origP = $script:reintentoTexto
            $script:reintentoTexto = ''
            $script:dictadoConfianzaEn = -999999
            $script:dictadoEco = $false
            try {
                $rcP = Join-Path $TmpDir 'dictado-confianza.txt'
                if (Test-Path -LiteralPath $rcP) {
                    $partesP = @(([System.IO.File]::ReadAllText($rcP)).Trim() -split '\s+')
                    $script:dictadoConfianza = [double]::Parse($partesP[0], [System.Globalization.CultureInfo]::InvariantCulture)
                    $script:dictadoEco = ($partesP.Count -gt 1 -and $partesP[1] -eq 'eco')
                    $script:dictadoConfianzaEn = $sw.ElapsedMilliseconds
                    Remove-Item -LiteralPath $rcP -Force -ErrorAction SilentlyContinue
                }
            } catch {}
            $limpioW = $fino.Trim()
            $script:yaReintentado = $false
            $sigueCon = if ($limpioW) { $limpioW } else { $origP }
            $script:siguioParakeet = $false
            # LA NUBE, SI YA CONTESTO (ver SEGUNDA OPINION EN LA NUBE). Solo cuando ni
            # Parakeet ni Whisper sacan una orden: si alguno la saca, se hace y punto,
            # que es mas rapido que cualquier cosa que venga de fuera.
            if ($script:nubeOut) {
                $nubeTxt = Receive-NubeOir
                $localOk = (Test-FastCommand $limpioW) -or (Test-FastCommand $origP)
                if ($nubeTxt -and -not $localOk) {
                    $esOrdenN = $false
                    try { $esOrdenN = [bool](Test-FastCommand $nubeTxt) } catch { $esOrdenN = $false }
                    if (Test-NubeSirve $nubeTxt $origP $esOrdenN) {
                        Log "NUBE: '$origP' / '$limpioW' -> '$nubeTxt' (lo saca la nube)"
                        Add-Estadistica 'nube-sirvio' "$origP -> $nubeTxt"
                        $script:reintentoVence = 0
                        $script:yaReintentado = $true
                        Process-Texto $nubeTxt
                        $fino = $null
                        continue
                    }
                    Log "NUBE: '$nubeTxt' tampoco es una orden que sepa hacer; sigo con el oido local"
                    Add-Estadistica 'nube-nada' "$origP -> $nubeTxt"
                }
            }
            # ver PARAKEET PARA LO QUE NO ES UNA ORDEN. El repaso con small se mantiene (oye
            # el AUDIO, no este texto): en las 202 grabaciones rescata 2 ordenes que Parakeet
            # oyo mal ("si agradezco y abre spotify" por "cierra discord y abre spotify").
            if ($limpioW -and -not (Test-FastCommand $limpioW) -and (Test-EspanolLargo $origP)) {
                $sigueCon = $origP
                $script:siguioParakeet = $true
                Log "PARAKEET -> WHISPER: '$origP' -> '$limpioW'; Whisper no saca una orden: sigo con lo de Parakeet"
            } else {
                Log "PARAKEET -> WHISPER: '$origP' -> '$limpioW'"
            }
            # SI LOS DOS OYEN LO MISMO, NO SE REPASA (15/09). "Revisa mi correo", "puedes
            # reproducir esta cancion", "instala en Steam It Takes Two": Parakeet y Whisper
            # oyeron lo mismo y aun asi pasaban por small y turbo, 30-47 s para oir otra vez lo
            # mismo. Medido: con un parecido de 0,9 o mas, en su uso real el repaso saco una
            # orden en 0 de 24 frases; en las 202 grabaciones en 1 ("abre otras" por "abre
            # outlast", de 2 palabras: por eso hacen falta 3 o mas).
            if ($limpioW -and $origP -and -not (Test-FastCommand $limpioW)) {
                $plP = ConvertTo-Plain $origP
                $plW = ConvertTo-Plain $limpioW
                $largoPW = [Math]::Max($plP.Length, $plW.Length)
                if ($largoPW -gt 0 -and @($plP -split '\s+' | Where-Object { $_ }).Count -ge 3 -and
                    (1.0 - (Get-Distancia $plP $plW) / $largoPW) -ge 0.9) {
                    $script:yaReintentado = $true
                    Log "PARAKEET y WHISPER oyen lo mismo: sin repaso"
                }
            }
            Process-Texto $sigueCon
            $fino = $null
        }
        if ($null -ne $fino) {
            $script:reintentoVence = 0
            $orig = $script:reintentoTexto
            $script:reintentoTexto = ''
            $reconocida = $script:reintentoReconocida
            $script:reintentoReconocida = $false
            $ecoR = $script:reintentoEco
            $script:reintentoEco = $false
            $esUltimo = $script:reintentoUltimo
            $script:reintentoUltimo = $false
            $alFallar = $script:reintentoAlFallar
            $script:reintentoAlFallar = 'procesar'
            $limpio = $fino.Trim()
            # si lo que oyo quien repaso es la frase de ejemplo (la escucha lo apunta con "eco")
            $ecoFino = $false
            try {
                $rcF = Join-Path $TmpDir 'dictado-confianza.txt'
                if (Test-Path -LiteralPath $rcF) {
                    $ecoFino = ([System.IO.File]::ReadAllText($rcF)) -match '\beco\b'
                    Remove-Item -LiteralPath $rcF -Force -ErrorAction SilentlyContinue
                }
            } catch {}
            # dos modelos que oyen EXACTAMENTE lo mismo se confirman, aunque sea la frase de ejemplo
            $mismoQueAntes = [bool]($limpio -and (ConvertTo-Plain $limpio) -eq (ConvertTo-Plain $orig))
            if ($esUltimo) {
                # ULTIMO RECURSO (turbo): vale si trae una orden entendible, con la misma guarda del eco
                if ($limpio -and (Test-FastCommand $limpio) -and (-not $ecoFino -or $mismoQueAntes)) {
                    Log "ULTIMO RECURSO: '$orig' -> '$limpio'"
                    Add-Estadistica 'turbo-sirvio' "$orig -> $limpio"
                    Process-Texto $limpio
                } elseif ($reconocida -or $alFallar -eq 'noentendi') {
                    Log "ULTIMO RECURSO: turbo tampoco lo saca ('$orig' -> '$limpio'); no hago nada"
                    Add-Estadistica 'turbo-nada' $orig
                    $script:seguimientoPendiente = $false
                    Send-UIEvento 'gesto:confuso'
                    Show-Popup "No te entendi. Repitelo." 'error'
                    Say "No te entendi"
                    Open-EscuchaTrasNoEntendi
                } else {
                    # lo que oyo turbo, si se parece, es el mejor oido que hay: con lo primero, la
                    # charla contesto a "la distancia del solo de la tierra" cuando turbo habia oido
                    # "cual es la distancia del sol a la tierra" (15/09)
                    $sigue = if ($limpio -and (Test-MismoAudio $orig $limpio)) { $limpio } else { $orig }
                    Log "ULTIMO RECURSO: turbo tampoco saca una orden de '$orig' ('$limpio'); sigue su camino con '$sigue'"
                    Add-Estadistica 'turbo-nada' $orig
                    Add-OidoDudoso $sigue
                    $script:yaReintentado = $true   # ya se repaso: que no vuelva a pedir el oido fino
                    Process-Texto $sigue
                }
            } elseif ($reconocida -and $ecoR) {
                # lo primero era un eco de la frase de ejemplo: solo vale lo que confirme el repaso
                # ... y un eco no confirma a otro eco (tanda dirigida, 14/09): "pon modo noche"
                # desde lejos, base lo oyo bien, small oyo "Que hora es" y se hizo la hora. Si el
                # repaso no lo confirma, se intenta con turbo antes de rendirse
                if ($limpio -and (-not $ecoFino -or $mismoQueAntes) -and (Test-MismoAudio $orig $limpio) -and (Test-FastCommand $limpio)) {
                    Log "OIDO FINO: el eco '$orig' lo confirma el repaso como '$limpio'"
                    Add-Estadistica 'fino-sirvio' "$orig -> $limpio"
                    Process-Texto $limpio
                } elseif (-not (Request-UltimoRecurso $orig $true $true 'noentendi')) {
                    Log "OIDO FINO: '$orig' era la frase de ejemplo y el repaso ('$limpio') no lo confirma; no hago nada"
                    Add-Estadistica 'fino-eco' $orig
                    $script:seguimientoPendiente = $false
                    Send-UIEvento 'gesto:confuso'
                    Show-Popup "No te entendi. Repitelo." 'error'
                    Say "No te entendi"
                    Open-EscuchaTrasNoEntendi
                }
            } elseif ($reconocida -and ((-not $limpio) -or (ConvertTo-Plain $limpio) -eq (ConvertTo-Plain $orig) -or
                -not (Test-MismoAudio $orig $limpio) -or -not (Test-FastCommand $limpio))) {
                # se repaso una orden que YA se entendia (ver REPASO DE LO DUDOSO): si
                # el repaso no trae otra orden entendible, vale lo que se oyo primero
                Log "OIDO FINO: el repaso ('$limpio') no mejora '$orig'; la hago tal cual"
                Add-Estadistica 'fino-igual' $orig
                Process-Texto $orig
            } elseif ($limpio -and (ConvertTo-Plain $limpio) -ne (ConvertTo-Plain $orig) -and (Test-MismoAudio $orig $limpio) -and
                      ($mismoQueAntes -or -not ($ecoFino -or (Test-EsFraseEjemplo $limpio)))) {
                # la guarda del eco va TAMBIEN aqui (16/09, ver UNA SOLA FRASE DEL EJEMPLO):
                # antes solo la miraba la rama de abajo, y por esta entraban las cuatro
                # equivocadas graves que se midieron con las grabaciones leidas
                if ((Test-FastCommand $limpio) -or -not (Request-UltimoRecurso $orig $false $false 'procesar')) {
                    if ($script:siguioParakeet -and -not (Test-FastCommand $limpio)) {
                        # SMALL NO PISA A PARAKEET (15/09): "mueve It Takes Two a la carpeta Games"
                        # lo oyo bien Parakeet; small oyo "state 2", se siguio con eso y el agente
                        # busco "state 2" 48 s. Si small tampoco saca una orden, vale Parakeet.
                        Log "OIDO FINO: '$limpio' tampoco es una orden; sigo con lo de Parakeet: '$orig'"
                        Process-Texto $orig
                    } else {
                        Log "OIDO FINO: '$orig' -> '$limpio'"
                        Add-Estadistica 'fino-sirvio' "$orig -> $limpio"
                        Process-Texto $limpio
                    }
                }
            } elseif ($limpio -and -not (Test-MismoAudio $orig $limpio) -and $script:siguioParakeet -and -not (Test-FastCommand $limpio)) {
                # lo de Parakeet era una frase en espanol y el repaso no trae una orden: se sigue
                # con Parakeet en vez de "no te entendi" (ver SMALL NO PISA A PARAKEET)
                Log "OIDO FINO: '$limpio' no se parece a lo de Parakeet ni es una orden; sigo con Parakeet: '$orig'"
                Process-Texto $orig
            } elseif ($limpio -and -not (Test-MismoAudio $orig $limpio) -and -not $ecoFino -and
                      -not (Test-EsFraseEjemplo $limpio) -and (Test-FastCommand $limpio)) {
                # EL REPASO ACIERTA AUNQUE NO SE PAREZCA (15/09). Cuando base oye basura, lo de small
                # no comparte ninguna palabra con ello y se tiraba como "invento suyo". Medido con las
                # 202 grabaciones: base sin orden y small con orden que no se parecen, 16 eran la orden
                # correcta ("cierra steam", "abre spotify", "abre elden ring") y 2 equivocadas, y las
                # dos inofensivas. Jugando, braya lo sufrio y la autosordina se callo 10 minutos. Vale
                # si el repaso trae una orden clara y no es la frase de ejemplo de Whisper (el eco).
                Log "OIDO FINO: '$orig' -> '$limpio' (no se parece, pero el repaso trae una orden clara)"
                Add-Estadistica 'fino-sirvio' "$orig -> $limpio"
                Process-Texto $limpio
            } elseif ($limpio -and -not (Test-MismoAudio $orig $limpio)) {
                if (-not (Request-UltimoRecurso $orig $false $false 'noentendi')) {
                    Log "OIDO FINO descartado: '$limpio' no se parece en nada a '$orig'; es invento suyo"
                    Add-Estadistica 'fino-invento' "$orig -> $limpio"
                    Add-Estadistica 'ruido' $orig
                    Add-RuidoRacha
                    $script:seguimientoPendiente = $false
                    Send-UIEvento 'gesto:confuso'
                    Show-Popup "No te entendi. Repitelo." 'error'
                    Say "No te entendi"
                    Open-EscuchaTrasNoEntendi
                }
            } else {
                # el oido fino oyo lo mismo: se intenta con turbo; si no, sigue su camino. Si no oyo
                # NADA (o ya no quedaba audio: "no queda audio de la orden anterior"), turbo
                # tampoco va a oir mas y solo sumaria 15-28 s
                if (-not $limpio -or -not (Request-UltimoRecurso $orig $false $false 'procesar')) {
                    Add-Estadistica 'fino-igual' $orig
                    Process-Texto $orig
                }
            }
        }
    }

    # --- abrir Win+H en cuanto el asistente se calle ---
    # Tiene que ser DESPUES de hablar (si no, se transcribe a si mismo) y con la
    # ventana de destino delante, porque Win+H escribe donde este el cursor.
    if ($script:dictadoWinHPendiente -and $script:pausaHasta -le 0 -and -not $script:busy) {
        $script:dictadoWinHPendiente = $false
        if ($script:dictadoVentana -ne [IntPtr]::Zero) {
            [void][AX]::ForceForeground($script:dictadoVentana)
            Start-Sleep -Milliseconds 250
        }
        # el oido propio se calla mientras: si no, Vosk y Windows se pelean por
        # el microfono y no gana ninguno. El boton sigue vivo, que es la salida.
        Pausar-Escucha $DictadoLargoMs
        Send-WinH
        Log "DICTADO LARGO: Win+H abierto sobre la ventana $($script:dictadoVentana)"
        Set-UI 'escuchando' 'dictando con Windows... manten el boton para terminar'
    }

    # --- el dictado largo se vuelve a abrir solo ---
    # Va SUELTO en el bucle, no colgado de "acabo de hablar": en este modo el
    # asistente no dice nada, asi que aquel bloque no se alcanza nunca y el modo
    # escribia un trozo y se quedaba sordo. Se espera a que no haya pausa de voz
    # en marcha para no competir por el microfono.
    if ($script:dictandoLargo -and -not $script:dictadoWinH -and -not $script:armed -and -not $script:busy -and -not $script:pendiente -and
        $script:pausaHasta -le 0 -and $DictadoWorker -and $script:wakeProc -and -not $script:wakeProc.HasExited) {
        Start-Dictado 'largo'
    }

    # --- la sordina vuelve tras un dictado con el boton (ver Start-Dictado) ---
    if ($script:sordinaRepausar -and -not $script:armed -and -not $script:busy -and -not $script:pendiente -and $script:reintentoVence -le 0) {
        $script:sordinaRepausar = $false
        $restanSordina = $script:sordinaHasta - $sw.ElapsedMilliseconds
        if ($restanSordina -gt 1000) {
            Pausar-Escucha $restanSordina
            Log "SORDINA: vuelve ($([int][Math]::Ceiling($restanSordina / 60000)) min)"
        }
    }

    # --- el dictado largo tiene plazo ---
    # La tercera salida, la que no depende de ti: si pasan los minutos sin
    # escribir nada, se cierra solo y lo dice. Un modo que escribe en la ventana
    # de delante no puede quedarse puesto porque te fuiste a otra cosa.
    if ($script:dictandoLargo -and $script:dictadoLargoHasta -gt 0 -and $sw.ElapsedMilliseconds -ge $script:dictadoLargoHasta) {
        Stop-DictadoLargo 'se acabo el plazo'
    }

    # --- escondida un rato: vuelve sola al vencer (ver ESCONDERSE UN RATO) ---
    if ($script:retiradaHasta -gt 0 -and $sw.ElapsedMilliseconds -ge $script:retiradaHasta) {
        $script:retiradaHasta = 0
        $estabaEscondida = ($script:uiEstado -eq 'retirada')
        $script:uiRetirada = $false
        if ($estabaEscondida) { Set-UI 'reposo'; Send-UIEvento 'gesto:saludo' }
    }

    # --- avisos que esperaban a que terminaras de dictar (ver Send-Aviso) ---
    if (-not $script:armed -and -not $script:pendiente -and $script:avisosAplazados.Count -gt 0) {
        $avA = $script:avisosAplazados[0]
        $script:avisosAplazados.RemoveAt(0)
        Send-Aviso $avA.texto $avA.tipo
    }

    # --- temporizadores vencidos ---
    if ($script:temporizadores.Count -gt 0) {
        for ($i = $script:temporizadores.Count - 1; $i -ge 0; $i--) {
            $t = $script:temporizadores[$i]
            # mientras dictas no suena: hablar encima congelaba el dictado (auditoria 13/09)
            if ($sw.ElapsedMilliseconds -ge $t.vence -and -not $script:armed) {
                $script:temporizadores.RemoveAt($i)
                Log "TEMPORIZADOR: $($t.texto)"
                # el sonido propio si suena: son dos notas de medio segundo, no
                # una frase encima, y es lo que hace que un temporizador sirva
                Play-Sonido 'te-oigo' ([System.Media.SystemSounds]::Exclamation)
                if ($t.tipo -eq 'foco' -and -not $script:pendiente -and -not $script:busy) {
                    # FIN DEL FOCO: se ofrece el descanso (si / no, o A / B)
                    $script:pendiente = @{ texto = ''; vence = 0; tipo = 'descanso' }
                    Say 'Fin del foco. ¿Descanso de cinco minutos?'
                    Set-UI 'escuchando' '¿Descanso de 5 minutos?'
                    Start-Confirmacion
                } else {
                    Send-Aviso $t.texto 'tiempo'
                }
            }
        }
    }

    # --- descargas de Steam: avisar cuando una termina ---
    # Cada dos minutos se releen los manifiestos (es leer texto de disco, no
    # hablar con Steam) y se compara con lo que estaba bajando antes.
    if (($sw.ElapsedMilliseconds - $script:descargaCheck) -ge 120000) {
        $script:descargaCheck = $sw.ElapsedMilliseconds
        try {
            $ahoraBajan = @{}
            # De paso, LO QUE LLEVA la mas avanzada: son los mismos bytes que ya
            # se acaban de leer, y la capsula ya sabe dibujar una fraccion en el
            # anillo. Se elige la mas avanzada porque es la que va a terminar
            # antes, que es lo que se quiere saber mirando de reojo.
            $frac = 0.0
            foreach ($j in @(Get-JuegosSteam)) {
                if ($j.bajando) {
                    $ahoraBajan[[string]$j.id] = $j.nombre
                    if ([double]$j.total -gt 0) {
                        $f = [double]$j.descargado / [double]$j.total
                        if ($f -gt $frac) { $frac = [Math]::Max(0.0, [Math]::Min(1.0, $f)) }
                    }
                }
            }
            # solo se reescribe el estado si el anillo se movio de verdad (1 %)
            if ([Math]::Abs($frac - $script:uiDescarga) -gt 0.01) {
                $script:uiDescarga = $frac
                Refresh-UI
            }
            # La PRIMERA lectura solo toma nota. Sin esta guarda, $null llegaba
            # al foreach, @($null.Keys) daba una lista con un $null dentro y
            # ContainsKey($null) reventaba la vuelta entera: la variable no se
            # llegaba a guardar nunca y el aviso de "ya se descargo" no salto
            # una sola vez, solo una excepcion en el log cada dos minutos.
            if ($null -ne $script:bajandoAntes) {
                foreach ($id in @($script:bajandoAntes.Keys)) {
                    if (-not $ahoraBajan.ContainsKey($id)) {
                        $nom = [string]$script:bajandoAntes[$id]
                        Log "DESCARGA terminada: $nom"
                        Send-Aviso "$nom ya acabo de descargarse." 'descarga'
                    }
                }
            }
            $script:bajandoAntes = $ahoraBajan
        } catch { Log ("descargas: " + $_.Exception.Message) }
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

    # --- portapapeles (cada 4 s; ver HISTORIAL DEL PORTAPAPELES) ---
    if (($sw.ElapsedMilliseconds - $script:portaCheck) -ge 4000) {
        $script:portaCheck = $sw.ElapsedMilliseconds
        try { if ([System.Windows.Forms.Clipboard]::ContainsText()) { Watch-Portapapeles ([System.Windows.Forms.Clipboard]::GetText()) } } catch {}
    }

    # --- que musica suena (cada 5 s; ver LA MUSICA EN LA CAPSULA) ---
    if (($sw.ElapsedMilliseconds - $script:musicaCheck) -ge 5000) {
        $script:musicaCheck = $sw.ElapsedMilliseconds
        try { Watch-Musica (Get-MusicaActual) } catch { Log ("musica: " + $_.Exception.Message) }
    }

    # --- dock y cascos conectados (cada 15 s; ver DOCK Y CASCOS) ---
    if (($sw.ElapsedMilliseconds - $script:dispCheck) -ge 15000) {
        $script:dispCheck = $sw.ElapsedMilliseconds
        try { Watch-Dispositivos } catch { Log ("dispositivos: " + $_.Exception.Message) }
    }

    # --- notificaciones nuevas (cada 30 s; ver NOTIFICACIONES MIENTRAS JUEGAS) ---
    if (($sw.ElapsedMilliseconds - $script:notifCheck) -ge 30000) {
        $script:notifCheck = $sw.ElapsedMilliseconds
        if (-not $script:invitado) { try { [void](Watch-Notificaciones @(Get-Notificaciones)) } catch { Log ("notificaciones: " + $_.Exception.Message) } }
    }

    # --- reglas sobre apps: se abrio o se cerro una (cada 3 s; sin reglas de
    #     apps no mira nada) ---
    if (($sw.ElapsedMilliseconds - $script:appsCheck) -ge 3000) {
        $script:appsCheck = $sw.ElapsedMilliseconds
        try { Watch-AppsReglas } catch { Log ("reglas de apps: " + $_.Exception.Message) }
    }

    # --- que juego esta en primer plano (cada 10 s, es una consulta cara) ---
    if (($sw.ElapsedMilliseconds - $script:juegoCheck) -ge 10000) {
        $script:juegoCheck = $sw.ElapsedMilliseconds
        try {
            $script:juegoExeCandidato = ''
            $j = Get-JuegoEnPrimerPlano
            # los segundos con el juego delante desde la ultima mirada (ver TIEMPO DE JUEGO)
            if ($script:juegoActivo -and $script:tiempoJuegoVisto -gt 0) {
                try { Add-TiempoJuego $script:juegoActivo ([int](($sw.ElapsedMilliseconds - $script:tiempoJuegoVisto) / 1000)) } catch {}
            }
            $script:tiempoJuegoVisto = $sw.ElapsedMilliseconds
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
                # IDEA 10: pasa por el freno de mano como todo lo demas. Es 'alto'
                # porque suena JUGANDO, que es justo cuando hace falta oirlo.
                [void](Test-PuedoAvisar 'juego-rato' 'alto' 120)
                $horas = [Math]::Round($JuegoAvisoMin / 60.0, 1)
                $cuanto = if ($JuegoAvisoMin -ge 60 -and ($JuegoAvisoMin % 60) -eq 0) { "$([int]$horas) horas" } else { "$JuegoAvisoMin minutos" }
                if ($cuanto -eq '1 horas') { $cuanto = 'una hora' }
                Log "JUEGO: aviso de tiempo ($cuanto con $j)"
                Send-Aviso "Oye, ya llevas $cuanto con $j." 'tiempo'
            }
        } catch {}
    }

    # --- reglas por hora y periodicas; fechas; nota semanal (cada minuto) ---
    $minutoAhora = Get-Date -Format 'HH:mm'
    if ($minutoAhora -ne $script:minutoVisto) {
        $script:minutoVisto = $minutoAhora
        try { Invoke-Reglas 'hora' $minutoAhora; Invoke-Reglas 'cada' } catch {}
        try { Test-Recordatorios } catch {}
        try { Update-BrilloAuto } catch {}   # ver BRILLO AUTOMATICO
        try { Test-FinInvitado } catch {}    # ver MODO INVITADO
        try { Test-LimiteJuego } catch {}    # ver LIMITE DE JUEGO PROPIO
        # jugando, el modelo de charla sale de la RAM (si no se esta hablando con el)
        try {
            if ($script:juegoActivo -and $script:charlaProc -and -not $script:charlaDescargada -and -not $script:charlaEsperando -and
                ($sw.ElapsedMilliseconds - $script:charlaUltima) -gt 30000) {
                if (Send-CharlaPedido @{ op = 'descargar' } $false) { $script:charlaDescargada = $true }
            }
        } catch {}
        # la copia del dia, tambien en el PRIMER minuto tras arrancar: diaVisto
        # nace con la fecha de hoy, asi que el bloque de "cambio de dia" no se
        # alcanza al arrancar y la copia no se hacia nunca (revision del 12/09)
        if (-not $script:copiaMirada) {
            $script:copiaMirada = $true
            try { if (Test-CopiaPendiente) { [void](New-CopiaSeguridad 'la del dia') } } catch {}
        }
        $diaAhora = Get-Date -Format 'yyyy-MM-dd'
        if ($diaAhora -ne $script:diaVisto) {
            $script:diaVisto = $diaAhora
            try { Test-FechasHoy } catch {}
            # la copia del dia, en silencio (tambien al arrancar, si toca)
            try { if (Test-CopiaPendiente) { [void](New-CopiaSeguridad 'la del dia') } } catch {}
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
                # CARGADOR: solo en el FLANCO, cuando cambia. Por estado se
                # repetiria cada minuto mientras siguiera enchufado.
                if ($null -ne $script:cargandoAntes -and $cg -ne $script:cargandoAntes) {
                    Invoke-Reglas 'cargadorQuita' $(if ($cg -eq 0) { 'quita' } else { '' })
                    Invoke-Reglas 'cargadorPone' $(if ($cg -eq 1) { 'pone' } else { '' })
                    Log "cargador: $(if ($cg -eq 1) { 'enchufado' } else { 'desenchufado' })"
                    # idea 13: al enchufar, lo util es cuanto le falta
                    if ($cg -eq 1) {
                        [void](Send-AvisoEntorno 'cargador-pone' "Cargando, vas por el $pc por ciento." 'bajo' 20)
                    } else {
                        # idea 7: al desenchufar, cuanto te queda EN TIEMPO, no en porcentaje
                        $txtB = "Sin cargador, al $pc por ciento."
                        if ($script:bateriaMin -gt 0) { $txtB = "Sin cargador: te quedan unos $([int]$script:bateriaMin) minutos." }
                        [void](Send-AvisoEntorno 'cargador-quita' $txtB 'medio' 20)
                    }
                }
                # idea 15: la dejaste cargando toda la noche y ya esta llena
                if ($cargando -and $pc -ge 100) {
                    Invoke-Reglas 'bateriaLlena' 'llena'
                    [void](Send-AvisoEntorno 'bateria-llena' 'Ya esta cargada del todo, puedes desenchufarla.' 'bajo' 240)
                }
                # idea 14: por debajo del 15 %, y esto SI es critico (suena jugando)
                if (-not $cargando -and $pc -le 15) {
                    [void](Send-AvisoEntorno 'bateria-baja' "Te queda el $pc por ciento de bateria." 'alto' 20)
                }
                $script:cargandoAntes = $cg
                # cuanto gasta el juego de delante (ver BATERIA POR JUEGO)
                try { Update-BateriaJuego $pc $cg } catch { Log ("bateria por juego: " + $_.Exception.Message) }
                # a tu hora de dejarla y con poca bateria (ver RECORDATORIO PARA CARGAR)
                try {
                    if (Test-RecordarCarga $pc $cg) {
                        Log "CARGA: recordatorio ($pc %)"
                        Send-UIEvento 'pulso:bateria'
                        if (-not $script:busy -and -not $script:pendiente -and $script:uiEstado -eq 'reposo') { Set-UI 'hablando' 'Enchufame antes de dormir' 4000 }
                    }
                } catch { Log ("recordatorio de carga: " + $_.Exception.Message) }
                # cuanto tiempo queda, que es lo que decide si empiezas otra
                # partida. Viene en el mismo objeto que ya se acaba de leer.
                $script:bateriaMin = 0
                try {
                    $rt = [int]$bat.EstimatedRunTime
                    if ($rt -gt 0 -and $rt -lt 1000) { $script:bateriaMin = $rt }
                } catch {}
                # DESCARGAS DE STEAM: por FLANCO. Lo que dispara es que un juego
                # DEJE de estar bajando, no que este instalado; si no, cada juego
                # ya instalado dispararia la regla en cada vuelta. La primera
                # lectura solo toma nota: al arrancar no se sabe que estaba
                # bajando antes, y anunciar entonces seria inventarse un final.
                try {
                    # antes esto solo se miraba si habia una regla 'descarga' creada a mano;
                    # con los avisos puestos hay que mirarlo igual (idea 24)
                    if ($EntornoOn -or @(Get-Reglas | Where-Object { $_.tipo -eq 'descarga' }).Count -gt 0) {
                        $null = Update-Juegos
                        $ahoraBajan = @{}
                        foreach ($jj in @($script:Juegos)) { if ($jj.bajando) { $ahoraBajan[$jj.nombre] = $true } }
                        if ($null -eq $script:bajandoReglas) {
                            $script:bajandoReglas = $ahoraBajan
                        } else {
                            foreach ($nm in @($script:bajandoReglas.Keys)) {
                                if (-not $ahoraBajan.ContainsKey($nm)) {
                                    Log "DESCARGA terminada (regla): $nm"
                                    Invoke-Reglas 'descarga' $nm
                                    # idea 24: ya se puede jugar
                                    [void](Send-AvisoEntorno "descarga-$nm" "Ya termino de descargarse $nm." 'medio' 180)
                                }
                            }
                            $script:bajandoReglas = $ahoraBajan
                        }
                    }
                } catch {}
                # DISCO: se mira aqui mismo, que ya estamos en el chequeo por minuto
                try {
                    $di = New-Object System.IO.DriveInfo('C')
                    if ($di.IsReady) {
                        $gbLibres = [Math]::Round($di.AvailableFreeSpace / 1073741824.0, 1)
                        Invoke-Reglas 'disco' ([string]$gbLibres)
                        # idea 25: con menos de 15 gigas, un juego ya no cabe
                        if ($gbLibres -lt 15) {
                            [void](Send-AvisoEntorno 'disco-poco' "Te quedan $gbLibres gigas en el disco. Preguntame que ocupa mas." 'medio' 720)
                        }
                    }
                } catch {}
                if (-not $cargando -and $pc -le $BateriaAviso -and -not $script:bateriaAvisada) {
                    $script:bateriaAvisada = $true
                    Log "AVISO: bateria al $pc %"
                    # AHORRO JUGANDO (13/09): con un juego delante no se habla. Pulso
                    # ambar y la pregunta en la capsula; se contesta con ≡+A / ≡+B o
                    # la voz. Solo si el brillo esta alto: si no, no hay que ahorrar.
                    $brilloAhora = -1
                    if ($script:juegoActivo) { try { $brilloAhora = [int]((Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness) } catch {} }
                    if ($script:juegoActivo -and $brilloAhora -gt 40 -and -not $script:pendiente -and -not $script:busy) {
                        Send-UIEvento 'pulso:bateria'
                        $script:pendiente = @{ texto = ''; vence = 0; tipo = 'ahorro' }
                        Set-UI 'escuchando' "Bateria al $pc%. ¿Bajo el brillo?"
                        Start-Confirmacion
                    } else {
                        Send-Aviso "Oye, te queda $pc por ciento de bateria." 'bateria'
                    }
                }
                # rearmar cuando se recupera, para que pueda volver a avisar
                if ($cargando -or $pc -gt ($BateriaAviso + 10)) { $script:bateriaAvisada = $false }
            }
        } catch {}
    }

    # cierra el popup al vencer su plazo (antes se esperaba 8 s bloqueando)
    # el plazo cuenta despues de que Nova termine de LEERLA (mientras habla el
    # oido esta en pausa y no puedes decir "dejala ahi"), y se congela mientras
    # dictas: si no, cerraba justo cuando ibas a fijarla (revision del 13/09)
    if ($script:popupUntil -gt 0 -and $sw.ElapsedMilliseconds -ge $script:popupUntil -and
        $sw.ElapsedMilliseconds -ge ($script:pausaHasta + 5000) -and -not $script:armed) {
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
                # POR QUE murio (14/09): el codigo de salida y lo ultimo que apunto
                # la propia capsula en tmp\ui-error.log
                $porQueUi = ''
                try { $porQueUi = " codigo $($script:uiProc.ExitCode)" } catch {}
                try {
                    $rutaErrUi = Join-Path $TmpDir 'ui-error.log'
                    if ((Test-Path -LiteralPath $rutaErrUi) -and ((Get-Item -LiteralPath $rutaErrUi).LastWriteTime -gt (Get-Date).AddMinutes(-2))) {
                        $ultErrUi = @(Get-Content -LiteralPath $rutaErrUi -Tail 1)[0]
                        if ($ultErrUi) { $porQueUi += "; su ultimo error: " + $ultErrUi.Substring(0, [Math]::Min(400, $ultErrUi.Length)) }
                    }
                } catch {}
                Log "WARN: la interfaz murio ($porQueUi); relanzando (intento $($script:uiIntentos)/3)"
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
    } catch {
        $script:erroresBucle++
        $dondeErr = ''
        try { $dondeErr = " (linea $($_.InvocationInfo.ScriptLineNumber))" } catch {}
        if ($script:erroresBucle -le 50) { Log ("ERROR en una vuelta del bucle, sigo: " + $_.Exception.Message + $dondeErr) }
        # lo que pudo quedar a medias no puede dejar a Nova esperando para siempre
        $script:armed = $false
        $script:pendiente = $null
        $startPrev = $startNow
        try { Set-UI 'reposo' } catch {}
        Start-Sleep -Milliseconds 300
    }
    Start-Sleep -Milliseconds 30
}