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

- [ ] **3. Listas de verdad, no notas.**
      «Apunta pan en la lista de la compra», «¿qué tengo en la lista?», «borra el
      primero». El diario guarda texto suelto; una lista se tacha y se vacía.

- [ ] **5. Reglas sobre cualquier app, no solo juegos de Steam.**
      «Cuando abra Spotify, baja el juego al 40». El motor de reglas ya existe
      entero; solo mira juegos, que es la mitad de los casos.

- [ ] **6. Avisos relativos a una hora.**
      «Avísame diez minutos antes de las diez». Hay «a las diez» y hay «en veinte
      minutos», pero no lo que de verdad pides antes de una partida.

- [ ] **8. Copia de seguridad de lo aprendido.**
      Traducciones, modos, reglas, rechazos y notas a un zip con fecha, con una
      frase. Un JSON corrupto se lleva por delante meses de ajustes sin aviso.

- [ ] **10. «¿Qué he hecho hoy?»**
      A qué jugaste y cuánto, qué apuntaste, qué descargas acabaron, cuántas
      veces se activó sola. Todos esos datos ya se guardan; nadie los junta.

---

## Interfaz y visuales

- [ ] **12. Distinguir «lo hago yo» de «esto lo lleva el agente».**
      Hoy `pensando` es idéntico para 0,3 s locales y para 160 s del agente
      completo. Saberlo desde el primer instante cambia si esperas o cancelas.

- [ ] **16. Fijar la tarjeta larga.**
      «Déjala ahí» para que no se vaya a los 8 s, «quítala» para cerrarla. Con
      una lista de pasos, ocho segundos no llegan ni para el segundo.

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
- **El fallo rojo del banco.** «Se pone siempre encima» llevaba días en rojo y
  era de la prueba, no del asistente: sobre una ventana que nunca se ha
  mostrado, `SetWindowPos(HWND_TOPMOST)` devuelve true sin marcar nada. El
  banco pasa entero por primera vez.

## Por dónde empezar

Si hay que elegir: la **3** (listas de verdad) y la **10** («¿qué he hecho
hoy?»), que son las dos que aprovechan datos que ya se guardan y que no recoge
nadie. Después la **8** (copia de seguridad de lo aprendido), que es barata y
es lo único que protege meses de ajustes de un JSON corrupto.

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
