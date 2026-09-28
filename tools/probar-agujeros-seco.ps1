# LOS AGUJEROS QUE NO LO ERAN (27/09, idea 79 de las 121), la mitad del asistente
#
# El worker lee importante.jsonl y agrupa (ver probar-agujeros.py); aqui se hace lo que el worker NO
# puede hacer: probar EN SECO si eso que Nova dijo que no sabia es algo que SI sabe. De los 8
# agujeros contados en los dos registros, TRES eran falsos: dos veces 'que hora es?' -contesto 'no
# tengo acceso a la hora actual de tu consola'- y una el clima, que se arreglo a mano el 15/09 y el
# comentario de assistant.ps1 lo dice con estas palabras: 'cual es el clima para hoy iba a la charla,
# que decia que no tenia el clima'.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la prueba sea EN SECO: Test-FastCommand, que dice si hay orden y no ejecuta nada
#   2. que lo que paso UNA vez no cuente como agujero de Nova
#   3. que sin agujeros repetidos la frase no salga (nada de recitar fallos)
#   4. que un agujero falso se diga como tal, porque es el unico arreglable hoy
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
foreach ($f in @('Get-AgujerosSemana', 'Get-ParrafoAgujeros')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)

# EL DOBLE DEL RESOLVEDOR, despues de cargar: Test-FastCommand de verdad arrastra media casa
# (commands.json, traducciones, los perfiles), y lo que este banco vigila es el CABLEADO, no el
# resolvedor, que ya tiene sus propios bancos.
$script:probadas = @()
function Test-FastCommand([string]$t) {
    $script:probadas += @($t)
    return ($t -match 'hora|clima|tiempo')     # lo que Nova si sabe resolver
}
$script:ejecutadas = @()
function Invoke-FastCommand([string]$t) { $script:ejecutadas += @($t); return 'ejecutado' }

$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-agu2-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $MemoriaDir 'cerebro') -Force | Out-Null
$AgujerosJson = Join-Path $MemoriaDir 'cerebro\agujeros.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Escribir($o) { [IO.File]::WriteAllText($AgujerosJson, (ConvertTo-Json $o -Depth 5), $UTF8) }
function Reset { $script:probadas = @(); $script:ejecutadas = @() }

try {
    Write-Host ''
    Write-Host '-- 1. SIN FICHERO, NI UNA PALABRA --'
    Reset
    Comp '1a. sin agujeros.json no hay nada' ($null -eq (Get-AgujerosSemana)) ''
    Comp '1b. y el parrafo sale vacio' ((Get-ParrafoAgujeros) -eq '') 'nada de recitar fallos'

    Write-Host ''
    Write-Host '-- 2. LO QUE PASO UNA VEZ NO ES UN AGUJERO --'
    Reset
    Escribir @{ total = 3; grupos = @(@{ veces = 1; frase = 'que hora es'; dias = @('2026-09-27') },
                                      @{ veces = 1; frase = 'cuanto pesa la luna'; dias = @('2026-09-26') }) }
    $a2 = Get-AgujerosSemana
    Comp '2a. se lee el total' ($a2.total -eq 3) ([string]$a2.total)
    Comp '2b. pero ninguno repetido' (@($a2.repetidos).Count -eq 0) ''
    Comp '2c. asi que no se dice nada' ((Get-ParrafoAgujeros) -eq '') ''
    Comp '2d. y ni se prueba en seco lo que no se repite' (@($script:probadas).Count -eq 0) 'no se gasta trabajo en eso'

    Write-Host ''
    Write-Host '-- 3. EL CASO DE VERDAD: la hora, que SI sabe --'
    Reset
    Escribir @{ total = 8; grupos = @(@{ veces = 3; frase = 'que hora es'; dias = @('2026-09-25', '2026-09-26') },
                                      @{ veces = 2; frase = 'como se llama mi mascota'; dias = @('2026-09-26', '2026-09-27') }) }
    $a3 = Get-AgujerosSemana
    Comp '3a. los dos repetidos entran' (@($a3.repetidos).Count -eq 2) ([string]@($a3.repetidos).Count)
    $hora3 = @($a3.repetidos | Where-Object { $_.frase -match 'hora' })[0]
    $masco3 = @($a3.repetidos | Where-Object { $_.frase -match 'mascota' })[0]
    Comp '3b. la hora sale marcada como agujero FALSO' ($hora3.falso) 'Nova si sabe la hora'
    Comp '3c. y la mascota como agujero de verdad' (-not $masco3.falso) 'eso si le falta'
    $p3 = Get-ParrafoAgujeros
    Comp '3d. el parrafo dice cuantas y cuantas de lo mismo' ($p3 -match 'no supe contestarte 8' -and $p3 -match '2 eran de lo mismo') $p3
    Comp '3e. nombra lo que de verdad le falta' ($p3 -match 'mascota') ''
    Comp '3f. y avisa de lo que SI sabia' ($p3 -match ('si la s' + [char]0xE9 + ' y te dije que no') -and $p3 -match 'hora') ''

    Write-Host ''
    Write-Host '-- 4. EN SECO DE VERDAD: NADA SE EJECUTA --'
    # CUATRO y no dos: Get-AgujerosSemana se llamo dos veces -una directa en 3a y otra dentro de
# Get-ParrafoAgujeros-, y cada una prueba los dos repetidos. Lo que importa es que se prueban los
# REPETIDOS y ninguno mas.
Comp '4a. se probaron los repetidos, dos por pasada' (@($script:probadas).Count -eq 4 -and (@($script:probadas | Sort-Object -Unique).Count -eq 2)) ([string]@($script:probadas).Count + ' pruebas de ' + [string](@($script:probadas | Sort-Object -Unique).Count) + ' frases')
    Comp '4b. y NO se ejecuto ninguna' (@($script:ejecutadas).Count -eq 0) 'Test-FastCommand dice si hay orden; no la hace'
    Comp '4c. el codigo no llama a Invoke-FastCommand' (-not ((Traer 'Get-AgujerosSemana') -match 'Invoke-FastCommand')) 'una prueba que ejecuta no es una prueba'

    Write-Host ''
    Write-Host '-- 5. CON EL FICHERO ROTO O VACIO, COMO SI NO HUBIERA --'
    Reset
    [IO.File]::WriteAllText($AgujerosJson, 'esto no es json', $UTF8)
    Comp '5a. json roto: nada' ($null -eq (Get-AgujerosSemana)) ''
    Escribir @{ total = 0; grupos = @() }
    Comp '5b. cero agujeros: nada' ($null -eq (Get-AgujerosSemana)) 'una semana sin agujeros no es noticia'
    Comp '5c. y el parrafo vacio' ((Get-ParrafoAgujeros) -eq '') ''

    Write-Host ''
    Write-Host '-- 6. EL CABLEADO --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp '6a. la nota semanal lo dice' ($sinCom -match '\$parrafoAg = Get-ParrafoAgujeros') ''
    Comp '6b. dentro de su propio try' ($sinCom -match 'try \{ \$parrafoAg = Get-ParrafoAgujeros \} catch \{ \$parrafoAg = .. \}') 'que falle esto no puede tumbar la nota'
    Comp '6c. y el worker escribe el fichero que aqui se lee' ([IO.File]::ReadAllText((Join-Path $Raiz 'charla_worker.py')) -match 'agujeros\.json') ''
    Comp '6d. con os.replace, no a medias' ([IO.File]::ReadAllText((Join-Path $Raiz 'charla_worker.py')) -match 'os\.replace\(tmp_ag, ruta_ag\)') ''
} finally {
    Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'los agujeros se cuentan, y los falsos se cazan en seco' -ForegroundColor Green
exit 0
