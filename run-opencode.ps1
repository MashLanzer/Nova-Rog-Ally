param(
    [Parameter(Mandatory = $true)][string]$promptFile,
    [Parameter(Mandatory = $true)][string]$outFile,
    [Parameter(Mandatory = $true)][string]$workDir,
    [Parameter(Mandatory = $true)][string]$cli
)

# IMPORTANTE: NO poner $ErrorActionPreference = "Stop" aqui.
# En PS 5.1, redirigir stderr de un .exe nativo (2>&1) envuelve cada linea en un
# ErrorRecord (NativeCommandError); con "Stop" eso mata el script ANTES de escribir
# $outFile y el asistente reporta "(sin salida de opencode)".
$ErrorActionPreference = "Continue"

# Comillado segun las reglas de CommandLineToArgvW: duplica las barras que
# preceden a una comilla, escapa la comilla y duplica las barras finales.
function ConvertTo-CmdArg([string]$s) {
    if ($null -eq $s) { $s = "" }
    $s = [regex]::Replace($s, '(\\*)"', '$1$1\"')
    $s = [regex]::Replace($s, '(\\+)$', '$1$1')
    return '"' + $s + '"'
}

$errFile = [System.IO.Path]::ChangeExtension($outFile, ".err.txt")
$exitCode = -1
$stdout = ""
$stderr = ""

try {
    $env:PATH = "C:\Program Files\nodejs;" + $env:PATH

    $text = ""
    if (Test-Path -LiteralPath $promptFile) {
        $text = [System.IO.File]::ReadAllText($promptFile, [System.Text.Encoding]::UTF8)
    }
    # el dictado puede traer saltos de linea; en argv se colapsan a espacios
    $text = ($text -replace '\s+', ' ').Trim()

    if ($text.Length -eq 0) {
        $stderr = "prompt vacio: $promptFile"
    }
    else {
        # stdin vacio => EOF inmediato (evita que el CLI se quede esperando input
        # cuando se lanza sin consola interactiva)
        $inFile = [System.IO.Path]::ChangeExtension($outFile, ".in.txt")
        [System.IO.File]::WriteAllText($inFile, "")

        $rawOut = [System.IO.Path]::ChangeExtension($outFile, ".raw.txt")

        # El `--` es OBLIGATORIO por seguridad: sin el, un texto dictado que
        # empiece por guion ("menos i" -> -i) lo parsea yargs como flag.
        # Verificado: con `--` responde bien; sin `--` sale exit=1 en 2s.
        $argLine = "run --auto --dir " + (ConvertTo-CmdArg $workDir) + " -- " + (ConvertTo-CmdArg $text)

        $p = Start-Process -FilePath $cli -ArgumentList $argLine `
            -WorkingDirectory $workDir -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $rawOut -RedirectStandardError $errFile `
            -RedirectStandardInput $inFile
        # tocar .Handle cachea el handle del proceso; sin esto .ExitCode
        # devuelve $null tras salir (quirk de Start-Process -PassThru)
        $null = $p.Handle
        $p.WaitForExit()
        $exitCode = $p.ExitCode

        if (Test-Path -LiteralPath $rawOut) {
            $stdout = [System.IO.File]::ReadAllText($rawOut, [System.Text.Encoding]::UTF8)
            Remove-Item -LiteralPath $rawOut -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $errFile) {
            $stderr = [System.IO.File]::ReadAllText($errFile, [System.Text.Encoding]::UTF8)
        }
        Remove-Item -LiteralPath $inFile -Force -ErrorAction SilentlyContinue
    }
}
catch {
    $stderr = $stderr + "`r`nrunner error: " + $_.Exception.Message
}
finally {
    # PASE LO QUE PASE se escribe $outFile: si falta, el asistente no sabe por que fallo.
    $body = $stdout
    if ($body.Trim().Length -eq 0) {
        $body = "(opencode no produjo stdout; exit=$exitCode)`r`n" + $stderr
    }
    try {
        [System.IO.File]::WriteAllText($outFile, $body, (New-Object System.Text.UTF8Encoding($false)))
    }
    catch {}
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
}

exit $exitCode
