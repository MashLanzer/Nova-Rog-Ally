# QUEJARSE CUENTA COMO FALLO AUNQUE NOVA NO SEPA REHACER LA ORDEN (26/09, idea 3 de las 121).
#
# 'fallo-dicho-por-ti' es EL UNICO DATO HUMANO de toda la medicion: es braya diciendo "eso no
# era". Sin el, la meta numero uno -cero ordenes equivocadas- no se puede medir, y el motor de
# decisiones propias se queda sin combustible. Va 0 de 588 ordenes. Cero en toda la vida de Nova.
#
# POR QUE IBA A CERO, medido el 26/09: el unico Write-FalloUso de ese camino vivia DENTRO del
# "if ($corrOk)", o sea que braya solo conseguia marcar una orden como equivocada si ademas
# Nova sabia reconstruir la orden buena Y esa reconstruccion era ejecutable. Y ni siquiera
# llegaba ahi: 'CORRECCION:' sale CERO veces en assistant.log y en assistant.log.1, porque de
# las 64 frases reales que encajan en $RE_QUEJA, Get-OrdenCorregida devuelve algo en CERO.
#
# LO QUE SE ARREGLA son dos cosas distintas:
#   1. Marcar deja de depender de rehacer. Que Nova no sepa reconstruir la orden buena no hace
#      que la anterior fuera buena.
#   2. Una queja que NOMBRA EL ACTO DE PEDIR marca el fallo aunque no salga ninguna orden.
#
# Y LO QUE ESTE BANCO VIGILA SOBRE TODO ES LO SEGUNDO, porque es lo que puede envenenar el
# dato: de las 64 frases que encajan en $RE_QUEJA, SESENTA Y TRES son charla que empieza por
# "no" o "pero". Marcarlas seria meter 63 fallos falsos en la unica senal humana que hay.
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

Write-Host '-- 1. los dos patrones son distintos, y por una razon --'
foreach ($cte in @('RE_QUEJA', 'RE_QUEJA_FUERTE', 'QuejaVentanaMs')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim()) }
}
Comp 'no son el mismo patron' ($RE_QUEJA -ne $RE_QUEJA_FUERTE) 'uno reconoce quejas, el otro decide marcar un fallo'
# EL "no" DE CABEZA NO PUEDE ESTAR EN EL FUERTE: es lo que arrastra las 63 frases de charla.
Comp 'el fuerte NO coge el "no" de cabeza' ($RE_QUEJA_FUERTE -notmatch '\^\(\?:no\|') 'eso es lo que trae 63 frases de charla'
# NI "no es el/la": probado, sube a 4 y tres son charla sobre el juego.
Comp '  ni "no es el/la"' ($RE_QUEJA_FUERTE -notmatch 'no es \(\?:el') '3 de esas 4 son charla sobre el juego'

Write-Host ''
Write-Host '-- 2. el fuerte coge lo que tiene que coger --'
$f = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'ConvertTo-Plain' }, $true)
if (-not $f) { Comp 'se saca ConvertTo-Plain del arbol' $false ''; exit 1 }
Invoke-Expression $f.Extent.Text
# LAS DE VERDAD: braya nombrando lo que pidio. Estas SI marcan.
foreach ($q in @('no te pedi eso, te pedi que abrieras los ajustes',
                 'yo no dije eso',
                 'lo que dije fue que cerraras steam',
                 'te dije que bajaras el volumen',
                 'por que no abriste el navegador')) {
    Comp ("marca: '" + $q + "'") ((ConvertTo-Plain $q) -match $RE_QUEJA_FUERTE) ''
}
Write-Host ''
Write-Host '-- 3. y NO coge la charla que empieza por no (las 63) --'
# ESTAS SON FRASES REALES de pruebas\audio\uso\destinos.jsonl, copiadas tal cual. Son las que
# encajan en $RE_QUEJA y NO deben marcar nada: no son quejas a Nova.
foreach ($c in @('No veo una ciencia',
                 'No, no estaba hablando contigo',
                 'No lo estas haciendo mal, la IA lo va a revisar',
                 'No, No',
                 'No, este es otro juego, no es el de Roblox',
                 'No, no es el timing, es literalmente que esta mal hecho el juego',
                 'Pero la pregunta tiene que salirme despues de eso',
                 'No, quiero saber que se esta descargando en Steam')) {
    $pl = ConvertTo-Plain $c
    Comp ("no marca: '" + $c.Substring(0, [Math]::Min(46, $c.Length)) + "'") ($pl -notmatch $RE_QUEJA_FUERTE) $(
        if ($pl -match $RE_QUEJA) { 'si encaja en RE_QUEJA, como debe' } else { '' })
}

Write-Host ''
Write-Host '-- 4. y el codigo lo usa donde toca --'
# EL BLOQUE SE DELIMITA CON CODIGO, NO CON UN COMENTARIO (26/09, lo cazo este banco a la
# primera). La primera version buscaba el comentario "LAS QUEJAS REHACEN LA ORDEN" dentro de
# $sinCom, que es precisamente el texto CON LOS COMENTARIOS QUITADOS: no lo encontraba nunca,
# se caia al fallback y cogia un trozo que empezaba despues de la guarda, asi que dos
# comprobaciones salian rojas con el codigo perfectamente bien.
$iQ = $sinCom.IndexOf('if (-not $script:corrigiendo -and -not $script:pendiente')
Comp 'se encuentra el camino de la queja' ($iQ -ge 0) ''
if ($iQ -lt 0) { Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
$iFin = $sinCom.IndexOf('AJEDREZ A CIEGAS', $iQ)
if ($iFin -lt 0) { $iFin = [Math]::Min($sinCom.Length, $iQ + 3000) }
$bloque = $sinCom.Substring($iQ, $iFin - $iQ)
Comp 'el camino mira RE_QUEJA_FUERTE' ($bloque -match 'RE_QUEJA_FUERTE') ''
Comp '  y marca el fallo con Write-FalloUso' ($bloque -match 'Write-FalloUso') ''
# LO QUE SE ARREGLA: que marcar NO dependa de que la reconstruccion sea ejecutable.
$nFallo = @([regex]::Matches($bloque, 'Write-FalloUso')).Count
Comp '  desde DOS sitios, no solo tras reconstruir' ($nFallo -ge 2) "$nFallo llamadas: la queja fuerte y la correccion"
# Y LA PRUEBA QUE IMPORTA: que ninguna de las dos este dentro del if de "se puede ejecutar".
$iOk = $bloque.IndexOf('if ($corrOk)')
$iUltimoFallo = $bloque.LastIndexOf('Write-FalloUso')
Comp '  y ninguna cuelga de "se puede ejecutar"' ($iOk -lt 0 -or $iUltimoFallo -lt $iOk) 'marcar no es rehacer'
# LA VENTANA, DE LA CONSTANTE Y NO A MANO
Comp '  la ventana sale de la constante' ($bloque -match 'QuejaVentanaMs') "$([int]($QuejaVentanaMs/1000)) s"

Write-Host ''
Write-Host '-- 5. contra las frases de verdad, todas de golpe --'
# LA PRUEBA MAS HONESTA: las 432 frases con texto que Nova ha oido de verdad. Si el patron
# fuerte cogiera muchas, estaria envenenando el dato humano; si cogiera cero, no serviria.
$dest = Join-Path $raiz 'pruebas\audio\uso\destinos.jsonl'
if (Test-Path -LiteralPath $dest) {
    $vistas = @{}
    $nQ = 0; $nF = 0
    foreach ($l in @(Get-Content -LiteralPath $dest -Encoding UTF8)) {
        $o = $null
        try { $o = $l | ConvertFrom-Json } catch { continue }
        if (-not $o.detalle) { continue }
        $k = [string]$o.id + '|' + [string]$o.detalle
        if ($vistas.ContainsKey($k)) { continue }
        $vistas[$k] = $true
        $pl = ConvertTo-Plain ([string]$o.detalle)
        if ($pl -match $RE_QUEJA) { $nQ++ }
        if ($pl -match $RE_QUEJA_FUERTE) { $nF++ }
    }
    Write-Host ("       de $($vistas.Count) frases reales: $nQ encajan en RE_QUEJA y $nF en el fuerte")
    Comp 'el fuerte marca alguna' ($nF -ge 1) 'si fuera cero, esto no serviria para nada'
    # EL LISTON: mas de un 10 % de las quejas seria empezar a marcar charla. Hoy va 1 de 64.
    Comp '  y no se pasa marcando charla' ($nF -le [Math]::Max(3, [int]($nQ * 0.10))) "$nF de $nQ; el tope es el 10 %"
} else {
    Write-Host '       (no hay destinos.jsonl: no se puede medir contra frases reales)'
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  quejarse marca la orden, sepa o no rehacerla'
exit 0
