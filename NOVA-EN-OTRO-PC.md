# Nova en tu laptop — cómo, sin romper la de la consola

*Todo lo de aquí está medido el 24/09/2026 sobre esta máquina y este repositorio. Los números
llevan al lado de dónde salen.*

---

## La respuesta corta

**Sí se puede, y no hay que construir casi nada.** Nova es mucho más portátil de lo que parece:

- **No hay ni una ruta a fuego en el código.** Todo se calcula desde la carpeta del script.
- **Ninguna de las 163 órdenes se rompe** por estar en un portátil: lo que parece de consola
  —brillo, energía, batería, clips, volumen— va por **API de Windows, no de ASUS**.
- **Los tres binarios ya viajan compilados** en el repositorio (`nova_ui.exe`,
  `assistant-dx.dll`, `wake_worker.exe`), y el hash de seguridad cuadra. No hace falta
  compilar.
- **La pantalla no ata nada**: el tamaño y la esquina de la cápsula se calculan al arrancar.
- **El micrófono se recalibra solo** desde el 22/09: lo aprendido aquí no estorba allí.

**Lo que sí se pierde, y es lo importante:** en un portátil sin mando desaparece **la única
entrada que no es la voz**. El gatillo `≡` está en **un solo sitio de 26.800 líneas**, y no hay
ningún atajo de teclado global. Eso choca de frente con la regla 7 de la casa (con un 70,4 % de
comprensión, todo lo que dependa de una palabra necesita una segunda vía). Volvemos a ello.

---

## Lo que hay que mover, con su tamaño

| | de dónde sale | tamaño |
|---|---|---|
| **El repositorio** (292 ficheros) | `git clone` | **6 MB** |
| `vosk/` — **sin esto Nova es sorda a su nombre** | alphacephei.com (URL en el `.gitignore`) | 58 MB |
| `piper/` — la voz de respaldo | github.com/rhasspy/piper/releases | 98 MB |
| `modelos/canary` — primer escalón del repaso | (el que usa `config.json` hoy) | 198 MB |
| Whisper `base` + `small` | **se bajan solos** la primera vez | 606 MB |
| `qwen2.5:3b` — el modelo local de la charla | `ollama pull` | ~2 GB |
| `stockfish` — solo si quieres el ajedrez | github | 100 MB |

Lo que **no** hace falta copiar: `parakeet` (641 MB) y `omnilingual` (350 MB) — el primero es el
oído titular pero degrada solo si falta, y el segundo lleva fuera de la cascada desde el 22/09.

---

## ⚠️ Lo primero de todo: GitHub está cuatro días atrás

**`git clone` HOY no te trae la Nova de hoy.** Medido:

```
git rev-list --count origin/main..main  →  183 commits
git diff --shortstat origin/main main   →  227 ficheros, +43.784 / -1.250
```

El último commit que hay en GitHub es del **20/09 a las 02:16**. Todo lo de estos cuatro días
—las dos tandas de veinte ideas, los 172 bancos, los arreglos de hoy— **está solo en esta
consola**.

**Antes de tocar la laptop, sube desde la consola:**

```powershell
powershell -NoProfile -File tools\subir-a-github.ps1
```

Hazlo en una ventana de verdad (pide credenciales). Si no subes, la laptop nacerá con una Nova
de hace cuatro días.

---

## El único camino por el que la laptop puede romper la consola

Y es uno solo: **`config.json`**.

Ese fichero **está versionado**, lleva **cuatro rutas con tu nombre de usuario** dentro, y
**Nova lo reescribe sola**: hay 12 llamadas a `Set-Cfg` que tocan la escala de la cápsula, la
esquina, el color, la velocidad de la voz, el modelo de Whisper, la última decisión… Si las dos
Novas lo commitean, se pisan.

Las cuatro rutas, medidas:

```
paths.opencodeCli     C:\Users\braya\AppData\Roaming\npm\...\opencode.exe
paths.claudeCodeCli   C:\Users\braya\AppData\Roaming\npm\...\claude.exe
paths.workDir         C:\Users\braya\Documents
paths.nodeDir         C:\Program Files\nodejs
```

Las tres primeras se rompen si el usuario de Windows de la laptop no se llama también `braya`.

**La protección, y es una línea en cada máquina:**

```powershell
git update-index --skip-worktree config.json
```

Con eso, git deja de mirar ese fichero **en las dos**: la laptop usa el suyo, la consola el
suyo, y un `git pull` no puede pisar ninguno. Hazlo **en la consola también**, para dormir
tranquilo.

---

## La memoria: la decisión que tienes que tomar tú

**Un `git clone` te da una Nova amnésica.** Medido: `git ls-files memoria` devuelve
**exactamente un fichero**, el README. Todo lo demás está en `.gitignore`: tu perfil, las 5
recetas, los hábitos, los juegos, las estadísticas, el cerebro de la charla (277 KB de
vectores), las reglas y las claves. Son **412 KB** en total.

Tres opciones, y las tres están medidas:

**(a) Que empiece de cero** — la que recomiendo. Es otra máquina, otro sitio, otro micrófono y
otro ruido de fondo. Que aprenda sus propios hábitos es lo coherente, y no hay ningún riesgo.

**(b) Que herede lo de hoy** — copias **una vez**, por USB, el ZIP más reciente de `copias\`
(`lo-aprendido_2026-09-24_2044.zip`, 197 KB, 40 entradas) y lo descomprimes allí. **Saca
`config.json` del ZIP antes**, o volverás a meter las rutas de esta máquina.

**(c) Memoria compartida por OneDrive** — **no lo hagas.** Está medido: la única línea de
OneDrive del código copia el ZIP diario a `OneDrive\Nova\copias` y **no existe restauración**;
es un camino de ida. Y si forzaras la sincronización, la última en escribir se llevaría el día
entero de la otra: Nova reescribe `perfil.md`, `habitos.json` y `estadisticas.json` enteros,
no por líneas.

---

## El orden exacto, en la laptop

**Antes:** en la consola, `tools\subir-a-github.ps1` y `git update-index --skip-worktree config.json`.

1. **Instalar lo que hace falta** (versiones exactas de esta máquina):
   - **Python 3.12.10** — la ruta está clavada a `Python312`, así que instala esa serie.
   - `pip install vosk==0.3.45 sounddevice==0.5.6 numpy faster-whisper==1.2.1 sherpa-onnx-core edge-tts miniaudio comtypes httpx onnxruntime ctranslate2`
   - **Git**, **Node** (para opencode), **Ollama**, y **ffmpeg** (`winget install Gyan.FFmpeg`).
   - *Lo imprescindible para que arranque son `vosk` y `sounddevice`.* Sin `sherpa_onnx` o sin
     `chess` Nova arranca igual: se capturan y degradan solas.
2. **`git clone`** del repositorio.
3. **`git update-index --skip-worktree config.json`** y edita ahí las cuatro rutas de `paths`.
4. **Bajar a mano** `vosk/` (58 MB, obligatorio) y `piper/` (98 MB). Las URLs están escritas en
   el propio `.gitignore`.
5. **`ollama pull qwen2.5:3b`** si quieres la charla local.
6. **Arrancar**: `powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File assistant.ps1`
   (así arranca aquí; no hay tarea programada ni nada en Inicio salvo Ollama).
7. La primera vez, Whisper se baja `base` y `small` solo (606 MB). Si no quieres esperar,
   copia de `C:\Users\braya\.cache\huggingface\hub` las dos carpetas
   `models--Systran--faster-whisper-base` y `--small`. **No copies `large-v3-turbo`** (1,5 GB):
   está apagado.

**Lo que NO hay que hacer:** compilar. `tools\compilar-ui.ps1` y `tools\recompilar-dx.ps1` solo
hacen falta si editas `nova_ui.cs` o `assistant-dx.cs`. Y si recompilas el DLL, hay que borrar
`seguridad.hashDll` de `config.json`, como dice el propio comentario del código.

---

## Lo que allí será distinto

**Peor:**

- **Sin mando no hay segunda vía.** El gatillo `≡` es la única entrada que no es la voz. Jugando
  es aún más grave: con un juego delante la palabra de activación se ignora a propósito (viene
  del 11/09, cuando Nova se activaba sola y abría cosas), así que **sin mando y jugando, Nova
  queda incomunicada**. Las listas cerradas y el sí/no degradan solos a voz; la lupa, no.
  *La solución sería un atajo de teclado global, pero hay que hacerlo con cuidado: un hook mal
  puesto se traga teclas del juego, que es la regla 4.* No está hecho.
- **`HILOS_PRECISO = 8` está a fuego** y coincide justo con los 8 hilos de este chip (Ryzen Z2
  A, 4 núcleos / 8 lógicos). En otra CPU habría que mirarlo: no se recalcula solo.

**Mejor:**

- **Sobra RAM.** Aquí Windows ve 11,7 GB de 16 y los modelos se sueltan por plazos calibrados
  para eso. Con más memoria, esos plazos pueden ser más generosos.
- **La lista de juegos de Steam sería idéntica** (depende de la cuenta, no de la máquina), pero
  la de *instalados* será distinta: eso sale del registro de Windows y del `libraryfolders.vdf`
  de cada equipo.

---

## Resumen para decidir

| | |
|---|---|
| ¿Se puede? | **Sí**, y sin construir nada |
| ¿Cuánto hay que mover? | 6 MB de repo + ~360 MB obligatorios + lo que elijas |
| ¿Qué puede romper la consola? | **Solo `config.json`**, y se blinda con una línea |
| ¿Comparten memoria? | **No lo hagas.** Que cada una aprenda lo suyo |
| ¿Qué se pierde allí? | La segunda vía del mando, que es la regla 7 |
| ¿Hay que hacer algo antes? | **Sí: subir a GitHub.** Va cuatro días y 182 commits atrás |

---

*Escrito el 24/09/2026. Cada cifra se puede volver a sacar: `git ls-files`, `git rev-list`,
`du -sm`, y el `.gitignore` con las URLs de los modelos dentro.*
