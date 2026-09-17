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
| 5 | **Durante el repaso está sorda y tira el audio**: 3.033 s descartados, y `atender_reintento` corre antes de mirar `dictar.flag` — justo cuando braya repite tras un «no te entendí» | MEDIO | `wake_vosk.py` |
| 6 | La confianza de Whisper **se hereda de la orden anterior** cuando gana Parakeet: solo 42 de 188 traen dato propio | MEDIO | — |
| 7 | Los audios de más de 8 s nunca reciben small ni turbo (25 de 188), y el camino Parakeet→Whisper no tiene ningún tope | MEDIO | — |
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
| 7 | El atajo de pronombres convierte «ponla siempre encima» en «pon spotify siempre encima» y acaba **abriendo Spotify** | MEDIO | `assistant.ps1:2190` |
| 8 | `Test-FastCommand` (que valida todo y corre sobre los parciales **mientras hablas**) lee el escritorio, escanea siete carpetas y toca el estado de la cápsula | MEDIO | — |
| 9 | `Find-Traduccion` devuelve la **primera** clave dentro del tope, no la más cercana: el resultado depende del orden del hashtable (fallo que no se reproduce) | MEDIO | `assistant.ps1:6105` |
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

**PENDIENTE — 3.3 #1, la `ReadLineAsync` huérfana.** Sigue sin tocar. Es el otro GRAVE de
la voz: un plazo vencido deja la lectura viva sobre la tubería y la frase siguiente puede
recibir la ruta de la anterior, o reventar y dejar la voz en línea por muerta el resto de
la sesión.

### 3.3 La cápsula y los workers — HECHA (11 hallazgos)

Lo más grave no está en el dibujado, sino en **el camino de la voz**.

| # | Hallazgo | Sev. | Dónde | Arreglo más barato |
|---|---|---|---|---|
| 1 | Un plazo de voz vencido deja una `ReadLineAsync` huérfana: la frase siguiente recibe la ruta de la anterior (boca descuadrada) o revienta y la voz en línea se da por muerta **el resto de la sesión** | GRAVE | `assistant.ps1:7876` | Guardar la tarea en `$script:ttsLectura` y reutilizarla, como ya hace `Receive-Charla` |
| 2 | Si la voz falla, la escucha se queda **sorda hasta 90 s** con la cápsula gesticulando en silencio; y «cállate» no salva porque pasa por el micro pausado | GRAVE | `assistant.ps1:8163` | Bajar el techo de la estimación a ~12 s y dejar que la duración real la alargue |
| 3 | `Start-Sleep 250 ms` fijo en **cada frase**, en el hilo del bucle (1 s por charla de 4 frases). El mp3 además queda abierto y la caché no puede borrarlo | GRAVE (velocidad) | `assistant.ps1:7830` | Usar el evento `MediaOpened` en vez de la espera fija |
| 4 | «Pensando» es la única animación sin fin que quedó a 60 fps (9 relojes + órbita con sombra desenfocada), y es el estado que dura minutos | MEDIO | `nova_ui.cs:3828` | `SetDesiredFrameRate` a 15-20 fps: tres líneas |
| 5 | `CapturarFondo` duerme el hilo de la interfaz 45 ms **en cada orden**, justo cuando se quiere ver la reacción | MEDIO | `nova_ui.cs:1431` | `LockBits` en vez de ~530 `GetPixel`, y bajar el sleep |
| 6 | La caché de voz solo se poda **al arrancar**: el worker vive desde el login, así que el tope de 60 MB nunca se aplica en caliente | MEDIO | `tts_worker.py:107` | Podar cada N frases desde `principal()` |
| 7 | El cerebro reescribe `cerebro.json` y `vectores.json` **enteros en cada turno** (~6 MB) aunque solo cambie `usos += 1`; y `completar_vectores` lo hace cada 16 vectores, en reposo y a batería | MEDIO | `charla_memoria.py:212` | No guardar en `respuesta_directa`; marcar sucio y agrupar |
| 8 | La cápsula lee **un solo evento por vuelta** de 80 ms: dos eventos seguidos y el primero se pierde (ya hubo un parche puntual por esto) | MEDIO | `assistant.ps1:8596` | Encolar en `Send-UIEvento` cuando el anterior no se ha consumido |
| 9 | El texto se corta a mitad de palabra (la voz sí corta bien) y la marquesina desplaza texto + copia desenfocada a 60 fps, ~7 s por respuesta larga | MEDIO | `assistant.ps1:8541` | Cortar por el último espacio, como ya hace `Get-TextoVoz` |
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
| 5 | `Save-Habitos`, `Save-JuegosMem` y `Add-HistorialMusica` no usan `Write-Atomico` | MEDIO | — |
| 6 | Un número mal escrito en `config.json` mata el arranque **antes de que exista `Log`** | MEDIO | — |
| 7 | El modo invitado tiene siete huecos (`Add-Traduccion`, `Add-Rechazo`…) y **no sobrevive a un reinicio** | MEDIO | — |
| 8 | Ninguna prueba toca `New-CopiaSeguridad` ni `Get-Cfg` | MEDIO | — |
| 9 | Verificado **sano** (para no perseguirlo): `$LASTEXITCODE` sí sobrevive a las tuberías `| Select-String`, y los 26 scripts con función de aserción usan bien `$script:` | — | — |

### 3.5 Decisiones tomadas al implementar (17/09)

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
