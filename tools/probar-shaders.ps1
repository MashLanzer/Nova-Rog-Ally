# LA CACHE DE SHADERS, QUE NADIE VACIA (1/10, la 10 de las 20 funciones nuevas)
#
# MEDIDO EN ESTA CONSOLA: 902 MB en DxcCache, 74,7 en DxCache, 3,2 en D3DSCache, 0,6 en VkCache.
# Casi un giga con 27 GB libres de 476. Y el segundo motivo, que es el que la pone en la lista: al
# cambiar la VRAM hay que vaciarla o los juegos petardean, y eso es algo que braya tiene que
# acordarse de hacer a mano.
#
# AQUI NO SE BORRA NADA DE VERDAD: las carpetas son de pega, dentro de un LOCALAPPDATA de pega. Un
# banco que vacie la cache de shaders de braya cada vez que corre la bateria le hace ir mas lento el
# primer arranque de cada juego, y eso no lo decide un banco.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-shaders-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$viejoLocal = $env:LOCALAPPDATA
try {
    $MemoriaDir = $tmp
    $VramVistaPath = Join-Path $tmp 'vram-vista.json'
    $ShadersSitios = @('AMD\DxCache', 'AMD\DxcCache', 'D3DSCache')
    foreach ($n in @('Write-Atomico', 'Get-CacheShaders', 'Get-FraseCacheShaders', 'Clear-CacheShaders', 'Watch-VramCambiada')) {
        Invoke-Expression (Traer $n)
    }
    $script:dichos = @()
    function Log([string]$m) { $script:dichos += $m }
    $script:avisos = @()
    function Send-AvisoEntorno { param($c, $t, $n, $cada, $forzar) $script:avisos += ($c + '|' + $t); return $true }
    $script:juegoActivo = ''

    # las cachés de pega: una gorda, una pequena y una que no existe
    $env:LOCALAPPDATA = $tmp
    foreach ($par in @(@('AMD\DxcCache', 9), @('AMD\DxCache', 3))) {
        $d = Join-Path $tmp $par[0]
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        for ($i = 0; $i -lt $par[1]; $i++) {
            [IO.File]::WriteAllBytes((Join-Path $d ("sh$i.bin")), (New-Object byte[] (100KB)))
        }
    }

    Write-Host ''
    Write-Host '-- 1. encuentra las cachés y las ordena por tamano --'
    $l = @(Get-CacheShaders)
    Comp 'encuentra las dos que existen' ($l.Count -eq 2) "$($l.Count) (la tercera no existe y no se inventa)"
    Comp '  y la gorda va primero' ($l[0].nombre -eq 'DxcCache') "$($l[0].nombre)"
    Comp '  con su cuenta de ficheros' ($l[0].n -eq 9) "$($l[0].n)"

    Write-Host ''
    Write-Host '-- 2. la frase: cuanto ocupa y quien tiene la culpa --'
    $f = Get-FraseCacheShaders
    Comp 'dice los megas' ($f -match '1\d{2} megas|\d+ megas') "$f"
    Comp '  y cual es la mas gorda' ($f -match 'DxcCache') ''
    Comp '  y dice que se regenera sola' ($f -match 'regenera sola') 'si no, da miedo borrarla'

    Write-Host ''
    Write-Host '-- 3. CON UN JUEGO DELANTE NO SE TOCA --'
    # Sus ficheros los puede tener abiertos el juego: borrar por debajo de un proceso que lee es
    # pedir un cuelgue, y un cuelgue a mitad de partida es lo peor que puede hacer esta funcion.
    $script:juegoActivo = 'Juego De Pega'
    $r = Clear-CacheShaders
    Comp 'se niega y dice por que' ($r -match 'Mejor no' -and $r -match 'Juego De Pega') "$r"
    Comp '  y NO ha borrado nada' (@(Get-CacheShaders)[0].n -eq 9) 'siguen los nueve ficheros'
    $script:juegoActivo = ''

    Write-Host ''
    Write-Host '-- 4. sin juego, la vacia y dice cuanto solto --'
    $r2 = Clear-CacheShaders
    Comp 'dice los megas que ha soltado' ($r2 -match 'megas libres') "$r2"
    Comp '  y avisa de que el primer arranque tarda mas' ($r2 -match 'tardara un poco mas') ''
    Comp '  y de verdad quedan vacias' (@(Get-CacheShaders).Count -eq 0) 'sin ficheros, no salen en la lista'
    # LAS CARPETAS SE QUEDAN: si desaparecen, algunos drivers dejan de cachear hasta reiniciar y
    # entonces TODO va mas lento, que es lo contrario de lo que se venia a hacer.
    Comp '  pero las carpetas siguen ahi' (Test-Path -LiteralPath (Join-Path $tmp 'AMD\DxcCache')) 'borrarlas deja al driver sin cachear'

    Write-Host ''
    Write-Host '-- 5. el aviso cuando cambia la VRAM --'
    # Es la mitad que de verdad hacia falta: ese es el momento de vaciarla y el que se olvida.
    $script:avisos = @()
    function Get-CimInstance { param($ClassName, $Namespace, $Filter, $ErrorAction) return @([pscustomobject]@{ AdapterRAM = 4GB }) }
    Watch-VramCambiada
    Comp 'la primera vez solo apunta, no avisa' ($script:avisos.Count -eq 0) 'sin un valor anterior no hay cambio que contar'
    Comp '  y deja la VRAM apuntada' (Test-Path -LiteralPath $VramVistaPath) ''
    Watch-VramCambiada
    Comp '  y si no cambia, sigue callada' ($script:avisos.Count -eq 0) ''
    function Get-CimInstance { param($ClassName, $Namespace, $Filter, $ErrorAction) return @([pscustomobject]@{ AdapterRAM = 8GB }) }
    Watch-VramCambiada
    Comp 'al cambiar de 4 a 8 GB, avisa' ($script:avisos.Count -eq 1) "$($script:avisos.Count)"
    Comp '  y dice los dos valores' ($script:avisos[0] -match '4' -and $script:avisos[0] -match '8') "$($script:avisos[0])"
    Comp '  y dice que hay que vaciar la cache' ($script:avisos[0] -match 'cache de shaders') ''
} finally {
    $env:LOCALAPPDATA = $viejoLocal
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 6. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca shaders' ($sinCom -match "kind = 'shaders'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'shaders' \{") ''
Comp '  y la VRAM se mira al arrancar' ($sinCom -match 'Watch-VramCambiada') ''
# Y NO EN EL BUCLE: la VRAM se cambia en la BIOS o en Armoury y eso pide reiniciar, asi que mirarlo
# cada vuelta seria mirar algo que no puede cambiar mientras Nova corre.
$iW = $sinCom.IndexOf('Watch-VramCambiada')
$iBucle = $sinCom.IndexOf('--- PALABRA DE ACTIVACION')
Comp '  y se mira ANTES del bucle' ($iW -gt 0 -and ($iBucle -lt 0 -or $iW -lt $iBucle)) 'la VRAM no cambia con Nova encendida'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova vacia la cache de shaders, y avisa cuando le cambias la VRAM' -ForegroundColor Green
exit 0
