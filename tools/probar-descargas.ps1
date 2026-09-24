# Reglas atadas a una descarga de Steam, del archivo real.
# Dos cosas pueden salir mal y las dos se comprueban aquí:
#   1. "cuando termine de descargarse X" encaja TAMBIÉN con la regla de cerrar
#      un juego ("cuando termine X"), así que si el orden se cambia, la de la
#      descarga deja de existir sin que nadie se entere.
#   2. El disparo va por FLANCO (bajando -> ya no bajando). Si mirara solo
#      "está instalado", cada juego instalado dispararía la regla en cada
#      vuelta del bucle, es decir, cada minuto, para siempre.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
# el MISMO $VERBOS del archivo real: una copia a mano se queda vieja
$VERBOS = ($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left.Extent.Text -eq '$VERBOS' }, $true)).Right.Extent.Text.Trim("'")

$script:reglas = New-Object System.Collections.ArrayList
# la coma no es un adorno: sin ella PowerShell ENUMERA la lista y, vacia,
# devuelve $null, con lo que la funcion de verdad reventaba al anadir
function Get-Reglas { return ,$script:reglas }
function Save-Reglas { }
function Log($m) { }
function Add-Estadistica($a, $b) { }
function Send-UIEvento($e) { }
function Say($t) { $script:dicho += @($t) }
function Test-FastCommand($t) { return $true }   # aquí se prueba la CONDICIÓN
function Invoke-FastCommand($t) { $script:ejecutado += @($t); return "ok" }
$script:juegosDeMentira = @('ELDEN RING', 'OUTLAST 2')
function Find-Juego($t) {
    foreach ($j in $script:juegosDeMentira) {
        if ((ConvertTo-Plain $j) -eq (ConvertTo-Plain $t)) { return @{ nombre = $j } }
    }
    return $null
}
$script:confirmado = $false
# LA TRAJO OTRA IDEA Y ESTE BANCO NO SE ENTERO (24/09): sin ella moria a mitad, y
# encima salia con codigo 0. Lo vio la trampa nueva, no una persona.
# ConvertTo-Digitos necesita su tabla de numeros, que ocupa varias lineas del fuente
$txtFuenteD = [System.IO.File]::ReadAllText($ruta)
$mN = [regex]::Match($txtFuenteD, '(?ms)^\$NumerosPalabra = (@\{.*?^\})')
if (-not $mN.Success) { throw 'no encuentro $NumerosPalabra' }
$NumerosPalabra = Invoke-Expression $mN.Groups[1].Value
Invoke-Expression (Traer 'ConvertTo-Digitos')
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Write-Atomico')
Invoke-Expression (Traer 'Describe-Regla')
# desde la idea 5 (reglas sobre apps) Invoke-ReglaVoz decide app o juego con
# Resolve-SujetoRegla; sin commands.json cargado, Resolve-Proceso sale sin mas
Invoke-Expression (Traer 'Resolve-Proceso')
Invoke-Expression (Traer 'Resolve-SujetoRegla')
Invoke-Expression (Traer 'Invoke-ReglaVoz')
Invoke-Expression (Traer 'Invoke-Reglas')

$fallos = 0
function Comp($etiqueta, $ok, $detalle) {
    Write-Host ("  {0}  {1,-40} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# --- crear la regla ---
$r1 = Invoke-ReglaVoz 'cuando termine de descargarse elden ring abrelo'
$re = @($script:reglas)[-1]
Comp 'se crea la regla' ($r1 -and $re.tipo -eq 'descarga') "tipo=$($re.tipo)"
Comp 'con el juego bien resuelto' ($re.valor -eq 'ELDEN RING') "valor='$($re.valor)'"
Comp '"abrelo" se traduce al juego' ($re.accion -eq 'abre ELDEN RING') "accion='$($re.accion)'"

# --- y NO le roba la suya a "cuando termine X" (cerrar un juego) ---
$null = Invoke-ReglaVoz 'cuando termine outlast 2 pon modo noche'
$re2 = @($script:reglas)[-1]
Comp 'cerrar un juego sigue siendo cerrar' ($re2.tipo -eq 'juegoCierra') "tipo=$($re2.tipo)"

# --- una descarga sin nombre vale, y es "cualquiera" ---
$null = Invoke-ReglaVoz 'cuando termine de bajarse un juego avisame'
$re3 = @($script:reglas)[-1]
Comp 'sin nombre, vale cualquier descarga' ($re3.tipo -eq 'descarga' -and -not $re3.valor) "valor='$($re3.valor)'"

# --- "abrelo" sin juego no se puede resolver, y se dice ---
$script:reglas.Clear()
$r4 = Invoke-ReglaVoz 'cuando termine de bajarse un juego abrelo'
Comp '"abrelo" sin nombre lo avisa' (($r4 -match 'que juego') -and $script:reglas.Count -eq 0) ''

# --- el disparo ---
$script:reglas.Clear()
$null = Invoke-ReglaVoz 'cuando termine de descargarse elden ring abrelo'
$script:ejecutado = @(); $script:dicho = @()
Invoke-Reglas 'descarga' 'OUTLAST 2'
Comp 'otro juego no la dispara' ($script:ejecutado.Count -eq 0) ''
Invoke-Reglas 'descarga' 'ELDEN RING'
Comp 'el suyo si la dispara' ($script:ejecutado.Count -eq 1 -and $script:ejecutado[0] -eq 'abre ELDEN RING') ("[" + ($script:ejecutado -join '|') + "]")

# --- LOS SENSORES DE LAS 31 IDEAS, YA ENGANCHABLES (16/09, fase 3) ---
# Nova se enteraba de todo esto pero solo lo decia: no se le podia colgar nada.
# Cada tipo nuevo tiene que estar en CINCO sitios, y si falta uno falla EN SILENCIO:
# el patron (no se crea), el switch de "avisame" (nace muerta), Describe-Regla (recita
# el nombre tecnico), el switch de Invoke-Reglas (se guarda y no dispara jamas) y el
# sensor. Aqui se comprueban los cuatro primeros de un tiron.
$nuevas = @(
    @{ frase = 'cuando quite el dock pon el modo bateria'; tipo = 'dockQuita'; dato = 'quita' }
    @{ frase = 'cuando me quite los cascos pon el volumen al 30'; tipo = 'cascosQuita'; dato = 'quita' }
    @{ frase = 'cuando termine de cargar pon el modo trabajo'; tipo = 'bateriaLlena'; dato = 'llena' }
    @{ frase = 'cuando coja el mando pon el modo juego'; tipo = 'mandoCoge'; dato = 'coge' }
    @{ frase = 'cuando conecte el disco de los juegos abre steam'; tipo = 'discoJuegos'; dato = 'pone' }
)
foreach ($n in $nuevas) {
    $script:reglas.Clear()
    $null = Invoke-ReglaVoz $n.frase
    $rN = @($script:reglas)[-1]
    Comp "se crea: $($n.frase)" ($rN -and $rN.tipo -eq $n.tipo) "tipo=$($rN.tipo)"
    $desc = Describe-Regla $rN
    Comp "  y sabe decirla en cristiano" ($desc -notmatch [regex]::Escape($n.tipo)) "$desc"
    $script:ejecutado = @(); $script:dicho = @()
    Invoke-Reglas $n.tipo $n.dato
    Comp "  y dispara de verdad" ($script:ejecutado.Count -eq 1) ("[" + ($script:ejecutado -join '|') + "]")
    $script:ejecutado = @()
    Invoke-Reglas $n.tipo 'otracosa'
    Comp "  pero no con otro dato" ($script:ejecutado.Count -eq 0) ("[" + ($script:ejecutado -join '|') + "]")
}
# "avisame" a secas no es ejecutable: tiene que convertirse en algo que DECIR
$script:reglas.Clear()
$null = Invoke-ReglaVoz 'cuando termine de cargar avisame'
$rAv = @($script:reglas)[-1]
Comp 'avisame se convierte en algo que decir' ($rAv -and $rAv.accion -match '^di\s+\S') "accion='$($rAv.accion)'"
# quitar el disco y conectarlo son cosas distintas
$script:reglas.Clear()
$null = Invoke-ReglaVoz 'cuando quite el disco de los juegos di adios'
$rQ = @($script:reglas)[-1]
Comp 'quitar el disco se guarda como quita' ($rQ.tipo -eq 'discoJuegos' -and $rQ.valor -eq 'quita') "valor='$($rQ.valor)'"
$script:ejecutado = @()
Invoke-Reglas 'discoJuegos' 'pone'
Comp 'y NO salta al conectarlo' ($script:ejecutado.Count -eq 0) ("[" + ($script:ejecutado -join '|') + "]")

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
