# EL LOG ES EL INSTRUMENTO CON EL QUE SE DECIDE TODO AQUI (18/09).
#
# Y hasta hoy no lo comprobaba nadie: 26 probadores mencionan Log, pero todos lo DOBLAN con una
# funcion vacia para que no ensucie; ninguno miraba el de verdad. Asi se colaron dos cosas:
#
#  · la salida del agente llega con saltos de linea dentro y Out-File la escribia tal cual, asi
#    que solo la primera quedaba fechada. En el log real hay 79 lineas huerfanas de ese tipo,
#    y rompen cualquier analisis por columnas.
#  · Rotate-Log se llamaba en CADA escritura, con su Get-Item .Length: 26.906 comprobaciones
#    del tamaño del fichero.
#
# Aqui se saca Log y Rotate-Log DEL ARCHIVO REAL y se escriben en un log de mentira.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}

$base = Join-Path $env:TEMP ('probar-log-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $base -Force
$EventLog = Join-Path $base 'assistant.log'
$MaxLogBytes = 2048          # pequeño a proposito: asi la rotacion se puede provocar
$KeepLogs = 3
$Probar = $true
$script:logEscrituras = 0
Invoke-Expression (Traer 'Rotate-Log')
Invoke-Expression (Traer 'Log')

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# LA COMA NO ES UN ADORNO: sin ella, con UNA sola linea PowerShell desenrolla el array y
# devuelve la cadena, con lo que (Lineas)[0] da su primer CARACTER en vez de la linea entera.
# Lo avisa la cabecera de probar-destino-uso.ps1 y me lo he vuelto a comer aqui.
function Lineas { return ,@(Get-Content -LiteralPath $EventLog -ErrorAction SilentlyContinue) }
$RE = '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}  '

Write-Host '  -- una linea normal, como siempre --'
Log 'orden recibida'
$l = Lineas
Comp 'se escribe con su marca de tiempo' ($l.Count -eq 1 -and $l[0] -match $RE) ($l -join '')
Comp 'y con el texto detras' ($l[0] -match 'orden recibida$') ''

Write-Host '  -- y la salida del agente, que viene en varias lineas --'
# esto es lo que de verdad pasaba: 79 lineas huerfanas en el log real
Log "Abro Steam ahora.`nLa pagina ya esta abierta.`nListo."
$l = Lineas
$sinMarca = @($l | Where-Object { $_.Trim() -and $_ -notmatch $RE })
Comp 'las tres lineas quedan escritas' ($l.Count -eq 4) ("lineas: " + $l.Count)
Comp 'y NINGUNA se queda sin marca de tiempo' ($sinMarca.Count -eq 0) (($sinMarca -join ' | '))
Comp 'el texto no se pierde por el camino' (($l -join ' ') -match 'Abro Steam ahora' -and ($l -join ' ') -match 'Listo\.') ''

Write-Host '  -- el tamaño no se mira en cada linea (pero se mira) --'
# con el tope en 2 KB, escribir de sobra tiene que acabar rotando
$antes = $script:logEscrituras
foreach ($i in 1..120) { Log ("relleno de prueba numero $i, con texto suficiente para llenar el fichero de mentira") }
Comp 'el contador avanza con cada escritura' ($script:logEscrituras -eq ($antes + 120)) ("escrituras: " + $script:logEscrituras)
Comp 'y acaba rotando (existe el .1)' (Test-Path -LiteralPath "$EventLog.1") ''

Write-Host '  -- lo que NO puede pasar: perder el historico --'
# el arranque rotaba por su cuenta a .1 pisando el anterior; ahora hay un solo camino, con
# KeepLogs copias. Con suficiente escritura tiene que aparecer tambien el .2
foreach ($i in 1..200) { Log ("mas relleno $i, texto largo para forzar varias rotaciones seguidas del fichero") }
Comp 'se guardan varias copias, no solo una' (Test-Path -LiteralPath "$EventLog.2") ''

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue

# LA SALIDA LIMPIA EXISTE Y ESTA ENTERA (18/09). La linea "VoiceAssistant cerrado" solo se
# escribe si el proceso sale por exit (PowerShell.Exiting no se dispara con un kill), y hasta
# hoy la unica forma de parar a Nova era matarla: esa linea no habria salido jamas. Se lee el
# fuente y se comprueba que las cuatro piezas siguen ahi.
Write-Host '  -- la salida limpia, entera --'
$src = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'), [System.Text.Encoding]::UTF8)
Comp 'la marca de salida esta definida' ($src -match '\$MarcaSalir = Join-Path \$TmpDir "salir\.flag"') ''
Comp 'y se limpia al arrancar, con las demas' ($src -match '\$MarcaWake, \$MarcaSalir\)') ''
Comp 'el bucle la mira y sale por exit (no por kill)' ($src -match 'Test-Path -LiteralPath \$MarcaSalir[\s\S]{0,1200}exit 0') ''
# Y CIERRA SUS WORKERS ANTES (18/09, noche): el de escucha miraba al padre solo en su pulso, cada
# 15 s, y se quedaba vivo hasta que parar-nova.ps1 lo mataba. La charla por Stop-Charla, escucha
# y voz por Kill, y todo ANTES del exit, que despues ya no hay quien lo haga.
Comp 'y cierra sus workers antes de salir (charla, escucha, voz)' ($src -match 'Test-Path -LiteralPath \$MarcaSalir[\s\S]{0,900}Stop-Charla[\s\S]{0,500}wakeProc[\s\S]{0,200}ttsProc[\s\S]{0,300}\.Kill\(\)[\s\S]{0,300}exit 0') ''
Comp 'y el cierre deja su linea en el log' ($src -match 'PowerShell\.Exiting[\s\S]{0,200}VoiceAssistant cerrado') ''
Comp 'existe tools\parar-nova.ps1' (Test-Path -LiteralPath (Join-Path $raiz 'tools\parar-nova.ps1')) ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
