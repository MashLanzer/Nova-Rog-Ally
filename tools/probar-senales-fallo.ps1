# LAS SENALES DE FALLO QUE NOVA SE DEDUCE SOLA Y NO LEIA NADIE (27/09, idea 99 de las 121)
#
# EL DATO: pruebas\audio\uso\senales-fallo.jsonl tiene 33 lineas de cinco dias (20, 21, 22, 23 y
# 25/09): 14 'ruido' y 5 'descarte' de peso ALTO -Nova no hizo NADA con la frase- y 14
# 'no-orden-a-charla' de peso BAJO -hizo algo que quiza no era-. En todo el proyecto, fuera de dos
# bancos, el fichero aparece en DOS sitios: quien lo escribe (Write-FalloDeducido) y quien lo BORRA
# (Invoke-Olvido). Cero lecturas. Y el comentario de Write-FalloDeducido dice que los pesos van
# separados "para que quien lo lea los cuente por separado": no habia nadie leyendo.
#
# DONDE SE CUELGA: en el parrafo semanal, que hoy sale vacio SIEMPRE -'auto-ajuste' vale cero en 14
# dias y la lista 'decisiones' esta vacia-, para que al menos diga de que murieron las ordenes.
#
# LO QUE ESTE BANCO PROTEGE, y el primero es la piedra con la que ya tropezo el contador de falsas
# alarmas cuando llego a decir 489 %:
#   1. que los pesos NO se sumen nunca: se cuentan por separado
#   2. que solo entren los dias que cuentan (Test-DiaCuenta), igual que el resto de la casa
#   3. que una linea rota no se lleve el fichero entero
#   4. que el parrafo semanal deje de salir vacio, y que cuando SI hay decisiones no las tape
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('Test-DiaCuenta', 'Get-SenalesFallo', 'Get-SenalFallePeor', 'Get-ParrafoDecisiones')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# EL MUNDO DE MENTIRA, despues de cargar
$DecisionDatosDesde = '2026-09-20'
$mD = [regex]::Match($txt, '(?m)^\$DecisionDatosDesde = ''([0-9-]+)''')
if ($mD.Success) { $DecisionDatosDesde = $mD.Groups[1].Value }
Comp 'la fecha desde la que cuentan los datos sale del archivo' ($DecisionDatosDesde -match '^\d{4}-\d\d-\d\d$') $DecisionDatosDesde
$LogDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-senales-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$dirUso = Join-Path $LogDir 'pruebas\audio\uso'
New-Item -ItemType Directory -Path $dirUso -Force | Out-Null
$ruta = Join-Path $dirUso 'senales-fallo.jsonl'
function Escribir([string[]]$lineas) {
    [IO.File]::WriteAllText($ruta, (($lineas -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($false)))
    $script:senalesSello = ''      # el cache es por tamano: aqui se fuerza a releer
    $script:senalesCache = $null
}
function Linea([string]$dia, [string]$senal, [string]$peso, [string]$detalle = 'lo que sea') {
    $id = ($dia -replace '-', '') + '-120000'
    return ('{"id":"' + $id + '","hora":"' + $dia + ' 12:00:00","senal":"' + $senal + '","peso":"' + $peso + '","detalle":"' + $detalle + '"}')
}

try {
    Write-Host ''
    Write-Host '-- 1. LOS PESOS NO SE SUMAN NUNCA (la piedra del 489 %) --'
    # los numeros de verdad del fichero de hoy: 14 ruido alto, 5 descarte alto, 14 no-orden bajo
    $ls = @()
    foreach ($i in 1..14) { $ls += (Linea '2026-09-21' 'ruido' 'alto') }
    foreach ($i in 1..5) { $ls += (Linea '2026-09-22' 'descarte' 'alto') }
    foreach ($i in 1..14) { $ls += (Linea '2026-09-23' 'no-orden-a-charla' 'bajo') }
    Escribir $ls
    $sf = Get-SenalesFallo $dirUso
    Comp '1a. las tres senales, cada una por su lado' ($sf.Count -eq 3) ([string]$sf.Count)
    Comp '1b. el ruido, 14 de peso alto' ($sf['ruido'].alto -eq 14 -and $sf['ruido'].bajo -eq 0) ([string]$sf['ruido'].alto + ' alto / ' + [string]$sf['ruido'].bajo + ' bajo')
    Comp '1c. el descarte, 5 alto' ($sf['descarte'].alto -eq 5) ([string]$sf['descarte'].alto)
    Comp '1d. y la charla, 14 BAJO y ni uno alto' ($sf['no-orden-a-charla'].bajo -eq 14 -and $sf['no-orden-a-charla'].alto -eq 0) ([string]$sf['no-orden-a-charla'].bajo + ' bajo / ' + [string]$sf['no-orden-a-charla'].alto + ' alto')
    # LA COMPROBACION QUE DE VERDAD IMPORTA: no hay ningun campo que mezcle los dos
    $mezcla = @($sf.Keys | Where-Object { $sf[$_].total -ne ($sf[$_].alto + $sf[$_].medio + $sf[$_].bajo) })
    Comp '1e. el total cuadra con la suma de los pesos' ($mezcla.Count -eq 0) 'pero el total no se usa para decidir nada'
    Comp '1f. y cada senal guarda sus dias' ($sf['ruido'].dias.Count -eq 1 -and $sf['ruido'].dias['2026-09-21'] -eq 14) ([string]$sf['ruido'].dias.Count + ' dia(s)')

    Write-Host ''
    Write-Host '-- 2. SOLO LOS DIAS QUE CUENTAN --'
    $antes = [datetime]::ParseExact($DecisionDatosDesde, 'yyyy-MM-dd', $null).AddDays(-3).ToString('yyyy-MM-dd')
    Escribir @((Linea $antes 'ruido' 'alto'), (Linea $antes 'ruido' 'alto'), (Linea '2026-09-23' 'ruido' 'alto'))
    $sf2 = Get-SenalesFallo $dirUso
    Comp '2a. lo de antes de la fecha de corte no entra' ($sf2['ruido'].alto -eq 1) ([string]$sf2['ruido'].alto + ' de 3; ' + $antes + ' queda fuera')
    Comp '2b. y su dia tampoco' (-not $sf2['ruido'].dias.ContainsKey($antes)) 'es la misma guarda que Get-FalsasAlarmas desde el 20/09'

    Write-Host ''
    Write-Host '-- 3. UNA LINEA ROTA NO SE LLEVA EL FICHERO --'
    Escribir @((Linea '2026-09-23' 'ruido' 'alto'), 'esto no es json', '', '{"id":"corto"}',
               '{"senal":"descarte","peso":"alto"}', (Linea '2026-09-23' 'descarte' 'alto'))
    $sf3 = Get-SenalesFallo $dirUso
    Comp '3a. las buenas se leen' ($sf3['ruido'].alto -eq 1 -and $sf3['descarte'].alto -eq 1) ([string]$sf3.Count + ' senales')
    Comp '3b. la que no trae id se salta' ($sf3['descarte'].total -eq 1) 'sin id no hay dia, y sin dia no se puede filtrar'
    Escribir @()
    Comp '3c. con el fichero vacio, nada' ((Get-SenalesFallo $dirUso).Count -eq 0) ''
    $script:senalesSello = ''; $script:senalesCache = $null
    Comp '3d. y sin fichero, tampoco revienta' ((Get-SenalesFallo (Join-Path $LogDir 'no-existe')).Count -eq 0) ''

    Write-Host ''
    Write-Host '-- 4. LA PEOR DE LA SEMANA, CON NOMBRE --'
    $hoy = (Get-Date).Date
    $d1 = $hoy.AddDays(-2).ToString('yyyy-MM-dd')
    $d2 = $hoy.AddDays(-5).ToString('yyyy-MM-dd')
    $viejo = $hoy.AddDays(-30).ToString('yyyy-MM-dd')
    $ls4 = @()
    foreach ($i in 1..3) { $ls4 += (Linea $d1 'ruido' 'alto') }
    foreach ($i in 1..7) { $ls4 += (Linea $d2 'no-orden-a-charla' 'bajo') }
    foreach ($i in 1..20) { $ls4 += (Linea $viejo 'descarte' 'alto') }
    Escribir $ls4
    $peor = Get-SenalFallePeor 7 $hoy
    Comp '4a. gana la que mas salio en la ventana' ($null -ne $peor -and $peor.senal -eq 'no-orden-a-charla') ([string]$peor.senal + ' x' + [string]$peor.veces)
    Comp '4b. con sus veces' ($peor.veces -eq 7) ([string]$peor.veces)
    Comp '4c. y sabe que es de las de peso bajo' (-not $peor.alto) 'hizo algo que quiza no era'
    Comp '4d. y lo de hace un mes NO cuenta' ($peor.senal -ne 'descarte') 'veinte de hace 30 dias no son la semana'
    # con solo las altas, lo dice
    Escribir @((Linea $d1 'ruido' 'alto'), (Linea $d1 'ruido' 'alto'))
    $peor2 = Get-SenalFallePeor 7 $hoy
    Comp '4e. y cuando son altas, lo sabe' ($peor2.alto) 'no hizo nada con lo que dijo'
    Escribir @((Linea $viejo 'ruido' 'alto'))
    Comp '4f. sin nada en la ventana, no opina' ($null -eq (Get-SenalFallePeor 7 $hoy)) 'mejor callarse que inventar una semana'

    Write-Host ''
    Write-Host '-- 5. EL PARRAFO SEMANAL DEJA DE SALIR VACIO --'
    $ini = $hoy.AddDays(-7); $fin = $hoy
    $ls5 = @()
    foreach ($i in 1..4) { $ls5 += (Linea $d1 'ruido' 'alto') }
    Escribir $ls5
    $stVacio = @{ decisiones = @(); recientes = @() }
    $p5 = Get-ParrafoDecisiones $stVacio $ini $fin
    Comp '5a. ya dice algo' ($p5.Length -gt 0) $p5
    Comp '5b. y dice que no decidio nada' ($p5 -match 'no decidi nada') ''
    Comp '5c. nombrando la senal en castellano' ($p5 -match 'restos del microfono') 'no "ruido:alto", que eso no es una frase'
    Comp '5d. con las veces' ($p5 -match '4 veces') ''
    Comp '5e. y diciendo que no hizo nada' ($p5 -match 'no hice nada') 'el peso alto, contado como lo que es'
    # UNA SOLA VEZ, en singular
    Escribir @((Linea $d1 'ruido' 'alto'))
    $p5b = Get-ParrafoDecisiones $stVacio $ini $fin
    Comp '5f. y una sola vez se dice en singular' ($p5b -match 'una vez' -and -not ($p5b -match '1 veces')) $p5b

    Write-Host ''
    Write-Host '-- 6. Y CUANDO SI HAY DECISIONES, NO LAS TAPA --'
    $stCon = @{ decisiones = @(((Get-Date).ToString('yyyy-MM-dd') + ' 12:00  [auto-ajuste]  apague el zumbido')); recientes = @() }
    $p6 = Get-ParrafoDecisiones $stCon $ini $fin
    Comp '6a. sale la decision, no la senal' ($p6 -match 'apague el zumbido') $p6
    Comp '6b. y no se cuela lo de las senales' (-not ($p6 -match 'no decidi nada')) 'las decisiones de verdad mandan'
    # y sin senales Y sin decisiones, sigue vacio
    Escribir @()
    Comp '6c. sin nada de nada, sigue vacio' ((Get-ParrafoDecisiones $stVacio $ini $fin) -eq '') 'no se inventa un parrafo'
} finally {
    Remove-Item -LiteralPath $LogDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
Comp '7a. las senales se leen de verdad en algun sitio' ($sinCom -match 'Get-SenalFallePeor 7 \$fin') 'antes el fichero solo se escribia y se borraba'
Comp '7b. con cache por tamano, como su hermana' ((Traer 'Get-SenalesFallo') -match 'selloS -eq \$script:senalesSello') 'esto corre en el camino de una orden'
Comp '7c. y filtrando por los dias que cuentan' ((Traer 'Get-SenalesFallo') -match 'Test-DiaCuenta \$diaS') ''
Comp '7d. el dia sale del id, sin parsear horas' ((Traer 'Get-SenalesFallo') -match '\$idS\.Substring\(0, 4\)') 'el mismo truco de Get-FalsasAlarmas'
Comp '7e. y quien lo borra sigue borrandolo' ($sinCom -match "Remove-JsonlDesde \(Join-Path \`$usoDir 'senales-fallo\.jsonl'\)") 'el olvido no se ha tocado'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'las senales de fallo ya las lee alguien, y sin sumar los pesos' -ForegroundColor Green
exit 0
