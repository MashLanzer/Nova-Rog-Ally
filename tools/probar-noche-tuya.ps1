# LA NOCHE ES LA TUYA, NO LAS ONCE (25/09, idea 8)
#
# LO MEDIDO: el silencio nocturno estaba fijo de 23 a 8 ($EntornoNocheDesde / $EntornoNocheHasta)
# mientras en el MISMO archivo existe Get-HoraFinHabitual, que saca de los habitos de braya a
# que hora suele apagar de verdad y se usa para otra decision. Dos criterios para la misma
# pregunta, y el que calla a Nova era el de a fuego.
#
# POR QUE IMPORTA: braya juega de noche. Anoche hablaba con Nova a las 2 de la madrugada. Un
# silencio que empieza a las 23 le calla tres horas UTILES, y ademas hace que Nova parezca rota
# justo cuando mas la usa.
#
# LO QUE SE HACE: la hora a la que empieza el silencio sale de sus habitos cuando hay datos
# suficientes (Get-HoraFinHabitual pide 4 dias y devuelve -1 si no llega). Sin datos, el numero
# de config de siempre. Asi el primer dia funciona igual que antes y a la semana es suyo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. la noche sale de sus habitos --'
Comp 'existe Get-NocheDesde' ($sinCom -match 'function Get-NocheDesde') ''
# EL BLOQUE, NO UNA DISTANCIA (25/09, idea 2): esto era un "que esten a menos de 600
# caracteres", y esa clase de expresion se pone roja el dia que alguien mete un comentario en
# medio. Se saca la funcion entera del arbol, que no depende de cuanto ocupe nada.
$dN = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-NocheDesde' }, $true)
Comp 'y usa la funcion que YA existia' ($dN -and $dN.Extent.Text -match 'Get-HoraFinHabitual') 'no un criterio nuevo'
Comp 'el numero de config sigue como respaldo' ($sinCom -match '\$EntornoNocheDesde = \[int\]\(Get-Cfg') 'el primer dia funciona igual que antes'
$usos = @([regex]::Matches($sinCom, '(?<!function )Get-NocheDesde')).Count
Comp 'y se usa al decidir si es de noche' ($usos -ge 1) "$usos uso(s)"

Write-Host ''
Write-Host '-- 2. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-NocheDesde' }, $true)
if (-not $d) {
    Comp 'se saca Get-NocheDesde del arbol' $false ''
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
Invoke-Expression $d.Extent.Text
function Log([string]$m) { }
# los dobles, DESPUES de cargar (manera 9)
$script:finHabitual = -1
function Get-HoraFinHabitual { return $script:finHabitual }
$EntornoNocheDesde = 23

# SIN DATOS: el de siempre
$script:finHabitual = -1
Comp 'sin habitos, el numero de config' ((Get-NocheDesde) -eq 23) 'Get-HoraFinHabitual devuelve -1 con menos de 4 dias'

# APAGA A LA UNA DE LA MADRUGADA: 25 h en minutos = 1500
$script:finHabitual = 1500
Comp 'si apaga a la 1, la noche empieza a la 1' ((Get-NocheDesde) -eq 1) 'no a las 23'

# APAGA A LAS 2: 26 h = 1560
$script:finHabitual = 1560
Comp 'si apaga a las 2, a las 2' ((Get-NocheDesde) -eq 2) 'el caso real de braya'

# APAGA PRONTO, A LAS 22: 22 h = 1320
$script:finHabitual = 1320
Comp 'y si apaga pronto, tambien' ((Get-NocheDesde) -eq 22) 'se calla antes, no despues'

# UN VALOR ABSURDO NO PASA
# UN VALOR ABSURDO CAE AL RESPALDO, no a una hora inventada (25/09). Con el modulo 24, 99999
# minutos dan "las 10": una hora perfectamente valida y perfectamente falsa. Por eso se valida
# lo que ENTRA, no solo lo que sale.
$script:finHabitual = 99999
Comp 'un valor absurdo cae al de config' ((Get-NocheDesde) -eq 23) 'no a una hora inventada'
$script:finHabitual = 1740   # 29 h, el maximo que puede devolver de verdad
Comp 'y el maximo real si vale' ((Get-NocheDesde) -eq 5) '29 h son las 5 de la madrugada'

Write-Host ''
Write-Host '-- 3. EN MINUTOS: la noche empieza donde acaba TU hora, no en la hora en punto (idea 39) --'
# los dobles que faltan para las funciones nuevas. Get-Cfg devuelve el defecto, asi que
# margenDormirMin = 30 (el valor vivo, que no esta en config.json).
$EntornoNocheHasta = 8
function Get-Cfg([string]$s, [string]$k, $d) { return $d }
Comp 'las dos constantes de la noche estan puestas' ($EntornoNocheHasta -eq 8 -and $EntornoNocheDesde -eq 23) 'sin ellas, [int]$null*60 = 0 y la ventana se da la vuelta'
$dIni = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-InicioNocheMin' }, $true)
$dNoc = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-EsNocheAviso' }, $true)
Comp 'existen Get-InicioNocheMin y Test-EsNocheAviso' ($dIni -and $dNoc) ''
Invoke-Expression $dIni.Extent.Text
Invoke-Expression $dNoc.Extent.Text
# IDEA 86 (27/09): el fin del silencio ya no es el 8 escrito, sale de Get-NocheHasta -el final de
# la franja muerta medida-. Aqui se le da un doble que devuelve el 8 de siempre: lo que este banco
# prueba es el INICIO de la noche, no de donde sale el final, que tiene el suyo
# (probar-franja-muerta.ps1). Sin esto moria con 'Get-NocheHasta no se reconoce'.
function Get-NocheHasta([datetime]$ahora = (Get-Date)) { return [int]$EntornoNocheHasta }

# 1. el corazon: 00:24 + 30 de margen = 00:54, no las 00:00 del truncado
$script:finHabitual = 1464
Comp 'apaga a las 00:24 -> el silencio empieza a las 00:54' ((Get-InicioNocheMin) -eq 54) 'truncar daria 0; sin margen, 24'
# 2. el modulo 1440: pasada la medianoche no se dispara al dia siguiente
$script:finHabitual = 1500
Comp 'apaga a la 01:00 -> 01:30' ((Get-InicioNocheMin) -eq 90) 'sin % 1440 daria 1530'
$script:finHabitual = 1320
Comp 'apaga a las 22:00 -> 22:30' ((Get-InicioNocheMin) -eq 1350) ''
# 3. y 4. el respaldo con *60, y la validacion de entrada
$script:finHabitual = -1
Comp 'sin datos, el respaldo es 23:00 EN MINUTOS (1380)' ((Get-InicioNocheMin) -eq 1380) 'return 0 o return 23 (sin *60) romperia esto'
$script:finHabitual = 99999
Comp 'un valor absurdo cae al respaldo, no a una hora inventada' ((Get-InicioNocheMin) -eq 1380) '99999 % 1440 daria las 10:39'

# 5. el conductual, con fin = 1464 (inicio 00:54): lo que de verdad recupera 95 ordenes
$script:finHabitual = 1464
Comp 'a las 00:30 YA NO es de noche (aviso recuperado)' (-not (Test-EsNocheAviso ([datetime]'2026-09-27 00:30'))) 'antes del cambio era silencio'
Comp '  ni a las 00:53' (-not (Test-EsNocheAviso ([datetime]'2026-09-27 00:53'))) ''
Comp '  pero a las 00:54 si, en el borde exacto' (Test-EsNocheAviso ([datetime]'2026-09-27 00:54')) ''
Comp '  y a las 01:10 tambien' (Test-EsNocheAviso ([datetime]'2026-09-27 01:10')) ''
Comp '  a las 07:59 sigue siendo noche' (Test-EsNocheAviso ([datetime]'2026-09-27 07:59')) ''
Comp '  y a las 08:00 la manana (no se movio)' (-not (Test-EsNocheAviso ([datetime]'2026-09-27 08:00'))) ''
# 6. la madrugada que envuelve, con fin = 1358 (22:38 -> inicio 23:08)
$script:finHabitual = 1358
Comp 'apaga a las 22:38 -> silencio desde las 23:08' ((Get-InicioNocheMin) -eq 1388) ''
Comp '  a las 23:20 es de noche (rama envolvente)' (Test-EsNocheAviso ([datetime]'2026-09-27 23:20')) 'sin la rama -gt, hablaria toda la noche'
Comp '  y a las 22:50 todavia no' (-not (Test-EsNocheAviso ([datetime]'2026-09-27 22:50'))) ''
# 7. el degenerado: el margen no puede empujar el inicio por delante de la hora de levantarse
$script:finHabitual = 470
Comp 'apaga a las 07:50 -> el silencio NO da la vuelta al reloj' (-not (Test-EsNocheAviso ([datetime]'2026-09-27 12:00'))) 'sin la guarda, silencio de 08:20 a 08:00: casi 24 h'

# 8. EL ENGANCHE, sobre el texto real de Test-PuedoAvisar: que la llame y ya no compare horas
$dP = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-PuedoAvisar' }, $true)
$txtP = if ($dP) { $dP.Extent.Text } else { '' }
Comp 'Test-PuedoAvisar llama a Test-EsNocheAviso' ($txtP -match 'Test-EsNocheAviso') 'escribir las funciones y no engancharlas dejaria esto verde'
Comp '  y ya no trunca con (Get-Date).Hour' ($txtP -notmatch '\(Get-Date\)\.Hour') 'esa era la comparacion vieja, en horas'
# Y Get-NocheDesde NO se toca: sigue devolviendo horas para su otro cliente (Test-VueltaSaludo)
Comp 'Get-NocheDesde sigue devolviendo horas (su otro cliente)' ($dN.Extent.Text -match 'Floor\(\$m / 60\) % 24') 'Test-VueltaSaludo compara con .Hour'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  la noche es la tuya'
exit 0
