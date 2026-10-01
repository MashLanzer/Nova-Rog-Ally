# QUE NOVA LEA SU PROPIO CONTADOR DE ERRORES TRAGADOS (1/10, idea 1 de las 20 nuevas)
#
# Nova lleva desde el 27/09 contando los errores que se comen los 'catch {}' vacios, CON SU NUMERO
# DE LINEA, y el mecanismo funcionaba. El 1/10, mirando otra cosa, aparecio en estadisticas.json:
#     pete:979  -> 987 veces      pete:1002 -> 100 veces
# y las dos eran EL MISMO FALLO (el File::Replace de Write-Atomico, que cambio de linea entre dos
# commits). MIL OCHENTA Y SIETE errores tragados, apuntados cuatro dias, leidos por nadie. Y el
# fallo era gordo: la escritura "atomica" no era atomica.
#
# LO QUE DEFIENDE ESTA SECCION:
#  1. que la cuenta sea del ACUMULADO DE DIAS y no de la sesion: lo que hace noticia a un pete es
#     que lleve 987 veces, no que haya salido tres veces hoy;
#  2. que la frase diga EL NUMERO DE LINEA, que es lo unico que convierte la queja en algo
#     arreglable -"tengo un error" no sirve para nada-;
#  3. que no se repita la misma noticia cada minuto, pero que SI vuelva si el fallo empeora;
#  4. que un pete nuevo en OTRA linea pueda hablar aunque el viejo ya se dijera;
#  5. y que con poca cosa se calle: veinte veces puede ser un fichero que aun no existe al arrancar.
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
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
$PeteAvisaDesde = 200
foreach ($n in @('Get-PeorPeteHistorico', 'Get-FrasePetes', 'Get-PeorPete')) { Invoke-Expression (Traer $n) }

# LAS ESTADISTICAS, DOBLADAS: asi el banco decide los numeros y no los decide el fichero de braya,
# que cambia cada dia (seria la manera 7: el color lo pone el entorno).
$script:statsPega = @{ dias = @{} }
function Get-Estadisticas { return $script:statsPega }
$script:petePeor = $null
$script:peteTabla = @{}

Write-Host ''
Write-Host '-- 1. la cuenta es del ACUMULADO DE DIAS, no de la sesion --'
# EL CASO DE VERDAD, con los numeros que de verdad habia: la misma linea en dos dias.
$script:statsPega = @{ dias = @{
    '2026-09-27' = @{ 'pete:979' = 400; 'charla' = 12 }
    '2026-09-28' = @{ 'pete:979' = 587; 'pete:1002' = 40 }
    '2026-09-29' = @{ 'pete:1002' = 60 }
} }
$h = Get-PeorPeteHistorico
Comp 'suma la misma linea de todos los dias' ($h -and [int]$h.veces -eq 987) "$(if($h){$h.veces})"
Comp '  y dice de que linea es' ($h -and [string]$h.linea -eq '979') "$(if($h){$h.linea})"
Comp '  y en cuantos dias viene pasando' ($h -and [int]$h.dias -eq 2) "$(if($h){$h.dias})"
# Y NO SE CUELA LO QUE NO ES UN PETE: 'charla' vale 12 y no debe ganarle a nada
Comp '  y no confunde otro contador con un pete' ($h -and [string]$h.linea -ne 'charla') ''

Write-Host ''
Write-Host '-- 2. la frase lleva EL NUMERO DE LINEA --'
# Sin el numero seria "tengo un error", que no se puede arreglar. braya lee el codigo conmigo.
$fr = Get-FrasePetes
Comp 'dice cuantas veces' ($fr -match '987') "$fr"
Comp '  y en que linea' ($fr -match 'linea 979') ''
Comp '  y en cuantos dias' ($fr -match '2 dias') ''

Write-Host ''
Write-Host '-- 3. y si ademas esta pasando AHORA, lo distingue --'
# Un fallo viejo y uno vivo no son la misma noticia.
$script:petePeor = @{ linea = 979; veces = 7; que = 'La ruta de acceso no tiene un formato valido.' }
$fr2 = Get-FrasePetes
Comp 'dice que en esta sesion va por 7' ($fr2 -match 'en esta sesion va por 7') "$fr2"
Comp '  y repite el mensaje del error' ($fr2 -match 'no tiene un formato valido') ''
# UNA SOLA VEZ EN LA SESION NO ES NOTICIA (lo dice Get-PeorPete, que ya existia)
$script:petePeor = @{ linea = 979; veces = 1; que = 'algo' }
Comp 'una sola vez en la sesion no se menciona' ((Get-FrasePetes) -notmatch 'en esta sesion') ''
$script:petePeor = $null

Write-Host ''
Write-Host '-- 4. con poca cosa se calla --'
# Veinte veces puede ser un fichero que todavia no existe en el arranque.
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'pete:500' = 9 } } }
Comp 'con nueve veces no se queja' ((Get-FrasePetes) -match 'voy bien') "$(Get-FrasePetes)"
$script:statsPega = @{ dias = @{} }
Comp 'y sin ningun pete, lo dice sin inventar' ((Get-FrasePetes) -match 'no se me ha roto nada') "$(Get-FrasePetes)"
Comp '  y Get-PeorPeteHistorico devuelve nada, no un cero' ($null -eq (Get-PeorPeteHistorico)) ''

Write-Host ''
Write-Host '-- 5. el aviso: no se repite cada minuto, pero vuelve si empeora --'
# ESTO SE EJECUTA, no se lee: se saca el bloque del bucle y se corre con avisos de pega.
$script:avisados = @()
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    $script:avisados += @{ clave = $clave; texto = $texto }
    return $true
}
function Add-Estadistica([string]$k, [string]$v = '') { }
function Watch-ErroresTragados { return 1 }
function Log([string]$m) { }
$script:uiMia = $false
$script:peteDicho = ''
# el mismo codigo que corre en el bucle, tal cual
$bloque = {
    $petes = Watch-ErroresTragados
    if ($petes -gt 0) {
        $peor = Get-PeorPete
        if ($peor) { Add-Estadistica ('pete:' + $peor.linea) ([string]$peor.veces + ' veces: ' + $peor.que) }
        $hist = Get-PeorPeteHistorico
        if ($hist -and [int]$hist.veces -ge $PeteAvisaDesde) {
            $marca = [string]$hist.linea + ':' + [string]$hist.veces
            $yaDicho = 0
            if ($script:peteDicho -match '^(\d+):(\d+)$' -and $Matches[1] -eq [string]$hist.linea) { $yaDicho = [int]$Matches[2] }
            if ($yaDicho -le 0 -or [int]$hist.veces -ge ($yaDicho * 2)) {
                $script:peteDicho = $marca
                $script:uiMia = $true
                [void](Send-AvisoEntorno ('pete-' + [string]$hist.linea) (Get-FrasePetes) 'medio' 1440)
            }
        }
    }
}
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'pete:979' = 250 } } }
& $bloque
Comp 'con 250 veces avisa' ($script:avisados.Count -eq 1) "$($script:avisados.Count)"
Comp '  y la clave lleva la linea dentro' ($script:avisados.Count -ge 1 -and $script:avisados[0].clave -eq 'pete-979') "$(if($script:avisados.Count){$script:avisados[0].clave})"
Comp '  y se marca como suya (nadie lo pregunto)' ($script:uiMia) 'idea 54'
& $bloque; & $bloque
Comp '  y NO lo repite cada minuto' ($script:avisados.Count -eq 1) "$($script:avisados.Count) tras tres vueltas"
# PERO SI DOBLA, ES OTRA NOTICIA: algo que iba a 250 y va a 500 ha empeorado de verdad
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'pete:979' = 500 } } }
& $bloque
Comp '  pero si DOBLA, vuelve a decirlo' ($script:avisados.Count -eq 2) "$($script:avisados.Count)"
# Y UN PETE EN OTRA LINEA ES OTRO FALLO, y tiene que poder hablar aunque el viejo ya se dijera
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'pete:979' = 500; 'pete:4242' = 900 } } }
& $bloque
Comp 'un pete nuevo en otra linea habla igual' ($script:avisados.Count -eq 3 -and $script:avisados[2].clave -eq 'pete-4242') "$(if($script:avisados.Count -ge 3){$script:avisados[2].clave})"
# Y POR DEBAJO DEL LISTON, NI UNA PALABRA
$script:avisados = @(); $script:peteDicho = ''
$script:statsPega = @{ dias = @{ '2026-10-01' = @{ 'pete:7' = 199 } } }
& $bloque
Comp "con 199 (el liston son $PeteAvisaDesde) no dice nada" ($script:avisados.Count -eq 0) "$($script:avisados.Count)"

Write-Host ''
Write-Host '-- 6. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron para preguntarlo' ($sinCom -match "kind = 'petes'") ''
# POR ORDEN Y NO POR DISTANCIA: una ventana de caracteres se rompe el dia que alguien escriba un
# comentario en medio (ver probar-bancos-fragiles). Se exige que las dos partes ESTEN y en que orden.
$iEjec = $sinCom.IndexOf("'petes' {")
$iFrase = $sinCom.IndexOf('Get-FrasePetes', [Math]::Max(0, $iEjec))
Comp '  y su ejecutor llama a la frase' ($iEjec -ge 0 -and $iFrase -gt $iEjec) ''
$iWatch = $sinCom.IndexOf('Watch-ErroresTragados')
$iHistB = $sinCom.IndexOf('Get-PeorPeteHistorico', [Math]::Max(0, $iWatch))
Comp 'el aviso sale del bloque que ya calculaba el pete' ($iWatch -ge 0 -and $iHistB -gt $iWatch) 'no se estrena ningun reloj'
# EL Add-Estadistica VA ANTES del aviso: si no, la cuenta de hoy se quedaria fuera de la suma que
# decide, y el aviso iria siempre un minuto por detras de la realidad.
$iAdd = $sinCom.IndexOf("Add-Estadistica ('pete:' + ")
$iHist = $sinCom.IndexOf('$hist = Get-PeorPeteHistorico')
Comp '  y se apunta ANTES de mirar la suma' ($iAdd -ge 0 -and $iHist -ge 0 -and $iAdd -lt $iHist) "apunta en $iAdd, mira en $iHist"
# Y EL LISTON SE PUEDE MOVER SIN TOCAR EL CODIGO
Comp 'el liston sale de config.json' ($sinCom -match "Get-Cfg 'registro' 'peteAvisaDesde'") ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova dice lo que se le rompe por dentro, con la linea' -ForegroundColor Green
exit 0
