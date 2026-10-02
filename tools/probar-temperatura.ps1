# LA TEMPERATURA DEL CHIP, QUE ES LA QUE EXPLICA EL RUIDO DEL VENTILADOR (27/09, idea 103)
#
# EL PROBLEMA: Nova dice "hay un ruido de fondo constante, si puedes quitalo" SIN SABER si el ruido
# es suyo. Lo ha dicho 36 veces en 17 dias, mas 1.649 aparcadas por no haber nadie. Si el zumbido es
# su propio ventilador, mandarle a buscar algo que no existe es hacerle perder el tiempo. Y no lo
# habia mirado nunca: cero apariciones de ThermalZone o temperatura en las 32.900 lineas.
#
# LO QUE HAY EN ESTA MAQUINA, medido: \_TZ.THRM con Temperature = 329 (KELVIN ENTEROS, resolucion de
# un grado) = 55,9 C, ThrottleReasons = 0, PercentPassiveLimit = 100. MSAcpi_ThermalZoneTemperature
# no devuelve nada aqui, y AsusHWMonitorWMI / AsusAtkWmi_WMNB existen con CERO instancias.
#
# LO QUE CUESTA, corrigiendo a la ficha (1.625 ms) Y a su verificador (37 ms): medido dos veces, en
# un sistema ocupado la PRIMERA costo 9.331 ms y en uno tranquilo 30 ms; las siguientes, 24-38 ms
# siempre. La primera puede ser carisima y no hay forma de saberlo de antemano, asi que se cronometra
# y se apaga sola. La sonda de CPU por Get-Counter cuesta 480 ms: esto en caliente es quince veces
# mas barato que lo que ya se usa.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que "caliente" NO sea un numero inventado, sino que ella misma se frene
#   2. que un kelvin sin sentido no se convierta en un grado con sentido
#   3. que si la sonda es lenta o no existe, se apague sola y NADA cambie
#   4. y que el aviso de ruido sin dato sea exactamente el de antes
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
foreach ($f in @('Get-Temperatura', 'Test-CalienteDeVerdad')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$mT = [regex]::Match($txt, "(?m)^\`$TempTopeMs = \[int\]\(Get-Cfg 'ui' 'tempTopeMs' (\d+)\)")
Comp 'el tope de la sonda sale del archivo' $mT.Success ($mT.Groups[1].Value + ' ms')
$TempTopeMs = if ($mT.Success) { [int]$mT.Groups[1].Value } else { 400 }

Write-Host ''
Write-Host '-- 1. CALIENTE NO ES UN NUMERO ESCRITO A OJO --'
Comp '1a. a 55 grados y sin frenarse, NO esta caliente' (-not (Test-CalienteDeVerdad @{ c = 55; throttle = 0; pasivo = 100 })) 'los grados solos no dicen nada: la zona puede ser el chasis'
Comp '1b. ni a 84' (-not (Test-CalienteDeVerdad @{ c = 84; throttle = 0; pasivo = 100 })) 'si no se frena, 84 es su temperatura normal de trabajo'
Comp '1c. pero si SE FRENA, si' (Test-CalienteDeVerdad @{ c = 84; throttle = 4; pasivo = 100 }) 'ThrottleReasons lo dice el sistema, no yo'
Comp '1d. o si baja el limite pasivo' (Test-CalienteDeVerdad @{ c = 70; throttle = 0; pasivo = 80 }) ''
Comp '1e. frenandose a 55 grados tambien' (Test-CalienteDeVerdad @{ c = 55; throttle = 1; pasivo = 100 }) 'el numero no manda: manda que se frene'
Comp '1f. y sin dato, no se afirma nada' (-not (Test-CalienteDeVerdad $null)) ''

Write-Host ''
Write-Host '-- 2. LA SONDA, CONTRA LA MAQUINA DE VERDAD --'
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { }
$sw = [Diagnostics.Stopwatch]::StartNew()
# EL RECUERDO DE LA SONDA (2/10, idea 10): Get-Temperatura consulta si la apago hace poco antes de
# pagar la primera lectura, que puede costar 9.331 ms (medido, esta en su comentario). Se dobla con
# interruptor para poder probar las dos ramas sin tocar el disco de braya.
$AcelOlvidoDias = 7
$script:sondaApagadaDias = -1
$script:sondasGuardadas = @()
function Get-SondaApagadaDias([string]$n, [datetime]$a = (Get-Date)) { return $script:sondaApagadaDias }
function Save-Sonda([string]$n, [string]$c) { $script:sondasGuardadas += "$n|$c" }
$script:tempSonda = ''
$script:tempUltima = $null
$script:tempLeidas = 0
# se hace un Get-CimInstance antes, como hace Nova (llama a Win32_Battery cada minuto): eso es lo
# que abarata la primera lectura termica, y medirlo sin eso serian nueve segundos.
$null = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
# Y SE MIDE LA SEGUNDA, que es la que el codigo juzga: la primera paga la carga del contador de
# rendimiento. En este banco la primera costo 1.192 ms y la sonda se apagaba sola para siempre.
$null = Get-Temperatura
$t1 = [Diagnostics.Stopwatch]::StartNew()
$t = Get-Temperatura
$msT = $t1.ElapsedMilliseconds
if ($null -eq $t) {
    Write-Host ('  --   esta maquina no da zona termica; se salta lo que depende de ella (' + ($script:logs -join ' / ') + ')')
    Comp '2a. y se apaga sola, sin reventar' ($script:tempSonda -eq 'no') ([string]$script:tempSonda)
    Comp '2b. diciendolo en el registro' (@($script:logs | Where-Object { $_ -match 'temperatura' }).Count -ge 1) ''
} else {
    Comp '2a. da un grado con sentido' ([int]$t.c -gt 0 -and [int]$t.c -lt 120) ([string]$t.c + ' grados en ' + [string]$t.zona)
    Comp '2b. y en caliente cuesta poco' ($msT -lt 2000) ([string]$msT + ' ms la primera; la sonda de CPU cuesta 480')
    $t2 = [Diagnostics.Stopwatch]::StartNew(); $null = Get-Temperatura; $ms2 = $t2.ElapsedMilliseconds
    Comp '2c. y la segunda, menos' ($ms2 -le [Math]::Max(100, $msT)) ([string]$ms2 + ' ms')
    Comp '2d. la sonda queda encendida' ($script:tempSonda -eq 'si') ([string]$script:tempSonda)
    Comp '2e. y lo dice una vez, con el coste' (@($script:logs | Where-Object { $_ -match 'zona termica' }).Count -eq 1) ($script:logs -join ' / ')
    Comp '2f. trae el freno y el limite pasivo' ($t.ContainsKey('throttle') -and $t.ContainsKey('pasivo')) ('throttle=' + [string]$t.throttle + ' pasivo=' + [string]$t.pasivo)
    Comp '2g. y hoy esta maquina no se esta frenando' (-not (Test-CalienteDeVerdad $t)) 'lo normal: por eso el aviso de ruido no cambia hoy'
}

Write-Host ''
Write-Host '-- 3. UN KELVIN SIN SENTIDO NO SE CONVIERTE EN UN GRADO CON SENTIDO --'
# se dobla el Get-CimInstance para poder darle valores imposibles
$script:zonasFalsas = @()
function Get-CimInstance { param([string]$ClassName, $ErrorAction) return $script:zonasFalsas }
function Reset { $script:tempSonda = ''; $script:tempUltima = $null; $script:logs = @(); $script:tempLeidas = 0 }
Reset
$script:zonasFalsas = @([pscustomobject]@{ Name = '\_TZ.X'; Temperature = 0; ThrottleReasons = 0; PercentPassiveLimit = 100 })
Comp '3a. cero kelvin (el contador sin datos) no vale' ($null -eq (Get-Temperatura)) '0 K serian -273 grados'
Comp '3b. y se apaga, no lo repite cada minuto' ($script:tempSonda -eq 'no') ''
Reset
$script:zonasFalsas = @([pscustomobject]@{ Name = '\_TZ.X'; Temperature = 500; ThrottleReasons = 0; PercentPassiveLimit = 100 })
Comp '3c. 500 K (227 grados) tampoco' ($null -eq (Get-Temperatura)) ''
Reset
$script:zonasFalsas = @()
Comp '3d. sin ninguna zona, nada' ($null -eq (Get-Temperatura)) ''
Comp '3e. y no vuelve a mirar' ($script:tempSonda -eq 'no') 'una clase que no existe no aparece de repente'
Reset
$script:zonasFalsas = @([pscustomobject]@{ Name = '\_TZ.A'; Temperature = 320; ThrottleReasons = 0; PercentPassiveLimit = 100 },
                        [pscustomobject]@{ Name = '\_TZ.B'; Temperature = 350; ThrottleReasons = 2; PercentPassiveLimit = 90 })
$tm = Get-Temperatura
# 350 K - 273,15 = 76,85, y [int] en PowerShell REDONDEA, no trunca: son 77. (Escribi 76 y el banco
# me corrigio; 77 es el numero mas cercano, asi que el codigo esta bien y la cuenta era mia.)
Comp '3f. con varias zonas, gana la MAS CALIENTE' ($null -ne $tm -and [int]$tm.c -eq 77) ([string]$tm.c + ' grados, de ' + [string]$tm.zona)
Comp '3g. y trae SU freno, no el de la otra' ([int]$tm.throttle -eq 2 -and [int]$tm.pasivo -eq 90) 'la que se frena es la que explica el ventilador'
Comp '3h. asi que esa SI esta caliente' (Test-CalienteDeVerdad $tm) ''
# una mezcla de zona valida e imposible
Reset
$script:zonasFalsas = @([pscustomobject]@{ Name = '\_TZ.ROTA'; Temperature = 999; ThrottleReasons = 0; PercentPassiveLimit = 100 },
                        [pscustomobject]@{ Name = '\_TZ.BUENA'; Temperature = 330; ThrottleReasons = 0; PercentPassiveLimit = 100 })
$tm2 = Get-Temperatura
Comp '3i. una zona rota no tira la buena' ($null -ne $tm2 -and [string]$tm2.zona -eq '\_TZ.BUENA') ([string]$tm2.zona)

Write-Host ''
Write-Host '-- 4. SI ES LENTA, SE APAGA SOLA (el criterio del acelerometro y de la carga) --'
Reset
function Get-CimInstance { param([string]$ClassName, $ErrorAction) Start-Sleep -Milliseconds ($TempTopeMs + 250); return @([pscustomobject]@{ Name = '\_TZ.X'; Temperature = 330; ThrottleReasons = 0; PercentPassiveLimit = 100 }) }
# LA PRIMERA SE PERDONA: paga la carga del contador. La que decide es la segunda.
$primera = Get-Temperatura
Comp '4a bis. la primera lenta SI da dato' ($null -ne $primera) 'si se juzgara, se perderia una fuente que luego cuesta 30 ms'
Comp '4a. y la segunda, lenta tambien, devuelve nada' ($null -eq (Get-Temperatura)) ([string]$TempTopeMs + ' ms de tope')
Comp '4b. y se apaga para siempre' ($script:tempSonda -eq 'no') ''
Comp '4c. diciendo lo que costaba' (@($script:logs | Where-Object { $_ -match 'la apago' }).Count -eq 1) ($script:logs -join ' / ')
Comp '4d. y no se vuelve a llamar' ($null -eq (Get-Temperatura)) 'el segundo intento sale por el return de arriba, sin dormir'

Write-Host ''
Write-Host '-- 5. EL AVISO DE RUIDO SIN DATO ES EL DE ANTES --'
Comp '5a. las cuatro frases de siempre siguen ahi' ($sinCom -match 'Hay un ruido de fondo constante y asi no te voy a oir bien') ''
Comp '5b. y no dependen de la sonda' ($sinCom -match '(?s)\$frasesRuido = @\(\s*\r?\n?\s*''Hay un ruido de fondo constante') 'se montan antes de preguntar por la temperatura'
Comp '5c. las otras solo salen si se esta frenando' ($sinCom -match 'if \(Test-CalienteDeVerdad \$tRuido\) \{') ''
Comp '5d. y se dicen como "mi zona termica marca X"' ($sinCom -match 'mi zona termica marca') 'no como si fuera el chip: puede ser el chasis'
Comp '5e. con el numero dentro' ($sinCom -match "\+ \[int\]\`$tRuido\.c \+ ' grados") ''
Comp '5f. el fallo de la sonda no rompe el aviso' ($sinCom -match 'try \{ \$tRuido = Get-Temperatura \} catch \{ \$tRuido = \$null \}') ''

Write-Host ''
Write-Host '-- 6. LA SERIE, DONDE YA SE PAGA UN Get-CimInstance --'
Comp '6a. se apunta en el fichero del latido' ($sinCom -match "\[temperatura\] ' \+ \[int\]\`$tP\.c") 'no en el registro: el registro acaba de adelgazar'
Comp '6b. solo cuando cambia el grado' ($sinCom -match '\[int\]\$tP\.c -ne \[int\]\$script:tempApuntada') 'kelvin enteros: son pocas lineas por hora'
Comp '6c. y va en el bloque de la bateria' ($sinCom -match "(?s)\[bateria\] ' \+ \`$pc.{0,2000}\[temperatura\] '") 'ahi ya se paga un Get-CimInstance, que es lo que abarata esto'
Comp '6d. diciendo si se estaba frenando' ($sinCom -match 'FRENANDO \(') ''
Comp '6e. y a que jugaba' ($sinCom -match "(?s)\[temperatura\].{0,400}jugando a ' \+ \`$script:juegoActivo") 'para poder cruzar calor con juego'

Write-Host ''
Write-Host '-- 9. SI SE APAGO HACE POCO, NI SE INTENTA (2/10, idea 10) --'
# Esta sonda se apaga sola cuando tarda -en estadisticas.json esta "auto-ajuste = sonda de
# temperatura off: 1548 ms de 400"-, pero eso era un CONTADOR y no un recuerdo: el arranque
# siguiente volvia a pagar la primera lectura, que puede costar 9.331 ms medidos.
Reset
# EL CONTADOR DE VERDAD: el banco no llevaba ninguno, asi que "NI TOCA el CIM" salia verde
# comparando una variable que nadie incrementaba. Se dobla aqui, contando.
function Get-CimInstance { param([string]$ClassName, $ErrorAction) $script:cimLlamadas++; return @([pscustomobject]@{ Name = '\_TZ.X'; Temperature = 320; ThrottleReasons = 0; PercentPassiveLimit = 100 }) }
$script:sondaApagadaDias = 2
$script:cimLlamadas = 0
$r = Get-Temperatura
Comp '9a. con el recuerdo puesto, no devuelve nada' ($null -eq $r) ''
Comp '9b.   y NI TOCA el CIM caro' ($script:cimLlamadas -eq 0) "llamadas=$($script:cimLlamadas)"
Comp '9c.   y lo dice una vez, con los dias' (@($script:logs | Where-Object { $_ -match 'la apague hace 2 dia' }).Count -eq 1) ($script:logs -join ' | ')
# Y NO LO REPITE EN CADA VUELTA: la sonda queda en 'no' y las siguientes salen por el primer if
$antes = $script:logs.Count
[void](Get-Temperatura); [void](Get-Temperatura)
Comp '9d.   y no lo repite cada vuelta' ($script:logs.Count -eq $antes) "$($script:logs.Count - $antes) lineas nuevas"
# Y SIN RECUERDO, SE PRUEBA COMO SIEMPRE: sin esto el respaldo taparia la sonda para siempre
Reset
$script:sondaApagadaDias = -1
$script:cimLlamadas = 0
[void](Get-Temperatura)
Comp '9e. sin recuerdo, SI mira el sensor' ($script:cimLlamadas -ge 1) "llamadas=$($script:cimLlamadas)"

Write-Host ''
Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova sabe si el zumbido es su propio ventilador' -ForegroundColor Green
exit 0
