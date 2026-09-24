# LOS FICHEROS POR LOS QUE SE HABLAN LA ESCUCHA, EL ASISTENTE Y LA CAPSULA (22/09).
#
# Los tres procesos se comunican por archivos en tmp\, y ahi habia dos fallos de los que
# solo se ven cuando dos cosas pasan a la vez:
#
# 1. EL ESTADO DEL WORKER MUERTO. escucha-estado.txt lo escribe la escucha y lo leen tres
#    sitios del asistente, y NADIE LO BORRA NUNCA. Cuando el worker muere y arranca otro,
#    lo que se lee es la medicion del muerto hasta que el nuevo escribe su primer pulso.
#    Medido: 214 arranques, 16 s de mediana hasta el primer pulso, 46 s en el p90, y el
#    14 % tarda mas de 30 s. Ninguno de los tres ejecuta una orden -son el aviso de ruido,
#    el aviso de cascos y la respuesta a "como me oyes"-, asi que no abre la puerta a una
#    orden equivocada; lo que hace es que Nova DIGA algo que no es verdad.
#
# 2. LA ESCRITURA ATOMICA QUE SE RENDIA. La escucha escribe con .tmp + os.replace para que
#    nadie lea un archivo a medias. Pero la capsula leia ui-nivel.txt con File.ReadAllText
#    y el asistente el parcial con [File]::ReadAllText, y las dos formas abren SIN permitir
#    que nadie borre o renombre mientras tanto: cuando el replace caia justo ahi, Windows
#    lo tumbaba con "WinError 5: Acceso denegado", la escucha se rendia y escribia encima
#    SIN atomicidad, que es justo la ventana por la que se puede leer una orden a medias.
#    Medido: 20 fallos -14 de ui-nivel.txt, 6 de dictado-parcial.txt- en CUATRO dias
#    distintos, o sea costumbre y no episodio. Y como el contador de la escucha estaba
#    topado a 5 por proceso, 20 es un SUELO.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$wake = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))
$ui = [System.IO.File]::ReadAllText((Join-Path $raiz 'nova_ui.cs'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function SinComentarios([string]$t, [string]$marca = '#') {
    return (($t -split "`n") | ForEach-Object { $_ -replace ($marca + '.*$'), '' }) -join "`n"
}

Write-Host ''
Write-Host '-- 1. la medicion del worker anterior --'
$mFn = [regex]::Match($fuente, '(?ms)^function Test-EstadoFresco\b.*?^\}')
Comp 'existe Test-EstadoFresco' ($mFn.Success)
if (-not $mFn.Success) { Write-Host '  MAL  sin ella no hay nada que probar'; exit 1 }
$mMax = [regex]::Match($fuente, "(?m)^\`$EstadoMaxSegundos = (\d+)")
$tope = if ($mMax.Success) { [int]$mMax.Groups[1].Value } else { -1 }
Comp 'el liston esta en una constante, no escrito dentro' ($tope -gt 0) "$tope s"
# EL LISTON SALE DE COMO SE REFRESCA DE VERDAD: el estado se escribe en CADA vuelta del
# pulso -fuera del filtro de repetidos, por eso se refresca aunque el log calle-, y esas
# vueltas van a 15 s de mediana, 15 s en el p90, 29 s en el p99 y 72 s de maximo (n=2.665).
# Por debajo de 30 s se empezarian a tirar estados buenos; por encima de 120 s ya no
# protege de nada.
Comp 'y esta por encima del p99 de refresco (29 s)' ($tope -ge 30) "$tope s"
Comp 'sin pasarse, que si no no protege' ($tope -le 120)

# LOS TRES LECTORES, uno por uno. Si alguno se queda fuera, sigue diciendo mentiras.
$mRuido = [regex]::Match($fuente, '(?ms)^function Get-OidoConRuido\b.*?^\}')
Comp 'el aviso de ruido la mira' ($mRuido.Value -match 'Test-EstadoFresco')
$mCascos = [regex]::Match($fuente, "(?s)Te quitaste los cascos.{0,80}|.{0,700}Te quitaste los cascos")
Comp 'el aviso de cascos la mira' ($mCascos.Value -match 'Test-EstadoFresco')
$mComo = [regex]::Match($fuente, '(?s)la escucha por voz no esta funcionando.{0,900}')
Comp '"como me oyes" la mira' ($mComo.Value -match 'Test-EstadoFresco')
# y que no quede ningun lector suelto: tantas lecturas como guardas
$nLee = ([regex]::Matches($fuente, 'ReadAllText\(\$RutaEstado\)')).Count
$nGuarda = ([regex]::Matches((SinComentarios $fuente), 'Test-EstadoFresco')).Count - 1   # menos la definicion
Comp 'no queda ningun lector sin guarda' ($nGuarda -ge $nLee) "$nLee lecturas, $nGuarda guardas"

# Y SE EJECUTA, que es lo unico que lo demuestra: un fichero viejo y uno de ahora.
$tmpE = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-est-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
$RutaEstado = $tmpE
$EstadoMaxSegundos = $tope
. ([scriptblock]::Create($mFn.Value))
Set-Content -LiteralPath $tmpE -Value '13.5|0.004|0.31|60|1' -Encoding UTF8
Comp 'un estado recien escrito vale' (Test-EstadoFresco) 'de ahora mismo'
(Get-Item $tmpE).LastWriteTime = (Get-Date).AddSeconds(-($tope + 10))
Comp "uno de hace $($tope + 10) s ya no" (-not (Test-EstadoFresco)) 'el del worker muerto'
(Get-Item $tmpE).LastWriteTime = (Get-Date).AddHours(-6)
Comp 'y uno de hace seis horas, menos' (-not (Test-EstadoFresco))
(Get-Item $tmpE).LastWriteTime = (Get-Date).AddSeconds(-($tope - 5))
Comp "uno de hace $($tope - 5) s sigue valiendo" (Test-EstadoFresco) 'no se tiran los buenos'
Remove-Item -LiteralPath $tmpE -Force -ErrorAction SilentlyContinue
$RutaEstado = Join-Path ([System.IO.Path]::GetTempPath()) 'no-existe-esto.txt'
Comp 'y si no hay fichero, no revienta' (-not (Test-EstadoFresco))

Write-Host ''
Write-Host '-- 2. nadie bloquea el cambio atomico de la escucha --'
# FileShare.Delete es la parte que importa: es la que deja que el os.replace ocurra
# mientras el otro lee. Con ReadWrite solo, el replace sigue fallando.
Comp 'la capsula lee ui-nivel.txt compartiendo' ($ui -match 'FileStream\(rutaNivel')
Comp '  ...y dejando borrar (FileShare.Delete)' `
    ($ui -match '(?s)FileStream\(rutaNivel.{0,200}?FileShare\.ReadWrite \| FileShare\.Delete')
Comp 'ya no usa File.ReadAllText(rutaNivel)' (-not ((SinComentarios $ui '//') -match 'File\.ReadAllText\(rutaNivel\)'))
Comp 'el asistente lee el parcial compartiendo' ($fuente -match 'FileStream\(\$RutaParcial')
Comp '  ...y dejando borrar' `
    ($fuente -match '(?s)FileStream\(\$RutaParcial.{0,300}?FileShare\]::Delete')
Comp 'y lo cierra pase lo que pase (finally)' `
    ($fuente -match '(?s)FileStream\(\$RutaParcial.{0,600}?finally \{.{0,200}?Dispose')
Comp 'ya no usa ReadAllText($RutaParcial)' (-not ((SinComentarios $fuente) -match 'ReadAllText\(\$RutaParcial'))
# el patron que ya existia y del que se copio, que siga
Comp 'y el de rutaEstado, que ya lo hacia bien, sigue' ($ui -match 'FileStream\(rutaEstado')

Write-Host ''
Write-Host '-- 3. y que el log pueda CONTAR si se acabaron --'
$mTope = [regex]::Match($wake, '(?m)^MAX_AVISOS_ESCRIBIR = (\d+)')
$topeAv = if ($mTope.Success) { [int]$mTope.Groups[1].Value } else { -1 }
# Con el tope en 5 por proceso, los 20 del log eran un suelo y no un numero: en cuanto un
# proceso llegaba a cinco, dejaba de contar.
Comp 'el tope de avisos deja contar mas de 20' ($topeAv -gt 20) "$topeAv"
# pero sigue habiendo tope: si el disco falla de verdad, esto escribe en cada palabra
Comp 'y sigue habiendo tope, que si no llena el log' ($topeAv -gt 0 -and $topeAv -le 200) "$topeAv"

Write-Host ''
Write-Host '-- lo que NO puede cambiar --'
# El formato del fichero de estado NO se toca: dos lectores lo parsean por posicion, y
# anteponerle una marca de tiempo los romperia. Por eso se mira la fecha del archivo.
Comp 'el formato del estado sigue siendo por | ' ($wake -match 'def decir_estado')
Comp 'y se sigue leyendo por posicion' ($fuente -match '\$st\[4\]' -and $fuente -match '\$st\[2\]|\$stC\[2\]')
Comp 'Test-EstadoFresco mira la FECHA, no el contenido' ($mFn.Value -match 'LastWriteTime')
# La escritura atomica sigue siendo atomica: lo que se arregla es quien la bloqueaba.
Comp 'la escucha sigue escribiendo con .tmp y replace' ($wake -match 'os\.replace\(tmp, ruta\)')
Comp 'y sigue teniendo su respaldo si falla' ($wake -match 'lo intento directo')

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  nadie lee la medicion del worker muerto, y nadie bloquea el cambio atomico'
exit 0
