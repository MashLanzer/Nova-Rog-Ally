# Compila nova_ui.cs -> nova_ui.exe con el csc del .NET Framework 4.x.
# Las referencias a WPF van con ruta completa porque csc no las resuelve por
# nombre corto (no estan en el directorio del compilador).
$raiz = Split-Path -Parent $PSScriptRoot
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$gac = "$env:WINDIR\Microsoft.NET\assembly"
$refs = @(
    "$gac\GAC_MSIL\PresentationFramework\v4.0_4.0.0.0__31bf3856ad364e35\PresentationFramework.dll",
    "$gac\GAC_64\PresentationCore\v4.0_4.0.0.0__31bf3856ad364e35\PresentationCore.dll",
    "$gac\GAC_MSIL\WindowsBase\v4.0_4.0.0.0__31bf3856ad364e35\WindowsBase.dll",
    "$gac\GAC_MSIL\System.Xaml\v4.0_4.0.0.0__b77a5c561934e089\System.Xaml.dll"
)
# System.Drawing no se lista: csc ya la incluye por defecto y duplicarla da CS1703
$faltan = $refs | Where-Object { -not (Test-Path $_) }
if ($faltan) { Write-Host "No encuentro:"; $faltan | ForEach-Object { Write-Host "  $_" }; exit 1 }
$argumentos = @("/nologo", "/target:winexe", "/optimize+", "/out:$raiz\nova_ui.exe") + ($refs | ForEach-Object { "/reference:$_" }) + "$raiz\nova_ui.cs"
& $csc $argumentos
if ($LASTEXITCODE -eq 0) { Write-Host "OK -> $raiz\nova_ui.exe" }
exit $LASTEXITCODE
