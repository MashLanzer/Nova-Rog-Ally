# LAS CORRECCIONES DE OIDO SE GANAN DEL USO (27/09, idea 87 de las 121)
#
# EL DATO: commands.json lleva 110 correcciones foneticas escritas a mano. Cruzadas con los 941
# dictados de los dos registros, solo NUEVE han aparecido alguna vez en algo que Nova oyera; las otras
# 101 no se han usado nunca. Y las que SI pasan no estan: en las 560 ordenes reales salen 12
# sustituciones distintas en la cabeza de la frase ('su'/'tuvo'/'subo' por 'sube', 'haben'/'haber' por
# 'abre', 'seattle'/'si es' por 'cierra'). La tabla $VERBOS_OIDOS tiene seis entradas, tambien a mano.
#
# LO QUE ESTE BANCO PROTEGE, y el primero es el caso 'ajutos' que ya mordio una vez:
#   1. que NO se aprenda a atar una orden a un fallo del micro: el bueno tiene que ser un verbo que
#      Nova ya usa, el malo no puede ser nada que ya signifique algo, ni parecerse a un verbo
#   2. que hagan falta DOS testigos de FUENTES distintas (la correccion hablada y Vosk)
#   3. que lo escrito a mano por braya siga mandando sobre lo aprendido
#   4. que se pueda quitar
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
foreach ($f in @('ConvertTo-Plain', 'Get-Distancia', 'Get-OidoAprendido', 'Save-OidoAprendido',
                 'Test-PuedeAprenderOido', 'Add-TestigoOido', 'Remove-OidoAprendido',
                 'Get-VerbosAprendidos', 'Repair-Verb')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$OidoTestigosMin = 2
$OidoAprendidoMax = 60
Comp 'hacen falta dos testigos' ($txt -match '\$OidoTestigosMin = 2') ''
Comp 'y la lista tiene tope' ($txt -match '\$OidoAprendidoMax = 60') ''

# el mundo de mentira, DESPUES de cargar
$VERBOS_LISTA = @('abre', 'cierra', 'pon', 'sube', 'baja', 'lee', 'busca', 'pausa', 'silencia', 'pega')
$VERBOS_OIDOS = @{ 'sierra' = 'cierra'; 'aure' = 'abre' }
$VERBOS_IMPERATIVO = @{ 'abreme' = 'abre' }
$cmds = $null
function Test-NombreConocido([string]$t) { return ($t -eq 'steam' -or $t -eq 'spotify') }
$script:logs = @()
$script:invitado = $false
function Log([string]$msg) { $script:logs += @($msg) }
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { }
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-oido-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $MemoriaDir -Force | Out-Null
$OidoAprendidoPath = Join-Path $MemoriaDir 'oido-aprendido.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$ruta, [string]$contenido) { [IO.File]::WriteAllText($ruta, $contenido, $UTF8) }
function Reset {
    $script:oidoAprendido = $null
    $script:logs = @()
    if (Test-Path -LiteralPath $OidoAprendidoPath) { Remove-Item -LiteralPath $OidoAprendidoPath -Force }
}

try {
    Write-Host ''
    Write-Host '-- 1. EL CASO ajutos: LO QUE NO SE PUEDE APRENDER --'
    Reset
    Comp '1a. el bueno tiene que ser un verbo que Nova usa' (-not (Test-PuedeAprenderOido 'si es' 'ajutos')) 'si no, el ruido inventa ordenes'
    Comp '1b. el malo no puede ser ya un verbo' (-not (Test-PuedeAprenderOido 'pega' 'abre')) '"pega" sale del altavoz todo el rato'
    Comp '1c. ni estar ya en la tabla escrita' (-not (Test-PuedeAprenderOido 'sierra' 'abre')) 'lo de braya manda'
    Comp '1d. ni ser una app o un juego conocido' (-not (Test-PuedeAprenderOido 'steam' 'abre')) ''
    Comp '1e. ni parecerse a un verbo de verdad' (-not (Test-PuedeAprenderOido 'abra' 'cierra')) 'para eso ya esta la distancia de Repair-Verb'
    Comp '1f. ni ser una palabra de dos letras' (-not (Test-PuedeAprenderOido 'su' 'sube')) 'demasiado corto para atarlo'
    Comp '1g. ni llevar un espacio dentro' (-not (Test-PuedeAprenderOido 'si es' 'cierra')) 'aqui solo se cambia la cabeza, una palabra'
    Comp '1h. y una palabra nueva que suena a otra cosa, SI' (Test-PuedeAprenderOido 'haben' 'abre') ''

    Write-Host ''
    Write-Host '-- 2. DOS TESTIGOS, Y DE FUENTES DISTINTAS --'
    Reset
    Comp '2a. el primer testigo no basta' (-not (Add-TestigoOido 'haben' 'abre' 'correccion')) ''
    Comp '2b. y lo dice' (@($script:logs | Where-Object { $_ -match 'primer testigo' }).Count -eq 1) ''
    Comp '2c. el MISMO camino otra vez no cuenta' (-not (Add-TestigoOido 'haben' 'abre' 'correccion')) 'dos veces el mismo testigo es uno'
    Comp '2d. otra fuente SI' (Add-TestigoOido 'haben' 'abre' 'vosk') ''
    Comp '2e. y entonces ya vale' ((Get-VerbosAprendidos)['haben'] -eq 'abre') ''
    Comp '2f. y se dice en el registro' (@($script:logs | Where-Object { $_ -match 'ya vale por' }).Count -eq 1) ''
    # y si el segundo testigo dice OTRA cosa, no cuenta
    Reset
    $null = Add-TestigoOido 'haben' 'abre' 'correccion'
    Comp '2g. un testigo que dice otra palabra no suma' (-not (Add-TestigoOido 'haben' 'cierra' 'vosk')) ''
    # NI UNA VISITA PUEDE ENSENARLE (27/09): lo pidio el trinquete de probar-invitado.ps1, y es la
    # que mas importa de las siete que cazo: una correccion de oido cambia como Nova entiende
    # TODAS las ordenes de braya a partir de entonces, no solo la frase que dijo el invitado.
    Reset
    $script:invitado = $true
    Comp '2h. en modo invitado no hay testigo' (-not (Add-TestigoOido 'haben' 'abre' 'correccion')) ''
    Comp '  ni se escribe nada' (-not (Test-Path -LiteralPath $OidoAprendidoPath)) 'lo que diga otro no se queda'
    $script:invitado = $false

    Write-Host ''
    Write-Host '-- 3. LO APRENDIDO ARREGLA LA FRASE --'
    Reset
    $null = Add-TestigoOido 'haben' 'abre' 'correccion'
    $null = Add-TestigoOido 'haben' 'abre' 'vosk'
    Comp '3a. "haben steam" se vuelve "abre steam"' ((Repair-Verb 'haben steam') -eq 'abre steam') (Repair-Verb 'haben steam')
    Comp '3b. y lo escrito a mano sigue mandando' ((Repair-Verb 'sierra discord') -eq 'cierra discord') 'la tabla de braya va primero'
    Comp '3c. una palabra suelta no se toca' ((Repair-Verb 'haben') -eq 'haben') 'un verbo solo casi nunca es una orden'

    Write-Host ''
    Write-Host '-- 4. SE PUEDE QUITAR --'
    Comp '4a. se quita' (Remove-OidoAprendido 'haben') ''
    Comp '4b. y deja de arreglar la frase' ((Repair-Verb 'haben steam') -eq 'haben steam') ''
    Comp '4c. quitar lo que no hay no revienta' (-not (Remove-OidoAprendido 'nunca-visto')) ''

    Write-Host ''
    Write-Host '-- 5. SOBREVIVE AL REINICIO Y NO CRECE SIN FIN --'
    Reset
    $null = Add-TestigoOido 'haben' 'abre' 'correccion'
    $null = Add-TestigoOido 'haben' 'abre' 'vosk'
    $script:oidoAprendido = $null          # como si Nova se reiniciara
    Comp '5a. lo aprendido se relee del disco' ((Get-VerbosAprendidos)['haben'] -eq 'abre') ''
    Comp '5b. con sus testigos' ((Get-OidoAprendido)['haben'].testigos -eq 2) ([string](Get-OidoAprendido)['haben'].testigos)
    # el tope
    for ($i = 0; $i -lt ($OidoAprendidoMax + 10); $i++) {
        $null = Add-TestigoOido ('palabrota' + $i) 'abre' 'correccion'
    }
    Comp '5c. la lista se queda en su tope' ((Get-OidoAprendido).Count -le $OidoAprendidoMax) ([string](Get-OidoAprendido).Count + ' de ' + [string]$OidoAprendidoMax)

    Write-Host ''
    Write-Host '-- 6. EL CABLEADO --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp '6a. la correccion hablada deja testigo' ($sinCom -match "Add-TestigoOido \`$pMal\[0\] \`$pBien\[0\] 'correccion'") ''
    Comp '6b. y solo si el resto de la frase es igual' ($sinCom -match "\`$pMal\[1\] -eq \`$pBien\[1\] -and \`$pMal\[0\] -ne \`$pBien\[0\]") 'si cambia todo, no es una palabra mal oida'
    Comp '6c. Vosk deja el suyo, leyendo el registro' ($sinCom -match "Add-TestigoOido \`$pe\[0\] \`$pv\[0\] 'vosk'") ''
    Comp '6d. y exige que el de Vosk SI sea verbo y el otro no' ($sinCom -match '(?s)VERBOS_LISTA -contains \$pv\[0\]\)\) \{ continue \}.{0,200}VERBOS_LISTA -contains \$pe\[0\]\) \{ continue \}') 'al reves seria aprenderse el fallo de Vosk'
    Comp '6e. el registro se lee una vez al dia, no en el bucle' ($sinCom -match '\$script:oidoVoskDia -eq \$hoyV') ''
    Comp '6f. y Repair-Verb los usa DESPUES de los de a mano' ($sinCom -match '(?s)VERBOS_IMPERATIVO\[\$partes\[0\]\].{0,300}Get-VerbosAprendidos') ''
} finally {
    Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'las correcciones de oido se ganan del uso, con dos testigos' -ForegroundColor Green
exit 0
