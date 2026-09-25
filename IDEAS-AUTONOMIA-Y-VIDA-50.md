# Cincuenta ideas para que Nova decida sola y se sienta viva

*25 de septiembre de 2026. Todo lo de aquí está medido sobre este repositorio y sobre los
quince días de registro (09/09 → 25/09, 55.562 líneas). Cada idea lleva su dato.*

---

## El diagnóstico, en tres números

Antes de las ideas, lo que encontré al medir. Son los tres números que las explican todas:

**1. Nova tiene veinte formas de tomar la iniciativa, y nueve están muertas.**

De las 20 clases de cosa que Nova puede hacer sin que se lo pidan, **9 no han disparado ni una
vez en los últimos dos días**, y cuatro de ellas **nunca**:

| Muerta | Cuánto lleva viva el código | Veces que ha disparado |
|---|---|---|
| Una **regla** ejecutándose sola | 14 días | **0** (y hoy no hay ninguna guardada) |
| Un **recordatorio** avisando al vencer | 14 días | **0** |
| El **límite de tiempo de juego** | 11 días | **0** |
| El **modo invitado** detectado solo | 11 días | **0** |
| El aviso de **batería baja** | 15 días | **1** |
| **Subir de nivel** | 12 días | 11 días sin pasar |
| La **autosordina** | 14 días | murió el 15/09 |
| Los **logros** de Steam | 14 días | murió el 20/09 |
| El **diario** del día | 11 días | **dejó de escribirse el 22/09** |

**2. Habla más por su cuenta que lo que la llamas — y cada vez más.**

309 iniciativas contra 393 veces que la llamaste. Pero la tendencia importa más que el total:

| | 11/09 | 15/09 | 19/09 | 22/09 | 24/09 |
|---|---:|---:|---:|---:|---:|
| Iniciativas suyas | 9 | 29 | 27 | 56 | 21 |
| Veces que la llamaste | 120 | 28 | 7 | 7 | **1** |
| **Proporción** | 0,07 | 1,04 | 3,86 | 8,0 | **21,0** |

El 24/09 habló **veintiuna veces por su cuenta por cada vez que la llamaste**. Eso no es
autonomía: es ruido de fondo. La autonomía que quieres no es *hablar* más, es **decidir** más.

**3. Sabe mucho de ti y casi nada de eso decide algo.**

60 datos en tu perfil (**lleno, 60 de 60**, de 91 aprendidos), 111 recuerdos en su cerebro, 12
canciones, 6 juegos con sus horas, 34 órdenes repetidas, 27 marcas de a qué hora hablas. De todo
eso, lo único que **decide** algo es `habitos.json`. El resto sólo sirve para contestar
preguntas.

---

## A. Resucitar lo que ya tiene y no usa (1–8)

### 1. Que las reglas se propongan solas
**El dato, y es más crudo de lo que parecía:** `memoria\reglas.json` **no existe**. Ahora mismo
hay **cero reglas guardadas**. En el registro hay 1.094 líneas de "REGLA N guardada", pero son
casi todas de los bancos probando el mecanismo; frases de regla dichas de verdad: **una**, en
quince días. El mecanismo funciona —se probó de punta a punta el 24/09— y está vacío.
**La idea:** que Nova proponga la primera regla ella misma, sacada de lo que ya ve: *"llevas
tres días poniendo el modo juego al abrir Steam, ¿lo hago yo?"*. Una regla que existe es la
diferencia entre un mecanismo y una costumbre.

### 2. Recordatorios que nazcan de la conversación
**El dato:** `recordatorios.json` tiene **2 bytes**: está vacío. 14 días, 0 disparos.
**La idea:** que detecte los "luego lo hago" y los "recuérdamelo" que ya aparecen en las charlas
y ofrezca convertirlos, en vez de esperar a que digas la frase exacta.

### 3. El diario dejó de escribirse y nadie se enteró
**El dato:** 10 notas de diario entre el 10 y el 21/09, y **ninguna desde el 22**. Tres días de
silencio sin que salte nada.
**La idea:** que Nova vigile sus propias costumbres. Si algo que hacía todos los días deja de
pasar tres días seguidos, que lo diga. Es el mismo principio que aplica a tu batería, aplicado a
ella misma.

### 4. Los logros de Steam, muertos desde el 20/09
**El dato:** 5 logros detectados en total, ninguno en cinco días.
**La idea:** comprobar si es que no juegas a nada con logros o si el sensor se rompió. Y si
funciona, que celebre de verdad: un logro raro (menos del 5 % de jugadores) merece más que un
pulso en la cápsula.

### 5. La autosordina se olvidó de existir
**El dato:** 5 veces, todas entre el 12 y el 15/09. Diez días sin usarse.
**La idea:** revisar si su condición de disparo sigue siendo alcanzable. Una capacidad que deja
de dispararse sin que nadie la apague suele ser una condición que ya no se cumple nunca.

### 6. El límite de tiempo de juego que nunca avisó
**El dato:** fijaste un límite el 14/09. **0 avisos en 11 días.**
**La idea:** averiguar por qué. O el límite era muy alto, o el contador se reinicia, o el aviso
cae dentro del silencio de juego. Cualquiera de las tres es un fallo.

### 7. Los treinta temas que ya conoce, y que no usa para nada
**El dato:** el cerebro tiene **30 de 30 temas** (tope lleno): `comunicacion` 21 veces, `steam`
9, `clarificacion` 10.
**La idea:** que el tema sirva para algo. Si el 70 % de lo que le preguntas es de comunicación,
que cargue antes lo que hace falta para eso.

### 8. La lápida del perfil que todavía no existe
**El dato:** `perfil-caidos.md` se creó el 24/09 y **no hay fichero**, porque el perfil llegó a
60 justo ahora. El próximo dato que aprenda tirará otro.
**La idea:** que avise **antes** de tirar algo, no después. *"Para aprender esto tengo que
olvidar aquello, ¿te parece?"* — una vez, no cada vez.

---

## B. Decidir sin preguntar, con red (9–16)

*La regla 1 de la casa dice que Nova puede fallar en entender pero no ejecutar lo que no se le
pidió. Estas ocho respetan eso: todas actúan sobre algo que ya está decidido o es reversible.*

### 9. Cerrar juegos colgados sin preguntar
**El dato:** hoy los detecta (sabe que están zombis, gastando CPU) y **pregunta**.
**La idea:** un juego colgado no tiene partida que perder. Cerrarlo y avisar después.

### 10. Deshacer en vez de preguntar
**La idea general, y es la que más cambia:** cuando la acción es reversible, **hacerla y ofrecer
deshacer durante diez segundos** en lugar de preguntar antes. Convierte doce preguntas en doce
acciones con red.

### 11. Aprender de tus síes
**El dato:** las propuestas de hábito **siempre preguntan**, aunque hayas dicho que sí cinco
veces al mismo tipo de propuesta.
**La idea:** tres síes seguidos del mismo tipo → la cuarta se aplica y se avisa. Tres noes → deja
de proponerlo.

### 12. Que un "no" dure
**El dato:** `Test-Rechazada` sabe que ya dijiste que no… y **vuelve a preguntar**.
**La idea:** un no a una frase exacta vale para siempre, como ya pasa con las traducciones.

### 13. Los alias, directos
**El dato:** para aprender que "calcu" es "calculadora", pregunta.
**La idea:** aprenderlo y decirlo. *"Apunto que 'calcu' eres tú diciendo calculadora."*

### 14. Escalones en la duda de voz, en vez de una pregunta única
**El dato:** la misma pregunta de "¿esta voz es la tuya?" se dispara en **7 sitios distintos**,
todos con el mismo umbral, sin importar si la acción es abrir una calculadora o apagar el PC.
**La idea:** que el escalón dependa del daño. Una acción inocua con voz dudosa se hace; una
peligrosa se pregunta.

### 15. La nube, sin permiso, cuando la duda es grande
**La idea:** ya decide sola cuándo consultar la nube; que además decida **cuándo no merece la
pena** por el estado de la red, en vez de gastar el plazo entero.

### 16. Un presupuesto de autonomía en vez de un permiso por acción
**La idea:** darle un cupo — *"puedes hacer hasta N cosas reversibles al día sin preguntar"* —
y que ella elija en qué gastarlo. Es más parecido a confiar en alguien que a autorizar cada
paso.

---

## C. Aprender de lo que ya guarda (17–24)

### 17. Validar el 15 % de batería con los datos que ya lleva días guardando
**El dato:** se guarda `cargador-puesto` desde el 18/09 **expresamente** para validar ese
número, y **no se lee en ningún sitio**.

### 18. Que el brillo lo aprenda de ti
**El dato:** tabla fija 80/60/40/60/25 % por franja horaria, sin una medición detrás.

### 19. Que la noche sea la tuya
**El dato:** silencio nocturno fijo de 23 a 8, cuando en el mismo fichero hay
`Get-HoraFinHabitual`, que **sí** sale de tus hábitos.

### 20. Saber qué juego te gasta la batería
**El dato:** `juegos.json` tiene 6 juegos con sus minutos, y sólo sirve para contestar *"¿cuánto
he jugado?"*.
**La idea:** cruzarlo con el gasto de batería que ya mide. *"Con este juego te quedan 50 minutos,
con el otro hora y media."*

### 21. La música que ya pusiste
**El dato:** 12 canciones guardadas, cero influencia en nada.
**La idea:** que sepa que eso ya sonó ayer, y que sepa qué sueles poner a cada hora.

### 22. Los cuatro contadores que no lee nadie
**El dato:** `cargador-puesto`, `llamada-en-juego`, `toque-corto`, `aviso-caducado` se escriben
y **no se leen jamás**.
**La idea:** o se usan para decidir algo, o se dejan de escribir. Guardar por guardar es deuda.

### 23. Aprender de cuándo te callas tú
**El dato:** hay 27 marcas de a qué horas hablas (`charlaHoras`) y se usan para una sola cosa:
decidir si precargar el modelo local.
**La idea:** que también decidan **cuándo hablar ella**. Sus picos de avisos son a las 22h y las
20h; tus picos de hablarle, a las 19h y las 15h. No coinciden.

### 24. Que mida si sus avisos sirven
**El dato:** 82 avisos hablados, de los cuales **32 son del mismo tipo** (ruido en el oído) y 20
de otro (batería llena). Dos tipos se comen el 63 %.
**La idea:** apuntar qué haces después de cada aviso. Un aviso que nunca cambia tu conducta es
un aviso que sobra — y ahí tiene 32 candidatos del mismo tipo para mirar.

---

## D. Iniciativa con criterio, no más ruido (25–32)

### 25. Hablar menos y decidir más
**El dato:** el 24/09 habló 21 veces por su cuenta por 1 vez que la llamaste.
**La idea:** el presupuesto de voz que ya existe debería gastarse en lo que **te cambia el día**,
no en lo que le resulta fácil detectar. Ordenar los avisos por utilidad medida (idea 24), no por
orden de llegada.

### 26. Juntar en vez de gotear
**El dato:** 6 avisos de "hora de dormir", 6 de disco, 4 de gmail — repartidos.
**La idea:** una sola frase al volver con todo junto, como ya hace el parte de la mañana.

### 27. Elegir el momento, no sólo el permiso
**El dato:** hay una zona muerta clara de **02h a 08h** — ni hablas ni te hablan.
**La idea:** que use esa ventana para lo suyo: resumir el día, podar el perfil, revisar sus
propias costumbres. Trabajar cuando no molesta es una forma de autonomía.

### 28. Terminar lo que empieza
**El dato:** 3 avisos **caducados sin decirse** desde el 24/09 a la 01:38.
**La idea:** lo que prometió decir, se dice. Aunque sea tarde y aunque sea en una frase junta.

### 29. Avisar de lo que ella misma rompe
**El dato:** el 24/09 se quedó muerta a las 21:53 y **no te enteraste hasta que yo lo vi**.
**La idea:** que al arrancar mire si la sesión anterior acabó mal (ya sabe distinguirlo: un
"iniciado" sin su "cerrado") y lo diga. *"Ayer me caí a las diez menos cuarto."*

### 30. Contar lo que hizo mientras no estabas
**La idea:** no un registro, una frase. *"Mientras jugabas bajé dos actualizaciones y me callé
cuatro avisos."* Es lo que hace que parezca que ha estado ahí.

### 31. Preguntar ella, de vez en cuando
**El dato:** aprendió **91 datos** y conserva **60**; los dos únicos que enseñaste a mano están
entre los que se cayeron, y hoy no queda ni uno marcado como dicho por ti.
**La idea:** que a veces pregunte **ella** algo concreto que le falte, una vez al día como mucho.
Un asistente que sólo responde no parece vivo.

### 32. Saber cuándo callarse del todo
**La idea:** el complemento de todo lo anterior. Detectar que estás concentrado —partida
competitiva, llamada larga, escribiendo— y **guardarlo todo** sin preguntar, como ya hace con el
juego pero con más señales.

---

## E. Memoria y continuidad (33–41)

### 33. Que el humor sobreviva al reinicio
**El dato:** *contenta* y *cauta* duran **2 minutos**, viven sólo en la cápsula y **no se
guardan**. Un reinicio y se acabó.

### 34. Que el ánimo tenga memoria larga
**El dato:** el ánimo se calcula de aciertos y errores de **hoy y ayer**. Es real (afecta al
latido y al color), pero no recuerda nada.
**La idea:** que una racha mala de una semana pese distinto que un mal rato.

### 35. Guardar en bruto lo que importó
**El dato:** la charla se guarda palabra por palabra y **se borra al día siguiente**, dejando
sólo un resumen en viñetas.
**La idea:** conservar en bruto los turnos marcados —donde te reíste, donde te enfadaste— y
resumir el resto.

### 36. Recordar dónde lo dejasteis
**La idea:** que pueda retomar una conversación de anteayer sin que se la vuelvas a explicar.
Tiene 111 recuerdos; le falta el hilo.

### 37. Los aniversarios de lo suyo
**El dato:** hay 2 resúmenes semanales escritos y nadie los lee.
**La idea:** que los use. *"La semana pasada por estas horas estabas con el mismo jefe final."*

### 38. Que note los cambios
**La idea:** con 5 días de minutos de juego y 14 de estadísticas ya puede decir *"llevas tres
días jugando menos"* o *"hoy me has llamado una sola vez"*. Notar un cambio es lo más parecido
a prestar atención.

### 39. Olvidar a propósito, y decirlo
**El dato:** la poda tira "lo que lleva más tiempo sin repetirse", en silencio.
**La idea:** que olvidar sea un acto con voz. *"Voy a dejar de acordarme de esto, que hace tres
semanas que no sale."*

### 40. Que lo que enseñas a mano no se pode nunca
**El dato:** los **dos únicos** datos que enseñaste a mano con "aprende que…" están entre los 31
perdidos.

### 41. Un hilo entre sesiones
**El dato:** las 3 últimas frases de saludo **sí** se guardan, para no repetirse. Es lo único de
continuidad que hay.
**La idea:** extender esa idea: que no repita la misma broma, el mismo consejo ni el mismo aviso
dos días seguidos.

---

## F. Carácter propio (42–50)

*Aquí hay que tener cuidado: "más viva" no es "más pesada". Todas estas van dentro del
presupuesto de voz que ya existe.*

### 42. Que te llame por tu apodo
**El dato:** sabe que tienes uno —está en el perfil— y **no lo usa ni una sola vez**.

### 43. Opiniones propias, pequeñas y con base
**La idea:** que diga lo que piensa cuando tiene dato. *"Ese juego te dura veinte minutos de
media, ¿seguro?"* No es personalidad de adorno: es usar lo que sabe.

### 44. Que tenga manías
**La idea:** tres o cuatro constantes suyas que no cambien: una hora a la que siempre está más
despierta, una cosa que siempre comenta, una palabra que usa ella y nadie más. La personalidad
es repetición, no variedad.

### 45. Que se equivoque en voz alta
**El dato:** cuando algo le falla, lo apunta en el registro y calla.
**La idea:** que lo diga alguna vez. *"Te he entendido mal tres veces seguidas, perdona."*
Reconocer un fallo hace más por parecer vivo que veinte frases ingeniosas.

### 46. Momentos del día con carácter
**El dato:** ya cambia de color y de latido de noche (23h–8h).
**La idea:** que también cambie **lo que dice**: más corta por la mañana, más larga de
madrugada.

### 47. Variar donde hoy repite
**El dato:** 5 variantes de saludo y 8 de relleno; **todo lo demás lo genera el modelo cada
vez**.
**La idea:** al revés de lo que parece — no hacen falta más variantes, hace falta que las pocas
que hay signifiquen algo. Que el saludo dependa de cómo acabó el día anterior.

### 48. Que reaccione a lo que ve, no sólo a lo que le dices
**El dato:** ya detecta el juego, la batería, el cargador, las descargas, los amigos conectados.
**La idea:** que a veces comente sin que haya nada que avisar. *"Otra vez el mismo jefe."* Una
vez al día, dentro del presupuesto.

### 49. Un gesto propio para lo que no tiene nombre
**El dato:** tiene más de 20 gestos, y los tres más usados en un día fueron duda (96), grito (81)
y negar (36) — los tres son reacciones a fallos.
**La idea:** que tenga también gestos para cosas buenas y los use tanto como los de fallo.

### 50. Que se le note cuando lleva un buen día
**El dato:** el ánimo ya cambia el color y el latido, pero **nada más**.
**La idea:** que también cambie el **cómo**: más iniciativa cuando lleva racha buena, más
prudencia cuando lleva mala. Que el estado de ánimo tenga consecuencias, no sólo aspecto.

---

## Lo que yo haría primero, si me dejas elegir

Cinco, por este orden:

1. **La 29** (avisar cuando se cayó) — porque hoy te enteraste por mí, no por ella.
2. **La 1** (proponer la primera regla) — porque desbloquea un mecanismo entero que lleva 14
   días vacío.
3. **La 10** (deshacer en vez de preguntar) — porque convierte doce preguntas en doce acciones
   sin tocar la regla 1.
4. **La 24** (medir si sus avisos sirven) — porque sin eso, "hablar más" es siempre "molestar
   más".
5. **La 42** (llamarte por tu apodo) — porque cuesta una línea y es de las que más se notan.

---

*Los números salen de: `assistant.log` + `assistant.log.1` (55.562 líneas, 09/09–25/09), los
ficheros de `memoria\`, y `git log -S` para saber desde cuándo existe cada cosa antes de
llamarla muerta.*
