# UN RECORDATORIO CON LA FECHA ILEGIBLE SE BORRABA EN SILENCIO (24/09).
#
# LA MEDICION QUE LO DESTAPO: CERO lineas "RECORDATORIO vence" en las 54.428 del registro, con
# 295 "RECORDATORIO (...)" creados. Ninguno ha sonado nunca. Y el del 12/09 16:59:48 vencia el
# 13/09 a las 10:00:00 con Nova VIVA a esa hora exacta -hay una linea suya a las 10:00:00
# clavadas-.
#
# EL AGUJERO estaba en una linea:
#
#     try { $c = [DateTime]$r.cuando } catch { continue }
#
# Ese 'continue' saltaba al siguiente SIN pasar por el 'else { $quedan += $r }' de abajo, y el
# Save-Recordatorios de dos lineas mas alla guardaba la lista SIN esa entrada. O sea: una fecha
# que no se puede leer no aplazaba el recordatorio, LO BORRABA DEL DISCO, y sin una linea.
#
# LO QUE MAS SE VIGILA AQUI: que no se borre, que no se repita la linea en cada vuelta -el
# bucle pasa por aqui constantemente, y eso seria el fallo de los 25 avisos identicos del
# 22/09 con otra ropa- y que los buenos sigan funcionando exactamente igual.
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

$base = Join-Path ([System.IO.Path]::GetTempPath()) ('recor-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$RecordatoriosPath = Join-Path $base 'recordatorios.json'

foreach ($f in @('Get-Recordatorios', 'Save-Recordatorios', 'Write-Atomico', 'Test-Recordatorios')) {
    Invoke-Expression (Traer $f)
}
# dobles: lo que Nova diria y lo que apuntaria, sin hablar ni vibrar de verdad
$script:dicho = New-Object System.Collections.ArrayList
$script:avisos = New-Object System.Collections.ArrayList
$script:stats = New-Object System.Collections.ArrayList
function Log([string]$m) { [void]$script:dicho.Add($m) }
function Send-Aviso([string]$t, [string]$k) { [void]$script:avisos.Add($t) }
function Start-Vibracion($p) { }
function Invoke-Despertador { [void]$script:avisos.Add('despertador') }
function Save-Corrupto($a, $b) { }
function Add-Estadistica($a, $b) { [void]$script:stats.Add("$a|$b") }
$script:recordatorioIlegible = New-Object System.Collections.ArrayList

function Limpia {
    $script:dicho.Clear(); $script:avisos.Clear(); $script:stats.Clear()
    $script:recordatorioIlegible.Clear()
}
function Pon($lista) { Save-Recordatorios $lista }

Write-Host ''
Write-Host '-- 1. EL AGUJERO: una fecha ilegible ya no borra el recordatorio --'
Limpia
Pon @(
    @{ texto = 'sacar la basura'; cuando = 'esto no es una fecha' },
    @{ texto = 'llamar a mi madre'; cuando = (Get-Date).AddHours(3).ToString('s') }
)
Comp 'de partida hay dos' ((@(Get-Recordatorios)).Count -eq 2) "$((@(Get-Recordatorios)).Count)"
Test-Recordatorios
$tras = @(Get-Recordatorios)
Comp 'tras la vuelta siguen los DOS' ($tras.Count -eq 2) "$($tras.Count)"
Comp 'y el de la fecha rota sigue ahi' (@($tras | Where-Object { $_.texto -eq 'sacar la basura' }).Count -eq 1) ''
Comp 'y deja una linea que lo dice' (@($script:dicho | Where-Object { $_ -match 'ilegible' }).Count -eq 1) "$($script:dicho -join ' | ')"
Comp 'y un contador para poder vigilarlo' (@($script:stats | Where-Object { $_ -match '^recordatorio-ilegible' }).Count -eq 1) "$($script:stats -join ' ')"

Write-Host ''
Write-Host '-- 2. pero la linea NO se repite en cada vuelta --'
# El bucle pasa por aqui constantemente. Si esto se cayera, un solo recordatorio roto
# escribiria una linea por vuelta hasta llenar el registro, que es el fallo del 22/09.
$antes = @($script:dicho | Where-Object { $_ -match 'ilegible' }).Count
for ($i = 1; $i -le 60; $i++) { Test-Recordatorios }
$ahora = @($script:dicho | Where-Object { $_ -match 'ilegible' }).Count
Comp 'sesenta vueltas mas y ni una linea de mas' ($ahora -eq $antes) "$ahora linea(s) en total"
Comp 'y el recordatorio sigue en su sitio' (@(@(Get-Recordatorios) | Where-Object { $_.texto -eq 'sacar la basura' }).Count -eq 1) ''

Write-Host ''
Write-Host '-- 3. y los buenos siguen funcionando igual --'
Limpia
Pon @(
    @{ texto = 'esto vence'; cuando = (Get-Date).AddMinutes(-5).ToString('s') },
    @{ texto = 'esto no'; cuando = (Get-Date).AddHours(2).ToString('s') }
)
Test-Recordatorios
Comp 'el que vencio suena' (@($script:avisos | Where-Object { $_ -match 'esto vence' }).Count -eq 1) "$($script:avisos -join ' | ')"
Comp 'y deja su linea de siempre' (@($script:dicho | Where-Object { $_ -match 'RECORDATORIO vence' }).Count -eq 1) ''
$q = @(Get-Recordatorios)
Comp 'el que no vencio se queda' ($q.Count -eq 1 -and $q[0].texto -eq 'esto no') "$($q.Count)"
Comp 'y el que sono se va del disco' (@($q | Where-Object { $_.texto -eq 'esto vence' }).Count -eq 0) ''

Write-Host ''
Write-Host '-- 4. el roto y el bueno conviven, que es el caso que importa --'
# Si el roto rompiera la vuelta, el bueno de detras no llegaria a sonar nunca. Por eso van
# en este orden: el ilegible PRIMERO.
Limpia
Pon @(
    @{ texto = 'roto'; cuando = 'ayer por la tarde' },
    @{ texto = 'vence ya'; cuando = (Get-Date).AddMinutes(-1).ToString('s') },
    @{ texto = 'para luego'; cuando = (Get-Date).AddHours(5).ToString('s') }
)
Test-Recordatorios
Comp 'el bueno de detras del roto SI suena' (@($script:avisos | Where-Object { $_ -match 'vence ya' }).Count -eq 1) "$($script:avisos -join ' | ')"
$q2 = @(Get-Recordatorios)
Comp 'quedan el roto y el de luego' ($q2.Count -eq 2) "$($q2.Count)"
Comp 'y el roto es uno de ellos' (@($q2 | Where-Object { $_.texto -eq 'roto' }).Count -eq 1) 'no se tira'

Write-Host ''
Write-Host '-- 5. el despertador, que no es un aviso --'
Limpia
Pon @(@{ texto = 'despertador'; cuando = (Get-Date).AddMinutes(-2).ToString('s') })
Test-Recordatorios
Comp 'el despertador suena, no avisa' (@($script:avisos | Where-Object { $_ -eq 'despertador' }).Count -eq 1) ''
Comp 'y se va de la lista' ((@(Get-Recordatorios)).Count -eq 0) ''

Write-Host ''
Write-Host '-- 6. LO QUE NO HACE: adivinar la fecha --'
$tr = SinComentarios (Traer 'Test-Recordatorios')
Comp 'no se inventa una fecha' (($tr -notmatch 'AddDays') -and ($tr -notmatch 'AddHours') -and ($tr -notmatch 'Get-Date\)\.Add')) 'un recordatorio sin fecha no se recoloca'
# SOLO EL CATCH DE LA FECHA, no un trozo a partir de el: a 300 caracteres de distancia esta
# el Send-Aviso LEGITIMO del recordatorio que vence, y la comprobacion pasaba por su culpa.
# El regex vive una sola vez, abajo, y de ahi salen las tres comprobaciones.
Comp 'y el que no vence sigue conservandose' ($tr -match '\$quedan \+= \$r') ''
# Y QUE EL CONTINUE NO VUELVA A SALTARSE EL GUARDADO: es el fallo exacto de hoy.
$fin = [char]10 + '        }'
$catchFecha = [regex]::Match($tr, '(?s)\[DateTime\]\$r\.cuando \} catch \{(.*?)' + [regex]::Escape($fin))
$dentro = $(if ($catchFecha.Success) { $catchFecha.Groups[1].Value } else { '' })
Comp 'el catch de la fecha se encuentra' ($catchFecha.Success) ''
Comp 'y conserva la entrada' ($dentro -match '\$quedan \+= \$r') 'era un continue pelado'
Comp 'y no avisa de algo que no sabe cuando era' ($catchFecha.Success -and $dentro -notmatch 'Send-Aviso') ''
Comp 'ni hace vibrar el mando por ello' ($catchFecha.Success -and $dentro -notmatch 'Start-Vibracion') ''

Write-Host ''
Write-Host '-- 7. y el que la llama ya no se traga el fallo --'
$sinCom = (($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
Comp 'el catch del bucle deja rastro' ($sinCom -match 'try \{ Test-Recordatorios \} catch \{ Log') 'estaba vacio'
Comp 'y no queda ningun catch vacio ahi' ($sinCom -notmatch 'Test-Recordatorios \} catch \{\}') ''

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  un recordatorio con la fecha rota ya no se borra solo'
exit 0
