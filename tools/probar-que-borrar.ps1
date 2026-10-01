# QUE BORRAR PARA HACER SITIO (30/09, la 2 de las 20 funciones nuevas)
#
# EL DATO QUE LA PIDE: 27 GB libres de 476 y 320,3 GB en veinte juegos, con Black Myth: Wukong
# ocupando 139,57 GB el solo. Nova sabia decir cuanto queda; no sabia QUE quitar.
#
# TODO CON JUEGOS DE PEGA, NUNCA CON LOS DE BRAYA: un banco que nombre un juego suyo se pone rojo
# el dia que lo desinstala (es la manera 5 de salir verde mintiendo, y ya mordio dos veces con
# 'elden ring' escrito a mano). Aqui se montan $script:Juegos y los tiempos a mano.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
$LogDir = $Raiz
foreach ($n in @('ConvertTo-Plain', 'Get-EspacioPorJuego', 'Get-FraseQueBorrar')) { Invoke-Expression (Traer $n) }
function Log([string]$m) { }

$hoy = Get-Date
function Dia([int]$atras) { return $hoy.AddDays(-1 * $atras).ToString('yyyy-MM-dd') }

# los juegos de pega: uno enorme pero recien jugado, uno grande y olvidado, y uno pequeno
$script:Juegos = @(
    @{ appid = '1'; nombre = 'Juegazo Enorme';  bytes = 140GB },
    @{ appid = '2'; nombre = 'Juego Olvidado';  bytes = 30GB },
    @{ appid = '3'; nombre = 'Juego Pequeno';   bytes = 2GB },
    @{ appid = '4'; nombre = 'Sin Tamano';      bytes = 0 }
)
# Y LOS TIEMPOS, armados como JSON Y LEIDOS COMO JSON, que es exactamente lo que hace la funcion de
# verdad con memoria\juegos.json. Montarlos con [pscustomobject]@{ (Dia 2) = ... } no vale: en un
# literal de tabla hash la clave entre parentesis no se evalua como se espera y salen claves con el
# texto de la llamada. Pasaba en la primera version de este banco y dejaba los cuatro casos mudos.
# El apostrofe tipografico U+2019 va a proposito: es el de "Marvel's" en los manifiestos de Steam.
$apos = [char]0x2019
$memJson = @"
{
  "Juegazo Enorme": { "dias": { "$(Dia 2)": 3600 } },
  "Juego Olvidado": { "dias": { "$(Dia 40)": 1800 } },
  "Marvel${apos}s Spider-Man": { "dias": { "$(Dia 3)": 900 } },
  "Fecha Rota": { "dias": { "no-es-una-fecha": 10 } }
}
"@
$memFalsa = $memJson | ConvertFrom-Json
function Get-JuegosMem { return $memFalsa }

Write-Host ''
Write-Host '-- 1. la lista: ordenada por tamano, con los dias sin jugar --'
$l = @(Get-EspacioPorJuego)
Comp 'solo entran los que tienen tamano' ($l.Count -eq 3) "$($l.Count) de 4 (el de 0 bytes no cuenta)"
Comp 'y van de mayor a menor' ($l[0].nombre -eq 'Juegazo Enorme' -and $l[2].nombre -eq 'Juego Pequeno') "$($l[0].nombre) primero"
Comp 'el recien jugado trae sus dias' ($l[0].dias -eq 2) "$($l[0].dias) dias"
Comp 'el olvidado tambien' (($l | Where-Object { $_.nombre -eq 'Juego Olvidado' }).dias -eq 40) ''
Comp 'y el que no esta apuntado sale como desconocido' (($l | Where-Object { $_.nombre -eq 'Juego Pequeno' }).dias -lt 0) 'menos que cero = no lo se'

Write-Host ''
Write-Host '-- 2. el candidato NO es el mas gordo si lo estas jugando --'
# Esto es de lo que va la funcion: recomendar borrar lo que juegas esta semana no es recomendar.
$fr = Get-FraseQueBorrar
Comp 'recomienda el grande que no tocas' ($fr -match 'Juego Olvidado') "$fr"
Comp '  y NO el que jugaste hace dos dias' ($fr -notmatch 'sobra es Juegazo Enorme') ''
# Y SE DICE POR QUE, que es el dato que decide: si el mayor se queda fuera, hay que saberlo.
Comp '  pero dice cual es el mas gordo y por que no' (($fr -match 'mas gordo es Juegazo Enorme') -and ($fr -match 'hace 2 dias')) ''
Comp '  y dice cuanto queda en el disco' ($fr -match 'Te quedan') ''

Write-Host ''
Write-Host '-- 3. por un juego concreto --'
Comp 'dice los gigas que libera' ((Get-FraseQueBorrar 'Juego Olvidado') -match '30 gigas') ''
Comp '  y cuanto lleva sin abrirse' ((Get-FraseQueBorrar 'Juego Olvidado') -match '40 dias') ''
Comp 'un juego que no esta no se inventa' ((Get-FraseQueBorrar 'Juego Que No Existe 99') -match 'No encuentro') ''

Write-Host ''
Write-Host '-- 4. los dos fallos que cazo la primera prueba --'
# UNO: el apostrofe tipografico. El manifiesto de Steam trae "Marvel's Spider-Man" con U+2019 y el
# fichero de tiempos lo guardo de otra forma: dos textos del mismo juego que no casaban, asi que
# Nova decia "no tengo apuntado que lo hayas jugado" de algo que esta en su propio fichero.
$script:Juegos = @(@{ appid = '5'; nombre = "Marvel$([char]0x2019)s Spider-Man"; bytes = 66GB })
$l2 = @(Get-EspacioPorJuego)
Comp 'un nombre con apostrofe cruza con sus tiempos' ($l2[0].dias -eq 3) "$($l2[0].dias) dias (antes: sin apuntar)"
# DOS: una clave que no es una fecha daba "hace 739889 dias" (el ano 1).
$script:Juegos = @(@{ appid = '6'; nombre = 'Fecha Rota'; bytes = 5GB })
$l3 = @(Get-EspacioPorJuego)
Comp 'una fecha que no es fecha no inventa dias' ($l3[0].dias -lt 0) "$($l3[0].dias) (antes: 739889)"

Write-Host ''
Write-Host '-- 5. el cableado: la orden existe y llega --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca queBorrar' ($sinCom -match "kind = 'queBorrar'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'queBorrar' \{") ''
Comp '  y llama a la frase' ($sinCom -match 'Get-FraseQueBorrar') ''
# EL TAMANO SALE DEL MANIFIESTO Y NO DE MEDIR CARPETAS: medir 320 GB por una pregunta hablada
# seria barrer el disco entero. SizeOnDisk ya lo trae contado.
Comp 'el tamano sale de SizeOnDisk, no de medir el disco' ($txt -match 'SizeOnDisk') 'barrer 320 GB por una pregunta seria absurdo'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova dice que borrar para hacer sitio, y no te manda borrar lo que juegas' -ForegroundColor Green
exit 0
