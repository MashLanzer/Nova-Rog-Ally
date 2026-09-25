# LA PREGUNTA DE LOS AMIGOS: LO CARO ESTABA HECHO Y NO SE USABA NUNCA (25/09)
#
# EL DATO. Los tres patrones de "amigos conectados" van anclados en ^ y $: exigen que la frase
# EMPIECE por quien/quienes/hay algun amigo/que amigos y ACABE justo ahi. Contado sobre los
# 633 dictados distintos de assistant.log y su rotado, cogen CERO de las tres veces que braya
# lo ha preguntado en catorce dias. Las tres estan aqui abajo, tal como las oyo Nova.
#
# LO QUE COSTO. El 25/09 a las 01:19:52 y a las 01:22:41 la frase acabo en el agente, que abrio
# Steam y pincho la pantalla con el raton: 48,7 s y 70,5 s, contra los ~166 ms de la peticion a
# la API. Y no es que faltara el codigo: Start-AmigoPregunta, Receive-AmigoPregunta y
# Format-AmigosSteam estaban escritos y la clave de Steam puesta desde el 24/09. Solo fallaba
# el patron que lo dispara. Braya se dio cuenta solo a las 01:21:18: "no se supone que tienes
# una API para hacer todo eso".
#
# LO QUE VIGILA ESTE BANCO:
#  1. Que las tres formas reales entren, incluida la que lleva 'team' por Steam mal oido.
#  2. Que la QUEJA de 32 palabras no entre. Es la que obliga al tope de doce palabras, y sin
#     ese tope preguntar por los amigos se dispararia hablando de ellos.
#  3. Que lo de Discord siga yendo a Discord.
#  4. Que no le robe la frase a la vigilancia ("avisame cuando se conecte mi novia").
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# LA RAMA DE VERDAD, sacada del archivo. Se corta entre dos marcas suyas y no contando llaves.
$ini = $fuente.IndexOf("# Y COMO LO DICE BRAYA, QUE NO ES ASI (25/09)")
$fin = if ($ini -ge 0) { $fuente.IndexOf('# HISTORIAL DE MUSICA', $ini) } else { -1 }
if ($ini -lt 0 -or $fin -lt 0) { Write-Host '  MAL  no encuentro la rama de amigos por conceptos'; exit 1 }
$rama = $fuente.Substring($ini, $fin - $ini)
Invoke-Expression ("function Amigos([string]`$f) {`n" + $rama + "`n}")

Write-Host ''
Write-Host '-- 1. LAS TRES FORMAS QUE USA DE VERDAD (y que hoy no cogia ninguna) --'
$reales = @(
    'dime de mis amigos dona steam quien esta conectado',
    'si dime cuales de mis amigos estan conectados en steam',
    'tengo algun amigo conectado en el team'
)
foreach ($r in $reales) {
    $a = @(Amigos $r)
    Comp ('"' + $r.Substring(0, [Math]::Min(48, $r.Length)) + '"') ($a.Count -eq 1 -and $a[0].kind -eq 'amigosSteam') `
        $(if ($a.Count) { "kind=$($a[0].kind)" } else { 'no la coge' })
}

Write-Host ''
Write-Host '-- 2. LA QUEJA DE 32 PALABRAS NO PIDE NADA --'
# Esta frase lleva "amigo" Y "conectado", asi que sin el tope de doce palabras Nova se pondria
# a consultar la API mientras braya se queja de que no la usa.
$queja = 'ok pero porque tuviste que abrir el steam y mirar la pantalla y todo eso para ver que amigo estaba conectado no se supone que tienes una api para hacer todo eso'
Comp 'la queja del 25/09 a las 01:21:18 no dispara nada' (@(Amigos $queja).Count -eq 0) "$(@($queja -split '\s+').Count) palabras"

Write-Host ''
Write-Host '-- 3. DISCORD SIGUE SIENDO DISCORD --'
$aD = @(Amigos 'hay alguien conectado en discord')
Comp 'lo de Discord va a Discord' ($aD.Count -eq 1 -and $aD[0].kind -eq 'amigosDiscord') $(if ($aD.Count) { "kind=$($aD[0].kind)" })

Write-Host ''
Write-Host '-- 4. NO LE ROBA LA FRASE A LA VIGILANCIA --'
# "avisame cuando se conecte mi amigo" arma una vigilancia, que es otra cosa. Dice "conecte",
# no "conectado", y por eso no entra aqui. Si alguien ampliara el patron a "conect\w+" se
# llevaria esa frase por delante y la vigilancia dejaria de armarse sin que nadie lo notara.
# LA FRASE LLEVA "amigo" A PROPOSITO: las dos primeras que puse aqui decian "mi novia" y "mi
# amiga", y ninguna de las dos casa con '\b(?:amigos?|alguien)\b' -"amiga" no es "amigo"-, asi
# que se quedaban fuera por la PRIMERA condicion y no probaban nada de la segunda. La rotura
# de ampliar "conectado" salia VERDE con ellas. Con esta sale roja, que es lo que toca.
foreach ($v in @('avisame cuando se conecte mi amigo', 'dime cuando se conecte algun amigo')) {
    Comp ('sigue sin ser "amigos conectados": "' + $v + '"') (@(Amigos $v).Count -eq 0)
}

Write-Host ''
Write-Host '-- 5. Y QUE LA MAQUINARIA QUE DISPARA SIGA EXISTIENDO --'
# Un patron arreglado que llama a una funcion que ya no esta es peor que el patron roto: la
# frase se reconoce y revienta. Las tres son las que hacen la peticion de verdad.
foreach ($fn in @('Start-AmigoPregunta', 'Receive-AmigoPregunta', 'Format-AmigosSteam')) {
    Comp "$fn sigue en el archivo" ($fuente -match ("(?m)^function\s+" + [regex]::Escape($fn) + "\b"))
}

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'la pregunta de los amigos entra como la dice braya'
exit 0
