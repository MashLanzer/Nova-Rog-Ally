# "NO DIJE DISCORD, DIJE STEAM": LA CORRECCION QUE NIEGA LO MAL OIDO (25/09)
#
# LO QUE PASO. El 25/09 a la 01:26:11 la API tradujo un 'Cierra este in.' mal oido -que era
# "cierra Steam"- a 'cierra discord', y a la 01:26:12 Nova lo APRENDIO PARA SIEMPRE. A la
# 01:26:29, diecisiete segundos despues, braya dijo "No dije Discord, dije Steam". Nova
# contesto "Tienes razon, mi mal" y NO DESHIZO NADA: la traduccion envenenada seguia en
# traducciones.json a la manana siguiente, apuntando a la aplicacion por la que braya habla
# con su pareja. Entre las 01:25:37 y las 01:27:03 pidio cerrar Steam CUATRO veces y no lo
# consiguio ni una.
#
# LOS DOS FALLOS QUE HABIA DEBAJO, que es lo que vigila este banco:
#   1. El patron de "no, dije X" SI casaba, pero capturaba desde el PRIMER "dije": de
#      'no dije discord dije steam' sacaba 'discord dije steam'.
#   2. Y como ese trozo no resuelve a ninguna orden, el bloque entero se saltaba y se perdia
#      tambien el DESHACER. Una correccion a medio entender acababa en ninguna correccion.
#
# LO MEDIDO, y por eso los patrones piden una NEGACION DE LO DICHO delante: sobre los 737
# dictados de assistant.log y su rotado (633 distintos), estas dos formas cogen EXACTAMENTE
# las dos correcciones de verdad que hay y ninguna de las otras 631. Las cuatro que se
# parecen y NO lo son estan abajo, una a una, como casos negativos.
#
# Y NO SE ADIVINA EL VERBO. De "no dije Discord, dije Steam" sale 'steam' a secas: Nova
# deshace y olvida, pero no abre Steam por su cuenta. Adivinar que hacer con un nombre suelto
# es la regla 1 al reves, lo mismo que ya decide "abre este" en Resolve-Deictico.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PowerShell 5.1 con -File sale con codigo 0 aunque el
# script muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}
# TRAER, NO COPIAR. Un banco que se trae su propia copia de la constante prueba SU numero y
# no el de Nova: es la manera 4 de salir verde mintiendo, y ha mordido dos veces aqui.
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function TraerVar([string]$n) {
    $m = [regex]::Match($fuente, '(?m)^\s*\$' + $n + '\s*=\s*(.+?)\s*$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro la variable $n"; exit 1 }
    return $m.Groups[1].Value
}
foreach ($v in @('VERBOS_OIDOS', 'VERBOS_IMPERATIVO')) {
    $txt = [regex]::Match($fuente, '(?ms)^\$' + $v + ' = @\{.*?^\}').Value
    if (-not $txt) { Write-Host "  MAL  no encuentro la tabla $v"; exit 1 }
    Invoke-Expression $txt
}
Invoke-Expression (Traer 'Repair-Verb')
$reNiegaDoble = Invoke-Expression (TraerVar 'reNiegaDoble')
$reNiegaPedi  = Invoke-Expression (TraerVar 'reNiegaPedi')

# EL BLOQUE DE VERDAD, sacado del archivo y no reescrito aqui. Va desde la linea que declara
# el primer patron hasta la llave que cierra el if: si alguien lo cambia, este banco mide el
# cambio y no una copia que se quedo atras.
# Se corta entre dos marcas del propio archivo -la primera linea del bloque y el comentario
# del bloque siguiente- y no con una expresion regular que cuente llaves: contar llaves es
# justo la manera 7 de salir verde mintiendo (una regex cortaba en la primera llave y probaba
# media funcion). Si alguien mueve cualquiera de las dos marcas, esto se para en rojo.
$iniB = $fuente.IndexOf('$reNiegaDoble = ')
$finB = if ($iniB -ge 0) { $fuente.IndexOf('# "NO, DIJE ABRE STEAM"', $iniB) } else { -1 }
if ($iniB -lt 0 -or $finB -lt 0) { Write-Host '  MAL  no encuentro el bloque de la correccion'; exit 1 }
$bloque = $fuente.Substring($iniB, $finB - $iniB)

# EL DOBLE DE Resolve-Fragment. No resuelve de todo: solo lo justo para separar "esto es una
# orden" de "esto no lo es", que es la unica decision que toma el bloque. Y lo que devuelve
# para cada frase esta comprobado contra la funcion de verdad: de sus 317 patrones sobre $f,
# 'steam' a secas solo casa con el que exige una lista de amigos viva Y un numero -asi que no
# resuelve-, y 'cierra steam' casa con el de cerrar aplicaciones.
$script:pedidas = @()
function Resolve-Fragment([string]$fr) {
    $script:pedidas += $fr
    if ($fr -match '^(?:cierra|abre)\s+\S+') { return @(@{ kind = 'app'; desc = $fr }) }
    return @()
}
# El envoltorio NO devuelve $null cuando no casa, sino NADA, que es lo que hace el codigo de
# verdad: cae de largo al bloque siguiente. Y no es un detalle: @($null) en PowerShell es un
# array de UN elemento, asi que "no ha devuelto nada" contaba como una accion y los cuatro
# casos negativos salian MAL con el codigo bueno.
Invoke-Expression ("function Probar-Correccion([string]`$f) {`n" + $bloque + "`n}")

Write-Host ''
Write-Host '-- 1. LAS DOS CORRECCIONES DE VERDAD DEL REGISTRO --'
$script:pedidas = @()
# @( ) A PROPOSITO, y no es cosmetica: PowerShell DESENVUELVE un array de un elemento, asi
# que con una sola accion $r1 seria la tabla hash y $r1.Count valdria 2 -sus dos claves- y
# $r1[0] seria $null. El banco daba MAL por eso, no por el codigo. Quien llama de verdad
# (Process-Texto) ya envuelve igual.
$r1 = @(Probar-Correccion 'no dije discord dije steam')
Comp 'la del 25/09 a la 01:26:29 se reconoce' ($r1.Count -gt 0) 'no dije discord dije steam'
Comp 'y lo primero que hace es DESHACER Y OLVIDAR' ($r1 -and $r1[0].kind -eq 'noEraEso') "kind=$(if ($r1) { $r1[0].kind })"
Comp 'coge el ULTIMO dije, no el primero' ($script:pedidas -contains 'steam') "pidio resolver: $($script:pedidas -join ' / ')"
Comp 'y NO se inventa que hacer con un nombre suelto' ($r1.Count -eq 1) "$($r1.Count) accion(es): solo deshacer"

$script:pedidas = @()
$r2 = @(Probar-Correccion 'no no te pedi la hora dije sierra steam')
Comp 'la de "no te pedi la hora, dije sierra steam"' ($r2.Count -gt 0)
Comp 'deshace' ($r2 -and $r2[0].kind -eq 'noEraEso')
Comp 'Y ADEMAS hace lo que si le pediste' ($r2.Count -eq 2 -and $r2[1].kind -eq 'app') "$($r2.Count) acciones"
Comp 'con el verbo mal oido reparado (sierra -> cierra)' ($script:pedidas -contains 'cierra steam') "pidio resolver: $($script:pedidas -join ' / ')"

Write-Host ''
Write-Host '-- 2. LO QUE SE PARECE Y NO LO ES (las cuatro del registro) --'
# Sin la negacion de lo dicho delante, un "dije" suelto en mitad de una charla deshace algo
# que nadie pidio deshacer, que es la regla 1.
$negativos = @(
    'no solo no me estas entendiendo dije que podria ser algo de tu codigo que no te preocupes',
    'no no te estoy probando dije el fuego el fuego no el huevo',
    'no no solo queria saber el lado',
    'no lo que quiero saber es por que me contestas eso ahora si eso lo dije hace cinco minutos'
)
foreach ($n in $negativos) {
    Comp ('no deshace: "' + $n.Substring(0, [Math]::Min(40, $n.Length)) + '..."') (@(Probar-Correccion $n).Count -eq 0)
}
# Y la que ya cogia el patron VIEJO tiene que seguir yendo por el, no por este.
Comp 'y "no queria saber cuanta ram..." sigue sin ser correccion aqui' `
    (@(Probar-Correccion 'no queria saber cuanta ran esta ocupando roblox y nova o sea tu al mismo tiempo').Count -eq 0)

Write-Host ''
Write-Host '-- 3. QUE EL DESHACER NO DEPENDA DE ENTENDER LO CORREGIDO --'
# ESTE ES EL ARREGLO. Antes, si lo corregido no resolvia, el bloque entero se saltaba y se
# perdia el deshacer: justo lo que paso con Discord.
$script:pedidas = @()
$r3 = @(Probar-Correccion 'no dije discord dije cualquier cosa que no existe')
Comp 'aunque lo corregido no se entienda, SE DESHACE' ($r3 -and $r3[0].kind -eq 'noEraEso')
Comp 'y no se ejecuta nada mas' ($r3.Count -eq 1) "$($r3.Count) accion(es)"

Write-Host ''
Write-Host '-- 4. QUE LOS PATRONES SEAN LOS DE NOVA, NO LOS MIOS --'
Comp 'el patron doble sale del archivo' ($reNiegaDoble -like '*dije*queria*quise decir*')
Comp 'el patron de "no te pedi" tambien' ($reNiegaPedi -like '*pedi*')
Comp 'y ninguno lleva un caracter invisible dentro' `
    (-not ($reNiegaDoble + $reNiegaPedi).ToCharArray().Where({ [int]$_ -in @(7, 8, 11, 12, 27) })) `
    'el 0x08 de un \b mal escrito no se ve al leerlo'

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'la correccion que niega deshace, olvida y no se inventa el verbo'
exit 0
