# CORREGIR HABLANDO LO QUE NOVA CREE SABER DE TI (23/09, idea 7).
#
# TRES COSAS QUE ESTABAN MAL, medidas ejecutando el codigo de verdad, no leyendolo:
#
#  1. EL FILTRO "no guardo lo que habla de mi" SE COMIA LAS CORRECCIONES DE TRATO. De los 10
#     rechazos de catorce dias, OCHO eran instrucciones sobre como hablarle. El arreglo del
#     21/09 pedia 'prefiere que no' PEGADO, y las frases reales dicen 'prefiere que NOVA no':
#     por eso siguieron cayendo el 22/09 a las 01:13:49 ("Braya prefiere que Nova no lea la
#     pantalla sin ser pedido") y a las 21:49:05 ("braya prefiere que Nova no le hable durante
#     ciertos periodos"), las dos POSTERIORES a ese arreglo.
#
#  2. Remove-DatoPerfil BORRABA LO QUE NO ERA. Comparaba con Contains() a pelo, sin ancla de
#     palabra: "la captura de la pantalla, eliminalo" se llevaba "Braya guarda las capturas en
#     D:\Capturas" -porque "captura" esta DENTRO de "capturas"- y "el recordatorio del
#     dentista, eliminalo" se llevaba "Braya tiene cita con el dentista el jueves". Ninguna de
#     las dos frases pedia borrar nada del perfil: eso es Nova haciendo algo que braya no
#     pidio, que es la regla 1.
#
#  3. "ESO ES FALSO, ELIMINALO" NO APUNTABA A NADA DESPUES DE UN ARRANQUE, y Nova arranca 244
#     veces en 15 dias (16,3 al dia).
#
# Y faltaba lo otro: que se pueda DESHACER un borrado hablando.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el andamio: perfil de mentira en un temporal y reloj de mentira ---------
$script:ahoraMs = 0
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { $script:ahoraMs }
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('pf-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$PerfilPath = Join-Path $tmp 'perfil.md'
$PerfilMax = 60
$script:logs = @()
function Log([string]$m) { $script:logs += $m }
function Add-Estadistica($a, $b) { }
function Set-AcabaDeAprender { }
function Get-PalabrasNo { return @() }
$script:invitado = $false
$script:ultimoDatoPerfil = ''
$script:perfilQuitado = $null
foreach ($n in @('ConvertTo-Plain', 'ConvertTo-Suave', 'Get-DatosPerfil', 'Save-DatosPerfil',
                 'Test-DatoTrato', 'Add-DatoPerfil', 'Remove-DatoPerfil', 'Get-UltimoDatoPerfil')) {
    Invoke-Expression (Traer $n)
}
$RE_DATO_SENSIBLE = [regex]::Match($fuente, '(?m)^\$RE_DATO_SENSIBLE\s*=\s*(.+)$').Groups[1].Value
$RE_DATO_SENSIBLE = Invoke-Expression $RE_DATO_SENSIBLE

# EL PERFIL DE PRUEBA sale de datos con la MISMA forma que los suyos: tercera persona,
# empezando por "Braya", y con los dos pares que de verdad se pisaban en su perfil.
$basePerfil = @(
    'Braya tiene cita con el dentista el jueves',
    'Braya guarda las capturas en D:\Capturas',
    'Braya juega a It Takes Two con su novia',
    'Braya anota sus partidas en un cuaderno',
    'Braya usa Discord para hablar con sus amigos',
    'Braya vio un oso polar en el zoo',
    'Braya prefiere respuestas cortas',
    'Braya tiene un mando de Xbox',
    'Braya escucha musica mientras juega',
    'Braya toca la guitarra los domingos'
)
function Poner($datos) { Save-DatosPerfil @($datos); $script:ultimoDatoPerfil = ''; $script:perfilQuitado = $null }

Write-Host ''
Write-Host '-- 1. las correcciones de trato son datos, las opiniones no --'
# Las dos primeras son SUS frases, copiadas del registro, con la hora a la que se tiraron.
Comp 'la del 22/09 01:13:49 pasa' (Test-DatoTrato 'Braya prefiere que Nova no lea la pantalla sin ser pedido')
Comp 'la del 22/09 21:49:05 pasa' (Test-DatoTrato 'braya prefiere que Nova no le hable durante ciertos periodos')
Comp 'no le gusta que le llamen tio' (Test-DatoTrato 'A braya no le gusta que Nova le diga tio')
Comp 'pidio que deje de preguntar tanto' (Test-DatoTrato 'Braya pidio que Nova deje de preguntar tanto')
Comp 'quiere que le avise antes de abrir nada' (Test-DatoTrato 'Braya quiere que Nova le avise antes de abrir nada')
Comp 'una opinion sobre Nova NO es trato' (-not (Test-DatoTrato 'Braya considera que Nova se equivoca frecuentemente')) 'es queja'
Comp 'ni "siente que no le entiende"' (-not (Test-DatoTrato 'Braya siente que Nova no entiende bien lo que dice'))
Comp 'ni un dato normal' (-not (Test-DatoTrato 'Braya juega a It Takes Two con su novia'))

Write-Host ''
Write-Host '-- 2. y por eso Add-DatoPerfil ya no las tira --'
Poner $basePerfil
$r1 = Add-DatoPerfil 'Braya prefiere que Nova no lea la pantalla sin ser pedido' 'charla'
Comp 'se guarda la del 01:13:49' ($null -ne $r1) $(if ($r1) { 'guardada' } else { ($script:logs | Select-Object -Last 1) })
Poner $basePerfil
$r2 = Add-DatoPerfil 'braya prefiere que Nova no le hable durante ciertos periodos' 'charla'
Comp 'se guarda la del 21:49:05' ($null -ne $r2)
Poner $basePerfil
$r3 = Add-DatoPerfil 'Braya considera que Nova se equivoca frecuentemente' 'charla'
Comp 'y la queja sobre Nova sigue fuera' ($null -eq $r3) 'regla: el perfil no habla de Nova'
Poner $basePerfil
$r4 = Add-DatoPerfil 'Braya probablemente juega de noche' 'charla'
Comp 'y la deduccion, tambien' ($null -eq $r4)

Write-Host ''
Write-Host '-- 3. LAS DOS FRASES QUE BORRABAN LO QUE NO ERA --'
# Estas dos son las que cantan. Si alguien devuelve el Contains() crudo, o baja el piso a 1,
# las dos vuelven a llevarse un dato del perfil que braya no pidio borrar.
Poner $basePerfil
$q1 = Remove-DatoPerfil 'el recordatorio del dentista'
Comp '"el recordatorio del dentista" no borra nada' ($null -eq $q1) $(if ($q1) { "SE LLEVO: $q1" } else { '' })
Comp 'y el perfil sigue con sus 10' ((Get-DatosPerfil).Count -eq 10) "$((Get-DatosPerfil).Count)"
Poner $basePerfil
$q2 = Remove-DatoPerfil 'la captura de la pantalla'
Comp '"la captura de la pantalla" no borra nada' ($null -eq $q2) $(if ($q2) { "SE LLEVO: $q2" } else { '' })
Poner $basePerfil
$q3 = Remove-DatoPerfil 'mi juego favorito es It Takes Two'
Comp 'pero "mi juego favorito es It Takes Two" SI borra el suyo' ($q3 -eq 'Braya juega a It Takes Two con su novia') "$q3"

Write-Host ''
Write-Host '-- 4. la raiz de cuatro letras, y el ancla de palabra --'
Poner $basePerfil
$q4 = Remove-DatoPerfil 'olvida lo de la captura de pantalla que guardo'
Comp 'singular contra plural SI se emparejan' ($q4 -eq 'Braya guarda las capturas en D:\Capturas') "$q4"
Poner $basePerfil
$q5 = Remove-DatoPerfil 'la nota'
Comp '"nota" no se cuela dentro de "anota"' ($null -eq $q5) $(if ($q5) { "SE LLEVO: $q5" } else { 'el ancla aguanta' })
Poner $basePerfil
$q6 = Remove-DatoPerfil 'el oso polar'
Comp 'y "el oso polar" sigue borrando el suyo' ($q6 -eq 'Braya vio un oso polar en el zoo') "$q6"

Write-Host ''
Write-Host '-- 5. una palabra comun no borra un dato al azar --'
# "braya" sale en los 10 datos de prueba, igual que en 28 de sus 60 de verdad.
Poner $basePerfil
$q7 = Remove-DatoPerfil 'braya'
Comp '"braya" solo no borra nada' ($null -eq $q7) $(if ($q7) { "SE LLEVO: $q7" } else { '' })
Poner $basePerfil
$q8 = Remove-DatoPerfil 'guitarra'
Comp 'pero una palabra rara si' ($q8 -eq 'Braya toca la guitarra los domingos') "$q8"

Write-Host ''
Write-Host '-- 6. el ultimo dato sobrevive al arranque --'
Poner $basePerfil
$script:ultimoDatoPerfil = ''
Comp 'sin variable, lo saca del fichero' ((Get-UltimoDatoPerfil) -eq 'Braya toca la guitarra los domingos') "$(Get-UltimoDatoPerfil)"
$script:ultimoDatoPerfil = 'Braya tiene un mando de Xbox'
Comp 'y si hay variable, manda la variable' ((Get-UltimoDatoPerfil) -eq 'Braya tiene un mando de Xbox')
$script:ultimoDatoPerfil = ''
(Get-Item -LiteralPath $PerfilPath).LastWriteTime = (Get-Date).AddMinutes(-45)
Comp 'un perfil de hace 45 min ya no vale' ((Get-UltimoDatoPerfil) -eq '') 'no adivina a que te refieres'

# --- los IF de verdad de Invoke-FastCommand, en su orden ---------------------
# Aqui no vale mirar el patron suelto: lo que importa es QUE hace el cuerpo, y en que orden
# se prueban. Se sacan del arbol los if de Invoke-FastCommand que tocan el perfil y se
# replican en el mismo orden, parando en el primero que contesta: eso es lo que pasa de
# verdad. Asi se ve si un patron se come al de abajo (paso dos veces hoy con la idea 11-B).
$ifn = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Invoke-FastCommand' }, $true)
$cands = @()
foreach ($x in $ifn.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)) {
    if ($x.Extent.Text -match 'Remove-DatoPerfil|perfilQuitado') { $cands += $x }
}
# SOLO LOS DE PRIMER NIVEL: FindAll baja tambien a los if de DENTRO de un if, y el deshacer
# lleva uno. Colado en la fila, ese hijo contestaria fuera de su sitio y la fila dejaria de
# ser la de verdad.
$bloques = @()
foreach ($x in $cands) {
    $dentro = $false
    foreach ($y in $cands) {
        if ($y -ne $x -and $y.Extent.StartOffset -le $x.Extent.StartOffset -and $y.Extent.EndOffset -ge $x.Extent.EndOffset) { $dentro = $true }
    }
    if (-not $dentro) { $bloques += $x.Extent.Text }
}
function Decir([string]$frase) {
    foreach ($b in $bloques) {
        $r = & { $text = $frase; Invoke-Expression $b }
        if ($r) { return [string]$r }
    }
    return ''
}

Write-Host ''
Write-Host '-- 7. los tres if del perfil salen del arbol --'
Comp 'hay cuatro: olvida-que, eso-es-falso, deshacer y el cajon' ($bloques.Count -eq 4) "$($bloques.Count)"

Write-Host ''
Write-Host '-- 8. y puestos en fila, hacen lo que toca --'
Poner $basePerfil
$d1 = Decir 'el recordatorio del dentista, eliminalo'
Comp 'la frase del dentista no contesta' ($d1 -eq '') "$d1"
Comp 'y no se ha ido ningun dato' ((Get-DatosPerfil).Count -eq 10) "$((Get-DatosPerfil).Count)"
Poner $basePerfil
$d2 = Decir 'el oso polar, eliminalo'
Comp 'la del oso polar si borra' ($d2 -match 'oso polar') "$d2"
Comp 'y quedan nueve' ((Get-DatosPerfil).Count -eq 9) "$((Get-DatosPerfil).Count)"

Write-Host ''
Write-Host '-- 9. DESHACER: la otra mitad de la regla 1 --'
$script:ahoraMs = 1000
$d3 = Decir 'vuelve a ponerlo'
Comp 'lo devuelve' ($d3 -match 'oso polar') "$d3"
Comp 'y vuelven a ser diez' ((Get-DatosPerfil).Count -eq 10) "$((Get-DatosPerfil).Count)"
Comp 'y ahora "eso es falso" apunta a el' ((Get-UltimoDatoPerfil) -eq 'Braya vio un oso polar en el zoo')
$d4 = Decir 'vuelve a ponerlo'
Comp 'dos veces seguidas no lo duplica' ($d4 -notmatch 'oso polar') "$d4"
Comp 'siguen siendo diez' ((Get-DatosPerfil).Count -eq 10) "$((Get-DatosPerfil).Count)"
Poner $basePerfil
$script:ahoraMs = 1000
[void](Decir 'el oso polar, eliminalo')
$script:ahoraMs = 1000 + 301000
$d5 = Decir 'ponlo otra vez'
Comp 'pasados cinco minutos, ya no' ($d5 -notmatch 'oso polar') "$d5"
Comp 'y contesta algo, no se queda callada' ($d5 -ne '') "$d5"
Comp 'la ventana no deja el dato fuera para siempre' ((Get-DatosPerfil).Count -eq 9) 'sigue borrado, que es lo pedido'

Write-Host ''
Write-Host '-- 10. y el banco -Probar lo ve en local, no lo manda a la IA --'
$tf = SinComentarios (Traer 'Test-FastCommand')
Comp 'Test-FastCommand tiene el espejo del deshacer' ($tf -match 'vuelve\\s\+a\\s\+ponerlo')

Write-Host ''
Write-Host '-- 11. la poda no se come las instrucciones de trato --'
# Un dato de trato es justo lo que braya repite y lo que mas le molesta perder. La poda tira
# "lo que lleva mas sin repetirse", y antes eso incluia sus correcciones.
$pod = SinComentarios (Traer 'Add-DatoPerfil')
Comp 'la poda salta los datos de trato' ($pod -match 'iTira[\s\S]{0,200}Test-DatoTrato')

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ahora se puede corregir hablando'
exit 0
