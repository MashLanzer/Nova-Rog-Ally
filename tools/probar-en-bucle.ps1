# LA MISMA QUEJA VEINTISIETE VECES Y NADIE LA OYE (27/09, idea 76 de las 121)
#
# EL DATO: la madrugada del 26/09, 61 lineas identicas de 'charla: diario: no pude resumir lo del
# 2026-09-25 ([WinError 10061]...)' entre las 00:07:45 y la 01:13:07, una cada 65 segundos, y seguian
# saliendo mientras se contaban. Y la linea mas repetida de los dos registros es 'RESUMEN AL VOLVER:
# Mientras no estabas: 1 mensaje de XBOX Game Bar Widgets', 774 veces IDENTICA.
#
# Ese caso concreto ya lo arreglo la idea 14 (ollama_vivo dobla la espera hasta un techo). Esto es el
# detector GENERAL, en Log, que es el embudo por el que pasa todo lo que Nova hace.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que Log NO llame a nada (una llamada que escriba, dentro de Log, es recursion infinita)
#   2. que la tabla no crezca sin fin: 58.000 lineas distintas no pueden ser 58.000 entradas
#   3. que se avise UNA vez por duplicacion (10, 20, 40...), no cuatrocientas veces
#   4. que pasada la ventana la cuenta empiece de cero: un fallo de ayer no es un bucle de hoy
#   5. que dos lineas iguales con numeros distintos cuenten como la MISMA (por eso es un bucle)
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
foreach ($f in @('Get-LogClave', 'Add-LogRepe', 'Get-LogRepetido', 'Test-LogEnBucle', 'Get-LogRepePeor')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
$LogRepeTabla = 200
$LogRepeVentanaMs = 1800000
$LogRepeListon = 10
Comp 'los tres numeros salen del archivo' (($txt -match '\$LogRepeTabla = 200') -and ($txt -match '\$LogRepeVentanaMs = 1800000') -and ($txt -match '\$LogRepeListon = 10')) ''
$script:msFalsos = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:msFalsos }
function Reset {
    $script:logRepe = @{}
    $script:logRepeAvisos = New-Object System.Collections.ArrayList
    $script:msFalsos = 0
}

Write-Host ''
Write-Host '-- 1. LA LINEA CON NUMEROS DISTINTOS ES LA MISMA LINEA --'
Comp '1a. los numeros se vuelven N' ((Get-LogClave 'no pude resumir lo del 2026-09-25 (10061)') -eq (Get-LogClave 'no pude resumir lo del 2026-09-26 (10061)')) (Get-LogClave 'no pude resumir lo del 2026-09-25 (10061)')
Comp '1b. y dos quejas distintas no se mezclan' ((Get-LogClave 'no pude resumir') -ne (Get-LogClave 'no pude guardar')) ''
Comp '1c. una linea larguisima se recorta' ((Get-LogClave ('x' * 400)).Length -le 160) ([string](Get-LogClave ('x' * 400)).Length + ' letras')

Write-Host ''
Write-Host '-- 2. EL BUCLE DEL 26/09, TAL CUAL --'
Reset
# 61 lineas, una cada 65 s, con la fecha y el codigo de error dentro
for ($i = 1; $i -le 61; $i++) {
    $script:msFalsos = $i * 65000
    Add-LogRepe ("charla: diario: no pude resumir lo del 2026-09-25 ([WinError 10061] no hay nadie escuchando, intento $i)") $script:msFalsos
}
# EL PEOR SE MIRA DURANTE LA RACHA: al final de las 61 lineas la ventana se acaba de reiniciar y la
# cuenta vale poco, que es exactamente lo que tiene que pasar (una racha de hace una hora no es un
# bucle de ahora). Asi que se rehace la racha y se mira a la mitad.
Reset
for ($i = 1; $i -le 20; $i++) {
    $script:msFalsos = $i * 65000
    Add-LogRepe ("charla: diario: no pude resumir lo del 2026-09-25 ([WinError 10061] intento $i)") $script:msFalsos
}
$peor = Get-LogRepePeor
Comp '2a. se ve como UNA linea repetida' ($null -ne $peor) $(if ($peor) { $peor.clave.Substring(0, 40) })
Comp '2b. con sus veces y sus minutos' ($peor.veces -eq 20 -and $peor.minutos -ge 20) ([string]$peor.veces + ' veces en ' + [string]$peor.minutos + ' min')
Comp '2c. y pasa del liston' ($peor.veces -ge $LogRepeListon) ([string]$peor.veces + ' >= ' + [string]$LogRepeListon)
# y ahora si, las 61 de aquella noche: la ventana las parte y la cuenta se reinicia sola
Reset
for ($i = 1; $i -le 61; $i++) {
    $script:msFalsos = $i * 65000
    Add-LogRepe ("charla: diario: no pude resumir lo del 2026-09-25 ([WinError 10061] intento $i)") $script:msFalsos
}
$avisos = @(Get-LogRepetido)
Comp '2d. y deja notas, no una por linea' ($avisos.Count -ge 1 -and $avisos.Count -le 8) ([string]$avisos.Count + ' notas para 61 lineas')
Comp '2e. cada nota dice cuantas y en cuantos minutos' ($avisos[0].veces -ge 10 -and $avisos[0].minutos -ge 1) ([string]$avisos[0].veces + ' veces en ' + [string]$avisos[0].minutos + ' min')
Comp '2f. y al recogerlas, se vacian' (@(Get-LogRepetido).Count -eq 0) 'si no, se diria lo mismo cada minuto'

Write-Host ''
Write-Host '-- 3. UNA VEZ POR DUPLICACION, NO CUATROCIENTAS --'
Reset
for ($i = 1; $i -le 100; $i++) { $script:msFalsos = $i * 1000; Add-LogRepe 'algo que falla' $script:msFalsos }
$av3 = @(Get-LogRepetido)
Comp '3a. cien lineas iguales dejan pocas notas' ($av3.Count -le 5) ([string]$av3.Count + ' notas: ' + (@($av3 | ForEach-Object { $_.veces }) -join ', '))
Comp '3b. y las notas van doblando' (($av3.Count -ge 3) -and ($av3[1].veces -ge $av3[0].veces * 2)) (@($av3 | ForEach-Object { $_.veces }) -join ' -> ')

Write-Host ''
Write-Host '-- 4. LO QUE PASA UNA VEZ NO ES UN BUCLE --'
Reset
Add-LogRepe 'esto pasa una vez' 1000
Comp '4a. una sola linea no deja nota' (@(Get-LogRepetido).Count -eq 0) ''
Comp '4b. ni sale como bucle' (-not (Test-LogEnBucle 'esto pasa una vez')) ''
# ojo: en 4a ya se conto UNA, asi que ocho mas son nueve
for ($i = 1; $i -le 8; $i++) { $script:msFalsos = 1000 + $i * 100; Add-LogRepe 'esto pasa una vez' $script:msFalsos }
Comp '4c. con nueve tampoco (el liston son 10)' (-not (Test-LogEnBucle 'esto pasa una vez')) '9 veces'
$script:msFalsos = 2100
Add-LogRepe 'esto pasa una vez' $script:msFalsos
Comp '4d. con diez, si' (Test-LogEnBucle 'esto pasa una vez') 'y quien reintente puede doblar su espera'

Write-Host ''
Write-Host '-- 5. LA VENTANA: UN FALLO DE HACE HORAS NO CUENTA --'
Reset
for ($i = 1; $i -le 12; $i++) { $script:msFalsos = $i * 1000; Add-LogRepe 'fallo viejo' $script:msFalsos }
Comp '5a. doce seguidas: esta en bucle' (Test-LogEnBucle 'fallo viejo') ''
$script:msFalsos = 12000 + $LogRepeVentanaMs + 1000
Comp '5b. media hora despues, ya no' (-not (Test-LogEnBucle 'fallo viejo')) 'lo de hace horas no es un bucle de ahora'
Add-LogRepe 'fallo viejo' $script:msFalsos
$e5 = $script:logRepe[(Get-LogClave 'fallo viejo')]
Comp '5c. y la cuenta empieza de cero' ($e5.veces -eq 1) ([string]$e5.veces)

Write-Host ''
Write-Host '-- 6. LA TABLA NO CRECE SIN FIN --'
Reset
# SIN NUMEROS EN EL TEXTO: con numeros, las 350 caerian en la MISMA clave (se vuelven N) y este caso
# no probaria el tope, que fue lo que paso al escribirlo. Se usan letras distintas.
$letras = 'abcdefghijklmnopqrstuvwxyz'
$hechas = 0
foreach ($a in $letras.ToCharArray()) {
    foreach ($b in $letras.ToCharArray()) {
        if ($hechas -ge ($LogRepeTabla + 150)) { break }
        $hechas++
        $script:msFalsos = $hechas
        Add-LogRepe ("queja unica " + $a + $b + " que no se repite jamas") $script:msFalsos
    }
    if ($hechas -ge ($LogRepeTabla + 150)) { break }
}
Comp '6a. con 350 lineas distintas de verdad, la tabla se queda en su tope' ($script:logRepe.Count -le $LogRepeTabla -and $script:logRepe.Count -gt 1) ([string]$script:logRepe.Count + ' de ' + [string]$LogRepeTabla + ' (se metieron ' + [string]$hechas + ')')
Comp '6b. y las notas tampoco crecen' ($script:logRepeAvisos.Count -le 20) ([string]$script:logRepeAvisos.Count)

Write-Host ''
Write-Host '-- 7. LO QUE IMPORTA: Log NO LLAMA A NADA (recursion) --'
$log = Traer 'Log'
Comp '7a. Log llama a Add-LogRepe' ($log -match 'Add-LogRepe \$msg \$sw\.ElapsedMilliseconds') ''
Comp '7b. y dentro de su propio try' ($log -match 'try \{ Add-LogRepe .* \} catch \{\}') 'contar no puede tumbar una linea de registro'
$addr = Traer 'Add-LogRepe'
foreach ($peligrosa in @('Add-Estadistica', 'Send-AvisoEntorno', 'Log ', 'Say ', 'Set-UI')) {
    Comp ('7c. Add-LogRepe no llama a ' + $peligrosa.Trim()) (-not ($addr -match [regex]::Escape($peligrosa))) 'cualquiera de estas puede escribir y volver a Log'
}
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7d. quien cuenta y avisa es el bucle, una vez por minuto' ($sinCom -match 'foreach \(\$rp in @\(Get-LogRepetido\)\)') ''
Comp '7e. y solo habla de lo gordo (cuatro veces el liston)' ($sinCom -match '\[int\]\$rp\.veces -ge \(\$LogRepeListon \* 4\)') ''

Write-Host ''
Write-Host '-- 8. EL MEDIDOR DEL PULSO NO PUEDE ALIMENTAR ESTA TABLA (1/10) --'
# EL CASO, y costo doce segundos por vuelta: las lineas 'SORDA' se citaban a si mismas -el
# "haciendo QUE" era la linea SORDA anterior-, asi que CADA UNA era distinta de todas las demas y
# creaba una CLAVE NUEVA aqui. Con la tabla llena, cada clave nueva dispara un Sort-Object de la
# tabla ENTERA, y eso pasa dentro de Log, que es el embudo de todo. Medido: 430 lineas SORDA con una
# peor de 18,18 s; con el filtro puesto, SIETE lineas y 1,71 s.
# SE COMPRUEBA EN Log, que es donde esta el filtro, y con el texto de verdad del archivo: si alguien
# lo quita, esto se pone rojo antes de que Nova vuelva a quedarse sorda doce segundos.
# EL 2/10 EL FILTRO GANO 'EN BUCLE:', que es justo la linea del medidor que mas se repetia: 94
# lineas del 2/10 del tipo "SORDA (...): EN BUCLE: llevo 10 veces lo mismo en 9 min: ...". Se
# comprueban las TRES claves por separado en vez de casar el regex entero con un literal, para que
# anadir una cuarta manana no vuelva a poner este banco rojo con el codigo perfecto.
foreach ($clave in @('SORDA', 'LENTA:', 'EN BUCLE:')) {
    Comp ("8a. Log no guarda '" + $clave + "' como ultimo") ($log -match ("notmatch '\^\(\?:[^']*" + [regex]::Escape($clave))) 'si las guarda, se citan a si mismas'
}
# Y QUE EL FILTRO DE VERDAD FILTRE, no solo que este escrito. Log entera arrastra media casa
# -secretos, disco, Add-LogRepe-, asi que se saca SU condicion del archivo y se ejecuta esa: si
# manana alguien cambia el regex, estos tres casos lo dicen.
$mFil = [regex]::Match($log, "-notmatch\s+'(\^\(\?:[^']+)'")
Comp '8b. se puede sacar su condicion del archivo' ($mFil.Success) ''
if ($mFil.Success) {
    $reFil = $mFil.Groups[1].Value
    # el filtro guarda la linea solo si NO casa con ese patron: eso es lo que se prueba
    $guarda = { param($m) return ($m -and $m -notmatch $reFil) }
    Comp '8c.   una linea normal SI se guarda' (& $guarda 'JUEGO: abierto Elden Ring') ''
    Comp '8d.   una SORDA no' (-not (& $guarda 'SORDA 12.22 s en una vuelta (lo normal en mi son 62 ms): JUEGO: abierto')) ''
    Comp '8e.   una LENTA tampoco' (-not (& $guarda 'LENTA: la vuelta mediana son 600 ms y el bucle solo duerme 30')) ''
    # Y NO SE PASA DE LISTO: una linea que solo MENCIONE la palabra si se guarda, porque el filtro
    # esta anclado al principio. Si no, se perderia el "haciendo que" de cualquier linea que hable
    # del medidor.
    Comp '8f.   pero una que solo la menciona, si' (& $guarda 'el banco de SORDA dice que todo va bien') 'el filtro esta anclado al principio'
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'lo que se repite en bucle se cuenta y se dice' -ForegroundColor Green
exit 0
