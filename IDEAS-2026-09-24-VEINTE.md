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

### 8. La mitad de sus frases se fabrican en el momento

**330** frases suenan en menos de 250 ms (`voz: frase ya preparada`) y **311** tardan más
(`sintetizada al momento`). Y no es poco: de esas 311, la **mediana es 903 ms**, el **p90
1.247 ms** y la peor **3,6 segundos** callada antes de empezar a hablar.

Casi la mitad de lo que te dice paga la síntesis entera. Hay que saber qué tienen las 330 que
no tienen las otras.

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

### 19. El registro es 68 % ruido del oído

**34.602 de las 50.580 líneas** son `[escucha]` (pulsos, ganancia, recortes). Buscar un fallo
de verdad ahí dentro es imposible sin un `grep -v`, y este repaso ha perdido un buen rato en
eso. Separar el pulso del oído a su propio fichero deja el registro legible de un vistazo.

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

---

*Escrito el 24/09/2026, después de terminar las veinte ideas anteriores y su repaso. Cada
número de aquí se puede reproducir con un `grep` sobre `assistant.log` o leyendo
`memoria\estadisticas.json`.*
