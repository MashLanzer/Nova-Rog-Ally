# ABRIR UN JUEGO ERA LO UNICO QUE NOVA NUNCA COMPROBABA (27/09, idea 81 de las 121)
#
# EL DATO: SILENT BREATH se mando abrir CINCO veces el 11/09 (15:24, 17:33, 18:10, 19:21 y 20:15, dos
# de ellas contestando 'si' a una pregunta de Nova) y el detector de juegos NO lo vio arrancar ni una
# sola vez. Little Nightmares: 7 ordenes y 3 arranques vistos. Outlast: 2 y 1. Que braya repita la
# misma orden cinco veces en cinco horas es la firma de que no pasaba nada, y Nova daba por hecho que
# se habia abierto porque los juegos estaban excluidos A PROPOSITO de la comprobacion de aperturas.
#
# Las dos mitades ya existian -la orden que pide abrir y el detector que ve entrar el juego, que ha
# visto 11 distintos-; faltaba el cable.
#
# LO QUE ESTE BANCO PROTEGE, y es justo el motivo por el que se excluyeron:
#   1. que un juego SIN plazo aprendido NO se vigile: Nova se calla, como hasta hoy
#   2. que el plazo salga de lo que tarda ESE juego (p90 con margen), no de los 10 s de las apps
#   3. que un juego que aparece tarde pero aparece no genere ni una palabra
#   4. que lo que tarda se APUNTE siempre, que es lo que hace que el plazo se aprenda
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
foreach ($f in @('ConvertTo-Plain', 'Get-PercentilLista', 'Get-PlazoJuegoAbre', 'Add-JuegoPedido', 'Test-JuegosPedidos')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
$JuegoAbreMinMuestras = 3
$JuegoAbreMargen = 2.0
$JuegoAbreTopeMs = 600000
Comp 'los tres numeros salen del archivo' (($txt -match '\$JuegoAbreMinMuestras = 3') -and ($txt -match '\$JuegoAbreMargen = 2\.0') -and ($txt -match '\$JuegoAbreTopeMs = 600000')) ''

# los dobles, DESPUES de cargar
$script:medidas = @{}
function Get-TrabajoTiempos([string]$clave) {
    $l = New-Object System.Collections.ArrayList
    if ($script:medidas.ContainsKey($clave)) { foreach ($v in $script:medidas[$clave]) { [void]$l.Add([int]$v) } }
    return , $l
}
$script:apuntadas = @()
function Add-TrabajoTiempo([string]$clave, [int]$ms) {
    $script:apuntadas += @(@{ clave = $clave; ms = $ms })
    if (-not $script:medidas.ContainsKey($clave)) { $script:medidas[$clave] = @() }
    $script:medidas[$clave] += @($ms)
    return $true
}
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
$script:stats = @()
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { $script:stats += @(@{ ruta = $r; detalle = $d }) }
$script:msFalsos = 1000000
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:juegosPedidos = New-Object System.Collections.ArrayList
    $script:juegoActivo = $null
    $script:logs = @()
    $script:stats = @()
    $script:apuntadas = @()
    $script:msFalsos = 1000000
}

Write-Host ''
Write-Host '-- 1. SIN PLAZO APRENDIDO, NOVA SE CALLA (como hasta hoy) --'
Reset
$script:medidas = @{}
Comp '1a. un juego nuevo no tiene plazo' ((Get-PlazoJuegoAbre 'SILENT BREATH') -eq 0) 'y sin plazo no se vigila'
Comp '1b. se apunta igual, para medir' (Add-JuegoPedido 'SILENT BREATH') ''
Comp '1c. pero sin vencimiento' ([double]$script:juegosPedidos[0].vence -eq 0) 'solo esta ahi para cronometrar'
$script:msFalsos += 300000      # cinco minutos sin que aparezca
Comp '1d. y a los cinco minutos no dice NADA' (@(Test-JuegosPedidos).Count -eq 0) 'este es el caso por el que se excluyeron los juegos'
$script:msFalsos += 400000      # pasado el tope de diez minutos
$null = Test-JuegosPedidos
Comp '1e. al llegar al tope se cae solo, en silencio' ($script:juegosPedidos.Count -eq 0) 'sin dejar basura en la lista'

Write-Host ''
Write-Host '-- 2. LO QUE TARDA SE APUNTA: asi se aprende el plazo --'
Reset
$script:medidas = @{}
$null = Add-JuegoPedido 'Little Nightmares'
$script:msFalsos += 42000       # tardo 42 s en aparecer
$script:juegoActivo = 'Little Nightmares'
$av2 = @(Test-JuegosPedidos)
Comp '2a. al verlo entrar, no hay aviso' ($av2.Count -eq 0) ''
Comp '2b. y se apunta lo que tardo' (@($script:apuntadas).Count -eq 1 -and @($script:apuntadas)[0].ms -eq 42000) ([string]@($script:apuntadas)[0].ms + ' ms')
Comp '2c. con la clave del juego' (@($script:apuntadas)[0].clave -match 'abre-juego:little nightmares') (@($script:apuntadas)[0].clave)
Comp '2d. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'tardo 42 s en aparecer' }).Count -eq 1) ''
Comp '2e. la lista queda limpia' ($script:juegosPedidos.Count -eq 0) ''

Write-Host ''
Write-Host '-- 3. CON TRES MEDIDAS YA HAY PLAZO --'
Reset
$script:medidas = @{ 'abre-juego:little nightmares' = @(40000, 45000) }
Comp '3a. con dos medidas, todavia no' ((Get-PlazoJuegoAbre 'Little Nightmares') -eq 0) '2 de 3'
$script:medidas['abre-juego:little nightmares'] = @(40000, 45000, 50000)
$pl3 = Get-PlazoJuegoAbre 'Little Nightmares'
Comp '3b. con tres, si' ($pl3 -gt 0) ([string]([int]($pl3 / 1000)) + ' s')
Comp '3c. y es el p90 con margen, no el p90 pelado' ($pl3 -eq 100000) '50 s x 2 = 100 s'
$script:medidas['abre-juego:lento'] = @(500000, 550000, 600000)
Comp '3d. con un juego lentisimo, el tope manda' ((Get-PlazoJuegoAbre 'lento') -eq $JuegoAbreTopeMs) '10 min como maximo'

Write-Host ''
Write-Host '-- 4. Y AHORA SI: EL JUEGO QUE NO ARRANCA SE DICE --'
Reset
$script:medidas = @{ 'abre-juego:silent breath' = @(30000, 35000, 40000) }
$null = Add-JuegoPedido 'SILENT BREATH'
Comp '4a. ahora si tiene vencimiento' ([double]$script:juegosPedidos[0].vence -gt 0) ''
$script:msFalsos += 50000
Comp '4b. a los 50 s todavia calla' (@(Test-JuegosPedidos).Count -eq 0) 'su plazo son 80 s'
$script:msFalsos += 40000
$av4 = @(Test-JuegosPedidos)
Comp '4c. pasado su plazo, lo dice' ($av4.Count -eq 1) (@($av4) -join ' | ')
Comp '4d. con el nombre del juego dentro' ($av4[0] -match 'SILENT BREATH') ''
Comp '4e. y se apunta como que no surtio efecto' (@($script:stats | Where-Object { $_.ruta -eq 'no-surtio-efecto' }).Count -eq 1) (@($script:stats)[0].detalle)
Comp '4f. una sola vez, no una por vuelta' (@(Test-JuegosPedidos).Count -eq 0) ''

Write-Host ''
Write-Host '-- 5. EL QUE TARDA MUCHO PERO LLEGA, NI UNA PALABRA --'
Reset
$script:medidas = @{ 'abre-juego:tarda mucho' = @(100000, 110000, 120000) }
$null = Add-JuegoPedido 'tarda mucho'
$script:msFalsos += 200000      # 200 s: por debajo de su plazo (240 s)
$script:juegoActivo = 'tarda mucho'
Comp '5a. aparece tarde pero aparece: sin aviso' (@(Test-JuegosPedidos).Count -eq 0) ''
Comp '5b. y su medida nueva entra' (@($script:apuntadas | Where-Object { $_.ms -eq 200000 }).Count -eq 1) 'asi el plazo sigue creciendo con el'

Write-Host ''
Write-Host '-- 6. SI YA ESTABA DELANTE, NO HAY NADA QUE COMPROBAR --'
Reset
$script:juegoActivo = 'Hollow Knight'
Comp '6a. pedir el juego que ya esta abierto no apunta nada' (-not (Add-JuegoPedido 'Hollow Knight')) ''
Comp '6b. y la lista sigue vacia' ($script:juegosPedidos.Count -eq 0) ''

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7a. la exclusion de juegos ya no esta' (-not ($sinCom -match 'if \(-not \$esJuego\) \{ \[void\]\(Add-AperturaPendiente')) 'era el "SOLO APPS, NO JUEGOS"'
Comp '7b. y ahora el juego va por su lista' ($sinCom -match 'if \(\$esJuego\) \{ \[void\]\(Add-JuegoPedido \$comoSeLlama\) \}') ''
Comp '7c. las apps siguen por la suya' ($sinCom -match 'else \{ \[void\]\(Add-AperturaPendiente \$comoSeLlama\) \}') 'lo de siempre no se toca'
Comp '7d. el bucle comprueba las dos' ($sinCom -match 'foreach \(\$avisoJ in \(Test-JuegosPedidos\)\)') ''
Comp '7e. y la lista de pedidos tiene tope' ($sinCom -match 'while \(\$script:juegosPedidos\.Count -gt 5\)') 'no crece sin fin'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'abrir un juego ya se comprueba, con el plazo que tarda ese juego' -ForegroundColor Green
exit 0
