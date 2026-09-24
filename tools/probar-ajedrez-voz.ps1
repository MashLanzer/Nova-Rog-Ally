# EL PUENTE DEL AJEDREZ: que una frase de braya llegue a la partida, y que una orden normal NO
# (23/09, lo pidio braya).
#
# Lo que se prueba aqui es la TRIPLE LLAVE de Invoke-Ajedrez, que es lo unico que puede
# hacerle dano: (a) sin partida abierta no se mira nada, (b) la frase tiene que tener FORMA de
# jugada con el patron anclado, y (c) python-chess la valida contra las legales. Si falla
# cualquiera, la frase sigue su camino de siempre.
#
# El ajedrez en si -reglas, legalidad, el motor- se prueba en tools\probar-ajedrez.py; aqui
# solo el enganche.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}

# --- dependencias: nada de llamar a Python de verdad, se sustituye el puente ---
$AjedrezOn = $true
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('aj-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
function Log($m) { }
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Test-AjedrezAbierta')
Invoke-Expression (Traer 'Invoke-Ajedrez')
# El selector del mando (funcion 10) se trae DE VERDAD, no se finge: contestar "la primera"
# tiene que cerrarlo, y si algun dia deja de existir esa llamada aqui se vera. Esto lo canto
# el propio banco: al engancharlo, 'la primera' reventaba con "Close-Eleccion no se reconoce".
Invoke-Expression (Traer 'Close-Eleccion')
$script:eleccion = $null
$script:ajedrezPreguntaHasta = 0
# un reloj de mentira: Invoke-Ajedrez mira $sw para caducar la pregunta
$script:relojAj = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:relojAj }
$script:confirmaFin = 0; $script:confirmaTotal = 0
function Set-UI([string]$e, [string]$t = '', [int]$ms = 0) { }
# el puente se sustituye para no arrancar Python en cada caso: lo que interesa aqui es QUE
# argumentos se le mandan, no lo que contesta (eso ya se prueba en probar-ajedrez.py).
$script:llamadas = @()
function Invoke-AjedrezPy([string[]]$args2) {
    $script:llamadas += ($args2 -join ' ')
    return [pscustomobject]@{ decir = 'vale'; hay_partida = $true; opciones = @(); fin = $false }
}

function Pide([string]$f) { $script:llamadas = @(); return (Invoke-Ajedrez $f) }

Write-Host ''
Write-Host '-- sin partida abierta, NADA pasa por aqui --'
$script:ajedrezActiva = $false
foreach ($f in @('caballo foxtrot tres', 'peon echo cuatro', 'retira esa', 'por donde vamos')) {
    $r = Pide $f
    Comp ("'" + $f + "' se va por su camino") ($null -eq $r -and $script:llamadas.Count -eq 0)
}

Write-Host ''
Write-Host '-- empezar se reconoce siempre --'
foreach ($f in @('juguemos al ajedrez', 'juega ajedrez conmigo', 'una partida de ajedrez', 'ajedrez a ciegas')) {
    $r = Pide $f
    Comp ("'" + $f + "'") ($null -ne $r -and $script:llamadas -contains '--empezar')
}

Write-Host ''
Write-Host '-- con partida abierta, una jugada llega --'
$script:ajedrezActiva = $true
foreach ($f in @('caballo foxtrot tres', 'peon echo cuatro', 'echo cuatro', 'torre alfa seis',
                 'caballo a foxtrot tres', 'alfil come en delta cinco', 'enroque corto')) {
    $r = Pide $f
    Comp ("'" + $f + "' llega a la partida") ($script:llamadas.Count -eq 1 -and $script:llamadas[0] -like '--dicho *')
}

Write-Host ''
Write-Host '-- y una ORDEN NORMAL no, aunque haya partida --'
# Estas son ordenes de verdad del log de braya. Es la regla de la casa: tolera que no le
# entienda, no tolera que haga algo que no pidio.
foreach ($f in @('sube el volumen', 'abre steam', 'que hora es', 'cierra el navegador',
                 'pon el modo juego', 'abre la calculadora', 'baja el brillo a la mitad',
                 'cuanta bateria queda', 'no me hables por 10 minutos')) {
    $r = Pide $f
    Comp ("'" + $f + "' NO toca el tablero") ($null -eq $r -and $script:llamadas.Count -eq 0)
}

Write-Host ''
Write-Host '-- las salidas, que es lo que braya exige de cualquier modo --'
foreach ($par in @(@('dejamos la partida', '--cerrar'), @('abandono', '--cerrar'),
                   @('me rindo', '--cerrar'), @('deja el ajedrez', '--cerrar'),
                   @('retira esa', '--deshacer'), @('deshaz', '--deshacer'),
                   @('por donde vamos', '--estado'))) {
    # OJO: la rama de cerrar apaga la partida, asi que hay que volver a abrirla en cada caso.
    # Sin esto, el primer '--cerrar' dejaba $ajedrezActiva en $false y los cinco casos
    # siguientes salian rojos... con el codigo bien.
    $script:ajedrezActiva = $true
    $r = Pide $par[0]
    Comp ("'" + $par[0] + "' -> " + $par[1]) ($script:llamadas.Count -eq 1 -and $script:llamadas[0] -like ($par[1] + '*'))
}
$script:ajedrezActiva = $true
[void](Pide 'abandono')
Comp 'y al cerrar, la partida deja de estar abierta' (-not $script:ajedrezActiva) 'sin esto seguiria capturando frases'

Write-Host ''
Write-Host '-- contestar a la pregunta de las dos parecidas --'
$script:ajedrezActiva = $true
$script:ajedrezPreguntaHasta = 60000
[void](Pide 'la primera'); Comp "'la primera' elige la 1" ($script:llamadas[0] -eq '--elegir 1')
$script:ajedrezPreguntaHasta = 60000
[void](Pide 'el segundo'); Comp "'el segundo' elige la 2" ($script:llamadas[0] -eq '--elegir 2')

Write-Host ''
Write-Host '-- pero SIN pregunta viva, un numero suelto no mueve nada --'
# La partida vive dias entre los diecisiete arranques diarios, y la pregunta se
# guardaba en disco sin caducar: un "dos" suelto tres dias despues hacia la jugada que
# quedo pendiente. Y cada intento arrancaba Python (~1,2 s con el bucle parado) aunque
# no hubiera nada que elegir.
$script:ajedrezPreguntaHasta = 0
foreach ($f in @('la primera', 'la segunda', 'uno', 'dos', 'el segundo')) {
    $r = Pide $f
    Comp "'$f' no elige nada" (($null -eq $r) -and ($script:llamadas.Count -eq 0)) 'ni arranca Python'
}
# y caduca sola al minuto
$script:ajedrezPreguntaHasta = 100
$script:relojAj = 60200
$r = Pide 'la primera'
Comp 'y al minuto ya no vale' (($null -eq $r) -and ($script:llamadas.Count -eq 0)) 'la pregunta se contesta en el momento'

Write-Host ''
Write-Host '-- y donde esta enganchado --'
# EL ORDEN, NO LA DISTANCIA (24/09). Esto media que entre las dos marcas hubiera menos de
# 700 caracteres, asi que cualquier codigo nuevo que se metiera en medio -sin mover nada de
# sitio- ponia el banco rojo. Lo que importa es que el ajedrez se mire ANTES que el camino
# local, y que no haya nada entre medias que se quede la frase.
$iAj = $fuente.IndexOf('$aj = Invoke-Ajedrez $text')
$iLo = $fuente.IndexOf('# 1) local instantaneo')
Comp 'va en Process-Texto, antes del camino local' ($iAj -gt 0 -and $iLo -gt $iAj) "ajedrez en $iAj, local en $iLo"
# y entre los dos no puede haber ningun 'return' que se lleve la frase antes
$entreAj = $fuente.Substring($iAj, [Math]::Max(0, $iLo - $iAj))
Comp 'y nada se lleva la frase por el camino' (@([regex]::Matches($entreAj, '(?m)^\s*return')).Count -le 2) "$(@([regex]::Matches($entreAj, '(?m)^\s*return')).Count) returns en medio"
Comp 'y NO dentro de Invoke-FastCommand' (-not ($fuente -match '(?s)function Invoke-FastCommand.{0,4000}Invoke-Ajedrez')) 'a esa la llaman reglas y perfiles, no braya'
Comp 'se puede apagar desde config' ($fuente -match "Get-Cfg 'juego' 'ajedrez'")
Comp 'y el turno se lanza por proceso, no residente' ($fuente -match '& \$PyExe \$AjedrezPy')


Write-Host ''
Write-Host '-- EL DOCUMENTO NO PUEDE MENTIR --'
# AJEDREZ-COMO-JUGAR.md se escribio porque braya dijo que no entendia como jugar. Un manual
# que promete una frase que Nova no entiende es peor que no tener manual: le manda a decir
# algo que no funciona y a pensar que se ha roto el ajedrez. Asi que aqui se sacan LAS FRASES
# DEL PROPIO DOCUMENTO y se meten por el puente de verdad.
# Se cogen solo las de las listas y las tablas -que son las que le dicen que diga- y se dejan
# fuera las de Nova, que en este documento van siempre en cursiva (entre asteriscos) o
# citadas con >.
$doc = Join-Path $raiz 'AJEDREZ-COMO-JUGAR.md'
Comp 'el documento esta' (Test-Path -LiteralPath $doc) 'AJEDREZ-COMO-JUGAR.md'
$frases = @()
# CON LA CODIFICACION DICHA A MANO: el .md no lleva BOM, y ReadAllLines a secas lo lee
# como ANSI en PowerShell 5.1. Las comillas angulares dejaban de reconocerse y el banco
# sacaba 0 frases del documento, en verde de milagro.
foreach ($ln in [System.IO.File]::ReadAllLines($doc, [System.Text.Encoding]::UTF8)) {
    $t = $ln.Trim()
    if ($t.StartsWith('>')) { continue }
    if (-not ($t.StartsWith('-') -or $t.StartsWith('|'))) { continue }
    # LAS COMILLAS ANGULARES VAN ESCAPADAS, no puestas a pelo: este .ps1 no lleva BOM y
    # PowerShell 5.1 lo lee como ANSI, asi que un caracter no ASCII escrito tal cual llega
    # partido en dos. En un comentario da igual; dentro de un [^...] cambia lo que casa, y
    # el banco sacaba 0 frases del documento estando todo bien.
    foreach ($m in [regex]::Matches($ln, '(\*{0,2})\u00AB([^\u00BB]+)\u00BB(\*{0,2})')) {
        # UNA cursiva es Nova hablando; DOS asteriscos es negrita, y eso lo dice braya. Con
        # un solo asterisco en el patron los dos casos salian iguales y se colaban por Nova
        # trece de las frases que el tiene que decir: el banco decia 17 de 17 mirando la
        # mitad del documento.
        if ($m.Groups[1].Value -eq '*' -and $m.Groups[3].Value -eq '*') { continue }
        $f = ($m.Groups[2].Value -replace '\*\*', '').Trim()
        if ($f.Length -lt 3) { continue }
        if ($f.StartsWith([string][char]0x00BF)) { continue }
        $frases += $f
    }
}
Comp 'y promete frases' ($frases.Count -ge 25) "$($frases.Count) frases del documento"
$entran = 0
foreach ($f in $frases) {
    # "nova," es la palabra de activacion: se la quita el oido antes de llegar aqui
    $limpia = ($f -replace '(?i)^nova\s*,?\s*', '')
    $script:ajedrezActiva = $true
    # "la primera" y compania son RESPUESTAS: el documento las ensena dentro de la
    # seccion de la pregunta, asi que aqui se prueban con una pregunta viva. Que sin
    # ella no valgan es lo correcto, y se comprueba aparte mas abajo.
    $script:relojAj = 0; $script:ajedrezPreguntaHasta = 60000
    $r = Pide $limpia
    $ok = ($null -ne $r) -and ($script:llamadas.Count -ge 1)
    if ($ok) { $entran++ }
    else { Write-Host ("       no  " + $f) }
}
$script:ajedrezPreguntaHasta = 0
Comp 'y Nova entiende todas las que promete' ($entran -eq $frases.Count) "$entran de $($frases.Count)"

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  la jugada llega a la partida, y la orden sigue siendo una orden'
exit 0
