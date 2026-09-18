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

**2. Mover ella sola el umbral de confianza.** — **NO se hace todavía; salió algo mejor**
*Lo que se buscaba:* en el log hay **49 descartes por confianza**, y el texto es voz tuya
limpia (`'nova'` 25 veces, `'hola nova'` 4, `'ey nova'` 3), con un margen pequeño: a 0.10 o
menos en el 53 %. Parecía la prueba de que el umbral estorbaba, y encaja con tu queja de
«cuando le digo nova no se activa».
*Lo que decía el reparto por día:* **41 de los 49 son del 11/09**. Los días siguientes tienen
4, 5 y 0. El 11/09 es justo cuando la ganancia arrancaba en x8 y el micro saturaba — el fallo
que **ya se arregló** (`8d00a14`, 16/09), y que `probar-escucha.py` documenta así: «sus dos
quejas eran el MISMO fallo». Bajar el umbral ahora sería arreglar con datos **anteriores al
arreglo anterior**.
*Lo que sí salió, y vale más:* **ninguna decisión propia puede salir de un solo día.** Al
mirarlo, lo mismo le pasaba a lo que Nova **ya decide**: los 29 intentos del último recurso
son de **una única tarde** (15/09, 100 % concentrado). La decisión era correcta en el fondo,
pero el método era frágil.
→ **`Test-DatosRepartidos`**: ahora toda decisión exige **3 días distintos** y que **ningún
día pase del 70 %**. Aplicado a las dos decisiones que ya existían (último recurso y nube).
Con los números de hoy, el último recurso **no se habría decidido**, y eso es lo correcto.
*8 casos nuevos en la prueba, incluido uno con los 29 intentos reales de braya: comprueba que
con esos datos NO decide.*
*Pendiente:* la bajada de umbral en sí, cuando haya descartes repartidos en varios días
posteriores al arreglo de la ganancia. Hoy no los hay.

**3. Apagar el oído fino cuando deje de aportar.** — **HECHA (17/09)**
*Y con un matiz que mejora la idea original:* **los inventos cuentan en contra**. El fino
acierta 27 de 81, pero **se inventa la orden 5 veces** (`fino-invento`, que es rama
excluyente de `fino-sirvio`, comprobado). Un invento no es «no aportó»: es **una orden
equivocada**, justo lo que menos toleras. Así que lo que se mide es el acierto **neto**:
acertó menos inventó.
Comprobado antes de contar nada: `fino` cuenta cada repaso pedido por sus dos caminos y
ambos hacen `return` (no se duplica), y `fino-ahorrado` es el camino en que **no** se pide,
así que no ensucia el denominador.
**Hoy no se apaga, por dos motivos independientes**, y los dos tienen su caso con los
números reales: el neto es (27−5)/81 = **27 %**, muy por encima del 15 %; y el reparto
concentra el **74 %** en un solo día, por encima del tope del 70 %.
`$WhisperPreciso` se lee en vivo en las cuatro puertas que deciden si repasar, así que
apagarlo surte efecto en el acto —a diferencia del umbral de la idea 2— y se deshace
hablando. *14 casos nuevos, incluido el que demuestra que con 10 aciertos y 9 inventos sí lo
apaga, y con los mismos 10 aciertos sin inventos no lo toca.*

**4. Bajar su gasto sola al ver un juego, y devolverlo al salir.** — **YA ESTABA HECHA**
Aplicado el criterio 4 (*¿ya existe a medias?*) antes de tocar nada, y la respuesta es que sí,
casi entera, y no de esta tanda:
- `soltar_parakeet_si_toca`, `soltar_preciso_si_toca` y `soltar_ultimo_si_toca` sueltan los
  tres modelos con un juego delante;
- el revisor de charla se descarga (`revisor_parado`);
- la conversación no se precarga jugando;
- la palabra pasa a solo botón (`solo-boton.flag`);
- los fps de la cápsula ya se bajaron (15/20/30);
- y **sí se devuelve al salir**: `Exit-Juego` restaura el brillo, con `restaurarAlSalir: true`
  activo en la configuración de braya.

**DESCARTADO — soltar Vosk jugando.** Era la única pieza que faltaba y parecía gratis: si
jugando solo vale el botón, el modelo de la palabra sobra. **Pero no sobra**: `modelo` se usa
también para crear los reconocedores del **dictado** (líneas 630, 637, 643, 976 y 1547).
Soltarlo jugando **rompería el botón**, que es justo lo único que funciona con un juego
delante. Se destruiría lo que se quiere proteger.

**5. Dejar de ofrecer lo que siempre rechazas.** — **HECHA (17/09)**, y al revés de lo que
parecía. El filtro **ya existía** y era más duro de lo que pedía la idea: dejaba de proponer
**al primer «no»**, no a los tres. Lo que faltaba era lo contrario, **dejar de vetar**:
- **El veto no caducaba nunca.** Comprobado: ni una sola línea que pode esa lista. Un «no»
  suelto de hace meses vetaba esa propuesta el resto de la vida de Nova, y las costumbres
  cambian. Ahora un «no» caduca a los **60 días** y la propuesta vuelve **una** vez.
- **La lista mezclaba dos cosas.** También se añade lo que **aceptas** (para no reofrecer algo
  que ya es una regla). Eso **no** debe caducar: la regla existe. Así que ahora se distingue
  «sí» (permanente) de «no» (caduca).
- **Las entradas viejas se respetan como permanentes**: no se puede saber si fueron un sí o un
  no, y equivocarse hacia el lado de no molestar es lo correcto.
*Dos trampas que se llevaron por delante el primer intento:* las claves **ya llevan `|`
dentro** (`app|edge|abre spotify`), así que la fecha no podía pegarse con ese separador y las
entradas pasaron a ser objetos; y la línea que las lee hacía `[string]$r`, que habría
convertido cada objeto en `"System.Collections.Hashtable"` **perdiendo la lista entera en
silencio**.
*19 casos en `probar-propuestas.ps1` (2n19), incluidos los dos que sujetan el sentido: lo
aceptado sigue vetado cinco años después, y lo rechazado vuelve al día 60.*

**6. Aprender del «deshaz» sin que se lo expliques.** — **HECHA (17/09)**
Deshacer algo que acaba de pasar es decirle que estuvo mal, sin tener que explicarlo. Pero
esta idea tenía un peligro que podía dejarla peor que antes: **«abre steam» reconocido
limpio, ejecutado bien, y luego «deshaz» porque cambiaste de idea NO es una orden
equivocada**. Apuntarla haría que Nova dejase de entender una orden buena. El propio
`probar-rechazos.ps1` ya lo avisaba: *«una frase vetada para siempre por una vez que
cambiaste de idea sería peor que el problema que arregla»*.
**Así que aprende solo si se cumplen las dos cosas:** que la orden sea **reciente** (menos de
30 s, con la marca de tiempo que `$script:ultimaOrden` ya llevaba) **y** que viniera de algo
**dudoso** — una traducción aprendida o una receta de hace menos de 3 minutos. De un
reconocimiento limpio no se aprende nada: solo se deshace.
El núcleo que hacía `no era eso` (apuntar el rechazo, marcarlo como fallo medible, olvidar la
traducción o la receta) se ha sacado a **`Invoke-AprenderDelError`** y ahora lo comparten los
dos caminos: cuando lo dices, en modo normal; cuando solo deshaces, en modo conservador.
*17 casos nuevos. Los que sujetan el sentido: una orden limpia deshecha **no** se apunta y
«abre steam» sigue entendiéndose; y cuando vino de una traducción se apunta **tu** frase, no
la orden a la que se tradujo.*
*Y una trampa del lenguaje que costó un caso en rojo:* el doble de `Get-Recetas` en la prueba
devolvía la lista **sin la coma** (`return ,$lista`), así que PowerShell la desenrollaba, la
función recibía una copia y su `.Remove()` no tocaba el original. El código real sí la lleva.
La prueba mentía, no el código.

**7. Limpiarse por espacio, no por calendario.** — **NO PROCEDE (medido 17/09)**
Todo lo que Nova genera suma **~61 MB**: 33,4 de audios de uso (189 archivos) y 27,5 de
`tmp`, con `memoria` entera en **0,2 MB**. Enfrente hay **115 GB libres**. Es el **0,05 %**
del espacio disponible. Una poda por umbral de disco sería código que no se ejecuta nunca, y
con el riesgo de borrar de más por un error de cálculo.
**Y la premisa de la idea era falsa:** no hay ninguna limpieza «por calendario» que sustituir.
Lo que hay es lo correcto ya:
- la **caché de voz** se poda sola (tope 60 MB, hoy al 23 %) y se lleva su `.env` en pareja;
- hay un **barrido de restos** de órdenes canceladas (`in|out|err|raw-` de más de un día), que
  además se salta el banco para no tocar archivos de una orden viva.
De los 1.075 archivos de `tmp`, **955 son esa caché**. El resto es estado vivo, más 13
`.bak-*` (~3,2 MB) que son copias de mis propias sesiones de parcheo: basura de desarrollo,
no de Nova.
*Si algún día procede, la pieza ya está:* Nova sabe leer el espacio libre
(`AvailableFreeSpace`), que es lo que usa para contestarte cuánto queda.

**8. Ajustar el oído por hora y por ruido.** — **NO PROCEDE (medido 17/09)**
Misma causa que la idea 2, y conviene que quede junta: **41 de los 57 descartes son del
11/09**, el día del fallo de ganancia ya arreglado, y ese día contamina **todas** las franjas
(14h:3, 15h:7, 16h:4, 17h:6, 18h:5, 19h:11, 20h:5).
Los días limpios (15 y 16/09) tienen **5 descartes cada uno**, repartidos de uno en uno. Solo
dos franjas tienen descartes en 3 días o más —las 18h y las 19h— y **quitando el 11/09 quedan
4 y 2**. Con eso no se decide nada: las franjas que peor pinta tienen (16h, 11h) son
justamente las que menos datos tienen (5 y 6 activaciones en total).
**Y de aquí sale una idea nueva, la 61:** `Test-DatosRepartidos` exige días distintos, pero
**no** exige que los datos sean **posteriores al arreglo de la cosa que se mide**. Dos veces
ya (ideas 2 y 8) los datos que invitaban a actuar eran de antes de arreglar el problema que
los causaba.

**9. Rehacer sola tu huella de voz.** — **HECHA (17/09)**, y la mitad ya estaba
`Update-MiVoz` **ya la rehacía sola**: lleva una media `{f0, n}`, descarta saltos de más de
60 Hz para que la voz de otro no arrastre tu referencia, y al llegar al tope (60) pasa a
**media móvil**. De hecho **ya se había movido y nadie se enteró**: era 119,6 Hz y hoy
`mi-voz.json` dice **116,8**.
**El agujero que apareció al mirarlo:** la guarda de 60 Hz impide un **salto**, pero no una
**deriva lenta**. En `tmpoces.json` la segunda voz de la casa está en **144,0 Hz**, a solo
**27,2 Hz** de la tuya — o sea **dentro** de esa guarda. Si esa persona usa el botón a menudo,
su tono entra poco a poco en tu media y un día «solo yo» la acepta a ella y duda de ti, sin
que nadie lo sepa.
**Lo que faltaba era enterarse**: ahora `mi-voz.json` guarda también la **referencia base**, y
cuando la media se aleja **15 Hz** de ella (menos de medio margen de «solo yo», que son 35)
Nova lo dice con los dos números y vuelve a fijar la base, para no repetirlo. No avisa con
pocas muestras, no avisa dos veces, y un invitado sigue sin tocar nada.
*11 casos nuevos en `probar-voz-dueno.ps1`.* *Y un error mío que la prueba destapó:* el bloque
quedó colocado **después** de que el probador borrase su carpeta temporal, así que cinco casos
fallaban por no encontrar el archivo. La prueba estaba mal puesta, no el código.

**10. Ponerse un presupuesto de tiempo y rendirse a tiempo.** — **NO PROCEDE: lo arregló la
idea 1** (medido 17/09)
**El turbo era el problema, y Nova ya lo apagó sola.** Quitándolo, la cadena del oído hoy es
**mediana 1,5 s y p90 5,0 s** (n=163), con solo **5 órdenes por encima de 10 s** y 3 por
encima de 20. Por motor: `base` 1,3 s de mediana, `small` 4,1 s… y `turbo` **16,2 s**, con un
máximo de 76,5. Un presupuesto para el oído rescataría 5 casos de 163, y meter un freno nuevo
en el camino del oído es justo donde más daño hace equivocarse.
**Y donde de verdad hacía falta, ya existía:** `Get-PlazoJob` (25 s para traducir o planear,
90 s para pregunta o charla, 4 min por defecto) con **rendición real** que además lo dice
(«el modelo tardó demasiado y lo he dejado»); `ReintentoMaxMs` por cada repaso; la vibración
del mando a los 8 s; la barra de progreso; y rendiciones propias en el correo y las recetas.
*Esto es lo más interesante del bloque: una decisión que Nova tomó sola dejó sin objeto a otra
idea de la lista.*

---

## 20 más

### Su propio cuerpo: memoria, arranque y recursos

**11.** Decidir **qué modelos carga según la RAM libre**. — **HECHA (17/09)**, aunque no
donde decía la idea.
*Al arrancar no había nada que decidir:* lo único que se carga entonces es **Vosk** y
**Whisper base**, y los dos son **imprescindibles** — sin ellos no hay palabra de activación
ni dictado por botón. Ponerles una guarda de RAM dejaría a Nova inútil, igual que soltar Vosk
jugando habría roto el botón (idea 4). La prueba incluye un caso que vigila que **no** se les
ponga.
*Lo que sí faltaba:* los modelos **perezosos** cargaban sin mirar la memoria — Parakeet
(**639 MB** en disco) y el oído fino (~500 MB en int8) —, y son exactamente los del incidente
documentado del **15/09**: con ellos y base a la vez quedaron **0,3 GB libres de 7,7** y
Whisper pasó de ~1 s a **12,9 s por orden**. Había guarda para la charla
(`Test-RamParaCharla`, 3000 MB) pero **ninguna** para estos.
- `ram_libre_mb()` mide con `ctypes` + `GlobalMemoryStatusEx`, **sin añadir dependencias**:
  comprobado que da lo mismo que `psutil` (2.414 MB por las dos vías).
- Umbrales propios y menores que el de la charla: **1200 MB** para Parakeet, **900** para el
  oído fino. No son 3000 porque estos no ocupan 2 GB.
- **Quedarse sin RAM no marca el modelo como roto.** `_parakeet_roto` y `_preciso_roto` son
  para siempre; esto es pasajero: al cerrar el juego hay sitio y se carga. Tiene su propio
  caso, y otro que comprueba que la guarda va **antes** del `try`.
*22 casos en `probar-ram-modelos.ps1` (2n20).*
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

## Inspección de las 10 primeras (17/09)

Hecha al cerrar la décima, como estaba previsto. Salieron **dos huecos reales**, y los dos
rompían reglas de la cabecera de este archivo.

**Hueco A — `Set-Cfg` ignorado, en los dos sentidos.** Las tres decisiones,
`Save-DecisionPropia` y `Undo-DecisionPropia` hacían `[void](Set-Cfg ...)`. `Set-Cfg`
**devuelve `$false` si falla**, y el repo ya tenía el patrón bueno en cuatro sitios (esquina,
color, escala, «solo yo»), que lo comprueban y lo dicen: *«pero no he podido guardarlo para la
próxima»*. Sin eso, Nova decía «he apagado el último recurso» y al reiniciar seguía encendido:
**mentía**. Y en el camino de vuelta, igual: «vuelvo a usar mi oído fino» y al reiniciar no.

**Hueco B — el aviso se perdía de madrugada.** Los avisos son de nivel `'medio'`, y
`Test-PuedoAvisar` se calla de noche, jugando, y mientras habla, dicta o espera un sí. Como
`Send-AvisoEntorno` **no reintenta nunca**, Nova podía apagar algo a las 4 de la mañana y **no
contarlo jamás**. Un cambio silencioso, que es justo lo que la cabecera prohíbe.

**La regla que sale, y que ahora cumplen las tres decisiones:**
> **Una decisión que no se puede guardar ni contar, no se toma.**
- Si `Set-Cfg` falla: se **revierte la variable viva**, no se avisa de nada y **no se marca el
  día**, para reintentarlo.
- Si no se puede avisar: **no se decide**, y tampoco se marca el día — así se reintenta *esa
  misma mañana* en vez de esperar a mañana (por eso la comprobación va **antes** de marcarlo).
- Y al deshacer, si no se puede guardar, se dice la verdad («si me reinicias, se apaga otra
  vez») y la decisión **sigue apuntada** para poder reintentarlo.
*14 casos nuevos en `probar-revision-propia.ps1`.*

### Y dos ideas nuevas que salen de la inspección

**62. Que los umbrales de las decisiones vivan en un solo sitio.**
El 15 % de aprovechamiento, los 20 intentos mínimos, los 3 días y el 70 % están repetidos **a
mano en las tres decisiones**. Hoy coinciden; dentro de tres meses, no. Una tabla los mantiene
juntos y hace evidente cuándo una decisión usa un criterio distinto **a propósito**.

**63. Que apunte cuándo aplaza una decisión, y por qué.**
La guarda nueva sale con un `return $false` **en silencio**. No es grave (no cambia nada), pero
si Nova lleva semanas sin decidir nada no habría forma de saber si es que no hay datos, o que
siempre la pillan de noche. Una línea de log al día lo resuelve.

---

## Una más, salida del trabajo (61)

**61. No decidir con datos anteriores al arreglo de lo que se mide.**
`Test-DatosRepartidos` ya exige 3 días distintos y que ninguno pase del 70 %, pero no sabe
que el 16/09 se arregló la ganancia. Dos ideas seguidas (la **2** y la **8**) invitaban a
actuar con datos que eran **secuela de un fallo ya corregido**. Haría falta una **fecha de
corte**: cuando Nova cambia algo que afecta a lo que mide, los datos de antes no cuentan para
decidir sobre ello. Ella ya apunta sus cambios en `auto-ajuste`, así que la fecha está.

---

## Cómo se elige la siguiente

1. ¿Hay **dato propio** que la justifique? Si no, primero se mide.
2. ¿Se puede **deshacer hablando**? Si no, no se implementa.
3. ¿Qué pasa si se equivoca? Si la respuesta es «se queda callada» o «se queda un modo
   puesto sin saberlo», va con aviso obligatorio o no va.
4. ¿**Ya existe a medias**? Antes de escribir nada, mirar: el parte semanal, las horas
   habituales y el autoapagado del acelerómetro ya estaban, y tres ideas de las primeras
   tandas hubo que corregirlas por eso.
