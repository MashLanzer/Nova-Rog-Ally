# Veinte ideas nuevas para Nova — 24/09/2026, tarde

*Todas medidas hoy sobre `assistant.log` + `assistant.log.1` (54.428 líneas, del 09/09 al
24/09), los JSON de `memoria\` y el propio código. **Ordenadas por lo que te cuestan a ti**, no
por el tamaño del número.*

**Y una regla que me ha mordido cuatro veces hoy, así que va delante:** cada idea dice **desde
cuándo existe el código** implicado. Contar fallos sin mirar eso es cómo acabé declarando rotas
cuatro cosas que ya estaban arregladas. Si algo dejó de pasar hace días, aquí lo pone.

---

## A. Promete cosas y no las cumple

### 1. Los recordatorios no han sonado NUNCA, y una fecha ilegible los borra en silencio

**0 líneas** `RECORDATORIO vence` en 54.428. Cero. Y no es que no se hayan creado: hay **295**
`RECORDATORIO (…)` (285 del banco, los demás tuyos).

El del 12/09 16:59:48 vencía el 13/09 a las 10:00:00, y Nova estaba **viva a esa hora exacta**
—hay una línea suya a las 10:00:00 clavadas—. No sonó.

La causa está en `Test-Recordatorios`: `try { $c = [DateTime]$r.cuando } catch { continue }`.
Ese `continue` se salta el `else { $quedan += $r }`, y el `Save-Recordatorios $quedan` de dos
líneas más abajo **lo borra del disco sin escribir una línea**. Y quien la llama lo hace con
`try { … } catch {}`, sin registro.

*Desde el 11/09.* · *Daño directo hasta hoy: cero* —los dos recordatorios reales que creaste los
cancelaste tú en menos de 25 segundos—. Pero es **la única función de Nova que promete algo a
futuro**, y nunca se ha ejecutado de verdad.

> **HECHA.** El `continue` del `catch` saltaba el `else { $quedan += $r }`, y el
> `Save-Recordatorios` de dos líneas más abajo guardaba la lista **sin esa entrada**. Ahora se
> conserva y se apunta una vez por arranque —no en cada vuelta, que sería el fallo de los 25
> avisos idénticos—, y el `catch` del llamador deja rastro. **No se adivina la fecha:** un
> recordatorio que no se puede leer se conserva para que puedas preguntar por él. Banco 2n132,
> 7 roturas y 7 rojas.

### 2. El recetario ejecuta sin IA y sin confirmar, y 3 de sus 8 recetas son basura de pruebas

`memoria\recetas.json` tiene **8 recetas y solo una tiene usos** (la id 1, con 2). Las **id 5,
7 y 8** ejecutan PowerShell **sin un solo hueco**: crean siempre `Desktop\Hola.txt`,
`Desktop\prueba` y `Desktop\Prueba dos`. La id 7 se aprendió de una frase **mal oída**: *"pon el
nombre prueba y la carpeta en el escritorio"* (20/09 18:58:22).

Una receta se ejecuta **sin IA y sin confirmar**. Con el oído al 70,4 %, eso es la regla 1 al
revés esperando su turno.

*Lo que haría falta:* rechazar las recetas sin ni un `{hueco}` y podar las que lleven N días con
cero usos. *Lo que se rompería:* alguna receta legítima de un solo paso fijo ("abre mis
capturas").

> **HECHA, y la regla 1 NO estaba rota.** `Get-PatronReceta` construye un regex **anclado
> `^…$` palabra por palabra**: margen cero. Probado con 15 variantes, *"pon el nombre prueba y
> la carpeta en el escritorio **ahora**"* no dispara, ni *"**ponle** el nombre…"*, ni siquiera
> tu frase original. Y las tres tenían `confirmadas=0`, así que preguntarían igual.
>
> Tampoco la id 7 salió de una frase mal oída: Parakeet oyó bien *"El nombre ponle prueba y la
> carpeta en el escritorio"* —eras tú contestando a *"¿dónde y con qué nombre?"*—. Falló el
> aprendiz, que metió "prueba" en el script en vez de hacer un hueco.
>
> Así que el arreglo es una **guardia al aprender**, no una poda: si una receta va a escribir y
> ningún valor acabó en hueco, solo puede hacer siempre lo mismo. El criterio se probó contra
> las ocho reales y separa las tres sin un falso positivo. Las tres ya no están; quedan cinco.

### 3. Una regla, una vez creada, no ha saltado jamás

`reglas.json` está vacío. En quince días creaste **dos** —una por voz el 11/09 que borraste 31
segundos después, otra escrita el 14/09— y **ninguna ha disparado nunca**.

Hoy se arregló la mitad: que un fallo del motor no se pierda callando. Lo que falta es lo otro,
y no se puede arreglar a ciegas: **hace falta una regla viva que observar.** La primera tarea es
crear una y ver qué pasa.


> **HECHA: el camino entero, probado por primera vez.** Cada pieza tenía su prueba; el camino
> completo, ninguna. El banco 2n137 crea la regla por voz **con tu frase exacta del 11/09**, la
> guarda, la relee del disco, la dispara con el juego, comprueba que hace lo que decía, y que
> **no** dispara con otro juego, ni al cerrarlo, ni con una app del mismo nombre, ni con la
> batería, ni con los cascos. Y que se puede borrar, que es lo que la convierte en un modo con
> salida.

---

## B. Habla cuando no toca y calla cuando sí

### 4. Nova habla por su cuenta casi tanto como cuando la llamas

Contadores de `memoria\estadisticas.json`:

| | avisos por su cuenta | veces que la llamaste |
|---|---|---|
| del 19 al 24/09 | **69** | 80 |
| antes del 16/09 | **0** | 119 |

Los avisos por su cuenta **nacieron el 16/09** y en una semana casi igualan a las veces que tú
la llamas. Cada uno por separado está justificado —y el propio código tiene escrito *"hablar por
todo es lo que cansa"*—. El problema es la suma, y **nadie está mirando la suma**.

> **HECHA, y el listón no es un número nuevo: es una proporción.** Nova no habla por su cuenta
> más veces de las que la llamas. Probada sobre los trece días reales: corta **26 de 79** y los
> 26 caen en los **dos** días en que sobraban (24 del 22/09 y 2 del 23/09). **Ni uno de los
> seis días buenos pierde un solo aviso**, y el banco comprueba justo eso. El suelo tampoco es
> nuevo: es el mismo tope por hora que ya había. Lo de nivel alto pasa siempre.

### 5. El parte de la mañana: 24 decisiones aparcadas y una dicha en total

El parte es el **único canal** por el que Nova cuenta lo que ha decidido sola. Última vez que
salió: **22/09 a las 05:00**. La decisión se aparcó **24 veces** (`SIN DATOS: lo dejo para el
parte` — 9 el 21/09, 4 el 22/09, 10 el 23/09, 1 el 24/09) y se dijo **una vez en total**, el
18/09, cuando el contador iba por "0 de 43". Hoy va por **126**.

La ventana es 05:00–11:59, y tu primera orden del día cayó dentro solo **3 de 15 días**.

*Desde el 13/09.* · *Te costó:* que hoy te enteraras de esto porque lo miró una persona, no
porque Nova te lo dijera.

> **HECHA.** La ventana deja de ser una hora: el parte sale **la primera vez que apareces**, a
> la hora que sea. Las dos guardas siguen enteras —una vez al día, y solo si te has dejado ver
> en los últimos 30 minutos— y sale por la cápsula, no por la voz, así que jugando no
> interrumpe. Las cinco de la mañana siguen siendo el principio del día. Y el saludo se adapta:
> "buenos días" a las nueve de la noche, no.

### 6. El correo: 26 conexiones para decirte tres frases, y siempre la misma

13 pares `CORREO: mirando el de la mañana` / `5 sin leer`, y solo **3** avisos (19, 22 y 23/09),
porque el aviso tiene plazo de 720 minutos. Peor: el 22/09 se conectó **4 veces esa misma
mañana** (07:00, 07:45, 08:34, 09:50) y 3 el 23/09 — la guarda de "una vez al día" **no
sobrevive a los reinicios**. Y son **los mismos 5 sin leer desde el 19/09**: la frase que oyes
es siempre idéntica.

*Desde el 16/09.* · Se arregla apuntando el día en `habitos.json`, como ya hace el parte, y
callando si el número no ha cambiado.


> **HECHA.** El día en que ya se miró el correo se apunta **en disco**, como el parte desde el
> 13/09. Y se apunta cuántos había: si el número no ha cambiado, no se repite. Que sigan sin
> leerse los mismos cinco correos no es una novedad. La ventana de 7 a 12 no se toca: ahí sí
> tiene sentido, y no hay ningún dato que diga lo contrario.

---

## C. Lo que Nova cree saber y no sabe

### 7. La batería por juego no ha aprendido nada en quince días

**0 líneas** `BATERIA:` y **0** `bateria-rara`, con `Update-BateriaJuego` llamada **cada
minuto**. La causa está medida: hay **11 líneas** `cargador:` en todo el registro, y de las 6
desconexiones **la más larga con Nova viva fue de 9 minutos** (19/09 09:24→09:33). El tramo
exige **10 minutos o más**. Nunca llega.

Consecuencia: `Get-DuracionBateriaJuego` devuelve `$null` **siempre**, y sus tres usos no
contestan nunca. El 23/09 jugaste **191 minutos** y Nova no sabía decirte cuánto te duraba.

*Desde el 13/09.* · *Al tocarlo:* tramos más cortos dan ritmos ruidosos y el aviso
`bateria-rara` (umbral ×1,6) empezaría a saltar en falso.

> **MEDIDA: la causa no era el umbral.** Los **seis** tramos reales dicen que hay 169,7 min
> desenchufada en quince días y que el solape juego-sin-cargador son **cinco minutos**, uno
> solo. Probado con 10, 8, 6, 5, 4 y 3 minutos: el único candidato —ELDEN RING, ~5 min, ~1,7 %
> de caída— **tampoco pasaría el filtro del 2 %**.
>
> El motivo es que **juegas enchufado**: el 23/09 jugaste 191 minutos y el único desenchufe de
> ese día duró 1 minuto, 28 antes de abrir el juego.
>
> Así que **el umbral no se toca** —bajarlo daría un ritmo sacado de una muestra ruidosa, que es
> mentir con cara de dato—. Lo que faltaban eran datos: ahora el porcentaje se apunta cada vez
> que cambia, con el cargador y el juego al lado, en el fichero del latido. Dentro de unos días
> se podrá decidir de verdad.

### 8. De ELDEN RING solo ve el 2 % de lo que juegas

Comparado `memoria\juegos.json` con lo que dice Steam:

| | Nova ve | Steam (2 semanas) | ve el… |
|---|---|---|---|
| Black Myth: Wukong | 1,63 h | 1,7 h | 97 % |
| A Way Out | 3,15 h | 3,4 h | 93 % |
| It Takes Two | 12,86 h | 16,2 h | 80 % |
| Unravel Two | 0,06 h | 0,1 h | 64 % |
| **ELDEN RING** | **0,10 h** | **6,1 h** | **2 %** |

Lo detectó en primer plano **7 veces** y acumuló 354 segundos. Y de los **9** juegos que llegó a
ver en primer plano, solo **6** guardaron tiempo.

*No sé por qué*, y eso es lo que hay que averiguar antes de tocar nada.

> **MEDIDA e investigada contra una fuente que no es el registro de Nova.** Steam apunta cada
> arranque y cada cierre en `logs\gameprocess_log.txt`, y eso sobrevive a sus muertes. Las 13
> sesiones suman 22.081 s = 6,13 h, que cuadra al decimal con las 6,1 h de la API. Cruzadas con
> los tramos en que Nova tenía pulso:
>
> | | segundos | |
> |---|---|---|
> | Nova **muerta** | 19.501 (5,42 h) | **89,8 %** |
> | viva, pero el código no existía aún | 1.041 | 4,8 % |
> | **viva y ciega** | 1.185 | **5,5 %** |
>
> Y los 19.501 no son suposición: **el 100 % cae dentro de huecos que terminan con una línea
> `VoiceAssistant iniciado`**. Uno de ellos lo pediste tú (*"SALIDA pedida por marca"*, 18/09
> 22:20:12).
>
> **El 90 % no se arregla con código, y no se finge que sí.** El 5,5 % sí, y está demostrado con
> tus palabras: el 20/09 ELDEN RING corrió de 18:59:53 a 19:07:57, Nova lo vio **once
> segundos**, a las 19:01:22 contestó *"ELDEN RING no está abierto"* y a las 19:02:27 le dijiste
> al micrófono *"Elden Ring sí está abierto… el juego sigue abierto"*.
>
> La causa: buscaba un proceso cuyo `MainWindowHandle` fuera **exactamente** la ventana de
> delante, y en pantalla completa exclusiva eso no casa. **La solución ya estaba escrita treinta
> líneas más abajo**, en un comentario del 23/09, con su medición: de 500-740 ms a 20 ms.

### 9. Y una candidata concreta: `Add-TiempoJuego` tira el tramo entero

Rechaza cualquier incremento de **más de 120 segundos**, y el bloque que la llama mira cada 10 s.
Si el bucle se retrasa doce vueltas —o si la consola se suspende—, ese tramo **no se apunta, ni
se apunta que no se apuntó**. Es candidata a explicar parte del hueco de la idea 8, pero
**no está comprobado**, y comprobarlo es el trabajo.

> **DESCARTADA con datos.** En quince días hay **dos** huecos de más de 120 s con un juego
> delante, 878 s en total, y **los dos son de It Takes Two**. De ELDEN RING, ninguno. El tope no
> tiró ni un segundo suyo.

### 10. El historial de música guarda los anuncios de YouTube como si fueran canciones

**5 de las 12** entradas de `memoria\musica.json` (**41,7 %**) son anuncios: Base44, Tripo AI,
Firebase Brand Video, Copilot in Outlook, Introducing Grok Bot.

El patrón está en el registro: 15/09 15:00:32 `YOUTUBE:` → 15:00:39 *"Copilot in Outlook"* (7
segundos: el anuncio) → 15:00:49 la canción de Pitbull de verdad.

*Desde el 14/09.* · *Te cuesta:* que *"¿cómo se llamaba esa canción?"* te conteste un anuncio, y
que *"esa no me gusta"* vete el anuncio en vez de la canción. · *Se arregla* esperando 20-25 s o
descartando el título si cambia en menos de 15.

> **HECHA, y es la que mejor sale: el listón se elige solo.** Los cinco anuncios duraron 5 o 10
> segundos; la canción más corta que sobrevivió, **55**. Entre 10 y 55 no hay nada, así que
> cualquier número de ese hueco los separa sin un falso positivo. Se puso 20. Banco 2n135, 8
> roturas y 8 rojas.

### 11. El cerebro de la charla: 111 recuerdos, y ha servido una vez

`memoria\cerebro\cerebro.json` tiene **111 recuerdos**; `usos > 0` en **uno**, y la suma total de
usos es **1**. `vectores.json` son 110 vectores de 2.048 dimensiones, 226 KB. En el registro hay
**486** `charla dice:` y **una sola** línea `memoria: lo sé`.

Y para puntuar eso se carga `embeddinggemma:300m-qat-q8_0`, que es justo lo que la regla 5
prohíbe: algo residente comiendo RAM que le hace falta al juego.

*Desde el 13/09.* · *Las dos salidas:* apagar el modelo de significado y buscar por palabras, o
guardar solo lo que tú pidas recordar. · *Se pierde:* el "no repitas lo que ya me dijiste".


> **MEDIDA: mi métrica era la equivocada.** Reproducidas **las 328 preguntas reales** contra su
> propio cerebro: **una** pasa el listón, y es exactamente el único *"memoria: lo sé"* de quince
> días. El listón no falló ni una vez.
>
> Y bajarlo no arregla nada: embebidas 25 frases tuyas, el parecido máximo contra las respuestas
> firmes es **0,350** frente a un listón de 0,90. No es que el listón esté alto: es que en todo
> el pozo hay **dos** respuestas firmes. Bajarlo a 0,35 haría que contestara *"Escribir es
> plasmar palabras…"* a cualquier cosa.
>
> Tampoco rompe la regla 5: el modelo se llama con `keep_alive=0` y **no queda residente**.
>
> Lo que sí sobraba, y era gratis: la rama de significado medía contra esos dos vectores, **no
> podía disparar nunca**, y era el único sitio donde el modelo se carga en un turno de charla
> (2,87 s, siempre en frío). Fuera.

---

## D. Te oye peor de lo que podría

### 12. El recorte hace fallar 1,64 veces más, y no cambia nada

| | falla |
|---|---|
| dictados **con** un recorte en los 20 s previos (83) | **42,2 %** |
| dictados sin recorte (803) | 25,7 % |

z≈3,3, p<0,001. No es casualidad y no es leve. Hoy el recorte solo **baja la ganancia**; podría
además marcar la toma como dudosa y **pedirte que lo repitas**, porque **32 de esos 35 fallos**
acabaron escalando a un agente con manos.

*Lo que se rompería:* unas 83 veces en quince días oirías "repítemelo".

> **HECHA.** Los 83 dictados con recorte fallan el **42,2 %** frente al 25,7 % (z≈3,3,
> p<0,001), y **32 de esos 35 fallos** acababan escalando a un agente con manos. Ahora, cuando
> además no se entiende, se pide repetir y se ofrece el botón.
>
> **Y solo en ese camino:** mirando el recorte antes de intentar entender serían 83
> interrupciones en vez de 35, y la mayoría sin motivo. Con esto son **dos al día**.

### 13. El repaso pide permiso a la parte equivocada

El filtro que evita pedir el repaso exige **dos** cosas: más de 8 palabras **y** que sea "español
largo". En su ventana real funciona (14 repasos pedidos, 5 tirados, 4 ahorrados), pero de los
tirados estos días, **3 de 5 tenían más de 8 palabras** y no los cazó.

El dato que decide si la segunda condición sobra ya está tomado: de **149** frases de más de 8
palabras, **una sola** no era español largo.

> **FALSA, y por la misma trampa pero más fina.** Los cinco repasos tirados "desde el 22/09" son
> de **la 01:10 a la 01:15** de ese día… y el filtro se commiteó **a las 16:47:14**. Quince
> horas después.
>
> Desde que existe de verdad: **4 repasos pedidos, 4 ahorrados, cero tirados.** No ha tenido ni
> una oportunidad de fallar.
>
> *La lección afina la de la mañana:* la ventana se mide por la **hora** del commit, no por el
> día.

### 14. Cada arranque paga 4,2 segundos de cargar Whisper, y arranca doce veces al día

217 cargas medidas: mediana **4,2 s**, p90 7,8 s, **máximo 117,9 s**, suma **1.427 s**. Más 50
cargas de Parakeet (mediana 4,7 s, suma 324 s). **Casi media hora** de los quince días, solo
cargando modelos.

*Lo delicado:* la salida obvia —dejarlos cargados— choca de frente con la regla 5. Lo que sí se
puede mirar es por qué una carga tarda **117 segundos** cuando la mediana son 4.

> **HECHA, junto con la 15.** Whisper se cargaba **en serie y bloqueando**, antes de abrir el
> micrófono, y Vosk —que es quien oye "nova"— ya estaba cargado veinte líneas antes. Ahora carga
> en un hilo demonio, el mismo patrón que ya usaba Parakeet. Nada residente de más: el mismo
> modelo, la misma RAM, y el proceso ya corre en prioridad baja.
>
> Y **el dictado espera en vez de degradar**: con la carga en un hilo, `None` pasa a significar
> a veces "todavía no", y caer a Vosk en silencio sería perder comprensión justo en la meta del
> 100 %. El plazo tampoco es un número nuevo: la carga más lenta de las 217 fueron 117,9 s.

### 15. De "arrancada" a "te oye de verdad" hay 7 segundos… o cuatro minutos

211 arranques: mediana **7 s**, p90 11 s, pero **p99 142 s y máximo 242 s**. Ocho arranques (el
4 %) pasan de 30 segundos.

El aviso de "estoy sorda" que se puso hoy cubre los que pasan de 90 s, así que ya no te quedas
sin saberlo. Lo que sigue sin mirar es **por qué** uno tarda cuatro minutos.

> **MEDIDA: son mis reinicios, y te costaron un dictado.** Los ocho lentos, uno a uno: **seis**
> son un reinicio de desarrollo cayendo encima de un worker que aún cargaba, con dos copias de
> Whisper compitiendo. **Cinco de los ocho son del 16/09 entre las 20:13 y las 21:48**, los
> minutos exactos de cinco commits de esa sesión. Los otros dos son falsos.
>
> Lo que te costó: **un dictado**, el 16/09 a las 21:43:56. En los ocho huecos hay **cero
> pulsaciones de botón**, y eso sí es prueba —el botón lo registra el asistente, que está vivo
> mientras el worker carga—.
>
> Las dos defensas ya estaban puestas (17/09 y 19/09) y **desde el 19/09 ninguna carga pasa de
> 24,4 s**.

### 16. El seguimiento abre el micrófono y una de cada cinco veces no pasa nada

669 seguimientos abiertos; **213 acaban en algo útil y 281 en silencio**.

*Pero mira la evolución, que es lo interesante:* del 11 al 14/09 acababan en silencio el
**70-95 %** de las veces; desde el 15/09 están en el **15-35 %**. O sea que **ya se arregló casi
del todo**, y lo que queda es la cola. Lo pongo por eso: para que conste que se miró y que el
número gordo era viejo.


> **YA ESTABA ARREGLADO, y por eso lo puse: para que constara.** Del 11 al 14/09 acababan en
> silencio el **70-95 %**; desde el 15/09 están en el **15-35 %**. El número gordo era viejo.

---

## E. Peso muerto

### 17. El turbo lleva nueve días muerto y sigue entero en el código

Las 29 peticiones son **todas del 15/09**; el commit 446acb1 lo apagó ese día. Siguen en pie
`Request-UltimoRecurso`, `$WhisperUltimo`, `$ReintentoUltimoMs` y toda la rama `$esUltimo` del
bucle.

Cuando estaba vivo costaba **25 s de mediana y 61 s el peor**, más 17 cargas del modelo grande
de las que **15 se soltaron sin usarse**, con la VRAM a 4 GB.

> **MEDIDA, y la respuesta es NO borrar.** Está apagado por **config**, no por código, así que
> puedes volver a encenderlo hablando; borrarlo te quitaría esa opción y rompería las 14
> comprobaciones que se le pusieron hoy. Y no era "1 de 29": de los 27 `turbo-nada` **solo uno**
> murió de verdad, y en **catorce** impuso su transcripción porque era mejor (*"Coladojara y
> abre Steam"* → *"Calculadora, y abre Steam"*). **15 de 29, el 52 %.** Es caro, no inútil.
>
> Lo que sí se ha hecho: **dejar la cuenta escrita al lado del interruptor**, para que quien lo
> encienda vea antes lo que cuesta.

### 18. La nube: 0 aciertos en 126 intentos, y el interruptor sigue ahí

`nube-intento` 201, `nube-sirvio` **2** (1,0 %), `nube-nada` 90, `nube-tarde` 35. **Desde el
20/09: 0 de 126.** Ya está apagada, pero el interruptor sigue en `config.json` y cualquiera lo
puede volver a encender sin ver esta cifra. Como poco, la cifra debería estar escrita al lado.

> **MEDIDA, misma respuesta.** 0 aciertos en 126 intentos desde el 20/09, ya apagada, y la cifra
> queda ahora **al lado del interruptor**.

### 19. 548 MB de modelos que ya no están en la cascada

`modelos\` pesa 1,3 GB con 11 GB libres en C:. `omnilingual` (350 MB) aparece **3 veces** en todo
el registro y **salió de la cascada el 22/09**. `canary` (198 MB) se usó esas mismas 3 veces,
tardó **8,8 s** en cargar y esa carga tiró **14,5 s** de audio. Aparte, `modelos\stockfish\`
trae 1,6 MB de código fuente y wiki junto al ejecutable.

*El 22/09 el disco llegó a 0,81 GB libres.*

> **FALSA en la premisa.** No son 548 MB sin usar: **canary (197,9 MB) se usa hoy** —está en
> `config.json` como primer escalón del repaso—. El único que sobra es omnilingual (349,7 MB), y
> borrarlo libera **0,34 GB de los 10,7 libres** mientras rompe tres herramientas de `tools\`.
> No compensa. Y el mínimo de disco registrado son **6,8 GB el 23/09**, no los 0,81 que yo dije:
> **no demostrado**.

### 20. El plazo de la voz ya se mide; en unos días se podrá bajar de verdad

Desde hoy se guardan los milisegundos por letra de **todas** las frases, no solo las de charla
—que era la mitad ciega—. Con 20 muestras, el plazo saldrá del p99 real.

Hoy el dato solo puede **bajar** el plazo, nunca subirlo, porque sintetizar tiene una parte fija
y otra que crece con el texto y dividir por las letras sobreestima las frases largas. **Cuando
haya medidas para separar las dos partes**, podrá subirlo donde haga falta. Esa es la tarea: no
tocar nada todavía, y dentro de unos días mirar el fichero.

> **HECHA esta mañana.** Ya se miden todas las frases; el plazo saldrá del p99 real en cuanto
> haya 20 muestras. Esto no es una tarea: es esperar unos días y mirar el fichero.

---

## Lo que miré y estaba bien

Va aquí para que conste que se descartó, no que se olvidó:

- **El rebote charla↔traducir** — 55 rebotes, 44 de ellos el 18/09; la guarda es del 19/09 y hay
  **0 desde entonces**.
- **El resumen al volver** — 1.126 líneas idénticas el 21/09; arreglado el 22/09, **0 después**.
- **`bateria-llena`** — 4 al día por estado, arreglado el 22/09: **0 el 23/09 y 1 el 24/09**.
- **La cápsula** — 16 muertes, **15 antes del 13/09** y una el 21/09; vuelve en 0-3 s.
- **La latencia de la charla** — 227 medidas, mediana **1,0 s**; el p90 feo de 10,5 s es todo del
  13-15/09.
- **El aviso de la hora de dormir** — mentía a las 23:00; hoy ya dice *"sueles parar sobre las
  0:28"*.
- **Las descargas de Steam** — 18 terminadas, y las 3 del 24/09 cuadran con el disco (11,4 → 10,8 GB).
- **El ajedrez** — 0 líneas en el registro, pero el código es del 23/09: demasiado nuevo para
  llamarlo muerto.
- **El clima** — hora a hora, sin un fallo en catorce días.

---

*Escrito el 24/09/2026 por la tarde, después de cerrar las veinte de la mañana. Cada número se
puede volver a sacar: el registro es el de siempre y los ficheros de `memoria\` están en disco.*
