# C25 / OID-2: el Vosk grande, cerrado (22/09/2026)

El pendiente decía: **«Medir Vosk grande (2,3 GB): o sirve o se borra.»** Llevaba descargado
desde el 19/09 sin que nadie lo ejecutara nunca.

## La respuesta: no sirve, y ni siquiera hace falta medirlo entero

Se cierra por tres cosas, y la primera sola ya bastaba.

### 1. Vosk no transcribe las órdenes. Solo oye tu nombre.

Lo dice el propio `wake_vosk.py:73`:

> «Vosk pequeño sirve para la palabra de activación pero transcribe mal las órdenes.»

El camino de una orden es: **Vosk** detecta que has dicho «nova» → a partir de ahí graba →
y la orden la transcriben **Parakeet, Canary y Whisper**. Vosk no interviene en lo que se
entiende; solo en si Nova se despierta.

O sea que el modelo grande, aunque fuera perfecto, solo podría mejorar una cosa: oír tu
nombre. No arregla ni una sola orden mal entendida.

### 2. Y oír tu nombre ya funciona

De las últimas ocho activaciones del log: **cinco con confianza 1,00 y tres con 0,96**.

Los 45 descartes históricos por «suena demasiado flojo» no eran del modelo: eran de nivel de
señal, y se arreglaron el 22/09 haciendo el listón de ráfaga relativo a su voz en vez de un
número fijo. Cambiar de modelo no habría arreglado ninguno.

### 3. No cabe. Ni para medirlo.

Tres intentos de pasarle las 486 grabaciones murieron por falta de memoria:

| intento | cómo | hasta dónde |
|---|---|---|
| 1 | como proceso del harness | murió en el clip 475 **del modelo pequeño** |
| 2 | ídem, solo el grande | murió antes de los primeros 25 clips |
| 3 | desacoplado de Windows | murió tras 95 s de CPU, sin dejar ni error |

Con el modelo dentro, la consola bajaba a **1.418 MB libres de 11.979**. Para comparar: la
pila del oído de Nova (Vosk + Whisper base + Parakeet) son ~1.100 MB, y un juego pide 4-6 GB.
El modelo grande pediría 2,4 GB **permanentes** para mejorar algo que ya va al 96-100 %.

El informe de VRAM del 19/09 lo sospechaba —«con 4 GB de VRAM probablemente no compensa»—
y ahora está medido en vez de supuesto.

## Lo que sí salió de intentarlo

El modelo **pequeño** sí se midió entero (486 clips, en `pruebas/audio/medir-vosk-grande.json`),
así que queda como referencia si algún día hace falta comparar.

Y una lección de método: los procesos que lanza el harness tienen un límite de memoria propio.
Para medir algo que pase de ~2 GB hay que lanzarlo desacoplado con `Start-Process`. Aun así,
en esta consola ese modelo no entra.

## Qué hacer con los 2,3 GB de disco

`vosk/vosk-model-es-0.42` ocupa 2,3 GB y no se va a usar. **Borrarlo es decisión de braya**:
el pendiente decía «o sirve o se borra», y esto responde que no sirve, pero el disco es suyo.
Si se borra, `vosk/vosk-model-small-es-0.42` (57 MB) es el que usa Nova y no se toca.
