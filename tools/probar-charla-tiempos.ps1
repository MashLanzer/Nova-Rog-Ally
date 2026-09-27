# LAS CHARLAS YA MEDIDAS QUE SE TIRABAN (26/09, idea 37 de las 121).
#
# La primera frase de cada charla llegaba cronometrada en el log ("primera frase en N s") y se
# tiraba: 265 medidas en el registro que no alimentaban nada, mientras cuatro umbrales de espera
# seguian a fuego (5.000 / 2.000 / 5.000 / 16.000 ms). Ahora se guardan en charla-tiempos.json y
# de ahi salen los umbrales, con la misma regla que voz-tiempos: el dato solo BAJA la espera.
#
# DOS LISTAS, api y local, NO una. Emparejando en el registro cada medida con su motor: la API
# contesta el 90,7 % en 1,0 s (p95 2,9 s) y el local el 9,3 % en 16,5 s (max 33). Una sola lista
# da un p85 de 2,1 s que no es de nadie -la api con la cola del local encima-, y promediar dos
# cosas que se diferencian en 10x es lo que prohibe la regla 3.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- las funciones de verdad, con su json en un temporal (como probar-voz-plazo) ---
$script:invitado = $false
$CharlaTiemposJson = Join-Path ([IO.Path]::GetTempPath()) ('ct-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
$CharlaTiemposMax = 200
$DecisionMinIntentos = if ($fuente -match '(?m)^\$DecisionMinIntentos = (\d+)') { [int]$Matches[1] } else { -1 }
Invoke-Expression (Traer 'Get-CharlaTiempos')
Invoke-Expression (Traer 'Add-CharlaTiempo')
Invoke-Expression (Traer 'Get-CharlaPercentil')
Invoke-Expression (Traer 'Get-CharlaEsperaMs')
function Reset { if (Test-Path -LiteralPath $CharlaTiemposJson) { Remove-Item -LiteralPath $CharlaTiemposJson -Force } }

Comp '0. el liston de la casa se lee del archivo' ($DecisionMinIntentos -eq 20) "\$DecisionMinIntentos = $DecisionMinIntentos"

# --------------------------------------------------------------------------------------------
Write-Host '  -- las dos listas no se mezclan --'
Reset
# forma medida: api mediana 1,0 s con cola a 14; local 16-33 s
1..224 | ForEach-Object { [void](Add-CharlaTiempo ([int](900 + ($_ % 30) * 45 + $(if ($_ -gt 214) { 12500 } else { 0 }))) 'api') }
1..24 | ForEach-Object { [void](Add-CharlaTiempo ([int](16000 + $_ * 700)) 'local') }
$a = Get-CharlaTiempos 'api'
$l = Get-CharlaTiempos 'local'
$pApi = Get-CharlaPercentil 95 $a 20
$pLoc = Get-CharlaPercentil 50 $l 20
Comp '1. api p95 se queda en su escala baja (1,5-4 s, no en la del local)' ($pApi -ge 1500 -and $pApi -le 4000) "$pApi ms"
Comp '   y local p50 en la suya (> 14 s)' ($pLoc -gt 14000) "$pLoc ms"
# la mezcla que NO queremos: juntando las dos, el p95 se dispara
$mezcla = New-Object System.Collections.ArrayList
[void]$mezcla.AddRange(@($a)); [void]$mezcla.AddRange(@($l))
$pMix = Get-CharlaPercentil 95 $mezcla 20
Comp '   mezcladas darian un p95 que no es de nadie' ($pMix -gt 10000) "$pMix ms (por eso van separadas)"

Write-Host ''
Write-Host '  -- el dato solo BAJA la espera, nunca la sube --'
Reset
1..200 | ForEach-Object { [void](Add-CharlaTiempo ([int](30000 + $_ * 100)) 'api') }   # una tarde de red malisima
$aLento = Get-CharlaTiempos 'api'
Comp '2. con 200 muestras lentisimas, la muletilla sigue en 5000' ((Get-CharlaEsperaMs 95 5000 $aLento 20) -eq 5000) 'sin tope, Nova callaria 40 s'

Write-Host ''
Write-Host '  -- el liston de 20 muestras --'
Reset
1..19 | ForEach-Object { [void](Add-CharlaTiempo 1000 'api') }
$a19 = Get-CharlaTiempos 'api'
Comp '3. con 19 muestras no decide (percentil 0)' ((Get-CharlaPercentil 95 $a19 20) -eq 0) 'no me preguntes todavia'
Comp '   y devuelve el escrito' ((Get-CharlaEsperaMs 95 5000 $a19 20) -eq 5000) ''
[void](Add-CharlaTiempo 1000 'api')
$a20 = Get-CharlaTiempos 'api'
Comp '   con 20, ya decide' ((Get-CharlaPercentil 95 $a20 20) -gt 0) ''

# EL CABLEADO vive en Receive-Charla; se saca por AST y se extraen sus bloques por llaves (NO con
# [\s\S]{0,N}, la expresion fragil que la casa cuenta y limita). SIN LINEAS DE COMENTARIO: si no,
# el propio comentario que menciona "InvariantCulture" o el regex haria pasar el check aunque el
# codigo lo hubiera perdido (manera 16 de salir verde mintiendo).
$rc = Traer 'Receive-Charla'
function Bloque([string]$texto, [string]$anclaAbre) {
    $i = $texto.IndexOf($anclaAbre)
    if ($i -lt 0) { return '' }
    $abre = $texto.IndexOf('{', $i)
    if ($abre -lt 0) { return '' }
    $prof = 0
    for ($p = $abre; $p -lt $texto.Length; $p++) {
        if ($texto[$p] -eq '{') { $prof++ }
        elseif ($texto[$p] -eq '}') { $prof--; if ($prof -eq 0) { return $texto.Substring($abre, $p - $abre + 1) } }
    }
    return ''
}
function SinComentarios([string]$t) { return (($t -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n" }
$bInfo = SinComentarios (Bloque $rc "ev.ev -eq 'info'")
$bFrase = SinComentarios (Bloque $rc "ev.ev -eq 'frase'")

Write-Host ''
Write-Host '  -- la coma y el punto, y los dos formatos de linea (regex sacado del CODIGO) --'
# el regex de verdad, extraido del codigo del info (no reescrito aqui): tiene que cazar las dos formas
$mRe = [regex]::Match($bInfo, "-match '([^']+)'")
$reArchivo = if ($mRe.Success) { $mRe.Groups[1].Value } else { '' }
Comp '4. el regex de la primera frase esta en el codigo del info' ($reArchivo -like '*primera frase en*') "'$reArchivo'"
Comp '   caza el formato con parentesis (246 casos)' (('primera frase en 1.2 s (buscar en la memoria: 0.0 s)' -match $reArchivo) -and $Matches[1] -eq '1.2') ''
$g1 = if ('primera frase en 6.6 s' -match $reArchivo) { $Matches[1] } else { '' }
Comp '   y el formato a secas (11 casos)' ($g1 -eq '6.6') 'anclar con fin de linea perderia los 246 con parentesis'
# la cultura: bajo es-ES, el TryParse pelado lee "1.2" como 12; el bueno (Invariant) como 1,2
$culturaVieja = [System.Threading.Thread]::CurrentThread.CurrentCulture
try {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('es-ES')
    $d = 0.0
    $ok = [double]::TryParse('1.2', [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)
    Comp '   "1.2 s" son 1200 ms hasta bajo es-ES (InvariantCulture)' ($ok -and [int]($d * 1000) -eq 1200) "$([int]($d*1000)) ms"
} finally { [System.Threading.Thread]::CurrentThread.CurrentCulture = $culturaVieja }
Comp '   y el codigo del info parsea con InvariantCulture (no el TryParse pelado)' ($bInfo -match 'InvariantCulture') 'el pelado leeria 1.2 como 12 bajo es-ES'

Write-Host ''
Write-Host '  -- no guarda basura --'
Reset
Comp '9. no guarda ms 0 (hay 2 en el registro)' (-not (Add-CharlaTiempo 0 'api')) ''
Comp '   ni negativos' (-not (Add-CharlaTiempo -5 'api')) ''
Comp "   ni el origen 'memoria' / 'trivia' / vacio" ((-not (Add-CharlaTiempo 100 'memoria')) -and (-not (Add-CharlaTiempo 100 'trivia')) -and (-not (Add-CharlaTiempo 100 ''))) 'solo api y local'
$script:invitado = $true
Comp '   ni con el invitado delante' (-not (Add-CharlaTiempo 1000 'api')) ''
$script:invitado = $false
$aBasura = Get-CharlaTiempos 'api'
Comp '   nada de eso entro en la lista' ($aBasura.Count -eq 0) "api=$($aBasura.Count)"

Write-Host ''
Write-Host '  -- el tope de la lista --'
Reset
$CharlaTiemposMax = 30
1..60 | ForEach-Object { [void](Add-CharlaTiempo (1000 + $_) 'api') }
$aTope = Get-CharlaTiempos 'api'
Comp '10. con tope 30 y 60 metidas, quedan 30' ($aTope.Count -eq 30) "$($aTope.Count)"
Comp '    y son las ULTIMAS (la primera es 1031, no 1001)' ((@($aTope)[0] -eq 1031)) "primera=$((@($aTope))[0])"
$CharlaTiemposMax = 200
Reset

Write-Host ''
Write-Host '  -- y el cableado en assistant.ps1 (bloques por llaves, sin comentarios) --'
# 6. la muestra de una respuesta cortada no cuenta: el id se comprueba DENTRO del info (que
#    corre antes del filtro de id de 24274)
Comp '6. la muestra se ata al id dentro del info (una cortada no cuenta)' ($bInfo -match '\[int\]\$ev\.id -eq \$script:charlaId') 'el info corre antes del filtro de id general'
# 7. una respuesta, una muestra: en el frase se guarda y se cierra con -1
$iAdd = $bFrase.IndexOf('Add-CharlaTiempo')
$iCierra = $bFrase.IndexOf('$script:charlaMsPend = -1')
Comp '7. el frase guarda la muestra' ($iAdd -ge 0) ''
Comp '   y la cierra con -1 justo despues (una respuesta = una muestra)' ($iCierra -gt $iAdd) 'sin esto una respuesta larga meteria tres copias'
# tres puntos ponen charlaMsPend a -1: donde nace, Stop-Charla y Send-Charla
Comp '   Stop-Charla y Send-Charla tambien lo dejan en -1' ((@([regex]::Matches($fuente, '\$script:charlaMsPend = -1')).Count -ge 3)) 'nace, se corta y se resetea'
# 8. los tres literales ya no estan y las variables si
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '8. la muletilla ya no usa -gt 5000 a fuego' ($sinCom -match 'charlaDesde\) -gt \$script:charlaUmbralMuletilla') ''
Comp '   la barra ya no usa -gt 2000 a fuego' ($sinCom -match 'charlaDesde\) -gt \$script:charlaUmbralBarra') ''
Comp '   la escala usa las dos variables, no 5000.0/16000.0' (($sinCom -match '\[double\]\$script:charlaEscalaCaliente') -and ($sinCom -match '\[double\]\$script:charlaEscalaFria')) ''
Comp '   y no queda ningun 5000.0 ni 16000.0 literal en el bucle' (($sinCom -notmatch '\{ 5000\.0 \}') -and ($sinCom -notmatch '\{ 16000\.0 \}')) ''
# 12. la clave 'charla' ya no esta en DURACION_ESPERADA
$mDur = [regex]::Match($sinCom, '\$DURACION_ESPERADA = @\{[^}]*\}')
Comp "12. 'charla' fuera de DURACION_ESPERADA" ($mDur.Success -and ($mDur.Value -notmatch "'charla'")) 'era codigo muerto'
# 11. el .gitignore cubre el fichero nuevo
$gi = [IO.File]::ReadAllText((Join-Path $raiz '.gitignore'))
Comp '11. memoria/charla-tiempos.json esta en el .gitignore' ($gi -match 'memoria/charla-tiempos\.json') 'el repositorio es publico'

Reset
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'las charlas medidas ya no se tiran' -ForegroundColor Green
exit 0
