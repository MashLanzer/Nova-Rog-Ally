# LA COPIA QUE TE SALVA, PROBADA POR PRIMERA VEZ (19/09, B13 = MEJORAS.md 3.4 #8).
#
# New-CopiaSeguridad es lo unico que hay entre un Set-Content cortado a medias y perder
# meses de traducciones, reglas, modos, el cerebro y tu voz. Existe desde el 13/09 y hasta
# hoy no la tocaba NINGUNA prueba: la red de seguridad era justo lo que nadie miraba.
#
# TODO OCURRE EN UNA CARPETA DE MENTIRA ($env:TEMP): ni copias\ de verdad ni tu OneDrive se
# tocan. $env:OneDrive se cambia a un sitio inventado A PROPOSITO, porque la funcion escribe
# ahi sola y ademas ROTA: una prueba descuidada te borraria copias buenas de OneDrive.
#
# Lo que se comprueba, por orden de lo que duele si falla:
#   1. que el zip se pueda ABRIR y devuelva el contenido (un zip que no restaura no salva)
#   2. que no pise nada: los originales intactos y lo ajeno de copias\ sin tocar
#   3. que la rotacion deje las $CopiasMax ultimas y tire las MAS VIEJAS, no otras
#   4. que falle bien: sin nada que copiar, con el destino imposible y con OneDrive roto
#      devuelve $null o la copia local, pero NUNCA revienta al que la llama
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$txtFuente = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
# EL TOPE SE LEE DEL FUENTE, no se copia aqui: si manana son 30 copias en vez de 14, esta
# prueba lo sigue en vez de quedarse midiendo un numero que ya no existe.
$CopiasMax = if ($txtFuente -match '(?m)^\$CopiasMax\s*=\s*(\d+)') { [int]$Matches[1] } else { 0 }
$script:logs = @()
function Log($m) { $script:logs += [string]$m }
function LogTiene([string]$patron) { return [bool](@($script:logs | Where-Object { $_ -match $patron }).Count) }
Invoke-Expression (Traer 'New-CopiaSeguridad')
Invoke-Expression (Traer 'Test-CopiaPendiente')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el voice-ctrl de mentira: las mismas variables que usa la funcion, otras rutas ---
$base = Join-Path $env:TEMP ('copia-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $base -Force
$LogDir           = Join-Path $base 'nova'
$TmpDir           = Join-Path $LogDir 'tmp'
$MemoriaDir       = Join-Path $LogDir 'memoria'
$CopiasDir        = Join-Path $LogDir 'copias'
$TraduccionesPath = Join-Path $LogDir 'traducciones.json'
$cmdsPath         = Join-Path $LogDir 'commands.json'
$cfgPath          = Join-Path $LogDir 'config.json'
$reglasPath       = Join-Path $LogDir 'reglas.json'
$vozPath          = Join-Path $TmpDir 'mi-voz.json'
$odFalso          = Join-Path $base 'onedrive'
$env:OneDrive = $odFalso   # NUNCA el de verdad: la funcion rota lo que encuentra alli

function Escribe([string]$ruta, [string]$txt) {
    $d = Split-Path -Parent $ruta
    if (-not (Test-Path -LiteralPath $d)) { $null = New-Item -ItemType Directory -Path $d -Force }
    [System.IO.File]::WriteAllText($ruta, $txt, (New-Object System.Text.UTF8Encoding($false)))
}
# los seis origenes de verdad: cuatro JSON sueltos, la carpeta memoria\ entera y mi-voz.json
function Monta([switch]$vacio) {
    if (Test-Path -LiteralPath $LogDir) { Remove-Item -LiteralPath $LogDir -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $LogDir -Force
    if (Test-Path -LiteralPath $odFalso) { Remove-Item -LiteralPath $odFalso -Recurse -Force }
    $null = New-Item -ItemType Directory -Path $odFalso -Force
    $script:logs = @()
    if ($vacio) { return }
    Escribe $TraduccionesPath '{"cansado":"tired"}'
    Escribe $reglasPath       '[{"id":1,"tipo":"appAbre"}]'
    Escribe $cmdsPath         '{"apps":{"spotify":"spotify.exe"}}'
    Escribe $cfgPath          '{"voz":{"activada":true}}'
    Escribe (Join-Path $MemoriaDir 'habitos.json') '{"usos":18}'
    Escribe (Join-Path $MemoriaDir 'diario\2026-09-19.md') 'lo de hoy'
    Escribe $vozPath          '{"vector":[0.1,0.2]}'
}
function Huella { @(Get-ChildItem -LiteralPath $LogDir -Recurse -File | Where-Object { $_.FullName -notlike "$CopiasDir*" } |
                    Sort-Object FullName | ForEach-Object { $_.FullName + '|' + (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash }) -join "`n" }
function Zips { @(Get-ChildItem -LiteralPath $CopiasDir -Filter 'lo-aprendido_*.zip' -ErrorAction SilentlyContinue) }
# leer sin morir: si el archivo no salio del zip esto tiene que salir MAL y seguir, no
# tumbar la prueba y dejar los casos de despues sin medir (es lo que pasaba al probarla)
function Leer([string]$ruta) {
    if (-not (Test-Path -LiteralPath $ruta)) { return '' }
    return (Get-Content -LiteralPath $ruta -Raw).Trim()
}
# abrir el zip DE VERDAD (no mirar si el archivo existe): un zip a medias existe igual
function SeAbre([string]$ruta) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    try { $z = [System.IO.Compression.ZipFile]::OpenRead($ruta); $n = $z.Entries.Count; $z.Dispose(); return ($n -gt 0) }
    catch { return $false }
}

Write-Host '  -- la copia normal: que exista, que cuente bien y que SE PUEDA ABRIR --'
Monta
$antes = Huella
$r = New-CopiaSeguridad 'la prueba'
Comp 'devuelve la ficha de la copia' ($null -ne $r) ''
Comp 'y el zip esta donde dice' ($r -and (Test-Path -LiteralPath $r.ruta)) "$($r.ruta)"
Comp 'cuenta los 7 archivos (5 sueltos + 2 de memoria)' ($r -and $r.archivos -eq 7) "archivos=$($r.archivos)"
Comp 'y pesa algo (no es un zip vacio)' ($r -and $r.kb -ge 1) "kb=$($r.kb)"
Comp 'lo apunta en el log con el motivo' (LogTiene 'COPIA \(la prueba\)') ''

# LO QUE DE VERDAD IMPORTA: abrirlo. Un zip que se crea pero no restaura es peor que
# ninguno, porque te hace creer que estas a salvo.
$abierto = Join-Path $base 'abierto'
Expand-Archive -LiteralPath $r.ruta -DestinationPath $abierto -Force
$dentro = @(Get-ChildItem -LiteralPath $abierto -Recurse -File | ForEach-Object { $_.FullName.Substring($abierto.Length + 1) })
foreach ($q in @('traducciones.json', 'reglas.json', 'commands.json', 'config.json', 'mi-voz.json', 'memoria\habitos.json', 'memoria\diario\2026-09-19.md')) {
    Comp ("dentro esta $q") ($dentro -contains $q) ''
}
Comp 'y el contenido vuelve igual, no vacio' ((Leer (Join-Path $abierto 'traducciones.json')) -eq '{"cansado":"tired"}') ''
Comp 'lo de la subcarpeta tambien' ((Leer (Join-Path $abierto 'memoria\diario\2026-09-19.md')) -eq 'lo de hoy') ''

Write-Host '  -- no pisa nada de lo que copia --'
Comp 'los originales siguen byte a byte iguales' ((Huella) -eq $antes) ''
Comp 'y ninguno ha desaparecido' ((Test-Path -LiteralPath $TraduccionesPath) -and (Test-Path -LiteralPath $vozPath) -and (Test-Path -LiteralPath (Join-Path $MemoriaDir 'habitos.json'))) ''

Write-Host '  -- tambien la deja en OneDrive, y sin pisar lo ajeno --'
$destOD = Join-Path $odFalso 'Nova\copias'
Comp 'la misma copia esta en OneDrive\Nova\copias' (Test-Path -LiteralPath (Join-Path $destOD (Split-Path -Leaf $r.ruta))) ''
Comp 'y lo dice' (LogTiene 'tambien en OneDrive') ''
# el tope de OneDrive esta escrito a mano en el fuente: si un dia cambia $CopiasMax y ese 14
# no, guardarias 30 en casa y 14 fuera sin enterarte. Se comprueba aqui, que es barato.
$topeOD = if ($txtFuente -match 'LastWriteTime -Descending \| Select-Object -Skip (\d+)') { [int]$Matches[1] } else { -1 }
Comp 'OneDrive rota con el mismo tope que casa' ($topeOD -eq $CopiasMax) "OneDrive=$topeOD, casa=$CopiasMax"

Write-Host '  -- la rotacion: se van las MAS VIEJAS, y solo las copias --'
Monta
$null = New-Item -ItemType Directory -Path $CopiasDir -Force
# copias viejas de mentira, una por dia hacia atras. El nombre lleva la fecha, que es como
# la funcion decide cual es vieja (ordena por nombre), asi que basta con crear los nombres.
$viejas = @()
foreach ($i in 1..($CopiasMax + 3)) {
    $n = 'lo-aprendido_' + (Get-Date).AddDays(-$i).ToString('yyyy-MM-dd_HHmm') + '.zip'
    Escribe (Join-Path $CopiasDir $n) 'zip de mentira'
    $viejas += $n
}
Escribe (Join-Path $CopiasDir 'no-tocar.txt') 'esto no es una copia'
Escribe (Join-Path $CopiasDir 'lo-aprendido-a-mano.zip') 'tampoco: no lleva guion bajo'
$r2 = New-CopiaSeguridad 'la del dia'
$quedan = Zips
Comp "quedan exactamente $CopiasMax copias" ($quedan.Count -eq $CopiasMax) "quedan $($quedan.Count) de $($CopiasMax + 4)"
Comp 'la nueva esta entre las que quedan' ($r2 -and ($quedan.Name -contains (Split-Path -Leaf $r2.ruta))) ''
Comp 'la mas vieja se ha ido' (-not ($quedan.Name -contains $viejas[-1])) "la de hace $($CopiasMax + 3) dias"
Comp 'la de ayer se queda' ($quedan.Name -contains $viejas[0]) ''
Comp 'se fueron las 4 mas viejas, ni una mas' (@($viejas | Where-Object { $quedan.Name -notcontains $_ }).Count -eq 4) ''
Comp 'lo que no es una copia sigue ahi' ((Test-Path -LiteralPath (Join-Path $CopiasDir 'no-tocar.txt')) -and (Test-Path -LiteralPath (Join-Path $CopiasDir 'lo-aprendido-a-mano.zip'))) ''

Write-Host '  -- dos veces en el mismo minuto: se pisa la suya, no se duplica ni revienta --'
# El nombre solo baja a minutos (lo-aprendido_yyyy-MM-dd_HHmm), asi que "la del dia" y un
# "hazme una copia" seguidos caen en el mismo archivo. Con -Force eso es sustituir, no fallar:
# queda apuntado aqui para que nadie lo descubra el dia que lo necesite.
Monta
[void](New-CopiaSeguridad 'la del dia')
$b = New-CopiaSeguridad 'lo pediste'
Comp 'la segunda tambien devuelve ficha' ($null -ne $b) ''
Comp 'y no deja dos zips del mismo minuto' ((Zips).Count -eq 1) "hay $((Zips).Count)"
Comp 'el zip sigue abriendose despues de pisarlo' (SeAbre $b.ruta) ''

Write-Host '  -- falla bien: sin nada que copiar --'
Monta -vacio
$r3 = New-CopiaSeguridad 'sin nada'
Comp 'devuelve nada, no una ficha falsa' ($null -eq $r3) ''
Comp 'y lo dice claro en el log' (LogTiene 'no hay nada que copiar') ''
Comp 'no deja una carpeta copias vacia de recuerdo' (-not (Test-Path -LiteralPath $CopiasDir)) ''

Write-Host '  -- falla bien: el destino no se puede crear --'
Monta
Escribe $CopiasDir 'aqui hay un FICHERO donde deberia ir la carpeta'   # el caso real: disco lleno, ruta ocupada, permisos
$r4 = New-CopiaSeguridad 'destino imposible'
Comp 'no revienta al que la llama' $true '(si reventara, esta prueba no llegaria aqui)'
Comp 'devuelve nada' ($null -eq $r4) ''
Comp 'y deja dicho que fallo, con el motivo' (LogTiene 'COPIA fallida \(destino imposible\)') ''
Comp 'y no ha tocado los originales' ((Test-Path -LiteralPath $TraduccionesPath) -and (Test-Path -LiteralPath $cfgPath)) ''

Write-Host '  -- falla bien: OneDrive roto o apagado NO se lleva la copia de casa --'
Monta
$env:OneDrive = Join-Path $base 'onedrive-que-no-existe'
$r5 = New-CopiaSeguridad 'sin onedrive'
Comp 'sin OneDrive la copia local se hace igual' ($null -ne $r5 -and (Test-Path -LiteralPath $r5.ruta)) ''
Comp 'y no inventa la carpeta de OneDrive' (-not (Test-Path -LiteralPath $env:OneDrive)) ''
Monta
$env:OneDrive = $odFalso
Escribe (Join-Path $odFalso 'Nova') 'un fichero donde iria la carpeta Nova'
$r6 = New-CopiaSeguridad 'onedrive roto'
Comp 'con OneDrive roto la copia local vale igual' ($null -ne $r6 -and (Test-Path -LiteralPath $r6.ruta)) ''
Comp 'y lo cuenta en vez de callarselo' (LogTiene 'no pude dejarla en OneDrive') ''
$env:OneDrive = $odFalso

Write-Host '  -- cada cuanto toca (que reiniciar cinco veces no deje cinco copias) --'
Monta
Comp 'sin carpeta, toca copia' (Test-CopiaPendiente) ''
$r7 = New-CopiaSeguridad 'la del dia'
Comp 'recien hecha, NO toca' (-not (Test-CopiaPendiente)) ''
(Get-Item -LiteralPath $r7.ruta).LastWriteTime = (Get-Date).AddHours(-19)
Comp 'a las 19 horas todavia no' (-not (Test-CopiaPendiente)) ''
(Get-Item -LiteralPath $r7.ruta).LastWriteTime = (Get-Date).AddHours(-21)
Comp 'a las 21 si' (Test-CopiaPendiente) ''

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
