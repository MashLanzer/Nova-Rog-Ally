# QUIEN VIGILA AL VIGILANTE: LA SECCION 7 DE LA BATERIA (27/09, tras la revision)
#
# La seccion 7 de probar-todo.ps1 es la unica que mira la SALIDA DE ERROR que van dejando los 314
# bancos. Es la pieza mas importante de toda la bateria y la que menos se mira, porque no prueba
# ninguna funcion de Nova: prueba a los demas bancos. Si su logica se rompe, no se rompe una
# comprobacion, se queda sin vigilancia la bateria entera y nadie se entera, que es exactamente lo
# que paso hasta hoy.
#
# LO QUE TIENE QUE DISTINGUIR, y son cuatro cosas distintas:
#   1. un banco que llamo a una funcion que no habia traido  -> ROJO (no prueba lo que dice probar)
#   2. un banco de Python que murio en el import             -> ROJO (no comprobo nada; nuevo hoy)
#   3. ruido legitimo: avisos, barras de progreso            -> AMARILLO (un rojo que sale siempre
#                                                               se aprende a ignorar)
#   4. nada escrito                                          -> VERDE
#
# COMO SE PRUEBA, sin copiar nada: el bloque se SACA del probar-todo.ps1 de verdad por sangrado -no
# es una funcion, asi que no vale el AST- y se ejecuta con un fichero de errores de mentira. Si
# manana alguien cambia ahi la logica, esto lo mide sobre el codigo nuevo, no sobre una copia.
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$mal = 0

$ruta = Join-Path $PSScriptRoot 'probar-todo.ps1'
$bat = [IO.File]::ReadAllLines($ruta)
$ini = -1
for ($i = 0; $i -lt $bat.Count; $i++) {
    if ($bat[$i] -eq 'if (Test-Path -LiteralPath $script:errBanco) {') { $ini = $i; break }
}
if ($ini -lt 0) {
    Write-Host '  MAL  no encuentro el bloque de la seccion 7 en probar-todo.ps1' -ForegroundColor Red
    exit 1
}
$fin = -1
for ($i = $ini + 1; $i -lt $bat.Count; $i++) {
    if ($bat[$i] -eq '}') { $fin = $i; break }
}
if ($fin -lt 0) {
    Write-Host '  MAL  encuentro el principio del bloque pero no su final' -ForegroundColor Red
    exit 1
}
$bloque = ($bat[$ini..$fin] -join "`r`n")
Write-Host ''
Write-Host ('-- el bloque sacado del fichero de verdad: lineas ' + ($ini + 1) + '-' + ($fin + 1) + ' --')

function Caso([string]$que, [string]$contenido, [bool]$esperoRojo) {
    $script:errBanco = Join-Path $env:TEMP ('err-de-mentira-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
    [IO.File]::WriteAllText($script:errBanco, $contenido)
    $fallos = 0
    $avisosAmarillos = @()
    # EL BLOQUE HABLA POR Write-Host (stream 6) y aqui NO puede salir: la bateria filtra esta
    # seccion buscando "MAL", y los "MAL" de los casos de mentira se leerian como fallos de verdad.
    $null = (Invoke-Expression $bloque 6>&1 5>&1 4>&1 3>&1 2>&1) | Out-String
    $rojo = ($fallos -gt 0)
    Remove-Item -LiteralPath $script:errBanco -Force -ErrorAction SilentlyContinue
    if ($rojo -eq $esperoRojo) { Write-Host ('  OK   ' + $que.PadRight(54) + ' fallos=' + $fallos) }
    else { Write-Host ('  MAL  ' + $que.PadRight(54) + ' fallos=' + $fallos + ', esperaba rojo=' + $esperoRojo) -ForegroundColor Red; $script:mal++ }
    # y que los avisos amarillos no se cuelen como rojos ni al reves
    return $avisosAmarillos.Count
}

Write-Host ''
Write-Host '-- LO QUE TIENE QUE PONERSE ROJO --'
$py = @(
    'Traceback (most recent call last):',
    '  File "C:\x\tools\probar-lo-que-sea.py", line 12, in <module>',
    '    import numpy as np',
    "ModuleNotFoundError: No module named 'numpy'") -join "`r`n"
$null = Caso 'un banco de Python que murio en el import' $py $true
$null = Caso 'y tambien si es un ImportError pelado' "ImportError: cannot import name 'x' from 'y'" $true
$null = Caso 'una funcion que el banco no trajo' "El termino 'Get-Lo-Que-Sea' no se reconoce como nombre de un cmdlet. CommandNotFoundException" $true

Write-Host ''
Write-Host '-- Y LO QUE NO --'
$amarillos = Caso 'ruido normal: se queda en amarillo' '  aviso: la barra de progreso escribio algo' $false
Write-Host ('  --   y deja su aviso amarillo (' + $amarillos + ')') -ForegroundColor DarkGray
$null = Caso 'sin nada escrito, verde' '' $false

Write-Host ''
if ($mal -eq 0) {
    Write-Host 'la seccion 7 distingue el ruido de un banco muerto'
    exit 0
}
Write-Host ('MAL: ' + [string]$mal + ' comprobaciones') -ForegroundColor Red
exit 1
