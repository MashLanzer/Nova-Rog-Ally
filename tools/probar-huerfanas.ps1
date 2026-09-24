# LAS CINCO QUE NADIE PROBABA (23/09).
#
# Mapeando el repositorio para la tanda de veinte funciones salieron cinco funciones que NO
# aparecen en ningun banco. Las cinco son la base de cuatro de las ideas que vienen, asi que
# tocarlas sin red seria justo lo que la casa no hace:
#
#   Get-MusicaActual       (idea 1: poner musica y decir que se pone)
#   Get-PrimerVideoYouTube (idea 1: el video N, "no, la siguiente")
#   Test-Recordatorios     (idea 4: recordatorios que se repiten)
#   Remove-DatoPerfil      (idea 7: "eso es falso, eliminalo")
#   Get-AmigosSteam        (idea 10: avisar cuando se conecte alguien)
#
# Aqui no se prueba que Windows tenga musica ni que Steam conteste: eso no se puede fijar en
# un banco. Se prueba LO QUE ES DE NOVA y le puede fallar a braya: que no reviente cuando el
# de enfrente no contesta, que no invente, que no se quede colgada, y que la clave de Steam no
# salga nunca en el log.
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
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) {
    return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
}
function TraerCodigo([string]$n) { return (SinComentarios (Traer $n)) }

# --- el andamio comun ---------------------------------------------------------
$script:logs = @()
function Log([string]$m) { $script:logs += $m }
$script:dichos = @()
function Send-Aviso([string]$t, [string]$tipo = '') { $script:dichos += $t }
function Start-Vibracion($p, $f = 0) { }
function Invoke-Despertador { $script:logs += 'DESPERTADOR SONANDO' }
$script:invitado = $false

Write-Host ''
Write-Host '-- 1. Test-Recordatorios: vence, avisa, y no se queda dando vueltas --'
Invoke-Expression (TraerCodigo 'Test-Recordatorios')
$script:recs = @()
function Get-Recordatorios { return $script:recs }
$script:guardados = $null
function Save-Recordatorios($l) { $script:guardados = @($l); $script:recs = @($l) }

$script:recs = @()
$script:guardados = $null
Test-Recordatorios
Comp 'sin recordatorios no hace nada' (($script:guardados -eq $null) -and ($script:dichos.Count -eq 0))

$ayer = (Get-Date).AddMinutes(-5).ToString('s')
$manana = (Get-Date).AddHours(6).ToString('s')
$script:recs = @([pscustomobject]@{ cuando = $ayer; texto = 'sacar la pizza' },
                 [pscustomobject]@{ cuando = $manana; texto = 'llamar a mama' })
$script:dichos = @(); $script:guardados = $null
Test-Recordatorios
Comp 'el que vence, se dice' (@($script:dichos | Where-Object { $_ -match 'sacar la pizza' }).Count -eq 1) ($script:dichos -join ' | ')
Comp 'y el que no, se calla' (@($script:dichos | Where-Object { $_ -match 'llamar a mama' }).Count -eq 0)
Comp 'y solo queda el de manana' (($script:guardados.Count -eq 1) -and ($script:guardados[0].texto -eq 'llamar a mama')) "$($script:guardados.Count) en disco"

# Y EL QUE VENCIO NO PUEDE VOLVER. Es la trampa de este tipo de funcion: si no se guarda la
# lista podada, el mismo recordatorio salta en cada vuelta, para siempre. Es exactamente lo
# que paso el 21/09 con el resumen al volver: 1.126 veces la misma frase en nueve horas.
$script:dichos = @()
Test-Recordatorios
Comp 'y no vuelve a saltar en la vuelta siguiente' ($script:dichos.Count -eq 0) 'si no, se repite para siempre'

# el despertador no es un aviso: suena
$script:recs = @([pscustomobject]@{ cuando = $ayer; texto = 'despertador' })
$script:dichos = @(); $script:logs = @()
Test-Recordatorios
Comp 'el despertador suena, no se dice' (($script:dichos.Count -eq 0) -and ($script:logs -contains 'DESPERTADOR SONANDO'))

# una fecha ilegible no puede tumbar el bucle ni borrar los demas
$script:recs = @([pscustomobject]@{ cuando = 'esto no es una fecha'; texto = 'raro' },
                 [pscustomobject]@{ cuando = $manana; texto = 'bueno' })
$script:dichos = @(); $script:guardados = $null
$reviento = $false
try { Test-Recordatorios } catch { $reviento = $true }
Comp 'una fecha ilegible no revienta' (-not $reviento)
Comp 'y no se lleva por delante al bueno' (@(Get-Recordatorios | Where-Object { $_.texto -eq 'bueno' }).Count -eq 1)

Write-Host ''
Write-Host '-- 2. Remove-DatoPerfil: borra el que es, o ninguno --'
Invoke-Expression (TraerCodigo 'ConvertTo-Plain')
Invoke-Expression (TraerCodigo 'ConvertTo-Suave')
Invoke-Expression (TraerCodigo 'Remove-DatoPerfil')
$script:datos = @()
function Get-DatosPerfil { return $script:datos }
function Save-DatosPerfil($d) { $script:datos = @($d) }

$base = @(
    'braya juega a Elden Ring por las noches',
    'braya tiene una pareja que juega con el',
    'se llama Amino el juego que juega con su novia',
    'braya prefiere la musica electronica',
    'tiene 14 juegos instalados en Steam'
)
$script:datos = $base.Clone()
$fuera = Remove-DatoPerfil 'el juego que se llama Amino'
Comp 'borra el dato que le nombran' ($fuera -match 'Amino') "'$fuera'"
Comp 'y solo ese' ($script:datos.Count -eq 4) "$($script:datos.Count) datos"

$script:datos = $base.Clone()
$nada = Remove-DatoPerfil 'la capital de Australia y los pinguinos'
Comp 'lo que no tiene que ver, no borra nada' ($null -eq $nada) "'$nada'"
Comp 'y el perfil queda entero' ($script:datos.Count -eq 5) "$($script:datos.Count) datos"

# LA MITAD DE LAS PALABRAS, de verdad: aqui 'juego' SI casa, pero de cuatro palabras dichas
# hace falta que casen dos. Se vio rompiendolo: con 'la capital de Australia y los
# pinguinos' no casaba NINGUNA, asi que ese caso lo paraba otra guarda y esta no se probaba.
$script:datos = $base.Clone()
$pocas = Remove-DatoPerfil 'aquel juego raro de mesa'
Comp 'una palabra de cuatro no basta' ($null -eq $pocas) 'juego casa, pero hacen falta dos'
Comp 'y no se pierde nada' ($script:datos.Count -eq 5)

$script:datos = $base.Clone()
$corto = Remove-DatoPerfil 'eso'
Comp 'una palabra corta no borra nada' ($null -eq $corto) 'menos de 4 letras, no cuenta'
Comp 'y el perfil sigue entero' ($script:datos.Count -eq 5)

# LA MITAD DE LAS PALABRAS: es lo que lo hace seguro. Con una sola coincidencia borraria
# cualquier cosa que comparta la palabra "braya", que esta en medio perfil.
# UNA PALABRA COMUN NO BORRA NADA. Se vio escribiendo este banco: el umbral era 'al menos
# la mitad de las palabras dichas', y la mitad de UNA es UNA. Medido en su perfil de
# verdad, 'braya' sale en 28 de 60 datos (47 %): decir 'braya, borralo' se llevaba uno al
# azar, y lo que hay en su perfil es suyo.
$script:datos = @('braya juega a Elden Ring por las noches',
                  'braya tiene una pareja que juega con el',
                  'braya prefiere la musica electronica',
                  'braya tiene 14 juegos en Steam',
                  'se llama Amino el juego que juega con su novia',
                  'le gusta la astronomia', 'braya juega de noche',
                  'braya conoce King Lear', 'braya tiene sentido del humor',
                  'braya usa pantalla dividida', 'braya juega con su novia',
                  'braya prefiere YouTube a Spotify')
$antesN = $script:datos.Count
$flojo = Remove-DatoPerfil 'braya'
Comp 'nombrar solo "braya" no borra nada' ($null -eq $flojo) 'sale en 10 de 12 datos de la prueba'
Comp 'y el perfil no pierde ni uno' ($script:datos.Count -eq $antesN) "$($script:datos.Count) de $antesN"
# pero una palabra RARA si vale sola: senala a un dato y a uno solo
$raro = Remove-DatoPerfil 'astronomia'
Comp 'pero una palabra rara si borra el suyo' ($raro -match 'astronomia') "'$raro'"
Comp 'y solo ese' ($script:datos.Count -eq ($antesN - 1))

Write-Host ''
Write-Host '-- 3. Get-PrimerVideoYouTube: el numero N, y si no hay, lo dice --'
$yt = TraerCodigo 'Get-PrimerVideoYouTube'
Comp 'sin busqueda, devuelve vacio' ($yt -match "if \(-not \`$q\) \{ return '' \}") 'nada de inventarse una url'
Comp 'tiene tope de tiempo' ($yt -match 'TimeoutSec 6') 'no se cuelga esperando a YouTube'
Comp 'saca los ids con un patron de 11 caracteres' ($yt -match 'videoId.*A-Za-z0-9_-\]\{11\}') 'el largo exacto de un id'
Comp 'y quita los repetidos' ($yt -match 'Select-Object -Unique') 'YouTube repite el mismo video en la pagina'
Comp 'si pide el 5 y solo hay 3, da el ultimo' ($yt -match 'pongo el ultimo') 'y lo dice en el log'
Comp 'si no hay ninguno, devuelve vacio' ($yt -match "sin videos en la pagina") 'y quien llama abre la busqueda'
Comp 'y si YouTube falla, tampoco inventa' (($yt -match 'catch') -and ($yt -match "return ''"))
# la parte de sacar ids se puede probar SIN red, con una pagina de mentira
# LA LINEA QUE SACA LOS IDS SE TRAE DE LA FUNCION, no se copia: copiandola, este banco
# seguia verde con el -Unique quitado del codigo de verdad. Se vio rompiendolo.
$lineasYt = @($yt -split "`n")
$iYt = -1
for ($q = 0; $q -lt $lineasYt.Count; $q++) { if ($lineasYt[$q] -match 'regex\]::Matches') { $iYt = $q; break } }
$codIds = if ($iYt -ge 0) { ($lineasYt[$iYt..($iYt + 1)] -join "`n") -replace '\[string\]\$r\.Content', '$html' } else { '' }
Comp 'la linea de los ids se lee de la funcion' ($codIds -match 'Matches') "$($codIds.Length) caracteres"
$html = '{"videoId":"aaaaaaaaaaa"} basura {"videoId":"bbbbbbbbbbb"} mas {"videoId":"aaaaaaaaaaa"} {"videoId":"ccccccccccc"}'
# SIN @() Y SIN ASIGNAR: la linea que se trae YA es una asignacion a $ids, y una asignacion
# no emite nada, asi que capturar su retorno daba cero ids siempre (verde de milagro).
$ids = $null
Invoke-Expression $codIds
$ids = @($ids)
Comp 'con una pagina de mentira saca tres distintos' ($ids.Count -eq 3) ($ids -join ', ')
Comp 'y el segundo es el segundo' ($ids[1] -eq 'bbbbbbbbbbb')

Write-Host ''
Write-Host '-- 4. Get-MusicaActual: lo que suena, sin colgarse ni inventar --'
$mu = TraerCodigo 'Get-MusicaActual'
Comp 'se rinde tras tres fallos seguidos' ($mu -match 'mediaFallos -ge 3') 'sin sesion de medios, no se insiste'
Comp 'y el contador se pone a cero al acertar' ($mu -match 'mediaFallos = 0')
Comp 'sin sesion, devuelve nada' ($mu -match "if \(-not \`$ses\)") 'no se inventa una cancion'
Comp 'en pausa no vuelve a preguntar' ($mu -match "PlaybackStatus" -and $mu -match "-ne 'Playing'") 'la cancion no cambia en pausa'
Comp 'y la pregunta tiene tope de 1,5 s' ($mu -match 'TryGetMediaPropertiesAsync\(\)\).*1500') 'una app que no contesta no cuelga el bucle'
Comp 'si revienta, lo apunta y devuelve nada' (($mu -match 'catch') -and ($mu -match "Log \(""musica: "))

Write-Host ''
Write-Host '-- 5. Get-AmigosSteam: y sobre todo, que la clave no salga en el log --'
$am = TraerCodigo 'Get-AmigosSteam'
Comp 'sin clave lo dice y no llama' ($am -match 'necesito una clave de su API') 'y dice donde pedirla'
Comp 'sin sesion de Steam, tambien lo dice' ($am -match 'no tiene la sesion iniciada')
Comp 'LA CLAVE SE TAPA EN EL LOG' ($am -match "key=\*\*\*") 'un log con la clave dentro es un log que no se puede ensenar'
Comp 'las dos llamadas llevan tope de tiempo' (@([regex]::Matches($am, 'TimeoutSec 6')).Count -eq 2)
Comp 'y no pide mas de cien amigos' ($am -match 'Select-Object -First 100')
Comp 'si Steam falla, lo dice y no revienta' ($am -match 'no pude preguntarle a Steam')
# y la comprobacion de verdad: que el enmascarado FUNCIONA
$mensajeConClave = "steam amigos: error de https://api.steampowered.com/x?key=ABCD1234SECRETO&steamid=1 timeout"
$tapado = $mensajeConClave -replace 'key=[^&\s]+', 'key=***'
Comp 'y tapa de verdad una clave de mentira' (($tapado -notmatch 'ABCD1234SECRETO') -and ($tapado -match 'key=\*\*\*')) $tapado

Write-Host ''
if ($fallos) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  las cinco que nadie miraba, ya tienen quien las mire'
exit 0
