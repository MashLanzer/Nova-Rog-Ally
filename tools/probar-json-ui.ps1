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

Remove-Item $RutaUiEstado -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
