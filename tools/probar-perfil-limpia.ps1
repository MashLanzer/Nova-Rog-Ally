# LIMPIAR LO QUE CREE SABER DE BRAYA (23/09, funcion 5 de la tanda de funciones nuevas).
#
# perfil.md tiene 59 datos y el tope son 60: esta lleno, asi que cada dato nuevo expulsa a
# otro. Y solo las 15 ultimas lineas viajan en cada prompt de la charla, o sea que la basura
# le vuelve hablada. Hoy nueve de esos huecos se los comen dos nombres MAL OIDOS: tres lineas
# de un juego llamado "Amino" ("se llama Amino", "usa Amino", "juega en Amino") y dos de un
# "Meramiau" que acabo inventando un gato que no existe. Y el caso que lo prueba: el 20/09 a
# las 23:09-23:11 sus DOS correcciones seguidas del nombre del juego se guardaron como dos
# datos NUEVOS encima del malo.
#
# LO QUE NO SE HACE: borrar por su cuenta. Lo que hay en su perfil es suyo. Se busca el par
# que mas se parece y se le PREGUNTA con las dos frases delante.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'ConvertTo-Suave')
Invoke-Expression (Traer 'Get-ParParecidoPerfil')
$script:datosFalsos = @()
function Get-DatosPerfil { return $script:datosFalsos }

Write-Host ''
Write-Host '-- la basura de su perfil de verdad --'
# las tres lineas del juego mal oido, tal cual estan en memoria\perfil.md
$script:datosFalsos = @(
    'juega a un juego llamado Amin', 'se llama Amino', 'usa Amino', 'juega en Amino',
    'braya conoce King Lear de Shakespeare', 'braya tiene sentido del humor',
    'prefiere que la musica se abra en YouTube en lugar de Spotify',
    'tiene 14 juegos instalados en Steam', 'braya juega Elden Ring', 'braya tiene pareja'
)
$par = Get-ParParecidoPerfil
Comp 'encuentra un par' ($null -ne $par) $(if ($par) { "$($par.parecido): $($par.a) || $($par.b)" } else { '' })
Comp 'y es el del nombre mal oido' ($par -and $par.a -match 'Amin' -and $par.b -match 'Amin') 'frases de dos y tres palabras'

Write-Host ''
Write-Host '-- pero NO empareja lo que no tiene que ver --'
# Los verbos comunes se caen solos porque van en minuscula: "prefiere" y "quiere" salian en
# dos o tres lineas cada uno y emparejaban cosas sin relacion.
$script:datosFalsos = @(
    'prefiere que la musica se abra en YouTube en lugar de Spotify',
    'Prefiere concentracion sin interrupciones durante el juego',
    'braya quiere recrear una foto con su pareja', 'quiere dejar un zoom configurado',
    'braya conoce King Lear de Shakespeare', 'braya tiene sentido del humor',
    'braya se va a cobrar de raro', 'tiene 14 juegos instalados', 'braya juega de noche',
    'le gusta la astronomia'
)
$par2 = Get-ParParecidoPerfil
Comp 'no empareja por "prefiere" ni "quiere"' ($null -eq $par2) $(if ($par2) { "$($par2.a) || $($par2.b)" } else { 'ninguno' })

Write-Host ''
Write-Host '-- con pocos datos no dice nada --'
$script:datosFalsos = @('braya juega Elden Ring', 'braya tiene pareja')
Comp 'con dos datos, no hay nada que limpiar' ($null -eq (Get-ParParecidoPerfil))

Write-Host ''
Write-Host '-- y no borra: pregunta --'
Comp 'arma una confirmacion' ($fuente -match "tipo = 'perfilPar'") ''
# sin el signo de apertura: el .ps1 se lee sin BOM y ese caracter no sobrevive
Comp 'con las dos frases delante' ($fuente -match 'Me quedo con la primera o con la segunda') ''
Comp 'y solo borra si braya elige' ($fuente -match "(?s)'perfilPar'.{0,900}Save-DatosPerfil") ''
Comp 'si no entiende, deja las dos' ($fuente -match 'No te he entendido; las dejo las dos') 'lo que hay en su perfil es suyo'
Comp 'y puede decir que no' ($fuente -match 'Vale, las dejo las dos') ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  encuentra lo repetido y te deja elegir a ti'
exit 0
