# EL CUADERNO DE LA ALLY SE QUEDABA A MEDIAS EN CADA APAGADA (26/09, idea 52 de las 121).
#
# Save-UsoAlly solo bajaba al disco cuando se juntaban 300 s pendientes; nadie lo volcaba al
# cerrar ni por reloj. Medido: 35 de las 71 sesiones terminadas desde el 18/09 (49 %) murieron
# sin cierre limpio, y 10 no llegaron ni a 300 s de vida, o sea que perdieron entera su cuenta.
# Ahora dos vias nuevas (regla 7): el manejador de salida vuelca al cerrar, y el bucle de 10 s
# vuelca cada $UsoAllyVolcadoSeg segundos aunque no se junten los 300. Save-UsoAlly/Save-TiempoJuego
# ya salen sin escribir si no hay nada pendiente, asi que no estrena coste.
#
# TODO SE EJECUTA: el scriptblock del Exiting y el bloque del bucle se sacan del fuente y se corren
# en un arnes con ficheros de mentira. Comprobar con $src -match 'Save-UsoAlly' saldria verde con
# la llamada en un comentario (manera 2 y 17 de salir verde mintiendo).
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$det = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $det)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function TraerVar([string]$n) {
    $m = [regex]::Match($fuente, '(?m)^\$' + $n + '\s*=\s*(.+?)\s*$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro la variable $n"; exit 1 }
    return $m.Groups[1].Value
}

# --- el mundo de mentira ---
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('usoally-vol-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmp)
$MemoriaDir = $tmp
$UsoAllyPath = Join-Path $MemoriaDir 'uso-ally.json'
function Log([string]$m) { }
function Save-Corrupto([string]$a, [string]$b) { }
$script:cuentaEst = 0
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { $script:cuentaEst++ }
$script:invitado = $false
$script:usoAllyPend = @{}
$script:usoAlly = $null
$script:tiempoJuegoPend = @{}
$script:juegosMem = $null
$script:arranqueContado = $true
# UsoAllyMax lo usa Save-UsoAlly en su poda por dia: sin el, $null hace de tope y Save-UsoAlly tira
# una excepcion que el manejador se traga, y el cuaderno sale sin escribir (paso al escribir esto).
foreach ($v in @('UsoAllyOcioMin', 'UsoAllyMax', 'UsoAllyDias', 'UsoAllyVolcadoSeg')) { Invoke-Expression ('$' + $v + ' = ' + (TraerVar $v)) }
foreach ($f in @('Get-UsoAlly', 'Add-UsoAlly', 'Save-UsoAlly', 'Get-DiaJuego',
        'Get-JuegosMem', 'Save-JuegosMem', 'Get-DiasJuego', 'Save-TiempoJuego', 'Get-TiempoJugado')) { Invoke-Expression (Traer $f) }

# el scriptblock del manejador de salida, sacado por AST y ejecutable
$sbAst = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and $x.Extent.Text -match 'VoiceAssistant cerrado PID=' }, $true)
if (-not $sbAst) { Write-Host '  MAL  no encuentro el manejador de salida'; exit 1 }
$txtSB = $sbAst.Extent.Text
$manejador = [scriptblock]::Create($txtSB.Substring(1, $txtSB.Length - 2))

$juegosPath = Join-Path $MemoriaDir 'juegos.json'
$dia = Get-DiaJuego (Get-Date)
# resets: los Get-* cachean en $script:usoAlly / $script:juegosMem, asi que sin vaciar el cache el
# banco leeria datos viejos y una rotura del volcado saldria verde (paso: cache-bleed). Se vacia el
# cache Y se borra el fichero antes de cada caso, asi Get-UsoAlly lee del DISCO y prueba que se escribio.
function FreshUso { $script:usoAlly = $null; Remove-Item -LiteralPath $UsoAllyPath -Force -ErrorAction SilentlyContinue }
function FreshJuegos { $script:juegosMem = $null; Remove-Item -LiteralPath $juegosPath -Force -ErrorAction SilentlyContinue }

try {
Write-Host ''
Write-Host '-- 1 y 2: al cerrar, lo pendiente cae al disco --'
FreshUso; FreshJuegos
$script:usoAllyPend = @{ 'ELDEN RING|con' = 60 }        # 60 < 300: no vuelca solo
$script:tiempoJuegoPend = @{ 'ELDEN RING' = 120 }
& $manejador
$script:usoAlly = $null                                 # forzar releer del DISCO: prueba que el fichero se escribio
$u = Get-UsoAlly
Comp '1. el cuaderno de la Ally se vuelca al salir (con=60)' ($u.ContainsKey($dia) -and [int]$u[$dia]['ELDEN RING']['con'] -eq 60) "con=$($u[$dia]['ELDEN RING']['con'])"
# NO se lee con Get-TiempoJugado: esa vuelca ella sola (Save-TiempoJuego en su 1a linea) y taparia
# el fallo. Se mira que el manejador vacio lo pendiente y escribio juegos.json.
Comp '2. y el tiempo de juego tambien (pending vaciado, juegos.json escrito)' (($script:tiempoJuegoPend.Count -eq 0) -and (Test-Path -LiteralPath $juegosPath)) "pend=$($script:tiempoJuegoPend.Count)"

Write-Host ''
Write-Host '-- 3. y NO escribe si no hay nada pendiente --'
FreshUso
$script:usoAllyPend = @{}
$script:tiempoJuegoPend = @{}
& $manejador
Comp '3. con nada pendiente, no reescribe el cuaderno' (-not (Test-Path -LiteralPath $UsoAllyPath)) 'la guarda de Save-UsoAlly protege el disco'

Write-Host ''
Write-Host '-- 4. el reloj vuelca aunque no se junten 300 s --'
$iniR = $fuente.IndexOf('# Y UN VOLCADO POR RELOJ')
$finR = if ($iniR -ge 0) { $fuente.IndexOf('# EL CANDIDATO A JUEGO DESCONOCIDO', $iniR) } else { -1 }
if ($iniR -lt 0 -or $finR -lt 0) { Write-Host '  MAL  no encuentro el bloque del reloj'; exit 1 }
$reloj = [scriptblock]::Create($fuente.Substring($iniR, $finR - $iniR))
# a 91 s (> 90) vuelca; a 89 s no
FreshUso
$script:usoAllyPend = @{ 'ELDEN RING|con' = 60 }; $script:usoAllyVolcado = 0
$sw = [pscustomobject]@{ ElapsedMilliseconds = 91000 }
& $reloj
$script:usoAlly = $null
Comp '4. con 60 s pendientes y el reloj pasado (91 s), vuelca' ((Get-UsoAlly).ContainsKey($dia)) ''
FreshUso
$script:usoAllyPend = @{ 'ELDEN RING|con' = 60 }; $script:usoAllyVolcado = 0
$sw = [pscustomobject]@{ ElapsedMilliseconds = 89000 }
& $reloj
Comp '   y a 89 s (por debajo de 90) todavia no' (-not (Test-Path -LiteralPath $UsoAllyPath)) 'un cambio de signo en la comparacion sale rojo aqui'

Write-Host ''
Write-Host '-- 5. el plazo no baja del suelo ni sube de 300 --'
Comp "5. UsoAllyVolcadoSeg del archivo ($UsoAllyVolcadoSeg s) esta entre 60 y 300" ($UsoAllyVolcadoSeg -ge 60 -and $UsoAllyVolcadoSeg -le 300) ''

Write-Host ''
Write-Host '-- 6. lo llama el bucle de los 10 s, no Watch-Entorno --'
$iCuaderno = $fuente.IndexOf('# EL CUADERNO DE LA ALLY, en la misma mirada')
Comp '6. el volcado por reloj cae dentro del tic de los 10 s' ($iCuaderno -ge 0 -and $iniR -gt $iCuaderno) ''
$we = Traer 'Watch-Entorno'
Comp '   y NO dentro de Watch-Entorno, donde $EntornoOn lo apagaria' ($we -notmatch 'usoAllyVolcado') ''

} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'el cuaderno de la Ally se vuelca al salir y por reloj' -ForegroundColor Green
exit 0
