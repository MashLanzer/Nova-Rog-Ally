# QUE NOVA SE INCLUYA EN EL PARTE SEMANAL QUE YA ESCRIBE (17/09).
#
# La nota semanal ya contaba cuantas cosas le pediste, cuantas resolvio al instante, los
# tropiezos y lo que no entendio... pero hablaba solo de ti. Desde esta tanda Nova toma
# decisiones propias -apagar la nube, el oido fino o el ultimo recurso, avisar de que su idea
# de tu voz se ha movido- y eso no estaba en ninguna parte que braya fuera a leer: solo en el
# log.
#
# Lo que mas se comprueba: que si NO decidio nada, no escriba ninguna linea (un parte que
# dice "no hice nada especial" cansa mas de lo que informa) y que solo cuente lo de ESA
# semana.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Get-ParrafoDecisiones')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
$ini = [datetime]'2026-09-07'
$fin = [datetime]'2026-09-13'
function Stats($lineas) { return @{ recientes = @($lineas) } }

Write-Host '  -- una semana sin decisiones no dice nada --'
Comp 'sin recientes, parrafo vacio' ((Get-ParrafoDecisiones (Stats @()) $ini $fin) -eq '') ''
$soloOtras = Stats @('2026-09-10 11:00  [local]  abre steam', '2026-09-11 12:00  [charla]  hola')
Comp 'con actividad normal, tampoco' ((Get-ParrafoDecisiones $soloOtras $ini $fin) -eq '') ''

Write-Host '  -- y cuando decide, lo cuenta con su numero --'
$una = Stats @('2026-09-10 11:00  [auto-ajuste]  ultimo recurso off: 1 de 29')
$p = Get-ParrafoDecisiones $una $ini $fin
Comp 'una decision se cuenta' ($p -match 'decidi una cosa') ("'" + $p + "'")
Comp 'y trae el dato que la justifica' ($p -match '1 de 29') ''

$dos = Stats @('2026-09-10 11:00  [auto-ajuste]  ultimo recurso off: 1 de 29',
               '2026-09-12 09:00  [auto-ajuste]  nube off: 1 de 24')
$p2 = Get-ParrafoDecisiones $dos $ini $fin
Comp 'dos decisiones, en plural' ($p2 -match 'decidi 2 cosas') ("'" + $p2 + "'")
Comp 'y salen las dos' ($p2 -match '29' -and $p2 -match '24') ''

Write-Host '  -- y reconoce cuando se equivoco --'
$conDeshacer = Stats @('2026-09-10 11:00  [auto-ajuste]  nube off: 1 de 24',
                       '2026-09-10 11:30  [auto-deshecho]  escucha.nubeOir')
$p3 = Get-ParrafoDecisiones $conDeshacer $ini $fin
Comp 'dice que se lo deshiciste' ($p3 -match 'deshacer') ("'" + $p3 + "'")
Comp 'y lo admite' ($p3 -match 'equivoque') ''

Write-Host '  -- y cuenta si arranco a medias --'
$medias = Stats @('2026-09-11 08:00  [arranque-medias]  me falta la capsula',
                  '2026-09-12 08:00  [arranque-medias]  no encuentro el agente')
$p4 = Get-ParrafoDecisiones $medias $ini $fin
Comp 'dos arranques a medias' ($p4 -match 'a medias 2 veces') ("'" + $p4 + "'")

Write-Host '  -- SOLO lo de esa semana (lo importante) --'
$fuera = Stats @('2026-09-01 11:00  [auto-ajuste]  algo viejo: 1 de 30',
                 '2026-09-20 11:00  [auto-ajuste]  algo futuro: 2 de 30')
Comp 'lo de antes y lo de despues no cuentan' ((Get-ParrafoDecisiones $fuera $ini $fin) -eq '') ("'" + (Get-ParrafoDecisiones $fuera $ini $fin) + "'")
$borde = Stats @('2026-09-07 00:05  [auto-ajuste]  el primer dia: 1 de 30',
                 '2026-09-13 23:55  [auto-ajuste]  el ultimo dia: 2 de 30')
Comp 'los dos dias del borde SI cuentan' ((Get-ParrafoDecisiones $borde $ini $fin) -match 'decidi 2 cosas') ''

Write-Host '  -- y lo raro no lo rompe --'
Comp 'una linea con formato roto se salta' ((Get-ParrafoDecisiones (Stats @('basura', '2026-13-45 xx [auto-ajuste] mal')) $ini $fin) -eq '') ''
Comp 'sin recientes ninguno, no revienta' ((Get-ParrafoDecisiones @{} $ini $fin) -eq '') ''

# --- y que el parte lo use de verdad ---
Write-Host '  -- y la nota semanal lo escribe --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
$i = $txt.IndexOf('function Write-NotaSemanal')
$j = $txt.IndexOf("`nfunction ", $i + 10)
$cuerpo = $txt.Substring($i, $j - $i)
Comp 'Write-NotaSemanal llama al parrafo' ($cuerpo -match 'Get-ParrafoDecisiones') ''
Comp 'y solo lo escribe si hay algo que contar' ($cuerpo -match 'if \(\$parrafoYo\)') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
