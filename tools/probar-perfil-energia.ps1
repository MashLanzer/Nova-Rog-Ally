# EL PERFIL DE ENERGIA POR JUEGO (30/09, la 5 de las 20 funciones nuevas)
#
# LO QUE SE MIDIO ANTES DE PROMETERLO: en esta consola no hay WMI de ASUS accesible (ASUSWMI,
# AsusAtkWmi, ATKWMI: ninguna responde) y el TDP en vatios lo lleva Armoury Crate. Pero la consola
# expone sus perfiles como PLANES DE ENERGIA de Windows -Turbo, PD Turbo, Performance, Equilibrado-
# y powercfg los cambia. Asi que no se tocan vatios: se cambia el perfil por donde la consola deja.
#
# ESTE BANCO DOBLA powercfg. Cambiar de verdad el perfil de la consola de braya por correr la
# bateria seria inaceptable: se queda en Turbo o donde este, y el banco no lo toca.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-energia-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $MemoriaDir = $tmp
    $PlanesPath = Join-Path $tmp 'planes-juego.json'
    foreach ($n in @('ConvertTo-Plain', 'Write-Atomico', 'Get-PlanesEnergia', 'Get-PlanEnergiaActual',
                     'Set-PlanEnergia', 'Get-PlanesJuego', 'Save-PlanJuego', 'Set-PlanDeEseJuego')) {
        Invoke-Expression (Traer $n)
    }
    $script:dichos = @()
    function Log([string]$m) { $script:dichos += $m }

    # EL powercfg DE PEGA: imita la salida de la Ally de braya, con Turbo activo.
    $script:activo = 'Turbo'
    $script:vecesSet = 0
    function powercfg {
        if ($args -contains '/list') {
            $out = @('', 'Combinaciones de energia existentes (* activas)', '-----')
            foreach ($p in @(@('27fa6203-3987-4dcc-918d-748559d549ec', 'Performance'),
                             @('381b4222-f694-41f0-9685-ff5bb260df2e', 'Equilibrado'),
                             @('62346f4c-22a8-45c0-adf0-24a1cb9f2739', 'PD Turbo'),
                             @('6fecc5ae-f350-48a5-b669-b472cb895ccf', 'Turbo'))) {
                $l = 'GUID de plan de energia: ' + $p[0] + '  (' + $p[1] + ')'
                if ($p[1] -eq $script:activo) { $l += ' *' }
                $out += $l
            }
            return $out
        }
        if ($args -contains '/setactive') {
            $script:vecesSet++
            $g = $args[-1]
            switch ($g) {
                '27fa6203-3987-4dcc-918d-748559d549ec' { $script:activo = 'Performance' }
                '381b4222-f694-41f0-9685-ff5bb260df2e' { $script:activo = 'Equilibrado' }
                '62346f4c-22a8-45c0-adf0-24a1cb9f2739' { $script:activo = 'PD Turbo' }
                '6fecc5ae-f350-48a5-b669-b472cb895ccf' { $script:activo = 'Turbo' }
            }
            return @()
        }
        return @()
    }

    Write-Host ''
    Write-Host '-- 1. lee los perfiles de la consola y cual esta puesto --'
    $ps = @(Get-PlanesEnergia)
    Comp 'encuentra los cuatro perfiles' ($ps.Count -eq 4) "$($ps.Count)"
    Comp 'y sabe cual esta activo' ((Get-PlanEnergiaActual) -eq 'Turbo') "$(Get-PlanEnergiaActual)"

    Write-Host ''
    Write-Host '-- 2. cambiarlo, y comprobar que cambio de verdad --'
    $r = Set-PlanEnergia 'equilibrado'
    Comp 'cambia al que se le pide' ($r.ok -and (Get-PlanEnergiaActual) -eq 'Equilibrado') "$($r.texto)"
    # 'PD Turbo' ANTES QUE 'Turbo': si se busca el mas corto primero, "pon pd turbo" se queda en
    # Turbo y braya no se entera de que le puso otro perfil.
    $r2 = Set-PlanEnergia 'pd turbo'
    Comp 'y "pd turbo" no se queda en Turbo' ($r2.ok -and (Get-PlanEnergiaActual) -eq 'PD Turbo') "$(Get-PlanEnergiaActual)"
    # SI YA ESTABA, NO SE TOCA NADA
    $antes = $script:vecesSet
    $r3 = Set-PlanEnergia 'pd turbo'
    Comp 'si ya estaba puesto, no lo vuelve a poner' ($script:vecesSet -eq $antes) "$($r3.texto)"

    Write-Host ''
    Write-Host '-- 3. lo que no existe, y lo que no cambia --'
    $r4 = Set-PlanEnergia 'hiperturbo galactico'
    Comp 'un perfil que no existe se dice' (-not $r4.ok) "$($r4.texto)"
    Comp '  y nombra los que SI hay' ($r4.texto -match 'Turbo' -and $r4.texto -match 'Equilibrado') 'si no, braya no sabe que pedir'
    # Y SI powercfg NO HACE NADA, NO SE PRESUME EL CAMBIO: es la regla 1.
    function powercfg { if ($args -contains '/list') { return @('GUID de plan de energia: 11111111-1111-1111-1111-111111111111  (Turbo) *') } return @() }
    $r5 = Set-PlanEnergia 'performance'
    Comp 'si no cambia de verdad, lo dice' (-not $r5.ok) "$($r5.texto)"

    Write-Host ''
    Write-Host '-- 4. se aprende del uso: el perfil de ESE juego --'
    Save-PlanJuego 'Juego De Pega' 'PD Turbo'
    $h = Get-PlanesJuego
    Comp 'se queda el perfil del juego' ($h['juegodepega'] -eq 'PD Turbo') "$($h.Count) juego(s) apuntado(s)"
    Comp '  y lo dice en el log' (@($script:dichos | Where-Object { $_ -match 'me quedo con PD Turbo' }).Count -ge 1) ''
    # Y NO SE REESCRIBE SI NO CAMBIA (regla 4)
    $script:dichos = @()
    Save-PlanJuego 'Juego De Pega' 'PD Turbo'
    Comp '  y no reescribe lo que ya estaba' (@($script:dichos).Count -eq 0) 'nada que apuntar si no cambia'

    Write-Host ''
    Write-Host '-- 5. al entrar en el juego se le pone SU perfil --'
    $script:activo = 'Equilibrado'
    function powercfg {
        if ($args -contains '/list') {
            $o = @()
            foreach ($p in @(@('aaaaaaaa-1111-1111-1111-111111111111', 'Equilibrado'), @('bbbbbbbb-2222-2222-2222-222222222222', 'PD Turbo'))) {
                $l = 'GUID de plan de energia: ' + $p[0] + '  (' + $p[1] + ')'
                if ($p[1] -eq $script:activo) { $l += ' *' }
                $o += $l
            }
            return $o
        }
        if ($args -contains '/setactive') { if ($args[-1] -like 'bbbb*') { $script:activo = 'PD Turbo' } else { $script:activo = 'Equilibrado' } }
        return @()
    }
    $puesto = Set-PlanDeEseJuego 'Juego De Pega'
    Comp 'pone el perfil aprendido de ese juego' ($puesto -eq 'PD Turbo' -and $script:activo -eq 'PD Turbo') "$puesto"
    # Y UN JUEGO SIN PERFIL APRENDIDO NO TOCA NADA: Nova no decide sola a cuantos vatios se juega.
    $script:activo = 'Equilibrado'
    $puesto2 = Set-PlanDeEseJuego 'Otro Juego Sin Perfil'
    Comp 'y un juego sin perfil no cambia nada' ((-not $puesto2) -and $script:activo -eq 'Equilibrado') 'eso es gusto de braya, no de Nova'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 6. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca perfilEnergia' ($sinCom -match "kind = 'perfilEnergia'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'perfilEnergia' \{") ''
Comp '  y Enter-Juego pone el perfil del juego' ($sinCom -match 'Set-PlanDeEseJuego \$nombre') ''
# NO PISA LOS MODOS DE LA CASA: 'modo ahorro' y los demas son otra cosa y ya estaban aprendidos.
Comp 'sigue existiendo el modo ahorro de siempre' ($sinCom -match 'modo ahorro') 'perfil y modo son cosas distintas'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova pone el perfil de energia de cada juego, y lo aprende de lo que le pides' -ForegroundColor Green
exit 0
