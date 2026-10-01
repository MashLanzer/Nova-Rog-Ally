# EL MOTOR QUE SE DESCARTO YA HABIA OIDO LA PALABRA BUENA (26/09, idea 25 de las 121).
#
# Cada orden la oyen TRES motores -Vosk, Parakeet y a veces Whisper- y Nova se queda con uno.
# Los otros dos se escriben en tmp\dictado-oidos.txt y hasta hoy solo los leia la NUBE, cuando
# ya se habia decidido mandar la frase fuera.
#
# MEDIDO sobre las 560 ordenes de registro.jsonl con las tres transcripciones guardadas: en 17
# -el 3,0 %- la entregada NO empieza por un verbo de la lista $VERBOS y la de Vosk SI. Leidas
# una a una, en QUINCE de esas 17 la de Vosk era la buena:
#     'Su volumen cincuenta por ciento'  <- vosk 'sube el volumen cincuenta porciento'
#     'Y es un navegador'                <- vosk 'cierra el navegador'
#     'Here the glove'                   <- vosk 'abre teclado'
#
# Y EL SITIO ESTA MEDIDO TAMBIEN: puesto delante del filtro de ruido se cubren los 17; puesto
# delante de la nube, como decia la idea, se pierden TRES -el 18 %- porque mueren antes en ese
# filtro por tener una o dos palabras ('Sierra Gul', 'Seattle Navegador', 'Haber team').
#
# LO QUE ESTE BANCO VIGILA MAS QUE NADA, y es la regla 1 de la casa: que la candidata SOLO se
# pruebe cuando la entregada no ha resuelto nada. Si se probara siempre, un 'abre steam' que ya
# funciono podria acabar ejecutando el 'cierra todos los programas' que oyo otro motor.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$fuente = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
            $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}

Write-Host '-- 1. Get-OtrosOidos, EJECUTADA, con y sin el interruptor --'
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Get-OtrosOidos')
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('oidos-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
function Pon { [IO.File]::WriteAllLines($tmp, [string[]]@(
        'parakeet: y es un navegador', 'whisper: y es navegador', 'vosk: cierra el navegador')) }
try {
    Pon
    $cr = @(Get-OtrosOidos -principal 'Y es un navegador' -ruta $tmp -Crudo)
    # SIN EL PREFIJO, Y ESTA ES LA COMPROBACION QUE DECIDE SI LA IDEA SIRVE DE ALGO: si -Crudo
    # devolviera 'vosk: cierra el navegador', Test-FastCommand no aceptaria NUNCA una candidata
    # y todo esto se quedaria muerto en verde.
    Comp 'con -Crudo, los textos vienen limpios' ($cr -contains 'cierra el navegador') (($cr -join ' | '))
    Comp '  sin el nombre del motor delante' (-not (@($cr) | Where-Object { $_ -match '^[a-z-]+:' })) ''
    # Y NO SE BORRA: quien pregunta va a probarlas en local y, si ninguna sirve, la frase sigue
    # su camino hasta la nube, que es quien de verdad las consume.
    Comp '  y el fichero sigue ahi' (Test-Path -LiteralPath $tmp) 'la nube las necesita despues'
    # LA QUE YA SE PROBO NO ES UNA SEGUNDA OPINION
    Comp '  y la que ya se dijo no se devuelve' (-not ($cr -contains 'y es un navegador')) ''
    Comp '  ni se repite ninguna' (@($cr).Count -eq @($cr | Select-Object -Unique).Count) ''

    # SIN EL INTERRUPTOR, TODO COMO SIEMPRE. Es lo que vigila probar-segunda-oreja.
    Pon
    $blo = Get-OtrosOidos -principal 'Y es un navegador' -ruta $tmp
    Comp 'sin -Crudo, sigue saliendo el bloque para la nube' ($blo -match 'MISMA frase' -and $blo -match 'IGNORA') ''
    Comp '  con el nombre del motor, que ahi si hace falta' ($blo -match 'vosk: cierra el navegador') ''
    Comp '  y el fichero SI se consume' (-not (Test-Path -LiteralPath $tmp)) 'unas candidatas viejas contestarian a lo de antes'
    # SIN FICHERO NO SE INVENTA NADA
    Comp 'sin fichero, con -Crudo no da nada' (@(Get-OtrosOidos -principal 'x' -ruta $tmp -Crudo).Count -eq 0) ''
    Comp '  y sin -Crudo, cadena vacia' ((Get-OtrosOidos -principal 'x' -ruta $tmp) -eq '') ''
} finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '-- 2. TODO EL CODIGO NUEVO VIVE DENTRO DE Get-OtrosOidos --'
# probar-segunda-oreja la saca del arbol y la EJECUTA SOLA, con solo ConvertTo-Plain al lado.
# Una funcion auxiliar nueva la mataria con CommandNotFoundException, y ese banco saldria
# "el banco se rompio" por algo que no es el fallo.
$cuerpoG = Traer 'Get-OtrosOidos'
$llamadas = @([regex]::Matches($cuerpoG, '(?m)[^-\w]((?:Get|Split|Read|Parse)-[A-Z][A-Za-z]*)') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$permitidas = @('Get-Content', 'Get-OtrosOidos')
$sobra = @($llamadas | Where-Object { $permitidas -notcontains $_ })
Comp 'no llama a ninguna auxiliar nueva' ($sobra.Count -eq 0) (($sobra -join ', '))

Write-Host ''
Write-Host '-- 3. EL BLOQUE: solo cuando la entregada no resolvio --'
$iB = $sinCom.IndexOf('$candsO = @(Get-OtrosOidos -principal $text -ruta $RutaOidos -Crudo)')
Comp 'el bloque existe y pide las candidatas' ($iB -ge 0) ''
# CON NOMBRES Y NO POR POSICION: probar-segunda-oreja busca la cadena literal
# 'Get-OtrosOidos $text' para comprobar que la llamada de la nube esta bajo 'traducir'. Si esta
# se escribiera igual, ese banco podria mirar el bloque equivocado y aprobar lo que no es.
Comp '  con los parametros por nombre' ($sinCom -notmatch 'Get-OtrosOidos \$text \$RutaOidos') (
    'si no, probar-segunda-oreja mira el bloque equivocado')
$iFin = $sinCom.IndexOf('$palabras = @(($text -split ', [Math]::Max(0, $iB))
$blB = if ($iB -ge 0 -and $iFin -gt $iB) { $sinCom.Substring($iB, $iFin - $iB) } else { '' }
Comp '  y se lee entero, hasta el filtro de ruido' ($blB -ne '') ''
# ESTA ES LA GUARDA DE LA REGLA 1: el bloque vive DENTRO del else, detras de la rama que SI
# ejecuta. Si la entregada resolvio, aqui no se llega nunca.
$iFast = $sinCom.IndexOf('$fast = Invoke-FastCommand $text')
$iTrad = $sinCom.IndexOf('# 3) ')
Comp 'va DETRAS de la orden local' ($iFast -ge 0 -and $iB -gt $iFast) 'si la entregada resolvio, aqui no se llega'
$iRec = $sinCom.IndexOf('$recInc = $null')
Comp '  y detras de las traducciones y las recetas' ($iRec -ge 0 -and $iB -gt $iRec) (
    'lo que braya enseno a mano vale mas que la adivinanza de otro motor')
$iRuido = $sinCom.IndexOf('Log "RUIDO descartado (no llega al agente)')
# EL $iB TAMBIEN SE EXIGE (manera 18): si el bloque dejara de existir, $iB seria -1, y -1 es MENOR
# que cualquier indice valido, asi que esta linea saldria VERDE justo cuando ha dejado de ver lo que
# vigila. Al comparar orden hacen falta los DOS indices, no solo uno.
Comp '  pero DELANTE del filtro de ruido' ($iRuido -ge 0 -and $iB -ge 0 -and $iB -lt $iRuido) (
    'puesto detras se pierden 3 de los 17, el 18 %')

Write-Host ''
Write-Host '-- 4. y no hace nada que no se le haya pedido --'
Comp 'la primera que resuelve, y para' ($blB -match 'if \(\$okO\) \{ \$candO = \$cO; break \}') ''
Comp '  y el filtro es Test-FastCommand, sin liston propio' ($blB -match 'Test-FastCommand \$cO') ''
# CON LA VOZ RARA O EL DICTADO DUDOSO SE PREGUNTA: esto es adivinar de segunda mano.
# NO BASTA CON QUE LA LINEA EXISTA: lo destapo una rotura que salio verde. Cambiando el
# "if ($dudosoO)" por "if ($false)" la asignacion se queda escrita y el -match seguia casando.
# Hay que mirar la DECISION.
Comp 'con la voz rara, pregunta antes' ($blB -match '\$dudosoO = \[bool\]\(Test-VozExtrana\)') ''
Comp '  y con el dictado dudoso, tambien' ($blB -match 'Test-DictadoDudoso') ''
function EnOrden([string]$t, [string]$a, [string]$b) {
    $ma = [regex]::Match($t, $a); if (-not $ma.Success) { return $false }
    return [regex]::Match($t.Substring($ma.Index + $ma.Length), $b).Success
}
Comp '  y ese "dudoso" decide de verdad' (EnOrden $blB 'if \(\$dudosoO\) \{' 'Start-Confirmacion') 'la variable suelta no frena nada'
# Y SI LA PROPIA ORDEN ARMA UNA PREGUNTA, no se da por hecha.
Comp '  y si la orden arma una pregunta, se pregunta' ($blB -match 'if \(\$script:pendiente\) \{') ''
# EN CONVERSACION NO: una respuesta corta en mitad de una charla no es una orden fallida.
$iGuarda = $sinCom.LastIndexOf('if (-not ($script:enSeguimiento and', [Math]::Max(0, $iB))
$mGuarda = [regex]::Match($sinCom.Substring([Math]::Max(0, $iB - 400), [Math]::Min(400, $iB)),
    'if \(-not \(\$script:enSeguimiento -and \(\$sw\.ElapsedMilliseconds - \$script:charlaUltima\) -lt 60000\)\)')
Comp 'en plena conversacion no se mete' ($mGuarda.Success) (
    'los 60 s son los que ya usa el filtro de ruido, no un numero nuevo')
# NUNCA A LA NUBE: si la candidata no resuelve en local, se calla y sigue el camino de siempre.
Comp 'y NUNCA manda nada fuera' ($blB -notmatch 'Submit-Command') 'si no resuelve en local, se calla'
# QUEDA DICHO Y CONTADO
# LAS DOS RAMAS dicen "OTRO OIDO", la que pregunta y la que ejecuta. Se pide la frase que solo
# dice la que ejecuta, o borrarla no se nota.
Comp 'queda dicho en el log' ($blB -match 'no la entendi; otro motor habia oido') ''
Comp '  y contado' ($blB -match "Add-Estadistica 'otro-oido'") ''
# Y SE DICE QUE SE ENTENDIO OTRA COSA: braya tiene que poder oir que Nova adivino.
Comp '  y te dice que entendio otra cosa' ($blB -match 'que es lo que entendi') (
    'adivinar en silencio seria peor que no adivinar')
# LAS CANDIDATAS SE CONSUMEN al ejecutar: si no, quedarian para la orden siguiente.
Comp '  y las candidatas se gastan al usarlas' ($blB -match 'Remove-Item -LiteralPath \$RutaOidos') ''

Write-Host ''
Write-Host '-- 5. contra el registro de verdad --'
$n = 0
$reg = Join-Path $raiz 'pruebas\audio\uso\registro.jsonl'
if (Test-Path -LiteralPath $reg) {
    foreach ($l in [IO.File]::ReadAllLines($reg)) { if ($l -match '"entregado"') { $n++ } }
}
Write-Host ("       $n ordenes con las tres transcripciones guardadas; en 17 la de Vosk empezaba por verbo y la entregada no")
Comp 'hay ordenes con las que medir esto' ($n -ge 300) ''

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que oyo el otro motor se prueba antes de rendirse'
exit 0
