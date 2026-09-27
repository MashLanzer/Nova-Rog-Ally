# QUE LA LISTA DE 'LO QUE DECIDI YO SOLA' DEJE DE ESTAR VACIA (27/09, idea 114 de las 121)
#
# EL DATO: memoria\estadisticas.json tiene la clave 'decisiones' y esta vacia. En 16 dias hay 3.335
# eventos en 67 claves distintas y NI UNO es 'auto-ajuste', 'auto-deshecho' ni 'arranque-medias', que
# son las tres unicas que entran ahi. Y no es por falta de motor: hay CATORCE sitios que escriben
# 'auto-ajuste' y ninguno se ha disparado nunca (buscados uno a uno en el registro: 'mi voz:' 0,
# 'nube off' 0, 'oido fino off' 0, 'sonda de' 0...). Las ocho lineas de 'confianza minima' que salen
# en el log son del arranque del 10/09, no del ajuste.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la primera vez de cada numero se apunte: es la primera vez que Nova lo sabe
#   2. que el liston de 'cambio que importa' salga de la propia serie y no de un porcentaje escrito
#   3. que la serie de cambios se alimente SIEMPRE, se apunte o no: alimentarla solo con los
#      apuntados haria que la mediana subiera sola y acabara tapandolo todo
#   4. que una deriva lenta acabe saliendo, y que un numero que baila no escriba nada
#   5. una vez al dia y por numero, o los 60 huecos se llenan en una tarde
#   6. que el detalle lleve la cifra, que es la regla de esa lista
#   7. y que el ritmoBateria NO sea una de las fuentes: hay UNA linea 'BATERIA:' en todo el
#      registro, porque braya juega enchufado. Apuntar algo que pasa una vez cada dieciseis dias
#      no llena ninguna lista.
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
$quiero = @('Test-AjusteQueImporta', 'Add-AjustePropio', 'Get-PercentilLista')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
# EL CUERPO DE UNA FUNCION, RECORTADO POR SUS LIMITES DE VERDAD (27/09, idea 2). Antes el 8n de
# abajo media "a menos de 2000 caracteres de la firma", y eso se pone rojo solo el dia que
# alguien escribe una linea dentro de la funcion. Con el arbol del parser da igual la distancia.
function Cuerpo([string]$nombre) {
    $d = @($defs | Where-Object { $_.Name -eq $nombre })
    if ($d.Count -eq 0) { return '' }
    return (($d[0].Extent.Text -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
}
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 3 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)

# EL MUNDO DE MENTIRA (despues de cargar)
$AjustesCambiosMax = 20
$script:invitado = $false
$script:hab = @{ ajustes = @{} }
function Get-Habitos { return $script:hab }
function Save-Habitos { }
function Get-AjustesPropios { if (-not $script:hab.ajustes) { $script:hab.ajustes = @{} }; return $script:hab.ajustes }
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
$script:apuntadas = @()
function Add-Estadistica([string]$ruta, [string]$det = '', [bool]$c = $false) {
    # SOLO ESTAS TRES ENTRAN EN 'decisiones', copiado del original
    if ($ruta -in @('auto-ajuste', 'auto-deshecho', 'arranque-medias')) { $script:apuntadas += @($ruta + ' | ' + $det) }
}
function Reset { $script:hab = @{ ajustes = @{} }; $script:apuntadas = @(); $script:logs = @() }

Write-Host ''
Write-Host '-- 1. LA PRIMERA VEZ DE CADA NUMERO SE APUNTA --'
Reset
# el p99 de ms por letra que hay en disco ahora mismo: 167 muestras -> 69,7
Comp '1a. el primer valor se apunta' (Add-AjustePropio 'voz-por-letra' 69.7 'lo que tardo en hablar, por letra' '2026-09-27') ''
Comp '1b. y la lista deja de estar vacia' ($script:apuntadas.Count -eq 1) ([string]$script:apuntadas.Count)
Comp '1c. con la etiqueta que esa lista lee' ($script:apuntadas[0] -match '^auto-ajuste \|') ([string]$script:apuntadas[0])
Comp '1d. y con la cifra dentro' ($script:apuntadas[0] -match '69[.,]7') 'un auto-ajuste sin cifra no se puede leer en el parte'
$r0 = Test-AjusteQueImporta $null 69.7 '2026-09-27'
Comp '1e. y lo dice por que' ([string]$r0.porque -eq 'la primera vez que lo se') ([string]$r0.porque)

Write-Host ''
Write-Host '-- 2. UNA VEZ AL DIA Y POR NUMERO --'
Comp '2a. el mismo dia no se repite' (-not (Add-AjustePropio 'voz-por-letra' 99.0 'lo que tardo en hablar, por letra' '2026-09-27')) 'se recalcula en cada frase'
Comp '2b. y no escribe nada' ($script:apuntadas.Count -eq 1) ([string]$script:apuntadas.Count)
Comp '2c. pero OTRO numero si, el mismo dia' (Add-AjustePropio 'trabajo-api-traducir' 1704 'lo que suele tardar api-traducir' '2026-09-27') 'el freno es por numero, no global'
Comp '2d. y ya van dos' ($script:apuntadas.Count -eq 2) ([string]$script:apuntadas.Count)

Write-Host ''
Write-Host '-- 3. EL PRIMER CAMBIO SE APUNTA: DE AHI SALE LA PRIMERA MEDIDA --'
Reset
[void](Add-AjustePropio 'voz-por-letra' 60.0 'por letra' '2026-09-25')
$antesL = $script:apuntadas.Count
Comp '3a. al dia siguiente, el primer cambio entra' (Add-AjustePropio 'voz-por-letra' 62.0 'por letra' '2026-09-26') ''
Comp '3b. y dice que es el primero que le ve' ($script:logs[-1] -match 'el primer cambio que le veo') ([string]$script:logs[-1])
Comp '3c. y el detalle lleva el antes y el despues' ($script:apuntadas[-1] -match '60 -> 62') ([string]$script:apuntadas[-1])

Write-Host ''
Write-Host '-- 4. EL LISTON SALE DE LO QUE ESE NUMERO SE MUEVE --'
# una serie que se mueve de 2 en 2: un salto de 1 no importa, uno de 5 si
$antes = @{ apuntado = 60.0; ultimo = 60.0; dia = '2026-09-25'; cambios = @(2.0, 2.0, 2.0, 2.0) }
$rP = Test-AjusteQueImporta $antes 61.0 '2026-09-26'
Comp '4a. un salto menor que lo normal no se apunta' (-not $rP.apunta) 'se mueve de 2 en 2 y este fue 1'
$rG = Test-AjusteQueImporta $antes 65.0 '2026-09-26'
Comp '4b. uno mayor, si' ($rG.apunta) ([string]$rG.porque)
Comp '4c. y dice el numero y su normal' (([string]$rG.porque -match '5') -and ([string]$rG.porque -match '2')) 'se movio 5 y lo normal es 2'
# y con una serie que baila mucho, el mismo salto NO importa
$baila = @{ apuntado = 60.0; ultimo = 60.0; dia = '2026-09-25'; cambios = @(10.0, 12.0, 9.0, 11.0) }
Comp '4d. el mismo salto en un numero que baila, no' (-not (Test-AjusteQueImporta $baila 65.0 '2026-09-26').apunta) 'lo normal en el son 10, no 2'
Comp '4e. y ahi hace falta uno mayor' ((Test-AjusteQueImporta $baila 75.0 '2026-09-26').apunta) ''

Write-Host ''
Write-Host '-- 5. LA SERIE DE CAMBIOS SE ALIMENTA SIEMPRE --'
$rNo = Test-AjusteQueImporta $antes 61.0 '2026-09-26'
Comp '5a. aunque no se apunte, el salto se guarda' (@($rNo.cambios).Count -eq 5) ([string]@($rNo.cambios).Count + ' cambios de 4 que habia')
Comp '5b. y el guardado es el salto de verdad' ((@($rNo.cambios)[-1]) -eq 1.0) 'si solo entraran los apuntados, la mediana subiria sola'
# el mismo dia tampoco pierde el salto
$rMismo = Test-AjusteQueImporta $antes 61.0 '2026-09-25'
Comp '5c. y el mismo dia tampoco lo pierde' (@($rMismo.cambios).Count -eq 5) ''
# el tope
$lleno = @{ apuntado = 60.0; ultimo = 60.0; dia = '2026-09-25'; cambios = @(1..20 | ForEach-Object { 1.0 }) }
Comp '5d. con el tope puesto, no crece mas' (@((Test-AjusteQueImporta $lleno 63.0 '2026-09-26').cambios).Count -eq 20) '20 es el tope'

Write-Host ''
Write-Host '-- 6. UNA DERIVA LENTA ACABA SALIENDO --'
Reset
# sube de 0,5 en 0,5 todos los dias: cada salto es pequeno, pero la distancia al apuntado crece
$v = 60.0
$dias = @('2026-09-01','2026-09-02','2026-09-03','2026-09-04','2026-09-05','2026-09-06','2026-09-07','2026-09-08')
$cuantas = 0
foreach ($d in $dias) { $v += 0.5; if (Add-AjustePropio 'deriva' $v 'un numero que sube despacio' $d) { $cuantas++ } }
Comp '6a. la deriva se apunta, no se pierde' ($cuantas -ge 2) ([string]$cuantas + ' veces en 8 dias de subida')
Comp '6b. pero no todos los dias' ($cuantas -lt 8) 'la distancia tiene que pasar de lo que se mueve'
# y un numero que baila sin ir a ningun sitio escribe MENOS que la deriva
Reset
$cuantasB = 0
$i = 0
foreach ($d in $dias) { $i++; $vb = 60.0 + $(if ($i % 2 -eq 0) { 0.5 } else { -0.5 }); if (Add-AjustePropio 'baila' $vb 'un numero que va y viene' $d) { $cuantasB++ } }
Comp '6c. el que va y viene escribe menos' ($cuantasB -lt $cuantas) ([string]$cuantasB + ' contra ' + [string]$cuantas)

Write-Host ''
Write-Host '-- 7. LO QUE HAGA OTRO NO ES SU DECISION --'
Reset
$script:invitado = $true
Comp '7a. en modo invitado no apunta' (-not (Add-AjustePropio 'voz-por-letra' 69.7 'por letra' '2026-09-27')) ''
Comp '7b. y no escribe nada' ($script:apuntadas.Count -eq 0) ''
$script:invitado = $false

Write-Host ''
Write-Host '-- 8. EL CABLEADO Y LAS FUENTES --'
Comp '8a. el repaso cuelga del hueco de una vez al dia' ($sinCom -match '(?s)Test-JuegosCiegos.{0,400}Test-AjustesDelDia') ''
Comp '8b. y no del bucle' (-not ($sinCom -match '(?s)juegoCheck.{0,400}Test-AjustesDelDia')) 'lee dos ficheros de disco'
Comp '8c. la fuente del plazo de la voz esta' ($sinCom -match "Add-AjustePropio 'voz-por-letra'") '167 muestras en disco: hay dato desde el primer arranque'
# SOBRE EL CUERPO DE Test-AjustesDelDia: Get-VozTiempos sale en mas sitios del fichero y el caso
# pasaba por otro, asi que quitarle el liston al repaso no lo ponia rojo.
$cuerpoD = @($defs | Where-Object { $_.Name -eq 'Test-AjustesDelDia' })[0].Extent.Text
Comp '8d. y exige el historial de la casa' ($cuerpoD -match '\$DecisionMinIntentos') 'el mismo liston que el resto de decisiones propias'
Comp '8d2. y no se conforma con una muestra' (-not ($cuerpoD -match '@\(\$vz\)\.Count -ge 1\b')) 'con dos frases el p99 no dice nada'
Comp '8e. la del p75 de cada trabajo, tambien' ($sinCom -match "Add-AjustePropio \(\'trabajo-\' \+ \`$cl\)") ''
Comp '8f. y la linea base del consumo' ($sinCom -match "Add-AjustePropio \(\'consumo-\' \+ \`$nom") ''
# EL ritmoBateria NO: una linea 'BATERIA:' en todo el registro
Comp '8g. el ritmoBateria NO es una fuente' (-not ($sinCom -match "Add-AjustePropio[^\r\n]{0,60}ritmoBateria")) 'pasa una vez cada dieciseis dias'
Comp '8h. la cuota de nucleo tampoco' (-not ($sinCom -match "Add-AjustePropio \(\'cpu-")) 'baila mucho mas que la RAM y seria ruido'
Comp '8i. y las series del consumo no se cuentan como trabajo' ($sinCom -match "\`$cl\.StartsWith\('ram:'\)") 'si no, ram:oido saldria dos veces'
# SIN SUS COMENTARIOS: el de dentro explica justamente por que NO se usa Get-PercentilLista, y
# buscarla sobre el texto entero la encontraba ahi.
$cuerpoT = ((@($defs | Where-Object { $_.Name -eq 'Test-AjusteQueImporta' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '8j. Test-AjusteQueImporta es pura' (-not ($cuerpoT -match '(Get-Date|\$sw\.|Log |Test-Path|Get-Content|Save-)')) 'por eso se le pueden correr ocho dias en un milisegundo'
# el 0.5 que hay dentro es el percentil 50, no una tolerancia: lo que se vigila es que el liston
# con el que se compara salga de la serie y no de una constante
Comp '8k. el liston sale de sus propios cambios' (($cuerpoT -match '\$dist -gt \$normal') -and ($cuerpoT -match '\$ordC = @\(\$sinMedir')) ''
Comp '8l. y no de un factor sobre el valor' (-not ($cuerpoT -match '\$valor \* |\* \$valor|apuntado \* ')) 'nada de "un 10 % mas"'
Comp '8m. ni usa el percentil entero de la casa' (-not ($cuerpoT -match 'Get-PercentilLista')) 'aquel devuelve [int] y con 0,5 daba 0'
Comp '8n. la etiqueta es una de las tres que esa lista lee' ((Cuerpo 'Add-AjustePropio') -match "Add-Estadistica 'auto-ajuste'") ''
Comp '8o. y el camino a decisiones sigue en pie' ($sinCom -match "\`$ruta -in @\('auto-ajuste', 'auto-deshecho', 'arranque-medias'\)") ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la lista de lo que decidio ella sola ya tiene con que llenarse' -ForegroundColor Green
exit 0
