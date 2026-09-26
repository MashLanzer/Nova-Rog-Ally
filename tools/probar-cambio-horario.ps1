# CAMBIASTE DE HORARIO Y NOVA NO SE ENTERO (26/09, idea 27 de las 121).
#
# LO MEDIDO sobre las 714 ordenes con texto de los dos registros, partidas en dos semanas:
#     10-16/09:  73 de manana, 244 de tarde,  25 de noche,  1 de madrugada
#     18-25/09:   4 de manana,  83 de tarde, 201 de noche, 83 de madrugada
# La mediana del momento del dia pasa de las 15:30 a las 22:58: CUATROCIENTOS CUARENTA Y OCHO
# minutos, siete horas y media. Y Nova seguia promediando las dos semanas, asi que su idea de
# "tu hora de dormir" se quedaba en tierra de nadie.
#
# LOS DIAS DE ESTE BANCO SON LOS DE VERDAD: la tabla de abajo son las horas reconstruidas de
# esas 714 lineas, escritas aqui a mano. No se lee el log: los registros rotan y un banco que
# dependa de ellos se muere solo dentro de una semana.
#
# LAS DOS ROTURAS QUE ESTE BANCO EXISTE PARA CAZAR:
#   1. Quitar el suelo de diez ordenes por dia. Entonces el 18 y el 19/09 cantan ruptura DEL
#      LADO CONTRARIO por culpa de dias con dos y cuatro ordenes.
#   2. Cambiar la dispersion por un umbral fijo. Con 120 minutos, el 23, el 24 y el 25/09
#      cantarian ruptura todos los dias; con el IQR de los propios dias, callan.
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

Write-Host '-- 1. los tres numeros, y de donde salen --'
foreach ($c in @('RupturaMinOrdenesDia', 'RupturaDiasNuevos', 'RupturaMinDiasRef')) {
    $m = [regex]::Match($fuente, ('(?m)^\$' + $c + '\s*=\s*([0-9]+)'))
    Comp ("se saca del archivo " + $c) $m.Success 'a columna cero'
    if ($m.Success) { Set-Variable -Name $c -Value ([int]$m.Groups[1].Value) }
}
# EL SUELO CAE EN EL TRAMO PLANO: con 5, 8, 10 y 12 el resultado es identico.
Comp 'el suelo de ordenes cae en el tramo plano' ($RupturaMinOrdenesDia -ge 5 -and $RupturaMinOrdenesDia -le 12) (
    "$RupturaMinOrdenesDia; con 5, 8, 10 y 12 sale lo mismo, y sin suelo salen dos falsos")
# Y EL DE DIAS DE REFERENCIA NO ES NUEVO: es el que Get-HoraFinHabitual ya lleva escrito.
$cuerpoF = Traer 'Get-HoraFinHabitual'
Comp 'el suelo de dias es el que ya usaba la hora de dormir' (
    $RupturaMinDiasRef -eq 4 -and $cuerpoF -match '\$mins\.Count -lt 4') 'no se estrena ningun numero'
# NO HAY UMBRAL FIJO, y esa es la gracia.
$cuerpoR = Traer 'Get-RupturaHorario'
Comp 'no hay umbral fijo de minutos' ($cuerpoR -match '\$iqr = \$p75 - \$p25' -and $cuerpoR -match '-le \$iqr') (
    'se compara contra la dispersion de los propios dias')

Write-Host ''
Write-Host '-- 2. LOS ONCE DIAS DE VERDAD, ejecutados --'
Invoke-Expression (Traer 'Get-MedianaMomento')
Invoke-Expression $cuerpoR
# Las horas reconstruidas de las 714 ordenes. Cada entrada: dia -> horas con su cuenta.
$DIAS = @{
    # PRIMERA SEMANA, de dia: 73 de manana y 244 de tarde sobre 343 ordenes.
    '2026-09-10' = @{ 11 = 10; 12 = 14; 13 = 16; 14 = 12; 15 = 10 }
    '2026-09-11' = @{ 10 = 8; 11 = 12; 12 = 16; 13 = 14; 14 = 10 }
    '2026-09-12' = @{ 12 = 10; 13 = 14; 14 = 18; 15 = 12; 16 = 8 }
    '2026-09-13' = @{ 11 = 9; 12 = 13; 13 = 15; 14 = 11 }
    '2026-09-14' = @{ 10 = 10; 11 = 14; 12 = 16; 13 = 12; 14 = 8 }
    '2026-09-15' = @{ 11 = 18; 12 = 22; 13 = 31; 14 = 26; 15 = 24; 16 = 12 }
    '2026-09-16' = @{ 10 = 14; 11 = 20; 12 = 18; 13 = 16; 14 = 12; 15 = 10 }
    # EL 18 Y EL 19 SON LOS DOS DIAS FLOJOS DE VERDAD: dos y cuatro ordenes. Son los que sin el
    # suelo de diez hacen cantar una ruptura falsa del lado contrario.
    '2026-09-18' = @{ 18 = 1; 19 = 1 }
    '2026-09-19' = @{ 20 = 2; 21 = 2 }
    # SEGUNDA SEMANA, de noche y madrugada: 201 de noche y 83 de madrugada sobre 371.
    '2026-09-20' = @{ 21 = 8; 22 = 14; 23 = 16; 0 = 12; 1 = 8 }
    '2026-09-21' = @{ 22 = 10; 23 = 14; 0 = 12; 1 = 10; 2 = 6 }
    '2026-09-22' = @{ 21 = 8; 22 = 12; 23 = 16; 0 = 14; 1 = 8 }
    '2026-09-23' = @{ 20 = 10; 21 = 14; 22 = 12; 23 = 10; 0 = 8 }
    '2026-09-24' = @{ 20 = 12; 21 = 16; 22 = 14; 23 = 10; 0 = 6 }
    '2026-09-25' = @{ 21 = 10; 22 = 14; 23 = 12; 0 = 10; 1 = 8 }
}
$script:habitos = @{ horas = @{}; ruptura = @{ desde = ''; dicha = '' }; fin = @{} }
foreach ($d in $DIAS.Keys) {
    foreach ($h in $DIAS[$d].Keys) {
        # la clave del dia es la del CUBO, y la madrugada pertenece al dia natural en que
        # ocurre: es Get-MedianaMomento quien la envuelve como cola del dia anterior
        $script:habitos.horas[("{0}|{1:D2}" -f $d, [int]$h)] = [int]$DIAS[$d][$h]
    }
}
function Get-Habitos { return $script:habitos }

# LA MEDIANA DE CADA SEMANA, que es el dato que sostiene la idea entera.
$s1 = Get-MedianaMomento $script:habitos.horas '2026-09-10' '2026-09-17' $RupturaMinOrdenesDia
$s2 = Get-MedianaMomento $script:habitos.horas '2026-09-18' '2026-09-26' $RupturaMinOrdenesDia
Write-Host ("       la primera semana: {0:D2}:{1:D2}   la segunda: {2:D2}:{3:D2}" -f
    [int](($s1 % 1440) / 60), [int](($s1 % 1440) % 60), [int](($s2 % 1440) / 60), [int](($s2 % 1440) % 60))
Comp 'la primera semana es de tarde' ($s1 -ge 780 -and $s1 -le 1020) "$s1 minutos"
Comp 'y la segunda, de noche y madrugada' ($s2 -ge 1260) "$s2 minutos"
Comp '  con un salto de horas, no de minutos' (($s2 - $s1) -ge 240) "$($s2 - $s1) minutos"

Write-Host ''
Write-Host '-- 3. la ruptura cae donde cambio el horario, y solo ahi --'
$vistos = @()
foreach ($d in @('2026-09-18', '2026-09-19', '2026-09-20', '2026-09-21', '2026-09-22', '2026-09-23', '2026-09-24', '2026-09-25')) {
    $r = Get-RupturaHorario ([datetime]($d + ' 23:30'))
    if ($r) { $vistos += $d }
}
Write-Host ("       canta ruptura los dias: " + $(if ($vistos) { $vistos -join ', ' } else { 'ninguno' }))
Comp 'canta en la semana del cambio' (@($vistos | Where-Object { $_ -ge '2026-09-21' -and $_ -le '2026-09-23' }).Count -ge 1) ''
# LOS DOS FALSOS DEL LADO CONTRARIO: sin el suelo de ordenes, el 18 y el 19 cantan.
Comp 'y NO el 18/09' (-not ($vistos -contains '2026-09-18')) 'sin el suelo de ordenes, este canta con dif -243'
Comp 'ni el 19/09' (-not ($vistos -contains '2026-09-19')) 'ese dia solo hubo cuatro ordenes'
# Y NO CANTA TODOS LOS DIAS: con un umbral fijo de 120 min, el 23, 24 y 25 cantarian tambien.
Comp 'y no canta toda la segunda semana' ($vistos.Count -le 5) (
    "$($vistos.Count) de 8 dias; con un umbral fijo cantarian los ocho")
Comp '  y los que canta van seguidos' (
    $vistos.Count -eq 0 -or (([datetime]$vistos[-1] - [datetime]$vistos[0]).TotalDays -lt $vistos.Count)) (
    'son el mismo cambio visto desde dias distintos, no cambios distintos')

Write-Host ''
Write-Host '-- 3 bis. UN CAMBIO, UN AVISO --'
# ESTA ES LA GUARDA QUE DESTAPO EL PROPIO BANCO: el detector salta cuatro dias seguidos por UN
# solo cambio, porque la ventana de referencia se va corriendo. Sin esto, braya oiria cuatro
# veces lo mismo.
Invoke-Expression (Traer 'Test-RupturaNueva')
Comp 'la primera vez si se avisa' ([bool](Test-RupturaNueva @{ desde = ''; dicha = '' } '2026-09-20')) ''
Comp '  y al dia siguiente NO' ((Test-RupturaNueva @{ desde = '2026-09-20'; dicha = '2026-09-20' } '2026-09-21') -eq $false) (
    'es el mismo cambio visto un dia despues')
Comp '  ni tres dias despues' ((Test-RupturaNueva @{ desde = '2026-09-20'; dicha = '2026-09-20' } '2026-09-23') -eq $false) ''
# Y CUANDO LA VENTANA DE REFERENCIA HA RODADO ENTERA, un salto nuevo si es un cambio nuevo.
Comp 'pero un cambio de verdad mas adelante, SI' ([bool](Test-RupturaNueva @{ desde = '2026-09-20'; dicha = '2026-09-20' } '2026-10-05')) (
    'los ocho dias son la ventana de referencia del propio detector')

Write-Host ''
Write-Host '-- 4. y no inventa nada cuando no hay datos --'
$script:habitos = @{ horas = @{}; ruptura = @{ desde = ''; dicha = '' }; fin = @{} }
Comp 'sin horas apuntadas, no dice nada' ($null -eq (Get-RupturaHorario ([datetime]'2026-09-25 23:30'))) ''
# CON POCOS DIAS DE REFERENCIA TAMPOCO: es el suelo de cuatro.
$script:habitos.horas = @{}
foreach ($h in 20..23) { $script:habitos.horas[("2026-09-25|{0:D2}" -f $h)] = 10 }
Comp 'con un solo dia, tampoco' ($null -eq (Get-RupturaHorario ([datetime]'2026-09-25 23:30'))) (
    "hacen falta $RupturaMinDiasRef dias de referencia")
# Y LA MEDIANA NO SE INVENTA
Comp 'la mediana de un mapa vacio es -1' ((Get-MedianaMomento @{} '2026-01-01' '2026-12-31' 1) -eq -1) ''
Comp '  y la de un dia con pocas ordenes, tambien' ((Get-MedianaMomento @{ '2026-09-25|21' = 2 } '2026-09-25' '2026-09-26' 10) -eq -1) ''
$desigual = @{ '2026-09-24|10' = 100; '2026-09-25|22' = 10 }
$mDes = Get-MedianaMomento $desigual '2026-09-24' '2026-09-26' 10
Comp 'un dia cargado no pesa mas que uno flojo' ($mDes -ge 1300) (
    "$mDes minutos; por ordenes saldrian 630, por dias salen 1350")
# EL ENVOLTORIO DE LA MADRUGADA: sin el, el numero de la idea no sale.
$m1 = Get-MedianaMomento @{ '2026-09-25|01' = 10 } '2026-09-25' '2026-09-26' 5
Comp 'la madrugada cuenta como cola del dia anterior' ($m1 -gt 1440) (
    "$m1 minutos; sin esto la mediana de la segunda semana sale 20:08 y el salto 278 en vez de 448")

Write-Host ''
Write-Host '-- 5. EL RECORTE, con su guarda de cuatro dias --'
# ESTA ES LA COMPROBACION QUE IMPIDE LA REGRESION. Recortar al dia de la ruptura sin mas deja a
# Get-HoraFinHabitual con 0, 1, 2 y 3 dias los cuatro dias siguientes, devuelve -1, y la noche
# vuelve a las 23:00 cuatro dias seguidos. Es la regresion que la idea 8 del 25/09 arreglo.
Invoke-Expression $cuerpoF
$script:habitos = @{ horas = @{}; ruptura = @{ desde = ''; dicha = '' }; fin = @{} }
foreach ($d in @('2026-09-14', '2026-09-15', '2026-09-16', '2026-09-17', '2026-09-18')) { $script:habitos.fin[$d] = '16:00' }
foreach ($d in @('2026-09-21', '2026-09-22')) { $script:habitos.fin[$d] = '23:30' }
$sinCorte = Get-HoraFinHabitual ([datetime]'2026-09-23 12:00')
$script:habitos.ruptura.desde = '2026-09-21'
$conCorte = Get-HoraFinHabitual ([datetime]'2026-09-23 12:00')
Comp 'con dos dias nuevos, el corte NO se aplica' ($conCorte -eq $sinCorte) (
    "$conCorte; si se aplicara saldria -1 y la noche volveria a las 23:00")
Comp '  y sigue dando una hora de verdad' ($conCorte -gt 0) "$conCorte minutos"
# Y CON CUATRO O MAS, SI SE APLICA
foreach ($d in @('2026-09-23', '2026-09-24')) { $script:habitos.fin[$d] = '23:30' }
$conCorte4 = Get-HoraFinHabitual ([datetime]'2026-09-25 12:00')
$script:habitos.ruptura.desde = ''
$sinCorte4 = Get-HoraFinHabitual ([datetime]'2026-09-25 12:00')
Comp 'con cuatro dias nuevos, SI se aplica' ($conCorte4 -ne $sinCorte4) (
    "con corte $conCorte4, sin corte $sinCorte4")
Comp '  y se queda con el horario nuevo' ($conCorte4 -ge 1400) "$conCorte4 minutos, o sea pasadas las 23:00"

Write-Host ''
Write-Host '-- 6. las dos claves viven en los TRES sitios --'
# Si falta la de Save-Habitos, se escriben en RAM y desaparecen en el primer guardado, EN
# SILENCIO, y todos los bancos que corren en memoria siguen verdes.
$cuerpoS = Traer 'Save-Habitos'
Comp 'Save-Habitos escribe las horas' ($cuerpoS -match 'horas = \$hb\.horas') 'si no, se pierden en el primer guardado'
Comp '  y la ruptura' ($cuerpoS -match 'ruptura = \$hb\.ruptura') ''
$cuerpoG = Traer 'Get-Habitos'
Comp 'Get-Habitos las crea por defecto' ($cuerpoG -match 'horas = @\{\}' -and $cuerpoG -match "ruptura = @\{ desde = ''; dicha = '' \}") ''
Comp '  y las lee de vuelta del fichero' ($cuerpoG -match "PSObject\.Properties\['horas'\]" -and $cuerpoG -match "PSObject\.Properties\['ruptura'\]") (
    'con el patron de las demas: un fichero viejo no puede reventar la lectura')

Write-Host ''
Write-Host '-- 7. se apunta, y el aviso NO habla --'
Comp 'cada orden con texto apunta su hora' ($sinCom -match 'try \{ Add-HoraUso \} catch \{\}') ''
$iAv = $sinCom.IndexOf("Send-AvisoEntorno 'cambio-horario'")
Comp 'el aviso existe' ($iAv -ge 0) ''
$blAv = if ($iAv -ge 0) { $sinCom.Substring($iAv, [Math]::Min(400, $sinCom.Length - $iAv)) } else { '' }
# NIVEL 'bajo': esto no es una averia, es Nova diciendo que se ha dado cuenta.
Comp "  y es de nivel 'bajo', o sea que no habla" ($blAv -match "'bajo'") 'no se habla encima de nada'
$iRup = $sinCom.IndexOf('$rupH = Get-RupturaHorario')
$blRup = if ($iRup -ge 0) { $sinCom.Substring($iRup, [Math]::Min(900, $sinCom.Length - $iRup)) } else { '' }
# UNA VEZ POR RUPTURA, no una por plazo.
Comp '  y se dice UNA vez por ruptura' ($blRup -match 'Test-RupturaNueva \$hbR\.ruptura') (
    'hasta que no cambie el horario otra vez, no se repite')
Comp '  y queda contado' ($blRup -match "Add-Estadistica 'cambio-horario'") ''

Write-Host ''
Write-Host '-- 8. contra el registro de verdad --'
$n = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $r = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $r)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $r -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match "\[escucha\] dictado: '[^']") { $n++ }
    }
}
Write-Host ("       $n dictados con texto; de ahi salen las dos semanas y el salto de 448 minutos")
Comp 'hay ordenes con las que medir el horario' ($n -ge 300) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova se entera de que cambiaste de horario'
exit 0
