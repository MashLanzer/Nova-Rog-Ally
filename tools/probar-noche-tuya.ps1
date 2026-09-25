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
Comp 'y usa la funcion que YA existia' ($sinCom -match 'Get-NocheDesde[\s\S]{0,600}Get-HoraFinHabitual') 'no un criterio nuevo'
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
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  la noche es la tuya'
exit 0
