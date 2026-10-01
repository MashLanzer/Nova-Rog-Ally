# LA COPIA DE LA PARTIDA GUARDADA, ANTES DE JUGAR (30/09, la 1 de las 20 funciones nuevas)
#
# Lo que se respaldaba hasta hoy era lo que Nova APRENDE, no lo que braya JUEGA. Esta seccion
# comprueba las tres cosas que hacen que el respaldo sirva de algo:
#   1. que encuentre donde guarda cada juego -el nombre de la carpeta NO es el del juego:
#      'ELDEN RING' guarda en 'EldenRing'-,
#   2. que NO copie si no se ha jugado (110,51 MB de Elden Ring en cada alt-tab llenan los 27 GB
#      libres en una tarde),
#   3. y que no case por una letra en comun, que convertiria 'PEAK' en cualquier carpeta.
#
# NO TOCA LAS COPIAS DE VERDAD: $CopiasDir apunta a una carpeta temporal que se borra al final.
# Y NO LLAMA A ROBOCOPY EN LA BATERIA: la copia de verdad se prueba contra un juego de pega hecho
# aqui, no contra los 110 MB de Elden Ring.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}

$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}

# el entorno de pega: todo lo que se escribe va a una carpeta temporal
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-saves-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $LogDir = $Raiz
    $MemoriaDir = $tmp
    $CopiasDir = Join-Path $tmp 'copias'
    $SavesEstadoPath = Join-Path $tmp 'saves-copias.json'
    $SavesCopiasMax = 3
    $SavesTopeMB = 600
    foreach ($n in @('ConvertTo-Plain', 'Write-Atomico', 'Get-SitiosGuardado', 'Get-CarpetaGuardado',
                     'Get-SelloGuardado', 'Get-SavesEstado', 'Backup-GuardadoJuego')) {
        Invoke-Expression (Traer $n)
    }
    $script:dichos = @()
    function Log([string]$m) { $script:dichos += $m }

    $txt = [IO.File]::ReadAllText($PS1)
    Write-Host ''
    Write-Host '-- 1. los numeros salen del archivo --'
    Comp 'el tope de copias por juego' ($txt -match '\$SavesCopiasMax = 3') 'tres, y rota'
    Comp 'y el tope de tamano' ($txt -match '\$SavesTopeMB = 600') 'mas que eso se dice y no se copia'

    Write-Host ''
    Write-Host '-- 2. un juego de pega: encuentra, copia, y no repite --'
    # EL JUEGO DE PEGA VIVE EN UN SITIO DE PEGA: Get-SitiosGuardado mira las variables de entorno,
    # asi que se le cambia USERPROFILE y APPDATA a la carpeta temporal. Asi este banco no depende
    # de que braya tenga tal juego instalado hoy -la manera 5 de salir verde mintiendo- ni escribe
    # un byte en sus carpetas de verdad.
    $falsoPerfil = Join-Path $tmp 'perfil'
    $falsoApp = Join-Path $falsoPerfil 'AppData\Roaming'
    New-Item -ItemType Directory -Force -Path $falsoApp | Out-Null
    $carpetaJuego = Join-Path $falsoApp 'JuegoDePega'
    New-Item -ItemType Directory -Force -Path $carpetaJuego | Out-Null
    [IO.File]::WriteAllText((Join-Path $carpetaJuego 'partida.sav'), 'una partida a medias')
    $viejoPerfil = $env:USERPROFILE; $viejoApp = $env:APPDATA; $viejoLocal = $env:LOCALAPPDATA
    try {
        $env:USERPROFILE = $falsoPerfil; $env:APPDATA = $falsoApp; $env:LOCALAPPDATA = $falsoApp
        $c = Get-CarpetaGuardado 'Juego De Pega'
        Comp 'encuentra la carpeta aunque el nombre lleve espacios' ($c -eq $carpetaJuego) "$c"
        $s1 = Get-SelloGuardado $c
        Comp '  y le saca su sello' ($null -ne $s1 -and $s1.n -eq 1) "$(if ($s1) { "$($s1.n) fichero(s)" } else { 'nulo' })"

        $r1 = Backup-GuardadoJuego 'Juego De Pega'
        Comp 'la primera vez la copia' ($r1 -eq 'copiada') "$r1"
        $r2 = Backup-GuardadoJuego 'Juego De Pega'
        Comp '  y la segunda NO la repite' ($r2 -eq 'ya estaba copiado') "$r2"

        # Y SI SE JUEGA, VUELVE A COPIAR: lo que decide es el sello, no el reloj. Sin esto, el
        # respaldo se haria una vez en la vida y no serviria para nada.
        Start-Sleep -Milliseconds 1100
        [IO.File]::WriteAllText((Join-Path $carpetaJuego 'partida.sav'), 'una partida mas avanzada que antes')
        $r3 = Backup-GuardadoJuego 'Juego De Pega'
        Comp 'si la partida cambia, vuelve a copiarla' ($r3 -eq 'copiada') "$r3"

        Write-Host ''
        Write-Host '-- 3. lo que NO debe pasar --'
        $cNo = Get-CarpetaGuardado 'Juego Que No Existe 99999'
        Comp 'un juego sin carpeta no inventa ninguna' (-not $cNo) "$cNo"
        Comp '  y copiarlo no revienta' ((Backup-GuardadoJuego 'Juego Que No Existe 99999') -eq 'no encuentro donde guarda') ''
        # UN NOMBRE DE DOS LETRAS NO PUEDE CASAR CON NADA: si no, 'ab' se llevaria cualquier carpeta
        Comp 'un nombre de dos letras no casa con nada' (-not (Get-CarpetaGuardado 'ab')) 'haria falsos positivos en masa'
        # Y NO CASA POR TENER LETRAS EN COMUN: 'Pega' no es 'JuegoDePega'
        Comp 'y no casa por llevar letras en comun' (-not (Get-CarpetaGuardado 'Pega')) 'tiene que empezar igual'

        Write-Host ''
        Write-Host '-- 4. el tope de tamano se respeta --'
        $SavesTopeMB = 0.000001      # cualquier cosa pasa de aqui
        $script:dichos = @()
        Start-Sleep -Milliseconds 1100
        [IO.File]::WriteAllText((Join-Path $carpetaJuego 'partida.sav'), 'otra vez distinta para que el sello cambie')
        $r4 = Backup-GuardadoJuego 'Juego De Pega'
        Comp 'lo que pasa del tope no se copia' ($r4 -eq 'pesa demasiado') "$r4"
        Comp '  y se dice en el log' (@($script:dichos | Where-Object { $_ -match 'el tope son' }).Count -ge 1) 'callarse seria perder la partida sin avisar'
    } finally {
        $env:USERPROFILE = $viejoPerfil; $env:APPDATA = $viejoApp; $env:LOCALAPPDATA = $viejoLocal
    }

    Write-Host ''
    Write-Host '-- 5. el cableado: se llama al entrar en el juego --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    $iEnt = $sinCom.IndexOf('function Enter-Juego')
    $iBk = $sinCom.IndexOf('Backup-GuardadoJuego $nombre', $iEnt)
    Comp 'Enter-Juego llama a la copia' ($iEnt -ge 0 -and $iBk -gt $iEnt) ''
    # Y LO PRIMERO, antes de que el juego escriba: copiar despues de arrancarlo no respalda nada.
    $iAviso = $sinCom.IndexOf('juego-pendiente-', $iEnt)
    Comp '  y antes que lo demas de Enter-Juego' ($iBk -gt 0 -and $iAviso -gt $iBk) 'si copia tarde, copia lo ya pisado'
    # NO PUEDE ESPERAR A ROBOCOPY: esperarlo serian 110 MB de bucle congelado, que es la regla 4 y
    # es justo lo que dejo a Nova sorda el 63 % del tiempo este mismo dia.
    $cuerpoBk = Traer 'Backup-GuardadoJuego'
    Comp '  y no espera a que acabe la copia' (($cuerpoBk -match 'Start-Process') -and ($cuerpoBk -notmatch '-Wait')) 'robocopy aparte, sin -Wait'
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'la partida guardada se respalda antes de jugar, y solo si has jugado' -ForegroundColor Green
exit 0
