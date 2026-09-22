# Comprueba que cada frase acaba en LA ACCION QUE TOCA, no solo que se
# entienda. El resto del banco cuenta cuantas se reconocen, y ese numero no ve
# las colisiones: dos ordenes pueden entenderse las dos y una haberse comido a
# la otra. La lista esta en pruebas\destinos.txt, con el porque.
$raiz = Split-Path -Parent $PSScriptRoot
$lista = Join-Path $raiz 'pruebas\destinos.txt'
if (-not (Test-Path -LiteralPath $lista)) { Write-Host "falta $lista"; exit 1 }

$esperado = [ordered]@{}
$conMarca = @{}
$saltadas = @{}
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
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
