# NOVENTA SEGUNDOS ESPERANDO A QUE ELIJAS UN AMIGO, SIN HABER MEDIDO CUANTO TARDAS (27/09, idea 97)
#
# EL FALLO DE FONDO NO ERA EL NUMERO, ERA DESDE CUANDO SE CUENTA: los 90 s arrancaban al ARMAR el
# selector, o sea antes de leer la lista en voz alta. Diez nombres leidos son unos 15 s, asi que la
# ventana efectiva para elegir eran ~75 s y eso no estaba escrito en ningun sitio.
#
# Y LO QUE HABIA MEDIDO NO SERVIA, que es lo que corrigio el verificador de la ficha:
# memoria\habitos.json guarda 30 medidas de ritmo -mediana 2,26 s, p80 3,75 s, maxima 6,26 s-, pero
# eso es "cuanto tarda en EMPEZAR a hablar tras una frase corta", no "cuanto tarda en elegir de una
# lista de diez oida". Y ademas hoy no daria nada: NINGUNA de las 30 lleva fecha, asi que
# Get-VentanaSeguimiento se va por su guarda de 3 dias distintos y devuelve el valor por defecto.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la ventana empiece cuando Nova CALLA, no cuando se arma el selector
#   2. que hasta tener datos suyos manda el numero escrito, y que ese numero es un TECHO
#   3. que con 5 medidas en 3 dias distintos la ventana salga de SUS datos
#   4. que una sola tarde de pruebas no pueda decidirla
#   5. que nunca baje de un suelo, que cortarle la eleccion cuesta repetir la orden entera
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
foreach ($f in @('Get-AmigoEligeDesde', 'Add-RitmoElegir', 'Get-VentanaElegir')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$AmigoEligeMs = 25000
$EligeTopeDia = 3
$EligeMax = 20
Comp 'el techo sale del archivo' ($txt -match '\$AmigoEligeMs = 25000') 'eran 90.000'
Comp '  y ya no es el de antes' (-not ($txt -match '\$AmigoEligeMs = 90000')) ''
Comp '  con tope de medidas por dia' ($txt -match '\$EligeTopeDia = 3') 'una tarde no llena la lista'

# EL MUNDO DE MENTIRA, despues de cargar
$script:invitado = $false
$script:vozFinReal = 0
$script:finVoz = 0
$script:habitos = $null
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
$guardados = 0
function Save-Habitos { $script:guardados++ }
function Get-Habitos {
    if ($null -eq $script:habitos) { $script:habitos = @{ ritmo = (New-Object System.Collections.ArrayList) } }
    return $script:habitos
}
function Reset {
    $script:habitos = $null
    $script:logs = @()
    $script:invitado = $false
    $script:vozFinReal = 0
    $script:finVoz = 0
    $script:guardados = 0
}

Write-Host ''
Write-Host '-- 1. LA VENTANA EMPIEZA CUANDO NOVA CALLA (el fallo de fondo) --'
Reset
$e = @{ en = 1000 }
Comp '1a. sin voz todavia, cuenta desde que se armo' ((Get-AmigoEligeDesde $e) -eq 1000) ([string](Get-AmigoEligeDesde $e))
# leer diez nombres son unos 15 s: la voz acaba mucho despues de armarse el selector
$script:vozFinReal = 16000
Comp '1b. con la voz acabada, cuenta desde ahi' ((Get-AmigoEligeDesde $e) -eq 16000) ([string](Get-AmigoEligeDesde $e) + '; antes los 90 s ya llevaban 15 gastados')
$script:vozFinReal = 0
$script:finVoz = 14500
Comp '1c. y vale cualquiera de los dos relojes de voz' ((Get-AmigoEligeDesde $e) -eq 14500) 'Say-Online usa uno y la voz local el otro'
$script:vozFinReal = 16000
Comp '1d. de los dos, el mas tardio' ((Get-AmigoEligeDesde $e) -eq 16000) ''
$script:vozFinReal = 500
$script:finVoz = 400
Comp '1e. y nunca antes de armarse' ((Get-AmigoEligeDesde $e) -eq 1000) 'una voz vieja de otra frase no adelanta la ventana'
Comp '1f. sin selector, cero' ((Get-AmigoEligeDesde $null) -eq 0) 'y no revienta'

Write-Host ''
Write-Host '-- 2. SIN DATOS SUYOS MANDA EL NUMERO ESCRITO --'
Reset
Comp '2a. sin medidas, el techo' ((Get-VentanaElegir) -eq $AmigoEligeMs) ([string](Get-VentanaElegir) + ' ms')
$null = Add-RitmoElegir 4.0
Comp '2b. con una medida tampoco cambia' ((Get-VentanaElegir) -eq $AmigoEligeMs) 'hacen falta cinco'

Write-Host ''
Write-Host '-- 3. UNA TARDE DE PRUEBAS NO DECIDE ESTO --'
Reset
# cinco medidas del MISMO dia: no bastan
for ($i = 0; $i -lt 8; $i++) { $null = Add-RitmoElegir (3.0 + $i) }
Comp '3a. el tope por dia muerde' (@((Get-Habitos).elegir).Count -le $EligeTopeDia) ([string]@((Get-Habitos).elegir).Count + ' de ' + [string]$EligeTopeDia)
Comp '3b. y con un solo dia sigue el techo' ((Get-VentanaElegir) -eq $AmigoEligeMs) 'la misma guarda que las otras decisiones propias'

Write-Host ''
Write-Host '-- 4. CON SUS DATOS, LA VENTANA SALE DE ELLOS --'
Reset
# cinco medidas en tres dias distintos, metidas a mano para no pelearse con el tope diario
$h = Get-Habitos
$h['elegir'] = New-Object System.Collections.ArrayList
foreach ($m in @(@(3.0, '2026-09-25'), @(4.0, '2026-09-25'), @(5.0, '2026-09-26'), @(6.0, '2026-09-26'), @(7.0, '2026-09-27'))) {
    [void]$h.elegir.Add(@{ s = [double]$m[0]; f = [string]$m[1] })
}
$v = Get-VentanaElegir
Comp '4a. ya no manda el techo' ($v -lt $AmigoEligeMs) ([string]$v + ' ms en vez de ' + [string]$AmigoEligeMs)
# EL P90 DE CINCO MEDIDAS ES EL CUARTO: Floor((5-1)*0.9) = Floor(3,6) = 3, o sea $ordE[3] = 6 s.
# (Escribi 7 aqui la primera vez y el banco me corrigio: con cinco muestras el p90 no es la mayor.)
Comp '4b. y sale del p90 mas dos segundos' ($v -eq 8000) ([string]$v + ' ms; el p90 de 3-4-5-6-7 s es 6 s')
Comp '4c. lo que es cuatro veces menos que los 90.000 de antes' ($v -lt 25000) ''
# y si tarda MAS, la ventana sube... hasta el techo
$h['elegir'] = New-Object System.Collections.ArrayList
foreach ($m in @(@(20.0, '2026-09-25'), @(22.0, '2026-09-25'), @(30.0, '2026-09-26'), @(40.0, '2026-09-26'), @(60.0, '2026-09-27'))) {
    [void]$h.elegir.Add(@{ s = [double]$m[0]; f = [string]$m[1] })
}
Comp '4d. si tardara mucho, la ventana no pasa del techo' ((Get-VentanaElegir) -eq $AmigoEligeMs) ([string](Get-VentanaElegir) + '; el techo solo puede bajar')
# y si tarda muy poco, hay suelo
$h['elegir'] = New-Object System.Collections.ArrayList
foreach ($m in @(@(0.5, '2026-09-25'), @(0.6, '2026-09-25'), @(0.7, '2026-09-26'), @(0.8, '2026-09-26'), @(0.9, '2026-09-27'))) {
    [void]$h.elegir.Add(@{ s = [double]$m[0]; f = [string]$m[1] })
}
Comp '4e. y nunca baja del suelo' ((Get-VentanaElegir) -ge 6000) ([string](Get-VentanaElegir) + ' ms; cortarle la eleccion cuesta repetir la orden entera')

Write-Host ''
Write-Host '-- 5. LO QUE NO SE APUNTA --'
Reset
Comp '5a. una eleccion instantanea imposible, no' (-not (Add-RitmoElegir 0)) 'ni negativa'
Comp '5b. ni una de dos minutos' (-not (Add-RitmoElegir 121)) 'eso es que se fue y volvio'
Comp '5c. y en modo invitado tampoco' ($(try { $script:invitado = $true; -not (Add-RitmoElegir 4.0) } finally { $script:invitado = $false })) 'lo que haga otro no ajusta sus numeros'
Comp '5d. asi que no se ha guardado nada' ($script:guardados -eq 0) ([string]$script:guardados + ' guardado(s)')
Comp '5e. y una normal SI' (Add-RitmoElegir 4.0) ''
Comp '5f. con su fecha' ([string]@((Get-Habitos).elegir)[0].f -eq (Get-Date -Format 'yyyy-MM-dd')) 'sin fecha no cuenta para los dias: es lo que le pasa hoy a las 30 de ritmo'

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
Comp '6a. la ventana se consulta, no se escribe a ojo' ($sinCom -match '-lt \(Get-VentanaElegir\)') ''
Comp '6b. y el origen tambien' ($sinCom -match '\$sw\.ElapsedMilliseconds - \(Get-AmigoEligeDesde \$script:amigoEligiendo\)') ''
Comp '6c. al elegir se mide' ($sinCom -match '\$segE = \(\$sw\.ElapsedMilliseconds - \(Get-AmigoEligeDesde \$eV\)\) / 1000\.0') ''
Comp '6d. y se dice en el registro' ($sinCom -match 'ELEGIR: tardaste') 'un numero que se ajusta y no se ve no ha pasado'
# LA GUARDA DE VERDAD NO ERA EL ORDEN, ERA DE DONDE SE LEE. Escribi primero "la medida va antes de
# vaciar el selector" y el banco lo tumbo: dentro de Complete-AmigoElige hay DOS
# '$script:amigoEligiendo = $null' -uno en la rama de invitado, que va antes de todo-. Mirandolo, el
# orden da igual: la medida usa $eV, que es la COPIA local que se saco al entrar, asi que sigue
# valiendo aunque la variable del script ya este vacia. Lo que hay que vigilar es justo eso.
$cAE = Traer 'Complete-AmigoElige'
Comp '6e. la medida lee la copia local, no la variable del script' (
    $cAE -match '\(Get-AmigoEligeDesde \$eV\)' -and -not ($cAE -match 'Get-AmigoEligeDesde \$script:amigoEligiendo')) 'asi vaciar el selector no se lleva el momento de partida'
Comp '6e bis. y el selector se saca al entrar' ($cAE -match '\$eV = \$script:amigoEligiendo') ''
Comp '6f. un numero fuera de la lista no cuenta como eleccion' ($sinCom -match '(?s)No tengo un \$n en esa lista\.".{0,400}\$segE =') ''
Comp '6g. y se guarda con los demas habitos' ($sinCom -match "elegir = @\(\`$\(if \(\`$hb\.ContainsKey\('elegir'\)\)") ''
Comp '6h. y se relee' ($sinCom -match "\`$crudoH\.PSObject\.Properties\['elegir'\]") 'si no, cada arranque volveria al techo'
Comp '6i. y NO se reutiliza el ritmo de hablar' (-not ((Traer 'Get-VentanaElegir') -match 'Get-VentanaSeguimiento|\$hbV\.ritmo')) 'mide otra tarea: 30 medidas de arrancar a hablar, no de elegir de una lista'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la ventana de elegir empieza cuando Nova calla y sale de sus propias medidas' -ForegroundColor Green
exit 0
