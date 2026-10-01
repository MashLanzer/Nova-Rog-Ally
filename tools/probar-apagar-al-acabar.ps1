# APAGA LA CONSOLA CUANDO ACABE LA DESCARGA (30/09, la 8 de las 20 funciones nuevas)
#
# La mas barata de las veinte: las dos piezas ya estaban enteras -Nova sabe apagar y sabe cuando una
# descarga termina- y solo faltaba juntarlas. Es la orden de dejar algo gordo bajando e irse a dormir.
#
# LO QUE ESTA SECCION DEFIENDE son las tres guardas, porque esta funcion APAGA LA CONSOLA y
# equivocarse aqui se nota mucho:
#   1. sin nada bajando no se arma (si no, "apaga cuando acabe" apagaria al instante),
#   2. no se queda puesto para siempre: a las 8 horas se suelta solo y lo dice (regla 2),
#   3. y "cancela el apagado" suelta TAMBIEN el modo, no solo el shutdown de ahora.
#
# AQUI NO SE APAGA NADA: Start-Process esta doblado y se cuentan las llamadas.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
$ApagarAlAcabarMaxH = 8
foreach ($n in @('Start-ApagarAlAcabar', 'Stop-ApagarAlAcabar', 'Watch-ApagarAlAcabar')) { Invoke-Expression (Traer $n) }
$script:dichos = @()
$script:hablado = @()
function Log([string]$m) { $script:dichos += $m }
function Say([string]$m) { $script:hablado += $m }
# EL RELOJ DEL BUCLE, de pega: asi se puede viajar en el tiempo sin esperar ocho horas
$script:reloj = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
# EL APAGADO, DOBLADO: aqui no se apaga la consola de braya por correr un banco
$script:apagados = @()
function Start-Process { param([string]$FilePath, $ArgumentList, $WindowStyle, [switch]$Wait)
    $script:apagados += ($FilePath + ' ' + ($ArgumentList -join ' ')) }
$script:steamFalso = @()
function Get-JuegosSteam { return $script:steamFalso }

Write-Host ''
Write-Host '-- 1. sin nada bajando NO se arma --'
$script:apagarAlAcabar = $false
$script:steamFalso = @(@{ nombre = 'Instalado'; bajando = $false; descargado = 10; total = 10 })
$r = Start-ApagarAlAcabar
Comp 'dice que no hay nada que esperar' ($r -match 'No hay ninguna descarga') "$r"
Comp '  y NO deja el modo armado' (-not $script:apagarAlAcabar) 'si no, apagaria al instante'

Write-Host ''
Write-Host '-- 2. con una descarga, se arma y lo dice con el dato --'
$script:steamFalso = @(@{ nombre = 'Juego Gordo'; bajando = $true; descargado = 20GB; total = 100GB })
$r2 = Start-ApagarAlAcabar
Comp 'se arma' ($script:apagarAlAcabar) ''
Comp '  y dice a que espera' ($r2 -match 'Juego Gordo') "$r2"
Comp '  y cuanto le falta' ($r2 -match '80 gigas') ''
Comp '  y como cancelarlo' ($r2 -match 'cancela el apagado') ''

Write-Host ''
Write-Host '-- 3. mientras siga bajando, no apaga --'
$script:apagados = @()
Watch-ApagarAlAcabar
Comp 'no apaga con la descarga a medias' ($script:apagados.Count -eq 0) "$($script:apagados.Count) apagado(s)"
Comp '  y sigue armado' ($script:apagarAlAcabar) ''

Write-Host ''
Write-Host '-- 4. al acabar, avisa y apaga --'
$script:steamFalso = @(@{ nombre = 'Juego Gordo'; bajando = $false; descargado = 100GB; total = 100GB })
$script:hablado = @()
Watch-ApagarAlAcabar
Comp 'apaga cuando ya no baja nada' ($script:apagados.Count -eq 1) "$($script:apagados.Count)"
Comp '  con shutdown y un plazo' ($script:apagados[0] -match 'shutdown' -and $script:apagados[0] -match '/s' -and $script:apagados[0] -match '60') "$($script:apagados[0])"
Comp '  avisando ANTES en voz alta' (@($script:hablado | Where-Object { $_ -match 'Apago la consola' }).Count -ge 1) 'el apagado nunca es una sorpresa'
Comp '  y diciendo como pararlo' (@($script:hablado | Where-Object { $_ -match 'cancela el apagado' }).Count -ge 1) ''
Comp '  y el modo se suelta' (-not $script:apagarAlAcabar) 'no puede quedarse armado tras apagar'
# Y NO APAGA DOS VECES: tras soltar el modo, otra ronda no hace nada.
$script:apagados = @()
Watch-ApagarAlAcabar
Comp '  y no apaga otra vez' ($script:apagados.Count -eq 0) ''

Write-Host ''
Write-Host '-- 5. la guarda de las horas (regla 2: nada se queda puesto) --'
# Una descarga que se queda PARADA dejaria esto armado toda la noche; a las 8 h se suelta solo.
$script:reloj = 0
$script:steamFalso = @(@{ nombre = 'Descarga Parada'; bajando = $true; descargado = 1GB; total = 100GB })
[void](Start-ApagarAlAcabar)
$script:apagados = @(); $script:hablado = @()
$script:reloj = 9 * 3600000      # nueve horas despues, y sigue sin acabar
Watch-ApagarAlAcabar
Comp 'a las 8 horas suelta el modo' (-not $script:apagarAlAcabar) ''
Comp '  y NO apaga la consola' ($script:apagados.Count -eq 0) 'apagar al dia siguiente seria lo peor que puede hacer'
Comp '  y lo dice en voz alta' (@($script:hablado | Where-Object { $_ -match 'suelto el apagado' }).Count -ge 1) "$($script:hablado -join ' | ')"

Write-Host ''
Write-Host '-- 6. cancelarlo a mano --'
$script:reloj = 0
$script:steamFalso = @(@{ nombre = 'Otra'; bajando = $true; descargado = 1GB; total = 50GB })
[void](Start-ApagarAlAcabar)
Comp 'se puede cancelar' (Stop-ApagarAlAcabar 'prueba') ''
Comp '  y queda suelto' (-not $script:apagarAlAcabar) ''
Comp '  y cancelar dos veces no miente' (-not (Stop-ApagarAlAcabar 'prueba')) 'devuelve falso si no habia nada armado'

Write-Host ''
Write-Host '-- 7. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca apagarAlAcabar' ($sinCom -match "kind = 'apagarAlAcabar'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'apagarAlAcabar' \{") ''
Comp '  y la ronda del minuto lo vigila' ($sinCom -match 'Watch-ApagarAlAcabar') ''
# "CANCELA EL APAGADO" TIENE QUE SOLTAR TAMBIEN EL MODO: sin esto, el shutdown de ahora se quita y
# al acabar la descarga Nova vuelve a apagar, cuando braya ya habia dicho que no.
Comp 'y "cancela el apagado" suelta el modo' ($sinCom -match "Stop-ApagarAlAcabar 'braya lo cancelo'") 'si no, vuelve a apagar luego'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova apaga cuando acaba la descarga, y no se queda armada para siempre' -ForegroundColor Green
exit 0
