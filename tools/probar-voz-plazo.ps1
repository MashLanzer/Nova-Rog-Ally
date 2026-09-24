# EL PLAZO DE LA VOZ YA NO ES UN NUMERO A FUEGO (24/09, idea 8 de la tanda nueva).
#
# LO QUE SE MIDIO, Y POR QUE LA IDEA CAMBIO DE FORMA. La idea decia que Say-Online bloquea el
# bucle con un Wait sincrono y habia que hacerla asincrona. Sobre el registro: son 303,2 s en
# quince dias, o sea 20 s al dia. Y se miraron las 311 ventanas de espera buscando DENTRO
# sucesos que significaran "el bucle tenia algo que hacer" -dictados, activaciones,
# interrupciones, cortes, recordatorios, whisper, parakeet, descartes- y cayeron CERO de los
# 7.391 del log. Hay un motivo estructural: Say llama a Pausar-Escucha ANTES que a Say-Online,
# asi que durante toda la espera el microfono esta callado a proposito.
#
# LO QUE SI ERA UN FALLO: de esos 304 s, VEINTICUATRO son tres plantones de 8 s (13/09, 15/09
# y 19/09). Tres sucesos, el 7,9 % del total. Y el plazo que los produce eran dos numeros a
# fuego -8000 + letras * 15- que no salian de ninguna medida.
#
# Y LA CEGUERA, que es lo que mas se vigila aqui: la linea que mide solo se escribe SI hay
# charla, asi que de la mitad de las frases de Nova no habia ni un dato. Sin eso, mover el
# plazo seria inventarse un numero.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

foreach ($f in @('Get-VozTiempos', 'Add-VozTiempo', 'Get-VozPlazoMs')) { Invoke-Expression (Traer $f) }
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('voz-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$VozTiemposJson = Join-Path $base 'voz-tiempos.json'
$VozTiemposMax = 200
$script:invitado = $false

Write-Host ''
Write-Host '-- 1. SIN DATOS, EL DE SIEMPRE: con poco historial no se juzga nada --'
# Es el mismo liston que el resto de decisiones propias de la casa. Si esto se cae, Nova
# estrenaria un plazo calculado con dos frases.
Comp 'con la lista vacia, 8000 + letras * 15' ((Get-VozPlazoMs 100 @() 20 2500 30000) -eq 9500) "$(Get-VozPlazoMs 100 @() 20 2500 30000) ms"
Comp 'y con 19 muestras todavia el de siempre' ((Get-VozPlazoMs 100 @(1..19) 20 2500 30000) -eq 9500) "$(Get-VozPlazoMs 100 @(1..19) 20 2500 30000) ms"
Comp 'y el de siempre respeta su techo de 30 s' ((Get-VozPlazoMs 9000 @() 20 2500 30000) -eq 30000) "$(Get-VozPlazoMs 9000 @() 20 2500 30000) ms"

Write-Host ''
Write-Host '-- 2. CON DATOS REALES: el p99 por las letras, por tres --'
# 200 muestras que imitan lo medido: la mayoria en torno a 0,02 ms por letra y una cola
# larga. Con una frase de 100 letras, el plazo tiene que caer MUY por debajo de los 9.500
# de hoy, que es de donde salen los tres plantones de 8 s.
# LOS NUMEROS SALEN DE LO MEDIDO, no de un invento: n=311 frases de charla con mediana
# 903 ms, p90 1.247, p99 2.792 y maximo 3.636. Con las frases de charla en torno a 150
# caracteres, eso son unos 6 ms por letra de mediana y 18 en el p99.
$reales = @()
1..190 | ForEach-Object { $reales += (5.0 + ($_ % 7) * 0.5) }
1..10 | ForEach-Object { $reales += (15.0 + ($_ % 3) * 1.5) }
$p = Get-VozPlazoMs 100 $reales 20 2500 30000
Comp 'con 200 muestras ya decide el dato' ($p -ne 9500) "$p ms, y el de siempre eran 9.500"
Comp 'y el plazo baja de los 9,5 s de antes' ($p -lt 9500) "$p ms"
Comp 'pero no baja del suelo de 2,5 s' ($p -ge 2500) "$p ms"
# Y ESCALA CON LO LARGA QUE SEA LA FRASE, que es el motivo de guardar ms POR LETRA: una
# respuesta de 600 caracteres tarda mas en sintetizarse que un "vale".
$corto = Get-VozPlazoMs 10 $reales 20 2500 30000
$largo = Get-VozPlazoMs 600 $reales 20 2500 30000
Comp 'una frase larga tiene mas plazo que una corta' ($largo -gt $corto) "$corto ms vs $largo ms"
Comp 'y la corta se queda en el suelo' ($corto -eq 2500) "$corto ms"
Comp 'y ninguna pasa del techo' ((Get-VozPlazoMs 99999 $reales 20 2500 30000) -le 30000) ''

# LO QUE MAS IMPORTA DE TODO EL BANCO: el dato solo puede BAJAR el plazo, nunca subirlo.
# Los ms por letra no son una recta -sintetizar tiene una parte fija y otra que crece con el
# texto-, asi que dividir por las letras sobreestima las frases largas. Mientras no haya una
# medida que separe las dos partes, subir el plazo seria inventarse un numero.
$lentas = @()
1..200 | ForEach-Object { $lentas += (500.0 + $_) }   # absurdamente lentas a proposito
foreach ($n in @(10, 50, 100, 300, 600, 2000)) {
    $deSiempre = [Math]::Min(30000, 8000 + $n * 15)
    $sale = Get-VozPlazoMs $n $lentas 20 2500 30000
    Comp ("con $n letras, ni con datos malisimos sube del de siempre") ($sale -le $deSiempre) "$sale ms vs $deSiempre ms"
}

Write-Host ''
Write-Host '-- 3. y lo que se guarda son ms POR LETRA, no ms sueltos --'
# Sin dividir por las letras no se puede comparar un "vale" con una respuesta larga, y el
# plazo saldria de una mezcla que no significa nada.
Remove-Item -LiteralPath $VozTiemposJson -Force -ErrorAction SilentlyContinue
Comp 'la lista empieza vacia' ((Get-VozTiempos).Count -eq 0) ''
Comp 'guarda una medida' (Add-VozTiempo 2000 100) ''
$l = Get-VozTiempos
Comp 'y es ms partido por letras' ([Math]::Abs([double]$l[0] - 20.0) -lt 0.01) "$($l[0])"
# 2.000 ms en 10 letras y 2.000 ms en 1.000 letras NO son lo mismo, y tienen que
# distinguirse: si se guardaran los ms sueltos, los dos darian 2.000.
[void](Add-VozTiempo 2000 1000)
$l2 = Get-VozTiempos
Comp 'dos frases de distinto largo no se confunden' ([double]$l2[0] -ne [double]$l2[1]) "$($l2[0]) vs $($l2[1])"

Write-Host ''
Write-Host '-- 4. y no guarda basura --'
Comp 'cero milisegundos, no' (-not (Add-VozTiempo 0 100)) ''
Comp 'negativos, tampoco' (-not (Add-VozTiempo -5 100)) ''
Comp 'cero letras, tampoco (seria dividir por cero)' (-not (Add-VozTiempo 2000 0)) ''
$antes = (Get-VozTiempos).Count
[void](Add-VozTiempo 0 0)
Comp 'y ninguna de esas entra en la lista' ((Get-VozTiempos).Count -eq $antes) "$((Get-VozTiempos).Count)"

Write-Host ''
Write-Host '-- 5. con un invitado delante, nada --'
# Esto mide la maquina, no a nadie... pero la regla de la casa es que toda funcion que
# guarde se decida a mano, y aqui la decision es que no hace falta guardar mientras hay
# otra persona: el plazo de la voz no cambia por quien hable.
$script:invitado = $true
$antesInv = (Get-VozTiempos).Count
Comp 'con invitado no guarda' (-not (Add-VozTiempo 1500 80)) ''
Comp 'y la lista no crece' ((Get-VozTiempos).Count -eq $antesInv) ''
$script:invitado = $false

Write-Host ''
Write-Host '-- 6. la lista tiene tope, o el json crece sin fin --'
$VozTiemposMax = 30
1..60 | ForEach-Object { [void](Add-VozTiempo (1000 + $_) 100) }
$fin = Get-VozTiempos
Comp 'no pasa del tope' ($fin.Count -le 30) "$($fin.Count) de tope 30"
Comp 'y se queda con las ULTIMAS, no las primeras' ([Math]::Abs([double]$fin[$fin.Count - 1] - 10.6) -lt 0.01) "$($fin[$fin.Count - 1])"

Write-Host ''
Write-Host '-- 7. y Say-Online lo usa de verdad --'
$so = SinComentarios (Traer 'Say-Online')
Comp 'el plazo sale de Get-VozPlazoMs' ($so -match '\$plazoVoz = Get-VozPlazoMs') ''
Comp 'y ya no queda el 8000 a fuego en Say-Online' ($so -notmatch '8000 \+ \$texto\.Length') 'vive dentro de Get-VozPlazoMs, de respaldo'
Comp 'y mide TODAS las frases, no solo las de charla' ($so -match 'Add-VozTiempo \(\$sw\.ElapsedMilliseconds - \$t0Voz\) \$texto\.Length') ''
# LO QUE DE VERDAD IMPORTA: que la medida este FUERA del if de la charla. Es el fallo que
# dejaba ciega a la mitad de las frases, y meterla dentro seria repetirlo con otra ropa.
$iMide = $so.IndexOf('Add-VozTiempo')
$iIf = $so.IndexOf('$script:charlaEsperando -or')
Comp 'y la medida va ANTES del if de la charla' (($iMide -ge 0) -and ($iIf -ge 0) -and ($iMide -lt $iIf)) 'dentro del if, se perderia la mitad'
# Y NO SE TOCA LA ESPERA EN SI: la reescritura asincrona se descarto con datos (0 de 7.391
# sucesos cayeron dentro de una espera), y su fallo tipico -"dice una y suena otra"- ya
# costo tres arreglos.
Comp 'la espera sigue siendo la de siempre' ($so -match '\$tarea\.Wait\(\$plazoVoz\)') 'la asincrona se descarto con datos'
Comp 'y al vencer sigue matando el worker' ($so -match '\$script:ttsProc\.Kill\(\)') 'lo unico que deja la tuberia limpia'

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  el plazo de la voz ya sale de lo que tarda de verdad'
exit 0
