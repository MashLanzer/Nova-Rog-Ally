# CUANDO EL OIDO SE ROMPE A MITAD DEL DICTADO, QUE SE NOTE (26/09, idea 5 de las 121).
#
# LO QUE PASO, y esta en el registro con hora: el 25/09 a las 21:33:19 braya la llamo cuatro
# veces seguidas -"ACTIVADO por nova nova nova nova"-. A las 21:33:23, 21:33:27 y 21:33:28 el
# bucle del oido fallo TRES VECES con el mismo error: "name 'callado' is not defined". Las tres
# veces rehizo el reconocedor, que no arregla nada porque el fallo era del codigo. Y lo que
# llego a las 21:33:29 fue "dictado: 8 s sin oir nada" -> "vacio, ignorado" -> "No te escuche".
# La orden se perdio entera y braya se quedo creyendo que Nova no le oia. Otra vez a las 22:48.
#
# TRES COSAS SE ARREGLAN, y la primera es la que causaba todo:
#   1. EL BUG. wake_vosk.py usaba 'callado' CUARENTA Y CINCO LINEAS antes de asignarlo, asi que
#      el primer dictado de cada worker reventaba. Y aunque no hubiera reventado, no hacia lo
#      que decia su comentario: 'callado' vale "no se oyo nada", no "Nova esta hablando", y con
#      'hay_algo' delante "not callado" es cierto siempre. La guarda no frenaba nada.
#   2. REHACER EL RECONOCEDOR NO ARREGLA UN FALLO DEL CODIGO. Si el mismo texto de error vuelve
#      dentro de la ventana, se deja de rehacer y se marca el turno como perdido.
#   3. UN TURNO PERDIDO QUE SE SABE PERDIDO no es un turno vacio: Nova dice "se me ha ido,
#      repitemelo" en vez de "no te escuche", que es mentira y ademas desanima a repetir.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$py = Join-Path $raiz 'wake_vosk.py'
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$tp = [IO.File]::ReadAllText($py, [Text.Encoding]::UTF8)
$ta = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
# SIN COMENTARIOS: los de aqui arriba y los del propio codigo nombran 'callado' para explicar
# el fallo, asi que buscando sobre el texto crudo el banco se encontraria a si mismo.
$pySin = (($tp -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$aSin = (($ta -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. el bug: una variable usada antes de existir --'
# LA COMPROBACION DE VERDAD, y no un grep: se busca CADA uso de 'callado' y se mira si alguno
# esta por encima de su asignacion. Asi vale para este fallo y para el siguiente que se cuele.
$lineas = @($pySin -split "`n")
$iAsigna = -1; $usosAntes = @()
for ($i = 0; $i -lt $lineas.Count; $i++) {
    if ($iAsigna -lt 0 -and $lineas[$i] -match '^\s*callado\s*=') { $iAsigna = $i }
}
Comp "se encuentra donde se asigna 'callado'" ($iAsigna -ge 0) "linea $($iAsigna + 1) del texto sin comentarios"
if ($iAsigna -ge 0) {
    for ($i = 0; $i -lt $iAsigna; $i++) {
        if ($lineas[$i] -match '\bcallado\b' -and $lineas[$i] -notmatch '^\s*callado\s*=' -and
            $lineas[$i] -notmatch 'flojos_callados') { $usosAntes += ($i + 1) }
    }
}
Comp "  y nadie la usa antes" ($usosAntes.Count -eq 0) $(
    if ($usosAntes.Count) { "se usa en la(s) linea(s) " + ($usosAntes -join ', ') + " y se asigna en la $($iAsigna + 1)" }
    else { 'ni un uso por encima de su asignacion' })
# Y LA GUARDA QUE EL COMENTARIO PROMETIA: no adelantar mientras suenan los altavoces.
Comp 'el adelanto no corre con los altavoces sonando' ($pySin -match 'if \(hay_algo and nivel_salida\(\) <= UMBRAL_ALTAVOZ') 'lo que entra por el micro es ella misma'

Write-Host ''
Write-Host '-- 2. el mismo fallo dos veces no se rehace --'
foreach ($cte in @('FALLO_REPETIDO_SEG')) {
    $m = [regex]::Match($tp, ('(?m)^' + $cte + '\s*=\s*(.+)$'))
    Comp ("se saca del archivo " + $cte) $m.Success ''
    if ($m.Success) { Set-Variable -Name $cte -Value ([double]($m.Groups[1].Value.Trim())) }
}
Comp 'la ventana cubre un dictado entero' ($FALLO_REPETIDO_SEG -ge 30) "$FALLO_REPETIDO_SEG s; el tope duro del dictado son 30"
Comp '  y no tanto como para juntar dos' ($FALLO_REPETIDO_SEG -le 120) "$FALLO_REPETIDO_SEG s"
Comp 'se guarda el texto del ultimo fallo' ($pySin -match '_ultimo_fallo') ''
# LA CONDICION ES EL TEXTO EXACTAMENTE IGUAL: es lo que separa un fallo de codigo de un json
# raro de Vosk, que es para lo que se escribio este except. Si fuera "cualquier fallo dos
# veces", se perderia la recuperacion que ya funcionaba.
Comp '  y la condicion es que sea IDENTICO' ($pySin -match '_txt_fallo == _ultimo_fallo\[0\]') 'dos json rotos distintos no dan el mismo texto'
Comp '  con la ventana de la constante' ($pySin -match 'FALLO_REPETIDO_SEG') ''
# Y QUE SIGA REHACIENDOSE LA PRIMERA VEZ: quitar eso seria romper lo que ya funcionaba.
Comp '  la primera vez SI rehace el reconocedor' ($pySin -match 'rec = nuevo_reconocedor\(\)') 'la recuperacion de los json raros no se toca'
Comp '  y avisa en el log de que no lo rehace' ($tp -match 'no rehago el reconocedor') ''

Write-Host ''
Write-Host '-- 3. y el turno perdido se dice, no se calla --'
# EL CANAL TIENE QUE ESCRIBIR EN UN NOMBRE DEFINIDO (26/09, idea 40). Antes esto casaba
# 'escribir(RUTA_DICTADO, "PERDIDO")', pero RUTA_DICTADO no existe: en ejecucion lanzaba
# NameError y el except mudo se lo tragaba, asi que la marca no se escribia NUNCA y el banco
# salia verde sobre una llamada muerta. Ahora se exige el fichero del dictado (TEXTO, sys.argv[7])
# Y que ESE nombre este definido, no solo que la llamada exista.
Comp 'el oido escribe PERDIDO en el fichero del dictado' ($pySin -match 'escribir\(TEXTO, "PERDIDO"\)') 'RUTA_DICTADO no existia: NameError mudo'
Comp '  y TEXTO esta definido (no un nombre inventado)' ($tp -match '(?m)^TEXTO = sys\.argv') 'sys.argv[7], el fichero del dictado'
Comp '  y el fallo al marcarlo ya no se traga' ($pySin -match 'no pude marcar el turno como perdido') 'antes era except: pass'
Comp 'el asistente la reconoce' ($aSin -match "\`$text -eq 'PERDIDO'") ''
# LO QUE IMPORTA: que NO caiga en el camino del dictado vacio, que dice "No te escuche" -una
# mentira- y encima lo apunta como 'error', que es lo que hunde el animo.
$iPerd = $aSin.IndexOf("'PERDIDO'")
$iVacio = $aSin.IndexOf('vacio, ignorado')
Comp '  y lo coge ANTES que el camino del vacio' ($iPerd -ge 0 -and $iVacio -ge 0 -and $iPerd -lt $iVacio) 'si no, diria "No te escuche"'
$bloque = if ($iPerd -ge 0 -and $iVacio -gt $iPerd) { $aSin.Substring($iPerd, $iVacio - $iPerd) } else { '' }
Comp '  lo dice en voz alta' ($bloque -match 'Send-Aviso') 'un turno perdido en silencio es el fallo que se viene a arreglar'
Comp '  con una frase que invita a repetir' ($bloque -match 'Repitemelo') ''
Comp '  y no lo cuenta como "error"' ($bloque -notmatch "Add-Estadistica 'error'") 'error es lo que hunde el animo, y esto no es culpa de braya'
Comp '  sino con su propia clave' ($bloque -match "Add-Estadistica 'oido-roto'") ''

Write-Host ''
Write-Host '-- 4. contra el registro de verdad --'
$logs = @('assistant.log', 'assistant.log.1') | ForEach-Object { Join-Path $raiz $_ } | Where-Object { Test-Path -LiteralPath $_ }
$nFallos = 0; $nCallado = 0
foreach ($lg in $logs) {
    foreach ($l in @(Get-Content -LiteralPath $lg -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match 'fallo en una vuelta del bucle') {
            $nFallos++
            if ($l -match "callado' is not defined") { $nCallado++ }
        }
    }
}
Write-Host ("       el bucle fallo $nFallos veces en el registro, $nCallado de ellas por 'callado'")
Comp 'el fallo que se arregla esta en el registro' ($nCallado -ge 1) 'no es un caso inventado'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el oido roto se nota, y no se arregla rehaciendolo'
exit 0
