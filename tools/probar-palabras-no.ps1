# LAS PALABRAS QUE BRAYA NO AGUANTA (23/09, funcion 2 de la tanda de funciones nuevas).
#
# Se lo pidio TRES veces: 20/09 23:05 "deja de decirme man, no me digas asi", 20/09 23:19
# "deja de llamarme tio", 21/09 00:03 "deja de decir tio, no me gusta esa palabra, guardalo en
# memoria". Nova prometio dos veces que no lo haria, y el 22/09 a las 21:48:35 dijo "No te
# sigo, tio".
#
# Y lo peor no era que siguiera diciendolo, sino lo que APRENDIO de la queja: en perfil.md
# quedo escrito "braya habla con acento español (usa 'tio')" -el dato del reves, porque la
# muletilla es de ella- y esa linea viaja en el prompt de todas sus charlas. La queja
# realimentaba justo lo que molestaba.
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
Invoke-Expression (Traer 'ConvertTo-Plain')
Invoke-Expression (Traer 'Remove-PalabrasNo')
$script:palabrasNo = @('tio', 'man')
function Get-PalabrasNo { return $script:palabrasNo }

Write-Host ''
Write-Host '-- la frase del 22/09 a las 21:48:35 --'
$r = Remove-PalabrasNo 'No te sigo, tio.'
Comp 'se va la palabra' ($r -notmatch 'tio') $r
Comp 'y la coma del vocativo con ella' ($r -eq 'No te sigo.') "'$r'"

Write-Host ''
Write-Host '-- las otras formas en que se le colaba --'
$casos = @(
    @{ de = 'Tio, eso no lo se.';                a = 'eso no lo se.' }
    @{ de = 'Vale man, lo hago.';                a = 'Vale, lo hago.' }
    @{ de = 'Que pasa tio, todo bien?';          a = 'Que pasa, todo bien?' }
    @{ de = 'No te sigo, tio. Dime otra vez.';   a = 'No te sigo. Dime otra vez.' }
)
foreach ($c in $casos) {
    $x = Remove-PalabrasNo $c.de
    Comp ("'" + $c.de + "'") ($x -notmatch '(?i)\b(tio|man)\b') "-> '$x'"
}

Write-Host ''
Write-Host '-- y NO se lleva por delante lo que se le parece --'
# "man" a secas se comeria mando, manda, semana, humano, comando... y Nova le lee los cuatro
# mandos. Palabra entera o nada.
foreach ($f in @('El mando no responde.', 'Te lo mando ahora.', 'Esta semana has jugado 5 horas.',
                 'Comando ejecutado.', 'Es un juego humano.', 'Vas por la mitad.')) {
    $x = Remove-PalabrasNo $f
    Comp ("'" + $f + "' intacta") ($x -eq $f) "-> '$x'"
}

Write-Host ''
Write-Host '-- el filtro va donde tiene que ir --'
# En Get-TextoVoz, NO en Say: la charla pre-sintetiza con Get-TextoVoz y cachea por md5 del
# texto. Filtrando despues, el md5 no cuadra y cada frase tocada pierde la voz preparada.
Comp 'el filtro esta dentro de Get-TextoVoz' ($fuente -match 'function Get-TextoVoz\(\[string\]\$texto\) \{\s*\r?\n\s*\$t = Add-TildesVoz \(Remove-PalabrasNo') ''
Comp 'y antes del recorte a 1.200 letras' ($fuente -match '(?s)Remove-PalabrasNo.{0,700}1200') ''

Write-Host ''
Write-Host '-- la lista es corta y se puede deshacer --'
Comp 'hay tope de cinco' ($fuente -match '\$listaPN\.Count -ge 5') 'un "no digas X" mal oido no puede dejarla muda'
Comp 'se puede devolver una palabra' ($fuente -match "'palabraSi'") ''
Comp 'y preguntar cuales son' ($fuente -match "'palabrasLista'") ''
# POR NUMERO DE LINEA, no por IndexOf de un texto: el comentario que hay encima del patron
# MENCIONA "no digas nada" para explicar por que va delante, asi que buscar esa cadena
# encontraba el comentario y media al reves. Van cinco veces hoy con la misma trampa.
$lineas = $fuente -split "`r?`n"
$nPal = ($lineas | Select-String -SimpleMatch '(?:no (?:me )?(?:digas|llames)' | Select-Object -First 1).LineNumber
$nSor = ($lineas | Select-String -SimpleMatch 'no me escuches|no escuches' | Select-Object -First 1).LineNumber
Comp 'la orden va DELANTE de la sordina' ($nPal -and $nSor -and $nPal -lt $nSor) "linea $nPal contra $nSor"
Comp 'y excluye las palabras de relleno' ($fuente -match "'nada', 'mas', 'eso'") 'o "no digas nada" vetaria la palabra nada'

Write-Host ''
Write-Host '-- y el dato del reves no vuelve a entrar --'
Comp 'el perfil rechaza datos con una palabra vetada' ($fuente -match "PERFIL: no guardo un dato que habla de") ''
$perfil = Get-Content -LiteralPath (Join-Path $raiz 'memoria\perfil.md') -Raw -Encoding UTF8
Comp 'y el que estaba ya no esta' (-not ($perfil -match 'acento espa')) 'se borro a mano'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  lo que te molesta deja de decirlo, y no lo aprende del reves'
exit 0
