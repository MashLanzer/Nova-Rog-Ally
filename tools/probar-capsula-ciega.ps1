# CUANDO LA CAPSULA NO SE VE, NO CUENTA COMO SALIDA (25/09, ideas 1 y 6)
#
# LO QUE PASO, con braya jugando la noche del 24: la capsula estaba en z=0 -por delante del
# juego-, visible, colocada y con su ancho y su alto correctos, y NO SE PINTABA NI UN PIXEL.
# A Way Out estaba en pantalla completa EXCLUSIVA, y ahi ningun overlay de ventana se dibuja.
# Nova estuvo media hora ensenandole cosas a nadie.
#
# COMO SE SABE, y es limpio: el modo exclusivo CAMBIA LA RESOLUCION DEL ESCRITORIO. Medido esa
# noche: el panel de la Ally es 1920x1080 nativo y el escritorio estaba a 1280x720. El modo
# "ventana sin bordes" no cambia nunca la resolucion, asi que la diferencia lo delata.
#
# POR QUE IMPORTA MAS QUE UN DETALLE: la regla 2 de la casa dice que ningun modo puede tener
# una sola salida. Con la capsula ciega, todo lo que hoy va SOLO a la capsula -el pulso, el
# nivel, los avisos de nivel 'bajo'- no llega a ninguna parte. Y Nova no lo sabia.
#
# Y LA IDEA 6, que sale de la misma medicion: braya cerro el juego a las 00:01:13 y veinte
# minutos despues el escritorio SEGUIA a 1280x720. El juego no le devolvio su resolucion.
# Nova ya detecta el cierre del juego; con esto puede decirselo. No se la cambia sola: en una
# consola portatil bajar la resolucion a veces es a proposito, para bateria.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. sabe mirar la pantalla --'
Comp 'existe Get-ResolucionNativa' ($sinCom -match 'function Get-ResolucionNativa') ''
Comp 'existe Test-CapsulaCiega' ($sinCom -match 'function Test-CapsulaCiega') ''
Comp 'y la nativa se guarda, no se pregunta cada vez' ($sinCom -match '\$script:resNativa') 'el panel no cambia de tamano'

Write-Host ''
Write-Host '-- 2. LAS FUNCIONES, SACADAS DEL ARCHIVO Y EJECUTADAS --'
foreach ($f in @('Test-CapsulaCiega')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    if (-not $d) {
        Comp ("se saca " + $f + " del arbol") $false ''
        Write-Host ''
        Write-Host "  $mal MAL"
        exit 1
    }
    Invoke-Expression $d.Extent.Text
}
function Log([string]$m) { }

# los dobles, DESPUES de cargar (manera 9)
$script:juegoActivo = ''
$script:resNativa = $null
function Get-ResolucionNativa { return $script:resNativa }
function Get-ResolucionActual { return $script:resAhora }

# SIN JUEGO: aunque la resolucion sea rara, la capsula se ve
$script:resNativa = @(1920, 1080); $script:resAhora = @(1280, 720); $script:juegoActivo = ''
Comp 'sin juego delante, la capsula se ve' ((Test-CapsulaCiega) -eq $false) 'una resolucion baja no la esconde'

# CON JUEGO Y MISMA RESOLUCION: es sin bordes, se ve
$script:resAhora = @(1920, 1080); $script:juegoActivo = 'AWayOut.exe'
Comp 'con juego y la resolucion nativa, se ve' ((Test-CapsulaCiega) -eq $false) 'eso es ventana sin bordes'

# EL CASO DEL 24/09: juego + resolucion cambiada = exclusiva = ciega
$script:resAhora = @(1280, 720)
Comp 'con juego y otra resolucion, esta CIEGA' ((Test-CapsulaCiega) -eq $true) 'el caso de A Way Out'

# Y CON EL MISMO ANCHO PERO DISTINTO ALTO (25/09, lo cazo una rotura): con 1280x720 contra
# 1920x1080 cambian las dos cifras, asi que comparar solo el ancho daba la misma respuesta y
# la rotura salia verde. 1920x1200 es una resolucion real de monitor y comparte ancho con la
# nativa: solo quien mire TAMBIEN el alto la distingue.
$script:resAhora = @(1920, 1200)
Comp 'y si solo cambia el alto, tambien esta ciega' ((Test-CapsulaCiega) -eq $true) '1920x1200 contra 1920x1080'

# SIN SABER LA NATIVA: ante la duda, se ve (no se inventa un problema)
$script:resNativa = $null
Comp 'sin saber la nativa, se da por visible' ((Test-CapsulaCiega) -eq $false) 'ante la duda, no inventar'
$script:resNativa = @(1920, 1080); $script:resAhora = $null
Comp 'y sin saber la actual, tambien' ((Test-CapsulaCiega) -eq $false) ''

Write-Host ''
Write-Host '-- 3. y se usa para no hablarle a una pantalla que no esta --'
# LA CLAVE DEL JSON, NO LA PALABRA (25/09, lo cazo una rotura): "capsulaCiega" tambien es el
# nombre de la variable, asi que buscarla a secas daba verde aunque se borrara del estado que
# se le manda a la capsula.
Comp 'el estado de la capsula lo lleva' ($sinCom -match '"capsulaCiega":') 'para que la propia capsula lo sepa'
# Y LA LLAMADA, NO LA DEFINICION (lo cazo otra): "Test-CapsulaCiega" encuentra su propia
# "function Test-CapsulaCiega", asi que dejar de llamarla no se notaba.
$usos = @([regex]::Matches($sinCom, '(?<!function )Test-CapsulaCiega')).Count
Comp 'y se recalcula de verdad, no solo se define' ($usos -ge 1) "$usos uso(s)"
# Y QUE EL AVISO QUE NO SE VE AL MENOS VIBRE (lo cazo la cuarta): sin esto, un aviso que se
# calla por respeto a la partida y ademas no se pinta no ha llegado a ninguna parte.
Comp 'existe la vibracion de respaldo' ($sinCom -match 'function Send-AvisoVibrado') ''
$iSA = $sinCom.IndexOf('if (Test-AvisoSinVoz) {')
$blSA = if ($iSA -gt 0) { $sinCom.Substring($iSA, [Math]::Min(500, $sinCom.Length - $iSA)) } else { '' }
Comp 'y el aviso sin voz la usa' ($blSA -match 'Send-AvisoVibrado') 'la regla 2: ninguna salida unica'

Write-Host ''
Write-Host '-- 4. y avisa si el juego te dejo la pantalla cambiada (idea 6) --'
Comp 'existe la comprobacion al cerrar el juego' ($sinCom -match "Send-AvisoEntorno 'pantalla-cambiada'") ''
Comp 'y NO se la cambia sola' (-not ($sinCom -match "pantalla-cambiada[^\n]{0,300}Set-Resolucion|ChangeDisplaySettings")) 'en portatil, bajarla a veces es a proposito'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova sabe cuando no se la ve'
exit 0
