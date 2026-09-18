# Qué sabe hacer Nova hoy

*Estado a 18/09/2026. Todas las cifras están medidas, no estimadas: salen del banco de pruebas,
del registro (`assistant.log`), de `memoria/estadisticas.json` y del historial de git.*

---

## El salto de estos ocho días

| | 10/09 | 13/09 | 16/09 | **18/09** |
|---|---:|---:|---:|---:|
| líneas de `assistant.ps1` | 2.564 | 11.465 | 14.957 | **15.965** |
| funciones | 72 | 240 | 317 | **336** |
| probadores | **0** | 26 | 41 | **59** |

El 10/09 era un script de 2.564 líneas **sin una sola prueba**. Hoy hay **59 probadores** y 56
bloques de banco que se pasan enteros antes de cada commit. 290 commits en total.

**El oído, que es la meta número 1** (medido con grabaciones reales, no con texto):

| | antes | ahora |
|---|---:|---:|
| órdenes entendidas hablando | 55 de 90 (**61 %**) | 74 de 90 (**82 %**) |
| tiempo de `base` por frase | 0,97 s | **0,78 s** |

Y en el banco de hoy: **88/89** y **183/186** órdenes escritas, **20 de 20 (100 %)** con voz
real, y **3 de 97** en ruido (aquí cuanto más bajo, mejor).

---

## Lo que sabe hacer, por áreas

### Oírte
- Escucha continua por la palabra **«nova»**, o manteniendo el botón ≡ 1,1 s.
- Cascada de oído, cada escalón solo si hace falta:
  **Vosk** (la palabra) → **Parakeet** → **Whisper base** → **small** (oído fino) →
  **turbo** (último recurso) → **Gemini** (nube).
- **Se calla sola** si el micrófono caza ruido en racha (3 descartes en 5 minutos → 10 min).
- Filtra los **recitados**: cuando Whisper devuelve su propia frase de ejemplo o enumera tu
  biblioteca, eso no es una orden.
- **108 correcciones** de erratas de transcripción («yutub» → «youtube»).
- **Solo te obedece a ti**: compara el tono de voz (tu referencia, 116 Hz) y pregunta antes de
  lo peligroso si no te reconoce.
- **Modo invitado**: con otra persona hablando, no aprende nada ni toca tus datos.

### Hacer cosas
- **24 apps**, **14 sitios**, **9 buscadores**.
- **5 modos**: juego, noche, trabajo, cine, silencio. Se pueden crear y cambiar hablando.
- Volumen, brillo, música, «reproduce el **vídeo número 3**» de YouTube.
- Listas (se llenan, se leen, se tachan, se vacían), recordatorios, despertador, fechas
  señaladas (cumpleaños, que vuelven cada año).
- Apagado y reinicio programados, instalar juegos, reglas atadas a descargas de Steam.
- **Correo por voz**, y nunca envía sin un sí explícito.

### Con los juegos
- Sabe **qué juego tienes delante**, dónde lo dejaste y cuánto llevas jugado hoy.
- Cuánta batería te come cada juego, y tus **logros de Steam**.
- Con un juego abierto: solo botón, avisos sin voz, y silencio para lo que no es urgente.

### Recordar y conversar
- Charla con **API** y **modelo local de respaldo** si la API falla.
- **Cerebro propio**: lo que contesta la API se guarda *firme*; lo del modelo local entra
  *provisional* hasta que se revisa. Nunca guarda nada que dependa de la fecha, ni claves,
  ni dinero, ni salud.
- **Diario por días**, resumido en viñetas con el modelo local (tus conversaciones nunca van
  a la API para esto).
- **Perfil**: lo que sabe de ti, y olvida lo que le digas que olvide.

### Aprender sola
- **Recetas** con variantes: «crea una nota en el escritorio **que diga** X» aprendió sola que
  «**llamada** X» es lo mismo.
- **Traducciones** de tus frases a órdenes que entiende.
- **Reglas**: «cuando te pongas los cascos, baja el volumen».
- Detecta tus **costumbres** y te propone automatizarlas (y si dices que no, no insiste en
  60 días).

### Avisarte con criterio
Batería, disco lleno, descargas terminadas, cascos, dock, Gmail lleno, hora de dormir, y
«hoy me estoy equivocando más de lo normal».

Con **frenos**, que es lo que hace que no canse: jugando calla, de noche calla, tope de 4 por
hora, nunca mientras hablas o dictas, y los de poca monta se ven sin decirse.

### Cuidarse sola
- **Se revisa a sí misma** una vez al día y apaga lo que no le sirve — y puedes **deshacerlo
  hablando**: «deshaz lo que has cambiado».
- Si no puede explicar una decisión con un número, no la toma. Y si los datos no llegan,
  **te lo dice** en vez de callárselo.
- **Copia de seguridad diaria** (14 con rotación) con gemela en OneDrive.
- Avisa si **arrancó a medias**, no carga un modelo si no cabe en la RAM, y sobrevive a un
  `config.json` roto.
- Escribe un **parte semanal** contándote qué decidió, con qué dato y si te lo deshiciste.

### La cápsula
Avatar con gestos y pulsos, tarjeta para respuestas largas que no te saca del juego, siempre
encima sin robar el foco, panel rápido con doble toque y vibración del mando.

---

## Lo que NO sabe hacer

- Conversación abierta **sin la API**.
- Entender una frase que no ha visto nunca sin recurrir a un modelo.
- **Recuperar de su memoria**: tiene 32 recuerdos y los 32 están a **0 usos**. Nunca ha
  traído uno a una conversación.
- **Comprobar que lo que hizo salió bien**: abre Steam y da por hecho que se abrió.

Eso último es el proyecto siguiente: **`NOVA-LLM.md`**.

---

## La advertencia honesta

Nova **no se usa desde el 16/09 a las 22:00**, y desde entonces se han metido **1.354 líneas**
nuevas. Todo eso está probado en el banco, pero **no validado con tu voz**. Hoy, un día de uso
real vale más que cualquier función nueva.
