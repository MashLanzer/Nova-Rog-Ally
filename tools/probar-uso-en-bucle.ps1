# QUE UNA SOLA ORDEN NO ESCRIBA TREINTA Y NUEVE DESTINOS (1/10, idea 3 de las 20 nuevas)
#
# LO QUE PASO: el 18/09 el id 20260918-233533 -"Este estado es cargando en Steam"- escribio
# TREINTA Y NUEVE lineas de destino en 92 segundos, alternando 'charla' y 'traducir' dos veces por
# segundo. Y otro escribio 31. Algo entro en bucle.
#
# Y LO PEOR NO FUE EL ESPACIO: esas dos son las que hacian creer que braya repetia las ordenes. Con
# ellas dentro, el corpus dice que el 26,1 % de las ordenes se repiten en menos de un minuto, y no
# es verdad: era el bucle contandose a si mismo. Un dato asi manda a buscar un fallo que no existe,
# y eso cuesta mas que no tener el dato.
#
# EL NUMERO SALE DE MEDIR: de los 375 ids guardados, el 78,9 % tiene UNA linea, el 98,9 % tiene
# cuatro o menos, y lo mas alto legitimo son 7 y 9. El salto siguiente son 31 y 39.
#
# ESTE BANCO EJECUTA Write-DestinoUso DE VERDAD sobre una carpeta de pega y cuenta las lineas que
# salen. Comprobar la forma del codigo aqui no serviria: lo que importa es cuantas lineas acaban en
# el fichero.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}

# --- las listas y constantes, con los mismos valores que el fichero ---
$DestinosUso = @('local', 'aprendida', 'firma', 'memoria', 'traducida', 'receta', 'error', 'descarte', 'ruido', 'recitado')
$DestinosNeutros = @('charla', 'traducir', 'plan', 'accion', 'pregunta')
$DestinosSecos = @('descarte', 'ruido', 'error', 'recitado')
$DestinosFallo = @('descarte', 'ruido', 'error')
$UsoIdFrescoMin = 5
$UsoDestinosMax = 12
$RE_REFERENCIA = @{}
foreach ($n in @('Write-DestinoUso', 'Test-MarcaUsoVieja')) { Invoke-Expression (Traer $n) }
function ConvertTo-Plain([string]$t) { return ([string]$t).ToLowerInvariant() }
$script:apuntado = @()
function Add-Estadistica([string]$k, [string]$v = '') { $script:apuntado += "$k=$v" }
$script:log = @()
function Log([string]$m) { $script:log += $m }
function Write-FalloDeducido([string]$a = '', [string]$b = '', [string]$c = '') { return $true }
$script:ultimaOrden = $null
$script:ultimaSeca = $false
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { 0 }

# LA CARPETA DE PEGA: con su tmp y su pruebas\audio\uso, que es lo que la funcion mira
$base = Join-Path ([IO.Path]::GetTempPath()) ('nova-bucle-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$TmpDir = Join-Path $base 'tmp'
$LogDir = $base
$dirUso = Join-Path $base 'pruebas\audio\uso'
New-Item -ItemType Directory -Force -Path $TmpDir, $dirUso | Out-Null
$ficheroUso = Join-Path $dirUso 'destinos.jsonl'
$marca = Join-Path $TmpDir 'dictado-id.txt'

function Lineas { if (Test-Path -LiteralPath $ficheroUso) { return @([IO.File]::ReadAllLines($ficheroUso)).Count } ; return 0 }
function Reset([string]$id) {
    Remove-Item -LiteralPath $ficheroUso -Force -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText($marca, $id)
    $script:usoLineasId = ''; $script:usoLineas = 0
    $script:apuntado = @(); $script:log = @()
}
# el id SIEMPRE de ahora, para que la caducidad de la idea 2 no se meta en medio
$idAhora = (Get-Date).ToString('yyyyMMdd-HHmmss')

try {
    Write-Host ''
    Write-Host '-- 1. lo normal pasa sin tocarlo --'
    # el 98,9 % de las ordenes escriben cuatro lineas o menos
    Reset $idAhora
    foreach ($i in 1..4) { [void](Write-DestinoUso 'charla' "frase $i") }
    Comp 'cuatro destinos se escriben los cuatro' ((Lineas) -eq 4) "$(Lineas)"
    Comp '  y no se queja de nada' ($script:apuntado.Count -eq 0 -and $script:log.Count -eq 0) "$($script:log -join ' | ')"
    # y los 9 del caso legitimo mas alto que hay en el corpus
    Reset $idAhora
    foreach ($i in 1..9) { [void](Write-DestinoUso 'charla' "frase $i") }
    Comp 'y los NUEVE del caso legitimo mas alto, tambien' ((Lineas) -eq 9) "$(Lineas)"
    Comp '  sin una palabra' ($script:log.Count -eq 0) ''

    Write-Host ''
    Write-Host '-- 2. el bucle se corta en seco --'
    Reset $idAhora
    # las 39 de verdad, tal como pasaron: 'charla' y 'traducir' alternando
    foreach ($i in 1..39) { [void](Write-DestinoUso $(if ($i % 2) { 'charla' } else { 'traducir' }) 'Este estado es cargando en Steam') }
    Comp "de 39 intentos solo se escriben $UsoDestinosMax" ((Lineas) -eq $UsoDestinosMax) "$(Lineas)"
    Comp '  y lo dice, UNA vez y no 27' (@($script:log | Where-Object { $_ -match 'en bucle' }).Count -eq 1) "$($script:log.Count) lineas de registro"
    Comp '  con el id dentro, para poder buscarlo' (@($script:log | Where-Object { $_ -match [regex]::Escape($idAhora) }).Count -eq 1) ''
    Comp '  y lo apunta para poder contarlo' (@($script:apuntado | Where-Object { $_ -match '^uso-orden-en-bucle=' }).Count -eq 1) "$($script:apuntado -join ' | ')"

    Write-Host ''
    Write-Host '-- 3. la cuenta es POR ORDEN, no global --'
    # Si fuera global, la orden siguiente nacería con el tope ya gastado y no se apuntaria nunca mas.
    # Esto es lo que hace que el freno no se convierta en una mordaza.
    # LOS DOS IDS, DISTINTOS A LA FUERZA. Primer intento de esta linea: puse AddSeconds(-1) y los
    # dos ids salieron IGUALES, porque entre la primera linea del banco y esta ya habia pasado un
    # segundo de reloj. El banco se puso rojo acusando al codigo de un fallo que era mio.
    $idOtro = (Get-Date).AddMinutes(-2).ToString('yyyyMMdd-HHmmss')
    if ($idOtro -eq $idAhora) { Comp 'los dos ids de prueba son distintos' $false 'el banco no puede probar esto' }
    [IO.File]::WriteAllText($marca, $idOtro)
    $script:log = @()
    foreach ($i in 1..3) { [void](Write-DestinoUso 'charla' 'otra orden distinta') }
    Comp 'la orden siguiente escribe con normalidad' ((Lineas) -eq ($UsoDestinosMax + 3)) "$(Lineas) en total"
    Comp '  y no se queja de ella' ($script:log.Count -eq 0) "$($script:log -join ' | ')"
    # Y AL VOLVER a la primera, el tope sigue puesto para ella... o se reinicia, pero lo que NO
    # puede pasar es que la cuenta de una orden se le pegue a otra: eso ya se ha comprobado arriba.

    Write-Host ''
    Write-Host '-- 4. y el freno NO se traga la primera linea de una orden --'
    # Un freno que empieza contando mal dejaria ordenes enteras sin destino, que es peor que el
    # fallo original: sin destino, una orden no cuenta ni como acierto ni como fallo.
    Reset $idAhora
    Comp 'la PRIMERA linea de una orden se escribe siempre' ([bool](Write-DestinoUso 'local' 'abre steam') -and (Lineas) -eq 1) "$(Lineas)"
} finally {
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 5. el cableado --'
$cuerpo = Traer 'Write-DestinoUso'
$sin = (($cuerpo -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$iFreno = $sin.IndexOf('$script:usoLineas -ge $UsoDestinosMax')
$iEscribe = $sin.IndexOf('AppendAllText')
Comp 'el freno esta dentro de Write-DestinoUso' ($iFreno -ge 0) ''
Comp '  y ANTES de escribir' ($iFreno -ge 0 -and $iEscribe -ge 0 -and $iFreno -lt $iEscribe) "freno en $iFreno, escribe en $iEscribe"
# LA CUENTA SUBE DESPUES DE ESCRIBIR, no antes: si subiera antes, el liston seria "doce intentos"
$iSube = $sin.IndexOf('$script:usoLineas++', $iEscribe)
Comp '  y la cuenta sube DESPUES de escribir' ($iEscribe -ge 0 -and $iSube -gt $iEscribe) 'si no, el liston serian intentos y no lineas'
$txt = [IO.File]::ReadAllText($PS1)
Comp 'el tope sale de config.json' ($txt -match "Get-Cfg 'uso' 'destinosMax'") ''
# Y EL NUMERO ESTA DEFENDIDO CON LA MEDICION, no elegido a dedo
Comp '  y el motivo del numero esta escrito al lado' ($txt -match '98,9 % tiene cuatro o menos') 'de donde sale el 12'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'una sola orden ya no puede llenar el corpus' -ForegroundColor Green
exit 0
