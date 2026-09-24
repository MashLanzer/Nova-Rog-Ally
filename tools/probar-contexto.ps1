# LA MEMORIA ENTRE ORDENES (20/09), y lo que sonaba antes de llamarla.
#
# Lo pidio braya con estas palabras: "no quiero activarla, decirle algo, y que en la
# siguiente orden no sepa de que le hable en la anterior". Se hizo el mismo dia y se
# quedo SIN PRUEBA, que es como se pierden las cosas: la bateria pasaba en verde
# igualmente porque ningun banco la tocaba.
#
# Del log del 18/09, el caso que lo motivo: 20:10:38 "Puedes abrir YouTube y reproducir
# musica" -> se abre; 20 s despues "Con la novena cancion" llega al modelo DESNUDA y
# Nova contesta "No se a que te referis con la novena cancion".
#
# Aqui se prueban las dos mitades: los turnos (lo que os dijisteis) y el ambiente (lo
# que sonaba en la habitacion antes de que la llamaras, que NO es lo mismo y no puede
# presentarse igual: si se le da al modelo como si se lo hubieran dicho a el, contesta
# a una frase que no era suya).
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA (aprendida tres veces el 19/09): toda funcion que se llame aqui TIENE que estar
# en esta lista. Si falta, la prueba corre contra una funcion que no existe y pasa en
# verde sin probar nada (paso con Test-ApiContestaPrimero, un dia entero).
foreach ($fn in @('Add-Turno', 'Get-ContextoTurnos')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

# los numeros de verdad, sacados del archivo (no copiados a mano: si alli cambian, aqui
# cambian solos y la prueba sigue midiendo lo que hay)
$TurnosMax = [int]([regex]::Match($fuente, '(?m)^\$TurnosMax\s*=\s*(\d+)').Groups[1].Value)
$TurnosVidaMs = [int]([regex]::Match($fuente, '(?m)^\$TurnosVidaMs\s*=\s*(\d+)').Groups[1].Value)
Comp 'los topes salen del archivo' (($TurnosMax -ge 1) -and ($TurnosVidaMs -ge 1000)) "$TurnosMax turnos / $TurnosVidaMs ms"

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:invitado = $false
$script:ambienteUltimo = ''
$script:turnos = New-Object System.Collections.ArrayList

Write-Host '-- sin nada, no hay contexto --'
Comp 'vacio de verdad' ((Get-ContextoTurnos) -eq '')

Write-Host '-- los turnos: el caso del log del 18/09 --'
Add-Turno 'Puedes abrir YouTube y reproducir musica' 'abro youtube y la pongo'
$c = Get-ContextoTurnos
Comp 'aparece lo que dijo' ($c.Contains('reproducir musica'))
Comp 'y lo que hizo Nova' ($c.Contains('abro youtube'))
Comp 'le dice al modelo que lo ignore si se entiende solo' ($c.Contains('IGNORA'))

Write-Host '-- la misma frase repetida no crea dos turnos --'
Add-Turno 'Puedes abrir YouTube y reproducir musica' 'ya estaba puesta'
Comp 'sigue habiendo un solo turno' ($script:turnos.Count -eq 1) "$($script:turnos.Count)"

Write-Host '-- nunca mas de los que dice el archivo --'
for ($i = 1; $i -le ($TurnosMax + 3); $i++) { Add-Turno "orden numero $i" "hecho $i" }
Comp "se queda en $TurnosMax" ($script:turnos.Count -eq $TurnosMax) "$($script:turnos.Count)"
Comp 'y son los ultimos, no los primeros' ((Get-ContextoTurnos).Contains("orden numero $($TurnosMax + 3)"))

Write-Host '-- y caducan (no es un modo que se quede puesto) --'
foreach ($t in $script:turnos) { $t.cuando = $sw.ElapsedMilliseconds - $TurnosVidaMs - 1000 }
Comp 'pasado el plazo, no queda contexto' ((Get-ContextoTurnos) -eq '')

Write-Host '-- el ambiente: lo que sonaba antes de llamarla --'
$script:turnos.Clear()
$script:ambienteUltimo = 'estabamos hablando de cambiar la tele del salon'
$c = Get-ContextoTurnos
Comp 'el ambiente solo ya da contexto' ($c -ne '')
Comp 'y trae lo que sonaba' ($c.Contains('cambiar la tele'))
Comp 'DICE que no se lo decian a el' ($c.Contains('NO se lo decian'))

Write-Host '-- con turnos, el ambiente va el primero (es lo mas viejo) --'
Add-Turno 'ponme musica' 'la pongo'
$c = Get-ContextoTurnos
Comp 'sale el ambiente antes que el turno' ($c.IndexOf('cambiar la tele') -lt $c.IndexOf('ponme musica'))

Write-Host '-- un ambiente largo se recorta, y se queda con el FINAL --'
$script:ambienteUltimo = ('viejo ' * 100) + 'ESTO ES LO ULTIMO QUE SE DIJO'
$c = Get-ContextoTurnos
Comp 'se queda lo ultimo, que es lo que importa' ($c.Contains('ESTO ES LO ULTIMO QUE SE DIJO'))
$linea = @($c -split "`n" | Where-Object { $_.Contains('sonaba esto cerca') })[0]
Comp 'y la linea no se desmadra' ($linea.Length -lt 340) "$($linea.Length) caracteres"

Write-Host '-- con un invitado delante, Nova no arrastra NADA --'
$script:invitado = $true
Comp 'ni turnos ni ambiente' ((Get-ContextoTurnos) -eq '')
$script:invitado = $false

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  la memoria entre ordenes se acuerda, caduca, y el ambiente va aparte y etiquetado'
exit 0
