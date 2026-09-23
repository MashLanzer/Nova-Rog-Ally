# SALIR DE LA SORDINA LLAMANDOLA POR SU NOMBRE (22/09 por la noche).
#
# Lo pidio braya con estas palabras: "si le digo que no hable en x tiempo, tiene que
# desactivarse la escucha hasta que la vuelva a llamar". Antes de hoy la sordina solo se
# quitaba con el boton (mantener el gatillo) o diciendo "despierta" -y eso ultimo no podia
# oirlo, porque durante la sordina el worker no escuchaba NADA-.
#
# Y OJO CON EL HISTORIAL, que es lo que hace delicado este cambio: el 21/09 esto mismo se
# rompio al reves. La marca de pausa se quedaba en "voz:" durante la sordina, asi que el
# worker aceptaba "nova", "para" y "calla", abria el microfono y sonaba el tic... con la
# sordina todavia puesta en disco: Nova despierta a medias. Por eso aqui se comprueba que
# durante la sordina se escucha SOLO el nombre, y que al oirlo se deshace TODO de una pieza
# (la hora a cero, el aviso de vuelta retirado y la escucha reanudada).
#
# Lo que se puede estropear sin querer y por eso esta aqui:
#   - que la marca vuelva a 'x' (sorda del todo: el nombre ya no la saca);
#   - que la marca se quede en 'voz:' (el fallo del 21/09: se despierta a medias);
#   - que "para" o "calla" la despierten (no son para eso, y suenan en cualquier video);
#   - que el sello de la hora se ponga DESPUES de pausar (la primera marca saldria 'x');
#   - y que "no hables en diez minutos" deje de entenderse.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre en assistant.ps1"; exit 1 }
    return $fn.Extent.Text
}

# dependencias minimas para Pausar-Escucha: un reloj y un fichero de mentira
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('sordina-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$MarcaPausa = Join-Path $base 'escucha-pausa.flag'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$InterrumpirOn = $true
$EscuchaNombre = 'nova'
$script:sordinaHasta = 0
$script:pausaHasta = 0
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Pausar-Escucha')
function Marca { if (Test-Path -LiteralPath $MarcaPausa) { [System.IO.File]::ReadAllText($MarcaPausa) } else { '' } }

Write-Host ''
Write-Host '-- la marca que deja cada pausa --'
$script:sordinaHasta = 0
Pausar-Escucha 3000 'ya te digo la hora'
Comp 'hablando, la marca lleva lo que dice' ((Marca).StartsWith('voz:')) (Marca)
Pausar-Escucha 3000
Comp 'una pausa seca es una x' ((Marca) -eq 'x') (Marca)
# y ahora la sordina
$script:sordinaHasta = $sw.ElapsedMilliseconds + 600000
Pausar-Escucha 600000
Comp 'en sordina, la marca lleva su NOMBRE' ((Marca) -eq 'nombre:nova') (Marca)
# el caso del 21/09: mientras esta muda, Say vuelve a pasar por aqui CON texto
Pausar-Escucha 2000 'me callo diez minutos'
Comp 'y lo que diga al callarse no la pisa' ((Marca) -eq 'nombre:nova') 'el fallo del 21/09 era quedarse en voz:'
$script:sordinaHasta = 0
Pausar-Escucha 1000
Comp 'al salir de la sordina, vuelve a ser una x' ((Marca) -eq 'x') (Marca)

Write-Host ''
Write-Host '-- el worker escucha SOLO el nombre mientras esta muda --'
Comp 'hay un reconocedor de solo-nombre' ($oido -match 'def _reconocedor_nombre\(') ''
Comp 'y solo conoce el nombre' ($oido -match 'json\.dumps\(\[NOMBRE, "\[unk\]"\]\)') 'ni para, ni calla, ni basta'
Comp "la marca 'nombre:' lo enciende" ($oido -match 'if marca\.startswith\("nombre:"\)')
Comp "y 'voz:' sigue con las palabras de corte" ($oido -match 'elif marca\.startswith\("voz:"\)|elif not marca\.startswith\("voz:"\)')

Write-Host ''
Write-Host '-- y al llamarla, se deshace TODO --'
# El bloque entero, contando llaves (nunca por distancia en caracteres).
$ini = $fuente.IndexOf('if ($script:sordinaHasta -gt $sw.ElapsedMilliseconds -and')
$cuerpo = ''
if ($ini -ge 0) {
    $j = $fuente.IndexOf('{', $fuente.IndexOf('ConvertTo-Plain $EscuchaNombre', $ini)); $prof = 0
    for ($k = $j; $k -lt $fuente.Length; $k++) {
        if ($fuente[$k] -eq '{') { $prof++ }
        elseif ($fuente[$k] -eq '}') { $prof--; if ($prof -eq 0) { $cuerpo = $fuente.Substring($j, $k - $j + 1); break } }
    }
}
Comp 'el despertar existe y se delimita' ($cuerpo.Length -gt 0) "$($cuerpo.Length) caracteres"
Comp 'la hora de la sordina se pone a cero' ($cuerpo -match '\$script:sordinaHasta = 0')
Comp 'se retira el aviso de vuelta' ($cuerpo -match "tipo -eq 'sordina'.*RemoveAt|RemoveAt")
Comp 'y la escucha se reanuda de verdad' ($cuerpo -match 'Reanudar-Escucha -Forzar') 'sin esto se queda a medias'
Comp 'y te contesta, para que sepas que volvio' ($cuerpo -match 'Say ')
Comp 'queda contado' ($cuerpo -match "Add-Estadistica 'sordina-nombre'")
# el orden del sello, que es lo que hacia que la primera marca saliera 'x'
# el bloque 'sordina' entero, contando llaves: con una ventana de N caracteres se coge
# medio bloque y la comprobacion mide cualquier cosa.
$iniS = $fuente.IndexOf("'sordina' {")
$blqS = ''
if ($iniS -ge 0) {
    $jS = $fuente.IndexOf('{', $iniS); $profS = 0
    for ($kS = $jS; $kS -lt $fuente.Length; $kS++) {
        if ($fuente[$kS] -eq '{') { $profS++ }
        elseif ($fuente[$kS] -eq '}') { $profS--; if ($profS -eq 0) { $blqS = $fuente.Substring($jS, $kS - $jS + 1); break } }
    }
}
Comp 'el bloque de la sordina se delimita' ($blqS.Length -gt 0) "$($blqS.Length) caracteres"
# SIN LOS COMENTARIOS, y es la leccion de hoy en carne propia: el comentario que hay ahi
# arriba dice 'sordinaHasta se sella ANTES de pausar, porque Pausar-Escucha mira esa
# variable', o sea que NOMBRA las dos cosas, y ademas en el orden contrario. Comparando
# posiciones sobre el texto crudo, esta comprobacion medía mi propia explicacion en vez
# del codigo, y salia roja con el codigo bien.
$codS = (($blqS -split "`r?`n") | Where-Object { $_.Trim() -notmatch '^#' }) -join "`n"
$posSella = $codS.IndexOf('$script:sordinaHasta =')
$posPausa = $codS.IndexOf('Pausar-Escucha')
Comp 'y al entrar, la hora se sella ANTES de pausar' ($posSella -ge 0 -and $posPausa -ge 0 -and $posSella -lt $posPausa) "sella en $posSella, pausa en $posPausa"

Write-Host ''
Write-Host '-- y "no hables en diez minutos" se entiende --'
# La linea del patron, entera, y se prueba CONTRA ELLA: asi esto mide lo que de verdad
# entiende Nova y no si alguien escribio unas palabras en el fichero.
$lineaS = @($fuente -split "`r?`n" | Where-Object { $_ -match 'no \(\?:me \)\?habl\[ae\]s' })[0]
Comp 'la linea del patron existe' ($null -ne $lineaS -and $lineaS.Length -gt 0) ''
$patS = ''
if ($lineaS) {
    $mS = [regex]::Match($lineaS, "-match '(.+)'\)")
    if ($mS.Success) { $patS = $mS.Groups[1].Value }
}
Comp 'y se puede leer el patron' ($patS.Length -gt 0) "$($patS.Length) caracteres"
# LA FRASE DE VERDAD, la que dijo braya a las 21:48:54 del 22/09 jugando a It Takes Two.
Comp 'su frase literal entra' ('no no me hablas por 10 minutos' -match $patS) "'No, no me hablas por 10 minutos'"
Comp 'y trae su plazo' ($Matches[1] -eq '10' -and $Matches[2] -eq 'minutos') "$($Matches[1]) $($Matches[2])"
Comp 'las otras formas tambien' (('no me hables' -match $patS) -and ('no digas nada en 5 minutos' -match $patS))
# Y LO QUE NO PUEDE COLARSE: quejarse de que no le habla NO es mandarla callar.
Comp 'una queja no la calla' (-not ('por que no me hablas nunca' -match $patS)) 'se queda en charla'
Comp 'ni pedirle que hable mas alto' (-not ('no hables mas alto' -match $patS))

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  te callas cuando te lo dice, y vuelves cuando te llama'
exit 0
