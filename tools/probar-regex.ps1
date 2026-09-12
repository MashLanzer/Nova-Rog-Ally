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
