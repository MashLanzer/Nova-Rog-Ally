# QUE HIZO NOVA CON LO QUE OYO (17/09).
#
# El worker ya guardaba lo que OYO cada modelo, pero no a donde iba a parar la frase.
# Sin eso, la meta de braya -"cero ordenes equivocadas"- no se podia medir: sabiamos si
# te habia oido, no si habia acertado. Esto comprueba la pieza que lo apunta.
#
# Lo que de verdad importa aqui es que el id se CONSUMA: si una frase deja su id puesto,
# el siguiente apunte se lo colgaria a ella y las cuentas saldrian mal, que es peor que
# no medir nada.
#
# Y desde el 19/09, lo contrario tambien: hay apuntes que son una PARADA en el camino
# ($deCamino) y no pueden comerse el id, porque el desenlace llega despues. Comerselo
# costo tres ordenes bien hechas contadas como fallo el 18/09.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
# la MISMA lista del archivo real: una copia a mano se queda vieja
$DestinosUso = Invoke-Expression (($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left.Extent.Text -eq '$DestinosUso' }, $true)).Right.Extent.Text)
$DestinosNeutros = Invoke-Expression (($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left.Extent.Text -eq '$DestinosNeutros' }, $true)).Right.Extent.Text)
$DestinosFallo = Invoke-Expression (($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left.Extent.Text -eq '$DestinosFallo' }, $true)).Right.Extent.Text)
Invoke-Expression (Traer 'Write-DestinoUso')
# la llama Write-DestinoUso: sin traerla aqui el banco revienta con CommandNotFoundException
Invoke-Expression (Traer 'Write-FalloDeducido')
$script:ultimoDeducidoId = ''

# un sitio de mentira, con la forma que tiene el de verdad
$base = Join-Path $env:TEMP ('destino-uso-' + [guid]::NewGuid().ToString('N'))
$TmpDir = Join-Path $base 'tmp'
$LogDir = $base
$dirUso = Join-Path $base 'pruebas\audio\uso'
$null = New-Item -ItemType Directory -Path $TmpDir -Force
$null = New-Item -ItemType Directory -Path $dirUso -Force
$destinos = Join-Path $dirUso 'destinos.jsonl'
$marca = Join-Path $TmpDir 'dictado-id.txt'

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# la coma no es un adorno: sin ella PowerShell DESENROLLA el array de una sola linea y
# devuelve la cadena suelta, con lo que (Lineas)[0] daba '{' -el primer caracter- en vez
# de la linea entera. Es la misma trampa que ya obligo a escribir "return ,$script:reglas"
# en Get-Reglas, y me la he vuelto a comer hoy.
function Lineas {
    if (-not (Test-Path -LiteralPath $destinos)) { return ,@() }
    # OJO: "$res = if (...) { @(...) }" NO vale. El resultado del if sale por la tuberia
    # y, con una sola linea, llega desenrollado: $res acaba siendo la CADENA, y entonces
    # (Lineas)[0] devuelve '{' (su primer caracter) en vez de la linea entera. Hay que
    # asignar el @() directamente, y devolverlo con coma para que no se desenrolle otra vez.
    $res = @(Get-Content -LiteralPath $destinos | Where-Object { $_.Trim() })
    return ,$res
}
function PonId([string]$v) { [System.IO.File]::WriteAllText($marca, $v) }

Write-Host '  -- se apunta lo que hizo --'
PonId '20260917-010203'
$r = Write-DestinoUso 'local' 'abre steam'
Comp 'una orden local se apunta' ($r -and (Lineas).Count -eq 1) ("lineas: " + (Lineas).Count)
# SIN @(): "@(Lineas)[0]" no da la primera LINEA, da el array entero, porque Lineas devuelve
# ",$res" y el @() lo envuelve otra vez (medido: Count=1 y su elemento 0 es otro Object[]).
# Aqui acertaba de milagro, porque en este punto solo hay una linea.
$j = (Lineas)[0] | ConvertFrom-Json
Comp 'con el id de esa orden' ($j.id -eq '20260917-010203') "id=$($j.id)"
Comp 'y con lo que hizo' ($j.hizo -eq 'local' -and $j.detalle -eq 'abre steam') "hizo=$($j.hizo) detalle=$($j.detalle)"

Write-Host '  -- el id se consume (lo que mas duele si falla) --'
Comp 'la marca desaparece tras apuntar' (-not (Test-Path -LiteralPath $marca)) ''
$r2 = Write-DestinoUso 'local' 'otra cosa'
Comp 'un segundo apunte YA no cuelga de esa orden' ((-not $r2) -and (Lineas).Count -eq 1) ("lineas: " + (Lineas).Count)

Write-Host '  -- lo que es OIDO no es DESTINO --'
PonId '20260917-010500'
$r3 = Write-DestinoUso 'fino' 'lo repaso el oido fino'
Comp "'fino' no se apunta como destino" ((-not $r3) -and (Lineas).Count -eq 1) ("lineas: " + (Lineas).Count)
Comp 'y NO se come el id de la frase' (Test-Path -LiteralPath $marca) ''
$r4 = Write-DestinoUso 'error' 'no supe hacerlo'
Comp 'el destino de verdad si lo usa' ($r4 -and (Lineas).Count -eq 2) ("lineas: " + (Lineas).Count)

Write-Host '  -- la charla y el agente dejan huella, sin comerse el id (18/09) --'
# Mas de la mitad del uso real es charla, traduccion o agente, y no dejaba rastro: un "no era
# eso" dicho tras una charla marcaba la ultima orden LOCAL, de hasta 300 s antes.
PonId '20260918-020000'
$nAnt = (Lineas).Count
$rN = Write-DestinoUso 'charla' 'que es un volcan'
Comp 'una charla se apunta' ($rN -and (Lineas).Count -eq ($nAnt + 1)) ("lineas: " + (Lineas).Count)
Comp 'pero NO se come el id de la frase' (Test-Path -LiteralPath $marca) ''
Comp 'y queda recordada por si dices que estuvo mal' ($script:ultimoUsoId -eq '20260918-020000') "id=$($script:ultimoUsoId)"
# y esto es lo que protege la medicion: el destino de verdad llega despues y SI lo consume
$nAnt2 = (Lineas).Count
$rR = Write-DestinoUso 'traducida' 'abre steam'
Comp 'el destino de verdad se apunta con el mismo id' ($rR -and (Lineas).Count -eq ($nAnt2 + 1)) ''
# OJO: "@(Lineas)[-1] | ConvertFrom-Json" NO da la ultima linea; le llegan todas y devuelve
# un objeto por cada una, con lo que $jN.hizo es un ARRAY y cualquier -eq contra el filtra en
# vez de comparar: el caso sale verde diga lo que diga. Se indexa sobre una variable.
$todasN = (Lineas)
$jN = $todasN[$todasN.Count - 1] | ConvertFrom-Json
Comp 'y es el que manda al contar' ($jN.hizo -eq 'traducida' -and $jN.id -eq '20260918-020000') "hizo=$($jN.hizo)"
Comp 'ahora si se consume el id' (-not (Test-Path -LiteralPath $marca)) ''

Write-Host '  -- el descarte local es una PARADA, no un desenlace (19/09) --'
# En el log del 18/09, 'revisar mi agenda para manana' se apunto como 'descarte' y acabo
# ejecutando la RECETA 6. Como el descarte se comia el id, la receta no pudo apuntar su
# linea: una orden que SALIO BIEN quedo contada como fallo, y con ella otras dos. Eso es lo
# que hacia inservible elegir "las 3 peores del dia" por el destino.
PonId '20260918-191439'
$nD = (Lineas).Count
$rD = Write-DestinoUso 'descarte' 'revisar mi agenda para manana' $true
Comp 'la parada se apunta igual' ($rD -and (Lineas).Count -eq ($nD + 1)) ("lineas: " + (Lineas).Count)
Comp 'pero NO se come el id' (Test-Path -LiteralPath $marca) ''
$rD2 = Write-DestinoUso 'receta' 'revisa mi calendario'
Comp 'y el desenlace de verdad escribe detras' ($rD2 -and (Lineas).Count -eq ($nD + 2)) ("lineas: " + (Lineas).Count)
# se indexa sobre una variable, no sobre (Lineas)[-1]: ver la nota de mas arriba
$todasD = (Lineas)
$jD = $todasD[$todasD.Count - 1] | ConvertFrom-Json
Comp 'la ultima es la que manda al contar' ($jD.hizo -eq 'receta' -and $jD.id -eq '20260918-191439') "hizo=$($jD.hizo)"
Comp 'y ESE si consume el id' (-not (Test-Path -LiteralPath $marca)) ''
# LO QUE NO PUEDE CAMBIAR: una parada a la que no le llega nada detras sigue siendo un
# fallo. 'cierra en la ring' (18/09 18:47) se tradujo a 'abre ELDEN RING en steam' y la
# confirmacion vencio sin respuesta: nadie hizo nada, y eso cuenta.
PonId '20260918-184632'
$nD3 = (Lineas).Count
[void](Write-DestinoUso 'descarte' 'cierra en la ring' $true)
$todasD3 = (Lineas)
$jD3 = $todasD3[$todasD3.Count - 1] | ConvertFrom-Json
Comp 'sola, la parada sigue contando como descarte' ($jD3.hizo -eq 'descarte' -and (Lineas).Count -eq ($nD3 + 1)) "hizo=$($jD3.hizo)"
# la parada deja el id vivo a proposito: se limpia para que el caso de abajo empiece sin marca
Remove-Item -LiteralPath $marca -Force -ErrorAction SilentlyContinue

Write-Host '  -- y no molesta cuando no toca --'
# la referencia se toma AQUI y no se escribe a mano: cualquier caso que se añada mas arriba
# deja mas lineas en el fichero, y un numero fijo se pondria rojo sin que nada este roto
$nBase = (Lineas).Count
$r5 = Write-DestinoUso 'local' 'sin ninguna orden delante'
Comp 'sin id no apunta nada' ((-not $r5) -and (Lineas).Count -eq $nBase) ''
PonId ''
$r6 = Write-DestinoUso 'local' 'id vacio'
Comp 'con el id vacio tampoco' ((-not $r6) -and (Lineas).Count -eq $nBase) ''
PonId '20260917-011000'
Remove-Item -LiteralPath $dirUso -Recurse -Force
$r7 = Write-DestinoUso 'local' 'sin grabaciones'
Comp 'si no se graba el uso, no inventa carpetas' ((-not $r7) -and -not (Test-Path -LiteralPath $destinos)) ''

Write-Host '  -- el .jsonl se puede leer de verdad --'
$null = New-Item -ItemType Directory -Path $dirUso -Force
PonId '20260917-012000'
[void](Write-DestinoUso 'receta' 'pon el modo juego')
$bytes = [System.IO.File]::ReadAllBytes($destinos)
$bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Comp 'sin BOM (o Python no lee la primera linea)' (-not $bom) ''

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "$fallos casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
