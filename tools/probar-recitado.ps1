# La frase de ejemplo de Whisper recitada (15/09) y lo mal oido que no se aprende.
# En vivo, con casi silencio, Whisper devolvio su frase de ejemplo entera y se subio
# el volumen y se bajo el brillo; y "Ensectiva el modo noche" se aprendio como "modo
# noche". Aqui se comprueba que un recitado no pasa y que una orden sola sigue valiendo.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function Log($m) { }
$RutaWakeVosk = Join-Path $raiz 'wake_vosk.py'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:frasesEjemplo = $null
$script:oidosDudosos = @{}

Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'Get-FrasesEjemplo')
Invoke-Expression (Traer 'Test-RecitaEjemplo')
Invoke-Expression (Traer 'Add-OidoDudoso')
Invoke-Expression (Traer 'Test-OidoDudoso')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-48} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

$frases = @(Get-FrasesEjemplo)
Comp 'la frase de ejemplo se lee de wake_vosk.py' ($frases.Count -eq 5) ($frases -join ' | ')
Comp 'el recitado del 15/09 no es una orden' (Test-RecitaEjemplo 'Sube el volumen, Pon el modo noche, ¿Qué hora es? Baja el brillo') ''
Comp 'dos frases distintas del ejemplo tampoco' (Test-RecitaEjemplo '¿Qué hora es? Baja el brillo') ''
Comp 'ni con el nombre y una letra cambiada' (Test-RecitaEjemplo 'Nova, abra Steam. Sube el volumen.') ''
Comp 'una sola orden del ejemplo SI vale' (-not (Test-RecitaEjemplo 'Sube el volumen')) ''
Comp 'la misma repetida tambien es un recitado' (Test-RecitaEjemplo '¿Qué hora es? ¿Qué hora es') ''
Comp 'dos ordenes que no son del ejemplo valen' (-not (Test-RecitaEjemplo 'abre steam y pon música')) ''
Comp 'una del ejemplo con otra distinta vale' (-not (Test-RecitaEjemplo 'Sube el volumen, abre discord')) ''
Comp 'nada dicho no es recitado' (-not (Test-RecitaEjemplo '')) ''

Comp 'lo mal oido no esta marcado al principio' (-not (Test-OidoDudoso 'Ensectiva el modo noche')) ''
Add-OidoDudoso 'Ensectiva el modo noche'
Comp 'una vez repasado queda marcado' (Test-OidoDudoso 'ensectiva el modo noche') ''
Comp 'y lo demas no' (-not (Test-OidoDudoso 'desactiva el modo noche')) ''

if ($fallos -eq 0) { Write-Host "todo correcto" } else { Write-Host "$fallos MAL"; exit 1 }
