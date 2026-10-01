# Veinte funciones nuevas para el uso diario — 30/09/2026

Las 121 ideas de autonomía iban de que Nova **se porte** mejor. Estas van de que **haga cosas
nuevas** que braya use a diario. Es la primera tanda de funciones desde que lo pidió, así que la
regla de pulir-antes-que-añadir no aplica aquí: lo dijo él.

**Todas están comprobadas contra el código antes de proponerlas.** Cada una lleva su cuenta de
ocurrencias en `assistant.ps1` (0 = no existe nada). No hay ninguna que ya esté hecha con otro
nombre, y no se repite nada de lo descartado con dato en `IDEAS-ESTADO-2026-09-25.md`.

Los datos de la consola el 30/09, que es lo que ordena la lista:

| | |
|---|---|
| Disco C: | **27 GB libres de 476** |
| Juegos indexados | 21 |
| RAM que ve Windows | 11,70 GB |
| Batería | la de una Ally, y se juega enchufado y sin enchufar |

---

## A. Las que atacan algo que le pasa HOY

### 1. La copia de la partida guardada, antes de jugar
`copia.*partida|respaldo.*save` → **0 ocurrencias**

Antes de abrir un juego, copiar su carpeta de guardado a `copias\saves\<juego>\<fecha>`. Si una
partida se corrompe o un parche la rompe, hay vuelta atrás. Hoy no hay ninguna: lo único que se
respalda es lo que Nova aprende, no lo que braya juega.

**Reutiliza** todo lo que ya existe: `Enter-Juego` ya sabe cuándo empieza una partida, y la copia
del día ya sabe comprimir y rotar. **Coste: bajo.**

### 2. Qué libera borrar cada juego, y cuál sobra
`liberar.*espacio|cuanto libera` → **0**

Con 27 GB de 476, esto es la función más pertinente de la lista. Que diga "si borras X recuperas
Y GB, y no lo tocas desde hace Z días" — cruzando el tamaño en disco con lo que ya mide de tiempo
jugado. Decidir qué borrar es una pregunta que se hace de verdad cuando quedan 27 GB.

**Reutiliza** el índice de Steam, `juegos.json` y los tiempos de juego. **Coste: bajo.**

### 3. Mover un juego a otro disco, hablando
`mover.*juego|mover.*disco` → **1** (una mención, sin función)

"Mueve Elden Ring al disco de fuera". Steam lo soporta por biblioteca; hoy hay que hacerlo a mano
por la interfaz. **Coste: medio** (hay que tocar las carpetas de biblioteca de Steam con cuidado).

### 4. Cuánto durará la batería con ESTE juego
`autonomia|durara la bateria` → **0**

Nova ya sabe el porcentaje. Lo que no sabe es **cuánto dura**, y eso depende brutalmente del juego.
Midiendo el gasto por minuto **por juego** puede decir "con Elden Ring te quedan 70 minutos; con
Unravel Two, dos horas". Es un número que solo se puede aprender midiendo, que es como hace todo lo
demás.

**Reutiliza** el medidor de batería y `Enter-Juego`. **Coste: bajo**, y mejora con el uso.

### 5. El perfil de energía por juego
`TDP|watts|vatios` → **0**

En una Ally el TDP manda más que los gráficos: a 15 W un indie va perfecto y a 25 W la batería dura
la mitad. Que Nova recuerde con qué perfil juega cada juego y lo ponga al abrirlo. Hoy no hay nada
de energía por vatios, solo el modo ahorro global.

**Coste: medio** (hay que ver si el TDP se toca por software en este modelo; si no se puede, se queda
en avisar, y eso se mide antes de prometerlo).

### 6. La batería del mando
`mando.*bateria|bateria.*mando` → **0**

Nova ya lee el mando por XInput en cada vuelta, pero no su batería. Que avise **antes** de que se
muera a mitad de partida, no cuando ya se murió.

**Reutiliza** el sondeo de XInput que ya está en el bucle. **Coste: bajo.**

### 7. La descarga se pausa cuando te pones a jugar
`pausar.*descarga|descarga.*pausa` → **3** (sabe mirar las descargas, no pausarlas)

Steam descargando mientras juegas es tirones garantizados. Que al entrar en un juego pause la
descarga y al salir la reanude. Y que lo diga, porque si no parece que la descarga se ha colgado.

**Reutiliza** el vigilante de descargas de Steam, que ya existe. **Coste: bajo.**

### 8. Apaga la consola cuando acabe la descarga
`apagar.*cuando.*termine|apaga al acabar` → **0**

"Cuando termine de descargar, apaga". Para dejarla bajando algo grande y irse a dormir. Nova ya sabe
apagar y ya sabe cuándo termina una descarga; lo que falta es juntarlo.

**Reutiliza** las dos piezas enteras. **Coste: muy bajo.**

### 9. Avisar de la actualización pendiente ANTES de abrir el juego
`actualiz.*juego` → **4** (poco, y nada que avise antes)

Abrir un juego y encontrarte 12 GB de parche es perder la sesión. Que al decir "abre X" avise
primero si tiene actualización pendiente y cuánto pesa.

**Coste: bajo** (sale del mismo sitio que las descargas).

### 10. Vaciar la caché de shaders cuando toca
`shader` → **1** (una mención, sin función)

Al cambiar la VRAM hay que vaciar la caché de shaders de AMD o los juegos empiezan a petardear —
está apuntado en la memoria del proyecto como algo que hay que acordarse de hacer. Que lo haga ella
cuando detecte el cambio, en vez de que haya que recordarlo.

**Coste: bajo.**

---

## B. Steam, el dinero y los amigos

### 11. El reloj del reembolso
`reembolso|devolver.*juego` → **0**

Steam devuelve el dinero si no pasas de **2 horas jugadas y 14 días** desde la compra. Nova ya mide
exactamente las dos cosas: tiempo jugado por juego y cuándo apareció en la biblioteca. Que avise
"llevas 1 h 40 en X y te quedan 6 días: si no te está gustando, ahora puedes devolverlo". Es dinero
real y la ventana se pasa sola.

**Reutiliza** los tiempos de juego. **Coste: bajo.**

### 12. La lista de deseos, y cuándo baja de precio
`wishlist|lista de deseos|oferta` → **0**

Lo de "qué juegos están en oferta" hoy lo contesta la IA buscando en la web, que no es lo mismo que
vigilar **tu** lista. Que mire la wishlist y avise cuando algo baje del precio que le digas.

**Coste: medio** (hay que leer la wishlist; la pública se puede consultar sin credenciales).

### 13. Un amigo acaba de empezar tu juego
`amigo.*empez|empez.*jugar.*amigo` → **0**

Nova ya sabe quién está conectado y ya sabe vigilar a uno. Lo que falta es el cruce que importa: que
alguien se ponga **al juego que tú estás jugando**, que es justo el momento de decirle algo.

**Reutiliza** el vigilante de amigos entero. **Coste: bajo.**

### 14. Qué logro te falta, y cuál es el más fácil
`logro.*falta|cuantos logros` → **0** (sabe cuándo saltan, no cuáles quedan)

Nova ya detecta logros al vuelo. Que sepa además cuántos faltan y cuál tiene el porcentaje global
más alto, que es el atajo real para el que persigue el 100 %.

**Reutiliza** la vigilancia de logros que ya está. **Coste: medio.**

### 15. ¿Este juego va bien en la Ally?
`deck.*verified|verificado` → **9** (hay algo, pero no para decidir una compra)

Antes de comprar: si está verificado para mandos y pantalla pequeña, y qué dicen de los
rendimientos. Es la pregunta que se hace cada vez que ve una oferta.

**Coste: medio.**

---

## C. Durante la partida

### 16. Traducir lo que pone en pantalla, en vivo
`traduc.*chat|chat.*traduc` → **0**

Nova ya hace OCR de la pantalla **y** ya traduce. Lo que no existe es juntarlo en una orden sola:
"¿qué dice aquí?" en un juego que está en inglés o en japonés, sin salir de la partida.

**Reutiliza las dos piezas completas.** **Coste: muy bajo**, y es de las que más se notan.

### 17. Subtítulos de lo que suena
`subtitulo` → **0**

Para jugar con el volumen bajo o con alguien durmiendo al lado: transcribir lo que dicen los
personajes. Nova ya tiene el oído montado; el trabajo está en separar el audio del juego del micro.

**Coste: alto.** Lo pongo porque es útil, no porque sea barato.

### 18. Limitar los FPS, hablando
`fps|frames` → **0**

Limitar a 30 FPS casi dobla la batería en portátil. Hoy hay que entrar en el menú de AMD.

**Coste: medio.**

### 19. El volumen del micro, por voz
`volumen.*micro|ganancia.*micro` → **1**

Nova controla el volumen de salida y el de cada app, pero no el del micro — y es lo que se toca
cuando entras a hablar con alguien y te dicen que no se te oye.

**Coste: muy bajo.**

### 20. El resumen de la sesión al cerrar el juego
Nova ya escribe el parte del día y el resumen semanal, pero no el de **la partida que acaba**:
cuánto has jugado, qué logros cayeron, si subiste de nivel, cuánta batería se fue. Es el momento en
que apetece oírlo y el único que no tiene su resumen.

**Reutiliza** el diario, los logros y los tiempos. **Coste: bajo.**

---

## Por dónde empezar, si se mira el coste contra lo que se nota

Las cuatro más baratas y que más se notan, en este orden:

1. **La 8** (apaga al acabar la descarga) y **la 16** (traducir la pantalla): las dos son juntar dos
   piezas que ya están enteras. Son horas, no días.
2. **La 2** (qué libera borrar cada juego): con 27 GB libres, es la que resuelve algo de hoy.
3. **La 1** (copia de la partida guardada): barata, y es la única de la lista que evita una pérdida
   que no se puede deshacer.
4. **La 11** (el reloj del reembolso): barata y es dinero.

La **17** (subtítulos) es la más cara de todas y la dejaría para el final. La **5** (TDP) hay que
medirla antes de prometerla: si este modelo no deja tocar los vatios por software, se queda en
avisar.

---

# Lo que se midió al implementarlas (1/10/2026)

Esta parte se escribió **después** de medir cada una contra la consola de verdad. Dos de las veinte
ya existían, dos no se pueden hacer con los datos que hay, y una sale a medias. Lo demás está hecho.

## Las que ya estaban (y se me escaparon al verificar)

- **La 9** (avisar de la actualización pendiente al abrir un juego): está en `Enter-Juego` desde la
  idea 11. Mi comprobación contó 4 ocurrencias de `actualiz.*juego` y las leí como "poco".
- **La 16** (traducir lo que pone en pantalla): existe como *"qué dice aquí"* / *"qué pone en la
  pantalla"* — hace OCR y lo traduce, y si el OCR no encuentra letras manda la captura a la API.
  Mi comprobación buscó `traduc.*chat` y no la vio.

## Las que NO se pueden hacer, con el dato que las tumba

- **La 18 (limitar los FPS).** No hay por dónde: `HKCU:\Software\AMD\DVR` no existe,
  `HKLM:\SOFTWARE\AMD\CN` tampoco, y el limitador vive en Adrenalin, que no expone nada. Lo que la
  idea buscaba —alargar la batería— lo da la **función 5** (el perfil de energía), que sí funciona.
- **La 11 (el reloj del reembolso), a medias.** Steam **no guarda la fecha de compra** en ningún
  sitio accesible: `PurchaseTime`, `Licenses` y `rt_purchase` dan cero apariciones en
  `localconfig.vdf`, el `appmanifest` solo trae `LastPlayed`, y la API pública no la expone. Así que
  se puede avisar de las **2 horas jugadas** (que es el límite que más se pasa por alto) pero no de
  los **14 días**. Se implementa esa mitad y se dice cuál falta.
- **La 14 (qué logro te falta), a medias.** `GetPlayerAchievements` devuelve **403 Prohibido**: el
  perfil de Steam está privado, así que Nova no puede leer tus logros conseguidos. Lo que sí
  responde es `GetGlobalAchievementPercentagesForApp`, o sea **cuáles son los más fáciles del
  juego** (medido en Black Myth: 81 logros, el más fácil lo tiene el 97,7 % de la gente), que es el
  atajo real para el 100 %. Con el perfil en público la otra mitad entra sola.

## Lo que se verificó que SÍ responde

| | medido |
|---|---|
| Wishlist (12) | **33 juegos**, por `IWishlistService/GetWishlist` |
| Precios (12) | `appdetails?appids=A,B&filters=price_overview` — el filtro combinado con `cc`/`l` da 400 |
| Deck Verified (15) | responde; **Black Myth: Wukong sale "no soportado"** en portátil, con sus 139 GB |
| Caché de shaders (10) | **902 MB** en `DxcCache`, 74,7 en `DxCache`, 3,2 en `D3DSCache`: casi 1 GB |
| Perfiles de energía (5) | Turbo, PD Turbo, Performance, Equilibrado — `powercfg` los cambia |
| Batería del mando (6) | el mando integrado da tipo 0 y nivel 0: **no tiene batería propia** |
| Guardados (1) | Steam Cloud solo cubre 6 de 26 carpetas, con 0-9 KB; Elden Ring son 110,51 MB |
| Juegos en disco (2) | **320,3 GB en 20 juegos**, con 27 GB libres de 476 |

## Los fallos que cazaron sus propios bancos, al escribirlas

Cinco, y todos míos. Van dentro de los bancos como casos, para que no vuelvan:

1. El tope de tamaño de la copia se comparaba con los **MB ya redondeados**, así que un guardado
   pequeño daba 0,00 y no superaba ningún tope: la guarda no se podía ni ejercitar.
2. `[0]` sobre un `Sort-Object` de **un solo elemento** devuelve el primer **carácter**:
   `'2026-09-28'[0]` es `'2'`, y el juego salía como "no lo has jugado". Con los juegos de braya no
   se veía, porque los suyos tienen varios días.
3. `[int]` **redondea** en PowerShell: 3,93 días se decían como "4 días". Hace falta `Floor`.
4. El **apóstrofe tipográfico** de "Marvel's" rompía el cruce con el fichero de tiempos.
5. El perfil de energía casaba **por subcadena**: *"hiperturbo galáctico"* activaba **Turbo**.

Y uno que cazó el banco de colisiones de la batería, no el suyo: *"mueve spotify a la otra
pantalla"* se lo comía el patrón de **mover un juego de disco** (función 3), en vez de ir al
monitor. El destino ahora tiene que sonar a disco.

## La 17 (subtítulos del audio del juego): lo que se midió antes de escribir una línea

Es la más cara de las veinte y la única que gasta **un núcleo entero** mientras trabaja, así que
se midió todo primero, en esta consola y con la batería de pruebas encima (números pesimistas):

| | retraso | tiempo real | CPU |
|---|---|---|---|
| Capturar el audio del sistema (WASAPI loopback) | — | — | **8,7 %** de un núcleo |
| Whisper tiny int8, trozos de 6 s, **1 hilo** | 1,8 s | x0,30 | **99 %** de un núcleo |
| ídem, 2 hilos | 1,2 s | x0,20 | 197 % |
| ídem, 4 hilos | 1,2 s | x0,20 | **385 %** |

**Cuatro hilos es dinero tirado**: igual de rápido que dos y el doble de núcleos. Va con **uno**,
porque el juego va delante (regla 5).

**No traduce, y es la parte que más dolió.** Whisper solo sabe traducir *hacia* inglés. Para el
español hay que pasar por el modelo local, y eso también se midió: **4,13 s** con `llama3.2:1b` y
**5,04 s** con `qwen2.5:3b`. Encima de los 1,8 s de transcribir son **siete segundos** de retraso,
y además traducía mal:

| lo que dice el juego | lo que salía |
|---|---|
| *the top of the tower* | **el topo del castillo** |
| *the bridge is out* | **El puente está fuera** |
| *he sold us out* | **Se entregó a nosotros** |

Un subtítulo que llega siete segundos tarde y mal no es un subtítulo. Así que la función se partió
en dos piezas, cada una con el precio que puede pagar:

1. **Subtítulos en vivo**, en el idioma del juego, 1,8 s. Para seguir el diálogo.
2. **"¿qué ha dicho?"**, eso sí traducido al español sobre los últimos 30 s ya oídos. Ahí los 5 s
   se pagan a gusto, porque braya lo ha pedido y está esperando.

### Dos hallazgos del camino

- **El loopback coge el sonido ANTES del volumen maestro**: con el volumen al 12 % el pico
  capturado es idéntico al de siempre (0,9853). O sea que los subtítulos funcionan **con el sonido
  bajado**, que es como se juega de noche.
- **Con nada sonando el pico es exactamente 0,00000**, así que la puerta de "no hay nada que
  subtitular" es gratis y exacta: no hace falta ningún VAD para eso.

### Y dos fallos míos, uno de ellos mudo

6. `m.transcribe()` devuelve `(segmentos, info)` y los segmentos son **perezosos**: `list(...)`
   sobre la tupla hacía una lista de **dos cosas** sin transcribir nada, y la medición salía a
   **x0,01**. Una medida que miente por no agotar un generador.
7. `StandardInput.WriteLine` de PowerShell cuela **su preámbulo (BOM)** delante del primer `{`:
   el worker recibía `\uFEFF{`, `json.loads` fallaba y el pedido se perdía **en silencio** —
   "¿qué ha dicho?" no contestaba nunca y no quedaba ni una línea de error. `Send-CharlaPedido` ya
   lo había resuelto el 13/09 escribiendo bytes UTF-8 al `BaseStream`; aquí se hace igual, y el
   banco lo comprueba mirando que el primer byte sea `0x7B`.
