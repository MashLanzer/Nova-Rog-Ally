# LOS 158 AVISOS CADUCADOS ERAN ANONIMOS (1/10, idea 10 de las 20 nuevas)
#
# Add-Estadistica usa el PRIMER argumento como nombre del contador y el segundo va a $s.recientes,
# que tiene 40 plazas y se vacia sola. La linea de los caducados pasaba la clave como SEGUNDO
# argumento, asi que de los 158 apuntados se sabia cuantos pero no CUALES.
#
# Y saber cuales es lo que importa: un aviso cuyo plazo vence antes de que braya vuelva esta mal
# CALIBRADO, no mal dicho. 'gmail-lleno' tiene plazo propio de UNA SEMANA y se aparco 1.652 veces en
# el registro: su noticia sigue siendo verdad al dia siguiente, asi que caducarla a las dos horas es
# tirarla por nada.
#
# LO QUE DEFIENDE:
#  1. que el contador de siempre siga ahi (tres bancos buscan ese literal) Y que ademas haya
#     desglose por clave, con el mismo formato que 'aviso-nada:' y 'aviso-sirvio:';
#  2. que el plazo se alargue solo para la clave que caduca TRES veces o mas, no una;
#  3. que tenga tope, porque un plazo infinito es lo mismo que no tener plazo: volveria a soltar
#     noticias rancias, que es justo lo que los 120 minutos vienen a evitar;
#  4. y que ante la duda -sin estadisticas legibles- se use el plazo de siempre.
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
# los mismos valores que el fichero
$AvisoEsperaCaducaMin = 120
$AvisoCaducaAlargaDesde = 3
$AvisoCaducaMaxMin = 1440
Invoke-Expression (Traer 'Get-CaducaAviso')
# LAS ESTADISTICAS, DOBLADAS: asi los numeros los decide el banco y no el fichero de braya.
$script:statsPega = @{ dias = @{} }
function Get-Estadisticas { return $script:statsPega }

Write-Host ''
Write-Host '-- 1. sin historial, el plazo de siempre --'
Comp 'una clave nueva usa los 120 de siempre' ((Get-CaducaAviso 'nunca-vista') -eq 120) "$(Get-CaducaAviso 'nunca-vista') min"
Comp 'y una clave vacia tambien' ((Get-CaducaAviso '') -eq 120) "$(Get-CaducaAviso '') min"
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'aviso-caducado:gmail-lleno' = 2 } } }
Comp 'con DOS caducados todavia no se alarga' ((Get-CaducaAviso 'gmail-lleno') -eq 120) "$(Get-CaducaAviso 'gmail-lleno') min"

Write-Host ''
Write-Host '-- 2. con tres o mas, se alarga --'
# Una vez puede ser que braya no volviera ese dia. Tres es el patron.
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'aviso-caducado:gmail-lleno' = 3 } } }
Comp 'con TRES se dobla' ((Get-CaducaAviso 'gmail-lleno') -eq 240) "$(Get-CaducaAviso 'gmail-lleno') min"
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'aviso-caducado:gmail-lleno' = 6 } } }
Comp 'con SEIS se cuadruplica' ((Get-CaducaAviso 'gmail-lleno') -eq 480) "$(Get-CaducaAviso 'gmail-lleno') min"
# y suma los dias, que es donde vive la cuenta de verdad
$script:statsPega = @{ dias = @{
    '2026-09-29' = @{ 'aviso-caducado:disco-poco' = 1 }
    '2026-09-30' = @{ 'aviso-caducado:disco-poco' = 1 }
    '2026-10-01' = @{ 'aviso-caducado:disco-poco' = 1; 'aviso-caducado:otra' = 9 }
} }
Comp 'suma la clave de TODOS los dias' ((Get-CaducaAviso 'disco-poco') -eq 240) "$(Get-CaducaAviso 'disco-poco') min, de 1+1+1"
Comp '  y no mezcla una clave con otra' ((Get-CaducaAviso 'otra') -eq 480) "$(Get-CaducaAviso 'otra') min, de 9"

Write-Host ''
Write-Host '-- 3. CON TOPE: un plazo infinito es no tener plazo --'
# Sin tope, un aviso que caduco cien veces aguantaria aparcado semanas y volveria a soltar noticias
# rancias, que es exactamente lo que los 120 minutos vienen a evitar.
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'aviso-caducado:x' = 10000 } } }
Comp 'con diez mil caducados no pasa del tope' ((Get-CaducaAviso 'x') -le $AvisoCaducaMaxMin) "$(Get-CaducaAviso 'x') min de $AvisoCaducaMaxMin"
Comp '  y el tope es un dia, no una semana' ($AvisoCaducaMaxMin -eq 1440) "$AvisoCaducaMaxMin min"

Write-Host ''
Write-Host '-- 4. ante la duda, el plazo de siempre --'
# Alargar un plazo a ciegas es la forma de acabar diciendo la bateria de hace tres horas.
function Get-Estadisticas { throw 'estadisticas ilegibles' }
Comp 'con las estadisticas rotas, los 120 de siempre' ((Get-CaducaAviso 'gmail-lleno') -eq 120) "$(Get-CaducaAviso 'gmail-lleno') min"
function Get-Estadisticas { return $null }
Comp 'y con estadisticas vacias, tambien' ((Get-CaducaAviso 'gmail-lleno') -eq 120) "$(Get-CaducaAviso 'gmail-lleno') min"

Write-Host ''
Write-Host '-- 5. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# EL CONTADOR DE SIEMPRE NO SE TOCA: tres bancos buscan ese literal, y el total sigue valiendo.
Comp "el contador 'aviso-caducado' de siempre sigue" ($sinCom -match "Add-Estadistica 'aviso-caducado' ") 'tres bancos lo buscan'
Comp '  y ademas se apunta con la clave dentro' ($sinCom -match "Add-Estadistica \('aviso-caducado:' \+ ") ''
Comp '  con el mismo formato que aviso-nada' ($sinCom -match "aviso-nada:" -and $sinCom -match "aviso-caducado:") 'se lee con el mismo codigo'
# Y LOS DOS JUNTOS: si el desglose se pusiera en otro sitio, podrian separarse
$iTot = $sinCom.IndexOf("Add-Estadistica 'aviso-caducado' ")
$iDes = $sinCom.IndexOf("Add-Estadistica ('aviso-caducado:' + ")
Comp '  y van pegados, para que no se separen' ($iTot -ge 0 -and $iDes -gt $iTot -and ($iDes - $iTot) -lt 300) "$($iDes - $iTot) caracteres"
# EL PLAZO SALE DE LA FUNCION, no del numero a pelo
$cuerpoA = Traer 'Add-AvisoEspera'
Comp 'Add-AvisoEspera pide el plazo a la funcion' ($cuerpoA -match 'Get-CaducaAviso \$clave') ''
Comp '  y ya no usa la constante a pelo' ($cuerpoA -notmatch 'AddMinutes\(\$AvisoEsperaCaducaMin\)') ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el aviso que siempre caduca aguanta mas, y se sabe cual es' -ForegroundColor Green
exit 0
