# LO QUE SE APRENDE LLEVA LA FRASE DE BRAYA COMO CLAVE (26/09, idea 7 de las 121).
#
# Cuando la charla decide que lo dicho era en realidad una orden, la REESCRIBE a su manera, y
# hasta hoy era esa reescritura la que acababa de clave en traducciones.json. O sea que Nova
# aprendia a entender SUS PROPIAS palabras, que braya no vuelve a decir nunca. La frase de
# verdad se tenia delante ($ev.original), se escribia en el log y se tiraba.
#
# MEDIDO: de las 21 lineas APRENDIDO del registro, CUATRO tienen de clave una frase que braya
# no dijo jamas en esa forma -'cambia al bloc de notas', 'Ensectiva el modo noche', 'Que ponga
# muzigen, YouTube' y 'Cierra este in.'-. Y esa ultima es la que envenevo el vocabulario el
# 25/09: braya dijo "Que habla, dije que cerraras este in" y se guardo 'Cierra este in.' =
# 'cierra discord', apuntando a la app por la que habla con su pareja. Explica tambien el otro
# numero: 21 aprendidas y UNA sola usada en su vida.
#
# LO QUE NO SE TOCA: la orden reescrita sigue siendo la que se EJECUTA. Solo cambia bajo que
# nombre se archiva, y se archivan LAS DOS.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. la frase de braya se guarda cuando la charla la reescribe --'
Comp 'se guarda fraseComoLaDijiste' ($sinCom -match '\$script:fraseComoLaDijiste = @\{') ''
Comp '  con lo que dijo braya, no con la reescritura' ($sinCom -match 'texto = \[string\]\$ev\.original') ''
# Y SOLO CUANDO SON DISTINTAS: si la charla no reescribio nada, no hay nada que arreglar y
# guardarlo seria aprender dos veces lo mismo.
Comp '  y solo si la charla la cambio' ($sinCom -match '\$ev\.original\) -ne \$ordenC') ''
# SE LIMPIA CUANDO NO HAY: si se quedara pegada, la siguiente traduccion -de otra frase
# distinta- se aprenderia con la clave de la anterior. Seria peor que el fallo original.
# SE BUSCA EN EL BLOQUE DE LA CHARLA, no en todo el archivo (26/09, lo cazo una rotura). La
# cadena "$script:fraseComoLaDijiste = $null" tambien aparece en la declaracion inicial y
# dentro de Get-FraseComoLaDijiste, asi que buscandola suelta el banco seguia verde con el
# "else" de la charla borrado: la frase se quedaba pegada y la SIGUIENTE traduccion -de otra
# frase distinta- se habria aprendido con la clave de la anterior. Peor que el fallo original.
$iCh = $sinCom.IndexOf('$script:fraseComoLaDijiste = @{')
$bloqueCh = if ($iCh -ge 0) { $sinCom.Substring($iCh, [Math]::Min(320, $sinCom.Length - $iCh)) } else { '' }
Comp '  y se borra cuando no la hay' ($bloqueCh -match 'else \{[\s\S]{0,80}\$script:fraseComoLaDijiste = \$null') 'si se quedara pegada, envenenaria la siguiente'

Write-Host ''
Write-Host '-- 2. la ventana sale de los datos --'
$m = [regex]::Match($txt, '(?m)^\$FraseDichaVentanaMs\s*=\s*(.+)$')
Comp 'se saca del archivo FraseDichaVentanaMs' $m.Success ''
if ($m.Success) { Invoke-Expression ('$FraseDichaVentanaMs = ' + $m.Groups[1].Value.Trim()) }
# LOS HUECOS REALES entre la reescritura y el APRENDIDO: 2,2,2,2,2,2,2,2,3,3,3,4,4,5,6,11 y
# 4800 segundos. La ventana tiene que cubrir los dieciseis y dejar fuera el de hora y veinte.
Comp '  cubre el hueco real mas largo (11 s)' ($FraseDichaVentanaMs -ge 11000) "$([int]($FraseDichaVentanaMs/1000)) s"
Comp '  y deja fuera el falso (4800 s)' ($FraseDichaVentanaMs -lt 4800000) "$([int]($FraseDichaVentanaMs/1000)) s"

Write-Host ''
Write-Host '-- 3. y la funcion caduca de verdad --'
$dG = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-FraseComoLaDijiste' }, $true)
Comp 'existe Get-FraseComoLaDijiste' ($null -ne $dG) ''
if ($dG) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Expression $dG.Extent.Text
    $script:fraseComoLaDijiste = $null
    Comp '  sin nada guardado, devuelve vacio' ((Get-FraseComoLaDijiste) -eq '') ''
    $script:fraseComoLaDijiste = @{ texto = 'que habla, dije que cerraras este in'; cuando = $sw.ElapsedMilliseconds }
    Comp '  con algo reciente, lo devuelve' ((Get-FraseComoLaDijiste) -match 'cerraras este in') 'la frase real del 25/09'
    # RANCIA: una frase de hace un minuto ya no habla de esta traduccion
    $script:fraseComoLaDijiste = @{ texto = 'algo viejisimo'; cuando = ($sw.ElapsedMilliseconds - $FraseDichaVentanaMs - 1000) }
    Comp '  y una rancia, no' ((Get-FraseComoLaDijiste) -eq '') "pasada la ventana de $([int]($FraseDichaVentanaMs/1000)) s"
    Comp '    y ademas la tira' ($null -eq $script:fraseComoLaDijiste) 'para que no vuelva a mirarse'
}

Write-Host ''
Write-Host '-- 4. se aprende con ella, y por el mismo filtro --'
$iAprende = $sinCom.IndexOf('Add-Traduccion $original $propuesta')
Comp 'se encuentra donde se aprende' ($iAprende -ge 0) ''
$bloque = if ($iAprende -ge 0) { $sinCom.Substring($iAprende, [Math]::Min(1800, $sinCom.Length - $iAprende)) } else { '' }
Comp '  y tambien con la frase de braya' ($bloque -match 'Add-Traduccion \$dicha \$propuesta') 'las dos apuntan al mismo destino'
# EL FILTRO NO SE AFLOJA: si la frase real es larga o pierde un nombre propio, no se aprende.
# Sin esto, la idea 7 desharia el arreglo del 15/09 que puso ese filtro.
Comp '  pasando por el filtro de las 6 palabras' ($bloque -match '\$palD\.Count -gt 6') 'no se afloja lo que ya protegia'
Comp '  y por el del nombre propio' ($bloque -match 'nombreFueraD') ''
Comp '  y por el del oido dudoso' ($bloque -match 'Test-OidoDudoso \$dicha') 'lo mal oido no se aprende, ni siquiera dicho por braya'
# Y NO SE APRENDE DOS VECES LO MISMO
Comp '  y no repite si son iguales' ($bloque -match '\$dicha -ne \$original') ''
# LO QUE SE EJECUTA NO CAMBIA: solo cambia bajo que nombre se archiva.
Comp '  la orden que se ejecuta sigue siendo la reescrita' ($bloque -match 'Add-Traduccion \$original \$propuesta') 'esto es un anadido, no un cambio de destino'

Write-Host ''
Write-Host '-- 5. contra el registro de verdad --'
$n = 0; $conDicho = 0
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'no era charla sino una orden') {
            $n++
            if ($l -match '\(dicho:') { $conDicho++ }
        }
    }
}
Write-Host ("       $n ordenes sacadas de la charla, $conDicho con una reescritura distinta de lo dicho")
Comp 'el caso existe en el registro' ($conDicho -ge 1) 'no es un caso inventado'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo aprendido lleva tu frase, no la que Nova se reescribio'
exit 0
