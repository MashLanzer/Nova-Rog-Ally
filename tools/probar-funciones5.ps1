# Pruebas de las funciones de la quinta tanda: despertador, rutina de dormir,
# limite de juego, historial de musica, clip del juego, descargas de Steam y dock
# o cascos. Las funciones se sacan DEL ARCHIVO REAL; carpeta temporal propia.
#
#   powershell -NoProfile -File tools\probar-funciones5.ps1
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn($n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta la funcion $n en assistant.ps1" }
    return $f.Extent.Text
}
$top = $ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] }
foreach ($a in $top) { if (@('DIAS_SEMANA', 'MESES', 'HORAS_PALABRA') -contains $a.Left.VariablePath.UserPath) { Invoke-Expression $a.Extent.Text } }
foreach ($n in 'ConvertTo-Plain', 'Invoke-RecordatorioVoz', 'Get-Recordatorios', 'Save-Recordatorios', 'Get-MinutosDichos', 'Format-MinutosDichos',
    'Invoke-DespertadorVoz', 'Invoke-RutinaDormir', 'Test-LimiteJuego', 'Get-HistorialMusica', 'Add-HistorialMusica', 'Find-CancionDe',
    'Get-CancionAnterior', 'Invoke-ClipJuego', 'Get-DescargaJuego', 'Format-Gigas', 'Watch-Dispositivos', 'Write-Atomico', 'Test-DictadoDudoso', 'Add-DiarioResumen') { Invoke-Expression (TraerFn $n) }

$MemoriaDir = Join-Path $env:TEMP ('nova-f5-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $MemoriaDir | Out-Null
$RecordatoriosPath = Join-Path $MemoriaDir 'recordatorios.json'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$script:eventos = @(); $script:avisos = @()
function Log($m) {}
function Add-Estadistica {}
function Refresh-UI {}
function Save-Corrupto($r, $q) {}
function Send-UIEvento($e) { $script:eventos += $e }
function Send-Aviso($t, $tipo) { $script:avisos += $t }
$mal = 0
function Comp($etq, $ok, $det = '') {
    if (-not $ok) { $script:mal++ }
    "  {0}  {1}{2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $etq, $(if ("$det" -ne '') { "  -> $det" } else { '' })
}

Write-Host "--- minutos dichos ---"
Comp 'dos horas' ((Get-MinutosDichos 'dos' 'horas') -eq 120)
Comp 'media hora' ((Get-MinutosDichos 'media' 'hora') -eq 30)
Comp 'una hora y media' ((Get-MinutosDichos 'una' 'hora y media') -eq 90)
Comp '45 minutos' ((Get-MinutosDichos '45' 'minutos') -eq 45)
Comp 'y se dicen bien' ((Format-MinutosDichos 120) -eq '2 horas' -and (Format-MinutosDichos 60) -eq 'una hora' -and (Format-MinutosDichos 30) -eq 'media hora' -and (Format-MinutosDichos 45) -eq '45 minutos')

Write-Host "--- despertador ---"
$script:despertadorSonoEn = -9999999
$r = Invoke-DespertadorVoz 'despiertame manana a las 7'
Comp 'se pone para manana a las 7' ($r -match '^Listo, te despierto manana a las 7:00') $r
$rs = @(Get-Recordatorios)
Comp 'queda como un recordatorio despertador' ($rs.Count -eq 1 -and $rs[0].texto -eq 'despertador' -and ([datetime]$rs[0].cuando).Hour -eq 7) ($rs | ConvertTo-Json -Compress)
Comp 'en 20 minutos es un temporizador, no esto' ($null -eq (Invoke-DespertadorVoz 'despiertame en 20 minutos'))
Comp 'lo que no es un despertador, nada' ($null -eq (Invoke-DespertadorVoz 'abre steam'))
Comp 'cinco minutos mas solo si acaba de sonar' ($null -eq (Invoke-DespertadorVoz 'cinco minutos mas'))
$script:despertadorSonoEn = $sw.ElapsedMilliseconds
$r2 = Invoke-DespertadorVoz 'cinco minutos mas'
Comp 'recien sonado, lo pospone' ($r2 -eq 'Vale, 5 minutos mas.' -and @(Get-Recordatorios).Count -eq 2) $r2
Comp 'se quita' ((Invoke-DespertadorVoz 'quita el despertador') -eq 'Despertador quitado.' -and @(Get-Recordatorios).Count -eq 0)

Write-Host "--- rutina de dormir ---"
$script:ordenes = @()
function Invoke-FastCommand($t) { $script:ordenes += $t; return 'hecho' }
$script:pendiente = $null
$rr = Invoke-RutinaDormir
Comp 'baja brillo y volumen y pregunta por el despertador' ($script:ordenes -contains 'pon el brillo al 20' -and $script:ordenes -contains 'pon el volumen al 20' -and $rr -match 'despertador\?$' -and $script:pendiente.tipo -eq 'despertador') $rr
$script:pendiente = $null
[void](Invoke-DespertadorVoz 'despiertame manana a las 8')
$rr2 = Invoke-RutinaDormir
Comp 'con despertador puesto, no pregunta' ($rr2 -match 'ya esta puesto' -and $null -eq $script:pendiente) $rr2

Write-Host "--- limite de juego ---"
$script:juegoActivo = 'Hades'
$script:juegoDesde = $sw.ElapsedMilliseconds - 119 * 60000
$script:limiteJuego = @{ min = 120; avisos = 0; visto = $false }
Test-LimiteJuego
Comp 'antes de llegar, nada' ($script:avisos.Count -eq 0)
$script:juegoDesde = $sw.ElapsedMilliseconds - 121 * 60000
Test-LimiteJuego; Test-LimiteJuego
Comp 'al llegar, un aviso (y solo uno)' ($script:avisos.Count -eq 1 -and $script:avisos[0] -match '2 horas con Hades') ($script:avisos -join ' | ')
$script:juegoDesde = $sw.ElapsedMilliseconds - 136 * 60000
Test-LimiteJuego
Comp '15 min despues, otro mas firme' ($script:avisos.Count -eq 2 -and $script:avisos[1] -match 'dejamos')
$script:juegoActivo = $null
Test-LimiteJuego
Comp 'al cerrar el juego se quita' ($null -eq $script:limiteJuego)

Write-Host "--- historial de musica ---"
# las tildes con codigos: este archivo no lleva BOM y PowerShell 5.1 leeria mal los literales
$titi = "Tit$([char]0xED) me pregunt$([char]0xF3)"
$mananera = "Ma$([char]0xF1)anera"
$script:invitado = $false; $script:musicaHist = $null; $script:uiMusica = 0; $script:musicaTitulo = ''
$ahora = Get-Date '2026-09-20 12:00'
Add-HistorialMusica $titi 'Bad Bunny' (Get-Date '2026-09-19 22:10')
Add-HistorialMusica $titi 'Bad Bunny' (Get-Date '2026-09-19 22:14')
Add-HistorialMusica 'Otra' 'X' (Get-Date '2026-09-19 22:30')
Add-HistorialMusica $titi 'Bad Bunny' (Get-Date '2026-09-19 23:00')
Add-HistorialMusica $mananera 'Y' (Get-Date '2026-09-20 08:00')
Comp 'no apunta dos veces seguidas la misma' ((Get-HistorialMusica).Count -eq 4) ((Get-HistorialMusica).Count)
$cN = Find-CancionDe 'anoche' $ahora
Comp 'la que mas sono anoche' ($cN -and $cN.t -ceq $titi) $cN.t
$cM = Find-CancionDe 'esta manana' $ahora
Comp 'esta manana' ($cM -and $cM.t -ceq $mananera) $cM.t
Comp 'de un rato sin musica, nada' ($null -eq (Find-CancionDe 'ayer por la manana' $ahora))
$script:musicaHist = $null
$hD = Get-HistorialMusica
Comp 'sobrevive al disco, con tildes' ($hD.Count -eq 4 -and $hD[0].t -ceq $titi) ($hD.Count)
$cAnt = Get-CancionAnterior
Comp 'esa cancion: la ultima si no suena nada' ($cAnt.t -ceq $mananera) $cAnt.t
$script:uiMusica = 1; $script:musicaTitulo = $mananera
$cAnt2 = Get-CancionAnterior
Comp 'y la de antes si la ultima es la que suena' ($cAnt2.t -ceq $titi) $cAnt2.t
$script:invitado = $true; Add-HistorialMusica 'De invitado' 'Z'; $script:invitado = $false
Comp 'lo de un invitado no se apunta' ((Get-HistorialMusica).Count -eq 4)

Write-Host "--- clip del juego y descargas ---"
function Get-ItemProperty { param($Path, $ErrorAction) return [pscustomobject]@{ HistoricalCaptureEnabled = $script:gdvr } }
$script:combos = @()
function Send-Combinacion($c) { $script:combos += $c }
$script:gdvr = 0
Comp 'sin grabacion en segundo plano lo dice y no pulsa nada' ((Invoke-ClipJuego) -match 'activa en la Game Bar' -and $script:combos.Count -eq 0)
$script:gdvr = 1
Comp 'con ella, Win+Alt+G' ((Invoke-ClipJuego) -eq 'clip guardado' -and $script:combos[0] -eq 'win+alt+g')
function Find-Juego($t) { if ($t -match 'elden') { return @{ nombre = 'ELDEN RING' } }; if ($t -match 'hades') { return @{ nombre = 'Hades' } }; return $null }
$script:Juegos = @(@{ nombre = 'ELDEN RING'; bajando = $true; descargado = 25GB; total = 50GB }, @{ nombre = 'Hades'; bajando = $false; descargado = 0; total = 0 })
$dj = Get-DescargaJuego 'elden ring'
Comp 'cuanto le queda a un juego que se baja' ($dj -match '^ELDEN RING va por el 50 por ciento; faltan') $dj
Comp 'un juego que no se baja' ((Get-DescargaJuego 'hades') -eq 'Hades no se esta descargando')
Comp 'lo que no es un juego, nada' ($null -eq (Get-DescargaJuego 'la pizza'))

Write-Host "--- dock y cascos ---"
$script:reglasDisparadas = @()
function Invoke-Reglas($tipo, $dato) { $script:reglasDisparadas += "$tipo=$dato" }
$script:salidaNombre = 'Altavoces (Realtek)'
function Get-SalidasAudio { return @(@{ nombre = $script:salidaNombre; actual = $true }) }
$script:pantallasAntes = $null; $script:cascosAntes = $null; $script:uiDock = 0
Watch-Dispositivos
Comp 'la primera vez solo mira, no dispara' ($script:reglasDisparadas.Count -eq 0)
$script:salidaNombre = 'Auriculares (WH-1000XM4)'
Watch-Dispositivos
Comp 'al ponerte los cascos, dispara' ($script:reglasDisparadas -contains 'cascosPone=pone' -and $script:reglasDisparadas.Count -eq 1) ($script:reglasDisparadas -join ',')
Watch-Dispositivos
Comp 'y no se repite mientras sigan puestos' ($script:reglasDisparadas.Count -eq 1)
$script:pantallasAntes = 0
Watch-Dispositivos
Comp 'una pantalla mas: el dock' ($script:reglasDisparadas -contains 'dockPone=pone') ($script:reglasDisparadas -join ',')

Write-Host "--- dato dudoso de una receta y diario de conversaciones ---"
$script:dictadoConfianza = -0.9; $script:dictadoConfianzaEn = $sw.ElapsedMilliseconds
Comp 'un dictado con poca seguridad es dudoso' (Test-DictadoDudoso)
$script:dictadoConfianza = -0.3
Comp 'uno claro, no' (-not (Test-DictadoDudoso))
$script:dictadoConfianza = -0.9; $script:dictadoConfianzaEn = $sw.ElapsedMilliseconds - 120000
Comp 'lo de hace mas de un minuto no cuenta' (-not (Test-DictadoDudoso))
$DiarioDir = Join-Path $MemoriaDir 'diario'
Add-DiarioResumen '2026-09-13' "- braya hablo de Hades`n- y de musica"
$notaD = Join-Path $DiarioDir '2026-09-13.md'
$txtD = if (Test-Path $notaD) { [System.IO.File]::ReadAllText($notaD) } else { '' }
Comp 'el resumen va al diario de ese dia, con titulo' ($txtD -match '^# ' -and $txtD -match '## Lo que hablamos' -and $txtD -match '- braya hablo de Hades' -and $txtD -match '- y de musica') $txtD
Add-DiarioResumen '2026-09-13' "- otra charla"
Comp 'un segundo resumen del mismo dia se anade, no pisa' (([System.IO.File]::ReadAllText($notaD)) -match 'Hades' -and ([System.IO.File]::ReadAllText($notaD)) -match 'otra charla')
Add-DiarioResumen 'no es fecha' '- x'
Comp 'una fecha rara no crea nada' (@(Get-ChildItem $DiarioDir).Count -eq 1)

Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
