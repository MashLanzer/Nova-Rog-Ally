# LOS DOS AVISOS DE BATERIA QUE NO SABIAN UNO DEL OTRO (25/09, idea 7)
#
# LA SOSPECHA ERA OTRA y era FALSA, conviene decirlo: la idea 7 decia "el 15 % nunca se ha
# validado, avisa aunque tengas el cargador puesto". Se midio y NO: las dos ramas miran
# $cargando (BatteryStatus -eq 2) antes de abrir la boca. Ahi no habia nada que arreglar.
#
# LO QUE SI DESTAPO LA MEDICION, que es lo que prueba este banco:
#   1. Habia DOS avisos para el mismo hecho, a 66 lineas uno del otro, y ninguno sabia del
#      otro: al cruzar el liston saltaban LOS DOS -un aviso de prioridad alta por la cola del
#      entorno Y la frase hablada-. Lo mismo dicho dos veces.
#   2. El de arriba llevaba el 15 ESCRITO A MANO en vez de $BateriaAviso. O sea que mover
#      avisos.bateriaPct en config.json cambiaba uno de los dos y dejaba el otro en 15.
#
# LO QUE NO SE HACE, y es importante: NO se mueve el 15. Para eso no hay datos -UN solo aviso
# en 16 dias (11/09 17:16) y las tres unicas veces que se apunto a que porcentaje enchufa braya
# fueron al 97, 100 y 100 %: la consola vive enchufada-. Sin datos no se mueve un numero, que
# es la regla 3 de la casa.
#
# Y NO SE BORRA NINGUNO DE LOS DOS, porque querian cosas distintas: el de abajo es el PRIMER
# aviso (con pestillo, y con un juego delante no habla: capsula ambar y pregunta por el brillo);
# el de arriba es el RECORDATORIO mientras sigas sin enchufar, con su plazo de 20 minutos.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. EL NUMERO NO ESTA DUPLICADO --'
# EL FALLO ORIGINAL, escrito como comprobacion para que no pueda volver: un 15 suelto al lado
# de una comparacion de bateria. Se mira sin comentarios, porque esta cabecera habla del 15.
# Del 1 al 99, a proposito: "$pc -le 0" es la comprobacion de que la lectura sirve (linea 133)
# y "-gt 100" lo mismo por arriba. Esos son sanidad, no un liston, y prohibirlos era un falso
# positivo que salio la primera vez que corrio este banco.
$aPelo = @([regex]::Matches($sinCom, '\$pc\s+-le\s+(?:[1-9]|[1-9]\d)\b')).Count
Comp 'ninguna rama compara el % contra un numero escrito a mano' ($aPelo -eq 0) "$aPelo encontrada(s)"
$usos = @([regex]::Matches($sinCom, '\$BateriaAviso')).Count
Comp 'el liston sale de la constante' ($usos -ge 2) "$usos uso(s) de BateriaAviso"

Write-Host ''
Write-Host '-- 2. LAS DOS RAMAS USAN LA MISMA DECISION --'
Comp 'existe Get-AvisoBateria' ($sinCom -match 'function Get-AvisoBateria') ''
Comp 'existe Test-BateriaRearme' ($sinCom -match 'function Test-BateriaRearme') ''
$llam = @([regex]::Matches($sinCom, '(?<!function )Get-AvisoBateria')).Count
Comp 'y las DOS ramas preguntan a la misma funcion' ($llam -ge 2) "$llam llamada(s); si fuera 1, una de las dos volveria a decidir por su cuenta"
$reOK = @([regex]::Matches($sinCom, '(?<!function )Test-BateriaRearme')).Count
Comp 'el rearme tambien' ($reOK -ge 1) "$reOK llamada(s)"

Write-Host ''
Write-Host '-- 3. LAS FUNCIONES, SACADAS DEL ARCHIVO Y EJECUTADAS --'
foreach ($n in @('Get-AvisoBateria', 'Test-BateriaRearme')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ("se saca $n del arbol") $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
    Invoke-Expression $d.Extent.Text
}
# el liston, del archivo (manera 6): no una copia escrita aqui
$mB = [regex]::Match($txt, '(?m)^\$BateriaAviso\s*=\s*\[int\]\(Get-Cfg\s+''avisos''\s+''bateriaPct''\s+(\d+)\)')
Comp 'se saca del archivo el liston por defecto' $mB.Success ''
$BateriaAviso = if ($mB.Success) { [int]$mB.Groups[1].Value } else { 15 }
Write-Host ("     el liston por defecto es " + $BateriaAviso)

# CON EL CARGADOR PUESTO, NADA. Aunque este al 3 %.
Comp 'con el cargador puesto no dice nada' ((Get-AvisoBateria 3 $true $false) -eq '') 'ni al 3 %'
Comp '  ni el recordatorio' ((Get-AvisoBateria 3 $true $true) -eq '') ''

# POR ENCIMA DEL LISTON, NADA
Comp 'por encima del liston, nada' ((Get-AvisoBateria ($BateriaAviso + 1) $false $false) -eq '') "al $($BateriaAviso + 1) %"

# EL PRIMER CRUCE: UNO SOLO, y es el primero
$p = Get-AvisoBateria $BateriaAviso $false $false
Comp 'al cruzar el liston toca el PRIMERO' ($p -eq 'primero') "devolvio '$p'"
Comp '  y NO el recordatorio a la vez' ($p -ne 'recordatorio') 'este es el doblete que se arreglo'

# LA SEGUNDA PASADA: el recordatorio, y solo el recordatorio
$r = Get-AvisoBateria $BateriaAviso $false $true
Comp 'ya avisada, toca el RECORDATORIO' ($r -eq 'recordatorio') "devolvio '$r'"
Comp '  y no repite el primero' ($r -ne 'primero') 'el pestillo sigue valiendo'

# LOS DOS NUNCA A LA VEZ: una funcion que devuelve UNA cosa no puede dar dos avisos.
# Se comprueba barriendo todo el rango, que es mas fuerte que mirar dos casos.
$dobles = 0
foreach ($pct in 0..100) {
    foreach ($cg in @($true, $false)) {
        foreach ($ya in @($true, $false)) {
            $v = Get-AvisoBateria $pct $cg $ya
            if ($v -notin @('', 'primero', 'recordatorio')) { $dobles++ }
        }
    }
}
Comp 'en 404 combinaciones nunca salen los dos' ($dobles -eq 0) 'del 0 al 100 %, con y sin cargador, avisada o no'

# EL LISTON MANDA DE VERDAD: si se cambia la constante, cambia la decision. Esto es lo que
# NO pasaba con el 15 escrito a mano.
$BateriaAviso = 30
Comp 'si se sube el liston a 30, al 25 % ya avisa' ((Get-AvisoBateria 25 $false $false) -eq 'primero') 'con el 15 a pelo esto callaba'
$BateriaAviso = 5
Comp 'si se baja a 5, al 10 % se calla' ((Get-AvisoBateria 10 $false $false) -eq '') ''
# Y EL 0 DESACTIVA, como promete la linea de config
$BateriaAviso = 0
Comp 'con el liston a 0 no avisa nunca' ((Get-AvisoBateria 1 $false $false) -eq '') '0 = desactivado, como dice config.json'
# Y AL 0 % TAMBIEN (25/09, lo cazo una rotura). Quitar la guarda del "0 = desactivado" dejaba
# el banco verde entero, porque con el liston a 0 cualquier porcentaje de 1 en adelante ya se
# iba por el "-gt". El unico que la necesita es el 0 exacto, y no lo probaba nadie.
Comp '  ni siquiera con la bateria al 0 %' ((Get-AvisoBateria 0 $false $false) -eq '') 'el unico caso que esa guarda protege'
$BateriaAviso = if ($mB.Success) { [int]$mB.Groups[1].Value } else { 15 }

Write-Host ''
Write-Host '-- 4. EL REARME --'
Comp 'enchufar rearma' (Test-BateriaRearme 5 $true) 'aunque siga bajisima'
Comp 'subir 10 por encima del liston rearma' (Test-BateriaRearme ($BateriaAviso + 11) $false) ''
Comp 'justo en el liston + 10 todavia no' (-not (Test-BateriaRearme ($BateriaAviso + 10) $false)) 'hace falta pasarlo, no tocarlo'
Comp 'seguir bajo y sin cargador no rearma' (-not (Test-BateriaRearme ($BateriaAviso - 1) $false)) 'si no, avisaria en bucle'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  los dos avisos de bateria se reparten el trabajo'
exit 0
