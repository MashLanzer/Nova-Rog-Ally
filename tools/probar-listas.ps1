# Listas de verdad: que se añada, se lea, se tache y se vacíe, y que el archivo
# sobreviva a todo eso. Las funciones se sacan DEL ARCHIVO REAL, como en las
# demás pruebas. No toca tus listas: usa una carpeta temporal.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'ConvertTo-Plain')
Invoke-Expression (TraerFn 'Get-Listas')
Invoke-Expression (TraerFn 'Save-Listas')
Invoke-Expression (TraerFn 'Resolve-Lista')
Invoke-Expression (TraerFn 'Format-Lista')

# --- mundo de mentira ---
$MemoriaDir = Join-Path $env:TEMP ('listas-prueba-' + [guid]::NewGuid().ToString('N'))
$RutaListas = Join-Path $MemoriaDir 'listas.json'
New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null
function Log([string]$t) { }
function Save-Corrupto($ruta) { }

$fallos = 0
function Ok([string]$etiqueta, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "--- la lista se llena, se lee y se vacia ---"

Ok 'sin archivo, no hay listas' ((Get-Listas).Keys.Count -eq 0)

# se apunta una cosa en la de la compra
$l = Get-Listas
$cual = Resolve-Lista 'la compra' $l
Ok 'la compra se llama compra' ($cual -eq 'compra') "-> $cual"
$l[$cual] = @('pan')
Ok 'se guarda' (Save-Listas $l)

# y se vuelve a leer del disco, que es lo que de verdad importa
$l2 = Get-Listas
Ok 'sobrevive al disco' (@($l2['compra']).Count -eq 1 -and $l2['compra'][0] -eq 'pan') "-> $($l2['compra'] -join ',')"

# "la lista" a secas, con una sola, es esa
Ok '"la lista" con una sola es esa' ((Resolve-Lista '' $l2) -eq 'compra')

# dos listas: "la lista" a secas se va a la de la compra
$l2['regalos'] = @('cargador')
$null = Save-Listas $l2
$l3 = Get-Listas
Ok 'con dos, "la lista" es la de la compra' ((Resolve-Lista '' $l3) -eq 'compra')
Ok 'y se puede pedir la otra por su nombre' ((Resolve-Lista 'regalos' $l3) -eq 'regalos')
Ok 'con articulo delante tambien' ((Resolve-Lista 'los regalos' $l3) -eq 'regalos')

# como se dice en voz alta
$l3['compra'] = @('pan', 'leche', 'huevos')
$null = Save-Listas $l3
$dicho = Format-Lista 'compra' (Get-Listas)['compra']
Ok 'se lee con cuantas son' ($dicho -match '3 cosas' -and $dicho -match 'pan, leche, huevos') "-> $dicho"
Ok 'una sola se dice en singular' ((Format-Lista 'regalos' @('cargador')) -match '1 cosa')
Ok 'y vacia se dice vacia' ((Format-Lista 'compra' @()) -match 'esta vacia')

# los acentos y las mayusculas no crean listas nuevas
$l4 = Get-Listas
$l4['compra'] = @('Pan de molde')
$null = Save-Listas $l4
Ok 'acentos y mayusculas no duplican lista' ((Resolve-Lista 'COMPRA' (Get-Listas)) -eq 'compra')

# un archivo corrupto no revienta ni borra nada: devuelve vacio y ya
[System.IO.File]::WriteAllText($RutaListas, 'esto no es json', (New-Object System.Text.UTF8Encoding($false)))
Ok 'con el archivo roto, no revienta' ((Get-Listas).Keys.Count -eq 0)

Remove-Item $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
