# QUE LO DIGA CONJUGADO (23/09, idea 1 de la cuarta tanda; lo pidio braya con estas palabras:
# "que lo diga conjugado en todas las frases que se pueda").
#
# Invoke-FastCommand devuelve el nombre interno de la accion -"abrir steam", "cerrar
# navegador", "volumen al 50 por ciento"- y esa misma cadena se decia en voz alta. Medido en
# assistant.log: 139 respuestas locales en infinitivo, 77 formas distintas, y "abrir steam" es
# la frase mas repetida de toda Nova, 23 veces. Sonaba a fichero de log.
#
# Las frases de aqui abajo NO son inventadas: son las que Nova ha dicho de verdad, sacadas del
# log con su cuenta. La leccion es de anoche misma: el banco de la pantalla dividida salio
# verde con cinco frases que habia escrito yo, y el patron cogia cero de las once reales.
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
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Get-FraseAccion')

Write-Host ''
Write-Host '-- las que mas ha dicho, con su cuenta en el log --'
# (veces, lo que devuelve Invoke-FastCommand, lo que tiene que decir)
$reales = @(
    @{ n = 23; de = 'abrir steam';                        a = 'Abro steam' }
    @{ n = 8;  de = 'abrir calculadora';                  a = 'Abro calculadora' }
    @{ n = 7;  de = 'cerrar navegador';                   a = 'Cierro navegador' }
    @{ n = 5;  de = 'abrir SILENT BREATH en Steam';       a = 'Abro SILENT BREATH en Steam' }
    @{ n = 4;  de = 'cerrar steam';                       a = 'Cierro steam' }
    @{ n = 3;  de = 'mostrar el escritorio';              a = 'Muestro el escritorio' }
    @{ n = 3;  de = 'volumen al 50 por ciento';           a = 'Pongo el volumen al 50 por ciento' }
    @{ n = 2;  de = 'brillo al 50 por ciento';            a = 'Pongo el brillo al 50 por ciento' }
    @{ n = 2;  de = 'abrir la carpeta games';             a = 'Abro games' }
    @{ n = 1;  de = 'bajar volumen';                      a = 'Bajo el volumen' }
    @{ n = 1;  de = "buscar 'gatos con botas' en google"; a = 'Busco gatos con botas en google' }
)
$dichas = 0
foreach ($c in $reales) {
    $r = Get-FraseAccion $c.de
    $ok = ($r -eq $c.a)
    if ($ok) { $dichas += [int]$c.n }
    Write-Host ("       {0} x{1,-3} {2,-34} -> {3}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $c.n, $c.de, $r)
    if (-not $ok) { $script:fallos++ }
}
Comp 'cubre las que mas veces ha dicho' ($dichas -ge 55) "$dichas de 59 veces reales"

Write-Host ''
Write-Host '-- los planes se dicen enteros, con "y" --'
$plan = Get-FraseAccion 'mostrar el escritorio; modo juego; brillo al 100 por ciento; volumen al 70 por ciento; abrir discord'
Write-Host ("       " + $plan)
Comp 'el plan de 5 pasos sale entero' (($plan -split ' y ').Count -eq 5) 'no se recorta: la capsula no guarda la lista'
Comp 'empieza conjugado' ($plan -match '^Muestro el escritorio')
Comp 'y acaba conjugado' ($plan -match 'abro discord$')
Comp 'lo que no sabe conjugar va tal cual' ($plan -match 'modo juego') 'mejor un infinitivo que una frase inventada'

Write-Host ''
Write-Host '-- lo que NO reconoce se devuelve intacto --'
foreach ($x in @('la pongo', 'el wifi ya estaba encendido', 'No veo texto en la pantalla', 'Son las 16:16')) {
    Comp ("'" + $x + "' no se toca") ((Get-FraseAccion $x) -eq $x)
}
Comp 'y una cadena vacia no revienta' ((Get-FraseAccion '') -eq '')

Write-Host ''
Write-Host '-- y el dato interno NO se toca --'
# $a.desc es lo que va al log, a la memoria de la charla, a lo que contesta "repite" y lo que
# afirman los bancos. Si se conjugara ahi, se romperia todo eso a la vez.
Comp 'Add-Turno sigue recibiendo el nombre interno' ($fuente -match 'Add-Turno \$text \$fast') ''
Comp 'y Set-UltimaOrden tambien' ($fuente -match "Set-UltimaOrden \`$original \(\(\`$hechasP -join ', '\)\)")
Comp 'se dice la version conjugada' ($fuente -match 'Say \$fraseF') ''
Comp 'y se ve la misma que se oye' ($fuente -match 'Show-Popup \$fraseF') 'o la tarjeta diria una cosa y la voz otra'

Write-Host ''
Write-Host '-- la pregunta de confirmacion se queda como estaba --'
# "¿Abro SILENT BREATH?" ya viene conjugada por su lado, y es la frase con la que braya dice
# si o no: deformarla seria tocar justo eso.
$conf = [regex]::Match($fuente, '(?s)if \(\$fast -and \$script:pendiente\) \{.{0,600}').Value
Comp 'la rama pendiente no pasa por la conjugacion' (-not ($conf -match 'Get-FraseAccion')) ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  lo que hace, lo dice conjugado'
exit 0
