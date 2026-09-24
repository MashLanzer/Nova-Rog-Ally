# Pruebas de dos cosas que Nova hace sola sin molestar:
#  - NOTIFICACIONES: que cuente solo las nuevas, que jugando solo lata el borde,
#    y que el resumen y la lectura digan lo que tienen que decir.
#  - HABITOS: que proponga automatizar una costumbre de verdad (misma orden a la
#    misma hora, o justo despues de abrir una app, tres dias distintos), y que
#    no insista: una al dia, un "no" veta 60 dias y un "si" para siempre.
# Trabaja en una carpeta temporal propia y la borra al acabar.
#
#   powershell -NoProfile -File tools\probar-costumbres.ps1
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn($n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta la funcion $n en assistant.ps1" }
    return $f.Extent.Text
}
foreach ($n in 'ConvertTo-Plain', 'Watch-Notificaciones', 'Get-ResumenNotificaciones', 'Get-LecturaNotificaciones', 'Get-Contactos', 'Save-Contactos',
    'Get-Habitos', 'Save-Habitos', 'Add-Habito', 'Find-Propuesta', 'Test-ParteManana',
    'Add-RitmoSeguimiento', 'Get-VentanaSeguimiento', 'Add-CharlaHora', 'Test-PrecargaCharla', 'Write-Atomico',
    # Test-ApiContestaPrimero (19/09, af8961a): Test-PrecargaCharla la llama en su primera
    # linea. Sin traerla aqui, esta prueba corria con una funcion que NO existe: PowerShell
    # escupia CommandNotFoundException, la condicion valia $false y los casos pasaban igual,
    # o sea que se estaba probando media funcion sin enterarse.
    'Test-ApiContestaPrimero',
    'Test-PropuestaVetada', 'Add-PropuestaTratada') { Invoke-Expression (TraerFn $n) }
# Test-PropuestaVetada usa esta variable del script. Sin ella valdria $null y el veto
# dejaria de aplicarse EN SILENCIO, que es peor que fallar (17/09).
$txtCost = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
if ($txtCost -match '(?m)^[$]PropuestaVetoDias = ([0-9]+)') { $PropuestaVetoDias = [int]$Matches[1] }
else { throw 'falta $PropuestaVetoDias en assistant.ps1' }
$script:invitado = $false

$MemoriaDir = Join-Path $env:TEMP ('nova-costumbres-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $MemoriaDir | Out-Null
$script:eventos = @()
function Log($m) {}
function Send-UIEvento($e) { $script:eventos += $e }
function Set-UI {}
function Test-AvisoSinVoz { return $false }
function Send-Aviso {}
$script:reglasFalsas = New-Object System.Collections.ArrayList
function Get-Reglas { return ,$script:reglasFalsas }
$mal = 0
function Comp($etq, $ok, $det = '') {
    if (-not $ok) { $script:mal++ }
    "  {0}  {1}{2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $etq, $(if ("$det" -ne '') { "  -> $det" } else { '' })
}
function Notif($id, $app, $titulo, $texto) { return @{ id = [string]$id; app = $app; titulo = $titulo; texto = $texto } }

Write-Host "--- notificaciones ---"
$script:notifVistas = @{}; $script:notifPendientes = New-Object System.Collections.ArrayList; $script:notifPrimera = $true
$script:juegoActivo = $null
$ya = @((Notif 1 'Discord' 'Ana' 'hola'))
Comp 'lo que ya habia al arrancar no cuenta como nuevo' ((Watch-Notificaciones $ya) -eq 0 -and $script:notifPendientes.Count -eq 0)
Comp 'sin nada nuevo, lo dice' ((Get-ResumenNotificaciones) -match '^nada nuevo')
$script:juegoActivo = 'Hades'
$dos = $ya + @((Notif 2 'Discord' 'Ana' 'vienes?'), (Notif 3 'WhatsApp' 'Mama' 'la cena'))
Comp 'jugando: cuenta las dos nuevas' ((Watch-Notificaciones $dos) -eq 2 -and $script:notifPendientes.Count -eq 2)
Comp 'y solo late el borde (pulso), nada mas' ($script:eventos.Count -eq 1 -and $script:eventos[0] -eq 'pulso:mensaje') ($script:eventos -join ',')
Comp 'la misma lista otra vez no las repite' ((Watch-Notificaciones $dos) -eq 0 -and $script:notifPendientes.Count -eq 2)
$script:juegoActivo = $null
[void](Watch-Notificaciones ($dos + @((Notif 4 'Discord' 'Leo' 'gg'))))
Comp 'fuera del juego se apunta pero no late' ($script:notifPendientes.Count -eq 3 -and $script:eventos.Count -eq 1)
$res = Get-ResumenNotificaciones
Comp 'resumen: cuantas y de quien, la app con mas primero' ($res -eq 'tienes 3: 2 de Discord y 1 de WhatsApp. Di leemelos si quieres oirlos') $res
$lee = Get-LecturaNotificaciones
Comp 'lectura: app, remitente y texto' ($lee -eq 'Discord, Ana: vienes?. WhatsApp, Mama: la cena. Discord, Leo: gg') $lee
Comp 'leidas, se vacian' ($script:notifPendientes.Count -eq 0 -and (Get-LecturaNotificaciones) -match '^no tengo')

Write-Host "--- habitos: la misma orden a la misma hora ---"
$script:habitos = $null
$hoy = Get-Date '2026-09-20 10:00'
Add-Habito 'que hora es' (Get-Date '2026-09-17 21:00')
Comp 'una pregunta no es una costumbre' ((Get-Habitos).usos.Count -eq 0)
Add-Habito 'Pon modo noche' (Get-Date '2026-09-17 21:05')
Add-Habito 'pon modo noche' (Get-Date '2026-09-18 21:20')
Comp 'dos dias no bastan' ($null -eq (Find-Propuesta $hoy))
Add-Habito 'pon modo noche' (Get-Date '2026-09-18 21:25')
Comp 'dos veces el mismo dia cuentan como un dia' ($null -eq (Find-Propuesta $hoy))
Add-Habito 'pon modo noche' (Get-Date '2026-09-19 20:55')
$pr = Find-Propuesta $hoy
Comp 'tres dias a la misma hora: la propone' ($pr -and $pr.tipo -eq 'hora' -and $pr.accion -eq 'pon modo noche') $pr.clave
Comp 'a la hora del medio, redondeada a 5 min' ($pr.valor -eq '21:05') $pr.valor
$script:habitos = $null
Comp 'sobrevive a releer el archivo' ($null -ne (Find-Propuesta $hoy) -and (Get-Habitos).usos.Count -eq 4)
Comp 'lo de hace mas de una semana no cuenta' ($null -eq (Find-Propuesta (Get-Date '2026-09-30 10:00')))
(Get-Habitos).ultimaPropuesta = '2026-09-20'
Comp 'una al dia como mucho' ($null -eq (Find-Propuesta $hoy))
(Get-Habitos).ultimaPropuesta = ''
# FORMATO VIEJO (texto suelto, sin fecha): se respeta como permanente, porque no se puede
# saber si fue un si o un no y equivocarse hacia el lado de no molestar es lo correcto
[void](Get-Habitos).rechazadas.Add('hora|pon modo noche')
Comp 'lo vetado con el formato viejo sigue vetado' ($null -eq (Find-Propuesta $hoy))
(Get-Habitos).rechazadas.Clear()
# UN "NO" YA NO ES PARA SIEMPRE (17/09): veta ahora y caduca a los $PropuestaVetoDias dias.
# Se comprueba sobre Test-PropuestaVetada y no sobre Find-Propuesta, porque con una fecha
# 61 dias mas tarde los usos ya no entrarian en la ventana de una semana y el caso no
# probaria lo que dice probar.
Add-PropuestaTratada (Get-Habitos) 'hora|pon modo noche' $false $hoy
Comp 'un no reciente si veta' ($null -eq (Find-Propuesta $hoy))
Comp 'y sigue vetando a los 30 dias' (Test-PropuestaVetada (Get-Habitos) 'hora|pon modo noche' $hoy.AddDays(30))
Comp 'pero caduca y se vuelve a ofrecer' (-not (Test-PropuestaVetada (Get-Habitos) 'hora|pon modo noche' $hoy.AddDays($PropuestaVetoDias + 1)))
# y lo ACEPTADO no caduca nunca: la regla ya existe
Add-PropuestaTratada (Get-Habitos) 'hora|pon modo noche' $true $hoy
Comp 'lo aceptado no caduca jamas' (Test-PropuestaVetada (Get-Habitos) 'hora|pon modo noche' $hoy.AddDays(3650))
(Get-Habitos).rechazadas.Clear()
[void]$script:reglasFalsas.Add(@{ id = 1; tipo = 'hora'; valor = '21:00'; accion = 'pon modo noche' })
Comp 'si ya hay una regla asi, no la propone' ($null -eq (Find-Propuesta $hoy))
$script:reglasFalsas.Clear()

Write-Host "--- habitos: justo despues de abrir una app ---"
$script:habitos = $null; Remove-Item (Join-Path $MemoriaDir 'habitos.json') -ErrorAction SilentlyContinue
foreach ($d in '2026-09-15', '2026-09-16') {
    Add-Habito 'abre steam' (Get-Date "$d 18:00"); Add-Habito 'baja el volumen al 30' (Get-Date "$d 18:02")
}
Add-Habito 'abre steam' (Get-Date '2026-09-18 12:00'); Add-Habito 'baja el volumen al 30' (Get-Date '2026-09-18 12:10')
Comp 'a los 10 min ya no cuenta como "justo despues"' ($null -eq (Find-Propuesta $hoy))
Add-Habito 'abre steam' (Get-Date '2026-09-19 23:00'); Add-Habito 'baja el volumen al 30' (Get-Date '2026-09-19 23:01')
$pr2 = Find-Propuesta $hoy
Comp 'tres dias abriendo y luego lo mismo: la propone' ($pr2 -and $pr2.tipo -eq 'appAbre' -and $pr2.valor -eq 'steam' -and $pr2.accion -eq 'baja el volumen al 30') $pr2.clave

Write-Host "--- habitos: tres ordenes seguidas -> un modo ---"
$script:habitos = $null; Remove-Item (Join-Path $MemoriaDir 'habitos.json') -ErrorAction SilentlyContinue
foreach ($d in '2026-09-15', '2026-09-16') {
    Add-Habito 'pon modo juego' (Get-Date "$d 20:00"); Add-Habito 'sube el brillo al 80' (Get-Date "$d 20:01"); Add-Habito 'abre discord' (Get-Date "$d 20:02")
}
Comp 'dos dias seguidos no bastan' ($null -eq (Find-Propuesta $hoy))
Add-Habito 'pon modo juego' (Get-Date '2026-09-18 10:00'); Add-Habito 'sube el brillo al 80' (Get-Date '2026-09-18 10:04'); Add-Habito 'abre discord' (Get-Date '2026-09-18 10:12')
Comp 'si se estiran mas de 5 min no es una secuencia' ($null -eq (Find-Propuesta $hoy))
Add-Habito 'pon modo juego' (Get-Date '2026-09-19 22:00'); Add-Habito 'sube el brillo al 80' (Get-Date '2026-09-19 22:01'); Add-Habito 'abre discord' (Get-Date '2026-09-19 22:03')
$pr3 = Find-Propuesta $hoy
Comp 'tres dias, las tres seguidas: la propone (aunque sea a otra hora)' ($pr3 -and $pr3.tipo -eq 'secuencia' -and @($pr3.ordenes).Count -eq 3 -and $pr3.ordenes[2] -eq 'abre discord') $pr3.clave
[void](Get-Habitos).rechazadas.Add($pr3.clave)
Comp 'rechazada, no vuelve' ($null -eq (Find-Propuesta $hoy))
$script:invitado = $true
$antesInv = (Get-Habitos).usos.Count
Add-Habito 'pon modo noche' (Get-Date '2026-09-19 23:00')
Comp 'en modo invitado no se apunta nada' ((Get-Habitos).usos.Count -eq $antesInv)
$script:invitado = $false

Write-Host "--- parte de la manana ---"
$script:recFalsos = @()
function Get-Recordatorios { return $script:recFalsos }
$script:resumenPendiente = ''
$script:clima = @{ emoji = 'X'; temp = 18; desc = 'esta despejado' }
Test-ParteManana (Get-Date '2026-09-20 15:00')
Comp 'por la tarde no hay parte' ($script:resumenPendiente -eq '')
$script:recFalsos = @([pscustomobject]@{ cuando = '2026-09-20T18:00:00'; texto = 'llamar a mama' }, [pscustomobject]@{ cuando = '2026-09-21T09:00:00'; texto = 'otro dia' })
Test-ParteManana (Get-Date '2026-09-20 08:30')
Comp 'a primera hora: tiempo y lo de hoy (no lo de manana)' ($script:resumenPendiente -match '^Buenos dias . X 18.' -and $script:resumenPendiente -match 'hoy: llamar a mama$') $script:resumenPendiente
# QUE LA CAPSULA LO ENSENE SON DOS COSAS, no una (revision del 23/09). El bucle vacia
# $script:resumenPendiente Y borra habitos.parteTexto; haciendo solo la primera, la
# funcion hacia bien su trabajo -reponerlo, porque para ella ese parte no habia llegado
# a decirse- y el banco lo contaba como tres fallos. Y de paso no probaba lo unico que
# importa aqui: que SI se reponga cuando Nova reinicia antes de decirlo.
$script:resumenPendiente = ''
(Get-Habitos).parteTexto = ''; Save-Habitos   # las dos cosas que hace el bucle al
# ensenarlo: vaciar la variable y borrarlo DEL DISCO. Sin el Save, al releer el fichero
# vuelve a estar y la funcion lo repone, que es justo lo que tiene que hacer.
Test-ParteManana (Get-Date '2026-09-20 09:30')
Comp 'una vez al dia' ($script:resumenPendiente -eq '')
$script:habitos = $null
Test-ParteManana (Get-Date '2026-09-20 10:00')
Comp 'y lo recuerda tras releer el archivo' ($script:resumenPendiente -eq '')
$script:invitado = $true
Test-ParteManana (Get-Date '2026-09-21 08:00')
Comp 'nada en modo invitado' ($script:resumenPendiente -eq '')
$script:invitado = $false

# PERO SI NOVA REINICIO ANTES DE DECIRLO, EL PARTE VUELVE. Es para lo que se escribio:
# arranca 17 veces al dia, y sin esto un reinicio entre la preparacion y la voz gastaba
# el dia entero sin que braya oyera nada.
$script:habitos = $null
$script:resumenPendiente = ''
$hbP = Get-Habitos
$hbP.parteVisto = '2026-09-20'
$hbP.parteTexto = 'Buenos dias, esto no llego a decirse'
Test-ParteManana (Get-Date '2026-09-20 11:00')
Comp 'si Nova reinicio sin decirlo, vuelve' ($script:resumenPendiente -eq 'Buenos dias, esto no llego a decirse') $script:resumenPendiente
$hbP.parteTexto = ''
$script:resumenPendiente = ''

# LA DECISION QUE ESPERA DATOS SALE POR AQUI (20/09, P5). Antes iba por un aviso suelto de
# nivel 'medio' que se calla de noche: sono UNA vez (18/09 19:59) y no podia repetir hasta
# el 25/09. Ahora se apunta y lo saca el parte, sin ponerse pesada: una cada 7 dias.
$script:habitos = $null
Remove-Item (Join-Path $MemoriaDir 'habitos.json') -ErrorAction SilentlyContinue
$script:resumenPendiente = ''
$script:recFalsos = @()
$script:clima = $null
$script:parteSinDatos = 'Tengo una decision esperando: mi oido fino solo me ha servido 2 de 30 veces'
Test-ParteManana (Get-Date '2026-09-22 08:30')
Comp 'la decision que espera datos sale en el parte' ($script:resumenPendiente -match 'una decision esperando') $script:resumenPendiente
Comp 'y sale ella sola, sin tiempo ni recordatorios' ($script:resumenPendiente -match '^Buenos dias') $script:resumenPendiente
Comp 'dicha una vez, no se queda repitiendose' ($script:parteSinDatos -eq '')
$script:parteSinDatos = 'Tengo una decision esperando: otra cosa'
$script:resumenPendiente = ''
Test-ParteManana (Get-Date '2026-09-23 08:30')
Comp 'al dia siguiente NO insiste' ($script:resumenPendiente -eq '') $script:resumenPendiente
Comp 'y la deja apuntada para cuando toque' ($script:parteSinDatos -ne '')
$script:resumenPendiente = ''
Test-ParteManana (Get-Date '2026-09-30 08:30')
Comp 'pasada la semana, vuelve a salir' ($script:resumenPendiente -match 'otra cosa') $script:resumenPendiente
$script:habitos = $null
Comp 'y se acuerda entre reinicios (habitos.json)' ((Get-Habitos).sinDatosVisto -eq '2026-09-30')

Write-Host "--- tu ritmo al hablar y la precarga de la charla ---"
$script:habitos = $null; Remove-Item (Join-Path $MemoriaDir 'habitos.json') -ErrorAction SilentlyContinue
$SeguimientoMs = 2500; $ConversacionEsperaMs = 7000; $ConversacionOn = $true; $TmpDir = $MemoriaDir
function Dicho($s) { [System.IO.File]::WriteAllText((Join-Path $TmpDir 'seguimiento-voz.txt'), $s); Add-RitmoSeguimiento }
Comp 'sin datos, las ventanas de siempre' ((Get-VentanaSeguimiento $false) -eq 2500 -and (Get-VentanaSeguimiento $true) -eq 7000)
foreach ($s in '1.0', '1.2', '0.8', '1.1', '3.0', '1.0') { Dicho $s }
Comp 'apunta lo que tardas en empezar a hablar' ((Get-Habitos).ritmo.Count -eq 6)
$vc = Get-VentanaSeguimiento $true
Comp 'si contestas rapido, la charla espera menos (sin bajar de 4 s)' ($vc -ge 4000 -and $vc -lt 7000) $vc
Comp 'las ordenes nunca por debajo de lo configurado' ((Get-VentanaSeguimiento $false) -eq 2500)
foreach ($i in 1..6) { Dicho '5.5' }
$vc2 = Get-VentanaSeguimiento $true
Comp 'si tardas, espera mas (con tope de 12 s)' ($vc2 -gt 7000 -and $vc2 -le 12000) $vc2
Dicho '45'
Comp 'un disparate (mas de 30 s) no cuenta' ((Get-Habitos).ritmo.Count -eq 12)
$script:habitos = $null
Comp 'sobrevive a releer el archivo' ((Get-Habitos).ritmo.Count -eq 12)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:charlaUltima = -99999999; $script:juegoActivo = $null
Comp 'sin costumbre de charlar a esta hora, no precarga' (-not (Test-PrecargaCharla (Get-Date '2026-09-20 22:10')))
foreach ($d in '2026-09-17', '2026-09-18', '2026-09-19') { Add-CharlaHora (Get-Date "$d 22:30") }
Comp 'tres dias charlando a esa hora: precarga' (Test-PrecargaCharla (Get-Date '2026-09-20 22:10'))
Comp 'a otra hora no' (-not (Test-PrecargaCharla (Get-Date '2026-09-20 09:10')))
Comp 'lo de hace mas de dos semanas no cuenta' (-not (Test-PrecargaCharla (Get-Date '2026-10-15 22:10')))
$script:juegoActivo = 'Hades'
Comp 'jugando no, que la RAM es del juego' (-not (Test-PrecargaCharla (Get-Date '2026-09-20 22:10')))
$script:charlaUltima = $sw.ElapsedMilliseconds
# EL JUEGO MANDA, TAMBIEN SI ACABAS DE CHARLAR (19/09). Esta prueba comprobaba lo
# contrario -que una charla reciente se saltaba el freno del juego- y se cambia a
# proposito, no para que pase: con el modelo local ya en qwen2.5:3b (~2 GB en RAM,
# antes 1.5b con 986 MB) volver a meterlo mientras juegas le quita al juego justo lo
# que el bucle del minuto acababa de liberar. El camino de 'suena a charla' ya miraba
# el juego lo primero; ahora los dos caminos hacen lo mismo.
Comp 'jugando NO precarga, aunque acabeis de hablar' (-not (Test-PrecargaCharla (Get-Date '2026-09-20 22:10')))
$script:juegoActivo = $null
Comp 'y sin juego, una charla reciente si precarga' (Test-PrecargaCharla (Get-Date '2026-09-20 22:10'))
$script:invitado = $true; Add-CharlaHora (Get-Date '2026-09-20 03:00'); $script:invitado = $false
Comp 'lo de un invitado no cuenta' (@((Get-Habitos).charlaHoras.Keys | Where-Object { $_ -like '*|03' }).Count -eq 0)

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
