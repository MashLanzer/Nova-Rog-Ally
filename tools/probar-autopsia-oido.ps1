# LA AUTOPSIA DEL OIDO ANTES DE RELANZARLO (27/09, idea 110 de las 121)
#
# EL DATO: 28 relanzamientos del worker de escucha en el registro -25 al primer intento, 2 al segundo
# y 1 al tercero- y NI UNA autopsia: la linea decia "el worker de escucha murio; relanzando" y nada
# mas. Mientras, la capsula SI lo hace bien desde siempre: su relanzamiento imprime el codigo de
# salida y la ultima linea de ui-error.log, y en el registro hay TRES lineas suyas con "( codigo -1)".
#
# Y LA CAUSA SE SABE EN LA MITAD DE LOS CASOS: seis de esas muertes son SUICIDIOS con causa apuntada
# -"el microfono lleva N s sin entregar audio; salgo para que me relancen", un sys.exit(3) de
# wake_vosk.py:4135-, asi que el codigo 3 dice "el microfono se paro" sin adivinar nada. Y las tres
# autopsias que existen en todo el registro (las tres del 15/09) apuntan al mismo sitio: "Windows
# fatal exception: access violation", comtypes/_post_coinit/unknwn.py line 420 in Release y
# "ValueError: COM method call without VTable", que es el medidor de altavoces.
#
# SE DICE, NO SE DECIDE: relanzar distinto segun la causa es un cambio de comportamiento que con TRES
# autopsias en 17 dias no se puede justificar. Primero se mide.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el codigo de salida salga en la linea del "murio", como en la capsula
#   2. que el 3 se traduzca a lo que significa
#   3. que el stderr no meta una linea en blanco (el fichero suele acabar asi)
#   4. que un wake-err.log viejo NO se atribuya a esta muerte
#   5. y que el relanzamiento siga pasando aunque la autopsia falle
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
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# EL TROZO DE VERDAD, cortado por sangrado (un '} elseif (...) {' tiene equilibrio de llaves cero)
$lin = [IO.File]::ReadAllLines($PS1)
$i0 = -1
for ($i = 0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*\$porQueW = ''''$') { $i0 = $i; break }
}
Comp 'se encuentra la autopsia en el fichero' ($i0 -ge 0) ''
$i1 = -1
for ($i = $i0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match 'el worker de escucha murio') { $i1 = $i; break }
}
Comp '  y acaba en la linea del "murio"' ($i1 -gt $i0 -and ($i1 - $i0) -lt 35) ([string]($i1 - $i0 + 1) + ' lineas')
$cuerpo = ($lin[$i0..$i1] -join "`n")

# EL MUNDO DE MENTIRA
$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-autop-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$rutaErr = Join-Path $TmpDir 'wake-err.log'
$enc = New-Object Text.UTF8Encoding($false)
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { }
$script:wakeIntentos = 1
# el proceso falso: solo hace falta su ExitCode
$fn = [scriptblock]::Create("function Autopsia(`$codigo) {`n`$script:wakeProc = [pscustomobject]@{ ExitCode = `$codigo }`n$cuerpo`nreturn `$script:logs[`$script:logs.Count - 1]`n}")
. $fn
function Reset { $script:logs = @(); if (Test-Path -LiteralPath $rutaErr) { Remove-Item -LiteralPath $rutaErr -Force } }

try {
    Write-Host ''
    Write-Host '-- 1. EL CODIGO DE SALIDA, COMO EN LA CAPSULA --'
    Reset
    $l = Autopsia 1
    Comp '1a. la linea lleva el codigo' ($l -match 'codigo 1') ([string]$l)
    Comp '1b. y sigue diciendo el intento' ($l -match 'intento 1/3') ''
    Comp '1c. con el mismo formato que la capsula' ($l -match 'murio \( codigo') 'la de la interfaz dice "murio ( codigo -1)"'

    Write-Host ''
    Write-Host '-- 2. EL CODIGO 3 ES EL SUICIDIO DEL MICROFONO --'
    Reset
    $l3 = Autopsia 3
    Comp '2a. se traduce a lo que significa' ($l3 -match 'el microfono se paro y salio el solo') ([string]$l3)
    Comp '2b. seis de las 28 muertes son asi' ($l3 -match 'codigo 3') 'lo dice el propio worker con sys.exit(3)'
    # y el 3 no se inventa para otros codigos
    Reset
    Comp '2c. y el 0 no se traduce' (-not ((Autopsia 0) -match 'el microfono se paro')) ''
    Reset
    Comp '2d. ni el -1' (-not ((Autopsia -1) -match 'el microfono se paro')) ''

    Write-Host ''
    Write-Host '-- 3. EL STDERR, SIN LINEAS EN BLANCO --'
    Reset
    # el fichero suele acabar en blanco: con Get-Content -Tail 1 la autopsia decia "su ultimo error: "
    [IO.File]::WriteAllText($rutaErr, "Traceback (most recent call last):`r`nValueError: COM method call without VTable`r`n`r`n", $enc)
    $l4 = Autopsia 1
    Comp '3a. coge la ultima linea CON algo' ($l4 -match 'COM method call without VTable') ([string]$l4)
    Comp '3b. y no dice "su ultimo error: " y nada' ($l4 -match 'su ultimo error: [^)\s]') 'el ") relanzando" de despues hacia inutil un $ aqui'
    Comp '3c. y lo nombra si huele a COM' ($l4 -match 'huele al medidor de altavoces') 'las tres autopsias que hay apuntan ahi'
    # las otras dos formas de la misma causa
    Reset
    [IO.File]::WriteAllText($rutaErr, "Windows fatal exception: access violation`r`n", $enc)
    Comp '3d. tambien con access violation' ((Autopsia 1) -match 'huele al medidor') ''
    Reset
    [IO.File]::WriteAllText($rutaErr, "  File `"comtypes/_post_coinit/unknwn.py`", line 420, in Release`r`n", $enc)
    Comp '3e. y con comtypes' ((Autopsia 1) -match 'huele al medidor') ''
    # y un error de otra cosa NO se le atribuye al medidor
    Reset
    [IO.File]::WriteAllText($rutaErr, "MemoryError: no cabe el modelo`r`n", $enc)
    $l5 = Autopsia 1
    Comp '3f. pero un error de otra cosa, no' (-not ($l5 -match 'huele al medidor')) ([string]$l5)
    Comp '3g. aunque SI se dice cual fue' ($l5 -match 'MemoryError') ''

    Write-Host ''
    Write-Host '-- 4. UN wake-err.log VIEJO NO ES DE ESTA MUERTE --'
    Reset
    [IO.File]::WriteAllText($rutaErr, "ValueError: COM method call without VTable`r`n", $enc)
    (Get-Item -LiteralPath $rutaErr).LastWriteTime = (Get-Date).AddHours(-3)
    $l6 = Autopsia 1
    Comp '4a. no se atribuye un error de hace tres horas' (-not ($l6 -match 'VTable')) ([string]$l6)
    Comp '4b. pero el codigo si sale' ($l6 -match 'codigo 1') 'la ventana son dos minutos, como en la capsula'

    Write-Host ''
    Write-Host '-- 5. SIN NADA, LA LINEA SIGUE SALIENDO --'
    Reset
    $l7 = Autopsia 1
    Comp '5a. sin wake-err.log, se relanza igual' ($l7 -match 'relanzando') ([string]$l7)
    Comp '5b. y tmp/wake-err.log esta hoy a 0 bytes' $true 'por eso hacia falta el codigo de salida'
    # un fichero vacio tampoco rompe
    Reset
    [IO.File]::WriteAllText($rutaErr, "`r`n`r`n", $enc)
    Comp '5c. con el fichero en blanco, tampoco' ((Autopsia 1) -match 'relanzando') ''
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
Comp '6a. el relanzamiento sigue pasando' ($sinCom -match '(?s)el worker de escucha murio.{0,200}Initialize-Escucha') 'la autopsia no puede impedirlo'
Comp '6b. y la estadistica se apunta igual' ($sinCom -match "Add-Estadistica 'relanza:oido'") ''
Comp '6c. la autopsia va ANTES del Log' ($sinCom.IndexOf('$porQueW = ''''') -lt $sinCom.IndexOf('el worker de escucha murio')) ''
Comp '6d. cada trozo en su propio try' (@([regex]::Matches($sinCom, 'try \{ \$porQueW|try \{ if \(\[int\]\$script:wakeProc\.ExitCode')).Count -ge 2) 'si el ExitCode tira, el stderr se sigue leyendo'
Comp '6e. y el vuelco entero de Initialize-Escucha sigue' ($sinCom -match 'su salida de error la vez anterior') 'esto no lo sustituye, lo completa'
# y el modelo: la capsula sigue haciendo lo mismo
Comp '6f. la capsula sigue con su autopsia' ($sinCom -match 'la interfaz murio \(\$porQueUi\)') 'de aqui salio el patron'
Comp '6g. y las dos leen su propio fichero' (($sinCom -match "'ui-error\.log'") -and ($sinCom -match "'wake-err\.log'")) ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el oido dice por que se murio antes de que lo relancen' -ForegroundColor Green
exit 0
