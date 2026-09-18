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
**12.** Soltar modelos **por el uso real**. — **HECHA (17/09)**, y la respuesta fue distinta
para cada modelo.
*El hueco no era el plazo, era la condición:* `soltar_preciso_si_toca` **solo soltaba si había
un juego delante**. Sin juego, el oído fino se quedaba en RAM para siempre (~500 MB) aunque
pasaran días. En todo el log **se soltó una sola vez**.
*Medido antes de elegir el número:* entre dos usos del oído fino pasan **111 s de mediana**,
pero el **30 % de los huecos pasa de 5 minutos**, el 18 % de 10 y el **13 % de media hora** (el
mayor, 59 horas). Recargarlo cuesta **2,5 s**. Retenerlo horas para ahorrar 2,5 s es mal
negocio → se suelta también sin juego, con **20 minutos** de paciencia (deja fuera al 82 % de
los huecos, así que no corta una racha de órdenes).
**Y a Parakeet no se le pone plazo, a propósito:** se usa cada **28 s de mediana** (p90 170 s,
solo el 8 % de huecos pasa de 5 min) y recargarlo cuesta **5,6 s**. Soltarlo por inactividad
sería contraproducente. Aplicar la misma regla a los tres habría sido lo cómodo y lo peor.
*8 casos nuevos en `probar-ram-modelos.ps1`, incluido el que vigila que Parakeet siga **sin**
plazo.*
**13.** **Autodiagnóstico al arrancar.** — **HECHA (17/09)**, y no había que diagnosticar
nada nuevo: había que **contarlo**.
*Lo que ya existía:* Nova **ya comprueba** sus piezas al arrancar —si falta `wake_vosk.py`,
`nova_ui.exe`, `commands.json` o el CLI del agente— y **ya degrada bien**: la voz baja en
cascada online → Piper → Windows, y hay vigilantes que avisan con un aviso a la vista cuando
una pieza se cae **en marcha**.
*El hueco:* todas esas comprobaciones de arranque **morían en el log**, donde nadie las ve.
Nova arrancaba a medias, saludaba «Listo» igual, y el fallo se descubría a la primera orden
que no funcionaba.
*Lo hecho:* se recogen las comprobaciones que **ya había** —sin añadir ninguna— y se cuentan
en el **saludo**, que existe justo para eso (el comentario de la línea 97 dice «saludo hablado
al arrancar: confirma que la voz funciona»). Si todo está bien, el saludo es el de siempre; si
no: *«Listo, pero arranqué a medias: me falta la cápsula y no encuentro el agente.»* Y queda
en las estadísticas como `arranque-medias`.
*16 casos en `probar-arranque.ps1` (2n21).* *Y un rojo falso que destapó un defecto de la
prueba:* uno de los textos buscados aparece **también en el comentario que yo mismo escribí**,
y como usaba `IndexOf` se quedaba en la primera aparición. Ahora recorre todas.
**14.** Elegir **voz online o local por latencia medida**. — **NO PROCEDE (medido 17/09)**
*La cascada ya existe y ya funciona en marcha*, no solo al arrancar: `Say` intenta
`Say-Online` y si devuelve falso cae a `Say-Piper` **en la misma frase** (8733-8734), y
devuelve falso por todas las vías que importan (sin respuesta en el plazo, respuesta de la
frase anterior, worker muerto). El cambio por latencia **ya ocurre**.
*Y el 1 % no justifica gobernarlo:* de **202 frases**, la voz online falló **2 veces**
(«sin respuesta»), y las otras tres vías de fallo están a **cero**. Piper está instalado, así
que la alternativa es real — simplemente no hace falta decidir nada.
*Además el instrumento no existe:* el único número es un `Log` que **solo se escribe en
charla** («o el log se llenaría de esto»), no distingue online de Piper y no llega a ninguna
estadística; sus 202 registros se parten 101/101 entre «ya preparada» y «sintetizada al
momento», que es un dato sobre la **caché**, no sobre el motor. Y Piper no mide nada
comparable. Habría que construir medidor, histórico y regla para gobernar 2 casos de 202, y
todo eso en el camino de la voz, que es de los delicados.
**15.** Vigilar **su propio tamaño de datos**. — **NO PROCEDE por tamaño (medido 17/09)**,
pero deja dos apuntes.
*Lo que pesa de verdad:* todo `memoria/` suma **~182 KB** — estadísticas 10,4 (6 días),
hábitos 4,7, recetas 4,7, diario 1,1, semanas 0,8 y el cerebro 158,7. Lo único voluminoso es
`pruebas/audio/uso` con **34 MB**, y son los `.wav` con los que se mide todo: justo lo que no
hay que compactar.
*Y las podas ya existen, repartidas:* `recientes` 40, `descartes` 30, `usos` 400, música 300,
notificaciones 30, variantes de receta 20, recetas `$RecetasMax`; y el cerebro tiene las suyas
(`MAX_RECUERDOS = 5000`, `MAX_PENDIENTES = 300`…) con un `_podar()` propio.
**Dos excepciones que sí quedan anotadas:**
- **`$s.dias` no se poda nunca.** Los `Select-Object -First 30` y `-First 14` son para
  **escribir el informe**, no para recortar el archivo. En tamaño da igual (~600 KB al año),
  pero **`Test-DatosRepartidos` y las tres decisiones recorren `dias`**: crece el coste de cada
  revisión un poco cada día. Podar por encima de, digamos, 120 días sería gratis.
- **`charla-YYYY-MM-DD.jsonl`**: uno por día, sin tope (60 KB en un solo día). Es lo único con
  ritmo apreciable, y archivarlos por meses sí tendría sentido el día que estorben.
**16.** **Recuperarse de un worker muerto con paciencia creciente.** — **NO PROCEDE
(medido 17/09)**
*Donde existe, está bien hecho y ha funcionado.* La escucha y la cápsula llevan 3 intentos,
comprobación **cada 30 s** (no en cada vuelta), aviso hablado una sola vez al rendirse,
degradación explícita al botón… y **rearme solo tras 5 minutos vivo**, con un comentario del
13/09 que documenta justo lo que esta idea pedía: *«un worker que muere cada 40 s reiniciaba
el contador sin parar y nunca se daba por perdido»*. Eso ya **es** paciencia creciente.
*Y ha hecho falta de verdad:* **15 muertes** del worker de escucha y **15** de la interfaz en
el log, todas resueltas en el intento 1/3 (una en el 2/3). Ninguna llegó a «no se sostiene».
*Donde no existe, tampoco hace falta:* `ttsIntentos`, `piperIntentos` y `charlaIntentos` no
existen, pero **el worker de voz no ha muerto ni una vez** (`voz online: el worker murió` = 0)
ni el de charla (`charla: el worker se cerró` = 0). Y su relanzamiento no es un bucle ciego:
la charla, al cerrarse, **reencamina la pregunta** en vez de reintentar, y la voz **cae a
Piper en la misma frase**.
Añadir contadores a tres workers que nunca han muerto sería código sin evidencia, y en el
camino de la voz.

### Entenderte mejor sin que se lo pidas

**17.** **Reordenar sus propios patrones** por lo que más aciertas. — **NO PROCEDE
(verificado 17/09)**, y por tres motivos que se suman.
*El dato no existe:* las estadísticas guardan la **ruta** (`local` 176, `traducida` 15,
`receta` 7…), no **qué patrón** acertó. Habría que instrumentar `Resolve-Fragment`, que corre
sobre **cada parcial mientras hablas**: el camino más caliente que tiene Nova.
*Reordenar rompería cosas:* en esas **1.315 líneas** hay **21 comentarios explícitos sobre el
orden** — «va ANTES de anotar: si no, "apunta lo copiado" guardaría una nota», «van ANTES que
"apunta…"», «los números a cifras ANTES de mirar ningún patrón»… No es una lista reordenable
por frecuencia: es una cadena con precedencias ganadas a base de fallos. En esta misma sesión
tropecé con dos (el «deshaz» genérico que se comía al específico, y «ponla siempre encima»).
*Y no hay nada que ganar:* la capa local ya resuelve **en menos de 1 s sin modelo**, y no hay
ni una medición de lentitud suya en el log. Sería optimizar lo que no duele a cambio de
arriesgar lo que sí.
**18.** **Crearte atajos sola** para lo que repites. — **NO PROCEDE (medido 17/09)**
*El mecanismo ya está entero:* `Find-Propuesta` detecta los tres patrones —la misma orden a la
misma hora, la orden que sigue a abrir una app, y tres órdenes encadenadas— y te lo ofrece
cuando no molesta. Lo que pedía la idea es **crearlo sin preguntar**.
*Pero no hay nada que crear:* hay **18 usos guardados**, «abre steam» sale 3 veces… y
**ninguna orden se repite en 3 días distintos**, que es el mínimo que `Find-Propuesta` exige.
Hoy Nova no propondría ni una vez, así que saltarse la pregunta no cambiaría **nada**.
*Y el precio sería alto:* quitar la confirmación es lo que convierte «aprende solo» en «hace
cosas que no pediste» — el mismo fallo que ya mordió con las reglas creadas por voz (3.2 #3).
Además rompería el equilibrio de la **idea 5**: el veto de una propuesta caduca a los 60 días
**porque hay una pregunta de por medio**; sin pregunta, esa caducidad se vuelve peligrosa.
*La forma sensata de esta idea ya está hecha:* Nova propone, tú dices sí, y entonces lo crea
sola y no vuelve a preguntarlo nunca.
**19.** **Aprender a abrir lo que instalas.** — **YA ESTABA, para lo que importa
(verificado 17/09)**
*Los juegos se aprenden solos:* `Update-Juegos` relee la biblioteca de Steam **cada 60 s**, con
un comentario que lo dice tal cual — «sin esto, un juego instalado después de arrancar no
existiría hasta el siguiente reinicio» — y hay otro refresco cada 2 min para las descargas. En
el log: «biblioteca de Steam: 14 juegos indexados». Instalas un juego y Nova lo conoce sin que
nadie le enseñe nada.
*Lo que no se aprende son las apps de escritorio:* `Resolve-Target` mira `commands.json`
(24 apps, 14 sitios) y `Find-Aproximado` sobre esa misma lista; si no está, devuelve `$null`.
Ese era el hueco.
*Pero no le ha pasado ni una vez:* de **11 órdenes de abrir** en el registro, **ninguna** falló
por app desconocida. Las que no se reconocieron son transcripciones rotas —«Abre St», «Abre
Sting», «Abre Team», «Abre este»— o frases de conversación entera. Encaja con lo ya medido
sobre la nube: **los errores son de oído, no de vocabulario**. Un buscador de programas
instalados no arregla «Abre Team».
**20.** **Retirar reglas suyas** que no se disparan o fallan. — **SIN SUJETO (medido 17/09)**
`reglas.json` tiene **0 entradas**: no hay ni una regla tuya que retirar. Las 1.095 líneas de
«REGLA» del log son del mecanismo interno (`Invoke-Reglas 'juegoAbre'` y demás disparos por
evento), no reglas guardadas. Y ya existe el filtro que impide **proponer** una regla si hay
otra igual. El día que haya reglas de verdad, esta idea vuelve a tener sentido; hoy no tiene
sobre qué actuar.
**21.** **Desactivar recetas que fallan.** — **YA ESTABA, y mejor de lo que pedía la idea**
El corte existe: `$r.fallos + 1` y, **a los 3 fallos seguidos**, la receta se borra y la orden
se reencamina al agente. El contador **se resetea al acertar**, así que son tres seguidos, no
tres en toda su vida.
*Y antes de borrarla hay algo que la idea no contemplaba: se intenta **repararla**.* La tarea
va al cerebro **con la receta rota y su error**, y la versión corregida ocupa su sitio
**conservando usos, confirmaciones y formas de decirlo**. El comentario lo explica: «antes una
receta que fallaba dos veces se borraba y se perdía lo aprendido».
*Y no hay nada que desactivar hoy:* las 4 recetas tienen **`fallos = 0`**.
**22.** **Dejar de dar los avisos que ignoras.** — **NO PROCEDE (medido 17/09)**
*Los frenos ya existen y están calibrados uno a uno*, no en bloque: cada aviso lleva **su
nivel y su plazo** — `bateria-baja` alto/20 min, `bateria-llena` bajo/**4 h**, `gmail-lleno`
medio/**una semana**, `hora-dormir` noche/8 h, `disco-poco` medio/12 h, `resumen-semana`
bajo/semana… — más un **tope global de 4 por hora**, silencio nocturno y silencio jugando.
*Y no hay nada que silenciar:* se han dado **7 avisos en total**, de tres tipos
(`bateria-llena` 2, `descarga-<juego>` 2, `gmail-lleno` 3).
*El dato que haría falta no existe:* `entornoVistos` guarda **cuándo** se avisó, no si
reaccionaste. Y aquí «reaccionar» ni siquiera está definido: ¿enchufar el cargador?, ¿vaciar
el Gmail?, ¿decir algo? Habría que inventar un medidor de reacción para silenciar avisos que
**ya tienen plazo de días**.
**23.** **Ajustar el volumen de su voz al ruido.** — **NO PROCEDE (verificado 17/09)**
*La mitad útil ya existe:* de **22:00 a 7:00 la voz suena al 55 %** (del 13/09), con una
limitación ya documentada — solo vale para la voz en línea, porque Piper va por `SoundPlayer`,
que no tiene volumen.
*El dato que haría falta no sirve:* `ui-nivel.txt` lo escribe el worker **para la cápsula**; el
asistente solo le pasa la ruta y **nunca lo lee**. Y mide el nivel **mientras hablas**, no el
ruido de la sala cuando Nova va a hablar (ahora mismo marca `0.000`).
*Y `nivel_salida()` tampoco:* mide lo que **sale** por los altavoces, no lo que hay en la
habitación — y de ella cuelgan **cuatro protecciones del oído** cuyo propio comentario avisa de
que tocarla las hace desaparecer «en silencio» y devuelve los fallos del 11/09.
Haría falta un medidor nuevo del micro en reposo para gobernar algo que ya resuelve el
horario.

### Cuándo callarse y cuándo actuar

**24.** **Callarse cuando otra cosa usa el micro.** — **YA ESTABA, y ampliarla la empeoraría**
La idea pedía «añadir más casos (grabando, partida con voz)», pero `Test-EnLlamada` **no va por
casos**: pregunta al registro de Windows
(`CapabilityAccessManager\ConsentStore\microphone`) y detecta **cualquier** aplicación con el
micro abierto — `LastUsedTimeStart` puesto y `LastUsedTimeStop` a cero —, saltándose a la
propia Nova y a los componentes del sistema. Eso ya cubre Discord, OBS, el juego con voz y lo
que se instale mañana, **sin listas que mantener**.
Enumerar casos sería cambiar algo genérico por una lista que se queda corta. Y está bien
rematada: cachea 3 s para no machacar el registro, escribe en el log cuándo se calla **y
cuándo vuelve**, y la usan dos sitios — `Say` (calla y lo enseña en la cápsula con su latido) y
`Test-AvisoSinVoz`.
*En el log no se ha disparado ni una vez, así que tampoco hay evidencia de que falle.*
**25.** Afinar el **modo noche con tus horas reales**. — **NO PROCEDE (medido 17/09)**, y por
tres motivos que se suman.
*El cálculo ya existe:* `Get-HoraFinHabitual` saca tu hora habitual con la **mediana de los
últimos 14 días** y ya exige **4 días como mínimo** para pronunciarse. Se usa para el
recordatorio de cargar, con su media hora de antelación.
*No hay datos:* solo **3 días** registrados, por debajo de ese mínimo, y con una dispersión
enorme — **17:24, 01:00 y 21:59**, o sea **456 minutos** entre el más pronto y el más tarde.
Mover una hora con eso sería el error de las ideas 2 y 8 otra vez.
*Y la idea confundía dos cosas:* `nocheDesde`/`nocheHasta` (23 y 8) **no son «el modo noche»**
que pides hablando: gobiernan el **silencio nocturno de todos los avisos de entorno**.
Moverlos cambiaría cuándo se calla Nova para todo, que es un efecto mucho mayor que el que
buscaba la idea.
*Lo que sí queda:* el día que haya 4+ días de datos coherentes, `Get-HoraFinHabitual` ya está
construida y solo hay que decidir **qué** mover.
**26.** **Callarse en la franja en que siempre la mandas callar.** — **NO PROCEDE
(medido 17/09)**
*No hay ninguna franja «de siempre»:* le has mandado callar **12 veces**, repartidas en **seis
franjas distintas** (10, 14, 15, 16, 17 y 22 h), con un máximo de **4** en una sola (16 h) y
varias de una única vez. Con el freno de la idea 2 —3 días distintos y ningún día por encima
del 70 %— **no pasaría ninguna**.
*Y ya se calla sola, pero por el motivo correcto:* la **autosordina** se disparó **5 veces**
(3 descartes seguidos → 10 minutos de silencio, avisando). Reacciona al **ruido real**, no al
reloj, que es mejor: si esta tarde no hay ruido, no se calla por costumbre.
*Nota de método:* la primera medición dio «470 veces» y era falsa — el patrón se tragaba
`ENVIAR (silencio)`, una marca interna del envío de órdenes. Rehecha con patrones precisos
quedaron 12.
**27.** Decidir entre **palabra o botón según lo que funciona**. — **NO PROCEDE: el ajuste
impide medirlo (17/09)**
Medido con las marcas reales del log (`solo boton mientras juegas` / `vuelve la palabra de
activacion`): **293 activaciones y 56 descartes, todos con la palabra activa; cero jugando**.
Es lo coherente — `soloBotonEnJuego` está en `true`, así que con un juego delante la palabra
se apaga y **no puede fallar ni acertar**. Solo hay **3 tramos de juego** en todo el log.
O sea: **el dato que la decisión necesitaría no existe, y no existe porque el propio ajuste lo
impide**. Para decidirlo habría que desactivarlo un tiempo y arriesgarse a activaciones
equivocadas en mitad de una partida, que es justo lo que ese ajuste evita y lo que más
molesta.
*Nota de método, la segunda seguida:* mi primera medición daba «254 activaciones jugando», y
era un artefacto — marcaba «jugando» al ver «juego en primer plano» y no lo apagaba nunca. Con
las marcas correctas, cero. Van dos veces (idea 26 y esta) que un número grande a la primera
resulta ser del medidor, no del sistema.

### Gastar con cabeza

**28.** Decidir **cuándo merece la pena la IA cara**. — **NO PROCEDE (verificado 17/09)**
*La jerarquía ya está decidida, y la elegiste tú:* «API PRIMERO (15/09, elegido por braya:
capa local y API para las conversaciones)». Y lleva una **regla de coste real**: con la API
activa **no se carga el modelo local**, porque «gastaría 1-2 GB de RAM que la escucha
necesita».
*Y ya degrada sola:* `$script:apiFallo` apaga la API hasta el próximo arranque cuando el error
no se arregla reintentando, y entonces contesta el modelo local.
*Lo que la idea pide no es calculable:* **no se registra qué motor atendió cada cosa** (no hay
ninguna estadística de api/local/agente) ni hay **tiempos por camino** — el único «tras N s»
del log es uno, de 240 s. Sin acierto ni coste por motor, «cuándo merece la pena la cara» no
tiene números con los que decidirse.
*El reparto real, para tenerlo escrito:* **201 órdenes en local** frente a **165 a un modelo**
(charla 86, acción 69, pregunta 10); de las de charla, **87 por API y 47 por el local**.
**29.** **Copia de seguridad cuando toca.** — **YA ESTABA, y mejor que la idea** — *pero deja
una sospecha*
`New-CopiaSeguridad` empaqueta traducciones, reglas, `commands.json`, `config.json`, toda
`memoria/` y `mi-voz.json` en un zip con rotación, y **se dispara sola por dos vías**: en el
**primer minuto tras arrancar** y al **cambiar de día**, con `Test-CopiaPendiente` (20 h desde
la última).
*Y la condición que pedía la idea sería peor:* «cuando lleves un rato sin hablarle» falla justo
cuando Nova se enciende y se apaga a ratos. El disparo al arrancar cubre eso, y el comentario
del 12/09 lo documenta: sin él «la copia no se hacía nunca», porque `diaVisto` nace con la
fecha de hoy y el bloque de cambio de día no se alcanzaba.
**⚠ Lo que sí hay que mirar:** no existe la carpeta `copias/`, **no hay ni un zip** y **ni una
línea** en el log. Con `CopiasDir` inexistente, `Test-CopiaPendiente` devuelve `$true`, así que
la copia **debería** haberse hecho en el primer minuto. O falla en silencio (el `try/catch` se
traga el error) o el bucle no llega ahí. **Comprobar la próxima vez que Nova se encienda**, y
si falla, que el `catch` lo diga en vez de callar.
**30.** Ampliar el **parte semanal** con lo que decidió sola. — **HECHA (17/09)**
El parte ya existía y estaba bien escrito —días hablados, cuántas órdenes, cuántas resolvió al
instante, tropiezos, lo que no entendió y hasta los gestos— pero **hablaba solo de ti**. Desde
esta tanda Nova toma decisiones propias, y eso solo vivía en el log.
Ahora, si esa semana decidió algo, el parte lo cuenta **con el número que la justificó**:
> *«Esta semana decidí una cosa por mi cuenta: último recurso off: 1 de 29. Me pediste deshacer
> una de ellas, así que ahí me equivoqué.»*
Incluye lo que **deshiciste** (o sea, dónde se equivocó) y las veces que **arrancó a medias**.
Se cumple sola la regla de la lista —«si no puede explicar una decisión con un número, no
debería haberla tomado»— porque el detalle que guarda ya trae el número.
*Y si esa semana no decidió nada, no escribe ni una línea:* un parte que dice «no hice nada
especial» cansa más de lo que informa. Ése es el primer caso de la prueba.
*17 casos en `probar-parte-semanal.ps1` (2n22), incluidos los dos del filtro de fechas: lo de
la semana anterior y la siguiente no cuenta, y los dos días del borde sí.*

---

## 30 más

### Que EJECUTE lo que ya escribe

**31. Retirar el filtro de recitados cuando sobre.** — **NO PROCEDE (medido 17/09)**
*La condición que ella misma escribió no se cumple:* «si baja a cero **durante semanas**». Lo
que hay es **0, 4, 0, 6, 3, 0** en seis días — **13 recitados**, el último hace dos días. El
filtro sigue trabajando.
*Y no es un filtro, son dos, y ninguno sobra:*
- `Test-CatalogoRecitado`, descrita en el propio código como **«la defensa principal contra
  abrir cosas solo»** — o sea, contra lo que más te molesta;
- `Test-RecitaEjemplo`, que caza los ecos de la frase de ejemplo de Whisper. Con casos reales
  guardados: *«¿Qué hora es? ¿Qué hora es»*, dos veces el 16/09.
**⚠ Y la regla, tal como está escrita, es peligrosa:** el `0` del 17/09 es de un día con **0
activaciones y 0 ruido**, o sea **sin uso**. Un contador a cero puede significar «ya no hace
falta» o «ese día no se usó», y hoy **no se distinguen**. Aplicarla tal cual retiraría la
guarda tras unas vacaciones. Si algún día se hace, tendrá que exigir **días con uso real**, no
días de calendario — la misma lección de las ideas 2 y 8.

**32. Reaccionar cuando el micro empieza a cazar audio.** — **HECHA, PERO AL REVÉS (18/09)**
*La premisa era falsa y la medición la tumbó.* La frase decía: «si `recitado` sube, el
micrófono está cazando audio». Medido sobre los 13 recitados del log, mirando el pico de audio
de la activación que produjo cada uno:

| | n | pico mediano | máximo |
|---|---:|---:|---:|
| recitado — eco del ejemplo | 7 | **0.000** | 0.268 |
| recitado — catálogo | 6 | 0.078 | 0.364 |
| *ruido de verdad* | 41 | 0.077 | **0.995** |

El recitado llega con el micro **casi mudo**, no cazando audio. Y la causa está identificada:
`PROMPT_ORDENES` (`wake_vosk.py:120`) se pasa como `initial_prompt` a Whisper, así que cuando
no hay audio que transcribir **Whisper devuelve su propio prompt** — de ahí el famoso «¿Qué
hora es? ¿Qué hora es». Bajar la ganancia, que es justo lo que pedía la idea, **la habría
dejado más sorda precisamente cuando no oye**.

**Y la otra reacción «obvia» era peor todavía:** sumar el recitado a la racha de la autosordina
habría callado a Nova el 16/09 a las 11:47:27 — con braya hablándole (activación legítima «nova
por», confianza 0.95, pico 0.268, y un dictado de seguimiento tres segundos después). Es el
mismo fallo del 15/09 que `Add-RuidoRacha` ya documenta: «NO ES RUIDO SI ERES TU».

**Lo que sí se hizo:** corregir la leyenda que ella misma escribe en `estadisticas.md`. Era la
que guiaba mal —me guio mal a mí mientras trabajaba esta idea— y es la que ella leería para
decidir sola. Ahora dice lo medido, nombra las dos formas del recitado, y avisa de que un cero
puede ser un día sin uso. `probar-recitado.ps1` lo comprueba y deja en rojo a quien intente
sumar el recitado a la sordina.

**33. Generalizar el autoapagado del acelerómetro.** — **HECHA, Y DESTAPÓ UN SEGUNDO PERDIDO (18/09)**
*Generalizarlo a «todos los vigilantes» no tenía caso:* de las 10 funciones `Watch-*`, varias
reciben los datos por parámetro (`Watch-Notificaciones`, `Watch-Musica`, `Watch-Portapapeles`)
— son manejadores, no sondas, y un manejador no puede «no responder». Las demás ya degradan
con `try/catch`, y **el log no registra ni un fallo** de ninguna.

*Pero al medir el coste apareció lo que nadie había mirado:*

| sonda | cadencia | coste medido |
|---|---|---:|
| **`Win32_Processor`** (carga de CPU) | **cada 30 s** | **1057–1320 ms** |
| `WmiMonitorBrightness` (con el juego) | con el juego | 12–15 ms |
| `Win32_Battery` | cada 60 s | 22–30 ms |

`Get-CimInstance Win32_Processor` tardaba **más de un segundo**, cinco medidas de cinco y en
caliente, **síncrono dentro del bucle**, solo para mover la insignia de carga de la cápsula:
Nova congelada un segundo de cada treinta **por un adorno**.

**Alternativas medidas:** `Win32_PerfFormattedData_PerfOS_Processor` 288–295 ms; el
**contador de rendimiento de .NET, 0–10 ms** — unas 100 veces menos, y más reactivo.

**Lo que se hizo,** que es el criterio del acelerómetro generalizado *donde sí hay coste*:
`Get-CargaCPU` usa el contador; si no existe, cae a CIM **cronometrado**; y si el respaldo pasa
de `cargaTopeMs` (400 ms) **se apaga para siempre** y lo apunta con su número, porque una
insignia cosmética no vale un bloqueo. El acelerómetro usa 150 ms porque corre cada 250 ms;
aquí la cadencia es 30 s, así que el tope es más generoso. `probar-carga-cpu.ps1` (2n23) cubre
los siete caminos, incluido que tras apagarse **no vuelve a llamar** a la sonda cara.

### Afinar sus propios números, que hoy son fijos en `config.json`

**34. `autoSordinaRachas` (3), `autoSordinaVentanaMin` (5) y `autoSordinaMinutos` (10).** — **NO PROCEDE (18/09)**
*Los números puestos a ojo resultaron ser los correctos.* Simulado con los **83 eventos reales
que suman racha** (son **cuatro** caminos, no dos: `NO era una orden` 41, `RUIDO descartado` 35,
`OIDO FINO descartado` 5, `NO era una pregunta` 2):

| | vent=2 | vent=3 | **vent=5** | vent=8 | vent=10 |
|---|---:|---:|---:|---:|---:|
| rachas=2 | 22 | 24 | **26** | 29 | 31 |
| **rachas=3 (hoy)** | 2 | 5 | **11** | 15 | 17 |
| rachas=4 | 0 | 0 | **0** | 3 | 5 |

Bajar a 2 la dispararía **26 veces**; subir a 4 la **apaga del todo**. El 3 es el único valor
que ni la desboca ni la desactiva, así que **no hay dónde moverlo**. (Las reales fueron 5 y no
11 porque las guardas de origen ya frenan la mitad.)

*Y aunque lo hubiera:* las 5 sordinas se reparten **1 el 12/09 y 4 el 15/09 — el 80 % en un
solo día**, así que el freno de «datos repartidos» (≥3 días, ≤70 % en uno) que pusimos en esta
misma tanda **le prohíbe a Nova decidirlo sola**. Funciona como debe.

**⚠ LO QUE APARECIÓ DE CAMINO, y también se cae al medirlo:** 2 de las 5 sordinas se
dispararon con frases que son de braya — la de las 14:10 por *«Reproduce una canción»* y
*«Vamos a ver el volumen»*, y la de las 14:48 por *«No, o sea, que me lo busques…»*, justo la
única tras la cual intentó hablarle. Y el log enseña que **no falló el oído**: Parakeet, Whisper
y turbo transcribieron *«Reproduce una canción»* palabra por palabra. Falló el **catálogo**, el
traductor contestó «no es una orden»… y eso se contabiliza como **ruido del micrófono** y ayuda
a callarla 10 minutos. Son dos cosas distintas mezcladas: **«no te oí» ≠ «no sé hacer eso»**.

*Pero medido sobre los 41 «NO era una orden», es 1 caso, no muchos:*

| señal | casos |
|---|---:|
| transcripción consistente entre motores | 2 de 41 |
| «español claro» de 4+ palabras | 30 de 41 |
| **las dos a la vez** | **1 de 41** |

Y de paso se cae el indicador fácil: **«español claro» no sirve** aquí, porque deja pasar basura
bien formada (*«CLAVARAL LUCTS, SODE MOTORMICISIN»*, *«Ocapainteres en el Nuevo Elad»*). La
señal que sí distingue es **que varios motores coincidan**, y ya existe (`$script:siguioParakeet`
y la línea `PARAKEET -> WHISPER`) — pero con 1 o 2 casos no hay con qué justificar tocar la
autosordina.

**Y la solución «obvia» queda prohibida, por si alguien la retoma:** `Test-VozExtrana` devuelve
`$false` («no es extraña») cuando `SoloYo` está apagado, el origen es seguimiento, el tono no se
midió (`f0 ≤ 0`) o no hay voz del dueño aprendida — o sea que **«no extraña» casi siempre
significa «no lo sé»**. En todo el log hay **2** `VOZ EXTRANA` frente a **83** eventos de ruido:
usarla como guarda en `Add-RuidoRacha` dejaría la autosordina en **0 disparos, sin avisar**.

**35. `holdMs` (1100).** — **MEDIDOR INSTALADO; NO SE PUEDE DECIDIR TODAVÍA (18/09)**
*La idea estaba mal enunciada:* `holdMs` no es «cuánto tardas en soltar», es el tiempo que hay
que **mantener** ≡ para que empiece a dictar.

*Y no se podía ajustar porque no había ni un dato:* la duración de la pulsación **no se medía
en ningún sitio**. El log solo repite el valor configurado («mantener ≡ 1.1 s»), y la línea
«soltado» que parecía servir resultó ser de *«último recurso soltado»*, del oído fino — nada
que ver. El botón sí se usa (**102** `DICTADO (mantener` y **30** `(largo` en siete días), así
que la pregunta es legítima; lo que faltaba era la medida.

*Lo único que delata un umbral alto es **soltar sin que llegue a disparar**,* y el código ya
detectaba ese caso exacto (`-not $startNow -and $startPrev -and -not $holdFired`) sin medir
nada. Ahora `Add-ToqueCorto` apunta los milisegundos ahí, descartando los toques de menos de
120 ms (el doble toque abre el panel rápido: no es un intento de dictar) y lo que ya disparó.
Se apunta **sin detalle** a propósito, para no ensuciar «Últimas órdenes» con algo que no es una
orden — y `Write-DestinoUso` filtra por `$DestinosUso`, así que una clave nueva no toca
`destinos.jsonl`. `probar-toque-corto.ps1` (2n24) lo cubre.

**Cuándo se podrá decidir:** cuando haya toques cortos repartidos en ≥3 días. Si se amontonan
cerca de los 1100 ms, el umbral está alto; si casi no aparecen, el número era bueno y la idea
se cierra sola.

**36. `autoSubmitMs` (2500).** — **NO PROCEDE: el número no está en el camino que usa (18/09)**
*Ese 2500 es letra muerta.* Solo actúa bajo `-not $script:ordenPorWorker`, y el propio código lo
dice: «ENVÍO AUTOMÁTICO (**solo para el dictado antiguo de Windows**). Con Vosk el propio worker
detecta el silencio y entrega el texto». Con `config.json` en `"motorOrdenes": "worker"`, esa
condición es falsa siempre. Comprobado por cinco lados:

- `$script:ordenPorWorker` pasa a `$false` en **un único sitio**: una **orden escrita** (texto,
  sin audio), que va directa a `Process-Texto` — ahí no hay silencio que temporizar;
- en el log: **0** auto-envíos por silencio;
- `vozwin` y `vozwin-mudo` están **vacías todos los días** en la tabla.

*Y lo que la idea pedía **ya está hecho**, en el número que sí manda.* Quien corta la frase en
el uso real es `SILENCIO_FIN` (1,5 s) y `SILENCIO_FIN_LOTENGO` (1,1 s) de `wake_vosk.py`, y
`PENDIENTE.md` documenta que se calcularon justo así: «dentro de una orden llegaste a **0,81 s**
(con 20 parecía 0,45) y con pausas a propósito a **1,44 s**. El cierre rápido pasa de 0,8 a
**1,1 s** y el normal de 1,4 a **1,5 s**».

**⚠ Y de paso queda descartada una «mejora» que parecía obvia:** bajar `SILENCIO_FIN` para ganar
tres décimas por orden. Esos valores se **subieron** a propósito, medidos sobre 90-110
grabaciones, porque las pausas a propósito llegan a 1,44 s. Bajarlos cortaría órdenes por la
mitad — y cortar una orden sale mucho más caro que esperar 0,3 s.

**37. `soloYoMargenHz` (35) y `soloYoMinimo` (12).** — **NO PROCEDE: no existe un valor que sirva (18/09)**
*Primero, la idea cita el valor por defecto del código:* `config.json` ya tiene **42**, subido
con dato en su día («gritando *basta* llegaste a 37 Hz de tu tono normal; el margen pasa de 40 a
**42 Hz**»).

*Y estrecharlo es imposible, no difícil.* Lo que hay aprendido de verdad:

| | tono | muestras | distancia a la tuya |
|---|---:|---:|---:|
| **tú** (`voces.json`) | 115,4 Hz | **225** | — |
| otra voz | 144,0 Hz | 42 | **28,6 Hz** |
| otra | 172,6 Hz | 20 | 57,2 Hz |
| otra | 233,2 Hz | 23 | 117,8 Hz |

La segunda voz más oída está a **28,6 Hz**, o sea **ya dentro** del margen de 42: hoy se
confunde contigo. Para separarla el margen tendría que ser **menor que 28,6**… pero para no
rechazarte a ti cuando alzas la voz tiene que ser **mayor o igual que 37**. **37 > 28,6: las dos
condiciones no se pueden cumplir a la vez.** Estrecharlo —lo que pedía la idea— te dejaría
fuera a ti gritando, que es justo cuando más falta hace que obedezca.

*Y `soloYoMinimo` (12) tampoco tiene recorrido:* hay **225** muestras de tu voz y 60 en
`mi-voz.json` (el tope). Ya está superado de sobra por los dos lados.

**Lo que esto enseña de verdad:** el tono **no puede ser** la única defensa de «solo yo», y el
diseño actual ya lo asume — `Test-VozExtrana` solo se consulta en los puntos críticos (crear
reglas, órdenes peligrosas), no en cada frase. La separación real tendría que venir de algo más
que un número de hercios (huella de voz), y eso es otro proyecto, no un ajuste.

**38. `avisos.bateriaPct` (15).** — **MEDIDOR INSTALADO; NO SE PUEDE DECIDIR TODAVÍA (18/09)**
*El dato que la idea necesita no existía.* Para saber si el 15 % es el bueno hay que saber a qué
porcentaje enchufas de verdad… y eso **no se apuntaba en ninguna parte**: el log decía
«cargador: enchufado» y nada más.

*Lo que hay medido, y es casi nada:*

| | |
|---|---:|
| avisos de batería realmente disparados (`AVISO: bateria al`) | **1** |
| veces que se enchufó el cargador | **2** (en 2 días) |
| nivel de batería visto | casi siempre **100 %** |

Dos enchufados en dos días **no pasan el freno de datos repartidos** (≥3 días), y la consola
vive enchufada, así que el aviso del 15 % prácticamente no llega a saltar. **Por eso el 15 no se
toca:** solo se empieza a apuntar.

`Add-CargaConectada` registra el nivel **en el flanco de enchufar** (no al quitarlo, que no dice
nada, y no cada minuto), descartando lecturas imposibles. Se guarda **sin detalle**, como el
toque corto, para no ensuciar «Últimas órdenes» con algo que no es una orden.
`probar-cargador.ps1` (2n25) lo cubre.

**⚠ Y de camino, una cifra mía que era falsa:** conté «84 avisos de batería» y resultó que
**71 eran una sola regla tuya guardada** («cuando la batería baje del 15 por ciento…») repetida
en el log, más preguntas tuyas del tipo «cuánta batería queda». Es la tercera vez en esta tanda
que un número grande a la primera resulta ser del medidor y no del mundo; la marca exacta del
código (`AVISO: bateria al`) da **1**.

**Cuándo se podrá decidir:** cuando haya enchufados repartidos en ≥3 días. Si resulta que
enchufas siempre al 40-50 %, avisar al 15 llega tarde; si enchufas al 100 por costumbre, el
número da igual y la idea se cierra sola.

**39. `entorno.nocheDesde` / `nocheHasta`.** — **NO PROCEDE: un número, dos usos opuestos (18/09)**
*Las horas medidas sí dicen algo,* con 1407 eventos de uso repartidos en 7 días:

```
11h 103   14h 109   15h 288   17h 143   19h 132   21h  65
22h  28   23h   9   00h  20   01h  59   02h-08h  0   09h  34
```

Usas la consola **hasta la 1-2 de la madrugada** (a la 01 h hay más actividad que a las 23 h) y
de 02 a 08 no hay nada. Con `nocheDesde=23`, la franja de «solo lo crítico» te pilla despierto
durante **88 eventos** — repartidos, además, en 6 días, así que el freno de datos no lo impide.

*Pero moverlo no arregla nada y sí rompe algo.* Dos razones:

1. **El camino casi no se recorre:** en todo el registro hay **5 avisos de entorno** (3
   `gmail-lleno`, 2 `bateria-llena`), todos entre las 19 y las 21 h y **ninguno de noche**. La
   franja no ha silenciado nada todavía — y encima ya hay una guarda anterior más fuerte: con un
   juego abierto, los avisos que no son críticos callan igual.
2. **El número lo comparten dos usos con exigencias contrarias:** para silenciar avisos querría
   empezar más tarde (a las 2), pero `Get-AvisoHoraDormir` lo usa como umbral del aviso «son las
   23:40 y a esta hora no sueles estar levantado», que necesita empezar **a las 23**. Subirlo a 2
   dejaría ese aviso sin poder dispararse justo en su franja útil, y **rompería la idea 18**, que
   ya se autoajusta bien con los hábitos (≥3 días de los últimos 14).

**Si algún día hay que tocarlo, primero hay que separarlo en dos números** — «desde cuándo callo
los avisos» y «desde cuándo es tarde para ti» — porque hoy son el mismo y tiran en direcciones
opuestas.

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

## Y al terminar esta lista: `NOVA-LLM.md`

braya, mientras se trabajaba en esto: «¿podemos hacer que Nova sea todo esto, o sea **ser un
verdadero LLM sin serlo**?». Está escrito aparte, en **`NOVA-LLM.md`**, porque es un proyecto
distinto y no una entrada más de esta lista.
En corto: de las **seis piezas** que hacen útil a un asistente, **solo una necesita un LLM de
verdad**. Nova ya tiene tres y media. La que más falta —y la que **no necesita modelo
ninguno**— es el **bucle de verificación**: hacer, comprobar el resultado y corregirse.
**Se empieza al acabar esta lista, y entonces solo se trabaja en eso.**

---

## Cómo se elige la siguiente

1. ¿Hay **dato propio** que la justifique? Si no, primero se mide.
2. ¿Se puede **deshacer hablando**? Si no, no se implementa.
3. ¿Qué pasa si se equivoca? Si la respuesta es «se queda callada» o «se queda un modo
   puesto sin saberlo», va con aviso obligatorio o no va.
4. ¿**Ya existe a medias**? Antes de escribir nada, mirar: el parte semanal, las horas
   habituales y el autoapagado del acelerómetro ya estaban, y tres ideas de las primeras
   tandas hubo que corregirlas por eso.
