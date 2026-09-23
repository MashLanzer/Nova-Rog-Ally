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
Comp 'el aumento es fijo, no "lo que quepa"' ($sl -match '\$esc = 2\.0') 'x2'
Comp 'y lo que no cabe se recorta, no se encoge' ($sl -match 'GraphicsUnit\]::Pixel') 'DrawImage con rectangulo de origen'
# la cuenta, con LOS NUMEROS DE ESTA CONSOLA (medidos hoy): el escritorio va a 1280x720
$origW = [int](1280 * 0.6); $origH = [int](720 * 0.6)      # lo que da Get-ZonaRect al centro
$vMaxW = [int](1280 * 0.70); $vMaxH = [int](720 * 0.70)    # el techo de la version vieja
$antes = [Math]::Min($vMaxW / [double]$origW, $vMaxH / [double]$origH)
Comp 'la cuenta vieja no ampliaba' ($antes -lt 1.25) ("x{0:N2} con el centro de la pantalla" -f $antes)
Comp 'la nueva si' ($true) 'x2, mas del doble'
Comp 'la letra pequena no se emborrona' ($sl -match 'NearestNeighbor') 'nada de bilineal'

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
