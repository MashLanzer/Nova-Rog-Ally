# EL 44 % DEL DIARIO DE GESTOS ERA RUIDO QUE NINGUN LECTOR MIRA (27/09, idea 100 de las 121)
#
# EL DATO, contado sobre tmp\gestos.log: 1.506 'escucho' + 124 'lotengo' + 2 'atencion' = 1.632 de
# 3.674 lineas, el 44,4 % exacto. Y los DOS unicos lectores -la tabla de memoria\estadisticas.md y
# el parte semanal- los saltan explicitamente por nombre: "ruido: pasan a cada rato".
#
# Y LA PODA IBA A TIRAR LO BUENO PARA CONSERVARLOS: el fichero crece a 204 lineas al dia (3.674 en
# 18 dias) y la poda entraba a las 6.000 dejando las 5.000 ultimas, asi que llegaba en unos once
# dias y de esas 5.000 unas 2.220 serian de esas tres. Cada linea de ruido que se queda echa una de
# verdad.
#
# DOS CAMBIOS: la capsula ya no las escribe linea a linea -lleva la cuenta del dia en
# gestos-cuenta.txt- y la poda corta por FECHA, no por lineas.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la poda deje siempre los mismos DIAS, y no un numero de lineas que segun el mes son 8
#      dias o 40
#   2. que no borre nunca un dia que la tabla todavia ensena
#   3. que el techo de lineas siga ahi por si un bucle escribe de golpe
#   4. que la capsula desvie los tres y SOLO los tres
#   5. y que el contador nuevo lo LEA alguien, para que no sea otro fichero muerto
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$CS = Join-Path $Raiz 'nova_ui.cs'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
# $txtCs Y NO $cs: en PowerShell los nombres de variable NO distinguen mayusculas, asi que $cs
# machacaba a $CS -la ruta del fichero- con su contenido, y el Get-Item de mas abajo moria con
# 'caracteres no validos en la ruta de acceso'. Es la misma trampa que junto una constante y un
# contador el 27/09 ($AcelSeguidos).
$txtCs = [IO.File]::ReadAllText($CS)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

$GestosDias = 14
$GestosLineasTope = 6000
$m1 = [regex]::Match($txt, '(?m)^\$GestosDias = (\d+)')
$m2 = [regex]::Match($txt, '(?m)^\$GestosLineasTope = (\d+)')
Comp 'los dias salen del archivo' $m1.Success ($m1.Groups[1].Value + ' dias')
Comp 'y el techo de lineas tambien' $m2.Success ($m2.Groups[1].Value + ' lineas')
if ($m1.Success) { $GestosDias = [int]$m1.Groups[1].Value }
if ($m2.Success) { $GestosLineasTope = [int]$m2.Groups[1].Value }
Comp '  y los dias son los que ensena la tabla' ($sinCom -match 'Select-Object -First \$GestosDias') 'si no, se podaria algo que se sigue mostrando'

# EL TROZO DE LA PODA, SACADO DEL FICHERO Y EJECUTADO. No vive en una funcion propia -esta dentro
# del bloque que rehace el markdown- asi que se corta por sangrado, que es lo unico fiable: un
# '} elseif (...) {' tiene equilibrio de llaves cero y contar llaves saca un cuerpo vacio.
$lin = [IO.File]::ReadAllLines($PS1)
$i0 = -1
for ($i = 0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*if \(\$lineasG\.Count -gt \$GestosLineasTope\) \{') { $i0 = $i; break }
}
Comp 'se encuentra la poda en el fichero' ($i0 -ge 0) ''
$sangrado = ($lin[$i0] -replace '\S.*$', '').Length
$i1 = -1
for ($i = ($i0 + 1); $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*\}' -and (($lin[$i] -replace '\S.*$', '').Length -eq $sangrado)) { $i1 = $i; break }
}
Comp '  y donde acaba' ($i1 -gt $i0 -and ($i1 - $i0) -lt 30) ([string]($i1 - $i0 + 1) + ' lineas')
$cuerpo = ($lin[$i0..$i1] -join "`n")
Comp '  cortando por fecha, no por lineas' ($cuerpo -match 'CompareOrdinal\(\$_\.Substring\(0, 10\), \$desdeG\)') ''

# el mundo de mentira
$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-gestos-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$gl = Join-Path $TmpDir 'gestos.log'
$enc = New-Object Text.UTF8Encoding($false)
$fn = [scriptblock]::Create("function Podar([string]`$gl, [ref]`$lineasG) {`n" + ($cuerpo -replace '\$lineasG', '$lineasG.Value') + "`nreturn `$lineasG.Value`n}")
. $fn
function Montar([int]$dias, [int]$porDia) {
    $ls = @()
    for ($d = $dias; $d -ge 0; $d--) {
        $f = (Get-Date).AddDays(-1 * $d).ToString('yyyy-MM-dd')
        for ($k = 0; $k -lt $porDia; $k++) { $ls += ($f + ' 12:00:0' + ($k % 10) + ' duda') }
    }
    [IO.File]::WriteAllLines($gl, [string[]]$ls, $enc)
    return $ls
}
function Dias([string[]]$ls) { return @($ls | ForEach-Object { $_.Substring(0, 10) } | Select-Object -Unique).Count }

try {
    Write-Host ''
    Write-Host '-- 1. POR DEBAJO DEL TECHO NO SE TOCA NADA --'
    $ls = Montar 40 10          # 41 dias x 10 = 410 lineas
    $antes = $ls.Count
    $r = @(Podar $gl ([ref]$ls))
    Comp '1a. no se poda' ($r.Count -eq $antes) ([string]$r.Count + ' de ' + [string]$antes)
    Comp '1b. y siguen los 41 dias' ((Dias $r) -eq 41) ([string](Dias $r) + ' dias')

    Write-Host ''
    Write-Host '-- 2. PASADO EL TECHO, SE QUEDAN LOS DIAS DE LA TABLA --'
    # 40 dias a 200 lineas = 8.200: pasa el techo de 6.000
    $ls2 = Montar 40 200
    # EL TAMANO SE GUARDA ANTES: Podar recibe [ref], asi que al reasignar dentro cambia tambien la
    # variable de aqui y comparar contra ella era compararla consigo misma. Salio MAL a la primera.
    $antes2 = $ls2.Count
    $r2 = @(Podar $gl ([ref]$ls2))
    Comp '2a. se poda' ($r2.Count -lt $antes2) ([string]$r2.Count + ' de ' + [string]$antes2)
    Comp '2b. y quedan los dias de la tabla' ((Dias $r2) -le ($GestosDias + 1) -and (Dias $r2) -ge $GestosDias) ([string](Dias $r2) + ' dias, la tabla ensena ' + [string]$GestosDias)
    $hoy = (Get-Date).ToString('yyyy-MM-dd')
    Comp '2c. con hoy dentro' (@($r2 | Where-Object { $_.StartsWith($hoy) }).Count -gt 0) ''
    $viejo = (Get-Date).AddDays(-40).ToString('yyyy-MM-dd')
    Comp '2d. y lo de hace 40 dias fuera' (@($r2 | Where-Object { $_.StartsWith($viejo) }).Count -eq 0) ''
    # y se escribio de verdad
    $enDisco = [IO.File]::ReadAllLines($gl, [Text.Encoding]::UTF8)
    Comp '2e. y el fichero del disco tambien' ($enDisco.Count -eq $r2.Count) ([string]$enDisco.Count)

    Write-Host ''
    Write-Host '-- 3. LO QUE LA PODA VIEJA HACIA MAL (de esto va la idea) --'
    # con 200 lineas al dia, 5.000 lineas son 25 dias; con 1.000 al dia son CINCO. La ventana de la
    # relacion cambiaba de tamano segun cuanto se hablara ese mes.
    $ls3 = Montar 40 1000
    $r3 = @(Podar $gl ([ref]$ls3))
    Comp '3a. hablando mucho, los dias NO se encogen' ((Dias $r3) -ge 5) ([string](Dias $r3) + ' dias; la poda vieja dejaba 5')
    Comp '3b. pero el techo de lineas se respeta' ($r3.Count -le $GestosLineasTope) ([string]$r3.Count + ' de tope ' + [string]$GestosLineasTope)

    Write-Host ''
    Write-Host '-- 4. Y NUNCA SE QUEDA VACIO --'
    # todas las lineas de hace un ano: por fecha no queda ninguna, asi que manda el techo
    $ls4 = @()
    for ($k = 0; $k -lt 7000; $k++) { $ls4 += ('2025-01-01 12:00:00 duda') }
    [IO.File]::WriteAllLines($gl, [string[]]$ls4, $enc)
    $r4 = @(Podar $gl ([ref]$ls4))
    Comp '4a. con todo viejo, no se borra todo' ($r4.Count -gt 0) ([string]$r4.Count + ' lineas; mejor un fichero grande que uno vacio')
    # y con lineas sin fecha reconocible
    $ls5 = @()
    for ($k = 0; $k -lt 7000; $k++) { $ls5 += ('basura sin fecha') }
    [IO.File]::WriteAllLines($gl, [string[]]$ls5, $enc)
    $r5 = @(Podar $gl ([ref]$ls5))
    Comp '4b. con lineas sin fecha, tampoco' ($r5.Count -gt 0) ([string]$r5.Count)

    Write-Host ''
    Write-Host '-- 5. LA CAPSULA DESVIA LOS TRES, Y SOLO LOS TRES --'
    Comp '5a. los tres estan en una lista a la vista' ($txtCs -match 'gestosRuido = \{ "escucho", "lotengo", "atencion" \}') 'los mismos que los dos lectores saltan'
    Comp '5b. y son LOS MISMOS que salta el markdown' ($sinCom -match "\`$g -in @\('escucho', 'lotengo', 'atencion'\)") 'dos listas que se separen serian el fallo'
    Comp '5c.   y el parte semanal' ($sinCom -match "\`$Matches\[2\] -in @\('escucho', 'lotengo', 'atencion'\)") ''
    Comp '5d. van al contador, no al diario' ($txtCs -match 'if \(Array\.IndexOf\(gestosRuido, nombre\) >= 0\)') ''
    $iIf = $txtCs.IndexOf('if (Array.IndexOf(gestosRuido, nombre) >= 0)')
    $iRet = $txtCs.IndexOf('return;', $iIf)
    $iApp = $txtCs.IndexOf('File.AppendAllText(rutaGestosLog', $iIf)
    Comp '5e. con un return antes del append, para no escribir las dos veces' ($iIf -ge 0 -and $iRet -gt $iIf -and $iApp -gt $iRet) ''
    Comp '5f. y los demas siguen yendo al diario' ($txtCs -match 'File\.AppendAllText\(rutaGestosLog') ''
    Comp '5g. el contador se reescribe, no crece' ($txtCs -match 'File\.WriteAllText\(rutaC') 'una linea por dia y gesto, no un append por gesto'
    # EL FORMATO NO ES LA REGLA (30/09). Esto pedia el if y el Clear() en la MISMA linea, con la
    # llave pegada, y el bloque crecio a estilo Allman -llave en su linea- al meterle dentro la
    # relectura de lo que ya hay de hoy. Rojo por un salto de linea, con el codigo intacto. Se
    # sigue exigiendo lo mismo -que el Clear() cuelgue de ese if y no ande suelto- pero sin
    # mandar donde va la llave: el hueco es corto a proposito, para que no cuele un Clear() que
    # este veinte lineas mas abajo y ya no dependa de la condicion.
    Comp '5h. y empieza de cero al cambiar el dia' ($txtCs -match '(?s)if \(cuentaGestosDia != hoy\)\s*\{?\s*cuentaGestos\.Clear\(\)') ''
    $exeG = Join-Path $Raiz 'nova_ui.exe'
    if (Test-Path -LiteralPath $exeG) {
        Comp '5i. la capsula compilada esta al dia' ((Get-Item -LiteralPath $exeG).LastWriteTime -ge (Get-Item -LiteralPath $CS).LastWriteTime) 'si no, esto no corre todavia'
    } else {
        Write-Host '  --   no hay nova_ui.exe compilado, se salta'
    }

    Write-Host ''
    Write-Host '-- 6. Y EL CONTADOR NUEVO LO LEE ALGUIEN --'
    Comp '6a. el markdown lo lee' ($sinCom -match "gestos-cuenta\.txt") 'si no, seria otro fichero muerto como senales-fallo.jsonl'
    Comp '6b. y lo ensena' ($sinCom -match 'de los que pasan a cada rato') ''
    Comp '6c. con el formato que escribe la capsula' ($sinCom -match "\\d\{4\}-\\d\{2\}-\\d\{2\}\) \(\\S\+\) \(\\d\+\)") 'fecha, gesto y cuenta'
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el diario de gestos se mide en dias y ya no guarda lo que nadie lee' -ForegroundColor Green
exit 0
