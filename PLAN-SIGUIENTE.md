# Plan siguiente — 18/09/2026

*Nueve equipos exploraron nueve zonas de Nova, propusieron 60 ideas y cada una pasó por tres
lentes adversariales (`ya_existe`, `sin_datos`, `rompe_algo`). Este documento es el resultado, con
las objeciones dentro: **son la parte más útil**. Todas las cifras llevan de dónde salen; las que
he medido yo hoy lo dicen.*

---

## 1. El resumen honesto

**El balance es «menos de lo que parecía», y bastante menos.** De 60 ideas sobrevivieron intactas
**8**; otras 14 entran **recortadas**, casi siempre porque el diagnóstico era correcto pero el
arreglo propuesto rompía algo; y **38 se caen**. El reparto de por qué se caen repite el patrón de
siempre en este proyecto: **ya existía** (la mitad del filtro de ruido corto, el aplazamiento de
avisos mientras dictas, la cobertura de traducciones y recetas en el banco, apuntar los aplazamientos
de decisiones), **no hay datos** (cuatro ideas apuntan a caminos con 0 ocurrencias en 26.811 líneas
de registro), o **el arreglo rompe el camino bueno** (limpiar `$script:jobMotor` en `Clear-OpencodeJob`
mata las 68 llamadas a Claude Code; meter «mira» en las muletillas tira una orden que hoy funciona;
la fórmula nueva de la barra empieza en el 65 %). Y una lección nueva y cara: **tres equipos
distintos propusieron el mismo arreglo de la misma variable y ninguno vio que el otro lo estaba
proponiendo** — es el `$script:ultimoUsoEn` declarado dos veces, y sí es un fallo real.

**Lo que sí se puede mejorar de verdad es poco pero concreto**, y casi todo cae en dos sitios: la
**función que pidió braya** (el saludo al volver, que existe a medias, nunca ha salido ni una vez y
tiene dos frases fijas) y la **medición de la meta nº 1**, que hoy tiene dos agujeros comprobados:
el fichero `pruebas/audio/uso/destinos.jsonl` **no existe todavía** y la guarda de 5 minutos que
protege «no era eso» **no vence nunca**, porque otra función le pisa el reloj cada 30 segundos.
Fuera de eso, la mayor parte de lo que se propuso arregla cosas que **no han ocurrido nunca**: el
agente no se cancela desde el 11/09, el PLAN no se ha ejecutado ni una vez, la revisión propia no ha
tomado ninguna decisión, y Nova **no se usa desde el 16/09 a las 22:00**. Eso hay que decirlo sin
rodeos: **varias piezas de este plan no se pueden juzgar hasta que braya use Nova unos días**, y
están marcadas una por una.

---

## 2. LA FUNCIÓN QUE PIDIÓ braya — «has vuelto a la consola» ✅ **HECHA el 18/09**

> **Estado:** implementada y en el banco (`tools/probar-vuelta.ps1`, bloque `2n30`, 26 casos en
> verde). Tres decisiones que este plan dejaba abiertas y se tomaron al escribirla:
>
> 1. **El saludo sale solo ante la señal del mando.** Desde el bucle a secas saludaría a una
>    habitación vacía en cuanto pasaran 45 minutos, y al recibir una orden hablada sonaría encima
>    de su propia respuesta. Hablarle **sella** presencia, pero no dispara el saludo. «Tomar la
>    consola en las manos» es literalmente lo que se pidió.
> 2. **`Test-VueltaSaludo` corre ANTES de sellar la presencia.** Sellando primero, la ausencia
>    sería siempre 0 y no saludaría jamás: el mismo fallo que E1 con otra ropa.
> 3. **La marca de presencia no baja al disco en cada pulsación.** El bucle va a 30 ms y
>    `Save-Habitos` reescribe el fichero entero: en memoria siempre, al disco como mucho una vez
>    por minuto. Un caso del banco lo vigila (50 pulsaciones → 1 escritura).
>
> Y una corrección sobre lo que decía este plan: el gesto no puede mandarse antes de `Send-Aviso`
> confiando en que la voz se calle sola. `Test-AvisoSinVoz` se consulta **antes** de elegir la vía,
> porque el gesto `saludo` de la cápsula llama a `Sonar(sonSuave)`: con un juego delante se oiría
> un ruido sin que nadie hable, que es peor que el saludo entero.
>
> Se retiró el `mando-vuelta` viejo (0 disparos en 9 días): hacía lo mismo peor, y dejar los dos
> era saludar dos veces.

> «cuando nova esté encendida, y pasa un tiempo sola, al tomar la consola en mis manos lo detecte y
> me salude de alguna forma, no siempre igual porque se vuelve repetitivo»

### 2.1. Lo que hay hoy, y por qué no funciona

Son **tres mecanismos que hacen lo mismo**, y los dos que importan están a cero.

| pieza | línea | cuándo dispara | canal | veces en 9 días |
|---|---|---|---|---:|
| `mando-vuelta` dentro de `Watch-Entorno` | 5649-5653 | 90 min quieto **y solo botones del mando** | voz, nivel `medio` | **0** |
| `Test-ResumenAlVolver` | 6181-6194 | 2 h sin orden **y solo si hay notificaciones** | cápsula, sin voz | **0** |
| saludo de arranque | 14506 | cada arranque | voz, **texto fijo** | **142** |

*(Recuentos míos sobre `assistant.log`, 26.811 líneas con hora, del 09/09 al 17/09: `grep` de
«mando-vuelta» = 0, «RESUMEN AL VOLVER» = 0, «saludo de arranque» = 142. Las únicas 7 líneas
`ENTORNO (` de toda la vida del proyecto son 3 `gmail-lleno`, 2 `descarga-` y 2 `bateria-llena`.)*

**Por qué `mando-vuelta` no puede salir casi nunca** — tres causas, las tres medidas:

1. **El reloj muere en cada arranque.** `$script:entornoUltimaActividad` (5638) se mide con
   `$sw.ElapsedMilliseconds`, el cronómetro del proceso. Hay **187 arranques en 9 días** con
   mediana de sesión de **5,8 min**: un contador que necesita 90 minutos dentro del mismo proceso
   casi nunca los junta.
2. **Solo cuenta el mando.** El disparo está dentro de `if ($botones -ne 0)`. Desglose exacto de
   las 803 líneas `DICTADO (` del registro: **380 seguimiento, 291 por la palabra «nova», 102 por
   botón (63 + 31 + 8 con la tilde rota), 30 dictado largo**. El botón es el **12,7 %**: hablarle
   no cuenta como estar presente.
3. **Es más nuevo de lo que parece.** Nació en el commit `93c43c3` del **16/09 a las 20:13**, y
   desde entonces solo hubo **9 órdenes reales** (21:43 a 22:00 del 16/09). No es que falle: casi
   no ha tenido ocasión. Hay que decirlo así para no exagerar el defecto.

**Por qué `Test-ResumenAlVolver` no puede salir nunca** — esto sí es un fallo de verdad: la función
hace `$script:ultimoUsoEn = $ahoraU` (6184) **siempre, antes de decidir nada**, y `Watch-Entorno`
la llama **cada 30 s** (5669). La diferencia no llega jamás a las 2 h de la línea 6183. Además
exige notificaciones pendientes (`$script:notifPendientes`, 5012), que **viven solo en RAM** y se
vacían en cada reinicio. Y de regalo, esa variable **está declarada dos veces** —en 1443 para
`Write-FalloUso` y en 6179 para el resumen— o sea que además ensucia la medición de la meta
(ver idea **E1** de la sección 3, que es la mitad seria de esto).

### 2.2. Las señales de detección, con su coste

| señal | de dónde sale | coste | ¿entra? |
|---|---|---|---|
| **orden hablada** | `Process-Texto` (13760), por donde pasa todo lo que dice | 0 (ya se ejecuta) | **sí** |
| **botón / panel** | `Watch-Entorno $botones` (5646), el bucle ya lee los 4 mandos por XInput | 0 (ya se lee) | **sí** |
| **teclado y ratón** (`GetLastInputInfo`) | no existe en el proyecto (0 apariciones en `assistant.ps1`, `assistant-dx.cs`, `nova_ui.cs`, `wake_vosk.py`) | 2-4 µs por llamada, medido | **NO en v1** |

**Por qué el teclado se queda fuera, aunque es la señal que más gente usaría.** Dos motivos
medidos, y el segundo es descalificante:

- Ahora mismo devuelve **~13 horas sin entrada** con 80 h de encendido: braya usa la voz, así que
  esa señal diría «ausente» estando él delante.
- **Nova se pisa su propia señal**: `GetLastInputInfo` cuenta también la entrada sintética, y Nova
  genera teclado desde **32 sitios** con `[AX]::keybd_event` (`Send-Key` 160-172, Alt+F4 y Alt+Tab
  8086-8087, teclas de medios 5396, combos con Win/Alt 9534-9542 y 10698-10718). Cada vez que Nova
  escribe o baja el volumen por teclado, el reloj de «última entrada» se pone a cero y la señal
  diría «está delante» sin que braya haya tocado nada.
- Además obliga a recompilar `assistant-dx.dll`, y `assistant.ps1:10806-10826` compara su SHA256
  contra `config.json → seguridad.hashDll` y avisa con «ALERTA: assistant-dx.dll NO coincide».

*Si algún día hace falta, la fase honesta es la que propuso el equipo: apuntar en el log los
segundos sin teclado cada 5 minutos durante 3 días, **sin saludar**, y cruzarlo con los `DICTADO`.
Hoy no hace falta: con voz + botón se cubren el 100 % de las interacciones registradas.*

### 2.3. Dónde vive la marca de presencia

**En `memoria/habitos.json`, clave nueva `presencia`.** No en `tmp/avisos-vistos.json`, y esto es
importante: `Get-EntornoVistos` (5532) **solo lee el disco si la tabla está vacía**
(`if ($script:entornoVistos.Count -gt 0) { return }`). Si la presencia se escribiera ahí antes de la
primera lectura, el fichero dejaría de leerse en esa sesión y el primer `Save-EntornoVistos`
borraría las **4 claves reales** que hay hoy (`gmail-lleno`, `bateria-llena` y dos `descarga-`).
Sería reintroducir el fallo que arregló el commit `7373ffe`.

```
"presencia": {
    "visto":   "2026-09-18 19:41:07",   // última señal de braya (hora de RELOJ)
    "saludo":  "2026-09-18 19:41:09",   // cuándo se saludó por última vez
    "frases":  ["Anda, ya estás aquí.", "Mira quién vuelve.", "Buenas. ¿Retomamos?"]
}
```

**Trampa documentada que hay que respetar:** `Get-Habitos` (5181) y `Save-Habitos` copian
**campo a campo**; una clave nueva hay que añadirla en **las dos** o se pierde en el primer
guardado. Ya pasó con `minutosJuego`. Y `memoria/habitos.json` está en `.gitignore` (línea 62), así
que no hay problema de privacidad con el repo público.

**Coste:** ninguno nuevo. `Set-UsoAhora` (6201) ya llama a `Save-Habitos` **en cada orden**, y ese
guardado está medido en **1,33 ms** (200 escrituras en 265,7 ms con el fichero de 4.768 bytes).

### 2.4. Cómo se cuenta la ausencia

```
ausencia = ahora - max(presencia.visto, arranque del proceso + 60 s)
```

La segunda mitad es la que evita el saludo falso, y sale de los datos: **de los 55 huecos de 20
minutos o más que hay en el registro, en 30 hubo un arranque de Nova dentro**, y en esos Nova ya
saludó al arrancar (142 veces). Saludar otra vez sería decir hola dos veces en pocos segundos.

### 2.5. Los umbrales, con la medición que los elige

Medido por mí hoy sobre `assistant.log` (9 días). «Interacción» = línea `[escucha] dictado: '...'`
con texto, `DICTADO (`, `PANEL RAPIDO` o `CONFIRMAR`; 1.301 en total. «Nova viva todo el hueco» =
el registro no está mudo más de 10 minutos seguidos dentro del hueco (con Nova encendida el latido
escribe constantemente; es lo que distingue «estuvo sola» de «estuvo apagada»).

| umbral | huecos | **con Nova viva todo el rato** | vuelta entre 23 y 8 | saludos/día reales |
|---:|---:|---:|---:|---:|
| 20 min | 55 | 25 | 6 | 2,8 |
| 30 min | 40 | 15 | 6 | 1,7 |
| **45 min** | 33 | **10** | 6 | **1,1** |
| 60 min | 24 | 6 | 6 | 0,7 |
| 90 min (lo de hoy) | 17 | 5 | 4 | 0,6 |
| 180 min | 13 | 3 | 3 | 0,3 |

**Esto zanja una discusión entre dos equipos.** Uno proponía 45 min contando solo los dos días de
`registro.jsonl` (7 vueltas en 2 días = 3,5/día, que cansaría); otro decía que 45 min daban 3,4
saludos al día sobre la muestra grande. Los dos contaban huecos en los que **Nova estaba apagada**,
que son los que ya cubre el saludo de arranque. Filtrando por «Nova viva», **45 minutos dan 1,1
saludos al día**: ese es el número bueno.

Las 10 vueltas reales con Nova encendida, para que se vea qué se está saludando:

```
10/09 23:50 -> 11/09 01:09    79 min   vuelve 01:09
11/09 16:46 -> 11/09 17:31    46 min   vuelve 17:31
12/09 20:13 -> 12/09 21:12    59 min   vuelve 21:12
15/09 15:54 -> 15/09 16:44    49 min   vuelve 16:44
15/09 16:44 -> 15/09 17:31    47 min   vuelve 17:31
15/09 18:30 -> 16/09 00:45   374 min   vuelve 00:45   <- con It Takes Two delante
16/09 01:00 -> 16/09 09:55   536 min   vuelve 09:55
16/09 10:01 -> 16/09 11:41   100 min   vuelve 11:41
16/09 11:51 -> 16/09 19:25   454 min   vuelve 19:25
16/09 19:46 -> 16/09 21:43   117 min   vuelve 21:43
```

**Decisión: dos escalones.**

| ausencia | canal | cuántas veces habría salido en 9 días |
|---|---|---|
| **45 min – 3 h** | cápsula: `Set-UI 'hablando' <frase> 4500` + `Send-UIEvento 'gesto:saludo'` | 6 |
| **3 h o más** | voz (una frase corta) **+** cápsula | 4 (y una de ellas, la de las 00:45, cae en la franja de noche → se queda en cápsula) |

### 2.6. El mecanismo de variedad

**El patrón ya está escrito en casa y funciona:** `assistant.ps1:15047-15048`, el relleno de la
charla —`Get-Random` sobre la lista **filtrando la última dicha**, y guardando la elegida en
`$script:ultimoRelleno`—. Su propio comentario dice la lección: *«variadas y NUNCA la misma dos
veces seguidas (14/09): con tres, se repetían»*, por eso hay ocho.

Dos cambios sobre ese patrón, y los dos salen de datos:

1. **Filtrar las 3 últimas, no solo la anterior**, y guardarlas **en disco** (`presencia.frases`).
   `$script:ultimoRelleno` solo existe en memoria (grep: aparece en 15047 y 15048 y en ningún sitio
   más), y con 187 arranques en 9 días una memoria de proceso se olvida constantemente.
2. **Variar también el saludo de arranque.** Es el que de verdad oye braya: **142 veces la misma
   frase** («Listo. Di nova cuando me necesites.») frente a las 10 vueltas de 9 días que saludaría
   la función nueva. Si la variedad rinde en algún sitio, es ahí. *(Lo que NO se toca: el texto de «arranque a
   medias» de 14509-14513, que es información, no saludo.)*

**Ojo con las bolsas sueltas:** hoy hay **tres sorteos independientes que no se conocen entre sí** —
el de `hola` (2232: «Hola. Dime.», «Aquí estoy. ¿Qué hacemos?», «Hola, te escucho.»), el relleno de
la charla y el saludo nuevo—, y además los cinco grupos de 2231-2236 usan `Get-Random` **sin filtro
ninguno**. Que la memoria de 3 sea compartida, o se estará moviendo el problema de sitio.

### 2.7. Las frases

Reglas de forma, medidas: **por debajo de 40 letras**. `Say` (8898) calcula
`min(90000, len*70 + 1200)` ms de micrófono mudo, con un **suelo de 1,2 s**: una frase de 25 letras
ya son 2,95 s de sordera, y de 40 letras, 4 s.

| # | frase | condición |
|---|---|---|
| 1 | «Anda, ya estás aquí.» | cualquiera |
| 2 | «Mira quién vuelve.» | cualquiera |
| 3 | «Buenas. ¿Retomamos?» | cualquiera |
| 4 | «Por aquí, todo tranquilo.» | cuando no hay nada que contar |
| 5 | «Cuánto tiempo.» | ausencia > 3 h |
| 6 | «Te hacía lejos.» | ausencia > 6 h |
| 7 | «Ya era hora, eh.» | ausencia > 6 h |
| 8 | «Buenos días. ¿Empezamos?» | primera vuelta del día, de 5 a 12 |
| 9 | «Hola. Que sepas que es tarde.» | franja 23-8 → **solo cápsula** |
| 10 | «¿Seguimos con {juego}?» | `Get-JuegoDeReferencia` devuelve algo |
| 11 | «Hola. Te dejaste {juego} a medias.» | ídem |
| 12 | «Ya está {descarga}, por si venías a eso.» | terminó una descarga durante la ausencia |

**Tres avisos honestos sobre esta lista:**

- **La 10 y la 11 casi nunca podrán salir hoy.** `Get-JuegoDeReferencia` (4907-4911) devuelve el
  juego de delante o el último de hace menos de 2 h, y `$script:ultimoJuego` **es de proceso**
  (se asigna solo en `Exit-Juego`, 10534). Tras un reinicio, nada. Y el «te quedaste en…» no puede
  decirse: `memoria/juegos.json` tiene **un solo juego** (`It Takes Two`) y **ninguna clave `nota`**
  — solo `dias`. Además `Show-RecuerdoJuego` (4989) ya enseña «te quedaste en…» **al entrar en el
  juego**, en cápsula y como mucho una vez por hora: no hay que decirlo dos veces.
- **La 12 puede duplicar un aviso que ya salió.** Las descargas terminadas se avisan por
  `Send-AvisoEntorno "descarga-$nm"` (16014) y ya dispararon 2 veces el 16/09 (Black Myth: Wukong
  20:50:16, Marvel's Spider-Man 21:12:17, las dos en `tmp/avisos-vistos.json`). Con otra clave, el
  freno no lo impide: **hay que consultar `$entornoVistos` por su clave `descarga-*` antes de
  meterla en el saludo**.
- **La 9 no es silenciosa aunque se quede en cápsula.** `nova_ui.cs:2393`, `case "saludo"`, llama
  `Sonar(sonSuave)`. A las 2 de la madrugada eso suena igual. De noche: `Set-UI` y **nada de gesto**.

### 2.8. Cuándo NO saludar

| caso | por qué | dónde |
|---|---|---|
| **en los primeros 60 s tras arrancar** | el saludo de arranque acaba de sonar (142 veces); dos saludos seguidos | guarda nueva |
| **si Nova arrancó dentro de la ausencia** | ya saludó al arrancar; 30 de los 55 huecos tienen un arranque dentro | lo resuelve la fórmula de 2.4 |
| **mientras dicta (`$script:armed`)** | el saludo saldría ~4 s después de pulsar ≡ (mantener ≡ son 1,1 s, `$HOLD_MS` línea 88) y `Say` deja el micro mudo 3 s **en mitad de la orden** | **no está puesto**: `Test-PuedoAvisar` (5552-5583) mira `busy`, `pendiente` y `dictandoLargo`, pero **no `armed`** |
| **con un juego delante** | `avisos.sinVozEnJuego` es `true` en `config.json` | solo cápsula, y sin gesto (por el `Sonar`) |
| **de 23 a 8** | franja de silencio | solo cápsula, sin gesto |
| **invitado, «no me avises», modo silencio, sordina** | ya son política de la casa | `Test-PuedoAvisar` (5549-5553) y `Test-AvisoSinVoz` (9478-9489) |
| **más de un saludo por hora** | `presencia.saludo` | freno propio |

**El camino correcto para la voz es `Send-Aviso`, no `Send-AvisoEntorno`.** Verificado:
`Send-Aviso` (9492-9498) **ya aplaza** si `$script:armed` está puesto y lo suelta cuando bajas el
dictado (15674-15679), y pasa por `Test-AvisoSinVoz`, que calla con juego delante, con sordina y en
modo silencio. `Send-AvisoEntorno` no hace nada de eso: sale por `Send-AvisoCola` → `Say` directo.

**Y una trampa que hay que esquivar sí o sí:** el `$quietoMin` de `Watch-Entorno` (5647) alimenta
**dos** disparadores: el saludo (≥90) y `Invoke-Reglas 'mandoCoge'` (≥5, línea 5657). Y `mandoCoge`
es `$dispara = ($dato -eq 'coge')` (10052), **sin la guarda `$r.ultima`** que sí tienen `hora` y
`cada`. Hoy no molesta porque el reloj se reinicia en cada pulsación; si la ausencia pasa a leerse
de disco y se queda alta toda la sesión, una regla como «cuando coja el mando, pon el modo juego»
se dispararía **en cada pulsación**, con el bucle a 30 ms. **La cuenta de presencia del saludo y la
de `mandoCoge` tienen que ser dos, o `mandoCoge` necesita su propio rearme.**

### 2.9. Cómo se prueba en el banco

**`tools/probar-vuelta.ps1`**, con los dos moldes que ya existen:

- de `tools/probar-entorno.ps1`: `Parser::ParseFile` + `FunctionDefinitionAst` para sacar la función
  **del archivo real** (líneas 9-13), dobles de `Say`/`Log`/`Show-Popup`, y `$EntornoVistosPath`
  apuntando a un fichero temporal con GUID. Su aviso vale oro y hay que copiarlo: la franja de noche
  se pone en `$hAhoraP + 2` porque **pasar el banco de madrugada bloqueaba 12 casos sin que nada
  estuviera roto** (líneas 19-26).
- de `tools/probar-autosordina.ps1` (líneas 26-28): el reloj falso, `$script:reloj` +
  `Add-Member ScriptProperty ElapsedMilliseconds`. Hace falta porque ni `Watch-Entorno` ni
  `Test-ResumenAlVolver` aceptan la hora por parámetro.
- **el molde malo que NO hay que copiar** es el de `probar-autosordina.ps1` en su versión vieja: su
  cabecera confiesa que durante un tiempo **imprimía el estado sin comparar nada y sin `exit 1`**.
  El bueno es el de `probar-entorno.ps1`: función `Comp`, contador `$fallos` y `exit 1` al final.

Casos (9):

1. 45 min fuera con Nova viva → saluda **en cápsula**, sin voz.
2. 20 min fuera → nada.
3. 4 h fuera, sin juego, a las 19:00 → saluda **con voz**.
4. 4 h fuera pero con un arranque dentro → **nada** (ya saludó al arrancar).
5. A los 30 s del arranque → nada.
6. Con `$script:juegoActivo` puesto → no llama a `Say` **ni a `Send-UIEvento`**.
7. A las 2 de la madrugada → cápsula, sin voz y sin gesto.
8. Con `$script:armed` puesto → no sale; al bajar el dictado, sale.
9. 12 saludos seguidos **reiniciando el estado de proceso entre medias** → ninguna frase repetida
   antes de la cuarta.

Se registra en `tools/probar-todo.ps1` como bloque **`2n30`**, con las tres líneas de siempre
(`Titulo`, `powershell -File`, `if ($LASTEXITCODE -ne 0) { $fallos++ }`). Pasaría de 60 bloques a 61.

### 2.10. Lo que NO entra en esta función, y por qué

| propuesta | por qué no |
|---|---|
| `GetLastInputInfo` como señal de presencia | Nova se pisa la señal con sus 32 `keybd_event`; y hoy marca 13 h «ausente» estando él delante |
| mover `$script:juegoActivo` para que `Exit-Juego` pueda hablar | `Exit-Juego` **no salta al cerrar el juego, sino al perder el primer plano**: de las 6 salidas del registro, **4 duraron menos de 2 minutos** (ELDEN RING 11 s, Little Nightmares III 20 s, Little Nightmares II 20 s, Little Nightmares III 83 s). Diría «Cerraste ELDEN RING» once segundos después de lanzarlo |
| quitar el `if ($partes.Count -eq 0) { return }` de 6191 | convertiría el resumen en saludo puro y chocaría con el saludo nuevo; además solo hay **10 líneas `NOTIFICACIONES:`** en 9 días |
| pasar la micro-charla («tres horas, un vaso de agua») por `Send-AvisoEntorno` | `Test-PuedoAvisar` mata **todo lo que no sea `alto`** con juego delante, nivel `bajo` incluido: las dos frases desaparecerían en vez de verse (ver **I3** en la sección 3, que sí propone el camino bueno) |
| reutilizar el reloj de `mandoCoge` | ver el aviso de 2.8: esa regla no tiene freno de rearme |

---

## 3. Las ocho áreas restantes

**Tabla de valor, mirando todo junto.** Orden por daño real, no por facilidad.

| # | idea | área | coste | veredicto |
|---|---|---|---|---|
| **E1** | `$script:ultimoUsoEn` declarada dos veces: la guarda de «no era eso» no vence nunca | errores | barata | **recortada** (el renombrado solo arregla la mitad) |
| **A1** | Una línea de cierre por trabajo en el registro | agentes | barata | **sobrevive** |
| **D1** | Mirar el interruptor antes de anunciar una decisión pendiente | decisiones | barata | **sobrevive** |
| **C1** | El banco de cadenas mide «la reconozco», no «hago las dos cosas» | encadenado | barata | **sobrevive** |
| **IA1** | El interrogativo suelto arrastra recuerdos que no vienen a cuento | ia | barata | **sobrevive** |
| **A2** | Medir la RAM del agente con un juego delante | agentes | barata | **sobrevive** (es medir, no cambiar) |
| **E2** | Los destinos neutros: que charla y agente dejen huella **sin consumir el id** | errores | media | **recortada** |
| **C2** | Que el PLAN abandone ante una confirmación pendiente | encadenado | media | **recortada** |
| **M1** | Las muletillas `ok/okey/vale/bueno`, **sin `mira`** | comandos | barata | **recortada** |
| **M2** | Que la lista de «no reconocido» **marque** lo ya resuelto (no que lo borre) | comandos | barata | **recortada** |
| **M3** | Que el prompt del traductor conozca correo, YouTube y cambiar de app | comandos | media | **recortada** |
| **I1** | Los asentimientos sueltos, a la cortesía que ya existe | interpretación | barata | **recortada** |
| **A3** | `'plan'` no está en las tablas de duración de la barra | agentes | barata | **recortada** |
| **A4** | La etiqueta del motor, puesta por cada lanzador | agentes | barata | **recortada** |
| **I3** | La micro-charla, por `Send-Aviso` | iniciativa | barata | **recortada** |
| **E3** | Que la queja que Nova sí arregla cuente como fallo | errores | barata | **recortada** |
| **I2** | El detalle de descartes **por trozo** | interpretación | media | **recortada** |
| **A5** | El bloque de recetas: condicionarlo por lo que rinde | agentes | media | **recortada** |
| **M4** | Que «baja la música» no abra la tienda de Steam | comandos | barata | **recortada, sin datos** |

---

### 3.1. Errores: identificar sus fallos y corregirlos

#### E1 — `$script:ultimoUsoEn` está declarada dos veces y la guarda de la meta no vence nunca ⚠ **lo más serio del plan**

**Qué pasa.** La misma variable la usan dos funciones con significados opuestos:
`Write-FalloUso` (declarada en **1443**, leída en **1448** con `-gt 300000`, los 5 minutos que
protegen «no era eso») y `Test-ResumenAlVolver` (declarada en **6179**, leída en **6183** con
`-ge 7200000`, las 2 horas de ausencia). Y `Test-ResumenAlVolver` **sella la variable en cada
llamada** (6184), desde `Process-Texto` (13760, correcto) y desde `Watch-Entorno` **cada 30 s**
(5669, el que rompe). Consecuencias:

- la guarda de 5 minutos **nunca vence**, así que un «no era eso» dicho tres horas después marcaría
  como fallo una orden de hace tres horas — justo lo que el comentario de 1447 dice que quiere
  evitar: *«un dato falso es peor que un dato que falta»*;
- y el resumen al volver no puede activarse jamás (0 apariciones en 26.811 líneas).

**Dónde se toca.** Renombrar la del resumen a `$script:ultimoHabloEn` en sus tres líneas
(6179, 6183, 6184) **y además** separar «cuándo estuvo braya» de «cuándo se comprobó»: la llamada de
`Watch-Entorno` (5669) solo **lee**; el sello lo pone únicamente la interacción real. Sin esa
segunda mitad el resumen sigue muerto — es la objeción que recibió la idea y es correcta.

**Riesgo.** `Write-FalloUso` alimenta el recuento de órdenes equivocadas, que es la meta nº 1:
se toca con `tools/probar-fallo-uso.ps1` delante.

**Cómo se mide.** Caso de banco con reloj falso: «no era eso» a los 4 min marca la orden, a los 6 no
(hoy ese caso sale **rojo**, que es la prueba de que el arreglo sirve). Y en uso real, que
«RESUMEN AL VOLVER» pase de 0 a salir en la primera ausencia larga.

**Objeción recibida** (`flojo`): *el renombrado arregla la mitad de `Write-FalloUso` pero deja el
auto-sellado de 6184 intacto, así que el resumen seguiría sin salir nunca.* Aceptada e incorporada
arriba. También hay que decir que el daño del lado de la meta **aún no ha ocurrido**: `destinos.jsonl`
no existe y no ha habido órdenes de voz desde que la pieza entró (`5a567b2`, 17/09 09:33).

#### E2 — Que la charla y el agente dejen huella, **sin robarle el id a la orden**

**Qué hace.** Hoy más de la mitad del uso real no entra en la cuenta de «¿acertó?». Medido sobre
`memoria/estadisticas.json`: el 15/09 hubo **142 eventos de rutas apuntables frente a 145 que no lo
son** (charla 69, traducir 54, acción 20, pregunta 2); el 16/09, 23 frente a 16. Y como la charla y
el agente no tocan `$script:ultimoUsoId`, un «no era eso» dicho tras una charla marca la última
orden **local** de hasta 300 s antes.

**Dónde se toca.** `assistant.ps1:1407` (`$DestinosUso`) y `tools/analizar-uso.py:30-31` (tercera
lista NEUTRO). **Recorte obligatorio:** los destinos neutros **no pueden consumir el id**, solo fijar
`$script:ultimoUsoId`.

**Objeción recibida** (`rompe_algo`, decisiva): *`Write-DestinoUso` (1416) **consume** el id, y una
sola orden dispara varias `Add-Estadistica` en cadena. En `memoria/estadisticas.json → recientes` la
MISMA frase del 16/09 21:59 aparece como `[charla]`, `[traducir]` y `[traducida]`: si `traducir`
entra en la lista, se come el id y los 10 `traducida` del 15/09 pasan de acierto a neutro.* Por eso
el recorte. Nota adicional que salió de ahí: **eso ya pasa hoy** con `descarte` (14486), que se
apunta justo antes del `Submit-Command 'traducir'` de 14488.

#### E3 — Que la queja que Nova **sí** sabe arreglar cuente como fallo

**Qué hace.** Cuando braya se queja, Nova reconoce la queja y rehace la orden, la orden equivocada
**sigue contando como acierto**.

**Dónde se toca.** `assistant.ps1:14243-14247`, antes del `Process-Texto $corr`:
`[void](Write-FalloUso "queja: $text")`. **Y nada más:** no meter `'correccion'` en `$DestinosUso`.

**Objeción recibida** (`rompe_algo`): *meter `correccion` en la lista dobla la cuenta — consume el id
de la queja, la orden rehecha se queda sin destino, y un solo error escribe **dos** líneas MAL en
`destinos.jsonl` con dos ids.* Y (`sin_datos`): *el camino tiene **0 ejecuciones**: `$RE_QUEJA` y
`Get-OrdenCorregida` entraron en `e4d297b` el 16/09 00:16, Nova rearrancó tres veces ese día, y hay
**0 líneas `CORRECCION:`** en el registro.* O sea: es una línea barata y correcta, pero **no se puede
comprobar hasta que braya use Nova**.

#### El resto del área, a la espera de datos

- **Apuntar el fallo aunque no salga una orden ejecutable** (`$RE_FALLO_DICHO` estricto): el patrón
  es limpio —«no era eso», «te equivocaste», «no te pedí»— y sobre 606 frases de voz reales encaja
  **4 veces con 0 falsos positivos**, frente a 45 del `$RE_QUEJA` amplio (28 de ellas conversación
  que empieza por «no»). Pero engancharlo en 14249 no vale: esa línea está **dentro del `if ($corr)`**
  y las dos quejas largas mueren antes (`Get-OrdenCorregida` devuelve `$null` con más de 8 palabras).
  Y aplicando su propio freno de 180 s, **produciría 1 apunte en toda la historia**… y apuntaría a un
  `recitado`, o sea a una alucinación de Whisper. **Esperar a datos.**
- **Una acción que revienta no puede contar como acierto**: cierto que el `catch` de 8399-8403 no
  hace `Log` ni `Add-Estadistica`, pero hay **1 sola línea `[FALLO:`** en todo el registro
  (15/09 10:20:12, «Abre Spotify») frente a 261 `LOCAL:`. El 0,38 %.

---

### 3.2. Agentes: cuándo llamar al grande

#### A1 — Una línea de cierre por trabajo ✅ **HECHA el 18/09**

> Una línea `TRABAJO modo= motor= prompt=Nc seg= pasos= salida=B exit=` junto al `RUNNER exit=`.
> Comprobado antes de escribirla: `Clear-OpencodeJob` corre en el `finally` **antes** de ese log y
> no toca ninguna de las cuatro variables, y `$script:jobMotor` se borra dos líneas **después**.

**Qué hace.** Hoy, para saber cuánto tarda una tarea hay que emparejar a mano **tres** líneas
(`SUBMIT`, `CEREBRO`, `RUNNER`), y ahí nacen los recuentos falsos. Una sola línea al terminar
convierte cualquier medición futura en un `grep`.

**Dónde se toca.** `Complete-OpencodeJob`, junto al `Log ("RUNNER exit=...")` de **11600**: modo,
motor, caracteres del prompt, segundos, pasos y salida. Los cuatro datos ya están en variables vivas
(`$script:jobModo`, `$script:jobMotor`, `$script:jobStart`, `$script:jobPasos`).

**El dato que la justifica.** El prompt fijo ha pasado de **2.991 a 5.131 caracteres (+72 %)**
comparando con el commit `f206335` del 15/09 (`CcInstruccionReceta` 2.028 → 3.635,
`CcInstruccionDato` 440 → 973), más `cerebro-sistema.md` (1.696) que va de prompt de sistema. Y las
33 líneas «CEREBRO (accion): claude-code sonnet, N caracteres» dan mediana **3.024**: **los 17 s de
mediana se midieron con un prompt casi la mitad de largo que el de hoy**.

**Coste** barata. **Riesgo** ninguno de comportamiento (solo escribe en el registro); mantener el
formato exacto y no reutilizar las palabras `SUBMIT` ni `RUNNER`.

#### A2 — Cuánta RAM se lleva el agente con un juego delante ✅ **sobrevive intacta**

**Qué hace.** Medir, no cambiar. La prioridad 2 de braya es velocidad y poca RAM con un juego
abierto, y la parte más pesada de Nova —levantar Claude Code con sus `node`— **no tiene ninguna
guarda de memoria**. En todo el proyecto hay **una sola** comprobación de RAM, y es de la charla
(`assistant.ps1:11876`); `Start-ClaudeCodeJob` (11316-11400) arranca sin mirar nada, y
`Get-SistemaCerebro` (4825) hasta le dice al modelo que braya está jugando.

**Cómo.** Una tarea inofensiva con y sin juego abierto, apuntando el pico de `claude.exe` y sus
`node`, igual que ya hace `tools/probar-ram-modelos.ps1`. **Si el pico se come más de la mitad de lo
libre, hay decisión que tomar; si no, se cierra por escrito y no se vuelve a proponer.**

#### A3 — `'plan'` no está en las tablas de duración de la barra (recortada)

`$script:jobModo` puede valer `'plan'` (12227, 12243) y **`'plan'` no está ni en
`$DURACION_ESPERADA` (11523) ni en `$DURACION_CC` (11526)**: cae al defecto de 60.000 ms, así que un
plan de 2 s pinta un 3 % de barra. Eso sí se arregla, y de paso se actualizan los números con lo
medido: traducir por API mediana 2 s (n=55), traducir por Claude Code 6 s (n=30), pregunta 4 s (n=5),
acción 17 s (n=33).

**Objeción recibida** (`rompe_algo`): *la fórmula propuesta (`1 - 0,35·e^(-t/esperado)`) **vale 0,65
en t=0**: la barra saltaría a dos tercios nada más lanzar cualquier trabajo, incluida una traducción
de 2 s. Miente más que la de hoy. Y bajar `accion` de 25 a 17 s hace que el barrido (que arranca al
pasar de 0,95, `nova_ui.cs:3376`) empiece **antes**, a los 16 s en vez de a los 23,7.* Aceptada:
**la fórmula no se toca**. El gasto del barrido ya tiene arreglo acordado y de una línea en
`REVISION-2026-09-18.md` hallazgo 7 (`SetDesiredFrameRate` 30 fps).

#### A4 — La etiqueta del motor, puesta por cada lanzador (recortada)

`$script:jobMotor` solo se limpia dentro de la rama `claude-code` de `Complete-OpencodeJob`
(11603-11604): ni `Clear-OpencodeJob` ni `Stop-OpencodeJob` la tocan. Una salida de la API con la
etiqueta heredada se leería con el parser equivocado y Nova diría en voz alta «(error del cerebro:
…)», que `Report-Reply` no reconoce (solo busca «(error de la API:», 12337).

**Lo que entra:** que **cada lanzador ponga su etiqueta al arrancar** (`'api'` en `Start-ClaudeJob`
11416, `'opencode'` en `Start-OpencodeJob` 11453).
**Lo que NO entra** (objeción `rompe_algo`, decisiva): *poner `$script:jobMotor = ''` en
`Clear-OpencodeJob` **rompe el camino principal entero**, porque el `finally { Clear-OpencodeJob }`
está en la línea 11597 y la lectura de la etiqueta en la 11603: la rama de Claude Code no se
ejecutaría nunca y las 68 llamadas del registro caerían al parser de opencode.*
**Y sin datos:** las 23 líneas «CANCELAR (hold durante procesamiento)» son 22 del 10/09 y 1 del
11/09, cuando el motor era opencode. **0 cancelaciones desde que existe el motor que deja la marca.**

#### A5 — El bloque de recetas: condicionarlo por lo que rinde, no por lo que retrasa (recortada)

A cada tarea se le pegan **3.637 caracteres** pidiendo una receta. El reparto de lo que ha producido,
desglosado por formato exacto: **7 «aprendida», 8 «RECETA descartada», 13 «el cerebro dice que esta
tarea no se puede repetir igual»** — y de las 7 aprendidas, **6 son del banco de recetas del 13/09**.
En `memoria/recetas.json` hay 4 recetas y **solo la id 1 tiene usos (2)**. O sea: **una receta útil en
uso real**. Y las 13 de «no se puede repetir» son exactamente las de mirar la pantalla, Steam, correo,
música e instalar. Condicionar el bloque (`assistant.ps1:11325`) por familia se sostiene.

**Objeción recibida** (`flojo`): *«cuánto retrasa no lo sabe nadie» es falso: el registro ya tiene el
experimento gratis. Las 8 tareas con prompt corto del 13/09 (625-2.616 caracteres) dieron el primer
`PASO n:` a los 10-14 s y las largas a los 12 s de mediana. **Un prompt 2,4 veces más corto no da ni
un segundo.*** Aceptada: **la tanda de 10 tareas con y sin bloque no se hace**. Y (`rompe_algo`):
*medirlo «en modo `-Probar`» es imposible, porque `-Probar` hace `exit 0` en 10780 y nunca llega a
`Report-Reply`.*

---

### 3.3. Decisiones: lo que Nova cambia sola

#### D1 — Mirar el interruptor antes de anunciar una decisión pendiente ✅ **sobrevive intacta**

**Qué hace.** Hoy la primera frase que Nova dirá al revisarse sería mentira: anuncia que va a apagar
el último recurso del oído, **que lleva apagado desde el 15/09**.

**El dato.** Comprobado por mí: `config.json → input.whisperModeloUltimo` está **vacío**, y entre las
líneas 5900 y 5928 de `Get-AvisoSinDatos` no aparece ni `$WhisperUltimo` ni `$NubeOir`, solo
contadores. Y el camino se alcanza: la nube no decide (`nube-intento` = 0 en los 6 días de
`memoria/estadisticas.json`) y el fino tampoco (neto 27−5 = 22, por encima del mínimo de 13).

**Dónde se toca.** `assistant.ps1:5900-5928`: añadir a cada entrada de la lista su interruptor vivo y
saltar el caso si está vacío, **igual que ya hace `Test-RevisionPropia` en 5965 y 5993**. Caso nuevo
en `tools/probar-sin-datos.ps1`.

**Coste** barata. **Riesgo** ninguno: solo quita frases falsas.

#### El resto del área: **todo a la espera de que Nova decida algo**

Cinco ideas más de decisiones se caen por la misma razón, y conviene dejarlo escrito para no volver:
**Nova no ha tomado ni una decisión propia**. Comprobado por tres vías: 0 líneas `DECISION PROPIA` y
0 `REVISION PROPIA` en los 2,6 MB del registro, ninguna clave `auto-ajuste`/`auto-deshecho` en los 6
días de `estadisticas.json`, y `config.json` **no tiene sección `"auto"`**, o sea que
`Save-DecisionPropia` no se ha ejecutado jamás. `AUTONOMIA.md` ya lo cerró así el 18/09 en las ideas
54, 55 y 58.

---

### 3.4. Trabajos encadenados

#### C1 — El banco de cadenas mide «la reconozco», no «hago las dos cosas» ✅ **HECHA el 18/09**

> 10 cadenas reales en `destinos.txt` con varias metas separadas por ` + `, y las metas **medidas
> con el probador real**, no inventadas. Dato que el plan no tenía: ` + ` ya era el separador que
> usa la salida del probador al encadenar acciones, así que el `-like` de una pieza no podía
> exigir dos. **Demostrado saboteando una meta**: el banco pasa a rojo con `falta: '…'`.

**Qué hace.** Que una cadena a la que se le pierde un eslabón salga **en rojo**. Hoy puede perderse
una orden entera y el número del banco no se mueve.

**El dato.** Las tres cadenas que fallaron de verdad el 10 y el 11/09 están **hoy** en
`pruebas/ordenes-que-funcionaban.txt` (líneas 4, 5 y 45) **contando como OK**, porque ese banco solo
mira si `Test-FastCommand` dice que sí, no qué hace. Dos ya están arregladas y una sigue rota, y el
banco sigue verde igual. En las 244 líneas de `pruebas/destinos.txt` **no hay ni una entrada con dos
metas**. Material disponible: de las 41 líneas `LOCAL: … ; …` del registro (34 distintas), unas 21
son cadenas reales de 2 a 5 acciones.

**Dónde se toca.** `pruebas/destinos.txt` admite varias metas separadas por ` + `, y
`tools/probar-destinos.ps1:37` (`$hace -like "*$debe*"`) pasa a exigirlas **todas**.

**Riesgo** bajo: fichero aparte, ninguna cifra existente (88 / 183 / ruido 3) se toca.

#### C2 — Que el PLAN abandone ante una confirmación pendiente ✅ **HECHA el 18/09**

> Los dos agujeros cerrados, y el ejecutor **sacado a su propia función** (`Invoke-PlanLocal`):
> estaba dentro de `Report-Reply`, que pasa de las 400 líneas, y por eso nadie lo había visto —
> lo que no se puede sacar a una función no se puede probar. `probar-plan.ps1` pasa de 10 casos
> (los 10 sobre `Split-Plan` con texto, ninguno sobre ejecutar) a 22. Añadido sobre el plan: al
> abandonar se limpia `$script:pendiente`, porque nadie llamó a `Start-Confirmacion` y esa
> pregunta no está viva en ninguna parte.

**El agujero es real y está verificado línea a línea.** El plan (12375-12390) es el único de los tres
ejecutores que **no mira `$script:pendiente`** (la charla sí, en 12189; las recetas también, en
12514). El vocabulario que se le ofrece al modelo incluye «cierra todos los programas» (8140) y
«abre \<juego\> en steam» (7157), que arman confirmación: `Invoke-FastCommand` devuelve la
**pregunta** como si fuera un resultado, el plan la suma a lo hecho y sigue; nadie llama a
`Start-Confirmacion`, así que `$pendiente` queda con `vence=0` y el bucle lo cierra por «plazo» →
«ni se ejecuta ni se habla».

**Lo que entra:** ante un `$pendiente`, el plan **abandona** y manda la tarea entera al agente. Y que
`tools/probar-plan.ps1` (hoy 9 comprobaciones, las 9 solo sobre `Split-Plan` con texto) recorra
`Test-FastCommand` → `Invoke-FastCommand` con cada forma del vocabulario.

**Lo que NO entra** (objeción `rompe_algo`): *«que pare, pregunte y siga si dice que sí» obliga a
guardar el resto del plan y reanudarlo tras una confirmación asíncrona: Nova ejecutaría los eslabones
que faltan **minutos después**, que es literalmente hacer algo que no se le pidió. Y la exposición es
mayor de lo que dice: hay **7 sitios** alcanzables desde el vocabulario del plan que ponen
`$script:pendiente` (7059, 7073, 7085, 7093, 7157, 7824, 8140, 8211).*

**Segundo agujero encontrado por la lente, y que nadie había visto:** en «plan a medias»
(12390-12394) se dice «Lo demás lo miro» y se manda al agente **el texto original completo**,
incluido lo ya hecho, así que el agente **repite los pasos ya ejecutados**.

**Estado:** el plan tiene **0 ejecuciones** (0 líneas `PLAN:`, 0 «pruebo a hacerla con órdenes mías»,
ninguna clave `plan-*` en `estadisticas.json`), y es barato arreglarlo **antes** de que se estrene.

---

### 3.5. IA: la charla, la memoria y el modelo

#### IA1 — Que el interrogativo suelto no arrastre recuerdos ✅ **sobrevive intacta**

**Qué hace.** Preguntar «qué es un volcán» o «qué tengo en mi escritorio» le mete a Nova el recuerdo
«¿Qué es escribir?» delante, solo porque las dos empiezan por «qué». braya lo nota como respuestas
que se van por las ramas.

**El dato.** Simulando `contexto()` con el cerebro real y sin embedder (que es lo que pasa hoy en
producción) sobre las 96 frases reales de `CHARLA (hablar)` del registro: **solo 9 recuperan algo, y
5 de esas 9 son el mismo recuerdo equivocado colándose por la ficha `?que`**. Las 4 buenas (la
distancia Tierra-Sol, «¿qué es escribir, hola», el lío del Bluetooth y el de la funda) comparten
palabras de contenido y sobrevivirían al filtro.

**Dónde se toca.** El filtro de `contexto()` (`charla_memoria.py:329`): exigir que el recuerdo
comparta **al menos una palabra de contenido**, no solo el interrogativo. Es una condición extra, no
un umbral nuevo a ojo. `fichas()` (117-123) es quien añade la ficha `?que`.

**Riesgo** bajo: es más restrictivo, solo puede quitar recuerdos. **Medida:** reproducir las 96
frases — hoy 9 (4 buenos, 5 malos), objetivo 4 y 0. Caso nuevo en `tools/probar-memoria.py`.

#### El resto del área, con los avisos que hay que conservar

- **Abrir la búsqueda por significado**: el diagnóstico es correcto (la puerta de
  `charla_worker.py:505-514` se abre en **6 de 96** frases reales, y las 59 líneas «buscar en la
  memoria» dicen **0,0 s** las 59 veces, o sea que el embedder nunca se carga al contestar), pero
  medido contra el Ollama de braya con `keep_alive=0`, cada llamada cuesta **1,7 s** y la respuesta
  por API tiene mediana de **1,6 s**: se doblaría la espera. Y la premisa de que «hoy hay RAM libre»
  es falsa: **25 de 26 precargas las rechazó `Test-RamParaCharla`** por falta de memoria.
  **No entra.** Lo que sí hay que corregir es `NOVA-LLM.md:132-141`: en el camino de **contestar**,
  la búsqueda por significado no está activa.
- **Limpiar el cerebro con el filtro del perfil**: el mecanismo falta de verdad
  (`guardar_texto`, 423, solo mira longitud y `sensible()`), pero los números estaban inflados:
  aplicando el criterio **exacto** de `Add-DatoPerfil` (4750-4752) a los 29 episodios caen **20, no
  25**, y las «quejas» son **0, no 15**. Y la premisa («viaja en el prompt en cada petición») es
  falsa: los episodios entraron en **2 turnos de 96**. Peor: entre los 20 que caerían está el
  episodio 26 (el del Bluetooth), que es **uno de los dos que sí se recuperan**. **El filtro para lo
  nuevo, sí; la limpieza de lo viejo, no.**
- **La espera de 18 s del modelo local**: la medición se rehízo y sale **17,6 s** (n=22), pero **las
  22 son con `qwen2.5:3b`**, y `config.json` dice `qwen2.5:1.5b` desde el 15/09 13:11. Respuestas
  locales con el modelo de hoy: **cero**. Además el «silencio» no existe: hay **21 líneas «tarda más
  de 5 s, digo algo mientras»** para 22 respuestas locales. **Medir el 1.5b antes de tocar nada.**

---

### 3.6. Comandos

#### M1 — Las muletillas `ok / okey / vale / bueno`, y **`mira` fuera** ✅ **HECHA el 18/09**

> Solo `$FILLER_INI`, como decía la ficha. Dato que la hace segura y que no estaba escrito: el
> patrón exige `\s+` **detrás** de la muletilla, así que «Ok» a secas —la línea 19 de
> `ruido-real.txt`, el corpus de la tele— no se toca. **Y M1 entraba sin red**: ningún probador
> de `tools/` mencionaba `Remove-Filler` ni las listas de muletillas, con lo que un cambio en ese
> regex —que decide si una frase es orden o charla— podía colarse entero sin ponerse nada en
> rojo. Ahora hay 5 casos en `destinos.txt`, incluido el guardián
> `busca cuanto vale una ps5 en google` → sigue buscando la frase entera.

**Qué hace.** «ok abre steam» o «bueno pon modo noche» se van hoy al modelo; «okey abre steam»
funciona en menos de un segundo. La lista vive en tres sitios que no dicen lo mismo:
`$FILLER_INI` (193) no las lleva, `$FILLER_GLOBAL` (189) lleva «okey» pero no «ok», y
`Test-Charla` (1045) y `Test-PareceCharla` (12085) sí las quitan las dos.

**El tamaño real, sin inflar.** De los 311 descartes del registro (259 únicos), **una sola** es una
orden que el código de hoy resolvería al caer la muletilla: «ok poner un temporizador de cinco
minutos» (15/09 11:19). Las demás son charla, que ya se encamina bien. Y **«vale» no aparece nunca**:
0 dictados que empiecen por «vale» en todo el registro. Véndase como **higiene**, no como rescate.

**Dónde se toca.** `$FILLER_INI` (193) **y solo ahí**. Dos cosas que NO se hacen:

- **`mira` no entra** (objeción `rompe_algo`, con dos roturas): *(1) `assistant.ps1:2967` es un
  patrón literal con «mira si hay algo colgado» dentro; quitando la muletilla, una orden que **hoy
  funciona** se iría al modelo. (2) `mira` está en `$INICIO_ORDEN` (1025), que es la frontera
  orden/charla, y se evalúa sobre el fragmento ya pasado por `Remove-Filler`.*
- **No se unifican las tres listas** (objeción `rompe_algo`): *`$FILLER_GLOBAL` borra la palabra **en
  cualquier parte** de la frase, incluido el texto que buscas. Medido: «busca gracias totales en
  youtube» → buscar **'totales'**. Con «vale» dentro, «busca cuánto vale una ps5 en google» →
  buscar «cuánto una ps5».*

#### M2 — Que la lista de «no reconocido» **marque** lo ya resuelto ✅ **HECHA el 18/09**

> Marcadas, no borradas, y el encabezado ya no manda a `commands.json`. Añadido sobre la ficha:
> esto se escribe desde `Add-Estadistica`, que corre en **cada orden**, así que preguntarle a la
> capa local por las 30 frases cada vez habría sido velocidad tirada —la prioridad nº 2 de
> braya—. El resultado se guarda en una caché por frase: se calcula una vez y luego sale gratis.

**El problema es real y caro.** El commit `d1e3bd0` de esta mañana lo dice con sus palabras: de
**18 frases reales que se fueron al agente, 9 YA FUNCIONABAN**. Medido por otro lado: de los 23
descartes con forma de orden que no están en ningún `pruebas/*.txt`, **7 los resuelve el código de
hoy**. Quien lee esa lista se pasa media sesión arreglando lo ya arreglado.

**Lo que entra:** **marcar** («ya se resuelve») al escribir `estadisticas.md` (1549), y arreglar el
encabezado de 1553, que hoy manda a `commands.json` y en todo el registro hay **un solo** fallo por
app desconocida («abre armony creator»), y «armoury crate» ya estaba en `commands.json`: falló el
oído, no el vocabulario.

**Lo que NO entra** (objeción `rompe_algo`): *borrar la entrada **rompe la medición de la meta**: los
descartes guardan el **fragmento** mientras la ruta `local` guarda la **frase entera**, con fecha
delante y recortados a 90 caracteres, así que la comparación fallaría justo en las frases compuestas
— quedaría implementado y sin efecto. Y una frase que falla 2 de cada 3 veces desaparecería al primer
acierto, que es exactamente la que no puede desaparecer.*

#### M3 — Que el prompt del traductor conozca lo que Nova ya hace (recortada)

De las 33 peticiones que el registro escaló al agente, varias son formas que la capa local **ya
resuelve** y el prompt no nombra: «Revisa mi correo» (3 veces), «Reproduce el segundo vídeo de
YouTube», «que reproduzcas la canción de Pitbull en YouTube». Y el desfase acaba de crecer: `d1e3bd0`
añadió el correo a la capa local **y no tocó el prompt**. En el otro sentido no hay deriva: las 56
formas que el prompt promete se resuelven **56 de 56**.

**Entran tres:** correo (2480), youtube (3058) y cambiar de app (2906).
**No entran dos** (objeción `rompe_algo`): *el **dictado largo** no puede estar en ese menú —
`dicta en <app>` enciende `$script:dictandoLargo`, un **modo que se queda puesto** y que manda sobre
todo lo demás; una traducción equivocada deja a Nova tecleando lo que oiga. Y **instalar** apunta a
un camino con **0 usos** (`store.steampowered` = 0 en todo el registro). Con el agravante de que la
traducción **se aprende** (`Add-Traduccion`, 12536) y se repite para siempre.*

#### M4 — Que «baja la música» no abra la tienda de Steam (recortada, y sin datos)

El patrón que instala juegos (3224) acepta «baja» y «bajame», así que cualquier «baja lo que sea»
que no sea volumen o brillo acaba abriendo la tienda buscando esas palabras como si fueran un juego.
Es el tipo de daño que braya odia: no es no entender, es **hacer algo que nadie pidió**.

**Pero no ha ocurrido nunca:** 0 apariciones de `steampowered` en las 26.906 líneas del registro, y
el patrón entró el 16/09 a las 15:48 con ~16 dictados reales después sin un disparo. Frases reales
que lo activarían, **2 en seis días**. El arreglo es **una palabra menos en una lista**; se hace
cuando se toque ese patrón por otra cosa, no como tarea propia.

---

### 3.7. Interpretación

#### I1 — Los asentimientos sueltos, a la cortesía que ya existe ✅ **HECHA el 18/09**

> Se cierra **en silencio** (no «De nada», que a un «ok» suelto suena raro), igual que hace la
> rama del seguimiento. `Add-RuidoRacha` no se toca, tal y como pedía la objeción.
>
> **El riesgo de verdad no estaba en la ficha, y se comprobó antes de escribir nada:** `vale` y
> `ok` son `PALABRAS_SI` del worker (`wake_vosk.py:686`), o sea respuestas a una confirmación.
> Pero solo lo son mientras hay una pregunta viva, y en ese rato el worker escucha con gramática
> cerrada (`reconocedor_si_no`) y responde por `confirmacion.txt`: el texto no pasa por
> `Process-Texto`, así que esta rama no puede robarle el «vale» a ninguna pregunta.
>
> Red nueva (`tools/probar-asentimiento.ps1`, bloque `2n31`, 23 casos): ningún probador cargaba
> `Process-Texto` —pasa de las 700 líneas—, así que el patrón **se saca del archivo real** y se
> prueba, como hace `probar-umbrales.ps1` con los umbrales. Lo que más vigila es lo que **no**
> puede caer ahí: `si`, `no`, `claro`, `dale` y `cancela`.

Un «ok», «vale» o «muy bien» suelto cuenta hoy como ruido, contesta «No te entendí» y suma para la
autosordina. **La mitad ya está arreglada**: `assistant.ps1:14067` (commit `446acb1`, 15/09) ya
captura «ok gracias», «vale gracias», «muy bien gracias» y responde «De nada», y 14057 cierra la
cadena en seguimiento. **Lo que queda** es el asentimiento **sin «gracias»** y fuera del seguimiento:
lo confirma una línea posterior al arreglo, «RUIDO descartado: 'Muy bien'» del 15/09 18:30.

**Lo que entra:** añadir `ok / vale / muy bien / perfecto / listo / de acuerdo` solos a la cortesía de
14067. **Lo que NO entra:** tocar `Add-RuidoRacha`.

**Objeción recibida** (`flojo`, y hay que leerla): *el título («empujan hacia los 10 minutos de
sordina») **no ha pasado nunca**. Fui a ver qué disparó cada una de las 5 autosordinas: «Enhanced
Edition», «¡Yoraz», tres frases largas de conversación, «El caminfo mas en su oréter well». **Ninguna
llevaba un asentimiento en la ventana de 5 minutos.*** Y (`flojo`): *«Ok», «okay» y «Gracias» son
tres de las 99 líneas de `pruebas/ruido-real.txt`, que es el corpus de la tele y del juego: son justo
las palabras que una serie de fondo dice todo el rato.* Total real: **7 «no te entendí» evitados en
8 días**.

#### I2 — El detalle de descartes **por trozo** (recortada)

`assistant.ps1:7036` hace `$script:ultimoDescarte = $f` **dentro del bucle de trozos** (cada trozo
pisa al anterior) y 14486 lo cuenta una vez por orden. Medido cruzando cada descarte con el dictado
anterior: **124 son la frase entera y 38 son un trozo de una orden compuesta** — esos 38 son justo
los que se pierden. Y `tools/aprende-descartes.ps1` (del 10/09) lee **solo el log**.

**Lo que NO hace falta** (objeción `ya_existe`): *contar ya existe (`Get-Atragantos`, 1671, devuelve
`@{frase; veces; rutas}` y `estadisticas.md` ya imprime la tabla con columna «veces»), y sacarlo del
log también (`Write-DestinoUso`, 1407-1434, escribe `destinos.jsonl`). La urgencia por la rotación
está mal planteada: **sí existe** desde el 14/09 (línea 71, a los 5 MB pasa a `assistant.log.1`) y el
log va por 2,59 MB.*
**Y tres avisos si se hace** (objeción `rompe_algo`): *(1) **privacidad**: el repo es público y
`.gitignore` va fichero a fichero; un `memoria/descartes.json` nuevo **no estaría ignorado**.
(2) A `Invoke-FastCommand` la llaman **8 sitios que no son la voz de braya** (la validación de la
traducción, los pasos del plan, las acciones de las reglas, las recetas, y hasta órdenes internas
fijas): es la trampa de las «1.095 reglas». (3) 80 de los 311 descartes están a menos de 20 s del
anterior, porque la misma frase pasa con la transcripción de Parakeet, la de Whisper y la del oído
fino: `veces` mentiría por arriba.*

#### El resto del área, tumbado y por qué conviene saberlo

- **No mandar a Whisper lo que Parakeet ya oyó como charla**: *el ahorro no existe, solo cambia de
  puerta, y a la lenta*: 31 de los 32 pares que el filtro frenaría cumplen `Test-MereceRepaso` y
  pedirían el **oído fino**, que es el modelo `small` (mediana 4,6 s, p90 10,4 s) frente al repaso
  (1,3 s / 3,8 s). Y apaga la segunda opinión de Gemini para esas frases.
- **Las traducciones que se pisan al guardarse**: la pérdida es real (14 `APRENDIDO`, 1 `OLVIDADO`,
  2 entradas hoy) pero **la causa propuesta es imposible**: solo puede haber una Nova (mutex
  `Local\VoiceAssistant`) y `-Probar` desvía el fichero. Y el formato delata a otro autor:
  `ConvertTo-Json` de PS 5.1 escribe **dos espacios** tras los dos puntos, y las copias del 13-15/09
  los tienen mientras las del 16-17/09 tienen **uno**. **Primero hay que averiguar quién reescribió
  el fichero**; fusionar al guardar además rompería el olvido (`probar-rechazos.ps1:95`).
- **Que las correcciones de oído no entren en el texto libre**: **0 casos reales en 8 días**, y en el
  único real la corrección **acierta** («Abre Team» → abrir steam). Peor: cortar detrás de
  `$VERBOS_TEXTO` mata la mitad buena de la lista — «busca gatos en yutu» funciona hoy porque
  `yutu`→`youtube` se corrige **al final de la frase**.

---

### 3.8. Iniciativa

#### I3 — La micro-charla, por `Send-Aviso` ✅ **HECHA el 18/09**

**El defecto es real:** las dos frases de 15896-15903 («van tres horas, un vaso de agua» y «es la una
de la mañana») son las **únicas** que Nova suelta saltándose todos los frenos, terminan en `Say`
directo, y encima **solo saltan si hay un juego delante** — o sea, hablan por encima de la partida,
que es justo lo que `avisos.sinVozEnJuego: true` prohíbe para todo lo demás. Es código del 11/09,
anterior a los frenos, que llegaron el 16/09.

**Lo que entra:** pasarlas por **`Send-Aviso`** (9492), que aplaza si estás dictando y cuyo
`Test-AvisoSinVoz` (9478-9489) calla con juego delante, con sordina y en modo silencio, dejando el
pulso en la cápsula. Y sus textos entran en el patrón de variedad de 2.6.

**Lo que NO se hace** (objeción `rompe_algo`): *pasarlas por `Send-AvisoEntorno` **las borra**:
`Test-PuedoAvisar` corta en 5567 todo lo que no sea `'alto'` con juego activo, `'bajo'` y `'noche'`
incluidos; y el banco lo daría por bueno.*

#### Lo demás de esta área

- **Los dos avisos del juego que se bloquean a sí mismos** («Cerraste X, dime dónde te quedaste» y
  «hoy llevas N horas»): el diagnóstico de código es correcto —se llama `Exit-Juego` con
  `$script:juegoActivo` todavía puesto, y `Test-PuedoAvisar` los tira—, pero **el arreglo es
  peligroso hasta arreglar la detección**: `Exit-Juego` salta al perder el **primer plano**, y
  **4 de las 6 salidas del registro duraron menos de 2 minutos** (ELDEN RING 11 s, dos de 20 s, una
  de 83 s). Con el cambio, Nova habría dicho «Cerraste ELDEN RING» **once segundos después de
  lanzarlo**. Primero exigir que el proceso del juego haya muerto y una duración mínima.
- **La caja negra de los frenos** (apuntar lo que decide callar): **ya se decidió que no**, hoy
  mismo, en `AUTONOMIA.md` idea 63: *«apuntarlos llenaría el log de ruido para contar que era de
  noche»*. Además `Send-Aviso` **ya registra** «aviso SIN VOZ (tipo): …» (9503) y hay 2 líneas de
  esas. Y el «cómo» rompía el contrato: hacer que `Test-PuedoAvisar` devuelva el motivo la convierte
  en verdadera siempre (`-not "texto"` es falso) y **todos los avisos pasarían**.
- **Instrumentar los «nova» ignorados mientras el agente trabaja**: mediría la población equivocada.
  Con un juego delante la palabra de activación **está apagada entera** (`MarcaSoloBoton`,
  `wake_vosk.py:1703-1711`), así que el contador daría **0 justo en el escenario principal**.

---

## 4. Lo que NO hay que hacer, y por qué

*Esta sección vale tanto como las otras: 38 ideas descartadas con su motivo, para no volver a
gastarlas.*

### 4.1. Ya existe (y dónde)

| idea | ya está en | detalle |
|---|---|---|
| Filtrar el ruido de 1-2 palabras antes de traducir | `assistant.ps1:14403-14413` | commit `dcdbbc4`, 11/09 16:27. Ha corrido **35 veces**. De las 16 llamadas cortas del registro, **14 son anteriores** a ese commit; las 2 posteriores entraron por **otra puerta** (la charla, 12198) |
| Datos aprendidos de mentira para el banco | `probar-traduccion.ps1:64`, `probar-recetas.ps1:19`, `probar-rechazos.ps1:72`, `probar-invitado.ps1:27` | y el «cómo» no funcionaría: `-Probar` (10746-10753) solo llama a `Test-FastCommand`, que **no consulta** `Find-Traduccion` ni `Find-Receta` |
| Guardar los descartes fuera del log, con su cuenta | `Write-DestinoUso` (1407) + `Get-Atragantos` (1671) | el fichero no existe aún porque la función es del 17/09, no porque falte código |
| Aplazar los avisos mientras dictas | `Send-Aviso` (9492-9498) + bucle (15674-15679) | **aplaza**, no descarta; la auditoría del 13/09 lo explica |
| Que un «gracias» no cuente como ruido | 14057 (seguimiento) y 14067 (cortesía, commit `446acb1`) | queda solo el asentimiento sin «gracias» → **I1** |
| Apuntar por qué aplaza una decisión | `AUTONOMIA.md` idea 63, cerrada el 18/09 | y la parte que importaba (`Get-AvisoSinDatos`) se cuenta **hablando** |
| Que el «una vez cada X» sobreviva al reinicio | commit `7373ffe`, 16/09 20:35 | `tmp/avisos-vistos.json`, 4 claves vivas |
| Una marca de presencia en disco | `habitos.fin`, escrita en **cada** `Process-Texto` vía `Set-UsoAhora` | hoy `{16/09: 21:59, 15/09: 01:00, 13/09: 17:24}`; resolución de minuto |

### 4.2. Sin datos (cero ocurrencias, o casi)

| idea | el cero |
|---|---|
| Cancelar una tarea deja la etiqueta del motor puesta | 23 `CANCELAR`, **22 del 10/09 y 1 del 11/09**, cuando el motor era opencode. 0 desde que existe Claude Code |
| «baja la música» abre la tienda de Steam | **0** `steampowered` en 26.906 líneas |
| No insistir en una decisión deshecha | **0** decisiones tomadas, **0** deshechas; `config.json` sin sección `auto` |
| El freno de «una decisión al día» tras reiniciar | ídem: 0 decisiones. Cualificar dos a la vez es imposible hoy |
| Cerrar en voz alta una promesa que caduca | el aviso `auto-sin-datos` **no ha sonado jamás** |
| Arreglar el denominador de la nube | `nube-intento` = 0 en los 6 días; y el filtro propuesto **deja pasar 8 de 8** de las llamadas reales (`Test-MereceRepaso` solo pide una palabra de ≥4 letras: «Yeah» pasa) |
| Una acción que revienta cuenta como acierto | **1** línea `[FALLO:` en todo el registro frente a 261 `LOCAL:` |
| Que las correcciones no entren en el texto libre | **0** casos reales; en el único real la corrección acierta |
| El respiro de 250 ms entre eslabones | **0** fallos encadenados, y la cadena que se cita **funcionó**: «Abre Steam y lanza Little Nightmares III» (12/09 18:34) y el juego arrancó |
| Reloj de pared para reglas «cada N minutos» | `reglas.json` es `[]`, **0 reglas**; las 1.094 «REGLA N guardada» del log son del banco |

### 4.3. El arreglo rompe algo (las más valiosas de leer)

| idea | qué rompe |
|---|---|
| `$jobMotor = ''` en `Clear-OpencodeJob` | el `finally` corre **antes** de leer la etiqueta: las **68** llamadas a Claude Code caerían al parser de opencode |
| `mira` en las muletillas | tira «mira si hay algo colgado» (2967), una orden que **hoy funciona**, y saca «mira» de `$INICIO_ORDEN` |
| Unificar las tres listas de muletillas | `$FILLER_GLOBAL` borra **dentro** del texto: «busca gracias totales en youtube» → buscar «totales» |
| La fórmula nueva de la barra | vale **0,65 en t=0**: dos tercios de barra nada más lanzar |
| Borrar de la lista de descartes lo ya resuelto | compara fragmento contra frase entera → no casaría; y borra la prueba de las frases que fallan a ratos |
| `dicta en <app>` en el prompt del traductor | enciende un **modo que se queda puesto**; y la traducción **se aprende** |
| Meter los temporizadores en `recordatorios.json` | 4 sitios que no saben qué es un temporizador los recitarían, los borrarían y los dispararían con voz en vez de con sonido |
| Meter destinos neutros en `$DestinosUso` tal cual | **consumen el id**: `traducida` pasaría de acierto a neutro |
| `correccion` en `$DestinosUso` | **dobla** la cuenta: dos líneas MAL por un solo error |
| Abrir el patrón de «no era eso» con `\b…\b` | contiene la alternativa «eso no» suelta → **deshace la última acción** y veta la frase, sobre conversación normal |
| Que `Test-PuedoAvisar` devuelva el motivo | cualquier cadena no vacía es verdadera → **todos los avisos pasarían**, de noche y jugando |
| Escribir la presencia en `tmp/avisos-vistos.json` | `Get-EntornoVistos` deja de releer el disco y el primer guardado **borra las 4 claves reales** |
| La micro-charla por `Send-AvisoEntorno` | `'bajo'` y `'noche'` mueren con juego delante: las dos frases desaparecerían |
| Mover `$script:juegoActivo` para que hablen los avisos de juego | `Exit-Juego` salta al perder el foco: 4 de 6 salidas duraron < 2 min |
| Espera activa entre eslabones | bloquea el bucle hasta 1,5 s: cápsula congelada, sin leer el mando ni la palabra de activación |
| Filtrar lo que el revisor de memoria encola | mata justo lo que aprendió: «braya tiene una consola ROG Ally», el episodio del Bluetooth; y sin encolar preguntas, **nada pasa nunca de provisional a firme** |
| Limpiar los 20 episodios que mencionan a Nova | borra el episodio 26, que es **uno de los dos que sí se recuperan**, y le quita el único rastro de sus propios fallos |
| Deduplicar el estilo por parecido | el umbral tendría que caer en la franja 0,25-0,40 y se comería «no repetir respuestas», que es lo que braya **más** repite |

### 4.4. Flojo (cierto, pero más pequeño de lo que se vendía)

- Las muletillas: **1 orden real de 188 grabaciones**, un solo día. «vale» no aparece nunca.
- «Ponme música relajante»: **2 frases en 6 días**, y una de las dos **la resolvió bien el agente**
  (puso el mix en YouTube en 22 s). Vale como arreglo de **destino** (Spotify **no está instalado**),
  no de volumen de casos.
- Los asentimientos y la sordina: 7 casos en 8 días, y **ninguna de las 5 autosordinas** la disparó
  un asentimiento.
- Estrenar el PLAN con «las 33 peticiones reales»: **al menos 10 de esas 33 son fixtures del propio
  banco** del 13/09 («crea una carpeta llamada Receta Dos…»), justo la forma que mejor descompone el
  plan. Medirlo con ellas dentro infla el resultado.
- El aviso «hoy me equivoco más de lo normal»: el diagnóstico es impecable (los tres escritores de
  `'error'` son dictado vacío, cancelación y timeout, **ninguno** es una orden mal entendida), pero
  **las cuatro fuentes nuevas valen 0 en todos los días medidos**: el aviso nuevo tampoco saltaría.

---

## 5. Por dónde empezar

Por daño real, no por facilidad.

1. **El saludo al volver (sección 2 entera).** Es lo que pidió braya, la pieza existe a medias y está
   a cero, y el diseño ya está cerrado con su umbral medido (45 min / 3 h), sus frenos y sus 9 casos
   de banco. Se puede implementar sin volver a investigar nada. *Y obliga a hacer antes el punto 2,
   porque comparten variable.*

2. **`$script:ultimoUsoEn`, la variable declarada dos veces (E1).** Es lo único de este plan que está
   **ensuciando la medición de la meta nº 1** ahora mismo: la guarda de 5 minutos que impide marcar
   como fallo una orden vieja **no vence nunca**. Renombrar en 6179/6183/6184 **y** que la llamada de
   `Watch-Entorno` solo lea.

3. **Usar Nova un día entero.** No es una tarea de código y es la más importante de las cinco.
   `pruebas/audio/uso/destinos.jsonl` **no existe**, el último uso real fue el **16/09 a las 22:00**,
   y desde entonces hay dos días de commits sin validar con su voz. **Doce** de las ideas de este
   documento no se pueden juzgar sin eso: el PLAN, la corrección de quejas, las decisiones propias,
   la nube, el modelo local de charla. Un día de uso vale más que cualquier función nueva.

4. ~~**Los tres seguros baratos del agente y la cadena: A1, C1 y C2.**~~ ✅ **HECHOS el 18/09.** La línea de cierre por trabajo
   (para poder re-medir los 17 s con el prompt que ha crecido un 72 %), las cadenas con dos metas en
   `destinos.txt` (hoy una cadena puede perder un eslabón y el banco no se entera), y que el PLAN
   abandone ante una confirmación **antes** de estrenarse. Los tres son baratos y los tres tapan un
   agujero que hoy nadie ve.

5. ~~**D1 y IA1, las dos de un rato.**~~ ✅ **HECHAS el 18/09.** D1 en `692d740`: cada decisión
   lleva su interruptor y lo apagado no se anuncia. IA1 en `3455fc7`, con el antes y el después
   medidos sobre las 96 frases reales: **de 9 recuperaciones (4 buenas, 5 el mismo error) a 4 y 0**,
   que era el objetivo exacto de esta ficha. Aviso guardado en la prueba: el caso obvio
   («escritorio» no trae «escribir») **sale verde sin el filtro**, porque en un cerebro de
   laboratorio ese `lex` ya está por debajo de 0,3; por eso la rama se prueba contra
   `_vale_de_contexto` con un hit de mentira y con «¿Qué?» a secas, que sí llega a 0,5.

---

*Escrito el 18/09/2026 sobre el código de `0ca3fbf`. Todo lo que dice «medido por mí» sale de
`assistant.log` (26.811 líneas con hora, 09/09 → 17/09), `memoria/estadisticas.json`,
`memoria/habitos.json`, `memoria/juegos.json`, `tmp/avisos-vistos.json`,
`pruebas/audio/uso/registro.jsonl` (374 líneas, **188 ids únicos**) y del propio `assistant.ps1`.
Ningún fichero del proyecto se ha modificado para escribir este plan.*
