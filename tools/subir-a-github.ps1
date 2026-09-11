# Sube el proyecto a GitHub desde una consola REAL.
#
# Por que existe este script: la terminal del asistente no tiene consola
# (no existe /dev/tty) y ademas hereda GIT_TERMINAL_PROMPT=0, asi que Git no
# puede pedir credenciales por ningun medio. Aqui se fuerzan las peticiones
# activadas y se ejecuta en una ventana de verdad, donde si puedes responder.

$ErrorActionPreference = 'Continue'

# LO IMPORTANTE: reactivar las peticiones, que vienen desactivadas por herencia
$env:GIT_TERMINAL_PROMPT = '1'
Remove-Item Env:\GCM_INTERACTIVE -ErrorAction SilentlyContinue

Set-Location 'C:\Users\braya\Documents\voice-ctrl'
$git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'

Write-Host ''
Write-Host '=== Subiendo Nova-Rog-Ally a GitHub ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Si te pide usuario y contrasena:' -ForegroundColor Yellow
Write-Host '   usuario    -> MashLanzer' -ForegroundColor Yellow
Write-Host '   contrasena -> un TOKEN personal, no tu clave de GitHub' -ForegroundColor Yellow
Write-Host '   (GitHub → Settings → Developer settings → Personal access' -ForegroundColor DarkYellow
Write-Host '    tokens → Tokens classic → permiso repo)' -ForegroundColor DarkYellow
Write-Host ''
Write-Host 'Tambien puede abrirse una ventana de inicio de sesion. Completala.' -ForegroundColor Yellow
Write-Host ''

& $git push -u origin main
$codigo = $LASTEXITCODE

Write-Host ''
if ($codigo -eq 0) {
    Write-Host 'LISTO: el proyecto se subio correctamente.' -ForegroundColor Green
} else {
    Write-Host "FALLO. Codigo de salida: $codigo" -ForegroundColor Red
    Write-Host 'Copia el mensaje de arriba y pasaselo al asistente.' -ForegroundColor Red
}
Write-Host ''
Write-Host 'Puedes cerrar esta ventana.' -ForegroundColor Gray
