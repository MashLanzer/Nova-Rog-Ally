# Diez FUNCIONES NUEVAS para Nova (23/09/2026, quinta tanda)

Cosas que Nova hoy **no sabe hacer**, no mejoras de lo que ya hace. La tanda salio de un
reproche de braya, y tenia razon: *"como me vas a decir que no hay contenido, literalmente el
limite es la imaginacion"*.

**El problema era el criterio, no el material.** Las tres tandas anteriores pedian PULIR -que
es lo que braya tiene guardado como preferencia desde el 14/09- y por eso los escepticos
tumbaban por sistema todo lo que fuera una funcion nueva. Cambiando el encargo y dejando solo
las tres reglas de seguridad -que quepa en esta consola, que no pueda ejecutar algo que no
pidio, y que si es un modo se sepa salir-, de 32 propuestas **sobrevivieron 21**. En la tanda
anterior sobrevivieron 6 de 25.

Ocho angulos: lo que podria hacer mientras juega, que no juega solo, lo que repite cada dia,
la memoria que guarda y no usa, la consola como ordenador, lo que puede enseñarle, la capsula
y la voz, y lo que ninguna asistente hace.

---

# Diez funciones nuevas para Nova

Ordenadas por lo que le cambian el día a día. Cada una lleva ya aplicadas las correcciones de las dos revisiones: lo que hay que cambiar del plan original va dicho dentro, no aparte. Y todas las frases de ejemplo van conjugadas, con la cosa dentro del verbo, como pidió braya.

---

## 1. Mirar la pantalla de verdad cuando él se lo pide, en vez de contestar a ciegas

**Para qué.** Es lo que más le ha costado en todo el log. De los 303 turnos reales de `pruebas\audio\uso\destinos.jsonl`, 40 hablan de la pantalla. Diez cogieron la ruta buena —la de captura adjunta— y contestaron bien. Ocho cayeron en la charla, que es ciega: en `charla_worker.py` la palabra "pantalla" no aparece ni una vez. De ahí sale la peor noche del log entero, el 20/09 entre las 23:04 y las 00:00: *"míralo tú mismo en la pantalla y dime qué ves"*, *"me dijiste cualquier cosa menos lo que viste en la pantalla"*, *"deja de decir que no ves nada en mi pantalla, literalmente tienes un OCR con el que puedes ver mi pantalla"*, *"estás alucinando"*. Tres de esas frases sí se tradujeron, pero a "lee la pantalla", que es OCR, y en un juego el OCR devuelve lo que devolvió el 22/09 a las 21:44: "No veo texto en la pantalla".

**Con qué se hace.** 0 MB, cero API nueva: `Save-Captura` + `Submit-Command` con la captura como tercer argumento ya funciona y ya deja en el log "VER PANTALLA: captura adjunta". Se hace en dos fases, y la fase 1 resuelve sus ocho frases sola:

- **Fase 1, en `assistant.ps1` y sin tocar la charla.** Ampliar el regex de la línea 19392 con las formas que él dice de verdad, sacadas de sus frases y no inventadas: `mira\s+(?:a\s+ver\s+)?(?:en\s+)?(?:mi|la|esta)?\s*pantalla`, el infinitivo `mirar`, `miralo\s+tu\s+mismo`, `puedes\s+(?:mirar|ver)\s+(?:mi|la)\s+pantalla`, `dime\s+que\s+ves` y `ves\s+(?:nada\s+)?en\s+mi\s+pantalla`. Se **tira el gate del juego**: no habría disparado en ninguno de los ocho casos, y tres de los diez aciertos fueron fuera de un juego. Lo que decide es la frase, que es lo único que él controla.
- **No se toca la guarda de verbos** (`abre|inicia|cierra|pon|ponme`…) del `-notmatch`: es lo que impide que "abre el juego que tengo en pantalla" acabe descrito en vez de ejecutado. Comprobado: ninguna de las ocho frases lleva un verbo de esa lista, así que ensanchar lo que mira no obliga a aflojar lo que frena.
- **Dos enganches que convierten fallos fechados en aciertos.** Que el rebote de `reescribir_orden` deje de aterrizar en "lee la pantalla" cuando la frase pide *ver* y no *leer*; y que cuando `interpretar` pide contar lo que se ve y el OCR vuelve vacío (`assistant.ps1:11956`), en vez de "No veo texto en la pantalla" se mande la imagen. Es una línea.
- **Fase 2, solo si hace falta la memoria de la charla.** La imagen entra **por** la charla, no rodeándola: `Send-Charla` ya acepta un `$extra` (16792-16793) donde cabe `imagen=<ruta>`, y en `charla_worker.py` el `content` pasa a lista. Con tres candados obligatorios: quitar la imagen del historial en cuanto conteste (`MAX_HISTORIAL` son 12, o sea que se reenviaría seis turnos y multiplicaría el coste por seis); que el blob no llegue nunca a `aprender_turno` ni a los vectores; y que el intento local vaya **sin** imagen y con una coletilla, porque qwen2.5:3b no ve y se inventaría la pantalla.

**Dónde se engancha.** `assistant.ps1` 19388-19392 (regex y guarda) y 11956 (OCR vacío); `charla_worker.py`, el destino de `reescribir_orden`.

**Cómo se sale.** No es un modo. Va turno a turno: si la frase no nombra ver ni pantalla, no hay captura y todo funciona como hoy. No queda nada puesto.

**Riesgo de orden equivocada: bajo**, no "ninguno". El único camino por el que podría hacer algo que él no pidió es que "lee la pantalla" se cuele como paso añadido de un plan cuando la frase original no menciona ni ver ni pantalla —el caso exacto del 22/09 a las 01:13:08—. Con ese candado puesto, baja a bajo de verdad. Y nadie contesta a ciegas: si la captura sale casi toda negra (`CopyFromScreen` devuelve negro en pantalla completa exclusiva) o la API falla, se dice y se acaba.

**Lo que dirá, conjugado.** *"La he mirado: te sale el cartel de sujetar la palanca."* · *"No he podido mirarla, me ha salido en negro."* · *"No he mirado nada, eso no me lo has pedido."*

---

## 2. Dejar de decir las palabras que él no aguanta, y no aprenderlas del revés

**Para qué.** Se lo ha pedido tres veces y sigue pasando. El 21/09 a las 00:03: *"deja de decir tío, no me gusta esa palabra, te lo digo ahorita, guárdalo en memoria"*. Otra: *"deja de llamarme tío al final, tú no eres española ni nada de eso"*. Y una tercera: *"también deja de decirme Man, no me digas así"*. Lo peor no es que siga diciéndolo: es lo que aprendió de la queja. En `memoria\perfil.md` está ahora *"braya habla con acento español (usa 'tío')"* —el dato guardado del revés, la muletilla es de ella— y esa línea realimenta el prompt de la charla, que la vuelve a usar. Hay cuatro entradas de estilo contra 'tío' y una contra 'man' peleándose con esa línea del perfil.

**Con qué se hace.** Un `memoria\palabras-no.json` de unas líneas. Cero instalación.

- **El filtro va DENTRO de `Get-TextoVoz`, no en `Say`.** Esto no es un matiz: la charla pre-sintetiza (`Send-PrepVoz (Get-TextoVoz …)`, 16930) y el md5 de `Get-RutaVozCache` tiene que cuadrar con lo que suena. Filtrando en `Say` se pierde la voz ya preparada y cada frase tocada se le va ~1 s. Dentro de `Get-TextoVoz`, antes del recorte a 1.200 letras, los tres caminos comparten texto y la cápsula enseña lo mismo que se oye.
- **Palabra entera y sin tildes**, comparando con `ConvertTo-Plain` y con `\b`: "man" a secas se come mando, manda, semana, humano, comando —y Nova le lee los cuatro mandos—; "tío" con tilde no caza el "tio" que escupe el modelo la mitad de las veces. Y se quita la coma del vocativo: *"No te sigo, tío."* → *"No te sigo."*, no *"No te sigo, ."*.
- **Solo lo que Nova redacta, nunca lo que lee.** Correo, OCR, nombres de juegos, canciones, lo que le repite dictado: intactos. Censurar un correo que dice "man" no es obedecerle, es mentirle sobre lo que pone en la pantalla.
- **Qué puede entrar**: tope de 5 palabras, una por entrada, rechazo de las funcionales, y si Nova no ha dicho esa palabra nunca en el log, no entra. Con el oído al 70,4 %, un "no digas X" mal entendido podría vetar "que" o "no" y dejarla muda a medias.
- **Que se llene solo también**, porque el comando exacto se va a perder (la petición del 20/09 se transcribió "Deja de decidido"): `citadas()` en `charla_memoria.py` ya saca la palabra entrecomillada de una entrada de estilo negativa, y esas se guardan solas cuando él se queja.
- **Al prompt, por el `extra`, jamás dentro de `SISTEMA`** (charla_worker.py:88): ese prefijo fijo es el que precarga Ollama, y cambiarlo tira la precarga —la primera frase se va de 2,2 s a 13,9 s—.

**Dónde se engancha.** `Get-TextoVoz`; el regex nuevo **delante** del de "no digas nada" (4576) y excluyendo "nada", "nada más" y "ni una palabra", porque si va detrás no se llega nunca y si va delante sin excluir, "no digas nada" vetaría la palabra "nada" en vez de callarla; `charla_worker.py` (extra); y la limpieza: borrar esa línea de `perfil.md` y las de estilo que la nombren, y que `Add-DatoPerfil` (6996) rechace de entrada cualquier dato que contenga una palabra vetada, o volverá a colarse por otra redacción como ya hizo el 22/09.

**Cómo se sale.** No es modo: es una lista que se ve y se deshace.

**Riesgo de orden equivocada: bajo.** Lo peor que puede pasar es una palabra vetada de más, y se quita con una frase.

**Lo que dirá, conjugado.** *"Vale, no te lo digo más."* · *"Te lo he quitado: ya no digo 'tío'."* · *"Te la he devuelto, vuelvo a decir 'tío'."* · *"No te digo cuatro palabras: tío, man, colega y chaval."*

---

## 3. Guardar una colocación de ventanas con su nombre y volver a montarla entera

*(Aquí se juntan las dos ideas que eran la misma: "montajes con nombre" y "guárdame este escritorio".)*

**Para qué.** Es lo que más ha pedido y lo único que nunca ha conseguido. El propio código lo tiene contado en `assistant.ps1:499`: *"En catorce días la pantalla dividida no se ejecutó bien ni una sola vez por voz: cero de once intentos"*. Y no es un capricho suelto, es una rutina: YouTube en una mitad y Pinterest en la otra, ocho momentos distintos en `destinos.jsonl` (18/09 de 19:03 a 20:04, 20/09 a las 18:55, 22/09 a las 01:10) más dos intentos del 10/09 en `assistant.log` —ocho, no nueve; el 18:56 del 20/09 no existe, son tres líneas del mismo intento—. El 18/09 a las 20:04 se quejó por voz: *"Solo abriste Pinterest, nunca abriste YouTube ni dividiste la pantalla a la mitad"*. El perfil dice para qué le sirve: *"braya quiere recrear una foto con su pareja"* —las referencias en Pinterest y el tutorial en YouTube— y *"quiere dejar un zoom configurado"*. Hoy hay cinco patrones de regex peleándose por adivinar cómo lo dice; con un nombre no hay nada que adivinar.

**Con qué se hace.** Cero instalación, y con un cambio de enfoque que es lo que la salva.

- **El montaje NO se saca de mirar la pantalla: se guarda de los destinos ya resueltos.** O de un "dividir" que Nova acaba de ejecutar bien —la línea 4873 ya tiene `izq` y `der` como objetos de `Resolve-Target`, con su url—, o dictado de una vez: "guarda pinterest con youtube como el tablero", que los dos están en `commands.json`. Así guarda *"https://www.pinterest.com a la izquierda"*, no *"dos Edge"*, y no le hace falta saber leer la barra del navegador.
- **Al montar, reusar en vez de duplicar.** "Dividir" siempre hace `Start-Process`: si el navegador ya estaba abierto, te abre otro. Por cada entrada, primero el camino de 'enfocar' (11935-11938: `Get-Process`, `ShowWindow(9)`, `ForceForeground`) y solo si no está abierta, `Start-Process`.
- **Esperar y colocar con lo que ya está probado.** El bucle de espera de ventana ya existe dentro de 'dividir' (11560-11569: `GetForegroundWindow` cada 200 ms hasta 4 s); se extrae a un ayudante. Para colocar, `[AX]::SetWindowPos` con `SWP_NOACTIVATE` (11927) mejor que Win+flecha, porque no roba el foco. Y clamp contra `WorkingArea` (11924-11926) por si el escritorio se guardó dockeado en la tele y se monta en la Ally.
- `memoria\montajes.json` con `Write-Atomico` (643) y **al .gitignore**, donde ya está `memoria/juegos.json`: el repo es público y ese fichero dice qué usa y cómo lo coloca.

**Dónde se engancha.** Canónicos nuevos ('guardarMontaje' y 'montar') junto a los de pantalla dividida (4869-4883); ejecución al lado del bloque 'dividir' (11554); interruptor `ventanas.montajes` en `config.json`, como `juego.ajedrez`.

**Cómo se sale.** No es un modo: monta y termina. Nunca cierra nada, solo abre y coloca. Si hay un juego delante, esa ventana no se toca.

**Riesgo de orden equivocada: bajo.** Al **montar**, el nombre es lista cerrada: elige entre los guardados con el umbral de `Find-JuegoPorSonido`, y si ninguno destaca dice los que tiene y no abre nada; nunca monta "el parecido". Al **guardar**, el nombre es libre —ahí la lista cerrada no protege, porque se lo está inventando en ese momento—, así que lo repite en alto y "bórralo" lo deshace: escribir un json con un nombre mal oído no rompe nada, montarlo sin querer sí.

**Lo que dirá, conjugado** (y sin anunciar antes: monta y luego cuenta). *"Te lo he guardado como el tablero: Pinterest a la izquierda y YouTube a la derecha."* · *"Te he montado el tablero."* · *"Te lo he montado a medias: YouTube no me ha llegado a colocar."* · *"Tengo dos: el tablero y el de trabajo."*

---

## 4. Buscar en su memoria por significado, y borrar de viva voz lo que acaba de decir

*(Aquí se juntan "buscar por significado" y "el del oso polar, elimínalo": comparten el mismo enganche y la segunda necesita a la primera para saber a qué se refiere.)*

**Para qué.** La rama 1b de `assistant.ps1:19558` se come la pregunta antes de que llegue a la charla, `Find-EnMemoria` (1745) no abre `cerebro.json`, y el repuesto es opencode a 25-60 s con tope de 240. De las cuatro veces que este camino se activó, acertó dos y falló dos. Medido hoy contra sus vectores de verdad: 5 preguntas de 5 sacaron el recuerdo correcto el primero sin compartir ni una palabra ("qué te dije del juego que era caro" → *"cada zombi cuesta ocho dólares"*, 0,576; "de qué hablamos del fuego en la casa" → *"braya dice que vio una casa con fuego"*, 0,651). Y el otro lado: el 18/09 a las 19:07, en 24 segundos, dos peticiones de borrado se fueron **enteras a opencode**, que es el agente con acceso total al sistema, mientras la charla le contestaba *"No tengo ningún dato sobre un oso polar"* —un dato que se había inventado ella misma el 13/09 y se había guardado—.

**Con qué se hace.** Nada que descargar: `embeddinggemma:300m-qat-q8_0` ya está instalado (338 MB), los 106 vectores están en `memoria/cerebro/vectores.json` y `Cerebro.buscar()` (`charla_memoria.py:347`) ya mezcla vector y palabras.

- **Una op `recordar`** (no "buscar": ese nombre ya lo usa `p.get("buscar")` para internet) en `atender()` (1047), junto a "apunta". **Sin** `revisor_parado.clear()`, o una pregunta a la memoria mientras juega despertaría al revisor que acaba de dormirse.
- **Primero lo gratis**: `buscar()` sin vector es instantáneo y ya cubre lo que comparte palabras; solo si eso falla se embebe la pregunta (medido: 3,3-3,4 s en frío, 0,03 s en caliente). Tope de 4 s y cae al camino de hoy sin decir nada raro. `keep_alive=0` se queda como está: el 13/09 ya se midió que dos modelos cargados paginan y suben el 3B de 3 s a 7-12 s, y él juega mientras habla. Si el worker está apagado o acaba de recibir "descargar", ni se intenta.
- **El listón, absoluto y medido, no relativo.** Fuera el margen de 0,06 copiado del ajedrez: con los datos reales los aciertos viven entre 0,45 y 0,65 y los fallos honestos llegan a 0,43. Listón 0,45 **en config**, y fijado pasándole antes 25-30 preguntas negativas sacadas de su propio log. Si en esa medición cualquier negativo pasa, no se enciende: soltarle un recuerdo que no viene a cuento es "hacer algo que no pidió", solo que hablando.
- **Que no invente, y que no finja citarle.** No pasa por ningún modelo generativo. Pero 101 de los 110 recuerdos son resúmenes en tercera persona escritos por el revisor, así que la conjugación depende del campo `tipo` que ya está guardado: los de tipo *contado* o *respuesta* salen de su boca y se conjugan enteros; los demás, no.
- **El asa para borrar.** `Find-EnMemoria` devuelve **hasta tres** líneas pegadas (`Select-Object -First 3`), así que el asa es la lista de lo que acaba de decir, cada una con su ruta y su texto exacto, y solo de `$DiarioDir` y `memoria\temas`. Se borra **por texto exacto y único** (si aparece cero o dos veces, no se toca nada), nunca por número de línea, porque `Add-DiarioResumen` mete bloques en ficheros de otras fechas. El reloj, con `$sw.ElapsedMilliseconds` a la manera de `$script:dictadoConfianzaEn`, 2 minutos, un asa viva como mucho.
- **Y el enganche que hoy rompe el caso**: "elimínalo" NO entra por la rama de memoria, entra por 10170 y 10178, que llaman a `Remove-DatoPerfil` y no encuentran nada. Esas dos ramas tienen que mirar **primero** el asa si está viva. El sujeto se casa contra las ≤3 líneas con `Get-Distancia` (638), porque Whisper oyó "El deloso volal".
- **Deshacer, no confirmar**: al 70,4 % un "sí" no confirma nada. La línea borrada entra como un paso más en `$script:historial` (5377-5405), así que "deshaz" —que él ya usa— la devuelve. Y no se apunta en el log lo que se borra, que es la regla ya escrita en 1866: queda *"OLVIDO: una línea del diario del 14/09"* y el texto solo en RAM hasta que caduque.

**Dónde se engancha.** `charla_worker.py::atender()` (1047); `assistant.ps1` en la rama `$RE_MEMORIA` (19560) por delante de `Find-EnMemoria`, con `$script:memPendiente` de 4 s que se limpia por los dos lados; y las ramas de borrado 10170/10178. De propina y gratis: meter `memoria\diario\*.md` en la lista de `Invoke-Olvido` (1869) con `Remove-LineasDesde`, que ya sabe hacerlo.

**Cómo se sale.** Nada es modo. El pendiente caduca a los 4 s, el asa a los 2 minutos, y a partir de ahí "olvida eso" vuelve a significar exactamente lo de siempre. En modo invitado ni busca ni borra: la rama ya corta con *"En modo invitado no miro tus notas"*.

**Riesgo de orden equivocada: bajo.** Solo lee `memoria\cerebro\*.json` y el diario, y habla; no toca el camino que acaba en `Invoke-FastCommand`. El borrado exige texto exacto, único y nombrado, y se deshace.

**Lo que dirá, conjugado.** *"El 21 me contaste que no te gustan todos los estilos de electrónica, solo algunos."* · *"Del 21 tengo esto apuntado: «Braya prefiere que la música se abra en YouTube»."* · *"Eso no lo tengo apuntado."* · *"Lo he borrado: el oso polar puede vivir sin dormir."* · *"Dije dos cosas, ¿te borro la del oso polar o la de los agujeros negros?"* · *"Te lo he devuelto."*

---

## 5. Limpiar lo que cree saber de él, preguntando una sola cosa con dos opciones

**Para qué.** `perfil.md` tiene exactamente 60 datos y `$PerfilMax = 60` (`assistant.ps1:6975`): está lleno, o sea que cada dato nuevo expulsa a otro. Y solo las 15 últimas líneas viajan en cada prompt de charla (`charla_worker.py:585`, `dp[-15:]`). Hoy esas 15 son *"tiene 8 dólares"*, *"quiere dejar un zoom configurado"* y *"braya habla con acento español (usa 'tío')"*, mientras *"prefiere que la música se abra en YouTube en lugar de Spotify"*, que es la primera línea, no entra nunca. Nueve de los 60 huecos se los comen dos nombres mal oídos: cuatro líneas de "Meramiau"/"Mira mío"/"Meramión" —que acabaron inventando un gato que no existe— y cinco de un juego llamado "Amin"/"Aminó". Esto no es cosmético: esas 15 líneas viajan en **todas** las charlas, así que la basura le vuelve hablada. Y el argumento fuerte es del 20/09 a las 23:09-23:11: sus **dos** correcciones seguidas del nombre del juego se guardaron como dos datos nuevos encima del malo.

**Con qué se hace.** Nada que descargar, y partido en dos mitades, porque `Cerebro` no toca `perfil.md` ni una vez.

- **La comparación, en `charla_worker.py`**, que ya tiene vivos el `EmbedOllama` y las líneas del perfil. **La pregunta y el borrado, en `assistant.ps1`**, que es quien manda en el perfil. El canal no hay que inventarlo: el bucle lector (16904) ya atiende eventos que no contestan a ninguna pregunta ("dato", "corrección", "diario"), así que basta `{"ev":"perfil_par","a":…,"b":…}`.
- **Medido con sus 60 líneas reales**: embeberlas cuesta 19,2 s en frío y 5,3 s en caliente, y salen 1 par por encima de 0,80, 5 sobre 0,75 y 10 sobre 0,70. O sea, una o dos preguntas, no una encuesta. Y **no vale** el parecido fonético de `pruebas/fonetica.py`: sobre esas mismas 60 líneas da 295 pares "parecidos", entre ellos "King Lear" con "tiene sentido del humor". Vale el vector.
- **La pregunta, al revés de lo obvio.** Entre 0,70 y 0,78 aparecen pares que son las **dos cosas ciertas a la vez** ("está jugando a un videojuego de zombis" contra "juega juegos de terror", 0,767). Si ahí se pregunta cuál es verdad, se acaba borrando algo cierto. Así que se pide **elegir cuál es**, no autorizar un borrado: *"¿Meramiau es tu gato, o es el personaje de tu novia?"*. La respuesta construye en vez de destruir, y aunque la elija al revés el perfil queda coherente, no mutilado.
- **Lista cerrada de tres y nada más**: la A, la B y "déjalo". Cualquier cosa que no encaje limpiamente cuenta como "déjalo" y no se borra nada. El que calla, conserva: dejar un dato falso cuesta una línea sucia más; borrar uno verdadero se pierde de verdad, porque `Save-DatosPerfil` (6989) reescribe el fichero entero y detrás solo están los zips diarios de `copias\`.
- **Molde de la trivia, no de la confirmación.** `Start-Confirmacion` escribe `confirmar.flag` y deja un pendiente esperando: eso es un modo. La trivia es una ventana con reloj (`triviaHasta = ahora + 90 s`, 16942; la primera frase dentro del plazo se toma como respuesta y se cierra sola, 19070). Eso es lo que hay que copiar.
- **Borrado por igualdad exacta**, leyendo con `Get-DatosPerfil`, quitando la línea que coincide carácter a carácter y reescribiendo. **Nunca `Remove-DatoPerfil`**: esa función adivina por palabras de 4+ letras, y con "usa Aminó" queda una sola palabra útil que aparece en tres líneas —ganaría la primera del fichero y borraría "se llama Aminó", que no es la que él eligió—.

**Dónde se engancha.** `charla_worker.py` (el par); `assistant.ps1`, sección PERFIL (6948) para la pregunta y el borrado; interruptor `perfil.repaso` en `config.json`.

**Cómo se sale.** Es una pregunta suelta, no un modo. Si no contesta dentro de la ventana, Nova se calla, no borra nada y ese grupo no se vuelve a preguntar en 7 días. Nunca con `$script:juegoActivo` puesto, nunca justo después de una orden, una al día como mucho, y solo cuando hay contradicción medible —que se acaban—.

**Riesgo de orden equivocada: bajo.** No borra por defecto, y lo que borre queda escrito entero en el log, como ya hace *"PERFIL: olvidado: …"* (7196).

**Lo que dirá, conjugado.** *"De estas dos, ¿cuál es? Una, Meramiau es tu gato. Dos, Meramiau es el personaje de tu novia."* · *"Vale, me quedo con el personaje y te borro lo del gato."* · *"Lo dejo como está."*

---

## 6. Soltarle sitio en el disco: cantar la factura, borrar lo que es caché y decir cuánto le ha soltado de verdad

**Para qué.** Nova ya le avisa pero no sabe actuar, y encima promete algo que no tiene: cuatro veces le ha dicho *"Te quedan X gigas. Pregúntame qué ocupa más"* (20/09 19:01 con 14,5 GB; 21/09 20:33 con 14,9; 22/09 08:33 con 11,1; 23/09 08:00 con 13,8) y **"qué ocupa más" no existe**: el único parser de tamaño es "cuánto ocupa {juego}" (4295), y el "lo que más ocupa" de la línea 1197 mide RAM, no disco. El 18/09 le quedaban 115 GB; hoy 13,7 de 475.

**Con qué se hace.** PowerShell pelado, 0 MB. Lista **cerrada** escrita en el código, nunca una ruta dicha por voz. Y el reparto por dueño, que es lo que decide si la función miente o no:

- **Lo regenerable se borra de verdad** con `Remove-Item`, porque mandarlo a la papelera lo mueve pero no lo libera: si Nova "borra" 900 MB así y luego dice que los ha soltado, `DriveInfo` seguirá marcando 13,7 GB —la mentira exacta contra la que se escribió el comentario de la línea 10934—. Medido hoy: AMD 672,6 MB, Packages `LocalCache`+`TempState` 132,2, TEMP viejo ~75, D3DSCache 2,4 y la papelera 0,2. Unos **880 MB**, no los "cuatro gigas y medio" del ejemplo; la frase se compone del recuento, jamás de un número escrito a mano.
- **Lo suyo va a la papelera**, uno a uno, con el ladrillo que ya existe (`DeleteFile(…,'SendToRecycleBin')`, 10922-10928). Descargas —822 MB en 9 archivos— nunca en bloque: se leen por nombre y fecha y solo se borra el que él nombre; ahí hay instaladores y el mod con el que juega.
- **Exclusiones medidas**: de los 2.457 MB de `%TEMP%`, 2.376,7 son `%TEMP%\claude`, en uso ahora mismo. Fuera eso, fuera lo escrito en las últimas 24 h, y fuera lo bloqueado (de 300 temporales de muestra, 3 estaban abiertos: se saltan en silencio y **no** se cuentan en el "te he soltado"). `C:\Windows\Temp` se cae de la lista: Nova no va como administrador y desde aquí se lee como 0 archivos. De `Packages`, solo `LocalCache` y `TempState`; el resto son sesiones, logins y partidas.
- **La lista se congela antes de hablar**: el sí de los 6 s se aplica a los ficheros que se midieron al cantar la factura, no a un segundo barrido —si no, algo escrito en esos seis segundos se borraría sin haber sido nombrado—.
- **Velocidad**: `Remove-Item` sobre carpetas regenerables son segundos; 22.826 archivos uno a uno por VisualBasic son minutos con Nova parada, porque cada uno pasa por el shell y escribe su registro.
- **Y ya que canta**, que nombre los dos bultos que valen más que todo lo anterior junto: `vosk/vosk-model-es-0.42`, 2,3 GB que no usa nadie, y la unidad **D: de 477 GB** que tiene al lado.

**Dónde se engancha.** Parser junto a `kind='disco'` (4091) y 'papelera' (4048); ejecución junto a 'aPapelera' (10861) y 'disco' (11405); el resumen, hermana de `Get-PapeleraResumen` (5659); y el aviso de 21652 deja de prometer lo que no existe.

**Cómo se sale.** No es un modo: una pregunta con `$script:pendiente` tipo 'peligrosa', que caduca sola en 6 s y no borra nada. Ojo con un detalle: la salida que prometía ("saca eso de la papelera") **choca** con 4159, que ya captura `^(restaura|recupera|saca) (.+)$` como restaurar una ventana, y no existe ninguna función de recuperar de la papelera. Hay que darle otra frase, o no prometerla.

**Riesgo de orden equivocada: bajo**, y vive en el reparto: lo único que se borra de verdad es caché regenerable de una lista escrita en el código.

**Lo que dirá, conjugado.** *"He mirado y te puedo soltar ochocientos ochenta megas: seiscientos setenta de la caché de AMD y ciento treinta de cachés de apps. ¿Te los suelto?"* · *"Te he soltado ochocientos sesenta megas de verdad; te quedan catorce gigas y medio."* · *"En Descargas tienes ochocientos veintidós megas en nueve archivos; esos son tuyos, te los mando a la papelera si me lo dices."* · *"He mirado y no te puedo soltar casi nada: lo que ocupa son los juegos."*

---

## 7. Hacerse sitio para hablar: bajarle el juego mientras dice la frase y devolvérselo al acabar

**Para qué.** Le habla mientras juega —toda la tanda del 22/09 de 21:43 a 21:48 es con una partida delante— y hoy Nova habla **encima** del audio del juego, a volumen fijo. En catorce días habla 41 veces con un juego en primer plano, con los altavoces medidos entre 0,10 y 1,000. Que se oiga a la primera ahorra la repetición entera, que son dos intervenciones habladas menos. No cambia lo que dice: cambia que llegue.

**Con qué se hace.** 0 MB, las dos mitades están puestas, pero con seis correcciones que no son opcionales:

- **No se pone 50, se multiplica.** `PonerVolumenApp` es absoluto de 0 a 100 (`assistant-dx.cs:536`): si él tiene el juego al 30 %, poner 50 se lo **sube**. Se lee antes con `LeerVolumenApp` (devuelve -1 si no hay sesión) y se baja en proporción; si ya está por debajo de ~20, no se toca nada.
- **Se baja justo antes de `Play-Audio`** (12133), que es el único sitio donde ya se sabe que va a sonar algo. `Say` tiene cinco salidas antes: `Test-EnLlamada`, la voz en línea, la tardía, Piper, el *"no hay ninguna voz disponible"* de 12893 y el catch. Bajando arriba del todo, una llamada entrante dejaría el juego bajado toda la llamada.
- **Reloj propio, nunca `pausaHasta` a secas.** `$script:juegoBajadoHasta = max(vozFinReal, pausaHasta) + 250`, con techo duro de 20 s, y devuelto **siempre** por el bucle aunque no haya sonado nada. `pausaHasta` se alarga con la sordina y con *"no me hables por diez minutos"* —que es literalmente lo que dijo el 22/09 a las 21:48:55—: atado ahí, el juego se le quedaría a media voz diez minutos. Y se devuelve también a mano en la rama del corte (20346) y en la del "no hay voz".
- **Una sola bajada por tanda.** La charla encadena frases (el 22/09 dijo tres en nueve segundos): si sube y baja por frase, eso es bombeo y suena peor que no hacer nada. No se devuelve mientras `charlaFrases` tenga cola.
- **Si él lo toca, manda él.** Antes de devolver se relee: si el nivel ya no es el que dejó Nova, se respeta el suyo y se tira el guardado. "Sube el juego" ya existe y no se le puede pisar.
- **Que no sobreviva a Nova.** 235 arranques en 14 días; un juego al 45 % para siempre sería un modo pegado **y** mudo. Testigo en `tmp\juego-volumen.json` con el patrón ya probado del brillo (14817-14830), devuelto al arrancar si el mismo juego sigue vivo, y devuelto también en `Exit-Juego` (14865).
- **Solo el juego.** Los PID se resuelven una vez al entrar (21367), no en cada frase —`Get-Process` recorriendo todo es caro y él prioriza la velocidad—, y solo los de `$script:juegoExe`: bajarle Discord le quitaría la voz de su pareja, que es el peor fallo posible de esta función.
- **Un efecto que nadie mira**: `wake_vosk.py` congela la ganancia con los altavoces sonando (587, 1537, 1589, 3286; 1.472 líneas de "suenan los altavoces"). Durante la ventana de bajada y medio segundo después, el calibrador no toma medida, o se recalibraría con el juego bajo.

**Dónde se engancha.** Dos funciones nuevas (`Bajar-Juego` / `Devolver-Juego`), llamadas desde `Say` y desde el bucle principal (20431), no alrededor de `Say-Online` —si no, Piper y la voz de Windows se quedarían fuera—.

**Cómo se sale.** Dura lo que dura una frase, y hay tres caminos de vuelta más el testigo en disco. "No me bajes el juego" lo apaga del todo.

**Riesgo de orden equivocada: bajo**, y todo está en devolverlo.

**Lo que dirá, conjugado.** Nada, que es la gracia. Como mucho, si él lo apaga: *"Vale, ya no te lo bajo."*

---

## 8. Enseñarle el trozo de pantalla ampliado en vez de leérselo mal

**Para qué.** La familia "lee la esquina de arriba a la derecha", "qué pone en el centro" (4331-4360) existe precisamente porque en una consola de 7 pulgadas la letra pequeña no se lee. Y hoy la respuesta es un recitado del OCR: ahí es donde los fallos del OCR se convierten en palabras equivocadas dichas en voz alta —el único OCR de juego del log devolvió cinco fragmentos y dos eran basura ("O", "Kit")—. El 20/09 se lo dijo: *"no describas lo que ves en la pantalla literalmente"*, y ese chorro aparece 5 veces en `destinos.jsonl`. Ampliando el recorte no hay OCR que falle: lo lee él, en medio segundo, y Nova no dice una palabra.

**Con qué se hace.** 0 MB. `Get-ZonaRect` (15017) + `Save-Captura` (15044) ya recortan exactamente esa zona y dejan un PNG; hoy ese PNG solo sirve para dárselo al OCR. Dos caminos, y los dos están en casa:

- **Por la cápsula**: meter `"lupa"` y `"lupaN"` en la misma línea JSON de `Set-UI` (13343-13405) —el contador hace falta, porque si la ruta no cambia el JSON no cambia y la cara no se entera, que es el mismo truco de "evento"/"n"—, y un `Image` en `nova_ui.cs` hermano del avatar (1018). Dos detalles finos: `NearestNeighbor`, no `HighQuality`, porque el filtro suave emborrona el texto justo cuando lo amplías; y cargarlo por `MemoryStream` con `BitmapCacheOption.OnLoad`, porque `BitmapImage` cachea por URI y enseñaría la captura anterior, además de bloquear el fichero.
- **O por ventana propia sobre `AXTarjeta`** (15643-15657: handle sin mostrar, `SW_SHOWNA`, sin `TopMost`), que es lo que no le echa de la partida. Si se hace así, necesita su propio `$lupaForm`/`$lupaUntil` **y** hay que añadir esos nombres a 'quitarTarjeta' y 'fijarTarjeta' (10817-10829), que hoy solo miran `$popupForm`: si no, "quítala" le contesta *"no había ninguna tarjeta"* mientras la lupa le sigue tapando la pantalla, que es exactamente el modo sin salida que no aguanta.
- **Tope de tamaño**: 3x de un cuarto de esta pantalla es más grande que la pantalla entera. Se calcula la escala para que quepa en el 60 % del área de trabajo y se baja el aumento si no cabe.
- **Rama propia, sin OCR.** Sale en cuanto se copia la pantalla, que es lo rápido; el OCR se corre después sobre ese mismo PNG **solo** si él pide "copia lo que pone ahí". Así la lupa es más rápida que la lectura de hoy, no más lenta.

**Dónde se engancha.** Rama 'lupa' al lado de 'ocr' (11947); `Get-ZonaRect`/`Save-Captura` (15017-15070); `Set-UI` (13376-13401) o `Show-Popup` (15612).

**Cómo se sale.** Cierre triple: el plazo `$PopupMs` (8.000 ms) que el bucle ya retira (21683-21698), "quítala", y cualquier orden siguiente. "Déjala ahí" la fija como mucho los 10 minutos de `$PopupFijadaMs`, no para siempre.

**Riesgo de orden equivocada: ninguno.** Solo dibuja una ventana que no roba el foco ni manda una tecla.

**Lo que dirá, conjugado.** *"Ahí lo tienes."* y se calla. Si la lupa acaba narrando, pierde su única ventaja.

---

## 9. Saber cuáles de sus juegos se juegan entre dos, y contestar qué pueden jugar ella y él esta noche

**Para qué.** Es su rutina de la noche y hoy Nova no tiene ni el dato. It Takes Two —cooperativo obligatorio— lleva casi 13 horas en `memoria\juegos.json` en cinco sesiones (20.273 s el 15/09, 11.495 el 22/09, 9.907 el 20/09). Lo preguntó dos veces en voz alta y las dos se perdieron con *"tampoco es una orden que sepa hacer"*: el 20/09 a las 23:23, *"andamos buscando un juego de terror que vamos a jugar juntos"*, y otra noche, *"recomiéndame algún juego bueno de Roblox que se pueda jugar con mi novia"*. Y anteanoche lo resolvió a mano: entre las 00:32 y las 00:50 del 23/09 terminó de instalar **Unravel Two** y **A Way Out**, los dos estrictamente de dos jugadores. Nova vio pasar las tres descargas y no supo leer lo que significaban.

**Con qué se hace.** `store.steampowered.com/api/appdetails?appids=ID&filters=categories&l=spanish`: **sin clave y gratis** (la de `api.steampowered.com` que usa `Get-AmigosSteam` sí la pide, y en `config.json` no hay sección `steam`, o sea que esa función hoy solo contesta que le falta). Con el filtro, las doce juntas ocuparon 7.173 bytes; sin él, la ficha entera trae capturas y vídeos y se va a cientos de kB por juego. Las etiquetas que importan vienen ya en español: 9 Cooperativo, 39 Cooperativo a pantalla partida, 24 Pantalla partida, 44 Remote Play Together.

Y el agujero que hay que tapar de entrada: **It Takes Two y Roblox no tienen appmanifest**. Nova los conoce solo porque los ve en primer plano. Así que la etiqueta viene de dos sitios: de Steam cuando hay appid, y **dicha por él** cuando no ("It Takes Two es de dos", y se guarda); y si le preguntan por uno que no sabe, *"de ese no lo sé, ¿es de dos?"* en vez de callárselo. Nada de tabla escrita a mano: la biblioteca se movió 17 → 10 → 12 → 14 → 16 → 11 → 14 en cinco días, y una lista fija nace caducada.

**Dónde se guarda.** `memoria\juegos-dos.json` con `Write-Atomico` (643), por appid y por nombre limpio. **No** en `memoria\juegos.json`: `Save-JuegosMem` (7284) lo reescribe entero desde `$script:juegosMem` cada vez que se apunta tiempo de juego, así que la etiqueta se la llevaría por delante el siguiente `Save-TiempoJuego`.

**Cuándo consulta.** Nunca dentro de `Update-Juegos`, que se llama desde ocho sitios y corre cada 60 s: meterle 2,5 s de red la congela, y sin conexión el `TimeoutSec` se multiplica por juego. Se pide cuando ve un appid nuevo, o la primera vez que él pregunta, con `TimeoutSec 4` y el patrón del clima (13776-13792): si la red falla, contesta con lo guardado.

**Cómo se sale.** No es un modo: pregunta y respuesta corta. Abrir sigue pasando por `Start-Confirmacion`.

**Riesgo de orden equivocada: ninguno.** Lee un `.acf`, un JSON en disco y habla.

**Lo que dirá, conjugado, y con la concordancia cuidada** como se arregló el "1 juegos" en 3559 —y separando lo que se juega en el sofá de lo que es por internet, porque "Co-op" mete en el mismo saco a A Way Out y a Elden Ring—. *"De lo que tienes instalado podéis jugar a tres los dos solos: A Way Out, Unravel Two y The Past Within, y los tres los tenéis sin tocar. Si queréis por internet, os sirve Content Warning."* · *"Ese sí, se juega a pantalla partida."* · *"Ese no lo sé, ¿es de dos?"*

---

## 10. Elegir con el pulgar: resolver con el mando cualquier lista cerrada, sin pasar por el oído

**Para qué.** El 70,4 % de oído es el techo de todo lo demás: el 22/09 fueron 15 bien y 4 equivocadas, el 21/09 10 y 6, y las falsas alarmas van del 20 % al 50 % según el día. El ajedrez demostró que cuando la respuesta está en una lista cerrada no hace falta transcribir, solo elegir; el paso siguiente es que ni siquiera haga falta hablar. Y esto no es una función suelta: **es lo que hace fiables a la vez a media docena de las de esta lista** —los montajes, los recuerdos, el par del perfil, los juegos de dos—, porque todas acaban en "elige entre estas".

**Antes de escribir una línea, se mide**, y cuesta dos minutos: ejecutar `tools\diag\diag-buttons.ps1` dos veces, una en escritorio y otra con It Takes Two delante, y apuntar qué botones llegan en cada caso. Eso resuelve A4 y A5, que llevan pendientes desde el 19/09, y decide la idea entera. Si la cruceta no llega fuera del juego, se navega con lo único que sí llega siempre, el **≡** (19 toques cortos contados en `estadisticas.json`, con sueltas medidas a 190 y 158 ms): toque corto salta al siguiente, mantener elige.

**Con qué se hace.** 0 MB. `Open-PanelRapido` / `Show-PanelRapido` / `Invoke-PanelRapido` (19989-20075) ya son una lista navegable con arriba/abajo, A para confirmar, vibración al abrir y cierre solo a los 6 s. Falta soltarla:

1. **Descablear la lista.** `$PanelItems` es un array global fijo (19983) y `Show-PanelRapido` decide la etiqueta con un `switch` que nombra a mano volumen, brillo, música, energía y salida (20007-20022). Los ítems pasan a `$script:panel.items`, cada uno con su etiqueta y su acción; ese `switch` se queda solo como contenido del panel de ajustes.
2. **Un campo `modo` ('ajustes' / 'elige'), porque hoy el panel se suicida justo cuando haría falta.** La línea 20173 lo cierra si hay `$script:pendiente`, y la 20196 no lo abre si lo hay —y un selector nace precisamente cuando hay algo pendiente—.
3. **Que la A no se la coma la confirmación.** El bloque que atiende A y B (20136-20166) corre antes y solo mira `$script:pendiente`: si hay una elección abierta, la A se gastaría en decir que sí a otra cosa.
4. **Dentro del juego, jamás un botón pelado**: acordes con ≡ apretado y contando el flanco, como ya se hace desde el 13/09 en 20141, para que una pulsación que ya venía apretada jugando no valga como elección. Y nunca ≡ + botón izquierdo, que dispara el atajo de ASUS.
5. **Cinco o seis candidatas como mucho.** La cápsula enseña una línea (`Get-TextoCapsula`, 13334, aplasta saltos y trunca a 140), así que se ve "‹ 3/6 Hollow Knight ›" de uno en uno; y con un juego delante, cada golpe de cruceta también se lo come el juego.

**Y los números reales, que los de la idea original no eran los que hay**: Steam tiene 13 `appmanifest`, hay 8 recetas, el historial de música guarda 12 canciones —300 es el tope de `Add-HistorialMusica` (7947), no lo que hay dentro— y `memoria\contactos.json` ni siquiera existe. Lo que hoy vale la pena ofrecer: los juegos de Steam, las ventanas abiertas, los montajes, las dos jugadas del ajedrez y el par del perfil.

**Cómo se sale.** Es el patrón más seguro que tiene Nova: pasar por encima no ejecuta nada, solo A ejecuta, B cancela, y **al vencer el plazo se cierra sin ejecutar**. Si le llega una ráfaga de pulsaciones seguidas, las descarta y se cierra: eso es él jugando, no él eligiendo.

**Riesgo de orden equivocada: ninguno**, con una condición que no se toca: las preguntas marcadas 'peligrosa' siguen exigiendo el sí hablado (20154). La cruceta sirve para señalar **cuál**, nunca para relajar lo peligroso; si no, sería la puerta de atrás de las órdenes protegidas.

**Lo que dirá, conjugado.** *"Te he puesto Hollow Knight."* · *"Lo he dejado."*

---

**Se quedan fuera por poco** (y ninguna está muerta): el segundo mando y quién apretó —fase 1 medible, pero antes hay que contar durante dos o tres partidas cuántos mandos vivos ve de verdad, porque si juegan por internet no se dispara jamás—; el dedo que pulsa por nombre lo que está escrito en la pantalla; vigilar un trozo de pantalla y avisar vibrando; señalar con la cápsula en vez de describir; enseñarle una zona del juego ("esto de aquí es mi vida"); el cuaderno de nombres propios; leer la mitad de la pantalla de ella; y apagarle lo que arranca con Windows.

---

## Si hubiera que elegir tres

**La 2 (las palabras que no dice), la 3 (los montajes con nombre) y la 1 (mirar la pantalla de verdad).** Las tres tienen lo mismo en común, y por eso van juntas: **son las tres cosas que él ha pedido en voz alta, más de una vez, y que siguen sin funcionar**. Tres peticiones de quitar una muletilla, once intentos de partir la pantalla con cero aciertos, y una noche entera peleándose con que Nova no miraba. No hay que convencerle de que las quiere: ya se enfadó por las tres.

Y además cubren los tres frentes distintos: la 2 arregla **cómo le habla** y es pequeña; la 3 arregla **lo que le hace** y es la única función de esta lista con un cero absoluto medido detrás; la 1 arregla **lo que le contesta** y convierte un "estás alucinando" en la respuesta que buscaba. Si solo cupiera una, la 2: se toca en un sitio, se nota en cada frase, y no puede hacer daño.

---

## Lo que cayó, y por qué

- **Llamarla con un silbido o dos chasquidos** — el motivo estaba mal leído, braya ya contestó a esa pregunta antes, y reabre el disparo por sonido que ya se había cerrado.
- **Un vocabulario de vibraciones, un "¿qué era eso?" y el parte de lo que te perdiste** — los números no dicen lo que la idea afirmaba, y el vocabulario que prometía construir ya existe.
- **Esperar al hueco para hablar (pausa o pantalla de carga)** — el dato que la sostenía estaba inventado y el hueco que promete no existe en esta casa.
- **"A la de tres, los dos": los dos mandos vibrando a la vez** — comprobado en la consola: `XInputGetState` solo contesta 0 en el índice 0, el segundo mando no consta.
- **Nova le dice algo a ella por su mando y ella contesta por el suyo** — mismo mando que no consta, y el mecanismo hace justo lo contrario de lo que promete.
- **Al entrar en el juego, una línea de dónde te atascaste** — el recuerdo en que se apoyaba es una alucinación de la propia Nova, rastreada hasta la frase que la inventó.
- **Encontrar un archivo por voz y hacer una de tres cosas con él** — de las tres pruebas, dos estaban mal contadas y la tercera no era lo que parecía.
- **El veto de música ("esto no me gusta", y no vuelve a sonar)** — motivo inventado, y la única vez que Nova hizo exactamente eso, se equivocó.
- **Ponerle nombre a las voces que lleva días oyendo** — esas tres personas son ruido; ya se midió y ya está escrito.
- **Contestar sin hablar: sí/no en la carita, cantidades en la barra** — los datos no sostienen el mecanismo propuesto y el canal elegido ya está medido.
- **La voz de la casa: lista corta y cerrada para la pareja** — ya está hecha en `assistant.ps1`, y el número que la justificaba no aguanta un nombre.