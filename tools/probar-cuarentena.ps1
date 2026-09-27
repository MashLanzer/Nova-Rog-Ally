# LO APRENDIDO NO TOCA EL DISCO HASTA QUE SOBREVIVE TU CORRECCION (26/09, idea 15 de las 121).
#
# EL CASO QUE LO DESTAPO, con hora exacta: el 25/09 a la 01:26:12 Nova aprendio
# 'Cierra este in.' = 'cierra discord' y lo bajo a disco al instante. DIECISIETE SEGUNDOS
# despues, a la 01:26:29, braya dijo "No dije Discord, dije Steam". Demasiado tarde: ya estaba
# escrito, apuntando a la app por la que habla con su pareja, y ahi se quedo hasta que alguien
# lo vio a mano al dia siguiente.
#
# LO QUE CAMBIA: lo aprendido espera un rato EN MEMORIA antes de bajar a disco. La entrada SI
# entra en $script:traducciones desde el primer momento -Nova la usa ya-; lo unico que espera
# es el fichero. Si braya corrige en ese rato, no llega a escribirse nunca.
#
# Y EL PLAZO SE APRENDE de lo que braya tarda en corregir, que es justo lo que hay que medir.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ps1 = Join-Path $raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. los cuatro numeros, y de donde salen --'
foreach ($c in @('CuarentenaArranque', 'CuarentenaSuelo', 'CuarentenaTecho', 'CuarentenaMinimas')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $c + '\s*=\s*([0-9]+)'))
    Comp ("se saca del archivo " + $c) $m.Success ''
    if ($m.Success) { Set-Variable -Name $c -Value ([int]$m.Groups[1].Value) }
}
# EL DE ARRANQUE TIENE QUE CUBRIR EL CASO REAL: braya tardo 17 s en corregir lo de Discord.
Comp 'el de arranque cubre los 17 s del caso real' ($CuarentenaArranque -ge 17000) "$([int]($CuarentenaArranque/1000)) s"
Comp '  y no se pasa' ($CuarentenaArranque -le $CuarentenaTecho) ''
Comp 'el techo no apuesta a que Nova no muera' ($CuarentenaTecho -le 60000) "$([int]($CuarentenaTecho/1000)) s; muere 235 veces en 14 dias"
Comp 'el suelo da tiempo a oir la frase' ($CuarentenaSuelo -ge 5000) "$([int]($CuarentenaSuelo/1000)) s"

Write-Host ''
Write-Host '-- 2. lo aprendido se usa YA, pero no se escribe --'
$dA = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Add-Traduccion' }, $true)
Comp 'se encuentra Add-Traduccion' ($null -ne $dA) ''
if ($dA) {
    $c = (($dA.Extent.Text -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    # LO QUE NO PUEDE CAMBIAR: la entrada sigue entrando en la tabla que Nova consulta.
    Comp '  la entrada entra en la tabla igual que antes' ($c -match '\$t\[\$clave\] = \$traducida') 'Nova la usa desde ahora mismo'
    # LO QUE SI CAMBIA: ya no baja a disco aqui.
    Comp '  pero YA NO se guarda al momento' ($c -notmatch 'Save-Traducciones') 'ese era el fallo del 25/09'
    Comp '  sino que entra en la cola' ($c -match 'traduccionesCuarentena\.Add') ''
    # Y EL "APRENDIDO" SE HA MOVIDO: decirlo aqui seria anunciar algo que puede no llegar.
    Comp '  y no dice "APRENDIDO" antes de tiempo' ($c -notmatch 'APRENDIDO') 'se dice al bajar a disco, no al ponerlo en cola'
    # LAS GUARDAS DE SIEMPRE NO SE TOCAN
    Comp '  el modo invitado sigue vetado' ($c -match '\$script:invitado') ''
    Comp '  y lo destructivo sigue sin aprenderse' ($c -match 'NO APRENDO una traduccion destructiva') ''
}

Write-Host ''
Write-Host '-- 3. el plazo, ejecutado --'
foreach ($n in @('Get-CorreccionTiempos', 'Add-CorreccionTiempo', 'Get-CuarentenaMs', 'Flush-Cuarentena', 'Remove-Cuarentena')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    Comp "existe $n" ($null -ne $d) ''
    if ($d -and $n -in @('Get-CorreccionTiempos', 'Get-CuarentenaMs')) { Invoke-Expression $d.Extent.Text }
}
$dP = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-NubePercentil' }, $true)
if ($dP) { Invoke-Expression $dP.Extent.Text }
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-cuar-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$MemoriaDir = $tmp
$CorreccionTiemposJson = Join-Path $tmp 'correcciones-tiempos.json'
function Log([string]$m) { }
function Write-Atomico([string]$r, [string]$c) { [IO.File]::WriteAllText($r, $c, (New-Object Text.UTF8Encoding($false))) }
try {
    Comp 'sin muestras, manda el de arranque' ((Get-CuarentenaMs) -eq $CuarentenaArranque) "$([int]($CuarentenaArranque/1000)) s"
    # CON MUESTRAS: el p90 de lo que braya tarda, acotado.
    $l = @(12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, 25000, 40000)
    [IO.File]::WriteAllText($CorreccionTiemposJson, (ConvertTo-Json -InputObject $l -Compress), (New-Object Text.UTF8Encoding($false)))
    $p = Get-CuarentenaMs
    Comp 'con muestras, sale su p90' ($p -eq 25000) "$([int]($p/1000)) s de una lista cuyo p90 es 25 s"
    # Y ACOTADO POR ARRIBA Y POR ABAJO: lo que impide que una racha rara lo deje inservible.
    [IO.File]::WriteAllText($CorreccionTiemposJson, (ConvertTo-Json -InputObject @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10) -Compress), (New-Object Text.UTF8Encoding($false)))
    Comp '  nunca por debajo del suelo' ((Get-CuarentenaMs) -eq $CuarentenaSuelo) "$([int]($CuarentenaSuelo/1000)) s"
    [IO.File]::WriteAllText($CorreccionTiemposJson, (ConvertTo-Json -InputObject @(99000, 99000, 99000, 99000, 99000, 99000, 99000, 99000, 99000, 99000) -Compress), (New-Object Text.UTF8Encoding($false)))
    Comp '  ni por encima del techo' ((Get-CuarentenaMs) -eq $CuarentenaTecho) "$([int]($CuarentenaTecho/1000)) s"
    # POCAS MUESTRAS: manda el de arranque, aunque las pocas que haya digan otra cosa.
    [IO.File]::WriteAllText($CorreccionTiemposJson, (ConvertTo-Json -InputObject @(40000, 40000) -Compress), (New-Object Text.UTF8Encoding($false)))
    Comp '  y con dos muestras, todavia no' ((Get-CuarentenaMs) -eq $CuarentenaArranque) "hacen falta $CuarentenaMinimas"
    # BASURA EN EL FICHERO: ni revienta ni inventa
    [IO.File]::WriteAllText($CorreccionTiemposJson, '{roto', (New-Object Text.UTF8Encoding($false)))
    Comp '  con el fichero roto, el de arranque' ((Get-CuarentenaMs) -eq $CuarentenaArranque) ''
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '-- 4. y las dos salidas de la cola --'
# LAS DOS SALIDAS Y UN PLAZO, que es la regla 2 de la casa: o vence y baja a disco, o braya
# corrige y se tira. Nunca se queda ahi para siempre.
Comp 'lo que vence baja a disco' ($sinCom -match 'Flush-Cuarentena') ''
$iF = $sinCom.IndexOf('function Flush-Cuarentena')
$blF = if ($iF -ge 0) { $sinCom.Substring($iF, [Math]::Min(900, $sinCom.Length - $iF)) } else { '' }
Comp '  con UNA sola escritura para todas' (@([regex]::Matches($blF, 'Save-Traducciones')).Count -eq 1) 'Save-Traducciones reescribe el fichero entero'
Comp '  y ahi si se dice APRENDIDO' ($blF -match 'APRENDIDO') ''
$iR = $sinCom.IndexOf('function Remove-Cuarentena')
$blR = if ($iR -ge 0) { $sinCom.Substring($iR, [Math]::Min(900, $sinCom.Length - $iR)) } else { '' }
Comp 'y lo corregido se tira antes de escribirse' ($blR -match '\$t\.Remove') ''
# Y SE MIDE LO QUE TARDO: de ahi sale el plazo de manana. Sin esto el numero no se aprende.
Comp '  midiendo cuanto tardaste en corregir' ($blR -match 'Add-CorreccionTiempo') 'de ahi sale el plazo de manana'
# EL ENGANCHE: el rechazo lo llama, y el bucle vacia.
Comp 'el rechazo vacia la cuarentena' ($sinCom -match "Remove-Cuarentena 'lo rechazaste'") ''
function EnOrden([string]$t, [string]$a, [string]$b) {
    $ma = [regex]::Match($t, $a); if (-not $ma.Success) { return $false }
    return [regex]::Match($t.Substring($ma.Index + $ma.Length), $b).Success
}
Comp '  y va ANTES de Remove-Traduccion' (EnOrden $sinCom "Remove-Cuarentena 'lo rechazaste'" "Remove-Traduccion \`$olvidada") 'si sigue en cola, no hay nada que borrar del fichero'
Comp 'el bucle baja lo que vence' ($sinCom -match '\$script:traduccionesCuarentena\.Count -gt 0 -and') ''
Comp '  y no cuesta nada con la cola vacia' ($sinCom -match 'traduccionesCuarentena\.Count -gt 0 -and \(\$sw\.ElapsedMilliseconds - \$script:cuarentenaCheck\)') 'regla 4'

Write-Host ''
Write-Host '-- 5. el caso del 25/09, en el registro --'
$hay = $false
foreach ($f in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $f
    if (-not (Test-Path -LiteralPath $ruta)) { continue }
    foreach ($l in @(Get-Content -LiteralPath $ruta -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($l -match "APRENDIDO: 'Cierra este in\.' = 'cierra discord'") { $hay = $true }
    }
}
Write-Host ("       el aprendizaje de 'Cierra este in.' esta en el registro: $hay")
Comp 'el caso que lo motiva es real' $hay 'el 25/09 a la 01:26:12, corregido 17 s despues'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo aprendido espera a ver si lo corriges'
exit 0
