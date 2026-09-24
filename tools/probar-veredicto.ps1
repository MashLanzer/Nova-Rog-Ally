# EL BANCO SE TRAGABA SUS PROPIOS ERRORES (22/09).
#
# probar-todo.ps1 tenia 104 subidas de $fallos, y 98 eran la MISMA linea muda
#     if ($LASTEXITCODE -ne 0) { $fallos++ }
# sin un solo mensaje y sin guardar de que seccion venian. El veredicto solo podia decir
# "3 comprobaciones con problemas" y tocaba reejecutar secciones a ciegas -hasta 104- para
# saber cuales eran. Encima 95 de esas 98 filtran su salida con Select-String, asi que un
# banco que muere por una excepcion no imprime NADA.
#
# Y habia algo peor: la seccion 7, que existe para cazar los bancos que mueren a medias,
# buscaba UN SOLO patron (CommandNotFoundException). Cualquier otra excepcion -un JSON
# roto, un fichero que no esta, python reventando al importar- pasaba de largo, la seccion
# se pintaba en VERDE diciendo "todos los bancos ejecutan de verdad lo que dicen"... y la
# linea siguiente BORRABA el fichero de errores. El unico rastro del fallo se destruia en
# la misma pasada que lo producia.
#
# Este banco prueba al banco. Se rie un poco, pero es el unico fichero del proyecto que no
# tenia a nadie mirandole, y es el que decide si todo lo demas esta bien.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$todo = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probar-todo.ps1'))

$malos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:malos++ }
}

Write-Host ''
Write-Host '-- cada fallo dice de que seccion viene --'
# REGLA DEL BANCO (van veintiuna): Titulo se TRAE de probar-todo.ps1. Es justo la funcion
# que se cambio, y copiarla aqui seria probar una copia mia.
$mT = [regex]::Match($todo, '(?ms)^function Titulo\(\$t\) \{.*?^\}')
Comp 'Titulo sigue existiendo' ($mT.Success)
if (-not $mT.Success) { Write-Host '  MAL  sin Titulo no hay nada que probar'; exit 1 }
. ([scriptblock]::Create($mT.Value))

# COMO SE APUNTA EL NOMBRE SIN TOCAR LAS 98 LINEAS: cada seccion empieza SIEMPRE llamando a
# Titulo, y sus $fallos++ vienen despues, asi que la propia Titulo mira si el contador subio
# durante la seccion ANTERIOR. Aqui se simula justo eso.
$secFallidas = @()
$script:tituloActual = ''
$script:fallosAlEmpezar = 0
$fallos = 0

Titulo '1. la primera, que va bien'
Titulo '2. la segunda, que falla'
$fallos++
Titulo '3. la tercera, que tambien va bien'
Titulo '4. la cuarta, que falla dos veces'
$fallos += 2
Titulo '5. la quinta, bien'
# la ultima no tiene detras otro Titulo: la cierra el veredicto, igual que en el fichero
if ($script:tituloActual -and $fallos -gt $script:fallosAlEmpezar) { $secFallidas += $script:tituloActual }

Comp 'apunta las dos que fallaron' ($secFallidas.Count -eq 2) "$($secFallidas.Count) de 2"
Comp 'y son las que son' (($secFallidas -join ' | ') -match 'la segunda.*la cuarta') ($secFallidas -join ' | ')
Comp 'no apunta las que fueron bien' (-not (($secFallidas -join ' ') -match 'primera|tercera|quinta'))
Comp 'y cuenta los tres fallos' ($fallos -eq 3) "$fallos"

# LA ULTIMA SECCION ES LA QUE MAS FACIL SE PIERDE, porque no tiene otro Titulo detras.
$secFallidas = @(); $script:tituloActual = ''; $script:fallosAlEmpezar = 0; $fallos = 0
Titulo '1. bien'
Titulo '7. la ULTIMA, que falla'
$fallos++
if ($script:tituloActual -and $fallos -gt $script:fallosAlEmpezar) { $secFallidas += $script:tituloActual }
Comp 'la ultima seccion no se pierde' ($secFallidas.Count -eq 1 -and $secFallidas[0] -match 'ULTIMA') ($secFallidas -join '')
Comp 'y el veredicto la cierra en el fichero' `
    ($todo -match '(?m)^if \(\$script:tituloActual -and \$fallos -gt \$script:fallosAlEmpezar\) \{ \$secFallidas \+= \$script:tituloActual \}')

# Sin fallos no se apunta nadie: el verde tiene que seguir siendo verde.
$secFallidas = @(); $script:tituloActual = ''; $script:fallosAlEmpezar = 0; $fallos = 0
foreach ($n in 1..5) { Titulo "$n. todas bien" }
if ($script:tituloActual -and $fallos -gt $script:fallosAlEmpezar) { $secFallidas += $script:tituloActual }
Comp 'sin fallos no apunta ninguna' ($secFallidas.Count -eq 0) "$($secFallidas.Count)"

Write-Host ''
Write-Host '-- la seccion 7 ya no se pinta verde con errores dentro --'
# No se intenta clasificar linea por linea: un error de PowerShell ocupa seis lineas y se
# parte solo por el ancho de la consola, asi que cualquier filtro fino se equivoca. Basta
# con saber si quedo ALGO escrito ahi.
$m7 = [regex]::Match($todo, '(?s)Titulo "7\. Bancos que llaman.{0,6000}')
$s7 = $m7.Value
Comp 'la seccion 7 sigue ahi' ($m7.Success)
Comp 'ya no mira un solo patron' ($s7 -match '\$conAlgo = @\(\$lineasErr \| Where-Object')
Comp 'el verde solo si no quedo NADA escrito' ($s7 -match 'if \(\$conAlgo\.Count -eq 0\) \{\s*\r?\n\s*Write-Host "   ninguno')
Comp 'y si quedo algo, lo ensena' ($s7 -match 'AMARILLO: ninguna funcion sin traer')
Comp 'con las lineas de verdad, no solo el numero' ($s7 -match 'foreach \(\$oL in \(\$conAlgo \| Select-Object -First')
Comp 'y entra en los avisos amarillos del final' ($s7 -match '\$avisosAmarillos \+= ')
# EN AMARILLO Y NO EN ROJO, igual que la seccion 6: por aqui pasa tambien ruido legitimo
# (avisos de python, barras de progreso), y un rojo que sale siempre se aprende a ignorar,
# que es la unica forma de matar un aviso.
Comp 'en amarillo, que un rojo de siempre se ignora' ($s7 -match 'Yellow')

Write-Host ''
Write-Host '-- y el rastro deja de destruirse solo --'
# Antes se borraba SIEMPRE, tambien cuando dentro estaba la excepcion que acababa de matar
# a un banco. Se prueba de verdad, con los dos ficheros.
$mBorra = [regex]::Match($s7, '(?s)if \(\$conAlgo\.Count -eq 0\) \{\s*\r?\n\s*Remove-Item.{0,400}?\}')
Comp 'el borrado ahora tiene condicion' ($mBorra.Success)
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-err-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
foreach ($caso in @(@('vacio', @()), @('con-error', @('', 'Exception: se rompio algo', '  en la linea 3', '')))) {
    $script:errBanco = Join-Path $tmp ($caso[0] + '.txt')
    Set-Content -LiteralPath $script:errBanco -Value $caso[1] -Encoding UTF8
    $lineasErr = @(Get-Content -LiteralPath $script:errBanco -ErrorAction SilentlyContinue)
    $conAlgo = @($lineasErr | Where-Object { ([string]$_).Trim() })
    . ([scriptblock]::Create($mBorra.Value))
    $sigue = Test-Path -LiteralPath $script:errBanco
    if ($caso[0] -eq 'vacio') {
        Comp 'si estaba vacio se borra, como siempre' (-not $sigue) 'nada que dejar en TEMP'
    } else {
        Comp 'si habia una excepcion, NO se borra' ($sigue) 'el rastro se queda'
    }
}
# Las lineas en blanco no cuentan como "algo": el fichero acaba siempre con un salto.
$script:errBanco = Join-Path $tmp 'solo-blancos.txt'
Set-Content -LiteralPath $script:errBanco -Value @('', '   ', '') -Encoding UTF8
$conAlgo = @(@(Get-Content -LiteralPath $script:errBanco) | Where-Object { ([string]$_).Trim() })
Comp 'las lineas en blanco no cuentan como error' ($conAlgo.Count -eq 0) "$($conAlgo.Count)"
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '-- lo que NO puede cambiar --'
# Las dos frases del veredicto las buscan tal cual los cerrar-ronda*.ps1 de tmp con
# Select-String. Cambiarles una palabra rompe el cierre de ronda sin que nadie se entere.
Comp 'la linea del numero, palabra por palabra' ($todo -match '"\$fallos comprobaciones con problemas"')
Comp 'y la de "todo en orden" sigue igual' ($todo -match 'todo en orden')
Comp 'los nombres van DEBAJO del numero, no en su linea' `
    ($todo -match '(?s)Write-Host "\$fallos comprobaciones con problemas".{0,200}?foreach \(\$sF in \$secFallidas\)')
Comp 'y se sigue saliendo con 1 si hay fallos' ($todo -match '(?s)foreach \(\$sF in \$secFallidas\).{0,200}?exit 1')
# Las secciones saltadas y los avisos amarillos son de antes y siguen.
Comp 'las secciones saltadas siguen saliendo' ($todo -match 'seccion\(es\) SALTADA\(S\)')
Comp 'y los avisos amarillos tambien' ($todo -match 'aviso\(s\) en AMARILLO')
# Cada seccion tiene que tener SU nombre: con dos iguales, decir el nombre no identifica.
$et = @([regex]::Matches($todo, '(?m)^Titulo "([0-9a-z]+)\.') | ForEach-Object { $_.Groups[1].Value })
$rep = @($et | Group-Object | Where-Object { $_.Count -gt 1 })
Comp 'ninguna etiqueta repetida' ($rep.Count -eq 0) `
    $(if ($rep.Count) { 'repetidas: ' + (($rep | ForEach-Object { $_.Name }) -join ', ') } else { "$($et.Count) secciones" })
# Y que Titulo siga siendo lo primero de cada seccion, que es de lo que depende todo esto.
Comp 'todas las secciones empiezan por Titulo' ($et.Count -ge 100) "$($et.Count) secciones"

Write-Host ''
if ($malos -gt 0) {
    Write-Host "  $malos caso(s) MAL"
    exit 1
}
Write-Host '  el banco ya dice de que seccion viene cada fallo, y no borra el rastro'
exit 0
