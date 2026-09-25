# LOS LOGROS QUE NADIE VE (25/09)
#
# LO MEDIDO: "LOGRO (stats de Steam cambiaron)" sale CINCO veces en dieciseis dias -tres el
# 15/09, una el 19 y una el 20- y ninguna desde entonces. Y NO esta roto el mecanismo: los
# .bin que vigila siguen cambiando, el mas reciente el 24/09 a las 22:41 (A Way Out).
#
# POR QUE NO LO VE, y son dos agujeros del mismo sitio:
#   1. La fecha del fichero ($script:logroStamp) vivia SOLO EN RAM. Nova se apaga y se olvida:
#      lo que pasara mientras no estaba no existio. El 24/09 a las 22:41 cambio el .bin, y en
#      el registro no hay ni una linea entre las 21 y las 23 de ese dia. Estaba apagada.
#   2. Cada vez que el juego sale del primer plano se hace "$script:logroArchivo = ''", y al
#      volver la primera pasada SOLO apuntaba la fecha y se iba con un return. Un logro
#      conseguido entre salir y volver tampoco se veia. El 23/09 hubo dos alt-tab en 70 s.
#
# EL ARREGLO: la fecha se guarda en disco por juego, y al volver -o al arrancar- se compara
# contra lo GUARDADO en vez de contra lo que se acaba de leer.
#
# Y LO QUE NO SE HACE: cantar la primera vez. Sin nada guardado no se sabe si el fichero
# cambio ayer o hace un mes, y una medalla por instalar Nova seria justo el falso positivo que
# le quitaria credito a las de verdad.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. la fecha sobrevive al apagon --'
foreach ($n in @('Get-LogrosStamp', 'Save-LogrosStamp', 'Test-LogroNuevo')) {
    Comp "existe $n" ($sinCom -match ('function ' + $n)) ''
}
Comp 'vive en un fichero de la memoria' ($sinCom -match "LogrosStampPath = Join-Path \`$MemoriaDir 'logros-stamp.json'") ''
# EL PUNTO DEL ARREGLO: la primera pasada tras un alt-tab tiene que COMPARAR, no solo apuntar
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Watch-LogrosSteam' }, $true)
Comp 'se encuentra Watch-LogrosSteam' ($null -ne $d) ''
if ($d) {
    $c = ($d.Extent.Text -split "`n" | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp 'la primera pasada compara con lo guardado' ($c -match 'Test-LogroNuevo \$antesL') 'antes solo apuntaba y se iba'
    Comp '  y guarda la fecha nueva' ($c -match 'Save-LogrosStamp') ''
    $veces = @([regex]::Matches($c, 'Save-LogrosStamp')).Count
    Comp '  en los DOS caminos, no solo en uno' ($veces -ge 2) "$veces; el de volver al juego y el de verlo cambiar en vivo"
    Comp 'y el evento sigue saliendo' ($c -match "Send-UIEvento 'logro'") ''
}

Write-Host ''
Write-Host '-- 2. LA DECISION, SACADA DEL ARCHIVO Y EJECUTADA --'
$dT = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-LogroNuevo' }, $true)
if (-not $dT) { Comp 'se saca Test-LogroNuevo del arbol' $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
Invoke-Expression $dT.Extent.Text
$ayer = [datetime]'2026-09-24 22:41:00'
$hoy = [datetime]'2026-09-25 10:00:00'

# EL DOBLE DEL LOG, para distinguir el $false bueno del $false de un error (25/09). Lo enseno
# una rotura: quitar la guarda de "sin nada guardado" dejaba el banco VERDE, porque el catch
# de la funcion atrapaba el Parse de la cadena vacia y devolvia $false igual... que es TAMBIEN
# la respuesta correcta. Es la manera 10, otra vez y en codigo de hoy. Se arreglo alli -el
# catch deja linea- y aqui se cuenta si la dejo.
$script:quejas = 0
function Log([string]$m) { if ($m -match 'logros: no entiendo la fecha') { $script:quejas++ } }

# LA PRIMERA VEZ NO CANTA
$script:quejas = 0
Comp 'sin nada guardado, no canta' (-not (Test-LogroNuevo '' $hoy)) 'una medalla por instalar Nova no vale'
Comp '  y sale por la guarda, no por el catch' ($script:quejas -eq 0) 'un fichero nuevo NO es una averia'
$script:quejas = 0
Comp '  ni con un null' (-not (Test-LogroNuevo $null $hoy)) ''
Comp '  tambien por la guarda' ($script:quejas -eq 0) ''

# EL CASO QUE ARREGLA: el fichero cambio mientras Nova estaba apagada
Comp 'si cambio mientras no miraba, SI canta' (Test-LogroNuevo ($ayer.ToString('o')) $hoy) 'el caso del 24/09 a las 22:41'

# Y SI NO HA CAMBIADO, NADA
Comp 'la misma fecha no es un logro' (-not (Test-LogroNuevo ($hoy.ToString('o')) $hoy)) ''

# UNA FECHA ANTERIOR NO ES UN LOGRO: es un retroceso (una copia de Steam restaurada)
Comp 'una fecha ANTERIOR tampoco' (-not (Test-LogroNuevo ($hoy.ToString('o')) $ayer)) 'restaurar una copia no da medallas'

# Y UNA FECHA ILEGIBLE NO REVIENTA NI CANTA
$script:quejas = 0
Comp 'una fecha ilegible no canta' (-not (Test-LogroNuevo 'esto no es una fecha' $hoy)) ''
Comp '  ni revienta' $true 'si hubiera reventado, el trap ya habria salido'
Comp '  pero ESTA si lo dice en el log' ($script:quejas -eq 1) 'una fecha corrupta no puede pasar por un dia tranquilo'

Write-Host ''
Write-Host '-- 3. y la clave muerta de habitos.json, fuera --'
# MEDIDO: habitos.minutosJuego se escribia y se leia de disco y NADIE la usaba para nada desde
# el 23/09, cuando la cuenta buena se mudo a memoria\juegos.json (Get-MinutosJuegoHoy). 89
# bytes congelados: no tenia entrada del 24/09 aunque ese dia se jugaron 116 minutos.
# -cnotmatch Y NO -notmatch (25/09, tercer mordisco de las mayusculas en un dia). El -match
# de PowerShell IGNORA mayusculas, asi que 'minutosJuego' casaba dentro de Get-MinutosJuegoHoy
# -que es justo la funcion buena, la que hay que CONSERVAR- y este banco salia rojo con el
# codigo perfectamente limpio. La c de -cnotmatch es la que distingue una cosa de la otra.
Comp 'ya no queda ni un minutosJuego en el codigo' ($txt -cnotmatch 'minutosJuego') 'la clave muerta, no la funcion Get-MinutosJuegoHoy'
Comp 'y la cuenta de verdad sigue ahi' ($sinCom -match 'function Get-MinutosJuegoHoy') 'esa es la que decide el aviso de tiempo'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  los logros ya no se pierden mientras no mira'
exit 0
