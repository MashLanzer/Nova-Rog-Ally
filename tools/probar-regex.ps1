# Comprueba que TODOS los patrones del asistente compilan como expresion regular.
#
# Por que existe: el 11/09 se colo '(?i)steamapps\common\([^\]+)' con barras
# simples. .NET ni siquiera podia compilarlo ("conjunto [] sin terminar"), pero
# la llamada estaba dentro de un try/catch por proceso, asi que la deteccion de
# juegos colgados devolvia lista vacia SIEMPRE y en silencio. Un regex roto no
# da la cara: se limita a no encontrar nunca nada.
#
#   powershell -File tools\probar-regex.ps1
param([string[]]$Archivos = @('assistant.ps1'))

$operadores = @('-match', '-notmatch', '-imatch', '-cmatch', '-split', '-replace', '-ireplace', '-creplace')
$fallos = 0
$vistos = 0

foreach ($archivo in $Archivos) {
    if (-not (Test-Path -LiteralPath $archivo)) { Write-Host "no existe: $archivo"; continue }
    $err = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath $archivo), [ref]$err)
    for ($i = 0; $i -lt $tokens.Count - 1; $i++) {
        $t = $tokens[$i]
        if ($t.Type -ne 'Operator' -and $t.Type -ne 'CommandArgument') { continue }
        if ($operadores -notcontains $t.Content.ToLowerInvariant()) { continue }
        $sig = $tokens[$i + 1]
        if ($sig.Type -ne 'String') { continue }
        # solo literales COMPLETOS: si el patron sigue con '+', es un trozo de
        # una concatenacion ('^cuando...' + $VERBOS + '...') y por si solo no
        # tiene por que compilar.
        $patron = $sig.Content
        if ($patron -match '\$') { continue }
        if ($i + 2 -lt $tokens.Count) {
            $post = $tokens[$i + 2]
            if ($post.Type -eq 'Operator' -and $post.Content -eq '+') { continue }
        }
        $vistos++
        # CARACTERES DE CONTROL. Un patron puede compilar perfectamente y aun
        # asi estar roto: si un '' escrito en otro lenguaje se colo como
        # BACKSPACE (0x08), el regex busca un backspace literal y no coincide
        # nunca. Paso el 11/09 en siete lineas a la vez -entre ellas el filtro
        # que se comia "dale a enter" y el limite de palabra de los titulos de
        # juego- y ninguna comprobacion lo veia, porque todas compilaban.
        # tabulador, CR y LF son legitimos: hay patrones que parten por lineas
        $control = ($patron.ToCharArray() | Where-Object { [int]$_ -lt 32 -and [int]$_ -notin @(9, 10, 13) })
        if ($control) {
            $fallos++
            $codigos = ($control | ForEach-Object { '0x{0:X2}' -f [int]$_ }) -join ' '
            Write-Host ("  CONTROL {0}:{1}  caracteres invisibles ({2}) en el patron" -f $archivo, $sig.StartLine, $codigos) -ForegroundColor Red
            Write-Host ("          probablemente un escape mal traducido; suele ser un ")
            continue
        }
        try {
            [void][regex]::new($patron)
        } catch {
            $fallos++
            Write-Host ("  ROTO  {0}:{1}  {2}" -f $archivo, $sig.StartLine, $patron) -ForegroundColor Red
            Write-Host ("        {0}" -f $_.Exception.Message.Trim())
        }
    }
}

Write-Host ""
if ($fallos -eq 0) {
    Write-Host "$vistos patrones comprobados, todos compilan."
    exit 0
}
Write-Host "$vistos patrones comprobados, $fallos ROTOS."
exit 1
