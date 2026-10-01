# UN AVISO 'bajo' QUE PIERDE LA TARJETA SE PIERDE ENTERO (1/10, idea 11 de las 20 nuevas)
#
# Send-AvisoEntorno marca el aviso como dado -$script:entornoVistos y Save-EntornoVistos- y DESPUES
# intenta pintar la tarjeta. El comentario que habia alli decia que si la tarjeta falla no importa,
# porque "lo que no se puede perder es que SUENE".
#
# ESO ES FALSO PARA LOS DE NIVEL 'bajo', que son precisamente los que NO suenan: se ven y ya. Si la
# tarjeta falla, ese aviso se pierde ENTERO y encima queda marcado como dado, asi que no vuelve a
# intentarse hasta que pase su cadaMin -que para 'gmail-lleno' es una semana-.
#
# CASO REAL del 30/09 a las 20:18, en el registro: "ENTORNO (estreno-animo, bajo)" fallo la tarjeta
# y se perdio del todo. Ese mismo minuto fallaron 'me-olvide' y 'me-cai', pero esos son 'medio' y si
# se dijeron ("lo digo igual"): el unico que se perdio fue el de nivel 'bajo'.
#
# Y EL AGUJERO CRECIO EL MISMO DIA: la idea 9 baja a 'bajo' los avisos que nunca sirven.
#
# LO QUE DEFIENDE:
#  1. que un 'bajo' con la tarjeta rota NO se de por dado, ni en memoria ni en disco;
#  2. que un 'medio' con la tarjeta rota SI se de por dado, porque ese se dice igual;
#  3. que cuando la tarjeta funciona, nada de esto se note;
#  4. y que se apunte, para poder contar cuantos se han perdido.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
$EntornoOn = $true
$AvisoReaccionMin = 8; $AvisoReaccionCeroMin = 5; $AvisoMudoCeros = 8; $AvisoEsperaTope = 6
# Y LAS DEL FINAL DE LA FUNCION, que tambien hacen falta: sin $AvisosMirarMax el while de la cola de
# observacion comparaba contra $null y acababa con "El indice estaba fuera del intervalo", que desde
# fuera parece un fallo del codigo y era del banco. Los mismos valores que el fichero.
$AvisoReaccionVentanaMs = 300000
$AvisosMirarMax = 4
foreach ($n in @('Get-ReaccionesAviso', 'Get-NivelAviso', 'Send-AvisoEntorno')) { Invoke-Expression (Traer $n) }

# --- los dobles, DESPUES de cargar lo de verdad ---
$script:entornoVistos = @{}
$script:guardado = 0
function Save-EntornoVistos { $script:guardado++ ; $script:enDisco = @{} ; foreach ($k in $script:entornoVistos.Keys) { $script:enDisco[$k] = $script:entornoVistos[$k] } }
function Get-EntornoVistos { return $script:entornoVistos }
$script:enDisco = @{}
$script:log = @()
function Log([string]$m) { $script:log += $m }
$script:apuntes = @()
function Add-Estadistica([string]$k, [string]$v = '') { $script:apuntes += "$k|$v" }
function Test-AvisoAplazable([string]$c, [string]$n) { return $false }
function Test-PuedoAvisar([string]$c, [string]$n = 'medio', [int]$m = 60) { return $true }
function Get-Estadisticas { return @{ dias = @{} } }
$script:dicho = @()
function Send-Aviso([string]$t, [string]$c = '') { $script:dicho += $t }
function Set-UI([string]$e, [string]$t = '', [int]$m = 0) { }
$script:uiMia = $false
$script:ultimaRespuesta = ''
# LA TARJETA, CON INTERRUPTOR: asi el banco decide si se puede pintar y no lo decide la maquina
# donde corre (si dependiera de que haya capsula de verdad, seria la manera 7).
$script:tarjetaVa = $true
$script:pintadas = 0
function Show-Popup([string]$t, [string]$e = 'hablando') {
    if (-not $script:tarjetaVa) { throw "El termino 'Show-Popup' no se reconoce" }
    $script:pintadas++
}
# EL CAMINO DE 'medio' SIGUE HASTA LA VOZ, asi que hacen falta sus piezas: sin ellas la seccion 3
# se rompia con "No se puede llamar a un metodo en una expresion con valor NULL", que desde fuera
# parece un fallo del codigo y era del banco.
$script:avisoCola = New-Object System.Collections.ArrayList
$script:avisoColaDesde = 0
$script:avisosMirar = New-Object System.Collections.ArrayList
$script:entornoAvisos = New-Object System.Collections.ArrayList
function Send-AvisoCola([string]$t = '', [string]$c = '') { $script:dicho += $t; return $true }
function Test-CabeOtroAviso { return $true }
function Start-Dictado { }
function Get-EsperaAviso([string]$c, [int]$b) { return $b }
$sw = [pscustomobject]@{}
$sw | Add-Member -MemberType ScriptProperty -Name ElapsedMilliseconds -Value { 0 }
function Reset { $script:entornoVistos = @{}; $script:enDisco = @{}; $script:log = @(); $script:apuntes = @()
                 $script:dicho = @(); $script:pintadas = 0; $script:guardado = 0
                 $script:avisoCola = New-Object System.Collections.ArrayList
                 $script:avisosMirar = New-Object System.Collections.ArrayList }

Write-Host ''
Write-Host '-- 1. con la tarjeta funcionando, nada de esto se nota --'
Reset
$r = Send-AvisoEntorno 'estreno-juego' 'Bajaste algo y no lo has abierto' 'bajo' 1440
Comp 'el aviso sale' ([bool]$r) "$r"
Comp '  se pinta la tarjeta' ($script:pintadas -eq 1) "$($script:pintadas)"
Comp '  y queda dado' ($script:entornoVistos.ContainsKey('estreno-juego')) ''
Comp '  tambien en disco' ($script:enDisco.ContainsKey('estreno-juego')) ''
Comp '  y no se apunta ningun perdido' (@($script:apuntes | Where-Object { $_ -match '^aviso-perdido' }).Count -eq 0) "$($script:apuntes -join ' ')"

Write-Host ''
Write-Host '-- 2. CON LA TARJETA ROTA Y NIVEL "bajo": no se da por dado --'
# Es el caso del 30/09: ese aviso no suena, asi que si la tarjeta falla no ha llegado por ningun
# lado. Darlo por dado es perderlo hasta que pase su cadaMin, que puede ser una semana.
Reset
$script:tarjetaVa = $false
$r2 = Send-AvisoEntorno 'estreno-juego' 'Bajaste algo y no lo has abierto' 'bajo' 1440
Comp 'devuelve falso: no se ha avisado' (-not $r2) "$r2"
Comp '  y NO queda dado en memoria' (-not $script:entornoVistos.ContainsKey('estreno-juego')) "$($script:entornoVistos.Keys -join ',')"
Comp '  NI en disco' (-not $script:enDisco.ContainsKey('estreno-juego')) "$($script:enDisco.Keys -join ',')"
Comp '  se apunta como perdido' (@($script:apuntes | Where-Object { $_ -match '^aviso-perdido\|estreno-juego' }).Count -eq 1) "$($script:apuntes -join ' ')"
Comp '  y lo dice, explicando que lo deja sin dar' (@($script:log | Where-Object { $_ -match 'SIN DAR' }).Count -eq 1) "$($script:log -join ' | ')"
# Y SE PUEDE REINTENTAR: lo siguiente es que al volver a intentarlo, con la tarjeta arreglada, salga
$script:tarjetaVa = $true
$r3 = Send-AvisoEntorno 'estreno-juego' 'Bajaste algo y no lo has abierto' 'bajo' 1440
Comp 'y al arreglarse la tarjeta, el aviso SALE' ([bool]$r3 -and $script:pintadas -eq 1) "$r3"
Comp '  y ahora si queda dado' ($script:entornoVistos.ContainsKey('estreno-juego')) ''

Write-Host ''
Write-Host '-- 3. con la tarjeta rota y nivel "medio": SI se da por dado --'
# Ese se dice igual, asi que SI ha llegado. Deshacer el marcado ahi lo repetiria en voz alta.
Reset
$script:tarjetaVa = $false
$r4 = Send-AvisoEntorno 'me-olvide' 'He dejado de hacer la copia' 'medio' 1440
Comp 'el aviso cuenta como dado' ([bool]$r4) "$r4"
Comp '  y queda marcado' ($script:entornoVistos.ContainsKey('me-olvide')) ''
Comp '  y se dice que se dice igual' (@($script:log | Where-Object { $_ -match 'lo digo igual' }).Count -eq 1) "$($script:log -join ' | ')"
Comp '  y NO se apunta como perdido' (@($script:apuntes | Where-Object { $_ -match '^aviso-perdido' }).Count -eq 0) ''
$script:tarjetaVa = $true

Write-Host ''
Write-Host '-- 4. el cableado --'
$cuerpo = Traer 'Send-AvisoEntorno'
$sin = (($cuerpo -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$iMarca = $sin.IndexOf('$script:entornoVistos[$clave] = ')
$iPinta = $sin.IndexOf('Show-Popup $texto')
$iDes = $sin.IndexOf('$script:entornoVistos.Remove($clave)')
Comp 'se marca como dado antes de pintar (como siempre)' ($iMarca -ge 0 -and $iPinta -gt $iMarca) "marca en $iMarca, pinta en $iPinta"
Comp '  y se DESHACE despues, si hizo falta' ($iDes -gt $iPinta -and $iPinta -ge 0) "deshace en $iDes"
# POR ORDEN Y NO POR DISTANCIA (ver probar-bancos-fragiles).
$iQuita = $sin.IndexOf('entornoVistos.Remove($clave)')
$iSave = $sin.IndexOf('Save-EntornoVistos', [Math]::Max(0, $iQuita))
Comp '  tocando el disco tambien' ($iQuita -ge 0 -and $iSave -gt $iQuita) 'si no, un reinicio lo daria por dado'
Comp '  y solo para los que no suenan' ($sin -match "-not \`$pintada -and \`$nivel -eq 'bajo'") ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'un aviso que solo se ve no se da por dado si no se ha podido ver' -ForegroundColor Green
exit 0
