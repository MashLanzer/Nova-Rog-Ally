# Pendiente

Lo que queda por hacer, con el porqué de cada cosa. Anotado el 12/09/2026.
Para retomar: leer esto y `ESTADO.txt` (lo que ya funciona), y pasar
`powershell -NoProfile -File tools\probar-todo.ps1` antes de tocar nada.

---

## Antes de nada, dos cosas tuyas

- [ ] **Grabar las 20 frases** — `python tools\grabar-ordenes.py` (una sola vez).
      Es lo único que falta para poder medir si el micrófono te entiende. Hasta
      que existan esas grabaciones, cualquier cambio en el reconocimiento es una
      opinión. Después se mide con `python tools\probar-audio.py`, que ya va
      dentro de `probar-todo.ps1`.

- [ ] **Encender el asistente y probarlo.** Sigue apagado a propósito desde el
      11/09. El comando está al principio de `ESTADO.txt`.

Y para devolver la pantalla de la Ally a como estaba (ahora no se apaga nunca,
ni con batería):

    powershell -NoProfile -File "C:\Users\braya\Documents\pantalla-ally\restaurar.ps1"

---

## Funciones nuevas

- [ ] **1. Dictado largo de verdad.**
      Hoy el dictado es para órdenes cortas; para escribir un mensaje no sirve.
      «Dicta un correo» entraría en modo continuo escribiendo en la ventana de
      delante, con «punto y aparte», «borra lo último» y «cambia X por Y».

- [ ] **2. Órdenes de ventana sobre una app por su nombre.**
      «Minimiza Spotify», «manda Discord al otro monitor», sin ponerla delante
      primero. Todo lo de ventanas actúa solo sobre la que tiene el foco, que es
      justo la que no quieres tocar mientras juegas.

- [ ] **3. Listas de verdad, no notas.**
      «Apunta pan en la lista de la compra», «¿qué tengo en la lista?», «borra el
      primero». El diario guarda texto suelto; una lista se tacha y se vacía.

- [ ] **4. «¿Cómo va todo?»** — *casi gratis, los datos ya se recogen*
      Un parte único: batería y cuánto queda, CPU, disco, qué se descarga, a qué
      juegas, si hay algo colgado, si está en sordina. Hoy son seis preguntas
      distintas y hay que acordarse de las seis.

- [ ] **5. Reglas sobre cualquier app, no solo juegos de Steam.**
      «Cuando abra Spotify, baja el juego al 40». El motor de reglas ya existe
      entero; solo mira juegos, que es la mitad de los casos.

- [ ] **6. Avisos relativos a una hora.**
      «Avísame diez minutos antes de las diez». Hay «a las diez» y hay «en veinte
      minutos», pero no lo que de verdad pides antes de una partida.

- [ ] **7. Teclas y botones repetidos para menús.**
      «Baja tres veces», «dale a A», «atrás dos veces». Con un juego a pantalla
      completa y el mando en la mano, es lo único que no se puede hacer hablando.

- [ ] **8. Copia de seguridad de lo aprendido.**
      Traducciones, modos, reglas, rechazos y notas a un zip con fecha, con una
      frase. Un JSON corrupto se lleva por delante meses de ajustes sin aviso.

- [ ] **9. Que solo te obedezca a ti.** — *la que sigue la línea de hoy*
      La voz por tono ya se estima y se guarda; usarla para pedir confirmación
      cuando quien habla no eres tú. Es la defensa que falta contra el audio de
      un vídeo CON VOZ HUMANA, que es el único ruido que los filtros de hoy no
      distinguen.

- [ ] **10. «¿Qué he hecho hoy?»**
      A qué jugaste y cuánto, qué apuntaste, qué descargas acabaron, cuántas
      veces se activó sola. Todos esos datos ya se guardan; nadie los junta.

---

## Interfaz y visuales

- [ ] **12. Distinguir «lo hago yo» de «esto lo lleva el agente».**
      Hoy `pensando` es idéntico para 0,3 s locales y para 160 s del agente
      completo. Saberlo desde el primer instante cambia si esperas o cancelas.

- [ ] **13. Cola visible con varias órdenes.**
      «Abre Steam y pon modo juego» son dos cosas; que se vean los dos puntos y
      cuál va tachándose. Si falla la segunda, hoy no hay forma de saber cuál fue.

- [ ] **15. Tamaño grande a petición.** — *la que más se nota en la Ally*
      En la pantalla de 7", 13,5 px es pequeño de verdad. «Hazte más grande» /
      «más pequeña», recordado como la esquina.

- [ ] **16. Fijar la tarjeta larga.**
      «Déjala ahí» para que no se vaya a los 8 s, «quítala» para cerrarla. Con
      una lista de pasos, ocho segundos no llegan ni para el segundo.

- [ ] **17. Avisos sin voz.**
      En sordina o con un juego delante, que la batería o un temporizador sean un
      pulso de color en el borde en vez de hablarte encima. Hoy o habla o no te
      enteras.

- [ ] **18. «¿Cómo estás configurada?»**
      Una tarjeta con lo esencial: voz, modelos, estado del oído, esquina, reglas
      activas, modos. Hoy eso es leerse `config.json` a mano.

- [ ] **19. Color a elección.**
      «Ponte de color naranja», guardado igual que la esquina. Los colores de
      estado se mantienen; cambia el de reposo.

- [ ] **20. Que se aparte también hacia arriba o abajo.**
      Solo sabe deslizarse de lado. En una esquina y con una ventana que ocupa
      toda la franja, apartarse en horizontal no la salva.

---

## Hechas (12/09/2026)

- **11. Que se vea qué va a hacer, antes de hacerlo.** Un glifo en el hueco de
  la carita justo antes de cada acción que toca el sistema, sin añadir espera.
  Detalle en `ESTADO.txt`, sección de la cápsula.
- **14. El anillo del avatar como progreso de la descarga.** Y de paso salió
  que el aviso de "ya se descargó" no había funcionado nunca: una variable
  declarada dos veces y compartida por dos usos con claves distintas.

## Por dónde empezar

Si hay que elegir: la **9**, porque sigue la línea de lo que se arregló estos
días (que no actúe sin que se lo pidas). La **4** es casi gratis porque los
datos ya están recogidos. Y la **15** es la que más se agradece en la Ally.

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
