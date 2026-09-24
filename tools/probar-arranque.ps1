# QUE NOVA DIGA SI ARRANCO A MEDIAS (17/09).
#
# Nova ya comprobaba sus piezas al arrancar -si falta wake_vosk.py, nova_ui.exe,
# commands.json o el CLI del agente- pero todas esas comprobaciones morian en el log, donde
# nadie las ve: arrancaba a medias, saludaba "Listo" igual, y el fallo se descubria a la
# primera orden que no funcionaba.
#
# Esto NO anadio comprobaciones nuevas: recoge las que ya habia y las cuenta en el saludo,
# que existe justo para eso ("confirma que la voz funciona").
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Add-FalloArranque')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- la lista de lo que no arranco --'
$script:fallosArranque = New-Object System.Collections.ArrayList
Comp 'empieza vacia' ($script:fallosArranque.Count -eq 0) ''
Add-FalloArranque 'me falta la capsula'
Comp 'apunta un fallo' ($script:fallosArranque.Count -eq 1) ''
Add-FalloArranque 'me falta la capsula'
Comp 'y no lo apunta dos veces' ($script:fallosArranque.Count -eq 1) ("van " + $script:fallosArranque.Count)
Add-FalloArranque ''
Comp 'un fallo vacio no cuenta' ($script:fallosArranque.Count -eq 1) ''
Add-FalloArranque 'no encuentro el agente'
Comp 'otro distinto si' ($script:fallosArranque.Count -eq 2) ''

# --- la frase que se dice, montada igual que en el arranque ---
function Frase($lista) {
    if ($lista.Count -eq 0) { return 'Listo. Di nova cuando me necesites.' }
    $t = if ($lista.Count -eq 1) { $lista[0] }
         else { ($lista[0..($lista.Count - 2)] -join ', ') + ' y ' + $lista[-1] }
    return "Listo, pero arranque a medias: $t."
}
Write-Host '  -- y como suena --'
Comp 'sin fallos, el saludo de siempre' ((Frase @()) -notmatch 'a medias') ("'" + (Frase @()) + "'")
Comp 'con uno, se dice ese' ((Frase @('me falta la capsula')) -eq 'Listo, pero arranque a medias: me falta la capsula.') ("'" + (Frase @('me falta la capsula')) + "'")
$dos = Frase @('me falta la capsula', 'no encuentro el agente')
Comp 'con dos, se unen con "y"' ($dos -match 'capsula y no encuentro') ("'" + $dos + "'")
$tres = Frase @('a', 'b', 'c')
Comp 'con tres, comas y la ultima con "y"' ($tres -match 'a, b y c') ("'" + $tres + "'")

# --- y que el enganche siga puesto en el codigo real ---
Write-Host '  -- y las comprobaciones que ya existian lo apuntan --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
foreach ($par in @(
    @('falta wake_vosk.py', 'la palabra de activacion'),
    @('falta nova_ui.exe', 'la capsula'),
    @('no hay commands.json', 'la lista de ordenes'),
    @('opencode CLI no encontrado', 'el agente'),
    @('voz no disponible', 'la voz'))) {
    # TODAS las apariciones, no la primera: algunos de estos textos salen tambien en un
    # comentario, y mirar solo la primera daba un rojo falso (17/09).
    $ok = $false
    $i = $txt.IndexOf($par[0])
    while ($i -ge 0) {
        $trozo = $txt.Substring($i, [Math]::Min(320, $txt.Length - $i))
        if ($trozo -match 'Add-FalloArranque') { $ok = $true; break }
        $i = $txt.IndexOf($par[0], $i + 1)
    }
    Comp ("se apunta cuando falla " + $par[1]) $ok ''
}
Comp 'y el saludo lo dice' ($txt -match 'arranque a medias') ''
Comp 'y queda en las estadisticas' ($txt -match "Add-Estadistica 'arranque-medias'") ''

Write-Host ''
Write-Host '-- CUANTO TARDA EN ABRIR EL OIDO (23/09, idea 12) --'
# LA IDEA PEDIDA -mover la carga de Whisper a un hilo- NO SE HACE, y los numeros dicen por
# que: del "oido ya listo" a la primera orden, sobre 234 arranques, CERO en 2 s, UNA en 3 s
# (el 0,4 %) y mediana 41 s. Si braya le estuviera hablando a una Nova sorda, al levantarse
# el oido habria un monton de ordenes pegadas al cero. No hay ni una. Asi que lo que se anade
# es la MEDICION, que es lo unico que justificaria tocar la carga algun dia.
#
# Y LO QUE SI ESTABA ROTO: la coletilla "todavia estoy abriendo el oido" salia en el 100 % de
# los arranques -0 veces del 10 al 19/09, y 6/14, 9/10, 12/12 y 13/13 del 20 al 23-. Y no es
# que el oido empeorara: la mediana de carga sigue clavada en 4,10 s. Lo que cambio el 20/09
# es que la marca pasa a escribirla el asistente ANTES de lanzar nada, asi que cuando el
# saludo la mira SIEMPRE esta puesta. Una certeza disfrazada de aviso no informa de nada.
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('arr-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $TmpDir -Force
$MemoriaDir = $TmpDir
$script:ahoraMs = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:oidoMarcaPuesta = 0
$script:oidoApuntado = $false
$script:oidoListoEn = 0
$script:oidoProntoDicho = $false
$script:apuntes = @()
$script:logs = @()
function Log([string]$m) { $script:logs += $m }
function Add-Estadistica($a, $b) { $script:apuntes += "$a" }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
# EL TOPE SALE DEL FUENTE: sin el, $ArranqueOidoMax llega como $null y "Count -gt $null" es
# cierto para cualquier lista, asi que el recorte se disparaba en el primer apunte y encima
# reventaba. Es el mismo cuidado de siempre: nada de copiar numeros a mano.
$srcA = [System.IO.File]::ReadAllText($rutaA)
$ArranqueOidoMax = if ($srcA -match '(?m)^\$ArranqueOidoMax = (\d+)') { [int]$Matches[1] } else { 200 }
foreach ($fn in @('Get-ArranqueOidoPath', 'Get-ArranqueOidoMs', 'Add-ArranqueOidoMs',
                  'Add-ArranqueOido', 'Add-ArranquePronto')) { Invoke-Expression (Traer $fn) }
$marcaO = Join-Path $TmpDir 'oido-cargando.txt'
function Arranca([int]$en = 0) {
    $script:ahoraMs = $en
    $script:oidoMarcaPuesta = $en
    $script:oidoApuntado = $false
    $script:oidoListoEn = 0
    $script:oidoProntoDicho = $false
    $script:apuntes = @(); $script:logs = @()
    [System.IO.File]::WriteAllText($marcaO, 'x')
    try { Remove-Item -LiteralPath (Get-ArranqueOidoPath) -Force -ErrorAction SilentlyContinue } catch {}
}

Arranca 1000
$script:ahoraMs = 3000
Add-ArranqueOido
Comp 'con la marca puesta, no apunta nada' ($script:apuntes.Count -eq 0) "$($script:apuntes.Count)"
Remove-Item -LiteralPath $marcaO -Force
$script:ahoraMs = 5100
Add-ArranqueOido
Comp 'al desaparecer la marca, apunta' (@($script:apuntes | Where-Object { $_ -eq 'arranque-oido' }).Count -eq 1) "$($script:apuntes -join ', ')"
Comp 'y el numero es contra CUANDO se puso la marca' (@(Get-ArranqueOidoMs)[0] -eq 4100) "$(@(Get-ArranqueOidoMs)[0]) ms"
Add-ArranqueOido
Add-ArranqueOido
Add-ArranqueOido
Comp 'y se apunta UNA sola vez, aunque se llame cinco' (@($script:apuntes | Where-Object { $_ -eq 'arranque-oido' }).Count -eq 1) "$($script:apuntes -join ', ')"

# el numero que DECIDE: le habla justo al abrirse el oido
$script:ahoraMs = 7000
Add-ArranquePronto
Comp 'hablarle a los 1,9 s de abrirse cuenta' (@($script:apuntes | Where-Object { $_ -eq 'arranque-pronto' }).Count -eq 1) "$($script:apuntes -join ', ')"
Add-ArranquePronto
Comp 'pero solo una vez por arranque' (@($script:apuntes | Where-Object { $_ -eq 'arranque-pronto' }).Count -eq 1) "$($script:apuntes -join ', ')"
Arranca 1000
Remove-Item -LiteralPath $marcaO -Force
$script:ahoraMs = 5100
Add-ArranqueOido
$script:ahoraMs = 5100 + 4000
Add-ArranquePronto
Comp 'y a los 4 s ya no cuenta' (@($script:apuntes | Where-Object { $_ -eq 'arranque-pronto' }).Count -eq 0) "$($script:apuntes -join ', ')"

# la lista tiene tope
Arranca 0
Remove-Item -LiteralPath $marcaO -Force
1..210 | ForEach-Object { Add-ArranqueOidoMs $_ }
Comp 'la lista de tiempos no crece sin fin' (@(Get-ArranqueOidoMs).Count -le 200) "$(@(Get-ArranqueOidoMs).Count)"

Write-Host ''
Write-Host '-- y la coletilla del saludo ya no sale SIEMPRE --'
$txtS = [System.IO.File]::ReadAllText($rutaA)
# el if del saludo tiene que mirar el RELOJ, no solo la marca
$iSal = $txtS.IndexOf("oido-cargando.txt')) -and")
Comp 'la coletilla mira cuanto lleva la marca puesta' ($iSal -ge 0 -and $txtS.Substring($iSal, 220) -match 'oidoMarcaPuesta') 'antes salia el 100 % de las veces'
Comp 'y el umbral esta escrito con su porque' ($txtS -match 'una certeza disfrazada de aviso') ''
Comp 'la marca la sigue poniendo el asistente' ($txtS -match "WriteAllText\(\(Join-Path \`$TmpDir 'oido-cargando\.txt'\)") ''

Write-Host ''
Write-Host '-- y se puede preguntar --'
$patA = ''
foreach ($l in ($txtS -split "`r?`n")) {
    if ($l -match "'(\^\(\?:cuanto tardas en [^']+)'") { $patA = $Matches[1]; break }
}
if (-not $patA) { throw 'no encuentro el patron de cuanto tardas en arrancar' }
Comp '"cuanto tardas en arrancar" entra' ('cuanto tardas en arrancar' -match $patA) ''
Comp 'y "cuanto tarda tu oido en cargar" tambien' ('cuanto tarda tu oido en cargar' -match $patA) ''
Comp 'pero "cuanto tarda la nube" NO' ('cuanto tarda la nube' -notmatch $patA) 'esa es otra pregunta y va delante'

try { Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
