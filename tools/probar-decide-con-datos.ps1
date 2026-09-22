# EL MOTOR QUE AJUSTA A NOVA SOLA, Y LOS DATOS CON LOS QUE DECIDE (22/09).
#
# braya pidio que Nova se adapte y cambie sola. Eso ya existe -la revision propia apaga la
# nube, apaga el oido fino, afina el tope de espera-, pero al peinarlo aparecieron tres
# sitios donde los datos con los que decide, o los avisos con los que lo cuenta, se caen
# por el camino. Ninguno cambia lo que Nova DECIDE: cambian con que lo decide y si llega a
# contarlo, que para el caso es lo mismo.
#
# 1. EL AVISO QUE NUNCA LLEGABA AL PARTE. Set-AvisoSinDatos apuntaba el aviso en una
#    variable de SESION, y el parte que lo recoge sale a las 05:00. Entre una cosa y otra
#    Nova se reinicia -la mediana de sesion son 5,8 minutos y ese dia hubo 16 arranques-,
#    asi que la variable llegaba vacia. En el log hay 12 lineas "SIN DATOS: lo dejo para el
#    parte de la manana" y ni un solo parte que lo dijera; las tres ultimas son la MISMA
#    frase a las 08:00, 08:34 y 09:50, o sea el mismo aviso reapuntandose en cada arranque.
#    Su pareja ya estaba en disco (sinDatosVisto, la fecha en que SALIO); faltaba el texto.
#
# 2. EL TOPE DE LA NUBE, CON DATOS DE OTRA NOVA. nube-tiempos.json guarda los milisegundos
#    y el dia de cada uno, y de sus 80 muestras SETENTA Y CUATRO no traen dia (92,5 %). El
#    freno del reparto ya las ignoraba, pero el p90 y el recuento salian de las 80: el
#    freno miraba unos datos y el numero salia de otros. Medido: p90 de las 80 = 6.708 ms
#    -> tope 7.500; p90 de las 6 fechadas = 4.685 -> tope 5.500. Dos segundos de espera en
#    cada pregunta, y hacia el lado malo.
#
# 3. EL PARRAFO SEMANAL QUE SALIA VACIO. Get-ParrafoDecisiones resume LA SEMANA buscando
#    auto-ajuste / auto-deshecho / arranque-medias en "recientes", que tiene 40 filas.
#    Medido hoy sobre memoria\estadisticas.json: 28 de esas 40 son aviso-entorno (el 70 %)
#    y las decisiones dentro de la ventana son CERO. En los dias cargados entran 560-600
#    eventos, asi que la ventana real es de una hora, no de una semana.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\[].*?^\}}' -f [regex]::Escape($n)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0}' -f $n); exit 1 }
    return $m.Value
}

Write-Host ''
Write-Host '-- 1. el aviso sobrevive a un reinicio --'
# La variable de sesion se queda, que otras pruebas la miran; lo que se anade es el disco.
Comp 'el aviso se guarda en habitos.json' ($fuente -match '\$hbS\.sinDatosTexto = \$t')
Comp 'y habitos lo lleva en su estructura' ($fuente -match "sinDatosTexto = ''")
Comp 'se carga al leer el archivo' ($fuente -match '\$script:habitos\.sinDatosTexto = \[string\]\$crudoH\.sinDatosTexto')
Comp 'y se escribe al guardarlo' ($fuente -match 'sinDatosTexto = \[string\]\$hb\.sinDatosTexto')
# EL ARCHIVO DE ANTES DE HOY NO LO TRAE, y eso no puede romper nada.
Comp 'si el archivo es viejo, no revienta' ($fuente -match "PSObject\.Properties\['sinDatosTexto'\]")
# El parte lo recoge del disco cuando la sesion llega vacia, que es SIEMPRE tras reiniciar.
Comp 'el parte lo lee del disco si la sesion no lo trae' `
    ($fuente -match '-not \$script:parteSinDatos -and \$hbM\.sinDatosTexto')
# Y AL SALIR SE BORRA DE LOS DOS SITIOS: si no, volveria a salir en cuanto se reiniciara,
# que es el mismo fallo por el otro lado.
$mSale = [regex]::Match($fuente, '(?s)\$script:parteSinDatos = ''''.{0,400}?Save-Habitos')
Comp 'al salir se borra tambien del disco' ($mSale.Success -and $mSale.Value -match "sinDatosTexto = ''")
Comp 'y se sigue marcando la fecha en que salio' ($mSale.Value -match 'sinDatosVisto = \$ahora')

Write-Host ''
Write-Host '-- 2. el tope de la nube, solo con lo fechado --'
Comp 'existe Get-NubeTiemposConDia' ($fuente -match 'function Get-NubeTiemposConDia')
$mFn = Traer 'Get-NubeTiemposConDia'
# la coma de siempre: una lista vacia desenrollada se queda en $null y el que la recibe
# peta al pedirle .Count
Comp 'devuelve con coma, como sus hermanas' ($mFn -match 'return ,\$l')
Comp 'el caso 4 la usa' ($fuente -match '\$listaN = Get-NubeTiemposConDia')
Comp 'y el p90 sale de esa misma lista' ($fuente -match 'Get-NubePercentil 90 \$listaN')
Comp 'Get-NubePercentil acepta la lista' ($fuente -match 'function Get-NubePercentil\(\[int\]\$pct = 90, \$lista = \$null\)')
Comp 'y sin lista sigue haciendo lo de antes' ($fuente -match 'if \(\$null -eq \$lista\) \{ \$lista = Get-NubeTiempos \}')
# NO SE BORRA NADA del fichero: las sin fecha se quedan y la cinta las saca sola.
Comp 'no se purga el fichero de tiempos' (-not ($fuente -match 'Remove-Item.*NubeTiemposJson'))

# Y SE EJECUTA, con el fichero de verdad si esta.
. ([scriptblock]::Create((Traer 'Get-NubeTiempos')))
. ([scriptblock]::Create((Traer 'Get-NubeDias')))
. ([scriptblock]::Create($mFn))
. ([scriptblock]::Create((Traer 'Get-NubePercentil')))
$MemoriaDir = Join-Path $raiz 'memoria'
$NubeTiemposJson = Join-Path $MemoriaDir 'nube-tiempos.json'
function Log($m) {}
if (Test-Path -LiteralPath $NubeTiemposJson) {
    # SE ASIGNA PRIMERO, SIN @() DELANTE, y aqui me costo un rojo: estas tres funciones
    # acaban en 'return ,$l' para que una lista vacia no se convierta en $null, y esa misma
    # coma hace que @(Get-NubeTiempos) deje un array de UN elemento con el ArrayList entero
    # dentro. Contaba 1 donde hay 80. Es la trampa que el propio assistant.ps1 tiene
    # documentada en Test-NubeRepartida desde el 21/09, y aun asi vuelve a morder.
    $todasL = Get-NubeTiempos
    $conDia = Get-NubeTiemposConDia
    $nT = @($todasL).Count
    $nC = @($conDia).Count
    Comp 'con el fichero real, las fechadas son menos' ($nC -le $nT) "$nC de $nT"
    if ($nT -gt 0 -and $nC -gt 0) {
        $pT = Get-NubePercentil 90
        $pC = Get-NubePercentil 90 $conDia
        Comp 'y el p90 sale distinto (por eso importa)' ($pT -ne $pC) "todas $pT ms, fechadas $pC ms"
    }
} else {
    Comp 'con el fichero real' $true '(no hay fichero todavia; se salta)'
}
# una lista vacia no puede petar a quien la reciba
$NubeTiemposJson = Join-Path ([System.IO.Path]::GetTempPath()) 'no-existe-nube.json'
$vacia = Get-NubeTiemposConDia
Comp 'sin fichero devuelve lista, no $null' ($null -ne $vacia -and @($vacia).Count -eq 0)

Write-Host ''
Write-Host '-- 3. el parrafo semanal ya encuentra las decisiones --'
Comp 'existe la lista decisiones' ($fuente -match 'decisiones = @\(\)')
Comp 'solo entran las tres rutas de decision' `
    ($fuente -match "\`$ruta -in @\('auto-ajuste', 'auto-deshecho', 'arranque-medias'\)")
Comp 'con tope propio de 60' ($fuente -match '\$s\.decisiones \| Select-Object -First 60')
Comp 'recientes NO cambia de tope' ($fuente -match '\$s\.recientes \| Select-Object -First 40')
Comp 'se guarda en el json' ($fuente -match 'NotePropertyName decisiones')
Comp 'se carga del json' ($fuente -match '\$script:stats\.decisiones = @\(\$j\.decisiones')
Comp 'y el olvido por dia la barre igual' ($fuente -match "@\('descartes', 'recientes', 'decisiones'\)")
$mPar = Traer 'Get-ParrafoDecisiones'
Comp 'el parrafo lee la lista nueva' ($mPar -match '\$deDonde = @\(\$stats\.decisiones\)')
Comp 'y cae a recientes si aun esta vacia' ($mPar -match 'if \(\$deDonde\.Count -eq 0\) \{ \$deDonde = @\(\$stats\.recientes\) \}')

# Y SE EJECUTA, que es lo unico que lo demuestra. El caso de verdad: 40 avisos tapando las
# decisiones, que es lo que hay hoy en el fichero.
. ([scriptblock]::Create($mPar))
$hoy = Get-Date -Format 'yyyy-MM-dd'
$ini = [datetime]::Now.AddDays(-7); $fin = [datetime]::Now.AddDays(1)
$avisos = @(1..40 | ForEach-Object { "$hoy 11:00  [aviso-entorno]  ruido $_" })
$conLista = @{ decisiones = @("$hoy 10:00  [auto-ajuste]  nube tope: 7000 -> 5500",
                              "$hoy 10:05  [auto-deshecho]  escucha.nubeOir")
               recientes = $avisos }
$r1 = Get-ParrafoDecisiones $conLista $ini $fin
Comp 'con la lista nueva, el parrafo sale' ([bool]$r1) $(if ($r1) { $r1.Substring(0, [Math]::Min(46, $r1.Length)) } else { '(vacio)' })
$comoEstaba = @{ decisiones = @(); recientes = $avisos }
$r2 = Get-ParrafoDecisiones $comoEstaba $ini $fin
Comp 'y con 40 avisos delante salia VACIO' (-not $r2) 'el fallo, reproducido'
$viejo = @{ decisiones = @(); recientes = @("$hoy 10:00  [auto-ajuste]  algo de antes") }
$r3 = Get-ParrafoDecisiones $viejo $ini $fin
Comp 'el respaldo del fichero viejo funciona' ([bool]$r3)
# y que no se invente nada cuando no hay decisiones
$nada = @{ decisiones = @(); recientes = @("$hoy 10:00  [charla]  hola") }
Comp 'sin decisiones no dice nada' (-not (Get-ParrafoDecisiones $nada $ini $fin))
# ni saque de la semana lo que es de otra
$vieja = @{ decisiones = @("2026-01-01 10:00  [auto-ajuste]  de hace meses"); recientes = @() }
Comp 'ni cuenta lo de fuera de la semana' (-not (Get-ParrafoDecisiones $vieja $ini $fin))

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  Nova decide con datos de ahora, y llega a contarlo'
exit 0
