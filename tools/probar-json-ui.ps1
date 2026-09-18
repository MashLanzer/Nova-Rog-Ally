# Comprueba que el JSON que el asistente escribe para la capsula sigue siendo
# valido y lleva los campos nuevos. Se saca Set-UI DEL ARCHIVO REAL.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'ConvertTo-JsonTexto')
Invoke-Expression (TraerFn 'Set-UI')

# --- mundo de mentira ---
$UiNuevaOn = $true
$RutaUiEstado = Join-Path $env:TEMP 'ui-estado-prueba.json'
$MarcaSoloBoton = Join-Path $env:TEMP 'solo-boton-prueba.flag'
$EscuchaOn = $true
$script:reloj = 100000
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$script:wakeProc = [PSCustomObject]@{ HasExited = $false }
$script:temporizadores = New-Object System.Collections.ArrayList
$script:uiEvento = ''; $script:uiEventoN = 0; $script:juegoExe = ''; $script:uiAudio = ''
$script:uiBateria = 88; $script:uiCargando = 0; $script:uiPerfil = ''; $script:uiCarga = 12
$script:uiClima = ''; $script:uiAnimo = 0.0; $script:uiProgreso = 0.0; $script:uiVoz = 0
$script:uiUltimo = ''; $script:uiHasta = 0; $script:sordinaHasta = 0
$script:confirmaFin = 0; $script:confirmaTotal = 0

function Comprobar($etiqueta, $oidoEsperado, $tipoEsperado) {
    $script:uiUltimo = ''   # forzar reescritura
    Set-UI 'reposo' 'hola'
    $txt = Get-Content -Raw -LiteralPath $RutaUiEstado
    try { $j = $txt | ConvertFrom-Json } catch { Write-Host "  MAL  $etiqueta -> JSON INVALIDO: $txt"; return $false }
    $ok = ($j.oido -eq $oidoEsperado) -and ($j.tempoTipo -eq $tipoEsperado)
    # Write-Host, no la cadena suelta: si se devuelve, el llamador recibe un
    # array [texto, bool] que SIEMPRE es truthy y la comprobacion no comprueba nada
    Write-Host ("  {0}  {1,-26} oido='{2}' tempoTipo='{3}'" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $j.oido, $j.tempoTipo)
    return $ok
}

$fallos = 0
Write-Host "--- campos nuevos segun la situacion ---"
if (Test-Path $MarcaSoloBoton) { Remove-Item $MarcaSoloBoton -Force }
if (-not (Comprobar 'normal' 'palabra' '')) { $fallos++ }

Set-Content -Path $MarcaSoloBoton -Value 'x'
if (-not (Comprobar 'jugando (solo boton)' 'boton' '')) { $fallos++ }
Remove-Item $MarcaSoloBoton -Force

$script:sordinaHasta = $script:reloj + 600000
if (-not (Comprobar 'en sordina' 'sorda' '')) { $fallos++ }

[void]$script:temporizadores.Add(@{ vence = ($script:reloj + 600000); texto = 'vuelvo'; total = 600000; tipo = 'sordina' })
if (-not (Comprobar 'sordina con su anillo' 'sorda' 'sordina')) { $fallos++ }

$script:sordinaHasta = 0
$script:temporizadores.Clear()
[void]$script:temporizadores.Add(@{ vence = ($script:reloj + 120000); texto = 'saca la pizza'; total = 120000 })
if (-not (Comprobar 'temporizador normal' 'palabra' '')) { $fallos++ }

# El plazo del si/no: si estos dos campos no salen como numeros, la capsula no
# puede dibujar la barra vaciandose y el JSON entero se cae.
$script:temporizadores.Clear()
$script:confirmaFin = 1789211478223; $script:confirmaTotal = 6000
$script:uiUltimo = ''
Set-UI 'confirmando' 'abro Little Nightmares?'
$txtC = Get-Content -Raw -LiteralPath $RutaUiEstado
$okC = $false
try {
    $jc = $txtC | ConvertFrom-Json
    $okC = ($jc.estado -eq 'confirmando') -and ($jc.confirmaFin -eq 1789211478223) -and ($jc.confirmaTotal -eq 6000)
} catch { $okC = $false }
Write-Host ("  {0}  {1,-26} estado='{2}' plazo={3}" -f $(if ($okC) { 'OK ' } else { 'MAL' }), 'esperando si/no', $jc.estado, $jc.confirmaTotal)
if (-not $okC) { $fallos++ }

# LOS DOS CAMPOS NUEVOS: que esta haciendo (el glifo) y como va la descarga
# (el anillo). El decimal es lo delicado: con la cultura de esta maquina un
# 0,650 con coma rompe el JSON entero, y entonces la capsula no falla de forma
# visible: se queda con el ultimo estado bueno y no hay manera de saber por que.
$script:temporizadores.Clear()
$script:confirmaFin = 0; $script:confirmaTotal = 0
$script:uiHaciendo = 'sonido'; $script:uiDescarga = 0.65; $script:uiCola = '3/2!'
$script:uiUltimo = ''
Set-UI 'reposo' 'bajando el volumen'
$txtD = Get-Content -Raw -LiteralPath $RutaUiEstado
$okD = $false; $jd = $null
try {
    $jd = $txtD | ConvertFrom-Json
    $okD = ($jd.haciendo -eq 'sonido') -and ($txtD -match '"descarga":0\.650') -and ($jd.cola -eq '3/2!')
} catch { $okD = $false }
Write-Host ("  {0}  {1,-26} haciendo='{2}' descarga={3}" -f $(if ($okD) { 'OK ' } else { 'MAL' }), 'accion en curso', $jd.haciendo, $jd.descarga)
if (-not $okD) { $fallos++ }

# y que al terminar se APAGUEN los dos: un glifo que se queda encendido dice
# que esta haciendo algo cuando ya no hace nada
$script:uiHaciendo = ''; $script:uiDescarga = 0; $script:uiCola = ''
$script:uiUltimo = ''
Set-UI 'reposo' 'listo'
$txtE = Get-Content -Raw -LiteralPath $RutaUiEstado
$okE = $false; $je = $null
try {
    $je = $txtE | ConvertFrom-Json
    $okE = ($je.haciendo -eq '') -and ([double]$je.descarga -eq 0) -and ($je.cola -eq '')
} catch { $okE = $false }
Write-Host ("  {0}  {1,-26} haciendo='{2}' descarga={3}" -f $(if ($okE) { 'OK ' } else { 'MAL' }), 'y se apagan al acabar', $je.haciendo, $je.descarga)
if (-not $okE) { $fallos++ }

Remove-Item $RutaUiEstado -Force -ErrorAction SilentlyContinue

# CADA ANIMACION SIN FIN, CON SU TOPE DE FOTOGRAMAS (18/09).
# Una animacion Forever a 60 fps cuesta un cuarto de nucleo (lo dice el comentario de
# nova_ui.cs junto al vaiven), y con un juego delante eso se paga en fluidez, que es la
# prioridad numero dos de braya. El 13/09 y el 17/09 se les puso tope a todas... menos a una:
# el barrido de la barra de progreso, que es justo la que sale en las esperas largas. Se
# escapo DOS RONDAS SEGUIDAS porque nadie lo comprobaba.
# Esto no ejecuta la capsula: lee el fuente y comprueba la regla.
Write-Host ""
Write-Host "  -- cada animacion sin fin lleva su tope de fotogramas --"
$fuenteUI = [System.IO.File]::ReadAllText((Join-Path (Split-Path -Parent $PSScriptRoot) 'nova_ui.cs'))
$lineasUI = $fuenteUI -split "`r?`n"
$sinTope = @()
for ($i = 0; $i -lt $lineasUI.Count; $i++) {
    if ($lineasUI[$i] -notmatch 'RepeatBehavior\.Forever') { continue }
    # la ventana: el tope se pone junto a la animacion, antes o despues de arrancarla.
    # 8 y no 6, medido: las distancias reales son +2, +6, +3, +1, +4, +3, +3, y la del vaiven
    # esta justo en el borde de 6. Con margen exacto, un comentario nuevo ahi pondria esto en
    # rojo sin que nada estuviera roto.
    $desde = [Math]::Max(0, $i - 8)
    $hasta = [Math]::Min($lineasUI.Count - 1, $i + 8)
    $trozo = ($lineasUI[$desde..$hasta] -join "`n")
    if ($trozo -notmatch 'SetDesiredFrameRate') { $sinTope += ($i + 1) }
}
$nForever = ([regex]::Matches($fuenteUI, 'RepeatBehavior\.Forever')).Count
Write-Host ("  {0}  {1,-42} {2}" -f $(if ($sinTope.Count -eq 0) { 'OK ' } else { 'MAL' }),
    "las $nForever animaciones sin fin tienen tope", $(if ($sinTope.Count -eq 0) { '' } else { 'sin tope en la linea ' + ($sinTope -join ', ') }))
if ($sinTope.Count -gt 0) { $fallos++ }
# y que sigan existiendo: si alguien las quita o cambia el nombre, esto se queda en verde
# comprobando nada, que es como se cuelan estas cosas
Write-Host ("  {0}  {1,-42} {2}" -f $(if ($nForever -ge 7) { 'OK ' } else { 'MAL' }),
    'y no han desaparecido del fuente', "hay $nForever")
if ($nForever -lt 7) { $fallos++ }

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
