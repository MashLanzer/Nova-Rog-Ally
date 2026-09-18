# QUE UN "NO" NO DURE PARA SIEMPRE, Y QUE UN "SI" SI (17/09).
#
# Nova propone convertir en regla lo que repites ("a esta hora sueles pedirme X, ¿lo hago yo
# sola?"). La lista de propuestas ya tratadas NO se podaba nunca -comprobado: ni una linea
# que la limpie- asi que un "no" suelto vetaba esa propuesta el resto de la vida de Nova.
#
# Y en la misma lista se guardan las que ACEPTASTE, para no volver a ofrecer algo que ya es
# una regla. Esas no pueden caducar: la regla existe. De ahi que haya que distinguirlas.
#
# Lo que mas se comprueba aqui: que lo aceptado no vuelva NUNCA, que lo rechazado vuelva UNA
# vez pasados los 60 dias, y que lo guardado con el formato viejo se respete.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txtA = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
if ($txtA -match '(?m)^\$PropuestaVetoDias = (\d+)') { $PropuestaVetoDias = [int]$Matches[1] } else { throw 'no encuentro PropuestaVetoDias' }
Invoke-Expression (Traer 'Test-PropuestaVetada')
Invoke-Expression (Traer 'Add-PropuestaTratada')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
$hoy = [datetime]'2026-09-17'
function Nuevo { return @{ rechazadas = (New-Object System.Collections.ArrayList) } }

# las claves DE VERDAD llevan "|" dentro: por eso la fecha no se puede pegar con ese
# separador y las entradas son objetos
$claveHora = 'hora|abre steam'
$claveApp  = 'app|edge|abre spotify'
$claveSeq  = 'seq|abre steam|pon modo juego|sube el volumen'

Write-Host '  -- lo que aceptaste no se vuelve a proponer JAMAS --'
$hb = Nuevo
Add-PropuestaTratada $hb $claveHora $true $hoy
Comp 'recien aceptada, vetada' (Test-PropuestaVetada $hb $claveHora $hoy) ''
Comp 'y cinco anos despues, sigue vetada' (Test-PropuestaVetada $hb $claveHora $hoy.AddDays(1825)) ''

Write-Host '  -- lo que rechazaste vuelve, pero no manana --'
$hb = Nuevo
Add-PropuestaTratada $hb $claveApp $false $hoy
Comp 'recien rechazada, vetada' (Test-PropuestaVetada $hb $claveApp $hoy) ''
Comp 'a los 30 dias sigue vetada' (Test-PropuestaVetada $hb $claveApp $hoy.AddDays(30)) ''
Comp "al dia $PropuestaVetoDias ya se puede volver a ofrecer" (-not (Test-PropuestaVetada $hb $claveApp $hoy.AddDays($PropuestaVetoDias))) ''
Comp 'y al ano, claro' (-not (Test-PropuestaVetada $hb $claveApp $hoy.AddDays(365))) ''

Write-Host '  -- las claves con barras dentro no se rompen --'
$hb = Nuevo
Add-PropuestaTratada $hb $claveSeq $false $hoy
Comp 'una secuencia con tres ordenes se guarda entera' (Test-PropuestaVetada $hb $claveSeq $hoy) ''
Comp 'y no confunde una clave con otra' (-not (Test-PropuestaVetada $hb $claveHora $hoy)) ''

Write-Host '  -- lo guardado con el formato viejo se respeta --'
# antes eran textos sueltos y no se sabe si fueron un si o un no: se dejan permanentes,
# que es equivocarse hacia el lado de no molestar
$hb = Nuevo
[void]$hb.rechazadas.Add($claveHora)
Comp 'un texto suelto sigue vetando' (Test-PropuestaVetada $hb $claveHora $hoy) ''
Comp 'y sigue vetando dentro de dos anos' (Test-PropuestaVetada $hb $claveHora $hoy.AddDays(730)) ''

Write-Host '  -- cambiar de idea funciona en los dos sentidos --'
$hb = Nuevo
Add-PropuestaTratada $hb $claveHora $false $hoy      # dijiste que no
Add-PropuestaTratada $hb $claveHora $true $hoy       # y luego que si
Comp 'el si posterior manda' (Test-PropuestaVetada $hb $claveHora $hoy.AddDays(365)) ''
Comp 'y no quedan dos entradas de lo mismo' (@($hb.rechazadas).Count -eq 1) ("entradas: " + @($hb.rechazadas).Count)

Write-Host '  -- la lista no crece para siempre --'
$hb = Nuevo
Add-PropuestaTratada $hb 'hora|vieja' $false $hoy.AddDays(-200)
Add-PropuestaTratada $hb 'hora|aceptada' $true $hoy.AddDays(-200)
Add-PropuestaTratada $hb 'hora|reciente' $false $hoy
Comp 'se poda el "no" caducado al apuntar otra' (@($hb.rechazadas | Where-Object { $_.c -eq 'hora|vieja' }).Count -eq 0) ''
Comp 'pero el "si" viejo NO se poda' (@($hb.rechazadas | Where-Object { $_.c -eq 'hora|aceptada' }).Count -eq 1) ''
Comp 'y la reciente sigue' (Test-PropuestaVetada $hb 'hora|reciente' $hoy) ''

Write-Host '  -- y lo que nunca se propuso, no esta vetado --'
$hb = Nuevo
Comp 'lista vacia no veta nada' (-not (Test-PropuestaVetada $hb $claveHora $hoy)) ''
Comp 'una clave que no esta, tampoco' (-not (Test-PropuestaVetada $hb 'app|nada|nada' $hoy)) ''

# --- y que Find-Propuesta use de verdad la funcion, no el -contains de antes ---
Write-Host '  -- y los tres filtros usan la funcion nueva --'
$fp = Traer 'Find-Propuesta'
Comp 'ningun -contains suelto en Find-Propuesta' (-not ($fp -match 'rechazadas -contains')) ''
Comp 'y los tres sitios preguntan por Test-PropuestaVetada' (([regex]::Matches($fp, 'Test-PropuestaVetada')).Count -eq 3) ("veces: " + ([regex]::Matches($fp, 'Test-PropuestaVetada')).Count)

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
