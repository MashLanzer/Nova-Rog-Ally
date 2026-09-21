# "CIERRA EL RING" MATABA ELDEN RING SIN PREGUNTAR (21/09), de la tanda de agentes.
#
# Find-JuegoPorSonido compara como SUENA lo que se ha dicho con los titulos de la
# biblioteca, para rescatar "abre elden ring" cuando Whisper oye "abre el ring". Su propio
# comentario dice "se usa solo detras de un verbo de abrir y SIEMPRE pregunta antes".
#
# Los dos caminos de ABRIR lo cumplen: marcan $script:dudosa con el nombre, y por eso la
# guarda del ejecutor pregunta "¿abro ELDEN RING?" en vez de hacerlo. El camino de CERRAR
# -que es el que MATA un proceso- no lo marcaba. Asi que "abre el ring" preguntaba y
# "cierra el ring" cerraba el juego de golpe, con la partida abierta.
#
# Lo que se prueba aqui no es que reconozca bien: es que PREGUNTE. Lo primero ya funciona.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- los tres caminos que usan el parecido por sonido --'
# se cuentan sobre el archivo: si manana alguien anade un cuarto, esto lo canta
$usos = [regex]::Matches($fuente, '(?m)^\s*\$\w+ = Find-JuegoPorSonido ')
Comp 'hay tres sitios que lo usan' ($usos.Count -eq 3) "$($usos.Count) sitios"
$conDudosa = 0
foreach ($m in $usos) {
    # VENTANA LARGA: en este archivo el comentario que explica el porque ocupa mas que el
    # codigo, y con 420 caracteres el sitio que acabo de arreglar salia MAL teniendo la
    # linea justo debajo del parrafo. Es la segunda vez hoy que me pasa lo mismo.
    $cola = $fuente.Substring($m.Index, [Math]::Min(1200, $fuente.Length - $m.Index))
    if ($cola -match '\$script:dudosa = ') { $conDudosa++ }
}
Comp 'y los TRES marcan la orden como dudosa' ($conDudosa -eq $usos.Count) "$conDudosa de $($usos.Count)"

Write-Host ''
Write-Host '-- el de cerrar, que es el que mata un proceso --'
Comp 'cerrar por sonido marca dudosa antes de devolver' `
    ($fuente -match "(?s)\`$jC = Find-JuegoPorSonido.{0,900}\`$script:dudosa = \[string\]\`$jC\.nombre.{0,200}kind = 'cerrarJuego'")
# y la guarda que lo convierte en pregunta tiene que seguir existiendo
Comp 'la guarda de la orden dudosa sigue en pie' ($fuente -match '\$ConfirmacionOn -and \$script:dudosa')

Write-Host ''
Write-Host '-- y que el parecido siga reconociendo, que para eso esta --'
# las funciones de verdad, con TODO lo que llaman por dentro
# ConvertTo-Juego esta aqui porque Get-ClaveSonido la llama por dentro. Van NUEVE veces
# que me dejo una fuera y la prueba corre contra el vacio: es la regla que mas cuesta.
foreach ($fn in @('ConvertTo-Plain', 'ConvertTo-Juego', 'Get-ClaveSonido', 'Get-Distancia', 'Find-JuegoPorSonido')) {
    $m = [regex]::Match($fuente, ('(?ms)^function {0}[ (\r\n].*?^\}}' -f [regex]::Escape($fn)))
    if (-not $m.Success) { Write-Host ('  MAL  no encuentro {0}' -f $fn); exit 1 }
    . ([scriptblock]::Create($m.Value))
}
# su biblioteca de verdad, tal como la ve Nova
$script:Juegos = @(
    @{ nombre = 'ELDEN RING' }, @{ nombre = 'It Takes Two' }, @{ nombre = 'Black Myth: Wukong' },
    @{ nombre = 'Cat Quest III' }, @{ nombre = 'Hollow Knight' }, @{ nombre = 'Content Warning' },
    @{ nombre = 'Roblox' }, @{ nombre = 'PEAK' })
$script:ClavesJuegos = $null

foreach ($c in @(
        @{ dicho = 'el ring'; espera = 'ELDEN RING' },
        @{ dicho = 'elden ring'; espera = 'ELDEN RING' },
        @{ dicho = 'el reino'; espera = 'ELDEN RING' },
        @{ dicho = 'la wu kong'; espera = 'Black Myth: Wukong' },
        @{ dicho = 'roblox'; espera = 'Roblox' }
    )) {
    $j = Find-JuegoPorSonido $c.dicho ('cierra ' + $c.dicho) 0.5
    $n = if ($j) { [string]$j.nombre } else { '(nada)' }
    Comp ("'cierra $($c.dicho)' suena a $($c.espera)") ($n -eq $c.espera) "sale [$n]"
}

Write-Host ''
Write-Host '-- CONTROLES: lo que NO se parece a ningun juego no puede colarse --'
foreach ($c in @('el navegador', 'la calculadora', 'discord', 'todo', 'la ventana')) {
    $j = Find-JuegoPorSonido $c ('cierra ' + $c) 0.5
    $n = if ($j) { [string]$j.nombre } else { '' }
    Comp ("'cierra $c' no es ningun juego") (-not $n) $(if ($n) { "dice que es [$n]" } else { '' })
}

if ($fallos -gt 0) { Write-Host ''; Write-Host "  $fallos fallo(s)"; exit 1 }
Write-Host ''
Write-Host '  cerrar un juego por el sonido del nombre pregunta antes, igual que abrirlo'
exit 0
