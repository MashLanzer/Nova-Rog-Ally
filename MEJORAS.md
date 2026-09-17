# Mejoras de Nova: lo medido y lo propuesto

Lista viva para consultar y decidir qué se hace después. Empezada el 17/09/2026.

**Cómo se usa:** nada entra aquí como «buena idea». Entra con un número al lado o con la
nota de que todavía no se puede medir. Lo que se descarta también se queda escrito, con
el dato que lo tumbó, para que nadie (yo el primero) lo reintente dentro de tres semanas.

**La meta de braya manda:** que Nova le entienda al 100 % y no ejecute ni una orden
equivocada; y la velocidad por encima de casi todo. Una mejora que cambie segundos por
órdenes perdidas no es una mejora.

---

## 1. Medido hoy y ya decidido

### 1.1 El oído fino SE QUEDA — medido
Interviene en 125 de 187 órdenes reales y en 100 cambia el texto. Pasando los 100 pares
por el resolvedor local: **rescata 18, estropea 7**. Se queda.
Por motor: base 60 repasos (rescata 10), small 24 (5), turbo 15 (3, no estropea ninguna).

### 1.2 Las 7 que «estropeaba» NO eran un problema — cerrado
Las 7 están protegidas por la red de PARAKEET→WHISPER (`Test-EspanolLargo` +
`-not Test-FastCommand`): Nova ya se quedaba con el texto bueno. La lección fue sobre la
medición: comparar lo que oyó el repaso contra lo que oyó Parakeet **no dice qué hizo
Nova**. Para eso está ahora `destinos.jsonl`.

### 1.3 Frenar el repaso: DESCARTADO con datos
Era la idea más prometedora de la lista corta. Aplicar el freno que ya existe
(`Test-PareceCharla`) al camino Parakeet→Whisper frenaría 22 de los 73 repasos inútiles
**pero se cargaría 5 de los 18 rescates**. Segundos a cambio de órdenes perdidas: no.

### 1.4 EL ÚLTIMO RECURSO (turbo): pendiente de decidir, ya medido
| motor | veces | mediana | total | rescata |
|---|---|---|---|---|
| base | 115 | 1,3 s | 4,3 min | 10 |
| small | 48 | 4,1 s | 4,2 min | 5 |
| **turbo** | **23** | **16,2 s** | **7,4 min** | **~3** |

Turbo es 9 veces más lento que base, se lleva casi la mitad del tiempo de repasos y sale
a **~149 s de espera por cada orden que salva** (`turbo` 29 lanzamientos / `turbo-nada`
27 en las estadísticas). A su favor: nunca estropeó ninguna.
- [ ] Decidir: bajarle el plazo, lanzarlo solo con audio corto, solo si parece orden, o
      quitarlo. Antes, mirar con `destinos.jsonl` si esos ~3 rescates importaban.

### 1.5 Medir aciertos: HECHO
`Write-DestinoUso` apunta qué hizo Nova con cada orden, y «eso estuvo mal» / «no era eso»
la marca como fallo confirmado. `python tools\analizar-uso.py` junta las dos mitades y
da el porcentaje. Es el único dato que no depende de que nadie interprete nada.

---

## 2. Las 10 ideas nuevas (17/09) y su estado

| # | Idea | Estado |
|---|---|---|
| 1 | Vocabulario según el juego abierto | **BLOQUEADA**: la duda entre candidatos no se registra en ningún sitio, así que no se puede saber si pasa 5 veces al día o 2 al mes. Hay que instrumentar un contador primero |
| 2 | No repasar lo que nunca fue una orden | **DESCARTADA** con datos (ver 1.3) |
| 3 | «¿Cómo me has entendido hoy?» | pendiente |
| 4 | Repaso del día: preguntar por las 3 peores | pendiente |
| 5 | Perfil de ruido por hora | pendiente |
| 6 | Deshacer con historial | pendiente |
| 7 | Leer una zona de la pantalla | pendiente |
| 8 | Modo sin manos (confirmar con el mando) | pendiente |
| 9 | Segunda opinión también en órdenes ambiguas | pendiente |
| 10 | Avisos al móvil | pendiente (la más cara y la que menos acerca al 100 %) |

---

## 3. Auditoría completa de Nova (17/09)

Cuatro auditorías en paralelo, por áreas disjuntas. Cada hallazgo viene con severidad,
cómo se mide y **5 mejoras** concretas.

- [ ] **3.1 El oído** — `wake_vosk.py`, activación, ganancia, Parakeet/Whisper.
- [ ] **3.2 El núcleo de órdenes** — resolución, recetas, reglas, traducciones, modos.
- [ ] **3.3 La cápsula y los workers** — `nova_ui.cs`, voz, charla, cerebro.
- [ ] **3.4 Robustez y datos** — persistencia, procesos, config, y pruebas que mienten.

*(Pendiente de rellenar: las cuatro estaban ejecutándose cuando se creó este archivo. Sus
informes van en el scratchpad de la sesión como `informe-oido.md`, `informe-ordenes.md`,
`informe-capsula.md` e `informe-robustez.md`.)*

---

## 4. Lo que ya sabíamos que fallaba (arreglado hoy, por si vuelve)

- **La calibración del micro se tiraba en cada arranque** (38 veces). Causaba las dos
  quejas a la vez: se activaba sola con ruido y no oía a braya. Blindado en
  `tools\probar-escucha.py`.
- **Un juego con nombre vacío se llevaba cualquier orden** (`$q -match '\b\b'` casa
  siempre). Encontrado montando las primeras pruebas de `Find-JuegoEn`, que no tenía
  ninguna pese a su historial.
- **Un banco que cambiaba de color según la hora**: `probar-entorno.ps1` daba 12 fallos
  falsos de madrugada, y uno de sus OK era falso.
