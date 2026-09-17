# CUANDO BRAYA DICE QUE ESTUVO MAL (17/09).
#
# El destino apuntado dice lo que Nova CREYO hacer, y eso no basta: "abrir Outlast"
# cuenta como acierto aunque el quisiera Outlast 2. Solo braya lo sabe, asi que cuando
# dice "no era eso" (o "eso estuvo mal") esa orden queda marcada como fallo. Es el unico
# dato de toda la medicion que no depende de que nadie interprete nada.
#
# ESTE ARCHIVO ES A PROPOSITO LO MAS TONTO POSIBLE: sin funciones de ayuda que lean
# variables del script, leyendo el .jsonl con ReadAllLines y comparando contenidos, no
# diferencias. Una version anterior con ayudantes (Lineas/PonId/Comp compartiendo estado)
# daba MAL con el codigo funcionando -comprobado cinco veces por separado-, y depurar la
# prueba costo mas que escribir la funcion. Si hay que elegir, que la prueba sea boba.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$DestinosUso = Invoke-Expression (($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left.Extent.Text -eq '$DestinosUso' }, $true)).Right.Extent.Text)

# todo el entorno, antes de inyectar nada
$sw = [System.Diagnostics.Stopwatch]::StartNew()
function Log($m) { }
$script:ultimoUsoId = ''
$script:ultimoUsoEn = 0
$base = Join-Path $env:TEMP ('fallo-uso-' + [guid]::NewGuid().ToString('N'))
$TmpDir = Join-Path $base 'tmp'
$LogDir = $base
$dirUso = Join-Path $base 'pruebas\audio\uso'
$null = New-Item -ItemType Directory -Path $TmpDir -Force
$null = New-Item -ItemType Directory -Path $dirUso -Force
Invoke-Expression (Traer 'Write-DestinoUso')
Invoke-Expression (Traer 'Write-FalloUso')

$mal = 0
$fDestinos = Join-Path $dirUso 'destinos.jsonl'
$fMarca = Join-Path $TmpDir 'dictado-id.txt'

Write-Host '  -- decir "no era eso" deja rastro --'
[System.IO.File]::WriteAllText($fMarca, '20260917-020000')
$d1 = Write-DestinoUso 'local' 'abre outlast'
$n1 = @([System.IO.File]::ReadAllLines($fDestinos)).Count
if ($d1 -and $n1 -eq 1) { Write-Host '  OK   la orden queda apuntada' } else { Write-Host "  MAL  la orden queda apuntada (devolvio=$d1 lineas=$n1)"; $mal++ }
if ($script:ultimoUsoId -eq '20260917-020000') { Write-Host '  OK   y su id queda recordado para poder corregirlo' } else { Write-Host "  MAL  el id no quedo recordado ('$($script:ultimoUsoId)')"; $mal++ }

$f1 = Write-FalloUso 'abre outlast 2'
$lin = @([System.IO.File]::ReadAllLines($fDestinos))
if ($f1 -and $lin.Count -eq 2) { Write-Host '  OK   decir que estuvo mal lo marca' } else { Write-Host "  MAL  decir que estuvo mal lo marca (devolvio=$f1 lineas=$($lin.Count))"; $mal++ }
if ($lin.Count -ge 2) {
    $j = $lin[1] | ConvertFrom-Json
    if ($j.id -eq '20260917-020000') { Write-Host '  OK   con el id de ESA orden, no de otra' } else { Write-Host "  MAL  id equivocado ($($j.id))"; $mal++ }
    if ($j.hizo -eq 'fallo-dicho-por-ti') { Write-Host '  OK   marcada como fallo dicho por ti' } else { Write-Host "  MAL  hizo=$($j.hizo)"; $mal++ }
    if ($j.detalle -eq 'abre outlast 2') { Write-Host '  OK   y guarda lo que querias de verdad' } else { Write-Host "  MAL  detalle=$($j.detalle)"; $mal++ }
}
$f2 = Write-FalloUso 'otra vez'
$n2 = @([System.IO.File]::ReadAllLines($fDestinos)).Count
if ((-not $f2) -and $n2 -eq 2) { Write-Host '  OK   pero no se marca dos veces la misma' } else { Write-Host "  MAL  se marco dos veces (devolvio=$f2 lineas=$n2)"; $mal++ }

Write-Host '  -- una queja tardia NO ensucia los datos --'
[System.IO.File]::WriteAllText($fMarca, '20260917-030000')
[void](Write-DestinoUso 'local' 'pon el volumen al 30')
$script:ultimoUsoEn = $sw.ElapsedMilliseconds - 400000   # como si hubieran pasado 6 minutos
$n3 = @([System.IO.File]::ReadAllLines($fDestinos)).Count
$f3 = Write-FalloUso 'muy tarde'
$n4 = @([System.IO.File]::ReadAllLines($fDestinos)).Count
if ((-not $f3) -and $n4 -eq $n3) { Write-Host '  OK   pasados 5 min ya no marca esa orden' } else { Write-Host "  MAL  marco una orden vieja (devolvio=$f3)"; $mal++ }
if (-not $script:ultimoUsoId) { Write-Host '  OK   y no deja el id colgando para la siguiente' } else { Write-Host "  MAL  quedo el id '$($script:ultimoUsoId)'"; $mal++ }

Write-Host '  -- y sin nada delante, ni se inmuta --'
$f4 = Write-FalloUso 'sin ninguna orden antes'
$n5 = @([System.IO.File]::ReadAllLines($fDestinos)).Count
if ((-not $f4) -and $n5 -eq $n4) { Write-Host '  OK   sin orden previa no apunta ni revienta' } else { Write-Host "  MAL  apunto sin orden previa (devolvio=$f4)"; $mal++ }

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
