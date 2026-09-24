# "No era eso" contra el ruido: la lista de frases que ya te molestaron una vez.
# Lo que importa de esto es que se cure sola. Una frase vetada para siempre por
# una vez que cambiaste de idea sería peor que el problema que arregla, así que
# se comprueba que decir "sí" la retire.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Log($m) { }
$MemoriaDir = Join-Path $env:TEMP ("rech-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $MemoriaDir | Out-Null
$RechazosPath = Join-Path $MemoriaDir 'rechazos.json'
$script:rechazos = $null

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Rechazos')
Invoke-Expression (Traer 'Save-Rechazos')
Invoke-Expression (Traer 'Write-Atomico')
Invoke-Expression (Traer 'Add-Rechazo')
Invoke-Expression (Traer 'Remove-Rechazo')
Invoke-Expression (Traer 'Test-Rechazada')
Invoke-Expression (Traer 'Invoke-AprenderDelError')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Comp 'al principio no hay nada' (-not (Test-Rechazada 'abre steam')) ''
Comp 'se apunta una frase' (Add-Rechazo 'Abre Steam') ''
Comp 'y se reconoce igual sin tildes ni mayusculas' (Test-Rechazada 'abre steam') ''
Comp 'otra frase no queda vetada' (-not (Test-Rechazada 'abre spotify')) ''
Comp 'una palabra suelta no se apunta' (-not (Add-Rechazo 'steam')) 'vetaria media lista'

# se cuenta cuantas veces
$null = Add-Rechazo 'abre steam'
Comp 'lleva la cuenta' ((Get-Rechazos)['abre steam'] -eq 2) ("van " + (Get-Rechazos)['abre steam'])

# sobrevive a releer el archivo (es lo que pasa al reiniciar)
$script:rechazos = $null
Comp 'sobrevive al reinicio' (Test-Rechazada 'abre steam') ''

# y se cura: decir que si la retira
Comp 'decir que si la retira' (Remove-Rechazo 'abre steam') ''
Comp 'y ya no pregunta mas' (-not (Test-Rechazada 'abre steam')) ''
$script:rechazos = $null
Comp 'tambien despues de reiniciar' (-not (Test-Rechazada 'abre steam')) ''
Comp 'retirar una que no esta dice que no' (-not (Remove-Rechazo 'abre lo que sea')) ''


# --- APRENDER DEL "DESHAZ" SIN QUE SE LO EXPLIQUES (17/09) ---
# Deshacer algo que acaba de pasar es decir que estuvo mal. Pero SOLO cuenta si la orden
# venia de algo dudoso: deshacer una orden limpia por cambiar de idea no es un error suyo, y
# apuntarla haria que Nova dejase de entender una orden buena.
Write-Host ""
Write-Host "  -- aprender del deshaz, pero solo cuando toca --"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:ultimaAprendida = ''
$script:ultimoEjecutado = ''
$script:ultimaReceta = $null
$script:ultimaRecetaEn = 0
$script:ultimaRecetaUsada = $false
$script:recetasFalsas = New-Object System.Collections.ArrayList
$script:traduccionesQuitadas = @()
$script:fallosMarcados = @()
function Write-FalloUso([string]$porque = '') { $script:fallosMarcados += $porque; return $true }
function Remove-Traduccion([string]$o) { $script:traduccionesQuitadas += $o; return $true }
# OJO A LA COMA: Get-Recetas de verdad hace "return ,$script:recetas". Sin ella
# PowerShell DESENROLLA el ArrayList y la funcion recibiria una copia, asi que su
# .Remove() no tocaria el original y la prueba mentiria. Misma trampa que ya avisa
# Get-HistorialMusica en assistant.ps1.
function Get-Recetas { return ,$script:recetasFalsas }
function Save-Recetas { }

# 1) orden LIMPIA deshecha: no se aprende nada
$script:rechazos = $null
$script:ultimaAprendida = ''
$script:ultimoEjecutado = 'abre steam'
$r1 = Invoke-AprenderDelError $true
Comp 'una orden limpia deshecha no se apunta' ($null -eq $r1) ''
Comp 'y "abre steam" sigue entendiendose' (-not (Test-Rechazada 'abre steam')) ''

# 2) la misma orden, pero venia de una TRADUCCION: eso si se aprende
$script:ultimaAprendida = 'hazme la pantalla mas clarita'
$script:ultimoEjecutado = 'sube el brillo'
$r2 = Invoke-AprenderDelError $true
Comp 'si vino de una traduccion, si aprende' ($null -ne $r2) ''
Comp 'apunta TU frase, no la orden a la que se tradujo' (Test-Rechazada 'hazme la pantalla mas clarita') ''
Comp 'y NO veta la orden normal' (-not (Test-Rechazada 'sube el brillo')) ''
Comp 'olvida la traduccion que la causo' ($script:traduccionesQuitadas -contains 'hazme la pantalla mas clarita') ''
Comp 'y lo marca como fallo medible' (@($script:fallosMarcados).Count -eq 1) ''

# 3) venia de una RECETA reciente que se EJECUTO: se olvida la receta
$script:rechazos = $null
$script:ultimaAprendida = ''
$script:ultimoEjecutado = 'pon la tele en el salon'
[void]$script:recetasFalsas.Add(@{ id = 'r1'; frase = 'pon la tele en el salon' })
$script:ultimaReceta = 'r1'
$script:ultimaRecetaEn = $sw.ElapsedMilliseconds
$script:ultimaRecetaUsada = $true     # se ejecuto y salio mal: ESE es el caso
$r3 = Invoke-AprenderDelError $true
Comp 'si vino de una receta, la olvida' ($r3 -and $r3.recetaOlvidada -eq 'pon la tele en el salon') ''
Comp 'y la receta ya no esta' ($script:recetasFalsas.Count -eq 0) ''

# 3b) RECIEN ENSENADA (21/09): 'deshaz' por cualquier otra cosa NO se la puede llevar.
# Ensenarle una receta marca ultimaReceta igual que ejecutarla, porque 'olvida eso'
# tiene que poder deshacer las dos; lo que distingue una de otra es ultimaRecetaUsada.
# Sin esto, ensenarle algo y decir 'deshaz' en los tres minutos siguientes -por el
# volumen, por una app- borraba la receta recien aprendida y sin avisar.
$script:rechazos = $null
$script:ultimaAprendida = ''
$script:ultimoEjecutado = 'sube el volumen'
[void]$script:recetasFalsas.Add(@{ id = 'r1b'; frase = 'pon la tele en el salon' })
$script:ultimaReceta = 'r1b'
$script:ultimaRecetaEn = $sw.ElapsedMilliseconds
$script:ultimaRecetaUsada = $false    # ensenada, NO ejecutada
$r3b = Invoke-AprenderDelError $true
Comp 'una receta recien ensenada no se borra al deshacer' ($null -eq $r3b) ''
Comp 'y sigue estando' ($script:recetasFalsas.Count -eq 1) ''
$script:recetasFalsas.Clear()
$script:ultimaRecetaUsada = $false

# 4) una receta VIEJA (mas de 3 min) ya no cuenta como dudosa
$script:rechazos = $null
$script:ultimaAprendida = ''
$script:ultimoEjecutado = 'abre spotify'
[void]$script:recetasFalsas.Add(@{ id = 'r2'; frase = 'abre spotify' })
$script:ultimaReceta = 'r2'
$script:ultimaRecetaUsada = $true     # ejecutada, para que lo que decida sea el PLAZO
$script:ultimaRecetaEn = $sw.ElapsedMilliseconds - 200000    # hace mas de 3 minutos
$r4 = Invoke-AprenderDelError $true
Comp 'una receta de hace rato ya no cuenta' ($null -eq $r4) ''
Comp 'y no se lleva por delante "abre spotify"' (-not (Test-Rechazada 'abre spotify')) ''
$script:recetasFalsas.Clear()

# 5) cuando lo DICES ("no era eso"), se aprende siempre, tambien de una orden limpia
$script:rechazos = $null
$script:ultimaAprendida = ''
$script:ultimaReceta = $null
$script:ultimoEjecutado = 'cierra el navegador'
$r5 = Invoke-AprenderDelError $false
Comp 'si lo dices tu, aprende aunque fuera limpia' ($null -ne $r5 -and $r5.apuntada) ''
Comp 'y queda apuntada' (Test-Rechazada 'cierra el navegador') ''

# 6) sin nada que rechazar, no revienta
$script:rechazos = $null
$script:ultimaAprendida = ''
$script:ultimoEjecutado = ''
$script:ultimaReceta = $null
$r6 = Invoke-AprenderDelError $false
Comp 'sin frase anterior no revienta' ($null -ne $r6 -and -not $r6.apuntada) ''

# --- y que el enganche siga en su sitio: sin el, esto no se usa nunca ---
Write-Host "  -- y el deshaz de verdad lo llama --"
$txtR = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
Comp 'el deshaz llama a la funcion en modo conservador' ($txtR -match 'Invoke-AprenderDelError \$true') ''
Comp 'y "no era eso" la llama en modo normal' ($txtR -match 'Invoke-AprenderDelError \$false') ''
Comp 'con su ventana de tiempo' ($txtR -match 'DeshazEnsenaMs') ''

Remove-Item $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
