# EL "HAS VUELTO" GUARDABA LOS MINUTOS CUANDO LO QUE QUISO GUARDAR ERA EL RITMO
# (27/09, idea 104 de las 121)
#
# LOS 45 MINUTOS SE ELIGIERON para que saliera "poco mas de un saludo al dia". Lo que hay que
# guardar es ese "uno al dia", no los 45: los huecos de braya cambian y sobre todo Nova se reinicia
# mucho, y un reinicio se come el saludo -el hueco tiene que tenerla viva de punta a punta-.
#
# MEDIDO sobre los dos registros (2.028 interacciones en 18 dias y 258 arranques, 14,3 al dia),
# contando solo los huecos con Nova viva de punta a punta:
#     15 min -> 1,78 saludos/dia      45 min -> 0,83   (el de hoy)
#     20 min -> 1,44                  60 min -> 0,61
#     30 min -> 0,94                  90 min -> 0,39
# Con el objetivo de ~1 al dia el que mas se acerca es TREINTA. Y para la voz, con su propio ritmo
# pedido (0,3 al dia): 120 min da 0,28 y los 180 de hoy dan 0,22, asi que el mas cercano es 120.
# (La ficha decia 0,31 saludos/dia con 45 minutos; medido con 18 dias sale 0,83: el problema es real
# pero bastante menor de lo que decia.)
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que se elija EL MAS CERCANO al ritmo pedido, no el mas grande que llegue
#   2. que un hueco con un reinicio en medio NO cuente (es el nucleo de la idea)
#   3. que con pocos dias no se decida nada
#   4. que no baje nunca del suelo
#   5. que se pueda deshacer hablando, y que entonces no se vuelva a poner
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
foreach ($f in @('Get-VueltaMinMedido', 'Update-VueltaMin')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# las listas y los ritmos, del archivo
$VueltaUmbrales = @(15, 20, 30, 45, 60, 90)
$VueltaVozUmbrales = @(60, 90, 120, 180, 240, 360)
$VueltaDiasMin = 5
$VueltaAlDia = 1.0
$VueltaVozAlDia = 0.3
Comp 'los umbrales salen del archivo' ($txt -match '\$VueltaUmbrales = @\(15, 20, 30, 45, 60, 90\)') ''
Comp '  los de la voz tambien' ($txt -match '\$VueltaVozUmbrales = @\(60, 90, 120, 180, 240, 360\)') ''
Comp '  el ritmo pedido es config, no codigo' ($txt -match "Get-Cfg 'entorno' 'vueltaAlDia' 1\.0") 'braya puede cambiarlo sin tocar el fichero'
Comp '  y la voz tiene el suyo, mas bajo' ($txt -match "Get-Cfg 'entorno' 'vueltaVozAlDia' 0\.3") 'la voz interrumpe; la capsula solo se ve'
Comp '  y hacen falta 5 dias' ($txt -match '\$VueltaDiasMin = 5') ''

Write-Host ''
Write-Host '-- 1. EL MAS CERCANO AL RITMO PEDIDO, no el mas grande que llegue --'
# los huecos REALES medidos, con Nova viva: 18 dias
$reales = @{ 15 = 32; 20 = 26; 30 = 17; 45 = 15; 60 = 11; 90 = 7 }
$r = Get-VueltaMinMedido $reales 18 1.0 5 15
Comp '1a. con sus huecos de verdad, 30 minutos' ($r -eq 30) ([string]$r + ' min; 17/18 = 0,94 al dia, y el pedido es 1,0')
Comp '1b. y NO 20, que es el mas grande que llega' ($r -ne 20) '26/18 = 1,44: se pasa por 0,44 en vez de por 0,06'
Comp '1c. ni 45, el de hoy' ($r -ne 45) '15/18 = 0,83'
# y con la voz
$realesV = @{ 60 = 11; 90 = 7; 120 = 5; 180 = 4; 240 = 4; 360 = 3 }
$rv = Get-VueltaMinMedido $realesV 18 0.3 5 60
Comp '1d. y para la voz, 120' ($rv -eq 120) ([string]$rv + ' min; 5/18 = 0,28 y el pedido es 0,3')

Write-Host ''
Write-Host '-- 2. CON POCOS DIAS NO SE DECIDE NADA --'
Comp '2a. con 4 dias, cero (no cambiar)' ((Get-VueltaMinMedido $reales 4 1.0 5 15) -eq 0) 'un solo fin de semana no es una costumbre'
Comp '2b. con 5 ya si' ((Get-VueltaMinMedido $reales 5 1.0 5 15) -gt 0) ''
Comp '2c. sin huecos, el mas grande (el que menos molesta)' ((Get-VueltaMinMedido @{ 15 = 0; 30 = 0; 90 = 0 } 18 1.0 5 15) -eq 90) 'todos empatados a 0: gana el que menos interrumpe'
Comp '2d. y con un ritmo pedido de cero, nada' ((Get-VueltaMinMedido $reales 18 0 5 15) -eq 0) ''

Write-Host ''
Write-Host '-- 3. EL SUELO NO SE CRUZA --'
# si braya hiciera huecos cortisimos todo el rato, 15 seria el que mas se acerca... y es el suelo
$cortos = @{ 15 = 18; 20 = 10; 30 = 5; 45 = 2; 60 = 1; 90 = 0 }
Comp '3a. el suelo de la capsula son 15' ((Get-VueltaMinMedido $cortos 18 1.0 5 15) -ge 15) ([string](Get-VueltaMinMedido $cortos 18 1.0 5 15) + ' min')
# y con el suelo de la voz, los de abajo ni se miran
$rv2 = Get-VueltaMinMedido $realesV 18 5.0 5 60
Comp '3b. y el de la voz son 60' ($rv2 -ge 60) ([string]$rv2 + ' min; pidiendo 5 al dia, el mas cercano seria el mas bajo')
Comp '3c. un umbral por debajo del suelo no entra' ((Get-VueltaMinMedido @{ 5 = 100; 60 = 11 } 18 0.3 5 60) -eq 60) 'ni aunque se acerque mas'

Write-Host ''
Write-Host '-- 4. UN HUECO CON UN REINICIO EN MEDIO NO CUENTA (el nucleo de la idea) --'
$cuerpo = Traer 'Update-VueltaMin'
Comp '4a. los arranques se leen del registro' ($cuerpo -match "VoiceAssistant iniciado.{0,60}naces\.Add") ''
Comp '4b. y un hueco roto se salta' ($cuerpo -match '\$roto = \(\$iN -lt \$naces\.Count -and \$naces\[\$iN\] -lt \$b\)') ''
Comp '4c. sin volver atras en la lista' ($cuerpo -match 'while \(\$iN -lt \$naces\.Count -and \$naces\[\$iN\] -le \$a\) \{ \$iN\+\+ \}') '258 arranques x 2.028 huecos serian medio millon de comparaciones'
Comp '4d. y la actividad usa la MISMA lista que la siembra' ($cuerpo -match '\$linea -match \$RE_SEED_ACTIVIDAD') 'una sola idea de que es una interaccion'

Write-Host ''
Write-Host '-- 5. UNA VEZ AL DIA, NO EN CADA ARRANQUE --'
Comp '5a. el dia se guarda en config.json' ($cuerpo -match "Get-Cfg 'entorno' 'vueltaMedidoDia' ''") '811 ms medidos x 14,3 arranques al dia son once segundos tirados'
Comp '5b. y se marca aunque no cambie nada' ($cuerpo -match "(?s)Set-Cfg 'entorno' 'vueltaMedidoDia' \`$hoyV.{0,300}\`$cambio\.Count -eq 0") 'lo que cuesta es leer, y eso se paga igual'
Comp '5c. la fecha se calcula FUERA del try' ($cuerpo -match "(?s)\`$hoyV = \(Get-Date\)\.ToString\('yyyy-MM-dd'\)\s*\r?\n\s*try \{") 'si el try se cayera, el dia se marcaria vacio'
Comp '5d. y solo una vez por sesion' ($cuerpo -match '\$script:vueltaMedido = \$true') ''
Comp '5e. y va en el arranque, no en el bucle' ($sinCom -match '\[void\]\(Update-VueltaMin\)') ''

Write-Host ''
Write-Host '-- 6. SE PUEDE DESHACER HABLANDO --'
Comp '6a. se apunta como decision propia' ($cuerpo -match "Save-DecisionPropia 'entorno' 'vueltaMin'") 'asi "deshaz eso" sabe a que volver'
Comp '6b. con el valor de ANTES' ($cuerpo -match "Save-DecisionPropia 'entorno' 'vueltaMin' \(\[string\]\`$VueltaMin\)") 'apuntado antes de cambiarlo'
Comp '6c. y la de la voz tambien' ($cuerpo -match "Save-DecisionPropia 'entorno' 'vueltaVozMin'") ''
Comp '6d. y si lo devolvio, no se vuelve a poner' ($cuerpo -match "Test-DecisionDevuelta 'entorno' 'vueltaMin'") 'sin esto, "deshaz eso" duraria hasta manana'
Comp '6e. diciendolo' ($cuerpo -match 'me lo devolviste hace poco') ''
Comp '6f. y queda en las estadisticas como auto-ajuste' ($cuerpo -match "Add-Estadistica 'auto-ajuste'") 'para que salga en el parrafo semanal'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el saludo de vuelta guarda el ritmo pedido, no los minutos' -ForegroundColor Green
exit 0
