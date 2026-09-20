# Lo que queda por hacer en Nova (19/09/2026)

Las once listas de pendientes del proyecto, leidas enteras, cruzadas contra el codigo real y
juntadas en una sola. Sustituye a `PENDIENTE.md` (12/09), que esta desfasado.

Fuentes: PENDIENTE.md, MEJORAS.md, PLAN-SIGUIENTE.md, REVISION-2026-09-18.md, AUTONOMIA.md,
TRASPASO.md, USO-2026-09-18.md, NOVA-LLM.md, QUE-SABE-HACER.md, ESTADO.txt, y los tres
informes del 19/09 (OIDO, MEDICION-MODELOS, VRAM).

**Antes de nada, esto invalida media lista:** Nova está encendida **ahora mismo** desde las 09:19 de hoy (`assistant.log:30276`, PID 19508, sigue latiendo a las 19:18) y arrancó **antes** de los arreglos del oído (12:00–16:06). El proceso vivo lleva el tope de la nube a **2,5 s** (`assistant.log:30283`) mientras `config.json:70` ya dice **7000**. Si pruebas algo del oído sin reiniciar, estás midiendo el código del 18/09. *(La nota de memoria «Nova parada desde el 18/09» está mal: lleva encendida todo el día, y con `decodificado=0%` — hoy nadie le ha hablado.)*

---


---

> ## Estado al cierre del 20/09
>
> **Lo primero, porque cambia cómo se lee el resto de esta lista:** Nova estuvo
> **encendida** con el juez del nombre en modo «mirar» desde las 02:01 hasta las 03:00, y
> ese juez escribía en `assistant.log` **la transcripción libre de cada ráfaga de voz** que
> pasa la puerta del micrófono, no solo las tuyas. Se cortó con **cero líneas escritas**.
> Junto a eso se cerraron otras tres puertas del mismo tipo (commit `e9fc18d`), y una de
> ellas explica lo de la noche del 19/09: `Start-NubeOir` mandaba el WAV a Google y la
> comprobación de «esa voz no es la tuya» vivía 1.300 líneas más abajo, o sea **después**
> del viaje.
>
> ### Cerrados hoy
>
> | id | qué era | cómo se cerró |
> |---|---|---|
> | **B4** | El diario falso del 14/09 (osos polares, Hades) | Ya estaba vacío: se fue en la limpieza del 19/09. Queda solo el encabezado, como el del 17/09 |
> | **B8** | Vectores que faltaban (ids 3, 53, 54) | 53 y 54 hechos; el **id 3 no debe tener vector**: está `rechazada` y `completar_vectores` la salta a propósito. No era un fallo |
> | **C1** | `probar-audio.py` mide el camino viejo | **Medido y cerrado con dato**: `tools\medir-parakeet-20.py` da **11 de 20 (55 %)** para Parakeet solo frente a **19 de 20 (95 %)** de Whisper solo. Meterle Parakeet haría suspender su propio listón sin que nada hubiera empeorado. El circuito se queda |
> | **C27** | «Apuntar el fallo aunque no salga orden» — estaba *bloqueado a propósito* | **Desbloqueado por P1**: ahora los fallos deducidos van a `senales-fallo.jsonl`, con etiqueta y peso propios |
> | **S2‑S5** | Las cuatro puertas de privacidad | commit `e9fc18d`, con `tools\probar-olvido.ps1` (2n37) |
> | **P1‑P5** | Aprendizaje autónomo, los cinco pasos | commit `47cd527` |
>
> ### Lo que P1‑P5 cambian de esta lista
>
> **C28 (las seis de autonomía que esperaban datos) ya no espera a lo mismo.** No esperaba
> trabajo: esperaba que Nova pudiera *ver* sus errores. P1 le da esa vista (`descarte`,
> `ruido` y `no-orden-a-charla` dejan rastro por orden) y P4 le da con qué juzgarla (una
> binomial de verdad, con α 0,01 porque la revisión corre todos los días). Sigue haciendo
> falta **uso real**: con `auto.datosDesde = 2026-09-20` la ventana arranca **vacía**.
>
> Y un número que conviene tener delante: **`fallo-dicho-por-ti` va 0 de 119 órdenes.** La
> meta «cero órdenes equivocadas» hoy no se puede medir, porque el único dato humano que la
> mediría nunca se ha producido. Por eso P1 no es un extra: es lo que hace medible la meta.
>
> ### Lo nuevo que hay que probar con tu voz (y no se puede probar sin ella)
>
> 1. «Abre Steam» y luego «sube el volumen»: que lo segundo **solo** suba el volumen.
> 2. Tras 3 minutos de silencio, «hay alguna actualización de este» **no** debe resolver.
> 3. Llamarla flojito desde lejos, para ver si `escucha.rafagaMinima` (0,030) se pasa de
>    estricta contigo.
> 4. «Olvida los últimos diez minutos»: debe contestar cuántos rastros borró y de cuántos
>    sitios, **sin decir qué borró**.
> 5. Mirar las líneas `juez (solo mirando)` del log antes de poner `juezNombre` en `"si"`.
>
> ### Dos números tuyos, no míos
>
> - **`escucha.guardarUsoDias` = 30.** A los 30 días se borra el WAV y se queda su línea del
>   registro. Puesto en 30 y no en 7 porque los 167 audios del 15/09 son la base de las
>   medidas del oído; bájalo si prefieres que el audio dure menos.
> - **`escucha.ambiente` = `"no"`.** Encenderlo hace que Nova recuerde en RAM (45 s, nunca a
>   disco) lo que sonaba **antes** de que la llamaras, para entender un «apunta eso». Es tu
>   casa la que se oye: la decisión es tuya.


> ## Estado al cierre del 19/09 (noche)
>
> **27 cerrados hoy**, de los 95 que había:
>
> | grupo | hechos | cómo |
> |---|---|---|
> | B (pequeños) | **9 de 17** | commits `95ab5c5`, `c4055dc` |
> | C (medianos) | **18 de 28** | commits `c714970`, `01e5f08`, `9775e5a` |
>
> De esos 18 medianos, **5 resultaron NO PROCEDER al medirlos** (C3, C12, C13, C17, C21) y
> quedan cerrados con su dato en `MEJORAS.md`, para que nadie los reabra. Eso también cuenta:
> es trabajo que ya no hay que hacer.
>
> Quedan **68**: 23 tuyos (probar en vivo o decidir), 8 pequeños, 10 medianos y 8 grandes.
>
> **Lo que NO se hizo y por qué:** `C9` (que Nova ajuste sola el tope de la nube) queda fuera
> a propósito: es el mayor del grupo, toca bucle y escucha, escribe `config.json` por su cuenta
> y por diseño no podría decidir nada hasta el 23/09. Merece su propia sesión.
>
> **Fuera a propósito, con motivo:** `C9` (Nova ajusta sola el tope de la nube),
> `C18` (el contador de dudas rompe `probar-titulos.ps1`, un banco que nadie ejecutaba) y
> `C6` (las traducciones perdidas: antes hay que separar «no pude leerlo» de «no es JSON
> válido», o un cerrojo acabaría apartando el fichero bueno).
>
> **Un pendiente que parecía cerrado y no lo está:** «abre el navegador y a pantalla dividida,
> abre Steam» —la frase real del 18/09— se sigue yendo a la IA. Se arregló la forma corta
> («pon X a pantalla dividida»), no la cadena con dos verbos.


## A) LO TUYO: probar en vivo o decidir (23)

Va primero porque bloquea a casi todo lo demás.

| id | qué es | por qué importa | apuntado en | tamaño |
|---|---|---|---|---|
| **A0 REINICIAR** | Cerrar Nova y volver a abrirla | Está corriendo con el código de ayer y el tope de nube viejo. Sin esto, cualquier prueba del oído miente | `assistant.log:30276,30283` + `config.json:70` (no estaba en ninguna lista) | 1 minuto |
| **A1 OÍDO-VIVO** | Hablarle y ver 3 cosas: que la espera a la nube no se note cuando acierta a la primera, que los 7 s no se hagan eternos cuando falla, y que no se acumulen `nube-*.wav` en `tmp\` | Es lo único que falta para cerrar el trabajo del oído de hoy; el commit dice literal «SIN PROBAR HABLANDO» | `OIDO-2026-09-19.md:314-318` (OID-3/4/5, ×3 apuntes) | pequeño |
| **A2 USO-NOVA-CORTE** | Decir «nova» mientras ella habla, a ver si calla | El código ya está (`wake_vosk.py:1165`); sin probarlo no sabes si sirve | `USO-2026-09-18.md:166` | pequeño |
| **A3 EST-DICTADO** | Bloc de notas delante, «dicta un correo», una frase, y mirar dónde escribe | Es lo único del dictado largo que nunca se ha confirmado desde dentro. *(Un informe lo daba por hecho por los 30 dictados de uso real; el otro no. Se zanja en 30 segundos)* | `ESTADO.txt:505,540` (archivado) + `PENDIENTE.md:11,561` (×2) | pequeño |
| **A4 B1** | Con el mando: A = sí, B = no con una pregunta esperando | Si esto no va, todas las confirmaciones jugando se caen | `PENDIENTE.md:37` (13/09) | pequeño |
| **A5 B2** | Con el mando: panel rápido (doble toque en ≡, cruceta, A/B) | Idem: función entregada y nunca tocada | `PENDIENTE.md:78` (13/09) | pequeño |
| **A6 USO-TOQUE** | **Decidir** si baja el `holdMs` de 1100 ms (el 18/09 lo soltaste a los 190 ms dos veces y se te abrió el panel) | Ya hay 12 toques cortos medidos; es gusto tuyo, nadie puede decidirlo por ti | `USO-2026-09-18.md:237` + `AUTONOMIA.md:633` (AUT-35, ×2) | pequeño |
| **A7 B4** | Probar la salida de sonido **con cascos puestos** | Sin cascos solo hay una salida: no se puede comprobar de otra forma | `PENDIENTE.md:325` | pequeño |
| **A8 B5** | En una llamada de Discord, que no hable (texto + pulso) | Es el caso en que hablar sola te avergüenza delante de otros | `PENDIENTE.md:327-328` | pequeño |
| **A9 B6** | Decir «cállate» mientras habla y ver que su propia voz no se cuela | La guarda por tono nunca se ha oído funcionar | `PENDIENTE.md:696-700` | pequeño |
| **A10 B7** | Escuchar si acentúa bien desde `Add-TildesVoz` | Odias las voces robóticas; esto es exactamente eso | `PENDIENTE.md:606-608` | pequeño |
| **A11 B3** | Crear **dentro de Discord** los atajos Ctrl+Shift+M y Ctrl+Shift+D | Sin ellos «silencia mi micro» no hace absolutamente nada (y `config.json` ni siquiera tiene sección `discord`) | `PENDIENTE.md:95-96` | pequeño |
| **A12 B8** | Sacar la clave gratuita de la API de Steam | Es el único punto marcado «a medias» de todo `PENDIENTE.md`; sin clave, «¿quién está conectado?» no existe | `PENDIENTE.md:189-191` | pequeño |
| **A13 B9** | **Revocar la `ANTHROPIC_API_KEY`** que salió en claro el 13/09 | Seguridad, y lleva 6 días apuntada. Nadie puede verificarlo desde el repo | `PENDIENTE.md:307-309` | pequeño |
| **A14 VRAM-1** | Jugar a Wukong y Spider-Man y juzgar los 4 GB de VRAM (si hay tirones o texturas tardonas, subir a 6) | No existe ninguna medición publicada de 4/6/8 GB en el Z2 A: solo se decide jugando | `VRAM-2026-09-19.md:133-135,144` | medio |
| **A15 VRAM-AJUSTES** | Tres casillas fuera de Nova: Image Sharpening ON al 50 %, RSR ON solo en Elden Ring a 720p, topes de fps 30/40/40 en Command Center | Son las únicas recomendaciones del informe de VRAM sin aplicar | `VRAM-2026-09-19.md:111-112,117,122-123` (VRAM-5/6/7, ×3) | pequeño |
| **A16 VRAM-3** | Pasar el bloque 5 del banco con tu voz | Con 11,7 GB ya no debería decir «SALTADA»: hay que verlo | `VRAM-2026-09-19.md:95,138` | pequeño |
| **A17 TRA-FULLSCREEN** | Ver la cápsula con un juego a **pantalla completa exclusiva** | Sobre ventana sin bordes ya se sabe que sí; en exclusiva, no | `TRASPASO.md:584` | pequeño |
| **A18 A3-5b** | Mirar si la cápsula se cuela en su propia captura de pantalla | Es la mitad que quedó viva de un hallazgo: el `Thread.Sleep(45)` de `nova_ui.cs:1448` no se toca hasta verlo | `MEJORAS.md:171-178,197` | pequeño |
| **A19 H7m5** | Con un juego delante, decidir si la cápsula deja de barrer del todo | Si deja de barrer pierdes la señal de «sigo trabajando» justo cuando no la ves. Solo se juzga jugando | `REVISION-2026-09-18.md:501,549` | medio |
| **A20 H4m2** | **Decidir**: ¿que obedezca «calla» cuando no reconoce el tono? | Si dices que sí, la tele puede mandarla callar; si dices que no, a veces no te obedece a ti. Ya hay datos en el log desde el 18/09 | `REVISION-2026-09-18.md:317` + comentario en `wake_vosk.py:1218-1221` | decisión |
| **A21 DEC-OPENROUTER** | **Decidir** si entra OpenRouter junto a Gemini | Hay gasto de por medio. El propio informe dice que no ataca el cuello (los fallos son de oído, no de entendimiento), pero nunca se marcó como descartado | `MEJORAS.md:501-527` | decisión |
| **A22 TRA-RAM-UI** | **Decidir** si molestan los ~130 MB de `nova_ui.exe` (`ui.nueva = false` vuelve a la barra vieja) | Con 11,7 GB visibles probablemente ya da igual: basta con que lo cierres | `TRASPASO.md:582` | decisión |
| **A23 USAR-DIAS** | Usarla varios días seguidos | Es lo que desbloquea AUT-2, AUT-35, AUT-38 y las cuatro de autonomía bloqueadas: no son código, son datos repartidos en ≥3 días | `AUTONOMIA.md:61,633,705` + `QUE-SABE-HACER.md:114` + `NOVA-LLM.md:50` (×3) | continuo |

---

## B) PEQUEÑO Y CON VALOR CLARO — menos de una sesión (17)

| id | qué es | por qué importa | apuntado en | tamaño |
|---|---|---|---|---|
| **B1 MODELO-LOCAL** | Cambiar `config.json:101` a `qwen2.5:3b` y corregir el documento que dice que ya lo usa | Un dato, una línea: el 3b acierta **16/18** y el 1.5b **13/18**. Y `MEDICION-MODELOS-2026-09-19.md:24` afirma algo falso | `PLAN-SIGUIENTE.md:715-718` + `MEDICION-MODELOS-2026-09-19.md:24-25` (×2) | pequeño |
| **B2 AUT-61** | Dar a `Test-DatosRepartidos` (`assistant.ps1:6139`) una fecha de corte: «no cuentes nada anterior a X» | **Desbloquea AUT-54/55/56/58 de golpe** y evita que la primera decisión propia de Nova salga de los datos podridos del 15/09 (de antes de arreglar el micro) | `AUTONOMIA.md:1154` | pequeño-medio |
| **B3 H3m2** | Poner listón mínimo en `tools\probar-regex.ps1:97-100`: hoy sale verde con 0 patrones vistos | Una prueba que siempre aprueba no es una prueba | `REVISION-2026-09-18.md:233` | pequeño |
| **B4 H1m3** | Borrar `memoria\diario\2026-09-14.md` (osos polares, «ocho horas», Hades: sale del banco de pruebas) | Es memoria falsa dentro de su cabeza real | `REVISION-2026-09-18.md:144` | pequeño |
| **B5 MEN-2** | Actualizar o archivar `ESTADO.txt` (fechado 14/09, dice «EJECUTANDO AHORA: NO» mientras está ejecutando) | `PENDIENTE.md` manda leerlo al retomar y describe una Nova que ya no existe | `REVISION-2026-09-18.md:720-723` | pequeño |
| **B6 MEN-1** | Quitar código muerto de `wake_vosk.py`: `leer_vocabulario` (`:834`, nunca se llama) y `pico_voz` (`:1859`, se calcula y no se lee) | Menos ruido donde vive el oído, que es lo que más se toca | `MEJORAS.md:87` + `REVISION-2026-09-18.md:714-719` (A1-9, ×2) | pequeño |
| **B7 A1-10** | Que `decodificado=N%` mida la ventana reciente, no toda la vida del proceso (`wake_vosk.py:1451-1452`, nunca se resetea) | Tal como está **no puede avisar de nada**: el pulso del log es decorativo | `MEJORAS.md:88` + `REVISION-2026-09-18.md:717` (×2) | pequeño |
| **B8 NLLM-VECTOR3** | Generar los vectores que faltan: hay 50 para 53 recuerdos (faltan los ids 3, 53 y 54) | **Ha empeorado**: el informe citaba solo el id 3. Esos recuerdos no se encuentran por significado | `NOVA-LLM.md:159` | pequeño |
| **B9 VERIFICAR-ACCIONES** | Que el «cerrados N de M» llegue a la voz y a estadísticas, y comprobar que un archivo creado existe de verdad | Es la meta declarada de `NOVA-LLM.md`: que compruebe que lo que hizo salió bien. Hoy solo lo hacen las recetas | `NOVA-LLM.md:123` + `:125` + `QUE-SABE-HACER.md:106` (×3) | pequeño |
| **B10 H2m4** | Casos de prueba para `Start-CorreoManana` / `Receive-CorreoManana` | `grep CorreoManana tools/` no devuelve **nada**: el correo de la mañana no tiene una sola prueba | `REVISION-2026-09-18.md:183` | pequeño |
| **B11 H3m4** | Resumen final del banco con las secciones saltadas | El aviso amarillo existe, pero la sección 5 desaparece del recuento y parece que todo pasó | `REVISION-2026-09-18.md:239` | pequeño |
| **B12 H3m5** | Meter `probar-ocr.ps1` en el banco y anotar por qué quedan fuera `probar-vivo`, `probar-precarga` y `probar-voz-windows` | `probar-vivo.ps1` es **el único que prueba el bucle principal** y nadie lo ejecuta | `REVISION-2026-09-18.md:242` | pequeño |
| **B13 A4-8b** | Una prueba, aunque sea, para `New-CopiaSeguridad` | Es la función que te salva si algo se rompe, y no la cubre nada | `MEJORAS.md:217,397-398` | pequeño |
| **B14 A3-11** | Que la cápsula no deje de anotar a los 50 errores ni **borre** su log a los 200 KB (`nova_ui.cs:404,408`) | Justo cuando más falla es cuando deja de contarte por qué | `MEJORAS.md:203` | pequeño |
| **B15 H2m2** | Que avise sola si lleva N días sin apuntar ni una orden en `destinos.jsonl` | Sin uso real no se puede decidir nada; que lo diga ella y no lo descubras tú un mes después | `REVISION-2026-09-18.md:176` | pequeño |
| **B16 VRAM-2** | Tras una sesión de voz, mirar el log: que no quede ningún «no lo cargo» | Ya casi: la última negativa es del 18/09 23:37 y el 19/09 09:25 cargó Parakeet en 4,9 s. Falta una sesión para cerrarlo | `VRAM-2026-09-19.md:136-137` | pequeño |
| **B17 LIMPIEZA-LISTAS** | Tachar en `PENDIENTE.md`, `MEJORAS.md` y `ESTADO.txt` lo que ya está hecho y borrar lo que apunta a ficheros inexistentes (`scratchpad\analisis\aprender.md`) | Estas listas te mandan hacer cosas hechas hace días. Hoy cuestan más de lo que ayudan | los tres documentos (17/09, 17/09, 14/09) | pequeño-medio |

---

## C) MEDIANO (28)

| id | qué es | por qué importa | apuntado en | tamaño |
|---|---|---|---|---|
| **C1 A1-8** | Que `tools\probar-audio.py` pase el audio por Parakeet (o que avise de que mide el camino viejo); su listón sigue en 0,75 | Mide el circuito de **antes del 15/09**: aprueba algo que ya no existe | `MEJORAS.md:86` + `REVISION-2026-09-18.md:235` (H3m3, ×2) | medio |
| **C2 H5m2** | Cerrojo con PID en el worker para que dos instancias no carguen Whisper a la vez | Fue la causa del racimo de 117,9 s del 16/09. El mutex que hay protege al asistente, no al worker | `REVISION-2026-09-18.md:419` | medio |
| **C3 H5m5** | No reindexar Steam **entre arranques** (caché en disco); dentro de una sesión ya hay freno de 60 s | 171 reindexados. Antes hace falta una medición válida: la del 18/09 dio `juegos=0` y no mide nada | `REVISION-2026-09-18.md:386-393` | medio |
| **C4 AVISOS-JUEGO** | Arreglar la detección de salida de juego (exigir que el proceso muera + duración mínima) y con eso desbloquear los dos avisos | `Exit-Juego` salta al perder el primer plano: 4 de 6 «salidas» duraron menos de 2 min (Elden Ring, 11 s). Tocar el aviso antes que la detección es peligroso | `PLAN-SIGUIENTE.md:918-924` | medio-grande |
| **C5 FILTRO-PERFIL** | Pasar por el filtro del perfil lo **nuevo** que entra en el cerebro de la charla (`charla_memoria.py:455`) | Hoy solo mira longitud y `sensible()`. El plan aprueba la mitad: el filtro para lo nuevo sí, limpiar lo viejo no | `PLAN-SIGUIENTE.md:708-714` | medio |
| **C6 TRADUCCIONES-PISADAS** | Averiguar quién reescribió `traducciones.json` (14 aprendidos perdidos) | La causa propuesta era imposible; la pista buena es el formato (dos espacios tras los dos puntos = PS 5.1). Fusionar al guardar rompería el olvido | `PLAN-SIGUIENTE.md:885-890` | medio |
| **C7 H1m2** | Que `charla_worker.py` se niegue a escribir el diario sin que le digan la carpeta (`:64` apunta por defecto a la memoria real) | Es la puerta por la que el banco de pruebas metió recuerdos falsos | `REVISION-2026-09-18.md:141` | medio |
| **C8 H2m3** | Que el banco avise en amarillo si `assistant.ps1`/`wake_vosk.py` cambiaron y no hay uso real posterior | Exactamente lo que pasó hoy: código nuevo, cero voz encima | `REVISION-2026-09-18.md:179` | medio |
| **C9 N1** | Que Nova ajuste **sola** el tope de la nube | Ya no está bloqueado por falta de datos (`nube-intento: 75`). Hoy solo sabe apagar la nube entera, no afinarla | `MEJORAS.md:495-497` | medio |
| **C10 USO-DIVIDIDA** | «…y a pantalla dividida, abre Steam» con **una sola** app: hoy el patrón exige dos | Falla en una cadena que ya usaste; con una app no sabe qué poner al otro lado | `USO-2026-09-18.md:175` | medio |
| **C11 USO-BARRA** | «Guarda un acceso directo en la barra»: no existe como orden, cae al agente | Cero coincidencias de «anclar»/«barra de tareas» en el código. Lo pediste y no lo entendió | `USO-2026-09-18.md:75` | medio |
| **C12 I4** | Repaso del día: que pregunte por las 3 peores órdenes | Convierte el uso real en corrección dirigida, que es la meta del 100 % | `MEJORAS.md:60` | medio |
| **C13 I5** | Perfil de ruido por hora | El ruido de la tele a las 22:00 no es el de las 10:00 | `MEJORAS.md:61` | medio |
| **C14 I6** | Deshacer con historial (más de un paso) | Hoy solo deshace lo último | `MEJORAS.md:62` | medio |
| **C15 I7** | Leer una zona de la pantalla | Es lo que hace útil el OCR jugando | `MEJORAS.md:63` | medio |
| **C16 I8** | Modo sin manos: confirmar con el mando | Huele a decisión tuya antes de programarse | `MEJORAS.md:64` | medio |
| **C17 I9** | Segunda opinión también en órdenes **ambiguas**, no solo cuando no entiende nada | Hoy la nube solo entra cuando falla del todo; los errores caros son los que entiende mal con confianza | `MEJORAS.md:65` | medio |
| **C18 I1** | Vocabulario según el juego abierto — **bloqueada**: primero hay que contar cuántas veces duda entre candidatos | Sin ese contador no se sabe si pasa 5 veces al día o 2 al mes | `MEJORAS.md:57` | medio |
| **C19 META-NUMERO** | Contador visible de la meta (aciertos/órdenes del día) y que responda «¿cómo me has entendido hoy?» | Tu meta es el 100 %: hoy es una idea, no un número que puedas mirar | `MEJORAS.md:59` (I3) + `REVISION-2026-09-18.md:185` (H2m5, ×2) | medio |
| **C20 P2** | Medir whisper.cpp con la Radeon (Vulkan) | «Sin medir todavía» desde el 15/09; es el camino más directo a un oído más rápido | `PENDIENTE.md:892` | medio |
| **C21 P3** | Confirmación diferida a los 60 s en las recetas (hoy `esperaMs` = 6 s) | Fase 2 apuntada y nunca hecha; 6 s es poco para una receta larga | `PENDIENTE.md:1497` + `config.json:91-93` | medio |
| **C22 VRAM-4** | Vigilar que qwen no se precargue de más (el camino «suena a charla» no mira si hay API) | Con 11,7 GB se precarga 1,1 GB cada vez que algo suena a charla | `VRAM-2026-09-19.md:96-97,138-139` | medio |
| **C23 VRAM-8** | Medir la pila entera cargada a la vez (Parakeet + base + small + qwen) | Nadie lo ha hecho: los ~2,5 GB son una suma en papel | `VRAM-2026-09-19.md:147-149` | medio |
| **C24 VRAM-9** | *(opcional)* Probar Ollama con `OLLAMA_IGPU_ENABLE=1` | El propio informe duda de que compense con 4 GB. Barato de probar, fácil de descartar | `VRAM-2026-09-19.md:145-146` | medio |
| **C25 OID-2** | Medir Vosk grande (2,3 GB), descargado y sin probar con el pipeline de hoy | Ya está en disco ocupando sitio; o sirve o se borra | `OIDO-2026-09-19.md:80-82` | medio |
| **C26 MEDIR-LOCAL** | Medir cuántas tareas resuelve el plan local y cuántas siguen yendo al agente | Referencia del 15/09: 20 llamadas al agente = 11,6 min = 23 % de toda tu espera. Sin medida nueva no sabes si mejoró | `PENDIENTE.md:1507-1508` (P4) + `NOVA-LLM.md:208` (NLLM-MEDIR, ×2) | medio |
| **C27 FALLO-DICHO** | Apuntar «no era eso / te equivocaste» aunque no salga una orden ejecutable | **Bloqueado a propósito**: con los datos de hoy produciría 1 apunte en toda la historia, y sobre una alucinación de Whisper. Esperar a más uso | `PLAN-SIGUIENTE.md:451-457` | medio |
| **C28 AUT-BLOQUEADAS** | Las seis de autonomía que esperan datos: umbral de «nova» (AUT-2), batería (AUT-38), y medir/no insistir/explicar/revertir sus propias decisiones (AUT-54, 55, 56, 58) | **No son trabajo, son espera.** Hay 0 `auto-ajuste` y 0 `auto-deshecho`: es su freno funcionando. Se abren con B2 (AUT-61) + A23 (usarla) | `AUTONOMIA.md:61,705,1021,1033,1040,1065` (×6) | — |

---

## D) GRANDE O QUE NECESITA DECIDIR ANTES (8)

| id | qué es | por qué importa | apuntado en | tamaño |
|---|---|---|---|---|
| **D1 EL-OÍDO** | Los nombres propios que el oído **local** sigue fallando: «Abre St», «Sierra Gul», «Haben The Ring» | Hoy los salva la nube, no el código. Es tu meta declarada (entender al 100 %) y el trabajo de fondo de todo el proyecto | `OIDO-2026-09-19.md:78-79` (OID-1) + `USO-2026-09-18.md:89` (USO-OIDO, ×2) | grande, continuo |
| **D2 USO-CALENDARIO** | Google Calendar de verdad (OAuth + API) | Hoy «revisa mi agenda» te contesta con recordatorios: Nova **no tiene** calendario, y por IMAP no se llega. Necesita tu sí antes de empezar | `USO-2026-09-18.md:94` | grande |
| **D3 H5m4** | Decir que sigue **sorda mientras carga** el modelo (hoy saluda «Listo» y no oye, hasta 2 minutos) | Es el fallo que más te confunde al arrancar. El propio informe se corrige: **no es barata**, hay que inventar un canal worker→asistente | `REVISION-2026-09-18.md:378-385` | grande |
| **D4 H1m5** | Marcar cada línea del diario como `prueba` o `real` y que el resumidor descarte lo que no sea real | Es la solución de raíz a la memoria contaminada (B4 solo limpia lo de ahora) | `REVISION-2026-09-18.md:150` | grande |
| **D5 I10** | Avisos al móvil | El propio documento la marca como «la más cara y la que menos acerca al 100 %». La listo para que se pueda descartar con conocimiento | `MEJORAS.md:66` | grande |
| **D6 P5** | Fase 2 de «aprender»: correo, aprender de «no, dije X» y traducciones por uso | **Hay que reescribir el pendiente o retirarlo**: de los 4 puntos, «el vídeo número N» ya está hecho, el correo se trabajó el 18/09, y el fichero `scratchpad\analisis\aprender.md` que cita ya no existe | `PENDIENTE.md:1509-1511` | grande |
| **D7 TRA-COMANDOS** | Ampliar `commands.json` con lo que el uso real no reconoce (`memoria\estadisticas.md` dice exactamente qué falló) | Es el trabajo continuo que convierte cada sesión de uso en órdenes nuevas | `TRASPASO.md:566` | continuo |
| **D8 A3-7** | Reescritura entera del cerebro en cada turno — **aplazado con razón, no tocar** | El disparador es 1 MB y `cerebro.json` va por 25,9 KB. Lo listo para que no se reabra por error | `MEJORAS.md:180-185,199` | grande (no toca) |

---

## Recuento honesto

Repartidos en **11 documentos** (`PENDIENTE.md`, `MEJORAS.md`, `PLAN-SIGUIENTE.md`, `REVISION-2026-09-18.md`, `AUTONOMIA.md`, `TRASPASO.md`, `USO-2026-09-18.md`, `NOVA-LLM.md`, `QUE-SABE-HACER.md`, `ESTADO.txt`, y los tres del 19/09):

| | |
|---|---:|
| Puntos revisados en total | **481** |
| **Ya hechos** | **309** |
| Descartados con motivo escrito | **77** |
| Apuntados como abiertos | 95 |
| — de esos, el mismo pendiente en dos o tres sitios, o ya hecho | **−13** |
| — agrupados por comodidad (los 3 del oído, las 3 casillas de GPU, las 6 de autonomía) | −9 |
| + 3 que no estaban en ninguna lista (reiniciar Nova, limpiar las listas, el acceso directo en la barra) | +3 |
| **QUEDAN, sin duplicados** | **76** |

**Por grupo:** A) tuyos **23** · B) pequeños **17** · C) medianos **28** · D) grandes **8**.

**Los que quité por estar ya hechos aunque las listas los pedían (6 gordos):** usar Nova un día entero (`destinos.jsonl` tiene 236 líneas, última hoy a las 11:16 — lo daban por inexistente **tres** documentos), el turbo/último recurso (apagado, `config.json:17`), el tope de la nube dentro de plazo (7000), decir «nova» para interrumpir por el lado del código, «cierra lo que acabas de abrir» (commit `9791de5`), y revisar `tmp\ui-error.log` (**no existe el fichero: significa que la cápsula no ha registrado ni un error**, se puede cerrar). Y uno que estaba mal listado: **«pon X de Y» sin decir «canción» no es un pendiente, está fuera a propósito** para no tragarse «pon el volumen de…» (`USO-2026-09-18.md:150`). Bórralo de donde lo veas.

---

## Lo que yo haría primero

1. **A0 — Reiniciar Nova.** Lleva desde las 09:19 corriendo el código de ayer y esperando a la nube solo 2,5 s cuando el config ya dice 7. Todo lo demás que pruebes hoy sin esto mide algo que ya no existe, y hoy `decodificado=0%`: no le has hablado desde que arrancó.
2. **B1 — Poner `qwen2.5:3b`.** Una línea (`config.json:101`), un dato claro: **16/18 contra 13/18**. Es la mejor relación esfuerzo/ganancia de toda la lista, va por tu regla de decidir con datos, y de paso corrige un documento que hoy afirma en falso que ya lo estás usando.
3. **B2 — AUT-61, la fecha de corte.** Es lo único de autonomía programable hoy sin esperar datos, **desbloquea cuatro ideas de golpe** (AUT-54/55/56/58) y evita que la primera decisión que Nova tome sola salga de los 29 intentos del 15/09, medidos antes de arreglar la ganancia del micro.

Y en cuanto reinicies, lo tuyo: **A1** (hablarle y ver el oído nuevo), **A3** (dictado largo) y **A13** (revocar la clave de Anthropic, que lleva 6 días apuntada).

## Ficheros relevantes

- `C:\Users\braya\Documents\voice-ctrl\assistant.ps1` (446, 3163, 6139, 8611, 10667, 11039, 12372, 13736)
- `C:\Users\braya\Documents\voice-ctrl\wake_vosk.py` (834, 1165, 1218-1225, 1451-1452, 1859)
- `C:\Users\braya\Documents\voice-ctrl\config.json` (12 `holdMs`, 17 `whisperModeloUltimo`, 70 `nubeTopeMs`, 101 `modeloLocal`)
- `C:\Users\braya\Documents\voice-ctrl\nova_ui.cs` (404, 408, 1448) · `charla_worker.py` (64) · `charla_memoria.py` (455)
- `C:\Users\braya\Documents\voice-ctrl\assistant.log` (30276 arranque de hoy, 30283 el tope viejo de 2,5 s)
- `C:\Users\braya\Documents\voice-ctrl\tools\probar-audio.py` (271), `tools\probar-regex.ps1` (97-100), `tools\probar-todo.ps1` (301)
- `C:\Users\braya\Documents\voice-ctrl\memoria\diario\2026-09-14.md`, `memoria\cerebro\vectores.json`, `memoria\estadisticas.json`
- `C:\Users\braya\Documents\voice-ctrl\pruebas\audio\uso\destinos.jsonl`