# Veinte ideas nuevas para Nova — 24/09/2026

Todas salen de **medir cómo se comporta Nova de verdad**: 50.451 líneas de `assistant.log`
(15 días), `memoria\estadisticas.json` y las 514 frases reales de `pruebas\audio\uso`.

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

`pausa: el asistente habla o dicta, se ignora el microfono` sale **1.132 veces**: son los ratos
en los que Nova está hablando. Cortarla mientras habla **sí existe** —`INTERRUMPIDA: 'X'
mientras hablaba -> me callo y te escucho`— pero solo ha saltado **10 veces en 15 días**: tres
el 14/09, tres el 22/09, y días enteros con ninguna.

O sea: 1.132 ocasiones y 10 cortes. O cuesta mucho acertar, o no sabes que se puede. Con las
respuestas largas (la guía de un juego, el resumen del día, una lista de amigos) son varios
segundos hablándole encima sin que pase nada.

*Lo que hay que medir antes de tocar:* cuántas de esas 1.132 veces le hablaste de verdad
mientras ella hablaba. Ese dato **está** en `pruebas\audio\uso`, con marca de tiempo.

### 3. El micrófono satura, y encima desconfía de sí mismo

- `recorte detectado: bajando ganancia` — **404 veces**.
- `recorte con los altavoces sonando` — **262 veces** más, y ahí la ganancia se queda quieta.
- `medidor de altavoces activo: se desconfia del microfono` — **472 veces**.

O sea: casi 700 saturaciones y 472 ratos en los que Nova decide no fiarse de lo que oye porque
suenan sus propios altavoces. Eso es justo cuando tú le hablas encima de lo que ella dice.

### 4. Parakeet cae a Whisper el 84 % de las veces

**338 rebotes** (`parakeet-a-whisper`) frente a **64 aciertos** (`parakeet`). O el motor rápido
sirve para algo, o sobra: hoy se paga el arranque de los dos.

### 5. 1.116 trozos de audio tirados por llegar tarde

`descartados N s de audio atrasado`: **604** en la transcripción y **478** en el oído fino,
con **374 en un solo día** (15/09) y 208 el 20/09. Es audio que ya estaba grabado y se tira
**sin mirarlo**.

### 6. El oído fino: uno de cada tres no cambia nada

**45 de 145 pasadas** devuelven **exactamente el mismo texto** (31 %) y **7 se inventan algo**
(`fino-invento`). Merece la pena medir cuándo aporta de verdad y saltárselo cuando no.

---

## B. Te contesta tarde, o no contesta

### 7. La nube no contesta, o llega cuando ya no hace falta

De **201 intentos**: **90 no devuelven nada** (45 %), **35 no contestan a tiempo** y **12
contestan después** de que el oído local ya hubiera resuelto — uno de ellos **2,1 s tarde**.

### 8. La mitad de sus frases se fabrican en el momento

`voz: frase ya preparada` **330** veces frente a `voz: frase sintetizada al momento` **311**.
Casi la mitad de lo que te dice paga la síntesis entera antes de empezar a sonar. Las que ya
están preparadas suenan al instante: hay que saber por qué las otras no lo están.

### 9. Traducir una orden le cuesta 105 llamadas a la API

**246 traducciones** en 15 días, de las que **105 salen a la API** (`TRABAJO modo=traducir
motor=api`) y solo **38** acaban en una orden traducida que sirve. Es el camino más caro y el
que menos veces acierta.

### 10. El plan de órdenes locales: 26 intentos, 4 sirvieron

`plan` 15, `plan-no` 11, `plan-sirvio` **4**. Uno de cada seis. O se mide por qué falla o se
quita: cada intento es tiempo antes de contestarte.

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

### 15. Treinta y cuatro horas seguidas analizando ruido

La racha más larga son **2.074 pulsos seguidos** de `esto no es voz, es ruido de fondo`, uno
por minuto: **34 horas y media** sin una sola voz, terminando el 23/09 a las 10:30. Y hay
**1.864 momentos** con más de 600 pulsos seguidos. De madrugada eso es un núcleo trabajando
para nada, y el núcleo hace falta cuando juegas.

### 16. El resumen al volver es un widget el 62 % de las veces

**774 de los 1.249** dicen exactamente `Mientras no estabas: 1 mensaje de XBOX Game Bar
Widgets`. Solo **123** son de Discord, que es donde están tus personas, y **352** ni siquiera
dicen de quién. Una lista negra de remitentes que no son personas convertiría un aviso que ya
no escuchas en uno que sí.

### 17. Se reinicia 16 veces al día

**245 arranques en 15 días**: 14 el 20/09, 13 ayer. Cada uno tira el estado que vive en memoria
—y esta tanda ya tuvo que salvar dos cosas que se perdían ahí— y paga el arranque del oído
entero. Nadie ha mirado **por qué** se reinicia tanto.

### 18. El micrófono se muere

**Seis veces**: `ERROR: el microfono lleva N s sin entregar audio; salgo para que me relancen`.
Se relanza solo, pero cada una es un hueco en el que Nova **no oye absolutamente nada** y tú no
te enteras.

---

## E. Y dos que no son de Nova, sino de poder arreglarla

### 19. El registro es 68 % ruido del oído

**34.525 de las 50.451 líneas** son `[escucha]` (pulsos, ganancia, recortes). Buscar un fallo
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
