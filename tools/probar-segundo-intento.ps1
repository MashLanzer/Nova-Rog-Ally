# APRENDER DEL SEGUNDO INTENTO (26/09, idea 24 de las 121).
#
# CUANDO braya dice algo, Nova no lo entiende, y a los pocos segundos lo repite de otra forma y
# ESO SI funciona, ahi hay una traduccion regalada: lo que dijo mal es lo mismo que lo que dijo
# bien, y las dos lineas ya estan en el registro sin que nadie las cruce.
#
# MEDIDO sobre los 714 dictados con texto de los dos registros: SEIS pares reales.
#
# LA TRAMPA NUMERO UNO, Y ESTE BANCO EXISTE PARA CAZARLA: la idea proponia un parecido de 0,75,
# pero ese 0,75 sale de SequenceMatcher, que es de Python. Aqui la metrica que existe es
# Get-Distancia (Levenshtein), y con ella los seis pares dan 0,662 a 0,889: con 0,75 se pierden
# TRES de los seis. Los seis pares estan escritos abajo con sus textos y sus segundos reales,
# asi que poner 0,75 "porque lo dice la idea" pone este banco rojo.
#
# Y LA ROTURA PELIGROSA DE VERDAD: que falte la marca del camino de la nube. El 22/09 a la
# 01:09 'Si es Steam' murio en la capa local, la nube la tradujo a 'abre steam' y Nova ABRIO
# Steam; 17 s despues braya dijo 'Sierra Steam'. Sin esa marca se aprenderia
# 'si es steam' = cerrar Steam, y a partir de ahi ese mal oido CERRARIA Steam. Regla 1 rota, y
# no es hipotetico: esta en el log.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$fuente = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
            $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}

Write-Host '-- 1. los dos numeros, contra los pares de verdad --'
foreach ($c in @('RepeticionVentanaMs', 'RepeticionParecido', 'RepeticionLargoMax')) {
    $m = [regex]::Match($fuente, ('(?m)^\$' + $c + '\s*=\s*([0-9.]+)\s*$'))
    Comp ("se saca del archivo " + $c) $m.Success 'a columna cero y en su propia linea'
    if ($m.Success) { Set-Variable -Name $c -Value ([double]$m.Groups[1].Value) }
}
# NO SE COMPARA LA CONSTANTE CONSIGO MISMA: se comprueba que cae donde la medicion la deja.
Comp 'el parecido deja pasar el par mas justo' ($RepeticionParecido -le 0.662) (
    "$RepeticionParecido; el par mas flojo de los seis da 0,662")
Comp '  y no baja tanto como para colar basura' ($RepeticionParecido -ge 0.55) 'con 0,50 entran claves que no sirven'
Comp 'la ventana cubre el hueco real mas largo' ($RepeticionVentanaMs -ge 42000) "$([int]($RepeticionVentanaMs/1000)) s; el mayor de los seis son 42"
Comp '  y no se pasa' ($RepeticionVentanaMs -le 60000) 'de 45 a 180 s no entra NI UN par mas en catorce dias'

Write-Host ''
Write-Host '-- 2. LOS SEIS PARES DE VERDAD, ejecutados --'
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Test-SegundoIntento')
function Par([string]$antes, [string]$ahora, [int]$seg, [string]$llego = 'nada') {
    $p = @{ texto = $antes; plano = (ConvertTo-Plain $antes); cuando = 0.0; llego = $llego }
    return (Test-SegundoIntento $p (ConvertTo-Plain $ahora) ([double]($seg * 1000)))
}
# Los seis del registro, con sus textos y sus segundos. Si alguien sube el parecido a 0,75,
# tres de estos seis dejan de pasar y el banco lo dice con el nombre delante.
$pares = @(
    @{ a = 'DINTA, CORREO'; b = 'Dicta un correo'; s = 12 },
    @{ a = 'Cierra Do'; b = 'Cierra todo'; s = 15 },
    @{ a = 'Si es Steam'; b = 'Sierra Steam'; s = 17 },
    @{ a = 'Ok, y de los juegos que tengo ahi'; b = 'Dime de los juegos que tengo de Steam'; s = 29 },
    @{ a = 'O abrir al cincuenta por ciento'; b = 'Tuvo el brillo al cincuenta por ciento'; s = 30 },
    @{ a = 'Tiktam un correo en el bloc de notas'; b = 'Dicta, un correo en el blog de notas'; s = 42 })
foreach ($p in $pares) {
    $pl1 = ConvertTo-Plain $p.a; $pl2 = ConvertTo-Plain $p.b
    $par = 1.0 - ((Get-Distancia $pl1 $pl2) / [double][Math]::Max($pl1.Length, $pl2.Length))
    Comp ("'" + $p.a + "' -> '" + $p.b + "'") ([bool](Par $p.a $p.b $p.s)) ("$($p.s) s, parecido {0:N3}" -f $par)
}

Write-Host ''
Write-Host '-- 3. y lo que NO tiene que pasar --'
# EL PRIMER INTENTO TIENE QUE HABER MUERTO. Caso real: 'Activa Bluetooth' y 'Activa el
# Bluetooth' a 11 s, parecido 0,90, pero la primera se ejecuto bien. Aprenderlas seria decir
# que la primera estaba mal.
Comp 'si el primero SI llego, no se aprende' (-not (Par 'Activa Bluetooth' 'Activa el Bluetooth' 11 'local')) (
    'parecido 0,90, pero aquella funciono')
Comp 'pasada la ventana, tampoco' (-not (Par 'Cierra Do' 'Cierra todo' 120)) '120 s'
Comp 'y dos frases distintas no se parecen' (-not (Par 'Abre Steam' 'Que hora es' 10)) ''
# LA FRASE IDENTICA NO ES UNA CORRECCION: es que lo dijo dos veces.
Comp 'ni la misma frase repetida clavada' (-not (Par 'Abre Steam' 'Abre Steam' 10)) 'eso no corrige nada'
Comp 'sin previo, no hay nada que aprender' (-not (Test-SegundoIntento $null 'abre steam' 1000.0)) ''
# $null VALE 0 EN UNA COMPARACION NUMERICA: un previo a medio hacer pasaria por "hace un momento".
# UN PREVIO A MEDIO HACER: con la hora sin poner, $null vale 0 en la resta y la entrada sale
# ANTIQUISIMA, que es el lado seguro. Se comprueba que de verdad cae por ahi y no por otro sitio.
$roto = @{ texto = 'x'; plano = 'cierra do'; cuando = $null; llego = 'nada' }
Comp 'y un previo sin hora se descarta por viejo' ([bool](Test-SegundoIntento $roto 'cierra todo' 90000.0) -eq $false) (
    'el $null vale 0, asi que la edad sale enorme: el lado seguro')
# EL TOPE DE LARGO: Get-Distancia es una matriz n x m y esto corre en el camino en caliente.
$largo = ('a' * ([int]$RepeticionLargoMax + 10))
$pL = @{ texto = $largo; plano = $largo; cuando = 0.0; llego = 'nada' }
Comp 'una frase larguisima ni se compara' (-not (Test-SegundoIntento $pL ($largo + 'b') 1000.0)) (
    "mas de $([int]$RepeticionLargoMax) caracteres")

Write-Host ''
Write-Host '-- 4. LA MARCA DEL CAMINO DE LA NUBE, que es la que evita el destrozo --'
# La rama de la traduccion aprendida ejecuta FUERA de Process-Texto. Sin su marca, una frase
# que la nube tradujo y Nova EJECUTO sigue contando como "no llego a nada".
$iN = $sinCom.IndexOf('$script:ultimaAprendida = $original')
Comp 'se encuentra la rama de la nube' ($iN -ge 0) ''
$blN = if ($iN -ge 0) { $sinCom.Substring($iN, [Math]::Min(260, $sinCom.Length - $iN)) } else { '' }
Comp '  y marca que la orden SI llego' ($blN -match "intentoActual\.llego = 'local'") (
    "el 22/09: 'Si es Steam' la abrio la nube y 17 s despues llego 'Sierra Steam'")

Write-Host ''
Write-Host '-- 5. las demas ramas que actuan tambien marcan --'
# Si falta una, esa frase contara como muerta y la siguiente orden parecida se aprendera
# encima. Son siete sitios: seis ramas locales mas la de la nube.
$n = @([regex]::Matches($sinCom, "intentoActual\.llego = 'local'")).Count
Comp 'las siete marcas estan puestas' ($n -eq 7) "$n"
foreach ($par in @(
        @{ n = 'la que pregunta antes de hacer'; a = 'Log "CONFIRMAR: ''$text'' -> $fast"' },
        @{ n = 'la orden local'; a = 'Set-UltimaOrden $text ([string]$fast)' },
        @{ n = 'la memoria local'; a = 'Log "MEMORIA LOCAL:' },
        @{ n = 'la traduccion ya aprendida'; a = 'Set-UltimaOrden $apr ([string]$r)' })) {
    $i = $sinCom.IndexOf($par.a)
    $bl = if ($i -ge 0) { $sinCom.Substring($i, [Math]::Min(200, $sinCom.Length - $i)) } else { '' }
    Comp ("marca " + $par.n) ($bl -match "intentoActual\.llego = 'local'") ''
}

Write-Host ''
Write-Host '-- 6. la captura, y el guarda del repaso --'
$iC = $sinCom.IndexOf('$script:intentoPrevio = $script:intentoActual')
Comp 'se capturan los dos ultimos intentos' ($iC -ge 0) ''
$blC = if ($iC -ge 0) { $sinCom.Substring([Math]::Max(0, $iC - 200), [Math]::Min(200, $iC)) } else { '' }
# SIN ESTE GUARDA el repaso del oido fino pisa la frase buena con su re-transcripcion del MISMO
# audio: 'Tiktam un correo en el bloc de notas' da 0,889 y lo que saco el repaso da 0,429.
Comp '  pero NO cuando es el repaso del mismo audio' ($blC -match '-not \$script:yaReintentado') (
    'el repaso se re-entra con su propia transcripcion')
Comp '  ni en modo invitado' ($blC -match '-not \$script:invitado') ''
# Y VA EN Process-Texto, que es el unico embudo: la llaman doce sitios.
$iP = $sinCom.IndexOf('function Process-Texto')
Comp '  y va dentro de Process-Texto' ($iP -ge 0 -and $iC -gt $iP) 'el unico embudo de las ordenes'

Write-Host ''
Write-Host '-- 7. y lo que se aprende, con sus dos frenos --'
$iA = $sinCom.IndexOf('Add-Traduccion $script:intentoPrevio.texto $text')
Comp 'se aprende la pareja' ($iA -ge 0) ''
# EL BLOQUE ENTERO, ACOTADO POR SU VECINO Y NO POR UN NUMERO DE CARACTERES: una ventana fija
# se queda corta en cuanto alguien anade una linea, y ya ha mordido tres veces hoy.
$iFinA = $sinCom.IndexOf('elseif ($plano -match $RE_MEMORIA)', [Math]::Max(0, $iA))
$iIniA = $sinCom.LastIndexOf('Test-SegundoIntento $script:intentoPrevio', [Math]::Max(0, $iA))
$blA = if ($iIniA -ge 0 -and $iFinA -gt $iIniA) { $sinCom.Substring($iIniA, $iFinA - $iIniA) } else { '' }
Comp '  y el bloque se lee entero' ($blA -ne '') ''
# EL MISMO FILTRO QUE YA EXISTE: solo se aprende lo que se puede repetir (15/09).
Comp '  solo si la clave se puede repetir' ($blA -match '\$palV\.Count -le 6\)') 'seis, no sesenta: el -le 6 casa dentro de -le 60'
Comp '  y queda dicho en el log' ($blA -match "me lo quedo") 'la rama del else tambien dice SEGUNDO INTENTO'
Comp '  y contado' ($blA -match "Add-Estadistica 'segundo-intento'") ''
# SE GASTA AL USARLO: si no, la misma pareja se aprende otra vez en la siguiente orden buena.
Comp '  y la pareja se gasta' ($blA -match '\$script:intentoPrevio = \$null') 'o se aprenderia otra vez en la siguiente'
# Y NO SE LE PONE Test-OidoDudoso, porque aqui el primer intento ES mal oido por definicion.
# SE MIRA LA LINEA DEL if ENTERA, no el bloque: un "(Test-OidoDudoso) -and" cabe DELANTE del
# ancla y se quedaria fuera. Lo destapo una rotura que salio verde.
$mIf = [regex]::Match($sinCom, '(?m)^.*Test-SegundoIntento \$script:intentoPrevio.*$')
Comp 'y NO se le aplica el freno de lo mal oido' ($mIf.Success -and $mIf.Value -notmatch 'Test-OidoDudoso') (
    'el primer intento es mal oido por definicion; lo que frena es la repeticion misma')

Write-Host ''
Write-Host '-- 8. contra el registro de verdad --'
$n = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match "\[escucha\] dictado: '[^']") { $n++ }
    }
}
Write-Host ("       $n dictados con texto en los dos registros; de ahi salen los seis pares")
Comp 'hay dictados de donde sacar los pares' ($n -ge 300) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  si te repites, lo aprendo'
exit 0
