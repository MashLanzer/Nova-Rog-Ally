# LOS TEMPORALES QUE NADIE VUELVE A MIRAR (26/09, idea 10 de las 121).
#
# EL CASO QUE LO DESTAPO: tmp\clave.txt, 109 bytes, del 12 de septiembre, con una clave de la
# API de Anthropic EN CLARO. Catorce dias ahi. Y nadie la lee: cero referencias en todo el
# codigo, es residuo de una prueba.
# Un matiz honesto: tmp\ esta en el .gitignore desde la linea 7 y "git ls-files tmp" sale
# vacio, asi que NO viajo al repositorio publico. Lo que lleva catorce dias es en el DISCO.
#
# MEDIDO sobre los 134 ficheros del primer nivel de tmp: 96 llevan mas de 7 dias sin tocarse y
# el codigo no los nombra. Son 12,1 MB. Y el reparto de edades deja un hueco limpio: hay
# ficheros de 0-1 dia y de 9-14, y NI UNO entre 7 y 9.
#
# LO QUE MAS VIGILA ESTE BANCO no es que borre, es QUE NO BORRE DE MAS. Un fichero de tmp que
# el codigo lee -mi-voz.json es la huella de la voz de braya y puede pasar semanas sin
# reescribirse- no es basura: perderlo seria perder algo que costo conseguir.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. la lista de intocables esta COMPLETA --'
# ESTA ES LA COMPROBACION QUE IMPIDE EL DESASTRE, y es la misma idea que el .gitignore
# vigilado de esta manana: una lista escrita a mano caduca sola. Si manana alguien anade un
# fichero nuevo a tmp y no lo mete en $TmpVivos, el barrido se lo comeria a los siete dias.
$m = [regex]::Match($txt, '(?ms)^\$TmpVivos = @\((.*?)^\)')
Comp 'se encuentra $TmpVivos' $m.Success ''
$vivos = @()
if ($m.Success) { $vivos = @([regex]::Matches($m.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }) }
Comp "  con nombres dentro" ($vivos.Count -ge 20) "$($vivos.Count) nombres"
# LO QUE EL CODIGO NOMBRA Y ESTA EN tmp TIENE QUE ESTAR EN LA LISTA
$pat = "['`"]([A-Za-z0-9_-]+\.(?:txt|json|flag|log|wav|png|md|jsonl|lock))['`"]"
$mencionados = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($f in @('assistant.ps1', 'wake_vosk.py', 'charla_worker.py', 'charla_memoria.py', 'tts_worker.py', 'nova_ui.cs', 'assistant-dx.cs', 'voz_windows.py')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    $t = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
    foreach ($mm in [regex]::Matches($t, $pat)) { [void]$mencionados.Add($mm.Groups[1].Value) }
}
# OJO CON EL NOMBRE: en PowerShell $tmpDir y $TmpDir son la MISMA variable, y mas abajo se le
# da a $TmpDir la carpeta de mentira. La primera version de este banco se quedaba sin la
# carpeta de verdad y la seccion 5 no media nada, en silencio. Es el mismo tropiezo que ya
# tienen documentado $ok/$OK y $AnimoLargoDias/$animoLargoDias.
$carpetaTmpReal = Join-Path $raiz 'tmp'
$faltan = @()
if (Test-Path -LiteralPath $carpetaTmpReal) {
    foreach ($f in @(Get-ChildItem -LiteralPath $carpetaTmpReal -File -ErrorAction SilentlyContinue)) {
        if (-not $mencionados.Contains($f.Name)) { continue }
        if ($f.Extension -in @('.lock', '.flag')) { continue }
        if ($vivos -notcontains $f.Name) { $faltan += $f.Name }
    }
}
Comp '  y no falta ninguno de los que el codigo nombra' ($faltan.Count -eq 0) $(
    if ($faltan.Count) { "FALTAN: " + ($faltan -join ', ') } else { "comprobados contra $($mencionados.Count) nombres del codigo" })
# LOS QUE DE VERDAD DUELEN, por su nombre: si alguien los quita de la lista, que se vea.
foreach ($v in @('mi-voz.json', 'escucha-estado.txt', 'ganancia.txt', 'voces.json', 'gestos.log')) {
    Comp "  protege $v" ($vivos -contains $v) $(switch ($v) {
        'mi-voz.json' { 'la huella de la voz de braya' }
        'ganancia.txt' { 'lo que el oido ha aprendido de su microfono' }
        'voces.json' { 'las voces de la casa' }
        default { '' } })
}

Write-Host ''
Write-Host '-- 2. el plazo, y de donde sale --'
$mD = [regex]::Match($txt, '(?m)^\$TmpVidaDias\s*=\s*([0-9]+)')
Comp 'se saca del archivo TmpVidaDias' $mD.Success ''
if ($mD.Success) { $TmpVidaDias = [int]$mD.Groups[1].Value }
# NO ES UN NUMERO NUEVO: $CachesLimpiables ya usa 7 para "un temporal de Windows es viejo".
Comp '  es el mismo 7 que ya usaba la casa' ($TmpVidaDias -eq 7) 'dias = 7 en $CachesLimpiables'
Comp '  y no baja de 3' ($TmpVidaDias -ge 3) 'probar-disco-limpia exige al menos 3'

Write-Host ''
Write-Host '-- 3. la funcion, ejecutada sobre una carpeta de mentira --'
$dC = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Clear-TmpViejo' }, $true)
Comp 'existe Clear-TmpViejo' ($null -ne $dC) ''
$llam = @([regex]::Matches($sinCom, '(?<!function )Clear-TmpViejo')).Count
Comp '  y alguien la llama' ($llam -ge 1) "$llam llamada(s)"
if ($dC) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-tmp-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $TmpDir = $tmp
    $TmpVivos = $vivos
    $script:avisos = @()
    function Log([string]$m) { }
    function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60, [bool]$ya = $false) {
        $script:avisos += @{ clave = $clave; nivel = $nivel; texto = $texto }; return $true
    }
    Invoke-Expression $dC.Extent.Text
    function Poner([string]$n, [string]$c, [int]$dias) {
        $p = Join-Path $tmp $n
        [IO.File]::WriteAllText($p, $c)
        (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-1 * $dias)
    }
    try {
        Poner 'basura-vieja.txt' 'nada' 14
        Poner 'basura-de-ayer.txt' 'nada' 1
        Poner 'mi-voz.json' '{"f0":115}' 40          # VIEJISIMO Y VIVO: no se toca jamas
        Poner 'corte.flag' '' 30                     # una senal, no un dato
        Poner 'algo.lock' '' 30
        Poner 'clave.txt' 'ANTHROPIC_API_KEY=sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAA' 14
        $r = Clear-TmpViejo $tmp
        Comp 'suelta lo viejo y huerfano' ((Test-Path -LiteralPath (Join-Path $tmp 'basura-vieja.txt')) -eq $false) ''
        Comp '  y no toca lo de ayer' (Test-Path -LiteralPath (Join-Path $tmp 'basura-de-ayer.txt')) "el plazo son $TmpVidaDias dias"
        Comp '  NI lo que el codigo lee, por viejo que sea' (Test-Path -LiteralPath (Join-Path $tmp 'mi-voz.json')) '40 dias, y es la huella de la voz'
        Comp '  ni las senales (.flag)' (Test-Path -LiteralPath (Join-Path $tmp 'corte.flag')) 'valen cero bytes y su ausencia significa algo'
        Comp '  ni los cerrojos (.lock)' (Test-Path -LiteralPath (Join-Path $tmp 'algo.lock')) ''
        Comp 'y la cuenta cuadra' ($r.ficheros -eq 2) "$($r.ficheros) ficheros: la basura vieja y la clave"
        # EL SECRETO: se avisa ANTES de borrarlo. Si se borrara callando, braya no se entera
        # nunca de que tiene una clave que rotar, que es lo unico que de verdad hay que hacer.
        Comp 'una clave en claro se AVISA' ($script:avisos.Count -eq 1 -and $script:avisos[0].clave -eq 'secreto-en-claro') "$($script:avisos.Count) aviso(s)"
        Comp '  con nivel alto' ($script:avisos.Count -gt 0 -and $script:avisos[0].nivel -eq 'alto') 'una clave expuesta no espera a que acabes de jugar'
        Comp '  diciendo que hay que cambiarla' ($script:avisos.Count -gt 0 -and $script:avisos[0].texto -match 'cambiar') 'borrarla no la desexpone'
        Comp '  y ademas se borra' ((Test-Path -LiteralPath (Join-Path $tmp 'clave.txt')) -eq $false) ''
        # SEGUNDA PASADA: ya no queda nada que soltar ni nada que avisar
        $script:avisos = @()
        $r2 = Clear-TmpViejo $tmp
        Comp 'a la segunda no queda nada' ($r2.ficheros -eq 0 -and $script:avisos.Count -eq 0) ''
        # Y SIN CARPETA, NI REVIENTA NI INVENTA
        $r3 = Clear-TmpViejo (Join-Path $tmp 'no-existe')
        Comp 'sin carpeta, ni revienta' ($r3.ficheros -eq 0) ''
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host '-- 4. y no se mete donde no le llaman --'
if ($dC) {
    $c = $dC.Extent.Text
    Comp 'no baja a los subdirectorios' ($c -notmatch '-Recurse') 'tmp\voz es la cache de la voz y tiene dueno'
    Comp '  ni borra directorios' ($c -match 'Get-ChildItem[^\r\n]*-File') ''
}
# tmp\voz TIENE DUENO: tts_worker.py la poda sola con su propio tope. Dos limpiadores sobre la
# misma carpeta es como se pierde una cache entera.
$tts = Join-Path $raiz 'tts_worker.py'
if (Test-Path -LiteralPath $tts) {
    $tt = [IO.File]::ReadAllText($tts, [Text.Encoding]::UTF8)
    Comp 'la cache de voz sigue teniendo su propio podador' ($tt -match 'CACHE_MAX_MB') 'por eso el barrido no baja ahi'
}

Write-Host ''
Write-Host '-- 5. contra la carpeta de verdad --'
if (Test-Path -LiteralPath $carpetaTmpReal) {
    $n = 0; $bytes = 0
    $lim = (Get-Date).AddDays(-1 * $TmpVidaDias)
    foreach ($f in @(Get-ChildItem -LiteralPath $carpetaTmpReal -File -ErrorAction SilentlyContinue)) {
        if ($vivos -contains $f.Name) { continue }
        if ($f.Extension -in @('.lock', '.flag')) { continue }
        if ($f.LastWriteTime -gt $lim) { continue }
        $n++; $bytes += $f.Length
    }
    Write-Host ("       en tmp hay $n fichero(s) de mas de $TmpVidaDias dias sin dueno: $([Math]::Round($bytes/1MB,1)) MB")
    Comp 'hay algo que soltar (o ya se solto)' ($n -ge 0) ''
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  los temporales viejos se sueltan, y lo que hace falta no se toca'
exit 0
