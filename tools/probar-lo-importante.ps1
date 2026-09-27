# LEER EL FICHERO DONDE APUNTA LAS VECES QUE LA CORRIGES (27/09, idea 117 de las 121)
#
# EL AGUJERO: memoria\cerebro\importante.jsonl lo escribe el worker en modo 'a' y su propio
# comentario dice que "NO se poda nunca". No lo leia nadie. La idea 79 ya lee los AGUJEROS -que el
# worker agrupa en agujeros.json-, pero el fichero de donde salen seguia muerto en el disco.
#
# Y AL ABRIRLO, LA SORPRESA: cinco lineas, las cinco con por='correccion', y ninguna es una
# correccion. Son frases que el oido entendio mal en mitad de una charla:
#     "No hay nada mas, eh? Mira yo"
#     "No, yo subi, pero ten cuidado cuando suba, Es tipo ese de arriba, Es que.., Es que nunca atras"
#     "No, porque se destilada la camera con anadir con la contable"
#     "No lo es, Es mas enterada, Es de aca, Encerno? Hasta que es cheap media"
#     "No, no, no, no, no, no, no"
# Entran porque empiezan por "no" y tienen cinco palabras o mas. Por eso agujeros.json no existia
# todavia: todo se etiquetaba de correccion y nada llegaba a ser un agujero.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el motivo nuevo 'no-entendi' separe los tres casos, y con las cinco lineas DE VERDAD
#   2. que una correccion explicita siga siendo una correccion aunque Nova no la entendiera del todo
#   3. que "no, no, no, no, no" no cuente como correccion: sin dos palabras distintas no hay frase
#   4. que un agujero -"no lo se", "no tengo acceso"- siga siendo un agujero
#   5. que una linea rota no se lleve el fichero por delante
#   6. y que las correcciones NO vayan al prompt de la charla: con cinco de cinco siendo ruido, eso
#      es justo el riesgo que la ficha nombra
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$PY = Join-Path $Raiz 'charla_worker.py'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$py = [IO.File]::ReadAllText($PY)
$pySin = (($py -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# EL CUERPO DE UNA FUNCION DE PYTHON, POR SU SANGRADO (27/09, idea 2): de su 'def' hasta el
# siguiente 'def' o 'class' que empiece en la columna cero. El 7i de abajo miraba "a menos de 300
# caracteres del nombre del fichero", y eso se pone rojo solo el dia que se escribe una linea por
# medio -o deja pasar la poda si la escriben 320 caracteres mas abajo-.
function CuerpoPy([string]$texto, [string]$nombre) {
    $i = $texto.IndexOf("def $nombre(")
    if ($i -lt 0) { return '' }
    $m = [regex]::Match($texto.Substring($i + 4), "(?m)^(def |class )")
    if ($m.Success) { return $texto.Substring($i, $m.Index + 4) }
    return $texto.Substring($i)
}

# LAS PIEZAS DE VERDAD DEL LADO DE POWERSHELL
$quiero = @('Get-Importante', 'Get-ImportanteResumen', 'Get-ParrafoImportante')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 3 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)

# EL MUNDO DE MENTIRA (despues de cargar)
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
$TmpBanco = Join-Path ([IO.Path]::GetTempPath()) ('nova-imp-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpBanco -Force | Out-Null
$MemoriaDir = $TmpBanco
New-Item -ItemType Directory -Path (Join-Path $TmpBanco 'cerebro') -Force | Out-Null
$ImportanteJsonl = Join-Path $TmpBanco 'cerebro\importante.jsonl'
$enc = New-Object Text.UTF8Encoding($false)

# EL MOTOR DEL WORKER SE PRUEBA EN SU PROPIO BANCO, tools\probar-lo-importante.py, y alli se
# EJECUTA la funcion de verdad sacada del fichero. Aqui habia una copia de por_que_importa escrita a
# mano -los patrones si salian del .py, pero el ORDEN de los cuatro 'if' estaba reescrito-, asi que
# mover un 'if' en el worker no ponia rojo nada: doblar la pieza que se prueba es la manera 15 de
# salir verde mintiendo. Este banco se queda con lo suyo, que es el lector de PowerShell.
Write-Host ''
Write-Host '-- 1. EL MOTOR DEL WORKER TIENE SU PROPIO BANCO --'
$bancoPy = Join-Path $PSScriptRoot 'probar-lo-importante.py'
Comp '1a. y existe' (Test-Path -LiteralPath $bancoPy) 'tools\probar-lo-importante.py'
Comp '1b. y ejecuta la funcion, no una copia' (((Get-Content -LiteralPath $bancoPy -Raw) -match 'exec\(cuerpo, ns\)') -and ((Get-Content -LiteralPath $bancoPy -Raw) -match 'por_que_importa = ns')) ''
Comp '1c. el motivo nuevo esta en el worker' ($pySin -match 'RE_NO_ENTENDI') ''

Write-Host ''
Write-Host '-- 4. EL LECTOR: LEE, CUENTA Y RESPETA EL PLAZO --'
$hoy = Get-Date '2026-09-27'
$lineas = @(
    '{"d":"2026-09-25","h":"21:49","por":"no-entendi","braya":"a","nova":"b"}'
    '{"d":"2026-09-26","h":"16:53","por":"no-entendi","braya":"c","nova":"d"}'
    '{"d":"2026-09-26","h":"17:00","por":"correccion","braya":"e","nova":"f"}'
    '{"d":"2026-09-27","h":"09:00","por":"agujero","braya":"g","nova":"h"}'
    '{"d":"2026-08-01","h":"09:00","por":"correccion","braya":"viejo","nova":"i"}'
)
[IO.File]::WriteAllText($ImportanteJsonl, (($lineas -join "`r`n") + "`r`n"), $enc)
$l7 = Get-Importante 7 $hoy
Comp '4a. lee las de la semana' (@($l7).Count -eq 4) ([string]@($l7).Count + ' de 5, la de agosto fuera')
$rs = Get-ImportanteResumen $l7
Comp '4b. y las cuenta por motivo' (([int]$rs.noEntendi -eq 2) -and ([int]$rs.correccion -eq 1) -and ([int]$rs.agujero -eq 1)) ('no-entendi ' + $rs.noEntendi + ', correccion ' + $rs.correccion + ', agujero ' + $rs.agujero)
Comp '4c. con su total' ([int]$rs.total -eq 4) ([string]$rs.total)
Comp '4d. y la fecha de la ultima' ([string]$rs.ultima -eq '2026-09-27') ([string]$rs.ultima)
$l60 = Get-Importante 60 $hoy
Comp '4e. con mas plazo entran mas' (@($l60).Count -eq 5) ([string]@($l60).Count)

Write-Host ''
Write-Host '-- 5. UNA LINEA ROTA NO SE LLEVA EL FICHERO --'
[IO.File]::WriteAllText($ImportanteJsonl, (@(
    $lineas[0]
    '{"d":"2026-09-26","h":"1'
    'esto no es json ni de lejos'
    ''
    $lineas[1]
) -join "`r`n") + "`r`n", $enc)
$lr = Get-Importante 7 $hoy
Comp '5a. se queda con las buenas' (@($lr).Count -eq 2) ([string]@($lr).Count + ' de 2 buenas entre tres basuras')
Comp '5b. y no se queja por el altavoz' ($script:logs.Count -eq 0) 'una linea rota no es una averia que contar'
# sin fichero, nada
Remove-Item -LiteralPath $ImportanteJsonl -Force
# SIN @(): Get-Importante devuelve con 'return ,@(...)', asi que un @() aqui da un array de UNO
# con la lista vacia dentro y .Count vale 1. Es el mismo fallo de Get-ProcesosNova, tercera vez.
$vacia = Get-Importante 7 $hoy
Comp '5c. sin fichero, lista vacia' ([int]$vacia.Count -eq 0) ([string]$vacia.Count)
Comp '5d. y el resumen no peta' ([int](Get-ImportanteResumen (Get-Importante 7 $hoy)).total -eq 0) ''

Write-Host ''
Write-Host '-- 6. LA FRASE DEL PARTE SEMANAL --'
[IO.File]::WriteAllText($ImportanteJsonl, (($lineas -join "`r`n") + "`r`n"), $enc)
$fr = Get-ParrafoImportante
Comp '6a. dice los ratos que no entendio' ($fr -match '2 ratos') ([string]$fr)
Comp '6b. y las veces que la corrigieron' ($fr -match 'corregiste 1 vez') ''
Comp '6c. lo del oido va primero' ($fr.IndexOf('no te entendi') -lt $fr.IndexOf('corregiste')) 'es lo que nadie media'
# sin nada, no dice nada
[IO.File]::WriteAllText($ImportanteJsonl, '', $enc)
Comp '6d. sin nada, no dice nada' ((Get-ParrafoImportante) -eq '') 'un parte que dice "no paso nada" cansa'
# Y LO QUE DE VERDAD PROTEGE ESE 'return': que con lineas de SOLO agujero tampoco diga nada. De los
# agujeros ya habla Get-ParrafoAgujeros, con su prueba en seco y todo; decirlos otra vez aqui seria
# la misma noticia dos veces en el mismo parte.
[IO.File]::WriteAllText($ImportanteJsonl, ('{"d":"' + (Get-Date).ToString('yyyy-MM-dd') + '","h":"10:00","por":"agujero","braya":"a","nova":"no lo se"}' + "`r`n"), $enc)
Comp '6f. con solo agujeros, se calla' ((Get-ParrafoImportante) -eq '') 'de esos ya habla el parrafo de los agujeros'
# y en singular
[IO.File]::WriteAllText($ImportanteJsonl, '{"d":"' + (Get-Date).ToString('yyyy-MM-dd') + '","h":"10:00","por":"no-entendi","braya":"a","nova":"b"}' + "`r`n", $enc)
$f1 = Get-ParrafoImportante
Comp '6e. con uno, lo dice en singular' ($f1 -match '1 rato\b') ([string]$f1)

Remove-Item -LiteralPath $TmpBanco -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '-- 7. EL CABLEADO, Y LO QUE NO SE HACE --'
Comp '7a. el motivo nuevo existe en el worker' ($pySin -match 'RE_NO_ENTENDI') ''
Comp '7b. y se mira ANTES que la negacion larga' ($pySin.IndexOf('RE_NO_ENTENDI.search(respuesta)') -lt $pySin.IndexOf('RE_NEGACION.match(texto)')) 'era la que se comia las cinco'
Comp '7c. pero DESPUES de la correccion explicita' ($pySin.IndexOf('RE_CORRIGE.search(texto)') -lt $pySin.IndexOf('RE_NO_ENTENDI.search(respuesta)')) 'esa dice QUE estaba mal'
Comp '7d. el turno se sigue guardando igual' ($pySin -match 'apuntar_importante\(texto, respuesta, por_que_importa') 'el fichero no pierde ni una linea'
Comp '7e. el parrafo va al parte semanal' ($sinCom -match '(?s)Get-ParrafoAgujeros.{0,400}Get-ParrafoImportante') 'al lado del de los agujeros'
Comp '7f. y el de los agujeros sigue en pie' ($sinCom -match 'function Get-ParrafoAgujeros') 'aquel lee los agrupados y este el bruto'
# LO QUE NO SE HACE: las correcciones NO van al prompt de la charla
Comp '7g. las correcciones NO van al prompt' (-not ($pySin -match "(?i)(ya te lo corrigio|esto ya te lo|importante.jsonl[^\r\n]{0,60}prompt)")) 'cinco de cinco eran ruido: primero que haya correcciones'
# LO QUE DE VERDAD IMPORTA ES EL MODO DE APERTURA: 'a' anade y 'w' machaca. (Buscar la palabra
# 'poda' aqui la encontraba en el propio docstring de la funcion, que dice que NO se poda nunca.)
Comp '7h. el fichero se abre para ANADIR, no para machacar' ($pySin -match '"importante\.jsonl"\), "a"') 'con "w" se perderia todo en cada turno'
# "POR NINGUN LADO" SE COMPRUEBA EN DOS MITADES: que la funcion que lo escribe no lo poda, y que
# el nombre del fichero no aparece en codigo fuera de ella (si apareciera, habria otro que lo toca
# y esta comprobacion se habria quedado corta sin avisar).
$cuerpoImp = CuerpoPy $pySin 'apuntar_importante'
$impFuera = @(($pySin -split "`n") | Where-Object { $_ -match 'importante\.jsonl' -and $cuerpoImp.IndexOf($_) -lt 0 })
Comp '7i. y no se le corta la cola por ningun lado' (($cuerpoImp -ne '') -and -not ($cuerpoImp -match '\[-\d+:\]') -and ($impFuera.Count -eq 0)) ('su comentario dice que NO se poda nunca' + $(if ($impFuera.Count) { '; lo tocan fuera: ' + ($impFuera -join ' / ') }))
$cuerpoR = @($defs | Where-Object { $_.Name -eq 'Get-ImportanteResumen' })[0].Extent.Text
Comp '7j. Get-ImportanteResumen es pura' (-not ($cuerpoR -match '(Get-Date|Test-Path|Get-Content|Log |\$sw\.)')) 'por eso se le pueden pasar las cinco de verdad'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el inventario de sus fallos ya lo lee alguien, y dice la verdad' -ForegroundColor Green
exit 0
