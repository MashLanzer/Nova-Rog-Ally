# CON CUANTA MEMORIA ESTA OYENDO, Y QUE SE ENTERE ALGUIEN (26/09, idea 17 de las 121).
#
# EL AGUJERO: cuando queda poca memoria el oido encoge SOLO su plazo para soltar los modelos
# -y con eso oye peor-, lo apuntaba en assistant-pulso.log y no se enteraba nadie. Ni el
# cerebro: assistant.ps1 abria ese fichero en UN sitio y era para borrarlo. Un monologo.
#
# MEDIDO sobre los pulsos con ram_libre de assistant-pulso.log: el 42,9 % corria con el plazo
# recortado y el 11,4 % en el suelo x0,10. La mediana de memoria libre de esta consola son
# 2.815 MB y el liston de "comoda" estaba en 2.500: justo por debajo de la mediana, o sea que
# se recortaba casi la mitad del tiempo por diseno.
#
# ESTE BANCO CUBRE LA FONTANERIA. Los numeros -los listones, el replay de los pulsos de verdad
# y la cuenta- estan en tools\probar-plazos-soltar.py, que ejecuta las funciones de Python.
#
# LA TRAMPA CENTRAL, y es la razon de que este banco exista: en PowerShell $null vale 0 en una
# comparacion numerica. Si falta el decimo campo, $st[9] es $null, [int]$null es 0, y Nova
# diria en voz alta "he estado 0 % con la memoria justa" cuando la verdad es que no lo sabe.
# Por eso "no se sabe" es -1 y nunca 0.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$ps1 = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$tp = [IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'), [Text.Encoding]::UTF8)
$pSin = (($tp -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. EL CAMPO VA AL FINAL, O SE ROMPEN LOS OTROS LECTORES --'
# EL PREFIJO ABIERTO A PROPOSITO (ver probar-oido-flojo:150-160): esta linea CRECE por diseno,
# y un banco que exija un numero exacto de campos castiga cumplir el diseno. Lo que de verdad
# hay que proteger es que nadie meta un campo EN MEDIO: los lectores de assistant.ps1 van por
# indice y les cambiaria el significado a todos a la vez y en silencio.
Comp 'el estado empieza por sus campos de siempre' ($pSin -match '"%\.1f\|%s\|%\.3f\|%d\|%d\|%d\|%d') ''
Comp '  y el nuevo va DETRAS de los que ya estaban' ($pSin -match 'desc_recientes, ram_justa_pct\(\)') 'el octavo y el noveno se ocuparon esta misma tarde'
Comp '  sin tocar el orden de los anteriores' ($pSin -match 'recientes, desde_recorte,') ''

Write-Host ''
Write-Host '-- 2. Y EL BUCLE TIENE QUE CONTARLO, O NO HAY NADA QUE DECIR --'
# LO CAZO UNA ROTURA A PROPOSITO: quitando la llamada del bucle, los contadores se quedaban a
# cero para siempre, ram_justa_pct devolvia -1 siempre, y los dos bancos pasaban en verde
# mientras Nova se quedaba muda sobre esto. Toda la logica se puede probar y no servir de nada
# si el unico sitio que la usa no la llama.
Comp 'el pulso cuenta con cuanta memoria va' ($pSin -match 'apunta_ram\(_ram, jugando\(\)\)') ''
# CON EL _ram QUE YA TIENE EN LA MANO (reglas 4 y 5): ram_libre_mb hace un GlobalMemoryStatusEx
# por ctypes y esto corre mientras braya juega.
Comp '  sin una medida nueva de memoria' ($pSin -notmatch 'apunta_ram\(ram_libre_mb\(\)') 'se reusa el _ram del pulso'
# Y CON LA GUARDA DEL JUEGO EN EL SITIO DE LA LLAMADA: jugando() se evalua aqui.
Comp '  y pasandole si hay un juego delante' ($pSin -match 'apunta_ram\([^)]*jugando') 'ahi la memoria es del juego'

Write-Host ''
Write-Host '-- 3. EL LECTOR, EJECUTADO DE VERDAD --'
foreach ($fn in @('Test-EstadoFresco', 'Get-OidoMemoriaJusta')) {
    $m = [regex]::Match($fuente, "(?ms)^function $fn \{.*?^\}")
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
$base = Join-Path ([IO.Path]::GetTempPath()) ('apretado-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$RutaEstado = Join-Path $base 'escucha-estado.txt'
$mMax = [regex]::Match($fuente, '(?m)^\$EstadoMaxSegundos = (\d+)')
$EstadoMaxSegundos = if ($mMax.Success) { [int]$mMax.Groups[1].Value } else { 45 }
function Pon([string]$linea) { [IO.File]::WriteAllText($RutaEstado, $linea) }
try {
    # SIN FICHERO: no se sabe nada. Pasa en el primer arranque de la vida.
    Comp 'sin fichero, no se sabe' ((Get-OidoMemoriaJusta) -eq -1) 'primer arranque'
    # EL WORKER VIEJO: nueve campos, los de esta tarde. Aqui es donde $null valdria 0.
    Pon '2.6|0|0.000|60|0|0|-1|-|3'
    Comp 'con un oido de nueve campos, no se sabe' ((Get-OidoMemoriaJusta) -eq -1) 'sin la guarda, el campo es $null y [int]$null es 0'
    # DIEZ CAMPOS Y FRESCO: se lee, y se lee EL DECIMO.
    Pon '2.6|0|0.000|60|0|0|-1|-|3|43'
    Comp 'con diez campos, devuelve el suyo' ((Get-OidoMemoriaJusta) -eq 43) 'el decimo, no el septimo'
    # QUE NO SE LEA OTRO CAMPO POR ERROR: aqui el septimo vale 77 y el decimo 43.
    Pon '2.6|0|0.000|60|0|0|77|-|3|43'
    Comp '  y no el de los segundos desde el recorte' ((Get-OidoMemoriaJusta) -eq 43) 'un indice de menos daria 77'
    # EL ESTADO RANCIO: lo que hay ahi es del worker anterior hasta que el nuevo escribe.
    (Get-Item $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-($EstadoMaxSegundos + 15))
    Comp 'con el estado rancio, no se sabe' ((Get-OidoMemoriaJusta) -eq -1) "del worker muerto; mas de $EstadoMaxSegundos s"
    (Get-Item $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-($EstadoMaxSegundos - 10))
    Comp '  y uno de hace un momento sigue valiendo' ((Get-OidoMemoriaJusta) -eq 43) ''
    # EL CERO DE VERDAD NO ES -1: si el oido ha contado diez minutos y ninguno iba justo, eso
    # es un dato bueno y tiene que llegar como 0, no confundirse con "no se sabe".
    Pon '2.6|0|0.000|60|0|0|-1|-|3|0'
    Comp 'un cero de verdad llega como cero' ((Get-OidoMemoriaJusta) -eq 0) 'distinto de no saberlo'
    # Y LA BASURA NO REVIENTA NI INVENTA
    Pon 'esto no es un estado'
    Comp 'con basura dentro, no se sabe' ((Get-OidoMemoriaJusta) -eq -1) ''
} finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
# LA GUARDA DEL CONTEO, MIRADA EN EL FUENTE, y hay que explicar por que no basta con el caso
# de arriba: quitandola, la funcion SIGUE devolviendo -1, pero de casualidad. $st[9] de un
# array de nueve es $null, $null.Trim() revienta, y el catch devuelve -1 por el camino
# equivocado. El dia que alguien quite el .Trim() -que no pinta gran cosa ahi- [int]$null pasa
# a valer 0 y Nova empieza a decir "he estado 0 % con la memoria justa" cuando no lo sabe.
# Lo cazo una rotura a proposito que salio verde.
$mG = [regex]::Match($fuente, "(?ms)^function Get-OidoMemoriaJusta \{.*?^\}")
$cG = if ($mG.Success) { $mG.Value } else { '' }
Comp 'y la guarda del conteo esta escrita, no es casualidad' ($cG -match '\$st\.Count -lt 10') 'sin ella solo salva el Trim'
Comp '  y el -1 sale por la puerta de delante' ($cG -match 'if \(\$st\.Count -lt 10\) \{ return -1 \}') ''

Write-Host ''
Write-Host '-- 4. SE APUNTA, PERO NO INTERRUMPE --'
# EL BLOQUE ENTERO, ACOTADO POR SUS DOS VECINOS Y NO POR UN NUMERO DE CARACTERES. Una
# ventana fija de 700 se comia el bloque de 'oido-sin-repaso' que va justo antes -que si
# tiene un Send-AvisoEntorno- y daba rojo con el codigo bien. Ya mordio en probar-plazos-soltar
# esta misma tarde.
$iA = $sinCom.IndexOf('$pctRJ = Get-OidoMemoriaJusta')
$iFin = $sinCom.IndexOf('Get-AvisoHoraDormir')
Comp 'se encuentra el bloque, entre sus dos vecinos' ($iA -ge 0 -and $iFin -gt $iA) ''
$blA = if ($iA -ge 0 -and $iFin -gt $iA) { $sinCom.Substring($iA, $iFin - $iA) } else { '' }
Comp 'queda apuntado en las estadisticas' ($blA -match "Add-Estadistica 'oido-apretado'") ''
# ESTO ES LO QUE EVITA EL DESTROZO: el 22/09 se midio a donde lleva avisar de todo -28 de las
# 40 filas de estadisticas.json eran aviso-entorno y las decisiones en esa ventana eran CERO-.
Comp '  y NO hay ningun aviso nuevo' ($blA -notmatch 'Send-AvisoEntorno') 'esto se apunta, no interrumpe'
# EL FLANCO: una vez por sesion del oido, no una cada vuelta del bucle.
function EnOrden([string]$t, [string]$a, [string]$b) {
    $ma = [regex]::Match($t, $a); if (-not $ma.Success) { return $false }
    return [regex]::Match($t.Substring($ma.Index + $ma.Length), $b).Success
}
Comp '  una sola vez, con bandera' ($blA -match '-not \$script:ramJustaApuntada') ''
Comp '  y la bandera se marca ANTES de apuntar' (EnOrden $blA '\$script:ramJustaApuntada = \$true' 'Add-Estadistica') 'si falla el apunte, no se reintenta cada 30 s'
# Y SE REARMA SOLA: el oido nuevo devuelve -1 hasta tener diez minutos, y eso borra la bandera.
Comp 'y un oido recien arrancado rearma la bandera' (EnOrden $blA '\$pctRJ -lt 0' 'ramJustaApuntada = \$false') 'el -1 sale gratis como senal de oido nuevo'
Comp 'la bandera nace apagada' ($sinCom -match '\$script:ramJustaApuntada = \$false') ''

Write-Host ''
Write-Host '-- 5. Y SE DICE SOLO SI PREGUNTA, Y SOLO SI SE SABE --'
$iE = $sinCom.IndexOf("'estadoEscucha' {")
$blE = if ($iE -ge 0) { $sinCom.Substring($iE, [Math]::Min(2600, $sinCom.Length - $iE)) } else { '' }
Comp 'la respuesta de "como me oyes" lo cuenta' ($blE -match 'memoria justa') ''
# -1 NO SE DICE, Y 0 TAMPOCO: lo primero seria mentir, lo segundo seria ruido.
Comp '  y solo si es mayor que cero' ($blE -match '\$pctM -gt 0') 'con -1 mentiria, con 0 seria ruido'
# EN MINUTOS DE CADA DIEZ, que es como se entiende y como esta medido: el pulso corre cada
# 15 s, o sea 40 por cada diez minutos.
Comp '  y en minutos de cada diez, no en por ciento' ($blE -match 'de cada diez minutos') ''

Write-Host ''
Write-Host '-- 6. contra el registro de verdad --'
$n = 0
$log = Join-Path $raiz 'assistant-pulso.log'
if (Test-Path -LiteralPath $log) {
    foreach ($l in @(Get-Content -LiteralPath $log -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'plazo=x0\.') { $n++ }
    }
}
Write-Host ("       el oido corrio con el plazo recortado $n veces en assistant-pulso.log")
Comp 'el problema existe' ($n -ge 10) 'medido: el 42,9 % de los pulsos'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  se sabe con cuanta memoria estuvo oyendo'
exit 0
