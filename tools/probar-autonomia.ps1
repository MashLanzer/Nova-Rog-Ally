# CUANTO DURARA LA BATERIA CON ESTE JUEGO (30/09, la 4 de las 20 funciones nuevas)
#
# El dato ya estaba: Update-BateriaJuego apunta el ritmo en %/h por juego desde el 13/09. Lo que no
# existia era la pregunta. Nova decia "te queda el 60 %", que en una portatil no dice nada: las
# horas dependen del juego.
#
# LO QUE ESTA SECCION VIGILA es que no se invente numeros. Medido el 30/09: de nueve juegos con
# tiempos, solo UNO tiene ritmo apuntado. Asi que los tres casos que importan son: lo se, lo se de
# otros, y no lo se. Los tres tienen que sonar distinto.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($n in @('ConvertTo-Plain', 'Get-TrozoAutonomia')) { Invoke-Expression (Traer $n) }

# los ritmos de pega, como JSON y leidos como JSON: es lo que hace la funcion de verdad
$memJson = @'
{
  "Juego Medido":    { "ritmoBateria": 30, "muestrasBateria": 5 },
  "Juego De Una":    { "ritmoBateria": 50, "muestrasBateria": 1 },
  "Juego Sin Medir": { "dias": { "2026-09-01": 100 } }
}
'@
$mem = $memJson | ConvertFrom-Json
function Get-JuegosMem { return $mem }

Write-Host ''
Write-Host '-- 1. de un juego medido, el tiempo sale de SU ritmo --'
# 60 % al 30 %/h son dos horas justas
$t1 = Get-TrozoAutonomia 60 'Juego Medido'
Comp 'dice las horas que quedan' ($t1 -match '2 horas') "$t1"
Comp '  y no dice que sea una media de otros' ($t1 -notmatch 'media de tus otros') ''
# 30 % al 30 %/h es una hora
Comp 'una hora se dice como una hora' ((Get-TrozoAutonomia 30 'Juego Medido') -match 'una hora') ''
# 15 % al 30 %/h son 30 minutos
Comp 'y menos de una hora, en minutos' ((Get-TrozoAutonomia 15 'Juego Medido') -match '30 minutos') ''

Write-Host ''
Write-Host '-- 2. de una sola partida medida, se avisa --'
$t2 = Get-TrozoAutonomia 50 'Juego De Una'
Comp 'da el numero' ($t2 -match '1 hora|60 minutos') "$t2"
Comp '  pero avisa de que es de una sola partida' ($t2 -match 'una sola partida') 'de una muestra no sale una promesa'

Write-Host ''
Write-Host '-- 3. de un juego sin medir, usa la media y LO DICE --'
$t3 = Get-TrozoAutonomia 40 'Juego Sin Medir'
Comp 'usa la media de los otros' ($t3 -match 'media de tus otros') "$t3"
Comp '  y el numero sale de esa media' ($t3 -match '\d') '(30 y 50 dan media 40: 40 % a 40 %/h = 1 h)'

Write-Host ''
Write-Host '-- 4. y si no sabe nada, lo dice sin inventar --'
$vacio = '{}' | ConvertFrom-Json
function Get-JuegosMem { return $vacio }
$t4 = Get-TrozoAutonomia 60 'Cualquiera'
Comp 'dice que todavia no lo sabe' ($t4 -match 'todavia no se') "$t4"
Comp '  y NO suelta ningun numero de horas' ($t4 -notmatch '\d+\s*(?:horas|minutos)') 'inventar una autonomia es peor que callarse'
Comp '  y promete aprenderlo' ($t4 -match 'aprendo jugando') ''

Write-Host ''
Write-Host '-- 5. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca autonomia' ($sinCom -match "kind = 'autonomia'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'autonomia' \{") ''
# Y NO PISA LA PREGUNTA VIEJA: "cuanta bateria queda" contesta el PORCENTAJE y es otra cosa. La
# responde Get-FraseBateria, no un kind: por eso se comprueba la funcion y no una etiqueta.
Comp '  y sigue existiendo la del porcentaje' ($sinCom -match 'Get-FraseBateria') 'son dos preguntas distintas'
# EL RITMO NO SE ESCRIBE AQUI: lo apunta Update-BateriaJuego, y si alguien lo duplicara se
# separarian el dia que se toque uno (la manera 4 de salir verde mintiendo).
$cuerpo = Traer 'Get-TrozoAutonomia'
Comp 'el ritmo se LEE, no se calcula otra vez' (($cuerpo -match 'ritmoBateria') -and ($cuerpo -notmatch 'Save-JuegosMem')) 'lo apunta Update-BateriaJuego'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova dice cuanto dura la bateria con ESE juego, y dice cuando no lo sabe' -ForegroundColor Green
exit 0
