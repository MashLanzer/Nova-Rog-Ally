# QUE APRENDA A DECIR LOS NOMBRES DE SUS JUEGOS (23/09, idea 18).
#
# EL HUECO: cuando braya contesta "no" a "ELDEN RING?", hoy Nova solo apunta en el log y dice
# "vale, lo dejo". NO APRENDE NADA, asi que el mismo titulo mal oido vuelve a fallar manana.
# Y Add-Traduccion guarda la FRASE entera, asi que aprender "abre gus gus dup" no sirve para
# "cierra gus gus dup": lo que hay que atar es el SONIDO al JUEGO.
#
# EL DATO: el oido acierta el 70,4 % y lo peor son los titulos en ingles -"Jolon Nights",
# "gus gus dup", "Aura pic", "contenguarme", "cierra en la ring"-. Find-JuegoPorSonido rescata
# 12 de 34 titulos mal oidos de las dos tandas dirigidas: quedan 22 que hoy NO se recuperan.
#
# LO QUE MAS VIGILA ESTE BANCO, y es lo que puede salir peor:
#  1. que la clave se guarde SIN ARTICULO. Get-ClaveSonido pega las palabras, asi que "el
#     warning" se vuelve 'elguarning' y eso se parece MAS a 'eldenring' que a
#     'kontentguarning'. Guardarla con articulo resucitaria el fallo del 21/09, pero ya sin
#     preguntar: lo APRENDIDO abriria ELDEN RING teniendo Content Warning instalado.
#  2. que CERRAR siga preguntando siempre, aunque lo aprendido diga otra cosa: ahi se mata un
#     proceso con la partida abierta.
#  3. que con la tabla vacia todo responda EXACTAMENTE como hoy.
$ErrorActionPreference = 'Stop'
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
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el mundo de mentira ----------------------------------------------------
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('oid-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
$script:invitado = $false
$script:juegosOidos = $null
$script:sonidoAprendido = $false
function Log([string]$m) { }
function Save-Corrupto($a, $b) { }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
foreach ($f in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-ClaveSonido', 'Get-Distancia',
                 'Get-JuegosOidosPath', 'Get-JuegosOidos', 'Save-JuegoOido', 'Remove-JuegoOido',
                 'Find-JuegoPorSonido')) { Invoke-Expression (Traer $f) }

# su biblioteca de verdad, con los titulos de dos palabras para arriba
$script:Juegos = @(
    @{ nombre = 'ELDEN RING' }, @{ nombre = 'Content Warning' }, @{ nombre = 'Black Myth: Wukong' },
    @{ nombre = 'Wallpaper Engine' }, @{ nombre = 'PEAK' }, @{ nombre = 'Roblox' },
    @{ nombre = 'Hollow Knight' }, @{ nombre = 'It Takes Two' }, @{ nombre = 'Cat Quest III' },
    @{ nombre = 'Goose Goose Duck' }, @{ nombre = 'MECCHA CHAMELEON' }, @{ nombre = 'MIMESIS' })
$script:ClavesJuegos = $null

function Suena([string]$dicho, [string]$verbo = 'abre') {
    $frase = "$verbo $dicho"
    $j = Find-JuegoPorSonido $dicho $frase 0.5
    if ($j) { return [string]$j.nombre }
    return ''
}
function Limpia {
    $script:juegosOidos = $null
    try { Remove-Item -LiteralPath (Get-JuegosOidosPath) -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host ''
Write-Host '-- 1. CON LA TABLA VACIA, todo igual que hoy --'
Limpia
Comp '"cierra en la ring" sigue dando ELDEN RING' ((Suena 'en la ring' 'cierra') -eq 'ELDEN RING') "$(Suena 'en la ring' 'cierra')"
Comp '"el warning" sigue dando Content Warning' ((Suena 'el warning') -eq 'Content Warning') "$(Suena 'el warning')"
Comp '"el wukong" sigue dando Black Myth' ((Suena 'el wukong') -eq 'Black Myth: Wukong') "$(Suena 'el wukong')"
Comp '"gus gus dup" sigue dando Goose Goose Duck' ((Suena 'gus gus dup') -eq 'Goose Goose Duck') "$(Suena 'gus gus dup')"
Comp 'y "todo" sigue sin ser un juego' ((Suena 'todo' 'cierra') -eq '') "$(Suena 'todo' 'cierra')"

Write-Host ''
Write-Host '-- 2. y lo que hoy NO se recupera, con una correccion, si --'
Limpia
# "aura pic" es de su lista de titulos mal oidos y hoy NO lo recupera nadie: comprobado
# ejecutando Find-JuegoPorSonido con su biblioteca. "jolon nights" si lo rescata ya el
# parecido, asi que no serviria para ver esto.
Comp '"aura pic" hoy no da nada' ((Suena 'aura pic') -eq '') "$(Suena 'aura pic')"
$ok = Save-JuegoOido 'aura pic' 'PEAK'
Comp 'se puede apuntar' ($ok) ''
$script:juegosOidos = $null   # como si Nova se reiniciara
Comp 'y ahora si da PEAK' ((Suena 'aura pic') -eq 'PEAK') "$(Suena 'aura pic')"

Write-Host ''
Write-Host '-- 3. LA CLAVE SE GUARDA SIN ARTICULO --'
# Con articulo, "el warning" se vuelve elguarning, que se parece MAS a eldenring: lo
# aprendido abriria ELDEN RING teniendo Content Warning instalado, y ya sin preguntar.
Limpia
[void](Save-JuegoOido 'el warning' 'Content Warning')
$script:juegosOidos = $null
Comp 'guardando "el warning", "warning" tambien lo encuentra' ((Suena 'warning') -eq 'Content Warning') "$(Suena 'warning')"
Comp 'y "el warning" sigue dando Content Warning' ((Suena 'el warning') -eq 'Content Warning') "$(Suena 'el warning')"
$tablaK = @((Get-JuegosOidos).Keys)
Comp 'y la clave guardada no empieza por el articulo' (@($tablaK | Where-Object { $_ -like 'el*' }).Count -eq 0) "$($tablaK -join ', ')"

Write-Host ''
Write-Host '-- 4. lo aprendido NO abre la puerta a lo que nunca es un juego --'
Limpia
[void](Save-JuegoOido 'aura pic' 'PEAK')
$script:juegosOidos = $null
Comp '"todo" sigue sin ser un juego' ((Suena 'todo' 'cierra') -eq '') "$(Suena 'todo' 'cierra')"
Comp 'y "esto" tampoco' ((Suena 'esto' 'cierra') -eq '') "$(Suena 'esto' 'cierra')"

Write-Host ''
Write-Host '-- 5. lo que no se puede aprender --'
Limpia
Comp 'un juego que no tiene, no se apunta' (-not (Save-JuegoOido 'lo que sea' 'Juego Inventado 9')) ''
Comp 'una clave de dos letras, tampoco' (-not (Save-JuegoOido 'el' 'ELDEN RING')) 'casaria con todo'
$script:invitado = $true
Comp 'y un invitado no ensena nada' (-not (Save-JuegoOido 'jolon nights' 'Hollow Knight')) ''
$script:invitado = $false
Comp 'asi que la tabla sigue vacia' ((Get-JuegosOidos).Count -eq 0) "$((Get-JuegosOidos).Count)"

Write-Host ''
Write-Host '-- 6. una entrada que apunta a un juego desinstalado se ignora --'
Limpia
[void](Save-JuegoOido 'aura pic' 'PEAK')
$script:juegosOidos = $null
$script:Juegos = @($script:Juegos | Where-Object { $_.nombre -ne 'PEAK' })
$script:ClavesJuegos = $null
Comp 'no devuelve un juego que ya no esta' ((Suena 'aura pic') -ne 'PEAK') "$(Suena 'aura pic')"
$script:Juegos += @{ nombre = 'PEAK' }
$script:ClavesJuegos = $null

Write-Host ''
Write-Host '-- 7. y se puede olvidar (regla 2) --'
Limpia
[void](Save-JuegoOido 'aura pic' 'PEAK')
$script:juegosOidos = $null
Comp 'esta puesto' ((Suena 'aura pic') -eq 'PEAK') ''
Comp 'se quita' (Remove-JuegoOido 'aura pic') ''
$script:juegosOidos = $null
Comp 'y vuelve a comportarse como al principio' ((Suena 'aura pic') -eq '') "$(Suena 'aura pic')"
Comp 'quitar lo que no hay, lo dice' (-not (Remove-JuegoOido 'nada de nada')) ''
# y las dos formas de pedirlo hablando, sacadas del fuente
$patO = ''
foreach ($l in ($fuente -split "`r?`n")) {
    if ($l -match "'(\^\(\?:olvida\|olvidate de\|borra\|quita\)[^']+)'") { $patO = $Matches[1]; break }
}
if (-not $patO) { Write-Host '  MAL  no encuentro el patron de olvidar'; exit 1 }
Comp '"olvida que el warning es content warning" entra' ('olvida que el warning es content warning' -match $patO) ''
$patO2 = ''
foreach ($l in ($fuente -split "`r?`n")) {
    if ($l -match 'lo que aprendiste de' -and $l -match "'(\^[^']+)'") { $patO2 = $Matches[1]; break }
}
if (-not $patO2) { Write-Host '  MAL  no encuentro la segunda forma de olvidar'; exit 1 }
Comp 'y "olvida lo que aprendiste de el warning" tambien' ('olvida lo que aprendiste de el warning' -match $patO2) ''

Write-Host ''
Write-Host '-- 8. CERRAR SIGUE PREGUNTANDO SIEMPRE --'
# Ahi se mata un proceso con la partida abierta: ni siquiera lo aprendido se ejecuta solo.
$fc = $fuente
$iCerrar = $fc.IndexOf('$jC = Find-JuegoPorSonido')
if ($iCerrar -lt 0) { Write-Host '  MAL  no encuentro el camino de cerrar'; exit 1 }
$trozoC = $fc.Substring($iCerrar, [Math]::Min(1800, $fc.Length - $iCerrar))
Comp 'cerrar marca la duda SIEMPRE' ($trozoC -match '\$script:dudosa = \[string\]\$jC\.nombre') ''
Comp 'y no mira si ya estaba aprendido' ($trozoC -notmatch 'sonidoAprendido') 'ahi se mata un proceso'
$iAbrir = $fc.IndexOf('$jSonido = Find-JuegoPorSonido')
$trozoA = $fc.Substring($iAbrir, [Math]::Min(1200, $fc.Length - $iAbrir))
Comp 'pero abrir si se fia de lo que ya corrigio' ($trozoA -match 'sonidoAprendido') 'ya lo dijo el una vez'

Write-Host ''
Write-Host '-- 9. la ventana de 60 s y el nombre POR ESCRITO --'
$lineaAp = @($fuente -split "`r?`n" | Where-Object { $_ -match 'se llama\|se dice\|era\|es\|se llamaba' })[0]
if (-not $lineaAp) { Write-Host '  MAL  no encuentro el patron de aprender'; exit 1 }
$iAp = $fuente.IndexOf($lineaAp)
$trozoAp = $fuente.Substring($iAp, 900)
Comp 'la guarda de los 60 s va en la misma condicion' ($trozoAp -match 'ultimoSonidoDudoso -and' -and $trozoAp -match '60000') ''
Comp 'y el juego se busca POR ESCRITO' ($trozoAp -match 'Find-Juego \$nomJA') 'aprender de un sonido con otro sonido es aprender de una suposicion'
Comp 'nunca por sonido' ($trozoAp -notmatch 'Find-JuegoPorSonido \$nomJA') ''

try { Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  lo que le corriges una vez, ya no se le olvida'
exit 0
