# EL ANIMO CON MEMORIA LARGA (25/09, idea 34 de las 50)
#
# LO MEDIDO, y es peor de lo que decia la idea: el animo de hoy+ayer SALTA COMO UN YOYO. Sacado
# de memoria\estadisticas.json, dia a dia:
#     23/09  +0,62      24/09  -0,50      25/09  +0,50
# De +0,62 a -0,50 y otra vez a +0,50 en tres dias. Y ese -0,50 del 24/09 no viene de un mal
# dia: viene de UN error y CERO aciertos, porque ese dia braya estuvo programando y casi no le
# hablo. Lo mismo el 17/09: -0,36 con cero sucesos propios, arrastrado del 16.
#
# O SEA QUE EL ANIMO CORTO CONFUNDE "DIA MALO" CON "DIA VACIO". Y desde la idea 50 ese numero
# decide cuanto habla Nova por su cuenta, asi que el 24/09 se habria pasado el dia a media
# racion por un unico error, con la semana entera yendo bien.
#
# LO QUE PRUEBA ESTE BANCO es que el largo arregla justo eso y no cambia nada mas:
#   - una ventana de 7 dias con peso decreciente, para que lo reciente pese mas;
#   - y sobre todo: UN DIA CON POCOS SUCESOS NO VOTA. Eso es lo que separa el dia malo del dia
#     vacio, y es lo unico que el corto no sabe hacer.
#
# Y LA PARTE QUE NO ES UN TERMOMETRO: Get-FraseAnimo. Un numero que nadie puede explicar no se
# siente vivo. Que Nova sepa decir "llevo unos dias entendiendote peor" si, y sale del mismo
# fichero, sin inventar nada. Se calla salvo que las dos ventanas tengan base y el salto sea
# grande, que es lo que separa esto de una asistente que comenta su humor cada cinco minutos.
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

Write-Host '-- 0. DOS NOMBRES QUE ERAN LA MISMA VARIABLE --'
# LO CAZO ESTE BANCO el 25/09, en codigo recien escrito: la constante $AnimoLargoDias (cuantos
# dias mira la ventana, 7) y el estado $script:animoLargoDias (cuantos votaron) son EL MISMO
# NOMBRE para PowerShell, que no distingue mayusculas. En cuanto se calculaba por primera vez,
# el estado le ponia la ventana a 0 y el animo de fondo se quedaba mudo para siempre. Es el
# mismo tropiezo que $PY contra $py de esta misma semana, asi que se comprueba y no se confia.
# Y OJO CON EL CONJUNTO QUE GUARDA LAS GRAFIAS (25/09): la primera version de esta
# comprobacion usaba un @{} de PowerShell, cuyas claves TAMBIEN ignoran las mayusculas, asi que
# 'animoLargoDias' y 'AnimoLargoDias' entraban como una sola y la cuenta daba 1 siempre. O sea
# que el detector tenia dentro exactamente el fallo que buscaba, y se pasaba la rotura sin
# verla. Hace falta un conjunto ORDINAL, que es el que distingue mayusculas de verdad.
$nombres = @{}
foreach ($m in [regex]::Matches($txt, '\$(?:script:)?([A-Za-z][A-Za-z0-9]*)\s*=')) {
    $n = $m.Groups[1].Value
    $k = $n.ToLower()
    if (-not $nombres.ContainsKey($k)) {
        $nombres[$k] = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    }
    [void]$nombres[$k].Add($n)
}
$choques = @($nombres.Keys | Where-Object { $nombres[$_].Count -gt 1 -and $_ -match 'animo' })
Comp 'ninguna pareja del animo se pisa por mayusculas' ($choques.Count -eq 0) "$(@($choques | ForEach-Object { $_ + ': ' + (@($nombres[$_]) -join ' / ') }) -join '; ')"
# Y QUE EL DETECTOR SEPA DETECTAR: si no encuentra el choque de mentira que se le pone aqui
# delante, tampoco encontrara el de verdad, y este bloque seria decoracion. Es la unica forma
# de saber que un detector funciona sin esperar a que pase la desgracia.
$pru = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
[void]$pru.Add('animoBase'); [void]$pru.Add('AnimoBase')
Comp '  y el detector distingue mayusculas de verdad' ($pru.Count -eq 2) 'con un @{} normal esto daria 1'

Write-Host ''
Write-Host '-- 1. existe, se calcula, y DECIDE --'
foreach ($n in @('Get-AnimoDia', 'Get-AnimoLargo', 'Get-FraseAnimo')) {
    Comp "existe $n" ($sinCom -match ('function ' + $n)) ''
}
$u = @([regex]::Matches($sinCom, '(?<!function )Get-AnimoLargo')).Count
Comp 'Get-AnimoLargo se usa en al menos dos sitios' ($u -ge 2) "$u uso(s): el arranque y cada suceso"
# NO BASTA CON QUE LA LINEA "$script:animoLargo = $lgA.animo" EXISTA (25/09, lo cazo una
# rotura): sustituyendo la llamada por un "$lgA = @{ animo = 0.0; dias = 0 }" el arranque
# dejaba de calcular nada y esa linea seguia ahi, tan contenta. Es mirar la forma y no lo que
# hace. Lo que hay que comprobar es que el arranque LLAMA a la funcion con las estadisticas.
Comp 'el arranque lo calcula de verdad' ($sinCom -match '\$lgA\s*=\s*Get-AnimoLargo\s+\$diasE') 'llamando a la funcion con las estadisticas del disco'
Comp '  y se lo guarda' ($sinCom -match '\$script:animoLargo\s*=\s*\$lgA\.animo') ''
# LO QUE LO SEPARA DE UN ADORNO: que el suelo de avisos lo mire. Si no, es otro termometro.
$dS = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-SueloPorAnimo' }, $true)
Comp 'y Get-SueloPorAnimo lo mira' ($dS -and $dS.Extent.Text -match 'animoLargo') 'si no, seria otro numero decorativo'
# Y NO SE FIA DE QUE LA CONSTANTE EXISTA (25/09). En PowerShell $null vale 0 en una comparacion
# numerica, asi que "0 -ge $null" es CIERTO: si $AnimoLargoMinDias no estuviera definida al
# pasar por ahi, la ventana larga mandaria SIEMPRE, con cero dias de base. Esto no se puede
# probar ejecutando -haria falta una sesion sin la constante-, asi que se comprueba la guarda.
Comp '  exigiendo al menos un dia de base pase lo que pase' (
    $dS -and $dS.Extent.Text -match '\[Math\]::Max\(1, \[int\]\$AnimoLargoMinDias\)') 'porque $null se compara como 0'

Write-Host ''
Write-Host '-- 2. LAS FUNCIONES, SACADAS DEL ARCHIVO Y EJECUTADAS --'
foreach ($n in @('Get-AnimoDia', 'Get-AnimoLargo', 'Get-FraseAnimo')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp "se saca $n del arbol" $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
}
# TODAS LAS DEL ANIMO, no una lista escrita a mano (25/09). La primera version nombraba
# Get-AnimoDeDias y nada mas; el dia que esa funcion paso a apoyarse en Get-AnimoDia y
# Get-AnimoDeCuentas -para que la formula no estuviera duplicada- siete comprobaciones se
# pusieron rojas con el codigo perfectamente bien: la funcion reventaba por dentro, su catch
# devolvia 0.0 y 0.0 es tambien una respuesta legitima. Una lista a mano en un banco caduca el
# dia que alguien reparte una funcion en dos.
foreach ($fA in @($ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -match 'Animo' }, $true))) {
    Invoke-Expression $fA.Extent.Text
}

# las constantes, del archivo (manera 6)
foreach ($cte in @('AnimoLargoDias', 'AnimoLargoMinSucesos', 'AnimoLargoMinDias', 'AnimoSaltoMin')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim()) }
}
# los dobles, DESPUES de cargar (manera 9)
$script:quejas = 0
function Log([string]$m) { if ($m -match 'animo largo: no pude') { $script:quejas++ } }

$hoy = [datetime]'2026-09-25'
function Dia([int]$ok, [int]$mal) { return @{ local = $ok; error = $mal } }

Write-Host ''
Write-Host '-- 3. UN DIA VACIO NO ES UN DIA MALO (el fallo que arregla) --'
# EL CASO REAL DEL 24/09: un error suelto, cero aciertos, en un dia en que casi no le hablo.
# Con el corto eso da -0,50 y Nova se pasa el dia a media racion.
$yoyo = @{
    '2026-09-25' = (Dia 7 0)
    '2026-09-24' = (Dia 0 1)      # <- el dia vacio: UN error y nada mas
    '2026-09-23' = (Dia 1 2)
    '2026-09-22' = (Dia 13 0)
    '2026-09-21' = (Dia 0 6)
    '2026-09-20' = (Dia 14 6)
    '2026-09-19' = (Dia 1 4)
}
$lg = Get-AnimoLargo $yoyo $hoy
Comp 'el dia de UN error no vota' ($lg.dias -eq 2) "votaron $($lg.dias) de 7: solo los que tienen datos"
Comp '  y el animo de fondo sale positivo' ($lg.animo -gt 0) "$($lg.animo); el corto de ese dia daba -0,50"
Comp '  y no se quejo por el camino' ($script:quejas -eq 0) ''

# SIN NADA, CERO Y SIN BASE
$v = Get-AnimoLargo @{} $hoy
Comp 'sin datos: cero dias de base' ($v.dias -eq 0) 'y por tanto no manda sobre nada'
Comp '  y no revienta' ($v.animo -eq 0.0) ''
$vn = Get-AnimoLargo $null $hoy
Comp 'con $null tampoco' (($vn.dias -eq 0) -and ($vn.animo -eq 0.0)) ''
Comp '  y sale por la guarda, no por el catch' ($script:quejas -eq 0) 'si saltara el catch, el log lo diria'

Write-Host ''
Write-Host '-- 4. LO RECIENTE PESA MAS --'
# Mismo par de dias, en orden distinto: el que este mas cerca manda.
$subiendo = @{ '2026-09-25' = (Dia 30 0); '2026-09-24' = (Dia 0 20) }
$bajando  = @{ '2026-09-25' = (Dia 0 20); '2026-09-24' = (Dia 30 0) }
$aS = (Get-AnimoLargo $subiendo $hoy).animo
$aB = (Get-AnimoLargo $bajando $hoy).animo
Comp 'un dia bueno reciente pesa mas que uno malo viejo' ($aS -gt $aB) "subiendo $aS, bajando $aB"
Comp '  y los dos dias votan igual' (((Get-AnimoLargo $subiendo $hoy).dias) -eq 2) ''

Write-Host ''
Write-Host '-- 5. UNA MALA RACHA SI SE NOTA (que es lo que la idea pedia) --'
$racha = @{}
foreach ($j in 0..6) { $racha[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 2 15) }
$lr = Get-AnimoLargo $racha $hoy
Comp 'siete dias malos seguidos dan animo negativo' ($lr.animo -lt 0) ([string]$lr.animo)
Comp '  con los siete votando' ($lr.dias -eq 7) "$($lr.dias)"
# Y LA CONSECUENCIA: que hable menos. Este es el enlace entero.
$mA = [regex]::Match($txt, '(?m)^\$AnimoMalo\s*=\s*(.+)$')
if ($mA.Success) { Invoke-Expression ('$AnimoMalo = ' + $mA.Groups[1].Value.Trim()) }
$mB = [regex]::Match($txt, '(?m)^\$AnimoBueno\s*=\s*(.+)$')
if ($mB.Success) { Invoke-Expression ('$AnimoBueno = ' + $mB.Groups[1].Value.Trim()) }
Invoke-Expression $dS.Extent.Text
$script:uiAnimo = 0.9                      # el corto dice que todo va bien...
$script:animoLargo = $lr.animo             # ...pero la semana dice que no
$script:animoBase = $lr.dias
Comp 'y con una semana mala habla MENOS aunque hoy vaya bien' ((Get-SueloPorAnimo 4) -lt 4) "suelo $(Get-SueloPorAnimo 4) en vez de 4"
# Y AL REVES: sin base, manda el corto y todo se comporta como antes
$script:animoBase = 0
$script:uiAnimo = -0.9
Comp 'sin base suficiente manda el corto, como siempre' ((Get-SueloPorAnimo 4) -lt 4) 'los primeros dias esto no cambia nada'

Write-Host ''
Write-Host '-- 6. Y SABE CONTARLO, sin ser un pesado --'
# TRES DIAS BUENOS DESPUES DE TRES MALOS: eso si es una tendencia
$mejora = @{}
foreach ($j in 0..2) { $mejora[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 40 0) }
foreach ($j in 3..6) { $mejora[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 2 15) }
$fM = Get-FraseAnimo $mejora $hoy
Comp 'una mejora clara se dice' (-not [string]::IsNullOrEmpty($fM)) "$fM"
Comp '  y se nota que es a mejor' ($fM -match 'mejor') "$fM"

$peora = @{}
foreach ($j in 0..2) { $peora[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 2 15) }
foreach ($j in 3..6) { $peora[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 40 0) }
$fP = Get-FraseAnimo $peora $hoy
Comp 'un empeoramiento claro tambien' (-not [string]::IsNullOrEmpty($fP)) "$fP"
Comp '  y lo reconoce' ($fP -match 'peor') "$fP"

# UNA SEMANA NORMAL: NADA. Esto es lo que separa esto de comentar el humor cada rato.
$normal = @{}
foreach ($j in 0..6) { $normal[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 20 3) }
Comp 'una semana sin cambios NO se comenta' ([string]::IsNullOrEmpty((Get-FraseAnimo $normal $hoy))) 'lo normal es callarse'
# Y UNA MEJORA PEQUENA TAMPOCO (25/09, lo cazo una rotura). Con la semana plana el salto sale
# exactamente 0, y 0 no distingue un liston de 0,35 de uno de 0,0 -por el redondeo puede salir
# hasta un pelin negativo y colarse por el otro lado-. Hace falta un salto REAL pero por debajo
# del liston: eso es lo que separa "ha cambiado algo" de "ha cambiado lo bastante como para
# decirlo". Sin esta prueba, bajar el liston a cero pasaba desapercibido y Nova se volvia una
# pesada que comenta su humor cada vez que respira.
$pelin = @{}
foreach ($j in 0..2) { $pelin[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 20 2) }
foreach ($j in 3..6) { $pelin[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 20 3) }
$fPe = Get-FraseAnimo $pelin $hoy
$sPe = (Get-AnimoLargo $pelin $hoy).animo - (Get-AnimoLargo $pelin $hoy.AddDays(-3)).animo
Comp 'una mejora pequena no se comenta' ([string]::IsNullOrEmpty($fPe)) "el salto fue $([Math]::Round($sPe,3)) y el liston es $AnimoSaltoMin"
Comp '  y el salto era de verdad, no cero' ([Math]::Abs($sPe) -gt 0.001) 'si fuera 0 esta prueba no distinguiria ningun liston'

# SIN BASE, NADA: no se opina de lo que no se sabe
Comp 'sin datos no opina' ([string]::IsNullOrEmpty((Get-FraseAnimo @{} $hoy))) ''
$soloHoy = @{ '2026-09-25' = (Dia 40 0) }
Comp 'con un solo dia tampoco' ([string]::IsNullOrEmpty((Get-FraseAnimo $soloHoy $hoy))) 'una tendencia necesita dos puntos'
# NI CON BASE HOY PERO NADA DETRAS (25/09, lo cazo una rotura). Los dos casos de arriba salen
# por la PRIMERA guarda -la de 'ahora'-, asi que borrar la segunda -la de 'antes'- dejaba el
# banco verde: ninguna prueba llegaba hasta ella. Este es el unico caso que la ejercita: tres
# dias buenos recien estrenados y nada antes. Sin ese 'antes' no hay tendencia que contar,
# solo un estreno, y decir "te entiendo mejor que antes" sin un antes es inventarselo.
$estreno = @{}
foreach ($j in 0..2) { $estreno[$hoy.AddDays(-$j).ToString('yyyy-MM-dd')] = (Dia 40 0) }
Comp 'con base hoy pero nada detras, tampoco' ([string]::IsNullOrEmpty((Get-FraseAnimo $estreno $hoy))) 'no hay "antes" con el que comparar'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el animo tiene memoria larga, y sabe contarla'
exit 0
