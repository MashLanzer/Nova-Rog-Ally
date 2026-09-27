# EL PLAZO PARA DECIR SI, CONTADO Y PUESTO POR ELLA (27/09, idea 102 de las 121)
#
# EL DATO, emparejando cada 'confirmacion: esperando si/no' con su desenlace en los dos registros:
# 24 confirmaciones, TRECE contestadas y once que vencieron sin respuesta. Los trece retrasos, en
# segundos: 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3. LA MAS LENTA, TRES SEGUNDOS. Con el plazo en 4 s
# no se pierde ni una de las trece.
#
# Y SE MIDE DESDE DONDE EL PLAZO EMPIEZA DE VERDAD: desde que el microfono queda libre. Contando
# desde la pregunta parece que el plazo corta por la mitad del reparto -hay un si a los 7 s y una
# muerte a los 7 s-, pero esa cuenta incluye la propia voz de Nova, que el codigo ya descuenta.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que con pocos datos NO se mueva nada: hoy hay 13 y el minimo son 20
#   2. que los vencidos por plazo NUNCA entren como medida (se justificarian a si mismos)
#   3. que el cubo del juego vaya aparte y con su propio techo
#   4. que nunca baje del suelo ni suba del techo
#   5. y que el reloj de la medida se empuje con la voz, igual que el vencimiento
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('Get-ConfirmacionTiempos', 'Add-TiempoRespuesta', 'Get-PlazoConfirmacionMs', 'Get-PlazoConfirmacion')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LAS CONSTANTES SALEN DEL ARCHIVO
function Num([string]$nombre, [int]$porDefecto) {
    $m = [regex]::Match($txt, '(?m)^\$' + $nombre + ' = (\d+)')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $porDefecto
}
$ConfirmacionMs = 6000
$mC = [regex]::Match($txt, "(?m)^\`$ConfirmacionMs = \[int\]\(Get-Cfg 'confirmacion' 'esperaMs' (\d+)\)")
if ($mC.Success) { $ConfirmacionMs = [int]$mC.Groups[1].Value }
$ConfirmacionMax = Num 'ConfirmacionMax' 60
$ConfirmacionSueloMs = Num 'ConfirmacionSueloMs' 3000
$DecisionMinIntentos = Num 'DecisionMinIntentos' 20
$EleccionMs = Num 'EleccionMs' 15000
Comp 'el numero de siempre sale del archivo' ($ConfirmacionMs -eq 6000) ([string]$ConfirmacionMs + ' ms')
Comp 'el suelo tambien' ($ConfirmacionSueloMs -eq 3000) ([string]$ConfirmacionSueloMs + ' ms; la mas lenta medida son 3 s')
Comp 'y el minimo de muestras es el de la casa' ($DecisionMinIntentos -eq 20) ([string]$DecisionMinIntentos + ' , el mismo de las otras decisiones propias')
Comp 'y el techo con juego es el del selector' ($EleccionMs -eq 15000) ([string]$EleccionMs + ' ms')

Write-Host ''
Write-Host '-- 1. CON POCOS DATOS NO SE MUEVE NADA (hoy hay 13) --'
# los trece retrasos REALES del registro, en ms
$reales = @(1000, 1000, 1000, 1000, 1000, 1000, 2000, 2000, 2000, 2000, 3000, 3000, 3000)
Comp '1a. con los 13 de hoy, el de siempre' ((Get-PlazoConfirmacionMs $reales $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $ConfirmacionMs) -eq $ConfirmacionMs) ([string]$reales.Count + ' muestras, minimo ' + [string]$DecisionMinIntentos)
Comp '1b. sin ninguna, tambien' ((Get-PlazoConfirmacionMs @() $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $ConfirmacionMs) -eq $ConfirmacionMs) ''
Comp '1c. con 19 tampoco' ((Get-PlazoConfirmacionMs (1..19 | ForEach-Object { 1000 }) $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $ConfirmacionMs) -eq $ConfirmacionMs) 'el liston no se estira'

Write-Host ''
Write-Host '-- 2. CON DATOS DE SOBRA, SALE DE ELLOS --'
# veinte iguales a los reales: p95 de 3 s por dos = 6 s, o sea el numero de hoy
$veinte = @()
foreach ($x in @(1000, 1000, 1000, 1000, 1000, 1000, 2000, 2000, 2000, 2000, 3000, 3000, 3000, 1000, 1000, 2000, 2000, 3000, 1000, 2000)) { $veinte += $x }
$p = Get-PlazoConfirmacionMs $veinte $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $ConfirmacionMs
Comp '2a. con sus tiempos de hoy sale... el numero de hoy' ($p -eq 6000) ([string]$p + ' ms; el p95 de 3 s por dos')
Comp '2b. y eso tambien es un resultado' ($p -eq $ConfirmacionMs) 'el dato de hoy NO pide cambiar nada'
# si contestara mas rapido, baja
$rapidas = @(); foreach ($i in 1..25) { $rapidas += 800 }
$p2 = Get-PlazoConfirmacionMs $rapidas $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $ConfirmacionMs
Comp '2c. contestando mas rapido, el plazo baja' ($p2 -lt $ConfirmacionMs) ([string]$p2 + ' ms en vez de ' + [string]$ConfirmacionMs)
Comp '2d. pero nunca del suelo' ($p2 -ge $ConfirmacionSueloMs) ([string]$p2 + ' >= ' + [string]$ConfirmacionSueloMs)
# si tardara mucho, sube... hasta el techo
$lentas = @(); foreach ($i in 1..25) { $lentas += 20000 }
$p3 = Get-PlazoConfirmacionMs $lentas $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $ConfirmacionMs
Comp '2e. y no pasa del techo' ($p3 -eq $ConfirmacionMs) ([string]$p3 + ' ms')
$p4 = Get-PlazoConfirmacionMs $lentas $DecisionMinIntentos $ConfirmacionMs $ConfirmacionSueloMs $EleccionMs
Comp '2f. con el techo del selector, llega mas lejos' ($p4 -eq $EleccionMs) ([string]$p4 + ' ms; con un juego delante las manos estan ocupadas')

Write-Host ''
Write-Host '-- 3. EL P95 ES EL P95 --'
$escalera = @(); foreach ($i in 1..100) { $escalera += ($i * 100) }
$p5 = Get-PlazoConfirmacionMs $escalera $DecisionMinIntentos 99999 0 99999
Comp '3a. de 100 a 10.000, el p95 por dos son 19.000' ($p5 -eq 19000) ([string]$p5 + ' ms; el p95 de la escalera es 9.500')
Comp '3b. y no es el maximo' ($p5 -lt 20000) 'con el maximo serian 20.000'

Write-Host ''
Write-Host '-- 4. LO QUE NO SE APUNTA (la guarda que importa) --'
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-conf-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $MemoriaDir -Force | Out-Null
$ConfirmacionTiemposJson = Join-Path $MemoriaDir 'confirmacion-tiempos.json'
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$r, [string]$t) { [IO.File]::WriteAllText($r, $t, $UTF8) }
$script:invitado = $false
$script:juegoActivo = $null
$script:confTiempos = $null
try {
    Comp '4a. un vencido por plazo NO entra' (-not (Add-TiempoRespuesta 6000 'plazo' $false)) 'si entrara, el plazo se justificaria a si mismo para siempre'
    Comp '4b. ni un silencio' (-not (Add-TiempoRespuesta 6000 '' $false)) ''
    Comp '4c. ni algo imposible' (-not (Add-TiempoRespuesta 0 'si' $false)) 'ni negativo'
    Comp '4d. ni un minuto entero' (-not (Add-TiempoRespuesta 61000 'si' $false)) 'eso es que se fue y volvio'
    $script:invitado = $true
    Comp '4e. ni en modo invitado' (-not (Add-TiempoRespuesta 1500 'si' $false)) 'lo que haga otro no ajusta sus numeros'
    $script:invitado = $false
    Comp '4f. un si SI entra' (Add-TiempoRespuesta 1500 'si' $false) ''
    Comp '4g. y un no tambien' (Add-TiempoRespuesta 2500 'no' $false) 'contestar que no es contestar'
    $t = Get-ConfirmacionTiempos
    Comp '4h. los dos en el cubo de sin juego' ($t.sinJuego.Count -eq 2 -and $t.conJuego.Count -eq 0) ([string]$t.sinJuego.Count + ' / ' + [string]$t.conJuego.Count)

    Write-Host ''
    Write-Host '-- 5. EL CUBO DEL JUEGO VA APARTE --'
    $null = Add-TiempoRespuesta 8000 'si' $true
    $t2 = Get-ConfirmacionTiempos
    Comp '5a. la del juego va a su cubo' ($t2.conJuego.Count -eq 1) ([string]$t2.conJuego.Count)
    Comp '5b. y no ensucia el otro' ($t2.sinJuego.Count -eq 2) ([string]$t2.sinJuego.Count + '; con las manos ocupadas se tarda mas')
    Comp '5c. y sobrevive al reinicio' ($(
        $script:confTiempos = $null
        $t3 = Get-ConfirmacionTiempos
        $t3.sinJuego.Count -eq 2 -and $t3.conJuego.Count -eq 1)) 'se guarda en disco'
    # el tope por cubo
    for ($i = 0; $i -lt ($ConfirmacionMax + 15); $i++) { $null = Add-TiempoRespuesta 1200 'si' $false }
    Comp '5d. el tope por cubo muerde' ((Get-ConfirmacionTiempos).sinJuego.Count -le $ConfirmacionMax) ([string](Get-ConfirmacionTiempos).sinJuego.Count + ' de ' + [string]$ConfirmacionMax)
    Comp '5e. y el del juego no se toca' ((Get-ConfirmacionTiempos).conJuego.Count -eq 1) ''

    Write-Host ''
    Write-Host '-- 6. Y EL PLAZO DE AHORA MISMO USA EL CUBO QUE TOCA --'
    $script:juegoActivo = $null
    $sinJ = Get-PlazoConfirmacion
    Comp '6a. sin juego, con 60 muestras de 1,2 s' ($sinJ -eq $ConfirmacionSueloMs) ([string]$sinJ + ' ms; el p95 por dos son 2.400, y el suelo son ' + [string]$ConfirmacionSueloMs)
    $script:juegoActivo = 'Elden Ring'
    $conJ = Get-PlazoConfirmacion
    Comp '6b. con juego y UNA muestra, el de siempre' ($conJ -eq $ConfirmacionMs) ([string]$conJ + ' ms; de ese cubo no hay datos todavia')
    $script:juegoActivo = $null
} finally {
    Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
Comp '7a. los tres sitios preguntan el plazo' (@([regex]::Matches($sinCom, 'Get-PlazoConfirmacion')).Count -ge 4) ([string]@([regex]::Matches($sinCom, 'Get-PlazoConfirmacion')).Count + ' menciones (3 usos + la definicion)')
Comp '7b. y ya no queda el numero suelto en el bucle' (-not ($sinCom -match '\$sw\.ElapsedMilliseconds \+ \$ConfirmacionMs')) ''
Comp '7c. ni en el empuje de la voz' (-not ($sinCom -match '\$finVozC \+ \$ConfirmacionMs')) ''
Comp '7d. la medida arranca en Start-Confirmacion' ($sinCom -match '\$script:pendiente\.desde = \$sw\.ElapsedMilliseconds') ''
Comp '7e. y se empuja con la voz, como el vencimiento' ($sinCom -match '\[double\]\$script:pendiente\.desde -lt \$finVozC') 'si no, se mediria la voz de Nova mas lo que tarda braya'
Comp '7f. se apunta al contestar' ($sinCom -match 'Add-TiempoRespuesta \$msR \$respuesta') ''
Comp '7g. y se dice en el registro' ($sinCom -match 'CONFIRMAR: tardaste') 'un numero que se ajusta y no se ve no ha pasado'
Comp '7h. el juego se guarda al preguntar, no al contestar' ($sinCom -match '\$script:pendiente\.juego = \[bool\]\$script:juegoActivo') 'si el juego se cierra mientras piensa, la muestra sigue siendo de su cubo'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el plazo para decir si sale de lo que tarda braya, no de una corazonada' -ForegroundColor Green
exit 0
