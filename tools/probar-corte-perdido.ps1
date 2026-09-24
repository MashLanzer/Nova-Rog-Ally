# LAS CINCO INTERRUPCIONES QUE SE TIRABAN DENTRO DE CASA (24/09, idea 2 de la tanda nueva).
#
# EL DATO: el oido escribio 15 corte.flag en quince dias y el asistente atendio 10. Las otras
# cinco NO se perdieron por el oido -acerto las quince- sino en el bloque del bucle:
#
#   - CUATRO con un dictado abierto. El 20/09 a las 12:54 y a las 13:34 hubo dos dictados
#     colgados de 48 segundos con "para", "nova" y "basta" dichos DENTRO, y el bloque tenia
#     dos ramas para tres situaciones: con $script:armed puesto no entraba ninguna. Un modo
#     abierto 48 s con dos ordenes de parar dentro es un modo sin salida, que es la regla 2.
#   - UNA por pausa vencida, que es correcto... pero tampoco dejaba rastro.
#
# Y NINGUNA DE LAS CINCO DEJO UNA LINEA EN EL REGISTRO: el flag se borra en la tercera linea
# del bloque, antes de decidir. Por eso el agujero tardo quince dias en verse.
#
# LO QUE NO SE TOCA: ni las palabras de corte, ni el 0,9 de confianza, ni el margen de tono.
# No hay un dato que diga que se quedan cortos, y los 19 rechazos por tono son la guarda que
# evito que la propia voz de Nova la callara.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

foreach ($f in @('ConvertTo-Plain', 'Resolve-Corte')) { Invoke-Expression (Traer $f) }
$N = 'nova'

Write-Host ''
Write-Host '-- 1. LAS SEIS SITUACIONES TIENEN RAMA, que es lo que fallaba --'
# El fallo de quince dias fue tener dos ramas para tres situaciones. Aqui se recorren las
# seis combinaciones posibles y ninguna puede quedarse sin respuesta.
$casos = @(
    @{ p = 'nova';  arm = $false; pau = $false; sor = $true;  esp = 'sordina-vuelve' },
    @{ p = 'basta'; arm = $false; pau = $false; sor = $true;  esp = 'tarde' },
    @{ p = 'para';  arm = $true;  pau = $true;  sor = $false; esp = 'cancela-dictado' },
    @{ p = 'nova';  arm = $true;  pau = $false; sor = $false; esp = 'cancela-dictado' },
    @{ p = 'nova';  arm = $false; pau = $true;  sor = $false; esp = 'corta-y-escucha' },
    @{ p = 'basta'; arm = $false; pau = $true;  sor = $false; esp = 'corta-y-calla' },
    @{ p = 'para';  arm = $false; pau = $false; sor = $false; esp = 'tarde' }
)
foreach ($c in $casos) {
    $r = Resolve-Corte $c.p $N $c.arm $c.pau $c.sor
    $et = "'$($c.p)' armado=$($c.arm) pausa=$($c.pau) sordina=$($c.sor)"
    Comp ("$et -> $($c.esp)") ([string]$r.accion -eq $c.esp) "$([string]$r.accion)"
}

Write-Host ''
Write-Host '-- 2. EL CASO DEL 20/09: un dictado abierto con "para" dentro --'
# Dos dictados colgados de 48 s con "para", "nova" y "basta" dichos dentro. Hoy se cancelan.
foreach ($pal in @('para', 'basta', 'calla', 'nova')) {
    $r = Resolve-Corte $pal $N $true $true $false
    Comp ("con dictado abierto, '$pal' lo cancela") ([string]$r.accion -eq 'cancela-dictado') "$([string]$r.accion)"
    Comp "   y NO reabre el microfono" (-not $r.abreMicro) 'cancelar no es pedir hablar'
}

Write-Host ''
Write-Host '-- 3. y el dictado manda sobre la pausa --'
# Si esta hablando Y hay un dictado abierto, lo que se pide es cancelar el dictado.
$r = Resolve-Corte 'nova' $N $true $true $false
Comp 'hablando Y dictando: se cancela el dictado' ([string]$r.accion -eq 'cancela-dictado') "$([string]$r.accion)"

Write-Host ''
Write-Host '-- 4. ninguna se pierde sin dejar rastro --'
# Las cinco perdidas no dejaron ni una linea, y por eso el agujero duro quince dias.
$conEst = 0
foreach ($c in $casos) {
    $r = Resolve-Corte $c.p $N $c.arm $c.pau $c.sor
    if ([string]$r.estadistica) { $conEst++ }
}
Comp 'las siete situaciones dejan un contador' ($conEst -eq $casos.Count) "$conEst de $($casos.Count)"
$rt = Resolve-Corte 'para' $N $false $false $false
Comp 'y la que llega tarde tiene el suyo' ([string]$rt.estadistica -eq 'corte-tarde') "$([string]$rt.estadistica)"
$bloque = ($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'el bucle lo apunta de verdad' ($bloque -match "Add-Estadistica 'corte-tarde'") ''
Comp 'y el del dictado tambien' ($bloque -match "Add-Estadistica 'corte-dictado'") ''

Write-Host ''
Write-Host '-- 5. lo que NO se toca --'
$rc = SinComentarios (Traer 'Resolve-Corte')
Comp 'la decision es pura: no habla' (($rc -notmatch 'Say\b') -and ($rc -notmatch 'Send-Aviso')) ''
Comp 'ni ejecuta una orden' (($rc -notmatch 'Invoke-FastCommand') -and ($rc -notmatch 'Submit-Command')) 'la regla 1'
Comp 'ni toca el estado' (($rc -notmatch '\$script:armed =') -and ($rc -notmatch '\$script:pausaHasta =')) 'decide; quien actua es el bucle'
# las palabras de corte y el liston de confianza viven en el oido y no se tocan
$wake = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))
Comp 'las palabras de corte siguen en el oido' ($wake -match 'PALABRAS_CORTE') 'no se amplian: no hay dato que lo pida'

Write-Host ''
Write-Host '-- 6. y el bloque del bucle usa la decision, no un -eq repetido --'
$iB = ($fuente -split "`r?`n" | Select-String -SimpleMatch 'Resolve-Corte $palabraCorte' | Select-Object -First 1).LineNumber
Comp 'el bucle llama a Resolve-Corte' ($null -ne $iB) ''
$lineas = @($fuente -split "`r?`n")
$trozo = (($lineas[($iB - 1)..($iB + 60)] | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
# EL 'if' EN SI, no que la palabra aparezca por ahi: $dCorte.abreMicro sale dos veces en este
# trozo -una en $esNombreC- y la comprobacion pasaba aunque el if volviera a comparar a mano.
Comp 'y decide con abreMicro, no comparando otra vez' ($trozo -match 'if \(\$dCorte\.abreMicro\)') 'dos sitios que comparan lo mismo acaban separandose'
Comp 'y no queda ningun -eq con el nombre en el bloque' ($trozo -notmatch 'ConvertTo-Plain \$EscuchaNombre') 'la comparacion vive en Resolve-Corte y en ningun sitio mas'
Comp 'la rama del dictado existe en el bucle' ($trozo -match "cancela-dictado") ''
Comp 'y cierra el dictado de verdad' ($trozo -match '\$script:armed = \$false') ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya no se tira una interrupcion que acerto'
exit 0
