# LA FRANJA EN LA QUE NUNCA ESTAS, CALCULADA POR ELLA MISMA (27/09, idea 86 de las 121)
#
# EL PROBLEMA: el dia de braya empezaba a las 5 porque alguien lo escribio, y el AddHours(-5) estaba a
# mano en SIETE lineas; seis no llamaban a Get-DiaJuego, que existe justo para eso, y ese desfase ya
# costo un fallo el 23/09. Y el final del silencio nocturno era un 8 fijo en config.json mientras el
# PRINCIPIO de la noche si se aprendia de sus horas.
#
# EL DATO: 0 de 714 ordenes entre las 02:00 y las 08:59 en 13 dias, y solo 6 de 3.557 gestos en esa
# franja en 15 dias. Medido con sus ficheros de hoy: franja muerta de las 2 a las 9 (7 h sin NADA),
# asi que el dia parte a las 5 -el de siempre, no cambia nada- y el silencio se acaba a las 9.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que sin datos o con una franja corta se queden el 5 y el 8 de siempre
#   2. que la franja se vea aunque cruce la medianoche
#   3. que el corte NO se mueva a media sesion (se calcula una vez al dia)
#   4. que no se pague leer dos ficheros en cada llamada, que Get-DiaJuego corre en el bucle
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
foreach ($f in @('Get-FranjaMuerta', 'Get-CorteDia', 'Get-NocheHasta', 'Get-DiaJuego')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$FranjaHorasMin = 4
$FranjaDiasMin = 3
$CorteDiaPorDefecto = 5
$EntornoNocheHasta = 8
Comp 'la franja minima son 4 horas' ($txt -match '\$FranjaHorasMin = 4') ''
Comp 'y hacen falta 3 dias con datos' ($txt -match '\$FranjaDiasMin = 3') ''
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
# el doble de la fuente de datos, DESPUES de cargar: lo que se prueba aqui es la franja, no la lectura
$script:horasFalsas = @{}
$script:diasFalsos = 0
$script:vecesLeido = 0
function Get-HorasConActividad([datetime]$ahora = (Get-Date)) {
    $script:vecesLeido++
    $h = @{}
    for ($i = 0; $i -lt 24; $i++) { $h[$i] = 0 }
    foreach ($k in $script:horasFalsas.Keys) { $h[[int]$k] = [int]$script:horasFalsas[$k] }
    return @{ horas = $h; dias = $script:diasFalsos }
}
function Reset {
    $script:franjaCalculadaDia = ''
    $script:franjaMuerta = $null
    $script:corteDia = $CorteDiaPorDefecto
    $script:logs = @()
    $script:vecesLeido = 0
}
$hoy = [datetime]'2026-09-27 12:00'

Write-Host ''
Write-Host '-- 1. SIN DATOS, EL 5 Y EL 8 DE SIEMPRE --'
Reset
$script:horasFalsas = @{}
$script:diasFalsos = 0
Comp '1a. sin dias con datos, no hay franja' ($null -eq (Get-FranjaMuerta $hoy)) ''
Comp '1b. el corte sigue a las 5' ((Get-CorteDia $hoy) -eq 5) ''
Comp '1c. y el silencio hasta las 8' ((Get-NocheHasta $hoy) -eq 8) 'el numero escrito de config.json'

Write-Host ''
Write-Host '-- 2. UNA FRANJA CORTA NO CUENTA --'
Reset
# actividad en todas las horas menos tres
$script:horasFalsas = @{}
for ($h = 0; $h -lt 24; $h++) { $script:horasFalsas[$h] = 5 }
$script:horasFalsas[3] = 0; $script:horasFalsas[4] = 0; $script:horasFalsas[5] = 0
$script:diasFalsos = 10
Comp '2a. con tres horas seguidas, no hay franja' ($null -eq (Get-FranjaMuerta $hoy)) 'el minimo son 4'
Comp '2b. y los numeros no se mueven' (((Get-CorteDia $hoy) -eq 5) -and ((Get-NocheHasta $hoy) -eq 8)) ''

Write-Host ''
Write-Host '-- 3. EL CASO DE VERDAD: su franja de las 2 a las 9 --'
Reset
$script:horasFalsas = @{ 0 = 24; 1 = 16; 9 = 1; 10 = 4; 11 = 4; 12 = 1; 13 = 8; 14 = 1; 15 = 5
                         16 = 9; 18 = 9; 19 = 3; 20 = 10; 21 = 17; 22 = 24; 23 = 23 }
$script:diasFalsos = 12
$f3 = Get-FranjaMuerta $hoy
Comp '3a. la franja va de las 2 a las 9' ($f3.de -eq 2 -and $f3.a -eq 9) ([string]$f3.de + ' -> ' + [string]$f3.a)
Comp '3b. y son 7 horas' ($f3.horas -eq 7) ([string]$f3.horas)
Comp '3c. el dia parte a las 5, como hasta hoy' ((Get-CorteDia $hoy) -eq 5) 'la idea era que HOY no cambiase nada'
Comp '3d. y el silencio se acaba a las 9, no a las 8' ((Get-NocheHasta $hoy) -eq 9) 'medido, no escrito'
Comp '3e. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'FRANJA MUERTA' }).Count -eq 1) (@($script:logs) -join ' | ')

Write-Host ''
Write-Host '-- 4. LA FRANJA QUE CRUZA LA MEDIANOCHE SE VE ENTERA --'
Reset
# activo de 8 a 20, muerto de 21 a 7 (once horas que cruzan la medianoche)
$script:horasFalsas = @{}
foreach ($h in 8..20) { $script:horasFalsas[$h] = 4 }
$script:diasFalsos = 8
$f4 = Get-FranjaMuerta $hoy
Comp '4a. la franja empieza a las 21' ($f4.de -eq 21) ([string]$f4.de)
Comp '4b. y acaba a las 8' ($f4.a -eq 8) ([string]$f4.a)
Comp '4c. con sus once horas' ($f4.horas -eq 11) ([string]$f4.horas)
Comp '4d. y el corte cae de madrugada' ((Get-CorteDia $hoy) -eq 2) ('las ' + [string](Get-CorteDia $hoy))

Write-Host ''
Write-Host '-- 5. NI SE PAGA EN CADA LLAMADA NI SE MUEVE A MEDIA SESION --'
Reset
$script:horasFalsas = @{ 0 = 24; 1 = 16; 9 = 1; 10 = 4; 20 = 10; 21 = 17; 22 = 24; 23 = 23 }
$script:diasFalsos = 12
$null = Get-CorteDia $hoy
$leido1 = $script:vecesLeido
for ($i = 0; $i -lt 50; $i++) { $null = Get-DiaJuego $hoy.AddMinutes($i) }
Comp '5a. cincuenta llamadas y una sola lectura' ($script:vecesLeido -eq $leido1) ([string]$script:vecesLeido + ' lecturas para 51 llamadas')
# Y CON DIAS DISTINTOS, QUE ES COMO LO LLAMA EL CODIGO DE VERDAD (28/09). El 5a de arriba hace las
# cincuenta llamadas con el MISMO dia, y asi no puede ver el fallo que se comio un nucleo entero: el
# sello de la cache salia de la fecha que le PREGUNTAN, y Get-DiaJuego se llama con otros dias -hay
# un bucle de ocho en Get-RupturaRitmo, mas Get-DiaJuego $hoy.AddDays(-10) y $hoy.AddDays(1)-. Cada
# llamada con otro dia invalidaba la cache, recalculaba todo y la dejaba apuntando a ESE dia; la
# siguiente con hoy recalculaba otra vez. Medido en la Nova de produccion: 161 lineas FRANJA MUERTA
# en 96 minutos y 1.000 ms de CPU por segundo, plano. Es la manera 17 de salir verde mintiendo: un
# caso que no toca lo que dice vigilar.
$leido2 = $script:vecesLeido
foreach ($d in 1, -9, -10, -3, -5, -7, -2, -8, -4, -6) { $null = Get-DiaJuego $hoy.AddDays($d) }
$null = Get-NocheHasta $hoy.AddDays(-4)
Comp '5a2. y con diez dias DISTINTOS, tambien una sola' ($script:vecesLeido -eq $leido2) ([string]($script:vecesLeido - $leido2) + ' lecturas de mas')
Comp '5a3. y el corte es el mismo para cualquier dia' (((Get-CorteDia $hoy.AddDays(-10)) -eq (Get-CorteDia $hoy)) -and ((Get-CorteDia $hoy.AddDays(1)) -eq (Get-CorteDia $hoy))) 'hay UNA franja vigente, no una por dia'
# y aunque los datos cambien a media sesion, el corte del dia NO se mueve
$corteAntes = Get-CorteDia $hoy
$script:horasFalsas = @{ 3 = 9; 4 = 9; 5 = 9 }      # de golpe madruga
Comp '5b. el corte no cambia en el mismo dia' ((Get-CorteDia $hoy.AddHours(3)) -eq $corteAntes) 'cambiarlo a media sesion deja dos mitades que no cuadran'
# EL CAMBIO DE DIA SE PRUEBA MOVIENDO EL SELLO, NO PASANDO UNA FECHA FUTURA (28/09). Antes este caso
# hacia Get-CorteDia $hoy.AddDays(1) y daba por bueno que eso recalculara: o sea que daba por bueno
# justo el fallo -que la fecha preguntada decidiera la cache-. Lo que se quiere vigilar es que al
# cambiar el dia DE VERDAD se vuelva a calcular, y eso es el sello.
$script:franjaCalculadaDia = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
$leido3 = $script:vecesLeido
$corteNuevo = Get-CorteDia $hoy
Comp '5c. y al cambiar el dia de verdad si se recalcula' (($script:vecesLeido -eq ($leido3 + 1)) -and ($corteNuevo -ne $corteAntes)) ('1 lectura nueva y el corte pasa de las ' + [string]$corteAntes + ' a las ' + [string]$corteNuevo)

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '6a. ya no queda ningun AddHours(-5) a mano' (-not ($sinCom -match 'AddHours\(-5\)')) 'eran siete'
Comp '6b. Get-DiaJuego pregunta por el corte' ($sinCom -match 'function Get-DiaJuego.*Get-CorteDia') ''
Comp '6c. el silencio nocturno tambien' ($sinCom -match '\$hastaMin = \[int\]\(Get-NocheHasta\) \* 60') ''
Comp '6d. y Test-EsNocheAviso' ($sinCom -match '\$hastaN = \[int\]\(Get-NocheHasta \$ahora\) \* 60') ''
Comp '6e. la franja se guarda por dia' ($sinCom -match '\$script:franjaCalculadaDia -eq \$hoyF') ''
Comp '6f. y Floor, no [int], para que 7/2 no redondee a 4' ($sinCom -match '\[Math\]::Floor\(\$mejorLargo / 2\)') 'PowerShell redondea 3,5 a 4'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la franja muerta sale de sus horas, y el dia parte donde no hay nadie' -ForegroundColor Green
exit 0
