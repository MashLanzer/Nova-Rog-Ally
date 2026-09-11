# Banco de pruebas del entendimiento

Cada archivo es una lista de ordenes, una por linea. Las lineas que empiezan
por `#` son comentarios.

    powershell -File assistant.ps1 -Probar pruebas\ordenes-que-funcionaban.txt

Dice cuales resuelve la capa local (`OK`) y cuales acabarian en el agente
(`->IA`). No ejecuta ninguna accion y no toca tu memoria: reglas,
recordatorios, fechas y estadisticas se desvian a una carpeta temporal.

- `ordenes-que-funcionaban.txt`: sacadas del log, de las que el asistente ya
  resolvia en local. Sirven de red contra regresiones: si baja el numero,
  algo se ha roto.
- `ordenes-que-fallaban.txt`: las que el log daba por no reconocidas. Muchas
  son ruido de activaciones falsas y charla, asi que este numero NO tiene que
  llegar al total; lo que importa es que suba cuando se arregla algo.
- `casos-nuevos.txt`: casos concretos que se estan trabajando, con sus
  controles (frases que NO se deben partir ni reconocer de mas).
