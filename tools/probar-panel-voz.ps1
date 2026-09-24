# LA VOZ, EN EL MENU DEL MANDO (23/09, idea 14).
#
# LA IDEA PEDIDA SE CAE, y con dato: un boton para "repite eso". En 1.804 frases distintas
# suyas braya NO ha pedido que repita NI UNA VEZ. Un boton para una orden que nadie ha dicho
# jamas sobra, y encima ocupa sitio en el unico menu del mando que hay.
#
# LO QUE SI ESTA RESPALDADO: las dos unicas cosas que pidio sobre como suena Nova -"habla mas
# rapido" y "haz que suene todo un poco mas bajito", las dos del 13/09- solo se pueden pedir
# HABLANDO, y hablando falla el 29,6 % de las veces. Y hay un rato en que hablar no sirve de
# nada: "ARRANQUE: el oido aun carga" sale 39 veces en 244 arranques, y 12 de 12 el 22/09 y
# 12 de 12 el 23/09, con 4,10 s de mediana. Ahi el mando es la unica via.
#
# LO QUE VIGILA ESTE BANCO: que apretar el boton cambie la voz DE VERDAD. Si la rama tocara
# $script:vozVelocidad sin pasar por Set-VozVelocidad, la capsula diria "Voz +30" y la voz
# seguiria hablando igual: braya aprieta, ve que la pantalla le hace caso y oye que no, que
# es peor que no tener el boton.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

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

# --- el mundo de mentira ----------------------------------------------------
$VozCache = Join-Path ([System.IO.Path]::GetTempPath()) ('voz-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $VozCache -Force
$script:vozVelocidad = 0
$script:panelBrillo = -1
$script:panelEnergia = ''
$script:panelSalida = $null
$script:uiMusica = $false
$script:musicaTitulo = ''
$script:panel = @{ i = 0; hasta = 0; nota = '' }
$script:cfg = @{}
$script:cfgEscrituras = 0
$script:uiTexto = ''
function Log([string]$m) { }
function Get-Cfg($sec, $clave, $def = '') { if ($script:cfg.ContainsKey("$sec.$clave")) { return $script:cfg["$sec.$clave"] }; return $def }
function Set-Cfg($sec, $clave, $valor) { $script:cfg["$sec.$clave"] = $valor; $script:cfgEscrituras++; return $true }
function Set-UI([string]$e, [string]$t = '', [int]$ms = 0) { $script:uiTexto = $t }
function Send-Key($k) { }
function Set-Brillo($n) { }
function Get-ModoEnergia { return 'equilibrado' }
function Set-ModoEnergia($m) { return $true }
function Get-SalidasAudio { return @() }
function Start-Vibracion($a, $b) { }
foreach ($v in @('XINPUT_A', 'XINPUT_ARR', 'XINPUT_ABA')) {
    $m = [regex]::Match($fuente, '(?m)^\$' + $v + ' = (.+)$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro $v"; exit 1 }
    Invoke-Expression ('$' + $v + ' = ' + $m.Groups[1].Value)
}
$mP = [regex]::Match($fuente, '(?m)^\$PanelItems = (.+)$')
if (-not $mP.Success) { Write-Host '  MAL  no encuentro $PanelItems'; exit 1 }
$PanelItems = Invoke-Expression $mP.Groups[1].Value
Invoke-Expression (Traer 'Set-VozVelocidad')
Invoke-Expression (Traer 'Show-PanelRapido')
Invoke-Expression (Traer 'Invoke-PanelRapido')

function Pon([string]$item) {
    $i = [array]::IndexOf($PanelItems, $item)
    if ($i -lt 0) { Write-Host "  MAL  '$item' no esta en el panel"; exit 1 }
    $script:panel = @{ i = $i; hasta = 99999; nota = '' }
}

Write-Host ''
Write-Host '-- 1. la voz esta en el menu, y todos los items tienen etiqueta y accion --'
Comp 'el panel tiene "voz"' ($PanelItems -contains 'voz') ($PanelItems -join ', ')
$sp = SinComentarios (Traer 'Show-PanelRapido')
$ip = SinComentarios (Traer 'Invoke-PanelRapido')
$sinEtq = @($PanelItems | Where-Object { $sp -notmatch ("'" + $_ + "' \{") })
Comp 'todos tienen etiqueta' ($sinEtq.Count -eq 0) $(if ($sinEtq.Count) { 'sin etiqueta: ' + ($sinEtq -join ', ') + ' (linea en blanco en la capsula)' } else { "$($PanelItems.Count) items" })
$sinAcc = @($PanelItems | Where-Object { $_ -ne 'salida' -and $ip -notmatch ("'" + $_ + "' \{") })
Comp 'y todos, menos salida, hacen algo' ($sinAcc.Count -eq 0) $(if ($sinAcc.Count) { 'boton muerto: ' + ($sinAcc -join ', ') } else { '' })

Write-Host ''
Write-Host '-- 2. arriba y abajo mueven la voz de verdad --'
Pon 'voz'
$script:vozVelocidad = 0
Invoke-PanelRapido $XINPUT_ARR
Comp 'arriba sube 15' ($script:vozVelocidad -eq 15) "$script:vozVelocidad"
Invoke-PanelRapido $XINPUT_ABA
Invoke-PanelRapido $XINPUT_ABA
Comp 'abajo baja 15 cada vez' ($script:vozVelocidad -eq -15) "$script:vozVelocidad"

Write-Host ''
Write-Host '-- 3. y no se sale del rango que ya tenia la orden hablada --'
Pon 'voz'
$script:vozVelocidad = 45
Invoke-PanelRapido $XINPUT_ARR
Comp 'por arriba se para en 45' ($script:vozVelocidad -eq 45) "$script:vozVelocidad"
$script:vozVelocidad = -30
Invoke-PanelRapido $XINPUT_ABA
Comp 'y por abajo en -30' ($script:vozVelocidad -eq -30) "$script:vozVelocidad"
$sv = SinComentarios (Traer 'Set-VozVelocidad')
# '45' A SECAS CASA DENTRO DE 450 y de 1450: se ancla al tope de verdad
Comp 'el recorte vive en Set-VozVelocidad, no aqui' ($sv -match '-30' -and $sv -match '(?<![0-9])45(?![0-9])' -and $ip -notmatch '\[Math\]::Max\(-30') 'un solo sitio'

Write-Host ''
Write-Host '-- 4. el boton A vuelve a lo normal --'
Pon 'voz'
$script:vozVelocidad = 30
Invoke-PanelRapido $XINPUT_A
Comp 'A deja la voz normal' ($script:vozVelocidad -eq 0) "$script:vozVelocidad"
Show-PanelRapido
Comp 'y la capsula lo dice' ($script:uiTexto -match 'Voz normal') "$script:uiTexto"
$script:vozVelocidad = 15
Show-PanelRapido
Comp 'con signo cuando no es normal' ($script:uiTexto -match 'Voz \+15') "$script:uiTexto"
$script:vozVelocidad = -15
Show-PanelRapido
Comp 'y el menos tambien' ($script:uiTexto -match 'Voz -15') "$script:uiTexto"

Write-Host ''
Write-Host '-- 5. LO QUE TIENE QUE CANTAR: que la voz cambie de verdad --'
# Si la rama tocara la variable sin pasar por Set-VozVelocidad, la capsula diria una cosa y
# la voz haria otra. El worker lee ESTE fichero, no la variable.
Pon 'voz'
$script:vozVelocidad = 0
Invoke-PanelRapido $XINPUT_ARR
$fv = Join-Path $VozCache 'velocidad.txt'
Comp 'velocidad.txt existe tras tocar' (Test-Path -LiteralPath $fv) "$fv"
Comp 'y dice el MISMO numero que la variable' ((Get-Content -LiteralPath $fv -Raw).Trim() -eq [string]$script:vozVelocidad) "fichero='$((Get-Content -LiteralPath $fv -Raw).Trim())' variable='$script:vozVelocidad'"

Write-Host ''
Write-Host '-- 6. config.json solo se reescribe si el numero cambia --'
Pon 'voz'
$script:vozVelocidad = 0
$script:cfg = @{}; $script:cfgEscrituras = 0
Invoke-PanelRapido $XINPUT_ARR
Comp 'la primera vez si se guarda' ($script:cfgEscrituras -eq 1) "$script:cfgEscrituras"
Invoke-PanelRapido $XINPUT_A
Invoke-PanelRapido $XINPUT_A
Comp 'pero volver a lo mismo no reescribe' ($script:cfgEscrituras -eq 2) "$script:cfgEscrituras escrituras para 3 pulsaciones"
$script:vozVelocidad = 45
$script:cfg['voz.velocidad'] = 45
$script:cfgEscrituras = 0
Invoke-PanelRapido $XINPUT_ARR
Comp 'ni tocar arriba estando en el tope' ($script:cfgEscrituras -eq 0) "$script:cfgEscrituras"

Write-Host ''
Write-Host '-- 7. con seis items, los indices siguen dando la vuelta --'
# EJECUTADO, NO CALCULADO (24/09, repaso). Esto era ($i+1) %% $n comparado consigo mismo:
# aritmetica del banco, cero codigo de produccion, verde pase lo que pase. Ahora se pulsa
# abajo n+1 veces de verdad y se mira donde acaba el cursor.
# EL CURSOR NO LO MUEVE Invoke-PanelRapido -esa actua sobre el item de debajo-, lo mueve el
# bloque del mando en el bucle, con izquierda y derecha. Se saca ese trozo del codigo y se
# ejecuta, que es lo unico que prueba la vuelta de verdad.
$n = $PanelItems.Count
$lIzq = @($fuente -split "`r?`n" | Where-Object { $_ -match 'XINPUT_IZQ\) \{ \$script:panel\.i' })[0]
$lDer = @($fuente -split "`r?`n" | Where-Object { $_ -match 'XINPUT_DER\) \{ \$script:panel\.i' })[0]
if (-not $lIzq -or -not $lDer) { Write-Host '  MAL  no encuentro el movimiento del cursor del panel'; exit 1 }
$movIzq = ($lIzq -replace '^\s*elseif \([^)]*\) \{', '') -replace '\}\s*$', ''
$movDer = ($lDer -replace '^\s*elseif \([^)]*\) \{', '') -replace '\}\s*$', ''
function Show-PanelRapido { }
Pon 'voz'
$script:panel.i = 0
for ($i = 0; $i -lt ($n + 1); $i++) { Invoke-Expression $movDer }
Comp 'yendo a la derecha n+1 veces se vuelve al segundo' ($script:panel.i -eq 1) "i=$($script:panel.i) con $n items"
$script:panel.i = 0
Invoke-Expression $movIzq
Comp 'y a la izquierda desde el primero se va al ultimo' ($script:panel.i -eq ($n - 1)) "i=$($script:panel.i)"
Comp 'y el bucle usa el modulo, no un numero fijo' ($fuente -match '\$script:panel\.i \+ 1\) % \$PanelItems\.Count') ''

Write-Host ''
Write-Host '-- 8. el panel sigue teniendo sus tres salidas (regla 2) --'
Comp 'se cierra con B' ($fuente -match 'Close-PanelRapido') ''
Comp 'tiene el item "salida"' ($PanelItems -contains 'salida') ''
Comp 'y vence solo a los 6 s' ((SinComentarios (Traer 'Open-PanelRapido')) -match 'hasta = \$sw\.ElapsedMilliseconds \+ 6000') ''

try { Remove-Item -LiteralPath $VozCache -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  la voz ya se cambia sin hablar'
exit 0
