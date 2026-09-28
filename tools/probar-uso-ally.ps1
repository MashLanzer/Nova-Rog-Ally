# EL CUADERNO DE LA ALLY: QUE SE HACE CON LA CONSOLA, HABLE BRAYA O NO (25/09)
#
# LO PIDIO EL, con estas palabras: "a veces no hablo con nova pero paso horas con ella jugando o
# encendida o haciendo cosas, y eso nova deberia saberlo tambien, ya que ella tiene que
# controlar toda la Ally".
#
# LO MEDIDO, y es lo que lo justifica: Nova YA mira que hay en primer plano cada 10 s, pero solo
# se queda con ello si es un juego. De todo lo demas no guarda nada. Y el unico motor que podria
# proponerle algo -Find-Propuesta- come de habitos.usos, que son ORDENES DE VOZ: 34 entradas de
# 27 tipos distintos en 6 dias, asi que su condicion de "lo mismo a la misma hora en tres dias"
# no se cumple nunca y no ha propuesto NADA jamas. Mientras tanto la consola deja 49 comienzos
# de juego en 10 dias, 169 sucesos de cargador y 211 de descargas, y de 737 dictados en 14 dias
# NI UNO pide una regla.
#
# LA DISTINCION QUE LO DECIDE TODO, y la puso braya: "la consola esta encendida tambien porque
# tu estas trabajando ahi". ENCENDIDA NO ES EN USO. Por eso cada tramo cae en una de dos
# cuentas que no se suman: 'con' (alguien toco algo hace poco) y 'sin' (despierta y sola).
# Y si no se puede saber -Get-InactividadMin devuelve -1- el tramo NO se apunta en ninguna:
# inventarse que hay alguien seria peor que perder diez segundos.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function TraerVar([string]$n) {
    $m = [regex]::Match($fuente, '(?m)^\$' + $n + '\s*=\s*(.+?)\s*$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro la variable $n"; exit 1 }
    return $m.Groups[1].Value
}

# LAS CONSTANTES, DEL ARCHIVO: una copia aqui probaria mi numero y no el de Nova (manera 4).
foreach ($v in @('UsoAllyOcioMin', 'UsoAllyMax', 'UsoAllyDias')) {
    Invoke-Expression ('$' + $v + ' = ' + (TraerVar $v))
}
Write-Host ("       del archivo: ocio $UsoAllyOcioMin min, tope $UsoAllyMax apps, $UsoAllyDias dias")

# el fichero de mentira, en temporal: el cuaderno de braya no se toca
$tmpU = Join-Path ([IO.Path]::GetTempPath()) ("usoally-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tmpU)
$UsoAllyPath = Join-Path $tmpU 'uso-ally.json'
function Log([string]$m) { }
function Save-Corrupto([string]$a, [string]$b) { }
$script:invitado = $false
$script:usoAllyPend = @{}
$script:usoAlly = $null
# FALTABAN TRES EN CADENA (27/09, idea 86): Get-DiaJuego ya no lleva el 5 escrito dentro, se lo
# pregunta a Get-CorteDia; esa sale de Get-FranjaMuerta, y esa de Get-HorasConActividad. Sin las
# tres el banco moria en el caso 1 con "el termino 'Get-CorteDia' no se reconoce". Se traen de
# verdad, no se doblan: la hora a la que parte el dia tiene que ser la misma que en Nova.
foreach ($f in @('Get-UsoAlly', 'Add-UsoAlly', 'Save-UsoAlly',
        'Get-HorasConActividad', 'Get-FranjaMuerta', 'Get-CorteDia', 'Get-DiaJuego')) { Invoke-Expression (Traer $f) }
# y los numeros de la franja, del archivo tambien: una copia aqui probaria los mios (manera 4)
foreach ($v in @('FranjaHorasMin', 'FranjaDiasMin', 'CorteDiaPorDefecto')) {
    Invoke-Expression ('$' + $v + ' = ' + (TraerVar $v))
}
$script:franjaCalculadaDia = ''
$script:franjaMuerta = $null
$script:corteDia = $CorteDiaPorDefecto
# LAS DOS FUENTES DE ACTIVIDAD, VACIAS AQUI, y el doble va DESPUES de cargar las piezas buenas para
# que no tape a ninguna. Este banco no prueba la franja -eso es probar-franja-muerta.ps1- y el
# cuaderno de braya no se toca. Sin datos, Get-FranjaMuerta hace lo que hace en la consola cuando
# aun no hay $FranjaDiasMin dias: no opina, y el dia parte en $CorteDiaPorDefecto, que es el real.
function Get-Habitos { return @{ usos = @() } }
$ActivacionesJsonl = Join-Path $tmpU 'activaciones-que-aqui-no-hay.jsonl'
$hoy = [datetime]'2026-09-25 14:00'

try {
Write-Host ''
Write-Host '-- 1. ENCENDIDA NO ES EN USO: dos cuentas que no se suman --'
Add-UsoAlly 'ELDEN RING' 60 0                       # braya jugando
Add-UsoAlly 'ELDEN RING' 60 90                      # la consola sola, 90 min sin tocar nada
Save-UsoAlly $hoy
$u = Get-UsoAlly
$dia = Get-DiaJuego $hoy
Comp 'apunta el dia' ($u.ContainsKey($dia)) "dia=$dia"
Comp 'y la app, aunque nadie haya hablado' ($u[$dia].ContainsKey('ELDEN RING')) ($u[$dia].Keys -join ',')
Comp 'con alguien delante va a "con"' ([int]$u[$dia]['ELDEN RING']['con'] -eq 60) "con=$($u[$dia]['ELDEN RING']['con'])"
Comp 'y encendida y sola va a "sin"' ([int]$u[$dia]['ELDEN RING']['sin'] -eq 60) "sin=$($u[$dia]['ELDEN RING']['sin'])"

Write-Host ''
Write-Host '-- 2. LO QUE NO ES UN JUEGO TAMBIEN CUENTA --'
# Esto es lo que no existia: hasta hoy, si delante habia un navegador, no quedaba rastro.
Add-UsoAlly 'msedge' 30 1
Add-UsoAlly 'explorer' 20 1
Save-UsoAlly $hoy
$u = Get-UsoAlly
Comp 'un navegador deja rastro' ($u[$dia].ContainsKey('msedge')) ($u[$dia].Keys -join ',')
Comp 'y el explorador tambien' ($u[$dia].ContainsKey('explorer'))

Write-Host ''
Write-Host '-- 3. LO QUE NO SE SABE NO SE INVENTA --'
$antes = [int]$u[$dia]['msedge']['con'] + [int]$u[$dia]['msedge']['sin']
Add-UsoAlly 'msedge' 30 -1        # Get-InactividadMin no ha podido medirlo
Save-UsoAlly $hoy
$u = Get-UsoAlly
$ahora = [int]$u[$dia]['msedge']['con'] + [int]$u[$dia]['msedge']['sin']
Comp 'con la medicion fallida (-1) no se apunta nada' ($ahora -eq $antes) "antes $antes, ahora $ahora"

Write-Host ''
Write-Host '-- 4. LAS GUARDAS DE SIEMPRE --'
$antes2 = [int]$u[$dia]['msedge']['con']
Add-UsoAlly 'msedge' 600 1        # un hueco de 10 min: la consola durmio
Save-UsoAlly $hoy
$u = Get-UsoAlly
Comp 'un tramo de mas de 120 s no es tiempo de uso' ([int]$u[$dia]['msedge']['con'] -eq $antes2) "con=$($u[$dia]['msedge']['con'])"
$script:invitado = $true
Add-UsoAlly 'valorant' 60 1
Save-UsoAlly $hoy
$script:invitado = $false
$u = Get-UsoAlly
Comp 'con un invitado delante no se apunta nada' (-not $u[$dia].ContainsKey('valorant')) ($u[$dia].Keys -join ',')

Write-Host ''
Write-Host '-- 5. NO CRECE PARA SIEMPRE --'
# EL SAVE VA DENTRO DEL BUCLE A PROPOSITO (27/09): Add-UsoAlly se guarda ella sola cuando lo
# pendiente pasa de 300 s, y ahi llama a Save-UsoAlly SIN dia, o sea con Get-Date, el dia de
# verdad. Con las apps sumando 1, 2, 3... segundos ese disparo salta en la app 24 y de las 52 solo
# dos acababan en el dia de la prueba: el tope de 40 se comprobaba sobre 5 apps y no tocaba nada
# (manera 17), y "la de un segundo ya no" salia verde porque app1 estaba en OTRO dia, no por la
# poda. Guardando cada vuelta lo pendiente nunca llega a 300 y las 52 caen en el dia que se mira.
for ($i = 1; $i -le ($UsoAllyMax + 12); $i++) { Add-UsoAlly ("app$i") $i 1; Save-UsoAlly $hoy }
$u = Get-UsoAlly
Comp "no guarda mas de $UsoAllyMax apps en un dia" ($u[$dia].Count -eq $UsoAllyMax) "$($u[$dia].Count) apps, con $($UsoAllyMax + 15) metidas"
# y las que caen son las de MENOS tiempo, que son las que no dicen nada
Comp 'y la que mas tiempo tiene sigue estando' ($u[$dia].ContainsKey("app$($UsoAllyMax + 12)")) ''
Comp 'y la de un segundo ya no' (-not $u[$dia].ContainsKey('app1')) ''
# los dias viejos se van
$viejo = $hoy.AddDays(-($UsoAllyDias + 5))
$script:usoAlly[(Get-DiaJuego $viejo)] = @{ 'algo' = @{ con = 10; sin = 0 } }
Add-UsoAlly 'ELDEN RING' 10 1
Save-UsoAlly $hoy
Comp "los dias de hace mas de $UsoAllyDias se podan" (-not (Get-UsoAlly).ContainsKey((Get-DiaJuego $viejo))) ''

Write-Host ''
Write-Host '-- 6. SOBREVIVE AL DISCO --'
$script:usoAlly = $null          # como si Nova se reiniciara
$u2 = Get-UsoAlly
Comp 'se relee del fichero' ($u2.ContainsKey($dia)) ''
Comp 'y con las dos cuentas dentro' ([int]$u2[$dia]['ELDEN RING']['sin'] -eq 60) "sin=$($u2[$dia]['ELDEN RING']['sin'])"

Write-Host ''
Write-Host '-- 7. Y EL BUCLE LO LLAMA DE VERDAD --'
# Un cuaderno que nadie escribe es peor que no tenerlo: sale verde y no aprende nada.
# EL BLOQUE SE RECORTA POR SUS MARCAS, no por distancia. Una expresion que pida "esto y aquello
# a menos de tantos caracteres" es de las que este proyecto llama fragiles: ata la comprobacion
# a lo CERCA que estan dos lineas hoy, y se cae sola en cuanto alguien mete un comentario en
# medio. La escribi asi y el trinquete de probar-bancos-fragiles la canto en el acto. (Y ni
# siquiera se puede citar el patron aqui: ese banco cuenta las coincidencias en TODO el fichero,
# comentarios incluidos, asi que escribirlo de ejemplo ya sumaba una.)
$iniB = $fuente.IndexOf('# EL CUADERNO DE LA ALLY, en la misma mirada')
$finB = if ($iniB -ge 0) { $fuente.IndexOf('$script:usoAllyVisto = $sw.ElapsedMilliseconds', $iniB) } else { -1 }
if ($iniB -lt 0 -or $finB -lt 0) { Write-Host '  MAL  no encuentro el enganche del bucle'; exit 1 }
$bloqueB = $fuente.Substring($iniB, $finB - $iniB)
Comp 'el bucle de los 10 s apunta el uso' ($bloqueB.Contains('Add-UsoAlly $appU')) 'donde ya se paga la consulta cara'
Comp 'y le pasa la inactividad, no un si a secas' ($bloqueB.Contains('(Get-InactividadMin)')) ''
Comp 'y apunta lo que hay delante aunque NO sea un juego' ($bloqueB.Contains('Get-ProcesoEnPrimerPlano')) ''

} finally { Remove-Item -LiteralPath $tmpU -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'Nova apunta lo que se hace con la Ally, y sabe si habia alguien'
exit 0
