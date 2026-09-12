# "Siempre encima" sobre la ventana de delante: se prueba con una ventana de
# mentira, colocada fuera de la pantalla, para no molestar a lo que estés
# haciendo. Lo que se comprueba es que el estilo WS_EX_TOPMOST cambie de verdad
# en los dos sentidos, y que leerlo diga la verdad: si EstaEncima mintiera, el
# asistente contestaría "ya estaba" y no haría nada.
#
# LA VENTANA TIENE QUE ESTAR MOSTRADA, y esto costó un fallo rojo en el banco
# durante días: sobre una ventana que NUNCA se ha mostrado, SetWindowPos con
# HWND_TOPMOST devuelve true y no marca nada (medido: el estilo se queda en
# 0x10000 en vez de 0x10008). No era un fallo del asistente -en uso real la
# ventana siempre se ve- sino de esta prueba, que la creaba y no la mostraba.
# Se muestra con SW_SHOWNA (8), que la hace visible SIN activarla: así sigue
# sin robarle el foco a nadie, que era el motivo de no mostrarla.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant-dx.dll')

$f = New-Object System.Windows.Forms.Form
$f.FormBorderStyle = 'None'; $f.ShowInTaskbar = $false
$f.Size = New-Object System.Drawing.Size(80, 40)
$f.Location = New-Object System.Drawing.Point(-4000, -4000)   # fuera de la vista
$h = $f.Handle
[void][AX]::ShowWindow($h, 8)      # SW_SHOWNA: visible pero sin activarla
Start-Sleep -Milliseconds 150

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-32} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

$antes = [AX]::EstaEncima($h)
Comp 'empieza sin estar encima'  (-not $antes) ''
$puso = [AX]::SiempreEncima($h, $true)
$ahora = [AX]::EstaEncima($h)
Comp 'se pone siempre encima'    ($puso -and $ahora) "puso=$puso lee=$ahora"
$quito = [AX]::SiempreEncima($h, $false)
$final = [AX]::EstaEncima($h)
Comp 'y se puede quitar'         ($quito -and -not $final) "quito=$quito lee=$final"
Comp 'una ventana que no existe' (-not [AX]::SiempreEncima([IntPtr]::Zero, $true)) 'no revienta'

[void][AX]::ShowWindow($h, 0)      # SW_HIDE, antes de soltarla
$f.Dispose()
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
