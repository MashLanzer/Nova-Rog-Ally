# "NO ERA ESO" TAMBIEN LLEGA A LO QUE SE METIO EN commands.json (26/09, idea 53 de las 121).
#
# commands.json era el UNICO sitio donde lo aprendido no tenia marcha atras: Invoke-AprenderDelError
# ya deshacia traduccion, receta y cuarentena, pero no el alias. Medido: en 15 dias de registro Nova
# escribio UN alias en commands.json, uno solo, y fue el envenenado ('ajutos' -> '' la noche del
# 22/09). Ahora Add-Alias-Comando marca su origen (aliasNova), "no era eso" lo borra, y "olvida que
# X es Y" a viva voz tambien. Nunca toca lo que puso braya a mano.
#
# TODO SE EJECUTA con las funciones de verdad (AST) sobre un commands.json de mentira. Comprobar el
# borrado con try{}catch{} y una funcion falsa saldria verde con la funcion rota (manera 17).
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

# --- el mundo de mentira ---
$base = Join-Path ([IO.Path]::GetTempPath()) ('aliasol-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$cmdsPath = Join-Path $base 'commands.json'
$script:invitado = $false
$script:cmds = $null
$script:ultimoAlias = $null
$script:ultimaAprendida = ''
$script:ultimaReceta = $null
$script:ultimaRecetaUsada = $false
$script:ultimaRecetaEn = 0
$script:ultimoEjecutado = ''
$sw = [pscustomobject]@{ ElapsedMilliseconds = 100000 }
function Log($m) { }
function ConvertTo-Plain([string]$t) { return $t.ToLower() }
function Write-Atomico($r, $txt) { [IO.File]::WriteAllText($r, $txt) }
function Set-AcabaDeAprender { }
function Add-Rechazo($t) { return $false }
function Write-FalloUso($t) { }
function Remove-Cuarentena($t) { }
function Remove-Traduccion($t) { }
$script:loQueResuelve = $null
function Resolve-Target([string]$t) { if ($null -eq $script:loQueResuelve) { return $null }; return , $script:loQueResuelve }   # la coma: PS desenrolla arrays de un elemento
foreach ($f in @('Test-Prop', 'Add-Alias-Comando', 'Remove-Alias-Comando', 'Invoke-AprenderDelError')) { Invoke-Expression (TraerFn $f) }

# commands.json de mentira. 'steam' en apps SIN marca = de braya; aliasNova vacio.
function Reset {
    $j = @{ apps = @{ 'steam' = 'steam.exe' }; sitios = @{ 'youtube' = 'https://youtube.com' }; aliasNova = @{} }
    [IO.File]::WriteAllText($cmdsPath, ($j | ConvertTo-Json -Depth 8))
    $script:cmds = $null
}
function Bytes { return [IO.File]::ReadAllText($cmdsPath) }
function Leer { return (Get-Content -LiteralPath $cmdsPath -Raw -Encoding UTF8 | ConvertFrom-Json) }

Write-Host ''
Write-Host '-- 1. un alias que escribio Nova se quita (fichero Y memoria) --'
Reset
$script:loQueResuelve = @(@{ kind = 'sitio'; url = 'https://reddit.com'; desc = 'abrir reddit' })
$null = Add-Alias-Comando 'foro' 'reddit'
$q = Remove-Alias-Comando 'foro' $true
$j = Leer
Comp '1. Remove-Alias-Comando devuelve true' ($q -eq $true) "devolvio: $q"
Comp '   y foro ya no esta en el fichero' (-not (Test-Prop $j.sitios 'foro')) ($j.sitios.PSObject.Properties.Name -join ',')
Comp '   ni en $script:cmds (se recargo la memoria)' (-not (Test-Prop $script:cmds.sitios 'foro')) 'sin recargar seguiria resolviendo hasta el reinicio'
Comp '   y la marca aliasNova tambien se limpio' (-not (Test-Prop $j.aliasNova 'foro')) ''

Write-Host ''
Write-Host '-- 2. EL CASO QUE IMPORTA: lo que puso braya a mano NO se toca --'
Reset
$antes = Bytes
$q = Remove-Alias-Comando 'steam' $true       # 'steam' no esta en aliasNova: es de braya
$despues = Bytes
Comp '2. el borrado automatico no se lleva un alias de braya' ($q -eq $false) "devolvio: $q"
Comp '   y commands.json no cambia ni un byte' ($antes -eq $despues) ''

Write-Host ''
Write-Host '-- 3. "no era eso" justo despues de aprender, lo quita --'
Reset
$script:loQueResuelve = @(@{ kind = 'sitio'; url = 'https://reddit.com'; desc = 'abrir reddit' })
$null = Add-Alias-Comando 'foro' 'reddit'      # esto pone $script:ultimoAlias
Comp '3a. tras aprender, $script:ultimoAlias apunta al alias' ($null -ne $script:ultimoAlias -and $script:ultimoAlias.alias -eq 'foro') ''
$ret = Invoke-AprenderDelError $false
$j = Leer
Comp '3b. Invoke-AprenderDelError lo borra del fichero' (-not (Test-Prop $j.sitios 'foro')) ''
Comp '   devuelve aliasOlvidado con el nombre' ($ret.aliasOlvidado -eq 'foro') "aliasOlvidado=$($ret.aliasOlvidado)"
Comp '   y deja $script:ultimoAlias a $null' ($null -eq $script:ultimoAlias) ''

Write-Host ''
Write-Host '-- 4. y no se lleva por delante lo que no era --'
Reset
$script:ultimoAlias = $null
$antes = Bytes
$ret = Invoke-AprenderDelError $false
$despues = Bytes
Comp '4. sin ultimo alias, commands.json no cambia' ($antes -eq $despues) ''
Comp '   aliasOlvidado es $null' ($null -eq $ret.aliasOlvidado) ''
Comp '   y las tres claves de siempre siguen ahi' (($ret.ContainsKey('apuntada')) -and ($ret.ContainsKey('olvidada')) -and ($ret.ContainsKey('recetaOlvidada'))) ''

Write-Host ''
Write-Host '-- 5. olvidar lo que no existe no reescribe el fichero --'
Reset
$antes = Bytes
$q = Remove-Alias-Comando 'nomeinventes' $false
$despues = Bytes
Comp '5. devuelve false y no reescribe' (($q -eq $false) -and ($antes -eq $despues)) "devolvio: $q"

Write-Host ''
Write-Host '-- 6. con un invitado delante no se borra nada --'
Reset
$script:loQueResuelve = @(@{ kind = 'sitio'; url = 'https://reddit.com'; desc = 'abrir reddit' })
$null = Add-Alias-Comando 'foro' 'reddit'
$antes = Bytes
$script:invitado = $true
$q = Remove-Alias-Comando 'foro' $true
$script:invitado = $false
$despues = Bytes
Comp '6. en modo invitado, false y ni un byte cambiado' (($q -eq $false) -and ($antes -eq $despues)) 'la guarda va en la primera linea'

Write-Host ''
Write-Host '-- 7. el camino hablado reparte bien (sonido primero, alias el else) --'
$rf = TraerFn 'Resolve-Fragment'
Comp '7. Resolve-Fragment lleva el objetivo y sigue siendo juegoOlvidaSonido' ($rf.Contains("oido = `$Matches[1].Trim(); objetivo = `$Matches[2].Trim(); desc = 'olvidar como suena ese juego'")) ''
$sinCom = (($fuente -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$iJO = $sinCom.IndexOf("'juegoOlvidaSonido' {")
$iRJO = if ($iJO -ge 0) { $sinCom.IndexOf('Remove-JuegoOido', $iJO) } else { -1 }
$iRAO = if ($iJO -ge 0) { $sinCom.IndexOf('Remove-Alias-Comando', $iJO) } else { -1 }
Comp '   y en el manejador el sonido se prueba ANTES que el alias' ($iRJO -ge 0 -and $iRAO -gt $iRJO) "juego=$iRJO alias=$iRAO"

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL" -ForegroundColor Red; exit 1 }
Write-Host 'un alias aprendido se puede olvidar' -ForegroundColor Green
exit 0
