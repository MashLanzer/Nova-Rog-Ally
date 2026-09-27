# EL DIARIO DE GESTOS NO DECIA QUIEN LO PROVOCO, Y EL RESUMEN LO CONTABA AL REVES
# (27/09, idea 101 de las 121)
#
# LO QUE ESTABA ESCRITO: memoria\semanas\2026-W37.md dice "Lo que mas me dijiste, segun mis gestos:
# grito x148, confuso x143, orgullo x123, perdida x59". De esos cuatro, TRES son de Nova -confuso,
# orgullo y perdida los dispara lo que ELLA dice, o los manda el asistente por la puerta de
# eventos-. W38 dice "duda x256, grito x235, confuso x119, negar x80": confuso otra vez, y 'duda' la
# pueden disparar los dos.
#
# EL REPARTO, contado clasificando cada linea del diario contra las tres tablas de patrones de
# nova_ui.cs y los doce 'gesto:<nombre>' que manda assistant.ps1:
#   87 lineas (4,3 %)   solo braya puede dispararlas
#   681   (33,3 %)      solo Nova
#   792   (38,8 %)      un nombre que pueden disparar los dos
#   481                 grito y susurro, que salen de MedirTono: el microfono de braya
# El verificador de la ficha tenia razon en eso ultimo: grito NO es de Nova.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que las lineas VIEJAS, sin letra, se sigan leyendo (o el diario entero se perderia)
#   2. que lo que no lleva marca NO se le atribuya a nadie
#   3. que en "lo que me dijiste" entren SOLO los suyos
#   4. que la capsula sepa de quien es cada gesto en los seis sitios que lo apuntan
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$RutaCs = Join-Path $Raiz 'nova_ui.cs'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
# $txtCs y NO $cs: $CS machacaria la ruta, que en PowerShell es la misma variable (paso el 27/09)
$txtCs = [IO.File]::ReadAllText($RutaCs)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host ''
Write-Host '-- 1. LA REGEX ACEPTA LAS DOS FORMAS (si no, se pierde el diario entero) --'
# LA REGEX SE SACA DEL FICHERO, no se copia: si alguien la cambia en el codigo y no aqui, esto
# dejaria de probar lo que corre.
# SE SACA DE LA LINEA QUE LA USA, cogiendo lo que hay entre las comillas simples: un meta-regex que
# escape un regex es ilegible y se rompe con nada (lo escribi asi y salio MAL a la primera).
$rx = ''
# SE BUSCA LA LINEA POR CONTENIDO LITERAL, y las dos versiones anteriores de esto salieron MAL:
# con '^(\d{4}' hay varias regex de fecha en el fichero y cogia una de otra cosa, y buscando 'tyn'
# con -match resulta que PowerShell NO distingue mayusculas y "NotePropertyName" lleva "tyN"
# dentro. .Contains es literal y sensible, que es lo que hacia falta.
foreach ($lRx in ($txt -split "`r?`n")) {
    if ($lRx.Contains('[tyn?]') -and $lRx.Contains('-match')) {
        if ($lRx -match "-match '([^']+)'") { $rx = $Matches[1]; break }
    }
}
Comp 'la regex sale del archivo' ($rx.Length -gt 0) $rx
if (-not $rx) { Write-Host '  MAL  sin la regex no se puede probar nada'; exit 1 }
$vecesRx = @([regex]::Matches($sinCom, [regex]::Escape($rx))).Count
Comp '  y los DOS lectores usan la misma' ($vecesRx -eq 2) ([string]$vecesRx + ' lectores; dos regex que se separen serian el fallo')

function Leer([string]$l) {
    if ($l -match $rx) {
        return @{ dia = $Matches[1]; gesto = $Matches[2]; quien = $(if ($Matches[3]) { [string]$Matches[3] } else { '' }) }
    }
    return $null
}
$vieja = Leer '2026-09-20 18:55:20 confuso'
Comp '1a. una linea VIEJA se sigue leyendo' ($null -ne $vieja -and $vieja.gesto -eq 'confuso') 'hay 3.674 asi'
Comp '1b. y se queda sin quien' ($vieja.quien -eq '') 'no se le atribuye a nadie'
$tuya = Leer '2026-09-27 12:00:00 grito t'
Comp '1c. una nueva de braya' ($null -ne $tuya -and $tuya.gesto -eq 'grito' -and $tuya.quien -eq 't') ''
$suya = Leer '2026-09-27 12:00:00 confuso y'
Comp '1d. una nueva de Nova' ($null -ne $suya -and $suya.gesto -eq 'confuso' -and $suya.quien -eq 'y') ''
$nose = Leer '2026-09-27 12:00:00 logro ?'
Comp '1e. y una que de verdad no se sabe' ($null -ne $nose -and $nose.quien -eq '?') ''
Comp '1f. el nombre no se come la letra' ((Leer '2026-09-27 12:00:00 determinacion t').gesto -eq 'determinacion') 'con \S+ codicioso, el gesto seria "determinacion t"'
Comp '1g. y una linea con basura no casa' ($null -eq (Leer 'esto no es una linea')) ''

Write-Host ''
Write-Host '-- 2. EN "LO QUE ME DIJISTE" ENTRAN SOLO LOS SUYOS --'
$lin = [IO.File]::ReadAllLines($PS1)
$i0 = -1
for ($i = 0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*\$gl = Join-Path \$TmpDir ''gestos\.log''' -and $i -gt 20000) { $i0 = $i; break }
}
Comp 'se encuentra el lector del parte semanal' ($i0 -ge 0) ''
# el bloque: desde el if de Test-Path hasta su cierre, por sangrado
$iIf = -1
for ($i = $i0; $i -lt ($i0 + 4); $i++) { if ($lin[$i] -match '^\s*if \(Test-Path -LiteralPath \$gl\) \{') { $iIf = $i; break } }
$sang = ($lin[$iIf] -replace '\S.*$', '').Length
$iFin = -1
for ($i = ($iIf + 1); $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*\}' -and (($lin[$i] -replace '\S.*$', '').Length -eq $sang)) { $iFin = $i; break }
}
$cuerpo = ($lin[$iIf..$iFin] -join "`n")
Comp '  y su bloque' ($iFin -gt $iIf -and ($iFin - $iIf) -lt 20) ([string]($iFin - $iIf + 1) + ' lineas')
$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-gq-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$gl = Join-Path $TmpDir 'gestos.log'
$fn = [scriptblock]::Create("function Contar([datetime]`$ini, [datetime]`$fin) {`n`$gestos = @{}`n`$gestosSinMarca = 0`n$cuerpo`nreturn @{ g = `$gestos; sin = `$gestosSinMarca }`n}")
. $fn
$enc = New-Object Text.UTF8Encoding($false)
try {
    $hoy = (Get-Date).ToString('yyyy-MM-dd')
    [IO.File]::WriteAllLines($gl, [string[]]@(
        "$hoy 12:00:00 grito t",
        "$hoy 12:00:01 grito t",
        "$hoy 12:00:02 confuso y",
        "$hoy 12:00:03 orgullo y",
        "$hoy 12:00:04 perdida y",
        "$hoy 12:00:05 gracias t",
        "$hoy 12:00:06 logro ?",
        "$hoy 12:00:07 escucho y",
        "$hoy 12:00:08 duda"), $enc)
    $r = Contar ((Get-Date).AddDays(-1)) ((Get-Date).AddDays(1))
    Comp '2a. solo entran los suyos' (@($r.g.Keys).Count -eq 2) (($r.g.Keys | Sort-Object) -join ', ')
    Comp '2b. con sus cuentas' ($r.g['grito'] -eq 2 -and $r.g['gracias'] -eq 1) ('grito x' + [string]$r.g['grito'])
    Comp '2c. y los de Nova NO' (-not ($r.g.ContainsKey('confuso') -or $r.g.ContainsKey('orgullo') -or $r.g.ContainsKey('perdida'))) 'eran tres de los cuatro del resumen de W37'
    Comp '2d. ni los que no se sabe' (-not $r.g.ContainsKey('logro')) ''
    Comp '2e. ni el ruido de siempre' (-not $r.g.ContainsKey('escucho')) ''
    Comp '2f. y las viejas se cuentan aparte' ($r.sin -eq 1) ([string]$r.sin + ' sin marca')
    # el caso de la primera semana: TODO viejo
    [IO.File]::WriteAllLines($gl, [string[]]@("$hoy 12:00:00 confuso", "$hoy 12:00:01 grito", "$hoy 12:00:02 duda"), $enc)
    $r2 = Contar ((Get-Date).AddDays(-1)) ((Get-Date).AddDays(1))
    Comp '2g. una semana entera sin marcas no afirma nada' (@($r2.g.Keys).Count -eq 0) ([string]@($r2.g.Keys).Count)
    Comp '2h. pero se sabe cuantas eran' ($r2.sin -eq 3) ([string]$r2.sin)
    Comp '2i. y el resumen lo dice en vez de callarse' ($sinCom -match 'no sé cuáles fueron cosa tuya') 'la regla 2 de la casa'
    # y fuera de la ventana no entra nada
    [IO.File]::WriteAllLines($gl, [string[]]@('2020-01-01 12:00:00 grito t'), $enc)
    $r3 = Contar ((Get-Date).AddDays(-7)) (Get-Date)
    Comp '2j. y lo de fuera de la semana sigue fuera' (@($r3.g.Keys).Count -eq 0 -and $r3.sin -eq 0) ''
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 3. LA TABLA DEL MARKDOWN DICE DE QUIEN ES CADA UNO --'
Comp '3a. el nombre lleva de quien es' ($sinCom -match "\`$claveG = \`$g \+ \`$\(switch \(\`$qG\)") ''
Comp '3b. y no se juntan los dos' ($sinCom -match "'t' \{ ' \(tu\)' \} 'y' \{ ' \(yo\)' \}") '"confuso" de Nova y "confuso" de braya son dos cosas'
Comp '3c. lo sin marca se queda sin etiqueta' ($sinCom -match "default \{ '' \}") 'no dice "(tu)" de lo que no sabe'

Write-Host ''
Write-Host '-- 4. LA CAPSULA SABE DE QUIEN ES, EN TODOS LOS SITIOS --'
Comp '4a. AnotarGesto recibe el quien' ($txtCs -match 'void AnotarGesto\(string nombre, char quien\)') ''
Comp '4b. y lo escribe al final de la linea' ($txtCs -match 'nombre \+ " " \+ quien \+ "\\r\\n"') 'al final para que las viejas sigan casando'
Comp '4c. Gesto lo pasa' ($txtCs -match "void Gesto\(string nombre, char quien = '\?'\)") "con '?' de fabrica: quien no lo diga, no se atribuye"
Comp '4d. el texto de braya va con t' ($txtCs -match "rxExtra\[i\]\.IsMatch\(p\)\) \{ Gesto\(gestosExtra\[i\]\[0\], 't'\)") ''
Comp '4e. el de Nova con y' ($txtCs -match "RX_PROPIOS\[i\]\.IsMatch\(p\)\) \{ Gesto\(GESTOS_PROPIOS\[i\]\[0\], 'y'\)") ''
Comp '4f. el grito del microfono con t' ($txtCs -match 'Gesto\("grito", ''t''\)') 'lo que corrigio el verificador: sale del micro de braya'
Comp '4g. y el susurro tambien' ($txtCs -match 'Gesto\("susurro", ''t''\)') ''
Comp '4h. la puerta de eventos, con y' ($txtCs -match "case ""gesto"": Gesto\(arg, 'y'\)") 'ahi estaban los 681 apuntes que el resumen le atribuia a el'
Comp '4i. el logro de Steam, con t' ($txtCs -match 'case "logro": Gesto\("logro", ''t''\)') 'el oro lo saco el jugando'
Comp '4j. y repetir una orden, con t' ($txtCs -match 'Gesto\("determinacion", ''t''\)') ''
# NINGUNO SE QUEDA SIN LETRA: la comprobacion que pilla el que se olvide manana
$sueltos = @([regex]::Matches($txtCs, 'Gesto\("[a-z]+"\)') | ForEach-Object { $_.Value })
# el de dentro de un comentario no cuenta
$sueltosReal = @()
foreach ($lc in ($txtCs -split "`r?`n")) {
    if ($lc.TrimStart().StartsWith('//')) { continue }
    foreach ($m in [regex]::Matches($lc, 'Gesto\("[a-z]+"\)')) { $sueltosReal += $m.Value }
}
Comp '4k. y ni uno se queda sin letra' ($sueltosReal.Count -eq 0) ($sueltosReal -join ', ')
$exe = Join-Path $Raiz 'nova_ui.exe'
if (Test-Path -LiteralPath $exe) {
    Comp '4l. la capsula compilada esta al dia' ((Get-Item -LiteralPath $exe).LastWriteTime -ge (Get-Item -LiteralPath $RutaCs).LastWriteTime) 'si no, esto no corre todavia'
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el diario de gestos dice de quien es cada uno, y el resumen ya no se lo atribuye a braya' -ForegroundColor Green
exit 0
