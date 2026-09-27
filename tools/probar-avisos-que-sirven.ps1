# QUE NOVA MIDA SI SUS AVISOS SIRVEN (25/09, idea 24 de las cincuenta)
#
# LO MEDIDO sobre los 81 avisos que Nova ha dicho de verdad en quince dias, mirando si braya le
# hablo en los cinco minutos siguientes:
#
#   ruido en el micro     32 avisos (40 % del total)  ->  reacciono 2 veces   (6 %)
#   bateria llena         20 avisos (25 %)            ->  reacciono 3 veces   (15 %)
#   hora de dormir         7                          ->  reacciono 3 veces   (43 %)
#   poco disco             6                          ->  reacciono 2 veces   (33 %)
#   el correo de la manana 3                          ->  reacciono 2 veces   (67 %)
#   se cerro el juego      3                          ->  reacciono 2 veces   (67 %)
#
# O sea que Nova gasta el 64 % de su voz en los DOS avisos que menos mueven a braya, y los que
# si le interesan los dice tres veces cada uno. Eso es lo que hay detras de la proporcion del
# 24/09: hablo 21 veces por su cuenta por UNA que la llamaron.
#
# LA SALVEDAD, y va escrita aqui porque importa: "hablarle despues" no mide todo. Si Nova dice
# que hay ruido y braya se levanta y apaga un ventilador sin decirle nada, eso cuenta como "no
# reacciono". Por eso lo que se hace NO es callar un aviso, sino ESPACIARLO: si algo no mueve a
# braya, se dice menos veces, nunca cero. Un aviso que no sirve y se dice cada media hora es
# ruido; el mismo cada seis horas sigue estando ahi el dia que si importe.
#
# Y POR ESO HACE FALTA UN MINIMO DE MUESTRAS: con tres avisos no se sabe nada. El liston son 8,
# que es donde el aviso mas repetido (32) ya tiene cuatro tandas y los raros no se tocan.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. existe, se apunta y se usa --'
Comp 'existe Get-EsperaAviso' ($sinCom -match 'function Get-EsperaAviso') ''
# QUE SE ESCRIBAN, NO SOLO QUE APAREZCAN (25/09, lo cazaron dos roturas): "aviso-sirvio:"
# tambien sale en Get-ReaccionesAviso, que es quien LEE el contador. Buscar la cadena a secas
# daba verde aunque se borrara el sitio donde se APUNTA, que es justo lo que importa.
Comp 'y se apunta cuando el aviso SI movio algo' ($sinCom -match 'Add-Estadistica \("aviso-sirvio:') 'braya hablo dentro de la ventana'
Comp 'y cuando no movio nada' ($sinCom -match 'Add-Estadistica \("aviso-nada:') 'la ventana vencio en silencio'
Comp 'la ventana mide lo mismo que la medicion que lo justifica' ($sinCom -match '\$AvisoReaccionVentanaMs = 300000') '5 min, como la tabla del registro'
# LA LLAMADA, NO LA DEFINICION (25/09, lo cazo una rotura): "Get-EsperaAviso" a secas encuentra
# la propia "function Get-EsperaAviso", asi que borrar su uso dejaba el banco verde con la
# funcion muerta dentro del archivo.
$usos = @([regex]::Matches($sinCom, '(?<!function )Get-EsperaAviso')).Count
Comp 'Test-PuedoAvisar usa la espera aprendida' ($usos -ge 1) "$usos uso(s) ademas de la definicion"
# Y LA GUARDA DE LO CRITICO, EN SU SITIO (lo cazo otra rotura): "nivel -eq 'alto'" aparece en
# varios puntos del archivo por otras razones, asi que se mira el bloque que decide la espera.
$iE = $sinCom.IndexOf('$espera = ')
$blE = if ($iE -gt 0) { $sinCom.Substring($iE, [Math]::Min(260, $sinCom.Length - $iE)) } else { '' }
Comp 'y lo critico no se espacia nunca' ($blE -match "nivel -eq 'alto'" -and $blE -match 'Get-EsperaAviso') 'un aviso urgente no se aprende a callar'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-EsperaAviso' }, $true)
if (-not $d) {
    Comp 'se saca Get-EsperaAviso del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
# y sus constantes, del archivo (manera 6: nunca una copia propia)
foreach ($cte in @('AvisoReaccionMin', 'AvisoEsperaTope')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim()) }
}
function Log([string]$m) { }

# el doble de la fuente de datos, DESPUES de cargar (manera 9)
$script:reacciones = @{}
function Get-ReaccionesAviso([string]$clave) {
    if ($script:reacciones.ContainsKey($clave)) { return $script:reacciones[$clave] }
    return @()
}

Comp 'sin datos, la espera no cambia' ((Get-EsperaAviso 'lo-que-sea' 60) -eq 60) 'con tres avisos no se sabe nada'

# POCAS MUESTRAS: aunque no sirva ninguna, todavia no se toca
$script:reacciones['pocas'] = @($false) * 4
Comp 'con 4 muestras tampoco' ((Get-EsperaAviso 'pocas' 60) -eq 60) "minimo $AvisoReaccionMin"

# EL CASO REAL DE oido-ruido: 32 avisos, 2 reacciones (6 %)
$script:reacciones['ruido'] = @(@($true) * 2 + @($false) * 30)
$e = Get-EsperaAviso 'ruido' 60
Comp 'un aviso que casi nunca mueve nada se espacia' ($e -gt 60) "$e min en vez de 60"
Comp '  pero no se calla del todo' ($e -le ($AvisoEsperaTope * 60) -and $e -lt 100000) "tope $AvisoEsperaTope h"

# EL CASO DE correo-manana: 3 de 3 (100 %) -> pocas muestras, no se toca
$script:reacciones['correo'] = @($true) * 3
Comp 'uno que si sirve, con pocas muestras, no se toca' ((Get-EsperaAviso 'correo' 60) -eq 60) ''

# UNO QUE SIRVE Y TIENE MUESTRAS: no se espacia
$script:reacciones['util'] = @(@($true) * 7 + @($false) * 3)
Comp 'uno que sirve no se espacia' ((Get-EsperaAviso 'util' 60) -eq 60) '70 % de reaccion'

# Y SI EMPIEZA A SERVIR, VUELVE: lo aprendido no es una condena
$script:reacciones['ruido'] = @(@($true) * 9 + @($false) * 3)
Comp 'y si vuelve a servir, recupera su ritmo' ((Get-EsperaAviso 'ruido' 60) -eq 60) 'lo aprendido se puede desaprender'

# EL TOPE, CON UNA BASE QUE LO ALCANCE (25/09, lo cazo una rotura). Con base 60 el peor caso
# da 60 x 4 = 240, que ya cabe en el tope de 360: quitar el tope no cambiaba nada y la rotura
# salia verde. Con una base de 180 el peor caso son 720 y el tope tiene que morder.
$script:reacciones['nunca'] = @($false) * 100
$e = Get-EsperaAviso 'nunca' 180
Comp 'el tope muerde de verdad' ($e -le ($AvisoEsperaTope * 60)) "$e min con base 180, tope $($AvisoEsperaTope * 60)"
Comp '  y sin el se iria a 720' (($AvisoEsperaTope * 60) -lt 720) 'por eso hace falta'
$e2 = Get-EsperaAviso 'nunca' 60
Comp 'y con una base normal, cuatro veces mas' ($e2 -eq 240) "$e2 min en vez de 60"

Write-Host ''
Write-Host '-- MIRA VARIOS AVISOS A LA VEZ, NO UNO (27/09, idea 91 de las 121) --'
# EL DATO: de los 103 avisos de los dos registros, 76 suenan, y ONCE de esos 76 tienen otro aviso
# que suena dentro de los cinco minutos de la ventana (huecos de 14, 15, 15, 28, 50, 54, 77, 78,
# 209, 239 y 266 s). Con la version de UN solo aviso en observacion, el segundo pisaba al primero
# y el primero se quedaba sin apuntar ni 'sirvio' ni 'nada': una medicion de cada siete perdida,
# con 12 muestras guardadas en total.
#
# Y LO QUE PISABA ERA EL AVISO MENOS UTIL: 'oido-ruido' es el segundo en cinco de esos once pares
# y es el que menos mueve a braya (2 reacciones de 32). El mecanismo que existe para espaciarlo se
# quedaba sin datos justo por su culpa.
#
# LOS TRES TROZOS SE SACAN DEL FICHERO Y SE EJECUTAN. No estan en funciones propias -viven dentro
# de Send-AvisoEntorno, Start-Dictado y el bucle principal-, asi que se cortan por texto con
# asserts de que se cogio lo que se queria.
$lin = [IO.File]::ReadAllLines($PS1)
function Equilibrio([string]$l) {
    $c = (($l -replace "'[^']*'", "''") -replace '"[^"]*"', '""')
    $c = ($c -split '#')[0]
    return (@([regex]::Matches($c, '\{')).Count - @([regex]::Matches($c, '\}')).Count)
}
function CortarDesde([int]$i0) {
    $prof = 0
    for ($i = $i0; $i -lt $lin.Count; $i++) {
        $prof += Equilibrio $lin[$i]
        if ($prof -le 0) { return ($lin[$i0..$i] -join "`n") }
    }
    return ''
}
# los dos 'if ($script:avisosMirar.Count -gt 0)': uno apunta 'sirvio' y el otro 'nada'
$trozoSirvio = ''; $trozoNada = ''; $trozoObs = ''
for ($i = 0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*if \(\$script:avisosMirar\.Count -gt 0\) \{') {
        $b = CortarDesde $i
        if ($b -match 'aviso-sirvio') { $trozoSirvio = $b }
        elseif ($b -match 'aviso-nada') { $trozoNada = $b }
    }
    if ($lin[$i] -match '^\s*\[void\]\$script:avisosMirar\.Add\(') {
        # el Add mas el while del tope: cuatro lineas, y se comprueba que son esas
        $trozoObs = ($lin[$i..($i + 4)] -join "`n")
    }
}
Comp 'se saca del fichero el trozo que pone en observacion' (($trozoObs -match 'avisosMirar\.Add\(') -and ($trozoObs -match 'RemoveAt\(0\)')) ([string]@($trozoObs -split "`n").Count + ' lineas')
Comp '  el que apunta que SIRVIO' (($trozoSirvio -match 'aviso-sirvio') -and ($trozoSirvio -match 'Clear\(\)')) ([string]@($trozoSirvio -split "`n").Count + ' lineas')
Comp '  y el que apunta que NO movio nada' (($trozoNada -match 'aviso-nada') -and ($trozoNada -match 'RemoveAt\(\$iM\)')) ([string]@($trozoNada -split "`n").Count + ' lineas')
Comp '  y ninguno se paso de tamano' ((@($trozoSirvio -split "`n").Count -lt 20) -and (@($trozoNada -split "`n").Count -lt 20)) 'si crece de golpe, el corte caso donde no debia'
Comp 'y ya no queda ni una mencion al de uno solo' (-not ($txt -match '\$script:avisoMirar\b')) 'el nombre viejo se fue entero'

# EL MUNDO DE MENTIRA, DESPUES de cortar los trozos. $sw se dobla con un objeto cuyo reloj se
# mueve a mano: es lo unico que decide cuando vence una ventana.
$sw = [pscustomobject]@{ ElapsedMilliseconds = 0 }
$script:apuntes = @()
$script:lineas = @()
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) { $script:apuntes += @($ruta) }
function Log([string]$m) { $script:lineas += @($m) }
$AvisosMirarMax = 4
$AvisoReaccionVentanaMs = 300000
$script:avisosMirar = New-Object System.Collections.ArrayList
$fObs = [scriptblock]::Create("function Observar([string]`$clave) {`n$trozoObs`n}")
$fSir = [scriptblock]::Create("function Hablo {`n$trozoSirvio`n}")
$fNad = [scriptblock]::Create("function Vencer {`n$trozoNada`n}")
. $fObs; . $fSir; . $fNad
function ResetM { $script:avisosMirar.Clear(); $script:apuntes = @(); $script:lineas = @(); $sw.ElapsedMilliseconds = 0 }

# 1. EL CASO REAL QUE SE PERDIA: los 14 s del 23/09 (disco-poco y 14 s despues oido-ruido)
ResetM
Observar 'disco-poco'
$sw.ElapsedMilliseconds = 14000
Observar 'oido-ruido'
Comp 'los dos avisos siguen en observacion' ($script:avisosMirar.Count -eq 2) ([string]$script:avisosMirar.Count)
$sw.ElapsedMilliseconds = 60000
Hablo
Comp '  y al hablar se apunta UNA reaccion' (@($script:apuntes | Where-Object { $_ -match '^aviso-sirvio:' }).Count -eq 1) ([string]@($script:apuntes).Count + ' apunte(s)')
Comp '  a disco-poco, que llevaba mas rato esperando' ($script:apuntes -contains 'aviso-sirvio:disco-poco') ($script:apuntes -join ', ')
Comp '  y NO a oido-ruido, que es el que pisaba' (-not ($script:apuntes -contains 'aviso-sirvio:oido-ruido')) 'el empate se pierde a proposito'
Comp '  y se dice en el registro' (@($script:lineas | Where-Object { $_ -match 'empate' }).Count -eq 1) ''
Comp '  la lista queda vacia' ($script:avisosMirar.Count -eq 0) 'una frase no contesta a dos avisos'

# 2. Y LO QUE ANTES SE PERDIA, AHORA SE APUNTA COMO 'nada' SI NADIE HABLA
ResetM
Observar 'juego-cierra'
$sw.ElapsedMilliseconds = 50000
Observar 'oido-ruido'
$sw.ElapsedMilliseconds = 300001            # vence la ventana del primero
Vencer
Comp 'al vencer el primero se apunta que no movio nada' ($script:apuntes -contains 'aviso-nada:juego-cierra') ($script:apuntes -join ', ')
Comp '  y el segundo sigue esperando su turno' ($script:avisosMirar.Count -eq 1 -and $script:avisosMirar[0].clave -eq 'oido-ruido') ([string]$script:avisosMirar.Count)
$sw.ElapsedMilliseconds = 350002
Vencer
Comp '  y cuando le toca, tambien se apunta' ($script:apuntes -contains 'aviso-nada:oido-ruido') 'antes esta muestra no existia'
Comp '  sin dejar nada dentro' ($script:avisosMirar.Count -eq 0) ''

# 3. LO QUE NO PUEDE PASAR: que un aviso se apunte DOS veces
ResetM
Observar 'disco-poco'
$sw.ElapsedMilliseconds = 60000
Hablo
$sw.ElapsedMilliseconds = 400000
Vencer
Comp 'un aviso que sirvio no se apunta tambien como que no' (@($script:apuntes | Where-Object { $_ -match 'disco-poco' }).Count -eq 1) ($script:apuntes -join ', ')

# 4. Y HABLAR SIN NINGUN AVISO DELANTE NO APUNTA NADA
ResetM
Hablo
Comp 'hablar sin avisos en observacion no apunta nada' (@($script:apuntes).Count -eq 0) ([string]@($script:apuntes).Count)
Comp '  ni escribe en el registro' (@($script:lineas).Count -eq 0) 'un dictado normal no dice nada de esto'

# 5. EL TOPE, que existe para que una tanda de avisos no llene la lista
ResetM
foreach ($k in @('a', 'b', 'c', 'd', 'e', 'f')) { Observar $k }
Comp 'la lista no pasa de su tope' ($script:avisosMirar.Count -le $AvisosMirarMax) ([string]$script:avisosMirar.Count + ' de ' + [string]$AvisosMirarMax)
Comp '  y se van los mas viejos, no los nuevos' ($script:avisosMirar[($script:avisosMirar.Count - 1)].clave -eq 'f') ([string]$script:avisosMirar[($script:avisosMirar.Count - 1)].clave)
Comp '  diciendo que salen sin medir' (@($script:lineas | Where-Object { $_ -match 'sin medir' }).Count -eq 2) ([string]@($script:lineas | Where-Object { $_ -match 'sin medir' }).Count)
Comp '  y el tope sale del archivo' ($txt -match '\$AvisosMirarMax = 4') 'medido: nunca se juntaron mas de dos'

# 6. Y LOS QUE NO SUENAN SIGUEN SIN ENTRAR: de un aviso que nadie oyo no se deduce nada
$blSA = ''
for ($i = 0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match "^\s*if \(\`$nivel -ne 'bajo'\) \{") { $blSA = CortarDesde $i; break }
}
Comp 'la observacion vive dentro del if de nivel' (($blSA -match 'avisosMirar\.Add\(') -and ($blSA.Length -gt 0)) 'los "bajo" no suenan: de esos no se puede deducir si movieron algo'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova aprende que avisos te mueven'
exit 0
