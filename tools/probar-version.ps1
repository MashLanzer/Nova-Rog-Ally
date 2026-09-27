# NOVA NO SABIA QUE VERSION DE SI MISMA ESTABA CORRIENDO (27/09, idea 95 de las 121)
#
# EL DATO: 648 commits sobre Nova entre el 10 y el 27/09, unos 36 al dia, y 259 lineas
# "VoiceAssistant iniciado" en los dos registros SIN UNA SOLA marca de version: apuntan PID,
# trigger y cerebro, y nada mas. Cuando un numero suyo empeora no hay forma de decir desde cuando,
# y con 36 cambios al dia eso es no poder atribuir nada a nada.
#
# TRES COSAS Y NO UNA, que es donde la ficha se quedaba corta: EL HASH DE HEAD NO IDENTIFICA EL
# CODIGO QUE CORRE. Aqui lo normal es tener cambios sin commitear -es como se trabaja-, asi que dos
# arranques con el mismo hash pueden llevar codigo distinto. El tamano y la fecha de assistant.ps1
# si cambian con cada edicion y no cuestan nada.
#
# Y SIN LANZAR GIT: medido, `git rev-parse --short HEAD` en un proceso aparte son 152 ms del
# arranque; leyendo .git a mano son 3,94 ms de media en cinco medidas (5,0 / 3,3 / 3,3 / 3,4 / 4,7).
# Cuarenta veces menos, sin depender de que git este instalado y sin proceso hijo que colgarse.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el hash salga bien en las tres formas que tiene .git de guardarlo
#   2. que sin git, o con .git roto, NO reviente y siga dando algo que distinga dos versiones
#   3. que el tamano y la fecha vayan SIEMPRE, tambien cuando el hash sale
#   4. que las versiones no se coman las 40 plazas de "recientes", y que reabrir Nova cinco veces
#      sin tocar el codigo no cuente como cinco versiones
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
Invoke-Expression (Traer 'Get-VersionNova')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# UN MUNDO DE MENTIRA CON SU PROPIO .git, para poder probar las tres formas
$Base = Join-Path ([IO.Path]::GetTempPath()) ('nova-ver-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$HASH = '9f3c1a2b4d5e6f708192a3b4c5d6e7f809a1b2c3'
function Montar([string]$modo) {
    if (Test-Path -LiteralPath $Base) { Remove-Item -LiteralPath $Base -Recurse -Force }
    New-Item -ItemType Directory -Path $Base -Force | Out-Null
    # un assistant.ps1 de mentira, que es lo que se mide para el tamano y la fecha
    [IO.File]::WriteAllText((Join-Path $Base 'assistant.ps1'), ('x' * 3000))
    if ($modo -eq 'sin-git') { return }
    $gd = Join-Path $Base '.git'
    New-Item -ItemType Directory -Path $gd -Force | Out-Null
    if ($modo -eq 'roto') {
        [IO.File]::WriteAllText((Join-Path $gd 'HEAD'), "esto no es una cabeza`n")
        return
    }
    if ($modo -eq 'suelta') {
        [IO.File]::WriteAllText((Join-Path $gd 'HEAD'), "ref: refs/heads/main`n")
        New-Item -ItemType Directory -Path (Join-Path $gd 'refs\heads') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $gd 'refs\heads\main'), ($HASH + "`n"))
        return
    }
    if ($modo -eq 'empaquetada') {
        [IO.File]::WriteAllText((Join-Path $gd 'HEAD'), "ref: refs/heads/main`n")
        [IO.File]::WriteAllText((Join-Path $gd 'packed-refs'),
            "# pack-refs with: peeled fully-peeled sorted `n0000000000000000000000000000000000000000 refs/heads/otra`n$HASH refs/heads/main`n")
        return
    }
    if ($modo -eq 'detached') {
        [IO.File]::WriteAllText((Join-Path $gd 'HEAD'), ($HASH + "`n"))
        return
    }
    throw ('modo desconocido: ' + $modo)
}
function Ver([string]$modo) {
    Montar $modo
    $script:LogDir = $Base
    $script:versionNova = ''
    return (Get-VersionNova)
}

try {
    Write-Host ''
    Write-Host '-- 1. LAS TRES FORMAS QUE TIENE .git DE GUARDAR EL HASH --'
    $v1 = Ver 'suelta'
    Comp '1a. con la referencia suelta sale el hash' ($v1 -match '^9f3c1a2') $v1
    Comp '1b. cortado a siete, como git rev-parse --short' ($v1 -split ' ')[0].Length -eq 7 ([string]($v1 -split ' ')[0])
    $v2 = Ver 'empaquetada'
    Comp '1c. empaquetada por un git gc, tambien' ($v2 -match '^9f3c1a2') $v2
    Comp '1d. y no coge la de OTRA rama del packed-refs' (-not ($v2 -match '0000000')) 'la linea de "otra" esta antes'
    $v3 = Ver 'detached'
    Comp '1e. y con la cabeza suelta, que el hash esta en HEAD' ($v3 -match '^9f3c1a2') $v3

    Write-Host ''
    Write-Host '-- 2. SIN GIT, O CON .git ROTO, NO SE QUEDA MUDA --'
    $v4 = Ver 'sin-git'
    Comp '2a. sin .git no revienta' ($v4.Length -gt 0) $v4
    Comp '2b. y da algo que distingue dos versiones' ($v4 -match '^\d+k \d{4}-\d{4}$') 'tamano y fecha del fichero'
    $v5 = Ver 'roto'
    Comp '2c. con un HEAD que no se entiende, igual' ($v5 -match '^\d+k \d{4}-\d{4}$') $v5
    Comp '2d. y sin hash inventado' (-not ($v5 -match '[0-9a-f]{7} ')) 'mejor sin hash que con uno falso'

    Write-Host ''
    Write-Host '-- 3. EL TAMANO Y LA FECHA VAN SIEMPRE (de esto va la correccion a la ficha) --'
    # ES EL CASO DE TODOS LOS DIAS: mismo commit, codigo editado encima. Con solo el hash, los dos
    # arranques serian "la misma version" y no lo son.
    $v6 = Ver 'suelta'
    Comp '3a. con hash, tambien lleva tamano y fecha' ($v6 -match '^[0-9a-f]{7} \d+k \d{4}-\d{4}$') $v6
    # se edita el fichero sin tocar git: la version TIENE que cambiar
    Start-Sleep -Milliseconds 1100
    [IO.File]::WriteAllText((Join-Path $Base 'assistant.ps1'), ('x' * 9000))
    $script:versionNova = ''
    $v7 = Get-VersionNova
    Comp '3b. editando el codigo sin commitear, la version cambia' ($v7 -ne $v6) ($v6 + '  ->  ' + $v7)
    Comp '3c. y el hash sigue siendo el mismo' (($v7 -split ' ')[0] -eq ($v6 -split ' ')[0]) 'por eso el hash solo no basta'

    Write-Host ''
    Write-Host '-- 4. UNA SOLA VEZ POR ARRANQUE --'
    $script:versionNova = ''
    $null = Get-VersionNova
    # se rompe el .git a mala idea: si volviera a leerlo, la respuesta cambiaria
    Remove-Item -LiteralPath (Join-Path $Base '.git') -Recurse -Force
    Comp '4a. la segunda vez no vuelve a leer nada' ((Get-VersionNova) -eq $v7) 'se queda con la primera respuesta'
} finally {
    Remove-Item -LiteralPath $Base -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 5. Y CONTRA EL REPOSITORIO DE VERDAD --'
$script:LogDir = $Raiz
$script:versionNova = ''
$vr = Get-VersionNova
Comp '5a. aqui sale una version entera' ($vr -match '^[0-9a-f]{7} \d+k \d{4}-\d{4}$') $vr
$hashGit = ''
try { $hashGit = (& git -C $Raiz rev-parse --short HEAD 2>$null).Trim() } catch {}
if ($hashGit) {
    Comp '5b. y el hash es el que dice git' (($vr -split ' ')[0] -eq $hashGit) ('leido ' + ($vr -split ' ')[0] + ', git dice ' + $hashGit)
} else {
    Write-Host '  --   git no contesta aqui, se salta la comparacion'
}
# y lo que cuesta, medido: primero se calienta, que si no se mide el JIT
$script:versionNova = ''; $null = Get-VersionNova
$ms = @()
foreach ($i in 1..5) {
    $script:versionNova = ''
    $sw5 = [Diagnostics.Stopwatch]::StartNew()
    $null = Get-VersionNova
    $ms += $sw5.Elapsed.TotalMilliseconds
}
$media = ($ms | Measure-Object -Average).Average
Comp '5c. y cuesta menos de 20 ms' ($media -lt 20) ([string][Math]::Round($media, 2) + ' ms de media en 5; lanzar git eran 152')

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
Comp '6a. la version va en la linea de arranque que ya existia' ($sinCom -match 'VoiceAssistant iniciado PID=\$PID \(version: \$verNova;') 'asi se compara con las 259 que ya hay'
Comp '6b. y queda en las estadisticas del dia' ($sinCom -match "Add-Estadistica 'version' \`$verNova") ''
Comp '6c. en su propia lista, no en recientes' ($sinCom -match "\`$ruta -eq 'version' -and \`$d") '16 arranques al dia se comerian las 40 plazas'
Comp '6d. y esa rama va ANTES de la de recientes' ($sinCom.IndexOf("`$ruta -eq 'version'") -lt $sinCom.IndexOf('$s.recientes = @(@($fila)')) 'si no, entraria en las dos'
Comp '6e. una version repetida no anade linea' ($sinCom -match '\@\(\$s\.versiones\)\[0\] -notmatch \(\[regex\]::Escape\(\$d\)') 'reabrir Nova sin tocar el codigo no es otra version'
Comp '6f. la lista tiene tope' ($sinCom -match '\$s\.versiones = @\(@\(\(Get-Date[^\r\n]*Select-Object -First 40\)') ''
Comp '6g. se guarda en el json' ($sinCom -match 'Add-Member -NotePropertyName versiones') ''
Comp '6h. y se relee al arrancar' ($sinCom -match "\`$j\.PSObject\.Properties\['versiones'\]") 'si no, cada arranque empezaria de cero'
Comp '6i. no lanza ningun proceso para saberlo' (-not ((Traer 'Get-VersionNova') -match 'Diagnostics\.Process|Start-Process|& git')) 'medido: 152 ms contra 4'

Write-Host ''
Write-Host '-- 7. Y LA LISTA DE VERSIONES, EJECUTADA DE VERDAD --'
# El trozo no vive en una funcion propia -esta dentro de Add-Estadistica, que arrastra media casa-,
# asi que se corta por texto del fichero y se ejecuta. Con asserts de que se cogio lo que se queria.
$lin = [IO.File]::ReadAllLines($PS1)
$i0 = -1
for ($i = 0; $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match "^\s*\} elseif \(\`$ruta -eq 'version' -and \`$d\) \{") { $i0 = $i; break }
}
Comp '7a. se encuentra la rama en el fichero' ($i0 -ge 0) ''
# POR SANGRADO Y NO CONTANDO LLAVES, y las dos razones son la misma linea: '} elseif (...) {' tiene
# una llave que cierra y otra que abre, o sea equilibrio CERO. Contando desde ella el bloque parecia
# acabarse en el acto; empezando en la siguiente con profundidad 1, el corte se comia TAMBIEN el
# '} elseif ($d) {' de despues y sus 29 lineas. El cierre de esta rama es la primera linea posterior
# que empieza por '}' con el MISMO sangrado que su apertura.
$sangrado = ($lin[$i0] -replace '\S.*$', '').Length
$i1 = -1
for ($i = ($i0 + 1); $i -lt $lin.Count; $i++) {
    if ($lin[$i] -match '^\s*\}' -and (($lin[$i] -replace '\S.*$', '').Length -eq $sangrado)) { $i1 = $i; break }
}
Comp '7b. y donde acaba' ($i1 -gt $i0 -and ($i1 - $i0) -lt 20) ([string]($i1 - $i0 + 1) + ' lineas')
# se quitan el '} elseif (...) {' de la primera linea y el cierre, y queda el cuerpo
$cuerpo = ($lin[($i0 + 1)..($i1 - 1)] -join "`n")
Comp '7c. con lo que importa dentro' (($cuerpo -match 'versiones') -and ($cuerpo -match 'Select-Object -First 40')) ''
$fn = [scriptblock]::Create("function Apuntar(`$s, [string]`$d) {`n$cuerpo`n}")
. $fn
$st = @{ dias = @{}; descartes = @(); recientes = @(); decisiones = @() }
Apuntar $st '2608fe1 2112k 0927-0725'
Comp '7d. la primera version abre la lista' (@($st.versiones).Count -eq 1) ([string]@($st.versiones).Count)
Comp '7e. con su fecha y hora delante' ($st.versiones[0] -match '^\d{4}-\d\d-\d\d \d\d:\d\d  2608fe1 2112k 0927-0725$') ([string]$st.versiones[0])
Apuntar $st '2608fe1 2112k 0927-0725'
Apuntar $st '2608fe1 2112k 0927-0725'
Comp '7f. reabrir Nova sin tocar el codigo no anade nada' (@($st.versiones).Count -eq 1) ([string]@($st.versiones).Count + '; hay unos 16 arranques al dia')
Apuntar $st '2608fe1 2115k 0927-0801'
Comp '7g. y editar el codigo SI' (@($st.versiones).Count -eq 2) ([string]@($st.versiones).Count)
Comp '7h. la nueva va primera' ($st.versiones[0] -match '2115k') ([string]$st.versiones[0])
Apuntar $st '2608fe1 2112k 0927-0725'
Comp '7i. volver a una version anterior tambien cuenta' (@($st.versiones).Count -eq 3) 'es otro cambio, aunque el codigo ya se hubiera visto'
Comp '7j. y no toca recientes' (@($st.recientes).Count -eq 0) ([string]@($st.recientes).Count + ' fila(s) en recientes')
Comp '7k. ni el contador de los dias' (@($st.dias.Keys).Count -eq 0) 'eso lo hace la parte de arriba de Add-Estadistica'
for ($k = 0; $k -lt 60; $k++) { Apuntar $st ('hash' + $k + ' 2112k 0927-0725') }
Comp '7l. y la lista tiene tope' (@($st.versiones).Count -le 40) ([string]@($st.versiones).Count + ' de 40')

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova sabe que version de si misma esta corriendo' -ForegroundColor Green
exit 0
