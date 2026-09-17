# Pendiente

Lo que queda por hacer, con el porqué de cada cosa. Anotado el 12/09/2026.
Para retomar: leer esto y `ESTADO.txt` (lo que ya funciona), y pasar
`powershell -NoProfile -File tools\probar-todo.ps1` antes de tocar nada.

---

## Antes de nada, tres cosas tuyas

- [ ] **Probar el dictado largo con una ventana tuya delante.** Está hecho y
      probado por dentro, pero lo único que no se ha podido comprobar desde
      aquí es que el texto acabe en TU ventana y no en otra (inyectando
      órdenes por archivo no se controla el foco). Abre el Bloc de notas, di
      "dicta un correo", di una frase y mira. Detalle en `ESTADO.txt`.

- [ ] **Encender el asistente y probarlo.** Sigue apagado a propósito desde el
      11/09. El comando está al principio de `ESTADO.txt`.

Y para devolver la pantalla de la Ally a como estaba (ahora no se apaga nunca,
ni con batería):

    powershell -NoProfile -File "C:\Users\braya\Documents\pantalla-ally\restaurar.ps1"

---

## Funciones nuevas

Elegidas el 13/09 (todas menos la «tarjeta de fin de partida»). REGLA DE
DISEÑO: máximo minimalismo MANTENIENDO EL DISEÑO ACTUAL de la cápsula. Nada de
tarjetas ni elementos visibles nuevos: se reutiliza lo que ya hay (texto corto,
pulsos de color del borde, gestos, insignia) o la voz.

- [x] **A. Responder con el mando** (13/09): con una pregunta esperando, A = sí
      y B = no (cuenta la pulsación, no tenerlo apretado; una pregunta
      peligrosa sigue pidiendo un sí hablado). La pista de la cápsula dice
      «Ⓐ sí · Ⓑ no». **Falta probarlo con el mando en la mano.**
- [x] **B. «¿Dónde me quedé?»** (13/09): «me quedé en el jefe del castillo» o
      «lo dejo en…» mientras juegas (o hasta 2 h después) lo apunta en
      `memoria\juegos.json`. «¿Dónde me quedé?» lo dice, y al volver a entrar
      en el juego sale en la cápsula, sin voz ni tarjeta.
- [x] **C. Batería por juego** (13/09): sin cargador y con un juego delante,
      mide por tramos de 20 min cuánto gasta y lo promedia. «¿Cuánto me dura la
      batería?» / «¿me da para terminar?» contesta con el ritmo de ESE juego, y
      al entrar la cápsula dice «batería para 2 horas». `tools\probar-juegos.ps1`.
- [x] **D. Te propone automatizaciones** (13/09): apunta las órdenes que HACEN
      algo (`memoria\habitos.json`). Si la misma se repite a la misma hora
      (±30 min) o justo después de abrir una app (3 min), tres días distintos
      de la última semana, pregunta al terminar una orden (nunca jugando) si
      la hace sola. Sí = regla; no = no vuelve a proponerla. Una al día.
- [x] **E. Notificaciones mientras juegas** (13/09): mira las de Windows cada
      30 s. Jugando, una nueva solo hace latir el borde de la cápsula en azul
      claro (sin voz, sin texto). «¿Qué me han escrito?» dice cuántas y de qué
      app; «léemelos» las lee, sin tarjeta. `tools\probar-costumbres.ps1`.
- [x] **F. La música en la cápsula** (13/09): mira cada 5 s lo que suena en
      Windows (Spotify, navegador…). Mientras suena y está en reposo, la carita
      se mece 3° de lado a lado, a 12 fps (nada jugando a pantalla completa ni
      dormida). Al empezar una canción, «♪ título · artista» 3,5 s, solo si no
      juegas ni está haciendo nada. «¿Qué canción es?» lo dice; «pausa la
      música» / «reanuda la canción» usan la tecla de reproducir.
- [x] **G. Nova evoluciona** (13/09): nivel del 0 al 5 según lo aprendido
      (tareas, formas de pedirlas, datos tuyos y reglas; umbrales 1, 5, 12, 25
      y 50). Casi invisible a propósito: el halo crece 2 px por nivel. Al subir,
      después de hablar, chispas doradas y «Nivel 3» un momento, sin voz ni
      sonido. «¿Qué nivel tienes?» dice cuánto falta para el siguiente.
- [x] **H. El clima vivo en el cristal** (13/09): con el tiempo de cada hora
      (open-meteo), si llueve le resbala una gota a la carita cada 14-26 s; si
      nieva, un copo; con tormenta, además, un destello breve del halo. Solo en
      reposo, ni dormida ni a pantalla completa. De 22:00 a 7:00 la voz en línea
      suena al 55 % (Piper, el respaldo, no tiene volumen). El tono del
      amanecer no se añadió: la cápsula ya cambia de tono de noche.
- [x] **I. Panel rápido con el mando** (13/09): doble toque en ≡ y la cápsula
      enseña una sola línea, «‹ Volumen ›». Cruceta izquierda/derecha: Volumen,
      Brillo, Música. Arriba/abajo: sube/baja (brillo de 10 en 10, que se lee y
      se dice); siguiente/anterior en la música. A: silenciar o play/pausa. B
      cierra; a los 6 s sin tocar nada se cierra solo. OJO: XInput no es
      exclusivo, así que con un juego delante la cruceta también le llega al
      juego. **Falta probarlo con el mando en la mano.**

Segunda tanda, elegidas todas el 13/09 (misma regla de diseño):

- [x] **J. Modo foco** (13/09): «modo foco» (25 min), «modo foco de media hora»,
      «pomodoro». Un temporizador de tipo foco que el anillo de la cápsula cuenta;
      al terminar, «¿descanso de cinco minutos?» (sí/no o el mando) y otro
      anillo de 5 min. «Termina el foco» lo quita.
- [x] **K. Historial del portapapeles** (13/09): los 10 últimos textos copiados,
      mirados cada 4 s, solo en memoria (ni disco ni log). «¿Qué copié antes?»,
      «pega lo penúltimo», «¿qué he copiado hoy?» (por voz, sin tarjeta).
- [x] **L. Traducir la pantalla** (13/09): «¿qué dice esto?», «tradúceme esto».
      Lee la pantalla en local (OCR) y solo ese texto va al cerebro, que contesta
      en una o dos frases; se oye, sin tarjeta. Es un atajo de `Process-Texto`:
      el banco `-Probar` no lo ve.
- [x] **M. Micrófono de Discord** (13/09): «silencia mi micro», «ensordéceme».
      Nova pulsa un atajo GLOBAL (config.json `discord.teclaMicro`, por defecto
      Ctrl+Shift+M; `discord.teclaSordo`, Ctrl+Shift+D). **Hay que crear esos
      atajos en Discord** (Ajustes > Atajos de teclado). Son interruptores: Nova
      no sabe si queda silenciado o no, y no lo presume.
- [x] **N. Ahorro con batería baja jugando** (13/09): cuando salta el aviso de
      batería (config `avisos.bateriaPct`, 15 %) con un juego delante y el
      brillo por encima de 40, en vez de hablar: pulso ámbar y «¿Bajo el
      brillo?» en la cápsula; sí (o ≡+A) lo pone al 30 %.
- [x] **O. Recordatorio para cargar** (13/09): apunta la última orden de cada día
      (la madrugada cuenta como el día anterior). Con 4 días de las dos últimas
      semanas sale tu hora habitual; en la media hora antes, sin cargador y por
      debajo del 40 %, pulso ámbar y «Enchúfame antes de dormir». Una vez al día.
- [x] **P. Respuestas más cortas jugando** (13/09): con un juego delante, el
      prompt de sistema del cerebro le pide una sola frase corta.
- [x] **Q. Resumen al volver** (13/09): si la orden llega tras más de 2 h sin
      decirle nada, después de contestar la cápsula enseña «Mientras no estabas:
      3 mensajes de Discord». Hoy solo cuenta mensajes; si no pasó nada, calla.
- [x] **R. La cápsula se atenúa sin uso** (13/09): a los 5 min en reposo sin
      actividad baja poco a poco (cápsula al 70 %, carita al 80 %); vuelve entera
      al cambiar de estado o al acercar el ratón (`Despertar`).
- [x] **S. Reacciones al tono de voz:** YA EXISTÍA (`MedirTono` en nova_ui.cs:
      gritar encoge y abre los ojos; susurrar la acerca y baja el halo). Solo se
      añadió que al susurrar se incline 7°.

---

## Interfaz y visuales

- [x] **12. Distinguir «lo hago yo» de «esto lo lleva el agente»** (13/09).
      «Pensando» es ámbar cuando lo hace Nova sola (una receta, el oído fino,
      leer la pantalla) y violeta desde el primer instante cuando lo lleva la
      IA (`Submit-Command` pone la marca; el estado viaja como `remoto`, y
      cualquier estado que no sea «pensando» la quita).

- [x] **16. Fijar la tarjeta larga** (13/09). «Déjala ahí» / «fija la tarjeta» /
      «no la quites» la deja 10 minutos (no para siempre); «quítala» / «ya la
      leí» la cierra. Mientras está fijada, los mensajes cortos van solo a la
      cápsula; uno largo la sustituye. Probado en vivo: seguía a los 14 s.

- [x] **18. «¿Cómo estás configurada?»** (13/09). También «cuál es tu
      configuración», «qué ajustes tienes». En una tarjeta: nombre, oído
      (Whisper y oído fino, sordina), voz, cerebro y sus modelos, esquina,
      tamaño, color, y cuántos modos, reglas, tareas aprendidas y datos tuyos.

- [x] **19. Color a elección** (13/09). «Ponte de color naranja», «vuélvete
      azul», «cambia tu color a rosa», «ponte morada»; «color normal» o «vuelve
      a tu color» para el de siempre. Quince colores (`$ColoresUI`), guardado en
      `config.json` (`ui.color`) como la esquina. Solo cambia el de reposo; de
      noche el elegido se templa un poco en vez de volverse melocotón. Al
      cambiar, una onda del color nuevo.

- [x] **20. Que se aparte también hacia arriba o abajo** (13/09). Si deslizarse
      de lado la deja igual de tapada (la ventana ocupa toda la franja), se
      queda en su lado y sube hasta el borde de la ventana (o baja, si vive
      arriba). Si la ventana no deja hueco, se queda donde está. «¿Me tapa?» se
      pregunta en su sitio base (`topBase`), no en el apartado: si no, subía,
      dejaba de estar tapada y bajaba en bucle. Probado con una ventana de
      prueba de toda la anchura: sube y al cerrarla vuelve.
      Ojo para probarlo: una ventana abierta desde un script de fondo no se
      queda con el foco (Windows lo impide) y la cápsula solo se aparta de la
      ventana que tiene el foco; hace falta `AttachThreadInput`.

---

## Quinta tanda (elegidas todas el 13/09, noche)

Misma regla de diseño: minimalista, sin tarjetas ni elementos fijos nuevos.

Diseño (nova_ui.cs; nada nuevo a la vista):
- [x] D1 Destello blanco en el halo cuando la API confirma algo del cerebro (sin sonido).
- [x] D2 Voz de la charla con un pelo de oro si es de memoria y de violeta si es de la API.
- [x] D3 La línea de la cápsula se llena mientras la charla tarda (en frío, 12-16 s).
- [x] D4 Escucha activa: **ya existía** (asiente cada 3,5 s en frases largas).
- [x] D5 Cara según la charla: apoyo si dices que estás cansado o triste; risa si cuenta un chiste.
- [x] D6 De 1:00 a 6:00 se duerme a los 10 min sin uso; al despertar, bostezo.
- [x] D7 Al enchufar el cargador, una luz verde sube por el halo.
- [x] D8 Con otra pantalla conectada (dock), un 25 % más grande.
- [x] D9 Un copo en diciembre y enero, una hoja en octubre y noviembre (cada 2-4 min en reposo).
- [x] D10 Mira un instante a una ventana nueva o hacia donde salen las notificaciones.

Funciones:
- [x] F1 «Haz un clip» / «guarda la jugada»: Win+Alt+G. Si la Game Bar no graba en
      segundo plano, lo dice. («Guarda lo último» ya era copiar la respuesta.)
- [x] F2 «¿Cómo paso este jefe?» con un juego delante: pantalla + búsqueda web en
      la API, explicado en 2-3 frases; se aprende.
- [x] F3 «Me voy a dormir»: brillo y volumen bajos y pregunta por el despertador
      (con un juego delante, antes apunta dónde te quedaste). «Apágate en 30
      minutos» (siempre con un sí) y «cancela el apagado».
- [x] F4 «Despiértame a las 7»: música, la hora, el tiempo y lo de hoy; «cinco
      minutos más»; «quita el despertador».
- [x] F5 «¿Cuánto le queda a X?», «¿qué se está descargando?», «pausa las
      descargas» (abre las descargas de Steam: desde fuera no se pueden pausar).
- [x] F6 «Avísame cuando lleve 2 horas»: aviso al llegar y otro 15 min después.
- [x] F7 «Hazme una pregunta»: trivia de lo confirmado; «me rindo».
- [x] F8 «Cuando conecte el dock / me ponga los cascos…» (reglas y recordatorios).
- [~] F9 «¿Quién está conectado en Steam?» **necesita una clave gratuita de la API
      de Steam** en config (`steam.apiKey`). Discord: solo con un bot en tus
      servidores; **descartado por braya el 14/09** (no se hace).
- [x] F10 Historial en `memoria\musica.json`; «¿cómo se llamaba esa canción?»,
      «pon la que sonaba anoche» (la busca en Spotify).

Mejoras de lo que existe:
- [x] M1 «¿Qué has aprendido?» cuenta también lo aprendido hablando.
- [x] M2 Precarga de Qwen al llamarla si hablasteis hace poco o sueles charlar a esa hora.
- [x] M3 Repaso del día (con 20 min sin charla): poda, junta repetidos, re-revisa lo provisional.
- [x] M4 Lo que contesta Claude Code a una pregunta también pasa al cerebro.
- [x] M5 «Espera», «para», «calla» mientras habla: se calla y te escucha (descarta la
      palabra si está en su propia frase, por el eco). **Probar con altavoces.**
- [x] M6 Voz un pelo más alegre o más calmada según la frase de la charla.
- [x] M7 Tres frases en 10 min con una voz que no es la tuya: pregunta si pone el modo invitado.
- [x] M8 La ventana de escucha se ajusta a lo que tardas en empezar a hablar.
- [x] M9 Con 4 o más mensajes, el modelo LOCAL los resume (nunca la API).
- [x] M10 En plena charla, «recuérdamelo luego» se reescribe con lo hablado y se hace.

Medido al hacerlo: la búsqueda por significado con Qwen cargado hacía paginar a
Windows (428 MB libres) y la respuesta pasaba de 3 s a 13 s. Ahora solo se usa
para confirmar una pregunta parecida que ya se encontró por palabras.

## Cuarta tanda (elegidas todas el 13/09, noche)

Regla de diseño de siempre: minimalista, sin cambiar la cápsula.

Diseño (todo en nova_ui.cs, sin elementos nuevos a la vista):
- [x] D1 La sombra sigue al sol (ángulo según la hora).
- [x] D2 Estela breve al cambiar de esquina.
- [x] D3 Asiente con ≡+A y niega con ≡+B.
- [x] D4 Cara de concentración en modo foco (ojos entrecerrados, latido lento).
- [x] D5 El halo marca el volumen al cambiarlo (campo `vol`).
- [x] D6 Tono muy leve del icono del juego en el color de reposo (18 %).
- [x] D7 Expresión según el tiempo (lluvia/nieve cautos, sol atentos).
- [x] D8 Noche profunda: tras medianoche, halo casi apagado.
- [x] D9 Descarga terminada: el anillo se completa con un salto.
- [x] D10 El icono del juego entra girando.

Funciones:
- [x] F1 Recordatorio de un solo uso ligado a abrir una app o juego.
- [x] F2 «Resúmeme esto» (pantalla resumida por voz).
- [x] F3 Contactos importantes en las notificaciones («pon a Ana como importante»).
- [x] F4 Brillo automático por hora («activa el brillo automático»).
- [x] F5 Notas de voz: «graba una nota» (el worker guarda el WAV en
      memoria\notas-voz, con su texto al lado), «reproduce mi última nota»,
      «lee mi última nota de voz».
- [x] F6 Traductor de conversación: «traduce lo que diga (en francés)». Whisper
      escucha en ese idioma, la traducción se oye y vuelve a escuchar sola; se
      acaba con silencio o «stop».
- [x] F8 Modo invitado: «pon el modo invitado» / «quita el modo invitado» (o
      solo tras 30 min sin órdenes). Sin costumbres, recetas, perfil, voz,
      estadísticas, notas ni mensajes, y la charla no hereda la tuya.
- [x] F9 Copia de seguridad también en OneDrive (14 últimas).
- ~~F10 Aviso de temperatura~~ **No viable:** WMI (MSAcpi_ThermalZoneTemperature)
  da acceso denegado sin administrador.

Mejoras de lo que existe:
- [x] M1 Recetas que preguntan el valor que falta («crea una carpeta» → «¿Qué
      nombre?»). Solo con un hueco y al final de la frase aprendida.
- [x] M2 Temporizadores con nombre, pausa y «¿cuánto le queda al de…?».
- [x] M3 Reglas combinadas («cuando abra X y sea de noche…»; noche = 20:00–7:00).
- [x] M4 Hábitos que proponen modos: tres órdenes seguidas (en menos de 5 min,
      tres días) → «¿te hago un modo?» → «modo rutina».
- [x] M5 Panel rápido con Energía y Salida de sonido.
- [x] M6 «Dónde me quedé» automático leyendo la pantalla al salir.
- [x] M7 Contestar mensajes por voz («contéstale que ya voy»; escribe sin enviar).
- [x] M8 Parte de la mañana: primera orden del día (5–12 h), una línea sin voz
      con el tiempo, la batería y lo de hoy.
- [x] M9 Batería con consejo («¿me da para jugar hasta las 12?»).
- [x] M10 Listas al portapapeles («copia la lista de la compra», «pásame mi lista»).

### SECCIÓN APARTE: conversación de verdad (pedida el 13/09)

La idea F7 («cuentas y conversiones sin IA») se convierte en algo más grande:
que Nova pueda **conversar de verdad** sin pasar por Claude Code. Requisitos
que puso braya:
- Una IA de conversación propia (sin Claude Code).
- **Nova vuelve a escuchar sola después de responder o de hacer cada cosa**,
  esperando más palabras suyas, sin tener que decir «Nova» otra vez.
- **Sin modo ni frase para empezar:** Nova distingue sola orden, charla o las
  dos cosas en la misma frase.
- Cerebro **híbrido** y que gaste **poca RAM**.

**Hecho (13/09, noche):**
- [x] `charla_worker.py`: Qwen2.5 3B en local con Ollama (1,9 GB cargado;
      contexto de 1024, un solo modelo y una sola petición, caché de 8 bits;
      sale de la RAM a los 2 min sin hablar y al abrir un juego). Si no puede,
      la API de Claude (Haiku, con búsqueda web para noticias o precios); si la
      API falla (sin saldo), vuelve al local; si todo falla, el cerebro de siempre.
- [x] Contesta **frase a frase**: la primera suena en ~3 s (en frío, ~12 s
      mientras carga el modelo).
- [x] Reparto sin modo: lo que Nova sabe hacer se hace; lo que parece charla o
      pregunta va a la conversación; si el modelo ve que era algo que HACER,
      responde `[ORDEN]` y va al camino de las órdenes. Una frase mixta («qué
      hora es y cuéntame algo») hace la orden y conversa el resto.
- [x] Al acabar de contestar escucha sola ~7 s, y otra ventana si callas; las
      respuestas cortas («sí, claro») siguen la conversación. La charla se
      olvida tras 5 min sin hablar. La voz ajena se sigue descartando.
- [x] **Cerebro propio** (`charla_memoria.py`, pedido «con especial atención»):
      todo lo que responden Ollama y la API se aprende en `memoria\cerebro\`
      (fuera del repositorio) para no tener que volver a preguntarlo.
      - Lo de la API entra firme; lo del modelo local, **provisional**: solo
        sirve de pista («sin confirmar») hasta que la API lo revisa en segundo
        plano (y nunca mientras se habla). Si estaba mal, guarda lo correcto y
        Nova se corrige («por cierto, antes me equivoqué…»).
      - Responde de memoria (sin Ollama, ~0 s) solo si está firme, es la misma
        pregunta con el mismo interrogativo, no es personal ni caduca (hoy,
        precios, noticias) y no depende de lo hablado justo antes.
      - Busca por palabras (siempre) y por significado (`embeddinggemma`, 338 MB,
        cargado solo para cada consulta que no se encuentra por palabras).
      - De cada charla saca también datos sobre braya (van al perfil de siempre,
        con sus filtros), cómo le gusta que le hablen, sus temas, lo que cuenta
        y un recuerdo. Nada de datos sensibles; nada de un invitado.
      - «Eso no es verdad» rechaza lo último y pregunta a la API; «olvida lo de
        X» borra lo aprendido sobre X.
      - Probado de verdad: respuesta local → revisada por la API → firme → la
        segunda vez, de memoria en 2 s; «me encanta Hades» → dos datos al perfil.
- [ ] La clave `ANTHROPIC_API_KEY` venía con un salto de línea al final (la API
      no funcionaba en el worker; ya se limpia al leerla) y ha salido en claro
      en la sesión del 13/09: **revocarla y crear otra**.
- [ ] Ver con el uso real si el 3B se inventa datos demasiado (el de los pulpos
      salió mal dos veces) y si hace falta pasar más preguntas a la API.
- [x] «¿Qué has aprendido?» cuenta lo del cerebro propio (M1 de la quinta tanda).
- [ ] Si la RAM aprieta jugando: `qwen2.5:3b-instruct-q3_K_M` (~1,6 GB) o bajar
      la memoria reservada a la gráfica en Armoury Crate (hoy 8 de 16 GB).

## Tercera tanda de ideas (13/09, noche): hechas

- [x] **Modo de energía por voz:** «modo ahorro», «modo rendimiento», «modo
      equilibrado», «ahorra batería», «¿qué modo de energía tengo?» (el
      deslizador de Windows, no Armoury Crate).
- [x] **Bluetooth y Wi-Fi:** «apaga el bluetooth», «enciende el wifi» (WinRT).
      Apagar el Wi-Fi deja sin IA ni voz en línea, y lo dice.
- [x] **Salida de sonido:** «pon el sonido en los cascos», «vuelve a los
      altavoces», «¿por dónde suena?» (`nova_audio.cs`). Sin cascos conectados
      solo hay una salida y lo dice. **Probar con unos cascos.**
- [x] **Silencio en llamadas:** si otra app usa el micrófono (registro de
      privacidad de Windows), Nova no habla: texto y un pulso. **Probar en una
      llamada de Discord.**
- [x] **Tiempo de juego:** «¿cuánto he jugado esta semana / hoy / este mes?»
      (minutos por día en `memoria\juegos.json`).
- [x] **Aviso de actualización:** al abrir un juego de Steam con actualización
      pendiente, lo dice en la respuesta.
- [x] **La última captura:** «copia la última captura» (al portapapeles),
      «enséñame la última captura».
- [x] **Velocidad de la voz:** «habla más rápido / más despacio / normal»
      (voz en línea, de -30 % a +45 %, guardado en config).
- [x] **Vistazo:** acercar el ratón a la cápsula en reposo enseña la hora y la
      batería 2,5 s.
- [x] **Esconderse un rato:** «escóndete 10 minutos»; vuelve sola.
- [x] **Permisos del cerebro (G8):** bloqueado lo destructivo por decisión de
      braya (registro, procesos, PowerShell y archivos del MCP de Windows;
      borrar y matar procesos por terminal).

## Auditoría exhaustiva (13/09, noche)

Un agente probó Nova entera (arranque, activación, ~570 frases en el banco, 22
órdenes en vivo, cerebro, recetas, reglas, cápsula, robustez). Arreglado y
comprobado (banco completo en verde; G1-G6 probados en vivo donde se podía):

- **G1** Una excepción ya no apaga el asistente: red en el bucle principal, y
  `.Trim()` sobre una traducción vacía no revienta.
- **G2** «No me escuches» ya no se levanta al terminar de hablar (probado: la
  marca sigue a los 12 s; «escúchame» la quita).
- **G3** Un aviso o temporizador mientras dictas espera a que termines (probado:
  sonó justo al acabar el dictado, sin los 50 s congelado); empezar un dictado
  corta la voz y vuelve a escuchar.
- **G4** Las preguntas llevan su contenido: «¿Abro SILENT BREATH?» (era `$var?`).
- **G5** Los valores de una receta viajan en variables de entorno: una comilla
  tipográfica ya no cuela código.
- **G6** Una segunda copia sale antes de tocar `tmp\` (probado: 0 marcas borradas).
- **G7** Colisiones: «cierra steam y discord» / «cierra spotify, discord y steam»
  cierran todo; «quita el sonido a spotify» silencia; «baja spotify» y «sube el
  volumen de spotify» son el volumen de la app; «baja el volumen del todo» al
  mínimo; «pon el volumen/brillo a la mitad» al 50 %; «pausa spotify» pausa;
  «pasa la música» es siguiente; «quita/olvida el modo X» ya no lo borra;
  «bloquea a ese tío en discord» ya no bloquea.
- **G9** Un error de la cuenta tras usar herramientas no se repite con el respaldo.
- **M1** Recetas con «puedes/podrías…» se aprenden (se ajusta el primer verbo).
- **M2** Más verbos de orden: «cuenta…», «dime…» ya no se descartan como charla.
- **M3** «No era eso» tras una traducción apunta tu frase, no la orden normal.
- **M4** Ya no dice «True». **M5** «Cada 2 horas…» crea la regla. **M6** «Cierra la
  calculadora» funciona (CalculatorApp). **M7** El worker sale si el asistente
  muere, y al arrancar se paran los huérfanos. **M8** Tras 3 fallos del worker el
  botón dicta sin esperarle; el contador se rearma a los 5 min vivo. **M9** Un
  JSON ilegible (listas, traducciones, recetas, reglas) se aparta como
  `.corrupto-<fecha>` en vez de sobrescribirse. **M10** Plazo por modo (traducir
  25 s, preguntas 90 s) y el respaldo con opencode solo para tareas. **M13**
  Cancelar pone el progreso a cero.
- Leves: ganancia recordada que se descartaba en cada arranque; «quedan 2 minutos
  para se acabo el tiempo»; «deshaz» tocaba el brillo sin motivo; log de arranque
  que decía «opencode»; la cápsula releía gestos.txt cada 250 ms (CPU); «dime qué
  hora es», «no me escuches una hora», «hey nova pon modo juego», «pon un
  temporizador de 10 minutos», «apaga la música», «pon modo foco».

Queda abierto:
- [x] **G8: permisos del cerebro.** braya eligió bloquear lo destructivo (13/09):
      `$CcProhibido` quita al cerebro el registro, los procesos, PowerShell y el
      sistema de archivos del MCP de Windows, y los comandos de borrar, matar
      procesos o tocar el registro.
- [x] **M11 (14/09):** una receta con script ya no bloquea el bucle. El script
      corre aparte (`Start-PasoScript`), el bucle lo recoge (`Watch-Receta`) y
      al acabar pasa lo de siempre (`Complete-RecetaResultado`). Mientras
      corre, ≡ y la cápsula responden; otra receta no se empieza a la vez.
- [x] **M12 (14/09):** si «nova» salta con la voz de otra persona (tono a más de
      70 Hz del tuyo aprendido) y lo oído son 4 palabras o menos, el worker
      entrega lo de Vosk sin gastar Whisper. Con el botón o en un seguimiento,
      nunca. **Ver con el uso real** que no se salte órdenes tuyas.
- [x] Escrituras no atómicas en los JSON de memoria (14/09): `Write-Atomico`
      escribe un `.tmp` y lo cambia por el bueno de una vez (listas,
      estadísticas, config, commands, traducciones, rechazos, recetas,
      contactos, reglas, fechas y recordatorios).
- [x] Frases mal dirigidas (14/09): «graba un audio para mi madre» → nota de
      voz; «regresa a steam» → cambiar a Steam; «en youtube busca gatos» y «en
      youtube pon lofi» → YouTube (era la trampa de `$Matches`); «canción
      anterior» → anterior; «minimiza zorglub» → «no veo ninguna ventana»;
      «apaga / reinicia el ordenador» → local, con un sí y 30 s para cancelar.
      «Abre teams» → Steam **es a propósito**: el alias de `commands.json`
      corrige a Whisper, que oye «teams» cuando dices «steam».

## De la revisión del agente (13/09, tarde): arreglado

Un agente revisó las nueve ideas de la primera tanda. Todo arreglado:

1. **Grave:** una costumbre podía acabar en una regla peligrosa diaria. Lo
   confirmado ya no cuenta como costumbre, «cierra» y «todo» salen del filtro, y
   al aceptar una propuesta se valida la acción y se rechaza lo destructivo.
2. A/B del mando jugando: hace falta ≡ a la vez, y nunca mientras suena la
   pregunta. La pista dice «≡+Ⓐ sí · ≡+Ⓑ no» jugando y solo «Ⓑ no» si es peligrosa.
3. «Déjala ahí»: la tarjeta no se cierra hasta 5 s después de que Nova termine de
   leerla, ni mientras dictas.
4. El panel rápido ya no pisa «escuchando» ni una pregunta al cerrarse.
5. «Qué me dicen» ya no lee tus mensajes.
6. Una propuesta aceptada no se vuelve a proponer.
7. «Pon la música» / «para la música» miran si ya suena antes de pulsar.
8. La marca de «sin tarjeta» caduca a los 3 s.
9. Una lectura fallida de notificaciones no hace pasar lo viejo por nuevo; lo
   visto se poda.
10. La batería por juego sigue el tramo con Alt+Tab.
11. La música solo pregunta el título mientras suena, con tope de 1,5 s.
12. «Me quedé en…» solo con el juego delante o cerrado hace menos de 30 min, y
    no con «casa», «trabajo», «dormido»…
13. El destello de tormenta vuelve a la opacidad correcta del halo.
14. El nivel ya celebrado va a `memoria\habitos.json`, no a config.json.

## De la revisión del agente (12/09), lo que queda

Lo grave ya está arreglado (commit a693e80). Queda, por orden:

- [x] **La cápsula gastaba ~40 % de un núcleo en reposo; ahora ~15 %** (13/09).
      Medido quitando piezas de una en una (`NOVA_DIAG=mirar,latido,tic33,z,
      blur,sombras,efectos,transp`, que se queda en `nova_ui.cs` para volver a
      medir): el desenfoque, las sombras y la transparencia apenas cuentan. Lo
      caro era el **latido** (la respiración del punto, una animación sin fin
      que repintaba la ventana entera a 60 fps: 28 %) y la **mirada** (nunca
      llegaba del todo a su sitio y repintaba 15 veces por segundo: 8 %). El
      latido va ahora a 12 fps (`NOVA_LATIDO_FPS` para probar otro: 8 fps da
      12 %, 20 fps da 19 %) y la mirada se planta al llegar. Sin los dos,
      3,9 %. El halo de «pensando», también sin fin, va a 30 fps (una tarea del
      cerebro puede pensar minutos).
- [x] **Activaciones falsas que dejaban la escucha abierta 30 s** (13/09).
      El dictado se cierra vacío si en 8 s no sale ni una palabra (probado en
      vivo: 8 s). Lo del `pico 0.000` era engañoso: el log daba el pico del
      ÚLTIMO bloque, que al acabar la frase es silencio; el filtro por pico de
      ráfaga ya existía desde el 11/09. Ahora el log enseña los dos
      (`rafaga`). Queda mirar con el uso si siguen saliendo ~4/h.
- [x] **Oído fino fuera de plazo** (13/09): no repasa audios de más de 8 s, y
      si el asistente se rinde y quita la marca, corta entre segmentos.
- [x] **Micrófono muerto** (13/09): si pasan 5 s sin llegar un bloque, el
      worker sale y el asistente lo relanza (abre el micrófono de nuevo). No
      se ha podido provocar aquí; revisado a mano.
- [x] **Escrituras atómicas** (13/09): el worker escribe a `.tmp` y cambia de
      golpe; si el lector lo tiene abierto, escribe directo como antes.
- [x] Charla corta en inglés (13/09): de 3 a 6 palabras, si al menos la mitad
      son inglesas corrientes, ninguna española y no lleva el nombre de un
      juego («the last of us» sigue siendo orden). Casos en
      `tools\probar-funciones.ps1`.
- [x] «En qué me puedes ayudar» (13/09): el relleno quita «me puedes» y llegaba
      como «en que ayudar», sin el «me» que pedía el patrón.
- [x] «Guarda el archivo» (13/09): es Ctrl+S. «Guarda X» sigue minimizando
      apps («guarda discord»), pero no archivo/documento/cambios/trabajo.
- [x] `Close-PanelDictado` y TextInputHost (13/09, sin cambios): solo corre por
      el camino de Win+H (`Finish-Dictation` y el dictado largo con Win+H), que
      con Whisper no se usa. Cuando se usa, es lo único que cierra el panel
      seguro; Windows relanza el proceso al volver a hacer falta.
- [x] `RevisarPantalla` (13/09) mira ya los cuatro bordes del área útil. Sigue
      siendo solo la pantalla principal, que es donde vive la cápsula.

## Hechas (13/09/2026)

- **Claude Code como cerebro.** Lo que la capa local no entiende va a
  `claude -p` con la suscripción (Haiku para entender, Sonnet para preguntas y
  tareas con el MCP de Windows). La API y opencode quedan de respaldo, y una
  tarea que ya usó herramientas nunca se repite con el respaldo. Detalle en
  `ESTADO.txt`.
- **Autoaprendizaje: recetas.** Lo que el cerebro hace con herramientas se
  guarda como plantilla con huecos y pasos; la próxima vez Nova lo hace sola y
  sin IA (preguntando las 2 primeras veces). Nada destructivo entra nunca en
  una receta. Detalle en `ESTADO.txt`.
- **Que se note que aprende.** Cuando aprende algo (una tarea, otra forma de
  pedirla, algo que le enseñas o un dato tuyo) la cápsula da un saltito con
  chispas doradas; cuando hace sola una receta, sin IA, lo marca con dos
  latidos. Y «¿cuánto has aprendido?» / «¿cuánto me has ahorrado?» cuenta lo
  que sabe y el tiempo de espera que te ahorró esta semana (~20 s por uso).
- [x] Las pruebas del autoaprendizaje (13/09) ya pasan con `probar-todo`:
      `tools\probar-recetas.ps1`, 51 casos (recetas y su seguridad, coletilla,
      variantes, perfil, «cuánto has aprendido» y la celebración).
- [x] Los valores dictados de una receta (14/09, M7): Whisper apunta su
      seguridad (`dictado-confianza.txt`); si una receta con datos llega de un
      dictado dudoso (avg_logprob < -0,8, calibrado con las 20 grabaciones de
      `pruebas\audio`: pregunta en 9 de 20, todas mal oídas), Nova dice «Entendí: … ¿Es así?» antes
      de hacerla. Un «no» pide repetirlo sin castigar a la receta.
- [x] Diario de conversaciones (14/09, M10): cada charla del día se apunta en
      `memoria\cerebro\charla-<día>.jsonl`; al día siguiente, con Nova en reposo,
      el modelo LOCAL lo resume en 2-5 viñetas que van al diario de ese día
      (`## Lo que hablamos`) y el registro en bruto se borra. Nada de un invitado.

A partir del 14/09 braya prefiere **pulir lo que ya hay** antes que añadir
funciones nuevas.

## Hechas (12/09/2026)

- **5. Reglas sobre cualquier app.** «Cuando abra Spotify, baja el juego al
  40», «cuando cierre Discord, sube el volumen». Cualquier app de
  `commands.json`, además de los juegos. Si el nombre es exactamente una app
  gana la app; si no, se prueba como juego y luego como app por parecido. Un
  vigilante mira cada 3 s solo las apps que salen en alguna regla y dispara al
  CAMBIAR (al arrancar Nova no cuenta como "abrir" lo que ya estaba abierto).

- **6. Avisos relativos a una hora.** «Avísame diez minutos antes de las
  diez», «recuérdame media hora antes de las ocho que empieza la partida»,
  «mañana un cuarto de hora antes de las nueve y media». Si no dices qué, el
  aviso dice cuánto falta; si ya estás dentro del margen, lo dice; si no dices
  de qué hora, pregunta. De paso salieron dos fallos viejos: «a las 11:30» se
  leía como las 11 (la normalización cambia los dos puntos por un espacio), y
  «recuérdame EN VEINTE minutos…» acababa anotado en el diario porque el
  atajo solo apartaba los tiempos dichos con cifras.

- **8. Copia de seguridad de lo aprendido.** «Haz una copia de seguridad» o
  «haz un respaldo», y una sola al día sin pedirla. Zip con fecha en
  `copias\` (fuera de git): memoria entera, traducciones, reglas, modos y
  alias, config y la voz del dueño. Se guardan las 14 últimas.

- **11. Que se vea qué va a hacer, antes de hacerlo.** Un glifo en el hueco de
  la carita justo antes de cada acción que toca el sistema, sin añadir espera.
  Detalle en `ESTADO.txt`, sección de la cápsula.
- **14. El anillo del avatar como progreso de la descarga.** Y de paso salió
  que el aviso de "ya se descargó" no había funcionado nunca: una variable
  declarada dos veces y compartida por dos usos con claves distintas.
- **4. «¿Cómo va todo?»** Un solo parte con las seis cosas que importan antes
  de una partida, y callando lo que no aporta. Se prueba de verdad (lo que
  dice, no solo que la frase se reconozca) con `tools\probar-parte.ps1`.
- **9. Que solo te obedezca a ti.** Si una orden que toca algo llega con una
  voz que no se parece a la tuya, pregunta en vez de hacerla. Con guardas
  anchas para no molestar: hace falta medida de tono, una voz dueña clara y
  más de 35 Hz de diferencia. `tools\probar-voz-dueno.ps1`.
- **15. Tamaño a petición.** «Hazte más grande» / «más pequeña» / «tamaño
  normal», en escalones del 75 al 200 %, recordado como la esquina.
- **7. Teclas repetidas para menús.** «Abajo tres veces», «atrás», «dale a la
  a». Flechas de verdad, y números dichos con palabras. De paso salió que el
  banco no veía las colisiones entre órdenes parecidas: ahora hay
  `pruebas\destinos.txt` y `tools\probar-destinos.ps1`.
- **2. Ventanas de una app por su nombre.** «Minimiza Spotify», «manda Discord
  al otro monitor», sin ponerla delante y sin robarle el foco a nadie. Lo de
  mover entre monitores no se ha podido probar de verdad: en esta máquina solo
  hay una pantalla, y lo que sí se comprobó es que lo dice en vez de moverla.
- **17. Avisos sin voz.** Con un juego delante, en sordina o en modo silencio,
  los avisos se ven (tres pulsos de color en el borde, cada cosa con el suyo)
  en vez de hablarte encima. `tools\probar-avisos.ps1`.
- **1. Dictado largo.** «Dicta un correo» y todo lo que digas se escribe en la
  ventana de delante, con puntuación, «borra lo último» y «cambia X por Y».
  Tres salidas (la frase, el botón y un plazo). **Falta que lo pruebes tú con
  una ventana delante**: ver arriba.
- **13. Cola visible.** Una fila de puntos cuando la orden lleva más de una
  cosa: el actual encendido, los hechos apagados, el que falla en rojo.
- **10. «¿Qué he hecho hoy?»** Junta en una frase lo que ya se guardaba
  suelto: a qué jugaste, qué apuntaste, cuántas órdenes diste y cuántas veces
  se despertó para nada.
- **3. Listas de verdad.** Se añade, se lee, se tacha y se vacía (preguntando
  antes). En `memoria\listas.json`. `tools\probar-listas.ps1`.
- **Las 20 grabaciones, hechas y explotadas.** De 7 de 20 a 17 de 20 con el
  mismo audio. Destapó cuatro fallos que llevaban meses ahí y que el banco de
  texto no podía ver, todos por los números dichos con palabras. Detalle en
  `ESTADO.txt`, sección "PROBAR CON TU VOZ".
- **El dictado, medido otra vez (14/09).** Con las mismas 20 grabaciones:
  base con 8 hilos en vez de 4 acierta igual y tarda 1,7 s por orden en vez de
  2,0, y el oído fino baja de ~6 s a ~4,8 s. Beam 1 pierde aciertos y meter
  palabras de órdenes en las hotwords no mejora nada fuera del ruido (±1 entre
  pasadas). Cuatro correcciones más en `commands.json` («brille», «bril», «seguidame»,
  «seguedame»), que es lo que small sigue oyendo. La prueba de audio contaba
  «qué hora es» como fallo si cambiaba el minuto; ya no.
- **Pulido de lo que ya había, diez cosas (14/09):**
  1. *Repaso de lo dudoso aunque se entienda:* si Whisper traía una seguridad
     por debajo de −0,9 (`input.repasoDudoso`) y la frase es una orden, se repasa
     con small antes de hacerla; si el repaso no trae otra orden, se hace la
     primera. Las órdenes bien oídas de las grabaciones van de −0,73 para arriba.
  2. *Whisper repite:* «cierra el discord, cierra el discord» se hace una vez.
     Las de dar pasos («sube el volumen, sube el volumen») se siguen repitiendo.
  3. *Cuarenta grabaciones:* 20 frases más en `tools\grabar-ordenes.py`, dos de
     charla (acierto = no hacer nada). **Te toca grabarlas:**
     `python tools\grabar-ordenes.py nuevas` (solo graba las que faltan).
  4. *Lo que base casi acierta:* «si arra» → cierra, «medio de ahora» → media
     hora, «bolumen» y cinco formas de «sube volumen»; «pon el juego 80» sin «al».
  5. *Arranque:* medido, 0,45 s en leer el script y ~1 s hasta estar activo. No
     hay nada que ganar ahí; no se tocó.
  6. *RAM jugando:* con un juego delante y 5 min sin usarse, el oído fino
     (~500 MB) se suelta; si hace falta se recarga en ~3 s.
  7. *Charla en frío:* la primera frase tardó 19 s (7,8 s son cargar el modelo).
     Ahora, si lo que vas diciendo ya suena a charla, empieza a cargar mientras
     terminas de hablar (no jugando).
  8. *Por qué muere la cápsula:* apunta sus errores en `tmp\ui-error.log` y el
     log dice el código de salida y el último error.
  9. *Cerebro:* ya caducaba lo provisional a los 30 días; en uso real aún no hay
     nada aprendido que revisar. Sin cambios.
  10. *La voz con tildes:* el código escribe «entendi», «bateria», «cancion» y
      la voz puede acentuar mal; `Add-TildesVoz` las pone antes de hablar y en lo
      que enseña la cápsula (solo palabras sin otra lectura). **Sin oírlo aún:**
      a la voz le llega el texto corregido (lo dice el código), pero falta
      escuchar si ahora acentúa bien.
  - *Fallo encontrado de paso:* «qué opinas de Hollow Knight», «Hollow Knight es
    difícil» o «te gusta Steam» ABRÍAN el juego o la app (la regla del nombre
    suelto buscaba el título dentro de la frase). Ahora van a la conversación.
    «Haz una captura» no se entendía.
- **Segunda tanda de pulido (14/09):**
  1. *Charla en frío:* el prompt de sistema (322 tokens) tardaba 6,9 s en leerse
     en frío. Recortarlo se midió y EMPEORA las marcas ([ORDEN]/[API] 15 de 20
     frente a 20 de 20), así que se queda. Lo que se hizo: lo fijo va delante y
     lo que cambia (perfil, contexto, juego) al final, y la precarga lee esa parte
     fija. Tras precargar, la primera frase llega en 2,2 s en vez de 13,9 s.
  2. *La pausa de la escucha* mientras Nova habla usaba la cuenta de letras
     (70 ms + 1,2 s) y la duración real solo podía alargarla; ahora también la
     acorta (~0,7 s menos sorda por frase). La sordina no se toca.
  3. *Los fallos del banco:* 3 de 5 son controles a propósito. «abrir el steam
     y en una segunda ventana buscar pinterest» se arregló («en otra ventana /
     pestaña» se ignora). «Freelesign en el navegador buscal Pinterest» es audio
     destrozado: se deja.
  4. *El ruido que pasa (3 de 97):* dos títulos sueltos, que al ejecutarse
     preguntan antes («¿SILENT BREATH?»), y «adiós», que se despide. Sin cambios.
  5. *Lo que se abrió sin verbo en el log:* «sí», «es», «el» y los catálogos
     recitados ya no disparan nada con los filtros de hoy. Sin cambios.
  6. *La voz ya no se corta a mitad de palabra* a las 300 letras: corta en el
     último punto (o espacio).
  7. *Rellenos de la charla:* ocho en vez de tres y nunca el mismo seguido.
  8. *Lo que vas diciendo en la cápsula* se corta por palabras, no por letras.
  9. *`tmp\ui-error.log`:* aún no existe (la cápsula no ha fallado desde que se
     añadió). Revisarlo tras unos días.
  10. **Te toca con la voz:** la guarda del repaso dudoso, la precarga al hablar
      y soltar el oído fino jugando no se pueden probar con órdenes escritas.
- **Tercera tanda de pulido (14/09):**
  1. *Datos inventados:* con 10 preguntas sobre juegos, el modelo local se
     equivoca en casi todas («Hades es de terror», «Peak es de estrategia») y
     pedírselo en el prompt no lo arregla. Las preguntas de datos concretos
     (quién hizo, de qué va, háblame de, qué opinas de…) van a la API, sin
     búsqueda; lo que contesta se aprende firme.
  2. *Chino y etiquetas:* 0 de 20 respuestas con chino; `limpiar` ya quita las
     etiquetas entre corchetes. Sin cambios.
  3. *La barra de espera* de la charla se ajusta: 5 s si el modelo está caliente
     o recién precargado, 16 s si no.
  4. *Cerrar antes la frase:* esperaba 1,4 s de silencio. Si la orden ya se
     entiende entera (`tmp\lotengo.txt`, con el texto exacto), bastan 0,8 s. En
     las 20 grabaciones la pausa más larga dentro de una orden es de 0,45 s.
     **Sin probar con voz.**
  5. *La voz que se cae* ya no congela el bucle 2 s (Piper, 2,5 s) al relanzarla.
  6. *El oído fino compensa:* 17 repasos, 12 sirvieron, 4 igual, 1 inventado.
  7. *Falsos «nova»:* 246 activaciones; la confianza no separa las útiles de
     las que acaban en nada (1,0: 19 órdenes y 47 descartes). Sin cambios.
  8. `tools\probar-precarga.py`: la medición de la precarga, para lanzarla a mano.
  9. `ESTADO.txt` al día con todo lo del 14/09.
  10. *Piper:* recibía el texto en la codificación de la consola y destrozaba
      las tildes («batera est»). Ahora va en UTF-8. Con `--debug` se ve que con
      tildes acentúa bien y sin ellas no («baTEria», «ESta»).
- **Cuarta tanda de pulido (14/09):**
  1. *Caracteres invisibles:* en `tools\probar-regex.ps1` y `TRASPASO.md` había
     un retroceso (0x08) donde iba `\b`, en comentarios y en un aviso: no rompía
     ninguna comprobación, pero el texto decía otra cosa. Arreglado.
  2. *Lo que la API contesta se aprende:* «quién hizo», «de qué va», «háblame de»
     y «qué sabes de» cuentan ya como preguntas generales (antes solo se
     aprendían «qué es», «quién fue»…). Una opinión («qué opinas de») NO: no se
     guarda como dato para repetir.
  3. *Sin API, los datos concretos no los inventa el local:* se midió con un
     aviso concreto en el prompt y siguió inventando («Goose Goose Duck es una
     película de Disney de 1999»). Ahora el worker los devuelve (`delegar`) y
     van al cerebro de preguntas (Claude Code).
  4. *Voz preparada:* una frase nueva tarda ~1 s en sintetizarse y una hecha
     2 ms. Un segundo worker de voz prepara las frases de la charla en cuanto
     llegan, así no hay ~1 s de hueco entre frase y frase.
  5. *«Lo tengo» cada 200 ms:* medido, la capa local tarda ~109 ms por frase;
     comprobar tan a menudo bloquearía el bucle mientras hablas. Se queda en
     400 ms.
  6. *Caché de voz:* ya reutilizaba cada frase (clave: voz, ritmo, tono y
     texto). Sin cambios.
  7. *Cuándo se cierra la frase* es ya una función (`silencio_para_cerrar`) con
     su prueba sin micrófono: `tools\probar-escucha.py`, dentro de probar-todo.
  8. **Te toca:** grabar las 20 frases nuevas; con 40 se recalibra el umbral
     del repaso dudoso y las correcciones.
  9. *ESTADO.txt:* la cabecera decía «EJECUTANDO AHORA: SÍ» del 12/09.
  10. *Correcciones con riesgo* («estima», «programan», «navegado», «team»):
      probadas en frases normales, ninguna acaba en una orden. La clave «estín»
      (con tilde) no podía coincidir nunca: ahora es «estin».
  - *Dos fallos que salieron en la prueba en vivo de esta tanda:*
    - **Nova se interrumpía a sí misma.** Las 3 interrupciones del log fueron
      falsas («cállate» con confianza 1,00 y 0,98, «silencio» 0,95), en charlas
      sin nadie hablando: con gramática cerrada, su voz por el altavoz sonaba a
      una palabra de corte, y cortaba la charla tras la primera frase. La
      confianza no lo separa; el tono sí: braya va de 111 a 126 Hz (sus 20
      grabaciones) y Nova de 165 a 327. La palabra solo vale si el tono del
      trozo donde se oyó está a 40 Hz del tuyo. **Pruébalo:** di «cállate»
      mientras habla. Un grito muy agudo podría no valer; queda el botón.
      Probado en vivo: descartó «basta» (211 Hz, su voz), pero se coló un
      «espera» con tono 0 (no medible). Ahora el trozo es de ±0,4 s y, con tu
      tono ya aprendido, una palabra sin tono medible no corta.
    - «Háblame un poco de Hollow Knight» iba al modelo local («un poco» rompía
      el patrón). En vivo, «quién hizo Hollow Knight» ya fue a la API: «Team
      Cherry», en 1,7 s.
- **Quinta tanda de pulido (14/09):**
  1. *RAM de Nova, medida en vivo* (`tools\probar-vivo.ps1`): 730 MB en reposo y
     869 MB en charla. Escucha (Vosk + Whisper base) ~290 MB, PowerShell ~200,
     cápsula ~140, cada worker de voz ~50. Lo que ahoga la Ally no es Nova: es el
     modelo local de charla (~1,9 GB) cuando se carga. Sin más recortes.
  2. *La voz preparada se cierra* tras 3 min sin charla.
  3. *El banco completo* se salta la sección de audio (avisando) con menos de
     1,5 GB libres: antes el sistema llegó a matarlo a medias.
  4. *Primera frase antes:* si la primera frase de la charla pasa de ~90 letras
     sin punto, sale por su última coma.
  5. *Precargar la charla al decir «nova»:* medido, NO. Mientras Ollama precarga,
     Whisper tarda 2,23 s por orden en vez de 1,63 (+36 %) y la precarga dura
     15 s: frenaría todas las órdenes. Se queda solo cuando lo que dices ya suena
     a charla.
  6. *La corrección del cerebro* («por cierto, antes me equivoqué») ya tenía su
     prueba en probar-memoria; en vivo depende de que el local se equivoque.
  7. *El corte al gritar* se calibra con las 100 grabaciones (abajo).
  8. *Voz preparada, en vivo:* 3 frases seguidas y las 3 llegaron ya hechas. El
     log dice ahora «voz: frase ya preparada / sintetizada al momento».
  9. *`assistant.log` se rota:* pasados 5 MB, al arrancar se guarda como
     `assistant.log.1`.
  10. `tools\probar-vivo.ps1`: arranca Nova de verdad, prueba orden local,
      opinión, charla larga y dato concreto, fotografía la RAM y la para,
      devolviendo memoria y config. Si se corta: `-Restaurar`.

## Las 100 grabaciones: lo que enseñaron (14/09)

Grabadas el 14/09 de 19:12 a 19:22 (317 s de voz). Primer análisis
(`pruebas\audio\cien\informe-antes.md`): **Nova entendía 38 de 66 órdenes** (58 %),
cuando con las 20 de antes parecían 17 de 20. Veinte frases no enseñaban esto.

- **Whisper se iba al inglés y a recitar nombres** («Everything», «King is a
  Hollow Knight», «Outlast 3, Goose Duck»): la culpa era de las hotwords (la lista
  de apps y juegos). Medido con las 90 grabaciones de orden, charla y nombre:
  | configuración | como el asistente | base solo (órdenes) |
  |---|---|---|
  | hotwords (lo de antes) | 63 de 90 | 28 de 78 |
  | sin hotwords, audio normalizado | 62 | 30 |
  | frase neutra en español | 64-73 | 28 |
  | **frase de ejemplo con órdenes** | **74 de 90** | **43 de 78** |

  El riesgo de la frase inicial (que continúe la frase con ruido y se invente una
  orden, lo que pasó el 11/09 con la lista de nombres) **se midió**: 108 trozos de
  ruido (71 del cuarto, 30 de la voz de Nova, 7 sintéticos) y ninguna orden con la
  frase de ejemplo; con las hotwords, la voz de Nova diciendo «¿Abro Hollow
  Knight?» sí acababa en abrirlo. Aplicado: `PROMPT_ORDENES` en wake_vosk.py, y
  probar-audio y analizar-100 la leen de ahí.
- **Pausas:** dentro de una orden llegaste a 0,81 s (con 20 parecía 0,45) y con
  pausas a propósito a 1,44 s. El cierre rápido pasa de 0,8 a **1,1 s** y el
  normal de 1,4 a **1,5 s**.
- **Corte por tono:** gritando «basta» llegaste a 37 Hz de tu tono normal; el
  margen pasa de 40 a **42 Hz**. Vosk reconoce las 10 palabras de corte con
  confianza 1,00.
- **Repaso dudoso:** hay órdenes mal oídas con tanta seguridad como las buenas;
  el umbral no las separa. Sin cambios.
- **Capa local:** «pon el brillo de/del 30» bajaba el brillo; «pon el brillo» a
  secas también. «King is a Hollow Knight» preguntaba si abrirlo (ahora el nombre
  suelto rechaza frases con palabras inglesas). Correcciones: abresteam,
  abresting, trinta, subelbrio, suelbrio, subvolumen, sting.
- **Lo que sigue flojo:** voz baja (5 de 10) y desde lejos (3 de 6), con picos de
  0,29-0,33 frente a 0,81 en tono normal.
- **Con todo aplicado** (segundo análisis, 20:18): órdenes 52 de 66 (antes 38),
  con «nova» delante 6 de 6 (antes 3), charla 12 de 12, voz baja 8 de 10, fuerte
  10 de 10, desde lejos 4 de 6. En total **74 de 90 (82 %)**, antes 55 (61 %).
  Base tarda 0,78 s por frase (antes 0,97).
- **El efecto secundario de la frase de ejemplo:** con voz poco clara, base a veces
  devuelve su propio ejemplo («pausa» en voz baja -> «Baja el volumen»; «cuánta
  batería queda» desde lejos -> «¿Qué hora es?»). La escucha marca ese eco y, con
  seguridad por debajo de −0,5 (`input.repasoEco`), el oído fino tiene que
  confirmarlo; si no, «no te entendí» y nada. Medido: de 3 órdenes equivocadas
  queda 1, sin perder aciertos, y solo 5 de 90 órdenes buenas esperan el repaso.
- **La frase de ejemplo, sin números** (tercer experimento, 110 grabaciones: las
  90 + las 20 antiguas). Con «al treinta» dentro, «pon el juego al ochenta» se oyó
  «al treinta»: se haría con otro número sin avisar.
  | frase | como el asistente | otra orden | número cambiado | ruido |
  |---|---|---|---|---|
  | con «al treinta» | 92 de 110 | 2 | 1 | 0 |
  | **sin números** | **92 de 110** | 2 | **0** | 0 |
  | con un juego | 91 de 110 | 3 | 0 | 1 |

  Queda la sin números: «Nova, abre Steam. Sube el volumen. Pon el modo noche.
  ¿Qué hora es? Baja el brillo.» La del juego se inventaba «Abre Little
  Nightmares III». Precio de no dar nombres: los títulos largos («little
  nightmares tres») se entienden peor; queda como tarea.
- **META DESDE EL 14/09: que Nova te entienda siempre.** No se avanza en nada más
  hasta llegar. Medido así: 100 % en tus tandas de grabaciones y **cero órdenes
  equivocadas** (si duda, que pida repetir). El informe de analizar-100 lo da.
- **Tanda dirigida (64 frases, `python tools\grabar-100.py dirigida`):** 12
  títulos de juegos, las 10 que seguían fallando, 10 en voz baja, 10 desde lejos,
  8 deprisa, 4 con números, 4 de charla y 6 con tele o música sin hablar. Las 64
  pasadas por la capa local: todas válidas.
- **Mientras se graba (sin cargar la CPU):**
  - Lo mal oído en las 100 que se rescata sin riesgo: miniminista, descagando /
    escagando, «cancel el temporizado», rubando, «espacio me quedo», quanto,
    mollofoco, «se cuéntame» / seguéltame, «littlenimer3», «iron imer». 21 de 24.
    Se quitó «aquí estoy jugando»: es una frase normal y encajaba en otras.
  - «pon el volumen / el brillo 70», sin «al», ya se pone (solo con «pon»).
  - **«Silencio», «cállate», «basta», «para»** mientras Nova habla o en los 6 s
    siguientes la callan; antes silenciaban el PC.
  - Los títulos de juegos: «LittleNimer3» o «iron Imer» no se parecen a
    «Little Nightmares» ni por sonido; se espera a los 12 títulos grabados para
    ver si hace falta algo general.
  - **Los workers con pythonw.exe** (si existe): con python.exe cada uno abría
    su conhost.exe (3-5 procesos, ~40 MB). Falta comprobarlo en vivo.
  - `tools\probar-vivo.ps1 -Piper`: la misma prueba con la voz sin conexión
    (config.json se devuelve al acabar). `-Jugando`: pide que abras un juego y
    comprueba solo botón, respuesta de una frase y que no precarga la charla. Un
    juego no se puede fingir: Nova mira la ventana de delante.
  - **La cápsula (~140 MB):** medida con cada pieza apagada (NOVA_DIAG), no baja
    de 133-143 MB: es la base de .NET/WPF, no las animaciones. Los efectos solo
    cuestan CPU (3,5 s -> 2,1 s en 8 s sin ellos). Sin cambios: no se toca el
    diseño.
  - Pendiente de la tanda: subir el volumen de la voz floja antes de Whisper
    (el experimento está escrito y usa también la tanda dirigida).
- **Tanda dirigida, grabada el 14/09 (23:17-23:24):** 35 de 64 (55 %), con 2
  órdenes equivocadas. Voz baja 11 de 13, charla 4 de 4, tele y música 6 de 6
  (no se hizo nada), deprisa 4 de 9, normal 7 de 20 (casi todo títulos de
  juegos) y **desde lejos 3 de 12** (pico 0,38). Lo que se arregló por ella:
  - **Las 2 equivocadas eran de la lógica, no del oído:** «pon modo noche»
    desde lejos se oyó bien pero, al ser la frase de ejemplo, el repaso oyó
    «¿Qué hora es?» (otra frase de ejemplo) y se hizo la hora: **un eco ya no
    confirma a otro eco**. «Cierra steam» se oyó «¡Siempre Steam!» y abría Steam:
    **sin verbo, cada palabra tiene que ser del nombre** (o parecérsele mucho).
  - **Juegos por cómo suenan** (`Find-JuegoPorSonido`): el título pasado a cómo
    lo dice alguien que habla español y comparado por sonido. Con todo lo que
    oyó Whisper: 13 frases acaban en su juego, 0 en otro juego y 0 frases
    normales en un juego. Solo detrás de «abre…» y siempre preguntando antes.
  - «aure» / «aura» -> abre; «al ochente», «Abésame», «Aguete ruando»,
    «meni meni sato», «temporizables»; y «pon el juego **el** 30».
  - En marcha: si subir el volumen de la voz floja rescata «desde lejos».
- **Ronda del 15/09 (con un agente para las correcciones):**
  - Tanda dirigida reanalizada con todo: **44 de 64 (69 %), 0 órdenes
    equivocadas** (antes 35 y 2). Desde lejos sigue en 3 de 12.
  - Subir el volumen de la voz floja antes de Whisper: 64 -> 65 de 83 (dentro
    del ±1). No se aplica.
  - Juego por sonido también sin verbo, con umbral 0,85 («Ahora gus gus dup»,
    donde «ahora» se borra como muletilla): 0 falsos en 786 frases.
  - Correcciones del agente: se quedan las deformaciones que se repiten (bofsa,
    aufza, pauza, miniminiza, gus gus dup, se respodify, gato hendito). **Se
    quitaron 14 que eran la transcripción exacta de una sola grabación**: subían
    la nota de estas grabaciones pero en directo Whisper no oirá nunca lo mismo.
  - **Cuidado con la cifra:** todo se ajustó mirando `cien` y `dirigida`, así que
    medir con ellas es aprenderse el examen. La cifra honesta sale de la tanda
    `validacion` (60 frases que no se usan para ajustar nada).
  - **Whisper large-v3-turbo como último recurso** (cuando base y small no dan
    ninguna orden), con 36 grabaciones que fallaban, 15 de control y 45 trozos de
    ruido: rescata **19 de 36** (normal 10 de 12, voz baja 3 de 4, lejos solo 2
    de 11), no rompe ninguna de control y 0 órdenes con ruido. La única orden
    equivocada fue un eco de la frase de ejemplo («¿Qué hora es?»), que la guarda
    del eco ya frena. Precio: **~12 s por frase** en la Ally, 34 s la primera
    carga y ~1 GB de RAM mientras está cargado. **Decisión de braya: sí, pero no
    jugando.** Montado así: la escucha acepta un tercer modelo
    (`input.whisperModeloUltimo`, por defecto large-v3-turbo; vacío lo apaga), que
    se carga solo al pedirlo, suelta small antes de cargar y se suelta a los 2 min
    sin uso o en cuanto hay un juego delante. El asistente lo pide
    (`Request-UltimoRecurso`) cuando base y small no sacan una orden o no
    confirman un eco; nunca jugando, ni con lo que parece charla, una vez por
    orden y con 60 s de plazo. Lo que traiga pasa la guarda del eco: una frase de
    ejemplo solo vale si coincide con lo que oyó base (dos modelos que oyen lo
    mismo sí se confirman). **Sin probar con voz.**
  - **NVIDIA Parakeet TDT 0.6B v3** (sherpa-onnx, int8, CPU), medido con las 214
    grabaciones de orden, charla y ruido de las tres tandas y 101 trozos de ruido,
    con la capa local de hoy:
    | estrategia | cien | dirigida | validación | total | equivocadas | s/orden |
    |---|---|---|---|---|---|---|
    | Whisper como hoy | 86/90 | 48/64 | 54/60 | 188/214 | 1 | 3,9 |
    | Parakeet solo | 65/90 | 35/64 | 29/60 | 129/214 | 0 | 0,6 |
    | Parakeet y, si no, small | 85/90 | 44/64 | 38/60 | 167/214 | 0 | 2,2 |
    | **Parakeet y, si no, Whisper como hoy** | **88/90** | **52/64** | **55/60** | **195/214** | **0** | **3,2** |

    Parakeet solo entiende menos (voz baja 14 de 31, lejos 4 de 26), pero es muy
    rápido y **nunca hace una orden equivocada**: no lleva frase de ejemplo que se
    cuele. Ruido: 0 órdenes. La combinación acierta más, 0 equivocadas y tarda
    menos. Se monta como oído principal. (Dirigida no tiene turbo simulado.)
  - **Montado (15/09): Parakeet primero.** La escucha pasa el audio por Parakeet
    y lo entrega marcado (`tmp\dictado-motor.txt`). Si el asistente lo entiende
    como orden, la hace; si no, pide «base» y Whisper repasa el mismo audio, que
    sigue el camino de siempre (repaso con small, eco, turbo, charla). Con un
    juego delante, sin el modelo o sin voz, todo va por Whisper como antes, y
    jugando Parakeet se suelta de la RAM (~0,7-1 GB con él cargado).
  - **Validación con el circuito entero:** 54 de 60 (90 %), 1 «equivocada» sin
    peligro (con música, small oyó «¿Qué tal?» y Nova dijo «Hola. Dime.»).
    Parakeet sacó 21 órdenes en 0,5 s, ninguna equivocada; turbo aportó 6.
    Ojo: la validación ya se usó para corregir, así que **hace falta otra tanda
    nueva** para una medida limpia.
  - Parakeet detecta el idioma él solo: en la prueba oyó «abre steam» como
    «What's the thing». Al no ser una orden, pasa a Whisper y no hace daño.
  - **Sin probar con voz** (con órdenes escritas no se pasa por la escucha).
  - whisper.cpp con la gráfica AMD (Vulkan): sin medir todavía.
- **PRIMERA PRUEBA EN VIVO (15/09, 10:12-10:26): mucho peor que las tandas.**
  Cuatro órdenes dichas («abre spotify», «sube el volumen», «qué hora es», «pon
  modo noche») y **4 órdenes equivocadas**: abrió Steam dos veces por «abre
  spotify» (Whisper devolvió su frase de ejemplo; la segunda vez, «Abra Steam»,
  ni se marcó como eco), abrió Xbox (Parakeet sacó «el Xbox» de una frase larga)
  y puso el volumen al 35 y bajó el brillo (con casi silencio tras una respuesta,
  Whisper recitó la frase de ejemplo entera). Además se aprendió «ensectiva el
  modo noche» = «modo noche», lo contrario de lo dicho (borrado; copia en tmp).
  Nova se paró a las 10:26.
  - **Por qué:** con los WAV capturados en vivo (`guardar-audio.txt`) se
    descartó la ganancia (recortar las grabaciones a x6,8 no cambia nada), el
    silencio alrededor (recortarlo no arregla a Parakeet; meter las grabaciones
    entre silencio real no las rompe) y el micrófono (el mismo, MME). Lo que
    cambia es cómo hablas: **dando órdenes hablas más rápido y cortado que
    leyendo** («abre spotify» 0,7 s en vivo, 1,2 s grabado). Las tandas medían
    tu voz leyendo. Parakeet en vivo contesta en inglés o ruso a las órdenes
    cortas; las frases largas las entiende perfectas.
  - **Lento:** al pulsar ≡ se precargaba qwen2.5:3b (2 GB): 0,3 GB libres y
    Whisper de 4,5 a 12,9 s por orden (la primera, 29 s). Y la escucha llegó a
    tirar 34 s de audio mientras repasaba (sin arreglar: el bucle es de un hilo).
  - **Medido y descartado:** que un eco del ejemplo solo valga si lo confirma un
    oído SIN frase de ejemplo (Parakeet o small sin ella) pierde 14 aciertos en
    las 214 grabaciones y no quita ninguna equivocada en vivo. Small sin frase
    de ejemplo oye fatal («Subtítulos en español de la comunidad de Amara.org»).
    **El eco de «abre Steam» sigue sin resolver**: no se distingue de un «abre
    steam» de verdad ni por seguridad ni por el repaso.
  - **Arreglado (banco entero en orden, mismas cifras que antes):**
    - Parakeet no manda si lo que saca no cubre la voz (4 letras por segundo de
      voz; la orden buena más baja tuvo 6,2, el Xbox 1,5; 0 aciertos perdidos).
    - Dos o más frases distintas de la frase de ejemplo son un recitado: no se
      hace nada (en las 214 grabaciones pasó 2 veces y ninguna era una orden).
      Prueba nueva: `tools\probar-recitado.ps1`.
    - No se precarga la charla sin 3 GB libres (`conversacion.precargaRamMinMB`).
    - Lo que necesitó repaso no se aprende (ni traducción ni alias), y si el
      modelo lo traduce a una orden, **se pregunta con un sí hablado**.
    - Tras turbo sin orden, se sigue con el texto de turbo si se parece (la
      charla contestaba a «la distancia del solo de la tierra»).
    - Spotify no está instalado en este PC: por eso «abrir spotify» fallaba.
  - **Sesión de uso real (propuesta de braya):** `escucha.grabarUso = true`
    guarda cada orden en `pruebas\audio\uso\` (WAV + `registro.jsonl` con lo
    que oyó cada modelo). Lo siguiente es analizarlo cruzándolo con
    assistant.log por la hora, y probar otras frases de ejemplo con esas
    grabaciones para el eco de «abre Steam».
- **LA SESIÓN DE USO REAL (15/09, 11:16-11:48, 40 órdenes).** braya: «es muy lento,
  a veces no hace lo que le digo, y cuando lo hace se demora muchísimo».
  Cruzando `pruebas\audio\uso\registro.jsonl` con assistant.log:
  - **Lo lento no era el oído:** claude-code tardaba 8-11 s en entender una frase
    (Haiku) y 35-90 s en una tarea (Sonnet): «pon un temporizador de cinco
    minutos» 81 s, «reproduce el segundo video de YouTube» 148 s. Antes pasaba por
    base, small y turbo (15-28 s más). La charla, 10-22 s hasta la primera frase:
    hablaba primero qwen y la API solo si qwen se apartaba con [API].
  - Parakeet oye bien las frases largas, pero no mejor que base (24 % de palabras
    mal frente a 20 %, con small de referencia en las 40): **no se salta Whisper**.
  - La escucha se cayó una vez (access violation con small y turbo cargados) y
    turbo se pidió en bucle sin audio. Sin arreglar.
  - Spotify no está instalado: «abrir spotify» falla con el error de Windows.
- **Reparto nuevo (elegido por braya el 15/09):** capa local + API de Anthropic
  para charla y órdenes, memoria local de lo que contesta la API, Claude Code solo
  para tareas pesadas, y de respaldo qwen2.5:1.5b (sin internet), opencode y
  Whisper. Montado:
  - `Submit-Command`: traducir y preguntar, API → Claude Code → opencode; las
    tareas (TAREA), Claude Code → opencode. Si la API falla, lo rehace Claude Code.
  - `charla_worker.py`: la API primero; qwen solo si la API no está o falla, y ya
    no se precarga con API. embeddinggemma sigue para buscar en la memoria.
  - Medido: entender una frase 0,8-1,7 s; una pregunta 3,4-5,3 s (Opus 5) o 2,3 s
    (Haiku); «qué ves en mi pantalla» 5,8 s con la captura a la API
    (`claude-api.ps1 -Imagen`, reducida a 1280 px en JPEG), antes 87 s.
  - **El prompt de traducir** solo conocía una parte de lo que Nova sabe hacer y
    marcaba «cierra la calculadora y cierra steam» como NO y el temporizador como
    TAREA. Ahora lleva todas las formas, cada una comprobada con la capa local, y
    varias órdenes por línea (se juntan con « y »). Con las 40 frases de uso: solo
    «reproduce el segundo video» sale TAREA.
  - **Tras cada «No te entendí» vuelve a escuchar sola** (como mucho dos seguidas).
  - Pruebas: `probar-charla.py` adaptada al orden nuevo; `probar-recetas.ps1` pasa.
  - **Sigue mal:** si Whisper oye mal, la API también se equivoca («podría cerrar el
    navegador» oído «podría ser el navegador» → «abre navegador»).
  - **Medido y descartado: la API como reparadora del oído.** En las 202 grabaciones,
    55 frases sin orden local. Con turbo guardado (14 de validación): turbo 6 bien y
    0 equivocadas; la API con el texto de base 1 y 4; la API con lo que oyeron
    Parakeet, base y small, 3 y 5. En las 55, la API con los tres rescata 6 y **se
    inventa 13 órdenes** («qué hora es» con la tele, «abre steam» por «cierra steam»,
    «abre edge» por «sube el brillo»). **Turbo se queda.** Lo que protege de la
    traducción de algo mal oído es la pregunta con sí hablado (TRADUCCION DE ALGO
    MAL OIDO), no la API.
  - **Turbo no cabe con todo lo demás:** cargarlo tumbó dos veces la medición por
    falta de memoria, y el 15/09 la escucha se cayó con él cargado. Arreglado el
    bucle que lo pedía una y otra vez (UN REPASO QUE SE QUEDA SIN DUENO: un dictado
    nuevo abandona el repaso pendiente; turbo una vez por frase y nunca con el
    repaso vacío). Sin probar con voz.
- **SEGUNDA SESIÓN DE USO (15/09, 13:08-13:21, 26 órdenes).** braya: «ya me aburrí
  de que no me entienda». Lo rápido ya funcionaba (la charla empieza en 1,3-1,7 s,
  traducir 2-3 s), pero:
  - **Parakeet oía bien y se seguía con lo que oía peor.** «Ahora por favor abre
    youtube y reproduce música de Pitbull» → base «abre y duro y reproducente en
    música de Pipboon»; «que pongan música en YouTube» → «muzigen» (y se aprendió:
    borrado); «borra eso» → «baja eso». En 27 frases de uso donde no coincidían,
    Parakeet acertó claramente en ~16 y base solo en 3 órdenes cortas que base sí
    entiende. **Arreglado:** si Whisper saca orden, vale Whisper; si no, se sigue
    con Parakeet cuando es una frase en español de 4+ palabras (`Test-EspanolLargo`).
    El repaso con small se mantiene: oye el audio y en las 202 grabaciones rescata
    2 órdenes que Parakeet oyó mal.
  - **«No me suena tu voz» con su propia voz:** al quejarse subió a 155, 153 y
    179 Hz (su tono, 116). **Arreglado:** con el botón o en la escucha de seguimiento
    no se desconfía de la voz; tras el nombre, margen de 42 Hz (su grito medido).
  - **La charla se disculpaba en vez de abrir Steam** tres veces seguidas.
    **Arreglado:** `[ORDEN]` también con quejas; con la API real, 3 de 4 quejas sueltas
    y la cuarta con la conversación delante.
  - **La escucha se cayó otra vez** (13:12, comtypes Release): el medidor de
    altavoces se creaba con `ctypes.cast`, sin reservar el objeto, y se liberaba dos
    veces. **Arreglado** con `QueryInterface` (20 creados y soltados sin caerse). Era
    también la caída de la mañana, no turbo.
  - «¿Qué hora es? ¿Qué hora es» (la misma frase de ejemplo dos veces) ahora también
    es un recitado.
  - «pon un temporizador de <n> minutos»: la traducción con huecos se hacía nada;
    ahora se quita lo que lleva hueco y se hace el resto.
  - «Abre YouTube y reproduce Pitbull» se perdió: se leyó el archivo del dictado
    vacío en el mismo segundo. Ahora se mira una segunda vez (causa sin confirmar).
  - **La marca al final:** con la conversación delante, la API contestaba «Tienes
    toda la razón. Voy a hacerlo ahora. [ORDEN]»; solo se miraba el principio y la
    marca se borraba. Ahora `[ORDEN]` cuenta en cualquier parte. Con la API real:
    3 de 3 quejas acaban en orden.
  - **La reescritura de órdenes** («recuérdamelo luego») la hacía qwen, que con 1.5B
    se inventó «Abre Steam y inicia sesión, luego inicia una nueva partida». Ahora la
    hace la API («Pero la idea es que lo abras…» → «Abre Steam.») y el local solo sin
    API. Ojo: `RE_DEIXIS` también caza «solo» u «hola»; con la API solo cuesta ~0,7 s.
- **TERCERA SESIÓN DE USO (15/09, 14:05-14:41, 24 órdenes).** Ya casi todo se oye
  bien (Parakeet, base y small coinciden); lo que falla es qué hace y cuánto tarda:
  - **Turbo apagado en uso real** (`input.whisperModeloUltimo = ""`). Hoy se pidió 25
    veces y rescató UNA orden (y dudosa); se cargó 14 veces (hasta 55,6 s). Con él la
    escucha llegó a 1.961 MB con 1 GB libre: Whisper tardó 41,7 s en 1,2 s de audio,
    Parakeet 72 s en 0,5 s, «dictado sin respuesta del worker» y 80 s de audio tirado.
    Con las grabaciones leídas turbo rescataba 6 de 14, pero manda el uso real.
  - **Sin repaso si Parakeet y Whisper oyen lo mismo** (parecido ≥ 0,9, 3+ palabras):
    en uso real el repaso sacó orden en 0 de 24; en las grabaciones, 1 («abre
    otras», de 2 palabras, que se sigue repasando). Quita 30-47 s a «revisa mi
    correo» o «puedes reproducir esta canción».
  - **YouTube pone el vídeo**, no solo lo busca: el primer videoId de la página de
    resultados, sin clave (antes, queja y 83 s de agente). Si falla, la búsqueda.
  - **«Gracias» fuera del seguimiento** contesta «De nada» (era «No te entendí»).
  - **La charla marca [ORDEN]** también para lo que Nova puede mirar («¿en cuánto está
    la descarga de Steam?» contestaba «no veo la descarga desde aquí»).
- **CUARTA SESIÓN DE USO (15/09, 14:57-15:14, 16 órdenes, jugando a It Takes Two).**
  Sin cuelgues ni caídas (turbo apagado). YouTube puso el vídeo. Pero:
  - **El repaso bueno se tiraba como «invento»:** jugando, Parakeet se suelta y base
    oyó basura; small oyó bien y, al no compartir palabras, se descartaba. Medido en
    las 202 grabaciones: ese descarte tiraba 16 órdenes correctas y frenaba 2
    equivocadas (inofensivas). **Arreglado:** si el repaso trae una orden clara y no es
    el eco de la frase de ejemplo, vale aunque no se parezca.
  - **La autosordina se calló 10 min** con tres «no te entendí» que eran él
    contestándole. **Arreglado:** no cuenta lo que llega por botón o seguimiento.
  - **Small pisaba a Parakeet:** «mueve It Takes Two a la carpeta Games» → «state 2» y
    48 s de agente. **Arreglado:** si se siguió con Parakeet y small tampoco saca orden,
    vale Parakeet.
  - **«Cierra el navegador» tardaba 20 s:** 1,5 s de espera por cada proceso sin
    ventana. **Arreglado:** una sola espera para todos.
  - **«El juego que estoy jugando / que está en pantalla / este juego»** se cambia por el
    juego que tiene delante (buscaba la frase tal cual).
  - Queda: jugando no hay Parakeet (es a propósito, la RAM es del juego) y base oye
    peor con el juego sonando.
- **QUINTA SESIÓN DE USO (15/09, 15:29-15:45, 45 órdenes).** Ya casi todo se oye
  bien. braya pidió además quitar la tarjeta y revisar la memoria:
  - **«Se corta y deja de hablar, y sale un toast con todo»:** la voz se recortaba
    a 300 letras (`Get-TextoVoz`) y el resto solo salía en la tarjeta. Ahora la voz
    dice hasta 1.200 letras con más plazo y **no hay tarjeta nunca**, solo la cápsula.
  - **La memoria:** no se borró nada (las copias no tenían recetas antes de hoy).
    Las tareas del agente se aprenden como receta solo si se pueden repetir igual; lo
    que da información (el correo, qué hay en el escritorio) o depende de la pantalla
    vuelve al agente cada vez, por diseño. Lo que sí estaba mal: se aprendieron
    traducciones malas («abre la carpeta Games» = «abre explorador», «busca Clem??n»,
    frases de 15 palabras). Borradas, y ya no se aprende una frase de más de 6
    palabras ni una traducción que pierde un nombre propio.
  - **La receta de la nota** escribía siempre en `Hola.txt`; ahora el archivo se
    llama como lo que se dice.
  - **Tildes rotas en todo lo de la API** (preguntas y traducciones): se leía como
    Latin-1 y se escribía en la codificación de la consola. `claude-api.ps1`
    decodifica los bytes en UTF-8 y escribe en UTF-8 (también en `-SalidaArchivo`).
    Comprobado byte a byte por el camino del asistente: «Clem C3 AD n». Ojo al
    probarlo: un .ps1 sin BOM con tildes dentro se lee como ANSI y las rompe él
    mismo, y la consola de PowerShell las pinta mal aunque el archivo esté bien.
  - «Activa el Bluetooth» encendía el wifi (`$Matches` machacado). Arreglado.
  - «Describe mi fondo de pantalla» se corregía a «escribe» y **tecleaba** el texto.
    Arreglado; y «qué ves en pantalla» ya no atrapa órdenes como «abre el juego que
    tengo en pantalla», que ahora lee la pantalla y abre ese juego de la biblioteca.
  - **Abrir una carpeta por su nombre** («abre la carpeta Games»), clima con más
    formas («cuál es el clima para hoy») y «entiendo, gracias» → «De nada».
  - Sin hacer: recetas para tareas de información (leer el correo cada vez sin agente).
- **¿1000 grabaciones más?** Todavía no: con estas 100 ya se ve qué falla y se
  mide cada arreglo. Lo que falla ahora son frases concretas (modo noche/foco,
  «minimiza todo», «qué se está descargando», «cancela el temporizador») y la voz
  baja o lejana: mejor una tanda corta y dirigida a eso que 1000 al azar.

## Las 100 grabaciones: cómo se hicieron

Para ajustar con datos tuyos y no a ojo el margen del corte por tono, el umbral
del repaso dudoso, el cierre rápido de la frase, las correcciones y el volumen.

1. **Apaga Nova** (usa el mismo micrófono y el mismo botón).
2. `python tools\grabar-100.py`. Pantalla completa: arriba la frase, debajo el
   **tono** (normal, voz baja, fuerte, gritando, deprisa, despacio, desde lejos,
   con pausas, cansado, animado).
   - **≡** empieza a grabar; **≡** otra vez para, guarda y pasa a la siguiente.
     Tómate el tiempo que quieras entre una y otra.
   - **B** vuelve a la anterior para repetirla. Teclado: Enter = ≡, R = repetir,
     Esc = salir. Se puede dejar a medias: al volver sigue por donde iba.
   - Son 66 órdenes, 12 frases de charla, 10 palabras para cortarla («cállate»,
     «espera»… normal y gritando), 6 con pausas y 6 con «nova» delante.
3. Al terminar, con Nova apagada: `python tools\analizar-100.py` (~10 min). Deja
   `pruebas\audio\cien\informe.md` con los aciertos por tono y una recomendación
   para cada ajuste. Las 100 frases ya se pasaron por la capa local: todas las
   órdenes tienen su acción y ninguna de charla dispara nada.
    - «Quién hizo Hollow Knight» preguntaba «¿Abro Hollow Knight?», y «dime quién
      hizo Outlast» lo repetía en voz alta. Ahora las dos van a la conversación.
- **El fallo rojo del banco.** «Se pone siempre encima» llevaba días en rojo y
  era de la prueba, no del asistente: sobre una ventana que nunca se ha
  mostrado, `SetWindowPos(HWND_TOPMOST)` devuelve true sin marcar nada. El
  banco pasa entero por primera vez.

## Por dónde empezar

Si hay que elegir: la **10** («¿qué he hecho hoy?»), que junta datos que ya se
guardan y que no recoge nadie. Después la **8** (copia de seguridad de lo
aprendido), que es barata y es lo único que protege meses de ajustes de un
JSON corrupto — y ahora hay una cosa más que proteger, las listas.

---

## Trampas de esta base de código (leer antes de tocar)

Están todas contadas en los commits, pero por si acaso:

- `$Matches` se pisa con CUALQUIER `-match` posterior. Copiar los grupos a
  variables en la línea siguiente, siempre.
- Los patrones de un `switch -regex` no pasaban por el probador hasta el
  12/09. Ya sí (`tools\probar-regex.ps1`, que también mira las herramientas).
  Un `\l` inválido no rompe un patrón: rompe el `switch` entero y se caen cien
  órdenes de golpe.
- Escribir parches con heredocs se come las barras dobles: `\b` acaba siendo un
  BACKSPACE y `\a` un BELL, invisibles al leer. Mejor escribir el script de
  parche a un archivo, o usar `chr(92)`.
- `Repair-Verb` arregla el verbo de cabeza por parecido ANTES de que llegue a
  ningún patrón: «ponte» llega como «ponme». Si una orden con verbo no encaja,
  mirar eso primero.
- El banco (`-Probar`) comprueba la FORMA de la frase, no que la acción llegue
  a hacerse. Para reglas y cosas que escriben archivos, hace falta prueba
  aparte (hay ejemplos en `tools\probar-*.ps1`).
- `config.json` va SIN BOM: lo leen también los workers de Python, en crudo.
- Hay ATAJOS en `Process-Texto`, antes de todos los patrones: "apunta ...",
  "recuerda ...", "crea el modo ...". El banco de `-Probar` NO pasa por ahí,
  así que una orden puede decir en el banco que va a un sitio y en vivo acabar
  en otro. Pasó el 12/09 con las listas: el banco decía "apuntar pan" y en vivo
  se archivaba en el diario. Si algo se comporta distinto en vivo que en el
  banco, mirar esos atajos primero.
- Scripts de prueba escritos con un heredoc de bash: `\\` se queda en `\`. Un
  filtro como `'voice-ctrl\\assistant\.ps1'` acaba siendo `\a` (un BELL) y no
  encuentra nada, así que la parada decía «quedan vivos: 0» con el asistente
  encendido (13/09, dos veces). Para parar el asistente de una prueba: guardar
  el PID de `Start-Process -PassThru`, parar sus hijos por `ParentProcessId` y
  comprobar después desde PowerShell, no desde el heredoc.

---

## NOVA SE ENTERA DE LO QUE PASA (plan de braya, 16/09)

Quiere que Nova reaccione a su entorno: al coger la consola, al pasar algo. Pidió 30
ideas y aprobó las 30, más poder crearlas hablando («cuando pase X, haz Y»).

**Fase 0 (hecha el 16/09): el motor.** No añade ningún comportamiento; monta el freno
de mano, que es lo que hace que 30 avisos no sean insoportables:
`Test-PuedoAvisar` / `Send-AvisoEntorno` con tope por hora (4), silencio total mientras
juega salvo lo crítico, horas tranquilas (23-8), cada aviso una vez por su plazo, los
de nivel bajo sin voz (solo cápsula), nada con invitado delante ni mientras habla o
espera un sí, y «no me avises de nada» / «vuelve a avisarme».
APAGADO por defecto: `config.json` → `entorno.avisos`.

**Fase 1 (hecha el 16/09): lo que ya tenía sensores.** Ninguno hubo que inventarlo:
todos esos flancos ya se detectaban y lo único que faltaba era que Nova dijera algo.
dock (2, 3), cascos (4, 5), cerrar un juego (9), descarga terminada (24), disco bajo
(25), batería y cargador (7, 13, 14, 15).

**Fase 2 (hecha el 16/09).** Lo mejor fue descubrir cuánto ya existía:
- [x] 1 y 17: el parte de la mañana y el resumen al volver ya estaban escritos, pero
      colgaban de que braya hablara primero (se preparaban dentro de `Process-Texto`).
      Ahora `Watch-Entorno` los llama desde el bucle y salen solos.
- [x] 6: coger la consola. El bucle ya lee los cuatro mandos; si aparecen botones tras
      90 minutos quietos, saluda y ofrece seguir con el último juego.
- [x] 26: Gmail lleno, una vez por semana (`entorno.gmailLleno`).
- [x] 30: resumen semanal, los domingos por la tarde, con `Get-BalanceAprendizaje`.
- [x] 27 y 28: YA ESTABAN, y mejor de lo que las habría escrito. `Find-Propuesta` mira
      tres patrones (misma orden a la misma hora, orden tras abrir una app, tres
      seguidas), nunca propone jugando, una al día y con lista de rechazadas.
- [x] 19 (cuánto llevas hoy): se cayó de esta tanda porque me inventé una función que
      no existía (`Get-TiempoJuegoHoy`). Hecha en la fase 3, llevando la cuenta de
      minutos POR DÍA al cerrar cada juego, que es cuando se sabe lo que duró.

**Idea 31 (nueva, del propio braya el 16/09): el disco de los juegos va y viene.**
Conecta un disco externo (E:, «Extreme SSD») con 10 juegos más y lo quita. Se vio en
vivo: por la mañana Nova indexaba 16 juegos y por la tarde 26. Hasta ahora la
biblioteca solo se refrescaba cuando alguien preguntaba por un juego, así que con el
disco fuera «abre Elden Ring» intentaría abrir algo que ya no está. Hecho: `Watch-Entorno`
compara las unidades listas cada 30 s y, si cambian, reindexa y lo dice.

- [ ] Pendiente menor: «abre spider man» se va al modelo porque el título empieza por
      «Marvel's». Con «marvels spider man» sí encaja en local.

**Fase 3 (hecha el 16/09): 10, 11, 16, 19, 20 y 23.** La 8 (mensajes importantes
jugando) ya existía y ya pasaba por el freno, así que no hubo nada que tocar.
- [x] 23: dos avisos seguidos se dicen en UNA frase. La primera versión estaba MAL: le
      pegaba al aviso nuevo el texto del anterior… que ya había sonado, o sea que lo
      repetía en voz alta. Lo que se junta es solo la VOZ: el aviso se apunta y se ve al
      momento, pero se dice unos segundos después con los que caigan. Lo crítico no hace
      cola y además va primero.
- [x] 11: al abrir un juego con actualización o descarga a medias en Steam (StateFlags
      distinto de 4), lo dice ANTES de que el juego no arranque.
- [x] 10: el aviso de las 2 horas jugando pasa por el freno de mano como todo lo demás.
- [x] 19 y 20: minutos de juego por día, apuntados al cerrar. La madrugada cuenta como
      el día anterior y se guardan 30 días. OJO: los hábitos se guardan campo a campo,
      así que `minutosJuego` hubo que añadirlo a `Get-Habitos` Y a `Save-Habitos`; si no,
      se pierde en el primer guardado (la misma trampa que tuvieron las recetas).
- [x] 16: avisa si un juego gasta batería mucho más rápido que SU propia media, no que
      un número inventado, y solo con tres muestras de historial.

**Fase 4 (hecha el 17/09): 18, 22 y 29.** Las tres devuelven la frase (o cadena vacía)
sin hacer nada, y el vigilante decide si se dice: así el banco puede probarlas sin que
Nova hable.
- [x] Nivel de aviso nuevo, `noche`. EL AVISO QUE SE CALLABA A SÍ MISMO: el freno
      silencia de noche todo lo que no sea `alto`, así que un «vete a dormir» a las 2 de
      la madrugada no habría salido nunca; y ponerlo `alto` es peor, porque lo crítico
      suena jugando y se salta el tope. `noche` se salta el silencio nocturno y nada más.
- [x] 18: la hora de dormir es LA TUYA. No un sermón a las 23:00 clavadas: solo si a esa
      hora no sueles estar levantado (menos de 3 días de los últimos 14), el mismo
      criterio que ya usaba la precarga de la charla.
- [x] 22: el correo de la mañana, una vez al día. `Invoke-CorreoScript` ESPERA a que el
      script termine (hasta 25 s): llamarlo desde el bucle dejaría a Nova congelada y
      sorda ese rato, así que se lanza y se recoge en otra vuelta, como la nube.
- [x] 29: avisa si hoy falla mucho más que SU media de la semana.

**Crear estas cosas hablando (hecho el 17/09).** Al cruzar los datos salió que los 13
disparadores que se podían pedir hablando eran EXACTAMENTE los 13 que ya existían: el
hueco eran los sensores nuevos de las fases 1-4, que solo avisaban. Ahora hay cinco más:
`dockQuita`, `cascosQuita`, `bateriaLlena`, `discoJuegos` y `mandoCoge` («cuando quite el
dock, pon el modo batería», «cuando coja el mando, pon el modo juego»…).
- Cada tipo nuevo tiene que estar en CINCO sitios o falla en silencio: el patrón (no se
  crea), el switch de «avísame» a secas (nace muerta, porque `avisa` no es ejecutable),
  `Describe-Regla` («qué reglas tengo» recitaría el nombre técnico), el switch de
  `Invoke-Reglas` (se guarda y no dispara jamás) y el sensor.
- OJO CON EL ORDEN, y lo cazó el banco: «cuando termine de cargar» lo capturaba antes la
  regla de cerrar un juego («cuando termine X»), que tomaba «de cargar» como nombre de
  juego. Va delante, igual que ya le pasó a la de descargas.
- El mando dispara con 5 minutos quieto, no con los 90 del saludo: hablar cansa, pero
  «pon el modo juego» no.

Con esto el plan del entorno está terminado: las 31 ideas y poder crearlas hablando.

## 17/09: se activaba sola y no le oía (era el MISMO fallo)

braya: «se está activando sola más de lo normal, y no me entiende bien cuando le digo
nova, o sea nunca se activa literalmente, pero sí lo hace sola a veces sin yo hablarle».

`wake_vosk.py` descartaba cualquier ganancia guardada por debajo de x1.5 y arrancaba en
x8, con el argumento de que «la voz entra a 0.02-0.05 y hace falta amplificar entre x8 y
x26». Eso era cierto con el micrófono de entonces. Con el de ahora su voz entra a p90
0.47-0.99 con x0.7 (muy por encima de `PICO_OBJETIVO`, 0.35): su ganancia correcta ES
baja, así que la regla se cumplía SIEMPRE y además sobrescribía el archivo.

Medido en el log: la calibración buena se ha tirado **38 veces**, dos solo el 16/09
(x1.1 → x8.0 a las 19:55 y x0.8 → x8.0 a las 21:48). Arrancando a x8, el ruido de fondo
basta para activarla sola —6 de las 13 activaciones de ese día tienen **pico 0.000**, y
todas caen durante el descenso desde x8 (x3.6, x2.9, x2.7, x2.1), que dura minutos
porque bajar es lento a propósito (factor 0.2)—, y mientras tanto la voz de verdad
satura («recorte detectado: bajando ganancia a x1.0»). Un solo fallo, sus dos quejas.

**POR QUÉ IMPORTA ANOTARLO: ya figuraba como arreglado.** Está en la auditoría del 13/09,
en «Leves: ganancia recordada que se descartaba en cada arranque». Lo que se hizo
entonces no fue quitar la regla, sino SOBRESCRIBIR el archivo con x8 para que el descarte
no se repitiera en cada arranque; es decir, se consolidó el x8 y el fallo quedó vivo tres
días más. Ahora no puede volver: `probar-escucha.py` comprueba sobre el texto de
`wake_vosk.py` que no queda el descarte ni ninguna regla que compare la guardada con un
mínimo, y deja escrito con sus números por qué su ganancia correcta es menor que x1.

Arrancar desde lo guardado es seguro: el pulso recalcula la ganancia DESDE CERO
(`PICO_OBJETIVO` / pico crudo) en cuanto hay voz sostenida y para subir es rápido.

Dos cosas más que salieron tirando de este hilo:
- [x] **Un banco no puede cambiar de color según la hora.** `probar-entorno.ps1` fijaba
      la franja de noche real (23-8), así que pasarlo de madrugada bloqueaba todos los
      avisos normales —lo correcto— y salían 12 casos MAL sin nada roto. Y peor: «nivel
      bajo: sin voz» seguía en verde, porque con todo bloqueado se cumple solo. Era un OK
      falso. Ahora la franja se pone lejos de la hora actual y los casos que van de horas
      la fijan ellos.
- [x] **«Solo 471 MB libres» era MEMORIA, no disco.** El aviso que salta la prueba con su
      voz decía «MB libres» sin decir de qué (`FreePhysicalMemory`); el disco tenía 116 GB.
      Con Nova cerrada quedaron 1791 MB y la prueba corrió por fin: **20 de 20 (100 %)**,
      con el oído fino rescatando las 2 que falló el modelo rápido.

## 17/09: ¿el oído fino ayuda o estorba? MEDIDO: se queda

Uno de los «medir en uso real» que llevaban días abiertos. Con las 188 órdenes reales
grabadas: el oído fino interviene en 125 y en 100 oye algo DISTINTO. La pregunta era si
ese cambio mejora o empeora, porque cuesta ~4,8 s por orden.

Método (repetible): de `registro.jsonl` se sacan los pares «antes → después» (el campo
`entregado` es lo que se entregó antes del repaso; el `texto` de la línea del repaso es
lo de después), y se pasan los dos por el resolvedor local con `assistant.ps1 -Probar`.
Lo que se compara no es si suena mejor, sino si Nova **reconoce la orden**.

    en local:  antes 8 de 100   ->   después 19 de 100

- **rescata 18** («Abre St» → «Abre Steam», «Cierra la aplicación de Xbook» → «Xbox»,
  «I go like a gun to say anything» → «¿Hay algo descargándose en Steam»)
- **estropea 7**, y varias ya eran basura en ambos lados. Las que duelen de verdad son de
  puntuación: «Sí, hazlo ahora en el escritorio» → «Si hazlo ahora en el escritorio», y
  «describir mi fondo de pantalla» con mayúsculas de más.
- 73 seguían sin entenderse en los dos casos.

**Conclusión: se queda.** Rescata más del doble de lo que estropea. Pero el hallazgo
gordo es ese 73: el oído fino se gasta sobre todo en audio que nunca fue una orden
(charla, ruido, frases a medias), no en órdenes mal oídas. Ahí está el ahorro, no en
quitarlo.

- [ ] Siguiente: mirar si se puede saltar el repaso cuando lo oído no se parece a una
      orden ni de lejos (las 73), y recuperar esas 7 normalizando puntuación y mayúsculas
      antes de comparar.

## 16/09: el perfil, limpio y con filtro

Tenía 26 líneas y solo cuatro decían algo cierto: ocho variantes contradictorias sobre
música electrónica, cuatro sobre el apodo «Bull» (que salió de oírle mal), tres quejas
sobre Nova convertidas en rasgo suyo y varias vacías («tiene juegos»). Todo eso viajaba
con CADA petición al cerebro.

- [x] No se guarda lo que habla de Nova, lo que viene de una queja ni lo que es una
      deducción; del mismo tema solo queda una línea. El solapamiento se mira en los
      dos sentidos: calcular solo qué parte de la frase nueva está en la vieja castiga
      a las frases largas, que son las que más ruido meten.
- [x] La instrucción del cerebro pide solo lo que braya afirma de sí mismo, y callar
      en la duda.
- [x] Perfil limpiado a 4 líneas comprobables. El anterior, en `tmp\perfil.md.bak-16sep`.

## 16/09: entender mejor (bloque 1 de 4), primera tanda

Sale del análisis de las cinco sesiones de uso real del 15/09
(`scratchpad\analisis\errores.md`): de 141 órdenes, solo 49 salieron bien. De
las 116 con problema, **solo 17 eran del oído**; el resto era qué hace Nova con
una frase que oyó bien. Por eso se empieza por entender, no por el oído.

Hecho y comprobado con el banco (88/89, 183/186, ruido 3/97, destinos en verde):

- «cierra todo» **cierra** (con la confirmación de siempre) en vez de mostrar el
  escritorio. Se dijo 5 veces el 15/09 y siempre quería cerrar.
- **El verbo de cabeza se normaliza a imperativo** (poner→pon, pone→pon,
  reproducir→reproduce, cerrar→cierra…). Cada regla enumeraba sus propias formas,
  así que «poner un temporizador de cinco minutos» y «reproducir lofi en youtube»
  se iban al modelo (34 s) mientras «pon…» tardaba 2 s. Un solo sitio, todas las
  reglas arregladas.
- Temporizador con «para/por» y números en palabras.
- La fecha con palabras delante («cuál es la fecha de hoy», «quiero saber qué día es hoy»).
- Descargas: «hay algo descargándose en Steam», «revisa ahora si algo se está descargando».
- Espacio: «qué espacio tengo disponible».
- «cierra google/youtube/gmail» cierra el navegador (antes la API lo traducía como «Abre Google»).
- «corta los últimos 30 segundos de juego» (antes, 41 s de agente).
- «abre el teclado» (teclado en pantalla) y «escribir X» en infinitivo.
- «qué tengo en mi escritorio», en local (antes 44 s de agente).
- «qué tienes anotado sobre mí» y «qué has aprendido hoy».
- Ya no se anota una PREGUNTA: «¿recuerdas cuál es mi música preferida?» se
  guardaba como nota. Las tres copias de esa regla quedan iguales.
- «lo que dije fue que…» ya no se toma por una consulta a la memoria: era una corrección.

Queda del bloque 1 (por orden de impacto medido):

- [x] **Las quejas rehacen la orden** (19 casos, evitaba ~16). HECHO el 16/09:
      `Get-OrdenCorregida` + un paso en `Process-Texto` antes que nada, con
      `$script:ultimaOrden` (solo lo de los últimos 3 minutos) y una sola vuelta
      (`$script:corrigiendo`). Si lo que sale no es una orden que Nova sepa hacer,
      no se hace nada: la frase sigue a la charla como siempre. Probado en
      `tools\probar-correccion.ps1` con texto exacto, porque la primera versión
      daba por buenas frases pegadas («la hora dije cierra steam»).
- [x] La charla no tiene los datos de Nova (10 casos). HECHO el 16/09:
      `Get-DatosNova` manda con cada frase la hora, la fecha, el clima, las
      descargas de Steam, los temporizadores puestos (sin los internos), el nivel,
      lo último que hizo y el juego abierto; el worker los pone delante del modelo
      (`texto_datos`) y se le dice que nunca conteste que no puede saberlos.
- [x] Confusiones que quedan: «¿recuerdas…?» a la memoria y «ábrelo» con el juego
      que nombró el agente (16/09); **modo por voz** (16/09): «en modo juego no abras
      Discord» cambia el modo de verdad, en vez de guardarse como nota en el diario.
      Se analiza en `Resolve-ModoPorVoz` (sin tocar nada, porque `Resolve-Fragment`
      se usa también para validar órdenes) y se aplica en `Invoke-ModoEditar` desde el
      ejecutor. No se mete en un modo algo que Nova no sepa hacer, ni se deja un modo
      vacío. Lo de «la parte que no entendí» queda descartado (ver más abajo).
- [ ] Vigilante de la escucha: YA EXISTÍA (se comprueba cada 30 s, se relanza hasta
      3 veces, se rearma si aguanta 5 minutos y, si se agota, avisa en voz alta de que
      sigue el botón). No había nada que hacer.
- [x] Traducciones que invierten el verbo o inventan un nombre. HECHO el 16/09:
      `Test-TraduccionOpuesta` y `Test-NombreInventado` se comprueban ANTES de
      ejecutar lo que propone la API; si la da la vuelta («cierra Google» → «Abre
      Google») o mete un juego que no nombraste, no se hace nada y se pide repetir.
      También «ábrelo» apunta ya al juego que nombró la respuesta del agente.
- [x] Reproducir el vídeo o la canción número N (16/09) e instalar un juego (16/09):
      «instala X» abre su ficha en la tienda de Steam, porque la biblioteca de Nova
      son los appmanifest del disco (solo los instalados) y de uno que no lo está no
      hay identificador para un `steam://install`. Si ya lo tienes, te lo dice. Ojo:
      el parecido no vale aquí (Silksong no es Hollow Knight, Outlast Trials no es
      Outlast); se exige el mismo nombre.
- [x] «No era una orden» ya no te deja sin respuesta (16/09): si es español claro,
      largo y con tu voz, va a la charla en vez de callarse. Para el ruido de un
      vídeo, todo sigue igual (banco de ruido: 3 de 97).

Bloque 2 (oído), empezado el 16/09:

- [x] Filtro de eco en el repaso. El agente midió que las 4 órdenes equivocadas
      graves del camino actual salían del repaso («sube el volumen» → «¿Qué hora
      es?»). La escucha SÍ marcaba el eco, pero el asistente solo miraba esa marca
      en una de las ramas; ahora también en la que acepta un repaso parecido, y
      además se comprueba el texto con `Test-EsFraseEjemplo` (una sola frase).
- [x] Gemini flash-lite como segunda opinión con tope. HECHO el 16/09, pero
      APAGADO: se enciende con `config.json` -> `escucha.nubeOir = "gemini"` (tope en
      `escucha.nubeTopeMs`, 2,5 s) y reiniciando Nova. Cuando Parakeet no saca una
      orden se piden dos cosas a la vez: el repaso de Whisper y una segunda opinión a
      Gemini con el audio de `tmp\ultima-orden.wav`. Solo se usa si contesta a tiempo,
      si ni Parakeet ni Whisper sacaron nada, y si trae una orden que Nova sabe hacer
      (nunca la frase de ejemplo ni un juego que no nombraste). La clave vive en la
      variable de entorno GEMINI_API_KEY, no en el repositorio.
- [x] ENCENDIDO el 16/09 a petición de braya (`escucha.nubeOir = "gemini"`), tras
      ver que entiende más órdenes y baja la espera media de 5,7 s a 4,2 s.
- [ ] Medir en uso real cuántas veces llega dentro del tope de 2,5 s.

Bloque 3 (aprender de todo), fase 1 empezada el 16/09:

- [x] Un paso de receta puede LEER y decir lo que encuentra: tipo `lectura`, su
      salida en `$script:ultimaSalidaPaso` (antes solo se guardaba el ERROR del
      script, por eso una receta no podía dar información), `Test-ScriptSoloLectura`
      con lista blanca (no lista negra) y `Format-VozInfo` para pasar del JSON a la
      frase, con singular/plural y frase propia cuando no hay nada.
- [x] Recetas de información completas (16/09): se aprenden (con paso de lectura
      validado y plantilla de voz obligatoria), se ejecutan sin bloquear y dicen el
      dato. El agente YA tiene permiso para aprenderlas (`$CcInstruccionReceta` nueva),
      y cuando dice que no, dice el motivo (pantalla, contenido, externo, destructivo,
      inseguro, charla), que queda en el log y en las estadísticas.
- [x] «Reproduce el segundo vídeo de YouTube» y «la tercera canción», en local: se
      coge el vídeo número N de la misma página de resultados y se recuerda la última
      búsqueda. Sin búsqueda previa, avisa en vez de abrir algo al azar.
- [ ] NO se hará: avisar de «la parte que no entendí» de una frase compuesta. Al
      revisarlo, la regla ya es «todo o nada» (si un trozo no se reconoce, la frase
      entera va al modelo). Los dos casos del 15/09 eran otra cosa: «abre el navegador
      con Pinterest» (orden mal resuelta, arreglada) y «pon el brillo al 70 y ahora es
      Tin» (frase cortada por el dictado). Un aviso genérico daría falsas alarmas.
- [x] Sembradas al arrancar: descargas, documentos y clips (de 1 receta a 4).
- [x] Una receta `info` se ejecuta sin preguntar (solo lee, no cambia nada).
- [ ] Confirmación diferida a los 60 s (queda para la fase 2).

Bloque 4 (tareas sin Claude Code), empezado el 16/09:

- [x] EL PLAN. Cuando la API dice TAREA, antes de llamar al agente (35-90 s) se le
      pide que descomponga la petición en órdenes del vocabulario local, una por
      línea. Se comprueban TODAS con `Test-FastCommand` antes de hacer ninguna; si
      una sola no encaja, no se hace nada y la tarea va al agente como siempre. La
      API no ejecuta nada: solo propone frases de una lista cerrada.
      Si falla a mitad, se dice lo que sí se hizo y el resto va al agente.
- [ ] Medir en uso real cuántas tareas resuelve el plan y cuántas siguen yendo al
      agente (el 15/09: 20 llamadas, 11,6 min, el 23 % de toda la espera).
- [ ] Pendiente de la fase 2 de `aprender.md`: correo, aprender de «no, dije X»,
      traducciones por uso y el vídeo número N.
`scratchpad\analisis\aprender.md`) y tareas sin Claude Code.
