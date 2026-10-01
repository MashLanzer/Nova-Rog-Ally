# LA DESCARGA QUE TE ESTROPEA LA PARTIDA (30/09, la 7 de las 20 funciones nuevas)
#
# LO QUE SE PROMETIO fue "pausar la descarga al ponerte a jugar". LO QUE SE PUEDE, medido: Steam no
# deja pausar por software. No hay URL 'steam://' para pausar, y en el localconfig.vdf de esta cuenta
# no existen 'AllowDownloadsDuringGameplay' ni 'DownloadThrottleWhileStreaming' (se buscaron las tres
# claves, ninguna esta). Tocar esos ficheros con Steam abierto es pelearse con quien los reescribe.
# ASI QUE ESTA SECCION VIGILA LO QUE SI SE ENTREGA: que te enteres EN EL MOMENTO, con el dato de que
# se baja y cuanto falta, y una sola vez por descarga. Prometer una pausa que no pasa seria peor.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($n in @('Get-FraseDescargaJugando', 'Watch-DescargaJugando')) { Invoke-Expression (Traer $n) }
$script:avisos = @()
function Send-AvisoEntorno { param($c, $t, $n, $cada, $forzar) $script:avisos += ($c + '|' + $t); return $true }

# la biblioteca de pega: se dobla Get-JuegosSteam, que es la fuente de datos, y no el lector
$script:steamFalso = @()
function Get-JuegosSteam { return $script:steamFalso }

Write-Host ''
Write-Host '-- 1. sin nada bajando, no dice nada --'
$script:steamFalso = @(@{ nombre = 'Juego Instalado'; bajando = $false; descargado = 100; total = 100 })
Comp 'con todo instalado se calla' ((Get-FraseDescargaJugando) -eq '') 'hablar por hablar es lo que cansa'

Write-Host ''
Write-Host '-- 2. con una descarga encima, lo dice CON EL DATO --'
$script:steamFalso = @(@{ nombre = 'Juego Que Baja'; bajando = $true; descargado = 30GB; total = 100GB })
$f = Get-FraseDescargaJugando
Comp 'nombra el juego que se baja' ($f -match 'Juego Que Baja') "$f"
Comp '  y dice el porcentaje' ($f -match '30 %') ''
Comp '  y los gigas que faltan' ($f -match '70 gigas') 'sin el dato, "hay una descarga" no sirve de nada'
Comp '  y avisa de los tirones' ($f -match 'tirones') ''
Comp '  y dice como pararla' ($f -match 'pausa las descargas') ''

Write-Host ''
Write-Host '-- 3. una descarga ya acabada no cuenta --'
# El contador puede quedarse viejo: si no falta nada, no hay nada que avisar.
$script:steamFalso = @(@{ nombre = 'Ya Esta'; bajando = $true; descargado = 100GB; total = 100GB })
Comp 'si no falta nada, no avisa' ((Get-FraseDescargaJugando) -eq '') ''

Write-Host ''
Write-Host '-- 4. el aviso: UNA vez por descarga, no en cada alt-tab --'
# Es el fallo que se arreglo el 28/09 con el aviso de las dos horas: Enter-Juego se dispara cada vez
# que el juego vuelve al primer plano, diez veces en una noche.
$script:avisos = @()
$script:descargaJugandoDicha = ''
$script:steamFalso = @(@{ nombre = 'Juego Que Baja'; bajando = $true; descargado = 30GB; total = 100GB })
Watch-DescargaJugando 'Elden Ring De Pega'
Comp 'avisa la primera vez' ($script:avisos.Count -eq 1) "$($script:avisos.Count)"
Watch-DescargaJugando 'Elden Ring De Pega'
Watch-DescargaJugando 'Elden Ring De Pega'
Comp '  y NO repite en los alt-tab siguientes' ($script:avisos.Count -eq 1) "$($script:avisos.Count) tras tres entradas"
# PERO SI CAMBIA LA DESCARGA, ES OTRA COSA Y SE DICE
$script:steamFalso = @(@{ nombre = 'Otro Juego Distinto'; bajando = $true; descargado = 1GB; total = 50GB })
Watch-DescargaJugando 'Elden Ring De Pega'
Comp '  pero si empieza OTRA descarga, si' ($script:avisos.Count -eq 2) "$($script:avisos.Count)"
# Y AL ACABARSE SE OLVIDA, para que la siguiente vuelva a avisar
$script:steamFalso = @()
Watch-DescargaJugando 'Elden Ring De Pega'
Comp '  y al acabarse se rearma' ($script:descargaJugandoDicha -eq '') "[$($script:descargaJugandoDicha)]"

Write-Host ''
Write-Host '-- 5. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'Enter-Juego lo vigila' ($sinCom -match 'Watch-DescargaJugando \$nombre') ''
Comp 'y al abrir las descargas se dice el dato' ($sinCom -match 'Get-FraseDescargaJugando') ''
# Y NO SE PROMETE UNA PAUSA QUE NO PASA: en ningun sitio se dice "he pausado".
$cuerpo = (Traer 'Get-FraseDescargaJugando') + (Traer 'Watch-DescargaJugando')
Comp 'no dice en ningun momento que la haya pausado' ($cuerpo -notmatch 'he pausado|pausada|la pare') 'Steam no deja pausar por software'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova te avisa de la descarga que te da tirones, con el dato y una sola vez' -ForegroundColor Green
exit 0
