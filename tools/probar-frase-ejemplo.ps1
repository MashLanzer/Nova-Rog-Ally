# LA FRASE DE EJEMPLO DE WHISPER, ESCRITA CON SUS PROPIAS ORDENES (27/09, idea 118 de las 121)
#
# EL DATO: a Whisper se le pasa siempre la misma frase, escrita a mano el 14/09 y sin tocar desde
# entonces: "Nova, abre Steam. Sube el volumen. Pon el modo noche. Que hora es? Baja el brillo."
# Contadas las primeras palabras de las 226 ordenes utiles de destinos.jsonl:
#     abre 23, cierra 18, que 13, mira 10, dime 6, revisa 5, muevete 5, pon 4, baja 3, sube 1
# La frase lleva 'sube' -UNA orden real en todo el historial- y 'baja' -tres-, y NO lleva 'cierra',
# que son dieciocho. Y 'cierra' es justo el que peor se oye: 21 veces salio deformado en el registro
# -'Tierra Steam', 'Sierra Gul', 'Si es Steam', 'Sierra and the Ring'-.
#
# LO QUE ESTE BANCO PROTEGE, Y LO PRIMERO ES LO QUE MAS IMPORTA:
#   1. las DOS guardas medidas del 14/09: ni un numero ni un nombre propio en la frase. Son lo unico
#      que sostiene que este ejemplo funcione, y por eso el texto sale de plantillas de la casa y no
#      de las ordenes de braya, que traen las dos cosas.
#   2. que 'cierra' entre, que es el motivo de la idea
#   3. que el dato de su uso elija QUE verbos, de mas usado a menos
#   4. que sin historial no se cambie nada
#   5. que la frase no baile entre dos arranques con los mismos datos
#   6. y que una charla o un descarte NO cuenten como orden
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

# LAS PIEZAS Y LA TABLA, DEL FICHERO REAL
$quiero = @('ConvertTo-Plain', 'Get-VerbosUsados', 'Get-PromptOrdenes')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 3 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)
$asg = $arbol.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$PromptFrases' }, $true)
Invoke-Expression ('$PromptFrases = ' + $asg.Right.Extent.Text)
$PromptOrdenesMax = [int]([regex]::Match($sinCom, '\$PromptOrdenesMax = (\d+)').Groups[1].Value)
$PromptOrdenesMin = [int]([regex]::Match($sinCom, '\$PromptOrdenesMin = (\d+)').Groups[1].Value)
Comp 'la tabla de plantillas sale del fichero real' ($PromptFrases.Count -ge 10) ([string]$PromptFrases.Count + ' verbos, ' + $PromptOrdenesMax + ' frases, minimo ' + $PromptOrdenesMin)

Write-Host ''
Write-Host '-- 1. LAS DOS GUARDAS DEL 14/09: NI NUMEROS NI NOMBRES PROPIOS --'
# NINGUNA plantilla puede llevar una cifra: con "al treinta" dentro, "pon el juego al ochenta" se
# oia "al treinta", y el numero cambiado se haria en silencio.
$conCifra = @()
foreach ($k in @($PromptFrases.Keys)) { if ([string]$PromptFrases[$k] -match '\d') { $conCifra += @([string]$k) } }
Comp '1a. ni una plantilla lleva cifras' ($conCifra.Count -eq 0) $(if ($conCifra.Count) { 'las llevan: ' + ($conCifra -join ', ') } else { 'las ' + $PromptFrases.Count + ' limpias' })
# ni numeros escritos con letra, que arrastran igual
$conLetra = @()
foreach ($k in @($PromptFrases.Keys)) {
    if ([string]$PromptFrases[$k] -match '(?i)\b(?:cero|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|veinte|treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa|cien|mil)\b') { $conLetra += @([string]$k) }
}
Comp '1b. ni numeros escritos con letra' ($conLetra.Count -eq 0) $(if ($conLetra.Count) { 'los llevan: ' + ($conLetra -join ', ') } else { 'el numero arrastra igual escrito' })
# NI NOMBRES PROPIOS: con "Abre Little Nightmares III" se inventaba ese juego en frases que no lo
# decian. Se busca cualquier palabra con mayuscula que no sea la primera de la frase.
$conNombre = @()
foreach ($k in @($PromptFrases.Keys)) {
    $f = [string]$PromptFrases[$k]
    $pals = @($f -split '\s+')
    for ($i = 1; $i -lt $pals.Count; $i++) {
        $w = $pals[$i].Trim('.', ',', '?', '!')
        if ($w.Length -gt 1 -and $w -cmatch '^[A-Z]') { $conNombre += @([string]$k + ': ' + $w) }
    }
}
Comp '1c. ni un nombre propio en ninguna' ($conNombre.Count -eq 0) $(if ($conNombre.Count) { ($conNombre -join ', ') } else { 'ni Steam, ni juegos, ni nada' })
# y la de hoy SI lleva uno: Steam. Se deja dicho, que es de donde viene la idea.
Comp '1d. y la de hoy llevaba "Steam"' ($sinCom -match 'PROMPT_ORDENES_POR_DEFECTO|abre Steam' -or (Get-Content (Join-Path $Raiz 'wake_vosk.py') -Raw) -match 'abre Steam') 'por eso las plantillas son de la casa y no de sus ordenes'

Write-Host ''
Write-Host '-- 2. CON SUS DATOS DE VERDAD: "cierra" ENTRA --'
# el conteo real de destinos.jsonl, copiado aqui
$reales = @{ abre = 23; cierra = 18; que = 13; mira = 10; dime = 6; revisa = 5; muevete = 5; pon = 4; baja = 3; apaga = 1; sube = 1 }
$fr = Get-PromptOrdenes $reales
Comp '2a. sale una frase' ($fr.Length -gt 20) ([string]$fr)
Comp '2b. y lleva "Cierra"' ($fr -match '(?i)\bcierra\b') '18 usos, y 21 veces mal oido'
Comp '2c. y "abre", el mas usado' ($fr -match '(?i)\babre\b') '23 usos'
Comp '2d. ya NO lleva "Sube"' (-not ($fr -match '(?i)\bsube\b')) 'una sola orden real en todo el historial'
Comp '2e. ni "Baja"' (-not ($fr -match '(?i)\bbaja\b')) 'tres'
Comp '2f. son cinco frases, como la de hoy' (@($fr -split '(?<=[.?])\s+' | Where-Object { $_ }).Count -eq $PromptOrdenesMax) ([string]@($fr -split '(?<=[.?])\s+' | Where-Object { $_ }).Count)
Comp '2g. empieza por "Nova,"' ($fr.StartsWith('Nova, ')) 'es la palabra con la que empieza cada orden'
# y la frase generada tampoco lleva numeros ni nombres
Comp '2h. la frase generada no lleva cifras' (-not ($fr -match '\d')) ''

Write-Host ''
Write-Host '-- 3. EL ORDEN LO MANDA EL USO --'
# si manana 'pon' fuera el mas usado, iria primero
$otro = @{ pon = 90; sube = 80; abre = 2; cierra = 1 }
$fr2 = Get-PromptOrdenes $otro
Comp '3a. el mas usado va primero' ($fr2.StartsWith('Nova, pon')) ([string]$fr2)
Comp '3b. y el segundo, segundo' ($fr2 -match '^Nova, pon [^.]+\. Sube') ''
Comp '3c. con menos de cinco verbos, salen los que hay' (@((Get-PromptOrdenes @{ abre = 30; cierra = 20 }) -split '(?<=[.?])\s+' | Where-Object { $_ }).Count -eq 2) ''

Write-Host ''
Write-Host '-- 4. SIN HISTORIAL NO SE CAMBIA NADA --'
Comp '4a. con 19 ordenes no se toca' ((Get-PromptOrdenes @{ abre = 19 }) -eq '') ('el liston son ' + $PromptOrdenesMin)
Comp '4b. con 20, si' ((Get-PromptOrdenes @{ abre = 20 }) -ne '') ''
Comp '4c. sin nada, tampoco' ((Get-PromptOrdenes @{}) -eq '') ''
# y un verbo SIN plantilla no puede colar texto suyo
Comp '4d. un verbo sin plantilla no entra' ((Get-PromptOrdenes @{ 'destilada' = 99; 'abre' = 30 }) -notmatch 'destilada') 'lo que no tiene plantilla no se inventa'
Comp '4e. y si NINGUNO tiene plantilla, no se cambia' ((Get-PromptOrdenes @{ 'destilada' = 99; 'encerno' = 50 }) -eq '') 'mejor la de siempre que una inventada'

Write-Host ''
Write-Host '-- 5. LA MISMA ENTRADA DA LA MISMA FRASE --'
# si bailara entre arranques, el oido tendria un ejemplo distinto cada vez
$empate = @{ abre = 10; cierra = 10; pon = 10; dime = 10; mira = 10; sube = 10 }
$a1 = Get-PromptOrdenes $empate
$a2 = Get-PromptOrdenes $empate
$a3 = Get-PromptOrdenes $empate
Comp '5a. tres veces, la misma' (($a1 -eq $a2) -and ($a2 -eq $a3)) ([string]$a1)
Comp '5b. y con todo empatado, sale por orden de verbo' ($a1.StartsWith('Nova, abre')) 'el desempate es el nombre, no el azar'

Write-Host ''
Write-Host '-- 6. UNA CHARLA NO ES UNA ORDEN --'
$filas = @(
    [pscustomobject]@{ hizo = 'local';     detalle = 'abre el navegador' }
    [pscustomobject]@{ hizo = 'accion';    detalle = 'cierra la ventana' }
    [pscustomobject]@{ hizo = 'traducir';  detalle = 'Cierra Steam' }
    [pscustomobject]@{ hizo = 'traducida'; detalle = 'pon el modo noche' }
    [pscustomobject]@{ hizo = 'charla';    detalle = 'abre abre abre abre' }
    [pscustomobject]@{ hizo = 'descarte';  detalle = 'abre' }
    [pscustomobject]@{ hizo = 'ruido';     detalle = 'abre' }
    [pscustomobject]@{ hizo = 'error';     detalle = 'abre' }
    [pscustomobject]@{ hizo = 'local';     detalle = '' }
)
$c = Get-VerbosUsados $filas
Comp '6a. cuenta las cuatro atendidas' ((([int]$c['abre']) + ([int]$c['cierra']) + ([int]$c['pon'])) -eq 4) ('abre ' + [int]$c['abre'] + ', cierra ' + [int]$c['cierra'] + ', pon ' + [int]$c['pon'])
Comp '6b. y "abre" solo una vez' ([int]$c['abre'] -eq 1) 'las de charla, descarte, ruido y error no cuentan'
Comp '6c. la de detalle vacio no rompe' ($c.Count -eq 3) ([string]$c.Count + ' verbos distintos')
Comp '6d. "Cierra" con mayuscula cuenta igual' ([int]$c['cierra'] -eq 2) 'ConvertTo-Plain la baja'

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
Comp '7a. se escribe en tmp' ($sinCom -match "\`$PromptOrdenesPath = Join-Path \`$TmpDir 'prompt-ordenes.txt'") 'donde el oido la busca'
Comp '7b. y se rehace una vez al dia' ($sinCom -match '(?s)Test-FicherosMemoria.{0,400}Update-PromptOrdenes') ''
Comp '7c. no en el bucle' (-not ($sinCom -match '(?s)juegoCheck.{0,500}Update-PromptOrdenes')) 'lee destinos.jsonl entero'
Comp '7d. y solo escribe si cambia' ($sinCom -match '\$antes -eq \$fr') 'un fichero reescrito igual es disco por nada'
Comp '7e. lo dice cuando cambia' ($sinCom -match 'la frase de ejemplo pasa a ser') ''
$cuerpoP = ((@($defs | Where-Object { $_.Name -eq 'Get-PromptOrdenes' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7f. Get-PromptOrdenes es pura' (-not ($cuerpoP -match '(Get-Date|Test-Path|Get-Content|Log |\$sw\.)')) 'por eso se le pueden correr veinte casos'
Comp '7g. y Get-VerbosUsados tambien' (-not (((@($defs | Where-Object { $_.Name -eq 'Get-VerbosUsados' })[0].Extent.Text) -match '(Get-Date|Test-Path|Get-Content|Log )'))) ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la frase de ejemplo ya lleva los verbos que de verdad dice' -ForegroundColor Green
exit 0
