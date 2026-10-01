# EL RELOJ DEL REEMBOLSO (1/10, la 11 de las 20 funciones nuevas) - LA MITAD QUE SE PUEDE
#
# Steam devuelve el dinero con menos de DOS HORAS jugadas y menos de CATORCE DIAS desde la compra.
# MEDIDO: la fecha de compra NO existe en ningun sitio al que Nova pueda llegar. 'PurchaseTime',
# 'Licenses' y 'rt_purchase' dan cero apariciones en localconfig.vdf, el appmanifest solo trae
# 'LastPlayed', y la API publica no la expone. Los catorce dias no se pueden contar.
#
# LAS DOS HORAS SI: Nova lleva los segundos por juego desde el 19/09. Lo que esta seccion defiende es
# que DIGA lo que no sabe. Un aviso que haga creer que el plazo esta entero cuando solo se controla
# la mitad es peor que no avisar: braya podria dejar pasar los catorce dias creyendo que Nova vigila.
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
$ReembolsoHoras = 2.0
$ReembolsoAvisaMin = 95
foreach ($n in @('ConvertTo-Plain', 'Get-HorasJugadas', 'Get-FraseReembolso', 'Watch-Reembolso')) { Invoke-Expression (Traer $n) }
$script:avisos = @()
function Send-AvisoEntorno { param($c, $t, $n, $cada, $forzar) $script:avisos += ($c + '|' + $t); return $true }

# los tiempos de pega, como JSON y leidos como JSON (igual que hace la funcion de verdad)
$memJson = @'
{
  "Recien Comprado":  { "dias": { "2026-09-30": 1800 } },
  "Casi En El Limite":{ "dias": { "2026-09-29": 3600, "2026-09-30": 2160 } },
  "Ya Pasado":        { "dias": { "2026-09-28": 20000 } }
}
'@
$mem = $memJson | ConvertFrom-Json
function Get-JuegosMem { return $mem }

Write-Host ''
Write-Host '-- 1. las horas salen de lo que ya apunta --'
Comp 'media hora se lee bien' ((Get-HorasJugadas 'Recien Comprado') -eq 0.5) "$(Get-HorasJugadas 'Recien Comprado')"
Comp 'y suma TODOS los dias' ((Get-HorasJugadas 'Casi En El Limite') -eq 1.6) "$(Get-HorasJugadas 'Casi En El Limite')"
Comp 'un juego sin apuntar da -1' ((Get-HorasJugadas 'Juego Desconocido') -eq -1) 'y no 0, que seria "no lo has jugado"'

Write-Host ''
Write-Host '-- 2. dentro del plazo: cuanto queda --'
$f = Get-FraseReembolso 'Recien Comprado'
Comp 'dice los minutos jugados' ($f -match '30 minutos') "$f"
Comp '  y los que quedan para las dos horas' ($f -match 'quedan 90') ''
# LO QUE NO SE SABE SE DICE: sin esto, braya creeria que Nova le vigila los catorce dias.
Comp '  y AVISA de que los catorce dias no los sabe' ($f -match 'catorce dias' -and $f -match 'no lo se') 'callarlo haria creer que el plazo esta entero'

Write-Host ''
Write-Host '-- 3. pasado el limite, se dice claro --'
$f2 = Get-FraseReembolso 'Ya Pasado'
Comp 'dice que ya no lo devuelven' ($f2 -match 'ya no lo devuelve') "$f2"
Comp '  y no promete nada mas' ($f2 -notmatch 'quedan') ''
Comp 'un juego que no tiene no se inventa' ((Get-FraseReembolso 'Juego Desconocido') -match 'No tengo apuntado') ''
Comp 'y sin juego pide el nombre' ((Get-FraseReembolso '') -match 'Dime de que juego') ''

Write-Host ''
Write-Host '-- 4. el aviso: solo en la ventana que sirve --'
$script:avisos = @(); $script:reembolsoDicho = @{}
# por debajo de hora y media no viene a cuento
Watch-Reembolso 'Recien Comprado'
Comp 'con media hora no avisa' ($script:avisos.Count -eq 0) 'todavia no hay nada que decidir'
# en la ventana si
Watch-Reembolso 'Casi En El Limite'
Comp 'a hora y media y pico, avisa' ($script:avisos.Count -eq 1) "$($script:avisos.Count)"
Comp '  y dice cuanto queda' ($script:avisos[0] -match 'quedan 24') "$($script:avisos[0])"
# UNA SOLA VEZ: repetirlo cada minuto mientras juega seria insoportable
Watch-Reembolso 'Casi En El Limite'
Watch-Reembolso 'Casi En El Limite'
Comp '  y no repite' ($script:avisos.Count -eq 1) "$($script:avisos.Count) tras tres rondas"
# Y PASADAS LAS DOS HORAS, NO: el dinero ya no vuelve, y decirlo es recordarle algo que no puede
# arreglar.
$script:avisos = @(); $script:reembolsoDicho = @{}
Watch-Reembolso 'Ya Pasado'
Comp 'pasado el limite ya no avisa' ($script:avisos.Count -eq 0) 'seria recordarle algo que no puede arreglar'
# y un juego sin datos no revienta
$script:avisos = @()
Watch-Reembolso 'Juego Desconocido'
Comp 'y un juego sin datos no revienta' ($script:avisos.Count -eq 0) ''

Write-Host ''
Write-Host '-- 5. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca reembolso' ($sinCom -match "kind = 'reembolso'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'reembolso' \{") ''
Comp '  y se vigila con un juego delante' ($sinCom -match 'Watch-Reembolso') ''
# LOS NUMEROS SALEN DEL ARCHIVO, no escritos aqui
Comp 'las dos horas salen del archivo' ($txt -match '\$ReembolsoHoras = 2\.0') ''
Comp '  y el aviso a los 95 minutos tambien' ($txt -match '\$ReembolsoAvisaMin = 95') ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova vigila las dos horas del reembolso, y dice que los catorce dias no los sabe' -ForegroundColor Green
exit 0
