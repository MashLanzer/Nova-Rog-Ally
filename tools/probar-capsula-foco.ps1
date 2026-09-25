# LA CAPSULA NO PUEDE ROBAR EL FOCO (24/09)
#
# LO QUE PASO, y lo conto braya jugando: al reiniciar Nova a las 23:33 con A Way Out abierto,
# el juego se quedo sin audio Y la capsula dejo de verse encima. Dos sintomas, una sola causa:
# medido con GetForegroundWindow, la ventana de delante era nova_ui, no el juego. Un juego que
# pierde el foco se silencia (lo hacen casi todos) y al recuperarlo vuelve a ponerse delante,
# tapando la capsula.
#
# POR QUE NO PASABA ANTES: Nova suele estar arrancada ANTES de abrir el juego, y entonces no
# hay foco que robar. El codigo no habia cambiado -nova_ui.cs es del 22/09 19:38 y el exe del
# 22/09 20:56, comprobado-. Lo que cambio fue el orden.
#
# EL FALLO DE VERDAD estaba en CUANDO se ponen los estilos: WS_EX_NOACTIVATE se aplicaba en
# Loaded, que corre DESPUES de que la ventana ya se ha pintado. Para entonces el foco ya se
# habia robado. Ahora se aplica tambien en SourceInitialized -el hwnd ya existe, la ventana
# todavia no se ve- y, sobre todo, ShowActivated = false, que es la propiedad de WPF hecha
# justo para esto.
#
# LA COMPROBACION QUE MAS VALE ES LA 2: que el .exe que corre se haya compilado DESPUES del
# .cs. Un arreglo que esta en el codigo pero no en el binario no arregla nada, y aqui el
# binario va versionado en el repositorio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$CS  = Join-Path $Raiz 'nova_ui.cs'
$EXE = Join-Path $Raiz 'nova_ui.exe'
$mal = 0
$saltadas = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  ($detalle)" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  ($detalle)" })); $script:mal++ }
}

Write-Host '-- 1. la ventana no se activa nunca --'
$txt = [IO.File]::ReadAllText($CS)
# los comentarios fuera: si no, un comentario que nombre ShowActivated dejaria pasar la rotura
$codigo = ($txt -split "`n" | Where-Object { $_.TrimStart() -notmatch '^//' }) -join "`n"

Comp 'ShowActivated = false esta puesto' ($codigo -match 'ShowActivated\s*=\s*false') 'la propiedad de WPF para esto'
$iC = $codigo.IndexOf('public NovaUI()')
$iS = $codigo.IndexOf('ShowActivated')
Comp 'y esta en el constructor, antes de que exista ventana' ($iC -gt 0 -and $iS -gt $iC -and ($iS - $iC) -lt 2000) 'ponerlo despues no serviria'

Comp 'los estilos se ponen en SourceInitialized' ($codigo -match 'SourceInitialized\s*\+=') 'antes del primer fotograma'
$iSI = $codigo.IndexOf('SourceInitialized +=')
$iL  = $codigo.IndexOf('Loaded +=')
Comp 'y SourceInitialized va ANTES que Loaded' ($iSI -gt 0 -and $iL -gt 0 -and $iSI -lt $iL) 'ese es todo el arreglo'
$blSI = if ($iSI -gt 0 -and $iL -gt $iSI) { $codigo.Substring($iSI, $iL - $iSI) } else { '' }
Comp 'y ahi dentro se pone WS_EX_NOACTIVATE' ($blSI -match 'WS_EX_NOACTIVATE') ''
Comp 'y sigue puesto tambien en Loaded' ($codigo.Substring([Math]::Max($iL,0)) -match 'WS_EX_NOACTIVATE') 'la red, por si SourceInitialized no corriera'
Comp 'y PonerEncima sigue sin activar' ($codigo -match 'SetWindowPos\(hwnd, HWND_TOPMOST[^)]*SWP_NOACTIVATE') 'subir de capa no es coger el foco'

Write-Host ''
Write-Host '-- 1b. y con un juego delante se sigue viendo --'
# EL 0,32 NUNCA SE HABIA EJERCITADO: era el tamano para cuando hay un juego en pantalla
# completa, pero Nova estaba ciega a esos juegos hasta el arreglo del 24/09, asi que
# juegoActual llegaba vacio y en la practica siempre se usaba el 0,5. Al arreglar la ceguera se
# estreno la rama, y braya dijo que no veia la capsula: 0,32 sobre un punto de 22 px deja 7 px.
# Esta seccion existe para que ese numero no pueda volver a bajar sin que nadie se entere.
$mEsc = [regex]::Match($codigo, 'destino\s*=\s*pequena\s*\?\s*\(string\.IsNullOrEmpty\(juegoActual\)\s*\?\s*([0-9.]+)\s*:\s*([0-9.]+)\)')
Comp 'se encuentra la escala de reposo' $mEsc.Success ''
if ($mEsc.Success) {
    $sinJuego = [double]::Parse($mEsc.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    $conJuego = [double]::Parse($mEsc.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
    Comp 'con un juego delante NO baja de 0,40' ($conJuego -ge 0.40) "$conJuego (por debajo no se ve sobre el HUD)"
    Comp 'y sigue siendo mas discreta que sin juego' ($conJuego -lt $sinJuego) "$conJuego < $sinJuego"
    Comp 'y sin juego se mantiene' ($sinJuego -ge 0.45) "$sinJuego"
}

Write-Host ''
Write-Host '-- 2. y lo que CORRE lleva el arreglo, no solo el codigo --'
# Esta es la que de verdad protege: el .exe va versionado, asi que se puede editar el .cs y
# olvidarse de compilar. El arreglo estaria escrito y no funcionaria.
Comp 'el exe existe' (Test-Path -LiteralPath $EXE) ''
if (Test-Path -LiteralPath $EXE) {
    $tCs = (Get-Item -LiteralPath $CS).LastWriteTime
    $tEx = (Get-Item -LiteralPath $EXE).LastWriteTime
    Comp 'el exe se compilo DESPUES del codigo' ($tEx -ge $tCs) ("cs $($tCs.ToString('dd/MM HH:mm')) -> exe $($tEx.ToString('dd/MM HH:mm'))")
}

Write-Host ''
Write-Host '-- 3. LA PRUEBA DE VERDAD: arrancarla y ver si roba el foco --'
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class FocoW {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
}
"@
function Proc-Delante() {
    $h = [FocoW]::GetForegroundWindow()
    $p = [uint32]0
    [void][FocoW]::GetWindowThreadProcessId($h, [ref]$p)
    try { return (Get-Process -Id $p -ErrorAction Stop).ProcessName } catch { return '' }
}
# NO SE HACE CON UN JUEGO DELANTE: arrancar una segunda capsula mientras braya juega le mete
# una ventana en la pantalla, y eso es justo lo que este banco existe para evitar. Se salta
# con aviso, que es mas honesto que hacerlo igual o que fingir que se hizo.
$juego = @(Get-Process | Where-Object { $_.MainWindowTitle -and $_.WorkingSet64 -gt 800MB -and $_.ProcessName -notmatch 'chrome|msedge|firefox|Code' })
if ($juego.Count -gt 0) {
    Write-Host "  SALTADA: hay un juego delante ($($juego[0].ProcessName)); no se le mete una ventana encima"
    $saltadas++
} else {
    $antes = Proc-Delante
    Write-Host "  delante ahora: '$antes'"
    $estado = Join-Path ([IO.Path]::GetTempPath()) ('nova-foco-' + [Guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
    Set-Content -LiteralPath $estado -Value 'idle||' -Encoding UTF8
    $ui = $null
    try {
        $ui = Start-Process -FilePath $EXE -ArgumentList @("`"$estado`"", "$PID") -WorkingDirectory $Raiz -PassThru
        $null = $ui.Handle
        Start-Sleep -Seconds 3
        $despues = Proc-Delante
        Comp 'la capsula arranco' (-not $ui.HasExited) "PID $($ui.Id)"
        Comp 'y NO se puso delante' ($despues -ne 'nova_ui') "delante sigue '$despues'"
        Comp 'y el de delante no cambio' ($despues -eq $antes) "'$antes' -> '$despues'"
    } finally {
        if ($ui -and -not $ui.HasExited) { try { $ui.Kill() } catch {} }
        Remove-Item -LiteralPath $estado -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
if ($saltadas -gt 0) { Write-Host "  la capsula no roba el foco, PERO $saltadas seccion(es) saltada(s)"; exit 0 }
Write-Host '  la capsula no roba el foco'
exit 0
