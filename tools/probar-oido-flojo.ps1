# TE LLAMASTE TRES VECES Y NO TE OI (24/09, idea 1 de la tanda nueva).
#
# LA MEDICION: 83 descartes por "suena demasiado flojo" en el registro, 57 dentro de 19
# rachas de dos o mas en 120 s. Mirado que paso DESPUES de cada una de las 19, con 15 min de
# ventana: CERO acabaron en la orden que pidio, 17 se quedaron en nada y DOS ejecutaron algo
# que no habia pedido. El del 22/09 a la 01:12 esta con sus palabras en el registro: Nova
# abrio los ajustes Y ademas leyo la pantalla, y el dicto "no tenias que leer la pantalla,
# no te pedi eso". O sea que no se recupera sola.
#
# LO QUE MAS SE VIGILA AQUI, y es lo contrario de lo que parece: que esto NO toque ningun
# liston. De los 83 descartes, 45 pasan con los altavoces sonando (0,10 a 0,38) y una linea
# JUEGO al lado: no es braya hablando bajo, es el juego diciendo algo parecido a "nova".
# Subir la sensibilidad en una racha seria amplificar justo eso -la regla 1 al reves-, asi
# que esto solo HABLA, y solo cuenta las rachas que pasan en silencio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
$oido = [System.IO.File]::ReadAllText((Join-Path $raiz 'wake_vosk.py'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }
function Log([string]$m) { }
function Get-Cfg($a, $b, $c) { return $c }

$FlojoRachaMinima = 3
Invoke-Expression (Traer 'Test-AvisarFlojo')

Write-Host ''
Write-Host '-- 1. EL LISTON DE TRES: las rachas medidas, una a una --'
# Los tamanos reales de las rachas del registro, y si los altavoces estaban callados. Con
# altavoces sonando el worker NI LAS CUENTA, asi que aqui llegan como 0.
$rachas = @(
    @{ d = '20/09 21:13'; n = 4; callado = $true },  @{ d = '21/09 16:28'; n = 3; callado = $true },
    @{ d = '21/09 16:37'; n = 6; callado = $true },  @{ d = '21/09 23:42'; n = 5; callado = $true },
    @{ d = '23/09 23:36'; n = 3; callado = $true },
    @{ d = '23/09 23:25'; n = 8; callado = $false }, @{ d = '24/09 01:00'; n = 4; callado = $false },
    @{ d = '20/09 13:32'; n = 2; callado = $true },  @{ d = '21/09 00:11'; n = 2; callado = $true },
    @{ d = '22/09 01:10'; n = 2; callado = $true },  @{ d = '23/09 21:47'; n = 2; callado = $false }
)
$avisadas = 0
foreach ($r in $rachas) {
    $script:flojoAvisado = $false
    $cuenta = $(if ($r.callado) { $r.n } else { 0 })
    $sale = Test-AvisarFlojo $cuenta $false $false
    $esperado = ($r.callado -and $r.n -ge 3)
    if ($sale) { $avisadas++ }
    $altav = $(if ($r.callado) { 'callados' } else { 'sonando ' })
    $quePasa = $(if ($esperado) { 'avisa' } else { 'calla' })
    Comp ("$($r.d): $($r.n) descartes, altavoces $altav -> $quePasa") ($sale -eq $esperado) "$sale"
}
Comp 'en total avisa 5 veces, no 11' ($avisadas -eq 5) "$avisadas de $($rachas.Count) rachas"

Write-Host ''
Write-Host '-- 2. UNA VEZ POR RACHA, que es el fallo de los 25 avisos identicos --'
$script:flojoAvisado = $false
Comp 'la primera vez habla' (Test-AvisarFlojo 4 $false $false) ''
$script:flojoAvisado = $true
$repes = 0
for ($i = 1; $i -le 40; $i++) { if (Test-AvisarFlojo 4 $false $false) { $repes++ } }
Comp 'y las 40 vueltas siguientes, callada' ($repes -eq 0) "$repes de 40"
Comp 'con la racha aun abierta (1 o 2) sigue callada' (-not (Test-AvisarFlojo 2 $false $false)) ''
# EL REARME A MEDIAS, que es lo que se escapaba: si se rearmara en cuanto la cuenta baja
# del liston, un hueco de un solo minuto dentro de la MISMA racha -bajar a 2 y volver a 3-
# la partiria en dos y Nova hablaria dos veces por lo mismo. Y eso pasa de verdad: la racha
# del 21/09 a las 16:37 son 6 descartes en 84 s, con huecos de 20 y 30 segundos dentro.
$script:flojoAvisado = $false
[void](Test-AvisarFlojo 4 $false $false); $script:flojoAvisado = $true
[void](Test-AvisarFlojo 2 $false $false)
Comp 'un hueco corto NO rearma nada' ($script:flojoAvisado) 'sigue siendo la misma racha'
Comp 'y al volver a subir, no repite' (-not (Test-AvisarFlojo 5 $false $false)) 'hablaria dos veces por la misma racha'
[void](Test-AvisarFlojo 0 $false $false)
Comp 'solo se rearma cuando la racha llega a CERO' (-not $script:flojoAvisado) 'el worker solo cuenta los ultimos 2 min'
Comp 'y entonces la racha siguiente si se dice' (Test-AvisarFlojo 3 $false $false) ''

Write-Host ''
Write-Host '-- 3. ni mientras habla ni en sordina --'
# Su propia voz entrando por el microfono genera descartes: avisar ahi seria contestarse
# sola. Y la sordina es justo el modo en el que braya pidio que no le hablara.
$script:flojoAvisado = $false
Comp 'hablando, no avisa' (-not (Test-AvisarFlojo 9 $true $false)) 'su voz genera descartes'
$script:flojoAvisado = $false
Comp 'en sordina, tampoco' (-not (Test-AvisarFlojo 9 $false $true)) 'se lo pidio el'
$script:flojoAvisado = $false
Comp 'y callada y sin sordina, si' (Test-AvisarFlojo 9 $false $false) ''

Write-Host ''
Write-Host '-- 4. LO QUE NO TOCA: ni un liston, ni una orden --'
$tf = SinComentarios (Traer 'Test-AvisarFlojo')
Comp 'no toca la ganancia ni la puerta' (($tf -notmatch 'ganancia') -and ($tf -notmatch 'umbral')) ''
Comp 'ni la rafaga minima' ($tf -notmatch 'rafagaMinima') 'subirla es la regla 1 al reves'
Comp 'ni ejecuta nada' (($tf -notmatch 'Invoke-FastCommand') -and ($tf -notmatch 'Submit-Command') -and ($tf -notmatch 'Start-Process')) 'la regla 1'
Comp 'ni habla ella: decide y ya' (($tf -notmatch '\bSay\b') -and ($tf -notmatch 'Send-Aviso')) ''
Comp 'el liston de la rafaga sigue en el oido' ($oido -match 'def umbral_rafaga') 'y este banco no lo cambia'

Write-Host ''
Write-Host '-- 5. el oido solo cuenta las que pasan EN SILENCIO --'
$sinCom = (($oido -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'apunta la racha' ($sinCom -match 'flojos_callados\.append') ''
Comp 'y solo si los altavoces callan' ($sinCom -match 'if salida <= UMBRAL_ALTAVOZ:[^#]{0,120}flojos_callados\.append') 'las 45 con sonido no cuentan'
# EL 120 EXACTO, no "algo que empieza por 120": con 1200 el regex de antes pasaba igual, y
# veinte minutos de ventana juntan rachas que no tienen nada que ver entre si.
Comp 'la ventana son dos minutos justos' ($sinCom -match 'FLOJO_VENTANA = 120\.0[^0-9]') ''
# Y QUE SE USE. Esto es lo que se escapaba: la constante puede estar escrita y la cuenta
# sumar la sesion entera, y entonces el aviso no se apagaria nunca.
Comp 'y la cuenta la usa de verdad' ($sinCom -match 'if ahora_f - t <= FLOJO_VENTANA') 'si sumara todas, avisaria para siempre'
Comp 'y la lista tiene tope' ($sinCom -match 'del flojos_callados') 'no crece sin fin'

Write-Host ''
Write-Host '-- 6. el sexto campo va AL FINAL, o rompe al asistente viejo --'
# assistant.ps1 lee este fichero por INDICE en cuatro sitios y los de antes cogen los campos
# 0 a 4. Meterlo en medio cambiaria el significado de todos ellos de golpe.
Comp 'el estado tiene seis campos' ($sinCom -match '"%\.1f\|%s\|%\.3f\|%d\|%d\|%d"') ''
Comp 'y el nuevo es el ultimo' ($sinCom -match '1 if ruido_de_fuera else 0, recientes\)') ''
$gf = SinComentarios (Traer 'Get-OidoFlojos')
Comp 'el asistente lee el indice 5' ($gf -match '\$st\[5\]') ''
Comp 'y con un worker viejo devuelve cero' ($gf -match '\$st\.Count -lt 6') 'no adivina'
Comp 'y con el estado rancio, tambien' ($gf -match 'Test-EstadoFresco') 'es el dato del worker anterior'

Write-Host ''
Write-Host '-- 7. y el bucle lo usa de verdad --'
$bloque = (($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'el bucle llama a Test-AvisarFlojo' ($bloque -match 'Test-AvisarFlojo \(Get-OidoFlojos\)') ''
Comp 'y solo apunta el aviso si SALIO' ($bloque -match "Send-AvisoEntorno 'oido-flojo'[\s\S]{0,240}flojoAvisado = \`$true") 'si lo para la noche, se reintenta'
Comp 'y el aviso nombra el boton' ($fuente -match "oido-flojo'[\s\S]{0,200}boton") 'la regla 7: siempre una segunda via'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  ya no se queda callada cuando la llamas y no te oye'
exit 0
