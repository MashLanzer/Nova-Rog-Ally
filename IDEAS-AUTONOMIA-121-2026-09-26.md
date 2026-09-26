# Ciento veintiuna ideas de autonomía para Nova — 26 de septiembre de 2026

Salidas de un barrido de **veinte ángulos** sobre el código y los datos reales, cada uno ciego a
los demás, y pasadas por **tres filtros adversariales** que no las vieron nacer. El método está
en `METODO-BUSCAR-IDEAS.md` y el script en `tools\ideas\buscar-ideas.workflow.js`.

**Cada idea trae un número que un agente contó**, y ese número lo reprodujo después otro agente
distinto. Las que no se pudieron reproducir están abajo, en la lista de las muertas, con lo que
salió al volver a contar.

## El embudo

| | |
|---|---|
| Propuestas por los 20 buscadores | **180** |
| Sobreviven a su propio revisor | 143 |
| Sobreviven a «¿ya lo hace Nova?» | 135 |
| Sobreviven a «¿aguanta el dato?» | 130 |
| Tras fusionar los duplicados entre ángulos | **121** |

De las 121: **40 acercan la meta del 100 % de comprensión** y **88 son adaptativas** (el
número que usan lo aprende Nova sola de sus propios datos, que es lo que pediste).

**Coste del barrido:** 98 agentes, 13,4 millones de tokens, 4.524 usos de herramientas, ninguno caído.

---

Leyenda: **⬆** acerca el 100 % de comprensión · **∿** adaptativa · **⚙** fusión de varias ideas que resultaron ser la misma

## A. Las que más cambian (valor 8 a 10) — 28 ideas

### 1. El gitignore se escribe a mano fichero a fichero, y ya van tres sin cubrir ∿

**Valor 8 · coste 2 · ángulo `privacidad`**

**Qué.** Nova comprobaria sola que todo lo que escribe en memoria\ esta ignorado, en vez de fiarse de que alguien se acuerde de anadirlo. Sacaria la lista de rutas del propio codigo y la cruzaria con git check-ignore. Si aparece una sin cubrir, la anade al .gitignore y lo dice; nunca la borra ni la commitea.

**El dato.** El codigo puede crear 32 ficheros distintos en memoria\. TRES no estan en el .gitignore: memoria\logros-stamp.json (assistant.ps1:20327, cuando juega y que logros saca), memoria\montajes.json (17442, sus montajes de ventanas con las URL que visita, por ejemplo la de Pinterest) y memoria\palabras-no.json (17723, las palabras que no aguanta que le digan). El repositorio es PUBLICO: el proximo git add -A los mete. Y no es un descuido aislado: 36 commits han tocado el .gitignore, y el propio fichero cuenta por escrito tres veces que se le escaparon ficheros (perfil-todo.md y perfil-caidos.md el 25/09, uso-ally.json el 25/09). De los 189 bancos de tools\, NINGUNO comprueba esto.

**Dónde se comprobó.** grep -oE 'Join-Path \$MemoriaDir .[A-Za-z0-9_.-]+\.(json|md|pgn)' assistant.ps1 | sort -u | wc -l -> 32; bucle con git check-ignore sobre esos 32 -> fallan logros-stamp.json, montajes.json y palabras-no.json; git log --format=%h -- .gitignore | wc -l -> 36; grep -lniE 'gitignore|privacidad|check-ignore' tools/*.ps1 -> solo probar-barra-espera.ps1, y de pasada

**Cómo se hace.** Banco nuevo tools\probar-memoria-ignorada.ps1 (ASCII puro, sin BOM, sin tildes ni enye): saca con Select-String las rutas Join-Path $MemoriaDir de assistant.ps1, wake_vosk.py y charla_memoria.py, y por cada una llama a git check-ignore -q; falla listando las que no esten. Y en assistant.ps1, al arrancar, la misma comprobacion en corto: si encuentra una sin cubrir, la anade al final del .gitignore con un comentario con la fecha y deja un Log. Entra en tools\probar-todo.ps1.

**Riesgo y guarda.** Que escriba en el .gitignore mientras braya tiene un commit a medias. La guarda: solo anade lineas al final, nunca quita ni reordena, y si git check-ignore no esta disponible no hace nada y lo apunta. Que se cuele un falso positivo (una ruta que es de prueba, como la de assistant.ps1:21027 que usa $pruebaDir) se evita exigiendo que la variable sea exactamente $MemoriaDir.

### 2. El ánimo se le hunde por los botones que braya pulsa sin hablar

**Valor 8 · coste 2 · ángulo `contadores`**

**Qué.** El ánimo decide cuánto habla Nova por su cuenta, y su único 'mal' es el contador 'error', que NO mide comprensión: mide dictados vacíos, cancelaciones de braya y timeouts de opencode. Que el 'mal' del ánimo sean los descartes y los ruidos —lo que de verdad no entendió— y que las cancelaciones y los botones pulsados sin hablar dejen de contar.

**El dato.** 'error' sube en tres sitios exactos y en ningún otro. Contados en assistant.log + assistant.log.1: 100 "vacio, ignorado", 23 "CANCELAR (hold durante procesamiento)" y 1 "RUNNER timeout" = 124 eventos, ninguno un fallo de oído. Además 'dictado vacio' YA está excluido a propósito en Write-FalloDeducido y en Get-ComoTeEntendi: el ánimo es el único sitio de la casa que lo cuenta como fallo, y lo pesa x2. Efecto real: el 25/09 salió ánimo del día -0,83 (7 aciertos contra 11 "errores") y ánimo largo -0,40, por debajo de $AnimoMalo = -0,3, que es lo que PARTE EN DOS el suelo de avisos. Con 'descarte' (7 ese día) el día sale -0,50 y el largo -0,35. Y el alcance: el ánimo ve 364 de los 3.240 eventos apuntados en 14 días, el 11 %; los 595 de charla, acción, plan, pregunta, receta y perfil no cuentan ni a favor ni en contra.

**Dónde se comprobó.** assistant.ps1:2947 (Get-AnimoDia, ok = local/aprendida/memoria/traducida, mal = error), 10433 ($AnimoMalo=-0.3), 10435 (Get-SueloPorAnimo, floor($suelo/2)), 26126 / 27010 / 27712 (los tres Add-Estadistica 'error'), 2825 (Write-FalloDeducido excluye 'dictado vacio')

**Cómo se hace.** Un solo cambio en Get-AnimoDia (assistant.ps1:2947): que $mal sume 'descarte' + 'ruido' en vez de 'error'. La fórmula (Get-AnimoDeCuentas) no se toca, y ya vive en un solo sitio con su banco. Get-AvisoFallos ya hizo exactamente este cambio el 22/09 por esta misma razón, así que hay precedente medido dentro de la casa.

**Riesgo y guarda.** Que el ánimo suba de golpe y Nova hable más justo al estrenarlo. La guarda: 'descarte' está medido (163 en 12 días, más que los 80 'error'), así que el listón no se afloja, cambia de sitio; y el ánimo largo (7 días, mínimo 10 sucesos por día) amortigua el salto del primer día.

> **El verificador corrigió el dato:** El dia sale -0,833 con 'error' y -0,500 con 'descarte', exacto; pero ese -0,50 es con 'descarte' SOLO, no con 'descarte'+'ruido' como dice el "como": con los dos el 25/09 da -0,895, mas bajo que hoy. Y el animo LARGO no da -0,40 / -0,35: recalculado con Get-AnimoLargo (7 dias, peso 1/(j+1), minimo 10 sucesos) sale -0,313 con 'error' y -0,320 con 'descarte' a 25/09, o -0,240 y -0,302 a 26/09. O sea que el 25/09 el suelo se parte en dos en los dos casos y el cambio no mueve esa decision ese dia; a fecha de hoy la mueve al reves de lo que dice el riesgo (hablaria MENOS, no mas).

### 3. Quejarte cuenta como fallo aunque Nova no sepa rehacer la orden ⬆ ∿

**Valor 9 · coste 3 · ángulo `aprender`**

**Qué.** Cuando te quejas justo después de que Nova haga algo, hoy Nova intenta reconstruir la orden buena y, si no lo consigue, no apunta nada: ni la queja ni el fallo. La idea es separar las dos cosas. Rehacer la orden es difícil y puede salir mal; marcar que ESA orden estuvo mal es fácil y no ejecuta nada. Esa marca es el único dato humano que mide la meta número uno de braya.

**El dato.** pruebas/audio/uso/destinos.jsonl tiene 588 órdenes reales y CERO con 'fallo-dicho-por-ti'. Ni una en toda la vida de Nova. Mientras tanto, de las 365 frases que acabaron en la charla, 76 encajan en el patrón de queja que Nova ya tiene escrito, y 35 de esas 76 llegaron con una orden ejecutada en los 180 s anteriores. La línea 'CORRECCION:' no aparece ni una sola vez en assistant.log ni en assistant.log.1: el camino entero lleva desde el 16/09 sin dispararse nunca.

**Dónde se comprobó.** wc -l pruebas/audio/uso/destinos.jsonl = 588 y conteo por 'hizo' (charla 261, traducir 102, local 84, descarte 40, traducida 26, ruido 21, plan 15, pregunta 12, accion 12, recitado 7, error 7, memoria 1; ningún fallo). grep -c '  CORRECCION:' assistant.log assistant.log.1 = 0 y 0. El código: assistant.ps1:2769 (Write-FalloUso) y assistant.ps1:25764 (solo se llama si la reconstrucción pasa Test-FastCommand).

**Cómo se hace.** En assistant.ps1:25751, sacar el Write-FalloUso del if que exige que la orden reconstruida sea ejecutable: si Get-OrdenCorregida devuelve algo -o si la frase solo encaja en $RE_QUEJA y hay una orden reciente-, se marca el fallo y se sigue el camino de siempre. Marcar no ejecuta nada, así que no toca la regla 1. Y la ventana de 180 s pasa a ser la misma medida de la idea de la cuarentena, no un número escrito. Detalle que ya avisa el propio comentario del código: no meter 'correccion' en $DestinosUso, que Write-DestinoUso consume el id.

**Riesgo y guarda.** Marcar como fallo una orden buena porque la frase siguiente empezaba por 'no' y era charla (de las 76, muchas lo son). Como la marca va en destinos.jsonl y es la señal humana limpia, la guarda es exigir las formas que niegan lo dicho -'no te pedí', 'yo no dije', 'lo que dije fue'- y no el 'no' suelto de cabeza; las formas flojas van al fichero de sospechas, que para eso existe aparte.

> **El verificador corrigió el dato:** Las quejas con orden reciente son 34, no 35. Y hay que corregir la premisa: NO es cierto que hoy 'si no lo consigue, no apunta nada' en general; por el camino 'noEraEso' (4640 -> Invoke-AprenderDelError 7279) si se apunta sin reconstruir. Lo que falta es solo en el camino de Get-OrdenCorregida (25751).

### 4. Volver al juego no es entrar en el juego ∿

**Valor 8 · coste 3 · ángulo `juegos`**

**Qué.** Cada vez que la ventana del juego vuelve al primer plano, Nova aplica el perfil y dice 'Modo juego' en voz alta. Un alt-tab de veinte segundos cuenta como entrar. Que aprenda de sus propias vueltas cuánto dura un alt-tab suyo y se calle cuando es el mismo juego de hace un momento.

**El dato.** 56 veces se aplicó el perfil en 14 días, y 30 de esas 56 son volver al MISMO juego en menos de una hora. Los huecos medidos: 24 s, 24 s, 30 s, 41 s, 47 s, 52 s, 110 s, 113 s, 121 s, 130 s, 141 s, 221 s... la mediana de las 30 vueltas es 280 s. O sea que la mitad de esos 'Modo juego' llegan menos de cinco minutos después del anterior. Solo hubo 9 cierres de verdad en esos 14 días. La tarjeta hermana (Show-RecuerdoJuego) ya tiene la guarda de una hora; la frase hablada no tiene ninguna.

**Dónde se comprobó.** assistant.ps1:20665 (Say "Modo $JuegoPerfilEntrar.") contra assistant.ps1:8886 (la guarda de 3600000 ms de Show-RecuerdoJuego); grep "perfil 'juego' aplicado" assistant.log assistant.log.1 | cuenta = 56, y el recuento de re-entradas al mismo juego en menos de 1 h = 30

**Cómo se hace.** En Enter-Juego, antes del Say, se mira el hueco desde la última entrada a ESE juego. Si es menor que el corte aprendido, se aplica el perfil igual (el brillo hay que ponerlo) pero no se habla ni se manda el evento a la cápsula, y se escribe una línea en el log diciendo que se calló y por qué. El corte se guarda en habitos.json y se recalcula con las vueltas de los últimos 14 días.

**Riesgo y guarda.** Callarse cuando sí era una partida nueva. Guarda: si el proceso del juego CAMBIÓ de identificador, es una partida nueva de verdad y se habla siempre, por corto que sea el hueco. Nova ya guarda ese identificador ($script:juegoPid) desde el 19/09.

### 5. Que la misma excepcion dos veces en el mismo turno no se tape con un dictado vacio ⬆

**Valor 8 · coste 3 · ángulo `errores`**

**Qué.** En el catch del bucle del worker se guarda el texto de la ultima excepcion. Si se repite IDENTICO dentro del mismo dictado, deja de rehacer el reconocedor (un fallo del propio codigo no lo arregla rehacerlo) y marca el turno como perdido, para que Nova diga 'se me ha ido, repitemelo' en vez de entregar un vacio como si no hubieras dicho nada.

**El dato.** 25/09 a las 21:33:19 braya la llamo cuatro veces seguidas: 'ACTIVADO por nova nova nova nova (confianza 1.00)'. A las 21:33:23, 21:33:27 y 21:33:28, tres veces el mismo fallo: "fallo en una vuelta del bucle: name 'callado' is not defined". Las tres veces rehizo el reconocedor. Y lo que llego a las 21:33:29 fue 'dictado: 8 s sin oir nada; no hay nada que transcribir' -> 'vacio, ignorado'. La orden se perdio entera y en silencio. Cuatro veces ese dia (tres a las 21:33 y una a las 22:48).

**Dónde se comprobó.** assistant.log lineas 6623-6633. Codigo: wake_vosk.py:4165-4175 (el except del bucle, que rehace el reconocedor y sigue), y la causa: wake_vosk.py:3684 usa 'callado' 45 lineas antes de que 3729 lo asigne, asi que el primer dictado tras arrancar el worker revienta.

**Cómo se hace.** En wake_vosk.py, junto al except de 4165: una variable _ultimo_fallo con (texto, hora). Si el texto es identico y estamos dentro del mismo dictado, se salta nuevo_reconocedor() y se escribe en RUTA_DICTADO una marca 'PERDIDO' que el asistente ya sabe leer por el mismo camino que el dictado vacio. En Process-Texto, 'PERDIDO' se contesta con una frase corta en vez de con 'vacio, ignorado'.

**Riesgo y guarda.** Confundir un fallo pasajero de Vosk (un json raro, que es para lo que se hizo rehacer el reconocedor) con uno de codigo y dejar de recuperarse. Lo evita que la condicion sea el texto EXACTAMENTE igual y dentro del mismo dictado: dos json distintos no dan el mismo texto.

### 6. El tiempo se vuelve a pedir por red en dos de cada tres consultas ∿

**Valor 8 · coste 3 · ángulo `continuidad`**

**Qué.** El clima se guarda una hora, pero solo dentro del proceso. Cada arranque nace con la cache vacia y con el reloj puesto en 'hace una hora', asi que a los 20 segundos de vivir Nova sale a internet otra vez aunque el dato de hace cuatro minutos siga siendo bueno. Guardandolo en disco con su hora, casi todas esas llamadas desaparecen del camino del arranque.

**El dato.** 495 lineas 'clima:' en los dos registros; 335 de ellas (el 68 %) caen en los 3 minutos siguientes a un arranque. La cache es $script:clima con $script:climaCheck arrancando en -3600000, y la consulta es un Invoke-RestMethod a api.open-meteo.com con 4 s de plazo. No existe ningun memoria/clima.json.

**Dónde se comprobó.** assistant.ps1:19101-19102 (las dos variables), 19143 (Invoke-RestMethod con TimeoutSec 4), 28444 (la condicion de la hora). Conteo cruzado de lineas 'clima:' contra los 'VoiceAssistant iniciado' de assistant.log.1 + assistant.log.

**Cómo se hace.** En el bloque que ya rellena $script:clima (19165) escribir tambien memoria/clima.json con emoji, desc, temp y hora. Al arrancar, leerlo: si es mas reciente que la ventana valida, se carga en $script:clima y $script:climaCheck se pone como si acabara de mirar.

**Riesgo y guarda.** Decir un tiempo viejo. Guarda: la ventana sale de cuanto se mueve de verdad la temperatura entre dos lecturas suyas guardadas, y tiene tope duro en una hora, que es lo que ya hay hoy; si el fichero es mas viejo, se ignora y se pregunta.

### 7. Lo que se aprende tiene que llevar tu frase como clave, no la que Nova se reescribió ⬆

**Valor 8 · coste 3 · ángulo `aprender`**

**Qué.** Cuando la charla decide que lo que dijiste era en realidad una orden, reescribe la frase a su manera y es ESA la que acaba guardada en traducciones.json. O sea que Nova aprende a entender sus propias palabras, que nunca vuelves a decir. La frase real se tiene delante ($ev.original), se escribe en el log y se tira. Basta pasarla hasta el sitio donde se aprende.

**El dato.** De las 21 líneas APRENDIDO del log, 8 tienen como clave una frase que braya NO dijo ni escribió nunca en esa forma: 'cambia al bloc de notas', 'Ensectiva el modo noche', 'Que ponga muzigen, YouTube', 'Mira, por qué no me dices cuánto espacio libre me queda en la consola', 'Cierra Google', 'Sí, abre Steam', 'Cierra el administrador' y 'Cierra este in.'. La última es justo la que envenenó el vocabulario el 25/09: braya dijo 'Que habla, dije que cerraras este in' y lo que se guardó fue 'Cierra este in.' = 'cierra discord'. Y explica el otro número: 21 aprendidas, 1 sola usada jamás.

**Dónde se comprobó.** assistant.log:5973 ('charla: no era charla sino una orden -> Cierra este in. (dicho: Que habla, dije que cerraras este in)') frente a assistant.log:5982. El $ev.original que se desaprovecha: assistant.ps1:23067. Donde se aprende la clave equivocada: assistant.ps1:23615. Y 117 eventos de 'no era charla sino una orden' en total, 34 de ellos con reconstrucción distinta de lo dicho.

**Cómo se hace.** En assistant.ps1:23067 llevar [string]$ev.original en $script:fraseComoLaDijiste junto con el sello de tiempo, y usarla en assistant.ps1:23615 como clave de Add-Traduccion cuando exista y sea reciente (la orden reescrita sigue siendo lo que se EJECUTA, solo cambia bajo qué nombre se archiva). Lo mismo en el camino del oído fino y del último recurso, que también sustituyen la frase. Si las dos formas son distintas, se guardan LAS DOS apuntando al mismo destino: la reconstruida no estorba y la tuya es la que va a volver.

**Riesgo y guarda.** Que la frase original sea tan larga o tan sucia que no sirva de clave. Lo tapa el filtro que ya existe en assistant.ps1:23612 (más de 6 palabras, nombre propio perdido, letras rotas): se aplica a la clave nueva igual que a la vieja, y si no pasa, no se aprende, que es lo que pasa hoy de todas formas.

> **El verificador corrigió el dato:** Las claves que braya NUNCA dijo son 4, no 8. Cruzando las 8 contra los 866 dictados + ORDEN ESCRITA, normalizando acentos y puntuacion: NUNCA DICHAS solo 'cambia al bloc de notas', 'Ensectiva el modo noche', 'Que ponga muzigen, YouTube' y 'Cierra este in.'. Tres se dijeron EXACTAMENTE tal cual ('Mira, por que no me dices cuanto espacio libre me queda en la consola', 'Si, abre Steam', 'Cierra el administrador') y 'Cierra Google' aparece contenida en una frase dicha. O sea 4 de 21, no 8 de 21. La idea sigue en pie porque la que envenevo el vocabulario el 25/09 esta entre las 4, y el mecanismo roto se ve entero en el log.

### 8. El plazo de cada repaso sale de lo que tarda ese motor, no de un 15 fijo ⬆ ∿ ⚙

**Valor 8 · coste 4 · ángulo `numeros-fijos+ordenes-fallidas`**

**Qué.** Todos los repasos del oido comparten un solo plazo escrito a mano, 15 segundos, y el ultimo recurso otro, 60 segundos: dos numeros fijos para cinco motores que tardan cosas muy distintas. Nova ya apunta cuanto tarda cada repaso en pruebas\audio\uso\registro.jsonl, asi que cada motor (canary, base, small, omni, turbo) pasa a tener su propio plazo, sacado del p90 de sus propias medidas, entre un suelo y un techo. Y de propina, en Request-WhisperTras, si el p50 del motor de ese escalon ya se sale del techo, ese escalon ni se pide: se salta al siguiente, que pedirlo cuesta plazo y sordera. Mientras un motor no tenga bastantes muestras, manda el numero de siempre.

**El dato.** 477 repasos con su tiempo apuntado en registro.jsonl (no 469; el recuento se rehizo). Por motor: canary n=29, p50 3,0 s, p90 8,78 s, p99/maximo 14,53 s, NINGUNO pasa de 15 s -o sea que le sobran 6 segundos-; base n=328, p90 5,96 s, 6 pasan de 15 s; small n=94, p90 28,78 s, p99 238,88 s, DOCE pasan de 15 s; omni n=3, uno pasa; turbo n=23, p90 22,87 s, DIECISIETE pasan de 15 s (y ese tiene su propio fijo, $ReintentoUltimoMs = 60000, que tambien sobra: 60 contra un p90 de 22,87). Contando el oido fino como bloque salen 132 medidas con p50 4,9 s, p90 24,5 s y maximo 238,9 s. El resultado en el log: 30 lineas 'OIDO FINO: sin respuesta a tiempo; sigo con lo que tenia', y de esas 24 SI contestaron despues, a los 8, 12, 13, 14, 14, 23, 24, 28, 28, 28, 30, 31, 31, 32, 32, 35, 42, 45, 61, 88, 89, 142, 142 y 238 segundos: 30 repasos pagados y tirados. Y mientras corren, el microfono se queda sordo: 507 tiradas de audio atrasado por '(oido fino)' que suman 3.618 segundos.

**Dónde se comprobó.** assistant.ps1:24206 ($ReintentoMaxMs = 15000) y sus TRES usos, 24511 (Request-WhisperTras), 25733 y 26089; assistant.ps1:24541 ($ReintentoUltimoMs = 60000) usado en 24569. La maquinaria que se reaprovecha: Add-TrabajoTiempo (22163), Get-TrabajoPercentil (22189) y sus topes en 22128-22133. Medicion: python sobre pruebas\audio\uso\registro.jsonl agrupando 'segundos' por 'motor'; conteos: grep -c 'sin respuesta a tiempo' y grep -oE "oido fino: '[^']*' \([0-9.]+ s\)" sobre assistant.log y assistant.log.1.

**Cómo se hace.** No hace falta fichero nuevo: la maquinaria esta hecha y no se usa aqui. Add-TrabajoTiempo / Get-TrabajoPercentil (assistant.ps1:22163 y 22189) ya traen tope de 60 muestras por clave, minimo de 10 ($TrabajoTiemposMin, por debajo devuelve 0 = 'no me preguntes todavia'), y suelo/techo de 0,5x y 2,0x lo escrito ($TrabajoSuelo/$TrabajoTecho). Se anade una llamada a Add-TrabajoTiempo 'repaso-canary' (y base, small, omni, turbo) donde ya se registra el tiempo de cada repaso, y $ReintentoMaxMs se sustituye por un Get-PlazoOido($motor) -calcado de Get-DuracionEsperada, assistant.ps1:22205- en los tres sitios que lo usan (24511, 25733, 26089), con el 15000 de respaldo; lo mismo para $ReintentoUltimoMs en 24569 con el 60000 de respaldo. Ademas, en Request-WhisperTras (assistant.ps1:24498), si el p50 de ese motor ya supera el techo, se salta ese escalon y se pasa al siguiente.

### 9. Se queda sin su repaso fino por falta de disco y no lo dice ⬆

**Valor 8 · coste 4 · ángulo `iniciativa`**

**Qué.** Cuando arranca la escucha y no hay sitio, el worker decide no cargar parakeet, ni el oído fino, ni canary: lo escribe en su registro y sigue. Nova oye peor esa sesión entera y no lo cuenta. El aviso 'disco-poco' dice los gigas que quedan, pero nunca la consecuencia, y salta por un listón de gigas en vez de por lo que de verdad ha pasado.

**El dato.** 32 veces en 17 días el worker escribió 'no lo cargo, solo quedan X MB libres': 18 de parakeet (le hacen falta 1200 MB), 8 del oído fino (900) y 6 de canary. Concentradas: 18 el 18/09 y 9 el 25/09. En ninguna de esas 32 dijo Nova una palabra. Enfrente, 'disco-poco' ha salido 7 veces en 10 días y nunca en la misma sesión que una de esas 32.

**Dónde se comprobó.** Contado con: grep 'no lo cargo, solo quedan' sobre assistant.log + assistant.log.1 (las tres variantes salen del worker). El aviso de disco que sí existe está en assistant.ps1:28606-28608 (disco-critico y disco-poco).

**Cómo se hace.** El worker ya escribe escucha-estado.txt; que marque en un campo nuevo al final qué repaso se ha quedado fuera y cuántos megas faltaban (el mismo patrón de añadir al final que documenta decir_estado en wake_vosk.py:3053). Nova lo lee una vez por arranque y dice: 'me he quedado sin mi repaso fino, me faltan 280 megas'. Nivel 'medio', y con el mismo cadaMin que disco-poco para que no sea otra frase encima.

**Riesgo y guarda.** Que se convierta en una segunda queja del disco pegada a disco-poco. La guarda es la que ya usa Nova para eso: los dos avisos comparten cola y Send-AvisoCola los dice en UNA sola frase, y dejar que el del oído vaya delante, que es el que trae la consecuencia y no solo el número.

### 10. Hay una clave de Anthropic en claro en tmp desde hace catorce dias ∿

**Valor 8 · coste 4 · ángulo `privacidad`**

**Qué.** Nova barreria sola lo personal que queda tirado en tmp. Hoy nadie lo hace: los borrados son cinco Remove-Item escritos a mano fichero a fichero. Pasaria a repasar tmp al arrancar y tirar lo que lleve mas tiempo del que ese fichero suele vivir, avisando en el registro de cuanto solto.

**El dato.** tmp\clave.txt tiene 109 bytes y dentro una clave sk-ant-api03- entera y usable, escrita el 12/09: catorce dias en claro. Es el unico sk-ant que hay en todo el proyecto. Al lado: pantalla.png, 1.995.159 bytes, una captura de la pantalla de braya del 25/09 que ademas viajo a la nube y que NADIE borra; prueba-pantalla.png del 15/09 (1.266.994 bytes); correo-manana-c2ab6a6f.json del 17/09 con el remitente y asunto de 5 correos suyos, uno de Chase que empieza 'Hello Brayan'; ultima-orden.wav y nube-817de444.wav con su voz; mi-voz.json con su biometria (f0 121,2). Son 11 ficheros y 3,6 MB de datos personales. El fichero mas viejo de tmp es del 11/09, 15 dias. En assistant.ps1 solo hay 5 Remove-Item sobre $TmpDir, todos de un fichero concreto por su nombre.

**Dónde se comprobó.** ls -la tmp/clave.txt -> 109 bytes, 2026-09-12; head -c 200 tmp/clave.txt -> sk-ant-api03-...; grep -rlE 'sk-ant-api03-[A-Za-z0-9_-]{20,}' . --exclude-dir=.git -> solo ./tmp/clave.txt; assistant.ps1:20722, 24505, 24851-24853 (los unicos borrados en tmp); ls -lat tmp/ | tail -3 -> _chk_reg.json 2026-09-11

**Cómo se hace.** Funcion nueva Clear-TmpViejo en assistant.ps1, llamada una vez al arrancar junto al resto de inicializaciones. Lee tmp\vida-tmp.json, donde por cada NOMBRE de fichero se guarda cuanto suele tardar en reescribirse (mediana de los intervalos observados entre LastWriteTime consecutivos). Si un fichero lleva sin tocarse mas de tres veces su vida normal, fuera. Los que nunca se han visto reescribirse empiezan con el plazo que salga de la mediana global. clave.txt, las capturas y los .wav entran los primeros. Aparte, y por separado, avisar a braya UNA vez de que esa clave estaba ahi para que la rote.

**Riesgo y guarda.** Borrar un fichero que un proceso esta usando ahora mismo (wake-worker.lock, ui-estado.json, escucha-estado.txt). La guarda: no se toca nada cuyo LastWriteTime sea de esta sesion, ni ningun .lock o .flag, y el barrido corre solo al arrancar, antes de lanzar el worker. Y el aviso de la clave se da una vez y se apunta, para no convertirse en un modo que se queda.

> **El verificador corrigió el dato:** tmp no son 11 ficheros ni 3,6 MB: son 136 ficheros y 52 MB (ls -1 tmp | wc -l -> 136; du -sm tmp -> 52). Los 11 personales citados si estan uno a uno; lo que falta contar son los 20 assistant.ps1.bak-* y wake_vosk.py.bak-* del 15-20/09, que solos pesan ~13 MB y tambien llevan la clave de Steam dentro.

### 11. Que corregir a Nova hablando sirva de algo: marcar el recuerdo malo, y cambiarlo cuando dices el bueno ∿ ⚙

**Valor 8 · coste 5 · ángulo `charla+aprender`**

**Qué.** Hoy la unica forma de que Nova de por mala su ultima respuesta es decirle una de seis frases exactas que ademas tienen que EMPEZAR la frase ('eso no es verdad', 'te equivocas'...). braya no corrige asi nunca: corrige en mitad de la frase ('no, te confundes', 'no, ahi te equivocaste', 'no se llama a mi, se llama Amino'). Resultado: el recuerdo que acaba de nacer de la respuesta equivocada se queda firme para siempre. Se arregla en un solo sitio -el worker de la charla, donde ya vive un detector de correcciones medido- y de paso, cuando la correccion trae el valor bueno, se SUSTITUYE la respuesta del recuerdo en vez de dejarlo solo tachado y sin nada en su sitio.

**El dato.** Los 365 turnos de charla del registro (14 dias): braya corrige 61 veces, el 16,7 %, medido con el detector que ya esta en charla_worker (RE_CORRIGE caza 41 frases; de las 66 que empiezan por 'no', las 56 de cinco palabras o mas son practicamente todas correcciones). De esas 61, CERO encajan con el patron anclado con ^ de assistant.ps1:25333, que en 14 dias no se ha disparado ni una vez por voz. Dentro de esas 61 hay 4 correcciones de DATO en medio de frase -no 7, recontadas sobre los 866 dictados-: 'No te confundes, La musica electronica si me gusta...', 'No, no te llamas eres Nova, te llamas Nova...', 'no se llama a mi, se llama Amino' y 'No, ahi te equivocaste, Bueno, si hay una estructura de madera...'; esas cuatro son las que traen el valor bueno y por eso valen para sustituir, no solo para tachar. El aviso 'queda como incorrecta' sale UNA sola vez en las 58.643 lineas de assistant.log + assistant.log.1 (2026-09-13 19:18:49), y la linea anterior es 'ORDEN ESCRITA: eso no es verdad': tecleada a mano en una prueba, no hablada. Esa unica vez es la unica 'rechazada' del cerebro: memoria/cerebro/cerebro.json tiene 121 recuerdos, 120 en estado 'firme' y 1 'rechazada'. O sea, 61 correcciones habladas, 0 recuerdos marcados por voz en todo el historial.

**Dónde se comprobó.** charla_worker.py:930 (por_que_importa), :908-925 (RE_CORRIGE, RE_NEGACION y su medicion en el comentario), :576-581 (la unica rama que llama a marcar_incorrecta, solo con duda=true), :718 y :619 (ultimo_dicho / rAp['recuerdo']); charla_memoria.py:708 (marcar_incorrecta: pone estado 'rechazada'), :354 (buscar excluye las rechazadas), :377 (respuesta_directa exige 'firme'); assistant.ps1:25333 (el patron anclado con ^ tras Test-CharlaCaliente), :22832 (Send-Charla y su flag duda), :25098 (Get-OrdenCorregida, el patron 'no es X, es Y' que ya existe). Conteos: grep -c 'queda como incorrecta' sobre assistant.log + assistant.log.1; el detector pasado por los 365 turnos extraidos de 'CHARLA (hablar):' / 'charla dice:'; cerebro.json contado con python.

**Cómo se hace.** Todo en charla_worker.responder(), en un solo sitio, para no acabar con dos detectores marcando el mismo turno: antes de contestar, si por_que_importa(texto, '') devuelve 'correccion', si el turno anterior fue hace menos de 180 s y si ese turno dejo un id (ultimo_dicho, o rAp['recuerdo']), entonces (a) si la frase trae el par malo/bueno -reutilizando el mismo patron 'no es X, es Y' / 'no se llama X, se llama Y' que Get-OrdenCorregida ya tiene en assistant.ps1:25098, portado al worker-, op nueva 'corrige' en charla_memoria.py que SUSTITUYE la respuesta de ese recuerdo; (b) si es una queja sin dato detras, cerebro.marcar_incorrecta(ese id), que solo pone 'rechazada' (nunca borra, es reversible, y buscar() ya deja fuera las rechazadas, asi que no hace falta tocar el camino de respuesta). En los dos casos, sacar su job de datos['pendientes'] para que el revisor de fondo no lo vuelva a dar por bueno. Una linea de log con la frase exacta que lo disparo, para poder contar los falsos a los quince dias y subir el liston si hace falta. El patron de assistant.ps1:25333 se deja como esta: sigue valiendo para forzar que Nova reconteste por API, pero ya no es el unico camino para marcar.

### 12. Una confianza gratis para Parakeet: cuánto coincide con lo que ya oyó Vosk ⬆ ∿

**Valor 8 · coste 5 · ángulo `oido`**

**Qué.** Hoy, cuando la orden la entrega Parakeet (el camino rápido, el de casi todas), Nova entrega el texto SIN ningún número de confianza: el asistente no tiene con qué medir si fiarse. Pero Vosk ha decodificado ese mismo audio en paralelo y su texto está ahí, gratis, sin gastar un milisegundo más. La idea es convertir el parecido entre los dos textos en el número de confianza que falta, escribirlo en dictado-confianza.txt como ya se hace con el de Whisper, y que el asistente decida con él: con acuerdo alto, adelante sin repaso; con acuerdo bajo, repaso directo sin esperar a fallar primero.

**El dato.** De las 560 órdenes guardadas (15-25/09), 422 se entregaron con seguridad = null: tres de cada cuatro llegan sin ningún número. Y el acuerdo Vosk/Parakeet SÍ separa: sobre las 347 órdenes que tienen texto de los dos y destino apuntado, con acuerdo alto (Jaccard >= 0,5; n=163) acabaron en la basura 17 (10 %); con acuerdo bajo (< 0,2; n=84) acabaron 27 (32 %). Triple de basura. Y hay 421 órdenes con los dos textos, así que el número se puede calcular casi siempre.

**Dónde se comprobó.** wake_vosk.py:3819 (guardar_uso con seguridad=_ultima_seguridad) y wake_vosk.py:2213, donde _ultima_seguridad solo se rellena dentro de transcribir_whisper. Conteo sobre pruebas\audio\uso\registro.jsonl (1.037 filas, 560 de orden) y destinos.jsonl (588 filas), emparejados por id.

**Cómo se hace.** En wake_vosk.py, junto a donde se arma texto_final (sobre la línea 3814, donde ya se comparan los cuatro oídos para RUTA_OIDOS), calcular el Jaccard de palabras sin tildes entre texto_vosk y oido_parakeet y escribirlo en dictado-confianza.txt con una marca de origen ('acuerdo'). El umbral no se escribe a mano: se guarda la lista de acuerdos con guardar_lista/cargar_lista (la misma máquina que ya usan coberturas y márgenes, con el nombre del micro) y el listón sale de su propio percentil. En assistant.ps1, donde ya se lee la confianza para decidir el repaso.

**Riesgo y guarda.** Que un acuerdo bajo pero correcto (Parakeet acierta y Vosk no) mande a repasar de más y le haga esperar. Por eso el número solo AÑADE un motivo para repasar y nunca impide entregar: si la cascada no saca nada, se entrega lo de Parakeet como hoy. Y el listón sale de sus propios percentiles, así que se corrige solo si Vosk empeora.

> **El verificador corrigió el dato:** Los dos números de cabecera son exactos: 560 órdenes, 422 con seguridad=null, 421 con texto de Vosk Y de Parakeet. Los porcentajes de basura también salen clavados: acuerdo alto 10 %, acuerdo bajo 32 %, triple. Lo que NO se reproduce son las n: emparejando registro.jsonl con destinos.jsonl por id salen 273 órdenes con los dos textos y destino (146 con Jaccard >= 0,5 y 14 a la basura; 50 con < 0,2 y 16 a la basura), no 347/163/84. destinos.jsonl tiene 588 filas pero solo 360 ids distintos, y solo 273 de esos coinciden con una orden que tenga los dos textos. La conclusión aguanta con muestra más pequeña.

### 13. Avisa del ruido sin comprobar si el ruido le ha costado algo ∿

**Valor 8 · coste 5 · ángulo `iniciativa`**

**Qué.** 'Hay un ruido de fondo y así no te voy a oír bien' salta con mirar un campo del estado de la escucha: si muchos bloques pasan la puerta y los altavoces están callados, ya lo dice. Nunca comprueba lo único que importa, que es si ALGUIEN ha intentado llamarla y no ha entrado. El worker ya cuenta descartes; solo hay que mirarlos antes de abrir la boca.

**El dato.** 33 de los 36 avisos 'oido-ruido' (el 92 %) salieron sin UN SOLO 'nova' descartado o ignorado en los 60 minutos previos. Los tres que sí tenían: 23/09 21:36 (3 descartes en 30 min), 25/09 11:04 (3) y 25/09 23:54 (16). El 22/09 lo dijo VEINTIDÓS veces entre las 08:00 y las 20:20, todas con cero descartes cerca. Y oido-ruido es el 37,5 % de toda la voz propia de Nova: 36 de 96 avisos.

**Dónde se comprobó.** assistant.ps1:11531 (la llamada), 11185 Get-OidoConRuido y 11216 Test-AvisarRuido; wake_vosk.py:3053 decir_estado. Medido cruzando las 36 líneas 'ENTORNO (oido-ruido' con las 697 líneas "descartado 'nova'" y "'nova' ignorado" de assistant.log + assistant.log.1.

**Cómo se hace.** Un octavo campo en escucha-estado.txt con los descartes de 'nova' de los últimos minutos por CUALQUIER motivo (el sexto ya lleva los flojos, así que el molde y el cuidado de añadir al final están escritos en decir_estado). En assistant.ps1, Test-AvisarRuido exige que ese número sea mayor que cero. Cuando no hay campo octavo (worker viejo) se comporta como hoy.

**Riesgo y guarda.** Que empiece el ruido, braya lo intente una vez, no entre y se calle sin saber por qué. No pasa: el disparo es el PRIMER descarte, no el quinto, así que el aviso llega en el mismo intento en que se le pierde. Y oido-mudo y oido-flojo, que son nivel 'alto', siguen delante y no se tocan.

> **El verificador corrigió el dato:** El 22/09 lo dijo 25 veces, no 22 (y es el mismo 25 que ya esta escrito en el comentario de assistant.ps1:11198). El 25/09 23:54 tenia 35 descartes en los 60 min previos, no 16. Y oido-ruido es el 50,7 % de la voz propia de Nova (36 de los 71 avisos que SUENAN), no el 37,5 %: ese 37,5 cuenta como voz los 26 'bajo' que nunca se dicen.

### 14. Que Nova note que el cerebro local esta apagado: dejar de llamarlo cada 65 s, levantarlo una vez y decirlo ∿ ⚙

**Valor 8 · coste 5 · ángulo `errores+red`**

**Qué.** Un unico estado "cerebro local" en charla_worker.py: al primer WinError 10061 deja de reintentar cada minuto y espera el doble cada vez desde su propio suelo (1, 2, 4... hasta 30 min), el primer exito borra la espera entera, lo dice UNA vez al caer y otra al volver (no 71 veces en el log), intenta arrancar ollama.exe una sola vez por sesion si no hay juego delante y sobra RAM, y si sigue sin estar lo DICE al contestar ("ahora mismo no tengo el modelo local") en vez de fallar en silencio. El freno se aplica SOLO al trabajo de fondo (resumen del diario, vectores, trivia), nunca a una peticion en caliente. Para la nube ese freno ya existe; para el local no hay ninguno.

**El dato.** Todas las lineas son del 26/09 y el contador crecia mientras se media: 31 -> 43 -> 46 -> 65 -> 71 lineas identicas "charla: diario: no pude resumir lo del 2026-09-25 ([WinError 10061] ... el equipo de destino denego expresamente dicha conexion)", de las 00:07:45 a la 01:28:21, una cada 65 s exactos, sin freno y sin cambiar nada. "no pude resumir" y "10061" dan los mismos 65-71 en assistant.log y CERO en assistant.log.1. Comprobado a mano: no hay ningun proceso ollama y http://127.0.0.1:11434 devuelve "No es posible conectar con el servidor remoto"; ollama.exe esta instalado en C:\Users\braya\AppData\Local\Programs\Ollama\ollama.exe y NO estaba en ejecucion. En la misma vuelta de ese bucle, completar_vectores() falla igual pero dentro de un "except Exception: pass", o sea que ni se ve. Y el plan B para cuando no hay internet no lo ha probado nadie: desde el 18/09 la charla lleva 178 "contesto (api)" frente a 3 "contesto (local)" (223 frente a 25 en todo el registro), y hoy no funcionaria.

**Dónde se comprobó.** charla_worker.py:63 (OLLAMA = http://127.0.0.1:11434), :1046-1057 (el POST del resumen sin freno; el except solo hace salida("info") y return False), :745-755 (revisar_una: el bucle que lo reintenta a cada pasada con 20 min sin charla, con el "except Exception: pass" de completar_vectores), :438 ("ollama no esta en marcha": httpx.ConnectError/ConnectTimeout ya estan distinguidos), :302 (api_disponible solo mira clave y saldo, nunca la red), :794 (el bucle de fondo ya se para con un juego delante). assistant.ps1:21750 y 23420 ($script:apiFallo: el mismo freno, pero solo para la nube; se consulta en 22637, 23282 y 23527). Contado con: grep -c "no pude resumir" assistant.log; Get-Process ollama* vacio; Invoke-WebRequest a 127.0.0.1:11434.

**Cómo se hace.** En charla_worker.py, al lado de OLLAMA: un dict de estado {url -> (fallos_seguidos, no_antes_de, caido_desde, arranque_probado)}. Un solo punto de entrada ollama_vivo() que devuelve False sin tocar la red mientras no toque el proximo intento; un ConnectError o ConnectTimeout dobla la espera desde su propio suelo y el primer exito la borra entera. resumir_dias_pasados (1046), completar_vectores (charla_memoria.py:775, llamada en 753) y la trivia pasan por el. Una sola linea de info al caer y otra al volver. El arranque: subprocess con "ollama.exe serve" oculto, UNA vez por sesion y nunca en bucle, solo si no hay juego delante (la misma guarda de revisar_una:794) y la RAM libre pasa del minimo que ya usa la precarga. Son unas veinte lineas de Python y no tocan el bucle de PowerShell.

### 15. Cuarentena: lo aprendido no toca el disco hasta que sobrevive el rato que tardas en corregir ⬆ ∿

**Valor 9 · coste 6 · ángulo `aprender`**

**Qué.** Hoy Nova escribe lo que aprende en el fichero en el mismo segundo, y cuando la corriges ya está guardado. La idea es que lo recién aprendido viva un rato en memoria y solo baje a disco si no lo has corregido. Si en ese rato dices que no, se cae sin haber existido. Y el rato no lo elige nadie: sale de lo que braya tarda de verdad en corregir.

**El dato.** El 25/09 a las 01:26:12 se escribió en disco 'Cierra este in.' = 'cierra discord'; a las 01:26:29, 17 segundos después, braya dijo 'No dije Discord, dije Steam'. Diecisiete segundos. Y todos los plazos de este área están escritos a mano: $DeshazEnsenaMs = 30000 (assistant.ps1:7260), 180000 para las recetas (7269), 180000 para las quejas (25082) y 300000 para marcar el fallo (2773). Cuatro números fijos, cero medidos. Las siete correcciones con hora que hay en 14 días llegaron entre 11 y 48 s, p90 = 44 s.

**Dónde se comprobó.** assistant.log:5982 y assistant.log:5995; assistant.ps1:7260, 7269, 25082 y 2773 (los cuatro plazos, comprobados con grep -n). Los retrasos reales salen de los 6 pares de repetición medidos más la corrección del 25/09.

**Cómo se hace.** En Add-Traduccion (assistant.ps1:7167) y Save-JuegoOido: en vez de llamar a Save-Traducciones al momento, dejar la entrada en $script:traduccionesEnCuarentena con su hora y programar el volcado en el pulso, que ya corre. Invoke-AprenderDelError y el camino de 'no dije X, dije Y' miran primero la cuarentena: si lo corregido está ahí, se borra de RAM y no se escribe nunca. El plazo de cuarentena es el p90 de los retrasos de corrección que Nova haya apuntado en memoria/correcciones-tiempos.json, con suelo y techo como ya hace el listón de letras por segundo de wake_vosk.py, y de paso ESE mismo número sustituye a los cuatro fijos de arriba.

**Riesgo y guarda.** Que Nova se cierre en esos segundos y se pierda lo aprendido. Es aceptable: perder una traducción que aún no se ha usado nunca cuesta mucho menos que quedarse con una envenenada para siempre, y Find-Traduccion ya la tiene disponible desde RAM mientras dura la cuarentena, así que no se nota en velocidad.

### 16. Un techo de ganancia aprendido, y que lo respeten los DOS caminos que la suben ⬆ ∿ ⚙

**Valor 9 · coste 6 · ángulo `log-uso+ordenes-fallidas+errores`**

**Qué.** Cuando el audio satura sin altavoces sonando, Nova baja la ganancia al 60 % y se olvida del valor que reventó. Después hay DOS caminos distintos que la vuelven a subir por encima de ese mismo valor, y por eso el pin-pon nunca acaba: (a) la rama de ruido constante, que devuelve la ganancia a 'la última buena' -justo la que saturó- y solo está protegida por una ventana fija de 45 s; y (b) la rama normal de calibración, que recalcula la ganancia desde cero a partir del p90 crudo, sube el 60 % del camino con un tope de salto de 4,0 y NO mira 'ultimo_recorte' para nada. La idea es que Nova aprenda un techo por micrófono -la ganancia que ya ha saturado con los altavoces callados- y que ese techo entre en el min() de los dos caminos, no de uno. El techo caduca solo si pasa el plazo sin ningún recorte, así que nunca se queda sorda.

**El dato.** RECORTES: 491 líneas 'recorte detectado: bajando ganancia' en 14 días (66 solo el 26/09). En 178 de ellas (36,3 %) la ganancia había vuelto a subir POR ENCIMA de la que acababa de saturar: 19 en menos de 30 s y 49 en menos de 60 s. Y 224 recortes llegaron a menos de 30 s del anterior. Ejemplos reales del rebote: saturó en x1,3 y 20 s después ya iba por x5,3; saturó en x0,7 y a los 250 s iba por x16,3; saturó en x9,8 y 41 s después por x21,8. CON LA GUARDA DE ALTAVOCES YA PUESTA (22/09 en adelante) siguen saliendo 140 recortes: 74 del 22 al 25/09 (31+21+3+19) y 66 el 26/09 él solo. 45 de ellos llegaron a menos de 10 min del anterior y 18 a más de 45 s, o sea FUERA de la ventana RECORTE_RECIENTE=45 que debía evitar el rebote: por eso la ventana fija no basta. LA VUELTA A LA 'BUENA': 99 'vuelvo a la x' en el registro, y van a más: 12 el 22/09, 2 el 23, 5 el 24, 39 el 25 y 41 el 26. La sierra es literal y siempre la misma: 23:53:55 x22,4 -> 23:54:02 x13,4 -> 23:58:10 x8,0 -> 23:59:47 x13,4 -> 23:59:57 x8,0 -> 00:01:05 x13,4 -> 00:01:56 x8,0 -> 00:07:08 x13,4 -> 00:08:18 x8,0: nueve recortes en 14 minutos. En la ventana de 37 min del 26/09 (00:01:05 a 00:38:09): 31 recortes y 18 vueltas a x22,4, una cada 50-100 s. LO QUE CUESTA: de 886 dictados medidos, los 83 que traían un recorte en los 20 s previos fallaron el 42,2 % frente al 25,7 % de los otros 803 -1,64 veces peor, z~3,3, p<0,001-, y 32 de esos 35 fallos acabaron mandando la orden entera a opencode. Cada vuelta del ciclo destroza un segundo de audio. Y EL PROPIO CÓDIGO LO PREDIJO el 22/09: 'Esperar al recorte NO BASTA -se probo, y solo espaciaba el pin-pon a un ciclo de 45 s'.

**Dónde se comprobó.** wake_vosk.py:360 (RECORTE_RECIENTE = 45,0, fijo) y :361 (ultimo_recorte); :3514-3521 (la rama que NO baja la ganancia cuando nivel_salida() > UMBRAL_ALTAVOZ) y :3525 (ganancia = ganancia * 0,6); :4059 (la vuelta a ganancia_buena, la única protegida por RECORTE_RECIENTE); :4099-4114 (la calibración recalcula desde cero, factor 0,6 al subir, tope PASO_MAX=4,0 y ninguna mirada a ultimo_recorte); :3040 (RUTA_GANANCIA) y :4151 (se guarda con el nombre del micro); :263-264 (GANANCIA_MIN=0,3, GANANCIA_MAX=40,0). assistant.ps1:11150-11162 (el 42,2 % frente al 25,7 % y la ventana de 20 s). Conteos: cat assistant.log.1 assistant.log | grep -c 'recorte detectado: bajando ganancia' -> 491; grep 'vuelvo a la x' assistant-pulso.log assistant.log.1 assistant.log | cut -c1-10 | sort | uniq -c. El pin-pon se cuenta emparejando cada recorte con el anterior y reconstruyendo la ganancia previa (la bajada es fija: ganancia*0,6).

**Cómo se hace.** En wake_vosk.py, UNA variable 'techo_recorte' con su fichero hermano de ganancia.txt -ligado al nombre del micrófono, como coberturas.txt, por el mismo camino de RUTA_GANANCIA (línea 3040)- y TRES sitios donde tocarla: 1) En el bloque del recorte (3505-3530), dentro del 'else' que sí baja la ganancia, es decir SOLO con nivel_salida() <= UMBRAL_ALTAVOZ: apuntar la ganancia de partida que acaba de saturar; si ese mismo valor ya estaba apuntado dentro del plazo, pasa a ser techo. 2) En la rama de la vuelta (4059): añadir 'ganancia_buena <= techo_recorte' a las condiciones que ya hay (cabe, RECORTE_RECIENTE). Este es el camino que produce las 99 'vuelvo a la x'. 3) En la rama de calibración (4114), antes del round final: 'propuesta = min(propuesta, techo_recorte * 0,9)'. Este es el camino que hoy no mira el recorte para nada y el que produce los saltos de x1,3 a x5,3. Ningún número a mano: el plazo del techo es la mediana medida entre dos recortes seguidos, guardada en tmp como ya se hace con rafagas.txt y ganancia.txt. El techo caduca solo -sube un escalón, dividido por 0,6, cuando pasan ~20 min sin ningún recorte- y nunca baja de la ganancia con la que se entregó una orden buena.

### 17. El oído se recorta a sí mismo el plazo cuatro de cada diez minutos y no se lo dice a nadie ⬆ ∿

**Valor 8 · coste 6 · ángulo `autoconocimiento`**

**Qué.** Cuando queda poca memoria, el oído encoge su propio plazo para soltar los modelos: con eso oye peor. Lo hace solo, lo apunta en su pulso y no se entera nadie: ni el cerebro, ni braya, ni las estadísticas. Además los tres números que gobiernan ese recorte están escritos a mano. El oído guarda un histograma de la memoria libre que ya mide, pone sus dos listones en su propio p60 y p15, y escribe una línea que el cerebro lee, para que Nova pueda decir 'hoy he estado oyendo con la memoria justa cuatro de cada diez minutos'.

**El dato.** 101 pulsos con ram_libre en assistant-pulso.log: 59 corren con plazo entero (x1,00), 42 recortado (el 41,6 %) y 10 en el suelo (x0,10). El mínimo medido fue 116 MB libres. Y los listones fijos: RAM_COMODA = 2500, RAM_APRETADA = 1000, SOLTAR_MIN_FACTOR = 0.1, mientras la mediana real de memoria libre de esta consola es 2.815 MB, o sea que el listón de 'cómoda' está justo por debajo de la mediana y por eso se recorta casi la mitad del tiempo. El comentario de esas mismas líneas cita a braya pidiendo que sea adaptativo y a continuación escribe los tres números a mano.

**Dónde se comprobó.** wake_vosk.py:815-828 (los tres números y plazo_soltar); wake_vosk.py:4129-4130 (donde se escribe el pulso); grep -ohE 'ram_libre=[0-9]+' assistant-pulso.log | awk bandas -> cómoda 59, media 32, apretada 10; grep -ohE 'plazo=x[0-9.]+' | uniq -c -> x1.00 59, x0.10 10

**Cómo se hace.** En wake_vosk.py, una lista corta de las últimas N lecturas de ram_libre_mb() -que ya se llaman en 8 sitios- guardada junto al resto del estado del oído, y plazo_soltar saca RAM_COMODA y RAM_APRETADA de su p60 y p15 en vez de las constantes. La línea para el cerebro va por anota_pulso, que ya existe, y el cerebro la cuenta con Add-Estadistica 'oido-apretado'.

**Riesgo y guarda.** Que con un juego abierto todo el rato el histograma se deslice hacia abajo y los listones acaben tan bajos que el oído no suelte nada y Nova se muera sin memoria, que es justo lo que pasó la madrugada del 19/09. La guarda: el histograma se corta por abajo en un suelo de seguridad y sólo cuentan lecturas de cuando NO hay juego en primer plano, que es cuando la foto de memoria es la de Nova y no la del juego.

> **El verificador corrigió el dato:** ram_libre_mb() se llama en 9 sitios de wake_vosk.py, no en 8

### 18. La puerta de los altavoces decide si te oye, y esta puesta a ojo ⬆ ∿

**Valor 8 · coste 6 · ángulo `numeros-fijos`**

**Qué.** Cuando los altavoces pasan de 0,02 Nova sube el liston de la palabra de activacion de 0,55 a 0,85, y ahi se le caen las llamadas. Ese 0,02 no sale de sus datos: en esta consola el silencio no es 0,0002, es cero clavado. Nova ya apunta el nivel de los altavoces en cada pulso y el desenlace de cada activacion: puede aprender a partir de que nivel el liston duro compensa de verdad.

**El dato.** 149 llamadas descartadas por esa rama en los dos registros. De esas, 109 (el 74 %) tenian confianza 0,55 o mas, o sea que habrian pasado con el liston normal; y 55 (el 36,9 %) van seguidas en menos de 60 segundos de una activacion buena o del boton, que es la prueba de que era braya. El nivel de altavoces de esos descartes es p25 0,072 y mediana 0,128, muy por encima del 0,02. Y en los 14.393 pulsos con altavoces apuntados, 13.414 (el 93,2 %) valen 0,000 exactos: entre 0 y 0,02 solo caen 86 pulsos, el 0,6 %. Ademas, en pruebas\audio\uso\activaciones.jsonl las 61 activaciones que pasaron con el liston duro acabaron en orden 43 veces (70 %), MAS que las 46 del liston flojo (28, el 61 %): el liston duro se esta aplicando a llamadas de verdad.

**Dónde se comprobó.** wake_vosk.py:606 (UMBRAL_ALTAVOZ = _num_de_config('umbralAltavoz', 0.02)), rama de descarte en wake_vosk.py:3927. Medicion: grep de 'altavoces=' en los dos logs (n=14.393) y de "descartado ...: confianza N < N (altavoces N > N" (n=148), mas python sobre activaciones.jsonl (n=107).

**Cómo se hace.** En wake_vosk.py ya existe apuntar_uso() y el fichero activaciones.jsonl con conf, umbral, altavoces y desenlace. Se anade una funcion umbral_altavoz() -igual de pequena que umbral_rafaga(), wake_vosk.py:303- que lee ese fichero al arrancar y devuelve el nivel a partir del cual, en las ultimas 100 activaciones, el liston duro deja fuera MENOS del 20 % de las que acabaron en orden. Con menos de 30 activaciones apuntadas, el 0,02 de siempre.

**Riesgo y guarda.** Subir la puerta es aflojar la guardia justo cuando suena el juego, y la regla 1 de la casa dice que Nova no puede hacer algo que nadie pidio. Tres guardas: el techo se queda en UMBRAL_ALTAVOZ_FUERTE (0,35), donde la palabra ya se ignora entera; el filtro de rafaga relativa a su voz (wake_vosk.py:303) sigue delante y es el que caza el silencio amplificado; y jugando sigue mandando 'solo el boton'.

### 19. Las tres transcripciones de cada orden, guardadas y tiradas ⬆ ∿

**Valor 8 · coste 6 · ángulo `muertas`**

**Qué.** De cada orden grabada Nova guarda lo que oyo Vosk, lo que oyo Parakeet, lo que oyo Whisper y cual fue el texto que acabo usandose. Son 543 filas con la respuesta correcta al lado: el corpus exacto para saber de que motor fiarse. El unico codigo que abre ese fichero lee el id y el origen y tira los cuatro textos. La idea es que Nova mida su propia cascada con lo que ya tiene en disco, en vez de esperar meses a juntar 20 muestras nuevas.

**El dato.** pruebas/audio/uso/registro.jsonl tiene 1.037 lineas; 543 traen los tres motores y el texto entregado. Contadas: Parakeet dijo exactamente lo entregado 408 veces (75 %), Whisper 134 (25 %), Vosk 73 (13 %). Parakeet volvio vacio 122 veces, y en 13 de esas 122 Vosk YA decia palabra por palabra lo que se acabo entregando ("que hora es", "toma una captura de pantalla", "cual es el clima para hoy"), pero igualmente se llamo a Whisper en 121 de las 122. Mientras tanto el motor que si deberia juzgar la cascada esta en ayunas: repaso:canary y repaso:base valen 5 cada uno, de UN solo dia, y repaso-sirvio no existe en estadisticas.json (cero en 14 dias), cuando el caso 5 de Test-RevisionPropia pide 20 muestras repartidas en 3 dias.

**Dónde se comprobó.** assistant.ps1:2881-2900 (Get-FalsasAlarmas: del registro solo saca Matches[1] -el id- y 'origen'; comprobado con grep de campos sobre ese bloque). Escritura en wake_vosk.py. Los 543/408/134/73 y los 13 de 122 salen de leer registro.jsonl y comparar en plano (sin tildes ni signos) cada motor contra el campo 'entregado'.

**Cómo se hace.** Una funcion nueva, Get-MotoresMedidos, al lado de Get-FalsasAlarmas (assistant.ps1:2878) y con su mismo truco de cache por tamano de fichero para no releer en cada orden. Devuelve, por motor, cuantas veces su texto fue el entregado. Con eso: (a) alimentar el caso 5 de Test-RevisionPropia con datos que ya existen en vez de los contadores vacios; (b) en el punto donde hoy se lanza el repaso porque Parakeet vino vacio, mirar primero si el texto de Vosk -que ya esta en memoria y no cuesta nada- pasa Test-FastCommand, y si pasa, no llamar a Whisper.

**Riesgo y guarda.** Fiarse de Vosk, que es el peor de los tres (13 %), y ejecutar una orden mal oida. La guarda es la que ya existe: el texto de Vosk solo se acepta si Test-FastCommand lo reconoce ENTERO como una orden cerrada; si no, la cascada sigue igual que hoy. Y el otro riesgo, que leer 1.037 lineas en cada orden cueste velocidad, lo resuelve el mismo sello por tamano de fichero que Get-FalsasAlarmas usa desde el 20/09 (7,9 ms con 820 lineas, y solo cuando el fichero ha crecido).

> **El verificador corrigió el dato:** La mitad (b) esta mal situada y hay que corregirla antes de implementarla: el texto de Vosk NO esta en memoria donde se decide el repaso. La decision se toma en assistant.ps1:27646 y ahi solo existe $dicPar (lo de Parakeet); grep de 'vosk' en assistant.ps1 solo devuelve claves de config y el nombre del proceso. Vosk vive unicamente dentro de wake_vosk.py y de ahi salta a registro.jsonl, y Test-FastCommand es PowerShell. Asi que 'no cuesta nada' es falso: haria falta que wake_vosk.py pasara su texto al asistente. Ojo tambien a que ese punto ya tiene una guarda parecida (repaso-ahorrado, 27632, 12 usos), asi que la rama nueva debe colgarse al lado y no encima.

### 20. Mientras braya juega, la cápsula no se duerme nunca aunque tenga ocho interruptores para apagarse ∿

**Valor 8 · coste 6 · ángulo `capsula`**

**Qué.** Dormir() exige a propósito que no haya juego delante, así que durante las horas de partida siguen vivos todos los relojes: el de 33 ms, el de la mirada a 66 ms, el del estado a 80 ms, el de 'ponerse encima' a 300 ms y el de 250 ms. La cápsula ya trae ocho interruptores para apagar piezas, pero solo se encienden con una variable de entorno que el cerebro no pone nunca. Que Nova decida sola cuáles apaga cuando hay un juego delante, y los vuelva a encender al salir.

**El dato.** 72.176 segundos de juego (20 horas) en 11 días según memoria\juegos.json, y en todos ellos la cápsula queda despierta por la condición 'string.IsNullOrEmpty(juegoActual)' de Dormir. Los relojes permanentes suman unos 65 tics por segundo (30 + 15 + 12,5 + 4 + 3,3). El propio comentario del código dice que solo respirar costaba el 28 % de un núcleo antes de capar a 12 fps. Los ocho interruptores (transp, z, blur, efectos, sombras, tic33, mirar, latido) tienen 0 usos desde assistant.ps1: grep -c NOVA_DIAG assistant.ps1 da 0.

**Dónde se comprobó.** nova_ui.cs:905 (condición de Dormir), 848-866 (los cinco relojes y sus intervalos), 1750 (el comentario del 28 % de un núcleo), 388-389 (diag y Sin()); memoria\juegos.json (suma de los segundos por día de los 8 juegos = 72.176).

**Cómo se hace.** nova_ui.cs: 'diag' deja de ser static readonly y pasa a leerse en caliente de un campo nuevo 'piezas' de ui-estado.json dentro de LeerEstado (3455). assistant.ps1: Set-UI (18570) rellena ese campo con lo que sobra cuando hay juego delante y lo vacía al salir; el listón no es un 85 escrito a mano sino el contador de CPU que ya se lee en 28438.

**Riesgo y guarda.** Dejar la cápsula tiesa y que parezca colgada justo cuando braya la mira. Guarda: el latido y el texto no se apagan nunca; solo mirada, blur, sombras y tic33, que son adorno. Y con la idea del fichero de visibilidad el cerebro ve si la cápsula sigue escribiendo, así que un apagado que la congele se nota.

> **El verificador corrigió el dato:** memoria\juegos.json suma 71.721 segundos (19,9 horas) repartidos en 9 dias distintos, no 72.176 s en 11 dias. Los 8 juegos y el reparto por dia si estan.

### 21. Las 34 veces que la cara se puso cauta por dos noes seguidos y el cerebro no se enteró ⬆ ∿

**Valor 8 · coste 6 · ángulo `capsula`**

**Qué.** La cápsula detecta sola que braya ha dicho 'no' dos veces en menos de un minuto y se pone cauta dos minutos. Esa señal es el aviso más temprano de que Nova está metiendo la pata en cadena, y muere en la cara: el cerebro, que es quien podría dejar de adivinar y empezar a preguntar, nunca se entera. Que esa racha salga por la misma puerta del diario y que el cerebro la use para subir el listón de confianza un rato.

**El dato.** 34 rachas de dos o más 'negar' en menos de 60 s en los 15 días de tmp\gestos.log (132 negaciones en total), incluidas una de 4 seguidos el 15/09 a las 11:44 y una de 3 el mismo día a las 15:30. Son 2,3 rachas al día de media. El cerebro no lee 'negar' para nada: los dos únicos sitios que abren gestos.log lo usan para el resumen semanal y para la página de estadísticas, los dos a posteriori.

**Dónde se comprobó.** nova_ui.cs:2411-2413 (negaciones y Humor('cauta',2)); assistant.ps1:3222 y 20550 (los dos únicos lectores de gestos.log, ambos para informes). Rachas contadas recorriendo tmp\gestos.log y agrupando los 'negar' separados por 60 s o menos: 34 grupos de 2 o más.

**Cómo se hace.** nova_ui.cs: en el bloque de 'negar' (2411), cuando la racha llega a 2 apuntar una línea marcada en el diario ('racha-no') además del gesto. assistant.ps1: leer esa marca en la vuelta del bucle que ya mira los ficheros de tmp y, mientras dure, subir el listón de confianza y mandar lo dudoso a preguntar en vez de a ejecutar, con el mismo mecanismo de escucha.confianzaMinima que ya existe.

**Riesgo y guarda.** Que Nova se vuelva preguntona justo cuando braya está harto, que es lo contrario de lo que hace falta. Guarda: la subida dura lo que dura el humor cauto de la cápsula (dos minutos), tiene plazo y se cae sola; y cuánto sube el listón se calcula con los aciertos y errores de esas rachas, no con un número puesto a dedo.

> **El verificador corrigió el dato:** El 'como' es inviable tal cual: escucha.confianzaMinima NO se puede subir en caliente. $EscuchaConf se lee una vez (17997) y se pasa como argumento 15 al lanzar wake_vosk.py (18379); cambiarlo obligaria a relanzar el worker y soltar el microfono, que rompe la regla 4 justo en el peor momento. La palanca que SI esta en el cerebro y SI se puede mover por vuelta del bucle es $RepasoDudosoUmbral (24196, input.repasoDudoso = -0.9) contra $script:dictadoConfianza (25721), que ya manda a repasar antes de hacer nada. Ademas la racha mas larga no es de 4 sino de 11 'negar' seguidos.

### 22. Un tercer oído de Vosk que solo sabe los nombres de lo que tienes instalado ⬆ ∿

**Valor 8 · coste 6 · ángulo `oido`**

**Qué.** El oído ya usa reconocedores de Vosk con lista cerrada para tres cosas (el nombre, el sí/no de confirmar y las palabras de corte). La idea es un cuarto, con la lista de apps, sitios y juegos instalados, corriendo sobre el mismo audio de la orden. No transcribe la frase: solo contesta 'aquí suena Steam'. Ese nombre viaja con el texto, y cuando la parte de arriba no reconoce el nombre que escribió Parakeet, no hace falta cargar Whisper: ya hay un candidato del propio oído.

**El dato.** 'sting' aparece 36 veces en el registro de uso frente a 113 de 'steam', y Sting no es nada que esté instalado en esa consola. No se arregla solo: comprobado el corrector fonético del asistente, 'sting' está a distancia 5 de 'steam' y el tope para una palabra de cinco letras es 2, así que lo RECHAZA (y 'ting' a 7, 'resting' a 9, también). El resultado está en el registro: 'Abre Sting' -> 'no es una orden que entienda; lo repasa Whisper' -> 'abre Steam', pagando el repaso entero por un nombre que la consola conoce de memoria.

**Dónde se comprobó.** wake_vosk.py:1751 (GRAMATICA), 1784 (GRAMATICA_SI_NO), 2555 (_reconocedor_corte), 2561 (_reconocedor_nombre); assistant.ps1:794-870 (Get-DistanciaFon y Find-Aproximado, tope k.Length*0.34*2). Conteo de palabras sobre registro.jsonl; distancias reimplementando Get-DistanciaFon en Python.

**Cómo se hace.** En wake_vosk.py, una función reconocedor_nombres() igual que _reconocedor_corte pero con la lista que el asistente ya le escribe en un fichero (apps + sitios + juegos instalados, los mismos que mete en el prompt del traductor). Se alimenta con los mismos bloques del dictado que ya se le pasan al juez (juez_oye) y, al cerrar, lo que saque se escribe junto a las candidatas de dictado-oidos.txt como 'nombres: steam'. En assistant.ps1, Find-Aproximado mira primero esa línea antes de pedir repaso.

**Riesgo y guarda.** Que la gramática cerrada alucine un nombre en cualquier ruido, que es exactamente el fallo del 20/09 con el nombre 'nova'. Dos guardas: el reconocedor lleva SetWords(True) y se exige confianza como en los otros tres, y su respuesta no ejecuta nada por sí sola, solo entra como candidata detrás de un verbo de abrir/cerrar, que es donde Find-Aproximado ya obliga a confirmar.

> **El verificador corrigió el dato:** Exacto por los dos lados. Contando palabras sobre registro.jsonl: 'sting' 36, 'steam' 113, 'ting' 2, 'resting' 1. Y reimplementando Get-DistanciaFon (assistant.ps1:820) con sus GruposFon: sting->steam = 5, ting->steam = 7, resting->steam = 9, con el tope de Find-Aproximado para una clave de 5 letras en max(2, floor(5*0,34)*2) = 2. Los tres se rechazan. Comprobado además en el log real: 25/09 01:25:37 'Cierre Sting, Paul' -> 'no es una orden que entienda; lo repasa canary' -> canary devuelve 'resting' -> acaba en 'no te pongo mas resting'.

### 23. El descarte que se arrepiente: el oído ya tiene la respuesta correcta 30 segundos después ⬆ ∿

**Valor 8 · coste 6 · ángulo `oido`**

**Qué.** El oído descarta llamadas por dos motivos (la ráfaga suena demasiado floja, o los altavoces están sonando y se exige más confianza) y no vuelve a pensar en ello. Pero si a los pocos segundos se abre una escucha buena -porque braya repitió, o porque se rindió y apretó el botón-, ese descarte estaba MAL, y Nova tiene las dos líneas escritas en su propio registro. La idea es que el oído se ponga la nota él mismo: cada descarte queda marcado como acertado o arrepentido según lo que pase en los 30 segundos siguientes, y con esa cuenta mueve sus propios umbrales en vez de esperar a que alguien los toque a mano.

**El dato.** En 17 días de registro: 148 descartes por 'confianza N < N (altavoces N > N: se exige mas)' y 113 por 'suena demasiado flojo para ser una llamada (rafaga N < N)'. Cruzados con las 1.204 aperturas de escucha buenas: 9 de los 148 (6 %) y 15 de los 113 (13 %) van seguidos de una escucha que sí se abrió en menos de 30 s. Son 24 veces en 17 días en que Nova le ignoró y él tuvo que insistir, y cada una está ya escrita en su propio registro sin que nadie la cuente.

**Dónde se comprobó.** wake_vosk.py:1713 (umbral_confianza), :303 (umbral_rafaga), :491 (umbral_actividad). Conteo: grep de las tres formas de '[escucha] descartado ...' en assistant.log + assistant.log.1 (148 / 113 / 102) y cruce de sus horas con las 1.204 líneas '[escucha] dictado: escuchando la orden'.

**Cómo se hace.** En wake_vosk.py, donde se escribe cada línea de descarte, guardar la hora y el motivo en una cola corta en RAM. Cuando se abre un dictado (por nombre o por botón), mirar esa cola: todo descarte de los últimos 30 s se apunta en un jsonl como 'arrepentido', y los que caducan sin eso, como 'acertado'. Con esa cuenta, umbral_confianza y umbral_rafaga bajan un escalón cuando los arrepentidos pasan de una fracción de los descartes, y suben si aparecen activaciones en seco; los pasos y los topes con la misma forma que ya tiene apuntar_rafaga_buena/techo_puerta.

**Riesgo y guarda.** Que baje el listón y vuelvan las activaciones solas de madrugada (el 20/09 grabó 70 s de una conversación privada). Se evita porque la señal es de dos direcciones: las activaciones en seco ya se apuntan con su desenlace en activaciones.jsonl y empujan el umbral hacia arriba; y hay tope duro por abajo, el RAFAGA_SUELO que ya existe.

> **El verificador corrigió el dato:** Recontado y emparejado yo: 113 descartes por 'suena demasiado flojo' (exacto) y 149 por 'confianza N < N (altavoces...)' (la idea decía 148). Cruzados con las 1.204 líneas 'dictado: escuchando la orden' (exacto), los arrepentidos salen 15 de 113 (13 %) y 9 de 149 (6 %): los dos porcentajes, clavados. LO QUE LA IDEA SE DEJA FUERA ES LO MEJOR: hay una TERCERA forma, 'confianza N < N' a secas, sin altavoces, con 110 descartes... y 43 de ellos (39 %) van seguidos de una escucha buena en menos de 30 s. Es el triple de arrepentimiento que las dos que sí cuenta. Si esto se implementa, que sea con las tres.

### 24. Aprender del segundo intento, cuando repites porque no te entendió ⬆ ∿

**Valor 8 · coste 6 · ángulo `aprender`**

**Qué.** Cuando dices algo, no pasa nada, y en menos de minuto y medio lo repites casi igual y ESTA VEZ sí sale una orden local, Nova se queda con el par: la primera forma queda apuntada como equivalente de la orden que acabó haciendo. Hoy los dos intentos son dos frases sueltas que no se conocen entre sí. Es la corrección más frecuente que hace braya y la única que no cuesta ni una palabra extra: simplemente repetirse.

**El dato.** De 714 dictados con texto en assistant.log + assistant.log.1 (14 días), 23 son una repetición de la anterior con parecido >= 0,75 en menos de 90 s. En 6 de esas 23 el primer intento murió (charla, nube o nada) y el segundo se resolvió en local: 'DINTA, CORREO' -> 'Dicta un correo'; 'Tiktam un correo en el bloc de notas' -> 'Dicta, un correo en el blog de notas'; 'O abrir al cincuenta por ciento' -> 'Tuvo el brillo al cincuenta por ciento'; 'Cierra Do' -> 'Cierra todo'; 'Si es Steam' -> 'Sierra Steam'; y una de juegos. Los retrasos reales fueron 12, 15, 17, 29, 30 y 42 s. Nova no aprendió NADA de ninguna de las seis.

**Dónde se comprobó.** assistant.log y assistant.log.1, extraídos con: grep -ohE "\[escucha\] (dictado|oido fino|ultimo recurso): '[^']*'" assistant.log assistant.log.1 y emparejados por SequenceMatcher >= 0,75 dentro de 90 s. El sitio donde falta el enganche: assistant.ps1:25894 (Set-UltimaOrden solo en el camino que SÍ ejecutó) y assistant.ps1:7167 (Add-Traduccion).

**Cómo se hace.** Guardar $script:dictadoAnterior = @{ texto; plano; cuando; llegoA } en Process-Texto, poniendo llegoA = 'nada' en las ramas de charla/descarte/nube y 'local' en la que ejecuta. En la rama LOCAL de Process-Texto (assistant.ps1:25894), antes de Set-UltimaOrden, comprobar si el dictado anterior tenía llegoA='nada', está dentro de la ventana y Get-Distancia sobre los dos planos da parecido suficiente; si sí, llamar a Add-Traduccion con la frase vieja y la orden nueva. Add-Traduccion ya trae puestos los tres frenos que hacen falta: modo invitado, destino destructivo y el tope por uso. La ventana y el parecido mínimo NO se escriben a mano: se calculan del p90 de los pares que la propia Nova vaya viendo, arrancando en 90 s y 0,75 porque es lo que dan los 23 pares medidos, y el comentario cita esa medición.

**Riesgo y guarda.** Aprender un par que no era una corrección sino dos órdenes parecidas seguidas ('Activa Bluetooth' + 'Activa el Bluetooth', que están en los 23). La guarda es que solo cuenta si el PRIMERO no ejecutó nada: si el primero funcionó, no había nada que corregir. Y el segundo tiene que resolverse en la capa local, no en la nube, que es donde entran las invenciones.

> **El verificador corrigió el dato:** Los pares de repeticion son 20, no 23. Contando SOLO lineas 'dictado' con texto, ventana <=90 s y SequenceMatcher >= 0,75 sobre los 714, salen 20 pares. Con las tres clases de linea juntas salen 106, pero ese numero esta inflado porque 'oido fino' y 'ultimo recurso' son RE-transcripciones del MISMO audio y se emparejan consigo mismas. El 23 no se reproduce por ningun camino. No cambia la idea: los 6 pares que la sostienen son los 6 que cita, con sus segundos exactos.

### 25. El motor que se descartó ya había oído la palabra buena ⬆ ∿

**Valor 10 · coste 7 · ángulo `aprender`**

**Qué.** Nova graba lo que oyó cada motor en cada orden real, incluido Vosk, que está escuchando todo el rato y no cuesta nada. Cuando la frase que gana no lleva a ningún sitio, lo que oyó Vosk se manda a la nube pero no se prueba NUNCA contra la capa local, que es gratis e instantánea. La idea es probarlo antes de pagar: si la frase entregada no empieza por un verbo y la de un motor descartado sí, se prueba esa en local.

**El dato.** En pruebas/audio/uso/registro.jsonl hay 560 órdenes reales con las tres transcripciones. En 25 de ellas un motor descartado traía una palabra de orden que la entregada no tenía, y en 17 la entregada NO empieza por verbo mientras Vosk SÍ. Son justo las que acabaron mal: 'Si es a los ajutos' cuando Vosk había oído 'cierra los ajustes' (ese es el caso que metió 'ajutos' en commands.json); 'Si es en navego' / Vosk 'cierra es navegador'; 'Seattle Navegador' / Vosk 'cierra el navegador'; 'Here at the glow' / Vosk 'abre teclado'; 'Haber team' / Vosk 'abre sting'; 'Tuvo el brillo al cincuenta por ciento' / Vosk 'sube el brillo al cincuenta porciento'.

**Dónde se comprobó.** pruebas/audio/uso/registro.jsonl (1037 líneas, 560 con campo 'entregado'), comparando 'entregado' contra 'vosk' con las apps y sitios de commands.json. Lo que ya existe y solo mira a la nube: assistant.ps1:23246 (los candidatos van únicamente en modo 'traducir') y wake_vosk.py:3807 (donde se escriben).

**Cómo se hace.** Get-OtrosOidos ya lee tmp/dictado-oidos.txt y está en assistant.ps1:18109. En Process-Texto, justo antes de mandar a la charla o a la nube, recorrer esas candidatas y pasarlas por Test-FastCommand; si alguna es una orden reconocible y la elegida no, se ejecuta ESA y se dice cuál se hizo. Y cuando braya corrige, se mira si la palabra corregida estaba en una candidata: eso apunta un voto a favor de ese motor en memoria/motores-aciertos.json, y el umbral para fiarse de una candidata sale de su tasa medida, no de un número escrito. Si la candidata no se reconoce, no pasa nada y sigue el camino de siempre.

**Riesgo y guarda.** Que una candidata mal oída se convierta en una orden que nadie pidió, que es la regla 1. Guardas: solo se prueba si la entregada NO resuelve a nada (si resuelve, manda ella), solo contra la capa local -nunca contra el agente, igual que ya se decide para el modo 'accion'-, y la acción sale por el camino de confirmación cuando es destructiva o cuando la voz no suena a braya.

### 26. Aprender sola con qué programa se abre cada juego ⬆ ∿

**Valor 9 · coste 7 · ángulo `juegos`**

**Qué.** Nova solo sabe que hay un juego delante si puede leer la ruta del programa. Los juegos con anticopia y los de la Store no la dejan leer, y entonces para ella no hay juego: ni cierra el micrófono al modo solo-botón, ni cuenta el tiempo, ni vigila los logros. La idea es que apunte sola qué programa estuvo delante mientras Steam movía la fecha de última partida de UN juego, y se guarde ese par en una tabla propia que crece sola y sustituye a la lista escrita a mano.

**El dato.** El 25/09, de 22:45 a 23:53, braya jugó a ELDEN RING NIGHTREIGN. Steam apunta LastPlayed 25/09 23:53; el cuaderno de la Ally apunta 4.038 s del programa 'nightreign' delante y con alguien tocando; juegos.json apunta 75 s ese día para ese juego. Es el 2 %. En esa hora ciega el registro tiene 45 descartes de la palabra 'nova' y 14 activaciones, con 'vuelve la palabra de activacion' puesto en vez del modo solo-botón. Y Roblox no aparece NI UNA vez en las 59 líneas de 'juego en primer plano' de 14 días, aunque el 20/09 entre 23:00 y 23:38 braya dictó 50 frases y en 7 dijo Roblox. La tabla de programas conocidos son 4 nombres a mano.

**Dónde se comprobó.** memoria\uso-ally.json ('nightreign': con=4038) contra memoria\juegos.json ('ELDEN RING NIGHTREIGN' 2026-09-25: 75); assistant.ps1:19003 (Get-JuegoEnPrimerPlano y $EXES_JUEGO, 4 entradas); appmanifest_2622380.acf LastPlayed=1790... -> 25/09 23:53; awk '$0>="2026-09-25 22:45:22" && $0<="2026-09-25 23:55"' assistant.log | grep -c "descartado 'nova'|ignorado: los altavoces" = 45

**Cómo se hace.** Nuevo memoria\juegos-exes.json. En el mismo tic de 10 s que ya paga la consulta cara (assistant.ps1:28243-28258) se guarda el nombre de proceso cuando Get-JuegoEnPrimerPlano devuelve vacío. Cada 60 s, Update-Juegos ya relee los appmanifest: si el LastPlayed de UN solo juego ha avanzado dentro de la ventana en la que ese proceso estuvo delante, se apunta proceso->juego. Get-JuegoEnPrimerPlano consulta esa tabla justo después de $EXES_JUEGO, antes del return $null.

**Riesgo y guarda.** Aprender como juego algo que no lo es (un instalador, el lanzador de EA, el navegador). Guardas: solo se aprende si el proceso estuvo delante más de 5 min seguidos Y en esa misma ventana movió su LastPlayed EXACTAMENTE un appmanifest; si mueven dos, no se aprende nada. Cada línea aprendida guarda la fecha y el número de veces que se confirmó, y se borra diciendo 'olvida que X es un juego'.

> **El verificador corrigió el dato:** 75/4038 = 1,86 %, no 2 %

### 27. Cambiaste de horario hace una semana y no se entero ∿

**Valor 8 · coste 7 · ángulo `tiempo`**

**Qué.** Nova mezcla los 14 dias con el mismo peso. Los datos dicen que braya cambio de horario a mitad de camino, y ella sigue promediando dos personas distintas. Que detecte la ruptura con su propia dispersion -sin umbral inventado-, recorte las ventanas al tramo nuevo y lo diga una sola vez.

**El dato.** Las 714 ordenes reales parten en dos semanas que no se parecen. Del 10 al 16/09: 343 ordenes -73 de manana, 215 de tarde, 54 de noche, 1 de madrugada- y la mediana del momento del dia a las 15:30. Del 18 al 25/09: 371 ordenes -4 de manana, 45 de tarde, 239 de noche, 83 de madrugada- y la mediana a las 22:58. La mediana se movio 448 minutos (7 h 28 min) en una semana, mientras la dispersion DENTRO de una misma semana (p25-p75 de habitos.fin) es de 160 minutos: el salto es 2,8 veces su propio ruido, o sea medible sin inventarse nada.

**Dónde se comprobó.** memoria/habitos.json (fin, charlaHoras) y el reparto por franja de las 714 lineas "[escucha] dictado: '...'" de assistant.log + assistant.log.1. Las ventanas de 14 dias: assistant.ps1:12939 (Get-HoraFinHabitual), 22607-22610 (Add-CharlaHora) y 11993 (Test-DatosRepartidos).

**Cómo se hace.** Una funcion que compare la mediana del momento del dia de los ultimos 3 dias con la de los 7-10 anteriores. Si la diferencia supera la dispersion interna de esos dias (p75-p25), se marca ruptura: las ventanas de 14 dias se recortan al tramo nuevo y Nova lo dice UNA vez, por la capsula. Los datos ya estan todos en habitos.json; no hace falta apuntar nada nuevo.

**Riesgo y guarda.** Cantar una ruptura por dos dias raros -un fin de semana, una tarde de pruebas- y tirar datos buenos. Guardas: el umbral es su propia dispersion y no un numero; hacen falta 3 dias seguidos del lado nuevo antes de mover nada; y se dice una sola vez por ruptura, sin voz si cae de noche. Importante: con 11 dias de fin NO hay patron por dia de la semana -uno o dos dias por cada dia-, asi que esto no debe intentar distinguir entre sabado y martes.

> **El verificador corrigió el dato:** El reparto por franja esta mal en las dos semanas, porque usa un corte tarde/noche distinto del que sale al recontar. Con manana 06-12, tarde 12-20, noche 20-24 y madrugada 00-06: del 10 al 16/09 son 73 manana, 244 tarde, 25 noche y 1 madrugada (dice 215 y 54); del 18 al 25/09 son 4 manana, 83 tarde, 201 noche y 83 madrugada (dice 45 y 239). Los totales, las dos medianas y los 448 minutos -que es lo que sostiene la idea- si salen clavados.

### 28. Llamarla dos veces seguidas es una prueba, y hoy no cuenta para nada ⬆ ∿

**Valor 8 · coste 8 · ángulo `ordenes-fallidas`**

**Qué.** Cuando Nova descarta el nombre por poca confianza, no guarda memoria de ello: la siguiente llamada se juzga desde cero. Pasaría a tener en cuenta la insistencia: si la MISMA palabra vuelve en los pocos segundos siguientes a un descarte por confianza, el listón baja un escalón aprendido de los huecos que ella misma ha medido, porque una persona que repite su nombre está llamando.

**El dato.** 372 descartes del nombre en el registro frente a 434 activaciones. 47 de esos descartes van seguidos de una activación buena en 20 segundos o menos, repartidos en 12 días: o sea, 47 veces braya la llamó, no le hizo caso y tuvo que repetir. En 15 de ellos la palabra era exactamente la misma, con huecos al listón de 0,00 / 0,03 / 0,04 / 0,04 / 0,06 / 0,13 / 0,16 / 0,16 / 0,16 / 0,22 / 0,22 / 0,28 / 0,30 / 0,31 / 0,48 y una espera de 1, 1, 2, 3, 5, 5, 5, 6, 7, 7, 7, 9, 12, 14 y 16 segundos. Cinco de los quince se quedaron a 0,06 o menos. Además, 148 de los 258 descartes por confianza son con el listón subido por los altavoces, que es justo cuando braya está jugando.

**Dónde se comprobó.** wake_vosk.py:1713 (umbral_confianza), wake_vosk.py:1760 (CONFIANZA_MIN = 0.55), wake_vosk.py:3931 (la línea de descarte). Conteo con un script sobre assistant.log y assistant.log.1 emparejando "descartado 'X': confianza A < B" con el siguiente "ACTIVADO por 'X'" a 20 s o menos.

**Cómo se hace.** En wake_vosk.py, junto a umbral_confianza, guardar el último descarte por confianza (palabra, confianza, tono y momento). En umbral_confianza, si la palabra que se está juzgando es la misma, han pasado menos segundos que la ventana medida y el descarte anterior fue POR CONFIANZA (no por ráfaga), restar el escalón aprendido. El escalón y la ventana se guardan como ganancia.txt y coberturas.txt, y se recalculan de los huecos y esperas que la propia Nova vaya apuntando.

**Riesgo y guarda.** Es el riesgo más serio de toda la lista: bajar el listón del nombre es exactamente cómo la madrugada del 20/09 Nova se despertó sola cinco veces y grabó una conversación privada. Guardas: no se toca NUNCA la guarda de ráfaga (que es la que paró aquello) ni el juez; el escalón solo se aplica a la segunda llamada, con la palabra idéntica, dentro de la ventana medida, y solo si el tono de las dos cae dentro del margen de braya; el listón rebajado no puede bajar del CONFIANZA_MIN de hoy más el escalón aprendido, con un suelo duro; y si tras una activación así el dictado sale vacío dos veces seguidas, el escalón se apaga solo.

> **El verificador corrigió el dato:** No son 47 descartes seguidos de activacion en 20 s repartidos en 12 dias: emparejando cada descarte por confianza con la PRIMERA activacion posterior a 20 s o menos salen 35, en 8 dias. Tambien: 373 descartes totales del nombre (no 372), 438 activaciones (no 434, el registro ha crecido) y 149 de los 258 descartes por confianza con el liston subido por los altavoces (no 148). Los 15 de palabra identica, que son los que sostienen la idea, salen identicos.

## B. Las de en medio (valor 6 y 7) — 61 ideas

### 29. Los avisos que solo se ven en la cápsula gastan turno y ensucian lo que Nova aprende

**Valor 6 · coste 1 · ángulo `iniciativa`**

**Qué.** Un aviso de nivel 'bajo' no se dice nunca: solo sale en la cápsula. Pero en Send-AvisoEntorno el apunte del tope por hora y el 'queda en observación' van ARRIBA del if que separa niveles, así que un aviso mudo ocupa una de las cuatro plazas de la hora y además se queda como el aviso al que Nova le mira la reacción. Resultado: Nova apunta 'no reaccionó' a cosas que no dijo, y esa cuenta es la que decide cada cuánto repetirlas.

**El dato.** 26 de los 96 avisos (27 %) son nivel 'bajo' y nunca sonaron: bateria-llena 21, cargador-pone 2, lo-que-no-dije 2, resumen-semana 1. Y de las ONCE muestras de reacción que hay guardadas hoy, CUATRO son de claves mudas: aviso-nada:bateria-llena, aviso-nada:cargador-pone, aviso-nada:lo-que-no-dije y aviso-sirvio:lo-que-no-dije. Además hay dos robos medidos: 22/09 08:00:25 oido-ruido (dicho) seguido 89 s después de bateria-llena (mudo), y 23/09 20:41:58 cargador-quita (dicho) seguido 60 s después de cargador-pone (mudo).

**Dónde se comprobó.** assistant.ps1:11031 ($script:entornoAvisos.Add) y 11039 ($script:avisoMirar), los dos ANTES del 'if ($nivel -eq alto) / elseif ($nivel -ne bajo)' de 11044-11058. Niveles contados con: grep -oE "ENTORNO \([^,]+, [a-z]+\)" sobre assistant.log + assistant.log.1. Muestras, en memoria\estadisticas.json (claves aviso-sirvio: y aviso-nada:).

**Cómo se hace.** Mover las dos líneas dentro de las dos ramas que sí hablan, que es exactamente lo que ya se hizo el 24/09 con Add-Estadistica 'aviso-dicho' y por el mismo motivo escrito en el comentario de esa línea. El Show-Popup y el Add-Estadistica 'aviso-entorno' se quedan donde están, que esos sí miden todo.

**Riesgo y guarda.** Que un aviso 'bajo' se vuelva ilimitado y la cápsula se llene de globos. No pasa: el freno por clave (avisos-vistos.json y su cadaMin) sigue delante de todo y es el que de verdad los espacia; lo que se quita es el presupuesto de VOZ, que ellos no gastan.

> **El verificador corrigió el dato:** 26 de 97 (26,8 %), no de 96. Y hoy hay 12 muestras de reaccion, no 11 (se sumo aviso-nada:hora-dormir el 26/09); las mudas siguen siendo 4.

### 30. Al reiniciarse, Nova olvida que llevas horas fuera y te habla igual

**Valor 6 · coste 1 · ángulo `iniciativa`**

**Qué.** Hoy un aviso solo se aparca para cuando vuelvas si Get-AusenciaMin dice que llevas 30 minutos sin dar señales. Pero esa función tiene un suelo: la ausencia nunca puede ser mayor que la edad del proceso, así que recién arrancada vale casi cero y Nova da por hecho que estás delante. Nova nace unas quince veces al día. La solución ya está escrita en el mismo fichero y no se usa aquí: Get-InactividadMin le pregunta a Windows cuánto hace que alguien tocó teclado, ratón o mando, viva Nova o no.

**El dato.** De los 19 avisos 'medio' aparcables desde que existe el aparcado (23/09), ONCE salieron con Nova arrancada hacía menos de 31 minutos, o sea con el aparcado estructuralmente imposible. En NUEVE de esos once braya llevaba más de una hora sin hablarle: 23/09 10:32 (602 min sin voz), 23/09 10:32 (602), 23/09 14:33 (843), 23/09 16:33 (963), 24/09 20:45 (289), 24/09 20:46 (289), 25/09 08:14 (405), 25/09 08:16 (406), 25/09 09:29 (479). Y 259 arranques en 17 días, 15 al día de media.

**Dónde se comprobó.** assistant.ps1:12763 (Get-AusenciaMin, el suelo es la primera línea: $ahora.AddMilliseconds(-$sw.ElapsedMilliseconds).AddSeconds(60)); assistant.ps1:12789 (Get-InactividadMin, que ya existe y solo se usa en dos sitios: 26201 y 28257); assistant.ps1:10513 (Test-AvisoAplazable). Medido cruzando 'ENTORNO (' con 'VoiceAssistant iniciado' y con las activaciones de voz en assistant.log + assistant.log.1.

**Cómo se hace.** En Test-AvisoAplazable, coger el MAYOR de Get-AusenciaMin y Get-InactividadMin. Get-InactividadMin ya devuelve -1 cuando no lo sabe, así que se ignora ese caso y se queda lo de siempre. Son tres líneas y ninguna función nueva.

**Riesgo y guarda.** Que Windows dé un ocio grande porque braya está viendo un vídeo sin tocar nada, y un aviso útil se aparque. La guarda es que aparcar no es tirar: la cola tiene plazo de 120 min y desde la idea 5 del 25/09 lo caducado se dice igual, tarde ('Se me pasó decirte esto a tiempo'). Y el -1 nunca calla a Nova.

### 31. Pasar los recuerdos viejos por la regla que ya existe, como ya se hace con el estilo

**Valor 7 · coste 2 · ángulo `charla`**

**Qué.** Al cargar el cerebro, cada recuerdo vuelve a pasar por el mismo filtro que decide si algo nuevo entra. Lo que hoy no se guardaria -lo que habla de Nova en vez de hablar de braya- deja de servir de contexto en el prompt de cada charla. Es exactamente lo que ya hace repasar_estilo con las nueve lineas de estilo, aplicado a los 121 recuerdos.

**El dato.** memoria\cerebro\cerebro.json tiene 121 recuerdos (111 episodios, 6 contado, 4 respuesta). 36 de ellos -el 30 %- llevan dentro 'nova' o 'asistente' y HOY los rechazaria guardar_texto, que tiene ese filtro desde el 19/09. Los 36 son del 15/09 (20) y del 18/09 (16); del 19/09 en adelante, cero. Repitiendo los 365 turnos reales de charla del registro contra ese mismo cerebro, se sirvieron 31 lineas de contexto y 3 salieron de esos 36, entre ellas 'Braya tiene algo descargandose en Steam pero Nova no puede verlo' y 'Nova no tiene acceso a la hora del sistema'. Nova se lee a si misma diciendo que no puede hacer cosas que si hace.

**Dónde se comprobó.** charla_memoria.py:92 (RE_SOBRE_NOVA), :511 (el filtro dentro de guardar_texto), :664 (repasar_estilo, que SI repasa lo viejo y lo explica), :207 (cargar, que no lo hace con los recuerdos). Conteo: script propio que carga cerebro.json y cuenta cm.RE_SOBRE_NOVA.search(cm.plano(r['respuesta']))

**Cómo se hace.** Un repasar_recuerdos() al lado de repasar_estilo, llamado desde cargar(). Reutiliza el filtro entero de guardar_texto (RE_SOBRE_NOVA + sensible + longitud minima) en vez de copiarlo, igual que repasar_estilo reutiliza _estilo, para que la regla viva en un solo sitio. Devuelve cuantos aparto y el worker lo dice al arrancar, como ya dice estilo_fuera.

**Riesgo y guarda.** Apartar de mas: hay recuerdos que nombran a Nova de pasada y son suyos ('braya llama Bull a Nova'). Guardas: no se borra nada, se marca 'rechazada' (estado que ya existe, deja de servirse de contexto y el repaso ya lo poda a los 60 dias, o sea reversible); y si el recuento sale por encima de la mitad del cerebro, no toca nada y avisa, porque eso significa que el filtro esta mal, no la memoria.

### 32. Lo que Whisper se inventa cuenta como acierto en el número de la meta ⬆

**Valor 7 · coste 2 · ángulo `contadores`**

**Qué.** 'recitado' es lo que Whisper rellena cuando casi no hay audio —repite su propia frase de ejemplo o enumera la biblioteca— y está metido en la lista de aciertos del número de la meta. Sacarlo de los aciertos y ponerlo en neutro: no es un acierto ni un fallo, es que no hubo orden.

**El dato.** $UsoBien incluye 'recitado', y el propio comentario de la tabla dice que esos casos llegan con el pico a 0,000 de mediana, o sea silencio. En pruebas\audio\uso\destinos.jsonl hay 7 'recitado' entre los 158 desenlaces juzgados de los últimos 14 días. Recalculando la meta con el mismo criterio de Get-MetaDias: 74,7 % con recitado dentro, 73,5 % sin él; el 21/09 pasa de 62 % a 57 %, el 20/09 de 79 % a 77 % y el 25/09 de 80 % a 79 %. No es mucho, pero es el número que braya mira para saber si va hacia el 100 %, y está inflado por lo único que Nova se inventa.

**Dónde se comprobó.** assistant.ps1:3602 ($UsoBien incluye 'recitado'), 2631 ($DestinosUso), 2644 ($DestinosSecos), 2648 (el comentario que lo deja a propósito como acierto), 3612 (Get-MetaDias); recuento de 'recitado' en pruebas/audio/uso/destinos.jsonl → 7

**Cómo se hace.** Mover 'recitado' de $UsoBien (3602) a $UsoNeutro. Con eso se arreglan a la vez Get-MetaDias, Get-ComoTeEntendi y la tabla del markdown, porque las tres leen esas mismas tres listas. Hay que tocar también $DestinosSecos y tools\probar-meta.ps1, que vigila que las listas no se separen.

**Riesgo y guarda.** Que el número baje de golpe y parezca que Nova ha empeorado justo el día del cambio. La guarda: la tabla se reconstruye entera desde el JSON en cada apunte, así que los 14 días se recalculan con el mismo criterio y la serie no se parte por la mitad; y Nova lo dice una vez al hacerlo.

> **El verificador corrigió el dato:** Dos correcciones al "como": $DestinosSecos (2644) NO se toca, 'recitado' tiene que seguir siendo seco porque esa lista decide si se reabre el microfono, no si fue acierto; y ademas de tools/probar-meta.ps1 hay que cambiar tools/analizar-uso.py:30 (BIEN), que es la lista paralela que el banco compara.

### 33. Que no se guarde como respuesta firme una pregunta que hizo ella

**Valor 6 · coste 2 · ángulo `charla`**

**Qué.** El cerebro guarda como conocimiento seguro lo que contesta la API. Cuando esa respuesta fue 'no te he entendido, completa', se queda guardada como si fuera un dato. Basta con no guardar una respuesta que es toda ella una peticion de aclaracion.

**El dato.** En todo el cerebro hay 3 respuestas firmes. Una es el recuerdo 117: pregunta '¿Como se llama', respuesta '¿Como se llama que? Completa que no me quedo claro.', guardada firme el 25/09 por venir de la API. Comprobado ejecutando el propio codigo: respuesta_directa('Como se llama') la devuelve tal cual, sin llamar a ningun modelo. Y en la repeticion de los 365 turnos reales es el recuerdo MAS servido de los 121: 4 de las 31 lineas de contexto, el 13 %. De las 247 respuestas de Nova del registro, 19 son peticiones de aclaracion.

**Dónde se comprobó.** charla_memoria.py:470 (guardar_respuesta: solo filtra caduca y sensible); memoria\cerebro\cerebro.json, recuerdo id 117; comprobacion con un script que llama a cm.Cerebro().respuesta_directa()

**Cómo se hace.** Dos lineas en guardar_respuesta: si la respuesta es corta (menos de 120 letras) y todo lo que contiene es pregunta -acaba en '?' y no hay ninguna frase afirmativa delante- o encaja con un patron corto de aclaracion ('no te entendi', 'a que te refieres', 'completa', 'no me quedo claro'), no se guarda. Y de paso, el recuerdo 117 pasa a 'rechazada'.

**Riesgo y guarda.** Tirar respuestas buenas que acaban ofreciendo algo ('...salio en 2017. ¿Quieres que te lo abra?'). Guarda: solo se descarta si la respuesta ENTERA es pregunta; en cuanto hay una afirmacion delante entra como hasta ahora. El banco puede fijar los dos casos: la de '¿Como se llama que?' fuera, la de '...salio en 2017. ¿Quieres...?' dentro.

> **El verificador corrigió el dato:** las peticiones de aclaracion no son 19: 23 con el patron de aclaracion, 16 contando solo las cortas que son pregunta entera

### 34. La lista que impide borrar la consola se salta con ri -Rec -For ∿

**Valor 7 · coste 3 · ángulo `privacidad`**

**Qué.** Nova auditaria sola su propia lista de prohibiciones en vez de darla por buena. El fichero que gobierna a opencode veta 36 patrones sobre una base de todo permitido, y los patrones casan texto literal: los alias y las abreviaturas de PowerShell pasan por al lado. Nova generaria la lista de equivalentes preguntandosela a la maquina y avisaria de cada veto que tenga un rodeo.

**El dato.** Son 36 reglas deny sobre "*": "allow". Comprobado en esta consola: Remove-Item tiene 6 alias (del, erase, rd, ri, rm, rmdir) y los dos vetos que lo cubren son '*Remove-Item*-Recurse*' y '*Remove-Item*-Force*', que exigen el nombre largo del cmdlet Y el nombre largo del parametro. Pero en Remove-Item el unico parametro que empieza por 'Rec' es Recurse y el unico que empieza por 'For' es Force, asi que PowerShell liga -Rec y -For sin ambiguedad: 'ri -Rec -For C:\...' no casa con NINGUNO de los 36. Igual Invoke-Expression, vetado, cuyo alias iex no lo esta; Stop-Service (alias spsv) y Remove-ItemProperty (alias rp), lo mismo. Y ningun patron menciona powershell, asi que desde bash 'powershell -c "..."' entra entero. opencode sigue vivo: 37 menciones en el registro de hoy y 669 en el anterior.

**Dónde se comprobó.** C:\Users\braya\.config\opencode\opencode.jsonc (el que manda, 36 deny, identico a la copia del repo opencode.permisos.json); Get-Alias -Definition Remove-Item -> del, erase, rd, ri, rm, rmdir; (Get-Command Remove-Item).Parameters.Keys filtrado por Rec* -> solo Recurse, por For* -> solo Force; TRASPASO.md:520; cat assistant.log | grep -ci opencode -> 37

**Cómo se hace.** Banco nuevo tools\probar-permisos-opencode.ps1 (ASCII puro, sin BOM, sin tildes ni enye). Lee el opencode.jsonc de verdad con ConvertFrom-Json, saca los patrones deny, y por cada uno que nombre un cmdlet de PowerShell pregunta a la maquina con Get-Alias -Definition y con (Get-Command X).Parameters.Keys cuales son los alias y que abreviaturas de parametro son inequivocas; genera las variantes y comprueba si alguna escapa a los 36 patrones. Falla listandolas. No toca el fichero: solo informa, porque cambiar los permisos del agente es decision de braya.

**Riesgo y guarda.** Que el banco de una lista larguisima de variantes y acabe siendo ruido que nadie lee. La guarda: se limita a los cmdlets que los propios patrones ya nombran (son 6) y da como mucho las tres variantes mas cortas de cada uno. Y no arregla nada solo: proponer el patron es util, pero ampliar los permisos de un agente con acceso total es exactamente lo que Nova no debe hacer sin que braya lo mire.

### 35. Que al cancelar un dictado a los 50 segundos mire si el oido sigue vivo ⬆ ∿

**Valor 7 · coste 3 · ángulo `errores`**

**Qué.** La red de seguridad de los 50 s cancela y pinta 'Sin respuesta del microfono', y ahi se acaba: no mira si el worker esta vivo ni si su estado se esta moviendo. Que en ese mismo punto compruebe HasExited y la fecha de escucha-estado.txt, y decida: si murio, relanzarlo YA en vez de esperar al siguiente paso de la vigilancia; si esta vivo y escribiendo, decir 'no me llego nada, repitemelo'.

**El dato.** 59 'dictado sin respuesta del worker; se cancela' en el registro, 35 de ellas en los ultimos 14 dias, con una racha de cinco el 21/09 entre las 00:29 y la 01:11. La vigilancia del worker es otra cosa distinta y mira cada 30 s. Y en ninguno de esos casos hay un 'worker de escucha murio' en el minuto siguiente: el worker estaba VIVO y mudo, asi que relanzarlo a ciegas tampoco era la respuesta; lo que faltaba era mirar.

**Dónde se comprobó.** assistant.ps1:27658-27665 (la rama de los 50 s) y assistant.ps1:27089-27095 (la vigilancia, cada 30000 ms). Contado con: grep 'dictado sin respuesta del worker' assistant.log.1 assistant.log | cut -c1-10 | sort | uniq -c, y el cruce con 'worker de escucha murio' por numero de linea.

**Cómo se hace.** En la rama de 27662, antes del Log: $vivo = $script:wakeProc -and -not $script:wakeProc.HasExited; $fresco = (Get-Item $RutaEstado).LastWriteTime -gt (Get-Date).AddSeconds(-$topeEstado). Tres caminos: muerto -> Initialize-Escucha ahi mismo; vivo pero el estado congelado -> relanzar y anotarlo; vivo y fresco -> Say corto pidiendo que lo repita. El mensaje del Log pasa a decir cual de los tres fue.

**Riesgo y guarda.** Relanzar el oido a mitad de algo y perder mas de lo que se gana. Por eso solo se relanza en los dos casos donde ya no hay nada que perder (muerto, o el estado congelado mas alla del tope). El tope sale de una medicion que ya esta hecha en este proyecto: la cadencia del estado es 15 s de mediana, 29 s el p99 y 72 s el maximo sobre n=2.665, asi que el liston es ese p99 y no un numero inventado.

> **El verificador corrigió el dato:** El 'en ninguno de esos casos hay un worker de escucha murio en el minuto siguiente' es casi cierto pero no exacto: cruzando las 59 cancelaciones con las 28 muertes por marca de tiempo, UNA tiene muerte dentro de los 60 s siguientes (y la misma dentro de 180 s). O sea 1 de 59, no 0. La conclusion aguanta: en el 98 % el worker estaba vivo y mudo.

### 36. Los 52 toques cortos del mando no hacen nada; que enseñen lo que Nova se calló

**Valor 7 · coste 3 · ángulo `capsula`**

**Qué.** El toque corto en el botón se mide y se apunta, y luego se tira: no pasa nada. El único vistazo que tiene la cápsula (hora y batería) solo se enciende si el RATÓN entra a 60 píxeles, cosa que en una consola de mano no ocurre. Que un toque corto que no encadene un segundo abra ese vistazo, y que la línea la arme Nova con lo que tiene aparcado sin decir.

**El dato.** 52 toques de entre 120 y 1.100 ms apuntados como 'toque-corto' en memoria\estadisticas.json (5+7+4+1+2+2+3+28 repartidos entre el 18 y el 25 de septiembre), y ninguno hace nada. El doble toque, que sí hace algo, abrió el panel rápido 6 veces en todo el registro. Mientras tanto la cola de avisos aparcados tiene ahora mismo 1 dentro, el registro tiene 450 líneas de 'N aviso(s) no cabian ahora' y 7 de 'caducado sin decirse'.

**Dónde se comprobó.** assistant.ps1:26226-26232 (Add-ToqueCorto: apunta y devuelve, no hace nada), 26966 (el bucle del mando donde se decide el doble toque); nova_ui.cs:1685 (Vistazo), 2800 (cerca = ratón a menos de 60 px y movido en 20 s), 2838 (única llamada a Vistazo). Contado con: grep -c 'PANEL RAPIDO: abierto' assistant.log assistant.log.1 (6); grep -c 'no cabian ahora' (450); grep -c 'caducado sin decirse' (7); tmp\avisos-esperando.json (1 entrada).

**Cómo se hace.** assistant.ps1: en el bloque del doble toque (26966), cuando pasan los 450 ms sin segundo toque, llamar a un Show-Vistazo nuevo que haga Set-UI 'reposo' con la hora, el porcentaje de batería y, si hay, el primer aviso de tmp\avisos-esperando.json. Se va sola en 2,5 s como el vistazo del ratón y no toca uiEstado ni bloquea el bucle.

**Riesgo y guarda.** Pisar el doble toque o aparecer encima de un dictado. Guarda: solo se dispara si no hay nada armado, pendiente ni ocupado (las mismas condiciones que ya pide Open-PanelRapido), es solo texto, y el segundo toque dentro de 450 ms sigue abriendo el panel encima sin problema.

### 37. Las 256 charlas ya medidas que se tiran, y los tres numeros a fuego que deberian salir de ellas ∿ ⚙

**Valor 7 · coste 3 · ángulo `autoconocimiento+red`**

**Qué.** Cada vez que Nova contesta hablando, charla_worker.py mide cuanto tardo la primera frase y se lo manda por el canal de info. Receive-Charla lo escribe en el registro y lo tira: assistant.ps1:22953 hace Log y continue, sin guardar nada. Hay voz-tiempos.json y nube-tiempos.json, pero no hay charla-tiempos.json y trabajo-tiempos.json no tiene ninguna clave de charla. Recoger ese numero donde ya llega y que de el salgan los tres umbrales de la espera que hoy estan escritos a mano: la muletilla de los 5 s (27213), la barra que arranca a los 2 s (27225) y la escala de 5/16 s de la barra (27229). De regalo, Nova puede contestar '¿vas mas lenta que ayer?' de su camino mas usado.

**El dato.** 256 lineas 'charla: primera frase en N s' entre assistant.log y assistant.log.1: p50 1,1 s · p75 1,6 s · p85 2,1 s (por el metodo del mas cercano; la primera cuenta decia 1,9) · p90 6,6 s (la primera cuenta decia 6,4) · p95 18,2 s · p99 22,2 s (la primera cuenta decia 21,7) · maximo 33,0 s. El 5.000 escrito a mano es 4,5 veces la mediana y cae por casualidad cerca del p89. La muletilla salto 34 veces de esas 256, el 13,3 % (una primera cuenta dijo 29 y 11,3 %). La charla es el camino mas usado de Nova: 364 en 14 dias frente a 271 activaciones. memoria\charla-tiempos.json no existe. memoria\trabajo-tiempos.json tiene cuatro claves medidas -api-plan, api-pregunta, api-traducir, claude-code-accion- y ninguna es de charla, con 141 trabajos detras. Y el 'charla'=5000 de $DURACION_ESPERADA es codigo muerto: en todo el registro hay 4 lineas BARRA y son esos mismos cuatro modos; jamas ha corrido un trabajo modo=charla.

**Dónde se comprobó.** charla_worker.py:550 (donde se mide y se emite); assistant.ps1:22953 (Receive-Charla, el 'info' que solo loguea y tira); assistant.ps1:27213 (el 5000 de la muletilla), 27225 (los 2000 de la barra) y 27229 (el $escalaE 5000.0/16000.0); assistant.ps1:22084 ($DURACION_ESPERADA con 'charla'=5000 y su propio comentario admitiendo que no hay ni una charla medida); assistant.ps1:22128-22210 (Add-TrabajoTiempo / Get-TrabajoPercentil / Get-DuracionEsperada, con suelo 0,5x, techo 2x y minimo de 10 muestras); assistant.ps1:2385-2448 (Add-VozTiempo / Get-VozTiempos / Get-VozPlazoMs); percentiles con grep -oE 'primera frase en [0-9.]+ s' | sort -n; ls memoria/ -> no hay charla-tiempos.json

**Cómo se hace.** El numero se recoge en el unico sitio donde ya llega: assistant.ps1:22953, en Receive-Charla, parseando el 'primera frase en N s' del info antes del Log. Guardarlo copiando el patron de Add-VozTiempo/Get-VozTiempos (2385-2448), que ya esta probado: lista con tope, escritura atomica UTF8 sin BOM, percentil por el metodo del mas cercano y el respaldo de lo escrito mientras haya menos de 20 muestras. Los tres umbrales pasan a Get-CharlaPercentil: 85 para la muletilla (27213), 40 para el arranque de la barra (27225) y 90 para la escala fria (27229), con tope duro por arriba en los 16 s que hoy estan escritos. IMPORTANTE, y esto ya se comprobo: el atajo de reusar Add-TrabajoTiempo 'api-charla' + Get-DuracionEsperada parece mas barato pero regala la mitad de la ganancia -su suelo de 0,5x solo deja bajar el 5.000 hasta 2.500, cuando el dato pide 1,6-2,1 s- y ademas la barra de la charla ni siquiera pasa por ahi: usa su propio par a mano en 27229. Si aun asi se toma ese camino, la funcion se llama Get-DuracionEsperada, no Get-TrabajoMs. Y en cualquiera de los dos casos, el 'charla'=5000 de $DURACION_ESPERADA (22084) es codigo muerto y se borra.

### 38. Decir el nombre de la carpeta en vez del nombre del juego ⬆ ∿

**Valor 7 · coste 3 · ángulo `juegos`**

**Qué.** Cuando Nova no encuentra el juego en la biblioteca, se queda con el nombre de la carpeta de instalación y lo usa para todo: lo dice en voz alta y lo usa como clave de su memoria. El dato bueno está en el propio fichero de Steam, en el campo installdir, que Nova ya lee y no usa NUNCA. Que se construya la tabla carpeta->nombre real, y que además corrija sola las claves ya guardadas mal.

**El dato.** El 20/09 a las 12:55:08 Nova dijo textualmente: 'Cerraste CatQuest_Purribean. Si quieres, dime donde te quedaste.' El juego se llama Cat Quest III. Y sus 100 segundos siguen guardados en juegos.json bajo la clave 'CatQuest_Purribean', así que 'cuánto he jugado a Cat Quest III' dará cero para siempre. De los 17 appmanifest instalados hoy, en 7 la carpeta NO se llama como el juego (AWayOut, UnravelTwo, 5dchesswithmultiversetimetravel, CatQuest_Purribean, BlackMythWukong, Skyrim Special Edition, wallpaper_engine). Y hay 5 carpetas en steamapps\common sin ningún appmanifest (ELDEN RING, Little Nightmares, Little Nightmares II, Little Nightmares III, REANIMAL): de ahí salen los tres juegos que Nova vio en primer plano y no le dejaron ni un segundo.

**Dónde se comprobó.** assistant.log.1 línea '2026-09-20 12:55:08 ENTORNO (juego-cierra, medio): Cerraste CatQuest_Purribean'; memoria\juegos.json clave 'CatQuest_Purribean'; grep -c '\.dir\b' assistant.ps1 = 0 (se lee en Get-JuegosSteam, assistant.ps1:1109, y no se usa en ninguna parte); 23 carpetas en steamapps\common contra 17 appmanifest

**Cómo se hace.** En Get-JuegosSteam, el campo 'dir' que ya se lee se mete en una tabla installdir(minúsculas)->nombre. En Get-JuegoEnPrimerPlano, antes de Find-Juego $carpeta, se mira esa tabla. Y una vez, al arrancar: si una clave de juegos.json coincide con un installdir cuyo juego tiene otro nombre, se fusionan los días bajo el nombre bueno y se deja apuntado en el log qué se movió.

**Riesgo y guarda.** Fusionar dos juegos distintos y perder días. Guarda: la fusión solo se hace si el nombre destino NO existe ya como clave, o si existe y no comparten ningún día; en cualquier otro caso se deja como está y se escribe una línea en el log. Se hace una sola vez y se guarda copia del fichero antes (Save-Corrupto ya hace eso).

> **El verificador corrigió el dato:** Son 6 carpetas sin appmanifest, no 5: las 5 de juegos (ELDEN RING, Little Nightmares, II, III, REANIMAL) mas 'Steam Controller Configs'. Y de los tres juegos vistos sin un segundo guardado (Little Nightmares II, Little Nightmares III, Outlast), Outlast NO tiene carpeta en common: no sale de ahi.

### 39. La noche empieza donde acaba la hora, no donde paras tu ∿

**Valor 7 · coste 3 · ángulo `tiempo`**

**Qué.** Get-NocheDesde ya saca tu hora de parar de tus propios datos, pero la trunca a la hora en punto: 00:24 se convierte en 'callate desde las 00:00'. Pasar el silencio nocturno a minutos y sumarle el mismo margen que ya usa el aviso de 'es tarde'.

**El dato.** La mediana de habitos.fin son 1.464 minutos, o sea las 00:24. floor(1464/60)%24 = 0, asi que el silencio de avisos arranca a las 00:00, VEINTICUATRO MINUTOS ANTES de tu hora habitual de parar. En las horas 00 y 01 hay 84 de las 714 ordenes reales (11,8 %), repartidas en 5 dias distintos: estas delante y ella esta muda para todo lo que no sea nivel 'noche'.

**Dónde se comprobó.** assistant.ps1:10137-10150 (Get-NocheDesde, la linea del %24) y 10287-10289 (esNocheE compara HORAS enteras); memoria/habitos.json (fin, 11 dias). Conteo por hora sobre las 714 lineas "[escucha] dictado: '...'" de assistant.log + assistant.log.1.

**Cómo se hace.** Get-NocheDesde devuelve minutos en vez de hora; el calculo de esNocheE en Test-AvisoEntorno compara minutos del dia; se le suma entorno.margenDormirMin (30), que es el margen que la casa ya usa para la misma pregunta. Hoy el silencio empezaria a las 00:54 en vez de a las 00:00.

**Riesgo y guarda.** Que hable mas tarde de noche. Guardas: no toca nocheHasta, no toca el nivel 'noche' (el unico que se salta el silencio) y sigue el tope de 4 avisos por hora. Y si Get-HoraFinHabitual no tiene 4 dias, devuelve -1 y todo queda como siempre.

### 40. Nova escribe sus propios fallos en el registro y no los lee nunca ⬆

**Valor 7 · coste 3 · ángulo `ordenes-fallidas`**

**Qué.** El oído anota "fallo en una vuelta del bucle: X" cuando una vuelta entera del bucle de escucha se cae por una excepción, y nadie mira esa línea: ni el asistente, ni un banco, ni un aviso. Nova pasaría a contar esos fallos por mensaje; si el mismo se repite, lo aparca como aviso de entorno y lo deja escrito en el diario para que la siguiente tanda lo vea. Lo primero que cazaría ya está ahí.

**El dato.** 4 líneas "fallo en una vuelta del bucle: name 'callado' is not defined" el 25/09 (21:33:23, 21:33:27, 21:33:28 y una más) y cero reacciones en todo el registro. Es un fallo de verdad: wake_vosk.py lee la variable 'callado' en la línea 3684 y solo la asigna en la 3729, así que en el primer dictado de cada worker la vuelta se cae. Se ve el precio en el mismo minuto: 21:33:19 braya llamó con 'nova nova nova nova' (confianza 1.00), tres vueltas se cayeron, y a las 21:33:29 el dictado acabó en "8 s sin oir nada; no hay nada que transcribir" y texto vacío. Grep de "fallo en una vuelta del bucle" en assistant.ps1 y en tools\*.ps1: 0 resultados.

**Dónde se comprobó.** wake_vosk.py:3684 frente a wake_vosk.py:3729 (uso antes de la asignación), wake_vosk.py:4168 (la línea que se anota), assistant.log 2026-09-25 21:33:19-21:33:29. Comando: grep -n "fallo en una vuelta del bucle" wake_vosk.py assistant.ps1

**Cómo se hace.** Dos piezas. (a) Arreglar el fallo: inicializar callado = False junto a las demás variables del dictado, antes del bucle interno (wake_vosk.py, alrededor de 3650). (b) La autonomía: en assistant.ps1, donde ya se leen las líneas del worker (la misma ruta que trae "WARN: el worker de escucha murio", 27094), reconocer el prefijo "fallo en una vuelta del bucle:" y llevar la cuenta por mensaje; al segundo igual, Send-AvisoEntorno con nivel medio y una línea en memoria\diario. Reutiliza el aparcado de avisos que ya existe, así que no habla mientras braya juega.

**Riesgo y guarda.** Que se convierta en una fuente de ruido si una excepción se repite mil veces. Guarda: el aviso va por el aparcador de entorno, que ya no repite la misma clave (la firma del 24/09), y el contador se lleva por mensaje, no por línea. No es adaptativa y no lo disimulo: el umbral de "cuántas veces" no sale de ninguna medición, solo hay un caso medido.

> **El verificador corrigió el dato:** Las 4 lineas no son todas del mismo minuto: tres el 25/09 a las 21:33:23, 21:33:27 y 21:33:28, y la cuarta a las 22:48:16. Y hay un error de mecanismo en el "como" que hay que corregir antes de implementarlo: assistant.ps1 NO lee ninguna linea del worker. anota() (wake_vosk.py:619) abre el MISMO fichero de log y escribe directo el prefijo [escucha]; el "WARN: el worker de escucha murio" de assistant.ps1:27094 lo escribe el propio assistant mirando HasExited, no leyendo una tuberia. El contador tiene que vivir dentro de wake_vosk.py (en el propio except de :4168) y cruzar al asistente como cruza ya el recorte: por un campo de escucha-estado.txt, que es el unico canal worker->asistente que existe.

### 41. Mirar todas las unidades, no solo la C:

**Valor 7 · coste 3 · ángulo `consola`**

**Qué.** Nova mide el disco con DriveInfo('C') en cuatro sitios del archivo y no mira nada mas. Al lado hay una microSD de 477 GB completamente vacia. Asi que avisa de que no queda sitio sin decir que hay casi medio terabyte a un centimetro, y repite el aviso hasta que alguien aparezca.

**El dato.** C: tiene 45,1 GB libres de 475,5. D: ("Rog SD", extraible) tiene 476,8 GB libres de 477: esta vacia. El registro trae 843 lineas "disco-poco" aparcadas por no haber nadie y 11 mas en el anterior, y una que caduco sin decirse. Esa noche DISCO bajo hasta 26,6 GB (25/09 22:10) oscilando entre 26,6 y 43. Los 17 juegos con manifiesto viven todos en la unidad que se ahoga; la vacia no es ni biblioteca de Steam.

**Dónde se comprobó.** assistant.ps1:16290, 17269, 17306 y 28567 (los cuatro DriveInfo('C') escritos a mano). Conteos: grep -h "ENTORNO aparcado" ... | sed 's/.*): //' | sort | uniq -c -> disco-poco 843 + 11; grep "DISCO:" assistant.log. Medicion: [System.IO.DriveInfo]::GetDrives() | Where IsReady.

**Cómo se hace.** Una Get-Unidades que devuelva las que estan IsReady con letra, tipo (fija o extraible) y gigas libres, y que el aviso de disco del bloque del minuto (28567) la use para redactar: "quedan 26 gigas en C, pero tienes 476 libres en la tarjeta". La respuesta hablada a "cuanto sitio queda" (3575 y 3738) pasa a decirlas todas. Mover un juego de biblioteca lo hace Steam, asi que eso se PROPONE y se abre la ventana; Nova no mueve nada ella.

**Riesgo y guarda.** Que una unidad extraible desaparezca a media frase o que una de red tarde. Solo se miran las que DriveInfo marca IsReady, y se etiqueta el tipo al hablar: "en la tarjeta, que puedes quitar" no es lo mismo que "en C". Y nunca proponer mover algo pesado a una extraible como si fuera fija, que es justo el lio del que sale la idea de los ocho juegos.

> **El verificador corrigió el dato:** Las lineas 3575 y 3738 NO son DriveInfo('C') escritas a mano: las dos leen la letra de la unidad de Steam del registro y solo caen en 'C' como respaldo. Los literales son cuatro: 16290, 17269, 17306 y 28567. Y "no mira nada mas" es falso: la linea 11441 YA hace [System.IO.DriveInfo]::GetDrives() | Where IsReady (es la idea 31, la que reindexa juegos al cambiar las unidades), y 15878-15886 recorre una lista. Conteo: 843 "disco-poco" en total entre los dos registros, no 843 + 11. Y el minimo de disco del registro no es 26,6 GB sino 5,2 GB; la oscilacion del 25/09 si sale clavada (26,6 a las 22:10, entre 26,6 y 43 esa noche). C: hoy: 44,9 GB libres de 475,5.

### 42. Una pregunta nace muda en las manos ⬆ ∿

**Valor 7 · coste 3 · ángulo `mando`**

**Qué.** Cuando Nova pregunta con un juego delante y el mando se ha movido hace poco, da un zumbido corto en el mismo momento de preguntar, no solo al contestar. Y mide si sirve: compara el tiempo de respuesta de las preguntas con zumbido y sin el, y si no baja, deja de zumbar y lo anota.

**El dato.** Hay 21 llamadas a Start-Vibracion en assistant.ps1 y ninguna cuando NACE la pregunta: el mando vibra al contestar (5 sitios), al abrir el panel, al abrir el selector, al oirte en juego y con los eventos 'hecho', 'logro' y 'aviso'. La pregunta solo escribe un texto en la capsula con la pista del mando. Con juego delante ese texto compite con la partida, y se nota: de las 12 preguntas que se pueden cronometrar en los dos logs, 3 murieron por plazo a los 7, 7 y 10 s, y en total 5 de 20 murieron asi. Y el canal esta disponible: 'mando: vibracion disponible' 130 veces.

**Dónde se comprobó.** grep -n 'Start-Vibracion' assistant.ps1 -> 21 sitios: 11500, 18619-18623, 18790, 20283, 23811, 24858, 26396, 26488, 26707, 26731, 26835, 26840, 26844, 26997, 27001, 27018. Donde nace la pregunta, assistant.ps1:27362 (Set-UI 'confirmando' con Get-PistaMando), no hay ninguna. Tiempos: awk emparejando 'CONFIRMAR: ... ->' con su desenlace en assistant.log.1 + assistant.log.

**Cómo se hace.** En assistant.ps1:27362, el mismo sitio donde ya se pinta la pista del mando, anadir Start-Vibracion con un patron corto y flojo si hay juego activo y Get-QuietudMando (idea 2) dice que el mando se ha movido hace poco. Apuntar en memoria\estadisticas.json el tiempo hasta la respuesta separando las preguntas con zumbido de las de sin, que es exactamente el dato que ya hace falta para la idea 3.

**Riesgo y guarda.** Un zumbido a destiempo en mitad de una partida puede costar una muerte en el juego, que es justo lo que se evitaba callandose. Guardas: patron corto y flojo, el mismo criterio del zumbido de 'te he oido en juego' que ya se eligio por eso; nunca para preguntas de nivel bajo; nunca si ya vibro algo en los ultimos 3 s; y si tras 10 preguntas con zumbido el tiempo medio de respuesta no ha bajado, se apaga solo y se escribe el motivo en el log.

> **El verificador corrigió el dato:** Son 20 llamadas a Start-Vibracion, no 21: el grep da 21 lineas porque una es la definicion de la funcion en assistant.ps1:20955. La lista de sitios que cita es correcta.

### 43. Parakeet se va a otro idioma y la guarda solo sabe inglés ⬆ ∿

**Valor 7 · coste 3 · ángulo `oido`**

**Qué.** Parakeet v3 elige idioma por frase y a veces elige mal. Nova ya lo vigila, pero con una lista de palabras inglesas escrita a mano: si la frase no lleva ninguna de esas palabras, la guarda no salta, aunque lo entregado sea neerlandés, portugués o directamente ruido. La idea es cambiar el juez: en vez de preguntar '¿hay palabras inglesas?', preguntar a Vosk, que es español y solo español y ya ha oído ese mismo audio. Si lo de Parakeet no tiene NI UNA palabra española y Vosk sí oyó español, el idioma estaba mal elegido y se repasa, venga de donde venga.

**El dato.** En las 560 órdenes del registro la guarda de inglés salta 20 veces. Pero hay otras 24 entregas SIN una sola palabra española ni una sola tilde que la guarda no pilla, y en 11 de ellas Vosk sí oyó palabras españolas. Son las peores del registro: 'Kyo' (Vosk: 'qué hora es'), 'An together temporary' (Vosk: 'conté que temporizador'), 'Maar die dog komen beheer' -neerlandés- (Vosk: 'marido a en vez de'), 'Coisa na main dana' (Vosk: 'franceses han aumentado'), 'Completion telephone' (Vosk: 'conté con podrían teléfono'). En el registro del asistente la guarda solo se disparó 7 veces en 17 días.

**Dónde se comprobó.** wake_vosk.py:1338 (PALABRAS_EN, lista escrita a mano) y wake_vosk.py:1347 (suena_ingles: exige una palabra de esa lista). Conteo: reimplementando suena_ingles sobre las 560 filas de pruebas\audio\uso\registro.jsonl. grep -c 'suena a ingles' assistant.log assistant.log.1 -> 7.

**Cómo se hace.** En wake_vosk.py, suena_ingles pasa a recibir también el texto de Vosk y se reescribe: sigue siendo False si hay una palabra de PALABRAS_ES o una tilde/eñe; pasa a ser True si no hay ninguna Y (hay palabra de PALABRAS_EN, como hoy) O (Vosk sacó al menos dos palabras y alguna está en PALABRAS_ES). repasar_si_ingles ya recibe los bloques y llama al oído fino: no cambia. El punto de llamada está sobre la línea 3760, donde texto_vosk ya existe.

**Riesgo y guarda.** Que mande a repasar órdenes buenas que solo llevan nombres propios ('Elden Ring', 'Hollow Knight'). Se evita con lo que ya hay: esos nombres casi siempre van detrás de un verbo español ('abre', 'pon') que está en PALABRAS_ES, y la guarda exige CERO palabras españolas. Y repasar no borra nada: si el repaso no saca texto, se entrega lo de Parakeet igual.

> **El verificador corrigió el dato:** El dato medido es EXACTO reimplementando suena_ingles sobre el campo 'entregado' de las 560 órdenes: salta 20 veces, hay otras 24 sin una sola palabra española ni tilde que no pilla, y en 11 de ellas Vosk sí oyó español. Los ejemplos citados están todos en el registro ('Coisa na main dana' / Vosk 'franceses han aumentado'; 'Maar die dog komen beheer' / Vosk 'marido a en vez de'; 'Completion telephone' / Vosk 'conté con podrían teléfono'). LO QUE ESTÁ MAL es el conteo del log: 'suena a ingles' aparece 14 veces (2 en assistant.log + 12 en assistant.log.1), no 7. La diferencia con las 20 es que la guarda solo llega a repasar si whisper no es None.

### 44. Los 1200 MB que Parakeet dice necesitar no los ha medido nadie ⬆ ∿

**Valor 6 · coste 3 · ángulo `ordenes-fallidas`**

**Qué.** Parakeet se niega a cargar si quedan menos de 1200 MB libres, un número escrito a mano. Nova pasaría a MEDIR lo que ocupa de verdad: RAM libre antes y después de cargarlo, guardar esa huella junto a ganancia.txt y coberturas.txt, y exigir esa huella más un colchón en vez del 1200. El mismo patrón que ya usa para el listón de cobertura.

**El dato.** 18 negativas en 5 días (18, 22, 23, 24 y 25/09), con estos MB libres: 294, 378, 382, 405, 449, 501, 587, 610, 667, 824, 919, 929, 976, 981, 984, 1110, 1174, 1174. Cinco de ellas tenían más de 900 MB y dos 1174, o sea a 26 MB del listón. El precio está medido: cuando Parakeet estaba, la transcripción tardó 1,68 s de mediana (549 medidas); en los 14 casos en que tras un "no lo cargo" contestó Whisper, la mediana fue 7,2 s y el peor 31,3 s. En el código no hay una sola llamada a ram_libre_mb() DESPUÉS de cargar el modelo, así que la huella real no está medida en ningún sitio.

**Dónde se comprobó.** wake_vosk.py:837 (RAM_MIN_PARAKEET = 1200.0), wake_vosk.py:1132-1138 (la negativa), wake_vosk.py:1150-1154 (la carga, sin medir después). Comando: cat assistant.log assistant.log.1 | grep -oE "parakeet: no lo cargo, solo quedan [0-9]+ MB"

**Cómo se hace.** En modelo_parakeet (wake_vosk.py:1129-1157), medir ram_libre_mb() justo antes del from_transducer y otra vez después de _parakeet_uso; la diferencia es la huella. Guardarla en un fichero de estado al lado de RUTA_GANANCIA/RUTA_COBERTURAS (misma función escribir(), mismo criterio de ligarlo al micro no hace falta aquí: es por modelo). RAM_MIN_PARAKEET pasa a ser un suelo de arranque y la guarda usa max(huella_medida * colchon, suelo_minimo). Lo mismo vale para RAM_MIN_PRECISO (900) con el oído fino.

**Riesgo y guarda.** Quedarse corto y que la carga tumbe la consola mientras braya juega, que es la regla 5. Guardas: el colchón se aplica sobre la huella MÁXIMA observada, no la media; si todavía no hay ninguna medida se usa el 1200 de hoy tal cual; y se sigue pidiendo un suelo absoluto por debajo del cual no se carga aunque la huella diga que cabe.

> **El verificador corrigió el dato:** La mediana de Parakeet que puedo reproducir es 1,8 s sobre 365 medidas, no 1,68 s sobre 549; con un patron mas ancho baja a 1,5 s sobre 164. El orden de magnitud y la conclusion no cambian. Matiz al "en ningun sitio": hacer_sitio_a_parakeet SI mide una huella -la del OIDO FINO al soltarlo, wake_vosk.py:1003-1005- pero esa rama no se ha ejecutado nunca (0 lineas de "soltado para hacerle sitio a Parakeet" en todo el registro) y de Parakeet sigue sin medirse nada.

### 45. Que tapar los secretos sea cosa del registro, no de quien lo llama ∿

**Valor 6 · coste 3 · ángulo `privacidad`**

**Qué.** Hoy cada sitio que escribe un error decide por su cuenta si tapa la clave. Nova pasaria a taparlos dentro de la propia funcion Log: al arrancar carga los secretos que de verdad tiene (los valores de memoria\claves.json y las variables ANTHROPIC_API_KEY y NOVA_CORREO_CLAVE) y sustituye cualquiera de ellos por *** en toda linea que vaya al registro, venga de donde venga. Si manana se anade otra clave al fichero, queda tapada sin tocar una sola linea de codigo.

**El dato.** En assistant.ps1 hay 489 llamadas a Log. De ellas, 137 vuelcan $_.Exception.Message tal cual, y SOLO 4 tapan la clave con -replace 'key=[^&\s]+'. Las tres URL de Steam que llevan la clave en la query (lineas 9812, 9838, 9934) pueden reventar en cualquier punto y salir por cualquiera de los otros 133. Nova guarda 3 secretos: la clave de Steam en memoria\claves.json, ANTHROPIC_API_KEY (7 referencias) y NOVA_CORREO_CLAVE (5 referencias).

**Dónde se comprobó.** assistant.ps1:9770 y 9920 y 28171-28172 (los 4 que tapan); funcion Log sin ningun filtro; conteo: grep -c "Log.*Exception.Message" assistant.ps1 -> 137; ese mismo grep | grep -c replace -> 4; grep -cE "^\s*(try \{ )?Log " assistant.ps1 -> 489

**Cómo se hace.** Tocar solo la funcion Log de assistant.ps1 (esta justo antes de ConvertTo-CmdArg). Anadir $script:secretos, una lista cargada una vez al arrancar desde Get-Content memoria\claves.json mas [Environment]::GetEnvironmentVariable de las dos variables, filtrando los valores de menos de 8 caracteres. Dentro de Log, antes del Out-File, un foreach que haga $msg = $msg.Replace($s,'***'). Banco nuevo tools\probar-log-sin-secretos.ps1 (sin tildes ni enye) que meta una clave falsa, provoque un Log con ella dentro y compruebe que no aparece en el fichero.

**Riesgo y guarda.** Que el reemplazo cueste tiempo en el bucle: son 3 cadenas por linea y Log ya hace Out-File, que es mil veces mas caro; aun asi la lista se carga UNA vez y se cachea, nunca se lee el disco dentro de Log. El otro riesgo es tapar de mas y dejar un error ilegible: por eso solo se sustituyen valores literales de 8 caracteres o mas, nunca patrones.

> **El verificador corrigió el dato:** NOVA_CORREO_CLAVE tiene 1 referencia, no 5 (grep -c sobre assistant.ps1, wake_vosk.py, charla_*.py y nova_ui.cs: 1 sola, en assistant.ps1). ANTHROPIC_API_KEY son 6 en assistant.ps1 + 1 en charla_worker.py = 7 en total, asi que el 7 solo vale si se cuentan todos los ficheros. El resto (489 / 137 / 4) sale clavado.

### 46. Sabe a que hora paras, pero no cuanto te mueves de esa hora ∿

**Valor 6 · coste 3 · ángulo `tiempo`**

**Qué.** De habitos.fin solo se saca la mediana. La dispersion esta en los mismos datos y nadie la calcula, asi que tres avisos distintos le suman un 30 escrito a mano. Calcular la banda (p25, mediana, p75) una vez y que la usen el recordatorio de cargar y el aviso de 'es tarde'.

**El dato.** Las 11 noches de habitos.fin acaban a las 17:24, 21:59, 22:38, 23:38, 23:50, 00:24, 00:28, 01:00, 01:18, 01:18 y 01:29: las diez de verdad ocupan 3 h 30 min. Test-RecordarCarga solo dispara en los 30 minutos anteriores a la mediana (23:54-00:24) y solo 1 de las 11 noches cae ahi; con la banda p25-p75 (23:38-01:18) caerian 8 de 11. Y el aviso de 'es tarde' usa el mismo 30: salta pasadas las 00:54, o sea 4 de las 11 noches. Mas de una de cada tres no es una ruptura de rutina, es tu rutina; con su propia dispersion (p75 menos mediana = 54 min) saltaria 1 de 11.

**Dónde se comprobó.** assistant.ps1:12937-12963 (Get-HoraFinHabitual y Test-RecordarCarga, el '$finH - 30') y 11643-11661 (Get-AvisoHoraDormir, entorno.margenDormirMin = 30); memoria/habitos.json (fin).

**Cómo se hace.** Get-BandaFinHabitual devuelve (p25, mediana, p75) del mismo array que ya construye Get-HoraFinHabitual. Test-RecordarCarga dispara dentro de [p25, p75]; Get-AvisoHoraDormir usa (p75 - mediana) como margen en vez del 30.

**Riesgo y guarda.** Con pocos dias la banda sale rara. Guarda: la que ya existe -menos de 4 dias, Get-HoraFinHabitual devuelve -1 y los dos avisos se comportan como hoy-. Y ojo, el recordatorio de cargar sigue sin tener casi sentido para el: de los 7 episodios sin cargador del registro, 6 vuelven al enchufe en 20 minutos o menos.

> **El verificador corrigió el dato:** El p25 de habitos.fin es 22:38 (1.358 min), no 23:38: con la indexacion de la casa, Floor(11*0,25) = 2 -> 1.358, y con Floor((11-1)*0,25) sale lo mismo. La banda correcta es [22:38, 01:18] y con ella caen exactamente las 8 de 11 que dice, asi que la cuenta se salva y la etiqueta no.

### 47. El juego que se abre y se muere a los diez segundos ∿

**Valor 6 · coste 3 · ángulo `juegos`**

**Qué.** Cuando un juego arranca y el proceso muere en segundos, Nova hoy lo trata como una partida normal: dice 'Modo juego', baja el brillo, lo restaura y se calla. Que cuente los intentos seguidos y, al tercero, lo diga ella: 'NIGHTREIGN lleva tres intentos muriéndose al arrancar', y ofrezca lo que braya acabó haciendo a mano.

**El dato.** El 25/09, entre 21:34 y 22:45, ELDEN RING NIGHTREIGN entró en primer plano SEIS veces y las seis murió el proceso a los 11, 21, 11, 11, 11 y 10 segundos; las seis dejaron la línea 'cerrado con 0 min de partida (minimo 3): sin aviso'. ELDEN RING hizo lo mismo a las 21:32 (21 s). Nova dijo 'Modo juego' seis veces y no notó nada. A las 21:58, en medio de esos seis intentos, braya dictó: 'cierra el Steam completamente, mata el proceso... es necesario para un reinicio completo'. Es decir, lo diagnosticó él.

**Dónde se comprobó.** grep 'cerrado con' assistant.log -> seis líneas de NIGHTREIGN el 25/09 (21:34:42, 22:00:02, 22:09:27, 22:26:41, 22:29:03, 22:45:32); assistant.ps1:20758 (Test-SalidaJuego) y 19081 ($JuegoMinimoPartida = 3)

**Cómo se hace.** En Test-SalidaJuego, donde hoy solo se escribe 'sin aviso' y se sale, se apunta en memoria el par (juego, hora) de cada salida con el proceso muerto y menos de $corto segundos de partida. Tres en menos de 30 minutos -> Send-AvisoEntorno de nivel medio con la frase y la oferta de cerrar los procesos de Steam (ya existe el cierre de procesos). El contador se borra en cuanto una partida del mismo juego pasa del mínimo.

**Riesgo y guarda.** Confundir 'lo cerré yo aposta' con 'se murió'. Guarda: el umbral de 'corto' no es un número escrito, sale de las partidas reales de ESE juego en juegos.json (la mediana de sus sentadas); mientras no haya al menos 3 sentadas suyas guardadas, se usa la mediana de todos sus juegos y se dice en el log de dónde salió. Y nunca se cierra nada sin decirlo: la oferta se confirma.

### 48. Los instrumentos mudos: 38 de sus 88 contadores no han contado nada

**Valor 6 · coste 3 · ángulo `autoconocimiento`**

**Qué.** Nova instala medidores y no comprueba que midan. Uno de ellos lleva dos días puesto sin haber tomado una sola muestra, y la respuesta a '¿cuánto tardas en oírme?' devuelve 'aún no lo he medido bastantes veces' para siempre. Una comprobación diaria que recorra las claves de Add-Estadistica que hay en el código y los almacenes memoria\*-tiempos.json, y avise de los que siguen a cero desde el commit que los introdujo.

**El dato.** 88 claves de Add-Estadistica escritas en assistant.ps1; sólo 50 tienen algún dato en los 14 días de estadisticas.json. 38 están mudas. El caso claro es 'arranque-oido': entró el 24/09 a las 02:20 (commit 3be3ac6), ha habido unos 14 arranques desde entonces, y no tiene ni un dato en estadisticas.json, ni una línea 'ARRANQUE: el oido tardo' en los dos registros (de las 40 líneas ARRANQUE que hay, las 40 son la otra), ni existe el fichero memoria\arranque-oido.json. Lo mismo memoria\guia-tiempos.json, que tampoco existe. Y 'REVISION PROPIA' no aparece ni una vez en las 58.554 líneas de registro, con estadisticas.json['decisiones'] vacío y 'auto-ajuste' a cero en 14 días.

**Dónde se comprobó.** grep -ohE "Add-Estadistica '[a-z0-9:-]+'" assistant.ps1 | sort -u -> 88; cruce con las claves de memoria\estadisticas.json -> 38 mudas; git log -S 'function Add-ArranqueOido' -> 2026-09-24 02:20 3be3ac6; assistant.ps1:12738-12751 (Add-ArranqueOido) y 12708 (la frase que nunca podrá decir)

**Cómo se hace.** Un banco en tools/ que saque las claves del fuente con un regex y las cruce con memoria\estadisticas.json, más la lista de los ficheros *-tiempos.json que el código nombra. Lo que salga mudo y sea de hace más de N días según git log -S, se escribe en el registro y se cuenta. Se puede enganchar en el mismo sitio de la revisión diaria (assistant.ps1:11420).

**Riesgo y guarda.** Que señale contadores que están mudos porque lo que cuentan es raro de verdad ('regla-peligrosa', 'nube-invento'). La guarda: no se acusa a nada de estar roto; se lista 'sin muestras desde que se puso' con su fecha de git, y los que son raros a propósito se marcan una vez en una lista que se lee del propio fuente, no de un número escrito aparte.

> **El verificador corrigió el dato:** Los dos registros tienen 58.644 líneas, no 58.554; y en el JSON hay 66 claves con datos, de las cuales 50 vienen de Add-Estadistica y 16 por otra vía (aviso-nada:*, repaso:*, accion, plan, pregunta, traducir)

### 49. Lo que bajas y no abres ⬆ ∿

**Valor 6 · coste 3 · ángulo `juegos`**

**Qué.** Que Nova cruce dos cosas que ya tiene delante y no junta nunca: lo que se descargó cada día y la fecha de última partida de Steam. Si pasan varios días y un juego recién bajado sigue sin abrirse ni una vez, lo dice una sola vez, con lo que ocupa. Y cuando el disco apriete, que en vez de decir 'pregúntame qué ocupa más' diga ya cuál sobra.

**El dato.** De los 16 juegos instalados hoy, OCHO no se han abierto nunca (LastPlayed a cero): Marvel's Spider-Man Remastered 65,96 GB, Aniimo 29,28, Skyrim Special Edition 14,99, Biped 4,24, Jackbox Party Pack 6 2,22, Lucid Cats 1,18, Jackbox Megapicker 0,39 y 5D Chess 0,01. Son 118,3 GB. Cuatro de ellos se bajaron ANTEAYER Y AYER: de las 7 descargas del 24 y 25/09, cuatro (Aniimo, Jackbox Party Pack 6, Biped, Lucid Cats, 36,9 GB) siguen sin abrirse. Mientras tanto, el disco C llegó a 6,8 GB libres el 23/09 a las 22:55 y a 7,8 GB el 25/09 a las 10:56; ahora quedan 45.

**Dónde se comprobó.** memoria\descargas.json (7 nombres los días 2026-09-24 y 2026-09-25) contra los appmanifest de C:\Program Files (x86)\Steam\steamapps (LastPlayed=0 en 8 de 16) y SizeOnDisk; grep 'DISCO:' assistant.log assistant.log.1 (15 líneas, mínimo 6.8 GB); assistant.ps1:28565-28610 (el vigilante del disco) y 15923 (la pregunta 'ocupa', que solo responde de un juego por su nombre)

**Cómo se hace.** Get-JuegosSteam ya trae 'ultimo' y 'tamano'. Se añade una función que devuelve los instalados con ultimo=0 ordenados por tamaño. Dos salidas: (a) en el aviso de disco que ya existe, en vez de 'pregúntame qué ocupa más', el nombre y los gigas del mayor sin abrir; (b) una vez, cuando un juego de descargas.json cumple los días sin abrirse, una frase de nivel bajo. Nunca se desinstala nada solo.

**Riesgo y guarda.** Sonar a regañina, que es justo lo que braya no quiere. Guardas: una sola frase por juego y para siempre (se apunta que ya se dijo); nada de listas; y los días que hay que esperar no son un número a mano, salen de cuánto tarda él de verdad en estrenar un juego (Unravel Two y A Way Out se bajaron el 24/09 y se jugaron el mismo día, así que hoy ese número sería 1 día y con tan pocas muestras conviene decirlo en el log).

> **El verificador corrigió el dato:** 'DISCO:' son 50 lineas (35+15), no 15. El minimo real es 5,2 GB (2026-09-24 23:38:15), no 6,8; el 6,8 del 2026-09-23 22:55:35 existe pero no es el minimo. Y 'que ocupa mas' YA EXISTE (assistant.ps1:5500 -> Get-FacturaDisco): contesta con caches, no con juegos.

### 50. Se muere la mitad de las veces y sólo recuerda la última ∿

**Valor 6 · coste 3 · ángulo `autoconocimiento`**

**Qué.** Nova ya detecta UNA caída al arrancar (Get-CaidaAnterior) y lo cuenta. Lo que no tiene es la tasa: no sabe que se muere mal la mitad de las veces, ni que ayer relanzó el oído cuatro veces. Cuenta en estadísticas 'arranque', 'cierre-limpio', 'relanza:oido' y 'relanza:capsula' -ninguna de las cuatro existe hoy entre sus 88 claves- y cuando la cuenta de hoy pasa de su propia mediana de 14 días lo dice una vez: 'llevo cuatro arranques esta tarde, algo me está matando'.

**El dato.** Desde que existe la línea 'VoiceAssistant cerrado' (18/09 17:06, commit 79ca9a0) hay 72 arranques y sólo 36 cierres limpios: exactamente la mitad de las sesiones acaban sin salir por la puerta. Y los workers: 28 'el worker de escucha murió; relanzando' y 18 'la interfaz murió' en el registro, 46 relanzamientos en 12 días, con un pico de 9 en un solo día (22/09). Ninguno de esos 46 se cuenta en ningún sitio ni se le dice a braya. Las sesiones además son cortísimas: mediana 9,6 min y 93 de 255 duran menos de 5 minutos.

**Dónde se comprobó.** Conteo sobre assistant.log.1 + assistant.log con corte en '2026-09-18 17:06:00' -> iniciados 72, cerrados 36; grep -E 'worker de escucha murio|la interfaz murio' | awk fecha | uniq -c -> 46 en 12 días; assistant.ps1:27094 y 28692 (donde se escriben esos WARN sin contarlos)

**Cómo se hace.** Un Add-Estadistica en los cuatro sitios que ya existen: assistant.ps1:21154 (arranque), 21162 (cierre limpio), 27094 (relanza el oído) y 28692 (relanza la cápsula). La comparación con la mediana de 14 días reutiliza Get-Estadisticas y Test-DatosRepartidos, que ya se usan en Test-RevisionPropia. El aviso sale por Send-AvisoEntorno con nivel 'medio', como el de la nube.

**Riesgo y guarda.** Que en una tarde de desarrollo -que es cuando más reinicios hay- Nova se ponga pesada avisando de sus propios reinicios. La guarda: el listón es su propia mediana de 14 días, no un número, y el aviso se aparca con el mismo criterio de presencia que ya usa ('no hay nadie desde hace 30 min'), que ya aparca 4.140 avisos en el registro.

### 51. Que la precarga de la charla pese las horas en vez de contarlas ∿

**Valor 6 · coste 3 · ángulo `ficheros`**

**Qué.** Nova precarga el modelo de charla si a esta hora habéis hablado tres días de los últimos catorce. Pero lo que guarda es un 1 por día y hora, no cuántas veces: a las nueve de la mañana, con un solo dictado suelto, cuenta igual que a las nueve de la noche con veinte. Y el tres está escrito a mano.

**El dato.** habitos.json -> charlaHoras: 31 claves, TODAS con valor 1, repartidas en 15 horas distintas de 11 días. Solo 4 horas llegan al listón de 3 días: la 01 (3 días), la 21 (5), la 22 (4) y la 23 (4). Las otras 11 horas (09, 10, 11, 13, 14, 15, 17, 18, 19, 20 y 00) se quedan fuera con 1 o 2 días, aunque algunas tengan mucho más uso que otras.

**Dónde se comprobó.** assistant.ps1:22607-22608 (Add-CharlaHora: si ya existe la clave se sale, y si no la pone a 1); assistant.ps1:22655 (Test-PrecargaCharla exige >= 3 días a esa hora en 14); assistant.ps1:11659 (Get-AvisoHoraDormir usa la misma cuenta); reparto por horas calculado en python sobre memoria\habitos.json

**Cómo se hace.** En Add-CharlaHora, sumar en vez de poner un 1 (el fichero ya guarda enteros, así que no rompe nada: un fichero viejo se lee como «una vez»). Y que el listón de Test-PrecargaCharla salga del propio reparto —las horas que están por encima de la mediana de charla— en vez del 3 escrito. Get-AvisoHoraDormir seguiría contando días distintos, que es lo que necesita, con un Where sobre las mismas claves.

**Riesgo y guarda.** Que una noche larga de charla a una hora rara deje esa hora precargando para siempre y le quite RAM al juego. Guardas: las dos que ya existen siguen mandando por encima de esto (no se precarga con un juego delante, ni con menos de 3.000 MB libres), y la ventana sigue siendo de 14 días, así que una noche suelta se cae sola.

### 52. El cuaderno de la Ally se queda a medias en cada apagada ∿

**Valor 6 · coste 3 · ángulo `continuidad`**

**Qué.** Add-UsoAlly acumula segundos en RAM y solo los baja al disco cuando llega a 300. Save-UsoAlly se llama desde UN solo sitio en todo el fichero, y ni el cierre limpio ni una caida vuelcan lo pendiente: cada apagada tira hasta 5 minutos de uso ya contados. Igual el tiempo de juego cuando Nova muere con el juego delante, porque el unico volcado lo hace Exit-Juego y esa funcion no llega a correr.

**El dato.** 'Save-UsoAlly' sale 2 veces en assistant.ps1: la definicion y una sola llamada, dentro de 'if ($sumaU -ge 300)'. 259 arranques en 17 dias (246 en assistant.log.1 + 13 en assistant.log), 15,2 al dia; los ultimos 7 dias, 67 arranques (9,6 al dia). El 25/09, con 10 arranques, uso-ally.json guarda 4.038 s de nightreign en todo el dia. Y de las 23 sesiones con un juego delante desde el 18/09, 8 murieron sin cerrar, o sea sin pasar por Exit-Juego.

**Dónde se comprobó.** assistant.ps1:13301 (unica llamada), 13304 (definicion), 20671 (Save-TiempoJuego en Exit-Juego), 21160 (el manejador PowerShell.Exiting, que hoy solo escribe una linea). Conteo: grep -c 'VoiceAssistant iniciado' assistant.log.1 assistant.log

**Cómo se hace.** Meter Save-UsoAlly y Save-TiempoJuego dentro del Register-EngineEvent PowerShell.Exiting de assistant.ps1:21160, y anadir en Watch-Entorno un volcado por reloj (no por cantidad) cuyo plazo salga de la vida mediana medida de sus sesiones, no de un numero escrito a mano.

**Riesgo y guarda.** Escribir mas a menudo son mas escrituras en disco, justo lo que el comentario de Add-UsoAlly dice que braya no quiere. La guarda es doble: Save-UsoAlly ya sale sin hacer nada si Count -eq 0, y el plazo del volcado nunca baja de 60 s por mucho que la mediana de sesion caiga.

> **El verificador corrigió el dato:** 9 de 23 sesiones con juego murieron sin cerrar (no 8); Save-TiempoJuego tiene 3 llamadas, no solo la de Exit-Juego; 35 de las 71 sesiones desde el 18/09 (49 %) murieron sin cierre

### 53. "No era eso" tiene que llegar también a lo que se metió en commands.json ⬆

**Valor 6 · coste 3 · ángulo `aprender`**

**Qué.** Nova puede escribir un alias nuevo en commands.json, pero no tiene ninguna forma de quitarlo: ni por voz ni cuando la corriges. Es el único sitio donde lo que aprende es irreversible. Por eso la pregunta de alias está apagada, porque un alias malo se queda para siempre. Darle marcha atrás es lo que permitiría volver a encenderla con datos.

**El dato.** Add-Alias-Comando escribe en commands.json y no hay ninguna función que quite un alias: hay Remove-Perfil para los modos (assistant.ps1:6982) y Remove-JuegoOido para los sonidos de juegos, pero nada para apps ni sitios. Invoke-AprenderDelError (assistant.ps1:7262) solo sabe deshacer dos cosas, traducciones y recetas. El daño ya ocurrió: la madrugada del 22/09 entró 'ajutos': '' entre los sitios y hubo que sacarlo a mano. La pregunta de alias lleva apagada desde entonces con el marcador en 5 preguntas, 0 aprendidas útiles y 1 sí que envenenó el vocabulario.

**Dónde se comprobó.** assistant.ps1:6996 (Add-Alias-Comando), assistant.ps1:7262 (Invoke-AprenderDelError, solo traducción y receta), assistant.ps1:6982 (Remove-Perfil, que sí existe para los modos). grep -n cmdsPath assistant.ps1: solo tres funciones escriben ese fichero y solo una de ellas -la de los modos- tiene su borrado. El comentario que cuenta el incidente está en assistant.ps1:7004 y siguientes.

**Cómo se hace.** Escribir Remove-Alias-Comando con la misma forma que Remove-Perfil: leer commands.json, quitar la propiedad de apps o sitios, Write-Atomico y recargar $script:cmds. Marcar en $script:ultimoAlias lo que se acabe de aprender, y que Invoke-AprenderDelError lo deshaga igual que deshace una traducción, con la misma guarda de $soloSiDudosa. Añadir el camino hablado 'olvida que X es Y' para los alias, que hoy solo existe para los datos. Y apuntar los alias aprendidos por Nova aparte de los que puso braya, porque lo enseñado a mano no se toca.

**Riesgo y guarda.** Borrar por error un alias que braya escribió a mano en commands.json. Se evita con la marca de origen: solo se puede quitar automáticamente lo que escribió Nova; lo de braya solo sale si lo pide él hablando, y entonces se le dice cuál se quitó.

### 54. Lo que Nova hace por su cuenta se ve igual que lo que le pediste

**Valor 6 · coste 3 · ángulo `capsula`**

**Qué.** Cuando Nova baja el brillo porque lo decidió ella, la cápsula enciende exactamente el mismo icono que cuando braya se lo pide: no hay forma de distinguir 'esto me lo mandaste' de 'esto lo hago yo'. Con la regla 1 de la casa eso es justo lo que hay que poder ver de un vistazo, porque es lo único que da margen a decir que no antes de que pase. Una marca pequeña en la cápsula para lo que sale de ella sola.

**El dato.** 96 avisos por su cuenta generados en 10 días ('aviso-entorno' en memoria\estadisticas.json: 6+1+3+7+9+6+31+14+5+14), de los que solo 11 llegaron a decirse ('aviso-dicho': 3 y 8). Más 5 autosordinas decididas sola y 84 arranques anunciando el presupuesto de 'hasta 4 por hora'. Y en los 33 campos que la cápsula lee de ui-estado.json no hay ninguno que diga de quién fue la idea: hay 'remoto' (lo lleva la IA) y 'origen' (memoria o api), pero ninguno para 'esto no me lo has pedido'.

**Dónde se comprobó.** memoria\estadisticas.json (claves aviso-entorno y aviso-dicho por día); assistant.ps1:11033 y 11060 (los dos contadores), 18677 y 14599 (Set-UIHaciendo, que pinta el icono igual venga de donde venga), 18570-18597 (la lista entera de campos del JSON, sin ninguno de autoría); nova_ui.cs:1204 (GlifoDeAccion, el mismo glifo para las dos procedencias). Contado con: grep -c 'avisos por mi cuenta' assistant.log assistant.log.1 (84).

**Cómo se hace.** assistant.ps1: un campo 'mia' en el JSON de Set-UI, que Invoke-Acciones (14599) pone a 1 cuando la acción viene de una regla, de un aviso de entorno o de una decisión propia, y a 0 cuando viene de una orden. nova_ui.cs: al pintar el glifo en PintarHaciendo (1230) añadirle un aro fino del color de 'pensando' cuando mia=1; nada de texto ni de sonido, solo la marca.

**Riesgo y guarda.** Convertir la cápsula en un semáforo lleno de adornos que ya no se lee de un vistazo. Guarda: es una sola marca sobre un glifo que ya existe, no una forma nueva ni una línea de texto; y si el campo no llega (una versión vieja del cerebro) el glifo se pinta como hoy.

> **El verificador corrigió el dato:** Hoy son 97 aviso-entorno (no 96) y 12 aviso-dicho (no 11): falta contar el 2026-09-26, con 1 de cada. Son 33 campos leidos, correcto, pero Set-UI escribe 35. Y la funcion de la linea 14599 se llama Invoke-FastCommand: 'Invoke-Acciones' NO EXISTE en assistant.ps1. Ojo ademas a que Set-UIHaciendo (18677) manda el glifo ya resuelto desde $GlifosAccion del lado PowerShell, no la clave, asi que GlifoDeAccion de nova_ui.cs:1204 no es por donde entra el dato.

### 55. Cuando Nova se disculpa, que lo apunte ella misma

**Valor 6 · coste 3 · ángulo `aprender`**

**Qué.** La charla admite que se equivocó bastante más a menudo de lo que braya dice 'no era eso'. Esa admisión la escribe Nova, no braya, así que no hay riesgo de confundir una charla que empieza por 'no' con una corrección. Cada vez que la respuesta lleve un 'tienes razón', 'me equivoqué' o 'metí la pata', ese turno queda apuntado como sospecha de fallo con la frase que lo provocó.

**El dato.** De 542 respuestas de la charla en 14 días, 33 son una admisión clara de error ('Tienes razón, me equivoqué al interpretar lo que dijiste', 'Claro, tienes razón. Disculpa el error, confundí Bluetooth con wifi', 'Tienes razón, me pasé. No debería haber dicho que lo cerré si nunca estuvo abierto'). Otras 6 son disculpas por una limitación, no por un error, y se quedan fuera. Hoy el fichero de sospechas, pruebas/audio/uso/senales-fallo.jsonl, tiene 33 líneas en total y solo tres clases: ruido 14, no-orden-a-charla 14, descarte 5. Añadir esta señal dobla el corpus de sospechas de golpe.

**Dónde se comprobó.** grep 'charla dice:' sobre assistant.log y assistant.log.1 (542 líneas), filtrado por el patrón de admisión. wc -l pruebas/audio/uso/senales-fallo.jsonl = 33 y conteo por 'senal'. El sitio: assistant.ps1 donde se registra 'charla dice' y la función que escribe las señales (la hermana de Write-FalloUso, assistant.ps1:2769 y siguientes).

**Cómo se hace.** En el manejador del evento de la charla, antes de Say, pasar la respuesta por un patrón corto ('tienes (toda la )?razon|me equivoque|me confundi|mi mal|mi error|meti la pata|no deberia haber') y, si casa, escribir una línea {senal:'me-disculpe', peso:'medio', detalle:<la frase tuya de ese turno>} en senales-fallo.jsonl. No toca destinos.jsonl -no es la señal humana- ni consume el id, exactamente por la razón que ya explica el comentario de Write-FalloUso. Y tools/analizar-uso.py suma la clase nueva sin cambios en las tres listas que vigila probar-meta.ps1.

**Riesgo y guarda.** Que la charla sea educada y se disculpe sin haber fallado ('perdón, man, fui muy largo'). Por eso va al fichero de SOSPECHAS y no al de verdades, con peso medio, y por eso el patrón excluye las disculpas por limitación ('lo siento, no tengo información sobre...'), que son 6 de las 39 y no son un error.

> **El verificador corrigió el dato:** Las admisiones son 31, no 33. Pasando su propio patron ('tienes (toda la )?razon|me equivoque|me confundi|mi mal|mi error|meti la pata|no deberia haber') por las 542 respuestas salen 31, y de esas 31 alguna no es admision de error ('Bueno, tecnicamente si es verdad, pero tienes razon en que es mas complicado', 'Tienes razon, deberia haberlo hecho'). Sigue casi doblando las 33 senales que hay hoy, que es el argumento.

### 56. Cargar el oído mientras Nova habla, que es cuando el micrófono no sirve para nada ∿

**Valor 6 · coste 3 · ángulo `oido`**

**Qué.** Mientras Nova habla o dicta, el oído se pone en pausa y tira el audio sin mirarlo. Son ratos largos y frecuentes, y ahí dentro no hace absolutamente nada. Justo después de esos ratos es cuando braya contesta, y es donde se paga la carga de Parakeet. La idea es usar la pausa: en cuanto empieza, si Parakeet (o Canary) no está cargado y hay RAM, se carga ahí, con el micrófono ya ignorado. Cuando ella termina de hablar, el modelo está dentro y la respuesta de braya no paga nada.

**El dato.** 1.200 pausas emparejadas en 17 días: 5 s de mediana, 685 de 5 s o más, 285 de 10 s o más, 161 minutos en total con el micrófono ignorado. Y 700 de las 1.211 pausas (57 %) terminan con un dictado empezando en menos de 5 segundos: contesta enseguida. Mientras tanto, de las 72 cargas de Parakeet del registro, 30 (el 42 %) ocurren en los 20 s SIGUIENTES al fin de una pausa, o sea en el peor momento posible. Cargar cuesta 4,75 s de mediana (p90 11,7, máximo 27,4; 483 s en total), y la mediana cabe entera dentro de la pausa mediana.

**Dónde se comprobó.** wake_vosk.py:3288-3306 (la rama de PAUSA del bucle, que solo llama a vigilar_corte y tira los datos), :961 (precargar_parakeet, que hoy solo corre al arrancar), :1111 (modelo_parakeet). Conteo: emparejando '[escucha] pausa: el asistente habla o dicta' con '[escucha] pausa: fin' en assistant.log + assistant.log.1, y cruzando con '[escucha] dictado: escuchando la orden' y 'parakeet cargado en N s'.

**Cómo se hace.** En wake_vosk.py, dentro del if de PAUSA, cuando se acaba de entrar en pausa (el mismo sitio donde hoy se escribe 'pausa: el asistente habla o dicta'), lanzar el hilo que ya existe: precargar_parakeet() en un threading.Thread daemon, con el candado de carga que ya tiene modelo_parakeet. Las guardas de RAM (RAM_MIN_PARAKEET) y de juego (jugando()) ya están dentro y no se tocan. Nada más: el resto de la rama de pausa sigue igual.

**Riesgo y guarda.** Que se ponga a cargar en una pausa cortísima y la carga siga corriendo cuando braya ya está hablando, robándole CPU al reconocimiento. Se evita esperando a que la pausa lleve un par de segundos abierta (que es menos que la mediana de 5 s) y porque el hilo ya es daemon y el candado impide dos cargas a la vez; y con un juego delante no se hace, como ya ordena jugando().

> **El verificador corrigió el dato:** Emparejando 'pausa: el asistente habla o dicta' con 'pausa: fin' en los dos logs salen 1.221 pausas (la idea dice 1.200/1.211), mediana 5 s (exacto), 695 de 5 s o más (dice 685), 294 de 10 s o más (dice 285) y 57 % terminan con un dictado en menos de 5 segundos (exacto, 701 de 1.221). Las cargas, clavadas: 72 con tiempo apuntado, mediana 4,75 s, p90 11,7, máximo 27,4, 484 s en total (dice 483). EL ÚNICO NÚMERO FUERA: el total de micrófono ignorado son 198 minutos, no 161.

### 57. Su IP sale en claro cada dia para que le digan lo que Nova ya sabe ∿

**Valor 6 · coste 3 · ángulo `privacidad`**

**Qué.** Nova dejaria de preguntar donde esta cuando la respuesta lleva dias siendo la misma. Hoy pide la ubicacion a un tercero por HTTP sin cifrar una vez al dia. Pasaria a contar cuantos dias seguidos ha dado la misma ciudad y, a partir de ahi, escribir lat/lon en config.json y no volver a preguntar salvo que el clima falle o cambie la red.

**El dato.** De los 8 destinos externos que hay en el codigo, ip-api.com es el UNICO que va por http:// sin cifrar, sin contar 127.0.0.1: los otros siete (api.anthropic.com, api.steampowered.com, store.steampowered.com, api.open-meteo.com) van todos por https. En esa peticion viaja la IP publica de braya en claro. Y la respuesta no cambia: memoria\ubicacion.json lleva Tampa, y Tampa es lo unico que ha salido en los registros (12 menciones, ninguna otra ciudad). El cache es por dia ('dia': '2026-09-25'), asi que se repite a diario, y clima.lat y clima.lon estan a null en config.json, que es justo lo que el comentario del codigo dice que lo evitaria.

**Dónde se comprobó.** assistant.ps1:19128 -> Invoke-RestMethod -Uri 'http://ip-api.com/json/?fields=lat,lon,city'; assistant.ps1:19096-19097 el comentario que ya avisa ('eso manda la IP a un tercero; con clima.lat/lon en config.json no hace falta'); grep de https?:// sobre los cuatro ficheros -> un solo http externo; cat memoria/ubicacion.json -> Tampa, dia 2026-09-25; config.json clima.lat=null, clima.lon=null

**Cómo se hace.** Dos cosas en Update-Clima (assistant.ps1, sobre la 19128). Primera, cambiar la URL a https://ip-api.com, que el servicio lo acepta. Segunda, anadir a memoria\ubicacion.json un contador 'iguales' que suba cada dia que la ciudad coincida con la guardada y se ponga a cero si cambia; cuando pase de la racha que se haya medido, escribir lat y lon en config.json con Set-Cfg y dejar de llamar. Si open-meteo empieza a fallar o la lat/lon guardada da error, se borra el contador y se vuelve a preguntar.

**Riesgo y guarda.** Que braya se lleve la consola de viaje y Nova le de el clima de Tampa. La guarda: la racha se rompe sola en cuanto open-meteo devuelva algo incoherente, y ademas se reevalua si cambia el SSID o el adaptador de red, que es lo que de verdad indica que se ha movido. Y el paso a https puede fallar si el plan gratuito no lo sirve: si la llamada https falla, se usa la ubicacion guardada, nunca se vuelve a http.

### 58. Que el recuerdo guarde tambien la frase con la que tu lo dijiste

**Valor 6 · coste 3 · ángulo `charla`**

**Qué.** Los recuerdos los escribe la API en tercera persona y con sus palabras; braya habla con las suyas, en trozos. Por eso la busqueda por palabras casi nunca los encuentra. La frase original de braya ya esta en la mano cuando el recuerdo se guarda: basta con dejarla dentro como variante, que es lo que ya se hace con las respuestas y no con los episodios.

**El dato.** Los 111 episodios dicen cosas como 'Braya tiene una funda para una consola y esta teniendo problemas con ella', mientras braya dijo 'no cierra bien, no coincide con la consola'. Medido el mejor parecido por palabras de cada episodio contra CUALQUIERA de las 365 frases reales: mediana 0,175, y el liston para servir de contexto es 0,30. Solo 20 de los 111 pueden llegar a pasarlo alguna vez; 43 no llegan ni a 0,15. Resultado: 97 de los 121 recuerdos no aparecen ni una sola vez en los 365 turnos, y en total se sirvieron 31 lineas de contexto. El techo que se ganaria esta medido: 95 de las 365 frases -el 26 %- se parecen a 0,30 o mas a algo que el mismo ya habia dicho antes.

**Dónde se comprobó.** charla_memoria.py:585 (donde YA se hace para las respuestas: self._variante(r, job['pregunta'])), :607-609 (donde NO se hace al guardar 'contado' y 'episodio'), :447 (_variante), :293 (_formas, que ya puntua todas las variantes), :318 (_vale_de_contexto y el 0,30). Medicion: script que calcula Cerebro._lex de cada episodio contra las 365 frases

**Cómo se hace.** guardar_texto acepta un argumento opcional 'dicho' y, cuando aplicar_revision guarda un 'contado' o un 'episodio', le pasa job['pregunta'] -la frase de braya, que ya esta ahi mismo- como variante. buscar() y _formas ya puntuan todas las formas, asi que no se toca la busqueda ni se llama a ningun modelo: cuesta unos bytes por recuerdo.

**Riesgo y guarda.** Ensuciar la busqueda: una frase suya corta y generica ('no, no, no') como variante haria saltar ese recuerdo con cualquier cosa. Guardas: solo se guarda si la frase tiene al menos 3 palabras de contenido; _variante ya tiene tope de variantes; y _frecuencias ya castiga las palabras que salen en muchos recuerdos, asi que una variante generica pesa poco por si sola.

> **El verificador corrigió el dato:** el techo no es 95 frases (26 %): repitiendo la cuenta salen 109 de 365 (30 %) sin filtro, y 61 (17 %) si se exige la guarda de 3 palabras de contenido que la propia idea pone

### 59. La voz de lo que ya esta escrito y esperando su turno

**Valor 6 · coste 3 · ángulo `red`**

**Qué.** Los avisos del entorno se quedan aparcados con el texto YA escrito esperando un buen momento, y cuando por fin se dicen pagan casi un segundo de red delante de braya. Que Nova mande ese texto al worker de voz preparada mientras espera. De paso, el aviso se puede decir con la voz buena aunque cuando le toque no haya red.

**El dato.** Send-PrepVoz tiene UN solo sitio que la llama, la charla. En el registro hay 97 avisos del entorno dichos y 4.140 vueltas de "ENTORNO aparcado" (1.649 oido-ruido, 1.648 gmail-lleno, 843 disco-poco): el texto se conoce con minutos u horas de antelacion. Y sintetizar al momento cuesta 974 ms de media (348 medidas: p50 902, p90 1.245, p99 2.264, maximo 3.636) frente a 5 ms si ya esta hecha (358 medidas). Ahora mismo tmp\avisos-esperando.json tiene un aviso escrito con vencimiento a las 03:00.

**Dónde se comprobó.** assistant.ps1:17789 (Send-PrepVoz) y assistant.ps1:23010 (su unico llamador); tmp/avisos-esperando.json; grep -c "voz: frase sintetizada al momento" = 348 y "voz: frase ya preparada" = 358 sobre assistant.log y assistant.log.1; grep -cE "ENTORNO \(" = 97.

**Cómo se hace.** Una llamada a Send-PrepVoz dentro de Send-AvisoEntorno cuando el aviso se aparca, y otra en el parte de la manana. El worker de preparacion ya existe, ya corre en prioridad por debajo de lo normal y ya comparte la misma cache por md5, asi que no hay nada que inventar.

**Riesgo y guarda.** Gastar red en avisos que luego caducan sin decirse (el registro tiene 2 "ENTORNO caducado sin decirse" por clave). Guardas: solo se prepara el aviso que YA paso el filtro de "va a decirse", uno por vuelta como maximo, y si hay un juego delante no se prepara nada.

> **El verificador corrigió el dato:** p99 de sintetizar: 2.792 ms, no 2.264. 'ENTORNO aparcado' 4.141, no 4.140. 'caducado sin decirse' son 7, no 2, o sea que el riesgo de gastar voz en avisos que luego no se dicen es algo mayor del que ella misma se pone; aun asi, 7 frente a 97 dichos.

### 60. Dejar de reintentar a ciegas el resumen del diario ∿

**Valor 7 · coste 4 · ángulo `ficheros`**

**Qué.** Cuando Ollama no está levantado, Nova intenta resumir el día pasado una vez por minuto, para siempre, y solo lo apunta en el registro. Nadie se entera, el día sin resumir se queda esperando y el diario se queda sin nota.

**El dato.** 46 líneas idénticas «charla: diario: no pude resumir lo del 2026-09-25 ([WinError 10061] ... conexión denegada)» entre las 00:07:45 y las 00:56:46 del 26/09: una cada 65 segundos, 49 minutos seguidos. memoria\cerebro\charla-2026-09-25.jsonl sigue ahí con 5.830 bytes sin resumir. Y en memoria\diario faltan las notas del 13/09 (que tuvo 4 charlas), del 24 y del 25/09.

**Dónde se comprobó.** `grep -c 'no pude resumir' assistant.log` -> 46; primera 2026-09-26 00:07:45, última 2026-09-26 00:56:46; charla_worker.py:1055-1057 (el except solo hace salida('info') y return False); charla_worker.py:737 (el bucle lo reintenta a cada pasada con 20 min sin charla); cruce de memoria\estadisticas.json (dias) con `ls memoria/diario`

**Cómo se hace.** En resumir_dias_pasados, un contador de fallos seguidos por día guardado junto al jsonl. A partir del tercero, esperar el doble cada vez hasta un tope. Y un plazo, que es la regla 2 de la casa: pasadas X horas sin poder resumir, escribir en el diario las frases en bruto recortadas (que es lo que hay) en vez de perder el día, y decirlo UNA vez por el canal de avisos, no 46 veces en el log.

**Riesgo y guarda.** Que el diario se llene de frases sueltas sin resumir y pierda gracia. Guarda: el volcado en bruto va marcado («sin resumir todavía») y, cuando Ollama vuelva, el día marcado se vuelve a intentar y sustituye lo crudo por las viñetas.

> **El verificador corrigió el dato:** 71 lineas 'no pude resumir', no 46: de las 00:07:45 a la 01:28:21 del 26/09, una cada ~65 s, y seguia creciendo al medir. En el diario faltan ademas el 19/09 (los que faltan son 13, 19, 24 y 25/09, no solo 13, 24 y 25).

### 61. El unico numero del tiempo que ajusta sola no pasa por la guarda de la casa ⬆ ∿

**Valor 7 · coste 4 · ángulo `tiempo`**

**Qué.** Get-VentanaSeguimiento decide cuanto tiempo deja el microfono abierto despues de cada respuesta con el p80 de las ultimas 30 muestras de habitos.ritmo. Esa lista son 30 numeros pelados, SIN fecha, y una sola tarde la llena entera. Guardar la fecha con cada muestra, poner tope por dia y exigir la misma guarda de datos repartidos que usan las demas decisiones propias.

**El dato.** habitos.ritmo tiene 30 valores y ninguna fecha; Add-RitmoSeguimiento hace FIFO a 30. El registro tiene 738 lineas con 'seguimiento' en 13 dias, y 86 de ellas son SOLO del 25/09: una tarde produce de sobra para reescribir la memoria completa. Nova aplica Test-DatosRepartidos (>=3 dias distintos y ningun dia por encima del 70 % del total) en 6 decisiones propias -nube, oido fino, turbo, repaso- y aqui en ninguna.

**Dónde se comprobó.** assistant.ps1:22578-22597 (Add-RitmoSeguimiento y Get-VentanaSeguimiento) y 11990 (Test-DatosRepartidos, llamada desde 12060, 12157, 12186, 12227 y 12319); memoria/habitos.json (ritmo). Conteo: grep -h seguimiento assistant.log assistant.log.1 | cut -c1-10 | sort | uniq -c.

**Cómo se hace.** ritmo pasa de lista de numeros a lista de {s, f} (el lector viejo se sigue aceptando, como ya se hace con juegos.json). Tope de 10 muestras por dia. Get-VentanaSeguimiento exige 3 dias distintos antes de salir de SeguimientoMs/ConversacionEsperaMs.

**Riesgo y guarda.** Quedarse con el valor por defecto mas tiempo del que se queda hoy. Lo compensa el tope por dia: con 10 al dia, tres tardes ya dan las 30 muestras y encima repartidas.

> **El verificador corrigió el dato:** Las lineas con 'seguimiento' en los dos registros son 1.339, no 738 (reparto por dia: 187, 110, 247, 34, 198, 47, 155, 6, 139, 52, 50, 28, 86). Los 86 del 25/09 y los 13 dias si son exactos. Y Test-DatosRepartidos se llama en 5 sitios (12060, 12157, 12186, 12227, 12319), no en 6.

### 62. La ventana de lo hablado son 6 idas y vueltas, y el 56 % de los turnos caen fuera ∿

**Valor 7 · coste 4 · ángulo `charla`**

**Qué.** El hilo de la charla se corta a 12 mensajes, un numero escrito a mano. En las conversaciones largas -que son justo las que cuestan entender- Nova ya no tiene delante el principio. Que la ventana se mida en caracteres que caben, y distinta para el modelo local (que si tiene tope de contexto) y para la API (que contesta el 90 % de las veces y no lo tiene).

**El dato.** MAX_HISTORIAL = 12 mensajes, o sea 6 idas y vueltas. Cortando los 365 turnos reales por huecos de 5 minutos salen 49 conversaciones: mediana 3 turnos, pero 15 pasan de 6 y la mas larga tiene 52. En total 206 de los 365 turnos -el 56 %- caen fuera de la ventana. Y de las 247 respuestas, 223 las dio la API y solo 25 el modelo local: el tope de 1.536 de contexto, que es la razon del recorte, casi nunca es quien contesta.

**Dónde se comprobó.** charla_worker.py:77 (MAX_HISTORIAL = 12), :293 (recortar); conteo de conversaciones sobre los turnos del registro; 'charla: contesto (api)' 223 veces y '(local)' 25 en assistant.log + assistant.log.1

**Cómo se hace.** recortar() deja de contar mensajes y cuenta caracteres, con dos presupuestos: el del local sale de num_ctx (1536 tokens, unos 2.500 caracteres de margen seguro) y el de la API es la conversacion entera desde el ultimo hueco de 5 minutos, con un tope duro. generar_local y generar_api ya reciben list(historial), asi que el recorte se hace al armar cada uno y no hace falta tocar nada mas.

**Riesgo y guarda.** Mas contexto es mas lento y mas caro en la API. Guardas: tope duro de caracteres por encima del presupuesto, y se mide contra lo que ya esta medido -de preguntar a la primera frase, mediana 1,0 s y p90 9,0 s en el registro-; si sube, se vuelve al numero de hoy.

### 63. La memoria permanente que Nova escribe y nadie puede preguntar

**Valor 7 · coste 4 · ángulo `muertas`**

**Qué.** perfil-todo.md es la memoria que no se borra: 64 datos de braya, incluido el nombre de su mascota y su apodo. Nada la lee. Las dos funciones que existen para leerla no las llama nadie, y no hay ni una frase que lleve a ellas. Nova apunta ahí lo que se le cae del perfil de 60 plazas y ahí muere: ni viaja al modelo ni se puede preguntar. La idea es que Find-PerfilTodo tenga por fin quien la llame -por voz con "que sabes de mi sobre X"- y, sobre todo, que cuando el perfil que sí viaja no tenga la respuesta, Nova mire sola en la permanente antes de decir que no lo sabe.

**El dato.** Get-PerfilTodo aparece 3 veces en assistant.ps1: su propia definicion (8244), su uso dentro de Find-PerfilTodo (8258), y nada mas. Find-PerfilTodo aparece 1 vez: su definicion (8254). Cero llamadores en 28.720 lineas. Sus unicas 5 referencias vivas estan en tools/probar-memoria-permanente.ps1, un banco. Mientras tanto el fichero tiene 64 datos, de los cuales 27 NO estan en perfil.md -el que si viaja al modelo-: esos 27 hoy no hay forma humana de sacarlos. Entre ellos "tiene un gato o mascota llamada Meramiau" y "tiene un apodo o nombre especial: Mira mio".

**Dónde se comprobó.** C:\Users\braya\Documents\voice-ctrl\assistant.ps1:8244 (Get-PerfilTodo), :8254 (Find-PerfilTodo), :8258. Comprobado con: grep -noP "(?<![-\w])(Get-PerfilTodo|Find-PerfilTodo)(?![-\w])" assistant.ps1  -> solo 3 lineas. El recuento de 64 vs 27 sale de comparar memoria/perfil-todo.md con memoria/perfil.md quitando la fecha del final de cada linea.

**Cómo se hace.** Dos costuras, las dos cortas. (1) En el bloque de Invoke-FastCommand que ya tiene el ancla de "que sabes de mi" (assistant.ps1:4563) anadir una variante con cola: '^que sabes de mi sobre (.+)$', kind nuevo 'perfilBusca', y en el switch de acciones llamar a Find-PerfilTodo $a.que. (2) La parte que de verdad da autonomia: en Get-DatosNova (22752) o justo antes de montar el pedido de la charla, si Find-PerfilTodo encuentra algo para las palabras de la pregunta, meter esas lineas en el campo 'datos' que texto_datos ya inyecta en charla_worker.py:1071. Asi Nova mira su memoria permanente sola, sin que nadie se lo pida.

**Riesgo y guarda.** Que la permanente crezca y empiece a colarse en cada peticion, que es justo lo que el comentario de la cabecera prohibe ("no viaja NUNCA", y por eso no tiene tope). La guarda: solo entran las lineas que casan con palabras de la pregunta y como mucho las que ya limita el parametro $tope=6 de Find-PerfilTodo; si no casa ninguna, no se manda nada y el prompt queda como hoy.

> **El verificador corrigió el dato:** Los datos de la permanente que NO estan en perfil.md son 31, no 27 (comparando en plano y quitando la fecha del final de cada linea). El resto -64, 41, 3 apariciones, 1 aparicion, cero llamadores- sale clavado.

### 64. Nova no lleva la cuenta de sus propias muertes: ni las suyas ni las de sus piezas ⬆ ∿ ⚙

**Valor 7 · coste 4 · ángulo `continuidad`**

**Qué.** Nova ya detecta UNA caida al arrancar (Get-CaidaAnterior) y relanza sola el oido y la capsula hasta tres veces, pero no guarda ni una cifra de nada de eso: no sabe que se muere mal la mitad de las veces, ni que ayer relanzo el oido cuatro veces. Los unicos contadores que hay ($script:wakeIntentos y $script:uiIntentos) viven en RAM y vuelven a cero en cada arranque, asi que ni siquiera dentro del dia se acumulan. Cuenta cuatro cosas en estadisticas -'arranque', 'cierre-limpio', 'oido-muerto' y 'capsula-muerta'- y cuando la cuenta de hoy pasa de su propia mediana de 14 dias lo dice una vez: 'llevo cuatro arranques esta tarde, algo me esta matando'.

**El dato.** Sesiones: desde que existe la linea 'VoiceAssistant cerrado' (18/09 17:06, commit 79ca9a0) hay 72 arranques y solo 36 cierres limpios -exactamente la mitad acaba sin salir por la puerta-, con mediana de 9,6 min por sesion y 93 de 255 por debajo de 5 minutos. Piezas: 28 lineas 'el worker de escucha murio; relanzando' y 18 'la interfaz murio' en los dos registros (17 dias), 46 relanzamientos en 12 dias. Repartidas de verdad, no en un pico: el oido en 10 dias distintos con un pico de 9 el 22/09; la capsula en 6 dias distintos con 6 el 11/09 y 4 el 10/09. Ninguno de esos 46 se cuenta en ningun sitio ni se le dice a braya, y ninguna de las 66 rutas distintas que hoy tiene estadisticas.json habla de arranques, cierres ni muertes de worker (verificado hoy sobre memoria\estadisticas.json).

**Dónde se comprobó.** Conteo sobre assistant.log.1 + assistant.log con corte en '2026-09-18 17:06:00' -> iniciados 72, cerrados 36; grep -E 'worker de escucha murio|la interfaz murio' | awk fecha | uniq -c -> 46 en 12 dias, repartidos en 10 y 6 dias. En el codigo: assistant.ps1:21154 ('VoiceAssistant iniciado'), 21162 ('VoiceAssistant cerrado', dentro del Register-EngineEvent PowerShell.Exiting), 27092-27101 (relanzar el oido), 28679-28696 (relanzar la capsula), 26313 y 18458 (los dos contadores de intentos puestos a 0 en cada arranque).

**Cómo se hace.** Un Add-Estadistica en los cuatro sitios que ya existen: assistant.ps1:21154 (arranque), 21162 (cierre limpio), 27094 (donde se escribe el WARN del oido) y 28692 (donde se escribe el de la capsula) -las dos ultimas son WARN que hoy ya se escriben sin contarse-. La comparacion con la mediana de 14 dias reutiliza Get-Estadisticas (2594) y Test-DatosRepartidos (11990), que ya se usan en Test-RevisionPropia. El aviso sale por Send-AvisoEntorno (11013) con su clave, que ya se frena sola en disco: nivel 'medio' para la tasa de muerte de la propia Nova -que ella no se arregla sola-, nivel 'bajo' para las muertes de oido y capsula, que si se arregla sola relanzando.

### 65. Las copias de seguridad resucitan 62 datos que el perfil ya habia tirado ∿

**Valor 6 · coste 4 · ángulo `privacidad`**

**Qué.** Nova volveria a pasar la poda por las copias viejas. Hoy el perfil se limpia solo -tira los estados que no son rasgos- pero las copias de seguridad guardan intacto el perfil de aquel dia, asi que lo borrado sigue vivo en doce sitios. Al hacer la copia del dia, reescribiria las anteriores quitando de su perfil.md los datos que ya no estan en el vivo.

**El dato.** Hay 12 zips en copias\, ninguno se poda nunca (cero borrados en el codigo). Juntando el perfil.md de los doce salen 95 datos distintos sobre braya. El perfil de hoy tiene 38. O sea: 62 datos que Nova ya decidio que no eran suyos siguen guardados, entre ellos 'Braya considera que Nova se equivoca frecuentemente', 'Braya siente que Nova no entiende bien lo que dice' y 'A braya no le gusta la musica electronica'. Los zips ademas llevan cerebro.json, los charla-*.jsonl de cada dia y el diario entero: en el del 23/09 hay charla-2026-09-22.jsonl y charla-2026-09-23.jsonl, que en memoria\cerebro ya no existen (alli solo queda el de hoy). Y 'olvida' aparece 29 veces en los registros.

**Dónde se comprobó.** comm -23 (datos de los 12 zips) (datos de hoy) | wc -l -> 62; 95 en las copias frente a 38 en memoria/perfil.md; ls copias/*.zip -> 12; grep -n copias assistant.ps1 filtrado por borr|poda|limpia|remove -> cero resultados; listado del zip del 23/09 con System.IO.Compression

**Cómo se hace.** En la funcion que crea la copia diaria (la que escribe copias\lo-aprendido_*.zip), despues de escribir la nueva: leer las lineas '- ' del perfil.md vivo, abrir cada zip anterior en modo Update con System.IO.Compression.ZipFile, y reescribir su entrada memoria\perfil.md quedandose solo con las lineas que sigan en el vivo. Lo mismo para memoria\cerebro\cerebro.json con los ids que la poda ya quito. Banco tools\probar-copias-podadas.ps1 que meta un dato falso, lo quite del perfil y compruebe que desaparece de los zips.

**Riesgo y guarda.** Corromper un zip a medio reescribir y quedarse sin copia, que es justo lo contrario de lo que se busca. La guarda: se escribe a un .zip.tmp al lado y se renombra al terminar, igual que hace Write-Atomico con los json; y se procesa un zip por dia, no los doce de golpe, para que un fallo nunca se lleve mas de una copia.

> **El verificador corrigió el dato:** 13 zips en copias\, no 12 (del 12/09 al 24/09), mas 12 en OneDrive\Nova\copias. 94 datos distintos en las copias, no 95. Y los huerfanos son 73, no 62.

### 66. Los tres puertos de mando que no existen se llevan el 96 % del tiempo de sondeo ∿

**Valor 6 · coste 4 · ángulo `mando`**

**Qué.** Nova aprende sola cuales de los cuatro puertos XInput han contestado alguna vez y deja de preguntarles a los vacios en cada vuelta. El puerto que si contesta se sigue sondeando cada 30 ms; los que nunca han contestado se miran cada pocos segundos, y en cuanto uno aparece vuelve a la lista de siempre. Nadie escribe el numero: el intervalo de repaso lo sube y lo baja ella segun encuentre o no mandos nuevos.

**El dato.** Medido hoy en esta consola con 300 llamadas por puerto: puerto 0 (el mando de la Ally, conectado, ret=0) 0,0464 ms por llamada; puertos 1, 2 y 3, todos devolviendo 1167 (no conectado), 0,3597 / 0,4715 / 0,3176 ms. De los 1,196 ms que cuesta una vuelta de sondeo, 1,15 ms se van en puertos que nunca han tenido nada: el 96 %. El bucle duerme 30 ms, o sea 33 vueltas por segundo, 38 ms de CPU por segundo, ~3,8 % de un nucleo quemado para siempre. Y el puerto 0 contesto en los 130 arranques que hay en los dos logs ("mando: vibracion disponible", 9 + 121).

**Dónde se comprobó.** assistant.ps1:26781 (el for de $u -lt 4) y assistant.ps1:28720 (Start-Sleep 30). Medicion: Add-Type con XInputGetState de xinput1_4.dll, 300 llamadas por puerto, en esta Ally. Arranques: grep -c 'mando: vibracion disponible' assistant.log assistant.log.1 -> 9 y 121.

**Cómo se hace.** En el for de assistant.ps1:26781, llevar $script:puertoVisto = @{} con la ultima vez que cada puerto devolvio 0. Un puerto que nunca ha contestado solo entra en el for si ha pasado $script:rescanMandoMs. Ese numero empieza en 1000, se multiplica por 2 hasta 4000 cada vez que un repaso sale vacio, y vuelve a 1000 en cuanto un puerto nuevo contesta. El puerto 0 queda fuera del rescan: es el mando fisico de la consola y es el que dispara el gatillo. No se toca nada del manejo de $pollErrs ni de $script:pollReintento, que son para la excepcion, no para el 1167.

**Riesgo y guarda.** Un mando enchufado en el puerto 1 podria tardar hasta 4 s en verse. Guardas: el puerto 0 nunca entra en el rescan (es el que dispara el gatillo y el que esta siempre), el rescan vuelve a 1 s al primer hallazgo, y como el rescan solo aplaza puertos que han dado 1167 desde el arranque, el caso peor es un mando USB nuevo que tarda unos segundos en responder al selector; el gatillo no se ve afectado nunca.

> **El verificador corrigió el dato:** 85,1 %, no 96 %. Medido con la clase AX del propio proyecto: p0=0,3949 / p1=0,8836 / p2=0,7740 / p3=0,5935 ms, vuelta 2,6460 ms, de la que 2,2511 ms son puertos vacios. A 33 vueltas: 87,3 ms/s de CPU = 8,7 % de un nucleo, y el ahorro es 74,3 ms/s, no 38. (En C# puro, sin el New-Object de PowerShell, el reparto es 0,0028 / 0,1188 / 0,1114 / 0,1202 ms = 99,2 %.)

### 67. Que la cápsula diga si se la ve, en vez de adivinarlo por la resolución ∿

**Valor 7 · coste 5 · ángulo `capsula`**

**Qué.** Hoy el cerebro decide si la cápsula se ve comparando la resolución nativa con la actual, y esa cuenta nunca ha dado 'no se ve'. La cápsula sí lo sabe: ya calcula si está en pantalla completa, si una ventana la tapa y si está a opacidad cero. Que escriba una línea en tmp\ui-visible.txt (la misma puerta por la que ya escribe tmp\gestos.log) y que Test-CapsulaCiega lea eso. De paso, la hora de ese fichero vale de latido: hoy el cerebro solo se entera de que la cápsula MURIÓ, no de que se colgó viva.

**El dato.** 'CAPSULA CIEGA' sale 0 veces en las 58.522 líneas de registro (7.942 en assistant.log + 50.580 en assistant.log.1), y en esos mismos días braya jugó 72.176 segundos (20 horas) según memoria\juegos.json. Los 5 avisos 'SIN VOZ' del registro no llevan la coletilla ', vibrado', o sea que Send-AvisoVibrado no ha disparado ni una vez. Y el campo 'capsulaCiega' se escribe en ui-estado.json pero nova_ui.cs no lo lee: 0 coincidencias de 'capsulaCiega' en las 4.144 líneas del fichero.

**Dónde se comprobó.** assistant.ps1:18574 (escribe capsulaCiega), 18761 (Test-CapsulaCiega), 18788 (Send-AvisoVibrado), 28678 (solo vigila el proceso muerto); nova_ui.cs:2933 (tapadaCuenta), 4066 (Cine), 2673 (Opacity=0). Contado con: grep -c 'CAPSULA CIEGA' assistant.log assistant.log.1 (0 y 0); grep -c 'capsulaCiega' nova_ui.cs (0); grep -ohE 'aviso SIN VOZ.*' assistant.log assistant.log.1 (5 líneas, ninguna con ', vibrado')

**Cómo se hace.** En nova_ui.cs: una función Anotar-Visible() junto a AnotarGesto (2322) que cada 5 s escriba '1|0 <hora>' en tmp\ui-visible.txt usando foco, apartada, Opacity y una P/Invoke a SHQueryUserNotificationState de shell32. En assistant.ps1: Test-CapsulaCiega (18761) lee ese fichero en vez de comparar resoluciones, y el bloque de vigilancia (28678) añade 'lleva demasiado sin escribir' como segundo motivo de relanzar.

**Riesgo y guarda.** Dar por ciega una cápsula que sí se ve haría a Nova hablar encima de la partida, que es peor que el fallo que arregla. Guarda: si el fichero falta, está vacío o es viejo, se supone visible, igual que hace hoy Test-CapsulaCiega con las resoluciones desconocidas. Y el plazo de 'viejo' se calcula con la cadencia medida del propio fichero, no con un número a mano.

> **El verificador corrigió el dato:** El registro tiene 58.636 lineas hoy (8.056 + 50.580), no 58.522. Y memoria\juegos.json suma 71.721 segundos (19,9 h) en 9 dias distintos (15,16,18,19,20,22,23,24,25 de septiembre), no 72.176 s en 11 dias.

### 68. Guardar también las correcciones que no son charla ⬆

**Valor 7 · coste 5 · ángulo `ficheros`**

**Qué.** El juicio de «este turno importa» solo corre dentro de la charla. Cuando braya corrige una ORDEN («no, yo te dije el segundo vídeo»), esa frase no pasa por apuntar_charla y por tanto no llega nunca a importante.jsonl. Se pierde justo el tipo de corrección más útil: la que dice qué orden ejecutó mal.

**El dato.** De las 69 frases del registro que encajan con las reglas de corrección, 21 (el 30 %) no aparecen en ninguna línea CHARLA: fueron órdenes o dictados normales. Ejemplos literales: «Pero ya no te dije que reproducieras eso, yo te dije el segundo video y claramente no era eso», «No, lo que quiero saber es por qué me contestas eso ahora, si eso lo dije hace cinco minutos», «No, solo no me estás entendiendo, Dije que podría ser algo de tu código».

**Dónde se comprobó.** charla_worker.py:987 (apuntar_importante se llama SOLO desde apuntar_charla, línea 970); cruce en python de las 69 frases-corrección de «[escucha] dictado:» contra el conjunto de frases «CHARLA (...)» de assistant.log + assistant.log.1 -> 21 fuera

**Cómo se hace.** Llevar por_que_importa() a PowerShell (son dos expresiones regulares y un contador de palabras) y llamarla en el punto donde ya se apunta el dictado, escribiendo en el MISMO memoria\cerebro\importante.jsonl con por='correccion-orden' y un campo más: la orden que Nova acababa de ejecutar. Así la línea dice qué se pidió, qué se hizo y qué dijo braya después.

**Riesgo y guarda.** Doblar la regla en dos sitios y que se separen con el tiempo (es la manera 15 de que un banco salga verde mintiendo: probar una copia y no la otra). Guarda: el banco compara las dos implementaciones sobre la misma lista de frases y falla si no coinciden en las 69.

> **El verificador corrigió el dato:** 16 de 68 fuera de charla (24 %), no 21 de 69 (30 %); y de esas 16 solo ~9 son correcciones de verdad (precision ~55 % fuera de la charla). Las tres frases literales que cita SI aparecen las tres.

### 69. Saber si la consola esta en la mesa o en las manos: el paquete del mando y el sensor de orientacion, gratis los dos ∿ ⚙

**Valor 7 · coste 5 · ángulo `mando+mando`**

**Qué.** Nova ya lee el estado del mando cada 30 ms y tira el dwPacketNumber, que XInput cambia solo cuando el mando se mueve: con el sabe gratis cuantos segundos lleva braya sin tocarlo. Y la consola tiene un sensor de orientacion que dice si esta tumbada boca arriba, en 0,08 ms. Juntando las dos senales, Get-EnLaMesa: plana Y el mando quieto mas que el umbral aprendido = esta en la mesa, no en las manos. Con eso decide si la pista de contestar con el mando es una via real antes de ofrecerla, y si una pregunta se hace ahora o se aplaza. El umbral de 'quieto' lo aprende de sus propios huecos, no de un numero puesto a mano. Ninguna de las dos senales cuesta nada: una ya se lee y se tira, la otra cuesta 0,08 ms.

**El dato.** EL MANDO: dwPacketNumber aparece 0 veces en las 28.720 lineas de assistant.ps1, aunque la struct se declara entera en assistant-dx.cs:35-38 y se lee cada 30 ms; solo se usa wButtons. Leida hoy la struct del puerto 0: LX=0 LY=-1 RX=0 RY=-1, o sea que las setas tienen valor en reposo y cualquier roce cambia el paquete. Hoy la unica senal de presencia es Get-InactividadMin (GetLastInputInfo) con un umbral escrito a mano, $UsoAllyOcioMin = 5 (assistant.ps1:13262). Coste de la senal nueva: cero, el estado ya se lee. Lo que se pierde por no tenerla: 41 lineas CONFIRMAR en los dos logs = 20 preguntas, de las que 5 murieron por plazo y 0 se contestaron con el mando. LA ORIENTACION: medido en esta Ally, SimpleOrientationSensor PRESENTE, devuelve Faceup, 0,0834 ms por lectura (200 llamadas con calentamiento; 0,1654 ms sin el). Gyrometer PRESENTE. LightSensor no hay. Ninguno de los tres aparece ni una vez en todo el repositorio, ni en el codigo ni en los 39 .md. Y POR QUE NO EL ACELEROMETRO: tambien esta PRESENTE (intervalo minimo 10 ms, lecturas reales Z entre -1,319 y -0,822) y contesta de verdad -30 lecturas de 30 no nulas-, pero su GetCurrentReading cuesta 15,52 ms medidos (15,5903 en la primera tanda; primera lectura 27,7 ms, maximo 27,71), y Watch-Acelerometro se llama desde el bucle cada 250 ms: encenderlo tal como esta pararia medio tick cuatro veces por segundo. El sensor de recambio cuesta 186 veces menos.

**Dónde se comprobó.** grep -c dwPacketNumber assistant.ps1 -> 0 (solo assistant-dx.cs:37 y cuatro tools/diag); assistant-dx.cs:35-38 (struct XINPUT_STATE); assistant.ps1:26785 (el poll, solo lee wButtons); assistant.ps1:26750 (Get-PistaMando, solo mira $script:mandoHay); assistant.ps1:12789 (Get-InactividadMin) y assistant.ps1:13262 ($UsoAllyOcioMin = 5); lectura de la struct hoy: LX=0 LY=-1 RX=0 RY=-1. Medicion WinRT desde PowerShell en esta consola: SimpleOrientationSensor.GetDefault() -> PRESENTE, 200 GetCurrentOrientation -> 0,0834 ms/llamada, valor Faceup; Accelerometer.GetDefault() -> PRESENTE, MinimumReportInterval 10, 200 GetCurrentReading -> 15,52 ms/llamada; Gyrometer -> PRESENTE. Codigo del acelerometro: assistant.ps1:20431 (la guarda de config), 20440 (Watch-Acelerometro y su guarda de 150 ms), 28429 (la llamada cada 250 ms); config.json sensores.acelerometro = false. grep -ril de SimpleOrientation, orientacion y Gyrometer sobre *.md y el codigo -> nada.

**Cómo se hace.** Dos piezas, y la segunda necesita la primera. (1) EL MANDO: en assistant.ps1:26785, junto al OR de wButtons, comparar $state.dwPacketNumber con el guardado del puerto 0 y anotar $script:mandoMovidoEn = $sw.ElapsedMilliseconds si cambia. Anadir Get-QuietudMando, que devuelve los segundos desde ese instante; el umbral de 'esta quieto de verdad' sale del percentil 90 de los huecos entre movimientos de los ultimos 7 dias, guardado en memoria\estadisticas.json. (2) LA ORIENTACION: en el bucle, junto al bloque del acelerometro (assistant.ps1:28429), leer GetCurrentOrientation una vez por segundo y guardar cuanto lleva en Faceup o Facedown, con try/catch y apagandose si tarda mas de 5 ms, igual que ya hace Watch-Acelerometro. Get-EnLaMesa devuelve cierto solo si la orientacion es plana Y Get-QuietudMando pasa del umbral aprendido. Lo consultan Get-PistaMando (assistant.ps1:26750), que hoy solo mira $script:mandoHay, y el sitio donde se decide si una pregunta se hace o se aplaza. El acelerometro se queda como esta: si algun dia hace falta, por ReadingChanged, nunca por GetCurrentReading dentro del bucle.

### 70. El historial de energia que Windows guarda de los dias que Nova no estaba ∿

**Valor 7 · coste 5 · ángulo `consola`**

**Qué.** Nova solo sabe lo que vio estando viva, y muere y nace muchas veces al dia. Windows guarda por su cuenta, en el informe de bateria, cuanto tiempo estuvo la consola despierta con cargador y sin el, dia a dia, y las ultimas transiciones. Leyendolo una vez al dia, Nova sabria de verdad como usa braya la consola en vez de adivinarlo con los trozos que le tocaron ver.

**El dato.** Nova arranco 259 veces en 17 dias (13 + 246 lineas "VoiceAssistant iniciado") y su serie de bateria entera tiene 18 lineas. El informe de Windows sale en 296 ms y trae 12 entradas de historial por dia y 20 transiciones recientes. Lo que dicen: del 15/09 al 26/09 la consola estuvo ACTIVA Y ENCHUFADA entre 23 h 11 m y 23 h 59 m CADA dia, y sin cargador 2 h 43 m en total en los once dias (media 14,8 min al dia); cuatro de esos once dias tienen 0 segundos sin cargador. Por eso el aprendizaje por juego no arranca nunca, y por eso el minimo de bateria que Nova ha visto en 17 dias es 90 %.

**Dónde se comprobó.** Medicion: powercfg /batteryreport /xml, secciones History (12 entradas, campos ActiveDcTime / ActiveAcTime / CsDcTime / CsAcTime) y RecentUsage (20 entradas con Ac y LocalTimestamp), cronometrado en 296 ms. Conteos: grep -c "VoiceAssistant iniciado" assistant.log assistant.log.1 (13 y 246); grep -c "\[bateria\]" assistant-pulso.log = 18. Codigo: assistant.ps1:28466-28486, el comentario que ya intuia esto con quince dias de datos propios.

**Cómo se hace.** Una Read-InformeBateria que lance powercfg a un XML en tmp\, lo lea con [xml] y devuelva los tramos. Se llama UNA vez al dia, nunca en el bucle. Con los tramos de RecentUsage donde Ac = 0, Update-BateriaJuego (8833) puede cruzar por fin los minutos de juego que ya tiene en juegos.json con los minutos reales sin cargador, aunque Nova no estuviera viva entonces.

**Riesgo y guarda.** Que powercfg tarde o falle en otra maquina, o que el XML cambie de forma: se cronometra, se apaga sola si pasa del tope y si no trae History se deja todo como esta. Y cuidado con la primera entrada del historial, que aqui trae una duracion imposible (P24695DT4H10M53S): las entradas absurdas se tiran, no se promedian, que promediar una basura es inventarse un numero con cara de medido.

> **El verificador corrigió el dato:** powercfg /batteryreport /xml tarda 208 ms, no 296. Todo lo demas sale exacto: 12 History, 20 RecentUsage, ActiveAc entre 23 h 11 m 37 s y 23 h 59 m 40 s los once dias del 15/09 al 26/09, ActiveDc sumando 2 h 42 m 42 s (media 14,8 min/dia) y CUATRO dias a PT0S (17, 21, 22 y 24/09). La primera entrada trae P24695DT4H10M53S, tal cual avisaba. 259 arranques (13+246) y 18 lineas [bateria], exactos.

### 71. El oído sabe cuánto va a tardar cada motor, así que no empieza lo que no llega ∿

**Valor 7 · coste 5 · ángulo `oido`**

**Qué.** El asistente espera 15 s por un repaso y luego se rinde. El oído tiene un solo tope para decidir si repasa: 8 segundos de audio (12 para base), el mismo para todos los motores, aunque unos son seis veces más lentos que otros. La idea es que el oído use lo que ya apunta de sí mismo -cuántos segundos tarda cada motor por segundo de audio- para calcular antes de empezar si va a llegar. Si no llega, contesta vacío AL MOMENTO: el asistente sigue con el siguiente escalón en vez de esperar 15 segundos y tirarlo.

**El dato.** Sobre los 477 repasos del registro, los segundos de CPU por segundo de audio son: base 0,32, canary 0,43, small 0,93, turbo 2,97. Dentro del plazo de 15 s le caben 46 s de audio a base y solo 5 a turbo, y el tope de hoy es 8 para los dos. El resultado: turbo se pasa de los 15 s en 17 de sus 23 usos (73 %), small en 12 de 94, base en 6 de 328. En total 36 repasos llegaron tarde: 23,2 minutos de CPU quemados para nada y 9 minutos de plazo esperándolos. Y en el registro hay 30 'OIDO FINO: sin respuesta a tiempo; sigo con lo que tenia'.

**Dónde se comprobó.** wake_vosk.py:153 (REPASO_MAX = 8.0), :164 (REPASO_MAX_BASE = 12.0), :1648 (tope_repaso), :1606 (atender_reintento); assistant.ps1:24206 ($ReintentoMaxMs = 15000). Medición sobre las 477 filas con 'motor' de registro.jsonl, dividiendo 'segundos' entre el 'dur' de la fila de orden con el mismo id. grep -c 'sin respuesta a tiempo' assistant.log assistant.log.1 -> 30.

**Cómo se hace.** En wake_vosk.py, una lista por motor con los segundos-por-segundo de sus últimos repasos, guardada con guardar_lista/cargar_lista como las coberturas. En atender_reintento, donde hoy se compara duracion > tope_repaso, se compara duracion * mediana_del_motor contra el plazo que el asistente le pase (hoy 15 s; se le escribe en el mismo fichero REINTENTO, detrás del nombre del motor, que ya viaja así). Si no cabe, se salta la carga y se escribe REINTENTO_TEXTO vacío, que es lo que ya hace hoy cuando el audio es largo.

**Riesgo y guarda.** Que se niegue a repasar algo que sí habría llegado porque la mediana estaba torcida por un arranque en frío. Dos guardas: se usa la mediana (no la peor) de una lista corta y reciente, y se deja siempre un margen; y el escalón último de la cascada nunca se salta por este motivo, igual que la revisión propia del asistente ya nunca quita el último escalón.

> **El verificador corrigió el dato:** Medición reproducida exacta sobre las 477 filas con 'motor' de registro.jsonl dividiendo 'segundos' entre el 'dur' de la fila con el mismo id: base 0,32 (n=328), canary 0,43 (n=29), small 0,93 (n=94), turbo 2,97 (n=23). Pasados de 15 s: turbo 17 de 23, small 12 de 94, base 6 de 328, 36 en total, 23,2 minutos de CPU quemados. Y 'sin respuesta a tiempo' sale 30 en los dos logs. CORRECCIÓN DE BULTO: no es cierto que el tope sea 'el mismo para todos los motores'. canary y omni salen de atender_reintento por su propia rama (wake_vosk.py:1626-1638) ANTES de que se calcule duracion y tope_repaso, así que hoy NO TIENEN NINGÚN TOPE. Eso refuerza la idea en vez de tumbarla, pero cambia dónde hay que meter mano. (Hay además un quinto motor que la idea no ve: omni, n=3, 1,05 s por segundo.)

### 72. Que Nova sepa cuándo se queda sorda y cuánto rato ⬆ ∿

**Valor 7 · coste 5 · ángulo `autoconocimiento`**

**Qué.** El bucle principal duerme 30 ms por vuelta, pero nadie ha medido nunca cuánto tarda de verdad una vuelta. Nova apunta en cada vuelta lo que tardó la anterior (una resta de $sw.ElapsedMilliseconds, coste cero) junto con el nombre de lo último que hizo. Guarda el peor de la sesión y el percentil 99 de sus propias vueltas; cuando una vuelta pasa de ese p99 propio, lo escribe: 'me quedé sorda 1,4 s abriendo Steam'. Es la única forma de hacer cumplir la regla 4 de la casa en vez de suponerla.

**El dato.** Cero mediciones del pulso real del bucle en 26.900 líneas: ElapsedMilliseconds sale 350 veces en assistant.ps1 y ninguna cronometra la vuelta. Mientras tanto el bucle sí se bloquea y está medido a mano en los comentarios: Say deja el micrófono mudo 3,6 s en el saludo (comentario de la línea 26180), recorrer los ~200 procesos cuesta de 500 a 740 ms (medido el 21/09, comentario de Get-RamResumen), y la zona de ejecución de órdenes que Process-Texto alcanza desde el bucle (líneas 14000-18000) tiene 29 Start-Sleep que suman 8.050 ms de bloqueo deliberado. El comentario de la línea 18875 llega a contar '47 vueltas del bucle' suponiendo el periodo, porque nadie lo sabe.

**Dónde se comprobó.** assistant.ps1:28707-28720 (cuerpo del bucle); awk 'NR>=14000 && NR<=18000' assistant.ps1 | grep -oE 'Start-Sleep -(Milliseconds|Seconds) [0-9]+' | awk suma -> n=29 suma_ms=8050; grep -c ElapsedMilliseconds assistant.ps1 -> 350

**Cómo se hace.** Dos variables de script junto a $startPrev al final del bucle (assistant.ps1:28707): $script:vueltaMs = $sw.ElapsedMilliseconds - $script:vueltaDesde y $script:vueltaDesde = $sw.ElapsedMilliseconds. La etiqueta de 'qué estaba haciendo' se pone donde ya hay un Set-UI o un Log. El almacén ya existe y está probado: Add-TrabajoTiempo/Get-TrabajoPercentil (assistant.ps1:22139-22200) con clave 'vuelta'. El aviso sale por Send-AvisoEntorno, como los demás.

**Riesgo y guarda.** Que el propio medidor ensucie el registro con una línea por vuelta. La guarda: sólo se escribe cuando la vuelta supera el p99 de esa misma sesión y como mucho una vez por minuto; el resto vive en memoria. Y si Get-TrabajoPercentil devuelve 0 (menos de $TrabajoTiemposMin muestras) no se dice nada, que es como ya se dice 'no me preguntes todavía'.

### 73. Sembrar del registro los contadores de la espera aprendida, contando solo los avisos que de verdad suenan ∿ ⚙

**Valor 6 · coste 5 · ángulo `numeros-fijos+iniciativa`**

**Qué.** Desde el 25/09 Nova mira si braya le habla en los cinco minutos siguientes a cada aviso y, con ocho muestras, espacia los que no mueven nada. El mecanismo esta bien; el problema es que los contadores empezaron en cero ese dia y ninguna clave llega a ocho, asi que hoy la regla no hace absolutamente nada y un mes despues seguiria igual. El registro ya guarda desde el 9 de septiembre esos mismos avisos con su hora y la actividad de braya: que se lean UNA vez al arrancar y se siembren los contadores. Y con un filtro que ninguna de las dos versiones tenia entera: solo los avisos que de verdad se oyen, porque de un aviso que nunca sono no se puede deducir si movio algo.

**El dato.** HOY: 12 muestras de reaccion en total (25 y 26/09) repartidas en 10 claves -oido-ruido 4 (1 sirvio + 3 nada), lo-que-no-dije 2, y ocho claves con 1-, contra un $AvisoReaccionMin de 8: ninguna llega, asi que Get-EsperaAviso devuelve siempre el numero escrito. EL REGISTRO: 97 avisos ENTORNO en assistant.log + assistant.log.1 (no 94 ni 96) con su hora, y 1.361 marcas de actividad de braya (DICTADO + TOQUE CORTO; no 3.140). CRUZANDOLOS con la ventana de 300.000 ms que usa el codigo: oido-ruido 36 avisos con 3 reacciones (8 %) -> su espera se multiplicaria por 4; bateria-llena 21 con 3 (14 %) -> se multiplicaria por 2. PERO bateria-llena se emite con nivel 'bajo' (assistant.ps1:28540), que solo se ve en la capsula y no suena nunca: su 'no reacciono' no mide nada y queda fuera, aportando CERO. Con ese filtro, de las 97 solo dos claves llegan al minimo de 8: oido-ruido (36, nivel medio) y hora-dormir (8, nivel noche). Quedan fuera los 26 avisos de nivel 'bajo' (bateria-llena 21, lo-que-no-dije 2, cargador-pone 2, resumen-semana 1) y los 2 de oido-mudo, que son 'alto' y ni pasan por Get-EsperaAviso. Hora-dormir va justo en el liston: si se descartan los 16 avisos que caen a menos de cinco minutos del siguiente, puede caer por debajo y quedarse sin sembrar ese dia. La cola restante, toda por debajo de 8: disco-poco 7, juego-cierra 4, gmail-lleno 4, correo-manana 3, me-cai 2, cargador-quita 2, dos descargas con 1, auto-sin-datos 1. MISMO PROBLEMA EN OTRO SITIO, anotado y fuera de este cambio: trabajo-tiempos.json tiene $TrabajoTiemposMin = 10 y de sus 4 claves solo api-traducir (12 muestras) llega; api-plan 3, claude-code-accion 3 y api-pregunta 1.

**Dónde se comprobó.** assistant.ps1:10230 ($AvisoReaccionMin = 8), 10233-10248 (Get-ReaccionesAviso, que suma las claves aviso-sirvio:/aviso-nada: de memoria\estadisticas.json), 10249-10265 (Get-EsperaAviso y su factor x4/x2 bajo el 30 %), 10278 (Test-PuedoAvisar la llama para todo lo que no sea 'alto'), 11032 (la linea 'ENTORNO (clave, nivel): texto' del log), 11038 ($script:avisoMirar, que vigila UN solo aviso y el segundo pisa al primero), 24685 y 27043 (los dos Add-Estadistica que escriben los contadores), 28540 (bateria-llena sale con nivel 'bajo'), 22128-22131 (trabajo-tiempos.json y TrabajoTiemposMin = 10). Medicion: python sobre assistant.log + assistant.log.1 contando 'ENTORNO (clave, nivel)' y emparejando cada uno con la actividad de braya en los 300 s siguientes, y sobre memoria\estadisticas.json y memoria\trabajo-tiempos.json.

**Cómo se hace.** Una funcion nueva Seed-ReaccionesAviso que corre UNA sola vez, en el arranque y despues de Initialize-Escucha -nunca dentro del bucle: son 6 MB de registro- con una marca en tmp para no repetirse. Recorre assistant.log y assistant.log.1, saca cada 'ENTORNO (clave, nivel):' con su hora y descarta tres grupos antes de contar nada: los de nivel 'bajo' (no suenan, solo capsula), los de nivel 'alto' (Test-PuedoAvisar ni llama a Get-EsperaAviso para ellos) y los que tienen otro aviso a menos de cinco minutos, porque ahi no se sabe a cual contesto braya -es el mismo criterio que ya aplica $script:avisoMirar, que solo vigila uno-. Para los que quedan, mira si hay ACTIVADO/DICTADO/ORDEN ESCRITA/TOQUE CORTO en los 300.000 ms siguientes y llama a Add-Estadistica 'aviso-sirvio:clave' o 'aviso-nada:clave' con la fecha del dia del aviso. Cero codigo de decision nuevo: solo se rellenan los contadores que Get-ReaccionesAviso ya lee. Lo de trabajo-tiempos.json queda anotado pero fuera: es otro fichero y otra funcion (Get-TrabajoTiempos).

### 74. Los tres silencios que cierran la frase, sacados de sus 560 grabaciones de uso real en vez de las tandas leídas del 14/09 ∿ ⚙

**Valor 6 · coste 5 · ángulo `numeros-fijos+oido`**

**Qué.** Los tres números que deciden cuándo Nova da tu frase por terminada son constantes fijas de una tanda de 100 grabaciones LEÍDAS del 14/09: SILENCIO_FIN = 1,5 s (frase que aún no se entiende), SILENCIO_FIN_LOTENGO = 1,1 s (el asistente ya tiene la orden entera) y SILENCIO_SIN_PALABRA = 3,2 s (el cierre que manda cuando suenan los altavoces). El tercero ni siquiera es eso: el propio comentario del código dice que es 'provisional y razonado, no medido' y que saldrá de los huecos entre palabras de las órdenes de uso real cuando los haya. Ya los hay: 560 grabaciones guardadas en pruebas\audio\uso. La idea es que el oído mida sus propias pausas dentro de cada orden, se las guarde atadas al nombre del micrófono y ponga los tres silencios en su percentil, exactamente igual que ya hace con la cobertura y la ráfaga, recalculándolos según entren grabaciones nuevas.

**El dato.** Medido dos veces sobre las mismas 560 grabaciones de pruebas\audio\uso, con dos detectores distintos, y las dos mediciones dicen lo mismo: (1) Ventanas de 50 ms con suelo por percentil 20 de los picos por bloque: 1.732 pausas DENTRO de una orden. p50 0,15 s · p90 0,70 · p95 1,15 · p99 2,35 · máxima 6,80 s. (2) Replicando el detector de voz que usa el propio código (segundos_de_voz), huecos de más de 0,09 s: 1.322 huecos. Mediana 0,24 s · p90 0,87 · p95 1,35 · p98 1,95 · p99 2,31 · máximo 6,84 s. Con este reparto, 1,5 s cae en el p96,1. Contra lo que dice el comentario del código (con las 100 leídas, la pausa más larga dentro de una orden normal fue 0,81 s, y 1,44 s forzando pausas a propósito): en uso real hay 139 pausas por encima de 0,81 s, el 8,0 %. Es decir, la tanda leída se quedaba corta por arriba en la cola. Y el precio de esperar de más: la cola de silencio que se paga al final de CADA orden es de 1,77 s de mediana (p90 2,24). Por 560 órdenes son 16,3 minutos de reloj esperando a que Nova dé la frase por cerrada. El 1,5 de hoy espera el doble de lo que hace falta el 90 % de las veces, y a braya lo que le importa es la velocidad.

**Dónde se comprobó.** wake_vosk.py:167 (SILENCIO_FIN = 1.5), wake_vosk.py:188 (SILENCIO_SIN_PALABRA = 3.2, con el comentario que pide la medición), wake_vosk.py:226 (SILENCIO_FIN_LOTENGO = 1.1), wake_vosk.py:229 (silencio_para_cerrar) y wake_vosk.py:3689-3702, que es el único sitio donde se usan los tres. Verificadas las cuatro líneas. Medición: dos scripts propios sobre pruebas\audio\uso\*.wav (560 ficheros), uno con ventanas de 50 ms y suelo por percentil 20, otro replicando segundos_de_voz.

**Cómo se hace.** La máquina entera ya existe en wake_vosk.py y no hay que inventar nada: guardar_lista/cargar_lista (1235/1245) guardan listas de números atadas al nombre del micro y tiran el fichero si es de otro, y cobertura_min() (1207) enseña el patrón completo — percentil + suelo + techo + valor de arranque hasta COBERTURA_MINIMAS muestras. Se añade una lista 'pausas' igual: al cerrar cada dictado se miden los huecos internos del audio que ya está en memoria (o, más barato, se cogen directamente de los tiempos de palabra que Vosk ya devuelve en rec.Result(), que no cuesta ni recorrer el audio) y se apuntan con apuntar_uso/guardar_lista. silencio_para_cerrar() deja de devolver constantes: devuelve el p95 de esa lista para lo que aún no se entiende y el p90 para lo que el asistente ya tiene (los dos escalones que hoy son 1,5 y 1,1), y SILENCIO_SIN_PALABRA sale de la misma lista por su p99 — que es justo lo que pide el comentario del código. Todo acotado entre suelo y techo, con los valores de hoy como respaldo hasta que haya ~30 medidas, igual que COBERTURA_ARRANQUE.

> **⚠ Ojo, esta contradice un descarte anterior.** Las dos ideas que fusiona fueron tumbadas
> por estar descartadas en `AUTONOMIA.md` con una medición de 90-110 grabaciones **leídas**.
> Pero esta no propone bajar el número a mano: propone que Nova lo mida sola de sus **560
> grabaciones de uso real**, y ahí el reparto es otro. Tú decides si el descarte sigue valiendo.

### 75. Apuntar la decisión que NO se tomó, y qué le falta para tomarla ∿

**Valor 6 · coste 5 · ángulo `contadores`**

**Qué.** Nova evalúa cinco decisiones propias cada día (la nube, el oído fino, cada escalón de la cascada, el tope de la nube y el último recurso) y cuando alguna no pasa el listón sale en silencio, sin dejar ni una línea. Que apunte un contador auto-frenado:<decisión>:<filtro> con el filtro concreto que la paró, y cuando el MISMO filtro pare la MISMA decisión varios días seguidos, que lo diga una vez con el número: «me faltan 34 repasos para poder juzgar mi oído fino».

**El dato.** En los 14 días de memoria\estadisticas.json hay CERO 'auto-ajuste', CERO 'auto-deshecho' y CERO 'arranque-medias', y la lista "decisiones" está vacía; en assistant.log y assistant.log.1 juntos también salen 0 de las tres. Y eso que hay NUEVE sitios que escriben 'auto-ajuste'. Simulando Test-RevisionPropia con los datos de hoy y datosDesde=2026-09-20: el oído fino va 56 repasos con neto 7 (9 sirvieron - 2 inventos) y Test-DecisionSolida pide 20+10x7 = 90 intentos, o sea le faltan 34; repaso:canary va 5 de 20 y repaso:base 5 de 20, les faltan 15 a cada uno; turbo va 0 en la ventana. Las cinco están frenadas por falta de dato y no hay ni una línea que lo diga.

**Dónde se comprobó.** assistant.ps1:11982 (Test-DecisionSolida), 11888 ($DecisionMinIntentos=20, $DecisionPorAcierto=10), 12096 (Test-RevisionPropia); grep -n "Add-Estadistica 'auto-ajuste'" assistant.ps1 → 9 sitios; grep -cE "auto-ajuste|auto-deshecho|arranque-medias" assistant.log assistant.log.1 memoria/estadisticas.json → 0, 0, 0

**Cómo se hace.** En Test-RevisionPropia, donde hoy cada 'if' largo se evalúa y se sale sin más: que cada rama calcule qué condición falló y llame a Add-Estadistica "auto-frenado:<clave>:<filtro>". Una función nueva Get-QueMeFalta que devuelva el texto ("me faltan N repasos") a partir de los mismos $numR que ya están calculados. Lo dice por Send-AvisoEntorno, nivel 'medio', que ya respeta el juego y la noche.

**Riesgo y guarda.** Que se convierta en una queja diaria. La guarda: el contador se escribe siempre pero se HABLA como mucho una vez por decisión y por semana, y solo cuando el filtro que frena es UNO solo (si le faltan dos cosas a la vez, no hay noticia que dar). Y nunca en nivel 'alto'.

### 76. La misma queja veintisiete veces en media hora y nadie la oye ∿

**Valor 6 · coste 5 · ángulo `autoconocimiento`**

**Qué.** Cuando algo suyo falla en bucle, Nova lo reintenta indefinidamente al mismo ritmo, escribe la misma línea una y otra vez y no lo dice ni se frena. Un detector de repetición dentro de Log: normaliza la línea (los números a N), la busca en una tabla pequeña y, cuando la misma línea pasa de su propio listón dentro de una ventana, hace dos cosas: frena el reintento doblando la espera, y lo cuenta para que el parte diga 'llevo 27 intentos fallando lo mismo desde medianoche'.

**El dato.** Hoy mismo, 26/09: 27 líneas idénticas 'charla: diario: no pude resumir lo del 2026-09-25 ([WinError 10061] ...)' entre las 00:07:45 y las 00:36:04, una cada 65 segundos exactos, y seguía cuando lo conté. El material sigue sin resumir: memoria\cerebro\charla-2026-09-25.jsonl está ahí y el último diario escrito es el 2026-09-23. No es un caso raro: la línea más repetida de los dos registros es 'RESUMEN AL VOLVER: Mientras no estabas: 1 mensaje de XBOX Game Bar Widgets', 774 veces idéntica.

**Dónde se comprobó.** grep 'no pude resumir' assistant.log | awk hora -> 00:07:45 ... 00:36:04, 27 líneas a 65 s; charla_worker.py:1046-1057 (el post a Ollama y el return False sin freno); ls memoria/diario/ -> último 2026-09-23.md; conteo de líneas idénticas sin [escucha] ni ENTORNO -> 774 la primera

**Cómo se hace.** En Log (assistant.ps1:182-197), antes del Out-File, una tabla de script con la línea normalizada como clave y {veces, primera, ultima}. Pasado el listón se llama a Add-Estadistica "repetido:<clave corta>" y se pone una bandera que el que reintenta consulta para doblar su espera. En el caso del diario, el freno va en charla_worker.py donde hoy hay un return False pelado.

**Riesgo y guarda.** Que la tabla crezca sin fin con 58.554 líneas distintas, o que se frene algo que conviene reintentar rápido. Las guardas: tabla con tope y ventana corta, y el freno sólo llega hasta un techo -nunca deja de reintentar del todo-, que es la regla 2 de la casa: ningún modo sin salida y sin plazo.

> **El verificador corrigió el dato:** No son 27 líneas sino 61, de 00:07:45 a 01:13:07, y seguía escribiéndose mientras yo lo contaba

### 77. La vibracion de aviso esta detras de una puerta que en 16 dias no se ha abierto ni una vez ∿

**Valor 6 · coste 5 · ángulo `mando`**

**Qué.** Nova vibra cuando decide callarse porque hay un juego delante, no cuando cree que no se le ve la capsula. Y mide si el zumbido sirve: si hubo pulsacion del gatillo, apertura del panel o llamada por su nombre en los 30 s siguientes. La clase de aviso que no mueve nada deja de vibrar sola.

**El dato.** Send-AvisoVibrado devuelve false si no esta $script:capsulaCiega, y Test-CapsulaCiega solo es cierto si el juego CAMBIA la resolucion. La linea 'CAPSULA CIEGA' sale 0 veces en los dos logs (16 dias), con 4.038 segundos de nightreign solo el 25/09 apuntados en memoria\uso-ally.json: el juego corre a la resolucion nativa, asi que la puerta no se abre nunca. Resultado medido: 5 lineas 'aviso SIN VOZ' y 0 vibradas. Y el canal si esta: 'mando: vibracion disponible' 130 veces. Ademas hay 450 lineas 'N aviso(s) no cabian ahora; siguen esperando' solo en el log actual.

**Dónde se comprobó.** assistant.ps1:18788 (Send-AvisoVibrado), assistant.ps1 Test-CapsulaCiega y su uso en 28293, Test-AvisoSinVoz en 18771. grep -c 'CAPSULA CIEGA' -> 0 y 0; grep -c 'aviso SIN VOZ' -> 1 y 4; grep -c 'mando: vibracion disponible' -> 9 y 121; grep -c 'no cabian ahora' assistant.log -> 450. memoria\uso-ally.json, 2026-09-25, nightreign con 4038.

**Cómo se hace.** En Send-Aviso (assistant.ps1:18793), cambiar la condicion de vibrar: en vez de $script:capsulaCiega, vibrar cuando Test-AvisoSinVoz haya dicho que no te habla, que es la que ya decide el silencio. Apuntar el instante del zumbido y mirar los 30 s siguientes buscando flanco del gatillo, apertura del panel o activacion por nombre, que el bucle ya ve todos. Guardar por clave de aviso cuantos zumbidos y cuantas reacciones.

**Riesgo y guarda.** Vibrar de mas en mitad de una partida molesta tanto como hablar encima. Guardas: el mismo presupuesto por hora que ya frena los avisos (EntornoPorHora), nunca dos zumbidos en menos de 60 s, nunca uno si ya vibro algo en los ultimos 3 s, y corte automatico de esa clase de aviso tras 5 zumbidos seguidos sin reaccion.

### 78. La costumbre se mide contra el reloj, y braya no tiene reloj ∿

**Valor 6 · coste 5 · ángulo `tiempo`**

**Qué.** Find-Propuesta busca la misma orden a la misma HORA DEL RELOJ. Que busque tambien anclada al ARRANQUE DE LA SESION: la misma orden dentro de los primeros N minutos desde que empiezas a hablar, en 3 dias distintos. Y que mire 14 dias en vez de 7, que es la ventana que ya usa todo lo demas en habitos.json. Si dices que si, nace una regla nueva de tipo 'arranque'.

**El dato.** CERO propuestas en 17 dias: 0 lineas 'PROPUESTA:' en las 58.537 del registro. El unico candidato, 'abre steam', tiene 4 dias distintos en la ventana (el minimo son 3), pero sus horas de reloj son 10:14, 20:05, 18:54 y 01:09: la mediana sale 13:08 y solo 1 de los 4 cae dentro de los +-30 minutos que exige el codigo, asi que se descarta. Medido contra el arranque de la sesion, los SIETE usos de 'abre steam' caen entre -0,6 y +1,4 minutos del inicio. Y hoy la ventana de 7 dias solo tiene 2 dias con usos; con 14 tendria los 4.

**Dónde se comprobó.** assistant.ps1:13031-13100 (Find-Propuesta, el bloque 1 con $mins/$med/+-30) y memoria/habitos.json (usos). Recuento: grep -c "PROPUESTA:" assistant.log assistant.log.1 -> 0 y 0. Desfases calculados cruzando habitos.json con las 714 lineas "[escucha] dictado: '...'" de los dos registros, cortando sesion a 45 min sin ordenes.

**Cómo se hace.** Cuarto detector dentro de Find-Propuesta, al lado de los tres que ya hay. Add-Habito guarda un campo mas: minutos desde la primera orden de esta tanda (la sesion se mide por ordenes, NO por el arranque de Nova, que ocurre 15 veces al dia). Nuevo tipo 'arranque' en el switch de Invoke-Reglas (assistant.ps1:19782) y su frase en Describe-Regla (19355). N sale del p80 de los desfases observados, con suelo de 2 minutos.

**Riesgo y guarda.** Proponer algo que no es costumbre sino una tanda de pruebas. Guardas: sigue siendo una PREGUNTA (regla 1 de la casa), sigue el veto de 60 dias, una al dia, y los 3 dias tienen que ser DIAS distintos, no 3 arranques de la misma tarde.

> **El verificador corrigió el dato:** La mediana que calcula el CODIGO para 'abre steam' es 18:54 (1.134 min), no 13:08: con 4 valores, $mins[[Math]::Floor(4/2)] = $mins[2] = 1.134. El 13:08 sale de medianear los 7 usos, que no es lo que hace Find-Propuesta. La conclusion no se mueve: con 18:54 tambien cae solo 1 de los 4 dentro de +-30 min. Y el registro tiene 58.644 lineas, no 58.537.

### 79. Leer el fichero de lo importante: contar los agujeros y descartar los que no lo son ⬆ ∿ ⚙

**Valor 7 · coste 6 · ángulo `muertas+charla`**

**Qué.** Desde el 25/09 Nova copia a memoria\cerebro\importante.jsonl cada turno en que braya la corrige y cada turno en que ella admite que no sabe algo. Lo escribe en modo 'a' y no lo lee nadie: es el inventario de sus agujeros y esta muerto en el disco. La idea es que el repaso del dia lo lea, junte los agujeros que se repiten, compruebe EN SECO si eso que dijo que no sabia es algo que si sabe (hay 3 de 8 asi), y lo cuente una vez por semana: 'esta semana no supe contestarte N cosas, y M eran de lo mismo'.

**El dato.** memoria\cerebro\importante.jsonl: 518 bytes, 2 lineas, nacido el 25/09 (por eso esta casi vacio). Se escribe en charla_worker.py:961, en modo 'a', y tiene CERO lectores: grep de 'importante.jsonl' y de 'apuntar_importante' fuera de tools\ solo devuelve charla_worker.py (905, 949, 955, 956, 961, 987 -quien escribe, su docstring y la unica llamada, la de 987); dentro de tools\ solo aparece en dos bancos (probar-charla-importante.py:189-190, probar-todo.ps1:1579). MATERIAL QUE HABRIA (tres conteos, con ventanas distintas, todos con las propias regex del fichero sobre assistant.log + assistant.log.1): (a) 17 dias -> 72 lineas: de 365 turnos de charla de braya, 6 correcciones por RE_CORRIGE y 55 mas por la negacion larga, y de 542 respuestas de Nova, 11 agujeros; (b) 14 dias -> 69 lineas: 61 correcciones y 8 agujeros; (c) sobre los dictados -> 68 de 714 (9,5 %) y 318 lineas CHARLA distintas (la cifra de 69/783, 8,8 % y 366 lineas quedo corregida al recontar). Y LO QUE DE VERDAD IMPORTA: de esos 8 agujeros, 3 NO son agujeros. Dos veces '¿que hora es?' (contesto 'no tengo acceso a la hora actual de tu consola') y una el clima. El del clima se arreglo A MANO el 15/09, y el comentario de assistant.ps1:5191 lo dice con estas palabras: 'cual es el clima para hoy iba a la charla, que decia que no tenia el clima'.

**Dónde se comprobó.** charla_worker.py:911-928 (RE_CORRIGE, RE_AGUJERO, RE_NEGACION con NEGACION_PALABRAS=5), :955 (por_que_importa, que devuelve el motivo y no un booleano, justo para poder contarlos por separado), :961 (apuntar_importante, open(..., 'a')), :987 (la unica llamada, dentro de apuntar_charla). El lugar donde colgarlo: charla_memoria.py:795 (Cerebro.repaso) y charla_worker.py:739 (quien lo llama con 20 min en reposo). El filtro en seco: assistant.ps1:3883 (Resolve-Fragment). La salida: assistant.ps1:20486 (Get-ParrafoDecisiones) y :20529 (Write-NotaSemanal). El arreglo manual del clima: assistant.ps1:5191-5193. Los conteos: pasar RE_CORRIGE, RE_NEGACION (>=5 palabras) y RE_AGUJERO por las lineas '[escucha] dictado: ...', 'CHARLA (hablar):' y 'charla dice:' de assistant.log y assistant.log.1.

**Cómo se hace.** Tres piezas y ninguna llamada nueva al modelo: es leer un jsonl y contar. (1) En charla_memoria.py, una funcion agujeros(dias) que lee importante.jsonl, se queda con las lineas por='agujero' y agrupa las que se repiten -por las palabras de contenido de fichas(), o por los vectores que el modulo ya calcula, igual que hace repaso con su corte de 0,95-. (2) Colgarla de Cerebro.repaso (charla_memoria.py:795), que ya corre una vez al dia con Nova 20 minutos en reposo; ahi mismo, cada frase repetida se manda por el camino de ordenes de assistant.ps1 EN SECO (Resolve-Fragment sin ejecutar la accion): si resuelve, es un agujero falso y Nova lo dice -'te dije dos veces que no sabia la hora, y si la se'-; si no resuelve, se queda en la lista de lo que de verdad le falta. (3) La salida se cuelga del resumen semanal que ya existe (Get-ParrafoDecisiones / Write-NotaSemanal, sobre assistant.ps1:20488): una frase mas con los N agujeros de la semana, los M repetidos y los falsos aparte. Guardas: la prueba es en seco y nunca llama a la accion; el fichero es de SOLO LECTURA en este camino (no se poda ni se reescribe); si no hay agujeros repetidos, la frase no sale; y sale una vez por semana, dentro del resumen que ya pasa por Test-PuedoAvisar en nivel medio (callado jugando, callado de noche, tope por hora y presupuesto del dia), que es la guarda contra lo que braya no aguanta: que Nova se ponga a recitar sus fallos.

### 80. Los 424 errores que Nova se traga: leerlos gratis en $Error, y arreglar ya el unico que se sabe que muerde ⬆ ∿ ⚙

**Valor 7 · coste 6 · ángulo `autoconocimiento+errores`**

**Qué.** Nova tiene 424 bloques catch vacios: cuando algo suyo revienta, se lo traga y sigue, y hoy no hay ni un dato de cuales de esos sitios disparan de verdad. No hace falta tocar ninguno para enterarse: PowerShell mete TODA excepcion capturada en la variable automatica $Error con su numero de linea, y Nova no la mira jamas. Una vez por minuto lee lo nuevo de $Error, agrupa por linea, lo cuenta en estadisticas como 'pete:<linea>' y en el parte dice la que mas: 'la funcion que abre la biblioteca me ha petado 12 veces esta sesion y no te lo dije'. Y de los 424, uno ya se sabe que muerde hoy, asi que ese se arregla sin esperar a que el contador lo confirme: la lectura de corte.flag, que cuando falla convierte decir 'nova' para salir de la sordina en callarla.

**El dato.** 424 catch completamente vacios de 767 catch totales en assistant.ps1, el 55,3 %; solo 100 escriben algo en el registro (la correccion de la 71 los contaba como 106 lineas con catch+Log; medidas hoy salen 100 ocurrencias de catch...Log). $Error, la variable automatica, no aparece NI UNA vez en las 28.720 lineas: los 6 aciertos del grep son todos $ErrorActionPreference, que ademas vale 'Stop' en la linea 6, o sea que hasta los errores de cmdlet se vuelven terminantes y acaban tambien en $Error. Comprobado en esta misma consola que sirve: tres excepciones tragadas por catch{} dejaron capturados=3 en $Error, con linea e identificador, y $MaximumErrorCount vale 256. El contador 'error' que si existe solo se pone en 3 sitios (26126 dictado vacio, 27010 cancelado, 27712 timeout de opencode) y suma 80 en 14 dias: no cuenta nada de lo que se traga. Reparto de los vacios: 64 viven en el bucle principal (lineas 26756-28720) y 36 dentro de Invoke-FastCommand (14183-16729), la funcion de 2.546 lineas que ejecuta las ordenes. El que ya puede morder: assistant.ps1:27119 lee corte.flag con ReadAllText crudo dentro de un catch vacio, y ese fichero lo escribe el worker con la MISMA funcion escribir() que ya ha fallado 36 veces con 'Acceso denegado'; si esa lectura falla la palabra queda vacia y Resolve-Corte (18298-18312) la resuelve como 'corta-y-calla'. En el bucle hay 15 lecturas con ReadAllText (38 en todo el fichero) y FileShare::Delete se usa UNA sola vez en las 28.720 lineas: en 27468, la lectura del parcial, que es la que esta bien hecha y hay que copiar.

**Dónde se comprobó.** Medido hoy sobre assistant.ps1 (28.720 lineas): grep -cE 'catch *\{ *\}' -> 424; grep -oE '\bcatch\b' | wc -l -> 767; grep -oE 'catch[^}]*Log' | wc -l -> 100; grep -n '\$Error' -> 6 lineas, todas $ErrorActionPreference; awk del bucle 26756-28720 -> 64 vacios y 15 ReadAllText; awk de 14183-16729 -> 36 vacios; grep -c 'FileShare\]::Delete' -> 1. Sitios leidos: assistant.ps1:27119 (corte.flag con ReadAllText en catch vacio), 27468 (el FileStream+FileShare.Delete que SI esta bien hecho), 18298-18312 (Resolve-Corte, donde la palabra vacia acaba en 'corta-y-calla'), 3009 (Add-Estadistica), 11406-11410 (el tic de 30 s de Watch-Entorno). grep -n "Add-Estadistica 'error'" -> 26126, 27010, 27712.

**Cómo se hace.** Una funcion Read-Petes con $script:petesVistos (cuantos habia la ultima vez) que recorra lo nuevo de $Error[0..($Error.Count-$vistos-1)], saque $_.InvocationInfo.ScriptLineNumber y llame a Add-Estadistica "pete:$linea" (Add-Estadistica esta en 3009). Se engancha donde ya esta el tic de 30 s de Watch-Entorno (assistant.ps1:11406-11410), junto a Add-ArranqueOido. Se sube $MaximumErrorCount para que un arranque ruidoso no tire la cola. En el registro, una sola linea por sitio y por sesion: la misma guarda que ya funciona en el worker con MAX_AVISOS_ESCRIBIR, que es lo que evita convertir el log en el ruido que los catch vacios evitaban. $Error se lee, nunca se limpia: limpiarlo romperia a cualquiera que lo mire despues. Y sin esperar a que el contador lo diga, se arregla el sitio que ya se sabe: la lectura de corte.flag (27119) pasa al mismo FileStream con FileShare.ReadWrite -bor FileShare.Delete que usa la lectura del parcial en 27468. No hay que editar los 424 catch uno a uno: $Error cubre los 767 sin tocar ninguno.

### 81. Abrir un juego es lo unico que Nova nunca comprueba ∿

**Valor 7 · coste 6 · ángulo `muertas`**

**Qué.** Nova apunta cada app que manda abrir y mira diez segundos despues si aparecio de verdad; si no, lo dice. A los juegos los deja fuera a proposito, y son justo las aperturas que mas fallan. Ella ya sabe detectar que un juego ha arrancado -lo hace todos los dias para ponerte el perfil de juego-, pero ese detector no esta conectado con la orden que pidio abrirlo. La idea es unir las dos mitades que ya existen: apuntar el juego pedido y, si el detector no lo ve en un plazo, decirlo en vez de dar por hecho que se abrio.

**El dato.** En 17 dias hay 86 ordenes de 'abrir', 15 de ellas de un juego en Steam. SILENT BREATH se mando abrir 5 veces el 11/09 (15:24, 17:33, 18:10, 19:21, 20:15; dos de ellas contestando 'si' a una pregunta de Nova) y el detector de juegos NO lo vio arrancar ni una sola vez. Little Nightmares: 7 ordenes, 3 arranques vistos. Outlast: 2 ordenes, 1 arranque. Que braya repita la misma orden cinco veces en cinco horas es la firma de que no pasaba nada. El detector si funciona: ha visto entrar 11 juegos distintos. Y la comprobacion general tampoco cubre esto: Test-EfectoAccion solo tiene tres condiciones (volumenPct, brillo y cerrarApp) para los 163 kinds distintos que produce el parser, y el contador 'no-surtio-efecto' vale cero en 14 dias.

**Dónde se comprobó.** assistant.ps1:14673 -> if (-not $esJuego) { [void](Add-AperturaPendiente $comoSeLlama) }; assistant.ps1:26325 el comentario "SOLO APPS, NO JUEGOS"; assistant.ps1:26332 (Add-AperturaPendiente) y :26344 (Test-AperturasPendientes). assistant.ps1:6474 Test-EfectoAccion, con sus tres unicos '$a.kind -eq'. Los 5/0, 7/3 y 2/1 salen de contar en assistant.log las lineas 'abrir <juego> en Steam' contra las lineas "perfil 'juego' aplicado al entrar en <juego>".

**Cómo se hace.** Quitar la exclusion de 14673 y darle a Add-AperturaPendiente una rama de juego: en vez de vigilar un nombre de proceso, apuntar el juego pedido en una lista y que Test-AperturasPendientes (26344) la contraste con $script:juegoActivo y $script:juegoExe, que es lo que ya alimenta el detector de "perfil 'juego' aplicado al entrar en X". El plazo no puede ser los 10 s de las apps: se aprende del propio historico, midiendo por juego cuanto tarda desde la orden hasta que el detector lo ve, y usando su p90.

**Riesgo y guarda.** Decir "no se ha abierto" de un juego que solo tarda mucho, que es exactamente el motivo por el que se excluyeron. Dos guardas. La primera es el plazo aprendido: hasta que un juego no tenga sus propias medidas, no se vigila y Nova se calla, que es el comportamiento de hoy. La segunda es la que ya lleva la funcion: devuelve $false cuando no sabe comprobar, y entonces nadie dice nada. Y si el juego no esta instalado y Steam abre su pagina de tienda, eso cuenta como caso conocido y no como fallo.

> **El verificador corrigió el dato:** Las '86 ordenes de abrir en 17 dias' no las pude reproducir: grep de 'abrir ' en los dos logs da 170 lineas, pero cuenta ecos y confirmaciones de la misma orden, asi que ni confirma ni desmiente el 86. Es un numero decorativo; los que sostienen la idea (5/0 de SILENT BREATH, 7/3 de Little Nightmares, 2/1 de Outlast, 11 juegos vistos, 3 kinds en Test-EfectoAccion) salen todos exactos.

### 82. Diez relojes de 'una vez cada tanto' nacen diciendo 'ya puedes'

**Valor 6 · coste 6 · ángulo `continuidad`**

**Qué.** Las esperas de Nova se miden contra su propio cronometro, que empieza en cero con el proceso. Diez de ellas arrancan directamente en un negativo grande, que significa 'hace muchisimo que no pasa': con 15 arranques al dia, una guarda de 'no repitas esto en 10 minutos' puede dispararse 15 veces en un dia.

**El dato.** 10 variables de sesion arrancan en un negativo de 4 cifras o mas: charlaUltima -600000, precargaEn -600000, climaCheck -3600000, invitadoPropuestoEn -9999999, despertadorSonoEn -9999999, avisoSueltaUltimo -999999, dictadoConfianzaEn -999999, amigoCheck -120000, descargaCheck -120000, mandoRespondioEn -100000. Y otras 67 cuyo nombre acaba en En/Ultimo/Check/Hasta/Desde/Vence/Visto arrancan en 0, -1 o vacio. Contra 15,2 arranques al dia. Ya se arreglo UNO a mano (calladoDia, el 24/09, guardado en habitos.json).

**Dónde se comprobó.** grep -cE '^\$script:[A-Za-z0-9_]+ *= *-[0-9]{4,}' assistant.ps1 -> 10; assistant.ps1:1699, 2078, 9380, 9386, 9689, 11077, 19102, 22559, 22571, 26762. El arreglo hecho a mano: assistant.ps1:13403 (Save-AvisoJuego) y 9171.

**Cómo se hace.** Un tmp/relojes.json con hora de pared por clave, escrito en el Exiting de 21160 y cada pocos minutos, mas un par Get-Reloj/Set-Reloj que al arrancar traduzca la hora guardada a milisegundos de $sw. Las variables entran una a una por lista blanca, no todas de golpe.

**Riesgo y guarda.** Un reloj guardado que deberia olvidarse: si braya reinicia a proposito para que Nova deje de estar callada, restaurar la sordina seria lo contrario de lo que pidio. Guarda: la lista blanca solo admite relojes de 'no repitas' (charla, precarga, propuesta de invitado, aviso de suelta); los de 'estoy callada' se quedan fuera a proposito y con el motivo escrito al lado.

> **El verificador corrigió el dato:** las otras variables con sufijo En/Ultimo/Check/Hasta/Desde/Vence/Visto que arrancan en 0, -1 o vacio son 65, no 67

### 83. Saber si la consola esta en la mano, no solo si alguien toco un boton ∿

**Valor 6 · coste 6 · ángulo `consola`**

**Qué.** Nova tiene un acelerometro y un sensor de orientacion dentro de la consola y hoy no los usa para saber si hay alguien. Con ellos sabria que braya la tiene cogida aunque no haya tocado ningun boton, y soltaria en ese momento los avisos que lleva dias guardando. Y al reves: apoyada boca arriba y quieta, no hay nadie delante. El acelerometro esta APAGADO por una medicion que en esta consola ya no es cierta.

**El dato.** El comentario del codigo dice "GetCurrentReading() tarda 5 s y devuelve null SIEMPRE" y por eso config.json tiene sensores.acelerometro = false. Medido hoy con el mismo camino que usa el codigo (ReportInterval fijado antes de leer): 30 lecturas de 30 NO nulas, la primera en 35 ms (la guarda del codigo corta en 150 ms), media 3,1 ms, maximo 19 ms. El sensor de orientacion contesta "Faceup" en 0-10 ms. Y hace falta: 4.140 lineas "ENTORNO aparcado (no hay nadie...)" entre los dos registros (1.649 de oido-ruido, 1.647 de gmail-lleno, 843 de disco-poco, 1 de correo-manana); 4.106 de ellas estan en assistant.log, que tiene 7.924 lineas: el 52 % del registro es Nova apuntando que no hay nadie. Siete de esos avisos caducaron sin llegar a decirse nunca.

**Dónde se comprobó.** assistant.ps1:20427-20431 (el comentario y el Get-Cfg que lo apaga), assistant.ps1:20452 (la guarda de 150 ms), assistant.ps1:20440 (Watch-Acelerometro), assistant.ps1:12789 (Get-InactividadMin), assistant.ps1:10513 (Test-AvisoAplazable), config.json -> sensores.acelerometro. Conteos: grep -c "ENTORNO aparcado" assistant.log assistant.log.1 (4106 y 34) y grep -h "ENTORNO aparcado" ... | sed 's/.*): //' | sort | uniq -c. Medicion: [Windows.Devices.Sensors.Accelerometer]::GetDefault() y SimpleOrientationSensor, 30 lecturas cronometradas.

**Cómo se hace.** Poner sensores.acelerometro = true y dar a Watch-Acelerometro (20440) un segundo uso ademas del sobresalto: guardar el instante de la ultima variacion que pase del ruido de reposo, y exponerlo como Get-MovimientoMin, hermana de Get-InactividadMin (12789). Test-AvisoAplazable (10513) pasa a mirar el minimo de las dos senales en vez de solo Get-AusenciaMin (12763). La cola de avisos que espera ya existe y ya sabe soltarse cuando vuelve.

**Riesgo y guarda.** Que en otra consola el sensor vuelva a fallar. La guarda de Watch-Acelerometro ya lo apaga para siempre si la primera lectura tarda mas de 150 ms o viene nula; Get-MovimientoMin devolveria -1 = "no lo se", tratado como lo trata Get-InactividadMin: quedarse con lo de siempre, nunca callar a Nova porque fallo una medicion. Y el otro riesgo es al reves: darle por presente porque vibra la mesa. Por eso el umbral sale de su propio reposo y se exige que la senal se repita, no un pico suelto.

> **El verificador corrigió el dato:** 30 lecturas de 30 NO nulas, si; pero la primera tardo 27,7 ms (no 35), la media 15,79 ms (no 3,1) y el maximo 27,71 ms (no 19). Orientacion: Faceup en 3,11 ms. Conteos: 4107+34 = 4141 aparcadas (decia 4140), desglose 1649 oido-ruido / 1648 gmail-lleno (decia 1647) / 843 disco-poco / 1 correo-manana; 7 caducadas sin decirse, exacto; assistant.log tiene 8045 lineas, no 7924 (sigue creciendo), o sea 51 %.

### 84. Un solo estado de red, en vez de dieciseis plazos sueltos ∿

**Valor 6 · coste 6 · ángulo `red`**

**Qué.** Hoy cada pieza descubre por su cuenta que no hay red y paga su propio plazo: el clima 4 s, la ficha de Steam 3 s, YouTube 6 s, los amigos 10 s, el correo 25 y 30, la API 40. Que haya un solo sitio donde se apunta cuando fue la ultima vez que algo de fuera contesto y cuantos fallos seguidos lleva. Las llamadas de FONDO lo consultan y se saltan si lo de fuera esta caido; las que pidio braya se intentan igual pero con el plazo corto.

**El dato.** 16 plazos de red escritos a mano frente a 2 que Nova se calcula sola. En PowerShell: 4 TimeoutSec (3 s tienda de Steam, 6 s YouTube, 4 s ip-api, 4 s open-meteo) mas AmigoRedMs 10.000, correo 25.000 y correo de la manana 30.000. En Python: 9 (connect 5,0 y 2,0; y 30, 40, 10, 30, 120, 20, 120, 180). Los dos adaptativos son Get-VozPlazoMs y el tope de la nube. Y grep de Test-Connection, NetworkAvailability, Test-Red, hayRed y sinRed sobre assistant.ps1, charla_worker.py, wake_vosk.py y nova_ui.cs: CERO resultados. No existe ninguna funcion que sepa si hay red.

**Dónde se comprobó.** assistant.ps1:1323, 14112, 19128, 19144, 9711 ($AmigoRedMs), 6733 (Invoke-CorreoScript), 12388 (correo de la manana); charla_worker.py:58, 401, 518, 817, 842, 1046, 1116, 1169, 1226; los dos adaptativos en assistant.ps1:2426 (Get-VozPlazoMs) y 2581 (Get-FraseNubeTiempo).

**Cómo se hace.** Dos variables en assistant.ps1 ($script:redUltimoOk y $script:redFallosSeguidos) que tocan las siete llamadas de PowerShell al entrar y al salir, y un json de una linea en tmp\ que charla_worker.py lee y escribe (ya comparten esa carpeta). Nada residente: dos enteros y cincuenta bytes en disco.

**Riesgo y guarda.** Que un servicio caido (Steam de mantenimiento) haga creer que no hay red y apague lo demas. Guarda: el estado solo pasa a "sin red" con fallos de DOS servicios DISTINTOS seguidos, cualquier exito lo borra al instante, y lo que braya pide en voz alta no se bloquea nunca, solo se le acorta el plazo.

> **El verificador corrigió el dato:** El recuento es exacto, pero la idea se vende peor informada de lo que es: 'cada pieza descubre por su cuenta que no hay red y paga su propio plazo' se queda corto, porque DOS piezas ya tienen su propio cortafuegos por servicio -Update-JuegosDosUno con $script:juegosDosPausaHasta (3 fallos, 10 min de espera, assistant.ps1:1345-1350) y la API con api_rota_hasta (charla_worker.py:148, 455-460)-. Lo que no existe es el estado COMPARTIDO, que es lo que propone. Que se escriba reusando esos dos patrones y no al lado de ellos. Y ojo con el titulo: el 'como' no unifica ni uno solo de los 16 plazos, solo anade una puerta; lo de 'el plazo corto' para lo que pide braya esta sin definir y dos personas lo pondrian distinto.

### 85. El cuaderno de activaciones que solo abre el borrador ⬆ ∿

**Valor 6 · coste 6 · ángulo `muertas`**

**Qué.** Cada vez que Nova se despierta al oir su nombre apunta una linea con 16 datos: la confianza con la que oyo el nombre, el umbral que estaba en vigor, la rafaga, el pico, la ganancia, si sonaban los altavoces, si la voz era ajena, cuanto espero y en que acabo. Es el unico sitio del proyecto donde queda escrito si despertarse valio la pena. Nadie lo lee. La idea es que el motor que ya decide cosas sola (Test-RevisionPropia) lea ese cuaderno y mueva por su cuenta la confianza minima, que hoy es un numero escrito a mano en config.json.

**El dato.** pruebas/audio/uso/activaciones.jsonl tiene 107 lineas de 6 dias (20 al 25/09). Desenlaces: 71 acabaron en orden, 27 en nada, 5 pisadas, 4 sin dictado. O sea que 36 de 107 (34 %) fueron despertarse para nada, y esas 27 'nada' suman 307 segundos de microfono abierto sin que saliera nada. Por tramos de confianza: entre 0,55 y 0,70 hay 8 activaciones y solo 4 dieron orden (50 %); por encima de 0,95 hay 61 y dan 46 (75 %). En todo el proyecto el fichero aparece 3 veces fuera de los bancos: quien lo escribe (wake_vosk.py:2374) y quien lo BORRA (assistant.ps1:2266, dentro de Invoke-Olvido).

**Dónde se comprobó.** grep -rn "activaciones.jsonl" --include=*.ps1 --include=*.py --include=*.cs .  -> wake_vosk.py:2374 escribe, assistant.ps1:2266 borra, y dos bancos (tools/probar-escucha.py, tools/probar-olvido.ps1). Ni un lector. Los recuentos salen de leer el jsonl y agrupar por 'desenlace' y por tramo de 'conf'.

**Cómo se hace.** Un caso nuevo en Test-RevisionPropia (assistant.ps1:12096), con la misma forma que los cuatro que ya hay: leer activaciones.jsonl, quedarse con los dias que pasen Test-DiaCuenta, y si un tramo de confianza tiene al menos $DecisionMinIntentos muestras y su tasa de 'orden' esta por debajo del minimo, subir escucha.confianzaMinima al borde de ese tramo. Se guarda con Save-DecisionPropia, que es lo que deja deshacerlo hablando ("deshaz lo que has cambiado") y lo que escribe auto.ultimaDecision.

**Riesgo y guarda.** Subir el umbral y que Nova deje de oir su nombre, que es lo contrario de la meta del 100 %. Las guardas ya estan escritas y son las que usan los otros cuatro casos: Test-DatosRepartidos (que no decida por una tarde rara), Test-DecisionSolida, el minimo de 20 intentos, una sola decision al dia, y Save-DecisionPropia para que braya lo devuelva con la voz. Ademas el boton y el mando siguen abriendo el microfono pase lo que pase con el umbral.

> **El verificador corrigió el dato:** El tramo alto depende de donde se ponga el borde: contando conf > 0,95 estricto salen 57 activaciones y 42 ordenes (74 %), no 61 y 46. Con conf >= 0,95 salen los 61/46 que cita. Misma conclusion, borde distinto.

### 86. La franja en la que nunca estas, calculada por ella misma ∿

**Valor 6 · coste 6 · ángulo `tiempo`**

**Qué.** El dia de braya empieza a las 5 porque alguien lo escribio, y esta escrito en cuatro sitios; el final del silencio nocturno es un 8 fijo mientras el principio SI se aprende. Que Nova calcule su franja muerta -la racha mas larga de horas con cero actividad- y de ahi salgan las dos cosas, desde un unico sitio.

**El dato.** AddHours(-5) aparece a mano en 4 lineas de assistant.ps1 (12655, 12940, 12958 y la propia Get-DiaJuego en 13355): tres de las cuatro no llaman a la funcion que existe justo para eso, y ese desfase ya costo un fallo el 23/09 segun el comentario del propio archivo. config.json trae entorno.nocheHasta = 8 fijo. Los datos: 0 de 714 ordenes entre las 02:00 y las 08:59 en 13 dias, y solo 6 de 3.557 gestos en esa misma franja en 15 dias. Fuera de la madrugada, la primera orden mas temprana de todo el registro es a las 09:25 (19/09).

**Dónde se comprobó.** assistant.ps1:12655, 12940, 12958 y 13355; config.json (entorno.nocheHasta). Conteo por hora de las 714 lineas "[escucha] dictado: '...'" y de tmp/gestos.log.

**Cómo se hace.** Get-FranjaMuerta: la racha mas larga de horas consecutivas con 0 ordenes en 14 dias (hoy, 02:00-08:59). De ahi salen el corte del dia = su punto medio (hoy ~05:00, o sea HOY NO CAMBIA NADA, que es justo lo que la hace segura) y el fin del silencio = su final (hoy las 09:00 en vez de las 08:00). Las 4 lineas del AddHours(-5) pasan a llamar a Get-DiaJuego, y Get-DiaJuego a Get-FranjaMuerta.

**Riesgo y guarda.** Que un dia madrugue y la franja se encoja, moviendo el corte del dia en mitad de las cuentas. Guardas: exigir una racha de 4 horas como minimo y 3 dias con datos; si no la hay, se queda el 5 y el 8 de siempre; y el corte solo se recalcula al cambiar de dia, nunca a media sesion.

> **El verificador corrigió el dato:** Los gestos son 3.557 en 16 dias distintos, no 15 (los 6 de la franja muerta si son exactos: 1 a las 03, 1 a las 05, 1 a las 06 y 3 a las 08). Y el punto medio de 02:00-08:59 son las 05:30, no las 05:00: solo 'hoy no cambia nada' si se trunca a la hora en punto, cosa que el 'como' tiene que decir. Aviso extra: mover el corte del dia reetiqueta dias ya guardados en habitos.fin y juegos.json, que se escribieron con el -5.

### 87. Las correcciones de oído se ganan del uso, no se escriben a mano ⬆ ∿

**Valor 6 · coste 7 · ángulo `aprender`**

**Qué.** commands.json lleva una lista de correcciones fonéticas escrita a mano que ya no tiene que ver con lo que Nova oye de verdad. La idea es que Nova se apunte ella los cambios de palabra que ve confirmados: cuando la misma palabra mal oída aparece dos veces en el sitio del verbo y las dos veces se acaba haciendo lo mismo, entra en la lista. Se añade, nunca se poda lo que puso braya.

**El dato.** Hay 110 correcciones escritas a mano en commands.json. De esas 110, solo 9 han aparecido alguna vez en algo que Nova oyera en 14 días: 'blog de notas', 'descagando', 'este estado es cargando', 'painterest', 'programan', 'sirra', 'sting', 'team' y 'temporizado'. Las otras 101 no se han usado nunca. Y las que SÍ pasaron no están: contando las 560 órdenes reales, salen 12 sustituciones distintas en la cabeza de la frase ('su'/'tuvo'/'subo' por 'sube', 'haben'/'haber'/'here' por 'abre', 'seattle'/'see'/'si es' por 'cierra'), y 'si es' por 'cierra' aparece DOS veces con Vosk de testigo, más otras dos en el corpus completo. La tabla $VERBOS_OIDOS tiene 6 entradas, también a mano.

**Dónde se comprobó.** commands.json (110 claves en 'correcciones', contadas con python) cruzadas contra los 941 dictados de assistant.log + assistant.log.1: 9 vivas, 101 nunca vistas. Los testigos: pruebas/audio/uso/registro.jsonl, filas donde 'vosk' empieza por verbo y 'entregado' no (17 de 560). La tabla fija: assistant.ps1:359.

**Cómo se hace.** Fichero nuevo memoria/oido-aprendido.json con {malo: {bueno, testigos, visto}}. Dos fuentes lo alimentan, las dos ya disponibles: el par de repetición de la primera idea y la fila de registro.jsonl donde Vosk trae el verbo. Solo se promueve a Repair-Verb -que es donde vive $VERBOS_OIDOS, assistant.ps1:400- cuando hay 2 testigos independientes, la palabra mala no es una palabra que Nova ya conozca (ni app, ni sitio, ni corrección, ni verbo) y no está a menos de 3 ediciones de una que sí, que es el mismo filtro que ya aplica Find-Generalizacion contra 'ajutos'. El número de testigos sube solo si esa sustitución ya provocó una corrección alguna vez.

**Riesgo y guarda.** Atar una orden buena a un fallo del micro, que es exactamente lo que pasó con 'ajutos'. Además de los filtros de arriba, cada entrada aprendida se puede quitar por voz y se cae sola si la orden que produce acaba en una corrección, porque entonces pierde su testigo. El rendimiento es corto -una o dos entradas en 14 días- pero permanente y sin escribir nada a mano, que es lo que braya pide.

### 88. La tabla de lo que más se le atraganta tiene hoy tres filas y ninguna es una orden ⬆

**Valor 6 · coste 7 · ángulo `contadores`**

**Qué.** La tabla que existe para que braya vea qué enseñarle está alimentada por dos colas cortas y por texto exacto, y por eso nunca ve un fallo de verdad. Que 'error' deje de entrar (su detalle es una etiqueta interna, no algo que braya dijera) y que las frases se agrupen por parecido con las funciones de distancia que Nova ya tiene, en vez de por texto idéntico.

**El dato.** Las tres filas de hoy en memoria\estadisticas.md son: «avísame cuando la descarga de Steam termino» (llega a 2 solo porque la tilde hizo que la lista de descartes guardara dos copias), «dictado vacio» (que es la etiqueta del contador 'error', no una frase de braya, y la tabla le dice que la enseñe) y «maar die dog komen beheer» (holandés de un vídeo de fondo). Y no es mala suerte: medido, 'recientes' va de 2026-09-25 23:16 a 23:54, TREINTA Y OCHO MINUTOS; y la lista de descartes borra la entrada anterior idéntica al reañadir, así que una frase no puede contar más de 1 por ahí. En los datos completos de uso hay 34 frases distintas que acabaron en nada con su texto y CERO repetidas exactas: por texto exacto no hay nada que encontrar.

**Dónde se comprobó.** assistant.ps1:3279 (Get-Atragantos), 3028 (la línea que borra el descarte idéntico), 3297 (recorre 'recientes', 40 filas); memoria/estadisticas.md:110-112; cruce de pruebas/audio/uso/destinos.jsonl con registro.jsonl → 34 frases en nada, 34 distintas

**Cómo se hace.** En Get-Atragantos (3279): quitar 'error' del switch de etiquetas y agrupar con Get-Distancia / Get-DistanciaFon (assistant.ps1:694 y 820, ya escritas y con banco) en vez de con ConvertTo-Plain a secas: dos frases caen en el mismo grupo si la distancia normalizada es pequeña. La tabla se construye igual.

**Riesgo y guarda.** Juntar dos órdenes distintas que suenan parecido y enseñarle a braya un grupo falso. La guarda: el grupo enseña la frase MÁS repetida como cabecera y lista las otras debajo, así braya ve siempre el texto crudo y puede descartar el grupo de un vistazo; y solo se agrupan frases que acabaron en nada, nunca las que salieron bien.

> **El verificador corrigió el dato:** No son 34 frases distintas: cruzando destinos.jsonl salen 47 desenlaces en nada con texto, 39 distintos, y quedandose con descarte+ruido y frases de mas de una palabra (que es lo que filtra Get-Atragantos) son 29, todas distintas. La conclusion aguanta (por texto exacto no hay nada), pero el numero es 29, no 34.

### 89. Aprender qué palabras eran la orden, no la frase entera ⬆ ∿

**Valor 6 · coste 9 · ángulo `aprender`**

**Qué.** Lo que Nova aprende es la frase completa, letra por letra, y braya no repite frases: repite intenciones con palabras distintas. Por eso lo aprendido no sirve casi nunca. La idea es que cuando la nube devuelva el MISMO destino desde dos frases distintas, Nova se quede con las palabras que las dos comparten y las use como firma de esa intención.

**El dato.** En 14 días la nube tradujo 58 frases. 24 de esas llamadas cayeron en un destino que la nube YA había producido antes: 'lee la pantalla' 3 veces, 'cierra todos los programas' 3, 'abre ajustes' 3, 'a mitad de pantalla' 3, y seis destinos más repetidos dos veces. Ninguna de las frases se repitió. Y el resultado del aprendizaje actual: 21 traducciones aprendidas, 1 usada en toda la vida ('aprendida' vale 1 en memoria/estadisticas.json frente a 'traducida' 42); las 6 que quedan hoy en traducciones.json tienen todas usos: 0. Las palabras comunes existen y son buenas en 5 de los 10 destinos repetidos: 'lee la pantalla' = {mira, pantalla} sobre 'Mira mi pantalla y encuentra otra solución', 'Mira la pantalla y dime qué ves' y 'Mira la pantalla tú mismo y dime qué está pasando'. Y las 22 líneas 'no aprendo ... frase larga' del log son justo estas frases, tiradas a la basura.

**Dónde se comprobó.** grep -h 'traduccion propuesta:' assistant.log assistant.log.1 (58 líneas) agrupadas por destino; memoria/estadisticas.json sumando los 14 días ('traducida' 42, 'aprendida' 1); traducciones.json (6 entradas, todas usos 0); assistant.ps1:23612 (el filtro que descarta las frases largas) y sus 22 disparos en el log.

**Cómo se hace.** Fichero memoria/firmas.json. En assistant.ps1:23612, donde hoy se dice 'no aprendo', apuntar en su lugar {destino, palabras de contenido} en una lista de candidatos. Cuando un destino junte 2 candidatos, guardar la intersección como firma. En Process-Texto, antes de mandar nada a la nube, probar las firmas: si todas las palabras de una firma están en lo dicho, se propone ese destino con el mismo trato que una receta -confirmando las primeras veces, recetas.confirmarVeces, y directo después-. El número de palabras de la firma no se fija: es el que dé la intersección, con mínimo 2, y una firma que sea subconjunto de otra se descarta por ambigua.

**Riesgo y guarda.** Que una firma corta se coma frases que no van por ahí ('steam' sola apuntaría a 'abre steam'). Por eso el mínimo de dos palabras, que deja fuera las 5 firmas de una sola palabra de los datos medidos, y por eso se confirma las primeras veces en vez de ejecutar. Sobre los datos reales esto habría ahorrado 3 llamadas a la nube de 58: poco, pero son 3 esperas de 5 a 8 s y crece solo con el uso.

## C. Las pequeñas (valor 5 o menos) — 32 ideas

### 90. Lo que dice otra persona se descarta, y acto seguido se escribe entero en el registro

**Valor 5 · coste 2 · ángulo `privacidad`**

**Qué.** Cuando la voz no es la de braya, Nova ya hace lo correcto tres veces: no guarda el wav, no lo manda al agente y no aprende nada. Pero justo despues escribe la frase completa en assistant.log. Pasaria a apuntar solo cuanto duraba y cuantas palabras eran, sin el texto, que es lo unico que hace falta para medir.

**El dato.** 11 lineas de assistant.log y assistant.log.1 son conversacion de otra persona guardada literal, 729 caracteres en total, la mas larga de 241. Por ejemplo la del 13/09 16:15:26 con una charla entera sobre un brazalete y ChatGPT, o la del 25/09 23:48:48. Todas salen de la misma linea de codigo. El contraste es lo que lo hace un fallo y no una decision: la misma deteccion de voz ajena salta 13 veces mas en el lado del oido (uso: no lo guardo, esa voz no es la tuya) y ahi SI se calla, no escribe el texto.

**Dónde se comprobó.** assistant.ps1:26062 -> Log "CHARLA descartada ($porque, no llega al agente): '$text'"; cat assistant.log assistant.log.1 | grep -c 'CHARLA descartada (voz que no es la tuya' -> 11; los mismos 11 recortados y contados -> 729 caracteres; wake_vosk.py:2421 es el sitio que si se calla

**Cómo se hace.** Una linea en assistant.ps1:26062. Donde hoy va '$text', cuando $esAjena sea cierto, poner el numero de palabras y los caracteres: "CHARLA descartada (voz que no es la tuya, no llega al agente): $($text.Split(' ').Count) palabras". Cuando el motivo sea 'charla' y la voz SI sea la suya, se deja como esta, que ahi el texto es de braya y sirve para depurar. Ampliar tools\probar-callarse-voz-ajena.ps1 para que compruebe que el texto no sale.

**Riesgo y guarda.** Perder informacion para depurar por que se descarto. No se pierde: el conteo de palabras y el motivo siguen, y el caso que de verdad importa depurar -la voz que SI es la suya y se descarto igual- conserva el texto entero.

> **El verificador corrigió el dato:** El banco que dice ampliar no existe: tools\probar-callarse-voz-ajena.ps1 no esta (solo hay tmp\V1-callarse-voz-ajena.py, del 21/09). Hay que crearlo de cero.

### 91. Solo puede mirar la reacción de un aviso a la vez, y el siguiente le pisa la medición

**Valor 5 · coste 2 · ángulo `iniciativa`**

**Qué.** Cuando Nova dice algo se queda mirando cinco minutos a ver si braya le habla; de ahí sale la espera aprendida. Pero guarda un único $script:avisoMirar, y el siguiente aviso lo pisa: el primero se queda sin apuntar ni 'sirvió' ni 'nada'. El comentario dice que es a propósito para no atribuir mal la reacción, y eso está bien, pero perder la muestra entera no hace falta: se pueden guardar los dos y apuntar el 'sirvió' al que llegó antes, o descartar solo los empatados.

**El dato.** 16 de los 96 avisos tienen otro aviso detrás dentro de los 5 minutos de la ventana, o sea que una de cada seis mediciones se pierde. Los huecos medidos: 1 s (19/09 09:20:33 bateria-llena y 09:20:34 correo-manana), 14, 15, 15, 33, 50, 54, 60, 77, 78, 89, 209, 239, 240, 266, 309 s. Y eso con solo 11 muestras guardadas en total: perder 16 en este régimen es perder más de lo que se tiene.

**Dónde se comprobó.** assistant.ps1:10229 ($script:avisoMirar = $null), 11039 (donde se pisa), 24684-24686 (donde se apunta 'sirvió'), 27042-27044 (donde se apunta 'nada'). Huecos calculados ordenando las líneas 'ENTORNO (' de assistant.log + assistant.log.1.

**Cómo se hace.** Cambiar $script:avisoMirar por una lista pequeña de @{clave; hasta}. Al hablar braya, se apunta 'sirvió' al más antiguo que siga vivo y se vacía la lista (una sola frase no puede haber contestado a tres avisos). En el bucle, los que se pasan de hora se apuntan 'nada' y salen. Es la misma lógica que ya tiene $script:entornoAvisos con su ventana.

**Riesgo y guarda.** Atribuir a un aviso la reacción que provocó otro, que es lo que el comentario actual quiere evitar. La guarda es apuntar el 'sirvió' solo al más antiguo y tirar el resto: se pierde el empate, pero no la muestra del que llevaba más rato esperando.

> **El verificador corrigió el dato:** 16 pares de 97 avisos, pero solo 10 son dos avisos que SUENAN. Y el ultimo hueco de la lista es 271 s, no 309 s: 1, 14, 15, 15, 33, 50, 54, 60, 77, 78, 89, 209, 239, 240, 266, 271.

### 92. Decir que esta sin red, una vez ∿

**Valor 5 · coste 2 · ángulo `red`**

**Qué.** Cuando el estado compartido dice "sin red", Nova lo dice una vez con la voz y la capsula lo ensena, en vez de contestar a medias sin explicar por que. Al volver la red, lo dice tambien, corto. Es un aviso, no un modo: caduca solo.

**El dato.** En 16 dias el registro tiene 51 fallos de red o de servicio: 43 del resumen del diario, 5 del clima (cuatro "No se puede resolver el nombre remoto: 'api.open-meteo.com'" el 11/09 y uno de tiempo de espera el 12/09) y 3 de "voz online: sin respuesta en 8 s". braya no ha oido NI UNO: buscando en los dos registros las frases que Nova diria si lo dijera -"No pude preguntarle a Steam", "No tengo el tiempo a mano", "no pude consultarlo", "No pude preguntarle al modelo"- salen CERO apariciones.

**Dónde se comprobó.** grep -c "no pude resumir" (43), "clima: no disponible" (5, con el texto del error DNS en assistant.log.1 del 11/09 04:17:06, 11:18:13, 13:39:59, 14:54:44), "voz online: sin respuesta" (3); grep de las cuatro frases habladas sobre assistant.log y assistant.log.1: 0. La linea que las diria esta en assistant.ps1:5193.

**Cómo se hace.** Send-AvisoEntorno con la clave 'sin-red', disparado por el contador de la idea anterior. La maquinaria de avisos ya existe con su nivel, su plazo y su "no repetir lo mismo": son cuatro lineas.

**Riesgo y guarda.** Cansar con avisos, que es justo lo que braya odia. Guardas: Send-AvisoEntorno ya se calla entero con un juego delante y ya tiene el filtro de no repetir; y el aviso de "ya volvio" solo sale si el de ida llego a decirse de verdad.

> **El verificador corrigió el dato:** 51 -> 79 fallos hoy (71 + 5 + 3). Y hay que tirar media prueba: 'buscando las frases que Nova diria... salen CERO apariciones' no demuestra nada, porque Say (17906) NO registra el texto de lo que dice -el registro solo guarda lo hablado en casos sueltos como 'charla dice:' y los 'ENTORNO (clave, nivel): texto'-. Esas frases no saldrian en el log aunque braya las hubiera oido veinte veces. Lo que si prueba el punto es la ausencia de clave de red en Send-AvisoEntorno, que es comprobable.

### 93. Que aprenda que fichero no la deja cambiarlo de golpe, en vez de chocar en cada palabra ∿

**Valor 5 · coste 2 · ángulo `errores`**

**Qué.** Un contador por NOMBRE de fichero dentro del worker de escucha: al tercer 'Acceso denegado' del mismo fichero en la misma sesion, ese fichero pasa a escritura directa el resto de la sesion y se anota una sola vez. Hoy paga la excepcion, el aviso y el reintento en cada palabra que oye, y encima el arreglo que se dio por bueno el 22/09 no lo arreglo.

**El dato.** 36 fallos 'escritura atomica fallida ... [WinError 5] Acceso denegado' en siete dias distintos: 20 de ui-nivel.txt, 14 de dictado-parcial.txt y 2 de escucha-estado.txt. Lo importante: el 22/09 se dio por arreglado (se anadio FileShare.Delete en los dos lectores) y DESPUES hay 12 mas: 2 el 23/09, 2 el 24/09 y OCHO el 25/09, el dia con mas fallos de todo el registro despues del arreglo. Y el contador esta topado a 50 por proceso, asi que 36 es un suelo, no una cuenta.

**Dónde se comprobó.** wake_vosk.py:2674-2696 (la funcion escribir), wake_vosk.py:2666 (MAX_AVISOS_ESCRIBIR = 50), nova_ui.cs:3596 y assistant.ps1:27468 (el arreglo del 22/09 con FileShare.Delete). Contado con: grep 'escritura atomica fallida' assistant.log.1 assistant.log | sed -E 's/^([0-9-]+).*en ([a-z-]+\.txt).*/\1 \2/' | sort | uniq -c

**Cómo se hace.** En wake_vosk.py, junto a _avisos_escribir: un dict _fallos_por_fichero. En el except de escribir() se suma por os.path.basename(ruta); si llega a 3, se mete ese nombre en un set _directo y la proxima llamada se salta el .tmp + os.replace y escribe directo, anotandolo una vez. Diez lineas, sin tocar nada mas.

**Riesgo y guarda.** Perder la atomicidad justo en el fichero por el que sale la orden y leer una orden a medias. Por eso el umbral son tres fallos del MISMO fichero y solo dura la sesion: al siguiente arranque vuelve a intentarlo atomico. Y ahora mismo ya se esta escribiendo directo en esos 36 casos, asi que no se pierde nada que no se pierda ya; lo que se quita es el coste y el ruido.

### 94. Dos de las cinco lineas de 'temas de los que suele hablar' dicen lo mismo

**Valor 3 · coste 2 · ángulo `charla`**

**Qué.** En el prompt de cada charla viajan los cinco temas mas contados. Hoy el primero y el quinto son el mismo tema escrito en singular y en plural, asi que una de las cinco plazas esta gastada y el tema que se queda fuera es real. Juntar los temas por su raiz, que es una funcion que ya esta en ese mismo fichero.

**El dato.** Los 30 temas del cerebro estan justo en el tope (MAX_TEMAS = 30), asi que cada tema nuevo echa a otro, y 14 de los 30 estan en 2, el suelo. Los cinco que van al prompt hoy son: videojuegos (60), comunicacion (23), clarificacion (10), steam (10) y videojuego (10). Juntandolos con raiz() quedaria videojuegos/videojuego (70) y la plaza libre la ocuparia roblox (6). Pasados los 30 temas por raiz() salen 29 grupos: la unica pareja que se junta es justo esa, y esta en el prompt dos veces.

**Dónde se comprobó.** charla_memoria.py:694 (_tema), :431 (los 5 temas que se meten en contexto), :110 (raiz, ya usada en olvidar en la linea 749), :47 (MAX_TEMAS = 30); memoria\cerebro\cerebro.json, campo 'temas'

**Cómo se hace.** _tema guarda cada tema bajo una clave de raices (frozenset de raiz() de sus palabras) y conserva como nombre visible el texto que mas veces se escribio. Al cargar, se juntan los que ya estan guardados, igual que repasar_estilo repasa el estilo viejo.

**Riesgo y guarda.** Juntar dos temas que no son el mismo: raiz() es un corte de sufijos y puede pegar palabras distintas. Guardas: solo se juntan si comparten TODAS las raices (no una), el nombre que queda es el mas escrito, y el numero de juntados se dice al arrancar como ya se hace con el estilo, asi que si junta de mas se ve el primer dia.

### 95. Nova no sabe qué versión de sí misma está corriendo

**Valor 3 · coste 2 · ángulo `autoconocimiento`**

**Qué.** En 16 días se han hecho 553 commits sobre Nova, unos 35 al día, y ella no tiene forma de saber cuál está ejecutando. Cuando un número suyo empeora, no puede decir desde cuándo. Al arrancar apunta el hash corto de git HEAD más el tamaño y la fecha de assistant.ps1 en la línea 'VoiceAssistant iniciado' y en el día de estadísticas. A partir de ahí la revisión propia puede decir 'los descartes subieron con el cambio de las 19:40, y llevas seis versiones desde entonces'.

**El dato.** 553 commits entre el 10/09 y el 25/09 (contados por día: 19, 37, 54, 27, 19, 12, 29, 67, 53, 18, 21, 32, 39, 28, 67, 31). 259 líneas 'VoiceAssistant iniciado' en assistant.log + assistant.log.1, y ninguna lleva versión: apuntan PID, el trigger y el cerebro, nada más. Búsqueda de marca de versión en los dos registros: 1 coincidencia, y es texto suelto, no una marca.

**Dónde se comprobó.** git log --since=2026-09-10 --pretty=%ad --date=short | sort | uniq -c; assistant.ps1:21154 (la línea de arranque, tal cual se escribe); grep -c 'VoiceAssistant iniciado' sobre los dos logs -> 259

**Cómo se hace.** En assistant.ps1:21154 añadir a la línea que ya se escribe el resultado de (git rev-parse --short HEAD) con un plazo corto, y de respaldo -si no hay git- el tamaño y LastWriteTime de assistant.ps1, que siempre están. Add-Estadistica 'version' con ese valor para que quede el día. Un solo proceso hijo por arranque, fuera del bucle.

**Riesgo y guarda.** Llamar a git en el arranque lo alarga. La guarda: la llamada va con tope de tiempo y con la ruta del ejecutable resuelta una vez; si tarda o falla, se queda el tamaño y la fecha del fichero, que no cuestan nada y sirven igual para distinguir dos versiones.

### 96. Contar como uso lo que de verdad usa el cerebro ∿

**Valor 2 · coste 2 · ángulo `ficheros`**

**Qué.** Cada recuerdo lleva un contador de usos que decide a quién se poda primero. Solo sube cuando Nova contesta con la respuesta guardada tal cual, cosa que solo pueden hacer 4 de los 121 recuerdos. Los otros 117, los que sí entran a diario en el contexto de la charla, se quedan a cero para siempre y la poda los ordena empatados.

**El dato.** En cerebro.json: 119 recuerdos con usos=0, uno con usos=1 y uno con usos=3. De 121 recuerdos, solo 4 son de tipo 'respuesta' (117 son episodio o contado). El único sitio que sube el contador es respuesta_directa, y solo busca entre los de tipo respuesta. La función contexto sí refresca 'usada' de los tres recuerdos que mete en el prompt, pero no toca 'usos'. Y _podar ordena por (prioridad, usos, usada).

**Dónde se comprobó.** charla_memoria.py:399 (r['usos'] += 1, dentro de respuesta_directa, que llama a buscar con tipos={'respuesta'}); charla_memoria.py:416 (contexto: solo r['usada']); charla_memoria.py:767-769 (_podar, clave = prioridad, usos, usada); conteo en python sobre memoria\cerebro\cerebro.json

**Cómo se hace.** En contexto(), subir usos a los recuerdos que de verdad entran en las tres líneas que van al prompt (hits[:3]), no a los seis que devuelve buscar, y guardar. Con eso la poda deja de decidir a ciegas y además aparece un dato que hoy no existe: «este recuerdo te ha servido siete veces», que sirve para el repaso y para contestar qué ha aprendido.

**Riesgo y guarda.** Inflar el contador con recuerdos que entran en el contexto pero que el modelo ni mira. Guarda: solo cuentan los tres que se escriben en el prompt (los que pasan _vale_de_contexto), y el banco comprueba que tras una charla que no usó nada el contador no se movió.

> **El verificador corrigió el dato:** MAX_RECUERDOS = 5000 (charla_memoria.py:43) y hay 121 recuerdos: _podar sale por el if de la linea 762 y NO se ejecuta nunca hoy. Lo que gana el cambio es el dato ('te ha servido siete veces'), no la poda.

### 97. Noventa segundos esperando a que elijas un amigo, sin haber medido nunca cuanto tardas ∿

**Valor 2 · coste 2 · ángulo `numeros-fijos`**

**Qué.** Cuando Nova te lee la lista de amigos conectados deja el microfono esperando 90 segundos. El propio codigo dice que ese numero no esta medido. Y Nova SI tiene medido cuanto tardas en empezar a hablar cuando te deja una ventana abierta: lo usa para la ventana de seguimiento y ahi la corta en 6 segundos. Dos ventanas para la misma persona, una aprendida y otra a ojo.

**El dato.** memoria\habitos.json guarda 30 medidas reales de cuanto tarda braya en arrancar a hablar: mediana 2,26 s, p80 3,25 s, maxima 6,26 s. Get-VentanaSeguimiento usa justo ese p80 y no pasa de 6.000 ms (12.000 en charla). Los 90.000 ms del selector de amigos son 14 veces la espera mas larga que se le ha medido nunca, y ademas es un modo que se queda activo, que es lo que braya dice que no aguanta.

**Dónde se comprobó.** assistant.ps1:9719 ($AmigoEligeMs = 90000, con el comentario 'NO HAY MEDICION -esto se estreno ayer- y se dice'). La medicion existente: Add-RitmoSeguimiento (assistant.ps1:22579) y Get-VentanaSeguimiento (assistant.ps1:22592); datos en memoria\habitos.json campo 'ritmo'.

**Cómo se hace.** Donde se arma el selector se sustituye $AmigoEligeMs por (tiempo real que dura la frase que se acaba de decir) + Get-VentanaSeguimiento. Lo primero ya existe: $script:vozFinReal (assistant.ps1:22563) guarda cuando acaba de verdad la frase que suena. Asi la ventana empieza a contar cuando Nova CALLA, no cuando empieza a hablar, que es el error que obligaba a poner 90 segundos.

**Riesgo y guarda.** Que se cierre mientras braya aun esta mirando la lista y haya que pedirla otra vez. Lo evita que la ventana arranque al terminar la voz -que es lo que hoy no pasa- mas el suelo de 6.000 ms que Get-VentanaSeguimiento ya trae, y el mando sigue valiendo: la regla 7 de la casa pide segunda via y ahi esta.

> **El verificador corrigió el dato:** El ritmo medido es de 'cuanto tarda en EMPEZAR a hablar tras una frase corta', no de 'cuanto tarda en elegir de una lista de diez oida': el suelo de 6.000 ms se esta aplicando a una tarea distinta de la que se midio, y hay que decirlo en el comentario.

### 98. La noche empieza cuando ella aprende y termina a las ocho porque sí ∿

**Valor 5 · coste 3 · ángulo `iniciativa`**

**Qué.** Get-NocheDesde saca la hora de empezar de las costumbres de braya, pero la de terminar sigue siendo un 8 escrito en config.json. A las 08:00:00 clavadas se abre la compuerta y sale lo que hubiera esperando, esté quien esté. Lo honesto no es aprender otra hora: es que el silencio de la mañana se levante cuando alguien toca la consola, que es un dato que Nova ya sabe pedirle a Windows.

**El dato.** La primera actividad de braya, en los 16 días del registro: mediana las 11:32, NUNCA antes de las 08:00 (el más madrugador fue el 22/09 a las 08:00 clavadas) y 9 de los 16 días después de las 10:00 (12:53, 13:57, 15:56, 16:31, 18:44, 20:58, 21:08, 21:33, 10:12). Y cinco de los 96 avisos salieron en el minuto siguiente a las 08:00:00: 20/09 08:00:57, 21/09 08:00:41, 22/09 08:00:25, 23/09 08:00:19 y 08:00:33.

**Dónde se comprobó.** assistant.ps1:10124 ($EntornoNocheHasta = Get-Cfg entorno nocheHasta 8), 10137 Get-NocheDesde (la mitad que sí aprende), 10286-10290 (el cálculo de la noche en Test-PuedoAvisar), 12789 Get-InactividadMin. Horas sacadas de la primera línea de actividad de voz de cada día lógico (corte a las 05:00, el mismo de assistant.ps1:12655) en assistant.log + assistant.log.1.

**Cómo se hace.** En Test-PuedoAvisar, antes de aplicar el silencio de la mañana, mirar Get-InactividadMin: si dice que alguien ha tocado la máquina hace poco, la noche se acabó aunque el reloj diga que no. Si devuelve -1 (no lo sabe), manda el 8 de siempre. No hay hora nueva que inventar ni número que aprender.

**Riesgo y guarda.** Que braya se levante a las 06:00, encienda la consola y le caiga encima la cola entera de la noche. Se evita con lo que ya hay: la cola se junta en UNA frase (Send-AvisoCola) y lo caducado se dice diciendo que es tarde. Y al revés no hay riesgo: si nadie toca nada, la compuerta sigue cerrada más allá de las ocho, que es lo que pasa 15 de cada 16 días.

> **El verificador corrigió el dato:** La mediana de la primera señal es 12:53, no 11:32, contando DICTADO + TOQUE CORTO (n=16); y 10 de los 16 dias despues de las 10:00, no 9. Lo que si sale clavado -y es lo que sostiene la idea- es 'nunca antes de las 08:00' y los cinco avisos de las 08:00:xx.

### 99. Las senales de fallo que Nova se deduce sola y solo lee el borrador ⬆

**Valor 5 · coste 3 · ángulo `muertas`**

**Qué.** Cuando una orden acaba en nada -ruido, descarte, o una frase que se fue a la charla sin ser charla-, Nova lo deduce y lo apunta con su peso: 'alto' si no hizo nada con la frase, 'bajo' si hizo algo que quiza no era. El comentario dice que van con peso "para que quien lo lea los cuente por separado". No los lee nadie. La idea es que el motor que se revisa a si misma los cuente: hoy sus cuatro casos miran solo los contadores de la cascada del oido, y este es el unico sitio donde queda escrito QUE frase fallo y por que.

**El dato.** pruebas/audio/uso/senales-fallo.jsonl tiene 33 lineas de 5 dias (20, 21, 22, 23 y 25/09): 14 'ruido', 14 'no-orden-a-charla' y 5 'descarte'. En todo el proyecto, fuera de dos bancos, el fichero aparece dos veces: quien lo escribe (assistant.ps1:2842, dentro de Write-FalloDeducido) y quien lo BORRA (assistant.ps1:2265, dentro de Invoke-Olvido). Cero lecturas. Y en el mismo periodo Test-RevisionPropia no ha decidido nada: 'auto-ajuste' vale cero en 14 dias y la lista 'decisiones' de estadisticas.json esta vacia.

**Dónde se comprobó.** assistant.ps1:2814 (Write-FalloDeducido), :2842 (la escritura), :2265 (Remove-JsonlDesde dentro de Invoke-Olvido). Comprobado con: grep -rn "senales-fallo" --include=*.ps1 --include=*.py . | grep -v "^./tools/"  -> solo esas lineas mas dos comentarios. El 14/14/5 sale de agrupar el jsonl por el campo 'senal'.

**Cómo se hace.** Una funcion Get-SenalesFallo al lado de Get-FalsasAlarmas (assistant.ps1:2878), con su mismo cache por tamano de fichero. Devuelve, por 'senal' y por dia, cuantas hay de peso alto y cuantas de peso bajo. Dos usos: colgarla del parrafo semanal (assistant.ps1:20488), que hoy sale vacio siempre porque la lista 'decisiones' esta a cero, para que al menos diga de que murieron las ordenes de la semana; y meterla en Get-DecisionEsperando, que es quien dice "tengo una decision esperando", para que la senal que domine tenga nombre.

**Riesgo y guarda.** Contar mal y dar un porcentaje imposible, que es la piedra con la que ya tropezo el contador de falsas alarmas (llego a decir 489 %). La guarda esta escrita en el propio fichero: los pesos 'alto' y 'bajo' no se suman nunca, se cuentan por separado, y solo se habla de los dias que pasen Test-DiaCuenta, igual que hace Get-FalsasAlarmas desde el 20/09.

### 100. El 44 % del diario de gestos es ruido que ningún lector mira, y la poda va a tirar lo bueno ∿

**Valor 5 · coste 3 · ángulo `capsula`**

**Qué.** Tres gestos (escucho, lotengo, atencion) se escriben línea a línea y luego los DOS únicos lectores los saltan a propósito. Ocupan casi la mitad del fichero y cuando la poda entre se llevará por delante gestos de verdad para conservarlos. Que se cuenten en una línea por día en vez de una por vez, y que el tope se mida en días de memoria, no en líneas.

**El dato.** escucho 1.454 + lotengo 124 + atencion 2 = 1.580 de 3.557 líneas (44,4 %), y los dos lectores los excluyen explícitamente por nombre. El fichero crece a 237 líneas al día (3.557 líneas entre el 11 y el 25 de septiembre, 15 días) y la poda entra a las 6.000 dejando 5.000: llega en unos 10 días, y de las 5.000 que conserve unas 2.220 serán de esas tres.

**Dónde se comprobó.** Contado con: awk '{print $3}' tmp\gestos.log | sort | uniq -c | sort -rn (escucho 1454, lotengo 124, atencion 2 de 3557); awk '{print $1}' tmp\gestos.log | sort | uniq -c (del 2026-09-11 al 2026-09-25). Filtros en assistant.ps1:3234 y 20557 ('if ($g -in @(''escucho'', ''lotengo'', ''atencion'')) { continue }'); poda en assistant.ps1:3225-3228.

**Cómo se hace.** nova_ui.cs: AnotarGesto (2322) desvía esos tres a un contador diario en tmp\gestos-cuenta.txt (una línea por día, se reescribe). assistant.ps1: la poda (3225) deja de contar líneas y corta por fecha, con los días calculados a partir del ritmo medido del propio fichero para que siempre quepan los mismos días de relación.

**Riesgo y guarda.** Perder el rastro de cuántas veces escuchó, que hoy está línea a línea. Guarda: el contador diario conserva la cuenta, y la poda por fecha nunca borra un día que todavía esté dentro de la ventana; si el ritmo no se puede medir, se queda con el tope de 5.000 de ahora.

### 101. El diario de gestos no dice quién lo provocó, y el resumen semanal lo cuenta al revés

**Valor 5 · coste 3 · ángulo `capsula`**

**Qué.** tmp\gestos.log guarda solo la hora y el nombre del gesto, así que no distingue lo que dijo braya de lo que dijo Nova ni de lo que mandó el cerebro. El resumen semanal lo lee como si todo fuera de braya. Una letra más por línea ('t' de tú, 'y' de yo) lo arregla, y el que escribe ya sabe cuál es.

**El dato.** memoria\semanas\2026-W37.md dice literalmente 'Lo que más me dijiste, según mis gestos: grito ×148, confuso ×143, orgullo ×123, perdida ×59': los CUATRO son de ella, no de braya. 2026-W38.md dice 'duda ×256, grito ×235, confuso ×119, negar ×80': tres de cuatro igual. De las 3.557 líneas del diario, solo 89 (2,5 %) vienen de patrones que únicamente braya puede disparar; 2.717 (76,4 %) son de Nova o del cerebro y 751 son ambiguas.

**Dónde se comprobó.** memoria\semanas\2026-W37.md y 2026-W38.md (el texto ya escrito); nova_ui.cs:2322 (AnotarGesto, escribe solo hora+nombre), 2299-2308 (MedirTono dispara 'grito' cuando el micro satura), 2156 (GESTOS_PROPIOS: 'orgullo' sale de 'listo/hecho/anotado' que dice ella); assistant.ps1:3226 y 20551 (los dos lectores). Reparto contado clasificando las 3.557 líneas contra las tres tablas de patrones y los 12 'gesto:<nombre>' que manda assistant.ps1: 89 + 751 + 2.717 = 3.557.

**Cómo se hace.** nova_ui.cs: AnotarGesto(nombre) pasa a AnotarGesto(nombre, quien); los llamantes ya lo saben (AnalizarTexto tiene el bool 'propio' en 2190, y la puerta de eventos del cerebro es otra). En assistant.ps1 las dos regex de lectura (3234 y 20552) aceptan la letra y filtran por ella; las líneas viejas sin letra cuentan como desconocidas y no entran en el 'lo que me dijiste'.

**Riesgo y guarda.** Romper los dos lectores con el formato viejo. Guarda: la regex acepta las dos formas y lo que no lleva letra va a un cubo 'no lo sé' que no se le atribuye a nadie; ningún resumen afirma de quién es un gesto sin marca.

> **El verificador corrigió el dato:** 'los CUATRO son de ella' es falso para 'grito': MedirTono (nova_ui.cs:2299-2308) lo dispara con nivelObjetivo >= 0.97 mientras estadoActual=='escuchando', o sea con el microfono de braya. Son TRES de cuatro en W37 (confuso, orgullo, perdida) y DOS claros en W38 (confuso, y duda que es ambiguo). El reparto 89/751/2.717 solo sale si grito (432) y susurro (38) se cuentan como no-braya, que es discutible: cuentalos aparte.

### 102. El plazo de los 6 s para decir si, contado y puesto por ella (y aparte cuando hay un juego delante) ∿ ⚙

**Valor 4 · coste 3 · ángulo `numeros-fijos+mando`**

**Qué.** Nova apunta cuanto tarda braya de verdad en contestar un si o un no -contando desde que el microfono queda libre, no desde que ella empieza a preguntar- y pone el plazo ella misma, con un cubo aparte para cuando hay un juego delante y las dos manos estan ocupadas. Hoy son 6 segundos fijos escritos a mano, ya retocados a mano una vez (de 3,5 a 6 el 18/09), en el unico sitio donde braya esta parado esperando a que ella reaccione.

**El dato.** Los dos logs (16 dias) se dejan medir de dos maneras y las dos hacen falta:  1) DESDE QUE EL MICRO QUEDA LIBRE ('confirmacion: esperando si/no' -> 'confirmacion: X -> X'), que es lo que el plazo cuenta de verdad: 24 confirmaciones, 16 contestadas con retrasos de 0,0,0,1,1,1,1,1,1,2,2,2,2,3,3,3 segundos. La mas lenta, TRES segundos. Las otras 8 (el 33 %) vencieron sin respuesta, y ahi los seis segundos se pagan enteros. Con el plazo en 4 s no se pierde ni una de las 16 y se recorta un tercio de la espera en las 8 que mueren.  2) DESDE LA PREGUNTA hasta el desenlace: 20 pares en 16 dias; los si a 4, 6, 6, 6, 7, 8, 8 s; los no a 4, 6, 7, 8, 11 s; y las muertas por plazo a 7, 7, 7, 10, 11 s. 5 de 20, una de cada cuatro. Parece que el plazo corta por la mitad del reparto (hay un si a los 7 s y una muerte a los 7 s), pero NO: esa cuenta incluye lo que tarda la propia voz de Nova, y el codigo ya la descuenta (assistant.ps1:27376 empuja el vencimiento a fin-de-voz + ConfirmacionMs). Medido desde donde el plazo empieza de verdad, nadie ha tardado nunca mas de 3 s. Los que mueren no es que contesten tarde: es que no contestan.  Listones de la casa que entran en juego: $DecisionMinIntentos = 20 (assistant.ps1:11888), techo del selector $EleccionMs = 15000 (assistant.ps1:26517).

**Dónde se comprobó.** assistant.ps1:23857 ($ConfirmacionMs = [int](Get-Cfg 'confirmacion' 'esperaMs' 6000)) y config.json confirmacion.esperaMs = 6000. Se lee en TRES sitios, no dos: assistant.ps1:23881 (la red de Start-Confirmacion), 23856 nota del 18/09, assistant.ps1:27356 (el rearme al pasar a 'confirmando') y assistant.ps1:27376 ($minimoC = $finVozC + $ConfirmacionMs). Medicion: cat assistant.log.1 assistant.log y emparejar (a) cada 'confirmacion: esperando si/no' con su 'confirmacion: X -> X', y (b) cada 'CONFIRMAR: ... -> ¿...' con su desenlace del mismo dia.

**Cómo se hace.** Add-TiempoRespuesta / Get-PlazoConfirmacion, copiando el patron ya probado de Add-VozTiempo + Get-VozPlazoMs (assistant.ps1:2402 y 13985): lista con tope de muestras, percentil por el metodo del mas cercano (igual que Get-NubePercentil / Get-TrabajoPercentil), y la funcion de calculo PURA con todo por parametro para que el banco le pueda pasar doscientos casos.  - Se apunta la diferencia entre el momento en que el micro queda libre (el mismo $finVozC de assistant.ps1:27375, que es cuando se escribe 'esperando si/no') y la llegada de la respuesta en Complete-Confirmacion; y con cada muestra, si fue si, no o plazo y si habia juego ($script:juegoActivo). Los vencidos por plazo NO entran como retraso: son censura, no una medida. - Dos cubos: sin juego y con juego. Sin juego, p95 por dos, suelo 3.000 ms y techo en los 6.000 de hoy: nunca se alarga lo que ya cubre las 16 respuestas medidas. Con juego, mismo calculo pero techo $EleccionMs = 15000, que es el que ya tiene el selector, porque ahi las manos estan ocupadas y de ese cubo todavia no hay ni una medida. - Con menos de $DecisionMinIntentos = 20 muestras en su cubo manda el 6.000 de siempre y se dice en el log. Hoy hay 16: de entrada NO se mueve nada; lo que cambia es que deja de ser una corazonada y empieza a contarse. - Se sustituye $ConfirmacionMs en los tres sitios que lo leen: 23881, 27356 y 27376.

### 103. La temperatura del chip, que es la que explica el ruido del ventilador ∿

**Valor 4 · coste 3 · ángulo `consola`**

**Qué.** Nova avisa de que hay un ruido de fondo constante y le pide a braya que lo quite, sin saber si el ruido es suyo. Windows expone la zona termica de la consola con la temperatura, el motivo de estrangulamiento y el limite pasivo. Con eso Nova podria decir "el zumbido es mi ventilador, la zona termica va por 84 grados" en vez de mandarle a apagar algo que no existe.

**El dato.** CERO apariciones de ThermalZone, MSAcpi o temperatura de hardware en las 28.720 lineas de assistant.ps1: Nova no ha leido nunca lo caliente que esta. Medido aqui: Win32_PerfFormattedData_Counters_ThermalZoneInformation da \_TZ.THRM con Temperature en kelvin, ThrottleReasons y PercentPassiveLimit; siete lecturas seguidas dieron 68,9 / 66,9 / 64,9 / 64,9 / 64,9 / 64,9 / 64,9 grados, o sea que se mueve de verdad. Coste: 1.625 ms la primera y 39-73 ms en caliente; para comparar, la sonda de CPU que apagaron por cara costaba 1.057-1.320 ms. Y hace falta: 36 avisos "Hay un ruido de fondo constante" dichos en 17 dias, mas 1.649 aparcados por no haber nadie. (MSAcpi_ThermalZoneTemperature no devuelve nada en esta maquina y las clases AsusHWMonitorWMI / AsusAtkWmi_WMNB existen pero tienen 0 instancias: por ahi no hay revoluciones de ventilador, solo la zona termica.)

**Dónde se comprobó.** assistant.ps1:10218 y 11102 (sus propios comentarios sobre el ventilador), assistant.ps1:26246-26252 (lo que costaba la sonda de CPU y por que se apago), assistant.ps1:26272 (Get-CargaCPU, el patron a copiar). Conteo: grep -h "ENTORNO (oido-ruido" assistant.log assistant.log.1 | wc -l = 36. Medicion: Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation, siete lecturas cronometradas.

**Cómo se hace.** Una Get-Temperatura al lado de Get-CargaCPU (26272), con el mismo patron exacto: se cronometra la primera llamada y si pasa del tope se apaga sola y lo escribe en el log. Se lee en el bloque que ya corre cada minuto y la serie se guarda en assistant-pulso.log como ya se hace con las lineas [bateria]. La rama que redacta el aviso de ruido consulta la temperatura antes de elegir la frase.

**Riesgo y guarda.** Que \_TZ.THRM sea una zona del chasis y no el chip, y que el numero suene mas exacto de lo que es. Se dice como "mi zona termica marca X", y si ThrottleReasons vale 0 no se afirma que este estrangulada. Si la clase no existe, Get-Temperatura devuelve $null y el aviso de ruido se queda literalmente como hoy: ninguna frase nueva depende de que el dato exista.

> **El verificador corrigió el dato:** La primera lectura NO cuesta 1.625 ms: en un proceso de PowerShell recien nacido costo 8.002 ms. En un proceso que ya habia hecho un Get-CimInstance (que es el caso de assistant.ps1, que llama a Win32_Battery cada minuto en 28453) la primera termica costo 37 ms y las siguientes 31-65 ms. Ahora marca 329 K = 55,9 C, no 64-69; Temperature viene en kelvin ENTEROS, o sea resolucion de 1 grado.

### 104. El 'has vuelto' guarda los minutos cuando lo que quiso guardar era el ritmo ∿

**Valor 3 · coste 3 · ángulo `numeros-fijos`**

**Qué.** Los 45 minutos que deciden cuando Nova te saluda al volver se eligieron para que saliera 'poco mas de un saludo al dia'. Lo que hay que guardar es ese 'uno al dia', no los 45 minutos: los huecos de braya cambian y sobre todo Nova se reinicia mucho mas que antes, y un reinicio se come el saludo. Que Nova recalcule los minutos cada semana para mantener el ritmo que se le pidio.

**El dato.** Contados los huecos entre cosas que hizo braya en los 16 dias de registro (4.094 interacciones): con 45 minutos salen 56 huecos, pero solo 5 con Nova viva de punta a punta, o sea 0,31 saludos al dia. El objetivo escrito en el codigo era 1,1. Y coincide con la realidad: en todo el registro hay exactamente 5 lineas 'VUELTA:'. El motivo esta medido: 472 arranques en 16 dias (29,5 al dia), frente a los 16,3 al dia que cita el comentario del 23/09. Para volver al ritmo pedido hoy haria falta bajar a unos 20 minutos (0,62 al dia) o menos.

**Dónde se comprobó.** assistant.ps1:10121 ($VueltaMin = Get-Cfg 'entorno' 'vueltaMin' 45) y 10122 ($VueltaVozMin, 180); se usa en assistant.ps1:12893. Medicion: python sobre los dos logs emparejando ACTIVADO/DICTADO/ORDEN ESCRITA y descartando los huecos con 'saludo de arranque' o 'VoiceAssistant iniciado' en medio.

**Cómo se hace.** En config.json se cambia 'vueltaMin' por 'vueltaAlDia' (1.0). Una funcion Get-VueltaMin que, una vez por sesion, recorre los dias guardados en memoria\estadisticas.json y los arranques del registro, prueba los umbrales 15/20/30/45/60/90 y devuelve el mas grande que llegue al ritmo pedido. Se guarda con Set-Cfg 'entorno' 'vueltaMin' para que se pueda deshacer hablando, como el resto de decisiones propias.

**Riesgo y guarda.** Que Nova acabe saludando cada veinte minutos y canse. El nivel bajo de VueltaMin es solo capsula, no voz: lo que habla es VueltaVozMin (180 min), que se recalcula con el mismo metodo pero con su propio ritmo pedido (0,3 al dia). Y hay suelo de 15 minutos, por debajo del cual no se baja nunca.

> **El verificador corrigió el dato:** 1.981 interacciones en el registro, no 4.094 (ACTIVADO / DICTADO / ORDEN ESCRITA sobre los dos logs). 472 arranques = 29,4 al dia. Los huecos y el 0,31/dia salen identicos.

### 105. El resumen del dia se escribe con el final del dia, y cuenta el dia de Nova

**Valor 5 · coste 5 · ángulo `charla`**

**Qué.** Lo hablado cada dia se resume con el modelo local y luego se borra el bruto. Pero al modelo solo le llegan los ultimos 2.500 caracteres, asi que el dia mas largo se resume con su ultima media hora, y el resto se pierde. Ademas el prompt pide que cuente 'de que hablaron braya y Nova', y el resultado es un diario que habla de Nova.

**El dato.** Contado sobre los turnos reales del registro: el 20/09 hubo 82 turnos y 16.098 caracteres de conversacion; al resumidor entran los 11 ultimos turnos, el 16 % del dia. El 18/09, 33 de 89. El 15/09, 25 de 72. El 21/09, 16 de 31. Despues os.remove borra el bruto entero. Y de las 24 vinetas que hay escritas en memoria\diario, 14 -el 58 %- nombran a Nova: 'Nova asumio que estaba hablando de uno', 'Nova se disculpa y pide que Braya repita'.

**Dónde se comprobó.** charla_worker.py:1046-1067 (num_ctx 1536, el recorte [-2500:] en la linea 1052 y el os.remove); memoria\diario\*.md (7 ficheros con seccion 'Lo que hablamos', 24 vinetas contadas)

**Cómo se hace.** Trocear en resumir_dias_pasados: una llamada local por conversacion (corte de 5 minutos sin hablar) o por cada 2.500 caracteres, pidiendo 2 vinetas por trozo, y quedarse con las 5 de los trozos mas largos. Esto corre con Nova 20 minutos en reposo, asi que tres o cuatro llamadas locales mas no le quitan nada al juego. Y en el prompt: 'sobre lo que le paso a braya; no hables de Nova ni de lo que entendio o dejo de entender'.

**Riesgo y guarda.** Mas llamadas locales es mas rato con el modelo cargado, y borrar el bruto sin haberlo resumido entero. Guardas: la condicion de 20 minutos sin charla ya esta y no se toca; tope de 6 trozos por dia; y si una sola llamada falla, el bruto NO se borra -como hoy- y se reintenta al dia siguiente.

> **El verificador corrigió el dato:** el 20/09 entran los 11 ultimos turnos de 82: el 13 %, no el 16 %

### 106. Que «¿qué sabes de...?» mire también el cerebro, no solo el diario

**Valor 5 · coste 5 · ángulo `ficheros`**

**Qué.** Hoy la búsqueda rápida en la memoria abre dos carpetas: memoria\diario y memoria\temas. La segunda no existe. Así que Nova contesta a «¿qué te conté de...?» rebuscando en 29 viñetas resumidas, mientras los 121 recuerdos con el texto entero de lo que hablasteis están en cerebro.json y esa búsqueda no los abre nunca.

**El dato.** memoria\diario: 12 ficheros .md, 2.866 bytes en total, 29 líneas útiles (todas viñetas). memoria\temas: NO EXISTE (0 ficheros, en los 16 días de vida del proyecto). memoria\cerebro\cerebro.json: 54.465 bytes, 121 recuerdos, de ellos 111 de tipo episodio y 6 de tipo contado, o sea 117 cosas que braya dijo y que esa búsqueda no puede encontrar. El contador 'memoria' de estadisticas.json va a 3 en 15 días.

**Dónde se comprobó.** assistant.ps1:2095-2141 (Find-EnMemoria, recorre $DiarioDir y (Join-Path $MemoriaDir 'temas')); `ls memoria/temas` -> No such file or directory; `wc -c memoria/diario/*.md` -> 2866 total; `cat memoria/diario/*.md | grep -c '^- '` -> 29; cerebro.json medido con python: 121 recuerdos, Counter({'episodio':111,'contado':6,'respuesta':4})

**Cómo se hace.** En Find-EnMemoria, añadir una tercera fuente al bucle de archivos: leer memoria\cerebro\cerebro.json y convertir cada recuerdo de tipo episodio/contado en una línea puntuable (campo 'respuesta', con la fecha de 'creada'), y las líneas de importante.jsonl igual. Se reutiliza tal cual la puntuación por palabras y la distancia 1 que ya tiene. Y quitar memoria\temas del bucle, o crearla al arrancar, pero no dejar la carpeta fantasma.

**Riesgo y guarda.** Que suelte un episodio sacado de contexto y suene raro («el 22 de septiembre: braya menciona una olla»). Guarda: los episodios se dicen SIEMPRE con su fecha delante («el 22 de septiembre me contaste que...»), y solo entran si puntúan igual o más que la mejor viñeta del diario, que es el criterio que ya existe.

### 107. El disco de fuera: los juegos que Nova no sabe que existen porque nunca lee el bloque "apps" ∿ ⚙

**Valor 5 · coste 5 · ángulo `consola+juegos`**

**Qué.** libraryfolders.vdf lista, para cada biblioteca de Steam, los juegos que tiene dentro. Nova ve que la segunda biblioteca (E:\SteamLibrary) no esta puesta y la salta en silencio, sin leer jamas la lista de appids que el propio fichero trae escrita. Resultado: de esos juegos no sabe ni que existen. Si braya pide uno, o contesta 'no lo tengo', o cae en la rama de la tienda y le abre la ficha para que lo instale: reinstalar 683,8 GiB que ya tiene. Que se lea el bloque de juegos de TODAS las bibliotecas, tambien las ausentes, y se guarde: asi 'abre ELDEN RING' contesta 'esta en el disco de fuera, que no esta puesto', y cuando el disco aparezca, Nova puede decir sola que ha vuelto.

**El dato.** libraryfolders.vdf declara DOS bibliotecas. La 0 (C:) trae 17 appids en su bloque "apps", y en disco hay exactamente 17 appmanifest_*.acf. La 1 (E:\SteamLibrary, totalsize 1.000.163.246.080 bytes = 1 TB) trae DIEZ appids; Test-Path E:\SteamLibrary = False y las unidades listas son solo C: y D:. Dos de esos diez (1817070 Spider-Man y 2358720 Black Myth) estan tambien en C:, o sea OCHO exclusivos, que suman 734.289.177.929 bytes = 683,8 GiB EXACTOS. De esos ocho, siete traen contenido: el appid 2139460 figura con 0 bytes en el vdf. Entre ellos esta el 1245620, que es ELDEN RING, 66 GB: braya jugo el 18, el 19 y el 20/09 y lo intento abrir el 25/09 a las 21:31; hoy la carpeta ELDEN RING sigue en steamapps\common con 0,05 GB y sin appmanifest. Nombrarlos es el problema: 7 de los 10 appids no se pueden nombrar hoy — solo 1817070 y 2358720 salen de los appmanifest de C:, y 1245620 de memoria\juegos-dos.json. El texto '"apps"' no aparece NI UNA VEZ en las 28.720 lineas de assistant.ps1: ese bloque no se lee jamas. Y el tipo de regla 'cuando conecte el disco de los juegos' ya existe en el traductor, pero memoria\reglas.json esta vacio ([]). OJO CON EL NOMBRE: E: no es 'la tarjeta'. La SD que SI esta puesta es D:, 'Rog SD', de 477 GB; E: es un aparato distinto, de 1 TB.

**Dónde se comprobó.** assistant.ps1:1109-1160 (Get-JuegosSteam; el comentario de 1128-1134 ya sabe que E: no esta y solo lo usa para no petar con DriveNotFoundException, y el 'continue' silencioso de 1133 es donde se pierde todo), assistant.ps1:1575 (Find-JuegoEn) y 1640 (Find-Juego), assistant.ps1:6237 (la rama de instalar: "se abre su ficha en la tienda y le das a instalar tu"), assistant.ps1:1317 (Get-FichaDosSteam, la consulta a la tienda que ya existe), assistant.ps1:11440-11462 (el flanco de unidades que ya relee la biblioteca y avisa), assistant.ps1:19625 y 19797 (el tipo de regla discoJuegos). Ficheros leidos: C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf (bloque "1", path E:\SteamLibrary, 10 appids), memoria\reglas.json = [], memoria\juegos-dos.json. Comprobaciones: Test-Path E:\SteamLibrary, [System.IO.DriveInfo]::GetDrives(), conteo de appmanifest_*.acf en C: = 17, grep -c '"apps"' assistant.ps1 = 0, wc -l assistant.ps1 = 28.720.

**Cómo se hace.** En Get-JuegosSteam, al leer libraryfolders.vdf se parsea tambien el bloque "apps" de CADA biblioteca (hoy solo se saca "path" con un regex por linea). Las bibliotecas que si estan puestas se cruzan con los appmanifest de siempre; en las que no estan, en vez del 'continue' de 1133 se guardan sus appids con sus bytes y estado 'en un disco que no esta' en memoria\juegos-fuera.json. Find-Juego (1640), cuando Find-JuegoEn y el refresco no encuentran nada, mira esa lista ANTES de rendirse y devuelve un 'esta pero no esta aqui', de modo que el despacho de 'abre X' y la rama de instalar de 6237 lo vean antes de mandar a la tienda. Los nombres no estan en el vdf -solo appid y bytes-, asi que salen de los que ya se tengan en memoria/juegos.json y juegos-dos.json, o de la consulta a la tienda que ya existe en 1317; sin nombre no se inventa nada: se dice 'siete juegos mas que no puedo nombrar sin el disco puesto'. Y en el flanco de unidades de 11440, cuando una biblioteca ausente vuelve a aparecer, se dice que juegos han vuelto (una frase, nivel bajo), reusando el aviso que ya hay ahi.

### 108. Perder el primer plano no es cerrar el juego: aplazar TODO lo que hace la salida, no solo la frase ∿ ⚙

**Valor 5 · coste 5 · ángulo `log-uso+ordenes-fallidas`**

**Qué.** Cuando el juego deja de estar delante -un alt-tab, una pantalla de carga, un overlay, o el salto a pantalla completa exclusiva- Nova lo trata como un cierre: devuelve el brillo a 100, devuelve la palabra de activacion y pone el tiempo de partida a cero. Segundos despues el juego vuelve y empieza otra vez. El brillo parpadea, la escucha parpadea y la partida se parte en trozos de once segundos. La idea es que la salida quede EN DUDA de verdad: al perder el primer plano no se toca nada (ni el brillo, ni la palabra de activacion, ni el contador), se apunta la salida con su hora, y solo se ejecuta si el juego no vuelve dentro de la ventana que Nova misma ha medido para ESE juego. Si vuelve, no era una salida: se cancela y el tramo se suma a la misma partida.

**El dato.** PARPADEO DEL BRILLO: 56 veces se aplico el perfil de juego y solo 43 restauraciones emparejadas (13 entradas se quedaron sin pareja). De esos 43 pares, 29 (67 %) duran menos de 2 minutos y 20 menos de 30 segundos. De las 26 veces que salio y volvio al MISMO juego, en 12 volvio en menos de 60 s y en 8 en menos de 30; mediana de los tiempos fuera 116 s, p75 unos 16 min. Sigue pasando ahora: el 25/09 ELDEN RING NIGHTREIGN entro y salio SEIS veces entre las 21:34 y las 22:45, con 8, 9, 10, 10, 11 y 21 segundos -doce cambios de brillo-; y el 23/09, con A Way Out, diez pares entre las 22:07 y las 22:43. PARPADEO DE LA ESCUCHA Y PARTIDA ROTA: el 25/09, entre 21:31 y 22:45, siete ciclos completos con ELDEN RING y ELDEN RING NIGHTREIGN de 11, 11, 11, 11, 20, 21 y 21 segundos; cada uno escribio "perfil 'juego' aplicado", "solo boton mientras juegas" y, once segundos despues, "brillo restaurado a 100" y "vuelve la palabra de activacion": el brillo subio y bajo siete veces y la palabra de activacion se apago y encendio siete veces en 75 minutos. Las siete sesiones medidas del registro entero duran 60 s o menos: no hay ni una larga. LA CONTRADICCION DENTRO DE NOVA: memoria\juegos.json dice ELDEN RING NIGHTREIGN = 75 segundos el 2026-09-25, mientras memoria\uso-ally.json dice que el proceso 'nightreign' estuvo 4.038 segundos en primer plano ese mismo dia. 54 veces mas.

**Dónde se comprobó.** assistant.ps1:20670 Exit-Juego (la salida entera), :20710 donde se apunta $script:juegoSalida, :20719-20720 Set-Brillo + Log 'brillo restaurado', :20733 Test-JuegoVivo, :20758 Test-SalidaJuego y su rama "ha vuelto al mismo juego" (:20761), :20777 "cerrado con N min de partida", :19003 Get-JuegoEnPrimerPlano, y el bucle en :28262-28280 (Exit-Juego / Enter-Juego y el borrado de $MarcaSoloBoton con el Log 'vuelve la palabra de activacion'). Ficheros: memoria\juegos.json frente a memoria\uso-ally.json. Comandos: cat assistant.log.1 assistant.log | grep "JUEGO: perfil 'juego' aplicado al entrar\|JUEGO: brillo restaurado" y emparejar por juego; grep "^2026-09-25 2[12]" assistant.log | grep -E "JUEGO|juego en primer plano".

**Cómo se hace.** El aplazamiento va en Exit-Juego (assistant.ps1:20670), que es de donde salen las tres cosas en el mismo segundo. Hoy Exit-Juego ya apunta la salida en duda en $script:juegoSalida (:20710) pero solo aplaza la FRASE 'cerraste X'; el brillo (:20719-20720), el reinicio del contador y el borrado de la marca de solo-boton se hacen al instante. Se mueve el bloque de Set-Brillo detras de la comprobacion, se guarda el brillo pendiente en $script:juegoSalida, y el bucle -donde ya vive Test-SalidaJuego- restaura cuando el juego no ha vuelto dentro de la ventana. Lo mismo con la palabra de activacion: el borrado de $MarcaSoloBoton en el bucle (:28277-28279) se aplaza igual. Y en Test-SalidaJuego, al confirmar el cierre, el tiempo del tramo se SUMA a la partida en vez de reiniciarla. CUIDADO CON LA GUARDA: no vale con Test-JuegoVivo, porque en los siete casos del 25/09 dio FALSO -el proceso si habia muerto un instante- y con esa condicion el parpadeo seguiria igual. La ventana es de tiempo: si el mismo nombre de juego reaparece dentro de ella, se cancela la salida. La ventana se aprende de las reapariciones medidas de ESE juego y se guarda en su entrada de memoria\juegos.json (donde ya viven 'ritmoBateria' y 'muestrasBateria'), o en memoria\habitos.json igual que el 'ritmo' que usa Get-VentanaSeguimiento (assistant.ps1:22590); sin datos, ventana cero y todo se comporta como hoy. De paso, al final del dia se comparan los segundos de juegos.json con los del proceso en uso-ally.json y se anota la discrepancia cuando pase de un factor.

### 109. La tabla de correcciones escrita a mano: 102 de 110 nunca se han oido ⬆ ∿

**Valor 5 · coste 5 · ángulo `muertas`**

**Qué.** commands.json lleva 110 correcciones de palabras mal oidas ('yutub', 'espotifai', 'guasap'...), escritas a mano una por una. En 17 dias de uso real solo 8 de ellas se han oido; las otras 102 son peso muerto que nadie ha medido nunca. La idea es que Nova puntue su propia tabla con las 784 frases reales que ya tiene grabadas, diga cuales se ganan el sitio y retire las que llevan 17 dias sin aparecer, en vez de que la lista siga creciendo a ojo.

**El dato.** commands.json: correcciones 110, apps 24, sitios 14, busquedas 9, perfiles 5. Cruzadas contra las 784 frases unicas de pruebas/audio/uso (destinos.jsonl + registro.jsonl, en plano): de las 110 correcciones se han oido 8 ('painterest', 'youtub', 'team', 'serra', 'descagando', 'temporizado', 'este estado es cargando', 'sting'); 102 nunca. De las 24 apps, 10 nunca se han nombrado (entre ellas 'edge', 'firefox', 'terminal', 'powershell', 'armoury crate'). De los 14 sitios, 11 nunca.

**Dónde se comprobó.** C:\Users\braya\Documents\voice-ctrl\commands.json. El cruce se hizo cargando el json y buscando cada clave, normalizada sin tildes ni signos, dentro del corpus de 784 frases unicas sacado de pruebas/audio/uso/destinos.jsonl y registro.jsonl (campos texto, detalle, frase, orden, entregado, parakeet, whisper, vosk).

**Cómo se hace.** Un script de mantenimiento que Nova se corra sola, colgado del mismo sitio donde ya corre la copia del dia (la linea COPIA de assistant.log, una vez al dia): lee commands.json, lee el corpus de uso, y por cada entrada de 'correcciones' apunta cuantas veces se ha oido en los ultimos N dias. Las que esten a cero pasan a una seccion 'dormidas' del propio fichero -no se borran- y dejan de compararse. El corte N no se escribe a mano: sale del propio reparto, igual que Get-DecisionMinimo, y hasta que no haya dias suficientes no se retira nada.

**Riesgo y guarda.** El peligro grande esta en el otro lado, en anadir: al buscar candidatos con parecido fonetico salen 'esta' (235 veces), 'este' (123) y 'estas' (56) como parecidos a 'steam'. Meter cualquiera de esos en la tabla convertiria "esta bien" en "steam bien" y romperia la regla 1 en cada frase. Por eso esta idea SOLO retira, nunca anade sola: lo que propone para entrar se le dice a braya y no se escribe hasta que el diga que si. Y retirar es reversible porque las entradas se mueven a 'dormidas', no se borran.

> **El verificador corrigió el dato:** Dos retoques menores. El corpus no son 784 frases unicas sino 1.414 con esos mismos ficheros y campos -da igual, el 8/102 sale identico con ambos-. Y de las 24 apps las que nunca se han nombrado son 9, no 10 (steam, navegador, internet, explorador, archivos, spotify, discord, calculadora, notas, configuracion, ajustes, administrador de tareas, paint, camara y xbox si aparecen; edge, firefox, terminal, powershell y armoury crate no).

### 110. Que haga la autopsia del oido antes de relanzarlo, como ya hace con la capsula

**Valor 5 · coste 5 · ángulo `errores`**

**Qué.** Guardar el ExitCode del worker al morir y relanzar segun la causa, igual que la capsula: salida 3 es el microfono parado, asi que antes de relanzar vuelve a enumerar dispositivos; con rastro de COM en stderr, relanzar sin el medidor de altavoces. Hoy relanza siempre exactamente igual y casi nunca sabe por que murio.

**El dato.** 28 relanzamientos del worker en el registro (25 al primer intento, 2 al segundo, 1 al tercero) y solo TRES autopsias, las tres del 15/09. tmp/wake-err.log esta hoy a 0 bytes. Seis de esas muertes son suicidios con causa conocida y apuntada ('el microfono lleva N s sin entregar audio; salgo para que me relancen', sys.exit(3)) y ninguna deja nada en stderr. Las tres autopsias que existen apuntan todas al mismo sitio: 'Windows fatal exception: access violation', 'comtypes/_post_coinit/unknwn.py line 420, in Release' y 'ValueError: COM method call without VTable', que es el medidor de altavoces. Y la capsula SI lo hace bien: su relanzamiento imprime el codigo de salida y la ultima linea de ui-error.log.

**Dónde se comprobó.** assistant.ps1:27090-27095 (el relanzamiento del oido, sin ExitCode) frente a assistant.ps1:28682-28692 (el de la capsula, con codigo y ultimo error). wake_vosk.py:3263 (sys.exit(3) por microfono parado), wake_vosk.py:659-696 (el medidor por comtypes). Contado con: grep -c 'worker de escucha murio' y grep -c 'su salida de error la vez anterior' sobre assistant.log.1 assistant.log

**Cómo se hace.** En la rama de 27091, copiar el patron de la capsula: try { $codW = $script:wakeProc.ExitCode } catch {}, meterlo en el Log y guardarlo en $script:wakeUltimaCausa. Initialize-Escucha lee esa causa: si es 3, un sd.query_devices() extra antes de arrancar (el argumento del dispositivo ya se lee al arrancar); si el stderr viejo trae 'comtypes' o 'access violation', se pasa un argumento mas que arranca sin el medidor de altavoces, que ya tiene su propio camino de recuperacion ('medidor de altavoces recuperado tras N fallos').

**Riesgo y guarda.** Arrancar en modo reducido cuando no hacia falta y quedarse sin medidor de altavoces sin motivo. Lo evita que el modo reducido solo entre a partir de la SEGUNDA muerte seguida y que se deshaga en cuanto el worker aguante los 5 minutos que $script:wakeDesde ya cuenta para rearmar los reintentos.

### 111. Lo que Nova ocupa de la consola, medido por ella ∿

**Valor 5 · coste 5 · ángulo `autoconocimiento`**

**Qué.** La regla 5 de la casa dice que nada residente se coma la RAM ni un núcleo que le hace falta al juego, y no hay una sola medición de eso. Nova nunca mira su propio consumo: sólo lo calcula si braya se lo pregunta en voz alta. Que se mire sola, cada minuto y por turnos -un proceso por vuelta-, y que aprenda su propia línea base: cuánto ocupa cuando no pasa nada. Cuando se sale de su propia línea base, lo dice o reinicia el worker que se ha hinchado.

**El dato.** Medido ahora mismo sobre los procesos vivos de Nova, con 1h59m de sesión: el cerebro (powershell, PID 27208) 214 MB y 1.874 s de CPU, o sea el 26,2 % de un núcleo sostenido; el oído (pythonw wake_vosk.py, PID 26464) 281 MB y el 15,4 %; la cápsula (nova_ui.exe, PID 25184) 98 MB y el 17,4 %. En total unos 675 MB y 0,60 de un núcleo de los 8, dos horas seguidas. Y TotalProcessorTime no aparece ni una vez en assistant.ps1, wake_vosk.py ni charla_worker.py; WorkingSet64 sólo sale dentro de Get-RamResumen, que únicamente corre desde una orden hablada (assistant.ps1:15843). La sonda que sí existe, Get-CargaCPU, mide el _Total de la máquina para pintar una insignia, no lo que gasta ella.

**Dónde se comprobó.** Get-Process -Id 27208,26464,25184 con StartTime y TotalProcessorTime, ejecutado en esta consola; grep -n TotalProcessorTime assistant.ps1 wake_vosk.py charla_worker.py -> 0; grep -n WorkingSet64 assistant.ps1 -> 1508,1509,1518,1528,1545-1547 (todo dentro de Get-RamResumen); assistant.ps1:26272 (Get-CargaCPU mide _Total)

**Cómo se hace.** Guardar los objetos Process de los workers que ya tiene en $script:wakeProc, $script:uiProc y $script:charlaProc, y una vez por minuto refrescar UNO solo -medido aquí: 5,7 ms por lectura- leyendo TotalProcessorTime y WorkingSet64. La cuota de núcleo es la resta de CPU dividida por la resta de reloj. Se guarda con Add-TrabajoTiempo, que ya existe, con claves 'cpu:cerebro', 'ram:oido' y demás.

**Riesgo y guarda.** Que la propia sonda cueste dentro del bucle y que avise de un pico normal. Las guardas: un proceso por vuelta cada 12 s, o sea 5,7 ms de cada 12.000; y el listón es su propio percentil 90 separando 'con juego delante' de 'sin juego', porque son dos mundos distintos. Si la sonda llega a costar más de un tope, se apaga sola y se dice, que es el criterio que Get-CargaCPU ya aplica.

> **El verificador corrigió el dato:** Leer TotalProcessorTime + WorkingSet64 de un proceso cuesta 9,5 ms medidos aquí (20 lecturas en 189 ms), no 5,7 ms

### 112. La ronda de fondo no mira si hay alguien delante ∿

**Valor 5 · coste 5 · ángulo `tiempo`**

**Qué.** El clima, el correo, el disco y la biblioteca de Steam se refrescan por reloj, sin preguntar si hay alguien. Nova ya calcula esa senal para aparcar los avisos. Que la ronda de RED use la misma: sin nadie desde hace un rato, cadencia larga; cualquier senal de vida la restaura y dispara un refresco inmediato.

**El dato.** Entre las 02:00 y las 08:59 no hay NI UNA de las 714 ordenes reales de 13 dias, y solo 6 de los 3.557 gestos de la capsula en 15 dias. Aun asi, en esa franja Nova hizo 54 consultas del tiempo, 16 de las 28 comprobaciones de correo (el 57 %), 34 refrescos de la biblioteca de Steam y 5 del disco. El 24/09 escribio 4.114 lineas 'ENTORNO aparcado' (una cada ~12 s: unas 14 horas sin nadie) y ese mismo dia consulto el tiempo 26 veces.

**Dónde se comprobó.** assistant.ps1:28441-28445 (el bloque del clima en el bucle: solo mira $ClimaOn y el temporizador, cero guardas de presencia), 19108 Update-Clima, 19258-19266 Test-BuenRatoParaTrabajo (la guarda buena, que ya existe y usa Get-InactividadMin). Conteos por hora sobre assistant.log + assistant.log.1.

**Cómo se hace.** La misma guarda que Test-BuenRatoParaTrabajo, aplicada a los cuatro temporizadores del bucle. El umbral de ausencia sale del p90 de las ausencias reales medidas (las lineas 'VUELTA: N min fuera'), no de un numero a mano.

**Riesgo y guarda.** Contestar con un dato viejo. Guardas: techo duro (nunca mas de N horas sin mirar, regla 2), refresco inmediato en cuanto vuelve la presencia -antes de que le de tiempo a preguntar- y EL OIDO QUEDA FUERA de esto: se puede hablar sin tocar nada, y dormirlo por inactividad la dejaria sorda.

> **El verificador corrigió el dato:** Clima en la franja: 55, no 54. Disco: 6 lineas 'DISCO: ' en la franja (de 50 en total), no 5. Y ojo con el 'como': el umbral NO puede salir del p90 de las lineas 'VUELTA: N min fuera', porque en los dos registros solo hay CINCO (71, 626, 123, 111 y 272 min); su p90 daria ~626 min, diez horas de ausencia, y la guarda no saltaria casi nunca. La via que si tiene datos es Get-AusenciaMin (12763), que ya mide en vivo, con el $TrabajoAusenciaMin = 15 que la casa ya usa para la copia.

### 113. Que Nova se mida a sí misma contra Steam, todos los días ∿

**Valor 5 · coste 5 · ángulo `juegos`**

**Qué.** Nova apunta el tiempo de juego con lo que ella ve, y ya sabemos que a veces ve el 2 %. Steam deja la fecha de la última partida escrita en disco, gratis y sin red. Que una vez al día compare las dos cuentas por su cuenta y, cuando no cuadren, lo apunte como un punto ciego suyo con nombre y fecha, en vez de seguir dando por buena su cuenta. Es el que cierra el bucle de la idea 1: el que descubre qué juegos no sabe ver.

**El dato.** En 14 días Nova vio ONCE juegos distintos en primer plano y solo OCHO tienen segundos guardados: Little Nightmares II, Little Nightmares III y Outlast se detectaron y no dejaron ni uno. El 25/09, NIGHTREIGN: Steam dice que la partida acabó a las 23:53 y Nova apunta 75 segundos. El 18/09 a las 18:48:42, dos minutos después de haber visto ELDEN RING en primer plano, Nova contestó 'no hay ningún juego abierto'. En total su memoria tiene 19,9 horas en 9 días, y solo hay UNA línea de batería por juego en todo el registro. Steam, en cambio, escribe LastPlayed en los 17 appmanifest sin pedir nada.

**Dónde se comprobó.** grep 'juego en primer plano' assistant.log assistant.log.1 -> 11 nombres distintos, contra las 8 claves de memoria\juegos.json; assistant.log.1 '2026-09-18 18:48:42 LOCAL: Cierra el juego -> no hay ningun juego abierto'; appmanifest_*.acf (campo LastPlayed, leído en assistant.ps1:1109 y usado solo para ordenar, nunca para comprobarse)

**Cómo se hace.** Una vez al día, en el hueco que ya existe para la nota semanal: para cada juego con LastPlayed de las últimas 24 h, se compara con los segundos que Nova apuntó ese día. Si lo suyo es menos de un tercio, se apunta el juego en memoria\juegos-ciegos.json con la fecha y la diferencia. Esa lista es la que dispara el aprendizaje de la idea 1 y la que permite decir, cuando braya pregunte cuánto ha jugado, 'lo que yo vi son dos horas, pero a este juego lo veo mal'.

**Riesgo y guarda.** Acusar de punto ciego a un juego que simplemente se jugó con Nova apagada (hay 10 arranques solo el 25/09). Guarda: solo se compara el tiempo en el que Nova estuvo viva, que ella ya sabe porque el cuaderno de la Ally apunta un tramo cada 10 s; si no hay cuaderno de esas horas, no se apunta nada y se dice en el log que no se puede juzgar.

### 114. Que la lista de «lo que decidí yo sola» deje de estar vacía ∿

**Valor 4 · coste 5 · ángulo `ficheros`**

**Qué.** Nova tiene una lista aparte en estadisticas.json para apuntar las decisiones que toma por su cuenta, y un párrafo semanal que las lee. La lista está vacía: ninguna de las tres etiquetas que la alimentan ha ocurrido nunca. Así que el parte semanal de «esto decidí yo» lleva saliendo en blanco desde que existe.

**El dato.** estadisticas.json -> decisiones = [] (lista vacía). En los 15 días de contadores diarios hay 3.243 eventos y NI UNO es 'auto-ajuste', 'auto-deshecho' ni 'arranque-medias' (grep de esas tres palabras en el fichero entero: 0 resultados). Y sí hay motor: 9 sitios escriben 'auto-ajuste', uno 'auto-deshecho' y uno 'arranque-medias'.

**Dónde se comprobó.** memoria\estadisticas.json (claves: dias, descartes, recientes, decisiones); `grep -o 'auto-ajuste\|auto-deshecho\|arranque-medias' memoria/estadisticas.json` -> vacío; `grep -c "Add-Estadistica 'auto-ajuste'" assistant.ps1` -> 9 (líneas 3376, 12170, 12198, 12240, 12298, 12335, 14629, 14642, 26295); assistant.ps1:3044 (solo esas tres rutas entran en 'decisiones'); assistant.ps1:20486 (Get-ParrafoDecisiones)

**Cómo se hace.** Apuntar como 'auto-ajuste' los números que Nova YA recalcula sola cada día y que hoy solo van al log: el plazo de la voz (p99 de las 118 muestras de voz-tiempos.json), el p75 de trabajo-tiempos.json, el ritmoBateria por juego de juegos.json y la ganancia del micrófono. Solo cuando el valor cambia respecto al último apuntado más de lo que cambia normalmente, para no apuntar ruido. El detalle ya trae el número, que es la regla de esa lista.

**Riesgo y guarda.** Llenar la lista de sesenta huecos con microajustes y que el parte semanal se vuelva ilegible. Guarda: el listón de «cambio que merece apuntarse» sale de la propia serie (la desviación de los últimos cambios), no de un porcentaje escrito, y el párrafo sigue diciendo como mucho cuatro.

> **El verificador corrigió el dato:** voz-tiempos.json tiene 119 muestras, no 118 (y es ventana movil de 200, asi que el numero cambia). Y OJO: uno de los cuatro candidatos ya existe a medias -la referencia f0 de tu voz YA escribe Add-Estadistica 'auto-ajuste' en 3376 cuando se mueve mas que MiVozDeriva-, asi que quedan tres nuevos: p99 del plazo de voz, p75 de trabajo-tiempos y ritmoBateria por juego.

### 115. Vigilar los ficheros de memoria, no solo las carpetas ∿

**Valor 4 · coste 5 · ángulo `ficheros`**

**Qué.** La vigilancia de costumbres mira tres carpetas. Nadie mira los ficheros sueltos. Hay once ficheros que el código sabe leer y escribir y que no se han creado nunca en toda la vida del proyecto, y cuatro más que llevan días congelados sin que nadie lo note.

**El dato.** El código nombra 28 ficheros .json dentro de memoria\ y solo existen 17. Los 11 que nunca se han escrito: ajedrez.json, arranque-oido.json, contactos.json, guia-tiempos.json, juegos-oidos.json, listas.json, logros-stamp.json, montajes.json, palabras-no.json, rechazos.json y trivia.json. Y de los 17 que sí existen, 4 llevan 3 días o más sin tocarse: fechas.json (11/09, 15 días), recordatorios.json (11/09, 15 días), musica.json (20/09, 6 días) y nube-tiempos.json (23/09, 3 días).

**Dónde se comprobó.** `grep -oE "MemoriaDir ['\"][a-z0-9-]+\.json['\"]" assistant.ps1 | sort -u` -> 28 nombres; `ls memoria/*.json` -> 17; comm de las dos listas -> los 11; fechas de `ls -la memoria/`

**Cómo se hace.** Una lista al estilo de Get-CostumbresPropias pero de ficheros, con el ritmo esperado sacado del propio historial: la mediana de días entre escrituras de los últimos 30 (se puede guardar en el mismo habitos.json, es un número por fichero). Si uno se pasa del triple de su ritmo, se apunta como 'auto-ajuste' —que de paso llena la lista vacía de la idea 6— y se dice una vez. Los once que no han nacido nunca no se avisan: no hay costumbre que romper, se listan en el parte semanal como «lo que sé hacer y nunca he hecho».

**Riesgo y guarda.** Avisar de un fichero que está parado con toda la razón (musica.json está parado porque no ha puesto música). Guarda: no hay aviso hasta que el fichero tenga al menos cuatro escrituras de historial, que es el mismo listón de la hora de dormir; con menos, se calla.

### 116. El saldo de su banco lo dijo la voz de Microsoft

**Valor 4 · coste 5 · ángulo `privacidad`**

**Qué.** Nova elegiria la voz por lo que va a decir, no solo por la configuracion. Hoy Say mira unicamente config.json. Pasaria a mandar por Piper, que es local y ya esta instalado, las frases que lleven dinero, banco, correo o salud, y seguir con la voz en linea para todo lo demas, que es lo normal.

**El dato.** De 213 frases que Nova ha dicho en voz alta, 12 llevaban dinero, banco o correo, y 5 eran de banco puro. Con voz.motor = online, el texto de cada una se POSTea a los servidores de Microsoft (edge-tts, es-MX-DaliaNeural). La peor, del 15/09 14:25:13: 'tienes 10940 no leidos, y hoy destacan una alerta de Chase de saldo bajo (7.23 dolares), una transferencia devuelta de 25 dolares'. Su saldo bancario, dicho por un servicio de terceros. Son 12 de 213: el 5,6 %, o sea que braya oiria la voz local muy de vez en cuando. Y Piper ya esta ahi: piper\es_MX-claude-high.onnx.

**Dónde se comprobó.** cat assistant.log assistant.log.1 | grep -cE 'REPLY:|ENTORNO \(' -> 213; ese mismo filtrado por chase|saldo|dolares|transferencia|banco|tarjeta|@gmail|correo|factura|deuda|pago -> 12; solo banco/dinero -> 5; assistant.ps1:17906 (Say) y 17952 (Say-Piper ya es el camino alternativo); el patron ya escrito en assistant.ps1:8134 ($RE_DATO_SENSIBLE); config.json:42 motor=online

**Cómo se hace.** En la funcion Say de assistant.ps1, antes de la eleccion de motor: si el texto casa con el $RE_DATO_SENSIBLE que YA existe en la linea 8134, intentar Say-Piper primero y solo caer a la voz en linea si Piper falla. Es un if y una llamada, porque Say-Piper (17049) ya esta escrita y ya es el camino de respaldo en 17952. Banco tools\probar-voz-local-sensible.ps1 que compruebe que una frase con 'saldo de Chase' no llega al worker en linea y una con 'abro Steam' si.

**Riesgo y guarda.** A braya no le gustan las voces roboticas, y esto le pone la voz local en algunas frases. Por eso se limita al 5,6 % medido y solo a dinero, banco, correo y salud, no a todo lo personal. El otro riesgo es la velocidad: Piper tarda mas en arrancar que la conexion ya abierta, asi que si Piper no responde en su plazo se sigue con la voz en linea, que es el comportamiento de hoy.

> **El verificador corrigió el dato:** 214 frases dichas, no 213. Y el dato que de verdad hay que corregir: $RE_DATO_SENSIBLE casa con 2 de las 214, no con las 12, y NO casa con 'alerta de Chase de saldo bajo (7.23 dolares), una transferencia devuelta de 25 dolares'.

### 117. Leer el fichero donde apunta las veces que la corriges ∿

**Valor 3 · coste 5 · ángulo `ficheros`**

**Qué.** Nova copia a importante.jsonl cada turno en que braya la corrige o en que ella admite que no sabe algo, y dice en su propio comentario que ese fichero «NO se poda nunca». Lo escribe y no lo lee nadie. Es el inventario de sus fallos y de sus agujeros, y está muerto en el disco.

**El dato.** memoria\cerebro\importante.jsonl: 518 bytes, 2 líneas, creado el 25/09 a las 21:49. Buscando 'importante.jsonl' en todo el código fuera de tools\: aparece UNA vez, en charla_worker.py:961, y en modo 'a' (añadir). Cero lectores. Y hay material: de los 783 dictados del registro, 69 (8,8 %) encajan con las propias reglas del fichero (RE_CORRIGE o un «no...» de cinco palabras o más); 61 de las 366 frases de charla.

**Dónde se comprobó.** charla_worker.py:955-968 (apuntar_importante, open(..., 'a')); `grep -rn importante --include=*.ps1 --include=*.py .` fuera de tools\ -> solo charla_worker.py:905,949,955,956,961,987; conteo de 69/783 y 61/366 con las regex RE_CORRIGE y RE_NEGACION del propio charla_worker.py aplicadas a las líneas «[escucha] dictado: '...'» y «CHARLA (...): ...» de assistant.log + assistant.log.1

**Cómo se hace.** Función nueva Get-Correcciones en assistant.ps1 que lea el jsonl (es una línea por objeto, barato). Dos usos: (1) el worker mete en el contexto de la charla «esto ya te lo corrigió el 25/09: ...» cuando la frase de ahora comparte palabras con una corrección de los últimos N días; (2) las líneas con por='agujero' se convierten en la lista de lo que Nova sabe que no sabe, que es justo lo que hoy no tiene.

**Riesgo y guarda.** Que meta correcciones viejas que ya no vienen a cuento y ensucie el prompt. Guarda: el plazo y el número de palabras en común no se escriben a mano, salen del propio fichero (se usa el corte que deja fuera al menos la mitad de las líneas), y como mucho entra UNA corrección por turno.

> **El verificador corrigió el dato:** 68 de 714 dictados (9,5 %), no 69 de 783 (8,8 %); y 318 lineas CHARLA distintas, no 366. Mismas regex RE_CORRIGE/RE_NEGACION del propio charla_worker.py sobre assistant.log + assistant.log.1.

### 118. La frase de ejemplo que se le da a Whisper no lleva el verbo que más falla ⬆ ∿

**Valor 5 · coste 6 · ángulo `oido`**

**Qué.** A Whisper se le pasa siempre la misma frase de ejemplo, escrita a mano el 14/09, para empujarle al español. Lleva 'Sube el volumen' y 'Baja el brillo', que casi no usa, y NO lleva 'cierra', que es su segundo verbo y justo el que el oído deforma sin parar. La idea es que esa frase la escriba Nova con sus propias órdenes: los verbos que de verdad dice, sacados de lo que ya apunta en destinos.jsonl, con las mismas reglas que ya están medidas (sin números y sin nombres de juegos, porque eso ya se probó y arrastraba).

**El dato.** 224 órdenes útiles en destinos.jsonl. Primeras palabras: 'abre' 23, 'cierra' 18, 'que' 13, 'dime' 6, 'pon' 4, 'baja' 4, 'sube' 1. La frase de ejemplo contiene 'sube' (1 orden real) y 'baja' (4) y no contiene 'cierra' (18). Y 'cierra' es precisamente lo que peor se oye: 21 veces en el registro salió como 'Sierra', 'Tierra', 'Cierro', 'Si es' o 'Si era' ('Sierra Gul', 'Tierra Sting', 'Si es a los ajutos', 'Si es el navegador').

**Dónde se comprobó.** wake_vosk.py:202 (PROMPT_ORDENES, con el comentario del 14/09 que explica por qué sin números ni nombres de juegos) y wake_vosk.py:205 (es_eco_del_ejemplo, que ya depende de esa frase). Conteo: primeras palabras de las 224 filas 'local/accion/traducir/traducida' de destinos.jsonl; y regex de sierra|tierra|cierro|si es|si era al principio de 'entregado' y 'texto' en registro.jsonl -> 12 + 9.

**Cómo se hace.** En assistant.ps1, donde ya se cuentan las estadísticas de uso, sacar los cinco verbos de cabeza más frecuentes de destinos.jsonl y escribir una frase en tmp (una oración corta por verbo, sin números y sin nombres de juegos, usando las plantillas que ya existen en las reglas). En wake_vosk.py, PROMPT_ORDENES deja de ser constante: se lee de ese fichero al arrancar y, si no está o está vacío, se queda la frase de hoy. es_eco_del_ejemplo ya parte la frase por puntuación, así que sigue funcionando sin tocarla.

**Riesgo y guarda.** Que el ejemplo arrastre a Whisper a repetirlo (el 14/09 se midió: con 'al treinta' dentro, 'pon el juego al ochenta' se oía 'al treinta'). Las dos guardas ya están escritas: la frase se genera sin números y sin nombres de juegos, y es_eco_del_ejemplo detecta cuándo Whisper ha devuelto el propio ejemplo y hace que el asistente pida confirmación en vez de ejecutar.

> **El verificador corrigió el dato:** Las cuentas se reproducen sobre las 224 filas local/accion/traducir/traducida de destinos.jsonl: abre 23, cierra 18, que 13, dime 6, pon 4, sube 1 — todas exactas menos 'baja', que son 3 y no 4. La frase de hoy ('Nova, abre Steam. Sube el volumen. Pon el modo noche. ¿Qué hora es? Baja el brillo.') efectivamente lleva 'sube' (1 orden real) y 'baja' (3) y no lleva 'cierra' (18). Y las deformaciones de 'cierra' al principio de lo entregado son 21 exactas: 'Tierra Steam y pon un tempón', 'Tierra el navegador', 'Sierra Ul', 'Sierra Gul', 'Sierra and the Ring', 'Tierra loja, avute'...

### 119. Rehacer el aviso aparcado en el momento de decirlo, no repetir el texto de hace horas

**Valor 5 · coste 6 · ángulo `log-uso`**

**Qué.** Cuando no hay nadie, Nova guarda el aviso con la frase ya escrita y lo suelta tal cual cuando braya vuelve. Si la frase lleva una cifra dentro -los gigas libres, el porcentaje de batería-, esa cifra es de hace horas. La idea es guardar la clave y los datos, no la frase, y rehacerla al decirla; y si el hecho ya no se cumple, tirarla en silencio.

**El dato.** 843 avisos 'disco-poco' aparcados en el registro, y su texto lleva el número dentro: 'Te quedan 10.2 gigas en el disco. Pregúntame qué ocupa más.' Las 46 lecturas 'DISCO:' del registro tienen 10 saltos de 1 GB o más en menos de una hora; el peor, 9,1 GB en UN minuto (25/09, de 35,7 a 26,6 entre las 22:09:26 y las 22:10:26); y el 25/09 el disco se movió en un rango de 35,2 GB en el mismo día (de 7,8 a 43,0). El 24/09 pasó de 10,7 a 5,2 GB en cuatro minutos y volvió a 8,5 media hora después. Ahora mismo hay un aviso esperando en tmp/avisos-esperando.json con vencimiento el 26/09 a las 02:25.

**Dónde se comprobó.** cat assistant.log.1 assistant.log | grep -c "ENTORNO aparcado.*disco-poco" -> 843; grep "DISCO: " assistant.log | para la volatilidad; cat tmp/avisos-esperando.json. Código: assistant.ps1:28608 (donde se compone el texto con $gbLibres dentro), :10925 Add-AvisoEspera (guarda clave, TEXTO, nivel, cada, vence), :10962 Send-AvisoEsperaSuelta y :10996, que llama a Send-AvisoEntorno con $v.texto tal cual.

**Cómo se hace.** Cambiar lo que guarda Add-AvisoEspera: en vez de 'texto', guardar 'clave' + 'datos' (una tabla con los gigas, el porcentaje o lo que toque) y un nombre de plantilla. En Send-AvisoEsperaSuelta, antes de soltar, volver a leer el dato (Get-DiscoLibre y la batería ya se leen en el mismo bucle), rehacer la frase y, si el hecho ya no se cumple, no decir nada. Si el dato no se puede releer, decir la frase sin la cifra.

**Riesgo y guarda.** Perder un aviso que sí importaba, que es justo lo que esta cola vino a evitar ('Nova prometió decirlos cuando braya volviera'). Guardas: solo se tira si el hecho ya NO se cumple, nunca por antigüedad; y si no se puede recalcular, se dice igual, sin número. Nota: no tiene número que aprender por sí sola, pero es la condición para que la prueba por hechos de la idea anterior no mida sobre cifras podridas.

> **El verificador corrigió el dato:** Las lecturas 'DISCO:' son 50, no 46. Y el aviso que hay aparcado ahora mismo en tmp/avisos-esperando.json no vence el 26/09 a las 02:25 sino a las 03:07:47, y es 'gmail-lleno' -que precisamente NO lleva cifra dentro-, asi que ese ejemplo concreto no prueba nada; lo que prueba la idea son las 843 aparcadas de disco-poco, que si la llevan.

### 120. Lo que Nova dice al entrar en un juego: los dos listones que no saltan nunca y la tarjeta muda ∿ ⚙

**Valor 4 · coste 6 · ángulo `tiempo+juegos`**

**Qué.** Al entrar en un juego Nova tiene dos bocas y las dos estan cerradas. La primera, Get-FraseJuegoNotado, comenta una racha o una vuelta, pero sus dos listones son numeros escritos a mano ($JuegoRachaMin = 3, $JuegoVueltaDias = 10) que los datos de braya no alcanzan nunca: no estan rotos, estan puestos donde el no llega. La segunda, Show-RecuerdoJuego, deberia decir 'te quedaste en...' o 'bateria para...', y sus dos fuentes estan practicamente vacias, asi que la tarjeta no ha salido ni una vez en catorce dias. Que los dos listones salgan de los propios huecos y rachas de braya, y que la tarjeta diga ademas lo que Nova SI sabe siempre: cuantas horas lleva con ese juego y cuando fue la ultima vez.

**El dato.** memoria/juegos.json tiene 8 juegos y 17 pares (juego, dia), 9 dias con juego, ventana de 60 dias. Los NUEVE huecos entre partidas del mismo juego son 1, 1, 1, 1, 1, 2, 2, 4 y 5 dias (ELDEN RING 1,1,5; It Takes Two 1,4,2,1; A Way Out 1; Unravel Two 2): el maximo es CINCO y JuegoVueltaDias=10 no se ha alcanzado ni una vez. La racha maxima es 3 (ELDEN RING el 18, 19 y 20/09) y JuegoRachaMin=3 exige un CUARTO dia seguido, que nunca hubo: tras el 20 vienen 5 dias de hueco. Las dos ramas estan muertas por construccion, no por un fallo, y 'juego-notado' sale 0 veces en los dos registros (14 dias). Con la convencion de percentil que ya usa la casa -Floor((n-1)*p), la de Get-VentanaSeguimiento (22595) y la de la linea 13987- el p90 de los 9 huecos es 4, no 5; con los 8 huecos que estaban guardados el 25/09 tambien da 4. El p80 con esa misma convencion da 2, demasiado bajo para ser el liston. El 25/09 ELDEN RING llevaba 5 dias sin tocarse: habria hablado con 4 o con 5. La otra boca: la linea 'JUEGOS: al entrar en' sale CERO veces en los dos registros (0 y 0 en assistant.log y assistant.log.1, 14 dias). Ninguno de los 8 juegos tiene nota, porque la pregunta 'dime donde te quedaste' salio 4 veces ('juego-cierra' = 1 + 3) y se quedo sin respuesta las 4. Solo 1 de los 8 tiene ritmoBateria (The Past Within, 30) y ademas hace falta estar sin cargador: hay 7 desenchufes en 14 dias. En cambio los minutos por dia y por juego estan en los 17 pares: esa fuente no esta vacia nunca.

**Dónde se comprobó.** assistant.ps1:8721-8722 ($JuegoRachaMin = 3, $JuegoVueltaDias = 10), 8723-8758 (Get-FraseJuegoNotado), 8760-8776 (Get-DiasDeJuego), 8864-8871 (Get-DuracionBateriaJuego), 8885-8901 (Show-RecuerdoJuego), 20606 (la llamada a Show-RecuerdoJuego al abrir el juego) y 28286-28287 (Send-AvisoEntorno 'juego-notado' 'bajo' 720); convencion de percentil en 22595 (Get-VentanaSeguimiento) y 13987 (Get-GuiaPlazoMs); memoria/juegos.json entero; grep -c 'JUEGOS: al entrar' assistant.log assistant.log.1 = 0 y 0; grep -c 'juego-notado' = 0 y 0; grep -c 'juego-cierra' = 1 y 3.

**Cómo se hace.** Tres piezas, todas sobre el mismo fichero que ya esta en disco y sin nada residente. (1) Dos funciones pequenas sobre juegos.json, recalculadas al leerlo y al guardar un dia nuevo, sobre los 60 dias que ya guarda: vuelta = max(3, p90 de TODOS los huecos observados con la convencion de la casa, Floor((n-1)*0.9)) -> hoy 4 dias; racha = max(3, la racha mas larga que haya encadenado con ESE juego), y se habla al IGUALARLA (>=), no al superarla: con el record en 3, igualar es lo que el hizo el 20/09 y superarlo es lo que no ha hecho nunca, asi que 'un dia mas que el record' dejaria la rama tan muerta como esta. (2) Show-RecuerdoJuego gana una tercera parte que no depende de ningun dato nuevo y no esta vacia nunca: 'llevas N horas con esto' (suma de los dias de ese juego en juegos.json) y 'la ultima vez fue hace N dias' (el mismo hueco del punto 1), junto a la nota y la bateria cuando las haya. Sigue siendo capsula sin voz, con su tope de 70 caracteres y su una-vez-por-hora. (3) Guardas: si hay menos de 5 huecos guardados para ese calculo se usan los fijos de hoy y se apunta en el log 'sin datos suficientes' (regla 3); los dos listones se escriben en el log con la cuenta de la que salen; suelo fijo de 3 dias en los dos; y se conservan las guardas que ya estan escritas, una vez al dia y solo si hoy todavia no ha jugado a ese juego.

### 121. La pantalla lleva seis dias encendida y la consola esta puesta para no apagarla nunca ∿

**Valor 3 · coste 7 · ángulo `consola`**

**Qué.** La consola esta configurada para no apagar la pantalla jamas, ni enchufada ni con bateria, y para no suspenderse nunca. Con la senal de presencia de la idea 1, Nova podria apagar la pantalla ella cuando lleva un rato sin haber nadie, y devolverla al primer movimiento. No toca la configuracion de Windows, no deja ningun modo puesto y cualquier toque la enciende.

**El dato.** powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE da indice 0x00000000 en corriente alterna Y en continua: "apagar la pantalla tras" = nunca. Lo mismo SUB_SLEEP STANDBYIDLE: nunca se suspende. Leerlo cuesta 111 ms. WmiMonitorBrightness marca CurrentBrightness = 100. La consola lleva 158,9 horas encendida (arranco el 19/09 a las 09:18) y el informe de Windows confirma 23 h y pico activa cada dia durante once dias seguidos, con el tiempo en suspension moderna a PT0S casi siempre. Y hay 4.140 lineas de avisos aparcados por no haber nadie: no son ratos cortos, son noches enteras con la pantalla encendida a tope y el chip a 65-69 grados. Nova no lee nada de esto: 0 apariciones de LastBootUpTime, powercfg o uptime en las 28.720 lineas, y el plan de energia activo (Turbo, de ASUS) tampoco lo ve, porque Get-ModoEnergia lee el deslizador de Windows, que es otra cosa.

**Dónde se comprobó.** Mediciones: powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE y SUB_SLEEP STANDBYIDLE (ambos 0x00000000 en AC y DC); Get-CimInstance -Namespace root/wmi WmiMonitorBrightness -> 100; Win32_OperatingSystem.LastBootUpTime -> 19/09 09:18, 158,9 h; powercfg /list -> Performance, Equilibrado, PD Turbo, Turbo (activo). Codigo: assistant.ps1:21309-21324 (el bloque Nova.Win de user32, donde NO hay SendMessage), assistant.ps1:13196 (Get-ModoEnergia, que lee el overlay y no el plan), assistant.ps1:12528 (el nivel de altavoces que deja el worker en escucha-estado.txt).

**Cómo se hace.** Anadir SendMessage al bloque Nova.Win que ya existe (21309) y una Set-PantallaApagada que mande WM_SYSCOMMAND / SC_MONITORPOWER a HWND_BROADCAST: una linea de P/Invoke y una llamada. Se dispara desde el bloque del minuto cuando Get-MovimientoMin y Get-InactividadMin digan las dos que no hay nadie desde hace mas de lo medido, nunca con un juego delante y nunca mientras suene algo -el nivel de altavoces ya esta en escucha-estado.txt, campo 3, y Nova ya lo lee (12528)-. Salidas: cualquier toque de teclado, raton, mando o pantalla la enciende sola, y ademas Nova la enciende en cuanto ve movimiento.

**Riesgo y guarda.** Apagarle la pantalla mientras mira un video o una guia sin tocar nada. Tres guardas: depende de la senal de MOVIMIENTO de la idea 1 y no solo del teclado; nunca si los altavoces estan dando nivel; nunca con un juego delante. Y cumple la regla de los modos: dos salidas (cualquier entrada del sistema, y la propia Nova al detectar presencia) mas un plazo, y no queda nada puesto ni se cambia ninguna opcion de energia de Windows.

> **El verificador corrigió el dato:** Leer powercfg /query cuesta 138 ms, no 111. El arranque es del 19/09 09:18:13, o sea 159,8 h ahora mismo (decia 158,9; es que el reloj sigue corriendo). Todo lo demas, clavado: VIDEOIDLE 0x00000000 en alterna Y en continua, STANDBYIDLE 0x00000000 en las dos, CurrentBrightness = 100, y los planes Performance / Equilibrado / PD Turbo / Turbo (este ultimo el activo).

---

# Lo descartado, y con qué dato

*Esto es lo que más vale de la lista. Trece ideas que parecían buenas y no lo eran, cada una con
la comprobación que la tumbó. Descartar con un número es tan útil como implementar, y más barato.*

## Las ocho que Nova ya hacía, o que ya estaban descartadas por escrito

### ~~La queja que rehace la orden se muere en la puerta del verbo~~

*Ángulo `muertas`.* SE HIZO ANOCHE, y ademas la mitad que proponia la idea se rechazo alli mismo por escrito. El commit 64f7ae8 del 25/09 metio en Invoke-FastCommand (assistant.ps1:4643-4697) el bloque "NO DIJE DISCORD, DIJE STEAM" con $reNiegaDoble y $reNiegaPedi (4678-4679): hoy esa frase SI hace algo -- devuelve 'noEraEso' (deshacer y olvidar la traduccion envenenada) y, si lo corregido resuelve, ejecuta la orden buena. Es el caso exacto que cita la idea, con su mismo ejemplo. Y lo que la idea propone -- pegarle el verbo de la orden anterior a un nombre suelto -- esta descartado ahi con su medicion y su razon: "Y NO SE ADIVINA EL VERBO: de 'no dije discord, dije Steam' sale 'steam' a secas, que no resuelve a nada (comprobado: los 317 patrones de esta funcion...). Nova deshace y olvida, y no abre Steam por su cuenta: adivinar que hacer con un nombre suelto es la regla 1 al reves", medido sobre 737 dictado...

### ~~El silencio que cierra la frase, medido con sus grabaciones de verdad~~

*Ángulo `numeros-fijos`.* DESCARTADA CON UN DATO en AUTONOMIA.md:694-697: «⚠ Y de paso queda descartada una «mejora» que parecia obvia: bajar SILENCIO_FIN para ganar tres decimas por orden. Esos valores se SUBIERON a proposito, medidos sobre 90-110 grabaciones, porque las pausas a proposito llegan a 1,44 s. Bajarlos cortaria ordenes por la mitad». El COMO de la idea es exactamente eso: silencio_para_cerrar() devolveria p95/p90 con techo en los 1,5/1,1 de hoy, o sea que solo puede BAJARLOS. Y sus propios numeros corregidos (p95 = 1,15 s) quedan por debajo del 1,44 medido de las pausas a proposito, o sea que cortaria ordenes: justo el dano que el documento ya midio. (Lo unico no cubierto por el descarte es SILENCIO_SIN_PALABRA = 3,2, que el COMO de la idea ni siquiera menciona.)

### ~~El margen de "eres tú" está escrito a mano y los datos dicen que falla por los dos lados~~

*Ángulo `ordenes-fallidas`.* DESCARTADA CON UN DATO, y el proyecto ya cazo el mismo error de premisa. (a) La premisa es falsa: dice '35 Hz para solo yo', pero config.json:73 pone soloYoMargenHz = 42; el 35 es solo el valor por defecto del codigo (assistant.ps1:18176). AUTONOMIA.md:699-701 tumbo una idea identica el 18/09 senalando exactamente eso: 'la idea cita el valor por defecto del codigo: config.json ya tiene 42'. (b) El margen asimetrico tampoco sale: AUTONOMIA.md:699-715 y REVISION-2026-09-18.md:656-658 demuestran que 'no existe un valor que sirva' porque la segunda voz de la casa esta a +28,6 Hz de braya y braya llega a +37 Hz gritando, los DOS hacia ARRIBA: 37 > 28,6. Estrechar el margen de arriba -que es justo lo que pide la idea- rechaza a braya cada vez que alza la voz. (c) Con los datos de HOY esta peor, no mejor: tmp/voces.json da braya 115,8 Hz (433 muestras) y la segunda voz mas oida 138,1 Hz (152 mu...

### ~~La ganancia se pelea consigo misma y anoche seguía haciéndolo~~

*Ángulo `ordenes-fallidas`.* El camino concreto que describe YA ESTA GUARDADO, y lo que queda es la idea 21 de esta misma tanda. (a) Dice 'el pulso la vuelve a subir a la ultima buena, que es justo la que saturo': esa rama (wake_vosk.py:4059) ya exige 'ahora - ultimo_recorte > RECORTE_RECIENTE' (45 s) y ademas cabe/ganancia_buena solo se sella en pulsos con pulsos_ruidosos==0 (:4144-4151), y la guarda de altavoces ya existe (:3514-3519). Medido: en 16 dias solo hay 17 lineas 'vuelvo a la x' en TODO el registro, la ultima el 24/09 13:20, y NINGUNA cerca de los 99 recortes de hoy. O sea que la sierra de anoche y de esta madrugada no sale por ahi. (b) La sierra real sale de la rama de CALIBRACION del pulso, que es exactamente lo que pide la idea 21 (mismo techo, mismo min(), mismo fichero hermano de ganancia.txt). Implementar las dos seria hacer dos veces el mismo trabajo, y la 21 ademas diagnostica bien de donde viene...

### ~~Un juego no dura once segundos: sus dos cuadernos se contradicen 54 veces y no se entera~~

*Ángulo `ordenes-fallidas`.* La mayor parte YA ESTA y el resto es la idea 22 de esta misma tanda. (a) El aplazamiento que pide existe desde el 19/09 (C4): Exit-Juego no anuncia nada, apunta una salida EN DUDA en $script:juegoSalida (assistant.ps1:20708-20714) y Test-SalidaJuego (:20758) solo cierra cuando Test-JuegoVivo dice que el PROCESO murio, con su plazo de 2 h; ademas tiene ya la rama 'ha vuelto al mismo juego: no era una salida' (:20762). (b) Lo de 'pone el tiempo de partida a cero' es falso: Enter-Juego:20603 hace 'if (-not ($script:juegoSalida -and $script:juegoSalida.nombre -eq $nombre)) { $script:juegoSesionMin = 0 }', o sea que volver al mismo juego YA suma en vez de reiniciar. (c) Su propia correccion dice que el arreglo hay que meterlo en Exit-Juego, que es exactamente donde lo mete la 22, en las mismas tres lineas. (d) La mitad de la palabra de activacion esta descartada en IDEAS-2026-09-22-TERCERA.md...

### ~~Los silencios que cierran la frase, medidos con sus 560 grabaciones de verdad~~

*Ángulo `oido`.* ESTA DESCARTADA CON UN DATO, y ademas el numero ya salio de una medicion de pausas reales. AUTONOMIA.md:694: «⚠ Y de paso queda descartada una "mejora" que parecia obvia: bajar SILENCIO_FIN para ganar tres decimas por orden. Esos valores se SUBIERON a proposito, medidos sobre 90-110 grabaciones, porque las pausas a proposito llegan a 1,44 s. Bajarlos cortaria ordenes por la mitad — y cortar una orden sale mucho mas caro que esperar 0,3 s.» El p95 que la propia idea mide es 1,35 s, POR DEBAJO de ese 1,44 s medido: el valor adaptativo que propone es exactamente el corte que el documento prohibe, y chocaria con la regla 7 y con la meta del 100 %. Y AUTONOMIA.md:689 anade que SILENCIO_FIN y SILENCIO_FIN_LOTENGO ya se calcularon asi, de los huecos de sus grabaciones ('llegaste a 0,81 s... y con pausas a proposito a 1,44 s'), o sea que el metodo que la idea propone ya se aplico una vez. Encima...

### ~~El tope de cuatro avisos por hora se borra cada vez que Nova arranca~~

*Ángulo `iniciativa`.* DESCARTADA CON UN DATO en IDEAS-2026-09-23.md:152 (commit 24d55a7, 23/09 a la 01:49), en la lista 'Porque el mecanismo culpado no es el que corre hoy': 'el cupo de 4 avisos por hora si se rearma, pero los 4 casos de dano son fosiles de dos fallos ya arreglados y el beneficio medido es cero'. Es exactamente este mecanismo, con el mismo diagnóstico. Reproduje la medición yo mismo y sale clavada a la de la idea (46 de 97 avisos con reinicio en la hora previa; 5 casos con 4+ avisos en los 60 min anteriores, los cinco tras un reinicio), o sea que la idea no aporta un mecanismo nuevo: aporta UN caso más que el descarte, el del 23/09 21:36:32 (reinicio a las 21:35:29, 63 s antes), que es posterior al descarte por unas 20 horas. Lo dejo escrito por si alguien quiere reabrirla: es 1 caso en los 3 días posteriores al descarte y CERO en los últimos 3 días (24, 25 y 26/09). Con la regla de matar ant...

### ~~El plazo de 6 s para contestar corta justo por la mitad de lo que braya tarda~~

*Ángulo `mando`.* DESCARTADA CON UN DATO EN LOS DOCUMENTOS. AUTONOMIA.md:787 es literalmente el punto 40 de la lista de numeros que podrian autoajustarse: '**40. confirmacion.esperaMs.** - **NO PROCEDE: medido, y el 3,5 ya esta bien (18/09)**', con los siete tiempos de respuesta medidos, el argumento de que el vencimiento ya es inofensivo ('CALLARSE NO EJECUTA NADA', que sigue vivo hoy en assistant.ps1:24085) y el freno de datos (las 7 respuestas eran todas del mismo dia). En codigo tampoco esta hecho, pero la regla dice matar lo descartado con dato. Dos avisos honestos por si braya quiere reabrirlo: (a) ese descarte se midio con esperaMs = 3500 y hoy config.json dice 6000, o sea que el numero cambio a mano DESPUES del analisis -exactamente el caso que prohibe el punto 61 de AUTONOMIA.md, 'no decidir con datos anteriores al arreglo de lo que se mide'-; (b) el freno de datos que lo tumbaba (todo de un solo...

## Las cinco cuyo número medía otra cosa

### ~~Los quince gigas del disco son gigas y deberian ser horas~~

*Ángulo `numeros-fijos`.* MUERTA POR LA REGLA 3: el numero del que cuelga toda la idea no se reproduce a ningun percentil, y lo que mide no es consumo sino vaiven. pruebaQueHice: python sobre las lineas 'DISCO: N GB libres' de los dos logs -> 51 lecturas (el 'dato' decia 46, la correccion 50; hoy 51), disco libre entre 5,2 y 44,9 GB (la correccion acierta, el 'dato' decia 43,0), y TODAS caben en 2,6 dias: de 2026-09-23 10:32 a 2026-09-26 01:53. Las dos bajadas citadas: 10,7 -> 5,2 GB el 24/09 de 23:34 a 23:38 EXACTA; la segunda no, el log da 13,6 a las 16:10 y 6,8 a las 22:55 del 23/09, 6 h 45 min, no 'una hora y 45 minutos'. LO QUE LA MATA: 'con ese ritmo, 15 gigas son menos de dos horas de margen' no sale. Calculando los ritmos entre lecturas consecutivas: 17 bajadas y 13 SUBIDAS -el disco sube tanto como baja-, mediana 1,5 GB/h -> 15 GB serian 10 horas de margen, no dos; y el p90 que la propia idea propone usa...

### ~~Los ocho juegos que estan en la tarjeta que no esta puesta~~

*Ángulo `consola`.* El dato sale CLAVADO y aun asi no sostiene la idea. libraryfolders.vdf declara dos bibliotecas: la 0 en C: con 17 appids (y hay exactamente 17 appmanifest_*.acf en disco) y la 1 en E:\SteamLibrary con totalsize 1.000.163.246.080 y 10 appids; Test-Path E:\SteamLibrary = False y [System.IO.DriveInfo]::GetDrives() solo da C: y D:. Quitando los dos repetidos (1817070 y 2358720) quedan 8 exclusivos que suman 734.289.177.929 bytes = 683,9 GiB EXACTOS, y uno de ellos (2139460) trae 0 bytes: son 7 con contenido, como decia la correccion. Get-JuegosSteam (1109-1160) hace `continue` cuando el Test-Path falla y no abre nunca el bloque "apps" ✓, y el vdf solo trae appid y bytes, sin nombres ✓. Lo que la mata es el DANO: `grep -hi "no lo tienes\|no esta instalado\|ficha en la tienda\|abro la tienda" assistant.log assistant.log.1` -> 0 lineas, y "SteamLibrary" -> 0 en las 58.751 lineas de los dos regi...

### ~~Nova revisa sola cuáles de sus 33 gestos están muertos y por qué~~

*Ángulo `capsula`.* MUERTA: el dato que la sostiene mide otra cosa, y al reves. Lo que SI reproduce: el switch de Gesto() tiene 33 case entre nova_ui.cs:2429-2625, y awk '{print $3}' tmp\gestos.log | sort -u dice que faltan CINCO, no cuatro -calma, determinacion, disculpa, sueno Y logro-, tal como avisa la correccion; y escucho+grito+duda = 1454+432+427 = 2.313 de 3.557 = 65 %, clavado. Lo que NO reproduce es el corazon de la idea. Comando: script python que busca callate/duerme/silencio/perdon/lo siento/disculpa/despacio/tranquilo en TODOS los campos de texto de los 1.037 registros de pruebas\audio\uso\registro.jsonl -> 6 aciertos, no 7, y los seis son de UN SOLO MINUTO del 15/09 (13:19:59 a 13:20:40), cuatro de ellos la misma frase repetida cuatro veces. Y al leerlos se cae la tesis entera: son 'Pero lo estas repitiendo, te estas DISCULPANDO y no estas abriendo Steam' y 'Me pidas disculpas y lo abras'. Br...

### ~~El cuaderno de voces está lleno, y dos de las cuatro son él~~

*Ángulo `oido`.* MUERE: el numero central mide OTRA COSA. Reproducido lo de fichero y codigo, todo exacto: `cat tmp/voces.json` -> [{115.8,n=433},{172.6,n=33},{138.1,n=152},{234.1,n=24}]; `sed -n '2095,2125p' wake_vosk.py` -> ventana `<= 22`, tope 4, `return 0` cuando esta lleno; 138,1-115,8 = 22,3; `cat tmp/mi-voz.json` -> {"f0":121.2,"n":60,"base":116.7}; MARGEN_CORTE_HZ = 42.0 en :2532; regla de voz ajena (>70 Hz Y <=4 palabras Y solo por nombre) en :3742; `grep -h 'voz: tono' assistant.log assistant.log.1 | awk` -> 691 medidas, 71 a mas de 70 Hz de 121,2; `ls pruebas/audio/uso/*.wav | wc -l` -> 560. PERO: (1) la entrada de 138,1 Hz NO es braya. `grep -n 'segunda voz|otra voz' AUTONOMIA.md` -> :194 'la segunda voz de la casa esta en 144,0 Hz' y :709 la tabla la lista como 'otra voz' (144,0 Hz, n=42), separada de la suya. Es la persona que usa el boton, derivada hoy a 138,1 con n=152. Las '585 medidas ...

### ~~Que se de cuenta de que su cara y su oido de respaldo estan compilados de hace dias~~

*Ángulo `errores`.* MUERE: el dato gordo mide otra cosa, y el otro es estado del disco de hoy. 1) wake_worker.exe NO es una compilacion de wake_vosk.py. ls -la wake_worker* -> existe wake_worker.cs (4.861 bytes, 10/09 19:04) junto a wake_worker.exe (10/09 19:04): el exe esta AL DIA con su propia fuente, al segundo. Es el worker de SAPI en C# que el comentario de assistant.ps1:18330 describe como alternativa; wake_vosk.py es el de Vosk. Compararlos y decir '15 dias, 84 commits y +5.012/-834 por detras' es medir dos piezas que nunca tuvieron que ir juntas. Los numeros sueltos si salen (git log --oneline --since=2026-09-10 -- wake_vosk.py | wc -l = 84; --numstat = +5012 -834), pero no dicen lo que la idea dice que dicen. 2) Y esa rama no corre: assistant.ps1:17998 lee escucha.motor con 'vosk' por defecto, config.json trae motor='vosk', y grep -c 'wake_worker' sobre assistant.log + assistant.log.1 da 0 y 0. El ...

---

# Los duplicados entre ángulos

Veinte buscadores a ciegas encuentran la misma cosa desde sitios distintos. Tres lentes
independientes marcaron 25 grupos de posible solape; un agente por grupo los resolvió con el
código delante. **Once eran la misma idea y cuatro más lo eran en parte; catorce grupos
resultaron ser cosas distintas que sólo compartían tema.**

| Ideas | ¿Eran la misma? | Qué las unía o qué las separa |
|---|---|---|
| 14 + 56 | **Sí** | Son la misma idea, y el código lo deja sin discusión. Las dos tocan la MISMA función, silencio_para_cerrar() en wake_vosk.py:229, para conseguir el MISMO efecto: que deje de devolver constantes y devuelva un percentil de las pausas medidas dentro de las órdene... |
| 13 + 28 + 57 | No | 13 y 28 SI son la misma: las dos quitan el mismo numero de la misma linea (assistant.ps1:24206, $ReintentoMaxMs = 15000) para ponerle a cada motor un plazo sacado del p90 de sus propias medidas, y las dos lo hacen en los mismos tres sitios donde se fija $scrip... |
| 16 + 30 + 58 | No | Las tres hablan del oido y de descartes de la palabra de activacion, pero cada una toca una funcion distinta, se dispara con una senal distinta y deja los fallos de las otras enteros. Mirado en el codigo: (1) La 16 mueve UMBRAL_ALTAVOZ (wake_vosk.py:606), que ... |
| 21 + 25 + 79 | **Sí** | Las tres son el mismo arreglo: aprender un TECHO de ganancia a partir del recorte y meterlo en el min() de las ramas que la suben. Mirado en el codigo, en wake_vosk.py solo hay DOS caminos que suben la ganancia: (a) la vuelta a ganancia_buena dentro de la rama... |
| 71 + 82 | **Sí** | Son la misma en lo que las define, y lo he comprobado en el codigo. Las dos existen para lo mismo: saber cuales de los 424 catch vacios de assistant.ps1 disparan de verdad. La 82 lo consigue editando 100 de esos sitios a mano (los 64 del bucle y los 36 de Invo... |
| 26 + 83 | No | Comparten la MISMA prueba (las 4 lineas "fallo en una vuelta del bucle: name 'callado' is not defined" del 25/09 y el turno perdido de las 21:33) y el mismo bloque de codigo de entrada: el except de wake_vosk.py:4164-4175. Por eso los revisores las juntaron. P... |
| 63 + 68 + 92 | No | NO son la misma. Los tres revisores las agruparon por TEMA ("la noche"), pero cada una agarra un extremo distinto del intervalo, o directamente otro trabajo.  El silencio nocturno es un intervalo [nocheDesde, nocheHasta) que se calcula en assistant.ps1:10287-1... |
| 15 + 93 | **Sí** | Son la misma, y no por tema sino por codigo: las dos crean UNA funcion de siembra que corre una vez al arrancar, lee los mismos dos ficheros (assistant.log + assistant.log.1), busca la misma linea (la 'ENTORNO (clave, nivel):' de assistant.ps1:11032), aplica l... |
| 64 + 98 | **Sí** | Si son la misma, y es el caso intermedio: la 98 se come a la 64 entera. Mirando el codigo, el "como" de la 64 es exactamente el primer parrafo del "como" de la 98 -las mismas dos lineas 8721-8722 y la misma Get-FraseJuegoNotado (8723), para el mismo efecto: qu... |
| 22 + 29 + 99 | **Sí** | Las tres hablan del mismo tema (el alt-tab del juego) pero solo DOS tocan el mismo codigo para el mismo efecto. La 22 y la 29 son la misma: las dos aplazan lo que hace Exit-Juego (assistant.ps1:20670) al perder el primer plano. La 22 es el caso pequeno -solo e... |
| 33 + 101 | **Sí** | Son la misma. Las dos atacan exactamente el mismo punto del codigo y el mismo fallo: en Get-JuegosSteam (assistant.ps1:1109-1160) el bucle solo saca "path" de libraryfolders.ic vdf y, cuando Test-Path de la carpeta steamapps falla, hace 'continue' (linea 1133)... |
| 95 + 102 | No | Comparten tema (juegos y el LastPlayed de los appmanifest) y hasta comparten un dato -los 75 s que Nova apunto de NIGHTREIGN el 25/09-, pero tocan funciones distintas y arreglan fallos distintos.  La 95 toca la DETECCION: crea memoria/juegos-exes.json, escribe... |
| 12 + 117 | No | NO son la misma: comparten la evidencia (las 110 correcciones a mano de commands.json y que casi ninguna se ha oido nunca) pero tocan funciones distintas y van en direcciones OPUESTAS. La 12 toca Repair-Words (assistant.ps1:338-346), que recorre $cmds.correcci... |
| 46 + 120 | **Sí** | Las dos atacan la MISMA cadena y el MISMO fallo: braya corrige hablando, el detector no casa, y el recuerdo equivocado se queda 'firme'. Las dos acaban en la misma funcion de destino, charla_memoria.marcar_incorrecta (charla_memoria.py:708), a la que hoy solo ... |
| 31 + 122 + 125 | No | Miradas contra el codigo, no son tres ideas sino dos. 122 y 125 SI son la misma, y 31 no. 122 y 125: la 125 dice literalmente que Get-EnLaMesa "devuelve cierto solo si la orientacion es plana Y la quietud del mando (idea 2) pasa del umbral aprendido", o sea qu... |
| 20 + 123 | **Sí** | Son la misma. Las dos cambian exactamente la misma pieza: $ConfirmacionMs (assistant.ps1:23857, config.json confirmacion.esperaMs = 6000) deja de ser un numero escrito a mano y pasa a calcularse con los tiempos de respuesta medidos. Y las dos lo sustituyen en ... |
| 37 + 124 | No | NO son la misma: comparten el sintoma (la linea 'CAPSULA CIEGA' sale 0 veces y por eso no ha vibrado nada nunca), pero cada una toca una funcion distinta y arregla un fallo distinto, y la otra se queda con todo su trabajo por hacer. La 37 ataca la DETECCION: T... |
| 74 + 128 | **Sí** | Son la misma. Las dos nacen de la MISMA medicion tirada -la linea 'primera frase en N s' que charla_worker.py:550 emite y que Receive-Charla escribe y descarta en assistant.ps1:22953- y las dos la recogen en ESE mismo punto, que es el unico donde llega. Las do... |
| 23 + 131 | No | Comparten el tema (la cola de avisos aparcados, tmp/avisos-esperando.json) pero tocan funciones distintas para arreglar fallos distintos, y ninguna deja a la otra sin trabajo.  La 23 toca Add-AvisoEspera (assistant.ps1:10925) para cambiar LO QUE SE GUARDA -hoy... |
| 9 + 50 + 133 | No | Las tres hablan del mismo fichero muerto (importante.jsonl, escrito en charla_worker.py:961 y sin un solo lector fuera de dos bancos), pero eso es TEMA, no trabajo. Mirando lo que tocaria cada una: la 9 y la 50 SI son la misma. Las dos leen exactamente las mis... |
| 80 + 127 + 135 | No | 80 y 127 SI son la misma: las dos tocan charla_worker.py, ponen un diccionario de estado al lado de OLLAMA, frenan con espera que se dobla los mismos reintentos (el POST de resumir_dias_pasados en :1046 y completar_vectores en :753), las dos limitan el freno a... |
| 1 + 137 | No | Comparten el MISMO dato de diagnostico (cero 'auto-ajuste', 'auto-deshecho' y 'arranque-medias' en memoria/estadisticas.json, con 9 sitios que escriben auto-ajuste), pero arreglan dos silencios distintos en funciones distintas, y ninguna deja a la otra sin tra... |
| 77 + 138 | No | NO son la misma: solo comparten una astilla, y ninguna deja a la otra sin trabajo.  Qué caza cada una, mirado en el código:  - La 77 no mira ficheros, mira CLAVES dentro de un fichero que está vivo. Cruza las 88 llamadas a Add-Estadistica (assistant.ps1:3009) ... |
| 88 + 141 | No | Comparten el tema ("el cronometro $sw arranca en cero con el proceso"), pero arreglan fallos distintos, en funciones distintas y con formas de dato distintas; implementar una deja el trabajo de la otra intacto.  88 toca el PRESUPUESTO POR HORA de los avisos de... |
| 73 + 143 | **Sí** | Son la misma, y ademas es el caso de una grande que se come a una pequena. Mire las cuatro lineas en el codigo y coinciden literalmente: el "como" de la 143 dice "un Add-Estadistica 'oido-muerto' y otro 'capsula-muerta' justo donde hoy se escribe el WARN (2709... |

*Que catorce de veinticinco fueran falsos positivos es el motivo de que esto lo resuelva un agente
por grupo mirando el código, y no una votación entre lentes: dos ideas sobre el oído no son la
misma idea.*

