# UN AMIGO ACABA DE EMPEZAR TU JUEGO (1/10, la 13 de las 20 funciones nuevas)
#
# Nova ya sabia quien esta conectado y a que juega (gameextrainfo) y ya sabia vigilar a uno concreto.
# Faltaba el cruce que importa: que alguien se ponga AL JUEGO QUE TU ESTAS JUGANDO.
#
# LO QUE ESTA SECCION DEFIENDE:
#  1. que sea un FINAL de la maquina de amigos que ya existe y no una maquina nueva: duplicarla
#     serian dos listas que se separan el dia que alguien toque una (la manera 4);
#  2. que NO gaste red sin juego delante, ni mas de una ronda cada cinco minutos (son DOS llamadas);
#  3. que no hable DOS VECES del mismo amigo en el mismo juego;
#  4. y que los nicks de sus amigos salgan marcados como privados, igual que en los otros caminos.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
$AmigoJuegoCadaMin = 5
foreach ($n in @('ConvertTo-Plain', 'Watch-AmigoEnMiJuego', 'Receive-AmigoEnMiJuego')) { Invoke-Expression (Traer $n) }
$script:dicho = @()
function Say([string]$m) { $script:dicho += $m }
function Log([string]$m) { }
$script:pedidas = @()
function Start-AmigoPregunta([string]$fin) { $script:pedidas += $fin; return '' }
$script:reloj = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:reloj }

function Reset {
    $script:dicho = @(); $script:pedidas = @()
    $script:amigoJuegoEn = -999999; $script:amigoJuegoDicho = @{}
    $script:amigoPide = $null; $script:steamPide = $null; $script:steamTask = $null
    $script:respuestaPrivada = $false
    $script:reloj = 0
}

Write-Host ''
Write-Host '-- 1. sin juego delante no gasta ni una peticion --'
Reset
$script:juegoActivo = ''
Watch-AmigoEnMiJuego
Comp 'sin juego, no pregunta' ($script:pedidas.Count -eq 0) "$($script:pedidas.Count) peticiones"

Write-Host ''
Write-Host '-- 2. con juego delante pregunta, y con el final nuevo --'
Reset
$script:juegoActivo = 'Elden Ring De Pega'
Watch-AmigoEnMiJuego
Comp 'con juego, pregunta' ($script:pedidas.Count -eq 1) "$($script:pedidas.Count)"
Comp '  y usa el final "cruzar"' ($script:pedidas[0] -eq 'cruzar') "$($script:pedidas[0])"
# NO MAS DE UNA RONDA CADA CINCO MINUTOS: son dos llamadas a Steam por ronda.
Watch-AmigoEnMiJuego
Watch-AmigoEnMiJuego
Comp '  y no repite antes de los cinco minutos' ($script:pedidas.Count -eq 1) "$($script:pedidas.Count) tras tres rondas"
$script:reloj = 6 * 60000
Watch-AmigoEnMiJuego
Comp '  pero pasados, si' ($script:pedidas.Count -eq 2) "$($script:pedidas.Count)"

Write-Host ''
Write-Host '-- 3. EL CANAL ES DE QUIEN LLEGUE PRIMERO --'
# Si hay algo en vuelo, esta ronda se salta: habra otra en cinco minutos, y la vigilancia de amigos
# no puede quedarse sin canal por esto.
foreach ($par in @(@('amigoPide', 'los amigos'), @('steamPide', 'otra pregunta suya'), @('steamTask', 'el canal'))) {
    Reset
    $script:juegoActivo = 'Elden Ring De Pega'
    Set-Variable -Name $par[0] -Scope script -Value 'ocupado'
    Watch-AmigoEnMiJuego
    Comp ('con ' + $par[1] + ' ocupado, no pide') ($script:pedidas.Count -eq 0) ''
}

Write-Host ''
Write-Host '-- 4. el cruce: solo si es EL MISMO juego --'
Reset
$script:juegoActivo = 'Elden Ring De Pega'
$lista = @(
    @{ id = '1'; nombre = 'Amigo Uno'; online = $true; jugando = 'Otro Juego Cualquiera' },
    @{ id = '2'; nombre = 'Amigo Dos'; online = $true; jugando = '' },
    @{ id = '3'; nombre = 'Amigo Tres'; online = $true; jugando = 'Elden Ring De Pega' }
)
Receive-AmigoEnMiJuego $lista
Comp 'avisa del que juega a lo mismo' ($script:dicho.Count -eq 1 -and $script:dicho[0] -match 'Amigo Tres') "$($script:dicho -join ' | ')"
Comp '  y no nombra a los otros' ($script:dicho[0] -notmatch 'Amigo Uno' -and $script:dicho[0] -notmatch 'Amigo Dos') ''
Comp '  y dice a que se ha puesto' ($script:dicho[0] -match 'Elden Ring De Pega') ''
# LOS NICKS SON SUYOS: esta respuesta tiene que ir marcada como privada, como los otros caminos.
Comp '  y la marca como privada' ($script:respuestaPrivada) 'son los nicks de sus amigos'

Write-Host ''
Write-Host '-- 5. una sola vez por amigo y juego --'
# Si se queda jugando dos horas, se dice al empezar y se acabo.
Receive-AmigoEnMiJuego $lista
Receive-AmigoEnMiJuego $lista
Comp 'no repite al mismo amigo' ($script:dicho.Count -eq 1) "$($script:dicho.Count) tras tres cruces"
# PERO SI SE PONE A OTRO JUEGO QUE TAMBIEN JUEGAS, es otra cosa y se dice
$script:juegoActivo = 'Otro Juego Cualquiera'
Receive-AmigoEnMiJuego $lista
Comp 'pero si cambias de juego y otro lo juega, si' ($script:dicho.Count -eq 2 -and $script:dicho[1] -match 'Amigo Uno') "$($script:dicho[1])"

Write-Host ''
Write-Host '-- 6. lo que NO debe cruzar --'
Reset
$script:juegoActivo = 'Elden Ring De Pega'
# UN NOMBRE DE DOS LETRAS NO CRUZA CON NADA: si no, cualquier juego valdria.
Receive-AmigoEnMiJuego @(@{ id = '9'; nombre = 'X'; online = $true; jugando = 'El' })
Comp 'un nombre de dos letras no cruza' ($script:dicho.Count -eq 0) "$($script:dicho -join '|')"
# y sin juego delante no cruza nada, aunque llegue la lista
Reset
$script:juegoActivo = ''
Receive-AmigoEnMiJuego $lista
Comp 'sin juego delante no cruza nada' ($script:dicho.Count -eq 0) ''

Write-Host ''
Write-Host '-- 7. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'el bucle lo vigila' ($sinCom -match 'Watch-AmigoEnMiJuego') ''
Comp 'y el final "cruzar" esta en la maquina de amigos' ($sinCom -match "if \(\`$finP -eq 'cruzar'\) \{ Receive-AmigoEnMiJuego") ''
# Y NO SE HA DUPLICADO LA MAQUINA: sigue habiendo UNA sola Receive-AmigoPregunta.
Comp '  y la maquina de amigos sigue siendo una' ((@([regex]::Matches($sinCom, 'function Receive-AmigoPregunta')).Count) -eq 1) 'dos se separarian'
# Y EL CRUCE VA ANTES del 'listaP.Count -eq 0': si no, con cero amigos conectados esta vigilancia
# diria en alto "No veo a ningun amigo", que es hablar por hablar en algo que nadie pregunto.
# SE MIDE DENTRO DE SU FUNCION, no en todo el fichero: 'No veo a ningun amigo' aparece antes en otro
# sitio y el IndexOf global comparaba con el que no era. Primer intento de escribir esta linea.
# SE MIDE DENTRO DE SU FUNCION Y CONTRA LA LINEA CONCRETA: 'No veo a ningun amigo' sale DOS veces
# ahi -una por cada paso de la maquina- asi que comparar contra el texto comparaba con el que no era.
# Dos intentos me costo esta linea.
$cuerpoRec = Traer 'Receive-AmigoPregunta'
$iCruzar = $cuerpoRec.IndexOf("'cruzar'")
$iVacia = $cuerpoRec.IndexOf('if ($listaP.Count -eq 0)')
Comp '  y el cruce va antes de la queja de la lista vacia' ($iCruzar -gt 0 -and $iVacia -gt $iCruzar) 'una vigilancia no habla para decir "nadie"'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova avisa cuando un amigo se pone a tu mismo juego' -ForegroundColor Green
exit 0
