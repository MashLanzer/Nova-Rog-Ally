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
# SECCIONES QUE NO SE EJECUTAN (19/09, B11): la 5 (tu voz de verdad) se salta sola
# cuando no hay 1500 MB de RAM libres, y hasta hoy desaparecia sin rastro: el banco
# acababa en "todo en orden" aunque lo UNICO que mide el microfono no se hubiera
# ejecutado. Saltar no es fallar, asi que se apuntan aparte de $fallos, pero se
# dicen por su nombre al final para que nadie lea un verde que no es entero.
$secSaltadas = @()
# AVISOS EN AMARILLO (19/09, H2m3): ni verde ni rojo. Son cosas que el banco NO puede
# comprobar por si mismo -como que el codigo nuevo se haya usado de verdad- y que si se
# dijeran en rojo molestarian en pleno desarrollo. Se juntan aqui para que el veredicto
# final no diga un verde entero cuando no lo es.
$avisosAmarillos = @()

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

Titulo "2n7b. El correo de la manana (que no congele el bucle ni cuente de mas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-correo-manana.ps1') | Select-String 'MAL|todo correcto'
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

Titulo "2n32. Que el log se pueda leer entero (y no se pise el historico)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-log.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n31. Que un 'ok' suelto no sea ruido (y no se trague un si)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-asentimiento.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n33. 'No estaba hablando contigo' se calla, y un 'si' suelto no va a la API"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-no-era-contigo.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n30. Que te salude al volver a la consola (y que sepa callarse)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-vuelta.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n29. Los umbrales de las decisiones viven en un solo sitio"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-umbrales.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n28. Que compruebe si la app que mando abrir se abrio"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-apertura.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n27. Que compruebe si la orden surtio efecto (y no presuma)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-efecto.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n26. Cuenta tambien lo que NO puede decidir por falta de datos"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-sin-datos.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n25. A que porcentaje enchufas el cargador (el otro medidor que faltaba)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-cargador.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n24. Cuanto tardas en soltar el boton (el medidor que faltaba)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-toque-corto.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n23. La sonda de carga es barata (y se apaga sola si no lo es)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-carga-cpu.ps1') | Select-String 'todo correcto|MAL'
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

Titulo "2n19. Que un no no dure para siempre (y que un si si)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-propuestas.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n20. Que un modelo no se cargue si no cabe en la RAM"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ram-modelos.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n21. Que Nova diga si arranco a medias"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-arranque.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n22. Que Nova se incluya en su parte semanal"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-parte-semanal.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n24. Que la charla y la traduccion no se pasen la misma frase sin parar"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-rebote.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n37. Olvidar lo de hace un rato, en los seis sitios donde queda rastro"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-olvido.ps1') | Select-String 'no toca lo de antes|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n34. El OCR lee un codigo de la pantalla y acaba en la nota"
# ENTRA EN EL BANCO EL 19/09 (B12): la prueba estaba escrita desde hace dias y no la
# corria nadie. Cabe aqui porque NO necesita microfono, ni Nova encendida, ni cargar
# modelos de voz: pinta ella misma una imagen con un codigo, la lee el OCR de Windows
# y comprueba que la nota acaba en un diario de mentira ($env:TEMP), no en el tuyo.
# Si algun dia falla por el motor, lo dice claro: "no hay motor de OCR" = falta el
# idioma en Windows, no es una regresion de Nova.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ocr.ps1') | Select-String 'correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n27. Que Nova avise si lleva dias sin apuntar ni una orden (sin uso no se decide nada)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-sin-uso.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n35. El contador de la meta (como me has entendido hoy)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-meta.ps1') | Select-String 'todo correcto|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n36. La copia que te salva (que se pueda abrir, que rote y que falle bien)"
# ENTRA EN EL BANCO EL 19/09 (B13 = MEJORAS.md 3.4 #8): New-CopiaSeguridad existe desde el
# 13/09 y no la tocaba ninguna prueba. Cabe aqui porque NO necesita microfono, ni Nova
# encendida, ni cargar modelos: monta un voice-ctrl de mentira en $env:TEMP y cambia
# $env:OneDrive para no rotar el tuyo. Tarda ~7 s.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-copia.ps1') | Select-String 'todo correcto|MAL'
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
    $minimo = if ($banco -eq 'ordenes-que-funcionaban.txt') { 88 } else { 228 }   # 228 desde el 20/09 tarde: MEDIDO (226 + 2 saltadas). +7 de "olvida los ultimos X minutos". Antes 221, 218, 210, 202, 190, 188
    $n = -1
    if ($linea -and ("$linea" -match 'reconocidas en local:\s*(\d+)')) { $n = [int]$Matches[1] }
    # LOS JUEGOS QUE YA NO TIENES NO SON UNA REGRESION (19/09): las lineas con
    # '@si-tienes:<juego>' se saltan cuando ese juego no esta instalado, asi que cuentan
    # como buenas para el minimo. Si se reinstala, vuelven a probarse de verdad.
    $salt = 0
    $lsalt = @($salida | Select-String 'saltadas por juegos que ya no tienes')[-1]
    if ($lsalt -and ("$lsalt" -match ':\s*(\d+)')) { $salt = [int]$Matches[1] }
    if ($salt -gt 0) { Write-Host ("   ({0} saltadas: juegos que ya no tienes instalados)" -f $salt) -ForegroundColor DarkGray }
    if ($n -ge 0) { $n += $salt }
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
    $secSaltadas += "5. Tu voz de verdad (solo $libreMB MB libres, hacen falta 1500) -> python tools/probar-audio.py"
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

Titulo "6. Codigo del oido cambiado y ni una voz encima (AMARILLO, no fallo)"
# CODIGO NUEVO Y CERO VOZ (19/09, H2m3). Este banco es TEXTO: pasarlo entero en verde no
# dice nada sobre si Nova te entiende cuando hablas. Hoy 19/09 ha pasado justo eso: el
# oido reescrito durante todo el dia y la ultima orden real de las 11:16, asi que las 251
# veces que se puso verde no median el cambio que se acababa de hacer. Desde el 15/09 aqui
# no se decide nada sin uso real (memoria: 'medir con uso real'), y un banco que no avisa
# de eso deja creer que si.
#
# EN AMARILLO Y NO EN ROJO, y lo pedia ya la nota: en pleno desarrollo se tocan estos dos
# ficheros veinte veces seguidas sin hablarle, y un rojo ahi se aprende a ignorar -que es
# la unica forma de matar un aviso-. No suma a $fallos ni cambia el codigo de salida.
#
# SOLO assistant.ps1 Y wake_vosk.py: son los dos que estan en el camino de la voz, desde
# que el microfono oye hasta que se hace la orden. Tocar una prueba o un analizador no
# cambia lo que Nova entiende, y avisar por eso seria ruido.
#
# LA FECHA DEL FICHERO, no la del commit: lo que corre es el archivo del disco, y entre
# editarlo y commitearlo pueden pasar horas en las que el banco ya se esta pasando. El
# precio es que un 'git clone' recien hecho pone la fecha de hoy a todo y esto avisaria
# una vez; se calla en cuanto le hables.
$fUso = Join-Path $raiz 'pruebas\audio\uso\destinos.jsonl'
$ultimaVoz = $null
if (Test-Path -LiteralPath $fUso) {
    # la hora se saca de DENTRO del JSON y mirando hacia atras, igual que Get-AvisoSinUso
    # en assistant.ps1: la fecha del fichero la mueve una copia o un git, y la ultima linea
    # puede estar partida si Nova se apago justo mientras la escribia.
    $colaU = @(Get-Content -LiteralPath $fUso -Tail 5 -ErrorAction SilentlyContinue)
    for ($iU = $colaU.Count - 1; $iU -ge 0; $iU--) {
        if (([string]$colaU[$iU]) -match '"hora"\s*:\s*"([^"]+)"') {
            $dU = [datetime]::MinValue
            if ([datetime]::TryParse($Matches[1], [ref]$dU)) { $ultimaVoz = $dU; break }
        }
    }
}
if (-not $ultimaVoz) {
    # sin fichero o sin ninguna hora legible no hay con que comparar: instalacion nueva.
    # Que lleve dias sin uso ya lo dice Nova sola (Get-AvisoSinUso); aqui no se repite.
    Write-Host "   (todavia no hay ni una orden apuntada: nada que comparar)" -ForegroundColor DarkGray
} else {
    $nuevos = @()
    foreach ($nF in @('assistant.ps1', 'wake_vosk.py')) {
        $rF = Join-Path $raiz $nF
        if (-not (Test-Path -LiteralPath $rF)) { continue }
        $mF = (Get-Item -LiteralPath $rF).LastWriteTime
        if ($mF -gt $ultimaVoz) {
            $nuevos += ('{0} tocado el {1}, {2:n1} h despues de la ultima orden' -f $nF, $mF.ToString('dd/MM HH:mm'), ($mF - $ultimaVoz).TotalHours)
        }
    }
    if ($nuevos.Count -eq 0) {
        Write-Host ('   OK  la ultima orden real ({0}) es posterior al codigo del oido' -f $ultimaVoz.ToString('dd/MM HH:mm')) -ForegroundColor DarkGray
    } else {
        Write-Host ('   AMARILLO: el oido cambio DESPUES de la ultima orden real ({0})' -f $ultimaVoz.ToString('dd/MM HH:mm')) -ForegroundColor Yellow
        foreach ($nU in $nuevos) { Write-Host "      - $nU" -ForegroundColor Yellow }
        Write-Host '      Este banco es texto: que pase en verde no dice si te entiende. Hablale un rato y vuelve.' -ForegroundColor Yellow
        $avisosAmarillos += ('codigo del oido cambiado y sin voz encima: ' + ($nuevos -join ' / '))
    }
}

# LOS TRES QUE SE QUEDAN FUERA A PROPOSITO (19/09, B12). Este banco existe para pasarlo
# despues de CADA cambio sin microfono y sin arrancar nada; estas tres no caben ahi, y
# hasta hoy quedaban fuera sin que nadie dijera por que. Ojo: dos son .py, no .ps1.
#
#   tools\probar-vivo.ps1        ARRANCA NOVA DE VERDAD: exige que este APAGADA, pide
#                                2000 MB libres, tarda minutos, habla en voz alta y toca
#                                memoria\ y config.json (los copia y los devuelve, pero si
#                                la matan a medias hay que llamarla con -Restaurar).
#                                Es la UNICA que prueba el bucle principal: pasala a mano
#                                antes de dar por buena una sesion, no en cada cambio.
#   tools\probar-precarga.py     Carga el modelo local DOS veces (~1,9 GB y ~40 s) para
#                                medir el frio contra la precarga. Solo al tocar
#                                charla_worker.py, y con la maquina libre.
#   tools\probar-voz-windows.py  INTERACTIVA: te pide hablar por el microfono cinco veces
#                                seguidas. Sirve para decidir si el dictado de Windows oye
#                                este microfono, no para vigilar regresiones.

Write-Host ""
Pop-Location
if ($secSaltadas.Count -gt 0) {
    # B11 (19/09): las secciones que NO se han ejecutado, por su nombre y antes del
    # veredicto. Antes desaparecian y el verde final mentia por omision.
    Write-Host ("$($secSaltadas.Count) seccion(es) SALTADA(S), no se han ejecutado:") -ForegroundColor Yellow
    foreach ($sec in $secSaltadas) { Write-Host "   - $sec" -ForegroundColor Yellow }
}
if ($avisosAmarillos.Count -gt 0) {
    Write-Host ("$($avisosAmarillos.Count) aviso(s) en AMARILLO (no son fallos, pero el verde no es entero):") -ForegroundColor Yellow
    foreach ($avA in $avisosAmarillos) { Write-Host "   - $avA" -ForegroundColor Yellow }
}
if ($fallos -gt 0) { Write-Host "$fallos comprobaciones con problemas" -ForegroundColor Red; exit 1 }
# UN SOLO 'PERO' (19/09, H2m3): antes solo contaba las saltadas, y ahora puede haber dos
# motivos a la vez. Se conserva el texto "todo en orden" porque tmp\cerrar-ronda*.ps1 lo
# busca tal cual, y se sigue saliendo con 0: un amarillo no rompe la ronda.
$peros = @()
if ($secSaltadas.Count -gt 0) { $peros += "$($secSaltadas.Count) seccion(es) SALTADA(S)" }
if ($avisosAmarillos.Count -gt 0) { $peros += "$($avisosAmarillos.Count) aviso(s) en AMARILLO" }
if ($peros.Count -gt 0) {
    Write-Host ("todo en orden, PERO con " + ($peros -join ' y ') + " (arriba)") -ForegroundColor Yellow
    exit 0
}
Write-Host "todo en orden" -ForegroundColor Green
