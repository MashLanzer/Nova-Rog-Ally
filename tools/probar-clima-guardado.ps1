# EL TIEMPO NO SE VUELVE A PEDIR EN CADA ARRANQUE (26/09, idea 6 de las 121).
#
# El clima se guardaba una hora... pero solo dentro del proceso. Cada arranque nacia con
# $script:clima vacio y $script:climaCheck en -3600000 -o sea, "hace una hora"-, asi que a los
# veinte segundos de vivir Nova salia a internet otra vez aunque el dato de hace cuatro minutos
# siguiera siendo bueno. Y Nova arranca MUCHO.
#
# MEDIDO sobre assistant.log y assistant.log.1: 258 arranques y 504 consultas de clima, de las
# cuales 334 -el 66 %- caen en los TRES MINUTOS siguientes a un arranque. Dos de cada tres
# viajes a internet eran el dato que ya se sabia.
#
# LA VENTANA NO SE ALARGA: sigue siendo la misma hora que ya habia. Lo unico que cambia es que
# ahora sobrevive al reinicio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. se guarda y se recupera --'
foreach ($n in @('Save-Clima', 'Restore-Clima')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    Comp "existe $n" ($null -ne $d) ''
    if ($d) { Invoke-Expression $d.Extent.Text }
}
foreach ($l in @('Save-Clima', 'Restore-Clima')) {
    $n = @([regex]::Matches($sinCom, ('(?<!function )' + $l))).Count
    Comp "  y alguien llama a $l" ($n -ge 1) "$n llamada(s)"
}
$m = [regex]::Match($txt, '(?m)^\$ClimaFrescoMs\s*=\s*(.+)$')
Comp 'se saca del archivo ClimaFrescoMs' $m.Success ''
if ($m.Success) { Invoke-Expression ('$ClimaFrescoMs = ' + $m.Groups[1].Value.Trim()) }
# LA VENTANA NO SE ALARGA: es la hora que ya habia. Alargarla seria decir un tiempo viejo.
Comp '  y es la misma hora que ya habia' ($ClimaFrescoMs -eq 3600000) "$([int]($ClimaFrescoMs/60000)) minutos"

Write-Host ''
Write-Host '-- 2. y funciona de verdad, sobre un disco de mentira --'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-clima-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$MemoriaDir = $tmp
$sw = [System.Diagnostics.Stopwatch]::StartNew()
function Log([string]$m) { }
function Write-Atomico([string]$ruta, [string]$contenido) {
    [IO.File]::WriteAllText($ruta, $contenido, (New-Object Text.UTF8Encoding($false)))
}
try {
    $script:clima = @{ emoji = 'S'; desc = 'esta despejado'; temp = 21 }
    $script:uiTiempo = 'sol'
    Comp 'guarda lo que sabe' ([bool](Save-Clima 0)) ''
    Comp '  y deja el fichero' (Test-Path -LiteralPath (Join-Path $tmp 'clima.json')) ''
    # AHORA SE OLVIDA, como en un arranque nuevo
    $script:clima = $null
    $script:uiTiempo = ''
    $script:climaCheck = -3600000
    $min = Restore-Clima
    Comp 'lo recupera tras el reinicio' ($min -ge 0) "$min minutos de antiguedad"
    Comp '  con la temperatura buena' ($script:clima -and [int]$script:clima.temp -eq 21) ''
    Comp '  y la cara del tiempo' ($script:uiTiempo -eq 'sol') 'la gota o el copo de la capsula'
    # Y EL RELOJ: la proxima consulta tiene que caer cuando le tocaba, no una hora mas tarde.
    # EL RELOJ, CONTRA UN NUMERO CONCRETO Y NO CONTRA "algo mayor que el inicial" (26/09, lo
    # cazo una rotura). Comprobar solo "climaCheck > -3600000" pasaba igual si alguien ponia
    # climaCheck = ahora a secas, que es el fallo que se viene a evitar: la proxima consulta
    # caeria una hora DESPUES de cuando le tocaba. Con un fichero de antiguedad conocida se
    # puede exigir el valor de verdad.
    $script:clima = $null
    $medioViejo = [ordered]@{ emoji = 'S'; desc = 'despejado'; temp = 21; codigo = 0; ui = 'sol'
                              cuando = (Get-Date).AddMinutes(-30).ToString('o') }
    Write-Atomico (Join-Path $tmp 'clima.json') (ConvertTo-Json -InputObject $medioViejo -Depth 3)
    $antesCheck = $sw.ElapsedMilliseconds
    $min30 = Restore-Clima
    Comp '  dice bien la antiguedad' ($min30 -ge 29 -and $min30 -le 31) "$min30 minutos, y el fichero es de hace 30"
    $desc = $antesCheck - $script:climaCheck
    Comp '  y el reloj descuenta lo que ya envejecio' ($desc -ge 1700000 -and $desc -le 1900000) "descuenta $([int]($desc/60000)) min; sin esto la proxima consulta llegaria una hora tarde"

    # RANCIO: mas viejo que la ventana, se ignora y se pregunta
    $viejo = [ordered]@{ emoji = 'L'; desc = 'llueve'; temp = 5; codigo = 61; ui = 'lluvia'
                         cuando = (Get-Date).AddMilliseconds(-1 * ($ClimaFrescoMs + 60000)).ToString('o') }
    Write-Atomico (Join-Path $tmp 'clima.json') (ConvertTo-Json -InputObject $viejo -Depth 3)
    $script:clima = $null
    Comp 'un tiempo rancio NO se usa' ((Restore-Clima) -lt 0) 'mas viejo que la ventana'
    Comp '  y no deja nada puesto' ($null -eq $script:clima) 'mejor sin tiempo que con uno de hace tres horas'
    # EL BORDE, que es lo unico que separa una hora de diez: justo dentro y justo fuera.
    $justo = [ordered]@{ emoji = 'N'; desc = 'nublado'; temp = 9; codigo = 3; ui = ''
                         cuando = (Get-Date).AddMilliseconds(-1 * ($ClimaFrescoMs - 60000)).ToString('o') }
    Write-Atomico (Join-Path $tmp 'clima.json') (ConvertTo-Json -InputObject $justo -Depth 3)
    $script:clima = $null
    Comp '  un minuto antes del tope, SI' ((Restore-Clima) -ge 0) ''
    # DEL FUTURO: un reloj movido hacia atras dejaria un fichero eternamente "fresco"
    $futuro = [ordered]@{ emoji = 'X'; desc = 'raro'; temp = 99; codigo = 0; ui = ''
                          cuando = (Get-Date).AddHours(3).ToString('o') }
    Write-Atomico (Join-Path $tmp 'clima.json') (ConvertTo-Json -InputObject $futuro -Depth 3)
    $script:clima = $null
    # SE MIRA SI CARGO ALGO, NO EL NUMERO QUE DEVUELVE (26/09, lo cazo una rotura). Un fichero
    # del futuro da una antiguedad NEGATIVA, asi que "lo que devuelve es menor que cero" se
    # cumplia... cargando el clima igualmente. La prueba pasaba por la razon equivocada.
    [void](Restore-Clima)
    Comp 'un tiempo del FUTURO tampoco' ($null -eq $script:clima) 'un reloj movido atras lo dejaria fresco para siempre'
    # BASURA: un fichero a medio escribir no puede reventar el arranque
    [IO.File]::WriteAllText((Join-Path $tmp 'clima.json'), '{ esto no es json', (New-Object Text.UTF8Encoding($false)))
    $script:clima = $null
    [void](Restore-Clima)
    Comp 'con el fichero roto, ni revienta ni inventa' ($null -eq $script:clima) ''
    Remove-Item -LiteralPath (Join-Path $tmp 'clima.json') -Force
    Comp 'y sin fichero, tampoco' ((Restore-Clima) -lt 0) 'la primera vez no hay nada que recuperar'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 3. contra el registro de verdad --'
# CUANTOS VIAJES A INTERNET SE AHORRAN. Si saliera cero, esto no serviria para nada.
$arr = @(); $cli = @()
foreach ($f in @('assistant.log.1', 'assistant.log')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(.*)$') {
            $t = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
            if ($Matches[2] -match 'VoiceAssistant iniciado') { $arr += $t }
            elseif ($Matches[2] -match '^clima:') { $cli += $t }
        }
    }
}
if ($cli.Count -gt 0) {
    $arr = @($arr | Sort-Object)
    $cerca = 0
    foreach ($c in $cli) {
        $ult = $null
        foreach ($a in $arr) { if ($a -le $c) { $ult = $a } else { break } }
        if ($ult -and ($c - $ult).TotalSeconds -le 180) { $cerca++ }
    }
    $pct = [int](100.0 * $cerca / $cli.Count)
    Write-Host ("       $($arr.Count) arranques, $($cli.Count) consultas de clima, $cerca en los 3 min siguientes a un arranque ($pct %)")
    Comp 'hay viajes que ahorrar' ($cerca -ge 50) 'si fuera cero, esto no serviria'
} else {
    Write-Host '       (no hay registro con el que medir)'
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el tiempo de hace un rato sobrevive al reinicio'
exit 0
