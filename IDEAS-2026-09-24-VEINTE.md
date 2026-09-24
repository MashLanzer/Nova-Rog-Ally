# Veinte ideas nuevas para Nova — 24/09/2026

Todas salen de **medir cómo se comporta Nova de verdad**: 50.581 líneas de registro (15 días,
324 horas), `memoria\estadisticas.json` y las 514 frases reales de `pruebas\audio\uso`.

**Dónde reproducir los números:** al reiniciar Nova esta mañana el registro rotó, así que esas
50.581 líneas están ahora en **`assistant.log.1`**, no en `assistant.log`.

**Una advertencia que me hice a mí mismo escribiendo esto:** la primera versión de esta lista
salía de las frases que Nova descartó, y la tiré entera. De las que había apuntado, *crear una
carpeta*, *revisar mi correo*, *mira la pantalla y dime qué ves*, *pon un temporizador para 2
horas* y *pon la novena canción* **ya funcionan todas**: los descartes eran de antes de que
existieran esas funciones (crear carpetas llegó el 22/09 y los descartes son del 13 al 20).
Lo dice tu propia memoria del 23/09: *de las 357 frases que no reconoció en catorce días, 330
ya se entienden hoy*. Así que estas veinte no miran lo que no entiende, sino **lo que hace mal
entendiéndolo**.

Van ordenadas por lo que más te cuesta hoy.

---

## A. Te oye mal, y se puede medir cuánto

### 1. Llamarla por su nombre falla 6 de cada 10 veces

De las **917 veces** que dijiste su nombre, solo pasaron **392 (43 %)**:

- **83** se tiraron por sonar flojo — `descartado 'nova': suena demasiado flojo para ser una
  llamada` —, **29 en un solo día** (21/09) y **13 anoche entre las 00:14 y la 01:23**.
- **442** se ignoraron por estar jugando — `'nova' ignorado: estas jugando, aqui solo vale el
  botón` —, **166 en un solo día** (15/09). Y no es solo "nova" a secas: ahí están *"oye
  nova"*, *"ey nova"*, *"nova por favor"*, *"nova escucha"*, *"nova nova nova"*.

El umbral no es fijo: se mueve solo entre **0,017 y 0,030** según el ruido, y **21 de esos 83
descartes estaban a menos de un 20 % del umbral del momento**. Una parte se pierde por un pelo.

*Lo delicado:* subirlo a lo bruto hace que la tele la despierte. Lo que hay que mirar es si un
rechazo por volumen puede pedir una segunda opinión en vez de tirar la frase, y qué hacer con
el "nova" jugando, que hoy se descarta **en silencio** y tú no te enteras de que te oyó.

> **HECHA el 24/09, y la receta obvia era la trampa.** Los 83 descartes por flojo caen en **19
> rachas** de dos o más en 120 s. Lo que decide no son las rachas, sino qué pasó *después* de
> cada una, con quince minutos de ventana:
>
> | qué pasó tras la racha | cuántas |
> |---|---|
> | acabó ejecutando la orden que pediste | **0 de 19** |
> | se quedó en nada | 17 de 19 |
> | ejecutó algo que **no** pediste | 2 de 19 |
>
> El segundo de esos dos está con tus palabras en el registro: el 22/09 a la 01:12, tras una
> racha, por fin te oyó, abrió los ajustes **y además leyó la pantalla**, y tú dictaste *"no
> tenías que leer la pantalla, no te pedí eso"*.
>
> Y por qué no se sube la sensibilidad: de los 83 descartes, **45 pasan con los altavoces
> sonando de 0,10 a 0,38** y una línea `JUEGO:` al lado. Eso no eres tú hablando bajo, es el
> juego diciendo algo que suena a "nova". Amplificarlo sería la regla 1 al revés.
>
> Así que Nova **solo lo dice**, y solo cuando los altavoces están callados: *"te he oído
> llamarme varias veces pero llegas muy flojo; acércate un poco, o úsame con el botón"*. El
> listón de tres también está medido: con 2 saldrían 11 avisos en 3 días (3,7 al día, que es
> el fallo de los 25 avisos idénticos del 22/09); con 3 salen **5** y se quedan fuera las dos
> rachas que eran del juego; con 4 se pierde la del 21/09 a las 16:28, que era de verdad.

### 2. Interrumpirla funciona, pero se ha usado 10 veces en 15 días

`pausa: el asistente habla o dicta, se ignora el microfono` sale **1.133 veces**: son los ratos
en los que Nova está hablando. Cortarla mientras habla **sí existe** —`INTERRUMPIDA: 'X'
mientras hablaba -> me callo y te escucho`— pero solo ha saltado **10 veces en 15 días**: tres
el 14/09, tres el 22/09, y días enteros con ninguna.

O sea: 1.133 ocasiones y 10 cortes. O cuesta mucho acertar, o no sabes que se puede. Con las
respuestas largas (la guía de un juego, el resumen del día, una lista de amigos) son varios
segundos hablándole encima sin que pase nada.

*Lo que hay que medir antes de tocar:* cuántas de esas 1.133 veces le hablaste de verdad
mientras ella hablaba. Ese dato **está** en `pruebas\audio\uso`, con marca de tiempo.

> **HECHA el 24/09.** Y el fallo no era el que decía la idea. El oído escribió **15
> `corte.flag` en quince días y el asistente atendió 10**: las otras cinco no se perdieron por
> el oído —acertó las quince— sino en el bloque del bucle. **Cuatro con un dictado abierto**
> (el 20/09 hubo dos dictados colgados de 48 segundos con *"para"*, *"nova"* y *"basta"*
> dichos dentro), porque el bloque tenía **dos ramas para tres situaciones**; y una por pausa
> vencida. Un modo abierto 48 s con dos órdenes de parar dentro es un modo sin salida, que es
> la regla 2.
>
> Y ninguna de las cinco dejó **una sola línea** en el registro: el flag se borra en la tercera
> línea del bloque, antes de decidir. Por eso el agujero tardó quince días en verse.
>
> Ahora hay cinco salidas y ninguna situación se queda sin rama, cada una deja su contador, y
> **no se toca ni una palabra de corte, ni el 0,9 de confianza, ni el margen de tono**: no hay
> un dato que diga que se quedan cortos, y los 19 rechazos por tono son la guarda que evitó
> que su propia voz la callara.

### 3. El micrófono satura, y encima desconfía de sí mismo

- `recorte detectado: bajando ganancia` — **404 veces**.
- `recorte con los altavoces sonando` — **262 veces** más, y ahí la ganancia se queda quieta.
- `medidor de altavoces activo: se desconfia del microfono` — **472 veces**.

O sea: casi 700 saturaciones y 472 ratos en los que Nova decide no fiarse de lo que oye porque
suenan sus propios altavoces. Eso es justo cuando tú le hablas encima de lo que ella dice.

### 4. Lo que oye el motor rápido hay que repasarlo el 84 % de las veces

`PARAKEET: 'X' no es una orden que entienda; lo repasa <otro>` sale **338 veces**, frente a
**64** en las que lo que oyó Parakeet ya era una orden buena. O sea que **cinco de cada seis
frases pasan por un segundo motor**, con lo que eso cuesta en tiempo. Hay que medir si el
rápido está compensando el arranque que paga.

### 5. 1.116 trozos de audio tirados por llegar tarde

`descartados N s de audio atrasado`: **604** en la transcripción y **478** en el oído fino,
con **374 en un solo día** (15/09) y 208 el 20/09. Es audio que ya estaba grabado y se tira
**sin mirarlo**.

### 6. El oído fino: uno de cada tres no cambia nada

De **145 repasos**, **45 (31 %) no mejoran nada** —`OIDO FINO: el repaso no mejora 'X'; la hago
tal cual`— y **7 se inventan algo** que no se parece al audio (`fino-invento`). Frente a eso,
**37 sí sirvieron**. Merece la pena medir cuándo aporta de verdad y saltárselo cuando no.

---

## B. Te contesta tarde, o no contesta

### 7. La nube no contesta, o llega cuando ya no hace falta

De **201 intentos**: en **90 (45 %)** lo que trajo **tampoco era una orden que Nova supiera
hacer** (`NUBE: 'X' tampoco es una orden que sepa hacer; sigo con el oido local`), en **35** no
contestó a tiempo, y **12** llegaron **después** de que el oído local ya hubiera resuelto —uno
de ellos 2,1 s tarde—. Queda menos de un tercio de intentos que aportan algo.

> **HECHA el 24/09, con el listón medido a mano.** La nube se acepta solo si **la mitad de sus
> palabras de cuatro letras o más** casan con lo que se oyó de verdad. El listón sale de cuatro
> casos reales: las dos invenciones del 18/09 coincidían al **33 %** —las dos compartían solo
> el relleno *"quiero"* / *"también"*— y las correcciones buenas al **75-100 %**. Con "cualquier
> palabra vale" las dos invenciones habrían pasado.

### 8. La mitad de sus frases se fabrican en el momento

**330** frases suenan en menos de 250 ms (`voz: frase ya preparada`) y **311** tardan más
(`sintetizada al momento`). Y no es poco: de esas 311, la **mediana es 903 ms**, el **p90
1.247 ms** y la peor **3,6 segundos** callada antes de empezar a hablar.

Casi la mitad de lo que te dice paga la síntesis entera. Hay que saber qué tienen las 330 que
no tienen las otras.

> **HECHA el 24/09, pero no como decía.** La idea era quitar la espera síncrona que bloquea el
> bucle. Medida: son **303,2 s en quince días**, o sea 20 s al día. Y se miraron las 311
> ventanas de espera buscando *dentro* sucesos que significaran "el bucle tenía algo que
> hacer" —dictados, activaciones, interrupciones, cortes, recordatorios, descartes—:
> **cayeron 0 de los 7.391** que hay en el registro. Hay un motivo: `Say` llama a
> `Pausar-Escucha` **antes** que a `Say-Online`, así que durante toda la espera el micrófono
> está callado a propósito.
>
> Así que la reescritura asíncrona se descarta, y queda dicho por qué: su fallo típico —*"Nova
> dice una frase y suena otra"*— ya costó tres arreglos (17/09, 19/09 y 21/09) por un motivo
> mucho menor.
>
> **Lo que sí era un fallo:** de esos 304 s, **veinticuatro son tres plantones de 8 s**. Tres
> sucesos valen el 7,9 % del total. Y el plazo que los produce eran dos números a fuego
> (`8000 + letras * 15`) que no salían de ninguna medida: estaba en **2,2 veces el peor caso
> visto**. Ahora sale del p99 real, y una frase de 100 letras pasa de 9.500 ms a **5.400**.
>
> Y la ceguera, que era lo peor: esa línea **solo se escribe si hay charla**, así que de la
> mitad de las frases no había ni un dato. Ahora se miden todas —sin una línea por frase, que
> es lo que se acaba de quitar del registro con la idea 19—.
>
> Con una guarda: **el dato solo puede bajar el plazo, nunca subirlo.** Sintetizar tiene una
> parte fija y otra que crece con el texto, así que dividir por las letras sobreestima las
> frases largas; subirlo sería inventarse un número, bajarlo no.

### 9. Traducir una orden le cuesta 105 llamadas a la API

**246 frases** se mandaron por el camino de traducir en 15 días; de ellas **105 salieron a la
API** (`TRABAJO modo=traducir motor=api`) y solo **38** acabaron en una orden traducida que
sirve. Es el camino más caro y uno de los que menos veces acierta.

### 10. El plan de órdenes locales: 15 intentos, 4 sirvieron

`plan-sirvio` **4** frente a `plan-no` **11**: de **15 intentos, 4 salieron con órdenes que
Nova sabe hacer** y los otros 11 acabaron en el agente igualmente. Uno de cada cuatro. Cada
intento es tiempo antes de contestarte.

### 11. El turbo: 27 de 29 sin resultado

`turbo` 29, `turbo-nada` **27**. Dos de cada cien.

---

## C. Aprende cosas que luego tira

### 12. El perfil está lleno y se tira lo que entra

`perfil.md` tiene **60 datos, que es exactamente el tope**, y en 15 días ha aprendido **97**.
O sea que **37 se han caído** por el camino y nadie sabe cuáles ni por qué. Con el tope puesto,
cada dato nuevo empuja a otro fuera **en silencio**.

> **HECHA el 24/09, junto con la 20.** De los 60 datos de `memoria\perfil.md`, **veintitrés
> (el 38 %)** no son rasgos tuyos sino estados que duraron un rato: *"está en una llamada"*,
> *"vio una casa con fuego"*, *"tiene 8 dólares"*, *"usa espadas de metal en el juego"*. Y el
> perfil **viaja con cada petición** al modelo, así que cada uno era ruido en todas las
> respuestas.
>
> El filtro es una **lista cerrada**, igual que el de los tratos y por el mismo motivo: una
> abierta tiraría rasgos de verdad. Y con la salvaguarda al revés: si la frase dice *"siempre"*,
> *"suele"* o *"favorito"*, **es** un rasgo aunque hable de algo que pasa. Medido sobre los 60
> reales: caza **20 de 21** y ni un falso positivo.
>
> Y la lápida: la poda tiraba uno en silencio y se llevó por delante los **dos únicos datos que
> enseñaste a mano** con *"aprende que..."*. Ahora quedan en `perfil-caidos.md` y **"qué has
> olvidado de mí"** los lee.

### 13. Las recetas: 11 aprendidas, 7 usadas, 6 rechazadas

`receta-aprendida` 11, `receta` 7, `receta-no` 6, `receta-variante` 3. Son casi tantas
rechazadas como usadas. Hay que ver qué distingue a una receta que sirve de una que estorba.

### 14. Las reglas no se usan **nada**

`reglas.json` está **vacío** y `recordatorios.json` también. En catorce días hay **una sola
regla creada de verdad** (14/09); las otras 1.093 que salen en el registro son de las pruebas
del 11 y el 12/09.

Con todo el aparato construido —los patrones, `Describe-Regla`, el switch de disparo, el sensor
del bucle, cuatro salidas— no tienes **ni una** puesta. O no te sirve como está, o no sabes que
existe. Antes de añadirle nada, hay que averiguar cuál de las dos.

---

## D. Gasta cuando no hace falta

### 15. ~~Casi nueve horas seguidas analizando ruido~~ — **FALSA, y lo bueno es por qué**

> **Comprobada el 24/09 y retirada.** Lo de las horas sin voz es cierto: 8 h 42 min seguidos
> del 23/09, y 38 de las 324 horas del registro. Lo que **no** es cierto es la conclusión —
> "todo ese tiempo el oído está decodificando al 100 %"—. Medidos los **15.957** pulsos del
> registro que traen `decodificado=N%`:
>
> | | |
> |---|---|
> | al 100 % | **32 pulsos, el 0,2 %** |
> | al 0 % | **9.636 pulsos, el 60,4 %** |
> | mediana | **0 %** |
> | media | **9,5 %** |
>
> O sea: el oído ya se salta el decodificador seis de cada diez veces. Lo pone el propio
> `wake_vosk.py` en su línea 3300 —*"ni se toca el decodificador. Es donde está el ahorro
> real"*—, y los números dicen que funciona. El núcleo que la idea quería rescatar **ya está
> libre**.

### 16. ~~El resumen al volver es un widget el 62 % de las veces~~ — **FALSA: arreglado el 22/09**

> **Comprobada el 24/09 y retirada.** Los 774 de 1.249 son reales, pero no son 774 avisos: son
> **la misma notificación repetida**. Y caen **enteros en dos días**:
>
> | día | líneas `RESUMEN AL VOLVER` |
> |---|---|
> | 19/09 | 123 |
> | 21/09 | 1.126 (774 de ellas, el mismo widget, de 03:18 a 09:45) |
> | 22/09 en adelante | **0** |
>
> El 22/09 se puso `$script:resumenFirma` justo para eso, y desde entonces no hay ni una. Yo
> conté un fallo ya arreglado y lo presenté como abierto.
>
> Y la lista negra que proponía **ya se descartó a conciencia**, con su motivo escrito encima
> de la función: *"20 de las 36 de esos días son de Discord, o sea personas escribiendo"*, y
> una lista a mano choca con que todo se ajuste hablando.

### 17. ~~No se reinicia: se MUERE, catorce veces al día~~ — **FALSA por construcción**

> **Comprobada el 24/09 y retirada.** Los 246 arranques son reales; las "211 muertes", no. La
> resta era imposible: **`VoiceAssistant cerrado` no existía antes del 18/09 19:59** —es la
> primera vez que aparece en todo el registro—, así que los 9 días anteriores contaban
> arranques contra una línea que el código todavía no escribía.
>
> Con los dos lados midiendo lo mismo, del 18/09 en adelante:
>
> | | |
> |---|---|
> | arranques | **60** |
> | cierres limpios | **35** |
> | muertes de verdad | **25 en 5,5 días → 4,5 al día** |
>
> Y la causa está a la vista. Cruzados los 246 arranques con los **331 commits que tocan
> `assistant.ps1`**:
>
> | arranques a menos de… | |
> |---|---|
> | 10 min de un commit | 166 (**67 %**) |
> | 30 min de un commit | 207 (**84 %**) |
> | 60 min de un commit | 222 (**90 %**) |
>
> Los días gordos son los de desarrollo —10/09: 50 arranques; 12/09: 39— y los últimos días
> están en 4-14. **No se muere: la reinicio yo cada vez que la edito.** El "cualquier cosa que
> se le añada se va a perder catorce veces al día" era la conclusión más alarmante de las
> veinte, y era mía, no suya.

### 18. El micrófono se muere

**Seis veces**: `ERROR: el microfono lleva N s sin entregar audio; salgo para que me relancen`.
Se relanza solo, pero cada una es un hueco en el que Nova **no oye absolutamente nada** y tú no
te enteras.

---

## E. Y dos que no son de Nova, sino de poder arreglarla

> **HECHA el 24/09.** Y el listón sale de dos mediciones que ya estaban hechas, no de una
> corazonada: el estado se refresca cada **15 s de mediana, 29 s en el p99 y 72 s de máximo**
> (n=2.665), y arrancar el oído tarda **6 s de mediana y 12 s en el p90** (n=235 arranques).
> Con 90 segundos no se avisa en ningún arranque normal —ni siquiera en el p90, por doce— y sí
> en los ocho que pasaron de 60 s, **incluido el de 28 minutos y medio**.
>
> Va con nivel `alto` y no `medio` a propósito: `medio` se calla de noche y con un juego
> delante, y estar sorda es justo lo que hay que decir mientras juegas, porque ahí el botón es
> la única vía que te queda.

### 19. El registro es 68 % ruido del oído

**34.602 de las 50.580 líneas** son `[escucha]` (pulsos, ganancia, recortes). Buscar un fallo
de verdad ahí dentro es imposible sin un `grep -v`, y este repaso ha perdido un buen rato en
eso. Separar el pulso del oído a su propio fichero deja el registro legible de un vistazo.

> **HECHA el 24/09, y midiéndola salió algo peor.** La familia `pulso:` son **23.527 líneas,
> el 43,6 % de las líneas y el 51,2 % de los bytes** —los bytes son lo que manda, porque la
> rotación mide bytes—. Moviendo solo el *latido* el registro pasa de **378 KB/día a 207** y
> el histórico de **54 días a 99**: ×1,83.
>
> El `pulso: p90=` **no se mueve**, y no es un descuido: lleva escrito desde antes que *"esta
> sí se escribe siempre: es el ajuste de ganancia de verdad, el dato con el que se decide si
> la escucha está bien calibrada"*. Son 2.835 líneas que se quedan donde alguien las lee.
>
> Y no lo lee nadie, comprobado uno a uno: los seis sitios que leen el registro buscan otras
> cosas, y los cuatro scripts que juntan log y pulso lo **excluyen** con `-notmatch`.
>
> **Lo que salió de paso, y era peor:** de las 3.448 líneas del 24/09, **2.848 —el 82,6 %—**
> eran `ENTORNO aparcado`. Lo escribí yo el 23/09 con la idea 20 de la tanda anterior: el
> repaso del entorno pasa cada 30 s y los mismos tres avisos volvían a aparcarse en cada
> vuelta, **300 líneas por hora, unas 7.200 al día con la consola sola**. Arreglado con la
> misma guarda de firma del 22/09. El banco de avisos estaba verde: solo miraba que la cola
> no creciera, y no crecía.

### 20. Que lo que se oye en una llamada no acabe en su cabeza

El **23/09 de 21:10 a 22:19**, jugando a Unravel Two y A Way Out con la llamada detectada
(`llamada en juego: te he oido, pero con Unravel Two delante solo vale el boton`), Nova mandó
a la charla lo que se oía del otro lado y del juego:

> `[charla] Estuvo visto con ser seguida con un jugador llamado Menamión, En las notas de De
> Nueva ...`

Y a las **21:16** guardó en tu perfil **"está en una llamada"**, que no es un dato tuyo: es un
estado de diez minutos que se queda ahí para siempre — y ocupando uno de los 60 huecos de la
idea 12.

*Lo delicado:* con la llamada detectada, lo que se oye no es necesariamente para Nova. Hay que
decidir qué hacer con la charla y con el perfil mientras dura, **sin dejarla muda** si de
verdad le hablas.

> **HECHA el 24/09, junto con la 12.** *"Estoy en una llamada"* pasa a ser una **sordina de
> diez minutos**, y va en las órdenes rápidas y no en la charla porque hoy se la llevaba la
> charla —empieza por *"estoy"*, que no es un verbo de orden— y las órdenes se miran antes.
>
> No hace falta ejecutor nuevo: cae en la sordina de siempre, **con sus dos salidas** (el botón
> y *"ya escúchame"*) y su aviso de vuelta. Y los diez minutos no son un número inventado: son
> los que pediste tú esa misma noche —*"no me hablas en diez minutos"*— y los mismos de la
> autosordina por ruido.
>
> El *"está en una llamada"* que se guardó en tu perfil a las 21:16:33 lo caza ahora el filtro
> de la idea 12.

---

*Escrito el 24/09/2026, después de terminar las veinte ideas anteriores y su repaso. Cada
número de aquí se puede reproducir con un `grep` sobre `assistant.log` o leyendo
`memoria\estadisticas.json`.*
