# ELEGIR CON EL MANDO (23/09, funcion 10 de la tanda de funciones nuevas).
#
# EL DATO QUE LO PIDE: en catorce dias el mando se uso para contestar una pregunta CERO veces.
# Y no es que no haya preguntas -hubo VEINTE- ni que no haya mando: es una consola de mano,
# XInput lo ve en el puerto 0 y leerlo cuesta 0,197 ms (medido hoy). CINCO de esas veinte
# murieron por plazo -una de cada cuatro-, y una era "abre Hollow Knight en steam", que ya
# venia de un oido dudoso. El atajo existia desde el 13/09 y era invisible.
# (Las 40 lineas de "CONFIRMAR" del log son DOS por pregunta: 12 normales + 8 de traduccion
#  = 20. Desenlaces: 7 si, 5 no, 5 por plazo, 2 ejecutadas al vencer, 1 cancelada.)
#
# Lo que se prueba aqui:
#   1. QUE SE VEA. Con una pregunta esperando, la capsula tiene que decir que A y B valen; con
#      un juego delante, que hace falta ≡+A; y en una pregunta peligrosa, que A NO vale (esa
#      regla es del 13/09 y no se toca).
#   2. QUE SEA UNA SEGUNDA PUERTA, NUNCA LA UNICA. Sin mando no se abre nada y la voz de
#      siempre sigue siendo el camino. Esto es lo mas importante del banco.
#   3. QUE TENGA SALIDA. Es un modo, y en esta casa un modo del que no se sabe salir es el
#      peor fallo posible: A elige, B cancela, la voz sigue valiendo y hay un plazo que lo
#      cierra solo.
#   4. Que la cruceta de la vuelta de verdad, y que no se pise con el panel rapido ni con una
#      pregunta de si/no.
$ErrorActionPreference = 'Stop'
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
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
function TraerVar([string]$n) {
    $a = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $x.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $x.Left.VariablePath.UserPath -eq $n }, $true)
    if (-not $a) { Write-Host "  MAL  no encuentro `$$n"; exit 1 }
    return $a.Extent.Text
}
# EL TROZO DEL BUCLE SE SACA DEL FICHERO Y SE EJECUTA. No es una funcion -vive dentro del
# while- asi que se corta por sus dos comentarios. Copiarlo aqui seria probar la copia.
$i1 = $fuente.IndexOf('    # ELIGIENDO DE UNA LISTA (23/09, funcion 10)')
$i2 = $fuente.IndexOf('    # DOBLE TOQUE en ', $i1)
$trozoBucle = if ($i1 -ge 0 -and $i2 -gt $i1) { $fuente.Substring($i1, $i2 - $i1) } else { '' }

# --- el andamio: lo minimo para que el selector viva, y nada mas ---------------
$script:uiEstado = ''; $script:uiTexto = ''; $script:uiMs = 0
$script:vibro = @(); $script:dicho = @(); $script:logs = @()
$script:confirmaFin = 0; $script:confirmaTotal = 0
$script:panel = $null; $script:pendiente = $null; $script:busy = $false
$script:juegoActivo = $false
$script:relojFalso = 0
function Log([string]$m) { $script:logs += $m }
function Set-UI([string]$estado, [string]$texto = '', [int]$ms = 0) {
    $script:uiEstado = $estado; $script:uiTexto = $texto; $script:uiMs = $ms
}
function Start-Vibracion($p, $f = 0) { $script:vibro += 1 }
function Say([string]$t, [string]$e = '') { $script:dicho += $t }
function Invoke-AjedrezPy([string[]]$a) { return @{ decir = ('jugada ' + ($a -join ' ')) } }
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojFalso }
foreach ($v in @('EleccionMs', 'XINPUT_ARR', 'XINPUT_ABA', 'XINPUT_IZQ', 'XINPUT_DER',
                 'XINPUT_A', 'XINPUT_B', 'XINPUT_START', 'TRIGGER')) { Invoke-Expression (TraerVar $v) }
$XINPUT_LB = 0x0100        # un boton que el selector NO consume, para el caso del plazo
# LAS DOS GUARDAS DEL MANDO SE TRAEN DEL FICHERO, no se copian: son exactamente lo que
# faltaba en el selector y lo que este banco no probaba. Se evaluan en cada vuelta, igual
# que en el bucle de verdad.
$txtConMenu = TraerVar 'conMenu'
$txtMandoVale = TraerVar 'mandoVale'
$script:pausaHasta = 0
$script:uiHasta = 0
foreach ($f in @('Show-Eleccion', 'Open-Eleccion', 'Close-Eleccion', 'Complete-Eleccion',
                 'Get-PistaMando')) { Invoke-Expression (Traer $f) }
$script:eleccion = $null; $script:mandoHay = $false
# una vuelta del bucle con estos botones recien pulsados. $botones son los que estan
# APRETADOS en esta vuelta (para $conMenu) y $pulsados los que acaban de bajar.
function Vuelta([int]$pulsados = 0, [int]$avanzaMs = 0, [int]$botones = -1) {
    $script:relojFalso += $avanzaMs
    if ($botones -lt 0) { $botones = $pulsados }
    Invoke-Expression $txtConMenu
    Invoke-Expression $txtMandoVale
    Invoke-Expression $trozoBucle
}

Write-Host ''
Write-Host '-- el trozo del bucle se lee del fichero, no se copia --'
Comp 'el bloque del selector se encuentra' ($trozoBucle.Length -gt 300) "$($trozoBucle.Length) caracteres"

Write-Host ''
Write-Host '-- SIN MANDO NO PASA NADA: la voz sigue siendo el camino --'
$script:mandoHay = $false
$abrio = Open-Eleccion @('torre alfa seis', 'torre alfa siete') 'ajedrez'
Comp 'no se abre nada sin mando' (-not $abrio -and -not $script:eleccion) 'y quien llama sigue con la voz'
Comp 'y la capsula no se toca' ($script:uiEstado -eq '')
Comp 'la pista tampoco se pone' ((Get-PistaMando '') -eq '') 'sin mando no se anuncia un mando'

Write-Host ''
Write-Host '-- la pista, que es la mitad de esta funcion --'
$script:mandoHay = $true
$script:juegoActivo = $false
$p1 = Get-PistaMando ''
Comp 'fuera del juego: A y B solos' (($p1 -match 'A si') -and ($p1 -match 'B no') -and ($p1 -notmatch [string][char]0x2261)) $p1.Trim()
$script:juegoActivo = $true
$p2 = Get-PistaMando ''
Comp 'con un juego delante: hace falta el menu' (($p2 -match ([string][char]0x2261) + '\+A') -and ($p2 -match ([string][char]0x2261) + '\+B')) $p2.Trim()
$script:juegoActivo = $false
$p3 = Get-PistaMando 'peligrosa'
Comp 'en una peligrosa, A no se ofrece' (($p3 -notmatch 'A si') -and ($p3 -match 'B no')) $p3.Trim()
# y la regla de verdad, la del 13/09, sigue en el codigo. Esto es lo unico que se puede
# mirar por texto: ese camino es el de la pregunta de si/no, que este banco no monta.
# La regla del ≡ EN EL SELECTOR se prueba ejecutandolo, mas abajo.
Comp 'y el codigo sigue sin dejar que A confirme una peligrosa' `
    ($fuente -match "elseif \(\`$script:pendiente\.tipo -eq 'peligrosa'\)") 'A pide un si hablado'
# la pista se pega a la pregunta cuando la capsula pasa a confirmando
Comp 'la pista se pega a la pregunta' `
    ($fuente -match "Set-UI 'confirmando' \(\`$script:uiTexto \+ \(Get-PistaMando")

Write-Host ''
Write-Host '-- y cuando hay mando, la lista se puede resolver con la cruceta --'
$script:mandoHay = $true
$script:relojFalso = 0
$abrio = Open-Eleccion @('torre alfa seis', 'torre alfa siete') 'ajedrez'
Comp 'se abre' ($abrio -and $null -ne $script:eleccion)
Comp 'empieza por la primera' ($script:eleccion.i -eq 0) $script:uiTexto
Comp 'y se ve cual es y cuantas hay' (($script:uiTexto -match 'torre alfa seis') -and ($script:uiTexto -match '1/2')) $script:uiTexto
Comp 'el anillo cuenta ESTE plazo' ($script:confirmaTotal -eq $EleccionMs) "$($script:confirmaTotal) ms"
Vuelta $XINPUT_DER
Comp 'la cruceta a la derecha pasa a la segunda' ($script:eleccion.i -eq 1) $script:uiTexto
Vuelta $XINPUT_DER
Comp 'y da la vuelta al llegar al final' ($script:eleccion.i -eq 0) 'dos opciones, vuelve a la primera'
Vuelta $XINPUT_IZQ
Comp 'y a la izquierda tambien' ($script:eleccion.i -eq 1)
$antes = $script:dicho.Count
Vuelta $XINPUT_A
Comp 'A elige la que estaba marcada' ($null -eq $script:eleccion) 'y cierra el selector'
Comp 'y se hace la jugada 2' (($script:dicho.Count -gt $antes) -and ($script:dicho[-1] -match '--elegir 2')) $script:dicho[-1]

Write-Host ''
Write-Host '-- las tres salidas (es un modo, y aqui eso se paga) --'
# 1) B
$script:relojFalso = 0
[void](Open-Eleccion @('uno', 'dos') 'ajedrez')
Vuelta $XINPUT_B
Comp 'B lo cierra' ($null -eq $script:eleccion)
Comp 'y sin hacer nada' ($script:logs[-1] -match 'cancelado con B') $script:logs[-1]
# 2) el plazo
$script:relojFalso = 0
[void](Open-Eleccion @('uno', 'dos') 'ajedrez')
Vuelta 0 ($EleccionMs - 100)
Comp 'antes del plazo sigue abierto' ($null -ne $script:eleccion) "a los $($EleccionMs - 100) ms"
Vuelta 0 200
Comp 'y al vencer se cierra solo' ($null -eq $script:eleccion) "a los $($EleccionMs + 100) ms"
Comp 'y el anillo se apaga' ($script:confirmaFin -eq 0)
# 3) la voz
Comp 'la voz de siempre sigue contestando' ($fuente -match "primera\|primero\|el\\\\s\+primero\|uno\)\\\$' \) \{ Close-Eleccion" -or
    $fuente -match "Close-Eleccion \`$false; \`$r = Invoke-AjedrezPy @\('--elegir', '1'\)") 'y cierra el selector al hacerlo'

Write-Host ''
Write-Host '-- CON UN JUEGO DELANTE, A A PELO NO VALE (esto era el fallo grave) --'
# Nacio sin la guarda y era lo peor de la tanda: con un juego delante A es el boton que
# mas se pulsa -saltar-, asi que saltando en Hollow Knight se hacia una jugada de ajedrez
# que braya no habia elegido. Y el banco lo tapaba: dejaba $juegoActivo en $false para
# TODAS las vueltas, asi que probaba justo el caso que no importa.
$script:juegoActivo = 'Hollow Knight'
$script:relojFalso = 0
[void](Open-Eleccion @('torre alfa seis', 'torre alfa siete') 'ajedrez')
$antes = $script:dicho.Count
Vuelta $XINPUT_A
Comp 'A a pelo no elige nada' (($null -ne $script:eleccion) -and ($script:dicho.Count -eq $antes)) 'sigue abierto y no se ha jugado'
Vuelta $XINPUT_DER
Comp 'y la cruceta a pelo tampoco mueve' ($script:eleccion.i -eq 0)
# con el menu apretado si
Vuelta ($XINPUT_DER -bor $TRIGGER) 0 ($XINPUT_DER -bor $TRIGGER)
Comp 'con el menu apretado, la cruceta si mueve' ($script:eleccion.i -eq 1)
Vuelta ($XINPUT_A -bor $TRIGGER) 0 ($XINPUT_A -bor $TRIGGER)
Comp 'y el menu mas A si elige' (($null -eq $script:eleccion) -and ($script:dicho.Count -gt $antes)) $(if ($script:dicho.Count -gt $antes) { $script:dicho[-1] } else { '' })

Write-Host ''
Write-Host '-- ni mientras Nova esta hablando la pregunta --'
# La otra mitad de $mandoVale: un boton pulsado MIENTRAS suena la pregunta no es una
# respuesta. Es la misma regla que lleva la pregunta de si/no desde el 13/09.
$script:juegoActivo = $false
$script:relojFalso = 1000
[void](Open-Eleccion @('uno', 'dos') 'ajedrez')
$script:pausaHasta = 3000          # la voz aun suena
$antes = $script:dicho.Count
Vuelta $XINPUT_A
Comp 'con la voz sonando, A no elige' (($null -ne $script:eleccion) -and ($script:dicho.Count -eq $antes))
$script:pausaHasta = 0             # ya callo
Vuelta $XINPUT_A
Comp 'y en cuanto calla, si' ($null -eq $script:eleccion)

Write-Host ''
Write-Host '-- el plazo no se renueva con un boton que no es suyo --'
# Estaba en el if de fuera, asi que jugando -donde llueven botones- el plazo no vencia
# NUNCA y la lista se quedaba puesta para siempre. Un modo sin plazo es un modo sin salida.
$script:relojFalso = 0
[void](Open-Eleccion @('uno', 'dos') 'ajedrez')
Vuelta $XINPUT_LB 10000
Comp 'LB no lo consume nadie' ($null -ne $script:eleccion) 'a los 10 s'
Vuelta $XINPUT_LB 6000
Comp 'y aun asi vence a los 15' ($null -eq $script:eleccion) 'a los 16 s, con LB pulsado dos veces'

Write-Host ''
Write-Host '-- la capsula ensena la lista aunque la voz la pise --'
# Open-Eleccion pinta y un instante despues Say pone 'hablando': el selector se quedaba
# abierto 15 s SIN NADA EN PANTALLA, y el manual del ajedrez promete que se ve.
$script:relojFalso = 0
[void](Open-Eleccion @('torre alfa seis', 'torre alfa siete') 'ajedrez')
Set-UI 'hablando' 'torre alfa seis o torre alfa siete'   # lo que hace Say justo despues
$script:uiHasta = 2000
Vuelta 0 1000
Comp 'mientras habla, no la pisa' ($script:uiEstado -eq 'hablando') $script:uiTexto
Vuelta 0 2000
Comp 'y al callar vuelve a ensenarla' (($script:uiEstado -eq 'confirmando') -and ($script:uiTexto -match 'torre alfa seis')) $script:uiTexto
$script:uiHasta = 0

Write-Host ''
Write-Host '-- y al cerrarse no le borra el anillo a una pregunta recien nacida --'
$script:relojFalso = 0
[void](Open-Eleccion @('uno', 'dos') 'ajedrez')
$script:pendiente = @{ tipo = '' }
$script:confirmaFin = 999999; $script:confirmaTotal = 8000    # la pregunta de si/no
Vuelta 0
Comp 'el selector se aparta' ($null -eq $script:eleccion)
Comp 'pero el anillo de la pregunta sigue' (($script:confirmaFin -eq 999999) -and ($script:confirmaTotal -eq 8000)) 'el camino normal es justo este'
$script:pendiente = $null; $script:confirmaFin = 0; $script:confirmaTotal = 0

Write-Host ''
Write-Host '-- no se pisa con lo que ya habia --'
$script:relojFalso = 0
[void](Open-Eleccion @('uno', 'dos') 'ajedrez')
$script:pendiente = @{ tipo = '' }
Vuelta 0
Comp 'una pregunta de si/no manda mas' ($null -eq $script:eleccion) 'el selector se aparta'
$script:pendiente = $null
$script:panel = @{ i = 0 }
Comp 'con el panel abierto no se abre' (-not (Open-Eleccion @('uno', 'dos') 'ajedrez'))
$script:panel = $null
$script:pendiente = @{ tipo = '' }
Comp 'con una pregunta esperando tampoco' (-not (Open-Eleccion @('uno', 'dos') 'ajedrez'))
$script:pendiente = $null
Comp 'con una lista de una sola cosa, no' (-not (Open-Eleccion @('uno') 'ajedrez')) 'no hay nada que elegir'
Comp 'ni con siete' (-not (Open-Eleccion @('1', '2', '3', '4', '5', '6', '7') 'ajedrez')) 'eso ya no se lee de un vistazo'

Write-Host ''
Write-Host '-- y el ajedrez lo usa cuando pregunta entre dos --'
Comp 'el puente abre el selector con las opciones' `
    ($fuente -match "if \(\`$r\.opciones -and @\(\`$r\.opciones\)\.Count -ge 2\)") 'las que da python-chess'
Comp 'pero devuelve la frase igual' ($fuente -match "\[void\]\(Open-Eleccion @\(\`$r\.opciones\) 'ajedrez'\)[\s\S]{0,80}return \[string\]\`$r\.decir") 'el selector no sustituye a la voz'

Write-Host ''
Write-Host '-- y no habla por su cuenta --'
$oe = Traer 'Open-Eleccion'
$se = Traer 'Show-Eleccion'
Comp 'abrir la lista no dice nada en voz alta' (($oe -notmatch '\bSay\b') -and ($se -notmatch '\bSay\b')) 'solo se ve'
Comp 'pero vibra, que se nota con el juego delante' ($oe -match 'Start-Vibracion')
Comp 'y se apunta en el log' ($oe -match 'Log \(')

Write-Host ''
Write-Host '-- y "hay mando" no se da por supuesto --'
Comp 'se marca solo si XInput contesta que si' `
    ($fuente -match "if \(\`$r -eq 0\) \{ \`$botones = \`$botones -bor \[int\]\`$state\.Gamepad\.wButtons; \`$script:mandoHay = \`$true \}") 'codigo 0 = conectado'

Write-Host ''
if ($fallos) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  se puede elegir con el mando, y sin mando todo sigue igual'
exit 0
