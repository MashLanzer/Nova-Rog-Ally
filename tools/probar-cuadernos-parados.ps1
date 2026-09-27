# VIGILAR LOS FICHEROS DE MEMORIA, NO SOLO LAS CARPETAS (27/09, idea 115 de las 121)
#
# EL DATO: la vigilancia de costumbres mira TRES carpetas y nadie mira los ficheros sueltos.
# Contado en disco: el codigo nombra 41 ficheros .json dentro de memoria\ y solo existen 20. Y de los
# veinte, cuatro llevan dias congelados sin que nadie se entere: fechas.json 16 dias,
# recordatorios.json 15, musica.json 6 y nube-tiempos.json 3.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la lista de ficheros NO se escriba a mano: se pregunta a las variables del script, porque
#      una lista a mano en una casa que estrena cuadernos cada dia nace desactualizada
#   2. que los de subcarpeta (diario, semanas, cerebro) no se cuenten como ficheros sueltos
#   3. que el ritmo salga del propio fichero y no de un numero: musica.json parado seis dias no es
#      una averia si braya pone musica cada cinco
#   4. que sin historial suficiente se calle (el mismo liston de cuatro que la hora de dormir)
#   5. que el que ACABA de escribirse no se acuse nunca
#   6. que el codigo recien nacido no se acuse de no haber tenido tiempo: de los 21 que hoy no
#      existen, la mitad son de esta misma tanda
#   7. que se diga UNA vez y no cada dia
#   8. y que esto NO vaya a la lista de 'lo que decidi yo sola': un cuaderno parado no es una
#      decision, y meterlo ahi seria mentir sobre lo que esa lista significa
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
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LAS PIEZAS DE VERDAD. Los dobles van DESPUES.
$quiero = @('Test-FicheroParado', 'Get-FicherosMemoria')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 2 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)

# EL MUNDO DE MENTIRA (despues de cargar)
$FicherosHuecosMax = 30
$FicherosHuecosMin = 4
$FicherosVecesRitmo = 3
$FicherosNacerDias = 7

Write-Host ''
Write-Host '-- 1. LA LISTA SE PREGUNTA, NO SE ESCRIBE A MANO --'
# un memoria de mentira con variables como las de la casa
$MemoriaDir = 'C:\pruebas\memoria'
$HabitosPath = Join-Path $MemoriaDir 'habitos.json'
$MusicaPath = Join-Path $MemoriaDir 'musica.json'
$FirmasPath = Join-Path $MemoriaDir 'firmas.json'
$DiarioAlgoPath = Join-Path $MemoriaDir 'diario\2026-09-27.json'      # subcarpeta: NO cuenta
$CerebroAlgoPath = Join-Path $MemoriaDir 'cerebro\trozos.json'        # subcarpeta: NO cuenta
$OtraCosaPath = 'C:\otro\sitio\cosa.json'                             # fuera de memoria: NO cuenta
$UnMarkdownPath = Join-Path $MemoriaDir 'perfil.md'                   # no es json: NO cuenta
# LA FOTO DE LAS VARIABLES ENTRA POR PARAMETRO, que es lo que hace probable esta pieza: con un
# Get-Variable dentro, la funcion sacada por AST no ve NADA -Invoke-Expression le hace su propio
# ambito- y devolvia la lista vacia siempre, con -Scope Script y sin el.
$falsas = @(
    @{ Name = 'HabitosPath';     Value = $HabitosPath }
    @{ Name = 'MusicaPath';      Value = $MusicaPath }
    @{ Name = 'FirmasPath';      Value = $FirmasPath }
    @{ Name = 'DiarioAlgoPath';  Value = $DiarioAlgoPath }
    @{ Name = 'CerebroAlgoPath'; Value = $CerebroAlgoPath }
    @{ Name = 'OtraCosaPath';    Value = $OtraCosaPath }
    @{ Name = 'UnMarkdownPath';  Value = $UnMarkdownPath }
    @{ Name = 'MusicaOtraVez';   Value = $MusicaPath }
    @{ Name = 'UnNulo';          Value = $null }
) | ForEach-Object { [pscustomobject]$_ }
# SIN @() en el llamador: ver el comentario de su return. Con @() esto valdria 1 siempre.
$lista = Get-FicherosMemoria 'C:\pruebas\memoria' $falsas
$nombres = @($lista | ForEach-Object { [System.IO.Path]::GetFileName($_) })
Comp '1a. encuentra los sueltos de memoria' (($nombres -contains 'musica.json') -and ($nombres -contains 'firmas.json') -and ($nombres -contains 'habitos.json')) ([string]$nombres.Count + ': ' + ($nombres -join ', '))
Comp '1b. los de subcarpeta NO' (-not ($nombres -contains '2026-09-27.json')) 'el diario y las semanas son carpetas, y de esas ya se encarga la otra vigilancia'
Comp '1c. ni el cerebro' (-not ($nombres -contains 'trozos.json')) ''
Comp '1d. ni lo que esta fuera de memoria' (-not ($nombres -contains 'cosa.json')) ''
Comp '1e. ni lo que no es json' (-not ($nombres -contains 'perfil.md')) ''
Comp '1f. y no se repite ninguno' ($nombres.Count -eq (@($nombres | Select-Object -Unique)).Count) ''

Write-Host ''
Write-Host '-- 2. LA PRIMERA VEZ SOLO SE APUNTA QUE EXISTE EL NOMBRE --'
$r1 = Test-FicheroParado $null '2026-09-10' 17 '2026-09-27'
Comp '2a. la primera vez no avisa' (-not $r1.avisa) 'aunque lleve 17 dias parado'
Comp '2b. ni lo echa en falta' (-not $r1.nace) ''
Comp '2c. y guarda la fecha que vio' ([string]$r1.visto -eq '2026-09-10') ([string]$r1.visto)
Comp '2d. sin inventarse huecos hacia atras' (@($r1.huecos).Count -eq 0) 'el historial empieza hoy'

Write-Host ''
Write-Host '-- 3. EL RITMO SALE DEL PROPIO FICHERO --'
# musica.json: si se escribe cada 5 dias, seis dias parado NO es nada
$cada5 = @{ visto = '2026-09-20'; huecos = @(5.0, 5.0, 4.0, 6.0, 5.0); conocido = '2026-08-01'; dicho = '' }
Comp '3a. seis dias parado con ritmo de cinco, no avisa' (-not (Test-FicheroParado $cada5 '2026-09-20' 6 '2026-09-26').avisa) 'el triple de 5 son 15'
Comp '3b. y a los 16 si' ((Test-FicheroParado $cada5 '2026-09-20' 16 '2026-10-06').avisa) ''
# el mismo numero de dias con un fichero diario SI es una averia
$cada1 = @{ visto = '2026-09-20'; huecos = @(1.0, 1.0, 1.0, 1.0, 2.0); conocido = '2026-08-01'; dicho = '' }
$rD = Test-FicheroParado $cada1 '2026-09-20' 6 '2026-09-26'
Comp '3c. seis dias con ritmo de uno, si avisa' ($rD.avisa) ('su ritmo es ' + [Math]::Round($rD.ritmo, 1) + ' y el triple son ' + [Math]::Round($rD.ritmo * 3, 1))
Comp '3d. y dice su ritmo de verdad' ([Math]::Abs([double]$rD.ritmo - 1.0) -lt 0.01) '1 dia es su mediana'
Comp '3e. el mismo parado, dos ritmos, dos respuestas' ((Test-FicheroParado $cada1 '2026-09-20' 6 '2026-09-26').avisa -and -not (Test-FicheroParado $cada5 '2026-09-20' 6 '2026-09-26').avisa) 'ahi esta el sentido de sacarlo de sus datos'

Write-Host ''
Write-Host '-- 4. SIN HISTORIAL, SE CALLA --'
$poco = @{ visto = '2026-09-10'; huecos = @(1.0, 1.0, 1.0); conocido = '2026-08-01'; dicho = '' }
Comp '4a. con tres huecos no opina' (-not (Test-FicheroParado $poco '2026-09-10' 99 '2026-09-27').avisa) 'el liston son cuatro, el de la hora de dormir'
$justo = @{ visto = '2026-09-10'; huecos = @(1.0, 1.0, 1.0, 1.0); conocido = '2026-08-01'; dicho = '' }
Comp '4b. con cuatro, si' ((Test-FicheroParado $justo '2026-09-10' 99 '2026-09-27').avisa) ''
$sinNada = @{ visto = '2026-09-10'; huecos = @(); conocido = '2026-08-01'; dicho = '' }
Comp '4c. y sin ninguno, tampoco' (-not (Test-FicheroParado $sinNada '2026-09-10' 99 '2026-09-27').avisa) ''

Write-Host ''
Write-Host '-- 5. EL QUE ACABA DE ESCRIBIRSE NO SE ACUSA --'
$rN = Test-FicheroParado $cada1 '2026-09-27' 0 '2026-09-27'
Comp '5a. si cambio la fecha, no avisa' (-not $rN.avisa) ''
Comp '5b. y el hueco nuevo entra en su ritmo' (@($rN.huecos).Count -eq 6) ([string]@($rN.huecos).Count + ' de 5 que habia')
Comp '5c. con los dias que paso de verdad' ((@($rN.huecos)[-1]) -eq 7.0) 'del 20 al 27 son siete'
Comp '5d. y se queda con la fecha nueva' ([string]$rN.visto -eq '2026-09-27') ''
# Y EL CASO QUE DE VERDAD NECESITA ESE 'return': Nova apagada diez dias, y el fichero se escribio
# hace ocho -o sea DESPUES de la ultima mirada-. La fecha es nueva, asi que no esta parado; pero
# $diasSin son 8 y con un ritmo de 1 el liston de 3 se pasaria y lo acusaria por las buenas.
$alVolver = @{ visto = '2026-09-10'; huecos = @(1.0, 1.0, 1.0, 1.0); conocido = '2026-08-01'; dicho = '' }
$rAV = Test-FicheroParado $alVolver '2026-09-19' 8 '2026-09-27'
Comp '5f. una escritura que se descubre tarde no se acusa' (-not $rAV.avisa) '8 dias sin, ritmo 1, liston 3: sin el return avisaria'
Comp '5g. y su hueco se apunta igual' (@($rAV.huecos).Count -eq 5) ([string]@($rAV.huecos).Count)
# y el tope
$lleno = @{ visto = '2026-09-20'; huecos = @(1..30 | ForEach-Object { 1.0 }); conocido = '2026-08-01'; dicho = '' }
Comp '5e. con el tope puesto, no crece' (@((Test-FicheroParado $lleno '2026-09-27' 0 '2026-09-27').huecos).Count -eq 30) '30 es el tope'

Write-Host ''
Write-Host '-- 6. EL CODIGO RECIEN NACIDO NO SE ACUSA --'
# firmas.json no existe y Nova lo conoce de hoy: es de codigo escrito ayer
$reciente = @{ visto = ''; huecos = @(); conocido = '2026-09-27'; dicho = '' }
Comp '6a. conocido de hoy y sin nacer, no se cuenta' (-not (Test-FicheroParado $reciente '' 0 '2026-09-27').nace) 'de los 21 que no existen, la mitad son de esta tanda'
Comp '6b. ni a los seis dias' (-not (Test-FicheroParado $reciente '' 0 '2026-10-03').nace) ''
Comp '6c. y a los siete si' ((Test-FicheroParado $reciente '' 0 '2026-10-04').nace) 'ahi ya tuvo ocasion'
# y uno que no existe NO se acusa de estar parado: no hay costumbre que romper
$viejoSinNacer = @{ visto = ''; huecos = @(9.0, 9.0, 9.0, 9.0); conocido = '2026-01-01'; dicho = '' }
$rV = Test-FicheroParado $viejoSinNacer '' 0 '2026-09-27'
Comp '6d. el que no existe no esta "parado"' (-not $rV.avisa) 'no hay ritmo que romper si nunca hubo escritura'
Comp '6e. se echa en falta, que es otra cosa' ($rV.nace) ''

Write-Host ''
Write-Host '-- 7. SE DICE UNA VEZ, NO CADA DIA --'
$yaDicho = @{ visto = '2026-09-10'; huecos = @(1.0, 1.0, 1.0, 1.0); conocido = '2026-08-01'; dicho = '2026-09-27' }
Comp '7a. el mismo dia no se repite' (-not (Test-FicheroParado $yaDicho '2026-09-10' 17 '2026-09-27').avisa) 'mientras siga parado, la noticia es la misma'
Comp '7b. y al dia siguiente si' ((Test-FicheroParado $yaDicho '2026-09-10' 18 '2026-09-28').avisa) 'lo frena el plazo del aviso, no esto'

Write-Host ''
Write-Host '-- 8. EL CABLEADO --'
Comp '8a. el repaso cuelga del hueco de una vez al dia' ($sinCom -match '(?s)Test-AjustesDelDia.{0,400}Test-FicherosMemoria') ''
Comp '8b. y no del bucle' (-not ($sinCom -match '(?s)juegoCheck.{0,500}Test-FicherosMemoria')) 'hace un Test-Path por fichero'
Comp '8c. una sola frase para todos los parados' ($sinCom -match "Send-AvisoEntorno 'fichero-parado'") 'tres avisos por lo mismo serian tres interrupciones'
Comp '8d. y de nivel bajo, que no es una urgencia' ($sinCom -match "'fichero-parado' \`$fr 'bajo'") ''
Comp '8e. NO va a la lista de lo que decidio ella' (-not ($sinCom -match "(?s)function Test-FicherosMemoria[\s\S]{0,3000}?Add-Estadistica 'auto-ajuste'")) 'un cuaderno parado no es una decision suya'
Comp '8f. la vigilancia de carpetas sigue en pie' ($sinCom -match 'function Get-CostumbresPropias') 'esto es lo que le faltaba, no su sustituto'
Comp '8g. y las tres carpetas siguen ahi' (($sinCom -match "'diario'") -and ($sinCom -match "'semanas'") -and ($sinCom -match "'copias'")) ''
$cuerpoT = ((@($defs | Where-Object { $_.Name -eq 'Test-FicheroParado' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '8h. Test-FicheroParado es pura' (-not ($cuerpoT -match '(Get-Date|\$sw\.|Log |Test-Path|Get-Item|Save-)')) 'por eso se le pueden correr veinte casos en un milisegundo'
Comp '8i. el liston es el triple de SU ritmo' ($cuerpoT -match '\$r\.ritmo \* \$FicherosVecesRitmo') 'no un numero de dias escrito'
Comp '8j. y el minimo de historial es el de la casa' ($cuerpoT -match '\$FicherosHuecosMin') ''
$cuerpoG = @($defs | Where-Object { $_.Name -eq 'Get-FicherosMemoria' })[0].Extent.Text
# LA FOTO ENTRA, NO SE COGE DENTRO: eso es lo que permite que este banco la pruebe de verdad
Comp '8k. Get-FicherosMemoria es pura' (-not ($cuerpoG -match 'Get-Variable|Test-Path|Get-Item|Get-Date')) 'con un Get-Variable dentro, sacada por AST devolvia vacio siempre'
Comp '8m. y quien la llama le pasa las de verdad' ($sinCom -match 'Get-FicherosMemoria \(\[string\]\$MemoriaDir\) @\(Get-Variable') 'el sitio que SI las ve'
Comp '8n. y no hay lista de nombres a mano en ningun sitio' (-not ($sinCom -match "ficherosDeMemoria = @\('")) ''
Comp '8l. y no lleva nombres escritos dentro' (-not ($cuerpoG -match "'[a-z-]+\.json'")) ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova ya se da cuenta cuando uno de sus cuadernos se queda parado' -ForegroundColor Green
exit 0
