# TRABAJAR CUANDO NO MOLESTA (25/09, idea 27 de las 50)
#
# LO MEDIDO: de 2.166 ordenes en dieciseis dias, CERO caen entre las 02 y las 08. Seis horas
# muertas cada dia. Y Nova esta despierta en esa franja -6.027 lineas de registro, en NUEVE
# noches distintas-: lo unico que hace es escuchar a nadie y aparcar avisos.
#
# Mientras tanto, la copia de lo aprendido se ha hecho TRECE veces y las trece entre las 17 y
# las 22 h, que son justo las horas de mas uso (235 ordenes a las 18h, 198 a las 19h). No es
# mala suerte: la copia se intenta EN EL PRIMER MINUTO TRAS ARRANCAR y braya arranca Nova
# cuando se pone a usarla. La tarea mas pesada del dia cae siempre en el peor momento.
#
# LO QUE **NO** SE HACE, y es la mitad de la idea: mirar el reloj. La franja de 02 a 08 es lo
# que braya hace HOY; atarse a eso seria un numero inventado el dia que cambie de horario. Se
# mira si esta DELANTE, que es lo que de verdad importa.
#
# Y LLEVA PLAZO (regla 2): aplazar sin tope convierte "cuando no moleste" en "nunca". Pasadas
# TrabajoEsperaMaxHoras se hace igual. Una copia tarde es un incordio; una que no se hace nunca
# es perder lo aprendido.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. existe, y la copia lo pregunta --'
Comp 'existe Test-BuenRatoParaTrabajo' ($sinCom -match 'function Test-BuenRatoParaTrabajo') ''
Comp 'existe Get-CopiaHorasEsperando' ($sinCom -match 'function Get-CopiaHorasEsperando') ''
$usos = @([regex]::Matches($sinCom, '(?<!function )Test-BuenRatoParaTrabajo')).Count
Comp 'y la copia lo pregunta en sus DOS caminos' ($usos -ge 2) "$usos uso(s): el del arranque y el del cambio de dia"
# Y QUE SIGA SIENDO LA MISMA COPIA: si la guarda nueva hubiera sustituido a Test-CopiaPendiente
# en vez de sumarse, se harian copias de mas.
Comp 'sin quitar la condicion de siempre' ($sinCom -match 'if \(Test-CopiaPendiente\)') 'la guarda nueva se suma, no sustituye'

Write-Host ''
Write-Host '-- 2. LA DECISION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-BuenRatoParaTrabajo' }, $true)
if (-not $d) { Comp 'se saca del arbol' $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
Invoke-Expression $d.Extent.Text
foreach ($cte in @('TrabajoAusenciaMin', 'TrabajoEsperaMaxHoras')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(\d+)'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value) }
}

Write-Host ''
Write-Host '-- 3. EL CASO REAL: braya delante, a las siete de la tarde --'
# Esto es lo que pasaba las trece veces: arranca Nova, se pone a usarla, y la copia salta.
Comp 'con braya recien llegado, NO se hace' (-not (Test-BuenRatoParaTrabajo 0 $false 21.0)) 'ausencia 0 min, 21 h esperando'
Comp '  ni a los cinco minutos' (-not (Test-BuenRatoParaTrabajo 5 $false 21.0)) ''
Comp 'pero sin nadie delante, SI' (Test-BuenRatoParaTrabajo 60 $false 21.0) 'una hora sin nadie'
Comp '  y justo en el liston tambien' (Test-BuenRatoParaTrabajo $TrabajoAusenciaMin $false 21.0) "$TrabajoAusenciaMin min"
Comp '  pero un minuto antes NO' (-not (Test-BuenRatoParaTrabajo ($TrabajoAusenciaMin - 1) $false 21.0)) ''

Write-Host ''
Write-Host '-- 4. CON UN JUEGO DELANTE, NUNCA (mientras haya plazo) --'
Comp 'jugando no se hace, aunque no haya nadie hablando' (-not (Test-BuenRatoParaTrabajo 999 $true 21.0)) 'comprimir 40 archivos mientras juegas es lo peor'

Write-Host ''
Write-Host '-- 5. PERO TIENE PLAZO, o seria un modo sin salida --'
# LA REGLA 2 DE LA CASA: ningun modo sin dos salidas y un plazo. Sin esto, una semana jugando
# seguido dejaria a Nova sin copias y sin decir nada.
Comp 'pasado el tope se hace aunque estorbe' (Test-BuenRatoParaTrabajo 0 $false ($TrabajoEsperaMaxHoras + 1)) "$($TrabajoEsperaMaxHoras + 1) h esperando"
Comp '  incluso con un juego delante' (Test-BuenRatoParaTrabajo 0 $true ($TrabajoEsperaMaxHoras + 1)) 'perder lo aprendido es peor que un tiron'
Comp '  y justo en el tope, tambien' (Test-BuenRatoParaTrabajo 0 $true ([double]$TrabajoEsperaMaxHoras)) ''
Comp 'y por debajo del tope el juego sigue mandando' (-not (Test-BuenRatoParaTrabajo 0 $true ($TrabajoEsperaMaxHoras - 1))) ''

Write-Host ''
Write-Host '-- 6. la cuenta de lo que lleva esperando --'
$dH = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-CopiaHorasEsperando' }, $true)
Invoke-Expression $dH.Extent.Text
$CopiasDir = Join-Path $env:TEMP ('nova-copias-prueba-' + [guid]::NewGuid().ToString('N'))
# SIN CARPETA, SE DA POR VIEJISIMA: si devolviera 0, la primera copia de una instalacion nueva
# no se haria hasta que alguien se fuera 15 minutos.
Comp 'sin carpeta de copias, se da por muy vieja' ((Get-CopiaHorasEsperando) -ge $TrabajoEsperaMaxHoras) "$(Get-CopiaHorasEsperando) h"
New-Item -ItemType Directory -Path $CopiasDir -Force | Out-Null
Comp 'con la carpeta vacia, igual' ((Get-CopiaHorasEsperando) -ge $TrabajoEsperaMaxHoras) ''
$zp = Join-Path $CopiasDir 'lo-aprendido_2026-09-25_1000.zip'
Set-Content -LiteralPath $zp -Value 'x' -Encoding Ascii
(Get-Item -LiteralPath $zp).LastWriteTime = (Get-Date).AddHours(-3)
Comp 'con una copia de hace 3 horas, dice 3' ([Math]::Abs((Get-CopiaHorasEsperando) - 3.0) -lt 0.2) "$([Math]::Round((Get-CopiaHorasEsperando),1)) h"
Comp '  y con eso NO toca hacerla si hay alguien' (-not (Test-BuenRatoParaTrabajo 0 $false (Get-CopiaHorasEsperando))) ''
(Get-Item -LiteralPath $zp).LastWriteTime = (Get-Date).AddHours(-40)
Comp 'con una de hace 40 horas, se hace ya' (Test-BuenRatoParaTrabajo 0 $true (Get-CopiaHorasEsperando)) "$([Math]::Round((Get-CopiaHorasEsperando),1)) h"
Remove-Item -LiteralPath $CopiasDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el trabajo pesado espera a un rato que no moleste'
exit 0
