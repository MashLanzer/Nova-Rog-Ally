# DIEZ RELOJES DE 'UNA VEZ CADA TANTO' NACIAN DICIENDO 'YA PUEDES' (27/09, idea 82 de las 121)
#
# EL PROBLEMA: las esperas se miden contra $sw, el cronometro del proceso, que empieza en cero. Diez
# variables de sesion arrancan en un negativo de cuatro cifras o mas -que significa "hace muchisimo
# que no pasa"- y Nova arranca 15,2 veces al dia: una guarda de "no repitas esto en diez minutos"
# podia dispararse quince veces en un dia. Uno ya se habia arreglado a mano (calladoDia, 24/09).
#
# LO QUE ESTE BANCO PROTEGE, y el segundo es el que importa:
#   1. que la hora guardada se traduzca bien a milisegundos del cronometro nuevo
#   2. que los relojes de 'ESTOY CALLADA' NO se restauren nunca: si braya reinicia a proposito para
#      que Nova deje de estar callada, devolverle la sordina es lo contrario de lo que pidio
#   3. que un reloj del futuro o viejisimo se tire en vez de creerselo
#   4. que escribir no cueste una escritura por vuelta
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
foreach ($f in @('Get-RelojesDisco', 'Get-Reloj', 'Set-Reloj')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$RelojesViejoMs = 604800000
$RelojesBlanca = @('charla', 'precarga', 'invitado-propuesto', 'aviso-suelta')
Comp 'la lista blanca son cuatro relojes de "no repitas"' ($txt -match "RelojesBlanca = @\('charla', 'precarga', 'invitado-propuesto', 'aviso-suelta'\)") ''
Comp 'y la semana es el limite de lo creible' ($txt -match '\$RelojesViejoMs = 604800000') ''

$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-rel-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$RelojesJson = Join-Path $TmpDir 'relojes.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$ruta, [string]$contenido) { [IO.File]::WriteAllText($ruta, $contenido, $UTF8) }
$script:msFalsos = 5000          # un proceso que acaba de arrancar
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:relojes = $null
    $script:relojesEscritoEn = @{}
    $script:msFalsos = 5000
    if (Test-Path -LiteralPath $RelojesJson) { Remove-Item -LiteralPath $RelojesJson -Force }
}
function Guardar([hashtable]$h) {
    $o = [ordered]@{}
    foreach ($k in ($h.Keys | Sort-Object)) { $o[$k] = [string]$h[$k] }
    Write-Atomico $RelojesJson (ConvertTo-Json $o -Compress)
    $script:relojes = $null
}

try {
    Write-Host ''
    Write-Host '-- 1. SIN FICHERO, EL VALOR DE SIEMPRE --'
    Reset
    Comp '1a. sin nada guardado, el negativo de siempre' ((Get-Reloj 'charla' -600000) -eq -600000) 'nada cambia hasta que hay dato'

    Write-Host ''
    Write-Host '-- 2. EL CASO DE VERDAD: hablo hace dos minutos y Nova se reinicio --'
    Reset
    Guardar @{ 'charla' = (Get-Date).AddMinutes(-2).ToString('yyyy-MM-dd HH:mm:ss') }
    $v2 = Get-Reloj 'charla' -600000
    # el cronometro va por 5 s; hace 2 min son 120.000 ms, asi que el valor es 5000 - 120000
    Comp '2a. el reloj queda en -115.000 y no en -600.000' ($v2 -lt -110000 -and $v2 -gt -120000) ([string][int]$v2 + ' ms')
    # y eso es lo que importa: una guarda de "no repitas en 10 min" ya no se dispara
    Comp '2b. con guarda de 10 min, NO toca repetir' (($script:msFalsos - $v2) -lt 600000) ([string][int](($script:msFalsos - $v2) / 1000))
    Reset
    Guardar @{ 'charla' = (Get-Date).AddMinutes(-20).ToString('yyyy-MM-dd HH:mm:ss') }
    $v2b = Get-Reloj 'charla' -600000
    Comp '2c. pero si hablo hace 20 min, si toca' (($script:msFalsos - $v2b) -gt 600000) ([string][int](($script:msFalsos - $v2b) / 60000) + ' min')

    Write-Host ''
    Write-Host '-- 3. LO QUE NO ESTA EN LA LISTA NO SE RESTAURA --'
    Reset
    Guardar @{ 'sordina' = (Get-Date).AddMinutes(-1).ToString('yyyy-MM-dd HH:mm:ss')
               'charla' = (Get-Date).AddMinutes(-1).ToString('yyyy-MM-dd HH:mm:ss') }
    Comp '3a. la sordina NO vuelve' ((Get-Reloj 'sordina' -999999) -eq -999999) 'si braya reinicio para que hable, hablar es lo correcto'
    Comp '3b. pero la charla si' ((Get-Reloj 'charla' -600000) -ne -600000) ''
    Comp '3c. y Set-Reloj tampoco guarda lo que no esta en la lista' (-not (Set-Reloj 'sordina')) ''

    Write-Host ''
    Write-Host '-- 4. UN RELOJ IMPOSIBLE SE TIRA --'
    Reset
    Guardar @{ 'charla' = (Get-Date).AddHours(2).ToString('yyyy-MM-dd HH:mm:ss') }
    Comp '4a. del futuro (cambio de hora): se tira' ((Get-Reloj 'charla' -600000) -eq -600000) 'un reloj del futuro es un reloj roto'
    Reset
    Guardar @{ 'charla' = (Get-Date).AddDays(-9).ToString('yyyy-MM-dd HH:mm:ss') }
    Comp '4b. de hace nueve dias: se tira' ((Get-Reloj 'charla' -600000) -eq -600000) 'mas de una semana no dice nada'
    Reset
    Guardar @{ 'charla' = 'ayer por la tarde' }
    Comp '4c. ilegible: se tira' ((Get-Reloj 'charla' -600000) -eq -600000) ''
    Reset
    [IO.File]::WriteAllText($RelojesJson, 'esto no es json', $UTF8)
    Comp '4d. fichero roto: el valor de siempre' ((Get-Reloj 'charla' -600000) -eq -600000) ''

    Write-Host ''
    Write-Host '-- 5. ESCRIBIR NO CUESTA UNA VEZ POR VUELTA --'
    Reset
    Comp '5a. la primera escritura pasa' (Set-Reloj 'charla') ''
    Comp '5b. la segunda seguida, no' (-not (Set-Reloj 'charla')) 'el freno de un minuto'
    $script:msFalsos += 61000
    Comp '5c. pasado el minuto, si' (Set-Reloj 'charla') ''
    Comp '5d. y el fichero existe' (Test-Path -LiteralPath $RelojesJson) ''
    $leido = Get-Content -LiteralPath $RelojesJson -Raw | ConvertFrom-Json
    Comp '5e. con la clave dentro' ([bool]$leido.charla) ([string]$leido.charla)
    # y las claves de otros relojes no se pisan
    $script:relojes = $null
    $script:msFalsos += 61000
    $null = Set-Reloj 'precarga'
    $leido2 = Get-Content -LiteralPath $RelojesJson -Raw | ConvertFrom-Json
    Comp '5f. y guardar otra no borra la primera' (([bool]$leido2.charla) -and ([bool]$leido2.precarga)) 'charla y precarga'

    Write-Host ''
    Write-Host '-- 6. EL CABLEADO --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp '6a. la charla lee su reloj al arrancar' ($sinCom -match "\`$script:charlaUltima = Get-Reloj 'charla' -600000") ''
    Comp '6b. y lo guarda al hablar' ($sinCom -match "\[void\]\(Set-Reloj 'charla'\)") ''
    Comp '6c. la precarga, igual' (($sinCom -match "Get-Reloj 'precarga'") -and ($sinCom -match "Set-Reloj 'precarga'")) ''
    Comp '6d. la propuesta de invitado, igual' (($sinCom -match "Get-Reloj 'invitado-propuesto'") -and ($sinCom -match "Set-Reloj 'invitado-propuesto'")) ''
    Comp '6e. el aviso de suelta, igual' (($sinCom -match "Get-Reloj 'aviso-suelta'") -and ($sinCom -match "Set-Reloj 'aviso-suelta'")) ''
    Comp '6f. y al salir se guarda el ultimo minuto' ($sinCom -match "(?s)Save-TiempoJuego.{0,600}relojesEscritoEn = @\{\}.{0,200}Set-Reloj 'charla'") 'el freno se salta ahi a proposito'
    # LO QUE NO DEBE ESTAR: ningun reloj de callarse
    foreach ($prohibido in @('sordina', 'pausa', 'callado')) {
        Comp ('6g. ' + $prohibido + ' NO esta en la lista blanca') (-not ($sinCom -match ("RelojesBlanca = @\([^\)]*" + $prohibido))) 'los de "estoy callada" se quedan fuera'
    }
    Comp '6h. el clima tampoco: ya tiene el suyo (idea 6)' (-not ($sinCom -match "RelojesBlanca = @\([^\)]*clima")) 'Restore-Clima restaura su antiguedad'
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'los relojes de no-repitas sobreviven al reinicio, y los de callarse no' -ForegroundColor Green
exit 0
