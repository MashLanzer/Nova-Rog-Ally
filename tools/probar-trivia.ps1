# LA TRIVIA, CON PREGUNTAS DE VERDAD, EL MANDO Y UN MARCADOR (23/09, idea 8).
#
# EL DATO QUE MANDA, del registro: el 13/09 a las 20:46:00 braya pregunto "que es un volcan".
# DOS MINUTOS Y CINCUENTA Y DOS SEGUNDOS despues, a las 20:48:52, la trivia le pregunto a EL
# "que es un volcan". Contesto "no se, me rindo". Las preguntas salian de lo que el mismo
# acababa de preguntar, asi que le devolvio la suya de hace tres minutos.
# Y "CHARLA (trivia)" sale UNA sola vez en las 49.492 lineas del registro: 13/09 20:48:52.
# Una vez en catorce dias, el dia que se estreno, y nunca mas.
#
# EL MANDO SE USO PARA CONTESTAR CERO VECES en catorce dias, con veinte preguntas vivas. Y con
# el oido al 70,4 % una trivia se contesta con nombres propios -"Canberra", "Leonardo da
# Vinci"-, que es la peor clase de palabra que le puede llegar. Con tres opciones y cruceta no
# hay nada que entender: por eso la respuesta por mando es la principal, y por eso la B tiene
# que SALIR del modo y no solo cerrar la lista.
#
# LO QUE MAS SE VIGILA AQUI: que las tres opciones se barajen. Un modelo de 3B pone la buena
# la primera casi siempre, y entonces "la primera" acierta sin saber nada y el juego no es un
# juego.
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
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el mundo de mentira ----------------------------------------------------
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('triv-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
$sw = [System.Diagnostics.Stopwatch]::StartNew()
# los dos numeros se leen del codigo: si alli cambian, el banco los sigue
$TriviaMinBanco = if ($fuente -match '(?m)^\$TriviaMinBanco = (\d+)') { [int]$Matches[1] } else { -1 }
$TriviaModoMs = if ($fuente -match '(?m)^\$TriviaModoMs = (\d+)') { [int]$Matches[1] } else { -1 }
$script:juegoActivo = $false
$ConversacionOn = $true
$script:charlaId = 0
$script:dicho = @()
$script:pintado = @()
$script:abierto = @()
$script:cerrado = 0
$script:pedidos = @()
$script:ramHay = $true
$script:mandoHay = $true
function Log([string]$m) { }
function Save-Corrupto($a, $b) { $script:corrupto = $true }
function Write-Atomico([string]$r, [string]$t, [bool]$bom = $false) {
    [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false)))
}
function Say([string]$t, [string]$e = '') { $script:dicho += $t }
function Show-Popup([string]$t, [string]$e = 'hablando') { $script:pintado += $t }
function Open-Eleccion([string[]]$ops, [string]$origen) {
    if (-not $script:mandoHay) { return $false }
    $script:abierto += , @{ opciones = @($ops); origen = $origen }
    return $true
}
function Close-Eleccion([bool]$tocarUI = $true) { $script:cerrado++ }
function Test-RamParaCharla { return $script:ramHay }
function Send-CharlaPedido($pedido, [bool]$arrancar = $true) { $script:pedidos += , $pedido; return $true }

foreach ($f in @('Get-TriviaPath', 'Get-BancoTrivia', 'Save-BancoTrivia', 'Request-BancoTrivia',
                 'Get-MarcadorTrivia', 'Show-PreguntaTrivia', 'Start-Trivia', 'Complete-Trivia',
                 'Stop-Trivia', 'Test-TriviaPlazo')) { Invoke-Expression (Traer $f) }

function Escribir($preguntas) {
    $o = @{ preguntas = @($preguntas); hechas = @() }
    [System.IO.File]::WriteAllText((Get-TriviaPath), (ConvertTo-Json -InputObject $o -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
}
function Limpia {
    $script:triviaBanco = $null
    $script:triviaActual = $null
    $script:triviaModoHasta = 0
    $script:triviaGenerando = $false
    $script:triviaBien = 0
    $script:triviaTotal = 0
    $script:dicho = @(); $script:pintado = @(); $script:abierto = @(); $script:cerrado = 0
    $script:pedidos = @(); $script:corrupto = $false
    try { Remove-Item -LiteralPath (Get-TriviaPath) -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host ''
Write-Host '-- 1. LAS TRES OPCIONES SE BARAJAN (lo que mata a la trivia si falla) --'
# Una sola pregunta, con la buena SIEMPRE la primera, que es lo que devuelve un modelo de 3B.
# Si no se barajase, "la primera" acertaria las sesenta veces.
Limpia
Escribir @(@{ id = 'q1'; pregunta = 'Capital de Australia?'; opciones = @('Canberra', 'Sidney', 'Melbourne'); buena = 1 })
$pos = @{ 1 = 0; 2 = 0; 3 = 0 }
$malCasado = 0
for ($i = 0; $i -lt 60; $i++) {
    $script:triviaActual = $null
    [void](Show-PreguntaTrivia)
    $a = $script:triviaActual
    $pos[[int]$a.buena]++
    # LA COMPROBACION DE VERDAD: la que dice que es buena tiene que SER la buena. Si la cuenta
    # del barajado esta mal, esto se cae aunque las tres posiciones salgan repartidas.
    if ([string]$a.opciones[[int]$a.buena - 1] -ne 'Canberra') { $malCasado++ }
    if (@($a.opciones | Sort-Object) -join '|' -ne 'Canberra|Melbourne|Sidney') { $malCasado++ }
}
Comp 'la buena cae en las tres posiciones' ($pos[1] -gt 0 -and $pos[2] -gt 0 -and $pos[3] -gt 0) "1:$($pos[1]) 2:$($pos[2]) 3:$($pos[3])"
Comp 'y no se queda pegada a la primera' ($pos[1] -lt 45) "$($pos[1]) de 60"
Comp 'la que marca como buena ES la buena, las 60 veces' ($malCasado -eq 0) "$malCasado fallos"
Comp 'y las tres opciones siguen estando' ($script:triviaActual.opciones.Count -eq 3) ''

Write-Host ''
Write-Host '-- 2. lo que el banco tira al leer --'
# El selector corta al pintar lo que pase de 26, y una opcion cortada no se puede elegir a
# ciegas. Y una pregunta con dos opciones deja el selector con dos: "la tercera" no existiria.
Limpia
Escribir @(
    @{ id = 'b1'; pregunta = 'Buena'; opciones = @('uno', 'dos', 'tres'); buena = 2 },
    @{ id = 'b2'; pregunta = 'Solo dos'; opciones = @('uno', 'dos'); buena = 1 },
    @{ id = 'b3'; pregunta = 'Cuatro'; opciones = @('uno', 'dos', 'tres', 'cuatro'); buena = 1 },
    @{ id = 'b4'; pregunta = 'Buena cero'; opciones = @('uno', 'dos', 'tres'); buena = 0 },
    @{ id = 'b5'; pregunta = 'Buena cuatro'; opciones = @('uno', 'dos', 'tres'); buena = 4 },
    @{ id = 'b6'; pregunta = 'Larga'; opciones = @('uno', 'dos', 'esta opcion tiene mas de veintiseis'); buena = 1 },
    @{ id = 'b7'; pregunta = 'Vacia'; opciones = @('uno', '', 'tres'); buena = 1 }
)
$b = Get-BancoTrivia
Comp 'de siete, solo pasa la que esta bien' (@($b.preguntas).Count -eq 1) "$(@($b.preguntas).Count)"
Comp 'y es la que es' (@($b.preguntas)[0].id -eq 'b1') "$(@($b.preguntas)[0].id)"
$gb = SinComentarios (Traer 'Get-BancoTrivia')
Comp 'el limite de 26 esta escrito, no adivinado' ($gb -match '\$_\.Length -gt 26') ''

Write-Host ''
Write-Host '-- 3. no repite pregunta hasta darles la vuelta a todas --'
# VEINTE, NO TRES: sacando tres de tres al azar, salir sin repetir es 6 de 27, o sea que un
# banco roto pasaria una de cada cinco veces. Con veinte de veinte, una entre cuarenta
# millones. Un banco que solo acierta a veces no es un banco.
Limpia
Escribir @(1..20 | ForEach-Object { @{ id = "r$_"; pregunta = "P$_"; opciones = @('a', 'b', 'c'); buena = 1 } })
$vistas = @()
[void](Start-Trivia)
for ($i = 0; $i -lt 20; $i++) {
    $vistas += [string]$script:triviaActual.id
    Complete-Trivia 0   # me rindo: pasa a la siguiente
}
Comp 'las veinte, sin repetir ninguna' ((@($vistas | Sort-Object -Unique)).Count -eq 20) "$((@($vistas | Sort-Object -Unique)).Count) distintas de 20"
Comp 'y a la veintiuna vuelve a empezar' ($null -ne $script:triviaActual) "$([string]$script:triviaActual.id)"
Comp 'la lista de hechas no crece sin fin' (@((Get-BancoTrivia).hechas).Count -le 20) "$(@((Get-BancoTrivia).hechas).Count)"

Write-Host ''
Write-Host '-- 4. el marcador --'
Limpia
Escribir @(@{ id = 'm1'; pregunta = 'Una'; opciones = @('a', 'b', 'c'); buena = 1 })
Comp 'sin jugar nada, no se inventa un cero de algo' ((Get-MarcadorTrivia) -eq 'aun no llevamos ninguna') "$(Get-MarcadorTrivia)"
[void](Start-Trivia)
Complete-Trivia ([int]$script:triviaActual.buena)                        # acierto
Complete-Trivia ((([int]$script:triviaActual.buena) % 3) + 1)            # fallo
Comp 'uno de dos' ((Get-MarcadorTrivia) -eq 'llevas 1 de 2') "$(Get-MarcadorTrivia)"
Comp 'y al acertar lo dice' (@($script:dicho | Where-Object { $_ -like 'Bien.*' }).Count -eq 1) ''
Comp 'al fallar dice cual era' (@($script:dicho | Where-Object { $_ -like 'No, era *' }).Count -eq 1) ''

Write-Host ''
Write-Host '-- 5. LAS SALIDAS: ni una sola puede faltar (regla de la casa) --'
Limpia
Escribir @(@{ id = 's1'; pregunta = 'Una'; opciones = @('a', 'b', 'c'); buena = 1 })
[void](Start-Trivia)
Comp 'al empezar, el modo esta abierto' ($script:triviaModoHasta -gt $sw.ElapsedMilliseconds) ''
Stop-Trivia 'voz'
Comp '1) diciendolo: el modo se cierra' ($script:triviaModoHasta -eq 0) ''
Comp '   y cierra el selector de paso' ($script:cerrado -ge 1) "$($script:cerrado)"
Comp '   y no deja una pregunta viva colgando' ($null -eq $script:triviaActual) ''
# el plazo
Limpia
Escribir @(@{ id = 's2'; pregunta = 'Una'; opciones = @('a', 'b', 'c'); buena = 1 })
[void](Start-Trivia)
Test-TriviaPlazo
Comp '2) el plazo no vence antes de tiempo' ($script:triviaModoHasta -gt 0) ''
$script:triviaModoHasta = $sw.ElapsedMilliseconds - 1
Test-TriviaPlazo
Comp '   y vencido, se cierra solo' ($script:triviaModoHasta -eq 0) ''
Comp '   el plazo son los cinco minutos del codigo' ($TriviaModoMs -eq 300000) "$TriviaModoMs ms"
# la B del mando
$lineasB = @($fuente -split "`r?`n")
$iB = ($lineasB | Select-String -SimpleMatch 'ELEGIR: cancelado con B' | Select-Object -First 1).LineNumber
if (-not $iB) { Write-Host '  MAL  no encuentro la rama de la B'; exit 1 }
$trozoB = ($lineasB[($iB - 4)..($iB + 3)] -join "`n")
Comp '3) la B del mando SALE del modo, no solo cierra la lista' ($trozoB -match "Stop-Trivia 'boton B'") ''
Comp '   y solo cuando lo que hay abierto es la trivia' ($trozoB -match "origen -eq 'trivia'") ''
# 4) mandar callar. "para" y "basta" son dos de las salidas que la trivia anuncia, y hasta el
# 24/09 se las comia el CORTE -que esta 84 lineas antes-: la callaba y el modo seguia vivo
# cinco minutos con la pregunta puesta.
$lineasC = @($fuente -split "`r?`n")
$iC = ($lineasC | Select-String -SimpleMatch 'CORTE:' | Select-Object -First 1).LineNumber
if (-not $iC) { Write-Host '  MAL  no encuentro el bloque del CORTE'; exit 1 }
$trozoC = ($lineasC[($iC - 9)..($iC + 1)] -join "`n")
Comp '4) mandar callar tambien sale de la trivia' ($trozoC -match "Stop-Trivia 'corte'") 'antes la callaba y el modo seguia vivo'
Comp '   y solo si estaba en la trivia' ($trozoC -match 'triviaModoHasta -gt \$sw\.ElapsedMilliseconds') ''
# el plazo, llamado en el bucle
Comp 'Test-TriviaPlazo se llama en el bucle de verdad' ($fuente -match '(?m)^\s+try \{ Test-TriviaPlazo \} catch \{\}') ''
$st = SinComentarios (Traer 'Stop-Trivia')
Comp 'salir dos veces no habla dos veces' ($st -match '\$script:triviaModoHasta -le 0.*return') ''

Write-Host ''
Write-Host '-- 6. las ordenes del modo viven DENTRO del modo --'
# "siguiente" fuera de la trivia es la tecla multimedia y no se toca: por eso todo el bloque
# va bajo la guarda. Se comprueba con el arbol, no leyendo lineas sueltas.
# ESA CONDICION SALE DOS VECES desde el 24/09: la guarda del bloque de ordenes y la del
# CORTE, que hace que "para" y "basta" salgan del modo. Se coge por lo que hay DENTRO, no por
# el orden, que si no el banco mira la que no es.
$guarda = @($ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.IfStatementAst] -and
    $x.Clauses[0].Item1.Extent.Text -eq '$script:triviaModoHasta -gt $sw.ElapsedMilliseconds' -and
    $x.Extent.Text -like '*Complete-Trivia 1*' }, $true))
Comp 'hay una guarda del modo' ($guarda.Count -eq 1) "$($guarda.Count)"
# SIN COMENTARIOS: si no, "siguiente" casaba con el comentario que explica por que esta
# "siguiente", y borrar el codigo dejando el comentario seguia dando verde.
$dentro = if ($guarda.Count -ge 1) { SinComentarios $guarda[0].Extent.Text } else { '' }
Comp 'la salida esta dentro' ($dentro -match "Stop-Trivia 'voz'") ''
Comp 'el marcador esta dentro' ($dentro -match 'Get-MarcadorTrivia') ''
Comp '"la primera" esta dentro' ($dentro -match 'Complete-Trivia 1') ''
Comp '"siguiente" esta dentro (fuera es la tecla multimedia)' ($dentro -match 'siguiente') ''
$iGuarda = $fuente.IndexOf('if ($script:triviaModoHasta -gt $sw.ElapsedMilliseconds) {')
$iF7 = $fuente.IndexOf('if ($script:triviaHasta -gt $sw.ElapsedMilliseconds) {')
Comp 'y el bloque va DELANTE del de F7' ($iGuarda -gt 0 -and $iF7 -gt $iGuarda) 'si no, "la primera" se iria a la charla'
# el marcador no gasta la pregunta
$iMarc = $dentro.IndexOf('Get-MarcadorTrivia')
$iResp = $dentro.IndexOf('Complete-Trivia 1')
Comp 'el marcador no gasta la pregunta viva' ($iMarc -lt $iResp -and $dentro.Substring($iMarc, [Math]::Min(120, $dentro.Length - $iMarc)) -notmatch 'Complete-Trivia') '"como voy" no es una respuesta'
$iSal = $dentro.IndexOf("Stop-Trivia 'voz'")
Comp 'y la salida va la primera de todas' ($iSal -lt $iMarc) 'una salida nunca va detras de nada'

Write-Host ''
Write-Host '-- 7. pedir preguntas: cuando si y cuando no --'
Limpia
$script:juegoActivo = $true
Comp 'NO se piden con un juego delante' ((Request-BancoTrivia) -eq $false) 'la regla 5 de la casa'
$script:juegoActivo = $false
$script:ramHay = $false
Comp 'NO se piden sin RAM' ((Request-BancoTrivia) -eq $false) ''
$script:ramHay = $true
Comp 'sin ellos, si' ((Request-BancoTrivia) -eq $true) ''
Comp 'y no se piden dos veces a la vez' ((Request-BancoTrivia) -eq $false) ''
Comp 'solo salio un pedido' (@($script:pedidos).Count -eq 1) "$(@($script:pedidos).Count)"
Comp 'el pedido lleva la ruta puesta' ([string]@($script:pedidos)[0].ruta -eq (Get-TriviaPath)) 'el worker no adivina la carpeta'
Comp 'y dice cuantas' ([int]@($script:pedidos)[0].cuantas -gt 0) "$([int]@($script:pedidos)[0].cuantas)"
$rq = SinComentarios (Traer 'Request-BancoTrivia')
Comp 'NO usa Send-Charla (esa pone la capsula a esperar)' ($rq -notmatch 'Send-Charla\b') ''
$ct = SinComentarios (Traer 'Complete-Trivia')
Comp 'contestar no sale a pedir nada' ($ct -notmatch 'Request-BancoTrivia') 'contestar cuesta cero'

Write-Host ''
Write-Host '-- 8. sin banco, no se miente: se cae a lo de antes --'
Limpia
Comp 'sin banco, Start-Trivia dice que no' ((Start-Trivia) -eq $false) ''
Comp 'y no ha dicho nada por su cuenta' (@($script:dicho).Count -eq 0) "$(@($script:dicho) -join ' / ')"
Comp 'ni ha pintado una pregunta vacia' (@($script:pintado).Count -eq 0) "$(@($script:pintado) -join ' / ')"
Comp 'ni ha abierto el selector con nada dentro' (@($script:abierto).Count -eq 0) "$(@($script:abierto).Count)"
Comp 'ni ha dejado el modo abierto' ($script:triviaModoHasta -eq 0) "$($script:triviaModoHasta)"
Comp 'pero se pide para la proxima' (@($script:pedidos).Count -eq 1) "$(@($script:pedidos).Count)"
# Y LA RED DE DEBAJO, POR SEPARADO: Start-Trivia ya se para antes, asi que esta linea de
# Show-PreguntaTrivia no se alcanza por el camino normal. Se llama a mano justo por eso: dos
# redes que solo se prueban juntas son una sola red, y el dia que alguien quite la de arriba
# nadie se entera. Sin ella, $cand esta vacia y Get-Random revienta o sale una pregunta en
# blanco leida en voz alta.
Comp 'y Show-PreguntaTrivia sola tampoco saca nada' ((Show-PreguntaTrivia) -eq $false) ''
Comp 'sin decir ni pintar una pregunta en blanco' ((@($script:dicho).Count -eq 0) -and (@($script:pintado).Count -eq 0)) "$(@($script:dicho) -join ' / ')"
Limpia
Escribir @(1..3 | ForEach-Object { @{ id = "p$_"; pregunta = "P$_"; opciones = @('a', 'b', 'c'); buena = 1 } })
[void](Start-Trivia)
Comp 'con pocas, juega Y pide mas' (@($script:pedidos).Count -eq 1 -and $null -ne $script:triviaActual) "$TriviaMinBanco es el liston"
Comp 'el liston esta escrito arriba, no suelto' ($TriviaMinBanco -gt 0) "$TriviaMinBanco"

Write-Host ''
Write-Host '-- 9. el banco se guarda y se vuelve a leer igual --'
# TRES preguntas y se contesta UNA: con una sola, la ronda se agota en esa misma respuesta y
# la lista de hechas se vacia a proposito para volver a empezar -que es lo que tiene que
# pasar-, asi que no habria nada que comprobar.
Limpia
Escribir @(1..3 | ForEach-Object { @{ id = "g$_"; pregunta = "G$_"; opciones = @('a', 'b', 'c'); buena = 2 } })
[void](Start-Trivia)
$hecha = [string]$script:triviaActual.id
Complete-Trivia 1
$script:triviaBanco = $null
$b2 = Get-BancoTrivia
Comp 'las preguntas siguen ahi tras guardar' (@($b2.preguntas).Count -eq 3) "$(@($b2.preguntas).Count)"
Comp 'y se acuerda de la que ya hizo' (@($b2.hechas) -contains $hecha) "$(@($b2.hechas) -join ',') / hecha $hecha"
Comp 'guarda ANTES de sacar la siguiente' ((SinComentarios (Traer 'Complete-Trivia')).IndexOf('Save-BancoTrivia') -lt (SinComentarios (Traer 'Complete-Trivia')).IndexOf('Show-PreguntaTrivia')) 'al reves se guardaria la ronda ya vaciada'
Comp 'y no se marco como corrupto' (-not $script:corrupto) ''

Write-Host ''
Write-Host '-- 10. el aviso de que el banco ya esta NO habla --'
$lineasN = @($fuente -split "`r?`n")
$iN = ($lineasN | Select-String -SimpleMatch "if (`$ev.ev -eq 'banco') {" | Select-Object -First 1).LineNumber
if (-not $iN) { Write-Host '  MAL  no encuentro el lector del evento banco'; exit 1 }
$trozoN = ($lineasN[($iN - 1)..($iN + 5)] -join "`n")
Comp 'no dice nada por voz' ($trozoN -notmatch '(?m)^\s*Say ') 'llega cuando llega, sin cortar nada'
Comp 'apunta que ya no esta generando' ($trozoN -match '\$script:triviaGenerando = \$false') ''
Comp 'y tira la cache para releerlo' ($trozoN -match '\$script:triviaBanco = \$null') ''

Write-Host ''
Write-Host '-- 11. entrar: sus cuatro frases de "curioso" tambien --'
$linE = @($fuente -split "`r?`n" | Where-Object { $_ -match 'hazme una pregunta' })[0]
if (-not $linE) { Write-Host '  MAL  no encuentro el patron de entrada'; exit 1 }
$patE = [regex]::Match($linE, "'(\^[^']+)'").Groups[1].Value
foreach ($f in @('hazme una pregunta', 'preguntame algo', 'ponme a prueba', 'trivia',
                 'cuentame algo curioso', 'dime algo curioso', 'un dato curioso', 'algo curioso')) {
    Comp ("entra: `"$f`"") ($f -match $patE) ''
}
foreach ($f in @('que es un volcan', 'pon musica', 'curioso')) {
    Comp ("NO entra: `"$f`"") (-not ($f -match $patE)) 'la regla 1: nada que no haya pedido'
}

Write-Host ''
Write-Host '-- 12. el filtro del worker es el mismo que el de aqui --'
# Si el worker dejara pasar lo que PowerShell tira, el banco diria veinte y tendria doce.
$w = [System.IO.File]::ReadAllText((Join-Path $raiz 'charla_worker.py'))
Comp 'el worker exige tres opciones' ($w -match 'len\(ops\) != 3:') ''
Comp 'el worker exige buena en 1..3' ($w -match 'if b < 1 or b > 3:') ''
Comp 'el worker corta en 26 igual que el selector' ($w -match 'len\(o\) > 26 for o in ops') 'con el 26 suelto, un 2600 colaba'
Comp 'el worker no adivina la carpeta' ($w -match 'ruta = \(p\.get\("ruta"\) or ""\)') ''
Comp 'y genera en su hilo, sin pisar una charla' ($w -match 'if not ocupado\.is_set\(\):') ''
# EL ESTADO QUE SE QUEDABA PEGADO (24/09, repaso). triviaGenerando solo se bajaba al recibir
# el evento 'banco', y el worker salia SIN emitirlo por siete caminos: tras un solo fallo -y
# con un modelo de 3B, "no devolvio una lista" es lo normal- la trivia no volvia a pedir
# preguntas hasta reiniciar Nova.
# SOLO DENTRO DE generar_banco: el resto del worker usa 'info' a proposito para contar cosas
# de la charla, y ahi no hay ningun estado de PowerShell esperando.
$iG = $w.IndexOf('def generar_banco(p):')
$jG = $w.IndexOf("`ndef ", $iG + 10)
if ($iG -lt 0 -or $jG -le $iG) { Write-Host '  MAL  no encuentro generar_banco'; exit 1 }
$cuerpoG = $w.Substring($iG, $jG - $iG)
$sinAviso = @($cuerpoG -split "`n" | Where-Object { $_ -match 'salida\("info"' })
Comp 'el worker avisa SIEMPRE, aunque sea con cero' ($sinAviso.Count -eq 0) "$($sinAviso.Count) salidas mudas"
$nAvisos = @([regex]::Matches($cuerpoG, 'salida\("banco"')).Count
Comp 'y son siete caminos, no uno' ($nAvisos -ge 7) "$nAvisos avisos"
Comp 'y el de estar ocupada tambien' ($w -match 'salida\("banco", p\.get\("id"\) or 0, n=0') ''
$rq2 = SinComentarios (Traer 'Request-BancoTrivia')
Comp 'y PowerShell no se fia: le pone plazo' ($rq2 -match 'triviaGenerandoEn') 'si el aviso no llega, se desatasca solo'
# y se prueba de verdad: generando puesto y el plazo vencido -> vuelve a pedir
Limpia
$script:triviaGenerando = $true
$script:triviaGenerandoEn = $sw.ElapsedMilliseconds
Comp 'con una peticion viva, no pide otra' ((Request-BancoTrivia) -eq $false) ''
$script:triviaGenerandoEn = $sw.ElapsedMilliseconds - 180001
Comp 'pero pasados tres minutos sin respuesta, si' ((Request-BancoTrivia) -eq $true) 'antes se quedaba mudo hasta reiniciar'

try { Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  la trivia ya pregunta de verdad, baraja, y se sale de ella'
exit 0
