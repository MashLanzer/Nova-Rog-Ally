# QUE NOVA TE DIGA QUE SE CAYO (25/09, idea 29 de las cincuenta)
#
# LO QUE PASO, y es el motivo exacto de esta idea: el 24/09 a las 21:53 Nova se murio de golpe
# mientras braya jugaba, y estuvo muerta hasta las 23:33 -una hora y cuarenta-. braya no se
# entero por ella: se entero porque yo lo vi mirando procesos. Su asistente se le habia muerto
# y al volver le saludo como si nada.
#
# EL RASTRO YA ESTABA, en dos sitios distintos:
#   1. "VoiceAssistant iniciado" sin su "VoiceAssistant cerrado" detras. El cerrado solo se
#      escribe al salir por la puerta; un kill no lo escribe, y por eso su ausencia delata.
#   2. El oido, que si se entera: "el asistente ya no existe (PID 19604); salgo y suelto el
#      microfono". Esa linea trae la HORA EXACTA de la muerte, que la otra no tiene.
# Con las dos se puede decir algo util -cuando fue, cuanto estuvo fuera y que estaba haciendo-
# en vez de un "me cai" a secas.
#
# LA VENTANA TEMPORAL IMPORTA AQUI MAS QUE NUNCA: la linea "cerrado" no existe antes del 18/09
# a las 17:06. Un arranque anterior a esa fecha NO tiene cerrado porque no se escribia, no
# porque se cayera. Si esto no se mira, Nova diria "me cai" de cada sesion de nueve dias.
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

Write-Host '-- 1. la funcion existe y se usa --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'existe Get-CaidaAnterior' ($sinCom -match 'function Get-CaidaAnterior') ''
Comp 'y se llama al arrancar' ($sinCom -match 'Test-CaidaAnterior|Get-CaidaAnterior [^\n]*\$PID') ''
Comp 'el aviso va por la puerta del entorno' ($sinCom -match "Send-AvisoEntorno 'me-cai'") 'si no estas, se guarda para cuando vuelvas'
Comp 'y NO por Say' (-not ($sinCom -match "Say .{0,40}me cai")) 'Say no mira la sordina ni el juego'

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA CON LOGS DE MENTIRA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-CaidaAnterior' }, $true)
if (-not $d) {
    Comp 'se saca Get-CaidaAnterior del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
# Y SUS DOS CONSTANTES, SACADAS DEL ARCHIVO (manera 6). La funcion las usa pero no las lleva
# dentro, asi que traer solo la funcion las dejaba en $null: $CaidaHuecoMaxHoras a $null hace
# que "$fuera -gt ($null * 60)" sea "$fuera -gt 0", o sea que TODA caida se descartaba y el
# banco daba tres rojos con el codigo bien. Escribirlas aqui a mano seria probar mi numero en
# vez del suyo, que es el otro lado del mismo error.
foreach ($cte in @('CaidaDesdeQueHayCerrado', 'CaidaHuecoMaxHoras', 'CaidaMargenArranqueSeg')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo la constante " + $cte) $m.Success ''
    if ($m.Success) { Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim()) }
}
Comp 'y el tope del hueco es un numero de horas razonable' ($CaidaHuecoMaxHoras -ge 2 -and $CaidaHuecoMaxHoras -le 48) "$CaidaHuecoMaxHoras h"
function Log([string]$m) { }          # el doble, DESPUES de cargar (manera 9)

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-caida-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
function Escribe([string]$nombre, [string[]]$lineas) {
    $r = Join-Path $tmp $nombre
    [IO.File]::WriteAllLines($r, $lineas)
    return $r
}
try {
    # --- CIERRE LIMPIO: no debe decir nada
    $lim = Escribe 'limpio.log' @(
        '2026-09-24 20:00:00  VoiceAssistant iniciado PID=111 (trigger: x)',
        '2026-09-24 20:30:00  algo normal',
        '2026-09-24 21:00:00  VoiceAssistant cerrado PID=111',
        '2026-09-24 22:00:00  VoiceAssistant iniciado PID=222 (trigger: x)')
    $r = Get-CaidaAnterior $lim 222
    Comp 'un cierre limpio no dice nada' ($null -eq $r) "$(if ($r) { 'dijo: ' + $r.texto })"

    # --- CIERRE SUCIO: debe decirlo, con hora y hueco
    # OJO CON EL ORDEN (25/09, lo cazo una rotura): si la linea del oido fuera la ULTIMA del
    # log, quitarle a la funcion la busqueda de esa linea daria la misma hora por el camino de
    # respaldo y el banco no notaria nada. Por eso aqui hay una linea DESPUES: asi la hora
    # buena (21:53, la del oido) y la del respaldo (22:10) son distintas y se puede distinguir.
    # En el log de verdad pasa igual: tras morir el asistente, sus workers siguen escribiendo.
    $suc = Escribe 'sucio.log' @(
        '2026-09-24 20:44:49  VoiceAssistant iniciado PID=19604 (trigger: x)',
        '2026-09-24 21:52:40  mando: vibracion disponible',
        '2026-09-24 21:53:00  [escucha] el asistente ya no existe (PID 19604); salgo y suelto el microfono',
        '2026-09-24 22:10:00  [escucha] worker fuera',
        '2026-09-24 23:33:09  VoiceAssistant iniciado PID=10716 (trigger: x)')
    $r = Get-CaidaAnterior $suc 10716
    Comp 'un cierre sucio SI se dice' ($null -ne $r) ''
    if ($r) {
        Comp '  y sabe la hora exacta de la muerte' ($r.cuando -eq '21:53') "$($r.cuando)"
        Comp '  y cuanto estuvo fuera' ($r.minutos -eq 100) "$($r.minutos) min (21:53 -> 23:33)"
        Comp '  y que estaba haciendo' ($r.haciendo -match 'vibracion|mando') "$($r.haciendo)"
    }

    # --- LO QUE ESCRIBE EL ARRANQUE NUEVO NO ES "lo que estaba haciendo" (25/09). Se vio en
    # la primera prueba de verdad: dijo "hacia: marca huerfana de la sesion anterior", que es
    # una linea que escribe el arranque NUEVO al limpiar, no la sesion que murio. Caen en el
    # hueco entre las dos, asi que hay que descartarlas por cercania al arranque.
    $conLimpieza = Escribe 'limpieza.log' @(
        '2026-09-24 20:44:49  VoiceAssistant iniciado PID=19604 (trigger: x)',
        '2026-09-24 21:52:40  braya pidio abrir Steam',
        '2026-09-24 21:53:00  [escucha] el asistente ya no existe (PID 19604); salgo y suelto el microfono',
        '2026-09-24 23:33:04  marca huerfana de la sesion anterior: dictar.flag',
        '2026-09-24 23:33:05  limpieza: 3 restos de ordenes canceladas',
        '2026-09-24 23:33:09  VoiceAssistant iniciado PID=10716 (trigger: x)')
    $r = Get-CaidaAnterior $conLimpieza 10716
    Comp 'lo que escribe el arranque nuevo no cuenta como "lo que hacia"' ($null -ne $r -and $r.haciendo -match 'Steam') "$(if ($r) { $r.haciendo })"

    # --- SIN LA LINEA DEL OIDO: se sabe que cayo, pero no la hora exacta
    $sinOido = Escribe 'sinoido.log' @(
        '2026-09-24 20:44:49  VoiceAssistant iniciado PID=19604 (trigger: x)',
        '2026-09-24 21:52:40  lo ultimo que hizo',
        '2026-09-24 23:33:09  VoiceAssistant iniciado PID=10716 (trigger: x)')
    $r = Get-CaidaAnterior $sinOido 10716
    Comp 'sin la linea del oido, sigue sabiendo que cayo' ($null -ne $r) ''
    if ($r) { Comp '  y usa la ultima linea como hora' ($r.cuando -eq '21:52') "$($r.cuando)" }

    # --- LA VENTANA TEMPORAL: antes del 18/09 no habia "cerrado", asi que no se sabe
    $viejo = Escribe 'viejo.log' @(
        '2026-09-15 10:00:00  VoiceAssistant iniciado PID=1 (trigger: x)',
        '2026-09-15 12:00:00  algo',
        '2026-09-15 14:00:00  VoiceAssistant iniciado PID=2 (trigger: x)')
    $r = Get-CaidaAnterior $viejo 2
    Comp 'antes del 18/09 NO acusa una caida' ($null -eq $r) 'la linea cerrado no existia: ausencia no es prueba'

    # --- PRIMER ARRANQUE DE LA VIDA: no hay anterior, no hay nada que decir
    # CON LINEAS DETRAS (25/09, lo cazo una rotura): con una sola linea, dar por bueno el
    # indice 0 como "arranque anterior" no llegaba a inventarse nada porque no habia nada que
    # recorrer, y la rotura salia verde. Con actividad detras, quien no compruebe que existe un
    # arranque anterior de verdad se inventa una caida que no hubo.
    $solo = Escribe 'solo.log' @(
        '2026-09-24 22:00:00  VoiceAssistant iniciado PID=9 (trigger: x)',
        '2026-09-24 22:05:00  algo que hizo',
        '2026-09-24 22:30:00  [escucha] pulso normal')
    Comp 'con un solo arranque no dice nada' ($null -eq (Get-CaidaAnterior $solo 9)) ''

    # --- EL LOG ROTO Y SE LLEVO EL ARRANQUE ANTERIOR. Este es el caso de verdad, no un
    # invento: assistant.log rota al pasar de 5 MB, y entonces el trozo que queda empieza a
    # media sesion. Hay actividad ANTES del arranque pero ningun "iniciado" antes de el. Quien
    # no compruebe que ese arranque anterior existe de verdad se inventara una caida cada vez
    # que rote el log, que es justo cuando Nova mas ha estado trabajando.
    $rotado = Escribe 'rotado.log' @(
        '2026-09-24 09:00:00  lo que quedo de la sesion anterior',
        '2026-09-24 09:30:00  [escucha] pulso normal',
        '2026-09-24 10:00:00  mas actividad suelta',
        '2026-09-24 12:00:00  VoiceAssistant iniciado PID=77 (trigger: x)')
    Comp 'si el log roto y no hay arranque anterior, no se inventa nada' ($null -eq (Get-CaidaAnterior $rotado 77)) 'pasa cada 5 MB de registro'

    # --- SIN FICHERO: ni se cae ni inventa
    Comp 'sin log no revienta' ($null -eq (Get-CaidaAnterior (Join-Path $tmp 'no-existe.log') 1)) ''

    # --- DOS CAIDAS SEGUIDAS: la que cuenta es la ULTIMA, no la primera
    # Y AQUI EL PRIMERO CIERRA BIEN (25/09, lo cazo una rotura): si las dos sesiones acabaran
    # mal, mirar el primer arranque en vez del anterior daria la misma respuesta y el banco no
    # veria la diferencia. Con este "cerrado" en medio, quien mire el primero encuentra un
    # cierre limpio y calla; solo quien mire el ANTERIOR de verdad ve la caida de las 13:30.
    $dos = Escribe 'dos.log' @(
        '2026-09-24 10:00:00  VoiceAssistant iniciado PID=1 (trigger: x)',
        '2026-09-24 11:00:00  VoiceAssistant cerrado PID=1',
        '2026-09-24 12:00:00  VoiceAssistant iniciado PID=2 (trigger: x)',
        '2026-09-24 13:30:00  [escucha] el asistente ya no existe (PID 2); salgo y suelto el microfono',
        '2026-09-24 14:00:00  VoiceAssistant iniciado PID=3 (trigger: x)')
    $r = Get-CaidaAnterior $dos 3
    Comp 'con dos caidas, cuenta la ultima' ($null -ne $r -and $r.cuando -eq '13:30') "$(if ($r) { $r.cuando })"

    # --- UN HUECO ABSURDO NO SE DICE: si el log tiene dias de diferencia, no es "me cai"
    $lejano = Escribe 'lejano.log' @(
        '2026-09-20 10:00:00  VoiceAssistant iniciado PID=1 (trigger: x)',
        '2026-09-20 11:00:00  [escucha] el asistente ya no existe (PID 1); salgo y suelto el microfono',
        '2026-09-24 14:00:00  VoiceAssistant iniciado PID=3 (trigger: x)')
    $r = Get-CaidaAnterior $lejano 3
    Comp 'una caida de hace cuatro dias ya no se cuenta' ($null -eq $r) 'contarla seria hablar de historia, no avisar'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  Nova ya te dice cuando se ha caido'
exit 0
