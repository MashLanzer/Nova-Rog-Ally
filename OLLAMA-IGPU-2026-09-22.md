# C24 / VRAM-9: la charla local, tres veces más rápida (22/09/2026)

El pendiente venía de `VRAM-2026-09-19.md:151`, y decía esto:

> «Si Ollama con `OLLAMA_IGPU_ENABLE=1` (Vulkan sobre la Radeon) iría más rápido que en CPU:
> nadie lo ha probado; **con 4 GB de VRAM probablemente no compensa**.»

Medido con `tools/medir-ollama-igpu.py` (seis peticiones sacadas de su propio log, a
qwen2.5:3b, con Nova parada). **La suposición era falsa.**

| | primera palabra | tokens por segundo | dónde está el modelo |
|---|---:|---:|---|
| como estaba (CPU) | 0,47 s | 9,6 | 0 % en la GPU |
| `OLLAMA_IGPU_ENABLE=1` | **0,29 s** | **29,3** | 100 % en la GPU (2.084 MB) |
| | **+38 %** | **+205 %** | |

Tres veces más rápido generando. En la charla —que es el camino que braya nota rápido— eso
es la diferencia entre una respuesta que se va desgranando y una que sale de golpe.

## Activado

`OLLAMA_IGPU_ENABLE=1` como variable de usuario. Se quita en una línea:

```powershell
[Environment]::SetEnvironmentVariable('OLLAMA_IGPU_ENABLE', $null, 'User')
```

(y reiniciar Ollama). Se activa sin preguntar porque los datos son claros, no cuesta dinero
ni manda nada fuera, y braya prioriza la velocidad. Ver `voice-ctrl-decide-con-datos`.

## Lo que hay que saber, y no es menor

**En esta consola la VRAM sale de la misma RAM.** Es una APU: los 4 GB de «VRAM» de la Radeon
son 4 GB que Windows deja de ver. Así que meter el modelo en la GPU **no ahorra memoria, la
cambia de sitio**: con qwen cargado quedan ~600 MB libres igual que antes.

Lo que ya protege eso, y no ha hecho falta tocarlo:

- `assistant.ps1:20114` — **jugando, el modelo de charla sale de la RAM** si llevas 30 s sin
  hablarle. Esa guarda existía desde antes y ahora vale igual.
- `keep_alive: 2m` en `charla_worker.py:337` — sin usarlo, Ollama lo suelta a los dos minutos.
- `Test-RamParaCharla` — no lo precarga si no hay sitio.

**El riesgo que queda**, y no está medido: hablarle **mientras** juegas. Ahí el modelo pide
2 GB de VRAM de los 4 que tiene la Radeon, compitiendo con el juego. Ollama cae a CPU solo si
no cabe, pero puede haber tirones mientras dura la conversación. Si pasa, se quita con la
línea de arriba.

## Un fallo de la herramienta, encontrado usándola

`parar_ollama()` mataba `ollama.exe` pero **no los `llama-server` que deja detrás** — Ollama
lanza uno por modelo cargado. Quedaron dos huérfanos de 1.675 y 551 MB que dejaron la consola
en **376 MB libres** y empezaron a matar procesos. Arreglado: ahora también mata
`llama-server.exe`.

Es el mismo patrón del día: el fallo no salió de leer el código, salió de usarlo.
