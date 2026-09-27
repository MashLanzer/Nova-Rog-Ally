# QUE NOVA SE MIDA A SI MISMA CONTRA STEAM, EN FRIO (27/09, idea 113 de las 121)
#
# EL DATO, sacado de los dos cuadernos de Nova el 25/09:
#   memoria\juegos.json     'ELDEN RING NIGHTREIGN' ->    75 segundos
#   memoria\uso-ally.json   'nightreign'            -> 4.038 segundos con alguien delante
#                           'ELDEN RING NIGHTREIGN' ->    10 segundos
# Nova SI vio la partida entera: la apunto en el otro cuaderno y con el nombre del ejecutable, y
# nunca cruzo las dos cuentas. La ficha creia que el dato se perdia; estaba partido en dos ficheros
# que no se hablaban. Y Steam sella LastPlayed de nightreign el 25/09 a las 23:53, que es el arbitro.
#
# LO QUE ESTE BANCO PROTEGE, y todo con los DOS DIAS DE VERDAD que hay en disco:
#   1. que se use SOLO la columna 'con': explorer tiene con=2.797 y sin=64.083 el 26/09, asi que
#      sumando las dos el escritorio de Windows es el candidato de todos los dias
#   2. que el escritorio no pueda ser un juego nunca
#   3. que solo se aprenda con UN desconocido y UN juego de Steam: adivinar entre dos cierra el
#      microfono por la cara
#   4. que un desconocido que pierde contra un juego bien visto no se lleve la partida
#   5. que sin cuaderno de ese dia no se acuse a nadie (la guarda de la ficha, gratis)
#   6. que se aprenda en el MISMO juegos-exes.json del aprendizaje en vivo, sin estrenar cuaderno
#   7. y que alguien lo lea cuando braya pregunte cuanto ha jugado
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
$quiero = @('Find-CiegosDeUnDia', 'Get-ColaCiegos', 'Get-JuegosDeSteamDelDia')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 3 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)

# EL MUNDO DE MENTIRA (despues de cargar)
$ExesJuegoMinSeg = 600
$CiegoFraccion = 3
$CiegoShell = @('explorer', 'dwm', 'shellexperiencehost', 'searchhost', 'startmenuexperiencehost',
                'applicationframehost', 'pickerhost', 'textinputhost', 'systemsettings',
                'lockapp', 'searchapp', 'widgets', 'sihost', 'taskmgr')
$script:juegosCiegos = @{}
function Get-JuegosCiegos { return $script:juegosCiegos }

# EL CUADERNO DEL 25/09, COPIADO DE memoria\uso-ally.json TAL CUAL
$dia25 = @{
    'nightreign'            = @{ con = 4038; sin = 0 }
    'explorer'              = @{ con = 321;  sin = 17802 }
    'EADesktop'             = @{ con = 30;   sin = 0 }
    'steamwebhelper'        = @{ con = 19;   sin = 0 }
    'Discord'               = @{ con = 10;   sin = 0 }
    'ELDEN RING NIGHTREIGN' = @{ con = 10;   sin = 0 }
    'SearchHost'            = @{ con = 10;   sin = 0 }
}
# Y EL DEL 26/09, el dia en que NO se debe aprender nada
$dia26 = @{
    'Marvel Spider-Man Remastered' = @{ con = 5486; sin = 0 }
    'explorer'                     = @{ con = 2797; sin = 64083 }
    'EmuDeck'                      = @{ con = 1850; sin = 320 }
    'msedge'                       = @{ con = 1260; sin = 0 }
    'Black Myth: Wukong'           = @{ con = 860;  sin = 0 }
    'utweb'                        = @{ con = 410;  sin = 0 }
    'steamwebhelper'                = @{ con = 390;  sin = 0 }
    'WindowsTerminal'              = @{ con = 180;  sin = 0 }
    'python-3.11.0-amd64'          = @{ con = 110;  sin = 0 }
    'mame'                         = @{ con = 0;    sin = 20 }
}
$conocidos = @('ELDEN RING NIGHTREIGN', 'ELDEN RING', 'Marvel Spider-Man Remastered',
               'Black Myth: Wukong', 'A Way Out', 'Unravel Two', 'The Past Within',
               'CatQuest_Purribean', 'It Takes Two')

Write-Host ''
Write-Host '-- 1. EL 25/09 DE VERDAD: LA PARTIDA DE UNA HORA QUE CONTO 75 SEGUNDOS --'
$r = Find-CiegosDeUnDia $dia25 $conocidos @('ELDEN RING NIGHTREIGN') @{ 'ELDEN RING NIGHTREIGN' = 75 }
Comp '1a. sale un solo candidato desconocido' (@($r.candidatos).Count -eq 1) ([string]@($r.candidatos).Count)
Comp '1b. y es nightreign, con sus 4.038 s' (([string]$r.mayor.proc -eq 'nightreign') -and ([int]$r.mayor.seg -eq 4038)) ([string]$r.mayor.proc + ' ' + [int]$r.mayor.seg + ' s')
Comp '1c. se aprende que es NIGHTREIGN' ([string]$r.aprende -eq 'ELDEN RING NIGHTREIGN') ([string]$r.aprende)
Comp '1d. y el juego queda marcado como ciego' (@($r.ciegos).Count -eq 1) ([string]@($r.ciegos).Count)
Comp '1e. con lo que vio y lo que pudo ver' ((@($r.ciegos)[0].visto -eq 75) -and (@($r.ciegos)[0].podria -eq 4038)) '75 de 4.038 es el 1,9 %'
Comp '1f. y con el nombre del proceso que si lo vio' (@($r.ciegos)[0].proceso -eq 'nightreign') 'eso es lo que permite arreglarlo'

Write-Host ''
Write-Host '-- 2. SOLO LA COLUMNA "con": EL ESCRITORIO TIENE 64.083 EN "sin" --'
Comp '2a. explorer no sale de candidato el 25' (@($r.candidatos | Where-Object { $_.proc -eq 'explorer' }).Count -eq 0) 'con=321, sin=17.802'
$r26 = Find-CiegosDeUnDia $dia26 $conocidos @('Marvel Spider-Man Remastered', 'Black Myth: Wukong') @{ 'Marvel Spider-Man Remastered' = 5485; 'Black Myth: Wukong' = 860 }
Comp '2b. ni el 26, con sus 2.797 en "con"' (@($r26.candidatos | Where-Object { $_.proc -eq 'explorer' }).Count -eq 0) 'sumando las dos columnas ganaria a cualquier juego'
# LO QUE PASARIA SIN LA LISTA, ejecutado de verdad y no razonado: se le cambia el nombre a explorer
# por uno que la lista no conoce y con sus 2.797 s se convierte en el mayor candidato del 26/09.
$comoSiNo = @{}
foreach ($k in $dia26.Keys) { $comoSiNo[$(if ($k -eq 'explorer') { 'unNombreCualquiera' } else { $k })] = $dia26[$k] }
$rSin = Find-CiegosDeUnDia $comoSiNo $conocidos @('Marvel Spider-Man Remastered', 'Black Myth: Wukong') @{ 'Marvel Spider-Man Remastered' = 5485; 'Black Myth: Wukong' = 860 }
Comp '2c. sin la lista, el escritorio seria el mayor' ([string]$rSin.mayor.proc -eq 'unNombreCualquiera') ([string]$rSin.mayor.proc + ' con ' + [int]$rSin.mayor.seg + ' s')
Comp '2d. y explorer esta en la lista del fichero real' ($sinCom.Contains("CiegoShell = @('explorer'")) 'no es un umbral: explorer.exe ES el escritorio'
# Y UN CASO QUE LA LISTA DEL SHELL NO TAPA, que es donde de verdad se ve si se usa 'con' o la suma:
# una app cualquiera dejada abierta toda la noche. 120 s con alguien delante y 30.000 sin nadie es
# el patron real de explorer, y pasa igual con cualquier cosa que no este en la lista.
$nocturno = @{
    'algunaApp'             = @{ con = 120;  sin = 30000 }
    'ELDEN RING NIGHTREIGN' = @{ con = 1200; sin = 0 }
}
$rN = Find-CiegosDeUnDia $nocturno $conocidos @('ELDEN RING NIGHTREIGN') @{ 'ELDEN RING NIGHTREIGN' = 1200 }
Comp '2e. lo abierto toda la noche no es candidato' (@($rN.candidatos).Count -eq 0) 'con=120 y sin=30.000: sumando seria el mayor del dia'
Comp '2f. y no se acusa a nadie por ello' ((@($rN.ciegos).Count -eq 0) -and ([string]$rN.aprende -eq '')) ''

Write-Host ''
Write-Host '-- 3. EL 26/09: DOS DESCONOCIDOS, ASI QUE NO SE APRENDE NADA --'
Comp '3a. salen dos candidatos' (@($r26.candidatos).Count -eq 2) ([string]@($r26.candidatos).Count + ': ' + ((@($r26.candidatos) | ForEach-Object { $_.proc }) -join ', '))
Comp '3b. EmuDeck y msedge, los dos por encima de 600' ((@($r26.candidatos)[0].proc -eq 'EmuDeck') -and (@($r26.candidatos)[1].proc -eq 'msedge')) 'el liston de 600 s NO los separa'
Comp '3c. y NO se aprende nada' ([string]$r26.aprende -eq '') 'adivinar entre dos cierra el microfono por la cara'
Comp '3d. y ningun juego sale ciego' (@($r26.ciegos).Count -eq 0) '5.485 de 5.486 y 860 de 860: las cuentas casan'

Write-Host ''
Write-Host '-- 4. UN DESCONOCIDO QUE PIERDE NO SE LLEVA LA PARTIDA --'
# mismo dia, pero con un juego bien visto que le gana al desconocido
$mezcla = @{
    'algo_raro'             = @{ con = 700;  sin = 0 }
    'ELDEN RING NIGHTREIGN' = @{ con = 3000; sin = 0 }
}
$rM = Find-CiegosDeUnDia $mezcla $conocidos @('ELDEN RING NIGHTREIGN') @{ 'ELDEN RING NIGHTREIGN' = 3000 }
Comp '4a. hay un candidato y un juego de Steam' ((@($rM.candidatos).Count -eq 1) -and ([int]$rM.mayor.seg -eq 700)) ''
Comp '4b. pero NO se aprende' ([string]$rM.aprende -eq '') 'Nova vio 3.000 s del juego y 700 del desconocido'
Comp '4c. ni sale ciego' (@($rM.ciegos).Count -eq 0) '3.000 no es menos de un tercio de 700'

Write-Host ''
Write-Host '-- 5. EL SUELO DE RUIDO Y LOS DOS JUEGOS DE STEAM --'
$flojo = @{ 'apenas' = @{ con = 599; sin = 0 } }
$rF = Find-CiegosDeUnDia $flojo $conocidos @('ELDEN RING') @{}
Comp '5a. con 599 s no es candidato' (@($rF.candidatos).Count -eq 0) 'por debajo de diez minutos nadie es un juego'
$rF2 = Find-CiegosDeUnDia @{ 'apenas' = @{ con = 600; sin = 0 } } $conocidos @('ELDEN RING') @{}
Comp '5b. con 600 justos, si' (@($rF2.candidatos).Count -eq 1) 'el mismo liston que el aprendizaje en vivo'
# dos juegos de Steam el mismo dia: se detecta el ciego pero no se atribuye
$rD = Find-CiegosDeUnDia $dia25 $conocidos @('ELDEN RING NIGHTREIGN', 'The Past Within') @{ 'ELDEN RING NIGHTREIGN' = 75; 'The Past Within' = 5680 }
Comp '5c. con dos juegos de Steam no se aprende' ([string]$rD.aprende -eq '') 'el 25/09 de verdad Steam sella cuatro'
Comp '5d. pero el ciego se sigue detectando' (@($rD.ciegos).Count -eq 1) 'NIGHTREIGN con 75 s sigue estando mal'
Comp '5e. y el que SI cuadra no se acusa' ((@($rD.ciegos) | Where-Object { $_.juego -eq 'The Past Within' }).Count -eq 0) '5.680 s pasan de sobra el tercio'

Write-Host ''
Write-Host '-- 6. SIN CUADERNO NO SE JUZGA A NADIE (la guarda de la ficha) --'
$rV = Find-CiegosDeUnDia $null $conocidos @('ELDEN RING') @{}
Comp '6a. sin cuaderno, ni candidatos ni ciegos' ((@($rV.candidatos).Count -eq 0) -and (@($rV.ciegos).Count -eq 0)) ''
Comp '6b. ni se aprende nada' ([string]$rV.aprende -eq '') ''
$rE = Find-CiegosDeUnDia @{} $conocidos @('ELDEN RING') @{}
Comp '6c. con el cuaderno vacio, igual' ((@($rE.candidatos).Count -eq 0) -and ([string]$rE.aprende -eq '')) 'un dia jugado con Nova apagada'
Comp '6d. y el que corre lo dice en el log' ($sinCom -match 'no tengo cuaderno de uso, asi que no puedo juzgar') ''

Write-Host ''
Write-Host '-- 7. QUE ALGUIEN LO LEA --'
$script:juegosCiegos = @{}
Comp '7a. sin ciegos, no dice nada' ((Get-ColaCiegos) -eq '') ''
$script:juegosCiegos = @{ 'ELDEN RING NIGHTREIGN' = @{ dia = '2026-09-25'; visto = 75; podria = 4038; proceso = 'nightreign' } }
$c1 = Get-ColaCiegos
Comp '7b. con uno, lo nombra' ($c1 -match 'ELDEN RING NIGHTREIGN') ([string]$c1)
Comp '7c. y avisa de que su cuenta se queda corta' ($c1 -match 'se queda cort[oa]') ''
$script:juegosCiegos['Outlast'] = @{ dia = '2026-09-25'; visto = 0; podria = 900; proceso = 'outlast' }
$c2 = Get-ColaCiegos
Comp '7d. con varios, dice cuantos' ($c2 -match '2 juegos') ([string]$c2)

Write-Host ''
Write-Host '-- 8. EL CABLEADO --'
Comp '8a. el repaso cuelga del hueco de una vez al dia' ($sinCom -match '(?s)Invoke-CorreccionesDormidas.{0,400}Test-JuegosCiegos') ''
Comp '8b. y no del bucle' (-not ($sinCom -match '(?s)juegoCheck.{0,400}Test-JuegosCiegos')) 'lee dos ficheros de disco'
Comp '8c. se aprende en el fichero que YA existe' ($sinCom -match '(?s)function Test-JuegosCiegos[\s\S]{0,4000}?Save-ExeJuego') 'no estrena cuaderno para el aprendizaje'
Comp '8d. y el aprendizaje en vivo sigue en pie' ($sinCom -match 'Find-JuegoPorUltimoJugado') 'esto es su red de seguridad, no su sustituto'
Comp '8e. la cola se dice al contestar el tiempo jugado' ($sinCom -match '(?s)Get-TiempoJugado \$a\.dias[\s\S]{0,700}?Get-ColaCiegos') ''
# SOBRE SU PROPIO TEXTO: AddDays(-1) sale en mas sitios del fichero y el caso pasaba por otro
$cuerpoT = @($defs | Where-Object { $_.Name -eq 'Test-JuegosCiegos' })[0].Extent.Text
Comp '8f. solo se repasa AYER' ($cuerpoT -match "AddDays\(-1\)") 'LastPlayed es el ULTIMO jugado: a los dos dias ya no dice nada del dia que se repasa'
Comp '8g. y no el dia de hoy, que esta a medias' (-not ($cuerpoT -match "if \(-not \`$dia\) \{ \`$dia = \(Get-Date\)\.ToString")) ''
Comp '8h. y una sola vez por dia' ($sinCom -match '\$hb\.ciegosVisto') ''
Comp '8i. el modo invitado no aprende' ($sinCom -match '(?s)function Save-JuegoCiego[\s\S]{0,300}?\$script:invitado') 'lo que haga otro no es su cuenta'
$cuerpoF = @($defs | Where-Object { $_.Name -eq 'Find-CiegosDeUnDia' })[0].Extent.Text
Comp '8i. Find-CiegosDeUnDia es pura' (-not ($cuerpoF -match '(Get-Date|\$sw\.|Log |Test-Path|Get-Content)')) 'por eso se puede probar con los dos dias reales'
Comp '8j. y mira la columna con, no la suma' (($cuerpoF -match '\.con') -and -not ($cuerpoF -match '\.con \+ ')) ''
Comp '8k. el tope del fichero es el mismo de juegos-exes' (($sinCom -match '\$CiegosMax = 40') -and ($sinCom -match '\$ExesJuegoMax = 40')) ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova ya cruza sus dos cuentas y sabe a que juegos ve mal' -ForegroundColor Green
exit 0
