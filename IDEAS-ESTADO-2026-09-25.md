# Estado de las ideas — 25/09/2026

Este documento dice, de las **21 ideas** y las **50 de autonomía**, cuáles están hechas, cuáles
se descartaron **y con qué dato**, y cuáles quedan.

Lo importante no son las hechas: son **las descartadas**. Cada una lleva la medición que la
tumbó. Descartar una idea con un número es tan útil como implementarla, y bastante más barato.

---

## Lo hecho hoy (25/09)

| # | Idea | Lo que la justificaba |
|---|---|---|
| 21.1 | Nova no sabe si se la está viendo | la cápsula invisible en pantalla completa exclusiva |
| 21.2 | Las bombas de relojería de los bancos | 28 expresiones frágiles; 2 mordieron esa madrugada |
| 21.4 | Lo que dura un rato no ocupa plaza | 21 de 57 datos del perfil eran estados pasajeros |
| 21.5 | Los avisos que te prometió y perdió | 4 avisos caducaron sin decirse |
| 21.6 | La resolución no vuelve sola | — |
| **21.7** | **Los dos avisos de batería que se pisaban** | **saltaban los dos a la vez, y uno tenía el 15 escrito a mano** |
| **21.15** | **El ánimo con el que se despierta** | **arrancaba en 0 justo cuando más habla por su cuenta** |
| 21.17+38 | Que note a qué estás jugando | juegos.json no decidía nada desde que existe |
| **21.18 / 50.35** | **Lo que importó no se resume** | **342 turnos de charla → 29 viñetas en 14 días** |
| 21.19 | Un banco contra los workers sin protección | 44 workers huérfanos, 1,3 GB |
| 21.20 | La lista de procesos que se ampliaba a mano | — |
| 21.21 | El perfil sin tope, y la memoria permanente | 45 de 60 datos invisibles para la charla |
| 50.3 | El diario dejó de escribirse y nadie se enteró | 3 días de silencio sin que saltara nada |
| 50.24 | Que mida si sus avisos sirven | — |
| 50.29 | Si la vez anterior acabó mal, se dice | — |
| **50.34** | **El ánimo con memoria larga** | **+0,62 → −0,50 → +0,50 en tres días** |
| **50.4** | **Los logros que nadie ve** | **5 en 16 días, y el .bin cambió el 24/09 sin que lo viera** |
| **50.47** | **Las dos frases que sí se repiten** | **33 veces en 4 días y 20 en 8** |
| 50.50 | El ánimo cambia lo que hace | habló 21 veces por su cuenta por 1 que la llamaron |
| — | **La cascada de repasos, medible** | **canary: 18 usos, CERO órdenes sacadas** |
| **50.27** | **Trabajar cuando no molesta** | **las 13 copias, las 13 entre las 17h y las 22h** |
| **50.30** | **Contar lo que hizo mientras no estabas** | **el resumen sólo contaba mensajes, nunca lo que hizo ella** |

---

## Lo descartado, y con qué dato

Esto es lo que más vale de la lista.

### 21.9 — El brillo por hora aprendido
**El dato:** la función `Get-BrilloPorHora` **ya existe desde el 13/09** y braya **nunca la ha
activado** (`habitos.brilloAuto = false`, 0 líneas en el log). Y de 13 peticiones de brillo en
16 días, sólo 6 traen un valor, todas en ventanas de segundos propias de una tanda de pruebas
(tres órdenes contradictorias en 50 segundos el 18/09). Ninguna orden de brillo desde el 18/09.
**Además el patrón va al revés:** los dos valores más altos (90 y 100) son los más tardíos.
→ Reescribir eso sería inventarse datos que no existen.

### 21.10 — La confianza mínima del oído (0,65)
**El dato:** el 0,65 **no se usa nunca**. `config.json` pone 0,55, y el listón que de verdad
decide es `confianzaLarga = 0,85`, que **ya se validó el 22/09** simulando bajarlo: colaría 47
de 62 descartes, incluidos siete despertares falsos confirmados.
→ La idea partía de un número equivocado.

### 21.12 — Borrar un candidato único sin preguntar
**El dato:** **cero usos** de la papelera en todo el registro. Braya no ha mandado nunca nada a
la papelera por voz.
→ Quitar una pregunta de seguridad en algo que nunca se ha usado es riesgo puro sin beneficio.

### 50.1 — Que las reglas se propongan solas
**El dato:** de 34 usos apuntados en `habitos.json`, **cero parejas se repiten dos veces
siquiera**. El más repetido es "abre steam" (7 veces en 4 días) y no le sigue nada de forma
consistente. Y el filtro que las recoge está bien: de 322 órdenes locales deja pasar 63, y las
255 que descarta son preguntas ("qué hora es"), no costumbres.
→ Nova no puede proponer una regla que braya no ha repetido nunca.

### 50.2 — Recordatorios que nazcan de la conversación
**El dato:** el patrón `avísame cuando la descarga de Steam termine` **ya funciona**, y se
comprobó en vivo. Las líneas del log que parecían fallos son del **21/09 a las 23:41**, y el
patrón entró el **22/09 a las 00:31** — una hora después. La trampa de la ventana temporal.

### 50.5 — La autosordina
**El dato:** está apagada **a propósito** desde el 22/09, tras revisar las cinco veces que
saltó: **las cinco las disparó la voz de braya, ninguna el ruido**, y dos eran órdenes suyas
mal oídas. → Tocarla sería deshacer trabajo bueno.

### 50.6 — El límite de tiempo de juego
**El dato:** el código actual lleva **dos días** y ha tenido **cero oportunidades**: el 24/09
se jugaron 116 minutos y el listón son 120. Los dos avisos del registro son del código viejo
(se nota en el formato de la línea). → No está roto: está sin estrenar.

### 50.36 — Recordar dónde lo dejasteis
**El dato:** sobre 2.653 frases, 6 eventos únicos parecidos, y **ninguno pide retomar nada**:
son quejas dentro de la misma sesión ("te dije ahora mismo que en YouTube").

### 50.43/44 — Opiniones y manías propias
**El dato:** las 8 entradas de "estilo" del cerebro son **preferencias de braya**, no de Nova.
No hay ni un dato que medir, porque no existe la estructura.
→ Esto no es una decisión de datos: es de gusto. **Hace falta que lo decida braya.**

### 50.9 a 50.16 — TODA la sección "decidir sin preguntar"
**El dato, y descarta las ocho de una vez:** conté **cuántas veces pregunta Nova antes de
hacer algo**. Son **32 en 16 días, y ninguna desde el 20/09** — cinco días sin una sola
pregunta. Y las 32 son de tres tipos, los tres correctos:

- **frases mal oídas** (`'abre calcladra'`, 3 veces) → preguntar es exactamente lo que debe hacer;
- **borrados** (`'vacía la lista'`, `'borra la lista de compra'`) → la regla 1 de la casa;
- **plazos vencidos** — que no son una pregunta: son que nadie contestó.

→ **No hay preguntas de más que quitar.** La sección entera parte de una premisa falsa: Nova
ya casi no pregunta. La autonomía que le falta no es *dejar de preguntar*, es **hacer cosas
útiles por su cuenta**, que es por donde ha ido el trabajo de hoy.

### 50.12 — Que un "no" dure
**El dato:** el mecanismo **funciona y está documentado**. El 13/09 a las 16:24 apuntó
`RECHAZO apuntado: 'baja el volumen'` y ocho minutos después, al pedir lo mismo, preguntó:
*"La última vez me dijiste que no era eso"*. Se ha usado **una vez en 16 días**. Y el diseño
actual —preguntar, y si dices que sí quitarlo de la lista— lleva escrita su razón: *"así se
cura sola en vez de quedarse vetada para siempre por una vez que cambiaste de idea"*.

### 50.7 — Los treinta temas que no usa para nada
**El dato:** **sí los usa.** `charla_memoria.py:431-435` mete los cinco más frecuentes en el
contexto de cada charla (*"Temas de los que suele hablar: …"*), y `:750` los usa para buscar.

### Quitar la muletilla del principio ("mira", "oye")
**El dato:** 19 de 531 frases no reconocidas (4 %), y **la mayoría son falsos positivos**: en
"mira mi pantalla" *mira* es el verbo, no una muletilla. Quitarla rompería más de lo que arregla.

### Las 36 frases de Steam sin reconocer
**El dato:** "estado es cargando en steam" x20 y "hay alguna actualización de este" x16 son
**todas del mismo día (18/09)**. Tanda de pruebas, como los 190 "llame al médico" del 11-12/09.
El uso real sobre descargas son 2 frases el 15/09, y el mecanismo ya existe.

---

## Las dos últimas, y por qué van juntas

**50.27 — trabajar cuando no molesta.** De 2.166 órdenes en 16 días, **cero** caen entre las
02 y las 08. Seis horas muertas cada día, y Nova está **despierta** en esa franja (6.027 líneas
de registro, nueve noches distintas): lo único que hace es escuchar a nadie y aparcar avisos.
Mientras tanto la copia de lo aprendido se ha hecho **13 veces y las 13 entre las 17h y las
22h**, las horas de más uso. No es mala suerte: la copia se intenta *en el primer minuto tras
arrancar*, y tú arrancas Nova cuando vas a usarla.

Y **no se mira el reloj**: esa franja es lo que haces hoy, y atarse a ella sería un número
inventado el día que cambies de horario. Se mira si estás delante. Con plazo: pasadas 30 horas
se hace igual, estorbe o no.

**50.30 — contar lo que hizo.** El resumen al volver sólo contaba **mensajes**. Ahora, cuando
vuelves: *"Mientras no estabas: 2 mensajes de Discord · Y me callé 3 cosas y guardé lo
aprendido."* Y nunca es un motivo para hablar: si no hay mensajes que contar, no saluda sola
para presumir.

Van juntas porque la segunda **no tenía nada que contar hasta que existió la primera**.

---

## Lo que queda, y necesita que decidas tú

1. **Tu apodo** (21.16 y 50.42). Nova sabe que tienes uno y no lo usa nunca. Hace falta que
   le digas cuál es.
2. **Si quieres que Nova tenga opiniones propias** (50.43/44). No hay datos que lo decidan;
   es cuestión de si te apetece o no.
3. **El segundo motor de transcripción**: quitarlo ahorra ~2 s por orden a cambio de algo de
   comprensión. Con tu meta del 100 %, no lo toco sin que lo digas.

## Lo que se decide solo, en cuanto haya datos

- **La cascada de repasos**: canary lleva 18 usos y 0 órdenes sacadas. El listón para decidir
  son 20. Nova lo quitará sola cuando llegue, lo dirá, y podrás deshacerlo.
- **El aviso de tiempo de juego**: sin estrenar, esperando un día de 2 horas.
- **El diario**: el vigilante entró anoche; hoy lleva 2 días de retraso y el tope son 4.
