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
# EL DOBLE SE PONE UN ESCALON MAS ABAJO (25/09). Aqui habia un doble de Get-DiasDeJuego, o sea
# que este banco sustituia LA FUNCION QUE ESTABA ROTA y por eso salia verde con ella rota. Es
# una manera nueva de salir verde mintiendo: doblar justo la pieza que se quiere probar.
# LO QUE TAPABA: Get-DiasDeJuego leia 'dias' con .PSObject.Properties, que solo vale mientras
# ese campo sea el objeto recien salido del JSON. En cuanto braya juega cinco minutos,
# Save-TiempoJuego lo reescribe como HASHTABLE, y ahi .PSObject.Properties devuelve Keys,
# Values y Count en vez de fechas. Resultado: 'juego-notado' 0 veces en los dos registros.
# Ahora el doble es Get-JuegosMem -el fichero- y se traen del archivo los DOS lectores de
# verdad, asi que las dos formas del campo 'dias' se prueban de verdad.
foreach ($fn in @('Get-DiasDeJuego', 'Get-DiasJuego', 'Get-DiaJuego')) {
    $dFn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $fn }, $true)
    if (-not $dFn) { Comp "se saca $fn del arbol" $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
    Invoke-Expression $dFn.Extent.Text
}
$script:juegosMemDoble = @{}
function Get-JuegosMem { return $script:juegosMemDoble }
# ayuda para montar el fichero como lo deja Nova: 'dias' es un HASHTABLE con minutos por dia
function PonDias([string]$nombre, [string[]]$dias) {
    $h = @{}
    foreach ($d in $dias) { $h[$d] = 30 }
    $script:juegosMemDoble[$nombre] = @{ 'dias' = $h }
}
# y como sale del JSON la primera vez, antes de que nadie lo reescriba
function PonDiasJson([string]$nombre, [string[]]$dias) {
    $o = New-Object PSObject
    foreach ($d in $dias) { Add-Member -InputObject $o -NotePropertyName $d -NotePropertyValue 30 }
    $script:juegosMemDoble[$nombre] = @{ 'dias' = $o }
}
$script:juegosDias = @{}   # se conserva el nombre para no tocar el resto del banco
$hoy = [datetime]'2026-09-25 12:00'

# UN JUEGO NUEVO: no hay nada que contar
PonDias 'Nuevo' @()
Comp 'un juego nuevo no da pie a nada' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Nuevo' $hoy))) ''

# UN DIA SUELTO: tampoco
PonDias 'Suelto' @('2026-09-24')
Comp 'con un dia detras tampoco' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Suelto' $hoy))) 'una racha de dos no es una racha'

# RACHA DE TRES (ayer, anteayer y el anterior): eso si
PonDias 'Elden' @('2026-09-24', '2026-09-23', '2026-09-22')
$f = Get-FraseJuegoNotado 'Elden' $hoy
Comp 'tres dias seguidos si se notan' (-not [string]::IsNullOrEmpty($f)) "$f"
Comp '  y dice cuantos' ($f -match '4|cuarto|cuatro') "$f"

# TRES DIAS SUELTOS NO SON UNA RACHA (25/09, lo cazo una rotura: al hacer que contara
# CUALQUIER dia en vez de solo los consecutivos, el banco seguia verde entero. Ninguno de los
# casos de arriba tenia tres dias repartidos, asi que la unica linea que mide "seguidos" no la
# miraba nadie). Jugo ayer, hace cinco dias y hace diez: son tres dias, no una racha de tres.
PonDias 'Salteado' @('2026-09-24', '2026-09-20', '2026-09-15')
Comp 'tres dias sueltos NO son una racha' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Salteado' $hoy))) 'seguidos quiere decir seguidos'

# UNA VUELTA DESPUES DE MUCHO: tambien
PonDias 'Viejo' @('2026-09-01')
$f2 = Get-FraseJuegoNotado 'Viejo' $hoy
Comp 'una vuelta despues de semanas se nota' (-not [string]::IsNullOrEmpty($f2)) "$f2"
Comp '  y dice cuanto hacia' ($f2 -match '24|semanas|dias') "$f2"

# PERO NO SI FUE HACE POCO
PonDias 'Reciente' @('2026-09-23')
Comp 'volver tras dos dias no es noticia' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Reciente' $hoy))) ''

# SI YA JUGO HOY, NO SE REPITE
PonDias 'Hoy' @('2026-09-25', '2026-09-24', '2026-09-23', '2026-09-22')
Comp 'si ya jugo hoy, no lo vuelve a decir' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'Hoy' $hoy))) 'una vez al dia, no en cada arranque'

Write-Host ''
Write-Host '-- 3. LAS DOS FORMAS DEL CAMPO "dias" (lo que tenia mudo esto) --'
# El fichero nace del JSON con 'dias' como objeto, y en cuanto braya juega cinco minutos
# Save-TiempoJuego lo reescribe como HASHTABLE. Las dos tienen que leerse igual: con una sola
# de las dos probada, el fallo que dejo 'juego-notado' en cero pasaba en verde.
PonDiasJson 'RecienLeido' @('2026-09-24', '2026-09-23', '2026-09-22')
Comp 'con dias como sale del JSON, se lee' ((Get-FraseJuegoNotado 'RecienLeido' $hoy) -match 'dia 4 seguido') ''
PonDias 'YaGuardado' @('2026-09-24', '2026-09-23', '2026-09-22')
Comp 'y con dias ya reescrito como hashtable, tambien' ((Get-FraseJuegoNotado 'YaGuardado' $hoy) -match 'dia 4 seguido') 'esta era la que fallaba'

Write-Host ''
Write-Host '-- 4. EL DIA DE JUGAR EMPIEZA A LAS CINCO --'
# juegos.json guarda los dias con Get-DiaJuego, que resta cinco horas. Si aqui se usara la
# fecha natural, entre las 00:00 y las 05:00 la cuenta se iria un dia entero: justo la franja
# en la que braya juega (la sesion continua mas larga del registro acaba a las 00:45).
PonDias 'Madrugada' @('2026-09-24', '2026-09-23', '2026-09-22')
$deMadrugada = [datetime]'2026-09-26 02:00'
Comp 'a las 02:00 del 26 todavia es el dia 25' ((Get-FraseJuegoNotado 'Madrugada' $deMadrugada) -match 'dia 4 seguido') `
    "sale: '$(Get-FraseJuegoNotado 'Madrugada' $deMadrugada)'"
PonDias 'YaJugoDeNoche' @('2026-09-25', '2026-09-24', '2026-09-23')
Comp 'y si ya jugo esta noche, no lo repite' ([string]::IsNullOrEmpty((Get-FraseJuegoNotado 'YaJugoDeNoche' $deMadrugada))) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova nota a que estas jugando'
exit 0
