# "NO ME HABLAS EN DIEZ MINUTOS" (23/09 21:16). Nova dijo que si y no se callo.
#
# EL CASO, tal y como esta en el log:
#   21:16:25  [escucha] parakeet: 'Si, esto en una llamada, No me hablas en diez minutos'
#   21:16:26  CHARLA (hablar): Si, esto en una llamada, No me hablas en diez minutos
#   ...y el modelo contesto que vale. La sordina NO se activo: siguio escuchando.
#
# Decir que si y no hacerlo es el peor fallo que puede tener Nova, y es la SEGUNDA vez con
# esta familia de frases. El 21/09 fue "Solo estoy pensando en Mojarta, no te actives por
# diez minutos", y entonces se escribio el patron de SUFIJO con su regla de oro -solo con
# plazo explicito- pero solo para "no te actives". Dos dias despues volvio a pasar con otra
# frase de la misma familia.
#
# Las dos causas, medidas pasando trece formas naturales por el patron de entonces: cogia
# TRES. Faltaban los numeros hablados (Get-MinutosDichos llegaba hasta CINCO, asi que "diez
# minutos" no existia), el indicativo que suelta el oido ("no me hablAs"), y los enlaces
# "durante" y "por".
#
# LO QUE ESTE BANCO NO DEJA PASAR: que la frase de braya, con su ruido delante, no se calle.
# Y lo contrario: que un "callate ya" suelto en mitad de una charla NO la calle.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
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
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Get-MinutosDichos')
Invoke-Expression (Traer 'Format-MinutosDichos')

# LOS IF DE LA SORDINA, ENTEROS Y DEL ARBOL. Aqui no vale leer el patron y probarlo suelto:
# lo que importa es cuantos MINUTOS sale, y eso lo decide el cuerpo del if.
$ifs = @()
foreach ($x in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
    $t = $x.Extent.Text
    if ($t -match "kind = 'sordina'") { $ifs += $t }
}
# lo que haria Resolve-Fragment: el primero que devuelve algo
function Callar([string]$frase) {
    foreach ($b in $ifs) {
        # con @(): el if devuelve un array de uno y PowerShell lo aplana a hashtable,
        # y entonces [0] pasa a ser "la clave 0", que no existe
        $r = @(& { $f = $frase; Invoke-Expression $b })
        if ($r -and $r[0]) { return $r[0] }
    }
    return $null
}

Write-Host ''
Write-Host '-- los dos ifs de la sordina se sacan del arbol --'
# TRES DESDE EL 24/09 (idea 20): el anclado, el de sufijo, y "estoy en una llamada".
Comp 'hay tres: el anclado, el de sufijo y el de la llamada' ($ifs.Count -eq 3) "$($ifs.Count)"

Write-Host ''
Write-Host '-- LA FRASE DE BRAYA, TAL Y COMO LA OYO PARAKEET --'
# Con su ruido delante. Esta es la que fallo.
$suya = 'si esto en una llamada no me hablas en diez minutos'
$aS = Callar $suya
Comp 'se calla' ($null -ne $aS) $(if ($aS) { [string]$aS.desc } else { 'SE FUE A LA CHARLA' })
Comp 'y son diez minutos, no quince' ($aS -and ([int]$aS.ms -eq 600000)) $(if ($aS) { "$([int]$aS.ms / 60000) min" } else { '' })

Write-Host ''
Write-Host '-- y las trece formas naturales de pedirlo --'
$formas = @(
    @('no me hables en diez minutos', 10),
    @('no me hables en 10 minutos', 10),
    @('no me hablas en diez minutos', 10),
    @('no me hables durante diez minutos', 10),
    @('no me hables por diez minutos', 10),
    @('callate diez minutos', 10),
    @('callate veinte minutos', 20),
    @('dejame en paz diez minutos', 10),
    @('no me digas nada en diez minutos', 10),
    @('no me molestes en media hora', 30),
    @('no me hables en una hora', 60),
    @('no te actives por quince minutos', 15),
    @('no me hables', 15),
    @('no me hables un rato', 15),
    @('duermete', 15)
)
$bien = 0
foreach ($par in $formas) {
    $a = Callar $par[0]
    $min = if ($a) { [int]([int]$a.ms / 60000) } else { -1 }
    $ok = ($min -eq $par[1])
    if ($ok) { $bien++ }
    Write-Host ("       {0} {1,-42} {2}" -f $(if ($ok) { 'SI ' } else { 'no ' }), $par[0],
                $(if ($a) { "$min min (se esperaban $($par[1]))" } else { '(no la coge)' }))
}
Comp 'las coge todas, con sus minutos' ($bien -eq $formas.Count) "$bien de $($formas.Count)"

# LO QUE ENSENO ROMPERLO, y queda dicho porque el que venga detras lo va a repetir:
# se rompio el codigo seis veces y CINCO salieron rojas. La sexta -aflojar a la vez el
# patron del sufijo y su guard de cero minutos- NO consegui que cantara: con las dos capas
# rotas, 'ya te he dicho mil veces que no me molestes' sigue sin callar a Nova, y no llegue
# a averiguar que tercera cosa lo impide. Asi que esa combinacion esta probada por separado
# (las dos secciones de aqui abajo) pero NO tiene una rotura que la cace entera. Si alguien
# toca esa pareja, que lo sepa.
Write-Host ''
Write-Host '-- y CADA CAPA hace su trabajo por separado --'
# Esto sale de romper el codigo: dos roturas no cantaban, y el motivo era bueno -lo que
# quitaba de una capa lo cubria la otra-. Pero entonces el banco no estaba probando las dos:
# estaba probando que ENTRE LAS DOS sale bien. Aqui se prueba cada una sola.
$ifAnc = @($ifs | Where-Object { $_ -match 'minS' })[0]
$ifSuf = @($ifs | Where-Object { $_ -match 'min2' })[0]
Comp 'se distinguen las dos capas' (($null -ne $ifAnc) -and ($null -ne $ifSuf))
function CallarCon([string]$bloque, [string]$frase) {
    $r = @(& { $f = $frase; Invoke-Expression $bloque })
    if ($r -and $r[0]) { return $r[0] }
    return $null
}
# la capa anclada: la frase limpia, sin ruido delante
foreach ($fr in @('no me hables durante diez minutos', 'no me hables por diez minutos',
                  'no me hablas en diez minutos', 'callate veinte minutos')) {
    Comp "   anclada: '$fr'" ($null -ne (CallarCon $ifAnc $fr))
}
# la capa de sufijo: la misma frase con ruido delante, que es la que fallo de verdad
foreach ($fr in @('si esto en una llamada no me hablas en diez minutos',
                  'solo estoy pensando en mojarta no te actives por diez minutos',
                  'oye una cosa callate por veinte minutos')) {
    Comp "   sufijo: '$($fr.Substring(0, [Math]::Min(38, $fr.Length)))'" ($null -ne (CallarCon $ifSuf $fr))
}
# y el sufijo NO se dispara sin plazo, ni con la puerta de atras quitada
foreach ($fr in @('ya te he dicho mil veces que no me molestes', 'pues no me hables')) {
    Comp "   sufijo NO coge '$($fr.Substring(0, [Math]::Min(34, $fr.Length)))'" ($null -eq (CallarCon $ifSuf $fr)) 'sin plazo no hay sordina'
}
Write-Host ''
Write-Host '-- pero un "callate" suelto SIGUE siendo charla --'
# La regla de oro del patron de sufijo, y no se toca: sin plazo explicito, una frase larga
# que acabe en "callate" no calla a nadie. Decirle a Nova que se calle DIEZ MINUTOS no sale
# por casualidad en mitad de una frase; "callate ya", si.
foreach ($f in @('no me hables asi', 'callate ya', 'no me molestes mas', 'que no te actives',
                 'le dije que no me hablara', 'no me hables de eso', 'no digas nada a nadie',
                 'mi hermano no me habla desde hace diez dias', 'no me hables como si fuera tonto',
                 # ESTA ES LA QUE VIGILA EL PLAZO DEL SUFIJO, y se vio rompiendolo: sin la
                 # regla de oro -solo con plazo explicito- una frase larga que ACABA en un
                 # verbo de callar se llevaria quince minutos de silencio por delante.
                 'ya te he dicho mil veces que no me molestes',
                 'pues no me hables', 'entonces dejame en paz')) {
    Comp "'$($f.Substring(0, [Math]::Min(40, $f.Length)))' es charla" ($null -eq (Callar $f))
}

Write-Host ''
Write-Host '-- los numeros hablados llegan hasta donde se dicen --'
# Get-MinutosDichos llegaba hasta CINCO. Por eso "diez minutos" no existia para Nova.
foreach ($par in @(@('diez', 10), @('quince', 15), @('veinte', 20), @('treinta', 30),
                   @('cuarenta y cinco', 45), @('noventa', 90), @('media', 0))) {
    $m = Get-MinutosDichos $par[0] 'minutos'
    Comp "'$($par[0]) minutos' son $($par[1])" ($m -eq $par[1]) "$m"
}
Comp "'dos horas' son 120" ((Get-MinutosDichos 'dos' 'horas') -eq 120)
Comp "'media hora' son 30" ((Get-MinutosDichos 'media' 'hora') -eq 30)
Comp 'y un disparate no cuenta' ((Get-MinutosDichos 'tropecientos' 'minutos') -eq 0) 'devuelve 0 y no se calla'
# Y LA PUERTA DE ATRAS SIGUE PUESTA: si por lo que sea salieran cero minutos, no se calla
# NADA. Es defensa en profundidad -hoy el patron no deja pasar un numero que no este en su
# lista-, pero una sordina de cero minutos o de toda la vida es justo lo que no puede pasar.
$ifAnclado = @($ifs | Where-Object { $_ -match 'minS' })[0]
Comp 'cero minutos no callan a nadie' ($ifAnclado -match 'if \(\$minS -le 0\) \{ return \$null \}') 'ni un patron roto puede dejarla muda'

Write-Host ''
Write-Host '-- y al callarse, se calla de verdad --'
$codigo = ($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'la sordina se apunta con el reloj' ($codigo -match '\$script:sordinaHasta = \$sw\.ElapsedMilliseconds \+ \$a\.ms')
Comp 'y se sale con el boton' ($fuente -match 'manten el boton') 'la salida que siempre esta'
Comp 'y diciendo su nombre' ($codigo -match "nombre:' \+ \(ConvertTo-Plain \`$EscuchaNombre\)") 'la otra puerta, del 22/09'

Write-Host ''
Write-Host '-- "estoy en una llamada" se calla, y no se va a la charla (24/09, idea 20) --'
# EL CASO: el 23/09 a las 21:16 braya dijo "estoy compartiendo el telefono", Nova contesto "te
# dejo tranquilo"... y en la hora siguiente metio diez frases mas en la charla y dijo
# diecinueve. Cero sordinas ese dia.
foreach ($fr in @('estoy en una llamada', 'estoy en llamada', 'estoy de reunion',
                  'ando en una videollamada', 'estoy grabando')) {
    $r = Callar $fr
    Comp ("`"$fr`" pone la sordina") ($null -ne $r) ''
    if ($r) { Comp "   y son diez minutos" ([int]$r.ms -eq 600000) "$([int]$r.ms) ms" }
}
# LOS DIEZ MINUTOS NO SON UN NUMERO NUEVO: son los que pidio el mismo esa noche y los mismos
# de la autosordina por ruido.
$autoMin = if ($fuente -match "'autoSordinaMinutos' (\d+)") { [int]$Matches[1] } else { 10 }
$rLl = Callar 'estoy en una llamada'
Comp 'y son los mismos de la autosordina por ruido' ([int]$rLl.ms -eq ($autoMin * 60000)) "$autoMin min"
# Y LO QUE NO PUEDE PASAR: que se lleve frases que no lo son
foreach ($fr in @('estoy aqui', 'estoy jugando', 'estoy bien', 'estoy en casa', 'llamada perdida')) {
    Comp ("`"$fr`" NO pone la sordina") ($null -eq (Callar $fr)) 'lista cerrada de cuatro palabras'
}
# y sigue diciendolo en voz alta: callarse en silencio es identico a estar rota
Comp 'y lo dice antes de callarse' ([string]$rLl.desc -match 'me callo') "$([string]$rLl.desc)"
Comp 'y dice como volver' ([string]$rLl.desc -match 'boton') 'la segunda salida, en voz alta'

Write-Host ''
if ($fallos) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  cuando le mandas callar se calla, y cuando no, no'
exit 0
