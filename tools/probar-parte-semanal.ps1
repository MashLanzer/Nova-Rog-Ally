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
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
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

# --- Y QUE ALGUIEN LA LEA (25/09, idea 37) ---
# EL FALLO QUE SE ARREGLA AQUI: la nota se escribia desde el 14/09 y su unica huella fuera del
# disco era un Log. Dos ficheros escritos, cero leidos. Todo lo de arriba seguia verde con la
# nota siendo una carta que Nova se mandaba a si misma.
Write-Host ''
Write-Host '  -- y alguien la lee (idea 37) --'
Invoke-Expression (Traer 'Get-DomingoDeSemana')
Invoke-Expression (Traer 'Get-TitularSemana')
Invoke-Expression (Traer 'Test-ParteSemanaContado')
foreach ($cteS in @('ParteSemanaFrescoDias', 'ParteSemanaTitularMax')) {
    $mCte = [regex]::Match($txt, ('(?m)^\$' + $cteS + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cteS) $mCte.Success ''
    if ($mCte.Success) { Invoke-Expression ('$' + $cteS + ' = ' + $mCte.Groups[1].Value.Trim()) }
}
$llamP = @([regex]::Matches((($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n", '(?<!function )Test-ParteSemanaContado')).Count
Comp 'y alguien la llama de verdad' ($llamP -ge 1) "$llamP llamada(s) fuera de su definicion"

# LA CUENTA DEL DOMINGO, CONTRA UN CASO QUE SE PUEDE MIRAR EN UN CALENDARIO: la semana 38 de
# 2026 va del lunes 14 al domingo 20 de septiembre, y es la del fichero que hay en disco.
$dom38 = Get-DomingoDeSemana 2026 38
Comp 'el domingo de 2026-W38 es el 20/09' ($dom38 -eq [datetime]'2026-09-20') "$($dom38.ToString('yyyy-MM-dd'))"
Comp '  y es domingo de verdad' ($dom38.DayOfWeek -eq [DayOfWeek]::Sunday) ''

# LOS DOBLES, DE LAS DEPENDENCIAS. Se dobla por donde SALE la voz y donde estan los ficheros;
# Test-ParteSemanaContado corre entera.
$tmpS = Join-Path ([IO.Path]::GetTempPath()) ('nova-semanas-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $tmpS 'semanas') | Out-Null
$MemoriaDir = $tmpS
$script:avisos = @()
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60, [bool]$yaEsperado = $false) {
    $script:avisos += @{ clave = $clave; texto = $texto; nivel = $nivel; cadaMin = $cadaMin }
    return $true
}
function Log([string]$m) {}
$notaW38 = @"
# Semana del 14 de septiembre al 20 de septiembre de 2026

Esta semana hablamos 6 dias. Me pediste 440 cosas, y 109 de ellas las resolvi al instante sin pasar por el modelo.
Hubo 37 tropiezos (cancelaciones, dictados vacios o esperas que se pasaron de tiempo).

Lo que mas me dijiste, segun mis gestos: duda x256, grito x235.
"@
[System.IO.File]::WriteAllText((Join-Path $tmpS 'semanas\2026-W38.md'), $notaW38, (New-Object System.Text.UTF8Encoding($false)))

# EL DIA DE VERDAD: el 25/09, cinco dias despues de que acabara esa semana. Es el caso real.
$script:avisos = @()
$r1 = Test-ParteSemanaContado ([datetime]'2026-09-25')
Comp 'la nota de la semana pasada se cuenta' ($r1 -and $script:avisos.Count -eq 1) "$($script:avisos.Count) aviso(s)"
$tx = if ($script:avisos.Count -gt 0) { $script:avisos[0].texto } else { '' }
# EL TITULAR SALE DEL FICHERO, no de una cuenta nueva: si alguien recalculara los numeros
# aqui, el 440 podria no coincidir con el que esta escrito. Se comprueba que son LOS DEL
# FICHERO, y que no se suelta el parrafo entero por voz.
Comp '  con los numeros que estan escritos en ella' ($tx -match '6 dias' -and $tx -match '440 cosas' -and $tx -match '109 de ellas') "'$tx'"
Comp '  y sin soltar el ladrillo entero' ($tx -notmatch 'tropiezos' -and $tx -notmatch 'gestos') 'las cinco lineas siguientes se quedan para leerlas'
# Y UNA LINEA KILOMETRICA SI SE RECORTA, que es lo unico que ejercita el tope. Sin este caso,
# subirlo a diez mil pasaria desapercibido y Nova soltaria parrafos enteros por voz.
[System.IO.File]::WriteAllText((Join-Path $tmpS 'semanas\2026-W40.md'),
    ("# Semana larga`r`n`r`n" + (('Paso una cosa y luego otra mas. ' * 20)) + "`r`n"),
    (New-Object System.Text.UTF8Encoding($false)))
$largo = Get-TitularSemana (Join-Path $tmpS 'semanas\2026-W40.md')
# EL TOPE, CONTRA UN NUMERO QUE NO ES EL TOPE (25/09, lo cazo una rotura de este mismo banco).
# La comprobacion de abajo mide el recorte contra $ParteSemanaTitularMax... que se saca del
# mismo archivo: subiendo la constante a cien mil, el titular salia de 640 caracteres y el
# banco seguia verde, porque comparaba el resultado con la constante ya rota. Es la manera 4
# con otra ropa: el listometro y lo medido salian de la misma fuente.
# 300 caracteres son unos 20 segundos hablando, y eso ya no es un titular.
Comp '  el tope es de un titular, no de un parrafo' ($ParteSemanaTitularMax -ge 60 -and $ParteSemanaTitularMax -le 300) "$ParteSemanaTitularMax caracteres"
Comp '  una linea kilometrica se recorta' ($largo.Length -le $ParteSemanaTitularMax) "$($largo.Length) caracteres, tope $ParteSemanaTitularMax"
Comp '    y por una frase entera, no a mitad de palabra' ($largo.EndsWith('.') -and $largo -notmatch '\.\.\.$') "termina en '$($largo.Substring([Math]::Max(0,$largo.Length-12)))'"
Remove-Item -LiteralPath (Join-Path $tmpS 'semanas\2026-W40.md') -Force
Comp '  diciendo donde esta lo demas' ($tx -match 'resumen de la semana') ''
Comp '  y la clave lleva la semana dentro' ($script:avisos[0].clave -eq 'parte-semana-2026-W38') "'$($script:avisos[0].clave)'; si no, la nota del lunes que viene se quedaria tapada por el plazo"
Comp '  y no se queda en la capsula' ($script:avisos[0].nivel -ne 'bajo') "nivel '$($script:avisos[0].nivel)'"

# UNA NOTA VIEJA NO ES NOTICIA: el mismo fichero, mirado un mes despues.
$script:avisos = @()
$r2 = Test-ParteSemanaContado ([datetime]'2026-10-20')
Comp 'una nota de hace un mes NO se cuenta' ((-not $r2) -and $script:avisos.Count -eq 0) "el plazo son $ParteSemanaFrescoDias dias"
# Y EL BORDE, que es lo unico que distingue un plazo de 7 de uno de 70: justo dentro y justo
# fuera. Sin estas dos, subir el plazo a 70 pasaria desapercibido.
$script:avisos = @()
[void](Test-ParteSemanaContado ($dom38.AddDays($ParteSemanaFrescoDias)))
Comp "  el ultimo dia del plazo todavia si" ($script:avisos.Count -eq 1) "$ParteSemanaFrescoDias dias despues del domingo"
$script:avisos = @()
[void](Test-ParteSemanaContado ($dom38.AddDays($ParteSemanaFrescoDias + 1)))
Comp "  y el siguiente ya no" ($script:avisos.Count -eq 0) ''

# CON DOS NOTAS, LA MAS NUEVA. Y por su NOMBRE, no por la fecha del disco: la vieja se escribe
# la ultima a proposito, que es lo que hace una copia de seguridad al restaurar.
[System.IO.File]::WriteAllText((Join-Path $tmpS 'semanas\2026-W39.md'), "# Semana del 21 al 27`r`n`r`nEsta semana hablamos 3 dias. Y poco mas.`r`n", (New-Object System.Text.UTF8Encoding($false)))
Start-Sleep -Milliseconds 20
(Get-Item (Join-Path $tmpS 'semanas\2026-W38.md')).LastWriteTime = (Get-Date)
$script:avisos = @()
[void](Test-ParteSemanaContado ([datetime]'2026-10-01'))
Comp 'con dos notas cuenta la mas nueva' ($script:avisos.Count -eq 1 -and $script:avisos[0].clave -eq 'parte-semana-2026-W39') "'$(if($script:avisos.Count){$script:avisos[0].clave})'"
Comp '  aunque la vieja se haya tocado despues' ($script:avisos.Count -eq 1 -and $script:avisos[0].texto -match '3 dias') 'por el nombre, no por LastWriteTime'

# SIN CARPETA NO REVIENTA (una Nova recien instalada no tiene memoria\semanas)
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-nada-' + [guid]::NewGuid().ToString('N'))
$script:avisos = @()
Comp 'sin carpeta de semanas, ni una queja' ((-not (Test-ParteSemanaContado ([datetime]'2026-09-25'))) -and $script:avisos.Count -eq 0) ''
# NI CON UNA NOTA VACIA, que es lo que deja un disco lleno a mitad de escritura
$MemoriaDir = $tmpS
[System.IO.File]::WriteAllText((Join-Path $tmpS 'semanas\2026-W39.md'), '', (New-Object System.Text.UTF8Encoding($false)))
$script:avisos = @()
Comp 'con la nota vacia, se calla' ((-not (Test-ParteSemanaContado ([datetime]'2026-10-01'))) -and $script:avisos.Count -eq 0) 'sin titular no hay nada que decir'
Remove-Item -LiteralPath $tmpS -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
