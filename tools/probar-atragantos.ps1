# LA TABLA DE LO QUE MAS SE LE ATRAGANTA TENIA TRES FILAS Y NINGUNA ERA UNA ORDEN (27/09, idea 88)
#
# LAS TRES FILAS QUE HABIA en memoria\estadisticas.md: "avisame cuando la descarga de Steam termino"
# -que llegaba a 2 solo porque una tilde hizo que la lista de descartes guardara dos copias-, "dictado
# vacio" -que es la ETIQUETA interna del contador 'error', no algo que braya dijera, y la tabla le
# pedia que se lo ensenara a Nova- y "maar die dog komen beheer", holandes de un video de fondo.
#
# Y NO ERA MALA SUERTE: por texto exacto no hay nada que encontrar. La lista 'recientes' cubre TREINTA
# Y OCHO MINUTOS (25/09 de 23:16 a 23:54), la de descartes borra la entrada identica al reanadir -asi
# que una frase no puede contar mas de 1 por ahi- y en los datos de uso hay 34 frases que acabaron en
# nada y las 34 son distintas entre si.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que 'error' NO entre en la tabla (su detalle es una etiqueta interna)
#   2. que dos formas de la misma orden mal oida caigan en el MISMO grupo
#   3. que dos ordenes DISTINTAS no se junten
#   4. que el texto crudo de cada forma se siga viendo, que es la guarda de agrupar por parecido
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
# Test-MismoSonido FALTABA, y con ella faltaba MEDIA SECCION (30/09). Get-DistanciaFon la llama una
# vez por celda de su matriz; sin traerla, la llamada lanzaba, el 'catch { $dFon = 1.0 }' de
# Get-Atragantos lo tragaba en silencio y la rama FONETICA del agrupado -la que junta 'stein' con
# 'steam', la mitad de lo que esta seccion dice vigilar- no se ejercitaba NUNCA. Lo destapo un caso
# nuevo que esperaba que 'bun il mudu nuchi' cayera con 'pon el modo noche': el propio codigo mide
# ese par en 0,206 por fonetica, dentro del tope, y aqui salian dos grupos.
# Es la manera 14 (una lista de funciones a mano caduca) con la 10 encima (un catch que devuelve un
# valor legitimo y tapa el fallo): 1.0 es "no se parecen", que es una respuesta valida.
foreach ($f in @('ConvertTo-Plain', 'Get-Distancia', 'Get-ClaveSonido', 'Test-MismoSonido', 'Get-DistanciaFon', 'Get-Atragantos')) {
    Invoke-Expression (Traer $f)
}
# Y LA TABLA DE SONIDOS, QUE NO ES UNA FUNCION Y POR ESO SE OLVIDABA (30/09). Test-MismoSonido
# recorre $script:GruposFon; sin ella el foreach no itera nada, devuelve False SIEMPRE, y entonces
# Get-DistanciaFon vale exactamente lo mismo que Get-Distancia por el doble. El Min() de
# Get-Atragantos se queda siempre con la de letras y la mitad fonetica del agrupado -justo la que
# junta 'stein' con 'steam'- no se ejercita en este banco.
# COMPROBADO sacandola del AST: con ella, 'pon el modo noche' contra 'bun il mudu nuchi' da 0,206
# por fonetica y agrupa; sin ella da 0,412 y no agrupa. Es el numero que el propio codigo documenta.
# SE SACA DEL ARBOL, no con un regex sobre el texto: una lista escrita a mano aqui caducaria igual.
$asigFon = $ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left.Extent.Text -eq '$script:GruposFon' }, $true) | Select-Object -First 1
Comp 'se encuentra la tabla de grupos foneticos' ($null -ne $asigFon) 'sin ella la mitad fonetica no se prueba'
if ($asigFon) { Invoke-Expression $asigFon.Extent.Text }
Comp '  y trae los grupos de verdad' (@($script:GruposFon).Count -ge 9) "$(@($script:GruposFon).Count) grupos"
Comp '  y dos letras que suenan igual lo dicen' ((Test-MismoSonido 'b' 'v') -and (Test-MismoSonido 'i' 'e')) 'b/v e i/e'
Comp '  y dos que no, tampoco' (-not (Test-MismoSonido 'a' 'z')) 'a/z no suenan igual'
$txt = [IO.File]::ReadAllText($PS1)
$AtraganteDistMax = 0.34
Comp 'el liston de parecido sale del archivo' ($txt -match '\$AtraganteDistMax = 0\.34') 'un tercio de la frase'

$script:stats = $null
function Get-Estadisticas { return $script:stats }
function Reset([string[]]$descartes, [string[]]$recientes) {
    $script:stats = @{ dias = @{}; descartes = @($descartes); recientes = @($recientes); decisiones = @() }
}

Write-Host ''
Write-Host '-- 1. EL "dictado vacio" YA NO ENTRA --'
Reset @() @('2026-09-25 23:16  [error]  dictado vacio',
            '2026-09-25 23:20  [error]  dictado vacio',
            '2026-09-25 23:30  [error]  cancelado')
$a1 = @(Get-Atragantos)
Comp '1a. la tabla queda vacia' ($a1.Count -eq 0) ([string]$a1.Count + ' filas')
Comp '1b. y el switch ya no tiene la rama de error' (-not ((Traer 'Get-Atragantos') -match "'error'\s+\{ 'acabo en error' \}")) 'era la fila que le pedia ensenar "dictado vacio"'

Write-Host ''
Write-Host '-- 2. LO QUE SI ES UNA ORDEN DE BRAYA SIGUE ENTRANDO --'
Reset @('2026-09-25  abre el disco duro') @('2026-09-25 23:16  [traducir]  pon la musica de pitbull')
$a2 = @(Get-Atragantos)
Comp '2a. las dos entran' ($a2.Count -eq 2) ([string]$a2.Count)
Comp '2b. con lo que paso' ((@($a2 | Where-Object { $_.rutas -contains 'no lo entendi' }).Count -eq 1) -and
                            (@($a2 | Where-Object { $_.rutas -contains 'tuve que preguntarle al modelo' }).Count -eq 1)) ''

Write-Host ''
Write-Host '-- 3. DOS FORMAS DE LA MISMA ORDEN, UN SOLO GRUPO --'
# el caso de verdad: la misma frase oida de tres formas, que por texto exacto contaban 1 cada una
Reset @('2026-09-25  avisame cuando la descarga de steam termino',
        '2026-09-24  avisame cuando la descarga de steam termine',
        '2026-09-23  avisame cuando la descarga de stim termine') @()
$a3 = @(Get-Atragantos)
Comp '3a. las tres caen en un grupo' ($a3.Count -eq 1) ([string]$a3.Count + ' grupos')
Comp '3b. que cuenta 3 veces y no 1' ($a3[0].veces -eq 3) ([string]$a3[0].veces)
Comp '3c. y guarda las otras dos formas' (@($a3[0].variantes).Count -eq 2) ([string]@($a3[0].variantes).Count + ': ' + (@($a3[0].variantes) -join ' | '))
Comp '3d. con su texto crudo, sin tocar' (@($a3[0].variantes | Where-Object { $_ -match 'stim' }).Count -eq 1) 'asi braya ve si el grupo es falso'

Write-Host ''
Write-Host '-- 4. DOS ORDENES DISTINTAS NO SE JUNTAN --'
Reset @('2026-09-25  pon musica de pitbull', '2026-09-24  cierra el navegador y apaga la pantalla') @()
$a4 = @(Get-Atragantos)
Comp '4a. siguen siendo dos' ($a4.Count -eq 2) ([string]$a4.Count)
Comp '4b. y ninguna arrastra variantes' ((@($a4 | Where-Object { @($_.variantes).Count -gt 0 }).Count -eq 0)) ''

Write-Host ''
Write-Host '-- 5. LO QUE NO ES UNA FRASE NO CUENTA --'
Reset @('2026-09-25  si', '2026-09-24  nova', '2026-09-23  a') @()
$a5 = @(Get-Atragantos)
Comp '5a. una palabra suelta nunca entra' ($a5.Count -eq 0) 'casi siempre es ruido, no una orden'

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '6a. se agrupa con las dos distancias que ya existen' ($sinCom -match '(?s)Get-Distancia \$k \$otra.{0,300}Get-DistanciaFon \$k \$otra') 'las dos ya tienen banco'
Comp '6b. normalizadas por el largo de la frase' ($sinCom -match '\$largo = \[Math\]::Max\(\$k\.Length, \$otra\.Length\)') 'tres letras no pesan igual en una frase corta'
Comp '6c. la tabla del markdown ensena las variantes' ($sinCom -match 'tambien: \$v') ''
Comp '6d. y hablando se dice cuantas, sin recitarlas' ($sinCom -match 'formas parecidas') 'tres variantes dichas en voz alta son ruido'

Write-Host ''
Write-Host '-- 7. LO QUE COSTABA CINCUENTA SEGUNDOS DEL BUCLE (30/09) --'
# EL CASO: braya pulso el boton y Nova tardo TREINTA SEGUNDOS en activarse. Medido: una vuelta de
# ~51 s cada ~82 s, sorda el 63 % del tiempo, con la vuelta mediana en 47 ms. El coste estaba aqui:
# el agrupado por parecido es O(n^2) y arma DOS matrices de Levenshtein en PowerShell por pareja.
# Reproducido con los 30 descartes y 40 recientes de verdad: 49.859 ms. Con el prefiltro de largos
# baja a 15.007 ms, y con la cache la segunda llamada cuesta 1 ms.
# SE CUENTAN LAS COMPARACIONES, NO LOS MILISEGUNDOS: un banco atado al reloj se pone rojo en una
# maquina cargada y verde en una rapida, y lo que hay que vigilar es que no se vuelva a calcular
# lo que ya se sabe, no cuanto tarda esta consola hoy.
$script:vecesDist = 0
# LA ORIGINAL SE COPIA CON OTRO NOMBRE, y el contador llama a esa. Envolverla cogiendo
# 'Get-Item function:Get-Distancia' se come la pila: al redefinirla, la referencia apunta a la
# nueva y se llama a si misma. Pasa en el primer intento de escribir esto.
Invoke-Expression ((Traer 'Get-Distancia') -replace 'function Get-Distancia', 'function Get-DistanciaReal')
function Get-Distancia([string]$a, [string]$b) { $script:vecesDist++; return (Get-DistanciaReal $a $b) }

# 7a. EL PREFILTRO: dos frases con largos muy distintos no pueden parecerse, y no se calculan.
# 'abre steam' (10) contra una de 60: la diferencia de largos ya pasa del tope de 0,34.
Reset @('2026-09-30  abre steam',
        '2026-09-30  oye nova abreme el steam y ponme la musica de siempre en spotify anda') @()
$script:vecesDist = 0
$a7 = @(Get-Atragantos)
Comp '7a. dos largos muy distintos no se comparan' ($script:vecesDist -eq 0) "$($script:vecesDist) matrices (antes: 1 por pareja)"
Comp '7b.   y siguen siendo dos grupos distintos' ($a7.Count -eq 2) "$($a7.Count) grupos"

# 7c. Y LO PARECIDO SI SE COMPARA: el prefiltro no puede cargarse el agrupado.
Reset @('2026-09-30  pon el modo noche', '2026-09-30  bun il mudu nuchi') @()
$script:vecesDist = 0
$a7b = @(Get-Atragantos)
Comp '7c. lo parecido si se compara' ($script:vecesDist -ge 1) "$($script:vecesDist) matrices"
Comp '7d.   y cae en un solo grupo' ($a7b.Count -eq 1) "$($a7b.Count) grupo(s)"

# 7e. LA CACHE: con los mismos datos, la segunda llamada no vuelve a comparar nada.
$script:vecesDist = 0
$a7c = @(Get-Atragantos)
Comp '7e. repetir con los mismos datos no recalcula' ($script:vecesDist -eq 0) "$($script:vecesDist) matrices en la 2a llamada"
Comp '7f.   y devuelve lo mismo' ($a7c.Count -eq $a7b.Count) "$($a7c.Count) vs $($a7b.Count)"

# 7g. Y EL SELLO TIENE QUE SER DEL CONTENIDO, no "cuantas hay y la ultima". Estas dos listas tienen
# el MISMO numero de entradas y el MISMO ultimo elemento, y son distintas: con un sello flojo, la
# cache devolveria la tabla de la anterior. Me paso escribiendo el arreglo, asi que queda vigilado.
Reset @('2026-09-30  pon el modo noche', '2026-09-30  bun il mudu nuchi') @()
$antes7 = @(Get-Atragantos).Count
Reset @('2026-09-30  cierra el discord ahora', '2026-09-30  bun il mudu nuchi') @()
$des7 = @(Get-Atragantos)
Comp '7g. dos listas con igual cuenta y final no comparten cache' ($des7.Count -eq 2) "$($des7.Count) grupos (con sello flojo salia $antes7)"

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la tabla de atragantos agrupa por parecido y ya no ensena etiquetas internas' -ForegroundColor Green
exit 0
