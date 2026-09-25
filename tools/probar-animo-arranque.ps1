# EL ANIMO CON EL QUE SE DESPIERTA (25/09, idea 15)
#
# LO MEDIDO: el animo de Nova -un numero de -1 a 1 sacado de sus aciertos y errores de hoy y
# ayer- se calculaba DENTRO de Add-Estadistica, o sea solo cuando ya habia pasado algo. En
# 27.000 lineas solo aparecia en dos sitios: ese calculo y el "$script:uiAnimo = 0" de la
# inicializacion. Asi que al arrancar valia 0, neutro, viniera de donde viniera.
#
# POR QUE NO ES UN ADORNO: desde la idea 50 el animo decide CUANTO habla Nova por su cuenta
# (Get-SueloPorAnimo baja el suelo de avisos a la mitad si el dia va mal). Y el arranque es
# justo su momento de mas iniciativa: ahi salen los avisos del entorno que se quedaron
# esperando, la caida anterior, lo que no dijo a tiempo. Soltaba su tanda mas grande del dia
# creyendo que venia de un dia neutro. El peor sitio posible para no saberlo.
#
# Y NO HUBO QUE GUARDAR NADA NUEVO: memoria\estadisticas.json lleva los aciertos y errores por
# dia desde el 11/09 -14 dias- y Get-Estadisticas ya los carga enteros al arrancar. Solo
# faltaba hacer la cuenta. Por eso el calculo SALE de Add-Estadistica a su propia funcion: la
# misma cuenta en los dos sitios, en vez de dos copias que se separan con el tiempo.
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

Write-Host '-- 1. la cuenta esta en UN sitio, y se hace al arrancar --'
Comp 'existe Get-AnimoDeDias' ($sinCom -match 'function Get-AnimoDeDias') ''
$usos = @([regex]::Matches($sinCom, '(?<!function )Get-AnimoDeDias')).Count
Comp 'se usa en DOS sitios' ($usos -ge 2) "$usos uso(s): el de siempre y el del arranque"
# LA DUPLICACION, PROHIBIDA: la formula solo puede estar dentro de la funcion. Si vuelve a
# aparecer suelta por ahi, es que alguien hizo su propia copia (manera 4 de salir verde).
$formula = @([regex]::Matches($sinCom, '\$ok\s*-\s*2\.0\s*\*\s*\$mal')).Count
Comp 'la formula aparece una sola vez' ($formula -eq 1) "$formula vez(ces); dos = hay una copia suelta"
# Y QUE SE DEFINA ANTES DE USARSE: en PowerShell una funcion no existe hasta que el script
# pasa por su linea, y Add-Estadistica esta en la 2969. Si Get-AnimoDeDias quedara detras, el
# catch de alrededor se tragaria el error y el animo se quedaria en 0 sin decir nada.
$lDef = ($txt -split "`n" | Select-String -Pattern '^function Get-AnimoDeDias' | Select-Object -First 1).LineNumber
$lUso = ($txt -split "`n" | Select-String -Pattern '^function Add-Estadistica' | Select-Object -First 1).LineNumber
Comp 'y se define ANTES de quien la llama' ($lDef -lt $lUso) "definida en la $lDef, usada desde la $lUso"

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-AnimoDeDias' }, $true)
if (-not $d) { Comp 'se saca Get-AnimoDeDias del arbol' $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
Invoke-Expression $d.Extent.Text
$hoy = [datetime]'2026-09-25'
$ayer = '2026-09-24'; $hoyS = '2026-09-25'

# SIN DATOS, NEUTRO. Y sin reventar.
# EL DOBLE DEL LOG, para poder distinguir el 0 bueno del 0 de un error (25/09). Lo enseno una
# rotura: quitar la guarda del $null dejaba este banco VERDE, porque el catch de la funcion
# devolvia 0.0 y 0.0 es tambien la respuesta correcta de un dia neutro. Es la manera 8 de la
# lista de la casa -se traga el error y lo cuenta como respuesta- y estaba en nuestro codigo.
# Se arreglo alli: el catch ahora deja linea. Aqui se cuenta si la dejo.
$script:quejas = 0
function Log([string]$m) { if ($m -match 'animo: no pude calcularlo') { $script:quejas++ } }

$script:quejas = 0
Comp 'sin datos sale 0' ((Get-AnimoDeDias @{} $hoy) -eq 0.0) 'neutro, que es lo honesto'
Comp '  y ese 0 es de verdad, no un error tragado' ($script:quejas -eq 0) 'un dia sin datos NO es una averia'
$script:quejas = 0
Comp 'con $null tampoco revienta' ((Get-AnimoDeDias $null $hoy) -eq 0.0) ''
Comp '  y sale por la guarda, no por el catch' ($script:quejas -eq 0) 'si saltara el catch, el log lo diria'

# UN DIA BUENO
$buenos = @{ $hoyS = @{ local = 20; traducida = 5 } }
$aB = Get-AnimoDeDias $buenos $hoy
Comp 'un dia de aciertos da animo positivo' ($aB -gt 0) ([string]$aB)

# UN DIA MALO
$malos = @{ $hoyS = @{ local = 2; error = 8 } }
$aM = Get-AnimoDeDias $malos $hoy
Comp 'un dia de errores da animo negativo' ($aM -lt 0) ([string]$aM)

# AYER CUENTA: es la mitad de la ventana, y es justo lo que se perdia al reiniciar
$soloAyer = @{ $ayer = @{ local = 1; error = 9 } }
$aA = Get-AnimoDeDias $soloAyer $hoy
Comp 'un dia malo de AYER se nota hoy' ($aA -lt 0) "$aA; esto es lo que se perdia al reiniciar"

# Y ANTEAYER NO: la ventana son dos dias, ni uno mas
$anteayer = @{ '2026-09-23' = @{ error = 50 } }
Comp 'anteayer ya no cuenta' ((Get-AnimoDeDias $anteayer $hoy) -eq 0.0) 'la ventana son dos dias'

# LOS TOPES
$exagerado = @{ $hoyS = @{ error = 500 } }
Comp 'nunca baja de -1' ((Get-AnimoDeDias $exagerado $hoy) -ge -1.0) ([string](Get-AnimoDeDias $exagerado $hoy))
$exagerado2 = @{ $hoyS = @{ local = 5000 } }
Comp 'nunca sube de 1' ((Get-AnimoDeDias $exagerado2 $hoy) -le 1.0) ([string](Get-AnimoDeDias $exagerado2 $hoy))

# EL DIVISOR MINIMO DE 10: un solo error del primer minuto no puede hundir el animo
$unError = @{ $hoyS = @{ error = 1 } }
$a1 = Get-AnimoDeDias $unError $hoy
Comp 'un solo error no hunde el animo' ($a1 -gt -0.3) "$a1; con el divisor a 10 sale -0,2 y no -2"

Write-Host ''
Write-Host '-- 3. Y CAMBIA LO QUE HACE, no solo lo que se ve --'
# el liston malo, del archivo (manera 6)
$mA = [regex]::Match($txt, '(?m)^\$AnimoMalo\s*=\s*(.+)$')
Comp 'se saca del archivo AnimoMalo' $mA.Success ''
if ($mA.Success) { Invoke-Expression ('$AnimoMalo = ' + $mA.Groups[1].Value.Trim()) }
$dS = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-SueloPorAnimo' }, $true)
if ($dS) {
    Invoke-Expression $dS.Extent.Text
    $mA2 = [regex]::Match($txt, '(?m)^\$AnimoBueno\s*=\s*(.+)$')
    if ($mA2.Success) { Invoke-Expression ('$AnimoBueno = ' + $mA2.Groups[1].Value.Trim()) }
    # EL ENLACE ENTERO: de las estadisticas de un dia malo al suelo de avisos, sin tocar nada
    # a mano. Esto es lo que demuestra que el arreglo sirve para algo.
    $script:uiAnimo = Get-AnimoDeDias $malos $hoy
    $sueloMalo = Get-SueloPorAnimo 4
    $script:uiAnimo = Get-AnimoDeDias $buenos $hoy
    $sueloBueno = Get-SueloPorAnimo 4
    Comp 'con un dia malo habla MENOS por su cuenta' ($sueloMalo -lt 4) "suelo $sueloMalo en vez de 4"
    Comp 'con un dia bueno se permite algo mas' ($sueloBueno -gt 4) "suelo $sueloBueno en vez de 4"
} else {
    Comp 'se encuentra Get-SueloPorAnimo' $false 'sin ella el animo vuelve a ser un adorno'
}

Write-Host ''
Write-Host '-- 4. y el arranque lo pregunta de verdad --'
Comp 'el arranque calcula el animo' ($sinCom -match '\$script:uiAnimo\s*=\s*Get-AnimoDeDias\s*\(Get-Estadisticas\)') 'leyendo las estadisticas que ya estan en disco'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova se despierta sabiendo de que dia viene'
exit 0
