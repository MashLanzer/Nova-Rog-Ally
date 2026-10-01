# LA PANTALLA NO SE APAGA NUNCA Y NOVA NO LO SABIA (27/09, idea 121 de las 121, la ultima)
#
# EL DATO, medido en esta consola: powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE da indice
# 0x00000000 en corriente ALTERNA y en CONTINUA, o sea "apagar la pantalla tras: nunca" en las dos, y
# WmiMonitorBrightness marca CurrentBrightness = 100. Con los 4.187 avisos aparcados por no haber
# nadie, eso no son ratos cortos: son noches con la pantalla encendida a tope. Y Nova no sabia nada:
# cero apariciones de LastBootUpTime, de uptime y de SendMessage en todo el archivo.
#
# UN DATO DE LA FICHA YA NO ES CIERTO: hablaba de 158,9 horas encendida desde el 19/09, y medido hoy
# la consola arranco a las 02:57 y lleva 11,6 horas. Braya la ha reiniciado. Lo que sigue en pie es
# lo otro, que es lo que importa: la pantalla no se apaga NUNCA por si sola.
#
# LO QUE ESTE BANCO PROTEGE, y lo primero es lo que decide todo:
#   1. que NO se apague nada mientras braya no lo encienda: nace apagado en config
#   2. que no saber algo NUNCA cuente a favor de apagar -ni el nivel, ni la presencia-
#   3. las tres guardas de la ficha: movimiento, altavoces y juego
#   4. que no quede ningun modo puesto ni se toque una opcion de energia de Windows
#   5. y que el parseo de powercfg aguante que Windows este traducido
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
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LAS PIEZAS DE VERDAD. Los dobles van DESPUES.
$quiero = @('Test-ApagarPantalla', 'Get-PantallaApagaTras', 'Get-HorasEncendida')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
# RECORTAR POR LOS LIMITES DE VERDAD, no por una ventana de N caracteres (27/09, idea 2). Los
# cuatro casos del cableado de abajo median "a menos de N caracteres de la firma", y una cuenta asi
# se pone roja sola en cuanto alguien escribe una linea dentro de la funcion.
function Cuerpo([string]$nombre) {
    $d = @($defs | Where-Object { $_.Name -eq $nombre })
    if ($d.Count -eq 0) { return '' }
    return (($d[0].Extent.Text -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
}
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 3 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)
$asg = $arbol.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$PantallaAltavozMin' }, $true)
Invoke-Expression ('$PantallaAltavozMin = ' + $asg.Right.Extent.Text)
Comp 'el suelo del nivel sale del fichero real' ($PantallaAltavozMin -gt 0) ([string]$PantallaAltavozMin)

Write-Host ''
Write-Host '-- 1. NACE APAGADO, Y ESO MANDA SOBRE TODO --'
Comp '1a. el interruptor nace en falso' ($sinCom -match "Get-Cfg 'entorno' 'apagarPantalla' \`$false") 'apagarle la pantalla es una accion sobre su maquina'
# con el interruptor en falso, ni con todo a favor
$r = Test-ApagarPantalla 600 600 0.0 $false 30 $false
Comp '1b. apagado, no apaga ni con 10 h sin nadie' (-not $r.apagar) ([string]$r.porque)
Comp '1c. y lo dice sin rodeos' ($r.porque -match 'no me has dicho') ''
# y encendido, ahi si
Comp '1d. encendido y con todo a favor, apaga' ((Test-ApagarPantalla 600 600 0.0 $false 30 $true).apagar) ''

Write-Host ''
Write-Host '-- 2. NO SABER NUNCA CUENTA A FAVOR DE APAGAR --'
Comp '2a. si no se sabe si suena algo, no apaga' (-not (Test-ApagarPantalla 600 600 -1 $false 30 $true).apagar) 'es el riesgo que la ficha nombra: un video sin tocar nada'
Comp '2b. y lo dice' ((Test-ApagarPantalla 600 600 -1 $false 30 $true).porque -match 'no se si suena') ''
Comp '2c. si no se sabe si hay alguien, no apaga' (-not (Test-ApagarPantalla -1 600 0.0 $false 30 $true).apagar) ''
Comp '2d. y lo dice' ((Test-ApagarPantalla -1 600 0.0 $false 30 $true).porque -match 'no se si hay alguien') ''
# el movimiento SI puede no saberse: entonces manda la otra senal
Comp '2e. sin acelerometro, manda la presencia' ((Test-ApagarPantalla 600 -1 0.0 $false 30 $true).apagar) 'el -1 del acelerometro no decide nada'
Comp '2f. pero sin las dos, no apaga' (-not (Test-ApagarPantalla -1 -1 0.0 $false 30 $true).apagar) ''

Write-Host ''
Write-Host '-- 3. LAS TRES GUARDAS DE LA FICHA --'
Comp '3a. con un juego delante, nunca' (-not (Test-ApagarPantalla 600 600 0.0 $true 30 $true).apagar) ''
Comp '3b. y lo dice' ((Test-ApagarPantalla 600 600 0.0 $true 30 $true).porque -match 'un juego delante') ''
Comp '3c. si algo esta sonando, nunca' (-not (Test-ApagarPantalla 600 600 0.5 $false 30 $true).apagar) 'un video no se apaga por no tocar nada'
Comp '3d. justo en el suelo del nivel, todavia no' (-not (Test-ApagarPantalla 600 600 ($PantallaAltavozMin * 2) $false 30 $true).apagar) ''
Comp '3e. y en silencio de verdad, si' ((Test-ApagarPantalla 600 600 0.0 $false 30 $true).apagar) ''
Comp '3f. si la movio hace un rato, no' (-not (Test-ApagarPantalla 600 5 0.0 $false 30 $true).apagar) 'el acelerometro es la senal que la ficha pide'
Comp '3g. y lo dice con los minutos' ((Test-ApagarPantalla 600 5 0.0 $false 30 $true).porque -match 'movido hace 5 min') ''
Comp '3h. si la movio hace mas del plazo, si' ((Test-ApagarPantalla 600 40 0.0 $false 30 $true).apagar) ''

Write-Host ''
Write-Host '-- 4. EL PLAZO --'
Comp '4a. con 29 min sin nadie y plazo 30, no' (-not (Test-ApagarPantalla 29 600 0.0 $false 30 $true).apagar) ''
Comp '4b. con 30 justos, si' ((Test-ApagarPantalla 30 600 0.0 $false 30 $true).apagar) ''
Comp '4c. y dice cuanto llevaba' ((Test-ApagarPantalla 30 600 0.0 $false 30 $true).porque -match '30 min sin nadie') ''
Comp '4d. el plazo entra por parametro' ((Test-ApagarPantalla 10 600 0.0 $false 5 $true).apagar) 'no es un numero de dentro'

Write-Host ''
Write-Host '-- 5. LO QUE WINDOWS TIENE PUESTO, LEIDO DE VERDAD --'
# ESTO LLAMA A powercfg DE VERDAD: es la unica forma de saber si el parseo aguanta que Windows este
# traducido, que es justo donde se rompe un regex escrito mirando la version en ingles.
$c = Get-PantallaApagaTras
Comp '5a. lee los dos indices' (([int]$c.alterna -ge 0) -and ([int]$c.continua -ge 0)) ('alterna ' + $c.alterna + ', continua ' + $c.continua)
Comp '5b. y en esta consola son cero: nunca se apaga' (([int]$c.alterna -eq 0) -and ([int]$c.continua -eq 0)) 'el dato de la idea, comprobado al correr'
$h = Get-HorasEncendida
Comp '5c. y sabe cuanto lleva encendida' ($h -gt 0) ([string]$h + ' h')
# UN RELOJ MOVIDO NO ES UN DATO, Y LA GUARDA TIENE DOS LADOS: con un 'ahora' del pasado salen horas
# negativas, y con uno muy del futuro salen decenas de miles. El caso de antes solo probaba el
# primero, y ese lo tapaba el propio -lt 0 de la comprobacion: quitar la guarda no ponia rojo nada.
Comp '5d. un arranque del futuro no cuenta' ((Get-HorasEncendida (Get-Date).AddYears(-2)) -lt 0) 'horas negativas: devuelve -1'
$lejos = Get-HorasEncendida (Get-Date).AddYears(3)
Comp '5e. ni un reloj adelantado tres anos' ($lejos -lt 0) ('sin la guarda serian ' + [int]((Get-Date).AddYears(3) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours + ' h')

Write-Host ''
Write-Host '-- 6. NO QUEDA NADA PUESTO --'
# CAMBIAR DE PLAN NO ES CAMBIAR UN PLAN (1/10, con la funcion 5 de las 20). Esto prohibia cualquier
# 'powercfg /setac...', y desde hoy existe Set-PlanEnergia, que hace '/setactive' A PROPOSITO: braya
# pide "pon el perfil turbo" y la consola expone sus perfiles como planes de Windows.
# LA DIFERENCIA ES LA QUE IMPORTA AQUI, que es de lo que va esta seccion -"no queda nada puesto"-:
#   - '/setacvalueindex', '/setdcvalueindex' y '/change' cambian valores DENTRO de un plan. Eso queda
#     puesto, es invisible y nadie lo deshace: sigue prohibido.
#   - '/setactive' cambia de plan, y eso se VE en Windows, lo pide braya y lo puede devolver con una
#     frase. No es algo que se quede puesto a su espalda.
Comp '6a. no se cambia ningun VALOR de energia' (-not ($sinCom -match 'powercfg /(setacvalueindex|setdcvalueindex|change|s\b)')) 'cambiar de plan si (funcion 5); cambiar sus valores no'
Comp '6b. la pantalla se enciende con el mismo sitio' ($sinCom -match 'function Set-PantallaApagada\(\[bool\]\$apagar = \$true\)') 'apagar y encender, una sola pieza'
Comp '6c. y encender es el -1 de lParam' ($sinCom -match '\$lp = if \(\$apagar\) \{ \[IntPtr\]2 \} else \{ \[IntPtr\]\(-1\) \}') ''
# EL BLOQUE DEL Add-Type, POR SU CIERRE DE VERDAD: el here-string va de @' a '@, y ahi estan sus
# limites. La cuenta de 1400 caracteres se quedaba corta sola con cada DllImport nuevo de al lado.
$iAT = $sinCom.IndexOf('Add-Type -Namespace Nova -Name Win')
$fAT = if ($iAT -ge 0) { $sinCom.IndexOf("`n'@", $iAT) } else { -1 }
$bloqueAT = if ($fAT -gt $iAT) { $sinCom.Substring($iAT, $fAT - $iAT) } else { '' }
Comp '6d. el P/Invoke va en el bloque que ya existia' ($bloqueAT -match 'public static extern IntPtr SendMessage') 'ni un Add-Type nuevo'
$cuerpoSP = Cuerpo 'Set-PantallaApagada'
Comp '6e. y no se crea ninguna tarea ni servicio' (($cuerpoSP -ne '') -and -not ($cuerpoSP -match '(schtasks|New-Service|Register-Scheduled)')) ''

Write-Host ''
Write-Host '-- 7. EL CABLEADO, Y LO QUE SI SE HACE HOY --'
Comp '7a. se lo cuenta una vez al dia' ($sinCom -match '\$script:pantallaDichoDia -eq \$dia') ''
Comp '7b. y cuelga del hueco diario, no del bucle' ($sinCom -match '(?s)Update-PromptOrdenes.{0,400}Test-DecirPantalla') 'powercfg cuesta 34 ms medidos'
Comp '7c. solo lo dice si de verdad no se apaga nunca' ($sinCom -match '\[int\]\$c\.alterna -ne 0 -and \[int\]\$c\.continua -ne 0') 'si Windows ya la apaga, no hay noticia'
Comp '7d. y dice si el interruptor esta puesto' ($sinCom -match 'entorno\.apagarPantalla') ''
$cuerpoNA = Cuerpo 'Get-NivelAltavoces'
Comp '7e. el nivel de altavoces sale del campo que ya escribe el worker' ($cuerpoNA -match '\$st\[2\]') 'tercer campo de escucha-estado.txt'
Comp '7f. y solo si el estado esta fresco' ($cuerpoNA -match 'Test-EstadoFresco') 'el del worker anterior no dice nada de ahora'
$cuerpoT = ((@($defs | Where-Object { $_.Name -eq 'Test-ApagarPantalla' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7g. Test-ApagarPantalla es pura' (-not ($cuerpoT -match '(Get-Date|Test-Path|powercfg|Get-CimInstance|Log |SendMessage|\$sw\.)')) 'por eso se le pueden correr veinte casos'
Comp '7h. y no apaga nada ella misma' (-not ($cuerpoT -match 'Set-PantallaApagada')) 'decide y devuelve; apagar es de otro'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova ya sabe que su pantalla no se apaga nunca, y puede apagarla el dia que se lo digan' -ForegroundColor Green
exit 0
