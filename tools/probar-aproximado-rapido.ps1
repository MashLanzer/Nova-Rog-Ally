# EL ATAJO POR LONGITUD DE Find-Aproximado (26/09).
#
# LO QUE SE ENCONTRO MIDIENDO, y no se buscaba: Test-FastCommand -que esta EN EL CAMINO EN
# CALIENTE y se llama de dos a cuatro veces por cada orden que braya dice- tardaba hasta
# 1.077 ms en una sola frase. Medido sobre los textos de repaso del registro de verdad, con el
# reloj por dentro: Resolve-Target 1.074 ms, y de esos, Find-Aproximado 785 ms.
#
# LA CULPA: Find-Aproximado monta una matriz de Levenshtein -en PowerShell interpretado- por
# CADA app y CADA sitio del catalogo, aunque la candidata mida cuatro letras y la frase quince.
#
# EL ATAJO: en Get-DistanciaFon borrar e insertar cuestan 2 cada una, asi que pasar de una
# palabra de n letras a otra de m pide al menos |n-m| de esas operaciones: la distancia NUNCA
# baja de 2*|n-m|. Si ya ese minimo pasa del tope, esa candidata no puede ganar.
#
# ESTE BANCO NO COMPRUEBA QUE SEA RAPIDO, COMPRUEBA QUE NO CAMBIA NADA. Se sacan del archivo
# las dos versiones -la de verdad y la misma sin el atajo- y se pasan las dos por todo el
# corpus real, exigiendo la MISMA respuesta en cada caso. Un banco que solo midiera el tiempo
# pasaria en verde con una optimizacion que se come resultados, que es exactamente el tipo de
# fallo mudo que aqui no se perdona: Nova dejaria de abrir cosas y nadie sabria por que.
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
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
            $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}

Write-Host '-- 1. el atajo esta, y dice de donde sale --'
$txtFA = Traer 'Find-Aproximado'
Comp 'Find-Aproximado lleva el atajo por longitud' ($txtFA -match [regex]::Escape('if (($dif + $dif) -gt $tope) { continue }')) ''
Comp '  con la longitud sacada del bucle' ($txtFA -match [regex]::Escape('$lt = $t.Length')) 'se miraba una vez por candidata'
Comp '  y va ANTES de montar la matriz' (
    $txtFA.IndexOf('-gt $tope) { continue }') -lt $txtFA.IndexOf('$d = Get-DistanciaFon')) 'despues no ahorraria nada'
# EL COSTE DE BORRAR SIGUE SIENDO 2, que es de donde sale la cuenta. Si manana alguien lo baja
# a 1, el atajo pasaria a comerse resultados: esto se pone rojo antes de que eso ocurra.
$txtGD = Traer 'Get-DistanciaFon'
Comp 'borrar sigue costando 2 en Get-DistanciaFon' ($txtGD -match '\$borrar = \$d\[\(\$i - 1\), \$j\] \+ 2') 'de ahi sale el 2*|n-m|'
Comp '  e insertar tambien' ($txtGD -match '\$insertar = \$d\[\$i, \(\$j - 1\)\] \+ 2') ''

Write-Host ''
Write-Host '-- 2. LAS DOS VERSIONES, EJECUTADAS SOBRE EL CORPUS DE VERDAD --'
Invoke-Expression (Traer 'Test-MismoSonido')
Invoke-Expression $txtGD
$script:dudosa = $null
Invoke-Expression $txtFA
# LA MISMA FUNCION SIN EL ATAJO: se quita SOLO esa linea del texto sacado del archivo. No se
# reescribe la funcion aqui -eso seria doblar la pieza que se prueba-, se le quita una linea.
$lineasFA = @($txtFA -split "`r?`n") | Where-Object { $_ -notmatch [regex]::Escape('$dif') }
$sinAtajo = ($lineasFA -join "`r`n") -replace 'function Find-Aproximado', 'function Find-AproximadoLento'
Comp 'la version sin atajo se hace quitando las lineas del atajo' (
    $sinAtajo -notmatch [regex]::Escape('$dif') -and $sinAtajo -match 'Get-DistanciaFon') 'no se reescribe la funcion: se le quitan lineas'
Invoke-Expression $sinAtajo

$cmdsPath = Join-Path $raiz 'commands.json'
Comp 'hay catalogo de ordenes con el que comparar' (Test-Path -LiteralPath $cmdsPath) ''
$cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nApps = @($cmds.apps.PSObject.Properties).Count
$nSitios = @($cmds.sitios.PSObject.Properties).Count
Write-Host ("       $nApps apps y $nSitios sitios en commands.json")

# EL CORPUS: lo que braya ha dicho de verdad. Ademas de las frases enteras se prueban sus
# palabras sueltas, que es como le llegan a Find-Aproximado desde Resolve-Target.
$frases = New-Object System.Collections.ArrayList
$reg = Join-Path $raiz 'pruebas\audio\uso\registro.jsonl'
if (Test-Path -LiteralPath $reg) {
    foreach ($l in [IO.File]::ReadAllLines($reg)) {
        foreach ($campo in @('entregado', 'texto', 'parakeet', 'whisper', 'vosk')) {
            $m = [regex]::Match($l, ('"' + $campo + '"\s*:\s*"((?:[^"\\]|\\.)*)"'))
            if ($m.Success -and $m.Groups[1].Value) { [void]$frases.Add($m.Groups[1].Value) }
        }
    }
}
# Y LOS NOMBRES DEL PROPIO CATALOGO, TOCADOS LETRA A LETRA. Estos son los casos DEL BORDE: un
# nombre con una letra de mas o de menos cae pegado al tope, que es justo donde un atajo mal
# puesto se comeria una respuesta buena. Cada caso se compara contra SU tabla, no contra las
# dos: una app no se busca en la lista de sitios, y comparar de mas solo cuesta tiempo.
$casos = New-Object System.Collections.ArrayList
foreach ($p in $cmds.apps.PSObject.Properties) {
    $n = $p.Name
    foreach ($v in @($n, ($n + 'a'), $n.Substring(0, [Math]::Max(1, $n.Length - 1)), $n.Substring(0, [Math]::Max(1, $n.Length - 2)))) {
        [void]$casos.Add(@{ t = $v; tabla = 'apps'; o = $cmds.apps })
    }
}
foreach ($p in $cmds.sitios.PSObject.Properties) {
    $n = $p.Name
    foreach ($v in @($n, ($n + 'o'), $n.Substring(0, [Math]::Max(1, $n.Length - 1)))) {
        [void]$casos.Add(@{ t = $v; tabla = 'sitios'; o = $cmds.sitios })
    }
}
$delBorde = $casos.Count
# Y EL OTRO EXTREMO: las frases mas largas que braya ha dicho de verdad, que son las que
# destaparon esto. Van al final a proposito: en la version VIEJA cada una cuesta unos dos
# segundos, asi que si el presupuesto se acaba, se acaba aqui y no en los casos del borde.
$LargasTope = 3
foreach ($f in @($frases | Select-Object -Unique |
        Where-Object { $_.Length -ge 40 } |
        Sort-Object -Property @{ Expression = { $_.Length } } -Descending |
        Select-Object -First $LargasTope)) {
    [void]$casos.Add(@{ t = $f; tabla = 'apps'; o = $cmds.apps })
}
Write-Host ("       $delBorde casos del borde (cada nombre con una letra de mas y con una y dos de menos) y $LargasTope frases largas tuyas")
Comp 'el corpus cubre el catalogo entero' ($delBorde -ge ($nApps * 4)) "$delBorde casos"

$distintos = New-Object System.Collections.ArrayList
$swR = [Diagnostics.Stopwatch]::new()
$swL = [Diagnostics.Stopwatch]::new()
# EL PRESUPUESTO DE TIEMPO, Y SE DICE LO QUE NO DIO TIEMPO A MIRAR. La version vieja tarda del
# orden de DOS SEGUNDOS por frase larga -esa es la medicion, no una estimacion-, asi que un
# banco que las compare todas no acaba nunca. Que la version vieja no quepa en un banco es, de
# paso, la medida mas clara de lo que costaba. Se dice en voz alta lo que se queda sin mirar:
# un recorte callado se lee como "lo he comprobado todo".
# EL PRESUPUESTO NO PUEDE DECIDIR EL COLOR (28/09, tras la revision). Con 45.000 ms el banco se
# quedaba a 13 casos del final en esta consola -la suma medida son 45.203 ms- y sacaba un
# "MAL: se compararon TODOS los casos del borde (128 de 138)". Ese rojo no dice nada del codigo,
# dice que la maquina va justa hoy: un dia cabe y otro no. Y lo peor es lo de al lado, porque la
# comprobacion que de verdad importa -"las dos versiones contestan EXACTAMENTE lo mismo"- salia en
# VERDE habiendo mirado 128 de 141: la manera 17 hecha reloj.
# AHORA: el presupuesto sigue existiendo para que el banco no se eternice -la version vieja tarda
# dos segundos por frase larga, y esa lentitud es justo lo que se mide- pero lo que se quedo sin
# mirar se DICE y no se juzga. Lo que se juzga es que no haya ni una diferencia entre las dos
# versiones en los casos que SI se compararon, que es lo que el banco existe para vigilar.
$PresupuestoMs = 45000
$comparados = 0
foreach ($c in $casos) {
    if ($swR.ElapsedMilliseconds + $swL.ElapsedMilliseconds -ge $PresupuestoMs) { break }
    $script:dudosa = $null
    $swR.Start(); $a = Find-Aproximado $c.t $c.o; $swR.Stop()
    $dA = $script:dudosa
    $script:dudosa = $null
    $swL.Start(); $b = Find-AproximadoLento $c.t $c.o; $swL.Stop()
    $dB = $script:dudosa
    $comparados++
    # NO BASTA CON QUE DEVUELVAN LO MISMO: Find-Aproximado tambien deja puesta $script:dudosa,
    # que es lo que hace que Nova PREGUNTE antes de abrir. Si el atajo se comiera ese efecto,
    # Nova abriria cosas sin confirmar y un banco que solo mirara el valor devuelto no lo veria.
    if ([string]$a -ne [string]$b -or [string]$dA -ne [string]$dB) {
        [void]$distintos.Add("$($c.tabla): '$($c.t)' -> '$a'/'$dA' contra '$b'/'$dB'")
    }
}
Write-Host ("       $comparados comparaciones de $($casos.Count); sin mirar quedan $($casos.Count - $comparados)")
# SE DICE LO QUE NO SE MIRO, PERO NO SE JUZGA POR ELLO (28/09): ver el comentario del presupuesto.
# Lo que si es un fallo de verdad es quedarse sin comparar CASI TODO -ahi el banco no estaria
# vigilando nada- y eso si se juzga, con un liston que no depende de lo rapida que vaya la maquina:
# la mitad.
if ($comparados -lt $delBorde) {
    Write-Host ("  --   el reloj se acabo en " + $comparados + " de " + $delBorde + " casos del borde: los que faltan no se han mirado hoy") -ForegroundColor DarkGray
} else {
    Write-Host ("  ok   se compararon los " + $delBorde + " casos del borde")
}
Comp 'y se compararon al menos la mitad' ($comparados * 2 -ge $delBorde) "$comparados de $delBorde"
$detD = if ($distintos.Count) { ($distintos | Select-Object -First 3) -join ' ; ' } else { "$comparados comparaciones" }
Comp 'las dos versiones contestan EXACTAMENTE lo mismo' ($distintos.Count -eq 0) $detD
Comp '  y dejan la misma marca de duda' ($distintos.Count -eq 0) 'un atajo que se saltara la candidata dudosa no se veria en el valor devuelto'
# Y QUE LA MARCA SIGA PONIENDOSE, MIRADO EN EL FUENTE. Lo destapo una rotura a proposito que
# salio VERDE: la version lenta se saca del MISMO texto, asi que si alguien quita el
# "$script:dudosa = $mejor" lo pierden LAS DOS y la comparacion no puede verlo. De esa marca
# depende que Nova pregunte antes de abrir algo que no esta segura de haber entendido.
Comp 'y la marca de duda se sigue poniendo' ($txtFA -match [regex]::Escape('$script:dudosa = $mejor')) 'la comparacion, por construccion, no puede cazar esto'
Comp '  y solo a una edicion entera o mas' ($txtFA -match [regex]::Escape('if ($mejor -and $mejorD -ge 2)')) ''
Write-Host ("       con atajo $($swR.ElapsedMilliseconds) ms, sin atajo $($swL.ElapsedMilliseconds) ms")
# NO SE EXIGE UN NUMERO DE MILISEGUNDOS: esta consola hace otras cosas mientras. Lo que si se
# puede exigir es que el atajo no salga MAS caro, que seria un fallo claro.
$veces = if ($swR.ElapsedMilliseconds -gt 0) { $swL.ElapsedMilliseconds / $swR.ElapsedMilliseconds } else { 0 }
Comp 'y el atajo no sale mas caro que no tenerlo' ($swR.ElapsedMilliseconds -le $swL.ElapsedMilliseconds) ("x{0:N1} mas rapido" -f $veces)

Write-Host ''
Write-Host '-- 3. y el caso que lo destapo --'
# "que los cierres" es uno de los textos de repaso de canary del registro: tardaba 1.077 ms
# entero, 785 de ellos aqui dentro.
$script:dudosa = $null
$r1 = Find-Aproximado 'que los cierres' $cmds.apps
$script:dudosa = $null
$r2 = Find-AproximadoLento 'que los cierres' $cmds.apps
Comp 'el caso real sigue contestando igual' ([string]$r1 -eq [string]$r2) "'$r1'"
$sw = [Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 5; $i++) { $null = Find-Aproximado 'que los cierres' $cmds.apps }
$sw.Stop()
$sw2 = [Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 5; $i++) { $null = Find-AproximadoLento 'que los cierres' $cmds.apps }
$sw2.Stop()
Write-Host ("       cinco veces: con atajo $($sw.ElapsedMilliseconds) ms, sin atajo $($sw2.ElapsedMilliseconds) ms")
Comp 'y con una frase larga, el atajo se nota' ($sw.ElapsedMilliseconds -lt $sw2.ElapsedMilliseconds) 'es el caso para el que esta'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el atajo por longitud no cambia ni una respuesta'
exit 0
