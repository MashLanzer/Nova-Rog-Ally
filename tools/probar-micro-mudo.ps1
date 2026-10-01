# TRES DICTADOS VACIOS SEGUIDOS SON UNA AVERIA, NO TRES CASUALIDADES (1/10, idea 8 de las 20)
#
# Un dictado vacio suelto es normal: braya pulsa el boton y no dice nada. Hay 10 en 609 ordenes, y
# YA estaba bien tratado -no cuenta como fallo de oido (Write-FalloDeducido lo excluye) ni entra en
# la cuenta de la meta-. Esa mitad de la idea ya estaba hecha.
#
# LO QUE FALTABA: tres SEGUIDOS son el micro tapado por la funda, el array desactivado en Windows u
# otro programa con el micro cogido en exclusiva. Y el sintoma desde fuera es el peor de todos:
# suena el tic, la capsula se abre, y Nova no contesta nada. Con un aviso suelto por vuelta eso
# parece mala suerte tres veces; dicho de golpe, es una averia que se puede arreglar.
#
# LO QUE DEFIENDE:
#  1. que hagan falta TRES, no uno ni dos;
#  2. que sean SEGUIDOS: en cuanto se oye algo, la cuenta vuelve a cero;
#  3. que se diga UNA vez y no en cada vacio a partir del tercero;
#  4. que el reinicio viva en la PRIMERA linea que sabe que hay texto, porque Process-Texto tiene
#     veinte salidas y en cualquiera de ellas la cuenta se quedaria colgada;
#  5. y que el liston se pueda mover desde config.json.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# EL BLOQUE SE EJECUTA, no se lee: se saca tal cual del fichero y se corre con dobles. Leer su
# forma no diria si hacen falta tres ni si la cuenta se reinicia, que es todo lo que importa.
$DictadoVaciosAvisa = 3
$script:dictaVacios = 0
$script:avisos = @()
$script:uiMia = $false
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    $script:avisos += @{ clave = $clave; texto = $texto; cadaMin = $cadaMin }
    return $true
}
# el trozo de verdad, copiado del fichero (si cambia alli y no aqui, la seccion 5 lo caza)
$unVacio = {
    $script:dictaVacios++
    if ($script:dictaVacios -ge $DictadoVaciosAvisa) {
        $script:dictaVacios = 0
        $script:uiMia = $true
        [void](Send-AvisoEntorno 'micro-mudo' ("Te he abierto el microfono $DictadoVaciosAvisa veces seguidas y no he oido nada. Mira si esta tapado o si otro programa lo tiene cogido.") 'medio' 30)
    }
}
$seOyoAlgo = { $script:dictaVacios = 0 }

Write-Host ''
Write-Host '-- 1. hacen falta TRES, no uno ni dos --'
& $unVacio
Comp 'con uno no dice nada' ($script:avisos.Count -eq 0) "$($script:avisos.Count)"
& $unVacio
Comp 'con dos tampoco' ($script:avisos.Count -eq 0) "$($script:avisos.Count)"
& $unVacio
Comp 'con TRES avisa' ($script:avisos.Count -eq 1) "$($script:avisos.Count)"
Comp '  y dice que mire si esta tapado' ($script:avisos[0].texto -match 'tapado') "$($script:avisos[0].texto)"
Comp '  y que otro programa lo pueda tener' ($script:avisos[0].texto -match 'otro programa') ''
Comp '  con el numero dentro, no "varias veces"' ($script:avisos[0].texto -match '3 veces seguidas') ''
Comp '  y marcado como suyo (nadie lo pregunto)' ($script:uiMia) 'idea 54'

Write-Host ''
Write-Host '-- 2. SEGUIDOS: si se oye algo, la cuenta vuelve a cero --'
# Tres vacios repartidos en toda la tarde NO son una averia. Si esto fallara, Nova acusaria al
# microfono de estar roto por tres pulsaciones sueltas en seis horas, que es peor que callarse.
$script:avisos = @(); $script:dictaVacios = 0
& $unVacio; & $unVacio
& $seOyoAlgo
& $unVacio; & $unVacio
Comp 'dos, una orden buena, y otros dos: no avisa' ($script:avisos.Count -eq 0) "$($script:avisos.Count)"
& $unVacio
Comp '  pero el tercero SEGUIDO si' ($script:avisos.Count -eq 1) ''

Write-Host ''
Write-Host '-- 3. se dice UNA vez, no en cada vacio a partir del tercero --'
# Si no, un micro tapado media hora soltaria el mismo aviso treinta veces.
$script:avisos = @(); $script:dictaVacios = 0
foreach ($i in 1..9) { & $unVacio }
Comp 'nueve vacios seguidos dan TRES avisos, no nueve' ($script:avisos.Count -eq 3) "$($script:avisos.Count)"
# y el freno de verdad lo pone el filtro de avisos: la misma clave con su cadaMin
Comp '  y los tres llevan la MISMA clave, para que el filtro los frene' (@($script:avisos | Where-Object { $_.clave -eq 'micro-mudo' }).Count -eq 3) ''
Comp '  con plazo corto, que esto es de ahora' ($script:avisos[0].cadaMin -le 60) "$($script:avisos[0].cadaMin) min"

Write-Host ''
Write-Host '-- 4. y lo que ya estaba: un vacio no es un fallo de oido --'
# Esta mitad de la idea YA estaba hecha en tres sitios, y no se puede perder: si un vacio contara
# como fallo, el porcentaje de la meta -lo que mas le importa a braya- bajaria por pulsar el boton.
Comp 'Write-FalloDeducido excluye el dictado vacio' ($sinCom -match "senal -eq 'error' -and \`$dF -eq 'dictado vacio'") ''
Comp '  y la cuenta de la meta tambien' (@([regex]::Matches($sinCom, "-eq 'dictado vacio' -and -not")).Count -ge 2) 'en dos sitios'

Write-Host ''
Write-Host '-- 5. el cableado --'
# POR ORDEN Y NO POR DISTANCIA (ver probar-bancos-fragiles).
$iVacio = $sinCom.IndexOf("Add-Estadistica 'error' 'dictado vacio'")
$iMudo = $sinCom.IndexOf('micro-mudo', [Math]::Max(0, $iVacio))
Comp 'el aviso sale donde se apunta el vacio' ($iVacio -ge 0 -and $iMudo -gt $iVacio) 'no se estrena ningun reloj'
Comp '  y la cuenta sube ahi mismo' ($sinCom -match '\$script:dictaVacios\+\+') ''
# EL REINICIO VA EN LA PRIMERA LINEA QUE SABE QUE HAY TEXTO: Process-Texto tiene veinte salidas, y
# al final de la funcion la cuenta se quedaria colgada en cualquiera de ellas.
$cuerpoP = ''
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
$dP = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Process-Texto' }, $true) | Select-Object -First 1
if ($dP) { $cuerpoP = $dP.Extent.Text }
$pSin = (($cuerpoP -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$iTexto = $pSin.IndexOf('if ($text.Length -gt 0) {')
$iCero = $pSin.IndexOf('$script:dictaVacios = 0')
Comp 'Process-Texto pone la cuenta a cero' ($iCero -ge 0) ''
Comp '  dentro del "if hay texto"' ($iTexto -ge 0 -and $iCero -gt $iTexto) "el if en $iTexto, el cero en $iCero"
Comp '  y pegado a el, no veinte salidas despues' ($iTexto -ge 0 -and $iCero -ge 0 -and ($iCero - $iTexto) -lt 400) "$($iCero - $iTexto) caracteres de distancia"
Comp 'el liston sale de config.json' ($txt -match "Get-Cfg 'escucha' 'vaciosAvisa'") ''
# Y EL TROZO QUE ESTE BANCO EJECUTA ES EL DEL FICHERO: si alli cambia y aqui no, esto lo caza.
Comp 'el bloque del banco sigue siendo el del fichero' ($sinCom -match 'dictaVacios -ge \$DictadoVaciosAvisa') ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'tres veces sin oir nada se dicen, en vez de parecer mala suerte' -ForegroundColor Green
exit 0
