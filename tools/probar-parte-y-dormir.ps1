# DOS AVISOS QUE SALIAN CUANDO NO TOCABA (22/09 por la noche, ideas 8 y 10).
#
# EL PARTE DE LA MANANA (idea 8). Desde el 20/09 lo llama tambien el bucle y sale a las
# 05:00:2x clavadas. La primera actividad real de braya esos dias fue a las 12:53, 16:31 y
# 20:25 -472, 691 y 925 minutos despues-. Y los tres dias NO LLEGO: el texto vivia en una
# variable de sesion, Nova reinicio entre medias las tres veces (20/09 12:08, 21/09 12:48,
# 22/09 07:44) y el dia ya estaba marcado en disco. Dia gastado en el disco, mensaje perdido
# en la memoria, tres de tres.
#
# LA HORA DE DORMIR (idea 10). Salio 4 veces y las CUATRO las desmiente su propio
# habitos.json: esas noches siguio 8, 84, 138 y 138 minutos mas. Su hora habitual de parar
# son las 00:24, y en 5 de los 7 dias con dato seguia despierto pasadas las 23:00. Es el
# unico aviso que se salta el silencio de la noche: lo unico que Nova decia de madrugada era
# algo que no era verdad.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
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
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre"; exit 1 }
    return $fn.Extent.Text
}

# --- dependencias: los habitos de mentira y los numeros del fichero real ---
$script:habitosFalsos = @{ fin = @{}; charlaHoras = @{}; presencia = @{} }
function Get-Habitos { return $script:habitosFalsos }
function Get-Cfg([string]$s, [string]$k, $d) { return $d }
$mND = [regex]::Match($fuente, '(?m)^\$EntornoNocheDesde = (.+)$')
Invoke-Expression ('$EntornoNocheDesde = ' + $(if ($mND.Success) { $mND.Groups[1].Value } else { '23' }))
Invoke-Expression (Traer 'Get-HoraFinHabitual')
Invoke-Expression (Traer 'Get-AvisoHoraDormir')

# SUS DATOS DE VERDAD: las noches del 15 al 21, con la hora a la que paro cada una
$script:habitosFalsos.fin = @{
    '2026-09-15' = '00:10'; '2026-09-16' = '23:38'; '2026-09-17' = '00:24'
    '2026-09-18' = '23:38'; '2026-09-19' = '00:24'; '2026-09-20' = '01:18'
}

Write-Host ''
Write-Host '-- las cuatro noches en que le dijo que no solia estar levantado --'
$hoy = [datetime]'2026-09-21 23:00:00'
Comp 'a las 23:00 ya NO se lo dice' ((Get-AvisoHoraDormir $hoy) -eq '') 'esa noche siguio 138 minutos mas'
$h2 = [datetime]'2026-09-21 23:30:00'
Comp 'ni a las 23:30' ((Get-AvisoHoraDormir $h2) -eq '')

Write-Host ''
Write-Host '-- pero si de verdad se pasa de su hora, lo dice --'
$h3 = [datetime]'2026-09-22 02:30:00'
$txt = Get-AvisoHoraDormir $h3
Comp 'a las 2:30 si habla' ($txt -ne '') $txt
Comp 'y dice a que hora suele parar' ($txt -match 'sueles parar sobre') 'con su dato, no con un reproche'
Comp 'y la hora que dice es la suya' ($txt -match '0:(1|2|3)\d') 'su mediana son las 00:24'

Write-Host ''
Write-Host '-- sin datos suficientes, se cae a lo de antes --'
$script:habitosFalsos.fin = @{ '2026-09-20' = '01:18' }     # un solo dia: menos de 4
$script:habitosFalsos.charlaHoras = @{}
$txt2 = Get-AvisoHoraDormir ([datetime]'2026-09-21 23:30:00')
Comp 'sigue avisando con el metodo viejo' ($txt2 -match 'no sueles estar levantado') $txt2
$script:habitosFalsos.charlaHoras = @{ '2026-09-18|23' = 1; '2026-09-19|23' = 1; '2026-09-20|23' = 1 }
Comp 'y calla si a esa hora suele hablar' ((Get-AvisoHoraDormir ([datetime]'2026-09-21 23:30:00')) -eq '')

Write-Host ''
Write-Host '-- el parte de la manana: sin nadie delante no se gasta --'
Comp 'la funcion distingue quien la llama' ($fuente -match 'function Test-ParteManana\(\[datetime\]\$ahora = \(Get-Date\), \[switch\]\$DesdeBucle\)') ''
Comp 'y el bucle es el unico que pasa el switch' (([regex]::Matches($fuente, 'Test-ParteManana -DesdeBucle')).Count -eq 1) 'en Process-Texto correria antes de Set-HabloAhora'
$blq = [regex]::Match($fuente, '(?s)if \(\$DesdeBucle\) \{.*?\n    \}').Value
Comp 'mira cuando se supo de braya por ultima vez' ($blq -match "presencia\['visto'\]") ''
Comp 'y si hace rato, se va SIN marcar el dia' ($blq -match 'return \}') 'se reintenta en la vuelta siguiente'

Write-Host ''
Write-Host '-- y el parte no se pierde si Nova reinicia --'
Comp 'el texto se guarda en disco' ($fuente -match '\$hbM\.parteTexto = \[string\]\$script:resumenPendiente') ''
Comp 'se recupera si no llego a decirse' ($fuente -match 'recuperado del disco, no habia llegado a decirse')
Comp 'y se borra del disco al decirlo' ($fuente -match "if \(\`$hbR\.parteTexto\) \{ \`$hbR\.parteTexto = ''; Save-Habitos \}") 'o lo repetiria en cada arranque'
Comp 'viaja en habitos.json' (($fuente -match "parteTexto = \[string\]\`$hb\.parteTexto") -and ($fuente -match "PSObject.Properties\['parteTexto'\]"))

Write-Host ''
Write-Host '-- LA VENTANA DEJO DE SER UNA HORA (24/09, idea 5 de la tanda nueva) --'
# El parte es el UNICO canal por el que Nova cuenta lo que ha decidido sola: su decision se
# aparco VEINTICUATRO veces ('SIN DATOS: lo dejo para el parte') y se dijo UNA vez en total,
# el 18/09, cuando el contador iba por '0 de 43'. Hoy va por 126.
#
# LA CAUSA: la ventana era 05:00-11:59 y braya no aparece por la manana casi la mitad de
# los dias. Primera senal suya de cada uno de los quince del registro: OCHO dentro y SIETE
# fuera (09/09 21:43, 12/09 13:57, 18/09 18:44, 20/09 12:52, 21/09 16:31, 23/09 21:08 y
# 24/09 15:56). Esos siete dias el parte no salia.
#
# LO QUE MAS SE VIGILA: que las DOS guardas que ya habia sigan enteras. Sin ellas, abrir la
# ventana convierte el parte en un aviso que sale a cualquier hora y a una casa vacia.
$tpm = (Traer 'Test-ParteManana')
$tpmSin = (($tpm -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'ya no se corta a las doce' ($tpmSin -notmatch 'ahora\.Hour -ge 12') 'siete de quince dias se quedaban sin parte'
Comp 'pero sigue sin salir antes de las cinco' ($tpmSin -match 'ahora\.Hour -lt 5') 'el dia empieza a las 5, como en Get-DiaJuego'
# GUARDA 1: una vez al dia y no mas.
Comp 'sigue saliendo una sola vez al dia' ($tpmSin -match 'parteVisto -eq \$hoyM') ''
# GUARDA 2: si braya no se ha dejado ver, el parte espera; no se gasta el dia.
Comp 'y espera a que braya este delante' ($tpmSin -match 'TotalMinutes -gt 30') 'no se gasta el dia con la casa vacia'
Comp 'y sale por la capsula, no por la voz' ($tpmSin -match '\$script:resumenPendiente') 'jugando no interrumpe'
# Y EL SALUDO SE ADAPTA: 'buenos dias' a las nueve de la noche es una tonteria.
Comp 'el saludo mira la hora' ($tpmSin -match "if \(\`$ahora\.Hour -lt 12\) \{ 'Buenos dias") ''
Comp 'y hay otra formula para el resto del dia' ($tpmSin -match "'Por cierto") ''
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  el parte espera a que estes, y la hora de dormir es la tuya'
exit 0
