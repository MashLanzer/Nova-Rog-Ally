# DE QUE VA ESTE JUEGO (23/09, idea 6). Y lo que NO va aqui: que hacer en esta parte.
#
# SU FRASE, y su fallo, fechado en el propio codigo el 15/09: jugando a It Takes Two, "busca
# informacion sobre el juego que esta en pantalla" buscaba esa frase tal cual en Google y
# abria el navegador ENCIMA de la partida. Y la ventana en la que no se puede abrir nada dura
# HORAS: It Takes Two 5 h 38 el 15/09, 3 h 12 el 22/09, 2 h 45 el 20/09, y la sesion continua
# mas larga medida fue de 6 h 14.
#
# LO QUE MAS VIGILA ESTE BANCO: que no se invente de que va un juego. Comprobado hoy contra
# la Wikipedia: buscar "It Takes Two" a secas devuelve la PELICULA de 1995 con Mary-Kate
# Olsen, y el titulo coincide EXACTO, asi que ninguna comprobacion de titulo lo cazaria. Por
# eso se busca "<juego> videojuego" y ademas se exige que el articulo hable de un juego.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el mundo de mentira. CERO RED: se le dan respuestas guardadas ----------
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('gui-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $TmpDir -Force
$MemoriaDir = $TmpDir
$script:ahoraMs = 100000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:guiaProc = $null
$script:guiaOut = ''
$script:guiaDesde = 0
$script:guiaJuego = ''
$script:juegoActivo = ''
$script:ultimaRespuesta = ''
$script:dichos = @()
$script:popups = @()
$script:apuntes = @()
$script:logs = @()
$DecisionMinIntentos = if ($fuente -match '(?m)^\$DecisionMinIntentos = (\d+)') { [int]$Matches[1] } else { 20 }
function Log([string]$m) { $script:logs += $m }
function Say([string]$t, [string]$e = '') { $script:dichos += $t }
function Show-Popup([string]$t, [string]$e = 'hablando') { $script:popups += $t }
function Add-Estadistica($a, $b) { $script:apuntes += "$a" }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
foreach ($f in @('Get-GuiaTiemposPath', 'Get-GuiaTiempos', 'Add-GuiaTiempo', 'Get-GuiaPlazoMs',
                 'Stop-Guia', 'Get-GuiaFrases', 'Receive-Guia')) { Invoke-Expression (Traer $f) }

# un proceso de mentira: ya salido, para que Receive-Guia lea el fichero
function ProcFalso([bool]$salido) {
    $p = [pscustomobject]@{ Id = 0 }
    $p | Add-Member -MemberType ScriptProperty -Name HasExited -Value ([scriptblock]::Create('$' + $salido.ToString().ToLower()))
    return $p
}
function PonRespuesta($obj) {
    $script:guiaOut = Join-Path $TmpDir 'guia.json'
    Write-Atomico $script:guiaOut (ConvertTo-Json -InputObject $obj -Depth 3)
    $script:guiaProc = ProcFalso $true
    $script:guiaDesde = $script:ahoraMs
    $script:dichos = @(); $script:popups = @(); $script:logs = @(); $script:apuntes = @()
}

Write-Host ''
Write-Host '-- 1. lo que llega de la Wikipedia se dice, y se dice de donde --'
$script:guiaJuego = 'It Takes Two'
$script:juegoActivo = 'It Takes Two'
PonRespuesta @{ ok = $true; motivo = ''; titulo = 'It Takes Two (videojuego)'; fuente = 'es.wikipedia'; ms = 700
                texto = 'It Takes Two es un videojuego de plataformas cooperativo. Fue desarrollado por Hazelight. Salio en 2021.' }
Receive-Guia
Comp 'lo dice en voz alta' ($script:dichos.Count -eq 1) "$($script:dichos.Count)"
Comp 'jugando, UNA sola frase' ($script:dichos[0] -match 'plataformas cooperativo' -and $script:dichos[0] -notmatch 'Hazelight') "$($script:dichos[0])"
Comp 'y dice de donde lo saco' ($script:dichos[0] -match 'Es de la Wikipedia') "$($script:dichos[0])"
Comp 'y queda apuntado el tiempo que tardo' (@(Get-GuiaTiempos) -contains 700) "$(@(Get-GuiaTiempos) -join ', ')"
$script:juegoActivo = ''
PonRespuesta @{ ok = $true; motivo = ''; titulo = 'It Takes Two (videojuego)'; fuente = 'es.wikipedia'; ms = 700
                texto = 'It Takes Two es un videojuego de plataformas cooperativo. Fue desarrollado por Hazelight. Salio en 2021.' }
Receive-Guia
Comp 'sin juego delante, dos frases' ($script:dichos[0] -match 'Hazelight' -and $script:dichos[0] -notmatch '2021') "$($script:dichos[0])"

Write-Host ''
Write-Host '-- 2. si viene de la Wikipedia inglesa, lo dice --'
PonRespuesta @{ ok = $true; motivo = ''; titulo = 'Content Warning'; fuente = 'en.wikipedia'; ms = 900
                texto = 'Content Warning is a 2024 co-op survival-horror video game. It was published by Landfall.' }
Receive-Guia
Comp 'avisa de que es la inglesa' ($script:dichos[0] -match 'en ingles') "$($script:dichos[0])"

Write-Host ''
Write-Host '-- 3. LO QUE NO ENCUENTRA, NO SE LO INVENTA --'
PonRespuesta @{ ok = $false; motivo = 'otro-titulo'; titulo = ''; fuente = ''; ms = 500; texto = '' }
$script:guiaJuego = 'Un Juego Que No Existe'
Receive-Guia
Comp 'dice que no lo encuentra' ($script:dichos[0] -match 'No he encontrado nada') "$($script:dichos[0])"
Comp 'y no se inventa ni una frase' ($script:dichos[0] -notmatch 'videojuego de') "$($script:dichos[0])"
Comp 'y el motivo queda en el log' (@($script:logs | Where-Object { $_ -match 'otro-titulo' }).Count -eq 1) "$($script:logs -join ' | ')"

Write-Host ''
Write-Host '-- 4. si tarda de mas, se corta y se dice --'
$script:guiaProc = ProcFalso $false
$script:guiaOut = Join-Path $TmpDir 'guia.json'
$script:guiaDesde = $script:ahoraMs
$script:dichos = @()
Receive-Guia
Comp 'antes del plazo, calladita' ($script:dichos.Count -eq 0) "$($script:dichos.Count)"
$script:ahoraMs += (Get-GuiaPlazoMs) + 100
Receive-Guia
Comp 'pasado el plazo, lo dice' ($script:dichos.Count -eq 1 -and $script:dichos[0] -match 'No he podido mirarlo') "$($script:dichos -join ' | ')"
Comp 'y suelta el proceso' ($null -eq $script:guiaProc) ''

Write-Host ''
Write-Host '-- 5. el plazo sale de lo medido, no de la cabeza --'
try { Remove-Item -LiteralPath (Get-GuiaTiemposPath) -Force -ErrorAction SilentlyContinue } catch {}
Comp 'con pocas medidas, ocho segundos' ((Get-GuiaPlazoMs) -eq 8000) "$(Get-GuiaPlazoMs) ms"
1..($DecisionMinIntentos + 2) | ForEach-Object { Add-GuiaTiempo 2000 }
Comp 'con medidas, sale de ellas' ((Get-GuiaPlazoMs) -eq 4000) "$(Get-GuiaPlazoMs) ms"
1..30 | ForEach-Object { Add-GuiaTiempo 20000 }
Comp 'y no se pasa de quince segundos' ((Get-GuiaPlazoMs) -le 15000) "$(Get-GuiaPlazoMs) ms"

Write-Host ''
Write-Host '-- 6. SU FRASE, Y A DONDE VA CADA MITAD --'
$patG = ''
foreach ($l in ($fuente -split "`r?`n")) {
    if ($l -match "'(\^\(\?:busca\|buscame\|investiga[^']+)'") { $patG = $Matches[1]; break }
}
if (-not $patG) { Write-Host '  MAL  no encuentro el patron de la guia'; exit 1 }
Comp 'su frase entera entra' ('busca informacion sobre el juego que estoy jugando y dime que hacer en esta parte' -match $patG) ''
Comp 'y "busca gatos en google" NO' ('busca gatos en google' -notmatch $patG) 'eso sigue siendo una busqueda'
$patP = ''
foreach ($l in ($fuente -split "`r?`n")) {
    if ($l -match 'tengo que hacer' -and $l -match "'(\^[^']+)'") { $patP = $Matches[1]; break }
}
if (-not $patP) { Write-Host '  MAL  no encuentro el patron de la parte'; exit 1 }
Comp '"que hago en esta parte" entra por el suyo' ('que hago en esta parte' -match $patP) ''
# y en el ejecutor, la parte va al cerebro y NO a la Wikipedia
$iEj = $fuente.IndexOf("'guiaJuego' {")
if ($iEj -lt 0) { Write-Host '  MAL  no encuentro el ejecutor'; exit 1 }
$ejG = $fuente.Substring($iEj, 1600)
Comp 'la parte va a la captura y al cerebro' ($ejG -match 'Save-Captura' -and $ejG -match "Submit-Command \`$pregG 'charla'") 'eso no esta en ninguna enciclopedia'
Comp 'y le pide que NO se lo invente' ($ejG -match 'no te lo inventes') ''
Comp 'la parte NO llama a la Wikipedia' ($ejG.IndexOf('Start-GuiaJuego') -gt $ejG.IndexOf('Submit-Command')) 'leer el resumen seria contestar a otra cosa'

Write-Host ''
Write-Host '-- 7. y no bloquea el bucle --'
$rg = SinComentarios (Traer 'Receive-Guia')
Comp 'la recogida no toca la red' ($rg -notmatch 'Invoke-WebRequest|Invoke-RestMethod') ''
Comp 'ni espera a nadie' ($rg -notmatch 'WaitForExit|Start-Sleep') 'solo mira si ya salio'
Comp 'se dice con Say, no con Send-Aviso' ($rg -match 'Say ' -and $rg -notmatch 'Send-Aviso') 'un aviso con el juego delante se queda mudo'
$sg = SinComentarios (Traer 'Start-GuiaJuego')
Comp 'y la peticion se lanza en otro proceso' ($sg -match 'Start-Process' -and $sg -match 'GuiaScript') ''

Write-Host ''
Write-Host '-- 8. el ayudante busca el JUEGO, no la pelicula --'
# LOS TRES CIERRES SE EJECUTAN DE VERDAD, sin tocar la red: se sacan del fichero y se les
# dan articulos guardados, incluido el de la pelicula que de verdad devuelve la Wikipedia.
$gw = [System.IO.File]::ReadAllText((Join-Path $raiz 'tools\guia-web.ps1'))
foreach ($fn in @('Quita-Tildes', 'Titulo-Limpio', 'Test-ArticuloJuego')) {
    $m = [regex]::Match($gw, ('(?ms)^function {0}[ (\[].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host "  MAL  no encuentro $fn en guia-web.ps1"; exit 1 }
    . ([scriptblock]::Create($m.Value))
}
$peli = 'It Takes Two (Dos por el precio de una en Espana) es una pelicula estadounidense de 1995, dirigida por Andy Tennant y protagonizada por las gemelas Olsen.'
Comp 'la PELICULA de 1995 se rechaza' ((Test-ArticuloJuego 'It Takes Two' $peli 'it takes two') -eq 'no-habla-de-un-juego') "$(Test-ArticuloJuego 'It Takes Two' $peli 'it takes two')"
$juego = 'It Takes Two es un videojuego de plataformas cooperativo desarrollado por Hazelight Studios y publicado por Electronic Arts.'
Comp 'y el JUEGO se acepta' ((Test-ArticuloJuego 'It Takes Two (videojuego)' $juego 'it takes two') -eq '') "$(Test-ArticuloJuego 'It Takes Two (videojuego)' $juego 'it takes two')"
Comp 'otro articulo con otro nombre, fuera' ((Test-ArticuloJuego 'Clasificacion por edades (videojuegos)' $juego 'content warning') -eq 'otro-titulo') ''
Comp 'un extracto de dos palabras, fuera' ((Test-ArticuloJuego 'It Takes Two' 'Es un videojuego.' 'it takes two') -eq 'extracto-corto') "$(Test-ArticuloJuego 'It Takes Two' 'Es un videojuego.' 'it takes two')"
Comp 'y sin titulo, fuera' ((Test-ArticuloJuego '' $juego 'it takes two') -eq 'sin-articulo') ''
Comp 'busca "<juego> videojuego"' ($gw -match '\$Juego \+ \$pista') 'sin eso, "It Takes Two" da la pelicula de 1995'
Comp 'y nunca rellena con un modelo' ($gw -notmatch 'gemini|claude|ollama|opencode') ''

Write-Host ''
Write-Host '-- y donde se recoge, que era lo que la hacia tardar medio minuto --'
# La guia se recogia DENTRO de Watch-Entorno, detras de su puerta de 30 s: el proceso tardaba
# uno o dos segundos y Nova hablaba entre 0 y 30 s despues, quince de media. Y Watch-Entorno
# sale en su primera linea si entorno.avisos esta apagado -que es el valor por DEFECTO del
# codigo-, asi que ahi la respuesta no llegaba nunca y la capsula se quedaba en "pensando".
$fnEnt = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Watch-Entorno' }, $true)
Comp 'Receive-Guia NO vive dentro de Watch-Entorno' ($fnEnt -and $fnEnt.Extent.Text -notmatch 'Receive-Guia') 'ahi solo se miraba cada 30 s, y con los avisos apagados nunca'
Comp 'y si se llama desde el bucle' ($fuente -match '(?m)^\s+try \{ Receive-Guia \} catch') ''
$sg = ($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Stop-Guia' }, $true)).Extent.Text
# SIN COMENTARIOS: el comentario que explica por que ya no hay -Wait contiene "-Wait", y la
# comprobacion de abajo lo casaba. Es el mismo tropiezo que la palabra "siguiente" en la trivia.
$sg = (($sg -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'matarla no para el bucle' ($sg -notmatch '\-Wait') 'arrancar taskkill.exe y esperarlo son 100-400 ms con un juego delante'
Comp 'y se suelta el proceso' ($sg -match 'Dispose') ''
Comp 'y al salir Nova no queda huerfana' ($fuente -match '(?s)try \{ Stop-Guia \} catch \{\}\s*\n\s*foreach \(\$pW in') 'antes se mataban los otros cuatro procesos y este no'

try { Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya te dice de que va, sin abrir nada encima de la partida'
exit 0
