# LAS COPIAS PODADAS (27/09, idea 65 de las 121)
#
# EL DATO: juntando el perfil.md de los 13 zips de copias\ salen 94 datos distintos sobre braya
# frente a los 38 que tiene el perfil vivo. Son 73 huerfanos que Nova ya decidio que no eran
# suyos y siguen guardados, entre ellos 'Braya considera que Nova se equivoca frecuentemente' y
# 'A braya no le gusta la musica electronica'. Ninguna linea del codigo los tocaba nunca.
#
# LO QUE ESTE BANCO PROTEGE, por orden de miedo:
#   1. que un zip NO se corrompa a medias (se trabaja en .tmp y se mueve al final)
#   2. que con el perfil vivo vacio NO se vacien las copias (la guarda que la idea no pedia)
#   3. que un zip ilegible NO bloquee la poda, y que un fallo AL ESCRIBIR si la pare
#   4. que lo que sigue vivo NO se toque, y que el resto del zip quede intacto
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
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($f in @('ConvertTo-Plain', 'Get-DatoSinCola', 'Get-DatosPerfil', 'Update-CopiaPodada', 'Invoke-PodaCopias')) { Invoke-Expression (Traer $f) }
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
$script:stats = @()
function Add-Estadistica([string]$r, [string]$d = '') { $script:stats += @($r) }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-poda-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$CopiasDir = Join-Path $tmp 'copias'
New-Item -ItemType Directory -Path $CopiasDir -Force | Out-Null
$PerfilPath = Join-Path $tmp 'perfil.md'
$UTF8 = New-Object Text.UTF8Encoding($false)

# --- el mundo de mentira: un perfil vivo con 2 datos y zips con 4 ---
function NuevoZip([string]$nombre, [string[]]$datos) {
    $carp = Join-Path $tmp ('arma-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
    $mem = Join-Path $carp 'memoria'
    New-Item -ItemType Directory -Path $mem -Force | Out-Null
    $lineas = @('# Lo que Nova sabe de braya', '') + @($datos | ForEach-Object { '- ' + $_ })
    [IO.File]::WriteAllLines((Join-Path $mem 'perfil.md'), [string[]]$lineas, $UTF8)
    # el resto del zip, que la poda NO debe tocar
    [IO.File]::WriteAllText((Join-Path $mem 'perfil-todo.md'), ('- lo permanente no se poda nunca' + [Environment]::NewLine))
    [IO.File]::WriteAllText((Join-Path $carp 'traducciones.json'), '{"a":"b"}')
    $z = Join-Path $CopiasDir $nombre
    Compress-Archive -Path (Join-Path $carp '*') -DestinationPath $z -Force
    Remove-Item -LiteralPath $carp -Recurse -Force
    return $z
}
function DentroDelZip([string]$z, [string]$entrada) {
    $za = [IO.Compression.ZipFile]::OpenRead($z)
    try {
        $e = @($za.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq $entrada })[0]
        if (-not $e) { return $null }
        $sr = New-Object IO.StreamReader($e.Open(), $UTF8)
        $t = $sr.ReadToEnd(); $sr.Close(); return $t
    } finally { $za.Dispose() }
}
function EntradasDe([string]$z) {
    $za = [IO.Compression.ZipFile]::OpenRead($z)
    try { return @($za.Entries | ForEach-Object { $_.FullName.Replace('\', '/') }) } finally { $za.Dispose() }
}
function LineasDato([string]$texto) { return @(($texto -split '\r?\n') | Where-Object { $_ -match '^- ' }) }

try {
    [IO.File]::WriteAllLines($PerfilPath, [string[]]@('# perfil', '', '- braya juega a Hollow Knight', '- braya vive en Mexico'), $UTF8)
    $viejos = @('braya juega a Hollow Knight', 'braya vive en Mexico',
                'Braya considera que Nova se equivoca frecuentemente', 'A braya no le gusta la musica electronica')
    $z1 = NuevoZip 'lo-aprendido_2026-09-10_1000.zip' $viejos
    $z2 = NuevoZip 'lo-aprendido_2026-09-11_1000.zip' $viejos
    $z3 = NuevoZip 'lo-aprendido_2026-09-12_1000.zip' $viejos

    Write-Host '-- 1. una pasada las deja todas limpias --'
    # A UNA POR DIA NO LLEGABA: solo se guardan las 14 ultimas copias, asi que las viejas salen
    # de la rotacion antes de que les toque el turno. El miedo a corromper se cubre con el .tmp
    # de cada zip y con el corte en el primer fallo de escritura (seccion 5).
    $r1 = Invoke-PodaCopias
    Comp '1a. poda las tres' ($r1 -and $r1.copias -eq 3) ([string]$r1.copias)
    Comp '1b. y quita dos huerfanos de cada una' ($r1.quitadas -eq 6) ([string]$r1.quitadas)
    $p1 = DentroDelZip $z1 'memoria/perfil.md'
    Comp '1c. lo huerfano ya no esta' (($p1 -notmatch 'se equivoca frecuentemente') -and ($p1 -notmatch 'musica electronica')) ''
    Comp '1d. y lo que sigue vivo SI esta' (($p1 -match 'Hollow Knight') -and ($p1 -match 'Mexico')) ''
    Comp '1e. la cabecera del fichero no se pierde' ($p1 -match 'Lo que Nova sabe') ''
    $p2 = DentroDelZip $z2 'memoria/perfil.md'
    Comp '1f. y las otras dos tambien estan limpias' (($p2 -notmatch 'se equivoca frecuentemente') -and ($p2 -match 'Hollow Knight')) ''

    Write-Host ''
    Write-Host '-- 2. el resto del zip queda igual --'
    $ents = EntradasDe $z1
    Comp '2a. siguen todas las entradas' ($ents.Count -eq (EntradasDe $z2).Count) ([string]$ents.Count + ' vs ' + [string](EntradasDe $z2).Count)
    Comp '2b. la permanente sigue dentro y sin tocar' ((DentroDelZip $z1 'memoria/perfil-todo.md') -match 'no se poda nunca') 'lo que braya pidio que no se borre'
    Comp '2c. y lo que no es el perfil, igual' ((DentroDelZip $z1 'traducciones.json') -eq '{"a":"b"}') ''
    Comp '2d. no queda ningun .tmp por el suelo' (@(Get-ChildItem -LiteralPath $CopiasDir -Filter '*.tmp' -ErrorAction SilentlyContinue).Count -eq 0) ''
    Comp '2e. el zip se puede seguir abriendo (no esta corrupto)' ([bool](DentroDelZip $z1 'memoria/perfil.md')) ''

    Write-Host ''
    Write-Host '-- 3. lo ya limpio no se vuelve a tocar --'
    $antes3 = @(Get-ChildItem -LiteralPath $CopiasDir -Filter '*.zip' | ForEach-Object { $_.LastWriteTime.Ticks })
    $r4 = Invoke-PodaCopias
    $desp3 = @(Get-ChildItem -LiteralPath $CopiasDir -Filter '*.zip' | ForEach-Object { $_.LastWriteTime.Ticks })
    Comp '3a. con todas limpias, no hace nada' ($null -eq $r4) 'y no devuelve un falso positivo'
    Comp '3b. y no reescribe ni un zip' ((($antes3 -join ',') -eq ($desp3 -join ','))) 'misma fecha de modificacion'

    Write-Host ''
    Write-Host '-- 4. LA GUARDA GORDA: perfil vivo vacio = no se toca nada --'
    $z4 = NuevoZip 'lo-aprendido_2026-09-13_1000.zip' $viejos
    [IO.File]::WriteAllLines($PerfilPath, [string[]]@('# perfil', ''), $UTF8)
    $script:logs = @()
    $r5 = Invoke-PodaCopias
    $p4 = DentroDelZip $z4 'memoria/perfil.md'
    Comp '4a. no poda nada' ($null -eq $r5) ''
    Comp '4b. y la copia conserva sus cuatro datos' ((LineasDato $p4).Count -eq 4) ([string](LineasDato $p4).Count)
    Comp '4c. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'perfil vivo esta vacio' }).Count -eq 1) ''

    Write-Host ''
    Write-Host '-- 5. un zip roto no se lleva a los demas --'
    [IO.File]::WriteAllLines($PerfilPath, [string[]]@('# perfil', '', '- braya juega a Hollow Knight'), $UTF8)
    $roto = Join-Path $CopiasDir 'lo-aprendido_2026-09-09_1000.zip'
    [IO.File]::WriteAllText($roto, 'esto no es un zip')
    $script:logs = @()
    $r6 = Invoke-PodaCopias
    Comp '5a. el zip ilegible NO bloquea: poda las demas' ($r6 -and $r6.copias -ge 1) ([string]$r6.copias + ' copias')
    Comp '5b. el roto se queda como estaba' ([IO.File]::ReadAllText($roto) -eq 'esto no es un zip') 'no se borra lo que no se entiende'
    Comp '5c. y lo apunta en el registro' (@($script:logs | Where-Object { $_ -match 'COPIA poda' }).Count -ge 1) ''
    Comp '5d. sin .tmp huerfanos tras el fallo' (@(Get-ChildItem -LiteralPath $CopiasDir -Filter '*.tmp' -ErrorAction SilentlyContinue).Count -eq 0) 'la guarda del .tmp'

    Write-Host ''
    Write-Host '-- 6. UN FALLO AL ESCRIBIR PARA LA PASADA (lo que la idea queria con el -una por dia-) --'
    # Se limpia la carpeta y se ponen tres con huerfanos; la de en medio se bloquea con un handle
    # exclusivo para que el Move-Item no pueda ponerla en su sitio. Esperado: la primera se poda,
    # la segunda falla y la TERCERA no se toca.
    Get-ChildItem -LiteralPath $CopiasDir -File | Remove-Item -Force
    [IO.File]::WriteAllLines($PerfilPath, [string[]]@('# perfil', '', '- braya juega a Hollow Knight', '- braya vive en Mexico'), $UTF8)
    $a6 = NuevoZip 'lo-aprendido_2026-09-01_1000.zip' $viejos
    $b6 = NuevoZip 'lo-aprendido_2026-09-02_1000.zip' $viejos
    $c6 = NuevoZip 'lo-aprendido_2026-09-03_1000.zip' $viejos
    $script:logs = @()
    # share 'Read': se puede LEER (asi que la poda la lee y reescribe su .tmp sin problema) pero
    # NO reemplazar, que es justo el fallo al escribir que se quiere probar. Con 'None' ni se
    # podria leer y entraria por la rama del zip ilegible, que es otra cosa.
    $bloqueo = [IO.File]::Open($b6, 'Open', 'Read', 'Read')
    try { $r7 = Invoke-PodaCopias } finally { $bloqueo.Close(); $bloqueo.Dispose() }
    Comp '6a. la primera se poda' ((LineasDato (DentroDelZip $a6 'memoria/perfil.md')).Count -eq 2) ([string](LineasDato (DentroDelZip $a6 'memoria/perfil.md')).Count)
    Comp '6b. la bloqueada se queda ENTERA con sus cuatro' ((LineasDato (DentroDelZip $b6 'memoria/perfil.md')).Count -eq 4) 'el .tmp nunca llego a su sitio'
    Comp '6c. y la TERCERA no se toca: la pasada se paro' ((LineasDato (DentroDelZip $c6 'memoria/perfil.md')).Count -eq 4) 'un fallo se lleva una copia como mucho'
    Comp '6d. y lo dice en el registro' (@($script:logs | Where-Object { $_ -match 'parada en lo-aprendido_2026-09-02' }).Count -eq 1) ''
    Comp '6e. sin .tmp por el suelo' (@(Get-ChildItem -LiteralPath $CopiasDir -Filter '*.tmp' -ErrorAction SilentlyContinue).Count -eq 0) ''
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'lo que el perfil tiro ya no revive en las copias' -ForegroundColor Green
exit 0
