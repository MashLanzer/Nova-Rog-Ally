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
- [ ] Ver con el uso real si hace falta que los valores dictados se corrijan
      antes de usarse en una receta (Whisper puede deformar un nombre de
      carpeta). Sin recetas reales todavía, no hay con qué medirlo.

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
