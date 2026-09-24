# QUE NOVA DIGA SI ARRANCO A MEDIAS (17/09).
#
# Nova ya comprobaba sus piezas al arrancar -si falta wake_vosk.py, nova_ui.exe,
# commands.json o el CLI del agente- pero todas esas comprobaciones morian en el log, donde
# nadie las ve: arrancaba a medias, saludaba "Listo" igual, y el fallo se descubria a la
# primera orden que no funcionaba.
#
# Esto NO anadio comprobaciones nuevas: recoge las que ya habia y las cuenta en el saludo,
# que existe justo para eso ("confirma que la voz funciona").
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
Invoke-Expression (Traer 'Add-FalloArranque')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- la lista de lo que no arranco --'
$script:fallosArranque = New-Object System.Collections.ArrayList
Comp 'empieza vacia' ($script:fallosArranque.Count -eq 0) ''
Add-FalloArranque 'me falta la capsula'
Comp 'apunta un fallo' ($script:fallosArranque.Count -eq 1) ''
Add-FalloArranque 'me falta la capsula'
Comp 'y no lo apunta dos veces' ($script:fallosArranque.Count -eq 1) ("van " + $script:fallosArranque.Count)
Add-FalloArranque ''
Comp 'un fallo vacio no cuenta' ($script:fallosArranque.Count -eq 1) ''
Add-FalloArranque 'no encuentro el agente'
Comp 'otro distinto si' ($script:fallosArranque.Count -eq 2) ''

# --- la frase que se dice, montada igual que en el arranque ---
function Frase($lista) {
    if ($lista.Count -eq 0) { return 'Listo. Di nova cuando me necesites.' }
    $t = if ($lista.Count -eq 1) { $lista[0] }
         else { ($lista[0..($lista.Count - 2)] -join ', ') + ' y ' + $lista[-1] }
    return "Listo, pero arranque a medias: $t."
}
Write-Host '  -- y como suena --'
Comp 'sin fallos, el saludo de siempre' ((Frase @()) -notmatch 'a medias') ("'" + (Frase @()) + "'")
Comp 'con uno, se dice ese' ((Frase @('me falta la capsula')) -eq 'Listo, pero arranque a medias: me falta la capsula.') ("'" + (Frase @('me falta la capsula')) + "'")
$dos = Frase @('me falta la capsula', 'no encuentro el agente')
Comp 'con dos, se unen con "y"' ($dos -match 'capsula y no encuentro') ("'" + $dos + "'")
$tres = Frase @('a', 'b', 'c')
Comp 'con tres, comas y la ultima con "y"' ($tres -match 'a, b y c') ("'" + $tres + "'")

# --- y que el enganche siga puesto en el codigo real ---
Write-Host '  -- y las comprobaciones que ya existian lo apuntan --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
foreach ($par in @(
    @('falta wake_vosk.py', 'la palabra de activacion'),
    @('falta nova_ui.exe', 'la capsula'),
    @('no hay commands.json', 'la lista de ordenes'),
    @('opencode CLI no encontrado', 'el agente'),
    @('voz no disponible', 'la voz'))) {
    # TODAS las apariciones, no la primera: algunos de estos textos salen tambien en un
    # comentario, y mirar solo la primera daba un rojo falso (17/09).
    $ok = $false
    $i = $txt.IndexOf($par[0])
    while ($i -ge 0) {
        $trozo = $txt.Substring($i, [Math]::Min(320, $txt.Length - $i))
        if ($trozo -match 'Add-FalloArranque') { $ok = $true; break }
        $i = $txt.IndexOf($par[0], $i + 1)
    }
    Comp ("se apunta cuando falla " + $par[1]) $ok ''
}
Comp 'y el saludo lo dice' ($txt -match 'arranque a medias') ''
Comp 'y queda en las estadisticas' ($txt -match "Add-Estadistica 'arranque-medias'") ''

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
