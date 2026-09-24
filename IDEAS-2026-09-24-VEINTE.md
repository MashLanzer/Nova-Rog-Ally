# Veinte ideas nuevas para Nova — 24/09/2026

Todas salen de **tu registro de catorce días** (50.340 líneas de `assistant.log`), de
`memoria\estadisticas.json` y de las 514 frases reales guardadas en `pruebas\audio\uso`.
Ninguna es una ocurrencia: cada una lleva el número que la sostiene y el día en que pasó.

Van ordenadas por lo que más te cuesta hoy, no por lo que sea más bonito de hacer.

---

## A. Lo que te rompe el uso diario

### 1. Que decir "nova" sirva de algo

De las **815 veces** que dijiste su nombre, solo pasaron **392 (48 %)**:

- **83** se tiraron por sonar flojo — `descartado 'nova': suena demasiado flojo para ser una
  llamada`, **29 en un solo día** (21/09), y **13 anoche entre las 00:14 y la 01:23**.
- **340** se ignoraron por estar jugando — `'nova' ignorado: estas jugando, aqui solo vale el
  botón`, **24 de ellas hoy mismo**.

Y el umbral no es fijo: se mueve solo entre **0,017 y 0,030** según el ruido, y **21 de esos
83 descartes estaban a menos de un 20 % del umbral del momento**. O sea que la mitad de las
veces que la llamas por su nombre, no te oye — y una parte es por un pelo.

*Lo delicado:* subir el umbral a lo bruto hace que la tele la despierte. Lo que hay que mirar
es si el rechazo por volumen puede pedir una segunda opinión en vez de tirar la frase, y qué
hacer con el "nova" jugando, que hoy se descarta **en silencio**.

### 2. Que no se crea lo que oye en una llamada

El **23/09 de 21:10 a 22:19**, jugando a Unravel Two y A Way Out, con la llamada detectada
(`llamada en juego: te he oido, pero con Unravel Two delante solo vale el boton`), Nova mandó
a la charla lo que se oía del otro lado y del propio juego:

> `[charla] Estuvo visto con ser seguida con un jugador llamado Menamión, En las notas de De
> Nueva ...`

Y a las **21:16** guardó en tu perfil **"está en una llamada"**, que no es un dato tuyo: es un
estado de diez minutos que se queda ahí para siempre.

*Lo delicado:* con la llamada detectada, lo que se oye no es necesariamente para Nova. Hay que
decidir qué hacer con la charla y con el perfil mientras dura, sin dejarla muda si de verdad
le hablas.

### 3. Que el resumen al volver no sea un widget

**774 de los 1.249 resúmenes** (el **62 %**) dicen exactamente esto:

> `RESUMEN AL VOLVER: Mientras no estabas: 1 mensaje de XBOX Game Bar Widgets`

Solo **123** son de Discord, que es donde están tus personas. El resto (**352**) ni siquiera
dicen de quién. Una lista negra de remitentes que no son personas convertiría un aviso que ya
no escuchas en uno que sí.

### 4. Mirar tu pantalla cuando se lo pides

**21 descartes** hablan de tu pantalla. Uno de ellos eres tú, con todas las letras:

> `deja de decir que no ves nada en mi pantalla literalmente tienes un ocr con el que ver mi
> pantalla`

Y también: *"mira la pantalla y dime que ves"*, *"míralo tú mismo en la pantalla y dime que
ves"*, *"mira mi pantalla y encuentra otra solución para llegar a la plataforma"*, *"te ves en
mi pantalla"* (dos veces). El OCR existe y la captura también; lo que falta es que esas frases
lleguen a él.

### 5. Crear carpetas y archivos

**22 descartes en tres días**: *"crea una carpeta llamada prueba dos en el escritorio"* (dos
veces, y otra vez como *"Crea una carpeta llamada Prueba 2..."*), *"puede crear una cappeta en
mi queridor"*, *"crea un archivo de texto en C:\Users\braya\AppData\Local\Temp\nova-prueba.txt
que diga hola desde nova"*. Es lo único que pediste repetidamente que **no existe**.

*Lo delicado:* crear es fácil, pero abre la puerta a escribir donde no toca. Lista cerrada de
carpetas (las siete de siempre) y nada de rutas dictadas a ciegas.

### 6. La muletilla "mira", sin romper el verbo "mira"

**16 descartes empiezan por "mira"**, y son dos cosas distintas:

- **Relleno**: *"mira ponme un temporizador de 5 minutos"*, *"mira recuérdame mañana
  instalarme el juego"*, *"mira por qué no me dices cuánto espacio libre me queda"*.
- **El verbo de verdad**: *"mira la pantalla y dime que ves"*, *"mira mi pantalla y mira si tú
  encuentras otra solución"*.

Quitarla a lo bruto rompe la mitad de los casos. Hay que quitarla **solo cuando lo que queda
detrás ya se entiende solo**.

### 7. El correo en infinitivo y en cortés

**Nueve descartes** de algo que ya existe y funciona: *"revisar mi correo"* (4), *"revisa mi
correo"* (2), *"puede revisar mi correo y ver si tengo algo nuevo"* (3).

### 8. Los dos descartes más repetidos, que siguen ahí

- *"estado es cargando en steam"* — **20 veces**
- *"hay alguna actualización de este"* — **16 veces**

La idea 2 de la tanda anterior tocó el deíctico, pero estas dos siguen cayéndose. Son, con
diferencia, las dos frases que más veces has repetido sin que Nova hiciera nada.

---

## B. Lo que gasta y no compra nada

### 9. Parakeet cae a Whisper el 84 % de las veces

**338 rebotes** (`parakeet-a-whisper`) frente a **64 aciertos** (`parakeet`). O el motor
rápido sirve para algo, o sobra: hoy se paga el arranque de los dos.

### 10. La nube no contesta, o llega tarde

De **201 intentos**: **90 no devuelven nada** (45 %), **35 no contestan a tiempo**
(`NUBE: no contesto a tiempo; sigo con el oido de siempre`) y **12 contestan después** de que
el oído local ya hubiera resuelto.

### 11. El oído fino que no cambia nada

**45 de 145 pasadas** devuelven **exactamente el mismo texto** (31 %) y **7 se inventan algo**
(`fino-invento`). Merece la pena medir cuándo aporta y saltárselo cuando no.

### 12. 1.082 trozos de audio tirados por llegar tarde

`descartados N s de audio atrasado`: **604** en la transcripción y **478** en el oído fino.
**374 en un solo día** (15/09). Es audio que ya se había grabado y se tira sin mirarlo.

### 13. Once horas y media analizando nada

**690 pulsos seguidos** de `esto no es voz, es ruido de fondo`, uno por minuto. De madrugada
eso es un núcleo trabajando para nada, y el núcleo hace falta cuando juegas.

### 14. El turbo que casi nunca acierta

**29 intentos, 27 sin resultado** (`turbo` / `turbo-nada`). Dos de cada cien. O se arregla o se
quita.

---

## C. Lo que ya existe y no se alcanza

### 15. "pon la novena canción"

**16 descartes** son de música. Los ordinales llegan hasta el décimo en una tabla, pero el
patrón de la canción se queda antes, así que *"pon la novena canción"* se va al modelo.

### 16. "pon un temporizador PARA 2 horas"

**Tres descartes**, y la única diferencia con la que sí funciona es **"para" en vez de "de"**.

### 17. La pantalla partida

**44 líneas** del registro hablan de *"la mitad de la pantalla"*: *"abre navegador en la mitad
de la pantalla izquierda con painteress y en la otra mitad de..."*, *"abre youtube a la mitad
de la pantalla y en la otra mitad"*. Los montajes existen, pero solo colocan **dos ventanas de
escritorio**, y la frase se descarta.

### 18. Un "sí", un "no" o un "ok" sin nada pendiente

**20 descartes** de *"si"*, *"no"*, *"ok"*, *"no no no no"*. Hoy se tiran en silencio. Podrían
al menos decirte a qué creía Nova que le estabas contestando.

---

## D. Lo que hay que mirar antes de tocar nada

### 19. Las reglas no se usan

`reglas.json` está **vacío** y `recordatorios.json` también. En catorce días hay **una sola
regla creada de verdad** (14/09); las otras 1.093 que salen en el registro son de las pruebas
del 11 y el 12/09.

Con todo el aparato construido —los patrones, `Describe-Regla`, el switch de disparo, el
sensor del bucle, cuatro salidas— **no hay ni una regla puesta**. O no te sirve como está, o no
sabes que existe. Antes de añadirle nada más, hay que averiguar cuál de las dos.

### 20. El micrófono se muere

**Seis veces**: `ERROR: el microfono lleva N s sin entregar audio; salgo para que me
relancen`. Se relanza solo, pero cada una es un hueco en el que Nova **no oye absolutamente
nada** y tú no te enteras.

---

*Escrito el 24/09/2026, después de terminar las veinte ideas anteriores y su repaso.*
