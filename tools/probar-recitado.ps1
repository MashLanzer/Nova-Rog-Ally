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
Invoke-Expression (Traer 'Test-EsFraseEjemplo')
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

# UNA SOLA FRASE DEL EJEMPLO (16/09): por aqui se colaban las 4 ordenes equivocadas
# graves del repaso, medidas con las 214 grabaciones leidas
Comp 'una sola frase del ejemplo se reconoce' (Test-EsFraseEjemplo 'Que hora es') ''
Comp 'y con el signo de apertura tambien' (Test-EsFraseEjemplo '¿Que hora es') ''
Comp 'y con una letra cambiada' (Test-EsFraseEjemplo 'Sube el volumen.') ''
Comp 'una orden de verdad NO es la frase de ejemplo' (-not (Test-EsFraseEjemplo 'cierra steam')) ''
Comp 'ni una frase larga que la contenga' (-not (Test-EsFraseEjemplo 'sube el volumen de spotify al cincuenta')) ''
Comp 'nada dicho tampoco' (-not (Test-EsFraseEjemplo '')) ''

Comp 'lo mal oido no esta marcado al principio' (-not (Test-OidoDudoso 'Ensectiva el modo noche')) ''
Add-OidoDudoso 'Ensectiva el modo noche'
Comp 'una vez repasado queda marcado' (Test-OidoDudoso 'ensectiva el modo noche') ''
Comp 'y lo demas no' (-not (Test-OidoDudoso 'desactiva el modo noche')) ''

# ---------------------------------------------------------------------------
# LO QUE DICE LA LEYENDA DE 'recitado' (18/09).
#
# La frase que Nova escribia en estadisticas.md guiaba MAL: "si esto sube, el microfono
# esta cazando audio". Medido sobre los 13 recitados del log, es al reves: llegan con el
# pico a 0.000 de mediana, mientras el ruido de verdad esta en 0.077 y llega a 0.995.
# Whisper devuelve su propio initial_prompt cuando casi no hay audio que transcribir.
# Importa porque es la frase que la propia Nova leeria para decidir sola, y porque a
# partir de ella lo "logico" era bajar la ganancia: exactamente lo contrario de lo que
# hace falta.
$txt = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
$leyenda = ''
foreach ($l in ($txt -split "`r?`n")) {
    if ($l -match 'AppendLine\("\*\*activacion\*\*') { $leyenda = $l }
}
Write-Host '  -- la leyenda de las estadisticas --'
Comp 'la leyenda sigue estando' ($leyenda -ne '') ''
Comp 'ya NO dice que el recitado sea cazar audio' ($leyenda -notmatch 'esta cazando audio') ''
Comp 'cuenta que es el eco de la frase de ejemplo' ($leyenda -match 'frase de ejemplo') ''
Comp 'y la otra forma, la biblioteca' ($leyenda -match 'biblioteca') ''
Comp 'trae el dato medido que lo demuestra' ($leyenda -match '0\.000' -and $leyenda -match '0\.077') ''
Comp 'y avisa de que un cero puede ser un dia sin uso' ($leyenda -match 'sin usarla') ''

# Y QUE UN RECITADO NO CALLE A NOVA. La tentacion al leer la frase vieja era sumarlo a la
# racha de la autosordina. Medido: el 16/09 habria saltado a las 11:47:27, con braya
# hablandole (activacion legitima 'nova por', confianza 0.95, pico 0.268, y un dictado de
# seguimiento tres segundos despues). Es el mismo fallo del 15/09 que ya esta documentado
# en Add-RuidoRacha ("NO ES RUIDO SI ERES TU"). Si alguien lo "arregla", esto se pone rojo.
Write-Host '  -- y un recitado no dispara la autosordina --'
$vistos = 0
$i = $txt.IndexOf("Add-Estadistica 'recitado'")
while ($i -ge 0) {
    $desde = [Math]::Max(0, $i - 400)
    $trozo = $txt.Substring($desde, [Math]::Min(900, $txt.Length - $desde))
    $vistos++
    Comp "el camino $vistos apunta el recitado sin callarse" ($trozo -notmatch 'Add-RuidoRacha') ''
    $i = $txt.IndexOf("Add-Estadistica 'recitado'", $i + 1)
}
Comp 'y siguen siendo los dos caminos conocidos' ($vistos -eq 2) "encontrados $vistos"

if ($fallos -eq 0) { Write-Host "todo correcto" } else { Write-Host "$fallos MAL"; exit 1 }
