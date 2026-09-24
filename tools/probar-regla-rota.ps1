# CUANDO EL MOTOR DE REGLAS REVIENTA, LA REGLA SE PERDIA EN SILENCIO (24/09, idea 14).
#
# LO QUE PASO, con hora. El 13/09 a las 16:22:01 braya dijo "cada 2 horas di que estire la
# espalda" -una regla perfectamente valida- y el motor de reglas reviento:
#
#     16:22:01  regla: No se puede llamar a un metodo en una expresion con valor NULL.
#     16:22:02  LOCAL descarta: no reconozco 'cada 2 horas di que estire la espalda' -> opencode
#     16:22:02  CHARLA descartada (charla, no llega al agente): 'cada 2 horas ...'
#     16:22:04  ORDEN ESCRITA: que reglas hay
#     16:22:04  LOCAL: que reglas hay -> No tienes reglas.
#
# Dos segundos despues pregunto que reglas habia y Nova le dijo que ninguna. El creia haberla
# creado. Paso tres veces: 11/09 01:13:25, 11/09 01:16:31 y 13/09 16:22:01.
#
# EL NULL DE ENTONCES YA NO ESTA: probado el 24/09 cargando las 528 funciones del archivo y
# pasandole las siete frases de regla que hay en el registro, incluida la que reviento.
# Ninguna lanza, y el error no vuelve a salir en el log desde el 13/09. Asi que este banco NO
# prueba el NULL: prueba que si algo revienta MANANA, no se pierda callando.
#
# Y LO QUE MAS SE VIGILA: que no se invente la regla. Fallar en entender se puede; crear algo
# a medias que braya no ha confirmado, no. Es la regla 1.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'ConvertTo-Plain')

# EL BLOQUE DE VERDAD, SACADO DEL ARCHIVO Y EJECUTADO. No se copia aqui: se extrae el trozo
# real de Invoke-FastCommand -del "$regla = $null" al "if ($regla) { return $regla }"- y se
# mete en una funcion. Asi el banco no puede quedarse verde con el codigo cambiado debajo.
$lineas = @($fuente -split "`r?`n")
$ini = -1; $fin = -1
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($ini -lt 0 -and $lineas[$i] -match '^\s*\$regla = \$null\s*$') { $ini = $i }
    elseif ($ini -ge 0 -and $lineas[$i] -match '^\s*if \(\$regla\) \{ return \$regla \}\s*$') { $fin = $i; break }
}
if ($ini -lt 0 -or $fin -lt 0) { Write-Host '  MAL  no encuentro el bloque de la regla en Invoke-FastCommand'; exit 1 }
$bloque = ($lineas[$ini..$fin] -join "`n")
Comp 'el bloque real se encuentra en el archivo' ($bloque.Length -gt 100) "$($fin - $ini + 1) lineas"

# El doble de Invoke-ReglaVoz: revienta o no segun lo que pida la prueba.
$script:reventar = $false
$script:devuelve = $null
$script:dicho = New-Object System.Collections.ArrayList
$script:contado = New-Object System.Collections.ArrayList
function Invoke-ReglaVoz([string]$text) {
    if ($script:reventar) { throw 'No se puede llamar a un metodo en una expresion con valor NULL.' }
    return $script:devuelve
}
function Log([string]$m) { [void]$script:dicho.Add($m) }
function Add-Estadistica($a, $b) { [void]$script:contado.Add("$a|$b") }
Invoke-Expression ("function Correr([string]`$text) {`n" + $bloque + "`n  return `$null`n}")

Write-Host ''
Write-Host '-- 1. EL CASO DEL 13/09, tal cual --'
$script:reventar = $true
$r = Correr 'cada 2 horas di que estire la espalda'
Comp 'la frase del 13/09 ya no se pierde callando' ([bool]$r) "$r"
Comp 'y dice que NO ha guardado nada' ($r -match 'no he guardado nada|No he guardado nada') 'o braya creera que la tiene'
Comp 'y le pide que lo repita' ($r -match 'otra vez|repite|repitemelo') 'la segunda via'
Comp 'el fallo sigue quedando en el registro' (@($script:dicho | Where-Object { $_ -match '^regla: ' }).Count -eq 1) "$($script:dicho.Count) linea(s)"
Comp 'y deja un contador para poder vigilarlo' (@($script:contado | Where-Object { $_ -match '^regla-rota\|' }).Count -eq 1) "$($script:contado -join ' ')"

Write-Host ''
Write-Host '-- 2. las SIETE formas de regla del registro, todas protegidas --'
# Son las que aparecen de verdad en assistant.log, mas las dos que Nova misma ofrece cuando
# le preguntas ("puedes decir: cuando abra un juego, pon modo juego").
$formas = @(
    'cada 2 horas di que estire la espalda',
    'cada dos horas di que estire la espalda',
    'cuando abra elden ring pon modo noche',
    'cuando la bateria baje del 20 por ciento bloquea',
    'cada 45 minutos pon modo noche',
    'todos los dias a las 22:30 pon modo noche',
    'todos los dias a las 09:00 pon el brillo al 60',
    'cuando abra un juego pon modo juego',
    'recuerdame cada hora que beba agua',
    'cada dia a las 8 pon el brillo al 60',
    'diariamente pon modo noche'
)
$script:reventar = $true
$protegidas = 0
foreach ($f in $formas) {
    $script:dicho.Clear(); $script:contado.Clear()
    $x = Correr $f
    if ($x) { $protegidas++ }
    Comp ("'$f'") ([bool]$x) $(if ($x) { 'avisa' } else { 'SE PIERDE' })
}
Comp 'las once formas quedan cubiertas' ($protegidas -eq $formas.Count) "$protegidas de $($formas.Count)"

Write-Host ''
Write-Host '-- 3. y lo que NO es una regla sigue su camino --'
# Si esto se cayera, cualquier frase que reventara por dentro se convertiria en "iba a guardar
# una regla", y Nova estaria contestando por algo que braya no pidio.
$script:reventar = $true
foreach ($f in @('que hora es', 'abre steam', 'sube el volumen', 'cuentame un chiste',
                 'cuanta bateria queda', 'pon musica', 'como me oyes')) {
    $script:dicho.Clear()
    $x = Correr $f
    Comp ("'$f' NO se trata como regla") (-not $x) $(if ($x) { "contesto: $x" } else { 'sigue su camino' })
}

Write-Host ''
Write-Host '-- 4. y sin reventar, todo igual que siempre --'
$script:reventar = $false
$script:devuelve = 'Hecho, regla 1 guardada.'
$r2 = Correr 'cuando abra elden ring pon modo noche'
Comp 'una regla buena se guarda como siempre' ($r2 -eq 'Hecho, regla 1 guardada.') "$r2"
$script:devuelve = $null
$r3 = Correr 'cuando abra elden ring pon modo noche'
Comp 'y si no era una regla, no se inventa nada' ($null -eq $r3) 'sigue su camino'
$script:dicho.Clear()
Comp 'y sin fallo no escribe nada en el registro' ($script:dicho.Count -eq 0) ''

Write-Host ''
Write-Host '-- 5. LO QUE NO HACE: inventarse la regla --'
$sinCom = (($bloque -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'no guarda nada por su cuenta' (($sinCom -notmatch 'Save-Reglas') -and ($sinCom -notmatch 'Add-Regla')) 'la regla 1'
Comp 'ni reintenta a ciegas' ($sinCom -notmatch 'Invoke-ReglaVoz[\s\S]*Invoke-ReglaVoz') 'una vez y ya'
Comp 'ni deja un modo abierto' ($sinCom -notmatch '\$script:pendiente =') 'la regla 2'
# La condicion tiene que ser LA MISMA que la guarda de voz extrana de doce lineas mas arriba:
# si las dos se separan, habra frases que una considera regla y la otra no.
$vozExtrana = [regex]::Match($fuente, "confirmado -and \(ConvertTo-Plain \`$text\) -match '([^']+)'")
$laNuestra = [regex]::Match($sinCom, "\`$eraRegla = \[bool\]\(\(ConvertTo-Plain \`$text\) -match '([^']+)'")
Comp 'la guarda de voz extrana sigue ahi' ($vozExtrana.Success) ''
Comp 'y esta usa la MISMA forma de frase' ($vozExtrana.Success -and $laNuestra.Success -and
    ($vozExtrana.Groups[1].Value -replace '\|a las\?\\s', '') -eq ($laNuestra.Groups[1].Value -replace '\|a las\?\\s', '')) 'dos listas que dicen lo mismo acaban separandose'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  una regla que revienta ya no se pierde callando'
exit 0
