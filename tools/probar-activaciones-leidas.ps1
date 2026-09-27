# EL CUADERNO DE ACTIVACIONES QUE SOLO ABRIA EL BORRADOR (27/09, idea 85 de las 121)
#
# EL AGUJERO: cada vez que Nova se despierta al oir su nombre, el oido apunta una linea con 14 datos
# -confianza, umbral en vigor, rafaga, pico, ganancia, altavoces, espera y EN QUE ACABO-. Es el unico
# sitio donde queda escrito si despertarse valio la pena, y en todo el repositorio aparecia TRES veces
# fuera de los bancos: quien lo escribe (wake_vosk.py) y quien lo BORRA (Invoke-Olvido). Ni un lector.
#
# LO QUE DICE, leidas sus 125 lineas de 8 dias: 79 acabaron en orden, 37 en NADA, 5 pisadas y 4 sin
# dictado; 46 de 125 (el 37 %) fueron despertarse para nada.
#
# LO QUE ESTE BANCO PROTEGE, y el primero es la meta de la casa:
#   1. que el tramo ALTO de confianza no se toque NUNCA (subir ahi es dejar de oir su nombre)
#   2. que hagan falta 20 muestras en 3 dias distintos, como las otras cinco decisiones
#   3. que un tramo que SI aporta no mueva nada
#   4. que con los datos de HOY no se cambie nada (nace midiendo, no cambiando)
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
foreach ($f in @('Get-DecisionMinimo', 'Get-DecisionPValor', 'Test-DecisionSolida',
                 'Get-ActivacionesTramos', 'Get-ConfianzaQueSobra')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
function Test-DiaCuenta([string]$d) { return $true }
$DecisionMinIntentos = 20
$DecisionAprovecha = 0.15
$DecisionPorAcierto = 10
$DecisionAlfa = 0.05
$EscuchaConf = 0.65
$ActivTramos = @(@{ de = 0.00; a = 0.55 }, @{ de = 0.55; a = 0.70 }, @{ de = 0.70; a = 0.85 },
                 @{ de = 0.85; a = 0.95 }, @{ de = 0.95; a = 1.01 })
Comp 'los cinco tramos salen del archivo' ($txt -match '\$ActivTramos = @\(@\{ de = 0\.00; a = 0\.55 \}') ''

$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-act-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $TmpDir 'pruebas\audio\uso') -Force | Out-Null
$LogDir = $TmpDir
$ActivacionesJsonl = Join-Path $TmpDir 'pruebas\audio\uso\activaciones.jsonl'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Escribir([object[]]$filas) {
    $l = @($filas | ForEach-Object { ConvertTo-Json $_ -Compress })
    [IO.File]::WriteAllLines($ActivacionesJsonl, [string[]]$l, $UTF8)
}
function Fila([double]$conf, [string]$des, [string]$dia) {
    return @{ hora = ($dia + ' 12:00:00'); conf = $conf; desenlace = $des; umbral = 0.016 }
}

try {
    Write-Host ''
    Write-Host '-- 1. SIN CUADERNO NO SE DECIDE NADA --'
    Comp '1a. sin fichero, ni tramos' (@(Get-ActivacionesTramos).Count -eq 0) ''
    Comp '1b. ni confianza que sobre' ((Get-ConfianzaQueSobra) -eq 0) ''

    Write-Host ''
    Write-Host '-- 2. EL TRAMO ALTO NO SE TOCA NUNCA --'
    # 40 activaciones por encima de 0,95 y solo 2 con orden: pesima tasa, y aun asi no se sube
    $filas = @()
    foreach ($i in 1..40) { $filas += (Fila 0.97 $(if ($i -le 2) { 'orden' } else { 'nada' }) ('2026-09-2' + ($i % 8))) }
    Escribir $filas
    $t2 = @(Get-ActivacionesTramos)
    Comp '2a. el tramo se lee' ($t2.Count -eq 1 -and $t2[0].n -eq 40) ([string]$t2[0].n + ' activaciones, ' + [string]$t2[0].ok + ' con orden')
    Comp '2b. pero NO se sube la confianza' ((Get-ConfianzaQueSobra) -eq 0) 'subir ahi es dejar de oir su nombre'

    Write-Host ''
    Write-Host '-- 3. UN TRAMO BAJO INUTIL SI SE CORTA --'
    # 30 activaciones en [0,70-0,85) y solo 1 con orden, repartidas en cinco dias
    $filas = @()
    foreach ($i in 1..30) { $filas += (Fila 0.75 $(if ($i -eq 1) { 'orden' } else { 'nada' }) ('2026-09-2' + ($i % 5))) }
    Escribir $filas
    $q3 = Get-ConfianzaQueSobra
    Comp '3a. se propone subir al borde del tramo' ($q3 -eq 0.85) ([string]$q3)
    Comp '3b. y ese borde deja fuera el tramo malo' ($q3 -gt 0.75) 'lo que casi nunca era una orden'

    Write-Host ''
    Write-Host '-- 4. LO QUE SI APORTA NO SE TOCA --'
    $filas = @()
    foreach ($i in 1..30) { $filas += (Fila 0.75 $(if ($i -le 20) { 'orden' } else { 'nada' }) ('2026-09-2' + ($i % 5))) }
    Escribir $filas
    Comp '4a. con 20 de 30 en orden, no se sube nada' ((Get-ConfianzaQueSobra) -eq 0) '67 % de aprovecho'

    Write-Host ''
    Write-Host '-- 5. NI POR POCOS DATOS NI POR UNA TARDE RARA --'
    $filas = @()
    foreach ($i in 1..15) { $filas += (Fila 0.75 'nada' ('2026-09-2' + ($i % 5))) }
    Escribir $filas
    Comp '5a. con 15 muestras, todavia no' ((Get-ConfianzaQueSobra) -eq 0) 'el minimo son 20'
    $filas = @()
    foreach ($i in 1..30) { $filas += (Fila 0.75 'nada' '2026-09-24') }
    Escribir $filas
    Comp '5b. y con 30 pero todas del MISMO dia, tampoco' ((Get-ConfianzaQueSobra) -eq 0) 'una tanda de pruebas no es una costumbre'

    Write-Host ''
    Write-Host '-- 6. Y CON EL CUADERNO DE VERDAD, HOY NO SE MUEVE NADA --'
    $real = Join-Path $Raiz 'pruebas\audio\uso\activaciones.jsonl'
    if (Test-Path -LiteralPath $real) {
        $ActivacionesJsonl = $real
        $tr = @(Get-ActivacionesTramos)
        foreach ($t in $tr) { Write-Host ('       [' + $t.de.ToString('N2') + '-' + $t.a.ToString('N2') + '): ' + $t.n + ' activaciones, ' + $t.ok + ' con orden, en ' + $t.dias + ' dias') }
        Comp '6a. se leen sus tramos' ($tr.Count -ge 3) ([string]$tr.Count + ' tramos con datos')
        Comp '6b. y HOY no se cambia nada' ((Get-ConfianzaQueSobra) -eq 0) 'nace midiendo, no cambiando'
    } else {
        Write-Host '  --   no hay cuaderno en esta maquina; el resto del banco no depende de el'
    }

    Write-Host ''
    Write-Host '-- 7. EL CABLEADO --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp '7a. es un caso de Test-RevisionPropia, como los otros cinco' ($sinCom -match '(?s)function Test-RevisionPropia.{0,20000}Get-ConfianzaQueSobra') ''
    Comp '7b. se guarda con Save-DecisionPropia (se puede deshacer hablando)' ($sinCom -match "Save-DecisionPropia 'escucha' 'confianzaMinima'") ''
    Comp '7c. respeta lo que braya ya devolvio' ($sinCom -match "Test-DecisionDevuelta 'escucha' 'confianzaMinima'") ''
    Comp '7d. y si no se puede guardar, se deshace en el acto' ($sinCom -match '(?s)Set-Cfg .escucha. .confianzaMinima.{0,200}EscuchaConf = \$antesC') 'nada de cambiar algo que no queda escrito'
    Comp '7e. una sola decision al dia sigue en pie' ($sinCom -match '\$script:revisionPropiaDia -eq \$hoyR') ''
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el cuaderno de activaciones por fin se lee' -ForegroundColor Green
exit 0
