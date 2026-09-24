# CAMBIAR UN MODO HABLANDO (16/09).
#
# El 15/09 a las 11:40, braya dijo "recuerda que al poner modo juego abras Steam y
# Discord no lo abras" y Nova lo guardo como una NOTA en el diario: el modo juego
# siguio abriendo Discord, justo lo que pedia que dejara de hacer.
#
# Aqui se comprueba que esas frases cambian el modo de verdad y, sobre todo, lo que NO
# puede pasar: que una frase cualquiera meta basura dentro de un modo, que se quede un
# modo vacio, o que se toque un modo que no existe.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txt = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
foreach ($v in 'VERBOS') {
    if ($txt -notmatch ("(?m)^\`$$v = '(.+)'\s*$")) { throw "no encuentro $v" }
    Set-Variable -Name $v -Value $Matches[1]
}
$VERBOS_LISTA = (($VERBOS -replace '^\(\?:', '') -replace '\)$', '') -split '\|'
if ($txt -match '(?ms)^\$VERBOS_OIDOS = @\{.*?^\}') { Invoke-Expression $Matches[0] }
if ($txt -match '(?ms)^\$VERBOS_IMPERATIVO = @\{.*?^\}') { Invoke-Expression $Matches[0] }
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-Distancia')
Invoke-Expression (Traer 'Repair-Verb')
Invoke-Expression (Traer 'Test-Prop')
Invoke-Expression (Traer 'Resolve-ModoPorVoz')
Invoke-Expression (Traer 'Invoke-ModoEditar')
# como lo hace Nova: primero se analiza (sin tocar nada) y luego se aplica
function Edit-PerfilPorVoz([string]$t) {
    $d = Resolve-ModoPorVoz $t
    if (-not $d) { return $null }
    return (Invoke-ModoEditar $d)
}

# --- el mundo de mentira: un commands.json con los modos de verdad ---
$script:guardado = $null
function Add-Perfil([string]$nombre, [string[]]$ordenes) {
    $script:guardado = @{ nombre = $nombre; ordenes = @($ordenes) }
    return $true
}
function Log($m) { }
function Add-Estadistica($a, $b) { }
function Set-AcabaDeAprender { }
# "abre steam" y "abre spotify" si son ordenes; "haz la cena" no
function Test-FastCommand([string]$t) { return ((ConvertTo-Plain $t) -match '^(?:abre|cierra|pon)\s+\w+') }
$cmds = [pscustomobject]@{ perfiles = [pscustomobject]@{
    juego = @('pon el brillo al 100%', 'pon el volumen al 70%', 'abre discord')
    noche = @('pon el brillo al 15%', 'pon el volumen al 25%')
    silencio = @('pon el volumen al 0%') } }
$script:invitado = $false

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- quitar algo de un modo (el caso del 15/09) --"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'recuerda que en modo juego no abras discord'
Comp 'la frase tal cual la dijo braya' ($r -match '^Hecho' -and $script:guardado.nombre -eq 'juego' -and
    $script:guardado.ordenes.Count -eq 2 -and ($script:guardado.ordenes -notcontains 'abre discord')) "$r"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'en el modo juego quita discord'
Comp 'dicho de otra forma' ($r -match '^Hecho' -and ($script:guardado.ordenes -notcontains 'abre discord')) "$r"

Write-Host "  -- anadir algo a un modo --"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'al poner modo juego abras steam'
Comp 'el subjuntivo, como se dice al pedirlo' ($r -match '^Hecho' -and ($script:guardado.ordenes -contains 'abre steam')) "$r"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'cuando ponga el modo noche cierra discord'
Comp 'otro modo, otra orden' ($r -match '^Hecho' -and $script:guardado.nombre -eq 'noche' -and ($script:guardado.ordenes -contains 'cierra discord')) "$r"

Write-Host "  -- analizar NO puede cambiar nada --"
# Resolve-Fragment se usa tambien para VALIDAR ordenes (al crear una receta, por
# ejemplo): si el analisis guardara el modo, se cambiarian modos sin que nadie lo pida.
$script:guardado = $null
$d = Resolve-ModoPorVoz 'en modo juego no abras discord'
Comp 'analizar reconoce la frase' ($d -and $d.modo -eq 'juego' -and $d.quitar) "modo=$($d.modo) quitar=$($d.quitar)"
Comp 'y NO ha guardado nada todavia' (-not $script:guardado) ''
$null = Invoke-ModoEditar $d
Comp 'solo al aplicarlo se guarda' ($script:guardado -and $script:guardado.nombre -eq 'juego') ''

Write-Host "  -- lo que NO puede pasar --"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'en modo juego haz la cena'
Comp 'no se mete en un modo algo que Nova no sabe hacer' (($r -match 'No se hacer') -and -not $script:guardado) "$r"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'en modo silencio no pongas el volumen al 0%'
Comp 'no se deja un modo vacio' (($r -match 'se queda vacio') -and -not $script:guardado) "$r"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'en modo fiesta abre spotify'
Comp 'un modo que no existe no se toca' ((-not $r) -and -not $script:guardado) "$r"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'recuerda que manana tengo cita con el dentista'
Comp 'una nota normal sigue siendo una nota' ((-not $r) -and -not $script:guardado) "$r"
$script:guardado = $null
$r = Edit-PerfilPorVoz 'en modo juego no abras spotify'
Comp 'quitar algo que el modo no hace: lo dice, no rompe nada' (($r -match 'no hace nada') -and -not $script:guardado) "$r"

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
