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

# EL BANCO SE TRAGABA SUS PROPIOS ERRORES (22/09, idea 8). Aqui habia 104 subidas de
# $fallos y 98 eran la MISMA linea muda -if ($LASTEXITCODE -ne 0) { $fallos++ }-, sin un
# solo mensaje y sin guardar de que seccion venian. Encima 95 de esas 98 filtran su salida
# con Select-String, asi que un banco que muere por una excepcion no imprime NADA. El
# veredicto solo podia decir "3 comprobaciones con problemas" y tocaba reejecutar secciones
# a ciegas -hasta 104- para saber cuales eran.
#
# COMO SE APUNTA EL NOMBRE SIN TOCAR LAS 98 LINEAS: cada seccion empieza SIEMPRE llamando a
# Titulo, y sus $fallos++ vienen despues, asi que la propia Titulo puede mirar si el contador
# subio durante la seccion ANTERIOR y apuntarla por su nombre. Asi cuentan las 104 subidas y
# no solo las 98 mudas -entran tambien la 3, la 4, la 7 y la 8, que si tienen mensaje pero
# tampoco decian su nombre al final-, y vale para la seccion que alguien anada manana sin
# acordarse de esto. La ultima seccion no tiene detras otro Titulo: la cierra el veredicto.
$secFallidas = @()
$script:tituloActual = ''
$script:fallosAlEmpezar = 0

function Titulo($t) {
    if ($script:tituloActual -and $script:fallos -gt $script:fallosAlEmpezar) { $script:secFallidas += $script:tituloActual }
    $script:tituloActual = $t
    $script:fallosAlEmpezar = $script:fallos
    Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan
}

Titulo "1. Patrones (todos deben compilar)"
# Tambien las herramientas: un CR suelto colado en una ruta dentro de una
# prueba hizo que la comprobacion mas importante del oido fino midiera 0 casos
# y dijera "OK" igual. Las pruebas tambien se rompen en silencio.
$aRevisar = @('assistant.ps1') + @(Get-ChildItem -Path $PSScriptRoot -Filter 'probar-*.ps1' | ForEach-Object { $_.FullName })
# LOS ERRORES QUE NADIE VEIA (20/09). Un banco que llama a una funcion que no ha
# extraido suelta CommandNotFoundException por la SALIDA DE ERROR y sigue diciendo
# "todo correcto", porque solo se mira su codigo de salida. Paso cinco veces en dos
# dias: probar-costumbres con Test-ApiContestaPrimero (un dia entero en verde sin
# probar nada), probar-plan con Set-UltimaOrden, probar-olvido, probar-json-ui con
# Get-TextoCapsula (16 errores por pasada) y probar-funciones5 con Send-AvisoEntorno.
# Aqui se recoge esa salida de todos y se mira al final, en la seccion 7.
$script:errBanco = Join-Path $env:TEMP ("banco-err-" + [guid]::NewGuid().ToString("N") + ".txt")
New-Item -ItemType File -Path $script:errBanco -Force | Out-Null

powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-regex.ps1') -Archivos $aRevisar
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2. Funciones sueltas, sacadas del archivo real"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-funciones.ps1')
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2c. El JSON de la capsula (campos del oido y del plazo)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-json-ui.ps1')  2>>$script:errBanco| Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2l. El parte general (que diga lo que hay y calle lo que no aporta)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-parte.ps1')  2>>$script:errBanco| Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2m. Que solo te obedezca a ti (a quien se pregunta y a quien no)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-voz-dueno.ps1')  2>>$script:errBanco| Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n. A donde va cada frase (colisiones entre ordenes parecidas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-destinos.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2o. Avisos sin voz (cuando hablar y cuando solo verse)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-avisos.ps1')  2>>$script:errBanco| Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2p. Listas (se llenan, se leen, se tachan y se vacian)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-listas.ps1')  2>>$script:errBanco| Select-String 'OK |MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2q. Autoaprendizaje (recetas, variantes, perfil, cuanto has aprendido)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-recetas.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2r. Cada juego (donde te quedaste, cuanto gasta de bateria)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-juegos.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2s. Costumbres (notificaciones jugando, proponer automatizar habitos)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-costumbres.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2t. Conversacion (frases, marcas [ORDEN]/[API], API primero y el local de respaldo)"
python (Join-Path $PSScriptRoot 'probar-charla.py')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2u. Cerebro propio (aprende sin quedarse con datos malos, busca por palabras y significado)"
python (Join-Path $PSScriptRoot 'probar-memoria.py')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2w. Escucha sin microfono (cuando se da por terminada la frase)"
python (Join-Path $PSScriptRoot 'probar-escucha.py')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2v. Quinta tanda (despertador, dormir, limite de juego, musica, clip, descargas, dock y cascos)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-funciones5.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2d. La tarjeta de respuestas largas (que no te saque del juego)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-tarjeta.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2e. Siempre encima (sobre una ventana de mentira, sin robar el foco)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ventana.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2f. Modos por voz (crear, sustituir y borrar en commands.json)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-modos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2g. Reglas atadas a una descarga de Steam"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-descargas.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2h. Frases que ya te molestaron una vez (y que se curan solas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-rechazos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n8. Los avisos por su cuenta: que sepa CALLARSE"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-entorno.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n7. El correo por voz (y que NUNCA envie sin un si)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-correo.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n7b. El correo de la manana (que no congele el bucle ni cuente de mas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-correo-manana.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n6. El perfil solo guarda lo que braya dice de si mismo"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-perfil.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n70. Y no tira lo que repite ni lo que enseno a mano"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-poda-perfil.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:no tira lo que)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n71. El estilo deja de contradecirse a si mismo"
python (Join-Path $PSScriptRoot 'probar-poda-estilo.py')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:ya no se contradice)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n5. Cambiar un modo hablando ('en modo juego no abras discord')"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-modo-voz.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n4. Instalar un juego (a su ficha de la tienda, o decir que ya lo tienes)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-instalar.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n3. El video numero N de YouTube ('reproduce el segundo')"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-youtube.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n2. El plan de ordenes locales antes de llamar al agente"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-plan.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n1. La segunda opinion de la nube (cuando vale y cuando no)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-nube.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2z. La traduccion no da la vuelta a lo pedido ni inventa un juego"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-traduccion.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2y. Las quejas rehacen la orden ('no te pedi la hora, dije cierra steam')"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-correccion.ps1')  2>>$script:errBanco| Select-String 'MAL|todo correcto'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2x. La frase de ejemplo recitada no es una orden (y lo mal oido no se aprende)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-recitado.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n32. Que el log se pueda leer entero (y no se pise el historico)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-log.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n31. Que un 'ok' suelto no sea ruido (y no se trague un si)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-asentimiento.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n33. 'No estaba hablando contigo' se calla, y un 'si' suelto no va a la API"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-no-era-contigo.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n30. Que te salude al volver a la consola (y que sepa callarse)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-vuelta.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n29. Los umbrales de las decisiones viven en un solo sitio"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-umbrales.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n28. Que compruebe si la app que mando abrir se abrio"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-apertura.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n27. Que compruebe si la orden surtio efecto (y no presuma)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-efecto.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n26. Cuenta tambien lo que NO puede decidir por falta de datos"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-sin-datos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n25. A que porcentaje enchufas el cargador (el otro medidor que faltaba)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-cargador.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n24. Cuanto tardas en soltar el boton (el medidor que faltaba)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-toque-corto.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n23. La sonda de carga es barata (y se apaga sola si no lo es)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-carga-cpu.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2i. Deshacer por ventana de tiempo (la foto mas vieja, no la ultima)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-deshacer.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2j. Guardar la esquina sin romper config.json"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-esquina.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2k. Los tres sonidos propios (y que sin ellos no se quede mudo)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-sonidos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n69. El mp3 abierto antes de hablar (y que la sordina NO se mueva)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-voz-adelantada.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2b. Autosordina (se calla sola si el microfono caza ruido en racha)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-autosordina.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n9. Que juego te abre (titulos parecidos y palabras sueltas)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-titulos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n10. Que HIZO Nova con lo que oyo (para poder medir los aciertos)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-destino-uso.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n11. Cuando braya dice que estuvo mal (el dato que no interpreta nadie)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-fallo-uso.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n12. Que quien crea una accion y quien la ejecuta hablen del mismo campo"
python (Join-Path $PSScriptRoot 'probar-acciones.py')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n13. Nova se revisa a si misma (y NO apaga lo que si le sirve)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-revision-propia.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n14. Un config.json mal escrito no puede matar el arranque"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-config.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n15. Que el pronombre no tape otra orden (ponla siempre encima)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-pronombres.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n16. Que el texto de la capsula no se parta a mitad de palabra"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-texto-capsula.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n17. Que la cache de voz se pode con Nova encendida (y no delante de la voz)"
python (Join-Path $PSScriptRoot 'probar-cache-voz.py')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n18. Que el modo invitado no aprenda nada de quien no eres tu"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-invitado.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n19. Que un no no dure para siempre (y que un si si)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-propuestas.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n20. Que un modelo no se cargue si no cabe en la RAM"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ram-modelos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n21. Que Nova diga si arranco a medias"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-arranque.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n22. Que Nova se incluya en su parte semanal"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-parte-semanal.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n74. Que la charla y la traduccion no se pasen la misma frase sin parar"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-rebote.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n42. El diario dice de donde viene cada linea (y el resumen solo usa lo real)"
python (Join-Path $PSScriptRoot 'probar-diario-origen.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:solo usa lo real)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n44. Que Nova ajuste sola lo que espera a la nube (C9)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-nube-tope.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:con suelo, techo y vuelta atras)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n72. La barra de espera (que el numero se lo mida ella, con suelo y techo)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-barra-espera.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se lo mide ella)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n41. Cuanto tarda la nube (el dato que le faltaba a C9)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-nube-tiempo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no se inventan un p90)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n40. El disco solo se abre para tu voz y para lo que fue una orden"
python (Join-Path $PSScriptRoot 'probar-grabar-uso.py')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:orden de verdad)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n38. La memoria entre ordenes, y lo que sonaba antes de llamarla"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-contexto.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:el ambiente va aparte)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n37. Olvidar lo de hace un rato, en los ocho sitios donde queda rastro"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-olvido.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:no toca lo de antes)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n34. El OCR lee un codigo de la pantalla y acaba en la nota"
# ENTRA EN EL BANCO EL 19/09 (B12): la prueba estaba escrita desde hace dias y no la
# corria nadie. Cabe aqui porque NO necesita microfono, ni Nova encendida, ni cargar
# modelos de voz: pinta ella misma una imagen con un codigo, la lee el OCR de Windows
# y comprueba que la nota acaba en un diario de mentira ($env:TEMP), no en el tuyo.
# Si algun dia falla por el motor, lo dice claro: "no hay motor de OCR" = falta el
# idioma en Windows, no es una regresion de Nova.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ocr.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n43. Leer SOLO una zona de la pantalla (la esquina del objetivo, el centro)"
# C15 (20/09). Tampoco necesita microfono ni Nova encendida: pinta un HUD de mentira,
# recorta con la misma funcion que usa Save-Captura y comprueba que cada frase acaba
# en SU zona. Lo segundo importa mas que lo primero: el banco de frases solo mira que
# algo se reconozca, asi que leer la esquina contraria le pasaria en verde.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ocr-zona.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n46. Abrir un juego que no es de Steam (y que siga estando vigilado)"
# D1, 2a parte (21/09). La biblioteca ERA Steam: lo que no tuviera appmanifest no
# existia, y braya no podia ni abrir Roblox. Lo que mas se prueba aqui es que abrir un
# juego siga siendo una orden vigilada: esa vigilancia colgaba de un -match contra
# steam://rungameid, asi que un juego de fuera se habria abierto de golpe y sin deshacer.
# De aqui salio tambien lo de la microSD que no esta puesta.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-juegos-xbox.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sigue estando vigilado)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n54. La cascada del repaso: Canary antes que Whisper, y sin tocar Parakeet"
# 21/09. Cuando Parakeet no saca una orden se llamaba SIEMPRE a Whisper. Medido con las
# 214 grabaciones suyas: anadir Canary da +23 ordenes bien resueltas (96 -> 119 de 181) y
# ademas es MAS RAPIDO que lo que se usaba (793 ms contra 3425 de whisper base).
# Lo que mas se prueba aqui no es que Canary funcione: es que si NO esta descargado, o si
# falla, todo siga exactamente como antes. Un oido roto es peor que un oido que no mejora.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-cascada-repaso.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sin Canary todo sigue como antes)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n68. No repasar lo que ya se va a tirar"
# 22/09. 328 peticiones de repaso en el log y 227 acaban en 'Whisper no saca una orden: sigo
# con lo de Parakeet'. El corte -espanol largo Y mas de 8 palabras- coge 148 de esas 328,
# que son 474,3 s de reloj y 432,1 s de audio tirado con Nova sorda. Cero ordenes perdidas.
# La mitad del arreglo es cerrar detras el pestillo del oido fino: sin el, la frase cae tres
# lineas mas abajo en small y se vuelve a preguntar lo que se acaba de decidir no preguntar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-repaso-ahorrado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se iba a tirar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n67. El oido se calienta solo al arrancar (idea 3)"
# 22/09. De 139 s de oido en una sesion de 12 minutos, 31 (el 22 %) fue SOLO cargar modelos,
# y la primera orden del arranque se come los 5,2 s de Parakeet ella sola. Nova arranco
# CATORCE veces ese dia: no es un caso raro, es el de todos los dias.
# Lo que se prueba es EL CERROJO, que es lo unico que puede salir caro: con un hilo que
# precarga, el de precarga y el del microfono pueden entrar a la vez y cargar DOS modelos de
# 703 MB. Se prueba con hilos de verdad, que una condicion de carrera no se ve leyendo.
python (Join-Path $PSScriptRoot 'probar-precarga-oido.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no paga la carga)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n66. Una transcripcion no puede eternizarse (idea 4)"
# 22/09. Medido sobre las 812 transcripciones del log: 2,3 s de mediana, 15,1 el p90... y
# 238,9 la peor, con el audio limitado a 15 s. Eso no es audio largo, es la maquina ahogada.
# Y pasado cierto punto el trabajo no le sirve a nadie: el asistente deja de esperar el repaso
# a los 15 s, asi que lo que llegue despues se tira, pero mientras tanto el hilo esta sordo.
# Con 30 s se corta el 4,1 % y se ahorran 838 s, y es el doble del p90. El banco ejecuta la
# funcion de verdad con un modelo que entrega los segmentos despacio: lo que importa es que
# al cortar DEVUELVA lo que ya tiene, y eso no se ve mirando el fuente.
python (Join-Path $PSScriptRoot 'probar-tope-reloj.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no puede eternizarse)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n73. Y la pregunta que la dejaba entrar ya no interrumpe"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-alias-apagado.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:ya no interrumpe)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n65. Una orden mal oida no envenena el vocabulario"
# 22/09. La cadena entera: el liston de letras roto hizo que Whisper devolviera 'Si es a los
# ajutos' donde braya dijo 'cierra los ajustes'; eso se aprendio, y Add-Alias-Comando metio
# ademas  'ajutos': ''  en la lista de SITIOS WEB de commands.json, porque su else guardaba
# $d.url tuviera valor o no. Desde entonces 'busca gatos en otra pestana' se resolvia como
# 'abrir ajutos' -abrir una direccion vacia-, y lo cazo el banco de destinos. Una sola orden
# mal oida envenenando el vocabulario para siempre es justo lo peor que puede pasar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-alias-vacio.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no envenena el vocabulario)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n106. Elegir con el mando"
# Funcion 10, y el numero que la pide es redondo: en catorce dias el mando se uso para
# contestar una pregunta CERO veces. No por falta de preguntas (veinte, cinco muertas por
# plazo: una de cada cuatro) ni por falta de mando (es una consola de mano; XInput lo ve en el
# puerto 0 y leerlo cuesta 0,197 ms). Era invisible: Nova preguntaba y no decia en ningun
# sitio que valia un boton. Ahora lo dice, y ademas vale para listas cerradas, no solo para
# si/no. Lo que se vigila: que sin mando no cambie NADA (la voz es el camino), que A siga sin
# valer en una pregunta peligrosa, y que el modo tenga sus tres salidas.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-elegir-mando.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sin mando todo sigue igual)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n105. A que podemos jugar los dos"
# Funcion 9. De sus doce juegos instalados OCHO son de dos, y tres -A Way Out, The Past
# Within y Content Warning- NO SE PUEDEN JUGAR SOLO. Ademas juega a Roblox con su novia. El
# dato sale de la ficha publica de la tienda de Steam (sin clave), se guarda y no se vuelve a
# pedir; el relleno va de una en una desde Watch-Entorno. Lo que se vigila: que no se mezcle
# "juntos" con "uno contra otro", que se diga si es a pantalla partida AQUI (una sola
# pantalla) o hace falta otro aparato, y que la frase que Nova ensena para apuntar un juego
# que no esta en Steam case de verdad con el patron de apuntar y no con el de preguntar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-juegos-dos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:de donde lo ha sacado)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n121. De que va este juego (y que hacer aqui, que es otra cosa)"
# Idea 6, partida en dos porque son dos preguntas y solo una tiene respuesta en una
# enciclopedia. Su frase y su fallo estan fechados en el propio codigo, 15/09: jugando a It
# Takes Two, "busca informacion sobre el juego que esta en pantalla" buscaba esa frase tal
# cual en Google y abria el navegador ENCIMA de la partida, y esa ventana dura HORAS (5 h 38
# el 15/09). Lo que mas se vigila: que no se invente de que va un juego. Comprobado contra la
# Wikipedia, buscar "It Takes Two" a secas devuelve la PELICULA de 1995 y el titulo coincide
# EXACTO, asi que la comprobacion de titulo sola no la caza: por eso se busca "<juego>
# videojuego" y ademas se exige que el articulo hable de un juego.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-guia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya te dice de que va)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n122. La trivia, con preguntas de verdad, el mando y un marcador"
# Idea 8. El dato que manda esta en el registro: el 13/09 a las 20:46:00 braya pregunto "que
# es un volcan" y a las 20:48:52 -DOS MINUTOS Y 52 SEGUNDOS despues- la trivia le pregunto a
# EL "que es un volcan"; contesto "no se, me rindo". Y "CHARLA (trivia)" sale UNA vez en las
# 49.492 lineas del registro: ese dia, y nunca mas. El mando se uso para contestar CERO veces
# en catorce dias. Lo que mas se vigila: que las tres opciones se barajen -un modelo de 3B
# pone la buena la primera casi siempre, y entonces "la primera" acierta sin saber nada- y que
# del modo se pueda salir por las tres puertas, la B del mando incluida.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-trivia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya pregunta de verdad)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n123. El modo de dos jugadores: ya existe, y la frase que lo pone"
# Idea 17, que era "NO se hace": un modo propio para las sesiones de dos seria un cuarto sitio
# donde se guardan listas de ordenes con nombre, teniendo ya perfiles, montajes y recetas. Lo
# que le falta a braya no es codigo, es la frase. Pero verificarlo encontro dos cosas de
# verdad: Add-Perfil era LA UNICA funcion que escribe memoria sin la guarda del modo invitado
# -y el invitado se propone justo cuando Nova no reconoce la voz, o sea, cuando la novia esta
# delante-, y un modo de DOS palabras se podia poner pero no crear ("crea el modo estamos dos:
# ..." guardaba un modo llamado "estamos"). Lo que mas se vigila: la salida. Ocho de sus doce
# juegos son de dos y la sesion mas larga medida son 6 h 14, asi que este es el candidato
# perfecto a quedarse puesto.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-modo-dos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el modo de dos ya existe)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n124. Avisar cuando se conecte alguien en Steam"
# Idea 10. Lo primero, y no se puede tapar: config.json NO tiene steam.apiKey, y en 14 dias
# Get-AmigosSteam no ha devuelto un solo amigo -braya lo pidio el 14/09 a las 00:15:50, Nova
# le contesto que necesitaba la clave, y sigue sin ponerla-. Por eso la comprobacion 10 es que
# SIN CLAVE no se arma nada y no sale una sola peticion. Lo que mas se vigila: que sin nada
# que vigilar no se llame a Steam -eso seria red en el bucle mientras juega-, que el aviso vaya
# por FLANCO y no por ESTADO -el de bateria llena se hizo por estado y dejo 19 avisos
# identicos, cuatro al dia, los quince ultimos sin que pasara nada-, y que el plazo sobreviva
# al reinicio, que son 211 arranques en 14 dias.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-amigos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:avisa una vez, por flanco)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n125. Decir que esta sorda, en vez de anunciar que escucha"
# Idea 18 de la tanda del 24/09. Medido sobre los 235 arranques del oido del registro: de
# "escucha continua ACTIVA ... di 'nova'" a "worker Vosk en marcha" -que es cuando vuelve a oir
# de verdad- pasan 6 s de mediana y 12 s en el p90, pero el p99 son 303 s y el maximo 1.716 s:
# veintiocho minutos y medio diciendo que escucha sin oir nada. Y tras las seis muertes del
# microfono los huecos fueron 19 s, 45 s, 5 min 49, 12 min 42 y 35 min 14.
# Lo que mas se vigila: que NO avise en un arranque normal. Son unos 16 arranques del oido al
# dia; con el liston mas bajo, Nova diria dieciseis veces al dia que esta sorda cuando solo
# estaba arrancando, que es el fallo de los 25 avisos identicos del 22/09 con otra ropa.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-oido-mudo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no dice que escucha mientras esta sorda)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n126. Las interrupciones que se tiraban dentro de casa"
# Idea 2 de la tanda del 24/09. El oido escribio 15 corte.flag en quince dias y el asistente
# atendio 10. Las otras cinco NO se perdieron por el oido -acerto las quince- sino en el
# bloque del bucle: cuatro con un dictado abierto (el 20/09 hubo dos dictados colgados de 48
# segundos con "para", "nova" y "basta" dichos DENTRO, y el bloque tenia dos ramas para tres
# situaciones) y una por pausa vencida. Ninguna dejo una sola linea en el registro, y por eso
# tardo quince dias en verse.
# Lo que mas se vigila: que las SEIS situaciones tengan rama, y que cada una deje un contador.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-corte-perdido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no se tira una interrupcion)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n127. Lo que dura un rato no es un dato, y la poda deja lapida"
# Ideas 12 y 20 de la tanda del 24/09. De los 60 datos de memoria\perfil.md, VEINTITRES (el
# 38 %) no son rasgos de braya sino estados de un rato: "esta en una llamada", "vio una casa
# con fuego", "tiene 8 dolares", "usa espadas de metal en el juego". Y el perfil VIAJA CON
# CADA peticion al modelo, asi que cada uno es ruido en todas las respuestas. El peor tiene
# hora: 23/09 21:16:33, "esta en una llamada", guardado como rasgo; esa misma noche Nova dijo
# "te dejo tranquilo" y en la hora siguiente metio diez frases mas en la charla.
# Y la otra mitad: al llenarse (60), la poda tiraba uno SIN DECIR CUAL, y se llevo por delante
# los DOS unicos datos que braya enseno a mano con "aprende que...".
# Lo que mas se vigila: los falsos positivos. La lista es CERRADA -igual que Test-DatoTrato- y
# la salvaguarda manda: si la frase dice "siempre", "suele" o "favorito", es un rasgo aunque
# hable de algo que pasa. Medido sobre los 60 reales: caza 20 de 21 y ni un falso positivo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-poda-perfil.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el perfil ya no tira lo que braya repite)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n128. Te llamaste tres veces y no te oi"
# Idea 1 de la tanda del 24/09. 83 descartes por "suena demasiado flojo" en el registro, 57
# de ellos dentro de 19 rachas de dos o mas en 120 s. Mirado que paso DESPUES de las 19, con
# 15 minutos de ventana: CERO acabaron en la orden que pidio, 17 se quedaron en nada y DOS
# ejecutaron algo que no habia pedido -el del 22/09 a la 01:12 esta con sus propias palabras
# en el registro: "no tenias que leer la pantalla, no te pedi eso"-. O sea que no se recupera.
# Lo que mas se vigila, y es lo contrario de lo que parece: que esto NO toque ningun liston.
# De los 83 descartes, 45 pasan con los altavoces sonando (0,10 a 0,38) y una linea JUEGO al
# lado: no es braya hablando bajo, es el juego diciendo algo parecido a "nova". Subir la
# sensibilidad seria amplificar justo eso, la regla 1 al reves. Asi que solo HABLA, solo
# cuenta las rachas en silencio, y el liston de tres deja 5 avisos en 3 dias en vez de 11.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-oido-flojo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no se queda callada cuando la llamas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n129. El plazo de la voz sale de lo que tarda de verdad"
# Idea 8 de la tanda del 24/09, que cambio de forma al medirla. Decia que Say-Online bloquea
# el bucle con un Wait sincrono: son 303,2 s en quince dias, 20 s al dia, y se miraron las
# 311 ventanas de espera buscando DENTRO sucesos que significaran "el bucle tenia algo que
# hacer" -dictados, activaciones, cortes, recordatorios, descartes-: cayeron CERO de los
# 7.391 del log, porque Say llama a Pausar-Escucha ANTES que a Say-Online. Asi que la
# reescritura asincrona se descarta: su fallo tipico -"dice una frase y suena otra"- ya
# costo tres arreglos (17/09, 19/09, 21/09).
# Lo que si era un fallo: de esos 304 s, VEINTICUATRO son tres plantones de 8 s, o sea que
# tres sucesos valen el 7,9 %. Y el plazo que los produce eran dos numeros a fuego.
# Lo que mas se vigila: que el dato solo pueda BAJAR el plazo. Los ms por letra no son una
# recta -sintetizar tiene parte fija y parte variable-, asi que subirlo seria inventarse un
# numero; bajarlo no, porque ahi el peor caso es que la frase caiga a Piper, que ya pasa.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-voz-plazo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el plazo de la voz ya sale de lo que tarda)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n120. La musica: poner lo que es, y no repetir lo que no le gusta"
# Ideas 1-A y 1-B. 52 intentos con frases distintas y ninguno acabo bien. El fallo de raiz,
# medido contra youtube.com con cuatro busquedas suyas: el regex viejo devolvia 45, 71, 45 y
# 28 ids mientras los resultados DE VERDAD -los bloques videoRenderer- eran 19, 16, 19 y 28,
# y en "musica electronica" no coincidia NI EL PRIMERO: el id que se abria salia de una
# estanteria de playlist. O sea que "el tercero" nunca fue el tercero. Ahora se leen los
# bloques de verdad CON SU TITULO, se dice el titulo antes de abrir nada, "la siguiente"
# cuesta cero red, y lo que dice que no le gusta no vuelve a salir. Eso NO va al perfil: el
# perfil esta a 59 de 60 y ya rechazo diez preferencias suyas.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-musica-no.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la musica ya pone lo que es)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n119. Lo que le corriges una vez, ya no se le olvida"
# Idea 18. Cuando braya contesta "no" a "ELDEN RING?", hoy Nova solo dice "vale, lo dejo" y
# NO APRENDE NADA: el mismo titulo mal oido vuelve a fallar manana. Y Add-Traduccion guarda
# la FRASE entera, asi que aprender "abre gus gus dup" no sirve para "cierra gus gus dup".
# Lo que se ata es el SONIDO al JUEGO. El oido va al 70,4 % y lo peor son los titulos en
# ingles: Find-JuegoPorSonido rescata 12 de 34 mal oidos, y quedan 22 que hoy no se
# recuperan nunca. Lo que mas se vigila: que la clave se guarde SIN ARTICULO -con el, "el
# warning" se vuelve elguarning, que se parece MAS a eldenring, y lo aprendido abriria ELDEN
# RING teniendo Content Warning instalado, ya sin preguntar-; y que CERRAR siga preguntando
# siempre, porque ahi se mata un proceso con la partida abierta.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-juegos-oidos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que le corriges una vez)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n118. El resumen del dia cuenta el dia entero"
# Idea 19. Existia medio, y la mitad que existia estaba bien: el patron y el ejecutor ya
# estaban, y NO se dispara solo. Le faltaban cuatro cosas, las cuatro medidas: CUANTO jugo
# (It Takes Two 3 h 12 el 22/09 y 2 h 45 el 20/09, todo en juegos.json y sin decirse),
# cuantas ordenes acerto, que se descargo y cuanto disco queda. Y a Get-QueHeHecho no la
# miraba NINGUN banco. Lo que mas se vigila: que el acierto salga del MISMO Get-MetaDias que
# ya comparten analizar-uso.py y probar-meta, y no de un contador nuevo: escribir otro es
# como se llego a tener un 72 % y un 75 % del mismo dia.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-resumen-dia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el resumen del dia ya cuenta el dia entero)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n117. Contar, medir y listar sus carpetas (solo lectura)"
# Idea 9. 41 frases de este tema en catorce dias -"cuenta cuantos archivos hay en mi carpeta
# de descargas"- y hoy ninguna se entendia en local: todas al agente. Y un fallo activo:
# "cuanto ocupa mi carpeta de descargas" caia en el patron de "cuanto ocupa <juego>" y Nova
# contestaba "no tengo ese juego en la biblioteca", que no es no entender sino contestar otra
# cosa. Lo que mas se vigila: que medir una carpeta grande NO deje el juego tirando (tope de
# tiempo y de ficheros, y si se corta lo dice), y que sin decir "carpeta" solo valgan las
# siete de siempre, que con el oido al 70,4 % un nombre libre es un nombre mal oido.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-carpetas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya cuenta y mide sus carpetas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n116. Que dice, y contesta que ahora voy"
# Idea 16. 31 eventos de notificacion en catorce dias y 45 mensajes; Discord es 24 eventos
# (77 %) y 38 mensajes (84 %): lo que le llega son PERSONAS. Y hoy Nova dice "tienes 3 de
# Discord" sin decir lo que ponen, o te lee cinco del tiron Y VACIA la cola. Ahora "que dice"
# dice el ultimo -remitente y primera linea- sin vaciar nada, y "contesta que ahora voy"
# funciona sin el pronombre pegado. Lo que mas se vigila: que preguntar no borre lo que
# quedaba por leer, y que el patron de contestar NO se trague "dile a maria que la llamo",
# porque escribiria en la ventana de otra persona. Y sigue sin enviar: ni un Enter.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-notif-quedice.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya te dice quien es y que pone)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n115. La voz, en el menu del mando"
# Idea 14, replanteada. La pedida -un boton para "repite eso"- se cae con dato: en 1.804
# frases distintas suyas braya NO ha pedido que repita NI UNA VEZ, y ese menu solo tiene
# sitio para lo que se usa. Lo que SI esta respaldado son las dos unicas cosas que pidio
# sobre como suena Nova -"habla mas rapido" y "que suene todo un poco mas bajito", las dos
# del 13/09-, que solo se pueden pedir HABLANDO, y hablando falla el 29,6 % de las veces. Y
# hay un rato en que hablar no sirve: "el oido aun carga" sale 39 veces en 244 arranques, 12
# de 12 el 22/09 y 12 de 12 el 23/09. Lo que mas se vigila aqui: que apretar cambie la voz de
# VERDAD, y no solo la etiqueta de la capsula.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-panel-voz.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la voz ya se cambia sin hablar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n114. No hablarle a una habitacion vacia"
# Idea 20. Medido: 77 avisos de entorno en catorce dias y solo 17 (22 %) tuvieron una orden
# suya en los cinco minutos siguientes. El peor es oido-ruido, 31 avisos y 2 atendidos, que
# es el 40 % de todo lo que Nova dice por su cuenta. Quitando los flancos fisicos -cargador,
# cascos, dock: cosas que acaba de hacer con las manos, o sea presencia probada- quedan 46
# avisos con 7 atendidos: 39 frases dichas a nadie. Ahora los de nivel medio se aparcan si
# lleva mas de 30 minutos sin dar senales -el mismo umbral del parte de la manana- y salen
# cuando vuelve, por el mando o diciendo "que me he perdido". Lo que mas se vigila: que un
# aviso aparcado NO se marque como dicho (gmail-lleno tiene plazo de una semana).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-avisos-espera.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no le habla a una habitacion vacia)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n113. La agenda mira los tres sitios, no uno"
# Idea 5. NO se hace un calendario nuevo: seria un CUARTO sitio con cosas con fecha al lado
# de los tres que ya hay. El alias existe desde el 18/09 -braya lo pidio tres veces y acabo
# en el agente (23 s) o en la charla- y lo que fallaba era su cobertura: leia solo
# recordatorios.json. Con el cumple de Ana guardado en fechas.json para manana, "dime si
# tengo algo anotado para manana" contestaba "No tienes nada apuntado para manana": Nova
# mintiendo con datos que ella misma guardo, en silencio y con una frase que suena bien.
# Ahora junta recordatorios, fechas anuales y las reglas de hora que HABLAN (un modo nocturno
# no es una cita), y se puede borrar una cita hablando, con dos salidas y sin borrar nunca si
# hay mas de una candidata.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-calendario.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la agenda mira ya los tres sitios)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n112. Lo que se repite: cada dos horas, di que estire la espalda"
# Idea 4. NO se amplia recordatorios.json -seria una segunda lista de cosas periodicas al
# lado de reglas.json, y el codigo ya tiene escrita esa leccion-. Se arregla la regla 'cada',
# que existia y para su frase no funcionaba, con tres fallos comprobados en el fuente:
#  1. no entraba la frase: el patron pide digitos y nadie llamaba a ConvertTo-Digitos, asi
#     que "cada DOS horas di que estire la espalda" se iba al modelo;
#  2. el reloj era el cronometro DEL PROCESO y se persistia: al reiniciar, $sw vuelve a cero
#     y la resta sale negativa, o sea que la regla no volvia a hablar NUNCA. Con 16,3
#     arranques al dia eso pasa el primer dia, y es un fallo mudo;
#  3. y la cuenta empezaba de cero en cada arranque, asi que "cada dos horas" casi nunca
#     llegaba a las dos horas.
# Ahora reloj de pared, plazo de hoy salvo "siempre", y dos salidas: por numero y por texto.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-repetidos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que se repite, ya se repite de verdad)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n111. \"Esto\", \"este\", \"eso\": la ventana que tienes delante"
# Idea 2. De las 41 frases suyas con un deictico sin referente, 16 son "hay alguna
# actualizacion de este" y 20 son "este estado es cargando en steam". Y midiendolo salio lo
# que cambio el plan: de las 599 frases de los tres ficheros de pruebas SOLO DOS entran en
# los patrones, y las dos ya se resuelven hoy en local, asi que el paso solo toca lo que hoy
# no sabe hacer nadie. Lo que vigila el banco, por orden: que nada que empiece por un verbo
# salga de aqui listo para ejecutarse (hoy "abre este" acaba en el agente, que tiene acceso
# total); que sin ventana util no se invente ningun referente; y que el paso siga viviendo en
# Process-Texto, porque $FILLER_INI se come el "este" de cabeza antes de Resolve-Fragment.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-deictico.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:esto ya sabe a que te refieres)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n110. Corregir hablando lo que Nova cree saber de ti"
# Idea 7. Tres fallos medidos ejecutando el codigo: (a) el filtro "no guardo lo que habla de
# mi" se comia las correcciones de trato -de 10 rechazos en catorce dias, OCHO lo eran, y dos
# son POSTERIORES al arreglo del 21/09, que pedia "prefiere que no" pegado cuando las frases
# reales dicen "prefiere que NOVA no"-; (b) Remove-DatoPerfil comparaba con Contains() sin
# ancla, asi que "la captura de la pantalla, eliminalo" se llevaba "guarda las capturas en
# D:\Capturas" y "el recordatorio del dentista, eliminalo" se llevaba la cita del dentista:
# Nova borrando lo que braya no pidio, que es la regla 1; (c) "eso es falso, eliminalo" no
# apuntaba a nada despues de un arranque, y Nova arranca 16,3 veces al dia. Y ahora se puede
# deshacer un borrado hablando, con cinco minutos de ventana.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-perfil-corrige.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ahora se puede corregir hablando)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n109. El aviso de las dos horas, contado por el dia"
# Idea 11. Con juego.avisoMinutos=120 el aviso debio saltar TRES dias (It Takes Two el 15/09
# con 5 h 38, el 20/09 con 2 h 45 y el 22/09 con 3 h 12) y "JUEGO: aviso de tiempo" sale UNA
# SOLA VEZ en catorce dias. Pedia 120 minutos de primer plano SIN UN CORTE, y $juegoDesde se
# pone a cero en cuanto miras Discord; encima cada reinicio lo reiniciaba (16,3 al dia). Y
# habitos.json llevaba una cuenta paralela que se perdia en cada reinicio y usaba otro "dia".
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-tiempo-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no lo mata un alt-tab)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n108. Las cinco funciones que no probaba nadie"
# Mapeando el repo para la tanda de veinte salieron cinco funciones sin ningun banco, y las
# cinco son la base de cuatro de las ideas que vienen: Get-MusicaActual, Get-PrimerVideoYouTube,
# Test-Recordatorios, Remove-DatoPerfil y Get-AmigosSteam. Escribiendo el banco aparecio un
# fallo de verdad: Remove-DatoPerfil borraba un dato al azar si le decias UNA palabra comun
# ("braya" sale en 28 de sus 60 datos). Y lo que se vigila sobre todo: que la clave de la API
# de Steam no salga NUNCA en el log.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-huerfanas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya tienen quien las mire)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n107. Mandar callar: que no diga que si y siga escuchando"
# 23/09 21:16, y es la segunda vez con la misma familia. braya dijo "no me hablas en diez
# minutos" (con ruido delante), Nova lo mando a la charla, el modelo contesto que vale y la
# sordina no se activo: siguio escuchando. Decir que si y no hacerlo es el peor fallo que
# puede tener. Medido: de trece formas naturales de pedirlo, el patron cogia TRES -los
# numeros hablados llegaban hasta CINCO, asi que "diez minutos" no existia-.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-mandar-callar.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:cuando le mandas callar se calla)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n104. La lupa: ensenar el trozo en vez de recitarlo"
# Funcion 8. Su pantalla son 15 x 9 cm con el escritorio a 1280x720: 0,117 mm por pixel, o sea
# eso era el OCR: la unica lectura de pantalla de JUEGO de todo el registro devolvio cinco
# trozos y dos eran basura ("O", "Kit"). Ademas el 20/09 lo pidio el: "no describas lo que ves
# en la pantalla literalmente". La lupa no lee nada, ensena. Lo que se vigila: que amplie de
# verdad (x2 recortando, no "lo que quepa" = x1,17), que no robe el foco con el mando en las
# manos, y que se quite sola.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-lupa.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no le quita el mando)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n103. Bajarle el juego para hablarle, y devolverselo"
# Funcion 7. Le habla mientras juega -toda la tanda del 22/09 de 21:43 a 21:48- y hablaba
# ENCIMA del audio del juego. Lo que se vigila: que NO le suba el volumen sin querer
# (PonerVolumenApp es absoluto: poner 50 con el juego al 30 lo sube) y que se lo devuelva
# siempre, aunque Nova muera o la corten.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-volumen-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:te lo devuelve)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n102. El disco: que ocupa y soltar lo regenerable"
# Funcion 6. Nova prometio CUATRO veces "preguntame que ocupa mas" y esa orden no existia.
# Es la funcion que borra, asi que se vigila: lista cerrada escrita en el codigo, nada suyo
# dentro, se pregunta antes, y el numero que dice sale de medir el disco -no de sumar lo que
# creia haber borrado-.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-disco-limpia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:solo lo que se regenera)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n101. Limpiar lo que cree saber de braya"
# Funcion 5. Su perfil esta lleno (59 de 60) y solo las 15 ultimas lineas viajan en cada
# charla, asi que la basura le vuelve hablada: tres lineas de un juego mal oido ("Amino") y
# dos de un "Meramiau" que acabo inventando un gato. No se borra solo: se busca el par que
# mas se parece y se le PREGUNTA con las dos frases delante.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-perfil-limpia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:te deja elegir a ti)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n100. Acordarse de lo que le contaste"
# Funcion 4. "¿que te dije del juego que era caro?" se iba a opencode -el agente con acceso
# total- tardando de 25 a 60 s, con la respuesta esperando en su propia memoria. El liston
# (0,28) se midio contra sus 110 recuerdos: los cinco temas que SI estan puntuan 0,315-0,534 y
# los cuatro que no, 0,205-0,241. El analisis proponia 0,45, que habria tirado cuatro de cinco.
python (Join-Path $PSScriptRoot 'probar-recordar.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:dice que no cuando no lo sabe)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n99. Montajes de ventanas con nombre"
# Funcion 3. En catorce dias la pantalla dividida no se ejecuto bien ni una vez por voz: cero
# de once intentos, y el 18/09 se quejo por voz ("solo abriste Pinterest, nunca abriste
# YouTube"). Con un nombre no hay nada que adivinar. El montaje se guarda de los destinos YA
# RESUELTOS, y al montarlo se reusa la ventana abierta en vez de abrir otra.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-montajes.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la vuelves a montar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n98. Las palabras que braya no aguanta"
# Funcion 2. Se lo pidio TRES veces ("deja de decirme man", "deja de llamarme tio", "deja de
# decir tio, no me gusta esa palabra") y seguia pasando. Y lo peor: de la queja aprendio
# "braya habla con acento español (usa 'tio')" -el dato del reves- y esa linea viajaba en el
# prompt de todas sus charlas, realimentando justo lo que molestaba.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-palabras-no.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no lo aprende del reves)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n97. Mirar la pantalla cuando se lo pide"
# Funcion 1, y es la queja mas dura de todo el registro: "miralo tu mismo y dime que ves",
# "me dijiste cualquier cosa menos lo que viste", "deja de decir que no ves nada, literalmente
# tienes un OCR", "estas alucinando". De sus 40 turnos sobre la pantalla, ocho caian en la
# charla, que es ciega. Y el OCR vacio no es "no veo nada": es que no hay LETRAS que leer.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-ver-pantalla.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la mira)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n96. Ajedrez a ciegas: el puente, y que una orden siga siendo una orden"
# Lo pidio braya. Lo que se vigila aqui no es el ajedrez -eso lo lleva python-chess- sino la
# triple llave: sin partida abierta no se mira nada, la frase tiene que tener FORMA de jugada
# con el patron anclado, y python-chess la valida contra las legales de ESE tablero. Con
# partida abierta, "sube el volumen" tiene que seguir subiendo el volumen.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-ajedrez-voz.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la orden sigue siendo una orden)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n95. Ajedrez a ciegas: la partida, el oido y el motor"
# En 1.127 transcripciones no hay NI UN par letra+cifra tipo "e4": dictar notacion no funciona
# y no va a funcionar. Por eso al oido no se le enseña ajedrez: python-chess da las jugadas
# legales y el oido solo ELIGE de esa lista cerrada. El par mas flojo del alfabeto hablado son
# las filas seis/siete (0,705), y una fila equivocada suele ser legal: ahi se pregunta siempre.
python (Join-Path $PSScriptRoot 'probar-ajedrez.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:una orden no se convierte en jugada)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n94. El brillo que vuelve a ser el tuyo, y el disco que deja rastro"
# Ideas 2 y 5 de la cuarta tanda. El brillo de antes del juego vivia solo en RAM: 33 perfiles
# aplicados contra 21 restauraciones, y de las 16 desde que su brillo es 70, las 12 con la
# cadena limpia devolvieron 70 y las 4 con un reinicio en medio devolvieron 100. Y el disco:
# el 22/09 cayo de 11,1 a 0,81 GB en catorce horas sin escribir UNA sola linea.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-brillo-y-disco.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el disco deja rastro)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n93. Que lo que hace lo diga conjugado"
# Idea 1 de la cuarta tanda, y lo pidio braya. Invoke-FastCommand devuelve el nombre interno
# de la accion y esa cadena se decia en voz alta: 139 respuestas en infinitivo, 77 formas, y
# "abrir steam" es la frase mas repetida de toda Nova (23 veces). Ahora se dice "Abro steam",
# pero el dato interno -log, memoria de la charla, bancos- sigue siendo "abrir steam".
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-frase-accion.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo dice conjugado)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n92. La pantalla dividida, como la dice braya"
# Idea 9. En catorce dias la pantalla dividida no se ejecuto bien ni una vez por voz: cero de
# once intentos. La forma "X en la mitad y en la otra mitad Y" la dijo tres veces en tres
# dias y las tres acabaron en el modelo o en una busqueda equivocada; la del 22 costo 68 s.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-pantalla-mitad.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya es una pantalla dividida)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n91. El parte de la manana y la hora de dormir"
# Ideas 8 y 10. El parte salia a las 05:00 clavadas -braya aparecia a las 12:53, 16:31 y
# 20:25- y los tres dias NO llego: vivia en una variable de sesion y Nova reiniciaba por
# medio, con el dia ya marcado en disco. Y el aviso de la hora de dormir salio 4 veces y las
# cuatro las desmiente su propio habitos.json: siguio 8, 84, 138 y 138 minutos mas.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-parte-y-dormir.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la hora de dormir es la tuya)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n90. El correo que no pediste, en una linea"
# Idea 6. El parte del correo leia remitente y asunto: 27 segundos clavados de microfono
# sordo el 19/09 y 327 caracteres el 22/09, la frase mas larga que ha dicho Nova. Dos de los
# cuatro asuntos eran el mismo aviso de saldo de su banco. Y es la UNICA vez en todo el log
# que braya corta algo que Nova empezo sola ("calla", 22/09 08:35:41).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-correo-corto.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se dice en una linea)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n89. Que lo que repites renueve el dato que se le parece"
# Idea 7. Las cinco primeras renovaciones reales del perfil fueron las cinco al dato
# equivocado: dijo "It Takes Two" y blindo "juegos de terror". Dos motivos: se quedaba con el
# PRIMERO que pasara el liston, y contaba como contenido palabras que estan en medio perfil
# ("braya" sale en 29 de 60 datos).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-perfil-parecido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el dato que se le parece)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n88. Que lo que te corrige valga tambien para lo ya guardado"
# Idea 5 de la tercera tanda. braya pidio TRES veces que no le llamara "tio" ni "man", Nova
# prometio dos veces que no, y dos dias despues: "No te sigo, tio". En cerebro.json habia 12
# entradas de estilo y dos decian lo contrario de lo que el pidio; las 12 viajan juntas en el
# prompt de todas sus charlas. La regla que lo arregla vivia en _estilo, que solo corre con lo
# que llega NUEVO: lo ya guardado no lo repasaba nadie. En su cerebro real se van 5 de 12.
python (Join-Path $PSScriptRoot 'probar-estilo-repasado.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya estaba guardado)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n87. Que la ventana cierre cuando dejas de hablar, no a los 30 s"
# Idea 2 de la tercera tanda. Con un juego sonando, las explosiones pasan el umbral de energia
# igual que una voz y rearman ultima_voz, asi que la ventana solo cerraba por el tope duro de
# 30 s. La noche del 22: cinco seguimientos seguidos al tope, 176 segundos para cinco frases,
# y a Whisper le llegaban ~4 s de braya y ~11 del juego. Ahora, con los altavoces sonando,
# manda que no salga una palabra NUEVA; sin altavoces no cambia nada.
python (Join-Path $PSScriptRoot 'probar-cierre-con-juego.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:cierra cuando dejas de hablar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n86. Jugando, tu nombre pasa por las mismas guardas que siempre"
# Idea 1 de la tercera tanda. La rama que ignora el nombre con un juego delante era la
# PRIMERA de la cadena: medido, 359 de 360 hipotesis entraban sin que nadie mirara altavoces,
# rafaga ni confianza, mientras que sin juego esas guardas tiran el 29 %. Daba igual mientras
# solo escribia una linea; desde que el asistente contesta con tarjeta y vibracion, cada
# falso positivo del juego era un toque en el mando que braya no pidio.
python (Join-Path $PSScriptRoot 'probar-guardas-juego.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:las mismas guardas que siempre)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n85. Que mandarla callar no le abra el microfono"
# Idea 4 de la tercera tanda, y es lo que braya pidio anoche. Por la rama del corte entran el
# nombre -que significa "voy a hablar"- y las seis palabras de parada, que significan lo
# contrario; las tres lineas que reabren la escucha estaban escritas para el primero. El
# 21/09 a las 00:07:53 dijo "para", Nova paro, reabrio el micro, cogio una frase que no era
# para ella, la mando a Gemini y a la API, y volvio a hablar 21 segundos despues.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-corte-callar.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no abre el microfono)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n84. Que el disco lleno se diga a tiempo, y se salte la noche"
# 22/09 por la noche: el ultimo aviso de disco fue a las 08:33 ("te quedan 11.1 gigas") y a
# las 22:50 quedaban 0,81 GB de 475 -el 0,18 %- sin una palabra en medio. Catorce horas: doce
# del plazo de 720 min y dos y media del silencio del modo juego. Y a las 23:00 entraba el
# silencio de la noche: con nivel 'medio' no habria hablado hasta las 08:00, con el disco a
# cero. Por debajo del liston critico pasa a 'alto', que es el unico nivel que se salta el
# juego, la noche y el tope por hora.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-disco-critico.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se salta la noche)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n83. Callarse cuando se lo dices, y volver cuando la llamas"
# 22/09 por la noche, y sale de una frase suya del log: a las 21:48:54, jugando, braya dijo
# "No, no me hablas por 10 minutos". Ninguna forma de HABLAR estaba en los patrones -habia
# de oir ("no me escuches") y de activarse ("no te actives")-, asi que se fue a la charla,
# que contesto "Vale, entendido, me callo"... y no se callo nadie. Ahora se calla de verdad,
# y sale llamandola por su nombre, que es lo que pidio. Ojo con el historial: el 21/09 esto
# mismo se rompio al reves (se despertaba a medias, con la sordina todavia en disco).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-sordina-nombre.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:vuelves cuando te llama)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n82. Que jugando te ignore, pero NO en silencio"
# 22/09 por la noche, visto en el log mientras braya jugaba: dijo 'nova' cinco veces en diez
# minutos con It Takes Two delante y no recibio NADA. Con un juego en primer plano solo vale
# el boton -eso viene del 11/09 y no se toca-, pero ignorarle en silencio es, desde fuera,
# identico a estar rota: la misma leccion del aviso del ruido doce horas antes. Ahora se ve
# en la capsula una vez por partida. Sin voz (jugando no se interrumpe, y la llamada pudo
# ser un falso positivo) y sin ejecutar nada.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-llamada-en-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no en silencio)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n81. Que la bateria llena se diga una vez por carga, no cuatro al dia"
# 22/09 por la noche. El aviso 'ya esta cargada del todo' colgaba de un ESTADO dentro de un
# bloque que corre cada minuto: con la consola enchufada eso es cierto el dia entero, y lo
# unico que lo frenaba era su plazo de 240 min. Resultado medido: 19 avisos identicos, cuatro
# al dia desde el 19/09, y el ultimo 'cargador: desenchufado' es del 19/09 a las 09:24. Y el
# aviso era lo de menos: la linea de al lado, Invoke-Reglas 'bateriaLlena', no tiene plazo
# NINGUNO y su rama del despacho es estado pelado, sin rearme; el dia que braya diga "cuando
# termine de cargar, pon el modo trabajo", esa accion se ejecutaria cada sesenta segundos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-bateria-llena.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:una vez por carga)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n64. Y que lo DIGA cuando el ruido le tapa la voz (idea 5)"
# La otra mitad de 2n63. Lo peor de la madrugada del 22 no fue quedarse sorda: fue que no lo
# dijo. 34 minutos sin oir y sin una palabra, que desde fuera es identico a funcionar bien.
# El worker deja el dato en el QUINTO campo de escucha-estado.txt -al final, para que las dos
# lecturas viejas sigan cogiendo los campos 0 a 3- y el aviso va por Send-AvisoEntorno con
# nivel 'medio', asi respeta el silencio de la noche, el modo juego y el limite por hora.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aviso-ruido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:le tapa la voz)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n63. Que Nova no se pueda quedar sorda"
# 22/09 de madrugada, el fallo mas gordo de la noche. A las 01:18:40 empezo a sonar algo
# constante; a partir de ahi TODOS los bloques pasaban UMBRAL_VOZ, el p90 'de voz' paso a ser
# el del ruido (0,13), la ganancia se calibro contra el y se hundio de x15,5 a x2,6, y la
# puerta subio a 0,1264. Las cinco rafagas con las que braya habia llamado a Nova esa noche
# fueron 0,024-0,081 CON EL SUELO EN 0,0045, o sea que su voz asoma 0,0195 sobre el ruido: en
# esa habitacion valdria 0,1294 contra una puerta de 0,1264, un 2 % de margen. No se puede
# afirmar que se quedara sorda -dejo de hablarle a las 01:18:36 y no hubo ni un intento
# despues-, pero un 2 % no es un sistema que funciona, es uno que aun no ha fallado.
# La leccion: un numero que sube solo necesita un techo que NO dependa de el. Ahora la puerta
# nunca pasa de la rafaga mas floja con la que se le ha oido de verdad, y el ruido constante
# (casi todos los bloques, dos pulsos seguidos) ni calibra ni sube nada, y ademas se dice.
python (Join-Path $PSScriptRoot 'probar-no-sorda.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no puede subir por encima de su voz)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n62. Los plazos de soltar modelos, segun la RAM que quede"
# 22/09, y de la misma peticion de braya: 'nova tiene que adaptarse a la situacion y cambiar
# sola'. Los cuatro plazos del oido (20 min el oido fino, 5 min con juego, 2 min el ultimo
# recurso) estaban escritos a mano. Medido ese dia con Nova en marcha: el worker del oido
# llevaba 1.668 MB con los cuatro modelos dentro y quedaban 1.767 MB libres de 11.979; y esa
# madrugada el asistente se murio a mitad de un dictado sin dejar ni un error en el Visor de
# eventos -la pinta de quedarse sin memoria-, sin una sola linea en el log que dijera cuanta
# RAM habia. Ahora el plazo sale de lo libre (entero con 2.500 MB, la decima parte con 1.000)
# y el pulso apunta la RAM, para que la proxima vez se pueda saber.
python (Join-Path $PSScriptRoot 'probar-plazos-soltar.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se adaptan a la memoria)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n61. El liston de letras, que se lo pone ella"
# 22/09, y sale de que braya dijera: 'no se puede hacer que el liston de letras sea
# ajustable por nova, de hecho todo deberia ser ajustable por ella'. Tenia razon y habia
# algo peor debajo: segundos_de_voz cortaba en un 0,008 fijo, por debajo del silencio del
# micro USB (0,018-0,025), y devolvia el FICHERO ENTERO como voz (11,0 s de audio -> 10,9 s
# de 'voz'). Eso hundia las letras por segundo y mandaba a Whisper ordenes que Parakeet ya
# tenia bien -'Cierra los ajustes' (3,4)-, que volvian PEOR: 'Si es a los ajutos'. Un numero
# fijo causando ordenes equivocadas. Ahora la voz se mide contra su propio silencio y el
# liston sale del ritmo de braya (mediana 13,7 letras/s en sus 395 grabaciones; * 0,30 = 4,1,
# que es el 4,0 de siempre). Lo que mas se prueba aqui es que el aprendizaje NO SE VAYA SOLO.
python (Join-Path $PSScriptRoot 'probar-liston-letras.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no se le va solo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n60. El liston de la rafaga, relativo a su voz"
# 21/09 noche, y salio de que braya dijera usandola: 'se demora en recibir lo que le
# digo'. El filtro de 'suena demasiado flojo' tenia un numero FIJO (0,030) y su voz
# entera estaba a veces por debajo: p90 de 0,011 a 0,026. Cruzando cada descarte con el
# p90 de su voz en ese momento, la mayoria de esas rafagas eran MAS FUERTES que su
# propia voz (127 %, 162 %). Ahora el liston se adapta: recupera 12 llamadas de las 39
# descartadas y no pierde ninguna de las 52 que ya activan.
python (Join-Path $PSScriptRoot 'probar-rafaga.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se adapta a su voz)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n59. Crear una carpeta o un archivo por voz (D7 + B9)"
# 21/09. El 20/09 braya lo pidio CUATRO veces y las cuatro se fueron al agente: para
# crear una carpeta eso es una grua para levantar un vaso. Se prueban las dos mitades:
# que se entienda -sin llevarse por delante 'crea una nota', que es apuntar, ni 'crea el
# modo X'- y que se cree DE VERDAD, comprobandolo con Test-Path despues (B9). El destino
# sale de Find-CarpetaPorNombre, que solo conoce seis carpetas, y el nombre no puede ser
# una ruta: sale de lo que se OYO.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-crear.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se entiende, se hace y se comprueba)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n58. Lo que se lee de fuera son DATOS, no ordenes"
# 21/09. Nova le pasa al modelo texto que NO ha dicho braya en tres sitios: el OCR de la
# pantalla, los correos y las notificaciones. Y la charla tiene un camino de vuelta -el
# evento 'orden'- que acaba en Invoke-FastCommand, o sea EJECUTANDO. Juntando las dos
# cosas, una ventana de Discord donde ponga 'cierra todos los programas' y un 'cuentame
# que ves' bastaban. Ahora esas peticiones van marcadas y, si vuelven con una orden, se
# tira. Contestar hablando si se puede: lo que no se puede es HACER lo que diga un texto
# que no salio de su boca.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-texto-de-fuera.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no puede convertirse en una orden)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n57. El numero de la meta, para mirarlo (C19)"
# OJO AL NOMBRE: probar-meta.ps1 ES OTRO BANCO (el 2n35, la frase hablada). El 21/09
# se sobrescribio sin querer al crear este, y lo canto la propia bateria: la seccion
# 2n35 se quedo sin una sola linea de salida. Este es probar-meta-TABLA.ps1.
# Preguntarlo ya se podia desde el 19/09; lo que faltaba era un sitio donde VERLO sin
# preguntar, y es la tabla que abre memoria\estadisticas.md. Lo que mas se prueba aqui
# no es la tabla: es que los DOS contadores -la frase hablada y la tabla- den el MISMO
# numero. El 19/09 la frase decia 72 % y el analisis 75 % del mismo dia, y dos numeros
# que no cuadran no se los cree nadie.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-meta-tabla.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el mismo que si lo preguntas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n56. Las 14 traducciones que se perdieron (C6)"
# OJO AL NOMBRE, igual que con probar-meta: probar-traduccion.ps1 (en singular) ES
# OTRO BANCO, el de que no se aprenda una traduccion destructiva. Este es el de las
# 14 perdidas y se llama probar-traducciones-PERDIDAS.ps1.
# 19/09: aparecieron 14 aprendidos menos en traducciones.json y nadie supo quien los
# habia borrado. La pista era el formato -dos espacios tras los dos puntos, o sea
# ConvertTo-Json de PowerShell 5.1-: lo reescribio Nova misma. Aprender y olvidar
# escribian el fichero ENTERO desde la copia que vive en RAM, y esa copia se queda
# VACIA cuando el JSON llega corrupto. Aqui se reproduce: 14 en el fichero, la RAM
# vacia, aprende una... y quedaba 1. Lo que mas importa del arreglo es lo de abajo:
# que fusionar con el disco NO resucite lo que acabas de mandar olvidar.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-traducciones-perdidas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no se lleva por delante)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n55. Lo que se guarda de ti, y lo que Nova dice que dijo"
# 21/09. Tres filtros que no filtraban, y los tres fallaban EN SILENCIO: el de datos
# sensibles del perfil comparaba CON tildes contra un patron escrito sin ellas
# ('diagnostic' no casa con "diagnostico" jamas); el de deducciones pedia que la frase
# EMPEZARA por 'probablemente', y los datos del perfil empiezan todos por 'Braya ...';
# y un aviso de nivel bajo -de los que se VEN y no se dicen- se quedaba como la ultima
# respuesta, asi que 'repite' soltaba una frase que Nova no habia dicho nunca.
# Lo que entra en el perfil VIAJA CON CADA PETICION al modelo: por eso van juntos.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-perfil-avisos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se filtra de verdad)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n53. Los juegos por su apodo, y el articulo que abria OTRO"
# 21/09, de sondear como pide las cosas de verdad. "abre el warning" abria ELDEN RING
# teniendo Content Warning instalado, y "cierra el warning" lo CERRABA: Get-ClaveSonido
# pega las palabras y "elguarning" se parece mas a "eldenring" que a "kontentguarning".
# Tres ordenes equivocadas. Lo que mas se prueba aqui son los CONTROLES: al comparar
# tambien contra las palabras sueltas del titulo, "todo" empezo a parecerse a "Hollow".
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-apodos-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el articulo ya no abre otro)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n52. 'Eso no es verdad' rechaza lo que Nova dijo, no otra cosa"
# 21/09, de la tanda. marcar_incorrecta se fiaba de ultimo_id, que es estado global y lo
# escribe TAMBIEN el hilo del revisor, de fondo y entre turnos. braya podia decir "no, eso
# no es verdad" y marcar como falso un recuerdo que no habia oido en su vida, dejando
# firme el que estaba mal. Dos errores de un golpe, y ninguno se ve hasta mucho despues.
python (Join-Path $PSScriptRoot 'probar-eso-no-es-verdad.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no lo que el revisor guardo de fondo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n51. Cerrar un juego por el sonido del nombre PREGUNTA antes"
# 21/09, de la tanda. Los dos caminos de ABRIR marcan la orden como dudosa y por eso Nova
# pregunta; el de CERRAR -que es el que mata un proceso- no lo hacia. Medido con su
# biblioteca de verdad: "cierra el ring" da ELDEN RING con 0,67 de parecido y se ejecutaba
# de golpe, con la partida abierta.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-cerrar-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:pregunta antes, igual que abrirlo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n50. El tope de la nube se guarda de verdad, y la sordina se calla de verdad"
# 21/09, de la tanda. El caso 4 de la revision propia anunciaba por voz un cambio que solo
# vivia en RAM: la mediana de sesion son 5,8 minutos y a los pocos minutos volvia a 7000
# sin decir nada, ademas de quedar bloqueado porque SI apuntaba que habia decidido. Y era
# la unica decision propia sin el freno de "datos repartidos". La sordina, aparte: dejaba
# la marca en modo voz y con eso decir "nova" la rompia y el worker seguia media hora.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-nube-sordina.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la sordina se calla de verdad)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n49. Lo que hay detras de un si (el correo, la direccion y el microfono)"
# 21/09, de la tanda de agentes. Detras de una confirmacion si/no estan: mandar un correo,
# borrar una carpeta, borrar una lista, apagar, reiniciar y cerrar los juegos. Y habia
# tres agujeros: el correo NO se enviaba nunca (nadie leia su campo y se contestaba "No te
# escuche"), mandarlo por nombre se contradecia solo, y cinco sitios reabrian la escucha
# sin reponer el factor, o sea que Nova preguntaba al aire. Mas el "si" fantasma del oido.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-confirmaciones.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:hace falta haber hablado)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n48. Las doce de la noche son las doce de la noche"
# 21/09, de la tanda de agentes. El mismo fallo en DOS sitios -las reglas por hora y los
# recordatorios, que tienen las dos lineas copiadas-: el 12 era el unico numero que no
# seguia la regla, y "de la manana" y "de la noche" estaban cambiados. Doce horas de
# error, y no solo en un aviso: "a las doce de la noche pon modo noche" bajaba el brillo
# al MEDIODIA. De paso, la madrugada no se reconocia y caia en "hora pequena = tarde".
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-horas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la madrugada no es la tarde)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n47. La noche que se quedo muda: el .part compartido y el respaldo que no existia"
# 21/09. 20/09 23:39:12, en mitad de una charla: los dos workers de voz escribieron en el
# MISMO temporal, uno reventro con WinError 32, y el respaldo de Piper no se podia
# alcanzar porque exigia una variable que nunca se llena. braya oyo media respuesta y
# silencio. Piper llevaba sin sonar desde el 10/09 y nadie lo sabia.
# Comprobado a mano el 21/09 que piper.exe SUENA: 2,9 s de audio con 276 ms de inferencia
# (factor 0,10 en tiempo real). Aqui no se ejecuta: tarda 3 s en cargar el modelo.
python (Join-Path $PSScriptRoot 'probar-voz-respaldo.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no se queda muda)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n45. Que Nova sepa que Roblox es un juego (y que no se invente ninguno)"
# D1 (21/09). Dos horas de Roblox y para Nova no estaba jugando: solo contaba como
# juego lo que viviera en steamapps\common, y su Roblox es el de Game Pass. Lo que
# mas se prueba aqui no es que reconozca juegos, sino que NO se invente ninguno: un
# falso positivo hace que se calle los avisos que si querias.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-juego-primer-plano.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sin inventarse ninguno)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n75. Que Nova avise si lleva dias sin apuntar ni una orden (sin uso no se decide nada)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-sin-uso.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n35. El contador de la meta (como me has entendido hoy)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-meta.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n39. Las falsas alarmas (que no vuelvan a salir porcentajes de 489 %)"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-falsas-alarmas.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n36. La copia que te salva (que se pueda abrir, que rote y que falle bien)"
# ENTRA EN EL BANCO EL 19/09 (B13 = MEJORAS.md 3.4 #8): New-CopiaSeguridad existe desde el
# 13/09 y no la tocaba ninguna prueba. Cabe aqui porque NO necesita microfono, ni Nova
# encendida, ni cargar modelos: monta un voice-ctrl de mentira en $env:TEMP y cambia
# $env:OneDrive para no rotar el tuyo. Tarda ~7 s.
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-copia.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:todo correcto)|MAL'
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
    $minimo = if ($banco -eq 'ordenes-que-funcionaban.txt') { 88 } else { 433 }   # 433 desde el 22/09 (avisame cuando la descarga termine). Antes 429 (C10, la pantalla dividida encadenada). Antes 421 tarde (el filtro de 'a las?' sin hora, que se tragaba
# cualquier frase que empezara por 'a la', y las preposiciones de las flechas). Antes 405
# verbo), 389 ('dime que X'), 377 (los apodos), 369 (el volumen al reves), 346, 335,
# 317, 308 y 289: MEDIDO (287 + 2 saltadas). +9 de "mira la pantalla". Antes 280, 260, 254, 242, 238, 234, 228, 221
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
# SI NO SALE LA LINEA, ESO TAMBIEN ES UN FALLO (21/09). La seccion 3 tiene esta guarda
# desde siempre y la 4 se quedo sin ella: si -Probar reventaba o cambiaba el texto de la
# linea de resultados, el -match no casaba, no se entraba al bloque y no se sumaba NADA.
# O sea que la prueba del RUIDO -la que vigila que Nova no se vuelva confiada- pasaba en
# verde justo cuando dejaba de medir.
$n = -1
if ("$linea" -match 'local:\s*(\d+)') { $n = [int]$Matches[1] }
if ($n -lt 0) {
    Write-Host "   MAL: no salio la linea de resultados del ruido; esto no ha medido nada" -ForegroundColor Red
    $fallos++
} elseif ($n -gt 3) {
    # 3 es lo que quedo el 11/09 con el corpus ya curado: dos nombres de juego
    # (que al ejecutarse preguntan antes) y un "Adios" que solo contesta. Si
    # sube, alguien ha aflojado la capa local y volvera a hacer cosas solo.
    Write-Host "   OJO: antes eran 3. Ha subido: algo se ha vuelto mas confiado." -ForegroundColor Red
    $fallos++
}

Titulo "5b. El DLL y la capsula, al dia con su fuente (AMARILLO, no fallo)"
# 21/09. assistant-dx.dll se PRECOMPILA a proposito -invocar csc en cada arranque colgaba
# y mataba el proceso en silencio-, asi que tocar assistant-dx.cs no cambia nada hasta que
# alguien recompila. Y mientras Nova esta en marcha el DLL esta BLOQUEADO, o sea que
# recompilar hay que hacerlo con ella parada y es justo cuando se olvida. Paso hoy mismo
# con OlvidarVolumen: el codigo ya la llama y el DLL todavia no la trae.
# LOS DOS BINARIOS QUE SE PRECOMPILAN: el DLL de los P/Invoke y la capsula. Los dos se
# quedan BLOQUEADOS mientras Nova corre, asi que recompilarlos hay que hacerlo con ella
# parada, y es justo cuando se olvida.
foreach ($par in @(
        @{ cs = 'assistant-dx.cs'; bin = 'assistant-dx.dll'; como = 'powershell -NoProfile -File tools\recompilar-dx.ps1' },
        @{ cs = 'nova_ui.cs'; bin = 'nova_ui.exe'; como = 'powershell -NoProfile -File tools\compilar-ui.ps1' })) {
    $csX = Join-Path $raiz $par.cs
    $binX = Join-Path $raiz $par.bin
    if (-not (Test-Path -LiteralPath $csX) -or -not (Test-Path -LiteralPath $binX)) { continue }
    $tCs = (Get-Item -LiteralPath $csX).LastWriteTime
    $tBin = (Get-Item -LiteralPath $binX).LastWriteTime
    if ($tCs -gt $tBin) {
        Write-Host ('   AMARILLO: {0} es mas nuevo que {1} ({2:dd/MM HH:mm} contra {3:dd/MM HH:mm})' -f $par.cs, $par.bin, $tCs, $tBin) -ForegroundColor Yellow
        Write-Host ('      Lo que cambiaste ahi NO esta corriendo. Para Nova y: {0}' -f $par.como) -ForegroundColor Yellow
        $avisosAmarillos += ('{0} cambiado y sin recompilar: lo que tocaste ahi no esta corriendo' -f $par.cs)
    } else {
        Write-Host ('   OK  {0} es igual o mas nuevo que su fuente' -f $par.bin) -ForegroundColor DarkGray
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
Titulo "8. Caracteres invisibles en el codigo (ROJO si los hay)"
# COMO SE PIERDE UNA TARDE (20/09). Un parche escribio una barra invertida y una b en una
# expresion regular, y lo que quedo en el archivo fue el caracter 0x08 (BACKSPACE), no las
# dos letras. El grep lo ensena igual, el editor lo ensena igual, PowerShell lo compila sin
# una queja... y el patron deja de casar con nada. "que juegos tengo" se fue a la IA y costo
# cuatro intentos entender por que, porque lo que se lee y lo que hay no son lo mismo.
# Y la primera version de ESTA seccion nacio con el mismo fallo dentro, en su propia tabla:
# por eso ahora se mira tambien a si misma y a los demas bancos, no solo al codigo.
# Se miran los peligrosos, los que deja caidos un escape mal hecho; el tabulador y el salto
# de linea NO, que son legitimos.
$malos = @{ 8 = 'b'; 7 = 'a'; 12 = 'f'; 11 = 'v'; 27 = 'ESC' }
$sucios = @()
$aMirar = @((Join-Path $raiz "assistant.ps1"), (Join-Path $raiz "wake_vosk.py"),
            (Join-Path $raiz "charla_worker.py"), (Join-Path $raiz "charla_memoria.py"),
            (Join-Path $raiz "config.json"), (Join-Path $raiz "commands.json"))
$aMirar += @(Get-ChildItem -Path $PSScriptRoot -Filter "probar-*" -File | ForEach-Object { $_.FullName })
foreach ($ruta in $aMirar) {
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    $txt = [System.IO.File]::ReadAllText($ruta)
    foreach ($cod in $malos.Keys) {
        $c = [string][char][int]$cod
        $n = ([regex]::Matches($txt, [regex]::Escape($c))).Count
        if ($n -gt 0) {
            $idx = $txt.IndexOf($c)
            $linea = if ($idx -ge 0) { ($txt.Substring(0, $idx) -split "`n").Count } else { 0 }
            $comoSeEscribe = if ($malos[$cod] -eq 'ESC') { 'ESC' } else { [char]92 + [string]$malos[$cod] }
            $sucios += ("{0}: {1} x {2} (primero en la linea {3})" -f (Split-Path -Leaf $ruta), $n, $comoSeEscribe, $linea)
        }
    }
}
if ($sucios.Count -gt 0) {
    foreach ($su in $sucios) { Write-Host ("   MAL: " + $su) -ForegroundColor Red }
    Write-Host "   Un escape mal hecho dejo el caracter de control en vez de las dos letras. Reescribe esa linea." -ForegroundColor Red
    $fallos++
} else {
    Write-Host "   ninguno: lo que se lee es lo que hay" -ForegroundColor Green
}

Titulo "2n77. Que el log no se llene de la misma linea (y los comentarios no mientan)"
python (Join-Path $PSScriptRoot 'probar-log-que-no-crece.py')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:dicen la verdad)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n76. Que el propio banco diga de que seccion viene cada fallo"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-veredicto.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:de que seccion viene cada fallo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n80. Que Nova decida con datos de ahora, y llegue a contarlo"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-decide-con-datos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:datos de ahora)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n79. Los ficheros por los que se hablan los tres procesos"
powershell -NoProfile -File (Join-Path $PSScriptRoot 'probar-ficheros-compartidos.ps1')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:nadie bloquea el cambio atomico)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n78. Que los bancos midan ESTE repo, en orden y sin etapas mudas"
python (Join-Path $PSScriptRoot 'probar-bancos-de-verdad.py')  2>>$script:errBanco| Select-String -CaseSensitive '(?i:sin etapas mudas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "7. Bancos que llaman a funciones que no han traido (ROJO si los hay)"
# No es un detalle de estilo: un banco asi no prueba lo que dice probar. probar-json-ui
# soltaba 16 de estos por pasada y salia en verde; probar-costumbres estuvo un dia
# entero comprobando una funcion que no existia. Lo que se mira es la SALIDA DE ERROR
# que fueron dejando los bancos de arriba, no una lista escrita a mano: asi vale
# tambien para el banco que alguien anada manana.
if (Test-Path -LiteralPath $script:errBanco) {
    $lineasErr = @(Get-Content -LiteralPath $script:errBanco -ErrorAction SilentlyContinue)
    $noExiste = @($lineasErr | Select-String -Pattern "CommandNotFoundException" -SimpleMatch)
    # LO QUE NO ERA "FUNCION QUE NO EXISTE" TAMBIEN CUENTA (22/09, idea 8). Esta seccion
    # miraba UN SOLO patron. Cualquier otra excepcion -un JSON roto, un fichero que no esta,
    # python que revienta al importar- pasaba de largo, la seccion se pintaba en VERDE
    # diciendo "todos los bancos ejecutan de verdad lo que dicen", y la linea de abajo
    # BORRABA el fichero: el unico rastro del fallo se destruia en la misma pasada que lo
    # producia. Y no asomaba por ningun otro lado, porque 95 de las 98 secciones filtran su
    # salida con Select-String y un banco muerto no imprime ninguna de las palabras buscadas.
    # No se intenta clasificar linea por linea -un error de PowerShell ocupa seis lineas y se
    # parte solo por el ancho de la consola, asi que cualquier filtro fino se equivoca-:
    # basta con saber si quedo ALGO escrito ahi, y ensenarlo.
    $conAlgo = @($lineasErr | Where-Object { ([string]$_).Trim() })
    if ($noExiste.Count -gt 0) {
        $quienes = @($lineasErr | ForEach-Object { if ($_ -match "El t.rmino .([A-Za-z]+-[A-Za-z]+).") { $Matches[1] } } | Sort-Object -Unique)
        Write-Host ("   MAL: " + $noExiste.Count + " llamada(s) a funciones que el banco no trajo: " + ($quienes -join ", ")) -ForegroundColor Red
        Write-Host "   Ese banco NO esta probando lo que dice probar. Traela con Traer/TraerFn, o ponle un sustituto." -ForegroundColor Red
        $fallos++
    } else {
        if ($conAlgo.Count -eq 0) {
            Write-Host "   ninguno: todos los bancos ejecutan de verdad lo que dicen" -ForegroundColor Green
        } else {
            # NI VERDE NI ROJO (22/09, idea 8): ninguna llamada a una funcion sin traer, pero
            # algo solto esas lineas por la salida de error. El verde entero aqui seria mentira.
            # EN AMARILLO Y NO EN ROJO, igual que la seccion 6: por aqui pasa tambien ruido
            # legitimo (avisos de python, barras de progreso), y un rojo que sale siempre se
            # aprende a ignorar, que es la unica forma de matar un aviso. Cuando se haya visto
            # en unas cuantas pasadas que aqui no cae ruido, se sube a rojo.
            Write-Host ("   AMARILLO: ninguna funcion sin traer, pero quedaron " + $conAlgo.Count + " linea(s) en la salida de error. Algun banco pudo morir a medias:") -ForegroundColor Yellow
            foreach ($oL in ($conAlgo | Select-Object -First 12)) { Write-Host ("      " + $oL) -ForegroundColor Yellow }
            if ($conAlgo.Count -gt 12) { Write-Host ("      ... y " + ($conAlgo.Count - 12) + " linea(s) mas en el fichero") -ForegroundColor Yellow }
            $avisosAmarillos += ("" + $conAlgo.Count + " linea(s) en la salida de error de los bancos (quedan en " + $script:errBanco + ")")
        }
    }
    # EL FICHERO SOLO SE BORRA SI NO QUEDABA NADA QUE MIRAR (22/09, idea 8). Antes se
    # borraba SIEMPRE, tambien cuando dentro estaba la excepcion que acababa de matar a un
    # banco: el unico rastro desaparecia en la misma pasada que lo producia. Cuando esta
    # vacio -el caso de todos los dias- se borra igual que siempre, que no hay por que dejar
    # basura en TEMP.
    if ($conAlgo.Count -eq 0) {
        Remove-Item -LiteralPath $script:errBanco -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host ("   (la salida de error entera queda en " + $script:errBanco + "; borrala tu cuando la hayas mirado)") -ForegroundColor DarkGray
    }
}

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
# LA ULTIMA SECCION LA CIERRA EL VEREDICTO (22/09, idea 8). Titulo apunta la seccion anterior
# cuando arranca la siguiente, asi que la ultima que se ejecuta -la 7- no tiene detras ningun
# Titulo que la cierre. Se cierra aqui, justo antes de dar el veredicto.
if ($script:tituloActual -and $fallos -gt $script:fallosAlEmpezar) { $secFallidas += $script:tituloActual }
if ($fallos -gt 0) {
    # EL NUMERO SOLO NO SERVIA DE NADA (22/09, idea 8): con 104 sitios donde sube el contador,
    # "3 comprobaciones con problemas" obligaba a reejecutar secciones a ciegas hasta dar con
    # ellas. Ahora los nombres van debajo. La linea del numero se conserva PALABRA POR PALABRA
    # porque los cerrar-ronda*.ps1 de tmp la buscan tal cual con Select-String.
    Write-Host "$fallos comprobaciones con problemas" -ForegroundColor Red
    foreach ($sF in $secFallidas) { Write-Host "   - $sF" -ForegroundColor Red }
    exit 1
}
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
