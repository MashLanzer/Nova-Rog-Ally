# CUANDO LA CAPSULA NO SE VE, NO CUENTA COMO SALIDA (25/09 ideas 1 y 6; 27/09 idea 67)
#
# LO QUE PASO, con braya jugando la noche del 24: la capsula estaba en z=0 -por delante del
# juego-, visible, colocada y con su ancho y su alto correctos, y NO SE PINTABA NI UN PIXEL.
# A Way Out estaba en pantalla completa EXCLUSIVA, y ahi ningun overlay de ventana se dibuja.
# Nova estuvo media hora ensenandole cosas a nadie.
#
# COMO SE SABIA HASTA EL 27/09, y este banco lo probaba asi: comparando la resolucion nativa con
# la actual, porque el modo exclusivo de A Way Out cambiaba la del escritorio -el panel de la Ally
# es 1920x1080 nativo y esa noche el escritorio estaba a 1280x720-.
#
# POR QUE YA NO SE HACE ASI, Y POR ESO ESTE BANCO CAMBIO (27/09, idea 67): esa cuenta no dijo
# 'no se ve' NI UNA VEZ en las 58.636 lineas de los dos registros, con 19,9 horas de juego dentro,
# porque los juegos de hoy corren a pantalla completa SIN cambiar de resolucion: nativa y actual
# coinciden y la cuenta siempre decia 'se ve'. Lo medido: 5 avisos 'SIN VOZ' y CERO vibrados.
# Ahora lo dice quien lo sabe. La capsula escribe en tmp\ui-visible.txt la linea
# '1|0 <hora> <cadencia ms>' cada 5 s -SeVe y AnotarVisible en nova_ui.cs- mirando su opacidad,
# si esta visible y SHQueryUserNotificationState, que es la senal que da Windows para el modo
# exclusivo; y Test-CapsulaCiega lee ese fichero. Por eso los casos de aqui ya no se montan con
# resoluciones: se montan escribiendo el fichero, que es lo que la funcion mira de verdad.
#
# POR QUE IMPORTA MAS QUE UN DETALLE: la regla 2 de la casa dice que ningun modo puede tener
# una sola salida. Con la capsula ciega, todo lo que hoy va SOLO a la capsula -el pulso, el
# nivel, los avisos de nivel 'bajo'- no llega a ninguna parte. Y Nova no lo sabia.
#
# ANTE LA DUDA, SE VE: sin fichero, vacio, ilegible o viejo se supone visible. Dar por ciega una
# capsula que si se ve haria hablar a Nova encima del juego, que es peor que el fallo que arregla.
# Y 'viejo' no es un numero a mano: son tres veces la cadencia que la propia capsula declaro.
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
Comp 'existe Get-ResolucionNativa' ($sinCom -match 'function Get-ResolucionNativa') 'la idea 6 la sigue usando al cerrar el juego'
Comp 'existe Get-UiVisible' ($sinCom -match 'function Get-UiVisible') 'la puerta por la que entra lo que dice la capsula'
Comp 'existe Test-CapsulaCiega' ($sinCom -match 'function Test-CapsulaCiega') ''
Comp 'y la nativa se guarda, no se pregunta cada vez' ($sinCom -match '\$script:resNativa') 'el panel no cambia de tamano'

Write-Host ''
Write-Host '-- 2. LAS FUNCIONES, SACADAS DEL ARCHIVO Y EJECUTADAS --'
# Get-UiVisible va en la lista porque Test-CapsulaCiega la llama por dentro desde la idea 67
# (27/09): antes decidia el solo comparando resoluciones y no hacia falta extraer nada mas.
foreach ($f in @('Get-UiVisible', 'Test-CapsulaCiega')) {
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
# el fichero es de verdad: Get-UiVisible se ejecuta entera, con su Test-Path, su regex y su reloj
$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('capsula-ciega-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TmpDir -Force)
$rutaVis = Join-Path $TmpDir 'ui-visible.txt'
function PonVisible([string]$ve, [int]$haceSeg, [int]$cadaMs) {
    # la linea EXACTA que escribe AnotarVisible en nova_ui.cs: se-ve, hora y cadencia, mas CRLF
    $h = (Get-Date).AddSeconds(-1 * $haceSeg).ToString('yyyy-MM-dd HH:mm:ss')
    [IO.File]::WriteAllText($rutaVis, ($ve + ' ' + $h + ' ' + $cadaMs + "`r`n"))
}
function BorraVisible { if (Test-Path -LiteralPath $rutaVis) { Remove-Item -LiteralPath $rutaVis -Force } }
# Y ESTOS DOS SON LA GUARDA DE LA REGRESION: devuelven resoluciones DISTINTAS a proposito. Si
# alguien vuelve a decidir la ceguera comparando resoluciones -la cuenta que la idea 67 tiro por
# no acertar nunca-, los casos de abajo que esperan 'se ve' se pondran rojos.
function Get-ResolucionNativa { return @(1920, 1080) }
function Get-ResolucionActual { return @(1280, 720) }

# SIN JUEGO DELANTE: no hay nada que la tape, diga lo que diga el fichero
PonVisible '0' 1 5000
Comp 'sin juego delante, la capsula se ve' ((Test-CapsulaCiega) -eq $false) 'sin juego nada la tapa'

# CON JUEGO Y LA CAPSULA DICIENDO QUE SE VE: se ve
$script:juegoActivo = 'AWayOut.exe'
PonVisible '1' 1 5000
Comp 'con juego, si la capsula dice que se ve, se ve' ((Test-CapsulaCiega) -eq $false) 'y la resolucion no decide: nativa 1920x1080 contra 1280x720'

# EL CASO DEL 24/09: juego + la capsula dice que no se pinta = CIEGA
PonVisible '0' 1 5000
Comp 'con juego, si la capsula dice que no se ve, esta CIEGA' ((Test-CapsulaCiega) -eq $true) 'el caso de A Way Out'

# UN DATO VIEJO NO VALE: 30 s con una cadencia declarada de 5 s son mas de tres cadencias, y eso
# es una capsula colgada o muerta, no una capsula ciega
PonVisible '0' 30 5000
Comp 'un no-se-ve viejo no cuenta' ((Test-CapsulaCiega) -eq $false) '30 s con cadencia de 5 s: ante la duda, se ve'

# Y EL PLAZO ES SU CADENCIA, NO UN NUMERO A MANO: la MISMA antiguedad con una cadencia declarada
# de 20 s si cae dentro de las tres cadencias, y entonces el 0 vale. Con un umbral fijo de 15 s
# -que es lo que tienta escribir- este caso sale rojo.
PonVisible '0' 30 20000
Comp 'y con cadencia de 20 s ese mismo dato si vale' ((Test-CapsulaCiega) -eq $true) '30 s, por debajo de 3 x 20 s'

# LA PRIMERA LINEA DE CADA ARRANQUE LLEVA cada=0 (no hay anterior), y ahi vale la cadencia
# declarada del reloj de la capsula, 5 s. Si el 0 se tomase al pie de la letra, 3 x 0 = 0 y TODO
# dato seria viejo: nunca se daria por ciega, que es exactamente el fallo que la idea 67 arreglo.
PonVisible '0' 6 0
Comp 'con cada=0 vale la cadencia de 5 s de la capsula' ((Test-CapsulaCiega) -eq $true) '6 s, por debajo de 3 x 5 s'
PonVisible '0' 30 0
Comp 'y con cada=0 un dato de 30 s si es viejo' ((Test-CapsulaCiega) -eq $false) '30 s, por encima de 3 x 5 s'

# SIN FICHERO: no hay quien lo diga, se supone visible
BorraVisible
Comp 'sin fichero, se da por visible' ((Test-CapsulaCiega) -eq $false) 'ante la duda, no inventar'
# VACIO (la capsula acaba de arrancar y el reloj no ha latido) y con basura dentro (truncado)
[IO.File]::WriteAllText($rutaVis, '')
Comp 'con el fichero vacio, tambien' ((Test-CapsulaCiega) -eq $false) ''
[IO.File]::WriteAllText($rutaVis, "0 ayer a las tantas 5000`r`n")
Comp 'y con una linea que no se entiende, tambien' ((Test-CapsulaCiega) -eq $false) 'una hora ilegible no es un no-se-ve'
try { Remove-Item -LiteralPath $TmpDir -Recurse -Force } catch {}

Write-Host ''
Write-Host '-- 3. y la capsula escribe lo que Nova lee (las dos puntas del contrato) --'
# SIN ESTO NO HAY NADA QUE LEER, y Get-UiVisible devuelve $null siempre, o sea 'se ve' siempre:
# el fallo de antes de la idea 67 volveria en silencio y todos los casos de arriba seguirian ok.
$cs = [IO.File]::ReadAllText((Join-Path $Raiz 'nova_ui.cs'))
Comp 'la capsula escribe ui-visible.txt' ($cs -match 'ui-visible\.txt') 'la puerta por la que entra el dato'
Comp 'y mira el modo exclusivo, no solo su opacidad' ($cs -match 'SHQueryUserNotificationState') 'lo que tapaba A Way Out'
Comp 'y la hora, en el formato que Nova parsea' ($cs -match 'yyyy-MM-dd HH:mm:ss') 'el mismo de TryParseExact'
Comp 'y lo apunta con su reloj, no una sola vez' ($cs -match 'relojVisible') ''
Comp 'y ese reloj late a los 5 s que Nova supone con cada=0' ($cs -match 'relojVisible\.Interval = TimeSpan\.FromMilliseconds\(5000\)') 'si cambia uno sin el otro, el plazo miente'

Write-Host ''
Write-Host '-- 4. y se usa para no hablarle a una pantalla que no esta --'
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
Write-Host '-- 5. y avisa si el juego te dejo la pantalla cambiada (idea 6) --'
Comp 'existe la comprobacion al cerrar el juego' ($sinCom -match "Send-AvisoEntorno 'pantalla-cambiada'") ''
Comp 'y NO se la cambia sola' (-not ($sinCom -match "pantalla-cambiada[^\n]{0,300}Set-Resolucion|ChangeDisplaySettings")) 'en portatil, bajarla a veces es a proposito'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova sabe cuando no se la ve'
exit 0
