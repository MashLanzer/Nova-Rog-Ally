# D7: CREAR UNA CARPETA O UN ARCHIVO POR VOZ (21/09).
#
# El 20/09 braya lo pidio CUATRO veces y las cuatro se fueron al agente: para crear una
# carpeta eso es una grua para levantar un vaso, con sus segundos de espera y su llamada de
# pago. Aqui se prueban las dos mitades:
#
#   1. QUE SE ENTIENDA, con las formas naturales de decirlo (el nombre delante, detras, con
#      "que se llame", con "llamada"), y que NO se lleve por delante lo que ya significaba
#      otra cosa ("crea una nota" es apuntar, "crea el modo X" es un modo).
#   2. QUE SE CREE DE VERDAD, y que si no aparece Nova NO diga que si (B9). New-Item puede
#      no lanzar y aun asi no dejar nada: permisos, un antivirus, un disco lleno.
#
# EL DESTINO SE FALSEA: Find-CarpetaPorNombre se sustituye por una carpeta de usar y tirar en
# %TEMP%. Un banco no puede ir dejando carpetas en el escritorio de nadie, y ademas asi se
# puede comprobar el caso de "la carpeta destino no existe" sin romper nada.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Log($m) { $script:logs += $m }
$script:logs = @()
function Add-Estadistica($r, $d = '', $c = $false) { $script:apuntes += "$r|$d" }
$script:apuntes = @()

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# ---------------------------------------------------------------- 1) que se entienda
Write-Host ''
Write-Host '-- se entiende, dicho de las formas naturales --'
# se prueba con -Probar, que es el camino de verdad del banco de frases
$tmpF = Join-Path $env:TEMP ("crear-" + [guid]::NewGuid().ToString('N') + ".txt")
@(
    'crea una carpeta en el escritorio que se llame fotos',
    'crea una carpeta fotos en el escritorio',
    'hazme una carpeta llamada capturas en el escritorio',
    'crea una carpeta que se llame juegos',
    'crea un archivo en el escritorio que se llame notas',
    'creame una carpeta en documentos que se llame trabajo'
) | Out-File -FilePath $tmpF -Encoding utf8
$salida = & powershell -NoProfile -ExecutionPolicy Bypass -File $ruta -Probar $tmpF 2>&1 | Out-String
Remove-Item -LiteralPath $tmpF -Force -ErrorAction SilentlyContinue
$nOk = ([regex]::Matches($salida, '(?m)^\s*OK\s')).Count
Comp 'las seis formas se entienden en local' ($nOk -eq 6) "$nOk de 6"
Comp 'y el destino sale bien cuando se dice' ($salida -match 'crear la carpeta trabajo en el documentos')
Comp 'sin decir donde, el escritorio' ($salida -match 'crear la carpeta juegos en el escritorio')

Write-Host ''
Write-Host '-- y NO se lleva por delante lo que ya significaba otra cosa --'
$tmpG = Join-Path $env:TEMP ("crear2-" + [guid]::NewGuid().ToString('N') + ".txt")
@(
    'crea una nota que diga comprar pan',
    'hazme una captura',
    'crea una carpeta que se llame ../fuera',
    'crea una carpeta en el escritorio que se llame con barra/mala'
) | Out-File -FilePath $tmpG -Encoding utf8
$sal2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ruta -Probar $tmpG 2>&1 | Out-String
Remove-Item -LiteralPath $tmpG -Force -ErrorAction SilentlyContinue
# "crea una nota que diga X" es apuntar algo, no un fichero llamado "que diga X"
Comp 'una nota sigue sin ser un archivo' ($sal2 -notmatch 'crear el archivo que diga')
Comp 'y la captura sigue siendo una captura' ($sal2 -match 'captura de pantalla')
# UN NOMBRE NO PUEDE SER UNA RUTA: el nombre sale de lo que se OYO
Comp 'un nombre con .. no se acepta' ($sal2 -match '(?m)^\s*->IA\s+crea una carpeta que se llame \.\./fuera')
Comp 'un nombre con barra tampoco' ($sal2 -match '(?m)^\s*->IA\s+crea una carpeta en el escritorio que se llame con barra/mala')

# ---------------------------------------------------------------- 2) que se cree de verdad
Write-Host ''
Write-Host '-- y se crea DE VERDAD, en una carpeta de usar y tirar --'
$base = Join-Path $env:TEMP ("crear3-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $base | Out-Null
# el destino falseado: asi no se toca el escritorio de nadie
function Find-CarpetaPorNombre([string]$n) { if ($n -eq 'ninguna') { return '' } return $base }

# el ejecutor de 'crearAlgo', sacado del archivo de verdad (si cambia alli, cambia aqui)
$mE = [regex]::Match($fuente, "(?s)'crearAlgo' \{.*?\r?\n                \}")
if (-not $mE.Success) { Write-Host '  MAL  no encuentro la rama crearAlgo en assistant.ps1'; exit 1 }
$cuerpo = $mE.Value -replace "^'crearAlgo' \{", '' -replace '\}\s*$', ''
# 'break' solo vale dentro de un switch: se envuelve en uno de una sola rama
function Hacer($a) { $script:a = $a; switch ('x') { 'x' { Invoke-Expression $cuerpo } }; return $script:a.desc }

$a1 = @{ kind = 'crearAlgo'; carpeta = $true; nombre = 'fotos'; donde = 'escritorio'; desc = '' }
$d1 = Hacer $a1
Comp 'la carpeta existe despues' (Test-Path -LiteralPath (Join-Path $base 'fotos')) $d1
Comp 'y lo dice bien' ($d1 -match 'carpeta fotos creada')

$a2 = @{ kind = 'crearAlgo'; carpeta = $false; nombre = 'notas'; donde = 'escritorio'; desc = '' }
$d2 = Hacer $a2
Comp 'el archivo existe, y con .txt' (Test-Path -LiteralPath (Join-Path $base 'notas.txt')) $d2

# YA ESTABA: no se pisa. Crear encima de un archivo suyo seria borrarlo.
$antes = (Get-Item -LiteralPath (Join-Path $base 'notas.txt')).LastWriteTimeUtc
Start-Sleep -Milliseconds 20
$d3 = Hacer @{ kind = 'crearAlgo'; carpeta = $false; nombre = 'notas'; donde = 'escritorio'; desc = '' }
Comp 'si ya existe, lo dice y NO lo pisa' `
    (($d3 -match 'ya tienes') -and ((Get-Item -LiteralPath (Join-Path $base 'notas.txt')).LastWriteTimeUtc -eq $antes)) $d3

# y si la carpeta destino no existe, se dice, no se revienta
$d4 = Hacer @{ kind = 'crearAlgo'; carpeta = $true; nombre = 'loquesea'; donde = 'ninguna'; desc = '' }
Comp 'sin carpeta destino, lo dice' ($d4 -match 'no encuentro') $d4

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '-- y la comprobacion de que existe esta en el codigo (B9) --'
# lo que no puede pasar es que diga "creado" sin mirar: es la mentira de las carpetas del 20/09
Comp 'se comprueba con Test-Path despues de crear' ($fuente -match 'CREAR: dije que cree')
Comp 'y si no esta, se apunta como que no surtio efecto' ($fuente -match "Add-Estadistica 'no-surtio-efecto' " + [char]34 + "crearAlgo")

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host ''
Write-Host '  crear una carpeta o un archivo se entiende, se hace y se comprueba'
exit 0
