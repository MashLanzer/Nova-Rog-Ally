# "QUE DICE?" MIENTRAS JUEGA (23/09, idea 16).
#
# EL DATO: 31 eventos de notificacion en catorce dias y 45 mensajes; Discord es 24 eventos
# (77 %) y 38 mensajes (84 %). Lo que le llega son PERSONAS, no avisos de maquina: solo 7 en
# catorce dias. Y hoy Nova dice "tienes 3 de Discord" y no lo que ponen, o te lee cinco del
# tiron y ademas VACIA la cola.
#
# LO QUE MAS VIGILA ESTE BANCO, dos cosas y las dos son la regla 1:
#  1. que preguntar "que dice" NO vacie la cola. Si alguien escribe Get-UltimaNotificacion
#     llamando por dentro a la de leer, hereda su .Clear() y preguntar borraria todo lo que
#     quedaba por leer: con 31 eventos en catorce dias, cada mensaje perdido es el 3 % de lo
#     que le llega y no se recupera.
#  2. que el patron de contestar NO se trague "dile a maria que la llamo". Sin el (?!a\s)
#     escribiria en la ventana de quien te escribio el ultimo mensaje, que puede no ser
#     maria. Eso es escribirle a quien no toca.
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

# --- el mundo de mentira ----------------------------------------------------
$script:ahoraMs = 1000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:notifPendientes = New-Object System.Collections.ArrayList
$script:ultimaNotif = $null
$script:ultimaNotifEn = 0
$NotifVentanaMs = if ($fuente -match '(?m)^\$NotifVentanaMs = (\d+)') { [int]$Matches[1] } else { 600000 }
function Log([string]$m) { }
Invoke-Expression (Traer 'Get-UltimaNotificacion')
Invoke-Expression (Traer 'Get-LecturaNotificaciones')

function N([string]$app, [string]$titulo, [string]$texto, [string]$id = '') {
    if (-not $id) { $id = [guid]::NewGuid().ToString('N').Substring(0, 6) }
    return @{ id = $id; app = $app; titulo = $titulo; texto = $texto }
}
function Pon($lista) {
    $script:notifPendientes.Clear()
    foreach ($n in @($lista)) { [void]$script:notifPendientes.Add($n) }
    if (@($lista).Count -gt 0) { $script:ultimaNotif = @($lista)[-1] }
    $script:ultimaNotifEn = $script:ahoraMs
}

Write-Host ''
Write-Host '-- 1. sin nada, lo dice, y no revienta --'
$script:notifPendientes.Clear()
$script:ultimaNotif = $null
$r0 = Get-UltimaNotificacion $false
Comp 'devuelve una frase, no vacio' ($r0 -eq 'no tengo nada nuevo') "$r0"

Write-Host ''
Write-Host '-- 2. de tres, el ULTIMO --'
Pon @((N 'Discord' 'Ana' 'oye estas?'), (N 'Discord' 'Luis' 'te toca'), (N 'Discord' 'Mara' 'entro ya'))
$r1 = Get-UltimaNotificacion $false
Comp 'dice el ultimo' ($r1 -match 'Mara' -and $r1 -match 'entro ya') "$r1"
Comp 'con la app delante' ($r1 -match '^Discord, Mara') "$r1"

Write-Host ''
Write-Host '-- 3. LO QUE TIENE QUE CANTAR: preguntar NO vacia la cola --'
Comp 'siguen los tres pendientes' ($script:notifPendientes.Count -eq 3) "$($script:notifPendientes.Count)"
[void](Get-UltimaNotificacion $false)
[void](Get-UltimaNotificacion $false)
Comp 'ni preguntando tres veces' ($script:notifPendientes.Count -eq 3) "$($script:notifPendientes.Count)"
# y la de leer SI la vacia, que es lo suyo y no se ha tocado
[void](Get-LecturaNotificaciones)
Comp 'pero "leemelos" si la vacia, como siempre' ($script:notifPendientes.Count -eq 0) "$($script:notifPendientes.Count)"

Write-Host ''
Write-Host '-- 4. una parrafada se corta, pero por palabra entera --'
# EL TEXTO ESTA HECHO PARA QUE EL CORTE CAIGA DENTRO DE UNA PALABRA: 130 letras, un espacio
# y una palabra de 40. A los 140 caracteres estariamos a mitad de la segunda.
$largo = ('x' * 130) + ' ' + ('y' * 40)
Pon @((N 'WhatsApp' 'Mama' $largo))
$r2 = Get-UltimaNotificacion $false
Comp 'no pasa de 140 y pico' ($r2.Length -le 175) "$($r2.Length) caracteres"
Comp 'y no parte una palabra a la mitad' ($r2 -notmatch 'y') "acaba en: $($r2.Substring([Math]::Max(0,$r2.Length-12)))"
Comp 'y avisa de que hay mas' ($r2 -match '\.\.\.$') "$($r2.Substring([Math]::Max(0,$r2.Length-6)))"

Write-Host ''
Write-Host '-- 5. sin texto, el remitente y nada mas --'
Pon @((N 'Steam' 'Ana' ''))
$r3 = Get-UltimaNotificacion $false
Comp 'dice quien es' ($r3 -eq 'Steam, Ana') "$r3"
Comp 'y no deja dos puntos colgando' ($r3 -notmatch ':\s*$') "$r3"
Pon @((N 'Steam' '' ''))
$r3b = Get-UltimaNotificacion $false
Comp 'sin titulo, solo la app' ($r3b -eq 'Steam') "$r3b"

Write-Host ''
Write-Host '-- 6. varias lineas: solo la primera --'
Pon @((N 'Discord' 'Luis' "primera linea`nsegunda linea`ntercera"))
$r4 = Get-UltimaNotificacion $false
Comp 'la primera linea y ya' ($r4 -match 'primera linea' -and $r4 -notmatch 'segunda') "$r4"

Write-Host ''
Write-Host '-- 7. LA VENTANA: sin mensaje reciente, la frase no es suya --'
# "que dice" son dos palabras que pueden sonar en la habitacion. Leer mensajes privados en
# voz alta por un falso positivo seria el peor fallo posible.
$patQ = [regex]::Match($fuente, "(?m)^\s*if \(\`$f -match '(\^\(\?:que dice.+?)' -and").Groups[1].Value
if (-not $patQ) { Write-Host '  MAL  no encuentro el patron de "que dice"'; exit 1 }
$condQ = [regex]::Match($fuente, "(?ms)^\s*if \(\`$f -match '\^\(\?:que dice.+?\n(.*?)\{").Groups[1].Value
Comp 'la guarda esta en la MISMA condicion' ($condQ -match 'ultimaNotif' -and $condQ -match 'NotifVentanaMs') "$($condQ.Trim())"
$bienQ = 0
foreach ($fr in @('que dice', 'que dicen', 'que pone', 'quien es', 'leemelo', 'lee el ultimo', 'el ultimo mensaje')) {
    if ($fr -match $patQ) { $bienQ++ } else { Write-Host "       no entra: '$fr'" }
}
Comp 'las siete formas entran' ($bienQ -eq 7) "$bienQ de 7"
Comp 'pero "que me dicen" NO' ('que me dicen' -notmatch $patQ) 'demasiado corriente, y lo dice el comentario de al lado'
Comp 'y la ventana son diez minutos' ($NotifVentanaMs -eq 600000) "$NotifVentanaMs ms"

Write-Host ''
Write-Host '-- 8. CONTESTAR: su forma entra, y la peligrosa no --'
$patC = [regex]::Match($fuente, "(?m)^\s*if \(\`$text -match '(\(\?i\)\^.*?cont\[e.*?)'\) \{").Groups[1].Value
if (-not $patC) { Write-Host '  MAL  no encuentro el patron de contestar'; exit 1 }
Comp '"contesta que ahora voy" entra' ('contesta que ahora voy' -match $patC) ''
Comp 'y "contestale que ya voy" sigue entrando' ('contestale que ya voy' -match $patC) ''
Comp 'y "dile que llego tarde" tambien' ('dile que llego tarde' -match $patC) ''
Comp 'PERO "dile a maria que la llamo" NO' ('dile a maria que la llamo manana' -notmatch $patC) 'escribiria en la ventana equivocada'
# "contesta al correo" SI entra, y esta bien que entre: escribe en la ventana de quien te
# escribio, que es lo que hace desde el 13/09. Lo que no puede entrar es un destinatario
# NOMBRADO, porque ese puede no ser el de la ventana.
Comp 'y "respondele que voy" sigue entrando' ('respondele que voy' -match $patC) ''
Comp 'pero "escribele a luis que llego" NO' ('escribele a luis que llego' -notmatch $patC) 
$cuerpoC = [regex]::Match($fuente, "(?ms)^\s*if \(\`$text -match '\(\?i\)\^.*?cont\[e.*?\n(.*?)\n    \}").Groups[1].Value
Comp 'y sigue sin enviar: ni un Enter' ($cuerpoC -notmatch '\{ENTER\}' -and $cuerpoC -match 'sin enviar') 'nunca se manda solo'
Comp 'y lleva la misma ventana de diez minutos' ($cuerpoC -match 'NotifVentanaMs') 'contestar a un mensaje de ayer es escribirle a quien no toca'

Write-Host ''
Write-Host '-- 9. y no se llama por dentro a la que vacia --'
$gu = SinComentarios (Traer 'Get-UltimaNotificacion')
Comp 'Get-UltimaNotificacion no llama a la de leer' ($gu -notmatch 'Get-LecturaNotificaciones') 'heredaria su Clear()'
Comp 'ni vacia la cola por su cuenta' ($gu -notmatch '\.Clear\(\)') ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya te dice quien es y que pone, sin borrar el resto'
exit 0
