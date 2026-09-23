# Diez ideas para Nova (22/09/2026, tercera tanda)

Salieron de **siete angulos distintos sobre sus datos reales** -lo que le pasa jugando, los
segundos, lo que no entiende, la charla y la memoria, la consola, lo que dice sin que le
pregunten, y lo que nadie puede medir despues- y **cada una paso por dos esceptricos**: uno
recontaba el numero por su cuenta y otro miraba si le sirve a braya y si es segura. De las
28 juzgadas sobrevivieron 14, y dos parejas eran la misma cosa con dos caras.

**Las tres primeras ya estan hechas** la misma noche (la 3 entera; de la 1 y la 2 se explica
abajo lo que queda). El resto esperan.

---

# Diez cambios, sacados de tus datos de hoy

Sobrevivieron 14. Dos parejas eran la misma cosa con dos caras (el disco lleno + los 2,3 GB de peso muerto; la revisión propia que no recuerda el día + la que no sabe lo que cuesta), así que quedan **12**. Van las 10 primeras enteras, ordenadas por lo que te cambian de verdad (veces que te pasa × lo que te cuesta), y las 2 últimas resumidas al final. Los números están recontados por los escépticos: donde el recuento original estaba inflado, va el bueno.

Un aviso que vale para todo: **assistant.log cubre 13-14 días (09/09 a 22/09), no 70.** No hay ficheros rotados. Todas las frecuencias de abajo son sobre eso, así que son *más* altas de lo que parecían.

---

## 1. Jugando, que el «te he oído» pase por las mismas cuatro guardas que fuera del juego

**El número:** 358 líneas `ignorado: estas jugando` en `assistant.log`. Con un juego delante, en todo el log **una sola** hipótesis llegó a una guarda: **359 de 360 (99,7 %) entran sin que nadie mire nada**. Fuera del juego esas mismas guardas tiran 156 de 540 (28,9 %: 7 por altavoces fuertes, 44 por «suena demasiado flojo», 105 por confianza). Por hora: 21,5 hipótesis con tu nombre por hora con juego (1.003 min medidos, 17 ventanas) contra 4,1/h sin juego (7.815 min) — **5,2 veces más**. Y es un suelo, porque la línea va topada a una por minuto (`wake_vosk.py:3540`). Esta noche: 54 entre 20:28:29 y 22:53:52, y **18 marcas después de que a las 21:48:55 le dijeras «no, no me hablas por 10 minutos»**. Dieciocho vibraciones tras pedir silencio.

**Hoy:** en `wake_vosk.py:3539`, la rama `if solo_boton:` es la PRIMERA de la cadena, por delante de `elif salida > UMBRAL_ALTAVOZ_FUERTE` (3549), `elif pico_rafaga < umbral_rafaga()` (3554), `elif conf < umbral_confianza(plano)` (3561) y `elif not juez_deja_pasar(texto)` (3584). Con un juego delante, cualquier cosa que Vosk fabrique con la palabra «nova» dentro cuenta como que la llamaste, escribe `tmp\llamada-en-juego.txt` (3546) y desde anoche Nova lo dice y saca el popup (`assistant.ps1:8247-8256`).

**Qué se hace:** mover la rama `solo_boton` al final, justo antes de `elif ahora - ultima_marca > 2.0` (3586), para que solo llegue ahí lo que ya pasó altavoces, ráfaga, confianza y juez. Y escribir en esa línea del log la confianza, la ráfaga y el nivel de altavoces, que hoy no salen: sin ellos no se puede repartir las 358.

**Obligatorio al moverla:** darle su propio reloj. Hoy `ultimo_aviso_solo_boton` lo comparten la rama de juego (3541) y la de altavoces fuertes (3550); eso no molesta porque jugando la segunda nunca se alcanza, pero en cuanto baje sí se alcanzará y los altavoces del juego estarán reseteando esa ventana todo el rato — y entonces tu llamada buena dentro de los 60 s siguientes no escribiría la marca y te quedarías **ignorado en silencio otra vez**, que es lo que se arregló anoche. Variable aparte (`ultimo_aviso_juego`).

**Lo que NO se toca:** `Start-Vibracion` (`assistant.ps1:8252`) se queda como está, en 'primera' y en 'otra'. Está puesta a propósito como acuse de recibo y ya va topada por el worker. Si después del cambio siguen sobrando vibraciones, se mira el número que quede; no se quita a ciegas.

**Gana:** deja de hablarte y de vibrarte el mando por cosas que dijo It Takes Two, y el «te llamé N veces y no te hice caso» de mañana pasa a ser un número real.

**Riesgo de orden equivocada: ninguno.** Solo añade guardas que ya usas fuera del juego; no ejecuta nada. El único peligro está en olvidarse del reloj aparte, y por eso va como parte obligatoria.

---

## 2. Jugando, que la ventana del micro se cierre cuando dejas de hablar, no a los 30 segundos

**El número:** esta noche 5 seguimientos llegaron al tope duro (21:44:46, 21:45:27, 21:46:21, 21:47:12, 21:47:57), cada uno con `audio de 30.0 s recortado a 15 s`. De abrir el micro a tener texto: **34, 33, 37, 32 y 40 s — 176 segundos para cinco frases.** Lo que salió: «Sí, estoy trabajo aquí en una parte», «me necesito ayudas a internazando», «Otra oliada, ¿me? Estamos». En los 13 días hay 8 sucesos de tope duro: 3 repartidos en 11 días y **5 esta noche en 4 minutos**. Y 27 transcripciones en total recibieron 15,0 s clavados, o sea que el fallo no es de hoy, se repite.

**Hoy, y el diagnóstico original estaba mal:** la culpa NO es de `techo_puerta()`. Esta noche la puerta valía 0,0123–0,0164, y eso es `suelo * SUELO_FACTOR` con `SUELO_FACTOR = 1.15` (`wake_vosk.py:359`) — comprobado con la aritmética del propio log: `suelo=0.0143 puerta=0.0164` y `suelo=0.0107 puerta=0.0123`. El techo valía ~0,034, muy por encima, así que nunca se aplicó. **Quien deja pasar el juego es que la puerta está solo un 15 % por encima de un suelo medido con el juego sonando:** el suelo sube con el juego y la puerta sube con él, así que las explosiones siguen asomando y rearman `ultima_voz` (`wake_vosk.py:3338-3340`), y la ventana solo cierra por `DICTADO_MAX = 30.0` (217). Después `TRANSCRIBIR_MAX` corta a 15 s y a Whisper le llegan ~4 s tuyos y ~11 del juego, con diálogo en español dentro. No son dictados con botón: son `DICTADO (seguimiento)`, ventanas que Nova se abre sola.

**Qué se hace (sin quitar la regla de energía, añadiendo una segunda más lenta):**
1. `ultima_voz` se queda como está. Al lado, una `ultima_palabra` que solo se refresca cuando el parcial o el final del reconocedor **han crecido** respecto al bloque anterior — la misma comprobación que ya existe en 3352-3357, reutilizada, no duplicada.
2. En el cierre (3393), una rama nueva que no toca el cierre normal: cerrar también si `hay_algo` y `nivel_salida() > UMBRAL_ALTAVOZ` y `(ahora - ultima_palabra) >= SILENCIO_SIN_PALABRA`. Fuera de los altavoces, todo igual que hoy.
3. `SILENCIO_SIN_PALABRA` sale **medido** (huecos entre palabras decodificadas dentro de tus órdenes reales, con `pruebas/audio/uso/destinos.jsonl`), como se sacó `SILENCIO_FIN`. Hasta tenerlo, 3,0-3,5 s: mata la ventana a ~4 s en vez de a 30 y deja el doble de margen que tu pausa más larga medida (1,44 s).
4. El cierre se anota con su motivo (`cerrado a %.1f s: los altavoces sonaban pero no salía ni una palabra nueva`). Un truncado silencioso no se puede medir.

**De propina, y se puede hacer aunque lo demás se caiga:** mover el cálculo de duración (`wake_vosk.py:1450`) y la guarda del tope (1453) por encima de las tres ramas que eligen modelo (1441-1449). A las 21:45:31 cargó `small` durante 3,7 s para decir acto seguido «30.0 s de audio es demasiado para repasar (tope 8 s)».

**Gana:** ~25 s por turno, 176 s solo en los cinco de esta noche; y Whisper oye tu frase en vez de tu frase con el juego encima, que es de donde salen los disparates.

**Riesgo de orden equivocada: bajo, y lo que lo hace seguro:** un texto entregado por esta rama nueva se marca como transcripción no fiable — puede ir a charla, y puede ejecutarse si LOCAL lo reconoce limpio, pero **el paso a opencode exige confirmación** (a las 21:48:08 un descarte de LOCAL mandó la orden entera a opencode). Así, si algún día corta a media frase, lo peor es que pregunte.

---

## 3. Que el aviso del disco hable cuando el disco se llena, y que nombre sus propios 2,3 GB muertos

**El número:** **ahora mismo C: tiene 852 MB libres de 475,53 GB: el 0,18 %.** El último aviso fue `2026-09-22 08:33:55 ENTORNO (disco-poco, medio): Te quedan 11.1 gigas` — **14 h 23 min de silencio mientras caían 10 GB**. De esos, 12 h son el plazo de 720 min haciendo lo que está escrito, y 2 h 23 son la puerta del juego. Lo peor viene ahora: a las 23:00 coge el relevo el silencio nocturno, así que aunque sueltes el mando, el nivel 'medio' sigue mudo **hasta las 08:00**. Y sí hay algo llenándolo: `Steam\steamapps\downloading` son **5,87 GB escritos hoy**. Aparte, `vosk/vosk-model-es-0.42` pesa **2,3 GB y no lo usa nadie** (solo `tools/medir-vosk-grande.py`; Nova usa el small de 58 MB, `wake_vosk.py:1578`): borrarlo lleva el disco de 0,83 a 3,13 GB, **×3,8 el margen**.

*(Se cae el cuento del pagefile: las 9 muertes del worker del 22/09 son de 07:41 a 13:15 y los 24,2 s de Whisper de las 09:50, cuando había ~11 GB libres. De 13:15 a 22:57, mientras el disco caía a cero, el worker murió cero veces. No es la causa.)*

**Hoy:** `assistant.ps1:21195-21196`, `if ($gbLibres -lt 15) { Send-AvisoEntorno 'disco-poco' ... 'medio' 720 }`. Un listón a mano, un nivel, 720 min. Y `Test-PuedoAvisar` (7911) tira todo lo que no sea 'alto' si `$script:juegoActivo`, y calla de 23:00 a 08:00.

**Qué se hace:**
- Un escalón crítico de nivel `'alto'` **por flanco**, con el patrón de `Test-BateriaLlenaFlanco` (21134): avisa en la vuelta en que cruza hacia abajo y no se rearma hasta que vuelve a subir por encima del listón + 2 GB. Nada de `cadaMin 60` sobre un estado — eso es el fallo que cerró la auditoría de anoche.
- Sacar las tres guardas de dictado del `if ($nivel -ne 'alto')` de 7911 y aplicarlas a **todos** los niveles: si estás dictando, el aviso espera a que sueltes el botón. No se pierde, sale después. Un disco que lleva 14 horas muriéndose puede esperar cuatro segundos; una orden cortada por la mitad no se recupera. Esto cierra de paso la misma rendija de `bateria-baja`.
- El listón **medido** y en `config.json`: el hueco que Windows necesita para crecer el pagefile (`MaximumBaseSize − AllocatedBaseSize`), no «la mitad de lo reservado».
- Texto plano de una frase: *«Quedan 0,8 gigas en el disco; con esto me quedo sorda.»* Sin drama.
- La línea del peso muerto **nombra una sola ruta exacta**, `vosk\vosk-model-es-0.42`, con el peso calculado en el momento dentro de esa rama (que dispara una vez al día, nunca en el bucle por minuto) y colgando de un `Test-Path` para que se apague sola si ya la borraste. **Nada de barrido genérico de «modelos que no cargo»**: `modelos\` son 1,2 GB y la caché de Hugging Face 2,2 GB, y las dos se usan — un barrido acabaría invitándote a borrar el oído que funciona.
- Quitar de ese aviso la promesa «pregúntame qué ocupa más»: no hay manejador en las 17.600 líneas. Hoy te ofrece algo que no sabe hacer.

**La pregunta, que es tuya:** ¿borro los 2,3 GB del Vosk grande? Se midió esta mañana y no sirve (Vosk solo oye el nombre y ya va al 96-100 %; tres intentos de medirlo murieron por memoria). `vosk/` está en `.gitignore:15` y no está versionado, así que recuperarlo sería rebajarlo de internet — y con 852 MB libres hoy no cabría. Si se borra, hay que retirar `tools/medir-vosk-grande.py`, que revienta en su línea 141.

**Gana:** el aviso llega cuando pasa, no nueve horas después; y 2,3 GB que multiplican por 3,8 el margen de la consola.

**Riesgo de orden equivocada: ninguno mientras solo HABLE.** En cuanto borre, vacíe una caché o pause una descarga, es una orden que no diste, y encima con el juego delante donde ni te enteras. La frase **nombra, no ofrece**: prohibido terminar en «¿lo borro?» o en confirmación — con el oído al 70,4 % un «sí» mal oído son 2,3 GB de un solo sentido. Borras tú, a mano.

---

## 4. Que «cállate» no te abra el micrófono

**El número:** 10 `INTERRUMPIDA` en 13 días. Tres son tu nombre (correcto: se calla porque vas a hablar). **Siete son palabras de parada**: 'silencio' (14/09 09:44:42), 'callate' (14/09 18:27:54), 'espera' (14/09 18:39:44), 'basta' (15/09 14:13:57), 'para' (15/09 14:49:41), 'para' (21/09 00:07:53), 'calla' (22/09 08:35:41). El micro se quedó abierto **14 + 10 + 50 + 4,4 = 78,4 segundos después de mandarla callar**. Y la que cuenta: el **21/09 a las 00:07:53** dijiste 'para' (confianza 0,96), Nova paró, reabrió el micro y a los 10 s cogió **«Botoncito atrás y el botón abajo»** — tú explicándole los mandos a quien juega contigo. Eso pasó por Parakeet, por Whisper, se mandó a **Gemini** (00:08:04) y a la **API de Claude**, y **21 segundos después de que la mandaras callar volvió a hablar**: «No te entiendo bien, ¿qué quieres hacer?» (00:08:14) y «¿Presionar botones de la consola o algo en el juego?» (00:08:19).

**Hoy:** `PALABRAS_CORTE = ["espera","para","calla","callate","basta","silencio"]` (`wake_vosk.py:2311`) más tu nombre. Las siete entran por la misma rama, `assistant.ps1:19953-19966`, donde el comentario «y te escucha, sin decir 'nova'» (19961) está escrito para el caso del nombre y se aplica a los seis que significan lo contrario. La distinción ya existe once líneas más arriba, en 19944.

**Qué se hace:** meter **las tres líneas** dentro de un `if` que reutilice la comparación de 19944: `seguimientoPendiente` (19962), `seguimientoFactor` (19963) y `ventanaCharla` (19964). Si solo mueves la primera, las otras dos quedan escritas sin ventana que las use y le pisan el valor a tu siguiente orden (se consumen en 18283-18285 y solo la primera se limpia sola en 20076). **`pausaHasta` (19965) se queda FUERA, en los dos caminos** — es lo que hace vencer la pausa y dispara `Reanudar-Escucha`; si se cuela dentro, al decirle «cállate» se queda sorda hasta que venza la frase que acabas de cortar. Callarse sí; quedarse sorda no. Y que el log distinga las dos ramas («me callo» / «me callo y te escucho»), o dentro de una semana no sabrás si sirvió.

**Al callarse, ni una palabra.** Nada de «vale». El `gesto:paciencia` de la cápsula ya lo dice sin hablar.

**Gana:** 78 s de micro abierto que no debía estarlo, y cierra la única vía del log por la que una frase que no era para Nova entró sola, acabó en dos nubes distintas y en dos frases habladas 21 s después de pedirle silencio. Es lo que pediste anoche: que cuando dice «me callo», se calle.

**Riesgo de orden equivocada: ninguno.** Quita una apertura de micro, no añade ninguna. No convertirlo en sordina ni en «modo callado»: la sordina tiene su propia puerta (19942) y su salida por el nombre.

---

## 5. Pasar la regla del «tío» por lo que ya está guardado, no solo por lo que llega nuevo

**El número:** se lo pediste **3 veces habladas** (20/09 23:05:26 «deja de decirme man», 20/09 23:19:17 «deja de llamarme tío», 21/09 00:02:56 «deja de decir tío, no me gusta esta palabra, guárdalo en memoria»), y Nova prometió **dos veces** que no («A partir de ahora sin el 'tío'», 20/09 23:19:27; «De ahora en adelante sin 'tío'», 21/09 00:03:04). **Hoy, dos días después, a las 21:48:35: «No te sigo, tío».** En `memoria\cerebro\cerebro.json` (guardado hoy a las 21:49) hay 12 entradas de `estilo`: **2 dicen que SÍ** («Prefiere tono casual y desenfadado (tuteo, 'man')», «tono informal y de confianza ('tío')») y 5 dicen que no. Las 12 viajan juntas, en la misma frase, en todas tus charlas. *(«man» sí se corrigió: 4 veces antes de que lo pidieras, cero después. El síntoma vivo es solo «tío» — pero la entrada del «man» sigue armada en disco.)*

**Hoy:** `charla_memoria.py:409-410` mete la lista entera de `estilo` en el prompt sin condición. Hoy a las 16:55 se escribió en `charla_memoria.py:628-639` la regla que resuelve justo esto («la última palabra sobre una palabra gana»), y su comentario dice «Probado sobre las 12 de verdad: quedan 7». Pero vive dentro de `_estilo()`, con **una sola llamada** (`:580`), que solo corre cuando llega una entrada nueva. `cargar()` (`:205-212`) hace `json.load` + `update` y no repasa nada. La regla lleva escrita desde las 16:55 y a las 21:48:35 seguía diciendo «tío», porque el veneno ya estaba en disco.

**Qué se hace:** sacar el bloque 628-639 a un método propio (`_podar_estilo(lista) -> lista`) que llamen los dos sitios — si se copia, el próximo retoque de la regla volverá a no alcanzar a lo guardado, que es literalmente el fallo que se arregla. Simulado sobre el `cerebro.json` real: **12 quedan en 7**, se van las 2 que te contradicen y 3 copias sobrantes del «sin tío», y sobreviven «No usar la palabra 'man'» y «prefiere que no le digan 'tío'».

**Crítico, y sin esto no se hace:** la poda va **fuera** del `try` de `cargar()` (después de la línea 219) y con su propio `try/except`. Dentro, cualquier excepción cae en el `except` de 213-219, que hace `os.replace` a `cerebro.json.corrupto-<fecha>` y `self.datos = self._vacio()`: no verías un error de poda, verías **a Nova arrancando en blanco, sin los 110 recuerdos, en silencio**. Y una línea en el log del worker con lo que quitó («estilo: 12 → 7, fuera: ...»); al log, nunca por voz.

Se toca el código y el efecto llega al reiniciar el worker. No editar `cerebro.json` a mano con Nova encendida: lo reescribe entero en cada `guardar()` y te lo pisa.

**Gana:** deja de pedirle al modelo en la misma frase que te hable con confianza llamándote «tío» y que no te llame «tío». Se acaba la única orden que has tenido que repetir tres veces y que ha roto después de prometerla dos.

**Riesgo de orden equivocada: ninguno** (no toca ningún camino de ejecución). El riesgo de verdad es el del `try/except`, y por eso va marcado arriba.

---

## 6. El aviso del correo: quién te escribe, no el asunto entero

**El número:** 2 avisos `correo-manana` en el log: 19/09 09:20:34 (271 caracteres) y 22/09 08:35:13 (**327**, el hablado más largo de Nova; el segundo son 210). Medido de verdad, no estimado: el 19/09 la pausa va de 09:20:38 a `pausa: fin` 09:21:05 = **27 segundos clavados de micrófono sordo** para 271 caracteres; a ese ritmo los 327 de hoy fueron **~32,5 s**. Y hoy a las **08:35:41 le dijiste «calla»** (confianza 0,94): es la **única vez en todo el log** que cortas algo que Nova empezó por su cuenta — el aviso de ruido sonó 25 veces y no lo cortaste ni una. Además, de los 4 asuntos que leyó, **2 eran byte a byte el mismo** («Chase, El saldo disponible de tu cuenta está por debajo de tu límite de $50.00 para la....»). Los dos días leyó en voz alta un aviso de saldo de tu banco.

**Hoy:** `Format-Correos` (`assistant.ps1:5579`) mete los 4 primeros con remitente **y asunto entero** (recortado a 80 con un '...' que la voz arrastra), sin juntar repetidos y sin mirar cuánto va a durar. Lo llama `Receive-CorreoManana` en `assistant.ps1:8961` con nivel 'medio', o sea que se dice. La función hermana `Get-ResumenNotificaciones` (7388-7394) ya lo hace bien con lo mismo: agrupa, cuenta y ofrece.

**Qué se hace:** que el aviso **no pedido** use el molde de la hermana: *«Tienes 5 correos nuevos: 2 de Chase, uno de Experian y 2 más.»* ~90 caracteres, ~9 s. Puede decir de quién es (eso es lo que te deja decidir); **el asunto no** — si lo acortas y dejas el asunto no has ganado nada. El aviso pedido (`Invoke-Correo`) no se toca.

**Lo que NO se copia sin arreglarlo antes:** el «Di léemelos». `$script:correoOfrecido` se asigna en **un solo sitio** de las 17.600 líneas, la 5621, dentro del camino **pedido**; `Receive-CorreoManana` no lo toca nunca. Así que hoy esa oferta acabaría en «Primero dime: revisa mi correo» (5633-5635) todas las mañanas: un callejón sin salida. Si se quiere la oferta, van las dos cosas juntas: `$script:correoOfrecido = @($rC.correos)` antes del `Send-AvisoEntorno` de 8963, **y un plazo** (`correoOfrecidoVence`, con el patrón de `$script:pendiente` de 5666, y el número en `config.json`), porque el regex de 3778 coge también «todos», «dímelos», «léelos», «cuáles son», «qué dicen», y hoy no caduca: diciendo «todos» a las nueve de la noche jugando te comerías el correo leído en voz alta. **Lo mínimo y seguro es solo acortar y agrupar, sin abrir escucha**: el camino a petición ya existe.

**Gana:** de 27-32 segundos a ~9, y deja de estar sorda 20 de esos segundos. Se acaba leerte dos veces el mismo asunto y decir en voz alta el saldo de tu banco sin que nadie lo pida.

**Riesgo de orden equivocada: ninguno si solo acorta.** Pasa a medio en cuanto arme un ofrecimiento sin plazo — eso es un modo que se queda activo, y es justo lo que rechazas.

---

## 7. Que lo que repites renueve el dato que se le parece, no el primero que pasa el listón

**El número:** hoy, de 21:44 a 21:49, se produjeron las **5 primeras renovaciones reales** del perfil (`grep -c "pero renuevo el que ya estaba"` = 5), y **las 5 fueron al dato equivocado**:

| Lo que dijiste | Lo que blindó |
|---|---|
| «Braya juega It Takes Two» | «braya juega juegos de terror» |
| «braya juega a It Takes Two» | «Braya juega a un videojuego llamado La última parada o similar» |
| «braya juega a It Takes Two» | «Braya juega videojuegos de supervivencia...» |
| «Braya juega videojuegos» | «braya juega Elden Ring» |
| «Braya juega a videojuegos» | «braya juega con otras personas» |

Y el remate: **«It Takes Two» no está en `memoria\perfil.md`.** Se aprendió el 18/09, bloqueó tres menciones, se lo llevó el tope, y hoy sus tres menciones nuevas no pueden volver a entrar porque chocan con «juegos de terror». **Nova no sabe a qué estás jugando ahora mismo**, y las tres veces que intentó aprenderlo le regaló la protección a otra cosa. En esos 6 minutos el tope desalojó 4 datos reales. Las palabras tapadera son «braya» (29 de 60 datos) y «juega» (11 de 60): comparten 2 de 3 y el listón es 0,60.

**Hoy:** el bucle de `assistant.ps1:7002-7040` recorre el perfil en orden y hace `return` con el **primero** que pasa el listón, no con el que más se parece. Hasta hoy eso solo descartaba; desde el cambio de hoy además renueva (manda al final), y como el tope poda por el principio (7061-7069), renovar es volverse inmune al desalojo.

**Qué se hace (solo esto):** quitar los dos `Save-DatosPerfil` + `return $null` de dentro del bucle; el bucle solo puntúa y guarda el mejor en `$mejor`/`$mejorPunt`; fuera, si hay `$mejor`, se mueve al final, un solo `Save`, una sola línea de `Log`. Puntuar por niveles para que la coincidencia fuerte no la gane una floja: **nivel 2** = `$cx -eq $clave` o `$cx.Contains($clave)` (lo que hoy es la primera rama); **nivel 1** = la regla proporcional de hoy (`0.6` o `comunes >= 3`). Dentro del mismo nivel, desempate por `[Math]::Max($propD,$propX)`, luego `$comunes`, y a igualdad el más viejo — así el resultado deja de depender del orden del fichero, que es el defecto que se arregla.

**No se tocan los umbrales ni `$PerfilMax`.** Este cambio no debe poder meter ni sacar ningún dato: si al probarlo se mueve el recuento del perfil, está mal hecho. Dos casos al banco, que tienen que **fallar con el código de ahora**: entrando «braya tiene novia» sobre el `perfil.md` de hoy debe renovarse «tiene novia» y quedarse quieto «braya tiene sentido del humor»; y un dato contenido en uno tardío no puede perder contra un 0,67 temprano.

*(Se deja fuera a propósito la lista de palabras genéricas: cuesta ~11 plazas de 60 y necesita su propia medición. Si alguien la quiere, que venga sola y diga qué 11 datos reales se caen.)*

**Gana:** lo que repites deja de blindar a un dato que no tiene nada que ver, y el desalojo vuelve a significar «lo que llevas más tiempo sin repetir».

**Riesgo de orden equivocada: ninguno.** Solo cambia a cuál se le renueva la fecha.

---

## 8. Que el parte de la mañana espere a que estés, en vez de gastarse a las 05:00

**El número:** desde el 20/09 el parte sale a las 05:00:2x clavadas. Tu primera actividad real: **20/09 a las 12:53 (472 min después), 21/09 a las 16:31 (691 min), 22/09 a las 20:25 (925 min)**. *(El dictado de las 08:00:50 de hoy no eras tú: viene de «INTERRUMPIDA: 'nova' mientras hablaba» — Nova se oyó a sí misma tras el aviso de ruido de las 08:00:25 — y acaba en «seguimiento: sin voz en 4.4 s». Entre las 05:00 y las 20:25 hay **cero** líneas `descartado 'nova'`: no estabas, y no es que no te oyera.)*

**Y es peor que llegar tarde: los tres días no llegó.** El texto va a `$script:resumenPendiente` (`assistant.ps1:7592`), que es variable de sesión (declarada en 9082 con el comentario «en memoria y no en disco a propósito»). Los tres días Nova reinició entre el parte y tu vuelta (20/09 12:08:45, 21/09 12:48:34, 22/09 07:44:51), mientras `parteVisto` ya estaba escrito en `habitos.json`. **Día gastado en disco, mensaje perdido en memoria: 3 de 3.** Hay una segunda vía sin reinicio, y el propio código la documenta en 9099: el consumidor (20033) dispara en cuanto Nova habla cualquier cosa, así que el aviso de ruido de las 08:00 de hoy habría pintado el parte a una habitación vacía. Dos de los partes, además, te daban los buenos días con «🌙 23°».

**Hoy:** `Test-ParteManana` (`assistant.ps1:7537`) solo mira el reloj: `if ($ahora.Hour -lt 5 -or $ahora.Hour -ge 12) { return }`. Hasta el 20/09 solo la llamaba `Process-Texto`, o sea que la disparaba tu primera orden y caía encima de ti (0, 0, 0 y 7 minutos de desfase los días 14-19). Desde el 20/09 la llama también el bucle (8201) y ahí no hay nadie que la dispare.

**Qué se hace:**
1. Un `[switch]$DesdeBucle`, pasado **solo** desde `Watch-Entorno` (8201). Es crítico: en `Process-Texto`, `Test-ParteManana` (18588) corre **antes** de `Set-HabloAhora` (18592), así que una puerta que aplicara también ahí bloquearía el parte exactamente en el momento para el que existe (187 arranques, mediana de sesión 5,8 min).
2. La señal: `Get-AusenciaMin` (9167), que lee `$hb.presencia['visto']` de disco (`Set-PresenciaAhora`, 9160) y **sobrevive a los reinicios**. No `$script:ultimoHabloEn` ni `$script:entornoUltimaActividad`: son relojes de proceso y valen 0 en cada arranque.
3. Presencia **reciente**: `(Get-AusenciaMin $ahora) -le 15`, no «alguna vez hoy». Si no, un botón a las 04:55 vuelve a soltar el parte a las 05:00 a una habitación vacía.
4. La puerta va arriba del todo, como un `return` seco. **No se toca dónde se sella `parteVisto`** (7565-7578, el arreglo del 21/09): así un día sin presencia no gasta nada y la ventana sigue abierta el resto de la mañana.

Y lo que no se hace, para que no se cuele por detrás: si entre las 5 y las 12 no apareces, ese día no hay parte. Nada de ensanchar la ventana ni de guardarlo para la tarde — eso es la idea de la hora variable, que está refutada.

**Gana:** el parte vuelve a caer 0-5 minutos antes de tu primera orden, como en 4 de 4 días hasta el 19/09, con el clima y la batería de ese momento. Tres partes por semana que hoy se pierden enteros.

**Riesgo de orden equivocada: ninguno.** La puerta solo puede impedir un parte, nunca dispararlo.

---

## 9. Entender «abre X en la mitad y en la otra mitad Y»

**El número:** **en 14 días la pantalla dividida no se ejecutó bien ni una sola vez por voz. Cero.** Hay 11 dictados tuyos con «mitad / dividida / split / pantalla izquierda-derecha» (1,6 % de tus 702 dictados), y el canónico «dividir pantalla» aparece **0 veces** en el log. Todo intento acabó en el modelo, en una búsqueda de Google equivocada o en una traducción basura. La forma concreta que arregla este cambio —«X en la mitad ... y en la otra mitad Y»— la dijiste **3 veces en 3 días distintos**: 18/09 20:03, 20/09 18:55 y 22/09 01:10. La de hoy costó **68 segundos** y acabó contigo cerrando el navegador a mano (01:11:16).

**Hoy:** `assistant.ps1:488, 493, 495, 500` tienen cuatro formas escritas de pedir pantalla dividida. Ninguna cubre esa. *(Y que no se mezclen dos cosas distintas: la del 18/09 19:04, «Sí, pero abre YouTube en la pantalla izquierda y Pinterest en la derecha», el patrón de 488 la coge perfectamente **en cuanto le quitas el «Sí, pero »** — eso es un problema de prefijo, porque el regex está anclado con `^`, y es otra idea, quizá más rentable. Y la del 18/09 20:03 llegó como «sobre youtube en la mitad...»: eso es el oído, no los patrones, y **no** se arregla metiendo «sobre» en `$VERBOS_OIDOS` (317-325), que es una lista cerrada a propósito.)*

**Qué se hace:** una rama más, como `elseif` **después** de la de 488 (para que «a la mitad izquierda... y en la otra mitad» conserve el lado que dijiste), que reescriba a «dividir pantalla $1 con $2» — canónico que ya existe y que ya ejecuta el kind 'dividir' (4844 / 11383). Con dos guardas:
- **Nada de `(.+)$` greedy.** Con la cola glotona, la frase real del 10/09 («...y en la otra mitad abre el navegador y busqué el gato con botas») deja `$2 = "el navegador y busqué el gato con botas"`, `Resolve-Target` falla y todo vuelve a opencode: cero ganancia en el caso con más peligro. Cortar con `|`, como ya hace la rama de 501-506, que es el separador que `Split-Compound` respeta.
- **Que no dispare con el volumen.** «A la mitad» es también el canónico del sonido y del brillo (4888, y `$mitad` en 4967/4999): que no entre si `$1` casa `^(?:el\s+|la\s+)?(volumen|sonido|brillo)\b`. Una línea, y elimina la única colisión plausible.

**Al banco:** las frases reales a `pruebas/destinos.txt`. La que hoy resuelve **mal** («En el navegador busca YouTube y Pinterest a la pantalla dividida» → busca la frase entera en Google) va con su destino **correcto**, en rojo, no omitida ni con el destino que da hoy. Y que quede dicho: **ese caso no lo arregla este patrón**, necesita una regla aparte.

**Gana:** las tres veces que la pediste con esa forma, incluida la de hoy; los 68 s de esta madrugada, los 2 min 35 s de la tanda del 18/09 y los 11 min 35 s de la de las 20:03.

**Riesgo de orden equivocada: bajo.** No ejecuta nada nuevo, reescribe a un canónico que ya existe; la única colisión (volumen/brillo) se cierra con la guarda de arriba.

---

## 10. Que «a esta hora no sueles estar levantado» se decida con la hora a la que paras de verdad

**El número:** 4 avisos `hora-dormir` (18/09 23:30, 19/09 23:00, 20/09 23:00, 21/09 23:00). **Los 4 los desmiente `habitos.json`**: esas noches seguiste 8, 84, 138 y 138 minutos más (fin 23:38, 00:24, 01:18, 01:18). Tu hora habitual de parar, con la misma cuenta que hace `Get-HoraFinHabitual`, son las **00:24**, y en 5 de los 7 días válidos seguías despierto pasadas las 23:00. Es el único aviso de nivel `'noche'`, el único que se salta el silencio de 23:00 a 08:00 (7915-7920): lo único que Nova dice de madrugada es algo que no es verdad.

**Dos matices que cambian a dónde apuntar:** la medida buena solo habría callado **3 de 4** (el 18/09 solo había 3 días en `fin`, y `Get-HoraFinHabitual` habría devuelto -1). Y el caso de las 23:00 **ya se auto-curó**: el propio cuarto aviso dejó una charla en `2026-09-21|23`, y con tres días `$diasD -ge 3` devuelve ''. Por eso hoy, con Nova encendida pasadas las 23:00 (presencia 23:01:31), no ha saltado. **La exposición viva está una hora más tarde:** `charlaHoras` tiene `|00` en 2 días y `|01` en 2 días, los dos por debajo de 3, y el filtro de 8338 deja pasar las horas 0 y 1. Antes no llegaba ahí porque el `cadaMin` de 480 ya se había gastado a las 23:00; esta noche ese freno no está.

**Hoy:** `Get-AvisoHoraDormir` (`assistant.ps1:8337-8345`) decide contando `charlaHoras`: las horas en las que has tenido **conversación**, no en las que usas la consola. Ese diccionario se llenó para otra cosa (la precarga de la charla, 16241) y tiene 25 entradas.

**Qué se hace, todo dentro de esa función:** sustituir el criterio de 8341-8343 por la comparación de minutos contra `Get-HoraFinHabitual` (9381), con la misma normalización +1440 que ya usa `Test-RecordarCarga` (9263-9265) — así cubre las 23, las 00 y la 01 de una vez — y devolver '' si la mediana es -1. Con cuatro condiciones:
1. **Suelo duro a las 23:00.** La guarda de 8338-8339 se queda tal cual y el listón nuevo se suma encima: `max($finH + margen, $EntornoNocheDesde * 60)`. `fin` mide la última orden, no la hora de dormir (el 13/09 vale 17:24); sin suelo, una semana en que uses poco a Nova por la tarde baja la mediana y el aviso se te adelanta a las 21 h.
2. **No tocar `$EntornoNocheDesde` ni `nocheHasta`.** Ese número tiene dos usos que tiran en direcciones opuestas y moverlo cambia cuándo se calla Nova para todo.
3. **El margen no es un número nuevo:** reutilizar los 30 minutos que `Test-RecordarCarga` ya usa alrededor de ese mismo `$finH` (9260). Cero constantes nuevas que revisar.
4. **El -1 se calla, pero deja rastro:** una línea de Log («HORA DORMIR: sin datos suficientes, callado») la primera vez de cada día, no en cada vuelta. Aquí un medidor que se para en silencio es peor que no tenerlo.

El texto puede decir su número, **una sola frase**: «Son las 01:40 y sueles parar sobre las 00:24.» Sin consejo detrás.

**Gana:** deja de decirte cuatro noches seguidas algo que sus propias medidas desmienten, justo en el único hueco donde tiene permiso para hablar de madrugada. Y la decisión pasa a salir de tus días.

**Riesgo de orden equivocada: ninguno**, solo habla. **A vigilar:** pasa de sonar a las 23:00 (contigo delante) a sonar hacia las 00:55, a veces cuando ya te has ido. Sigue siendo uno por noche y sigue callado jugando. Si en una semana el log muestra que suena a diario sin actividad tuya alrededor, se apaga; no se afina más.

---

## Las dos que también pasaron, pero cambian menos

**11. La revisión propia: ni se acuerda del día ni sabe lo que cuesta.** `$script:revisionPropiaDia` vive solo en RAM (`assistant.ps1:8635`): el 21/09 se revisó **9 veces** (10 arranques; 223 arranques en 13 días). «REVISION PROPIA» sale **0 veces** en todo el log, así que el choque aún no ha pasado — pero la nube está a ~7 intentos de pasar el reparto y el oído fino a 12 de pasar la regla de intentos: pueden cruzar la misma semana, y entonces la segunda decisión del día pisa a la primera y la primera se queda puesta **sin poder deshacerse hablando**. Se persiste el día (mejor en `habitos.json`, que ya guarda `parteVisto`), con una función `Set-RevisionDia` que escriba variable y clave a la vez, y limpiando la clave en los **cinco** caminos de fallo (8760, 8788, 8844, **8883** y el `catch` de **8741**), no en tres: si no, un fallo de disco bloquea la revisión el día entero y además sobrevive al reinicio. Lo más urgente es `Undo-DecisionPropia` (8490), cuya marca muere en el siguiente arranque. Segunda cara, y solo el primer paso: contar los segundos. `registro.jsonl`, 428 repasos en 7 días — base 309 (mediana 1,74 s), small 84 (mediana 4,46 / p90 14,91), turbo 23 (todos del 15/09, y **turbo ya está apagado**: `input.whisperModeloUltimo=''`). El coste vivo son **32,3 minutos de espera en 7 días** entre base y small, y `estadisticas.json` no tiene ni un contador de tiempo. Se apuntan suma y n por herramienta con una función aparte —**sin pasar por `Add-Estadistica`**, que dispararía `Write-DestinoUso` y contaminaría `destinos.jsonl`— y se añaden las claves a las listas de rutas de 2551 y 8731. **`$DecisionAprovecha` (8517) se queda en 0,15 fijo**: nada de escalarlo con el coste, eso apagaría el oído por reloj. Y con las medias en la mano, lo primero a mirar no es el listón sino las puntas (142,5 s y 238,9 s la madrugada del 21/09): eso se arregla con un tope, no bajando la barra. *Riesgo: ninguno; la marca solo puede impedir una decisión y el contador solo cuenta.*

**12. Apuntar las dos memorias en el pulso.** `ram_libre_mb()` (`wake_vosk.py:706-723`) rellena un `MEMORYSTATUSEX` entero y devuelve solo `ullAvailPhys`. Medido ahora: física 1.359 MB, commit 3.307 MB — **2,4 veces**. La línea del pulso que se añadió hoy (3753-3757) se puso justo para explicar la muerte silenciosa de la madrugada y apunta el único número que **no** puede explicarla: un proceso muere cuando se acaba el commit. Se añade una función **nueva al lado** (`commit_libre_mb()`), sin tocar la firma: hay 7 llamadas (754, 777, 887, 905, 958, 1016, 1782) que hacen `0 <= _libre < RAM_MIN_*`, una dentro del cerrojo `_carga_parakeet`, y `tools/probar-ram-modelos.ps1:35/39` solo comprueban que el **texto** aparezca, así que el banco seguiría en verde con el oído muerto. Escribir los dos en el pulso y en las cinco guardas que hoy cuentan una sola (778-780, 907-908, 960-961, 1017-1021, y la **muda** de 1782-1784, que se rinde sin escribir nada). **Las decisiones no se tocan:** repuntarlas al commit las haría más permisivas (cargaría con la física agotada y Windows pagina a disco), y en 20 muestras en vivo los dos números no discreparon ni una vez en el listón de 1200 MB. *Riesgo: ninguno, solo escribe en el log.*

---

## Si hubiera que elegir tres

**La 1, la 2 y la 3** — las tres te están pasando esta misma noche, con el mando en la mano, y las tres son pequeñas.

- La **1** porque 358 veces al día es la diferencia entre una asistente y un ruido, y porque 18 de esas marcas llegaron **después** de pedirle silencio.
- La **2** porque son 176 segundos perdidos en cinco frases y porque las transcripciones que produce («me necesito ayudas a internazando») son el material del que salen las órdenes que no pediste.
- La **3** porque tienes **852 MB libres ahora mismo** y, tal como está el código, Nova no te lo va a decir hasta las 08:00 de mañana.

Si solo cupiera una línea de código, la **4**: mover `$script:seguimientoPendiente` dentro del `if` del nombre. Es el arreglo más barato de la lista y cierra la única vía del log por la que una frase que no era para ella acabó en dos nubes y en dos respuestas habladas 21 segundos después de mandarla callar.

---

## Lo que cayó, y por qué (para no volver a proponerlo)

1. **Parakeet prohibido jugando por decreto** — `jugando()` mira una sola cosa (`tmp\solo-boton.flag`) y el recuento no salía; además `modelo_parakeet()` tiene una vía rápida en `wake_vosk.py:997` **antes** del cerrojo y del listón, así que la sustitución no sustituía nada.
2. **El alt-tab que te cambia el brillo** — la mitad del brillo se salva, pero la otra mitad tocaba la palabra de activación (justo lo que rechazas) y la idea decía mal dónde está.
3. **No arrancar un repaso cuando el oído va más lento que el tiempo real** — el número salía clavado, pero el camino del repaso vacío **sí** puede acabar ejecutando algo: riesgo de orden equivocada.
4. **Los 30 s recortados a los 15 primeros** — el código ya tiene esa idea resuelta y mejor en `wake_vosk.py:3414` (`callado = ...`).
5. **El plazo de 15 s del repaso, mal contado por los dos lados** — la causa que atribuía no ha pasado nunca y la otra mitad ya estaba arreglada.
6. **Las ventanas de micro que no cogen nada** — la mitad principal ya está hecha y ya es adaptativa; la premisa del «2500 en config.json» es falsa (`assistant.ps1:16176-16182`).
7. **Cuando ningún oído saca orden se queda el peor español** — el número era exacto (210 líneas, 165 a charla), pero ese desempate **sí** puede ejecutar: el sitio real es `assistant.ps1:20583`.
8. **«Revisa mi correo sin abrirlo»** — 1 caso en el log, no 4, y el arreglo no arreglaba ningún caso real.
9. **Nova se reescribe la orden y 81 de 110 la devuelve igual** — la segunda parte convertía el reescritor en un clasificador de conjunto cerrado: vía directa a orden equivocada.
10. **Mientras juegas, el perfil se llena de la partida** — el número nació hace cinco horas (commit de hoy a las 17:02) y encima el arreglo tiraba una orden directa tuya.
11. **Las 336 escaladas `parakeet-a-whisper` que nadie lee** — apagar el repaso apagaría **la nube en silencio**: `Start-NubeOir` cuelga de ahí.
12. **El tope de espera de la nube con un p90 sin los 35 plantones** — ese p90 ya no decide nada, y la segunda parte era un trinquete que solo sabe subir.

**Dos que quizá cayeron por mal motivo, y las volvería a mirar mañana:**

- **«La mitad de lo que el perfil aprende salió de la boca de Nova»** — el mecanismo quedó **verificado** (`charla_memoria.py:862` pide datos «que dijo él» pero `:870-873` le manda el turno entero, con lo que Nova contestó dentro), y el segundo escéptico dice expresamente que es un filtro, que no ejecuta nada, que no deja modo activo y que **aligera** el prompt. Leídos enteros, los dos motivos están a favor. Merece otra vuelta.
- **«El 1.200 y el 900 de la guarda de memoria son números a mano»** — cayó porque sus 7 rechazos eran todos de una noche ya arreglada, pero el segundo escéptico no la tumbaba: la dejaba muy acotada. Si se remide hoy, con It Takes Two abierto y la pila del oído dentro (medido: 1.233 MB la pila entera, no 2.500), vuelve a estar viva.