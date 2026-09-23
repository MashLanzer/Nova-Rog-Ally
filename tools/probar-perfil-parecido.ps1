# QUE LO QUE REPITES RENUEVE EL DATO QUE SE LE PARECE (22/09, idea 7 de la tercera tanda).
#
# El 22/09, entre las 21:44 y las 21:49, se produjeron las CINCO primeras renovaciones reales
# del perfil de braya... y las cinco fueron al dato equivocado:
#     dijo "Braya juega It Takes Two"        -> blindo "braya juega juegos de terror"
#     dijo "braya juega a It Takes Two"      -> blindo "Braya juega a un videojuego llamado
#                                               La ultima parada o similar"
#     dijo "Braya juega videojuegos"         -> blindo "braya juega Elden Ring"
# Dos motivos, y los dos se arreglan aqui:
#   1. El bucle se quedaba con el PRIMER dato que pasara el liston, no con el que mas se
#      parece. Renovaba y salia corriendo.
#   2. El parecido contaba palabras de 4 letras o mas, y ahi entran las que estan en medio
#      perfil: medido sobre sus 60 datos, "braya" sale en 29 (el 48 %), "tiene" en 15 y
#      "juega" en 11. Con eso, dos frases sobre juegos distintos se parecen por el sujeto.
#
# Este banco trae Add-DatoPerfil del fichero de verdad y le da datos de mentira en una
# carpeta temporal, incluida la lista REAL de esa noche.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre"; exit 1 }
    return $fn.Extent.Text
}

# --- lo minimo para que Add-DatoPerfil corra: sus datos en una variable, no en disco ---
$script:perfilFalso = @()
function Get-DatosPerfil { return $script:perfilFalso }
function Save-DatosPerfil([string[]]$datos) { $script:perfilFalso = @($datos) }
function Log([string]$m) { $script:dicho = $m }
function Add-Estadistica($a, $b) { }
function Set-AcabaDeAprender { }
# REGLA DEL BANCO: toda funcion y toda variable que use Add-DatoPerfil se trae del fichero
# de verdad, nunca se copia. El patron de datos sensibles se lee de su linea: copiarlo aqui
# ya paso una vez en este repo -probar-recetas tenia su propia version inventada y no probaba
# el filtro real-.
$mSens = [regex]::Match($fuente, '(?m)^\$RE_DATO_SENSIBLE = (.+)$')
if (-not $mSens.Success) { Write-Host '  MAL  no encuentro $RE_DATO_SENSIBLE'; exit 1 }
Invoke-Expression ('$RE_DATO_SENSIBLE = ' + $mSens.Groups[1].Value)
# $PerfilMax TAMBIEN, y esta no es opcional: sin ella, la poda del final es
# "while ($datos.Count -gt $null)", que en PowerShell es siempre cierto -> BUCLE INFINITO.
# El banco se colgo hasta que se trajo. Sale de su linea, no de un numero escrito aqui.
$mMax = [regex]::Match($fuente, '(?m)^\$PerfilMax = (.+)$')
if (-not $mMax.Success) { Write-Host '  MAL  no encuentro $PerfilMax'; exit 1 }
Invoke-Expression ('$PerfilMax = ' + $mMax.Groups[1].Value)
$script:invitado = $false
$script:ultimoDatoPerfil = ''
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'ConvertTo-Suave')
Invoke-Expression (Traer 'Add-DatoPerfil')

# LA LISTA DE ESA NOCHE, tal cual estaba en su perfil
$deEsaNoche = @(
    'braya juega juegos de terror',
    'Braya juega a un videojuego llamado La ultima parada o similar',
    'Braya juega videojuegos de supervivencia con su pareja',
    'braya juega Elden Ring',
    'braya juega con otras personas',
    'prefiere que la musica se abra en YouTube en lugar de Spotify',
    'braya tiene pareja',
    'tiene 14 juegos instalados en Steam',
    'braya tiene sentido del humor',
    'braya conoce King Lear de Shakespeare'
)

Write-Host ''
Write-Host '-- la noche del 22: dice It Takes Two --'
$script:perfilFalso = @($deEsaNoche)
$script:dicho = ''
[void](Add-DatoPerfil 'Braya juega a It Takes Two')
$ultimo = $script:perfilFalso[-1]
Comp 'no blinda el primero de la lista por el sujeto' ($ultimo -ne 'braya juega juegos de terror') "renovo: '$ultimo'"
# lo que de verdad se parece a "juega a It Takes Two" no esta en su perfil, asi que lo
# correcto es GUARDARLO, no renovar cualquier cosa
Comp 'y el dato nuevo entra' ($script:perfilFalso -contains 'Braya juega a It Takes Two') "$($script:perfilFalso.Count) datos"

Write-Host ''
Write-Host '-- pero lo que SI es el mismo tema, se renueva --'
$script:perfilFalso = @($deEsaNoche)
[void](Add-DatoPerfil 'braya juega a Elden Ring todas las noches')
Comp 'renueva el de Elden Ring, no otro' ($script:perfilFalso[-1] -eq 'braya juega Elden Ring') "renovo: '$($script:perfilFalso[-1])'"
Comp 'y no lo duplica' (-not ($script:perfilFalso -contains 'braya juega a Elden Ring todas las noches'))

Write-Host ''
Write-Host '-- y gana el que MAS se parece, no el primero --'
# OJO CON EL CASO: tiene que haber DOS que pasen el liston, o esto no distingue "el primero"
# de "el mejor" y sale verde con el fallo dentro. El primer intento tenia solo uno y la
# rotura a proposito no lo cazo.
# Y NINGUNO DE LOS DOS PUEDE CONTENER LA FRASE NUEVA: esa rama corta por su cuenta y salva
# el caso aunque el resto este roto. El intento anterior lo tenia y la rotura a proposito
# -quedarse con el primero- seguia saliendo verde. Aqui la frase nueva es la MAS larga, asi
# que solo decide la puntuacion por palabras, que es lo que se quiere probar.
$script:perfilFalso = @('braya juega videojuegos', 'braya juega videojuegos de terror')
[void](Add-DatoPerfil 'braya juega videojuegos de terror por la noche')
Comp 'los dos pasan el liston, y gana el que mas comparte' ($script:perfilFalso[-1] -eq 'braya juega videojuegos de terror') "renovo: '$($script:perfilFalso[-1])'"
Comp 'y el generico se queda donde estaba' ($script:perfilFalso[0] -eq 'braya juega videojuegos')

Write-Host ''
Write-Host '-- las palabras vacias salen de SUS datos, no de una lista --'
Comp 'se cuentan las palabras del propio perfil' ($fuente -match '\$vaciasP = @\(\$cuenta\.Keys \| Where-Object') ''
Comp 'con un liston relativo, no fijo' ($fuente -match '\$topeV = \[Math\]::Max\(3, \[int\]\[Math\]::Ceiling\(\$datos\.Count / 3\.0\)\)') 'un tercio de los datos'
Comp 'y solo si hay datos suficientes' ($fuente -match 'if \(\$datos\.Count -ge 8\)') 'con tres datos todo saldria en un tercio'
Comp 'el parecido las descuenta en los dos lados' ((([regex]::Matches($fuente, '\$vaciasP -notcontains \$_')).Count) -ge 2) 'la frase nueva y la vieja'

Write-Host ''
Write-Host '-- y se renueva DESPUES del bucle, no dentro --'
Comp 'se guarda el mejor y se decide al final' ($fuente -match '\$mejorX = \$null; \$mejorP = 0\.0') ''
Comp 'y el log dice cuanto se parecia' ($fuente -match 'parecido \$\(\[Math\]::Round\(\$mejorP, 2\)\)') 'para poder revisarlo luego'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  lo que repites renueva el dato que se le parece'
exit 0
