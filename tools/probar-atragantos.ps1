# LA TABLA DE LO QUE MAS SE LE ATRAGANTA TENIA TRES FILAS Y NINGUNA ERA UNA ORDEN (27/09, idea 88)
#
# LAS TRES FILAS QUE HABIA en memoria\estadisticas.md: «avisame cuando la descarga de Steam termino»
# -que llegaba a 2 solo porque una tilde hizo que la lista de descartes guardara dos copias-, «dictado
# vacio» -que es la ETIQUETA interna del contador 'error', no algo que braya dijera, y la tabla le
# pedia que se lo ensenara a Nova- y «maar die dog komen beheer», holandes de un video de fondo.
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
foreach ($f in @('ConvertTo-Plain', 'Get-Distancia', 'Get-ClaveSonido', 'Get-DistanciaFon', 'Get-Atragantos')) {
    Invoke-Expression (Traer $f)
}
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
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la tabla de atragantos agrupa por parecido y ya no ensena etiquetas internas' -ForegroundColor Green
exit 0
