# MONTAJES CON NOMBRE (23/09, funcion 3 de la tanda de funciones nuevas).
#
# Es lo que mas ha pedido braya y lo unico que nunca consiguio: el propio codigo lo tiene
# contado -en catorce dias la pantalla dividida no se ejecuto bien ni una vez por voz, cero de
# once intentos-. YouTube en una mitad y Pinterest en la otra sale en ocho momentos distintos
# del registro, y el 18/09 a las 20:04 se quejo por voz: "solo abriste Pinterest, nunca
# abriste YouTube ni dividiste la pantalla a la mitad". Su perfil dice para que le sirve:
# quiere recrear una foto con su pareja -las referencias en Pinterest, el tutorial en YouTube-.
#
# Hoy hay cinco patrones peleandose por adivinar COMO lo dice. Con un nombre no hay nada que
# adivinar: "guarda esto como el tablero" y luego "pon el tablero".
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('mont-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
function Log($m) { }
Invoke-Expression (Traer 'ConvertTo-Plain')
$MontajesPath = Join-Path $MemoriaDir 'montajes.json'
Invoke-Expression (Traer 'Get-Montajes')
Invoke-Expression (Traer 'Save-Montajes')

Write-Host ''
Write-Host '-- se guardan y sobreviven al reinicio --'
Comp 'al principio no hay ninguno' ((Get-Montajes).Count -eq 0)
$m = Get-Montajes
$m['el tablero'] = @{ izq = 'https://www.pinterest.com'; der = 'https://www.youtube.com'
                      izqTipo = 'url'; derTipo = 'url'; cuando = (Get-Date).ToString('s') }
Save-Montajes
Comp 'se guarda en disco' (Test-Path -LiteralPath $MontajesPath)
$script:montajes = $null          # como si Nova hubiera reiniciado
$vuelto = Get-Montajes
Comp 'y se lee igual tras "reiniciar"' ($vuelto.ContainsKey('el tablero')) "$($vuelto.Count) montaje(s)"
Comp 'con los dos lados' ($vuelto['el tablero'].izq -match 'pinterest' -and $vuelto['el tablero'].der -match 'youtube') "$($vuelto['el tablero'].izq) | $($vuelto['el tablero'].der)"
Comp 'y con su tipo, para saber si abrir url o app' ($vuelto['el tablero'].izqTipo -eq 'url')

Write-Host ''
Write-Host '-- se guarda lo RESUELTO, no lo que se oyo --'
# Esto es lo que lo salva: el montaje sale de los destinos que Resolve-Target ya convirtio en
# url o ejecutable, no de mirar la pantalla ni de adivinar lo que dijo. Asi guarda
# "https://www.pinterest.com a la izquierda" y no "dos ventanas de Edge".
Comp 'el dividir bueno se recuerda' ($fuente -match '\$script:ultimoDividir = @\{') ''
# el bloque del else, contando llaves desde la linea del if: con una ventana de N caracteres
# se mide el comentario de en medio y sale rojo con el codigo bien.
$iC = $fuente.IndexOf('if ($colocadas -lt 2)')
$elseC = if ($iC -ge 0) { $fuente.IndexOf('else {', $iC) } else { -1 }
$finC = if ($elseC -ge 0) { $fuente.IndexOf('ultimoDividir', $elseC) } else { -1 }
Comp 'y solo si se colocaron LAS DOS' ($elseC -gt $iC -and $finC -gt $elseC -and ($finC - $elseC) -lt 700) 'medio montaje no vale para guardarlo'
Comp 'guarda la url o el ejecutable, no el texto' ($fuente -match "(?s)ultimoDividir = @\{.{0,200}\`$a\.izq\.url.{0,80}\`$a\.izq\.target") ''

Write-Host ''
Write-Host '-- al montar, se reusa lo que ya esta abierto --'
# "dividir" siempre hace Start-Process: si el navegador ya estaba abierto, te abre OTRO.
Comp 'existe abrir-o-enfocar' ($fuente -match 'function Show-OAbrir') ''
Comp 'busca el proceso antes de lanzarlo' ($fuente -match '(?s)function Show-OAbrir.{0,700}Get-Process -Name \$nom') ''
Comp 'y lo trae al frente si estaba' ($fuente -match '(?s)function Show-OAbrir.{0,900}ForceForeground') ''
Comp 'solo abre si no habia ninguno' ($fuente -match '(?s)function Show-OAbrir.{0,1200}Start-Process') ''
Comp 'el montaje lo usa' ($fuente -match "(?s)'montajePon'.{0,900}Show-OAbrir") ''

Write-Host ''
Write-Host '-- las cuatro ordenes --'
foreach ($par in @(@('montajeGuarda', 'guardar'), @('montajePon', 'poner'),
                   @('montajesLista', 'listar'), @('montajeBorra', 'borrar'))) {
    Comp ("existe la de " + $par[1]) ($fuente -match ("'" + $par[0] + "'")) ''
}
Comp 'y decir el nombre a secas tambien monta' ($fuente -match "Get-Montajes\)\.ContainsKey\(\(ConvertTo-Plain \`$Matches\[1\]\)\)") '"pon el tablero" sin decir "montaje"'

Write-Host ''
Write-Host '-- y no es un modo --'
Comp 'no enciende nada que haya que apagar' (-not ($fuente -match "(?s)'montajePon'.{0,1500}\`$script:modo")) ''
Comp 'y se puede borrar lo guardado' ($fuente -match "(?s)'montajeBorra'.{0,300}Remove\(") ''

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  guardas una colocacion con su nombre y la vuelves a montar'
exit 0
