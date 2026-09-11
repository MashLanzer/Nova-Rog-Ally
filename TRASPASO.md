# TRASPASO: Asistente de voz por botón en ASUS ROG Ally

> Documento autocontenido para delegar a otra IA o retomar el proyecto.
> Carpeta: **`C:\Users\braya\Documents\voice-ctrl`**
> Última actualización: **2026-09-10, noche** (palabra de activación «Nova»,
> interfaz de cristal `nova_ui.exe`, traducción aprendida, temporizadores,
> repositorio en GitHub). Las secciones 15-17 son las más recientes.

---

## 1. OBJETIVO

Controlar el ASUS ROG Ally **por voz, en segundo plano**: decir **«Nova»** (o
mantener pulsado el botón `≡` del mando) → se abre el dictado y el usuario
habla → al callar, la orden se ejecuta y el asistente **responde hablando**.
La cara visible es una cápsula de cristal en la esquina inferior izquierda (§16).

Usuario: `braya`. Windows 11 build 26200, Windows PowerShell 5.1.
Mando integrado de la ROG Ally. El habla es **español latinoamericano**.

---

## 2. ENTORNO / HECHOS IMPORTANTES

- **CLI headless de opencode**:
  `C:\Users\braya\AppData\Roaming\npm\node_modules\opencode-ai\bin\opencode.exe`
  - `node` v24.19.0 en `C:\Program Files\nodejs` (**no está en el PATH** → el
    asistente lo añade al arrancar).
  - Invocación correcta: `opencode.exe run --auto --dir "<dir>" -- "<texto>"`
  - Arranque en frío medido: **16-149 s**. Timeout: 240 s.
- **Desktop app opencode**: su servidor usa puerto+password no legibles desde
  otro proceso → vía DESCARTADA.
- **Windows MCP** configurado en `C:\Users\braya\.config\opencode\opencode.jsonc`.
- **Dictado de Windows** en español, se activa con **Win+H**.
- **Python 3.12.10** en `%LOCALAPPDATA%\Programs\Python\Python312` (lo usa el
  worker de voz).
- XInput vía P/Invoke en `assistant-dx.dll` (clase `AX`). Fuente: `assistant-dx.cs`.

---

## 3. DESCUBRIMIENTO CRÍTICO SOBRE LOS BOTONES (XInput)

- En **modo escritorio**, la Ally solo expone a XInput los dos botones del
  marco: `≡` = START (0x0010) y el izquierdo = BACK/VIEW (0x0020).
- **RB/LB/Y/B/cruceta/L3/R3/LT/RT NO llegan** (ASUS/ACSE los remapea).
  Calibrado con `tools\diag\diag-buttons.ps1`.
- `≡` + el botón izquierdo juntos disparan un acceso rápido de ASUS → no usar.
- Disparador vigente: **mantener `≡` ~1,1 s**.

---

## 4. ARQUITECTURA / FLUJO ACTUAL

Un **único proceso** (`assistant.ps1`), **máquina de estados no bloqueante**,
y varios procesos hijos que se comunican con él **solo por archivos en `tmp\`**
(nunca por hilos: §11): `wake_vosk.py` (palabra de activación), `tts_worker.py`
(voz), `nova_ui.exe` (interfaz), opencode cuando toca, Piper si se usa.

```
[ decir "nova" ]  ó  [ mantener ≡ 1,1 s ]
  → bip + cápsula verde con onda + Win+H (dictado de Windows)
[ el usuario habla ]
  → la cápsula va mostrando la TRANSCRIPCIÓN EN VIVO
[ callar 2,5 s  (o mantener ≡ = "enviar ya") ]
  │
  ├─ "pregúntale a la IA …" → charla con --continue (recuerda lo hablado)
  ├─ RUTA LOCAL (Invoke-FastCommand)  ── <1 s, sin LLM ──────────────
  │    reconoce la orden entera → la ejecuta → cápsula azul + voz
  ├─ PREGUNTA ($RE_PREGUNTA) → modelo sin herramientas ── ~13 s
  ├─ TRADUCCIÓN APRENDIDA (traducciones.json) → local ── <1 s
  ├─ TRADUCIR: el modelo la convierte a una orden conocida ── ~13 s
  │    se valida con Invoke-FastCommand y se APRENDE. El modelo responde
  │    con la orden, con TAREA (es una petición, pero no de las locales)
  │    o con NO (no era una orden: audio de fondo) → se DESCARTA ahí.
  └─ AGENTE COMPLETO ── 25-160 s ── solo si el modelo dijo TAREA ──────
       Start-OpencodeJob lanza opencode.exe y retorna al instante
       cápsula ámbar "Procesando..." (mantener ≡ = cancelar, taskkill /T)
       [ el bucle SIGUE sondeando el botón cada 30 ms ]
       → al terminar: cápsula azul + voz + replies.log
```

Decisiones de diseño deliberadas:

- **Un solo hilo.** Se descartó usar runspaces: los objetos WinForms
  (`$capture`, `$lbl`) **no son thread-safe**. El bucle principal planifica.
- **Llamada directa al CLI**, sin `powershell.exe` intermedio (§11).
- **El popup no bloquea**: se cierra por plazo desde el bucle.
- **La ruta local es todo-o-nada**: media orden ejecutada es peor que ninguna.
- **Al agente no se llega por descarte, sino por veredicto.** Antes, todo lo
  que nadie entendía terminaba en el agente con `--auto`: el micrófono captaba
  un vídeo de fondo y esa frase se ejecutaba con permiso sobre `Documents`
  (37 veces solo el 11/09). Ahora quien decide es el traductor, que ya estaba
  en el camino y no cuesta latencia extra.

---

## 5. AUTOARRANQUE (funciona — NO CAMBIAR)

`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
`VoiceAssistantController` =

```
powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\braya\Documents\voice-ctrl\assistant.ps1"
```

> `assistant.ps1` **debe permanecer en la raíz**. No moverlo a `src\` sin
> actualizar esta clave del registro.

---

## 6. CAPA DE COMANDOS LOCALES

**Por qué existe:** «abre steam» tardaba **35 s** pasando por el agente, que
tomaba capturas de pantalla para algo que Windows resuelve en milisegundos. Una
orden de dos pasos tardó **163 s**. Medido tras el cambio: **500 ms**.

**Regla de oro — todo o nada:** si CUALQUIER fragmento no se reconoce, no se
ejecuta NADA y la frase entera va a opencode.

### Proceso de una frase

1. **Normalizar**: minúsculas, sin tildes.
2. **Corregir**: `commands.json → correcciones` («painterest» → «pinterest»).
3. **Separar**: corta en `y`, `,`, `luego`, `después`.
   - «además»/«también» separan **solo si les sigue un verbo**; si no son
     muletillas. Esto arregló «…y gato **Además** sube el volumen».
   - Si un fragmento no empieza por verbo (ni por lugar ni por orden de
     ventana), se reengancha al anterior: por eso `busca gatos y perros en
     google` NO se parte.
4. **Resolver** cada fragmento a una o varias acciones.

### Gramática reconocida (español latinoamericano)

- **Abrir**: `abre`, `ábreme`, `ábrele`, `abrí`, `ejecuta`, `inicia`, `lanza`,
  `arranca`, `prende`, `ponme`, `ponle`, `métete a`, `entra a`, `anda a`,
  `vete a`, `llévame a`, `muéstrame`.
- **Buscar**: `busca`, `búscame`, `googlea`, `investiga`.
  - `busca X en <sitio>` y también **el lugar ANTES del verbo**:
    `en youtube busca X`, `en el navegador busca X`.
  - Si lo pedido es un **sitio conocido**, lo ABRE en vez de buscarlo:
    «busca pinterest» → abre Pinterest. Solo busca si nombraste un buscador
    («busca gatos en youtube») o si es texto libre.
- **Juegos de Steam**: `abre little nightmares 3 en steam`, o el título suelto.
- **Niveles**: `sube`/`súbele`/`aumenta`, `baja`/`bájale`/`reduce`, `pon`,
  sobre **volumen** y **brillo**, con `al máximo`/`al mínimo` o **porcentaje
  exacto** (`baja el volumen al 50%`, `pon el brillo al 20 por ciento`).
  El porcentaje se busca **por objetivo**: «el volumen al 50% y el brillo al
  80%» pone cada uno en lo suyo. Con un único número global los ponía iguales.
  El volumen exacto se logra bajando a cero y subiendo N pasos (Windows mueve
  de 2 % en 2 %); el brillo sí es exacto, por WMI.
  > Ojo: `pon` también es verbo de abrir. Si la frase no menciona volumen ni
  > brillo, **debe caer al resto de la función**, no devolver `$null`, o
  > «ponme spotify» dejaría de funcionar.
- **Historial**: `repite`, `qué me dijiste`, `última respuesta` → repite la
  última respuesta, sea local o del agente.
- **Ventanas**: `a mitad de pantalla`, `a la izquierda`, `a la derecha`,
  `maximiza`, `minimiza` (Win+flechas). No llevan verbo, así que están
  registradas como inicio válido de fragmento.
- **Multimedia**: `pausa`, `reproduce`, `siguiente`, `anterior`, `silencia`.
- **Sistema**: `bloquea`.
- **Memoria**: `recuerda que…`, `anota…`, `apunta…` (§8).
- **Sin verbo**: decir solo `steam` o `youtube` ya abre.
- **Cortesía y muletillas**: `puedes…`, `por favor`, `porfa`, `oye`, `dale`,
  y arranques del dictado como `y a mí…`, `ya me…`, `pues…`.

### Tolerancia a los errores del dictado

El dictado deforma nombres sin parar («Team», «steamidos», «buscal»). Hay tres
capas, en este orden:

1. Tabla de `correcciones` en `commands.json`.
2. **Coincidencia aproximada** (Levenshtein) para apps y sitios, **solo si el
   objetivo tiene 3 palabras o menos**. Ese límite es importante: sin él,
   «Freelesign en el navegador buscal Pinterest» encontraba «navegador» dentro
   y abría el navegador ignorando el resto.
3. **Reparación del verbo**: solo la primera palabra y solo a distancia 1
   («buscal» → «busca»). Más margen inventaría órdenes.

Verificado que NO produce falsos positivos: `documento`, `puerta`, `ventana`,
`correo`, `canción`, `carpeta`, `música` no coinciden con nada.

### Juegos de Steam

Se lee la biblioteca del disco (`appmanifest_*.acf`) y se indexa al arrancar.
Los números romanos se normalizan («III» ↔ «3»), así que «little nighters 3»
encuentra *Little Nightmares III*.

**Juegos instalados después de arrancar**: cuando se pide un juego que no está
en el índice, se **relee la biblioteca y se reintenta** antes de rendirse, con
tope de una relectura por minuto. No hay que reiniciar nada.

| Operación | Coste |
|---|---|
| Releer la biblioteca | 133 ms |
| Consulta con relectura | 177 ms |
| Consulta sin relectura | 24 ms |

Ojo con la puntuación: se evalúan TODOS los títulos y se elige el mejor.
Devolver el primero que «contenía» el nombre hacía que «outlast 2» abriera
*Outlast*.

---

## 7. VOZ (TTS)

**Cadena de respaldo: en línea → Piper → Windows.** Si se cae la red sigue
habiendo voz; si falla todo, la voz vieja de Windows.

| Motor | Frase nueva | Repetida | Offline |
|---|---|---|---|
| **edge-tts en línea** (en uso) | 778-1.332 ms | **1-2 ms** | no |
| Piper (persistente) | 221-315 ms | — | sí |
| Voz de Windows | ~60 ms | — | sí |

Configurado en `config.json → voz`. Voz actual: **`es-MX-DaliaNeural`**.
Alternativas probadas: `es-MX-JorgeNeural`, `es-US-AlonsoNeural`,
`es-CO-SalomeNeural`.

### Por qué NO se usan las voces "Natural" de Windows

Se instaló **Dalia** desde Narrador y el paquete existe
(`MicrosoftWindows.Voice.es-MX.Dalia.1`), pero **Windows no la expone a las
aplicaciones**: su `Tokens.xml` la registra bajo
`HKLM\SOFTWARE\Microsoft\Speech Server\v11.0`, y **esa clave ni siquiera
existe** en esta máquina. Las apps leen `Speech_OneCore`, donde solo están las
viejas (Helena, Laura, Pablo). Registrarla a mano exige admin y no está
garantizado. **No perder tiempo en esto otra vez.**

### Detalles de implementación

- El worker (`tts_worker.py`) se mantiene **vivo**: arrancar Python por frase
  costaba 2,5-4,4 s.
- **Caché por hash** del texto en `tmp\voz\`. Sobrevive a reinicios y hace que
  «Anotado.» o «Abriendo Steam.» salgan en 2 ms.
- Los MP3 se reproducen con **`System.Windows.Media.MediaPlayer`** (WPF,
  `Play-Audio`). Antes se usaba MCI (`AX::PlayMp3`) y **reportaba éxito sin
  emitir sonido**: el asistente estuvo mudo un buen rato sin que nadie lo
  notara. MediaPlayer funciona en el bucle WinForms sin Dispatcher propio
  (hay un `Start-Sleep 250` tras `Open` para que cargue). MCI queda de respaldo.
- `ReadLineAsync` con tope de 8 s: si la red se cuelga, el bucle no se bloquea.

---

### Las cuatro rutas (el asistente elige sola, sin modos)

| Frase | Ruta | Coste |
|---|---|---|
| `abre steam`, `sube el volumen`, `recuerda que…` | Local | < 1 s |
| `qué hora es`, `cuánta batería`, `repite` | Local | < 1 s |
| `quién inventó el ajedrez` (`$RE_PREGUNTA`) | Modelo, **sin herramientas** | ~13 s |
| `pregúntale a la IA …` | Charla con `--continue` (recuerda la anterior) | ~13 s |
| orden no reconocida, ya traducida antes | `traducciones.json` → local | < 1 s |
| orden no reconocida, primera vez | Modelo la **traduce** a una orden conocida; se valida y se aprende | ~13 s |
| `crea un archivo en el escritorio` | Agente completo (si no se pudo traducir) | 25-160 s |

**Respuestas instantáneas** (no van al modelo): hora, fecha, batería, número de
juegos, notas del día, repetir la última respuesta. Preguntar la hora a un LLM
cuesta 13 s y encima puede negarse a contestar — se comprobó.

> **NO reintroducir un "modo conversación" persistente.** Se probó y fue un
> error: al quedarse activo se tragaba las órdenes («Abre steam» acabó en el
> modelo, que además se negó a ejecutarlo porque el prompt le prohibía usar
> herramientas). Todo lo que dependa de un estado pegajoso tiene ese riesgo.
> `opencode run --continue` sí encadena sesiones y recuerda (verificado), así
> que si algún día se quiere charla, debe activarse **por frase**, nunca por
> modo.

---

## 8. MEMORIA PERMANENTE (vault de Obsidian)

Carpeta: **`voice-ctrl\memoria`**. Se abre en Obsidian con *Abrir carpeta como
almacén*. No es contexto de conversación: son archivos Markdown que sobreviven
a todo y que el usuario puede leer y editar.

| Acción | Quién | Coste |
|---|---|---|
| **Guardar** — «recuerda que…» | local, sin LLM | < 1 s |
| **Recordar** — «¿qué sabes de…?» | opencode leyendo la carpeta | 25-60 s |

- Guardar escribe en `memoria\diario\AAAA-MM-DD.md` con la hora.
- **Se guarda el texto TAL CUAL se dijo**, con mayúsculas y acentos: la captura
  se hace sobre el texto original, antes de normalizar. Si se dejara pasar por
  la normalización, las notas quedarían en minúsculas y sin tildes.
- Al preguntar, `Expand-Prompt` detecta la intención y le dice a opencode dónde
  mirar y que responda **breve y hablado**, porque se lee en voz alta.

---

## 9. RENDIMIENTO: POR QUÉ NO SE USA `serve` + `--attach`

Investigado a fondo. **Conclusión: no sirve. No reintentarlo sin leer esto.**

| Medición | Resultado |
|---|---|
| `opencode serve --port 4096` | arranca en 2 s (avisa: sin password) |
| `run --attach` | 3,7-15 s (vs 24,6 s en frío) — más rápido |
| stdout de `--attach` | **0 bytes: la respuesta NO vuelve** |
| `--attach --format json` | solo un evento `step_start` |
| API HTTP directa | existe (162 rutas); sesión + prompt = 0,6 s |
| `POST /api/session/{id}/wait` | `"Session wait is not available yet"` |

`--attach` envía el mensaje y **sale sin esperar**. Como el asistente lee
stdout, sería más rápido pero mudo.

---

## 10. ARCHIVOS

```
voice-ctrl\
  assistant.ps1        # asistente principal (NO MOVER: la clave Run lo apunta)
  assistant-dx.dll     # P/Invoke: XInput, teclado, ForceForeground, PlayMp3
  assistant-dx.cs      # fuente del DLL
  config.json          # rutas, tiempos, voz, logs
  commands.json        # vocabulario local  <- AMPLIAR AQUÍ
  tts_worker.py        # worker de voz en linea (persistente + cache)
  wake_vosk.py         # worker de palabra de activacion (y dictado Vosk) §15
  wake_worker.cs/.exe  # alternativa SAPI en C#, no se usa (escucha.motor=sapi)
  nova_ui.cs/.exe      # interfaz: capsula de cristal WPF §16
  traducciones.json    # ordenes aprendidas (se crea sola)
  run-opencode.ps1     # runner suelto; ya NO se usa, sirve para probar el CLI
  memoria\             # vault de Obsidian (§8)
  piper\               # TTS offline de respaldo (97 MB)      [no en git]
  vosk\                # modelo es-ES pequeno de Vosk (~40 MB) [no en git]
  tmp\                 # temporales y archivos-marca; tmp\voz = cache de audio
  tools\compilar-ui.ps1   # recompila nova_ui.exe
  tools\subir-a-github.ps1# push desde una consola real (pide credenciales)
  tools\aprende-descartes.ps1 # que no reconocio la capa local
  tools\diag\          # diag-buttons.ps1 (calibrador), diag-escucha, diag-vosk
  legacy\voicedict.ps1 # script antiguo, referencia
  assistant.log        # eventos      replies.log  # respuestas completas
```

Repositorio: **https://github.com/MashLanzer/Nova-Rog-Ally** (público). Git en
`C:\Program Files\Git\cmd\git.exe` (no está en el PATH de la terminal del
asistente). Los `.exe` compilados SÍ se suben, para que clonar sea usable.

Recompilar el DLL:

```powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" `
    /target:library /out:assistant-dx.dll assistant-dx.cs
```

Respaldos: `voice-ctrl-backup-20260910-102414.zip` en `Documents`, y copias del
DLL anterior en `tools\`.

---

## 11. TRAMPAS CONOCIDAS (NO caer en ellas otra vez)

- **`$ErrorActionPreference = "Stop"` + captura de stderr de un `.exe`**: en
  PS 5.1 cada línea de stderr es un `ErrorRecord` y bajo `Stop` es terminante.
  Causó el bug original «sin salida de opencode». Nunca combinar ambas cosas.
- **El separador `--` es OBLIGATORIO** al pasar el texto dictado. Sin él, un
  texto que empiece por guion («menos i» → `-i`) lo parsea yargs como flag.
  Verificado: con `--` responde; **sin `--` sale `exit=1` en 2 s**.
- **`.ps1` en UTF-8 SIN BOM**: PowerShell 5.1 los lee como ANSI y `≡` se
  convierte en `â‰¡` en el log y en pantalla. Guardar siempre **con BOM**.
  Afecta también a los scripts de prueba: un banco sin BOM corrompe los
  acentos de los casos y da falsos negativos (pasó dos veces).
- **`.NET antepone un BOM a la primera línea de stdin redirigido**: el worker
  de voz lo quita con `lstrip`, o esa primera frase genera un hash distinto y
  nunca acierta en la caché.
- **`SetForegroundWindow` a secas NO basta**: hay *foreground lock* y un
  proceso en segundo plano no puede robar el foco (falló 3/3 en el log). Se usa
  `AX::ForceForeground` (`AttachThreadInput`). Su valor de retorno miente: hay
  que comprobar `GetForegroundWindow()`. **Y si falla, ABORTAR el dictado**: si
  se continúa, las palabras se escriben en otra ventana y disparan cosas
  sueltas (parece que «ejecuta mientras hablas»).
- **`Start-Process -PassThru`**: tocar `$p.Handle` justo después, o `.ExitCode`
  devuelve `$null` tras salir.
- **`$p.Kill()` no mata el árbol**: usar `taskkill /PID <id> /T /F`.
- **`$args` es variable automática** dentro de funciones: nunca usarla como
  nombre de parámetro (rompió un script de medición).
- **Índices de matriz bidimensional dentro de una llamada a método** no los
  traga el parser de PS 5.1: usar variables intermedias.
- **Las voces "Natural" de Windows no son accesibles a las apps** (§7).
- **NO matar procesos "opencode*" a ciegas**: la desktop app también se llama
  `OpenCode.exe` y es Electron (≈7 procesos, normal). Filtrar por `CommandLine`
  con `*node_modules\opencode-ai*`.
- **`Add-Type -TypeDefinition` compilando al arranque colgaba** → DLL precompilado.
- **WinForms no es thread-safe**: no tocar `$capture`/`$lbl` desde un runspace.
- **`--auto` auto-aprueba todo lo que no esté en `"deny"`**: poner algo en
  `"ask"` NO bloquea nada en el flujo por voz (§12).
- **Nada de eventos asíncronos en PowerShell** (SAPI, `Register-ObjectEvent`
  sobre reconocedores, runspaces tocando la UI): el manejador corre en otro
  hilo y **mata el proceso en silencio**. Pasó dos veces. Todo hijo se
  comunica por archivos-marca en `tmp\` y el bucle los sondea.
- **MCI (`mciSendString`) puede decir "ok" y no sonar**: ver §7. Comprobar
  siempre la voz al arrancar (para eso está el saludo).
- **La voz del propio asistente vuelve al micrófono** (pico 0,99) y hundía la
  ganancia automática: mientras habla o dicta existe `tmp\escucha-pausa.flag`
  y el worker ignora el audio. Si la pausa no se libera (hay `finally` para
  eso), la palabra de activación queda muda un minuto.
- **La ventana de captura de WinForms NO se puede quitar** aunque la interfaz
  nueva la tape: el dictado de Windows escribe en la ventana con foco. Se deja
  con `Opacity = 0.01` (con 0 exacto Windows deja de pintarla y puede perder
  el foco).
- **El modelo pequeño de Vosk NO vale para dictar** («abre stein»): sirve
  para la palabra de activación, no para transcribir órdenes. El grande no
  cabe (7,7 GB de RAM, ~1 GB libre). Por eso el dictado es **Whisper** (§15)
  o, como respaldo, `input.dictado = "windows"`.
- **El stdin de un proceso hijo va en IBM850 en la consola oculta**, y .NET
  Framework no deja fijar `StandardInputEncoding`. Cada tilde o «¿» llegaba
  al worker de voz como un *surrogate* que reventaba el md5: **el worker
  moría en silencio con cada frase no ASCII** y se relanzaba (2 s mudo).
  Solución: el asistente escribe **bytes UTF-8** en `BaseStream` y el worker
  lee `sys.stdin.buffer` y decodifica a mano. Verificado con «¿calculadora?».
- **`Start-Sleep 2500` son 2500 SEGUNDOS**, no milisegundos. Un guion de
  prueba se quedó 41 minutos dormido por esto.

---

## 12. SEGURIDAD Y PRIVACIDAD — RIESGOS ACEPTADOS

**Permisos del agente.** `opencode.jsonc` tiene `bash`, `edit`, `webfetch` y
`mcp__windows__*` en `"allow"`, y se invoca con `--auto` (el CLI lo describe
como *«dangerous!»*). Con `--dir` sobre todo `Documents`, una frase mal
transcrita puede ejecutar shell, editar archivos y controlar el escritorio
**sin confirmación**. Comprobado en vivo: opencode interpretó un «di
exactamente: …» como orden de teclear y escribió en la ventana enfocada.
**El usuario conoce el riesgo y ha decidido mantener el acceso total.**

**Envío automático.** Al enviarse solo tras 2,5 s de silencio, ya no existe el
segundo botón como último punto de control antes de ejecutar.

**Voz en línea.** Cada frase NUEVA que dice el asistente se sintetiza en
servidores de Microsoft: el texto de las respuestas —incluido lo que venga de
las notas de `memoria\`— sale del equipo. Con Piper no ocurría. Decisión
tomada a favor de la calidad de voz. Para revertir: `config.json → voz.motor`
= `"piper"`.

La capa local reduce la exposición de hecho: las órdenes habituales ya no
llegan al agente.

---

## 13. PENDIENTE / PRÓXIMOS PASOS

### Cerrados en esta sesión

- ✅ **Hash SHA256 del DLL**: se comprueba al arrancar contra
  `config.json → seguridad.hashDll`. **Avisa pero NO aborta**: ante un cambio,
  lo más probable es que lo hayas recompilado tú, y dejarte sin asistente por
  eso sería peor que el riesgo que cubre. Si recompilas, actualiza el valor.
- ✅ **Armoury Crate**: no es un `.exe` normal sino una app empaquetada. Se
  lanza con `shell:appsFolder\B9ECED6F.ArmouryCrateSE_qmba6cd70vzyy!App`.
- ✅ **Historial**: `repite` / `qué me dijiste`.
- ✅ **Porcentajes exactos** de volumen y brillo.
- ✅ **Palabra de activación** «Nova» con Vosk (§15).
- ✅ **Traducción con aprendizaje** de órdenes no reconocidas (§4).
- ✅ **Temporizadores, contexto de juego, captura/clip, pronombres, deshacer,
  perfiles** (§17).
- ✅ **Git**: instalado, repositorio público en GitHub.
- ✅ **Interfaz nueva** `nova_ui.exe` (§16).

### Bloqueados

- ❌ **Tarea programada**: `Register-ScheduledTask` da **acceso denegado**
  incluso para una tarea por usuario con disparador «al iniciar sesión». No es
  viable sin admin. La clave `Run` se queda (no da reinicio automático).
- ✅ **Dictado preciso**: `faster-whisper small` (§15). Pendiente de que el
  usuario lo valide con su voz; el respaldo es `input.dictado = "windows"`.

### Abiertos

1. **Ampliar `commands.json`** con el uso real: `memoria\estadisticas.md`
   lista exactamente lo que no se reconoció.
   ✅ **El ruido ya no llega al agente** (§4): el traductor responde `NO` y se
   descarta en ~13 s en vez de 25-160 s, y un descarte ya no deja armada la
   ventana de encadenar (una cascada de ruido se cortaba sola).
2. ✅ **Confirmación cuando la coincidencia es dudosa** (§15).
3. ✅ **Nivel de micrófono en la onda**: el worker escribe `tmp\ui-nivel.txt`
   (0..1, a 4 Hz) mientras dictas y la interfaz lo lee directamente.
4. **RAM de `nova_ui.exe`** (~130 MB, casi todo el runtime de WPF). Si molesta:
   `ui.nueva = false` en `config.json` devuelve la barra antigua.
5. Comprobar que la cápsula se ve **sobre juegos a pantalla completa
   exclusiva** (sobre ventana sin bordes sí).

---

## 14. COMANDOS ÚTILES

```powershell
# ¿Está corriendo?
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*-File*assistant.ps1*' } |
  Select-Object ProcessId, CreationDate

# Arrancarlo a mano
Start-Process powershell.exe -ArgumentList '-NoProfile','-WindowStyle','Hidden',
  '-ExecutionPolicy','Bypass','-File','C:\Users\braya\Documents\voice-ctrl\assistant.ps1' `
  -WorkingDirectory 'C:\Users\braya\Documents\voice-ctrl'

# Detenerlo (mata también worker de voz y Piper, que son hijos)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -like '*-File*assistant.ps1*' } |
  ForEach-Object { taskkill /PID $_.ProcessId /T /F }

# Leer los logs con el encoding correcto (el terminal los muestra mal)
[System.IO.File]::ReadAllText("$PWD\assistant.log", [System.Text.Encoding]::UTF8)

# Qué ruta tomó cada orden, y qué no se reconoció
([System.IO.File]::ReadAllText("$PWD\assistant.log", [System.Text.Encoding]::UTF8) -split "`r?`n") |
  Where-Object { $_ -match 'SUBMIT:|LOCAL|RUNNER exit|descarta|MEMORIA' }

# Vaciar la caché de voz (se regenera sola)
Get-ChildItem .\tmp\voz -Filter *.mp3 | Remove-Item -Force

# Recompilar la interfaz tras tocar nova_ui.cs (el asistente debe reiniciarse)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\compilar-ui.ps1

# Subir a GitHub (abre una consola real por si pide credenciales)
Start-Process powershell -ArgumentList '-NoExit','-File','tools\subir-a-github.ps1'
```

`taskkill /T` sobre el asistente se lleva también `wake_vosk.py`,
`tts_worker.py` y `nova_ui.exe`, que son hijos suyos. La interfaz además se
cierra sola si el asistente muere (recibe su PID y lo vigila cada 2 s).

---

## 15. ESCUCHA CONTINUA: PALABRA DE ACTIVACIÓN «NOVA»

`wake_vosk.py` es un proceso Python aparte (prioridad *BelowNormal*) que
tiene el micrófono abierto siempre y reconoce **solo** el nombre, con una
**gramática cerrada** de Vosk (modelo pequeño es-ES en `vosk\`). Al oírlo crea
`tmp\despierta.flag`; el bucle principal lo ve y llama a `Start-Dictado`, el
mismo camino que el botón.

Argumentos (en este orden): nombre, ruta de la marca, log, ganancia,
marca de pausa, marca de dictar, ruta del dictado, ruta del parcial.

Lo que costó afinar, y por qué está como está:

- **El micrófono de esta máquina entra bajísimo** (prueba de Windows: 7 %,
  pico crudo 0,02-0,05). SAPI lo tomaba por silencio. Vosk da el audio crudo,
  así que se **amplifica por software**: ganancia automática calculada sobre el
  **percentil 90 del audio crudo** (no del amplificado: antes se realimentaba
  y acababa en ×60 con recorte), y solo **cuando hay voz sostenida** (≥4
  bloques), nunca sobre silencio. Límites 0,5-40. Detecta recorte y baja.
- **Confianza mínima 0,55** y **límite de palabra `\b`** al comparar: sin
  eso «novato» disparaba (`endswith`).
- **Pausa**: mientras existe `tmp\escucha-pausa.flag` ignora el audio. La
  crea el asistente al hablar (su propia voz volvía con pico 0,99) y al
  dictar con Win+H (competían por el micro). Se libera en `finally` y por
  plazo desde el bucle.
- **Supervisado**: el bucle mira `HasExited` cada 30 s y relanza (3 intentos);
  si no se sostiene, avisa por voz y sigue con el botón. Antes moría en
  silencio y la palabra dejaba de funcionar el resto de la sesión.
- **Tras cancelar con el botón** la escucha se rearma sola (hubo un bug en que
  la pausa se quedaba puesta).
- El pulso `[escucha] pulso: …` en el log cada 15 s dice ganancia, bloques
  con voz y % decodificado: es el primer sitio donde mirar si «no me oye».
- **Dictado por Whisper** (`input.dictado = "whisper"`, el actual): el
  worker graba la orden (bloques ya amplificados), Vosk da la transcripción
  parcial en vivo mientras hablas, y al callar (1,4 s) **faster-whisper**
  (`small`, int8, CPU, 4 hilos) transcribe el audio entero. Se le pasa como
  *prompt* el vocabulario de `tmp\vocabulario.txt` (apps, sitios, juegos)
  para que acierte los nombres propios. Whisper puntúa: los puntos internos
  se vuelven comas (separan órdenes) y el final se quita. Carga en ~7 s al
  arrancar, **~460 MB de RAM** en el worker, transcribe una orden corta en
  1-3 s. Si no se puede cargar, cae a Vosk solo. `input.whisperModelo`
  admite `base` (más ligero, menos preciso). Modelo en
  `%USERPROFILE%\.cache\huggingface\hub\models--Systran--faster-whisper-small`.
- **Dictado por Vosk** (`input.dictado = "vosk"`): mismo camino sin Whisper;
  el modelo pequeño transcribe mal las órdenes. Se conserva como respaldo.
- **Confirmación sí/no**: cuando la capa local acierta una orden solo por
  parecido lejano (juego a distancia de edición, app a ≥2 letras), el
  asistente pregunta «¿Little Nightmares III?» y crea `tmp\confirmar.flag`;
  el worker pasa a una gramática cerrada (sí, dale, vale, claro, ok / no,
  cancela), usa los **parciales** para responder al instante y escribe
  `tmp\confirmacion.txt`. «No» cancela; «sí» o **3,5 s sin respuesta**
  ejecutan (`confirmacion.esperaMs`). El plazo empieza al terminar de sonar la
  pregunta. Sin estado pegajoso: la palabra de activación se ignora solo
  mientras hay una pregunta pendiente. Las traducciones del modelo no se
  confirman (o encajan o no).
- Alternativa C# con SAPI (`wake_worker.exe`, `escucha.motor = "sapi"`):
  funciona pero no amplifica; se conserva por si cambia el micrófono.
- Diagnóstico: `tools\diag\diag-escucha.ps1` y `tools\diag\diag-vosk.py`.

Config: `escucha.{activada, nombre, motor, ganancia, confianzaMinima}`.

---

## 16. INTERFAZ: LA CÁPSULA DE CRISTAL (`nova_ui.exe`)

Es **la cara visible** del asistente: un punto turquesa con halo, siempre
visible en la esquina inferior izquierda (12 px del borde), que se expande en
una cápsula de 340×44 con animación elástica. Estilo pedido por el usuario:
isla dinámica + cristal oscuro con acento neón. Tamaño: **no cambiar**, es el
que no molesta.

| Estado | Color | Qué muestra |
|---|---|---|
| `reposo` | turquesa `#35E0C8` | solo el punto, latiendo despacio |
| `escuchando` | verde `#3DF09A` | onda de audio + transcripción en vivo |
| `pensando` | ámbar `#FFB33D` | «Procesando…» / «Pensando…» / «Entendiendo…», halo pulsando |
| `hablando` | azul `#4DA6FF` | el texto que está diciendo |
| `error` | rojo `#FF5A5A` | el aviso (cancelado, no te escuché…) |

Cómo funciona:

- **Proceso WPF aparte** (`nova_ui.cs`, compilar con `tools\compilar-ui.ps1`).
  WinForms no acelera por hardware y las animaciones iban a tirones; WPF no
  convive con el bucle del asistente; separado además no puede tumbarlo.
- El asistente escribe **`tmp\ui-estado.json`**
  `{"estado","texto","nivel"}` (`Set-UI`) y la interfaz lo lee cada 80 ms.
  Solo se escribe si cambió. UTF-8 **sin BOM**.
- **Click-through** (`WS_EX_TRANSPARENT | TOOLWINDOW | NOACTIVATE`): nunca
  roba clics ni foco al juego. Sin barra de tareas.
- **Cristal de verdad, no plástico** (fue la crítica al primer intento, que
  tenía relleno opaco): la cápsula **captura la pantalla que hay detrás** al
  expandirse (se vuelve invisible 45 ms para no capturarse a sí misma), la
  desenfoca en GPU (`BlurEffect` 22 px) y la usa de fondo recortado; encima
  van tinte oscuro translúcido, **grano** fino tipo acrílico, **reflejo** de
  luz en la mitad superior, borde con luz (claro arriba, color del estado
  abajo), halo de color y sombra negra hacia abajo. El punto es una esfera con
  brillo, no un círculo plano. DWM no ofrece acrílico con forma de cápsula.
- Ancho = medida real del texto (`FormattedText`), tope 340. **El texto largo
  no agranda la cápsula: se desplaza.** Escuchando se ve siempre el final (lo
  último dicho); hablando recorre el texto una vez a ~100 px/s, que es el
  ritmo de la voz, con los bordes difuminados. El `TextBlock` va dentro de un
  `Canvas`, no de un `Grid`: el Grid le aplica un recorte de diseño que viaja
  con la transformación y el texto desaparecía al moverse.
- La fila de contenido va alineada a la izquierda explícitamente: con el
  `Stretch` por defecto, en reposo el punto salía cortado por el recorte.
- Recibe el **PID del asistente** y se cierra sola si muere. El asistente la
  supervisa cada 30 s (3 relanzos) y, si no se sostiene, **vuelve la barra
  antigua** (`$capture.Opacity = 1`).
- La **barra antigua sigue existiendo** con opacidad 0,01: Win+H necesita
  una ventana con foco. Los popups de WinForms solo se abren para textos
  de más de 80 caracteres (en la cápsula no cabrían).
- Coste: **~130 MB de RAM** (runtime de WPF), CPU despreciable en reposo.
  Apagar: `ui.nueva = false`.

**Vida (micro-animaciones).** Además del estado, el JSON lleva
`evento` + `n` (contador): la cápsula reproduce la animación cuando cambia
`n`, así que el mismo evento puede repetirse. `Send-UIEvento` en el asistente.

| Evento / momento | Qué hace la cápsula |
|---|---|
| `despierta` (al oír «nova» o el botón) | el punto salta con rebote elástico y lanza dos ondas concéntricas verdes |
| `hecho` (orden local ejecutada, memoria, traducción aprendida) | destello blanco, marca ✓ sobre el punto, una onda |
| `aviso` (temporizador, batería, tiempo de juego) | salto + dos ondas ámbar |
| entrar en `error` | la cápsula se sacude en horizontal |
| `pensando` | tres puntos que laten en cadena junto al texto; el halo respira |
| `hablando` | el punto «mueve la boca»: sílabas simuladas (80-210 ms, con pausas) hinchan el punto y el halo |
| reposo / escuchando | respiración lenta del punto y un **parpadeo** cada 4-9 s (aplastamiento vertical de 200 ms) |
| texto nuevo | entra deslizando 6 px desde abajo |
| `juego` (ruta del exe en el JSON) | el **icono del juego** pasa a ser el avatar (22 px, circular, aro del color del estado) y el punto se vuelve una insignia abajo a la derecha; entra creciendo con rebote |
| siempre | **mirada**: el reflejo del punto se desplaza (±2 px) hacia el ratón; si lleva 8 s quieto, hacia el centro de la ventana activa |
| `despierta` | además, **chispas**: 6 partículas salen disparadas del punto y se apagan (520 ms) |
| `hablando` con `audio` en el JSON | si existe `<mp3>.env` (envolvente RMS a 20 Hz que escribe `tts_worker.py` con `miniaudio`), la boca sigue **la voz real** con 300 ms de retardo; si no, sílabas simuladas |
| volumen del sistema cambia (COM, cada 250 ms; también los botones físicos) | en reposo, se abre 1,5 s con el glifo de Segoe MDL2 (silencio / bajo / medio / alto) y una barra fina |
| `brillo:NN` (evento que manda `Set-Brillo`) | lo mismo con un sol |
| `tempoFin`/`tempoTotal` (temporizador más próximo, ms Unix) | **anillo** de 2 px alrededor del punto que se vacía en sentido horario; al vencer, estalla en ondas |
| `bateria` ≤ 20 y no `cargando` | el punto/insignia pasa a **ámbar** y la respiración se acelera (0,9 s); `cargando`: destello verde cada 4 s |
| `perfil` = `noche`, o de 22:00 a 07:00 | paleta **melocotón** y respiración lenta (2,6 s) |
| `logro` (cada hora completa de juego) | oro en punto, insignia y aro durante 1,4 s, salto, dos ondas doradas, chispas y un arpegio |
| `pensando` > 20 s | los tres puntos se apagan y un punto **orbita** alrededor del avatar (2,4 s/vuelta) |
| transcripción en vivo | lo **nuevo** del texto entra en el color del estado y se funde a blanco en 0,5 s |
| arranque / fin | nace desde el centro con rebote y dos ondas; si el asistente muere, se aplasta en una línea y se apaga como un tubo antiguo |
| sonidos | tonos sintetizados en memoria (`SoundPlayer`, amplitud 0,15): despertar (523→784 Hz), tic (988 Hz), error (220 Hz), logro (arpegio), aviso (dos notas). El asistente ya no usa la campana de Windows cuando la cápsula está activa |
| **gestos** (lo que dices, en vivo) | la cápsula analiza lo NUEVO de la transcripción con expresiones regulares (`GESTOS_USUARIO`, en orden, gana la primera): *cariño* («te quiero», «eres genial»: sonrojo rosa, corazón que sube, salto), *gracias* (cabeceo doble y rubor), *risa* («jaja»: brinquitos), *saludo* («hola», «buenas»: se ladea a un lado y a otro con vaivén), *despedida* (adiós y tono azulado), *negar* («no», «cancela»: giro y vaivén), *asentir* («sí», «dale»), *reverencia* («por favor»: se inclina), *prisa* («rápido», «ya»: vibra y la onda se acelera 3 s), *calma* («tranquilo»: respira lento 12 s), *disculpa* («perdón»: un «oh»), *duda* (interrogativos al inicio o tras «y»/coma: ladea la cabeza y sale un «?»), *atención* («nova» dentro de la frase: salto), *sueño* («duérmete», «silencio»), *sorpresa* («wow», «en serio»: se hincha y onda blanca). Cada gesto tiene 1,5 s de enfriamiento |
| gestos (lo que ella dice) | al empezar a hablar analiza su propia respuesta (`GESTOS_PROPIOS`): *pena* («No pude…», «No encontré…»: se deja caer y ladea), *orgullo* («Listo», «Hecho», «Anotado», «Abriendo»: se hincha y sube), *duda* («¿…?»), *cariño* («de nada») |
| gestos (eventos del asistente) | `gesto:confuso` cuando la frase va al modelo por no entenderla en local (niega con la cabeza y «?»), `gesto:sobresalto` al cancelar con el botón (salta hacia atrás y se encoge), `gesto:lotengo` cuando lo transcrito hasta ahora **ya es una orden que la capa local reconoce** (`Test-FastCommand`, solo resuelve, no ejecuta; una vez por dictado, con tope de una comprobación cada 400 ms): asentimiento anticipado, destello y un tic |
| gestos **encadenados** | «gracias» hasta 25 s después de una *pena* → **alivio** (suspiro: se hincha, aguanta y suelta, tono verde). Repetir la misma orden que acabó en pena (90 s) → **determinación** (se aprieta, brilla y onda blanca) |
| **humor de minutos** | tras cariño/gracias/logro → *contenta* 2 min (respiración ×0,8); dos negaciones en 1 min → *cauta* 2 min (escala 0,92, respiración ×1,15, parpadeo cada 2-7 s) |
| **tono** (nivel del micro a 4 Hz) | ≥ 0,97 durante 0,75 s → *grito*: se encoge al 85 % y el reflejo se agranda («ojos como platos»); 0,02-0,22 durante 2 s con texto → *susurro*: se acerca (1,1) y baja el halo |
| **ritmo** (palabras/s de la transcripción, ventana 5 s) | ≥ 3 → onda y parpadeo más rápidos; ≤ 1,2 → todo más lento; vuelve al terminar la orden |
| muletillas («eh», «mmm», «a ver», «espera») | *paciencia*: parpadeo lento y mirada hacia arriba |
| frase larga (> 6 s escuchando) | *te escucho*: un asentimiento suave cada 3,5 s |
| **juego activo** + «voy a morir», «este jefe», «otra vez» | *apoyo*: se acerca, dorado, onda y tono; «lo logré», «ganamos», «gg» → medalla |
| entonación de lo que dice | una pregunta («¿…?») arquea (7°) y sube la mirada; cada cifra del texto es un tic (hasta 6) |
| idiomas y regionalismos | los patrones incluyen inglés (thanks, hello, please, sorry, yes/nope…) y regionalismos (parce, wey, tío, che, chévere, bacano, quiubo, no manches…) |
| **gestos propios** | `config.json → ui.gestos: [{gesto, patron}]` → el asistente escribe `tmp\gestos.txt` («gesto\|patrón») al arrancar y la cápsula lo relee cada 30 s. Se evalúan ANTES que los de serie. Gestos válidos: cualquiera de la tabla (carino, gracias, risa, saludo, negar, asentir, duda, apoyo, logro…) |
| diario de gestos | cada gesto se apunta en `tmp\gestos.log` (fecha, nombre; se recorta a 5000 líneas) y `estadisticas.md` lo resume por día en «Gestos de la cápsula» (sin escucho/lotengo/atención, que son ruido) |
| **ojos** | dos pupilas (4,2×6,4 px, azul muy oscuro) sobre el punto, que ahora es de **20 px en un hueco de 28** (antes 14/24: el usuario los vio pequeños), con reflejo pequeño arriba a la izquierda. Miran (±1,7 px, más que el reflejo), **parpadean ellas** (el punto apenas se aplasta) y ponen la **expresión** del gesto: *felices* (cariño, gracias, risa, logro, alivio, apoyo, orgullo), *entrecerrados* (duda, confuso, paciencia, perdida, calma, susurro), *abiertos* (sorpresa, grito, sobresalto, atención, al despertar), *tristes* (pena, despedida), *atentos* (escuchando/atenta), *cerrados* (dormida). Sobre un avatar (juego/tiempo) no se dibujan |
| `progreso` (0..1, del asistente) | línea de 2 px en el borde inferior que se llena; ≥ 0,95 late |
| `atenta` | verde apagado, onda, halo 0,3: «sigo aquí» tras responder (§18) |
| `voz` | tinte de la escucha por quien habla (§19) |
| **cine** (pantalla completa sin juego) | halo 0,15 en reposo, sin barra de volumen ni presencia |
| `gesto:perdida` (25 s dictando sin que nada encaje) | mira a un lado y a otro, «?» |
| `pensando` > 40 s | además de orbitar, **suda**: una gota azul le resbala cada 8 s |
| `carga` ≥ 85 (CPU, cada 30 s) | pulso rápido (1,1 s) y el color base tira a rojo caliente |
| ratón a < 60 px de la cápsula | **presencia**: el halo se enciende (0,95, radio 34), la mirada se estira y da un saltito; se apaga al alejarse |
| ventana en primer plano **a pantalla completa** (rect = pantalla; se ignoran `Progman`/`WorkerW`/barra) | **foco**: en reposo se encoge a la mitad (un punto de 22 px); se expande normal para hablar. Histéresis de 1 s |
| 30 min sin actividad, sin juego y sin foco | **sueño**: opacidad al 55 %, respiración de 4,2 s entre 0,22 y 0,45, se deja caer y ladea, y cada 9 s sube una «z». Cualquier estado, evento, gesto o cambio de volumen la **despierta** con un estiramiento vertical |
| `clima` (emoji, del asistente) | **solo cuando se pregunta** («¿qué tiempo hace?»): el emoji del tiempo sustituye a la carita mientras dura la respuesta (+1,5 s) y vuelve la cara. El asistente consulta Open-Meteo cada hora; sin `clima.lat/lon` en config pide la ubicación UNA vez a ip-api.com (manda la IP). El usuario decidió que la carita mande: el tiempo no se queda de avatar |
| texto largo desplazándose | **rastro**: una copia desenfocada (radio 5, opacidad 0,35) sigue al texto con 70 ms de retraso |
| últimos 10 s de un temporizador | **cuenta atrás**: el anillo late (grosor 2→3,6) y el punto hace un tic (1,14) con un «tic» agudo por cada segundo |
| `hablando` con envolvente | **ecualizador**: cuatro bandas blancas dentro del punto siguen la envolvente con modulación pseudo-espectral |
| arranque | **firma**: tras las ondas, las chispas dibujan una «N» en tres trazos y se apagan |
| `animo` (−1..1, del asistente: aciertos − 2·errores en 24 h) | ≤ −0,3: color base apagado (45 % hacia gris) y respiración de 2,3 s; ≥ 0,5: un 12 % más luminoso |
| ventana normal (no maximizada, no completa) tapando la esquina | **se aparta**: se desliza a la derecha del borde de esa ventana (sin salirse de pantalla) y vuelve al despejarse. Histéresis de 1 s; una ventana que cubre ≥ 90 % de la pantalla no la mueve |

Cuando hay un juego en primer plano el asistente pone su ejecutable en
`juego`; `Get-JuegoEnPrimerPlano` guarda la ruta en `$script:juegoExeCandidato`.
La interfaz saca el icono con `Icon.ExtractAssociatedIcon`.

---

## 18. MODO DE SEGUIMIENTO (encadenar órdenes sin repetir «nova»)

Tras responder a una orden, el asistente **vuelve a escuchar** durante
`input.seguimientoMs` (2500) sin palabra de activación. Si hablas, es otra
orden; si no, se cierra en silencio. Cadena típica: «nova, abre steam» … «y
sube el volumen» … «y avísame en veinte minutos» … «gracias».

- `Process-Texto` deja `$script:seguimientoPendiente`; cuando vence la pausa
  de la voz (`pausaHasta`, ahora calculada con la **duración real** del MP3
  vía `<mp3>.env`), el bucle llama a `Start-Dictado 'seguimiento'`.
- La marca `tmp\dictar.flag` lleva `seguimiento:<ms>`; el worker, si no oye
  voz sostenida (≥2 bloques) en ese plazo, entrega vacío y cierra
  (`seguimiento: sin voz`). Con voz, es un dictado normal (Whisper).
- La cápsula lo muestra en estado **`atenta`** (verde apagado, onda, halo
  bajo), sin ondas de despertar.
- «gracias», «nada más», «listo», «ya está» cierran la cadena («De nada»).
- No se arma tras avisos (temporizador, batería), ni con Win+H (no puede
  esperar sin robar el foco), ni con una confirmación pendiente.
- Verificado: tres órdenes encadenadas y cierre con «gracias».

---

## 19. CAPACIDADES DE CONTROL (locales, < 1 s)

| Frase | Qué hace |
|---|---|
| «cierra steam / discord / la calculadora» | `CloseMainWindow` (y `Kill` si no cierra) del proceso de `commands.json` (`Resolve-Proceso`; los URI tienen tabla `$PROCESOS_URI`) |
| «cierra esta ventana» | Alt+F4 |
| «cierra el juego» | cierra el proceso del juego activo |
| «cambia a discord», «ve a steam», «enfoca el navegador», «muestra spotify» | restaura y trae al frente su ventana (`ForceForeground`) |
| «vuelve al juego» | idem con el juego activo |
| «muestra el escritorio», «minimiza todo» | Win+D |
| «cambia de ventana» | Alt+Tab |
| «escribe hola qué tal» | teclea en la app activa (`SendKeys`, con los caracteres especiales escapados) |
| «pulsa enter / escape / espacio / tab / arriba / abajo / f5 …», «pulsa abajo 3 veces» | tecla virtual |
| «copia», «pega», «corta», «selecciona todo», «guarda», «deshaz eso», «rehaz», «nueva pestaña», «cierra la pestaña», «recarga» | atajos Ctrl+… |
| «baja / sube» (sin objeto) | Av Pág / Re Pág |
| «pon bad bunny en spotify» | `spotify:search:…` |
| «reproduce lofi en youtube» | búsqueda en YouTube |
| «busca en el equipo fotos de julio» | Win+S y teclea |
| «gracias», «hola», «adiós», «cómo estás», «quién eres», «qué puedes hacer» | respuestas sociales locales (antes «gracias» costaba 40 s de modelo) |

### Reglas por voz (`reglas.json`, `Invoke-ReglaVoz` / `Invoke-Reglas`)

«cuando abra elden ring pon modo noche» · «cuando cierre el juego pon el
brillo al 50» · «cuando la batería baje del 20 bloquea» · «todos los días a
las 9 pon el brillo al 60» · «a las diez y media de la noche pon modo noche»
· «cada 45 minutos recuérdame en 0 minutos que estire». Y «qué reglas hay»,
«borra la regla 2», «borra las reglas». La acción tiene que ser una orden
local (se valida con `Test-FastCommand`); se interpretan sobre la frase
ENTERA, antes de partir por «y». Disparadores: entrada/salida de juego
(`Enter-Juego`/`Exit-Juego`), batería (una vez por cruce, se rearma al subir
10 puntos), hora (una vez al día) y periódicas. **Trampa PS 5.1**: una
`ArrayList` vacía devuelta desde una función se desenrolla en `$null`;
`return ,$lista`.

### Fechas
«recuerda que el 3 de octubre es el cumple de Ana» → además del diario,
`memoria\fechas.json`; ese día, al arrancar o al cambiar de día, lo dice y
medalla. «qué fechas tengo».

### Voz interna (lo que hace opencode)
`opencode run --format json`: una línea por evento. `Watch-OpencodeProgress`
lee el archivo de salida cada 600 ms y traduce cada `tool_use` («ejecutando
un comando», «leyendo un archivo», «consultando la web», «controlando el
escritorio»…) al texto de `pensando`; además manda `progreso` (transcurrido
sobre lo esperado por modo: pregunta 18 s, traducir 15 s, charla 20 s,
acción 60 s) y la cápsula dibuja una **línea en el borde inferior** que late
al pasar del 95 %. La respuesta se saca de los eventos `text`.

### Micro-charla, logros, acelerómetro, nota semanal
- `charla.activada`: «tres horas seguidas, un vaso de agua» y «es la una,
  ¿seguimos?» (con juego), una vez al día cada uno.
- Logros: `Steam\appcache\stats\UserGameStats_<usuario>_<appid>.bin` cambia
  cuando cambian las estadísticas del juego activo → medalla (puede haber
  falsos positivos; tope de una cada 2 min).
- Acelerómetro (WinRT `Windows.Devices.Sensors.Accelerometer`, presente en la
  Ally): |a| − 1 g > 0,7 → sobresalto. Se sondea cada 250 ms.
- `memoria\semanas\AAAA-Www.md`: al arrancar y al cambiar de día, si la
  semana anterior tuvo uso y no tiene nota, se escribe en lenguaje hablado
  (órdenes, tropiezos, descartes, gestos).

### Seguimiento inteligente
Si la orden acaba «colgando» («abre steam y…», «pon el volumen y luego…»,
o con coma), la ventana de seguimiento se multiplica por 2,4 y la coletilla
se quita antes de ejecutar; si acaba en «listo» / «y ya» / «nada más», no
hay ventana. (`$script:seguimientoFactor`.) No hay prosodia real: se usa
la coletilla como señal de pausa.

### Ver la pantalla
- «lee la pantalla», «¿qué dice esta ventana?», «lee esto» → `Save-Captura`
  (rect de la ventana en primer plano vía `AX.GetWindowRect`; la cápsula se
  esconde 0,6 s con el evento `oculta` para no salir) + `Invoke-OCR` con el
  **OCR integrado de Windows** (WinRT `Windows.Media.Ocr`, idioma `es` o el
  del perfil). Lee hasta 320 caracteres; el texto entero queda en
  `tmp\ocr.txt` y en el popup. Verificado: leyó «Calculator. Standard. CE».
- «pregúntale a la IA qué es esto / esta ventana / este error» → la captura
  se adjunta con `--file` **y** el texto OCR va en el prompt («Texto visible
  en la ventana activa: …»), porque el modelo en uso **no admite imágenes**
  (contestó eso literalmente); con el texto sí puede ayudar.
- `Await-WinRT`: AsTask por reflexión con tope de 8 s (aparte del de la voz,
  que solo se inicializa en el camino de la voz de Windows).

### Recordatorios con fecha y hora (`memoria\recordatorios.json`)
«recuérdame mañana a las 10 que llame al médico», «avísame el viernes a las
cinco de la tarde que…», «recuérdame a las 3 revisar el horno» (hoy si no ha
pasado; si no, mañana), «el 20 de octubre a las 9…», «el lunes que…» (sin
hora: a las 9). Horas en cifra o palabra, «y media», «y cuarto», «menos
cuarto», «de la tarde/noche». «qué recordatorios tengo», «borra los
recordatorios». Se comprueban cada minuto: voz + aviso + vibración.
Sobreviven a los reinicios. El regex de notas («recuerda que…») excluye
estas formas para no archivarlas como nota.

### Vibración del mando (`mando.vibracion`)
`AX.XInputSetState` (mando 0). Patrones `[on, off, on…]` en ms que ejecuta el
bucle sin bloquear: despertar 90, seguimiento 40, `hecho` 50-60-50, `aviso`
120-80-120, `logro` 80-60-80-60-160, respuesta de una tarea de más de 8 s
220. Verificado: «mando: vibracion disponible».

### Autoaprendizaje de descartes
Cuando el modelo traduce con éxito y la diferencia con la orden original es
**una sola palabra** que corresponde a **una sola app/sitio** conocidos
(`Find-Generalizacion`: «ponme la calcu» → «calculadora»), tras responder
pregunta «¿Quieres que calcu sea siempre calculadora?» y escucha sí/no
(confirmación con `tipo = 'aprender'`): solo un «sí» claro aprende
(`Add-Alias-Comando`); el silencio no. Esa pregunta tiene prioridad sobre
el seguimiento.

### Acelerómetro: NO en la Ally
`Windows.Devices.Sensors.Accelerometer.GetDefault()` devuelve un sensor,
pero `GetCurrentReading()` **tarda 5 s y devuelve null siempre** (probado
también fijando `ReportInterval`). Sondearlo cada 250 ms **bloqueó el
asistente entero** (las órdenes tardaban 30 s en leerse). Apagado por
defecto (`sensores.acelerometro = false`); si se activa, la primera lectura
lenta o vacía lo desactiva sola.

### Voz por tono
El worker estima el tono fundamental (autocorrelación, 70-400 Hz) de cada
orden y agrupa voces por cercanía (±22 Hz) en `tmp\voces.json`; el índice va
en el JSON (`voz`) y la cápsula tiñe la escucha (verde, cian, violeta,
naranja). No es identificación de hablante real: separa voces de altura
distinta.

---

## 17. LO DEMÁS QUE SE AÑADIÓ (resumen rápido)

- **Temporizadores**: «recuérdame en 20 minutos que…», «avísame en una hora».
  Se guardan en `$script:temporizadores` y el bucle los vence; la memoria
  («recuerda que…») lleva un *lookahead* para no tragárselos.
- **Contexto de juego**: cada 10 s se mira qué proceso de `steamapps\common`
  está en primer plano (`Get-JuegoEnPrimerPlano`); «¿a qué estoy jugando?» y
  «¿cuánto llevo jugando?» responden al instante. «captura» / «clip» usan los
  atajos de la barra de juego (Win+Alt+PrtSc / Win+Alt+G).
- **Pronombres**: «ábrelo», «ciérralo», «búscalo» resuelven sobre
  `$script:ultimoObjetivo`.
- **Deshacer**: «deshaz» restaura volumen/brillo guardados en
  `Save-EstadoParaDeshacer`.
- **Perfiles** (`commands.json → perfiles`): juego, noche, trabajo, cine,
  silencio. «modo noche» aplica varios ajustes de golpe.
- **Alias por voz**: «cuando diga X quiero decir Y» → `Add-Alias-Comando`.
- **Aviso de batería** al 15 % (una vez; se rearma al cargar).
- **Saludo al arrancar** («Listo. Di nova cuando me necesites»): prueba
  de extremo a extremo de la cadena de audio. `voz.saludo`.
- **Respuestas cortas**: al agente se le pide resumir en UNA frase porque se
  lee en voz alta; a las preguntas, sin herramientas (`$PRE_HABLADO`).
- **Memoria sin modelo** (`Find-EnMemoria`): «¿qué sabes del wifi?» busca las
  palabras clave (sin vacías, con prefijo y distancia 1) en `memoria\diario`
  y `memoria\temas`, y lee hasta 3 líneas con su fecha, en <1 s. Solo si no
  encuentra nada va al modelo, como antes.
- **Rutinas de juego** (`config.json → juego`): al entrar en un juego se
  aplica el perfil `perfilAlEntrar` (solo los niveles, no las apps: abrir
  Discord encima de un juego recién lanzado estorba), guardando el brillo; al
  salir se restaura el brillo (`restaurarAlSalir`; el volumen no se puede
  leer, así que no se finge). `avisoMinutos` (120): «Oye, ya llevas dos horas
  con X», una vez por sesión de juego.
- **Estadísticas** (`memoria\estadisticas.md`, regenerada por
  `Add-Estadistica` en cada orden; estado en `estadisticas.json`): órdenes
  por día y ruta, **lo que la capa local no reconoció** (solo cuando la frase
  acabó yendo al modelo como orden, no las preguntas) y las últimas órdenes.
  Es la lista de lo que falta en `commands.json`, sin leer logs.
