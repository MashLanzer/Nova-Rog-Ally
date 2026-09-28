# ¿SE ABRIO LO QUE MANDE ABRIR? (18/09) — NOVA-LLM, pieza 1 (2/2).
#
# Abrir es la orden estrella: 61 de las ejecutadas en el registro son "-> abrir" (Steam 12
# veces, la calculadora 8, Spotify, el bloc de notas, Elden Ring). Y hasta hoy Nova mandaba
# abrir y daba por hecho que se abrio: si Steam no arrancaba, ella decia "Abre Steam" igual.
#
# POR QUE ES DIFERIDO. Medido: una app tarda 298 ms en aparecer como proceso y ~800 ms en tener
# ventana. Comprobar en el acto daria un "no se abrio" falso SIEMPRE, y esperar 800 ms dentro
# del bucle se pagaria en velocidad, que es la prioridad de braya. Por eso se apunta y se mira
# despues, sin bloquear.
#
# Lo que mas se comprueba aqui, igual que en probar-efecto.ps1, es que NO SE INVENTE FALLOS:
# un juego, una app que ya estaba abierta o una que no se sabe resolver NO se vigilan.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}

# --- el mundo de mentira ---
$script:reloj = 0
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$AperturaPlazoMs = 10000
$script:aperturas = New-Object System.Collections.ArrayList
$script:vivos = @()           # procesos que "existen" ahora mismo
$script:apuntado = @()
$script:dicho = @()
function Log($m) { $script:dicho += $m }
function Add-Estadistica($ruta, $detalle = '') { $script:apuntado += "$ruta|$detalle" }
function Get-Process {
    param([string]$Name, $ErrorAction)
    if ($script:vivos -contains $Name) { return @([PSCustomObject]@{ Name = $Name }) }
    return @()
}
# Resolve-Proceso de mentira: el de verdad mira commands.json y PROCESOS_URI
$script:mapa = @{ 'steam' = 'steam'; 'calculadora' = 'CalculatorApp'; 'bloc de notas' = 'notepad' }
function Resolve-Proceso([string]$t) {
    if ($t -eq 'ELDEN RING') { return @{ proceso = '*juego*'; nombre = 'ELDEN RING' } }
    if ($script:mapa.ContainsKey($t)) { return @{ proceso = $script:mapa[$t]; nombre = $t } }
    return $null
}

Invoke-Expression (Traer 'Add-AperturaPendiente')
Invoke-Expression (Traer 'Test-AperturasPendientes')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
function Reiniciar {
    $script:aperturas.Clear(); $script:vivos = @(); $script:apuntado = @(); $script:dicho = @(); $script:reloj = 0
}

Write-Host '  -- lo que SI se vigila --'
Reiniciar
Comp 'una app conocida y cerrada se apunta' (Add-AperturaPendiente 'steam') ''
Comp 'y queda una en la lista' ($script:aperturas.Count -eq 1) "hay $($script:aperturas.Count)"

Write-Host '  -- y si se abre, se quita sin decir nada (lo normal) --'
$script:vivos = @('steam')
$script:reloj = 3000
$avisos = Test-AperturasPendientes
Comp 'no avisa de nada' ($avisos.Count -eq 0) ''
Comp 'y deja de vigilarla' ($script:aperturas.Count -eq 0) ''
Comp 'sin apuntar ningun fallo' ($script:apuntado.Count -eq 0) ''

Write-Host '  -- EL CASO QUE IMPORTA: se mando abrir y no aparece --'
Reiniciar
[void](Add-AperturaPendiente 'steam')
$script:reloj = 3000
Comp 'a los 3 s todavia no se queja (aun puede tardar)' ((Test-AperturasPendientes).Count -eq 0) ''
Comp 'y la sigue vigilando' ($script:aperturas.Count -eq 1) ''
$script:reloj = 11000
$avisos = Test-AperturasPendientes
Comp 'pasado el plazo, lo dice' ($avisos.Count -eq 1) ($avisos -join ' ')
Comp 'y lo dice en cristiano' (($avisos -join ' ') -match 'mande abrir steam y no se ha abierto') ''
Comp 'lo apunta para poder medirlo' ((($script:apuntado -join ' ') -match 'no-surtio-efecto')) ($script:apuntado -join ' ')
Comp 'y deja de vigilarla (no repite el aviso)' ($script:aperturas.Count -eq 0) ''
$script:reloj = 20000
Comp 'a la vuelta siguiente ya no dice nada' ((Test-AperturasPendientes).Count -eq 0) ''

Write-Host '  -- y CALLA cuando no debe opinar --'
Reiniciar
$script:vivos = @('steam')
Comp 'si YA estaba abierta, no se vigila' (-not (Add-AperturaPendiente 'steam')) ''
Comp 'y no queda nada en la lista' ($script:aperturas.Count -eq 0) ''
Reiniciar
Comp 'un juego NO se vigila (tarda y no deja proceso)' (-not (Add-AperturaPendiente 'ELDEN RING')) ''
Comp 'una app que no sabe resolver, tampoco' (-not (Add-AperturaPendiente 'cosa rara')) ''
Comp 'ni una vacia' (-not (Add-AperturaPendiente '')) ''
Comp 'y la lista sigue vacia' ($script:aperturas.Count -eq 0) ''

Write-Host '  -- varias a la vez, cada una por su lado --'
Reiniciar
[void](Add-AperturaPendiente 'steam')
[void](Add-AperturaPendiente 'calculadora')
Comp 'se vigilan las dos' ($script:aperturas.Count -eq 2) ''
$script:vivos = @('CalculatorApp')
$script:reloj = 11000
$avisos = Test-AperturasPendientes
Comp 'solo se queja de la que no se abrio' ($avisos.Count -eq 1 -and ($avisos -join ' ') -match 'steam') ($avisos -join ' ')
Comp 'y no queda ninguna vigilada' ($script:aperturas.Count -eq 0) ''

Write-Host '  -- sin nada apuntado, no hace trabajo --'
Reiniciar
Comp 'lista vacia: devuelve vacio' ((Test-AperturasPendientes).Count -eq 0) ''

# --- y que el codigo real lo use ---
Write-Host '  -- y el ejecutor y el bucle lo usan --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
Comp 'al abrir una app se apunta' ($txt -match 'Add-AperturaPendiente \$comoSeLlama') ''
# ACTUALIZADO 27/09 (idea 81): antes esto era "if (-not $esJuego) { [void](Add-AperturaPendiente".
# Los juegos ya SI se vigilan, pero por su propia lista (Add-JuegoPedido), porque no se mira un
# nombre de proceso sino el detector de juegos. La intencion no cambia -una apertura pendiente
# solo se apunta si NO es un juego- y se sigue exigiendo igual de fuerte: que la llamada viva en
# la rama ELSE del if ($esJuego), no suelta por ahi.
Comp 'y solo si NO es un juego' ($txt -match 'if \(\$esJuego\) \{ \[void\]\(Add-JuegoPedido \$comoSeLlama\) \}\s*else \{ \[void\]\(Add-AperturaPendiente \$comoSeLlama\) \}') ''
Comp 'el bucle lo revisa' ($txt -match 'foreach \(\$avisoAp in \(Test-AperturasPendientes\)\)') ''
# que no cueste nada cuando no hay nada que mirar, que es el 99 % del tiempo
# ACTUALIZADO 27/09 (idea 81): la guarda era "$script:aperturas.Count -gt 0 -and"; ahora el
# bucle tambien despierta por los juegos pedidos, asi que es "($script:aperturas.Count -gt 0 -or
# $script:juegosPedidos.Count -gt 0) -and". Y de paso se deja de buscar la cadena suelta en las
# 36.800 lineas (manera 17 de salir verde mintiendo: una cadena que aparece en otro sitio): se
# coge por AST el if MAS INTERNO que envuelve la llamada real y se mira SU condicion, que es la
# que de verdad decide si se hace el trabajo.
$ifsAp = @(@($ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.IfStatementAst] -and $x.Extent.Text -match 'foreach \(\$avisoAp in \(Test-AperturasPendientes\)\)' }, $true)) |
    Sort-Object { $_.Extent.EndOffset - $_.Extent.StartOffset })
$condAp = ''
if ($ifsAp.Count -gt 0) { $condAp = ($ifsAp[0].Clauses[0].Item1.Extent.Text -replace '\s+', ' ') }
Comp 'y solo si hay algo apuntado' ($condAp -match '\$script:aperturas\.Count -gt 0') $condAp
Comp 'sin bloquear el bucle (nada de Start-Sleep)' ($txt -notmatch 'Add-AperturaPendiente[\s\S]{0,400}Start-Sleep') ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
