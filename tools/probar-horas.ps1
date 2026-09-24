# LAS DOCE DE LA NOCHE (21/09). Salio de la tanda de agentes que reviso todo el codigo,
# y en DOS sitios a la vez: las reglas por hora y los recordatorios, que tienen las mismas
# dos lineas copiadas.
#
# La primera suma 12 solo si la hora es MENOR que 12, asi que el 12 no lo tocaba nunca; la
# segunda miraba 'manana|am', que en espanol es justo al reves:
#     las doce de la NOCHE  son las 00:00   ->  se guardaban las 12:00, el mediodia
#     las doce de la MANANA son las 12:00   ->  se guardaban las 00:00, la medianoche
# Doce horas exactas de error. Y no era solo un aviso a destiempo: "a las doce de la noche
# pon modo noche" creaba una regla a las 12:00 y le bajaba el brillo AL MEDIODIA, jugando.
#
# Y midiendo esto salio otro: "a las tres de la madrugada" no tenia franja reconocida, asi
# que caia en la regla de "hora pequena, sera de tarde" y se iba a las 15:00.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# LA CUENTA SALE DEL ARCHIVO, NO COPIADA A MANO. Si manana alguien cambia el ajuste alli,
# esto mide lo que hay y no lo que habia: es la diferencia entre una prueba y un adorno.
$HORAS_PALABRA = @{}
$mH = [regex]::Match($fuente, '(?ms)^\$HORAS_PALABRA = @\{.*?^\}')
if (-not $mH.Success) { Write-Host '  MAL  no encuentro $HORAS_PALABRA'; exit 1 }
. ([scriptblock]::Create($mH.Value))

# los dos patrones de hora, tal cual estan en el archivo
$pats = [regex]::Matches($fuente, "\(de la manana\|de la tarde\|de la noche\|de la madrugada\|am\|pm\)")
Comp 'las dos puertas conocen la madrugada' ($pats.Count -eq 2) "$($pats.Count) de 2"

$ajustes = [regex]::Matches($fuente, "if \(\`$franja -match 'noche\|madrugada\|am' -and \`$(?:h|hora) -eq 12\) \{ \`$(?:h|hora) = 0 \}")
Comp 'y las dos tienen el ajuste del doce' ($ajustes.Count -eq 2) "$($ajustes.Count) de 2"
Comp 'ya no queda el ajuste viejo por ningun lado' ($fuente -notmatch "franja -match 'manana\|am'")

# la cuenta entera, sacada de las lineas de verdad del archivo
$mA = [regex]::Match($fuente, "(?ms)(if \(\`$franja -match 'tarde\|noche\|pm' -and \`$hora -lt 12\).*?\{ \`$hora = 0 \})")
if (-not $mA.Success) { Write-Host '  MAL  no encuentro el ajuste de franja'; exit 1 }
$ajuste = [scriptblock]::Create($mA.Groups[1].Value)

function Cuando([string]$numero, [string]$franjaD) {
    $hora = $numero
    if ($HORAS_PALABRA.ContainsKey($hora)) { $hora = $HORAS_PALABRA[$hora] }
    $hora = [int]$hora
    $franja = $franjaD
    . $ajuste
    return $hora
}

Write-Host ''
Write-Host '-- el doce, que es el unico numero que no sigue la regla --'
foreach ($c in @(
        @{ n = 'doce'; f = 'de la noche';     e = 0;  q = 'las doce de la noche son las 00:00' },
        @{ n = 'doce'; f = 'de la manana';    e = 12; q = 'las doce de la manana son el mediodia' },
        @{ n = 'doce'; f = 'de la madrugada'; e = 0;  q = 'las doce de la madrugada son las 00:00' },
        @{ n = '12';   f = 'am';              e = 0;  q = 'las 12 am son las 00:00' },
        @{ n = '12';   f = 'pm';              e = 12; q = 'las 12 pm son el mediodia' }
    )) {
    $v = Cuando $c.n $c.f
    Comp $c.q ($v -eq $c.e) $(if ($v -ne $c.e) { "sale $v, deberia ser $($c.e)" } else { "$v" })
}

Write-Host ''
Write-Host '-- y el resto de horas, que NO se pueden romper arreglando el doce --'
foreach ($c in @(
        @{ n = 'diez';  f = 'de la noche';     e = 22 },
        @{ n = 'ocho';  f = 'de la manana';    e = 8 },
        @{ n = 'tres';  f = 'de la tarde';     e = 15 },
        @{ n = 'tres';  f = 'de la madrugada'; e = 3 },
        @{ n = 'una';   f = 'de la madrugada'; e = 1 },
        @{ n = 'once';  f = 'de la noche';     e = 23 },
        @{ n = 'siete'; f = 'de la manana';    e = 7 },
        @{ n = '9';     f = 'pm';              e = 21 },
        @{ n = '9';     f = 'am';              e = 9 },
        @{ n = 'seis';  f = '';                e = 6 }
    )) {
    $v = Cuando $c.n $c.f
    $como = if ($c.f) { "$($c.n) $($c.f)" } else { "$($c.n), sin franja" }
    Comp "$como -> $($c.e):00" ($v -eq $c.e) $(if ($v -ne $c.e) { "sale $v" } else { '' })
}

Write-Host ''
Write-Host '-- la madrugada ya no se confunde con la tarde --'
# la regla de "sin franja y hora pequena, sera de tarde" es la que mandaba
# "a las tres de la madrugada" a las 15:00, porque la madrugada no se reconocia
# DESDE EL 21/09 LA REGLA MIRA ADEMAS LA HORA QUE ES. Sumar 12 solo tiene sentido si esa
# hora YA PASO hoy: de madrugada no habia pasado, y "recuerdame a las siete" dicho a las
# 3:00 se guardaba para las 19:00 en vez de para dentro de cuatro horas. Y braya juega de
# madrugada, que es justo cuando mas lo dice. Por eso el patron va en dos trozos.
$mS = [regex]::Match($fuente, "if \(-not \`$franja -and \`$hora -le 7 -and \`$hora -ge 1 -and \`$null -eq \`$fecha -and")
$mS2 = [regex]::Match($fuente, "\`$horaAhora -ge \`$hora\) \{ \`$hora \+= 12 \}")
Comp 'la regla de "hora pequena = tarde" sigue ahi' $mS.Success
Comp 'y solo suma 12 si esa hora ya paso hoy' $mS2.Success
foreach ($c in @('tres', 'cuatro', 'cinco', 'dos')) {
    $conFranja = Cuando $c 'de la madrugada'
    $esperado = [int]$HORAS_PALABRA[$c]
    # con franja, la regla de la hora pequena NO entra: por eso importa reconocerla
    Comp "a las $c de la madrugada se queda en las $esperado" ($conFranja -eq $esperado) `
        $(if ($conFranja -ne $esperado) { "sale $conFranja" } else { '' })
}

Write-Host ''
Write-Host '-- y que las frases enteras lleguen bien a las dos puertas --'
# el patron completo, para ver que la frase que diria braya casa y saca la franja
$reHora = [regex]::Match($fuente, "\^\(\?:todos los dias\|cada dia\|diariamente\|siempre\)\?[^\r\n]*?de la madrugada\|am\|pm\)[^\r\n]*")
Comp 'el patron de las reglas por hora existe' $reHora.Success
foreach ($frase in @('a las doce de la noche pon modo noche',
                     'todos los dias a las doce de la manana avisame',
                     'a las tres de la madrugada baja el brillo')) {
    $casa = $frase -match 'a\s+las?\s+(\d{1,2}|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce)(?::(\d{2})|\s+y\s+media|\s+y\s+cuarto)?\s*(de la manana|de la tarde|de la noche|de la madrugada|am|pm)?'
    $fr = if ($casa) { $Matches[3] } else { '' }
    Comp ("'" + $frase.Substring(0, [Math]::Min(38, $frase.Length)) + "' saca su franja") ([bool]$fr) "franja='$fr'"
}

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  las doce de la noche son las doce de la noche, y la madrugada no es la tarde'
exit 0
