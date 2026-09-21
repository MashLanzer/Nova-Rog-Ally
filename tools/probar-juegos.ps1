# Pruebas de lo que Nova recuerda de cada juego: donde te quedaste ("me quede
# en...") y cuanto gasta de bateria, aprendido por tramos.
# Trabaja en una carpeta temporal propia y la borra al acabar.
#
#   powershell -NoProfile -File tools\probar-juegos.ps1
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn($n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta la funcion $n en assistant.ps1" }
    return $f.Extent.Text
}
foreach ($n in 'Get-JuegosMem', 'Save-JuegosMem', 'Get-JuegoDeReferencia', 'Set-NotaJuego', 'Get-HaceCuanto', 'Update-BateriaJuego',
    'Get-DuracionBateriaJuego', 'Format-Minutos', 'Show-RecuerdoJuego', 'Add-TiempoJuego', 'Get-DiasJuego', 'Save-TiempoJuego',
    'Get-TiempoJugado') { Invoke-Expression (TraerFn $n) }

$MemoriaDir = Join-Path $env:TEMP ('nova-juegos-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $MemoriaDir | Out-Null
# un reloj de mentira: los tramos de bateria duran minutos y aqui no se espera
$script:ahoraMs = 0
$sw = New-Object PSObject
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$script:juegosMem = $null; $script:ultimoJuego = $null; $script:ultimoJuegoEn = 0
$script:tramoBat = $null; $script:juegoRecordado = @{}
$script:juegoActivo = $null; $script:uiCargando = 0; $script:uiBateria = 80
$script:ui = @()
function Log($m) {}
function Set-UI($e, $t, $ms) { $script:ui += "$e|$t" }
$mal = 0
function Comp($etq, $ok, $det = '') {
    if (-not $ok) { $script:mal++ }
    "  {0}  {1}{2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $etq, $(if ("$det" -ne '') { "  -> $det" } else { '' })
}

Write-Host "--- donde te quedaste ---"
Comp 'sin juego delante ni reciente, no hay juego de referencia' ($null -eq (Get-JuegoDeReferencia))
$script:juegoActivo = 'Hollow Knight'
Comp 'con uno delante, es ese' ((Get-JuegoDeReferencia) -eq 'Hollow Knight')
Set-NotaJuego 'Hollow Knight' 'el jefe del Castillo'
$script:juegosMem = $null
$mJ = Get-JuegosMem
Comp 'la nota se guarda y se relee del archivo' ($mJ['Hollow Knight']['nota'] -ceq 'el jefe del Castillo') $mJ['Hollow Knight']['nota']
$script:juegoActivo = $null; $script:ultimoJuego = 'Hollow Knight'; $script:ultimoJuegoEn = 0; $script:ahoraMs = 3600000
Comp 'recien cerrado (1 h), sigue siendo el de referencia' ((Get-JuegoDeReferencia) -eq 'Hollow Knight')
$script:ahoraMs = 3 * 3600000
Comp 'pasadas 2 h, ya no' ($null -eq (Get-JuegoDeReferencia))
Comp 'hace un rato' ((Get-HaceCuanto ((Get-Date).AddMinutes(-30).ToString('yyyy-MM-dd HH:mm'))) -eq 'hace un rato')
Comp 'ayer' ((Get-HaceCuanto ((Get-Date).AddDays(-1).ToString('yyyy-MM-dd 12:00'))) -eq 'ayer')
$re = '(?i)^\s*(?:me\s+(?:he\s+)?qued[eé]|me\s+quedo|lo\s+dej[oeé])\s+(?:en|por)\s+(.{3,120}?)[\s.]*$'
$reAst = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $x.Value -like '(?i)^\s*(?:me\s+(?:he\s+)?qued*' }, $true)
Comp 'el patron de la prueba es el del asistente' ($reAst -and $reAst.Value -eq $re)
Comp '"Me quede en el capitulo 3." encaja y guarda lo de detras' (('Me quedé en el capítulo 3.' -match $re) -and $Matches[1] -eq 'el capítulo 3') $Matches[1]
Comp '"lo dejo por la mina" encaja' ('lo dejo por la mina' -match $re)
Comp '"me quede dormido" no encaja' (-not ('me quede dormido' -match $re))

Write-Host "--- bateria por juego ---"
$script:juegosMem = $null; Remove-Item (Join-Path $MemoriaDir 'juegos.json') -ErrorAction SilentlyContinue
$script:ahoraMs = 0; $script:juegoActivo = 'ELDEN RING'
Update-BateriaJuego 90 0
Comp 'con juego y sin cargador se abre un tramo' ($script:tramoBat -and $script:tramoBat.pct -eq 90)
$script:ahoraMs = 5 * 60000; Update-BateriaJuego 88 0
Comp 'a los 5 min sigue abierto' ($script:tramoBat.pct -eq 90)
$script:ahoraMs = 20 * 60000; Update-BateriaJuego 80 0
Comp 'a los 20 min se cierra y aprende 30 %/h' ([double](Get-JuegosMem)['ELDEN RING']['ritmoBateria'] -eq 30) (Get-JuegosMem)['ELDEN RING']['ritmoBateria']
Comp 'y abre el siguiente tramo desde el % de ahora' ($script:tramoBat.pct -eq 80)
$script:ahoraMs = 40 * 60000; Update-BateriaJuego 60 0
Comp 'el segundo tramo (60 %/h) se mezcla: 0.6*30 + 0.4*60 = 42' ([double](Get-JuegosMem)['ELDEN RING']['ritmoBateria'] -eq 42) (Get-JuegosMem)['ELDEN RING']['ritmoBateria']
$script:ahoraMs = 43 * 60000; Update-BateriaJuego 59 1
Comp 'enchufar cierra el tramo sin aprender (3 min es poco)' ($null -eq $script:tramoBat -and [int](Get-JuegosMem)['ELDEN RING']['muestrasBateria'] -eq 2)
Comp 'cargando no abre tramo' ($null -eq $script:tramoBat)
$script:juegoActivo = $null; Update-BateriaJuego 59 0
Comp 'sin juego no abre tramo' ($null -eq $script:tramoBat)
Comp 'duracion: 84 % a 42 %/h son 120 min' ((Get-DuracionBateriaJuego 'ELDEN RING' 84) -eq 120)
Comp 'un juego sin datos no inventa' ($null -eq (Get-DuracionBateriaJuego 'Celeste' 50))
Comp 'minutos dichos: 45' ((Format-Minutos 45) -eq '45 minutos')
Comp 'minutos dichos: 100' ((Format-Minutos 100) -eq 'una hora y 40 minutos') (Format-Minutos 100)
Comp 'minutos dichos: 122' ((Format-Minutos 122) -eq '2 horas') (Format-Minutos 122)

Write-Host "--- al entrar en un juego ---"
$script:ui = @(); $script:uiBateria = 84; $script:uiCargando = 0; $script:ahoraMs = 50 * 60000
Set-NotaJuego 'ELDEN RING' 'Leyndell'
Show-RecuerdoJuego 'ELDEN RING'
Comp 'avisa en la capsula: nota y bateria' ($script:ui.Count -eq 1 -and $script:ui[0] -eq 'hablando|Te quedaste en Leyndell · bateria para 2 horas') ($script:ui -join ' / ')
$script:ahoraMs = 70 * 60000; Show-RecuerdoJuego 'ELDEN RING'
Comp 'volver con Alt+Tab a los 20 min no repite' ($script:ui.Count -eq 1)
$script:ahoraMs = 120 * 60000; $script:uiCargando = 1; Show-RecuerdoJuego 'ELDEN RING'
Comp 'pasada una hora si, y cargando no habla de bateria' ($script:ui.Count -eq 2 -and $script:ui[1] -eq 'hablando|Te quedaste en Leyndell') $script:ui[1]
Show-RecuerdoJuego 'Celeste'
Comp 'un juego sin nada que recordar no dice nada' ($script:ui.Count -eq 2)

Write-Host "--- tiempo de juego por dia ---"
$script:juegosMem = $null; Remove-Item (Join-Path $MemoriaDir 'juegos.json') -ErrorAction SilentlyContinue
$script:tiempoJuegoPend = @{}
Add-TiempoJuego 'Hades' 10
Comp 'se acumula en memoria, sin escribir cada 10 s' ($script:tiempoJuegoPend['Hades'] -eq 10 -and -not (Test-Path (Join-Path $MemoriaDir 'juegos.json')))
Add-TiempoJuego 'Hades' 500
Comp 'un salto de mas de 2 min no cuenta (asistente parado, suspension)' ($script:tiempoJuegoPend['Hades'] -eq 10)
# 10 s + 29 x 10 s = 300 s justos: ahi se guarda
for ($i = 0; $i -lt 29; $i++) { Add-TiempoJuego 'Hades' 10 }
Comp 'a los 5 min acumulados se guarda y se vacia' ($script:tiempoJuegoPend.Count -eq 0 -and (Test-Path (Join-Path $MemoriaDir 'juegos.json')))
$hoyT = Get-Date
$script:tiempoJuegoPend = @{ 'Celeste' = 1800 }; Save-TiempoJuego $hoyT.AddDays(-3)
$script:tiempoJuegoPend = @{ 'Celeste' = 3600 }; Save-TiempoJuego $hoyT.AddDays(-10)
$script:juegosMem = $null
$semanaT = @(Get-TiempoJugado 7 $hoyT)
$celT = @($semanaT | Where-Object { $_.juego -eq 'Celeste' })
$hadT = @($semanaT | Where-Object { $_.juego -eq 'Hades' })
Comp 'la semana suma lo de hace 3 dias y no lo de hace 10' ($celT.Count -eq 1 -and $celT[0].minutos -eq 30) ("Celeste=" + $celT[0].minutos)
Comp 'y lo de hoy' ($hadT.Count -eq 1 -and $hadT[0].minutos -eq 5) ("Hades=" + $hadT[0].minutos)
Comp 'de mas a menos' ($semanaT[0].juego -eq 'Celeste')
Comp 'en un mes si entra lo de hace 10 dias' ((@(Get-TiempoJugado 30 $hoyT | Where-Object { $_.juego -eq 'Celeste' })[0].minutos) -eq 90)


Write-Host ''
Write-Host '-- C4: no cantar un cierre de juego que no ha pasado (20/09) --'
# EL CASO REAL: el 20/09 a las 18:59:51 braya abrio ELDEN RING y a las 19:00:08, ONCE
# SEGUNDOS despues, Nova anuncio "Cerraste ELDEN RING. Si quieres, dime donde te quedaste"
# con 0 minutos de partida. El juego seguia abierto -el se lo dijo: "Elden Ring si esta
# abierto"- y de ahi salieron tres minutos de lio hasta que se rindio ("Ya, dejalo").
#
# La causa no era la deteccion, era que el umbral de 3 minutos NO EXISTIA: $JuegoSesionMin
# y $script:juegoSesionMin son la MISMA variable, porque PowerShell no distingue mayusculas
# en los nombres. El umbral se pisaba con el acumulador de minutos y la comparacion quedaba
# en "$minsS -lt 0", falsa para cualquier valor. Nacio roto en el commit c714970 del 19/09
# y la linea "sin aviso" no aparece NI UNA VEZ en todo el historial del log.
$fuenteC4 = [System.IO.File]::ReadAllText($ruta)

# 1. que no haya vuelto la colision de nombres
$declaraC4 = ([regex]::Matches($fuenteC4, '(?m)^\$(?:script:)?juegoSesionMin\s*=', 'IgnoreCase')).Count
Comp 'el acumulador de minutos se declara una sola vez' ($declaraC4 -eq 1) "$declaraC4 declaraciones"
Comp 'y el umbral tiene un nombre que no choca' ($fuenteC4 -match '\$JuegoMinimoPartida\s*=\s*\[int\]\(Get-Cfg')
$usosViejo = @([regex]::Matches($fuenteC4, '(?m)^[^#
]*\$JuegoSesionMin'))
Comp 'el nombre viejo solo queda en el comentario que lo explica' ($usosViejo.Count -eq 0) ("$($usosViejo.Count) usos fuera de comentario")

# 2. y que la comparacion muerda de verdad
# ESTO PROBABA EL OPERADOR -lt DE POWERSHELL, NO EL CODIGO (21/09). El bucle de abajo
# fijaba $JuegoMinimoPartida = 3 a mano y reescribia la comparacion dentro de la prueba:
#     $avisaria = -not ($minsS -lt $JuegoMinimoPartida)
# Eso es una COPIA de la comparacion, no la comparacion. Si manana alguien cambia el if de
# assistant.ps1 -o lo borra-, este bloque sigue en verde tan contento. Y el fallo que
# obligo a escribir esta prueba era exactamente ese: el umbral no existia porque la
# variable se pisaba, o sea que el if estaba ahi y no mordia.
# Asi que primero se comprueba que el if ESTA, con su forma, sobre el archivo de verdad.
Comp 'el cierre se calla de verdad por debajo del minimo' `
    ($fuenteC4 -match '\$minsS = \[int\]\$script:juegoSesionMin[\s\S]{0,240}?if \(\$minsS -lt \$JuegoMinimoPartida\) \{')
Comp 'y lo apunta en el log, para poder mirarlo luego' ($fuenteC4 -match 'min de partida \(minimo \$JuegoMinimoPartida\): sin aviso')
# y la aritmetica, con la comparacion SACADA del archivo, no escrita aqui
$mCmp = [regex]::Match($fuenteC4, '(?m)^\s*if \(\$minsS -lt \$JuegoMinimoPartida\) \{')
if (-not $mCmp.Success) { Comp 'encuentro la comparacion en assistant.ps1' $false } else {
    $cmp = [scriptblock]::Create('param($minsS, $JuegoMinimoPartida) ' + ($mCmp.Value.Trim() -replace '\{$', '') + ' { return $false }; return $true')
    foreach ($cas in @(@{ mins = 0; avisa = $false }, @{ mins = 2; avisa = $false }, @{ mins = 3; avisa = $true }, @{ mins = 40; avisa = $true })) {
        $avisaria = & $cmp ([int]$cas.mins) 3
        Comp ("con $($cas.mins) min de partida " + $(if ($cas.avisa) { 'avisa' } else { 'se calla' })) ($avisaria -eq $cas.avisa)
    }
}

# 3. el contador ya no redondea: [int] de 40 s daba UN MINUTO entero, y tres alt-tabs
#    cortos sumaban 3 minutos sin haber jugado ni dos
Comp 'los minutos se truncan, no se redondean' ($fuenteC4 -match '\$minsFg = \[int\]\[Math\]::Floor')
foreach ($par in @(@{ ms = 40000; min = 0 }, @{ ms = 100000; min = 1 }, @{ ms = 170000; min = 2 })) {
    $v = [int][Math]::Floor($par.ms / 60000)
    Comp ("$($par.ms) ms son $($par.min) minutos") ($v -eq $par.min) "salen $v"
}

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
