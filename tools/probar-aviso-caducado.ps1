# LO QUE TE PROMETIO DECIR, SE DICE (25/09, idea 5)
#
# LO MEDIDO: 4 avisos han caducado SIN DECIRSE desde que existe esa linea (24/09 01:38), dos de
# ellos la madrugada del 25 a las 23:52 y 23:53 -gmail-lleno y disco-poco-.
#
# POR QUE ES FEO, y no es un detalle: esos avisos estan en la cola PRECISAMENTE porque Nova
# decidio no molestar a braya en su momento y se prometio decirselos cuando volviera. Que
# despues se tiren en silencio convierte esa promesa en un agujero: ni se dijeron entonces ni
# se dicen nunca, y desde fuera es igual que si Nova no se hubiera enterado de nada.
#
# LO QUE SE HACE: antes de tirar uno por caducidad, si NUNCA se llego a decir, se dice -tarde,
# y diciendo que es tarde-. Si caducan varios a la vez, se juntan en una frase: tres avisos
# viejos sueltos son tres interrupciones por cosas que ya pasaron.
#
# LO QUE NO SE HACE: resucitar cualquier cosa. Un aviso caducado se dice UNA vez, al caducar, y
# con su nivel rebajado -no es una urgencia: es algo que ya paso-.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. un aviso caducado ya no se tira callando --'
Comp 'existe Get-FraseCaducados' ($sinCom -match 'function Get-FraseCaducados') ''
Comp 'y se dice al caducar' ($sinCom -match "Send-AvisoEntorno 'lo-que-no-dije'") 'por la puerta de siempre'
Comp 'se sigue apuntando el caducado' ($sinCom -match "Add-Estadistica 'aviso-caducado'") 'la estadistica no se pierde'
# Y QUE SE RECOJAN DE VERDAD (25/09, lo cazo una rotura): la frase puede existir y llamarse, y
# aun asi no decir nada si nadie mete los caducados en la lista. Sin esta comprobacion, borrar
# el "$caducados += $x" del bucle dejaba el banco verde y los avisos se seguian tirando
# callando, que es justo el fallo que esto arregla.
$iCad = $sinCom.IndexOf("Add-Estadistica 'aviso-caducado'")
$blCad = if ($iCad -gt 0) { $sinCom.Substring([Math]::Max(0, $iCad - 200), [Math]::Min(400, $sinCom.Length - [Math]::Max(0, $iCad - 200))) } else { '' }
Comp 'y se recogen para decirlos' ($blCad -match '\$caducados \+=') 'si no se recogen, no hay nada que decir'

Write-Host ''
Write-Host '-- 2. LA FRASE, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-FraseCaducados' }, $true)
if (-not $d) {
    Comp 'se saca Get-FraseCaducados del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
function Log([string]$m) { }

Comp 'sin caducados no dice nada' ([string]::IsNullOrEmpty((Get-FraseCaducados @()))) ''

$uno = @(@{ clave = 'gmail-lleno'; texto = 'Tienes el correo casi lleno.' })
$f = Get-FraseCaducados $uno
Comp 'con uno, lo dice y avisa de que es tarde' (($f -match 'correo') -and ($f -match '(?i)se me paso|a tiempo|tarde')) "$f"

$tres = @(
    @{ clave = 'gmail-lleno'; texto = 'Tienes el correo casi lleno.' },
    @{ clave = 'disco-poco'; texto = 'Te quedan 5 gigas en el disco.' },
    @{ clave = 'oido-ruido'; texto = 'Hay un ruido de fondo constante.' })
$f3 = Get-FraseCaducados $tres
Comp 'con tres, van en UNA frase' (($f3 -match 'correo') -and ($f3 -match 'disco') -and ($f3 -match 'ruido')) ''
Comp '  y en una sola frase, no tres' ((@([regex]::Matches($f3, '(?i)se me paso|no llegue a decirte')).Count) -le 1) 'tres avisos viejos no son tres interrupciones'

# LOS VACIOS NO CUENTAN
Comp 'los vacios no cuentan' ([string]::IsNullOrEmpty((Get-FraseCaducados @(@{ clave = 'x'; texto = '' })))) ''

Write-Host ''
Write-Host '-- 3. y no se resucita lo que ya no importa --'
$iC = $sinCom.IndexOf("Send-AvisoEntorno 'lo-que-no-dije'")
$linC = if ($iC -gt 0) { $sinCom.Substring($iC, [Math]::Min(200, $sinCom.Length - $iC)).Split([char]10)[0] } else { '' }
Comp 'se dice con nivel bajo o medio, no alto' ($linC -notmatch "'alto'") 'es algo que ya paso, no una urgencia'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que te prometio decir, se dice'
exit 0
