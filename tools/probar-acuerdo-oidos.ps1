# UNA CONFIANZA GRATIS PARA PARAKEET (26/09, idea 12 de las 121).
#
# EL AGUJERO: tres de cada cuatro ordenes llegaban al asistente SIN NINGUN numero de confianza.
# Medido sobre las 560 ordenes de registro.jsonl: 422 traen seguridad=null, el 75,4 %. Solo
# Whisper sabe decir lo seguro que esta de lo que oyo; cuando la orden la entrega Parakeet -que
# es lo normal- no hay nada, y el repaso del oido fino no se puede disparar por falta de dato.
#
# LO QUE SI HAY, Y NO CUESTA NADA: Vosk ya oyo esa misma frase para abrir el microfono. Cuanto
# se parecen los dos es una confianza gratis. Medido sobre 273 ordenes con destino apuntado:
#     acuerdo >= 0,50   n=146   13 acabaron en nada =  9 %
#     acuerdo 0,2-0,5   n= 77    6 acabaron en nada =  8 %
#     acuerdo <  0,20   n= 50   14 acabaron en nada = 28 %
# Y el 0,2 no es a ojo: es el percentil 20 exacto de los 421 pares medidos.
#
# ESTE BANCO VIGILA DOS TRAMPAS, y las dos son averias MUDAS -sin log, sin excepcion y sin
# banco rojo si no se comprueban a mano-:
#   1. dictado-confianza.txt lo escribe TAMBIEN Whisper con su avg_logprob. Escribir el acuerdo
#      siempre lo pisaria justo cuando Whisper acaba de trabajar, y el asistente perderia el
#      unico dato que hoy dispara el repaso.
#   2. cargar_lista tira el fichero ENTERO si ve un valor fuera de (0, tope). El 15 % de los
#      pares da 0,00 clavado y otro 15 % da 1,00: sin pisar a (0,01..1,0) y sin tope 1.01, el
#      liston se quedaria en el de arranque para siempre y en verde.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$tp = [IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [Text.Encoding]::UTF8)
$ta = [IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'), [Text.Encoding]::UTF8)
$pSin = (($tp -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$aSin = (($ta -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. las constantes, y de donde sale cada una --'
foreach ($c in @('ACUERDO_ARRANQUE', 'ACUERDO_SUELO', 'ACUERDO_TECHO', 'ACUERDO_PERCENTIL', 'ACUERDO_MEMORIA', 'ACUERDO_MINIMAS')) {
    $m = [regex]::Match($tp, ('(?m)^' + $c + '\s*=\s*([0-9.]+)'))
    Comp ("se saca del archivo " + $c) $m.Success ''
    if ($m.Success) { Set-Variable -Name $c -Value ([double]$m.Groups[1].Value) }
}
# EL 0,2 ES SU PROPIO p20, no un numero a ojo. Se dice aqui y no se saca de la constante, que
# seria una tautologia.
Comp 'el de arranque es el p20 medido' ($ACUERDO_ARRANQUE -eq 0.2) 'p20 de 421 pares = 0,200'
Comp 'el suelo y el techo salen de los p20 por dia' ($ACUERDO_SUELO -le 0.05 -and $ACUERDO_TECHO -ge 0.27 -and $ACUERDO_TECHO -le 0.35) "$ACUERDO_SUELO - $ACUERDO_TECHO; medidos 0,040 y 0,269"
# Y LAS MISMAS QUE LA COBERTURA: memoria y minimas no se inventan, se copian de su hermana.
$mCM = [regex]::Match($tp, '(?m)^COBERTURA_MEMORIA\s*=\s*([0-9]+)')
$mCN = [regex]::Match($tp, '(?m)^COBERTURA_MINIMAS\s*=\s*([0-9]+)')
Comp '  y la memoria es la de la cobertura' ($mCM.Success -and $ACUERDO_MEMORIA -eq [double]$mCM.Groups[1].Value) "$ACUERDO_MEMORIA"
Comp '  y las minimas tambien' ($mCN.Success -and $ACUERDO_MINIMAS -eq [double]$mCN.Groups[1].Value) "$ACUERDO_MINIMAS"

Write-Host ''
Write-Host '-- 2. TRAMPA 1: no pisar el numero de Whisper --'
# ESTA ES LA COMPROBACION QUE EVITA EL DESTROZO. Si el acuerdo se escribiera siempre, taparia
# el avg_logprob justo cuando Whisper acaba de correr.
$i = $pSin.IndexOf('_acu = acuerdo_oidos(')
Comp 'se calcula el acuerdo' ($i -ge 0) ''
$bl = if ($i -ge 0) { $pSin.Substring([Math]::Max(0, $i - 400), [Math]::Min(1400, $pSin.Length - [Math]::Max(0, $i - 400))) } else { '' }
Comp '  SOLO si Whisper no corrio' ($bl -match '_ultima_seguridad is None') 'si no, pisa el avg_logprob'
# Y NO VALE MIRAR "if rapido": repasar_si_ingles puede devolver rapido vacio y mejor lleno.
Comp '  y no por "si hubo texto rapido"' ($bl -notmatch 'if rapido') 'repasar_si_ingles puede dar rapido vacio y mejor lleno'
Comp '  ni con un dictado callado' ($bl -match 'not callado') ''
# EL FORMATO: el numero PRIMERO, para que un lector viejo siga leyendo un numero.
Comp '  y escribe el numero primero' ($pSin -match '"%\.2f acuerdo %\.2f"') 'un lector viejo hace float() de la primera palabra'

Write-Host ''
Write-Host '-- 3. TRAMPA 2: el 0,0 que tira el fichero entero --'
# cargar_lista exige 0.0 < v < tope_valor ESTRICTO: con UN solo valor fuera devuelve [] y el
# liston se queda en el de arranque para siempre, sin decir nada.
$iA = $pSin.IndexOf('def apuntar_acuerdo')
$blA = if ($iA -ge 0) { $pSin.Substring($iA, [Math]::Min(700, $pSin.Length - $iA)) } else { '' }
Comp 'el valor se pisa antes de guardarlo' ($blA -match 'min\(1\.0, max\(0\.01') 'el 15 % de los pares da 0,00 y otro 15 % da 1,00'
Comp '  y se carga con tope 1.01' ($pSin -match 'cargar_lista\(RUTA_ACUERDOS, ACUERDO_MEMORIA, 1\.01\)') 'cargar_lista exige v < tope ESTRICTO'
# Y QUE EL DETECTOR DETECTE: se comprueba que cargar_lista sigue siendo asi de estricta, porque
# si algun dia dejara de serlo, estas dos guardas dejarian de hacer falta... y nadie lo sabria.
Comp '  y cargar_lista sigue siendo estricta' ($pSin -match '0\.0 < v < tope_valor') 'si esto cambia, revisar las dos guardas de arriba'

Write-Host ''
Write-Host '-- 4. la cuenta del acuerdo, ejecutada --'
# La misma formula, para comprobar que separa lo que dice separar.
function Jac([string]$a, [string]$b) {
    $ta = @(($a -split '\s+') | Where-Object { $_ })
    $tb = @(($b -split '\s+') | Where-Object { $_ })
    if (-not $ta.Count -or -not $tb.Count) { return $null }
    $sa = New-Object 'System.Collections.Generic.HashSet[string]' (,[string[]]$ta)
    $sb = New-Object 'System.Collections.Generic.HashSet[string]' (,[string[]]$tb)
    $inter = New-Object 'System.Collections.Generic.HashSet[string]' (,[string[]]$ta)
    $inter.IntersectWith($sb)
    $union = New-Object 'System.Collections.Generic.HashSet[string]' (,[string[]]$ta)
    $union.UnionWith($sb)
    return $inter.Count / [double]$union.Count
}
Comp 'dos frases iguales dan 1' ((Jac 'cierra steam' 'cierra steam') -eq 1.0) ''
Comp 'dos frases sin nada en comun dan 0' ((Jac 'cierra steam' 'pon musica') -eq 0.0) ''
$med = Jac 'baja el volumen' 'baja el brillo'
Comp 'a medias, algo en medio' ($med -gt 0.3 -and $med -lt 0.7) ([string][Math]::Round($med, 2))

Write-Host ''
Write-Host '-- 5. y el asistente lo usa sin confundirlo --'
Comp 'el asistente distingue el acuerdo del avg_logprob' ($aSin -match "\`$partesC\[1\] -eq 'acuerdo'") 'son dos numeros distintos en el mismo fichero'
Comp '  y al ver uno, deshace el otro' ($aSin -match '\$script:dictadoAcuerdoEn = -999999') 'un acuerdo viejo no sobrevive a un dictado de Whisper'
Comp 'hay un repaso por desacuerdo' ($aSin -match '\$script:dictadoAcuerdo -lt \$script:dictadoAcuerdoListon') ''
Comp '  con su propio contador' ($aSin -match "Add-Estadistica 'fino-acuerdo'") 'para poder medir despues si sirvio'
# EL LISTON VIAJA EN EL FICHERO: el asistente no lo recalcula ni lo lleva escrito.
Comp '  y el liston lo manda el oido' ($aSin -match '\$script:dictadoAcuerdoListon = \[double\]::Parse') 'aqui no hay ningun numero a mano'
# EL CAMINO DE WHISPER NO SE TOCA
Comp 'el repaso de Whisper sigue intacto' ($aSin -match '\$script:dictadoConfianza -lt \$RepasoDudosoUmbral') ''

Write-Host ''
Write-Host '-- 6. contra las grabaciones de verdad --'
$reg = Join-Path $raiz 'pruebas\audio\uso\registro.jsonl'
if (Test-Path -LiteralPath $reg) {
    $n = 0; $sinSeg = 0; $conPar = 0
    foreach ($l in @(Get-Content -LiteralPath $reg -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -notmatch '"entregado"') { continue }
        $n++
        if ($l -match '"seguridad"\s*:\s*null') { $sinSeg++ }
        if ($l -match '"vosk"\s*:\s*"[^"]+"' -and $l -match '"parakeet"\s*:\s*"[^"]+"') { $conPar++ }
    }
    Write-Host ("       $n ordenes: $sinSeg sin numero de confianza, y $conPar con los dos textos")
    Comp 'el agujero es grande' ($n -gt 0 -and ($sinSeg / [double]$n) -gt 0.5) "$([int](100.0*$sinSeg/[Math]::Max(1,$n))) % sin dato"
    Comp '  y casi siempre se puede tapar' ($n -gt 0 -and ($conPar / [double]$n) -gt 0.5) "$([int](100.0*$conPar/[Math]::Max(1,$n))) % con los dos textos"
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  las ordenes de Parakeet ya traen confianza'
exit 0
