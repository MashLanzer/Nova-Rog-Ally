# Memoria del asistente de voz

Este es un **vault de Obsidian** y a la vez la memoria permanente del asistente.
Ábrelo en Obsidian con *Abrir carpeta como almacén* apuntando a esta carpeta:

```
C:\Users\braya\Documents\voice-ctrl\memoria
```

## Cómo funciona

La memoria no es un contexto de conversación que se pierde al reiniciar: son
archivos Markdown normales. Sobreviven a todo, los puedes leer y editar tú, y
Obsidian los enlaza y busca.

Hay dos caminos, a propósito:

| Acción | Quién la hace | Cuánto tarda |
|---|---|---|
| **Guardar** — «recuerda que…» | El asistente, en local | < 1 s |
| **Recordar** — «¿qué sabes de…?» | opencode leyendo esta carpeta | 25-60 s |

Guardar es instantáneo porque solo escribe una línea. Recordar necesita
entender la pregunta y rebuscar, y eso sí justifica esperar.

## Estructura

- `diario/` — una nota por día (`2026-09-10.md`). Ahí cae todo lo que dictas
  con «recuerda que…», con su hora.
- `temas/` — notas por asunto, para lo que quieras organizar a mano o pedirle
  al asistente que ordene.
- `README.md` — esto.

## Para el agente (opencode)

Cuando te pregunten por algo recordado:

1. Busca en `diario/` y `temas/` de esta carpeta.
2. Responde **breve y hablado**: la respuesta se lee en voz alta, así que nada
   de listas largas ni bloques de código.
3. Si no encuentras nada, dilo claramente en una frase. No inventes recuerdos.
4. Si te piden organizar o resumir, escribe en `temas/` y enlaza con
   `[[nombre-de-nota]]` para que Obsidian lo conecte.
