# Prueba la cadena completa de "apunta esto": imagen -> OCR -> nota en el
# diario, con las funciones SACADAS DEL ARCHIVO REAL. En vez de capturar la
# pantalla (que traeria lo que haya ahora), se genera una imagen con un codigo
# como los que salen en los juegos, que es el caso de uso.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn([string]$n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta $n" }
    return $f.Extent.Text
}
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Invoke-Expression (TraerFn 'Await-WinRT')
Invoke-Expression (TraerFn 'Invoke-OCR')
Invoke-Expression (TraerFn 'Add-Memoria')

# diario de mentira, para no escribir en las notas de verdad
$DiarioDir = Join-Path $env:TEMP 'diario-prueba-ocr'
if (Test-Path $DiarioDir) { Remove-Item $DiarioDir -Recurse -Force }

# --- imagen con un codigo, como el de una caja fuerte ---
$png = Join-Path $env:TEMP 'ocr-prueba.png'
$bmp = New-Object System.Drawing.Bitmap(760, 200)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Black)
$fuente = New-Object System.Drawing.Font('Segoe UI', 34, [System.Drawing.FontStyle]::Bold)
$blanco = [System.Drawing.Brushes]::White
$g.DrawString('CODIGO DE LA CAJA: 3 2 8', $fuente, $blanco, 20, 20)
$g.DrawString('puerta del sotano', $fuente, $blanco, 20, 100)
$g.Dispose(); $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

Write-Host "--- OCR sobre la imagen ---"
$texto = Invoke-OCR $png
Write-Host "   leido: '$texto'"

Write-Host "--- lo que guardaria en la nota ---"
$limpio = (($texto -replace '[\r\n]+', ' / ') -replace '\s{2,}', ' ').Trim()
$donde = 'SILENT BREATH'   # como si estuvieras jugando
$nota = Add-Memoria ("(de $donde) " + $limpio)
Get-Content -Raw -LiteralPath $nota | ForEach-Object { "   " + ($_ -replace "`r`n", "`n   ") }

Write-Host "--- y si luego preguntas por el codigo ---"
Invoke-Expression (TraerFn 'ConvertTo-Plain')
Invoke-Expression (TraerFn 'Find-EnMemoria')
$MemoriaDir = $env:TEMP
$PALABRAS_VACIAS = @('que','sabes','sobre','de','del','la','el','los','las','un','una','anote','apunte','cual','es','era')
$r = Find-EnMemoria 'que codigo anote'
Write-Host "   Find-EnMemoria('que codigo anote') -> $r"

Remove-Item $png -Force -ErrorAction SilentlyContinue
Remove-Item $DiarioDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
# se comparan los digitos sin espacios: el OCR conserva la separacion que tenga
# la imagen, y en la prueba el codigo esta escrito "3 2 8"
$digitos = ($texto -replace '[^0-9]', '')
if ($digitos -match '328') { Write-Host "el OCR leyo el codigo (digitos: $digitos): correcto" }
else { Write-Host "MAL: el OCR no leyo el codigo (digitos: '$digitos')"; exit 1 }
