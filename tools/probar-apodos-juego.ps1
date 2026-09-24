# LOS JUEGOS POR SU APODO, Y EL ARTICULO QUE ABRIA OTRO (21/09).
#
# De sondear como pide las cosas de verdad: nadie dice "abre Black Myth: Wukong" jugando,
# dice "abre el wukong". Y eso no solo no funcionaba: hacia abrir OTRO JUEGO.
#
# LA CAUSA: Get-ClaveSonido pega las palabras, asi que "el warning" se vuelve 'elguarning',
# y eso se parece mas a 'eldenring' que a 'kontentguarning'. Resultado medido:
#     abre el warning   ->  abrir ELDEN RING en Steam      (teniendo Content Warning)
#     cierra el warning ->  cerrar ELDEN RING
#     abre el engine    ->  abrir ELDEN RING en Steam      (teniendo Wallpaper Engine)
# Tres ordenes equivocadas, que es lo peor que puede pasar aqui.
#
# DOS COSAS SE ARREGLARON, y la segunda salio de romper la primera:
#   1. el articulo no entra ni como variante: nunca es parte del nombre de un juego.
#   2. el apodo es un RESCATE, no un competidor. Mezclar el titulo entero con sus palabras
#      sueltas en la misma comparacion le da a cada juego un camino mas de acercarse, y eso
#      ESTRECHA los margenes: "cierra en la ring" paso de resolver ELDEN RING a no resolver
#      nada, porque Content Warning llegaba a 0,63 por su palabra "Warning" contra el 0,67
#      de ELDEN RING por "RING", y la diferencia caia por debajo del margen de 0,08 que
#      impide adivinar. Asi que primero se busca por el titulo COMPLETO, como toda la vida,
#      y solo si ahi no gana nadie se prueba por el apodo.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA, van DIEZ veces: todo lo que se llame aqui sale del archivo de verdad.
# Get-ClaveSonido llama a ConvertTo-Juego, que llama a ConvertTo-Plain.
foreach ($fn in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-ClaveSonido', 'Get-Distancia', 'Find-JuegoPorSonido')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\r\n].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0}' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}

# su biblioteca de verdad, con los titulos que de dos palabras para arriba
$script:Juegos = @(
    @{ nombre = 'ELDEN RING' }, @{ nombre = 'Content Warning' }, @{ nombre = 'Black Myth: Wukong' },
    @{ nombre = 'Wallpaper Engine' }, @{ nombre = 'PEAK' }, @{ nombre = 'Roblox' },
    @{ nombre = 'Hollow Knight' }, @{ nombre = 'It Takes Two' }, @{ nombre = 'Cat Quest III' },
    @{ nombre = 'Goose Goose Duck' }, @{ nombre = 'MECCHA CHAMELEON' }, @{ nombre = 'MIMESIS' })
$script:ClavesJuegos = $null

function Suena([string]$dicho, [string]$verbo = 'abre') {
    $j = Find-JuegoPorSonido $dicho ("$verbo $dicho") 0.5
    if ($j) { return [string]$j.nombre }
    return ''
}

Write-Host ''
Write-Host '-- por el apodo, que es como se llaman hablando --'
foreach ($c in @(
        @{ d = 'el warning'; e = 'Content Warning' },
        @{ d = 'warning'; e = 'Content Warning' },
        @{ d = 'el wukong'; e = 'Black Myth: Wukong' },
        @{ d = 'el engine'; e = 'Wallpaper Engine' },
        @{ d = 'hollow'; e = 'Hollow Knight' },
        @{ d = 'el hollow'; e = 'Hollow Knight' }
    )) {
    $v = Suena $c.d
    Comp ("'$($c.d)' es $($c.e)") ($v -eq $c.e) $(if ($v -ne $c.e) { "sale [$v]" } else { '' })
}

Write-Host ''
Write-Host '-- y lo que YA funcionaba, que es lo que no se puede romper --'
foreach ($c in @(
        @{ d = 'elden ring'; e = 'ELDEN RING' },
        @{ d = 'el ring'; e = 'ELDEN RING' },
        @{ d = 'en la ring'; e = 'ELDEN RING' },
        @{ d = 'la ring'; e = 'ELDEN RING' },
        @{ d = 'cat quest'; e = 'Cat Quest III' },
        @{ d = 'roblox'; e = 'Roblox' }
    )) {
    $v = Suena $c.d
    Comp ("'$($c.d)' sigue siendo $($c.e)") ($v -eq $c.e) $(if ($v -ne $c.e) { "sale [$v]" } else { '' })
}

Write-Host ''
Write-Host '-- CONTROLES: palabras corrientes que NO pueden arrastrar un juego --'
# "todo" se parecia a "Hollow" lo bastante para que "cierra todo" cerrara Hollow Knight
foreach ($c in @('todo', 'todos', 'nada', 'esto', 'eso', 'el juego', 'la pantalla', 'el volumen',
                 'la musica', 'el correo', 'la ventana', 'el navegador', 'la calculadora',
                 'discord', 'spotify')) {
    $v = Suena $c
    Comp ("'$c' no es ningun juego") (-not $v) $(if ($v) { "dice que es [$v]" } else { '' })
}

Write-Host ''
Write-Host '-- y sigue sin adivinar cuando hay duda de verdad --'
# el margen de 0,08 es lo que impide elegir entre dos juegos que suenan igual
Comp 'el margen entre el primero y el segundo sigue exigido' ($fuente -match '\$r1\.p - \$r1\.segunda\) -ge 0\.08')
Comp 'y el titulo completo se prueba ANTES que el apodo' `
    ($fuente.IndexOf('$r1 = Busca-Mejor $porTitulo') -lt $fuente.IndexOf('$r2 = Busca-Mejor $porApodo'))
Comp 'el articulo no entra ni como variante' ($fuente -match "\`$sinArt = \(\`$resto -replace")
Comp 'y hay lista de lo que nunca es un juego' ($fuente -match '\$noEsJuego = @\(')

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  los juegos se reconocen por su apodo y el articulo ya no abre otro'
exit 0
