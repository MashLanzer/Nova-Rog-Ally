# EL TOQUE SUELTO DEL MANDO YA NO SE PIERDE (26/09, idea 36 de las 121).
#
# Un toque corto en el boton de menu (=) no hacia NADA: solo el DOBLE toque (dos en menos de
# 450 ms) abria el panel rapido. MEDIDO: 62 toques sueltos apuntados en el registro que se
# tragaba el vacio, y ninguno era la mitad de un doble (cero pares en el mismo segundo). Ahora,
# pasados 450 ms sin segundo toque, se pinta un vistazo en la capsula -hora, bateria y el aviso
# aparcado si lo hay-, 2,5 s, y se va solo. Es el gemelo del Vistazo() del raton de nova_ui.cs,
# que en una consola de mano no se dispara porque no hay raton.
#
# SOLO TEXTO: ni Say ni Start-Vibracion (regla 1: el boton lo usan los juegos, un toque
# accidental no puede sonar a orden; y el panel si vibra, asi que darle voz volveria los dos
# gestos indistinguibles).
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- EL MUNDO DE MENTIRA (manera 14: se doblan las dependencias, no la pieza que se prueba) ---
$sw = [pscustomobject]@{ ElapsedMilliseconds = 100000 }
function Log($m) { }
function Get-AvisoEspera { return $script:avisoEspera }   # como el real: se lee $script:avisoEspera directo
$script:guardado = 0
function Save-AvisoEspera { $script:guardado++ }
function Add-Estadistica($ruta, $detalle = '__SIN__') { [void]$script:apuntado.Add("$ruta|$detalle") }
function Say($t) { [void]$script:dichoSay.Add([string]$t) }
function Start-Vibracion { [void]$script:vibro.Add('vibro') }
function Set-UI([string]$estado, [string]$texto = '', [int]$ms = 0) {
    [void]$script:setUI.Add(@{ estado = $estado; texto = $texto; ms = $ms })
    # como el real: deja puesto el texto y el plazo, para que la guarda 'ya hay algo' funcione
    $script:uiTexto = $texto
    $script:uiHasta = if ($ms -gt 0) { $sw.ElapsedMilliseconds + $ms } else { 0 }
}

function Limpia {
    $script:panel = $null
    $script:armed = $false
    $script:pendiente = $null
    $script:busy = $false
    $script:capsulaCiega = $false
    $script:uiRetirada = $false
    $script:uiTexto = ''
    $script:uiHasta = 0
    $script:uiBateria = 87
    $script:uiCargando = 0
    $script:avisoEspera = New-Object System.Collections.ArrayList
    $script:toqueEn = 1000
    $script:setUI = New-Object System.Collections.ArrayList
    $script:dichoSay = New-Object System.Collections.ArrayList
    $script:vibro = New-Object System.Collections.ArrayList
    $script:apuntado = New-Object System.Collections.ArrayList
    $script:guardado = 0
}
function Aviso([string]$texto, [int]$minutos) {
    @{ clave = 'x'; texto = $texto; nivel = 'medio'; cada = 60
       vence = (Get-Date).AddMinutes($minutos).ToString('yyyy-MM-ddTHH:mm:ss') }
}
function UltimoTexto { if ($script:setUI.Count) { [string]$script:setUI[$script:setUI.Count - 1].texto } else { '' } }
function UltimoMs { if ($script:setUI.Count) { [int]$script:setUI[$script:setUI.Count - 1].ms } else { -1 } }
function UltimoEstado { if ($script:setUI.Count) { [string]$script:setUI[$script:setUI.Count - 1].estado } else { '' } }

Invoke-Expression (Traer 'Show-Vistazo')

# --------------------------------------------------------------------------------------------
Write-Host '  -- lo que el vistazo dice --'
Limpia
$r1 = Show-Vistazo
Comp '1. el vistazo se pinta' ([bool]$r1) "devolvio $r1"
Comp '   dice la hora' ((UltimoTexto) -match '\d{1,2}:\d{2}') (UltimoTexto)
Comp '   y la bateria' ((UltimoTexto) -match '87%') ''
Comp '2. y lleva plazo (2,5 s, no un modo sin salida)' ((UltimoMs) -eq 2500 -and (UltimoEstado) -eq 'reposo') "ms=$(UltimoMs) estado=$(UltimoEstado)"

Write-Host ''
Write-Host '  -- el aviso aparcado --'
Limpia
[void]$script:avisoEspera.Add((Aviso 'tienes el correo lleno' 30))
$null = Show-Vistazo
Comp '3. el aviso vivo sale en el vistazo' ((UltimoTexto) -match 'correo lleno') (UltimoTexto)
Comp '   sin comerse la hora y la bateria' ((UltimoTexto) -match '\d{1,2}:\d{2}' -and (UltimoTexto) -match '87%') ''

Limpia
[void]$script:avisoEspera.Add((Aviso 'esto ya caduco' -30))
$null = Show-Vistazo
Comp '4. el caducado NO sale' ((UltimoTexto) -notmatch 'esto ya caduco') (UltimoTexto)
Comp '   pero el vistazo se pinta igual' ((UltimoTexto) -match '\d{1,2}:\d{2}') ''

Limpia
[void]$script:avisoEspera.Add((Aviso 'sigo aqui' 30))
$null = Show-Vistazo
$antes = $script:avisoEspera.Count
$null = Show-Vistazo
Comp '5. la cola no se consume' ($script:avisoEspera.Count -eq $antes -and $script:guardado -eq 0) "cola=$($script:avisoEspera.Count), guardado=$($script:guardado)"

Write-Host ''
Write-Host '  -- las guardas: no pisar nada, y sin pintar de mas --'
foreach ($g in @('panel', 'busy', 'pendiente', 'armed', 'capsulaCiega', 'uiRetirada')) {
    Limpia
    if ($g -eq 'panel') { $script:panel = @{ i = 0 } }
    elseif ($g -eq 'pendiente') { $script:pendiente = @{ tipo = 'x' } }
    else { Set-Variable -Name $g -Scope script -Value $true }
    $rg = Show-Vistazo
    Comp "6. con la guarda $g puesta, no se asoma" ((-not $rg) -and $script:setUI.Count -eq 0) "devolvio $rg, set-ui=$($script:setUI.Count)"
}

Write-Host ''
Write-Host '  -- no se repite, no habla, no vibra --'
Limpia
$p = Show-Vistazo
$tras = Show-Vistazo
Comp '7. despues de pintar, deja el toque consumido' ($script:toqueEn -eq 0) "toqueEn=$($script:toqueEn)"
Comp '   y una segunda llamada no repinta' ((-not $tras) -and $script:setUI.Count -eq 1) "segunda=$tras, set-ui=$($script:setUI.Count)"
Comp '8. no habla ni vibra' ($script:dichoSay.Count -eq 0 -and $script:vibro.Count -eq 0) "say=$($script:dichoSay.Count), vibro=$($script:vibro.Count)"
Comp '   se apunta la estadistica sin detalle' ((($script:apuntado -join ' ') -match 'vistazo\|__SIN__')) ($script:apuntado -join ' ')

Write-Host ''
Write-Host '  -- y el bucle lo llama de verdad --'
$txt = [System.IO.File]::ReadAllText($rutaA, [System.Text.Encoding]::UTF8)
# sin lineas de comentario: la rotura tonta de esta tanda es comentar el codigo dejando el
# comentario, que casaria igual. Se filtran las '^\s*#' antes de mirar el cableado.
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '9a. el bucle llama a Show-Vistazo' ($sinCom -match '\[void\]\(Show-Vistazo\)') 'si nadie la llama, la idea no esta puesta'
$iLlam = $sinCom.IndexOf('[void](Show-Vistazo)')
$ini = [Math]::Max(0, $iLlam - 260)
$cerca = if ($iLlam -ge 0) { $sinCom.Substring($ini, [Math]::Min(300, $sinCom.Length - $ini)) } else { '' }
Comp '9b. y solo cuando cruzan los 450 ms sin boton apretado' ($cerca -match '-gt 450' -and $cerca -match '-not \$startNow') 'no con el boton apretado dictando'
Comp '9c. la rama del panel sigue con -le 450 y Open-PanelRapido' ($sinCom -match '-le 450' -and $sinCom -match 'Open-PanelRapido') ''
$nGt = @([regex]::Matches($sinCom, '-gt 450')).Count
$nLe = @([regex]::Matches($sinCom, '-le 450')).Count
Comp '9d. -gt 450 y -le 450 aparecen una vez cada uno' ($nGt -eq 1 -and $nLe -eq 1) "gt=$nGt, le=$nLe (ni solape ni hueco)"

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'el toque suelto del mando ya no se pierde' -ForegroundColor Green
exit 0
