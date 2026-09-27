# LO QUE LE FALTA PARA PODER DECIDIR (27/09, idea 75 de las 121)
#
# EL AGUJERO: Nova evalua cinco decisiones propias cada dia y, cuando alguna no llega al liston, sale
# EN SILENCIO. Get-AvisoSinDatos ya avisa de UNA de las formas de no llegar -que los datos esten
# amontonados en un solo dia- pero se calla justo en la que las frena a las cinco hoy: que FALTEN
# INTENTOS. En los 14 dias de estadisticas.json hay CERO 'auto-ajuste', CERO 'auto-deshecho' y la
# lista 'decisiones' esta vacia, con NUEVE sitios del codigo que escribirian 'auto-ajuste'.
# Simulado con sus datos: al oido fino le faltan 34 repasos (56 de los 90 que pide
# Test-DecisionSolida con 7 aciertos netos), y a canary y base 15 cada uno.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que lo APAGADO no se anuncie (seria prometer una decision ya tomada)
#   2. que lo que YA APORTA no se cuente como frenado
#   3. que se hable de UNA sola decision, no de las tres (eso es una queja, no una noticia)
#   4. que el contador se escriba SIEMPRE aunque no se hable, que es lo que hoy no se podia contar
#   5. que se hable como mucho una vez por semana y nunca en nivel 'alto'
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('Get-DecisionMinimo', 'Get-QueMeFalta', 'Set-AvisoQueMeFalta')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$DecisionMinIntentos = 20
$DecisionPorAcierto = 10
$DecisionAprovecha = 0.15
$AvisoFaltaSemanaMin = 10080
Comp 'los numeros de la decision salen del archivo' (($txt -match '\$DecisionMinIntentos = 20') -and ($txt -match '\$DecisionPorAcierto = 10')) ''
Comp 'y se habla una vez por semana' ($txt -match '\$AvisoFaltaSemanaMin = 10080') ''

# los dobles, DESPUES de cargar
$script:avisos = @()
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    $script:avisos += @(@{ clave = $clave; texto = $texto; nivel = $nivel; cada = $cadaMin }); return $true
}
$script:apuntados = @()
function Add-Estadistica([string]$ruta, [string]$detalle = '', [bool]$deCamino = $false) {
    $script:apuntados += @(@{ ruta = $ruta; detalle = $detalle })
}
function Num([hashtable]$h) {
    $n = @{}
    foreach ($k in @('turbo', 'turbo-sirvio', 'nube-intento', 'nube-sirvio', 'nube-invento', 'fino', 'fino-sirvio', 'fino-invento')) { $n[$k] = 0 }
    foreach ($k in $h.Keys) { $n[$k] = $h[$k] }
    return $n
}
function Reset { $script:avisos = @(); $script:apuntados = @() }

Write-Host ''
Write-Host '-- 1. LO APAGADO NO SE ANUNCIA --'
$WhisperUltimo = ''; $NubeOir = $false; $WhisperPreciso = ''
Reset
$f1 = @(Get-QueMeFalta (Num @{ 'fino' = 5 }))
Comp '1a. con las tres apagadas, no falta nada que contar' ($f1.Count -eq 0) ([string]$f1.Count)
Comp '1b. y no se apunta ni se habla' ((Set-AvisoQueMeFalta (Num @{ 'fino' = 5 })) -eq $false -and @($script:apuntados).Count -eq 0) ''

Write-Host ''
Write-Host '-- 2. EL CASO DE VERDAD: al oido fino le faltan 34 repasos --'
$WhisperPreciso = 'small'
Reset
# sus datos simulados: 56 repasos, 9 sirvieron, 2 inventos -> neto 7 -> pide 20 + 10*7 = 90
$num2 = Num @{ 'fino' = 56; 'fino-sirvio' = 9; 'fino-invento' = 2 }
$f2 = @(Get-QueMeFalta $num2)
Comp '2a. sale una sola decision frenada' ($f2.Count -eq 1) ([string]$f2.Count)
Comp '2b. y le faltan 34' ($f2[0].falta -eq 34) ([string]$f2[0].falta + ' (56 de 90)')
Comp '2c. cuenta el acierto NETO, no el bruto' ($f2[0].pide -eq 90) ([string]$f2[0].pide + ' = 20 + 10 x 7')
$r2 = Set-AvisoQueMeFalta $num2
Comp '2d. lo dice' ($r2 -and @($script:avisos).Count -eq 1) (@($script:avisos | ForEach-Object { $_.texto }) -join ' | ')
Comp '2e. con el numero dentro de la frase' (@($script:avisos)[0].texto -match '34 repasos') (@($script:avisos)[0].texto)
Comp '2f. en nivel medio, nunca alto' (@($script:avisos)[0].nivel -eq 'medio') 'el alto es para lo urgente'
Comp '2g. y con plazo de una semana' (@($script:avisos)[0].cada -eq 10080) ''
Comp '2h. y el contador queda apuntado' (@($script:apuntados | Where-Object { $_.ruta -eq 'auto-frenado:fino:pocos-datos' }).Count -eq 1) (@($script:apuntados)[0].detalle)

Write-Host ''
Write-Host '-- 3. LO QUE YA APORTA NO ESTA FRENADO --'
Reset
# 56 repasos y 30 utiles: por encima del 15 % de aprovecho, asi que no hay decision pendiente
$f3 = @(Get-QueMeFalta (Num @{ 'fino' = 56; 'fino-sirvio' = 30 }))
Comp '3a. no sale como frenada' ($f3.Count -eq 0) 'si aporta, no hay nada que decidir'
Comp '3b. y no se apunta nada' (@($script:apuntados).Count -eq 0) ''

Write-Host ''
Write-Host '-- 4. SE HABLA DE UNA SOLA, LA MAS CERCA --'
$WhisperUltimo = 'turbo'; $NubeOir = $true
Reset
$num4 = Num @{ 'fino' = 56; 'fino-sirvio' = 9; 'fino-invento' = 2;   # le faltan 34
               'turbo' = 18; 'turbo-sirvio' = 0;                      # le faltan 2
               'nube-intento' = 5; 'nube-sirvio' = 0 }                # le faltan 15
$f4 = @(Get-QueMeFalta $num4)
Comp '4a. las tres estan frenadas' ($f4.Count -eq 3) ([string]$f4.Count)
$null = Set-AvisoQueMeFalta $num4
Comp '4b. pero solo se habla de una' (@($script:avisos).Count -eq 1) ([string]@($script:avisos).Count + ' avisos')
Comp '4c. y es la que menos le falta' (@($script:avisos)[0].clave -eq 'auto-falta:turbo') (@($script:avisos)[0].texto)
Comp '4d. mientras el contador apunta las TRES' (@($script:apuntados).Count -eq 3) ([string]@($script:apuntados).Count + ' contadores')

Write-Host ''
Write-Host '-- 5. SIN DATOS DE NADA, EL MINIMO ES EL MINIMO --'
Reset
$f5 = @(Get-QueMeFalta (Num @{}))
Comp '5a. con cero intentos, faltan los 20 de entrada' (@($f5 | Where-Object { $_.falta -eq 20 }).Count -eq $f5.Count) (@($f5 | ForEach-Object { $_.clave + ':' + $_.falta }) -join ' ')

Write-Host ''
Write-Host '-- 6. EL CABLEADO --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '6a. se engancha en Set-AvisoSinDatos, por donde sale toda decision frenada' ($sinCom -match 'try \{ \[void\]\(Set-AvisoQueMeFalta \$num \$ahora\) \} catch \{\}') ''
Comp '6b. y NO se tocan las condiciones de Test-RevisionPropia' (-not ((Traer 'Test-RevisionPropia') -match 'Set-AvisoQueMeFalta')) 'ahi solo se lee lo ya calculado'
Comp '6c. va antes del aviso de reparto, que habla de otra cosa' ($sinCom -match '(?s)Set-AvisoQueMeFalta \$num \$ahora.{0,200}Get-AvisoSinDatos \$stats') ''

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova dice que le falta para poder decidir' -ForegroundColor Green
exit 0
