# LA TABLA DE CORRECCIONES ESCRITA A MANO: 96 DE 110 NUNCA SE HAN OIDO (27/09, idea 109 de las 121)
#
# EL DATO: commands.json lleva 110 correcciones de palabras mal oidas ('yutub', 'espotifai',
# 'guasap'...), escritas a mano una por una. Cruzadas contra las 1.447 frases unicas de
# pruebas\audio\uso -once dias de uso real- solo CATORCE se han oido alguna vez: bril, descagando,
# discor, escagando, "este estado es cargando", estin, navegado, painterest, pinteres, serra, sting,
# team, temporizado y youtub. Las otras 96 son peso muerto que nadie habia medido.
#
# Y NO ES SOLO PESO: Repair-Words hace UN [regex]::Replace POR ENTRADA en cada dictado. MEDIDO con
# una frase de 54 caracteres y 200 repeticiones: 1,125 ms con las 110 y 0,145 ms con las 14. SIETE
# VECES Y MEDIA mas, en el camino de cada orden.
#
# LO QUE ESTE BANCO PROTEGE, y el primero es el que de verdad importa:
#   1. que esto SOLO retire, nunca anada: por parecido fonetico, 'esta' (235 veces en el corpus),
#      'este' (123) y 'estas' (56) se parecen a 'steam', y meter cualquiera convertiria "esta bien"
#      en "steam bien"
#   2. que no se retire nada sin corpus suficiente
#   3. que NUNCA se lleve la tabla entera (corpus roto)
#   4. que las retiradas se MUEVAN y no se borren
#   5. y que el commands.json de verdad no se toque al probar
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
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('ConvertTo-Plain', 'Get-CorpusUso', 'Get-CorreccionesDormidas',
                 'Invoke-CorreccionesDormidas', 'Repair-Words')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$mD = [regex]::Match($txt, '(?m)^\$CorreccionesDiasMin = (\d+)')
Comp 'los dias minimos salen del archivo' $mD.Success ($mD.Groups[1].Value + ' dias')
$CorreccionesDiasMin = if ($mD.Success) { [int]$mD.Groups[1].Value } else { 7 }

Write-Host ''
Write-Host '-- 1. QUIEN SE QUEDA Y QUIEN SE VA --'
$corpus = ' || abre youtub || pon spotify || pinteres || abre steam || esta bien || este juego || '
$claves = @('youtub', 'pinteres', 'espotifai', 'guasap', 'yutub')
$d = @(Get-CorreccionesDormidas $corpus $claves)
Comp '1a. las que se han oido se quedan' (($d -notcontains 'youtub') -and ($d -notcontains 'pinteres')) ([string]($d -join ', '))
Comp '1b. y las que no, a dormir' (($d -contains 'espotifai') -and ($d -contains 'guasap') -and ($d -contains 'yutub')) ''
Comp '1c. son tres de cinco' ($d.Count -eq 3) ([string]$d.Count)
Comp '1d. una clave vacia no cuenta' ((@(Get-CorreccionesDormidas $corpus @('', '  '))).Count -eq 0) ''

Write-Host ''
Write-Host '-- 2. SOLO RETIRA: EL PELIGRO ESTA EN ANADIR --'
# 'esta' aparece 235 veces en el corpus de verdad y se parece a 'steam'. Si esto anadiera por
# parecido fonetico, "esta bien" pasaria a ser "steam bien" en CADA frase.
$ic = Traer 'Invoke-CorreccionesDormidas'
Comp '2a. no hay ni una linea que anada una correccion' (-not ($ic -match 'correcciones \| Add-Member|correcciones\.\$k = ')) 'proponer entradas nuevas es cosa de braya'
Comp '2b. solo se quitan de correcciones' ($ic -match '\$j\.correcciones\.PSObject\.Properties\.Remove\(\$k\)') ''
Comp '2c. y se ponen en dormidas' ($ic -match '\$j\.correccionesDormidas \| Add-Member') 'se MUEVEN, no se borran'
Comp '2d. sin tocar Get-DistanciaFon ni nada fonetico' (-not ($ic -match 'Get-DistanciaFon|Get-ClaveSonido')) "'esta' se parece a 'steam' y romperia cada frase"

Write-Host ''
Write-Host '-- 3. SIN CORPUS SUFICIENTE NO SE RETIRA NADA --'
$LogDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-corr-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$dirUso = Join-Path $LogDir 'pruebas\audio\uso'
New-Item -ItemType Directory -Path $dirUso -Force | Out-Null
$cmdsPath = Join-Path $LogDir 'commands.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$r, [string]$t) { [IO.File]::WriteAllText($r, $t, $UTF8) }
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { }
function Poner([int]$dias, $corr) {
    $l = @()
    for ($i = 0; $i -lt $dias; $i++) {
        $f = (Get-Date).AddDays(-1 * $i).ToString('yyyyMMdd')
        $l += ('{"id":"' + $f + '-120000","texto":"abre youtub y pon musica"}')
    }
    [IO.File]::WriteAllLines((Join-Path $dirUso 'registro.jsonl'), [string[]]$l, $UTF8)
    $o = [ordered]@{ correcciones = $corr; apps = @{ steam = 'steam' } }
    [IO.File]::WriteAllText($cmdsPath, (ConvertTo-Json -InputObject $o -Depth 6), $UTF8)
    $script:cmds = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:corpusUsoCache = $null
    $script:corpusUsoSello = ''
    $script:logs = @()
}
try {
    Poner 3 ([ordered]@{ youtub = 'youtube'; espotifai = 'spotify'; guasap = 'whatsapp' })
    $n = Invoke-CorreccionesDormidas
    Comp '3a. con 3 dias no retira nada' ($n -eq 0) ([string]$n)
    Comp '3b. y lo dice' (@($script:logs | Where-Object { $_ -match 'hacen falta' }).Count -eq 1) ($script:logs -join ' / ')
    Comp '3c. la tabla sigue entera' (@($script:cmds.correcciones.PSObject.Properties).Count -eq 3) ''

    Write-Host ''
    Write-Host '-- 4. CON CORPUS, SE RETIRAN LAS QUE NO SE OYEN --'
    Poner ($CorreccionesDiasMin + 2) ([ordered]@{ youtub = 'youtube'; espotifai = 'spotify'; guasap = 'whatsapp' })
    $n2 = Invoke-CorreccionesDormidas
    Comp '4a. se retiran dos' ($n2 -eq 2) ([string]$n2)
    Comp '4b. y queda la que se oye' (@($script:cmds.correcciones.PSObject.Properties).Count -eq 1 -and $script:cmds.correcciones.youtub -eq 'youtube') ''
    $j = Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Comp '4c. las otras dos estan en dormidas' (@($j.correccionesDormidas.PSObject.Properties).Count -eq 2) ''
    Comp '4d. CON SU VALOR, no vacias' ($j.correccionesDormidas.espotifai -eq 'spotify') ([string]$j.correccionesDormidas.espotifai)
    Comp '4e. y se puede volver a poner a mano' ($j.correccionesDormidas.guasap -eq 'whatsapp') 'se mueven, no se borran'
    Comp '4f. se dice cuantas y cuantas quedan' (@($script:logs | Where-Object { $_ -match 'a dormir' }).Count -eq 1) ($script:logs -join ' / ')
    # y Repair-Words deja de pagarlas EN ESTA SESION
    $cmds = $script:cmds
    Comp '4g. Repair-Words ya no las mira' ((Repair-Words 'abre espotifai') -eq 'abre espotifai') 'la tabla viva se recarga en el acto'
    Comp '4h. pero si la que se oye' ((Repair-Words 'abre youtub') -eq 'abre youtube') ''

    Write-Host ''
    Write-Host '-- 5. NUNCA SE LLEVA LA TABLA ENTERA (corpus roto) --'
    Poner ($CorreccionesDiasMin + 2) ([ordered]@{ zzz1 = 'a'; zzz2 = 'b' })
    $n3 = Invoke-CorreccionesDormidas
    Comp '5a. si NINGUNA se ha oido, no toca nada' ($n3 -eq 0) ([string]$n3)
    Comp '5b. y dice que huele a corpus roto' (@($script:logs | Where-Object { $_ -match 'corpus roto' }).Count -eq 1) ($script:logs -join ' / ')
    Comp '5c. la tabla sigue entera' (@($script:cmds.correcciones.PSObject.Properties).Count -eq 2) ''

    Write-Host ''
    Write-Host '-- 6. EL CORPUS SE LEE BIEN --'
    $co = Get-CorpusUso $dirUso
    Comp '6a. cuenta los dias por el id' ([int]$co.dias -eq ($CorreccionesDiasMin + 2)) ([string]$co.dias + ' dias')
    Comp '6b. y las frases' ([int]$co.frases -ge 1) ([string]$co.frases)
    Comp '6c. con cache por tamano' ((Traer 'Get-CorpusUso') -match '\$sello -eq \$script:corpusUsoSello') 'lee dos jsonl enteros: 2,7 s medidos'
    Comp '6d. y sin ficheros, no revienta' (([int](Get-CorpusUso (Join-Path $LogDir 'no-existe')).frases) -eq 0) ''
} finally {
    Remove-Item -LiteralPath $LogDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 7. EL CABLEADO, Y EL commands.json DE VERDAD INTACTO --'
Comp '7a. corre donde ya corre la copia del dia' ($sinCom -match '(?s)Invoke-PodaCopias\).{0,300}Invoke-CorreccionesDormidas') 'una vez al dia, no en el bucle'
Comp '7b. y recarga la tabla viva al retirar' ($sinCom -match '\$script:cmds = Get-Content -LiteralPath \$cmdsPath') 'para que Repair-Words deje de pagarlas ya'
Comp '7c. queda como decision propia' ($sinCom -match "Add-Estadistica 'auto-ajuste' \(""correcciones dormidas: ") ''
$real = Get-Content -LiteralPath (Join-Path $Raiz 'commands.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$nReal = @($real.correcciones.PSObject.Properties).Count
Comp '7d. el commands.json de verdad no se ha tocado' ($nReal -ge 14) ([string]$nReal + ' correcciones; el banco trabaja en su carpeta')
# y el cruce de verdad, sin escribir nada
$LogDir = $Raiz
$script:corpusUsoCache = $null; $script:corpusUsoSello = ''
$coR = Get-CorpusUso
if ([int]$coR.frases -gt 0) {
    $dR = @(Get-CorreccionesDormidas ([string]$coR.texto) @($real.correcciones.PSObject.Properties.Name))
    Comp '7e. y con los datos de hoy se retirarian casi todas' ($dR.Count -gt ($nReal / 2)) ([string]$dR.Count + ' de ' + [string]$nReal + ', con ' + [string]$coR.frases + ' frases de ' + [string]$coR.dias + ' dias')
    Comp '7f. pero NO todas: quedan las que si se oyen' ($dR.Count -lt $nReal) ([string]($nReal - $dR.Count) + ' se quedan')
} else {
    Write-Host '  --   no hay corpus de uso aqui, se salta'
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la tabla de correcciones se gana el sitio con el uso real' -ForegroundColor Green
exit 0
