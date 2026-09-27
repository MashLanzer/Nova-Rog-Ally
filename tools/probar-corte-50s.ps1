# CUANDO SE CANCELA UN DICTADO A LOS 50 S, MIRAR SI EL OIDO SIGUE VIVO (26/09, idea 35 de 121).
#
# Cuando pasan 50 s de dictado sin que el worker de Vosk entregue texto, la rama de seguridad
# corta y cancela. Hasta hoy cortaba IGUAL en los 59 casos del registro, sin mirar si el worker
# habia muerto o solo se habia quedado mudo. MEDIDO (assistant.log + .1): 59 cancelaciones, en 58
# el worker seguia VIVO -"la mentira duro 38,9 s de media"- y en 1 (1,7 %) habia muerto dentro de
# los 60 s. Ahora la rama mira: MUERTO -> relanza aqui mismo, sin esperar hasta 30 s a la
# vigilancia de mas abajo, respetando SU MISMO contador de 3 intentos; VIVO -> no lo toca y solo
# lo dice, porque matar un worker vivo tiraria una transcripcion que quiza esta llegando (las
# vueltas van a 72 s de maximo) y podria dejarlo huerfano sujetando el micro (regla 5).
#
# NINGUN BANCO tocaba esta rama antes de este: grep de '50000' o 'Sin respuesta del microfono' en
# tools\ solo sacaba probar-arranque-oido, probar-fallo-uso y probar-resumen-dia, y ninguno la
# probaba.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'), [Text.Encoding]::UTF8)
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}

# --------------------------------------------------------------------------------------------
# 1. LA RAMA DE LOS 50 S EXISTE Y SIGUE DENTRO DEL if DE $script:ordenPorWorker. Se saca por
#    llaves desde el elseif del umbral de 50000 hasta su cierre; asi el banco mide EL CODIGO de
#    esa rama, no el archivo entero.
# --------------------------------------------------------------------------------------------
$lineas = $fuente -split "`n"
$iElse = -1
for ($k = 0; $k -lt $lineas.Count; $k++) {
    if ($lineas[$k] -match '-\s*\$script:dictaInicio\)\s*-ge\s*50000\)\s*\{') { $iElse = $k; break }
}
Comp 'existe la rama de corte a los 50 s' ($iElse -ge 0) $(if ($iElse -ge 0) { "linea $($iElse + 1)" } else { 'no se encontro el umbral 50000' })
if ($iElse -lt 0) { Write-Host "  $mal MAL"; exit 1 }

# SACAR EL TROZO POR LLAVES, desde la '{' del elseif.
$desde = $fuente.IndexOf($lineas[$iElse])
$abre = $fuente.IndexOf('{', $desde)

# QUE SIGUE BAJO 'if ($script:armed -and $script:ordenPorWorker)': la cabecera abre ~248 lineas
# mas arriba (cadena larga de elseif), asi que un vistazo de N lineas no llega. Se casa por
# llaves: se coge la cabecera anterior a la rama, se emparejan sus llaves, y se comprueba que el
# elseif de los 50 s cae DENTRO de ese bloque. Asi el banco no depende de la distancia.
$mCab = [regex]::Matches($fuente.Substring(0, $desde), 'if \(\$script:armed -and \$script:ordenPorWorker\)\s*\{')
$dentro = $false
if ($mCab.Count -gt 0) {
    $abreCab = $mCab[$mCab.Count - 1].Index + $mCab[$mCab.Count - 1].Length - 1
    $pr = 0; $finCab = -1
    for ($q = $abreCab; $q -lt $fuente.Length; $q++) {
        $cc = $fuente[$q]
        if ($cc -eq '{') { $pr++ } elseif ($cc -eq '}') { $pr--; if ($pr -eq 0) { $finCab = $q; break } }
    }
    $dentro = ($finCab -gt $desde)
}
Comp 'la rama vive bajo el if de ordenPorWorker' $dentro 'no hace falta guarda de motor aparte'
$prof = 0; $fin = -1
for ($p = $abre; $p -lt $fuente.Length; $p++) {
    $c = $fuente[$p]
    if ($c -eq '{') { $prof++ }
    elseif ($c -eq '}') { $prof--; if ($prof -eq 0) { $fin = $p; break } }
}
Comp 'la rama cierra bien sus llaves' ($fin -gt $abre) ''
$ramaCruda = $fuente.Substring($abre, $fin - $abre + 1)
# SIN LINEAS DE COMENTARIO: la rotura tonta de esta tanda (ya seis veces) es comentar el codigo
# dejando el comentario, que casaba igual. Se filtran las lineas '^\s*#' ANTES de medir, como
# hace probar-oido-mudo.ps1:120.
$rama = (($ramaCruda -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

function Idx([string]$aguja) { return $rama.IndexOf($aguja) }
function Cuenta([string]$aguja) { return @([regex]::Matches($rama, [regex]::Escape($aguja))).Count }

# --------------------------------------------------------------------------------------------
# 2. MIRA SI EL OIDO ESTA VIVO Y CUAN FRESCO. HasExited para decidir, Test-EstadoFresco solo
#    para el texto (ver check 7: la decision NO puede depender de la frescura).
# --------------------------------------------------------------------------------------------
Comp 'mira si el worker esta vivo' ($rama -match 'HasExited') 'HasExited'
Comp 'y arranca por $script:wakeProc -and, nunca .HasExited a pelo' ($rama -match '\$script:wakeProc -and -not \$script:wakeProc\.HasExited') 'wakeProc puede ser $null aqui'
Comp 'lee la frescura del estado' ($rama -match 'Test-EstadoFresco') 'para el texto del log'

# --------------------------------------------------------------------------------------------
# 3. DOS CAMINOS EXCLUYENTES: MUERTO y VIVO, un Log distinto cada uno, partidos por $vivoW.
# --------------------------------------------------------------------------------------------
$iNotVivo = Idx 'if (-not $vivoW)'
$iLogMuerto = Idx 'estaba MUERTO; relanzo'
$iLogVivo = Idx 'el worker sigue vivo'
Comp 'el camino MUERTO va guardado por -not $vivoW' ($iNotVivo -ge 0) ''
Comp 'hay un log para el worker MUERTO' ($iLogMuerto -ge 0) ''
Comp 'y otro distinto para el worker VIVO' ($iLogVivo -ge 0 -and $iLogVivo -ne $iLogMuerto) ''

# --------------------------------------------------------------------------------------------
# 4. CANCELAR EL DICTADO SE HACE SIEMPRE, FUERA DE LOS DOS CAMINOS. Los tres pasos aparecen una
#    sola vez y DESPUES de los dos Logs (si alguien los mete en un camino, se quedan colgados en
#    el otro, que es justo la averia que esta rama tapa).
# --------------------------------------------------------------------------------------------
$iRm = Idx 'Remove-Item -LiteralPath $MarcaDictar'
$iArmed = Idx '$script:armed = $false'
$iHide = Idx '$capture.Hide()'
Comp 'Remove-Item $MarcaDictar aparece una sola vez' ((Cuenta 'Remove-Item -LiteralPath $MarcaDictar') -eq 1) ''
Comp '  y se hace despues de decidir (fuera de los dos caminos)' ($iRm -gt $iLogMuerto -and $iRm -gt $iLogVivo) 'no dentro de una rama'
Comp '$script:armed = $false aparece una vez y fuera' ((Cuenta '$script:armed = $false') -eq 1 -and $iArmed -gt $iLogVivo) ''
Comp '$capture.Hide() aparece una vez y fuera' ((Cuenta '$capture.Hide()') -eq 1 -and $iHide -gt $iLogVivo) ''

# --------------------------------------------------------------------------------------------
# 5. EL RELANZADO: exactamente UN Initialize-Escucha en la rama, DENTRO del camino MUERTO,
#    precedido de $script:wakeIntentos++ y de un Dispose(). Sin esto: bucle infinito de
#    relanzados, o fuga de handles, o relanzar un worker que sigue vivo.
# --------------------------------------------------------------------------------------------
$iInit = Idx 'Initialize-Escucha'
$iInc = Idx '$script:wakeIntentos++'
$iDisp = Idx '.Dispose()'
Comp 'la rama relanza una sola vez' ((Cuenta 'Initialize-Escucha') -eq 1) ''
Comp '  y el relanzado va dentro del camino MUERTO' ($iInit -gt $iNotVivo -and $iInit -lt $iLogVivo) 'nunca en el camino del worker vivo'
Comp '  con $script:wakeIntentos++ delante (no relanza sin fin)' ((Cuenta '$script:wakeIntentos++') -eq 1 -and $iInc -gt $iNotVivo -and $iInc -lt $iInit) 'respeta el techo de 3'
Comp '  y un Dispose() antes de soltar wakeProc (no fuga handles)' ($iDisp -gt $iNotVivo -and $iDisp -lt $iInit) ''
Comp '  respeta el techo de 3 intentos' ($rama -match '\$script:wakeIntentos -lt 3') ''

# --------------------------------------------------------------------------------------------
# 6. EL UNICO Say VA EN EL CAMINO VIVO Y DESPUES DE SU Set-UI. Si estaba muerto y se relanzo,
#    hablar pausaria el worker recien abierto; y del oido caido ya habla el aviso 'oido-mudo'.
# --------------------------------------------------------------------------------------------
$iSay = Idx 'Say '
$iSetUI = Idx "Set-UI 'error'"
Comp 'la rama habla una sola vez' ((Cuenta 'Say ') -eq 1) 'nada de Say en el camino MUERTO'
Comp '  guardado por if ($vivoW)' ($rama -match 'if \(\$vivoW\) \{ Say') 'solo se dice si el oido estaba vivo'
Comp '  y despues del Set-UI (si no, la capsula se lo come)' ($iSay -gt $iSetUI) ''

# --------------------------------------------------------------------------------------------
# 7. TEST-ESTADOFRESCO, CARGADA DE VERDAD (manera 14: se dobla la dependencia -el fichero de
#    estado-, no la pieza). Y el liston sale del archivo, no escrito aqui.
# --------------------------------------------------------------------------------------------
$mMax = [regex]::Match($fuente, "(?m)^\`$EstadoMaxSegundos = (\d+)")
$EstadoMaxSegundos = if ($mMax.Success) { [int]$mMax.Groups[1].Value } else { -1 }
Comp 'el liston de frescura se lee del archivo y es > 0' ($EstadoMaxSegundos -gt 0) "\$EstadoMaxSegundos = $EstadoMaxSegundos"

$base = Join-Path ([IO.Path]::GetTempPath()) ('corte50-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$RutaEstado = Join-Path $base 'escucha-estado.txt'
# sacar la funcion del archivo y cargarla tal cual
$mFn = [regex]::Match($fuente, "(?ms)^function Test-EstadoFresco \{.*?^\}")
Comp 'se encuentra Test-EstadoFresco en el archivo' ($mFn.Success) ''
if ($mFn.Success) {
    Invoke-Expression $mFn.Value
    [IO.File]::WriteAllText($RutaEstado, 'x')
    (Get-Item $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-($EstadoMaxSegundos + 15))
    Comp 'un estado rancio sale NO fresco' (-not (Test-EstadoFresco)) "mas de $EstadoMaxSegundos s"
    (Get-Item $RutaEstado).LastWriteTime = (Get-Date).AddSeconds(-($EstadoMaxSegundos - 10))
    Comp 'y uno de hace un momento sale fresco' (Test-EstadoFresco) 'no se tiran los buenos'
    Remove-Item -LiteralPath $RutaEstado -Force -ErrorAction SilentlyContinue
    Comp 'y sin fichero devuelve NO fresco (no fresquisimo por $null=0)' (-not (Test-EstadoFresco)) 'por eso la decision usa HasExited, no Get-OidoMudoDesde'
}
Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el corte de los 50 s mira si el oido sigue vivo'
exit 0
