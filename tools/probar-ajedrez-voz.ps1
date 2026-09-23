# EL PUENTE DEL AJEDREZ: que una frase de braya llegue a la partida, y que una orden normal NO
# (23/09, lo pidio braya).
#
# Lo que se prueba aqui es la TRIPLE LLAVE de Invoke-Ajedrez, que es lo unico que puede
# hacerle daño: (a) sin partida abierta no se mira nada, (b) la frase tiene que tener FORMA de
# jugada con el patron anclado, y (c) python-chess la valida contra las legales. Si falla
# cualquiera, la frase sigue su camino de siempre.
#
# El ajedrez en si -reglas, legalidad, el motor- se prueba en tools\probar-ajedrez.py; aqui
# solo el enganche.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}

# --- dependencias: nada de llamar a Python de verdad, se sustituye el puente ---
$AjedrezOn = $true
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('aj-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
function Log($m) { }
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Test-AjedrezAbierta')
Invoke-Expression (Traer 'Invoke-Ajedrez')
# el puente se sustituye para no arrancar Python en cada caso: lo que interesa aqui es QUE
# argumentos se le mandan, no lo que contesta (eso ya se prueba en probar-ajedrez.py).
$script:llamadas = @()
function Invoke-AjedrezPy([string[]]$args2) {
    $script:llamadas += ($args2 -join ' ')
    return [pscustomobject]@{ decir = 'vale'; hay_partida = $true; opciones = @(); fin = $false }
}

function Pide([string]$f) { $script:llamadas = @(); return (Invoke-Ajedrez $f) }

Write-Host ''
Write-Host '-- sin partida abierta, NADA pasa por aqui --'
$script:ajedrezActiva = $false
foreach ($f in @('caballo foxtrot tres', 'peon echo cuatro', 'retira esa', 'por donde vamos')) {
    $r = Pide $f
    Comp ("'" + $f + "' se va por su camino") ($null -eq $r -and $script:llamadas.Count -eq 0)
}

Write-Host ''
Write-Host '-- empezar se reconoce siempre --'
foreach ($f in @('juguemos al ajedrez', 'juega ajedrez conmigo', 'una partida de ajedrez', 'ajedrez a ciegas')) {
    $r = Pide $f
    Comp ("'" + $f + "'") ($null -ne $r -and $script:llamadas -contains '--empezar')
}

Write-Host ''
Write-Host '-- con partida abierta, una jugada llega --'
$script:ajedrezActiva = $true
foreach ($f in @('caballo foxtrot tres', 'peon echo cuatro', 'echo cuatro', 'torre alfa seis',
                 'caballo a foxtrot tres', 'alfil come en delta cinco', 'enroque corto')) {
    $r = Pide $f
    Comp ("'" + $f + "' llega a la partida") ($script:llamadas.Count -eq 1 -and $script:llamadas[0] -like '--dicho *')
}

Write-Host ''
Write-Host '-- y una ORDEN NORMAL no, aunque haya partida --'
# Estas son ordenes de verdad del log de braya. Es la regla de la casa: tolera que no le
# entienda, no tolera que haga algo que no pidio.
foreach ($f in @('sube el volumen', 'abre steam', 'que hora es', 'cierra el navegador',
                 'pon el modo juego', 'abre la calculadora', 'baja el brillo a la mitad',
                 'cuanta bateria queda', 'no me hables por 10 minutos')) {
    $r = Pide $f
    Comp ("'" + $f + "' NO toca el tablero") ($null -eq $r -and $script:llamadas.Count -eq 0)
}

Write-Host ''
Write-Host '-- las salidas, que es lo que braya exige de cualquier modo --'
foreach ($par in @(@('dejamos la partida', '--cerrar'), @('abandono', '--cerrar'),
                   @('me rindo', '--cerrar'), @('deja el ajedrez', '--cerrar'),
                   @('retira esa', '--deshacer'), @('deshaz', '--deshacer'),
                   @('por donde vamos', '--estado'))) {
    # OJO: la rama de cerrar apaga la partida, asi que hay que volver a abrirla en cada caso.
    # Sin esto, el primer '--cerrar' dejaba $ajedrezActiva en $false y los cinco casos
    # siguientes salian rojos... con el codigo bien.
    $script:ajedrezActiva = $true
    $r = Pide $par[0]
    Comp ("'" + $par[0] + "' -> " + $par[1]) ($script:llamadas.Count -eq 1 -and $script:llamadas[0] -like ($par[1] + '*'))
}
$script:ajedrezActiva = $true
[void](Pide 'abandono')
Comp 'y al cerrar, la partida deja de estar abierta' (-not $script:ajedrezActiva) 'sin esto seguiria capturando frases'

Write-Host ''
Write-Host '-- contestar a la pregunta de las dos parecidas --'
$script:ajedrezActiva = $true
[void](Pide 'la primera'); Comp "'la primera' elige la 1" ($script:llamadas[0] -eq '--elegir 1')
[void](Pide 'el segundo'); Comp "'el segundo' elige la 2" ($script:llamadas[0] -eq '--elegir 2')

Write-Host ''
Write-Host '-- y donde esta enganchado --'
Comp 'va en Process-Texto, antes del camino local' ($fuente -match '(?s)\$aj = Invoke-Ajedrez \$text.{0,700}# 1\) local instantaneo') ''
Comp 'y NO dentro de Invoke-FastCommand' (-not ($fuente -match '(?s)function Invoke-FastCommand.{0,4000}Invoke-Ajedrez')) 'a esa la llaman reglas y perfiles, no braya'
Comp 'se puede apagar desde config' ($fuente -match "Get-Cfg 'juego' 'ajedrez'")
Comp 'y el turno se lanza por proceso, no residente' ($fuente -match '& \$PyExe \$AjedrezPy')

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  la jugada llega a la partida, y la orden sigue siendo una orden'
exit 0
