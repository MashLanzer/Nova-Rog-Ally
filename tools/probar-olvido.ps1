# OLVIDAR LO DE HACE UN RATO (20/09), probado sobre copias de las superficies de verdad.
#
# Por que existe esta prueba: la noche del 19/09 hubo que borrar una conversacion privada
# y se hizo a mano, sitio por sitio. Se dijo "borrado y verificado, todo a cero" y quedaban
# 128 rastros: 41 lineas con frases literales en estadisticas.md, 40 en estadisticas.json,
# 1 en habitos.json y 46 en gestos.log. El fallo no fue borrar mal: fue no tener lista.
# Invoke-Olvido ES esa lista, y esta prueba comprueba que cada fila de la lista muerde.
#
# Lo importante que se prueba aqui, mas alla de que borre: que NO se lleva por delante lo
# de antes del corte. Un olvido que borra de mas no se nota hasta que falta algo.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# --- las funciones de verdad, sacadas del archivo real ---
# REGLA (aprendida tres veces el 19/09): si anades una funcion al codigo y la llamas desde
# aqui, TIENE que estar en esta lista. Si no, la prueba corre contra una funcion que no
# existe y pasa en verde sin probar nada (paso con Test-ApiContestaPrimero, todo un dia).
foreach ($fn in @('Remove-LineasDesde', 'Remove-JsonlDesde', 'Remove-ArchivosDesde', 'Invoke-Olvido')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}\(.*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

# --- un escenario falso con las mismas superficies que las de verdad ---
$base = Join-Path ([System.IO.Path]::GetTempPath()) ('olvido-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$LogDir = $base
$TmpDir = Join-Path $base 'tmp'
$MemoriaDir = Join-Path $base 'memoria'
$usoDir = Join-Path $base 'pruebas\audio\uso'
foreach ($d in @($base, $TmpDir, $MemoriaDir, $usoDir)) { $null = New-Item -ItemType Directory -Path $d -Force }

$ahora = Get-Date
$viejo = $ahora.AddMinutes(-60)      # de hace una hora: NO se toca
$nuevo = $ahora.AddMinutes(-3)       # de hace 3 minutos: se va
$f = { param($d) $d.ToString('yyyy-MM-dd HH:mm:ss') }

function Log($t) { }                                  # la de verdad escribe en el log

# ESTE STUB ERA LO QUE TAPABA EL FALLO MAS GRAVE DE TODA LA LISTA (21/09). Estaba vacio,
# y la de verdad reescribe estadisticas.json ENTERO desde $script:stats, que sigue en RAM
# con las frases dentro. Asi que el olvido se deshacia a si mismo: Nova borraba, contestaba
# "he borrado N rastros" y las devolvia al archivo antes de salir de Invoke-Olvido.
# Ahora el stub hace lo MISMO que la de verdad en lo que importa -volcar la cache al
# disco-, para que la prueba pueda ver si la cache quedo limpia o no.
$script:stats = $null
$script:habitos = $null
function Get-Estadisticas {
    if ($null -ne $script:stats) { return $script:stats }
    $script:stats = @{ dias = @{}; descartes = @(); recientes = @() }
    $rE = Join-Path $MemoriaDir 'estadisticas.json'
    if (Test-Path -LiteralPath $rE) {
        $jE = Get-Content -LiteralPath $rE -Raw | ConvertFrom-Json
        $script:stats.descartes = @($jE.descartes)
        $script:stats.recientes = @($jE.recientes)
    }
    return $script:stats
}
function Get-Habitos {
    if ($null -ne $script:habitos) { return $script:habitos }
    $script:habitos = @{ usos = (New-Object System.Collections.ArrayList) }
    $rH = Join-Path $MemoriaDir 'habitos.json'
    if (Test-Path -LiteralPath $rH) {
        $jH = Get-Content -LiteralPath $rH -Raw | ConvertFrom-Json
        foreach ($u in @($jH.usos)) { if ($u -and $u.t) { [void]$script:habitos.usos.Add(@{ t = [string]$u.t; f = [string]$u.f; h = [string]$u.h }) } }
    }
    return $script:habitos
}
function Save-Habitos {
    # como la de verdad: reescribe el archivo ENTERO desde la cache
    $hS = Get-Habitos
    [System.IO.File]::WriteAllText((Join-Path $MemoriaDir 'habitos.json'),
        (@{ usos = @($hS.usos) } | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $false))
}
function Add-Estadistica($r, $d = '', $c = $false) {
    $sE = Get-Estadisticas
    [System.IO.File]::WriteAllText((Join-Path $MemoriaDir 'estadisticas.json'),
        (@{ dias = @{}; descartes = @($sE.descartes); recientes = @($sE.recientes) } | ConvertTo-Json -Depth 8),
        (New-Object System.Text.UTF8Encoding $false))
}

# 1) los de linea con fecha
[System.IO.File]::WriteAllLines((Join-Path $base 'assistant.log'), @(
    ((& $f $viejo) + '  esto es de hace una hora y se queda'),
    ((& $f $nuevo) + '  NOVA: lo que se dijo hace tres minutos'),
    'una linea sin fecha, que tambien se queda'))
[System.IO.File]::WriteAllLines((Join-Path $base 'replies.log'), @(
    ((& $f $viejo) + '  respuesta vieja'),
    ((& $f $nuevo) + '  respuesta de hace un rato')))
# LAS COPIAS ROTADAS (21/09): cuando el log pasa del tope, Rotate-Log lo mueve a
# assistant.log.1, ese a .2 y asi. Lo que hay que olvidar puede estar entero ahi, y justo
# cuando mas probable es: una conversacion larga es la que hace rotar el log.
$KeepLogs = 3
[System.IO.File]::WriteAllLines((Join-Path $base 'assistant.log.1'), @(
    ((& $f $viejo) + '  una linea vieja de la copia rotada'),
    ((& $f $nuevo) + '  NOVA: algo privado que roto al archivo 1')))
[System.IO.File]::WriteAllLines((Join-Path $base 'assistant.log.2'), @(
    ((& $f $nuevo) + '  NOVA: y algo privado del archivo 2')))
[System.IO.File]::WriteAllLines((Join-Path $base 'replies.log.1'), @(
    ((& $f $nuevo) + '  una respuesta privada que roto')))
[System.IO.File]::WriteAllLines((Join-Path $TmpDir 'gestos.log'), @(
    ((& $f $viejo) + ' orgullo'),
    ((& $f $nuevo) + ' carino'),
    ((& $f $nuevo) + ' risa')))

# 2) el uso real: wav + su linea del registro
foreach ($par in @(@{n = 'viejo.wav'; d = $viejo }, @{n = 'nuevo.wav'; d = $nuevo })) {
    $r = Join-Path $usoDir $par.n
    [System.IO.File]::WriteAllBytes($r, [byte[]](1, 2, 3))
    (Get-Item -LiteralPath $r).LastWriteTime = $par.d
}
[System.IO.File]::WriteAllLines((Join-Path $usoDir 'registro.jsonl'), @(
    ('{"id":"viejo","hora":"' + (& $f $viejo) + '","entregado":"abre steam"}'),
    ('{"id":"nuevo","hora":"' + (& $f $nuevo) + '","entregado":"algo privado"}')))
# activaciones.jsonl (P2, 20/09): trae lo que se oyo en 'oido'
[System.IO.File]::WriteAllLines((Join-Path $usoDir 'activaciones.jsonl'), @(
    ('{"hora":"' + (& $f $viejo) + '","desenlace":"orden","oido":"pon musica"}'),
    ('{"hora":"' + (& $f $nuevo) + '","desenlace":"nada","oido":"una frase de ahora mismo"}')))
# senales-fallo.jsonl (P1, 20/09): trae el texto de la orden en 'detalle'
[System.IO.File]::WriteAllLines((Join-Path $usoDir 'senales-fallo.jsonl'), @(
    ('{"id":"viejo","hora":"' + (& $f $viejo) + '","senal":"ruido","detalle":"una orden vieja"}'),
    ('{"id":"nuevo","hora":"' + (& $f $nuevo) + '","senal":"descarte","detalle":"algo privado deducido"}')))

# 3) un wav a medio camino en tmp (el que viaja a la nube vive aqui)
$wn = Join-Path $TmpDir 'nube-abcd1234.wav'
[System.IO.File]::WriteAllBytes($wn, [byte[]](1, 2, 3))
$wv = Join-Path $TmpDir 'nube-viejo.wav'
[System.IO.File]::WriteAllBytes($wv, [byte[]](1, 2, 3))
(Get-Item -LiteralPath $wv).LastWriteTime = $viejo

# 4) y 5) estadisticas y habitos
$hoy = $ahora.ToString('yyyy-MM-dd')
$ayer = $ahora.AddDays(-1).ToString('yyyy-MM-dd')
[System.IO.File]::WriteAllText((Join-Path $MemoriaDir 'estadisticas.json'), (@{
            dias      = @{ $hoy = @{ local = 3 } }
            descartes = @(($hoy + '  una frase privada de hoy'), ($ayer + '  algo de ayer'))
            recientes = @()
        } | ConvertTo-Json -Depth 8))
[System.IO.File]::WriteAllText((Join-Path $MemoriaDir 'habitos.json'), (@{
            usos = @(
                @{ t = 'abre steam'; f = $viejo.ToString('yyyy-MM-dd'); h = $viejo.ToString('HH:mm') },
                @{ t = 'algo privado'; f = $nuevo.ToString('yyyy-MM-dd'); h = $nuevo.ToString('HH:mm') })
        } | ConvertTo-Json -Depth 8))

# LA CACHE SE CARGA ANTES, QUE ES COMO PASA DE VERDAD (21/09). Nova lleva horas en marcha
# cuando braya dice "olvida lo de hace un rato": $script:stats y $script:habitos estan en
# RAM desde el arranque, con las frases dentro. Si esta prueba empieza con las dos en $null
# el fallo NO se reproduce -Get-Estadisticas leeria del archivo ya limpio- y la prueba pasa
# en verde con el codigo roto. Comprobado: quitando la invalidacion de assistant.ps1, sin
# estas dos lineas no cantaba nada.
$null = Get-Estadisticas
$null = Get-Habitos
Comp 'la cache trae la frase privada antes de olvidar' `
    ((@($script:stats.descartes | ForEach-Object { [string]$_ }) -join ' | ').Contains('privada de hoy'))
Comp 'y la de habitos tambien' `
    ((@($script:habitos.usos | ForEach-Object { [string]$_.t }) -join ' | ').Contains('algo privado'))

Write-Host '-- olvidar los ultimos 10 minutos --'
$r = Invoke-Olvido 10

$log = [System.IO.File]::ReadAllText((Join-Path $base 'assistant.log'))
Comp 'del log se va lo de hace 3 min' (-not $log.Contains('hace tres minutos'))
Comp 'y se queda lo de hace una hora' ($log.Contains('se queda'))
Comp 'la linea sin fecha no se toca' ($log.Contains('sin fecha'))

Write-Host '-- y las copias rotadas, que es donde acaba una conversacion larga --'
$r1 = [System.IO.File]::ReadAllText((Join-Path $base 'assistant.log.1'))
Comp 'de la copia .1 se va lo de hace 3 min' (-not $r1.Contains('algo privado que roto'))
Comp 'y se queda lo viejo de esa copia' ($r1.Contains('una linea vieja de la copia rotada'))
$r2 = [System.IO.File]::ReadAllText((Join-Path $base 'assistant.log.2'))
Comp 'la copia .2 tambien se limpia' (-not $r2.Contains('algo privado del archivo 2'))
$rr1 = [System.IO.File]::ReadAllText((Join-Path $base 'replies.log.1'))
Comp 'y las respuestas rotadas igual' (-not $rr1.Contains('una respuesta privada que roto'))

$rep = [System.IO.File]::ReadAllText((Join-Path $base 'replies.log'))
Comp 'sus respuestas, igual' ((-not $rep.Contains('de hace un rato')) -and $rep.Contains('vieja'))

$ges = [System.IO.File]::ReadAllText((Join-Path $TmpDir 'gestos.log'))
Comp 'los gestos de hace un rato se van' ((-not $ges.Contains('carino')) -and (-not $ges.Contains('risa')))
Comp 'y los viejos se quedan' ($ges.Contains('orgullo'))

Comp 'el wav de uso reciente se borra' (-not (Test-Path -LiteralPath (Join-Path $usoDir 'nuevo.wav')))
Comp 'el wav de uso viejo se queda' (Test-Path -LiteralPath (Join-Path $usoDir 'viejo.wav'))

$reg = [System.IO.File]::ReadAllText((Join-Path $usoDir 'registro.jsonl'))
Comp 'su linea del registro se va con el' (-not $reg.Contains('algo privado'))
Comp 'la del audio viejo sigue' ($reg.Contains('abre steam'))

$act = [System.IO.File]::ReadAllText((Join-Path $usoDir 'activaciones.jsonl'))
Comp 'la activacion de hace 3 min se va' (-not $act.Contains('una frase de ahora mismo'))
Comp 'y la vieja se queda' ($act.Contains('pon musica'))

$sen = [System.IO.File]::ReadAllText((Join-Path $usoDir 'senales-fallo.jsonl'))
Comp 'la senal de fallo deducida se va' (-not $sen.Contains('algo privado deducido'))
Comp 'y la vieja se queda' ($sen.Contains('una orden vieja'))

Comp 'el wav que iba a la nube se borra' (-not (Test-Path -LiteralPath $wn))
Comp 'uno viejo de tmp se queda' (Test-Path -LiteralPath $wv)

$est = Get-Content -LiteralPath (Join-Path $MemoriaDir 'estadisticas.json') -Raw | ConvertFrom-Json
$desc = @($est.descartes) -join ' | '
Comp 'la frase descartada de hoy se va' (-not $desc.Contains('privada de hoy'))
Comp 'la de ayer se queda' ($desc.Contains('algo de ayer'))

$hab = Get-Content -LiteralPath (Join-Path $MemoriaDir 'habitos.json') -Raw | ConvertFrom-Json
$usos = @($hab.usos | ForEach-Object { $_.t }) -join ' | '
Comp 'el habito de hace 3 min se va' (-not $usos.Contains('algo privado'))
Comp 'el de hace una hora se queda' ($usos.Contains('abre steam'))

Write-Host '-- y lo que devuelve --'
Comp 'dice en cuantos sitios toco' ($r.Count -ge 6) ("$($r.Count) claves")
Comp 'devuelve los minutos que olvido' ($r['minutos'] -eq 10)

Write-Host '-- las dos caches en RAM: aqui se deshacia el olvido solo --'
# Antes de este arreglo, estas dos lineas volvian a llenar los archivos que se acababan de
# limpiar. Y habitos.json ni siquiera hacia falta hablar: Set-PresenciaAhora llama a
# Save-Habitos desde el bucle del mando, como mucho una vez por minuto.
# OJO: la de estadisticas NO queda en $null al final, y esta bien que sea asi: el empujon
# del paso 7 la vuelve a cargar A PROPOSITO, ya del archivo limpio, para reescribir el .md.
# Lo que hay que exigir no es que este vacia, sino que lo que tiene dentro este limpio.
$cacheDesc = @($script:stats.descartes | ForEach-Object { [string]$_ }) -join ' | '
Comp 'la cache de estadisticas se releyo del archivo limpio' (-not $cacheDesc.Contains('privada de hoy')) `
    $(if ($cacheDesc.Contains('privada de hoy')) { 'sigue teniendo la frase privada' } else { '' })
Comp 'y la de habitos queda tirada del todo' ($null -eq $script:habitos)
# y lo que de verdad importa: que un guardado POSTERIOR no las devuelva
Add-Estadistica 'lo que sea' ''
$est2 = Get-Content -LiteralPath (Join-Path $MemoriaDir 'estadisticas.json') -Raw | ConvertFrom-Json
$desc2 = @($est2.descartes) -join ' | '
Comp 'tras guardar otra vez, la frase privada NO vuelve' (-not $desc2.Contains('privada de hoy'))
Comp 'y la de ayer sigue estando' ($desc2.Contains('algo de ayer'))
# EL DE HABITOS ES PEOR PORQUE NO HACE FALTA HABLAR: Set-PresenciaAhora llama a
# Save-Habitos desde el bucle del mando, como mucho una vez por minuto. Menos de 60
# segundos despues de olvidar, lo olvidado estaba de vuelta solo.
Save-Habitos
$hab2 = Get-Content -LiteralPath (Join-Path $MemoriaDir 'habitos.json') -Raw | ConvertFrom-Json
$usos2 = @($hab2.usos | ForEach-Object { $_.t }) -join ' | '
Comp 'y un guardado de habitos tampoco la devuelve' (-not $usos2.Contains('algo privado'))
Comp 'con lo de hace una hora intacto' ($usos2.Contains('abre steam'))

Write-Host '-- un olvido de 0 minutos se trata como 10, no como "todo" --'
# esto era literalmente Comp '...' ($true): un verde de adorno. Ahora se ejecuta.
$r0 = Invoke-Olvido 0
Comp 'un olvido de 0 minutos se convierte en 10' ($r0['minutos'] -eq 10) "dice $($r0['minutos'])"
$logF = [System.IO.File]::ReadAllText((Join-Path $base 'assistant.log'))
Comp 'y no se lleva por delante lo de hace una hora' ($logF.Contains('se queda'))

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue

if ($fallos -gt 0) { Write-Host ''; Write-Host ("  $fallos fallo(s)"); exit 1 }
Write-Host ''
Write-Host '  el olvido borra lo de hace un rato en los 8 sitios y no toca lo de antes'
exit 0
