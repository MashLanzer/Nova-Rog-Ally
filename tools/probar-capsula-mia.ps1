# LO QUE NOVA HACE SOLA SE VE IGUAL QUE LO QUE LE PEDISTE (26/09, idea 54 de las 121).
#
# Medido: 100 aviso-entorno y 14 aviso-dicho en 11 dias -86 decisiones propias que solo se VIERON,
# exactamente igual que una respuesta a una orden. Ninguna de las 35 claves del JSON de la capsula
# decia de QUIEN fue la idea. Ahora un campo "mia" en ui-estado.json y un tinte ambar en 'hablando'
# (mas un aro fino sobre el glifo para cuando una regla dispare, hoy cero veces).
#
# El aviso de entorno se EJECUTA (es el camino de los 100). Invoke-Reglas, Process-Texto y nova_ui.cs
# se comprueban sobre su texto sacado por AST/IndexOf: comprobar '$src -match mia' saldria verde con
# la marca en un comentario, asi que se mira el sitio exacto.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
$fallos = 0
function Comp($etq, $ok, $det = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:fallos++ }
}

# --- 1. EJECUTAR el aviso de entorno: tiene que marcar $script:uiMia = $true ---
function Log($m) { }
function Add-Estadistica($a, $b = '') { }
function Show-Popup($t, $e = 'hablando') { }
function Save-EntornoVistos { }
function Send-AvisoCola($y = $false) { }
function Test-AvisoAplazable($c, $n = 'medio', $a = (Get-Date)) { return $false }   # no hay nadie fuera: no se aparca
function Test-PuedoAvisar($c, $n = 'medio', $cada = 60) { return $true }            # se permite: forzamos el camino que habla
function Add-AvisoEspera($c, $t, $n, $cada) { return $false }
$script:entornoVistos = @{}
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$script:entornoAvisos = New-Object System.Collections.ArrayList
$script:ultimaRespuesta = ''
$script:avisoMirar = $null
$AvisoReaccionVentanaMs = 180000
$sw = [pscustomobject]@{ ElapsedMilliseconds = 100000 }
$script:uiMia = $false
Invoke-Expression (TraerFn 'Send-AvisoEntorno')

Write-Host ''
Write-Host '-- 1. un aviso de entorno enciende la marca "mia" --'
$r = Send-AvisoEntorno 'dock' 'Pantalla conectada.' 'medio' 60
Comp '1. tras un aviso de entorno, $script:uiMia queda en true' ($script:uiMia -eq $true) "aviso salio: $r"

Write-Host ''
Write-Host '-- 2 y 3. la marca se pone donde toca y se apaga con una orden tuya --'
$reglasTxt = TraerFn 'Invoke-Reglas'
Comp '2. Invoke-Reglas marca la autoria al disparar una regla' ($reglasTxt -match '\$script:confirmado = \$true\s*\r?\n\s*\$script:uiMia = \$true') 'pegado a $script:confirmado, la apaga el vuelta-a-reposo'
$procTxt = TraerFn 'Process-Texto'
Comp '3. Process-Texto la APAGA (una orden tuya nunca sale marcada como mia)' ($procTxt -match '\$script:uiMia = \$false') 'sin esto, marcar de mas es peor que no marcar (regla 1)'
# y en Set-UI la marca caduca (dos salidas + plazo). El campo lo prueba de verdad probar-json-ui.ps1.
$setTxt = TraerFn 'Set-UI'
Comp '   y Set-UI la hace caducar al volver al reposo/escuchar' ($setTxt -match "if \(\`$estado -eq 'reposo' -or \`$estado -eq 'retirada' -or \`$estado -eq 'escuchando'\) \{ \`$script:uiMia = \`$false \}") 'regla 2: no hay modo sin salida'
Comp '   y escribe el campo "mia" en el JSON' ($setTxt.Contains(',"mia":"')) ''

Write-Host ''
Write-Host '-- 4..7. la capsula (nova_ui.cs): tinte, aro y sin animacion sin fin --'
$cs = [IO.File]::ReadAllText((Join-Path $raiz 'nova_ui.cs'))
Comp '4. lee el campo "mia" del JSON' ($cs.Contains('Campo(j, "mia"')) ''
# el tinte va DENTRO del case "hablando" (troceado por IndexOf, sin regex de distancia -> trinquete de fragiles)
$iH = $cs.IndexOf('case "hablando":')
$iErr = if ($iH -ge 0) { $cs.IndexOf('case "error":', $iH) } else { -1 }
$bloqueH = if ($iH -ge 0 -and $iErr -gt $iH) { $cs.Substring($iH, $iErr - $iH) } else { '' }
Comp '5. el tinte "if (mia)" esta dentro del case "hablando"' ($bloqueH.Contains('if (mia)')) ''
Comp '6. el aro aroMia se anade a capaAccion.Children' ($cs.Contains('capaAccion.Children.Add(aroMia)')) ''
# el aro NO puede llevar animacion sin fin (probar-json-ui exige tope de frames a toda Forever)
$iAro = $cs.IndexOf('aroMia = new Ellipse()')
$iAroFin = if ($iAro -ge 0) { $cs.IndexOf('capaAccion.Children.Add(aroMia)', $iAro) } else { -1 }
$bloqueAro = if ($iAro -ge 0 -and $iAroFin -gt $iAro) { $cs.Substring($iAro, $iAroFin - $iAro) } else { 'x' }
Comp '7. el aro no lleva animacion sin fin (Forever)' (-not $bloqueAro.Contains('Forever')) ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL" -ForegroundColor Red; exit 1 }
Write-Host 'lo que Nova hace sola se marca en la capsula' -ForegroundColor Green
exit 0
