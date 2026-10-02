# TRES PEQUENAS DE LA TANDA DE CUARENTA (2/10/2026): ideas 28, 35 y 39
#
# IDEA 28 - DELETREAR. `grep -ci deletrea assistant.ps1` daba CERO, y es de lo mas pedido a un
# asistente. Nova ya tenia las tres piezas -voz, capsula y OCR- sin juntarlas nunca. Va sobre todo a
# la CAPSULA, que es lo que importa: oir "e-l-e-n-e" letra a letra es dificil de seguir y verlo
# escrito se entiende de un golpe.
#
# IDEA 35 - "YA TE LO PREGUNTE Y DIJISTE QUE NO". El patron existia solo para dos casos concretos
# ('musica-no.json', de 2 bytes, y 'juegos-fuera.json'); todo lo demas que Nova pregunta se volvia a
# preguntar desde cero. Y preguntar lo que ya te dijeron que no es la forma mas rapida de que alguien
# apague un asistente. Un solo fichero y una sola funcion, para que la siguiente pregunta que se le
# ocurra a cualquiera ya nazca con memoria.
#
# IDEA 39 - LA CAPSULA DICE LO QUE ESTA HACIENDO. Medido en el arranque del 2/10: desde
# "VoiceAssistant iniciado" hasta "escucha continua ACTIVA" pasan DIECINUEVE SEGUNDOS -dieciseis la
# biblioteca de Steam- y luego Whisper tarda 2,1 s y Parakeet 4,5. En todo ese rato la capsula no
# decia nada, asi que desde fuera no habia forma de saber si Nova arrancaba o se habia colgado.
# Cero funciones nuevas: tres llamadas a Set-UI, que ya pinta texto.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`r?`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

$tmp = Join-Path $env:TEMP ("tres-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$MemoriaDir = $tmp
$NoQuieroDias = 90
$script:noQuiero = $null
$script:invitado = $false
function Write-Atomico([string]$ruta, [string]$texto, [bool]$bom = $false) {
    [IO.File]::WriteAllText($ruta, $texto, (New-Object System.Text.UTF8Encoding($false)))
}
function Get-Cfg($a, $b, $c) { return $c }
foreach ($n in @('Get-Deletreo', 'Get-NoQuieroPath', 'Get-NoQuiero', 'Add-NoQuiero', 'Test-YaDijoNo')) {
    Invoke-Expression (Traer $n)
}

try {
    Write-Host ''
    Write-Host '-- 28. deletrear --'
    Comp 'una palabra normal' ((Get-Deletreo 'elden') -eq 'E - L - D - E - N') "$(Get-Deletreo 'elden')"
    # LOS ESPACIOS SE DICEN: si no, "mi casa" y "micasa" suenan igual deletreados
    Comp 'los espacios se dicen' ((Get-Deletreo 'mi casa') -match 'espacio') "$(Get-Deletreo 'mi casa')"
    # LA ENIE Y LAS TILDES, CON NOMBRE: una "n" por una enie deja a braya escribiendo mal la palabra,
    # que es justo lo que esto viene a evitar.
    $enieMin = [char]0xF1
    Comp 'la enie se dice con nombre' ((Get-Deletreo ('ma' + $enieMin + 'ana')) -match 'ene con tilde') "$(Get-Deletreo ('ma'+$enie+'ana'))"
    # Y LA MAYUSCULA SE DISTINGUE DE LA MINUSCULA. Una tabla hash de PowerShell es INSENSIBLE a
    # mayusculas: con @{} las dos enies colapsaban en una clave y ganaba la ultima escrita. Comprobado
    # al probarlo la primera vez: la minuscula devolvia "ENE con tilde" en mayusculas.
    # OJO: 'enieMin' y 'enieMay', no 'enie' y 'ENIE': en PowerShell esos dos son LA MISMA
    # variable, la mayuscula pisaba a la minuscula y la comprobacion de abajo mirada la otra enie.
    $enieMay = [char]0xD1
    Comp '  y la mayuscula no se confunde con la minuscula' ((Get-Deletreo ('ma' + $enieMin + 'ana')) -cmatch 'ene con tilde') 'tabla ordinal, no @{}'
    Comp '  la mayuscula, en mayusculas' ((Get-Deletreo ([string]$enieMay + 'ANDU')) -cmatch 'ENE con tilde') "$(Get-Deletreo ([string]$enieMay+'ANDU'))"
    $eTilde = [char]0xE9
    Comp 'las vocales con tilde tambien' ((Get-Deletreo ('caf' + $eTilde)) -match 'e con tilde') "$(Get-Deletreo ('caf'+$eTilde))"
    Comp 'sin nada que deletrear, lo dice' ((Get-Deletreo '') -match 'No me has dicho') ''
    # Y NO SE DELETREA UN PARRAFO: con cuarenta caracteres ya es ilegible en la capsula
    $largo = Get-Deletreo ('a' * 80)
    Comp 'se corta a 40 letras' (@($largo -split ' - ').Count -le 40) "$(@($largo -split ' - ').Count) letras"
    # EL CABLEADO
    Comp 'hay patron para pedirlo' ($sinCom -match "kind = 'deletrea'") ''
    $iE = $sinCom.IndexOf("'deletrea' {")
    $iF = $sinCom.IndexOf('Get-Deletreo', [Math]::Max(0, $iE))
    Comp '  y su ejecutor llama a la funcion' ($iE -ge 0 -and $iF -gt $iE) ''
    Comp '  y lo pinta en la capsula' ($sinCom -match "Set-UI 'hablando' \(\[string\]\`$a\.que") 'verlo escrito se entiende de un golpe'

    Write-Host ''
    Write-Host '-- 35. ya te lo pregunte y dijiste que no --'
    Comp 'sin fichero, no hay ningun no' (-not (Test-YaDijoNo 'dormida-recordatorios')) ''
    Add-NoQuiero 'dormida-recordatorios'
    $script:noQuiero = $null
    Comp 'se guarda y se lee del disco en frio' (Test-YaDijoNo 'dormida-recordatorios') ''
    Comp '  y otro tema sigue libre' (-not (Test-YaDijoNo 'otra-cosa')) ''
    # CADUCA: un "no" de hace tres meses puede no ser el de hoy
    $script:noQuiero = @{ 'viejo' = (Get-Date).AddDays(-89).ToString('yyyy-MM-dd') }
    Comp 'a los 89 dias sigue valiendo' (Test-YaDijoNo 'viejo') ''
    $script:noQuiero = @{ 'viejo' = (Get-Date).AddDays(-90).ToString('yyyy-MM-dd') }
    Comp "  y a los $NoQuieroDias ya no" (-not (Test-YaDijoNo 'viejo')) 'se puede volver a ofrecer'
    # UNA FECHA FUTURA NO DEJA EL "NO" PUESTO PARA SIEMPRE (si el reloj de la consola salta)
    $script:noQuiero = @{ 'futuro' = (Get-Date).AddDays(5).ToString('yyyy-MM-dd') }
    Comp 'una fecha futura no vale' (-not (Test-YaDijoNo 'futuro')) 'si el reloj salta'
    # BASURA EN EL FICHERO: no rompe nada
    $script:noQuiero = @{ 'raro' = 'manana por la tarde' }
    Comp 'una fecha que no es fecha, tampoco' (-not (Test-YaDijoNo 'raro')) ''
    # EL MODO INVITADO NO DECIDE EL FUTURO DE BRAYA
    $script:noQuiero = @{}
    $script:invitado = $true
    Add-NoQuiero 'con-visita'
    $script:invitado = $false
    Comp 'el no de una visita no cuenta' (-not (Test-YaDijoNo 'con-visita')) 'aqui se decide SU futuro'
    # Y CON EL PLAZO A 0 SE APAGA
    $script:noQuiero = @{ 'x' = (Get-Date).ToString('yyyy-MM-dd') }
    $guardado = $NoQuieroDias; $NoQuieroDias = 0
    Comp 'con el plazo a 0 se apaga' (-not (Test-YaDijoNo 'x')) 'desactivable sin tocar codigo'
    $NoQuieroDias = $guardado
    # EL CABLEADO: la promesa de la frase se cumple
    $iFd = $sinCom.IndexOf('$fd2 = Get-FuncionDormida')
    $iNo = $sinCom.IndexOf('Test-YaDijoNo', [Math]::Max(0, $iFd))
    Comp 'el aviso de funcion dormida lo consulta' ($iFd -ge 0 -and $iNo -gt $iFd) 'su frase promete no insistir'

    Write-Host ''
    Write-Host '-- 39. la capsula dice lo que esta haciendo --'
    # LA LLAMADA DEL ARRANQUE, NO LA DEFINICION: IndexOf('Initialize-Voz') encontraba
    # 'function Initialize-Voz' veinte mil lineas antes, y los tres indices salian del sitio
    # equivocado. La llamada esta sola en su linea, sin 'function' delante.
    $iVoz = $sinCom.IndexOf("`nInitialize-Voz")
    $iEsc = $sinCom.IndexOf("`nInitialize-Escucha", [Math]::Max(0, $iVoz))
    $antesVoz = $sinCom.LastIndexOf("Set-UI 'pensando' 'preparando la voz", [Math]::Max(0, $iVoz))
    Comp 'avisa antes de preparar la voz' ($antesVoz -ge 0 -and $antesVoz -lt $iVoz) ''
    $entre = if ($iVoz -ge 0 -and $iEsc -gt $iVoz) { $sinCom.Substring($iVoz, $iEsc - $iVoz) } else { '' }
    Comp '  y antes de cargar el oido' ($entre -match "Set-UI 'pensando' 'cargando el oido") 'los 2,1 s de Whisper y 4,5 de Parakeet'
    $despues = if ($iEsc -ge 0) { $sinCom.Substring($iEsc, [Math]::Min(400, $sinCom.Length - $iEsc)) } else { '' }
    Comp '  y al acabar vuelve a reposo' ($despues -match "Set-UI 'reposo'") 'no se queda "pensando" para siempre'
    # EN TRY: si la capsula no esta, el arranque no se para (regla 7)
    Comp 'y en try, que el arranque no depende de que mires' ($sinCom -match "try \{ Set-UI 'pensando' 'cargando el oido[^}]+\} catch \{\}") 'regla 7'

    Write-Host ''
    if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
    Write-Host 'deletrea, se acuerda de un no, y dice lo que esta haciendo al arrancar' -ForegroundColor Green
    exit 0
}
finally {
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
