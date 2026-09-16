# LAS QUEJAS REHACEN LA ORDEN (16/09). El 15/09, 19 ordenes acabaron en nada porque la
# queja se trataba como charla o como consulta a la memoria: "no te pedi la hora, dije
# cierra Steam" se contestaba con una disculpa, y braya lo repetia hasta 7 veces.
#
# SE COMPARA EL TEXTO EXACTO a proposito. La primera version de esta prueba solo miraba
# si la orden aparecia DENTRO de lo devuelto, y daba por buenas frases pegadas que no
# son ordenes ("la hora dije cierra steam", "activa el wifi wifi es el bluetooth").
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:ultimoObjetivo = ''
# el patron y las listas, sacados del archivo real (no una copia: si cambian alli, aqui tambien)
$txt = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
foreach ($v in @('RE_QUEJA', 'VERBOS')) {
    if ($txt -notmatch ("(?m)^\`$$v = '(.+)'\s*$")) { throw "no encuentro $v en assistant.ps1" }
    Set-Variable -Name $v -Value $Matches[1]
}
$VERBOS_LISTA = (($VERBOS -replace '^\(\?:', '') -replace '\)$', '') -split '\|'
if ($txt -match '(?ms)^\$VERBOS_OIDOS = @\{.*?^\}') { Invoke-Expression $Matches[0] }
if ($txt -match '(?ms)^\$VERBOS_IMPERATIVO = @\{.*?^\}') { Invoke-Expression $Matches[0] }

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'Repair-Verb')
Invoke-Expression (Traer 'Get-OrdenCorregida')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Ultima([string]$t) {
    $script:ultimaOrden = @{ texto = $t; desc = $t; cuando = $sw.ElapsedMilliseconds }
}
function Sale($queja) { return [string](Get-OrdenCorregida $queja) }
function Igual($etiqueta, $queja, $esperado) {
    $r = Sale $queja
    Comp $etiqueta ($r -eq $esperado) "-> '$r'"
}
function Nada($etiqueta, $queja) {
    $r = Sale $queja
    Comp $etiqueta (-not $r) $(if ($r) { "devolvio '$r'" } else { '' })
}

Write-Host "  -- las quejas de verdad del 15/09 (texto exacto) --"
Ultima 'que hora es'
Igual 'no te pedi la hora, dije cierra steam' 'no te pedi la hora, dije cierra steam' 'cierra steam'

Ultima 'activa el wifi'
Igual 'no es el wifi, es el bluetooth' 'no es el wifi, es el bluetooth' 'activa el bluetooth'

Ultima 'abre steam'
Igual 'lo que dije fue que abrieras el juego' 'lo que dije fue que abrieras el juego' 'abre el juego'

Ultima 'que hora es'
Igual 'por que no abriste steam' 'por que no abriste steam' 'abre steam'

Ultima 'pon el brillo al 50'
Igual 'no, es el volumen' 'no, es el volumen' 'pon el volumen al 50'

$script:ultimoObjetivo = 'pitbull'
Ultima 'busca pitbull en youtube'
Igual 'no solo lo busques, reproducelo' 'no solo lo busques, reproducelo' 'reproduce pitbull'
$script:ultimoObjetivo = ''

Write-Host "  -- lo que NO debe convertirse en una orden --"
Ultima 'abre steam'
Nada 'una orden normal no es una queja' 'cierra discord'
Nada 'una pregunta tampoco' 'que hora es'
Nada 'charla con "no" dentro no arrastra' 'la verdad es que no me gusta ese juego'
Nada 'una queja sin nada que rehacer' 'no, eso no era'
Nada 'no repite la MISMA orden de antes' 'no, dije abre steam'

$script:ultimaOrden = $null
Nada 'sin ninguna orden antes, no corrige nada' 'no te pedi eso, dije cierra steam'

Ultima 'abre steam'
$script:ultimaOrden.cuando = $sw.ElapsedMilliseconds - 200000
Nada 'una queja de hace 3 minutos ya no vale' 'no, dije cierra discord'

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
