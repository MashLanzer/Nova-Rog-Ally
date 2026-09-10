# TRASPASO: Asistente de voz por botón en ASUS ROG Ally

> Documento autocontenido para delegar a otra IA o retomar el proyecto.
> Carpeta: **`C:\Users\braya\Documents\voice-ctrl`**
> Última actualización: **2026-09-10** (voz neuronal, memoria en Obsidian,
> juegos de Steam, envío automático).

---

## 1. OBJETIVO

Controlar el ASUS ROG Ally **por voz, en segundo plano**: mantener pulsado el
botón `≡` (menú del mando) → se abre el dictado de Windows y el usuario habla →
al callar, la orden se ejecuta y el asistente **responde hablando**.

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

Un **único proceso**, **máquina de estados no bloqueante**, **dos rutas** de
ejecución, y tres procesos hijos (opencode cuando toca, el worker de voz, y
Piper si se usa).

```
[ mantener ≡ 1,1 s ]
  → bip + barrita verde + Win+H (dictado de Windows)
[ el usuario habla ]
  → la barrita va mostrando la TRANSCRIPCIÓN EN VIVO
[ callar 2,5 s  (o mantener ≡ = "enviar ya") ]
  │
  ├─ RUTA LOCAL (Invoke-FastCommand)  ── <1 s, sin LLM ──────────────
  │    reconoce la orden entera → la ejecuta → burbuja + voz
  │
  └─ RUTA OPENCODE (si NO reconoce alguna parte) ── 25-160 s ────────
       Start-OpencodeJob lanza opencode.exe y retorna al instante
       barrita ámbar "* Procesando... (mantén ≡ para cancelar)"
       [ el bucle SIGUE sondeando el botón cada 30 ms ]
       → al terminar: burbuja + voz + replies.log
       → mantener ≡ mientras procesa = cancelar (taskkill /T)
```

Decisiones de diseño deliberadas:

- **Un solo hilo.** Se descartó usar runspaces: los objetos WinForms
  (`$capture`, `$lbl`) **no son thread-safe**. El bucle principal planifica.
- **Llamada directa al CLI**, sin `powershell.exe` intermedio (§11).
- **El popup no bloquea**: se cierra por plazo desde el bucle.
- **La ruta local es todo-o-nada**: media orden ejecutada es peor que ninguna.

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
- Los MP3 se reproducen con **MCI** (`AX::PlayMp3`, winmm.dll), no con
  `System.Windows.Media.MediaPlayer`: ese necesita un Dispatcher y encaja mal
  en el bucle WinForms.
- `ReadLineAsync` con tope de 8 s: si la red se cuelga, el bucle no se bloquea.

---

### Las cuatro rutas (el asistente elige sola, sin modos)

| Frase | Ruta | Coste |
|---|---|---|
| `abre steam`, `sube el volumen`, `recuerda que…` | Local | < 1 s |
| `qué hora es`, `cuánta batería`, `repite` | Local | < 1 s |
| `quién inventó el ajedrez` (`$RE_PREGUNTA`) | Modelo, **sin herramientas** | ~13 s |
| `crea un archivo en el escritorio` | Agente completo | 25-160 s |

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
  run-opencode.ps1     # runner suelto; ya NO se usa, sirve para probar el CLI
  memoria\             # vault de Obsidian (§8)
  piper\               # TTS offline de respaldo (97 MB)
  tmp\                 # temporales; tmp\voz = cache de audio
  tools\diag\          # diag-buttons.ps1 (calibrador) y otros
  legacy\voicedict.ps1 # script antiguo, referencia
  assistant.log        # eventos      replies.log  # respuestas completas
```

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

### Bloqueados

- ❌ **Tarea programada**: `Register-ScheduledTask` da **acceso denegado**
  incluso para una tarea por usuario con disparador «al iniciar sesión». No es
  viable sin admin. La clave `Run` se queda (no da reinicio automático).
- ⏸ **git**: no está instalado (`winget install Git.Git`). El `.gitignore` ya
  está escrito.

### Abiertos

1. **Ampliar `commands.json`** con el uso real. El log escribe
   `LOCAL descarta: no reconozco '<trozo>'`, que dice exactamente qué falta.
2. **Confirmación cuando la coincidencia es dudosa**: si se acertó por
   aproximación lejana (no por coincidencia exacta ni por contención),
   preguntar «¿Little Nightmares III?» antes de lanzar. Debe llevar
   **autocancelación por tiempo**, para no repetir el error del modo pegajoso.
3. Ideas nuevas: ver §15.

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
```
