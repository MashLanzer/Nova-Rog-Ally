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

Titulo "2m. Que solo te obedezca a ti (a quien se pregunta y a quien no)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-voz-dueno.ps1') | Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n. A donde va cada frase (colisiones entre ordenes parecidas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-destinos.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2o. Avisos sin voz (cuando hablar y cuando solo verse)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-avisos.ps1') | Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2p. Listas (se llenan, se leen, se tachan y se vacian)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-listas.ps1') | Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2q. Autoaprendizaje (recetas, variantes, perfil, cuanto has aprendido)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-recetas.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2r. Cada juego (donde te quedaste, cuanto gasta de bateria)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-juegos.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2s. Costumbres (notificaciones jugando, proponer automatizar habitos)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-costumbres.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2t. Conversacion (frases, marcas [ORDEN]/[API], API primero y el local de respaldo)"
python (Join-Path $PSScriptRoot 'probar-charla.py') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2u. Cerebro propio (aprende sin quedarse con datos malos, busca por palabras y significado)"
python (Join-Path $PSScriptRoot 'probar-memoria.py') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2w. Escucha sin microfono (cuando se da por terminada la frase)"
python (Join-Path $PSScriptRoot 'probar-escucha.py') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2v. Quinta tanda (despertador, dormir, limite de juego, musica, clip, descargas, dock y cascos)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-funciones5.ps1') | Select-String 'MAL|todo correcto'
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

Titulo "2n8. Los avisos por su cuenta: que sepa CALLARSE"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-entorno.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n7. El correo por voz (y que NUNCA envie sin un si)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-correo.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n6. El perfil solo guarda lo que braya dice de si mismo"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-perfil.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n5. Cambiar un modo hablando ('en modo juego no abras discord')"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-modo-voz.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n4. Instalar un juego (a su ficha de la tienda, o decir que ya lo tienes)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-instalar.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n3. El video numero N de YouTube ('reproduce el segundo')"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-youtube.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n2. El plan de ordenes locales antes de llamar al agente"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-plan.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n1. La segunda opinion de la nube (cuando vale y cuando no)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-nube.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2z. La traduccion no da la vuelta a lo pedido ni inventa un juego"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-traduccion.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2y. Las quejas rehacen la orden ('no te pedi la hora, dije cierra steam')"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-correccion.ps1') | Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2x. La frase de ejemplo recitada no es una orden (y lo mal oido no se aprende)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-recitado.ps1') | Select-String 'todo correcto|MAL'
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

Titulo "2n9. Que juego te abre (titulos parecidos y palabras sueltas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-titulos.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n10. Que HIZO Nova con lo que oyo (para poder medir los aciertos)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-destino-uso.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n11. Cuando braya dice que estuvo mal (el dato que no interpreta nadie)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-fallo-uso.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n12. Que quien crea una accion y quien la ejecuta hablen del mismo campo"
python (Join-Path $PSScriptRoot 'probar-acciones.py') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n13. Nova se revisa a si misma (y NO apaga lo que si le sirve)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-revision-propia.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n14. Un config.json mal escrito no puede matar el arranque"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-config.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n15. Que el pronombre no tape otra orden (ponla siempre encima)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-pronombres.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n16. Que el texto de la capsula no se parta a mitad de palabra"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-texto-capsula.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n17. Que la cache de voz se pode con Nova encendida (y no delante de la voz)"
python (Join-Path $PSScriptRoot 'probar-cache-voz.py') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n18. Que el modo invitado no aprenda nada de quien no eres tu"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-invitado.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "3. Ordenes que SI deben reconocerse"
foreach ($banco in @('ordenes-que-funcionaban.txt', 'casos-nuevos.txt')) {
    $salida = powershell -NoProfile -File 'assistant.ps1' -Probar (Join-Path 'pruebas' $banco) 2>&1
    $linea = @($salida | Select-String 'reconocidas en local')[-1]
    Write-Host ("   {0,-32} {1}" -f $banco, $linea)
    # LA CIFRA IMPORTA, NO QUE LA LINEA EXISTA (17/09). Esto solo miraba que la linea
    # estuviera ahi, asi que una caida de 88 a 5 pasaba EN VERDE: justo lo que este banco
    # existe para evitar. Las que fallan son controles a proposito, por eso el listero es
    # un minimo y no una igualdad: lo que no puede es BAJAR.
    $minimo = if ($banco -eq 'ordenes-que-funcionaban.txt') { 88 } else { 183 }
    $n = -1
    if ($linea -and ("$linea" -match 'reconocidas en local:\s*(\d+)')) { $n = [int]$Matches[1] }
    if ($n -lt 0) {
        Write-Host "   MAL: no salio la linea de resultados" -ForegroundColor Red
        $fallos++
    } elseif ($n -lt $minimo) {
        Write-Host ("   MAL: han BAJADO a {0}; el minimo conocido es {1}" -f $n, $minimo) -ForegroundColor Red
        $fallos++
    }
}

Titulo "5. Tu voz de verdad (si ya grabaste las ordenes)"
# Lo unico del banco que mide el MICROFONO y no texto. Si no hay grabaciones,
# lo dice y sigue: no es un fallo, es que todavia no las has hecho.
# Whisper base y small juntos piden ~1,2 GB. Sin ellos libres, el sistema llego a
# matar el banco a medias (14/09): mejor saltarla avisando, que no es un fallo.
$libreMB = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
if ($libreMB -lt 1500) {
    Write-Host "   SALTADA: solo $libreMB MB de MEMORIA libres (hacen falta 1500; no es el disco). Cierra algo y repitela sola: python tools/probar-audio.py" -ForegroundColor Yellow
} else {
    python (Join-Path $PSScriptRoot 'probar-audio.py')
    if ($LASTEXITCODE -ne 0) { $fallos++ }
}

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
