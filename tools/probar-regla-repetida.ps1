# ESA REGLA YA LA TIENES (1/10, ideas 20 y 18 de las 20 nuevas)
#
# MEDIDO sobre las 609 ordenes reales de braya: dicto A MANO la MISMA regla una y otra vez.
#     "regla: cuando abra elden ring pon modo noche"          ONCE veces
#     "regla: a las diez y media de la noche pon modo noche"   CINCO
#     "regla: avisame cuando la descarga de steam termino"      CINCO
# Veintiuna dictadas de TRES reglas. Y cada una creaba una regla NUEVA con otro id, asi que
# reglas.json acababa con once copias de la misma cosa, once veces el mismo disparo, y once ids
# distintos que braya tendria que borrar uno a uno.
#
# LO QUE DEFIENDE:
#  1. que una regla identica NO se cree dos veces, y que se diga cual es CON SU ID -sin el numero,
#     "esa ya la tienes" no sirve para borrarla-;
#  2. que un cambio de verdad SI pase: otra accion, otro disparador, u "siempre" en vez de hoy;
#  3. que la regla que ya existia quede como $script:ultimaRegla, para que "siempre" sepa a cual se
#     refiere (si no, decir la repetida y luego "siempre" tocaria la equivocada);
#  4. y que las copias '.antes-*' de memoria se barran a la semana (idea 18).
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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

Write-Host ''
Write-Host '-- 1. la comparacion: que cuenta como "la misma regla" --'
# SE EJECUTA el mismo filtro que hay en el fichero, con reglas de pega: asi se prueba el criterio,
# que es lo que decide, sin montar medio Invoke-ReglaVoz.
#
# DOS TROPIEZOS MIOS EN ESTAS LINEAS, los dos apuntados para que no vuelvan:
#   1. LAS COMAS NO SOBRAN: sin ellas, tres hashtables en lineas seguidas dentro de un @() no son
#      tres elementos del array.
#   2. Y UNA FUNCION QUE DEVUELVE @(una sola cosa) LA DESENVUELVE al salir, asi que devolvia el
#      hashtable pelado y '.Count' contaba sus SEIS CLAVES en vez de uno. Tres comprobaciones
#      salieron rojas acusando al codigo de un fallo que era del banco, dos veces seguidas.
# El codigo de verdad no sufre lo segundo: asigna a $igualR con @() delante, y una asignacion si
# conserva el array.
$reglasPega = @(
    @{ id = 1; tipo = 'juego'; valor = 'elden ring'; accion = 'pon modo noche'; cond = ''; hasta = '' },
    @{ id = 2; tipo = 'hora';  valor = '22:30';      accion = 'pon modo noche'; cond = ''; hasta = '' },
    @{ id = 3; tipo = 'juego'; valor = 'elden ring'; accion = 'baja el brillo'; cond = ''; hasta = '2026-10-01' }
)
function BuscaIguales([string]$tipo, [string]$valor, [string]$accion, [string]$condR = '', [string]$hastaR = '') {
    # el MISMO filtro que Invoke-ReglaVoz, letra por letra
    $enc = @($reglasPega | Where-Object {
        [string]$_.tipo -eq [string]$tipo -and
        [string]$_.valor -eq [string]$valor -and
        [string]$_.accion -eq [string]$accion -and
        [string]$_.cond -eq [string]$condR -and
        [string]$_.hasta -eq [string]$hastaR
    })
    # se devuelve un objeto con las dos cosas dentro: asi ni el array se desenvuelve ni hay que
    # envolver cada llamada en @() alla donde se llame
    return [pscustomobject]@{ cuantas = $enc.Count; primera = $(if ($enc.Count) { $enc[0] } else { $null }) }
}

$r1 = BuscaIguales 'juego' 'elden ring' 'pon modo noche'
Comp 'la misma regla se reconoce' ($r1.cuantas -eq 1) "$($r1.cuantas)"
Comp '  y dice CUAL es' ($null -ne $r1.primera -and [int]$r1.primera.id -eq 1) "id $(if ($r1.primera) { $r1.primera.id })"
Comp 'otra accion con el mismo disparador es OTRA regla' ((BuscaIguales 'juego' 'elden ring' 'sube el volumen').cuantas -eq 0) ''
Comp 'otro disparador con la misma accion es OTRA' ((BuscaIguales 'juego' 'hollow knight' 'pon modo noche').cuantas -eq 0) ''
Comp 'otro tipo con el mismo valor es OTRA' ((BuscaIguales 'hora' 'elden ring' 'pon modo noche').cuantas -eq 0) ''
# EL 'hasta' CUENTA: si la dictas otra vez y ahora la quieres para siempre, eso SI es un cambio
Comp 'la misma pero "siempre" en vez de hoy SI pasa' ((BuscaIguales 'juego' 'elden ring' 'baja el brillo' '' '').cuantas -eq 0) 'dictarla sin caducidad es un cambio'
Comp '  y con su misma caducidad, no' ((BuscaIguales 'juego' 'elden ring' 'baja el brillo' '' '2026-10-01').cuantas -eq 1) ''
# Y UNA CONDICION DISTINTA TAMBIEN ES OTRA REGLA
Comp 'una condicion distinta es otra regla' ((BuscaIguales 'juego' 'elden ring' 'pon modo noche' 'si hay poca bateria').cuantas -eq 0) ''

Write-Host ''
Write-Host '-- 2. el cableado de la regla repetida --'
$cuerpo = Traer 'Invoke-ReglaVoz'
$sin = (($cuerpo -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'el filtro esta dentro de Invoke-ReglaVoz' ($sin -match '\$igualR = @\(\$g \| Where-Object') ''
# ANTES DEL Add: si fuera despues, la regla ya estaria creada y la frase mentiria
$iFiltro = $sin.IndexOf('$igualR = @(')
$iAdd = $sin.IndexOf('[void]$g.Add($r); Save-Reglas')
Comp '  y ANTES de guardar la nueva' ($iFiltro -ge 0 -and $iAdd -ge 0 -and $iFiltro -lt $iAdd) "filtro en $iFiltro, Add en $iAdd"
Comp '  la frase lleva el id, para poder borrarla' ($sin -match 'Esa ya la tienes: es la regla ') ''
Comp '  y dice como borrarla' ($sin -match 'borra la regla') ''
Comp '  se apunta, para poder contarlo' ($sin -match "Add-Estadistica 'regla-repetida'") ''
# LA QUE YA EXISTIA QUEDA COMO ultimaRegla: si no, decir la repetida y luego "siempre" tocaria otra
Comp '  y la vieja queda como ultimaRegla' ($sin -match 'ultimaRegla = @\{ id = \[string\]') 'para que "siempre" acierte'
# Y NO SE GUARDA NADA en ese camino: no hay nada nuevo que guardar
$iRet = $sin.IndexOf('return ("Esa ya la tienes')
$trozoRep = if ($iFiltro -ge 0 -and $iRet -gt $iFiltro) { $sin.Substring($iFiltro, $iRet - $iFiltro) } else { 'Save-Reglas' }
Comp '  y NO se guarda el fichero de reglas' ($trozoRep -notmatch 'Save-Reglas') 'no hay nada nuevo que guardar'
# Y COMPARA LAS CINCO COSAS, no tres: con menos, dos reglas distintas se darian por iguales
foreach ($campo in @('tipo', 'valor', 'accion', 'cond', 'hasta')) {
    Comp ("  compara el campo '" + $campo + "'") ($sin -match ('\$_\.' + $campo + ' -eq')) ''
}

Write-Host ''
Write-Host '-- 3. las copias .antes-* se barren a la semana (idea 18) --'
$cuerpoT = Traer 'Clear-TmpViejo'
$sinT = (($cuerpoT -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'Clear-TmpViejo mira las copias de memoria' ($sinT -match "Filter '\*\.antes-\*'") ''
Comp '  en memoria, no en tmp' ($sinT -match '\$MemoriaDir -File -Filter') ''
Comp '  y solo las de mas de una semana' ($sinT -match 'AddDays\(-7\)') 'la de hoy se queda'
Comp '  cuenta lo que suelta, como el resto' ($sinT -match '\$viejasA[\s\S]{0,200}\$r\.bytes \+=') ''
Comp '  y lo dice' ($sinT -match 'COPIAS VIEJAS') ''
# EN SU PROPIO try: que esto falle no puede tumbar el barrido de tmp (regla 7)
$iCop = $sinT.IndexOf("Filter '*.antes-*'")
$antesCop = if ($iCop -gt 300) { $sinT.Substring($iCop - 300, 300) } else { $sinT.Substring(0, [Math]::Max(0, $iCop)) }
Comp '  dentro de su propio try' ($antesCop -match 'try \{') 'regla 7: que no se lleve el barrido de tmp'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'una regla que ya tienes no se crea otra vez' -ForegroundColor Green
exit 0
