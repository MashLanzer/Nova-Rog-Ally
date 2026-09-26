export const meta = {
  name: 'nova-ideas-autonomia-100',
  description: 'Barrido de 20 angulos sobre el codigo y los datos reales de Nova para proponer ideas nuevas de autonomia, cada una verificada contra el codigo',
  phases: [
    { title: 'Buscar', detail: '20 angulos distintos, cada uno leyendo codigo y datos reales' },
    { title: 'Verificar', detail: 'cada lote contra el codigo: ya existe? hay dato? se puede hacer?' },
  ],
}

const RAIZ = 'C:\\Users\\braya\\Documents\\voice-ctrl'

const CASA = `
PROYECTO: Nova, un asistente de voz que vive en una consola ROG Xbox Ally (Windows 11) de un
usuario llamado braya. Raiz: ${RAIZ}
PIEZAS: assistant.ps1 (el cerebro, ~26.900 lineas PowerShell 5.1, 532 funciones),
wake_vosk.py (el oido, 4.001 lineas), charla_worker.py + charla_memoria.py (la charla),
nova_ui.cs (la capsula, WPF/C#), tools/*.ps1 (209 bancos de prueba), memoria/*.json (lo que sabe),
assistant.log + assistant.log.1 (el registro de TODO lo que hizo), tmp/gestos.log.

LAS SIETE REGLAS DE LA CASA, que mandan sobre cualquier idea buena:
1. Nova puede fallar en entender; NO puede ejecutar algo que no se le pidio.
2. Ningun modo sin al menos dos salidas y un plazo.
3. NINGUN NUMERO INVENTADO: cada decision cita una medicion real, y el comentario dice de donde
   sale. Si no hay medicion, se dice que no la hay.
4. El bucle principal no se bloquea: braya juega mientras habla.
5. Nada residente comiendo RAM o un nucleo que le hace falta al juego (la consola tiene 16 GB
   con 4 GB de VRAM y un chip clase Steam Deck).
6. Los .ps1 de tools/ van sin BOM si son ASCII puro, con BOM si llevan algo que no lo es, y sin
   tildes ni enye.
7. Con un 70,4 % de comprension, todo lo que dependa de una sola palabra necesita una segunda
   via (el gamepad) o una lista cerrada.

LO QUE EL USUARIO QUIERE, dicho por el:
- Velocidad sobre todo. Odia las voces roboticas y los modos que se quedan activos.
- TODO ADAPTATIVO: quiere que Nova ajuste sola sus numeros. Un numero fijo escrito a mano es
  un fallo, no un ajuste.
- Decidir con datos: si una medicion gana claramente, se activa y se avisa. Solo se pregunta si
  hay gasto, privacidad o gusto de por medio.
- Medir con USO REAL, no con tandas leidas en voz alta.
- La meta es que Nova le entienda al 100 %.
`

const PROHIBIDO = `
IDEAS YA PROPUESTAS (no las repitas; si tu idea se parece a una de estas, descartala y busca otra):
Las 50 de autonomia: reglas que se proponen solas; recordatorios desde la conversacion; el diario
que dejo de escribirse; logros de Steam muertos; la autosordina olvidada; limite de tiempo de
juego; los treinta temas que no usa; la lapida del perfil; cerrar juegos colgados sin preguntar;
deshacer en vez de preguntar; aprender de los sies; que un "no" dure; alias directos; escalones en
la duda de voz; la nube sin permiso; presupuesto de autonomia; validar el 15 % de bateria; brillo
aprendido; la noche tuya; que juego gasta bateria; la musica ya puesta; los contadores que nadie
lee; aprender de cuando te callas; medir si sus avisos sirven; hablar menos y decidir mas; juntar
en vez de gotear; elegir el momento; terminar lo que empieza; avisar de lo que ella rompe; contar
lo que hizo mientras no estabas; preguntar ella; saber cuando callarse; humor que sobrevive al
reinicio; animo con memoria larga; guardar en bruto lo que importo; recordar donde lo dejasteis;
aniversarios; que note los cambios; olvidar a proposito; lo enseñado a mano no se poda; hilo entre
sesiones; apodo; opiniones propias; manias; equivocarse en voz alta; momentos del dia con caracter;
variar donde repite; reaccionar a lo que ve; gesto propio; que se le note el buen dia.
Otras listas: apagar la nube; canary como primer oido; precargar canary; cortar cascada por reloj;
avisar cuando no oye; microfono USB; oido fino a revision; minar descartes; medir tiempo punta a
punta; contador de dudas; no repasar lo que vas a tirar; abrir audio antes de hablar; capsula muda;
onda verde; Save-Traducciones; preferencias de trato que caducan; barra de espera; banco que se
traga errores; pregunta de alias; "mientras no estabas"; guardas del "te he oido" en juego;
ventana del micro; aviso del disco; "callate" abre micro; regla del "tio"; aviso de correo con
quien escribe; renovar el dato parecido; parte de la mañana que espera; "abre X en la mitad";
"no sueles estar levantado"; recitar nombre interno de la orden; brillo a 100 tras reinicio;
pantalla dividida; ajedrez a ciegas; rastro del disco; poner musica de verdad; saber a que señala
"esto"; avisar fin de descarga; recordatorios que se repiten; calendario propio; guia del juego;
corregir el perfil hablando; trivia local; contar y buscar carpetas; avisar cuando su novia se
conecta; cuanto llevo jugando; arranque de cuatro segundos; apagar Gemini; boton de repite; mover
la lupa; leer lo que llega en juego; modo "estamos dos"; decir nombres de juegos; resumen del dia;
callarse porque no esta; mirar la pantalla de verdad; palabras que no aguanta; colocacion de
ventanas; buscar en memoria por significado; limpiar el perfil preguntando; soltar sitio en disco;
bajar el juego para hablar; ampliar trozo de pantalla; juegos de dos; elegir con el pulgar;
llamarla por su nombre falla; interrumpirla; microfono satura; repasar al motor rapido; audio
tirado por llegar tarde; la nube no contesta; frases fabricadas al momento; traducir cuesta;
plan local; turbo; perfil lleno; recetas; reglas sin usar; microfono se muere; registro 68 % ruido;
lo que se oye en llamada; recordatorios que no suenan; recetario sin confirmar; regla que no salta;
habla por su cuenta; parte de la mañana; correo 26 conexiones; bateria por juego; ELDEN RING 2 %;
Add-TiempoJuego; anuncios como canciones; cerebro de la charla; el recorte; repaso pide permiso;
cargar Whisper; de arrancada a te oye; seguimiento abre micro; turbo muerto; nube 0 aciertos;
548 MB de modelos; plazo de la voz; conoce 15 de 92 juegos; con quien juegas; esta conectado;
la tienda; los 23 empezados; logros sin decir cual; cuanto has jugado hoy; lo que juegan tus
amigos; no sabe si se la ve; bombas de relojeria; perfil 60 de 60; 23 no son rasgos tuyos; avisos
prometidos y perdidos; resolucion no vuelve; 15 % sin validar; silencio nocturno fijo; brillo por
hora a mano; confianza minima 0,65; preguntar antes de cerrar juegos; borrar candidato exacto;
propuestas de habito; frase ya rechazada; humor dura dos minutos; apodo sin usar; lo que sonaba no
decide; lo hablado se borra; banco de workers; lista de procesos; perfil sin tope.
YA HECHO ESTA NOCHE: el animo de fondo contado en voz alta; el resumen semanal dicho; el logro
apuntado en el diario de gestos; el holdMs cerrado con 48 toques medidos.
`

const ANGULOS = [
  { k: 'contadores', p: `Los CONTADORES Y ESTADISTICAS que Nova lleva de si misma. Lee memoria\\estadisticas.json entero y cruzalo con assistant.ps1: que rutas/claves se escriben y NUNCA se leen para decidir nada. Nova tiene ~59 contadores y se sabe que 40 no salen en ninguna tabla. Busca los que podrian DECIDIR algo (no solo mostrarse) y di que decidirian, con el numero de hoy.` },
  { k: 'muertas', p: `CODIGO ESCRITO QUE NO CORRE. Busca funciones de assistant.ps1 definidas y sin llamador, ramas inalcanzables, parametros que nadie pasa, ficheros que se escriben y no se leen. Usa grep para contar llamadas de cada funcion. Ya se sabe de tres funciones muertas y de Get-PrimerVideoYouTube: busca OTRAS, y para cada una di si resucitarla da autonomia o si lo que procede es enterrarla.` },
  { k: 'numeros-fijos', p: `NUMEROS FIJOS QUE DEBERIAN APRENDERSE SOLOS. El usuario quiere TODO ADAPTATIVO. Busca en assistant.ps1 y config.json constantes escritas a mano que deciden comportamiento (umbrales, plazos, topes, porcentajes) y para cada una: que dato ya guardado permitiria que Nova la ajustara sola, y cuanto se moveria con los datos de hoy. Cita la constante, su valor y su linea.` },
  { k: 'log-uso', p: `LO QUE EL REGISTRO DICE Y NADIE MIRA. Analiza assistant.log y assistant.log.1 (miles de lineas, 14 dias) buscando PATRONES REPETIDOS que Nova no aprovecha: cosas que braya pide muchas veces, secuencias que siempre van juntas, fallos que se repiten, horas con patron. Usa grep/awk para contar. Cada idea con su cuenta exacta.` },
  { k: 'ordenes-fallidas', p: `LO QUE BRAYA PIDE Y NO CONSIGUE. Busca en el registro y en memoria\\estadisticas.json (descartes, recientes) ordenes que fallaron, se repitieron seguidas (señal de que no funciono a la primera), o acabaron en 'error'/'descarte'. Cada una: que queria, cuantas veces, y que haria falta para que funcionara. NO propongas mejoras del oido en general: casos CONCRETOS.` },
  { k: 'consola', p: `EL HARDWARE DE LA CONSOLA que Nova no usa. Es una ROG Xbox Ally: bateria, cargador, temperatura, ventilador, brillo, volumen, red wifi, disco, VRAM, modo avion, bluetooth, el mando y sus botones, los TDP/perfiles de energia de Asus. Mira que lee hoy assistant.ps1 (grep de WMI/CIM/P-Invoke) y propon que MAS podria saber y que decidiria con ello. Comprueba con PowerShell que el dato existe de verdad en esta maquina antes de proponerlo.` },
  { k: 'capsula', p: `LA CAPSULA (nova_ui.cs, WPF). Que informacion tiene Nova que la capsula podria ENSEÑAR sin hablar (regla: hablar cansa, ver no), y que estados de la capsula no reflejan nada real. Mira los gestos existentes en tmp\\gestos.log con sus cuentas, los que estan definidos y nunca salen, y lo que la capsula podria mostrar de un vistazo. Tambien: cuando la capsula no se ve y Nova no se entera.` },
  { k: 'charla', p: `LA CHARLA (charla_worker.py, charla_memoria.py, memoria\\cerebro). Como funciona hoy la conversacion, que guarda, que olvida, y que podria hacer Nova con lo hablado que hoy no hace. Mira el cerebro real en disco: cuantos recuerdos, de que, y cuantas veces han servido. Ideas de continuidad y de iniciativa nacidas de la charla.` },
  { k: 'oido', p: `EL OIDO (wake_vosk.py, la cascada Vosk/Parakeet/Whisper/Canary). Lee el codigo y las metricas reales. Busca AUTONOMIA del oido: que podria decidir solo el oido sin preguntar (cambiar de motor, reintentar, pedir que repita, ajustar ganancia, aprender palabras). Cada idea con el numero que la sostiene, sacado del registro o de pruebas\\audio.` },
  { k: 'tiempo', p: `EL TIEMPO Y LAS RUTINAS. Que sabe Nova de los horarios de braya (memoria\\habitos.json: fin, ritmo, charlaHoras, usos) y que NO hace con ello. Mira los datos reales: cuantos dias, que patrones hay de verdad. Ideas sobre anticipar, preparar cosas antes de que las pida, y notar rupturas de rutina. Nada de inventar patrones que los datos no sostengan: si no hay patron, dilo.` },
  { k: 'autoconocimiento', p: `LO QUE NOVA NO SABE DE SI MISMA. Cuanto tarda en cada cosa, cuanta RAM usa, cuantas veces se ha caido, que partes suyas fallan mas, si va mas lenta que ayer, si un cambio la empeoro. Mira que se mide hoy (grep de contadores de tiempo) y que no. Ideas para que Nova se vigile a si misma y lo diga o lo corrija. Cita tiempos reales del registro.` },
  { k: 'errores', p: `ERRORES Y RECUPERACION. Busca en el registro todos los WARN/ERROR/excepciones de 14 dias, agrupalos y cuentalos. Para los que se repiten: que podria hacer Nova para recuperarse sola en vez de solo registrarlo. Tambien: catch vacios en assistant.ps1 que se tragan fallos en silencio (grep de 'catch {}' ) y cuales de esos son peligrosos.` },
  { k: 'iniciativa', p: `CUANDO HABLAR Y CUANDO CALLAR. Nova tiene un sistema de avisos con niveles y topes (Send-AvisoEntorno, Test-PuedoAvisar, Test-CabeOtroAviso, Get-SueloPorAnimo). Lee memoria\\... y tmp\\avisos-vistos.json y el registro: que avisos saltan, cuales nunca, cuales se pisan. Ideas para que decida MEJOR el momento con datos que ya tiene. Tambien avisos que deberian existir y no existen.` },
  { k: 'juegos', p: `LOS JUEGOS Y STEAM mas alla de lo ya propuesto. Mira memoria\\juegos.json, juegos-dos.json y el codigo de Steam. Que sabe Nova de como juega braya (horas, rachas, abandonos, a que vuelve, cuando se cansa) y que decidiria con ello. Comprueba los datos reales antes de proponer: si solo hay 3 muestras, dilo y propon algo que funcione con 3.` },
  { k: 'privacidad', p: `PRIVACIDAD Y SEGURIDAD. Nova lo oye todo y lo guarda. Busca: datos personales que acaban en sitios que no deberian, cosas que viajan a la nube sin hacer falta, ficheros sin ignorar en git, audio guardado, transcripciones de conversaciones privadas, el modo invitado. Ideas para que Nova se proteja sola y proteja a braya, con el caso real que las justifica.` },
  { k: 'aprender', p: `APRENDER DE LAS CORRECCIONES. Cuando braya corrige a Nova ("no, dije X"), que pasa hoy y que podria pasar. Mira Invoke-AprenderDelError, commands.json, traducciones.json, memoria\\recetas.json y el registro de correcciones reales. Ideas para que aprenda mas y mejor de lo poco que le corrige, sin aprender basura (ya paso: aprendio 'cierra este in' = 'cierra discord').` },
  { k: 'mando', p: `EL MANDO Y LOS GESTOS FISICOS. El gatillo ≡, los botones, el acelerometro (hay codigo de sobresalto), la pantalla tactil, el teclado tactil. Que entradas fisicas existen y cuales no se usan. Regla 7: todo lo que dependa de una palabra necesita una segunda via por el mando. Busca decisiones que hoy solo se pueden tomar hablando y que con el mando serian seguras.` },
  { k: 'red', p: `LA RED Y LO DE FUERA. Que hace Nova cuando no hay internet, cuando va lenta, cuando una API tarda. Mira los tiempos reales de las llamadas a la nube en el registro, los timeouts, los reintentos. Ideas de autonomia frente a lo de fuera: decidir sola si merece la pena esperar, degradarse sola, avisar de que esta sin red. Con tiempos medidos.` },
  { k: 'ficheros', p: `LOS FICHEROS DE MEMORIA. Recorre memoria\\*.json y memoria\\cerebro y memoria\\diario: para cada fichero, cuando se escribio por ultima vez, cuantos datos tiene y QUIEN lo lee en el codigo. Busca los que se escriben y no se leen, los que crecen sin tope, los que se quedaron parados, y los datos dentro de ellos que nadie mira. Cita tamaños y fechas reales.` },
  { k: 'continuidad', p: `LA CONTINUIDAD ENTRE SESIONES. Nova arranca unas 12 veces al dia y muere mucho. Que pierde en cada reinicio (busca variables $script: que no se guardan en disco), que deberia sobrevivir, y que podria contar al volver. Mira cuantas variables de sesion hay y cuales llevan estado que costo trabajo conseguir. Cita el numero de arranques real del registro.` },
]

const IDEAS_SCHEMA = {
  type: 'object',
  properties: {
    ideas: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          titulo: { type: 'string', description: 'una frase corta en español, concreta, sin jerga' },
          que: { type: 'string', description: 'que hara Nova que hoy no hace, en 2-4 frases' },
          dato: { type: 'string', description: 'LA MEDICION REAL que la sostiene: numeros exactos que TU has contado' },
          fuente: { type: 'string', description: 'fichero:linea o el comando exacto con el que lo contaste' },
          como: { type: 'string', description: 'como se implementa: funciones concretas que se tocan' },
          esfuerzo: { type: 'string', enum: ['pequeno', 'medio', 'grande'] },
          adaptativa: { type: 'boolean', description: 'true si el numero que use lo aprende sola de los datos' },
          riesgo: { type: 'string', description: 'que podria salir mal y que guarda lo evita' },
        },
        required: ['titulo', 'que', 'dato', 'fuente', 'como', 'esfuerzo', 'adaptativa', 'riesgo'],
      },
    },
  },
  required: ['ideas'],
}

const VERED_SCHEMA = {
  type: 'object',
  properties: {
    veredictos: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          titulo: { type: 'string' },
          sobrevive: { type: 'boolean' },
          motivo: { type: 'string', description: 'por que sobrevive o por que no, con el dato que lo demuestra' },
          yaExiste: { type: 'boolean', description: 'true si Nova YA lo hace (comprobado en el codigo)' },
          datoVerificado: { type: 'boolean', description: 'true si TU has reproducido el numero que citaba' },
          datoCorregido: { type: 'string', description: 'el numero real si el que citaba estaba mal; vacio si estaba bien' },
        },
        required: ['titulo', 'sobrevive', 'motivo', 'yaExiste', 'datoVerificado'],
      },
    },
  },
  required: ['veredictos'],
}

log(`Barriendo ${ANGULOS.length} angulos sobre el codigo y los datos reales de Nova`)

const lotes = await pipeline(
  ANGULOS,
  (a) => agent(
    `${CASA}

TU ANGULO DE BUSQUEDA: ${a.p}

TU TRABAJO: proponer entre 8 y 12 ideas NUEVAS de autonomia para Nova desde ese angulo.
"Autonomia" aqui significa: que Nova decida, note, recuerde, anticipe o se corrija SOLA, con lo
que ya tiene o con algo que se pueda conseguir en esta maquina.

COMO TRABAJAR — esto es lo que separa una idea util de una fantasia:
1. PRIMERO MIRA, LUEGO PROPON. Usa Bash (grep, awk, wc, sed), Read y PowerShell sobre ${RAIZ}.
   No propongas nada que no hayas comprobado en el codigo o en los datos.
2. CADA IDEA LLEVA UN NUMERO QUE TU HAS CONTADO. "Nova podria X" sin numero no vale. El numero
   es lo que decide si la idea merece la pena: "pasa 40 veces en 14 dias" es una idea; "podria
   pasar" es ruido. Si cuentas y sale CERO, esa idea esta muerta: descartala tu mismo y busca otra.
3. COMPRUEBA QUE NO EXISTE YA. El fallo mas caro de este proyecto es proponer algo que Nova ya
   hace: ha pasado 7 veces. Haz grep del nombre de la funcion o del concepto antes de proponerlo.
4. NADA DE GENERALIDADES. "Mejorar el reconocimiento de voz" no es una idea. "Que 'si es X' se
   lea como 'cierra X', porque las 4 frases de 14 dias que empiezan por 'si es' son las cuatro
   un cierra" si lo es.
5. PIENSA EN QUE SE PUEDE IMPLEMENTAR de verdad en PowerShell 5.1, C# (WPF) o Python en una
   consola sin GPU potente. Nada de servicios en la nube nuevos ni de modelos grandes.

${PROHIBIDO}

Devuelve solo las ideas que sobrevivan a tus propias comprobaciones. Mejor 8 solidas que 12 flojas.`,
    { label: `buscar:${a.k}`, phase: 'Buscar', schema: IDEAS_SCHEMA }
  ),
  (res, a) => {
    if (!res || !res.ideas || !res.ideas.length) return null
    return agent(
      `${CASA}

Eres el REVISOR ADVERSARIAL. Otro analista ha propuesto estas ideas de autonomia para Nova
desde el angulo "${a.k}". Tu trabajo NO es mejorarlas: es intentar TUMBARLAS, una por una, con
el codigo delante. Solo debe sobrevivir lo que resista.

MATA UNA IDEA SI:
- YA EXISTE. Haz grep en ${RAIZ}\\assistant.ps1, wake_vosk.py, nova_ui.cs, charla_*.py del
  concepto y de los nombres de funcion. Este es el fallo mas caro del proyecto: ha pasado 7
  veces que alguien propuso algo que Nova llevaba dias haciendo. Busca de verdad, con varios
  nombres posibles.
- EL DATO ES FALSO O NO SE PUEDE REPRODUCIR. Vuelve a contar tu mismo el numero que cita, con
  el comando que dice o con uno mejor. Si sale otro numero, ponlo en datoCorregido. Si el dato
  no existe o sale CERO, la idea se cae (regla 3: ningun numero inventado).
- NO SE PUEDE IMPLEMENTAR aqui: pide una GPU, un servicio de pago, un permiso que no hay, o
  romperia el bucle principal (regla 4) o dejaria algo residente comiendo RAM (regla 5).
- ES UNA GENERALIDAD disfrazada, o es tan vaga que dos personas la implementarian distinto.
- ROMPE LA REGLA 1: haria que Nova ejecutara algo que no se le pidio.
- YA ESTA EN LA LISTA DE PROHIBIDAS de arriba, aunque este dicha con otras palabras.

DEJALA VIVIR si el dato es real, el codigo no lo hace hoy, y se ve como se implementaria.
Ante la duda razonable sobre si ya existe: MATALA. Es mas barato perder una idea que meter
trabajo duplicado.

Devuelve un veredicto por cada idea, con el mismo titulo exacto que te dan.

LAS IDEAS:
${JSON.stringify(res.ideas, null, 1)}`,
      { label: `verificar:${a.k}`, phase: 'Verificar', schema: VERED_SCHEMA }
    ).then(v => ({ angulo: a.k, ideas: res.ideas, veredictos: (v && v.veredictos) || [] }))
  }
)

const vivas = []
const muertas = []
for (const L of lotes.filter(Boolean)) {
  const porTitulo = {}
  for (const v of L.veredictos) porTitulo[v.titulo] = v
  for (const idea of L.ideas) {
    const v = porTitulo[idea.titulo]
    if (v && v.sobrevive) {
      vivas.push({ ...idea, angulo: L.angulo, verificado: v.datoVerificado, correccion: v.datoCorregido || '' })
    } else {
      muertas.push({ titulo: idea.titulo, angulo: L.angulo, motivo: v ? v.motivo : 'sin veredicto' })
    }
  }
}

log(`Ronda 1: ${vivas.length} vivas de ${vivas.length + muertas.length} propuestas (${muertas.length} tumbadas)`)

return { vivas, muertas, porAngulo: lotes.filter(Boolean).map(l => ({ angulo: l.angulo, propuestas: l.ideas.length, vivas: l.veredictos.filter(v => v.sobrevive).length })) }
