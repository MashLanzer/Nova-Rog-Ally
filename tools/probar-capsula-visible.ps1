# QUE LA CAPSULA DIGA SI SE LA VE (27/09, idea 67 de las 121)
#
# EL DATO: 'CAPSULA CIEGA' sale CERO veces en las 58.636 lineas de los dos registros, y en esos
# mismos dias braya jugo 19,9 horas (memoria\juegos.json, 9 dias). La cuenta que decidia -comparar
# la resolucion nativa con la actual- nunca dio 'no se ve', porque los juegos de hoy usan pantalla
# completa SIN cambiar de resolucion. Por eso los cinco avisos 'SIN VOZ' del registro salieron sin
# la coletilla ', vibrado': Send-AvisoVibrado no disparo ni una vez.
#
# AHORA lo dice quien lo sabe: nova_ui.cs escribe en tmp\ui-visible.txt '1|0 <hora> <cadencia ms>'
# cada 5 s. Y esa hora vale de latido: hasta hoy el cerebro solo se enteraba de que la capsula
# MURIO, no de que se colgo viva con su ventana pintada.
#
# LO QUE ESTE BANCO PROTEGE, por orden de miedo:
#   1. ANTE LA DUDA, SE VE. Sin fichero, vacio, ilegible o viejo -> visible. Dar por ciega una
#      capsula que si se ve hace a Nova hablar encima de la partida, que es peor que el fallo.
#   2. que 'viejo' NO sea un numero a mano: sale de la cadencia que la capsula declara.
#   3. que sin juego delante nunca se diga ciega.
#   4. que la capsula de verdad escriba el fichero (se arranca el exe y se mira).
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
foreach ($f in @('Get-UiVisible', 'Test-CapsulaCiega')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$cs = [IO.File]::ReadAllText((Join-Path $Raiz 'nova_ui.cs'))

$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-vis-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$ruta = Join-Path $TmpDir 'ui-visible.txt'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Latido([string]$ve, [datetime]$cuando, [int]$cada) {
    [IO.File]::WriteAllText($ruta, $ve + ' ' + $cuando.ToString('yyyy-MM-dd HH:mm:ss') + ' ' + [string]$cada + "`r`n", $UTF8)
}

try {
    Write-Host '-- 1. ANTE LA DUDA, SE VE --'
    $script:juegoActivo = 'Hollow Knight'
    if (Test-Path $ruta) { Remove-Item $ruta -Force }
    Comp '1a. sin fichero, no lee nada' ($null -eq (Get-UiVisible)) ''
    Comp '1b. y no se da por ciega' (-not (Test-CapsulaCiega)) 'es el caso del primer arranque'
    [IO.File]::WriteAllText($ruta, '', $UTF8)
    Comp '1c. fichero vacio: tampoco' (-not (Test-CapsulaCiega)) ''
    [IO.File]::WriteAllText($ruta, "no soy un latido`r`n", $UTF8)
    Comp '1d. fichero con basura: tampoco' (-not (Test-CapsulaCiega)) 'nada de adivinar'
    Latido '0' (Get-Date).AddMinutes(-5) 5000
    Comp '1e. latido VIEJO diciendo 0: se supone visible' (-not (Test-CapsulaCiega)) 'una capsula muerta no deja a Nova muda'

    Write-Host ''
    Write-Host '-- 2. y cuando SI lo dice, se le cree --'
    Latido '0' (Get-Date) 5000
    Comp '2a. latido fresco con 0: ciega' (Test-CapsulaCiega) 'esto es lo que no pasaba nunca'
    Latido '1' (Get-Date) 5000
    Comp '2b. latido fresco con 1: se ve' (-not (Test-CapsulaCiega)) ''

    Write-Host ''
    Write-Host '-- 3. sin juego delante, nunca ciega --'
    $script:juegoActivo = $null
    Latido '0' (Get-Date) 5000
    Comp '3a. con un 0 fresco pero sin juego: no ciega' (-not (Test-CapsulaCiega)) 'el aviso se ve igual en el escritorio'
    $script:juegoActivo = 'Hollow Knight'

    Write-Host ''
    Write-Host '-- 4. "viejo" sale de la cadencia que declara la capsula, no de un numero --'
    # con cadencia 5 s, un latido de hace 12 s es fresco (12 < 3x5) y uno de hace 20 s es viejo
    Latido '0' (Get-Date).AddSeconds(-12) 5000
    Comp '4a. cadencia 5 s, hace 12 s: todavia vale' (Test-CapsulaCiega) '12 < 3 x 5'
    Latido '0' (Get-Date).AddSeconds(-20) 5000
    Comp '4b. cadencia 5 s, hace 20 s: viejo' (-not (Test-CapsulaCiega)) '20 > 3 x 5'
    # y con una cadencia LENTA (la capsula va apretada), el mismo hace-20-s sigue valiendo
    Latido '0' (Get-Date).AddSeconds(-20) 15000
    Comp '4c. cadencia 15 s, hace 20 s: vale (el plazo se estira con ella)' (Test-CapsulaCiega) 'un numero fijo se lo habria comido'
    # la primera linea de cada arranque trae cada=0: se usa la cadencia declarada del reloj
    Latido '0' (Get-Date) 0
    $v0 = Get-UiVisible
    Comp '4d. con cadencia 0 (primer latido) se toma la declarada de 5 s' ($v0 -and $v0.cada -eq 5000) ([string]$v0.cada)

    Write-Host ''
    Write-Host '-- 5. el cableado (sobre los dos fuentes) --'
    Comp '5a. Test-CapsulaCiega ya NO compara resoluciones' (-not ((Traer 'Test-CapsulaCiega') -match 'Get-ResolucionNativa')) 'esa cuenta no dio "no se ve" ni una vez'
    Comp '5b. la capsula escribe ui-visible.txt' ($cs -match 'ui-visible\.txt') ''
    Comp '5c. y lo hace cada 5 s' ($cs -match 'relojVisible\.Interval = TimeSpan\.FromMilliseconds\(5000\)') ''
    Comp '5d. mirando el modo exclusivo de Windows' ($cs -match 'SHQueryUserNotificationState') 'QUNS_RUNNING_D3D_FULL_SCREEN'
    $iSeVe = $cs.IndexOf('bool SeVe()')
    $blSeVe = if ($iSeVe -gt 0) { $cs.Substring($iSeVe, [Math]::Min(900, $cs.Length - $iSeVe)) } else { '' }
    Comp '5e. ante un fallo, la capsula tambien dice que SI se ve' ($blSeVe -and ($blSeVe -match 'catch') -and ($blSeVe -match 'return true;')) 'el catch cae al return true'
    Comp '5f. el latido viejo es motivo de relanzar' ($txt -match 'sin latir \(su cadencia son') ''
    Comp '5g. pero solo si el fichero existe' ($txt -match '\$vLat -and \$vLat\.hace -gt \(6 \* \$vLat\.cada\)') 'con un exe viejo que no lo escribe, no se relanza en bucle'
    Comp '5h. y se mira cada 30 s, no solo al cambiar de juego' ($txt -match '# .SE LA VE\? \(27/09, idea 67\)') ''

    Write-Host ''
    Write-Host '-- 6. Y LA CAPSULA DE VERDAD, ARRANCADA AQUI --'
    $exe = Join-Path $Raiz 'nova_ui.exe'
    $estado = Join-Path $Raiz 'tmp\ui-estado.json'
    if ((Test-Path $exe) -and (Test-Path $estado) -and -not (Get-Process nova_ui -ErrorAction SilentlyContinue)) {
        $vis2 = Join-Path $Raiz 'tmp\ui-visible.txt'
        $habia = if (Test-Path $vis2) { [IO.File]::ReadAllText($vis2) } else { $null }
        $pr = Start-Process -FilePath $exe -ArgumentList @($estado, "$PID") -WorkingDirectory $Raiz -PassThru
        try {
            $t = 0
            while ($t -lt 24) { Start-Sleep -Milliseconds 500; $t++; if ((Test-Path $vis2) -and (([IO.File]::ReadAllText($vis2)) -ne $habia)) { break } }
            $linea = if (Test-Path $vis2) { ([IO.File]::ReadAllText($vis2)).Trim() } else { '' }
            Comp '6a. la capsula escribe su latido al arrancar' ($linea -match '^[01] \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \d+$') $linea
            Comp '6b. y dice que SE VE (esta en el escritorio, sin juego)' ($linea -match '^1 ') $linea
        } finally {
            Stop-Process -Id $pr.Id -Force -ErrorAction SilentlyContinue
            if ($null -ne $habia) { [IO.File]::WriteAllText($vis2, $habia, $UTF8) }
        }
    } else {
        Write-Host '  --   no se arranca la capsula aqui (falta el exe, el estado, o ya hay una en marcha)'
    }
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la capsula dice si se la ve, y su latido delata si se cuelga viva' -ForegroundColor Green
exit 0
