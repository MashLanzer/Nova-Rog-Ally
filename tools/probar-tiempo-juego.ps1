# EL AVISO DE LAS DOS HORAS SALTO UNA VEZ EN CATORCE DIAS (23/09, idea 11).
#
# EL DATO: con juego.avisoMinutos = 120, el aviso debio saltar TRES dias -It Takes Two el
# 15/09 (5 h 38 min), el 20/09 (2 h 45) y el 22/09 (3 h 12)- y "JUEGO: aviso de tiempo"
# aparece UNA SOLA VEZ en todo el registro: 15/09 20:31.
#
# LAS DOS CAUSAS:
#  1. La condicion pedia 120 minutos de PRIMER PLANO SIN UN SOLO CORTE. $script:juegoDesde
#     se pone a cero cada vez que cambia la ventana de delante, y eso pasa en cuanto miras
#     Discord, el navegador o la propia capsula de Nova. El repositorio ya sabia de esto: el
#     comentario de Exit-Juego dice "un alt-tab de 10 s parte la sesion en dos, y el log del
#     18/09 tiene tres de esos", y por eso se arreglo $script:juegoSesionMin... pero nadie
#     aplico el mismo arreglo al aviso.
#  2. Y cada reinicio de Nova ponia el contador a cero: 244 arranques en 15 dias, 16,3 al
#     dia. El unico aviso de catorce dias es el unico tramo de dos horas sin alt-tab ni
#     reinicio.
#
# Y EL SEGUNDO FALLO: habitos.json llevaba una cuenta PARALELA (minutosJuego) que solo se
# escribia al cambiar de ventana con Nova viva. Le falta entero el 15/09 de 5 h 38, le falta
# el 16/09, y el 20/09 apunta 2 minutos donde juegos.json apunta 2 h 45. Encima cada fichero
# usaba un "dia" distinto. Se queda UNA fuente de verdad.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el andamio: reloj de mentira y memoria en un temporal -------------------
$script:ahoraMs = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tj-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
$script:logs = @()
function Log([string]$m) { $script:logs += $m }
$script:invitado = $false
$script:juegoActivo = ''
$script:tiempoJuegoVisto = 0
foreach ($n in @('Get-JuegosMem', 'Save-JuegosMem', 'Get-DiasJuego', 'Get-DiaJuego',
                 'Add-TiempoJuego', 'Save-TiempoJuego', 'Get-TiempoJugado',
                 'Get-MinutosJuegoHoy', 'Format-Minutos')) { Invoke-Expression (Traer $n) }
$script:juegosMem = $null
$script:tiempoJuegoPend = @{}

Write-Host ''
Write-Host '-- 1. el dia de jugar empieza a las cinco, no a medianoche --'
# La unica sesion continua medible del registro va del 15/09 18:31 al 16/09 00:45: seis horas
# y cuarto. Con el dia natural, el contador se pone a cero EN MITAD de esa partida, que es
# justo la parte de la noche en la que el aviso hace falta.
Comp 'a las 23:59 del 15 es dia 15' ((Get-DiaJuego ([datetime]'2026-09-15 23:59')) -eq '2026-09-15')
Comp 'y a las 00:45 del 16, tambien' ((Get-DiaJuego ([datetime]'2026-09-16 00:45')) -eq '2026-09-15') 'la sesion no se parte'
Comp 'a las 04:59 sigue siendo el 15' ((Get-DiaJuego ([datetime]'2026-09-16 04:59')) -eq '2026-09-15')
Comp 'pero a las 05:01 ya es el 16' ((Get-DiaJuego ([datetime]'2026-09-16 05:01')) -eq '2026-09-16')

Write-Host ''
Write-Host '-- 2. los minutos de hoy se suman de las tres fuentes --'
$hoyClave = Get-DiaJuego
$script:juegosMem = @{ 'It Takes Two' = @{ dias = @{ $hoyClave = 7200 } } }
$script:tiempoJuegoPend = @{}
Comp 'lo que esta en disco cuenta' ((Get-MinutosJuegoHoy 'It Takes Two') -eq 120) "$(Get-MinutosJuegoHoy 'It Takes Two') min"
$script:juegosMem = @{ 'It Takes Two' = @{ dias = @{ $hoyClave = 7100 } } }
$script:tiempoJuegoPend = @{ 'It Takes Two' = 100 }
Comp 'y lo que aun no se ha volcado, tambien' ((Get-MinutosJuegoHoy 'It Takes Two') -eq 120) 'se vuelca cada 300 s'
$script:juegosMem = @{ 'It Takes Two' = @{ dias = @{ $hoyClave = 3600 } }
                       'ELDEN RING' = @{ dias = @{ $hoyClave = 1800 } } }
$script:tiempoJuegoPend = @{}
Comp 'sin nombre, suma todos los juegos' ((Get-MinutosJuegoHoy) -eq 90) "$(Get-MinutosJuegoHoy) min"
Comp 'y con nombre, solo ese' ((Get-MinutosJuegoHoy 'ELDEN RING') -eq 30)
# el tramo vivo: lo que se esta jugando ahora y todavia no se ha apuntado
$script:juegoActivo = 'It Takes Two'
$script:ahoraMs = 1000000
$script:tiempoJuegoVisto = 1000000 - 60000     # un minuto en marcha
Comp 'el tramo de ahora mismo tambien cuenta' ((Get-MinutosJuegoHoy 'It Takes Two') -eq 61) "$(Get-MinutosJuegoHoy 'It Takes Two') min"
# pero si la consola durmio, ese tramo no es tiempo de juego.
# EL RELOJ TIENE QUE IR HACIA ADELANTE: la primera version ponia tiempoJuegoVisto en
# negativo y entonces no entraba ni en el if exterior, asi que la rotura no cantaba. Aqui
# el reloj avanza una hora y el ultimo visto se queda donde estaba, que es lo que pasa de
# verdad cuando la consola se suspende.
$script:ahoraMs = 4600000
$script:tiempoJuegoVisto = 1000000              # hace una hora
Comp 'pero una consola dormida no suma una hora' ((Get-MinutosJuegoHoy 'It Takes Two') -eq 60) 'el mismo tope de 120 s de Add-TiempoJuego'
$script:ahoraMs = 1000000
$script:juegoActivo = ''; $script:tiempoJuegoVisto = 0

Write-Host ''
Write-Host '-- 3. EL ALT-TAB: esto es lo que hacia que el aviso no saltara --'
# Cuarenta tramos de tres minutos con un cambio de ventana entre cada dos. Con la cuenta
# vieja -tramo de primer plano- el contador se ponia a cero cuarenta veces y no llegaba a 120
# jamas. Con la cuenta por dia, son 120 minutos.
$script:juegosMem = @{}
$script:tiempoJuegoPend = @{}
$script:ahoraMs = 0
# los tramos son de 120 s porque ese es el tope de Add-TiempoJuego: un tramo mas largo es
# una consola que durmio, no tiempo de juego. Sesenta tramos de dos minutos son dos horas.
for ($i = 0; $i -lt 60; $i++) {
    Add-TiempoJuego 'It Takes Two' 120
    $script:ahoraMs += 130000                  # y un alt-tab de 10 s entre cada dos
}
Save-TiempoJuego
$minAlt = Get-MinutosJuegoHoy 'It Takes Two'
Comp 'con 60 alt-tabs, siguen siendo 120 minutos' ($minAlt -eq 120) "$minAlt min"
# y la condicion del aviso, sacada del bucle de verdad
$script:juegoAvisoDia = Get-DiaJuego
$script:juegoAvisoUlt = 0
$script:juegoAvisoCada = 0
$script:juegoAvisoNo = ''
$JuegoAvisoMin = 120
$pasoAv = if ($script:juegoAvisoCada -gt 0) { $script:juegoAvisoCada } else { $JuegoAvisoMin }
$dispara = ($minAlt -ge ($script:juegoAvisoUlt + $pasoAv))
Comp 'y el aviso dispara' $dispara 'con la cuenta vieja no disparaba NUNCA'

Write-Host ''
Write-Host '-- 4. EL REINICIO: 16,3 arranques al dia no pueden borrar la cuenta --'
$script:juegosMem = $null       # esto es lo que pasa al arrancar Nova: se relee del disco
$minTrasReinicio = Get-MinutosJuegoHoy 'It Takes Two'
Comp 'tras reiniciar Nova, siguen siendo 120' ($minTrasReinicio -eq 120) "$minTrasReinicio min"

Write-Host ''
Write-Host '-- 5. pero no avisa dos veces del mismo dia --'
$script:juegoAvisoUlt = 120
$dispara2 = ($minTrasReinicio -ge ($script:juegoAvisoUlt + $pasoAv))
Comp 'con el aviso ya dado, no repite' (-not $dispara2) 'si no, avisaria 16 veces al dia'
Comp 'y con avisoCada=0 solo una vez al dia' (($script:juegoAvisoCada -eq 0) -and ($script:juegoAvisoUlt -gt 0))
# al cambiar el dia, vuelve a estar armado
$script:juegoAvisoDia = '2026-01-01'
$rearma = ($script:juegoAvisoDia -ne (Get-DiaJuego))
Comp 'al cambiar de dia se rearma solo' $rearma

Write-Host ''
Write-Host '-- 6. y "hoy no me avises" calla, pero solo hoy --'
$script:juegoAvisoNo = Get-DiaJuego
Comp 'hoy no avisa' ($script:juegoAvisoNo -eq (Get-DiaJuego)) 'la guarda del bucle mira esto'
Comp 'y manana ya no vale' ((Get-DiaJuego ([datetime]::Now.AddDays(1))) -ne $script:juegoAvisoNo) 'se cae solo, no es un modo sin salida'
$script:juegoAvisoNo = ''

Write-Host ''
Write-Host '-- 7. y ya no quedan dos cuentas peleandose --'
$codigo = ($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp 'la variable vieja del aviso ya no existe' ($codigo -notmatch 'juegoAvisado') 'era lo que se rearmaba en cada alt-tab'
$exitJ = SinComentarios (Traer 'Exit-Juego')
Comp 'Exit-Juego ya no escribe minutosJuego' ($exitJ -notmatch 'minutosJuego\[') 'esa copia se perdia en cada reinicio'
Comp 'y usa Floor, no [int], para los minutos' ($exitJ -match '\$minJ = \[int\]\[Math\]::Floor') 'anclado a $minJ: hay otro Floor mas arriba. [int] redondea, y tres alt-tabs de 40 s daban 3 minutos'
$saveT = SinComentarios (Traer 'Save-TiempoJuego')
$getT = SinComentarios (Traer 'Get-TiempoJugado')
Comp 'Save-TiempoJuego usa el dia de jugar' ($saveT -match '\$diaT = Get-DiaJuego') 'anclado a $diaT: hay otro Get-DiaJuego dos lineas mas abajo'
Comp 'y Get-TiempoJugado tambien' ($getT -match 'Get-DiaJuego') 'las dos cuentas, la misma'
Comp 'el aviso del bucle cuenta por dia' ($codigo -match 'Get-MinutosJuegoHoy \$j')
Comp 'y ya no por el tramo de primer plano' ($codigo -notmatch 'ElapsedMilliseconds - \$script:juegoDesde\) -ge \(\$JuegoAvisoMin')

Write-Host ''
Write-Host '-- 8. y el estado del aviso sobrevive al reinicio --'
$hbDef = @($fuente -split "`r?`n" | Where-Object { $_ -match 'avisoJuego = @\{ dia' })
Comp 'avisoJuego esta en habitos por defecto' ($hbDef.Count -ge 1)
Comp 'se lee del fichero' ($codigo -match "avisoJuego'\] -and \`$crudoH\.avisoJuego")
Comp 'y se escribe' ($codigo -match 'avisoJuego = \$hb\.avisoJuego')
$savA = SinComentarios (Traer 'Save-AvisoJuego')
Comp 'y hay una funcion que lo apunta' ($savA -match 'Save-Habitos') 'si no, 16 avisos al dia'
# Y QUE SE LLAME DE VERDAD, no solo que exista: la rotura de quitar la llamada dentro del if
# del aviso no cantaba con la comprobacion de arriba sola.
Comp 'y el bucle la llama al avisar' ($codigo -match '\$script:juegoAvisoUlt = \[int\]\[Math\]::Floor\(\$minHoy / \$pasoAv\) \* \$pasoAv[\s\S]{0,80}Save-AvisoJuego')
Comp 'y tambien al cambiar de dia' ($codigo -match '\$script:juegoAvisoUlt = 0; Save-AvisoJuego')
Comp 'y el bucle mira el "hoy no me avises"' ($codigo -match '\$script:juegoAvisoNo -ne \$diaAv') 'si no, el silencio de hoy no vale para nada'

Write-Host ''
Write-Host "-- 9. 'cuanto llevo' contesta el DIA, no el tramo (idea 11-B) --"
# Antes contestaba ($sw - $juegoDesde)/60000: el tiempo desde el ultimo alt-tab o desde el
# ultimo arranque de Nova. Con 244 arranques en 15 dias, ese numero no dice nada.
Invoke-Expression (Traer 'Get-FraseTiempoHoy')
$script:juegosMem = @{ 'It Takes Two' = @{ dias = @{ (Get-DiaJuego) = 9000 } } }   # 150 min
$script:tiempoJuegoPend = @{}
$script:juegoActivo = 'It Takes Two'
$script:ahoraMs = 1000000
$script:tiempoJuegoVisto = 0
$script:juegoDesde = 1000000 - (12 * 60000)      # doce minutos en esta sentada
$fr = Get-FraseTiempoHoy 'It Takes Two'
Comp 'dice lo de hoy' ($fr -match 'hoy llevas') $fr
Comp 'y son las dos horas y media de hoy' ($fr -match '2 horas y 30 minutos') $fr
Comp 'y anade la sentada de ahora' ($fr -match 'en esta sentada') $fr
# EL CASO DEL REINICIO: el tramo se reinicia y el dia no, asi que un tramo MAYOR que el dia
# significa que el tramo esta mal, no que se haya jugado mas.
# EL RELOJ TIENE QUE IR HACIA ADELANTE: con $juegoDesde negativo no entra ni en el if
# ($juegoDesde -gt 0) y la rotura no cantaba. Se adelanta el reloj en vez de retrasar el
# arranque, que es lo que pasa de verdad.
$script:ahoraMs = 13000000
$script:juegoDesde = 1000000                     # doscientos minutos de tramo
$fr2 = Get-FraseTiempoHoy 'It Takes Two'
Comp 'pero un tramo mayor que el dia no se dice' ($fr2 -notmatch 'en esta sentada') $fr2
$script:ahoraMs = 1000000
# y una sentada de menos de cinco minutos tampoco: es ruido
$script:juegoDesde = 1000000 - (2 * 60000)
Comp 'ni una sentada de dos minutos' ((Get-FraseTiempoHoy 'It Takes Two') -notmatch 'en esta sentada')
$script:juegosMem = @{}
$script:tiempoJuegoPend = @{}
Comp 'y sin nada jugado, lo dice' ((Get-FraseTiempoHoy '') -match 'todavia no llevas nada')

Write-Host ''
Write-Host '-- 10. el aviso cada rato, y que no suelte los atrasados de golpe --'
Invoke-Expression (Traer 'Save-AvisoJuego')
Invoke-Expression (Traer 'Format-MinutosDichos')
Invoke-Expression (Traer 'Set-AvisoJuego')
Invoke-Expression (Traer 'Set-AvisoJuegoHoy')
$script:habitos = $null
function Get-Habitos { if (-not $script:habitos) { $script:habitos = @{ avisoJuego = @{} } }; return $script:habitos }
function Save-Habitos { }
$script:juegosMem = @{ 'It Takes Two' = @{ dias = @{ (Get-DiaJuego) = 10800 } } }   # tres horas
$script:juegoActivo = ''
$r10 = Set-AvisoJuego 60
Comp 'se enciende y lo dice' ($r10 -match 'cada una hora') $r10
Comp 'y se pone al dia al encenderse' ($script:juegoAvisoUlt -eq 180) "$($script:juegoAvisoUlt) min"
# la condicion del bucle, con el aviso recien puesto a las tres horas
$pasoB = $script:juegoAvisoCada
Comp 'no suelta tres avisos atrasados de golpe' (-not ((Get-MinutosJuegoHoy) -ge ($script:juegoAvisoUlt + $pasoB))) 'seria lo que te hace apagarlo'
# y a los 240 minutos, si
$script:juegosMem = @{ 'It Takes Two' = @{ dias = @{ (Get-DiaJuego) = 14400 } } }
Comp 'pero a la hora siguiente avisa' ((Get-MinutosJuegoHoy) -ge ($script:juegoAvisoUlt + $pasoB))
$r10b = Set-AvisoJuego 0
Comp 'y se quita' (($script:juegoAvisoCada -eq 0) -and ($r10b -match 'quitado')) $r10b

Write-Host ''
Write-Host '-- 11. y los dos silencios se caen SOLOS (regla de los modos) --'
$rs = Set-AvisoJuegoHoy $false
Comp 'hoy no me avises calla' (($script:juegoAvisoNo -eq (Get-DiaJuego)) -and ($rs -match 'Manana vuelvo')) $rs
Comp 'y la frase dice cuando vuelve' ($rs -match 'Manana') 'un modo que no dice como se sale, no vale'
Comp 'y se quita diciendolo' ((Set-AvisoJuegoHoy $true) -match 'vuelvo a avisarte') ''
# el silencio GENERAL, que era el unico modo de Nova sin plazo
Invoke-Expression (Traer 'Set-AvisosEntorno')
Invoke-Expression (Traer 'Test-FinSilencio')
$rg = Set-AvisosEntorno $false
Comp 'no me avises de nada calla' ($script:entornoCallado) ''
Comp 'y DICE que se le pasa manana' ($rg -match 'manana') $rg
Comp 'y apunta el dia' ($script:entornoCalladoDia -eq (Get-DiaJuego)) $script:entornoCalladoDia
Test-FinSilencio
Comp 'el mismo dia sigue callado' ($script:entornoCallado) 'no se cae antes de tiempo'
$script:entornoCalladoDia = '2026-01-01'
Test-FinSilencio
Comp 'y al dia siguiente vuelve SOLO' (-not $script:entornoCallado) 'esto era un modo del que solo se salia acordandose'

Write-Host ''
Write-Host '-- y el codigo dice lo que tiene que decir --'
$codB = ($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
Comp "el patron de 'cuanto llevo jugando' esta anclado en $" ($codB -match 'hace cuanto juego\)\$') 'con \b se tragaba "...jugando hoy"'
Comp 'el ejecutor contesta el dia, no el tramo' ($codB -match "'tiempoJuego' \{[\s\S]{0,200}Get-FraseTiempoHoy")
Comp 'y ya no hay una resta de juegoDesde ahi' ($codB -notmatch "'tiempoJuego' \{[\s\S]{0,200}ElapsedMilliseconds - \\$script:juegoDesde")
Comp 'el suelo de quince minutos sigue puesto' ($codB -match '\$minA -gt 0 -and \$minA -lt 15') 'por debajo es ruido, no aviso'
Comp 'y el bucle mira si el silencio caduco' ($codB -match 'try \{ Test-FinSilencio \} catch') 'si no, el modo sin salida vuelve'

Write-Host '-- 12. y las frases llegan a donde tienen que llegar --'
# ESTO SE EJECUTA CON EL PARSER DE VERDAD. Los patrones nacieron en Process-Texto y eran
# CODIGO MUERTO: 'avisame cada hora' lo cogia antes el patron de 'di/dime <algo>' y la regla
# generica 'cada', y 'quita el aviso de cada hora' caia en el de cancelar temporizadores.
# Moverlos a Invoke-FastCommand tampoco bastaba. Solo se vio pasandolos por -Probar.
$tmpF = Join-Path ([System.IO.Path]::GetTempPath()) ('fr-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.txt')
@('cuanto llevo hoy', 'cuanto jugue esta semana', 'cuanto llevo jugando hoy',
  'avisame cada hora', 'avisame cada media hora', 'quita el aviso de cada hora',
  'hoy no me avises del tiempo', 'vuelve a avisarme del juego',
  'cuanto ocupa hollow knight', 'a que he jugado hoy') | Set-Content -LiteralPath $tmpF -Encoding UTF8
$sal = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ruta -Probar $tmpF 2>&1 | Out-String)
Remove-Item -LiteralPath $tmpF -Force -ErrorAction SilentlyContinue
Comp "'cuanto llevo hoy' se reconoce" ($sal -match 'cuanto llevo hoy\s+->\s+tiempo de juego')
Comp "'cuanto jugue esta semana' tambien" ($sal -match 'cuanto jugue esta semana\s+->\s+tiempo de juego') 'el pasado simple no casaba con "he jugado"'
Comp "'cuanto llevo jugando hoy' NO cae en el tramo" ($sal -match 'cuanto llevo jugando hoy\s+->\s+tiempo de juego') 'el \b del patron viejo se lo tragaba'
Comp "'avisame cada hora' son 60 minutos" ($sal -match 'avisame cada hora\s+->\s+avisarte cada 60 minutos') 'antes creaba una regla generica'
Comp "'avisame cada media hora' son 30" ($sal -match 'avisame cada media hora\s+->\s+avisarte cada 30 minutos')
Comp "'quita el aviso de cada hora' lo quita" ($sal -match 'quita el aviso de cada hora\s+->\s+quitar el aviso') 'antes cancelaba un temporizador'
Comp "'hoy no me avises del tiempo' llega" ($sal -match 'hoy no me avises del tiempo\s+->\s+hoy no avisarte')
Comp "'vuelve a avisarme del juego' llega" ($sal -match 'vuelve a avisarme del juego\s+->\s+volver a avisarte')
# y lo que NO puede cambiar
Comp "'cuanto ocupa hollow knight' sigue siendo el tamano" ($sal -match 'cuanto ocupa hollow knight\s+->\s+tamano en disco')
Comp "'a que he jugado hoy' sigue siendo lo jugado" ($sal -match 'a que he jugado hoy\s+->\s+lo jugado')

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  el tiempo de juego se cuenta por dia, y el aviso ya no lo mata un alt-tab'
exit 0
