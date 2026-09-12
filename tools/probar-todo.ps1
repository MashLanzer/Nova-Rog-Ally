# Pasa TODAS las comprobaciones que no necesitan microfono ni arrancar nada.
# Pensado para ejecutarlo despues de cada cambio:
#
#   powershell -NoProfile -File tools\probar-todo.ps1
#
# Son cuatro cosas distintas, y la cuarta va al reves que las demas:
#   1. que los patrones compilen        (un regex roto no protesta: no encuentra nada)
#   2. que las funciones sueltas acierten (sacadas del archivo real, no de una copia)
#   3. que las ordenes de verdad se reconozcan   -> cuanto MAS alto, mejor
#   4. que el ruido real NO se reconozca         -> cuanto MAS bajo, mejor
$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz
$fallos = 0

function Titulo($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }

Titulo "1. Patrones (todos deben compilar)"
# Tambien las herramientas: un CR suelto colado en una ruta dentro de una
# prueba hizo que la comprobacion mas importante del oido fino midiera 0 casos
# y dijera "OK" igual. Las pruebas tambien se rompen en silencio.
$aRevisar = @('assistant.ps1') + @(Get-ChildItem -Path $PSScriptRoot -Filter 'probar-*.ps1' | ForEach-Object { $_.FullName })
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-regex.ps1') -Archivos $aRevisar
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2. Funciones sueltas, sacadas del archivo real"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-funciones.ps1')
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2c. El JSON de la capsula (campos del oido y del plazo)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-json-ui.ps1') | Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2l. El parte general (que diga lo que hay y calle lo que no aporta)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-parte.ps1') | Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2d. La tarjeta de respuestas largas (que no te saque del juego)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-tarjeta.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2e. Siempre encima (sobre una ventana de mentira, sin robar el foco)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ventana.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2f. Modos por voz (crear, sustituir y borrar en commands.json)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-modos.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2g. Reglas atadas a una descarga de Steam"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-descargas.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2h. Frases que ya te molestaron una vez (y que se curan solas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-rechazos.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2i. Deshacer por ventana de tiempo (la foto mas vieja, no la ultima)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-deshacer.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2j. Guardar la esquina sin romper config.json"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-esquina.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2k. Los tres sonidos propios (y que sin ellos no se quede mudo)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-sonidos.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2b. Autosordina (se calla sola si el microfono caza ruido en racha)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-autosordina.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "3. Ordenes que SI deben reconocerse"
foreach ($banco in @('ordenes-que-funcionaban.txt', 'casos-nuevos.txt')) {
    $salida = powershell -NoProfile -File 'assistant.ps1' -Probar (Join-Path 'pruebas' $banco) 2>&1
    $linea = @($salida | Select-String 'reconocidas en local')[-1]
    Write-Host ("   {0,-32} {1}" -f $banco, $linea)
    # las que fallan son controles a proposito; lo que importa es que no BAJE
    if (-not $linea) { $fallos++ }
}

Titulo "5. Tu voz de verdad (si ya grabaste las ordenes)"
# Lo unico del banco que mide el MICROFONO y no texto. Si no hay grabaciones,
# lo dice y sigue: no es un fallo, es que todavia no las has hecho.
python (Join-Path $PSScriptRoot 'probar-audio.py')
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "4. Ruido real (aqui cuanto MENOS se reconozca, mejor)"
$salida = powershell -NoProfile -File 'assistant.ps1' -Probar (Join-Path 'pruebas' 'ruido-real.txt') 2>&1
$linea = @($salida | Select-String 'reconocidas en local')[-1]
Write-Host "   $linea"
if ("$linea" -match 'local:\s*(\d+)') {
    $n = [int]$Matches[1]
    # 3 es lo que quedo el 11/09 con el corpus ya curado: dos nombres de juego
    # (que al ejecutarse preguntan antes) y un "Adios" que solo contesta. Si
    # sube, alguien ha aflojado la capa local y volvera a hacer cosas solo.
    if ($n -gt 3) {
        Write-Host "   OJO: antes eran 3. Ha subido: algo se ha vuelto mas confiado." -ForegroundColor Red
        $fallos++
    }
}

Write-Host ""
Pop-Location
if ($fallos -gt 0) { Write-Host "$fallos comprobaciones con problemas" -ForegroundColor Red; exit 1 }
Write-Host "todo en orden" -ForegroundColor Green
