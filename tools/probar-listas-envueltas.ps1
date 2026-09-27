# EL @() SOBRE UNA LISTA ENVUELTA: EL FALLO QUE HA VUELTO CUATRO VECES (27/09)
#
# LA TRAMPA. En PowerShell, una funcion que devuelve una coleccion con 'return $l' la DESENROLLA:
# si dentro hay un solo hashtable, el llamador recibe el hashtable y su .Count son las claves. La
# casa lo arregla desde hace tiempo con 'return ,$l' o 'return ,@($l)', que envuelve la lista para
# que llegue de una pieza. PERO entonces el llamador NO debe poner @() encima: eso le da un array
# de UNO con la lista dentro, y .Count vale 1 SIEMPRE, con cero elementos o con cuarenta.
#
# LAS CUATRO VECES, y lo que costo cada una:
#   1. Get-ProcesosNova (idea 111). Con un proceso vivo parecia funcionar -PowerShell saca la
#      propiedad del unico elemento- y con tres se media el mismo tres veces.
#   2. Get-FicherosMemoria (idea 115). La lista salia vacia siempre.
#   3. Get-Importante (idea 117). El caso "sin fichero, lista vacia" daba 1.
#   4. Get-JuegosDeSteamDelDia (idea 113), Y ESTA LLEGO A PRODUCCION. Con DOS juegos de Steam el
#      mismo dia -el 25/09 hubo CUATRO- la guarda '$st.Count -eq 1' de Find-CiegosDeUnDia pasaba
#      igual, asi que Nova aprendia 'ELDEN RING NIGHTREIGN The Past Within' como nombre de juego: lo
#      escribia en juegos-exes.json, lo metia de clave en juegos-ciegos.json y lo DECIA por el
#      altavoz. Justo lo que el comentario de esa guarda prohibe con todas las letras.
#   Y dos mas que llevaban ahi de antes: Get-Contactos (el contacto importante no se podia acertar)
#   y Get-MusicaNo (Nova contestaba 'tengo 1: ' con la lista vacia).
#
# POR ESO ESTE BANCO NO PRUEBA UNA PIEZA: AUDITA EL FICHERO ENTERO. Un fallo que vuelve cuatro veces
# no se arregla arreglandolo, se arregla poniendo algo que no le deje volver. Busca por AST todas las
# funciones que devuelven envuelto y luego todos los sitios que les ponen @() encima. Si manana
# alguien escribe el quinto, esto se pone rojo antes de que llegue a producirse.
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}

# LOS FICHEROS DE POWERSHELL DE LA CASA, no solo el assistant: el fallo puede nacer en cualquiera.
$ficheros = @(@(Join-Path $Raiz 'assistant.ps1') + @(Get-ChildItem -LiteralPath $Raiz -Filter '*.ps1' -File | ForEach-Object { $_.FullName }) | Sort-Object -Unique)
Comp 'hay ficheros que auditar' ($ficheros.Count -ge 1) ([string]$ficheros.Count + ' .ps1 de la raiz')

Write-Host ''
Write-Host '-- 1. QUIEN DEVUELVE LISTAS ENVUELTAS --'
$envuelven = @{}
foreach ($f in $ficheros) {
    $err = $null
    $arbol = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$err)
    if ($err.Count -gt 0) { Comp ('el fichero ' + (Split-Path -Leaf $f) + ' se parsea') $false ([string]$err.Count + ' errores'); continue }
    foreach ($d in @($arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
        # 'return ,' al principio de una linea: la forma que la casa usa para envolver
        if ($d.Body.Extent.Text -match '(?m)^\s*return\s*,') { $envuelven[$d.Name] = $true }
    }
}
$nombres = @($envuelven.Keys | Sort-Object)
Comp '1a. las encuentra por AST' ($nombres.Count -ge 10) ([string]$nombres.Count + ' funciones')
Comp '1b. y estan las que se sabe que lo hacen' (('Get-Recetas', 'Get-Reglas', 'Get-TrabajoTiempos' | Where-Object { $nombres -contains $_ }).Count -eq 3) 'Get-Recetas, Get-Reglas, Get-TrabajoTiempos'
Write-Host ('       ' + ($nombres -join ', '))

Write-Host ''
Write-Host '-- 2. Y QUIEN LES PONE @() ENCIMA (EL FALLO) --'
$malos = @()
foreach ($f in $ficheros) {
    $corto = Split-Path -Leaf $f
    $lineas = [IO.File]::ReadAllLines($f)
    for ($i = 0; $i -lt $lineas.Count; $i++) {
        $l = [string]$lineas[$i]
        # los comentarios no cuentan: este mismo banco y los comentarios del codigo hablan del patron
        if ($l.TrimStart().StartsWith('#')) { continue }
        foreach ($fn in $nombres) {
            if ($l -match ('@\(\s*' + [regex]::Escape($fn) + '(\s|\)|$)')) {
                $malos += @(('{0}:{1}  {2}' -f $corto, ($i + 1), $l.Trim()))
            }
        }
    }
}
foreach ($m in $malos) { Write-Host ('       ' + $m) -ForegroundColor Red }
Comp '2a. ni un @() sobre una lista envuelta' ($malos.Count -eq 0) $(if ($malos.Count) { [string]$malos.Count + ' sitios, arriba' } else { 'ninguno en ' + $ficheros.Count + ' ficheros' })

Write-Host ''
Write-Host '-- 3. QUE EL BANCO SEPA ENCONTRARLO DE VERDAD --'
# UN BANCO QUE SOLO DICE "no hay ninguno" NO VALE: podria estar mirando mal y siempre saldria verde.
# Asi que se le da un fichero de mentira CON el fallo dentro y se comprueba que lo caza.
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-envuelta-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
@'
function Get-CosasDeMentira {
    $l = New-Object System.Collections.ArrayList
    [void]$l.Add(@{ a = 1 })
    return ,@($l)
}
$bien = Get-CosasDeMentira
$malo = @(Get-CosasDeMentira)
'@ | Set-Content -LiteralPath $tmp -Encoding UTF8
try {
    $err2 = $null
    $ar2 = [System.Management.Automation.Language.Parser]::ParseFile($tmp, [ref]$null, [ref]$err2)
    $env2 = @()
    foreach ($d in @($ar2.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))) {
        if ($d.Body.Extent.Text -match '(?m)^\s*return\s*,') { $env2 += $d.Name }
    }
    Comp '3a. reconoce una funcion que envuelve' ($env2 -contains 'Get-CosasDeMentira') ([string]@($env2).Count + ' encontrada(s))')
    $l2 = [IO.File]::ReadAllLines($tmp)
    $pilla = @($l2 | Where-Object { $_ -match '@\(\s*Get-CosasDeMentira(\s|\)|$)' })
    Comp '3b. y caza el @() que le pusieron encima' ($pilla.Count -eq 1) ([string]$pilla.Count + ' de 1')
    Comp '3c. sin confundirse con el llamador bueno' (-not ($pilla -join '' -match '\$bien')) 'el de sin @() no se toca'
    # Y LA PRUEBA DE QUE EL FALLO ES REAL, ejecutandolo: con @() la cuenta miente
    . $tmp
    Comp '3d. y la cuenta miente de verdad' ((@(Get-CosasDeMentira).Count -eq 1) -and ((Get-CosasDeMentira).Count -eq 1)) 'con una sola cosa dentro las dos dan 1: por eso pasa desapercibido'
    # con DOS, que es donde se nota
    $dos = [scriptblock]::Create(@'
function Get-DosDeMentira { $l = New-Object System.Collections.ArrayList; [void]$l.Add(@{a=1}); [void]$l.Add(@{a=2}); return ,@($l) }
'@)
    . $dos
    Comp '3e. con DOS, el @() dice 1 y sin el dice 2' ((@(Get-DosDeMentira).Count -eq 1) -and ((Get-DosDeMentira).Count -eq 2)) 'ahi esta el fallo que llego a produccion'
} finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 4. LOS CUATRO SITIOS QUE YA SE ARREGLARON SIGUEN ARREGLADOS --'
$asis = [IO.File]::ReadAllText((Join-Path $Raiz 'assistant.ps1'))
foreach ($caso in @(
    @{ n = 'Get-JuegosDeSteamDelDia'; v = '$deSteam = Get-JuegosDeSteamDelDia $dia'; q = 'el que llego a produccion' }
    @{ n = 'Get-VozTiempos';          v = '$vz = Get-VozTiempos';                   q = 'el plazo de la voz' }
    @{ n = 'Get-Contactos';           v = '$importantes = Get-Contactos';           q = 'el contacto importante' }
    @{ n = 'Get-MusicaNo';            v = '$lN = Get-MusicaNo';                     q = 'la lista de lo que no le gusta' }
)) {
    Comp ('4. ' + $caso.n + ' se llama sin @()') ($asis.Contains($caso.v)) ([string]$caso.q)
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'ni un @() sobre una lista envuelta en toda la casa' -ForegroundColor Green
exit 0
