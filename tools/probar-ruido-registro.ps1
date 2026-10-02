# EL REGISTRO SE HABIA VUELTO RUIDO: TRES FUENTES, MEDIDAS HOY (2/10/2026)
#
# EL DATO QUE LO ABRE: el 2/10 Nova corrio el dia entero y braya no le dijo NI UNA palabra. El
# registro de ese dia: 706 lineas, de las que 569 (el 80,6 %) son avisos de vuelta lenta. Y de esas,
# 418 -el 59 % del dia- son esto:
#
#   SORDA 0.09 s en una vuelta (...): EXE DE JUEGO: 'windowsterminal' lleva rato delante y no se
#   cual es; Steam no lo aclara
#
# O sea: Nova tomaba la ventana de comandos por un juego desconocido, y cada vez FORZABA la relectura
# de la biblioteca de Steam -el trozo que mide 16 segundos en el arranque-, lo que explica que casi
# todas esas lineas lleven una vuelta sorda pegada.
#
# LAS TRES COSAS QUE SE ARREGLAN, y las tres con su numero:
#
#   A. 'windowsterminal' y compania no se preguntan nunca ($EXES_NO_JUEGO), y lo que ya se pregunto
#      tres veces sin aclararse tampoco. 418 lineas al dia, y la relectura de la biblioteca con
#      ellas.
#   B. 'EN BUCLE:' se queda fuera del $script:ultimoLog, como ya estaban SORDA y LENTA. El filtro se
#      escribio el 1/10 y decia "vale para cualquier otra linea del medidor que se anada manana",
#      y justo la que mas se repite no estaba: 94 lineas del 2/10 del tipo
#      "SORDA (...): EN BUCLE: llevo 10 veces lo mismo en 9 min: ...", una por minuto.
#   C. el aviso de consumo no repite el MISMO numero: el 2/10 hay ocho lineas identicas ("la capsula
#      va por 236 milesimas de nucleo y lo suyo son 230", un 2,6 % por encima), siete del oido y
#      cinco de tres cosas mas. El freno que habia era de TIEMPO; ahora, como los petes, vuelve a
#      hablar cuando EMPEORA.
#
# Y DOS QUE SE CAYERON AL MEDIRLAS, que es la mitad del valor de este fichero:
#
#   - "la vuelta sorda se anida sobre si misma": ARREGLADO EL 1/10 (commit aba78e0). Mis 456 lineas
#     eran de ANTES de ese arreglo, del mismo dia. Lo unico que quedaba vivo era el caso B.
#   - "ENTORNO aparcado, 4.219 lineas, la linea mas repetida del proyecto": ARREGLADO EL 24/09.
#     4.080 de esas 4.219 son del 24/09, el dia en que se arreglo. Despues: 25, 3, 46, 38, 2, 24 y 1
#     por dia. Era el error de la fecha del dato, otra vez, y esta vez cazado antes de escribir nada.
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
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`r?`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host ''
Write-Host '-- A. lo que nunca es un juego no se pregunta --'
# LA TABLA SE EJECUTA, no se lee: se saca del fichero y se mira dentro.
$iT = $txt.IndexOf('$EXES_NO_JUEGO = @{')
Comp 'existe la tabla' ($iT -gt 0) ''
if ($iT -gt 0) {
    $fin = $txt.IndexOf('}', $txt.IndexOf('systemsettings', $iT))
    Invoke-Expression $txt.Substring($iT, $fin - $iT + 1)
    foreach ($e in @('windowsterminal', 'explorer', 'powershell', 'cmd', 'taskmgr', 'steamwebhelper')) {
        Comp ("  '$e' esta dentro") ($EXES_NO_JUEGO.ContainsKey($e)) ''
    }
    # Y QUE NO SE PASE DE LISTA: un juego de verdad no puede estar aqui dentro.
    foreach ($j in @('eldenring', 'robloxplayerbeta', 'minecraft', 'hollow_knight')) {
        Comp ("  y '$j' NO esta") (-not $EXES_NO_JUEGO.ContainsKey($j)) ''
    }
}
# EL CABLEADO, por orden y no por distancia (ver probar-bancos-fragiles)
# LA RELECTURA QUE CUENTA ES LA DE ESTE BLOQUE, no la primera del fichero: esa misma linea sale
# tambien en el aviso de unidades, mas arriba, y buscarla desde el principio daba un rojo falso.
$iUso = $sinCom.IndexOf('$EXES_NO_JUEGO.ContainsKey($procE)')
$iRelee = $sinCom.IndexOf('$script:JuegosStamp = (Get-Date).AddMinutes(-5)', [Math]::Max(0, $iUso))
Comp 'se consulta ANTES de releer la biblioteca' ($iUso -ge 0 -and $iRelee -gt $iUso) "uso en $iUso, relectura en $iRelee"
# Y SIN 'return', QUE SE LLEVARIA POR DELANTE EL RESTO DE Watch-Entorno
$cuerpoW = Traer 'Watch-Entorno'
$iFuera = $cuerpoW.IndexOf('$fueraE = (')
$trozo = if ($iFuera -ge 0) { $cuerpoW.Substring($iFuera, [Math]::Min(700, $cuerpoW.Length - $iFuera)) } else { '' }
Comp '  y sin return, que cortaria Watch-Entorno entera' ($iFuera -ge 0 -and $trozo -notmatch '\breturn\b') 'el resto de la funcion son veinte bloques mas'

Write-Host ''
Write-Host '-- A2. y el que no se aclara, tres veces y basta --'
Comp 'hay un tope con nombre' ($sinCom -match '\$ExeSinAclararMax\s*=\s*\d') ''
Comp '  y se cuenta por exe' ($sinCom -match '\$script:exeSinAclarar\[\$procE\] = \[int\]\$script:exeSinAclarar\[\$procE\] \+ 1') ''
# SE BORRA AL ACERTAR: si no, un exe que un dia se aclara seguiria contando como fallido
$iSave = $sinCom.IndexOf('Save-ExeJuego $procE $cualE')
$iBorra = $sinCom.IndexOf('$script:exeSinAclarar.Remove($procE)', [Math]::Max(0, $iSave))
Comp '  y la cuenta se borra cuando SI se aclara' ($iSave -ge 0 -and $iBorra -gt $iSave) ''

Write-Host ''
Write-Host '-- B. EN BUCLE no se cita a si misma --'
# ESTO SE EJECUTA: se saca el embudo de Log y se le pasan lineas de verdad.
Comp "el filtro incluye 'EN BUCLE:'" ($sinCom -match "notmatch '\^\(\?:SORDA\|LENTA:\|EN BUCLE:\)") ''
$script:ultimoLog = ''
$bloque = {
    param($msg)
    if ($msg -and $msg -notmatch '^(?:SORDA|LENTA:|EN BUCLE:)') {
        $script:ultimoLog = if ($msg.Length -gt 80) { $msg.Substring(0, 80) } else { $msg }
    }
}
& $bloque 'DISCO: 31.4 GB libres'
Comp 'una linea normal si se recuerda' ($script:ultimoLog -match 'DISCO') "$script:ultimoLog"
& $bloque 'EN BUCLE: llevo 10 veces lo mismo en 9 min: DISCO: 31.4 GB libres'
Comp "  y 'EN BUCLE' NO la pisa" ($script:ultimoLog -match '^DISCO') "$script:ultimoLog"
& $bloque 'SORDA 0.08 s en una vuelta (lo normal en mi son 62 ms): DISCO'
Comp "  ni 'SORDA' (como ya estaba)" ($script:ultimoLog -match '^DISCO') "$script:ultimoLog"
& $bloque 'LENTA: algo'
Comp "  ni 'LENTA:'" ($script:ultimoLog -match '^DISCO') "$script:ultimoLog"
# Y QUE EL FILTRO NO SE PASE: 'EN BUCLEO' o 'SORDAMENTE' no empiezan por esas claves exactas... pero
# si por el prefijo. Lo que importa es que una linea CUALQUIERA siga entrando.
& $bloque 'CONSUMO: la capsula va por 136 megas'
Comp 'y cualquier otra linea sigue entrando' ($script:ultimoLog -match 'CONSUMO') "$script:ultimoLog"

Write-Host ''
Write-Host '-- C. el consumo no repite el mismo numero --'
$ConsumoAvisoMin = 60
$ConsumoNombres = @{ 'capsula' = 'la capsula'; 'oido' = 'el oido' }
$script:consumoAvisoEn = @{}
$script:consumoAvisoVal = @{}
$script:juegoActivo = ''
$script:dicho = @()
function Log([string]$m) { $script:dicho += $m }
$script:relojMs = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojMs }
Invoke-Expression (Traer 'Test-ConsumoSalido')

# El caso del 2/10: 236 contra un liston de 230, ocho veces.
$r1 = Test-ConsumoSalido 'cpu:capsula' 236 'capsula' 'milesimas de nucleo' 230
Comp 'la primera vez se dice' ($r1 -eq $true) "$r1"
$script:relojMs = 61 * 60000      # una hora larga despues: el freno de tiempo ya no frena
$r2 = Test-ConsumoSalido 'cpu:capsula' 236 'capsula' 'milesimas de nucleo' 230
Comp '  el MISMO numero, una hora despues, NO' ($r2 -eq $false) "$r2"
$script:relojMs = 122 * 60000
$r3 = Test-ConsumoSalido 'cpu:capsula' 234 'capsula' 'milesimas de nucleo' 230
Comp '  y uno MENOR, tampoco' ($r3 -eq $false) "$r3"
$r4 = Test-ConsumoSalido 'cpu:capsula' 260 'capsula' 'milesimas de nucleo' 230
Comp '  pero si EMPEORA, si' ($r4 -eq $true) "$r4"
Comp '  y en total se dijo dos veces, no cuatro' (@($script:dicho | Where-Object { $_ -match 'CONSUMO' }).Count -eq 2) "$($script:dicho.Count)"
# OTRA CLAVE ES OTRA NOTICIA: el freno es por cosa, no global.
$r5 = Test-ConsumoSalido 'cpu:oido' 44 'oido' 'milesimas de nucleo' 25
Comp 'otra cosa habla igual' ($r5 -eq $true) "$r5"
# Y POR DEBAJO DEL LISTON, NI UNA PALABRA (lo de siempre, que no se ha roto)
$r6 = Test-ConsumoSalido 'ram:cerebro' 100 'cerebro' 'megas' 310
Comp 'y por debajo del liston no se dice nada' ($r6 -eq $false) "$r6"
# EL FRENO DE TIEMPO SIGUE EN PIE: dos avisos seguidos de la misma cosa, aunque empeore
$script:consumoAvisoEn = @{}; $script:consumoAvisoVal = @{}; $script:relojMs = 0
[void](Test-ConsumoSalido 'cpu:capsula' 236 'capsula' 'milesimas' 230)
$script:relojMs = 5 * 60000
$r7 = Test-ConsumoSalido 'cpu:capsula' 400 'capsula' 'milesimas' 230
Comp 'y el freno de tiempo sigue frenando aunque empeore' ($r7 -eq $false) "a los 5 min: $r7"

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el registro deja de hablar de si mismo' -ForegroundColor Green
exit 0
