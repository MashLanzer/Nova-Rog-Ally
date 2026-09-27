# QUE "¿QUE SABES DE...?" MIRE TAMBIEN EL CEREBRO, NO SOLO EL DIARIO (27/09, idea 106 de las 121)
#
# EL DATO: esta busqueda abria memoria\diario -14 ficheros, 38 vinetas RESUMIDAS- y una carpeta
# memoria\temas que NO EXISTE y nunca ha existido: cero ficheros en los diecisiete dias de vida del
# proyecto, y ningun sitio del codigo la crea. Estaba en el bucle desde el primer dia haciendo un
# Test-Path que siempre falla.
#
# Y MIENTRAS TANTO, memoria\cerebro\cerebro.json guarda 123 recuerdos, de ellos 119 de tipo
# 'episodio' o 'contado': cosas que braya dijo, con su texto entero, que esta busqueda no podia
# encontrar de ninguna manera. El contador 'memoria' de estadisticas.json va a TRES en diecisiete
# dias, y con esto se entiende por que.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que los recuerdos del cerebro se encuentren, puntuados con la MISMA funcion que el diario
#   2. que los de tipo 'respuesta' NO entren (eso es lo que Nova contesto, no lo que braya conto)
#   3. que un recuerdo rechazado no vuelva por esta puerta
#   4. que sin cerebro, o con uno roto, la busqueda siga funcionando como antes
#   5. y que la carpeta fantasma se haya ido
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
foreach ($f in @('ConvertTo-Plain', 'Get-Distancia', 'Get-PuntosClaves', 'Find-EnMemoria')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LA LISTA DE PALABRAS VACIAS, DEL FICHERO: si un dia cambia, este banco cambia con ella
$lineas = $txt -split "`r?`n"
$iPV = -1
for ($i = 0; $i -lt $lineas.Count; $i++) { if ($lineas[$i] -match '^\$PALABRAS_VACIAS = @\(') { $iPV = $i; break } }
$acum = ''
for ($i = $iPV; $i -lt ($iPV + 8) -and $i -lt $lineas.Count; $i++) {
    $acum += $lineas[$i] + "`n"
    if ($lineas[$i].TrimEnd().EndsWith(')')) { break }
}
Invoke-Expression $acum
Comp 'las palabras vacias salen del archivo' ($PALABRAS_VACIAS.Count -gt 20) ([string]$PALABRAS_VACIAS.Count)

Write-Host ''
Write-Host '-- 1. LA CARPETA FANTASMA SE FUE --'
Comp "1a. ya no se busca en memoria\temas" (-not ($sinCom -match "Join-Path \`$MemoriaDir 'temas'")) 'cero ficheros en 17 dias, y nadie la crea'
Comp '1b. y el diario sigue' ($sinCom -match 'foreach \(\$d in @\(\$DiarioDir\)\)') ''

# el mundo de mentira
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
function Get-PerfilTodo { return @() }
$Base = Join-Path ([IO.Path]::GetTempPath()) ('nova-memc-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$MemoriaDir = $Base
$DiarioDir = Join-Path $Base 'diario'
$CerebroDir = Join-Path $Base 'cerebro'
New-Item -ItemType Directory -Path $DiarioDir -Force | Out-Null
New-Item -ItemType Directory -Path $CerebroDir -Force | Out-Null
$enc = New-Object Text.UTF8Encoding($false)
function Cerebro($recuerdos) {
    $o = @{ recuerdos = @($recuerdos) } | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText((Join-Path $CerebroDir 'cerebro.json'), $o, $enc)
}
function Rec([string]$tipo, [string]$texto, [string]$estado = 'firme', [long]$creada = 1758844800) {
    return @{ id = 1; tipo = $tipo; respuesta = $texto; pregunta = $texto; estado = $estado; creada = $creada }
}

try {
    Write-Host ''
    Write-Host '-- 2. LOS RECUERDOS DEL CEREBRO SE ENCUENTRAN --'
    $script:logs = @()
    Cerebro @((Rec 'episodio' 'braya se compro un teclado mecanico azul y le suena fuerte'))
    $r = Find-EnMemoria 'que sabes del teclado mecanico'
    Comp '2a. lo encuentra' ($null -ne $r -and $r -match 'teclado mecanico azul') ([string]$r)
    Comp '2b. con su fecha' ($r -match 'de septiembre') 'la fecha sale de "creada", que es un tiempo de Unix'
    Comp '2c. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'recuerdo\(s\) del cerebro' }).Count -eq 1) ($script:logs -join ' / ')
    # lo de tipo 'contado' tambien
    Cerebro @((Rec 'contado' 'a braya le gusta el cafe con hielo'))
    Comp '2d. y lo que le conto tambien' ((Find-EnMemoria 'que sabes del cafe') -match 'cafe con hielo') ''

    Write-Host ''
    Write-Host '-- 3. LO QUE NO ENTRA --'
    Cerebro @((Rec 'respuesta' 'el cielo es azul porque la atmosfera dispersa la luz'))
    Comp '3a. una RESPUESTA de Nova no entra' ($null -eq (Find-EnMemoria 'que sabes del cielo')) 'eso es lo que ella contesto, y tiene su propio camino'
    Cerebro @((Rec 'episodio' 'braya se compro un teclado mecanico azul' 'rechazada'))
    Comp '3b. ni un recuerdo rechazado' ($null -eq (Find-EnMemoria 'que sabes del teclado')) 'un recuerdo apartado por falso no vuelve por aqui'
    Cerebro @((Rec 'episodio' 'abc'))
    Comp '3c. ni un texto de tres letras' ($null -eq (Find-EnMemoria 'que sabes de abc')) ''
    Cerebro @((Rec 'episodio' 'braya se compro un teclado'))
    Comp '3d. ni lo que no tiene nada que ver' ($null -eq (Find-EnMemoria 'que sabes de la bicicleta')) ''

    Write-Host ''
    Write-Host '-- 4. SIN CEREBRO, O CON UNO ROTO, TODO SIGUE IGUAL --'
    Remove-Item -LiteralPath (Join-Path $CerebroDir 'cerebro.json') -Force
    [IO.File]::WriteAllText((Join-Path $DiarioDir '2026-09-25.md'), "# 25 de septiembre`r`n`r`n- braya arreglo la bicicleta por fin`r`n", $enc)
    $script:logs = @()
    $r4 = Find-EnMemoria 'que sabes de la bicicleta'
    Comp '4a. sin cerebro, el diario sigue contestando' ($null -ne $r4 -and $r4 -match 'bicicleta') ([string]$r4)
    Comp '4b. y no se queja de nada' (@($script:logs | Where-Object { $_ -match 'memoria del cerebro' }).Count -eq 0) 'que no exista no es un error'
    [IO.File]::WriteAllText((Join-Path $CerebroDir 'cerebro.json'), 'esto no es json', $enc)
    $script:logs = @()
    $r5 = Find-EnMemoria 'que sabes de la bicicleta'
    Comp '4c. con el cerebro roto, tambien' ($null -ne $r5 -and $r5 -match 'bicicleta') ''
    Comp '4d. y ESO si se dice' (@($script:logs | Where-Object { $_ -match 'memoria del cerebro' }).Count -eq 1) 'un fichero roto no es lo mismo que uno que no esta'
    # y sin CerebroDir definido (arranque a medias) tampoco revienta
    $guardado = $CerebroDir
    $CerebroDir = $null
    $r6 = Find-EnMemoria 'que sabes de la bicicleta'
    Comp '4e. y sin la ruta puesta, tampoco' ($null -ne $r6 -and $r6 -match 'bicicleta') ''
    $CerebroDir = $guardado

    Write-Host ''
    Write-Host '-- 5. LAS TRES FUENTES SE ORDENAN JUNTAS, POR PUNTOS --'
    Cerebro @((Rec 'episodio' 'braya arreglo la bicicleta y le cambio la rueda pinchada y el manillar'))
    $r7 = Find-EnMemoria 'que sabes de la bicicleta y la rueda pinchada'
    Comp '5a. gana el que tiene mas palabras en comun' ($r7 -match 'rueda pinchada') ([string]$r7)
    Comp '5b. y salen las dos fuentes si caben' ($r7 -match 'bicicleta') 'tres como mucho, del monton entero'
    Comp '5c. la puntuacion es la MISMA para todas' ((Traer 'Find-EnMemoria') -match '(?s)Get-PuntosClaves \$lp \$claves.{0,4000}Get-PuntosClaves \(ConvertTo-Plain \$txtC\) \$claves') 'una sola idea de que es "encaja"'
} finally {
    Remove-Item -LiteralPath $Base -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 6. Y CONTRA EL CEREBRO DE VERDAD --'
$MemoriaDir = Join-Path $Raiz 'memoria'
$DiarioDir = Join-Path $MemoriaDir 'diario'
$CerebroDir = Join-Path $MemoriaDir 'cerebro'
if (Test-Path -LiteralPath (Join-Path $CerebroDir 'cerebro.json')) {
    $jr = Get-Content -LiteralPath (Join-Path $CerebroDir 'cerebro.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $episodios = @($jr.recuerdos | Where-Object { $_.tipo -eq 'episodio' -or $_.tipo -eq 'contado' })
    Comp '6a. hay recuerdos que antes no se podian encontrar' ($episodios.Count -gt 100) ([string]$episodios.Count + ' de tipo episodio o contado')
    $vinetas = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $DiarioDir -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
        $vinetas += @([IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::UTF8) | Where-Object { $_ -match '^\s*-\s' }).Count
    }
    Comp '6b. contra las vinetas del diario' ($vinetas -gt 0 -and $episodios.Count -gt $vinetas) ([string]$vinetas + ' vinetas frente a ' + [string]$episodios.Count + ' recuerdos')
} else {
    Write-Host '  --   no hay cerebro.json aqui, se salta'
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la busqueda en la memoria ya mira el cerebro, donde esta lo que dijiste' -ForegroundColor Green
exit 0
