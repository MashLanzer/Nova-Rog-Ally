# La familia del ventilador: siete lentes sobre Nova (22/09/2026, de noche)

Por la mañana se estrenó el aviso «hay un ruido de fondo y así no te voy a oír». Por la
noche se miró **su primer día entero** y salió esto: **25 avisos idénticos, de 08:00 a
20:20**, 25 de los 37 avisos de entorno de dos días. Era el ventilador de braya, delante del
micrófono. O sea que el aviso acertaba en el fondo y fallaba en **cuántas veces**. Y lo que
convierte esto en un patrón y no en un despiste: el comentario que hay **tres líneas más
arriba en el propio código** ya decía lo correcto —«un ventilador puede estar sonando toda
la tarde y eso no son ganas de que te lo repitan»— mientras el número de debajo decía 30
minutos.

**Cuando un comentario y un número se contradicen, el que está mal casi siempre es el
número.** Esta auditoría busca esa familia por todo el proyecto.

## Cómo se hizo

**64 agentes.** Siete lentes peinando en paralelo —avisos que se rearman solos, números que
contradicen su comentario, ramas que se comen a otras, bancos que miran la forma y no el
efecto, el uso real del log, código muerto, y el primer día de las 21 ideas cerradas hoy— y
**dos escépticos por hallazgo**: uno abre el fichero y comprueba si el mecanismo existe de
verdad hoy; otro recuenta el número por su cuenta y tumba el hallazgo si el arreglo pudiera
ejecutar una orden que braya no dio.

**Resultado: 28 hallazgos juzgados, 7 sobreviven, 21 tumbados.** Otros 13 se quedaron sin
refutar por el tope de cuatro por lente, y se dice aquí para no aparentar cobertura que no
hubo. Los 7 vivos son **5 fallos** (tres lentes distintas encontraron el mismo, por su
cuenta, lo cual es la mejor señal de que era real).

---

## Los cinco, y cómo se cerraron

### 1. «Ya está cargada del todo» salía cuatro veces al día, para siempre

`assistant.ps1:20987`. Colgaba de un **estado** dentro de un bloque que corre cada minuto:
con la consola enchufada, eso es cierto el día entero, y lo único que frenaba el aviso era
su propio plazo de 240 minutos. **19 avisos idénticos** en el log, cuatro al día desde el
19/09 (08:00, 12:00, 16:00, 20:02), y el último `cargador: desenchufado` es del **19/09 a
las 09:24**: los quince últimos salieron sin un solo cambio de estado. Veinte líneas más
arriba, el comentario del cargador ya decía cómo se hace bien: «solo en el FLANCO, cuando
cambia. Por estado se repetiría cada minuto».

**Y el aviso era lo de menos.** La línea de al lado, `Invoke-Reglas 'bateriaLlena'`, **no
tiene plazo ninguno** —el de 240 vive dentro de `Send-AvisoEntorno`— y su rama del despacho
es estado pelado, sin el rearme que sí tienen `'bateria'` y `'disco'`. Hoy es inofensivo
porque `reglas.json` está vacío; el día que braya diga *«cuando termine de cargar, pon el
modo trabajo»* —frase que el código ya entiende— esa acción se ejecutaría **cada sesenta
segundos** hasta que desenchufara. Eso ya no es un aviso pesado: es una orden que nadie dio,
repetida toda la tarde.

Cerrado con `Test-BateriaLlenaFlanco` y banco propio (`probar-bateria-llena.ps1`): un día
entero enchufada al 100 % da **1 disparo en 1.441 lecturas**, y desenchufar y volver a
llenar sí cuenta como episodio nuevo. Roto a propósito tres veces (volver al estado, quitar
el guardia del arranque, sacar la regla fuera del flanco) y canta en las tres.

### 2. Un banco que pasaba en verde con la protección borrada

`tools/probar-confirmaciones.ps1:35`. Comprobaba que la rama del correo devuelve
`$script:confirmado` a `$false` con un `finally`… buscándolo en una ventana de **900
caracteres** desde el ancla. Medido: el `finally` propio está a **+483** y **hay otro, el de
la cola genérica de al lado, a +787**. O sea que se podía **borrar entero el del correo** y
el banco seguía contento, casando con el del bloque vecino. Comprobado las dos veces: con la
protección fuera, el regex viejo dice **verde**; el nuevo la caza.

Lo que protege no es poca cosa: `$script:confirmado` apaga **todas** las confirmaciones
mientras está puesto; si se queda en `$true` por una salida por `return`, la siguiente orden
peligrosa se ejecuta sin preguntar. Arreglado delimitando el bloque **contando llaves**, con
una guarda que canta si el delimitador se pasa de largo. Bajar el número no valía: 400 daba
un rojo falso y cualquier valor entre 484 y 786 vuelve a mentir en cuanto alguien añada dos
líneas de comentario ahí dentro.

### 3. El juez del nombre habría tumbado 49 de tus 52 llamadas

`wake_vosk.py`. Nació el 20/09 para cortar las activaciones falsas —la madrugada del 20 Nova
se activó sola cinco veces y grabó 70 s de una conversación privada— y llevaba dos días en
modo «mirar», apuntando qué habría hecho sin hacerlo. El dato:

> **24 de las 25 activaciones del 20/09 y 25 de las 27 del 21/09. 49 de 52. El 94 %.**

Y no eran dudosas: las tres primeras del log son llamadas de braya con confianza **0,91,
0,98 y 0,94**. Encenderlo habría dejado a Nova sorda a casi todas las veces que la llaman.
No falla el listón: falla el modelo. El reconocedor **libre** de Vosk pequeño no escribe
«nova» cuando braya dice «nova», así que la segunda etapa no puede confirmar nada.

Apagado (`escucha.juezNombre = "no"`), que **no cambia ni una activación** —en «mirar»
siempre dejaba pasar— y ahorra un reconocedor vivo y una decodificación en cada ráfaga, en
una consola que se queda en 420 MB libres cuando aprieta (tanto, que el 22/09 el juez ni
llegó a arrancar). El veredicto queda escrito en el código para que nadie lo reabra subiendo
un número.

**Lo que esto rompe, y hay que saberlo:** `jarvis-pendiente.md:257` pone como condición (a)
para desbloquear las ideas que «escuchan más» que el juez pase de «mirar» a «sí» con sus
cifras delante. Las cifras están delante y dicen que no puede pasar. **Esa puerta se queda
cerrada hasta que haya otro mecanismo**, no hasta que alguien suba un umbral. Anotado ahí
mismo.

Y una trampa que dejó ver el escéptico: el «ambiente» no tiene oído propio, se alimenta del
reconocedor del juez. Con el juez apagado, encender el ambiente daría una lista siempre
vacía y ni un error. Ahora avisa al arrancar.

### 4. «Hoy te estoy entendiendo peor» contaba cancelaciones y timeouts

`assistant.ps1:8278`. Miraba el contador `'error'`, que sube en tres sitios exactos y solo
uno tiene que ver con entender: dictado vacío, **la orden que cancela braya**, y el
**timeout de opencode**. Un día en que braya cancelara cuatro veces y opencode se atascara
dos, Nova le habría dicho que no le entiende. El contador de «no te entendí» es
`'descarte'`, y las magnitudes no se parecen: el 15/09 fueron 10 errores contra 30
descartes; el 11/09, 13 contra 52.

Cambiado el contador, **no el listón**: simulado día a día sobre `estadisticas.json`, con
`'error'` no habría saltado nunca en 11 días y con `'descarte'` tampoco. Eso está bien y es
lo que se busca —es un aviso para un día malo de verdad—; bajarlo ahora sería estrenar de
verdad, y hablando, un aviso que llevaba siete días midiendo lo que no era. El banco lleva
el caso que lo caza: doce cancelaciones no son doce malentendidos.

### 5. La nube se daba por cerrada porque un banco se inventó un tercer día

`IDEAS-2026-09-22.md` decía que la idea 1 estaba «cerrada: se apaga sola al llegar el tercer
día». No es así. El freno que manda no cuenta días, cuenta **reparto** (`Test-DatosRepartidos`,
tope 70 %), y los números reales son 20/09: 92 intentos, 21/09: 27, 22/09: 6 — el día gordo
pesa **92/125 = 73,6 %**, por encima del tope. Con eso no se apaga por muchos días que
pasen: hace falta que otro día de uso normal diluya al 20/09.

Se daba por cerrada porque `probar-revision-propia.ps1:278` **escribía 20 intentos** para el
tercer día (66,2 %, verde). El banco ya prueba las dos caras y el documento dice la verdad.

---

## Lo que salió de mirar el log mientras la auditoría corría

Dos cosas que no venían de las lentes sino de leer lo que le pasaba a braya esa misma noche,
y las dos están arregladas en el mismo commit:

- **Te ignoraba en silencio mientras jugabas.** Con un juego delante solo vale el botón —eso
  viene del 11/09 y no se toca—, pero no decía nada: **44 llamadas** ignoradas el 22/09, de
  20:28 a 22:05, incluidas «ey nova», «ey nova nova» y «ey nova escucha», que es alguien
  insistiendo porque cree que no le oyen. Ahora se ve en la cápsula, **una vez por partida**,
  sin voz (jugando no se interrumpe, y la llamada pudo ser un falso positivo) y sin ejecutar
  nada. Verificado en vivo un segundo después del reinicio.
  **Y la pregunta de fondo la contestó braya**: con el dato de las 44 llamadas delante,
  eligió **dejar el modo solo-botón como está**. No se toca; lo único que cambia es que
  ahora lo dice.
- **Dijo «me callo» y no se calló.** A las 21:48:54: *«No, no me hablas por 10 minutos»*.
  Ninguna forma de **hablar** estaba en los patrones, así que fue a la charla y la charla
  contestó «Vale, entendido, me callo»… y siguió escuchando. La última sordina de verdad del
  log es del 15/09. Ahora entra, se calla con plazo, y **vuelve cuando braya la llama por su
  nombre**, que es lo que pidió.

---

## Lo que se tumbó, y por qué importa

**21 hallazgos cayeron.** Los motivos se repiten y conviene tenerlos escritos, porque son los
mismos que hacen perder el tiempo cada vez:

- el mecanismo descrito **ya tenía una guarda** que el hallazgo no había visto;
- el número **no salía al recontarlo**, o medía otra cosa;
- **ya estaba contestado** en un documento anterior (varias propuestas reabrían cosas
  cerradas con dato el 17, el 19 o el 21/09);
- el arreglo **abría una vía de orden equivocada**, que aquí es motivo suficiente por sí solo.

Y un tumbado con reparo, que se deja apuntado: la regla `bateriaLlena` se tumbó como «hoy no
pasa nada porque `reglas.json` está vacío». Es cierto **hoy**, y por eso el arreglo se hizo
igual: lo que no puede pasar es que el día que braya cree esa regla, nadie se acuerde.

## Y lo que quedó sin mirar

**13 hallazgos no pasaron por los escépticos** porque cada lente refutaba solo los cuatro
primeros. No están descartados: están sin juzgar. Se dice aquí porque un informe que no
cuenta lo que se dejó fuera se lee como si lo hubiera cubierto todo, que es exactamente el
fallo que esta auditoría vino a buscar.
