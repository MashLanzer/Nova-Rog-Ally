# EL VOLUMEN DEL MICROFONO (1/10, la 19 de las 20 funciones nuevas)
#
# Nova controlaba el volumen de salida y el de cada app, pero no el del micro, que es el que se toca
# cuando entras a hablar con alguien y te dicen que no se te oye. El microfono es otro endpoint de
# Windows -eCapture (1) en vez de eRender (0)-, asi que son dos funciones nuevas en el .cs.
#
# LO QUE CONVIENE NO MEZCLAR, y por eso esta escrito aqui: Nova lleva SU PROPIA ganancia de software
# (x9,5, x26,4...) que multiplica lo que ya le llega al oido. Esta funcion mueve el volumen del
# APARATO en Windows, que es lo que oyen los demas en Discord. Subir una no arregla lo que la otra
# estropea, y confundirlas seria perseguir el fallo equivocado.
#
# AQUI NO SE TOCA EL MICRO DE VERDAD: [AX] esta doblado. Dejarle el micro a cero a braya por correr
# la bateria es lo peor que puede hacer este banco.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
foreach ($n in @('Get-FraseVolumenMicro', 'Set-VolumenMicro')) { Invoke-Expression (Traer $n) }
$script:dichos = @()
function Log([string]$m) { $script:dichos += $m }

# EL [AX] DE PEGA: un microfono de mentira con su valor, que se puede mover y que se puede hacer
# fallar. Asi se prueban las tres cosas que importan sin tocar el aparato de braya.
Add-Type -TypeDefinition @'
public class AX {
    public static int valor = 54;
    public static bool dejaPoner = true;
    public static bool seMueve = true;
    public static int LeerVolumenMicro() { return valor; }
    public static bool PonerVolumenMicro(int pct) {
        if (!dejaPoner) { return false; }
        if (seMueve) { valor = pct; }
        return true;
    }
}
'@

Write-Host ''
Write-Host '-- 1. decir como esta --'
[AX]::valor = 54
Comp 'dice el porcentaje' ((Get-FraseVolumenMicro) -match '54 por ciento') "$(Get-FraseVolumenMicro)"
[AX]::valor = 0
Comp 'y a cero avisa de que no te oye nadie' ((Get-FraseVolumenMicro) -match 'no te oye nadie') "$(Get-FraseVolumenMicro)"
[AX]::valor = 15
Comp 'y bajito lo dice' ((Get-FraseVolumenMicro) -match 'bajito') ''
[AX]::valor = -1
Comp 'y si no se puede leer, lo dice' ((Get-FraseVolumenMicro) -match 'No puedo leer') ''

Write-Host ''
Write-Host '-- 2. subir y bajar son RELATIVOS, como el volumen de salida --'
# "sube el micro" no es "pon el micro al 100": se mueve desde donde esta.
[AX]::valor = 50
$r = Set-VolumenMicro 0 'sube'
Comp 'subir sube desde donde estaba' ([AX]::valor -eq 65) "quedo en $([AX]::valor)"
Comp '  y lo dice' ($r -match '65 por ciento') "$r"
[AX]::valor = 50
[void](Set-VolumenMicro 0 'baja')
Comp 'bajar baja desde donde estaba' ([AX]::valor -eq 35) "quedo en $([AX]::valor)"
# Y NO SE SALE DE 0..100
[AX]::valor = 95
[void](Set-VolumenMicro 0 'sube')
Comp 'no pasa de 100' ([AX]::valor -eq 100) "$([AX]::valor)"
[AX]::valor = 5
[void](Set-VolumenMicro 0 'baja')
Comp 'ni baja de 0' ([AX]::valor -eq 0) "$([AX]::valor)"

Write-Host ''
Write-Host '-- 3. poner un numero concreto --'
[AX]::valor = 40
$r2 = Set-VolumenMicro 80 ''
Comp 'lo pone donde se le dice' ([AX]::valor -eq 80) "$([AX]::valor)"
Comp '  y lo confirma' ($r2 -match '80 por ciento') "$r2"
# SI YA ESTABA AHI, NO SE TOCA Y SE DICE
$r3 = Set-VolumenMicro 80 ''
Comp 'si ya estaba, lo dice y no insiste' ($r3 -match 'ya estaba') "$r3"

Write-Host ''
Write-Host '-- 4. lo que NO se presume (regla 1) --'
# El endpoint puede aceptar la llamada y no moverse: eso no es "hecho".
[AX]::valor = 40
[AX]::seMueve = $false
$r4 = Set-VolumenMicro 90 ''
Comp 'si pide 90 y se queda en 40, lo dice' ($r4 -match 'He pedido 90' -and $r4 -match '40') "$r4"
[AX]::seMueve = $true
# Y SI NO LE DEJAN, TAMPOCO SE PRESUME
[AX]::valor = 40
[AX]::dejaPoner = $false
$r5 = Set-VolumenMicro 90 ''
Comp 'si no le dejan, lo dice' ($r5 -match 'no me ha dejado') "$r5"
[AX]::dejaPoner = $true
# Y SI NO SE PUEDE NI LEER, no se intenta mover nada
[AX]::valor = -1
$r6 = Set-VolumenMicro 50 ''
Comp 'sin poder leerlo, no lo toca' ($r6 -match 'No puedo tocar') "$r6"

Write-Host ''
Write-Host '-- 5. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca volumenMicro' ($sinCom -match "kind = 'volumenMicro'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'volumenMicro' \{") ''
# EL VOLUMEN DE SIEMPRE NO SE PISA: "sube el volumen" sigue siendo el de salida.
Comp '  y el volumen de salida sigue existiendo' ($sinCom -match "kind = 'volumen") 'son dos aparatos distintos'
# Y EL P/INVOKE DEL MICRO ESTA EN EL .cs, con eCapture y no eRender
$cs = [IO.File]::ReadAllText((Join-Path $Raiz 'assistant-dx.cs'))
Comp 'LeerVolumenMicro esta en el .cs' ($cs -match 'LeerVolumenMicro') ''
Comp '  y PonerVolumenMicro tambien' ($cs -match 'PonerVolumenMicro') ''
Comp '  y pide el endpoint de CAPTURA (1)' ($cs -match 'GetDefaultAudioEndpoint\(1, 0, out dev\)') '0 seria los altavoces otra vez'
# Y SU PROPIA CACHE: compartir el puntero con los altavoces mezclaria los dos aparatos.
Comp '  y tiene su propio puntero' ($cs -match '_volMic') 'compartirlo con la salida los mezclaria'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova sube y baja el microfono, y no se lo inventa si no le dejan' -ForegroundColor Green
exit 0
