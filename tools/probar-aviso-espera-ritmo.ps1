# LO QUE ESPERA NO SE REINTENTA SIETE VECES POR SEGUNDO (24/09)
#
# LO MEDIDO: con braya jugando a A Way Out, el registro llevaba 413 lineas identicas -"ENTORNO:
# 2 aviso(s) no cabian ahora"- en un cuarto de hora, a razon de SEIS Y SIETE POR SEGUNDO
# (23:49:25 sale seis veces, 23:49:26 otras seis). Y cada una de esas pasadas reescribe
# memoria\avisos-espera.json en disco.
#
# POR QUE: la llamada a Send-AvisoEsperaSuelta estaba suelta dentro del "if (botones -ne 0)" de
# Watch-Entorno. Su comentario dice "este es el instante exacto en que se sabe que ha vuelto",
# pero ese bloque no corre cuando braya vuelve: corre CADA VEZ que el mando manda botones.
# Jugando son rafagas continuas. Es la regla 5 rota por I/O en vez de por RAM.
#
# DOS ARREGLOS, y este banco prueba los dos:
#   1. La llamada va detras de un antirrebote de un minuto (estructural, con el arbol).
#   2. La linea de registro solo sale cuando el numero CAMBIA (ejecutando la funcion de verdad).
#
# LA FUNCION SE CARGA ANTES QUE LOS DOBLES, a proposito: definirlos antes es la manera 9 de
# salir verde mintiendo -el archivo los pisa al cargarse- y hoy mismo mordio en otro banco,
# que acabo llamando a Piper de verdad y dejando un .wav en el disco.
$ErrorActionPreference = 'Stop'
trap { Write-Host "MAL  el banco reviento: $_"; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  ($detalle)" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  ($detalle)" })); $script:mal++ }
}

$errores = $null
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$errores)
Comp 'assistant.ps1 se parsea entero' ($errores.Count -eq 0) "$($errores.Count) error(es)"

Write-Host '-- 1. el antirrebote, mirando el ARBOL y no el texto --'
# Se buscan TODAS las llamadas a Send-AvisoEsperaSuelta y se mira, subiendo por el arbol, si
# cada una esta dentro de un if que compare contra 60000. Mirar el texto con un -match no
# valdria: el comentario del arreglo nombra la variable, y un comentario no frena nada.
$llamadas = $arbol.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.CommandAst] -and
    $n.GetCommandName() -eq 'Send-AvisoEsperaSuelta'
}, $true)
Comp 'se encuentran las llamadas' ($llamadas.Count -ge 3) "$($llamadas.Count) (el mando, el caducar y la voz)"

# DOS CRITERIOS DISTINTOS A PROPOSITO (24/09, lo cazaron las roturas):
#   - la del mando tiene que estar dentro de un if COMPLETO: condicion con el minuto Y cuerpo
#     que rearme la variable. Sin el rearme, la resta contra -999999 da siempre mas de un
#     minuto y el freno no frena nada, pero el if esta ahi y engana al que solo mire la forma.
#   - las OTRAS no pueden estar dentro de ningun if que mencione siquiera esa variable, aunque
#     ese if este a medias. "Que me he perdido" tiene que contestar al momento.
$conFreno = 0
$sinFreno = @()
$tocadas = @()
foreach ($c in $llamadas) {
    $p = $c.Parent
    $frenada = $false
    $rozada = $false
    while ($p) {
        if ($p -is [System.Management.Automation.Language.IfStatementAst] -and
            $p.Clauses[0].Item1.Extent.Text -match 'avisoSueltaUltimo') { $rozada = $true }
        $p = $p.Parent
    }
    if ($rozada) { $tocadas += $c.Extent.StartLineNumber }
    $p = $c.Parent
    while ($p -and -not $frenada) {
        if ($p -is [System.Management.Automation.Language.IfStatementAst]) {
            $cond = $p.Clauses[0].Item1.Extent.Text
            # Y QUE EL FRENO SE REARME DENTRO (24/09, lo cazo una rotura). Con el if puesto
            # pero sin la asignacion, avisoSueltaUltimo se queda en -999999 para siempre: la
            # resta da siempre mas de un minuto y dispara en todas las vueltas. El banco salia
            # verde con el freno completamente inutil.
            $cuerpo = $p.Clauses[0].Item2.Extent.Text
            if ($cond -match 'avisoSueltaUltimo' -and $cond -match '60000' -and
                $cuerpo -match '\$script:avisoSueltaUltimo\s*=\s*\$ahoraW') { $frenada = $true }
        }
        $p = $p.Parent
    }
    if ($frenada) { $conFreno++ } else { $sinFreno += $c.Extent.StartLineNumber }
}
Comp 'la del mando va con antirrebote' ($conFreno -ge 1) "$conFreno de $($llamadas.Count)"
# Y LAS OTRAS NO DEBEN LLEVARLO: "que me he perdido" tiene que contestar al momento, y el
# caducar de fondo es barato y no habla. Si el freno se colara ahi, Nova tardaria hasta un
# minuto en contestar a una pregunta directa.
Comp 'y las demas siguen sin freno' ($sinFreno.Count -ge 2) "lineas $($sinFreno -join ', ')"
Comp 'y ni siquiera lo rozan' ($tocadas.Count -eq $conFreno) "$($tocadas.Count) llamada(s) dentro de ese if, deberia ser $conFreno"

# y que el freno sea de verdad un minuto y no un numero cualquiera
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^\s*#' }) -join "`n"
Comp 'la variable del antirrebote se inicializa' ($sinCom -match '\$script:avisoSueltaUltimo\s*=\s*-?\d+') 'sin esto la primera pasada fallaria'
Comp 'y arranca en el pasado, para no perder la primera' ($sinCom -match '\$script:avisoSueltaUltimo\s*=\s*-\d{4,}') 'un 0 haria esperar un minuto tras arrancar'

Write-Host ''
Write-Host '-- 2. la funcion, SACADA DEL ARCHIVO Y EJECUTADA --'
$fn = $arbol.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $n.Name -eq 'Send-AvisoEsperaSuelta'
}, $true)
Comp 'se saca Send-AvisoEsperaSuelta del arbol' ($fn.Count -eq 1) ''
if ($fn.Count -eq 1) {
    Invoke-Expression $fn[0].Extent.Text      # PRIMERO la funcion de verdad...

    # ...y AHORA los dobles, que si no los pisaria el archivo al cargarse
    $script:dichos = @()
    function Log([string]$m) { $script:dichos += $m }
    function Get-AvisoEspera { }
    function Add-Estadistica { param($a, $b) }
    $script:guardados = 0
    function Save-AvisoEspera { $script:guardados++ }
    # que NINGUNO quepa, que es la situacion del 24/09: braya no habia llamado a Nova
    function Send-AvisoEntorno { param($c, $t, $n, $cada, $forzar) return $false }

    $script:avisoSueltaDicho = -1
    $script:avisoEspera = New-Object System.Collections.ArrayList
    $manana = (Get-Date).AddDays(1).ToString('o')
    foreach ($k in @('gmail-lleno', 'disco-poco')) {
        [void]$script:avisoEspera.Add(@{ clave = $k; texto = "algo de $k"; nivel = 'medio'; cada = 60; vence = $manana })
    }

    # tres pasadas seguidas con la MISMA situacion, que es lo que hacia el mando
    for ($i = 0; $i -lt 3; $i++) { [void](Send-AvisoEsperaSuelta) }
    $lineas = @($script:dichos | Where-Object { $_ -match 'no cabian ahora' })
    Comp 'tres pasadas iguales dejan UNA sola linea' ($lineas.Count -eq 1) "$($lineas.Count) linea(s) de 3 pasadas"
    Comp 'y la linea dice cuantos quedan' ($lineas.Count -ge 1 -and $lineas[0] -match '2 aviso') "$($lineas[0])"
    Comp 'y los dos avisos siguen en la cola' ($script:avisoEspera.Count -eq 2) "$($script:avisoEspera.Count)"

    # y si el numero CAMBIA, se vuelve a decir: el silencio no puede tapar un cambio real
    $script:dichos = @()
    [void]$script:avisoEspera.RemoveAt(0)
    [void](Send-AvisoEsperaSuelta)
    $lineas2 = @($script:dichos | Where-Object { $_ -match 'no cabian ahora' })
    Comp 'si cambia el numero, vuelve a decirse' ($lineas2.Count -eq 1) "$($lineas2.Count)"
    Comp 'y dice el numero nuevo' ($lineas2.Count -ge 1 -and $lineas2[0] -match '1 aviso') "$($lineas2[0])"

    # y cuando ya no queda ninguno, se calla del todo
    $script:dichos = @()
    $script:avisoEspera.Clear()
    [void]$script:avisoEspera.Add(@{ clave = 'x'; texto = 'x'; nivel = 'medio'; cada = 60; vence = $manana })
    function Send-AvisoEntorno { param($c, $t, $n, $cada, $forzar) return $true }   # ahora SI cabe
    [void](Send-AvisoEsperaSuelta)
    $lineas3 = @($script:dichos | Where-Object { $_ -match 'no cabian ahora' })
    Comp 'cuando salen todos, no dice nada' ($lineas3.Count -eq 0) "$($lineas3.Count)"
    Comp 'y la cola queda vacia' ($script:avisoEspera.Count -eq 0) "$($script:avisoEspera.Count)"
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que espera ya no se reintenta sin parar'
exit 0
