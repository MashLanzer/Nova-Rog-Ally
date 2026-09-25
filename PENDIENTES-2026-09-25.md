# Lo que queda en Nova, contado entero — 25 de septiembre de 2026

*Barrido de los 34 documentos y del código, con ocho lectores en paralelo y un revisor que les
buscó los fallos. De **155 pendientes en bruto**: 25 accionables, 8 esperando datos, 10
decisiones tuyas, 41 ya hechos o descartados. Cada línea lleva el dato que la sostiene o dice
que no lo hay.*

---

## 0. Tres cosas que circulaban mal, y que conviene corregir antes de que nadie las trabaje

1. **El aviso de dos horas de juego NO ha disparado nunca con el código de hoy.** Las dos
   líneas del registro que lo parecen (`assistant.log.1:19843` del 15/09 y `:50043` del 24/09)
   están en el **formato viejo** —decían *"2 horas con It Takes Two"*—; el código de hoy
   escribe minutos (`assistant.ps1:27821`) y el aviso por día entró el 23/09. Desde entonces
   `memoria/juegos.json` da 97, 116 y 94,7 minutos: **cero oportunidades**, tope 120.
2. **`traducciones.json` y `reglas.json` viven en la RAÍZ, no en `memoria/`.** Lo dice el
   propio código: `$TraduccionesPath = Join-Path $LogDir "traducciones.json"`.
3. **El deshacer no colgaba de `juegoSeLlama`.** El camino real es el de **rechazo**
   (`Invoke-AprenderDelError`, con `$script:ultimaAprendida`), que es el que se arregló hoy.

Y una cuarta, de cobertura: el barrido leyó **12 de los 34** `.md`. Los dos que más pendientes
vivos guardan quedaron fuera: **`AUDITORIA-2026-09-22.md`**, que confiesa por escrito *13
hallazgos sin juzgar* («no están descartados: están sin juzgar»), y **`jarvis-pendiente.md`**,
que bloquea una familia entera de ideas con cuatro condiciones que nadie ha reconciliado con el
código. Eso sigue sin hacer.

---

## 1. Hecho hoy

| Qué | El dato que lo justificaba |
|---|---|
| **La corrección que niega lo mal oído** — *"No dije Discord, dije Steam"* | Aprendió `'cierra este in' = 'cierra discord'` a la 01:26:12 y **no lo deshizo** cuando la corregiste 17 s después. Seguía en disco esta mañana, apuntando a la app por la que hablas con tu pareja. Pediste cerrar Steam **cuatro veces** en 86 segundos y no lo conseguiste |
| **El veto de música de una frase mal oída** | La **única** entrada que ha tenido `musica-no.json` en su vida era basura (`si es resting`), del mismo *"cierra Steam"*. Y `no quiero` casaba con **1 frase en 14 días**, que tampoco era música |
| **La pregunta de los amigos, como la dices tú** | Los tres patrones cogían **0 de 3** de tus formas reales. Las dos veces que lo pediste se fue al agente: **48,7 s y 70,5 s** contra ~166 ms de la API, con la clave ya puesta |
| **Un banco que no corría nadie** | `probar-microfono.py`, escrito el 22/09, sin correr **nunca**. 198 bancos y 199 secciones: el empate parecía decir que estaban todos |
| **Dos rojos de la tarjeta que eran el teclado táctil** | La captura salía del teclado, que tapa la esquina. Engañaba en las tres a la vez porque también es oscuro |
| **Una frase que decía lo contrario de lo que hace** | *"no tienes contactos importantes; todos los mensajes avisan igual"* — sin contactos no se avisa de **nadie** por su nombre |
| **El número del turbo, con sus dos caras juntas** | `turbo-sirvio` = 1 de 29 cuenta *"salió orden"*; el repaso a mano cuenta *"transcribió mejor"*, 15 de 29. No se contradicen, y para esa decisión manda el 1 |

| **«¿Seguimos con »** — el saludo que se quedaba a medias | `"$jg?"`: en PowerShell 5.1 la interrogación es carácter válido de nombre de variable. Salió vacía **en producción** (`assistant.log:6458`) y la frase rota se guardó en `habitos.json` |
| **«Este es el día 4 seguido con X»**, escrita y muda | `Get-DiasDeJuego` leía `dias` con `.PSObject.Properties` y `Save-TiempoJuego` lo reescribe como **hashtable**; y comparaba con la fecha natural mientras los días se cortan a las 05:00 |
| **`muévete a la derecha`** | lo pediste **4 veces** en 14 días y el patrón cogía **0**: exigía las dos coordenadas juntas |
| **La noche aprendida** en el saludo de vuelta | `Get-NocheDesde` ya la calcula y solo la usaba un sitio |
| **La regla 6, que no vigilaba nadie** | se coló un banco con letras raras y sin BOM, y la batería entera pasó en verde |

Y **dos rojos más que no eran de Nova**, los dos del mismo tipo — *un rojo que depende de lo que
tengas delante hoy no dice nada del código*:

- El de la **tarjeta**: la captura salía del **teclado táctil**, que tapa la esquina.
- El de **«a qué podemos jugar los dos»**: el banco llevaba **«elden ring» escrito a fuego** y
  `Find-Juego` mira la biblioteca de verdad. Cambiaste ELDEN RING por **ELDEN RING NIGHTREIGN**
  y el banco se puso rojo sin que nadie tocara una línea. Ahora coge un juego que de verdad
  tengas instalado, y si no hay biblioteca lo dice y salta esas dos frases.

Cada uno con su banco, y **cada banco roto a propósito**: **21 roturas, todas en rojo**. Cuatro
de ellas destaparon fallos **en mis propios bancos**, no en el código — entre ellos uno que
ponía un doble encima de la función que estaba rota, y otro cuyos casos negativos no llegaban
a tocar lo que decía vigilar.

---

## 2. Accionables, por lo que valen

**Lo que más vale es lo más barato:** *Nova no arranca con Windows*. De 22.081 s de juego
medidos contra el registro de Steam, **19.501 s (el 89,8 %) caen con Nova apagada**, y el 100 %
de esos huecos termina con un *"VoiceAssistant iniciado"*. La carpeta de inicio tiene hoy dos
ficheros y ninguno es Nova. Ese acceso directo desbloquea a la vez **tres mediciones** que hoy
no se llenan: el aviso de tiempo de juego, la batería por juego sin cargador y las 20 pasadas
de canary. **Es tuya la decisión de si quieres que arranque sola.**

### Acercan la meta del 100 % de comprensión
- **`si es X` no se lee como `cierra X`.** `$VERBOS_OIDOS` solo mira la **primera palabra**, y
  «si es» son dos. Medido: las **4** frases que empiezan por `si es` en 14 días son las cuatro
  un *cierra X* (`si es steam`, `si es en navego`, `si es la administrador`, `si es a los
  ajutos`), y hay **5** más con `cierre`. Pide dos guardas para ser segura: que no haya una
  confirmación esperando, y que lo de detrás sea algo abierto **ahora mismo**.
- **`muévete a la derecha de la pantalla`** — los dos patrones exigen las **dos** coordenadas
  juntas y acaban anclados, así que ni una sola ni la coletilla.

### Polish con dato, sin riesgo
- **Las letras de cada frase se tiran** (`Add-VozTiempo` las recibe y no las guarda), y sin
  ellas el plazo de la voz solo podrá bajar para siempre.
- **El «p99» del plazo es literalmente la peor muestra**: con n=50, el índice p99 es 49, que es
  el último. p99 = máximo = 63,3.
- **`HILOS_PRECISO` sigue en 8** en un chip de 4 núcleos físicos, y `tools/medir-hilos-whisper.py`
  (del 20/09) no se ha corrido nunca.
- **El plan local falla 14 de 18** (22 % de acierto) y ninguna revisión propia lo mira, aunque
  el turbo sí se juzga con el mismo listón.
- **Tres funciones muertas** que sus bancos disfrazan de vivas — una manera nueva de salir verde
  mintiendo. (Y `Get-PrimerVideoYouTube` **no** es de esas: es código muerto con cero cobertura,
  solo la llama `tools/cerrar-ronda.ps1`.)
- **40 de los 59 contadores** no salen en ninguna tabla que se mire: `$rutas` es una lista fija
  de 21 nombres mientras el JSON guarda todo.
- **`llamada-en-juego`** se escribe (10 casos en 4 días) y no lo lee nadie.
- **`Test-BuenRatoParaTrabajo`** solo la usa la copia de seguridad, teniendo dos llamadores.
- **Los resúmenes semanales** se escriben (2 ficheros) y no los lee nadie.
- **El enmascarado de la clave de Steam** está repartido en **cuatro** sitios; el documento
  decía tres, o sea que ya creció.

### Más grandes
- **Nova conoce 14 juegos de 92**: falta `GetOwnedGames`. Cuelgan cuatro ideas de esa petición.
- **El perfil entero (36 datos) viaja a Claude en cada petición**, y la maquinaria para
  recortarlo ya existe.
- **6 de los 36 datos del perfil son inventos** del revisor (cuatro de «Amino», dos de
  «Meramiau»): el 17 %.
- **Las 28 expresiones frágiles de los bancos siguen las 28**: lo que se hizo fue el trinquete
  que impide que crezcan, no el arreglo.
- **Los logros avisan de que pasó algo pero no de cuál**, y el 25/09 pasó **cinco veces
  seguidas** con el mismo juego.

---

## 3. Esperando a que se llene — con lo que llevan hoy

| Qué | Cuánto lleva | ¿Ya se puede? |
|---|---|---|
| El corpus de uso real | **533 grabaciones** del 15 al 25/09, `registro.jsonl` con 981 líneas y 533 ids | **Sí. Esto ya no espera** |
| La cascada canary | **0 de 20**, y no es un fallo: el contador se commiteó **hoy a las 10:53** (`86bf2ab`) y la Nova que corre arrancó a las **09:45**, así que no lleva ese código — y desde las 10:53 no ha habido ni un repaso. Empezará a contar **cuando reinicies Nova** | No |
| La batería por juego | **1 muestra** en doce días | No |
| El dato humano que haría medible el 100 % | **0 de 554**: ninguna línea de `destinos.jsonl` lleva `dicho-por-ti` | No |
| Una regla viva | `reglas.json` sigue con 2 bytes | No |
| Juegos zombis | el caso **no ha ocurrido nunca** en 14 días | No |
| Propuestas de hábito | **cero** propuestas, con 34 usos apuntados | No |
| La música | 12 entradas en 3 días, ninguna desde el 20/09, y 5 son anuncios | No |

---

## 4. Lo tuyo, que no puedo decidir yo

1. **Que Nova arranque con Windows** (el 89,8 % de arriba).
2. **Tu apodo.** El único que Nova cree saber es basura de transcripción.
3. **Si puede tener opiniones y manías propias.** Las ocho entradas de «estilo» son
   preferencias tuyas; ninguna es de ella.
4. **El contexto de la charla por significado**: +3,6 puntos de acierto por **2,87 s** de espera
   por turno. Con «velocidad sobre todo», no me parece una victoria clara.
5. **Poner los juegos en «ventana sin bordes»**: arregla de golpe que la cápsula no se vea en
   pantalla completa exclusiva y que el audio se corte. Es un ajuste en cada juego.
6. **Quitar el segundo motor de transcripción**: ~2 s por orden a cambio de comprensión.
7. **Bajar el `holdMs` de 1100 ms**: la medición dice que no hace falta.
8. **Limpiar los ocho datos mal oídos del perfil** preguntándote un par.
9. **Revocar la `ANTHROPIC_API_KEY`** que salió en claro el 13/09.
10. **Crear en Discord los atajos** `Ctrl+Shift+M` y `Ctrl+Shift+D`.
11. **Una regla viva**: el ciclo entero funciona y nunca ha disparado, porque no hay ninguna
    guardada.

---

## 4 bis. Las 50 de autonomía, recontadas contra el código

`IDEAS-ESTADO-2026-09-25.md` cierra **26 de las 50**. Las **24 restantes** no las mira ese
documento, así que las repasaron cinco agentes **en el código**, no en el papel. Resultado:

- **7 ya las hace Nova** y el documento se quedó atrás. La 20 (qué juego te gasta la batería)
  existe **desde el 13/09**; la 19 (la noche tuya) se hizo **hoy** bajo otro número; la 28, la
  32, la 39, la 40 y la 45 están enteras.
- **8 descartadas con dato.** La lápida del perfil **sí existe** (`perfil-caidos.md`, creado hoy
  a la 01:25). La música tiene **un solo título repetido** en 12 entradas, y las dos veces el
  mismo día. Y la 31 se cae porque su premisa es falsa: los dos datos que enseñaste a mano
  **no se los llevó el tope, los borraste tú**, y está en el registro.
- **2 no se pueden decidir**: el conteo es cero (la 17 tiene **4** muestras de cargador).
- **1 es decisión tuya** (la 44, las manías, que es la misma que la 43).
- **7 vivas, y las siete son pulir código que ya está escrito.** Ninguna añade nada.

**De esas 7 ya van tres hechas hoy:**

| # | Qué era | Lo que lo demuestra |
|---|---|---|
| **41** | *"¿Seguimos con "* salía **vacía** | En PowerShell 5.1 la interrogación es carácter válido de nombre de variable, así que `"$jg?"` es la variable `$jg?`. Salió en producción: `assistant.log:6458`, 25/09 10:57:58. Y la frase rota **se guardó** en `habitos.json`, ocupando plaza en el filtro de no repetir |
| **48** | *"Este es el día 4 seguido con X"* llevaba **muda desde siempre** | `Get-DiasDeJuego` leía `dias` con `.PSObject.Properties`, pero `Save-TiempoJuego` lo reescribe como **hashtable** en cuanto juegas cinco minutos: devolvía `Keys`, `Values` y `Count` en vez de fechas. Y comparaba con la fecha natural mientras los días se guardan cortando a las 05:00 |
| **19** | La noche aprendida, en el saludo de vuelta | `Get-NocheDesde` ya la calcula y solo la usaba `Test-PuedoAvisar`. *(En `Get-AvisoHoraDormir` NO se ha tocado: ahí el mismo cambio rompe la salida temprana si la noche cae en la madrugada. Pide su propia medición.)* |

**Y el 48 destapó una manera nueva de que un banco salga verde mintiendo:** `probar-juego-notado.ps1`
ponía un doble **encima de la función rota**, así que probaba su propio doble. Ahora el doble
está un escalón más abajo —en el fichero— y las dos formas del campo `dias` se prueban de verdad.

**Quedan 4 vivas**: la 22 (bajar `holdMs` — **es decisión tuya**, toca cómo se siente el
gatillo), la 37 (leer las dos notas semanales que nadie ha leído nunca), la 38 (`Get-FraseAnimo`
está escrita, con banco, y **sin un solo llamador**) y la 49 (el logro no se cuenta a sí mismo:
`nova_ui.cs:2642` se salta `Gesto()`, y 'logro' sale **0 veces** en 3.434 líneas de `gestos.log`
— pero toca recompilar la cápsula).

---

## 5. Y una cosa que encontré tirando de otro hilo

**La cápsula puede estar tapada y Nova no se entera.** Vive en `abajo-izquierda` (banda visible
≈ y 592–636), y el **teclado táctil** de Windows ocupa ≈ y 365–720 a todo el ancho: la tapa
entera. No se aparta porque `nova_ui.cs:2835` decide «me tapan» con `GetForegroundWindow()`, y
el teclado táctil **nunca** es la ventana en primer plano —es NOACTIVATE por diseño, para no
robarle el foco a lo que escribes—. Y la detección de «cápsula ciega» tampoco lo caza: esa va
por el **cambio de resolución**, que el teclado no provoca.

Rompe la regla 2 de la casa: si lo único que sale va a la cápsula y la cápsula no se ve, no ha
salido por ningún lado. **No está medido** cuántas veces coinciden «teclado abierto» y «Nova
quiere decir algo»: el teclado no deja rastro en el registro.

El arreglo no es el mismo que el de la tarjeta: `WindowFromPoint` sirve con la tarjeta porque
no es transparente al ratón, y la cápsula **sí** lo es (`nova_ui.cs:821` y `:829`). Para ella
hay que recorrer el orden de ventanas hacia arriba y mirar si alguna corta su rectángulo.
