# Diez ideas nuevas para Nova (22/09/2026, segunda tanda)

Las diez primeras están cerradas y los 24 pendientes también, así que estas son las
siguientes. Salieron de tres rondas de agentes peinando tus datos, y **cada una pasó por un
escéptico que intentó tumbarla**. De 61 propuestas sobrevivieron estas diez.

Las **ocho** que no llegaron cayeron casi siempre por lo mismo: un número inflado o algo que
Nova ya hacía. Eso también es información y está al final.

Las diez tienen **riesgo de orden equivocada: ninguno**. Y ocho de las diez son *pulir*.

---

## 1. No repasar lo que ya vas a tirar

**El número:** 328 peticiones de repaso en el log. **210 acabaron en «sigo con lo de
Parakeet»** — el 67 %. Filtrando a lo que Parakeet ya oyó como español de más de 8 palabras:
**148 de 328 repasos (45 %)**, 474 s de reloj y **432 s en los que Nova estaba sorda** a lo
siguiente que le decías. Órdenes perdidas si se salta: **cero**, siguiendo la cadena entera
(small y turbo incluidos).

Cuando dices una parrafada, Parakeet la oye bien y Nova la manda a repasar igualmente. El
repaso tarda, y al final se usa lo de Parakeet.

**Lo que faltaba**, y es la mitad del arreglo: si solo se salta el repaso, la frase cae tres
líneas después en el oído fino, que es cuatro veces más lento. Hay que cerrar esa puerta
también (`$script:yaReintentado`, que se borra solo en cada dictado: no es un modo).

**Gana:** 7,0 s de mediana por parrafada, 18,4 min en el log. Y ~90 llamadas menos a Gemini
con conversación privada dentro.
**Dónde:** `assistant.ps1:19509`, reutilizando `Test-EspanolLargo` (línea 715).

---

## 2. Abrir el audio antes de hablar

**El número:** el escéptico lo midió 120 veces y **corrigió mi cifra al alza**: abrir el mp3
tarda **464 ms**, no 298. Con el fichero abierto por adelantado: **31 ms**. Son **433 ms por
frase**, 599 frases en el log = **259 segundos**.

Y lo revelador: **309 de esas 599 frases ya estaban sintetizadas** (2 ms). O sea que en más de
la mitad de las veces, abrir el fichero **es el 99 % del retraso** — 150 veces más que generar
la voz.

El propio código ya sabía esto y lo compensaba en vez de arreglarlo: `assistant.ps1:11691`
suma +450 ms y `nova_ui.cs:2976` resta 300 ms para que la boca no vaya adelantada. Un
comentario del 17/09 ya decía «Open() tarda 453-547 ms».

**Gana:** Nova empieza a sonar medio segundo antes, siempre. Y desaparece el apaño de
+450/−300.
**Ojo:** ese +450 es también la ventana de sordina. Hay que ajustarla a la vez o Nova se
oiría a sí misma.

---

## 3. La cápsula se queda muda justo cuando más falta hace

**El número:** 328 repasos, mediana 3,0 s, p90 10 s, **máximo 35 s**, 1.586 s en total. 194
de los 328 pasaron de 3 segundos.

Cuando Nova no te entiende y manda a repasar, `assistant.ps1:17199` hace `Set-UI 'pensando'`
**sin texto** — y eso *borra* de la cápsula la frase que acababa de estar ahí. Resultado: «no
te he entendido» se ve exactamente igual que «estoy pensando»: tres puntitos y nada.

Lo llamativo es que los tres caminos hermanos **sí** ponen etiqueta: «Afinando el oído»,
«Pensándolo mejor». A este se le olvidó.

**Gana:** ver *qué creyó oír* es lo que te deja cortar antes de que salga la orden
equivocada. Coste: una cadena de texto.
**Dónde:** `assistant.ps1:17199`, copiando lo que hacen las líneas 17237, 18309 y 18558.

---

## 4. La onda verde sigue moviéndose cuando ya no te oye

**El número:** 412 veces medidas de «cerró el micro» a «texto listo»: media 3,48 s, p90 7 s,
**máximo 37 s**, 1.434 s en total. Y 54 veces el texto **no llegó nunca** (media 38,9 s hasta
que saltó la red de seguridad).

Cuando dejas de hablar, el micro se cierra y Nova se pone a transcribir. Pero la cápsula sigue
con la onda verde animada y los ojos atentos: te está diciendo «sigue, te escucho» cuando ya
no oye nada.

**Gana:** el único momento en que la cápsula miente. Sabrías al instante si repetir o esperar,
y en los cuelgues de 40 s lo verías a los 2. **Cero palabras habladas**: solo la onda que se
apaga.
**Dónde:** una marca en `wake_vosk.py` entre la línea 3202 y la 3228, como ya se hace con
`dictado-voz.txt`.

---

## 5. Save-Traducciones convierte lo aprendido en basura

**Esto no es una mejora: es un fallo activo, y está reproducido con tu fichero.**

El agente copió tu `traducciones.json` real (5 entradas), vació la RAM y llamó a
`Add-Traduccion` **una vez**. Las cinco quedaron así:

```
"t": "@{t=cierra administrador de tareas; usos=0}"
```

**5 de 5 destruidas con un solo «aprende».** La causa: `assistant.ps1:5830` relee el disco con
`[string]$pD.Value`, que es como se leía el formato **viejo**. Desde el 22/09 a la 01:09 el
fichero se escribe en el formato nuevo `{t, usos}`, y ese `[string]` saca la representación
del objeto entero en vez del texto.

**Gana:** evita que un día cualquiera tus traducciones se conviertan en cinco órdenes
ilegibles que Nova intentaría ejecutar. Eso es exactamente una orden equivocada.
**Primer paso:** el caso al banco `probar-traducciones-perdidas.ps1` — dará MAL —, y entonces
arreglar la línea.

---

## 6. Lo que pides sobre cómo hablarte se cae por antigüedad

**El número:** 92 datos aprendidos en el perfil, **36 ya no están**. Entre los caídos:

- «Braya prefiere respuestas concisas» (15/09 11:45)
- «le gusta ir directo al grano» (15/09 15:00)
- «Prefiere comunicación directa y clara» (16/09 11:xx)

Las dos listas donde Nova guarda cómo eres podan **por lo más viejo**, no por lo que sirve. Y
como lo viejo son las preferencias que dijiste una vez y lo nuevo es la charla de anoche, el
efecto es el contrario del que hace falta: se queda «vio una casa con fuego» y se cae «sé
breve».

Peor: el estilo del cerebro compara duplicados por **texto exacto**, así que cinco formas de
decir «no me llames tío» ocupan cinco de las doce plazas. Y esa lista viaja entera en el
prompt de **todas** las charlas, contradiciéndose: dice «tuteo, man» y «confianza (tío)»
primero, y «no usar man» y «sin usar tío» después.

**Gana:** que las dos cosas que más repites dejen de caerse solas.

---

## 7. La barra de espera miente

**El número:** la tabla de `assistant.ps1:15084` está escrita a mano
(`pregunta=4000, traducir=2500, plan=3000...`). Contra las 141 líneas `TRABAJO` reales:

| modo | dice | tarda de verdad |
|---|---:|---:|
| plan | 3,0 s | **1,5 s** (n=15) |
| pregunta | 4,0 s | **5,7 s** (n=11, máx 7,6) |

En los planes la barra pinta el 50 % cuando ya ha terminado. En las preguntas se queda clavada
al final esperando. Y el comentario de al lado ya avisaba: *«si miente, la barra no sirve de
nada»* — y otro decía *«el plan aún tiene 0 ejecuciones y no hay mediana real que copiar»*.
Ahora hay 15.

**Gana:** es la línea que miras mientras esperas, en los dos caminos más frecuentes. Y es
exactamente lo que pediste: que el número lo ponga ella.

---

## 8. El banco se traga sus propios errores

**El número:** `probar-todo.ps1` tiene **104** subidas del contador de fallos y **98 son la
misma línea muda** sin un solo mensaje. **Ninguna guarda el nombre de la sección**, así que el
veredicto solo puede decir «3 comprobaciones con problemas» — nunca cuáles.

Y hay algo peor: la sección 7, que debería cazar los bancos que mueren por una excepción, busca
**un solo patrón** (`CommandNotFoundException`). Cualquier otra excepción pasa, la sección se
pinta **en verde** diciendo «todos los bancos ejecutan de verdad lo que dicen»… y la línea
siguiente **borra el fichero de errores**. El único rastro del fallo se destruye en la misma
pasada que lo produjo.

**Gana:** «problemas en: 2n17, 2n40, 4» en vez de un número. Se acabaron las rondas de hasta
104 reejecuciones a ciegas.

---

## 9. La pregunta de alias: 5 veces, 0 aciertos, 1 envenenamiento

**El número:** 5 preguntas en 11 días, **0 aprendidas**, 4 noes explícitos… y **1 que sí se
aceptó y metió `"ajutos": ""` en commands.json**.

Sí: esa pregunta es exactamente por donde entró el fallo que arreglamos anoche. Nova te
interrumpe con «¿quieres que X sea siempre Y?» y el filtro de qué palabra vale es una lista
fija de 34 palabras comunes; cualquier palabra castellana que no esté ahí pasa.

Las cinco: `ponga → spotify` (no), `google → edge` (no), `cancion → spotify` (no), la **misma
51 segundos después** (no), y `ajutos → ajustes` (sí, y rompió el vocabulario).

**Gana:** cinco interrupciones menos y, sobre todo, cierra la puerta por la que una orden mal
oída envenena el vocabulario para siempre. 0 de 5 es el ritmo real.

---

## 10. El «mientras no estabas» que no se apaga

**El número:** **1.126 líneas** «RESUMEN AL VOLVER» el 21/09 — 97 KB, el **25 % de todo lo que
se escribió ese día**. De ellas, **774 vienen de una sola notificación** de XBOX Game Bar
Widgets, repetida cada 30 segundos durante **6 horas y 27 minutos**.

La función se rearma cada 30 s mientras lleves 2 h sin hablarle, sin que nadie la consuma. La
función hermana (el parte de la mañana) **ya tiene la guarda que a esta le falta**.

**Lo que el escéptico rechazó**, y con razón: tirar notificaciones viejas solas (20 de 36 son
de Discord, o sea personas) y una lista negra de apps de sistema a mano (3 casos en 13 días, y
choca con lo de «todo ajustable por ella»). **El arreglo bueno es el que no se propuso**: la
guarda de idempotencia, copiando la de `Test-ParteManana`.

---

## Si hubiera que elegir tres

**La 1, la 2 y la 5.** Las dos primeras son los dos trozos de espera más gordos que quedan
(7 s por parrafada y medio segundo en cada frase que dice), y la quinta no es una mejora sino
una bomba con la mecha encendida: el día que Nova aprenda una traducción, se lleva las cinco
que ya tenías.

## Lo que cayó, y por qué

Ocho propuestas no pasaron el filtro. Los motivos, por si vuelven a aparecer:

- **Canary fuera de la cascada** — el núcleo se confirma (8 corridas, 0 rescates) pero el
  número estaba inflado y la conclusión no se sostenía con tan pocos datos.
- **Cargar Whisper en un hilo** — abría vía de orden equivocada y rompía el caso del juego.
- **Detectar antes que el worker murió** — solo tocaba el 26 % del tiempo perdido, y la
  mayoría de esas muertes las provoqué yo desarrollando.
- **Una puerta de presencia para los avisos** — circular: si Nova no te oye por el ruido, no
  hay señal de presencia, así que nunca avisaría de que no te oye.
- **El parte de la mañana a una hora que no sea fija** — la función que iba a usar no sabe si
  estás o no.
- Y tres más por números que no aguantaron el recuento.

---

## APENDICE (22/09, de noche): el primer dia del aviso de ruido, contado

La idea 5 de la tanda de la manana -«avisar cuando no oye»- se estreno hoy. Al mirar su
primer dia entero salio esto:

**25 avisos identicos, de 08:00 a 20:20.** Son **25 de los 37** avisos de entorno de dos
dias enteros, y de nivel 'medio', o sea que se DICEN en voz alta. El reposo estaba en 30
minutos, y el comentario que hay tres lineas mas arriba en el codigo decia exactamente lo
contrario de lo que hacia el numero: «un ventilador puede estar sonando toda la tarde y eso
no son ganas de que te lo repitan».

**Y era un ventilador.** braya lo dijo al ver el dato: «estaba delante del ventilador, debe
de ser por eso». O sea que el aviso acerto en el fondo -habia ruido constante de verdad,
suelo de 0,0863 contra los 0,0046 de una habitacion callada- y fallo en lo unico que le
quedaba: **cuantas veces**. Si el ruido es algo que estas usando a proposito, la primera vez
es informacion y las veinticuatro siguientes son una molestia.

**El arreglo no es bajar el numero, es cambiar de limite.** El reloj deja de mandar y manda
el estado: se dice **una vez por episodio** y no se vuelve a decir hasta que el oido este
limpio un buen rato (15 min, `entorno.ruidoRearmeMinutos`) y el ruido vuelva. El reloj se
queda de red de seguridad y pasa de 30 a 120 minutos. Es la misma guarda de idempotencia
que la idea 10 de esta tanda, en otro aviso que se rearmaba solo.
Corrido contra las 12 horas de ruido de hoy: **1 aviso, no 25**.

**Y un segundo fallo que se vio tirando del mismo hilo:** el detector de ruido mira si casi
todos los bloques pasan la puerta, y **el sonido de los altavoces los pasa igual que un
ventilador** -musica, un video, un juego, o la propia voz de Nova-. La rama del ruido va
ANTES que la de los altavoces en el bucle de la escucha, asi que se lo quedaba ella.

El dato, dicho con precision: a las **20:57-20:59**, con musica sonando a 0,23-0,58 de nivel
de salida, entraban **41 a 56 bloques de 60** por la puerta, y el liston del ruido son 55.
La musica llega sola a un pelo de marcarse como ruido de fondo. **No se puede senalar un
pulso concreto de hoy** -escribi antes que el de las 20:32:52 lo era, y no me consta: esa
linea no guardaba el nivel de salida, que es justo por lo que ahora lo guarda-. Contado asi,
Nova le dice a braya que quite un ruido que ha puesto el, y que ella ya sabia que estaba
sonando. Ahora el campo que alimenta el aviso solo se enciende con lo que **no** es
ni su voz ni sus altavoces; la calibracion de la ganancia no se toca, que esa si trata los
dos casos igual a proposito y esta medida. El pulso, ademas, deja escrito el nivel de
salida: hoy habia 2.853 pulsos de ruido y ni uno decia si sonaba algo.
