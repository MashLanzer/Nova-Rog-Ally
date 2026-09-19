# Qué modelo le conviene a Nova, medido (19/09/2026)

braya preguntó: **¿es mejor el modelo local, llama o el CLI de Claude para las tareas
que le mando a Nova, y cuál es más rápido con y sin juegos delante?**

## Cómo se midió

- **Las frases son suyas**, no inventadas: 401 dictados únicos sacados de `assistant.log`,
  filtrados a los que acaban en un modelo, curados a 18 tareas reales. Se usan **tal y como
  llegaron**, con la transcripción imperfecta incluida («Cierra también la aplicación de
  Xbook», «Cierra lo último que habrete»), porque eso es lo que recibe el modelo en vivo.
- **El prompt es el suyo**: se extrae de `charla_worker.py` con `ast` sin ejecutarlo, así que
  es literalmente `SISTEMA + SISTEMA_ORDEN + SISTEMA_API` (1.631 caracteres).
- **La tarea medida es la real**: clasificar en `[ORDEN]` / `[API]` / contestar. 12 órdenes,
  5 de charla, 1 que necesita internet.
- Se mide **arranque en frío** y **latencia en caliente** por separado, porque Nova precarga.
- Medidor: `pruebas/medir-modelos.py`.

## Sin juego delante (3,5-6,5 GB libres)

| Motor | Aciertos | Mediana | En frío |
|---|---|---|---|
| **claude-haiku-4-5** (API) | **17/18** | **0,65 s** | 1,05 s |
| **qwen2.5:3b** (local, el actual) | 16/18 | 1,08 s | 1,57 s |
| qwen2.5:1.5b (local) | 13/18 | 0,93 s | 0,89 s |
| llama3.2:1b (local) | 10/18 | 1,81 s | 11,90 s |
| llama3.2:3b (local) | 7/18 | 2,16 s | 21,14 s |
| claude-code (CLI) | 6/6 | 7,00 s | — |

## Con Wukong delante (3,2 GB libres, el juego en el menú)

| Motor | Aciertos | Mediana | En frío |
|---|---|---|---|
| **claude-haiku-4-5** | **18/18** | **0,64 s** | 1,24 s |
| qwen2.5:3b | 16/18 | 1,25 s | **23,77 s** |
| qwen2.5:1.5b | 11/18 | 1,34 s | 12,79 s |

## Lo que dicen los números

1. **La API no se entera del juego.** Haiku pasa de 0,65 s a 0,64 s con Wukong delante:
   idéntico, porque el trabajo se hace fuera de la consola.
2. **Al modelo local el juego le destroza el arranque**, no la respuesta. qwen2.5:3b en
   caliente apenas sufre (1,08 -> 1,25 s), pero **cargarlo pasa de 1,57 s a 23,77 s**: 15
   veces más. El problema es meter 1,9 GB en una RAM que el juego ya ocupa, no generar texto.
3. **llama es peor que qwen en los dos tamaños**, y no por poco: 7/18 y 10/18 frente a 16/18
   y 13/18. Llama se salta la instrucción de responder `[ORDEN]` y se pone a explicar. Queda
   descartado; la pregunta de braya tiene respuesta clara.
4. **qwen2.5:3b es el mejor local y ya es el que usa Nova.** La configuración actual acierta.
5. **El CLI acierta todo (6/6) pero tarda 7,00 s**, once veces más que la API, porque arranca
   un proceso entero por invocación. Sirve para tareas de agente, no para clasificar órdenes.

## Margen de error

No sobreinterpretar diferencias de uno o dos aciertos. La misma tanda de qwen2.5:1.5b sin
juego dio **11/18 y 13/18** en dos ejecuciones idénticas (temperatura 0,3), así que el ruido
es de unos ±2. Lo que sí es sólido por tamaño del salto: llama (7-10) < qwen (13-16) <
haiku (17-18), y todas las latencias.

## Consecuencia práctica

La arquitectura actual (API primero con Haiku, qwen2.5:3b de respaldo) es la correcta y no
hay que tocarla. Lo que esta medición sí refuerza es **la guarda que se arregló esta misma
mañana** (`Test-ApiContestaPrimero`, commit `af8961a`): precargar qwen teniendo la API
disponible no es solo gastar 1-2 GB, es que **con un juego delante esa precarga cuesta 24
segundos**. La guarda valía más de lo que parecía cuando se escribió.

Lo que no cambia nada de esto: de las 305 frases que se van al modelo, solo 22 son tareas
reales. El 93 % restante es transcripción rota. **El sitio donde se gana es el oído, no el
cerebro.**
