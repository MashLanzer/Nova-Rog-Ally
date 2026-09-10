param([string]$promptFile, [string]$outFile, [string]$workDir, [string]$cli, [string]$useSep)
$ErrorActionPreference = "Stop"
$env:PATH = "C:\Program Files\nodejs;" + $env:PATH
$text = ""
if (Test-Path $promptFile) { $text = Get-Content -LiteralPath $promptFile -Raw }
try {
    if ($useSep -eq "yes") {
        $out = & $cli run --auto --dir $workDir -- $text 2>&1 | Out-String
    } else {
        $out = & $cli run --auto --dir $workDir $text 2>&1 | Out-String
    }
    Set-Content -LiteralPath $outFile -Value $out -Encoding utf8
} catch {
    Set-Content -LiteralPath $outFile -Value ("RUNNER-ERR: " + $_.Exception.Message) -Encoding utf8
}