# LAS EXPRESIONES QUE SE ROMPEN SOLAS (25/09, idea 2)
#
# EL PATRON: '$algo[\s\S]{0,900}$otraCosa', o sea "que estas dos cosas esten a menos de 900
# caracteres". Parece inofensivo y es una bomba de relojeria: el dia que alguien mete un
# comentario entre las dos, el banco se pone ROJO con el codigo perfectamente bien.
#
# LO MEDIDO: 28 expresiones asi en 12 bancos. Y no es teorico -DOS de ellas mordieron la
# madrugada del 25/09, en probar-log y probar-guia, solo porque escribi un comentario dentro
# del bloque que miraban-. Una tercera, en probar-segunda-oreja, media 2200 caracteres cuando
# la linea que importaba caia sobre el 2300: esa fallaba al reves, dejando pasar una rotura.
#
# POR QUE IMPORTA MAS DE LO QUE PARECE: un banco que se pone rojo solo entrena a ignorarlo. Y
# un banco que se ignora no protege nada.
#
# LO QUE HACE ESTE BANCO: no las prohibe de golpe -son 29 y arreglarlas a ciegas romperia
# comprobaciones que hoy funcionan- sino que pone un TECHO QUE SOLO PUEDE BAJAR, que es como
# esta casa trata estas cosas. Si aparece una nueva, rojo. Si se arregla alguna, el techo baja
# solo y ya no se puede volver a subir.
#
# LA ALTERNATIVA, para quien venga a arreglar una: recortar el bloque por sus limites de verdad
# (IndexOf de la primera linea hasta su cierre), quitarle los comentarios y comprobar que
# dentro estan las piezas, en cualquier orden y a cualquier distancia. Asi estan hechos
# probar-log y probar-guia desde esa madrugada.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}

# EL TECHO VIVE EN SU PROPIO FICHERO, no aqui dentro: asi bajarlo es un cambio de una linea que
# se ve en el diff, y no se puede subir "sin querer" editando el banco.
$RutaTecho = Join-Path $PSScriptRoot 'fragiles-techo.txt'

$hoy = 0
$porBanco = @{}
foreach ($f in @(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Name -like 'probar-*.ps1' -or $_.Name -like 'probar-*.py' })) {
    if ($f.Name -eq 'probar-bancos-fragiles.ps1') { continue }   # este habla de ellas, no las usa
    $c = [IO.File]::ReadAllText($f.FullName)
    $n = @([regex]::Matches($c, 'S\]\{0,\d+\}')).Count
    if ($n -gt 0) { $porBanco[$f.Name] = $n; $hoy += $n }
}

# EL TECHO SE CREA LA PRIMERA VEZ (25/09, lo cazo una rotura). La primera version solo
# escribia el fichero cuando el numero BAJABA, y como sin fichero el techo se daba por igual al
# recuento de hoy, nunca bajaba y nunca se creaba: el banco salia verde con cualquier numero de
# expresiones, incluidas las nuevas. Un techo que no existe no es un techo.
$techo = $hoy
if (Test-Path -LiteralPath $RutaTecho) {
    try { $techo = [int]((Get-Content -LiteralPath $RutaTecho -Raw).Trim()) } catch { $techo = $hoy }
} else {
    # SIN BOM: Set-Content -Encoding UTF8 lo mete en PowerShell 5.1, y el techo es un
    # numero suelto que otras herramientas leen. Un BOM delante lo convierte en basura.
    [IO.File]::WriteAllText($RutaTecho, [string]$hoy, (New-Object System.Text.UTF8Encoding $false))
    Write-Host ("  ok   techo puesto por primera vez en $hoy")
}

Write-Host '-- las expresiones que dependen de cuanto ocupa el codigo de al lado --'
foreach ($k in @($porBanco.Keys | Sort-Object)) {
    Write-Host ("     " + $k.PadRight(34) + $porBanco[$k])
}
Write-Host ''
Comp 'no han aparecido nuevas' ($hoy -le $techo) "hoy $hoy, techo $techo"

if ($hoy -lt $techo) {
    # EL TECHO BAJA SOLO. Nunca sube: para subirlo hay que editar el fichero a mano y eso se ve.
    [IO.File]::WriteAllText($RutaTecho, [string]$hoy, (New-Object System.Text.UTF8Encoding $false))
    Write-Host ("  ok   y el techo baja de $techo a $hoy  (se queda ahi)")
}

# Y QUE LAS QUE SE ESCRIBAN NUEVAS NO SEAN ENORMES: una de 3000 caracteres no mide una
# vecindad, mide medio archivo, y pasa por casualidad.
$enormes = @()
foreach ($f in @(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Name -like 'probar-*.ps1' -or $_.Name -like 'probar-*.py' })) {
    if ($f.Name -eq 'probar-bancos-fragiles.ps1') { continue }
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'S\]\{0,(\d+)\}')) {
        if ([int]$m.Groups[1].Value -gt 2000) { $enormes += ($f.Name + ' (' + $m.Groups[1].Value + ')') }
    }
}
Comp 'ninguna mide mas de 2000 caracteres' ($enormes.Count -eq 0) "$($enormes -join ', ')"

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  las expresiones fragiles no crecen'
exit 0
