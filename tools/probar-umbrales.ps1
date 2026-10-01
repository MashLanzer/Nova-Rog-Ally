# LOS UMBRALES DE LAS DECISIONES, EN UN SOLO SITIO (18/09, idea 62).
#
# POR QUE EXISTE. El 15 % de aprovechamiento y los 20 intentos minimos estaban escritos A MANO
# en cuatro sitios: las tres decisiones de Test-RevisionPropia (nube, oido fino, ultimo recurso)
# y Get-AvisoSinDatos, que es la que avisa de que hay una decision esperando datos.
#
# Separarlos NO daria ningun error: Nova avisaria de decisiones que ya no tocan, o callaria las
# que si, y nadie se enteraria. Es el fallo silencioso que este proyecto persigue.
#
# Esta prueba vigila dos cosas: que el calculo sea uno solo, y que NADIE vuelva a escribir el
# numero a mano en esas funciones.
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
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)

# las constantes se leen del propio archivo, no se copian aqui: si cambian, la prueba las sigue
$DecisionAprovecha = if ($txt -match '\$DecisionAprovecha = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
$DecisionMinIntentos = if ($txt -match '\$DecisionMinIntentos = ([0-9]+)') { [int]$Matches[1] } else { -1 }
Invoke-Expression (Traer 'Get-DecisionMinimo')
$DecisionAlfa = if ($txt -match '\$DecisionAlfa = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
$DecisionPorAcierto = if ($txt -match '\$DecisionPorAcierto = ([0-9]+)') { [int]$Matches[1] } else { -1 }
Invoke-Expression (Traer 'Get-DecisionPValor')
Invoke-Expression (Traer 'Test-DecisionSolida')

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

Write-Host '  -- las constantes existen y son razonables --'
Comp 'el aprovechamiento minimo esta definido' ($DecisionAprovecha -gt 0 -and $DecisionAprovecha -lt 1) "$DecisionAprovecha"
Comp 'y los intentos minimos tambien' ($DecisionMinIntentos -ge 5) "$DecisionMinIntentos"

Write-Host '  -- el calculo, con los numeros de verdad --'
# el caso real de hoy: el ultimo recurso lleva 1 acierto de 29 intentos
Comp 'con 29 intentos hacen falta 5 aciertos' ((Get-DecisionMinimo 29) -eq 5) "$(Get-DecisionMinimo 29)"
Comp 'y 1 de 29 NO aporta (por eso se apagaria)' (1 -lt (Get-DecisionMinimo 29)) ''
# el oido fino: 27 aciertos menos 5 inventos de 81 repasos = 22 neto
Comp 'con 81 repasos hacen falta 13' ((Get-DecisionMinimo 81) -eq 13) "$(Get-DecisionMinimo 81)"
Comp 'y el neto del oido fino (22) SI aporta' ((27 - 5) -ge (Get-DecisionMinimo 81)) ''
Comp 'redondea hacia arriba, no hacia abajo' ((Get-DecisionMinimo 21) -eq 4) "21 -> $(Get-DecisionMinimo 21)"
Comp 'con 0 intentos no pide nada' ((Get-DecisionMinimo 0) -eq 0) ''

Write-Host ''
Write-Host '  -- el alfa: la revision corre TODOS los dias, asi que 0,05 no vale --'
Comp 'el alfa esta definido y no pasa de 0,01' ($DecisionAlfa -gt 0 -and $DecisionAlfa -le 0.01) "$DecisionAlfa"
Comp 'y cada acierto pide mas intentos' ($DecisionPorAcierto -ge 1) "$DecisionPorAcierto"

Write-Host '  -- la binomial, contra numeros calculados aparte --'
# los p-valores estan calculados fuera de aqui; si la implementacion se tuerce, no cuadran
Comp '0 de 20: p = 0,0388 (no llega al 1 %)' ([Math]::Abs((Get-DecisionPValor 0 20) - 0.03875953) -lt 1e-7) "$(Get-DecisionPValor 0 20)"
Comp '1 de 29 -el caso real-: p = 0,0549' ([Math]::Abs((Get-DecisionPValor 1 29) - 0.05492035) -lt 1e-7) "$(Get-DecisionPValor 1 29)"
Comp '2 de 81 -la nube real-: p = 0,00022' ([Math]::Abs((Get-DecisionPValor 2 81) - 0.00022290) -lt 1e-7) "$(Get-DecisionPValor 2 81)"
Comp 'sin intentos no decide nada (p = 1)' ((Get-DecisionPValor 0 0) -eq 1.0) ''
Comp 'un neto negativo cuenta como 0, no como imposible' ((Get-DecisionPValor (-3) 40) -eq (Get-DecisionPValor 0 40)) ''
# LO QUE MAS IMPORTA DE LA IMPLEMENTACION: con 2000 intentos, 0,85^2000 es cero en coma
# flotante. Sumado a pelo daria p = 0 y Nova apagaria por un desbordamiento.
Comp 'y un historial enorme NO desborda a p = 0' ((Get-DecisionPValor 400 2000) -gt 0.99) "$(Get-DecisionPValor 400 2000)"

Write-Host '  -- la regla nueva, con los datos de verdad de braya --'
Comp '1 de 29 ya NO se apaga (antes si)' (-not (Test-DecisionSolida 1 29)) ''
Comp 'pero 1 de 42 si' (Test-DecisionSolida 1 42) ''
Comp '0 de 20 tampoco: hacen falta 29' (-not (Test-DecisionSolida 0 20)) ''
Comp 'y 0 de 29 si' (Test-DecisionSolida 0 29) ''
Comp 'la nube real (2 de 81) se apagaria' (Test-DecisionSolida 2 81) ''
Comp 'el oido fino real (neto 28 de 110) no' (-not (Test-DecisionSolida (33 - 5) 110)) ''
Comp 'y 6 de 29 tampoco: harian falta 93' (-not (Test-DecisionSolida 6 29)) ''

Write-Host '  -- y NUNCA es mas blanda que la regla de ayer --'
# la regla de ayer: 20 intentos y menos del 15 %. Se barren todos los casos plausibles
# buscando UNO en que la nueva apague algo que la vieja dejaba puesto. No puede haberlo.
$blanda = 0
foreach ($nB in 20..400) {
    foreach ($kB in 0..12) {
        if ($kB -ge $nB) { continue }
        $vieja = ($nB -ge $DecisionMinIntentos -and $kB -lt (Get-DecisionMinimo $nB))
        if ((Test-DecisionSolida $kB $nB) -and (-not $vieja)) { $blanda++ }
    }
}
Comp 'ni un caso en que decida donde la vieja no decidia' ($blanda -eq 0) "casos=$blanda"

Write-Host ''
Write-Host '  -- y NADIE escribe el numero a mano (lo que se queria evitar) --'
# se miran solo las funciones que deciden: si vuelve a aparecer un 0.15 o un "-lt 20" ahi
# dentro, es que alguien ha duplicado el criterio y volvemos al problema de partida
foreach ($fn in @('Test-RevisionPropia', 'Get-AvisoSinDatos')) {
    $cuerpo = Traer $fn
    Comp "$fn no repite el 0.15" ($cuerpo -notmatch '\* 0\.15') ''
    Comp "$fn no repite el 20 a mano" ($cuerpo -notmatch '-lt 20\b|-ge 20\b') ''
    Comp "$fn usa las constantes" ($cuerpo -match 'DecisionMinIntentos|Get-DecisionMinimo') ''
}

Write-Host '  -- y las tres decisiones siguen pidiendo lo mismo --'
# que no se haya colado un criterio distinto sin querer: las tres usan el mismo minimo
$cuerpoR = Traer 'Test-RevisionPropia'
$cuantas = ([regex]::Matches($cuerpoR, 'Get-DecisionMinimo')).Count
Comp 'las tres decisiones usan el calculo compartido' ($cuantas -ge 3) "usos=$cuantas"
$cuantosMin = ([regex]::Matches($cuerpoR, 'DecisionMinIntentos')).Count
Comp 'y las tres el minimo de intentos' ($cuantosMin -ge 3) "usos=$cuantosMin"
# 20/09: y las tres pasan tambien por la binomial. Si alguien anade una cuarta decision y
# se olvida del portero, esto se pone rojo.
$cuantasB = ([regex]::Matches($cuerpoR, 'Test-DecisionSolida')).Count
Comp 'y las tres por la prueba binomial' ($cuantasB -ge 3) "usos=$cuantasB"
Comp 'el aviso de "decision esperando" tambien' ((Traer 'Get-AvisoSinDatos') -match 'Test-DecisionSolida') ''

# EL SI/NO: EL WORKER TIENE QUE ESCUCHAR MAS DE LO QUE EL ASISTENTE ESPERA (18/09). Eran 5 s
# de worker frente a 3,5 s + la voz del asistente, al reves de como debe ser, y nadie lo
# comparaba. braya: "a veces no puedo responder en preguntas de si o no". Los dos numeros se
# leen del fuente: si alguien toca uno y no el otro, esto se pone rojo.
Write-Host ''
Write-Host '  -- el si/no: los dos relojes, a la par --'
$txtW = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [System.Text.Encoding]::UTF8)
$esperaMs = if ($txt -match "Get-Cfg 'confirmacion' 'esperaMs' ([0-9]+)") { [int]$Matches[1] } else { -1 }
$workerSeg = if ($txtW -match 'CONFIRMACION_MAX = ([0-9.]+)') { [double]$Matches[1] } else { -1 }
Comp 'el plazo del asistente se lee del fuente' ($esperaMs -gt 0) "esperaMs=$esperaMs"
Comp 'el del worker tambien' ($workerSeg -gt 0) "CONFIRMACION_MAX=$workerSeg"
Comp 'el worker escucha MAS de lo que el asistente espera' ($workerSeg * 1000 -gt $esperaMs) "worker=$($workerSeg)s asistente=$($esperaMs)ms"
Comp 'y con margen (al menos 1 s)' (($workerSeg * 1000 - $esperaMs) -ge 1000) ''
# y el plazo se REARMA cuando termina de hablar, no antes: la linea tiene que estar en el
# bloque de la confirmacion pendiente del bucle
#
# EL BLOQUE SE CIERRA DONDE EMPIEZA EL SIGUIENTE, NO A LOS 4500 CARACTERES (30/09). Esto cogia
# un trozo de 4500 y la proteccion que vigila -el empuje al fin de la voz- se fue a 5788 al
# crecer el bloque con los arreglos: la comprobacion se quedo CIEGA y se puso roja con el codigo
# intacto. Un numero de caracteres a mano caduca solo, igual que una lista a mano. Ahora el
# final es el marcador del bloque siguiente, asi que el trozo crece con el codigo.
# Y SI NO SE ENCUENTRA EL CIERRE, SE COGE TODO LO QUE QUEDA: nunca menos, porque quedarse corto
# es justo el fallo que se esta arreglando.
$iConf = $txt.IndexOf('--- CONFIRMACION PENDIENTE (si / no / plazo) ---')
$trozoConf = ''
if ($iConf -ge 0) {
    $iFin = $txt.IndexOf('--- PALABRA DE ACTIVACION', $iConf)
    $largo = if ($iFin -gt $iConf) { $iFin - $iConf } else { $txt.Length - $iConf }
    $trozoConf = $txt.Substring($iConf, $largo)
}
# Y SIN LOS COMENTARIOS, PARA LO QUE MIRA ORDEN (30/09). La comprobacion de que el empuje va
# ANTES de decidir el plazo comparaba dos IndexOf, y el de "Complete-Confirmacion 'plazo'" caia
# en un COMENTARIO de 55 lineas mas arriba que lo nombra en prosa: comparaba codigo contra
# comentario. Lo que mira orden usa este trozo; lo que solo mira presencia puede usar el de
# arriba, porque ahi un comentario que nombre la linea buena no cambia el veredicto.
$trozoConfCodigo = (($trozoConf -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# 27/09: EL REARME YA NO SUMA LA CONSTANTE A PELO, SUMA EL PLAZO MEDIDO (idea 102). La linea
# decia "+ $ConfirmacionMs" y esta comprobacion buscaba ese texto; ahora dice
# "+ (Get-PlazoConfirmacion)", que es el calculo compartido con techo $ConfirmacionMs. El codigo
# esta bien: lo desfasado era el banco. Se ancla a la llamada real, no a la constante suelta.
Comp 'el plazo se rearma al pasar a confirmando' ($trozoConf -match '\$script:pendiente\.vence = \$sw\.ElapsedMilliseconds \+ \(Get-PlazoConfirmacion\)') ''
# Y NADIE VUELVE A ESCRIBIR EL PLAZO A MANO AHI (es de lo que va esta seccion): ninguna
# asignacion de .vence dentro del bloque puede llevar un numero de tres cifras o mas.
$aManoV = [regex]::Matches($trozoConf, '\$script:pendiente\.vence = .*[0-9]{3}')
Comp 'y sin numeros a mano en el vencimiento' ($aManoV.Count -eq 0) "a mano=$($aManoV.Count)"
# Y LO QUE DE VERDAD PROTEGE (18/09, 20:15): el rearme de arriba paso la prueba y fallo en
# vivo, porque el plazo vencia ANTES de que la capsula pasara a 'confirmando' (la voz seguia
# sonando). Mientras hable, el vencimiento tiene que empujarse a "fin de la voz + plazo".
Comp 'mientras habla, el plazo NO corre (se empuja al fin de la voz)' ($trozoConf -match 'finVozC[\s\S]{0,300}\$script:pendiente\.vence = \$minimoC') ''
# Y LOS DOS TIENEN QUE ESTAR (30/09). Esto era un '-lt' pelado entre dos IndexOf, y cuando el
# primero no se encontraba devolvia -1, que es MENOR QUE CUALQUIER indice valido: la comprobacion
# pasaba en VERDE justo cuando habia dejado de ver lo que vigila. Es lo que llevaba pasando con la
# ventana corta de arriba. Ahora se exige que los dos aparezcan, y luego el orden.
$iEmpuje = $trozoConfCodigo.IndexOf('$minimoC')
$iDecide = $trozoConfCodigo.IndexOf("Complete-Confirmacion 'plazo'")
Comp 'el empuje y la decision del plazo estan los dos' (($iEmpuje -ge 0) -and ($iDecide -ge 0)) "empuje=$iEmpuje decide=$iDecide"
Comp 'y el empuje va ANTES de decidir el plazo' (($iEmpuje -ge 0) -and ($iDecide -ge 0) -and ($iEmpuje -lt $iDecide)) "empuje=$iEmpuje decide=$iDecide"

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
