# La velocidad del oído, medida (20/09/2026)

Esto nace de `C20` («medir whisper.cpp con la Radeon / Vulkan», apuntado desde el 15/09 como
«el camino más directo a un oído más rápido»). Antes de instalar nada pesado, lo primero era
saber **dónde está el tiempo de verdad**. Todo lo de aquí sale de `pruebas\audio\uso`, que son
grabaciones reales de braya, no de tandas leídas.

## 1. Cuánto tarda cada motor, sobre uso real

| motor | veces | mediana | p90 | máximo |
|---|---:|---:|---:|---:|
| **base** (el repaso normal) | 190 | **1,38 s** | 2,74 s | 37,63 s |
| **small** (el oído fino) | 60 | **4,16 s** | 8,48 s | 61,36 s |
| turbo (apagado desde el 15/09) | 23 | 16,21 s | 22,87 s | 76,53 s |

La duración del audio de una orden: mediana **5,00 s**, p90 8,50 s.

O sea que `base` va a RTF ≈ 0,28 y `small` a ≈ 0,83. Los máximos disparatados (37 s, 61 s) son
del racimo del 16/09, con dos instancias cargando Whisper a la vez; eso ya lo corta el cerrojo
del worker y no vuelve a contar.

## 2. ¿El oído fino compensa esos 2,8 s de más?

Sí, y por un margen que sorprende. Sobre los **47 audios** en los que corrieron los dos motores,
comparando no el texto sino **la acción que resuelve la capa local**:

| | |
|---|---:|
| las dos sacan orden | 4 |
| **solo el oído fino** | **8** |
| solo base | 2 |
| ninguna | 33 |

**Neto: +6 órdenes de 47.** Y no son matices, son frases que base deja inservibles:

| base oyó | small oyó | y entonces resuelve |
|---|---|---|
| «¿Hay algo de escagándose? ¿Qué hora es» | «¿Hay algo descargándose en Steam» | estado de las descargas |
| «¿Trabajo el segundo video de YouTube» | «Reproduce el segundo vídeo de YouTube» | reproducir |
| «Seja el explorado de Dios» | «Cierra el explorador de chivos» | cerrar explorador |
| «Ok, Puedes ponernos temporizados de 5 minutos» | «Ok, ¿puedes poner un temporizador de 5 minutos» | temporizador de 5 min |

Conclusión: **el oído fino se queda**, y acelerarlo sí tiene valor, porque es justo el que salva
las órdenes difíciles.

## 3. Lo que Vulkan tendría en contra

Antes de gastar una tarde en compilar `whisper.cpp` con Vulkan, tres cosas que ya se saben y que
apuntan en contra:

1. **La GPU es la del juego.** Hoy Whisper corre en CPU *a propósito*, con prioridad por debajo
   de lo normal, y el comentario del código lo dice: «No le quita CPU al juego». Pasarlo a la
   iGPU cambia eso justo en el caso de uso principal de la consola. Una RDNA 2 de 8 CU a 15-20 W
   no tiene sitio para dos cosas a la vez.
2. **La memoria también es la del juego.** La iGPU no tiene VRAM propia: sale de los mismos
   16 GB. Con la reserva en 4 GB y un juego pesado delante, el margen es el que es.
3. **El oído fino no corre siempre.** Entra 60 veces de 312 órdenes (19 %), solo cuando Parakeet
   y base no sacan nada. Acelerar lo que corre en uno de cada cinco casos rinde menos de lo que
   parece.

Lo que **no** está medido y sería lo único que justificaría intentarlo: si Vulkan sobre este chip
da 3× o más *con el juego delante*. Sin ese número, C20 no se abre.

## 4. Lo que sí es gratis: los hilos

`HILOS_PRECISO` está en **8** desde el 14/09, cuando se midió que «base pasa de 2,0 a 1,7 s con
los mismos aciertos». Pero el Z2 A tiene **4 núcleos físicos** y 8 hilos lógicos: en SMT los dos
hilos de un núcleo se pelean por la misma unidad de coma flotante, y en cargas así 8 puede ser
igual o peor que 4 — además de calentar más en un aparato de 15-20 W.

Nadie lo ha vuelto a medir desde entonces, y ahora el oído fino es `small`, no `base`. La medida
está en `tools\medir-hilos-whisper.py`, que prueba 2/4/6/8 hilos sobre grabaciones reales con
varias vueltas, se queda con el mejor tiempo de cada una y **solo recomienda cambiar si la
diferencia pasa del 5 %**.

**Resultado: no se toca. `HILOS_PRECISO = 8` se queda.** Y el camino hasta ese «no» es la
parte que merece la pena contar, porque dos veces estuvo a punto de salir un «sí» falso.

| medición | 2 hilos | 4 hilos | 6 hilos | 8 hilos | veredicto que daba |
|---|---:|---:|---:|---:|---|
| 1ª (por el **mejor** tiempo) | 92,1 | 58,1 | **47,8** | 76,9 | «baja a 6: −38 %» |
| 2ª (por la **mediana**) | 87,5 | 69,1 | **66,5** | 76,9 | «baja a 6: −14 %» |
| 3ª (**alternando** 4/8) | — | **68,5** | — | 70,8 | «se queda: −3 %» |

Tres cosas que salieron mal por el camino, y las tres son de método, no del chip:

1. **Decidir por el mejor tiempo.** La 1ª medición recomendaba 6 hilos con 47,8 s… y una
   mediana de 82,0 s, peor que la de 4. El mínimo premia al que tuvo un hueco de suerte.
2. **Medir con algo más corriendo.** Yo mismo lancé una prueba en paralelo durante la 1ª.
   Ahora el script calcula la dispersión entre la mejor y la peor vuelta y **avisa** cuando
   pasa del 25 %, en vez de dar un número bonito.
3. **Medir con un juego abierto, sin saberlo.** Aquí me equivoqué y conviene que quede
   escrito. Achaqué la dispersión al calor (15-20 W, veinte minutos de CPU al máximo y baja de
   frecuencia), que es una hipótesis razonable... pero al terminar miré los procesos:
   **It Takes Two llevaba abierto desde las 12:55 y había acumulado 37.845 s de CPU** — unos
   **2,3 de los 4 núcleos** de media, durante las tres mediciones. Ese era el ruido. Las dos
   primeras medidas se hicieron con el juego comiéndose más de la mitad de la máquina, y yo
   encima le estaba quitando el resto con Whisper.

**Lo que sí sobrevive, y es lo importante:** alternando 4,8,4,8 las dos configuraciones comen
exactamente la misma interferencia, sea del juego o del calor. Por eso el **3 %** es el número
bueno, y por eso la respuesta es que **no se toca**. Y hay un detalle a favor: medido así, con
un juego pesado delante, es *justo el escenario en el que Nova trabaja de verdad*.

**Dos reglas para la próxima medición en esta consola**, las dos aprendidas a golpes:
- **Mirar qué hay abierto antes de medir, no después.** `Get-Process | Sort WorkingSet` lleva
  dos segundos y habría ahorrado dos mediciones enteras.
- **Alternar siempre el orden** entre configuraciones. Es lo único que salvó la tercera.

*Un dato que sí queda, de propina:* `small` va a **RTF ≈ 0,79** en este chip, mida como mida.

## 5. Y el otro número que nadie tenía: cuánto tarda la nube

`C9` («que Nova ajuste **sola** el tope de la nube») no se podía ni empezar, y no por falta de
motor —`P4` le dio uno con binomial de verdad— sino por falta de dato. El tope
(`escucha.nubeTopeMs`) nació en 2.500 ms y se subió a 7.000 el 19/09 porque 2,5 s se quedaba
corto. Nadie sabe si 7 sobra o falta, **porque hasta hoy solo se apuntaba si la nube llegó
(`nube-sirvio`) o si se pasó del tope (`nube-tarde`), nunca cuánto tardó la que sí llegó.**

Con eso, lo único que Nova sabía hacer era apagar la nube entera. Afinar el tope es otra cosa:
un tope por debajo del p90 tira respuestas buenas, y uno muy por encima solo hace esperar de
más cuando la nube no va a contestar.

Ahora se guardan esos tiempos (`memoria\nube-tiempos.json`, los últimos 200). Tres decisiones
de diseño que conviene no reabrir:

- **Fichero propio, no `estadisticas.json`.** `Get-Estadisticas` cachea en memoria y solo relee
  tres claves, así que meter una cuarta obliga a tocar el corazón de las estadísticas y sus
  pruebas; y esto se escribe en cada respuesta de la nube.
- **Solo números, nunca la frase.** Por eso —al revés que `senales-fallo.jsonl` y
  `activaciones.jsonl`— este fichero **no** necesita entrar en la lista de `Invoke-Olvido`.
- **Con menos de 20 no dice un número.** Un p90 de tres muestras es una corazonada con aspecto
  de dato. Es el mismo listón que el resto de decisiones propias (`DecisionMinIntentos`).

Y se puede preguntar en voz alta («¿cuánto tarda la nube?»), porque un dato guardado que nadie
mira no sirve de nada. Prueba propia: `tools\probar-nube-tiempo.ps1`.

**Lo que falta para cerrar C9** es exactamente lo mismo que falta para todo lo demás: que braya
use Nova unos días. Con la ventana abierta el 20/09, hoy hay cero muestras.
