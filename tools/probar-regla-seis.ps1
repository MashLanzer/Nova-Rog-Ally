# LA REGLA 6 DE LA CASA NO LA VIGILABA NADIE (25/09)
#
# LA REGLA, tal como esta escrita en NOVA-TODO: "Los .ps1 de tools\ van SIN BOM si son ASCII
# puro, CON BOM si llevan algo que no lo es -PowerShell 5.1 lee un .ps1 sin BOM como ANSI- y no
# llevan tildes ni n con virgulilla".
#
# POR QUE IMPORTA, y no es estetica: PowerShell 5.1 abre un .ps1 sin BOM como ANSI, no como
# UTF-8. Un fichero con una sola letra rara y sin BOM se lee con la letra cambiada, y lo que sale por
# pantalla -o lo que se compara contra el codigo- deja de ser lo que hay escrito. Es el mismo
# tipo de fallo que el 0x08 de la seccion 8: se lee bien y no es lo que hay.
#
# COMO SE DESTAPO: escribiendo un banco nuevo el 25/09 se colo uno asi -no ASCII y sin BOM- y
# la bateria entera paso en verde sin decir nada. Ninguna de las 204 secciones miraba esto.
#
# LO QUE SE EXIGE Y LO QUE SOLO SE CUENTA, que no es lo mismo:
#   - ROJO: un .ps1 con algo que no es ASCII y SIN BOM. Ese es el que se lee mal. Hoy: cero.
#   - se cuenta y no rompe: un .ps1 con BOM siendo ASCII puro. PowerShell lo lee igual de bien,
#     asi que ponerlo en rojo seria pedir una limpieza que no arregla nada.
#   - TRINQUETE con las tildes: hay 28 ficheros que las llevan de antes. No se exige quitarlas
#     -seria tocar 28 ficheros por gusto-, pero el numero SOLO PUEDE BAJAR. Igual que el techo
#     de las expresiones fragiles.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}

$ficheros = @(Get-ChildItem -LiteralPath $raiz -Filter '*.ps1' -File) +
            @(Get-ChildItem -LiteralPath (Join-Path $raiz 'tools') -Filter '*.ps1' -File)

$sinBom = @(); $bomDeMas = @(); $conTildes = @()
foreach ($f in $ficheros) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $tieneBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $texto = [System.IO.File]::ReadAllText($f.FullName)   # ReadAllText detecta el BOM solo
    $noAscii = $false
    foreach ($c in $texto.ToCharArray()) { if ([int]$c -gt 127) { $noAscii = $true; break } }
    if ($noAscii -and -not $tieneBom) { $sinBom += $f.Name }
    if ($tieneBom -and -not $noAscii) { $bomDeMas += $f.Name }
    if ($texto -match '[\u00E1\u00E9\u00ED\u00F3\u00FA\u00F1\u00C1\u00C9\u00CD\u00D3\u00DA\u00D1\u00FC]') { $conTildes += $f.Name }
}

Write-Host ''
Write-Host "-- $($ficheros.Count) ficheros .ps1 --"
Comp 'ninguno con letras raras y sin BOM' ($sinBom.Count -eq 0) `
    $(if ($sinBom.Count) { "PowerShell 5.1 los leeria como ANSI: " + ($sinBom -join ', ') } else { 'que es el que se lee mal' })

# ESTE NO ROMPE: se dice y se sigue. Un BOM de mas no cambia como se lee el fichero.
if ($bomDeMas.Count -gt 0) {
    Write-Host ("  --   con BOM siendo ASCII puro (no rompe nada): " + ($bomDeMas -join ', ')) -ForegroundColor DarkGray
}

# EL TRINQUETE. El techo vive en un fichero al lado, como el de las expresiones fragiles, para
# que bajarlo sea un cambio visible en el repositorio y no un numero escondido en el banco.
$techoRuta = Join-Path $PSScriptRoot 'tildes-techo.txt'
$techo = if (Test-Path -LiteralPath $techoRuta) { [int]((Get-Content -LiteralPath $techoRuta -Raw).Trim()) } else { $conTildes.Count }
Comp 'las tildes no crecen' ($conTildes.Count -le $techo) "hoy $($conTildes.Count), techo $techo"
if ($conTildes.Count -lt $techo) {
    Write-Host ("  --   han bajado a $($conTildes.Count): baja el techo en tools\tildes-techo.txt") -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '-- Y QUE EL DETECTOR DETECTE --'
# Un barrido que no encuentra nada y uno que no sabe mirar se ven igual. Se le pone delante un
# fichero de mentira, escrito a proposito como el que romperia la regla.
$tmpD = Join-Path ([IO.Path]::GetTempPath()) ("regla6-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmpD)
try {
    $malo = Join-Path $tmpD 'malo.ps1'
    [System.IO.File]::WriteAllText($malo, ("# una " + [char]0xF1 + " y ninguna marca`nWrite-Host 'hola'`n"),
                                   (New-Object System.Text.UTF8Encoding($false)))
    $bytesM = [System.IO.File]::ReadAllBytes($malo)
    $bomM = ($bytesM.Length -ge 3 -and $bytesM[0] -eq 0xEF -and $bytesM[1] -eq 0xBB -and $bytesM[2] -eq 0xBF)
    $txtM = [System.Text.Encoding]::UTF8.GetString($bytesM)
    $naM = $false
    foreach ($c in $txtM.ToCharArray()) { if ([int]$c -gt 127) { $naM = $true; break } }
    Comp 'caza uno con letras raras y sin BOM' ($naM -and -not $bomM) 'escrito a proposito'

    $bueno = Join-Path $tmpD 'bueno.ps1'
    [System.IO.File]::WriteAllText($bueno, "# una enye y su marca`nWrite-Host 'hola'`n",
                                   (New-Object System.Text.UTF8Encoding($true)))
    $bytesB = [System.IO.File]::ReadAllBytes($bueno)
    $bomB = ($bytesB.Length -ge 3 -and $bytesB[0] -eq 0xEF -and $bytesB[1] -eq 0xBB -and $bytesB[2] -eq 0xBF)
    Comp 'y no se queja del que si lleva marca' $bomB
} finally {
    Remove-Item -LiteralPath $tmpD -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'ningun .ps1 se lee distinto de como esta escrito'
exit 0
