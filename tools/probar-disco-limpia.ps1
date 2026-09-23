# SOLTAR SITIO EN EL DISCO (23/09, funcion 6 de la tanda de funciones nuevas).
#
# Nova ya avisaba pero no sabia actuar, y encima prometia algo que no tenia: CUATRO veces le
# ha dicho a braya "te quedan X gigas, preguntame que ocupa mas" -20/09 con 14,5 GB, 21/09 con
# 14,9, 22/09 con 11,1 y 23/09 con 13,8- y "que ocupa mas" NO EXISTIA. El unico parser de
# tamaño era "cuanto ocupa {juego}", y el "lo que mas ocupa" que si existe mide RAM, no disco.
#
# ESTA ES LA FUNCION MAS PELIGROSA DE LA TANDA porque borra. Lo que se vigila aqui es
# exactamente eso: que la lista sea CERRADA y escrita en el codigo, que solo tenga cosas que
# el sistema regenera solo, que pregunte antes, y que el numero que dice salga de medir el
# disco y no de sumar lo que creia haber borrado.
$ErrorActionPreference = 'Stop'
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
function TraerVar([string]$n) {
    $as = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $x.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $x.Left.VariablePath.UserPath -eq $n }, $true)
    if (-not $as) { Write-Host "  MAL  no encuentro `$$n"; exit 1 }
    return $as.Extent.Text
}
Invoke-Expression (TraerVar 'CachesLimpiables')
Invoke-Expression (Traer 'Get-TamanoMB')
Invoke-Expression (Traer 'Get-FacturaDisco')

Write-Host ''
Write-Host '-- la lista es cerrada y solo de cosas regenerables --'
Comp 'la lista esta escrita en el codigo' ($CachesLimpiables.Count -ge 3) "$($CachesLimpiables.Count) sitios"
$malas = @($CachesLimpiables | Where-Object {
    $r = [string]$_.ruta
    $r -match '(?i)(Documents|Downloads|Desktop|Pictures|Videos|Music|OneDrive|Saved Games)'
})
Comp 'no hay nada suyo en la lista' ($malas.Count -eq 0) $(if ($malas) { ($malas.ruta -join '; ') } else { 'ni Documentos, ni Descargas, ni Escritorio' })
foreach ($c in $CachesLimpiables) {
    $esCache = ([string]$c.ruta -match '(?i)(cache|temp)')
    Comp ("'" + $c.nombre + "' es regenerable") $esCache ([string]$c.ruta)
}
Comp 'ninguna ruta sale de la voz' (-not ($fuente -match "(?s)CachesLimpiables.{0,900}\`$Matches")) 'la lista no se toca desde una orden'

Write-Host ''
Write-Host '-- y los temporales, solo los VIEJOS --'
$temp = @($CachesLimpiables | Where-Object { [string]$_.ruta -eq $env:TEMP })
Comp 'TEMP esta en la lista' ($temp.Count -eq 1)
Comp 'y con un plazo de dias' ($temp.Count -eq 1 -and [int]$temp[0].dias -ge 3) "$($temp[0].dias) dias" 
Comp 'Get-TamanoMB respeta ese plazo' ((Traer 'Get-TamanoMB') -match 'LastWriteTime -lt \$corte')

Write-Host ''
Write-Host '-- la factura sale de medir, no de un numero escrito --'
$fac = @(Get-FacturaDisco)
Comp 'la factura se calcula' ($fac.Count -ge 0) "$($fac.Count) sitio(s) con algo que soltar"
foreach ($f in $fac) { Write-Host ("       {0,8} MB  {1}" -f $f.mb, $f.nombre) }
Comp 'y ordena por tamaño' ($fac.Count -lt 2 -or $fac[0].mb -ge $fac[1].mb) ''

Write-Host ''
Write-Host '-- borra de verdad, y lo dice midiendo el disco --'
$limpia = Traer 'Clear-CachesDisco'
Comp 'usa Remove-Item, no la papelera' ($limpia -match 'Remove-Item') 'la papelera mueve pero no libera'
Comp 'mide el disco antes' ($limpia -match '(?s)\$antes = .{0,140}AvailableFreeSpace') ''
Comp 'y despues' ($limpia -match '(?s)\$despues = \$antes.{0,200}AvailableFreeSpace') ''
Comp 'el numero que dice es la resta' ($limpia -match 'soltado = \[Math\]::Round\(\$despues - \$antes') 'no la suma de lo que creia borrar'
Comp 'y no toca la carpeta de Nova' ($limpia -match 'voice-ctrl') 'ahi viven sus copias y sus medidas'

Write-Host ''
Write-Host '-- y pregunta antes de borrar --'
Comp 'arma confirmacion' ($fuente -match "(?s)'discoLimpia'.{0,700}\`$script:pendiente = @\{") ''
Comp 'y dice QUE va a borrar y cuanto' ($fuente -match 'voy a borrar') ''
Comp 'solo borra si braya confirma' ($fuente -match "(?s)'discoLimpia'.{0,900}if \(-not \`$script:confirmado\)") ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  te dice que ocupa y suelta solo lo que se regenera'
exit 0
