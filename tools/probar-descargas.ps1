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
$txtFuenteD = [System.IO.File]::ReadAllText($ruta)
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
Write-Host "-- EL FLANCO QUE HOY MIENTE (23/09, idea 3) --"
# HOY la unica condicion es "ya no esta bajando", sin mirar si el juego quedo instalado. Por
# eso cancelar la descarga, cerrar Steam o quitar la microSD se cantan como final.
# ESTA EN SU REGISTRO: 15/09 11:26:50 "LOCAL: Cierra la calculadora y cierra Steam" y ONCE
# SEGUNDOS despues, 11:27:01, "DESCARGA terminada: PEAK", con la pausa del microfono detras,
# o sea dicho en voz alta. PEAK se anuncia DOS veces y hoy no esta instalado; de los 15
# avisos del registro, CINCO son de juegos que ya no estan en la biblioteca.
$tmpD = Join-Path $env:TEMP ('desc-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmpD -Force
$MemoriaDir = $tmpD
$DescargasEstadoPath = Join-Path $tmpD 'descargas-estado.json'
$DescargasEstadoHoras = if ($txtFuenteD -match '(?m)^\$DescargasEstadoHoras = (\d+)') { [int]$Matches[1] } else { 12 }
$script:bajandoAntes = $null
$script:descargasArranque = $true
$script:descargasUltimo = ''
$script:logsD = @()
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
Invoke-Expression (Traer 'Get-DescargasEstado')
Invoke-Expression (Traer 'Save-DescargasEstado')
Invoke-Expression (Traer 'Test-DescargasFlanco')

function J([string]$id, [string]$nom, [bool]$baj, [int]$est, [double]$bd, [double]$bt) {
    return @{ id = $id; nombre = $nom; bajando = $baj; estado = $est; descargado = $bd; total = $bt }
}
function ReiniciaD {
    $script:bajandoAntes = $null
    $script:descargasArranque = $true
    $script:descargasUltimo = ''
    try { Remove-Item -LiteralPath $DescargasEstadoPath -Force -ErrorAction SilentlyContinue } catch {}
}

# 1. bajando -> instalado del todo: ese SI termino
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$fin1 = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 1000 1000))
Comp 'un juego que termina de verdad se anuncia' ($fin1.Count -eq 1 -and $fin1[0] -eq 'PEAK') ("[" + ($fin1 -join '|') + "]")
$fin1b = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 1000 1000))
Comp 'y no se repite en la vuelta siguiente' ($fin1b.Count -eq 0) ("[" + ($fin1b -join '|') + "]")

# 2. LA ROTURA DE VERDAD: PEAK desaparece de la biblioteca
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$fin2 = @(Test-DescargasFlanco @((J '9' 'ELDEN RING' $false 4 10 10)))
Comp 'cancelar la descarga NO es terminarla' ($fin2.Count -eq 0) $(if ($fin2.Count) { "anuncio una descarga que no termino: " + ($fin2 -join '|') } else { 'el caso del 15/09 11:27' })

# 3. sigue en la lista pero dejo de bajar sin instalarse (Steam cerrado)
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$fin3 = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 1026 500 1000))
Comp 'cerrar Steam a mitad tampoco' ($fin3.Count -eq 0) ("[" + ($fin3 -join '|') + "]")

# 3b. los bytes completos NO bastan si Steam no lo dejo instalado
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$fin3b = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 1026 1000 1000))
Comp 'con los bytes enteros pero sin instalar, tampoco' ($fin3b.Count -eq 0) ("[" + ($fin3b -join '|') + "]")

# 4. instalado, pero le faltaban bytes
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$fin4 = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 900 1000))
Comp 'ni un manifiesto al que le faltan bytes' ($fin4.Count -eq 0) ("[" + ($fin4 -join '|') + "]")

# 5. una lectura VACIA no borra lo que se sabia
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$fin5 = @(Test-DescargasFlanco @())
Comp 'la biblioteca ilegible no anuncia nada' ($fin5.Count -eq 0) ("[" + ($fin5 -join '|') + "]")
Comp 'y no se lleva por delante lo apuntado' ($script:bajandoAntes -and $script:bajandoAntes.Count -eq 1) "$(if ($script:bajandoAntes) { $script:bajandoAntes.Count } else { 'null' })"
$fin5b = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 1000 1000))
Comp 'asi que la vuelta siguiente si lo ve' ($fin5b.Count -eq 1) ("[" + ($fin5b -join '|') + "]")

# 6. al arrancar, sin nada apuntado, no se inventa un final
ReiniciaD
$fin6 = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 1000 1000))
Comp 'el primer vistazo no anuncia nada' ($fin6.Count -eq 0) ("[" + ($fin6 -join '|') + "]")

# 7. EL AGUJERO B: termino mientras Nova estaba apagada
ReiniciaD
Write-Atomico $DescargasEstadoPath (ConvertTo-Json -InputObject @{ cuando = (Get-Date).AddMinutes(-30).ToString('s'); bajando = @{ '1' = 'PEAK' } } -Depth 3)
$fin7 = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 1000 1000))
Comp 'lo que acabo con Nova apagada, se dice' ($fin7.Count -eq 1 -and $fin7[0] -eq 'PEAK') ("[" + ($fin7 -join '|') + "]")

# 8. pero no lo de anteayer
ReiniciaD
Write-Atomico $DescargasEstadoPath (ConvertTo-Json -InputObject @{ cuando = (Get-Date).AddHours(-20).ToString('s'); bajando = @{ '1' = 'PEAK' } } -Depth 3)
$fin8 = @(Test-DescargasFlanco @(J '1' 'PEAK' $false 4 1000 1000))
Comp 'una noticia de hace 20 horas ya no es noticia' ($fin8.Count -eq 0) ("tope $DescargasEstadoHoras h")

# 9. y con el apagado, tampoco se inventa el que ya no esta
ReiniciaD
Write-Atomico $DescargasEstadoPath (ConvertTo-Json -InputObject @{ cuando = (Get-Date).AddMinutes(-30).ToString('s'); bajando = @{ '1' = 'PEAK' } } -Depth 3)
$fin9 = @(Test-DescargasFlanco @(J '9' 'ELDEN RING' $false 4 10 10))
Comp 'ni aunque venga del disco: si no esta, no termino' ($fin9.Count -eq 0) ("[" + ($fin9 -join '|') + "]")

# 10. dos bajando y termina uno
ReiniciaD
$null = Test-DescargasFlanco @((J '1' 'PEAK' $true 1026 500 1000), (J '2' 'OUTLAST 2' $true 1026 100 1000))
$fin10 = @(Test-DescargasFlanco @((J '1' 'PEAK' $false 4 1000 1000), (J '2' 'OUTLAST 2' $true 1026 300 1000)))
Comp 'de dos que bajan, se anuncia el que acabo' ($fin10.Count -eq 1 -and $fin10[0] -eq 'PEAK') ("[" + ($fin10 -join '|') + "]")
Comp 'y el otro sigue fichado' ($script:bajandoAntes.ContainsKey('2')) "$($script:bajandoAntes.Count)"

# 11. el fichero se escribe solo cuando cambia el conjunto
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
$cuando1 = (Get-Item -LiteralPath $DescargasEstadoPath).LastWriteTime
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 700 1000)
$cuando2 = (Get-Item -LiteralPath $DescargasEstadoPath).LastWriteTime
Comp 'avanzar bytes no reescribe el fichero' ($cuando1 -eq $cuando2) 'cada dos minutos, para siempre, no'

Write-Host ""
Write-Host "-- Y EL BUCLE, SACADO DEL ARBOL Y EJECUTADO --"
# Las reglas de braya ("cuando termine de descargarse X, abrelo") tenian su PROPIO flanco,
# con el mismo fallo, y encima disparaban ACCIONES: cerrar Steam a mitad de una descarga podia
# abrir un juego que nadie pidio. Aqui se comprueba que los dos comen del mismo sitio.
$astD = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
$blqD = ''
foreach ($x in $astD.FindAll({ param($n) $n -is [System.Management.Automation.Language.ForEachStatementAst] }, $true)) {
    if ($x.Extent.Text -match 'Test-DescargasFlanco \$jsD') {
        # SE COGE TAMBIEN LA LINEA DE ENCIMA: ahi se apunta si esta es la primera vuelta del
        # arranque, que es lo que decide con QUE palabras se dice. Sin ella, el banco probaba
        # medio bloque y daba por bueno lo que no habia mirado.
        $antesD = $txtFuenteD.Substring(0, $x.Extent.StartOffset)
        $iPri = $antesD.LastIndexOf('$primeraD = ')
        if ($iPri -lt 0) { throw 'no encuentro donde se apunta la primera vuelta' }
        $blqD = $txtFuenteD.Substring($iPri, $x.Extent.EndOffset - $iPri)
        break
    }
}
if (-not $blqD) { throw 'no encuentro el bucle de las descargas' }
$script:avisado = @()
$script:reglasPedidas = @()
$script:reglasDisparadas = 0
function Send-Aviso([string]$t, [string]$tipo = '') { $script:avisado += $t }
function Invoke-Reglas([string]$tipo, [string]$dato = '') { $script:reglasPedidas += "$tipo|$dato" }
$script:apuntadas = @()
function Add-DescargaHecha([string]$n) { $script:apuntadas += $n }
function CorreBucle($juegos) {
    $script:avisado = @(); $script:reglasPedidas = @(); $script:reglasDisparadas = 0
    $script:apuntadas = @()
    & { $jsD = @($juegos); Invoke-Expression $blqD }
}

ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
CorreBucle @(J '1' 'PEAK' $false 4 1000 1000)
Comp 'el bucle avisa cuando termina de verdad' ($script:avisado.Count -eq 1) ("[" + ($script:avisado -join '|') + "]")
Comp 'y las reglas comen del MISMO flanco' ($script:reglasPedidas.Count -eq 1 -and $script:reglasPedidas[0] -eq 'descarga|PEAK') ("[" + ($script:reglasPedidas -join '|') + "]")
# Y SE APUNTA EN EL HISTORICO (idea 19): el resumen del dia lo lee de ahi, porque la variable
# del flanco se pierde en cada uno de los 16,3 arranques diarios.
Comp 'y queda apuntado para el resumen del dia' ($script:apuntadas.Count -eq 1 -and $script:apuntadas[0] -eq 'PEAK') ("[" + ($script:apuntadas -join '|') + "]")

ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
CorreBucle @(J '9' 'ELDEN RING' $false 4 10 10)
Comp 'y al cancelar no dispara NINGUNA regla' ($script:reglasPedidas.Count -eq 0) $(if ($script:reglasPedidas.Count) { 'abrio un juego que nadie pidio' } else { 'la regla 1, a salvo' })
Comp 'ni dice nada' ($script:avisado.Count -eq 0) ("[" + ($script:avisado -join '|') + "]")

# LO QUE ACABO CON NOVA APAGADA se dice con OTRAS palabras: "ya acabo" de algo que termino
# hace seis horas es inventarse un cuando.
ReiniciaD
Write-Atomico $DescargasEstadoPath (ConvertTo-Json -InputObject @{ cuando = (Get-Date).AddMinutes(-30).ToString('s'); bajando = @{ '1' = 'PEAK' } } -Depth 3)
CorreBucle @(J '1' 'PEAK' $false 4 1000 1000)
Comp 'lo de mientras no estaba se dice distinto' ($script:avisado.Count -eq 1 -and $script:avisado[0] -match 'mientras no estaba') ("[" + ($script:avisado -join '|') + "]")
ReiniciaD
$null = Test-DescargasFlanco @(J '1' 'PEAK' $true 1026 500 1000)
CorreBucle @(J '1' 'PEAK' $false 4 1000 1000)
Comp 'y lo de ahora mismo, como siempre' ($script:avisado.Count -eq 1 -and $script:avisado[0] -match 'ya acabo') ("[" + ($script:avisado -join '|') + "]")

try { Remove-Item -LiteralPath $tmpD -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Host ""
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host "todo correcto"
