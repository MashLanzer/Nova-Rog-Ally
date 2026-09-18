# TAREAS SIN EL AGENTE (16/09): el PLAN de ordenes locales.
#
# El 15/09, las 20 llamadas al agente costaron 11,6 min (el 23 % de toda la espera).
# Mirandolas una a una, la mayoria eran dos o tres ordenes que Nova ya sabe hacer dichas
# de una vez. Ahora, antes de llamar al agente, la API las descompone en ordenes del
# vocabulario local; aqui se comprueba que esa lista se lee bien y, sobre todo, que se
# RECHAZA entera en cuanto algo no encaja: es preferible esperar al agente que hacer
# tres cosas que nadie pidio.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Split-Plan')

# --- y el ejecutor, que hasta hoy no se probaba (18/09) ---
# El vocabulario de mentira: lo que Nova sabe hacer y lo que arma confirmacion. "cierra todos
# los programas" y "abre <juego> en steam" son de verdad dos de las siete puertas que ponen
# $script:pendiente y estan en el vocabulario que se le ofrece al modelo del plan.
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:pendiente = $null
$script:ultimaOrden = $null
$script:ultimaRespuesta = ''
$script:dicho = @()
$script:alAgente = @()
$script:eventos = @()
$VOCAB = @{
    'abre steam'                 = 'abrir steam'
    'sube el brillo'             = 'subir brillo'
    'pon el modo juego'          = 'modo juego'
    'abre la calculadora'        = 'abrir calculadora'
    'cierra todos los programas' = '¿Cierro todo?'      # esta ARMA confirmacion
    'pon un temporizador'        = '¿De cuanto lo pongo?' # y esta tambien
}
$CONFIRMA = @('cierra todos los programas', 'pon un temporizador')
$script:rota = ''      # una orden que se reconoce pero falla al ejecutarse
function Log($m) { }
function Add-Estadistica($a, $b) { }
function Say($t) { $script:dicho += $t }
function Show-Popup($t, $e = '') { }
function Send-UIEvento($e) { $script:eventos += $e }
function Submit-Command($t, $modo = 'accion', $adj = '') { $script:alAgente += $t }
function Test-FastCommand($t) { return $VOCAB.ContainsKey([string]$t) }
function Invoke-FastCommand($t) {
    $t = [string]$t
    if ($t -eq $script:rota) { return $null }
    if ($CONFIRMA -contains $t) {
        # lo que hace de verdad: devuelve LA PREGUNTA como si fuera un resultado y deja la
        # confirmacion a medias, sin que nadie llame a Start-Confirmacion
        $script:pendiente = @{ tipo = 'peligrosa'; texto = $t; vence = 0 }
        return $VOCAB[$t]
    }
    if ($VOCAB.ContainsKey($t)) { return $VOCAB[$t] }
    return $null
}
Invoke-Expression (Traer 'Invoke-PlanLocal')
function ResetP {
    $script:pendiente = $null; $script:dicho = @(); $script:alAgente = @()
    $script:eventos = @(); $script:rota = ''; $script:ultimaRespuesta = ''
}

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host "  -- planes que valen --"
$p1 = @(Split-Plan "cierra todos los programas`npon el modo juego")
Comp 'dos ordenes, una por linea' ($p1.Count -eq 2 -and $p1[0] -eq 'cierra todos los programas' -and $p1[1] -eq 'pon el modo juego') ($p1 -join ' | ')
$p2 = @(Split-Plan "1. abre youtube`n2. pon pitbull en youtube")
Comp 'se le quitan los numeros' ($p2.Count -eq 2 -and $p2[0] -eq 'abre youtube') ($p2 -join ' | ')
$p3 = @(Split-Plan "- abre steam`n- abre discord")
Comp 'y los guiones' ($p3.Count -eq 2 -and $p3[0] -eq 'abre steam') ($p3 -join ' | ')
$p4 = @(Split-Plan '"abre spotify"')
Comp 'y las comillas' ($p4.Count -eq 1 -and $p4[0] -eq 'abre spotify') ($p4 -join ' | ')

Write-Host "  -- planes que NO valen (van al agente) --"
Comp 'cuando dice que no se puede' ((@(Split-Plan "NO SE PUEDE")).Count -eq 0) ''
Comp 'aunque lo diga en minusculas' ((@(Split-Plan "no se puede hacer con esas ordenes")).Count -eq 0) ''
Comp 'si queda un hueco sin rellenar' ((@(Split-Plan "abre steam`npon el volumen al <n>")).Count -eq 0) ''
$seis = ((1..6 | ForEach-Object { 'abre steam' }) -join "`n")
Comp 'si son mas de cinco pasos' ((@(Split-Plan $seis)).Count -eq 0) ''
Comp 'si no devuelve nada' ((@(Split-Plan '')).Count -eq 0 -and (@(Split-Plan "`n  `n")).Count -eq 0) ''

Write-Host "  -- y ahora EJECUTARLO, que es donde estaba el agujero --"
ResetP
$r1 = Invoke-PlanLocal @('abre steam', 'sube el brillo') 'abre steam y sube el brillo'
Comp 'un plan entero se hace entero' ($r1 -and $script:ultimaRespuesta -eq 'abrir steam, subir brillo') $script:ultimaRespuesta
Comp 'y no molesta al agente' ($script:alAgente.Count -eq 0) ($script:alAgente -join ' | ')

ResetP
$r2 = Invoke-PlanLocal @('abre steam', 'baila un vals') 'abre steam y baila un vals'
Comp 'si una sola orden no vale, NO se hace nada' ((-not $r2) -and $script:dicho.Count -eq 0) ($script:dicho -join ' | ')
Comp 'y la peticion entera va al agente' ($script:alAgente -contains 'abre steam y baila un vals') ($script:alAgente -join ' | ')

Write-Host "  -- una orden que pide confirmacion corta el plan (18/09) --"
# El plan era el unico ejecutor que no miraba $script:pendiente. Invoke-FastCommand devuelve
# la PREGUNTA como si fuera un resultado: sin la guarda, "¿Cierro todo?" se contaba como
# hecho, el plan seguia tan contento y la confirmacion se quedaba colgada con vence=0.
ResetP
$r3 = Invoke-PlanLocal @('abre steam', 'cierra todos los programas', 'pon el modo juego') 'abre steam, cierra todo y pon el modo juego'
Comp 'el plan se abandona' (-not $r3) ''
Comp 'la pregunta NO cuenta como hecha' ($script:dicho.Count -eq 1 -and $script:dicho[0] -eq 'abrir steam. Lo demas lo miro.') ($script:dicho -join ' | ')
Comp 'y no se queda una confirmacion colgando' ($null -eq $script:pendiente) ''
Comp 'al agente va lo que QUEDA, no lo ya hecho' ($script:alAgente -contains 'cierra todos los programas y pon el modo juego') ($script:alAgente -join ' | ')
# los parentesis importan: sin ellos el -not se come el -join y se compara $false, que
# encaja con cualquier cosa y deja el caso en verde sin mirar nada
Comp 'y sobre todo NO se reenvia lo que ya se hizo' (-not (($script:alAgente -join ' ') -like '*abre steam*')) ($script:alAgente -join ' | ')

ResetP
$r4 = Invoke-PlanLocal @('pon un temporizador', 'abre steam') 'pon un temporizador y abre steam'
Comp 'si la confirmacion es la primera, no dice nada de lo hecho' ((-not $r4) -and $script:dicho.Count -eq 0) ($script:dicho -join ' | ')
Comp 'y va entero al agente' ($script:alAgente -contains 'pon un temporizador y abre steam') ($script:alAgente -join ' | ')

Write-Host "  -- y si una falla a mitad, solo se reenvia lo que falta --"
ResetP
$script:rota = 'sube el brillo'
$r5 = Invoke-PlanLocal @('abre steam', 'sube el brillo', 'pon el modo juego') 'abre steam, sube el brillo y pon el modo juego'
Comp 'se cuenta lo que si se hizo' ((-not $r5) -and $script:dicho[0] -eq 'abrir steam. Lo demas lo miro.') ($script:dicho -join ' | ')
Comp 'y al agente solo lo que queda' ($script:alAgente -contains 'sube el brillo y pon el modo juego') ($script:alAgente -join ' | ')

Write-Host ""
if ($fallos -gt 0) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host "todo correcto" -ForegroundColor Green
