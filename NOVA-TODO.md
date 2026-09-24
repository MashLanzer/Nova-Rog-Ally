# Nova, entera — 24 de septiembre de 2026

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

---

## 7. Cómo se comprueba que nada de esto miente

Cada cambio lleva un banco, y **cada banco se rompe a propósito** antes de darlo por bueno: un
script cambia el código de una manera que sería un fallo de verdad, corre el banco y exige que
salga **rojo**; luego restaura. Si una rotura deja el banco verde, al banco le falta un ojo y
se le añade.

**Las cinco maneras de que un banco salga verde mintiendo**, todas vistas de verdad:

1. **Mira la forma del código, no lo que hace.** Un `-match` sobre el texto pasa aunque la
   función esté rota. Por eso se saca del árbol y **se ejecuta**.
2. **Un comentario con la palabra buscada** hace invisible la rotura. Por eso se quitan los
   comentarios antes de mirar.
3. **El banco muere a mitad y sale con código 0.** PowerShell 5.1 con `-File` no falla aunque
   el script reviente. Por eso todos llevan un `trap`.
4. **Trae su propia copia de la constante.** Entonces prueba su número, no el del código.
5. **Exige un formato cerrado que el diseño permite ampliar.** Ha mordido dos veces con los
   campos de `escucha-estado.txt`.

Hoy: **170 bancos, 172 secciones**, y cada idea de las cuarenta con su script de roturas.

---

## 8. Lo que queda

**Decisiones que son tuyas, no mías:**

- **El contexto de la charla con significado.** Pasarle el vector a la búsqueda de contexto
  sube los aciertos del 8,6 % al 12,2 %, pero cuesta **2,87 s por turno**. Con "velocidad sobre
  todo", +3,6 puntos no me parece una victoria clara — pero el tiempo es tuyo.

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

*Nova lleva 515 commits y quince días de registro. Lo que hay aquí se puede volver a sacar
entero: el registro es `assistant.log` y su rotado, los ficheros de `memoria\` están en disco,
y cada número de este documento tiene detrás un comentario en el código que dice de dónde
sale.*
