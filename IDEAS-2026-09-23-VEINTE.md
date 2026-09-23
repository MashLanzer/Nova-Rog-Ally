# Veinte funciones nuevas para Nova

*23 de septiembre de 2026, después de la tanda de diez y de la revisión.*

---

## Antes de las ideas: un dato que cambia dónde hay que buscar

En catorce días Nova dijo **«no reconozco…» 474 veces**, sobre **357 frases distintas** de
braya. Suena a que hay mucho hueco. Pero pasando esas 357 frases por los patrones de hoy
—`tools/diag/diag-perdidas.ps1`, que se escribió para esto—:

| | |
|---|---|
| ya se entienden hoy | **330 frases** (447 de las 474 veces) |
| siguen sin entenderse | **27**, y son todas ruido: «opa», «mamamoo», «that», «mhm», «epic» |

**No queda ni una orden real sin cubrir.** Todo lo que braya ha pedido alguna vez, Nova ya
lo entiende. Así que las ideas que siguen no salen de los huecos: salen de lo que **intentó y
abandonó**, y de lo que tiene delante y nunca se le ocurrió pedir.

Contando sus **1.631 frases distintas** por temas:

| tema | frases suyas | estado hoy |
|---|---|---|
| música y canciones | **52** | lo intentó muchas veces; nunca funcionó bien |
| YouTube / pantalla partida | 56 | resuelto el 23/09 con los montajes |
| ficheros y carpetas | 41 | parcial |
| «esto», «este», «lo que estoy…» | **41** | Nova no sabe a qué señala |
| instalar y descargar | **27** | solo sabe mirar, no hacer |
| calendario y agenda | 8 | **no existe** |
| trivia y curiosidades | 8 | va a la nube, tarda |
| recordatorios repetidos | 7 | solo de una vez |
| corregir lo que sabe de él | 6 | **no existe** |
| capturas y clips | 3 | existe |

---

## 1. Poner música de verdad, y acordarse de lo que no le gusta

**El dato.** 52 frases suyas distintas sobre música, y ninguna acabó bien. Están todas en el
registro: *«Reproduce la canción de Pitbull Give Me Everything»*, *«Yo no lo quiero en
Spotify»*, *«Pero yo no te dije que reprodujeras eso, yo te dije el segundo vídeo»*, *«A
Pitbull, te lo acabo de decir, Pitbull»*, y la que lo resume todo:

> *«Reproduce música electrónica y además recuerda que ese tipo de música que pusiste ahora
> no me gusta»*

**Qué es.** «Nova, pon Give Me Everything de Pitbull» abre el primer resultado de YouTube y
**lo dice antes de abrirlo** («pongo Give Me Everything de Pitbull, ¿esa?»). «No, la
siguiente» pasa al segundo sin volver a buscar. Y **«esa no me gusta»** se apunta: el artista
o el estilo rechazado no vuelve a salir el primero.

**Por qué es segura.** No reproduce nada sin nombrarlo antes; la lista de resultados es
cerrada (los cinco primeros) y se recorre con la cruceta —el selector de la función 10— o
diciendo «la segunda».

---

## 2. Saber a qué señala cuando dice «esto»

**El dato.** 41 frases suyas llevan un deíctico sin referente: *«hay alguna actualización de
este»* (16 veces), *«este estado es cargando en Steam»* (20), *«abre este»*, *«ahora sí algo
se está explicando en este»*. Nova no tiene ni idea de a qué se refiere, así que se va al
modelo y falla.

**Qué es.** Cuando la frase lleva «este/esto/eso» y no hay nada más que la desambigüe, Nova
mira **qué ventana tiene delante** y contesta de eso. Si delante está Steam con un juego
abierto, «¿hay alguna actualización de este?» es sobre ese juego. Si no sabe qué hay delante,
lo dice: «¿de qué, de lo que tienes en pantalla?».

**Por qué es segura.** Solo resuelve el deíctico para **preguntas**, nunca para acciones: «abre
este» sigue preguntando.

---

## 3. Instalar un juego por voz

**El dato.** 27 frases sobre descargas, y las suyas son de hacer, no de mirar: *«Instala en
Steam, It Takes Two»*, *«avísame cuando la descarga de Steam terminó»*. Nova sabe decir cuánto
le queda a una descarga, pero no empezar una.

**Qué es.** «Nova, instala It Takes Two» abre `steam://install/<appid>`, que es la URL oficial
y hace que sea **Steam** quien pida la confirmación, no Nova. Y avisa al terminar.

**Por qué es segura.** Nova no descarga nada: abre la página de instalación y el botón lo
pulsa braya. El appid sale de la búsqueda de la tienda, no de un modelo.

---

## 4. Recordatorios que se repiten

**El dato.** *«cada 2 horas di que estire la espalda»* — dicho una vez, no reconocido. Los
recordatorios de Nova son todos de una vez.

**Qué es.** «cada dos horas dime que estire la espalda», «todos los días a las nueve
recuérdame X», «los lunes recuérdame Y». Se guardan en `memoria/recordatorios.json` con su
repetición.

**Por qué es segura.** Cada recordatorio repetido se puede quitar con «quita el de la espalda»
y Nova **los enumera** cuando se le pide: «¿qué me recuerdas?». Un recordatorio que no se sabe
apagar es exactamente el modo que no se tolera aquí.

---

## 5. Un calendario que sea suyo, sin cuentas ni nube

**El dato.** *«revisa mi calendario y dime si tengo algo anotado para mañana»*, dicho dos
veces, y ocho frases del tema. No hay calendario.

**Qué es.** «apunta que el viernes tengo médico a las cinco», «¿qué tengo mañana?», «¿tengo
algo el sábado?». Un JSON en `memoria/`, como los recordatorios. Sin Google, sin cuentas, sin
internet.

**Por qué es segura.** Solo lee y escribe un fichero suyo. Nada sale de la consola.

---

## 6. Guía del juego que tiene delante

**El dato.** *«Busca información sobre el juego que estoy jugando y dime qué [hacer] en esta
parte»*. Nova ya sabe qué juego está abierto (lo apunta en `memoria/juegos.json`) y ya sabe
buscar, pero nunca junta las dos cosas.

**Qué es.** «¿cómo paso esto?» → Nova coge el nombre del juego de delante, busca «<juego>
guía <lo que se ve en pantalla>» y **lee tres líneas**, sin abrir el navegador encima de la
partida.

**Por qué es segura.** No abre ninguna ventana con la partida delante —esa regla ya existe— y
si no encuentra nada lo dice, sin inventar.

---

## 7. Corregir lo que Nova cree saber de él, hablando

**El dato.** *«eso es un dato falso, elimínalo»*, *«eso no es verdad»*: 6 frases. Y el caso que
lo prueba, del 20/09: sus **dos correcciones seguidas** del nombre de un juego se guardaron
como dos datos nuevos encima del malo. Hoy su perfil tiene cuatro líneas de un «Amino» que no
existe y cuatro de un «Meramiau» inventado.

**Qué es.** «eso que acabas de decir es falso» borra **el dato concreto** que Nova acaba de
usar en su respuesta, no el último aprendido. Y «no me llamo así, me llamo X» corrige en vez
de añadir.

**Por qué es segura.** Le enseña qué línea va a borrar antes de hacerlo y lo resuelve con el
selector de la función 10: lo que hay en su perfil es suyo.

---

## 8. Trivia y curiosidades, en local

**El dato.** 8 frases: *«trivia»*, *«cuéntame algo curioso»*, *«cuántas patas tiene una
araña»*, *«cuál es la capital de Australia»*, *«quién pintó la Mona Lisa»*. Todas se fueron a
la nube y tardaron.

**Qué es.** Un modo de preguntas de tres o cinco rondas: Nova pregunta, braya contesta con
**el mando** (A/B o la cruceta, que es lo que tiene en las manos), y lleva el marcador. Las
preguntas las genera el modelo local una vez y se guardan.

**Por qué es segura.** Es un modo, así que lleva sus tres salidas: «déjalo», B en el mando, y
un plazo. Y no toca nada de la consola.

---

## 9. Contar y buscar en sus carpetas

**El dato.** 41 frases sobre ficheros y carpetas, y dos concretas que no entraron: *«cuenta
cuántos archivos hay en mi carpeta de descargas»*, *«cuenta cuántos archivos hay en mi carpeta
de documentos»*.

**Qué es.** «¿cuántos archivos hay en descargas?», «¿qué es lo más grande que tengo en
descargas?», «¿tengo algún PDF en el escritorio?». Contar, medir y listar —nunca borrar.

**Por qué es segura.** Solo lee. Borrar ya existe y ya pregunta.

---

## 10. Avisar cuando su novia se conecta

**El dato.** Juega con ella: **It Takes Two, seis horas seguidas** el 15-16/09 (`JUEGO: 6 h con
It Takes Two`), y Roblox. Y ocho de sus doce juegos son de dos. Nova ya sabe ver quién está
conectado en Steam (F9) pero solo si se lo preguntan.

**Qué es.** «avísame cuando se conecte <nombre>» → un toque en el mando y una tarjeta, sin
voz, cuando aparezca. Una vez, y se apaga sola.

**Por qué es segura.** Un aviso, una vez, sin voz con un juego delante. Se quita con «quita el
aviso de <nombre>».

---

## 11. «¿Cuánto llevo jugando?» y el freno que él mismo ponga

**El dato.** `memoria/juegos.json` ya guarda los minutos por día y por juego, y el log tiene
`JUEGO: 6 h con It Takes Two`. Nova avisa a las 2 h, pero braya no puede preguntarlo ni
cambiarlo.

**Qué es.** «¿cuánto llevo hoy?», «¿cuánto jugué esta semana?», «avísame cada hora mientras
juego», «hoy no me avises».

**Por qué es segura.** El aviso lo pone y lo quita él. Nova no cierra nada nunca.

---

## 12. Que el arranque no le cueste cuatro segundos

**El dato.** Nova arranca **17 veces al día** (235 en 14 días) y en cada arranque el oído
carga Whisper *base* desde cero: **192 cargas registradas, 3,7 a 4,2 s cada una**. Son unos
**12 minutos al día** en los que Nova está medio sorda, y el propio log lo dice: *«ARRANQUE: el
oído aún carga, lo aviso en el saludo»*.

**Qué es.** Mirar si el modelo se puede dejar precargado en memoria mapeada entre arranques, o
si Parakeet solo (que carga en 4,7 s pero es el que más acierta) basta para los primeros
segundos. **Primero medir, después decidir**: puede que la respuesta sea que no se puede.

**Por qué es segura.** Es una medición. No cambia nada hasta que el número diga qué cambiar.

---

## 13. Apagar Gemini, o dejarlo con un motivo

**El dato.** Está en su propio log, escrito por Nova hoy mismo:

> *«la segunda opinión de la nube solo me ha servido 0 de 125 veces»*

Cero de 125. Y cada llamada tiene un tope de 7 s que a veces se agota (*«no contestó a tiempo»*,
35 veces).

**Qué es.** Que Nova lo apague sola cuando lleve N días sin servir, lo diga una vez, y deje la
puerta abierta («vuelve a encender la nube»). Ella ya lo está proponiendo; solo le falta poder
hacerlo.

**Por qué es segura.** Apagar una segunda opinión no quita ninguna capacidad: el oído local
sigue igual. Y se enciende hablando.

---

## 14. Un botón para «repite eso»

**El dato.** En sus frases hay varios *«¿qué?»*, *«¿qué has dicho?»* y, con el ventilador
delante, Nova habla y él no la oye. El registro tiene 113 grabaciones que volvieron vacías.

**Qué es.** Doble toque en **B** (que hoy no hace nada fuera de una pregunta) repite la última
frase de Nova. Sin decir «repite», sin que el oído tenga que acertar.

**Por qué es segura.** B libre solo cuando no hay pregunta ni panel ni selector —las tres ya
se comprueban— y con un juego delante hace falta ≡+B, igual que todo lo demás.

---

## 15. Que la lupa se pueda mover

**El dato.** Su pantalla mide **15 × 9 cm** con el escritorio a 1280×720: **0,117 mm por
píxel**. La lupa (función 8) amplía ×2 un trozo fijo; si lo que quiere leer está justo al lado,
hay que pedir otra zona entera.

**Qué es.** Con la lupa abierta, la **cruceta la mueve** por la captura y los gatillos cambian
el aumento (×2, ×3, ×4). Sin volver a capturar: la imagen ya está.

**Por qué es segura.** Es el mismo mecanismo del selector, con las mismas guardas: ≡ con un
juego delante, plazo, y B la quita.

---

## 16. Leerle lo que llega mientras juega

**El dato.** 774 líneas del registro son la misma notificación repetida, y 117 de Discord, que
son personas escribiendo. Hoy Nova cuenta cuántas hay, pero no qué dicen.

**Qué es.** «¿qué dice?» tras un aviso de Discord lee **el remitente y la primera línea**, sin
abrir nada. Y «contesta que ahora voy» escribe eso y ya.

**Por qué es segura.** Escribir en un chat **sí pide confirmación** —es la misma familia que el
correo, que ya la pide—, y leer no abre ninguna ventana encima de la partida.

---

## 17. Modo «estamos dos»

**El dato.** Ocho de sus doce juegos son de dos, tres **solo** se pueden jugar de dos, y el
15/09 estuvo seis horas con It Takes Two.

**Qué es.** «vamos a jugar los dos» de una vez: pone el juego, sube el volumen del sistema,
silencia los avisos que no son urgentes y deja el brillo del perfil de juego. «ya estamos» lo
deshace.

**Por qué es segura.** Es un montaje con nombre, que ya existe (función 3): se guarda lo que
hizo y se deshace igual.

---

## 18. Que aprenda a decir los nombres de sus juegos

**El dato.** El oído va al **70,4 %**, y los títulos en inglés son lo que peor entiende: en el
registro están *«Jolon Nights»*, *«gus gus dup»*, *«Aura pic»*, *«contenguarme»*, *«cierra en
la ring»* (Elden Ring), *«abre stein»* (Steam). Ya hay un emparejado por sonido, pero solo se
usa detrás de un verbo de abrir.

**Qué es.** Que cada vez que braya **corrija** un título mal oído («no, Elden Ring»), esa forma
mal oída se guarde apuntando al juego bueno. Con cinco correcciones, Nova deja de fallar en
ese título para siempre.

**Por qué es segura.** Solo aprende de una corrección **explícita** suya, nunca de una
suposición. Y «olvida lo que aprendiste de los nombres» lo borra.

---

## 19. Un resumen del día, cuando él lo pida

**El dato.** El parte de la mañana ya existe y sale cuatro veces en el registro. Pero no hay
nada para el final del día, y Nova tiene los datos: qué jugó y cuánto, cuántas órdenes
acertó, qué descargó, cuánto disco queda.

**Qué es.** «¿qué tal el día?» → «tres horas con Elden Ring, te entendí 38 de 41, se bajaron
dos juegos y te quedan 12 gigas».

**Por qué es segura.** Solo cuenta lo que ya está apuntado. No se dispara sola: se pregunta.

---

## 20. Que sepa cuándo callarse porque él no está

**El dato.** El registro lo enseña sin querer: **774 avisos** repetidos entre las 03:18 y las
09:45 del 21/09, hablándole a una habitación vacía. Eso ya se arregló, pero el problema de
fondo sigue: Nova no sabe si braya está delante.

**Qué es.** Tres señales que ya tiene y no usa juntas: si el mando se ha movido en los últimos
minutos, si hay un proceso en primer plano cambiando, y si el micrófono oye algo que no sea el
ventilador. Con las tres en frío, **los avisos se guardan y se dan al volver**, en una línea.

**Por qué es segura.** No apaga nada: retrasa. Y lo urgente (batería al 5 %, disco lleno) sigue
saliendo siempre.

---

## Lo que NO propongo, y por qué

- **Un asistente que juegue por él.** Lo dijo claro el 20/09: quiere que Nova *mire* la
  pantalla, no que la maneje.
- **Más modos.** Cada modo nuevo es una salida más que mantener. Las cuatro ideas de arriba que
  son modos (8, 15, 17) reutilizan el selector y los montajes, que ya tienen sus salidas
  probadas.
- **Cambiar el motor del oído.** Está medido el 21/09: cambiar de modelo **no** mejora la
  comprensión, y las hotwords de Parakeet no se pueden usar. El techo del 70,4 % no se mueve
  por ahí; se mueve dando **otra vía** —el mando—, que es lo que se hizo hoy.

---

## Por dónde empezaría

| orden | idea | por qué esa |
|---|---|---|
| 1 | **1. Música** | 52 frases suyas, el tema que más ha intentado y que nunca ha funcionado |
| 2 | **7. Corregir el perfil hablando** | su perfil tiene 8 líneas inventadas de 59, y le vuelven habladas |
| 3 | **2. Saber a qué señala «esto»** | 41 frases, y hoy todas acaban en el modelo |
| 4 | **13. Apagar Gemini** | 0 de 125; es la decisión mejor respaldada de todo el registro |
| 5 | **14. Repetir con B** | media hora de trabajo y quita la fricción del ventilador |
