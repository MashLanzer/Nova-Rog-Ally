# EL RESUMEN DE LA PARTIDA QUE ACABA (1/10, la 20 de las 20 funciones nuevas)
#
# Nova escribia el parte del dia y el resumen de la semana, pero de la SESION que se cierra no decia
# nada, y es el momento en que apetece oirlo: acabas de soltar el mando.
#
# TODO SALE DE LO QUE YA MIDE: los minutos de la partida, lo jugado hoy, la bateria del tramo y los
# logros que cayeron. LO QUE ESTA SECCION DEFIENDE es que si de algo no hay dato, esa parte NO SE
# DICE en vez de rellenarse con un cero: "se han ido 0 puntos de bateria" es peor que no decirlo.
#
# Y VA EN EL CIERRE DE VERDAD, no en Exit-Juego: aquel se dispara en cada alt-tab -cinco de once
# salidas del log duraron menos de dos minutos- y un resumen por alt-tab seria insoportable.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
Invoke-Expression (Traer 'Get-FraseResumenSesion')
# los dobles: lo jugado hoy y la bateria
$script:hoyMin = 0
function Get-MinutosJuegoHoy { param($j = '') return $script:hoyMin }
$script:bateriaPct = 60
$script:hayBateria = $true
function Get-CimInstance { param($ClassName, $Namespace, $Filter, $ErrorAction)
    if (-not $script:hayBateria) { return @() }
    return @([pscustomobject]@{ EstimatedChargeRemaining = $script:bateriaPct; BatteryStatus = 1 }) }

Write-Host ''
Write-Host '-- 1. lo basico: cuanto has jugado --'
$script:sesionBatDesde = -1; $script:logrosSesion = 0; $script:hoyMin = 0
$f = Get-FraseResumenSesion 'Elden Ring De Pega' 45 2700
Comp 'dice el juego y los minutos' ($f -match 'Elden Ring De Pega' -and $f -match '45 minutos') "$f"
# LAS HORAS SE DICEN COMO HORAS: "95 minutos" es un numero que hay que traducir en la cabeza.
$f2 = Get-FraseResumenSesion 'Juego Largo' 95 5700
Comp 'y mas de una hora, en horas y minutos' ($f2 -match '1 hora y 35 minutos') "$f2"
$f3 = Get-FraseResumenSesion 'Juego Redondo' 120 7200
Comp '  y dos horas justas sin minutos de propina' ($f3 -match '2 horas' -and $f3 -notmatch 'y 0 minutos') "$f3"

Write-Host ''
Write-Host '-- 2. lo jugado HOY, que es el dato que no se tiene en la cabeza --'
$script:hoyMin = 200
$f4 = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp 'dice el total del dia' ($f4 -match 'hoy llevas 3 h 20 min') "$f4"
# Y SI EL TOTAL DEL DIA ES ESTA MISMA PARTIDA, NO SE REPITE: decir "45 minutos, y hoy llevas 45" es
# ruido.
$script:hoyMin = 45
$f5 = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp '  y no lo repite si es la misma partida' ($f5 -notmatch 'hoy llevas') "$f5"

Write-Host ''
Write-Host '-- 3. la bateria, solo si se jugo sin cargador --'
$script:hoyMin = 0
$script:sesionBatDesde = 80
$script:bateriaPct = 55
$f6 = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp 'dice los puntos que se fueron' ($f6 -match '25 puntos de bateria') "$f6"
Comp '  y deja el contador suelto para la siguiente' ($script:sesionBatDesde -eq -1) 'si no, la siguiente partida restaria de aqui'
# SIN DATO DE PARTIDA (enchufado), NO SE DICE NADA DE BATERIA
$script:sesionBatDesde = -1
$f7 = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp 'enchufado, no habla de bateria' ($f7 -notmatch 'bateria') "$f7"
# Y SI SE FUE MUY POCO, TAMPOCO: "se ha ido 1 punto" no es informacion
$script:sesionBatDesde = 60; $script:bateriaPct = 59
$f8 = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp 'y por un punto no dice nada' ($f8 -notmatch 'bateria') "$f8"

Write-Host ''
Write-Host '-- 4. los logros de la partida --'
$script:sesionBatDesde = -1; $script:logrosSesion = 3
$f9 = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp 'dice cuantos cayeron' ($f9 -match '3 logros') "$f9"
Comp '  y pone el contador a cero' ($script:logrosSesion -eq 0) 'si no, la siguiente partida los contaria otra vez'
$script:logrosSesion = 1
Comp 'y uno se dice en singular' ((Get-FraseResumenSesion 'Un Juego' 45 2700) -match '1 logro\b') ''
$script:logrosSesion = 0
Comp 'y sin logros no los menciona' ((Get-FraseResumenSesion 'Un Juego' 45 2700) -notmatch 'logro') ''

Write-Host ''
Write-Host '-- 5. lo que no se dice --'
Comp 'sin juego no hay frase' ((Get-FraseResumenSesion '' 45 2700) -eq '') ''
Comp 'y sin minutos tampoco' ((Get-FraseResumenSesion 'Un Juego' 0 0) -eq '') 'una partida de cero minutos no es una partida'
# Y SI LA BATERIA NO SE PUEDE LEER, no revienta ni se inventa
$script:hayBateria = $false; $script:sesionBatDesde = 80
$fA = Get-FraseResumenSesion 'Un Juego' 45 2700
Comp 'sin poder leer la bateria, sigue diciendo lo demas' ($fA -match '45 minutos' -and $fA -notmatch 'bateria') "$fA"
$script:hayBateria = $true

Write-Host ''
Write-Host '-- 6. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'se llama al resumen en el cierre' ($sinCom -match 'Get-FraseResumenSesion \$s\.nombre') ''
# EN EL CIERRE DE VERDAD, NO EN Exit-Juego: ahi esta la diferencia entre un resumen y un ruido.
$iExit = $sinCom.IndexOf('function Exit-Juego')
$iTest = $sinCom.IndexOf('cerrado de verdad')
$iLlam = $sinCom.IndexOf('Get-FraseResumenSesion $s.nombre')
Comp '  y despues del "cerrado de verdad"' ($iLlam -gt $iTest -and $iTest -gt 0) 'Exit-Juego se dispara en cada alt-tab'
Comp 'la bateria de partida se apunta al entrar' ($sinCom -match '\$script:sesionBatDesde = \[int\]\$bE\.EstimatedChargeRemaining') ''
Comp '  y solo si NO esta enchufado' ($sinCom -match '\[int\]\$bE\.BatteryStatus -ne 2') 'con cargador no hay gasto que contar'
Comp 'y los logros se cuentan donde se detectan' ((@([regex]::Matches($sinCom, '\$script:logrosSesion = \[int\]\$script:logrosSesion \+ 1')).Count) -eq 2) 'los dos sitios que cazan un logro'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova resume la partida al cerrarla, y calla lo que no sabe' -ForegroundColor Green
exit 0
