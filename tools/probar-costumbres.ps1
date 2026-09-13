# Pruebas de dos cosas que Nova hace sola sin molestar:
#  - NOTIFICACIONES: que cuente solo las nuevas, que jugando solo lata el borde,
#    y que el resumen y la lectura digan lo que tienen que decir.
#  - HABITOS: que proponga automatizar una costumbre de verdad (misma orden a la
#    misma hora, o justo despues de abrir una app, tres dias distintos), y que
#    no insista: una al dia, y un "no" es para siempre.
# Trabaja en una carpeta temporal propia y la borra al acabar.
#
#   powershell -NoProfile -File tools\probar-costumbres.ps1
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn($n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta la funcion $n en assistant.ps1" }
    return $f.Extent.Text
}
foreach ($n in 'ConvertTo-Plain', 'Watch-Notificaciones', 'Get-ResumenNotificaciones', 'Get-LecturaNotificaciones', 'Get-Contactos', 'Save-Contactos',
    'Get-Habitos', 'Save-Habitos', 'Add-Habito', 'Find-Propuesta', 'Test-ParteManana') { Invoke-Expression (TraerFn $n) }
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
[void](Get-Habitos).rechazadas.Add('hora|pon modo noche')
Comp 'un no es para siempre' ($null -eq (Find-Propuesta $hoy))
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
$script:resumenPendiente = ''
Test-ParteManana (Get-Date '2026-09-20 09:30')
Comp 'una vez al dia' ($script:resumenPendiente -eq '')
$script:habitos = $null
Test-ParteManana (Get-Date '2026-09-20 10:00')
Comp 'y lo recuerda tras releer el archivo' ($script:resumenPendiente -eq '')
$script:invitado = $true
Test-ParteManana (Get-Date '2026-09-21 08:00')
Comp 'nada en modo invitado' ($script:resumenPendiente -eq '')
$script:invitado = $false

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
