# CON UN JUEGO DELANTE, LA CAPSULA APAGA LO QUE NADIE MIRA (26/09, idea 20 de las 121).
#
# LO MEDIDO: 73.222 segundos de juego -20,3 horas- en diez dias distintos, contados sobre
# memoria\juegos.json. Y en todo ese tiempo la capsula NO SE DUERME NUNCA: la condicion de
# Dormir() pide string.IsNullOrEmpty(juegoActual), o sea que con un juego delante los cinco
# relojes siguen corriendo enteros.
#
# LO CONTABLE, y solo se dice lo contable: los cinco relojes suman 65,28 tics por segundo
# (300 ms, 80 ms, 33 ms, 250 ms y 66 ms) y los DOS que se apagan aqui son 45,45 de ellos, el
# 69,6 %. Ademas, cada tic de la mirada hace TRES llamadas al sistema -GetCursorPos,
# GetForegroundWindow y GetWindowRect-, unas 45 por segundo que con un juego a pantalla
# completa devuelven siempre lo mismo.
# LO QUE NO SE DICE, porque no esta medido: cuanto nucleo ahorra. El 28 % que cita el
# comentario del latido es del 13/09 y es el coste de ANTES del tope de 12 fps que ya se
# aplica, y no hay ningun medidor de CPU de la capsula en tools\.
#
# LA ROTURA QUE ESTE BANCO EXISTE PARA CAZAR: que alguien pare tambien el reloj de 80 ms o el
# latido. Eso deja la capsula tiesa mientras braya la esta mirando, y desde fuera no se
# distingue de que Nova se haya colgado.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$cs = Join-Path $raiz 'nova_ui.cs'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($cs, [Text.Encoding]::UTF8)
# SIN COMENTARIOS: si no, una nota que nombre la pieza contaria como usarla. Es lo que ya hace
# probar-capsula-foco.ps1 por el mismo motivo.
$sin = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^//' }) -join "`n"

Write-Host '-- 1. los dos relojes son CAMPOS, o el Stop ni compila --'
Comp 'relojMirada esta declarado como campo' ($sin -match '(?m)^\s*DispatcherTimer\b[^;]*\brelojMirada\b') ''
Comp 'relojTic33 tambien' ($sin -match '(?m)^\s*DispatcherTimer\b[^;]*\brelojTic33\b') ''
# COMO var LOCALES DEL CONSTRUCTOR NO SE PUEDEN PARAR: es el fallo que habria si alguien los
# devuelve a como estaban.
Comp '  y ya no son var locales del constructor' (
    $sin -notmatch 'var relojMirada = new DispatcherTimer' -and $sin -notmatch 'var reloj2 = new DispatcherTimer') 'un .Stop() sobre una local ni compila'
Comp '  y siguen con sus intervalos de siempre' (
    $sin -match 'relojTic33\.Interval = TimeSpan\.FromMilliseconds\(33\)' -and
    $sin -match 'relojMirada\.Interval = TimeSpan\.FromMilliseconds\(66\)') '33 ms y 66 ms'

Write-Host ''
Write-Host '-- 2. AhorroJuego: para los dos, Y LOS VUELVE A ARRANCAR --'
$iA = $sin.IndexOf('void AhorroJuego()')
Comp 'existe AhorroJuego' ($iA -ge 0) ''
$iFin = $sin.IndexOf('void Dormir()')
$cuerpo = if ($iA -ge 0 -and $iFin -gt $iA) { $sin.Substring($iA, $iFin - $iA) } else { '' }
Comp '  y se lee entero, hasta Dormir' ($cuerpo -ne '') ''
foreach ($p in @('relojMirada.Stop()', 'relojTic33.Stop()', 'relojMirada.Start()', 'relojTic33.Start()')) {
    Comp "  hace $p" ($cuerpo.Contains($p)) ''
}
# PARAR SIN RESTAURAR ES MEDIA FUNCION: al salir del juego la capsula se quedaria tiesa, que
# es justo el riesgo de esta idea.
Comp '  y al volver da un tic de la mirada' ($cuerpo -match 'relojMirada\.Start\(\); Mirar\(\)') 'raton, cerca y ventanaMirada se quedaron congelados'
# IDEMPOTENTE: esto lo llama LeerEstado, que corre doce veces por segundo.
Comp '  y no toca nada si ya esta como toca' ($cuerpo -match 'if \(debe == ahorroJuego\) \{ return; \}') 'LeerEstado corre 12 veces por segundo'
# LAS GUARDAS DE NOVA_DIAG SE RESPETAN: si alguien apago una pieza a mano para medir, no se le
# vuelve a encender por detras.
Comp '  y respeta el apagado manual de NOVA_DIAG' (
    @([regex]::Matches($cuerpo, 'Sin\("mirar"\)')).Count -eq 2 -and
    @([regex]::Matches($cuerpo, 'Sin\("tic33"\)')).Count -eq 2) 'dos veces cada uno: al parar y al arrancar'
# Y NO PUEDE TUMBAR LA LECTURA DE ESTADO.
Comp '  y un fallo aqui no tumba nada' ($cuerpo -match 'catch \{ \}') ''

Write-Host ''
Write-Host '-- 3. LO QUE NO SE APAGA NUNCA, que es la comprobacion que importa --'
# ESTA ES LA ROTURA QUE HAY QUE CAZAR. El reloj de 80 ms es el que lee el estado: pararlo deja
# la capsula tiesa de verdad. El latido y el parpadeo son el "esta viva". El de 300 ms la
# mantiene por encima del juego.
foreach ($p in @('reloj.Stop()', 'parpadeo.Stop()', 'relojZ.Stop()', 'reloj4.Stop()')) {
    Comp "AhorroJuego NO hace $p" (-not $cuerpo.Contains($p)) ''
}
Comp '  ni toca el latido' ($cuerpo -notmatch 'Latido') 'el latido es el "esta viva"'
# Y EN TODO EL FICHERO TAMPOCO: si alguien lo pone en otro sitio, el efecto es el mismo.
Comp 'y nadie para el reloj del estado en ningun sitio' ($sin -notmatch '\breloj\.Stop\(\)') 'es lo que mantiene viva la capsula'
Comp '  ni el parpadeo' ($sin -notmatch '\bparpadeo\.Stop\(\)') ''

Write-Host ''
Write-Host '-- 4. y solo con la boca quieta --'
# Si se apagara tambien mientras Nova habla o escucha, se perderian el lipsync y la onda, que
# es justo cuando braya la esta mirando.
Comp 'la condicion mira si hay un juego delante' ($cuerpo -match 'juegoActual') ''
Comp '  Y si esta en reposo' ($cuerpo -match 'bool quieto = \(estadoActual == "reposo"') 'hablando se perderian el lipsync y la onda'
Comp '  y ese "quieto" entra en la decision' ($cuerpo -match 'bool debe = [^;]*&& quieto') 'la variable suelta no sirve de nada'
Comp '  con la misma senal que usa Dormir' ($sin -match 'string\.IsNullOrEmpty\(juegoActual\)') 'la de 905, invertida'

Write-Host ''
Write-Host '-- 5. se llama desde DOS sitios, no solo al entrar al juego --'
# Con la llamada SOLO en la rama del juego, al empezar a hablar CON el juego delante los dos
# relojes seguirian parados y Nova hablaria con la boca quieta.
$iL = $sin.IndexOf('void LeerEstado()')
$blL = if ($iL -ge 0) { $sin.Substring($iL) } else { '' }
$nLl = @([regex]::Matches($blL, 'AhorroJuego\(\);')).Count
Comp 'LeerEstado la llama dos veces' ($nLl -ge 2) "$nLl llamadas"
Comp '  una al entrar o salir del juego' ($blL -match 'if \(cambioJuego\) \{ AhorroJuego\(\); \}') ''
Comp '  y otra al cambiar de estado' ($blL -match 'textoActual = txt;\s*\r?\n\s*AhorroJuego\(\);') 'si no, hablaria con la boca quieta'

Write-Host ''
Write-Host '-- 6. el diagnostico manual sigue entero --'
# Los ocho interruptores de NOVA_DIAG nunca se han usado (grep en assistant.ps1 da cero), pero
# son la unica forma de medir lo que cuesta cada pieza. El camino automatico no se los come.
$piezas = @([regex]::Matches($sin, 'Sin\("([a-z0-9]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
Comp 'siguen los ocho interruptores' ($piezas.Count -eq 8) ($piezas -join ', ')
foreach ($p in @('transp', 'z', 'blur', 'efectos', 'sombras', 'tic33', 'mirar', 'latido')) {
    if ($piezas -notcontains $p) { Comp "  falta $p" $false '' }
}

Write-Host ''
Write-Host '-- 7. y siguen siendo cinco relojes, con sus intervalos --'
# Para que el dia que alguien anada un sexto esto no se quede en verde midiendo un fichero que
# ya no es ese. De estos cinco sale el 65,28 tics/s del que se habla arriba.
$ms = @([regex]::Matches($sin, 'Interval = TimeSpan\.FromMilliseconds\((\d+)\)') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
Write-Host ("       intervalos que hay en el fichero: " + ($ms -join ', '))
Comp 'los cinco de la cuenta siguen ahi' (
    ($ms -contains 300) -and ($ms -contains 80) -and ($ms -contains 33) -and
    ($ms -contains 250) -and ($ms -contains 66)) '300, 80, 33, 250 y 66 ms'
foreach ($v in @(300, 80, 33, 250, 66)) {
    if ($ms -notcontains $v) { Comp "  falta el de $v ms" $false '' }
}
$tics = 0.0
foreach ($v in @(300, 80, 33, 250, 66)) { $tics += 1000.0 / $v }
Comp '  y suman los 65 tics por segundo de la cuenta' ([Math]::Abs($tics - 65.28) -lt 0.1) ("{0:N2}" -f $tics)
$apagados = (1000.0 / 33) + (1000.0 / 66)
Comp '  de los que estos dos son el 70 %' ([Math]::Abs(($apagados / $tics) - 0.696) -lt 0.01) ("{0:N1} de {1:N2}" -f $apagados, $tics)

Write-Host ''
Write-Host '-- 8. contra las horas de juego de verdad --'
$seg = 0
$jj = Join-Path $raiz 'memoria\juegos.json'
if (Test-Path -LiteralPath $jj) {
    try {
        $j = Get-Content -LiteralPath $jj -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) {
            foreach ($d in $p.Value.dias.PSObject.Properties) { $seg += [int]$d.Value }
        }
    } catch {}
}
Write-Host ("       {0:N1} horas de juego apuntadas, y en todas ellas la capsula no se dormia" -f ($seg / 3600.0))
Comp 'braya juega de verdad, y bastante' ($seg -ge 36000) "$([int]($seg/3600)) horas"

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  con un juego delante la capsula apaga lo que nadie mira'
exit 0
