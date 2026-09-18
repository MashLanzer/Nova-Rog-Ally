# Nova como un LLM, sin serlo

braya: «¿podemos hacer que Nova sea todo esto, o sea ser un verdadero LLM sin serlo?»

**Se empieza al terminar la lista de AUTONOMIA.md, y entonces solo se trabaja en esto.**

---

## La idea, en una frase

Lo que hace útil a un asistente **no es principalmente el modelo**. Es un conjunto de seis
piezas, y de esas, **solo una necesita un LLM de verdad**. Nova ya tiene tres y media. El
trabajo es completar las otras, que **caben en local** y no dependen de pagar nada.

## Las seis piezas, y dónde está Nova hoy

| # | pieza | qué es | Nova hoy |
|---|---|---|---|
| 1 | **Razonamiento con lenguaje** | entender una frase torcida y deducir la intención | **prestado** (API primero, Ollama de respaldo) |
| 2 | **Herramientas reales** | leer, escribir, ejecutar y ver el resultado | **sí, y muchas** |
| 3 | **Bucle de verificación** | hacer → comprobar → corregir | **no** ← *lo que más falta* |
| 4 | **Memoria con sentido** | recordar y traer lo relevante, no lo que coincide en letras | **a medias** |
| 5 | **Criterio para no actuar** | saber cuándo parar, preguntar o callarse | **sí, y bueno** |
| 6 | **Rendir cuentas** | decir qué hizo y por qué, con números | **sí**, desde la tanda de autonomía |

**Lo medido que respalda esto:** de 366 órdenes, **201 se resuelven en local sin tocar un
modelo** y 165 van a uno. Y los fallos **no son de comprensión: son de oído** — los 38 errores
registrados son «dictado vacío» y transcripciones rotas («Abre Team», «Abre Sting»).
Por eso un modelo más grande no la arreglaría.

---

## 1. El bucle de verificación — *empezar por aquí*

Es lo que más separa a Nova de un asistente que parece listo, y **no necesita modelo ninguno**.

Hoy Nova **ejecuta y da por hecho que salió bien**. Abre Steam y no mira si se abrió; pone el
volumen y no comprueba que se puso. Cuando algo falla, se entera braya.

Lo que haría falta, por orden:
- **Comprobar el efecto** de las acciones que ya son comprobables: una app abierta tiene
  proceso y ventana; el volumen se puede leer (`[AX]::LeerVolumen`, ya existe); el brillo
  también; un archivo creado existe o no.
- **Reintentar una vez** lo que falló por una causa conocida, y **solo una**.
- **Decirlo cuando no se pudo**, en vez de callar: «lo intenté y no se abrió».
- Y lo más valioso: **apuntarlo**. Una acción que falla a menudo es una orden que hay que
  arreglar, y hoy no queda registrada como fallo salvo que braya se queje.

*Por qué primero:* ataca directamente la meta de «cero órdenes equivocadas», se puede probar
en el banco sin modelo, y cada pieza es independiente (se puede empezar por el volumen, que
ya se sabe leer).

## 2. Memoria con sentido

Ya existe la infraestructura: `cerebro.json`, `vectores.json` (64 KB), tope de 5.000
recuerdos, diario por días, `perfil.md` y un revisor en segundo plano.

Lo que falla es **la recuperación**: traer lo que viene a cuento, no lo que coincide en
palabras. Es donde un modelo pequeño **local** (embeddings) rinde de verdad, y ya hay uno
configurado (`conversacion.modeloEmbeddings`).

Señal de que importa: `Find-Traduccion` devolvía la primera coincidencia y no la más parecida
—arreglado en esta tanda—. El mismo problema, más grande, está en la memoria.

## 3. Saber lo que no sabe

Yo digo «esto no lo he medido». Nova, cuando no entiende, **adivina**: son los
`fino-invento`, **5 órdenes equivocadas de 81 repasos**. Una IA que reconoce su límite parece
mucho más lista que una que acierta un poco más.

Ya hay piezas: la confianza del dictado, `Test-MereceRepaso`, el umbral de la palabra. Falta
**juntarlas en una sola idea de «seguridad»** que decida entre hacer, preguntar o callar.

## 4. Más herramientas fiables, no más inteligencia

Cada herramienta nueva multiplica lo que puede hacer **con el mismo cerebro prestado**. Y una
herramienta se prueba en el banco; un modelo, no.

---

## Lo que NO va a tener sin un LLM, y conviene no engañarse

Conversación abierta, entender una frase que no ha visto nunca, escribir texto largo con
sentido. Eso **es** el modelo y no se sustituye con reglas. Pero eso ya lo tiene prestado por
API, y para su uso real —abrir cosas, volumen, juego, recordatorios— **el LLM es lo de menos**.

## Cómo se sabrá si funciona

Lo mismo que en todo lo demás: **con el banco y con el registro de uso**.
- una acción verificada que falla y se corrige debe tener su caso en el banco;
- los `fino-invento` y los `error` tienen que **bajar**;
- y las órdenes resueltas en local, subir.

Si una de estas piezas no se puede medir, es que no se ha entendido bien todavía.
