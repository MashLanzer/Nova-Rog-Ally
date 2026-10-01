# Comprueba que cada frase acaba en LA ACCION QUE TOCA, no solo que se
# entienda. El resto del banco cuenta cuantas se reconocen, y ese numero no ve
# las colisiones: dos ordenes pueden entenderse las dos y una haberse comido a
# la otra. La lista esta en pruebas\destinos.txt, con el porque.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$lista = Join-Path $raiz 'pruebas\destinos.txt'
if (-not (Test-Path -LiteralPath $lista)) { Write-Host "falta $lista"; exit 1 }

# LO QUE DEPENDE DE UNA CORRECCION QUE NOVA DURMIO (30/09). Nova poda sola la tabla del oido:
# lo que no se ha oido en once dias de uso real se MUEVE a 'correccionesDormidas' del propio
# commands.json, porque Repair-Words paga un regex por entrada en cada dictado (110 entradas son
# 1,125 ms; 16 son 0,145). Veintiocho casos de esta lista dependian de una de esas, asi que el
# banco se puso rojo el 30/09 SIN QUE NADIE TOCARA UNA LINEA DE CODIGO: su color lo decidia el
# estado que Nova cambia sola, que es tan malo como salir verde sin merecerlo.
# La marca '@si-corrige:<clave>' dice de que entrada depende el caso, y aqui se salta si esa
# entrada esta dormida. Es reversible por los dos lados: si la clave se despierta, el caso vuelve
# a probarse de verdad, y si se duerme otra, basta marcarla.
# ESTA LA RESUELVE ESTE BANCO, no el -Probar del archivo real: assistant.ps1 no conoce la marca.
$dormidas = @{}
$conocidas = @{}
$leiCommands = $false
try {
    $jc = Get-Content -LiteralPath (Join-Path $raiz 'commands.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($jc.PSObject.Properties['correccionesDormidas']) {
        foreach ($pr in $jc.correccionesDormidas.PSObject.Properties) { $dormidas[$pr.Name] = $true; $conocidas[$pr.Name] = $true }
    }
    if ($jc.PSObject.Properties['correcciones']) {
        foreach ($pr in $jc.correcciones.PSObject.Properties) { $conocidas[$pr.Name] = $true }
    }
    $leiCommands = $true
} catch {
    # SI NO SE PUEDE LEER, NO SE SALTA NADA: mejor rojo de mas que verde de menos.
    Write-Host "  OJO  no pude leer commands.json; no salto ningun caso por correccion dormida" -ForegroundColor Yellow
}

$esperado = [ordered]@{}
$conMarca = @{}
$saltadas = @{}
$sinCorreccion = [ordered]@{}
$marcasMalas = 0
foreach ($linea in (Get-Content -LiteralPath $lista -Encoding UTF8)) {
    $l = $linea.Trim()
    if (-not $l -or $l.StartsWith('#')) { continue }
    $p = $l -split '\s*=>\s*', 2
    if ($p.Count -ne 2) { Write-Host "  MAL  linea sin '=>': $l"; continue }
    # LO QUE DEPENDE DE UN JUEGO QUE YA NO TIENES (19/09): tres casos de esta lista se
    # pusieron rojos solos cuando Little Nightmares III y REANIMAL se desinstalaron de
    # Steam. La marca '@si-tienes:<juego>' va al final del destino y la resuelve el
    # propio -Probar del archivo real, que es quien lee la biblioteca de verdad.
    $frD = $p[0].Trim(); $deD = $p[1].Trim()
    # La de la correccion va PRIMERO porque en dos lineas van las dos juntas, y quitandola
    # antes el '@si-tienes' vuelve a quedar al final, que es donde su regex lo busca.
    $mCD = [regex]::Match($deD, '\s*@si-corrige:\s*(.+?)\s*$')
    if ($mCD.Success) {
        $claveCD = $mCD.Groups[1].Value.Trim()
        $deD = $deD.Substring(0, $mCD.Index).Trim()
        if ($dormidas.ContainsKey($claveCD)) { $sinCorreccion[$frD] = $claveCD }
        # Y QUIEN VIGILA LA MARCA: una clave mal escrita aqui no existe en ninguna de las dos
        # tablas, asi que nunca saltaria y nunca avisaria; el caso se quedaria probandose contra
        # una correccion que nadie tiene y el dia que falle, el motivo estaria escondido en un
        # typo. Con esto, equivocarse escribiendo la marca es rojo, no silencio.
        elseif ($leiCommands -and -not $conocidas.ContainsKey($claveCD)) {
            Write-Host ("  MAL  '@si-corrige:{0}' no existe en commands.json (ni viva ni dormida): {1}" -f $claveCD, $frD) -ForegroundColor Red
            $marcasMalas++
        }
    }
    $mJD = [regex]::Match($deD, '\s*@si-tienes:\s*(.+)$')
    if ($mJD.Success) {
        $conMarca[$frD] = $frD + '   @si-tienes:' + $mJD.Groups[1].Value.Trim()
        $deD = $deD.Substring(0, $mJD.Index).Trim()
    } else { $conMarca[$frD] = $frD }
    $esperado[$frD] = $deD
}

# se le pasan al probador del archivo real, que es el que sabe resolver
$tmp = Join-Path $env:TEMP ("destinos-" + [guid]::NewGuid().ToString('N') + ".txt")
[System.IO.File]::WriteAllLines($tmp, @($esperado.Keys | ForEach-Object { $conMarca[$_] }), (New-Object System.Text.UTF8Encoding($false)))
$salida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $raiz 'assistant.ps1') -Probar $tmp 2>&1
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

# "  OK    <frase>        ->  <lo que hace>"  /  "  ->IA  <frase>"
$obtenido = @{}
foreach ($l in $salida) {
    $t = [string]$l
    if ($t -match '^\s*OK\s+(.*?)\s+->\s+(.*)$') { $obtenido[$Matches[1].Trim()] = $Matches[2].Trim() }
    elseif ($t -match '^\s*->IA\s+(.*)$') { $obtenido[$Matches[1].Trim()] = '<se va al modelo>' }
    elseif ($t -match '^\s*SALTO\s+(.*?)\s+\(ya no tienes') { $saltadas[$Matches[1].Trim()] = $true }
}

$fallos = 0
foreach ($frase in $esperado.Keys) {
    if ($saltadas.ContainsKey($frase)) {
        Write-Host ("  SALTO {0,-31} (ese juego ya no esta instalado)" -f $frase) -ForegroundColor DarkGray
        continue
    }
    if ($sinCorreccion.Contains($frase)) {
        Write-Host ("  SALTO {0,-31} (Nova durmio '{1}': no se oyo en once dias)" -f $frase, $sinCorreccion[$frase]) -ForegroundColor DarkGray
        continue
    }
    $debe = $esperado[$frase]
    $hace = if ($obtenido.ContainsKey($frase)) { $obtenido[$frase] } else { '<sin respuesta del probador>' }
    # VARIAS METAS EN UNA LINEA (18/09): una cadena tiene que hacer TODO lo que promete.
    # Con una sola pieza, "abre steam y sube el brillo" pasaba mirando solo un trozo y podia
    # perderse un eslabon entero sin que el numero se moviera. El separador es ' + ', el
    # mismo que usa el probador al encadenar acciones.
    $metas = @($debe -split '\s\+\s' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    # Y EN EL ORDEN QUE PROMETEN (22/09). Esto era '-notlike "*$_*"', que tiene dos
    # agujeros y los dos se reprodujeron antes de tocarlo:
    #  1. NO EXIGE ORDEN. Una cadena de tres acciones devuelta AL REVES pasaba en verde:
    #     'abre steam + sube el brillo + pon modo noche' contra un resultado que hiciera
    #     exactamente lo contrario daba 0 faltas. Y el orden es justo lo que distingue
    #     "abre steam y luego pon modo noche" de "pon modo noche y luego abre steam".
    #  2. -like TRATA LA META COMO PATRON, no como texto: un '*', un '?' o unos corchetes
    #     dentro de lo esperado dejan de compararse literalmente y empiezan a casar cosas
    #     que nadie escribio.
    # IndexOf con StringComparison::Ordinal arregla los dos de una vez: es literal, y
    # avanzando $pos obliga a que cada eslabon aparezca DESPUES del anterior. Se conserva
    # lo de buscar por subcadena, que es lo que hacia falta: el probador devuelve la frase
    # entera y las metas son trozos suyos.
    $pos = 0
    $faltan = @()
    foreach ($m in $metas) {
        $i = $hace.IndexOf($m, [Math]::Min($pos, $hace.Length), [StringComparison]::Ordinal)
        if ($i -lt 0) { $faltan += $m } else { $pos = $i + $m.Length }
    }
    $ok = ($faltan.Count -eq 0)
    if ($ok) {
        Write-Host ("  OK   {0,-32} -> {1}" -f $frase, $hace)
    } else {
        # se dice CUAL falta: con cadenas de cuatro eslabones, "esperaba algo con ..." entero
        # no sirve de nada para arreglarlo
        Write-Host ("  MAL  {0,-32} -> {1}   (falta: '{2}')" -f $frase, $hace, ($faltan -join "' y '"))
        $fallos++
    }
}

Write-Host ""
# LO SALTADO SE DICE EN ALTO, y con el numero: un banco que se calla lo que no ha probado es un
# banco que puede vaciarse solo, marca a marca, sin que el verde cambie nunca de color.
if ($sinCorreccion.Count) {
    Write-Host ("{0} casos SALTADOS porque su correccion esta dormida (de {1} en la lista). Despertarla en commands.json los vuelve a probar." -f $sinCorreccion.Count, $esperado.Count) -ForegroundColor DarkGray
}
$fallos += $marcasMalas
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
