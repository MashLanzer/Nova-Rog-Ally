# UNA REGLA, DE PUNTA A PUNTA (24/09, idea 3 de la tanda nueva).
#
# LO MEDIDO, y es de las cosas mas raras del registro: `reglas.json` esta VACIO. En quince
# dias braya creo DOS -una por voz el 11/09 a la 01:18:50, que borro 31 segundos despues, y
# otra escrita el 14/09- y NINGUNA ha disparado jamas. Cero lineas de una regla ejecutandose
# en 54.428.
#
# No es que no sepa que existen: Nova se lo ofrecio cuatro veces ("puedes decir: cuando abra
# un juego, pon modo juego"). Es que le fallaron a la cara -el 11/09 a la 01:16:21 le dijo
# "entendi la condicion, pero no reconozco la accion 'pon modo noche'", y la MISMA frase
# funciono dos minutos y medio despues- y que el motor reviento tres veces con un NULL que ya
# no esta (eso lo cubre probar-regla-rota.ps1).
#
# LO QUE NADIE HA COMPROBADO NUNCA, y es lo que hace este banco: que el ciclo ENTERO funcione.
# Crear la regla por voz, que se guarde, que sobreviva al disco, que dispare cuando toca y que
# NO dispare cuando no toca. Cada pieza tenia su prueba; el camino completo, ninguna.
#
# Y LO QUE MAS SE VIGILA: que no dispare de mas. Una regla que se ejecuta sola cuando no toca
# es la regla 1 rota de la peor manera posible, porque braya ni siquiera ha hablado.
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

# las piezas del camino, sacadas del archivo de verdad
# TODAS LAS FUNCIONES DEL ARCHIVO, no una lista a mano. Invoke-ReglaVoz llama a mas de veinte
# -Find-Juego, Resolve-SujetoRegla, Test-FastCommand...- y cada una llama a las suyas; una
# lista escrita a mano se queda corta a la primera y el banco muere a mitad, que es justo lo
# que paso al escribirlo. Definir funciones no ejecuta nada del cuerpo del script.
$cargadas = 0
foreach ($fn in $ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    try { Invoke-Expression $fn.Extent.Text; $cargadas++ } catch {}
}
if ($cargadas -lt 400) { Write-Host "  MAL  solo se cargaron $cargadas funciones"; exit 1 }
# y las constantes de nivel superior que usan (los regex de las reglas, los topes...)
foreach ($a in $ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] }, $false)) {
    try { Invoke-Expression $a.Extent.Text } catch {}
}

$base = Join-Path ([System.IO.Path]::GetTempPath()) ('regla-' + [System.Guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $base -Force
$ReglasPath = Join-Path $base 'reglas.json'
'[]' | Set-Content -LiteralPath $ReglasPath -Encoding UTF8

# LOS DOBLES VAN DESPUES DE CARGAR EL ARCHIVO, y no antes: al traerse las 500 y pico funciones
# reales, cualquier doble definido arriba queda PISADO por la de verdad y el banco acaba
# ejecutando acciones de verdad -o fallando porque le falta el entorno-. Paso al escribirlo.
$script:dicho = New-Object System.Collections.ArrayList
$script:hecho = New-Object System.Collections.ArrayList
function Log([string]$m) { [void]$script:dicho.Add($m) }
function Add-Estadistica($a, $b) { }
function Save-Corrupto($a, $b) { }
function Submit-Command([string]$t) { [void]$script:hecho.Add($t) }
function Test-FastCommand([string]$t) { return $true }
function Send-Aviso([string]$t, [string]$k = '') { [void]$script:hecho.Add("aviso: $t") }
function Invoke-FastCommand([string]$t) { [void]$script:hecho.Add($t); return 'hecho' }
function Refresh-UI { }
# QUE EL BANCO NO HABLE. Al traerse las funciones reales, alguna acaba en Piper y deja un .wav
# en piper\salida: paso al escribir esto. Un banco no puede tener efectos fuera de su carpeta.
function Say([string]$t, [string]$e = '') { [void]$script:dicho.Add("dice: $t") }
function Say-Online([string]$t, [string]$e = '') { return $false }
function Say-Piper([string]$t) { return $false }
function Play-Audio($a) { }
function Start-Vibracion($p) { }
function Pausar-Escucha($ms) { }
function Set-UI($a, $b = '', $c = 0) { }
$script:reglasDisparadas = 0
$script:reglasCaducadas = 0
$script:invitado = $false
$script:confirmado = $true
$script:reglas = $null

Write-Host ''
Write-Host '-- 1. SE CREA POR VOZ, que es como lo intento el 11/09 --'
# La frase es la suya, palabra por palabra: "cuando abra elden ring pon modo noche".
$r1 = Invoke-ReglaVoz 'cuando abra elden ring pon modo noche'
Comp 'la frase del 11/09 crea la regla' ([bool]$r1) "$r1"
$g = Get-Reglas
Comp 'y queda UNA guardada' (@($g).Count -eq 1) "$(@($g).Count)"
Comp 'con su condicion' (@($g)[0].tipo -eq 'juegoAbre') "tipo: $(@($g)[0].tipo)"
Comp 'y con el juego que dijo' ((@($g)[0].valor -replace '\s+', ' ') -match '(?i)elden ring') "valor: $(@($g)[0].valor)"

Write-Host ''
Write-Host '-- 2. SOBREVIVE AL DISCO --'
# Si esto se cayera, la regla existiria hasta el siguiente reinicio, que son doce al dia.
$script:reglas = $null
$g2 = Get-Reglas
Comp 'se relee del fichero' (@($g2).Count -eq 1) "$(@($g2).Count)"
Comp 'y con lo mismo dentro' (@($g2)[0].tipo -eq 'juegoAbre') ''

Write-Host ''
Write-Host '-- 3. Y DISPARA CUANDO TOCA, que es lo que no ha pasado NUNCA --'
$script:hecho.Clear()
Invoke-Reglas 'juegoAbre' 'ELDEN RING'
Comp 'al abrir ELDEN RING, la regla se ejecuta' ($script:reglasDisparadas -ge 1) "disparadas: $($script:reglasDisparadas)"
Comp 'y hace lo que decia' (@($script:hecho | Where-Object { $_ -match 'modo noche' }).Count -ge 1) "$($script:hecho -join ' | ')"

Write-Host ''
Write-Host '-- 4. y NO dispara cuando no toca --'
# Esto es lo que mas importa de todo el banco: una regla que se ejecuta sola cuando no toca es
# la regla 1 rota de la peor manera, porque braya ni siquiera ha hablado.
foreach ($caso in @(
    @{ t = 'juegoAbre';   d = 'It Takes Two'; que = 'con otro juego' },
    @{ t = 'juegoCierra'; d = 'ELDEN RING';   que = 'al CERRAR el mismo juego' },
    @{ t = 'appAbre';     d = 'ELDEN RING';   que = 'al abrir una app con ese nombre' },
    @{ t = 'bateria';     d = '10';           que = 'al bajar la bateria' },
    @{ t = 'cascosPone';  d = 'pone';         que = 'al ponerse los cascos' }
)) {
    $script:hecho.Clear(); $script:reglasDisparadas = 0
    Invoke-Reglas $caso.t $caso.d
    Comp ("$($caso.que), NO dispara") ($script:reglasDisparadas -eq 0) "disparadas: $($script:reglasDisparadas)"
}

Write-Host ''
Write-Host '-- 5. el ciclo entero, con las otras formas que Nova ofrece --'
# Son las que ella misma dice cuando le preguntas que puede hacer, mas las cuatro del banco de
# arranque. Si alguna no completara el ciclo, Nova estaria ofreciendo algo que no funciona.
$formas = @(
    @{ f = 'cuando abra un juego pon modo juego';          t = 'juegoAbre';    d = 'Hollow Knight' },
    @{ f = 'cuando cierre elden ring pon el brillo al 80'; t = 'juegoCierra';  d = 'ELDEN RING' },
    @{ f = 'cuando me ponga los cascos sube el volumen';   t = 'cascosPone';   d = 'pone' },
    @{ f = 'cuando quite el cargador pon modo ahorro';     t = 'cargadorQuita'; d = 'quita' }
)
foreach ($x in $formas) {
    '[]' | Set-Content -LiteralPath $ReglasPath -Encoding UTF8
    $script:reglas = $null
    $creada = Invoke-ReglaVoz $x.f
    $script:hecho.Clear(); $script:reglasDisparadas = 0
    Invoke-Reglas $x.t $x.d
    $ok = [bool]$creada -and $script:reglasDisparadas -ge 1
    Comp ("'$($x.f.Substring(0, [Math]::Min(42, $x.f.Length)))'") $ok $(if ($ok) { 'se crea y dispara' } else { "creada=$([bool]$creada) disparadas=$($script:reglasDisparadas)" })
}

Write-Host ''
# OJO CON @(Get-Reglas): NO desenrolla. Get-Reglas devuelve ",$lista" para que una lista
# vacia no se convierta en $null, y esa misma coma hace que @() vea la LISTA entera como UN
# objeto, o sea .Count = 1 siempre. Hay que asignar primero y envolver despues. Escribiendo
# este banco volvio a morder, y esta advertido en el propio archivo desde el 20/09.
Write-Host '-- 6. y se puede borrar, que es un modo con salida --'
# braya borro su primera regla 31 segundos despues de crearla. Si borrarla no funcionara, una
# regla seria un modo sin salida, que es la regla 2 de la casa.
'[]' | Set-Content -LiteralPath $ReglasPath -Encoding UTF8
$script:reglas = $null
[void](Invoke-ReglaVoz 'cuando abra elden ring pon modo noche')
$gAntes = Get-Reglas
Comp 'hay una regla' (@($gAntes).Count -eq 1) "$(@($gAntes).Count)"
$rb = Invoke-ReglaVoz 'borra las reglas'
$gTras = Get-Reglas
Comp 'y "borra las reglas" la quita' (@($gTras).Count -eq 0) "$rb, quedan $(@($gTras).Count)"
$script:reglas = $null
$gDisco = Get-Reglas
Comp 'y sigue borrada tras releer el disco' (@($gDisco).Count -eq 0) 'no vuelve al reiniciar'

Write-Host ''
Write-Host '-- 7. y con un invitado delante SI se puede, que esta decidido a conciencia --'
# Aqui me equivoque al escribir el banco y conviene que quede: di por hecho que un invitado no
# podria crear reglas, y el proyecto tiene la decision tomada al reves desde el 17/09.
# Save-Reglas esta en la lista de exentas de probar-invitado.ps1 con su motivo: "una regla se
# pide a proposito". El modo invitado existe para que Nova no APRENDA sola de quien no es
# braya, no para que deje de obedecer a alguien que le esta pidiendo algo a la cara.
'[]' | Set-Content -LiteralPath $ReglasPath -Encoding UTF8
$script:reglas = $null
$script:invitado = $true
[void](Invoke-ReglaVoz 'cuando abra elden ring pon modo noche')
$gInv = Get-Reglas
Comp 'con invitado, una regla PEDIDA si se crea' (@($gInv).Count -eq 1) 'se pide a proposito; no es aprender solo'
Comp 'y sigue exenta con su motivo escrito' ((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'probar-invitado.ps1') -Raw) -match "'Save-Reglas'\s*=\s*'una regla se pide a proposito'") 'si alguien cambia de idea, que lo cambie ahi'
$script:invitado = $false

Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  una regla se crea, se guarda, dispara cuando toca y calla cuando no'
exit 0
