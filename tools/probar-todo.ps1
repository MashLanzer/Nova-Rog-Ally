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
# LA VENTANA EN LA QUE EL CODIGO EXISTIA (24/09). Es la trampa que tumbo CUATRO conclusiones
# en un solo dia, y ninguna de las cuatro era un fallo de verdad:
#   - "el resumen al volver es un widget el 62 % de las veces": las 1.249 lineas caen enteras
#     en dos dias, 19 y 21/09, y desde el arreglo del 22/09 no hay ni una;
#   - "se muere catorce veces al dia": la linea "VoiceAssistant cerrado" no existia antes del
#     18/09 19:59, asi que nueve dias contaban arranques contra algo que no se escribia;
#   - "Nova avisa del ruido 31 veces": los 31 son del 22/09, el dia que se arreglo; despues, 6
#     y luego 0;
#   - "el filtro del repaso solo salto 4 veces mientras 120 candidatos pasaban": el filtro es
#     del 22/09 y los 120 son de antes; en SU ventana son 14 repasos, 5 tirados y 4 ahorrados.
# La regla, entonces: antes de decir que algo esta roto, mirar DESDE CUANDO existe el codigo
# -git log -S, o la fecha del comentario- y contar solo desde ahi. Si el fallo dejo de salir
# hace dias, la respuesta no es "esta roto": es "ya se arreglo". Un contador que cruza la
# fecha de su propio arreglo miente en la direccion mas cara, que es hacer trabajo de mas
# sobre algo que ya estaba bien.
# UN SCRIPT DE ROTURAS QUE SE INTERRUMPE DEJA EL CODIGO ROTO (25/09). Estos scripts aplican
# una rotura, corren el banco y RESTAURAN en un finally. Si se mata el proceso a mitad, el
# finally no llega a correr y la rotura se queda puesta en el archivo. Paso esta madrugada con
# voz_windows.py: quedo con un "return True" donde va la comprobacion de verdad, y el archivo
# seguia pareciendo sano -sintaxis correcta, todas las funciones en su sitio, el numero de
# llamadas exacto-. Solo lo caza correr el banco: por eso se corre SIEMPRE despues, y por eso
# la primera linea de cada script de roturas comprueba que el banco sale verde de partida.
# Si un script de roturas se interrumpe, hay que correr su banco antes de tocar nada mas.
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

Titulo "2n130. El audio atrasado que se tira, y que nadie miraba"
# El oido tira audio viejo 1.116 veces en el registro -6.563,6 s, casi dos horas de microfono
# a la basura- y hasta hoy no habia UNA sola comprobacion de eso. Reparto: transcripcion 604,
# oido fino 478, corte a mano 14, canary 10, fin de pausa 7, omni 3.
# Lo que decide que esto este bien: de 478 parejas "el modelo tardo X" -> "descartados Y",
# la mediana de Y/X es 0,96 y 423 de 478 (el 88 %) caen a menos de un segundo. O sea que lo
# que se tira es EXACTAMENTE la ventana en la que el hilo estuvo sordo, no audio vivo.
# Si descartara de menos, vuelven las activaciones fantasma, que es la regla 1 al reves.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-audio-atrasado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el audio de hace medio minuto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n131. Una regla que revienta ya no se pierde callando"
# Idea 14 de la tanda del 24/09. El 13/09 a las 16:22:01 braya dijo "cada 2 horas di que
# estire la espalda" -una regla valida- y el motor de reglas reviento; la frase siguio su
# camino como si no fuera una regla y dos segundos despues el pregunto "que reglas hay" y
# Nova le contesto "no tienes reglas". Creia haberla creado. Paso tres veces.
# EL NULL DE ENTONCES YA NO ESTA, y eso tambien se midio: cargadas las 528 funciones del
# archivo y pasadas las siete frases de regla del registro, ninguna lanza. Lo que se arregla
# es que el catch se tragaba cualquier fallo FUTURO y la frase se perdia en silencio.
# Lo que mas se vigila: que no se invente la regla, y que la forma de frase sea LA MISMA que
# usa la guarda de voz extrana doce lineas mas arriba; dos listas que dicen lo mismo en dos
# sitios acaban separandose.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-regla-rota.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:una regla que revienta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n132. Un recordatorio con la fecha rota ya no se borra solo"
# Idea 1 de la tanda nueva del 24/09. CERO lineas "RECORDATORIO vence" en las 54.428 del
# registro, con 295 recordatorios creados: ninguno ha sonado nunca. Y el del 12/09 16:59:48
# vencia el 13/09 a las 10:00:00 con Nova VIVA a esa hora exacta.
# El agujero estaba en una linea: 'try { $c = [DateTime]$r.cuando } catch { continue }'. Ese
# continue saltaba el 'else { $quedan += $r }' de abajo, y el Save-Recordatorios de dos lineas
# mas alla guardaba la lista SIN esa entrada. Una fecha ilegible no aplazaba el recordatorio:
# LO BORRABA DEL DISCO, sin escribir una linea. Y el llamador remataba con un catch vacio.
# Lo que mas se vigila: que no se borre, que la linea NO se repita en cada vuelta -el bucle
# pasa por aqui constantemente y eso es el fallo de los 25 avisos identicos del 22/09- y que
# un recordatorio bueno DETRAS de uno roto siga sonando.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-recordatorio-vivo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:un recordatorio con la fecha rota)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n133. No hablar por su cuenta mas que cuando la llaman"
# Idea 4 de la tanda nueva del 24/09. Del 19 al 24/09 hay 69 avisos por su cuenta contra 80
# veces que braya la llamo; antes del 16/09 -cuando nacieron- eran 0 contra 119. En una semana
# pasaron de no existir a casi igualar lo que el pide. Cada aviso por separado esta
# justificado; el problema es la suma, y nadie la miraba: el tope que habia son 4 POR HORA,
# que en un dia despierto dan hasta 64.
# El liston no es un numero nuevo, es una proporcion, y el suelo es el mismo $EntornoPorHora.
# Probado sobre los trece dias reales: corta 26 de 79 avisos y los 26 caen en los DOS dias en
# que sobraban (24 del 22/09 y 2 del 23/09). Ni uno de los seis dias buenos se toca.
# Lo que mas se vigila: justo eso, que los dias buenos no pierdan un solo aviso, y que lo de
# nivel 'alto' siga pasando siempre.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aviso-de-mas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no habla por su cuenta mas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n134. Un anuncio de YouTube no es una cancion"
# Idea 10 de la tanda nueva del 24/09. 5 de las 12 entradas de memoria\musica.json -el 41,7 %-
# son anuncios: Base44, Tripo AI, Firebase Brand Video, Copilot in Outlook e Introducing Grok
# Bot. El patron esta en el registro: 15/09 15:00:32 se abre YouTube, 15:00:39 suena "Copilot
# in Outlook", 15:00:49 la de Pitbull de verdad. Diez segundos de pre-roll.
# EL LISTON SE ELIGE SOLO: de las 13 lineas "MUSICA:" del registro, los cinco anuncios duraron
# 5 o 10 segundos y la cancion mas corta que sobrevivio duro 55. Entre 10 y 55 no hay NADA.
# Se puso 20, el doble del anuncio mas largo y menos de la mitad de la cancion mas corta.
# Lo que mas se vigila: que no se pierda una cancion de verdad. Tirar un anuncio no cuesta
# nada; tirar una cancion rompe "como se llamaba esa cancion", que es para lo que existe esto.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-musica-anuncios.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:un anuncio de YouTube ya no entra)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n135. El microfono ya no espera a que cargue el dictado"
# Ideas 14 y 15 de la tanda nueva del 24/09. Whisper se cargaba EN SERIE Y BLOQUEANDO, antes
# de abrir el stream de audio, y Vosk -que es quien oye "nova"- ya estaba cargado veinte
# lineas antes: el microfono esperaba 4,2 s de mediana, y hasta 117,9 s, a un modelo que solo
# hace falta al DICTAR. Suma de las 217 cargas del registro: 1.427 s.
# Los ocho arranques que pasaron de 30 s se miraron uno a uno: SEIS son un reinicio de
# desarrollo cayendo encima de un worker que aun cargaba, cinco de ellos el 16/09 entre las
# 20:13 y las 21:48, los minutos exactos de cinco commits. Y le costaron UN dictado: en los
# ocho huecos hay cero pulsaciones de boton, y el boton si se registra.
# Lo que mas se vigila: que el dictado ESPERE y no degrade. Con la carga en un hilo, "whisper
# vale None" pasa a significar a veces "todavia no", y caer a Vosk en silencio seria perder
# comprension justo en la meta del 100 %.
python tools\probar-arranque-oido.py 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el microfono ya no espera)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n136. Una toma saturada no se manda al agente a ver si adivina"
# Idea 12 de la tanda nueva del 24/09. Medido sobre los 886 dictados con texto: los 83 que
# traian un recorte en los 20 s previos fallaron el 42,2 % frente al 25,7 % de los otros 803.
# Es 1,64 veces peor, z~3,3, p<0,001. Pero no condena: 30 de esos 83 salieron BIEN, asi que el
# recorte no estropea la orden, la hace mas dificil.
# Lo que si era un fallo: 32 de los 35 acabaron escalando a opencode, o sea que una toma que
# Nova ya sabia mala se mandaba a un agente con manos a ver si adivinaba.
# Lo que mas se vigila: que esto NO se dispare cuando la orden SI se entiende. El recorte solo
# se mira en el camino de "no reconozco"; mirandolo antes serian 83 interrupciones en vez de
# 35, y la mayoria sin motivo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-toma-saturada.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:una toma saturada ya no se manda)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n137. Una regla, de punta a punta"
# Idea 3 de la tanda nueva del 24/09, y es de las cosas mas raras del registro: reglas.json
# esta VACIO, en quince dias braya creo DOS -una por voz el 11/09 que borro 31 segundos
# despues, y otra escrita el 14/09- y NINGUNA ha disparado jamas. Cero lineas de una regla
# ejecutandose en 54.428.
# No es que no sepa que existen -Nova se lo ofrecio cuatro veces-: es que le fallaron a la
# cara. Cada pieza del camino tenia su prueba; el camino COMPLETO, ninguna.
# Esto lo recorre entero: crear la regla por voz, guardarla, releerla del disco, dispararla
# cuando toca y -lo que mas importa- NO dispararla cuando no toca, que es la regla 1 rota de
# la peor manera posible porque braya ni siquiera ha hablado.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-regla-entera.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:una regla se crea, se guarda)|MAL'
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

Titulo "2n164. Contar lo que hizo mientras no estabas (idea 30 de las 50)"
# LO MEDIDO: el resumen al volver solo cuenta MENSAJES. Todas sus lineas del registro son de
# la misma forma -"Mientras no estabas: 1 mensaje de Discord", "3 mensajes"- y ni una dice
# nada de lo que hizo NOVA. Cuenta lo que paso, no lo que ella hizo.
# Y SI hace cosas: en la franja de 02 a 08 el registro tiene 302 avisos aparcados -118 del
# ruido, 118 del Gmail lleno, 66 del disco- y desde hoy tambien la copia de lo aprendido.
# Todo eso pasaba y nadie se enteraba nunca.
# LO QUE NO ES: un motivo para hablar. Va DESPUES del corte de "no hay nada que contar", asi
# que si no hay mensajes Nova no saluda solo para presumir de lo que hizo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-lo-que-hice.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que hizo mientras no estabas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n163. Trabajar cuando no molesta (idea 27 de las 50)"
# LO MEDIDO: de 2.166 ordenes en dieciseis dias, CERO caen entre las 02 y las 08. Seis horas
# muertas cada dia, y Nova esta DESPIERTA en esa franja -6.027 lineas de registro, en nueve
# noches distintas-: lo unico que hace es escuchar a nadie y aparcar avisos.
# Mientras, la copia de lo aprendido se ha hecho TRECE veces y las trece entre las 17 y las
# 22 h, que son las horas de mas uso (235 ordenes a las 18h). No es mala suerte: la copia se
# intenta EN EL PRIMER MINUTO TRAS ARRANCAR y braya arranca Nova cuando va a usarla.
# NO SE MIRA EL RELOJ: la franja de 02 a 08 es lo que hace HOY, y seria un numero inventado el
# dia que cambie de horario. Se mira si esta DELANTE. Y lleva plazo, que es la regla 2: pasadas
# 30 horas se hace igual, estorbe o no; una copia que no se hace nunca es perder lo aprendido.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-rato-tranquilo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:un rato que no moleste)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n162. Las dos frases que si se repiten"
# LO MEDIDO, y es mucho menos de lo que parecia: de las 1.842 frases que Nova dijo en el
# registro, las CUATRO mas repetidas son de UN SOLO DIA -el bucle de "Mientras no estabas" del
# 21/09, 774 veces-. Tanda de pruebas, no uso. Repartiendo por fecha, repetirse de verdad solo
# se repiten dos: "Hay un ruido de fondo constante..." (33 veces en 4 dias) y "Ya esta cargada
# del todo..." (20 en 8). Y son justo las que mas cansan, porque salen sin que braya pida nada.
# NO SE CONSTRUYE UN SISTEMA: el motor existe desde el 18/09 en Get-FraseVuelta -candidatas,
# filtrar las ultimas, Get-Random-. Solo faltaba sacarlo a una funcion y darles una bolsa.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-frases-variadas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no se repiten)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n161. Los logros que nadie ve (y una clave muerta de habitos.json)"
# LO MEDIDO: "LOGRO (stats de Steam cambiaron)" sale CINCO veces en dieciseis dias y ninguna
# desde el 20/09. Y NO esta roto: los .bin que vigila siguen cambiando, el mas reciente el
# 24/09 a las 22:41 (A Way Out). Son dos agujeros del mismo sitio:
#   1. la fecha del fichero vivia SOLO EN RAM, asi que un apagon la borraba: el 24/09 a las
#      22:41 Nova estaba apagada -no hay ni una linea entre las 21 y las 23 de ese dia-;
#   2. cada alt-tab hacia "logroArchivo = ''" y al volver la primera pasada solo apuntaba la
#      fecha y se iba con un return. El 23/09 hubo dos alt-tab en 70 segundos.
# Ahora la fecha se guarda en disco por juego y al volver se compara contra lo GUARDADO. La
# primera vez no canta, a proposito: una medalla por instalar Nova le quitaria credito al resto.
# Y DE PASO, FUERA habitos.minutosJuego: 89 bytes que se escribian y se leian de disco y que
# nadie usaba desde el 23/09, cuando la cuenta buena se mudo a juegos.json. Estaba congelada:
# no tenia entrada del 24/09 aunque ese dia se jugaron 116 minutos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-logros-steam.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no se pierden mientras no mira)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n160. El escalon de la cascada que no saca ninguna orden"
# LO MEDIDO: la cascada de repasos es canary -> base. En sus 18 usos REALES, canary NO ha
# sacado UNA SOLA orden. Y cuesta 3,3 s de mediana solo en cargarse mas 1,2-14,5 s de
# transcripcion; el peor, el 21/09 a las 23:40, fueron 23 segundos para devolver "Eh, no
# avisame cuando la descarga de de Sting termine", PEOR que lo que ya habia oido Parakeet.
# LO QUE NO SE HACE: apagar canary a mano. 18 no son 20, y DecisionMinIntentos son 20. Lo que
# se hace es poner el CONTADOR QUE FALTABA -la cascada no dejaba ni un numero con el que
# juzgarla- y meter el caso en la revision propia, que ya sabe apagar la nube y el oido fino
# con sus cuatro frenos. Nova lo decidira cuando tenga datos, y podra deshacerlo.
# Y EL ULTIMO ESCALON NO SE TOCA NUNCA: ese saca las ordenes de verdad (325 desenlaces por
# Whisper); quitarlo la dejaria sin red. Dos guardas distintas lo impiden.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-cascada-repasos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se puede juzgar sola)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n159. Lo que importo no se resume (idea 35 de las 50 / 18 de las 21)"
# LO MEDIDO: cada intercambio se apunta en bruto y al dia siguiente se resume en 2-5 vinetas y
# SE BORRA. En catorce dias eso ha convertido 342 turnos de conversacion en 29 vinetas y 2.866
# bytes; del 13, 19, 24 y 25/09 no hay ni vineta.
# Resumir esta bien para la mayoria -nadie necesita el bruto de "que hora es"-. Lo que esta mal
# es resumirlo TODO POR IGUAL. El 15 % de lo que dice braya son dos cosas que un resumen no
# puede reconstruir: cuando TE CORRIGE (41 frases: "No dije Discord, dije Steam") y cuando NOVA
# ADMITE UN AGUJERO (10: "No me has dicho nunca como se llama tu mascota"). Esos se copian a
# importante.jsonl, que no se poda. El bruto se sigue resumiendo y borrando igual que antes.
# La negacion larga se anadio midiendo: de las 66 frases que empiezan por "no", las de cinco
# palabras o mas son casi todas correcciones de verdad. Cinco es el liston, y esta medido.
# Y DESDE EL 27/09 (idea 68) el mismo banco cubre las correcciones que NO son charla: el juicio
# corre tambien en apuntar_hilo -por donde el asistente manda cada orden- y lo que llega con la
# charla dormida espera en hilo-pendiente.jsonl, que el worker vacia al arrancar. La regla sigue
# en un solo sitio: no hay copia en PowerShell que pueda separarse de esta.
python (Join-Path $PSScriptRoot 'probar-charla-importante.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sobrevive a la poda)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n158. El animo con memoria larga (idea 34 de las 50)"
# LO MEDIDO, y es peor de lo que decia la idea: el animo de hoy+ayer SALTA COMO UN YOYO.
#     23/09  +0,62      24/09  -0,50      25/09  +0,50
# Ese -0,50 del 24/09 no viene de un mal dia: viene de UN error y CERO aciertos, porque ese dia
# braya estuvo programando y casi no le hablo. O sea que el animo corto CONFUNDE "dia malo" con
# "dia vacio", y desde la idea 50 ese numero decide cuanto habla Nova por su cuenta.
# Ahora hay una ventana de 7 dias con peso decreciente y, sobre todo, UN DIA CON POCOS SUCESOS
# NO VOTA: eso es lo que separa el dia malo del dia vacio. La misma semana pasa a dar +0,66,
# +0,62 y +0,64. Y ademas sabe CONTARLO ("llevo unos dias entendiendote peor"), que es lo que
# separa un caracter de un termometro; se calla salvo que el salto sea grande y tenga base.
# TRES COSAS LAS CAZO ESTE BANCO, todas en codigo recien escrito: $AnimoLargoDias (la ventana)
# y $script:animoLargoDias (los que votan) eran LA MISMA variable para PowerShell; el detector
# que lo buscaba usaba un @{} cuyas claves tampoco distinguen mayusculas, o sea que tenia
# dentro el fallo que buscaba; y dos guardas no las ejercitaba ninguna prueba.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-animo-largo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:memoria larga, sabe contarla)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n157. El animo con el que se despierta (idea 15)"
# LO MEDIDO: el animo -de -1 a 1, sacado de los aciertos y errores de hoy y ayer- se calculaba
# DENTRO de Add-Estadistica, o sea solo cuando ya habia pasado algo. En 27.000 lineas aparecia
# en dos sitios: ese calculo y el "= 0" de la inicializacion. Al arrancar valia 0, viniera de
# donde viniera.
# Y NO ES UN ADORNO: desde la idea 50 el animo decide cuanto habla Nova por su cuenta. El
# arranque es su momento de MAS iniciativa -ahi salen los avisos que se quedaron esperando, la
# caida anterior, lo que no dijo a tiempo- y soltaba esa tanda creyendo venir de un dia neutro.
# No hubo que guardar nada: estadisticas.json lleva los dias desde el 11/09 y ya se carga al
# arrancar. Solo faltaba hacer la cuenta, y ahora se hace en UN sitio en vez de dos.
# Y UNA ROTURA DESTAPO UN CATCH MENTIROSO EN NUESTRO PROPIO CODIGO: devolvia 0.0, que es
# tambien la respuesta buena, asi que un animo roto era indistinguible de un dia tranquilo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-animo-arranque.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:de que dia viene)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n156. Los dos avisos de bateria que no sabian uno del otro (idea 7)"
# LA SOSPECHA ERA FALSA y conviene decirlo: la idea 7 decia "avisa aunque tengas el cargador
# puesto". Se midio y NO: las dos ramas miran $cargando antes de abrir la boca.
# LO QUE SI DESTAPO: habia DOS avisos para el mismo hecho a 66 lineas uno del otro, ninguno
# sabia del otro, y al cruzar el liston saltaban LOS DOS -aviso de prioridad alta por la cola
# Y la frase hablada-. Y el de arriba llevaba el 15 ESCRITO A MANO en vez de $BateriaAviso,
# asi que mover avisos.bateriaPct en config.json cambiaba uno y dejaba el otro en 15.
# NO SE MUEVE EL 15: para eso no hay datos -UN aviso en 16 dias, y las tres unicas lecturas de
# a que % enchufa braya son 97, 100 y 100-. Se reparten el trabajo: primero uno, luego el otro.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aviso-bateria.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se reparten el trabajo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n155. Que note a que estas jugando (ideas 17 y 38)"
# LO MEDIDO: memoria\juegos.json lleva 6 juegos con sus minutos por dia -ELDEN RING el 18, 19 y
# 20; Black Myth el 19; Unravel Two el 23- y ese fichero SOLO servia para contestar "cuanto he
# jugado". No decidia nada, no se comentaba nunca, no cambiaba una sola frase de Nova.
# Nova ya sabe cuando braya abre un juego, asi que con lo que YA esta en el disco puede decir
# algo que demuestre que se acuerda: "cuarto dia seguido con esto", "hacia 24 dias que no lo
# tocabas". Notar un cambio es lo mas parecido a prestar atencion que hay.
# LO QUE LO SEPARA DE SER UN PESADO: una racha se dice cuando LLEGA al minimo, no todos los
# dias; una vuelta solo si de verdad hacia mucho; y si ya jugo hoy, nada -si no, lo repetiria
# en cada arranque-. Va por Send-AvisoEntorno: con el juego delante se guarda, no interrumpe.
# Y UNA ROTURA ENSENO ALGO: hacer que contara CUALQUIER dia en vez de solo los consecutivos
# dejaba el banco verde entero, porque ningun caso tenia tres dias repartidos. Ahora lo hay.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-juego-notado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:nota a que estas jugando)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n154. Lo que dura un rato no ocupa una plaza (idea 4)"
# MEDIDO sobre el perfil real de braya: 21 de sus 57 datos -el 37 %- eran estados pasajeros
# guardados como si fueran rasgos: "esta en su cuarto", "acaba de completar un juego", "ha
# matado alrededor de veinte zombies en menos de veinte minutos", "usa espadas de metal en el
# juego". Ocupaban 21 de las 60 plazas de un perfil LLENO, expulsaban cosas que si valen y
# encima viajaban al cerebro en cada peticion.
# La guarda existia desde el 24/09 pero solo miraba lo que ENTRA; los que ya estaban dentro se
# quedaron dentro. Ahora salen del perfil que viaja y se quedan en la memoria permanente, que
# no tiene tope y no viaja: NO SE BORRA NADA, por eso puede hacerse sin preguntar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-perfil-pasajeros.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no ocupa una plaza)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n153. Las expresiones de los bancos que se rompen solas (idea 2)"
# EL PATRON: "que estas dos cosas esten a menos de 900 caracteres". Parece inofensivo y es una
# bomba de relojeria: el dia que alguien mete un comentario entre las dos, el banco se pone
# ROJO con el codigo perfectamente bien. Y un banco que se pone rojo solo entrena a ignorarlo.
# MEDIDO: 28 expresiones asi. DOS mordieron la madrugada del 25/09 -probar-log y probar-guia-
# solo porque se escribio un comentario dentro del bloque que miraban; y una tercera media 2200
# caracteres cuando la linea que importaba caia sobre el 2300, dejando pasar una rotura.
# NO SE PROHIBEN DE GOLPE -arreglar 28 a ciegas romperia comprobaciones que hoy funcionan- sino
# que hay un TECHO QUE SOLO PUEDE BAJAR, como esta casa trata estas cosas.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-bancos-fragiles.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:fragiles no crecen)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n152. El animo cambia lo que hace, no solo como se ve (idea 50)"
# Nova calcula un animo de -1 a 1 con sus aciertos y errores de hoy y ayer. Es un dato REAL...
# y hasta hoy solo servia para dos cosas de aspecto: el latido de la capsula y el color.
# LO QUE FALTABA era que le cambiara el COMPORTAMIENTO: si lleva un dia malo -o sea, si esta
# entendiendo mal a braya- lo ultimo que debe hacer es hablar MAS por su cuenta. Interrumpir
# mas justo cuando estas fallando es la peor combinacion. El dato que lo justifica: el 24/09
# hablo 21 veces por su cuenta por UNA que la llamaron.
# Los listones son los mismos que ya usa la capsula para apagarse o avivarse, asi que lo que se
# ve y lo que se hace cuentan la misma historia. Y lo critico pasa siempre.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-animo-consecuencias.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:cambia lo que hace)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n150. Lo que te prometio decir, se dice (idea 5)"
# MEDIDO: 4 avisos caducaron SIN DECIRSE desde que existe esa linea (24/09 01:38), dos de ellos
# la madrugada del 25. Y es feo por una razon concreta: esos avisos estan en la cola PORQUE
# Nova decidio no molestar en su momento y se prometio decirlos al volver. Tirarlos en silencio
# convierte la promesa en un agujero: ni entonces ni nunca.
# Ahora se dicen al caducar, JUNTOS en una frase -tres avisos viejos sueltos son tres
# interrupciones por cosas que ya pasaron- y diciendo que es tarde. Con nivel 'bajo': es algo
# que ya paso, no una urgencia.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aviso-caducado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:prometio decir, se dice)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n151. La noche es la tuya, no las once (idea 8)"
# El silencio nocturno estaba fijo de 23 a 8 mientras en el MISMO archivo existe
# Get-HoraFinHabitual, que saca de los habitos a que hora apaga braya de verdad y ya se usa
# para otra decision. Dos criterios para la misma pregunta, y el que callaba a Nova era el
# inventado. braya juega de noche -anoche le hablaba a las 2-, asi que un silencio que empieza
# a las 23 le callaba TRES HORAS UTILES.
# Sin datos suficientes (menos de 4 dias) sigue el numero de config, asi que el primer dia
# funciona igual que antes. Y se valida lo que ENTRA: 99999 minutos, con el modulo 24, darian
# "las 10", una hora perfectamente valida y perfectamente inventada.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-noche-tuya.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la noche es la tuya)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n149. Ningun worker residente se queda sin red (ideas 19 y 20)"
# voz_windows.py estuvo TRECE DIAS sin ninguna de las dos protecciones que tienen los demas
# workers, y nadie se entero hasta que habia 44 vivos comiendo 1,3 GB. No fue mala suerte: fue
# que NADA lo comprobaba. Ahora se comprueba: todo .py con un bucle que no termina solo tiene
# que leer por la tuberia (y morir cuando se cierre) o recibir NOVA_PID_PADRE.
# EL CRITERIO DE "RESIDENTE" COSTO DOS INTENTOS: mirar todo .py nombrado acusaba a
# ajedrez_turno.py, que se llama con "&" y no puede quedarse huerfano; mirar si el nombre esta
# cerca de un Start-Process dejaba fuera a casi todos, porque se lanzan por una variable. Lo
# que de verdad distingue a un residente esta en el propio worker: un bucle que no acaba.
# IDEA 20: la lista de los que se matan al salir se ampliaba A MANO y habia crecido tres veces
# en cuatro dias, siempre tarde. Ahora se construye sola con Get-Variable, asi que un worker
# nuevo entra el dia que se escribe. Probado ademas EN VIVO: con la marca de salida, el cierre
# limpio mato el oido y la voz y dejo su linea en el registro.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-residentes.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ningun residente se queda sin red)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n148. Cuando la capsula no se ve, no cuenta como salida"
# LO QUE PASO la noche del 24 con braya jugando: la capsula estaba en z=0 -por delante del
# juego-, visible, colocada y del tamano correcto, y NO SE PINTABA NI UN PIXEL. A Way Out
# estaba en pantalla completa EXCLUSIVA, y ahi ningun overlay de ventana se dibuja.
# COMO SE SABE: el modo exclusivo CAMBIA LA RESOLUCION DEL ESCRITORIO. Medido esa noche, el
# panel es 1920x1080 nativo y el escritorio estaba a 1280x720; el modo "sin bordes" no la
# cambia nunca. Con la capsula ciega, lo que solo va ahi no llega a nadie: regla 2 rota.
# Ahora Nova lo sabe, se lo dice a la propia capsula y VIBRA el mando en vez de callarse del
# todo -vibrar no saca a braya de la partida, que es lo que se evitaba al no hablar-.
# Y LA IDEA 6, de la misma medicion: braya cerro el juego a las 00:01:13 y veinte minutos
# despues la pantalla seguia a 720p. Ahora se lo dice. NO se la cambia sola: en una portatil
# bajar la resolucion a veces es deliberado, para bateria.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-capsula-ciega.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sabe cuando no se la ve)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n147. Los avisos que no te mueven se dicen menos"
# MEDIDO sobre los 81 avisos que Nova dijo de verdad en quince dias, mirando si braya le hablo
# en los cinco minutos siguientes: el ruido del micro son 32 avisos (40 % del total) y solo
# movio algo 2 veces (6 %); la bateria llena, 20 avisos (25 %) y 3 reacciones (15 %). Mientras,
# el correo de la manana y el aviso de juego cerrado tienen un 67 % de reaccion y se dicen tres
# veces cada uno. O sea que Nova gasta el 64 % de su voz en los DOS avisos que menos le mueven.
# LA SALVEDAD, escrita tambien en el banco: "hablarle despues" no mide todo -si apaga un
# ventilador sin decir nada, cuenta como que no reacciono-. Por eso NO se calla ningun aviso:
# se ESPACIA. Y hace falta un minimo de 8 muestras, un tope de 6 h y que lo critico ('alto') no
# se toque nunca.
# Y AMPLIADO CON LA IDEA 91 DE LAS 121 (27/09): miraba UN solo aviso en observacion y el
# siguiente lo pisaba. MEDIDO sobre los 103 avisos de los dos registros, 76 suenan y ONCE de
# esos 76 tienen otro que suena dentro de la ventana de 5 min (huecos de 14, 15, 15, 28, 50,
# 54, 77, 78, 209, 239 y 266 s): una medicion de cada siete se perdia, con 12 muestras
# guardadas en total. Y lo que pisaba era el aviso MENOS util -'oido-ruido' es el segundo en
# cinco de esos once pares-, o sea que el mecanismo que existe para espaciarlo se quedaba sin
# datos por su culpa. Ahora se guardan varios y el 'sirvio' va SOLO al mas antiguo: el empate
# se pierde a proposito, la muestra del que llevaba mas rato esperando no.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-avisos-que-sirven.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:aprende que avisos te mueven)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n145. Transcribir mientras braya calla (los 2,2 s que se perdian)"
# SU QUEJA, el 25/09: "se demora muchisimo en responderme y eso es desesperante". Y su
# pregunta: "como hace Alexa para contestar tan rapido".
# MEDIDO sobre 746 dictados: de "te escucho" a "ya tengo tu texto" pasan 10,0 s de mediana, de
# los que 5,5 son braya hablando y 2,8 los pone Nova. De esos 2,8, unos 2,2 son transcribir, y
# empiezan a contar CUANDO BRAYA YA CALLO: antes de eso el audio esta ahi, quieto.
# LO QUE HACE ALEXA es transcribir MIENTRAS hablas. Aqui se hace la version segura: Nova espera
# 1,5 s de silencio antes de cerrar la frase, y ahora usa ese rato para transcribir lo que ya
# tiene. Si lo unico que se anade despues es silencio, el trabajo ya esta hecho.
# NO CAMBIA NINGUNA DECISION, solo adelanta el calculo: si braya vuelve a hablar el adelanto se
# tira. Y no corre con un juego delante (regla 5) ni mientras Nova habla (se oiria a si misma).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-adelanto-oido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:transcribe mientras callas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n146. El perfil que viaja es el que viene a cuento"
# EL CASO, de braya esta noche: pregunto como se llama su mascota y Nova contesto "no me has
# dicho nunca como se llama tu mascota, asi que no lo se". El dato ESTABA en su perfil -la
# linea 27 de 60- y llevaba dias ahi. No lo vio porque al modelo de la charla solo le llegaban
# los QUINCE ULTIMOS datos (dp[-15:]), y el 27 de 60 no esta entre los quince ultimos.
# O sea que Nova sabia la respuesta y dijo que no la sabia: 45 de los 60 datos eran invisibles.
# Ahora se eligen los que comparten palabras con lo que acaba de preguntar y se rellena hasta
# quince con los mas recientes. Sin vectores ni nada caro: comparar palabras cuesta
# microsegundos y resuelve el caso que fallaba, que es preguntar POR algo que esta escrito.
python (Join-Path $PSScriptRoot 'probar-perfil-relevante.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el perfil que viaja)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n143. Nova se da cuenta de lo que ha dejado de hacer"
# EL DIARIO DEL DIA se escribio 10 veces entre el 10 y el 21/09 y NI UNA desde entonces: cuatro
# dias en blanco sin que saltara nada. Y no era que Nova estuviera apagada -la copia de lo
# aprendido siguio haciendose los 13 de 13 dias-: era esa costumbre concreta la que se rompio.
# POR QUE: el resumen vive dentro del worker de la charla y solo corre tras 20 min sin hablar Y
# con el revisor despierto, que se para en seco con un juego delante. Entre partidas y
# reinicios esa ventana casi nunca llega.
# LA IDEA: Nova ya vigila la bateria de braya, su disco y sus descargas; lo que no vigilaba era
# A SI MISMA. Avisa, no arregla: una costumbre rota puede tener diez causas y ponerse a
# adivinar es la clase de iniciativa que prohibe la regla 1.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-costumbres-propias.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se da cuenta de lo que ha dejado)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n144. Lo que oyo cada motor llega junto a Claude"
# LO PIDIO BRAYA el 25/09: "lo que entienden todos los modelos deberia enviarse y una IA como
# Claude debe armar la frase entera de ser necesario". El caso que lo motivo, esa misma noche:
# pregunto hace cuanto que un amigo se desconecto, Parakeet lo transcribio PERFECTO y Nova tiro
# ese texto porque "no cubre la voz" (3,8 letras por segundo contra un liston de 4,0: hablaba
# algo mas despacio de lo normal). Viajo la de Whisper, que convirtio el nombre en "base", y
# con eso dentro nadie podia hacer nada.
# MEDIDO: 29 descartes por cobertura en 514 transcripciones, y de los cuatro ultimos, en TRES
# la descartada era mejor. Dos de ellos, por DOS DECIMAS.
# Y SALE GRATIS: cuando el local no entiende, Nova YA llama a Claude para traducir (1,8 s de
# mediana). Mandarle las candidatas es la MISMA llamada con mas informacion.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-segunda-oreja.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:oyo cada motor llega junto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n142. Que Nova te diga que se cayo (y cuanto estuvo fuera)"
# EL CASO QUE LA ORIGINO: el 24/09 a las 21:53 Nova se murio de golpe mientras braya jugaba y
# estuvo muerta hasta las 23:33 -una hora y cuarenta-. No se entero por ella: se entero porque
# yo lo vi mirando procesos, y al volver ella le saludo como si nada. Un asistente que se muere
# y no lo cuenta obliga a vigilarlo, que es lo contrario de para lo que esta.
# EL RASTRO YA ESTABA en dos sitios: un "iniciado" sin su "cerrado" detras -el cerrado solo se
# escribe al salir por la puerta, asi que su AUSENCIA delata-, y la linea del oido, que si se
# entera: "el asistente ya no existe (PID N)", con la HORA EXACTA que la otra no tiene.
# LA VENTANA TEMPORAL ES LA CLAVE AQUI: la linea "cerrado" no existe antes del 18/09 17:06, asi
# que sin esa guarda Nova acusaria una caida por cada sesion de nueve dias, todas falsas.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-caida-anterior.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya te dice cuando se ha caido)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n141. La memoria que no se borra (y que no viaja al cerebro)"
# LO PIDIO BRAYA el 25/09: "haz una memoria permanente que guarde todo y no se mande al cerebro,
# y esta de 60 que siga asi, o sea temporal". Y tenia razon por donde no parecia: el perfil de
# 60 es lo que VIAJA -"va con CADA peticion al cerebro", dice su propio comentario-, 2.603
# caracteres y unos 723 tokens en cada una de las 186 consultas de quince dias. Por eso tiene
# tope. Pero que no pueda VIAJAR no obliga a PERDERLO: se aprendieron 91 datos y quedan 60, y
# entre los caidos estan los DOS UNICOS que braya enseno a mano.
# Ahora son dos ficheros: perfil.md sigue igual (60 plazas, viaja) y perfil-todo.md no tiene
# tope y NO VIAJA NUNCA. La seccion 3 del banco es la que importa: comprueba que el permanente
# no aparece en ninguno de los caminos por los que algo llega al modelo, porque el dia que
# alguien lo meta "para que Nova sepa mas", el coste por consulta se multiplica en silencio.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-memoria-permanente.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no se pierde, y sigue sin viajar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n138. Lo que espera no se reintenta siete veces por segundo"
# MEDIDO CON BRAYA JUGANDO, el 24/09 a las 23:49: 413 lineas identicas en el registro -"ENTORNO:
# 2 aviso(s) no cabian ahora"- a razon de SEIS Y SIETE POR SEGUNDO, y cada pasada reescribiendo
# memoria\avisos-espera.json en disco. La llamada estaba suelta dentro del "if (botones -ne 0)"
# de Watch-Entorno: su comentario dice "cuando braya vuelve", pero ese bloque corre con CADA
# rafaga del mando, que jugando es continua. Regla 5 rota por I/O en vez de por RAM.
# Ahora va detras de un antirrebote de un minuto, y la linea de registro solo sale cuando el
# numero CAMBIA. La pregunta por voz ("que me he perdido") no pasa por el freno y sigue
# contestando al momento; el banco comprueba las dos cosas por separado.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aviso-espera-ritmo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no se reintenta sin parar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n139. La capsula no puede robar el foco (sin audio en el juego)"
# LO CONTO BRAYA JUGANDO, el 24/09 a las 23:33: al reiniciar Nova con A Way Out abierto, el
# juego se quedo sin audio Y la capsula dejo de verse encima. Dos sintomas y una sola causa,
# medida con GetForegroundWindow: la ventana de delante era nova_ui, no el juego. Un juego que
# pierde el foco se silencia, y al recuperarlo se pone delante y tapa la capsula.
# EL CODIGO NO HABIA CAMBIADO (nova_ui.cs del 22/09 19:38, exe del 22/09 20:56): lo que cambio
# fue el ORDEN. Nova suele arrancar antes que el juego, y entonces no hay foco que robar.
# WS_EX_NOACTIVATE si estaba, pero se ponia en Loaded, que corre DESPUES de pintar la ventana.
# Ahora va tambien en SourceInitialized y, sobre todo, ShowActivated = false.
# LA COMPROBACION QUE MAS VALE es que el .exe se haya compilado DESPUES del .cs: el binario va
# versionado, asi que se puede arreglar el codigo y dejar corriendo el de antes.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-capsula-foco.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no roba el foco)|MAL|SALTADA'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n140. Los workers que sobrevivian a Nova (44 vivos, 1,3 GB)"
# EL PEOR FALLO DEL DIA, y no lo encontro ningun banco sino un aviso de memoria baja de
# Windows: el 24/09 a las 21:53 Nova murio de golpe mientras braya jugaba a A Way Out, y media
# hora despues habia 44 procesos voz_windows.py vivos comiendo 1,3 GB. La maquina ve 11,70 GB
# y el juego usaba 1,9; quedaban 0,70 GB libres. Regla 5 de la casa: nada residente comiendo
# RAM que le hace falta al juego.
# TRES AGUJEROS A LA VEZ: el worker no miraba si su padre seguia vivo (wake_vosk.py si lo hace
# desde el 13/09), el "parar limpio" no lo mataba -era el unico residente al que no mataba
# nadie- y el barrido del arranque no lo nombraba. En la ventana justa -desde que existe la
# linea "cerrado", el 18/09 a las 17:06- hay 61 arranques y 35 cierres limpios: 26 cierres
# sucios en seis dias, y en un cierre sucio PowerShell.Exiting no dispara por definicion.
# ESTA SECCION TARDA ~40 s A PROPOSITO: arranca un worker de verdad con un padre de mentira,
# lo mata y mira si el hijo se cierra solo. Mirar el codigo no habria valido: la primera
# version de este banco daba por muerto un worker vivo porque no cogia el Handle.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-huerfanos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no sobreviven a Nova)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n166. La correccion que niega lo mal oido (no dije Discord, dije Steam)"
# EL PEOR FALLO QUE HABIA VIVO ESTA MANANA, y no lo encontro ningun banco: estaba escrito en
# el registro y en disco. El 25/09 a la 01:26:11 la API tradujo un 'Cierra este in.' mal oido
# -era "cierra Steam"- a 'cierra discord', y un segundo despues Nova lo APRENDIO PARA SIEMPRE.
# A los diecisiete segundos braya dijo "No dije Discord, dije Steam", Nova contesto "Tienes
# razon, mi mal"... y no deshizo nada: la traduccion seguia en traducciones.json hoy,
# apuntando a la aplicacion por la que habla con su pareja. Pidio cerrar Steam CUATRO veces
# entre las 01:25:37 y las 01:27:03 y no lo consiguio ni una.
# DOS FALLOS, no uno: el patron capturaba desde el PRIMER "dije" -sacaba 'discord dije steam'-
# y, como eso no resuelve a ninguna orden, se saltaba el bloque entero y se perdia tambien el
# DESHACER. Una correccion a medio entender acababa en ninguna correccion.
# MEDIDO sobre los 633 dictados distintos de assistant.log y su rotado: las dos formas nuevas
# cogen EXACTAMENTE las dos correcciones de verdad que hay y ninguna de las otras 631; las
# cuatro que se parecen y no lo son estan en el banco como casos negativos.
# Y NO SE ADIVINA EL VERBO: de "no dije Discord, dije Steam" sale 'steam' a secas y Nova
# deshace y olvida, pero no abre Steam por su cuenta (regla 1, igual que "abre este").
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-correccion-niega.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:deshace, olvida y no se inventa el verbo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n167. Un veto de musica para siempre, de una frase mal oida"
# DE LA MISMA NOCHE Y DEL MISMO 'cierra Steam'. memoria\musica-no.json ha tenido UNA sola
# entrada en su vida y era basura: 'si es resting', del 25/09 a la 01:25:40, de un "No, no
# quiero, Cierre Sting, Paul" que canary "mejoro". Nova contesto "no te pongo mas resting" y
# lo guardo para siempre, sin preguntar.
# DOS AGUJEROS: de las cuatro maneras de vetar, tres hablan de gustar o de poner y la cuarta
# era "no quiero", que es una negativa de CUALQUIER cosa -contado sobre los 633 dictados casa
# con UNA frase en catorce dias, y tampoco es musica: "no quiero saber que se esta descagando
# en steam"-. Cero vetos buenos, dos malos. Y este camino no tenia la guarda de "no aprender
# de lo mal oido" que las traducciones llevan desde el 15/09.
# El banco EJECUTA la rama de verdad sacada del archivo, no mira su forma: con el oido dudando
# no se guarda nada, con el oido limpio si, y la guarda tiene que ir ANTES de escribir.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-musica-no-guarda.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no deja un veto de musica para siempre)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n168. La pregunta de los amigos, como la dice braya"
# LO CARO ESTABA HECHO Y NO SE USABA NUNCA. Los tres patrones de "amigos conectados" iban
# anclados en ^ y $ -la frase tenia que EMPEZAR por quien/quienes/hay algun amigo/que amigos y
# ACABAR ahi-, y contado sobre los 633 dictados distintos de assistant.log y su rotado cogen
# CERO de las tres veces que lo ha preguntado en catorce dias. Mientras tanto,
# Start-AmigoPregunta, Receive-AmigoPregunta y Format-AmigosSteam estaban escritos y la clave
# de Steam puesta desde el 24/09: las dos veces que lo pidio (25/09, 01:19:52 y 01:22:41) la
# frase se fue al agente, que abrio Steam y pincho la pantalla con el raton -48,7 s y 70,5 s
# contra ~166 ms de la peticion-. Braya lo dijo el solo a las 01:21:18: "no se supone que
# tienes una API para hacer todo eso".
# AHORA VA POR CONCEPTOS: nombra a un amigo Y habla de estar conectado, en doce palabras o
# menos. El tope separa la PREGUNTA de la QUEJA: la de 32 palabras lleva las dos ideas dentro
# y no pide nada. Medido: 3 de 3 cogidas, 0 coladas de 633.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-amigos-como-lo-dice.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:entra como la dice braya)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n169. Muevete a la derecha: una sola coordenada, y la coletilla"
# LOS DOS PATRONES DE ESQUINA EXIGIAN LAS DOS COORDENADAS JUNTAS y acababan anclados, asi que
# ni una sola ni "de la pantalla" detras. Contado sobre los 633 dictados distintos de
# assistant.log y su rotado, braya lo ha pedido CUATRO veces y las cuatro con una sola
# coordenada: no entraba ninguna. Tres de las cuatro llevan delante algo que $FILLER_INI no
# quita ("exacto", "no no", "tu"), y por eso el patron nuevo admite ese arranque: se puede
# hacer aqui y no en la lista general porque mover la capsula no borra, no cierra y no gasta.
# La coordenada va al FINAL, que es lo que impide robarle la frase a "mueve X a la carpeta Y" y
# a la pantalla partida. Medido: 4 de 4 cogidas, 0 coladas de 633.
# Y SOLO SE MUEVE LO QUE SE DIJO: la otra coordenada se copia de donde este ahora.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-esquina-una-coordenada.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:mueve solo esa coordenada)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n170. La pregunta que se comia el nombre de la variable"
# EN POWERSHELL 5.1 LA INTERROGACION ES UN CARACTER VALIDO DE NOMBRE DE VARIABLE, asi que
# "$jg?" dentro de una cadena no es el valor de $jg y una interrogacion: es la variable $jg?,
# que no existe, y la frase sale VACIA. Ya mordio en la auditoria del 13/09 -de ahi el
# comentario que hay en la frase de "no era eso"- y volvio a colarse en el saludo de vuelta.
# SALIO EN PRODUCCION: assistant.log:6458, 25/09 10:57:58, "VUELTA: 71 min fuera -> '¿Seguimos
# con '". De las tres variantes del saludo de vuelta esa es la UNICA que usa la continuidad -a
# que estabas jugando- y no habia funcionado NUNCA. Y la frase rota se GUARDO en
# memoria\habitos.json, donde ocupaba una plaza del filtro de no repetir y le quitaba el turno
# a las que si funcionan.
# EL BANCO NO MIRA UNA FRASE, MIRA EL PATRON: demuestra el fallo ejecutando PowerShell, saca la
# plantilla del archivo de verdad, y barre los 186 .ps1 del proyecto buscando mas. Arreglar el
# caso y no la clase es como no arreglarlo: ya iban dos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-interrogacion-variable.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se come el nombre de la variable)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n171. La regla 6 de la casa, que no vigilaba nadie"
# LA REGLA: los .ps1 van SIN BOM si son ASCII puro y CON BOM si llevan algo que no lo es,
# porque PowerShell 5.1 abre un .ps1 sin BOM como ANSI y no como UTF-8. Un fichero con una
# sola letra rara y sin BOM se lee con las letras cambiadas: el mismo tipo de fallo que el
# 0x08 de la seccion 8, se lee bien y no es lo que hay.
# COMO SE DESTAPO: escribiendo un banco nuevo hoy se colo uno asi -no ASCII y sin BOM- y esta
# bateria entera paso en verde sin decir una palabra. Ninguna de las 204 secciones lo miraba.
# LO QUE SE EXIGE Y LO QUE SOLO SE CUENTA: rojo si hay uno con letras raras y sin BOM (hoy
# cero); un BOM de mas sobre ASCII puro se dice y no rompe, porque PowerShell lo lee igual de
# bien y pedir esa limpieza no arregla nada. Y las tildes van con TRINQUETE: hay 28 ficheros
# que las llevan de antes, no se exige quitarlas, pero el numero solo puede bajar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-regla-seis.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se lee distinto de como esta escrito)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n172. Saludar a una habitacion vacia no es estar viva, es ruido"
# LO MEDIDO sobre assistant.log y su rotado: 213 "saludo de arranque" en 16 dias. Es, con
# diferencia, lo que mas dice Nova por su cuenta. De esos, 59 (el 28 %) se dijeron sin UNA SOLA
# senal de braya en media hora a cada lado, y 87 (el 41 %) sin ninguna en diez minutos; y estan
# repartidos en DOCE dias distintos, asi que no es una tanda de pruebas. La causa ya estaba
# contada: el 84 % de los arranques cae a menos de 30 min de un commit, o sea que la mayoria son
# reinicios de desarrollo y no braya sentandose.
# POR QUE NO BASTABA LO QUE HABIA: Get-AusenciaMin mide desde la ultima senal que le llego A
# NOVA y lleva un suelo de "arranque + 60 s", asi que al arrancar la ausencia vale CERO por
# construccion. Nova daba por hecho que braya estaba delante siempre que acababa de nacer, y
# nace 10-15 veces al dia. Ahora se lo pregunta a Windows: cuanto hace que alguien toco el
# teclado, el raton o el mando EN LA MAQUINA, viva Nova o no.
# EL LISTON NO SE INVENTA: es $AvisoEsperaMin, los mismos 30 minutos con los que ya decide "no
# hay nadie" para aparcar un aviso. Y callada no es desaparecida: el saludo se ve en la capsula.
# LO QUE MAS VIGILA EL BANCO: que un fallo de la llamada al sistema devuelva -1 ("no lo se") y
# Nova SALUDE. Callarla por una medicion fallida seria peor que el ruido que se quita, y ese
# camino se ejercita de verdad, con un tipo senuelo que hace reventar el P/Invoke.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-saludo-vacio.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no se dice a una habitacion vacia)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n173. El cuaderno de la Ally: que se hace con ella, hable braya o no"
# LO PIDIO BRAYA ASI: "a veces no hablo con nova pero paso horas con ella jugando o encendida o
# haciendo cosas, y eso nova deberia saberlo tambien, ya que ella tiene que controlar toda la
# Ally, es literalmente el cerebro que le estoy creando".
# LO MEDIDO: Nova ya miraba que hay en primer plano cada 10 s, pero solo se quedaba con ello si
# era un JUEGO; de lo demas no guardaba nada. Y el unico motor que podria proponerle algo
# -Find-Propuesta- come de habitos.usos, que son ORDENES DE VOZ: 34 entradas de 27 tipos
# distintos en 6 dias, asi que su condicion de "lo mismo a la misma hora en tres dias" no se
# cumple jamas y no ha propuesto NADA. Mientras tanto la consola deja 49 comienzos de juego en
# 10 dias, 169 sucesos de cargador y 211 de descargas, y de 737 dictados NI UNO pide una regla.
# LA DISTINCION QUE LO DECIDE TODO, y la puso el propio braya: "la consola esta encendida tambien
# porque tu estas trabajando ahi". ENCENDIDA NO ES EN USO. Cada tramo cae en una de dos cuentas
# que NO se suman -"con" alguien tocando algo, "sin" nadie- y si no se puede saber, no se apunta
# en ninguna: inventarse que hay alguien seria peor que perder diez segundos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-uso-ally.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:apunta lo que se hace con la Ally)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n224. Dejar de reintentar a ciegas el resumen del diario (idea 60 de las 121)"
# El spam ('no pude resumir' cada 65 s, 71 lineas el 26/09) ya lo arreglo la idea 14 (backoff +
# avisar una vez). Faltaba la regla 2: pasadas 6 h sin poder resumir un dia, volcar sus frases en
# bruto al diario ('sin resumir todavia') para no perderlo -una vez por dia-, y sustituirlo por las
# vinetas cuando ollama vuelva. Dos bancos: volcar_crudo_pendiente (py) y Add-DiarioResumen (ps).
python (Join-Path $PSScriptRoot 'probar-diario-crudo.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el dia sin resumir se vuelca en bruto a tiempo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-diario-crudo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el diario en bruto se sustituye por el resumen)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n223. La voz de lo que ya esta escrito y esperando su turno (idea 59 de las 121)"
# Los avisos del entorno se aparcan con el texto YA escrito y al soltarse pagaban ~974 ms de red
# delante de braya (frente a 5 ms si ya estaba hecha). Ahora, al aparcarse, se manda al worker de
# voz preparada (prioridad baja, cache md5): solo cuando Add-AvisoEspera devuelve true (no en cada
# vuelta), solo los 'medio' que si se dicen, nunca con juego. El parte de la manana NO (se muestra,
# no se dice). El banco ejecuta Send-AvisoEntorno con Send-PrepVoz doblado.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-voz-aparcada.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la voz del aviso aparcado se prepara sola)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n222. Que el recuerdo guarde tambien la frase con la que tu lo dijiste (idea 58 de las 121)"
# Los recuerdos los escribe la API en tercera persona y con sus palabras; braya con las suyas y
# en trozos. Por eso la busqueda por palabras casi nunca los encuentra (97 de 121 no salen ni una
# vez en 365 turnos). La frase de braya ya esta en la mano al guardar (job.pregunta): se deja como
# variante, con guarda de >= 3 palabras de contenido para no ensuciar la busqueda. Ejecuta el Cerebro.
python (Join-Path $PSScriptRoot 'probar-recuerdo-variante.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el recuerdo se encuentra por tus palabras)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n221. Su IP ya no sale en claro: ip-api por https y contar dias iguales (idea 57 de las 121)"
# De los 8 destinos externos, ip-api.com era el UNICO por http:// sin cifrar (los otros 7 por
# https): la IP publica de braya viajaba en claro una vez al dia. Ahora https, y se cuenta cuantos
# dias seguidos da la misma ciudad ('iguales' en ubicacion.json) para dejar de preguntar mas
# adelante -aun no se actua: sin racha medida no se fija el numero (regla 3) y falta detectar el
# viaje-. El banco es un guardarrail: ninguna llamada externa en claro en las cuatro fuentes.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-clima-privado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ni una llamada externa va en claro)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n220. Cuando Nova se disculpa, que lo apunte ella misma (idea 55 de las 121)"
# De 542 respuestas de la charla en 14 dias, 31 admiten un error ("tienes razon, me equivoque").
# Esa admision la escribe Nova, no braya, asi que no se confunde con una charla que empieza por
# "no". Cada turno asi queda como sospecha (senal 'me-disculpe', peso 'medio') con la frase de
# braya. Dobla el corpus de sospechas. El banco ejecuta Write-FalloDeducido y saca el patron del
# propio assistant.ps1; deja fuera las disculpas por limitacion ("lo siento, no tengo informacion").
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-disculpa.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:cuando Nova se disculpa, lo apunta ella misma)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n219. Lo que Nova hace sola se ve igual que lo que le pediste: campo 'mia' y marca en la capsula (idea 54 de las 121)"
# 100 avisos de entorno en 11 dias se veian exactamente igual que una respuesta a una orden;
# ninguna de las 35 claves del JSON decia de quien fue la idea. Ahora Set-UI escribe "mia",
# Send-AvisoEntorno/Invoke-Reglas la encienden, una orden de braya y el vuelta-a-reposo la apagan
# (regla 2), y la capsula tine 'hablando' de ambar y pone un aro sobre el glifo. El banco ejecuta
# el aviso de entorno de verdad y mira el sitio exacto en Invoke-Reglas, Process-Texto y nova_ui.cs.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-capsula-mia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que Nova hace sola se marca en la capsula)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n218. Olvidar un alias que aprendio Nova: darle marcha atras a commands.json (idea 53 de las 121)"
# commands.json era el UNICO sitio donde lo aprendido no tenia marcha atras. En 15 dias Nova
# escribio UN alias, y fue el envenenado ('ajutos' la noche del 22/09). Ahora Add-Alias-Comando
# marca su origen (aliasNova), "no era eso" lo borra (Invoke-AprenderDelError) y "olvida que X es Y"
# a viva voz tambien; nunca toca lo que puso braya a mano. El banco ejecuta las tres funciones (AST).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-alias-olvido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:un alias aprendido se puede olvidar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n217. El cuaderno de la Ally se quedaba a medias en cada apagada (idea 52 de las 121)"
# Save-UsoAlly solo bajaba a disco al juntar 300 s; 35 de 71 sesiones (49 %) morian sin cierre
# limpio y 10 no llegaban ni a 300 s, perdiendo entera su cuenta. Dos vias nuevas (regla 7): el
# manejador de salida vuelca uso-ally y tiempo-de-juego al cerrar, y el bucle de 10 s vuelca cada
# 90 s (percentil 10 de vida de sesion, por encima del suelo de 60). No estrena coste: los Save-*
# ya salen sin escribir si no hay nada pendiente. El banco ejecuta el manejador y el bloque del bucle.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-uso-ally-volcado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el cuaderno de la Ally se vuelca al salir y por reloj)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n245. Dos de las cinco lineas de temas del prompt decian lo mismo (idea 94 de las 121)"
# En el prompt de cada charla viajan los cinco temas mas contados, y eran videojuegos (63),
# comunicacion (26), clarificacion (10), steam (10) y videojuego (10): una plaza gastada en repetir
# el primero en singular, y el tema que se quedaba fuera era real (roblox, 6). Y los 30 temas estan
# en su tope, asi que cada tema nuevo echa a otro y una plaza gastada cuesta el doble. Pasados los
# 30 por clave_tema salen 29 grupos: la UNICA pareja que se junta en todo el cerebro es esa, y
# estaba en el prompt dos veces. Se agrupa por raices EN ORDEN, no en conjunto como pedia la ficha,
# asi que 'juegos de mesa' y 'mesa de juegos' siguen siendo dos temas.
python (Join-Path $PSScriptRoot 'probar-temas-juntos.py')  2>>$script:errBanco| Select-String 'MAL|no gastan dos plazas'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n244. Que aprenda que fichero no la deja cambiarlo de golpe (idea 93 de las 121)"
# 37 fallos 'escritura atomica fallida ... [WinError 5] Acceso denegado' en ocho dias distintos: 21
# de ui-nivel.txt, 14 de dictado-parcial.txt y 2 de escucha-estado.txt. Y el 22/09 esto se dio por
# arreglado -se anadio FileShare.Delete en los dos lectores- y DESPUES hay TRECE mas: 2 el 23/09, 2
# el 24/09, OCHO el 25/09 y uno el 27/09. El arreglo no lo arreglo, y con el tope de 50 avisos por
# proceso 37 es un suelo. Ahora, al tercer fallo del MISMO fichero, ese pasa a escritura directa el
# resto de la sesion: no se pierde nada -en esos 37 casos ya se escribia directo- y se quita la
# excepcion, el aviso y el reintento en cada palabra que se oye.
python (Join-Path $PSScriptRoot 'probar-escritura-directa.py')  2>>$script:errBanco| Select-String 'MAL|cada fichero aprende'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n243. Lo que dice otra persona no se escribe en el registro (idea 90 de las 121)"
# Con la voz ajena Nova ya hacia lo correcto TRES veces -no guarda el wav, no lo manda al agente
# y no aprende nada- y acto seguido la escribia ENTERA. ONCE lineas de conversacion de otra
# persona guardadas literal, 689 caracteres, la mas larga de 174. Y eran TRES sitios, no uno: el
# registro, la lista de descartes que sale en memoria\estadisticas.md y el registro de uso. El
# bloque de verdad se saca del fichero y se EJECUTA; y el caso contrario tambien se vigila -con
# la voz de braya el texto se sigue escribiendo, que ahi es lo que explica el descarte-.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-voz-ajena-callada.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que dice otra persona ya no se escribe)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n242. Las palabras que eran la orden, no la frase entera (idea 89 de las 121)"
# En 14 dias la nube tradujo 58 frases y 57 eran DISTINTAS: braya no repite frases, repite
# intenciones con otras palabras. Por eso el aprendizaje de frase entera dio 21 traducciones y
# UNA usada en su vida. Ahora, cuando dos frases distintas acaban en el mismo destino, lo que
# comparten se guarda como firma. MEDIDO sobre esas 58 y sin adornos: se habria ahorrado UNA
# llamada, no las tres de la ficha. Y las guardas salen de los mismos datos: con firmas de UNA
# palabra, {cierra} cerraria todos los programas al oir 'cierra steam' y {ring} CERRARIA elden
# ring cuando se pide abrirlo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-firmas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:las firmas aprenden las palabras)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n241. La tabla de atragantos tenia tres filas y ninguna era una orden (idea 88 de las 121)"
# Las tres filas eran: una frase que llegaba a 2 porque una tilde duplico el descarte, la ETIQUETA
# interna 'dictado vacio' -que la tabla pedia ensenarle a Nova- y holandes de un video de fondo. Y
# por texto exacto no habia nada que encontrar: 'recientes' cubre 38 minutos, los descartes borran la
# entrada identica al reanadir, y las 34 frases que acabaron en nada son 34 distintas. Ahora 'error'
# no entra y las frases se agrupan por PARECIDO con las dos distancias que ya existen, ensenando
# debajo el texto crudo de cada forma para que un grupo falso se vea de un vistazo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-atragantos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la tabla de atragantos agrupa por parecido)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n240. Las correcciones de oido se ganan del uso, no se escriben a mano (idea 87 de las 121)"
# De las 110 correcciones foneticas escritas a mano en commands.json, solo NUEVE han aparecido
# alguna vez en algo que Nova oyera; 101 no se han usado nunca. Y las que si pasan no estaban.
# Ahora se aprenden del uso con DOS testigos de fuentes distintas: la correccion hablada (en vivo) y
# Vosk oyendo el verbo bien cuando el entregado lo trae mal (del registro, una vez al dia). Los
# filtros son los de la casa contra el caso 'ajutos', y lo escrito por braya manda siempre. Medido
# en su registro: 3 candidatos apuntados, ninguno activo todavia -les falta el segundo testigo-.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-oido-aprendido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:las correcciones de oido se ganan del uso)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n239. La franja en la que nunca estas, calculada por ella misma (idea 86 de las 121)"
# El dia de braya empezaba a las 5 porque alguien lo escribio, y el AddHours(-5) estaba a mano en
# SIETE lineas -seis sin llamar a Get-DiaJuego, que existe para eso-; y el fin del silencio nocturno
# era un 8 fijo mientras el principio si se aprendia. Datos: 0 de 714 ordenes entre las 02:00 y las
# 08:59 en 13 dias. Ahora Nova calcula su franja muerta (la racha mas larga sin NADA): con sus
# ficheros de hoy va de las 2 a las 9, asi que el dia parte a las 5 -el de siempre, no cambia nada-
# y el silencio acaba a las 9. Se calcula una vez al dia y no se mueve a media sesion.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-franja-muerta.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la franja muerta sale de sus horas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n238. El cuaderno de activaciones que solo abria el borrador (idea 85 de las 121)"
# Cada vez que Nova se despierta apunta 14 datos, incluido EN QUE ACABO, y el fichero aparecia tres
# veces en todo el repositorio fuera de los bancos: quien lo escribe y quien lo BORRA. Leidas sus
# 125 lineas de 8 dias: 79 acabaron en orden y 46 en nada (37 %). Ahora Test-RevisionPropia lo lee
# como sexto caso y puede subir la confianza minima al borde de un tramo bajo que no aporte. Con los
# datos de HOY no mueve nada -ningun tramo bajo llega a 20 muestras con mala tasa-, y el tramo ALTO
# no se toca nunca: subir ahi seria dejar de oir su nombre, lo contrario de la meta del 100 %.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-activaciones-leidas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el cuaderno de activaciones por fin se lee)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n237. Un solo estado de red, en vez de dieciseis plazos sueltos (idea 84 de las 121)"
# Cada pieza descubria por su cuenta que no hay red: siete plazos escritos a mano en assistant.ps1 y
# nueve en el worker, y un grep de Test-Connection/NetworkAvailability/hayRed/sinRed daba CERO.
# Ahora hay un sitio con el ultimo exito y los fallos seguidos: lo de FONDO (clima, ip-api, ficha de
# Steam, correo de la manana) pregunta antes de salir; lo que pide braya no se bloquea nunca, solo
# se le acorta el plazo a la mitad. La guarda que importa: hacen falta DOS servicios DISTINTOS para
# darla por caida -Steam en mantenimiento no puede apagar el clima- y la caida caduca en 5 min.
# Y AMPLIADO CON LA IDEA 92 (27/09): decir que esta sin red, una vez. Nova se quedaba sin clima,
# sin resumen del dia y sin voz en linea, contestaba a medias y no explicaba por que; un grep de
# 'sin-red' en las 32.900 lineas daba CERO. OJO CON EL DATO DE LA FICHA: las 756 lineas 'no pude
# resumir' del registro son TODAS del 26/09, una por minuto, y son WinError 10061 -conexion
# denegada- contra Ollama en localhost, que no es falta de red. Los fallos de red de verdad son
# ONCE en 16 dias: 8 del clima (DNS de api.open-meteo.com) y 3 de la voz en linea. El aviso de
# vuelta solo sale si el de ida se dijo, y los dos estan en $AvisoSiempre porque caducan.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-estado-red.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:hay un solo estado de red)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n236. Saber si la consola esta en la mano, no solo si alguien toco un boton (idea 83 de las 121)"
# El comentario del codigo decia que el acelerometro 'tarda 5 s y devuelve null SIEMPRE' y por eso
# estaba apagado en config.json. Medido hoy con el MISMO camino (ReportInterval fijado): primera
# lectura 33 ms y de 30 lecturas CERO nulas, media 2,94 ms. Llevaba apagado por una medicion vieja.
# Ahora el mismo sensor del sobresalto dice si la consola se mueve, con umbral sacado de SU reposo y
# exigiendo dos lecturas seguidas (un golpe en la mesa no es braya). Eso recorta Get-NadieMin y
# suelta los avisos aparcados: 4.153 lineas 'ENTORNO aparcado', el 52 % del registro actual.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-movimiento.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:Nova sabe si la consola esta en la mano)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n235. Diez relojes de una-vez-cada-tanto nacian diciendo ya-puedes (idea 82 de las 121)"
# Las esperas se miden contra el cronometro del proceso, que empieza en cero. Diez variables de
# sesion arrancan en un negativo de cuatro cifras -'hace muchisimo que no pasa'- y Nova arranca 15,2
# veces al dia: una guarda de 'no repitas en diez minutos' podia dispararse quince veces. Ahora hay
# tmpelojes.json con hora de pared y un par Get-Reloj/Set-Reloj, por LISTA BLANCA: solo relojes de
# 'no repitas' (charla, precarga, propuesta de invitado, aviso de suelta). Los de 'estoy callada' se
# quedan fuera a proposito: si braya reinicia para que Nova hable, devolverle la sordina seria peor.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-relojes.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los relojes de no-repitas sobreviven)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n234. Abrir un juego era lo unico que Nova nunca comprobaba (idea 81 de las 121)"
# SILENT BREATH se mando abrir CINCO veces el 11/09 y el detector no lo vio arrancar ni una vez;
# Little Nightmares 7 ordenes y 3 arranques, Outlast 2 y 1. Los juegos estaban excluidos A PROPOSITO
# de la comprobacion de aperturas porque tardan mas que los 10 s de las apps. Ahora van por su
# propia lista, contra el detector de juegos que ya existia, y con el plazo que tarda ESE juego
# (p90 de sus medidas x2, tope 10 min). Guarda: sin tres medidas propias NO se vigila y Nova se
# calla, que es el comportamiento de hoy; lo que tarda se apunta siempre, y asi se aprende.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-juego-abre.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:abrir un juego ya se comprueba)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n233. Los errores que Nova se traga, leidos gratis en $Error (idea 80 de las 121)"
# 470 de los 897 catch de assistant.ps1 estan VACIOS (52,4 %): cuando algo revienta se lo traga y
# no habia ni un dato de cuales disparan. PowerShell ya mete toda excepcion capturada en $Error con
# su linea, y esa variable no aparecia NI UNA vez en el script. Ahora se lee una vez por minuto, se
# agrupa por linea y el parte dice la que mas. Y el unico de los 470 que ya se sabia que muerde
# esta arreglado: la lectura de corte.flag, que al fallar dejaba la palabra vacia y convertia decir
# 'nova' para salir de la sordina en callarla.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-petes-tragados.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los errores tragados se cuentan)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n232. Leer el fichero de lo importante: contar los agujeros y cazar los falsos (idea 79 de las 121)"
# importante.jsonl se escribia desde el 25/09 en modo 'a' y NO LO LEIA NADIE: cero lectores en todo
# el repositorio fuera de dos bancos. Es el inventario de sus agujeros. El worker agrupa los que
# son lo mismo (usa fichas(), que vive en su lado) y deja agujeros.json; el asistente prueba EN
# SECO con Test-FastCommand cuales de esos agujeros son FALSOS -de los 8 del registro, TRES lo
# eran: dos '¿que hora es?' y uno del clima- y lo dice en el resumen semanal. Solo lectura: este
# camino no poda ni reescribe el fichero, y sin agujeros repetidos no se dice nada.
python (Join-Path $PSScriptRoot 'probar-agujeros.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el inventario de agujeros por fin se lee)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-agujeros-seco.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los falsos se cazan en seco)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n231. La costumbre se medía contra el reloj, y braya no tiene reloj (idea 78 de las 121)"
# CERO propuestas en 17 dias. El unico candidato, 'abre steam', tiene los 4 dias distintos que
# hacen falta, pero sus horas son 10:14, 20:05, 18:54 y 01:09: contra la mediana del reloj solo 1
# cae dentro de los +-30 min. Medidos contra el ARRANQUE DE LA TANDA, sus siete usos caen entre
# -0,6 y +1,4 minutos. Cuarto detector anclado a cuando braya EMPIEZA a hablarle (tanda = primera
# orden tras 45 min sin ninguna, no el arranque de Nova, que pasa 15 veces al dia), ventana de 14
# dias y N por el p80 de sus desfases. Y de paso, el veto blindado contra el $null que vale 0.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-propuesta-tanda.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la costumbre se mide desde que empiezas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n230. La vibracion estaba detras de una puerta que no se abria nunca (idea 77 de las 121)"
# Send-AvisoVibrado solo vibraba con la capsula ciega, y eso se decidia por resolucion: cero lineas
# 'CAPSULA CIEGA' en 16 dias con 4.038 s de nightreign en un solo dia, o sea 5 avisos 'SIN VOZ' y
# CERO vibrados, con el canal disponible las 130 veces que arranco. La idea 67 arreglo la deteccion
# y aqui se anade la puerta que faltaba: tambien se vibra con un juego delante. Y se MIDE si el
# zumbido movio algo (gatillo, nombre o panel en 30 s); la clase que no mueve nada cinco veces
# seguidas deja de vibrar, pero la que alguna vez sirvio no se corta nunca.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-vibrado-sirve.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el zumbido se usa cuando hace falta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n229. La misma queja sesenta y una veces y nadie la oye (idea 76 de las 121)"
# La madrugada del 26/09: 61 lineas identicas de 'no pude resumir lo del 2026-09-25', una cada 65 s,
# y seguian saliendo mientras se contaban; la linea mas repetida de los dos registros sale 774
# veces IDENTICA. Ahora Log normaliza cada linea (numeros a N) y cuenta; pasado su liston se apunta
# 'repetido', se escribe una nota por DUPLICACION (10, 20, 40...) y se habla solo de lo gordo.
# Log NO llama a nada: Add-Estadistica o Send-AvisoEntorno desde dentro de Log serian recursion
# infinita en la pieza mas usada del programa; recoge el bucle, una vez por minuto.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-en-bucle.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que se repite en bucle se cuenta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n228. Apuntar la decision que NO se tomo, y que le falta para tomarla (idea 75 de las 121)"
# Cinco decisiones propias se evaluaban cada dia y salian EN SILENCIO cuando no llegaban al
# liston: cero 'auto-ajuste' en 14 dias con nueve sitios que lo escribirian. Get-AvisoSinDatos ya
# avisaba de una forma de no llegar -datos amontonados en un dia- y se callaba en la que las frena
# a las cinco: faltan intentos. Ahora se apunta 'auto-frenado:<clave>:pocos-datos' SIEMPRE y se
# habla de UNA sola (la que menos le falta), en nivel medio y una vez por semana. Sin tocar ni una
# condicion de Test-RevisionPropia: se lee lo que ya esta calculado.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-que-me-falta.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:Nova dice que le falta para poder decidir)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n227. Los tres silencios que cierran la frase, medidos de su uso real (idea 74 de las 121)"
# Los tres numeros salian de 100 grabaciones LEIDAS del 14/09, y del tercero el propio comentario
# decia 'provisional y razonado, no medido'. Medidas las 574 grabaciones de uso con el MISMO
# detector del oido: 1.363 pausas dentro de una orden, p90 1,15 s, p95 1,70, p99 3,55. O sea que el
# 1,5 de hoy cae en el p93,5 y estaba BIEN: poner el p95 lo haria mas LENTO. Asi que el numero
# escrito es el TECHO y Nova solo puede acelerar, con suelo para no cortar frases y el p99 -no el
# p98- en el unico silencio donde cerrar antes PIERDE lo que braya estaba diciendo.
python (Join-Path $PSScriptRoot 'probar-pausas-medidas.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los silencios salen de sus pausas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n226. Sembrar la espera aprendida con lo que ya sabia el registro (idea 73 de las 121)"
# La regla del 25/09 -espaciar los avisos que no mueven nada- no hacia NADA: sus contadores
# nacieron ese dia y ninguna clave llegaba a las 8 muestras que pide. El registro guarda 101
# avisos desde el 9/09 con su hora; leidos una vez al arrancar quedan 48 utiles y dos claves
# pasan del minimo: oido-ruido (30 muestras, 2 movieron algo -> espera x4) y hora-dormir (8 -> x2).
# Tres filtros: fuera los de nivel bajo (no suenan: su 'no reacciono' no mide nada), fuera los
# 'alto' (no pasan por Get-EsperaAviso) y fuera los que tienen otro aviso a menos de cinco minutos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-siembra-avisos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la espera aprendida arranca con lo que ya sabia)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n225. El pulso del bucle, que nadie habia medido nunca (idea 72 de las 121)"
# ElapsedMilliseconds sale 350 veces en el script y ninguna cronometraba la vuelta, mientras el
# bucle SI se bloquea: 29 Start-Sleep suman 8.050 ms en la zona de ordenes, Say deja el microfono
# mudo 3,6 s y los ~200 procesos cuestan 740 ms. Ahora cada vuelta mide la anterior (una resta) y,
# cuando pasa de SU p99, se escribe con lo ultimo que Nova apunto: 'SORDA 1,4 s ... STEAM:
# abriendo X'. En RAM y una muestra al disco por minuto: la regla 4 dice que el bucle no abre
# ficheros, y la ficha de la idea pedia justo una escritura por vuelta.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-pulso-bucle.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:Nova mide su propio pulso)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n224. El oido sabe cuanto tarda cada motor, asi que no empieza lo que no llega (idea 71 de las 121)"
# Medido sobre los 477 repasos de registro.jsonl, segundos por segundo de audio: base 0,32,
# canary 0,43, small 0,93, omni 1,05, turbo 2,97. En los 15 s de plazo a base le caben 46 s de
# audio y a turbo 5, y el tope era 8 para los dos: turbo se paso del plazo en 17 de sus 23 usos,
# 36 repasos llegaron tarde y 23,2 minutos de CPU se quemaron para nada. Canary y omni NO tenian
# ningun tope. Ahora el plazo viaja con el pedido y el oido estima antes de cargar; el ultimo
# escalon nunca se salta, y sin ritmo medido manda el tope de siempre.
python (Join-Path $PSScriptRoot 'probar-repaso-cabe.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el oido no empieza lo que no va a llegar)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-repaso-cabe.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el plazo viaja con el pedido)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n223. El historial de energia que Windows guarda de los dias que Nova no estaba (idea 70 de las 121)"
# Nova arranco 259 veces en 17 dias y su serie de bateria son 18 lineas. Windows guarda dia a dia
# cuanto estuvo la consola despierta con cargador y sin el: 248 ms el informe, 12 dias validos.
# Del 15 al 26/09, enchufada casi 24 h CADA dia y 14 min/dia sin cargador, cinco dias a cero: por
# eso el ritmo por juego no se aprende nunca (pide tramos de 10 min) y el minimo visto es el 90 %.
# La entrada imposible del informe (24.695 dias) se TIRA, no se promedia. Se lee una vez al dia y
# NUNCA desde el bucle. La rama que avisa se prueba con datos inyectados: aqui no salta sola.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-bateria-windows.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:Nova lee lo que Windows apunto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n222. En la mesa o en las manos: el paquete del mando y el sensor de orientacion (idea 69 de las 121)"
# Dos senales que ya estaban y no se usaban: dwPacketNumber -que XInput solo sube cuando el mando
# cambia, y aparecia CERO veces en el script- y SimpleOrientationSensor (0,157 ms en caliente
# frente a los 15,52 del acelerometro, que sigue apagado). Get-EnLaMesa exige las DOS cosas y
# calla si falta cualquiera. El umbral de 'quieto' es el p90 de los huecos de braya, con 20
# muestras minimas. Y lo que mas valia y no pedia la ficha: el mando cuenta como PRESENCIA, que
# GetLastInputInfo no ve. El banco lee el sensor de verdad y mide lo que cuesta.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-mesa-o-manos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:Nova sabe si la consola esta en la mesa)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n221. Que la capsula diga si se la ve, en vez de adivinarlo por la resolucion (idea 67 de las 121)"
# 'CAPSULA CIEGA' salia CERO veces en 58.636 lineas de registro con 19,9 h de juego dentro: los
# juegos de hoy usan pantalla completa SIN cambiar de resolucion, asi que la cuenta que decidia
# siempre dijo 'se ve' y Send-AvisoVibrado no disparo nunca. Ahora la capsula escribe en
# tmp\ui-visible.txt '1|0 <hora> <cadencia>' cada 5 s mirando su opacidad, si esta visible y
# SHQueryUserNotificationState; ese latido delata ademas que se cuelgue VIVA. Ante la duda -sin
# fichero, vacio, ilegible o viejo- se supone visible. El banco arranca el exe de verdad.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-capsula-visible.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la capsula dice si se la ve)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n220. Los tres puertos de mando que no existen se llevaban el 86 % del sondeo (idea 66 de las 121)"
# Medido en esta Ally con AX y 300 llamadas por puerto: el 0 (conectado) 0,15 ms; los 1, 2 y 3
# (ret=1167) 0,36 / 0,39 / 0,39. De 1,29 ms por vuelta, 1,14 en puertos que nunca tuvieron nada,
# 33 vueltas por segundo. Ahora un puerto que nunca contesto solo entra en el repaso, cuyo plazo
# sube solo de 1 s a 4 s y vuelve a 1 s al aparecer un mando; el puerto 0 nunca se aplaza y el
# gatillo no se gasta el repaso. El banco ejecuta las dos funciones y MIDE el ahorro en vivo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-mando-puertos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los puertos vacios ya no se preguntan en cada vuelta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n219. Las copias de seguridad resucitaban 73 datos que el perfil ya habia tirado (idea 65 de las 121)"
# Juntando el perfil.md de los 13 zips salian 94 datos distintos frente a los 38 del vivo, entre
# ellos 'Braya considera que Nova se equivoca frecuentemente'. Al hacer la copia del dia se poda
# el perfil.md de las anteriores dejando solo lo que sigue vivo: cada zip en su .tmp y al sitio
# solo al terminar; si el vivo estuviera vacio NO se toca nada; un zip ilegible se salta y un
# fallo AL ESCRIBIR para la pasada. perfil-todo.md no se poda nunca: es lo que braya pidio.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-copias-podadas.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que el perfil tiro ya no revive en las copias)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }
Titulo "2n216. Se muere la mitad de las veces y solo recuerda la ultima: contar arranques y relanzamientos (idea 50 de las 121)"
# 72 arranques / 36 cierres limpios (50 %) y 46 relanzamientos del oido o la capsula en 12 dias
# que Nova nunca conto ni dijo. Ahora cuenta 'arranque', 'cierre-limpio', 'relanza:oido' y
# 'relanza:capsula', y Test-ReiniciosDeMas avisa (nivel 'medio', se aparca si no hay nadie) cuando
# HOY supera SU PROPIA mediana de 14 dias -nunca un numero a mano; el liston es la propia Nova-.
# Datos inyectados; el banco ejecuta las funciones y el scriptblock del Exiting de verdad (AST).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-reinicios.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los reinicios se cuentan y se comparan con lo normal)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n215. Lo que bajas y no abres: cruzar descargas.json con el LastPlayed de Steam (idea 49 de las 121)"
# Nova avisaba de disco poco contestando megas de cache con 52 GB de juegos sin abrir delante.
# Get-JuegosSinAbrir los ve (tamano>0 y ultimo=0, el mayor primero) y el aviso de disco los nombra;
# Test-JuegoSinEstrenar avisa (nivel 'bajo', solo popup, una vez por juego) de lo bajado y no abierto
# pasado TU plazo -aprendido de tus propios estrenos, no un numero a mano-. NUNCA desinstala. Datos
# inyectados: mirar la biblioteca real se pondria rojo solo en cuanto braya desinstale un juego.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-juegos-sin-abrir.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que bajas y no abres se cuenta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n214. Los instrumentos mudos: contadores que no han contado nada (idea 48 de las 121)"
# ~90 claves de Add-Estadistica y ~40 no han contado nunca; 13 rutas memoria\* que el codigo
# nombra y no existen. Un contador que nadie alimenta parece que mide y no mide. El banco fecha
# cada clave por su primer commit (una pasada de git) y solo acusa las mudas de mas de 4 dias
# (N medido: el retraso maximo de un contador que si funciona son 4 dias, nube-tarde). No toca
# assistant.ps1: fechar pide git y son 2 s, que en el bucle de 30 s romperia la regla 4.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-instrumentos-mudos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no han medido nada estan contados)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n213. El juego que se abre y se muere a los diez segundos (idea 47 de las 121)"
# El 25/09 NIGHTREIGN murio 6 veces en una hora y Nova callo. Ahora cuenta las muertes seguidas
# del mismo juego (racha que se rompe por partida buena o por $JuegoVueltaMs) y a la 3a ofrece
# 'cierra steam'. >=3 y no ==3 porque la 3a real coincidio con una confirmacion viva. Solo
# palabras (regla 1): braya usa la orden que ya existe. Ningun numero nuevo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-juego-muere-al-arrancar.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el juego que se muere al arrancar se caza)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n212. Sabe a que hora paras, pero no cuanto te mueves de esa hora (idea 46 de las 121)"
# La banda p25/mediana/p75 de habitos.fin. La mediana ya la sabia; la banda anade la dispersion,
# y de ahi salen la ventana del recordatorio de carga (p75-p25, hoy 160 min contra 30 fijos) y el
# margen del aviso de dormir (p75-med, con suelo en 30). La mediana NO cambia (Floor(n/2)). Con
# los tres avisos reales del registro: 2 de 3 se silencian, el unico tardio de verdad se conserva.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-banda-fin.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la banda de habitos se mide sola)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n211. Que tapar los secretos sea cosa del registro, no de quien lo llama (idea 45 de las 121)"
# 4 de 144 vuelcos de excepcion tapan la clave de Steam con -replace; los otros 140 no. Ninguna
# se ha escapado aun (0 en los cuatro registros), pero son 140 caminos abiertos. Ahora Log
# sustituye el VALOR de cada secreto (claves.json entero + ANTHROPIC_API_KEY + NOVA_CORREO_CLAVE)
# por ***, asi que anadir una clave la tapa sin tocar codigo. Se carga una vez al arrancar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-log-sin-secretos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:todo correcto)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n210. Los 1200 MB que Parakeet dice necesitar no los midio nadie (idea 44 de las 121)"
# El liston de RAM (1200) se escribio con 7,7 GB libres y lo comparten tres modelos: canary
# (198 MB en disco) y omni (350) piden el liston del grande. Ahora cada modelo mide en vivo lo
# que ocupa al cargar (huellas-ram.txt) y su liston sale de max(huella)+454; sin huella, el
# respaldo es el 1200/900 de siempre, asi que el dia de estreno nada cambia. La ganancia
# medida es de canary y omni, que dejan de pedir prestado el liston del grande.
python (Join-Path $PSScriptRoot 'probar-huella-ram.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el liston sale de lo medido)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n209. Una pregunta nace muda en las manos: zumbido, y medir si sirve (idea 42 de las 121)"
# El mando NUNCA contesto una pregunta (0 en 17 dias) ni con la pista de texto puesta. Al nacer
# una pregunta, un zumbido corto y flojo -segunda via, regla 7-, con puerta HAY MANDO (no juego:
# 1 pregunta con juego delante en 17 dias). Se mide en dos listas y, si con 20 la mediana no
# baja, se apaga solo. No sustituye la pista de texto ni toca los plazos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-zumbido-pregunta.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la pregunta zumba en las manos y se mide si sirve)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n208. Mirar todas las unidades, no solo la C: (idea 41 de las 121)"
# El aviso de disco solo miraba C:. braya tiene una microSD de 477 GB vacia (D:, 'Rog SD'): Nova
# decia "quedan 5 gigas" con 477 al lado sin usar. Get-Unidades ve todas las fijas y extraibles
# (cada una a su try, sin las de red que cuelgan el bucle), y el aviso nombra la de mas sitio
# diciendo que es la tarjeta y que se puede quitar. No mueve nada (regla 1).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-unidades.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el disco mira todas las unidades)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n207. El oido apunta sus propios fallos en vez de olvidarlos (idea 40 de las 121)"
# El 25/09 el bucle del oido fallo 3 veces con el mismo texto, rehizo el reconocedor las 3, y la
# orden se perdio entera y en silencio. El worker cuenta ahora el mismo fallo repetido (sin
# umbral nuevo, el mismo _mismo de la idea 5), lo publica en escucha-estado.txt, y el asistente
# lo APUNTA en el diario. Y se resucita el canal PERDIDO que la idea 5 dejo muerto (escribia en
# RUTA_DICTADO, que no existe, dentro de un except mudo).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-fallo-bucle.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el oido apunta sus propios fallos)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n206. Decir el nombre del juego, no el de la carpeta (idea 38 de las 121)"
# El campo 'dir' (el installdir de Steam) se leia y no lo usaba nadie. Cuando la carpeta no se
# parece al titulo -CatQuest_Purribean es "Cat Quest III"- Nova decia el nombre de la CARPETA
# ("Cerraste CatQuest_Purribean", 20/09). Ahora Get-JuegoPorCarpeta lo traduce por igualdad
# exacta, y Repair-ClavesPorCarpeta arregla al arrancar lo ya guardado con el nombre malo (con
# copia de seguridad y sin fusionar dias que se solapan).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-carpeta-a-nombre.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:las claves de juego se arreglan por la carpeta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n205. Las charlas ya medidas que se tiraban, y cuatro umbrales que salen de ellas (idea 37 de las 121)"
# La primera frase de cada charla llegaba cronometrada al log ("primera frase en N s") y se
# tiraba: 265 medidas que no alimentaban nada, con cuatro umbrales de espera a fuego. Ahora se
# guardan en charla-tiempos.json -en DOS listas, api y local, porque contestan en 1 s vs 16 s- y
# de ahi salen los umbrales, que solo BAJAN la espera, nunca la suben. Y se borra 'charla' de
# DURACION_ESPERADA, que era codigo muerto (cero lineas BARRA con modo=charla en el registro).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-charla-tiempos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:las charlas medidas ya no se tiran)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n204. Los toques sueltos del mando ya no se pierden: ensenan un vistazo (idea 36 de las 121)"
# Un toque corto en el boton de menu no hacia NADA (solo el DOBLE toque abria el panel). MEDIDO:
# 62 toques sueltos apuntados que se tragaba el vacio, ninguno mitad de un doble. Ahora, pasados
# 450 ms sin segundo toque, se pinta un vistazo -hora, bateria y el aviso aparcado si lo hay-,
# 2,5 s y se va solo. Solo texto: ni Say ni vibracion (regla 1: un toque no es una orden).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-vistazo-toque.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el toque suelto del mando ya no se pierde)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n203. Al cancelar un dictado a los 50 s, mira si el oido sigue vivo (idea 35 de las 121)"
# La rama que corta el dictado a los 50 s cancelaba igual los 59 casos del registro, sin mirar.
# MEDIDO: en 58 el worker seguia vivo y solo mudo, en 1 (1,7 %) habia muerto. Ahora mira: MUERTO
# -> relanza aqui mismo (mismo contador de 3 intentos que la vigilancia de 30 s); VIVO -> no lo
# toca (matarlo tiraria una transcripcion que quiza llega y lo dejaria huerfano, regla 5) y solo
# lo dice. Test-EstadoFresco entra en el texto del log, nunca en la decision de relanzar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-corte-50s.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el corte de los 50 s mira si el oido sigue vivo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n202. La lista que impide borrar la consola se salta con un alias (idea 34 de las 121)"
# opencode tiene acceso total. Lo que le frena es una lista de 35 patrones "deny" en su jsonc,
# que casan TEXTO LITERAL: no saben que ri/rm/rd/del son Remove-Item, ni que -R es -Recurse.
# Comprobado de verdad: `ri -Rec -For` borra un arbol en TEMP sin casar con ninguno de los 35.
# La lista gemela de Claude Code ($CcProhibido) SI cubre alias; la de opencode se quedo atras.
# El banco es de SOLO LECTURA (regla 1): cuenta los rodeos con un trinquete (hoy 6), no arregla
# la lista, que es decision de braya. Urgencia baja: 0 ejecuciones de opencode desde el 13/09.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-permisos-opencode.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:los rodeos de la lista de opencode estan contados)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n201. La regla vale tambien para lo que ya estaba (idea 31 de las 121)"
# El 19/09 se escribio un filtro: lo que habla de Nova no entra en el cerebro, porque el cerebro
# es la memoria de BRAYA, no el diario de Nova. Pero ese filtro solo miraba lo que LLEGA.
# MEDIDO sobre memoria\cerebro\cerebro.json: de los 121 recuerdos, TREINTA Y SEIS hablan de Nova
# -el 29,75 %- y los 36 estan en estado "firme", o sea que entran en las busquedas y viajan en el
# contexto de todas las charlas. Los 36 son del 15/09 (20) y del 18/09 (16): cero del 19/09 en
# adelante, que es justo cuando se escribio el filtro. Es el mismo agujero que repasar_estilo
# arreglo para el estilo, y se arregla igual: no se borra nada, se marca como rechazada.
# Y CON DISYUNTOR: si el filtro se come mas de la MITAD de la memoria, no toca nada y lo dice.
python (Join-Path $PSScriptRoot 'probar-recuerdos-repasados.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la regla vale tambien para lo que ya estaba)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n200. Lo que no se dice no gasta turno (idea 29 de las 121)"
# Un aviso de nivel "bajo" solo sale en la capsula, no se dice NUNCA. Pero gastaba una de las
# cuatro plazas de VOZ de la hora y ademas se quedaba como el aviso al que Nova le mira la
# reaccion para aprender cuanto esperar. MEDIDO sobre los 97 avisos de los dos registros: 26 son
# "bajo", el 26,8 %, y CUATRO de las DOCE muestras de reaccion guardadas son de claves mudas.
# LOS DOS ROBOS, con hora: el 22/09 a las 08:00:25 salio oido-ruido (dicho) y 89 segundos
# despues bateria-llena (mudo) le quito la observacion; el 23/09 a las 20:41:58, cargador-quita
# pisado 60 s despues por cargador-pone. Es el mismo arreglo del 24/09 con aviso-dicho: el
# presupuesto es de VOZ, y lo que no habla no gasta. El aviso mudo sigue saliendo, viendose en
# la capsula y contandose; lo unico que cambia es que ya no cobra el turno de otro.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aviso-sin-voz.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que no se dice no gasta turno)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n199. Nova se entera de que cambiaste de horario (idea 27 de las 121)"
# MEDIDO sobre las 714 ordenes con texto de los dos registros, partidas en dos semanas:
#   10-16/09:  73 de manana, 244 de tarde,  25 de noche,  1 de madrugada
#   18-25/09:   4 de manana,  83 de tarde, 201 de noche, 83 de madrugada
# La mediana del momento del dia pasa de las 15:30 a las 22:58: CUATROCIENTOS CUARENTA Y OCHO
# minutos de salto, y Nova seguia promediando las dos semanas. NO HAY UMBRAL FIJO: el salto se
# compara contra la dispersion de los propios dias de referencia (IQR 160; 448/160 = 2,8). Con
# un umbral de 120 cantarian tres dias mas que con el IQR se callan. Y el suelo de diez ordenes
# por dia tampoco es a ojo: sin el, el 18 y el 19/09 cantan ruptura DEL LADO CONTRARIO.
# LA GUARDA QUE EVITA LA REGRESION: el recorte de la ventana solo se aplica si despues del
# corte quedan cuatro dias. Sin ella, Get-HoraFinHabitual devuelve -1 cuatro dias seguidos y la
# noche vuelve a las 23:00, que es justo lo que la idea 8 del 25/09 acaba de arreglar.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-cambio-horario.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se entera de que cambiaste de horario)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n198. Nova aprende sola con que programa se abre cada juego (idea 26 de las 121)"
# EL CASO, con numeros: el 25/09 braya jugo 4.038 segundos seguidos a ELDEN RING NIGHTREIGN -una
# hora y siete minutos- y Nova apunto SETENTA Y CINCO. El 1,86 %: se perdio el 98,14 % de la
# partida. Y en esa hora, con el microfono abierto porque "no habia juego", hay 45 lineas de
# llamadas descartadas en el registro. La lista de ejecutables de juego esta escrita a mano y
# tiene CUATRO entradas: todo lo que no arranque desde una carpeta reconocible es invisible.
# COMO SE APRENDE: si un proceso lleva diez minutos seguidos delante sin que Nova lo reconozca,
# se le pregunta a Steam, que sella LastPlayed en el appmanifest de lo que se acaba de jugar. Si
# se movio EXACTAMENTE UNO, ese es. Con dos no se aprende NADA: equivocarse aqui hace que Nova
# cierre el microfono creyendo que esta jugando, y eso lo deja sin voz. Los diez minutos salen
# del cuaderno de la Ally: el no-juego con mas tiempo delante en un DIA es explorer con 350 s, y
# la partida mas corta medida son 2.351. El liston cae en el hueco vacio entre los dos.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-exe-de-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:con que programa se abre cada juego)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n197. Lo que oyo el otro motor se prueba antes de rendirse (idea 25 de las 121)"
# Cada orden la oyen TRES motores -Vosk, Parakeet y a veces Whisper- y Nova se queda con uno.
# Los otros dos se escriben en tmp\dictado-oidos.txt y hasta hoy solo los leia la NUBE, cuando
# ya se habia decidido mandar la frase fuera. MEDIDO sobre las 560 ordenes con las tres
# transcripciones: en 17 (el 3,0 %) la entregada no empieza por verbo y la de Vosk SI, y leidas
# una a una en QUINCE de esas 17 la de Vosk era la buena. El sitio tambien esta medido: puesto
# delante del filtro de ruido se cubren los 17; delante de la nube se pierden TRES, el 18 %.
# LA GUARDA QUE EL BANCO VIGILA MAS, y es la regla 1: la candidata SOLO se prueba cuando la
# entregada no ha resuelto nada. Si se probara siempre, un "abre steam" que ya funciono podria
# acabar ejecutando el "cierra todos los programas" que oyo otro motor. Y nunca sale de local.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-otro-oido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se prueba antes de rendirse)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n196. Si te repites, lo aprendo (idea 24 de las 121)"
# Cuando braya dice algo, Nova no lo entiende, y a los pocos segundos lo repite de otra forma y
# ESO SI funciona, ahi hay una traduccion regalada. MEDIDO sobre los 714 dictados con texto de
# los dos registros: SEIS pares reales, con huecos de 12, 15, 17, 29, 30 y 42 s.
# LOS DOS NUMEROS NO SON LOS DE LA IDEA, y esa es la parte importante. La idea pedia parecido
# 0,75, pero ese 0,75 sale de SequenceMatcher, que es de Python; aqui la metrica que existe es
# Get-Distancia (Levenshtein), y con ella los seis pares dan de 0,662 a 0,889: con 0,75 se
# pierden TRES. Con 0,60 entran los seis y cero falsos sobre 534 pares. Y la ventana son 60 s y
# no 90: el hueco real mas largo es 42 y subir de 45 a 180 s no anade ni un par en catorce dias.
# LA ROTURA PELIGROSA que el banco vigila: que falte la marca del camino de la NUBE. El 22/09 a
# la 01:09 'Si es Steam' murio en local, la nube la tradujo y Nova ABRIO Steam; 17 s despues
# llego 'Sierra Steam'. Sin esa marca se aprenderia 'si es steam' = cerrar Steam. Regla 1 rota.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-segundo-intento.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:si te repites, lo aprendo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n195. El oido se pone la nota a sus propios descartes (idea 23 de las 121)"
# Cuando el oido tira una llamada -la rafaga sono floja, o los altavoces obligaban a exigir mas
# confianza- no volvia a pensar en ello nunca. Pero si a los pocos segundos se abre una escucha
# BUENA -porque braya repitio, o porque se rindio y apreto el boton- ese descarte estaba MAL, y
# las dos lineas ya estaban escritas en el registro sin que nadie las cruzara. MEDIDO sobre 18
# dias: 113 descartes por rafaga con 15 arrepentidos (13 %) y 162 por confianza con 9 (6 %). Los
# 30 s de la ventana tampoco son a ojo: de 67 arrepentidos, 60 caen entre 4 y 30 s.
# Y ESTO ES UN CUADERNO, NO UN MANDO: la mitad de la idea que ajustaba listones sola se cayo con
# su propio dato -recupera 7 llamadas y cuela 30 falsas-, asi que el banco vigila que nadie
# cablee descartes.jsonl dentro de umbral_rafaga, umbral_confianza, umbral_actividad ni la puerta.
python (Join-Path $PSScriptRoot 'probar-arrepentidos.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se pone la nota a sus propios descartes)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n194. Con un juego delante la capsula apaga lo que nadie mira (idea 20 de las 121)"
# MEDIDO: 21,7 horas de juego en diez dias distintos, contadas sobre memoria\juegos.json. Y en
# todas ellas la capsula NO se duerme nunca: la condicion de Dormir() pide que no haya juego
# delante, asi que con uno abierto los cinco relojes siguen corriendo enteros. Los cinco suman
# 65,28 tics por segundo y los DOS que se apagan aqui -la mirada de 66 ms y el tic33- son 45,45
# de ellos, el 69,6 %; ademas cada tic de la mirada hace TRES llamadas al sistema que con un
# juego a pantalla completa devuelven siempre lo mismo. NO se dice cuanto nucleo ahorra porque
# no esta medido: el 28 % del comentario del latido es de antes del tope de 12 fps.
# Y SOLO EN REPOSO: si se apagara mientras Nova habla se perderian el lipsync y la onda. El
# reloj que lee el estado, el latido y el parpadeo no se paran JAMAS: eso la dejaria tiesa.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-capsula-ahorro.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:apaga lo que nadie mira)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n193. El registro sirve para juzgar la cascada (idea 19 de las 121)"
# Python apunta en registro.jsonl TODO repaso que hace, con su motor y el texto que saco: 480
# lineas -base 328, small 94, canary 30, turbo 23, omni 3-. El asistente no abria ese fichero
# mas que para borrarlo. Y mientras tanto el caso 5 de la revision propia -el que decide si un
# escalon de la cascada de repasos merece la pena- no podia decidir NADA: sus contadores propios
# llevan cinco filas de un solo dia y DecisionMinIntentos son 20. Con el registro son treinta
# repasos de canary en cinco dias. "Sirvio" se decide con Test-FastCommand, LA MISMA regla que
# el contador vivo. Y se juzga de UNO EN UNO desde el bucle y solo con Nova parada: medido, eso
# tarda 70 ms de media y hasta 300 ms por frase, asi que los treinta de golpe serian dos
# segundos con el bucle quieto. El veredicto de cada linea se calcula una vez en la vida.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-motores-medidos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el registro sirve para juzgar la cascada)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n192. El atajo por longitud no cambia ni una respuesta (26/09)"
# LO QUE SE ENCONTRO MIDIENDO OTRA COSA: Test-FastCommand -que esta en el camino en caliente y
# se llama de dos a cuatro veces por cada orden que braya dice- tardaba hasta 1.077 ms en una
# sola frase. Con el reloj por dentro: Resolve-Target 1.074 ms, y de esos Find-Aproximado 785.
# La culpa era montar una matriz de Levenshtein en PowerShell interpretado por CADA app y CADA
# sitio, aunque la candidata midiera cuatro letras y la frase quince. El atajo es exacto, no
# aproximado: borrar e insertar cuestan 2, asi que la distancia nunca baja de 2*|n-m|; si ese
# minimo ya pasa del tope, esa candidata no puede ganar. Medido limpio y con calentamiento:
# frase larga 2.295 ms -> 0,7 ms; palabra corta 38 ms -> 26 ms. Y este banco NO mide el tiempo:
# ejecuta las DOS versiones sobre el catalogo entero tocado letra a letra y exige la misma
# respuesta y la misma marca de duda en cada caso.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-aproximado-rapido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no cambia ni una respuesta)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n191. La puerta de los altavoces se aprende de tus llamadas (idea 18 de las 121)"
# Cuando los altavoces pasaban de 0,02, a la palabra de activacion se le exigia 0,85 en vez de
# 0,55 y ahi se le caian las llamadas. Ese 0,02 nunca salio de un dato: medido sobre 14.422
# pulsos, 13.436 (el 93,2 %) valen CERO CLAVADO y entre 0 y 0,02 caen 89, el 0,6 %. No separaba
# nada, y costaba 153 descartes en los dos registros, 111 de ellos con confianza de sobra para el
# liston normal. Ahora la puerta sale del nivel al que braya llama DE VERDAD: el p80 de las 75
# activaciones que acabaron en orden, 0,177, acotado entre el 0,02 de config.json y el 0,35 al que
# la palabra se ignora entera. El techo no es adorno: la puerta se alimenta de un fichero que ella
# misma hace crecer, y es un trinquete. Y JUGANDO manda el 0,02 de siempre: ahi subirla no
# recupera ni una llamada -la rama de solo-boton las para igual- y solo anadiria vibraciones.
python (Join-Path $PSScriptRoot 'probar-puerta-altavoces.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la puerta de los altavoces se aprende de tus llamadas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n190. Se sabe con cuanta memoria estuvo oyendo (idea 17 de las 121)"
# El oido encoge SOLO su plazo para soltar los modelos cuando queda poca memoria -y con eso oye
# peor-, lo apuntaba en assistant-pulso.log y no se enteraba nadie: assistant.ps1 abria ese
# fichero en UN sitio y era para borrarlo. MEDIDO: el 42,9 % de los pulsos corria recortado y el
# 11,4 % en el suelo x0,10, con la mediana de memoria libre de la consola en 2.815 MB y el liston
# de "comoda" puesto a mano en 2.500, justo por debajo. Ahora los dos listones salen de lo que
# cuesta traer de vuelta lo que sueltan (RAM_MIN_PRECISO y RAM_MIN_PARAKEET + RAM_MIN_PRECISO) y
# el oido manda el porcentaje en el decimo campo. NO se hizo lo que pedia la idea -sacarlos de su
# propio p60/p15-: eso subia el recorte del 27,8 % al 59,8 %, porque un liston en el percentil p
# fija el recorte en 1-p por construccion. Eso no es adaptarse, es congelar el sintoma.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-oido-apretado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:con cuanta memoria estuvo oyendo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n189. La ganancia que saturo no se vuelve a poner (idea 16 de las 121)"
# MEDIDO sobre los dos registros: 985 lineas de "recorte detectado: bajando ganancia", y 564 son
# de hoy. Emparejando cada recorte con el anterior y reconstruyendo la ganancia de partida -la
# bajada es fija, x0,6-, 329 de los 985 (el 33,4 %) llegaron con la ganancia YA POR ENCIMA de la
# que acababa de saturar: uno de cada tres recortes es volver a pisar el mismo charco. CABE_MAX no
# lo veia porque mira el FONDO amplificado, y la voz tiene picos que el fondo no anticipa. Ahora se
# recuerda la MENOR ganancia que ha llegado a saturar y la respetan los DOS caminos que la suben,
# la vuelta a la buena y la calibracion del pulso. Caduca a los 904 s -el p95 de los 633 huecos
# medidos entre recortes- porque una habitacion cambia, y NUNCA frena una bajada: frenarla ahi
# dejaria el microfono saturado sin forma de salir.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-techo-ganancia.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:no se vuelve a poner)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n188. Lo aprendido espera a ver si lo corriges (idea 15 de las 121)"
# EL CASO, con hora: el 25/09 a la 01:26:12 Nova aprendio 'Cierra este in.' = 'cierra discord' y
# lo bajo a disco al instante. DIECISIETE SEGUNDOS despues braya dijo "No dije Discord, dije
# Steam". Demasiado tarde: ya estaba escrito, apuntando a la app por la que habla con su pareja.
# Ahora lo aprendido espera EN MEMORIA antes de bajar a disco. La entrada entra igual en la
# tabla -Nova la usa ya-; lo unico que espera es el fichero, y si braya corrige no se escribe.
# El plazo se APRENDE de lo que tarda en corregir (p90 de sus propias correcciones, entre 10 y
# 45 s); hasta que haya ocho muestras manda el de arranque, que son los 17 s del caso real.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-cuarentena.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:espera a ver si lo corriges)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n187. El cerebro local caido se nota una vez, no setecientas (idea 14 de las 121)"
# MEDIDO el 26/09: entre las 00:07 y las 13:49, assistant.log trae SETECIENTAS CINCUENTA Y SEIS
# lineas de "diario: no pude resumir ... 10061" -Windows diciendo que no hay nadie en ese
# puerto-. Los huecos: 517 de 65 s, 237 de 66 y uno de 67. Ni un freno. Y de las 877 lineas que
# la charla escribio ese dia, 756 son esa misma: el 86,2 %.
# Ahora se cuenta el fallo, se espera cada vez mas (65 s -> 30 min), se dice UNA vez, y en el
# primer fallo se prueba a levantarlo UNA vez por sesion -nunca con un juego delante ni sin RAM-.
# LO QUE MAS VIGILA EL BANCO: que el freno NO llegue a generar_local. Ahi hay alguien esperando
# respuesta, y saltarselo dejaria a braya sin contestacion cuando el modelo SI habia vuelto.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-cerebro-caido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:una vez, no setecientas)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n186. El ruido solo se dice cuando ha costado algo (idea 13 de las 121)"
# El aviso de "hay mucho ruido" saltaba mirando SOLO el nivel de fondo. MEDIDO: 36 avisos en
# los dos registros y en TREINTA Y TRES -el 91,7 %- no se habia caido ni una llamada del nombre
# en la hora anterior. Nova avisaba de un problema que no estaba teniendo; el 22/09 solto
# VEINTICINCO en doce horas. Ahora el oido cuenta las llamadas que se le caen y el aviso solo
# sale si hay alguna en la ultima media hora.
# Y VA EN EL NOVENO CAMPO, no en el octavo: el octavo lo ocupo esta misma tarde el repaso
# perdido por falta de RAM (idea 9). Dos ideas del mismo dia queriendo el mismo sitio.
# "No se sabe" es -1 y NO cero: con cero, un oido viejo dejaria el aviso mudo para siempre.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-ruido-que-cuesta.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:cuando ha costado algo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n185. Una confianza gratis para Parakeet (idea 12 de las 121)"
# Tres de cada cuatro ordenes llegaban al asistente SIN NINGUN numero de confianza: 422 de 560
# con seguridad=null, porque solo Whisper sabe decir lo seguro que esta. Pero Vosk ya oyo esa
# misma frase para abrir el microfono: cuanto coinciden los dos es una confianza gratis.
# MEDIDO sobre 273 ordenes con destino: acuerdo <0,2 -> 28 % acaba en nada; >=0,5 -> 9 %. Tres
# veces mas basura. Y el 0,2 es el p20 exacto de los 421 pares, no un numero a ojo.
# DOS TRAMPAS MUDAS que este banco vigila: escribir el acuerdo siempre pisaria el avg_logprob
# de Whisper justo cuando acaba de correr; y cargar_lista tira el fichero ENTERO si ve un 0,00
# o un 1,00 (el 15 % de los pares da cada uno), dejando el liston clavado y en verde.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-acuerdo-oidos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya traen confianza)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n184. Corregirla hablando toca el recuerdo (idea 11 de las 121)"
# Nova ya sabia reconocer una correccion -por_que_importa la caza para guardar el turno- pero
# eso no tocaba el RECUERDO que estaba mal: se quedaba firme en el cerebro y lo volvia a decir.
# El unico camino que lo tachaba exigia duda=true del asistente, y ese sale de un patron
# ANCLADO con ^ que caza CERO de las 61 correcciones habladas de catorce dias. Por eso "queda
# como incorrecta" aparece UNA vez en 59.872 lineas.
# Y EL VALOR ESTA EN TACHAR, NO EN SUSTITUIR: de esas 61, solo UNA trae un par "no es X, es Y"
# con la palabra mala dentro de lo que Nova acababa de decir. Las otras 60 se tachan.
# De paso, un bug: marcar_incorrecta tachaba el recuerdo y dejaba vivo su job, asi que el
# revisor de fondo lo daba por bueno mas tarde y lo volvia a dejar firme.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-corregir-recuerdo.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:hablando ya toca el recuerdo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n183. Los temporales que nadie vuelve a mirar (idea 10 de las 121)"
# EL CASO QUE LO DESTAPO: tmp\clave.txt, 109 bytes, del 12/09, con una clave de la API de
# Anthropic EN CLARO, y NADIE la lee: cero referencias en el codigo. tmp\ esta en el .gitignore
# y "git ls-files tmp" sale vacio, asi que no viajo al repositorio; lo que llevaba catorce dias
# es en el DISCO, con un agente de acceso total autorizado en la casa.
# MEDIDO: de los 134 ficheros del primer nivel de tmp, 96 llevan mas de 7 dias sin tocarse y el
# codigo no los nombra: 12,1 MB. El reparto de edades deja un hueco limpio entre 7 y 9 dias.
# LO QUE MAS VIGILA EL BANCO no es que borre, es QUE NO BORRE DE MAS: mi-voz.json es la huella
# de la voz de braya y puede pasar semanas sin reescribirse. Y tmp\voz no se toca jamas: tiene
# dueno (tts_worker.py la poda con su propio tope de 60 MB).
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-tmp-barrido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lo que hace falta no se toca)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n182. Cuando se queda sin un repaso por RAM, lo dice (idea 9 de las 121)"
# Cuando no hay RAM para un modelo, la guarda lo deja sin cargar y escribe una linea en el log
# que no lee nadie: Nova sigue funcionando pero oye PEOR, y braya piensa que hoy le entiende mal
# sin mas. MEDIDO: TREINTA Y DOS veces en 18 dias -18 parakeet, 8 oido fino, 6 canary- en DIEZ
# sesiones distintas; faltaban entre 24 y 906 MB, mediana 376.
# LA IDEA SE EQUIVOCABA EN LA CAUSA: decia disco y es RAM FISICA (ram_libre_mb ->
# GlobalMemoryStatusEx). disco-poco habla de gigas de disco y es otra averia; colgarlo de ahi
# daria "Te quedan 10,7 gigas. Me he quedado sin mi repaso fino" y se taparian entre ellos por
# compartir reposo. Clave propia. Y son CUATRO guardas, no tres: omni tambien, aunque no haya
# saltado nunca.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-repaso-perdido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se queda sin un repaso, lo dice)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n181. El plazo de cada repaso, de lo que tarda ESE motor (idea 8 de las 121)"
# Todos los repasos compartian UN plazo escrito a mano, 15 s, y el ultimo recurso 60: dos
# numeros fijos para cinco motores que tardan cosas muy distintas. MEDIDO sobre las 477 filas
# con 'segundos' de registro.jsonl: canary p99 14,5 s (0 pasan de 15), base p99 24,1 (6 pasan),
# small p99 238,9 (12 pasan), turbo p99 76,5 (DIECISIETE de 23 pasan). Y 30 lineas "sin
# respuesta a tiempo" que SI tenian respuesta despues: 30 repasos pagados y tirados.
# EL PERCENTIL ES 99 Y NO EL 90 QUE PEDIA LA IDEA: simulado, p90 da 17 timeouts NUEVOS contra 3
# rescatados -peor que hoy-, p95 11 contra 4, y p99 CERO contra 8. Un percentil usado como plazo
# de RENDIRSE garantiza por construccion que el (100-p) % se tire.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-plazo-oido.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el plazo que de verdad necesita)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n180. Lo aprendido lleva TU frase, no la que Nova se reescribio (idea 7 de las 121)"
# Cuando la charla decide que lo dicho era en realidad una orden, la REESCRIBE a su manera, y
# hasta hoy era esa reescritura la que acababa de clave en traducciones.json: Nova aprendia a
# entender sus PROPIAS palabras, que braya no vuelve a decir nunca. MEDIDO: de las 21 lineas
# APRENDIDO del registro, CUATRO llevan de clave una frase que braya no dijo jamas asi. Una de
# ellas es la que envenevo el vocabulario el 25/09: dijo "Que habla, dije que cerraras este in"
# y se guardo 'Cierra este in.' = 'cierra discord'. Y explica el otro numero: 21 aprendidas y
# UNA usada. Ahora se archivan LAS DOS, y la de braya pasa por el MISMO filtro (6 palabras,
# nombre propio, oido dudoso): aqui no se afloja nada, se archiva bajo el nombre bueno.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-clave-como-la-dijiste.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:lleva tu frase)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n179. El tiempo de hace un rato sobrevive al reinicio (idea 6 de las 121)"
# El clima se guardaba una hora, pero solo DENTRO del proceso: cada arranque nacia con la cache
# vacia y el reloj en "hace una hora", asi que a los 20 segundos de vivir Nova salia a internet
# otra vez aunque el dato de hace cuatro minutos siguiera siendo bueno. MEDIDO: 258 arranques y
# 504 consultas de clima, 334 de ellas -el 66 %- en los TRES minutos siguientes a un arranque.
# Dos de cada tres viajes eran el dato que ya se sabia. La ventana NO se alarga: sigue siendo la
# misma hora. Y el reloj descuenta lo que el fichero ya habia envejecido, para que la proxima
# consulta caiga cuando le tocaba y no una hora mas tarde.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-clima-guardado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:sobrevive al reinicio)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n178. El oido roto se nota, y no se arregla rehaciendolo (idea 5 de las 121)"
# EL CASO REAL, con hora: 25/09 21:33:19 braya la llama cuatro veces seguidas. 21:33:23, :27 y
# :28, el bucle falla tres veces con "name 'callado' is not defined" y las tres rehace el
# reconocedor, que no arregla un fallo del codigo. 21:33:29 llega "8 s sin oir nada" -> "No te
# escuche". La orden se perdio entera y braya se quedo creyendo que no le oia. Otra vez a las
# 22:48. El bug: wake_vosk.py usaba 'callado' CUARENTA Y CINCO lineas antes de asignarlo, y
# ademas no hacia lo que decia su comentario. Ahora: la guarda mira los altavoces, el mismo
# fallo repetido no rehace nada, y el turno perdido se DICE en vez de callarse.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-oido-roto.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el oido roto se nota)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n177. Volver al juego no es entrar en el juego (idea 4 de las 121)"
# Enter-Juego la llama el bucle en cuanto la ventana del juego vuelve al primer plano, asi que
# un alt-tab de veinte segundos contaba como entrar y Nova soltaba "Modo juego" otra vez.
# MEDIDO: 56 entradas en 14 dias, 45 vueltas a un juego ya visto y TREINTA de esas en menos de
# una hora (24 s, 24 s, 30 s, 41 s, 47 s, 52 s, 110 s...). Solo hubo 9 cierres de verdad.
# La senal buena no es el reloj sino el PROCESO: si el PID no ha cambiado no has salido, pasen
# veinte segundos o tres horas; si ha cambiado, es partida nueva aunque hayan pasado 20 s. El
# reloj queda de respaldo con la MISMA hora que la tarjeta hermana. El perfil se aplica igual:
# lo que se calla es la frase, y deja linea en el log.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-vuelta-juego.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:ya no es entrar en el juego)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n176. Quejarse marca la orden, sepa o no rehacerla (idea 3 de las 121)"
# 'fallo-dicho-por-ti' es EL UNICO dato humano de la medicion -braya diciendo "eso no era"- y
# va 0 de 588. Sin el, la meta nº 1 no se puede medir. Iba a cero porque el unico Write-FalloUso
# de ese camino vivia DENTRO del "if ($corrOk)": marcar dependia de que Nova supiera ademas
# reconstruir la orden buena. Y ni llegaba: 'CORRECCION:' sale CERO veces en los dos registros,
# porque de las 64 frases reales que encajan en $RE_QUEJA, Get-OrdenCorregida devuelve algo en
# CERO. Ahora marcar no depende de rehacer, y una queja que NOMBRA el acto de pedir marca aunque
# no salga ninguna orden. Con $RE_QUEJA a secas se marcarian 63 frases de charla que empiezan
# por "no"; con el patron fuerte se marca 1 de 64, y esa 1 es queja de verdad.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-queja-marca.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:marca la orden, sepa o no rehacerla)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n175. Lo que sabe de braya no se escapa al repositorio (idea 1 de las 121)"
# El .gitignore lista los ficheros de memoria\ UNO A UNO, a mano, y el propio fichero cuenta por
# escrito TRES veces que se le escapo alguno. El repositorio es publico. Medido el 26/09: de las
# 37 rutas de memoria\ que el codigo puede crear, tres no estaban cubiertas -montajes.json (las
# URL que visita), palabras-no.json (las palabras que no aguanta) y logros-stamp.json (cuando
# juega)-. Ninguna existia aun en disco: no se habia colado nada, pero el siguiente "git add -A"
# despues de usar esas funciones las habria metido. De los 189 bancos, ninguno miraba esto.
# Dos redes: lo que el codigo PUEDE escribir y lo que YA hay en disco. Y la misma comprobacion
# vive en assistant.ps1, porque un banco solo protege si alguien lo corre antes de commitear.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-memoria-ignorada.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:se queda fuera del repositorio)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n174. El logro no se contaba a si mismo (idea 49)"
# LO MEDIDO: 'logro' sale CERO veces en las 3.518 lineas de tmp\gestos.log, mientras 'orgullo'
# sale 188 y 'aprendido' 16. Y no es que no pasara: el registro de catorce dias trae 11 logros
# de Steam, 10 medallas de hora de juego y 11 fechas especiales. Treinta y dos momentos buenos
# que Nova celebro en pantalla y no apunto en ningun lado, asi que no salen en el resumen de la
# semana -que cuenta los gestos- ni le pusieron el humor 'contenta' que Gesto() da a 'logro'.
# El switch de Evento() lo mandaba a Logro() directo, saltandose Gesto(), que es quien apunta.
# OJO: esto vive en nova_ui.cs, o sea que hasta que la capsula se recompile con Nova parada,
# el diario seguira a cero. La seccion 5b de mas abajo lo avisa en amarillo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-logro-anotado.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:el logro ya se cuenta a si mismo)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "2n165. La ganancia es de un microfono, no de la consola"
# ENTRA EN LA BATERIA EL 25/09, Y LLEVABA TRES DIAS ESCRITO SIN CORRER. El banco es del
# 22/09 -el dia que braya enchufo un micro USB y dijo "Nova tiene que saber detectar cuando
# esta y no esta ese micro y reajustar su ganancia sola"- y desde entonces no lo habia
# lanzado NADIE: ni la bateria, ni otro banco. No salia rojo ni verde, no salia. Lo caza la
# seccion 9, que nacio hoy justo por esto.
# Cabe aqui porque NO necesita microfono: la ganancia se hereda o no leyendo el nombre del
# dispositivo que quedo guardado, y eso es logica sobre texto. Lo que NO se puede probar sin
# hardware -que al cambiar de micro el worker salga y el asistente lo relance- lo comprueba
# sobre el codigo de wake_vosk.py, y el propio banco lo dice en su cabecera.
# Lo que mas vigila: que una ganancia de OTRO micro no se herede. El array de Realtek estaba
# en x18,3; ese numero en un micro USB satura, y al reves deja a Nova sorda.
python (Join-Path $PSScriptRoot 'probar-microfono.py') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:la ganancia va con su microfono)|MAL'
if ($LASTEXITCODE -ne 0) { $fallos++ }

Titulo "9. Bancos que no corre nadie (ROJO si los hay)"
# UN BANCO HUERFANO NO SALE ROJO, NO SALE VERDE, NO SALE (25/09). En la carpeta tools habia
# 198 bancos y 199 secciones aqui, asi que el recuento parecia decir que estaban todos. No lo
# decia: algunas secciones corren dos bancos, y debajo de ese empate estaba probar-microfono.py
# sin correr desde que se escribio. Escribir la prueba y no engancharla cuesta lo mismo que no
# escribirla, pero da la sensacion contraria.
# TRES COSAS MIRA, y la tercera existe porque las dos primeras podrian ser decoracion:
#   - que ningun banco de la carpeta tools se quede fuera de esta bateria (o de otro banco que lo lance);
#   - que esta bateria no llame a uno que ya no existe (eso si sale rojo, pero con un mensaje
#     que no dice lo que pasa);
#   - y que el detector detecte, con un nombre inventado que no puede estar en ningun sitio.
# EL AGUJERO QUE TENIA AL NACER, y por eso no busca en los comentarios: nombrar un banco en
# un comentario lo daba por corrido. Hoy hay TRES asi -probar-vivo.ps1, probar-precarga.py y
# probar-voz-windows.py, los tres que se quedan fuera a proposito y estan explicados arriba-,
# y los tres pasaban en verde por la razon equivocada. Ahora son una excepcion declarada: si
# aparece un cuarto banco solo nombrado en un comentario, sale rojo.
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'probar-bancos-huerfanos.ps1') 2>>$script:errBanco | Select-String -CaseSensitive '(?i:todos los bancos se corren)|MAL'
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
