# CUANTO TARDA LA NUBE (20/09), el dato que le faltaba a C9.
#
# El tope de la nube nacio en 2.500 ms y se subio a 7.000 el 19/09 porque 2,5 s se
# quedaba corto. Pero nadie sabe si 7 sobra o falta, porque hasta hoy solo se apuntaba SI
# llego o si se paso del tope, nunca CUANTO tardo la que si llego. Sin ese dato, "que
# Nova ajuste sola el tope" (C9) no puede existir: solo sabria apagar la nube entera.
#
# Aqui se prueba la parte aritmetica, que es la que decidira: que los tiempos se guarden,
# que la lista no crezca sin fin, que el percentil salga bien, y -lo que mas importa- que
# con pocos datos NO diga un numero, porque un p90 de tres muestras es una corazonada con
# aspecto de dato.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA (aprendida cinco veces ya): toda funcion que se llame aqui TIENE que estar en
# esta lista, o la prueba corre contra algo que no existe. Desde hoy la seccion 7 del
# banco lo caza sola, pero mejor no darle trabajo.
# Get-NubeDias entra el 21/09: Add-NubeTiempo la llama por dentro para apuntar el dia de
# cada muestra. Sin ella aqui, esta prueba se puso en rojo con DOCE casos y el codigo de
# verdad correcto. Es la misma regla de siempre, y van ocho veces.
foreach ($fn in @('Get-NubeTiempos', 'Get-NubeDias', 'Add-NubeTiempo', 'Get-NubePercentil', 'Get-FraseNubeTiempo')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

# los topes salen del archivo, no copiados a mano
$NubeTiemposMax = [int]([regex]::Match($fuente, '(?m)^\$NubeTiemposMax\s*=\s*(\d+)').Groups[1].Value)
$DecisionMinIntentos = [int]([regex]::Match($fuente, '(?m)^\$DecisionMinIntentos\s*=\s*(\d+)').Groups[1].Value)
Comp 'los topes salen del archivo' (($NubeTiemposMax -ge 10) -and ($DecisionMinIntentos -ge 1)) "max $NubeTiemposMax, minimo para fiarse $DecisionMinIntentos"

$base = Join-Path ([System.IO.Path]::GetTempPath()) ('nubet-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$NubeTiemposJson = Join-Path $base 'nube-tiempos.json'
$NubeTopeMs = 7000
function Log($t) { }

Write-Host '-- sin nada guardado --'
Comp 'no hay tiempos' ((Get-NubeTiempos).Count -eq 0)
Comp 'el percentil no se inventa nada' ((Get-NubePercentil 90) -eq 0)
$f0 = Get-FraseNubeTiempo
Comp 'y lo dice en vez de soltar un numero' ($f0 -match 'Todavia no tengo suficientes') ("'" + $f0 + "'")

Write-Host '-- se guardan y se releen del disco --'
foreach ($ms in @(1000, 2000, 3000)) { [void](Add-NubeTiempo $ms) }
Comp 'estan los tres' ((Get-NubeTiempos).Count -eq 3)
Comp 'y el fichero existe' (Test-Path -LiteralPath $NubeTiemposJson)
Comp 'se leen del disco cada vez' ((Get-NubeTiempos).Count -eq 3) "$((Get-NubeTiempos) -join ',')"

Write-Host '-- con pocos datos NO se dice un numero (un p90 de tres es una corazonada) --'
$fPocos = Get-FraseNubeTiempo
Comp 'sigue diciendo que no le llega' ($fPocos -match 'Todavia no tengo suficientes')

Write-Host '-- el percentil, sobre 1..100 --'
Remove-Item -LiteralPath $NubeTiemposJson -Force -ErrorAction SilentlyContinue
for ($i = 1; $i -le 100; $i++) { [void](Add-NubeTiempo $i) }
Comp 'p50 = 50' ((Get-NubePercentil 50) -eq 50) ("p50=" + (Get-NubePercentil 50))
Comp 'p90 = 90' ((Get-NubePercentil 90) -eq 90) ("p90=" + (Get-NubePercentil 90))
Comp 'p100 = 100' ((Get-NubePercentil 100) -eq 100)
Comp 'y el orden no importa' ((Get-NubePercentil 90) -eq 90)

Write-Host '-- la lista no crece sin fin --'
Remove-Item -LiteralPath $NubeTiemposJson -Force -ErrorAction SilentlyContinue
for ($i = 1; $i -le ($NubeTiemposMax + 50); $i++) { [void](Add-NubeTiempo $i) }
$l = Get-NubeTiempos
Comp "se queda en $NubeTiemposMax" ($l.Count -eq $NubeTiemposMax) "$($l.Count)"
Comp 'y guarda los ULTIMOS, no los primeros' ($l[-1] -eq ($NubeTiemposMax + 50)) "el ultimo es $($l[-1])"

Write-Host '-- ya con datos de sobra, si dice el numero --'
$fr = Get-FraseNubeTiempo
Comp 'da mediana y peor de cada diez' (($fr -match 'de mediana') -and ($fr -match 'peor de cada diez')) ("'" + $fr.Substring(0, [Math]::Min(70, $fr.Length)) + "...'")
Comp 'y dice cuanto la espera hoy' ($fr -match '7 segundos')

Write-Host '-- un tiempo absurdo no entra --'
$antes = (Get-NubeTiempos).Count
[void](Add-NubeTiempo 0)
[void](Add-NubeTiempo -5)
Comp 'ni el cero ni los negativos' ((Get-NubeTiempos).Count -eq $antes)

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  los tiempos de la nube se guardan, caducan por numero y no se inventan un p90'
exit 0
