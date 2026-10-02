# UNA SONDA QUE SE APAGA POR LENTA TIENE QUE ACORDARSE (2/10/2026, ideas 9 y 10)
#
# EL DATO DEL ACELEROMETRO: en el registro hay 359 lineas "acelerometro: disponible (se probara la
# primera lectura)" y solo 16 "lecturas OK". Y la linea que lo apaga -"2 lecturas seguidas lentas o
# vacias (la ultima, 5021 ms, nulo=True); desactivado para no frenar el bucle"- sale 6 veces el 30/09
# y 9 el 1/10, o sea DESPUES de que esa guarda se escribiera el 30/09: el dato no es viejo.
#
# LO QUE COSTABA: la guarda necesita DOS lecturas lentas seguidas, y cada una son 5.015 ms medidos.
# Diez segundos de bucle parado -Nova sorda- en CADA arranque. El 2/10 hubo nueve arranques: minuto
# y medio al dia gastado en volver a descubrir lo mismo.
#
# EL DE LA TEMPERATURA es el mismo caso con otra ropa: en estadisticas.json esta "auto-ajuste = sonda
# de temperatura off: 1548 ms de 400". Se apaga bien, pero eso es un CONTADOR, no un recuerdo, y la
# primera lectura puede costar 9.331 ms (medido, esta en su propio comentario). Y encima es la funcion
# que braya pidio para saber si el zumbido es su ventilador: si se queda muerta, el aviso del ruido le
# sigue mandando a buscar un ruido que es de la consola.
#
# LO QUE SE DEFIENDE AQUI:
#  1. que el recuerdo se guarde con FECHA y se lea;
#  2. que CADUQUE -una actualizacion de Windows puede arreglar el sensor, y dejarlo muerto para
#     siempre por una medicion de hace un mes es justo el fallo que este sensor ya tuvo: lo tenia
#     apagado config.json por una medicion vieja, hasta el 27/09-;
#  3. que las DOS puertas por las que se apaga el acelerometro apunten (si solo apuntara una, el
#     arranque siguiente volveria a pagar la lectura lenta por el otro lado);
#  4. y que un fichero corrupto o ausente no rompa nada.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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

# --- el mundo de mentira: una carpeta propia, que no toca la de braya ---
$tmp = Join-Path $env:TEMP ("sondas-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$MemoriaDir = $tmp
$AcelOlvidoDias = 7
$script:sondas = $null
$script:log = @()
function Log([string]$m) { $script:log += $m }
function Write-Atomico([string]$ruta, [string]$texto, [bool]$bom = $false) {
    [IO.File]::WriteAllText($ruta, $texto, (New-Object System.Text.UTF8Encoding($false)))
}
foreach ($n in @('Get-SondasPath', 'Get-Sondas', 'Save-Sonda', 'Get-SondaApagadaDias')) {
    Invoke-Expression (Traer $n)
}

try {
    Write-Host ''
    Write-Host '-- 1. sin fichero, no hay nada apagado --'
    Comp 'no inventa un apagado' ((Get-SondaApagadaDias 'acelerometro') -eq -1) ''
    Comp '  y la tabla sale vacia, no nula' ((Get-Sondas) -ne $null) ''

    Write-Host ''
    Write-Host '-- 2. se guarda con fecha y se lee --'
    $hoy = (Get-Date).ToString('yyyy-MM-dd')
    Save-Sonda 'acelerometro' $hoy
    Comp 'el fichero existe' (Test-Path -LiteralPath (Get-SondasPath)) "$(Get-SondasPath)"
    # SE RELEE DE DISCO, no de la variable: si solo valiera en memoria, el arranque siguiente -que es
    # el caso que esto viene a arreglar- no se enteraria de nada.
    $script:sondas = $null
    Comp 'y se lee del disco en frio' ((Get-SondaApagadaDias 'acelerometro') -eq 0) "dias=$(Get-SondaApagadaDias 'acelerometro')"
    Comp '  otra sonda sigue sin apagar' ((Get-SondaApagadaDias 'temperatura') -eq -1) ''

    Write-Host ''
    Write-Host '-- 3. CADUCA, que es lo que evita dejar un sensor muerto para siempre --'
    Save-Sonda 'acelerometro' ((Get-Date).AddDays(-3).ToString('yyyy-MM-dd'))
    $script:sondas = $null
    Comp 'a los 3 dias sigue apagada' ((Get-SondaApagadaDias 'acelerometro') -eq 3) ''
    Save-Sonda 'acelerometro' ((Get-Date).AddDays(-7).ToString('yyyy-MM-dd'))
    $script:sondas = $null
    Comp "a los $AcelOlvidoDias YA no" ((Get-SondaApagadaDias 'acelerometro') -eq -1) 'se vuelve a probar'
    Save-Sonda 'acelerometro' ((Get-Date).AddDays(-40).ToString('yyyy-MM-dd'))
    $script:sondas = $null
    Comp '  ni a los 40' ((Get-SondaApagadaDias 'acelerometro') -eq -1) ''
    # UNA FECHA EN EL FUTURO NO VALE: si el reloj de la consola salta, no se queda apagada eternamente
    Save-Sonda 'acelerometro' ((Get-Date).AddDays(5).ToString('yyyy-MM-dd'))
    $script:sondas = $null
    Comp 'una fecha futura no la deja apagada' ((Get-SondaApagadaDias 'acelerometro') -eq -1) 'si el reloj salta'

    Write-Host ''
    Write-Host '-- 4. las dos sondas, cada una con su recuerdo --'
    Save-Sonda 'acelerometro' $hoy
    Save-Sonda 'temperatura' $hoy
    $script:sondas = $null
    Comp 'las dos a la vez' ((Get-SondaApagadaDias 'acelerometro') -eq 0 -and (Get-SondaApagadaDias 'temperatura') -eq 0) ''
    Comp '  y guardar una no borra la otra' ((Get-Sondas).Count -eq 2) "$((Get-Sondas).Count)"

    Write-Host ''
    Write-Host '-- 5. un fichero roto no rompe nada --'
    [IO.File]::WriteAllText((Get-SondasPath), '{esto no es json', (New-Object System.Text.UTF8Encoding($false)))
    $script:sondas = $null
    Comp 'con el json roto, no se apaga nada' ((Get-SondaApagadaDias 'acelerometro') -eq -1) ''
    [IO.File]::WriteAllText((Get-SondasPath), '{"acelerometro":"manana por la tarde"}', (New-Object System.Text.UTF8Encoding($false)))
    $script:sondas = $null
    Comp 'con una fecha que no es fecha, tampoco' ((Get-SondaApagadaDias 'acelerometro') -eq -1) ''

    Write-Host ''
    Write-Host '-- 6. el cableado en el fichero de verdad --'
    $txt = [IO.File]::ReadAllText($PS1)
    $sinCom = (($txt -split "`r?`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    # EL ACELEROMETRO: las DOS puertas por las que se apaga tienen que apuntar
    $nApunta = ([regex]::Matches($sinCom, "Save-Sonda 'acelerometro'")).Count
    Comp 'el acelerometro apunta por sus DOS puertas' ($nApunta -eq 2) "$nApunta sitios"
    Comp '  y se consulta al arrancar' ($sinCom -match "Get-SondaApagadaDias 'acelerometro'") ''
    # Y LA CONSULTA VA ANTES DE ANUNCIARLO: si no, el log diria "disponible" y acto seguido lo apaga
    $iCons = $sinCom.IndexOf("Get-SondaApagadaDias 'acelerometro'")
    $iAnun = $sinCom.IndexOf('acelerometro: disponible', [Math]::Max(0, $iCons))
    Comp '  antes de decir "disponible"' ($iCons -ge 0 -and $iAnun -gt $iCons) ''
    # LA TEMPERATURA
    Comp 'la temperatura apunta cuando se apaga' ($sinCom -match "Save-Sonda 'temperatura'") ''
    Comp '  y se consulta antes de la primera lectura' ($sinCom -match "Get-SondaApagadaDias 'temperatura'") ''
    $iT = $sinCom.IndexOf("Get-SondaApagadaDias 'temperatura'")
    $iLee = $sinCom.IndexOf('Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation', [Math]::Max(0, $iT))
    Comp '  y ANTES de tocar el CIM caro' ($iT -ge 0 -and $iLee -gt $iT) "consulta en $iT, CIM en $iLee"
    # EL PLAZO SALE DE UNA CONSTANTE CON NOMBRE, no de un numero suelto
    Comp 'el plazo tiene nombre' ($sinCom -match '\$AcelOlvidoDias\s*=\s*\d+') ''

    Write-Host ''
    if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
    Write-Host 'las sondas que se apagan por lentas se acuerdan, y el recuerdo caduca' -ForegroundColor Green
    exit 0
}
finally {
    # SIEMPRE, aunque algo reviente: si no, cada pasada deja una carpeta en TEMP (ver la manera 13)
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
