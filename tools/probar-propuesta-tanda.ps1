# LA COSTUMBRE SE MEDIA CONTRA EL RELOJ, Y BRAYA NO TIENE RELOJ (27/09, idea 78 de las 121)
#
# EL DATO: CERO propuestas en 17 dias, ni una linea 'PROPUESTA:' en las 58.644 del registro. El unico
# candidato, 'abre steam', tiene 4 dias distintos en la ventana -el minimo son 3- pero sus horas de
# reloj son 10:14, 20:05, 18:54 y 01:09: contra la mediana que calcula el codigo (18:54) solo 1 de
# los 4 cae dentro de los +-30 min que exige, asi que se descartaba. Medido contra el ARRANQUE DE LA
# TANDA, los SIETE usos caen entre -0,6 y +1,4 minutos del inicio. La costumbre existia y se estaba
# midiendo contra la cosa equivocada.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que los usos VIEJOS (sin el campo nuevo) no cuenten como "pedido al empezar"
#   2. que hagan falta TRES DIAS distintos, no tres de la misma tarde
#   3. que el N de minutos salga del p80 de sus desfases y no de un numero escrito
#   4. que la tanda se mida por ORDENES y no por el arranque de Nova, que pasa 15 veces al dia
#   5. que siga siendo una PREGUNTA y respete el veto de lo ya rechazado
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('ConvertTo-Plain', 'Get-PercentilLista', 'Get-MinutosDeTanda', 'Test-PropuestaVetada',
                 'Find-Propuesta', 'Describe-Regla')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
$TandaCorteMin = 45
$PropuestaVetoDias = 60
Comp 'el veto son 60 dias' ($txt -match '\$PropuestaVetoDias = 60') ''
Comp 'el corte de tanda son 45 min' ($txt -match '\$TandaCorteMin = 45') 'lo mismo que usa la ausencia'
Comp 'y la ventana de propuestas son 14 dias' ((Traer 'Find-Propuesta') -match 'AddDays\(-14\)') 'antes 7'

# el mundo de mentira
$script:habitos = $null
function Get-Habitos { return $script:habitos }
function Get-Reglas { return , @($script:reglas) }
$script:reglas = @()
function Reset {
    $script:habitos = @{ usos = (New-Object System.Collections.ArrayList); rechazadas = @(); ultimaPropuesta = '' }
    $script:reglas = @()
}
$hoy = [datetime]'2026-09-27 12:00'
function Uso([string]$t, [string]$dia, [string]$hora, $s) {
    $u = @{ t = $t; f = $dia; h = $hora }
    if ($null -ne $s) { $u['s'] = [int]$s }
    [void]$script:habitos.usos.Add($u)
}

Write-Host ''
Write-Host '-- 1. EL CASO DE VERDAD: los siete "abre steam" de braya --'
Reset
# sus horas reales, que la mediana del reloj descarta; y sus desfases reales de tanda (0, 1, 0, 1)
Uso 'abre steam' '2026-09-18' '10:14' 0
Uso 'abre steam' '2026-09-20' '20:05' 1
Uso 'abre steam' '2026-09-22' '18:54' 0
Uso 'abre steam' '2026-09-24' '01:09' 1
$p1 = Find-Propuesta $hoy
Comp '1a. ahora SI hay propuesta' ($null -ne $p1) $(if ($p1) { $p1.pregunta })
Comp '1b. y es del tipo nuevo' ($p1.tipo -eq 'empiezas') ([string]$p1.tipo)
Comp '1c. con el N sacado de sus desfases' ([int]$p1.valor -eq 2) ([string]$p1.valor + ' min (p80 de 0,0,1,1 con suelo 2)')
Comp '1d. y sigue siendo una PREGUNTA' ($p1.pregunta -match '\?$') ''
# Describe-Regla monta la frase entera (el cuando + la accion), asi que se mira que lleve el trozo
Comp '1e. la frase de la regla se entiende' ((Describe-Regla @{ tipo = 'empiezas'; accion = 'abre steam' }) -match 'cuando empieces a hablarme') (Describe-Regla @{ tipo = 'empiezas'; accion = 'abre steam' })

Write-Host ''
Write-Host '-- 2. LOS USOS VIEJOS NO CUENTAN COMO "AL EMPEZAR" --'
Reset
# los mismos cuatro, pero sin el campo (son de antes del 27/09)
Uso 'abre steam' '2026-09-18' '10:14' $null
Uso 'abre steam' '2026-09-20' '20:05' $null
Uso 'abre steam' '2026-09-22' '18:54' $null
Uso 'abre steam' '2026-09-24' '01:09' $null
$p2 = Find-Propuesta $hoy
Comp '2a. sin el campo, no se propone nada' ($null -eq $p2) 'contarlos como cero seria inventarse el dato'

Write-Host ''
Write-Host '-- 3. TRES DIAS DISTINTOS, NO TRES DE UNA TARDE --'
Reset
Uso 'pon modo juego' '2026-09-26' '18:00' 0
Uso 'pon modo juego' '2026-09-26' '19:00' 1
Uso 'pon modo juego' '2026-09-26' '20:00' 0
$p3 = Find-Propuesta $hoy
Comp '3a. tres veces el mismo dia no es costumbre' ($null -eq $p3) 'una tanda de pruebas no es un habito'
Uso 'pon modo juego' '2026-09-25' '11:00' 1
Uso 'pon modo juego' '2026-09-24' '23:00' 0
$p3b = Find-Propuesta $hoy
Comp '3b. en tres dias distintos, si' ($null -ne $p3b -and $p3b.tipo -eq 'empiezas') $(if ($p3b) { $p3b.pregunta })

Write-Host ''
Write-Host '-- 4. LO QUE SE PIDE A MITAD DE LA TANDA NO ES "AL EMPEZAR" --'
Reset
Uso 'abre spotify' '2026-09-26' '18:00' 40
Uso 'abre spotify' '2026-09-25' '11:00' 55
Uso 'abre spotify' '2026-09-24' '23:00' 3
$p4 = Find-Propuesta $hoy
# el p80 de (3,40,55) es 55, y los tres caben por debajo: esto SI se propone, pero con su N grande
Comp '4a. con desfases largos, el N es grande y no dos minutos' ($null -ne $p4 -and [int]$p4.valor -gt 2) $(if ($p4) { [string]$p4.valor + ' min' })
Comp '4b. y la frase lo dice asi' ($null -ne $p4 -and $p4.pregunta -match 'primeros') $(if ($p4) { $p4.pregunta })

Write-Host ''
Write-Host '-- 5. LO YA RECHAZADO NO SE VUELVE A PREGUNTAR --'
Reset
Uso 'abre steam' '2026-09-18' '10:14' 0
Uso 'abre steam' '2026-09-20' '20:05' 1
Uso 'abre steam' '2026-09-22' '18:54' 0
# el veto se guarda con 'c' (clave) y 'f' (fecha), y 'r' si se acepto: ver Test-PropuestaVetada
$script:habitos.rechazadas = @(@{ c = 'empiezas|abre steam'; f = '2026-09-26'; r = 'no' })
$p5 = Find-Propuesta $hoy
Comp '5a. con el veto puesto, no se propone' ($null -eq $p5) 'el mismo veto de 60 dias que las otras tres'
# Y EL BLINDAJE, que es la trampa del $null valiendo 0 en una comparacion numerica: si la constante
# no llegara, sin el Max(1,...) el veto no vetaria NADA y Nova volveria a proponer lo que braya ya
# rechazo. Es la tercera vez que esta trampa muerde en la casa (ver Get-EsperaAviso, Get-SueloPorAnimo).
$vetoGuardado = $PropuestaVetoDias
Remove-Variable PropuestaVetoDias -Scope Script -ErrorAction SilentlyContinue
$PropuestaVetoDias = $null
$hbV = @{ rechazadas = @(@{ c = 'empiezas|abre steam'; f = (Get-Date -Format 'yyyy-MM-dd'); r = 'no' }) }
Comp '5c. sin la constante, lo rechazado HOY sigue vetado' (Test-PropuestaVetada $hbV 'empiezas|abre steam') 'el Max(1, ...) de Test-PropuestaVetada'
$PropuestaVetoDias = $vetoGuardado
Reset
Uso 'abre steam' '2026-09-18' '10:14' 0
Uso 'abre steam' '2026-09-20' '20:05' 1
Uso 'abre steam' '2026-09-22' '18:54' 0
$script:reglas = @(@{ tipo = 'empiezas'; accion = 'abre steam'; valor = '2' })
$p5b = Find-Propuesta $hoy
Comp '5b. y si ya existe la regla, tampoco' ($null -eq $p5b) ''

Write-Host ''
Write-Host '-- 6. LA TANDA SE MIDE POR ORDENES --'
$script:tandaDesde = $null
$script:tandaUltima = $null
$t0 = [datetime]'2026-09-27 18:00'
Comp '6a. la primera orden de la tanda son 0 minutos' ((Get-MinutosDeTanda $t0) -eq 0) ''
Comp '6b. dos minutos despues, 2' ((Get-MinutosDeTanda $t0.AddMinutes(2)) -eq 2) ''
Comp '6c. media hora despues, 30 (misma tanda)' ((Get-MinutosDeTanda $t0.AddMinutes(30)) -eq 30) ''
# pasados 45 min SIN ordenes, es otra tanda y vuelve a cero
$t1 = $t0.AddMinutes(30).AddMinutes($TandaCorteMin + 1)
Comp '6d. tras 45 min sin ordenes, la tanda empieza de cero' ((Get-MinutosDeTanda $t1) -eq 0) 'y no cuenta desde la primera de la tarde'
Comp '6e. y la siguiente sigue esa tanda nueva' ((Get-MinutosDeTanda $t1.AddMinutes(3)) -eq 3) ''

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7a. Add-Habito guarda los minutos de tanda' ($sinCom -match "s = \(Get-MinutosDeTanda \`$cuando\)") ''
Comp '7b. la regla se dispara con la primera orden de la tanda' ($sinCom -match "Invoke-Reglas 'empiezas' 'empieza'") ''
Comp '7c. y el switch de reglas la conoce' ($sinCom -match "'empiezas' \{ \`$dispara = \(\`$dato -eq 'empieza'\) \}") ''
Comp '7d. el nombre no choca con el contador "arranque" de la idea 50' (-not ($sinCom -match "tipo -eq 'arranque'")) 'dos cosas distintas no pueden llamarse igual'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la costumbre se mide desde que empiezas a hablarle' -ForegroundColor Green
exit 0
