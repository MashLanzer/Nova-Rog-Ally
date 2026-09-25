# QUE NOVA SE DE CUENTA DE QUE HA DEJADO DE HACER ALGO (25/09, idea 3 de las cincuenta)
#
# LO MEDIDO: el diario del dia se escribio 10 veces entre el 10 y el 21/09, y NI UNA desde
# entonces. Cuatro dias callado sin que saltara nada. En el mismo periodo la copia diaria de lo
# aprendido siguio funcionando (13 de 13 dias), asi que no era que Nova estuviera apagada: era
# esa costumbre concreta la que se habia roto.
#
# POR QUE SE ROMPIO, investigado: el resumen del diario vive dentro del worker de la charla y
# solo corre tras 20 minutos sin hablar Y con el revisor despierto -que se para en seco cuando
# hay un juego delante-. Entre partidas y reinicios, esa ventana casi nunca llega. El material
# no se ha perdido (quedan 3 ficheros de charla en bruto sin resumir), pero el diario lleva
# cuatro dias en blanco.
#
# LA IDEA, y es autonomia de la de verdad: Nova ya vigila la bateria de braya, su disco y sus
# descargas. Lo que no vigila es A SI MISMA. Si algo que hacia todos los dias deja de pasar,
# deberia notarlo ella, no yo mirando carpetas.
#
# LO QUE NO HACE, a proposito: no intenta arreglarlo sola. Avisa. Una costumbre rota puede
# tener diez causas distintas y ponerse a "arreglar" a ciegas es justo la clase de iniciativa
# que la regla 1 de la casa prohibe.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. existe y se usa --'
Comp 'existe Get-CostumbresOlvidadas' ($sinCom -match 'function Get-CostumbresOlvidadas') ''
Comp 'y la lista de costumbres de verdad' ($sinCom -match 'function Get-CostumbresPropias') ''
# UNA DEFINICION NO ES UNA LLAMADA (25/09, lo cazo una rotura). Buscar "Test-CostumbresPropias"
# a secas encuentra la propia "function Test-CostumbresPropias", asi que borrar la llamada
# dejaba el banco verde con la funcion muerta dentro del archivo. Se cuentan las apariciones
# que NO son la definicion.
$llamadas = @([regex]::Matches($sinCom, '(?<!function )Test-CostumbresPropias')).Count
Comp 'se llama de verdad, no solo se define' ($llamadas -ge 1) "$llamadas llamada(s)"
Comp 'y avisa por la puerta del entorno' ($sinCom -match "Send-AvisoEntorno 'me-olvide'") 'si no estas, se guarda'
Comp 'y NO intenta arreglarlo sola' (-not ($sinCom -match "me-olvide[^\n]{0,200}(Invoke-FastCommand|Start-Process)")) 'avisar si, adivinar no'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-CostumbresOlvidadas' }, $true)
if (-not $d) {
    Comp 'se saca Get-CostumbresOlvidadas del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
function Log([string]$m) { }          # el doble, DESPUES de cargar (manera 9)

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-cost-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
function Carpeta([string]$nombre, [string[]]$ficheros) {
    $c = Join-Path $tmp $nombre
    New-Item -ItemType Directory -Path $c -Force | Out-Null
    foreach ($f in $ficheros) { Set-Content -LiteralPath (Join-Path $c $f) -Value 'x' -Encoding UTF8 }
    return $c
}
try {
    $hoy = [datetime]'2026-09-25'

    # --- AL DIA: escribio ayer y hoy, no hay nada que decir
    $alDia = Carpeta 'aldia' @('2026-09-24.md', '2026-09-25.md')
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'el diario'; carpeta = $alDia; cadaDias = 1; graciaDias = 3 }) $hoy)
    Comp 'una costumbre al dia no se dice' ($r.Count -eq 0) "$($r.Count)"

    # --- DENTRO DE LA GRACIA: lleva 2 dias, pero la gracia es 3
    $gracia = Carpeta 'gracia' @('2026-09-23.md')
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'el diario'; carpeta = $gracia; cadaDias = 1; graciaDias = 3 }) $hoy)
    Comp 'dentro de la gracia tampoco' ($r.Count -eq 0) '2 dias, gracia 3'

    # --- PASADA LA GRACIA: el caso real del diario, 4 dias
    $roto = Carpeta 'roto' @('2026-09-20.md', '2026-09-21.md')
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'el diario'; carpeta = $roto; cadaDias = 1; graciaDias = 3 }) $hoy)
    Comp 'pasada la gracia SI se dice' ($r.Count -eq 1) "$($r.Count)"
    if ($r.Count -eq 1) {
        Comp '  y dice cual es' ($r[0].nombre -eq 'el diario') "$($r[0].nombre)"
        Comp '  y cuantos dias lleva' ($r[0].dias -eq 4) "$($r[0].dias) dias (21 -> 25)"
    }

    # --- UNA SEMANAL NO SE MIDE COMO UNA DIARIA
    $sem = Carpeta 'sem' @('2026-W38.md')
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'el resumen de la semana'; carpeta = $sem; cadaDias = 7; graciaDias = 3 }) $hoy)
    Comp 'una semanal con 4 dias no se dice' ($r.Count -eq 0) 'cadaDias 7 + gracia 3 = 10'

    # --- CARPETA VACIA: nunca lo ha hecho. No es un olvido, es que no ha empezado.
    $vacia = Carpeta 'vacia' @()
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'algo nuevo'; carpeta = $vacia; cadaDias = 1; graciaDias = 3 }) $hoy)
    Comp 'una carpeta vacia no es un olvido' ($r.Count -eq 0) 'sin una primera vez no hay costumbre que romper'

    # --- CARPETA QUE NO EXISTE: ni revienta ni acusa
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'x'; carpeta = (Join-Path $tmp 'no-existe'); cadaDias = 1; graciaDias = 3 }) $hoy)
    Comp 'una carpeta que no existe no revienta' ($r.Count -eq 0) ''

    # --- VARIAS A LA VEZ: solo salen las rotas
    $r = @(Get-CostumbresOlvidadas @(
        @{ nombre = 'el diario'; carpeta = $roto; cadaDias = 1; graciaDias = 3 },
        @{ nombre = 'la copia'; carpeta = $alDia; cadaDias = 1; graciaDias = 3 },
        @{ nombre = 'la semana'; carpeta = $sem; cadaDias = 7; graciaDias = 3 }) $hoy)
    Comp 'con varias, solo salen las rotas' ($r.Count -eq 1 -and $r[0].nombre -eq 'el diario') "$($r.Count): $(($r | ForEach-Object { $_.nombre }) -join ', ')"

    # --- LOS NOMBRES DE FICHERO MANDAN, NO SU FECHA DE DISCO: una copia de seguridad puede
    # tocar la fecha de modificacion de todo sin que la costumbre se haya cumplido.
    # HACEN FALTA DOS FICHEROS PARA QUE ESTO PRUEBE ALGO (25/09, lo cazo una rotura). Con uno
    # solo, fiarse del disco o del nombre da la misma respuesta. Aqui el mas NUEVO por fecha de
    # disco es el mas VIEJO por nombre, que es lo que pasa de verdad cuando una copia de
    # seguridad o un git checkout tocan los ficheros: quien mire el disco dira que la costumbre
    # esta rota (20/09, cinco dias) y quien lea los nombres vera que se cumplio ayer.
    $raro = Carpeta 'raro' @('2026-09-20.md', '2026-09-24.md')
    (Get-Item (Join-Path $raro '2026-09-20.md')).LastWriteTime = $hoy
    (Get-Item (Join-Path $raro '2026-09-24.md')).LastWriteTime = $hoy.AddDays(-30)
    $r = @(Get-CostumbresOlvidadas @(@{ nombre = 'el diario'; carpeta = $raro; cadaDias = 1; graciaDias = 3 }) $hoy)
    Comp 'una fecha de disco tocada no engana' ($r.Count -eq 0) 'manda el nombre: el ultimo es del 24, no del 20'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 3. y las costumbres de verdad son las de verdad --'
$d2 = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-CostumbresPropias' }, $true)
if ($d2) {
    $cuerpo = $d2.Extent.Text
    foreach ($q in @('diario', 'copias', 'semanas')) {
        Comp ("vigila " + $q) ($cuerpo -match $q) ''
    }
    Comp 'y ninguna gracia es absurda' (-not ($cuerpo -match 'graciaDias\s*=\s*(0|[1-9][0-9]{2,})')) 'ni cero ni cien dias'
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova se da cuenta de lo que ha dejado de hacer'
exit 0
