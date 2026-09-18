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
| 3 | **Bucle de verificación** | hacer → comprobar → corregir | **no** ← *lo que más falta* |
| 4 | **Memoria con sentido** | recordar y traer lo relevante, no lo que coincide en letras | **a medias** |
| 5 | **Criterio para no actuar** | saber cuándo parar, preguntar o callarse | **sí, y bueno** |
| 6 | **Rendir cuentas** | decir qué hizo y por qué, con números | **sí**, desde la tanda de autonomía |

**Lo medido que respalda esto:** de 366 órdenes, **201 se resuelven en local sin tocar un
modelo** y 165 van a uno. Y los fallos **no son de comprensión: son de oído** — los 38 errores
registrados son «dictado vacío» y transcripciones rotas («Abre Team», «Abre Sting»).
Por eso un modelo más grande no la arreglaría.

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

## 2. Memoria con sentido

Ya existe la infraestructura: `cerebro.json`, `vectores.json` (64 KB), tope de 5.000
recuerdos, diario por días, `perfil.md` y un revisor en segundo plano.

Lo que falla es **la recuperación**: traer lo que viene a cuento, no lo que coincide en
palabras. Es donde un modelo pequeño **local** (embeddings) rinde de verdad, y ya hay uno
configurado (`conversacion.modeloEmbeddings`).

Señal de que importa: `Find-Traduccion` devolvía la primera coincidencia y no la más parecida
—arreglado en esta tanda—. El mismo problema, más grande, está en la memoria.

## 3. Saber lo que no sabe

Yo digo «esto no lo he medido». Nova, cuando no entiende, **adivina**: son los
`fino-invento`, **5 órdenes equivocadas de 81 repasos**. Una IA que reconoce su límite parece
mucho más lista que una que acierta un poco más.

Ya hay piezas: la confianza del dictado, `Test-MereceRepaso`, el umbral de la palabra. Falta
**juntarlas en una sola idea de «seguridad»** que decida entre hacer, preguntar o callar.

## 4. Más herramientas fiables, no más inteligencia

Cada herramienta nueva multiplica lo que puede hacer **con el mismo cerebro prestado**. Y una
herramienta se prueba en el banco; un modelo, no.

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
