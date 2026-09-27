# LO QUE NO SE DICE NO GASTA TURNO (26/09, idea 29 de las 121).
#
# EL AGUJERO: un aviso de nivel 'bajo' solo sale en la capsula, no se dice NUNCA. Pero gastaba
# una de las cuatro plazas de VOZ de la hora y ademas se quedaba como el aviso al que Nova le
# mira la reaccion para aprender cuanto esperar.
#
# MEDIDO sobre los 97 avisos de los dos registros: 26 son 'bajo', el 26,8 % (bateria-llena 21,
# cargador-pone 2, lo-que-no-dije 2, resumen-semana 1). Y CUATRO de las DOCE muestras de
# reaccion guardadas hoy son de claves que no suenan: un tercio del corpus con el que Nova
# aprende la espera esta medido sobre avisos que nadie oyo.
#
# LOS DOS ROBOS, CON HORA Y CLAVE:
#   22/09 08:00:25  oido-ruido     (medio, dicho)  ->  08:01:54  bateria-llena (bajo, mudo)
#   23/09 20:41:58  cargador-quita (medio, dicho)  ->  20:42:58  cargador-pone (bajo, mudo)
# En los dos, el aviso mudo se quedo con el desenlace del que si sono.
#
# ESTE BANCO EJECUTA Send-AvisoEntorno DE VERDAD, sacada del arbol: lo que hay que probar es una
# consecuencia -que el turno no se gasta-, y eso un regex no lo ve.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($ruta)
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

# --- el mundo de mentira. NUNCA se toca el tmp de verdad --------------------
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('sinvoz-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$EntornoVistosPath = Join-Path $tmp 'entorno-vistos.json'
$AvisoEsperaPath = Join-Path $tmp 'avisos-esperando.json'
$script:ahoraMs = 600000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:entornoVistos = @{}
$script:entornoAvisos = New-Object System.Collections.ArrayList
# LA LISTA DE AVISOS EN OBSERVACION (27/09, idea 91): antes era UNA variable a $null y ahora es
# una lista a la que Send-AvisoEntorno le hace .Add(). Sin este doble el banco revienta con "no
# se puede llamar a un metodo en una expresion con valor NULL".
$script:avisosMirar = New-Object System.Collections.ArrayList
$AvisosMirarMax = 4
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoEspera = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$script:juegoActivo = $null
$script:ultimaRespuesta = ''
$script:ausenciaMin = 0
$script:logs = @(); $script:apuntes = @(); $script:dichos = @(); $script:popups = @()
function Log([string]$m) { $script:logs += $m }
function Add-Estadistica($a, $b) { $script:apuntes += "$a|$b" }
function Show-Popup([string]$t, [string]$e = 'hablando') { $script:popups += $t }
function Say([string]$t, [string]$e = '') { $script:dichos += $t }
function Save-EntornoVistos { }
function Get-AusenciaMin([datetime]$ahora = (Get-Date)) { return $script:ausenciaMin }
function Get-CuentaHoy([string]$c) { return 0 }
function Write-Atomico([string]$r, [string]$t) { [IO.File]::WriteAllText($r, $t, (New-Object Text.UTF8Encoding($false))) }
function Send-AvisoCola([bool]$yaMismo = $false) {
    if ($script:avisoCola.Count -eq 0) { return }
    $piezas = @($script:avisoCola | ForEach-Object { ([string]$_).Trim().TrimEnd('.') })
    $script:avisoCola.Clear()
    Say (($piezas -join '. ') + '.')
}
function Test-AvisoAplazable([string]$clave, [string]$nivel) { return $false }
function Add-AvisoEspera($a, $b, $c, $d) { }
# LA VENTANA SALE DEL ARCHIVO, no escrita aqui: si algun dia cambia, el banco la sigue.
$mV = [regex]::Match($fuente, '(?m)^\$AvisoReaccionVentanaMs\s*=\s*(\d+)')
if (-not $mV.Success) { Write-Host '  MAL  no encuentro $AvisoReaccionVentanaMs'; exit 1 }
$AvisoReaccionVentanaMs = [int]$mV.Groups[1].Value
$EntornoPorHora = 4
# LO QUE Test-PuedoAvisar MIRA ADEMAS DEL TOPE: se pone todo del lado que deja pasar, para que
# aqui decida SOLO el presupuesto por hora, que es lo que este banco prueba. La franja de noche
# se calcula con Get-NocheDesde, asi que se dobla para dejarla fuera de la hora de ahora.
$EntornoOn = $true
$script:entornoCallado = $false
$script:invitado = $false
$script:busy = $false
$script:pendiente = $null
$script:dictandoLargo = $false
$script:armed = $false
$EntornoNocheHasta = (Get-Date).Hour
function Get-NocheDesde { return (((Get-Date).Hour + 2) % 24) }
# desde idea 39 (commit 10c4fc6) Test-PuedoAvisar mira la franja de noche con Test-EsNocheAviso,
# no con Get-NocheDesde: hay que doblarla a $false o el aviso se bloquea por "es de noche" y este
# banco -que prueba SOLO el presupuesto por hora- salia rojo por otra cosa.
function Test-EsNocheAviso([datetime]$ahora = (Get-Date)) { return $false }
function Get-EsperaAviso([string]$c, [int]$d) { return $d }
function Get-EntornoVistos { return $script:entornoVistos }
# Test-CabeOtroAviso llama a Get-SueloPorAnimo, que lee el animo del dia y aqui no pinta nada:
# se dobla devolviendo el suelo tal cual, que es lo que hace un dia normal.
function Get-SueloPorAnimo([int]$suelo) { return $suelo }
# EL FRENO DE VERDAD, sacado del archivo: es quien lee $script:entornoAvisos, y por eso este
# banco lo trae en vez de doblarlo. Sin el, el caso del turno no probaria nada.
foreach ($f in @('Test-CabeOtroAviso', 'Test-PuedoAvisar', 'Send-AvisoEntorno')) { Invoke-Expression (Traer $f) }

function Limpia {
    $script:entornoVistos = @{}
    $script:entornoAvisos.Clear()
    $script:avisoCola.Clear()
    $script:avisosMirar.Clear()
    $script:logs = @(); $script:apuntes = @(); $script:dichos = @(); $script:popups = @()
}

try {
    Write-Host ''
    Write-Host '-- 0. el autocontrol: sin esto, todo saldria verde por estar bloqueado --'
    # Si el mundo de mentira bloqueara los avisos -franja de noche, sordina, lo que sea- los
    # cinco casos de abajo pasarian sin probar nada. Es el fallo que probar-entorno ya documenta.
    Limpia
    $r0 = Send-AvisoEntorno 'oido-ruido' 'Hay ruido de fondo' 'medio' 60
    Comp 'un aviso normal SI sale' ([bool]$r0) "$r0"
    Comp '  y gasta su turno' ($script:entornoAvisos.Count -eq 1) "$($script:entornoAvisos.Count)"
    Comp '  y queda en observacion' ($script:avisosMirar.Count -eq 1 -and $script:avisosMirar[0].clave -eq 'oido-ruido') ''

    Write-Host ''
    Write-Host '-- A. EL TURNO: cuatro mudos no dejan a Nova sin voz --'
    # ESTA ES LA COMPROBACION QUE MIDE EL DANO. Con las dos lineas arriba del if, cuatro avisos
    # 'bajo' llenaban las cuatro plazas de la hora y el siguiente 'medio' -que SI habla- se
    # quedaba fuera.
    Limpia
    foreach ($c in @('bateria-llena', 'cargador-pone', 'lo-que-no-dije', 'resumen-semana')) {
        [void](Send-AvisoEntorno $c "algo de $c" 'bajo' 60)
    }
    Comp 'cuatro mudos no gastan ni un turno' ($script:entornoAvisos.Count -eq 0) (
        "$($script:entornoAvisos.Count); el tope de la hora son $EntornoPorHora")
    $rA = Send-AvisoEntorno 'oido-ruido' 'Hay ruido de fondo' 'medio' 60
    Comp '  y el que SI habla sigue cabiendo' ([bool]$rA) 'con las lineas arriba del if, aqui salia $false'
    Comp '  y es el unico que ocupa plaza' ($script:entornoAvisos.Count -eq 1) "$($script:entornoAvisos.Count)"

    Write-Host ''
    Write-Host '-- B. EL ROBO MEDIDO: 22/09 08:00:25 -> 08:01:54 --'
    # oido-ruido salio y hablo; 89 segundos despues bateria-llena, que no dice nada, le quito la
    # observacion. Lo que braya hiciera en los cinco minutos siguientes se le apunto al mudo.
    Limpia
    [void](Send-AvisoEntorno 'oido-ruido' 'Hay ruido de fondo' 'medio' 60)
    $script:ahoraMs += 89000
    [void](Send-AvisoEntorno 'bateria-llena' 'Ya esta llena' 'bajo' 60)
    Comp 'el mudo NO le quita la observacion al que sono' ($script:avisosMirar.Count -eq 1 -and $script:avisosMirar[0].clave -eq 'oido-ruido') (
        "quedo mirando '$($script:avisosMirar[0].clave)'")
    Comp '  y sigue con su plazo original' ($script:avisosMirar[0].hasta -eq (600000 + $AvisoReaccionVentanaMs)) ''
    # Y DESDE LA IDEA 91 (27/09) TAMPOCO SE LO QUITA OTRO QUE SI SUENE. Este es el otro robo, el
    # que el mudo no arreglaba: MEDIDO, once de los 76 avisos que suenan tienen otro que suena
    # dentro de la ventana -el 23/09 a las 08:00:19 disco-poco y 14 s despues oido-ruido-, y con
    # la version de UNA variable el primero se quedaba sin apuntar nada.
    $script:ahoraMs += 14000
    [void](Send-AvisoEntorno 'disco-poco' 'Queda poco disco' 'medio' 60)
    Comp '  ni otro que SI suena' ($script:avisosMirar.Count -eq 2) ([string]$script:avisosMirar.Count + ' en observacion')
    Comp '  y el primero sigue siendo el primero' ($script:avisosMirar[0].clave -eq 'oido-ruido') 'el "sirvio" va al mas antiguo'

    Write-Host ''
    Write-Host '-- C. y lo que NO puede cambiar: el mudo sigue saliendo --'
    # EL CASO NEGATIVO QUE TOCA LO QUE VIGILA: esto no es "callar mas", es no cobrarle el turno a
    # quien no habla. El aviso bajo tiene que seguir apareciendo en la capsula y contandose.
    Limpia
    $rC = Send-AvisoEntorno 'bateria-llena' 'Ya esta llena' 'bajo' 60
    Comp 'el aviso mudo SIGUE saliendo' ([bool]$rC) "$rC"
    Comp '  y se ve en la capsula' ($script:popups.Count -eq 1) "$($script:popups.Count) popups"
    Comp '  y queda en el log' ((($script:logs -join ' ') -match 'ENTORNO \(bateria-llena, bajo\)')) ''
    Comp '  y se cuenta como aviso' ((($script:apuntes -join ' ') -match 'aviso-entorno\|bateria-llena')) (
        'eso mide cuantos avisos hay, y eso si sirve')
    # PERO NO SE DICE, que es lo que era desde siempre
    Comp '  y NO se dice' ($script:dichos.Count -eq 0 -and $script:avisoCola.Count -eq 0) "$($script:dichos.Count) dichos"
    Comp '  ni se cuenta como dicho' ((($script:apuntes -join ' ') -notmatch 'aviso-dicho')) ''

    Write-Host ''
    Write-Host '-- D. los tres niveles que hablan SI gastan --'
    foreach ($n in @('alto', 'medio', 'noche')) {
        Limpia
        [void](Send-AvisoEntorno 'oido-ruido' 'algo' $n 60)
        Comp "el nivel '$n' gasta su turno" ($script:entornoAvisos.Count -eq 1) ''
        Comp "  y queda en observacion" ($script:avisosMirar.Count -eq 1) ''
    }
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '-- E. y las dos ramas de voz no se han tocado --'
# probar-perfil-avisos exige que entre la llave de apertura de cada rama y
# $script:ultimaRespuesta no haya NADA, ni siquiera un comentario. Por eso el bloque nuevo va
# DETRAS del if entero y no dentro de las ramas.
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# A luego B, en orden y sin tope de distancia: evita las expresiones fragiles [\s\S]{0,N} que se
# rompen al meter un comentario en medio (ver probar-bancos-fragiles).
function EnOrden([string]$t, [string]$a, [string]$b) {
    $ma = [regex]::Match($t, $a); if (-not $ma.Success) { return $false }
    return [regex]::Match($t.Substring($ma.Index + $ma.Length), $b).Success
}
Comp "la rama 'alto' sigue intacta" (EnOrden $sinCom 'if \(\$nivel -eq .alto.\) \{' '\$script:ultimaRespuesta') ''
Comp '  y la de los demas tambien' ($sinCom -match 'elseif \(\$nivel -ne .bajo.\) \{\s*\r?\n\s*\$script:ultimaRespuesta = \$texto') ''
# Y EL BLOQUE NUEVO VA DETRAS DEL if, no dentro.
$cuerpoS = Traer 'Send-AvisoEntorno'
$iRama = $cuerpoS.IndexOf("elseif (`$nivel -ne 'bajo') {")
$iGuarda = $cuerpoS.LastIndexOf("if (`$nivel -ne 'bajo') {")
Comp 'el guarda nuevo va DETRAS de las ramas' ($iGuarda -gt $iRama) 'asi no se toca ni un caracter dentro de ellas'
$iAdd = $cuerpoS.IndexOf('$script:entornoAvisos.Add')
$iMirar = $cuerpoS.IndexOf('$script:avisosMirar.Add(')
Comp '  y las dos lineas viven dentro' ($iAdd -gt $iGuarda -and $iMirar -gt $iGuarda) ''
Comp '  y solo hay una de cada' (
    @([regex]::Matches($cuerpoS, '\$script:entornoAvisos\.Add')).Count -eq 1 -and
    @([regex]::Matches($cuerpoS, '\$script:avisosMirar\.Add\(')).Count -eq 1) ''

Write-Host ''
Write-Host '-- F. contra el registro de verdad --'
$bajos = 0; $todos = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $r = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $r)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $r -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'ENTORNO \([^,]+, ([a-z]+)\)') { $todos++; if ($Matches[1] -eq 'bajo') { $bajos++ } }
    }
}
Write-Host ("       $bajos de $todos avisos del registro son de nivel 'bajo'")
Comp 'los mudos son una parte gorda de los avisos' ($todos -ge 20 -and $bajos -ge ($todos * 0.15)) (
    "{0:N1} %; medido antes: 26 de 97" -f $(if ($todos) { 100.0 * $bajos / $todos } else { 0 }))

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos MAL"; exit 1 }
Write-Host '  lo que no se dice no gasta turno'
exit 0
