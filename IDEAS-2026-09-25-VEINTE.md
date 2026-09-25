# Veinte ideas nuevas — 25 de septiembre de 2026

*Todas salen de algo medido esta noche o del repaso de hoy. Cada una lleva el dato al lado y
de dónde se saca. Ninguna está implementada todavía: es la lista para la siguiente tanda.*

---

## Las que arreglan algo que ya está pasando

### 1. Nova no sabe si se la está viendo

**Lo medido:** con *A Way Out* en pantalla completa exclusiva, la cápsula estaba en **z=0, por
delante del juego, visible y bien colocada** — y no se pintaba ni un píxel. La prueba de que el
juego estaba en exclusiva: el panel es **1920×1080 nativo** y el escritorio estaba a
**1280×720**; sólo el modo exclusivo cambia la resolución del escritorio.

**El problema de fondo:** Nova estuvo media hora enseñando cosas a nadie. Y eso choca con la
regla 2 de la casa — ningún modo sin al menos dos salidas.

**Qué haría:** comparar la resolución del escritorio con la nativa del panel en cada vuelta del
vigilante de juego. Si no coinciden y hay un juego delante, marcar `capsulaCiega` en el estado.
Con esa marca puesta, lo que hoy va sólo a la cápsula (el pulso, el nivel, los avisos de nivel
"bajo") pasa a vibración del mando o a voz, según lo que ya diga `Test-AvisoSinVoz`.

**Coste:** dos llamadas a la API de Windows cada 30 s. Nada.

---

### 2. Veintiséis bombas de relojería repartidas por los bancos

**Lo medido:** **28 expresiones con distancia fija en caracteres** (`[\s\S]{0,900}`, `{0,1200}`,
`{0,500}`…) repartidas en **12 bancos**. Esta madrugada **dos de ellas se pusieron rojas con el
código perfectamente bien**, sólo porque añadí un comentario dentro del bloque que miraban.
Quedan **26**.

**Qué haría:** cambiarlas por lo que ya funciona en `probar-log` y `probar-guia` desde esta
noche — recortar el bloque por sus límites reales (`IndexOf` de la primera línea hasta su
cierre), quitarle los comentarios y comprobar que dentro están las piezas, **en cualquier orden
y a cualquier distancia**.

**Por qué importa más de lo que parece:** un banco que se pone rojo solo entrena a ignorarlo.

---

### 3. El perfil está lleno: 60 de 60

**Lo medido:** `memoria\perfil.md` tiene exactamente **60 líneas** y el tope es 60
(`$PerfilMax`). Se han aprendido **91 datos distintos** y sobreviven **60**; el resto ha
desaparecido — y no todos por el tope: a alguno lo borró un *"olvida que…"* o un filtro
posterior, pero **el tope es el único que tira sin mirar qué tira**. Entre los perdidos están
**los dos únicos que enseñaste a mano** — *"mi juego favorito es Hollow Knight"* y *"mi color
favorito es el verde"* —, y hoy no queda **ni un solo** dato marcado como dicho por ti.

**Y la lápida todavía no existe:** `memoria\perfil-caidos.md` se creó el 24/09 para apuntar lo
que se cae, pero **no hay fichero**, porque no ha habido ninguna poda desde entonces. El perfil
llegó a 60 justo ahora: **el próximo dato que aprenda expulsará a otro**.

**Qué haría:** dos cosas distintas. Una, que lo que **tú enseñas a mano** no compita en la misma
cola que lo que ella deduce — que tenga su propio espacio y no se pode nunca. Y dos, avisar una
sola vez cuando el perfil llegue al tope, que es ahora.

---

### 4. Veintitrés de esos sesenta no son rasgos tuyos

**Lo medido:** el propio código lo reconoce: 23 de los 60 son **estados pasajeros** guardados
como si fueran rasgos permanentes — *"está en una llamada"*, con su fecha. Hay una guarda nueva
del 24/09 (`Test-DatoPasajero`) que impide que entren más, pero **no limpia los que ya están**.

**Qué haría:** pasar la guarda nueva por las 60 líneas una sola vez y proponerte la limpieza
—sin borrar nada sin decirlo—. Son 23 de 60: liberarías más de un tercio del perfil, que está
lleno (idea 3).

---

### 5. Los avisos que te prometió y perdió

**Lo medido:** **3 avisos caducados sin decirse** desde que existe esa línea (24/09 01:38) —
`oido-ruido`, `gmail-lleno`, `disco-poco`. Dos de ellos, esta misma madrugada a las 23:52 y
23:53.

**El detalle que lo hace feo:** esos avisos existen *precisamente* porque Nova decidió no
molestarte en su momento y se prometió decírtelos cuando volvieras. Caducan en silencio.

**Qué haría:** cuando uno esté a punto de caducar sin haberse dicho, o se dice aunque sea tarde,
o se junta con los demás en una sola frase ("mientras no estabas: el disco, el correo"). Nunca
desaparecer callando.

---

### 6. La resolución no vuelve sola

**Lo medido:** cerraste *A Way Out* a las **00:01:13** y veinte minutos después el escritorio
**seguía a 1280×720** con el panel a 1920×1080.

**Qué haría:** Nova ya detecta el cierre del juego ("JUEGO: cerrado de verdad"). Que en ese
momento compare la resolución con la nativa y, si no coincide, te lo diga — *"el juego te ha
dejado la pantalla a 720p, ¿la subo?"*. Restaurarla sola sin preguntar no, porque en una
portátil bajar la resolución a veces es deliberado, para batería.

---

## Las que convierten un número inventado en un número medido

### 7. El 15 % de batería nunca se ha validado — y se están guardando los datos para hacerlo

**Lo medido:** `$BateriaAviso = 15`. Su propio comentario admite: *"por eso aquí NO se cambia el
15: sólo se empieza a apuntar"*. Y desde entonces se guarda `cargador-puesto` en las
estadísticas… **que no se lee en ningún sitio**. Los datos llevan días acumulándose para un
cruce que nunca se escribió.

**Qué haría:** el cruce. Para cada aviso de batería, mirar cuántos minutos tardaste en enchufar.
Si siempre enchufas antes de que salte, el umbral sobra; si te pilla sin batería, va tarde.

---

### 8. El silencio nocturno es fijo, y en el mismo fichero hay uno adaptativo

**Lo medido:** `$EntornoNocheDesde = 23`, `$EntornoNocheHasta = 8`. En el **mismo archivo**
existe `Get-HoraFinHabitual`, que calcula de tus hábitos a qué hora sueles apagar — y se usa
para otra decisión.

**Qué haría:** que la ventana de silencio salga de esa misma función. Si te acuestas a las 2, un
silencio que empieza a las 23 te calla tres horas útiles.

---

### 9. El brillo por hora es una tabla escrita a mano

**Lo medido:** 80 % / 60 % / 40 % / 60 % / 25 % según la franja horaria. Cinco números sin una
sola medición detrás.

**Qué haría:** aprenderlos. Cada vez que cambies el brillo a mano, apuntar la hora y el valor;
a las pocas semanas la tabla es tuya y no mía.

---

### 10. La confianza mínima del oído: 0,65 sin validar

**Lo medido:** `$EscuchaConf = 0.65` decide cuántas veces Nova te oye al llamarla. Con un
**70,4 %** de comprensión medida, ese número es de los que más pesan — y nunca se ha barrido.

**Qué haría:** el barrido ya se puede hacer sin ti: hay grabaciones reales en `pruebas\audio\uso`.
Pasar las mismas con 0,55 / 0,60 / 0,65 / 0,70 y quedarse con el que más aciertos da sin subir
las activaciones solas.

---

## Las que le dan autonomía sin riesgo

### 11. Pregunta antes de cerrar juegos que ella misma ha detectado colgados

**Lo medido:** al detectar juegos "zombis" (colgados gastando CPU) pregunta antes de cerrarlos.

**Por qué sobra la pregunta:** un juego zombi no tiene partida que perder — está colgado. Es de
los pocos casos donde el riesgo real de actuar es menor que el de no actuar.

---

### 12. Y antes de borrar un único candidato exacto

**Lo medido:** al borrar un archivo pregunta siempre, **incluso cuando hay un solo candidato y
coincide exactamente** con lo que dijiste.

**Qué haría:** mantener la pregunta cuando hay varios candidatos o el parecido es aproximado —
que es donde está el peligro de verdad — y quitarla cuando la coincidencia es exacta y única.
Esto **sí** toca la regla 1, así que iría con "deshacer" durante diez segundos.

---

### 13. Las propuestas de hábito siempre preguntan, y nunca aprenden de tu respuesta

**Lo medido:** cuando detecta un patrón sólido (misma orden, misma hora, tres días seguidos) te
propone automatizarlo — **y vuelve a preguntar la próxima vez igual**, aunque le hayas dicho que
sí cinco veces.

**Qué haría:** que la respuesta cuente. Si aceptas tres propuestas del mismo tipo, la cuarta se
aplica y se avisa después. Y si rechazas tres, deja de proponer ese tipo.

---

### 14. Una frase que ya rechazaste vuelve a proponerse

**Lo medido:** `Test-Rechazada` detecta que ya dijiste que no a esa frase… **y vuelve a
preguntar**.

**Qué haría:** que un "no" valga para siempre en esa frase exacta, como ya pasa con las
traducciones corregidas.

---

## Las que la hacen sentir menos de cartón

### 15. Su humor dura dos minutos y se pierde al reiniciar

**Lo medido:** los estados *contenta* (late 20 % más rápido) y *cauta* (15 % más lento) viven
**sólo en la cápsula**, duran **2 minutos** y **no se guardan**. Un reinicio y se acabaron.

**Qué haría:** que el humor sobreviva al reinicio, y que dure lo que tenga que durar. Si te ha
entendido mal cinco veces seguidas, que siga cauta cuando vuelva, no que resucite optimista.

---

### 16. Sabe que tienes un apodo y no lo usa nunca

**Lo medido:** en el perfil hay *"tiene un apodo o nombre especial"*. Y no encontré **ni un solo
sitio** donde Nova te llame por él. El dato está guardado y muerto.

---

### 17. Lo que sonaba y a qué jugaste no deciden nada

**Lo medido:** `musica.json` (12 canciones) sólo sirve para contestar *"¿qué sonaba antes?"*.
`juegos.json` (6 juegos con sus minutos) sólo para *"¿cuánto he jugado?"*. Ninguno de los dos
influye en **ninguna** decisión.

**Qué haría:** lo obvio y barato — que sepa que llevas tres días seguidos con el mismo juego, o
que la canción que pediste ya la pusiste ayer. No hace falta nada listo: basta con leer lo que
ya está escrito.

---

### 18. Lo que habláis se borra cada día

**Lo medido:** cada turno se guarda en bruto en `cerebro\charla-AAAA-MM-DD.jsonl`, y al día
siguiente el modelo local lo resume en viñetas y **borra el bruto**. Las palabras exactas no
sobreviven 24 horas.

**Qué haría:** conservar en bruto lo que tenga marca de haber importado — donde te reíste, donde
te enfadaste, donde te dijo algo que guardaste. El resto que siga resumiéndose.

---

## Las dos de método

### 19. Un banco que impida que vuelva a colarse un worker sin protección

**Lo medido:** `voz_windows.py` estuvo **trece días** sin ninguna de las dos protecciones que
tienen los otros tres workers, y nadie se enteró hasta que había 44 procesos vivos comiendo
1,3 GB.

**Qué haría:** un banco que liste **todos** los procesos residentes que Nova arranca y exija que
cada uno tenga una de las dos cosas: o lee órdenes por su entrada estándar (y muere cuando se
cierra la tubería), o recibe `NOVA_PID_PADRE`. Si aparece uno nuevo sin ninguna, rojo. Así el
fallo no puede repetirse con el siguiente worker.

---

### 20. La lista de procesos que se matan al salir se amplía a mano

**Lo medido:** esa lista ha crecido **tres veces** en cuatro días — `piperProc` el 21/09,
`guiaProc` y `vozWinProc` el 24/09 —, y cada vez fue porque alguien descubrió que faltaba uno.

**Y hay una segunda factura, que se pagó esta madrugada:** al meter el quinto, **tres bancos se
pusieron rojos a la vez** con el código perfectamente bien. Uno exigía que `piperProc` fuera el
**último** de la fila (comprobaba `"…, $script:piperProc)"`, con el paréntesis pegado); otro
medía la distancia en caracteres hasta el `foreach`; el tercero pedía que dos líneas fueran
**adyacentes**. Los tres estaban atados a la *forma* de la lista, no a lo que hace.

**Qué haría:** que la lista **se construya sola** recorriendo las variables `$script:*Proc` que
existan, en vez de escribirse a mano. Lo que hoy es un descuido posible pasaría a ser imposible
— y de paso, los bancos dejarían de tener nada a lo que atarse mal.

---

*Las veinte salen de mediciones de hoy y de esta madrugada. Las que dicen "lo medido" se pueden
volver a sacar: `grep`, `git log -S`, el registro y los ficheros de `memoria\`.*
