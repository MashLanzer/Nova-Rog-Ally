# Diez ideas solo de Steam — 24/09/2026

*Todo lo de aquí está medido hoy, con tu clave ya funcionando, contra la API de Steam y contra
`assistant.log`. No hay ni un número estimado: si algo no se pudo medir, lo pongo como "no
medido" y ya está.*

**El punto de partida, que conviene tener delante:**

| | |
|---|---|
| Juegos en tu cuenta | **92** |
| Juegos que Nova conoce | **15** (los instalados: los lee del disco, no de Steam) |
| Juegos que jugaste en dos semanas | **14** |
| Juegos de los que Nova apuntó tiempo | **6** |
| Amigos | **4**, los cuatro con el perfil público |
| Nivel de Steam / cuenta desde | 5 / 11-09-2022 |

Y una fecha que lo explica casi todo: **el 14/09 a las 00:15:50** preguntaste *"quién está
conectado en steam"* y Nova contestó que necesitaba una clave de la API. **Hasta hoy no la ha
tenido.** Todo el código social de Steam —lista de amigos, vigilar a uno, quién está
conectado— lleva diez días escrito y muerto.


> **Por qué los amigos salen como "A, B, C y D":** este repositorio se sube a GitHub, y su
> `.gitignore` ya deja fuera los registros *"por privacidad"*. Los nicks de Steam de otras
> personas son datos de terceros, así que aquí van con etiqueta. Tú sabes quién es cada uno
> mirando la tabla de la idea 2; Nova, al ejecutarlo, usa los nombres de verdad.

---

## 1. Conoce 15 de tus 92 juegos, y una vez lo dijo en voz alta

`Get-JuegosSteam` lee los `appmanifest_*.acf` del disco: solo ve lo **instalado**. Por eso el
registro dice `Steam actualizada: 1 -> 15 juegos` y nunca más.

Y hay una frase tuya que lo delata. El **20/09 a las 19:04:20** Nova te dijo:

> *"No tengo acceso a la lista completa de nombres de tus juegos instalados, la verdad."*

Con `GetOwnedGames` los tiene los 92, con sus horas. Eso cambia tres cosas de golpe: *"abre
Resident Evil 4"* deja de fallar cuando no está instalado (y puede contestar **"lo tienes pero
no instalado, ¿lo bajo?"**), *"¿cuánto he jugado a X?"* tiene respuesta, y el buscador por
sonido —el que te entiende el nombre mal dicho— pasa de elegir entre 15 nombres a elegir entre
92.

*Lo delicado:* 92 nombres es un diccionario más grande para confundirse. Hay que medir si el
buscador por sonido acierta más o menos con la lista larga **antes** de darla por buena.

---

## 2. Con quién juegas, que es un dato y no una suposición

Cruzadas tu biblioteca y la de tus cuatro amigos:

| amigo | sus juegos | en común contigo | lo que más juega de lo vuestro |
|---|---|---|---|
| **la amiga A** | 18 | **16 (el 89 %)** | Don't Starve Together, It Takes Two, Cat Quest III |
| el amigo B | 75 | 15 | Phasmophobia, Helldivers 2, Ready or Not |
| el amigo C | 46 | 13 | Phasmophobia, Ready or Not, R.E.P.O. |
| el amigo D | 49 | 5 | R.E.P.O., Backrooms, Liar's Bar |

**La amiga A tiene 16 de sus 18 juegos en común contigo**, y los que más juega son exactamente
los tuyos. Y en dos semanas has jugado **16,2 h a It Takes Two y 3,4 h a A Way Out**, que son
dos juegos que **no se pueden jugar solo**.

O sea que Nova puede saber con quién juegas sin que se lo digas. Cuando abras It Takes Two,
mirar si esa persona está conectada y decírtelo **una vez** vale más que cualquier aviso
genérico.

---

## 3. Está conectado, y Nova no te lo dice nunca

Ahora mismo, medido al escribir esto: **el amigo D** ausente (se conectó hace hora y media),
**la amiga A** se desconectó hoy a las 05:31, los otros dos llevan semanas fuera.

`Watch-AmigoConecta` y `Start-AmigoVigila` existen en el código. Con la clave puesta ya
funcionan. Lo que falta es decidir **cuándo hablan**: mientras juegas, la regla es no
interrumpir, así que esto tiene que ir a la cápsula y no a la voz, o esperar a que salgas.

*Lo bueno de estos cuatro:* con cuatro amigos no hay riesgo de spam. Con cuarenta lo habría.

---

## 4. La tienda funciona sin clave, y hay descuentos de verdad

`store.steampowered.com/api/appdetails` responde **sin clave ninguna**, en español y en euros.
Probado hoy:

| | ahora | antes | |
|---|---|---|---|
| It Takes Two | 11,99 € | 39,99 € | **−70 %** |
| Need for Speed Heat | 6,99 € | | **−90 %** |
| ELDEN RING | 59,99 € | | — |

**Un aviso:** la respuesta **no viene con la clave del `appid` que pides**, sino con la del
paquete padre —ELDEN RING es 1245620 y contesta bajo 2855530—. Hay que coger la primera
propiedad, no buscar por el número que enviaste. Es un fallo fácil de cometer y silencioso.

---

## 5. Los 23 que empezaste y dejaste

**23 juegos** tienen entre 20 minutos y 2 horas y **nada en las últimas dos semanas**: los
abriste, los probaste y ahí se quedaron.

| | jugado | hoy cuesta |
|---|---|---|
| The Headliners | 112 min | 7,79 € |
| Ready or Not | 108 min | 49,99 € |
| **Need for Speed Heat** | 91 min | **6,99 €, −90 %** |
| Resident Evil Village | 85 min | 39,99 € |

Y aparte, **22 que no has abierto nunca** (Resident Evil 6, The Forest, Assassin's Creed
Odyssey, Squad...). Eso son 45 de 92.

Nova puede usar esto en la dirección útil: no *"cómprate cosas"*, sino **"esto ya lo tienes y
lo dejaste a la media hora"** cuando le preguntes a qué jugar.

---

## 6. Los logros: sabe que pasó algo, pero no qué

En todo el registro hay **cuatro** líneas de logro, las cuatro del 15/09 y las cuatro de It
Takes Two, y todas dicen lo mismo:

> `LOGRO (stats de Steam cambiaron) en It Takes Two`

No dice **cuál**. `GetPlayerAchievements` sí lo dice, con el nombre y la descripción. Medido
hoy en lo que juegas ahora:

| | |
|---|---|
| It Takes Two | 5 / 20 |
| Content Warning | 11 / 48 |
| REANIMAL | 9 / 41 |
| ELDEN RING | 8 / 42 |
| **A Way Out** | **0 / 14** |
| Black Myth: Wukong | 1 / 81 |

*"Has sacado \<nombre del logro\>"* es otra frase, y *"te faltan 9 para terminar It Takes Two"*
es otra cosa distinta. Las dos salen del mismo sitio.

---

## 7. De ELDEN RING solo ve el 2 % de lo que juegas

Comparado lo que Nova apunta en `memoria\juegos.json` con lo que dice Steam:

| juego | Nova ve | Steam (2 semanas) | ve el… |
|---|---|---|---|
| Black Myth: Wukong | 1,63 h | 1,7 h | **97 %** |
| A Way Out | 3,15 h | 3,4 h | **93 %** |
| It Takes Two | 12,86 h | 16,2 h | **80 %** |
| Unravel Two | 0,06 h | 0,1 h | 64 % |
| **ELDEN RING** | **0,10 h** | **6,1 h** | **2 %** |

Cuatro de cinco están bien. **ELDEN RING no.** Nova lo detectó en primer plano **7 veces** y
aun así solo acumuló 354 segundos. Y de los **9** juegos que llegó a ver en primer plano, solo
**6** acabaron con tiempo guardado: Little Nightmares III, Outlast y Little Nightmares II se
detectaron y no dejaron ni un segundo.

*No sé por qué todavía,* y eso es justo lo que hay que averiguar antes de tocar nada: puede ser
la pantalla completa exclusiva, puede ser que jugaras con Nova apagada, o puede ser el filtro
de los 120 segundos. Con Steam delante se puede **saber** cuál de las tres, porque Steam da la
verdad contra la que comparar.

---

## 8. Cuánto has jugado hoy, de verdad

Hoy Nova te avisa del tiempo de juego con lo que ella misma ha visto, que según la tabla de
arriba es entre el 2 % y el 97 % de la verdad según el juego. Con `GetRecentlyPlayedGames`
tiene el dato bueno: **14 juegos en dos semanas**, con sus horas exactas, encabezados por It
Takes Two con 16,2 h.

Esto no es una función nueva: es que **el aviso que ya existe deje de apoyarse en un número
que puede estar 50 veces por debajo**. Y encima permite lo de la idea 7: cuando las dos cuentas
no cuadren, Nova puede decirlo en vez de fiarse de la suya.

---

## 9. Lo que juegan tus amigos y tú no tienes

| juegan | juego |
|---|---|
| 2 de 4 | Among Us |
| 2 de 4 | Lethal Company |
| 2 de 4 | Papers, Please |
| 2 de 4 | Age of Mythology: Retold |
| 2 de 4 | Grand Theft Auto V |

No para que te lo compres —eso es lo que hace la tienda y ya cansa—, sino para la pregunta que
sí importa: cuando ****la amiga A**** esté conectada y tú preguntes *"¿a qué jugamos?"*, que la
respuesta salga de los **16 juegos que tenéis los dos** y no de una lista genérica. Y si no
tenéis ninguno libre, ahí sí vale decir cuál os falta a los dos y cuánto cuesta.

---

## 10. Nada de esto puede colgar el bucle, ni enseñar la clave

Esta no es una idea de función: es la condición de las nueve anteriores, y va aquí porque
nueve ideas nuevas que hablan con internet son nueve maneras de romper las reglas 4 y 5.

- **La clave no aparece en el registro.** Ya está resuelto en tres sitios con
  `-replace 'key=[^&\s]+', 'key=***'`, y cada petición nueva es un sitio más donde se puede
  olvidar. Debería haber **un solo** sitio que registre peticiones de Steam, no nueve.
- **Nada síncrono.** `Start-SteamAsync` ya existe y devuelve `$false` si hay una petición en
  vuelo. Las nueve ideas tienen que pasar por ahí, y ninguna puede esperar una respuesta
  dentro del bucle.
- **Una sola petición por cosa y con memoria.** La biblioteca de 92 juegos cambia como mucho
  una vez al día; los amigos, cada pocos minutos; los precios, una vez al día. Si cada idea
  pide por su cuenta, son nueve peticiones donde caben dos.
- **Y todo esto es de braya.** Con un invitado delante, quién está conectado y a qué juegas no
  se cuenta y no se guarda.

---

*Escrito el 24/09/2026, con la clave de Steam funcionando por primera vez. Cada número de aquí
se puede volver a sacar: la API se consultó hoy y el registro es el de siempre.*
