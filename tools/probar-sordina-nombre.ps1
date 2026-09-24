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
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
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
# SE EJECUTAN LOS IF DE VERDAD, sacados del arbol (23/09). Antes esto buscaba la LINEA del
# patron por su texto -'no (?:me )?habl[ae]s'- y sacaba el patron con un regex sobre ella:
# al ampliar el patron el 23/09 para que entendiera 'diez minutos', la linea dejo de casar
# y salieron cinco rojos con el codigo mejor que antes. Lo que importa no es como esta
# escrito el patron, sino si la frase de braya calla a Nova.
$ifsS = @()
foreach ($x in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
    if ($x.Extent.Text -match "kind = 'sordina'") { $ifsS += $x.Extent.Text }
}
Invoke-Expression (Traer 'Get-MinutosDichos')
Invoke-Expression (Traer 'Format-MinutosDichos')
function CallaCon([string]$frase) {
    foreach ($b in $ifsS) {
        $r = @(& { $f = $frase; Invoke-Expression $b })
        if ($r -and $r[0]) { return $r[0] }
    }
    return $null
}
Comp 'los ifs de la sordina se encuentran' ($ifsS.Count -ge 1) "$($ifsS.Count)"
# LA FRASE DE VERDAD, la que dijo braya a las 21:48:54 del 22/09 jugando a It Takes Two.
$a22 = CallaCon 'no no me hablas por 10 minutos'
Comp 'su frase literal entra' ($null -ne $a22) "'No, no me hablas por 10 minutos'"
Comp 'y trae su plazo' ($a22 -and ([int]$a22.ms -eq 600000)) $(if ($a22) { "$([int]$a22.ms / 60000) min" } else { '' })
# Y LA DEL 23/09, que es la misma pero con el numero dicho en palabra: volvio a fallar.
$a23 = CallaCon 'si esto en una llamada no me hablas en diez minutos'
Comp 'y la del dia siguiente, con diez en palabra' ($a23 -and ([int]$a23.ms -eq 600000)) $(if ($a23) { "$([int]$a23.ms / 60000) min" } else { 'SE FUE A LA CHARLA' })
Comp 'las otras formas tambien' (($null -ne (CallaCon 'no me hables')) -and ($null -ne (CallaCon 'no digas nada en 5 minutos')))
# Y LO QUE NO PUEDE COLARSE: quejarse de que no le habla NO es mandarla callar.
Comp 'una queja no la calla' ($null -eq (CallaCon 'por que no me hablas nunca')) 'se queda en charla'
Comp 'ni pedirle que hable mas alto' ($null -eq (CallaCon 'no hables mas alto'))

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  te callas cuando te lo dice, y vuelves cuando te llama'
exit 0
