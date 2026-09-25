# LO QUE DURA UN RATO NO OCUPA UNA PLAZA (25/09, idea 4)
#
# LO MEDIDO hoy sobre el perfil real de braya: 21 de sus 57 datos -el 37 %- son estados
# pasajeros guardados como si fueran rasgos suyos. Una muestra de verdad:
#   "esta en su cuarto"
#   "acaba de completar un juego"
#   "ha matado alrededor de veinte zombies en menos de veinte minutos"
#   "usa espadas de metal en el juego"
# Eso ocupa 21 de las 60 plazas de un perfil lleno, expulsa cosas que si valen, Y ADEMAS viaja
# al cerebro en cada peticion: son tokens pagados en cada consulta por saber que una vez mato
# veinte zombies.
#
# LA GUARDA YA EXISTE desde el 24/09 (Test-DatoPasajero) pero solo mira lo que ENTRA: los 21
# que ya estaban dentro se quedaron dentro.
#
# LO QUE SE HACE, y por que se puede hacer sin preguntar: los pasajeros salen del perfil -que
# es el que viaja y tiene 60 plazas- y se quedan en la memoria permanente, que no tiene tope y
# no viaja. NO SE PIERDE NADA: si algun dia hace falta uno, esta escrito. Si hubiera que
# borrarlos de verdad, esto iria con pregunta.
#
# Y LA SALVAGUARDA MANDA: Test-DatoPasajero tiene dentro una lista de rasgos que gana siempre
# (RE_DATO_RASGO). Un dato que parezca pasajero pero encaje ahi NO se mueve.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. existe la limpieza y corre una sola vez --'
Comp 'existe Clear-PerfilPasajeros' ($sinCom -match 'function Clear-PerfilPasajeros') ''
$usos = @([regex]::Matches($sinCom, '(?<!function )Clear-PerfilPasajeros')).Count
Comp 'y se llama al arrancar' ($usos -ge 1) "$usos uso(s)"
Comp 'usa la guarda que YA existia' ($sinCom -match 'Clear-PerfilPasajeros[\s\S]{0,1200}Test-DatoPasajero') 'no un criterio nuevo'
Comp 'y lo que saca va a la memoria permanente' ($sinCom -match 'Clear-PerfilPasajeros[\s\S]{0,1200}Add-PerfilTodo') 'no se pierde nada'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Clear-PerfilPasajeros' }, $true)
if (-not $d) {
    Comp 'se saca Clear-PerfilPasajeros del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
function Log([string]$m) { }

# los dobles, DESPUES de cargar (manera 9)
$script:invitado = $false
$script:perfil = @()
$script:permanente = @()
$script:guardado = 0
function Get-DatosPerfil { return $script:perfil }
function Save-DatosPerfil($d) { $script:perfil = @($d); $script:guardado++ }
function Add-PerfilTodo([string]$dato, [string]$fuente = '') { $script:permanente += $dato }
function Test-DatoPasajero([string]$dato) { return ($dato -match '(?i)^esta |acaba de|ahora mismo') }

$script:perfil = @(
    'braya juega a Hollow Knight',
    'esta en su cuarto',
    'acaba de completar un juego',
    'tiene una consola ROG Ally',
    'esta jugando a un juego de zombies')
Clear-PerfilPasajeros
Comp 'los pasajeros salen del perfil' ($script:perfil.Count -eq 2) "$($script:perfil.Count) de 5"
Comp '  y los rasgos se quedan' ((@($script:perfil | Where-Object { $_ -match 'Hollow|ROG' }).Count) -eq 2) ''
Comp '  y lo sacado va a la permanente' ($script:permanente.Count -eq 3) "$($script:permanente.Count)"
Comp '  no se pierde ninguno' ((@($script:permanente | Where-Object { $_ -match 'cuarto' }).Count) -eq 1) 'esta escrito, solo que no viaja'

# UNA SOLA VEZ: si no hay pasajeros, ni se guarda
$script:guardado = 0
Clear-PerfilPasajeros
Comp 'sin pasajeros no reescribe nada' ($script:guardado -eq 0) 'no se toca el disco por gusto'

# CON UN INVITADO DELANTE, NADA
$script:perfil = @('esta en su cuarto', 'braya juega a Hollow Knight')
$script:invitado = $true
Clear-PerfilPasajeros
$script:invitado = $false
Comp 'con un invitado delante no toca el perfil' ($script:perfil.Count -eq 2) 'la memoria de braya no se toca con otro delante'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que dura un rato ya no ocupa una plaza'
exit 0
