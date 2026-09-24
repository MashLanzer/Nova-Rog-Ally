# LA LUPA (23/09, funcion 8 de la tanda de funciones nuevas).
#
# De donde sale: braya juega en una pantalla de 7 pulgadas a 1080p, y ahi la letra de un menu
# mide un milimetro. Lo que habia para eso era el OCR, y el OCR en un juego no sirve: la unica
# lectura de pantalla de juego que hay en todo el registro devolvio cinco trozos, y dos eran
# basura ("O", "Kit"). Ademas el 20/09 braya lo dijo con todas las letras: "no describas lo que
# ves en la pantalla literalmente". Asi que la lupa no LEE nada: ENSENA el trozo ampliado y se
# calla. Nova no puede equivocarse diciendo un texto que no dice.
#
# Lo que se prueba aqui son las cuatro cosas que pueden fallarle a braya:
#   1. Que la frase natural entre. La que se dice de verdad es "ampliame la esquina de arriba
#      a la derecha", en ese orden; el primer intento solo cogia "la derecha de arriba" y la
#      frase normal no llegaba a ningun sitio.
#   2. Que no se pise con leer. Las dos ordenes se diferencian SOLO en el verbo.
#   3. Que amplie de verdad. El primer intento escalaba "lo que cupiera en el 70 % de la
#      pantalla", y eso daba x1,17 con cualquier resolucion (el centro es el 60 % de la
#      ventana y el techo era el 70 % de la pantalla: 0,70/0,60). Medido hoy en esta
#      consola: escritorio 1280x720 sobre un panel de 15 x 9 cm = 0,117 mm por pixel, o
#      sea que una letra de 12 px mide 1,4 mm. A x1,17 sigue siendo la misma letra.
#   4. Que no robe el foco ni se quede puesta. braya esta jugando con el mando en las manos.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$lineas = [System.IO.File]::ReadAllLines($ruta)
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# SIN COMENTARIOS, SIEMPRE. Este banco salia verde con la linea de NearestNeighbor
# BORRADA, porque la palabra seguia estando en el comentario de encima. Un banco que
# lee comentarios no prueba nada: prueba que alguien escribio la palabra.
function SinComentarios([string]$txt) {
    return (($txt -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
}
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre"; exit 1 }
    return $fn.Extent.Text
}
function TraerCodigo([string]$nombre) { return (SinComentarios (Traer $nombre)) }
function TraerVarTxt([string]$nombre) {
    $a = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $n.Left.VariablePath.UserPath -eq $nombre }, $true)
    if (-not $a) { Write-Host "  MAL  no encuentro `$$nombre"; exit 1 }
    return $a.Extent.Text
}
$codigoTodo = SinComentarios $fuente
# EL PATRON SE LEE DE SU LINEA, NO SE COPIA AQUI. Copiarlo seria probar la copia: ya paso
# tres veces en este repo, y la ultima el banco estaba verde mientras el patron real cogia 0
# de 11 frases suyas.
function PatronDe([int]$n) {          # $n = numero de linea, 1-based
    $l = $lineas[$n - 1]
    $a = $l.IndexOf("-match '")
    if ($a -lt 0) { return '' }
    $a += 8
    $b = $l.LastIndexOf("')")
    if ($b -le $a) { return '' }
    return $l.Substring($a, $b - $a)
}
# las lineas de los patrones, buscadas por lo que hacen (no por su numero, que se mueve)
$nLupa = @(); $nLee = @()
for ($i = 0; $i -lt $lineas.Count; $i++) {
    $l = $lineas[$i]
    if ($l -notmatch '^\s*if \(\$f -match') { continue }
    if ($l -match 'ampliame\|amplia') { $nLupa += ($i + 1) }
    elseif ($l -match '\^\(\?:lee\|leeme') { $nLee += ($i + 1) }
}

Write-Host ''
Write-Host '-- los cuatro patrones estan y se pueden leer --'
Comp 'hay cuatro patrones de lupa' ($nLupa.Count -eq 4) ("lineas: " + ($nLupa -join ', '))
$pats = @($nLupa | ForEach-Object { PatronDe $_ })
Comp 'los cuatro se leen enteros' (@($pats | Where-Object { $_.Length -gt 40 }).Count -eq 4)

Write-Host ''
Write-Host '-- la frase que se dice de verdad, en el orden en que se dice --'
# EL IF ENTERO SE SACA DEL ARBOL Y SE EJECUTA: patron Y cuerpo. Antes se leia el patron
# del fichero (bien) y luego el banco reconstruia la zona por su cuenta (mal): cambiando
# $lzV1 por $lzH1 en el codigo, 'la esquina de arriba a la derecha' ampliaria abajo a la
# izquierda y este banco seguia diciendo 13 de 13.
$ifs = @()
foreach ($x in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
    if ($x.Clauses[0].Item1.Extent.Text -match 'ampliame') { $ifs += $x.Extent.Text }
}
Comp 'los cuatro ifs se sacan del arbol' ($ifs.Count -eq 4) "$($ifs.Count) bloques"
# La esquina en espanol va "de arriba a la derecha". El orden al reves ("la derecha de
# arriba") tambien vale, pero no es el que sale de la boca.
$suyas = @(
    @('ampliame la esquina de arriba a la derecha',  'arriba-derecha'),
    @('ampliame la esquina de abajo a la izquierda', 'abajo-izquierda'),
    @('amplia arriba a la derecha',                  'arriba-derecha'),
    @('ensename la esquina de arriba a la izquierda','arriba-izquierda'),
    @('muestrame abajo a la derecha',                'abajo-derecha'),
    @('ampliame la derecha de arriba',               'arriba-derecha'),
    @('ampliame arriba',                             'arriba'),
    @('amplia la parte de abajo',                    'abajo'),
    @('ampliame la izquierda',                       'izquierda'),
    @('hazme zoom en la derecha',                    'derecha'),
    @('ampliame el centro',                          'centro'),
    @('agranda el texto del centro',                 'centro'),
    @('acercame el cartel del centro',               'centro')
)
$cogidas = 0
foreach ($par in $suyas) {
    $frase = $par[0]; $esperada = $par[1]
    $cual = ''
    foreach ($bloque in $ifs) {
        # se ejecuta el if de verdad, con $f puesta: si casa, su cuerpo devuelve la accion
        # CON @() DELANTE: el if devuelve un array de UN elemento y PowerShell lo aplana a
        # hashtable; entonces $acc[0] es 'la clave 0' de esa tabla, que no existe, y salia
        # vacio con el codigo bien. Trece 'no la coge' por un parentesis.
        $acc = @(& { $f = $frase; Invoke-Expression $bloque })
        if ($acc) { $cual = [string]$acc[0].zona; break }
    }
    $ok = ($cual -eq $esperada)
    if ($ok) { $cogidas++ }
    Write-Host ("       {0} {1,-46} {2}" -f $(if ($ok) { 'SI ' } else { 'no ' }), $frase, $(if ($cual) { $cual } else { '(no la coge)' }))
}
Comp 'las coge todas y en la zona que toca' ($cogidas -eq $suyas.Count) "$cogidas de $($suyas.Count)"

Write-Host '-- ampliar y leer no se pisan: solo las separa el verbo --'
Comp 'la lupa va DELANTE de leer' ($nLupa[0] -lt $nLee[0]) "lupa en $($nLupa[0]), leer en $($nLee[0])"
$patsLee = @($nLee | ForEach-Object { PatronDe $_ })
foreach ($f in @('ampliame la esquina de arriba a la derecha', 'ampliame el centro', 'amplia la izquierda')) {
    $tocaLee = @($patsLee | Where-Object { $f -match $_ }).Count
    Comp "'$($f.Substring(0,[Math]::Min(34,$f.Length)))' no cae en leer" ($tocaLee -eq 0)
}
foreach ($f in @('lee la esquina de arriba a la derecha', 'que dice arriba', 'leeme el centro')) {
    $tocaLupa = @($pats | Where-Object { $f -match $_ }).Count
    Comp "'$($f.Substring(0,[Math]::Min(34,$f.Length)))' no cae en la lupa" ($tocaLupa -eq 0)
}

Write-Host ''
Write-Host '-- y una orden normal no se convierte en lupa --'
# Del registro de braya, tal y como las oyo Nova.
foreach ($f in @('sube el volumen', 'abre steam', 'que hora es', 'pon el modo juego',
                 'ensename el escritorio', 'muestrame el tiempo')) {
    $toca = @($pats | Where-Object { $f -match $_ }).Count
    Comp "'$($f.Substring(0,[Math]::Min(34,$f.Length)))' sigue su camino" ($toca -eq 0)
}

Write-Host ''
Write-Host '-- las zonas que saca son zonas que Get-ZonaRect entiende --'
Invoke-Expression (Traer 'Get-ZonaRect')
foreach ($z in @('arriba', 'abajo', 'izquierda', 'derecha', 'centro',
                 'arriba-derecha', 'arriba-izquierda', 'abajo-derecha', 'abajo-izquierda')) {
    $r = Get-ZonaRect 0 0 1920 1080 $z
    $recorta = ($r.w -lt 1920 -or $r.h -lt 1080)
    Comp "'$z' recorta algo" $recorta "$($r.w)x$($r.h) en $($r.x),$($r.y)"
}

Write-Host ''
Write-Host '-- AMPLIA DE VERDAD (esto es lo que fallaba) --'
$sl = TraerCodigo 'Show-Lupa'
# EL ESCALADO VIVE EN Draw-Lupa DESDE LA IDEA 15: Show-Lupa monta la ventana y Draw-Lupa
# pinta la imagen. Estas tres comprobaciones miraban Show-Lupa y se pusieron rojas solas al
# partir la funcion, con el codigo bien.
$sd = TraerCodigo 'Draw-Lupa'
Comp 'el aumento arranca en x2' ($sd -match 'lupaEsc = 2\.0' -or $sl -match 'lupaEsc = 2\.0') 'y sube a x3 y x4 con el hombro'
Comp 'y lo que no cabe se recorta, no se encoge' ($sd -match 'GraphicsUnit\]::Pixel') 'DrawImage con rectangulo de origen'
# la cuenta, con LOS NUMEROS DE ESTA CONSOLA (medidos hoy): el escritorio va a 1280x720
$origW = [int](1280 * 0.6); $origH = [int](720 * 0.6)      # lo que da Get-ZonaRect al centro
$vMaxW = [int](1280 * 0.70); $vMaxH = [int](720 * 0.70)    # el techo de la version vieja
$antes = [Math]::Min($vMaxW / [double]$origW, $vMaxH / [double]$origH)
Comp 'la cuenta vieja no ampliaba' ($antes -lt 1.25) ("x{0:N2} con el centro de la pantalla" -f $antes)
# ANTES AQUI PONIA ($true) A SECAS (24/09, repaso): no podia ponerse roja nunca, y es justo la
# que vigila que la lupa amplie de verdad. Ahora se hace la cuenta NUEVA con los numeros del
# codigo: la ventana crece x$esc y el trozo del original que se ve se divide por $esc, asi que
# el aumento en pantalla es exactamente $esc. Si alguien lo pone a 1, esto canta.
$mEsc = [regex]::Match($sd + $sl, 'lupaEsc = ([0-9.]+)')
$esc = if ($mEsc.Success) { [double]$mEsc.Groups[1].Value } else { 0 }
$nw = [Math]::Min(($origW * $esc), $vMaxW)
$sw2 = [Math]::Min($origW, [Math]::Ceiling($nw / [Math]::Max(1, $esc)))
$ahora = if ($sw2 -gt 0) { $nw / $sw2 } else { 0 }
Comp 'la nueva si' ($ahora -ge 2) ("x{0:N2} con el trozo recortado" -f $ahora)
Comp 'la letra pequena no se emborrona' ($sd -match 'NearestNeighbor') 'nada de bilineal'

Write-Host ''
Write-Host '-- no roba el foco, que braya esta jugando --'
Comp 'usa la Form que no activa (AXTarjeta)' ($sl -match 'New-Object AXTarjeta')
Comp 'y la ensena con SW_SHOWNA, no con Show()' ($sl -match 'ShowWindow\(\$f\.Handle, 8\)')
Comp 'nunca llama a Show() ni a Activate()' ($sl -notmatch '\$f\.Show\(\)' -and $sl -notmatch 'Activate\(\)')
Comp 'ni sale en la barra de tareas' ($sl -match 'ShowInTaskbar = \$false')

Write-Host ''
Write-Host '-- y se quita sola, por las tres puertas --'
$cl = TraerCodigo 'Close-Lupa'
Comp 'el plazo se apunta al ensenarla' ($sl -match 'lupaUntil = \$sw\.ElapsedMilliseconds')
Comp 'el bucle la quita al vencer' ($codigoTodo -match 'lupaUntil -gt 0 -and \$sw\.ElapsedMilliseconds -ge \$script:lupaUntil') 'sin tocar nada'
Comp '"quita la lupa" la quita' ($codigoTodo -match "kind = 'lupaQuita'")
Comp 'y "quitala" tambien' ($codigoTodo -match '\$habia = \(\$script:popupForm -or \$script:lupaForm\)') 'la misma palabra que para la tarjeta'
Comp 'al cerrarla suelta el Bitmap' ($cl -match '\$script:lupaImg\.Dispose\(\)') '~3 MB por lupa en un proceso de meses'
Comp 'y el Form' ($cl -match '\$script:lupaForm\.Dispose\(\)')

Write-Host ''
Write-Host '-- el plazo de 12 s son 12 s (esto no lo era) --'
# Nacio dentro de Watch-Entorno, que sale de su cuerpo con un "si no han pasado 30 s,
# vuelve": los 12 s prometidos eran hasta 42, con una ventana que tapa el 92 % de la
# pantalla. Ahora vive en el bucle, que duerme 30 ms, junto al cierre de la tarjeta.
$iL = $codigoTodo.IndexOf('$script:lupaUntil) { Close-Lupa }')
$iW = $codigoTodo.IndexOf('function Watch-Entorno')
$iF = $codigoTodo.IndexOf('$script:popupUntil -gt 0')
Comp 'el cierre por plazo se encuentra' ($iL -gt 0)
Comp 'y NO esta dentro de Watch-Entorno' ($iL -gt $iW + 60000) 'esa funcion sale sola cada 30 s'
Comp 'sino pegado al cierre de la tarjeta' ([Math]::Abs($iL - $iF) -lt 2500) 'el bucle duerme 30 ms'

Write-Host '-- y la captura no se saca una foto de la lupa --'
# CopyFromScreen copia lo que hay encima, y la lupa es una ventana siempre encima: con la
# lupa puesta el OCR leia el trozo YA ampliado y la vision describia la lupa.
$sc = TraerCodigo 'Save-Captura'
Comp 'Save-Captura la esconde antes' ($sc -match 'ShowWindow\(\$lupaTapa, 0\)') 'SW_HIDE'
Comp 'y la vuelve a poner en un finally' (($sc -match 'finally') -and ($sc -match 'ShowWindow\(\$lupaTapa, 8\)')) 'braya la estaba mirando'

Write-Host '-- y sus verbos trocean una frase de dos ordenes --'
# Sin esto, medido con el parser real: 'sube el volumen y quita la lupa' subia el volumen
# Y NADA MAS, en silencio. Y la frase la ensena la propia Nova.
$verbos = TraerVarTxt 'VERBOS'
foreach ($v in @('ampliame', 'amplialo', 'acercame', 'agrandame', 'quitala', 'quita')) {
    Comp "'$v' esta en los verbos que cortan" ($verbos -match ('\|' + $v + '[\|\)]'))
}
Comp 'y las formas largas van antes que las cortas' `
    ($verbos.IndexOf('|quitale') -lt $verbos.IndexOf('|quita)') -or $verbos -match '\|quitale\|') `
    'con quita delante se perdia "quitale el siempre encima"'
Write-Host ''
Write-Host '-- Y SE PUEDE MOVER, que la captura ya esta hecha (idea 15) --'
# La lupa amplia x2 un trozo FIJO. Si lo que braya quiere leer esta al lado, antes habia
# que pedir otra zona entera y capturar de nuevo. La captura ya esta en el disco: moverse
# por ella es un DrawImage, no una foto.
# EL TROZO DEL BUCLE SE SACA DEL FICHERO Y SE EJECUTA, igual que en probar-elegir-mando:
# no es una funcion, vive dentro del while.
$m1 = $fuente.IndexOf('    # MOVIENDO LA LUPA (23/09, idea 15)')
$m2 = $fuente.IndexOf('    # ELIGIENDO DE UNA LISTA', $m1)
$trozoLupa = if ($m1 -ge 0 -and $m2 -gt $m1) { $fuente.Substring($m1, $m2 - $m1) } else { '' }
Comp 'el bloque de mover se encuentra' ($trozoLupa.Length -gt 300) "$($trozoLupa.Length) caracteres"

# el andamio: lo minimo para que ese trozo viva
$script:logs = @()
function Log([string]$m) { $script:logs += $m }
$script:relojL = 0
$swL = [pscustomobject]@{}
$swL | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojL }
$sw = $swL
$script:dibujos = 0
function Update-Lupa { $script:dibujos++; return $true }
function Close-Lupa { $script:lupaForm = $null }
$script:eleccion = $null; $script:panel = $null; $script:pendiente = $null
$script:juegoActivo = $false; $script:pausaHasta = 0
$script:lupaForm = 'una ventana'; $script:lupaNW = 900; $script:lupaNH = 600
$script:lupaDx = 0; $script:lupaDy = 0; $script:lupaEsc = 2.0
foreach ($v in @('LupaMs', 'LupaEscalas', 'XINPUT_ARR', 'XINPUT_ABA', 'XINPUT_IZQ',
                 'XINPUT_DER', 'XINPUT_A', 'XINPUT_B', 'XINPUT_LB', 'XINPUT_RB',
                 'XINPUT_START', 'TRIGGER')) { Invoke-Expression (TraerVarTxt $v) }
$txtConMenuL = TraerVarTxt 'conMenu'
$txtMandoValeL = TraerVarTxt 'mandoVale'
function VueltaL([int]$pulsados = 0, [int]$avanzaMs = 0, [int]$botones = -1) {
    $script:relojL += $avanzaMs
    if ($botones -lt 0) { $botones = $pulsados }
    Invoke-Expression $txtConMenuL
    Invoke-Expression $txtMandoValeL
    Invoke-Expression $trozoLupa
}

VueltaL $XINPUT_DER
Comp 'la cruceta a la derecha corre el trozo' ($script:lupaDx -gt 0) "dx=$($script:lupaDx)"
$antesDx = $script:lupaDx
VueltaL $XINPUT_IZQ
Comp 'y a la izquierda vuelve' ($script:lupaDx -lt $antesDx) "dx=$($script:lupaDx)"
VueltaL $XINPUT_ABA
Comp 'abajo tambien' ($script:lupaDy -gt 0) "dy=$($script:lupaDy)"
VueltaL $XINPUT_ARR
Comp 'y arriba' ($script:lupaDy -le 0) "dy=$($script:lupaDy)"
Comp 'y cada movimiento redibuja' ($script:dibujos -eq 4) "$($script:dibujos) dibujos"

$script:lupaEsc = 2.0
VueltaL $XINPUT_RB
Comp 'el hombro derecho amplia mas' ($script:lupaEsc -eq 3.0) "x$($script:lupaEsc)"
VueltaL $XINPUT_RB
Comp 'y otra vez' ($script:lupaEsc -eq 4.0) "x$($script:lupaEsc)"
VueltaL $XINPUT_RB
Comp 'pero no pasa de x4' ($script:lupaEsc -eq 4.0) 'mas aumento que eso no cabe nada'
VueltaL $XINPUT_LB
Comp 'y el izquierdo amplia menos' ($script:lupaEsc -eq 3.0) "x$($script:lupaEsc)"
$script:lupaEsc = 2.0
VueltaL $XINPUT_LB
Comp 'y no baja de x2' ($script:lupaEsc -eq 2.0) 'por debajo no se lee'

Write-Host ''
Write-Host '-- pero la cruceta es de tres: la lupa va la ultima --'
# La lupa, el selector y el panel rapido usan la MISMA cruceta. Si estan abiertos a la vez
# tiene que mandar uno solo, y la lupa es la que menos: las otras dos esperan respuesta.
$script:lupaDx = 0; $script:dibujos = 0
$script:eleccion = @{ opciones = @('a', 'b'); i = 0 }
VueltaL $XINPUT_DER
Comp 'con una lista abierta, la lupa no se mueve' (($script:lupaDx -eq 0) -and ($script:dibujos -eq 0))
$script:eleccion = $null
$script:panel = @{ i = 0 }
VueltaL $XINPUT_DER
Comp 'con el panel abierto tampoco' ($script:lupaDx -eq 0)
$script:panel = $null
$script:pendiente = @{ tipo = '' }
VueltaL $XINPUT_DER
Comp 'ni con una pregunta esperando' ($script:lupaDx -eq 0)
$script:pendiente = $null

Write-Host ''
Write-Host '-- y con un juego delante hace falta el menu --'
# La cruceta con un juego delante es del juego: moverla no puede mover la lupa sola.
$script:juegoActivo = 'Hollow Knight'
$script:lupaDx = 0
VueltaL $XINPUT_DER
Comp 'la cruceta a pelo no mueve nada' ($script:lupaDx -eq 0)
VueltaL ($XINPUT_DER -bor $TRIGGER) 0 ($XINPUT_DER -bor $TRIGGER)
Comp 'con el menu apretado si' ($script:lupaDx -gt 0) "dx=$($script:lupaDx)"
$script:juegoActivo = $false

Write-Host ''
Write-Host '-- y el plazo solo lo renueva lo que la lupa consume --'
$script:relojL = 0; $script:lupaUntil = $LupaMs
VueltaL $XINPUT_A 5000          # A no es suya
Comp 'un boton que no es suyo no renueva el plazo' ($script:lupaUntil -eq $LupaMs) "$($script:lupaUntil)"
VueltaL $XINPUT_DER 0
Comp 'pero moverla si' ($script:lupaUntil -gt $LupaMs) "$($script:lupaUntil)"
VueltaL $XINPUT_B 0
Comp 'y B la quita' ($null -eq $script:lupaForm) 'la tercera salida, con las manos en el mando'

Write-Host ''
Write-Host '-- y moverse NO vuelve a fotografiar la pantalla --'
$dl = TraerCodigo 'Draw-Lupa'
$ul = TraerCodigo 'Update-Lupa'
Comp 'Draw-Lupa no captura' ($dl -notmatch 'Save-Captura|CopyFromScreen') 'la captura ya esta en el disco'
Comp 'Update-Lupa tampoco' ($ul -notmatch 'Save-Captura|CopyFromScreen')
Comp 'y no crea una ventana nueva por pulsacion' ($ul -notmatch 'New-Object AXTarjeta') 'solo le cambia la foto'
Comp 'soltando el Bitmap viejo' ($ul -match '\$viejo\.Dispose\(\)') '~3 MB cada uno'
Comp 'y la lupa no se sale de la captura' ($dl -match '\[Math\]::Max\(0, \[Math\]::Min\(\$sx') 'fuera solo hay negro'
Write-Host ''
Write-Host '-- y NO recita lo que ve (que es el motivo de existir) --'
$ejec = ''
$i1 = $fuente.IndexOf("                'lupa' {")
$i2 = $fuente.IndexOf("                'lupaQuita' {", $i1)   # hasta ahi, y no hasta 'ocr':
# 'lupaQuita' tambien llama a Close-Lupa, y metiendola dentro la comprobacion de "quita la
# lupa antes de capturar" salia verde aunque esa linea no existiera. Comprobado rompiendolo.
if ($i1 -ge 0 -and $i2 -gt $i1) { $ejec = $fuente.Substring($i1, $i2 - $i1) }
# LOS COMENTARIOS FUERA, QUE SI NO ESTE BANCO MIRA LA FORMA Y NO LO QUE HACE. Se comprobo
# rompiendolo: comentando la linea de Close-Lupa el banco seguia verde, porque el texto
# "Close-Lupa" seguia estando ahi, delante de una almohadilla.
$codigo = ($ejec -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'el ejecutor de la lupa se lee' ($codigo.Length -gt 100) "$($codigo.Length) caracteres de codigo"
Comp 'no llama al OCR' ($codigo -notmatch 'Invoke-OCR') 'ni una letra transcrita'
Comp 'no dice lo que pone' ($codigo -notmatch 'Get-Trozo')
Comp 'y quita la lupa antes de capturar' ($codigo -match 'Close-Lupa') 'si no, la segunda saldria con la primera dentro'
Comp 'captura solo la zona pedida' ($codigo -match 'Save-Captura \$pngL \(\[string\]\$a\.zona\)')

Write-Host ''
if ($fallos) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  la lupa ensena, amplia de verdad, y no le quita el mando a braya'
exit 0
