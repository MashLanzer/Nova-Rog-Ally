# Nova, entera — 25 de septiembre de 2026

*Qué es, qué sabe hacer, cómo está hecha, qué se ha medido de ella y qué queda.
Escrito para leerlo de una sentada y saber en qué punto está.*

---

## 1. Qué es

Un asistente de voz que vive en el **ROG Xbox Ally** de braya y se controla **hablando o con el
gatillo `≡` del mando**, sin quitarle el primer plano al juego. Dices *"Nova"* o mantienes el
botón, hablas, y al callar ejecuta y contesta en voz alta. La cara visible es una cápsula de
cristal en una esquina.

**Las siete reglas de la casa**, que mandan sobre cualquier idea buena:

1. Nova puede fallar en entender; **no puede ejecutar algo que no se le pidió**.
2. Ningún modo sin **al menos dos salidas y un plazo**.
3. **Ningún número inventado**: cada decisión cita una medición real, y el comentario dice de
   dónde sale. Si no hay medición, se dice que no la hay.
4. **El bucle principal no se bloquea**: braya juega mientras habla.
5. **Nada residente** comiendo RAM o un núcleo que le hace falta al juego.
6. Los `.ps1` de `tools\` van **sin BOM si son ASCII puro, con BOM si llevan algo que no lo
   es** —PowerShell 5.1 lee un `.ps1` sin BOM como ANSI— y no llevan tildes ni ñ.
7. Con un **70,4 % de comprensión**, todo lo que dependa de una sola palabra necesita una
   **segunda vía** (el gamepad) o una lista cerrada.

---

## 2. De qué tamaño es

| | |
|---|---|
| `assistant.ps1` (el cerebro) | **26.863 líneas**, 532 funciones |
| `wake_vosk.py` (el oído) | 4.001 líneas |
| `charla_worker.py` + `charla_memoria.py` | 1.304 + 934 líneas |
| `ajedrez.py` | 293 líneas |
| Bancos de pruebas | **170 ficheros**, 172 secciones en la batería |
| Órdenes distintas que entiende | **162** |
| Contadores que lleva de sí misma | 49 |
| Commits | 515 |

---

## 3. Cómo te oye — la cascada

Cinco escalones, y cada uno existe porque el anterior falla de una manera concreta:

1. **Vosk** escucha el nombre. Gramática **cerrada**: ante cualquier ruido, el decodificador
   solo puede devolver una de las frases que conoce. Es lo único que corre siempre.
2. **Parakeet** transcribe la orden. Es el titular: 640 MB, el más rápido.
3. **Whisper base** repasa cuando Parakeet oyó algo que no parece una orden.
4. **Canary** es el primer escalón del repaso (`repasos: "canary,base"` en `config.json`).
5. **El oído fino** (Whisper `small`) y el **último recurso** (`large-v3-turbo`), este último
   apagado desde el 15/09.

**Las guardas que protegen la regla 1**, todas con su medición detrás:

- **Umbral de ráfaga adaptativo** (p90 de su voz × 0,85, entre 0,010 y 0,030): si lo que suena
  no tiene la energía de una voz, no es una llamada.
- **Veto por altavoces** (> 0,35): jugando, la palabra no es de fiar y solo vale el botón.
- **Confianza** que sube a 0,85 con frase larga o con los altavoces sonando.
- **Detector de ruido constante**, para no calibrar contra el ventilador.
- **Autosordina**: tres descartes seguidos y se calla diez minutos.
- **Margen de tono**: 19 rechazos porque era su propia voz.

---

## 4. Qué sabe hacer — las 162 órdenes

**La consola** — brillo, volumen (global, por app, relativo), modo ahorro, bloqueo, apagar,
suspender, monitor, resolución, salida de audio, RAM, disco, batería, energía, papelera,
capturas, lupa, siempre encima, atajos de teclado, portapapeles con historial.

**Los juegos** — abrirlos por nombre mal dicho (búsqueda fonética), cerrar el juego o todo,
saber a qué juegas y cuánto llevas, dónde te quedaste, guía del juego, clips, zombis
(procesos colgados), descargas de Steam, qué jugar con un amigo, tiempo de hoy y de la semana.

**Steam y los amigos** — biblioteca indexada, quién está conectado, vigilar a uno, elegir de
una lista con el mando, logros.

**La voz y la conversación** — charla de verdad (Haiku por API + un local pequeño), memoria de
lo hablado, "repite", "no era eso", "qué falló", velocidad de la voz, emociones.

**Lo que aprende** — perfil (60 datos con poda y lápida), recetas (aprende a repetir una tarea
sin IA), reglas ("cuando abra X, haz Y"), hábitos, palabras que le cuestan, música que no te
gusta, apodos de juegos.

**Los avisos por su cuenta** — batería, cargador, disco, correo, ruido de fondo, estar sorda,
hora de dormir, resumen al volver, parte del día, descargas terminadas.

**Y lo que no hace** — recordatorios y temporizadores, listas, notas, trivia, ajedrez, clima,
calendario, OCR de la pantalla, traducción, modos guardados, invitado.

---

## 5. Lo que se midió de ella, y lo que resultó ser

La regla 3 obliga a medir antes de tocar. Esto es lo que ha salido, **incluido lo que resultó
que yo había contado mal**:

### El oído

| | |
|---|---|
| Comprensión real | **70,4 %** de las órdenes |
| Cambiar de modelo | **no mejora** (medido el 21/09) |
| Llamarla por su nombre | 917 veces, pasaron 392 (43 %) |
| Descartes por sonar flojo | 83, en 19 rachas |
| De esas rachas, causadas por el juego | **45 de 83 descartes** con los altavoces a 0,10-0,38 |
| Audio atrasado tirado | 1.116 sucesos, 6.563 s — y **está bien**: es la ventana en que el hilo estuvo sordo |

### La voz

| | |
|---|---|
| Frases ya preparadas | 330 (2 ms de mediana) |
| Frases sintetizadas al momento | 311 (903 ms de mediana, 3,6 s la peor) |
| Tiempo que la voz bloqueó el bucle | 303,2 s en quince días = **20 s/día** |
| Sucesos perdidos durante esas esperas | **0 de 7.391** |

### Lo que se cayó al medirlo

- **"Se muere catorce veces al día"** → la línea `VoiceAssistant cerrado` no existía antes del
  18/09. Con los dos lados midiendo lo mismo: 25 muertes en 5,5 días. Y el **84 %** de los
  arranques cae a menos de 30 min de un commit: **la reinicio yo al editarla**.
- **"El resumen al volver es un widget el 62 % de las veces"** → arreglado el 22/09; cero desde
  entonces.
- **"Nueve horas analizando ruido al 100 %"** → de 15.957 pulsos, **32** están al 100 % y 9.636
  al 0 %. El oído ya se salta el decodificador seis de cada diez veces.
- **"El turbo: 2 de cada 100"** → eran **15 de 29**; en catorce impuso su transcripción porque
  era mejor. Es caro, no inútil.
- **"El filtro del repaso no funciona"** → se commiteó **quince horas después** de los casos que
  yo le achacaba. Desde que existe: 4 pedidos, 4 ahorrados, cero tirados.
- **"548 MB de modelos sin usar"** → canary se usa hoy. El único que sobra libera 0,34 GB de los
  10,7 libres y rompe tres herramientas.

**La trampa, escrita en la cabecera de la batería para que no vuelva a pasar:** antes de decir
que algo está roto, mirar **desde cuándo existe el código** —y a qué **hora** se commiteó— y
contar solo desde ahí. Un contador que cruza la fecha de su propio arreglo miente en la
dirección más cara: hacer trabajo de más sobre algo que ya estaba bien.

---

## 6. Lo que se ha arreglado hoy, 24 de septiembre

**Por la mañana, las primeras veinte** — 9 hechas, 8 medidas, 3 falsas:

- Nova avisa cuando **te oye llamarla y no te entiende** (5 avisos en 3 días, y deja fuera las
  ráfagas que eran del juego).
- Las **cinco interrupciones** que se tiraban dentro de casa: había dos ramas para tres
  situaciones, y ninguna dejaba rastro.
- La nube solo corrige si **la mitad de sus palabras** casan con lo que se oyó.
- El **plazo de la voz** sale del p99 real, no de dos números a fuego.
- Lo que **dura un rato no es un dato**: 23 de los 60 datos del perfil eran estados. Y la poda
  deja lápida, que *"qué has olvidado de mí"* lee.
- *"Estoy en una llamada"* → **sordina de diez minutos**.
- **Dice que está sorda** en vez de anunciar que escucha.
- El **latido del oído** se fue a su propio fichero: el histórico casi se dobla.

**Por la tarde, las otras veinte** — 10 hechas, 6 medidas, 2 falsas, 1 descartada, 1 ya estaba:

- Un **recordatorio con la fecha rota** ya no se borra solo y en silencio. *(Era la única
  función que promete algo a futuro, y no había sonado nunca.)*
- Nova **no habla por su cuenta más veces de las que la llamas**.
- El **parte del día** sale la primera vez que apareces, no solo por la mañana.
- El **correo** se mira una vez al día de verdad, y calla si no ha cambiado.
- Los **anuncios de YouTube** ya no entran en el historial de música.
- Una **toma saturada** ya no se manda a un agente con manos a ver si adivina.
- **Whisper carga sin cerrar el micrófono**, y el dictado espera en vez de degradar.
- Una **receta que escribe y no tiene huecos** ya no se aprende.
- El **ciclo entero de una regla**, probado por primera vez.
- Y Nova ya **no se queda ciega** con el juego en pantalla completa.

**Y de noche, tres que no encontró ningún banco** — dos los destapó un aviso de memoria
de Windows y el tercero lo contaste tú jugando:

### Los workers que sobrevivían a Nova

A las 21:53 Nova se murió de golpe mientras jugabas. Media hora después había **44 procesos
`voz_windows.py` vivos comiendo 1,3 GB**, con 0,70 GB libres y el juego usando 1,9. Regla 5 de
la casa rota. Lo destapó un aviso de memoria baja de Windows, no una prueba.

**Con la ventana temporal delante, el diagnóstico honesto:** el dictado de Windows está
**apagado** en tu configuración (`input.vozWindows = false`), así que Nova **hoy no crea
ninguno**. Esos 44 eran un **poso acumulado** de cuando estuvo encendido — y seguían ahí
porque **nada los limpiaba nunca**. Lo que se ha arreglado es un fallo **latente**: el día que
lo enciendas, vuelve a pasar.

Eran **tres agujeros a la vez**, y ninguno se veía desde el otro:

1. **El worker no miraba si su padre seguía vivo.** El oído sí lo hace desde el 13/09 — en el
   registro se lee *"el asistente ya no existe; salgo y suelto el micrófono"* —, pero el del
   dictado no tenía nada: su bucle duerme 80 ms, mira la marca y vuelve a empezar, para siempre.
2. **El cierre ordenado no lo mataba.** La lista de procesos que se matan al salir nombraba
   cuatro; él era **el único residente al que no mataba nadie**.
3. **El barrido del arranque no lo nombraba.** Esa lista se escribió el 17/09 a las 16:34 y el
   worker existe desde el 11/09 a las 23:00: no fue un desfase, fue un olvido.

**Cómo quedó:** el worker pregunta cada 2 segundos si su padre existe, y se cierra solo.
Medido: **tarda 1,5 s**. Y si nadie le dice de quién es hijo, sigue vivo — *ante la duda,
vivo*: uno que se suicidara por no saberlo te dejaría sin dictado en mitad de una partida.

*El banco no mira el código: arranca un worker de verdad, le pone un padre de mentira, mata al
padre y comprueba que el hijo se muere solo. Tuvo que ser así — la primera versión miraba el
código y daba por muerto a un proceso que estaba perfectamente vivo.*

**Y por qué era el único**, que es lo que cierra el diagnóstico: Nova lanza cuatro workers que
se quedan vivos, y los otros tres ya estaban protegidos **sin que nadie lo hubiera escrito
aposta**. El de la charla y el de la voz leen órdenes por su entrada estándar, y cuando el
padre muere esa tubería se cierra, salen del bucle y se apagan solos. El oído lleva el PID del
padre desde el 13/09. El del dictado de Windows **no hacía ninguna de las dos cosas** — es el
único que no lee nada por tubería y el único al que no se le decía de quién era hijo.

Eso explica el reparto exacto de lo que se encontró: **44 de ese, y cero de los otros tres**.

### La cápsula le robó el foco al juego

Lo contaste tú, jugando: al reiniciar Nova a las 23:33 con *A Way Out* abierto, **el juego se
quedó sin audio y la cápsula dejó de verse encima**. Medido con `GetForegroundWindow`, la
ventana de delante era `nova_ui`, no el juego — y un juego que pierde el foco se silencia.

Al principio di por hecho que eso explicaba **las dos cosas**, y no era verdad: el foco
explicaba el audio, pero la cápsula seguía sin verse después de arreglarlo. Lo de no verse
resultó ser otra cosa, y está más abajo. Conviene dejarlo escrito así: dos síntomas a la vez
invitan a buscarles una causa única, y aquí eran dos.

**El código no había cambiado** — comprobado con las fechas del `.cs` y del `.exe`. Lo que
cambió fue el **orden**: Nova suele estar arrancada antes de que abras el juego, y entonces no
hay foco que robar. El `WS_EX_NOACTIVATE` sí estaba, pero se aplicaba en `Loaded`, que corre
**después** de pintar la ventana: para entonces el foco ya estaba robado.

Ahora lleva **`ShowActivated = false`** — la propiedad de WPF hecha justo para esto — y los
estilos se ponen también en `SourceInitialized`, antes del primer fotograma. Y aparte, el
**"ducking" de Windows**: lo tenías sin definir, y el valor por defecto **baja el resto de
sonidos un 80 %** cuando una app abre el micrófono — y Nova lo tiene abierto siempre. Puesto en
*no tocar nada*.

*Su banco comprueba algo que ningún otro miraba: que el `.exe` se haya compilado **después**
del `.cs`. El binario va versionado, así que se puede arreglar el código y dejar corriendo el
de antes. Y la parte que de verdad lo prueba — arrancar una segunda cápsula y mirar quién se
queda con el foco — **se salta sola si hay un juego delante**, para no meterte una ventana en
la pantalla mientras juegas; se corrió con el escritorio libre a las 00:12 y pasó: el foco se
quedó donde estaba.*

### Y escribiendo en tu disco siete veces por segundo

Buscando lo anterior apareció esto en el registro: **443 líneas idénticas** — *"ENTORNO: 2
aviso(s) no cabían ahora"* — a razón de **seis y siete por segundo**. Y cada una de esas
pasadas **reescribe un fichero en tu disco**. Mientras jugabas.

La causa: la llamada estaba suelta dentro del `if (botones -ne 0)` del vigilante del entorno.
Su propio comentario dice *"este es el instante exacto en que se sabe que ha vuelto"* — pero
ese bloque no corre cuando vuelves: corre **cada vez que el mando manda botones**, que jugando
es continuo. Es la regla 5 rota por **entrada/salida a disco** en vez de por RAM.

Ahora va detrás de un freno de un minuto, y la línea del registro solo sale **cuando el número
cambia**. La pregunta por voz (*"qué me he perdido"*) no pasa por el freno y sigue contestando
al momento — el banco comprueba esas dos cosas por separado, porque una rotura demostró que
se podían confundir.

### Lo que NO se puede arreglar desde Nova, y conviene saberlo

Mientras se perseguía lo de la cápsula salió la explicación de fondo: **A Way Out estaba en
pantalla completa exclusiva**. La prueba es limpia — el panel de la Ally es **1920×1080
nativo** y el escritorio estaba a **1280×720**. Solo el modo exclusivo cambia la resolución del
escritorio; el "sin bordes" nunca lo hace.

En ese modo el juego manda directamente sobre la pantalla y **ningún overlay de ventana se
dibuja**, por muy "siempre encima" que esté. Medido: la cápsula estaba en z=0, por delante del
juego, visible y bien colocada — y aun así no se pintaba. Por eso Steam y Discord inyectan en
DirectX para sus overlays, que es otra cosa y que Nova no hace.

**La solución es del juego, no de Nova:** poner *Ventana sin bordes* en las opciones gráficas.
Con eso vuelve la cápsula y deja de cortarse el audio al cambiar de foco.

---

## 7. Cómo se comprueba que nada de esto miente

Cada cambio lleva un banco, y **cada banco se rompe a propósito** antes de darlo por bueno: un
script cambia el código de una manera que sería un fallo de verdad, corre el banco y exige que
salga **rojo**; luego restaura. Si una rotura deja el banco verde, al banco le falta un ojo y
se le añade.

**Las nueve maneras de que un banco salga verde mintiendo**, todas vistas de verdad — cinco
el 23/09 y cuatro más hoy:

1. **Mira la forma del código, no lo que hace.** Un `-match` sobre el texto pasa aunque la
   función esté rota. Por eso se saca del árbol y **se ejecuta**.
2. **Un comentario con la palabra buscada** hace invisible la rotura. Por eso se quitan los
   comentarios antes de mirar.
3. **El banco muere a mitad y sale con código 0.** PowerShell 5.1 con `-File` no falla aunque
   el script reviente. Por eso todos llevan un `trap`.
4. **Trae su propia copia de la constante.** Entonces prueba su número, no el del código.
5. **Exige un formato cerrado que el diseño permite ampliar.** Ha mordido dos veces con los
   campos de `escucha-estado.txt`.
6. **Trae su propia copia de una constante.** Dos bancos llevaban dentro el `4` del suelo de
   avisos y el `3` de la racha de flojos: probaban su número, no el de Nova.
7. **Saca la función con una expresión regular en vez del árbol.** Una de 3.000 caracteres
   cortaba en la primera llave y probaba media función.
8. **Define los dobles antes de cargar el archivo**, y el archivo los pisa. Uno acabó llamando
   a Piper de verdad y dejando un `.wav` en el disco.
9. **Se traga el error y lo cuenta como respuesta.** Hoy mismo: un `catch` que devolvía "muerto"
   cuando en realidad no había podido mirar. El banco daba por muerto a un proceso vivo.

**Y el mismo defecto, pero en el código y no en el banco:** una **lista cerrada que el diseño
amplió y nadie volvió a tocar**. El barrido de huérfanos nombraba tres workers; el cuarto
llevaba trece días acumulándose. Cada vez que se añade un proceso residente hay que añadirlo
en los dos sitios que lo matan.

**Y la trampa que más daño ha hecho hoy — la ventana temporal.** Tumbó **siete** conclusiones
mías seguidas. Antes de decir que algo está roto hay que mirar **desde cuándo existe ese
código, y a qué hora se commiteó, no solo qué día**: un fallo que "no aparece en quince días
de registro" puede llevar arreglado desde ayer por la tarde. Está escrita en la cabecera de
`tools/probar-todo.ps1` para que no se olvide.

Hoy: **173 bancos, 175 secciones**, y cada idea de las cuarenta con su script de roturas.

---

## 8. Lo que queda

**Decisiones que son tuyas, no mías:**

- **Tu apodo.** Nova sabe que tienes uno y **no lo usa nunca**. Hace falta que se lo digas; no
  hay forma de sacarlo de ningún dato.
- **Si quieres que tenga opiniones propias.** Las ocho entradas de "estilo" de su cerebro son
  preferencias **tuyas** —*"respuestas rápidas y directas"*, *"no usar la palabra man"*—, y
  **ninguna es de ella**. No hay dato que decida esto: es cuestión de si te apetece o no.
- **El contexto de la charla con significado.** Pasarle el vector a la búsqueda de contexto
  sube los aciertos del 8,6 % al 12,2 %, pero cuesta **2,87 s por turno**. Con "velocidad sobre
  todo", +3,6 puntos no me parece una victoria clara — pero el tiempo es tuyo.
- **Poner los juegos en "ventana sin bordes".** Es un ajuste en cada juego, no en Nova. En
  pantalla completa exclusiva **la cápsula no se ve** — ningún overlay de ventana se dibuja —
  y el audio se corta cada vez que algo le quita el foco al juego. Con el sin bordes se
  arreglan las dos cosas de golpe y el rendimiento es el mismo.

**Lo que hay que esperar a que se llene:**

- **El plazo de la voz**: desde hoy se miden todas las frases. Con 20 muestras, el plazo saldrá
  del p99 real.
- **La batería por juego**: desde hoy se apunta el porcentaje cada vez que cambia, con el
  cargador y el juego al lado. El umbral no era el problema —el solape juego-sin-cargador de
  quince días son **cinco minutos**, porque juegas enchufado—, faltaban datos.
- **Una regla viva**: el ciclo entero funciona y está probado, pero ninguna ha disparado nunca
  en producción porque no hay ninguna guardada.

**Lo que sigue abierto y no depende de esperar:**

- **Los 15 de 92 juegos**: Nova solo conoce los instalados. Con la clave de Steam funcionando
  desde hoy, puede conocerlos todos —con sus horas, sus logros y con quién juegas—. Eso está en
  su propio documento, con diez ideas medidas.
- **El 89,8 % del tiempo de juego que se pierde** porque Nova no está encendida. Eso no se
  arregla con código de detección.

---

## 8 bis. Lo del 25 de septiembre: las listas de ideas, repasadas enteras

Las **21 ideas** y las **50 de autonomía** se repasaron **una a una**. Y el resultado importa
más por lo que **no** se hizo que por lo que se hizo: **se descartaron más de las que se
implementaron**, y casi siempre por dos motivos — *el código ya lo hacía* o *no hay datos*.

**El descarte que vale por todos:** la sección entera *"decidir sin preguntar"* (ocho ideas)
se cayó con un solo número. Nova pregunta **32 veces en dieciséis días, y ninguna desde el
20/09**. Y las 32 son de tres tipos, los tres correctos: frases mal oídas (*'abre calcladra'*),
borrados, y plazos vencidos —que no son una pregunta, son que nadie contestó—. **No hay
preguntas de más que quitar.** La autonomía que le falta no es dejar de preguntar: es hacer
cosas útiles por su cuenta.

**Lo que sí tenía base, y es lo que se hizo:**

| Qué | Lo que lo justificaba |
|---|---|
| El ánimo al arrancar, y **con memoria de siete días** | saltaba de **+0,62 a −0,50** por *un* error en un día vacío |
| **Lo que importó no se resume** | 342 turnos de charla → **29 viñetas** en catorce días |
| Los **logros de Steam** | la fecha vivía en RAM: un apagón o un alt-tab los borraba |
| **Trabajar cuando no molesta** | las **13 copias, las 13 entre las 17h y las 22h** |
| **Contar lo que hizo** mientras no estabas | el resumen sólo contaba mensajes, nunca lo suyo |
| Que note **a qué juegas** | `juegos.json` existía y no decidía nada |
| La **cascada de repasos, medible** | canary: 18 usos, **cero** órdenes sacadas |

Esa última no se apagó a mano: el listón para decidir son 20 intentos y lleva 18. **Nova lo
decidirá sola**, lo dirá en voz alta y podrás deshacerlo — igual que ya hace con la nube y con
su oído fino.

Todo el detalle, con la medición de cada descarte, está en **`IDEAS-ESTADO-2026-09-25.md`**.

---

## 9. Los demás documentos

Este resume lo que **hay**. Lo que **podría haber** está repartido en estos, y cada uno lleva
sus mediciones dentro:

| Documento | Qué tiene |
|---|---|
| `IDEAS-2026-09-25-VEINTE.md` | **Las veinte siguientes**, salidas del repaso de esta madrugada: la cápsula que no sabe si se la ve, las 26 expresiones frágiles que quedan en los bancos, el perfil lleno |
| `IDEAS-AUTONOMIA-Y-VIDA-50.md` | **Cincuenta** para que decida sola y se sienta viva, con el diagnóstico de por qué: nueve de sus veinte iniciativas están muertas |
| `IDEAS-ESTADO-2026-09-25.md` | **Qué pasó con cada una de las 71**: hechas, y sobre todo **descartadas con el dato que las tumbó** |
| `IDEAS-STEAM-2026-09-24.md` | Diez sólo de Steam, con la clave ya funcionando |
| `IDEAS-2026-09-24-VEINTE.md` y `-NUEVAS-VEINTE.md` | Las cuarenta de ayer, ya cerradas |
| `NOVA-EN-OTRO-PC.md` | Cómo llevarla a la laptop sin romper la de la consola |
| `NOVA-LLM.md` | Los modelos medidos y cuál gana |

---

*Nova lleva 515 commits y quince días de registro. Lo que hay aquí se puede volver a sacar
entero: el registro es `assistant.log` y su rotado, los ficheros de `memoria\` están en disco,
y cada número de este documento tiene detrás un comentario en el código que dice de dónde
sale.*
