# LA CASCADA DEL REPASO (21/09): a quien se le pide repasar cuando Parakeet no saca una
# orden, y en que orden.
#
# Hasta hoy se llamaba siempre a Whisper. Medido con las 214 grabaciones de braya que
# tienen su texto de verdad apuntado, y con la capa local de hoy:
#
#   LA CASCADA                  ORDENES BIEN    MS POR AUDIO DE CADA UNO
#   parakeet                       95/181  52,5 %   1018    <- el primero, no se toca
#   parakeet + canary             118/181  65,2 %    793    <- +23
#   parakeet + canary + omni      124/181  68,5 %   2142    <- +6 mas
#   y whisper base de ultimo recurso                3425    <- lo que se usaba SIEMPRE
#   (whisper small, el oido fino, son 8649 ms)
#
# CANARY GANA PORQUE SE LE PUEDE DECIR EL IDIOMA. Parakeet v3 es multilingue y lo elige
# por frase: 13 de 99 veces eligio mal ("Haben wir", "По фоку"). A Canary se le dice
# src_lang="es" y ya. Por eso saca "Baja el brillo" donde Parakeet saca "Baja el Brio".
#
# Y OMNI APORTA AUNQUE SEA EL PEOR DE LOS TRES (55/181 el solo): se equivoca de forma
# DISTINTA -otra casa, otro entrenamiento, CTC en vez de transducer-, asi que recoge lo
# que a los otros dos se les cae. No hay que mirarlo como "el peor", sino como el tercero.
#
# WHISPER TURBO (large-v3-turbo) SE PROBO Y NO CABE: son ~1,5 GB en RAM y en esta consola,
# con un juego delante, se queda sin sitio. Medirlo mato la propia medicion.
#
# PARAKEET NO SE TOCA: sigue oyendo todas las ordenes. Lo unico que cambia es a quien se le
# pide el repaso, y eso solo pasa cuando lo que Parakeet saco NO es una orden.
#
# LO QUE MAS IMPORTA PROBAR AQUI no es que Canary funcione: es que si NO esta descargado,
# o si falla, TODO SIGA COMO ANTES. Un oido que se rompe es peor que un oido que no mejora.
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- el orden sale de config.json, no esta escrito a fuego --'
Comp 'la cascada se lee de escucha.repasos' ($fuente -match "\`$RepasoCascada = @\(\[string\]\(Get-Cfg 'escucha' 'repasos'")
$cfg = Get-Content -LiteralPath (Join-Path $raiz 'config.json') -Raw | ConvertFrom-Json
$lista = @([string]$cfg.escucha.repasos -split '\s*,\s*' | Where-Object { $_ })
Comp 'y hay una lista configurada' ($lista.Count -ge 1) ($lista -join ' -> ')
Comp 'con Whisper de ultimo recurso' ($lista[-1] -in @('base', 'ultimo')) "el ultimo es '$($lista[-1])'"

Write-Host ''
Write-Host '-- Parakeet NO se toca: sigue siendo el primero --'
# lo que decide que Parakeet manda esta antes y no lo toca la cascada
Comp 'Parakeet se sigue cargando igual' ($oido -match 'from_transducer\(')
Comp 'y sigue siendo el que oye primero' ($oido -match 'def modelo_parakeet\(\)')
Comp 'la cascada solo entra tras Parakeet' ($fuente -match "Log \`"PARAKEET: '\`$texto' no es una orden que entienda; lo repasa \`$quien\`"")

Write-Host ''
Write-Host '-- si Canary no esta, todo sigue como antes (lo mas importante) --'
Comp 'el oido devuelve None si no hay carpeta del modelo' `
    ($oido -match '(?s)carpetas = \[c for c in glob\.glob.{0,200}\*canary\*.{0,200}if not carpetas:.{0,120}_canary_roto = True')
Comp 'y lo dice sin tratarlo como fallo' ($oido -match '# NO es un fallo: si no esta descargado, todo sigue como antes')
Comp 'si Canary falla al cargar, se sigue con Whisper' `
    ($oido -match 'se repasa con Whisper como siempre')
# y el asistente encadena al siguiente en cuanto uno no da orden: con Canary ausente,
# devuelve texto vacio, Test-FastCommand da falso y se pasa a 'base'
Comp 'el asistente encadena al siguiente si uno no da orden' `
    ($fuente -match '\(\$script:repasoPaso \+ 1\) -lt \$RepasoCascada\.Count -and')
Comp 'y solo encadena si NO hubo orden' ($fuente -match '-not \(Test-FastCommand \(\[string\]\$fino\)\.Trim\(\)\)')

Write-Host ''
Write-Host '-- y no se hacen las cosas dos veces --'
Comp 'la nube se lanza solo en el primer paso' ($fuente -match 'if \(\$paso -eq 0\) \{ \[void\]\(Start-NubeOir \$texto\) \}')
Comp 'y el texto original se guarda una vez' ($fuente -match 'if \(\$paso -eq 0\) \{ \$script:repasoOriginal = \$texto \}')
# meter un 'continue' aqui romperia el final de la vuelta del bucle: esta apuntado
Comp 'no se usa continue para salir del bloque' `
    ($fuente -match "poniendo \`$fino a \`$null")

Write-Host ''
Write-Host '-- el oido sabe repasar con Canary --'
Comp 'atender_reintento acepta canary y omni' ($oido -match 'if pedido in \("canary", "omni"\):')
Comp 'y le dice el idioma, que es de lo que va todo' ($oido -match 'src_lang="es", tgt_lang="es"')
Comp 'los carga solo cuando hacen falta' (($oido -match 'def modelo_canary\(\)') -and ($oido -match 'def modelo_omni\(\)'))
# OMNI VA DETRAS DE CANARY A PROPOSITO: a Omnilingual no se le puede decir el idioma
# (from_omnilingual_asr_ctc solo acepta model y tokens), asi que tiene el mismo riesgo que
# Parakeet. Aporta +6 ordenes como TERCER escalon, recogiendo lo que a los otros se les cae.
$iCan = ([array]::IndexOf($lista, 'canary'))
$iOmn = ([array]::IndexOf($lista, 'omni'))
if ($iCan -ge 0 -and $iOmn -ge 0) {
    Comp 'y omni va DETRAS de canary, no delante' ($iCan -lt $iOmn) "canary en $iCan, omni en $iOmn"
}
# EL PLAZO YA NO ES UN NUMERO PELADO (22/09): pasa por plazo_soltar(), que lo encoge cuando
# la consola anda justa de memoria (ver wake_vosk.py, RAM_COMODA / RAM_APRETADA). El banco
# exige las DOS cosas: que sigan siendo el plazo de Parakeet -que es de lo que iba este
# caso- y que vayan envueltos, porque quitar la envoltura los dejaria fijos otra vez sin
# que nadie se enterara.
# EL PLAZO SE CALCULA UNA VEZ Y SE REPARTE (22/09): desde que Parakeet se suelta tambien
# sin juego, soltar_parakeet_si_toca elige el plazo al principio -jugando o quieto- y
# canary y omni usan ESE mismo, que es lo que se quiere: los tres se van juntos.
Comp 'y los suelta con el mismo plazo que a Parakeet' `
    (($oido -match '_canary is not None and \(time\.time\(\) - _canary_uso\) >= plazo') -and
     ($oido -match '_omni is not None and \(time\.time\(\) - _omni_uso\) >= plazo'))
Comp 'y ese plazo distingue si hay juego delante' `
    ($oido -match 'plazo = plazo_soltar\(PARAKEET_SOLTAR_JUGANDO if hay_juego else PARAKEET_SOLTAR_QUIETO\)')
Comp 'y el plazo mira la RAM que queda' ($oido -match 'def plazo_soltar\(')
Comp 'el repaso queda apuntado con su motor' ($oido -match 'motor=pedido')

Write-Host ''
Write-Host '-- y mientras repasa, la capsula no se queda muda --'
# LA CAPSULA MUDA (22/09). Request-WhisperTras terminaba con Set-UI 'pensando' a secas, y
# Set-UI escribe SIEMPRE el texto que le pasan: ese vacio BORRABA de la capsula la frase
# que habia, asi que "no te he pillado, lo estoy repasando" se veia igual que "estoy
# pensando". Medido en assistant.log: 328 repasos, mediana 3,0 s, p90 10 s, el peor 35 s;
# 194 de los 328 llegaron a 3 s o mas.
# AQUI SE EJECUTA LA FUNCION DE VERDAD, no se busca el texto en el fuente: lo que importa
# no es que la linea exista, es lo que acaba recibiendo la capsula.
$astR = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $raiz 'assistant.ps1'), [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $astR.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Invoke-Expression (TraerFn 'Request-WhisperTras')
# el mundo de mentira: lo justo para que corra sin microfono, sin worker y sin nube
$script:uiEst = ''; $script:uiTxt = ''; $script:uiN = 0
function Set-UI([string]$estado, [string]$texto = '', [int]$ms = 0) {
    $script:uiEst = $estado; $script:uiTxt = $texto; $script:uiN++
}
function Log($m) {}
function Add-Estadistica($q, $t = '') {}
function Start-NubeOir($t) { return $false }
$script:reloj = 100000
$sw = [PSCustomObject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }
$script:wakeProc = [PSCustomObject]@{ HasExited = $false }
$RepasoCascada = @('canary', 'base')
$ReintentoMaxMs = 20000
$TmpDir = Join-Path $env:TEMP 'nova-banco-capsula'
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$RutaReintento = Join-Path $TmpDir 'reintento.txt'
$MarcaReintento = Join-Path $TmpDir 'reintento.flag'

Comp 'se pide el repaso' ([bool](Request-WhisperTras 'baja el brio' 0))
Comp 'y la capsula se queda pensando' ($script:uiEst -eq 'pensando')
Comp 'CON TEXTO, no en blanco' ([bool]$script:uiTxt) ("capsula: '" + $script:uiTxt + "'")
Comp 'y dentro sigue lo que se oyo' ($script:uiTxt -like '*baja el brio*')
Comp 'con una etiqueta delante, no solo la frase' ($script:uiTxt -ne 'baja el brio')
Comp 'una sola escritura de capsula por repaso' ($script:uiN -eq 1) "$($script:uiN)"
Comp 'y se le sigue pidiendo al escalon que toca' (([System.IO.File]::ReadAllText($MarcaReintento)) -eq 'canary')
$antesUI = $script:uiTxt
[void](Request-WhisperTras 'baja el brio' 1)
Comp 'el segundo escalon pone lo mismo (no parpadea)' ($script:uiTxt -eq $antesUI)
Comp 'y pasada la cascada no se pide nada' (-not (Request-WhisperTras 'baja el brio' 9))
# LO QUE NO DEBE CAMBIAR: los tres caminos hermanos siguen con su etiqueta de siempre.
Comp "el ultimo recurso sigue diciendo 'Pensandolo mejor'" ($fuente -match "Set-UI 'pensando' 'Pensandolo mejor'")
Comp "y el oido fino, 'Afinando el oido' las dos veces" (([regex]::Matches($fuente, "Set-UI 'pensando' 'Afinando el oido'")).Count -eq 2)

Write-Host ''
Write-Host '-- y el modelo esta donde se espera --'
foreach ($par in @(@{ n = 'canary'; f = @('encoder*.onnx', 'decoder*.onnx', 'tokens.txt') },
                   @{ n = 'omnilingual'; f = @('model*.onnx', 'tokens.txt') })) {
    $dM = @(Get-ChildItem -LiteralPath (Join-Path $raiz 'modelos') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like ('*' + $par.n + '*') })
    if ($dM.Count -eq 0) {
        Write-Host ("  --   {0} no esta descargado: la cascada lo salta y sigue al siguiente" -f $par.n) -ForegroundColor DarkGray
        continue
    }
    Comp ("la carpeta de $($par.n) existe") ($dM.Count -eq 1) $dM[0].Name
    foreach ($f in $par.f) {
        Comp ("  trae $f") (@(Get-ChildItem -LiteralPath $dM[0].FullName -Filter $f).Count -ge 1)
    }
}

Write-Host ''
Write-Host '-- mientras transcribe, la capsula ya no dice "te escucho" --'
# TODO LO DE ARRIBA PASA CON EL MICROFONO CERRADO (22/09). Parakeet, Canary, Omni y
# Whisper trabajan cuando braya ya ha terminado de hablar: 412 veces medidas de cerrar
# el micro a entregar el texto, media 3,48 s, mediana 2,0 s, p90 7,0 s, maximo 37 s, y
# 229 de las 412 por encima de dos segundos. Hasta hoy la capsula se quedaba en
# 'escuchando' todo ese rato, con la onda verde animada y los ojos atentos.
Comp 'la escucha avisa de que ya no oye' `
    ($oido -match 'TRANSCRIBIENDO = os\.path\.join\(os\.path\.dirname\(NIVEL\), "transcribiendo\.flag"\)')
# POR ORDEN, NO POR DISTANCIA (25/09, idea 2). Estas dos comprobaciones decian "que estas
# piezas esten a menos de 600 / 3000 / 400 caracteres", y el commit que hizo que Nova
# transcriba mientras callas metio unas 90 lineas justo dentro de esa ventana: las dos se
# pusieron rojas con el codigo perfectamente bien. Es la bomba de relojeria que denuncia la
# idea 2, mordiendo en el banco que la estrena.
#
# Lo que hay que comprobar es el ORDEN -que la marca se ponga antes de transcribir y se quite
# antes de entregar-, y el orden se mira comparando DONDE esta cada pieza, no cuanto se
# separan. Asi da igual cuanto codigo haya en medio, que es la unica parte que puede crecer.
function Antes([string]$texto, [string]$a, [string]$b) {
    $ia = $texto.IndexOf($a)
    $ib = $texto.IndexOf($b)
    if ($ia -lt 0 -or $ib -lt 0) { return $false }
    return ($ia -lt $ib)
}
Comp 'la marca se pone al cerrar el micro' `
    ($oido.Contains('escribir(TRANSCRIBIENDO, "1")')) ''
# EL BLOQUE, POR SUS LIMITES DE VERDAD. Hay DOS "escribir(TRANSCRIBIENDO, 1)" en el oido -uno
# por cada camino- y comparar posiciones a secas cogia el primero, que es de otro sitio y esta
# antes: salia rojo sin que nada estuviera mal. Asi que se recorta el trozo que va de medir la
# voz a empezar a transcribir, y se comprueba que la marca cae DENTRO. Sin topes de longitud.
$iA1 = $oido.IndexOf('f0_dictado = anotar_voz(audio_dictado)')
$iA2 = $oido.IndexOf('rapido = oir_parakeet(audio_dictado) if')
$trozo = if ($iA1 -ge 0 -and $iA2 -gt $iA1) { $oido.Substring($iA1, $iA2 - $iA1) } else { '' }
Comp '  entre medir tu voz y ponerse a transcribir' `
    ($trozo -and $trozo.Contains('escribir(TRANSCRIBIENDO, "1")')) "$($trozo.Length) caracteres de bloque, sin tope"

Comp 'y se quita ANTES de entregar el texto' `
    (Antes $oido 'os.remove(TRANSCRIBIENDO)' 'escribir(TEXTO, texto_final)') 'si no, el asistente veria "transcribiendo" con el texto ya puesto'
Comp 'el corte con el boton tambien la pone y la quita' `
    ((([regex]::Match($oido, '(?s)el asistente lo corto a mano \(boton\).{0,4000}?escribir\(TEXTO, texto_final\)')).Value -match 'escribir\(TRANSCRIBIENDO') -and
     (([regex]::Match($oido, '(?s)el asistente lo corto a mano \(boton\).{0,4000}?escribir\(TEXTO, texto_final\)')).Value -match 'os\.remove\(TRANSCRIBIENDO'))
Comp 'el asistente sabe donde esta la marca' `
    ($fuente -match '\$RutaTranscribiendo = Join-Path \$TmpDir "transcribiendo\.flag"')
Comp 'y al verla pone la capsula a pensar' `
    ($fuente -match "(?s)if \(-not \`$script:dictaSordo -and \(Test-Path -LiteralPath \`$RutaTranscribiendo\)\) \{.{0,140}Set-UI 'pensando'")
Comp 'un parcial tardio ya no rearma la onda verde' `
    ($fuente -match "\`$estadoCapsula = if \(\`$script:dictaSordo\) \{ 'pensando' \} else \{ 'escuchando' \}")
Comp 'y cada dictado empieza sin marca vieja' `
    ($fuente -match "(?s)Remove-Item -LiteralPath \`$RutaTranscribiendo.{0,40}\r?\n\s*\`$script:dictaSordo = \`$false")

Write-Host ''
Write-Host '-- y lo que NO puede cambiar --'
Comp 'sigue siendo solo visual: ni una palabra nueva' `
    (-not ($fuente -match "(?s)Test-Path -LiteralPath \`$RutaTranscribiendo\)\) \{.{0,400}(Say |Show-Popup|Play-Sonido|Send-UIEvento)"))
Comp 'el estado normal sigue siendo escuchando' ($fuente -match "'pensando' \} else \{ 'escuchando' \}")
Comp 'la red de seguridad de los 50 s sigue en su sitio' `
    ($fuente -match 'dictado sin respuesta del worker; se cancela')
Comp 'la lista de marcas huerfanas del arranque no se ha tocado' `
    ($fuente -match '\$MarcaWake, \$MarcaSalir\)')
Comp 'y la marca no se toca en ningun otro sitio de la escucha' `
    ((([regex]::Matches($oido, 'escribir\(TRANSCRIBIENDO')).Count -eq 2) -and
     (([regex]::Matches($oido, 'os\.remove\(TRANSCRIBIENDO')).Count -eq 2))

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  la cascada del repaso esta puesta, y sin Canary todo sigue como antes'
exit 0
