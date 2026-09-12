# Banco de pruebas del entendimiento

Cada archivo es una lista de ordenes, una por linea. Las lineas que empiezan
por `#` son comentarios.

    powershell -File assistant.ps1 -Probar pruebas\ordenes-que-funcionaban.txt

O todo de una vez, incluyendo los patrones y las funciones sueltas:

    powershell -NoProfile -File tools\probar-todo.ps1

Dice cuales resuelve la capa local (`OK`) y cuales acabarian en el agente
(`->IA`). No ejecuta ninguna accion y no toca tu memoria: reglas,
recordatorios, fechas y estadisticas se desvian a una carpeta temporal.

- `ordenes-que-funcionaban.txt`: sacadas del log, de las que el asistente ya
  resolvia en local. Sirven de red contra regresiones: si baja el numero,
  algo se ha roto.
- `ordenes-que-fallaban.txt`: las que el log daba por no reconocidas. Muchas
  son ruido de activaciones falsas y charla, asi que este numero NO tiene que
  llegar al total; lo que importa es que suba cuando se arregla algo.
- `ruido-real.txt`: **corpus negativo**. Son los 103 dictados que el microfono
  capto de verdad (sacados de `assistant.log`): audio de videos, del juego y de
  gente hablando al lado. Aqui lo bueno es que el numero sea BAJO. Si sube, la
  capa local se ha vuelto confiada y el asistente volvera a hacer cosas que
  nadie le pidio. Cuando se creo reconocia 18 de 103; tras los arreglos del
  11/09 son 9, y de esos 6 son ordenes de verdad que estaban mezcladas.
- `casos-nuevos.txt`: casos concretos que se estan trabajando, con sus
  controles (frases que NO se deben partir ni reconocer de mas).
- `destinos.txt`: a DONDE tiene que ir cada frase, no solo que se entienda.
  Los demas archivos cuentan cuantas resuelve la capa local, y ese numero no
  ve las COLISIONES: dos ordenes pueden entenderse las dos y una haberse
  comido a la otra sin que el total se mueva. Paso el 12/09 con "sube" y
  "baja", que se los trago el patron del tamano de la capsula. Se pasa con
  `tools\probar-destinos.ps1` y va dentro de `probar-todo.ps1`.
