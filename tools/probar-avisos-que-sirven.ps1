# QUE NOVA MIDA SI SUS AVISOS SIRVEN (25/09, idea 24 de las cincuenta)
#
# LO MEDIDO sobre los 81 avisos que Nova ha dicho de verdad en quince dias, mirando si braya le
# hablo en los cinco minutos siguientes:
#
#   ruido en el micro     32 avisos (40 % del total)  ->  reacciono 2 veces   (6 %)
#   bateria llena         20 avisos (25 %)            ->  reacciono 3 veces   (15 %)
#   hora de dormir         7                          ->  reacciono 3 veces   (43 %)
#   poco disco             6                          ->  reacciono 2 veces   (33 %)
#   el correo de la manana 3                          ->  reacciono 2 veces   (67 %)
#   se cerro el juego      3                          ->  reacciono 2 veces   (67 %)
#
# O sea que Nova gasta el 64 % de su voz en los DOS avisos que menos mueven a braya, y los que
# si le interesan los dice tres veces cada uno. Eso es lo que hay detras de la proporcion del
# 24/09: hablo 21 veces por su cuenta por UNA que la llamaron.
#
# LA SALVEDAD, y va escrita aqui porque importa: "hablarle despues" no mide todo. Si Nova dice
# que hay ruido y braya se levanta y apaga un ventilador sin decirle nada, eso cuenta como "no
# reacciono". Por eso lo que se hace NO es callar un aviso, sino ESPACIARLO: si algo no mueve a
# braya, se dice menos veces, nunca cero. Un aviso que no sirve y se dice cada media hora es
# ruido; el mismo cada seis horas sigue estando ahi el dia que si importe.
#
# Y POR ESO HACE FALTA UN MINIMO DE MUESTRAS: con tres avisos no se sabe nada. El liston son 8,
# que es donde el aviso mas repetido (32) ya tiene cuatro tandas y los raros no se tocan.
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

Write-Host '-- 1. existe, se apunta y se usa --'
Comp 'existe Get-EsperaAviso' ($sinCom -match 'function Get-EsperaAviso') ''
# QUE SE ESCRIBAN, NO SOLO QUE APAREZCAN (25/09, lo cazaron dos roturas): "aviso-sirvio:"
# tambien sale en Get-ReaccionesAviso, que es quien LEE el contador. Buscar la cadena a secas
# daba verde aunque se borrara el sitio donde se APUNTA, que es justo lo que importa.
Comp 'y se apunta cuando el aviso SI movio algo' ($sinCom -match 'Add-Estadistica \("aviso-sirvio:') 'braya hablo dentro de la ventana'
Comp 'y cuando no movio nada' ($sinCom -match 'Add-Estadistica \("aviso-nada:') 'la ventana vencio en silencio'
Comp 'la ventana mide lo mismo que la medicion que lo justifica' ($sinCom -match '\$AvisoReaccionVentanaMs = 300000') '5 min, como la tabla del registro'
# LA LLAMADA, NO LA DEFINICION (25/09, lo cazo una rotura): "Get-EsperaAviso" a secas encuentra
# la propia "function Get-EsperaAviso", asi que borrar su uso dejaba el banco verde con la
# funcion muerta dentro del archivo.
$usos = @([regex]::Matches($sinCom, '(?<!function )Get-EsperaAviso')).Count
Comp 'Test-PuedoAvisar usa la espera aprendida' ($usos -ge 1) "$usos uso(s) ademas de la definicion"
# Y LA GUARDA DE LO CRITICO, EN SU SITIO (lo cazo otra rotura): "nivel -eq 'alto'" aparece en
# varios puntos del archivo por otras razones, asi que se mira el bloque que decide la espera.
$iE = $sinCom.IndexOf('$espera = ')
$blE = if ($iE -gt 0) { $sinCom.Substring($iE, [Math]::Min(260, $sinCom.Length - $iE)) } else { '' }
Comp 'y lo critico no se espacia nunca' ($blE -match "nivel -eq 'alto'" -and $blE -match 'Get-EsperaAviso') 'un aviso urgente no se aprende a callar'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-EsperaAviso' }, $true)
if (-not $d) {
    Comp 'se saca Get-EsperaAviso del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
# y sus constantes, del archivo (manera 6: nunca una copia propia)
foreach ($cte in @('AvisoReaccionMin', 'AvisoEsperaTope')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim()) }
}
function Log([string]$m) { }

# el doble de la fuente de datos, DESPUES de cargar (manera 9)
$script:reacciones = @{}
function Get-ReaccionesAviso([string]$clave) {
    if ($script:reacciones.ContainsKey($clave)) { return $script:reacciones[$clave] }
    return @()
}

Comp 'sin datos, la espera no cambia' ((Get-EsperaAviso 'lo-que-sea' 60) -eq 60) 'con tres avisos no se sabe nada'

# POCAS MUESTRAS: aunque no sirva ninguna, todavia no se toca
$script:reacciones['pocas'] = @($false) * 4
Comp 'con 4 muestras tampoco' ((Get-EsperaAviso 'pocas' 60) -eq 60) "minimo $AvisoReaccionMin"

# EL CASO REAL DE oido-ruido: 32 avisos, 2 reacciones (6 %)
$script:reacciones['ruido'] = @(@($true) * 2 + @($false) * 30)
$e = Get-EsperaAviso 'ruido' 60
Comp 'un aviso que casi nunca mueve nada se espacia' ($e -gt 60) "$e min en vez de 60"
Comp '  pero no se calla del todo' ($e -le ($AvisoEsperaTope * 60) -and $e -lt 100000) "tope $AvisoEsperaTope h"

# EL CASO DE correo-manana: 3 de 3 (100 %) -> pocas muestras, no se toca
$script:reacciones['correo'] = @($true) * 3
Comp 'uno que si sirve, con pocas muestras, no se toca' ((Get-EsperaAviso 'correo' 60) -eq 60) ''

# UNO QUE SIRVE Y TIENE MUESTRAS: no se espacia
$script:reacciones['util'] = @(@($true) * 7 + @($false) * 3)
Comp 'uno que sirve no se espacia' ((Get-EsperaAviso 'util' 60) -eq 60) '70 % de reaccion'

# Y SI EMPIEZA A SERVIR, VUELVE: lo aprendido no es una condena
$script:reacciones['ruido'] = @(@($true) * 9 + @($false) * 3)
Comp 'y si vuelve a servir, recupera su ritmo' ((Get-EsperaAviso 'ruido' 60) -eq 60) 'lo aprendido se puede desaprender'

# EL TOPE, CON UNA BASE QUE LO ALCANCE (25/09, lo cazo una rotura). Con base 60 el peor caso
# da 60 x 4 = 240, que ya cabe en el tope de 360: quitar el tope no cambiaba nada y la rotura
# salia verde. Con una base de 180 el peor caso son 720 y el tope tiene que morder.
$script:reacciones['nunca'] = @($false) * 100
$e = Get-EsperaAviso 'nunca' 180
Comp 'el tope muerde de verdad' ($e -le ($AvisoEsperaTope * 60)) "$e min con base 180, tope $($AvisoEsperaTope * 60)"
Comp '  y sin el se iria a 720' (($AvisoEsperaTope * 60) -lt 720) 'por eso hace falta'
$e2 = Get-EsperaAviso 'nunca' 60
Comp 'y con una base normal, cuatro veces mas' ($e2 -eq 240) "$e2 min en vez de 60"

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova aprende que avisos te mueven'
exit 0
