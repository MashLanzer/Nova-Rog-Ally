# QUE "CALLATE" NO TE ABRA EL MICROFONO (22/09 por la noche, idea 4 de la tercera tanda).
#
# Por la rama del corte entran DOS cosas que significan lo contrario: tu nombre -que quiere
# decir "voy a hablar", asi que reabrir el microfono es lo correcto- y las seis palabras de
# parada (espera, para, calla, callate, basta, silencio). Las tres lineas que reabren la
# escucha estaban escritas para el nombre y se aplicaban a las seis.
#
# EL CASO DE VERDAD, y es el unico del log en el que una frase que no era para Nova se colo
# entera: 21/09 00:07:53, braya dice "para" (confianza 0,96). Nova para, reabre el microfono,
# y a los diez segundos coge "¿Botoncito atras y el boton abajo?" -braya explicandole los
# mandos a quien juega con el-. Eso fue a Parakeet, a Whisper, a Gemini y a la API de Claude,
# y VEINTIUN SEGUNDOS despues de mandarla callar volvio a hablar. En el log hay 7 ordenes de
# parada y 78,4 segundos de microfono abierto detras de ellas.
#
# Lo que este banco vigila:
#   - que con una palabra de parada NO se arme el seguimiento ni la ventana de charla;
#   - que con el nombre SI (o habria que repetirlo cada vez, que es peor);
#   - que pausaHasta se toque en los DOS caminos: es lo que hace vencer la pausa, y metido
#     dentro del if dejaria a Nova sorda hasta que venciera la frase cortada;
#   - y que al callarse no diga ni una palabra.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# AHORA SE EJECUTA, NO SE LEE (24/09). Este banco miraba el texto de assistant.ps1 con
# IndexOf y contaba llaves para delimitar las dos ramas del if. Funcionaba... hasta que la
# idea 2 saco la decision a una funcion pura, y entonces se puso rojo con el codigo MEJOR de
# lo que estaba. Es justo lo que dice el commit e1ab4dc: el banco miraba la forma del codigo,
# no lo que hace.
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
foreach ($f in @('ConvertTo-Plain', 'Resolve-Corte')) { Invoke-Expression (Traer $f) }
$cuerpo = $fuente

Write-Host ''
Write-Host '-- el corte distingue quien es --'
Comp 'con tu nombre, abre el microfono' ((Resolve-Corte 'nova' 'nova' $false $true $false).abreMicro) ''
Comp 'con "para", NO' (-not (Resolve-Corte 'para' 'nova' $false $true $false).abreMicro) 'esto es lo que dejaba el micro abierto'
Comp 'y el log dice cual de las dos fue' (($cuerpo -match 'me callo y te escucho') -and ($cuerpo -match 'no abro el microfono')) 'o en una semana no se sabe si sirvio'

Write-Host ''
Write-Host '-- EL CASO DEL 21/09 00:07:53, palabra por palabra --'
# braya dijo "para" con confianza 0,96. Nova paro, reabrio el microfono, y a los diez
# segundos cogio "Botoncito atras y el boton abajo?" -braya explicandole los mandos a quien
# jugaba con el-. Eso fue a Parakeet, a Whisper, a Gemini y a la API de Claude.
foreach ($pal in @('espera', 'para', 'calla', 'callate', 'basta', 'silencio')) {
    $r = Resolve-Corte $pal 'nova' $false $true $false
    Comp ("'$pal' se calla y no abre nada") ((-not $r.abreMicro) -and ([string]$r.accion -eq 'corta-y-calla')) "$([string]$r.accion)"
}
Comp 'y el nombre sigue abriendo' ((Resolve-Corte 'nova' 'nova' $false $true $false).accion -eq 'corta-y-escucha') ''

Write-Host ''
Write-Host '-- con "para" o "callate", se calla y ya --'
$lineas = @($fuente -split "`r?`n")
# DELIMITADO POR SUS DOS MARCAS, no por un numero de lineas: 60 se quedaba corto y tres
# comprobaciones salian rojas con el codigo bien. Es la misma trampa que ya costo cuatro.
$iC = ($lineas | Select-String -SimpleMatch 'Resolve-Corte $palabraCorte' | Select-Object -First 1).LineNumber
$iFin = ($lineas | Select-String -SimpleMatch '# --- CONVERSACION' | Select-Object -First 1).LineNumber
if (-not $iC -or -not $iFin -or $iFin -le $iC) { Write-Host '  MAL  no se delimitar el bloque del corte'; exit 1 }
$bloque = (($lineas[($iC - 1)..($iFin - 2)] | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'el bloque del bucle existe' ($null -ne $iC) ''
Comp 'NO arma el seguimiento al callarse' ($bloque -match '\$script:seguimientoPendiente = \$false') 'esto es lo que dejaba el micro abierto'
Comp 'ni la ventana de charla' ($bloque -match '\$script:ventanaCharla = \$false') 'si no, la siguiente frase entra igual'
Comp 'y queda contado, para poder medirlo' ($bloque -match "Add-Estadistica 'corte-callar'")
# SOLO LA RAMA DEL CORTE: volver de la sordina SI habla ("Aqui estoy"), y eso es correcto.
# Lo que no puede hablar es callarse.
$iCorta = $bloque.IndexOf('$esNombreC = $dCorte.abreMicro')
$ramaCorte = if ($iCorta -ge 0) { $bloque.Substring($iCorta) } else { '' }
Comp 'la rama del corte se delimita' ($ramaCorte.Length -gt 0) "$($ramaCorte.Length) caracteres"
Comp 'y al callarse no dice ni una palabra' (-not ($ramaCorte -match '(?m)\bSay\b')) 'el gesto de la capsula ya lo cuenta'
Comp 'pero volver de la sordina SI habla' ($bloque -match "Say 'Aqui estoy") 'eso es lo correcto'

Write-Host ''
Write-Host '-- y no se queda sorda, que seria el fallo contrario --'
Comp 'pausaHasta se toca FUERA del if' ($cuerpo -match '(?s)\}\s*\r?\n\s*\$script:pausaHasta = \$sw\.ElapsedMilliseconds \+ 150') 'en los dos caminos'
Comp 'y sigue parando la voz y la charla' (($cuerpo -match 'Stop-Charla') -and ($cuerpo -match 'vozPlayer'))

Write-Host ''
Write-Host '-- las palabras de parada siguen siendo las de siempre --'
Comp 'el worker las tiene en una lista cerrada' ($oido -match 'PALABRAS_CORTE = \["espera", "para", "calla", "callate", "basta", "silencio"\]') ''
Comp 'y el nombre va aparte' ($oido -match 'PALABRAS_CORTE \+ \(\[NOMBRE\]')

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  cuando le mandas callar, se calla y no abre el microfono'
exit 0
