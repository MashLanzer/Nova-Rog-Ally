# EL DISCO DE FUERA: LOS JUEGOS QUE NOVA NO SABIA QUE EXISTEN (27/09, idea 107 de las 121)
#
# EL DATO: libraryfolders.vdf declara DOS bibliotecas. La 0 (C:) con 20 appids y la 1
# (E:\SteamLibrary, totalsize 1 TB) con DIEZ. Test-Path E:\SteamLibrary = False y las unidades que
# hay son C: y D:. Dos de esos diez estan tambien en C:, o sea OCHO exclusivos que suman
# 734.289.177.929 bytes = 683,9 GiB EXACTOS, siete de ellos con contenido.
#
# Y NOVA NO SABIA NI QUE EXISTEN: el texto '"apps"' no aparecia NI UNA VEZ en el fichero. Al ver que
# la unidad no esta se hacia 'continue' y se perdia la lista que el propio vdf trae escrita. Si braya
# pedia uno, o contestaba "no lo tienes" o le abria la ficha de la tienda para instalarlo: reinstalar
# 683,9 GiB que ya tiene. El appid 1245620 de esa lista es ELDEN RING, 66,4 GiB, y braya lo intento
# abrir el 25/09 a las 21:31.
#
# OJO CON EL APARATO: E: no es "la tarjeta". La SD que SI esta puesta es D:, de 477 GB; E: es otra
# cosa, de 1 TB. Aqui se dice "un disco que no esta puesto" y nunca se le pone nombre.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que el bloque "apps" se lea de verdad, con las barras bien
#   2. que un juego que esta TAMBIEN en un disco presente no cuente como ausente
#   3. que "abre X" y "instala X" digan que esta pero no aqui, en vez de mandar a la tienda
#   4. que sin nombre no se invente nada
#   5. y que una biblioteca PRESENTE no acabe en la lista de fuera
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-Distancia', 'Get-BibliotecasSteam',
                 'Get-JuegosFuera', 'Save-JuegosFuera', 'New-AbrirJuego')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host ''
Write-Host '-- 1. EL BLOQUE "apps" SE LEE (antes no se leia nunca) --'
Comp '1a. el texto "apps" ya aparece en el fichero' ($txt -match '\$t -eq ''"apps"''') 'antes: cero veces en 28.720 lineas'
$vdf = @'
"libraryfolders"
{
	"0"
	{
		"path"		"C:\\Program Files (x86)\\Steam"
		"totalsize"		"0"
		"apps"
		{
			"111"		"1000"
			"222"		"2000"
		}
	}
	"1"
	{
		"path"		"E:\\SteamLibrary"
		"totalsize"		"1000163246080"
		"apps"
		{
			"222"		"2000"
			"333"		"734289177929"
		}
	}
}
'@
$b = @(Get-BibliotecasSteam $vdf)
Comp '1b. salen las dos bibliotecas' ($b.Count -eq 2) ([string]$b.Count)
Comp '1c. con las barras a una' ($b[1].path -eq 'E:\SteamLibrary') ([string]$b[1].path + " (el vdf trae 'E:\\SteamLibrary')")
Comp '1d. y la de C: tambien' ($b[0].path -eq 'C:\Program Files (x86)\Steam') ([string]$b[0].path)
Comp '1e. con sus appids y sus bytes' ($b[1].apps.Count -eq 2 -and $b[1].apps['333'] -eq 734289177929) ([string]$b[1].apps['333'])
Comp '1f. el totalsize no se cuela como appid' (-not $b[1].apps.ContainsKey('1000163246080')) 'solo las lineas de DENTRO del bloque apps'
Comp '1g. y un vdf vacio no revienta' ((@(Get-BibliotecasSteam '')).Count -eq 0) ''
$sinApps = @'
	"0"
	{
		"path"		"C:\x"
	}
'@
Comp '1h. ni uno sin bloque apps' ((@(Get-BibliotecasSteam $sinApps)).Count -eq 1) 'una biblioteca sin juegos sigue siendo una biblioteca'
Comp '1i. y esa se queda sin appids' ((@(Get-BibliotecasSteam $sinApps))[0].apps.Count -eq 0) ''

Write-Host ''
Write-Host '-- 2. LA LISTA DE FUERA SE GUARDA Y SE RELEE --'
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-jf-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $MemoriaDir -Force | Out-Null
$JuegosFueraPath = Join-Path $MemoriaDir 'juegos-fuera.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$r, [string]$t) { [IO.File]::WriteAllText($r, $t, $UTF8) }
try {
    Comp '2a. sin fichero, lista vacia' ((@(Get-JuegosFuera)).Count -eq 0) ''
    [void](Save-JuegosFuera @(@{ appid = '1245620'; nombre = 'ELDEN RING'; bytes = 71328894976; donde = 'E:\SteamLibrary' },
                              @{ appid = '333'; nombre = ''; bytes = 1000; donde = 'E:\SteamLibrary' }))
    $l = @(Get-JuegosFuera)
    Comp '2b. se guarda y se relee' ($l.Count -eq 2) ([string]$l.Count)
    Comp '2c. con el nombre cuando se sabe' (@($l | Where-Object { $_.nombre -eq 'ELDEN RING' }).Count -eq 1) ''
    Comp '2d. y vacio cuando no' (@($l | Where-Object { -not $_.nombre }).Count -eq 1) 'sin nombre NO se inventa nada'
    Comp '2e. con sus bytes' ((@($l | Where-Object { $_.appid -eq '1245620' })[0].bytes) -eq 71328894976) ''

    Write-Host ''
    Write-Host '-- 3. "ABRE X" DICE QUE ESTA, PERO NO AQUI --'
    $j = @{ id = '1245620'; nombre = 'ELDEN RING'; fuera = $true; tamano = 71328894976; donde = 'E:\SteamLibrary' }
    $a = @(New-AbrirJuego $j)
    Comp '3a. no intenta lanzarlo' ($a[0].kind -eq 'decir') ([string]$a[0].kind + '; steam://rungameid solo abriria un error')
    Comp '3b. dice que esta en un disco que no esta' ($a[0].desc -match 'no esta puesto') ([string]$a[0].desc)
    Comp '3c. con los gigas, para decidir si buscarlo' ($a[0].desc -match '66,4|66\.4') ([string]$a[0].desc)
    Comp '3d. y no dice el nombre del aparato' (-not ($a[0].desc -match 'E:|tarjeta|SD')) 'E: no es "la tarjeta": la SD es D:'
    # y uno normal sigue igual
    $jn = @{ id = '999'; nombre = 'Hollow Knight' }
    $an = @(New-AbrirJuego $jn)
    Comp '3e. un juego normal se sigue abriendo' ($an[0].kind -eq 'app' -and $an[0].target -eq 'steam://rungameid/999') ([string]$an[0].target)
    Comp '3f. y uno con lanzador propio tambien' ((@(New-AbrirJuego @{ id = '1'; nombre = 'x'; lanzar = 'C:\x.exe' }))[0].target -eq 'C:\x.exe') ''

    Write-Host ''
    Write-Host '-- 4. EL CABLEADO --'
    $gj = Traer 'Get-JuegosSteam'
    Comp '4a. se leen las bibliotecas con el parseo nuevo' ($gj -match 'Get-BibliotecasSteam \(Get-Content -LiteralPath \$vdf') ''
    Comp '4b. lo de fuera se calcula DESPUES del bucle' ($gj.IndexOf('LO QUE HAY EN LOS DISCOS QUE NO ESTAN') -gt $gj.IndexOf('appmanifest_*.acf')) 'asi ya se sabe que appids se encontraron de verdad'
    Comp '4c. una biblioteca PRESENTE no entra en la lista' ($gj -match 'if \(Test-Path -LiteralPath \$dB\) \{ continue \}') 'sus juegos ya estan arriba'
    Comp '4d. ni un appid que este tambien en un disco puesto' ($gj -match 'if \(\$vistos\.ContainsKey\(\$idB\)\) \{ continue \}') 'dos de los diez estan en las dos'
    $fj = Traer 'Find-Juego'
    Comp '4e. Find-Juego lo mira ANTES de rendirse' ($fj -match 'Get-JuegosFuera') ''
    Comp '4f. y solo si el juego tiene nombre' ($fj -match 'if \(-not \$nmF\) \{ continue \}') 'sin nombre no se puede casar'
    Comp '4g. la rama de instalar tambien' ($sinCom -match 'if \(\$yaInst\.fuera\)') 'aqui estaba el dano: mandaba a bajar 66 GiB que ya tiene'
    Comp '4h. diciendo que bajarlo seria tirar gigas' ($sinCom -match 'seria tirar esos gigas') ''
    Comp '4i. y al conectar un disco se dice cuantos quedan fuera' ($sinCom -match 'me quedan ' -and $sinCom -match 'en otro disco que no esta') ''
    Comp '4j. la ruta del fichero vive pegada a MemoriaDir' ($txt -match '(?s)\$MemoriaDir = Join-Path \$LogDir "memoria"\s*\r?\n\$JuegosFueraPath') 'declarada 900 lineas antes, Nova no arrancaba'
    Comp '4k. y NO se escribio una cola de consultas a la tienda' (-not ($txt -match 'Update-NombreFuera')) 'medido: la API no devuelve el nombre con ningun filtro'
} finally {
    Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 5. Y CONTRA EL VDF DE VERDAD DE ESTA CONSOLA --'
$sp = ''
try { $sp = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath } catch {}
$vr = if ($sp) { Join-Path ($sp -replace '/', '\') 'steamapps\libraryfolders.vdf' } else { '' }
if ($vr -and (Test-Path -LiteralPath $vr)) {
    $br = @(Get-BibliotecasSteam (Get-Content -LiteralPath $vr -Raw -Encoding UTF8))
    Comp '5a. se leen las bibliotecas de verdad' ($br.Count -ge 1) ([string]$br.Count)
    $conApps = @($br | Where-Object { $_.apps.Count -gt 0 })
    Comp '5b. y todas traen su lista de juegos' ($conApps.Count -eq $br.Count) ([string]$conApps.Count + ' de ' + [string]$br.Count)
    $ausentes = @($br | Where-Object { -not (Test-Path -LiteralPath ((($_.path -replace '/', '\').TrimEnd('\')) + '\steamapps')) })
    if ($ausentes.Count -gt 0) {
        $ids0 = @{}
        foreach ($x in @($br | Where-Object { Test-Path -LiteralPath ((($_.path -replace '/', '\').TrimEnd('\')) + '\steamapps') })) {
            foreach ($k in @($x.apps.Keys)) { $ids0[$k] = $true }
        }
        $exc = @(); $by = 0.0
        foreach ($x in $ausentes) { foreach ($k in @($x.apps.Keys)) { if (-not $ids0.ContainsKey($k)) { $exc += $k; $by += [double]$x.apps[$k] } } }
        Comp '5c. hay juegos en un disco que no esta' ($exc.Count -gt 0) ([string]$exc.Count + ' appids, ' + [Math]::Round($by / 1073741824.0, 1) + ' GiB')
        Comp '5d. y antes de esto no se sabia ni que existian' ($by -gt 0) 'el continue silencioso se lo llevaba todo'
    } else {
        Write-Host '  --   ahora mismo todas las bibliotecas estan puestas, se salta'
    }
} else {
    Write-Host '  --   no hay Steam aqui, se salta'
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova sabe que juegos hay en el disco que no esta puesto' -ForegroundColor Green
exit 0
