# EL MP3 ABIERTO ANTES DE HABLAR (22/09).
#
# Play-Audio hacia Open() y Play() pegados, y desde el Open hasta que sale sonido pasan
# 464 ms de media (120 medidas en esta maquina; el rango 453-547 ya estaba apuntado dentro
# de Play-Audio). Con el mismo mp3 YA abierto en otro MediaPlayer, ese Play() suena en
# 31 ms: 433 ms menos por frase. En el log de braya hay 599 frases de voz, y 309 de ellas
# llegaron "ya preparadas" (2 ms de sintesis): en esas, abrir el fichero ERA el 99 % del
# retraso.
#
# TODO DEPENDE DE ACERTAR LA RUTA. El adelanto solo sirve si el mp3 que se abre por
# adelantado es EXACTAMENTE el que Play-Audio va a pedir, y esa ruta la decide
# tts_worker.py con un md5. Asi que este banco no comprueba que la cuenta de PowerShell
# "parezca" la de Python: las ejecuta LAS DOS y compara el resultado letra a letra.
#
# LAS DOS SE TRAEN DE SU FICHERO REAL, nunca copiadas (la regla del banco, van dieciseis):
#   - Get-RutaVozCache sale de assistant.ps1
#   - la cuenta del worker sale de tts_worker.py, el bloque entero desde 'ritmo =
#     velocidad()' hasta la ruta, mas velocidad() y AJUSTE_EMOCION
# Si cualquiera de las dos cambia y la otra no, esto se pone rojo. Que es justo lo que
# tiene que pasar: el dia que se separen, el adelanto deja de acertar en silencio.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$worker = [System.IO.File]::ReadAllText((Join-Path $raiz 'tts_worker.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# --- la cuenta de PowerShell, traida del fichero real ---
$mFn = [regex]::Match($fuente, '(?ms)^function Get-RutaVozCache\b.*?^\}')
if (-not $mFn.Success) { Write-Host '  MAL  no encuentro Get-RutaVozCache en assistant.ps1'; exit 1 }
. ([scriptblock]::Create($mFn.Value))

# El sitio de pruebas: una carpeta propia, para no tocar la cache de voz de verdad.
$VozCache = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-voz-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $VozCache | Out-Null
$VozOnlineNombre = 'es-MX-DaliaNeural'

# --- la cuenta de Python, traida de tts_worker.py ---
# Se sacan los tres trozos que deciden la ruta. No se importa el modulo entero a proposito:
# al importarlo correrian la poda de la cache y el bucle de stdin.
$mVel = [regex]::Match($worker, '(?ms)^def velocidad\(\):.*?^\s*return "\+0%"')
$mEmo = [regex]::Match($worker, '(?m)^AJUSTE_EMOCION = \{.*\}$')
$mCla = [regex]::Match($worker, '(?ms)^        ritmo = velocidad\(\).*?^        ruta = os\.path\.join\(SALIDA, clave \+ "\.mp3"\)')
Comp 'velocidad() sigue en tts_worker.py' $mVel.Success
Comp 'AJUSTE_EMOCION sigue en tts_worker.py' $mEmo.Success
Comp 'y el bloque que arma la clave tambien' $mCla.Success
if ($fallos -gt 0) {
    Write-Host ''
    Write-Host '  el worker cambio de forma: hay que mirar si Get-RutaVozCache sigue valiendo'
    exit 1
}

# El bloque de la clave viene indentado con 8 espacios (vive dentro de principal()).
$bloque = ($mCla.Value -split "`n" | ForEach-Object { $_ -replace '^        ', '' }) -join "`n"
$py = @"
# -*- coding: utf-8 -*-
# Generado por probar-voz-adelantada.ps1. Los tres trozos de abajo son los de
# tts_worker.py, copiados EN CALIENTE de ese fichero, no escritos aqui.
import hashlib
import io
import json
import os
import sys

SALIDA = sys.argv[1]
VOZ = sys.argv[2]
# LOS CASOS ENTRAN POR UN FICHERO UTF-8, NO POR STDIN. En PowerShell 5.1 la tuberia hacia
# un .exe sale en la pagina de codigos de la consola, y el "¿" llegaba aqui hecho un
# desastre: cinco de seis rutas coincidian y la del "¿" no. No era un fallo del adelanto,
# era el banco midiendo mal. El codigo de verdad no tiene ese problema porque Say-Online
# escribe BYTES UTF-8 al BaseStream, que es justo lo que cuenta el comentario del stdin en
# binario de aqui al lado.

$($mVel.Value)


$($mEmo.Value)


salida = []
for texto, emo in json.loads(io.open(sys.argv[3], encoding="utf-8").read()):
$($bloque -split "`n" | ForEach-Object { '    ' + $_ } | Out-String)
    salida.append(ruta)
sys.stdout.write(json.dumps(salida))
"@
# SIN PYTHON NO HAY COMPARACION, Y HAY QUE DECIRLO. Callarse y saltar la mitad del banco
# seria peor que fallar: la bateria se pintaria en verde sin haber comprobado lo unico que
# importa aqui, que es que las dos cuentas dan la misma ruta.
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host '  MAL  no hay python en el PATH: no puedo comparar con la cuenta del worker'
    Remove-Item -LiteralPath $VozCache -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}
$rutaPy = Join-Path $VozCache '_clave_worker.py'
[System.IO.File]::WriteAllText($rutaPy, $py, (New-Object System.Text.UTF8Encoding $false))

# LOS CASOS. Las tildes, la enye y el "¿" estan a proposito: el worker ya murio una vez por
# ahi (lo cuenta el comentario de stdin en binario), y si aquel arreglo se deshiciera, el
# md5 de Python cambiaria y este banco lo veria.
$casos = @(
    @{ t = 'Hola, ya esta'; e = '' },
    @{ t = 'Vale, lo dejo puesto'; e = 'alegre' },
    @{ t = 'Tranquilo, no pasa nada'; e = 'suave' },
    @{ t = '¿Quieres que te lo ponga en el salon? Manana por la manana'; e = '' },
    @{ t = 'Cancion numero cuatro, la del ano pasado'; e = 'alegre' },
    @{ t = 'Aqui hay tildes: camion, accion, ultimo, mas'; e = 'suave' }
)

function Comparar([int]$vel, [string]$comoSale) {
    # la velocidad se lee de velocidad.txt en cada frase, en los dos lados
    $fVel = Join-Path $VozCache 'velocidad.txt'
    if ($vel -eq [int]::MinValue) {
        if (Test-Path -LiteralPath $fVel) { Remove-Item -LiteralPath $fVel -Force }
    } else {
        [System.IO.File]::WriteAllText($fVel, [string]$vel)
    }
    $entrada = ConvertTo-Json @($casos | ForEach-Object { , @($_.t, $_.e) }) -Depth 4 -Compress
    $fCasos = Join-Path $VozCache '_casos.json'
    [System.IO.File]::WriteAllText($fCasos, $entrada, (New-Object System.Text.UTF8Encoding $false))
    $suyas = (& python $rutaPy $VozCache $VozOnlineNombre $fCasos) | ConvertFrom-Json
    $iguales = 0
    for ($i = 0; $i -lt $casos.Count; $i++) {
        $mia = Get-RutaVozCache $casos[$i].t $casos[$i].e
        if ($mia -eq $suyas[$i]) { $iguales++ }
        elseif ($iguales -eq $i) {
            # solo se ensena la primera que falla, con las dos rutas, para poder mirarla
            Write-Host ('       la mia:  ' + (Split-Path -Leaf $mia))
            Write-Host ('       la suya: ' + (Split-Path -Leaf $suyas[$i]) + '   <- "' + $casos[$i].t.Substring(0, [Math]::Min(34, $casos[$i].t.Length)) + '" [' + $casos[$i].e + ']')
        }
    }
    Comp $comoSale ($iguales -eq $casos.Count) "$iguales de $($casos.Count)"
}

Write-Host ''
Write-Host '-- la ruta que calculo yo es la que va a calcular el worker --'
Comparar 0 'a velocidad normal, las 6 frases'
Comparar 15 'con "habla mas rapido" (15), las 6'
Comparar -20 'con "habla mas despacio" (-20), las 6'
Comparar 400 'con un numero pasado de rosca (400 -> 100)'
Comparar ([int]::MinValue) 'y sin velocidad.txt, que es el arranque'

Write-Host ''
Write-Host '-- el cambio de sitio de los dos reproductores --'
$mPA = [regex]::Match($fuente, '(?ms)^function Play-Audio\b.*?^\}')
Comp 'Play-Audio sigue ahi' $mPA.Success
$pa = $mPA.Value
# Se compara con la ruta que DEVOLVIO el worker. Si algun dia los dos md5 se separasen,
# esto simplemente no acierta: nunca puede sonar otra frase.
Comp 'compara con la ruta que llega, no con la calculada' ($pa -match '\$ruta -eq \$script:preVozRuta')
Comp 'y solo si hay reproductor de repuesto' ($pa -match '\$ruta -eq \$script:preVozRuta -and \$script:reproductorPrevio')
# $script:reproductor tiene que seguir siendo SIEMPRE el que suena: es al que paran
# "callate", el dictado y el cierre limpio.
Comp 'el que suena sigue siendo $script:reproductor' ($pa -match '\$script:reproductor = \$script:reproductorPrevio')
# Con UN reproductor, Open() cortaba solo la frase anterior. Con dos, si el que sale no se
# para a mano, se oirian las dos a la vez.
Comp 'el que sale se para a mano' ($pa -match '\$script:reproductorPrevio\.Stop\(\)')
Comp 'y se cierra, para que la poda pueda borrar el mp3' ($pa -match '\$script:reproductorPrevio\.Close\(\)')
# Sin esto, el segundo Play-Audio de la misma frase volveria a cambiar de sitio los
# reproductores y sonaria el que acaba de cerrarse.
Comp 'el adelanto se da por gastado (preVozRuta = "")' ($pa -match "preVozRuta = ''")
Comp 'y si no acerto, se abre como toda la vida' ($pa -match '\$script:reproductor\.Open\(\[Uri\]\$ruta\)')
# Test-Path sigue siendo lo PRIMERO: un mp3 podado entre el adelanto y el Play no debe
# colarse por el camino rapido.
$primera = (($pa -split "`n") | Where-Object { $_.Trim() } | Select-Object -Skip 1 -First 1)
Comp 'lo primero sigue siendo comprobar que el mp3 existe' ($primera -match 'Test-Path -LiteralPath \$ruta')

Write-Host ''
Write-Host '-- quien lo abre por adelantado --'
$mOA = [regex]::Match($fuente, '(?ms)^function Open-VozAdelantada\b.*?^\}')
Comp 'Open-VozAdelantada existe' $mOA.Success
$oa = $mOA.Value
Comp 'mira la cabeza de la cola sin sacarla' ($oa -match 'charlaFrases\.Peek\(\)')
Comp 'con la cola vacia no hace nada' ($oa -match 'charlaFrases\.Count -eq 0.*return')
# El md5 en cada vuelta del bucle seria tonteria: la cabeza de la cola cambia una vez por
# frase, no mil veces por segundo.
Comp 'solo rehace el md5 si cambio la frase' ($oa -match '\$crudoV -ne \$script:preVozTexto')
Comp 'no reabre lo que ya tiene abierto' ($oa -match 'preVozRuta -eq \$script:preVozCalc')
# El worker tarda ~1 s en una frase nueva. Abrir un .part o un archivo a medias seria
# peor que no adelantar nada.
Comp 'espera a que el mp3 exista de verdad' ($oa -match 'Test-Path -LiteralPath \$script:preVozCalc')
Comp 'usa el mismo texto que al decirla (Get-TextoVoz)' ($oa -match 'Get-TextoVoz \$crudoV')
Comp 'y la misma emocion (Get-EmocionFrase)' ($oa -match 'Get-EmocionFrase \$crudoV')
Comp 'si algo peta, se queda sin adelanto y ya' ($oa -match "catch \{ \`$script:preVozRuta = '' \}")
# Asi se dice la frase de verdad tres mil lineas mas abajo. Si esto cambiara y el adelanto
# no, el md5 dejaria de coincidir sin que nadie se enterase.
Comp 'y asi es como se dice de verdad al desencolar' ($fuente -match 'Say \$fraseC \(Get-EmocionFrase \$fraseC\)')
Comp 'el bucle lo llama cada vuelta' ($fuente -match '\$script:charlaFrases\.Count -gt 0 \) \{ Open-VozAdelantada \}|charlaFrases\.Count -gt 0\) \{ Open-VozAdelantada \}')

Write-Host ''
Write-Host '-- LO QUE NO SE TOCA, QUE ES LO IMPORTANTE --'
# El "+450" de Say-Online NO es margen de cola: es esta misma latencia de Open, y con ella
# se fija pausaHasta, que es LA VENTANA DE SORDINA. Bajarlo a la vez que la latencia
# adelantaria el instante en que Nova vuelve a escuchar, y podria oirse a si misma. Eso es
# una orden equivocada, que es lo peor que le puede pasar.
Comp 'la sordina sigue en +450 (Nova no se oye a si misma)' ($fuente -match '\$n \* 50 \+ 450')
$ui = [System.IO.File]::ReadAllText((Join-Path $raiz 'nova_ui.cs'))
Comp 'y el reloj de la envolvente sigue en -300' ($ui -match '-\s*300')
# El adelanto no puede tocar el orden de la cola ni quien la vacia.
Comp 'nadie saca frases de la cola por adelantado' (-not ($oa -match 'Dequeue|Clear'))
# Sin quitar los comentarios esto salia rojo por el de dentro, que NOMBRA a Say al
# explicar de donde sale el texto. Un banco que lee comentarios no mide el codigo.
$oaCodigo = (($oa -split "`n") | ForEach-Object { $_ -replace '#.*$', '' }) -join "`n"
Comp 'ni dice nada por su cuenta' (-not ($oaCodigo -match '\bSay\b|Play-Audio'))

Remove-Item -LiteralPath $VozCache -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  el mp3 se abre antes de hablar, y la ruta es la misma que calcula el worker'
exit 0
