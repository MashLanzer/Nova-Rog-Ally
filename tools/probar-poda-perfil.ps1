# EL PERFIL PODABA LO MAS VIEJO, NO LO QUE MENOS VALE (22/09).
#
# memoria\perfil.md es lo que Nova sabe de braya. Caben 60, y al llegar al tope se iba "el
# primero", o sea el mas antiguo, sin mirar que era.
#
# MEDIDO sobre assistant.log y el perfil.md de verdad: se aprendieron 91 datos distintos y
# quedan 60. De los 35 que ya no estan (no todos por el tope -alguno lo borro "olvida
# que..." o un filtro posterior-, pero el tope es el unico que tira SIN MIRAR) se fueron:
#   - "Dicho por braya: mi juego favorito es Hollow Knight"
#   - "Dicho por braya: mi color favorito es el verde"
#     ...los DOS unicos que enseno a mano con "aprende que...". Hoy no queda ni un solo
#     "Dicho por braya:" en el perfil: se los llevo la cinta.
#   - "braya guarda sus partidas en una carpeta llamada Partidas Guardadas en el
#     escritorio", que es una ruta suya, justo para lo que nacio este archivo.
#   - "Braya prefiere respuestas concisas", "le gusta ir directo al grano" y "Prefiere
#     comunicacion directa y clara": lo mismo dicho de tres formas, o sea lo que mas ha
#     repetido, y las tres fuera.
# Y mientras tanto siguen dentro "vio una casa con fuego", "ha vendido zombies en el
# juego", "tiene 8 dolares" y "quiere dejar un zoom configurado".
#
# LAS DOS REGLAS QUE SE PRUEBAN AQUI:
#   1. lo que repite se renueva: el dato viejo se mueve al final, asi que "tirar el
#      primero" deja de querer decir "el mas viejo" y pasa a decir "el que lleva mas
#      tiempo sin que braya lo repita";
#   2. lo que enseno a mano no se cae: un dato que empieza por "Dicho por braya:" lo
#      escribio el pidiendo "aprende que..." (assistant.ps1:9651). Se salta el turno, y
#      solo cae si TODO lo que queda es suyo.
#
# REGLA DEL BANCO (van dieciocho): las funciones se TRAEN de assistant.ps1, nunca se
# copian. Add-DatoPerfil llama por dentro a cuatro mas y a una constante, y sin ellas esto
# muere con CommandNotFoundException; es el fallo que caza la seccion 7 de probar-todo.ps1
# y aqui se evita de entrada. Log es la unica que se sustituye, porque escribiria en el
# log de verdad: aqui se queda con lo que dice, que ademas hace falta para comprobarlo.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

foreach ($fn in @('ConvertTo-Plain', 'ConvertTo-Suave', 'Get-DatosPerfil', 'Save-DatosPerfil', 'Add-DatoPerfil')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\[].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0} en assistant.ps1' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
$mRE = [regex]::Match($fuente, '(?m)^\$RE_DATO_SENSIBLE = .*$')
if (-not $mRE.Success) { Write-Host '  MAL  no encuentro RE_DATO_SENSIBLE'; exit 1 }
. ([scriptblock]::Create($mRE.Value))
# el tope tambien sale del fichero: si algun dia son 80, esto se entera
$mMax = [regex]::Match($fuente, '(?m)^\$PerfilMax = (\d+)')
$PerfilMax = if ($mMax.Success) { [int]$mMax.Groups[1].Value } else { -1 }
Comp 'el tope sale de assistant.ps1' ($PerfilMax -ge 10) "caben $PerfilMax"

$script:dicho = @()
function Log([string]$msg) { $script:dicho += $msg }
# Add-Estadistica tambien se sustituye: escribe en las estadisticas de verdad y arrastra
# Write-DestinoUso y Get-Estadisticas detras. No es lo que se prueba aqui, pero SI se
# apunta que se llamo, porque un dato que entra en el perfil tiene que quedar contado.
$script:contados = @()
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) {
    $script:contados += $ruta
}
# Y Set-AcabaDeAprender, por lo mismo: necesita el cronometro del asistente y llama a
# Update-Madurez. Aqui solo se apunta que se llamo, que es lo unico que importa para el
# perfil: un dato que entra tiene que encender la senal de "acabo de aprender algo".
$script:aprendio = 0
function Set-AcabaDeAprender { $script:aprendio++ }
$script:invitado = $false
$PerfilPath = Join-Path ([System.IO.Path]::GetTempPath()) ('nova-perfil-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8) + '.md')

function Poner([string[]]$lista) {
    Save-DatosPerfil $lista
    $script:dicho = @()
}
function Leer { return @(Get-DatosPerfil) }

Write-Host ''
Write-Host '-- lo que repite se renueva, en los dos filtros --'
# FILTRO 1, el de "ya lo sabia" (texto contenido). Antes: return $null y el dato viejo se
# quedaba donde estaba, o sea acercandose a la salida aunque braya lo acabara de repetir.
Poner @('el primero de todos', 'braya juega a Hollow Knight por las noches', 'el ultimo')
[void](Add-DatoPerfil 'braya juega a Hollow Knight')
$l = Leer
Comp 'no lo duplica' ($l.Count -eq 3) "$($l.Count) datos"
Comp 'y el que ya estaba se va al final' ($l[-1] -eq 'braya juega a Hollow Knight por las noches') $l[-1]
Comp 'lo dice en el log' (($script:dicho -join ' ') -match 'ya lo sabia.*lo renuevo')

# FILTRO 2, el del parecido ("ya se algo de eso"). Esto salto 56 veces en el log y hasta
# hoy solo servia para descartar: la senal mas clara de que un dato le importa -que lo
# vuelva a decir con otras palabras- se tiraba a la basura.
Poner @('a braya le gustan las respuestas concisas y al grano', 'otro dato cualquiera aqui')
[void](Add-DatoPerfil 'braya prefiere respuestas concisas directas al grano')
$l = Leer
Comp 'tampoco duplica el parecido' ($l.Count -eq 2) "$($l.Count) datos"
Comp 'y tambien renueva el que ya estaba' ($l[-1] -match 'concisas y al grano') $l[-1]
Comp 'y lo dice' (($script:dicho -join ' ') -match 'pero renuevo el que ya estaba')

Write-Host ''
Write-Host '-- lo que enseno a mano no se cae --'
# Se llena justo hasta el tope con uno suyo EL PRIMERO, que es la peor posicion posible:
# con la poda de antes era el siguiente en caer.
$rellena = @('Dicho por braya: mi juego favorito es Hollow Knight')
for ($i = 1; $i -lt $PerfilMax; $i++) { $rellena += ("dato de relleno numero $i para el perfil") }
Poner $rellena
[void](Add-DatoPerfil 'un dato nuevo cualquiera que entra el ultimo')
$l = Leer
Comp "sigue habiendo $PerfilMax" ($l.Count -eq $PerfilMax) "$($l.Count) datos"
Comp 'el suyo sigue dentro' (@($l | Where-Object { $_ -match '^Dicho por braya' }).Count -eq 1)
Comp 'y cayo el primero que NO era suyo' (-not ($l -contains 'dato de relleno numero 1 para el perfil'))
Comp 'lo dice en el log' (($script:dicho -join ' ') -match 'lleva mas sin repetirse')

# Si TODO lo que queda es suyo, cae el mas viejo igual, como antes. Sin esto el bucle no
# terminaria nunca.
#
# LAS FRASES DE PRUEBA TIENEN QUE SER DISTINTAS DE VERDAD, y aqui costo dos rojos
# aprenderlo: con "el dato suyo numero 1", "...numero 2"... el filtro del parecido las ve
# como la misma cosa (comparten cuatro palabras de cuatro letras o mas) y las renueva en
# vez de anadirlas, asi que la poda no llegaba a entrar y el banco medi­a otra cosa. Con
# palabras propias en cada una, solo comparten "dicho" y "braya": dos comunes sobre seis,
# por debajo de los dos listones (3 comunes, o el 60 % de una de las dos).
$todosSuyos = @()
for ($i = 0; $i -lt $PerfilMax; $i++) { $todosSuyos += ("Dicho por braya: alfa$i beta$i gama$i delta$i") }
Poner $todosSuyos
[void](Add-DatoPerfil 'Dicho por braya: omega ultimo postrero zaguero')
$l = Leer
Comp 'si todo es suyo, cae el mas viejo (y no se cuelga)' ($l.Count -eq $PerfilMax) "$($l.Count) datos"
Comp 'y el que cayo fue el primero' (-not ($l -contains 'Dicho por braya: alfa0 beta0 gama0 delta0'))
Comp 'y el nuevo entro' ($l[-1] -match 'omega ultimo postrero')

# Y varios suyos repartidos: caen los de fuera por orden, ninguno suyo.
$mezcla = @()
for ($i = 0; $i -lt $PerfilMax; $i++) {
    $mezcla += $(if ($i % 10 -eq 0) { "Dicho por braya: el suyo numero $i" } else { "relleno normal numero $i aqui" })
}
Poner $mezcla
# tres frases sin nada en comun, por lo mismo de arriba
$tresNuevas = @(
    'braya guarda sus partidas en el escritorio',
    'toca la guitarra electrica los domingos',
    'prefiere el cafe sin azucar por la manana')
foreach ($n in $tresNuevas) { [void](Add-DatoPerfil $n) }
$l = Leer
Comp 'con los suyos repartidos, no cae ninguno suyo' (@($l | Where-Object { $_ -match '^Dicho por braya' }).Count -eq 6) `
    "quedan $(@($l | Where-Object { $_ -match '^Dicho por braya' }).Count) de 6"
Comp 'y entraron las tres nuevas' (@($tresNuevas | Where-Object { $l -contains $_ }).Count -eq 3) `
    "$(@($tresNuevas | Where-Object { $l -contains $_ }).Count) de 3"
Comp 'y cayeron tres de relleno, no mas' ($l.Count -eq $PerfilMax) "$($l.Count) datos"

Write-Host ''
Write-Host '-- lo que NO debe cambiar --'
Poner @('un dato normal y corriente del perfil')
[void](Add-DatoPerfil 'braya toma medicamentos para la migrana cada manana')
Comp 'lo sensible se sigue sin guardar' ((Leer).Count -eq 1) 'el filtro del 21/09'
[void](Add-DatoPerfil 'corto')
Comp 'lo muy corto tampoco' ((Leer).Count -eq 1)
[void](Add-DatoPerfil ('x' * 200))
Comp 'ni lo larguisimo' ((Leer).Count -eq 1)
$script:invitado = $true
[void](Add-DatoPerfil 'en modo invitado no se apunta nada de nadie')
Comp 'en modo invitado no guarda nada' ((Leer).Count -eq 1)
$script:invitado = $false
[void](Add-DatoPerfil 'este si es un dato nuevo que debe entrar')
Comp 'y un dato nuevo de verdad entra' ((Leer).Count -eq 2)
Comp 'y entra por el FINAL, como siempre' ((Leer)[-1] -match 'este si es un dato nuevo')
Comp 'y queda contado en las estadisticas' ($script:contados -contains 'perfil')
Comp 'y enciende la senal de "acabo de aprender"' ($script:aprendio -ge 1) "$($script:aprendio) veces"
# El archivo sigue siendo el de siempre: una linea por dato empezando por "- ".
$crudo = [System.IO.File]::ReadAllText($PerfilPath)
Comp 'el formato del archivo no cambia' ($crudo -match '(?m)^- este si es un dato nuevo')
Comp 'y conserva su cabecera' ($crudo -match 'Lo que Nova sabe de braya')

Remove-Item -LiteralPath $PerfilPath -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  el perfil ya no tira lo que braya repite ni lo que enseno a mano'
exit 0
