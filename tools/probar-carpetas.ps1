# CONTAR, MEDIR Y LISTAR LO QUE HAY EN SUS CARPETAS (23/09, idea 9). Solo lectura.
#
# EL DATO: 41 frases de este tema en su registro de catorce dias -"cuenta cuantos archivos
# hay en mi carpeta de descargas", "...de documentos"- y hoy NINGUNA se entendia en local:
# todas al agente.
# Y UN FALLO ACTIVO, verificado en el repositorio: "cuanto ocupa mi carpeta de descargas"
# caia en el patron de "cuanto ocupa <juego>" y Nova contestaba "no tengo ese juego en la
# biblioteca". Eso no es no entender: es contestar otra cosa.
#
# LO QUE MAS VIGILA ESTE BANCO: que medir una carpeta grande NO deje el juego tirando. braya
# juega casi siempre, y un recorrido sin tope sobre Descargas dentro del bucle es justo lo
# que no puede pasar. Por eso Get-ResumenCarpeta lleva tope de tiempo y de ficheros, y
# cuando se corta lo DICE.
$ErrorActionPreference = 'Stop'
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
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

Invoke-Expression (Traer 'Get-ResumenCarpeta')
Invoke-Expression (Traer 'Format-Gigas')
$CARPETAS_FIJAS = ''
foreach ($l in ($fuente -split "`r?`n")) {
    if ($l -match "^\`$CARPETAS_FIJAS = '(.+)'") { $CARPETAS_FIJAS = $Matches[1]; break }
}
if (-not $CARPETAS_FIJAS) { Write-Host '  MAL  no encuentro $CARPETAS_FIJAS'; exit 1 }

# --- una carpeta de mentira, con lo que hace falta --------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('carp-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
1..5 | ForEach-Object { [System.IO.File]::WriteAllText((Join-Path $tmp "f$_.txt"), ('a' * 1000)) }
$null = New-Item -ItemType Directory -Path (Join-Path $tmp 'dentro') -Force
1..3 | ForEach-Object { [System.IO.File]::WriteAllText((Join-Path $tmp "dentro\g$_.txt"), ('b' * 2000)) }
# desktop.ini lo pone Windows y no es suyo
[System.IO.File]::WriteAllText((Join-Path $tmp 'desktop.ini'), 'x')
# y un acceso directo, que se lee sin la extension
[System.IO.File]::WriteAllText((Join-Path $tmp 'Steam.lnk'), 'x')

Write-Host ''
Write-Host '-- 1. contar: el primer nivel, y nada mas --'
$r = Get-ResumenCarpeta $tmp
Comp 'se pudo mirar' ($r.ok) ''
Comp 'cinco ficheros y el acceso directo' ($r.ficheros -eq 6) "$($r.ficheros)"
Comp 'y una carpeta dentro' ($r.carpetas -eq 1) "$($r.carpetas)"
Comp 'desktop.ini no cuenta' (@($r.nombres) -notcontains 'desktop.ini') "$(@($r.nombres) -join ', ')"
Comp 'y el acceso directo se dice sin el .lnk' (@($r.nombres) -contains 'Steam') "$(@($r.nombres) -join ', ')"
Comp 'no cuenta lo de dentro de la subcarpeta' ($r.ficheros -eq 6) 'contar es del primer nivel'

Write-Host ''
Write-Host '-- 2. medir: eso SI baja hasta el fondo --'
$rm = Get-ResumenCarpeta $tmp $true
Comp 'suma los de dentro tambien' ($rm.bytes -ge 11000) "$($rm.bytes) bytes"
Comp 'y no se corto' (-not $rm.parcial) ''
Comp 'contar no mide (no cuesta lo que no hace falta)' ($r.bytes -eq 0) "$($r.bytes)"

Write-Host ''
Write-Host '-- 3. LO QUE NO PUEDE PASAR: dejar el juego tirando --'
# Con el tope a cero se fuerza el corte en la primera comprobacion.
# el tope de FICHEROS puesto a uno: con diez ficheros dentro tiene que cortarse ya
$rp = Get-ResumenCarpeta $tmp $true 60000 1
Comp 'con el tope puesto, se corta' ($rp.parcial) 'y no se queda ahi para siempre'
Comp 'y aun asi contesta' ($rp.ok) ''
$gc = SinComentarios (Traer 'Get-ResumenCarpeta')
Comp 'el tope de tiempo esta en la firma' ($gc -match '\$topeMs = \d+') ''
Comp 'y el de ficheros tambien' ($gc -match '\$topeFich = \d+') ''
Comp 'y no se llama a Get-TamanoMB, que no tiene tope' ($gc -notmatch 'Get-TamanoMB') ''

Write-Host ''
Write-Host '-- 4. una carpeta que no existe no devuelve ceros --'
$rn = Get-ResumenCarpeta (Join-Path $tmp 'no-existe-esto')
Comp 'dice que no' (-not $rn.ok) ''
Comp 'y con la ruta vacia, igual' (-not (Get-ResumenCarpeta '').ok) 'cero no es lo mismo que no se'

Write-Host ''
Write-Host '-- 5. las tres frases llegan a donde tienen que llegar --'
# Se sacan los patrones del fuente y se prueban con sus frases de verdad.
# LOS PATRONES SE SACAN POR UNA MARCA DE SU TEXTO, no por un ancla de final de linea: el
# fichero es CRLF y el $ de .NET deja el \r fuera, asi que el ancla no casaba nunca.
function Patron([string]$marca) {
    foreach ($l in ($fuente -split "`r?`n")) {
        if ($l -notmatch [regex]::Escape($marca)) { continue }
        $m = [regex]::Match($l, "'(\^[^']+)'")
        if ($m.Success) { return $m.Groups[1].Value }
    }
    Write-Host "  MAL  no encuentro el patron de '$marca'"
    exit 1
}
$patL = Patron 'ensename|muestrame|lista(?:me)?'
$patC = Patron 'canciones|cosas|elementos'
$patM = Patron 'ocupa|pesa|mide'
Comp 'su frase de contar entra' ('cuenta cuantos archivos hay en mi carpeta de descargas' -match $patC) ''
Comp 'y la de documentos' ('cuantos archivos hay en mi carpeta de documentos' -match $patC) ''
Comp 'y la de medir' ('cuanto ocupa mi carpeta de descargas' -match $patM) 'antes contestaba que no tenia ese juego'
Comp 'y la de listar' ('que hay en mi carpeta de documentos' -match $patL) ''

Write-Host ''
Write-Host '-- 6. sin decir "carpeta", solo las siete de siempre (regla 7) --'
$fijas = $CARPETAS_FIJAS -split '\|'
Comp 'la lista cerrada tiene siete' ($fijas.Count -eq 7) "$($fijas.Count): $CARPETAS_FIJAS"
$lineaFija = @($fuente -split "`r?`n" | Where-Object { $_ -match 'cuantos\|cuantas' -and $_ -match 'CARPETAS_FIJAS' })[0]
if (-not $lineaFija) { Write-Host '  MAL  no encuentro el patron de la lista cerrada'; exit 1 }
$mFija = [regex]::Match($lineaFija, "\('(\^[^']+)' \+ \`$CARPETAS_FIJAS \+ '([^']*)'\)")
if (-not $mFija.Success) { Write-Host '  MAL  no se leer el patron de la lista cerrada'; exit 1 }
$reFijo = $mFija.Groups[1].Value + $CARPETAS_FIJAS + $mFija.Groups[2].Value
Comp 'el patron sin "carpeta" usa la lista cerrada' ($null -ne $lineaFija) 'nada de nombres libres mal oidos'
Comp '"cuantos archivos hay en descargas" entra' ('cuantos archivos hay en descargas' -match $reFijo) ''
Comp 'pero "cuantos archivos hay en la nave" NO' ('cuantos archivos hay en la nave' -notmatch $reFijo) 'sin la palabra carpeta, solo las siete'

Write-Host ''
Write-Host '-- 7. y no se toca nada: esto solo lee --'
Comp 'ni borra' ($gc -notmatch 'Remove-Item|Delete\(') ''
Comp 'ni mueve' ($gc -notmatch 'Move-Item|MoveTo') ''
Comp 'ni escribe' ($gc -notmatch 'Set-Content|WriteAll|Out-File') ''
$antes = @(Get-ChildItem -LiteralPath $tmp -Force).Count
[void](Get-ResumenCarpeta $tmp $true)
Comp 'y la carpeta sigue igual despues de medirla' (@(Get-ChildItem -LiteralPath $tmp -Force).Count -eq $antes) "$antes"

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya cuenta y mide sus carpetas sin salir de casa'
exit 0
