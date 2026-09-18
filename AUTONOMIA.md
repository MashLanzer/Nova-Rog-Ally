# Nova se controla sola

braya: «busco no solo controlarla yo, sino que ella se pueda controlar, tomar decisiones por
ella misma sin que yo tenga que despertarla».

**Autonomía real = decide + actúa + rinde cuentas + se puede deshacer hablando.** Una idea
que no traiga las cuatro cosas no entra aquí. El patrón que ya funcionó, y que se repite en
todas:

> mira sus propios números → decide → **lo dice en voz alta con el dato** → se revierte
> diciéndoselo → y no vuelve a decidir lo mismo ese día si se lo devuelves.

Los tres frenos de siempre: **historial mínimo** (con cuatro datos no se juzga), **una vez
al día** (no en cada vuelta del bucle) y **nunca jugando ni con un invitado delante**.

---

## Ya hecho (17/09)

- **Se revisa a sí misma y apaga lo que no le sirve.** `Test-RevisionPropia`. El primer caso
  salió de sus números, no de una opinión: el último recurso se lanzó **29 veces y sirvió 1**,
  costando 16,2 s de mediana. Ella sola lo apagó. 16 casos en `probar-revision-propia.ps1`.
- **Lo que decide se deshace hablando.** `Undo-DecisionPropia`. «Deshaz lo que has cambiado»,
  «vuelve a poner el último recurso». Y «deshaz» a secas, cuando no hay nada tuyo pendiente,
  deshace lo suyo. Antes solo se podía editando `config.json` a mano.

### Y tres cosas que YA decide sola desde antes (para no proponerlas otra vez)

- La **ganancia del micro** se calcula sola (`escucha.ganancia = auto`).
- `Watch-Acelerometro` **se apaga para siempre** si la primera lectura tarda o viene vacía.
  Es el precedente de «medirse y desactivarse», y de ahí sale la idea **33**.
- Ya escribe sola `memoria\estadisticas.md` y un parte semanal en `memoria\semanas\`. Lo que
  **no** hace es actuar sobre lo que ahí escribe: de ahí salen las ideas **31, 32 y 60**.

---

## Las 10 primeras

Cada una con **el dato que la justifica** (no son ideas al aire) y **su freno**.

**1. Apagar la nube que no le sirve.** — **HECHA (17/09)**
*Y lo primero fue descubrir que no se podía decidir todavía.* El log enseñaba **29 llamadas**
a Gemini y las estadísticas decían `nube-nada: 1`: no cuadraba. El motivo es que había tres
contadores de **desenlace** (`sirvio`, `nada`, `tarde`) y **ninguno de intento**, así que si
la nube contestaba vacío —o si el oído local ya había sacado la orden— el lanzamiento no
dejaba rastro en ningún sitio. Decidir con eso habría sido decidir sobre un dato falso.
Así que la idea son dos cosas: **el instrumento y luego la decisión**.
- `Start-NubeOir` apunta ahora **cada intento** (`nube-intento`), que es el único punto por el
  que pasan todos los lanzamientos.
- Y hay un contador nuevo, `nube-sobra`, para cuando la nube **acierta pero ya no hacía
  falta**: una nube que siempre llega tarde no aporta aunque acierte siempre, y eso antes no
  se distinguía de equivocarse.
- Con ≥20 intentos y menos del 15 % de aciertos, la apaga sola, lo dice con sus números y se
  deshace hablando.
- **Freno nuevo que salió al hacerla: una sola decisión al día.** `Save-DecisionPropia` guarda
  una; si tomara dos el mismo día, la segunda pisaría a la primera y la primera se quedaría
  sin poder deshacerse. Tiene su propio caso en la prueba.
*22 casos nuevos en `probar-revision-propia.ps1`, incluido uno que vigila que el contador de
intentos siga existiendo: si alguien lo quita, la decisión vuelve a ser sobre un dato falso.*

**2. Mover ella sola el umbral de confianza.**
Hoy: ruido **3 de 97** y **132** activaciones. Si el ruido sube, más exigente; si se le
escapan activaciones tuyas, que afloje. *Freno: pasos pequeños, una vez al día.*

**3. Apagar el oído fino cuando deje de aportar.**
Hoy **sí** aporta (27 de 81 = 33 %), pero ya se inventa 5. Con el listón del 15 % que usó
para el turbo, que lo apague el día que baje. *Freno: el listón ya probado, no uno nuevo.*

**4. Bajar su gasto sola al ver un juego, y devolverlo al salir.**
fps de la cápsula, revisor parado, modelos soltados. *Freno: decirlo una vez, y deshacerlo
solo al cerrar el juego.*

**5. Dejar de ofrecer lo que siempre rechazas.**
Ya guarda `rechazadas` en `habitos.json`. Tres noes y deja de proponerlo.

**6. Aprender del «deshaz» sin que se lo expliques.**
Si deshaces en menos de 30 s lo que acaba de hacer, que se lo apunte como rechazo. Hoy solo
aprende si le dices «no era eso». *Ataca la meta de cero órdenes equivocadas.*

**7. Limpiarse por espacio, no por calendario.**
Cuando el disco baje del umbral, podar lo más viejo y decir qué tiró. *Freno: nunca lo del
día en curso.*

**8. Ajustar el oído por hora y por ruido.**
Tiene `ritmo` y `charlaHoras`. *Freno: solo franjas con muchos días de datos.*

**9. Rehacer sola tu huella de voz.**
El tono aprendido son **119,6 Hz**. Recalcular con muestras nuevas y **avisar del cambio**.

**10. Ponerse un presupuesto de tiempo y rendirse a tiempo.**
Si una orden va camino de pasar de X segundos encadenando repasos, renunciar y decirlo (el
turbo costaba 16,2 s).

---

## 20 más

### Su propio cuerpo: memoria, arranque y recursos

**11.** Decidir **qué modelos carga al arrancar según la RAM libre**.
**12.** Soltar modelos **por el uso real, no por un plazo fijo** (`soltar_preciso_si_toca`).
**13.** **Autodiagnóstico al arrancar**: micro, voz y cápsula; si la voz online no responde,
pasar a Piper **y decirlo**.
**14.** Elegir **voz online o local por latencia medida**.
**15.** Vigilar **su propio tamaño de datos** y compactar o archivar por meses.
**16.** **Recuperarse de un worker muerto con paciencia creciente**: tres muertes seguidas,
desactivarlo y decirlo.

### Entenderte mejor sin que se lo pidas

**17.** **Reordenar sus propios patrones** por lo que más aciertas.
**18.** **Crearte atajos sola** para lo que repites (hoy solo propone).
**19.** **Aprender a abrir lo que instalas** sin que se lo enseñes.
**20.** **Retirar reglas suyas** que no se disparan en un mes o fallan siempre.
**21.** **Desactivar recetas que fallan**: ya cuenta `fallos`, que decida ella el corte.
**22.** **Dejar de dar los avisos que ignoras** (nunca batería crítica ni seguridad).
**23.** **Ajustar el volumen de su voz al ruido** de la habitación.

### Cuándo callarse y cuándo actuar

**24.** **Callarse cuando otra cosa usa el micro** (`Test-EnLlamada`, ampliado).
**25.** Afinar el **modo noche con tus horas reales**. *Ojo: ya calcula «esta hora no sueles
estar levantado» y tu hora habitual de dejarla; falta que MUEVA el modo, no que lo sepa.*
**26.** **Callarse en la franja en que siempre la mandas callar.**
**27.** Decidir entre **palabra o botón según lo que funciona** (`soloBotonEnJuego` es fijo).

### Gastar con cabeza

**28.** Decidir **cuándo merece la pena la IA cara**.
**29.** **Copia de seguridad cuando toca**: cambios importantes **y** tú sin hablarle.
**30.** Ampliar el **parte semanal que ya existe** (`memoria\semanas\`) con lo que decidió
sola. *No es crearlo: es que se incluya a sí misma.*

---

## 30 más

### Que EJECUTE lo que ya escribe

**31. Retirar el filtro de recitados cuando sobre.**
`estadisticas.md` ya dice, escrito por ella: «si `recitado` baja a cero durante semanas,
quizá ya no hace falta el filtro». Que lo retire ella y lo diga, en vez de dejar la frase ahí.

**32. Reaccionar cuando el micro empieza a cazar audio.**
La otra mitad de esa misma frase: «si `recitado` sube, el micrófono está cazando audio». Hoy
lo escribe y no pasa nada. Que baje ganancia o suba exigencia, y lo cuente.

**33. Generalizar el autoapagado del acelerómetro.**
`Watch-Acelerometro` ya se apaga solo si la primera lectura tarda o viene vacía. Aplicar ese
mismo criterio a **todos** los vigilantes: el que no responde o no da nada útil, se apaga.

### Afinar sus propios números, que hoy son fijos en `config.json`

**34. `autoSordinaRachas` (3), `autoSordinaVentanaMin` (5) y `autoSordinaMinutos` (10).**
Tres números puestos a ojo. Que los calcule con sus rachas de ruido reales.

**35. `holdMs` (1100).** Medir cuánto tardas **tú** en soltar el botón y ajustarlo.

**36. `autoSubmitMs` (2500).** Igual con tus pausas reales al dictar: ya las mide (la pausa
más larga dentro de una orden fue 0,81 s).

**37. `soloYoMargenHz` (35) y `soloYoMinimo` (12).** Estrecharlos según lo separada que esté
tu voz de las demás que ha oído.

**38. `avisos.bateriaPct` (15).** Aprender a qué porcentaje enchufas de verdad y avisar ahí.

**39. `entorno.nocheDesde` / `nocheHasta`.** Moverlos con tus horas medidas, no con las que
se escribieron el primer día.

**40. `confirmacion.esperaMs`.** Cuánto tardas en contestar «sí» o «no», medido.

### Decidir con lo que ya vigila

**41. Dejar de vigilar logros de un juego que no los da.**
`Watch-LogrosSteam` lee un `.bin` cada poco. Si un juego no suelta logros, dejarlo.

**42. Ajustar el historial del portapapeles.**
`Watch-Portapapeles` guarda 10 fijos. Que lo suba o baje según cuántos reutilizas de verdad.

**43. Aprender qué dispositivos son normales.**
`Watch-Dispositivos` avisa de lo que aparece. Los que entran y salen a diario (tus cascos)
no son noticia: que deje de anunciarlos.

**44. Aprender qué música te gusta por lo que NO saltas.**
`Watch-Musica` y `musica.json` ya guardan lo que suena. Lo que no saltas, gusta.

**45. Aprender qué notificaciones te importan.**
`Watch-Notificaciones` las ve todas. Que aprenda de cuáles reaccionas y calle el resto.

**46. Retirar reglas de apps que ya no abres.**
`Watch-AppsReglas` vigila apps que quizá llevan meses sin abrirse.

**47. Cortar sola al agente cuando se eterniza.**
`Watch-OpencodeProgress` ya sigue el progreso. Que decida rendirse con su propia mediana.

### Sobre su propio conocimiento

**48. Podar el cerebro por lo que nunca se usa.** Guarda `usos` por recuerdo: lo que en
meses no se ha usado ni una vez, archivarlo.

**49. Retirar traducciones que ya no hacen falta.** Si la capa local ya entiende la frase
original, la traducción aprendida sobra (hoy hay 2 guardadas; el día que haya 200, importa).

**50. Fundir recetas duplicadas.** Dos recetas que hacen lo mismo con distinta frase son una
receta con dos variantes.

**51. Limpiar su `perfil.md` de lo caducado.** Lo que se contradice con algo más reciente no
debería seguir contando como verdad.

**52. Archivar fechas y recordatorios pasados** en vez de arrastrarlos para siempre.

**53. Retirar alias aprendidos que nunca se usan.** Si te enseñó un nombre y no lo has vuelto
a decir en meses, sobra y estorba al reconocimiento.

### Rendir cuentas y no repetir errores

**54. Medir si sus propias decisiones acertaron.** Apagó el último recurso: ¿subieron los
fallos después? Si sí, volver atrás **ella**.

**55. No insistir en una decisión que ya deshiciste dos veces.** A la segunda, retirarla de
su lista para siempre y decirlo.

**56. Saber explicarse cuando le preguntes «¿por qué hiciste eso?»** con el número que usó,
no con una frase amable.

**57. Avisar cuando lleva mucho sin poder decidir** por falta de datos: «llevo dos semanas
sin suficientes intentos para juzgar el oído fino».

**58. Detectar una mala racha y ofrecer volver a lo de fábrica.** Si lleva días fallando más
de lo normal, proponer deshacer **todos** sus ajustes de golpe.

**59. Guardar una foto de su configuración antes de cada auto-ajuste.** Hoy se guarda la
última decisión; con una foto se puede volver a un día entero.

**60. Incluirse en el parte semanal que ya escribe.** Una sección de «lo que decidí, con qué
dato, y si acerté». Si no puede explicar una decisión con un número, es que no debía tomarla.

---

## Cómo se elige la siguiente

1. ¿Hay **dato propio** que la justifique? Si no, primero se mide.
2. ¿Se puede **deshacer hablando**? Si no, no se implementa.
3. ¿Qué pasa si se equivoca? Si la respuesta es «se queda callada» o «se queda un modo
   puesto sin saberlo», va con aviso obligatorio o no va.
4. ¿**Ya existe a medias**? Antes de escribir nada, mirar: el parte semanal, las horas
   habituales y el autoapagado del acelerómetro ya estaban, y tres ideas de las primeras
   tandas hubo que corregirlas por eso.
