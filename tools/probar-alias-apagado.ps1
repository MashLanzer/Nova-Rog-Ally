# LA PREGUNTA DE ALIAS, APAGADA (22/09).
#
# Cuando Nova traducia una frase y la diferencia era UNA palabra, se ofrecia a aprenderla
# para siempre: "¿Quieres que X sea siempre Y?". Once dias de log, cinco preguntas:
#   15/09 13:14  'ponga'   -> spotify   NO
#   15/09 15:42  'google'  -> edge      NO
#   18/09 20:11  'cancion' -> spotify   NO
#   18/09 20:12  'cancion' -> spotify   NO   (la MISMA, 51 s despues)
#   22/09 01:14  'ajutos'  -> ajustes   SI... y fue la mala: 'ajutos' salia de una orden mal
#                oida y acabo metiendo  "ajutos": ""  en commands.json.
# Cero de cinco. Y no es gratis: entre 5 y 8 s medidos por pregunta, y ademas se come el
# SEGUIMIENTO, porque en el bucle es la PRIMERA rama de la cadena de elseif que hay justo
# despues de Reanudar-Escucha. O sea que se paga velocidad -lo que mas le importa a braya-
# por una apuesta a futuro, y encima justo despues de una orden que YA habia salido bien.
#
# Y ES REDUNDANTE: la frase exacta se guarda en traducciones.json un segundo antes
# (Add-Traduccion). Lo unico que anadia la pregunta era generalizar a OTRAS frases, que es
# justo la parte que puede envenenar el vocabulario.
#
# NO SE BORRA NADA: el candidato se APUNTA en el log, y con "aprender": {"preguntarAlias":
# true} en config.json vuelve la pregunta. Si dentro de un mes el log tiene candidatos que
# braya habria querido, se enciende. Con datos, que es como se decide aqui.
#
# De camino salieron dos filtros que SI valen, y aqui se prueban los dos contra los cinco
# casos de verdad.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA DEL BANCO (van veinte): Find-Generalizacion y las tres que llama por dentro se
# TRAEN de assistant.ps1, con el commands.json de verdad.
foreach ($fn in @('ConvertTo-Plain', 'Test-Prop', 'Get-Distancia', 'Find-Generalizacion')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\[].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0}' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
$mPC = [regex]::Match($fuente, '(?m)^\$PALABRAS_COMUNES = .*$')
if (-not $mPC.Success) { Write-Host '  MAL  no encuentro PALABRAS_COMUNES'; exit 1 }
. ([scriptblock]::Create($mPC.Value))
$script:apuntado = @()
function Log([string]$msg) { $script:apuntado += $msg }
$cmds = Get-Content -LiteralPath (Join-Path $raiz 'commands.json') -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host ''
Write-Host '-- el "o" que no era un "o" --'
# ASI ESTABA ESCRITO: if (Test-Prop $cmds.apps $x -or Test-Prop $cmds.sitios $x)
# PowerShell no lee ahi un "o" logico: lee UNA sola llamada a Test-Prop con "-or",
# "Test-Prop", "$cmds.sitios" y "$x" de argumentos sueltos. Asi que la lista de SITIOS no
# se miraba NUNCA, y por eso el 15/09 pregunto si "google" era siempre "edge" teniendo
# google en $cmds.sitios desde el primer dia.
Comp 'google esta en los sitios desde siempre' ([bool](Test-Prop $cmds.sitios 'google'))
$comoEstaba = (Test-Prop $cmds.apps 'google' -or Test-Prop $cmds.sitios 'google')
$comoQueda = ((Test-Prop $cmds.apps 'google') -or (Test-Prop $cmds.sitios 'google'))
Comp 'sin parentesis daba que NO lo conocia' (-not $comoEstaba) 'el fallo, reproducido'
Comp 'con parentesis dice que SI' ($comoQueda) 'el arreglo'
Comp 'y en el fichero estan puestos' ($fuente -match '\(Test-Prop \$cmds\.apps \$alias\[0\]\) -or \(Test-Prop \$cmds\.sitios \$alias\[0\]\)')
# Y de paso las correcciones, que el comentario de al lado prometia desde siempre y nadie
# habia llegado a mirar.
Comp 'ahora tambien mira las correcciones' ($fuente -match 'Test-Prop \$cmds\.correcciones \$alias\[0\]')
Comp 'que existen de verdad en commands.json' (@($cmds.correcciones.PSObject.Properties).Count -gt 0) `
    "$(@($cmds.correcciones.PSObject.Properties).Count) correcciones"

Write-Host ''
Write-Host '-- los cinco casos de verdad, contra el codigo de hoy --'
# El de 'google' ya no llega ni a candidato, porque el "o" arreglado lo caza.
$g = Find-Generalizacion 'abre google' 'abre edge'
Comp "'google' -> 'edge' ya ni se propone" ($null -eq $g) '(lo mata el "o" arreglado)'
# 'ajutos' esta a DOS ediciones de 'ajustes': no era un apodo, era "ajustes" mal oido, y
# aprenderlo habria sido atar una orden buena a un fallo del microfono.
$script:apuntado = @()
$a = Find-Generalizacion 'abre los ajutos' 'abre ajustes'
Comp "'ajutos' -> 'ajustes' ya ni se propone" ($null -eq $a) '(lo mata el parecido)'
Comp 'y dice por que' (($script:apuntado -join ' ') -match 'se parece demasiado')
# 'ponga' y 'cancion' SIGUEN pasando, y hay que decirlo: son palabras normales del
# castellano y Nova no tiene diccionario. Tres preguntas malas de cinco no es un liston, y
# por eso ademas de los filtros se apaga la pregunta.
$p = Find-Generalizacion 'ponga musica' 'pon spotify'
$c = Find-Generalizacion 'pon una cancion' 'pon spotify'
Comp "'ponga' y 'cancion' siguen pasando los filtros" ($null -ne $p -or $null -ne $c) `
    'por eso ademas se apaga la pregunta'

Write-Host ''
Write-Host '-- pero un apodo de verdad sigue valiendo --'
# Un apodo no se parece letra a letra: se parece en que es mas corto. 'calcu' esta a 6
# ediciones de 'calculadora' y no lo toca el filtro del parecido.
$k = Find-Generalizacion 'abre la calcu' 'abre calculadora'
Comp "'calcu' -> 'calculadora' sigue siendo candidato" ($null -ne $k) `
    $(if ($k) { "$($k.alias) -> $($k.objetivo)" } else { 'no lo propone' })
Comp 'la distancia de calcu a calculadora' ((Get-Distancia 'calcu' 'calculadora') -gt 2) `
    "$(Get-Distancia 'calcu' 'calculadora') ediciones"
Comp 'y la de ajutos a ajustes' ((Get-Distancia 'ajutos' 'ajustes') -le 2) `
    "$(Get-Distancia 'ajutos' 'ajustes') ediciones"

Write-Host ''
Write-Host '-- el interruptor --'
$mSw = [regex]::Match($fuente, "(?m)^\`$PreguntarAlias = \[bool\]\(Get-Cfg 'aprender' 'preguntarAlias' (\`$\w+)\)")
Comp 'el interruptor sale de config.json' ($mSw.Success)
Comp 'y viene APAGADO de fabrica' ($mSw.Success -and $mSw.Groups[1].Value -eq '$false') $mSw.Groups[1].Value
$cfg = Get-Content -LiteralPath (Join-Path $raiz 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$puesto = $null -ne $cfg.PSObject.Properties['aprender'] -and $null -ne $cfg.aprender.PSObject.Properties['preguntarAlias']
Comp 'en config.json esta apagado o no esta' (-not $puesto -or -not $cfg.aprender.preguntarAlias) `
    $(if ($puesto) { "puesto a $($cfg.aprender.preguntarAlias)" } else { 'no esta puesto (vale el de fabrica)' })
# EL CANDIDATO SE APUNTA SIEMPRE. Esa linea del log es la que dejara volver a decidirlo
# dentro de un mes: sin ella, apagar la pregunta seria quedarse sin los datos para saber si
# habia que apagarla.
$mRep = [regex]::Match($fuente, '(?s)if \(\$gen\) \{ Log "ALIAS candidato.{0,200}?\}')
Comp 'el candidato se apunta pase lo que pase' ($mRep.Success)
Comp 'con el alias y el objetivo' ($mRep.Value -match '\$\(\$gen\.alias\)' -and $mRep.Value -match '\$\(\$gen\.objetivo\)')
Comp 'y solo se PREGUNTA con el interruptor' ($fuente -match 'if \(\$gen -and \$PreguntarAlias\)')
# El orden importa: si el apunte fuera despues del if del interruptor, apagada la pregunta
# no se apuntaria nada.
$iLog = $fuente.IndexOf('Log "ALIAS candidato')
$iSi = $fuente.IndexOf('if ($gen -and $PreguntarAlias)')
Comp 'y se apunta ANTES de mirar el interruptor' ($iLog -gt 0 -and $iSi -gt $iLog)

Write-Host ''
Write-Host '-- lo que NO cambia --'
# La frase exacta se sigue guardando: eso es lo que hace que la proxima vez que braya diga
# lo mismo, Nova lo entienda sin preguntar nada.
Comp 'la frase exacta se sigue aprendiendo (Add-Traduccion)' ($fuente -match 'function Add-Traduccion')
Comp 'y sigue llamandose al traducir' (([regex]::Matches($fuente, '\bAdd-Traduccion ')).Count -ge 1)
# Test-OidoDudoso seguia delante y sigue: si el oido no estaba claro, ni candidato.
Comp 'si el oido fue dudoso, ni candidato' ($fuente -match 'if \(Test-OidoDudoso \$original\) \{ \$null \}')
# La maquinaria de responder si/no a la pregunta sigue entera, para cuando se encienda.
Comp 'la maquinaria del si/no sigue entera' ($fuente -match '\$script:aprenderPendiente = @\{ alias =')
Comp 'y el filtro de palabras comunes no se ha tocado' ($PALABRAS_COMUNES.Count -ge 30) `
    "$($PALABRAS_COMUNES.Count) palabras"

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  la pregunta de alias ya no interrumpe, y el candidato queda apuntado'
exit 0
