# Cómo se buscan ideas nuevas en Nova — el método, para repetirlo

*Escrito el 25/09/2026 de noche, cuando braya dijo «guarda esta estructura, me gusta». Esto no
es una lista de ideas: es **la máquina que las produce**. Cuando pida «busca ideas nuevas», se
usa esto y no se improvisa otra cosa.*

**El script está en `tools\ideas\buscar-ideas.workflow.js`** y se lanza con la herramienta
Workflow. Este documento explica **por qué** está hecho así, que es lo que no se puede deducir
leyendo el código.

---

## El problema que resuelve

En doce documentos hay ya unas **150 ideas** propuestas. Pedir «dame ideas» sin más produce
siempre las mismas tres cosas, y las tres son basura:

1. **Ideas que Nova ya hace.** Ha pasado **siete veces**: el repaso del 25/09 encontró que 7 de
   las 24 ideas «vivas» de las 50 de autonomía **estaban enteras en el código** y el documento
   se había quedado atrás. La 20 (qué juego te gasta la batería) existía **desde el 13/09**.
   Proponer trabajo hecho cuesta más que no proponer nada, porque parece progreso.
2. **Generalidades.** «Mejorar el reconocimiento de voz» no es una idea: no se puede
   implementar, no se puede medir y dos personas la harían distinta.
3. **Ideas sin número.** «Nova podría avisar de X» — ¿cuántas veces pasa X? Si la respuesta es
   cero, la idea está muerta y nadie lo sabe hasta que alguien la implementa. La **regla 3 de
   la casa** existe justo para esto.

---

## La estructura, en dos fases

### Fase 1 — Barrido multi-modal: 20 ángulos, cada uno ciego a los demás

**Por qué 20 ángulos y no un agente pidiendo veinte ideas:** un solo buscador encuentra siempre
el mismo tipo de cosa. Veinte buscadores con **parcelas distintas** encuentran veinte tipos de
cosa, y ninguno puede acaparar. Cada uno recibe una zona del sistema y la orden de **mirar antes
de proponer**.

Los veinte ángulos, y qué busca cada uno:

| Ángulo | Qué destripa |
|---|---|
| `contadores` | los ~59 contadores de `estadisticas.json`: cuáles se escriben y no deciden nada |
| `muertas` | funciones definidas sin llamador, ramas inalcanzables, ficheros que se escriben y no se leen |
| `numeros-fijos` | constantes escritas a mano que deberían aprenderse solas (**lo que más le importa a braya**) |
| `log-uso` | patrones repetidos en los 14 días de registro que Nova no aprovecha |
| `ordenes-fallidas` | lo que braya pidió y no consiguió: repeticiones seguidas, descartes, errores |
| `consola` | el hardware de la Ally sin usar: batería, temperatura, red, TDP, mando |
| `capsula` | lo que se podría **enseñar** sin hablar, y cuándo la cápsula no se ve |
| `charla` | `charla_worker.py`, el cerebro, la continuidad de la conversación |
| `oido` | autonomía de la cascada Vosk/Parakeet/Whisper/Canary |
| `tiempo` | horarios y rutinas de `habitos.json`, y las rupturas de rutina |
| `autoconocimiento` | lo que Nova no sabe de sí misma: sus tiempos, sus caídas, si va peor que ayer |
| `errores` | los WARN/ERROR repetidos y los `catch {}` que se tragan fallos en silencio |
| `iniciativa` | cuándo hablar y cuándo callar, con el sistema de avisos que ya existe |
| `juegos` | cómo juega braya (rachas, abandonos, cansancio) más allá de lo ya propuesto |
| `privacidad` | datos personales que acaban donde no deben, audio guardado, ficheros sin ignorar |
| `aprender` | sacar más de las pocas correcciones que braya hace, sin aprender basura |
| `mando` | segunda vía física para lo que hoy solo se puede decir hablando (**regla 7**) |
| `red` | qué hace cuando no hay internet o la nube tarda |
| `ficheros` | `memoria\*.json`: quién los lee, cuáles se quedaron parados, cuáles crecen sin tope |
| `continuidad` | qué pierde en cada uno de los ~12 reinicios diarios |

**Las cinco órdenes que recibe cada buscador** (esto es lo que hace que sirvan):

1. **Primero mira, luego propón.** Con `grep`, `awk`, `Read` y PowerShell sobre el repo. Nada
   que no se haya comprobado en el código o en los datos.
2. **Cada idea lleva un número contado por él.** El número es lo que decide si merece la pena:
   *«pasa 40 veces en 14 días»* es una idea; *«podría pasar»* es ruido. **Si cuenta y sale cero,
   la idea está muerta: la descarta él mismo y busca otra.**
3. **Comprobar que no existe ya**, con `grep` del nombre de la función y del concepto.
4. **Nada de generalidades.**
5. **Que se pueda implementar** en PowerShell 5.1, C# (WPF) o Python, en una consola sin GPU
   potente. Sin servicios nuevos ni modelos grandes.

### Fase 2 — Un revisor adversarial pegado a cada ángulo

Va **en pipeline, no con barrera**: en cuanto un ángulo termina, su revisor arranca, mientras
los otros diecinueve siguen buscando. No hay ninguna razón para que el ángulo `capsula` espere a
que acabe `log-uso`.

Al revisor se le dice explícitamente que **su trabajo no es mejorar las ideas, sino tumbarlas**.
Mata una idea si:

- **Ya existe** — y tiene que buscarla de verdad, con varios nombres posibles.
- **El dato es falso o no se puede reproducir** — vuelve a contar el número él mismo. Si sale
  otro, lo corrige; si sale cero, la idea se cae.
- **No se puede implementar aquí**, o rompería la regla 4 (bloquear el bucle) o la 5 (residente
  comiendo RAM).
- **Es una generalidad disfrazada.**
- **Rompe la regla 1**: haría que Nova ejecutara algo que no se le pidió.
- **Ya está en la lista de prohibidas.**

Y una instrucción que decide los casos dudosos: **ante la duda razonable sobre si ya existe,
matarla.** Es más barato perder una idea que meter trabajo duplicado.

---

## Lo que hay que pasarles siempre

Tres bloques de contexto, y sin ellos el barrido no vale nada:

1. **Las siete reglas de la casa** (están en `NOVA-TODO.md`). Sin ellas proponen cosas que
   bloquean el bucle o dejan procesos residentes.
2. **Lo que braya quiere, dicho por él**: velocidad sobre todo; **todo adaptativo** (un número
   fijo escrito a mano es un fallo, no un ajuste); decidir con datos y preguntar solo si hay
   gasto, privacidad o gusto; medir con uso real.
3. **El índice entero de lo ya propuesto** — los títulos de los doce `IDEAS-*.md` más
   `AUTONOMIA.md`. Se saca así:

```bash
grep -E "^###? " IDEAS-*.md AUTONOMIA.md
```

**Este bloque hay que actualizarlo en cada tanda.** Es lo único del script que caduca: cada
tanda nueva añade ideas que la siguiente no debe repetir.

---

## Cómo se usa

1. Sacar el índice de lo ya propuesto (el `grep` de arriba) y meterlo en la constante
   `PROHIBIDO` del script.
2. Lanzar `tools\ideas\buscar-ideas.workflow.js` con la herramienta Workflow.
3. Leer el resultado: `vivas`, `muertas` y `porAngulo`.
4. **Mirar `porAngulo` antes de la siguiente ronda.** Un ángulo que produce 8 ideas y salva 1
   está agotado: en la ronda siguiente se **cambia por otro**, no se repite. Repetir el mismo
   ángulo da las mismas ideas.
5. Repetir rondas hasta llegar al número que pidió braya, cambiando los ángulos flojos.
6. Escribir las supervivientes en un `IDEAS-AAAA-MM-DD-*.md` con su dato y su fuente.

---

## Fase 3 — La criba dura, que hace falta y no estaba en el plan

**Lo que enseñó la tanda del 25/09:** de 180 propuestas sobrevivieron **143**, un 79 %. Eso no
es que las ideas fueran buenas: es que **un revisor pegado a su propio lote es blando**. Seis
ángulos salvaron el **100 %** de lo que propusieron, y un revisor que no mata ni una no está
revisando.

Así que hay una tercera fase, y en las próximas tandas va desde el principio:

1. **Dedup cruzado, con tres lentes independientes** sobre la lista entera. Veinte buscadores
   trabajando a ciegas encuentran la misma cosa desde ángulos distintos: en esta tanda, el
   silencio que cierra la frase salió en `numeros-fijos` y en `oido`; cuándo empieza la noche,
   en `iniciativa` y en `tiempo`; y si la consola está en la mano, en `consola` y dos veces en
   `mando`. Las tres lentes agrupan **por mecanismo** (tocan la misma función), **por efecto**
   (hacer una deja la otra sin trabajo) y **por dato** (se apoyan en la misma medición). Un
   grupo sólo cuenta si **dos de las tres lentes lo ven** — así una lente sobreagrupadora no
   se lleva por delante ideas distintas.
2. **Dos filtros en cadena por lote, con revisores nuevos** que no han visto nacer las ideas:
   - **«¿ya lo hace Nova?»**, con la obligación de pegar el comando que corrió. Sin la prueba,
     el veredicto no vale.
   - **«¿aguanta el dato y se puede hacer?»**, reproduciendo cada número citado. Si sale cero o
     medía otra cosa, la idea se cae.
3. **Valoración** de las supervivientes (valor 1-10, coste 1-10, y si acerca el 100 % de
   comprensión), que es lo que convierte la lista en orden de trabajo.

**La regla que resume esto:** *quien propone no puede ser quien salva, y quien revisó una vez no
revisa dos.*

---

## Rendimiento por ángulo — se rellena en cada tanda

Esto es lo que dice qué ángulos merecen repetirse y cuáles están secos. **Sin esta tabla, la
segunda tanda repite los errores de la primera.**

### Tanda del 25-26/09/2026 — 180 propuestas, 121 finales

**Cómo leer esto:** `r1` es lo que salvó su propio revisor; `final` es lo que quedó vivo y sin
fusionar tras las tres cribas. La distancia entre las dos columnas es lo que mide **lo blando que
fue el revisor de ese ángulo** — y la última columna dice si el ángulo sigue teniendo mina.

| Ángulo | Propone | r1 | Final | Muertas | Absorbidas | ¿Repetirlo? |
|---|---|---|---|---|---|---|
| `aprender` | 10 | 10 | **9** | 0 | 1 | Sí, el más productivo |
| `ficheros` | 10 | 8 | **8** | 0 | 0 | Sí |
| `privacidad` | 8 | 8 | **8** | 0 | 0 | Sí, y ninguna cayó |
| `tiempo` | 8 | 8 | **7** | 0 | 1 | Sí |
| `autoconocimiento` | 9 | 9 | **7** | 0 | 2 | Sí |
| `oido` | 10 | 9 | **7** | 2 | 0 | Sí |
| `capsula` | 9 | 8 | **7** | 1 | 0 | Sí |
| `muertas` | 8 | 8 | **6** | 1 | 1 | Sí |
| `charla` | 10 | 8 | **6** | 0 | 2 | Sí |
| `juegos` | 8 | 8 | **6** | 0 | 2 | Sí |
| `iniciativa` | 10 | 8 | **6** | 1 | 1 | Sí |
| `consola` | 8 | 6 | **5** | 1 | 0 | Sí |
| `contadores` | 9 | 4 | **4** | 0 | 0 | Su revisor fue el más duro y acertó |
| `errores` | 10 | 8 | **4** | 1 | 3 | Solapa mucho con otros |
| `red` | 8 | 5 | **3** | 0 | 2 | Agotándose |
| `numeros-fijos` | 11 | 8 | **3** | 2 | 3 | **Agotado**: lo suyo lo encuentran los demás |
| `continuidad` | 9 | 4 | **3** | 0 | 1 | Agotándose |
| `mando` | 9 | 6 | **3** | 1 | 2 | Agotándose |
| `ordenes-fallidas` | 8 | 7 | **3** | 3 | 1 | **Agotado**: 3 de 7 eran cosas ya hechas |
| `log-uso` | 8 | 3 | **1** | 0 | 2 | **Agotado** |

**Para la próxima tanda:** cambiar `numeros-fijos`, `ordenes-fallidas` y `log-uso` por ángulos
nuevos. No es que sean malos temas — es que lo que encuentran **lo encuentran también los demás**,
y acaban absorbidos al fusionar. Mantener `aprender`, `privacidad`, `ficheros` y `oido`, que son
los que más ideas propias dejaron.

Coste de la tanda: **98 agentes** (20 buscadores + 20 revisores + 3 lentes de dedup + 30 cribas +
25 resolvedores de grupo), **13,4 millones de tokens**, 4.524 usos de herramientas, ninguno caído.

---

## Por qué no se hace de otra manera

- **Un agente pidiendo 100 ideas** da 100 títulos y ningún número. Lo importante no es la idea,
  es el dato que la sostiene, y eso obliga a mirar el código de verdad.
- **Sin revisor adversarial**, sobrevive todo, incluido lo que Nova ya hace. El revisor es lo
  que convierte una lluvia de ideas en una lista de trabajo.
- **Sin la lista de prohibidas**, la mitad vuelve a ser lo mismo con otras palabras.
- **Sin la orden de «si sale cero, descártala tú»**, el revisor tiene que hacer todo el trabajo
  sucio y se le escapan cosas.
