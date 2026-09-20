# QUE EL MODO INVITADO NO APRENDA NADA DE QUIEN NO ERES TU (17/09).
#
# "Modo invitado. No aprendo nada ni miro tus cosas", dice Nova al ponerlo. No era verdad
# del todo: la guarda estaba en 6 funciones (estadisticas, habitos, perfil, musica, charla,
# ritmo) y faltaba en las que aprenden de lo que se DICE. Dentro de Invoke-FastCommand
# -1.600 lineas- la unica comprobacion cubria "leer los mensajes", asi que un invitado podia
# dejar notas en el diario, contactos, fechas, alias, recetas y traducciones.
#
# Esta prueba tiene dos mitades, y la segunda es la que importa a largo plazo:
#   1) que las 11 de hoy tengan la guarda;
#   2) que NINGUNA funcion de guardado nueva se quede sin ella sin darse cuenta. Si alguien
#      anade una, esta prueba falla hasta que decida: o la protege, o la declara exenta con
#      su motivo aqui abajo.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- las que guardan algo TUYO: tienen que mirar el modo invitado ---
$DEBEN = @(
    'Add-Memoria', 'Add-DiarioResumen', 'Add-Alias-Comando', 'Add-Traduccion', 'Add-Rechazo',
    'Add-VarianteReceta', 'Add-Receta', 'Set-NotaJuego', 'Save-Contactos', 'Add-TiempoJuego',
    'Add-Fecha', 'Add-Estadistica', 'Add-Habito', 'Add-HistorialMusica', 'Add-DatoPerfil',
    'Add-CharlaHora', 'Add-RitmoSeguimiento'
)
# --- y las que NO guardan nada personal: exentas, con el motivo ---
$EXENTAS = @{
    'Set-UI'                  = 'dibuja la capsula, no guarda nada'
    'Set-Cfg'                 = 'ajustes de Nova, no datos de nadie'
    'Set-VozVelocidad'        = 'un ajuste de la voz'
    'Save-Corrupto'           = 'aparta un archivo roto: hay que hacerlo siempre'
    'Save-EstadoParaDeshacer' = 'brillo y volumen para poder deshacer, se borra solo'
    'Save-DecisionPropia'     = 'lo que decidio Nova de si misma, no del invitado'
    'Add-RecetasInfoBase'     = 'recetas de fabrica, se cargan al arrancar'
    'Save-EntornoVistos'      = 'dispositivos vistos, del equipo y no de una persona'
    'Save-Captura'            = 'guarda la imagen que se acaba de pedir a proposito'
    'Save-Habitos'            = 'lo llama Add-Habito, que ya mira el modo'
    'Save-JuegosMem'          = 'lo llaman Set-NotaJuego y Add-TiempoJuego, ya protegidos'
    'Save-Listas'             = 'la lista de la compra se pide en voz alta, no se aprende sola'
    'Save-Recetas'            = 'lo llaman Add-Receta y Add-VarianteReceta, ya protegidos'
    'Save-Rechazos'           = 'lo llama Add-Rechazo, ya protegido'
    'Save-Recordatorios'      = 'un recordatorio se pide a proposito'
    'Save-Reglas'             = 'una regla se pide a proposito'
    'Save-TiempoJuego'        = 'lo llama Add-TiempoJuego, ya protegido'
    'Save-DatosPerfil'        = 'lo llama Add-DatoPerfil, que ya mira el modo'
    'Add-Perfil'              = 'crear un modo se pide a proposito y se dice en voz alta'
    'Set-UsoAhora'            = 'marca de uso del propio Nova'
    'Add-NubeTiempo'          = 'solo son milisegundos, y con invitado la nube ni se lanza (Start-NubeOir sale en su primera linea)'
}

$fns = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

Write-Host '  -- las que aprenden de lo que se dice: con guarda --'
foreach ($n in $DEBEN) {
    $f = @($fns | Where-Object { $_.Name -eq $n })
    if ($f.Count -eq 0) { Comp "$n existe" $false 'no la encuentro'; continue }
    Comp $n ($f[0].Extent.Text -match 'script:invitado') ''
}

Write-Host ''
Write-Host '  -- y ninguna nueva se cuela sin decidirlo --'
$sinDecidir = @()
foreach ($f in $fns) {
    if ($f.Name -notmatch '^(Add|Save|Set)-') { continue }
    $t = $f.Extent.Text
    if ($t -notmatch 'WriteAllText|AppendAllText|Write-Atomico') { continue }   # solo las que escriben a disco
    if ($DEBEN -contains $f.Name) { continue }
    if ($EXENTAS.ContainsKey($f.Name)) { continue }
    if ($t -match 'script:invitado') { continue }                              # protegida por su cuenta
    $sinDecidir += $f.Name
}
Comp 'ninguna funcion de guardado sin decidir' ($sinDecidir.Count -eq 0) $(if ($sinDecidir.Count) { "sin decidir: " + ($sinDecidir -join ', ') } else { '' })
if ($sinDecidir.Count) {
    Write-Host '     (protegela con la guarda, o anadela a $EXENTAS aqui arriba con su motivo)' -ForegroundColor Yellow
}

# --- y una de verdad, ejecutada: que con un invitado delante no acumule nada ---
Write-Host ''
Write-Host '  -- y no es solo que lo diga: se ejecuta --'
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$script:tiempoJuegoPend = @{}
$script:invitado = $true
Invoke-Expression (Traer 'Add-TiempoJuego')
Add-TiempoJuego 'It Takes Two' 30
Comp 'con invitado, no apunta tiempo de juego' ($script:tiempoJuegoPend.Count -eq 0) ("entradas: " + $script:tiempoJuegoPend.Count)
$script:invitado = $false
Add-TiempoJuego 'It Takes Two' 30
Comp 'y sin invitado sigue apuntando como siempre' ($script:tiempoJuegoPend['It Takes Two'] -eq 30) ("-> " + $script:tiempoJuegoPend['It Takes Two'])

# Add-Rechazo devuelve $false, no $null: el llamador hace "$apuntada = Add-Rechazo ..."
$script:invitado = $true
function ConvertTo-Plain([string]$t) { return $t.ToLower() }
Invoke-Expression (Traer 'Add-Rechazo')
$r = Add-Rechazo 'abre steam'
Comp 'Add-Rechazo devuelve false, no se traga el resultado' ($r -eq $false) ("-> '" + $r + "'")
$script:invitado = $false

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
