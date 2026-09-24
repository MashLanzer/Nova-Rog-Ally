# LA SEGUNDA OPINION DE LA NUBE (16/09): cuando SI vale lo que oye Gemini y cuando no.
#
# Medido con las 344 grabaciones (214 leidas + 130 de uso real): gemini-3.5-flash-lite
# entiende mas ordenes que el camino local, pero tiene dos vicios propios que aqui se
# cortan: recita los nombres que lleve el prompt y a veces mete un juego que no dijiste.
# Y siempre, siempre, con tope de espera: 5 de cada 20 peticiones pasan de 3 s.
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
$RutaWakeVosk = Join-Path $raiz 'wake_vosk.py'
$script:frasesEjemplo = $null
$script:Juegos = @(@{ nombre = 'Hollow Knight Silksong' }, @{ nombre = 'It Takes Two' })

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'Get-FrasesEjemplo')
Invoke-Expression (Traer 'Test-EsFraseEjemplo')
Invoke-Expression (Traer 'Test-NombreInventado')
Invoke-Expression (Traer 'Test-NubeSirve')
Invoke-Expression (Traer 'Test-NubeEncaja')
Invoke-Expression (Traer 'Get-EsperaNubeMs')
function Log([string]$m) { }
function Add-Estadistica($a, $b) { }

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- se acepta --"
Comp 'una orden clara que el oido local no saco' (Test-NubeSirve 'cierra steam' 'sierra este' $true) ''
Comp 'con punto final y mayusculas' (Test-NubeSirve 'Cierra la calculadora y cierra Steam.' 'cierra la calle' $true) ''

Write-Host "  -- no se acepta --"
Comp 'vacio' (-not (Test-NubeSirve '' 'cierra steam' $false)) ''
Comp 'si no es una orden que Nova sepa hacer' (-not (Test-NubeSirve 'pues no se que decirte' 'cierra steam' $false)) ''
Comp 'la frase de ejemplo de Whisper (el eco)' (-not (Test-NubeSirve 'Que hora es' 'cierra steam' $true)) ''
Comp 'un juego que no habias nombrado' (-not (Test-NubeSirve 'abre Hollow Knight Silksong' 'busca el clima' $true)) ''
Comp 'un parrafo entero: eso no es una orden' (-not (Test-NubeSirve ('palabra ' * 40) 'cierra steam' $true)) ''
Comp 'el juego que SI nombraste, vale' (Test-NubeSirve 'abre Hollow Knight Silksong' 'abre hollow knight' $true) ''


Write-Host ""
Write-Host "-- LO QUE TRAE LA NUBE TIENE QUE PARECERSE A LO QUE SONO (24/09, idea 7) --"
# LOS DOS CASOS REALES, Y SON LO PEOR QUE HA PASADO AQUI. El 18/09 a las 20:06:24 se oyo
# "Quiero que se hace el diario" y Gemini devolvio "Quiero que cierre Steam.": Steam se cerro.
# Once segundos despues, sobre "Tambien se hace una vez", devolvio "Tambien cierre el
# navegador." y el navegador se cerro. Las dos pasaron todas las guardas que habia.
Comp 'el invento del 18/09 20:06:24 no pasa' (-not (Test-NubeEncaja 'Quiero que cierre Steam.' 'Quiero que se hace el diario' 'Quiero que si es el')) 'se cerro Steam sin que nadie lo pidiera'
Comp 'el del 20:06:35 tampoco' (-not (Test-NubeEncaja 'Tambien cierre el navegador.' 'Tambien se hace una vez' "I'm gonna know")) 'y el navegador'
# Y ENGANCHADA DE VERDAD, no solo definida: el fallo clasico es que la guarda exista y
# nadie la llame.
Comp 'y la guarda esta enganchada en Test-NubeSirve' (-not (Test-NubeSirve 'Quiero que cierre Steam.' 'Quiero que se hace el diario' $true)) ''
# PERO UNA CORRECCION DE VERDAD SIGUE VALIENDO. Sin esto la guarda seria solo un "no".
Comp 'corregir "sierra este steam" -> "cierra steam" SI vale' (Test-NubeEncaja 'cierra steam' 'sierra este steam' 'sierra esteam') ''
Comp 'y el juego que si nombraste, tambien' (Test-NubeEncaja 'abre Hollow Knight Silksong' 'abre hollow knight' '') ''
Comp 'y sigue pasando por Test-NubeSirve entera' (Test-NubeSirve 'abre Hollow Knight Silksong' 'abre hollow knight' $true) ''
# CUATRO LETRAS, NO TRES: con tres, "que" y "cierre" estan en las dos frases del 18/09 y el
# invento habria pasado igual.
Comp 'con palabras de tres letras el invento colaria' ('quiero que cierre steam' -match 'que') 'por eso el minimo es cuatro'

Write-Host ""
Write-Host "-- Y EL BUCLE YA NO LA ESPERA --"
# Habia un while con Start-Sleep que llegaba a 7,8 s con un juego delante. De las 12 esperas
# que hubo, CERO acabaron en un 'nube-sirvio'.
$sumaE = 0
foreach ($ms in @(1, 120, 500, 1000, 3000, 5800, 7800)) {
    foreach ($a in @($true, $false)) {
        foreach ($b in @($true, $false)) { $sumaE += (Get-EsperaNubeMs $a $b $ms) }
    }
}
Comp 'la espera es cero en las 28 combinaciones' ($sumaE -eq 0) "$sumaE ms en total"
$cuerpoB = (Traer 'Get-EsperaNubeMs')
Comp 'y no duerme por su cuenta' ($cuerpoB -notmatch 'Start-Sleep') ''
Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
