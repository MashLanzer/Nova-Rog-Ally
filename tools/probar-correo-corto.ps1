# EL AVISO DEL CORREO QUE NO HAS PEDIDO, CORTO (22/09 por la noche, idea 6).
#
# El parte de la mañana leia remitente Y ASUNTO de los cuatro primeros correos. Medido: el
# del 19/09 dejo el microfono sordo 27 segundos clavados (de la pausa a "pausa: fin"), y el
# del 22/09 son 327 caracteres, la frase hablada mas larga de Nova en todo el log, unos 32 s
# al mismo ritmo. De los cuatro asuntos que leyo, DOS eran byte a byte el mismo aviso de
# saldo de su banco: le dijo el saldo de su cuenta en voz alta, dos dias seguidos, sin que lo
# pidiera. Y el 22/09 a las 08:35:41 braya dijo "calla" (confianza 0,94): la UNICA vez en
# todo el log que corta algo que Nova empezo sola. El aviso del ruido sono 25 veces y no lo
# corto ni una.
#
# El aviso no pedido dice de QUIEN es -lo que deja decidir si merece la pena- y no de que.
# El camino PEDIDO no se toca: ahi el asunto es justo lo que hace falta.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Format-Correos')
Invoke-Expression (Traer 'Format-CorreosCorto')

# LOS CORREOS DE VERDAD de la mañana del 22, con los dos de Chase identicos
$delDia = @(
    [pscustomobject]@{ de = 'Chase'; asunto = 'El saldo disponible de tu cuenta esta por debajo de tu limite de $50.00 para la cuenta que termina en...' },
    [pscustomobject]@{ de = 'Chase'; asunto = 'El saldo disponible de tu cuenta esta por debajo de tu limite de $50.00 para la cuenta que termina en...' },
    [pscustomobject]@{ de = 'Experian'; asunto = 'Hay una actualizacion en tu informe de credito de este mes' },
    [pscustomobject]@{ de = 'Steam'; asunto = 'Tu recibo de compra de Steam' },
    [pscustomobject]@{ de = 'YouTube'; asunto = 'Novedades de los canales a los que te suscribiste' }
)

$largo = Format-Correos $delDia
$corto = Format-CorreosCorto $delDia

Write-Host ''
Write-Host '-- la mañana del 22, dicha de las dos formas --'
Write-Host ("     antes: " + $largo)
Write-Host ("     ahora: " + $corto)
Comp 'el corto es mucho mas corto' ($corto.Length -lt ($largo.Length / 2)) "$($corto.Length) contra $($largo.Length) caracteres"
Comp 'cabe en unos diez segundos de voz' ($corto.Length -le 120) "$($corto.Length) caracteres"

Write-Host ''
Write-Host '-- dice de quien, no de que --'
Comp 'nombra a los remitentes' (($corto -match 'Chase') -and ($corto -match 'Experian'))
Comp 'y NO dice el saldo de su banco' (-not ($corto -match 'saldo')) 'ni el asunto de nadie'
Comp 'ni el resto de asuntos' ((-not ($corto -match 'credito')) -and (-not ($corto -match 'recibo')))
Comp 'junta los repetidos en uno' ($corto -match '2 de Chase') 'dos de Chase eran el mismo correo'
Comp 'y dice cuantos hay en total' ($corto -match '5 correos nuevos')
# LA CUENTA TIENE QUE CUADRAR, sea cual sea el reparto: se suman los numeros que dice y los
# "uno de" que nombra, y eso tiene que dar el total. Esperar un numero concreto ataba el
# banco a cuantos remitentes se nombran hoy, que es una decision que puede cambiar.
$dice = ([regex]::Matches($corto, '(\d+) de ')).Count * 0 + (([regex]::Matches($corto, '(\d+) de ') | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Sum).Sum)
$dice += ([regex]::Matches($corto, 'uno de ')).Count
$mas = [regex]::Match($corto, 'y (?:(\d+)|(uno)) mas')
if ($mas.Success) { $dice += $(if ($mas.Groups[2].Success) { 1 } else { [int]$mas.Groups[1].Value }) }
Comp 'la cuenta cuadra: nombrados + resto = total' ($dice -eq 5) "$dice de 5"
Comp 'y el resto se dice en castellano' ($corto -match 'y uno mas') 'no "1 mas"'

Write-Host ''
Write-Host '-- casos raros --'
Comp 'sin correos, lo dice igual que antes' ((Format-CorreosCorto @()) -eq 'No tienes correos nuevos.')
$uno = @([pscustomobject]@{ de = 'Steam'; asunto = 'Tu recibo' })
Comp 'con uno solo, en singular' ((Format-CorreosCorto $uno) -match 'un correo nuevo')
Comp 'y sin asunto' (-not ((Format-CorreosCorto $uno) -match 'recibo'))
$sinDe = @([pscustomobject]@{ de = ''; asunto = 'algo' })
Comp 'sin remitente no se rompe' ((Format-CorreosCorto $sinDe) -match 'alguien')

Write-Host ''
Write-Host '-- y el camino PEDIDO sigue trayendo el asunto --'
Comp 'Format-Correos sigue existiendo' ($fuente -match 'function Format-Correos\(')
Comp 'y sigue diciendo el asunto' ($largo -match 'saldo') 'cuando braya pregunta, eso es lo util'
Comp 'el de la mañana usa el corto' ($fuente -match "Send-AvisoEntorno 'correo-manana' \(Format-CorreosCorto")
Comp 'y el pedido no lo usa' (-not ($fuente -match 'Invoke-Correo.{0,600}Format-CorreosCorto'))

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  el correo que no pediste se dice en una linea'
exit 0
