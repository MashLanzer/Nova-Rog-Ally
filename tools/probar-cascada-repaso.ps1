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
Comp 'y los suelta jugando, como a Parakeet' `
    (($oido -match '_canary is not None and \(time\.time\(\) - _canary_uso\) >= plazo_soltar\(PARAKEET_SOLTAR_JUGANDO\)') -and
     ($oido -match '_omni is not None and \(time\.time\(\) - _omni_uso\) >= plazo_soltar\(PARAKEET_SOLTAR_JUGANDO\)'))
Comp 'y el plazo mira la RAM que queda' ($oido -match 'def plazo_soltar\(')
Comp 'el repaso queda apuntado con su motor' ($oido -match 'motor=pedido')

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

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  la cascada del repaso esta puesta, y sin Canary todo sigue como antes'
exit 0
