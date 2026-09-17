# QUE HIZO NOVA CON LO QUE OYO (17/09).
#
# El worker ya guardaba lo que OYO cada modelo, pero no a donde iba a parar la frase.
# Sin eso, la meta de braya -"cero ordenes equivocadas"- no se podia medir: sabiamos si
# te habia oido, no si habia acertado. Esto comprueba la pieza que lo apunta.
#
# Lo que de verdad importa aqui es que el id se CONSUMA: si una frase deja su id puesto,
# el siguiente apunte se lo colgaria a ella y las cuentas saldrian mal, que es peor que
# no medir nada.
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
Invoke-Expression (Traer 'Write-DestinoUso')

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
$j = @(Lineas)[0] | ConvertFrom-Json
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

Write-Host '  -- y no molesta cuando no toca --'
$r5 = Write-DestinoUso 'local' 'sin ninguna orden delante'
Comp 'sin id no apunta nada' ((-not $r5) -and (Lineas).Count -eq 2) ''
PonId ''
$r6 = Write-DestinoUso 'local' 'id vacio'
Comp 'con el id vacio tampoco' ((-not $r6) -and (Lineas).Count -eq 2) ''
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
