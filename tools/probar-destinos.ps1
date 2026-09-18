# Comprueba que cada frase acaba en LA ACCION QUE TOCA, no solo que se
# entienda. El resto del banco cuenta cuantas se reconocen, y ese numero no ve
# las colisiones: dos ordenes pueden entenderse las dos y una haberse comido a
# la otra. La lista esta en pruebas\destinos.txt, con el porque.
$raiz = Split-Path -Parent $PSScriptRoot
$lista = Join-Path $raiz 'pruebas\destinos.txt'
if (-not (Test-Path -LiteralPath $lista)) { Write-Host "falta $lista"; exit 1 }

$esperado = [ordered]@{}
foreach ($linea in (Get-Content -LiteralPath $lista -Encoding UTF8)) {
    $l = $linea.Trim()
    if (-not $l -or $l.StartsWith('#')) { continue }
    $p = $l -split '\s*=>\s*', 2
    if ($p.Count -ne 2) { Write-Host "  MAL  linea sin '=>': $l"; continue }
    $esperado[$p[0].Trim()] = $p[1].Trim()
}

# se le pasan al probador del archivo real, que es el que sabe resolver
$tmp = Join-Path $env:TEMP ("destinos-" + [guid]::NewGuid().ToString('N') + ".txt")
[System.IO.File]::WriteAllLines($tmp, @($esperado.Keys), (New-Object System.Text.UTF8Encoding($false)))
$salida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $raiz 'assistant.ps1') -Probar $tmp 2>&1
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

# "  OK    <frase>        ->  <lo que hace>"  /  "  ->IA  <frase>"
$obtenido = @{}
foreach ($l in $salida) {
    $t = [string]$l
    if ($t -match '^\s*OK\s+(.*?)\s+->\s+(.*)$') { $obtenido[$Matches[1].Trim()] = $Matches[2].Trim() }
    elseif ($t -match '^\s*->IA\s+(.*)$') { $obtenido[$Matches[1].Trim()] = '<se va al modelo>' }
}

$fallos = 0
foreach ($frase in $esperado.Keys) {
    $debe = $esperado[$frase]
    $hace = if ($obtenido.ContainsKey($frase)) { $obtenido[$frase] } else { '<sin respuesta del probador>' }
    # VARIAS METAS EN UNA LINEA (18/09): una cadena tiene que hacer TODO lo que promete.
    # Con una sola pieza, "abre steam y sube el brillo" pasaba mirando solo un trozo y podia
    # perderse un eslabon entero sin que el numero se moviera. El separador es ' + ', el
    # mismo que usa el probador al encadenar acciones.
    $metas = @($debe -split '\s\+\s' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $faltan = @($metas | Where-Object { $hace -notlike "*$_*" })
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
