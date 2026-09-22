# Prueba la cadena completa de "apunta esto": imagen -> OCR -> nota en el
# diario, con las funciones SACADAS DEL ARCHIVO REAL. En vez de capturar la
# pantalla (que traeria lo que haya ahora), se genera una imagen con un codigo
# como los que salen en los juegos, que es el caso de uso.
# POR DONDE ESTE EL BANCO, NO POR UNA RUTA ESCRITA A MANO (22/09). Aqui habia
# 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1' a fuego: en una copia del repo en
# otra carpeta este banco seguiria midiendo el assistant.ps1 de SIEMPRE, y si alguien
# renombrara la carpeta se caeria entero sin que el fallo tuviera nada que ver con el OCR.
# Y SIN Stop NO SE ENTERA NADIE: este banco imprimia cuatro etapas y solo comprobaba una,
# asi que una excepcion por el camino se veia en pantalla y acababa en verde igual.
$ErrorActionPreference = 'Stop'
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
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
# ESTA ETAPA ERA MUDA (22/09): se imprimia la nota y no se miraba. Si Add-Memoria
# devolviera vacio, escribiera en otro sitio o se dejara el texto por el camino, el banco
# acababa en verde igual, porque el unico veredicto de abajo mira los digitos del OCR.
$contenido = if ($nota -and (Test-Path -LiteralPath $nota)) { Get-Content -Raw -LiteralPath $nota } else { '' }
if (-not $contenido) { Write-Host "MAL: Add-Memoria no dejo ninguna nota"; exit 1 }
if ($contenido -notmatch '328|3 2 8') { Write-Host "MAL: la nota no tiene el codigo leido"; exit 1 }
if ($contenido -notmatch [regex]::Escape($donde)) { Write-Host "MAL: la nota no dice de que juego salio"; exit 1 }

Write-Host "--- y si luego preguntas por el codigo ---"
Invoke-Expression (TraerFn 'ConvertTo-Plain')
# REGLA DEL BANCO: Find-EnMemoria llama a Get-Distancia por dentro y aqui no se traia.
# Hoy pasaba de milagro -con este texto entra por la coincidencia exacta y no llega a
# usarla-, pero en cuanto una palabra cambiase moriria con CommandNotFoundException... y
# el banco seguiria en verde, porque nadie miraba el resultado. Las dos mitades del fallo
# quedan tapadas: se trae la funcion, y abajo se comprueba lo que devuelve.
Invoke-Expression (TraerFn 'Get-Distancia')
Invoke-Expression (TraerFn 'Find-EnMemoria')
$MemoriaDir = $env:TEMP
$PALABRAS_VACIAS = @('que','sabes','sobre','de','del','la','el','los','las','un','una','anote','apunte','cual','es','era')
$r = Find-EnMemoria 'que codigo anote'
Write-Host "   Find-EnMemoria('que codigo anote') -> $r"
# Y ESTA TAMBIEN ERA MUDA. Es la etapa que de verdad le importa a braya: apuntar el codigo
# no sirve de nada si luego no lo encuentra al preguntarlo.
if (-not $r) { Write-Host "MAL: apunto el codigo pero no lo encuentra al preguntarlo"; exit 1 }
if ($r -notmatch '328|3 2 8') { Write-Host "MAL: lo que devuelve no trae el codigo: '$r'"; exit 1 }
# y que no conteste a cualquier cosa: una pregunta de algo que no anoto no puede devolver
# esta nota, que seria justo una respuesta equivocada
$rNo = Find-EnMemoria 'que me dijo el medico sobre las pastillas'
if ($rNo -match '328') { Write-Host "MAL: devuelve el codigo a una pregunta que no tiene nada que ver: '$rNo'"; exit 1 }
Write-Host "   y a una pregunta de otra cosa no le saca el codigo: correcto"

Remove-Item $png -Force -ErrorAction SilentlyContinue
Remove-Item $DiarioDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
# se comparan los digitos sin espacios: el OCR conserva la separacion que tenga
# la imagen, y en la prueba el codigo esta escrito "3 2 8"
$digitos = ($texto -replace '[^0-9]', '')
if ($digitos -match '328') { Write-Host "el OCR leyo el codigo (digitos: $digitos): correcto" }
else { Write-Host "MAL: el OCR no leyo el codigo (digitos: '$digitos')"; exit 1 }
