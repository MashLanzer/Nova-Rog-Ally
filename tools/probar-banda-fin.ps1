# SABE A QUE HORA PARAS, PERO NO CUANTO TE MUEVES DE ESA HORA (26/09, idea 46 de las 121).
#
# La banda p25/mediana/p75 de habitos.fin. La mediana ya la sabia; la banda anade la dispersion,
# y de ahi salen la ventana del recordatorio de carga (p75-p25) y el margen del aviso de dormir
# (p75-med). Lo que NO puede cambiar es la mediana (Get-NocheDesde y el texto del aviso dependen
# de ella) ni que el margen baje del de hoy. Todo con $hoy y habitos FIJOS: la ventana es movil.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira: habitos escritos a mano, cuartiles del archivo ---
$script:hb = @{ fin = @{}; ruptura = @{ desde = '' }; cargaAvisada = ''; charlaHoras = @{} }
function Get-Habitos { return $script:hb }
$script:guardado = 0
function Save-Habitos { $script:guardado++ }
function Get-Cfg([string]$s, [string]$k, $d) { return $d }
function Log([string]$m) { }
$EntornoNocheDesde = 23
$BandaFinPctBajo = if ($fuente -match '(?m)^\$BandaFinPctBajo\s*=\s*(\d+)') { [int]$Matches[1] } else { -1 }
$BandaFinPctAlto = if ($fuente -match '(?m)^\$BandaFinPctAlto\s*=\s*(\d+)') { [int]$Matches[1] } else { -1 }
Invoke-Expression (Traer 'Get-BandaFinHabitual')
Invoke-Expression (Traer 'Get-HoraFinHabitual')
Invoke-Expression (Traer 'Test-RecordarCarga')
Invoke-Expression (Traer 'Get-AvisoHoraDormir')

Comp '0. los cuartiles se leen del archivo y son 25 y 75' ($BandaFinPctBajo -eq 25 -and $BandaFinPctAlto -eq 75) "bajo=$BandaFinPctBajo alto=$BandaFinPctAlto"

function PonNoches($pares) {
    $script:hb.fin = @{}
    foreach ($p in $pares) { $script:hb.fin[$p[0]] = $p[1] }
}
$HOY = [datetime]'2026-09-26 18:00'
$ONCE = @(
    @('2026-09-13', '17:24'), @('2026-09-14', '21:59'), @('2026-09-15', '22:38'), @('2026-09-16', '23:38'),
    @('2026-09-17', '23:50'), @('2026-09-18', '00:24'), @('2026-09-19', '00:28'), @('2026-09-20', '01:00'),
    @('2026-09-21', '01:18'), @('2026-09-22', '01:18'), @('2026-09-23', '01:29'))

Write-Host ''
Write-Host '  -- 1, 2, 3: la mediana no se mueve; los cuartiles son los medidos --'
PonNoches $ONCE
$b = Get-BandaFinHabitual $HOY
Comp '1. la mediana sigue en 1464 (00:24), formula Floor(n/2)' ((Get-HoraFinHabitual $HOY) -eq 1464 -and $b.med -eq 1464) "med=$($b.med)"
# n PAR: 6 noches -> Floor(6/2)=indice 3. Ordenadas: 1418,1418,1464,1464,1518,1584 -> indice 3 = 1464
PonNoches @(@('2026-09-21', '00:10'), @('2026-09-22', '23:38'), @('2026-09-23', '00:24'), @('2026-09-24', '23:38'), @('2026-09-25', '00:24'), @('2026-09-26', '01:18'))
Comp '   con n par, med = Floor(n/2), no Ceiling(0.5n)-1' ((Get-BandaFinHabitual([datetime]'2026-09-27 18:00')).med -eq 1464) "1464, no 1424"
PonNoches $ONCE
Comp '2. p25 = 1358 (22:38), no 1418 (23:38, el que se cuela con n-1 mal)' ($b.p25 -eq 1358) "p25=$($b.p25)"
Comp '   y p75 = 1518 (01:18), no 1529 (recorte de indice mal)' ($b.p75 -eq 1518) "p75=$($b.p75)"
# con VALORES DISTINTOS (las 11 reales tienen 1518 en los indices 8 y 9, asi que un off-by-one
# en p75 no se veria): 5 noches 22:00,23:00,00:00,01:00,02:00 -> p25 idx1=23:00, med idx2=00:00,
# p75 idx3=01:00 (Ceiling(0.75*5)-1=3). Sin el -1 daria idx4 = 02:00.
PonNoches @(@('2026-09-20', '22:00'), @('2026-09-21', '23:00'), @('2026-09-22', '00:00'), @('2026-09-23', '01:00'), @('2026-09-24', '02:00'))
$b5 = Get-BandaFinHabitual $HOY
Comp '   con 5 valores distintos, p75 es el 4o (01:00), no el 5o (02:00)' (($b5.p75 -eq 1500) -and ($b5.p25 -eq 1380) -and ($b5.med -eq 1440)) "p25=$($b5.p25) med=$($b5.med) p75=$($b5.p75)"
PonNoches $ONCE
$b = Get-BandaFinHabitual $HOY
# la cuenta que justifica la idea
$enBanda = 0; $enVieja = 0
foreach ($p in $ONCE) { $hf = $p[1]; $mm = [int]$hf.Substring(0, 2) * 60 + [int]$hf.Substring(3, 2); if ($mm -lt 300) { $mm += 1440 }
    if ($mm -ge $b.p25 -and $mm -le $b.p75) { $enBanda++ }
    if ($mm -ge ($b.med - 30) -and $mm -le $b.med) { $enVieja++ } }
Comp '3. caen 8 de 11 en [p25,p75] (con 22:38; con 23:38 serian 7)' ($enBanda -eq 8) "$enBanda"
Comp '   y solo 1 en la ventana vieja [med-30, med]' ($enVieja -eq 1) "$enVieja"

Write-Host ''
Write-Host '  -- 4: Test-RecordarCarga usa la banda, no 30 min alrededor de la mediana --'
PonNoches $ONCE
Comp '4. a las 22:00 (fuera por abajo, antes de p25) no' (-not (Test-RecordarCarga 20 0 ([datetime]'2026-09-26 22:00'))) ''
Comp '   a las 22:38 (borde p25) SI (con el techo viejo -30 alrededor de la mediana daria false)' (Test-RecordarCarga 20 0 ([datetime]'2026-09-26 22:38')) ''
$script:hb.cargaAvisada = ''
Comp '   a la 01:18 (borde p75) SI' (Test-RecordarCarga 20 0 ([datetime]'2026-09-27 01:18')) ''
$script:hb.cargaAvisada = ''
Comp '   a la 01:30 (fuera por arriba) no' (-not (Test-RecordarCarga 20 0 ([datetime]'2026-09-27 01:30'))) ''
Comp '   con pct 41 (> 40) no, aunque este en banda' (-not (Test-RecordarCarga 41 0 ([datetime]'2026-09-27 00:24'))) 'la guarda del 40 % manda'

Write-Host ''
Write-Host '  -- 5: las guardas siguen (menos de 4 dias) --'
PonNoches @(@('2026-09-24', '00:24'), @('2026-09-25', '00:28'), @('2026-09-26', '01:00'))
Comp '5. con 3 noches, la banda es $null' ($null -eq (Get-BandaFinHabitual $HOY)) ''
Comp '   Get-HoraFinHabitual devuelve -1' ((Get-HoraFinHabitual $HOY) -eq -1) ''
Comp '   Test-RecordarCarga devuelve $false' (-not (Test-RecordarCarga 20 0 $HOY)) ''
Comp '   y el aviso cae al respaldo (no sueles estar levantado)' ((Get-AvisoHoraDormir([datetime]'2026-09-26 03:00')) -match 'no sueles estar levantado') ''

Write-Host ''
Write-Host '  -- 6: el margen del aviso: mas dispersion = mas margen antes de dar la lata --'
# las claves van dentro de la ventana movil [ahora-14d, ahora-5h): a las 00:55 del dia D, hoyK
# es D-1, asi que las noches acaban en D-2. margen pequeno (32) -> habla tarde; grande (50) -> calla.
# n=8, margen 32 (med 00:24, p75 00:56): a la 01:31 SIGUE HABLANDO
PonNoches @(@('2026-09-15', '22:38'), @('2026-09-16', '23:38'), @('2026-09-17', '23:50'), @('2026-09-18', '00:24'), @('2026-09-19', '00:24'), @('2026-09-20', '00:56'), @('2026-09-21', '01:18'), @('2026-09-22', '01:18'))
$t24 = Get-AvisoHoraDormir([datetime]'2026-09-24 01:31')
Comp '6. margen 32 y son las 01:31: sigue hablando (aviso tardio de verdad)' ($t24 -ne '') $t24
# n=9, margen 36 (med 00:24, p75 01:00): a las 00:55 CALLA (con el 30 fijo de antes hablaria)
PonNoches @(@('2026-09-15', '22:38'), @('2026-09-16', '23:38'), @('2026-09-17', '23:50'), @('2026-09-18', '00:24'), @('2026-09-19', '00:24'), @('2026-09-20', '00:28'), @('2026-09-21', '01:00'), @('2026-09-22', '01:18'), @('2026-09-23', '01:18'))
Comp '   margen 36 y son las 00:55: CALLA (con el 30 fijo hablaria)' ((Get-AvisoHoraDormir([datetime]'2026-09-25 00:55')) -eq '') ''
# n=10, margen 50 (med 00:24, p75 01:14): a las 00:59 CALLA
PonNoches @(@('2026-09-15', '22:38'), @('2026-09-16', '23:38'), @('2026-09-17', '23:50'), @('2026-09-18', '00:10'), @('2026-09-19', '00:24'), @('2026-09-20', '00:24'), @('2026-09-21', '00:28'), @('2026-09-22', '01:14'), @('2026-09-23', '01:18'), @('2026-09-24', '01:29'))
Comp '   margen 50 y son las 00:59: CALLA' ((Get-AvisoHoraDormir([datetime]'2026-09-26 00:59')) -eq '') ''

Write-Host ''
Write-Host '  -- 7: el margen NUNCA baja del de hoy (Max con 30) --'
# 6 noches con p75 == med (todas 00:24): margen bruto 0
PonNoches @(@('2026-09-21', '00:24'), @('2026-09-22', '00:24'), @('2026-09-23', '00:24'), @('2026-09-24', '00:24'), @('2026-09-25', '00:24'), @('2026-09-26', '00:24'))
$b7 = Get-BandaFinHabitual([datetime]'2026-09-27 18:00')
Comp '7. con p75 == med, a las 00:25 CALLA (margen efectivo 30, no 0)' ((Get-AvisoHoraDormir([datetime]'2026-09-27 00:25')) -eq '') "p75-med=$($b7.p75 - $b7.med), efectivo 30"

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'la banda de habitos se mide sola' -ForegroundColor Green
exit 0
