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
