# LOS UMBRALES DE LAS DECISIONES, EN UN SOLO SITIO (18/09, idea 62).
#
# POR QUE EXISTE. El 15 % de aprovechamiento y los 20 intentos minimos estaban escritos A MANO
# en cuatro sitios: las tres decisiones de Test-RevisionPropia (nube, oido fino, ultimo recurso)
# y Get-AvisoSinDatos, que es la que avisa de que hay una decision esperando datos.
#
# Separarlos NO daria ningun error: Nova avisaria de decisiones que ya no tocan, o callaria las
# que si, y nadie se enteraria. Es el fallo silencioso que este proyecto persigue.
#
# Esta prueba vigila dos cosas: que el calculo sea uno solo, y que NADIE vuelva a escribir el
# numero a mano en esas funciones.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)

# las constantes se leen del propio archivo, no se copian aqui: si cambian, la prueba las sigue
$DecisionAprovecha = if ($txt -match '\$DecisionAprovecha = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
$DecisionMinIntentos = if ($txt -match '\$DecisionMinIntentos = ([0-9]+)') { [int]$Matches[1] } else { -1 }
Invoke-Expression (Traer 'Get-DecisionMinimo')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- las constantes existen y son razonables --'
Comp 'el aprovechamiento minimo esta definido' ($DecisionAprovecha -gt 0 -and $DecisionAprovecha -lt 1) "$DecisionAprovecha"
Comp 'y los intentos minimos tambien' ($DecisionMinIntentos -ge 5) "$DecisionMinIntentos"

Write-Host '  -- el calculo, con los numeros de verdad --'
# el caso real de hoy: el ultimo recurso lleva 1 acierto de 29 intentos
Comp 'con 29 intentos hacen falta 5 aciertos' ((Get-DecisionMinimo 29) -eq 5) "$(Get-DecisionMinimo 29)"
Comp 'y 1 de 29 NO aporta (por eso se apagaria)' (1 -lt (Get-DecisionMinimo 29)) ''
# el oido fino: 27 aciertos menos 5 inventos de 81 repasos = 22 neto
Comp 'con 81 repasos hacen falta 13' ((Get-DecisionMinimo 81) -eq 13) "$(Get-DecisionMinimo 81)"
Comp 'y el neto del oido fino (22) SI aporta' ((27 - 5) -ge (Get-DecisionMinimo 81)) ''
Comp 'redondea hacia arriba, no hacia abajo' ((Get-DecisionMinimo 21) -eq 4) "21 -> $(Get-DecisionMinimo 21)"
Comp 'con 0 intentos no pide nada' ((Get-DecisionMinimo 0) -eq 0) ''

Write-Host '  -- y NADIE escribe el numero a mano (lo que se queria evitar) --'
# se miran solo las funciones que deciden: si vuelve a aparecer un 0.15 o un "-lt 20" ahi
# dentro, es que alguien ha duplicado el criterio y volvemos al problema de partida
foreach ($fn in @('Test-RevisionPropia', 'Get-AvisoSinDatos')) {
    $cuerpo = Traer $fn
    Comp "$fn no repite el 0.15" ($cuerpo -notmatch '\* 0\.15') ''
    Comp "$fn no repite el 20 a mano" ($cuerpo -notmatch '-lt 20\b|-ge 20\b') ''
    Comp "$fn usa las constantes" ($cuerpo -match 'DecisionMinIntentos|Get-DecisionMinimo') ''
}

Write-Host '  -- y las tres decisiones siguen pidiendo lo mismo --'
# que no se haya colado un criterio distinto sin querer: las tres usan el mismo minimo
$cuerpoR = Traer 'Test-RevisionPropia'
$cuantas = ([regex]::Matches($cuerpoR, 'Get-DecisionMinimo')).Count
Comp 'las tres decisiones usan el calculo compartido' ($cuantas -ge 3) "usos=$cuantas"
$cuantosMin = ([regex]::Matches($cuerpoR, 'DecisionMinIntentos')).Count
Comp 'y las tres el minimo de intentos' ($cuantosMin -ge 3) "usos=$cuantosMin"

# EL SI/NO: EL WORKER TIENE QUE ESCUCHAR MAS DE LO QUE EL ASISTENTE ESPERA (18/09). Eran 5 s
# de worker frente a 3,5 s + la voz del asistente, al reves de como debe ser, y nadie lo
# comparaba. braya: "a veces no puedo responder en preguntas de si o no". Los dos numeros se
# leen del fuente: si alguien toca uno y no el otro, esto se pone rojo.
Write-Host ''
Write-Host '  -- el si/no: los dos relojes, a la par --'
$txtW = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [System.Text.Encoding]::UTF8)
$esperaMs = if ($txt -match "Get-Cfg 'confirmacion' 'esperaMs' ([0-9]+)") { [int]$Matches[1] } else { -1 }
$workerSeg = if ($txtW -match 'CONFIRMACION_MAX = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
Comp 'el plazo del asistente se lee del fuente' ($esperaMs -gt 0) "esperaMs=$esperaMs"
Comp 'el del worker tambien' ($workerSeg -gt 0) "CONFIRMACION_MAX=$workerSeg"
Comp 'el worker escucha MAS de lo que el asistente espera' ($workerSeg * 1000 -gt $esperaMs) "worker=$($workerSeg)s asistente=$($esperaMs)ms"
Comp 'y con margen (al menos 1 s)' (($workerSeg * 1000 - $esperaMs) -ge 1000) ''
# y el plazo se REARMA cuando termina de hablar, no antes: la linea tiene que estar en el
# bloque de la confirmacion pendiente del bucle
$iConf = $txt.IndexOf('--- CONFIRMACION PENDIENTE (si / no / plazo) ---')
$trozoConf = if ($iConf -ge 0) { $txt.Substring($iConf, [Math]::Min(4500, $txt.Length - $iConf)) } else { '' }
Comp 'el plazo se rearma al pasar a confirmando' ($trozoConf -match '\$script:pendiente\.vence = \$sw\.ElapsedMilliseconds \+ \$ConfirmacionMs') ''
# Y LO QUE DE VERDAD PROTEGE (18/09, 20:15): el rearme de arriba paso la prueba y fallo en
# vivo, porque el plazo vencia ANTES de que la capsula pasara a 'confirmando' (la voz seguia
# sonando). Mientras hable, el vencimiento tiene que empujarse a "fin de la voz + plazo".
Comp 'mientras habla, el plazo NO corre (se empuja al fin de la voz)' ($trozoConf -match 'finVozC[\s\S]{0,300}\$script:pendiente\.vence = \$minimoC') ''
Comp 'y el empuje va ANTES de decidir el plazo' (($trozoConf.IndexOf('$minimoC')) -lt ($trozoConf.IndexOf("Complete-Confirmacion 'plazo'"))) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
