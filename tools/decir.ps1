param([Parameter(Mandatory = $true)][string]$Frase)
# Le pasa una orden ESCRITA al asistente encendido, como si se hubiera dicho en
# voz alta. Sirve para probar de extremo a extremo sin hablar (el cerebro, las
# reglas, la capsula...). El asistente la recoge en su bucle cuando no esta
# ocupado ni escuchando, y la borra al leerla.
#
#   powershell -NoProfile -File tools\decir.ps1 "que hora es en tokio"
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'tmp\orden-escrita.txt'
[System.IO.File]::WriteAllText($ruta, $Frase, (New-Object System.Text.UTF8Encoding($false)))
"dejada para el asistente: $Frase"
