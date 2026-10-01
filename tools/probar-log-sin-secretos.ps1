# QUE TAPAR LOS SECRETOS SEA COSA DEL REGISTRO, NO DE QUIEN LO LLAMA (26/09, idea 45 de las 121).
#
# Hoy 4 de 144 vuelcos de excepcion tapan la clave de Steam con -replace; los otros 140 no.
# Ninguna se ha escapado aun (0 en los cuatro ficheros de registro), pero son 140 caminos
# abiertos. Ahora Log sustituye el VALOR de cada secreto por *** antes de escribir, asi que
# anadir una clave a claves.json la tapa sin tocar codigo. Este banco ejecuta el Log de VERDAD
# (sacado por AST), no una copia del replace.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$fuente = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- el mundo de mentira: un $EventLog en TEMP, un claves.json en una carpeta temporal ---
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('logsec-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$EventLog = Join-Path $tmp 'assistant.log'
$ClavesPath = Join-Path $tmp 'claves.json'
$SecretoMinCar = if ($fuente -match '(?m)^\$SecretoMinCar\s*=\s*(\d+)') { [int]$Matches[1] } else { -1 }
$script:logEscrituras = 0
function Rotate-Log($x) { }
Invoke-Expression (Traer 'Log')
Invoke-Expression (Traer 'Initialize-Secretos')
function Leer { if (Test-Path -LiteralPath $EventLog) { Get-Content -LiteralPath $EventLog -Raw } else { '' } }
function Vaciar { if (Test-Path -LiteralPath $EventLog) { Remove-Item -LiteralPath $EventLog -Force } }

Comp '0. el suelo de longitud se lee del archivo' ($SecretoMinCar -eq 8) "\$SecretoMinCar = $SecretoMinCar"

Write-Host ''
Write-Host '  -- 1. el control: la comprobacion PUEDE fallar --'
$script:secretosTapar = @()
Vaciar; Log "error con CLAVEFALSA12345"
Comp '1. sin secretos, la cadena SI aparece (el banco mira el sitio bueno)' ((Leer) -match 'CLAVEFALSA12345') 'si no, todo lo demas seria verde con un Log mudo'

Write-Host ''
Write-Host '  -- 2, 3, 4: tapa el valor, deja legible el resto --'
$script:secretosTapar = @('CLAVEFALSA12345')
Vaciar; Log "steam: error con key=CLAVEFALSA12345&steamid=1"
$t = Leer
Comp '2. el secreto NO queda en el registro' ($t -notmatch 'CLAVEFALSA12345') ''
Comp '   y se ve que se tapo (***)' ($t -match '\*\*\*') ''
Comp '3. el resto sigue legible (steam, steamid, la marca)' (($t -match 'steam') -and ($t -match 'steamid=1') -and ($t -match '\d{4}-\d\d-\d\d \d\d:\d\d:\d\d')) 'un log tapado de mas no sirve'
Vaciar; Log "el juego CLAVEFALSA no arranca"
Comp '4. una palabra que es TROZO del secreto sale intacta' ((Leer) -match 'CLAVEFALSA no arranca') 'replace literal, no un patron que se coma prefijos'

Write-Host ''
Write-Host '  -- 5. la rama de los saltos de linea (por donde se escapa de verdad) --'
Vaciar; Log ("linea uno`nerror key=CLAVEFALSA12345`nlinea tres")
$t5 = Leer
Comp '5. el secreto en la SEGUNDA linea tambien se tapa' (($t5 -notmatch 'CLAVEFALSA12345') -and ($t5 -match 'linea tres')) 'el foreach va antes del if de los saltos'

Write-Host ''
Write-Host '  -- 6. la lista se construye bien (todas las claves + las de entorno, sin las cortas) --'
[IO.File]::WriteAllText($ClavesPath, '{"steam":"SECRETOLARGO123456","otra":"OTROSECRETOLARGO99","vacia":"","corta":"abc"}')
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', "APIKEYFALSA1234567890`n", 'Process')
[Environment]::SetEnvironmentVariable('NOVA_CORREO_CLAVE', 'CORREOFALSA123456', 'Process')
Initialize-Secretos
$L = @($script:secretosTapar)
Comp '6. entran las DOS claves del json, no solo steam' (($L -contains 'SECRETOLARGO123456') -and ($L -contains 'OTROSECRETOLARGO99')) 'la promesa entera de la idea'
Comp '   entran las dos variables de entorno (con Trim del salto)' (($L -contains 'APIKEYFALSA1234567890') -and ($L -contains 'CORREOFALSA123456')) ''
Comp '   NO entra la vacia ni la corta' (($L -notcontains '') -and ($L -notcontains 'abc')) "por el suelo de $SecretoMinCar"
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $null, 'Process')
[Environment]::SetEnvironmentVariable('NOVA_CORREO_CLAVE', $null, 'Process')

Write-Host ''
Write-Host '  -- 7. la cadena vacia: filtrada no mata a Log; a pelo, si (por eso el filtro) --'
$script:secretosTapar = @($L | Where-Object { $_ })
Vaciar
$vivo = $true
try { Log 'una linea cualquiera' } catch { $vivo = $false }
Comp '7. con la lista filtrada, Log escribe sin reventar' ($vivo -and ((Leer) -match 'una linea cualquiera')) ''
# un '' JUNTO a un secreto de verdad (un @('') a solas se desenvuelve a '' y el if se lo salta):
$script:secretosTapar = @('SECRETOLARGO123456', '')
$lanzo = $false
try { Log 'esto deberia lanzar' } catch { $lanzo = $true }
Comp '   y con un "" en la lista, Log LANZA (documenta el filtro)' $lanzo 'Replace("") tira ArgumentException'

Write-Host ''
Write-Host '  -- 8, 9, 10: el cableado sobre el fuente --'
# sin comentarios: el comentario de Log NOMBRA Initialize-Secretos para explicar por que la
# lista se carga fuera; casar eso seria un verde mintiendo (manera 16)
$txtLog = (((Traer 'Log') -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '8. Log no toca el disco ni el entorno para esto' (($txtLog -notmatch 'Get-Content') -and ($txtLog -notmatch 'Test-Path') -and ($txtLog -notmatch 'GetEnvironmentVariable') -and ($txtLog -notmatch 'Initialize-Secretos')) 'seria un Get-Content por linea'
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$iCarga = $sinCom.IndexOf("`nInitialize-Secretos")
$iURL = $sinCom.IndexOf('key=$clave')
Comp '9. Initialize-Secretos se llama a nivel de fichero, ANTES de las URL con la clave' ($iCarga -ge 0 -and $iURL -ge 0 -and $iCarga -lt $iURL) "carga en $iCarga, url en $iURL"
# 10. LOS -replace DE LOS SITIOS QUE LLAMAN SIGUEN PUESTOS. Son el cinturon de encima del
# tapado que ya hace Log, y estan porque la clave de Steam viaja DENTRO de la URL: cualquier
# excepcion de red la arrastraria entera al registro.
#
# ESTO ESTABA ESCRITO COMO '$nViejos -eq 4' Y SE PUSO ROJO EL 01/10 SIN QUE NADIE LO ROMPIERA:
# las funciones 13, 14 y 15 de las 20 anadieron dos sitios mas -los correctos, con su tapado
# puesto- y pasaron a ser SEIS. Es la manera 14 de los bancos que mienten: un numero escrito a
# mano dentro de un banco caduca en cuanto el codigo crece, y encima caduca hacia el ROJO, o sea
# que gasta una tarde en algo que estaba bien. Lo que hay que exigir no es 'cuatro': es que TODO
# sitio que registre una excepcion de la red de Steam la tape. Eso crece con el fichero solo.
$lineasSteam = @(($fuente -split "`n") | Where-Object {
    $_ -match '\$_\.Exception\.Message' -and $_ -match 'Log \("(?:steam|amigos|steam async|regla de amigo)'
})
$sinTapar = @($lineasSteam | Where-Object { $_ -notmatch 'key=\[\^&' })
Comp '10. todo registro de un fallo de la red de Steam tapa la clave' ($lineasSteam.Count -ge 4 -and $sinTapar.Count -eq 0) "$($lineasSteam.Count) sitios, $($sinTapar.Count) sin tapar"
foreach ($lS in $sinTapar) { Write-Host ('       ' + $lS.Trim()) -ForegroundColor Red }
# Y EL TOTAL NO PUEDE BAJAR DE LOS CUATRO QUE HABIA: asi un borrado silencioso sigue cazandose,
# que es para lo que se escribio esta comprobacion.
$nViejos = @([regex]::Matches($fuente, 'key=\[\^&\\s\]\+')).Count
Comp '    y no son menos que los cuatro de cuando se escribio esto' ($nViejos -ge 4) "$nViejos"

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
exit 0
