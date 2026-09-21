# EL PERFIL SOLO GUARDA LO QUE BRAYA DICE DE SI MISMO (16/09).
#
# El 15/09 su perfil acabo con 16 lineas, y SIETE eran la misma cosa mal entendida y
# contradiciendose ("no le gusta la musica electronica" / "le gusta musica electronica"
# / "tiene preferencias sobre musica electronica"...). Otras dos eran quejas suyas
# convertidas en dato permanente, y otra una deduccion de haberle oido decir "mi amor".
# Todo eso viaja con CADA peticion al cerebro, asi que una frase inventada envenena
# todas las respuestas siguientes.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txt = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
if ($txt -match "(?m)^\`$RE_DATO_SENSIBLE = '(.+)'\s*$") { $RE_DATO_SENSIBLE = $Matches[1] } else { throw 'no encuentro RE_DATO_SENSIBLE' }
$PerfilMax = 60
# ConvertTo-Plain ENTRA AQUI DESDE EL 21/09: Add-DatoPerfil la usa para mirar el dato
# SIN TILDES antes de compararlo con el patron de lo sensible, que esta escrito sin
# ellas ('diagnostic' no casa con "diagnostico" jamas). Sin traerla, este banco reventaba
# por dentro y la seccion 7 lo cantaba.
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'ConvertTo-Suave')
Invoke-Expression (Traer 'Add-DatoPerfil')

# el mundo de mentira: el perfil en memoria, sin tocar el de verdad
$script:perfilFalso = @()
function Get-DatosPerfil { return @($script:perfilFalso) }
function Save-DatosPerfil([string[]]$d) { $script:perfilFalso = @($d) }
function Log($m) { }
function Add-Estadistica($a, $b) { }
function Set-AcabaDeAprender { }
$script:invitado = $false

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- lo que SI se guarda --"
# LA INSTRUCCION SI SE GUARDA, AUNQUE NOMBRE A NOVA (20/09). El 18/09 a las 20:12 braya
# dijo 'cuando te digo que pongas una cancion SIEMPRE tiene que ser en YouTube', Nova
# contesto 'Entendido' y DOS SEGUNDOS despues el log decia 'PERFIL: no guardo lo que habla
# de mi'. Veinte segundos mas tarde volvio a abrir Spotify y braya se quejo. La regla de
# 'no hablar de mi' esta para las QUEJAS, no para las ordenes que el da. Este caso existe
# para que no vuelva a perderse.
Comp 'una INSTRUCCION tuya, aunque me nombre' ([bool](Add-DatoPerfil 'Quiere que Nova ponga musica siempre en YouTube' 'prueba')) ''
# Y "NO ME LLAMES ASI" TAMBIEN ES UNA INSTRUCCION (21/09). La noche del 20/09 braya pidio
# CUATRO veces que dejaran de llamarle "man" y "tio", la ultima diciendo "guardalo en
# memoria". Las cuatro correcciones murieron en este filtro: nombran a Nova y no llevan
# siempre/nunca/cada vez que. El log lo ensena cuatro veces: "PERFIL: no guardo lo que
# habla de mi: braya no quiere que Nova lo llame 'tio'". Y Nova siguio diciendo "tio"
# toda la noche. Estas cuatro son las frases REALES que saco el revisor del cerebro.
Comp 'no le gusta que Nova le diga man' ([bool](Add-DatoPerfil "No le gusta que Nova le diga 'man'" 'prueba')) ''
Comp 'no quiere que Nova lo llame tio' ([bool](Add-DatoPerfil "braya no quiere que Nova lo llame 'tio'" 'prueba')) ''
$antesDup = @(Get-DatosPerfil).Count
[void](Add-DatoPerfil "braya prefiere que Nova no le diga 'tio'" 'prueba')
[void](Add-DatoPerfil "no le gusta que Nova use la palabra 'tio'" 'prueba')
Comp 'decirlo de otras formas no lo duplica' ((@(Get-DatosPerfil).Count) -eq $antesDup) ("$antesDup datos")
Comp 'y la instruccion quedo guardada' (@(Get-DatosPerfil | Where-Object { "$_" -match "man|tio" }).Count -ge 1) ((@(Get-DatosPerfil) | Where-Object { "$_" -match 'man|tio' }) -join ' | ')
# y los controles: una QUEJA sobre Nova sigue sin entrar, que es para lo que se puso el filtro
Comp 'pero una queja sobre mi sigue fuera' (-not [bool](Add-DatoPerfil 'Braya se queja de que Nova repite mucho las respuestas' 'prueba')) ''
Comp 'y hablar de mi tampoco entra' (-not [bool](Add-DatoPerfil 'Quiere que Nova sepa quien la creo' 'prueba')) ''
Comp 'ni una opinion sobre como funciono' (-not [bool](Add-DatoPerfil 'Braya siente que Nova no entiende bien lo que dice' 'prueba')) ''
$script:perfilFalso = @()
Comp 'una ruta suya' ([bool](Add-DatoPerfil 'Su carpeta de capturas es D:\Capturas' 'prueba')) ''
Comp 'su juego favorito' ([bool](Add-DatoPerfil 'Su juego favorito es Hollow Knight' 'prueba')) ''
Comp 'y quedan los dos' ($script:perfilFalso.Count -eq 2) ($script:perfilFalso -join ' | ')

Write-Host "  -- el caso real del 15/09: siete lineas sobre lo mismo --"
$script:perfilFalso = @()
$null = Add-DatoPerfil 'A braya no le gusta la musica electronica' 'prueba'
foreach ($d in 'Le gusta musica electronica de ciertos estilos',
               'No le gusta musica electronica de otros estilos',
               'braya le gusta musica electronica',
               'Braya tiene preferencias sobre musica electronica',
               'braya no le gusta cierto estilo de musica electronica que escuchaba recientemente') {
    $null = Add-DatoPerfil $d 'prueba'
}
Comp 'del mismo tema solo queda UNA' ($script:perfilFalso.Count -eq 1) ($script:perfilFalso -join ' | ')

Write-Host "  -- lo que NO se guarda --"
$script:perfilFalso = @()
Comp 'una queja sobre Nova' (-not (Add-DatoPerfil 'Braya considera que Nova se equivoca frecuentemente' 'prueba')) ''
Comp 'otra queja' (-not (Add-DatoPerfil 'Braya siente que Nova no entiende bien lo que dice' 'prueba')) ''
Comp 'algo que habla del asistente' (-not (Add-DatoPerfil 'Quiere que Nova sepa quien la creo' 'prueba')) ''
Comp 'una deduccion entre parentesis' (-not (Add-DatoPerfil "Braya tiene una pareja (la llama 'mi amor')" 'prueba')) ''
Comp 'algo que empieza por "parece"' (-not (Add-DatoPerfil 'Parece que braya juega por las noches' 'prueba')) ''
Comp 'una contrasena' (-not (Add-DatoPerfil 'Su contrasena del banco es 1234' 'prueba')) ''
Comp 'algo de salud' (-not (Add-DatoPerfil 'Braya toma un medicamento para dormir' 'prueba')) ''
Comp 'y el perfil sigue vacio' ($script:perfilFalso.Count -eq 0) ($script:perfilFalso -join ' | ')

Write-Host "  -- y dos temas distintos SI caben --"
$script:perfilFalso = @()
$null = Add-DatoPerfil 'Su carpeta de capturas es D:\Capturas' 'prueba'
$null = Add-DatoPerfil 'Juega casi siempre a It Takes Two con su pareja' 'prueba'
Comp 'no se estorban entre si' ($script:perfilFalso.Count -eq 2) ($script:perfilFalso -join ' | ')

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
