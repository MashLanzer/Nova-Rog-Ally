# EL ESCALON DE LA CASCADA QUE NO SACA NINGUNA ORDEN (25/09)
#
# LO MEDIDO: la cascada de repasos es canary -> base. En sus 18 usos REALES del registro,
# canary NO ha sacado UNA SOLA orden: las 18 acaban en "REPASO: base tampoco dio una orden" o
# se van a Whisper. Y cuesta 3,3 s de mediana solo en cargarse, mas entre 1,2 y 14,5 s de
# transcripcion. El peor, el 21/09 a las 23:40: 8,8 s de carga mas 14,5 s de repaso -23
# segundos- para devolver "Eh, no avisame cuando la descarga de de Sting termine", que ademas
# es PEOR que lo que ya habia oido Parakeet.
#
# LO QUE **NO** SE HACE, y es la parte importante: NO se apaga canary a mano. 18 no son 20, y
# DecisionMinIntentos son 20. Lo que se hace es poner el CONTADOR QUE FALTABA -hasta hoy la
# cascada no dejaba ni un numero con el que juzgarla- y meter el caso en la revision propia,
# que ya sabe apagar la nube y el oido fino con sus frenos: minimo de intentos, umbral de
# aprovecho, solidez y datos repartidos en varios dias. Nova lo decidira cuando tenga datos.
#
# Y EL ULTIMO ESCALON NO SE TOCA NUNCA: ese es el que saca las ordenes de verdad (325
# desenlaces por Whisper) y quitarlo la dejaria sin red. Solo los de en medio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. EL CONTADOR, que es lo que faltaba --'
Comp 'se apunta cada repaso por motor' ($sinCom -match 'Add-Estadistica "repaso:\$motorC"') ''
Comp 'y cuando ese motor SI saca la orden' ($sinCom -match 'Add-Estadistica "repaso-sirvio:\$motorC"') ''
# LO QUE SE PAGO EL 24/09 CON nube-invento: contar los desenlaces y no los intentos. Aqui el
# total tiene que contarse SIEMPRE, no solo cuando falla.
$bloque = [regex]::Match($sinCom, '(?s)\$motorC = \[string\]\$RepasoCascada.{0,600}?\n\s*\}')
Comp 'el total se cuenta fuera del if del acierto' (
    $bloque.Success -and ($bloque.Value -replace '(?s)if \(Test-FastCommand.*', '') -match 'repaso:\$motorC') `
    'si se contara solo al fallar, el que acierta valdria cero siempre'
# Y QUE LAS CLAVES ENTREN EN EL RECUENTO: sin esto se cuentan cero para siempre y la regla de
# abajo es codigo muerto. Es exactamente lo que le paso a nube-invento hasta el 24/09.
Comp 'las claves entran en el recuento de la revision' (
    $sinCom -match '\$numR\["repaso:\$mC"\]\s*=\s*0') 'si no, contarian cero siempre'
Comp '  y salen de la lista de config, no escritas a mano' (
    $sinCom -match 'foreach \(\$mC in @\(\$RepasoCascada\)\)') 'asi un motor nuevo trae su contador solo'

Write-Host ''
Write-Host '-- 2. LA DECISION usa los MISMOS frenos que la nube y el oido fino --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Invoke-RevisionPropia' }, $true)
if (-not $d) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
         Where-Object { $_.Extent.Text -match 'caso 5: EL ESCALON DE LA CASCADA' } | Select-Object -First 1
}
Comp 'se encuentra la funcion de la revision propia' ($null -ne $d) ''
if ($d) {
    $c = $d.Extent.Text
    Comp 'exige un minimo de intentos' ($c -match '\$intC -lt \$DecisionMinIntentos') 'con 18 no se decide nada'
    Comp 'exige que no llegue al umbral de aprovecho' ($c -match 'Get-DecisionMinimo \$intC') ''
    Comp 'exige que el dato sea solido' ($c -match 'Test-DecisionSolida \$okC \$intC') ''
    Comp 'y que este repartido en varios dias' ($c -match 'Test-DatosRepartidos \$stR "repaso:\$mtC"') 'una tarde mala no cambia la config'
    # Y EL FRENO DEL OTRO CAMINO (26/09, idea 19). Desde hoy el caso 5 puede juzgar con lo que
    # ya esta en registro.jsonl cuando sus propias cuentas no llegan a 20. Sin este Comp, meter
    # el Test-DatosRepartidos de arriba dentro de un if/else dejaria la cadena literal en el
    # fuente y este banco seguiria verde mientras el camino nuevo se salta el reparto entero.
    Comp '  y tambien cuando decide con el registro' ($c -match 'Get-MotoresRepartidos \$medC \$mtC') 'el camino nuevo tiene su propio freno'
    Comp '  y solo con ese motor juzgado entero' ($c -match '\$medC\[\$mtC\]\.completo') 'lo que falta por juzgar son las lineas mas nuevas'
    Comp 'se puede deshacer' ($c -match "Save-DecisionPropia 'escucha' 'repasos'") 'regla 2: dos salidas'
    Comp 'y se dice en voz alta' ($c -match "Send-AvisoEntorno 'auto-cascada'") ''
    Comp '  con las dos salidas dentro del aviso' ($c -match 'deshaz lo que has cambiado') ''
    # SI NO SE PUEDE GUARDAR, SE DESHACE EN MEMORIA: si no, Nova se quedaria con la cascada
    # cambiada en esta sesion y el fichero diciendo otra cosa.
    Comp 'si no puede guardarlo, lo deja como estaba' ($c -match 'no pude guardar el cambio de la cascada') ''
}

Write-Host ''
Write-Host '-- 3. EL ULTIMO ESCALON NO SE TOCA NUNCA --'
# Esto es la salvaguarda: sin ella Nova podria quedarse sin ningun repaso, que es lo que de
# verdad saca las ordenes.
if ($d) {
    $c = $d.Extent.Text
    Comp 'el bucle se para antes del ultimo' ($c -match 'Select-Object -First \(\[Math\]::Max\(0, \$RepasoCascada\.Count - 1\)\)') ''
    Comp 'y ademas comprueba que quede alguno' ($c -match '\$quedaC\.Count -lt 1') 'dos guardas para lo mismo, a proposito'
}
# Y SE EJECUTA DE VERDAD, no solo se lee: con una cascada de un solo motor no puede quitar nada
$RepasoCascada = @('base')
$quita = @($RepasoCascada | Select-Object -First ([Math]::Max(0, $RepasoCascada.Count - 1)))
Comp 'con un solo motor, no hay ninguno que quitar' ($quita.Count -eq 0) 'ni siquiera entra en el bucle'
$RepasoCascada = @('canary', 'base')
$quita2 = @($RepasoCascada | Select-Object -First ([Math]::Max(0, $RepasoCascada.Count - 1)))
Comp 'con dos, solo el primero es candidato' (($quita2.Count -eq 1) -and ($quita2[0] -eq 'canary')) "$($quita2 -join ',')"
$RepasoCascada = @('canary', 'omni', 'base')
$quita3 = @($RepasoCascada | Select-Object -First ([Math]::Max(0, $RepasoCascada.Count - 1)))
Comp 'con tres, los dos primeros' (($quita3.Count -eq 2) -and ($quita3 -notcontains 'base')) "$($quita3 -join ',')"
$RepasoCascada = @()
$quita4 = @($RepasoCascada | Select-Object -First ([Math]::Max(0, $RepasoCascada.Count - 1)))
Comp 'con la cascada vacia no revienta' ($quita4.Count -eq 0) ''

Write-Host ''
Write-Host '-- 4. y el liston de hoy NO alcanza para decidir, que es lo correcto --'
$mD = [regex]::Match($txt, '(?m)^\$DecisionMinIntentos\s*=\s*(\d+)')
Comp 'se saca del archivo DecisionMinIntentos' $mD.Success ''
$minI = if ($mD.Success) { [int]$mD.Groups[1].Value } else { 20 }
# EL 18 ESTABA ESCRITO A MANO Y YA NO ES VERDAD (26/09). El registro trae hoy treinta repasos
# de canary, no dieciocho, y desde la idea 19 el caso 5 SI puede juzgarlos. Lo que sigue
# valiendo -y es lo que aqui hay que afirmar- es que las CUENTAS PROPIAS no llegan: se sacan
# del fichero en vez de escribirlas.
$nCanary = 0
$regC = Join-Path $Raiz 'pruebas\audio\uso\registro.jsonl'
if (Test-Path -LiteralPath $regC) {
    foreach ($lC in [IO.File]::ReadAllLines($regC)) { if ($lC -match '"motor"\s*:\s*"canary"') { $nCanary++ } }
}
$propiasC = 0
try {
    $stC = Get-Content -LiteralPath (Join-Path $Raiz 'memoria\estadisticas.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($dC in $stC.dias.PSObject.Properties) {
        foreach ($kC in $dC.Value.PSObject.Properties) { if ($kC.Name -eq 'repaso:canary') { $propiasC += [int]$kC.Value } }
    }
} catch { }
Write-Host "       canary: $nCanary repasos en el registro, $propiasC en mis propias cuentas"
Comp 'las cuentas propias de canary siguen sin llegar al minimo' ($propiasC -lt $minI) "$propiasC < ${minI}"
Comp '  pero el registro si tiene con que juzgarlo' ($nCanary -ge $minI) "$nCanary repasos apuntados por Python"

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  la cascada se puede juzgar sola'
exit 0
