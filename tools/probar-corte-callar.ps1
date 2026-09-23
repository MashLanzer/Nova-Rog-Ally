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
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# el bloque del corte, contando llaves desde el elseif (nunca por distancia en caracteres)
$ini = $fuente.IndexOf("Log (`"INTERRUMPIDA:")
$cuerpo = ''
if ($ini -ge 0) {
    $fin = $fuente.IndexOf('# --- CONVERSACION', $ini)
    if ($fin -gt $ini) { $cuerpo = $fuente.Substring($ini, $fin - $ini) }
}

Write-Host ''
Write-Host '-- el corte distingue quien es --'
Comp 'el bloque existe y se delimita' ($cuerpo.Length -gt 0) "$($cuerpo.Length) caracteres"
Comp 'compara la palabra con el nombre' ($cuerpo -match 'ConvertTo-Plain \$palabraCorte.{0,60}ConvertTo-Plain \$EscuchaNombre') ''
Comp 'y el log dice cual de las dos fue' (($cuerpo -match 'me callo y te escucho') -and ($cuerpo -match 'no abro el microfono')) 'o en una semana no se sabe si sirvio'

Write-Host ''
Write-Host '-- con tu nombre, te escucha --'
$ramaNombre = [regex]::Match($cuerpo, '(?s)if \(\(ConvertTo-Plain \$palabraCorte\).{0,80}\{(.*?)\} else \{').Groups[1].Value
Comp 'arma el seguimiento' ($ramaNombre -match '\$script:seguimientoPendiente = \$true') ''
Comp 'con su factor' ($ramaNombre -match '\$script:seguimientoFactor = 1\.0')
Comp 'y la ventana de charla si venias hablando' ($ramaNombre -match '\$script:ventanaCharla = \(')

Write-Host ''
Write-Host '-- con "para" o "callate", se calla y ya --'
# la rama del else, contando llaves: con un regex no-greedy se corta en la primera llave que
# aparezca y se mide media rama, que es como salian rojas tres comprobaciones con el codigo
# bien.
# ANCLADO AL if DE VERDAD: el primer '} else {' del bloque es el del propio mensaje de log
# ("me callo y te escucho" / "me callo, y no abro el microfono"), que dice lo mismo con
# otras palabras. Sin anclar, esto media 38 caracteres de un texto y salia rojo tres veces
# con el codigo bien. Es la trampa del dia, van cuatro.
$anclaIf = $cuerpo.IndexOf('if ((ConvertTo-Plain $palabraCorte)')
$iniE = if ($anclaIf -ge 0) { $cuerpo.IndexOf('} else {', $anclaIf) } else { -1 }
$ramaCalla = ''
if ($iniE -ge 0) {
    $jE = $cuerpo.IndexOf('{', $iniE); $profE = 0
    for ($kE = $jE; $kE -lt $cuerpo.Length; $kE++) {
        if ($cuerpo[$kE] -eq '{') { $profE++ }
        elseif ($cuerpo[$kE] -eq '}') { $profE--; if ($profE -eq 0) { $ramaCalla = $cuerpo.Substring($jE, $kE - $jE + 1); break } }
    }
}
Comp 'la rama de callarse se delimita' ($ramaCalla.Length -gt 0) "$($ramaCalla.Length) caracteres"
Comp 'NO arma el seguimiento' ($ramaCalla -match '\$script:seguimientoPendiente = \$false') 'esto es lo que dejaba el micro abierto'
Comp 'ni la ventana de charla' ($ramaCalla -match '\$script:ventanaCharla = \$false') 'si no, la siguiente frase entra igual'
Comp 'y queda contado, para poder medirlo' ($ramaCalla -match "Add-Estadistica 'corte-callar'")
Comp 'y no dice ni una palabra' (-not ($ramaCalla -match '(?m)\bSay\b')) 'el gesto de la capsula ya lo cuenta'

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
