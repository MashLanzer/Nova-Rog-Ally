# LO QUE DICE OTRA PERSONA NO SE ESCRIBE EN EL REGISTRO (27/09, idea 90 de las 121)
#
# EL DATO: con la voz ajena Nova ya hacia lo correcto TRES veces -no guarda el wav, no lo manda
# al agente y no aprende nada- y acto seguido la escribia ENTERA. ONCE lineas de conversacion de
# otra persona guardadas literal entre assistant.log y assistant.log.1, 689 caracteres, la mas
# larga de 174 ("Te te enamarito, creo que tu puedes convencerlo, ese no es mi problema").
#
# Y ERAN TRES SITIOS, no uno como decia la ficha: el registro, la lista de descartes -que sale
# escrita en memoria\estadisticas.md, que braya lee- y el registro de uso por Write-DestinoUso.
# Los tres salen del MISMO $text, asi que se tapan con una sola decision.
#
# Y NO ES UNA DECISION, ES UN OLVIDO: la misma deteccion salta 14 veces mas en el lado del oido
# (wake_vosk.py: "uso: no lo guardo, esa voz no es la tuya") y ahi SI se calla.
#
# COMO SE PRUEBA: el bloque de verdad se saca del fichero y se EJECUTA con dobles de Log,
# Add-Estadistica y Set-UI. No se reimplementa nada.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que con voz ajena el texto NO salga por ninguno de los tres sitios
#   2. que SI salga cuantas palabras y cuantos caracteres eran, que es lo que hace falta medir
#   3. que el contador del dia siga subiendo (si no, se perderia la medida)
#   4. y el caso contrario, que es el que evita pasarse de celoso: con la voz de braya el texto
#      se sigue escribiendo entero, porque ahi es lo unico que explica el descarte
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')

# EL BLOQUE DE VERDAD, SACADO DEL FICHERO. No esta en una funcion propia -vive dentro de
# Process-Texto, que tiene miles de lineas-, asi que se corta por llaves desde su 'if' y se
# ejecuta tal cual. Con tope de tamano: si un dia el bloque crece de golpe es que el corte casó
# donde no debia, y eso es lo que un dia movio 14.000 lineas de sitio.
$lineas = [IO.File]::ReadAllLines($PS1)
$ini = -1
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($lineas[$i] -match '^\s*if \(\$esCharla -or \$esAjena\) \{') { $ini = $i; break }
}
Comp 'se encuentra el bloque que descarta' ($ini -ge 0) ''
$prof = 0; $fin = -1
for ($i = $ini; $i -lt $lineas.Count; $i++) {
    $sinCad = ($lineas[$i] -replace "'[^']*'", "''") -replace '"[^"]*"', '""'
    $sinCad = ($sinCad -split '#')[0]
    $prof += @([regex]::Matches($sinCad, '\{')).Count - @([regex]::Matches($sinCad, '\}')).Count
    if ($prof -le 0) { $fin = $i; break }
}
Comp '  y se sabe donde acaba' ($fin -gt $ini) ([string]($fin - $ini + 1) + ' lineas')
Comp '  con un tamano razonable' (($fin - $ini) -lt 45) 'si crece de golpe, el corte caso donde no debia'
$cuerpo = ($lineas[$ini..$fin] -join "`n")
Comp '  y lleva las dos escrituras dentro' (($cuerpo -match 'Log ') -and ($cuerpo -match 'Add-Estadistica')) ''

# EL MUNDO DE MENTIRA, DESPUES de cortar el bloque
$script:logs = @()
$script:stats = @()
$script:ui = ''
function Log([string]$msg) { $script:logs += @($msg) }
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) {
    $script:stats += @{ ruta = $ruta; detalle = $detalle }
}
function Set-UI([string]$e, [string]$t = '', [int]$ms = 0) { $script:ui = $e }
$script:seguimientoPendiente = $true

# el bloque hace 'return', asi que se envuelve en una funcion para que el return sea el suyo
$correr = [scriptblock]::Create("function Correr(`$esCharla, `$esAjena, `$text, `$palabras) {`n$cuerpo`n}")
. $correr
function Reset { $script:logs = @(); $script:stats = @(); $script:ui = ''; $script:seguimientoPendiente = $true }

# la frase de verdad del 13/09 a las 16:18, la mas larga de las once
$AJENA = 'Te te enamarito, creo que tu puedes convencerlo, ese no es mi problema, es que no quiero que se enoje conmigo, pero tampoco quiero que se vaya de la casa'
$PAL = @($AJENA -split '\s+' | Where-Object { $_ -ne '' })

Write-Host ''
Write-Host '-- 1. LA VOZ AJENA: NI UNA PALABRA DE LO QUE DIJO --'
Reset
Correr $false $true $AJENA $PAL
Comp '1a. se apunta que paso' ($script:logs.Count -eq 1) ([string]$script:logs.Count + ' linea(s)')
Comp '1b. y dice que no era su voz' ($script:logs[0] -match 'voz que no es la tuya') $script:logs[0]
# LO QUE DE VERDAD IMPORTA: ni un trozo del texto. Se comprueban varios trozos, no la frase
# entera: con un solo -notmatch de la frase completa, recortarla a la mitad saldria verde.
$trozos = @('enamarito', 'convencerlo', 'no quiero que se enoje', 'se vaya de la casa', 'mi problema')
$fugas = @($trozos | Where-Object { $script:logs[0] -match [regex]::Escape($_) })
Comp '1c. y NO sale ni un trozo de lo que dijo' ($fugas.Count -eq 0) ([string]$fugas.Count + ' fuga(s): ' + ($fugas -join ', '))
Comp '1d. pero si cuantas palabras eran' ($script:logs[0] -match ([string]$PAL.Count + ' palabras')) ([string]$PAL.Count + ' palabras')
Comp '1e. y cuantos caracteres' ($script:logs[0] -match ([string]$AJENA.Length + ' caracteres')) ([string]$AJENA.Length + ' caracteres')
Comp '1f. la linea entera es corta' ($script:logs[0].Length -lt 100) ([string]$script:logs[0].Length + ' caracteres de registro para ' + [string]$AJENA.Length + ' de conversacion')

Write-Host ''
Write-Host '-- 2. NI EN LA LISTA QUE SALE EN estadisticas.md --'
Comp '2a. el descarte se cuenta' (@($script:stats | Where-Object { $_.ruta -eq 'descarte' }).Count -eq 1) 'el contador del dia tiene que seguir subiendo'
$detA = [string](@($script:stats | Where-Object { $_.ruta -eq 'descarte' })[0].detalle)
Comp '2b. y va SIN detalle' ([string]::IsNullOrEmpty($detA)) ("detalle: '" + $detA + "'")
Comp '2c. asi no entra en la lista de descartes' (-not ($detA -match 'enamarito')) 'esa lista se escribe en memoria\estadisticas.md'
Comp '2d. ni en el registro de uso' (-not ($detA -match 'convencerlo')) 'Write-DestinoUso escribe el mismo detalle'

Write-Host ''
Write-Host '-- 3. Y CON SU VOZ NO CAMBIA NADA (el caso que evita pasarse de celoso) --'
Reset
$SUYA = 'pero lo estas repitiendo, te estas disculpando y no estas abriendo Steam'
Correr $true $false $SUYA @($SUYA -split '\s+')
Comp '3a. se apunta' ($script:logs.Count -eq 1) ''
Comp '3b. y dice que era charla' ($script:logs[0] -match 'charla') $script:logs[0]
Comp '3c. CON el texto entero' ($script:logs[0] -match [regex]::Escape($SUYA)) 'es de braya y es lo que explica el descarte'
$detS = [string](@($script:stats | Where-Object { $_.ruta -eq 'descarte' })[0].detalle)
Comp '3d. y con detalle para la lista' ($detS -eq $SUYA) ''

Write-Host ''
Write-Host '-- 4. Y LAS DOS COSAS QUE YA HACIA BIEN SIGUEN IGUAL --'
Reset
Correr $false $true $AJENA $PAL
Comp '4a. no encadena un seguimiento' (-not $script:seguimientoPendiente) 'una voz ajena no abre conversacion'
Comp '4b. y la capsula vuelve al reposo, callada' ($script:ui -eq 'reposo') 'ni "no te entendi" ni nada'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '4c. y sigue sin llegar al agente' (-not ($cuerpo -match 'Submit-Command')) ''

Write-Host ''
Write-Host '-- 5. EL OTRO LADO, EL DEL OIDO, QUE YA SE CALLABA --'
$py = Join-Path $Raiz 'wake_vosk.py'
$tpy = [IO.File]::ReadAllText($py)
Comp '5a. el oido no guarda el audio de otra voz' ($tpy -match 'no lo guardo, esa voz no es la tuya') 'de aqui sale el criterio'
$lineaPy = @($tpy -split "`n" | Where-Object { $_ -match 'no lo guardo, esa voz no es la tuya' })[0]
Comp '5b. y ahi tampoco escribe el texto' (-not ($lineaPy -match 'texto|frase|\{t\}')) $lineaPy.Trim()

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'lo que dice otra persona ya no se escribe en ningun sitio' -ForegroundColor Green
exit 0
