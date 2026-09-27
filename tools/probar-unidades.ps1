# MIRAR TODAS LAS UNIDADES, NO SOLO LA C: (26/09, idea 41 de las 121).
#
# El aviso de disco solo miraba C:. braya tiene una microSD de 477 GB vacia (D:, 'Rog SD'): Nova
# decia "quedan 5 gigas" con 477 sin usar al lado. Ahora Get-Unidades ve todas las unidades fijas
# y extraibles, y el aviso nombra la que tiene mas sitio -diciendo que es la tarjeta y que se
# puede quitar-, sin proponer mover nada (regla 1).
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
$sw = [pscustomobject]@{ ElapsedMilliseconds = 100000 }
Invoke-Expression (Traer 'Format-Gigas')
$textoGU = Traer 'Get-Unidades'
Invoke-Expression $textoGU
Invoke-Expression (Traer 'Get-FraseOtraUnidad')

Write-Host '  -- 1. Get-Unidades: solo listas, solo fijas/extraibles, cada una a su try --'
# GetDrives() es un metodo estatico de .NET que no se puede fingir; se comprueba la ESTRUCTURA
# del filtro por texto y se corre la de verdad contra las unidades reales de la maquina.
Comp 'filtra por IsReady' ($textoGU -match 'IsReady') 'una unidad no lista no cuenta'
Comp '  y solo fijas y extraibles (no red, que cuelga el bucle)' (($textoGU -match "'Fixed'") -and ($textoGU -match "'Removable'")) 'regla 4'
# el try va DENTRO del foreach (una por una), no envolviendo todo el bucle
$iFor = $textoGU.IndexOf('foreach')
$iTry = $textoGU.IndexOf('try', $iFor)
$iCatch = $textoGU.IndexOf('} catch {}', $iFor)
Comp '  y cada unidad en su propio try/catch (una que se cae no tumba a las demas)' ($iFor -ge 0 -and $iTry -gt $iFor -and $iCatch -gt $iTry) ''
# la de verdad, contra el disco real: tiene que ver al menos una unidad con letra y tipo
$reales = @(Get-Unidades)
Comp '  corre de verdad y ve al menos una unidad' ($reales.Count -ge 1) "$($reales.Count) unidad(es): $(@($reales | ForEach-Object { $_.letra + '=' + $_.tipo }) -join ' ')"
Comp '  con tipo traducido (fija/extraible), no el DriveType en ingles' (@($reales | Where-Object { $_.tipo -notin @('fija', 'extraible') }).Count -eq 0) ''
# 9. no pisa la idea 31
Comp '9. no escribe en $script:entornoUnidades (idea 31)' ($textoGU -notmatch 'entornoUnidades') 'esa variable reindexa juegos, es otra cosa'

Write-Host ''
Write-Host '  -- 3, 4, 5. la frase, con Get-Unidades fingida (manera 14) --'
# se finge la DEPENDENCIA (Get-Unidades), se corre la funcion de verdad (Get-FraseOtraUnidad)
function U([string]$l, [string]$t, [long]$libres) { return [pscustomobject]@{ letra = $l; tipo = $t; etiqueta = $l; bytesLibres = $libres; bytesTotal = $libres } }
$GB = 1073741824L
$script:fake = @()
function Get-Unidades { return $script:fake }

$script:fake = @((U 'C' 'fija' (39 * $GB)), (U 'D' 'extraible' (477 * $GB)))
$f3 = Get-FraseOtraUnidad 'C'
Comp '3. a la extraible se la llama tarjeta y se puede quitar' (($f3 -match 'tarjeta') -and ($f3 -match 'puedes quitar')) "'$f3'"

$script:fake = @((U 'C' 'fija' (39 * $GB)), (U 'E' 'fija' (100 * $GB)))
$fE = Get-FraseOtraUnidad 'C'
Comp '  y a una fija con mas sitio, por su letra (sin "tarjeta")' (($fE -match 'en E') -and ($fE -notmatch 'tarjeta')) "'$fE'"

$script:fake = @((U 'C' 'fija' (39 * $GB)), (U 'D' 'extraible' (10 * $GB)))
$f4 = Get-FraseOtraUnidad 'C'
Comp '4. NO se nombra una unidad mas llena que la tuya' ($f4 -eq '') "con 39 en C y 10 en D: '$f4'"

$script:fake = @((U 'C' 'fija' (39 * $GB)))
$f5 = Get-FraseOtraUnidad 'C'
Comp '5. sin otra unidad, la frase queda como hoy (vacia)' ($f5 -eq '') "solo C: '$f5'"

Write-Host ''
Write-Host '  -- 6, 7. los dos avisos, con su nivel, su plazo y la frase --'
# sobre el texto del archivo
$iCrit = $fuente.IndexOf("Send-AvisoEntorno 'disco-critico'")
$iPoco = $fuente.IndexOf("Send-AvisoEntorno 'disco-poco'")
Comp '6. disco-critico va ANTES que disco-poco' ($iCrit -ge 0 -and $iPoco -gt $iCrit) ''
$lineaCrit = $fuente.Substring($iCrit, [Math]::Min(220, $fuente.Length - $iCrit))
$lineaPoco = $fuente.Substring($iPoco, [Math]::Min(220, $fuente.Length - $iPoco))
Comp "  critico sigue en 'alto' 60" (($lineaCrit -match "'alto'") -and ($lineaCrit -match "'alto' 60")) ''
Comp "  poco sigue en 'medio' 720" (($lineaPoco -match "'medio'") -and ($lineaPoco -match "'medio' 720")) ''
Comp '7. la frase de la otra unidad entra en LOS DOS avisos' (($lineaCrit -match '\$otraU') -and ($lineaPoco -match '\$otraU')) 'el critico es el que mas falta hace'

Write-Host ''
Write-Host '  -- 8. no mueve nada (regla 1) --'
$dosFunciones = (Traer 'Get-Unidades') + (Traer 'Get-FraseOtraUnidad')
Comp '8. las dos funciones no mueven ni borran nada' ($dosFunciones -notmatch 'Move-Item|Copy-Item|Remove-Item|robocopy|Start-Process') 'solo redactan; mover un juego es de Steam'

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'el disco mira todas las unidades' -ForegroundColor Green
exit 0
