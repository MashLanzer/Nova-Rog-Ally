# UNA TOMA SATURADA SE MANDABA AL AGENTE (24/09, idea 12 de la tanda nueva).
#
# LO MEDIDO, sobre los 886 dictados con texto del registro:
#
#     dictados CON un recorte en los 20 s previos (83)   fallan el 42,2 %  (35)
#     dictados sin recorte (803)                         fallan el 25,7 %  (206)
#
# 1,64 veces peor, z~3,3, p<0,001: no es casualidad. Pero tampoco condena, y eso importa: 30
# de esos 83 salieron BIEN, asi que el recorte no estropea la orden, la hace mas dificil.
#
# LO QUE SI ERA UN FALLO: 32 de los 35 acabaron en "LOCAL descarta: no reconozco -> la orden
# entera va a opencode". O sea que una toma que Nova YA SABIA mala se mandaba a un agente con
# manos a ver si adivinaba. Ahora, cuando ademas no se entiende, se pide repetir.
#
# LO QUE MAS SE VIGILA AQUI: que esto NO se dispare cuando la orden SI se entiende. El recorte
# solo se mira en el camino de "no reconozco"; si se mirara antes, Nova estaria pidiendo que le
# repitan ordenes que habia entendido perfectamente, y eso son 83 interrupciones en vez de 35.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }
Invoke-Expression (Traer 'Test-TomaSaturada')
# LA VENTANA SALE DEL ARCHIVO, NO DE AQUI (24/09). Escrita a mano, subirla a diez minutos en
# assistant.ps1 dejaba este banco verde: probaba con su propio 20 contra una funcion que ya
# usaba otro numero. Un banco que trae su copia de la constante no prueba la constante.
$mVent = [regex]::Match($fuente, '(?m)^\$RecorteVentanaSeg = (\d+)')
if (-not $mVent.Success) { Write-Host '  MAL  no encuentro $RecorteVentanaSeg'; exit 1 }
$ventana = [int]$mVent.Groups[1].Value
Comp 'la ventana es la de la medicion: 20 s' ($ventana -eq 20) "$ventana s"


Write-Host ''
Write-Host '-- 1. LA VENTANA DE 20 SEGUNDOS, que es la de la medicion --'
foreach ($seg in @(0, 1, 5, 10, 19, 20)) {
    Comp ("un recorte hace $seg s cuenta como saturada") (Test-TomaSaturada $seg $ventana) ''
}
foreach ($seg in @(21, 30, 60, 600)) {
    Comp ("y hace $seg s ya no") (-not (Test-TomaSaturada $seg $ventana)) ''
}

Write-Host ''
Write-Host '-- 2. y si no ha habido ninguno, no se inventa --'
# El oido manda -1 cuando no ha recortado en toda la sesion. Si eso contara como saturada,
# Nova pediria repetir TODO lo que no entiende, que son 521 veces en quince dias.
Comp 'sin ningun recorte (-1) no es saturada' (-not (Test-TomaSaturada -1 $ventana)) 'el oido manda -1'
Comp 'ni con cualquier otro negativo' (-not (Test-TomaSaturada -99 $ventana)) ''

Write-Host ''
Write-Host '-- 3. el oido lo deja escrito, y AL FINAL --'
# assistant.ps1 lee escucha-estado.txt por INDICE en cuatro sitios. Meter el campo en medio
# cambiaria el significado de todos ellos de golpe; es la misma decision del quinto (22/09) y
# del sexto (24/09).
$sinCom = (($oido -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'el estado tiene siete campos' ($sinCom -match '"%\.1f\|%s\|%\.3f\|%d\|%d\|%d\|%d"') ''
Comp 'y el del recorte es el ULTIMO' ($sinCom -match 'recientes, desde_recorte\)') ''
Comp 'y sale del ultimo recorte de verdad' ($sinCom -match 'desde_recorte = -1 if ultimo_recorte <= 0') ''
Comp 'que es el mismo que usa la guarda de la ganancia' ($sinCom -match 'ultimo_recorte = ahora') 'no hay dos relojes distintos'

Write-Host ''
Write-Host '-- 4. y el asistente lo lee con las mismas guardas de siempre --'
$gr = SinComentarios (Traer 'Get-SegDesdeRecorte')
Comp 'lee el indice 6' ($gr -match '\$st\[6\]') ''
Comp 'con un worker viejo devuelve -1' ($gr -match '\$st\.Count -lt 7') 'no adivina'
Comp 'y con el estado rancio, tambien' ($gr -match 'Test-EstadoFresco') 'seria el dato del worker anterior'
Comp 'y sin fichero, igual' ($gr -match 'Test-Path -LiteralPath \$RutaEstado') ''

Write-Host ''
Write-Host '-- 5. SOLO en el camino de "no reconozco" --'
# Esto es lo que decide si la idea vale o molesta. Si el recorte se mirara antes de intentar
# entender, Nova pediria repetir las 83 tomas con recorte en vez de las 35 que ademas no se
# entendieron. Mas del doble de interrupciones, y la mayoria sin motivo.
$bloque = (($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
$iDescarta = $bloque.IndexOf("LOCAL descarta: no reconozco '`$f', y la toma venia saturada")
$iNormal = $bloque.IndexOf("LOCAL descarta: no reconozco '`$f' -> la orden entera va a opencode")
Comp 'la guarda esta en el camino de "no reconozco"' ($iDescarta -ge 0) ''
Comp 'y va justo antes de escalar al agente' (($iDescarta -ge 0) -and ($iNormal -gt $iDescarta)) ''
Comp 'y solo hay UN sitio que lo mira' (([regex]::Matches($bloque, 'Test-TomaSaturada \$segRec')).Count -eq 1) 'dos sitios acabarian separandose'
# Y NO SE TOCA NADA DEL OIDO: ni la ganancia, ni el 0,6 con el que baja, ni el aviso del
# recorte con altavoces, que ademas esta comprobado que NO cuesta ordenes (de sus 262 casos
# solo 9 fueron seguidos de una orden, y 93 pasaron jugando).
Comp 'la ganancia sigue bajando igual' ($sinCom -match 'ganancia \* 0\.6') ''
Comp 'y el aviso del recorte con altavoces sigue' ($sinCom -match 'recorte con los altavoces sonando') 'ese no cuesta ordenes: 9 de 262'

Write-Host ''
Write-Host '-- 6. lo que contesta, y lo que NO hace --'
Comp 'pide que lo repita' ($fuente -match 'Me lo repites') ''
Comp 'y ofrece el boton, que es la segunda via' ($fuente -match 'toma venia saturada[\s\S]{0,400}boton') 'la regla 7: nunca una sola via'
Comp 'no ejecuta nada' ($bloque -notmatch 'Test-TomaSaturada[\s\S]{0,300}Submit-Command') 'la regla 1'
Comp 'y deja un contador para vigilarlo' ($bloque -match "Add-Estadistica 'toma-saturada'") ''
# Y BORRA EL ULTIMO DESCARTE: si se quedara puesto, esta frase contaria como "vocabulario que
# falta" y acabaria proponiendose para commands.json, que es justo lo contrario de la verdad.
Comp 'y no la cuenta como vocabulario que falta' ($bloque -match "toma venia saturada[\s\S]{0,300}ultimoDescarte = ''") 'no es que falte una palabra: es que se oyo mal'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  una toma saturada ya no se manda al agente a ver si adivina'
exit 0
