# LO QUE SE GUARDA DE BRAYA Y LO QUE NOVA DICE QUE DIJO (21/09).
#
# Tres cosas que se arreglaron el mismo dia y que tienen en comun que fallaban EN SILENCIO:
# nadie se entera de que un filtro no filtra hasta que miras lo que ha dejado pasar.
#
#   1. El filtro de datos sensibles del perfil comparaba contra el texto CON TILDES, y el
#      patron esta escrito sin ellas: 'diagnostic' no casa con "diagnostico" jamas. La
#      mitad de la lista de palabras prohibidas no prohibia nada. Y lo que entra en el
#      perfil VIAJA CON CADA PETICION al modelo.
#   2. El filtro de deducciones pedia que la frase EMPEZARA por 'probablemente'... y los
#      datos del perfil empiezan todos por "Braya ...", asi que no rechazaba ni uno. En el
#      perfil de verdad hay hoy un dato deducido que este patron si caza.
#   3. Un aviso de nivel 'bajo' -de los que se ven en la capsula y NO se dicen- se quedaba
#      como $script:ultimaRespuesta, o sea que "repite" contestaba una frase que Nova no
#      habia dicho nunca, tapando ademas la de verdad.
#
# LA REGLA DE LA EXTRACCION (van diez veces): toda funcion que se llame aqui tiene que
# estar en la lista de Traer, o la prueba corre contra el vacio y sale verde sin probar
# nada. Por eso debajo de cada bloque hay un caso que TIENE que salir MAL si el arreglo se
# deshace: comprobado rompiendolo a mano.
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
function Sacar([string]$nombre) {
    # una variable de nivel de script, tal y como esta escrita en el archivo
    $m = [regex]::Match($fuente, '(?m)^\$' + [regex]::Escape($nombre) + '\s*=\s*(.+)$')
    if (-not $m.Success) { throw "no encuentro la variable $nombre" }
    return $m.Groups[1].Value
}

function Log($m) { }
function Show-Popup($t, $n = '') { }
function Send-AvisoCola($ya) { $script:dicho = $true }
function Add-Estadistica($r, $d = '', $c = $false) { }
function Save-EntornoVistos { }
function ConvertTo-Suave([string]$s) { return (ConvertTo-Plain $s) }
function Get-DatosPerfil { return @($script:perfilFalso) }
function Save-DatosPerfil([string[]]$d) { $script:perfilFalso = @($d) }
function Set-AcabaDeAprender { $script:aprendio = $true }

# LA TRAJO OTRA IDEA Y ESTE BANCO NO SE ENTERO (24/09): sin ella moria a mitad, y
# encima salia con codigo 0. Lo vio la trampa nueva, no una persona.
Invoke-Expression (Traer 'Test-DatoTrato')
Invoke-Expression (Traer 'ConvertTo-Plain')
$RE_DATO_SENSIBLE = Invoke-Expression (Sacar 'RE_DATO_SENSIBLE')
# EL FILTRO DE LO PASAJERO Y SUS DOS REGEX (24/09, idea 12): Add-DatoPerfil los llama, asi que
# sin ellos este banco muere a mitad. Los regex son de varias lineas, asi que se sacan como
# asignacion del arbol y no con un regex de una linea.
Invoke-Expression (Traer 'ConvertTo-Suave')
Invoke-Expression (Traer 'Test-DatoPasajero')
$astPA = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'), [ref]$null, [ref]$null)
foreach ($aPA in $astPA.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] }, $false)) {
    if ($aPA.Left.VariablePath.UserPath -in @('RE_DATO_ESTADO', 'RE_DATO_RASGO')) { Invoke-Expression $aPA.Extent.Text }
}
Invoke-Expression (Traer 'Add-DatoPerfil')

$script:invitado = $false
$script:perfilFalso = @()
$script:ultimoDatoPerfil = ''
$PerfilMax = 60

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- 1. datos sensibles: el patron esta sin tildes, el dato NO --'
# estas son las que fallaban: la palabra prohibida lleva tilde en el texto real
foreach ($par in @(
    @{ d = 'Braya tiene un diagnostico de asma desde pequeno'; q = 'diagnostico sin tilde' },
    @{ d = 'A Braya le dieron un diagnóstico de asma de pequeño'; q = 'diagnóstico CON tilde' },
    @{ d = 'Braya toma medicamentos para dormir por las noches'; q = 'medicamentos (plural)' },
    @{ d = 'La contraseña de Braya para el correo es de las largas'; q = 'contraseña' },
    @{ d = 'Braya guarda el dinero de los juegos en una cuenta aparte'; q = 'dinero' },
    @{ d = 'Braya tiene problemas de salud desde hace anos'; q = 'salud' })) {
    Comp ("no se guarda: " + $par.q) ($null -eq (Add-DatoPerfil $par.d))
}
# y lo normal SI entra, que si no el filtro seria inutil por el otro lado
Comp 'un dato normal si se guarda' ($null -ne (Add-DatoPerfil 'Braya juega a Elden Ring casi todas las noches'))
Comp 'y otro tambien' ($null -ne (Add-DatoPerfil 'Braya guarda las capturas en la carpeta D de la microSD'))

Write-Host ''
Write-Host '-- 2. deducciones: la palabra va EN MEDIO, que es como llegan de verdad --'
# el dato se escribe en tercera persona, asi que empieza por "Braya" SIEMPRE: un patron
# anclado al principio no puede cazar ninguno
foreach ($par in @(
    @{ d = 'Braya probablemente juega de noche porque es cuando habla'; q = 'probablemente, en medio' },
    @{ d = 'Braya podria tener una pareja por como habla a veces'; q = 'podria (faltaba en la lista)' },
    @{ d = 'Esta ensenando a alguien (probablemente un nino) trucos de juegos'; q = 'el que hay HOY en su perfil' },
    @{ d = 'Braya seguramente prefiere las respuestas cortas'; q = 'seguramente' })) {
    Comp ("no se guarda: " + $par.q) ($null -eq (Add-DatoPerfil $par.d))
}
Comp 'y un dato afirmado de verdad si entra' ($null -ne (Add-DatoPerfil 'Braya prefiere que la musica se abra en YouTube'))

Write-Host ''
Write-Host '-- 3. un aviso que NO se dice no es la ultima respuesta --'
# aqui no hace falta ejecutar Send-AvisoEntorno entera (arrastra medio archivo): lo que se
# comprueba es que ultimaRespuesta ya NO esta antes del if, sino dentro de las dos ramas
# que hablan. Es una comprobacion de forma, y por eso va con el texto exacto.
# LA FUNCION SE SACA DEL ARBOL, no con un regex de 3.000 caracteres (24/09). Ese regex
# cortaba en el primer salto seguido de llave, asi que cualquier bloque nuevo dentro de
# Send-AvisoEntorno -o un comentario largo- la dejaba a medias y el banco se ponia rojo sin
# que nada estuviera mal. El arbol devuelve la funcion ENTERA, mida lo que mida.
$bloque = (Traer 'Send-AvisoEntorno')
Comp 'Send-AvisoEntorno esta donde se espera' ($bloque.Length -gt 200) ("$($bloque.Length) caracteres")
$antesDelIf = $bloque.Substring(0, [Math]::Max(0, $bloque.IndexOf("if (`$nivel -eq 'alto')")))
Comp 'ya no se pone para todos los avisos' (-not ($antesDelIf -match '\$script:ultimaRespuesta = \$texto'))
Comp 'la rama de nivel alto si la pone' ($bloque -match "if \(\`$nivel -eq 'alto'\) \{[\s\S]{0,200}?\`$script:ultimaRespuesta = \`$texto")
Comp 'y la de nivel medio tambien' ($bloque -match "elseif \(\`$nivel -ne 'bajo'\) \{\s*\r?\n\s*\`$script:ultimaRespuesta = \`$texto")
# el de nivel 'bajo' no entra en ninguna de las dos: ese es justo el que fallaba
Comp 'el de nivel bajo no pasa por ninguna de las dos' `
    (([regex]::Matches($bloque, '\$script:ultimaRespuesta = \$texto')).Count -eq 2) `
    "aparece $(([regex]::Matches($bloque, '\$script:ultimaRespuesta = \$texto')).Count) veces, tienen que ser 2"

Write-Host ''
Write-Host '-- 4. el clima: los chubascos de nieve son nieve, no "despejado" --'
# codigos WMO: 85 y 86 son chubascos de nieve, y esta cadena saltaba de 77 a 80
# OJO AL PATRON: tiene que ser el de la rama que pone el TEXTO ($emoji/$desc), no el de
# la capsula. Los dos dicen "71-77 o 85-86", asi que un -match suelto casa con el de la
# capsula y la prueba pasa en verde aunque el texto vuelva a decir "despejado": comprobado
# rompiendolo, y no lo cazaba. Por eso se pide el 'elseif' y el '$emoji' del final.
Comp 'la rama de la nieve incluye 85 y 86' `
    ($fuente -match 'elseif \(\(\$codigo -ge 71 -and \$codigo -le 77\) -or \(\$codigo -ge 85 -and \$codigo -le 86\)\) \{ \$emoji')
Comp 'y la capsula sigue dibujando copos con los mismos' `
    ($fuente -match "\(\`$codigo -ge 71 -and \`$codigo -le 77\) -or \(\`$codigo -ge 85 -and \`$codigo -le 86\)\) \{ 'nieve' \}")

Write-Host ''
Write-Host '-- 5. de madrugada, "a las siete" son las siete de la manana --'
Comp 'la suma de 12 mira la hora que es' ($fuente -match '\$horaAhora -ge \$hora\) \{ \$hora \+= 12 \}')
Comp 'y sigue pidiendo que no se dijera la franja' ($fuente -match '-not \$franja -and \$hora -le 7 -and \$hora -ge 1')

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host ''
Write-Host '  lo que se guarda de braya se filtra de verdad, y lo que Nova no dice no lo repite'
exit 0
