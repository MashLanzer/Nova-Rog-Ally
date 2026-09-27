# LOS PUERTOS DE MANDO QUE NO EXISTEN (27/09, idea 66 de las 121)
#
# EL DATO, medido en esta Ally con la clase AX del proyecto y 300 llamadas por puerto: puerto 0
# (el mando de la consola, ret=0) 0,1534 ms por llamada; puertos 1, 2 y 3, todos con 1167 (no
# conectado), 0,3592 / 0,3876 / 0,3944 ms. De los 1,2946 ms de una vuelta, 1,1412 se van en
# puertos que nunca han tenido nada: el 88,2 %. El bucle duerme 30 ms, o sea 33 vueltas por
# segundo: 42,7 ms de CPU por segundo, de los que 37,7 se tiraban.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el puerto 0 NUNCA se aplace (es el que dispara el gatillo)
#   2. que un puerto que nunca contesto se salte... y que en el repaso SI entre
#   3. que el plazo suba solo hasta el tope y vuelva al minimo al aparecer un mando
#   4. que un mando que se desenchufa vuelva a la cola de los aplazados
#   5. que el ahorro sea de verdad, midiendo las dos formas de sondear
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
foreach ($f in @('Test-SondearPuerto', 'Get-RescanMandoMs')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$RescanMandoMin = 1000
$RescanMandoTope = 4000
# los dos numeros, sacados del archivo: si alli cambian y aqui no, el banco lo dice
Comp 'el minimo del archivo es 1000 ms' ($txt -match '\$RescanMandoMin\s*=\s*1000') ''
Comp 'y el tope, 4000 ms' ($txt -match '\$RescanMandoTope\s*=\s*4000') ''

Write-Host ''
Write-Host '-- 1. el puerto 0 nunca se aplaza --'
$script:puertoVisto = @{}
Comp '1a. sin haber visto nada, el 0 SI se pregunta' (Test-SondearPuerto 0 $false 100000) 'es el mando de la consola'
Comp '1b. y los otros tres no' ((-not (Test-SondearPuerto 1 $false 100000)) -and (-not (Test-SondearPuerto 2 $false 100000)) -and (-not (Test-SondearPuerto 3 $false 100000))) ''

Write-Host ''
Write-Host '-- 2. en el repaso entran todos --'
Comp '2a. con repaso, el 3 tambien se pregunta' (Test-SondearPuerto 3 $true 100000) 'asi aparece un mando nuevo'

Write-Host ''
Write-Host '-- 3. un puerto que ya contesto se pregunta siempre, hasta que deje de hacerlo --'
$script:puertoVisto = @{ 1 = 100000 }
Comp '3a. recien visto: se pregunta sin repaso' (Test-SondearPuerto 1 $false 100030) ''
Comp '3b. dentro del tope: se sigue preguntando' (Test-SondearPuerto 1 $false (100000 + $RescanMandoTope)) 'justo en el limite'
Comp '3c. pasado el tope sin contestar: a la cola de los aplazados' (-not (Test-SondearPuerto 1 $false (100001 + $RescanMandoTope))) 'un mando desenchufado no se paga para siempre'

Write-Host ''
Write-Host '-- 4. el plazo lo mueve lo que encuentra, no un numero escrito --'
$p = $RescanMandoMin
$p1 = Get-RescanMandoMs $false $p;  $p2 = Get-RescanMandoMs $false $p1
$p3 = Get-RescanMandoMs $false $p2; $p4 = Get-RescanMandoMs $false $p3
Comp '4a. tres repasos vacios: 1000 -> 2000 -> 4000' (($p1 -eq 2000) -and ($p2 -eq 4000)) "$p1, $p2"
Comp '4b. y ahi se queda: no pasa del tope' (($p3 -eq 4000) -and ($p4 -eq 4000)) "$p3, $p4"
Comp '4c. al aparecer un mando, vuelve al minimo' ((Get-RescanMandoMs $true 4000) -eq 1000) 'enchufar otro se nota enseguida'

Write-Host ''
Write-Host '-- 5. el cableado en el bucle (sobre el fuente) --'
Comp '5a. el for pregunta por Test-SondearPuerto' ($txt -match 'if \(-not \(Test-SondearPuerto \$u \$repasaMando') ''
Comp '5b. el puerto que contesta se apunta con la hora' ($txt -match '\$script:puertoVisto\[\$u\] = \$sw\.ElapsedMilliseconds') ''
Comp '5c. y un puerto nuevo se dice en el registro' ($txt -match 'mando: aparecio uno en el puerto') ''
Comp '5d. el gatillo no se gasta el repaso' ($txt -match '\$repasaMando -and -not \$saltarPoll -and -not \$startNow') 'si corta el for, el repaso no cuenta'

Write-Host ''
Write-Host '-- 6. Y EL AHORRO, MEDIDO AQUI MISMO --'
$medido = $false
try {
    Add-Type -Path (Join-Path $Raiz 'assistant-dx.cs') -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing', 'System.Data' -ErrorAction Stop
    $medido = $true
} catch {
    # ya cargada en esta sesion, o no se puede compilar: se intenta usar igual
    $medido = [bool]([Type]::GetType('AX', $false))
}
if (-not $medido) {
    Write-Host '  --   no se pudo cargar AX en esta sesion; el ahorro no se mide (el resto si)'
} else {
    $porPuerto = @{}
    foreach ($u in 0..3) {
        $st = New-Object AX+XINPUT_STATE
        $r = [AX]::XInputGetState([uint32]$u, [ref]$st)
        $cron = [Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt 200; $i++) { $st = New-Object AX+XINPUT_STATE; $r = [AX]::XInputGetState([uint32]$u, [ref]$st) }
        $cron.Stop()
        $porPuerto[$u] = @{ ret = $r; ms = ($cron.Elapsed.TotalMilliseconds / 200) }
    }
    $vuelta = 0.0; $vacios = 0.0
    foreach ($u in 0..3) { $vuelta += $porPuerto[$u].ms; if ($porPuerto[$u].ret -ne 0) { $vacios += $porPuerto[$u].ms } }
    Write-Host ('       vuelta entera ' + [Math]::Round($vuelta, 4) + ' ms; en puertos vacios ' + [Math]::Round($vacios, 4) + ' ms (' + [Math]::Round(100 * $vacios / $vuelta, 1) + ' %)')
    Comp '6a. los puertos vacios se llevan mas de la mitad de la vuelta' (($vacios / $vuelta) -gt 0.5) ([string][Math]::Round(100 * $vacios / $vuelta, 1) + ' %')
    # y la vuelta "aplazada" (solo los puertos vivos) tiene que costar bastante menos
    $vivos = @(0..3 | Where-Object { $porPuerto[$_].ret -eq 0 })
    $cron2 = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt 200; $i++) { foreach ($u in $vivos) { $st = New-Object AX+XINPUT_STATE; $r = [AX]::XInputGetState([uint32]$u, [ref]$st) } }
    $cron2.Stop()
    $nueva = $cron2.Elapsed.TotalMilliseconds / 200
    Write-Host ('       sondeando solo los ' + $vivos.Count + ' puerto(s) vivo(s): ' + [Math]::Round($nueva, 4) + ' ms por vuelta')
    Comp '6b. la vuelta aplazada cuesta menos de la mitad' ($nueva -lt ($vuelta / 2)) ([string][Math]::Round($nueva, 4) + ' vs ' + [string][Math]::Round($vuelta, 4) + ' ms')
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'los puertos vacios ya no se preguntan en cada vuelta' -ForegroundColor Green
exit 0
