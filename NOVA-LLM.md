# Nova como un LLM, sin serlo

braya: «¿podemos hacer que Nova sea todo esto, o sea ser un verdadero LLM sin serlo?»

**Se empieza al terminar la lista de AUTONOMIA.md, y entonces solo se trabaja en esto.**

---

## La idea, en una frase

Lo que hace útil a un asistente **no es principalmente el modelo**. Es un conjunto de seis
piezas, y de esas, **solo una necesita un LLM de verdad**. Nova ya tiene tres y media. El
trabajo es completar las otras, que **caben en local** y no dependen de pagar nada.

## Las seis piezas, y dónde está Nova hoy

| # | pieza | qué es | Nova hoy |
|---|---|---|---|
| 1 | **Razonamiento con lenguaje** | entender una frase torcida y deducir la intención | **prestado** (API primero, Ollama de respaldo) |
| 2 | **Herramientas reales** | leer, escribir, ejecutar y ver el resultado | **sí, y muchas** |
| 3 | **Bucle de verificación** | hacer → comprobar → corregir | **empezado (18/09)**: volumen, brillo y apertura de apps |
| 4 | **Memoria con sentido** | recordar y traer lo relevante, no lo que coincide en letras | **sí**: busca por significado; le falta material, no código |
| 5 | **Criterio para no actuar** | saber cuándo parar, preguntar o callarse | **sí, y bueno** |
| 6 | **Rendir cuentas** | decir qué hizo y por qué, con números | **sí**, desde la tanda de autonomía |

**Lo medido que respalda esto:** de 366 órdenes, **201 se resuelven en local sin tocar un
modelo** y 165 van a uno. Y los fallos **no son de comprensión: son de oído** — los 38 errores
registrados son «dictado vacío» y transcripciones rotas («Abre Team», «Abre Sting»).
Por eso un modelo más grande no la arreglaría.

---

## Cómo quedó el plan (18/09)

De las cuatro secciones que tenía este documento, **una era trabajo de verdad y tres ya estaban
hechas o mal planteadas**. Comprobarlo costó menos que implementarlas a ciegas:

| pieza | veredicto |
|---|---|
| **1. Bucle de verificación** | **HECHA la parte que se puede medir**: volumen, brillo y apertura de apps |
| **2. Memoria con sentido** | **ya funcionaba**: busca por significado con 31 vectores; el «0 usos» era una métrica mía engañosa |
| **3. Saber lo que no sabe** | **ya estaba**, y la premisa era falsa: los `fino-invento` son inventos **cazados**, no ejecutados |
| **4. Más herramientas** | no es un proyecto con final, es trabajo continuo |

*Lo que queda pendiente de verdad, por orden:* cerrar (`cerrarApp` ya cuenta «cerrados N de M»,
falta que llegue a la frase), los archivos creados, y los relativos de volumen/brillo **si el uso
real los pide** — hoy medido, no los pide.

**Y lo que desbloquea todo lo demás no es código: es usar Nova.** El plan entero se apoya en
datos de 4 días de uso, y varias piezas están esperando material real para poder decidirse.

---

## 1. El bucle de verificación — **EMPEZADO (18/09)**

Es lo que más separa a Nova de un asistente que parece listo, y **no necesita modelo ninguno**.

Hasta hoy Nova **ejecutaba y daba por hecho que salió bien**. El fallo más caro del proyecto fue
justo ese: «volumen al 70» dejaba el volumen **a cero** mientras ella contestaba «volumen al 70
por ciento». Vivió semanas porque el banco comparaba la **descripción** de la acción y nunca su
efecto (`tools/probar-acciones.py` nació de ahí).

### Lo hecho

`Test-EfectoAccion` comprueba el efecto **después** de actuar, y va enganchada en el ejecutor
justo antes de dar la acción por hecha (`$hechas += $a.desc`), que es donde Nova decide qué va a
decir en voz alta:

1. **Comprueba** lo que se puede leer y es absoluto: `volumenPct` (`[AX]::LeerVolumen`) y
   `brillo` con nivel ≥ 0 (`Get-BrilloActual`).
2. **Reintenta una vez**, y solo lo idempotente — `Invoke-AccionOtraVez`. Poner el volumen al 70
   dos veces sigue siendo 70; repetir un «sube un paso» lo subiría dos.
3. **Lo dice en vez de presumir**: si tras el reintento sigue sin cuadrar, la frase pasa a ser
   «lo intenté dos veces y no se puso: se quedó en N», y la cápsula lo marca.
4. **Lo apunta**: `Add-Estadistica 'no-surtio-efecto'` con lo pedido y lo que quedó. Antes una
   acción que no surtía efecto **no dejaba ningún rastro** salvo que braya se quejara.

*Y calla cuando no sabe*, que es la mitad difícil: si `LeerVolumen()` devuelve −1 (no se puede
leer), si la acción es relativa o si no es de su tipo, devuelve `$null` y nadie dice nada.
Inventar un fallo es peor que no comprobar. Márgenes: ±2 en volumen (la conversión float→%
baila un punto) y ±5 en brillo (hay paneles que solo aceptan ciertos saltos).

*De camino:* `Get-BrilloActual` y `Get-BrilloDestino` salen a funciones propias. El cálculo del
destino vivía dentro de `Set-Brillo`, y copiarlo en dos sitios era la forma segura de que se
separaran. `Set-Brillo` **sigue sin devolver nada** a propósito: tiene 7 llamadores y en
PowerShell un valor que nadie recoge se cuela en la salida de la función que envuelve — habría
roto `Invoke-Deshacer`. Hay un caso en el banco que lo vigila.

`probar-efecto.ps1` (2n27), 36 casos.

### Abrir una app — **HECHO (18/09)**

*Es la orden estrella:* **61** de las ejecutadas en el registro son «→ abrir» (Steam 12 veces,
la calculadora 8, Spotify, el bloc de notas, Elden Ring). Y Nova mandaba abrir y daba por hecho
que se abrió.

*Es diferido a propósito, y lo impone la medición:* una app tarda **298 ms** en aparecer como
proceso y **~800 ms** en tener ventana. Comprobar en el acto daría un «no se abrió» falso
siempre, y esperar 800 ms dentro del bucle se pagaría en velocidad. Así que `Add-AperturaPendiente`
**apunta** lo que debería aparecer y `Test-AperturasPendientes` lo revisa **sin bloquear**, cada
2 s y solo si hay algo que mirar. Si a los 10 s no está: lo dice una vez («mandé abrir X y no se
ha abierto»), lo apunta como `no-surtio-efecto` y deja de vigilarlo.

*Y calla cuando no debe opinar:* si la app **ya estaba abierta** (la orden no cambia nada), si es
un **juego de Steam** (tarda más y no deja proceso propio, se abre por URI) o si `Resolve-Proceso`
no sabe resolverla. El mapa `PROCESOS_URI` ya cubre los casos difíciles: steam→`steam`,
spotify→`Spotify`, calculadora→`CalculatorApp`.

`probar-apertura.ps1` (2n28), 29 casos.

**⚠ Ojo con el «0 fallos al abrir» del registro:** no es evidencia de que nunca falle, sino de
que **hasta hoy nadie lo comprobaba**, así que un fallo no podía quedar anotado. Es un cero
circular. A partir de ahora sí se sabrá.

### Lo que queda de esta pieza

- **Los relativos** («sube el volumen», «baja un poco el brillo»): técnicamente fácil —basta con
  que la rama apunte el destino que ya calcula—, pero **medido, no hay caso**: las 349
  apariciones que parecían uso real eran el prompt de Whisper (`PROMPT_ORDENES` lleva «Sube el
  volumen» y «Baja el brillo») y líneas `RUNNER cmd:`. Las órdenes de volumen/brillo realmente
  ejecutadas son **25**, y casi todas **absolutas**, que es lo que ya se verifica. Se retomará si
  el uso real lo pide.
- **Cerrar** (`cerrarApp`, `cerrarTodo`): ya cuentan «cerrados N de M», o sea media verificación
  hecha; falta que eso llegue a la frase y a las estadísticas.
- **Archivos creados**: existe o no existe, trivial de comprobar, pero hoy solo lo hacen las
  recetas.

*Por qué se empezó aquí:* ataca directamente la meta de «cero órdenes equivocadas», se prueba en
el banco sin modelo, y cada trozo es independiente.

## 2. Memoria con sentido — **YA FUNCIONA; falta material, no código (18/09)**

*Comprobado, y el diagnóstico de arriba era mío y estaba equivocado.* La búsqueda por
significado **está activa**: el arranque registra «(significado: emb…)», hay **31 vectores para
32 recuerdos** en `vectores.json` (63 KB, modelo `embeddinggemma:300m-qat-q8_0`) y ese modelo
está instalado en Ollama junto a `qwen2.5:1.5b` y `qwen2.5:3b`.

**Y los recuerdos sí se recuperan.** `contexto()` busca con
`tipos={"respuesta","contado","episodio"}`, combina significado y palabras (`0.6·sem + 0.4·lex`)
y mete los tres mejores en el prompt como «Lo que ya sabes (úsalo solo si viene al caso)», más
el estilo y los temas de los que braya suele hablar.

**El «0 usos de 32» era una métrica engañosa** —la escribí yo en `QUE-SABE-HACER.md`—. Ese
contador **solo lo toca `respuesta_directa`**, que filtra `tipos={"respuesta"}` para decir algo
*tal cual* sin preguntar al modelo. Y el reparto real es:

| tipo | cuántos | ¿cuentan usos? |
|---|---:|---|
| `episodio` | **29** | no, pero **sí se usan** como contexto |
| `respuesta` | 3 (1 rechazada) | sí |

Las dos respuestas firmes son trivia que no se repite nunca: «¿Cuál es la distancia entre la
Tierra y el Sol?» y «¿Qué es escribir?». Por eso el contador está a cero.

*Lo que falta no es mejor recuperación, es material que merezca recuperarse,* y eso sale de
conversar: **86 charlas** en cuatro días, y ninguna repetida. Se retomará cuando el uso real lo
llene — igual que la idea 54: el mecanismo está listo y esperando datos.

*(Lo del `id 3` sin vector no era un fallo: está **rechazada**, y `completar_vectores`
salta las rechazadas a propósito. Contado el 19/09: **53 recuerdos, 50 vectores**; los que
faltaban de verdad eran el **53 y el 54**, de la noche del 18 —Nova se cerró antes de los
5 min de reposo que espera el revisor para cargar embeddinggemma—. Se completan sin hablarle
a Nova con `python tools\completar-vectores.py`.)*

## 3. Saber lo que no sabe — **YA ESTÁ, y la premisa era falsa (18/09)**

*Los 5 `fino-invento` no son «órdenes equivocadas»: son inventos **cazados**.* Ese camino
registra el invento, dice «No te entendí» y **no ejecuta nada**. Los cinco del registro lo
enseñan: «SILENCE», «¡Cochais en el mantenguero», «Tardenguelas»… y detrás no hay acción, solo
la pausa (y en uno, la autosordina). Eso que el plan ponía como prueba de que Nova adivina es
justo la prueba de que **ya sabe cuándo no sabe**.

*Y las piezas no hay que juntarlas: ya están puestas y calibradas con medición.*

| pieza | estado |
|---|---|
| `Test-DictadoDudoso` | umbral **−0,8**, calibrado con 20 grabaciones: preguntaba en 9, «todos mal oídos, y en ninguno bien oído» |
| `Test-MereceRepaso` | descarta el repaso imposible antes de gastar segundos |
| `$script:dudosa` → confirmación | **10** veces preguntó en vez de actuar |
| `Test-VozExtrana` | pregunta antes de lo peligroso si no reconoce la voz |
| filtro de ruido + autosordina | lo corto y lo repetido no llega a ejecutarse |

**⚠ Y lo más valioso: el umbral de la palabra ya se probó y NO sirve.** Está medido en el
código: el 12/09 «nova» saltó con confianzas de **0,65 a 0,96** mientras braya hablaba con otra
persona, «así que subir el umbral no lo separa de las órdenes buenas». Lo que sí separó, mirando
todas las frases largas del registro, fue **cómo empieza la frase** (`$INICIO_ORDEN`): una orden
empieza por lo que se quiere («abre», «busca», «sube», «recuérdame»); la charla, por cualquier
otra cosa.

Quien retome esto que no repita el experimento del umbral: ya está hecho y salió que no.

## 4. Más herramientas fiables, no más inteligencia — **trabajo continuo, no un proyecto**

Cada herramienta nueva multiplica lo que puede hacer **con el mismo cerebro prestado**. Y una
herramienta se prueba en el banco; un modelo, no.

Esto no se «termina»: hoy son **24 apps, 14 sitios, 9 buscadores, 5 modos** y 336 funciones. La
regla que sí aplica, y que esta tanda ha confirmado 20 veces, es **no añadir la número 25 sin
medir que hace falta**.

---

## Lo que NO va a tener sin un LLM, y conviene no engañarse

Conversación abierta, entender una frase que no ha visto nunca, escribir texto largo con
sentido. Eso **es** el modelo y no se sustituye con reglas. Pero eso ya lo tiene prestado por
API, y para su uso real —abrir cosas, volumen, juego, recordatorios— **el LLM es lo de menos**.

## Cómo se sabrá si funciona

Lo mismo que en todo lo demás: **con el banco y con el registro de uso**.
- una acción verificada que falla y se corrige debe tener su caso en el banco;
- los `fino-invento` y los `error` tienen que **bajar**;
- y las órdenes resueltas en local, subir.

Si una de estas piezas no se puede medir, es que no se ha entendido bien todavía.
