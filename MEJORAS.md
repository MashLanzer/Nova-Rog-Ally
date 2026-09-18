# Mejoras de Nova: lo medido y lo propuesto

Lista viva para consultar y decidir qué se hace después. Empezada el 17/09/2026.

**Cómo se usa:** nada entra aquí como «buena idea». Entra con un número al lado o con la
nota de que todavía no se puede medir. Lo que se descarta también se queda escrito, con
el dato que lo tumbó, para que nadie (yo el primero) lo reintente dentro de tres semanas.

**La meta de braya manda:** que Nova le entienda al 100 % y no ejecute ni una orden
equivocada; y la velocidad por encima de casi todo. Una mejora que cambie segundos por
órdenes perdidas no es una mejora.

---

## 1. Medido hoy y ya decidido

### 1.1 El oído fino SE QUEDA — medido
Interviene en 125 de 187 órdenes reales y en 100 cambia el texto. Pasando los 100 pares
por el resolvedor local: **rescata 18, estropea 7**. Se queda.
Por motor: base 60 repasos (rescata 10), small 24 (5), turbo 15 (3, no estropea ninguna).

### 1.2 Las 7 que «estropeaba» NO eran un problema — cerrado
Las 7 están protegidas por la red de PARAKEET→WHISPER (`Test-EspanolLargo` +
`-not Test-FastCommand`): Nova ya se quedaba con el texto bueno. La lección fue sobre la
medición: comparar lo que oyó el repaso contra lo que oyó Parakeet **no dice qué hizo
Nova**. Para eso está ahora `destinos.jsonl`.

### 1.3 Frenar el repaso: DESCARTADO con datos
Era la idea más prometedora de la lista corta. Aplicar el freno que ya existe
(`Test-PareceCharla`) al camino Parakeet→Whisper frenaría 22 de los 73 repasos inútiles
**pero se cargaría 5 de los 18 rescates**. Segundos a cambio de órdenes perdidas: no.

### 1.4 EL ÚLTIMO RECURSO (turbo): pendiente de decidir, ya medido
| motor | veces | mediana | total | rescata |
|---|---|---|---|---|
| base | 115 | 1,3 s | 4,3 min | 10 |
| small | 48 | 4,1 s | 4,2 min | 5 |
| **turbo** | **23** | **16,2 s** | **7,4 min** | **~3** |

Turbo es 9 veces más lento que base, se lleva casi la mitad del tiempo de repasos y sale
a **~149 s de espera por cada orden que salva** (`turbo` 29 lanzamientos / `turbo-nada`
27 en las estadísticas). A su favor: nunca estropeó ninguna.
- [ ] Decidir: bajarle el plazo, lanzarlo solo con audio corto, solo si parece orden, o
      quitarlo. Antes, mirar con `destinos.jsonl` si esos ~3 rescates importaban.

### 1.5 Medir aciertos: HECHO
`Write-DestinoUso` apunta qué hizo Nova con cada orden, y «eso estuvo mal» / «no era eso»
la marca como fallo confirmado. `python tools\analizar-uso.py` junta las dos mitades y
da el porcentaje. Es el único dato que no depende de que nadie interprete nada.

---

## 2. Las 10 ideas nuevas (17/09) y su estado

| # | Idea | Estado |
|---|---|---|
| 1 | Vocabulario según el juego abierto | **BLOQUEADA**: la duda entre candidatos no se registra en ningún sitio, así que no se puede saber si pasa 5 veces al día o 2 al mes. Hay que instrumentar un contador primero |
| 2 | No repasar lo que nunca fue una orden | **DESCARTADA** con datos (ver 1.3) |
| 3 | «¿Cómo me has entendido hoy?» | pendiente |
| 4 | Repaso del día: preguntar por las 3 peores | pendiente |
| 5 | Perfil de ruido por hora | pendiente |
| 6 | Deshacer con historial | pendiente |
| 7 | Leer una zona de la pantalla | pendiente |
| 8 | Modo sin manos (confirmar con el mando) | pendiente |
| 9 | Segunda opinión también en órdenes ambiguas | pendiente |
| 10 | Avisos al móvil | pendiente (la más cara y la que menos acerca al 100 %) |

---

## 3. Auditoría completa de Nova (17/09)

Cuatro auditorías en paralelo, por áreas disjuntas. Cada hallazgo viene con severidad,
cómo se mide y **5 mejoras** concretas.

### 3.1 El oído — HECHA (10 hallazgos)

| # | Hallazgo | Sev. | Dónde |
|---|---|---|---|
| 1 | **La ganancia está atascada en x0.7 y no puede bajar**: el objetivo calculado es 0.5, pero el paso de bajada (factor 0.2) da 0.66 y `round(...,1)` lo devuelve a 0.7. Simulado: ocho ciclos sin moverse | GRAVE | `wake_vosk.py:1699` |
| 2 | **El micrófono recorta en el propio conversor**: el p90 crudo llega a 0.99 en 206 de 806 pulsos y 40 de 188 grabaciones salen saturadas (329 «recorte detectado» en el log). Ninguna ganancia por software lo arregla, y **nadie toca nunca el nivel de captura de Windows** | GRAVE | `wake_vosk.py` |
| 3 | `GANANCIA_INICIAL` sigue siendo **x8**: si falta `tmp\ganancia.txt` —un directorio de usar y tirar— vuelve el fallo de ayer entero. La prueba nueva vigila la regla de descarte, no el valor de arranque | GRAVE | `wake_vosk.py:171` |
| 4 | «Parakeet primero» resuelve **29 de 188, no 144** (dato mío erróneo, ya corregido) | MEDIO | — |
| 5 | **Durante el repaso está sorda y tira el audio**: 3.033 s descartados, y `atender_reintento` corre antes de mirar `dictar.flag` — justo cuando braya repite tras un «no te entendí» | MEDIO | `wake_vosk.py` → **NO se arregla, ver abajo** |
| 6 | La confianza de Whisper **se hereda de la orden anterior** cuando gana Parakeet: solo 42 de 188 traen dato propio | MEDIO | → **DESCARTADO, ver abajo** |
| 7 | Los audios de más de 8 s nunca reciben small ni turbo (25 de 188), y el camino Parakeet→Whisper no tiene ningún tope | MEDIO | — → **DESCARTADO, ver abajo** |
| 8 | `probar-audio.py` mide **el circuito de antes del 15/09**: no carga Parakeet, así que su listón de 0,75 no avala lo que corre hoy | MEDIO | `tools\probar-audio.py` |
| 9 | `leer_vocabulario()` no se llama desde ningún sitio, pero el asistente sigue generando y pasando `tmp\vocabulario.txt`; `pico_voz` es variable muerta | LEVE | — |
| 10 | `decodificado=N%` es una media desde el arranque del proceso, no de la ventana: no puede avisar de nada | LEVE | — |

**HECHO (17/09) — 3.1 #1, #2 y #3, los tres de la ganancia.** Medido sobre 400 pulsos
reales: p90 crudo con mediana **0,601** y **27 % saturados** (109 de 400 con ≥0,98), o sea
que el micrófono pide atenuar **0,58 de mediana y 0,35 en los picos**.
- El **suelo** era 0,5, por encima de lo que pide: baja a 0,3.
- El **redondeo se comía la bajada**: con 0,7 y objetivo 0,58, `0,7+(0,58-0,7)*0,2 = 0,676`
  y `round(...,1)` devolvía 0,7. Clavada para siempre. Ahora, si toca bajar, se fuerza un
  decimal sin pasarse del objetivo: 0,7 → 0,6 con su voz, y 0,7 → 0,4 con el micro saturado.
- **`GANANCIA_INICIAL` era x8** y describía otro micrófono. Arrancar alto es lo que la hacía
  activarse sola; arrancar neutro (x1) es seguro porque **subir es rápido** (0,6) y bajar
  lento (0,2): simulado, 1,0 → 4,6 en un solo ciclo. Si faltara `tmp\ganancia.txt` ya no
  vuelve el fallo de ayer.
Seis casos nuevos en `probar-escucha.py`, incluido uno que reproduce el atasco.

### 3.2 El núcleo de órdenes — HECHA (9 hallazgos)

| # | Hallazgo | Sev. | Dónde |
|---|---|---|---|
| 1 | **«volumen al 70» ponía el volumen a CERO** (`nivel` creado / `pct` leído) | GRAVE | `assistant.ps1:2047` → **ARREGLADO** |
| 2 | **El banco nunca ejecuta**: `-Probar` solo imprime `desc` y no entra en el switch; `destinos.txt` compara texto, no lo que se hace. Por eso el nº 1 vivió tanto | GRAVE | `assistant.ps1:9879` |
| 3 | **Las reglas por voz nacen sin guardas**: `Invoke-ReglaVoz` sale antes de `Test-Rechazada` y `Test-VozExtrana`. **La voz de un vídeo puede crear reglas y modos** | GRAVE | `assistant.ps1:6382` |
| 4 | El patrón de la hora no exige «cuando»: «a las ocho cierra steam» guarda una **regla diaria** desde una frase de conversación | GRAVE | `assistant.ps1:9182` → **NO se arregla así, ver abajo** |
| 5 | **Al dispararse, una regla tiene carta blanca**: `$script:confirmado = $true`, así que «cierra todos los programas» se ejecuta sin preguntar. El camino de hábitos sí filtra lo destructivo; el hablado se olvidó | GRAVE | `assistant.ps1:9290` |
| 6 | Las recetas se prueban **antes** del filtro de ruido y sin rechazo ni voz ajena; con `confirmadas>=2` lanzan PowerShell sin preguntar | GRAVE | `assistant.ps1:13487` |
| 7 | El atajo de pronombres convierte «ponla siempre encima» en «pon spotify siempre encima» y acaba **abriendo Spotify** | MEDIO | `assistant.ps1:2190` → **HECHA** |
| 8 | `Test-FastCommand` (que valida todo y corre sobre los parciales **mientras hablas**) lee el escritorio, escanea siete carpetas y toca el estado de la cápsula | MEDIO | — |
| 9 | `Find-Traduccion` devuelve la **primera** clave dentro del tope, no la más cercana: el resultado depende del orden del hashtable (fallo que no se reproduce) | MEDIO | `assistant.ps1:6105` → **HECHA** |
**HECHO (17/09) — 3.3 #2, la sordera de hasta 90 s.** Era peor de lo que decía el
informe: `Say` fija la pausa por cuenta de letras ANTES de saber si habrá sonido, y había
**tres** salidas que se iban sin tocarla (Piper, «no hay voz» y el `catch` final). Ahora,
si no suena nada, se reanuda la escucha y la cápsula vuelve a reposo; y `Say-Piper` ajusta
el plazo con la **duración real** del `.wav`, como ya hacía la voz en línea.
- **NO se bajó el techo de 90 s**, que era la mejora nº 1 propuesta: si una frase larga
  tarda más que el techo nuevo, la escucha se reanudaría **mientras Nova habla** y se
  oiría a sí misma, que es justo lo que ese plazo existe para evitar. Se ataca el caso
  real (no ha sonado nada) en vez del síntoma.
- La tasa del `.wav` **se lee de su cabecera**, no de una constante. Primero puse 44100
  B/s a mano; el modelo actual declara justo eso, pero una constante copiada se desajusta
  en silencio el día que se cambie de voz. De paso: al verificarlo medí `ultima-orden.wav`
  (16.000 Hz) creyendo que era de Piper — es del **micrófono**. Verificar contra la fuente
  equivocada casi me hace «corregir» un número que estaba bien.

**HECHO (17/09) — 3.3 #1, la `ReadLineAsync` huérfana.** `Say-Online` creaba una lectura
nueva en cada frase y, al vencer el plazo, hacía `return` dejando la anterior viva sobre
el mismo `StreamReader`. De ahí salían los dos síntomas: `InvalidOperationException` («el
flujo está en uso») que daba la voz en línea por muerta **el resto de la sesión**, o la
lectura vieja quedándose con la ruta y la frase nueva recibiendo el audio de la anterior
—Nova diciendo una cosa y la cápsula moviendo la boca con otra—.
Se aplica el patrón que `Receive-Charla` ya usaba bien: la tarea se guarda en
`$script:ttsLectura` y se reutiliza en vez de crear otra; se limpia al relanzar el worker,
porque la tubería nueva invalida la pendiente.
- **Coste asumido a propósito:** cuando vence el plazo, la línea que llega tarde es la de
  la frase **anterior**, así que se descarta y esa frase cae a Piper. Es decir, un plazo
  vencido cuesta dos frases sin voz en línea en vez de una. Preferible a hablar
  descuadrada, pero queda escrito para que no parezca un efecto no visto.

**HECHO (17/09) — 3.3 #3, el cuarto de segundo de cada frase. Y la mejora propuesta era
MALA: medirlo lo salvó.** `Play-Audio` dormía 250 ms fijos en el hilo del bucle (202
frases en el log = **50,5 s congelado**, y la mitad eran frases ya preparadas que llegaban
en milisegundos). Medido en esta máquina:
- `Open()` tarda **453-547 ms** en estar listo, siempre → los 250 ms **no llegaban ni al
  peor caso**: `Play()` ya se llamaba sobre un audio a medio cargar.
- Y aun así sonaba, porque **`Play()` queda encolado**: llamándolo inmediatamente, la
  posición empieza a avanzar a los 513 ms, igual que con pausa. La pausa solo congelaba.
- `MediaOpened` (la mejora nº 2 que proponía la auditoría) **no llega NUNCA** aquí:
  sin bucle de mensajes WPF en un script de PowerShell el evento no se entrega (probado,
  ni en 2 s). Llegué a implementarlo y **empeoraba**: cada frase caía en una red de
  600 ms. Sondear `NaturalDuration` tampoco vale: 543 ms.
→ Queda `Open()` + `Play()` seguidos, sin esperar nada. **No reintentar `MediaOpened`.**

**HECHO (17/09) — 3.3 #10, el revisor que despertaba 1.200 veces por hora.** Era
`while True: sleep(3)` con un recorrido de hasta 5.000 recuerdos por vuelta. Ahora espera
sobre un evento, **se para del todo con un juego delante** (colgado de la operación
`descargar` que el asistente ya envía al abrir uno) y se reanuda en la siguiente charla;
si no encuentra trabajo, va espaciando hasta 60 s.

**HECHO (17/09) — 3.3 #4, «pensando» era lo único que quedaba a 60 fps.** El trabajo del
13/09 puso tope al latido, al vaivén y al halo, pero dejó fuera lo que acompaña a ese
estado: los 9 relojes de los puntitos y el giro de la órbita, ambos `Forever` y sin tope.
Y «pensando» dura minutos (la órbita ni siquiera aparece hasta los 20 s). Puntitos a
15 fps, órbita a 20.

**HECHO (17/09) — 3.3 #5, a medias y a propósito.** El muestreo de luz usaba `GetPixel`,
que bloquea y desbloquea el bitmap en **cada** llamada, varios cientos por captura, al
principio de cada orden y en el hilo de la interfaz. Ahora es un `LockBits` y un recorrido
del array: misma fórmula, misma cuenta.
- **El `Thread.Sleep(45)` NO se toca.** Está para que la cápsula no salga en su propia
  captura, y comprobar si se cuela exige **mirar la pantalla**, que es justo lo que yo no
  puedo hacer. Bajarlo a ciegas cambiaría CPU por un artefacto visible que descubriría
  braya y yo no. Queda para cuando alguien pueda verlo.

**APLAZADO — 3.3 #7, el cerebro reescribiendo sus JSON.** El hallazgo es correcto, pero
la auditoría lo dimensionó con el tope (`MAX_RECUERDOS = 5000`). Lo real hoy: **32
recuerdos y 31 vectores, 15,4 KB + 62,4 KB**. Reescribir 78 KB por turno no le quita
rendimiento a nada. Se vuelve grave cuando el cerebro crezca, así que queda anotado con
el umbral: **si `cerebro.json` pasa de ~1 MB, toca hacerlo** (no guardar en
`respuesta_directa`, agrupar, y sacar los vectores a binario).

### 3.3 La cápsula y los workers — HECHA (11 hallazgos)

Lo más grave no está en el dibujado, sino en **el camino de la voz**.

| # | Hallazgo | Sev. | Dónde | Arreglo más barato |
|---|---|---|---|---|
| 1 | Un plazo de voz vencido deja una `ReadLineAsync` huérfana: la frase siguiente recibe la ruta de la anterior (boca descuadrada) o revienta y la voz en línea se da por muerta **el resto de la sesión** | GRAVE | `assistant.ps1:7876` | Guardar la tarea en `$script:ttsLectura` y reutilizarla, como ya hace `Receive-Charla` |
| 2 | Si la voz falla, la escucha se queda **sorda hasta 90 s** con la cápsula gesticulando en silencio; y «cállate» no salva porque pasa por el micro pausado | GRAVE | `assistant.ps1:8163` | Bajar el techo de la estimación a ~12 s y dejar que la duración real la alargue |
| 3 | `Start-Sleep 250 ms` fijo en **cada frase**, en el hilo del bucle (1 s por charla de 4 frases). El mp3 además queda abierto y la caché no puede borrarlo | GRAVE (velocidad) | `assistant.ps1:7830` | Usar el evento `MediaOpened` en vez de la espera fija |
| 4 | «Pensando» es la única animación sin fin que quedó a 60 fps (9 relojes + órbita con sombra desenfocada), y es el estado que dura minutos | MEDIO | `nova_ui.cs:3828` | `SetDesiredFrameRate` a 15-20 fps: tres líneas |
| 5 | `CapturarFondo` duerme el hilo de la interfaz 45 ms **en cada orden**, justo cuando se quiere ver la reacción | MEDIO | `nova_ui.cs:1431` | `LockBits` en vez de ~530 `GetPixel`, y bajar el sleep |
| 6 | La caché de voz solo se poda **al arrancar**: el worker vive desde el login, así que el tope de 60 MB nunca se aplica en caliente | MEDIO | `tts_worker.py:107` | Podar cada N frases desde `principal()` → **HECHA** |
| 7 | El cerebro reescribe `cerebro.json` y `vectores.json` **enteros en cada turno** (~6 MB) aunque solo cambie `usos += 1`; y `completar_vectores` lo hace cada 16 vectores, en reposo y a batería | MEDIO | `charla_memoria.py:212` | No guardar en `respuesta_directa`; marcar sucio y agrupar |
| 8 | La cápsula lee **un solo evento por vuelta** de 80 ms: dos eventos seguidos y el primero se pierde (ya hubo un parche puntual por esto) | MEDIO | `assistant.ps1:8596` | Encolar en `Send-UIEvento` cuando el anterior no se ha consumido → **DESCARTADO, ver abajo** |
| 9 | El texto se corta a mitad de palabra (la voz sí corta bien) y la marquesina desplaza texto + copia desenfocada a 60 fps, ~7 s por respuesta larga | MEDIO | `assistant.ps1:8541` | Cortar por el último espacio, como ya hace `Get-TextoVoz` → **HECHA** |
| 10 | El revisor de memoria despierta **cada 3 s para siempre** (1.200/hora) y recorre 5.000 recuerdos para descubrir que no hay nada que hacer | LEVE | `charla_worker.py:663` | Sleep adaptativo 3 s → 30 s |
| 11 | La cápsula deja de anotar sus errores a partir del nº 50 **de toda la vida del proceso**, y al llegar a 200 KB borra el log en vez de rotarlo | LEVE | `nova_ui.cs:399` | Reiniciar el contador cada hora |

Cada hallazgo trae 5 mejoras ordenadas de más barata a más cara, con cómo medirlas.
### 3.4 Robustez y datos — HECHA (9 hallazgos)

| # | Hallazgo | Sev. | Dónde |
|---|---|---|---|
| 1 | **Un JSON de memoria ilegible no se aparta: se borra solo.** `Save-Corrupto` protege 5 de 13 archivos. Reproducido con `habitos.json` real cortado al 60 %: **18 usos → 0**, 4.768 B → 384 B, sin `.corrupto`. Afecta también a `estadisticas.json`, `juegos.json`, `rechazos.json`, `fechas.json` y `recordatorios.json` (catch vacío → caché vacía → el primer Save la escribe encima) | GRAVE | varios `Get-*` |
| 2 | **El barrido de workers huérfanos no encuentra ninguno desde el 14/09**: filtra `Name='python.exe'` pero `$PyWorker` es **pythonw.exe**. `charla_worker.py` no está en el filtro en ninguna versión. El log lleva 30 relanzamientos y 31 marcas huérfanas; en 8 GB eso se nota | GRAVE | `assistant.ps1:8329` |
| 3 | **`probar-autosordina.ps1` siempre sale verde**: el único de los 38 sin `exit 1`, y tres de sus cuatro casos imprimen el valor esperado sin compararlo | GRAVE | `tools\probar-autosordina.ps1` |
| 4 | **La sección 3 del banco solo comprueba que la línea exista, no el número**: una caída de 95 % a 5 % pasaría desapercibida | GRAVE | `tools\probar-todo.ps1` |
| 5 | `Save-Habitos`, `Save-JuegosMem` y `Add-HistorialMusica` no usan `Write-Atomico` | MEDIO | — → **DESCARTADO, ver abajo** |
| 6 | Un número mal escrito en `config.json` mata el arranque **antes de que exista `Log`** | MEDIO | → **HECHA** |
| 7 | El modo invitado tiene siete huecos (`Add-Traduccion`, `Add-Rechazo`…) y **no sobrevive a un reinicio** | MEDIO | — → **HECHA (la 1a mitad)** |
| 8 | Ninguna prueba toca `New-CopiaSeguridad` ni `Get-Cfg` | MEDIO | — |
| 9 | Verificado **sano** (para no perseguirlo): `$LASTEXITCODE` sí sobrevive a las tuberías `| Select-String`, y los 26 scripts con función de aserción usan bien `$script:` | — | — |

### 3.5 Decisiones tomadas al implementar (17/09)

- **HECHO — 3.4 #7, el modo invitado aprendia igual.** Y eran **11 huecos, no 7**.
  Nova dice "modo invitado, no aprendo nada ni miro tus cosas" y no era verdad: la guarda
  estaba en 6 funciones (estadisticas, habitos, perfil, musica, charla, ritmo) y faltaba en
  **todas las que aprenden de lo que se DICE**: diario (`Add-Memoria`, 4 caminos),
  **contactos**, fechas, rechazos, alias, recetas y sus variantes, notas de juego,
  traducciones y tiempo jugado.
  **Me equivoque a mitad de camino y conviene dejarlo escrito:** un primer analisis dijo que
  17 de 19 llamadas estaban protegidas porque su funcion contenedora mencionaba `invitado`.
  Era un falso positivo: `Invoke-FastCommand` ocupa **1.600 lineas** y sus dos unicas
  menciones cubren solo "leer los mensajes". Comprobar que la palabra aparece en la funcion
  no es comprobar que proteja **esa** llamada.
  **La guarda va en la puerta de cada funcion que guarda**, no repartida por los llamadores:
  asi no se puede olvidar al anadir un camino nuevo (mismo criterio que con `Get-Cfg`). Cada
  una devuelve lo que devolveria si no hubiera nada que guardar -`$false` donde se mira el
  resultado, `$null` donde se espera un objeto- para que el llamador no note la diferencia.
  23 casos en `probar-invitado.ps1` (2n18), y **la mitad que mas vale es la segunda**: si
  manana alguien anade una funcion de guardado y no la protege, la prueba falla hasta que
  decida -o la protege, o la declara exenta **con su motivo escrito**-. Ademas se ejecuta de
  verdad: con invitado no acumula tiempo de juego, y sin invitado sigue acumulando.
- **NO SE HACE — la 2a mitad de 3.4 #7, "no sobrevive a un reinicio".** Es cierto, y se
  queda asi a proposito. braya **odia los modos que se quedan activos**; un modo invitado que
  resucita despues de reiniciar es exactamente eso, y el fallo seria silencioso: Nova
  callada sin que nadie sepa por que. Hoy se quita solo a los 30 min sin ordenes y diciendolo
  ("se quita solo en media hora sin ordenes"). Si algun dia se persiste, tendria que ser con
  la hora guardada y **avisando al arrancar** de que sigue puesto.
- **DESCARTADO — 3.1 #7, "los audios de mas de 8 s nunca reciben small ni turbo".**
  Septimo, y este se cae leyendo lo que son. El tope (`REPASO_MAX = 8.0`) no es un descuido:
  el codigo ya explica por que esta ahi (12/09, small tardo 24 y 35 s con audios largos, con
  el plazo del asistente en 15 s y el hilo sordo todo ese rato).
  **Lo que hay dentro de esos 25 audios**, leidos uno a uno: conversacion y tele. "No, no
  llegaste a crear la nota, pero esta bien", "No te confundes, la musica electronica si me
  gusta", "Este senor abriendo de Estados Unidos paseado toda su tarjeta de credito vendio su
  carro". Pasados por la capa local, **se reconocen 3 de 25**.
  O sea: repasarlos costaria decenas de segundos de sordera para rescatar como mucho 3
  frases, y **varias de esas 3 son la tele hablando**. Repasar audios largos no solo seria
  lento: subiria las activaciones equivocadas, que es justo lo que braya no soporta. El tope
  ahorra tiempo y ademas protege.
  **La segunda mitad si es cierta** y se queda anotada: el camino Parakeet -> Whisper no
  lleva tope (`and not base` en la linea 526). Medido, es barato -1,3 s de mediana, p90
  3,8 s- con un solo caso extremo de 37,6 s, asi que no hay datos para justificar un tope
  todavia.
- **DESCARTADO — 3.3 #8, "la capsula pierde un evento si llegan dos seguidos".**
  Sexto. El mecanismo **es real**: `Send-UIEvento` sube `n` y reescribe el json al momento, y
  la capsula (cada 80 ms) dispara con `if (n != eventoN)` usando el `evento` que haya en ese
  instante; **no mira cuanto salto `n`**, asi que uno intermedio se perderia sin rastro.
  Lo que no hay es ningun sitio donde pueda pasar. De las 60 llamadas, solo 6 pares caen a
  menos de 12 lineas, y ninguno es un par de verdad:
  - `9058`/`9063` (`pulso:` / `aviso`) y `4924`/`4930`: **ramas de un `if/else`**, nunca se
    ejecutan las dos;
  - `12315`/`12326` y `13502`/`13511`: **el mismo evento** `hecho`, perder uno no cambia nada
    de lo que se ve;
  - `14216`/`14226` (`negar` / `asentir`): tambien ramas excluyentes, y el `else` **ya lleva
    `Start-Sleep 120`** con un comentario del 13/09 que explica justo este problema;
  - `4502`/`4510` (`sinia` / `aprendido`): el unico vivo, y lo separan tres operaciones de
    E/S (la tuberia de voz de `Say` y las dos escrituras json de `Add-VarianteReceta`).
  El caso que **si** paso en real -el `hecho` que pisaba al `aprendido`- ya tiene su parche.
  Y el arreglo propuesto ("encolar cuando el anterior no se ha consumido") **no se puede
  escribir**: el asistente no tiene canal de vuelta para saber si la capsula consumio nada.
  La alternativa -esperar ~100 ms dentro de `Send-UIEvento`- metería latencia en el hilo
  principal a cambio de un problema que no se ha visto ocurrir.
- **DESCARTADO — 3.4 #5, "tres sitios no usan `Write-Atomico`".** Quinto hallazgo
  que se cae al verificarlo. Es cierto en la letra -no llaman a la funcion- y falso en lo que
  importaba: **los tres hacen el patron atomico a mano**. `Save-Habitos`, `Save-JuegosMem` y
  `Add-HistorialMusica` escriben con `WriteAllText` a un `.tmp` y despues
  `Move-Item -LiteralPath ... -Force`, que es exactamente la rama final de `Write-Atomico`
  (esta intenta antes `File::Replace`, que aqui no aporta nada: `Replace` ni siquiera vale si
  el destino no existe, y por eso la propia funcion lo envuelve en un `Test-Path`).
  O sea: **no hay escritura directa sobre el archivo bueno**, que era el riesgo denunciado.
  Unificarlos seria tocar tres lineas que ya funcionan a cambio de nada.
- **NO SE ARREGLA (de momento) — 3.1 #5, sorda durante el repaso.** El mecanismo
  es cierto y el numero tambien: **3.033,2 s** descartados en total, y `transcribir_whisper`
  corre en el hilo del bucle, asi que Nova esta sorda mientras repasa y al terminar tira la
  cola. Pero medirlo cambia la decision.
  **Desglose del audio tirado por repaso** (el motivo del log es siempre "oido fino", pero
  `atender_reintento` lo llama por los tres caminos):
  | camino | total | veces | por evento |
  |---|---|---|---|
  | ultimo recurso | 688,8 s | 25 | **27,6 s** |
  | oido fino (small) | 691,6 s | 84 | 8,2 s |
  | whisper tras parakeet | 268,6 s | 123 | 2,2 s |
  El peor con diferencia era el **ultimo recurso, y Nova ya lo apago sola** (ver el bloque de
  autonomia): ese 41 % se va sin tocar una linea. Confirma ademas aquella decision por un
  motivo que no se habia contado: no solo ahorraba 16,2 s de espera por intento, tambien
  dejaba de tirar 27,6 s de audio cada vez.
  **Y el dano real es pequeno:** de los 84 repasos con hora, en 23 braya volvio a hablar en
  los 12 s siguientes, pero con **mediana de 6 s** -el repaso dura 4,6 s de mediana, o sea
  que ya habia terminado- y solo **2 de 84 (2,4 %)** cayeron en los 2 s siguientes, que es la
  unica ventana donde se pudo perder voz.
  Lo unico que lo arreglaria de verdad es sacar Whisper a otro hilo: el cambio mas
  arriesgado que se puede hacer en Nova (el hilo del audio) para recuperar 2 casos de 84. Se
  queda anotado con sus numeros por si el reparto cambia.
- **HECHO — 3.3 #6, la cache de voz solo se podaba al arrancar.** Cierto:
  `limpiar_cache()` se llamaba una vez, fuera de `principal()`, y el worker vive desde el
  login, asi que con Nova encendida el tope de 60 MB **no se aplicaba nunca**. Medido antes
  de tocar: la cache esta hoy en **13,8 MB con 487 mp3**, o sea al 23 % del tope, y a ~29 KB
  por frase faltan unas 1.600 frases nuevas para llegar. **Esto no rescata nada hoy**; sirve
  para no tener que vaciarla a mano dentro de unos meses, que es justo lo que se queria
  evitar cuando se puso el tope.
  **Lo que decidio el diseno fueron dos medidas, no la idea:**
  1. la poda cuesta **17,2 ms** con los 487 archivos de ahora (`listdir` + `stat`), asi que
     va **despues** de `print(ruta, flush=True)` -cuando el asistente ya tiene la ruta- y
     nunca delante de la voz: ahi serian 17 ms de retraso en cada frase;
  2. solo cuentan las frases **nuevas**, porque un acierto de cache no deja ningun archivo y
     podar entonces es trabajo para nada. `PODA_CADA = 50` son ~1,5 MB entre poda y poda.
  17 casos en `probar-cache-voz.py` (2n17). Los que mandan no son los de borrar: son los de
  **no** borrar `velocidad.txt` ni `ui-nivel.txt`, no llevarse el `.env` del que sobrevive, y
  el que comprueba que la poda **sigue estando detras** de la entrega de la ruta.
- **HECHO — 3.3 #9, el texto partido y la marquesina a 60 fps.** Dos mitades.
  **La que se ve:** `Set-UI` cortaba a 137 letras a pelo, o sea a mitad de palabra
  -"he abierto el esc..." por "el escritorio"-. La VOZ ya lo hacia bien **desde el 14/09**
  (`Get-TextoVoz` busca el final de una frase y si no el ultimo espacio): lo que se oia
  estaba cuidado y lo que se leia no. Ahora corta por el ultimo espacio, sin dejar coma ni
  punto colgando. Sacado a `Get-TextoCapsula` para poder ejecutarlo en una prueba sin montar
  media capsula; 12 casos en `probar-texto-capsula.ps1` (2n16), **uno de ellos demuestra que
  el corte viejo partia la palabra**, que es lo que hace que los otros 11 signifiquen algo.
  **La que se nota:** la marquesina dura `sobra * 10` ms -con una respuesta larga, unos 7 s-
  y van **dos animaciones a la vez**, el texto y su rastro desenfocado, las dos a 60 fps y
  **ninguna limitada**: era la animacion mas larga que quedaba suelta, y cae justo cuando
  Nova acaba de contestar. A 30 fps son la mitad de fotogramas compuestos; un texto que se
  desliza en linea recta no se distingue a 30. Un juego delante lo agradece mas que nadie.
- **HECHO — 3.2 #9, `Find-Traduccion` devolvia la primera, no la mas parecida.**
  Cierto en el codigo, pero **hoy no puede pasar**: hay 2 traducciones guardadas y no se
  parecen en nada (distancia ~25 sobre un tope de 5). Asi que esto no rescata ninguna orden y
  no se vende como tal; lo que quita es peor que un fallo normal: el resultado dependia del
  **orden del hashtable**, o sea que los mismos datos podian dar respuestas distintas en dos
  ejecuciones. Por eso el propio hallazgo decia "no se reproduce". Tres lineas, y el empate
  se rompe por orden alfabetico.
  **La leccion esta en la prueba, no en el arreglo.** El primer par que escribi
  (`sube el brillo` / `sube el brillo ya`) no demostraba nada: medido, el segundo queda a
  distancia 4 con tope 3, no entraba en el tope y por tanto **nunca competia**; esa prueba
  habria pasado igual con el codigo viejo. Se vio ejecutando el algoritmo anterior contra los
  dos ordenes: daba lo mismo. Con el par medido (`sube el brillo`, distancia 1, y
  `sube el brillos`, distancia 2, las dos dentro de su tope) el viejo da **`CON S` en un orden
  y `SIN S` en el otro**, y el nuevo siempre lo mismo. Una prueba que no se ha visto fallar no
  vale nada.
- **DESCARTADO — 3.1 #6, "la confianza se hereda de la orden anterior".** El
  cuarto hallazgo de la auditoria que se cae al verificarlo. El numero es correcto (42 de 188
  traen dato propio), pero la conclusion no: medido sobre las **144 ordenes en que gano
  Parakeet -las que supuestamente heredarian el dato- lo traen CERO**. Queda `None`, no
  heredado.
  Ya estaba protegido por cinco sitios: `_ultima_seguridad = None` en tres (`wake_vosk.py`
  764, 1343 y 1576, y los dos ultimos estan **justo antes de `if rapido:`**, o sea en el
  mismo camino que se denunciaba), mas el borrado de `dictado-confianza.txt` en dos
  (`assistant.ps1` 12638 y 12942). Y en PowerShell el valor si persiste en la variable, pero
  **ningun consumidor lo usa sin comprobar frescura**: 60 s en `Test-DictadoDudoso`, 15 s en
  los otros dos, y un `-999999` explicito antes de releer. La marca de tiempo era la
  proteccion que el hallazgo no vio.
  **Lo que si es cierto, como observacion y no como fallo:** 146 de 188 ordenes no tienen
  medida de confianza propia porque Parakeet no produce `avg_logprob`. El repaso por
  "dictado dudoso" no puede dispararse cuando gana Parakeet -por ausencia de dato, no por
  herencia-; esas ordenes tienen otra red, que es si `Test-FastCommand` las entiende.
- **HECHO — 3.2 #7, el pronombre tapaba otra orden.** El atajo de
  `abrelo` reescribe la frase ANTES de que llegue a su propio patron, y los patrones que
  empiezan igual estan cientos de lineas mas abajo. Resultado: era **mas grande de lo que
  decia el hallazgo**, no uno sino tres: `ponla siempre encima` (~2986), `ponle el volumen
  al 50` (~3005, la forma natural de esa orden) y `cierrala` (~2442, quitar la tarjeta).
  **Decidido con el log, no a ojo:** braya dice `abrelo` (4 veces) y **nunca** las otras, asi
  que el fallo es real por construccion pero no le ha mordido todavia; eso pide un arreglo
  conservador, no una reestructuracion. El atajo sigue valiendo cuando detras no hay otra
  orden: nada (`abrelo`), un donde (`abrelo en steam`) o relleno (`abrelo ya`).
  Sacado a `Resolve-Pronombre`, **fuera** de `Resolve-Fragment` (1.300 lineas), para que la
  prueba lo ejecute de verdad en vez de copiar el regex y creerselo. 17 casos en
  `probar-pronombres.ps1` (2n15), y los dos ultimos sujetan el porque: que la frase salvada
  **si** encaja con su patron, y que la que salia antes no encajaba con ninguno.
- **HECHO — 3.4 #6, un `config.json` mal escrito mataba el arranque.** Verificado
  entero antes de tocarlo: `[int]'mucho'` lanza, `$ErrorActionPreference='Stop'` esta en la
  linea 6, y **siete** de esas lecturas pasan antes de que `Log` exista (lineas 57-78; `Log`
  esta en la 95), asi que Nova moria sin dejar donde mirar. Son **52 lecturas**: se arregla
  en la unica puerta, `Get-Cfg`, no en 52 sitios. Importa mas desde ayer, porque ahora Nova
  **se escribe sola** en ese archivo.
  Aparecio algo que el hallazgo no decia y es peor, porque no avisa: `[bool]'loquesea'` **no
  lanza: devuelve `True`**. Un `"activada": "no"` se leia como activado, en silencio. Ahora
  se entienden si/no/true/false/1/0/on/off, y lo que no se entiende usa el de siempre.
  La regla es **rechazar lo que no encaja, nunca forzar el tipo**: forzandolo, una escala de
  1.25 con un default de 1 se habria convertido en 1. Eso tiene su propio caso en la prueba.
  De paso cae la mitad de **3.4 #8** (ninguna prueba tocaba `Get-Cfg`): 20 casos en
  `probar-config.ps1`, seccion 2n14 del banco.
- **HECHO — 3.2 #3, la voz de un vídeo creando reglas.** `Invoke-ReglaVoz` crea reglas,
  modos y recordatorios y devuelve en el acto, así que nunca llegaba a `Test-Rechazada`
  ni a `Test-VozExtrana`, unas 60 líneas más abajo. Y esas guardas no valían tal cual,
  porque miran `$acciones` y una regla no genera ninguna. Ahora se comprueba la voz
  **antes** de crear, con un patrón corto y conservador que solo decide si preguntar
  (duplicar aquí el regex largo de `Test-FastCommand` los habría separado con el tiempo).
- **NO SE ARREGLA — 3.2 #4, exigir «cuando» en el patrón de la hora.** El hallazgo es
  cierto, pero el arreglo propuesto es malo: el banco tiene
  `a las diez y media de la noche pon modo noche` como caso que **debe** funcionar
  (`pruebas\casos-nuevos.txt:81`). Exigir el prefijo convertiría una forma legítima y
  probada en un fallo. El riesgo real —que lo diga la tele— queda cubierto por la guarda
  de voz de arriba, que es donde había que atacarlo.
- **HECHO — 3.4 #2, el barrido de huérfanos.** Filtraba `Name='python.exe'` y los workers
  son `pythonw.exe` desde el 14/09: llevaba tres días sin encontrar ni uno. Ahora acepta
  los dos nombres y añade `charla_worker.py`, que faltaba y es el que más RAM gasta.
- **HECHO — 3.4 #1, #3 y #4**: los seis lectores de JSON que faltaban ya apartan el
  archivo dañado, el banco compara la cifra y `probar-autosordina.ps1` comprueba de
  verdad. Al arreglar esta última, sus 10 casos pasaron a la primera: **la función
  siempre estuvo bien, lo roto era el vigilante.**
- **HECHO — 3.2 #1**: el bug del volumen a cero.

- **HECHO — 3.2 #5, una regla disparada tenía carta blanca.** Se cierran **dos** puertas
  con el **mismo** criterio que ya usaba el camino de costumbres (dos listas distintas
  acabarían separándose): al **crear** la regla hablada, para que no llegue a existir; y
  al **dispararla**, porque una regla guardada antes de este cambio —o escrita a mano en
  `reglas.json`— llegaba igual a `$script:confirmado = $true` y se ejecutaba sin que
  nadie pudiera pararla.
  **Excepción `di ...`:** el filtro no se aplica a las acciones que solo hablan. El banco
  cazó la regresión en cuanto la metí: «cuando termine de cargar avísame» se convierte en
  «di ya esta cargada del **todo**», y el regex la rechazaba por esa palabra. El filtro es
  para lo que **hace**, no para lo que dice.

- **HECHO — 3.2 #6, las recetas se probaban antes del filtro de voz.** `Find-Receta`
  corría ~75 líneas antes de comprobar si la voz era de braya, y las de tipo `info` se
  lanzaban sin preguntar nada (una receta puede acabar ejecutando PowerShell). Ahora la
  comprobación va **antes** de la rama `info`, con el mismo criterio que las reglas.
- **HECHO — 3.2 #2, la prueba que faltaba.** No ejecuta las 113 ramas (abrirían programas
  y apagarían el equipo): compara, para cada acción, los campos que el productor **escribe**
  con los que su rama **lee**. Entra en el banco como 2n12.
  **Me costó cinco intentos y dos de ellos habrían pasado por buenos**: la validé contra
  una copia con el bug del volumen reintroducido y las dos primeras versiones decían
  «todo correcto» igual. Los fallos fueron míos, y quedan escritos en el archivo: una
  ventana de 1500 caracteres que tapaba el bug que buscaba, y juntar los cuatro
  productores de `volumenPct` en bloque cuando el roto era **uno** de los cuatro.
  Una prueba que no se ha visto fallar no vale nada.

---

## 4b. Que Nova se controle sola (17/09)

braya: «no solo controlarla yo, sino que ella se pueda controlar, tomar decisiones por
ella misma sin que yo tenga que despertarla».

**El hueco, medido:** Nova tiene **diez vigilantes** y nueve decisiones propias, pero
`Set-Cfg` —lo único que cambia su configuración— **solo se llamaba desde órdenes suyas**
(esquina, color, escala, voz, «solo yo»). Y `destinos.jsonl` solo se escribía: nadie lo
leía si braya no lanzaba `analizar-uso.py` a mano. Sabía lo que le pasaba y no se miraba
nunca.

**HECHO — se revisa a sí misma y apaga lo que no le sirve.** Una vez al día, en reposo,
sin juego ni invitado: mira sus estadísticas de 14 días y decide. El primer caso sale de
sus propios números, no de mi criterio: el último recurso (turbo) se lanzó **29 veces y
sirvió 1**, costando 16,2 s de mediana.
Tres frenos, porque una máquina que se toca sus ajustes da más respeto que pereza:
necesita **historial** (con menos de 20 intentos no juzga), decide **una vez al día**, y
**lo dice en voz alta** con sus números y cómo deshacerlo. 16 casos en
`probar-revision-propia.ps1` (2n13), y los que más importan son los que comprueban lo que
**no** debe hacer: con 10 útiles de 29 **no lo toca**.

**HECHO - y se deshace hablando (idea 10 de autonomia).** Darle el poder de cambiarse un
ajuste y no darle el deshacer por voz era dejar montado justo lo que braya odia: un ajuste
que se pone solo y que solo se quita editando `config.json`. Ahora cada decision se apunta
**con su valor de antes** y se revierte diciendolo: «deshaz lo que has cambiado», «deshaz
lo que cambiaste», «vuelve a poner el ultimo recurso». Y «deshaz» a secas, cuando no hay
nada tuyo pendiente, deshace lo suyo - contestar «no hay nada que deshacer» seria mentira.
Lo tuyo manda: si hay algo tuyo en la pila, eso va primero y su ajuste queda pendiente.
Ademas, si se lo devuelves, **ese dia no lo vuelve a apagar**; si no, revisarse por la
tarde y apagarlo otra vez seria ponerse a discutir contigo.

Dos detalles que costaron mas que el resto:
- **La decision se guarda en dos sitios y ninguno sobra.** `Get-Cfg` lee `$cfg`, la copia
  cargada AL ARRANCAR, y `Set-Cfg` escribe el archivo sin refrescarla: recien tomada la
  decision, preguntarle a `Get-Cfg` devolveria vacio, que es justo cuando mas se pide
  deshacerla. Variable viva para esta sesion, `config.json` para despues de reiniciar.
- **El orden de los patrones.** El «deshaz» de toda la vida termina en ``, sin ancla
  final, asi que se come «deshaz lo que has cambiado» entera. El patron nuevo va delante, y
  hay un caso que comprueba que sigue delante - y otro que demuestra que el generico se la
  habria comido, que es lo que explica por que el orden importa.

**DESCARTADO — 3.2 #8, «`Test-FastCommand` lee el escritorio y escanea siete carpetas».**
No es cierto: los tres accesos a disco de `Resolve-Fragment` están dentro de `if` con
regex específicos (solo se leen si preguntas por el escritorio), y `Resolve-Proceso` —que
se llama 11 veces— **no enumera procesos**, solo mira `commands.json` en memoria. Lo único
cierto del punto es que toca `$script:dudosa`, aunque lo restaura. Tercer hallazgo de la
auditoría que se cae al verificarlo.

**BLOQUEADO — autoajustar el tope de la nube.** Era el candidato obvio, pero
`nube-sirvio` y `nube-tarde` **no tienen ni un dato** en las estadísticas (solo
`nube-nada: 1`). Sin datos no hay decisión: sería inventármela.

---

## 4c. Una IA de pago (OpenRouter) junto a Gemini: medido antes de pagar (17/09)

braya pregunto si merece la pena poner una IA de OpenRouter que haga lo mismo que las
locales, y cuanto uso le daria de verdad.

**Lo primero: OpenRouter enruta modelos de TEXTO, no transcribe audio.** No puede sustituir
a Vosk, Parakeet ni Whisper. Gemini esta donde esta porque **oye** (`tools\gemini-oir.py`).

**El volumen, medido:** 188 ordenes con audio en 2 dias (~94/dia), 38 letras por orden
(~10 tokens). Aunque fueran a la nube solo los fallos, son ~25-35 llamadas al dia: del orden
de 1-2 millones de tokens al mes. **El dinero no es el problema** (centimos o pocos dolares
al mes segun el modelo).

**El problema es que no ataca el cuello.** Los errores acumulados son 38, y al mirarlos uno
a uno **son de OIDO, no de entendimiento**: los recientes son todos `dictado vacio` -no
llego texto ninguno, asi que no hay nada que interpretar- y los descartes son
transcripciones rotas: "un palo y un caso de", "calle sesena y va", "aun es que tu la
espantaya". Un modelo de texto no puede arreglar lo que no se oyo.
El margen de entendimiento ya es minimo: la capa local acierta **183/186 y 88/89**.

**Donde SI podria ganar algo:** frases mal transcritas pero adivinables por contexto, del
tipo "mueve y state 2 a la capeta games" -> "mueve It Takes Two a la carpeta games". Son un
punado, y con el riesgo de inventar (`fino-invento`: 5 de 81 ya hoy).

**Y antes de anadir una segunda nube hay que explicar la primera:** Gemini se llamo 29 veces
y las estadisticas dicen `nube-nada: 1` y **cero** `nube-sirvio`. Mas el precedente del
ultimo recurso: 29 intentos, sirvio 1, y Nova lo apago sola.

---

## 5. Orden de ataque propuesto

Por daño real a braya, no por facilidad:

1. **Los JSON que se borran solos** (3.4 #1) — es pérdida de datos silenciosa y ya reproducida.
2. **Las pruebas que mienten** (3.4 #3 y #4, 3.2 #2) — mientras el banco pueda dar verde en falso, nada de lo demás es fiable. Incluye la prueba que ejecuta acciones de verdad, que es lo que habría cazado el bug del volumen.
3. **Las reglas y recetas sin guardas** (3.2 #3, #4, #5, #6) — la voz de un vídeo creando reglas, y una regla disparada ejecutando cosas destructivas sin preguntar.
4. **El barrido de huérfanos roto** (3.4 #2) — 30 relanzamientos acumulados en una máquina de 8 GB.
5. **La voz: lectura huérfana y sordera de 90 s** (3.3 #1 y #2).
6. **La ganancia atascada y el recorte del micro** (3.1 #1, #2, #3) — lo de ayer no está cerrado del todo.
7. El resto, por coste.

*(Los informes completos, con las 5 mejoras de cada hallazgo y cómo medirlas, están en el
scratchpad de la sesión: `informe-oido.md`, `informe-ordenes.md`, `informe-capsula.md` e
`informe-robustez.md`.)*

---

## 4. Lo que ya sabíamos que fallaba (arreglado hoy, por si vuelve)

- **La calibración del micro se tiraba en cada arranque** (38 veces). Causaba las dos
  quejas a la vez: se activaba sola con ruido y no oía a braya. Blindado en
  `tools\probar-escucha.py`.
- **Un juego con nombre vacío se llevaba cualquier orden** (`$q -match '\b\b'` casa
  siempre). Encontrado montando las primeras pruebas de `Find-JuegoEn`, que no tenía
  ninguna pese a su historial.
- **Un banco que cambiaba de color según la hora**: `probar-entorno.ps1` daba 12 fallos
  falsos de madrugada, y uno de sus OK era falso.
