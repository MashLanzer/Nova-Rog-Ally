# QUE NOTE A QUE ESTAS JUGANDO (25/09, ideas 17 y 38)
#
# LO MEDIDO: memoria\juegos.json lleva 6 juegos con sus minutos por dia -ELDEN RING el 18, 19 y
# 20; Black Myth el 19; Unravel Two el 23- y ese fichero SOLO sirve para contestar "cuanto he
# jugado". No decide nada, no se comenta nunca, no cambia una sola frase de Nova.
#
# LA IDEA: Nova ya detecta cuando braya abre un juego. Con lo que ya tiene escrito puede decir
# algo que demuestre que se acuerda -"tercer dia seguido con esto", "hacia dos semanas que no
# lo tocabas"- en vez de callarse. Notar un cambio es lo mas parecido a prestar atencion, y no
# hace falta nada listo: basta con leer lo que ya esta en el disco.
#
# LO QUE NO SE HACE, y es lo que separa esto de ser un pesado: NO se comenta cada vez. Una
# racha se dice al tercer dia, no al cuarto ni al quinto; y una vuelta se dice si de verdad
# hacia mucho. Si no hay nada que contar, Nova se calla, que es lo normal.
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

Write-Host '-- 1. existe y se dice al abrir un juego --'
Comp 'existe Get-FraseJuegoNotado' ($sinCom -match 'function Get-FraseJuegoNotado') ''
$usos = @([regex]::Matches($sinCom, '(?<!function )Get-FraseJuegoNotado')).Count
Comp 'y se usa al detectar el juego' ($usos -ge 1) "$usos uso(s)"
Comp 'va por la puerta de los avisos' ($sinCom -match "Send-AvisoEntorno 'juego-notado'") 'con un juego delante se guarda o vibra, no interrumpe'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-FraseJuegoNotado' }, $true)
if (-not $d) {
    Comp 'se saca Get-FraseJuegoNotado del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
function Log([string]$m) { }
# las constantes, del archivo (manera 6)
foreach ($cte in @('JuegoRachaMin', 'JuegoVueltaDias')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim()) }
}
# el doble de los datos, DESPUES de cargar (manera 9)
$script:juegosDias = @{}
function Get-DiasDeJuego([string]$nombre) {
    if ($script:juegosDias.ContainsKey($nombre)) { return $script:juegosDias[$nombre] }
    return @()
}
$hoy = [datetime]'2026-09-25'

# UN JUEGO NUEVO: no hay nada que contar
$script:juegosDias['Nuevo'] = @()
Comp 'un juego nuevo no da pie a nada' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Nuevo' $hoy))) ''

# UN DIA SUELTO: tampoco
$script:juegosDias['Suelto'] = @('2026-09-24')
Comp 'con un dia detras tampoco' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Suelto' $hoy))) 'una racha de dos no es una racha'

# RACHA DE TRES (ayer, anteayer y el anterior): eso si
$script:juegosDias['Elden'] = @('2026-09-24', '2026-09-23', '2026-09-22')
$f = Get-FraseJuegoNotado 'Elden' $hoy
Comp 'tres dias seguidos si se notan' (-not [string]::IsNullOrEmpty($f)) "$f"
Comp '  y dice cuantos' ($f -match '4|cuarto|cuatro') "$f"

# TRES DIAS SUELTOS NO SON UNA RACHA (25/09, lo cazo una rotura: al hacer que contara
# CUALQUIER dia en vez de solo los consecutivos, el banco seguia verde entero. Ninguno de los
# casos de arriba tenia tres dias repartidos, asi que la unica linea que mide "seguidos" no la
# miraba nadie). Jugo ayer, hace cinco dias y hace diez: son tres dias, no una racha de tres.
$script:juegosDias['Salteado'] = @('2026-09-24', '2026-09-20', '2026-09-15')
Comp 'tres dias sueltos NO son una racha' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Salteado' $hoy))) 'seguidos quiere decir seguidos'

# UNA VUELTA DESPUES DE MUCHO: tambien
$script:juegosDias['Viejo'] = @('2026-09-01')
$f2 = Get-FraseJuegoNotado 'Viejo' $hoy
Comp 'una vuelta despues de semanas se nota' (-not [string]::IsNullOrEmpty($f2)) "$f2"
Comp '  y dice cuanto hacia' ($f2 -match '24|semanas|dias') "$f2"

# PERO NO SI FUE HACE POCO
$script:juegosDias['Reciente'] = @('2026-09-23')
Comp 'volver tras dos dias no es noticia' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Reciente' $hoy))) ''

# SI YA JUGO HOY, NO SE REPITE
$script:juegosDias['Hoy'] = @('2026-09-25', '2026-09-24', '2026-09-23', '2026-09-22')
Comp 'si ya jugo hoy, no lo vuelve a decir' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Hoy' $hoy))) 'una vez al dia, no en cada arranque'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova nota a que estas jugando'
exit 0
