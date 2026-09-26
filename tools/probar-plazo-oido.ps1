# EL PLAZO DE CADA REPASO SALE DE LO QUE TARDA ESE MOTOR (26/09, idea 8 de las 121).
#
# Todos los repasos del oido compartian UN plazo escrito a mano, 15 s, y el ultimo recurso otro,
# 60 s: dos numeros fijos para cinco motores que tardan cosas muy distintas.
#
# MEDIDO sobre las 477 filas con 'segundos' de pruebas\audio\uso\registro.jsonl:
#     base   n=328  p50 1,75 s  p99 24,09   pasan de 15 s:  6
#     small  n=94   p50 4,66    p99 238,88  pasan de 15 s: 12
#     canary n=29   p50 2,99    p99 14,53   pasan de 15 s:  0
#     turbo  n=23   p50 16,21   p99 76,53   pasan de 15 s: 17
#     omni   n=3                            pasan de 15 s:  1
# Y lo que costaba: 30 lineas "sin respuesta a tiempo", y las 30 tenian respuesta DESPUES, a
# 8, 12, 14, 23, 28, 30, 35, 45, 61, 88, 142 y hasta 238,9 s. Treinta repasos pagados y tirados.
#
# EL PERCENTIL ES 99 Y NO 90, Y ES LO QUE MAS VIGILA ESTE BANCO. Simulado sobre las 477
# medidas: p90 da DIECISIETE timeouts nuevos contra 3 rescatados -peor que hoy-, p95 da 11
# contra 4, y p99 da CERO nuevos contra 8 rescatados. Un percentil usado como plazo de RENDIRSE
# garantiza por construccion que el (100-p) % se tire.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. las cuatro constantes, y el 99 se defiende solo --'
foreach ($c in @('PlazoOidoPercentil', 'PlazoOidoMin', 'PlazoOidoSuelo', 'PlazoOidoTecho')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $c + '\s*=\s*([0-9.]+)'))
    Comp ("se saca del archivo " + $c) $m.Success ''
    if ($m.Success) { Set-Variable -Name $c -Value ([double]$m.Groups[1].Value) }
}
# EL LISTON QUE NO PUEDE SALIR DE LA CONSTANTE: si esto se comparara con $PlazoOidoPercentil,
# seria una tautologia. El 99 se dice aqui a proposito.
Comp 'el percentil es 99, no 90' ($PlazoOidoPercentil -eq 99) 'p90 daria 17 timeouts nuevos contra 3 rescatados'
Comp '  y NO es el 75 de la barra' ($PlazoOidoPercentil -ne 75) 'p75 de small son 8,4 s: hundiria el oido fino'
Comp 'el techo es el doble de lo escrito' ($PlazoOidoTecho -eq 2.0) 'sin el, small se iria a 238,9 s y el micro se quedaria sordo 4 minutos'

Write-Host ''
Write-Host '-- 2. la funcion, ejecutada sobre los tiempos de verdad --'
foreach ($n in @('Get-RepasoTiempos', 'Get-PlazoOido')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    Comp "existe $n" ($null -ne $d) ''
    if ($d) { Invoke-Expression $d.Extent.Text }
}
$LogDir = $raiz
function Log([string]$m) { }
$t = Get-RepasoTiempos
Comp 'se leen los tiempos del registro' ($t.Count -ge 3) "$($t.Count) motores con medidas"
# LOS CINCO MOTORES, CON EL NUMERO QUE TIENE QUE SALIR. Calculados a mano de las 477 medidas.
$esperado = @{ canary = 14530; base = 24090; small = 30000; turbo = 76530 }
foreach ($mo in @('canary', 'base', 'small', 'turbo')) {
    $esc = if ($mo -eq 'turbo') { 60000 } else { 15000 }
    $p = Get-PlazoOido $mo $esc
    $q = $esperado[$mo]
    Comp ("$mo sale a $([int]($p/1000)) s") ([Math]::Abs($p - $q) -le 1000) "esperado $([int]($q/1000)) s; escrito $([int]($esc/1000))"
}
# small ES EL QUE DEMUESTRA EL TECHO: su p99 real son 238,9 s.
Comp '  y small se queda en el techo, no en su p99' ((Get-PlazoOido 'small' 15000) -eq 30000) 'su p99 son 238,9 s'
# POCAS MUESTRAS: manda lo escrito. omni tiene 3.
$nOmni = if ($t.ContainsKey('omni')) { $t['omni'].Count } else { 0 }
Comp "con pocas muestras manda lo escrito (omni, n=$nOmni)" ((Get-PlazoOido 'omni' 15000) -eq 15000) "hacen falta $([int]$PlazoOidoMin)"
# LO QUE NO PUEDE PASAR NUNCA: devolver 0 o algo absurdo.
Comp 'un motor que no existe devuelve lo escrito' ((Get-PlazoOido 'no-existe-este-motor' 15000) -eq 15000) ''
Comp 'sin motor, lo escrito' ((Get-PlazoOido '' 15000) -eq 15000) ''
Comp 'sin numero escrito, no devuelve cero' ((Get-PlazoOido 'base' 0) -gt 0) 'un plazo de 0 dejaria el repaso muerto al nacer'

Write-Host ''
Write-Host '-- 3. y el plazo nuevo no pierde ningun repaso que hoy llegaba --'
# LA COMPROBACION QUE DE VERDAD IMPORTA, y la que tumbo el p90 de la idea: contar sobre las 477
# medidas cuantos repasos se PIERDEN con el plazo nuevo y cuantos se RESCATAN. Si se pierde
# alguno, el percentil esta mal elegido.
$nuevos = 0; $rescatados = 0; $detalle = @()
foreach ($mo in @($t.Keys)) {
    $esc = if ($mo -eq 'turbo') { 60000 } else { 15000 }
    $p = Get-PlazoOido $mo $esc
    foreach ($ms in @($t[$mo])) {
        if ($ms -le $esc -and $ms -gt $p) { $nuevos++; $detalle += "$mo $([int]($ms/1000))s" }
        elseif ($ms -gt $esc -and $ms -le $p) { $rescatados++ }
    }
}
Write-Host ("       con el plazo nuevo: $rescatados repasos rescatados, $nuevos perdidos")
Comp 'no se pierde ni un repaso que hoy llegaba' ($nuevos -eq 0) $(if ($detalle.Count) { ($detalle -join ', ') } else { '' })
Comp '  y se rescatan varios de los que hoy se tiran' ($rescatados -ge 5) "$rescatados"

Write-Host ''
Write-Host '-- 4. y el codigo lo usa en los cuatro sitios --'
$n = @([regex]::Matches($sinCom, 'Get-PlazoOido')).Count
Comp 'Get-PlazoOido se usa cuatro veces' ($n -ge 5) "$n (la definicion mas cuatro usos)"
Comp '  en la cascada, con el motor del escalon' ($sinCom -match 'Get-PlazoOido \$quien \$ReintentoMaxMs') ''
Comp '  en el ultimo recurso, con turbo' ($sinCom -match "Get-PlazoOido 'turbo' \`$ReintentoUltimoMs") ''
Comp '  y en los dos del oido fino, con small' (@([regex]::Matches($sinCom, "Get-PlazoOido 'small'")).Count -eq 2) ''
# NO SE TOCAN LOS NUMEROS DE SIEMPRE: ahora son el respaldo, no sobran.
Comp 'los numeros escritos siguen existiendo' (($txt -match '\$ReintentoMaxMs = 15000') -and ($txt -match '\$ReintentoUltimoMs = 60000')) 'son el respaldo cuando no hay medidas'
# Y EL LOG DEL ABANDONO TIENE QUE DECIR EL PLAZO: ya no hay un unico 15, asi que sin eso un
# "sin respuesta a tiempo" no se puede leer ni contar.
Comp 'el abandono dice con que plazo se rindio' ($sinCom -match 'sin respuesta a tiempo \(plazo') ''
# LA BARRA DE ESPERA NO SE ENTERA DE NADA: son dos decisiones distintas y no comparten constante.
Comp 'la barra de espera sigue con sus propias constantes' (($txt -match '\$TrabajoPercentil = 75') -and ($sinCom -notmatch 'Get-DuracionEsperada[^\r\n]*PlazoOido')) 'afinar la barra no puede romper el oido'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  cada motor tiene el plazo que de verdad necesita'
exit 0
