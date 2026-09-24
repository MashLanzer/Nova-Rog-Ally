# DE QUE VA ESTE JUEGO: el resumen de la Wikipedia, FUERA del bucle (23/09, idea 6).
#
# POR QUE UN PROCESO APARTE, y no una llamada mas dentro de Nova: la ventana en la que no se
# puede abrir nada dura HORAS -It Takes Two 5 h 38 el 15/09, 3 h 12 el 22/09, 2 h 45 el
# 20/09, y la sesion continua mas larga medida fue de 6 h 14-. Y lo que depende de la red
# tarda mas de lo que uno cree: la nube tiene mediana de 3.100 ms y 52 de 81 respuestas por
# encima de 2.500 ms. Asi que esto se lanza y se recoge cuando llegue, como ya se hace con el
# ayudante de la API.
#
# Y POR QUE UNA ENCICLOPEDIA Y NO UN MODELO: "de que va este juego" tiene una respuesta que se
# puede comprobar. La segunda opinion de la nube lleva 126 llamadas y ha servido 0.
#
# NUNCA SE RELLENA LO QUE NO SE ENCUENTRA: si el articulo no es el del juego, o el extracto
# viene corto, se devuelve ok:false y Nova lo dice. Inventarse de que va un juego es
# exactamente lo que no puede pasar.
param(
    [Parameter(Mandatory)][string]$Juego,
    [string]$SalidaArchivo = '',
    [int]$TimeoutSec = 6,
    [string]$Idiomas = 'es,en'
)
$ErrorActionPreference = 'Stop'

function Quita-Tildes([string]$t) {
    if (-not $t) { return '' }
    $n = $t.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $n.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) }
    }
    return $sb.ToString().ToLowerInvariant()
}

# el titulo de la Wikipedia trae a menudo una coletilla entre parentesis
# ("It Takes Two (videojuego de 2021)"): eso no cuenta para comparar
function Titulo-Limpio([string]$t) {
    return (Quita-Tildes (($t -replace '\s*\([^)]*\)\s*$', '').Trim()))
}

# LOS TRES CIERRES, JUNTOS Y APARTE: asi un banco puede probarlos sin tocar la red, que es
# lo unico que importa aqui -que no se invente de que va un juego-. Devuelve '' si el
# articulo vale, o el motivo por el que no.
function Test-ArticuloJuego([string]$titulo, [string]$texto, [string]$pedido) {
    # 1. QUE SEA EL ARTICULO DEL JUEGO, no el primero que devuelva el buscador
    $tl = Titulo-Limpio $titulo
    if (-not $tl) { return 'sin-articulo' }
    if ($tl -ne $pedido -and -not $tl.StartsWith($pedido) -and -not $pedido.StartsWith($tl)) { return 'otro-titulo' }
    # 2. y que traiga algo que decir: un extracto de dos palabras no es un resumen
    if (-not $texto -or $texto.Trim().Length -lt 40) { return 'extracto-corto' }
    # 3. Y QUE HABLE DE UN JUEGO. Cierre independiente del titulo: comprobado hoy, "It Takes
    # Two" a secas devuelve la PELICULA de 1995 y el titulo coincide EXACTO, asi que el
    # primer cierre solo no la cazaria.
    if ((Quita-Tildes $texto) -notmatch 'videojuego|video game|juego de') { return 'no-habla-de-un-juego' }
    return ''
}

$reloj = [System.Diagnostics.Stopwatch]::StartNew()
$pedido = Quita-Tildes $Juego
$res = @{ ok = $false; motivo = 'sin-articulo'; titulo = ''; texto = ''; fuente = ''; ms = 0 }

foreach ($idioma in ($Idiomas -split ',')) {
    $id = $idioma.Trim()
    if (-not $id) { continue }
    try {
        # el buscador y el extracto en la MISMA llamada: generator=search + prop=extracts
        # SE BUSCA "<juego> videojuego", no el nombre a secas, y esto no es un adorno:
        # comprobado hoy, "It Takes Two" a secas devuelve la PELICULA de 1995 con Mary-Kate
        # Olsen, y el titulo coincide exacto, asi que ninguna comprobacion de titulo lo
        # cazaria. Con la palabra detras salen los tres juegos suyos que se probaron.
        $pista = if ($id -eq 'es') { ' videojuego' } else { ' video game' }
        $url = 'https://' + $id + '.wikipedia.org/w/api.php?action=query&format=json&formatversion=2' +
               '&redirects=1&prop=extracts&exintro=1&explaintext=1&generator=search&gsrlimit=1&gsrsearch=' +
               [Uri]::EscapeDataString($Juego + $pista)
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec $TimeoutSec -Uri $url `
             -Headers @{ 'User-Agent' = 'Nova/1.0 (asistente personal)' }
        $j = $r.Content | ConvertFrom-Json
        $pg = @($j.query.pages)
        if ($pg.Count -eq 0) { continue }
        $p = $pg[0]
        $tit = [string]$p.title
        $txt = [string]$p.extract
        $motivo = Test-ArticuloJuego $tit $txt $pedido
        if ($motivo) { $res.motivo = $motivo; continue }
        $res.ok = $true
        $res.motivo = ''
        $res.titulo = $tit
        $res.texto = $txt.Trim()
        $res.fuente = $id + '.wikipedia'
        break
    } catch {
        $res.motivo = 'error-red'
    }
}

$res.ms = [int]$reloj.ElapsedMilliseconds
$json = ConvertTo-Json -InputObject $res -Depth 3
if ($SalidaArchivo) {
    # UTF-8 SIN BOM, igual que el ayudante de la API: quien lo lee es PowerShell 5.1
    [System.IO.File]::WriteAllText($SalidaArchivo, $json, (New-Object System.Text.UTF8Encoding($false)))
} else {
    Write-Output $json
}
