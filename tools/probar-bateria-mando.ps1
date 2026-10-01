# LA BATERIA DEL MANDO (30/09, la 6 de las 20 funciones nuevas)
#
# MEDIDO ANTES DE PROMETERLO, y el resultado cambio la funcion: el mando INTEGRADO de esta Ally
# contesta BatteryType=0 (desconectado) y BatteryLevel=0. No reporta bateria porque no la tiene, es
# parte de la consola. Decir "el mando esta al 0 %" seria mentir con un dato de verdad.
# Asi que hay DOS caminos y los dos se prueban: mando externo con bateria (se dice el nivel y se
# avisa si esta bajo) y mando integrado (se dice que su bateria es la de la consola).
#
# XInput NO DA PORCENTAJE: son cuatro escalones (vacia, baja, media, llena) y se dicen como
# escalones. Inventar un porcentaje a partir de cuatro valores seria precision de mentira.
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
$MandoBatNiveles = @{ 0 = 'vacia'; 1 = 'baja'; 2 = 'media'; 3 = 'llena' }
foreach ($n in @('Get-FraseBateriaMando', 'Watch-BateriaMando')) { Invoke-Expression (Traer $n) }
$script:dichos = @()
function Log([string]$m) { $script:dichos += $m }
$script:avisos = @()
function Send-AvisoEntorno { param($c, $t, $n, $cada, $forzar) $script:avisos += ($c + '|' + $t); return $true }

# EL MANDO DE PEGA: se dobla Get-BateriaMando y no XInput, porque lo que hay que probar son las
# frases y el aviso, no si el P/Invoke funciona -eso se midio a mano y esta en el .cs-.
$script:mandoFalso = $null
function Get-BateriaMando { return $script:mandoFalso }

Write-Host ''
Write-Host '-- 1. el mando integrado de esta consola (tipo 0, nivel 0) --'
$script:mandoFalso = @{ puerto = 0; tipo = 0; nivel = 0; propia = $false }
$f1 = Get-FraseBateriaMando
Comp 'dice que no tiene bateria propia' ($f1 -match 'no tiene bateria propia') "$f1"
Comp '  y NO dice que este vacia ni al 0' (($f1 -notmatch 'vacia') -and ($f1 -notmatch '0 %')) 'seria mentir con un dato de verdad'
Comp '  y manda a la pregunta que si tiene respuesta' ($f1 -match 'cuanto dura la bateria') ''

Write-Host ''
Write-Host '-- 2. un mando externo, con sus cuatro escalones --'
foreach ($par in @(@(3, 'llena'), @(2, 'media'), @(1, 'baja'), @(0, 'vacia'))) {
    $script:mandoFalso = @{ puerto = 0; tipo = 3; nivel = $par[0]; propia = $true }
    $f = Get-FraseBateriaMando
    Comp ('nivel ' + $par[0] + ' se dice "' + $par[1] + '"') ($f -match [regex]::Escape($par[1])) "$f"
}
# Y CON PILAS SE DICE QUE SON PILAS: no es lo mismo buscar un cable que buscar pilas.
$script:mandoFalso = @{ puerto = 0; tipo = 2; nivel = 1; propia = $true }
Comp 'con pilas, lo dice' ((Get-FraseBateriaMando) -match 'pilas') ''
# Y SOLO AVISA DE PREPARAR ALGO CUANDO ESTA BAJA
$script:mandoFalso = @{ poner = 1; puerto = 0; tipo = 3; nivel = 3; propia = $true }
Comp 'con la bateria llena no manda buscar cable' ((Get-FraseBateriaMando) -notmatch 'cable') ''

Write-Host ''
Write-Host '-- 3. sin mando conectado --'
$script:mandoFalso = $null
Comp 'lo dice y no inventa nada' ((Get-FraseBateriaMando) -match 'No veo ningun mando') ''

Write-Host ''
Write-Host '-- 4. el aviso: una vez por nivel, y nunca con el integrado --'
$script:avisos = @()
$script:mandoBatAvisado = -1
$script:mandoFalso = @{ puerto = 0; tipo = 3; nivel = 1; propia = $true }
Watch-BateriaMando
Comp 'avisa cuando la bateria esta baja' ($script:avisos.Count -eq 1) "$($script:avisos.Count) aviso(s)"
# Y NO UNA VEZ POR MINUTO HASTA QUE LO CARGUE: sin esto seria un aviso cada vuelta del minuto.
Watch-BateriaMando; Watch-BateriaMando
Comp '  y no repite mientras siga igual' ($script:avisos.Count -eq 1) "$($script:avisos.Count) tras tres rondas"
# AL CARGARLO SE REARMA, que si no la segunda vez que se gaste no avisaria
$script:mandoFalso = @{ puerto = 0; tipo = 3; nivel = 3; propia = $true }
Watch-BateriaMando
$script:mandoFalso = @{ puerto = 0; tipo = 3; nivel = 1; propia = $true }
Watch-BateriaMando
Comp '  pero tras cargarlo vuelve a avisar' ($script:avisos.Count -eq 2) "$($script:avisos.Count)"
# CON EL INTEGRADO NO AVISA NUNCA: no tiene bateria que se gaste.
$script:avisos = @()
$script:mandoBatAvisado = -1
$script:mandoFalso = @{ puerto = 0; tipo = 0; nivel = 0; propia = $false }
Watch-BateriaMando
Comp 'con el mando integrado no avisa nunca' ($script:avisos.Count -eq 0) 'su bateria es la de la consola'

Write-Host ''
Write-Host '-- 5. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca bateriaMando' ($sinCom -match "kind = 'bateriaMando'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'bateriaMando' \{") ''
Comp '  y la ronda del minuto lo vigila' ($sinCom -match 'Watch-BateriaMando') ''
# LA PREGUNTA DE LA CONSOLA NO SE PISA, Y LA DEL MANDO NO SE LA COME ELLA: el patron viejo de
# "cuanta bateria" lleva una guarda para dejar pasar las que nombran el mando.
Comp 'el patron viejo deja pasar las del mando' ($sinCom -match '\(\?\!\.\*\\b\(\?\:mando\|control\|gamepad\)\\b\)') 'si no, contesta la de la consola'
# Y EL P/INVOKE ESTA DECLARADO EN EL .cs, que es de donde sale el dato
$cs = [IO.File]::ReadAllText((Join-Path $Raiz 'assistant-dx.cs'))
Comp 'XInputGetBatteryInformation esta en el .cs' ($cs -match 'XInputGetBatteryInformation') ''
Comp '  y su struct tambien' ($cs -match 'XINPUT_BATTERY_INFORMATION') ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova dice la bateria del mando, y dice la verdad con el mando integrado' -ForegroundColor Green
exit 0
