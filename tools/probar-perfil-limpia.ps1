# LIMPIAR LO QUE CREE SABER DE BRAYA (23/09, funcion 5 de la tanda de funciones nuevas).
#
# perfil.md tiene 59 datos y el tope son 60: esta a un dato de llenarse, y a partir de ahi
# cada dato nuevo expulsa a otro. Y solo las 15 ultimas lineas viajan en cada prompt de la
# charla, o sea que la basura le vuelve hablada. Hoy OCHO de esos 59 se los comen dos nombres
# MAL OIDOS: cuatro lineas de un juego llamado "Amin"/"Amino" (las 16, 18, 19 y 20) y cuatro
# de un "Meramiau"/"Mira mio"/"Meramian" (24, 25, 27 y 34) que acabo inventando un gato que
# no existe. Y el caso que lo prueba: el 20/09 a las 23:09-23:11 sus DOS correcciones seguidas
# del nombre del juego se guardaron como dos datos NUEVOS encima del malo.
#
# LO QUE NO SE HACE: borrar por su cuenta. Lo que hay en su perfil es suyo. Se busca el par
# que mas se parece y se le PREGUNTA con las dos frases delante.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
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
# LA TRAJO OTRA IDEA Y ESTE BANCO NO SE ENTERO (24/09): sin ella moria a mitad, y
# encima salia con codigo 0. Lo vio la trampa nueva, no una persona.
Invoke-Expression (Traer 'Test-DatoTrato')
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
Write-Host '-- y no borra: PREGUNTA, y la pregunta se puede contestar --'
# ESTO SE EJECUTA, no se lee. Antes se comprobaba con -match sobre el fuente que existiera
# una rama 'perfilPar' en Complete-Confirmacion... y esa rama era INALCANZABLE: el canal de
# confirmacion solo transporta si/no -confirmacion.txt esta filtrado a ^(si|no)$, el oido
# entra en gramatica cerrada de si/no y el mando manda si/no-, asi que "la primera" no
# llegaba nunca y toda respuesta acababa en "no te he entendido". El banco estaba verde y
# la funcion no se podia completar. Ahora va por el selector de listas cerradas y aqui se
# ejecuta de verdad.
$script:guardado = $null
function Save-DatosPerfil($d) { $script:guardado = @($d) }
function Log($m) {}
function Add-Estadistica($a, $b) {}
$sw = [pscustomobject]@{}
$script:reloj = 0
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
Invoke-Expression (Traer 'Resolve-PerfilPar')

$script:datosFalsos = @('se llama Amino', 'usa Amino', 'braya tiene pareja')
$script:perfilPar = @{ a = 'se llama Amino'; b = 'usa Amino'; hasta = 60000 }
$d1 = Resolve-PerfilPar 1
Comp 'con la primera, se va la segunda' ($script:guardado -contains 'se llama Amino' -and -not ($script:guardado -contains 'usa Amino')) $d1

$script:guardado = $null
$script:perfilPar = @{ a = 'se llama Amino'; b = 'usa Amino'; hasta = 60000 }
$d2 = Resolve-PerfilPar 2
Comp 'con la segunda, se va la primera' ($script:guardado -contains 'usa Amino' -and -not ($script:guardado -contains 'se llama Amino')) $d2

$script:guardado = $null
$script:perfilPar = @{ a = 'se llama Amino'; b = 'usa Amino'; hasta = 60000 }
$d3 = Resolve-PerfilPar 0
Comp 'y si dice que las deje, no se toca nada' ($null -eq $script:guardado) $d3

$script:guardado = $null
$script:perfilPar = $null
$d4 = Resolve-PerfilPar 1
Comp 'sin pregunta abierta no borra nada' ($null -eq $script:guardado) $d4

# y las dos vias llegan aqui: la voz y el mando
Comp 'la voz tiene su patron' ($fuente -match "kind = 'perfilElige'; cual = 1") 'la primera / la segunda / las dos'
Comp 'y caduca al minuto' ($fuente -match 'perfilPar.hasta') 'la pregunta se contesta en el momento'
Comp 'el mando tambien' ($fuente -match "'perfil' \{ Say \(Resolve-PerfilPar") 'el selector de listas cerradas'
Comp 'y ya no usa el canal de si/no' ($fuente -notmatch "tipo = 'perfilPar'") 'ese canal solo transporta si y no'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  encuentra lo repetido y te deja elegir a ti'
exit 0
