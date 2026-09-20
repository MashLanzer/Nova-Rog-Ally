# JARVIS, lo que se puede copiar y lo que no

*20/09/2026. Cuatro investigaciones cruzadas: las películas pieza por pieza, lo que Nova ya tiene
medido, el estado del arte de 2026, y el ángulo crítico. Todas las cifras de Nova que aparecen aquí
salen de `memoria\estadisticas.json` (9 días con registro: 11, 12, 13, 15, 16, 17, 18, 19 y 20/09),
`memoria\cerebro\cerebro.json`, `memoria\habitos.json`, `memoria\recetas.json`, `reglas.json`,
`assistant.log` (31.802 líneas) y `config.json`. Se comprobaron leyendo los ficheros, no de memoria.
No se ha modificado nada.*

---

## 1. DE QUÉ VA ESTO

JARVIS no es una lista de funciones: es una **forma de comportarse**. Quitando el cine, lo que hace
que JARVIS parezca JARVIS son cinco cosas, y las cinco son baratas:

1. **Responde al instante**, aunque el trabajo tarde. Contesta primero, trabaja después.
2. **Vuelve él solo** cuando termina algo.
3. **Tiene una voz fija y seca**, con opinión, que cabe en una línea.
4. **Dice lo que no sabe**, y da el número de su confianza.
5. **Nunca hay que activarlo**: no hay modos, está o no está.

La quinta Nova ya la cumple, y es justo la manía de braya (nada de modos que se quedan puestos): en
eso Nova ya es más JARVIS que la mayoría de los proyectos que se llaman así. Las otras cuatro son el
trabajo.

**Lo que este documento NO es.** No es una lista de funciones nuevas. La regla del 14/09 sigue en
pie —pulir antes que añadir— y la meta sigue siendo que Nova entienda al 100 % con cero órdenes
equivocadas. De las 20 ideas que hay aquí abajo, **13 son cables que faltan entre piezas que ya
existen**. Y hay una sección entera (la 4) dedicada a lo que hay que dejar fuera por escrito, con la
fecha del incidente al lado, para que nadie lo reabra dentro de tres semanas.

### El filtro de admisión (seis preguntas)

Ninguna idea entra en este documento si no contesta las seis. Están aquí arriba para que el resto se
lea con ellas puestas:

1. **¿Qué dato de Nova la justifica?** Número del log, de estadísticas o de un banco. No una intuición.
2. **¿Cuál es su freno?** Historial mínimo, `Test-DatosRepartidos` (≥3 días distintos, ninguno por
   encima del 70 %), una decisión al día, nunca jugando ni con invitado, nunca de noche si no es crítica.
3. **¿Cuánto cuesta en ms y en RAM, y qué hace cuando hay un juego delante?**
4. **¿Se deshace hablando?** Si no, ¿por qué no lleva sí hablado?
5. **¿Escucha o guarda más de lo que Nova ya escucha o guarda?** Si sí, va detrás del juez del nombre
   en «sí» y de la purga con fecha.
6. **¿Acerca al 100 % del oído, o solo suena bien?**

### Nota de cifras, porque circulan tres y no dicen lo mismo

| cifra | qué mide | de dónde sale |
|---|---|---|
| **82 %** (74 de 90) | órdenes entendidas hablando, en el **banco** | `QUE-SABE-HACER.md` (18/09) |
| **15,5 %** (42 de 271) | fracción de **todo lo dictado en uso real** que acaba en una acción | `OIDO-2026-09-19.md` |
| 21,4 % (58 de 271) | el techo con Gemini sobre el mismo corpus → **margen real del oído: 8,5 %** | `OIDO-2026-09-19.md` |

El 15,5 % **no** es «Nova falla el 84 %»: ese denominador incluye charla y traducciones. Y hay una
cuarta cifra dando vueltas, «70,4 % (50 de 71)», que **no aparece en `OIDO-2026-09-19.md`**: no la uséis.
Encima, **188 de las 311 grabaciones del corpus son del 15-16/09**, anteriores a los arreglos del 18.
Cualquier número de «acierto actual» describe una Nova que ya no existe hasta que alguien pase los
**313 WAV** de `pruebas\audio\uso` por el pipeline de hoy.

---

## 2. LO QUE NOVA YA TIENE DE JARVIS

Más de lo que parece: de las 13 capacidades de JARVIS que son software real, Nova tiene **11
construidas**. Lo que falla casi nunca es el código; es que los mecanismos están **funcionando en
vacío**.

| pieza JARVIS | qué tiene Nova | **veces que ha actuado de verdad** | veredicto |
|---|---|---:|---|
| **Conversar con memoria** | charla con API + qwen2.5:3b de respaldo, cerebro con embeddings, perfil, diario | **184 turnos de charla**; **54 recuerdos, 53 a 0 usos** | máquina lista, sin material |
| **Hablar por su cuenta** | `Watch-Entorno` cada 30 s, con frenos (4/h, calla jugando, calla de noche) | **17 avisos** (`aviso-entorno`) en 12 días = 1,4/día; **7 son «batería llena»** | es un avisador de batería, no una iniciativa |
| **Saber si estás jugando** | perfil juego, brillo, silencio, solo botón, suelta los 3 modelos de ML | real y medido a diario (Wukong 98 min el 19/09) | **lo más cerca de todo** |
| **Leer la pantalla (OCR)** | `Invoke-OCR` + captura | **7 veces en 12 días, las 7 porque se lo pidieron** | nunca ha mirado por su cuenta |
| **Recetas aprendidas** | 6 recetas con variantes, aprende formas nuevas de decirse | **1 de 6 usada** (2 usos). Las otras **5 a 0** | nada las vuelve a llamar |
| **Detectar costumbres** | `Find-Propuesta` (misma orden, misma hora, 3 días distintos) | **0 propuestas en toda la historia** (`ultimaPropuesta` vacío) | el freno está bien puesto; faltan días |
| **Reglas «cuando X, haz Y»** | motor por hora, app, batería, descarga, cascos | **`reglas.json` = `[]`**. Ni una disparada | y el 19/09 braya dictó una que no está |
| **Decisiones propias** | `Test-RevisionPropia`: apaga lo que no sirve, con su número, y se deshace hablando | **0 `auto-ajuste`, 0 `auto-deshecho`**. Un solo «tengo una decisión esperando» (18/09) | el mejor mecanismo del proyecto, a estreno |
| **Comprobar que salió bien** | `Test-EfectoAccion`, `Test-AperturasPendientes` | **0 `no-surtio-efecto`** | ojo: es un **cero circular**, antes nadie miraba |
| **Parte de la mañana** | clima + batería + recordatorios | **3 veces**: 14, 15 y 16/09. Ninguna desde entonces | y quema el día antes de saber si tiene datos |
| **«Mientras no estabas…»** | resumen de lo acumulado | **123 líneas en el log el 19/09, dichas en voz: 0** | roto en la práctica, y ensucia el log |
| **Diario y parte semanal** | diario por días (modelo local, nunca API) + parte semanal | **8 días de diario** (3 vacíos), **1 parte semanal** (W37) | empezó bien y dejó de escribirse |
| **Solo te obedece a ti** | tono de voz (116 Hz), invitado, `soloYo` | **2 `voz-extrana`** frente a **87 eventos de ruido** | hoy «no extraña» suele significar «no lo sé» |
| **Deshacer hablando** | `Undo-DecisionPropia`, guardado por duplicado a propósito | existe y está probado en banco | **esto ya es JARVIS** |
| **Personalidad** | la cápsula: gestos, humor de minutos, ojos, tono, ritmo | en uso | la cara ya tiene carácter; la voz no |
| **Entender lo que le dices** | cascada Vosk → Parakeet → Whisper base → small → turbo → Gemini, 108 correcciones | 82 % en banco · 15,5 % en uso real · nube: **sirvió 2 de 81 intentos** | **el cuello de botella de todo lo demás** |

**Las tres en las que Nova ya está sorprendentemente cerca:** el criterio para **no** actuar y decirlo
con su número; la consciencia de la situación (suelta modelos, baja brillo, calla, y te lo devuelve al
salir, sin preguntar); y rendir cuentas dejándose deshacer hablando.

**Las tres en las que está más lejos de lo que parece:** la iniciativa (17 avisos, 7 de batería); el
aprendizaje (0 propuestas, 0 reglas, 5 de 6 recetas a 0 usos, 53 de 54 recuerdos a 0 usos); y la
comprensión, que manda sobre todo lo demás.

---

## 3. LO QUE SE PUEDE COPIAR

### AHORA — existe la pieza, le falta un cable

**JARVIS-1 · Decir la confianza y preguntar cuando duda.**
*Qué gana:* Nova ya sabe por qué escalón ha tenido que pasar (`fino` 110 veces, `turbo` 29,
`nube-intento` 81). Hoy se lo calla. Decir «creo que has dicho *abre Steam*, ¿voy?» convierte un
fallo en una pregunta, y **una duda dicha en voz alta no cuenta como orden equivocada**. Es la única
idea del documento que mueve directamente la meta del 14/09.
*Qué cuesta:* cero cómputo; el dato ya está calculado. Una frase.
*Riesgo y freno:* preguntar de más es lento, y braya prioriza la velocidad. Solo cuando se llegó a
`small`/nube **y** la cobertura local no casó; una sola pregunta; los 6 s que ya existen
(`confirmacion.esperaMs`); si vence, se descarta sin ejecutar.

**JARVIS-2 · Tareas en segundo plano con aviso al terminar.**
*Qué gana:* velocidad percibida sin tocar el oído. El CLI del agente tarda **7,00 s** (once veces la
API) y una tarea real 25-60 s; el 15/09, 20 llamadas al agente fueron **11,6 min = 23 % de toda la
espera de braya**. Con esto, «busca X y me lo cuentas» deja de bloquear.
*Qué cuesta:* es el único bloque sin un modelo de por medio. Identificador + estado
(`ejecutando`/`terminado`/`fallido`) + bandeja de entrada en una carpeta que alguien vigila. El patrón
ya está montado tres veces en casa: `charla_worker.py`, `tts_worker.py`, `wake_worker.exe`.
*Riesgo y freno:* **el aviso de «ya está» es una interrupción**. Terminar un trabajo no es una
emergencia: pasa por `Test-PuedoAvisar`, consume del mismo contador de 4/hora y nace en nivel bajo.

**JARVIS-3 · Cola de avisos con entrega «en el próximo hueco».**
*Qué gana:* hoy lo no urgente que cae jugando **se pierde**. Avisar en un borde natural en vez de al
azar da **46 % menos carga cognitiva** en laboratorio y **33 % menos** en campo (Attelia, 30 personas,
16 días), sin sensores dedicados. Y Nova ya sabe ver los bordes: juego cerrado, pantalla de carga,
menú de pausa, logro, partida terminada.
*Qué cuesta:* lógica pura, cero modelos. Dos valores por aviso: urgencia y caducidad.
*Riesgo y freno:* soltar seis avisos de golpe al cerrar el juego sería peor que perderlos. Se juntan
en una frase (`$AvisoJuntarMs`, 4 s, ya existe) y **lo que caducó se tira, no se dice**.

**JARVIS-4 · Personalidad fija y seca, con la regla «objeta una vez, con el dato, y luego obedece».**
*Qué gana:* es el 90 % de lo que la gente recuerda de JARVIS y cuesta **cero milisegundos de cómputo**.
*Qué cuesta:* líneas de texto.
*Riesgo y freno:* aquí el riesgo es real y está medido. Cada sílaba de más se paga en la voz en línea
(`es-MX-DaliaNeural`), y **más texto hablado es más superficie de eco**: `PROMPT_ORDENES` se pasa como
`initial_prompt` a Whisper, y de ahí salen los recitados (`Test-CatalogoRecitado`, `Test-RecitaEjemplo`,
16 `recitado` registrados). Reparto obligatorio: **la gracia va a la cápsula, la voz se queda en una
frase**, con tope de palabras verificable en el banco. Y llevar la contraria **solo con número**
(«eso lo apagué: sirvió 1 de 29 y costaba 16,2 s»), nunca por estilo.

**JARVIS-5 · Pronombres contra lo último hecho y lo último leído.**
*Qué gana:* «ábrelo», «ese», «el anterior», «ponlo ahí». Es lo que más suena a conversación de verdad
y lo más barato de la lista. La mitad está hecha: el hilo corto entre órdenes entró hoy (M2/M3,
commit `88258c7`) y **está sin probar hablando**.
*Qué cuesta:* enlazar ese hilo con lo último que devolvió el OCR.
*Riesgo y freno:* resolver mal un pronombre **es** una orden equivocada. Solo contra lo de los últimos
60 s, y nunca para nada que pase por el filtro destructivo: las dos puertas siguen cerradas.

**JARVIS-6 · Fechar los recuerdos y que uno pueda sustituir a otro.**
*Qué gana:* es el problema sin resolver número uno del sector (las memorias que solo suman devuelven
el dato viejo junto al nuevo) y aquí ya mordió: el 18/09 braya dijo «cuando te digo que pongas una
canción SIEMPRE en YouTube», Nova contestó «Entendido», el filtro del perfil lo tiró como queja y a
los 20 segundos abrió Spotify.
*Qué cuesta:* dos campos en un JSON: fecha/origen y «esto sustituye a aquello». Más la marca
prueba/real (D4), porque el diario del 14/09 tiene recuerdos del banco dentro de la memoria real.
*Riesgo:* ninguno mayor. Es el arreglo más barato con más efecto de toda la memoria.

**JARVIS-7 · Decir la verdad al arrancar en vez de «Listo».**
*Qué gana:* hoy Nova saluda «Listo» y está **sorda hasta dos minutos** mientras carga (D3). Es el fallo
que más confunde a braya. «No tengo registro de eso» y «no puedo acceder al mainframe» son JARVIS puro:
**un asistente que miente sobre estar listo es peor que uno lento**.
*Qué cuesta:* un canal worker→asistente. La cápsula ya tiene los estados.
*Riesgo:* ninguno.

**JARVIS-8 · Trocear la voz por frases.**
*Qué gana:* **200-500 ms** menos hasta la primera sílaba soltando la primera frase en cuanto hay un
punto, en vez de esperar al párrafo; 80-200 ms más precargando el primer trozo de audio. Un sistema
que empieza a sonar antes **se siente el doble de rápido** aunque tarde lo mismo. Es exactamente la
prioridad número uno de braya.
*Qué cuesta:* tubería, no modelo.
*Riesgo:* cortar una frase a la mitad si el troceo es tonto; se trocea por puntuación, no por longitud.

**JARVIS-9 · AEC (cancelación de eco) para poder cortarla mientras habla.**
*Qué gana:* «nova» para interrumpir ya existe (`wake_vosk.py:1165`, commit `5703a10`) y **nunca se ha
probado hablando** (A2). Sin que el micro se reste a sí misma, en una consola con altavoces eso
funciona a medias. SpeexDSP o WebRTC AEC3: librería en C, coste de CPU despreciable.
*Riesgo y freno:* **va detrás del juez del nombre**. Más micro abierto mientras ella habla es más
superficie de activación falsa, y de eso va la sección 4.

### CUANDO HAYA DATOS — necesita uso real antes

**JARVIS-10 · Ofrecer la receta que ya existe** («esto ya lo hicimos, ¿lo hago igual?»). Hoy 5 de 6
recetas están a 0 usos porque nada las vuelve a llamar. Necesita repeticiones reales para no ofrecer
ruido.

**JARVIS-11 · Precargar por hábito, no proponer.** Si a las 23:30 siempre abres lo mismo, tener el
modelo cargado a las 23:25 es velocidad pura sin decir una palabra. **Precalentar, nunca ejecutar**:
el estado del arte en predecir la siguiente acción (LongNAP, 1,9M de capturas, 1.837 h) es **17,1 % de
acierto a la primera**. Necesita que `habitos.json` llegue a 3 días distintos: hoy hay 28 órdenes
apuntadas repartidas en solo 4 días, y 0 propuestas.

**JARVIS-12 · Una sola variable de situación** que gobierne canal, tono y volumen, en vez de reglas
sueltas. **Bloqueada por un fallo conocido:** `Exit-Juego` salta al perder el primer plano, no al morir
el proceso (el 19/09 «salió» de Elden Ring a los 11 segundos por alt-tabear). Mientras eso siga así,
nada que dependa de «acabó de jugar» es fiable.

**JARVIS-13 · Consolidar la memoria de noche** con qwen2.5:3b, que ya está instalado: juntar lo
fragmentado, quitar duplicados, archivar lo viejo, mientras nadie pregunta. **Y nada más**: con 54
recuerdos, montar un sistema de memoria de los grandes empeoraría algo medido (por debajo de ~150
conversaciones, llevar el contexto entero saca 70-82 % y los sistemas de memoria 30-45 %).

**JARVIS-14 · Que mire la pantalla por su cuenta**, en momentos concretos y no siempre. Hoy: 7 OCR,
los 7 a petición. Necesita antes poder leer **una zona** (C15) y llegar cronometrada.

**JARVIS-15 · Iniciativa que se mide y se apaga sola:** dos contadores por iniciativa (atendida /
ignorada) en `Add-Estadistica`, y entrada en `Test-RevisionPropia` con el mismo criterio que ya mató al
último recurso. Hereda `auto.datosDesde = 2026-09-20`, así que por diseño no puede decidir nada antes
del 23/09.

### SI ALGÚN DÍA — posible, pero caro o lejano

**JARVIS-16 · Planificador con presupuesto** que **impida** que dos modelos pesados coincidan. No es
adorno: cargar qwen pasa de **1,57 s a 23,77 s** con Wukong delante. Es la versión defensiva de «hacer
varias cosas a la vez». Caro porque toca el bucle.

**JARVIS-17 · Supertonic 3 como voz local de respaldo** (99M, ONNX, español, 0,3x de RTF en un lector
de libros electrónicos): un Piper que suena mejor y pesa lo mismo. Solo arregla **la voz de cuando no
hay internet**, que hoy es la robótica. *Antes de tocar nada: medir cuánta RAM come Piper en la Ally.*
El banco de Picovoice le mide **2,6 GB de pico** en un Ryzen de sobremesa, y aquí nadie lo ha medido.

**JARVIS-18 · Micro-turnos por trozos**: el truco que hace funcionar a los modelos full-duplex, sin el
modelo full-duplex (los que existen son de 9B y no caben ni de lejos). Es arquitectura de tubería,
pero toca lo más delicado que hay.

**JARVIS-19 · Nova en más sitios** (el móvil, otro cacharro). El propio proyecto ya lo tiene marcado
(D5) como **«la más cara y la que menos acerca al 100 %»**. Aquí hay una consola.

**JARVIS-20 · Cerrar el círculo de la verificación**: hoy `Test-EfectoAccion` mira volumen y brillo,
pero el «cerrados N de M» no llega a la voz y no se comprueban los archivos creados. Es continuación
natural de JARVIS-7, pero sin uso real no hay ni un fallo que cazar (0 `no-surtio-efecto`, y es un cero
circular).

---

## 4. LO QUE NO HAY QUE COPIAR

Esta sección es obligatoria y va con fecha, para que no se reabra dentro de tres semanas.

**NO-1 · La escucha ambiental. «Que se entere de lo que pasa en la habitación».**
Esto no es un riesgo teórico: **pasó esta madrugada**. Entre las 00:12 y las 00:22 del 20/09 hubo
**cinco activaciones por nombre sin que braya dijera «nova» ni una vez**, que se convirtieron en
**14 grabaciones y 70 segundos de una conversación privada**. La gramática de Vosk es cerrada, así que
ante cualquier ruido el decodificador **está obligado** a devolver algo de la lista, y la confianza no
filtra porque viene inflada por construcción (dos de las cinco fueron «nova nova» y «por oye nova»).
Lo que sí las delataba era el nivel de la ráfaga en crudo: mediana **0,021** frente a **0,405** de las
87 activaciones históricas, veinte veces menos (de ahí `escucha.rafagaMinima = 0.03`).
El multiplicador no fue el oído, fue el **seguimiento**: 5 activaciones dieron 14 grabaciones porque
tras contestar el micro se reabre y ahí no hace falta decir el nombre. Y borrar el rastro fue un
trabajo de **nueve frentes**: 14 WAV, 25 líneas de `registro.jsonl`, 12 de `destinos.jsonl`, 410 de
`assistant.log`, una línea aprendida del perfil, 4 recuerdos con sus vectores, la charla del día y 5
WAV de `tmp` — **cuatro de ellos ya enviados a Google**.
Y el detalle que convierte esto en política: entre los recuerdos borrados había uno del **15/09** que
decía *«Braya activó a Nova sin intención mientras hablaba con su pareja»*. Ya había pasado, Nova lo
había anotado, y nadie lo leyó.
**Queda descartado por escrito:** «que escuche la conversación para tener contexto», «que se entere de
lo que pasa en la habitación», «que grabe por si acaso». Y **ninguna idea que dependa de oír más entra**
hasta que (a) el juez del nombre pase de `"mirar"` a `"sí"` con sus cifras delante, (b) el juez y
`rafagaMinima` cubran **también la ventana de seguimiento**, que es donde 5 se hicieron 14, (c) exista
purga con fecha de `pruebas\audio\uso` (hoy son **313 clips que viven para siempre**) y «borra lo de la
última media hora» como orden hablada que barra las nueve huellas de una vez, y (d) el envío a Gemini
cuelgue del juez, no del disparo de Vosk.

**NO-2 · Interrumpir constantemente, comentar lo que ve, ponerte al día al encender.**
El propio código lo dice en el comentario del motor de avisos: *«un asistente que habla solo se vuelve
insoportable rápido»*. Los frenos están calibrados contando huecos reales de 9 días: 4 avisos/hora, solo
nivel alto jugando, de **23:00 a 8:00 solo lo crítico**, nada con invitado delante, nunca mientras habla
o dicta, y el saludo de vuelta a 45 min (cápsula) y 180 min (voz) porque a 20 min salían 2,8 saludos al
día. **Y braya trabaja de noche**: un JARVIS nocturno entra por la puerta más protegida del sistema.
**Regla:** ninguna iniciativa nueva tiene canal propio. O consume del mismo contador de 4/hora vía
`Test-PuedoAvisar`, o no existe. Y nace en nivel bajo (cápsula, sin voz); asciende a voz solo con dato
de que braya la atiende.

**NO-3 · Iniciativas gordas automáticas.** Cerrar, apagar, reiniciar, bloquear, borrar, enviar,
comprar. Las **dos puertas** ya están puestas (al crear la regla y al dispararse, porque una regla
guardada antes del filtro llegaba igual con `$script:confirmado = $true`). El patrón bueno no es
preguntar más —preguntar es lento y braya prioriza la velocidad—: es **hacer y rendir cuentas**. Si se
deshace con una frase y sin pérdida, se hace y se dice. Si no se deshace, sí hablado obligatorio y
**nunca dentro de una regla que se dispara sola**.

**NO-4 · Opinar sin número.** Nova puede contradecir cuando tiene el dato, nunca por estilo. El
proyecto lleva **tres mediciones propias que salieron falsas a la primera** («470 veces» que eran 12,
«254 activaciones jugando» que eran 0, «gana 25 órdenes» que ganaba 0). Una Nova opinadora sin números
sería la cuarta. Regla de oro ya escrita: *si no puede explicar una decisión con un número, no debería
haberla tomado*.

**NO-5 · Un predictor de la siguiente acción.** El estado del arte falla el **83 % de las veces**
(Pass@1 17,1 %), con un modelo de visión de 7B y un mes entero de pantalla. Actuar con eso en mitad de
una partida es exactamente lo que braya odia. Repeticiones duras sí (misma orden, misma hora, tres días
distintos, que es lo que Nova ya hace); adivinar no.

**NO-6 · Montar un sistema de memoria de los grandes** (Letta, Zep, mem0) encima de 54 recuerdos.
Cada operación de memoria de esos sistemas es una llamada a un modelo, y por debajo de ~150
conversaciones **pierden por 35-40 puntos** contra llevar el contexto entero. Sería empeorar algo
medido y pagar RAM por ello.

**NO-7 · Modos que se quedan activos.** No hay «modo JARVIS». Ya está codificado: *«Una acción y una
frase: ni pregunta ni modo que se queda puesto»*; la sordina siempre tiene salida («si me necesitas
antes, mantén el botón»); el invitado se quita solo a los 30 min. Y la lección de las 5 autosordinas
del historial: **2 saltaron por frases buenas de braya** («Reproduce una canción», «Vamos a ver el
volumen») que los tres motores transcribieron bien — falló el catálogo, y se contabilizó como ruido de
micrófono. Cualquier modo automático nuevo tiene que distinguir **«no te oí» de «no sé hacer eso»**
antes de callarse.

**NO-8 · Sondas ambientales constantes.** Precedente medido: `Get-CimInstance Win32_Processor` tardaba
**1057-1320 ms cada 30 s, síncrono dentro del bucle**, solo para mover una insignia de carga. Nova
congelada un segundo de cada treinta por un adorno. Toda sonda nueva nace cronometrada y con
autoapagado, como ya lo tienen `cargaTopeMs` (400 ms) y `Watch-Acelerometro`.

**NO-9 · Voces y modelos que no caben.** Kokoro: **3,7 s hasta la primera sílaba y 2 GB** en un Ryzen
de sobremesa; suena mejor que Piper y da igual. Modelos full-duplex (Raon 9B, DuplexSLA): impensables
con un juego delante. Y nada nuevo puede **cargar un modelo dentro del camino de una orden**: o usa uno
ya cargado, o no entra.

---

## 5. LO QUE ES CIENCIA FICCIÓN

Para que nadie lo persiga, con el motivo técnico al lado:

- **Pilotar la armadura, volar, combatir.** No hay hardware ni control en tiempo real de esa clase.
  Tampoco hay armadura.
- **Ver por cualquier cámara del mundo, rastrear a alguien por satélite.** No existe ese acceso, y
  además sería ilegal.
- **Hackear un sistema en segundos**, descifrar claves, entrar en bases ajenas. Es magia de guion.
- **Sacar información de una imagen ilegible**, reconstruir un objeto en 3D mirándolo, identificar a
  cualquiera del planeta por la cara. Donde no hay información, no se puede recuperar: el OCR de
  pantalla **sí** es real y Nova ya lo tiene; lo demás no.
- **Diagnóstico médico por mirar a alguien**, detectar un ataque de ansiedad sin sensores. Aquí no hay
  ni cámaras ni sensores, y con ellos tampoco.
- **Distribuirse por internet, tener voluntad propia, convertirse en Vision.** Ficción pura. Pero ojo:
  **el efecto de personalidad sí es real** (JARVIS-4) y es el 90 % de lo que la gente recuerda.
- **Simular física completa y fabricar un traje en cinco horas** a partir de una frase.
- **Estar en casa, en el coche y en el traje.** Técnicamente posible (un estado, varios clientes de
  audio), pero aquí hay **una** consola: es la capacidad más citada por los «Jarvis caseros» de internet
  y la que **menos** aporta a Nova. Descartada por contexto, no por imposible.
- **Y la que más conviene decir en voz alta: entenderlo todo, siempre, sin equivocarse nunca.**
  JARVIS no tiene este problema en ninguna escena porque no paga latencia. Aquí la pila del oído cuesta
  **1,2 GB** medidos, el oído fino tarda **~4 s**, el tope de la nube está en 7 s, y el margen real que
  queda sobre el corpus de hoy es **8,5 %**, casi todo en **nombres propios** («Abre St», «Sierra Gul»,
  «Haben The Ring») y en Parakeet eligiendo inglés. El 100 % de braya es un objetivo de ingeniería con
  nombre y apellidos, no una capacidad que se copie de una película.

---

## 6. POR DÓNDE EMPEZARÍA

Antes de cualquiera de las tres: **A0** (reiniciar Nova, que lleva corriendo con el código de ayer y el
tope de nube viejo) y **el harness que pase los 313 WAV por el pipeline de hoy**. Sin eso, toda medición
describe una Nova que ya no existe, y las tres de abajo se juzgarían con cifras muertas.

**1. JARVIS-7 + JARVIS-1: que diga la verdad sobre sí misma.**
Son la misma idea en dos sitios: «todavía estoy despertando» en vez de «Listo», y «creo que has dicho X,
¿voy?» cuando ha tenido que bajar a `small`, a `turbo` o a la nube. Van primero porque son las únicas
que mueven **directamente la meta del 14/09**: una duda dicha en voz alta no cuenta como orden
equivocada, y un asistente que miente sobre estar listo es peor que uno lento. Coste: cero cómputo,
el dato ya está calculado. Riesgo: que pregunte de más; se acota con el escalón y con los 6 s que ya
existen.

**2. JARVIS-2: tareas en segundo plano con aviso al terminar.**
Porque la prioridad número uno de braya es la velocidad, y esto sube la velocidad **percibida** sin
tocar el oído ni cargar un modelo nuevo: 7,00 s del CLI y 25-60 s de una tarea del agente dejan de ser
espera muerta. Es el único bloque del documento sin un modelo de por medio —cola, identificador y una
carpeta vigilada— y el patrón ya está montado tres veces en casa.

**3. JARVIS-3: la cola con entrega en el próximo hueco.**
Va tercera porque es el cable que hace útil a la segunda: el «ya está» de un trabajo de fondo necesita
un hueco donde caer. Los avisos ya existen y los frenos están bien calibrados; lo único que falta es el
**cuándo**. 33-46 % menos carga cognitiva medido en campo, con los bordes que Nova ya sabe ver, y sin
gastar un solo aviso de más: sigue consumiendo del mismo contador de 4/hora.

**Lo que deliberadamente no está en estas tres:** JARVIS-4 (personalidad) va después de **A10**, porque
antes de añadir carácter hay que oír si la voz actual acentúa bien; y JARVIS-9 (AEC) va después del juez
del nombre, porque abrir más el micro antes de eso es repetir lo del 20/09.

---

## Ficheros y fuentes

**Del proyecto (solo lectura, nada modificado):**
`QUE-SABE-HACER.md` · `OIDO-2026-09-19.md` · `MEDICION-MODELOS-2026-09-19.md` ·
`PENDIENTES-2026-09-19.md` · `NOVA-LLM.md` · `AUTONOMIA.md` · `TRASPASO.md` · `config.json` ·
`reglas.json` (`[]`) · `memoria\estadisticas.json` · `memoria\cerebro\cerebro.json` (54 recuerdos,
53 a 0 usos) · `memoria\habitos.json` (`ultimaPropuesta` vacío) · `memoria\recetas.json` (6, una con
2 usos) · `assistant.log` (31.802 líneas) · `pruebas\audio\uso` (313 clips).
`assistant.ps1`: 3449 (modos que no se quedan puestos), 5758 (parte de la mañana), 6031-6140 (motor de
avisos y `Test-PuedoAvisar`), 6406 (`Save-DecisionPropia`), 6563 (`Test-RevisionPropia`), 6833
(`Test-ResumenAlVolver`), 7057 (`Find-Propuesta`), 11006 y 11077 (las dos puertas de lo destructivo),
11738 (`Invoke-OCR`), 14686 (`Add-RuidoRacha`).
`wake_vosk.py`: PREBUFFER, gramática cerrada, `limpiar_whisper`, `PROMPT_ORDENES`, 1165 («nova» corta).
Commits del 20/09: `e916a03` (activaciones falsas y borrado del rastro), `eceae08` (cadena de
seguimiento), `88258c7` (juez del nombre, hilo corto).

**De fuera:**
- [J.A.R.V.I.S. — MCU Wiki](https://marvelcinematicuniverse.fandom.com/wiki/J.A.R.V.I.S.) ·
  [Iron Man (2008), citas — IMDb](https://www.imdb.com/title/tt0371746/quotes/) ·
  [Age of Ultron, citas — IMDb](https://www.imdb.com/title/tt2395427/quotes/)
- [Attelia — Okoshi, Keio](https://www.ht.sfc.keio.ac.jp/~slash/research/attelia/) (46 % y 33 % menos
  carga cognitiva) · [estudio de campo sobre avisos adaptativos](https://www.sciencedirect.com/science/article/abs/pii/S1574119217304388)
- [LongNAP — Next Action Prediction](https://arxiv.org/html/2603.05923v1) (Pass@1 17,1 %)
- [ConvoMem: por qué las primeras 150 conversaciones no necesitan RAG](https://arxiv.org/html/2511.10523v1) ·
  [Sleep-time compute — Letta](https://www.letta.com/blog/sleep-time-compute/)
- [Comparativa de TTS en el aparato — Picovoice](https://picovoice.ai/blog/on-device-tts/) *(del
  fabricante de Orca)* · [Supertonic](https://github.com/supertone-inc/supertonic) ·
  [Supertonic 3](https://supertonic3.github.io/)
- [AEC en PJSIP (AEC3, Speex)](https://docs.pjsip.org/en/latest/specific-guides/audio/aec.html) ·
  [lista de modelos full-duplex](https://github.com/Ruiqi-Yan/Awesome-Full-Duplex-SDM)
- [Agentes de fondo con bandeja de entrada en archivos (ADR-0026)](https://joelclaw.com/adrs/adr-0026) ·
  [Speculative Interaction Agents](https://arxiv.org/pdf/2605.13360)
