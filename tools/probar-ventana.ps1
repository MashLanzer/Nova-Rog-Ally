# "Siempre encima" sobre la ventana de delante: se prueba con una ventana de
# mentira (nunca se muestra ni se activa) para no robarle el foco a lo que
# estés haciendo. Lo que se comprueba es que el estilo WS_EX_TOPMOST cambie de
# verdad en los dos sentidos, y que leerlo diga la verdad: si EstaEncima
# mintiera, el asistente contestaría "ya estaba" y no haría nada.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant-dx.dll')

$f = New-Object System.Windows.Forms.Form
$f.FormBorderStyle = 'None'; $f.ShowInTaskbar = $false
$f.Size = New-Object System.Drawing.Size(80, 40)
$f.Location = New-Object System.Drawing.Point(-4000, -4000)   # fuera de la vista
$h = $f.Handle

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

$f.Dispose()
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
