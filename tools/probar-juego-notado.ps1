# LO QUE NOVA DICE AL ENTRAR EN UN JUEGO (27/09, idea 120 de las 121)
#
# EL AGUJERO: al entrar en un juego Nova tiene dos bocas y las dos estan cerradas, y no por un fallo,
# sino porque sus numeros estan puestos donde braya no llega.
#
# LOS HUECOS QUE HAY DE VERDAD en memoria\juegos.json -9 juegos, 19 pares (juego, dia)- son
#     1, 1, 1, 1, 1, 2, 2, 4, 5, 7
# o sea que $JuegoVueltaDias = 10 no se ha alcanzado NI UNA VEZ. Y la racha mas larga con un juego
# son TRES dias (ELDEN RING, el 18, 19 y 20/09), mientras $JuegoRachaMin = 3 exige un CUARTO dia
# seguido, que nunca hubo. Se ve en el registro: 'juego-notado' sale CERO veces en los dos ficheros y
# 'JUEGOS: al entrar en' tambien CERO, catorce dias.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que con los datos REALES de braya las dos bocas hablen, que es toda la idea
#   2. que la racha se IGUALE y no se supere: con el record en 3, superarlo es lo que nunca ha hecho
#   3. que el liston de la vuelta salga del p90 de sus huecos, con la convencion de la casa
#   4. que con pocos huecos manden los numeros de siempre, y se diga (regla 3)
#   5. que la tarjeta tenga una fuente que NO este vacia nunca
#   6. y que el dia de jugar siga empezando a las cinco de la manana
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
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LAS PIEZAS DE VERDAD. Los dobles van DESPUES.
$quiero = @('Get-HuecosYRachas', 'Get-ListonVuelta', 'Get-ListonRacha', 'Get-ResumenJuego',
            'Get-FraseJuegoNotado', 'Get-DiaJuego', 'Get-CorteDia', 'Get-FranjaMuerta', 'Format-Minutos')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 9 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)
foreach ($v in 'JuegoRachaMin', 'JuegoVueltaDias', 'JuegoHuecosMin', 'CorteDiaHora') {
    $a = $arbol.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq ('$' + $v) }, $true)
    if ($a) { Invoke-Expression ('$' + $v + ' = ' + $a.Right.Extent.Text) }
}
Comp 'los numeros de siempre salen del fichero real' (($JuegoRachaMin -eq 3) -and ($JuegoVueltaDias -eq 10) -and ($JuegoHuecosMin -ge 1)) ("racha $JuegoRachaMin, vuelta $JuegoVueltaDias, minimo $JuegoHuecosMin huecos")

# LOS DIAS DE VERDAD, copiados de memoria\juegos.json
$reales = @{
    'A Way Out'             = @('2026-09-23', '2026-09-24')
    'Black Myth: Wukong'    = @('2026-09-19', '2026-09-26')
    'CatQuest_Purribean'    = @('2026-09-20')
    'ELDEN RING'            = @('2026-09-18', '2026-09-19', '2026-09-20', '2026-09-25')
    'ELDEN RING NIGHTREIGN' = @('2026-09-25')
    'It Takes Two'          = @('2026-09-15', '2026-09-16', '2026-09-20', '2026-09-22', '2026-09-23')
    'Spider-Man'            = @('2026-09-26')
    'The Past Within'       = @('2026-09-25')
    'Unravel Two'           = @('2026-09-23', '2026-09-25')
}
$script:diasFalsos = @{}
function Get-DiasDeJuego([string]$nombre) { if ($script:diasFalsos.ContainsKey($nombre)) { return @($script:diasFalsos[$nombre]) } return @() }
function Get-TodosLosDiasDeJuego { return $script:diasFalsos }
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
# EL CORTE DEL DIA DE JUGAR NO ES UN 5 ESCRITO: sale de Get-FranjaMuerta, que mide la franja en la
# que braya nunca esta. Aqui no hay pulso del que sacarla, asi que se fija el de por defecto del
# fichero real y se dice; probar con un corte de mentira seria probar otra cosa.
$a = $arbol.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$CorteDiaPorDefecto' }, $true)
Invoke-Expression ('$CorteDiaPorDefecto = ' + $a.Right.Extent.Text)
$script:franjaCalculadaDia = (Get-Date).ToString('yyyy-MM-dd')
$script:corteDia = $CorteDiaPorDefecto
Comp 'el corte del dia sale del fichero real' ($CorteDiaPorDefecto -ge 0 -and $CorteDiaPorDefecto -le 12) ('las ' + $CorteDiaPorDefecto + ', y lo mide Get-FranjaMuerta')

Write-Host ''
Write-Host '-- 1. LOS HUECOS Y LAS RACHAS QUE HAY DE VERDAD --'
$hr = Get-HuecosYRachas $reales
$hs = @(@($hr.huecos) | Sort-Object)
Comp '1a. salen los diez huecos' ($hs.Count -eq 10) ([string]$hs.Count + ': ' + ($hs -join ', '))
Comp '1b. y son los de su fichero' (($hs -join ',') -eq '1,1,1,1,1,2,2,4,5,7') ''
Comp '1c. la racha mas larga es de ELDEN RING' ([int]$hr.rachas['ELDEN RING'] -eq 3) ('3 dias: el 18, 19 y 20/09')
Comp '1d. y ningun otro pasa de dos' ((@(@($hr.rachas.Keys) | Where-Object { [int]$hr.rachas[$_] -gt 2 }).Count) -eq 1) ''
Comp '1e. un juego de un solo dia da racha 1' ([int]$hr.rachas['The Past Within'] -eq 1) ''

Write-Host ''
Write-Host '-- 2. LOS LISTONES QUE SALEN DE ESO --'
$lv = Get-ListonVuelta $hr.huecos
Comp '2a. la vuelta pasa a ser 5 dias' ([int]$lv.dias -eq 5) ([string]$lv.deDonde)
Comp '2b. y dice de que cuenta sale' ($lv.deDonde -match 'p90 de 10 huecos') ''
Comp '2c. el 10 de siempre no se alcanzaba nunca' ($JuegoVueltaDias -gt (@($hs)[-1])) ('el mayor hueco son ' + @($hs)[-1] + ' dias y el liston eran ' + $JuegoVueltaDias)
$lr = Get-ListonRacha ([int]$hr.rachas['ELDEN RING'])
Comp '2d. la racha de ELDEN RING se queda en 3' ([int]$lr.dias -eq 3) ([string]$lr.deDonde)
Comp '2e. y dice que es su record' ($lr.deDonde -match 'tu record con el son 3') ''
# el suelo: un juego sin historial no baja de 3
Comp '2f. sin rachas, manda el de siempre' ([int](Get-ListonRacha 0).dias -eq $JuegoRachaMin) ''
Comp '2g. y un record de 1 no baja el liston' ([int](Get-ListonRacha 1).dias -eq $JuegoRachaMin) 'por debajo de tres, todo seria noticia'
Comp '2h. pero un record de 6 lo sube' ([int](Get-ListonRacha 6).dias -eq 6) 'quien encadena seis no se sorprende con tres'

Write-Host ''
Write-Host '-- 3. CON LOS DATOS REALES, LAS DOS BOCAS HABLAN --'
$script:diasFalsos = $reales
# LA RACHA: el 20/09 ELDEN RING llevaba el 18 y el 19 detras, y ese fue el tercero
$script:diasFalsos = @{ 'ELDEN RING' = @('2026-09-18', '2026-09-19') }
$f = Get-FraseJuegoNotado 'ELDEN RING' (Get-Date '2026-09-20 18:00')
Comp '3a. el 20/09 habria dicho la racha' ($f -match 'dia 3 seguido') ([string]$f)
# LA VUELTA: el 25/09 llevaba 5 dias sin tocarlo
$script:diasFalsos = $reales
$script:diasFalsos['ELDEN RING'] = @('2026-09-18', '2026-09-19', '2026-09-20')
$f2 = Get-FraseJuegoNotado 'ELDEN RING' (Get-Date '2026-09-25 18:00')
Comp '3b. y el 25/09 habria dicho la vuelta' ($f2 -match 'Hacia 5 dias') ([string]$f2)
Comp '3c. con el 10 de siempre se habria callado' (5 -lt $JuegoVueltaDias) 'ahi esta el agujero de catorce dias'
# y lo dice en el log, con la cuenta
Comp '3d. y lo apunta con su cuenta' (@($script:logs | Where-Object { $_ -match 'liston' }).Count -ge 1) ([string]@($script:logs)[-1])

Write-Host ''
Write-Host '-- 4. LA RACHA SE IGUALA, NO SE SUPERA --'
# con dos dias detras y el liston en 3, HOY es el tercero: se iguala y se habla
$script:diasFalsos = @{ 'X' = @('2026-09-18', '2026-09-19') }
Comp '4a. dos detras y hoy, habla' ((Get-FraseJuegoNotado 'X' (Get-Date '2026-09-20 18:00')) -match 'dia 3 seguido') ''
# con uno solo detras, no
$script:diasFalsos = @{ 'X' = @('2026-09-19') }
Comp '4b. uno detras, no' ((Get-FraseJuegoNotado 'X' (Get-Date '2026-09-20 18:00')) -eq '') 'dos dias no es una racha'
# y si su record fuera 5, hacen falta 5
$script:diasFalsos = @{ 'X' = @('2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04', '2026-09-05', '2026-09-18', '2026-09-19') }
Comp '4c. con record de 5, dos detras no basta' ((Get-FraseJuegoNotado 'X' (Get-Date '2026-09-20 18:00')) -notmatch 'seguido') 'su record son 5'
$script:diasFalsos = @{ 'X' = @('2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04', '2026-09-05',
                                '2026-09-16', '2026-09-17', '2026-09-18', '2026-09-19') }
Comp '4d. y con cuatro detras, si' ((Get-FraseJuegoNotado 'X' (Get-Date '2026-09-20 18:00')) -match 'dia 5 seguido') 'iguala su record'

Write-Host ''
Write-Host '-- 5. CON POCOS HUECOS MANDAN LOS DE SIEMPRE, Y SE DICE --'
$pocos = Get-ListonVuelta @(1, 2, 3, 4)
Comp '5a. con cuatro huecos, el de siempre' ([int]$pocos.dias -eq $JuegoVueltaDias) ([string]$pocos.deDonde)
Comp '5b. y lo dice' ($pocos.deDonde -match 'hacen falta') 'la regla 3: lo que no se sabe se dice'
Comp '5c. con cinco ya se mide' ([int](Get-ListonVuelta @(1, 2, 3, 4, 9)).dias -ne $JuegoVueltaDias) ''
Comp '5d. sin ningun hueco, el de siempre' ([int](Get-ListonVuelta @()).dias -eq $JuegoVueltaDias) ''
# y el suelo de tres tambien manda en la vuelta
Comp '5e. con huecos de un dia, el suelo son 3' ([int](Get-ListonVuelta @(1, 1, 1, 1, 1, 1)).dias -eq 3) 'si no, hablaria cada dos por tres'

Write-Host ''
Write-Host '-- 6. LA TARJETA GANA UNA FUENTE QUE NO ESTA VACIA NUNCA --'
# ELDEN RING: 331+12+11+21 = 375 segundos en sus cuatro dias
$diasER = @{ '2026-09-18' = 331; '2026-09-19' = 12; '2026-09-20' = 11; '2026-09-25' = 21 }
$rj = Get-ResumenJuego 'ELDEN RING' $diasER (Get-Date '2026-09-27 18:00')
Comp '6a. suma los minutos de sus dias' ([int]$rj.minutos -eq 6) ('375 segundos = 6 minutos')
Comp '6b. y lo dice corto' ($rj.cuanto -match 'llevas .* con esto') ([string]$rj.cuanto)
Comp '6c. dice cuando fue la ultima' ([int]$rj.hueco -eq 2) ('del 25 al 27 son 2 dias')
Comp '6d. con su frase' ($rj.ultima -match 'hace 2 dias') ([string]$rj.ultima)
$ayer = Get-ResumenJuego 'X' @{ '2026-09-26' = 3600 } (Get-Date '2026-09-27 18:00')
Comp '6e. y si fue ayer, lo dice asi' ($ayer.ultima -eq 'la ultima vez fue ayer') ([string]$ayer.ultima)
$hoy = Get-ResumenJuego 'X' @{ '2026-09-27' = 3600 } (Get-Date '2026-09-27 18:00')
Comp '6f. si es hoy, no dice la ultima vez' ($hoy.ultima -eq '') 'esta jugando ahora'
Comp '6g. pero si las horas' ([int]$hoy.minutos -eq 60) ([string]$hoy.cuanto)
$vacio = Get-ResumenJuego 'X' @{} (Get-Date '2026-09-27 18:00')
Comp '6h. sin dias, no dice nada' (([int]$vacio.minutos -eq 0) -and ($vacio.cuanto -eq '')) ''

Write-Host ''
Write-Host '-- 7. EL DIA DE JUGAR EMPIEZA A LAS CINCO --'
# a las 02:00 del 27 todavia es el dia 26: si no, la cuenta se va un dia y esa es la franja en la
# que braya juega (su sesion continua mas larga acaba a las 00:45)
$madrugada = Get-ResumenJuego 'X' @{ '2026-09-26' = 3600 } (Get-Date '2026-09-27 02:00')
Comp '7a. antes del corte, el dia sigue siendo el de ayer' ([int]$madrugada.hueco -eq 0) ('el corte esta en las ' + $CorteDiaPorDefecto + '; con la fecha natural diria "ayer"')
$tarde = Get-ResumenJuego 'X' @{ '2026-09-26' = 3600 } (Get-Date '2026-09-27 18:00')
Comp '7b. y a las 18:00 ya es ayer' ([int]$tarde.hueco -eq 1) ''
# y la racha usa el mismo corte
$script:diasFalsos = @{ 'X' = @('2026-09-25', '2026-09-26') }
Comp '7c. la racha tambien lo respeta' ((Get-FraseJuegoNotado 'X' (Get-Date '2026-09-27 03:00')) -eq '') 'a las 03:00 del 27 es el 26, y ese dia ya jugo'

Write-Host ''
Write-Host '-- 8. EL CABLEADO Y LAS GUARDAS QUE YA ESTABAN --'
Comp '8a. si ya jugo hoy, no dice nada' ($sinCom -match '\$dias -contains \$hoyS') 'una vez al dia, no en cada arranque'
Comp '8b. la tarjeta sigue con su hora de freno' ($sinCom -match 'juegoRecordado\[\$nombre\]\) -lt 3600000') ''
Comp '8c. y con su tope de 70 caracteres' ($sinCom -match '\$txtR\.Length -gt 70') ''
# Y QUE LA FUENTE NUEVA ESTE ENGANCHADA, que es lo unico que hace que la tarjeta salga: el apartado
# 6 prueba Get-ResumenJuego suelta, y sin este caso quitarle la llamada a Show-RecuerdoJuego dejaba
# el banco verde con la tarjeta tan muda como estaba.
$cuerpoT = @($defs | Where-Object { $_.Name -eq 'Show-RecuerdoJuego' })[0].Extent.Text
Comp '8c2. la tarjeta llama a Get-ResumenJuego' ($cuerpoT -match 'Get-ResumenJuego \$nombre') 'sin esto seguiria sin salir nunca'
Comp '8c3. y usa las dos frases' (($cuerpoT -match '\$rec\.cuanto') -and ($cuerpoT -match '\$rec\.ultima')) 'las horas y la ultima vez'
Comp '8c4. sin pisar la nota ni la bateria' (($cuerpoT -match "\['nota'\]") -and ($cuerpoT -match 'Get-DuracionBateriaJuego')) 'se anade, no sustituye'
Comp '8d. la tarjeta sigue sin voz' ($sinCom -match "(?s)JUEGOS: al entrar en[^\r\n]*\r?\n\s*Set-UI 'hablando'") 'capsula, no altavoz'
Comp '8e. el aviso sigue en nivel bajo' ($sinCom -match "'juego-notado'[^\r\n]{0,80}'bajo'") ''
Comp '8f. los listones se apuntan con su cuenta' (@([regex]::Matches($sinCom, 'liston " \+ \$l')).Count -ge 2) 'para poder ver despues si valian'
$cuerpoV = ((@($defs | Where-Object { $_.Name -eq 'Get-ListonVuelta' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '8g. Get-ListonVuelta es pura' (-not ($cuerpoV -match '(Get-Date|Get-JuegosMem|Log |Test-Path)')) 'por eso se le pueden correr sus huecos reales'
Comp '8h. y usa la convencion de la casa' ($cuerpoV -match 'Floor\(\(\$v\.Count - 1\) \* 0\.9\)') 'la misma de Get-VentanaSeguimiento'
$cuerpoR = ((@($defs | Where-Object { $_.Name -eq 'Get-ResumenJuego' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '8i. Get-ResumenJuego acepta los dias por parametro' ($cuerpoR -match 'function Get-ResumenJuego\(\[string\]\$nombre, \$dias') 'para probarla sin tocar el fichero de braya'
# (el 'mando-huecos.json' que hay en el fichero es de la quietud del mando, otra cosa)
Comp '8j. y no estrena fichero' (-not ($sinCom -match 'juego-huecos\.json|juego-rachas\.json|resumen-juego\.json')) 'todo sale de juegos.json, que ya esta'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'los dos listones salen de sus partidas, y la tarjeta ya tiene que decir' -ForegroundColor Green
exit 0
