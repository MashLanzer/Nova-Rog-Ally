# Cómo jugar al ajedrez con Nova

Ajedrez **a ciegas**: sin tablero, sin pantalla, solo hablando. Nova lleva la partida entera
en la cabeza y tú también. Puedes estar jugando a otra cosa, con el mando en las manos.

---

## Lo primero: cómo se dice una casilla

Esto es lo único que hay que aprender, y son treinta segundos.

Un tablero tiene **columnas** (de izquierda a derecha) y **filas** (de abajo arriba). Una
casilla es una columna y una fila: la casilla `f3` es la columna f, fila 3.

**Las columnas se dicen con nombres, no con letras:**

| columna | se dice | | columna | se dice |
|---|---|---|---|---|
| a | **alfa** | | e | **echo** |
| b | **bravo** | | f | **foxtrot** |
| c | **charlie** | | g | **golf** |
| d | **delta** | | h | **hotel** |

**¿Por qué así y no «efe tres»?** Porque tu micrófono no distingue las letras sueltas. Está
medido en tu propio registro: en 1.127 frases tuyas **no hay ni una sola** que el oído haya
transcrito como «e4» o «f3». Y comparando las letras españolas entre sí, «e» y «efe» se
parecen un 80 %; con «echo» y «foxtrot», el peor par baja al 67 %. Con nombres largos acierta;
con letras sueltas, no.

**Las filas se dicen normales:** uno, dos, tres, cuatro, cinco, seis, siete, ocho.

> **También te entiende «efe tres» o «ce cuatro»** si te sale así. Funciona, pero acierta
> menos. Los nombres largos son la forma buena.

---

## Empezar

Di cualquiera de estas:

- **«nova, juguemos al ajedrez»**
- «nova, juega ajedrez conmigo»
- «nova, una partida de ajedrez»
- «nova, ajedrez a ciegas»

Te contesta: *«Vale, partida a ciegas. Llevas blancas: empiezas tú.»*

**Tú siempre llevas blancas y empiezas.**

---

## Mover

Di **la pieza y la casilla a la que va**:

| lo que dices | lo que hace |
|---|---|
| **«nova, peón echo cuatro»** | el peón a e4 |
| **«nova, caballo foxtrot tres»** | el caballo a f3 |
| **«nova, alfil charlie cuatro»** | el alfil a c4 |
| **«nova, dama hotel cinco»** | la dama a h5 |
| **«nova, torre delta uno»** | la torre a d1 |
| **«nova, rey golf uno»** | el rey a g1 |

Con los peones puedes ahorrarte la palabra: **«nova, echo cuatro»** también vale.

Y hay formas sueltas que entiende igual:

- «caballo **a** foxtrot tres» (con el «a» en medio)
- «alfil **come en** delta cinco» (para capturar; da igual, con decir dónde va basta)
- **«enroque corto»** y **«enroque largo»**

**Nova te contesta repitiendo tu jugada y diciendo la suya:**

> *«peón echo cuatro; yo, peón charlie cinco.»*

Ese «peón echo cuatro» del principio es **la confirmación de que te entendió bien**. Si oyes
otra cosa de la que dijiste, di **«retira esa»** (más abajo).

Si te da jaque, lo dice: *«caballo foxtrot siete; yo, dama hotel cinco. Jaque.»*

---

## Cuando te pregunta

A veces Nova contesta con una pregunta:

> *«¿torre alfa seis o torre alfa siete?»*

Eso pasa cuando lo que oyó encaja con **dos jugadas legales a la vez**. No está adivinando a
propósito: **seis** y **siete** son las dos palabras que más se confunden de todo el
vocabulario (se parecen un 70 %), y si se equivoca movería una pieza donde tú no dijiste.

Contestas con **«la primera»** o **«la segunda»**. También vale «uno» / «dos».

---

## Lo que puedes decirle durante la partida

| frase | qué hace |
|---|---|
| **«nova, retira esa»** | deshace tu última jugada y la suya. También «deshaz», «no era esa», «vuelve atrás» |
| **«nova, por dónde vamos»** | te dice por qué jugada vais y cuál fue la última. También «cómo va la partida», «a quién le toca» |
| **«nova, dejamos la partida»** | la cierra y la guarda. También «abandono», «me rindo», «deja el ajedrez» |

**«Retira esa» es la red de seguridad de todo esto.** Si Nova entiende mal una jugada, no hay
que confirmar nada: se deshace y ya. Por eso no te pregunta «¿seguro?» en cada movimiento — con
tu oído al 70 %, un «sí» mal oído no confirma nada, y deshacer sí es seguro.

---

## Lo que NO cambia mientras juegas

**Todo lo demás sigue funcionando igual.** Con la partida abierta puedes decir «nova, sube el
volumen», «nova, abre Steam», «nova, qué hora es» y Nova hace eso, no una jugada.

Está comprobado con nueve órdenes reales sacadas de tu registro. Una frase solo cuenta como
jugada si pasa **tres llaves**: que haya partida abierta, que la frase tenga forma de jugada
(una pieza o una columna, y una fila), y que esa jugada sea **legal en ese tablero**. Si falla
cualquiera de las tres, tu frase sigue su camino de siempre.

---

## Si se acaba

- Si ganas: *«Jaque mate, ganas tú.»*
- Si pierdes: *«Jaque mate. Gano yo.»*
- Tablas: *«Tablas por ahogado.»*

La partida se cierra sola y se guarda en `memoria\ajedrez.pgn`, que es el formato de toda la
vida: puedes abrirlo en cualquier web de ajedrez y ver la partida entera jugada.

**Y el nivel se ajusta solo.** Empieza en 1320 de Elo (principiante). Si ganas, sube 60; si
pierdes, baja 60. No hay que tocar nada.

---

## Si reinicias, o se apaga la consola

**No pasa nada: la partida sigue donde estaba.** Se guarda en disco después de cada jugada.

Esto no es un detalle: Nova arranca unas **17 veces al día** (235 veces en 14 días). Una
partida que viviera solo en memoria se perdería diecisiete veces diarias.

Al volver, di «nova, por dónde vamos» y te lo cuenta.

---

## Un ejemplo entero

> **Tú:** nova, juguemos al ajedrez
> **Nova:** Vale, partida a ciegas. Llevas blancas: empiezas tú.
>
> **Tú:** nova, peón echo cuatro
> **Nova:** peón echo cuatro; yo, peón charlie cinco.
>
> **Tú:** nova, caballo foxtrot tres
> **Nova:** caballo foxtrot tres; yo, peón delta seis.
>
> **Tú:** nova, alfil charlie cuatro
> **Nova:** alfil charlie cuatro; yo, caballo foxtrot seis.
>
> **Tú:** nova, por dónde vamos
> **Nova:** Vamos por la jugada 4. Lo último, caballo foxtrot seis. Te toca.
>
> **Tú:** nova, dejamos la partida
> **Nova:** Dejamos la partida. La guardo por si quieres verla.

---

## Si algo va mal

**«No me funciona el motor»** — falta el programa que juega (Stockfish). Está en
`modelos\stockfish\`; son 98 MB y no van en el repositorio. Si se borró, se vuelve a bajar de
`github.com/official-stockfish/Stockfish` (release, Windows x86-64).

**Dice una jugada que no era la tuya** — «retira esa», y dilo otra vez más despacio. Si se
repite con la misma casilla, prueba la forma larga: «caballo **a** foxtrot tres».

**No te hace caso al decir una jugada** — comprueba que hay partida abierta con «por dónde
vamos». Si dice que no hay ninguna, empieza otra.

**Quieres apagarlo del todo** — en `config.json`, `juego.ajedrez` a `false`.

---

## Lo que hay por dentro, en dos líneas

Nova **no sabe jugar al ajedrez**, y es a propósito: las reglas las lleva `python-chess`
(una librería, nada escrito a mano) y quien juega es **Stockfish**, que es el motor más fuerte
que existe, con la fuerza limitada para que sea jugable.

Lo único que se escribió aquí es lo que ninguna librería puede saber: **cómo suena una jugada
dicha en voz alta en español**. Y el truco que lo hace funcionar es que **al oído no se le
enseña ajedrez**: en cada turno la librería da las ~30 jugadas legales, y lo que oyó tu
micrófono solo tiene que **elegir** entre esas. Nunca transcribe una jugada desde cero — por
eso funciona con un oído que acierta el 70 % del tiempo.
