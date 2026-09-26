# EL RUIDO SOLO IMPORTA SI TE HA COSTADO ALGO (26/09, idea 13 de las 121).
#
# El aviso de "hay mucho ruido" saltaba mirando SOLO el nivel de fondo, sin preguntarse si por
# ese ruido se habia perdido alguna llamada.
#
# MEDIDO sobre assistant.log + assistant.log.1: 36 avisos de oido-ruido, y en TREINTA Y TRES
# -el 91,7 %- no se habia caido ni una llamada del nombre en la hora anterior. Nova avisaba de
# un problema que no estaba teniendo. El 22/09 llego a soltar VEINTICINCO en doce horas.
#
# LO QUE FALTABA ERA EL OTRO DATO, y ya pasaba por el oido: cada rama que descarta un "nova"
# apunta su hora, y el aviso solo sale si hay alguno en la ultima media hora.
#
# Y EL NOVENO CAMPO, NO EL OCTAVO: el octavo lo ocupo esta misma tarde el repaso perdido por
# falta de RAM (idea 9). Dos ideas del mismo dia queriendo el mismo sitio.
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
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
$pSin = (($tp -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$aSin = (($ta -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. el oido cuenta las llamadas que se le caen --'
Comp 'existe apuntar_descarte' ($pSin -match 'def apuntar_descarte') ''
$n = @([regex]::Matches($pSin, 'apuntar_descarte\(')).Count
Comp '  y lo llaman las ramas de descarte' ($n -ge 4) "$n (la definicion mas los sitios)"
# LAS RAMAS DE VERDAD, por su nombre: si alguien anade una cuarta forma de descartar y no la
# apunta, el aviso volvera a dispararse sin motivo y nadie sabra por que.
Comp '  la del juez' ($pSin -match 'NOMBRE_PLANO\)\)[\s\S]{0,80}apuntar_descarte') ''
Comp '  la de la rafaga floja' ($pSin -match 'umbral_rafaga\(\)\)\)[\s\S]{0,300}apuntar_descarte') ''
Comp '  y la de la confianza' ($pSin -match 'umbral_confianza\(plano\), _porque\)\)[\s\S]{0,120}apuntar_descarte') ''
# SE APUNTA AUNQUE EL LOG SE CALLE: dos de esas ramas tienen freno de 60 s para la LINEA.
Comp 'la lista tiene tope' ($pSin -match 'del descartes_nova\[:-64\]') 'no crece sin fin'

Write-Host ''
Write-Host '-- 2. la ventana, y el campo NOVENO --'
$m = [regex]::Match($tp, '(?m)^DESCARTES_VENTANA\s*=\s*([0-9.]+)')
Comp 'se saca del archivo DESCARTES_VENTANA' $m.Success ''
if ($m.Success) { $DESCARTES_VENTANA = [double]$m.Groups[1].Value }
Comp '  es media hora' ($DESCARTES_VENTANA -ge 900 -and $DESCARTES_VENTANA -le 3600) "$([int]($DESCARTES_VENTANA/60)) minutos"
# EL SITIO: detras del octavo, que es de la idea 9 de esta misma tarde.
Comp 'el estado empieza por sus campos de siempre' ($pSin -match '"%\.1f\|%s\|%\.3f\|%d\|%d\|%d\|%d') ''
Comp '  y el nuevo va DETRAS del repaso perdido' ($pSin -match 'repaso_perdido or "-", desc_recientes') 'el octavo ya estaba cogido'
# Y NO SE VUELVE A MEDIR EL AUDIO: se reusa el ahora_f que ya hay.
Comp '  sin volver a llamar a nivel_salida' ($pSin -match 'desc_recientes = sum\(1 for t in descartes_nova if ahora_f') 'cada pulso costaria una medida de audio'

Write-Host ''
Write-Host '-- 3. el asistente lo lee, y "no se sabe" no es "cero" --'
$dG = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-OidoDescartes' }, $true)
Comp 'existe Get-OidoDescartes' ($null -ne $dG) ''
if ($dG) {
    $c = $dG.Extent.Text
    Comp '  con las guardas de siempre' ($c -match 'Test-EstadoFresco' -and $c -match 'Test-Path -LiteralPath \$RutaEstado') ''
    Comp '  y exige el noveno campo' ($c -match '\$st\.Count -lt 9') 'un oido viejo no lo trae'
    # -1 Y NO 0: esta es la diferencia que decide si un oido viejo deja a Nova muda.
    Comp '  devolviendo -1 cuando no se sabe' ($c -notmatch 'return 0') 'con 0 se callaria el aviso para siempre'
}

Write-Host ''
Write-Host '-- 4. y el decisor, ejecutado --'
$dT = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-AvisarRuido' }, $true)
Comp 'existe Test-AvisarRuido' ($null -ne $dT) ''
if ($dT) {
    function Log([string]$m) { }
    Invoke-Expression $dT.Extent.Text
    # CON RUIDO Y LLAMADAS CAIDAS: avisa, como siempre
    $script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
    Comp 'con ruido y llamadas caidas, avisa' ([bool](Test-AvisarRuido $true 1000 60000 3)) 'el caso que si merece la pena'
    # CON RUIDO PERO SIN NINGUNA CAIDA: se calla. Es el 91,7 % de los avisos de hoy.
    $script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
    Comp 'con ruido pero sin ninguna caida, se calla' ((Test-AvisarRuido $true 1000 60000 0) -eq $false) '33 de los 36 avisos medidos'
    # SIN DATO (-1): se comporta como hasta hoy
    $script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
    Comp 'sin dato, avisa como siempre' ([bool](Test-AvisarRuido $true 1000 60000 -1)) 'un oido viejo no puede dejarla muda'
    # Y POR DEFECTO TAMBIEN, que es como la llaman los bancos viejos
    $script:ruidoAvisado = $false; $script:ruidoLimpioDesde = 0
    Comp '  y sin pasarle el dato, igual' ([bool](Test-AvisarRuido $true 1000 60000)) 'el parametro es opcional a proposito'
    # NO REPITE
    $script:ruidoAvisado = $true; $script:ruidoLimpioDesde = 0
    Comp 'y no repite si ya aviso' ((Test-AvisarRuido $true 1000 60000 3) -eq $false) ''
}
Comp 'y el aviso le pasa la cuenta' ($aSin -match 'Test-AvisarRuido \(Get-OidoConRuido\) \$ahoraW \$rearmeR \(Get-OidoDescartes\)') ''

Write-Host ''
Write-Host '-- 5. contra el registro de verdad --'
$avisos = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'ENTORNO \(oido-ruido') { $avisos++ }
    }
}
Write-Host ("       $avisos avisos de ruido en el registro; medido antes: 33 de 36 sin ni una llamada caida detras")
Comp 'el aviso existia y se disparaba mucho' ($avisos -ge 20) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el ruido solo se dice cuando ha costado algo'
exit 0
