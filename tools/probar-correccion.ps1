# LAS QUEJAS REHACEN LA ORDEN (16/09). El 15/09, 19 ordenes acabaron en nada porque la
# queja se trataba como charla o como consulta a la memoria: "no te pedi la hora, dije
# cierra Steam" se contestaba con una disculpa, y braya lo repetia hasta 7 veces.
#
# SE COMPARA EL TEXTO EXACTO a proposito. La primera version de esta prueba solo miraba
# si la orden aparecia DENTRO de lo devuelto, y daba por buenas frases pegadas que no
# son ordenes ("la hora dije cierra steam", "activa el wifi wifi es el bluetooth").
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red
       # y no deja la carpeta temporal de lo aprendido tirada por ahi si muere a mitad
       if ($tmpOido -and (Test-Path -LiteralPath $tmpOido)) { Remove-Item -LiteralPath $tmpOido -Recurse -Force -ErrorAction SilentlyContinue }
       exit 1 }
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
# LA VENTANA DE LA QUEJA, DEL ARCHIVO (26/09). Get-OrdenCorregida dejo de llevar el 180000
# escrito dentro y ahora usa $QuejaVentanaMs, que comparte con la marca del fallo. Sin sacarla
# aqui, la funcion la veia como $null... y en PowerShell $null vale 0 en una comparacion
# numerica, asi que "algo -gt $null" es CIERTO SIEMPRE: la funcion se salia por la guarda de
# "esto es muy viejo" en las seis pruebas y devolvia cadena vacia. Seis rojos con el codigo
# perfectamente bien. Es el mismo tropiezo que ya documenta el banco del animo.
$mQV = [regex]::Match($txt, '(?m)^\$QuejaVentanaMs\s*=\s*(.+)$')
if (-not $mQV.Success) { throw "no encuentro QuejaVentanaMs en assistant.ps1" }
Invoke-Expression ('$QuejaVentanaMs = ' + $mQV.Groups[1].Value.Trim())
# LOS TESTIGOS QUE HACEN FALTA, TAMBIEN DEL FICHERO (27/09). Get-VerbosAprendidos lo lee
# para decidir que entrada vale ya. Sin sacarlo, valdria $null (= 0) y cualquier entrada a
# medias contaria: el mismo tropiezo del $null que documenta la ventana de arriba.
$mOT = [regex]::Match($txt, '(?m)^\$OidoTestigosMin\s*=\s*(\d+)')
if (-not $mOT.Success) { throw "no encuentro OidoTestigosMin en assistant.ps1" }
$OidoTestigosMin = [int]$mOT.Groups[1].Value
if ($txt -match '(?ms)^\$VERBOS_OIDOS = @\{.*?^\}') { Invoke-Expression $Matches[0] }
if ($txt -match '(?ms)^\$VERBOS_IMPERATIVO = @\{.*?^\}') { Invoke-Expression $Matches[0] }

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Distancia')
# LA CADENA DE Repair-Verb, COMPLETA (27/09). Repair-Verb paso a consultar lo aprendido del
# uso (idea 87) y llama a Get-VerbosAprendidos, que a su vez llama a Get-OidoAprendido. Sin
# las dos, el banco reventaba en el PRIMER caso: "El termino 'Get-VerbosAprendidos' no se
# reconoce". Se extraen las de verdad, no una copia.
Invoke-Expression (Traer 'Get-OidoAprendido')
Invoke-Expression (Traer 'Get-VerbosAprendidos')
Invoke-Expression (Traer 'Repair-Verb')
Invoke-Expression (Traer 'Get-QuejaVentanaMs')
Invoke-Expression (Traer 'Get-OrdenCorregida')

# LA RUTA DE LO APRENDIDO, A UNA CARPETA TEMPORAL Y DESPUES DE CARGAR (27/09). Es lo unico
# de mentira que hace falta aqui. Y tiene que ser una ruta VALIDA que no exista, no $null:
# con $null, el Test-Path de dentro de Get-OidoAprendido revienta y su catch se traga el
# error devolviendo la lista vacia, que es justo la respuesta que espera la prueba. Esa es
# la manera 10 de salir verde mintiendo, y asi no pasa: aqui no se traga nada.
$tmpOido = Join-Path ([IO.Path]::GetTempPath()) ('nova-corr-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmpOido -Force | Out-Null
$OidoAprendidoPath = Join-Path $tmpOido 'oido-aprendido.json'
function Poner-Aprendido([string]$malo, [string]$bueno, [int]$testigos) {
    $j = '{"' + $malo + '":{"bueno":"' + $bueno + '","testigos":' + $testigos + ',"visto":"2026-09-27"}}'
    [IO.File]::WriteAllText($OidoAprendidoPath, $j, (New-Object Text.UTF8Encoding($false)))
    $script:oidoAprendido = $null   # la funcion real cachea: hay que soltar la cache
}
function Quitar-Aprendido {
    if (Test-Path -LiteralPath $OidoAprendidoPath) { Remove-Item -LiteralPath $OidoAprendidoPath -Force }
    $script:oidoAprendido = $null
}
Quitar-Aprendido

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

Write-Host "  -- la queja tambien pasa por lo aprendido de oido (idea 87) --"
# NO ES DECORADO: es lo que prueba que Get-VerbosAprendidos esta VIVA aqui. Si la cadena se
# quedase a medias (la lista vacia por un error tragado), este caso saldria rojo.
Poner-Aprendido 'haben' 'abre' $OidoTestigosMin
Ultima 'que hora es'
Igual 'un verbo aprendido del uso se repara' 'no te pedi la hora, dije haben steam' 'abre steam'

Poner-Aprendido 'haben' 'abre' ($OidoTestigosMin - 1)
Ultima 'que hora es'
Nada 'con un testigo de menos, no se toca' 'no te pedi la hora, dije haben steam'
Quitar-Aprendido

Remove-Item -LiteralPath $tmpOido -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
