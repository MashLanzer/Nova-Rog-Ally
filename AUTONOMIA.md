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

---

## Las 10 siguientes

Cada una con **el dato que la justifica** (no son ideas al aire) y **su freno**.

**1. Apagar la nube que no le sirve.**
Gemini lleva **29 llamadas** con `nube-nada: 1` y **cero** `nube-sirvio`. Es calcado al caso
del turbo que ya apagó sola.
*Freno: mínimo 20 llamadas antes de juzgar, y avisarlo.*

**2. Mover ella sola el umbral de confianza.**
Hoy: ruido **3 de 97** y **132** activaciones. Si el ruido sube, que se ponga más exigente;
si se le escapan activaciones tuyas, que afloje.
*Freno: pasos pequeños, una vez al día, reversible hablando.*

**3. Apagar el oído fino cuando deje de aportar.**
Hoy **sí** aporta (27 de 81 = 33 %), pero ya se inventa 5. Con el mismo listón del 15 % que
usó para el turbo, que lo apague el día que baje.
*Freno: el listón ya probado, no uno nuevo.*

**4. Bajar su gasto sola al ver un juego, y devolverlo al salir.**
Sin pedírselo: fps de la cápsula, revisor parado, modelos soltados.
*Freno: decirlo una vez, y deshacerlo solo al cerrar el juego.*

**5. Dejar de ofrecer lo que siempre rechazas.**
Ya guarda `rechazadas` en hábitos. Si propone algo tres veces y siempre dices que no, que
deje de proponerlo.
*Freno: tres noes, no uno.*

**6. Aprender del «deshaz» sin que se lo expliques.**
Si deshaces en menos de 30 s lo que acaba de hacer, eso es un error suyo: que se lo apunte
como rechazo. Hoy solo aprende si le dices «no era eso».
*Ataca directamente la meta de cero órdenes equivocadas.*

**7. Limpiarse por espacio, no por calendario.**
Caché de voz, audios de uso, capturas y logs: cuando el disco baje del umbral, podar lo más
viejo y decir qué tiró.
*Freno: nunca lo del día en curso.*

**8. Ajustar el oído por hora y por ruido.**
Tiene `ritmo` y `charlaHoras`. Si a ciertas horas la tele está siempre puesta, que arranque
más exigente en esa franja.
*Freno: solo franjas con muchos días de datos.*

**9. Rehacer sola tu huella de voz.**
El tono aprendido son **119,6 Hz**. Cuando junte suficientes muestras nuevas, que lo
recalcule y **avise del cambio**, para que «solo yo» no se degrade.
*Freno: cambios pequeños; uno grande se pregunta.*

**10. Ponerse un presupuesto de tiempo y rendirse a tiempo.**
Si una orden va camino de pasar de X segundos encadenando repasos, que renuncie y lo diga,
en vez de dejarte esperando (el turbo costaba 16,2 s).
*Freno: decir siempre por qué se rindió.*

**Por dónde empezar:** la **1** (calcada a la que ya funcionó y con datos de sobra), la **6**
(la que más acerca a cero órdenes equivocadas) y la **4** (que vaya igual de bien con un
juego abierto).

---

## 20 más

### Sobre su propio cuerpo: memoria, arranque y recursos

**11. Decidir qué modelos carga al arrancar según la RAM libre.**
Hoy carga lo mismo con 8 GB libres que con 500 MB. Que mire y decida: con poca RAM o un
juego ya abierto, ni cargar el preciso. *Freno: decirlo, y recargarlo al liberarse.*

**12. Soltar modelos sola según el uso real, no por un plazo fijo.**
Ya existe `soltar_preciso_si_toca` con un plazo puesto a mano. Que lo calcule ella: si hace
tres días que no usa el preciso, soltarlo antes.

**13. Autodiagnóstico al arrancar, y desactivar lo que esté roto.**
Comprobar micro, voz y cápsula. Si la voz online no responde, pasar a Piper **y decirlo**,
en vez de fallar en cada frase durante toda la sesión.

**14. Elegir voz online o local por latencia medida.**
Si la nube tarda más de X en tres frases seguidas, cambiar a Piper sola y volver cuando
mejore. *Freno: no cambiar a mitad de una frase.*

**15. Vigilar su propio tamaño de datos y compactar.**
Diario, cerebro, vectores, registro de uso. Cuando algo crezca por encima de su umbral,
compactarlo o archivarlo por meses, avisando de lo que archivó.

**16. Recuperarse sola de un worker muerto, con paciencia creciente.**
Si un worker muere tres veces seguidas, dejar de relanzarlo en bucle: desactivarlo,
decirlo, y seguir con lo que sí funciona.

### Sobre entenderte mejor sin que se lo pidas

**17. Reordenar sus propios patrones por lo que más aciertas.**
Mide `local` por ruta. Poner delante lo que más usas hace el reconocimiento más rápido sin
cambiar nada de lo que entiende.

**18. Crear atajos sola para lo que repites.**
Ya detecta hábitos pero solo propone. Que genere el alias, lo use y lo diga: «he aprendido
que cuando dices X quieres Y; dime que no si me equivoco».

**19. Aprender a abrir lo que instalas sin que se lo enseñes.**
Si aparece un juego o programa nuevo, aprender su nombre hablado y sus variantes, en vez de
esperar a que se lo digas la primera vez que falla.

**20. Retirar reglas suyas que ya no se usan o fallan siempre.**
Si una regla no se dispara en un mes, o falla las tres últimas veces, que la retire y lo
diga. *Hoy las reglas solo se quitan a mano.*

**21. Desactivar recetas que fallan.**
Ya cuenta `fallos` en cada receta. Que decida ella el corte en vez de tenerlo fijo, y avise
de cuál desactivó y por qué.

**22. Aprender qué avisos ignoras y dejar de darlos.**
Si un aviso de entorno lleva cinco veces sin que reacciones, que baje su nivel solo o deje
de darlo. *Freno: nunca los de batería crítica ni los de seguridad.*

**23. Ajustar el volumen de su voz al ruido de la habitación.**
Ya mide el nivel del micro. Si hay ruido, hablar más alto; de noche, más bajo, sin que
tengas que decírselo cada vez.

### Sobre cuándo callarse y cuándo actuar

**24. Callarse sola cuando el micro lo está usando otra cosa.**
Ya existe `Test-EnLlamada`. Que aprenda más casos (grabando, en partida con voz) y decida
guardarse los avisos para después.

**25. Aprender tus horas de sueño reales y mover el modo noche.**
No por una hora fija, sino por cuándo dejas de usarla de verdad. *Freno: preguntar la
primera vez que lo cambie.*

**26. Callarse en la franja en que siempre la mandas callar.**
Si a la misma hora le dices «cállate» tres días seguidos, que empiece callada esa franja y
lo diga.

**27. Decidir sola entre palabra y botón según lo que funciona.**
Hoy `soloBotonEnJuego` es un ajuste fijo. Que lo decida por datos: si jugando la palabra
falla o se activa sola, pasar a botón; si va bien, dejarla.

### Sobre gastar con cabeza

**28. Decidir cuándo merece la pena la IA cara.**
Con el tiempo y el acierto medidos de cada camino, que elija: local, nube barata o cara. Y
que lo apunte para poder revisarlo.

**29. Hacer copia de seguridad cuando toca de verdad.**
No por calendario: cuando haya cambios importantes (recetas, reglas, contactos) **y** lleves
un rato sin hablarle, para no molestar.

**30. Escribirse su propio parte semanal.**
Una vez por semana, un resumen corto de lo que decidió sola, lo que le costó tiempo y lo que
falló, en un `.md` que puedas leer. Si no puede explicar una decisión con un número, es que
no debería haberla tomado.

---

## Cómo se elige la siguiente

1. ¿Hay **dato propio** que la justifique? Si no, primero se mide.
2. ¿Se puede **deshacer hablando**? Si no, no se implementa.
3. ¿Qué pasa si se equivoca? Si la respuesta es «se queda callada» o «se queda un modo
   puesto sin saberlo», va con aviso obligatorio o no va.
