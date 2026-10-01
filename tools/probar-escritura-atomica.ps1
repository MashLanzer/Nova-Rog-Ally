# QUE LA ESCRITURA ATOMICA SEA ATOMICA DE VERDAD (1/10/2026)
#
# Write-Atomico llevaba toda la vida pasando $null como tercer argumento de File::Replace, y
# PowerShell convierte $null en CADENA VACIA al pasarlo a un parametro [string]. "" no es una ruta
# valida, asi que Replace lanzaba "La ruta de acceso no tiene un formato valido" SIEMPRE -tambien
# en el caso mas simple, con el destino existiendo y nadie tocandolo- y el camino atomico NUNCA se
# ejecutaba. Las ~50 rutas que pasan por esa funcion han estado yendo por el Move-Item de respaldo,
# que no es atomico: borra y renombra. Y era mudo por partida doble, porque el catch no dice nada y
# el Log del otro camino no saltaba al funcionar el Move-Item.
#
# ESTE BANCO NO LEE LA FORMA DEL CODIGO: ejecuta Write-Atomico de verdad sobre ficheros de verdad y
# comprueba el EFECTO. La unica forma de cazar lo de arriba era mirar si Replace hace su trabajo, y
# para eso hay que llamarlo.
#
# LO QUE DEFIENDE:
#  1. que el camino atomico se USE, no solo que este escrito: si Replace falla, se nota;
#  2. que escriba bien en el caso normal, la primera vez y con BOM;
#  3. que una ruta vacia se diga y no tire un '.tmp' en la raiz del repositorio;
#  4. que no deje .tmp por el suelo, ni cuando sale bien ni cuando sale mal;
#  5. y que nadie vuelva a pasar un $null a un metodo de .NET que espera una cadena.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
Invoke-Expression (Traer 'Write-Atomico')
$script:dicho = @()
function Log([string]$m) { $script:dicho += $m }

$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-atom-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
try {
    Write-Host ''
    Write-Host '-- 1. EL CAMINO ATOMICO SE USA DE VERDAD --'
    # LA COMPROBACION QUE FALTABA Y QUE HABRIA CAZADO EL FALLO: se le quita el respaldo de en medio
    # -se dobla Move-Item para que lance- y se exige que Write-Atomico funcione IGUAL. Si el camino
    # atomico no sirve, aqui se cae. Con el $null de antes, esta linea salia roja.
    $dest = Join-Path $tmpDir 'cosa.json'
    [IO.File]::WriteAllText($dest, '{"antes":1}')
    function Move-Item { throw 'el respaldo esta tapado a proposito: el camino atomico tiene que bastar' }
    $rompio = $false
    try { Write-Atomico $dest '{"despues":2}' } catch { $rompio = $true }
    Comp 'con el respaldo tapado, la escritura sigue funcionando' (-not $rompio) 'si falla, el camino atomico esta muerto'
    Comp '  y el destino tiene lo nuevo' ((Test-Path -LiteralPath $dest) -and ([IO.File]::ReadAllText($dest) -match 'despues')) "$(if (Test-Path $dest) { [IO.File]::ReadAllText($dest) })"
    Comp '  y no queda ningun .tmp' (-not (Test-Path -LiteralPath "$dest.tmp")) ''
    Remove-Item Function:Move-Item -ErrorAction SilentlyContinue

    Write-Host ''
    Write-Host '-- 2. y aguanta que otro tenga el fichero abierto --'
    # Nova lee sus propios ficheros con FileShare.Delete desde el 22/09, justo para que esto pueda
    # ocurrir mientras alguien lee. Medido: Replace lo consigue; el Move-Item NO.
    [IO.File]::WriteAllText($dest, '{"antes":1}')
    $fs = [IO.File]::Open($dest, 'Open', 'Read', 'ReadWrite, Delete')
    $rompio2 = $false
    try { Write-Atomico $dest '{"conLector":3}' } catch { $rompio2 = $true }
    $fs.Close()
    Comp 'con el fichero abierto (compartiendo borrado) se escribe igual' (-not $rompio2 -and ([IO.File]::ReadAllText($dest) -match 'conLector')) ''

    Write-Host ''
    Write-Host '-- 3. la primera vez, cuando el destino aun no existe --'
    $nuevo = Join-Path $tmpDir 'nunca-visto.json'
    Write-Atomico $nuevo '{"primera":1}'
    Comp 'se crea el fichero que no estaba' ((Test-Path -LiteralPath $nuevo) -and ([IO.File]::ReadAllText($nuevo) -match 'primera')) ''
    Comp '  y tampoco deja .tmp' (-not (Test-Path -LiteralPath "$nuevo.tmp")) ''

    Write-Host ''
    Write-Host '-- 4. el BOM se pone solo cuando se pide --'
    $conBom = Join-Path $tmpDir 'con-bom.txt'
    Write-Atomico $conBom 'hola' $true
    $b = [IO.File]::ReadAllBytes($conBom)
    Comp 'con $true lleva BOM' ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) ("primeros bytes: {0:X2} {1:X2} {2:X2}" -f $b[0], $b[1], $b[2])
    $sinBom = Join-Path $tmpDir 'sin-bom.txt'
    Write-Atomico $sinBom 'hola'
    $b2 = [IO.File]::ReadAllBytes($sinBom)
    Comp '  y sin pedirlo, no' ($b2[0] -eq 0x68) ("primer byte: {0:X2}" -f $b2[0])
    # Y AL REESCRIBIR SE MANTIENE: el Replace cambia el fichero entero, no parchea el principio
    Write-Atomico $conBom 'adios' $true
    $b3 = [IO.File]::ReadAllBytes($conBom)
    Comp '  y al reescribir con Replace sigue llevandolo' ($b3[0] -eq 0xEF -and ([IO.File]::ReadAllText($conBom) -match 'adios')) ''

    Write-Host ''
    Write-Host '-- 5. una ruta vacia se DICE, no se escribe en cualquier sitio --'
    # Lo que pasaba: con la ruta vacia, "$ruta.tmp" es ".tmp" a secas y acababa en la raiz del
    # repositorio con los datos de braya dentro.
    $script:dicho = @()
    $antesCwd = @(Get-ChildItem -LiteralPath $tmpDir -Force | ForEach-Object { $_.Name })
    Write-Atomico '' 'esto no se escribe en ningun sitio'
    Comp 'con la ruta vacia no escribe nada' (@(Get-ChildItem -LiteralPath $tmpDir -Force | ForEach-Object { $_.Name }).Count -eq $antesCwd.Count) ''
    Comp '  y lo dice en el registro' (@($script:dicho | Where-Object { $_ -match 'ruta vacia' }).Count -eq 1) "$($script:dicho -join ' | ')"
    Comp '  y no deja un ".tmp" suelto' (-not (Test-Path -LiteralPath (Join-Path (Get-Location) '.tmp'))) 'aparecio uno de verdad en la raiz el 27/09'

    Write-Host ''
    Write-Host '-- 6. si NO se puede poner en su sitio, se dice y no se queda el .tmp --'
    # Los dos caminos fallando: el destino bloqueado para escritura sin compartir nada. Medido:
    # ni Replace ni Move-Item pueden, y eso es exactamente cuando hay que hablar.
    $preso = Join-Path $tmpDir 'bloqueado.json'
    [IO.File]::WriteAllText($preso, '{"viejo":1}')
    $fsP = [IO.File]::Open($preso, 'Open', 'ReadWrite', 'None')
    $script:dicho = @()
    $lanzo = $false
    try { Write-Atomico $preso '{"nuevo":2}' } catch { $lanzo = $true }
    $fsP.Close()
    Comp 'lanza, para que el llamante sepa que no se guardo' $lanzo 'callarse seria decir que se guardo'
    Comp '  y lo deja escrito en el registro' (@($script:dicho | Where-Object { $_ -match 'no pude poner en su sitio' }).Count -eq 1) "$($script:dicho -join ' | ')"
    # EL .tmp NO SE QUEDA: lleva el contenido NUEVO y nadie lo barre en memoria\, asi que seria un escape
    Comp '  y el .tmp con los datos nuevos NO se queda' (-not (Test-Path -LiteralPath "$preso.tmp")) 'en memoria\ nadie barre los .tmp'
    Comp '  y el destino conserva lo viejo' ([IO.File]::ReadAllText($preso) -match 'viejo') ''
} finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 7. nadie vuelve a pasar $null a un metodo que espera una cadena --'
# LA REGLA GENERAL, no solo este sitio: PowerShell convierte $null en "" al pasarlo a un parametro
# [string] de .NET, y para muchas APIs "" no es lo mismo que null (una ruta vacia, por ejemplo).
# Lo que hace falta es [NullString]::Value. Se busca sobre el fuente SIN comentarios, porque este
# mismo arreglo explica el fallo en prosa y casar con eso seria un verde mintiendo (la manera 1).
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'Write-Atomico pasa [NullString]::Value, no $null' ($sinCom -match 'File\]::Replace\(\$tmp, \$ruta, \[NullString\]::Value\)') 'con $null falla SIEMPRE'
Comp '  y no queda ningun ::Replace con $null' ($sinCom -notmatch 'File\]::Replace\([^)]*\$null') ''
# Y EL OTRO SITIO QUE USA $null ASI ESTA COMPENSADO A MANO (ChangeExtension deja el punto colgando
# y se le quita con TrimEnd). Se comprueba que siga compensado, porque quitar el TrimEnd creyendo
# que sobra dejaria rutas como "eventos.-pulso.log".
$iCE = $sinCom.IndexOf('ChangeExtension($EventLog, $null)')
Comp "y el ChangeExtension con `$null sigue quitandose el punto" ($iCE -ge 0 -and $sinCom.Substring($iCE, 60) -match "TrimEnd\('\.'\)") 'sin el TrimEnd saldria "eventos."'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la escritura atomica es atomica de verdad' -ForegroundColor Green
exit 0
